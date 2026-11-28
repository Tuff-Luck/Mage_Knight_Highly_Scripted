-- Cohesive EnemyProperties services; preserve original lexical and factory boundaries.

-- EnemyAttacks
local attacks=(function()
-- Build fresh attack records and apply printed/perk/effect changes.
-- The caller supplies summoned records and the current per-source attack choices.
return function(attackTypes,combatEnemyHasTrait,combatEnemyFortificationCount)
    -- owner/slot identify the physical token carrying each attack, so its damage button can find it again.
    local function combatEnemyPrintedAttacks(data,perks,stripAbilities,ownerGUID)
        local attacks={}
        local base=type(data.attack)=="table" and data.attack or {}
        local override=perks~=nil and type(perks.attack)=="table" and perks.attack or {}
        local elemental=perks~=nil and perks.elemental==true
        local boost=perks~=nil and tonumber(perks.boost) or 0
        local boostUsed=false
        local swift=not stripAbilities and combatEnemyHasTrait(data,perks,"swiftness")
        local brutal=not stripAbilities and combatEnemyHasTrait(data,perks,"brutal")
        local cumbersome=not stripAbilities and combatEnemyHasTrait(data,perks,"cumbersome")
        local poison=not stripAbilities and combatEnemyHasTrait(data,perks,"poison")
        local paralyse=not stripAbilities and combatEnemyHasTrait(data,perks,"paralyse")
        local assassination=not stripAbilities and combatEnemyHasTrait(data,perks,"assassination")
        for _,attackType in ipairs(attackTypes) do
            local values=override[attackType.key] or base[attackType.key]
            for _,printedValue in ipairs(type(values)=="table" and values or {}) do
                local bonus=elemental and (attackType.key=="IF" and 1 or 2) or 0
                if not boostUsed and boost~=0 then bonus=bonus+boost boostUsed=true end
                -- Psychic Attacks never inherit offensive abilities (Apocalypse Dragon).
                local psychic=attackType.key=="M"
                attacks[#attacks+1]={key=attackType.key,label=attackType.label,
                    value=math.max(0,printedValue+bonus),block=attackType.block,
                    swift=not psychic and swift,brutal=not psychic and brutal,
                    cumbersome=not psychic and cumbersome,poison=not psychic and poison,
                    paralyse=not psychic and paralyse,assassination=not psychic and assassination,
                    owner=ownerGUID,slot=#attacks+1}
            end
        end
        return attacks
    end

    -- Know Your Prey changes exactly one printed attack's element. This does not
    -- affect other attacks (including ones belonging to a separate summoned token).
    local function convertPreyAttacks(attacks,effect)
        for _,conversion in ipairs(effect~=nil and effect.attackConversions or {}) do
            local attack=attacks[conversion.slot]
            if attack~=nil and attack.key==conversion.from then
                for _,kind in ipairs(attackTypes) do
                    if kind.key==conversion.to then
                        attack.key=kind.key
                        attack.label=kind.label
                        attack.block=kind.block
                        break
                    end
                end
            end
        end
    end

    -- A summoner with no token out yet counts as one 0 attack with no abilities per token still to come.
    -- Effects stored against a summoned token apply to that token's attacks while it replaces its summoner.
    local function combatSummonedAttackPrevented(summoned)
        local effect=summoned.effect
        -- Destruction (e.g. Nature's Vengeance) is distinct from cancelling an
        -- already revealed summon attack.
        return effect~=nil and effect.destroy==true
    end

    -- An Attack reduction modifies one printed Attack, not every Attack on a multi-attack enemy.
    -- When several Attacks exist, use the currently strongest one, with stable order on ties.
    -- All reductions are rebuilt from the original printed values on every scan (never cumulative).
    local function combatOrderedReductions(effect)
        local ordered={}
        for _,reduction in ipairs(effect~=nil and effect.attackReductions or {}) do
            ordered[#ordered+1]=reduction
        end
        table.sort(ordered,function(a,b)
            if a.amount~=b.amount then return a.amount>b.amount end
            -- A card can reduce two attacks on the same enemy. Keep its
            -- separate -2 effects in a predictable order so each one can be
            -- selected independently with the calculator's attack-cycle control.
            if a.source~=b.source then return tostring(a.source)<tostring(b.source) end
            return tostring(a.id or a.source)<tostring(b.id or b.source)
        end)
        return ordered
    end

    local function stripEligible(attack,reduction)
        if reduction.stripOwner~=nil and attack.owner~=reduction.stripOwner then return false end
        if reduction.stripTrait~=nil then return attack[reduction.stripTrait]==true end
        if reduction.stripColor~=nil then
            return attack.key==reduction.stripColor or attack.key=="IF"
        end
        return true
    end

    local function combatApplyAttackReductions(attacks,effect,ownerGUID,chosenAttacks)
        for _,reduction in ipairs(combatOrderedReductions(effect)) do
            local sourceKey=reduction.id or tostring(reduction.source)
            local choice=chosenAttacks~=nil and chosenAttacks[sourceKey] or nil
            local target=choice~=nil and attacks[choice] or nil
            if target~=nil and ((target.pending and not reduction.cancelAttack)
                or (target.summoned and reduction.cancelAttack) or target.cancelled
                or (ownerGUID~=nil and target.owner~=ownerGUID)
                or not stripEligible(target,reduction)) then
                target=nil
            end
            -- Stale selections fall back to the strongest currently legal attack.
            if target==nil then
                for _,attack in ipairs(attacks) do
                    if (not attack.pending or reduction.cancelAttack)
                        and not (attack.summoned and reduction.cancelAttack) and not attack.cancelled
                        and (ownerGUID==nil or attack.owner==ownerGUID)
                        and stripEligible(attack,reduction)
                        and (attack.value>0 or reduction.amount<0
                            or reduction.stripAbilities or reduction.cancelAttack
                            or reduction.stripTrait~=nil or reduction.stripColor~=nil)
                        and (target==nil or attack.value>target.value) then
                        target=attack
                    end
                end
            end
            if target~=nil then
                if reduction.cancelAttack then
                    target.cancelled=true
                    target.cancelSource=sourceKey
                end
                target.value=math.max(0,target.value-reduction.amount)
                if reduction.stripAbilities then
                    for _,trait in ipairs({"swift","brutal","cumbersome","poison",
                        "paralyse","assassination"}) do target[trait]=false end
                    target.abilitiesStripped=true
                end
                if reduction.stripTrait~=nil then
                    target[reduction.stripTrait]=false
                    target.strippedTraits=target.strippedTraits or {}
                    target.strippedTraits[reduction.stripTrait]=true
                end
                if reduction.stripColor~=nil then
                    local to=target.key=="IF" and (reduction.stripColor=="F" and "I" or "F") or "P"
                    for _,kind in ipairs(attackTypes) do
                        if kind.key==to then
                            target.key,target.label,target.block=kind.key,kind.label,kind.block
                            break
                        end
                    end
                end
                if reduction.firstDamageUnit~=nil then target.firstDamageUnit=reduction.firstDamageUnit end
            end
        end
    end

    local function combatEnemyAttacks(entry,includeCancelled,chosenAttacks)
        if entry.noAttack or entry.destroyed then return {} end
        local attacks=combatEnemyPrintedAttacks(entry.data,entry.perks,entry.removeAbilities,entry.guid)
        if entry.data.monsters~=nil then
            for _,summoned in ipairs(entry.summoned or {}) do
                if not combatSummonedAttackPrevented(summoned)
                    and not (entry.summonedDestroyed~=nil
                        and entry.summonedDestroyed[summoned.guid]==true) then
                    local strip=summoned.effect~=nil and summoned.effect.removeAbilities==true
                    local summonedAttacks=combatEnemyPrintedAttacks(summoned.data,summoned.perks,strip,summoned.guid)
                    for _,attack in ipairs(summonedAttacks) do attack.summoned=true end
                    convertPreyAttacks(summonedAttacks,summoned.effect)
                    combatApplyAttackReductions(summonedAttacks,summoned.effect,summoned.guid)
                    if summoned.effect~=nil and summoned.effect.grantCumbersome==true then
                        for _,attack in ipairs(summonedAttacks) do
                            if attack.key~="M" and not attack.abilitiesStripped
                                and not (attack.strippedTraits or {}).cumbersome then attack.cumbersome=true end
                        end
                    end
                    for _,attack in ipairs(summonedAttacks) do attacks[#attacks+1]=attack end
                end
            end
            if not entry.summonDone then
                for slot=#(entry.summoned or {})+1,#entry.data.monsters do
                    attacks[#attacks+1]={key="P",label="Summon",value=0,block="block",
                        pending=true,owner=entry.guid,summonSlot=slot}
                end
            else
                -- The physical draw is asynchronous. These placeholders cannot
                -- be cancelled because the draw has already been committed.
                for _=1,(entry.summonPending or 0) do
                    attacks[#attacks+1]={key="P",label="Summon",value=0,block="block",
                        pending=true,summoned=true,owner=entry.guid}
                end
            end
        end
        -- Apply the summoner's changes only to its own printed attacks. Changes
        -- aimed at a summoned monster were already applied to that token above.
        if entry.effect~=nil and #attacks>0 then
            local ownAttacks={}
            for _,attack in ipairs(attacks) do
                if attack.owner==entry.guid then ownAttacks[#ownAttacks+1]=attack end
            end
            convertPreyAttacks(ownAttacks,entry.effect)
        end
        combatApplyAttackReductions(attacks,entry.effect,nil,chosenAttacks)
        if entry.effect~=nil and entry.effect.grantCumbersome==true then
            for _,attack in ipairs(attacks) do
                if attack.owner==entry.guid and attack.key~="M"
                    and not attack.abilitiesStripped
                                and not (attack.strippedTraits or {}).cumbersome then attack.cumbersome=true end
            end
        end
        -- Keep original attack positions for the attack-cycle selector; actual
        -- combat omits precisely the cancelled attack and all its abilities.
        if not includeCancelled then
            for i=#attacks,1,-1 do
                if attacks[i].cancelled then table.remove(attacks,i) end
            end
        end
        return attacks
    end

    return {printed=combatEnemyPrintedAttacks,convertPreyAttacks=convertPreyAttacks,
        orderedReductions=combatOrderedReductions,applyReductions=combatApplyAttackReductions,
        enemyAttacks=combatEnemyAttacks}
end
end)()

-- EnemyDefences
local defences=(function()
-- Enemy defensive traits, effective Attack and grouped Armour calculations.
-- The coordinator retains physical enemy records, effects, phase state and targeting.
-- Read the live configuration so Artifact mode changes apply on every calculation.
return function(combatConfig)
    local function combatEnemyHasTrait(data,perks,key)
        return data[key]==true or (perks~=nil and perks[key]==true)
    end

    local function combatEnemyFortificationCount(data,perks)
        if combatEnemyHasTrait(data,perks,"unfortified") then return 0 end
        return (data.fortified==true and 1 or 0)
            +(perks~=nil and perks.fortified==true and 1 or 0)
            +(perks~=nil and perks.wallFortified==true and 1 or 0)
    end

    local function combatEnemyResists(data,perks,attackType)
        if attackType=="P" then return combatEnemyHasTrait(data,perks,"pResist") end
        if attackType=="F" then return combatEnemyHasTrait(data,perks,"fResist") end
        if attackType=="I" then return combatEnemyHasTrait(data,perks,"iResist") end
        -- Cold Fire is only resisted by an enemy with both Fire and Ice Resistance.
        if attackType=="IF" then
            -- A group resists Cold Fire only if one individual member has both traits.
            -- The ordinary group resistance flags are merged independently.
            if data~=nil and data.coldFireResist~=nil then return data.coldFireResist==true end
            return combatEnemyHasTrait(data,perks,"fResist")
                and combatEnemyHasTrait(data,perks,"iResist")
        end
        return combatEnemyHasTrait(data,perks,"mResist")
    end

    -- Groups are {sources=,category=}. The resisted part of one phase's attack is
    -- totalled first and halved once, rounding down.
    local function combatAttackTotal(groups,data,perks,phase)
        local normal,resisted=0,0
        local operations=combatConfig.resourceOperations
        local function phaseValue(source,field,asFamily)
            local value=tonumber(source.resources[field]) or 0
            return value+(operations~=nil and
                operations.phaseAttackBonus(source,field,phase,asFamily) or 0)
        end
        for _,group in ipairs(groups) do
            for _,source in ipairs(group.sources) do
                if not (source.dueling and source.duelingEligible==false
                    and group.category~="block") then
                    for _,attackType in ipairs(combatConfig.attackTypes) do
                        local value=phaseValue(source,attackType[group.category],group.category)
                        if phase=="range" and combatConfig.artifactCombat.bow then
                            local modeR=combatConfig.bowSourceModes[source.key.."#ranged"] or "double"
                            local modeS=combatConfig.bowSourceModes[source.key.."#siege"] or "none"
                            if group.category=="ranged" then
                                if modeR=="siege" then value=0
                                else value=value*2 end
                                if modeS=="ranged" then
                                    value=value+2*phaseValue(source,attackType.siege,"ranged")
                                end
                            elseif group.category=="siege" then
                                if modeS=="ranged" then value=0 end
                                if modeR=="siege" then
                                    value=value+phaseValue(source,attackType.ranged,"siege")
                                end
                            end
                        end
                        if value>0 then
                            -- Sword doubles every physical contribution in the
                            -- Attack phase, including physical Unit and Skill effects.
                            -- An Arcane Immune enemy keeps its printed Resistance.
                            if phase=="attack" and combatConfig.artifactCombat.sword
                                and attackType.key=="P" then
                                value=value*2
                            end
                            -- Bow's Ranged double only applies in the Ranged/Siege
                            -- phase. The later Attack phase is ordinary Attack.
                            local resistant=combatEnemyResists(data,perks,attackType.key)
                            if resistant and attackType.key=="P"
                                and combatConfig.artifactCombat.sword
                                and not combatEnemyHasTrait(data,perks,"arcaneImmunity") then
                                resistant=false
                            end
                            if resistant then resisted=resisted+value
                            else normal=normal+value end
                        end
                    end
                end
            end
        end
        return normal+math.floor(resisted/2)
    end

    -- A group is attacked as one: fortification and resistance of any member apply to all of
    -- them and the armours add together. Elusive members only use their higher armour in the
    -- Attack phase while one of their attacks is unblocked.
    local function combatGroupEntry(members,blockedAll,rangePhase)
        local data={fortified=false,elusive=true,coldFireResist=false}
        local perks={}
        local fortification=0
        local armour,elusiveArmour,attackArmour=0,0,0
        for _,member in ipairs(members) do
            if not member.stripFortify then
                fortification=math.max(fortification,combatEnemyFortificationCount(member.data,member.perks))
            end
            for _,key in ipairs({"pResist","fResist","iResist","mResist"}) do
                if not member.stripResist and not (key=="fResist" and member.stripFireResist)
                    and combatEnemyHasTrait(member.data,member.perks,key) then data[key]=true end
            end
            if not member.stripResist
                and not member.stripFireResist
                and combatEnemyHasTrait(member.data,member.perks,"fResist")
                and combatEnemyHasTrait(member.data,member.perks,"iResist") then
                data.coldFireResist=true
            end
            local elusive=combatEnemyHasTrait(member.data,member.perks,"elusive")
            local baseArmour=(rangePhase and member.rangeBaseArmour) or member.baseArmour
            local elusiveValue=(rangePhase and member.rangeElusiveArmour) or member.elusiveArmour
            local rangeArmour=elusive and elusiveValue or baseArmour
            armour=armour+baseArmour
            elusiveArmour=elusiveArmour+rangeArmour
            attackArmour=attackArmour+((elusive and not blockedAll[member.guid]) and elusiveValue or baseArmour)
        end
        data.fortified=fortification>=1
        perks.wallFortified=fortification>=2
        return {data=data,perks=perks,baseArmour=armour,elusiveArmour=elusiveArmour},attackArmour
    end

    -- Bonuses first assigned in the regular Attack phase must not retrospectively
    -- make an earlier Ranged/Siege attack fail.
    local function combatRangeGroupEntry(members)
        local result=combatGroupEntry(members,{},true)
        local lateBonus=0
        for _,member in ipairs(members) do lateBonus=lateBonus+(member.defendMeleeBonus or 0) end
        if lateBonus>0 then
            result.baseArmour=result.baseArmour-lateBonus
            result.elusiveArmour=result.elusiveArmour-lateBonus
        end
        local extra=0
        for _,member in ipairs(members) do
            if (member.bossLevel or 0)>1 then
                local armour=combatEnemyHasTrait(member.data,member.perks,"elusive")
                    and (member.rangeElusiveArmour or member.elusiveArmour)
                    or (member.rangeBaseArmour or member.baseArmour)
                extra=extra+((member.bossLevel-1)*math.max(1,
                    armour-(member.defendMeleeBonus or 0)))
            end
        end
        result.fullLevelArmour=(combatEnemyHasTrait(result.data,result.perks,"elusive")
            and result.elusiveArmour or result.baseArmour)+extra
        return result
    end

    -- Mutates only fresh calculator entries; never changes printed or saved perk data.
    local function prepareFortifications(entries,ignoreSiteFortifications)
        -- Preserve the printed/site Fortification before Demolish/Expose strips it.
        for _,entry in ipairs(entries) do
            entry.originalFortification=combatEnemyFortificationCount(entry.data,entry.perks)
        end
        -- Ignore site/wall Fortified, but preserve the monster's printed Fortified.
        if ignoreSiteFortifications==true then
            for _,entry in ipairs(entries) do
                local perks=entry.perks
                if perks~=nil and (perks.fortified==true or perks.wallFortified==true) then
                    local adjusted={}
                    for key,value in pairs(perks) do adjusted[key]=value end
                    adjusted.fortified=false
                    adjusted.wallFortified=false
                    entry.perks=adjusted
                end
            end
        end
    end

    -- Attack discovery is supplied by the coordinator, preserving the existing
    -- Taunt timing and ordering of effect application before phase flags.
    local function applyEffects(entry,effect,combatEnemyAttacks)
        if effect~=nil then
            -- Remove only the trait PRINTED on the selected enemy token. A
            -- separate fortification/resistance granted by its site remains.
            if next(effect.removedPrinted or {})~=nil then
                local copy={}
                for key,value in pairs(entry.data) do copy[key]=value end
                for trait in pairs(effect.removedPrinted) do
                    if trait=="defend" then copy[trait]=0
                    else copy[trait]=false end
                end
                entry.data=copy
            end
            local currentlyFortified=combatEnemyFortificationCount(entry.data,entry.perks)>0
                and effect.removeFortify~=true
            local reduction=currentlyFortified and effect.armourReduceFortified
                or effect.armourReduce
            if not currentlyFortified and entry.originalFortification>0 then
                reduction=reduction+(effect.armourBeforeFortificationRemoval or 0)
            end
            if effect.armourReduceByResist>0 then
                local resistances=0
                for _,key in ipairs({"pResist","fResist","iResist"}) do
                    if combatEnemyHasTrait(entry.data,entry.perks,key) then resistances=resistances+1 end
                end
                reduction=reduction+effect.armourReduceByResist*resistances
            end
            -- Taunt's provoke option grants its Armour discount only if the
            -- enemy actually attacks; it can NEVER help in Ranged/Siege.
            local lateReduction=effect.armourReduceAttackOnly or 0
            if lateReduction>0 then
                local attacks=combatEnemyAttacks(entry)
                local attacksNow=false
                for _,attack in ipairs(attacks) do
                    if not attack.pending then attacksNow=true break end
                end
                local noAttack=effect.noAttack==true or effect.destroy==true
                    or (effect.noAttackUnfortified==true
                        and (combatEnemyFortificationCount(entry.data,entry.perks)==0
                            or effect.removeFortify==true))
                if noAttack or not attacksNow then
                    reduction=math.max(0,reduction-lateReduction)
                    lateReduction=0
                end
            end
            entry.effectArmourReduction=reduction
            if reduction>0 then
                -- Curse applies to fortified enemies only in the later Attack
                -- phase. Preserve independent Ranged/Siege Armour, including
                -- reductions from other sources and the minimum of 1.
                local fortified=combatEnemyFortificationCount(entry.data,entry.perks)>0
                    and effect.removeFortify~=true
                local rangedReduction=math.max(0,reduction-lateReduction)
                if fortified then
                    rangedReduction=math.max(0,reduction
                        -(effect.armourReduceRangedUnfortifiedOnly or 0))
                end
                if rangedReduction~=reduction then
                    entry.rangeBaseArmour=math.max(1,entry.baseArmour-rangedReduction)
                    entry.rangeElusiveArmour=math.max(1,entry.elusiveArmour-rangedReduction)
                end
                entry.baseArmour=math.max(1,entry.baseArmour-reduction)
                entry.elusiveArmour=math.max(1,entry.elusiveArmour-reduction)
            end
            entry.stripFortify=effect.removeFortify
            entry.stripResist=effect.removeResist
            entry.stripFireResist=effect.removeFireResist
        end
    end

    return {hasTrait=combatEnemyHasTrait,fortificationCount=combatEnemyFortificationCount,
        resists=combatEnemyResists,attackTotal=combatAttackTotal,
        groupEntry=combatGroupEntry,rangeGroupEntry=combatRangeGroupEntry,
        prepareFortifications=prepareFortifications,applyEffects=applyEffects}
end
end)()

return {attacks=attacks,defences=defences}

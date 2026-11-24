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
        for _,group in ipairs(groups) do
            for _,source in ipairs(group.sources) do
                if not (source.dueling and source.duelingEligible==false
                    and group.category~="block") then
                    for _,attackType in ipairs(combatConfig.attackTypes) do
                        local value=tonumber(source.resources[attackType[group.category]]) or 0
                        if phase=="range" and combatConfig.artifactCombat.bow then
                            local modeR=combatConfig.bowSourceModes[source.key.."#ranged"] or "double"
                            local modeS=combatConfig.bowSourceModes[source.key.."#siege"] or "none"
                            if group.category=="ranged" then
                                if modeR=="siege" then value=0
                                else value=value*2 end
                                if modeS=="ranged" then
                                    value=value+2*(tonumber(source.resources[attackType.siege]) or 0)
                                end
                            elseif group.category=="siege" then
                                if modeS=="ranged" then value=0 end
                                if modeR=="siege" then
                                    value=value+(tonumber(source.resources[attackType.ranged]) or 0)
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

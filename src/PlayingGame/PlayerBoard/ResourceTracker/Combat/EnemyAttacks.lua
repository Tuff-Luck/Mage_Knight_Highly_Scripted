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
        return effect~=nil and (effect.noAttack==true or effect.destroy==true or (effect.noAttackUnfortified==true
            and (combatEnemyFortificationCount(summoned.data,summoned.perks)==0
                or effect.removeFortify==true)))
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

    local function combatApplyAttackReductions(attacks,effect,ownerGUID,chosenAttacks)
        for _,reduction in ipairs(combatOrderedReductions(effect)) do
            local sourceKey=reduction.id or tostring(reduction.source)
            local choice=chosenAttacks~=nil and chosenAttacks[sourceKey] or nil
            local target=choice~=nil and attacks[choice] or nil
            if target~=nil and (target.pending or target.cancelled
                or (ownerGUID~=nil and target.owner~=ownerGUID)) then
                target=nil
            end
            -- Stale selections fall back to the strongest currently legal attack.
            if target==nil then
                for _,attack in ipairs(attacks) do
                    if not attack.pending and not attack.cancelled
                        and (ownerGUID==nil or attack.owner==ownerGUID)
                        and (attack.value>0 or reduction.amount<0
                            or reduction.stripAbilities or reduction.cancelAttack)
                        and (target==nil or attack.value>target.value) then
                        target=attack
                    end
                end
            end
            if target~=nil then
                if reduction.cancelAttack then target.cancelled=true end
                target.value=math.max(0,target.value-reduction.amount)
                if reduction.stripAbilities then
                    for _,trait in ipairs({"swift","brutal","cumbersome","poison",
                        "paralyse","assassination"}) do target[trait]=false end
                    target.abilitiesStripped=true
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
                    convertPreyAttacks(summonedAttacks,summoned.effect)
                    combatApplyAttackReductions(summonedAttacks,summoned.effect,summoned.guid)
                    if summoned.effect~=nil and summoned.effect.grantCumbersome==true then
                        for _,attack in ipairs(summonedAttacks) do
                            if attack.key~="M" and not attack.abilitiesStripped then attack.cumbersome=true end
                        end
                    end
                    for _,attack in ipairs(summonedAttacks) do attacks[#attacks+1]=attack end
                end
            end
            for _=1,math.max(0,#entry.data.monsters-#(entry.summoned or {})) do
                attacks[#attacks+1]={key="P",label="Summon",value=0,block="block",pending=true}
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
                    and not attack.abilitiesStripped then attack.cumbersome=true end
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

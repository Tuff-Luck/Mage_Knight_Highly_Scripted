-- Resolve damage against caller-supplied Units and Hero Armour in printed Attack order.
-- The coordinator owns persistent state, physical wounds and assignment choices.
return function(cardDataOf,summonedBy,fortitudeUses)
    -- Cold Fire only counts as resisted by a Unit with both Fire and Ice resistance. Psychic has no Unit resistance rule.
    local function combatUnitResists(unit,attackKey)
        if attackKey=="IF" then return unit.resist.F==true and unit.resist.I==true end
        return unit.resist[attackKey]==true
    end

    -- items: {key,type,damage,poison,paralyse,assassination} in resolution order; targetsOf(key) lists the Unit GUIDs the player chose.
    local function combatDamageResolve(items,units,heroArmour,targetsOf,mitigation,elementMitigation,ignoreFirstHeroWound,appliedDamage)
        local used,results={},{}
        local firstHeroWoundIgnored=false
        -- Reserve a Unit required to receive its own protected enemy's damage first.
        -- An earlier, unrelated enemy must not consume that Unit before its forced assignment.
        local reserved={}
        for _,item in ipairs(items) do
            local guid=item.firstDamageUnit
            if guid~=nil and units[guid]~=nil and not units[guid].wounded then
                reserved[guid]=item.key
            end
        end
        for _,item in ipairs(items) do
            local remaining=item.damage
            local result={units={},heroWounds=0,discard=0,heroDamage=0,committedDestroyed={}}
            -- After Apply Wounds removes a Paralyzed Unit from the board, that
            -- Unit must still absorb its already-resolved share of this attack.
            -- Otherwise a new scan would incorrectly wound the Hero again.
            local prior=appliedDamage~=nil and appliedDamage[item.key] or nil
            for guid,absorbed in pairs(prior~=nil and prior.destroyed or {}) do
                local value=math.max(0,tonumber(absorbed) or 0)
                remaining=math.max(0,remaining-value)
                result.committedDestroyed[guid]=value
                -- Keep a resolved damage-phase entry for Vampiric Armor, Glory
                -- and other effects that look at which Units were wounded. This
                -- is not a live Unit and must never generate a new wound preview.
                local data=cardDataOf(guid)
                local name=data~=nil and data.name or nil
                result.units[#result.units+1]={
                    unit={guid=guid,name=type(name)=="table" and name[1]
                        or tostring(name or guid)},
                    wounded=true,destroyed=true,alreadyApplied=true,
                    absorbed=value,wounds=1}
            end
            local function assign(guid,forced)
                local unit=units[guid]
                if unit==nil or unit.wounded or used[guid] or remaining<=0
                    or (not forced and reserved[guid]~=nil and reserved[guid]~=item.key) then return end
                used[guid]=true
                local before=remaining
                local entry={unit=unit,wounded=true,resisted=combatUnitResists(unit,item.type),forced=forced}
                local armour=item.type=="M" and unit.level or unit.armour
                if entry.resisted then
                    remaining=remaining-armour
                    if remaining<=0 then entry.wounded,remaining=false,0 end
                end
                if entry.wounded then
                    remaining=math.max(0,remaining-armour)
                    entry.wounds=item.poison and 2 or 1
                    entry.destroyed=item.paralyse==true and unit.arcaneImmunity~=true
                    if unit.fortitudeUsed and unit.fortitudeGUID~=nil then
                        -- Once per Round, on one printed attack; calculator rescans
                        -- of this same attack may preview it without recharging.
                        local uses=fortitudeUses()
                        local prior=uses[unit.fortitudeGUID]
                        if prior==nil or prior.attackKey==item.key then
                            if prior==nil then uses[unit.fortitudeGUID]={attackKey=item.key} end
                            entry.wounded=false
                            entry.wounds=nil
                            entry.destroyed=nil
                            entry.fortitudePrevented=true
                        end
                    end
                end
                if entry.destroyed then entry.absorbed=math.max(0,before-remaining) end
                result.units[#result.units+1]=entry
            end
            -- Shocktroops must take damage first, even against Assassination.
            -- Ordinary voluntary Unit assignments still cannot bypass it.
            if item.firstDamageUnit~=nil then assign(item.firstDamageUnit,true) end
            for _,guid in ipairs(item.assassination and {} or targetsOf(item.key)) do
                if guid~=item.firstDamageUnit then assign(guid,false) end
            end
            if remaining>0 then
                -- Battle Hardened prevents damage to the Hero, not attack points
                -- or Unit damage. Brutal has already doubled item.damage.
                -- One use applies to one printed Attack, even on a multi-attack enemy.
                local sameEnemy=mitigation~=nil and (item.owner==mitigation.owner
                    or summonedBy(item.owner,mitigation.owner))
                if sameEnemy and not mitigation.used
                    and (mitigation.attackKey==nil or mitigation.attackKey==item.key) then
                    local ignored=item.type=="P" and mitigation.physical or mitigation.nonphysical
                    result.prevented=math.min(remaining,ignored)
                    remaining=remaining-result.prevented
                    mitigation.used=true
                    mitigation.appliedKey=item.key
                end
            end
            -- Elemental Resistance is a separate once-per-turn Hero safeguard.
            -- Fire/Ice prevent 2; Cold Fire, Physical and Psychic prevent 1.
            -- Apply after Brutal doubles damage and after Units absorb their share.
            if remaining>0 and elementMitigation~=nil and not elementMitigation.used then
                local sameEnemy=item.owner==elementMitigation.owner
                    or summonedBy(item.owner,elementMitigation.owner)
                if sameEnemy and (elementMitigation.attackKey==nil
                    or elementMitigation.attackKey==item.key) then
                    local ignored=(item.type=="F" or item.type=="I") and 2 or 1
                    result.elementPrevented=math.min(remaining,ignored)
                    remaining=remaining-result.elementPrevented
                    elementMitigation.used=true
                    elementMitigation.appliedKey=item.key
                end
            end
            if remaining>0 then
                result.heroDamage=remaining
                result.heroWounds=math.ceil(remaining/math.max(1,heroArmour))
                if ignoreFirstHeroWound==true and not firstHeroWoundIgnored and result.heroWounds>0 then
                    -- Veil of Mist ignores one hero Wound for the whole turn, not one per attack.
                    -- The ignored Wound also has no Poison/Paralyse side effects.
                    firstHeroWoundIgnored=true
                    result.heroWounds=result.heroWounds-1
                    result.veilWoundIgnored=true
                end
                if item.poison then result.discard=result.heroWounds end
            end
            result.paralyse=item.paralyse==true and result.heroWounds>0
            result.unitWounds=0
            for _,entry in ipairs(result.units) do result.unitWounds=result.unitWounds+(entry.wounded and entry.wounds or 0) end
            results[item.key]=result
        end
        return results
    end

    return {resolve=combatDamageResolve,unitResists=combatUnitResists}
end

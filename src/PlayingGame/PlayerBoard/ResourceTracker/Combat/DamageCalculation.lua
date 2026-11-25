-- Cohesive DamageCalculation services; preserve original lexical and factory boundaries.

-- DamagePreparation
local preparation=(function()
-- Build fresh Damage-phase inputs and selected Hero mitigation records.
-- Physical assignment synchronization and Damage commitment remain with CardRecognition.
return function(skillRuleOf)
    local function build(entries,groups,rowBlock,damageUnits,selfWoundsEarly)
        -- Block 6 (Utem Swordsmen) causes a Wound during Block, before any enemy
        -- damage assignment; do not allow that Unit to absorb an enemy attack.
        for guid in pairs(selfWoundsEarly) do
            if damageUnits[guid]~=nil then damageUnits[guid].wounded=true end
        end
        local damageSpec={attacks={},units={}}
        local damageItems={}
        for guid,unit in pairs(damageUnits) do
            if not unit.wounded then damageSpec.units[guid]=true end
        end
        for _,group in ipairs(groups) do
            if not group.rangeDefeated and not group.destroyed then
                for _,index in ipairs(group.members) do
                    local unblocked=rowBlock[index].unblocked
                    local last=0
                    for attackIndex in pairs(unblocked) do last=math.max(last,attackIndex) end
                    for attackIndex=1,last do
                        local info=unblocked[attackIndex]
                        if info~=nil and info.attack.owner~=nil
                            and not entries[index].rangeDead then
                            local attack=info.attack
                            local item={key=attack.owner..":"..tostring(attack.slot),owner=attack.owner,type=attack.key,
                                damage=info.damage,poison=attack.poison,paralyse=attack.paralyse,
                                assassination=attack.assassination,firstDamageUnit=attack.firstDamageUnit}
                            damageItems[#damageItems+1]=item
                            rowBlock[index].damageItems[attackIndex]=item
                            damageSpec.attacks[#damageSpec.attacks+1]={key=item.key,owner=item.owner,damage=item.damage,
                                assassination=item.assassination,firstDamageUnit=item.firstDamageUnit}
                        end
                    end
                end
            end
        end
        return damageSpec,damageItems
    end

    local function mitigationFor(seatScan,damageItems,state)
        local hardeningRecord=seatScan~=nil and seatScan.cards["0688d8"] or nil
        local hardenedTarget=hardeningRecord~=nil and hardeningRecord.enemyGUID or nil
        local mitigation=nil
        if hardenedTarget~=nil then
            local selected=state~=nil and state.battleHardenedAttackKey or nil
            local available={}
            for _,item in ipairs(damageItems) do
                if item.owner==hardenedTarget
                    or (state~=nil and state.attackedMonsters~=nil
                        and state.attackedMonsters[item.owner]~=nil
                        and state.attackedMonsters[item.owner][3]=="summoned"
                        and state.attackedMonsters[item.owner][4]==hardenedTarget) then
                    available[item.key]=true
                end
            end
            -- An attack that was fully Blocked cannot consume Battle Hardened.
            if selected~=nil and not available[selected] then selected=nil end
            local rule=skillRuleOf("0688d8")
            local spec=rule~=nil and rule.damageMitigation or nil
            if spec~=nil then
                mitigation={owner=hardenedTarget,attackKey=selected,
                    physical=spec.physical or 2,nonphysical=spec.nonphysical or 1}
            end
        end
        local elementRecord=seatScan~=nil and seatScan.cards["ae8673"] or nil
        local elementTarget=elementRecord~=nil and elementRecord.enemyGUID or nil
        local elementMitigation=nil
        if elementTarget~=nil then
            local selected=state~=nil and state.elementalResistanceAttackKey or nil
            local available={}
            for _,item in ipairs(damageItems) do
                if item.owner==elementTarget
                    or (state~=nil and state.attackedMonsters~=nil
                        and state.attackedMonsters[item.owner]~=nil
                        and state.attackedMonsters[item.owner][3]=="summoned"
                        and state.attackedMonsters[item.owner][4]==elementTarget) then
                    available[item.key]=true
                end
            end
            if selected~=nil and not available[selected] then selected=nil end
            elementMitigation={owner=elementTarget,attackKey=selected}
        end
        return mitigation,elementMitigation
    end

    -- Damage resolution can use at most one attack per mitigation effect.
    -- Reuse these recorded values rather than resolving mutable live Units again.
    local function restoreMitigations(results,mitigation,elementMitigation)
        for key,result in pairs(results or {}) do
            if mitigation~=nil and (result.prevented or 0)>0 then
                mitigation.used=true
                mitigation.appliedKey=key
            end
            if elementMitigation~=nil and (result.elementPrevented or 0)>0 then
                elementMitigation.used=true
                elementMitigation.appliedKey=key
            end
        end
    end

    return {build=build,mitigationFor=mitigationFor,restoreMitigations=restoreMitigations}
end
end)()

-- DamageResolution
local resolution=(function()
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
        -- Read committed Banner uses, but reserve new uses only within this preview.
        local reservedFortitude={}
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
                        -- Only the damage commit consumes the once-per-Round use.
                        -- The frozen damage results retain its protection after commit.
                        local guid=unit.fortitudeGUID
                        if fortitudeUses()[guid]==nil and not reservedFortitude[guid] then
                            reservedFortitude[guid]=true
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
end)()

return {preparation=preparation,resolution=resolution}

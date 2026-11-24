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

    return {build=build,mitigationFor=mitigationFor}
end

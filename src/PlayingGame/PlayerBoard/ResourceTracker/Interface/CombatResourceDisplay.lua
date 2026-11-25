-- Prepare grouped numeric and effect-only icon lists before visible rows are rendered.
return function(combatConfig,skillRuleOf,combatDetailPhase,combatEnemyResists,combatGroupResourceRows)
    local function build(entries,groups,allocated,emptyTarget,rowBlock,seatScan,
        woundedBeforeAttack,paralysisAttackCards,damageResults,mitigation,elementMitigation)
        local overflow=0
        -- Build all grouped rows before paging or rendering them. A group can
        -- span pages, and each following member offers two six-icon display lines.
        -- Only the button placement changes; allocated sources stay on their targets.
        local mitigationRecords={}
        for guid,record in pairs(seatScan~=nil and seatScan.cards or {}) do
            local rule=skillRuleOf(guid)
            if rule~=nil and rule.damageMitigation~=nil and record.enemyGUID~=nil then
                mitigationRecords[#mitigationRecords+1]={guid=guid,record=record}
            end
        end
        local displayByIndex={}
        for _,group in ipairs(groups) do
            local perMember={}
            for _,index in ipairs(group.members) do
                local lists={range={},block={},attack={}}
                for _,item in ipairs((allocated[index] or emptyTarget).details) do
                    if item.detail.family=="block" or item.detail.family=="move"
                        or item.detail.family=="influence" then
                        lists.block[#lists.block+1]={source=item.source,amount=item.detail.amount,
                            icon=item.detail.icon,text=item.detail.text,typeKey=item.detail.typeKey,
                            reduced=rowBlock[index].wrongBlock[item.source.key..tostring(item.detail.key)]==true}
                    end
                    if item.detail.family~="block" and item.detail.family~="move"
                        and item.detail.family~="influence" then
                        local phase=combatDetailPhase(item.detail,
                            group.rangeDefeated or group.rangeSpent,group.fortification,item.source)
                        -- Keep invalidated Attack-phase Unit icons visible so players
                        -- can see what was assigned, but make the unavailable value grey
                        -- and explain why it does not count. Earlier Ranged/Block stands.
                        local wounded=phase=="attack" and (woundedBeforeAttack[item.source.guid]==true
                            or item.source.dodgeIneligible==true)
                        local paralysisCard=phase=="attack"
                            and paralysisAttackCards[item.source.guid]==true
                        if phase~=nil then
                            lists[phase][#lists[phase]+1]={source=item.source,amount=item.detail.amount,
                                icon=item.detail.icon,text=item.detail.text,typeKey=item.detail.typeKey,
                                reduced=combatEnemyResists(group.entry.data,group.entry.perks,item.detail.typeKey),
                                wounded=wounded,paralysisCard=paralysisCard,ineffective=paralysisCard}
                        end
                    end
                end
                perMember[index]=lists
            end
            local distributed,hidden=combatGroupResourceRows(group.members,perMember,combatConfig.slotCount)
            for index,lists in pairs(distributed) do displayByIndex[index]=lists end
            overflow=overflow+hidden
            -- Numeric Ranged/Attack sources may flow through joined enemies, but
            -- enemy effects always stay on the row of the enemy they actually target.
            -- Put them first so the control stays visible even when a row is crowded.
            for _,index in ipairs(group.members) do
                local targetEntry=entries[index]
                local lists=displayByIndex[index]
                local function insertEffect(item)
                    if item==nil then return end
                    local buttons=lists[item.family]
                    table.insert(buttons,1,item)
                    if #buttons>combatConfig.slotCount then
                        table.remove(buttons)
                        overflow=overflow+1
                    end
                    combatConfig.effectSources[item.source.key]={arrow=item.arrow,
                        requiresDefence=item.requiresDefence==true}
                end
                for _,applied in ipairs(targetEntry.effect~=nil and targetEntry.effect.applied or {}) do
                    local effectButton=combatConfig.effectButtonInfo(targetEntry,applied)
                    if effectButton~=nil and applied.phaseAfterDamage then
                        effectButton.family="attack"
                        effectButton.tooltip=(effectButton.tooltip or "")
                            .."\nPlayed after Damage; Ranged/Siege and Block are locked."
                    end
                    insertEffect(effectButton)
                end
                -- The extra target from Explosive Bolt is an Armour effect, not
                -- more Ranged Attack. Red/grey states explain unmet conditions.
                for _,bolt in ipairs(targetEntry.explosiveBoltEffects or {}) do
                    insertEffect({source={guid=bolt.guid,key=bolt.key,name="Explosive Bolt"},
                        family="attack",arrow="other",requiresDefence=true,amount="-"..tostring(bolt.earned),
                        icon="MKChoiceArmourReduction",
                        text="Armour -"..tostring(bolt.earned).." after Ranged defeat (min 1)",
                        tooltip="Explosive Bolt: "..(bolt.reason or
                            ("Applied Armour reduction: "..tostring(bolt.applied)))
                            .."\nClick to retarget this effect separately from its Ranged Attack.",
                        ineffective=bolt.reason~=nil})
                end
                -- Damage mitigation is a Block-column control, but not Block points.
                for _,mitigationSource in ipairs(mitigationRecords) do
                    if mitigationSource.record.enemyGUID==targetEntry.guid then
                        insertEffect(combatConfig.mitigationButtonInfo(mitigationSource.guid,
                            mitigationSource.record,targetEntry,group,damageResults,
                            mitigationSource.guid=="ae8673" and elementMitigation or mitigation))
                    end
                end
            end
        end
        return displayByIndex,overflow
    end
    return build
end

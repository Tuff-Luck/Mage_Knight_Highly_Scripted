-- Render visible resource slots and final combat result rows from resolved phase data.
return function(combatConfig,combatPanelSetAttribute,combatAssignmentIconButton,
    combatEnemyHasTrait,combatGroupTraitsText,combatEnemyAttacks,combatTypeRich,
    combatNatureVengeanceBlockBonus,combatRich,combatDamageNotes,combatGroupAttackLine,
    combatCompactResultLines,tokenOf,profiler)
    -- XML rows and slots are fixed for the lifetime of the renderer.
    local families={"range","block","attack"}
    local emptyItems={}
    local ids={}
    for row=1,combatConfig.rowCount do
        local prefix="CombatEnemyRow"..row
        local rowIDs={row=prefix,armour=prefix.."Armour",traits=prefix.."Traits",
            attacks=prefix.."Attacks",offence=prefix.."Offence",result=prefix.."Result",
            cycle="CombatEnemyAttackCycle"..row,resultToggle="CombatEnemyResultToggle"..row,
            grids={},cells={},slots={}}
        ids[row]=rowIDs
        for _,family in ipairs(families) do
            rowIDs.grids[family]="CombatSourceGrid"..row..family
            rowIDs.cells[family]="CombatSourceCell"..row..family
            local slots={}
            rowIDs.slots[family]=slots
            for slot=1,combatConfig.slotCount do
                slots[slot]="CombatSourceSlot"..row..family..slot
            end
        end
    end
    local previous={}
    local attributeCache
    local function render(entries,groupOf,rowBlock,displayByIndex,seatScan,damageResults,knockout,
        pageOffset,visibleRows,shownTraits,shownOffence,shownAttacks,colUsed,maxResourceCounts,
        combatAssignmentSlotSources,combatAssignmentState,combatReductionAttackChoice,
        combatExpandedResults,combatAttackChoiceByRow,bossManual,totalRowHeight)
        local tracing=profiler~=nil and profiler.traceEnabled
        -- A replaced UI attribute cache requires a complete initial reconciliation.
        local currentCache=profiler~=nil and profiler.combatPanelAttributes or nil
        if currentCache~=attributeCache then previous={} attributeCache=currentCache end
        for row=1,combatConfig.rowCount do
            local index=pageOffset+row
            local entry=row<=visibleRows and entries[index] or nil
            local prior=previous[row]
            if entry~=nil or prior==nil or prior.visible then
                local iconProfile
                if tracing then iconProfile=profiler.profileStart() end
                local rowIDs=ids[row]
                local group=entry~=nil and groupOf[index] or nil
                -- Never populate a hidden row with an enemy from the next page.
                local lists=entry~=nil and displayByIndex[index] or nil
                local counts={}
                local resourceLines=1
                for _,family in ipairs(families) do
                    local items=lists~=nil and lists[family] or emptyItems
                    if entry~=nil and #items>0 then
                        colUsed[family]=true
                        maxResourceCounts[family]=math.max(maxResourceCounts[family],#items)
                        resourceLines=math.max(resourceLines,math.ceil(#items/combatConfig.lineSlotCount))
                    end
                    -- Collapse the second icon line completely when unused. The Grid is
                    -- anchored to the cell's centre, so tall text rows don't strand
                    -- their one-line icons against the top of the enemy row.
                    local gridID=rowIDs.grids[family]
                    local gridHeight=math.ceil(#items/combatConfig.lineSlotCount)*26
                    combatPanelSetAttribute(gridID,"height",tostring(gridHeight))
                    combatPanelSetAttribute(gridID,"preferredHeight",tostring(gridHeight))
                    local occupied=math.min(#items,combatConfig.slotCount)
                    counts[family]=occupied
                    -- First render clears all XML slots. Later renders only visit
                    -- occupied slots and the tail of slots that just became empty.
                    local limit=math.max(occupied,prior~=nil and prior.counts[family] or combatConfig.slotCount)
                    for slot=1,limit do
                        local id=rowIDs.slots[family][slot]
                        local item=items[slot]
                        if item~=nil then
                            combatAssignmentSlotSources[id]=item.source.key
                            combatConfig.slotBowFamilies[id]=item.detail~=nil
                                and (item.detail.family=="ranged" or item.detail.family=="siege")
                                and item.detail.family or nil
                            combatConfig.slotSelection[id]={key=item.source.key,
                                wounded=item.wounded,ineffective=item.ineffective}
                            local tooltipProfile
                            if tracing then tooltipProfile=profiler.profileStart() end
                            local tooltip=item.tooltip or (item.source.name..": "..item.text
                                ..(item.source.dodgeIneligible and
                                    " unavailable: the Hero took Wounds before the Attack phase"
                                    or (item.wounded and " can't apply 'Wounded'" or "")))
                            -- Cold Toughness's powered icon bonus is automatic. Explain
                            -- its printed Arcane Immunity exception on the Block source icon.
                            local coldToughness=seatScan~=nil and seatScan.cards["79bfbd"] or nil
                            if item.source.guid=="79bfbd" and item.typeKey=="I"
                                and coldToughness~=nil and coldToughness.powered==true then
                                local printedEnemy=entry~=nil and tokenOf(entry.guid) or nil
                                if printedEnemy~=nil and printedEnemy.arcaneImmunity==true then
                                    tooltip=tooltip.."\nCold Toughness: Ice Block 5 + 0 icon bonus (Arcane Immunity)."
                                else
                                    tooltip=tooltip.."\nCold Toughness: Ice Block 5 + 1 per printed enemy ability, attack type or resistance icon (automatic)."
                                end
                            end
                            if item.paralysisCard then
                                tooltip=tooltip.."\n"
                                    ..(knockout and "Knockout" or "Paralysis")
                                    ..": the Hero discards non-Wound cards before Attack."
                                    .." This planned card Attack does not count."
                            end
                            local bowFamily=combatConfig.slotBowFamilies[id]
                            if bowFamily~=nil and combatConfig.artifactCombat.bow then
                                local bowMode=combatConfig.bowSourceModes[
                                    item.source.key.."#"..bowFamily]
                                    or (bowFamily=="ranged" and "double" or "none")
                                local description=bowFamily=="ranged"
                                    and (bowMode=="siege" and "Convert to Siege (same value)"
                                        or "Double Ranged")
                                    or (bowMode=="ranged" and "Double and convert to Ranged"
                                        or "Keep original Siege")
                                tooltip=tooltip.."\nBow of Starsdawn: "..description
                                    ..". Right-click this source icon to switch."
                            end
                            if item.source.phaseLocked then
                                tooltip=tooltip.."\nLocked by Commit Damage. Use TTS Rewind to change."
                            end
                            if tooltipProfile~=nil then profiler.profileFinish("renderer.tooltip",tooltipProfile) end
                            combatAssignmentIconButton(id,true,item.amount,item.icon,
                                tooltip,combatAssignmentState.selected==item.source.key,
                                (item.typeKey~=nil
                                    and combatConfig.typeColors[item.typeKey][item.reduced and 2 or 1] or nil),
                                item.wounded,item.ineffective)
                            combatPanelSetAttribute(id,"interactable",
                                item.source.phaseLocked and "false" or "true")
                        else
                            combatAssignmentIconButton(id,false,0,"","",false)
                        end
                    end
                end
                if iconProfile~=nil then iconProfile=profiler.profileCheckpoint("renderer.iconSlots",iconProfile) end
                local merged=group~=nil and #group.members>1
                for _,family in ipairs({"range","attack"}) do
                    combatPanelSetAttribute(rowIDs.cells[family],"color",
                        merged and "rgba(1,1,1,0.10)" or "rgba(0,0,0,0)")
                end
                local rowHeight=math.max(combatConfig.rowHeight,resourceLines*26+4)
                if entry~=nil and group~=nil then
                    -- Final armour for the current layout: Elusive doubles unless every attack is blocked.
                    local armourValue=entry.baseArmour
                    if combatEnemyHasTrait(entry.data,entry.perks,"elusive") and not rowBlock[index].allBlocked then
                        armourValue=entry.elusiveArmour
                    end
                    combatPanelSetAttribute(rowIDs.armour,"text",
                        (entry.destroyed or entry.attackOnly) and "-" or tostring(armourValue))
                    -- Use actual modified defenses even on a single enemy (Sorcerers,
                    -- stripped fortification, and other effects may change them).
                    local sharedText=combatGroupTraitsText(entry,group.entry)
                    shownTraits[row]=sharedText
                    combatPanelSetAttribute(rowIDs.traits,"text",sharedText)
                    entry.attackCount=math.max(entry.attackCount or 1,select(2,sharedText:gsub("\n",""))+1)
                    -- An enemy defeated before the Block phase has no attack or
                    -- offensive abilities to resolve, even if its printed token has them.
                    local noEnemyAttack=group.rangeDefeated or entry.rangeDead
                        or group.destroyed or entry.destroyed
                    local attacks=combatEnemyAttacks(entry)
                    local attackLines={}
                    if not noEnemyAttack then
                        for attackIndex,attack in ipairs(attacks) do
                            local reduction=rowBlock[index].reductions[attackIndex] or 0
                            local markers={}
                            local selections=combatReductionAttackChoice[entry.guid] or {}
                            for rank,effect in ipairs(entry.attackReductions) do
                                if selections[effect.id or tostring(effect.source)]==attackIndex then
                                    markers[#markers+1]=tostring(rank)
                                end
                            end
                            attackLines[#attackLines+1]=(#markers>0 and ("▶"..table.concat(markers,",").." ") or "")
                                ..combatTypeRich(attack.label.." "..tostring(attack.value-reduction)
                                    ..(combatNatureVengeanceBlockBonus()>0 and " (Block +1)" or ""),
                                    attack.key,reduction>0)
                        end
                    end
                    local attackText=noEnemyAttack and ""
                        or (#attackLines>0 and table.concat(attackLines,"\n") or "-")
                    shownAttacks[row]=attackText
                    combatPanelSetAttribute(rowIDs.attacks,"text",attackText)
                    if noEnemyAttack then
                        shownOffence[row]=""
                        combatPanelSetAttribute(rowIDs.offence,"text","")
                        combatPanelSetAttribute(rowIDs.cycle,"active","false")
                        -- Removed attack lines must not leave extra empty height.
                        entry.attackCount=math.max(1,select(2,sharedText:gsub("\n",""))+1)
                    end
                    local lines={}
                    local isLast=group.members[#group.members]==index
                    if group.destroyed then
                        lines[1]=combatRich("Destroyed",combatConfig.COMBAT_GREEN)
                    elseif entry.rangeDead then
                        lines[1]=combatRich("Ranged defeated",combatConfig.COMBAT_GREEN)
                    elseif group.rangeDefeated then
                        -- Group results sit under the last enemy of the group.
                        if isLast then
                            lines[1]=combatRich("Ranged "..tostring(group.rangeTotal).."/"..tostring(group.rangeArmour)
                                .." Defeated",combatConfig.COMBAT_GREEN)
                        end
                    else
                        -- Keep each source's Block status and wound distribution together.
                        for lineIndex,line in ipairs(rowBlock[index].lines) do
                            local item=rowBlock[index].damageItems[lineIndex]
                            local attack=attacks[lineIndex]
                            if attack~=nil and not attack.pending then
                                local value=math.max(0,attack.value-(rowBlock[index].reductions[lineIndex] or 0))
                                line=attack.label.." "..tostring(value)..": "..line
                            end
                            lines[#lines+1]=line
                            if item~=nil then
                                for _,note in ipairs(combatDamageNotes(item,damageResults[item.key])) do
                                    lines[#lines+1]=note
                                end
                            elseif rowBlock[index].lines[lineIndex]:find("Blocked",1,true) then
                                lines[#lines+1]="Wounds: None"
                            end
                        end
                        if entry.attackPhaseDestroyed and not entry.attackOnly then
                            lines[#lines+1]=combatRich("Destroyed in Attack",combatConfig.COMBAT_GREEN)
                        end
                        if isLast and not entry.attackOnly then
                            if group.bossSpecial then
                                if group.attackTotal>0 then
                                    lines[#lines+1]="Attack "..tostring(group.attackTotal).." (level attack)"
                                end
                            else
                                local line=combatGroupAttackLine(group.attackTotal,group.attackArmour)
                                if line~=nil then lines[#lines+1]=line end
                            end
                        end
                    end
                    if entry.bossType=="control" then
                        lines[#lines+1]="Control: cannot be attacked"
                    elseif entry.bossLevel~=nil then
                        local ranged,melee=entry.bossRangeLevels or 0,entry.bossAttackLevels or 0
                        local manual=bossManual~=nil and bossManual[entry.guid]~=nil
                        lines[#lines+1]="Levels: -"..tostring(ranged+melee).."/"..tostring(entry.bossLevel)
                            .." (R "..tostring(ranged)..", A "..tostring(melee)..")"
                            ..(manual and (group.bossSpecial and #group.members>1
                                and " [Manual priority]" or " [Manual]") or "")
                    end
                    local compactLines=combatCompactResultLines(lines,rowBlock[index].damageItems,damageResults)
                    local detailText=table.concat(lines,"\n")
                    local compactText=table.concat(compactLines,"\n")
                    local hasDetails=detailText~=compactText
                    local expanded=hasDetails and combatExpandedResults[entry.guid]==true
                    local displayText=expanded and detailText or compactText
                    if hasDetails then displayText=displayText..(expanded and " [-]" or " [+]") end
                    -- Only explicit newlines take vertical space; Result text may overflow horizontally.
                    local displayLines=expanded and #lines or #compactLines
                    local minHeight=rowHeight
                    rowHeight=math.max(rowHeight,math.max(displayLines,entry.attackCount or 1)*15+4)
                    -- Only the Result text and its row/panel heights change when expanded.
                    combatConfig.resultRowCache[row]={guid=entry.guid,detailText=detailText,
                        compactText=compactText,hasDetails=hasDetails,detailLines=#lines,
                        compactLines=#compactLines,minHeight=minHeight,rowHeight=rowHeight,
                        attackCount=entry.attackCount or 1}
                    local resultID=rowIDs.result
                    combatPanelSetAttribute(resultID,"text",displayText)
                    combatPanelSetAttribute(rowIDs.resultToggle,"tooltip","")
                    combatPanelSetAttribute(resultID,"fontSize","12")
                    combatPanelSetAttribute(resultID,"font","Fonts/MKCardText")
                    combatPanelSetAttribute(resultID,"color","White")
                    totalRowHeight=totalRowHeight+rowHeight
                end
                combatPanelSetAttribute(rowIDs.row,"preferredHeight",tostring(rowHeight))
                if entry==nil then
                    combatAttackChoiceByRow[row]=nil
                    combatPanelSetAttribute(rowIDs.cycle,"active","false")
                end
                if iconProfile~=nil then profiler.profileFinish("renderer.resultText",iconProfile) end
                previous[row]={visible=entry~=nil,counts=counts}
            else
                combatAttackChoiceByRow[row]=nil
            end
        end
        return totalRowHeight
    end
    return render
end

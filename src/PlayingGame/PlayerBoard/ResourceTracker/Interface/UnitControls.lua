-- Render Unit-specific choice and targeting buttons; no ownership of activation,
-- combat assignment, or lifecycle state. Read current flags and cache tables per call.
return function(deps)
    local combatConfig=deps.combatConfig
    local choiceLetters=deps.choiceLetters
    local removeChoiceButtons=deps.removeChoiceButtons
    local unitHistorySelectedNumber=deps.unitHistorySelectedNumber
    local unitManaDecision=deps.unitManaDecision
    local unitHistoryIsCombatAbility=deps.unitHistoryIsCombatAbility
    local unitAbilityTargetCategory=deps.unitAbilityTargetCategory
    local unitHistoryKey=deps.unitHistoryKey
    local resourceCardsMoveRole=deps.resourceCardsMoveRole
    local resourceCardsHideAutomaticEnemyTarget=deps.resourceCardsHideAutomaticEnemyTarget
    local unitAbilityTargetKey=deps.unitAbilityTargetKey
    local resourceObjectUiXmlTable=deps.resourceObjectUiXmlTable
    local resourceCardsChoiceAssetsFor=deps.resourceCardsChoiceAssetsFor
    local resourceCardsChoiceIcon=deps.resourceCardsChoiceIcon
    local resourceObjectUiSetTable=deps.resourceObjectUiSetTable

    local function showUnitAbilityButtons(unit,abilities,activation,unwounded,decision,useIndex)
        local choiceButtonShown,choiceExpandedByGUID,combatCalcOn,combatPsychicActive,combatCumbersomeActive=deps.getContext()
        if unit==nil then return end
        if combatConfig~=nil and combatConfig.phaseObjectLocked~=nil
            and combatConfig.phaseObjectLocked(unit.guid) then
            removeChoiceButtons(unit)
            choiceButtonShown[unit.guid]="hidden"
            return
        end
        useIndex=useIndex or unitHistorySelectedNumber(unit.guid)
        if not unwounded or activation==nil or abilities==nil or #abilities==0 then
            removeChoiceButtons(unit)
            choiceExpandedByGUID[unit.guid]=nil
            return
        end
        local decision=decision or unitManaDecision(unit,abilities,activation,
            activation.frozenCounts)
        local available=decision.display
        local combatBlocked=combatConfig.unitCombatBlocked~=nil
            and combatConfig.unitCombatBlocked(unit,abilities,useIndex) or false
        local targetSpecs={}
        do
            local function addTarget(index)
                local ability=abilities[index]
                if ability==nil or (combatBlocked and unitHistoryIsCombatAbility(ability)) then return end
                if ability.key=="ready" then
                    targetSpecs[#targetSpecs+1]={index=index,category="unitReady",
                        idCategory="unitReady"..(useIndex>1 and ("@use"..useIndex) or ""),
                        ready=true}
                    return
                end
                local category=unitAbilityTargetCategory(ability)
                local numericKey=unitHistoryKey(unit.guid,useIndex)
                if category=="move" and resourceCardsMoveRole(numericKey,false)~="combat" then
                    category=nil
                end
                if category~=nil and not resourceCardsHideAutomaticEnemyTarget(
                    numericKey,category,false) then
                    targetSpecs[#targetSpecs+1]={index=index,category=category,
                        idCategory=category..(useIndex>1 and ("@use"..useIndex) or "")}
                end
                if combatCalcOn and (ability.enemyEffect~=nil
                    or (category==nil and ability.targetableEnemy==true))
                    and not resourceCardsHideAutomaticEnemyTarget(
                        unitAbilityTargetKey(unit.guid,index,ability,useIndex),
                        "effect",ability.enemyEffect~=nil and ability.targetableEnemy~=true) then
                    targetSpecs[#targetSpecs+1]={index=index,category="effect",
                        idCategory="effect@"..(useIndex>1 and ("use"..useIndex.."#") or "")
                            .."effect"..index}
                end
            end
            if abilities.multi==true then
                for index in ipairs(abilities) do
                    if decision.selected~=nil and decision.selected[index]==true then addTarget(index) end
                end
            elseif decision.index~=nil then
                addTarget(decision.index)
            end
        end
        local hasMoveAbility=false
        for _,index in ipairs(available) do
            if (tonumber(abilities[index]~=nil and abilities[index].move) or 0)>0 then
                hasMoveAbility=true
                break
            end
        end
        local hasChoices=#available>=2 or decision.ambiguous or hasMoveAbility
        if not hasChoices and #targetSpecs==0 then
            if choiceButtonShown[unit.guid]~="hidden" then
                removeChoiceButtons(unit)
                choiceButtonShown[unit.guid]="hidden"
            end
            choiceExpandedByGUID[unit.guid]=nil
            return
        end
        local selected=decision.index
        -- Move is a normal Unit choice, not an automatic reason to expand every
        -- option. When selected, its Movement/Combat controls are drawn separately.
        -- An unresolved paid choice may still require an expanded selection.
        local expanded=(decision.ambiguous and decision.index==nil and not abilities.paidChoiceExpandable)
            or (choiceExpandedByGUID[unit.guid]==true and #available>1)
        local selectedKeys={}
        for i in pairs(decision.selected or {}) do selectedKeys[#selectedKeys+1]=tostring(i) end
        table.sort(selectedKeys)
        local targetLabels={}
        if not expanded then
            for _,spec in ipairs(targetSpecs) do targetLabels[#targetLabels+1]=spec.idCategory end
        end
        local combatMoveAvailable=combatConfig.moveRoleAvailable(unitHistoryKey(unit.guid,useIndex))==true
        local signature="Unit:"..tostring(selected)..":"..tostring(expanded)
            ..":"..table.concat(available,",")..":"..table.concat(selectedKeys,",")
            ..":use="..tostring(useIndex)
            ..":move="..resourceCardsMoveRole(unitHistoryKey(unit.guid,useIndex),false)
            ..":combatMove="..tostring(combatMoveAvailable)
            ..":cumbersome="..tostring(combatCalcOn and combatCumbersomeActive)
            ..":psychic="..tostring(combatPsychicActive)
            ..":combatBlocked="..tostring(combatBlocked)
            ..":targets="..table.concat(targetLabels,",")
        local xml=resourceObjectUiXmlTable(unit.UI)
        if choiceButtonShown[unit.guid]==signature then
            -- TTS object UI is applied asynchronously. After a Call Offer switch,
            -- the scan may have cached this signature before the buttons really
            -- appeared on the moving Unit. Recreate only missing controls.
            local needed={}
            if hasChoices then
                for _,index in ipairs(expanded and available or {selected or available[1]}) do
                    needed["ResourceCardChoice_"..unit.guid.."_unit"..index]=true
                    if combatMoveAvailable
                        and (tonumber(abilities[index]~=nil and abilities[index].move) or 0)>0 then
                        needed["ResourceCardChoice_"..unit.guid.."_unit"..index.."Combat"]=true
                    end
                end
            end
            if #targetLabels>0 then
                for _,spec in ipairs(targetSpecs) do
                    needed["AttackAssignmentSource_"..unit.guid.."_0_"..spec.idCategory]=true
                end
            end
            for _,node in ipairs(xml) do
                local id=node.attributes~=nil and node.attributes.id or nil
                if id~=nil then needed[id]=nil end
            end
            if next(needed)==nil then return end
        end

        for i=#xml,1,-1 do
            local attr=xml[i].attributes
            if attr~=nil and type(attr.id)=="string"
                and (attr.id:sub(1,19)=="ResourceCardChoice_"
                    or attr.id:find("^AttackAssignmentSource_")~=nil) then table.remove(xml,i) end
        end
        local visibleAssets,seen={},{}
        local displayed=hasChoices and (expanded and available or {selected or available[1]}) or {}
        for _,index in ipairs(displayed) do
            local ability=abilities[index]
            local name=ability.icon or ability.key
            if not seen[name] then visibleAssets[#visibleAssets+1]=name seen[name]=true end
        end
        -- Unit Move has the same shield/Move choice as Action cards; Psychic
        -- Influence shares the shield/Influence treatment when relevant.
        for _,index in ipairs(displayed) do
            local ability=abilities[index]
            if (combatMoveAvailable and (tonumber(ability.move) or 0)>0)
                or (combatPsychicActive and ability.key=="influence"
                    and (tonumber(ability.influence) or 0)>0) then
                if not seen.block then visibleAssets[#visibleAssets+1]="block" seen.block=true end
                if not seen.move and (tonumber(ability.move) or 0)>0 then
                    visibleAssets[#visibleAssets+1]="move" seen.move=true
                end
                if not seen.influence and combatPsychicActive
                    and ability.key=="influence" then
                    visibleAssets[#visibleAssets+1]="influence" seen.influence=true
                end
            end
        end
        if #targetLabels>0 then visibleAssets[#visibleAssets+1]="target" end
        local assets,blocked=resourceCardsChoiceAssetsFor(unit.UI,visibleAssets)

        -- Shared printed rows keep a stable vertical slot; all sub-options start
        -- at the centre column and grow only to the right.
        local rows,rowByKey={},{}
        if expanded then
            for _,i in ipairs(displayed) do
                local ability=abilities[i]
                local key=ability.row or i
                if rowByKey[key]==nil then
                    rowByKey[key]={}
                    rows[#rows+1]=rowByKey[key]
                end
                rowByKey[key][#rowByKey[key]+1]=i
            end
        elseif hasChoices then
            rows={{displayed[1]}}
        end

        -- Fixed lower-left anchor works independently of translated text.
        -- The 180-degree UI rotation reverses the screen-space axes, so the
        -- first printed ability takes negative Y (above) and extra alternatives
        -- take negative X (to the screen-right of their primary option).
        -- Shift by one rendered Unit-button width (90 * 0.22) farther left.
        local baseX,baseY=91.8,80
        -- Button footprint is 90 * 0.22 = 19.8 UI units. Halve the
        -- *empty gap* (not the centre spacing) so neighbouring buttons
        -- remain separate and clickable: 34 -> 26.9, 35 -> 27.4.
        local rowSpacing=26.9
        local columnSpacing=27.4
        for rowIndex,indices in ipairs(rows) do
            local y=baseY+(rowIndex-(#rows+1)/2)*rowSpacing
            for columnIndex,index in ipairs(indices) do
                local ability=abilities[index]
                local active=decision.selected~=nil and decision.selected[index]==true
                    or decision.selected==nil and index==selected
                local invalidCombat=active and combatBlocked
                    and unitHistoryIsCombatAbility(ability)
                local icon=resourceCardsChoiceIcon(ability.icon or ability.key)
                if icon~=nil and blocked[icon.name] then icon=nil end
                local button={tag="Button",attributes={
                    id="ResourceCardChoice_"..unit.guid.."_unit"..index,
                    onClick="global/resourceUnitsChoiceClicked",
                    position=tostring(baseX-(columnIndex-1)*columnSpacing).." "..tostring(y).." -35",
                    rotation="0 0 180",width=90,height=90,scale="0.22 0.22",
                    colors=invalidCombat and "#9C3737|#B34A4A|#9C3737|#9C3737"
                        or active and "#387D30|#4CA940|#387D30|#387D30"
                        or "#454D5D|#69798E|#444C63|#454D5D",
                    fontSize=77,textColor="#FFFFFF",textAlignment="MiddleCenter"
                },value=icon==nil and (ability.buttonLabel
                    or (ability.key=="other" and tostring(ability.row))
                    or choiceLetters[ability.key] or "?") or ""}
                if icon~=nil then
                    button.children={{tag="Image",attributes={
                        image=icon.name,width=82,height=82,preserveAspect="true",
                        raycastTarget="false",color="#FFFFFF"}}}
                    if combatPsychicActive and ability.key=="influence"
                        and (tonumber(ability.influence) or 0)>0 then
                        local shield=resourceCardsChoiceIcon("block")
                        local influence=resourceCardsChoiceIcon("influence")
                        if shield~=nil and influence~=nil
                            and not blocked[shield.name] and not blocked[influence.name] then
                            button.children={{tag="Image",attributes={
                                image=shield.name,width=82,height=82,preserveAspect="true",
                                raycastTarget="false",color="#FFFFFF"}},
                                {tag="Image",attributes={image=influence.name,width=82,height=82,
                                    preserveAspect="true",raycastTarget="false",color="#FFFFFF"}}}
                        end
                    end
                    if ability.iconOverlay~=nil then
                        button.children[#button.children+1]={tag="Text",attributes={
                            text=ability.iconOverlay,width=82,height=82,
                            alignment="MiddleCenter",fontSize=62,fontStyle="Bold",
                            color=ability.iconOverlayColor or "#FF564A",
                            outline="#1C1514",outlineSize="2 -2",
                            raycastTarget="false"}}
                    end
                end
                if (tonumber(ability.move) or 0)>0 then
                    local phase=resourceCardsMoveRole(unitHistoryKey(unit.guid,useIndex),false)
                    -- The regular button becomes the Movement variant; the
                    -- adjacent C variant is a normal, equally-sized option cell.
                    local isMovement=phase~="combat"
                    button.attributes.colors=active and isMovement
                        and "#387D30|#4CA940|#387D30|#387D30"
                        or "#454D5D|#69798E|#444C63|#454D5D"
                    button.children=button.children or {}
                    button.children[#button.children+1]={tag="Text",attributes={
                        text="M",width=34,height=34,alignment="LowerRight",
                        fontSize=37,fontStyle="Bold",color="#9AFFA4",
                        outline="#101820",outlineSize="2 -2",raycastTarget="false"}}
                    if combatMoveAvailable then
                        local combatButton={tag="Button",attributes={
                        id="ResourceCardChoice_"..unit.guid.."_unit"..index.."Combat",
                        onClick="global/resourceUnitsChoiceClicked",
                        position=tostring(baseX-(#indices+columnIndex-1)*columnSpacing)
                            .." "..tostring(y).." -35",
                        rotation="0 0 180",width=90,height=90,scale="0.22 0.22",
                        colors=active and not isMovement
                            and "#387D30|#4CA940|#387D30|#387D30"
                            or "#454D5D|#69798E|#444C63|#454D5D",
                        fontSize=77,textColor="#FFFFFF",textAlignment="MiddleCenter"},
                        value="C"}
                    local shield=resourceCardsChoiceIcon("block")
                    local movement=resourceCardsChoiceIcon("move")
                    if combatCalcOn and combatCumbersomeActive and shield~=nil and not blocked[shield.name] then
                        combatButton.value=""
                        combatButton.children={{tag="Image",attributes={
                            image=shield.name,width=82,height=82,preserveAspect="true",
                            raycastTarget="false",color="#FFFFFF"}}}
                        if movement~=nil and not blocked[movement.name] then
                            combatButton.children[#combatButton.children+1]={tag="Image",attributes={
                                image=movement.name,width=82,height=82,
                                preserveAspect="true",raycastTarget="false",color="#FFFFFF"}}
                        else
                            combatButton.children[#combatButton.children+1]={tag="Text",attributes={
                                text="M",width=34,height=34,alignment="LowerRight",
                                fontSize=37,fontStyle="Bold",color="#69AEFF",
                                raycastTarget="false"}}
                        end
                    elseif icon~=nil then
                        -- Without Cumbersome use the Move icon with a C badge.
                        combatButton.value=""
                        combatButton.children={{tag="Image",attributes={
                            image=icon.name,width=82,height=82,preserveAspect="true",
                            raycastTarget="false",color="#FFFFFF"}},
                            {tag="Text",attributes={text="C",width=34,height=34,
                                alignment="LowerRight",fontSize=37,fontStyle="Bold",
                                color="#69AEFF",outline="#101820",
                                outlineSize="2 -2",raycastTarget="false"}}}
                    end
                        xml[#xml+1]=button
                        xml[#xml+1]=combatButton
                    else
                        xml[#xml+1]=button
                    end
                else
                    xml[#xml+1]=button
                end
            end
        end
        if #targetLabels>0 then
            local count=#targetSpecs
            for i,spec in ipairs(targetSpecs) do
                local targetAsset=resourceCardsChoiceIcon("target")
                local selectedMove=selected~=nil and (tonumber(abilities[selected].move) or 0)>0
                local choiceColumns=hasChoices and (selectedMove and combatMoveAvailable and 2 or 1) or 0
                local x=baseX-choiceColumns*columnSpacing
                local y=baseY+(i-(count+1)/2)*rowSpacing
                local children={}
                if targetAsset~=nil and not blocked[targetAsset.name] then
                    children={{tag="Image",attributes={image=targetAsset.name,
                        width=82,height=82,preserveAspect="true",raycastTarget="false",color="#FFFFFF"}}}
                end
                -- R (Ranged) and E (enemy effect) label independent targets
                -- without relying on unsupported object-attached tooltips.
                if count==2 and targetSpecs[1].index==targetSpecs[2].index then
                    children[#children+1]={tag="Text",attributes={
                        text=spec.category=="effect" and "E" or "R",
                        width=38,height=38,fontSize=35,alignment="LowerRight",
                        color="#FFFFFF",outline="#141820",outlineSize="2 -2",
                        raycastTarget="false"}}
                end
                xml[#xml+1]={tag="Button",attributes={
                    id="AttackAssignmentSource_"..unit.guid.."_0_"..spec.idCategory,
                    onClick=spec.ready and "global/attackAssignmentReadySourceClicked"
                        or "global/attackAssignmentSourceClicked",
                    position=tostring(x).." "..tostring(y).." -35",
                    rotation="0 0 180",width=90,height=90,scale="0.22 0.22",
                    colors="#454D5D|#69798E|#444C63|#454D5D",textColor="#FFFFFF",
                    textAlignment="MiddleCenter"
                },value="",children=children}
            end
        end
        resourceObjectUiSetTable(unit.UI,xml,assets)
        choiceButtonShown[unit.guid]=signature
    end


    return showUnitAbilityButtons
end

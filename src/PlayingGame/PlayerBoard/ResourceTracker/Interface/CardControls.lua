-- Card/Skill object controls. Coordinator retains gameplay, click handlers and state.
-- Read the current shared cache tables, combat flags and game state on every draw.
return function(deps)
    local trackerPrivate=deps.trackerPrivate
    local combatConfig=deps.combatConfig
    local choiceLetters=deps.choiceLetters
    local removeChoiceButtons=deps.removeChoiceButtons
    local cardPosture=deps.cardPosture
    local resourceCardsDetailsOpen=deps.resourceCardsDetailsOpen
    local resourceObjectUiXmlTable=deps.resourceObjectUiXmlTable
    local resourceObjectUiSameXML=deps.resourceObjectUiSameXML
    local resourceObjectUiSetTable=deps.resourceObjectUiSetTable
    local resourceCardsArtifactBroken=deps.resourceCardsArtifactBroken
    local cardCanPlaySideways=deps.cardCanPlaySideways
    local combatHardenedAttackOptions=deps.combatHardenedAttackOptions
    local combatAssignmentActiveSeat=deps.combatAssignmentActiveSeat
    local resourceCardsChoiceAssetsFor=deps.resourceCardsChoiceAssetsFor
    local resourceChoiceColumn=deps.resourceChoiceColumn
    local skillChoicePositions=deps.skillChoicePositions
    local resourceCardsChoiceIcon=deps.resourceCardsChoiceIcon
    local combatEffectSpec=deps.combatEffectSpec
    local currentChoice=deps.currentChoice
    local choiceCategory=deps.choiceCategory
    local inventorySetChoice=deps.inventorySetChoice

    local function showChoiceButtons(card,choices,powered,inventorySpec,inventorySets,resources,repeatLink)
        local choiceButtonShown,choiceExpandedByGUID,combatAssignmentState,
            combatCalcOn,combatCumbersomeActive,combatPsychicActive,combatEnemyInPlay,
            gameCards,cardResourceDefinitions,skillResourceDefinitions,skillTokens,
            gStates,turnOrder,factionRewardForObject,attackAssignmentsHasReadyTarget=deps.getContext()
        if card==nil or combatConfig.cardInTransit(card) then return end
        if combatConfig~=nil and combatConfig.phaseObjectLocked~=nil
            and combatConfig.phaseObjectLocked(card.guid) then
            removeChoiceButtons(card)
            choiceButtonShown[card.guid]="hidden"
            choiceExpandedByGUID[card.guid]=nil
            return
        end
        local cardData=gameCards[card.guid]
        local rule=cardData~=nil and cardResourceDefinitions[cardData.resourceKey]
            or skillResourceDefinitions[card.guid]
        choices=trackerPrivate.cardControlOptions.fallbackChoices(card,rule,choices,resources,repeatLink)
        local posture=cardPosture(card)
        local reward=factionRewardForObject~=nil and factionRewardForObject(card) or nil
        local isSkill=skillTokens[card.guid]~=nil or card.getGMNotes()=="Puppet Master"
            or reward~=nil
        if not resourceCardsDetailsOpen() then
            if choiceButtonShown[card.guid]~="hidden" then
                removeChoiceButtons(card)
                choiceButtonShown[card.guid]="hidden"
            end
            choiceExpandedByGUID[card.guid]=nil
            return
        end
        -- Skill tokens are physically smaller than Action cards, so their choice
        -- buttons (collapsed and expanded) need a larger dedicated scale.
        local buttonScale=isSkill and "0.58 0.58" or "0.25 0.25"
        local buttonSpacing=44
        local buttonRowOffset=-30
        local data=gameCards[card.guid]
        local isArtifact=data~=nil and data.cardType=="Artifact" and data.full==nil
        -- A physical flip is not a THROW/RECOVER choice. Hide every tracker
        -- control on the back without changing the saved Artifact selection.
        if data~=nil and data.cardType=="Artifact" and card.is_face_down==true then
            removeChoiceButtons(card)
            choiceButtonShown[card.guid]="hidden"
            choiceExpandedByGUID[card.guid]=nil
            return
        end
        if isArtifact and posture=="upright" and (choices==nil or #choices==0) then
            local xml=resourceObjectUiXmlTable(card.UI)
            local old={}
            for i,node in ipairs(xml) do old[i]=node end
            for i=#xml,1,-1 do
                local attr=xml[i].attributes
                if attr~=nil and type(attr.id)=="string"
                    and (attr.id:sub(1,19)=="ResourceCardChoice_"
                        or attr.id:find("^AttackAssignmentSource_")~=nil) then
                    table.remove(xml,i)
                end
            end
            local uiRotation=card.is_face_down==true and "0 180 180" or "0 0 180"
            local depth=card.is_face_down==true and "35" or "-35"
            xml[#xml+1]=trackerPrivate.artifactBreakButton(card,uiRotation,depth)
            if rule~=nil and rule.grailFamePerHealing~=nil and not powered then
                xml[#xml+1]=trackerPrivate.grailFameButton(card,uiRotation,depth)
            end
            if not resourceObjectUiSameXML(old,xml) then resourceObjectUiSetTable(card.UI,xml) end
            combatConfig.cardButtonIds[card.guid]=combatConfig.cardChoiceIds(card.guid,xml)
            choiceButtonShown[card.guid]="artifact-break-only:"..tostring(resourceCardsArtifactBroken(card.guid,card))
            return
        end
        if choices==nil or #choices==0
            or (card.is_face_down==true and not isSkill and not isArtifact and repeatLink==nil)
            or (not isSkill and posture=="discard")
            or (not isSkill and posture=="sideways" and not (cardCanPlaySideways(card)
                or card.getGMNotes()=="Wound")) then
            if choiceButtonShown[card.guid]~="hidden" then
                removeChoiceButtons(card)
                choiceButtonShown[card.guid]="hidden"
            end
            choiceExpandedByGUID[card.guid]=nil
            return
        end

        local rows,signatureParts,visibleAssets,assetSeen=trackerPrivate.cardControlOptions.buildRows(
            card,cardData,rule,choices,powered,inventorySpec,inventorySets,repeatLink,
            posture,isSkill,choiceExpandedByGUID[card.guid])
        if rows==nil then
            if choiceButtonShown[card.guid]~="hidden" then
                removeChoiceButtons(card)
                choiceButtonShown[card.guid]="hidden"
            end
            choiceExpandedByGUID[card.guid]=nil
            return
        end
        local buttonRotation=180
        if posture=="sideways" then
            buttonRotation=card.getRotation()[2]%360<180 and 90 or 270
        end
        local uiRotation=card.is_face_down==true and "0 180 180" or ("0 0 "..buttonRotation)
        local hardenedTarget=rule~=nil and rule.damageMitigation~=nil
            and combatAssignmentState.targets[card.guid] or nil
        local hardenedOptions=hardenedTarget~=nil and combatHardenedAttackOptions(hardenedTarget) or {}
        local mitigationStateKey=card.guid=="ae8673" and "elementalResistanceAttackKey"
            or "battleHardenedAttackKey"
        local hardenedKey=gStates~=nil and gStates[mitigationStateKey] or nil
        local hardenedIndex=1
        for i,option in ipairs(hardenedOptions) do
            if option.key==hardenedKey then hardenedIndex=i break end
        end
        -- Keep Skill icons just clear of the token surface to prevent
        -- z-fighting/flicker when the camera moves. Other object UI depths stay put.
        local buttonDepth=isSkill and (card.is_face_down==true and "12" or "-12")
            or (card.is_face_down==true and "35" or "-35")
        local conversion,conversionBudget,conversionValid=nil,0,false
        if rule~=nil and rule.combatConversion~=nil and combatCalcOn
            and posture=="upright" and resources~=nil then
            conversion,conversionBudget,conversionValid=combatConfig.conversionFor(
                combatAssignmentActiveSeat(),rule.combatConversion)
            -- The first scan has not stored its new records yet; the card itself
            -- is already a valid source and must receive its controls immediately.
            conversionValid=conversion~=nil
        end
        local special=gStates~=nil and gStates.startingCardSelections~=nil
            and gStates.startingCardSelections[card.guid] or nil
        local readyLinks={}
        if rule~=nil and (rule.readyWithInfluence~=nil or rule.simultaneousReady==true) then
            for sourceKey in pairs(gStates~=nil and gStates.unitReadyLinks or {}) do
                if sourceKey:match("^"..card.guid.."#ready%d+$") then
                    readyLinks[#readyLinks+1]=sourceKey
                end
            end
            table.sort(readyLinks)
        end
        local readyCount=#readyLinks
        -- Keep the Ready control for undo while links exist; otherwise show it
        -- only if the active Unit layout has a spent, eligible target.
        local canReadyUnit=rule~=nil and rule.readyWithInfluence~=nil and powered
            and attackAssignmentsHasReadyTarget~=nil
            and attackAssignmentsHasReadyTarget(
                turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber]~=nil
                    and turnOrder[gStates.turnNumber].seatPos or nil,
                rule.readyWithInfluence.maxLevel) or false
        local signature=(posture=="sideways" and "S" or (powered and "P" or "N"))
            ..":"..table.concat(signatureParts,";")..":"..uiRotation..":"..buttonDepth
            ..(combatCalcOn and (combatCumbersomeActive and ":CC" or ":C") or "")
            ..":PSY:"..tostring(combatPsychicActive)
            ..(rule~=nil and rule.damageMitigation~=nil
                and (":H:"..tostring(hardenedTarget)..":"..tostring(#hardenedOptions)
                    ..":"..tostring(hardenedIndex)) or "")
            ..(rule~=nil and rule.forkedLightning
                and (":FL:"..tostring(gStates~=nil and gStates.forkedLightningPhase or "range")) or "")
            ..(conversionValid and conversion~=nil and (":CV:"..tostring(conversionBudget)..":"
                ..tostring(conversion.attack)..":"..tostring(conversion.ranged)..":"
                ..tostring(conversion.block)..":"..tostring(conversion.element)
                ..":"..table.concat(conversion.blockUses or {},",")
                ..":"..table.concat(conversion.elementUses or {},",")) or "")
            ..(special~=nil and (":START:"..tostring(special.interaction)..":"
                ..tostring(special.recruited)..":"..tostring(special.terrain)) or "")
            ..":READY:"..tostring(readyCount)..":"..table.concat(readyLinks,",")
            ..":READY_ELIGIBLE:"..tostring(canReadyUnit)
            ..":ARTIFACT_BREAK:"..tostring(isArtifact and resourceCardsArtifactBroken(card.guid,card))
            ..":ENEMY_PRESENT:"..tostring(combatEnemyInPlay)
            ..":GRAIL:"..tostring(gStates~=nil and gStates.artifactGrailHealingUsed~=nil
                and gStates.artifactGrailHealingUsed[card.guid] or 0)
            ..":TARGETS:"..tostring(trackerPrivate.singleAutoEnemyGUID)
        if choiceButtonShown[card.guid]==signature
            and combatConfig.cardChoicesPresent(card) then return end
        local xml=resourceObjectUiXmlTable(card.UI)
        -- Preserve the actual pre-render object UI for a structural comparison.
        -- Unrelated object buttons remain in both lists, and moving a card with
        -- unchanged choices does not require a destructive TTS UI rebuild.
        local previousXml={}
        for index,node in ipairs(xml) do previousXml[index]=node end
        for i=#xml,1,-1 do
            local attr=xml[i].attributes
            if attr~=nil and type(attr.id)=="string"
                and (attr.id:sub(1,19)=="ResourceCardChoice_"
                    or attr.id:find("^AttackAssignmentSource_")~=nil) then table.remove(xml,i) end
        end
        local otherControlCount=#xml
        if conversionValid then visibleAssets[#visibleAssets+1]="target" end
        if rule~=nil and rule.dodgeAttackSplit and combatCalcOn
            and posture=="upright" and resources~=nil then
            visibleAssets[#visibleAssets+1]="attackReduction"
            visibleAssets[#visibleAssets+1]="target"
        end
        if rule~=nil and rule.defeatArmourReduce~=nil and powered and combatCalcOn
            and posture=="upright" then
            visibleAssets[#visibleAssets+1]="armourReduction"
            visibleAssets[#visibleAssets+1]="target"
        end
        local assets,blocked=resourceCardsChoiceAssetsFor(card.UI,visibleAssets)
        local multi=#rows>1
        for rowPosition,row in ipairs(rows) do
            local columns,columnByCategory={},{}
            for _,entry in ipairs(row.visible) do
                local column=resourceChoiceColumn(entry.category)
                if columnByCategory[column]==nil then
                    columns[#columns+1]=column
                    columnByCategory[column]=#columns
                end
            end
            local y=isSkill and 0 or (-12-(#rows-1)*15+(rowPosition-1)*30)
            -- 0 = printed stronger effect; 1, 2, ... = crystal set bonuses.
            if multi then
                xml[#xml+1]={tag="Text",attributes={
                    id="ResourceCardChoice_"..card.guid.."_label"..row.index,
                    position="-80 "..tostring(y).." "..buttonDepth,rotation=uiRotation,
                    width=60,height=90,scale="0.25 0.25",fontSize=62,
                    color="#DAE1EA",alignment="MiddleCenter",
                    raycastTarget="false",text=tostring(math.abs(row.index))}}
            end
            local displayed={}
            for _,entry in ipairs(row.visible) do displayed[entry.category]=true end
            local skillPositions=isSkill and skillChoicePositions(row.visible) or nil
            for entryIndex,entry in ipairs(row.visible) do
                local category=entry.category
                local column=resourceChoiceColumn(category)
                local x=((#columns+1)/2-columnByCategory[column])*buttonSpacing
                local above=row.expanded and category~=column and displayed[column]==true
                local buttonY=y+(above and buttonRowOffset or 0)
                if skillPositions~=nil then
                    x=skillPositions[category].x
                    buttonY=skillPositions[category].y
                end
                -- Blood Fury has three wound-scaled Attacks in one horizontal row.
                if reward~=nil and reward.name=="Blood Fury Dagger" then
                    x=((#row.visible+1)/2-entryIndex)*104
                    buttonY=0
                end
                local active=category==row.selected
                local icon=resourceCardsChoiceIcon(entry.icon)
                if icon~=nil and blocked[icon.name] then icon=nil end
                local buttonId="ResourceCardChoice_"..card.guid.."_"
                    ..(row.index>0 and ("set"..row.index.."_")
                        or row.index<0 and ("rep"..(-row.index).."_") or "")..category
                -- Fixed copied effects still need a visible icon in each row.
                -- It is deliberately not clickable: there is no alternative.
                if #row.entries>1 or (repeatLink~=nil and repeatLink.count>1) then
                    local button={tag="Button",attributes={
                        id=buttonId,onClick=#row.entries>1
                            and "global/resourceCardsChoiceClicked" or nil,
                        position=tostring(x).." "..tostring(buttonY).." "..buttonDepth,
                        rotation=uiRotation,width=90,height=90,
                        scale=buttonScale,
                        colors=active and "#387D30|#4CA940|#387D30|#387D30"
                            or "#454D5D|#69798E|#444C63|#454D5D",
                        fontSize=77,textColor="#FFFFFF",textAlignment="MiddleCenter"
                    },value=icon==nil and (choiceLetters[category]
                        or (category:sub(1,10)=="combatMove" and "C") or "") or ""}
                    if icon~=nil then
                        if entry.stackedIcons~=nil then
                            button.children={}
                            -- Listed back to front: later icons draw over earlier ones.
                            for _,stackedIcon in ipairs(entry.stackedIcons) do
                                local stackedAsset=resourceCardsChoiceIcon(stackedIcon)
                                if stackedAsset~=nil and not blocked[stackedAsset.name] then
                                    button.children[#button.children+1]={tag="Image",attributes={
                                        image=stackedAsset.name,width=82,height=82,
                                        preserveAspect="true",raycastTarget="false",color="#FFFFFF"}}
                                end
                            end
                        else
                            button.children={{tag="Image",attributes={
                                image=icon.name,width=82,height=82,preserveAspect="true",
                                raycastTarget="false",color="#FFFFFF"}}
                            }
                        end
                        local mark=entry.iconOverlay
                        if mark==nil and (category=="fireAttack" or category=="fireBlock") then
                            mark="F" -- Existing Battle Versatility fire icons.
                        end
                        if mark~=nil then
                            button.children[#button.children+1]={tag="Text",attributes={
                                text=mark,width=82,height=82,
                                alignment=entry.iconOverlayAlignment or "MiddleCenter",
                                fontSize=tonumber(entry.iconOverlaySize) or 62,
                                fontStyle="Bold",color=entry.iconOverlayColor or "#FF564A",
                                outline="#1C1514",outlineSize="2 -2",
                                raycastTarget="false"}}
                        end
                    end
                    if entry.roleBadge~=nil then
                        button.children=button.children or {}
                        button.children[#button.children+1]={tag="Text",attributes={
                            text=entry.roleBadge,width=34,height=34,
                            alignment="LowerRight",fontSize=37,fontStyle="Bold",
                            color=entry.roleBadge=="C" and "#69AEFF" or "#9AFFA4",
                            outline="#101820",outlineSize="2 -2",
                            raycastTarget="false"}}
                    end
                    -- Text-only alternatives (e.g. Chivalry's Reputation choice) are
                    -- real buttons even when no custom icon asset exists.
                    xml[#xml+1]=button
                end
                if not row.expanded and entry.targetResource~=nil then
                    local resource=row.index>0 and ("set"..row.index..":"..entry.targetResource) or entry.targetResource
                    local targetX=x
                    if #row.entries>1 or (repeatLink~=nil and repeatLink.count>1) then
                        -- Skill tokens push the target button out a further half button width.
                        local gap=buttonSpacing/2+(isSkill and 90*0.70/2 or 0)
                        targetX=x+(x>=0 and gap or -gap)
                    end
                    local targetAsset=resourceCardsChoiceIcon("target")
                    -- A split choice gets one target button per resource, each marked with its icon.
                    ---@type (string|boolean)[]
                    local parts=entry.splitTargets or {false}
                    if rule~=nil and rule.forkedLightning then
                        parts={}
                        for point=1,math.min(3,math.max(1,entry.forkedCount or 1)) do
                            parts[#parts+1]="fork"..point
                        end
                    end
                    for partIndex,part in ipairs(parts) do
                        local partX=rule~=nil and rule.forkedLightning
                            and targetX+(partIndex-(#parts+1)/2)*buttonSpacing*1.85
                            or targetX+(partIndex-1)*buttonSpacing*(targetX>=0 and 1 or -1)
                        local children={}
                        if part and not (rule~=nil and rule.forkedLightning) then
                            local partAsset=resourceCardsChoiceIcon(part)
                            if partAsset~=nil and not blocked[partAsset.name] then
                                children[#children+1]={tag="Image",attributes={
                                    image=partAsset.name,width=62,height=62,
                                    preserveAspect="true",raycastTarget="false",color="#FFFFFF"}}
                            end
                        end
                        children[#children+1]={tag="Image",attributes={
                            image=targetAsset.name,width=82,height=82,
                            preserveAspect="true",raycastTarget="false",color="#FFFFFF"}}
                        if rule~=nil and rule.forkedLightning then
                            children[#children+1]={tag="Text",attributes={
                                text=tostring(partIndex),width=58,height=58,fontSize=48,
                                alignment="LowerRight",color="#FFFFFF",
                                outline="#141820",outlineSize="2 -2",raycastTarget="false"}}
                        end
                        local independentEffect=row.index<0 and entry.targetResource=="effect"
                            and rule~=nil and rule.enemyEffect~=nil
                            and combatEffectSpec(rule,powered,entry.category)~=nil
                        local targetPart=independentEffect and ("rep"..(-row.index))
                            or part
                        local targetCategory=entry.targetResource
                        if row.index<0 and targetCategory=="unitReady" then
                            targetPart="use"..(-row.index)
                        end
                        xml[#xml+1]={tag="Button",attributes={
                            id="AttackAssignmentSource_"..card.guid.."_0_"
                                ..(row.index<0 and targetCategory~="unitReady"
                                    and ("rep"..(-row.index)..":") or "")..targetCategory
                                ..(targetPart and ("@"..targetPart) or ""),
                            onClick=entry.targetResource=="unitReady"
                                and "global/attackAssignmentReadySourceClicked"
                                or (entry.targetResource=="blockSource"
                                    and "global/resourceCardsBlockSourceLinkClicked"
                                    or (entry.targetResource=="ambush"
                                        and "global/attackAssignmentAmbushSourceClicked"
                                        or "global/attackAssignmentSourceClicked")),
                            position=tostring(partX).." "..tostring(buttonY).." "..buttonDepth,
                            rotation=uiRotation,width=90,height=90,scale=buttonScale,
                            colors="#454D5D|#69798E|#444C63|#454D5D",textColor="#FFFFFF",textAlignment="MiddleCenter"
                        },value="",children=children}
                    end
                end
            end
        end
        -- Dodge and Weave has no option selector: its normal Attack target follows
        -- other Attack cards, while these buttons independently reduce enemy Attacks.
        if rule~=nil and rule.dodgeAttackSplit and combatCalcOn
            and posture=="upright" and resources~=nil then
            local perUse=powered and 2 or 1
            local repeatCount=repeatLink~=nil and repeatLink.count or 1
            local count=perUse*repeatCount
            local targetAsset=resourceCardsChoiceIcon("target")
            local reduceAsset=resourceCardsChoiceIcon("attackReduction")
            -- Each copied use has its own effect targets. The printed Attack
            -- points still form one composite combat source.
            local targetX=-44
            for index=1,count do
                local useIndex=math.floor((index-1)/perUse)+1
                local withinUse=(index-1)%perUse
                local targetY=-12-(repeatCount-1)*15+(useIndex-1)*30
                local children={}
                if reduceAsset~=nil and not blocked[reduceAsset.name] then
                    children[#children+1]={tag="Image",attributes={image=reduceAsset.name,
                        width=76,height=76,preserveAspect="true",raycastTarget="false"}}
                end
                if targetAsset~=nil and not blocked[targetAsset.name] then
                    children[#children+1]={tag="Image",attributes={image=targetAsset.name,
                        width=42,height=42,preserveAspect="true",raycastTarget="false",
                        rectAlignment="LowerRight"}}
                end
                xml[#xml+1]={tag="Button",attributes={
                    id="AttackAssignmentSource_"..card.guid.."_0_effect@effect"..index,
                    onClick="global/attackAssignmentSourceClicked",
                    position=tostring(targetX-withinUse*44).." "..tostring(targetY).." "..buttonDepth,
                    rotation=uiRotation,width=90,height=90,scale=buttonScale,
                    colors="#454D5D|#69798E|#444C63|#454D5D",
                    textColor="#FFFFFF",textAlignment="MiddleCenter"},
                    value=#children==0 and "-2" or "",
                    children=children}
            end
        end
        -- Two small pool-allocation counters on Agility (Attack/Ranged), or one
        -- on Diplomacy (Block). Left click spends; right click returns points.
        -- Converted points remain independently targetable from the printed Move
        -- or Influence resource. No other printed card is duplicated.
        if conversionValid and conversion~=nil then
            local agility=rule.combatConversion=="agility"
            local multiDiplomacy=not agility and repeatLink~=nil
                and repeatLink.count>1
            local controls=agility and
                {{part="Attack",value=conversion.attack,label="A",x=-145,y=135},
                 {part="Ranged",value=conversion.ranged,label="R",x=15,y=135}}
                or {{part="Block",value=conversion.block,label="B",x=-80,y=135}}
            if multiDiplomacy then
                controls={}
                for index=1,repeatLink.count do
                    controls[#controls+1]={part="Block"..index,
                        value=conversion.blockUses~=nil
                            and conversion.blockUses[index] or 0,label="B"..index,
                        x=-152,y=-12-(repeatLink.count-1)*15+(index-1)*30,
                        index=index}
                end
            end
            for _,control in ipairs(controls) do
                xml[#xml+1]={tag="Button",attributes={
                    id="ResourceCardChoice_"..card.guid.."_convert"..control.part,
                    onClick="global/resourceCardsConversionClicked",
                    position=tostring(control.x).." "..tostring(control.y).." "..buttonDepth,
                    rotation=uiRotation,width=125,height=90,scale="0.30 0.30",
                    fontSize=55,colors="#454D5D|#69798E|#444C63|#454D5D",
                    textColor="#FFFFFF",textAlignment="MiddleCenter"},
                    value=control.label..tostring(control.value)}
                if control.value>0 then
                    local targetAsset=resourceCardsChoiceIcon("target")
                    local children={}
                    if targetAsset~=nil and not blocked[targetAsset.name] then
                        children[#children+1]={tag="Image",attributes={
                            image=targetAsset.name,width=78,height=78,
                            preserveAspect="true",raycastTarget="false"}}
                    end
                    xml[#xml+1]={tag="Button",attributes={
                        id="AttackAssignmentSource_"..card.guid.."_0_"
                            ..string.lower(control.part).."@convert"..control.part,
                        onClick="global/attackAssignmentSourceClicked",
                        position=tostring(multiDiplomacy and 174 or control.x+73)
                            .." "..tostring(control.y).." "..buttonDepth,
                        rotation=uiRotation,width=90,height=90,
                        scale="0.25 0.25",fontSize=60,
                        colors="#454D5D|#69798E|#444C63|#454D5D",
                        textColor="#FFFFFF",textAlignment="MiddleCenter"},
                        value=#children==0 and "T" or "",children=children}
                end
                if multiDiplomacy and powered then
                    xml[#xml+1]={tag="Button",attributes={
                        id="ResourceCardChoice_"..card.guid.."_convertElement"..control.index,
                        onClick="global/resourceCardsConversionClicked",
                        position="103 "..tostring(control.y).." "..buttonDepth,
                        rotation=uiRotation,width=105,height=90,
                        scale="0.30 0.30",fontSize=55,
                        colors="#454D5D|#69798E|#444C63|#454D5D",
                        textColor="#FFFFFF",textAlignment="MiddleCenter"},
                        value=conversion.elementUses~=nil
                            and conversion.elementUses[control.index] or "F"}
                end
            end
            if not agility and powered and not multiDiplomacy then
                xml[#xml+1]={tag="Button",attributes={
                    id="ResourceCardChoice_"..card.guid.."_convertElement",
                    onClick="global/resourceCardsConversionClicked",
                    position="100 135 "..buttonDepth,rotation=uiRotation,
                    width=105,height=90,scale="0.30 0.30",fontSize=55,
                    colors="#454D5D|#69798E|#444C63|#454D5D",
                    textColor="#FFFFFF",textAlignment="MiddleCenter"},
                    value=conversion.element}
            end
            xml[#xml+1]={tag="Text",attributes={
                id="ResourceCardChoice_"..card.guid.."_convertHint",
                position="0 190 "..buttonDepth,rotation=uiRotation,
                width=300,height=50,scale="0.25 0.25",fontSize=45,
                alignment="MiddleCenter",color="#E6E1D7",
                raycastTarget="false",text="Left + / Right -"}}
        end
        -- A multi-attack target needs an explicit choice of which single Attack
        -- Battle Hardened will mitigate. The cycling button is on the Skill, not
        -- the enemy, and never changes the existing calculator columns.
        if rule~=nil and rule.damageMitigation~=nil and #hardenedOptions>1 then
            xml[#xml+1]={tag="Button",attributes={
                id="ResourceCardChoice_"..card.guid.."_hardenedCycle",
                onClick="global/resourceCardsBattleHardenedAttackClicked",
                position="-105 0 "..buttonDepth,rotation=uiRotation,
                width=110,height=90,scale="0.42 0.42",fontSize=55,
                colors="#454D5D|#69798E|#444C63|#454D5D",
                textColor="#FFFFFF",textAlignment="MiddleCenter"},
                value=tostring(hardenedIndex).."/"..tostring(#hardenedOptions)}
        end
        if rule~=nil and rule.defeatArmourReduce~=nil and powered and combatCalcOn
            and posture=="upright" and resources~=nil then
            local reductionAsset=resourceCardsChoiceIcon("armourReduction")
            local targetAsset=resourceCardsChoiceIcon("target")
            local children={}
            if reductionAsset~=nil and not blocked[reductionAsset.name] then
                children[#children+1]={tag="Image",attributes={
                    image=reductionAsset.name,width=75,height=75,
                    preserveAspect="true",raycastTarget="false",color="#FFFFFF"}}
            end
            if targetAsset~=nil and not blocked[targetAsset.name] then
                children[#children+1]={tag="Image",attributes={
                    image=targetAsset.name,width=45,height=45,
                    preserveAspect="true",raycastTarget="false",color="#FFFFFF",
                    rectAlignment="LowerRight"}}
            end
            xml[#xml+1]={tag="Button",attributes={
                id="AttackAssignmentSource_"..card.guid.."_0_attack@explosiveAttack",
                onClick="global/attackAssignmentSourceClicked",
                position="140 0 "..buttonDepth,rotation=uiRotation,
                width=90,height=90,scale=buttonScale,fontSize=46,
                colors="#454D5D|#69798E|#444C63|#454D5D",
                textColor="#FFFFFF",textAlignment="MiddleCenter"},
                value=#children==0 and "Arm" or "",children=children}
        end
        if rule~=nil and rule.forkedLightning then
            local phase=gStates~=nil and gStates.forkedLightningPhase or "range"
            xml[#xml+1]={tag="Button",attributes={
                id="ResourceCardChoice_"..card.guid.."_forkPhase",
                onClick="global/resourceCardsForkedLightningPhaseClicked",
                position="160 0 "..buttonDepth,rotation=uiRotation,
                width=140,height=90,scale="0.38 0.38",fontSize=47,
                colors="#454D5D|#69798E|#444C63|#454D5D",
                textColor="#FFFFFF",textAlignment="MiddleCenter"},
                value=phase=="range" and "RNG" or "ATK"}
        end
        if rule~=nil and posture=="upright" and card.is_face_down~=true then
            local function startingControl(suffix,label,active,x,y)
                xml[#xml+1]={tag="Button",attributes={
                    id="ResourceCardChoice_"..card.guid.."_"..suffix,
                    onClick="global/resourceCardsStartingCardControlClicked",
                    position=tostring(x).." "..tostring(y).." "..buttonDepth,
                    rotation=uiRotation,width=160,height=90,scale="0.28 0.28",
                    fontSize=41,textColor="#FFFFFF",textAlignment="MiddleCenter",
                    colors=active and "#387D30|#4CA940|#387D30|#387D30"
                        or "#454D5D|#69798E|#444C63|#454D5D"},
                    value=label}
            end
            if rule.interactionReward~=nil then
                startingControl("interaction","INT",
                    special~=nil and special.interaction==true,135,-125)
            elseif rule.recruitDiscount~=nil and not powered then
                startingControl("recruit","-2 REC",
                    special~=nil and special.recruited==true,135,-125)
            elseif rule.readyWithInfluence~=nil and powered
                and (canReadyUnit or readyCount>0) then
                startingControl("ruthlessReady","RDY "..tostring(readyCount),
                    readyCount>0,145,-125)
            elseif rule.selectedTerrainDiscount~=nil and powered then
                startingControl("terrain",special~=nil and special.terrain~=nil
                    and special.terrain:sub(1,3):upper() or "TER",
                    special~=nil and special.terrain~=nil,150,-125)
            end
        end
        if rule~=nil and isArtifact
            and cardData.resourceKey=="artifactBannerFortitude"
            and trackerPrivate.bannerStrongActive(card) and posture=="upright"
            and not combatEnemyInPlay and not combatCalcOn
            and not trackerPrivate.bannerEffectUses().healing[card.guid] then
            xml[#xml+1]={tag="Button",attributes={
                id="ResourceCardChoice_"..card.guid.."_healAllUnits",
                onClick="global/resourceCardsArtifactHealUnitsClicked",
                position="145 -145 "..buttonDepth,rotation=uiRotation,
                width=160,height=85,scale="0.28 0.28",fontSize=40,
                colors="#454D5D|#69798E|#444C63|#454D5D",
                textColor="#FFFFFF",textAlignment="MiddleCenter"},value="HEAL"}
        end
        if rule~=nil and rule.staffDualChoices==true and posture=="upright" then
            -- Colour identity, not the shared numeric 'other=1', grants Ready.
            -- Ready may have been played earlier, but cannot be activated in combat.
            local _,first=currentChoice(card.guid,powered,choices)
            local second=nil
            if powered then
                local remaining={}
                for _,option in ipairs(choices or {}) do
                    if choiceCategory(option)~=first then remaining[#remaining+1]=option end
                end
                _,second=inventorySetChoice(card.guid,1,remaining,choices)
            end
            local redReady=type(resources)=="table" and not combatEnemyInPlay
                and (first=="red" or second=="red")
            if redReady then
                xml[#xml+1]={tag="Button",attributes={
                    id="AttackAssignmentSource_"..card.guid.."_0_unitReady",
                    onClick="global/attackAssignmentReadySourceClicked",
                    position="150 -145 "..buttonDepth,rotation=uiRotation,
                    width=150,height=85,scale="0.28 0.28",fontSize=46,
                    colors="#454D5D|#69798E|#444C63|#454D5D",textColor="#FFFFFF",
                    textAlignment="MiddleCenter"},value="RDY"}
            end
        end
        if rule~=nil and rule.simultaneousReady==true and posture=="upright"
            and resources~=nil and (tonumber(resources.healing) or 0)>0
            and (card.is_face_down~=true or repeatLink~=nil) then
            for index=1,(repeatLink~=nil and repeatLink.count or 1) do
                local sourceKey=card.guid.."#ready"..index
                local linked=gStates~=nil and gStates.unitReadyLinks~=nil
                    and gStates.unitReadyLinks[sourceKey]~=nil
                xml[#xml+1]={tag="Button",attributes={
                    id="ResourceCardChoice_"..card.guid.."_regenReady"..index,
                    onClick="global/resourceCardsRegenerationReadyClicked",
                    position="145 "..tostring(-125+(index-1)*62).." "..buttonDepth,
                    rotation=uiRotation,width=150,height=90,scale="0.28 0.28",
                    fontSize=44,textColor="#FFFFFF",textAlignment="MiddleCenter",
                    colors=linked and "#387D30|#4CA940|#387D30|#387D30"
                        or "#454D5D|#69798E|#444C63|#454D5D"},
                    value="RDY"..(repeatLink~=nil and tostring(index) or "")}
            end
        end
        if isArtifact and posture=="upright" then
            trackerPrivate.raiseArtifactChoiceControls(xml,otherControlCount+1,card.guid)
            xml[#xml+1]=trackerPrivate.artifactBreakButton(card,uiRotation,buttonDepth)
            if rule~=nil and rule.grailFamePerHealing~=nil and not powered then
                xml[#xml+1]=trackerPrivate.grailFameButton(card,uiRotation,buttonDepth)
            end
        end
        -- A fixed Attack/Block against a sole enemy needs no manual target icon.
        -- That can leave an otherwise empty object UI; TTS rejects setXmlTable({})
        -- with an Object reference error. The shared writer uses setXml("") here.
        -- A harmless signature change (for example, another enemy's target
        -- context during a card drop) must not flash an unchanged card UI.
        -- New image registrations still need the asset-list writer.
        if assets~=nil or not resourceObjectUiSameXML(previousXml,xml) then
            resourceObjectUiSetTable(card.UI,xml,assets)
            if trackerPrivate.traceEnabled then
                trackerPrivate.traceEvent("choice.write",nil,card.guid,
                    "buttons="..tostring(#combatConfig.cardChoiceIds(card.guid,xml)))
            end
        elseif trackerPrivate.traceEnabled then
            trackerPrivate.traceEvent("choice.same",nil,card.guid)
        end
        combatConfig.cardButtonIds[card.guid]=combatConfig.cardChoiceIds(card.guid,xml)
        choiceButtonShown[card.guid]=signature
    end


    return showChoiceButtons
end

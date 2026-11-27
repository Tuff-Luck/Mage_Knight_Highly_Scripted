-- Build card/Skill UI choices and row descriptors, without writing object XML.
-- Selection persistence, visibility lifecycle and combat assignment remain with the caller.
local moveOptions=require("PlayingGame.PlayerBoard.ResourceTracker.Interface.MoveRoleOptions")
return function(deps)
    local choiceLetters=deps.choiceLetters
    local combatConfig=deps.combatConfig
    local cardPosture=deps.cardPosture
    local choiceHasTargetableCombatResource=deps.choiceHasTargetableCombatResource
    local combatEffectSpec=deps.combatEffectSpec
    local resourceChoiceRank=deps.resourceChoiceRank
    local currentChoice=deps.currentChoice
    local inventorySetChoice=deps.inventorySetChoice
    local choiceCategory=deps.choiceCategory
    local skillChoiceFamily=deps.skillChoiceFamily
    local combatReductionChoiceIcon=deps.combatReductionChoiceIcon
    local resourceCardsMoveRole=deps.resourceCardsMoveRole
    local resourceCardsHideAutomaticEnemyTarget=deps.resourceCardsHideAutomaticEnemyTarget

    local function fallbackChoices(card,rule,choices,resources,repeatLink)
        -- Give non-resource Skill effects the same dedicated targeting icon used
        -- by the combat calculator, without pretending the bonus is a free Block.
        if rule~=nil and rule.blockSourceBoost~=nil then
            local amount=tonumber(resources~=nil and resources.move) or 0
            choices=amount>0 and {{move=amount}} or {{key="guide",icon="move"}}
        elseif rule~=nil and rule.damageMitigation~=nil then
            choices={{key="hardened",icon="other"}}
        end
        -- Starting cards with selectable conditional effects keep their controls
        -- even when their Move/Influence value is fixed; manual notes need no button.
        if rule~=nil and (rule.interactionReward~=nil or rule.recruitDiscount~=nil
            or rule.selectedTerrainDiscount~=nil or rule.influenceAction~=nil)
            and (choices==nil or #choices==0) and type(resources)=="table" then
            if (tonumber(resources.move) or 0)>0 then choices={{move=resources.move}}
            elseif (tonumber(resources.influence) or 0)>0 then
                choices={{influence=resources.influence}} end
        end
        -- Regeneration's Heal and Ready are simultaneous, not a choice.
        if (choices==nil or #choices==0) and rule~=nil
            and rule.simultaneousReady==true and type(resources)=="table"
            and (tonumber(resources.healing) or 0)>0 then
            choices={{healing=resources.healing}}
        end
        -- Ambush has only printed Move, but its independent combat buff must be
        -- targetable even before an enemy is in the play area.
        if (choices==nil or #choices==0) and rule~=nil and rule.combatLink~=nil
            and type(resources)=="table" and (tonumber(resources.move) or 0)>0
            and cardPosture(card)=="upright" and card.is_face_down~=true then
            choices={{move=resources.move}}
        end
        -- Fixed Move effects also require an ordinary grid choice for their phase.
        if (choices==nil or #choices==0) and type(resources)=="table"
            and (tonumber(resources.move) or 0)>0 then
            choices={{move=resources.move}}
        end
        -- A fixed effect (no alternatives) still needs a Target button for its combat resource.
        if (choices==nil or #choices==0) and type(resources)=="table" then
            local bestKey,bestRank
            for key,value in pairs(resources) do
                if type(value)=="number" and value>0 and choiceLetters[key]~=nil
                    and choiceHasTargetableCombatResource(key) then
                    local rank=key=="move" and 99 or resourceChoiceRank(key,{[key]=value})
                    if bestKey==nil or rank<bestRank or (rank==bestRank and key<bestKey) then
                        bestKey,bestRank=key,rank
                    end
                end
            end
            if bestKey~=nil then choices={{[bestKey]=resources[bestKey]}} end
        end
        -- Training, Force of Nature (basic) and other manual copied effects
        -- still get one visible reminder row per use. Never manufacture a
        -- numeric effect or an unsupported target for an untracked action.
        if repeatLink~=nil and repeatLink.count>1
            and (choices==nil or #choices==0) then
            choices={{key="other",icon="other"}}
        end
        return choices
    end

    local sidewaysCache={}
    local sidewaysCacheCount=0
    local function simpleSidewaysKey(card,rule,choices,powered,inventorySpec,repeatLink,posture,isSkill,expandedRow,shapeshiftField,combat,psychic,cumbersome)
        if posture~="sideways" or isSkill or powered or inventorySpec~=nil or repeatLink~=nil
            or shapeshiftField~=nil or #choices~=4
            or (rule~=nil and (rule.enemyEffect~=nil or rule.blockSourceBoost~=nil
                or rule.damageMitigation~=nil or rule.manaOverload or rule.shapeshift
                or rule.dodgeAttackSplit or rule.forkedLightning)) then return nil end
        local plain={"move","block","attack","influence"}
        for i,key in ipairs(plain) do
            if choices[i][key]~=1 then return nil end
            for field in pairs(choices[i]) do if field~=key then return nil end end
        end
        local _,selected=currentChoice(card.guid,powered,choices,true)
        return table.concat({tostring(selected),tostring(expandedRow),tostring(combat),
            tostring(psychic),tostring(cumbersome),tostring(combatConfig.moveRoleAvailable(card.guid)),
            tostring(resourceCardsMoveRole(card.guid,false)),
            tostring(resourceCardsHideAutomaticEnemyTarget(card.guid,"block",false)),
            tostring(resourceCardsHideAutomaticEnemyTarget(card.guid,"attack",false))},"|")
    end
    local function copyList(values)
        local copy={}
        for key,value in pairs(values) do copy[key]=value end
        return copy
    end
    local function buildRows(card,cardData,rule,choices,powered,inventorySpec,inventorySets,repeatLink,posture,isSkill,expandedRow,shapeshiftField)
        local combatCalcOn,combatPsychicActive,combatCumbersomeActive=deps.combatContext()
        local cacheKey=simpleSidewaysKey(card,rule,choices,powered,inventorySpec,repeatLink,posture,isSkill,
            expandedRow,shapeshiftField,combatCalcOn,combatPsychicActive,combatCumbersomeActive)
        local cached=cacheKey~=nil and sidewaysCache[card.guid] or nil
        if cached~=nil and cached.key==cacheKey then
            -- The renderer may append to its asset list; never expose cached assets.
            return cached.rows,cached.signature,copyList(cached.assets),copyList(cached.seen)
        end
        local function targetResourceFor(choice,category)
            if category=="ready" and cardData~=nil and rule~=nil
                and rule.unitReadyLevels~=nil and rule.staffDualChoices~=true then return "unitReady" end
            if rule~=nil and rule.blockSourceBoost~=nil then return "blockSource" end
            -- Ambush has ONE reusable target button. An Action card receives the
            -- combat bonus; a Cumbersome enemy receives the independent Move.
            if rule~=nil and rule.combatLink~=nil and cardPosture(card)=="upright"
                and card.is_face_down~=true then return "ambush" end
            -- Mana Overload's choices select which linked CARD resource is boosted;
            -- the Skill itself is not an independently targetable Attack/Block.
            if rule~=nil and (rule.manaOverload==true or rule.shapeshift==true) then return nil end
            if not combatCalcOn then return nil end
            if shapeshiftField~=nil then
                if shapeshiftField=="move" then
                    return combatCumbersomeActive and resourceCardsMoveRole(card.guid,false)=="combat"
                        and "move" or nil
                end
                return shapeshiftField
            end
            if rule~=nil and rule.damageMitigation~=nil then return "effect" end
            for _,field in ipairs(combatConfig.sourceFields) do
                if (tonumber(choice[field.key]) or 0)>0 then return field.key end
            end
            if combatPsychicActive and (tonumber(choice.influence) or 0)>0 then return "influence" end
            if combatCumbersomeActive and (tonumber(choice.move) or 0)>0 then return "move" end
            if rule~=nil and rule.dodgeAttackSplit==true then return nil end
            local spec=combatEffectSpec(rule,powered,category)
            if spec~=nil and not spec.all then return "effect" end
            return choiceHasTargetableCombatResource(category) and category or nil
        end
        -- Multiple-choice cards normally have one row. A declarative inventory
        -- set rule adds one more compact row for each complete set of crystals.
        local rows={{index=0,choices=choices}}
        -- Each copied use gets its own visible row, even when the printed
        -- effect has no alternatives. Numeric effects still share one composite
        -- combat source; enemy-only effects may have independent targets.
        if repeatLink~=nil and repeatLink.count>1 and posture=="upright" then
            rows={}
            for i=1,repeatLink.count do
                rows[#rows+1]={index=-i,
                    choices=repeatLink.options~=nil and (repeatLink.options[i] or {})
                        or choices}
            end
        end
        if powered and posture=="upright" and inventorySpec~=nil then
            for i=1,(inventorySets or 0) do
                rows[#rows+1]={index=i,choices=inventorySpec.choices}
            end
        end
        local signatureParts,visibleAssets,assetSeen={}, {}, {}
        for _,row in ipairs(rows) do
            local _,selected
            if row.index<0 then
                _,selected=combatConfig.repeatChoiceFor(card.guid,powered,row.choices,-row.index)
            elseif row.index==0 then
                _,selected=currentChoice(card.guid,powered,row.choices,
                    not isSkill and posture=="sideways")
            else
                _,selected=inventorySetChoice(card.guid,row.index,row.choices,choices)
            end
            row.selected=selected
            if selected~=nil and shapeshiftField==nil then
                for _,option in ipairs(row.choices) do
                    local roleGUID=option.shapeshiftTargetGUID or card.guid
                    local move=moveOptions.producesMove(option,choiceCategory(option))
                    if choiceCategory(option)==selected and move
                        and combatConfig.moveRoleAvailable(roleGUID)
                        and resourceCardsMoveRole(roleGUID,false)=="combat" then
                        row.selected=moveOptions.cardCategory(selected,"combat")
                        break
                    end
                end
            end
            row.entries={}
            local seen={}
            for j,choice in ipairs(row.choices) do
                local category=choiceCategory(choice)
                if category~=nil and choiceLetters[category]~=nil and not seen[category] then
                    seen[category]=true
                    local producesMove=shapeshiftField==nil and moveOptions.producesMove(choice,category)
                    local entry={category=category,
                        rank=resourceChoiceRank(category,choice),originalIndex=j,
                        skillFamily=isSkill and skillChoiceFamily(category,choice) or nil,
                        icon=combatReductionChoiceIcon(rule,powered,choice,category),
                        iconOverlay=choice.iconOverlay,
                        stackedIcons=choice.stackedIcons,splitTargets=choice.splitTargets,
                        forkedCount=rule~=nil and rule.forkedLightning and choice.rangedColdFire or nil,
                        targetResource=targetResourceFor(choice,category),
                        iconOverlayColor=choice.iconOverlayColor,
                        iconOverlayAlignment=choice.iconOverlayAlignment,
                        iconOverlaySize=choice.iconOverlaySize,
                        roleBadge=producesMove and moveOptions.badge("movement") or nil}
                    -- In combat, Influence can be committed to Psychic Block.
                    -- Show its function with shield beneath the Influence symbol.
                    if category=="influence" and combatPsychicActive
                        and (tonumber(choice.influence) or 0)>0 then
                        entry.icon="block"
                        entry.stackedIcons={"block","influence"}
                    end
                    if producesMove then
                        -- Two cells, one printed Move effect. Never duplicate points.
                        -- Friendly links are independent of Move's phase.
                        local friendly=entry.targetResource=="ambush" or entry.targetResource=="blockSource"
                        local splitMoveAttack=choice.splitMoveAttack==true
                        if splitMoveAttack and combatCalcOn then
                            entry.targetResource="attack"
                            entry.targetPart="attack"
                        elseif not friendly then entry.targetResource=nil end
                        row.entries[#row.entries+1]=entry
                        -- Combat Move can also pay for conversions and Spells.
                        -- Cumbersome controls targeting, not the role icon.
                        if combatConfig.moveRoleAvailable(choice.shapeshiftTargetGUID or card.guid) then
                            local combatEntry={}
                            for key,value in pairs(entry) do combatEntry[key]=value end
                            combatEntry.category=moveOptions.cardCategory(category,"combat")
                            combatEntry.originalIndex=j+0.5
                            combatEntry.icon="move"
                            combatEntry.stackedIcons=nil
                            combatEntry.roleBadge=moveOptions.badge("combat")
                            if splitMoveAttack and combatCalcOn then
                                -- Keep Attack aimed independently of the Move pool.
                                combatEntry.targetResource="attack"
                                combatEntry.targetPart="attack"
                                if combatCumbersomeActive then
                                    combatEntry.extraTargetResource="move"
                                    combatEntry.extraTargetPart="block"
                                end
                            elseif friendly then
                                combatEntry.targetResource=entry.targetResource
                                if entry.targetResource=="blockSource" and combatCalcOn
                                    and combatCumbersomeActive then
                                    combatEntry.extraTargetResource="move"
                                end
                            else
                                combatEntry.targetResource=combatCalcOn and combatCumbersomeActive
                                    and choice.shapeshiftTargetGUID==nil and "move" or nil
                            end
                            row.entries[#row.entries+1]=combatEntry
                        end
                    else
                        row.entries[#row.entries+1]=entry
                    end
                end
            end
            table.sort(row.entries,function(a,b)
                if a.rank~=b.rank then return a.rank<b.rank end
                return a.originalIndex<b.originalIndex
            end)
            for _,entry in ipairs(row.entries) do
                -- Ambush retains one reusable physical link even when repeated.
                if entry.targetResource=="ambush" and row.index< -1 then
                    entry.targetResource=nil
                end
                -- The Combat Calculator assigns ordinary Attack/Block to the lone
                -- enemy automatically. Keep all special split, manual and friendly
                -- target controls, even if they currently have only one candidate.
                if entry.targetResource~=nil and entry.splitTargets==nil
                    and entry.targetPart==nil
                    and (rule==nil or rule.forkedLightning~=true)
                    and resourceCardsHideAutomaticEnemyTarget(card.guid,
                        entry.targetResource,false) then
                    entry.targetResource=nil
                end
            end
            if #row.entries<1 or selected==nil then
                return nil
            end
            row.expanded=#row.entries>1 and ((row.index==0 and (expandedRow==true or expandedRow=="base"))
                or (row.index>0 and expandedRow=="set"..tostring(row.index))
                or (row.index<0 and expandedRow=="rep"..tostring(-row.index)))
            local selectedEntry
            for _,entry in ipairs(row.entries) do
                if entry.category==row.selected then selectedEntry=entry break end
            end
            row.visible=row.expanded and row.entries or {selectedEntry}
            -- A stable category/sole-enemy GUID does not imply a stable UI.
            -- Pending retargets, eligibility, split counts and dynamic icons
            -- can change the controls without changing the selected resource.
            local visibleSignatures={}
            for _,entry in ipairs(row.visible) do
                visibleSignatures[#visibleSignatures+1]=table.concat({
                    entry.category,tostring(entry.icon),tostring(entry.skillFamily),
                    tostring(entry.iconOverlay),tostring(entry.iconOverlayColor),
                    tostring(entry.iconOverlayAlignment),tostring(entry.iconOverlaySize),
                    tostring(entry.roleBadge),table.concat(entry.stackedIcons or {},","),
                    tostring(not row.expanded and entry.targetResource or nil),
                    tostring(not row.expanded and entry.extraTargetResource or nil),
                    tostring(not row.expanded and entry.targetPart or nil),
                    tostring(not row.expanded and entry.extraTargetPart or nil),
                    not row.expanded and table.concat(entry.splitTargets or {},",") or "",
                    tostring(not row.expanded and entry.forkedCount or nil)
                },"|")
                if not assetSeen[entry.icon] then
                    visibleAssets[#visibleAssets+1]=entry.icon
                    assetSeen[entry.icon]=true
                end
                for _,stackedIcon in ipairs(entry.stackedIcons or {}) do
                    if not assetSeen[stackedIcon] then
                        visibleAssets[#visibleAssets+1]=stackedIcon
                        assetSeen[stackedIcon]=true
                    end
                end
                if not row.expanded and entry.targetResource~=nil
                    and not assetSeen.target then
                    visibleAssets[#visibleAssets+1]="target"
                    assetSeen.target=true
                end
                if not row.expanded and entry.targetPart=="attack"
                    and not assetSeen.attack then
                    visibleAssets[#visibleAssets+1]="attack"
                    assetSeen.attack=true
                end
                if not row.expanded and entry.extraTargetResource~=nil
                    and not assetSeen.move then
                    visibleAssets[#visibleAssets+1]="move"
                    assetSeen.move=true
                end
                for _,part in ipairs(not row.expanded and entry.splitTargets or {}) do
                    if not assetSeen[part] then
                        visibleAssets[#visibleAssets+1]=part
                        assetSeen[part]=true
                    end
                end
            end
            signatureParts[#signatureParts+1]=row.index..":"..row.selected..":"
                ..(row.expanded and "open" or "closed")..":"..tostring(#row.entries)
                ..":"..table.concat(visibleSignatures,",")
        end
        if cacheKey~=nil then
            if sidewaysCache[card.guid]==nil then
                if sidewaysCacheCount>=256 then sidewaysCache={} sidewaysCacheCount=0 end
                sidewaysCacheCount=sidewaysCacheCount+1
            end
            sidewaysCache[card.guid]={key=cacheKey,rows=rows,signature=signatureParts,
                assets=copyList(visibleAssets),seen=copyList(assetSeen)}
        end
        return rows,signatureParts,visibleAssets,assetSeen
    end

    return {fallbackChoices=fallbackChoices,buildRows=buildRows}
end

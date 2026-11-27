-- Ready source validation, target eligibility and public Ready interaction policy.
local M={}
local resourceOps=require("PlayingGame.PlayerBoard.ResourceTracker.Core.ResourceOperations")

function M.sourceValid(sourceKey,seatPos,unitResourceDefinitions,unitManaDecision,cardInSeatPlayArea,cardPosture,combatEnemyInPlay,currentChoice,choiceCategory,inventorySetChoice,trackerPrivate,sideChoices,combatConfig,selectedResourceByGUID)
    if type(sourceKey)~="string" or gStates==nil then return false end
    local guid=unitHistorySourceBase(sourceKey)
    local abilities=unitResourceDefinitions[guid]
    if abilities~=nil then
        local useIndex=tonumber(sourceKey:match("#use(%d+)$")) or 1
        local group=gStates.unitActivationHistory and gStates.unitActivationHistory[guid]
        local activation=group~=nil and group.uses[useIndex] or nil
        if activation==nil or (seatPos~=nil and activation.seatPos~=seatPos) then return false end
        local unit=getObjectFromGUID(guid)
        if unit==nil then return false end
        local decision=unitManaDecision(unit,abilities,activation,
            activation.frozenCounts or activation.lastCounts)
        local choice=decision.index~=nil and abilities[decision.index] or nil
        return choice~=nil and choice.key=="ready"
    end
    local data=gameCards[guid]
    if data~=nil and data.resourceKey=="artifactDruidicStaff" then
        local card=getObjectFromGUID(guid)
        local current=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
        seatPos=seatPos or (current~=nil and current.seatPos)
        if card==nil or seatPos==nil or not cardInSeatPlayArea(guid,seatPos)
            or cardPosture(card)~="upright" or sourceKey~=guid then return false end
        local scan=resourceCardScanBySeat[seatPos]
        local record=scan~=nil and scan.cards[guid] or nil
        local linkedReady=gStates.unitReadyLinks~=nil
            and gStates.unitReadyLinks[sourceKey]~=nil
        if record==nil or (not record.complete and not (combatEnemyInPlay and linkedReady)) then
            return false
        end
        -- An already-committed pre-combat Ready remains valid during combat,
        -- but a new in-combat Ready is never authorised by the Staff.
        if combatEnemyInPlay and (gStates.unitReadyLinks==nil
            or gStates.unitReadyLinks[sourceKey]==nil) then return false end
        local choices=record.choices
        local _,first=currentChoice(guid,record.powered,choices)
        if record.powered~=true then return first=="red" end
        local remaining={}
        for _,option in ipairs(choices or {}) do
            if choiceCategory(option)~=first then remaining[#remaining+1]=option end
        end
        local _,second=inventorySetChoice(guid,1,remaining,choices)
        return second~=nil and first~=second and (first=="red" or second=="red")
    end
    if data~=nil and data.resourceKey=="artifactBannerCourage" then
        local card=getObjectFromGUID(guid)
        local current=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
        seatPos=seatPos or (current~=nil and current.seatPos)
        if card==nil or seatPos==nil then return false end
        if trackerPrivate.bannerCardForm(guid)=="full"
            and not resourceCardsArtifactBroken(guid,card) then return false end
        if trackerPrivate.bannerCardForm(guid)=="half"
            and card.is_face_down~=true then return false end
        if trackerPrivate.bannerCardForm(guid)=="full" then
            if not cardInSeatPlayArea(guid,seatPos)
                or cardPosture(card)~="upright" then return false end
            local uses=trackerPrivate.bannerEffectUses().courage[guid]
            for _,entry in ipairs(uses~=nil and uses.eligible or {}) do
                if entry.key==sourceKey then return true end
            end
            return false
        end
        if trackerPrivate.bannerCardForm(guid)~="half"
            or sourceKey~=guid then return false end
        -- Unit and play scripting zones overlap near the Banner snap.
        -- A face-down half still authorises exactly its own attached Unit.
        local state=unitLayoutResourceState(seatPos)
        for _,banners in pairs(state~=nil and state.bannersByUnit or {}) do
            if banners["Banner of Courage"]~=nil
                and banners["Banner of Courage"].guid==guid then return true end
        end
        return false
    end
    local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
    if rule==nil or (rule.unitReadyLevels==nil and rule.readyWithInfluence==nil) then return false end
    local card=getObjectFromGUID(guid)
    if card==nil or cardPosture(card)~="upright" then return false end
    local current=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    seatPos=seatPos or (current~=nil and current.seatPos)
    if seatPos==nil or not cardInSeatPlayArea(guid,seatPos) then return false end
    local scan=resourceCardScanBySeat[seatPos]
    local record=scan~=nil and scan.cards[guid] or nil
    if record==nil or record.complete~=true
        or (card.is_face_down==true and record.repeatLink==nil) then return false end
    if rule.readyOutsideCombat==true and combatEnemyInPlay
        and (gStates.unitReadyLinks==nil or gStates.unitReadyLinks[sourceKey]==nil) then return false end
    if rule.unitReadyAlways==true then return sourceKey==guid end
    if rule.readyWithInfluence~=nil then
        local index=tonumber(sourceKey:match("^"..guid.."#ready(%d+)$"))
        local spec=rule.readyWithInfluence
        return record.powered==true and index~=nil and index>=1
            and (spec.maxUses==nil or index<=spec.maxUses)
            and (not spec.requiresAction or record.influenceAction==true)
    end
    if rule.simultaneousReady==true then
        local index=tonumber(sourceKey:match("^"..guid.."#ready(%d+)$"))
        return index~=nil and index>=1 and index<=(record.repeatCount or 1)
            and record.resources~=nil and (tonumber(record.resources.healing) or 0)>0
    end
    local repeatIndex=tonumber(sourceKey:match("^"..guid.."#ready(%d+)$"))
    if record.repeatLink~=nil and repeatIndex~=nil then
        if repeatIndex<1 or repeatIndex>record.repeatLink.count then return false end
        local options=record.repeatLink.options~=nil
            and record.repeatLink.options[repeatIndex]
            or sideChoices(rule,record.powered)
        local _,selected=combatConfig.repeatChoiceFor(guid,record.powered,
            options,repeatIndex)
        return selected=="ready"
    end
    local choice=selectedResourceByGUID[guid]
    return (choice~=nil and choice.effect=="ready")
        or (choice==nil and gStates.unitReadyCardChoices~=nil
            and gStates.unitReadyCardChoices[guid]==true)
end

function M.sourceLevelLimit(sourceKey,seatPos)
    local guid=type(sourceKey)=="string" and unitHistorySourceBase(sourceKey) or nil
    local abilities=guid~=nil and unitResourceDefinitions~=nil and unitResourceDefinitions[guid] or nil
    if abilities~=nil then
        local useIndex=tonumber(sourceKey:match("#use(%d+)$")) or 1
        local group=gStates~=nil and gStates.unitActivationHistory~=nil
            and gStates.unitActivationHistory[guid] or nil
        local activation=group~=nil and group.uses[useIndex] or nil
        local choice=activation~=nil and abilities[activation.choice] or nil
        if choice~=nil and choice.key=="ready" then return choice.readyMaxLevel end
        -- The only currently printed Unit Ready ability is Herbalists.
        -- Read the declared limit even before a choice is persisted.
        for _,ability in ipairs(abilities) do
            if ability.key=="ready" then return ability.readyMaxLevel end
        end
        return nil
    end
    local data=guid~=nil and gameCards[guid] or nil
    local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
    if rule==nil then return nil end
    local current=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    seatPos=seatPos or (current~=nil and current.seatPos)
    local scan=seatPos~=nil and resourceCardScanBySeat[seatPos] or nil
    local record=scan~=nil and scan.cards[guid] or nil
    if rule.unitReadyLevels~=nil then
        return record~=nil and record.powered and rule.unitReadyLevels.powered
            or rule.unitReadyLevels.normal
    end
    return rule.readyWithInfluence~=nil and rule.readyWithInfluence.maxLevel or nil
end

function M.targetEligible(sourceKey,unitGUID,seatPos)
    local guid=type(sourceKey)=="string" and unitHistorySourceBase(sourceKey) or nil
    local data=guid~=nil and gameCards[guid] or nil
    local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
    local limit=M.sourceLevelLimit(sourceKey,seatPos)
    local target=gameCards[unitGUID]
    if limit~=nil and (target==nil or (tonumber(target.level) or math.huge)>limit) then return false end
    if rule==nil or rule.readyWithInfluence==nil then return true end
    if not resourceCardsReadySourceValid(sourceKey,seatPos) then return false end
    local unitData=gameCards[unitGUID]
    local level=unitData~=nil and tonumber(unitData.level) or nil
    if level==nil or level<1 or level>rule.readyWithInfluence.maxLevel then return false end
    local current=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    seatPos=seatPos or (current~=nil and current.seatPos)
    local scan=seatPos~=nil and resourceCardScanBySeat[seatPos] or nil
    if scan==nil then return false end
    local cost=level*rule.readyWithInfluence.costPerLevel
    -- The scan already subtracts every existing Ready payment. A retargeted
    -- existing link can reuse its previous payment instead of paying twice.
    local link=gStates.unitReadyLinks~=nil and gStates.unitReadyLinks[sourceKey] or nil
    local old=link~=nil and gameCards[link.unitGUID] or nil
    local credit=old~=nil and (tonumber(old.level) or 0)
        *rule.readyWithInfluence.costPerLevel or 0
    return resourceOps.influenceBudget(scan.totals,gStates.resourceTracker)+credit>=cost
end

function M.sourceClicked(player,value,id,combatEnemyInPlay,unitResourceDefinitions)
    if not resourceCardsPanelOpen() or not resourceCardsPlayerCanEdit(player~=nil and player.color or nil)
        or type(id)~="string" then return end
    local guid,suffix=id:match("^AttackAssignmentSource_([0-9a-f]+)_0_unitReady(.*)$")
    if guid==nil then return end
    local useIndex=tonumber(suffix:match("^@use(%d+)$"))
    if suffix~="" and useIndex==nil then return end
    local sourceKey=unitHistoryKey(guid,useIndex or 1)
    local data=gameCards~=nil and gameCards[guid] or nil
    local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
    if combatEnemyInPlay and rule~=nil
        and (data.resourceKey=="artifactDruidicStaff" or rule.readyOutsideCombat==true) then return end
    if not resourceCardsReadySourceValid(sourceKey) then return end
    local limit=resourceCardsReadySourceLevelLimit(sourceKey)
    attackAssignmentsBeginUnitReady(guid,sourceKey,player.color,limit)
end

return M

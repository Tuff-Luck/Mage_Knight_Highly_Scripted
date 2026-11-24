-- Relevant-zone filtering, played-source pickup/drop reconciliation, native Place Under, delayed choice reset and missing-control repair. Delayed callbacks resolve replaceable tables through live accessors.
local M={}

function M.scheduleChoiceReset(guid,seatPos,getChoices,getExpanded,trackerPrivate,cardInSeatPlayArea)
    if guid==nil or seatPos==nil then return end
    -- Avoid physics waits for mana, enemies and unrelated play-area objects.
    if getChoices()[guid]==nil and (gStates==nil
        or ((gStates.artifactBreaks==nil or gStates.artifactBreaks[guid]==nil)
            and (gStates.artifactGrailHealingUsed==nil
                or gStates.artifactGrailHealingUsed[guid]==nil)
            and (gStates.resourceCardPlayOrder==nil
                or gStates.resourceCardPlayOrder[guid]==nil)
            and (gStates.resourceCardMoveRoles==nil
                or gStates.resourceCardMoveRoles[guid]==nil))) then return end
    trackerPrivate.choiceResetGenerationByGUID[guid]=(trackerPrivate.choiceResetGenerationByGUID[guid] or 0)+1
    local serial=trackerPrivate.choiceResetGenerationByGUID[guid]
    -- On release, check X/Z instead of waiting for the shallow zone's Y
    -- membership to catch up with a card that is still falling.
    safeWaitFrames("PlayerBoard.CardRecognition",function()
        if trackerPrivate.choiceResetGenerationByGUID[guid]~=serial then return end
        safeWaitCondition("PlayerBoard.CardRecognition",function()
            if trackerPrivate.choiceResetGenerationByGUID[guid]~=serial then return end
            if not cardInSeatPlayArea(guid,seatPos) then
                -- A genuine departure retires this play's time-order slot;
                -- moving a card in/out again starts a fresh play sequence.
                if gStates~=nil and gStates.resourceCardPlayOrder~=nil then
                    gStates.resourceCardPlayOrder[guid]=nil
                end
                getChoices()[guid]=nil
                if gStates~=nil and gStates.resourceCardMoveRoles~=nil then
                    gStates.resourceCardMoveRoles[guid]=nil
                end
                -- A genuinely departed conversion card starts fresh on replay.
                local kind=guid=="878d92" and "agility" or guid=="8c3de6" and "diplomacy" or nil
                local conversions=gStates~=nil and gStates.resourceCardConversions or nil
                local seat=type(conversions)=="table" and conversions[tostring(seatPos)] or nil
                if kind~=nil and type(seat)=="table" then seat[kind]=nil end
                getExpanded()[guid]=nil
                resourceCardsArtifactBreakClear(guid)
                if gStates~=nil and gStates.artifactGrailHealingUsed~=nil then
                    gStates.artifactGrailHealingUsed[guid]=nil
                end
                if gStates~=nil and gStates.unitReadyCardChoices~=nil then
                    gStates.unitReadyCardChoices[guid]=nil
                end
                unitHistoryValidSources(seatPos)
            end
        end,function()
            if trackerPrivate.choiceResetGenerationByGUID[guid]~=serial then return true end
            local obj=getObjectFromGUID(guid)
            return obj==nil or (trackerPrivate.playCardMovements[guid]==nil
                and trackerPrivate.readyForXZ(obj))
        end,8)
    end,1)
end

function M.relevantZone(ctx,resourceObjectKind,combatEnemyData)
    if ctx==nil or ctx.zoneInfo==nil or ctx.obj==nil then return nil end
    -- The tracker only renders the active Mage Knight's board; ignore other seats early.
    local active=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    if active==nil or active.seatPos~=ctx.zoneInfo.seatPos then return nil end
    local kind=ctx.zoneInfo.kind
    -- A moving die is mana even though its face cannot yet be read safely.
    local objectKind=(ctx.objType=="Dice" and scriptObjectId(ctx.obj)=="Mana Dice")
        and "mana" or resourceObjectKind(ctx.obj)
    if kind=="play" and (objectKind~=nil or combatEnemyData(ctx.objGUID,ctx.obj)~=nil) then
        return ctx.zoneInfo.seatPos
    end
    if kind=="unit" and (objectKind=="unit" or objectKind=="mana" or objectKind=="puppet"
        or combatEnemyData(ctx.objGUID,ctx.obj)~=nil
        or unitLayoutIsCommand(ctx.obj) or unitLayoutIsWound(ctx.obj)) then
        return ctx.zoneInfo.seatPos
    end
    if kind=="crystal" and objectKind=="mana" then return ctx.zoneInfo.seatPos end
    if kind=="hand" and objectKind=="wound" then return ctx.zoneInfo.seatPos end
    return nil
end

function M.pickedUp(obj,trackerPrivate,resourceObjectKind,cardInSeatPlayArea,combatAssignmentState,selectedResourceByGUID,cardPosture)
    if obj==nil or obj.guid==nil or not resourceCardsPanelOpen()
        or not trackerPrivate.playCandidateKind(resourceObjectKind(obj)) then return end
    local active=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    if active==nil then return end
    local seat=active.seatPos
    local candidates=trackerPrivate.playCandidatesBySeat[seat]
    local previous=trackerPrivate.bySeat[seat]
    if (candidates~=nil and candidates[obj.guid]==true)
        or (previous~=nil and previous[obj.guid]==true)
        or cardInSeatPlayArea(obj.guid,seat) then
        -- A second pickup invalidates the first drop's pending callbacks.
        -- Capture what the player actually chose; a scan must not replace
        -- these choices or enemy targets with the nearest/default ones.
        local savedTargets={}
        local prefix=obj.guid.."#"
        for sourceKey,targetGUID in pairs(combatAssignmentState.targets or {}) do
            if sourceKey==obj.guid or sourceKey:sub(1,#prefix)==prefix then
                savedTargets[sourceKey]={targetGUID=targetGUID,
                    explicit=combatAssignmentState.explicit[sourceKey]==true}
            end
        end
        trackerPrivate.playCardMovements[obj.guid]={
            seatPos=seat,choice=selectedResourceByGUID[obj.guid],
            targets=savedTargets,posture=cardPosture(obj),
            faceDown=obj.is_face_down
        }
        if trackerPrivate.traceEnabled then
            trackerPrivate.traceEvent("move.pickup",seat,obj.guid,
                "held="..tostring(obj.held_by_color))
        end
        -- A normal Drop is not guaranteed (e.g. the native U/Place Under
        -- action). Watch every known pickup until the object is released.
        trackerPrivate.finishPlayCardMove(obj)
    end
end

function M.restoreMove(obj,state,cardInSeatPlayArea,selectedResourceByGUID,cardPosture,combatAssignmentState)
    if state==nil or obj==nil
        or not cardInSeatPlayArea(obj.guid,state.seatPos) then return end
    if state.choice~=nil then
        selectedResourceByGUID[obj.guid]=state.choice
    end
    if state.posture~=cardPosture(obj)
        or state.faceDown~=obj.is_face_down then return end
    for sourceKey,saved in pairs(state.targets or {}) do
        if saved.targetGUID~=nil then
            combatAssignmentState.targets[sourceKey]=saved.targetGUID
            combatAssignmentState.explicit[sourceKey]=saved.explicit
        end
    end
end

function M.finishMove(obj,trackerPrivate,queueSeat,cardInSeatPlayArea)
    local state=obj~=nil and trackerPrivate.playCardMovements[obj.guid] or nil
    if state==nil or state.releasing then return end
    state.releasing=true
    state.samples=0
    state.consecutive=0
    state.last=nil
    local guid=obj.guid
    if trackerPrivate.traceEnabled then trackerPrivate.traceEvent("move.watch",state.seatPos,guid) end
    local function sample()
        if trackerPrivate.playCardMovements[guid]~=state then return end
        local live=getObjectFromGUID(guid)
        if live==nil or (live.isDestroyed~=nil and live.isDestroyed()) then
            trackerPrivate.playCardMovements[guid]=nil
            if trackerPrivate.traceEnabled then trackerPrivate.traceEvent("move.gone",state.seatPos,guid) end
            queueSeat(state.seatPos,nil)
            return
        end
        state.samples=state.samples+1
        local held=live.held_by_color~=nil and live.held_by_color~=""
        local smooth=live.isSmoothMoving()
        if held or smooth then
            -- Never abandon the watcher with the movement lock still set.
            -- A missed onObjectDrop (notably U/Place Under) must not freeze
            -- every future option button and combat calculator refresh.
            if trackerPrivate.traceEnabled and (state.samples==1 or state.samples%90==0) then
                trackerPrivate.traceEvent("move.wait",state.seatPos,guid,
                    "held="..tostring(held).." smooth="..tostring(smooth)
                    .." samples="..state.samples)
            end
            safeWaitFrames("PlayerBoard.CardRecognition",sample,held and 6 or 3)
            return
        end
        local pos=live.getPosition()
        local rot=live.getRotation()
        local now={x=pos.x or pos[1],z=pos.z or pos[3],
            rx=rot.x or rot[1],ry=rot.y or rot[2],rz=rot.z or rot[3],
            face=live.is_face_down}
        local previous=state.last
        local function angleDifference(a,b)
            return math.abs(((a or 0)-(b or 0)+180)%360-180)
        end
        if previous~=nil
            and math.abs(now.x-previous.x)<0.04
            and math.abs(now.z-previous.z)<0.04
            and angleDifference(now.rx,previous.rx)<1
            and angleDifference(now.ry,previous.ry)<1
            and angleDifference(now.rz,previous.rz)<1
            and now.face==previous.face then
            state.consecutive=state.consecutive+1
        else
            state.consecutive=0
        end
        state.last=now
        if state.consecutive<2 and state.samples<24 then
            safeWaitFrames("PlayerBoard.CardRecognition",sample,1)
            return
        end
        trackerPrivate.restorePlayCardMove(live,state)
        trackerPrivate.playCardMovements[guid]=nil
        if trackerPrivate.traceEnabled then
            trackerPrivate.traceEvent("move.complete",state.seatPos,guid,
                "samples="..state.samples.." onMat="..tostring(cardInSeatPlayArea(guid,state.seatPos)))
        end
        -- Resume a single complete scan; normal drop handling determines
        -- whether this was a reposition or a genuine departure from play.
        resourceCardsObjectMoved(live,true)
        queueSeat(state.seatPos,nil)
    end
    safeWaitFrames("PlayerBoard.CardRecognition",sample,1)
end

function M.underAction(targets,trackerPrivate,resourceObjectKind,queueSeat)
    if not resourceCardsPanelOpen() then return end
    local active=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    local seat=active~=nil and active.seatPos or nil
    local zoneGUID=seat~=nil and playerPlayAreas~=nil and playerPlayAreas[seat] or nil
    local playZone=zoneGUID~=nil and getObjectFromGUID(zoneGUID) or nil
    local guids,playedCardUnder={},false
    for _,obj in ipairs(targets or {}) do
        if obj~=nil and obj.guid~=nil then
            guids[#guids+1]=obj.guid
            if playZone~=nil and trackerPrivate.playCandidateKind(resourceObjectKind(obj))
                and trackerPrivate.zoneFootprintContainsXZ(obj,playZone) then
                playedCardUnder=true
            end
            if trackerPrivate.traceEnabled then
                trackerPrivate.traceEvent("action.under",seat,obj.guid)
            end
            resourceCardsObjectPickedUp(obj)
        end
    end
    if #guids==0 then return end
    local session=trackerPrivate.trackerSession
    safeWaitFrames("PlayerBoard.CardRecognition",function()
        if trackerPrivate.trackerSession~=session or not resourceCardsPanelOpen() then return end
        for _,guid in ipairs(guids) do
            local obj=getObjectFromGUID(guid)
            if obj~=nil and (obj.isDestroyed==nil or not obj.isDestroyed()) then
                resourceCardsObjectMoved(obj)
            end
        end
        -- Native Under can jostle dice without a drop/zone callback. Resample
        -- the live play zone after delayed physics; outside mana never pays.
        if playedCardUnder and seat~=nil then
            local function queueZoneDice()
                local zone=getObjectFromGUID(zoneGUID)
                if zone==nil then return end
                for _,obj in ipairs(zone.getObjects()) do
                    if obj.type=="Dice" and scriptObjectId(obj)=="Mana Dice" then
                        queueSeat(seat,obj.guid)
                    end
                end
            end
            queueZoneDice()
            safeWaitFrames("PlayerBoard.CardRecognition",function()
                if trackerPrivate.trackerSession~=session
                    or not resourceCardsPanelOpen() then return end
                queueZoneDice()
                resourceCardsSourceChanged()
            end,22)
        end
        resourceCardsSourceChanged()
    end,2)
end

function M.zoneEntered(ctx,trackerPrivate,resourceCardsRelevantZone,resourceObjectKind,queueSeat)
    if not resourceCardsPanelOpen() or ctx==nil or ctx.zoneInfo==nil then return end
    -- Filter irrelevant zones and other players before touching the Unit layout.
    local seat=resourceCardsRelevantZone(ctx)
    if seat==nil then return end
    if trackerPrivate.traceEnabled then
        trackerPrivate.traceEvent("zone.enter",seat,ctx.objGUID,ctx.zoneInfo.kind)
    end
    if ctx.zoneInfo.kind=="play" and ctx.objType~="Dice"
        and trackerPrivate.playCandidateKind(resourceObjectKind(ctx.obj)) then
        -- A returned card invalidates any delayed choice-clear queued by its
        -- earlier onExitZone. The exit callback must never win after reentry.
        trackerPrivate.choiceResetGenerationByGUID[ctx.objGUID]=
            (trackerPrivate.choiceResetGenerationByGUID[ctx.objGUID] or 0)+1
        trackerPrivate.playCandidatesBySeat[seat]=trackerPrivate.playCandidatesBySeat[seat] or {}
        local candidates=trackerPrivate.playCandidatesBySeat[seat]
        local previous=trackerPrivate.bySeat[seat]
        local alreadyPlayed=candidates[ctx.objGUID]==true
            or (previous~=nil and previous[ctx.objGUID]==true)
            or trackerPrivate.playCardMovements[ctx.objGUID]~=nil
        candidates[ctx.objGUID]=true
        if alreadyPlayed then
            if trackerPrivate.traceEnabled then trackerPrivate.traceEvent("zone.reentry",seat,ctx.objGUID) end
            -- TTS emits EnterZone again when a relocated card falls through
            -- the thin zone. That is not a new play or another pickup.
            -- onObjectDrop owns its one reconciliation, even if the zone
            -- entry happens before the drop's final callback.
            return
        end
        -- For a genuinely new play, queue its first scan normally. Do not
        -- infer an ObjectPickUp from resting=false on zone entry.
    end
    if ctx.zoneInfo.kind=="play" and gameCards[ctx.objGUID]~=nil
        and gStates~=nil then
        gStates.resourceCardPlayOrder=gStates.resourceCardPlayOrder or {}
        if gStates.resourceCardPlayOrder[ctx.objGUID]==nil then
            gStates.resourceCardPlaySerial=(gStates.resourceCardPlaySerial or 0)+1
            gStates.resourceCardPlayOrder[ctx.objGUID]=gStates.resourceCardPlaySerial
        end
    end
    queueSeat(seat,ctx.objGUID)
end

function M.zoneLeft(ctx,trackerPrivate,resourceCardsRelevantZone,resourceObjectKind,combatConfig,cardInSeatPlayArea,scheduleChoiceResetAfterPlay,queueSeat)
    if not resourceCardsPanelOpen() or ctx==nil or ctx.zoneInfo==nil then return end
    local seat=resourceCardsRelevantZone(ctx)
    if trackerPrivate.traceEnabled then
        trackerPrivate.traceEvent("zone.leave",seat,ctx.objGUID,ctx.zoneInfo.kind)
    end
    if ctx.zoneInfo.kind=="play" then
        if ctx.obj~=nil and trackerPrivate.playCandidateKind(resourceObjectKind(ctx.obj))
            and (combatConfig.cardInTransit(ctx.obj)
                or cardInSeatPlayArea(ctx.objGUID,ctx.zoneInfo.seatPos)) then
            -- This is a transient exit of a card still being moved or
            -- physically over the play mat, not an ended play. Crucially,
            -- do not schedule a delayed choice reset here: onDrop owns the
            -- final departure check, and reentry may occur after the timer.
            if trackerPrivate.traceEnabled then trackerPrivate.traceEvent("zone.leave-transit",seat,ctx.objGUID) end
            return
        end
        scheduleChoiceResetAfterPlay(ctx.objGUID,ctx.zoneInfo.seatPos)
    end
    if seat==nil then return end
    queueSeat(seat,ctx.objGUID)
end

function M.checkChoicesAfterDrop(guid,seatPos,trackerPrivate,cardInSeatPlayArea,combatConfig,getChoiceButtonShown,queueSeat)
    if guid==nil or seatPos==nil then return end
    local serial=(trackerPrivate.cardUIRecheckSerial[guid] or 0)+1
    trackerPrivate.cardUIRecheckSerial[guid]=serial
    local session=trackerPrivate.trackerSession
    local function verify(attempt)
        if trackerPrivate.cardUIRecheckSerial[guid]~=serial
            or trackerPrivate.trackerSession~=session
            or not resourceCardsPanelOpen() then return end
        local card=getObjectFromGUID(guid)
        if card==nil or (card.isDestroyed~=nil and card.isDestroyed())
            or not cardInSeatPlayArea(guid,seatPos) then return end
        if not combatConfig.cardInTransit(card) then
            local expected=combatConfig.cardButtonIds[guid]
            if getChoiceButtonShown()[guid]~=nil and getChoiceButtonShown()[guid]~="hidden"
                and expected~=nil and #expected>0
                and not combatConfig.cardChoicesPresent(card) then
                if trackerPrivate.traceEnabled then
                    trackerPrivate.traceEvent("choice.repair",seatPos,guid,
                        "attempt="..tostring(attempt).." expected="..tostring(#expected))
                end
                queueSeat(seatPos,guid)
            end
        end
        if attempt==1 then
            -- Catch a late overwrite from TTS/another card-UI owner, without
            -- permanently polling every card in the play area.
            safeWaitFrames("PlayerBoard.CardRecognition",function() verify(2) end,12)
        end
    end
    safeWaitFrames("PlayerBoard.CardRecognition",function() verify(1) end,5)
end

function M.objectMoved(obj,stabilized,trackerPrivate,resourceObjectKind,manaColor,queueSeat,combatEnemyData,cardInSeatPlayArea,scheduleChoiceResetAfterPlay,combatTrackedSeat,combatTrackedEnemies)
    if obj==nil or not resourceCardsPanelOpen() then return end
    if trackerPrivate.traceEnabled then
        trackerPrivate.traceEvent("object.moved",nil,obj.guid,
            "stable="..tostring(stabilized).." held="..tostring(obj.held_by_color))
    end
    -- Some entries are reported only after the card is dropped. Protect that
    -- first scan too, even if no pickup/enter event registered the movement.
    if not stabilized and obj.type~="Dice" and obj.resting==false
        and trackerPrivate.playCardMovements[obj.guid]==nil
        and trackerPrivate.playCandidateKind(resourceObjectKind(obj)) then
        resourceCardsObjectPickedUp(obj)
    end
    -- Drop callbacks can arrive before the card's final rotation or before
    -- the shallow zone knows it is back. Keep the calculator unchanged.
    if trackerPrivate.playCardMovements[obj.guid]~=nil then
        trackerPrivate.finishPlayCardMove(obj)
        return
    end
    local player=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    if player==nil then return end
    local seat=player.seatPos
    if (obj.type=="Dice" and scriptObjectId(obj)=="Mana Dice") or manaColor(obj)~=nil then
        -- Reconcile removal as well as arrival; the scan reads current zones.
        queueSeat(seat,obj.guid)
        return
    end
    local isUnitStateToken=unitLayoutIsCommand(obj) or unitLayoutIsWound(obj)
    local isMonster=combatEnemyData(obj.guid,obj)~=nil
    local objectKind=resourceObjectKind(obj)
    if objectKind==nil and not isUnitStateToken and not isMonster then
        -- A played powered One with the Land may change Block value when the
        -- Mage Knight moves to different terrain. Only watch avatar drops
        -- while that exact effect is selected; no continual background scan.
        local scan=resourceCardScanBySeat[seat]
        if scan~=nil and (scan.usesCurrentHexBlock==true
            or scan.usesCurrentHexHealing==true or scan.usesSkillLocation==true) then
            for _,hero in ipairs(mageKnights or {}) do
                if hero.mage==player.mage and
                    (obj.guid==hero.model or obj.guid==hero.token or obj.guid==hero.standee) then
                    queueSeat(seat,obj.guid)
                    return
                end
            end
        end
        return
    end
    -- Already-observed sources always need a settled reconciliation, even
    -- when dropped just above a shallow zone. Avoid searching four zones to
    -- discover information the last scan already provided.
    local observed=trackerPrivate.bySeat[seat]
    -- The drop event can precede the shallow zone's physical re-entry.
    -- Keep the previously played source (and its explicit choices/target)
    -- when its released X/Z is still over this mat.
    if trackerPrivate.playCandidateKind(objectKind) then
        local candidates=trackerPrivate.playCandidatesBySeat[seat] or {}
        local known=candidates[obj.guid]==true
        local inPlay=cardInSeatPlayArea(obj.guid,seat)
        if inPlay then
            candidates[obj.guid]=true
            trackerPrivate.playCandidatesBySeat[seat]=candidates
        elseif known then
            candidates[obj.guid]=nil
            scheduleChoiceResetAfterPlay(obj.guid,seat)
        end
        if inPlay or known then
            queueSeat(seat,obj.guid)
            if inPlay then trackerPrivate.checkCardChoicesAfterDrop(obj.guid,seat) end
            return
        end
    end
    if observed~=nil and observed[obj.guid]==true then
        if (objectKind=="card" or objectKind=="skill" or objectKind=="factionReward")
            and not cardInSeatPlayArea(obj.guid,seat) then
            scheduleChoiceResetAfterPlay(obj.guid,seat)
        end
        queueSeat(seat,obj.guid)
        if trackerPrivate.playCandidateKind(objectKind)
            and cardInSeatPlayArea(obj.guid,seat) then
            trackerPrivate.checkCardChoicesAfterDrop(obj.guid,seat)
        end
        return
    end
    -- New arrivals only need zones that can actually hold their resource type.
    -- Mana/dice have already taken the dedicated early path above.
    local relevantZones
    if isMonster or isUnitStateToken or objectKind=="unit" or objectKind=="puppet" then
        relevantZones={playerPlayAreas[seat],playerUnitAreas[seat]}
    elseif objectKind=="wound" then
        relevantZones={playerPlayAreas[seat],playerUnitAreas[seat],handZones[seat]}
    else
        relevantZones={playerPlayAreas[seat]}
    end
    for _,zoneGUID in ipairs(relevantZones) do
        local zone=zoneGUID~=nil and getObjectFromGUID(zoneGUID) or nil
        if zone~=nil then
            for _,candidate in ipairs(zone.getObjects()) do
                if candidate.guid==obj.guid then queueSeat(seat,obj.guid) return end
            end
        end
    end
    if (isMonster and combatTrackedSeat==seat and combatTrackedEnemies[obj.guid]~=nil)
        or isUnitStateToken or (isMonster and trackerPrivate.bySeat[seat]~=nil
        and trackerPrivate.bySeat[seat][obj.guid]==true) then
        -- On a drop outside the zones, wait for the token to settle before
        -- checking membership. Otherwise smooth movement can retain a ghost
        -- indefinitely if no further zone event fires.
        queueSeat(seat,isMonster and obj.guid or nil)
    elseif trackerPrivate.bySeat[seat]~=nil and trackerPrivate.bySeat[seat][obj.guid]==true then
        scheduleChoiceResetAfterPlay(obj.guid,seat)
        -- Wait for this specific card to settle before reconciling its XML.
        -- An immediate scan could run while TTS is still clearing its UI.
        queueSeat(seat,obj.guid)
    end
end

return M

-- Manual per-seat presentation scale for the Play and Unit Areas.
-- The scale never changes the logical resource/combat values of an object.
local playAreaScaleWait={}
local SCALE_BUTTONS={playAreaScaleDown=true,playAreaScaleLabel=true,playAreaScaleUp=true,playAreaScaleScope=true}
local playAreaScaleSettling={} -- runtime-only; one pending settle check per object

local function playAreaScaleSettings(seat)
    gStates.playAreaScaleSettings=gStates.playAreaScaleSettings or {}
    local value=gStates.playAreaScaleSettings[seat]
    if value==nil then value={step=20,scope="Cards"} gStates.playAreaScaleSettings[seat]=value end
    value.step=math.max(12,math.min(20,math.floor(tonumber(value.step) or 20)))
    if value.scope~="All" then value.scope="Cards" end
    return value
end

local function playAreaScaleRecord()
    gStates.playAreaScaledObjects=gStates.playAreaScaledObjects or {}
    return gStates.playAreaScaledObjects
end

local function playAreaScaleInZone(guid,zoneGUID)
    local zone=zoneGUID~=nil and getObjectFromGUID(zoneGUID) or nil
    if zone~=nil then for _,obj in ipairs(zone.getObjects()) do if obj.guid==guid then return true end end end
    return false
end

local function playAreaScaleSeatContaining(guid)
    for seat=1,4 do
        if playAreaScaleInZone(guid,playerPlayAreas[seat])
            or playAreaScaleInZone(guid,playerUnitAreas[seat]) then return seat end
    end
    return nil
end

local function playAreaScaleObjectHeld(obj)
    if obj.held_by_color~=nil then return true end
    -- A Fixed-jointed summon may leave its zone while its summoner is held,
    -- even though TTS does not report the child as held itself.
    local attacked=gStates~=nil and gStates.attackedMonsters~=nil and gStates.attackedMonsters[obj.guid] or nil
    if attacked~=nil and attacked[3]=="summoned" and attacked[4]~=nil then
        local summoner=getObjectFromGUID(attacked[4])
        if summoner~=nil and summoner.held_by_color~=nil then return true end
    end
    return false
end

local function playAreaScaleEligible(seat,obj,scope)
    if obj==nil or obj.guid==nil then return false end
    -- The board and its zones are fixtures, not played components.
    if obj.type=="ScriptingTrigger" or obj.type=="HandTrigger" or obj.type=="Board"
        or obj.type=="Bag" or obj.type=="Infinite" then return false end
    for _,guid in ipairs(playerBoard) do if obj.guid==guid then return false end end
    for _,guid in ipairs(colorBand) do if obj.guid==guid then return false end end
    if unitLayoutIsUnit(obj) or unitLayoutIsWound(obj)
        or obj.hasTag("CombatPreviewWound") or obj.getGMNotes()=="Combat Preview Wound" then return false end
    -- A loose Wound in the Unit Area may be about to become a Unit Wound.
    if obj.getGMNotes()=="Wound" and playAreaScaleInZone(obj.guid,playerUnitAreas[seat]) then return false end
    return scope=="All" or obj.type=="Card" or obj.type=="Deck"
end

local function playAreaScaleComponents(scale)
    return {scale.x or scale[1],scale.y or scale[2],scale.z or scale[3]}
end

local function playAreaScaleRestore(obj)
    local records=playAreaScaleRecord()
    local entry=obj~=nil and records[obj.guid] or nil
    if entry==nil then return end
    -- An external effect or manual resize while scaled becomes the new natural size.
    local current=playAreaScaleComponents(obj.getScale())
    local previous=entry.factor or 1
    if math.abs(current[1]-entry.base[1]*previous)>0.015
        or math.abs(current[2]-entry.base[2]*previous)>0.015
        or math.abs(current[3]-entry.base[3]*previous)>0.015 then
        entry.base={current[1]/previous,current[2]/previous,current[3]/previous}
    end
    obj.setScale(entry.base)
    records[obj.guid]=nil
end

-- Combat cleanup restores the pre-summon size itself; forget only the play-area multiplier.
function playAreaScaleForgetObject(obj)
    if obj~=nil and obj.guid~=nil then playAreaScaleRecord()[obj.guid]=nil end
end

function playAreaScaleApplyObject(seat,obj,pending)
    if gStates==nil or seat==nil or obj==nil or obj.guid==nil then return end
    local setting=playAreaScaleSettings(seat)
    local records=playAreaScaleRecord()
    local entry=records[obj.guid]
    if not playAreaScaleEligible(seat,obj,setting.scope) then
        if entry~=nil and entry.seat==seat then playAreaScaleRestore(obj) end
        return
    end
    local factor=setting.step/20
    if entry==nil and factor==1 then return end
    local current=playAreaScaleComponents(obj.getScale())
    if entry==nil then
        entry={base=current,seat=seat,factor=1,pending=pending==true}
        records[obj.guid]=entry
    else
        local prev=entry.factor or 1
        if math.abs(current[1]-entry.base[1]*prev)>0.015
            or math.abs(current[2]-entry.base[2]*prev)>0.015
            or math.abs(current[3]-entry.base[3]*prev)>0.015 then
            entry.base={current[1]/prev,current[2]/prev,current[3]/prev}
        end
        entry.seat=seat
        entry.pending=pending==true
    end
    local target={entry.base[1]*factor,entry.base[2]*factor,entry.base[3]*factor}
    if math.abs(current[1]-target[1])>0.005 or math.abs(current[2]-target[2])>0.005
        or math.abs(current[3]-target[3])>0.005 then obj.setScale(target) end
    if factor==1 then records[obj.guid]=nil else entry.factor=factor end
end

-- A transient exit during a drag is not a real removal. Recheck the
-- object's destination after it is dropped and the physics have settled.
local function playAreaScaleRecheckObject(guid)
    local records=gStates~=nil and gStates.playAreaScaledObjects or nil
    if records==nil or records[guid]==nil then return end
    local obj=getObjectFromGUID(guid)
    if obj==nil then records[guid]=nil return end
    if playAreaScaleObjectHeld(obj) or obj.isSmoothMoving()==true then return end
    local seat=playAreaScaleSeatContaining(guid)
    if seat~=nil then playAreaScaleApplyObject(seat,obj)
    else playAreaScaleRestore(obj) end
end

local function playAreaScaleWaitForSettle(guid)
    if playAreaScaleSettling[guid]==true then return end
    playAreaScaleSettling[guid]=true
    local function finish()
        playAreaScaleSettling[guid]=nil
        playAreaScaleRecheckObject(guid)
    end
    safeWaitCondition("PlayerBoard.Scale",finish,function()
        local obj=getObjectFromGUID(guid)
        return obj==nil or (not playAreaScaleObjectHeld(obj)
            and obj.resting==true and obj.isSmoothMoving()==false)
    end,5,finish)
end

-- Only objects already managed by the scaling system need a post-drop check.
function playAreaScaleObjectDropped(obj)
    if obj~=nil and obj.guid~=nil and gStates~=nil
        and gStates.playAreaScaledObjects~=nil
        and gStates.playAreaScaledObjects[obj.guid]~=nil then
        playAreaScaleWaitForSettle(obj.guid)
    end
end

function refreshPlayAreaScale(seat)
    if gStates==nil or seat==nil then return end
    local seen={}
    for _,zoneGUID in ipairs({playerPlayAreas[seat],playerUnitAreas[seat]}) do
        local zone=zoneGUID~=nil and getObjectFromGUID(zoneGUID) or nil
        if zone~=nil then
            for _,obj in ipairs(zone.getObjects()) do
                if seen[obj.guid]~=true then
                    seen[obj.guid]=true
                    playAreaScaleApplyObject(seat,obj)
                end
            end
        end
    end
    -- Only objects that genuinely left both zones return to their natural size.
    local records=playAreaScaleRecord()
    for guid,entry in pairs(records) do
        if entry.seat==seat and seen[guid]~=true then
            local obj=getObjectFromGUID(guid)
            if obj==nil then records[guid]=nil
            elseif playAreaScaleObjectHeld(obj) then
                -- Lifting/rearranging does not undo scaling; the drop checks its destination.
            elseif obj.isSmoothMoving()==true then
                -- Scripted moves keep the same size until they reach their destination.
                playAreaScaleWaitForSettle(guid)
            else
                playAreaScaleRestore(obj)
            end
        end
    end
end

function schedulePlayAreaScale(seat)
    if seat==nil then return end
    if playAreaScaleWait[seat]~=nil then Wait.stop(playAreaScaleWait[seat]) end
    playAreaScaleWait[seat]=safeWaitFrames("PlayerBoard.Scale",function()
        playAreaScaleWait[seat]=nil
        refreshPlayAreaScale(seat)
    end,3)
end

local function playAreaScaleSeat(board)
    if board==nil or board.guid==nil then return nil end
    for seat,guid in ipairs(playerBoard) do if guid==board.guid then return seat end end
    return nil
end

local function playAreaScaleCanEdit(seat,playerColor)
    if seat==nil or gStates==nil or turnOrder==nil then return false end
    if turnOrderIndexAtSeat(seat)==nil then return false end
    local hand=Hands.getHands()[seat]
    if hand==nil then return false end
    return legalPlayerCheck(playerColor,gStates.handColors[hand.getValue()],"NoDummyException")==true
end

local function playAreaScaleChange(board,playerColor,delta,scopeToggle)
    local seat=playAreaScaleSeat(board)
    if not playAreaScaleCanEdit(seat,playerColor) then return end
    local setting=playAreaScaleSettings(seat)
    if scopeToggle==true then
        setting.scope=setting.scope=="Cards" and "All" or "Cards"
    else
        local step=math.max(12,math.min(20,setting.step+delta))
        if step==setting.step then return end
        setting.step=step
    end
    refreshPlayAreaScale(seat)
    refreshPlayAreaScaleControls()
end

function playAreaScaleDown(board,playerColor,altClick)
    return safeCallback("playAreaScaleDown",function() playAreaScaleChange(board,playerColor,-1,false) end)
end
function playAreaScaleUp(board,playerColor,altClick)
    return safeCallback("playAreaScaleUp",function() playAreaScaleChange(board,playerColor,1,false) end)
end
function playAreaScaleScope(board,playerColor,altClick)
    return safeCallback("playAreaScaleScope",function() playAreaScaleChange(board,playerColor,0,true) end)
end
function playAreaScaleLabel(board,playerColor,altClick) end

local function playAreaScaleBoardButtons(board,seat)
    local existing=board.getButtons() or {}
    for i=#existing,1,-1 do
        if SCALE_BUTTONS[existing[i].click_function]==true then board.removeButton(existing[i].index) end
    end
    if turnOrderIndexAtSeat(seat)==nil then return end
    local setting=playAreaScaleSettings(seat)
    local bounds=board.getBounds()
    local pos=board.getPosition()
    local scale=board.getScale()
    -- Place a single small row at the bottom-right WORLD edge. positionToLocal
    -- accounts for the stock mats' 180-degree rotation and their large object scale.
    local edgeX=pos.x+bounds.size.x/2-0.55
    local rowZ=pos.z-bounds.size.z/2+0.85
    local topY=bounds.center.y+bounds.size.y/2+0.07
    local yaw=board.getRotation().y or 0
    local rotation={0,(360-yaw)%360,0}
    local sx=math.max(0.01,scale.x or scale[1])
    local sz=math.max(0.01,scale.z or scale[3])
    -- TTS clamps classic button dimensions below 60 (except zero). Counter-scale the
    -- button instead of shrinking width/height below that minimum on an 8.2-scale mat.
    local buttonScale=1/math.max(sx,sz)
    local function add(label,callback,offset,width,background)
        local localPos=board.positionToLocal({edgeX+offset,topY,rowZ})
        board.createButton({
            click_function=callback,function_owner=Global,label=label,
            position={localPos.x,localPos.y,localPos.z},rotation=rotation,
            scale={buttonScale,buttonScale,buttonScale},
            width=background and math.floor(width*100+0.5) or 0,height=background and 85 or 0,
            font_size=70,font_color={0.98,0.94,0.84},
            color=background and {0.10,0.10,0.10,0.80} or {0,0,0,0},
            hover_color={0.22,0.22,0.22,0.85},press_color={0.3,0.3,0.3,0.8}
        })
    end
    add("<","playAreaScaleDown",-5.7,0.8,true)
    add(tostring(setting.step*5).."%","playAreaScaleLabel",-4.25,2.2,false)
    add(">","playAreaScaleUp",-2.8,0.8,true)
    add(setting.scope,"playAreaScaleScope",-1.1,2.1,true)
end

function refreshPlayAreaScaleControls()
    if gStates==nil or turnOrder==nil then return end
    for seat,boardGUID in ipairs(playerBoard) do
        local board=getObjectFromGUID(boardGUID)
        if board~=nil then playAreaScaleBoardButtons(board,seat) end
    end
end

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

-- Object-attached XML UI, matching the colour-bar image-button convention.
-- Board placement is calculated only on installation, never on a player click.
local function playAreaScaleControlPrefix(seat)
    return "PlayAreaScale"..tostring(seat)
end

local function playAreaScaleCanEdit(seat,playerColor)
    if seat==nil or gStates==nil or turnOrder==nil then return false end
    if turnOrderIndexAtSeat(seat)==nil then return false end
    local hand=Hands.getHands()[seat]
    if hand==nil then return false end
    return legalPlayerCheck(playerColor,gStates.handColors[hand.getValue()],"NoDummyException")==true
end

local function playAreaScaleUpdateLabels(board,seat)
    local setting=playAreaScaleSettings(seat)
    local prefix=playAreaScaleControlPrefix(seat)
    board.UI.setAttribute(prefix.."PercentText","text",tostring(setting.step*5).."%")
    board.UI.setAttribute(prefix.."ScopeText","text",setting.scope)
end

local function playAreaScaleChange(player,mouseButton,id,delta,scopeToggle)
    if mouseButton~="-1" then return end
    local seat=tonumber(tostring(id):match("^PlayAreaScale(%d+)"))
    if not playAreaScaleCanEdit(seat,player.color) then return end
    local setting=playAreaScaleSettings(seat)
    if scopeToggle==true then
        setting.scope=setting.scope=="Cards" and "All" or "Cards"
    else
        local step=math.max(12,math.min(20,setting.step+delta))
        if step==setting.step then return end
        setting.step=step
    end
    refreshPlayAreaScale(seat)
    -- Keep the XML and its anchor untouched. Rebuilding it with getBounds()
    -- on every click caused the previous controls to drift diagonally.
    local board=getObjectFromGUID(playerBoard[seat])
    if board~=nil and board.isDestroyed()~=true then playAreaScaleUpdateLabels(board,seat) end
end

function playAreaScaleDown(player,mouseButton,id)
    return safeCallback("playAreaScaleDown",function() playAreaScaleChange(player,mouseButton,id,-1,false) end)
end
function playAreaScaleUp(player,mouseButton,id)
    return safeCallback("playAreaScaleUp",function() playAreaScaleChange(player,mouseButton,id,1,false) end)
end
function playAreaScaleScope(player,mouseButton,id)
    return safeCallback("playAreaScaleScope",function() playAreaScaleChange(player,mouseButton,id,0,true) end)
end
-- Kept only as a harmless compatibility callback for classic buttons from an old save.
function playAreaScaleLabel() end

local function playAreaScaleBoardButtons(board,seat)
    if board==nil or board.isDestroyed()==true or turnOrderIndexAtSeat(seat)==nil then return end

    -- Missing UI ids can cause a TTS NullReferenceException from getAttribute.
    -- Inspect the existing XML tree instead, before any scale control exists.
    local prefix=playAreaScaleControlPrefix(seat)
    local xml=board.UI.getXmlTable() or {}
    for _,node in ipairs(xml) do
        if node.attributes~=nil and node.attributes.id==prefix.."PercentPanel" then
            playAreaScaleUpdateLabels(board,seat)
            return
        end
    end

    -- Remove legacy classic buttons left in an existing TTS save. They are no
    -- longer recreated; the new image buttons are part of the board's object XML.
    local old=board.getButtons() or {}
    for index=#old,1,-1 do
        if SCALE_BUTTONS[old[index].click_function]==true then board.removeButton(old[index].index) end
    end

    local bounds=board.getBounds()
    local pos=board.getPosition()
    -- The mats face the players at yaw 180: negative world X is their right.
    -- This mirrors the old left-hand placement to the bottom-RIGHT, without
    -- changing the 1.45-world-unit centre spacing between controls.
    local rightEdge=pos.x-bounds.size.x/2+0.55
    local bottom=pos.z-bounds.size.z/2+0.85
    local surface=bounds.center.y+bounds.size.y/2+0.06
    local function uiPosition(worldOffset)
        local point=board.positionToLocal({rightEdge+worldOffset,surface,bottom})
        -- XML uses 100 units per board-local unit. -40 raises it above the mat.
        return string.format("%.2f %.2f -40",point.x*100,point.z*100)
    end
    local function imageButton(id,callback,image,worldOffset,width)
        return {tag="Button",attributes={
            id=id,onClick="global/"..callback,
            onMouseDown="global/buttonClicked",onMouseUp="global/buttonClicked",
            height=100,width=width,position=uiPosition(worldOffset),
            rotation="0 0 180",scale="0.15 0.15",
            color="rgba(0,0,0,0.0)"
        },children={{tag="Image",attributes={id=id.."Image",image=image,
            type=image=="Sliced Button/Button Object Active" and "Sliced" or "Simple"}}}}
    end
    local setting=playAreaScaleSettings(seat)
    local items={
        imageButton(prefix.."OverkillDown","playAreaScaleDown","Overkill Down",5.7,90),
        {tag="Image",attributes={id=prefix.."PercentPanel",image="Overkill Text",
            height=90,width=115,position=uiPosition(4.25),
            rotation="0 0 180",scale="0.15 0.15"},
            children={{tag="Text",attributes={id=prefix.."PercentText",
                text=tostring(setting.step*5).."%",font="Fonts/MKCardText",
                fontSize=55,fontStyle="Bold",color="rgb(0,0,0)",alignment="MiddleCenter"}}}},
        imageButton(prefix.."OverkillUp","playAreaScaleUp","Overkill Up",2.8,90),
        imageButton(prefix.."Scope","playAreaScaleScope",
            "Sliced Button/Button Object Active",1.1,145)
    }
    items[4].children[#items[4].children+1]={tag="Text",attributes={
        id=prefix.."ScopeText",text=setting.scope,font="Fonts/MKCardText",
        fontSize=50,fontStyle="Normal",color="rgb(0,0,0)",alignment="MiddleCenter"
    }}

    -- Keep any other board-owned UI intact.
    for _,node in ipairs(items) do xml[#xml+1]=node end
    board.UI.setXmlTable(xml)
end

function refreshPlayAreaScaleControls()
    if gStates==nil or turnOrder==nil then return end
    for seat,boardGUID in ipairs(playerBoard) do
        local board=getObjectFromGUID(boardGUID)
        if board~=nil and board.isDestroyed()~=true then playAreaScaleBoardButtons(board,seat) end
    end
end

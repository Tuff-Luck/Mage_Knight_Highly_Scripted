-- Manual per-seat presentation scale for the Play and Unit Areas.
-- The scale never changes the logical resource/combat values of an object.
-- EDIT THESE VALUES to tune the control row on each player mat.
-- Positions are in world/table units relative to the mat's bottom-right edge:
--   offsetX: + moves right, - moves left
--   offsetY: + raises controls, - lowers them toward the board
--   offsetZ: + moves toward the far side of the table, - toward the player
--   rightInset / bottomInset: distance inward from that mat edge
-- Sizes use object-UI scale: 0.15 is the size of the percentage box.
local SCALE_CONTROL_UI={
    rightInset=0.55,
    bottomInset=0.85,
    offsetX=0.8,
    offsetY=-0.30,          -- lower the floating UI; adjust in 0.05 steps
    offsetZ=-1.35,
    arrowSpacing=0.90,       -- Down <-> percentage <-> Up (centre spacing)
    scopeSpacing=1.20,       -- Up <-> Cards/All centre spacing
    arrowScale=0.08,
    percentScale=0.08,
    scopeScale=0.08,
    arrowWidth=90,
    arrowHeight=90,
    boxWidth=130,
    boxHeight=90,
    percentFontSize=36,
    scopeFontSize=36,
}

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
    -- Permanent table/scenery objects are deliberately non-interactable and
    -- cannot be inspected by right-click. Never shrink them in "All" mode.
    -- Do not use getLock() here: legitimately played tokens can be locked.
    if obj.interactable==false or obj.type=="Table" then return false end
    -- Fixed table surfaces are also excluded if their interactable flag changes.
    if obj.guid=="3d4319" or obj.guid=="519f96" or obj.guid=="a02b0f" then return false end
    -- The board and its zones are fixtures, not played components.
    if obj.type=="ScriptingTrigger" or obj.type=="HandTrigger" or obj.type=="Board"
        or obj.type=="Bag" or obj.type=="Infinite" then return false end
    for _,guid in ipairs(playerBoard) do if obj.guid==guid then return false end end
    for _,guid in ipairs(colorBand) do if obj.guid==guid then return false end end
    -- Keep Unit cards, Command tokens (including Bonds of Loyalty and Banner
    -- of Command), and Wound tokens at their natural scale in either mode.
    if unitLayoutIsUnit(obj) or unitLayoutIsCommand(obj) or unitLayoutIsWound(obj)
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
    local prefix=playAreaScaleControlPrefix(seat)
    local xml=board.UI.getXmlTable() or {}

    -- Replace just our own controls, so edits to SCALE_CONTROL_UI take effect
    -- on a compiled/reloaded save as well as on a new table.
    -- No XML rebuild happens on scale-button clicks: only the labels change.
    for i=#xml,1,-1 do
        local attrs=xml[i].attributes
        if attrs~=nil and type(attrs.id)=="string" and attrs.id:sub(1,#prefix)==prefix then
            table.remove(xml,i)
        end
    end

    -- Clear the old-style buttons from an earlier save, if present.
    local old=board.getButtons() or {}
    for i=#old,1,-1 do
        if SCALE_BUTTONS[old[i].click_function]==true then board.removeButton(old[i].index) end
    end

    local ui=SCALE_CONTROL_UI
    local bounds=board.getBounds()
    local pos=board.getPosition()
    -- Use the positive-X edge for the actual bottom-right of the mat.
    -- Offsets stay in world coordinates so all four seats share one layout.
    local edgeX=pos.x+bounds.size.x/2-ui.rightInset+ui.offsetX
    local bottomZ=pos.z-bounds.size.z/2+ui.bottomInset+ui.offsetZ
    local surfaceY=bounds.center.y+bounds.size.y/2+0.06
    local function uiPosition(offset)
        local point=board.positionToLocal({edgeX+offset,surfaceY,bottomZ})
        -- Object-UI's third position coordinate is depth (the visible height
        -- above the board), not its second coordinate. Negative depth lifts UI.
        local depth=-40-ui.offsetY*100
        return string.format("%.2f %.2f %.2f",point.x*100,point.z*100,depth)
    end
    local function uiScale(value)
        return string.format("%.3f %.3f",value,value)
    end
    local function imageButton(id,callback,image,offset,width,height,scale)
        return {tag="Button",attributes={
            id=id,onClick="global/"..callback,
            onMouseDown="global/buttonClicked",onMouseUp="global/buttonClicked",
            height=height,width=width,position=uiPosition(offset),
            rotation="0 0 180",scale=uiScale(scale),
            color="rgba(0,0,0,0.0)"
        },children={{tag="Image",attributes={id=id.."Image",image=image}}}}
    end

    -- Left to right:  <  [100%]  >  [Cards/All]
    local scopeX=-1.10
    local upX=scopeX-ui.scopeSpacing
    local percentX=upX-ui.arrowSpacing
    local downX=percentX-ui.arrowSpacing
    local setting=playAreaScaleSettings(seat)
    local items={
        imageButton(prefix.."OverkillDown","playAreaScaleDown","Overkill Down",
            downX,ui.arrowWidth,ui.arrowHeight,ui.arrowScale),
        {tag="Image",attributes={id=prefix.."PercentPanel",image="Overkill Text",
            height=ui.boxHeight,width=ui.boxWidth,position=uiPosition(percentX),
            rotation="0 0 180",scale=uiScale(ui.percentScale)},
            children={{tag="Text",attributes={id=prefix.."PercentText",
                text=tostring(setting.step*5).."%",font="Fonts/MKCardText",
                fontSize=ui.percentFontSize,fontStyle="Bold",
                color="rgb(0,0,0)",alignment="MiddleCenter"}}}},
        imageButton(prefix.."OverkillUp","playAreaScaleUp","Overkill Up",
            upX,ui.arrowWidth,ui.arrowHeight,ui.arrowScale),
        imageButton(prefix.."Scope","playAreaScaleScope","Overkill Text",
            scopeX,ui.boxWidth,ui.boxHeight,ui.scopeScale)
    }
    items[4].children[#items[4].children+1]={tag="Text",attributes={
        id=prefix.."ScopeText",text=setting.scope,font="Fonts/MKCardText",
        fontSize=ui.scopeFontSize,fontStyle="Normal",
        color="rgb(0,0,0)",alignment="MiddleCenter",
        resizeTextForBestFit="true",resizeTextMinSize=26,
        resizeTextMaxSize=ui.scopeFontSize
    }}

    -- Preserve unrelated mat UI.
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

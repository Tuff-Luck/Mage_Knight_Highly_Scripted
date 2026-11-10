-- Physical Unit Offer loan for Call to Arms / Call to Glory.
-- This UI is independent of the Resource Tracker; the actual Unit keeps its GUID.
local SPELL_GUID="2eb8e8"
local excluded={["0a2e0b"]=true,["d8e49b"]=true,["9c5c38"]=true,["5c2da0"]=true}
local transferSerial=0
local spellMoveSerial=0 -- Invalidate stale leave-zone checks during drag/rearrangement.

local function previewState()
    return gStates~=nil and gStates.callOfferPreview or nil
end

local function vector(v)
    return {v.x or v[1],v.y or v[2],v.z or v[3]}
end

local function inZone(guid,zoneGUID)
    local zone=zoneGUID~=nil and getObjectFromGUID(zoneGUID) or nil
    if zone==nil then return false end
    for _,obj in ipairs(zone.getObjects()) do
        if obj.guid==guid then return true end
    end
    return false
end

local function cleanButtons(unit,removeResources)
    if unit==nil then return end
    local xml=unit.UI.getXmlTable() or {}
    local changed=false
    for i=#xml,1,-1 do
        local attrs=xml[i].attributes
        local id=attrs~=nil and attrs.id or nil
        if type(id)=="string" and (id:sub(1,17)=="CallOfferControl_"
            or (removeResources and (id:sub(1,19)=="ResourceCardChoice_"
                or id:sub(1,23)=="AttackAssignmentSource_"))) then
            table.remove(xml,i)
            changed=true
        end
    end
    -- Passing {} to TTS UI.setXmlTable raises "table was null".
    -- Match the existing Unit-choice cleanup convention for empty Object UI.
    if changed then unit.UI.setXmlTable(#xml>0 and xml or {{}}) end
end

local function restoreUnit(state,immediate)
    if state==nil or state.unitGUID==nil then return end
    local guid=state.unitGUID
    local home=state.home
    -- Retire the source before combat recalculation or physical movement.
    -- Otherwise a queued scan can reactivate the card and recreate its arrow.
    state.unitGUID=nil
    state.home=nil
    local unit=getObjectFromGUID(guid)
    if resourceUnitsBorrowedUnitEnded~=nil then resourceUnitsBorrowedUnitEnded(guid) end
    cleanButtons(unit,true)
    if unit~=nil and home~=nil then
        -- The offer is outside the Play Area: discard its temporary scale
        -- factor before restoring its original offer size.
        if playAreaScaleForgetObject~=nil then playAreaScaleForgetObject(unit) end
        unit.unlock()
        unit.setScale(home.scale)
        if immediate then
            unit.setRotation(home.rotation)
            unit.setPosition(home.position)
        else
            unit.setRotationSmooth(home.rotation,false,false)
            unit.setPositionSmooth(home.position,false,false)
        end
        safeWaitCondition("Offers.CallOffer",function()
            local live=getObjectFromGUID(guid)
            if live~=nil and inZone(guid,GUID.zone.unitOffer) then live.lock() end
        end,function()
            local live=getObjectFromGUID(guid)
            return live==nil or (live.resting and live.isSmoothMoving()==false)
        end,8)
    end
end

-- A temporarily displayed Unit must not disappear when the offer is
-- reflowed or re-dealt. Forced offer maintenance restores it synchronously.
function callOfferClose(immediate)
    local state=previewState()
    if state==nil then return end
    transferSerial=transferSerial+1
    restoreUnit(state,immediate==true)
    gStates.callOfferPreview=nil
end

local function available(state)
    local present={}
    for _,unit in ipairs(callOfferAvailableUnits()) do present[unit.guid]=true end
    if state.unitGUID~=nil then present[state.unitGUID]=true end
    return present
end

local function showControls(state,guid,serial)
    local unit=getObjectFromGUID(guid)
    if unit==nil or previewState()~=state or state.unitGUID~=guid
        or transferSerial~=serial then return end
    cleanButtons(unit,false)
    local xml=unit.UI.getXmlTable() or {}
    -- Rotate the parent Button, not its child Image: TTS object UI ignores
    -- child Image rotation in this layout. Up/Down become left/right at 90 degrees.
    local images={"Overkill Down","Overkill Up"}
    for _,entry in ipairs({
        {direction="previous",image=images[1],x="-135"},
        {direction="next",image=images[2],x="135"}
    }) do
        local id="CallOfferControl_"..guid.."_"..entry.direction
        xml[#xml+1]={tag="Button",attributes={
            id=id,onClick="global/callOfferCycleClicked",
            position=entry.x.." 0 -35",rotation="0 0 0",
            width=95,height=110,scale="0.40 0.40",
            color="rgba(0,0,0,0.0)"},
            children={{tag="Image",attributes={
                id=id.."Image",image=entry.image,
                preserveAspect="true",raycastTarget="false"
            }}}}
    end
    -- Object-attached UI has its own image registry. Passing these existing
    -- assets prevents an unregistered-image white square on moved Unit cards.
    local assets=resourceCardsExistingImageAssetsFor(unit.UI,images)
    if assets~=nil then unit.UI.setXmlTable(xml,assets)
    else unit.UI.setXmlTable(xml) end
end

-- The preview card's placement is independent of the Spell after the first borrow.
-- Keep the latest user-chosen spot when the player browses other Units.
local function rememberDisplayedUnit(state)
    local unit=state~=nil and state.unitGUID~=nil and getObjectFromGUID(state.unitGUID) or nil
    if unit~=nil then
        state.display={position=vector(unit.getPosition()),rotation=vector(unit.getRotation())}
    end
end

local function borrow(state,index)
    local guid=state.order[index]
    local unit=guid~=nil and getObjectFromGUID(guid) or nil
    local spell=getObjectFromGUID(state.spellGUID)
    if unit==nil or spell==nil then return false end
    if not inZone(guid,GUID.zone.unitOffer) then return false end
    local pos=vector(spell.getPosition())
    local display=state.display or {
        position={pos[1]+3.9,math.max(1.8,pos[2]+0.35),pos[3]},
        rotation={0,180,0}}
    state.index=index
    state.unitGUID=guid
    state.home={position=vector(unit.getPosition()),
        rotation=vector(unit.getRotation()),scale=vector(unit.getScale())}
    transferSerial=transferSerial+1
    local serial=transferSerial
    unit.unlock()
    unit.setScale({1.5,1,1.5})
    -- A new selection occupies the last manually chosen display location.
    -- Moving the Spell later does not drag the Unit or reset its layout.
    unit.setPositionSmooth(display.position,false,false)
    unit.setRotationSmooth(display.rotation,false,false)
    safeWaitCondition("Offers.CallOffer",function()
        showControls(state,guid,serial)
    end,function()
        local live=getObjectFromGUID(guid)
        return live==nil or (live.resting and live.isSmoothMoving()==false)
    end,8)
    if resourceCardsSourceChanged~=nil then resourceCardsSourceChanged() end
    return true
end

local function selectRelative(state,delta)
    local present=available(state)
    local count=#state.order
    if count==0 then return end
    local oldIndex=state.index or 1
    for step=1,count do
        local index=((oldIndex-1+step*delta)%count)+1
        local guid=state.order[index]
        if present[guid]==true and excluded[guid]~=true
            and guid~=state.unitGUID then
            rememberDisplayedUnit(state)
            restoreUnit(state,false)
            borrow(state,index)
            return
        end
    end
end

publishPublicUICallbacks({
    callOfferCycleClicked=function(player,value,id)
        local state=previewState()
        if state==nil or type(id)~="string" then return end
        local guid,direction=id:match("^CallOfferControl_([0-9a-f]+)_(previous)$")
        if guid==nil then guid,direction=id:match("^CallOfferControl_([0-9a-f]+)_(next)$") end
        if guid~=state.unitGUID then return end
        if legalPlayerCheck(player.color,state.seatPos,"NoDummyException")~=true then return end
        selectRelative(state,direction=="previous" and -1 or 1)
    end
})

-- Only a genuine, played Spell creates a temporary offer display.
function callOfferSpellEntered(spellGUID,seatPos)
    if spellGUID~=SPELL_GUID or seatPos==nil or gStates==nil then return end
    local spell=getObjectFromGUID(SPELL_GUID)
    if spell==nil or not inZone(SPELL_GUID,playerPlayAreas[seatPos]) then return end
    if spell.is_face_down==true then
        callOfferClose(false)
        return
    end
    local state=previewState()
    if state~=nil then
        if state.spellGUID==spellGUID and state.seatPos==seatPos then return end
        callOfferClose(true)
    end
    local order={}
    for _,unit in ipairs(callOfferAvailableUnits()) do
        if excluded[unit.guid]~=true then order[#order+1]=unit.guid end
    end
    if #order==0 then return end
    state={spellGUID=SPELL_GUID,seatPos=seatPos,order=order,index=1}
    gStates.callOfferPreview=state
    if not borrow(state,1) then gStates.callOfferPreview=nil end
end

-- Explicitly reevaluate only after the Spell has finished moving. A zone
-- exit during drag is not evidence that the Spell has been discarded.
function callOfferSpellChanged()
    if gStates==nil then return end
    local spell=getObjectFromGUID(SPELL_GUID)
    if spell~=nil and (spell.held_by_color~=nil or spell.resting~=true
        or spell.isSmoothMoving()==true) then return end
    if spell==nil or spell.is_face_down==true then
        callOfferClose(false)
        return
    end
    for seatPos=1,4 do
        if inZone(SPELL_GUID,playerPlayAreas[seatPos]) then
            if spell.held_by_color==nil and spell.resting==true then
                callOfferSpellEntered(SPELL_GUID,seatPos)
            end
            return
        end
    end
    callOfferClose(false)
end

-- A held card may briefly leave/re-enter a Scripting Zone. Wait for a real
-- settled destination and let newer pickup/drop/flip events cancel stale checks.
function callOfferSpellPickedUp()
    spellMoveSerial=spellMoveSerial+1
end

function callOfferScheduleSpellCheck()
    spellMoveSerial=spellMoveSerial+1
    local serial=spellMoveSerial
    safeWaitFrames("Offers.CallOffer",function()
        if serial~=spellMoveSerial then return end
        safeWaitCondition("Offers.CallOffer",function()
            safeWaitFrames("Offers.CallOffer",function()
                if serial==spellMoveSerial then callOfferSpellChanged() end
            end,3)
        end,function()
            if serial~=spellMoveSerial then return true end
            local spell=getObjectFromGUID(SPELL_GUID)
            return spell==nil or (spell.held_by_color==nil
                and spell.resting==true and spell.isSmoothMoving()==false)
        end,8)
    end,2)
end

function callOfferSpellLeft(spellGUID,seatPos)
    local state=previewState()
    if spellGUID~=SPELL_GUID or state==nil or state.seatPos~=seatPos then return end
    callOfferScheduleSpellCheck()
end

function callOfferBorrowedUnitForSeat(seatPos)
    local state=previewState()
    if state==nil or state.seatPos~=seatPos then return nil end
    if not inZone(SPELL_GUID,playerPlayAreas[seatPos]) then return nil end
    local spell=getObjectFromGUID(SPELL_GUID)
    if spell==nil or spell.is_face_down==true then return nil end
    return state.unitGUID~=nil and getObjectFromGUID(state.unitGUID) or nil
end

-- The normal player Unit area owns actual recruitment, not the offer loan.
function callOfferObjectDropped(obj)
    local state=previewState()
    if state==nil or obj==nil or obj.guid~=state.unitGUID then return end
    local guid=obj.guid
    safeWaitCondition("Offers.CallOffer",function()
        local current=previewState()
        if current==nil or current.unitGUID~=guid then return end
        if not inZone(guid,playerUnitAreas[current.seatPos]) then
            -- Repositioning the borrowed Unit is NOT recruitment. Keep its
            -- controls, combat links and new browsing position intact.
            rememberDisplayedUnit(current)
            return
        end
        transferSerial=transferSerial+1
        current.unitGUID=nil
        if resourceUnitsBorrowedUnitEnded~=nil then resourceUnitsBorrowedUnitEnded(guid) end
        cleanButtons(getObjectFromGUID(guid),true)
        gStates.callOfferPreview=nil
    end,function()
        local live=getObjectFromGUID(guid)
        return live==nil or (live.held_by_color==nil
            and live.resting and live.isSmoothMoving()==false)
    end,8)
end

function callOfferRestoreOnLoad()
    local state=previewState()
    if state==nil then return end
    local unit=state.unitGUID~=nil and getObjectFromGUID(state.unitGUID) or nil
    local spell=getObjectFromGUID(SPELL_GUID)
    if unit==nil or spell==nil or spell.is_face_down==true
        or not inZone(SPELL_GUID,playerPlayAreas[state.seatPos]) then
        callOfferClose(true)
        return
    end
    transferSerial=transferSerial+1
    showControls(state,unit.guid,transferSerial)
end

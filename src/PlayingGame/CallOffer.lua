-- Physical Unit Offer loan for Call to Arms / Call to Glory.
-- This UI is independent of the Resource Tracker; the actual Unit keeps its GUID.
local SPELL_GUID="2eb8e8"
local excluded={["0a2e0b"]=true,["d8e49b"]=true,["9c5c38"]=true,["5c2da0"]=true}
local transferSerial=0
local spellMoveSerial=0 -- Invalidate stale leave-zone checks during drag/rearrangement.

local function previewState()
    return gStates~=nil and gStates.callOfferPreview or nil
end

-- Shared object-UI navigation builder, used by Training's Advanced Action
-- offer preview without changing the existing Unit browser's lifecycle.
function callOfferAppendBrowseControls(xml,guid,prefix,callback,includeClaim)
    local images={"Overkill Down","Overkill Up"}
    for _,entry in ipairs({
        {direction="previous",image=images[1],x="-135"},
        {direction="next",image=images[2],x="135"}
    }) do
        local id=prefix..guid.."_"..entry.direction
        xml[#xml+1]={tag="Button",attributes={
            id=id,onClick="global/"..callback,
            position=entry.x.." 0 -35",rotation="0 0 0",
            width=95,height=110,scale="0.40 0.40",
            color="rgba(0,0,0,0.0)"},
            children={{tag="Image",attributes={
                id=id.."Image",image=entry.image,
                preserveAspect="true",raycastTarget="false"
            }}}}
    end
    if includeClaim then
        xml[#xml+1]={tag="Button",attributes={
            id=prefix..guid.."_claim",onClick="global/"..callback,
            position="0 0 -35",rotation="0 0 0",
            width=130,height=75,scale="0.40 0.40",
            text="Take",fontSize=40,
            color="rgba(0.12,0.32,0.16,0.92)",textColor="rgba(1,1,1,1)"}}
    end
    return images
end

local CALL_OFFER_CONTROL_PREFIXES={"CallOfferControl_"}
local CALL_OFFER_ALL_PREFIXES={"CallOfferControl_","ResourceCardChoice_","AttackAssignmentSource_"}
local function cleanButtons(unit,removeResources)
    if unit~=nil then
        resourceObjectUiRemovePrefixes(unit,
            removeResources and CALL_OFFER_ALL_PREFIXES or CALL_OFFER_CONTROL_PREFIXES)
    end
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
            if live~=nil and objectGUIDInZone(guid,GUID.zone.unitOffer) then live.lock() end
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
    local xml=resourceObjectUiXmlTable(unit.UI)
    -- Replace the browser's own arrows in one XML update. Clearing to {{}}
    -- and then immediately appending nodes can leave an invalid placeholder.
    for i=#xml,1,-1 do
        local attrs=xml[i].attributes
        if attrs~=nil and type(attrs.id)=="string"
            and attrs.id:sub(1,17)=="CallOfferControl_" then
            table.remove(xml,i)
        end
    end
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
    resourceObjectUiSetTable(unit.UI,xml,assets)
end

-- Other UI owners (notably the Resource Tracker's zone-exit refresh) may
-- replace a Unit's XML while it is being moved. Reinstate the browser controls
-- only if missing, leaving existing Unit choices and target buttons untouched.
function callOfferEnsureControls(seatPos)
    local state=previewState()
    if state==nil or state.unitGUID==nil
        or (seatPos~=nil and state.seatPos~=seatPos) then return end
    local spell=getObjectFromGUID(state.spellGUID)
    local unit=getObjectFromGUID(state.unitGUID)
    if spell==nil or spell.is_face_down==true or unit==nil
        or objectGUIDInZone(unit.guid,playerUnitAreas[state.seatPos]) then return end
    local previous,nextButton=false,false
    for _,node in ipairs(unit.UI.getXmlTable() or {}) do
        local id=node.attributes~=nil and node.attributes.id or nil
        if id=="CallOfferControl_"..unit.guid.."_previous" then previous=true
        elseif id=="CallOfferControl_"..unit.guid.."_next" then nextButton=true end
    end
    if not previous or not nextButton then
        showControls(state,unit.guid,transferSerial)
    end
end

-- The preview card's placement is independent of the Spell after the first borrow.
-- Keep the latest user-chosen spot when the player browses other Units.
local function rememberDisplayedUnit(state)
    local unit=state~=nil and state.unitGUID~=nil and getObjectFromGUID(state.unitGUID) or nil
    if unit~=nil then
        state.display={position=ttsVectorArray(unit.getPosition()),rotation=ttsVectorArray(unit.getRotation())}
    end
end

local function borrow(state,index)
    local guid=state.order[index]
    local unit=guid~=nil and getObjectFromGUID(guid) or nil
    local spell=getObjectFromGUID(state.spellGUID)
    if unit==nil or spell==nil then return false end
    if not objectGUIDInZone(guid,GUID.zone.unitOffer) then return false end
    local pos=ttsVectorArray(spell.getPosition())
    local display=state.display or {
        position={pos[1]+3.9,math.max(1.8,pos[2]+0.35),pos[3]},
        rotation={0,180,0}}
    state.index=index
    state.unitGUID=guid
    state.home={position=ttsVectorArray(unit.getPosition()),
        rotation=ttsVectorArray(unit.getRotation()),scale=ttsVectorArray(unit.getScale())}
    transferSerial=transferSerial+1
    local serial=transferSerial
    unit.unlock()
    unit.setScale({1.5,1,1.5})
    -- A new selection occupies the last manually chosen display location.
    -- Moving the Spell later does not drag the Unit or reset its layout.
    unit.setPositionSmooth(display.position,false,false)
    unit.setRotationSmooth(display.rotation,false,false)
    -- Show navigation immediately. A card placed over another card can take
    -- several seconds to settle; waiting to create ALL controls left the next
    -- Unit without buttons if physics never reported resting in that window.
    showControls(state,guid,serial)
    local function refreshSettled()
        if previewState()~=state or state.unitGUID~=guid
            or transferSerial~=serial then return end
        callOfferEnsureControls(state.seatPos)
        -- Recalculate after arrival as well as at selection time. Otherwise a
        -- scan during movement can cache missing ability/target buttons.
        if resourceCardsSourceChanged~=nil then resourceCardsSourceChanged() end
    end
    safeWaitCondition("Offers.CallOffer",refreshSettled,function()
        local live=getObjectFromGUID(guid)
        return live==nil or (live.resting and live.isSmoothMoving()==false)
    end,8,refreshSettled)
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
    -- Moving the already-used Spell must never grant a second Call to Glory.
    -- This saved flag is independent of the preview (which ends on recruitment).
    if gStates.callOfferGloryClaimed==true then return end
    local spell=getObjectFromGUID(SPELL_GUID)
    if spell==nil or not objectGUIDInZone(SPELL_GUID,playerPlayAreas[seatPos]) then return end
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
    if spell==nil then
        callOfferClose(false)
        gStates.callOfferGloryClaimed=nil
        return
    end
    if spell.is_face_down==true then
        -- A face-down Spell is inert, but flipping it does not undo recruitment.
        callOfferClose(false)
        return
    end
    for seatPos=1,4 do
        if objectGUIDInZone(SPELL_GUID,playerPlayAreas[seatPos]) then
            if spell.held_by_color==nil and spell.resting==true then
                callOfferSpellEntered(SPELL_GUID,seatPos)
            end
            return
        end
    end
    -- Clear the one-use latch only once the Spell truly leaves the play area.
    callOfferClose(false)
    gStates.callOfferGloryClaimed=nil
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
    if spellGUID~=SPELL_GUID then return end
    local state=previewState()
    -- Recruitment removes the preview, not the Spell's one-use history.
    -- A later genuine exit must still release the completion latch.
    if (state==nil or state.seatPos~=seatPos)
        and (gStates==nil or gStates.callOfferGloryClaimed~=true) then return end
    callOfferScheduleSpellCheck()
end

function callOfferBorrowedUnitForSeat(seatPos)
    local state=previewState()
    if state==nil or state.seatPos~=seatPos then return nil end
    if not objectGUIDInZone(SPELL_GUID,playerPlayAreas[seatPos]) then return nil end
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
        if not objectGUIDInZone(guid,playerUnitAreas[current.seatPos]) then
            -- Repositioning the borrowed Unit is NOT recruitment. Keep its
            -- controls, combat links and new browsing position intact.
            rememberDisplayedUnit(current)
            callOfferEnsureControls(current.seatPos)
            return
        end
        transferSerial=transferSerial+1
        -- The player has recruited this physical Unit with Call to Glory.
        -- Keep the Spell consumed even though its transient browser is gone.
        gStates.callOfferGloryClaimed=true
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
    -- This is saved separately from the preview. Do not spawn a replacement
    -- after loading a game in which the Unit was already recruited.
    if state==nil then return end
    local unit=state.unitGUID~=nil and getObjectFromGUID(state.unitGUID) or nil
    local spell=getObjectFromGUID(SPELL_GUID)
    if unit==nil or spell==nil or spell.is_face_down==true
        or not objectGUIDInZone(SPELL_GUID,playerPlayAreas[state.seatPos]) then
        callOfferClose(true)
        return
    end
    transferSerial=transferSerial+1
    showControls(state,unit.guid,transferSerial)
end

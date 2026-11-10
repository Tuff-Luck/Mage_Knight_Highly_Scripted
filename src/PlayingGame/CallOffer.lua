-- Physical Unit Offer loan for Call to Arms / Call to Glory.
-- This UI is independent of the Resource Tracker; the actual Unit keeps its GUID.
local SPELL_GUID="2eb8e8"
local excluded={["0a2e0b"]=true,["d8e49b"]=true,["9c5c38"]=true,["5c2da0"]=true}
local transferSerial=0

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
    for i=#xml,1,-1 do
        local attrs=xml[i].attributes
        local id=attrs~=nil and attrs.id or nil
        if type(id)=="string" and (id:sub(1,17)=="CallOfferControl_"
            or (removeResources and (id:sub(1,19)=="ResourceCardChoice_"
                or id:sub(1,23)=="AttackAssignmentSource_"))) then
            table.remove(xml,i)
        end
    end
    unit.UI.setXmlTable(xml)
end

local function restoreUnit(state,immediate)
    if state==nil or state.unitGUID==nil then return end
    local guid=state.unitGUID
    local unit=getObjectFromGUID(guid)
    if resourceUnitsBorrowedUnitEnded~=nil then resourceUnitsBorrowedUnitEnded(guid) end
    cleanButtons(unit,true)
    if unit~=nil and state.home~=nil then
        unit.unlock()
        unit.setScale(state.home.scale)
        if immediate then
            unit.setRotation(state.home.rotation)
            unit.setPosition(state.home.position)
        else
            unit.setRotationSmooth(state.home.rotation,false,false)
            unit.setPositionSmooth(state.home.position,false,false)
        end
        safeWaitCondition("Offers.CallOffer",function()
            local live=getObjectFromGUID(guid)
            if live~=nil and inZone(guid,GUID.zone.unitOffer) then live.lock() end
        end,function()
            local live=getObjectFromGUID(guid)
            return live==nil or (live.resting and live.isSmoothMoving()==false)
        end,8)
    end
    state.unitGUID=nil
    state.home=nil
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
    for _,entry in ipairs({
        {direction="previous",label="<",x="-145"},
        {direction="next",label=">",x="145"}
    }) do
        xml[#xml+1]={tag="Button",attributes={
            id="CallOfferControl_"..guid.."_"..entry.direction,
            onClick="global/callOfferCycleClicked",
            position=entry.x.." 0 -35",rotation="0 0 180",
            width=95,height=110,scale="0.40 0.40",fontSize=82,
            colors="#454D5D|#69798E|#444C63|#454D5D",
            textColor="#FFFFFF",textAlignment="MiddleCenter"},
            value=entry.label}
    end
    unit.UI.setXmlTable(xml)
end

local function borrow(state,index)
    local guid=state.order[index]
    local unit=guid~=nil and getObjectFromGUID(guid) or nil
    local spell=getObjectFromGUID(state.spellGUID)
    if unit==nil or spell==nil then return false end
    if not inZone(guid,GUID.zone.unitOffer) then return false end
    local pos=vector(spell.getPosition())
    state.index=index
    state.unitGUID=guid
    state.home={position=vector(unit.getPosition()),
        rotation=vector(unit.getRotation()),scale=vector(unit.getScale())}
    transferSerial=transferSerial+1
    local serial=transferSerial
    unit.unlock()
    unit.setScale({1.5,1,1.5})
    -- Stay alongside the actual played Spell, in its owner's play area.
    unit.setPositionSmooth({pos[1]+3.9,math.max(1.8,pos[2]+0.35),pos[3]},false,false)
    unit.setRotationSmooth({0,180,0},false,false)
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
    if not inZone(SPELL_GUID,playerPlayAreas[seatPos]) then return end
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

function callOfferSpellLeft(spellGUID,seatPos)
    local state=previewState()
    if spellGUID~=SPELL_GUID or state==nil or state.seatPos~=seatPos then return end
    -- Picking up and re-arranging the Spell must not destroy the browser.
    safeWaitCondition("Offers.CallOffer",function()
        if not inZone(SPELL_GUID,playerPlayAreas[seatPos]) then callOfferClose(false) end
    end,function()
        local spell=getObjectFromGUID(SPELL_GUID)
        return spell==nil or (spell.held_by_color==nil
            and spell.resting and spell.isSmoothMoving()==false)
    end,8)
end

function callOfferBorrowedUnitForSeat(seatPos)
    local state=previewState()
    if state==nil or state.seatPos~=seatPos then return nil end
    if not inZone(SPELL_GUID,playerPlayAreas[seatPos]) then return nil end
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
        if not inZone(guid,playerUnitAreas[current.seatPos]) then return end
        transferSerial=transferSerial+1
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
    if unit==nil or not inZone(SPELL_GUID,playerPlayAreas[state.seatPos]) then
        callOfferClose(true)
        return
    end
    transferSerial=transferSerial+1
    showControls(state,unit.guid,transferSerial)
end

-- Full Unit Area recruitment: cancelled selection, confirmed disband,
-- command ownership, Banners, Wounds, and save/load restoration.
-- Run from the repository root: lua5.2 tools/test-unit-replacement.lua
local function read(path)
    local file=assert(io.open(path,"r"))
    local body=file:read("*a")
    file:close()
    return body
end
local function section(source,a,b)
    local first=assert(source:find(a,1,true),"Missing section: "..a)
    local last=assert(source:find(b,first+#a,true),"Missing boundary: "..b)
    return source:sub(first,last-1)
end
local cardRecognition=read("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local replacement=read("src/PlayingGame/PlayerBoard/UnitReplacement.lua")
local flow=read("src/PlayingGame/PlayerBoard/CardFlow.lua")
local entry=read(".tts/objects/Global.lua")
local callbacks=read("src/PlayingGame/Callbacks.lua")
assert(entry:find('require("PlayingGame.PlayerBoard.UnitReplacement")',1,true))
assert(flow:find('unitReplacementBegin(player,claimedCard.guid,seatPos)',1,true))
assert(callbacks:find('"unitReplacementCancel","unitReplacementConfirm","unitReplacementSelectClicked"',1,true))
assert(cardRecognition:find('unitReplacementEnsureControls(seatPos)',1,true))
assert(read("src/PlayingGame/Events.lua"):find('resourceUnitsRetireUnit(obj.guid)',1,true))
assert(read("src/PlayingGame/PlayerBoard/Events.lua"):find(
    'resourceUnitsReconcileNewUnit(incomingGUID,unitSeatPos)',1,true))
assert(read("src/PlayingGame/Turn.lua"):find('unitReplacementClose()',1,true))

-- Ownership is not identical to the physical Command token's spent history.
-- A mere token lift cannot ready its old owner, but a replacement must.
local ownerCode=section(cardRecognition,"function resourceUnitsSpentCommands()",
    "-- An activation belongs to the physical Command token")
local oldPresent=true
local oldGUID="aab001"
local newGUID="bbc002"
local tokenGUID="ccc003"
local oldUnit={guid=oldGUID}
local newUnit={guid=newGUID}
local token={guid=tokenGUID}
local ownerState={currentRound=2,
    unitSpentCommandTokens={round=2,tokens={[tokenGUID]=true},owners={[tokenGUID]=oldGUID}},
    unitResourceActivations={}}
local retired={}
local ownerEnv={
    gStates=ownerState,
    unitLayoutObjectInAnyUnitArea=function(guid) return guid==oldGUID and oldPresent end,
    unitLayoutSnapshot=function() return {commands={token}} end,
    unitLayoutCommandTarget=function() return oldUnit end,
    unitHistoryReleaseUnit=function(guid) retired[#retired+1]=guid end,
    getObjectFromGUID=function() return nil end,
    removeChoiceButtons=function() end,
    choiceButtonShown={},choiceExpandedByGUID={}
}
setmetatable(ownerEnv,{__index=_G})
local ownerAPI=assert(load(ownerCode..
    "\nreturn resourceUnitsCommandSpent,resourceUnitsCommandOwner,"
    .."resourceUnitsAdoptCommand,resourceUnitsRecordSpentCommands,"
    .."resourceUnitsSpentCommands",
    "Command ownership","t",ownerEnv))()
local commandSpent,commandOwner,adopt,record,spentTable=ownerAPI()
assert(commandSpent(tokenGUID)==true and commandOwner(tokenGUID)==oldGUID)
assert(adopt(tokenGUID,newGUID,1,false)==false,
    "Moving a Command while its previous Unit is present must not ready it")
assert(commandSpent(tokenGUID) and commandOwner(tokenGUID)==oldGUID)
oldPresent=false
assert(adopt(tokenGUID,newGUID,1,false)==true,
    "New Unit should take an abandoned Command")
assert(not commandSpent(tokenGUID) and commandOwner(tokenGUID)==newGUID,
    "Replacement must reset spent Command and ownership")
assert(#retired==1 and retired[1]==oldGUID,"Old Unit history must be retired")
assert(adopt(tokenGUID,newGUID,1,false)==true and not commandSpent(tokenGUID),
    "Moving the SAME replacement Unit must keep its ownership")
record(1)
assert(commandSpent(tokenGUID) and commandOwner(tokenGUID)==oldGUID,
    "End Turn must capture the physical spent Unit owner")
assert(adopt(tokenGUID,newGUID,1,true)==true and not commandSpent(tokenGUID),
    "Explicitly approved recruitment must ready a formerly spent Command")
ownerState.currentRound=3
assert(not commandSpent(tokenGUID) and commandOwner(tokenGUID)==nil,
    "New Round must reset ownership and exhaustion together")

-- Simulate both ordinary and bonus/Banner Commands in the same replacement
-- panel. The banner used AS a Command is never destroyed or discarded.
local attrs,objects={},{}
local owner={
    guid="abc001",inUnit=true,x=0,resting=true,
    bounds={center={x=0,y=1,z=-34.74},size={x=2,z=3}},
    UI={nodes={}}
}
local candidate={guid="def002",offered=true,resting=true,UI={nodes={}}}
local wound={guid="aaa123",wound=true,x=0,z=-34.74}
local banner={guid="bba123",moved=false}
local command={guid="c0a001",resting=true,moved=false}
command.isSmoothMoving=function() return false end
command.setPositionSmooth=function(pos)
    command.moved=true
    command.position=pos
end
local bonusCommand={guid="c0b002"}
local woundReturned,oldTrashed,newClaimed=false,false,false
for _,obj in ipairs({owner,candidate,wound,banner,command,bonusCommand}) do objects[obj.guid]=obj end
owner.getBounds=function() return owner.bounds end
owner.getPosition=function() return {x=0,y=1,z=-34.74} end
owner.highlightOn=function() end
owner.highlightOff=function() end
candidate.highlightOn=function() end
candidate.highlightOff=function() end
banner.unlock=function() end
banner.setPositionSmooth=function() banner.moved=true end
local bag={putObject=function(obj)
    if obj==wound then woundReturned=true end
end}
local trash={putObject=function(obj)
    if obj==owner then
        oldTrashed=true
        owner.inUnit=false
        objects[owner.guid]=nil
    end
end}
local discard={getPosition=function() return {x=4,y=1,z=-41} end}
local function layout()
    local result={
        commands={command,bonusCommand},
        units={},unitBySlot={},unitSlotByGuid={},
        slotX={[1]=0,[2]=5},objects={wound,banner,command,bonusCommand}
    }
    if owner.inUnit then
        result.units[1]=owner
        result.unitBySlot[1]=owner
        result.unitSlotByGuid[owner.guid]=1
        result.objects[#result.objects+1]=owner
    end
    if newClaimed then
        result.units[1]=candidate
        result.unitBySlot[1]=candidate
        result.unitSlotByGuid[candidate.guid]=1
    end
    return result
end
local ui={setAttribute=function(id,key,value)
    attrs[id..":"..key]=value
end}
local state={turnNumber=5}
local claimBusy=false
local savedSnapshot=false
local finished=false
local clearedHistory=false
local closeCount=0
local env={
    gStates=state,UI=ui,
    gameCards={
        [owner.guid]={cardType="Regular Unit",name={"Old Unit"}},
        [candidate.guid]={cardType="Elite Unit",name={"New Unit"}}},
    GUID={zone={unitOffer="unitOffer"}},
    trashCan="trash",deedDeckDiscardZones={[1]="discard"},
    warningColor={1,0,0},
    unitLayoutSnapshot=function() return layout() end,
    unitLayoutCommandTarget=function()
        return owner.inUnit and owner or nil
    end,
    unitLayoutReadyCommandPosition=function() return {0,1.5,-39} end,
    unitLayoutFirstFreeCommand=function() return nil end,
    unitLayoutResourceState=function() return {bannersByUnit={
        [owner.guid]={artifact={guid=banner.guid}}}} end,
    unitLayoutIsWound=function(obj) return obj.wound==true end,
    legalPlayerCheck=function(color,seat) return color=="Red" and seat==1 end,
    objectGUIDInZone=function(guid,zone)
        return guid==candidate.guid and zone=="unitOffer" and candidate.offered
    end,
    getObjectFromGUID=function(guid)
        if guid=="trash" then return trash end
        if guid=="ab56f3" then return bag end
        if guid=="discard" then return discard end
        return objects[guid]
    end,
    resourceObjectUiXmlTable=function(objUI) return objUI.nodes end,
    resourceObjectUiSetTable=function(objUI,nodes) objUI.nodes=nodes end,
    resourceCardsExistingImageAssetsFor=function() return nil end,
    cardFlowUnitClaimBusy=function() return claimBusy end,
    rewindTransactionOwnerActive=function() return false end,
    rewindTransactionStart=function(callback)
        assert(not oldTrashed and not newClaimed,
            "Rewind point must precede all physical replacement mutations")
        savedSnapshot=true
        callback()
        return true
    end,
    rewindTransactionFinish=function() finished=true end,
    safeWaitCondition=function(_,done,ready)
        assert(ready(),"The Command must be ready before releasing Undo")
        done()
    end,
    cardFlowClaimUnitAtSlot=function(obj,seat,x,lay,source,onSettled)
        assert(obj==candidate and seat==1 and x==0 and source==command)
        assert(oldTrashed and clearedHistory and savedSnapshot and command.moved,
            "Old Unit history and physical Command must be readied after the rewind point")
        newClaimed=true
        candidate.offered=false
        if onSettled then onSettled() end
        return true
    end,
    resourceUnitsRetireUnit=function(guid)
        assert(guid==owner.guid)
        clearedHistory=true
    end,
    resourceCardsSourceChanged=function() end,
    broadcastToColor=function() end,
    publishPublicUICallbacks=function() end
}
setmetatable(env,{__index=_G})
env.publishPublicUICallbacks=function(funcs)
    for name,fn in pairs(funcs) do env[name]=fn end
end
assert(load(replacement,"Full Unit replacement","t",env))()
assert(env.unitReplacementBegin({color="Red"},candidate.guid,1),
    "Full board must open the replacement choice")
assert(attrs["UnitReplacement:active"]=="true" and not oldTrashed
    and candidate.offered,"Choice may not claim or trash until confirmation")
local function selectOld()
    env.unitReplacementSelectClicked({color="Red"},"-1","UnitReplaceSelect_"..owner.guid)
end
selectOld()
assert(state.unitReplacementPending.selectedGUID==owner.guid)
assert(attrs["UnitReplacementConfirm:interactable"]=="true")
assert(#owner.UI.nodes>0,"The disband selection button should be on the Unit")
-- Cancel is non-destructive, leaving the Unit offer as it was.
env.unitReplacementCancel({color="Red"})
assert(not oldTrashed and candidate.offered and state.unitReplacementPending==nil,
    "Cancelling replacement must leave all pieces in place")
assert(attrs["UnitReplacement:active"]=="false","Cancel must close panel")
assert(#owner.UI.nodes==0,"Cancel must remove its object button")

-- Saving while choosing must restore the panel and selection after load.
assert(env.unitReplacementBegin({color="Red"},candidate.guid,1))
selectOld()
attrs["UnitReplacement:active"]="false"
owner.UI.nodes={}
env.unitReplacementRestoreOnLoad()
assert(attrs["UnitReplacement:active"]=="true" and #owner.UI.nodes>0)
-- If the offered card is removed while a disband is pending, confirmation
-- must fail without touching the currently owned Unit.
candidate.offered=false
env.unitReplacementConfirm({color="Red"})
assert(not savedSnapshot and not oldTrashed and not newClaimed,
    "Invalidated offered Unit must not start the replacement transaction")
candidate.offered=true
env.unitReplacementConfirm({color="Red"})
assert(savedSnapshot and finished and oldTrashed and newClaimed,
    "Confirmation must replace the old Unit inside the rewind transaction")
assert(woundReturned,"The disbanded Unit's Wounds should return to the pool")
assert(banner.moved,"An attached Banner should move to the discard area")
assert(objects[command.guid]~=nil and objects[bonusCommand.guid]~=nil,
    "Command tokens and Banner/Bonds capacity must survive replacement")
assert(command.moved and command.position[3]==-39,
    "Spent Unit replacement must move the actual Command to its Ready snap")
assert(state.unitReplacementPending==nil and attrs["UnitReplacement:active"]=="false")
assert(not candidate.offered,"The new Unit must leave the offer only after confirmation")
print("Full Unit Area replacement, cancellation and Command ownership regressions passed")

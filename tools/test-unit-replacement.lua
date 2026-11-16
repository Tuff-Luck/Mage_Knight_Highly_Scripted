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
local assignments=read("src/PlayingGame/AttackAssignments.lua")
local replacementPanel=read("src/UI/UnitReplacement.xml")
local flow=read("src/PlayingGame/PlayerBoard/CardFlow.lua")
local entry=read(".tts/objects/Global.lua")
local callbacks=read("src/PlayingGame/Callbacks.lua")
assert(entry:find('require("PlayingGame.PlayerBoard.UnitReplacement")',1,true))
assert(flow:find('unitReplacementBegin(player,claimedCard.guid,seatPos)',1,true))
assert(callbacks:find('"unitReplacementCancel","unitReplacementSelectClicked"',1,true))
assert(not replacementPanel:find('id="UnitReplacementConfirm"',1,true),
    "No Confirm button should remain in the replacement panel")
assert(not replacementPanel:find('id="UnitReplacementClaimText"',1,true),
    "The new Unit name belongs inside the instruction, not its own line")
assert(not replacementPanel:find('id="UnitReplacementSelectedText"',1,true),
    "Selection is now immediate; no second status line should remain")
assert(replacementPanel:find('id="UnitReplacementCancel"',1,true),
    "Cancel must remain available while picking a Unit")
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
    "Command ownership","t",ownerEnv))
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
    bounds={center={x=0,y=1,z=-34.74},size={x=2,y=0.1,z=3,[1]=2,[2]=0.1,[3]=3}},
    UI={nodes={}},buttons={}
}
local candidate={guid="def002",offered=true,resting=true,UI={nodes={}}}
candidate.getButtons=function() return {} end
local wound={guid="aaa123",wound=true,x=0,z=-34.74}
wound.getPosition=function() return {x=0,y=1.5,z=-34.74} end
local banner={guid="bba123",moved=false}
local mana={guid="cba123",staged=false}
mana.getPosition=function() return {x=0,y=1.5,z=-34.74} end
mana.setPositionSmooth=function(pos) mana.staged=pos end
local command={guid="c0a001",resting=true,moved=false}
command.isSmoothMoving=function() return false end
command.setPositionSmooth=function(pos)
    command.moved=true
    command.position=pos
end
local bonusCommand={guid="c0b002"}
local woundReturned,oldTrashed,newClaimed=false,false,false
for _,obj in ipairs({owner,candidate,wound,banner,mana,command,bonusCommand}) do objects[obj.guid]=obj end
owner.getBounds=function() return owner.bounds end
owner.isDestroyed=function() return false end
owner.getScale=function() return {x=1,y=1,z=1} end
owner.getButtons=function() return owner.buttons end
owner.createButton=function(spec)
    spec.index=#owner.buttons
    owner.buttons[#owner.buttons+1]=spec
end
owner.removeButton=function(index)
    table.remove(owner.buttons,index+1)
    for i,button in ipairs(owner.buttons) do button.index=i-1 end
end
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
        slotX={[1]=0,[2]=5},objects={wound,banner,mana,command,bonusCommand}
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
    gStates=state,UI=ui,Global={name="Global"},
    joinLang=function(parts)
        local output={}
        for _,part in ipairs(parts) do
            if type(part)=="string" and part:find("{en}",1,true) then
                output[#output+1]=assert(part:match("^{en}(.-){it}"))
            else
                output[#output+1]=tostring(part)
            end
        end
        return table.concat(output)
    end,
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
    unitLayoutIsUnit=function(obj) return obj==owner or obj==candidate end,
    unitLayoutIsCommand=function(obj) return obj==command or obj==bonusCommand end,
    unitLayoutX=function() return -6 end,
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
-- Execute the same full-card transparent target helper used for damage.
local targetCode=section(assignments,
    "function attackAssignmentsAddInvisibleUnitTargetButton(obj,clickFunction)",
    "local function addDamageTargetButton(obj,clickFunction)")
assert(load(targetCode,"Shared invisible Unit hit-area","t",env))()
env.publishPublicUICallbacks=function(funcs)
    for name,fn in pairs(funcs) do env[name]=fn end
end
assert(load(replacement,"Full Unit replacement","t",env))()
owner.UI.nodes={{tag="Button",attributes={id="UnitReplaceSelect_"..owner.guid}}}
assert(env.unitReplacementBegin({color="Red"},candidate.guid,1),
    "Full board must open the replacement choice")
assert(attrs["UnitReplacement:active"]=="true" and not oldTrashed
    and candidate.offered,"Choice may not claim or trash until Unit is clicked")
local description=attrs["UnitReplacementDescription:text"]
assert(description:find("No free Command Tokens.\nClick a Unit you wish to disband and Replace with New Unit.",1,true),
    "The panel must show the requested two-line instruction and replacement name")
assert(#owner.UI.nodes==0,"No visible DISBAND button must be added to Unit XML")
assert(#owner.buttons==1 and owner.buttons[1].label==""
    and owner.buttons[1].click_function=="unitReplacementSelectClicked",
    "The Unit itself needs a single invisible damage-style hit area")
assert(owner.buttons[1].color[4]==0,
    "Card-wide replacement click area should be fully transparent")
env.unitReplacementEnsureControls(1)
env.unitReplacementEnsureControls(1)
assert(#owner.buttons==1,"Repeated refresh must not stack invisible buttons")
-- Cancel is non-destructive, leaving the Unit offer and current Unit intact.
env.unitReplacementCancel({color="Red"})
assert(not oldTrashed and candidate.offered and state.unitReplacementPending==nil,
    "Cancelling replacement must leave all pieces in place")
assert(attrs["UnitReplacement:active"]=="false","Cancel must close panel")
assert(#owner.buttons==0,"Cancel must remove the invisible hit area")

-- Saving while choosing must restore the panel and the invisible hit area.
assert(env.unitReplacementBegin({color="Red"},candidate.guid,1))
attrs["UnitReplacement:active"]="false"
owner.buttons={}
env.unitReplacementRestoreOnLoad()
assert(attrs["UnitReplacement:active"]=="true" and #owner.buttons==1)
-- The offer can change before a Unit is clicked. In that case the script must
-- leave the old Unit untouched, without locking the selection permanently.
candidate.offered=false
env.unitReplacementSelectClicked(owner,"Red")
assert(not savedSnapshot and not oldTrashed and not newClaimed,
    "Invalidated offered Unit must not start the replacement transaction")
assert(state.unitReplacementPending~=nil and state.unitReplacementPending.committing==false,
    "Failed selection must allow a fresh click")
candidate.offered=true
-- Clicking a Unit is the confirmation. There is no separate Confirm button.
env.unitReplacementSelectClicked(owner,"Red")
assert(savedSnapshot and finished and oldTrashed and newClaimed,
    "Clicking a Unit must replace it inside the rewind transaction")
assert(woundReturned,"The disbanded Unit's Wounds should return to the pool")
assert(banner.moved,"An attached Banner should move to the discard area")
assert(type(mana.staged)=="table" and mana.staged[3]==-40.3,
    "Attached mana/reminders must be staged away from the replacement Unit")
assert(objects[command.guid]~=nil and objects[bonusCommand.guid]~=nil,
    "Command tokens and Banner/Bonds capacity must survive replacement")
assert(command.moved and command.position[3]==-39,
    "Spent Unit replacement must move the actual Command to its Ready snap")
assert(state.unitReplacementPending==nil and attrs["UnitReplacement:active"]=="false")
assert(#owner.buttons==0,"Completed replacement must clear the hit area")
assert(not candidate.offered,"The new Unit must leave the offer only after clicking a Unit")
print("Full Unit Area replacement, cancellation and Command ownership regressions passed")

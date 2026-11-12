-- Regression: card planning during a Proxy turn must not announce failed button checks.
-- Run from the repository root: lua5.2 tools/test-training-permission.lua
local function eq(actual,expected,label)
    if actual~=expected then
        error((label or "Mismatch")..": "..tostring(actual).." ~= "..tostring(expected),2)
    end
end

-- Load only Shared's production permission function: the rest of Shared
-- depends on the live TTS environment and is unrelated to this test.
local handle=assert(io.open("src/Shared.lua","r"))
local shared=handle:read("*a")
handle:close()
local start=assert(shared:find("function legalPlayerCheck(",1,true))
local finish=assert(shared:find("-- Stable physical-object identity helpers.",start,true))
local loadPermission=assert(load(shared:sub(start,finish-1),"legalPlayerCheck from Shared.lua"))
loadPermission()

local broadcasts=0
local lastMessage
broadcastToAll=function(message)
    broadcasts=broadcasts+1
    lastMessage=message
end
joinLang=function(parts) return table.concat(parts) end
translateWord={Norowas="Norowas"}
warningColor={1,0.8,0.2}
Player={
    Red={seated=true,getHandTransform=function() return {position={-60,0,0}} end},
    Blue={seated=true,getHandTransform=function() return {position={-20,0,0}} end}
}
turnOrder={{seatPos=2,mage="Norowas"}}
gStates={firstStarted=true,turnNumber=1,positionMageKnight={[5]="Proxy"}}

eq(legalPlayerCheck("Red",2,"NoDummyException",true),false,"quiet unauthorized check")
eq(broadcasts,0,"quiet check has no broadcast")
eq(legalPlayerCheck("Blue",2,"NoDummyException",true),true,"owning seat still allowed")
eq(legalPlayerCheck("Black",2,"NoDummyException",true),true,"GM still allowed")
eq(legalPlayerCheck("Grey",2,"NoDummyException",true),false,"spectator still rejected")
eq(broadcasts,0,"allowed checks have no broadcast")
eq(legalPlayerCheck("Red",2,"NoDummyException"),false,"original unauthorized check")
eq(broadcasts,1,"ordinary button check still broadcasts")
assert(lastMessage:find("Norowas",1,true),"warning should name the target seat")

local card={guid="111111",type="Card"}
local training={guid="6fdeb0",type="Card"}
local inHand=true
local trainingInPlay=false
local objects={
    ["hand"]={getObjects=function() return inHand and {card} or {} end},
    ["play"]={getObjects=function() return trainingInPlay and {training} or {} end},
    ["111111"]=card,
    ["6fdeb0"]=training
}
getObjectFromGUID=function(guid) return objects[guid] end
handZones={[2]="hand"}
playerPlayAreas={[2]="play"}
gameCards={["111111"]={cardType="Starting"}}
local queued=0
safeWaitCondition=function() queued=queued+1 end
publishPublicUICallbacks=function(callbacks)
    for name,callback in pairs(callbacks) do _G[name]=callback end
end
dofile("src/PlayingGame/TrainingOffer.lua")

local function originTable()
    for i=1,20 do
        local name,value=debug.getupvalue(trainingOfferCardPickedUp,i)
        if name=="fromHand" then return value end
    end
    error("Training hand-origin registry not found")
end

-- Simply holding a card outside the current turn's seat is not an attempted Training use.
trainingOfferCardPickedUp("Red",card)
eq(broadcasts,1,"out-of-turn pickup silent")
eq(originTable()[card.guid],nil,"unauthorized pickup not registered")
trainingOfferObjectDropped("Red",card)
eq(broadcasts,1,"out-of-turn planning drop silent")
eq(queued,0,"no Training work while Training is absent")

-- Even with Training on the current player's board, a different player
-- rearranging cards must not produce a button-only permission warning.
trainingInPlay=true
trainingOfferObjectDropped("Red",card)
eq(broadcasts,1,"unrelated player's drop stays silent")
eq(queued,0,"unauthorized Training action not scheduled")

-- The rightful player can still carry origin evidence from hand pickup.
trainingOfferCardPickedUp("Blue",card)
eq(originTable()[card.guid],2,"owning player's hand origin preserved")
inHand=false
trainingOfferObjectDropped("Blue",card)
eq(queued,1,"authorized Training drop is still processed")
eq(broadcasts,1,"authorized Training drop has no warning")

-- An actual Training button click keeps the original explicit warning.
gStates.trainingOfferPreview={seatPos=2,cardGUID="222222"}
trainingOfferClicked({color="Red"},"","TrainingOfferControl_222222_next")
eq(broadcasts,2,"unauthorized Training button still broadcasts")
print("Training permission regressions passed")

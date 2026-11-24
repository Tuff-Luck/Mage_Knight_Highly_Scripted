-- Verify fresh private state and the coordinator's actual reset semantics.
-- Run from repository root: lua5.2 tools/test-resource-tracker-state.lua
package.path="src/?.lua;"..package.path
local create=require("PlayingGame.PlayerBoard.ResourceTracker.Core.State")
local first,second=create(),create()
assert(first~=second)
for _,key in ipairs({"generation","pendingSeatSettles","pendingSeatRender",
    "crystalHighlightCleared","bySeat","playCandidatesBySeat","playCardMovements",
    "choiceResetGenerationByGUID","palette","totalsKeys"}) do
    assert(type(first[key])=="table" and first[key]~=second[key],key.." must be private")
end
first.generation[2]=8
first.palette.green[1][1]=0
assert(second.generation[2]==nil and second.palette.green[1][1]==0.10)
for _,kind in ipairs({"card","skill","factionReward"}) do
    assert(second.playCandidateKind(kind),kind.." must be a recovery candidate")
end
for _,kind in ipairs({"mana","unit","enemy","wound","Dice"}) do
    assert(not second.playCandidateKind(kind),kind.." must not be a recovery candidate")
end
for _,key in ipairs({"move","influence","healing","attackFire","siegeIce",
    "rangedColdFire","blockPsychic"}) do
    assert(second.totalsKeys[key],key.." must remain a resource total")
end

-- Execute the real coordinator header and reset helper in one lexical scope.
local f=assert(io.open("src/PlayingGame/PlayerBoard/CardRecognition.lua","r"))
local source=f:read("*a")
f:close()
local headerEnd=assert(source:find("-- Catalog is defined once in UnitResources.lua",1,true))
local start=assert(source:find("local function clearAll()",1,true))
local finish=assert(source:find("-- Explicitly resolve Banner of Fortitude",start,true))
local saved={resourceTracker={move={move=3}}}
gStates=saved
turnOrder=nil
resourceCardsPanelOpen=function() return false end
local clearCount=0
local cleared={}
clearChoiceButtons=function() clearCount=clearCount+1 end
clearHighlight=function(guid) cleared[guid]=true end
local private,selected,reset=assert(load(source:sub(1,headerEnd-1)..[[
local combatConfig={}
selectedResourceByGUID.rage={effect="attack"}
choiceExpandedByGUID.rage=true
shown.rage=true
trackerPrivate.generation[2]=7
trackerPrivate.pendingSeatSettles[2]={rage=true}
trackerPrivate.pendingSeatRender[2]=true
trackerPrivate.bySeat[2]={rage=true}
trackerPrivate.playCandidatesBySeat[2]={rage=true}
trackerPrivate.playCardMovements.rage={seatPos=2}
trackerPrivate.cardUIRecheckSerial={rage=1}
resourceCardScanBySeat[2]={totals={attack=2}}
trackerPrivate.traceEnabled=true
]]..source:sub(start,finish-1)..[[
return trackerPrivate,selectedResourceByGUID,function()
    clearAll()
    assert(next(choiceExpandedByGUID)==nil)
    assert(selectedResourceByGUID.rage.effect=="attack")
end
]],"Tracker runtime reset"))()
local oldGeneration=private.generation
local oldWaits=private.pendingSeatSettles
local oldScan=resourceCardScanBySeat
reset()
assert(private.generation==oldGeneration and private.generation[2]==8)
for _,seat in ipairs({1,3,4}) do assert(private.generation[seat]==1) end
assert(private.pendingSeatSettles~=oldWaits)
for _,key in ipairs({"pendingSeatSettles","pendingSeatRender","bySeat",
    "playCandidatesBySeat","playCardMovements","cardUIRecheckSerial"}) do
    assert(next(private[key])==nil,key.." must be reset")
end
assert(resourceCardScanBySeat~=oldScan and next(resourceCardScanBySeat)==nil)
assert(selected.rage.effect=="attack" and clearCount==1 and cleared.rage)
assert(private.traceLines[1]=="0001 tracker.reset seat=- guid=- ")
assert(gStates==saved and gStates.resourceTracker.move.move==3,
    "Closing the runtime scan must not mutate saved offsets")
print("Resource Tracker state isolation and reset regression passed")

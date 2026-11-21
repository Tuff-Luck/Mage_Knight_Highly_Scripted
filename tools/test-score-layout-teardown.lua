-- Regression: late score UI callbacks abort only during strong TTS teardown.
-- Run from repo root: lua5.2 tools/test-score-layout-teardown.lua

local file=assert(io.open("src/PlayingGame/Scoring.lua","r"))
local source=file:read("*a")
file:close()

-- The full displayScore routine is large; verify its guard precedes the
-- ordinary scoring logic without changing its calculations.
assert(source:find('function displayScore(player, mouseButton, id)\n\t-- A late score UI callback',1,true),
    "Score display must guard against late teardown UI calls")
local displayStart=assert(source:find("function displayScore(player, mouseButton, id)",1,true))
local displayGuard=assert(source:find("protectedTableTeardownLikely() then return end",displayStart,true))
local displaySort=assert(source:find("local scoreboardOrder={}",displayStart,true))
assert(displayStart<displayGuard and displayGuard<displaySort,
    "The teardown guard must run before any score-zone lookups or state changes")

-- Execute the real claimed-card layout function with isolated TTS zone mocks.
local start=assert(source:find("function layoutClaimedCards(player, mouseButton, id)",1,true))
local finish=assert(source:find("\n--Swap Day and Night items",start,true))
local body=source:sub(start,finish-1).."\nreturn layoutClaimedCards"

local teardown=false
local scoreCalls={}
local zonesRead=0
local objects={}
for _,guid in ipairs({"deck-2","discard-2","hand-2"}) do
    objects[guid]={getObjects=function() zonesRead=zonesRead+1 return {} end}
end
local env={
    protectedTableTeardownLikely=function() return teardown end,
    gStates={preEndTurn=false,positionMageKnight={[5]="Volkare"}},
    turnOrder={{mage="Tovak",seatPos=2}},
    deedDeckZones={[2]="deck-2"},
    deedDeckDiscardZones={[2]="discard-2"},
    handZones={[2]="hand-2"},
    displayScore=function(...)
        scoreCalls[#scoreCalls+1]={...}
    end,
    getObjectFromGUID=function(guid) return objects[guid] end,
    log=function() end
}
setmetatable(env,{__index=_G})
local layout=assert(load(body,"layoutClaimedCards teardown regression","t",env))()

-- During teardown, score layout must return before Time Bending, scoring, and
-- zone access. The final-layout flag must not be written.
teardown=true
layout(nil,"-1","PreEndTurn")
assert(#scoreCalls==0 and zonesRead==0 and env.finalScoreLayoutPrepared==nil,
    "Probable scene teardown must skip all final-card layout work")

-- The same callback still works normally while the table is intact.
teardown=false
layout(nil,"-1","PreEndTurn")
assert(#scoreCalls==1 and scoreCalls[1][1]=="all" and scoreCalls[1][2]=="-1",
    "Normal final-score layout should still compute scores")
assert(zonesRead==3 and env.finalScoreLayoutPrepared==true,
    "Normal final-score layout should process every zone and finish")

-- Real missing-zone errors during gameplay must continue to propagate to
-- the existing safe-public-callback reporter rather than being suppressed.
env.finalScoreLayoutPrepared=false
objects["hand-2"]=nil
local ok,err=pcall(layout,nil,"-1","PreEndTurn")
assert(ok==false and tostring(err):find("nil value",1,true)~=nil,
    "A genuine gameplay-zone failure must remain visible")

-- Existing Rewards Claimed protection is unchanged.
env.gStates.preEndTurn=true
local before=#scoreCalls
layout(nil,"-1","PreEndTurn")
assert(#scoreCalls==before and env.finalScoreLayoutPrepared==false,
    "Rewards Claimed lock must continue to prevent premature final layout")

print("Score-layout teardown regression passed")

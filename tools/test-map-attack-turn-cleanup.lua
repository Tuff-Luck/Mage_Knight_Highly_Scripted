-- Regression: remote map Attack/Restore controls must disappear on Proxy and other automated turns.
-- Run from repository root: lua5.2 tools/test-map-attack-turn-cleanup.lua
local function read(path)
    local handle=assert(io.open(path,"r"))
    local contents=handle:read("*a")
    handle:close()
    return contents
end
local function eq(actual,expected,message)
    assert(actual==expected,(message or "Mismatch")..": expected "..tostring(expected)..", got "..tostring(actual))
end

local ui=read("src/PlayingGame/UI.lua")
local start=assert(ui:find("local function clearStaleMapActionButtons(obj)",1,true))
local finish=assert(ui:find("\nfunction addAvatarButtons()",start,true))
local helperSource=ui:sub(start,finish-1)
local writes=0
local env={
    setTrackedMapObjectUI=function(obj,xml)
        writes=writes+1
        obj.xml=xml
    end
}
setmetatable(env,{__index=_G})
local clear=assert(load(helperSource.."\nreturn clearStaleMapActionButtons",
    "stale map action button cleanup","t",env))()
local function object(xml)
    local obj={xml=xml}
    obj.UI={getXmlTable=function() return obj.xml end}
    return obj
end
local attack={tag="Button",attributes={id="monsterTovak",onClick="global/attackLocation"}}
local restore={tag="Button",attributes={id="siteTovak",onClick="global/restoreDestroyedSiteAtCurrentPlayer"}}
local unrelated={tag="Button",attributes={id="other",onClick="global/otherAction"}}
local panel={tag="Panel",attributes={id="status"}}

local monster=object({panel,attack,unrelated})
clear(monster)
eq(writes,1,"Stale rampager Attack removed")
eq(#monster.xml,2,"Unrelated map presentation preserved")
eq(monster.xml[1],panel,"Panel remains")
eq(monster.xml[2],unrelated,"Unrelated button remains")
clear(monster)
eq(writes,1,"No repeated empty UI writes")

local destroyed=object({restore})
clear(destroyed)
eq(writes,2,"Stale destroyed-site Restore removed")
eq(#destroyed.xml,1,"Empty placeholder retained for TTS")
eq(destroyed.xml[1].tag,nil,"Restore button gone")

local empty=object({{}})
clear(empty)
eq(writes,2,"Empty map UI is not rewritten")

-- The refresh must reconcile every map action object not updated by an actual
-- Mage Knight. That includes the Proxy/Dummy/Volkare turn, pre-end-turn cleanup,
-- and cases where an avatar object cannot be found.
assert(ui:find("local mapActionButtonsRefreshed={}",1,true),
    "Map action refresh needs an updated-object ledger")
assert(ui:find("mapActionButtonsRefreshed[mapDetails.guid]=true",1,true),
    "Active Mage Knight map actions must be marked as refreshed")
assert(ui:find("if mapActionButtonsRefreshed[mapDetails.guid]~=true then clearStaleMapActionButtons(mapDetails.obj) end",1,true),
    "Any untouched map action object must lose last turn's controls")
assert(ui:find("if order==gStates.turnNumber and gStates.preEndTurn==false then",1,true),
    "Only the current active Mage Knight may create map attacks")
local turn=read("src/PlayingGame/Turn.lua")
assert(turn:find("addAvatarButtons()",assert(turn:find("local function turnFinishCompletedTurnUI()",1,true)),true),
    "Turn-end UI must request map action reconciliation")

print("Map attack turn cleanup regressions passed")

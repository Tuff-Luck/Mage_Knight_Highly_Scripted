-- Regression: automatic reports identify their TTS script session and last save.
-- Run from repo root: lua5.2 tools/test-automatic-report-session-timing.lua
local read=function(path)
    local f=assert(io.open(path,"r"))
    local text=f:read("*a")
    f:close()
    return text
end

local callbackSource=read("src/PlayingGame/Callbacks.lua")
local eventSource=read("src/PlayingGame/Events.lua")
assert(callbackSource:find("function onLoad(saved_data)\n\t-- Capture the actual load event",1,true),
    "onLoad must mark the beginning of a new script session")
assert(callbackSource:find("automaticLuaRecordModLoad()",1,true))
assert(eventSource:find("function onSave()\n\t-- onSave commonly precedes teardown",1,true))
assert(eventSource:find("automaticLuaRecordModSave()",1,true))

local fakeTime=1700000000
local posted={}
local env={
    os={
        time=function() return fakeTime end,
        date=os.date
    },
    gStates={gameScenario="First Reconnaissance",playerCount=1,positionMageKnight={}},
    Player={
        getAvailableColors=function() return {} end,
        Black={seated=false}
    },
    WebRequest={post=function(url,fields,callback)
        assert(type(url)=="string" and type(fields)=="table")
        posted[#posted+1]=fields
        callback({response_code=200,text="ok"})
    end},
    getObjectFromGUID=function() return nil end,
    log=function() end
}
setmetatable(env,{__index=_G})
assert(loadfile("src/ErrorReporting.lua","t",env))()

fakeTime=fakeTime+30
env.automaticLuaRecordModLoad()
local loadAt=fakeTime
fakeTime=fakeTime+75
env.automaticLuaRecordModSave()
local saveAt=fakeTime
fakeTime=fakeTime+15
env.reportAutomaticLuaDiagnostic("testSessionTiming","first check","diagnostic context")
assert(#posted==1)
local comment=posted[1].Comment
assert(comment:find("Reporter Version: 465",1,true))
assert(comment:find("Mod loaded (UTC): "..os.date("!%Y-%m-%d %H:%M:%S UTC",loadAt),1,true))
assert(comment:find("Report generated (UTC): "..os.date("!%Y-%m-%d %H:%M:%S UTC",fakeTime),1,true))
assert(comment:find("Time since mod load: 90s (1m 30s)",1,true))
assert(comment:find("Last onSave (UTC): "..os.date("!%Y-%m-%d %H:%M:%S UTC",saveAt),1,true))
assert(comment:find("Time since onSave: 15s",1,true))
assert(comment:find("diagnostic context",1,true))

-- TTS reloads and rewinds must begin a new session with no stale save age.
fakeTime=fakeTime+20
env.automaticLuaRecordModLoad()
local newLoad=fakeTime
fakeTime=fakeTime+5
env.reportAutomaticLuaDiagnostic("testSessionTimingAfterReload","second check","")
assert(#posted==2)
local afterReload=posted[2].Comment
assert(afterReload:find("Mod loaded (UTC): "..os.date("!%Y-%m-%d %H:%M:%S UTC",newLoad),1,true))
assert(afterReload:find("Time since mod load: 5s (5s)",1,true))
assert(not afterReload:find("Last onSave (UTC):",1,true),
    "New script sessions should not retain timestamps from earlier sessions")

print("Automatic report session timing passed")

-- Regression: automatic reports identify their TTS script session and last save.
-- Run from repo root: lua5.2 tools/test-automatic-report-session-timing.lua
local read=function(path)
    local f=assert(io.open(path,"r"))
    local text=f:read("*a")
    f:close()
    return text
end

local callbackSource=read("src/PlayingGame/GameFlow/Callbacks.lua")
local eventSource=read("src/PlayingGame/GameFlow/Events.lua")
assert(callbackSource:find("function onLoad(saved_data)\n\t-- Capture the actual load event",1,true),
    "onLoad must mark the beginning of a new script session")
assert(callbackSource:find("automaticLuaRecordModLoad()",1,true))
assert(callbackSource:find("end,automaticLuaLoadStageContext)",1,true),
    "onLoad failures must attach their last stage")
assert(callbackSource:find("automaticLuaSetLoadStage(nil)",1,true),
    "successful onLoad must clear the incomplete-load marker")
assert(eventSource:find('automaticLuaSetLoadStage("Events: restore saved game state")',1,true),
    "saved game restoration must have a specific diagnostic stage")
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

fakeTime=fakeTime+30.25
env.automaticLuaRecordModLoad()
local loadAt=fakeTime
fakeTime=fakeTime+75.5
env.automaticLuaRecordModSave()
local saveAt=fakeTime
fakeTime=fakeTime+15.25
env.reportAutomaticLuaDiagnostic("testSessionTiming","first check","diagnostic context")
assert(#posted==1)
local comment=posted[1].Comment
local expectedVersion=assert(read("src/ErrorReporting.lua"):match('local automaticLuaErrorReporterVersion="(%d+)"'),
    "Reporter version must be a numeric string")
assert(comment:find("Reporter Version: "..expectedVersion.."\n",1,true))
assert(comment:find("Mod loaded (UTC): "..os.date("!%Y-%m-%d %H:%M:%S UTC",loadAt),1,true))
assert(comment:find("Report generated (UTC): "..os.date("!%Y-%m-%d %H:%M:%S UTC",fakeTime),1,true))
assert(comment:find("Time since mod load: 90s (1m 30s)",1,true))
assert(not comment:find("90.75s",1,true),"Duration must be rounded down to whole seconds")
assert(comment:find("Last onSave (UTC): "..os.date("!%Y-%m-%d %H:%M:%S UTC",saveAt),1,true))
assert(comment:find("Time since onSave: 15s",1,true))
assert(comment:find("diagnostic context",1,true))

-- TTS reloads and rewinds must begin a new session with no stale save age.
fakeTime=fakeTime+20
env.automaticLuaRecordModLoad()
local newLoad=fakeTime
fakeTime=fakeTime+5.75
env.reportAutomaticLuaDiagnostic("testSessionTimingAfterReload","second check","")
assert(#posted==2)
local afterReload=posted[2].Comment
assert(afterReload:find("Mod loaded (UTC): "..os.date("!%Y-%m-%d %H:%M:%S UTC",newLoad),1,true))
assert(afterReload:find("Time since mod load: 5s (5s)",1,true))
assert(not afterReload:find("Last onSave (UTC):",1,true),
    "New script sessions should not retain timestamps from earlier sessions")

-- The failing phase must survive an unsuccessful load and appear in both
-- its own report and a subsequent destruction report from the same session.
env.automaticLuaSetLoadStage("Events: restore resource and combat choices")
local failed=env.safeCallback("onLoad",function() error("simulated load failure") end,
    env.automaticLuaLoadStageContext)
assert(failed==false)
assert(#posted==3)
assert(posted[3].Comment:find("Load stage: Events: restore resource and combat choices",1,true))
assert(posted[3].Comment:find("Seat configuration initialized: true",1,true))

local destroyed=env.safeCallback("onObjectDestroy",function() error("simulated cleanup failure") end,
    function() return "Destroyed object GUID=startup\n"..env.automaticLuaLoadStageContext() end)
assert(destroyed==false)
assert(#posted==4)
assert(posted[4].Comment:find("Destroyed object GUID=startup",1,true))
assert(posted[4].Comment:find("Load stage: Events: restore resource and combat choices",1,true))
env.automaticLuaSetLoadStage(nil)
assert(env.automaticLuaLoadStageContext()=="",
    "Successful loading must not mark later destruction as a partial startup")
env.automaticLuaRecordModLoad()
assert(env.automaticLuaLoadStageContext():find("Load stage: onLoad entered",1,true),
    "A reload must discard the earlier failed stage")

print("Automatic report session timing and startup diagnostics passed")

-- Regression: automatic zone-error diagnostics must survive expired TTS userdata.
-- Run from the repository root: lua5.2 tools/test-zone-error-context.lua
local file=assert(io.open("src/ErrorReporting.lua","r"))
local source=file:read("*a")
file:close()

local function codeBetween(startText,endText)
    local first=assert(source:find(startText,1,true),"Missing "..startText)
    local last=assert(source:find(endText,first+#startText,true),"Missing "..endText)
    return source:sub(first,last-1)
end

local env={
    automaticLuaErrorValue=function(callback,fallback)
        local ok,value=pcall(callback)
        return ok and value~=nil and value or fallback
    end,
    automaticLuaErrorStateValue=function(_,fallback) return fallback end,
    playerZoneLookup={}
}
setmetatable(env,{__index=_G})
local contextCode=codeBetween("automaticLuaZoneContext=function(zone, obj)","\nfunction automaticLuaTurnPhaseContext")
local createContext=assert(load("local automaticLuaZoneContext\n"..contextCode..
    "\nreturn automaticLuaZoneContext","Zone context test","t",env))
local context=createContext()

local disposed=setmetatable({},{
    __index=function(_,key)
        error("Object reference not set to an instance of an object: "..tostring(key))
    end
})
local result=context(disposed,disposed)
assert(result:find("Object: unavailable",1,true),"Missing expired-object GUID fallback")
assert(result:find("Object type: unavailable",1,true),"Missing expired-object type fallback")
assert(result:find("Zone: unavailable",1,true),"Missing expired-zone GUID fallback")

-- A failed callback must remain captured even if the native object is expired.
local errors={}
env.automaticLuaZoneContext=context
env.automaticLuaTraceback=function(err) return tostring(err) end
env.automaticLuaBreadcrumb=function() end
env.automaticLuaProtectedCallbackDepth=0
env.reportAutomaticLuaError=function(name,err,details)
    errors[#errors+1]={name=name,error=err,context=details}
end
local callbackCode=codeBetween("function safeZoneCallback(functionName, callback, zone, obj)",
    "\n-- Lightweight boundary for hot TTS callbacks")
local createCallback=assert(load(callbackCode.."\nreturn safeZoneCallback",
    "Safe zone callback test","t",env))
local safeZoneCallback=createCallback()
local callbackResult=safeZoneCallback("onObjectLeaveZone",function()
    error("Original callback error",0)
end,disposed,disposed)
assert(callbackResult==false,"Failed zone callback unexpectedly succeeded")
assert(#errors==1 and errors[1].name=="onObjectLeaveZone","Original callback was not reported")
assert(errors[1].context:find("Object: unavailable",1,true),
    "Reporter failed to retain safe object context")

-- Failure in the diagnostic context itself must also be contained.
env.automaticLuaZoneContext=function() error("Expired object during diagnostics",0) end
callbackResult=safeZoneCallback("onObjectLeaveZone",function() error("Original callback error",0) end,
    disposed,disposed)
assert(callbackResult==false and #errors==2,"Diagnostic failure escaped its guard")
assert(errors[2].context:find("Zone/object context unavailable:",1,true),
    "Missing fallback for failed zone-context builder")

print("Expired-zone diagnostics regression passed")

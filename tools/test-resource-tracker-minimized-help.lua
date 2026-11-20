-- The Resource Tracker ? must open its independent floating Help even while
-- the resource tracker is minimized and automation is switched OFF.
-- Run from repository root: lua5.2 tools/test-resource-tracker-minimized-help.lua
local function read(path)
    local file=assert(io.open(path,"r"))
    local content=file:read("*a")
    file:close()
    return content
end
local src=read("src/PlayingGame/UI.lua")
local first=assert(src:find("local RESOURCE_TRACKER_EXPANDERS={",1,true))
local last=assert(src:find("local RESOURCE_TRACKER_ZERO_TEXT_COLOR=",first,true))
local attrs={
    ResourceTracker={active="true",height="35"},
    ResourceTrackerDetail={active="false",height="140"},
    CombatCalculatorHelp={active="false"}
}
local calls={scan=0,readiness=0,changed=0}
local ui={}
function ui.getAttribute(id,key)
    return attrs[id] and attrs[id][key] or nil
end
function ui.setAttribute(id,key,value)
    attrs[id]=attrs[id] or {}
    attrs[id][key]=value
end
local env={
    UI=ui,
    resourceCardsPlayerCanEdit=function(color) return color=="Blue" end,
    resourceCardsPanelOpen=function()
        calls.readiness=calls.readiness+1
        return false
    end,
    resourceCardsOnLoad=function() calls.scan=calls.scan+1 end,
    resourceCardsPanelChanged=function() calls.changed=calls.changed+1 end
}
setmetatable(env,{__index=_G})
local click=assert(load(src:sub(first,last-1).."\nreturn resourceTracker",
    "@Resource Tracker Help callback","t",env))()
local function equal(a,b,msg)
    assert(a==b,msg..": expected "..tostring(b)..", got "..tostring(a))
end
local function activate(id,color)
    click({color=color or "Blue"},"-1",id)
end
local xml=read("src/UI/ResourceTracker.xml")
local guideXml=read("src/UI/CombatCalculatorHelp.xml")
assert(xml:find('id="DisplayCombatCalculatorHelp"',1,true),"Missing header Help button")
assert(guideXml:find('id="CombatCalculatorHelp"',1,true),"Missing floating Help panel")
activate("DisplayCombatCalculatorHelp")
equal(ui.getAttribute("CombatCalculatorHelp","active"),"true","Help opens while minimized")
equal(ui.getAttribute("ResourceTrackerDetail","active"),"false","Help does not expand tracker")
equal(ui.getAttribute("ResourceTracker","height"),"35","Tracker stays minimized")
equal(calls.readiness,0,"Help must not check tracker readiness")
equal(calls.scan,0,"Help must not start resource scan")
equal(calls.changed,0,"Help must not restart automation")
activate("CloseCombatCalculatorHelp")
equal(ui.getAttribute("CombatCalculatorHelp","active"),"false","Help closes while minimized")
activate("DisplayCombatCalculatorHelp")
equal(ui.getAttribute("CombatCalculatorHelp","active"),"true","Help reopens while minimized")
activate("DisplayCombatCalculatorHelp","Red")
equal(ui.getAttribute("CombatCalculatorHelp","active"),"true","Unauthorised player cannot toggle Help")
activate("CloseCombatCalculatorHelp")
equal(ui.getAttribute("CombatCalculatorHelp","active"),"false","Close X still works")
print("Resource Tracker minimized Help regression passed")

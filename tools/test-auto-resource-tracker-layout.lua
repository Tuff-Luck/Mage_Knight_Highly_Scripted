-- Resource Tracker nested section height must survive turn handoffs and closing.
-- Run from repo root: lua5.2 tools/test-auto-resource-tracker-layout.lua
local function read(path)
    local f=assert(io.open(path,"r"))
    local result=f:read("*a")
    f:close()
    return result
end
local function slice(source,first,last)
    local a=assert(source:find(first,1,true),"Missing "..first)
    local b=assert(source:find(last,a+#first,true),"Missing "..last)
    return source:sub(a,b-1)
end
local function eq(actual,expected,label)
    assert(actual==expected,(label or "Mismatch")..": expected "..tostring(expected)
        ..", got "..tostring(actual),2)
end

local uiSource=read("src/PlayingGame/UI.lua")
local cardSource=read("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local attrs={
    ResourceTracker={active="true",height="245"},
    ResourceTrackerDetail={active="true",height="210"},
    CombatCalculatorHelp={active="false"}
}
local UI={}
local writes={}
function UI.getAttribute(id,key)
    return attrs[id] and attrs[id][key] or nil
end
function UI.setAttribute(id,key,value)
    if attrs[id]==nil then attrs[id]={} end
    attrs[id][key]=value
    writes[#writes+1]={id=id,key=key,value=value}
end
local openRequests,closedRequests,enabled=0,0,true
local env={
    UI=UI,
    resourceCardsPlayerCanEdit=function() return true end,
    resourceCardsPanelOpen=function() return UI.getAttribute("ResourceTrackerDetail","active")=="true" end,
    resourceCardsSetSeatEnabled=function(value) enabled=value end,
    resourceCardsPanelChanged=function(value)
        if value==false then closedRequests=closedRequests+1 end
    end,
    resourceCardsOnLoad=function() openRequests=openRequests+1 end
}
setmetatable(env,{__index=_G})

-- Load the real UI callback and its layout constants/functions, without starting TTS.
local callbackSource=slice(uiSource,"local RESOURCE_TRACKER_EXPANDERS={",
    "local RESOURCE_TRACKER_ZERO_TEXT_COLOR=")
local callback=assert(load(callbackSource..
    "\nreturn {click=resourceTracker,layout=resourceTrackerSyncLayout,restore=resourceTrackerRestoreExpandedLayout}",
    "Resource Tracker layout","t",env))()
local function click(id)
    callback.click({color="Blue"},"-1",id)
end
local function size(root,detail,label)
    eq(UI.getAttribute("ResourceTracker","height"),tostring(root),label.." root")
    eq(UI.getAttribute("ResourceTrackerDetail","height"),tostring(detail),label.." detail")
end

callback.layout(true)
size(245,210,"Fresh open")
click("DisplayMoveCosts")
eq(UI.getAttribute("MoveCosts","active"),"true","Terrain panel expands")
size(485,450,"Terrain expanded")
click("DisplaySiegeDetails")
size(635,600,"Two expanded sections")

-- Simulate a handoff overwriting only the parent heights, as the old code did.
UI.setAttribute("ResourceTracker","height","245")
UI.setAttribute("ResourceTrackerDetail","height","210")
callback.layout(true)
size(635,600,"Restore visible sections after handoff")
click("DisplaySiegeDetails")
size(485,450,"Collapse one section")
click("DisplayMoveCosts")
size(245,210,"Collapse terrain")

-- Closing turns tracking OFF, resets nested sections, and reopening uses fresh height.
click("DisplayMoveCosts")
click("DisplayResourceTrackerDetails")
size(35,210,"Closed")
eq(UI.getAttribute("ResourceTrackerDetail","active"),"false","Tracker details close")
eq(UI.getAttribute("MoveCosts","active"),"false","Terrain closes with tracker")
eq(enabled,false,"Tracker disabled")
eq(closedRequests,1,"Panel OFF cleanup")
click("DisplayResourceTrackerDetails")
size(245,210,"Reopened")
eq(enabled,true,"Tracker enabled")
eq(openRequests,1,"Tracker startup requested")

-- A handoff to another seat must use the same layout calculation instead
-- of forcibly resetting an expanded panel to the 245/210 defaults.
local handoffCode=slice(cardSource,
    "function resourceCardsAfterTurnHandoff(previousSeat)",
    "-- Shared by saved-game load")
env.gStates={firstStarted=true,turnNumber=2}
env.turnOrder={{seatPos=1},{seatPos=2}}
env.resourceCardsSeatEnabled=function(seat) return seat~=3 end
local handoff=assert(load(handoffCode..
    "\nreturn resourceCardsAfterTurnHandoff","Tracker handoff","t",env))()
UI.setAttribute("MoveCosts","active","true")
handoff(1)
size(485,450,"Turn handoff keeps expanded terrain readable")
eq(UI.getAttribute("ResourceTrackerDetail","active"),"true","Incoming enabled seat opens")
eq(openRequests,2,"Incoming seat startup requested")

env.turnOrder[3]={seatPos=3}
env.gStates.turnNumber=3
handoff(2)
size(35,210,"Disabled seat stays collapsed")
eq(UI.getAttribute("ResourceTrackerDetail","active"),"false","Disabled seat details close")
env.gStates.turnNumber=2
handoff(3)
size(485,450,"Restored enabled seat keeps expanded terrain")

-- Reopening should not depend on a stale root height left by a previous turn.
UI.setAttribute("ResourceTracker","height","35")
click("DisplayResourceTrackerDetails")
size(35,210,"Closing despite stale height")
click("DisplayResourceTrackerDetails")
size(245,210,"Reopening after stale height")

-- TTS rewinds start from 35px XML. The layout must be sized before enabling
-- the lower-anchored detail panel, otherwise it covers the header off-screen.
UI.setAttribute("ResourceTracker","height","35")
UI.setAttribute("ResourceTrackerDetail","active","false")
UI.setAttribute("MoveCosts","active","true")
UI.setAttribute("SiegeAmountDetails","active","true")
local start=#writes
callback.restore()
size(245,210,"Rewind restores known-good tracker geometry")
eq(UI.getAttribute("ResourceTrackerDetail","active"),"true","Rewind opens tracker")
eq(UI.getAttribute("MoveCosts","active"),"false","Rewind clears terrain expansion")
eq(UI.getAttribute("SiegeAmountDetails","active"),"false","Rewind clears combat expansion")
local rootSize,detailSize,shown=nil,nil,nil
for i=start+1,#writes do
    local write=writes[i]
    if write.id=="ResourceTracker" and write.key=="height" then rootSize=i end
    if write.id=="ResourceTrackerDetail" and write.key=="height" then detailSize=i end
    if write.id=="ResourceTrackerDetail" and write.key=="active" and write.value=="true" then shown=i end
end
assert(rootSize~=nil and detailSize~=nil and shown~=nil
    and rootSize<shown and detailSize<shown,
    "Rewind must size both panels before showing the resource details")
local xml=read("src/UI/ResourceTracker.xml")
assert(xml:find('id="ResourceTrackerDetail"',1,true)
    <xml:find('id="DisplayResourceTrackerDetails"',1,true),
    "Minimize button must render above details if the panels overlap")

print("Resource Tracker layout, header and rewind regression tests passed")

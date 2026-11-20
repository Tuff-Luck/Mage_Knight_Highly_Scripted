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
    ResourceTracker={active="true",height="175"},
    ResourceTrackerDetail={active="true",height="140"},
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
local renderSource=slice(uiSource,"local RESOURCE_TRACKER_ZERO_TEXT_COLOR=",
    "function resetResourceTrackerState()")
local callback=assert(load(callbackSource..renderSource..
    "\nreturn {click=resourceTracker,layout=resourceTrackerSyncLayout,restore=resourceTrackerRestoreExpandedLayout,render=refreshResourceTrackerText}",
    "Resource Tracker layout","t",env))()
local function click(id)
    callback.click({color="Blue"},"-1",id)
end
local function size(root,detail,label)
    eq(UI.getAttribute("ResourceTracker","height"),tostring(root),label.." root")
    eq(UI.getAttribute("ResourceTrackerDetail","height"),tostring(detail),label.." detail")
end

callback.layout(true)
size(175,140,"Fresh open")
click("DisplayMoveCosts")
eq(UI.getAttribute("MoveCosts","active"),"true","Terrain panel expands")
size(415,380,"Terrain expanded")
click("DisplaySiegeDetails")
size(415,380,"Legacy combat submenu is gone")

-- Simulate a handoff overwriting only the parent heights, as the old code did.
UI.setAttribute("ResourceTracker","height","175")
UI.setAttribute("ResourceTrackerDetail","height","140")
callback.layout(true)
size(415,380,"Restore terrain after handoff")
click("DisplaySiegeDetails")
size(415,380,"Combat dropdown remains removed")
click("DisplayMoveCosts")
size(175,140,"Collapse terrain")

-- Closing turns tracking OFF, resets nested sections, and reopening uses fresh height.
click("DisplayMoveCosts")
click("DisplayResourceTrackerDetails")
size(35,140,"Closed")
eq(UI.getAttribute("ResourceTrackerDetail","active"),"false","Tracker details close")
eq(UI.getAttribute("MoveCosts","active"),"false","Terrain closes with tracker")
eq(enabled,false,"Tracker disabled")
eq(closedRequests,1,"Panel OFF cleanup")

-- Help is independent of the resource scans and works from the 35px OFF header.
click("DisplayCombatCalculatorHelp")
eq(UI.getAttribute("CombatCalculatorHelp","active"),"true","Help opens while tracker minimized")
size(35,140,"Opening Help keeps tracker collapsed")
eq(UI.getAttribute("ResourceTrackerDetail","active"),"false","Help must not expand tracker")
eq(enabled,false,"Help must not enable tracker automation")
eq(openRequests,0,"Help must not start a resource scan")
click("CloseCombatCalculatorHelp")
eq(UI.getAttribute("CombatCalculatorHelp","active"),"false","Help closes while tracker minimized")
click("DisplayCombatCalculatorHelp")
eq(UI.getAttribute("CombatCalculatorHelp","active"),"true","Help can reopen while minimized")
click("DisplayResourceTrackerDetails")
eq(UI.getAttribute("CombatCalculatorHelp","active"),"true","Reopening tracker preserves open Help")
click("DisplayResourceTrackerDetails")
eq(UI.getAttribute("CombatCalculatorHelp","active"),"false","Minimizing tracker still closes Help")
click("DisplayResourceTrackerDetails")
size(175,140,"Reopened")
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
size(415,380,"Turn handoff keeps expanded terrain readable")
eq(UI.getAttribute("ResourceTrackerDetail","active"),"true","Incoming enabled seat opens")
eq(openRequests,2,"Incoming seat startup requested")

env.turnOrder[3]={seatPos=3}
env.gStates.turnNumber=3
handoff(2)
size(35,380,"Disabled seat stays collapsed")
eq(UI.getAttribute("ResourceTrackerDetail","active"),"false","Disabled seat details close")
env.gStates.turnNumber=2
handoff(3)
size(415,380,"Restored enabled seat keeps expanded terrain")

-- Reopening should not depend on a stale root height left by a previous turn.
UI.setAttribute("ResourceTracker","height","35")
click("DisplayResourceTrackerDetails")
size(35,140,"Closing despite stale height")
click("DisplayResourceTrackerDetails")
size(175,140,"Reopening after stale height")

-- TTS rewinds start from 35px XML. The layout must be sized before enabling
-- the lower-anchored detail panel, otherwise it covers the header off-screen.
UI.setAttribute("ResourceTracker","height","35")
UI.setAttribute("ResourceTrackerDetail","active","false")
UI.setAttribute("MoveCosts","active","true")

local start=#writes
callback.restore()
size(175,140,"Rewind restores known-good tracker geometry")
eq(UI.getAttribute("ResourceTrackerDetail","active"),"true","Rewind opens tracker")
eq(UI.getAttribute("MoveCosts","active"),"false","Rewind clears terrain expansion")

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
local combatXml=read("src/UI/CombatEnemyPanel.xml")
assert(xml:find('id="ResourceTrackerDetail"',1,true)
    <xml:find('id="DisplayResourceTrackerDetails"',1,true),
    "Minimize button must render above details if the panels overlap")
assert(not xml:find('id="DisplaySiegeDetails"',1,true),"Combat dropdowns must be removed")
assert(xml:find('id="CombatMoveRow"',1,true),"Combat Move requires its own conditional row")
assert(xml:find('id="HealiGeneratedRow"',1,true),"Healing requires a conditional Generated row")
assert(xml:find('id="MovemGeneratedRow"',1,true),"Move requires a conditional Generated row")
assert(xml:find('id="MoveCostHeader"',1,true)>xml:find('id="ResourceTrackerAddRow"',1,true),
    "Terrain Costs must be the bottom section under resource controls")

-- With zero visible resources, the tracker still exposes a 23px + control row
-- (35px title + 38px terrain header). It must still be considered open, or
-- adding cards will never trigger the first resource scan.
local readyCode=slice(cardSource,"function resourceCardsPanelReady()",
    "function resourceCardsPanelOpen()")
local ready=assert(load(readyCode.."\nreturn resourceCardsPanelReady",
    "Tracker scan readiness","t",env))()
env.gStates.resourceTracker={
    move={move=0},
    influence={generated=0,reputation=0,cityShields=0},
    healing={healing=0}
}
env.gStates.moveCost={}
env.refreshResourceTrackerReputation=function() end
env.resourceCardsEnemyPresent=function() return false end
env.currentCityShieldInfluence=function() return 0 end
env.resourceCardsEffectiveTerrainCost=function() return 2 end
env.resourceCardsEffectiveCombatMove=function() return 0 end
env.joinLang=function(parts) return table.concat(parts) end
local move,influence,healing=0,0,0
env.resourceCardsCurrentTotals=function() return {influence=influence,healing=healing} end
env.resourceCardsEffectiveMove=function() return move end
local generatedMove=nil
env.resourceCardsGeneratedMove=function() return generatedMove or move end
env.resourceCardsEffectiveValue=function(category,field)
    if category=="healing" and field=="healing" then return healing end
    return 0
end
callback.render()
size(85,50,"Zero resources compact height")
eq(UI.getAttribute("MovemAmountPlainRow","active"),"false","Empty Move hidden")
eq(UI.getAttribute("InfluAmountPlainRow","active"),"false","Empty Influence hidden")
eq(UI.getAttribute("HealiAmountPlainRow","active"),"false","Empty Healing hidden")
eq(ready(),true,"Compact open tracker must still scan cards")

move,influence,healing=4,2,1
callback.render()
size(166,131,"Three resources expand tracker")
eq(UI.getAttribute("MovemGeneratedRow","active"),"false","Unadjusted Move hides Generated")
eq(UI.getAttribute("MovemAmountPlainRow","active"),"true","Move reappears")
eq(UI.getAttribute("InfluAmountPlainRow","active"),"true","Influence reappears")
eq(UI.getAttribute("HealiAmountPlainRow","active"),"true","Healing reappears")

-- Manual adjustments change Move but not the printed generated amount.
generatedMove=4
move=3
callback.render()
size(189,154,"Move adjustment displays Generated")
eq(UI.getAttribute("MovemGeneratedRow","active"),"true","Adjusted Move shows Generated")
eq(UI.getAttribute("MovemGeneratedText","text"),"Generated : 4",
    "Move Generated remains the played-card amount")
move=4
callback.render()
size(166,131,"Undo Move adjustment hides Generated")
eq(UI.getAttribute("MovemGeneratedRow","active"),"false","Generated hides when matching Move")
generatedMove=nil
move,influence,healing=0,0,0
callback.render()
size(85,50,"Resources removed shrink tracker")
eq(ready(),true,"Empty tracker remains ready for next card")
click("DisplayMoveCosts")
size(325,290,"Expanded terrain has no extra bottom buffer")
click("DisplayMoveCosts")
size(85,50,"Collapsed terrain returns to flush bottom")
UI.setAttribute("ResourceTracker","height","35")
eq(ready(),false,"Collapsed header cannot scan")
UI.setAttribute("ResourceTracker","height","85")
UI.setAttribute("ResourceTrackerDetail","active","false")
eq(ready(),false,"Hidden detail cannot scan")

-- Neither reputation nor owned-city Shields should create Influence by
-- themselves. Positive card-generated Influence or a manual substitute enables
-- both only outside combat. Preserve the -99 No Interaction restriction.
env.gStates.resourceTracker.influence.reputation=3
env.currentCityShieldInfluence=function() return 2 end
callback.render()
size(85,50,"No played Influence cannot activate Reputation or City Shields")
eq(UI.getAttribute("InfluAmountPlainRow","active"),"false",
    "No unplayed Influence total from modifiers")
eq(UI.getAttribute("InfluAmountReputRow","active"),"false",
    "Unplayed Reputation bonus hidden")
eq(UI.getAttribute("InfluAmountCitySRow","active"),"false",
    "Unplayed City Shields bonus hidden")
eq(UI.getAttribute("InfluAmountPlainAdd","active"),"true",
    "Add Influence remains available before a source is played")

influence=2
callback.render()
size(189,154,"Played Influence enables both modifiers")
eq(UI.getAttribute("InfluAmountPlainText","text"),"Influence : 7",
    "Influence 2 + Reputation 3 + City Shields 2")
eq(UI.getAttribute("InfluAmountReputRow","active"),"true",
    "Reputation visible after Influence play")
eq(UI.getAttribute("InfluAmountCitySRow","active"),"true",
    "City Shields visible after Influence play")
eq(UI.getAttribute("InfluAmountPhysiText","text"),"Generated : 2",
    "Generated breakdown excludes Interaction modifiers")

influence=0
env.gStates.resourceTracker.influence.generated=1
callback.render()
size(189,154,"Manually played Influence enables both modifiers")
eq(UI.getAttribute("InfluAmountPlainText","text"),"Influence : 6",
    "Manual 1 + Reputation 3 + City Shields 2")
env.gStates.resourceTracker.influence.generated=0

influence=2
env.resourceCardsEnemyPresent=function() return true end
callback.render()
size(120,85,"Combat suppresses Interaction modifiers")
eq(UI.getAttribute("InfluAmountPlainText","text"),"Influence : 2",
    "Combat shows source Influence only")
eq(UI.getAttribute("InfluAmountReputRow","active"),"false",
    "Combat hides Reputation")
eq(UI.getAttribute("InfluAmountCitySRow","active"),"false",
    "Combat hides City Shields")
env.resourceCardsEnemyPresent=function() return false end

env.gStates.resourceTracker.influence.reputation=-99
callback.render()
eq(UI.getAttribute("InfluAmountPlainRow","active"),"false",
    "No Interaction prevents Influence despite generated points")
eq(UI.getAttribute("InfluAmountReputRow","active"),"true",
    "No Interaction warning shown after playing Influence")
env.gStates.resourceTracker.influence.reputation=0
env.currentCityShieldInfluence=function() return 0 end
influence=0
callback.render()
size(85,50,"Clearing Influence removes its modifiers")

local trackerWidth=tonumber(xml:match('id="ResourceTracker"[^>]-width="(%d+)"'))
local trackerX=tonumber(xml:match('id="ResourceTracker"[^>]-offsetXY="(%d+)'))
local combatX=tonumber(combatXml:match('id="CombatEnemyPanel"[^>]-offsetXY="(%d+)'))
eq(trackerWidth,225,"Tracker must stay within its original combat boundary")
eq(combatX-trackerX-trackerWidth,5,"Tracker and calculator must have five units gap")
assert(xml:find('id="ResourceTracker"[^>]-color="rgb%(0%.24,0%.2,0%.15%)"'),
    "Tracker should use the combat calculator runtime dark-brown colour")
assert(cardSource:find('function resourceCardsPanelReady()',1,true)
    and cardSource:find('UI.getAttribute("ResourceTrackerDetail","active")=="true"',1,true),
    "Tracker scanning readiness must still follow the expanded state")
for _,prefix in ipairs({"MovemAmountPlain","InfluAmountPlain","HealiAmountPlain"}) do
    assert(xml:find('id="'..prefix..'Down" rectAlignment="MiddleLeft" width="112"',1,true),
        prefix.." must have a broad left-side reduce target")
    assert(xml:find('id="'..prefix..'Up" rectAlignment="MiddleRight" width="113"',1,true),
        prefix.." must have a broad right-side increase target")
    assert(xml:find('id="'..prefix..'Add" active="false"',1,true),
        prefix.." must be restorable when its zero row disappears")
    for _,direction in ipairs({"Down","Up"}) do
        assert(xml:find('id="'..prefix..direction..'"',1,true),
            prefix.." must retain "..direction.." click area")
    end
end
for _,prefix in ipairs({"Movem","Siege","Range","Block","Attac","Influ","Heali"}) do
    assert(xml:find('id="'..prefix..'AmountPlainText" fontSize="18" fontStyle="Normal"',1,true),
        prefix.." headline must be 18pt with normal weight")
end
for _,prefix in ipairs({"MovemAmountPlain","InfluAmountPlain","HealiAmountPlain"}) do
    for _,direction in ipairs({"Down","Up"}) do
        assert(xml:find('id="'..prefix..direction..'"[^>]*colors="#FFFFFF00|#FFFFFF00|#FFFFFF00|#FFFFFF00"'),
            prefix.." "..direction.." must stay transparent on hover")
    end
end
assert(not xml:find('tooltip="[Ii]ncrease [MHI]',1,false)
    and not xml:find('tooltip="Decrease ',1,true),
    "Tracker adjustment buttons must not have tooltips")
for _,prefix in ipairs({"Siege","Range","Block","Attac"}) do
    assert(xml:find('id="'..prefix..'SingleElement"[^>]-offsetXY="-16 0"',1,false),
        prefix.." element label must match 16-unit left padding on the right")
end
assert(uiSource:find('id:sub(17,19)=="Add"',1,true),"Missing-resource + clicks must route as increases")
assert(xml:find('id="MoveCostHeaderText"',1,true),
    "Terrain Costs must have an id for translated text reapplication")
for _,id in ipairs({"MovemAmountPlainRow","InfluAmountPlainRow","HealiAmountPlainRow"}) do
    assert(xml:find('id="'..id..'" active="false"',1,true),
        id.." must start hidden before the first scan")
end

-- Exercise the actual saved-game reload path for both per-seat states.
-- A fresh Global XML begins with a collapsed header regardless of how the
-- active player's enablement preference was saved in gStates.
local onLoadSource=slice(cardSource,"function resourceCardsOnLoad(restoringSave)",
    "local function resourceCardsRelevantZone(ctx)")
local function simulateSavedTrackerReload(savedEnabled)
    local savedAttrs={
        ResourceTracker={active="true",height="35"},
        ResourceTrackerDetail={active="false",height="140"},
        MoveCosts={active="false"}
    }
    local events={}
    local savedUI={}
    function savedUI.getAttribute(id,key)
        return savedAttrs[id] and savedAttrs[id][key] or nil
    end
    function savedUI.setAttribute(id,key,value)
        savedAttrs[id]=savedAttrs[id] or {}
        savedAttrs[id][key]=value
        events[#events+1]={id=id,key=key,value=value}
    end
    local stored={
        firstStarted=true,turnNumber=1,
        resourceTrackerEnabledBySeat={[1]=savedEnabled}
    }
    local private={trackerStartupRequest=0,restoreAssignmentsPending=false}
    local calls={started=0,stopped=0,restoredAssignments=0}
    local loadEnv={
        UI=savedUI,gStates=stored,trackerPrivate=private,
        turnOrder={{seatPos=1}},
        resourceCardsSeatEnabled=function(seat)
            return stored.resourceTrackerEnabledBySeat[seat]~=false
        end,
        resourceCardsSetSeatEnabled=function(enabled)
            stored.resourceTrackerEnabledBySeat[1]=enabled
        end,
        resourceCardsPlayerCanEdit=function() return true end,
        resourceCardsPanelReady=function()
            return savedUI.getAttribute("ResourceTracker","active")=="true"
                and savedUI.getAttribute("ResourceTrackerDetail","active")=="true"
                and (tonumber(savedUI.getAttribute("ResourceTracker","height")) or 0)>35
        end,
        resourceCardsPanelChanged=function(open)
            if open then
                calls.started=calls.started+1
                private.trackerWasDisabled=false
            else
                calls.stopped=calls.stopped+1
                private.trackerWasDisabled=true
            end
        end,
        safeWaitCondition=function(_,callback,condition)
            if condition() then callback() end
        end,
        attackAssignmentsRestore=function()
            calls.restoredAssignments=calls.restoredAssignments+1
        end
    }
    setmetatable(loadEnv,{__index=_G})
    local layout=assert(load(callbackSource..
        "\nreturn {sync=resourceTrackerSyncLayout,restore=resourceTrackerRestoreExpandedLayout,click=resourceTracker}",
        "Reload layout functions","t",loadEnv))()
    loadEnv.resourceTrackerSyncLayout=layout.sync
    loadEnv.resourceTrackerRestoreExpandedLayout=layout.restore
    loadEnv.resourceCardsOnLoad=assert(load(onLoadSource.."\nreturn resourceCardsOnLoad",
        "Saved tracker reload","t",loadEnv))()
    loadEnv.resourceCardsOnLoad(true)
    return savedUI,stored,private,calls,events,layout.click
end

local closedUI,closedSaved,closedPrivate,closedCalls,_,closedClick=simulateSavedTrackerReload(false)
eq(closedUI.getAttribute("ResourceTracker","height"),"35","Closed save stays header-only")
eq(closedUI.getAttribute("ResourceTrackerDetail","active"),"false","Closed save stays collapsed")
eq(closedCalls.started,0,"Closed save must not scan play area")
eq(closedCalls.stopped,1,"Closed save keeps automation disabled")
eq(closedSaved.resourceTrackerEnabledBySeat[1],false,"Closed seat preference is preserved")
eq(closedPrivate.restoreAssignmentsPending,true,
    "Closed save defers assignments until explicit reopening")

-- The user can open a previously closed save; reopening must enable the
-- preference and restore the panel/scanning through its normal click flow.
closedClick({color="Blue"},"-1","DisplayResourceTrackerDetails")
eq(closedUI.getAttribute("ResourceTracker","height"),"175",
    "Manual reopening resizes tracker before scan")
eq(closedUI.getAttribute("ResourceTrackerDetail","active"),"true",
    "Manual reopening restores detail panel")
eq(closedSaved.resourceTrackerEnabledBySeat[1],true,
    "Manual reopening updates saved seat preference")
eq(closedCalls.started,1,"Manual reopening restarts automation")
eq(closedCalls.restoredAssignments,1,
    "Manual reopening recovers a deferred assignment if present")

local openUI,openSaved,openPrivate,openCalls,openEvents=simulateSavedTrackerReload(true)
eq(openUI.getAttribute("ResourceTrackerDetail","active"),"true",
    "Open save restores expanded detail panel")
eq(openUI.getAttribute("ResourceTracker","height"),"175",
    "Open save sizes root before first rescan")
eq(openCalls.started,1,"Open save starts automation exactly once")
eq(openCalls.stopped,0,"Open save must not be disabled by initial collapsed XML")
eq(openCalls.restoredAssignments,1,
    "Open save restores previously saved enemy targeting")
eq(openSaved.resourceTrackerEnabledBySeat[1],true,"Open save keeps enabled preference")
eq(openPrivate.restoreAssignmentsPending,false,"Open save completes pending restore")
local rootSize,detailSize,detailShow=nil,nil,nil
for index,write in ipairs(openEvents) do
    if write.id=="ResourceTracker" and write.key=="height" then rootSize=index end
    if write.id=="ResourceTrackerDetail" and write.key=="height" then detailSize=index end
    if write.id=="ResourceTrackerDetail" and write.key=="active"
        and write.value=="true" then detailShow=index end
end
assert(rootSize~=nil and detailSize~=nil and detailShow~=nil
    and rootSize<detailShow and detailSize<detailShow,
    "Reload must size the tracker before making its contents visible")

print("Resource Tracker layout, scanning, localization and rewind regression tests passed")

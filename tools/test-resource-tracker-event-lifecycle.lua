-- Exercise production delayed scan cancellation and live choice-table reset.
local root="src/PlayingGame/PlayerBoard/ResourceTracker/"
local function eq(a,b,label) assert(a==b,label..": expected "..tostring(b)..", got "..tostring(a)) end
local frames,conditions={},{}
local open=true
local object={guid="card",ready=false}
local env=setmetatable({
    gStates={resourceCardPlayOrder={card=1}},turnOrder={{seatPos=1}},
    resourceCardsPanelOpen=function() return open end,
    getObjectFromGUID=function(guid) return object end,
    safeWaitFrames=function(owner,callback,n) frames[#frames+1]=callback end,
    safeWaitCondition=function(owner,callback,condition,timeout,onTimeout)
        conditions[#conditions+1]={callback=callback,condition=condition,onTimeout=onTimeout}
    end,
    resourceCardsArtifactBreakClear=function(guid) end,
    unitHistoryValidSources=function(seat) end
},{__index=_G})
local tracker={generation={[1]=1},pendingSeatRender={},pendingSeatSettles={},
    choiceResetGenerationByGUID={},playCardMovements={},readyForXZ=function(obj) return obj.ready end}
local scheduler=assert(loadfile(root.."Core/TrackerLifecycle.lua","t",env))().scheduler
local renders=0
local function render(seat) renders=renders+1 end
local function schedule(seat) scheduler.schedule(seat,tracker,render) end
scheduler.queue(1,"card",tracker,schedule)
scheduler.queue(1,"card",tracker,schedule)
eq(#conditions,1,"Duplicate settling events coalesce")
eq(conditions[1].condition(),false,"Unsettled object waits")
object.ready=true
eq(conditions[1].condition(),true,"Settled object releases waiter")
conditions[1].callback()
schedule(1)
eq(#frames,1,"Render request coalesces")
frames[1]()
eq(renders,1,"Exactly one completed render")
schedule(1)
tracker.generation[1]=2
tracker.pendingSeatRender={}
frames[2]()
eq(renders,1,"Old generation cannot render")
local events=assert(loadfile(root.."Core/ObjectEvents.lua","t",env))()
local original={card={effect="attack"}}
local choices=original
local expanded={card=true}
events.scheduleChoiceReset("card",1,function() return choices end,
    function() return expanded end,tracker,function(guid,seat) return false end)
frames[3]()
choices={card={effect="move"}}
expanded={card=true}
eq(conditions[2].condition(),true,"Departure can settle")
conditions[2].callback()
eq(choices.card,nil,"Delayed reset uses current choice table")
eq(expanded.card,nil,"Delayed reset uses current expansion table")
eq(original.card.effect,"attack","Replaced table is untouched")
eq(env.gStates.resourceCardPlayOrder.card,nil,"Genuine departure retires play ordinal")
print("Event scheduling and live-table lifecycle regressions passed")

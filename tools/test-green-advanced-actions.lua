-- Regression checks for the official Green Advanced Actions (not Forgemaster).
-- Run from the repository root: lua5.2 tools/test-green-advanced-actions.lua.
local function source(path)
    local file=assert(io.open(path,"r"))
    local contents=file:read("*a")
    file:close()
    return contents
end
local function section(text,from,to)
    local start=assert(text:find(from,1,true),from)
    local finish=assert(text:find(to,start+1,true),to)
    return text:sub(start,finish-1)
end
local function eq(actual,expected,name)
    assert(actual==expected,tostring(name)..": expected "..tostring(expected)
        ..", got "..tostring(actual))
end
local data=source("src/Data.lua")
local reader=source("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local callbacks=source("src/PlayingGame/Callbacks.lua")

-- Heal 1/2 and Ready are simultaneous. They are not a mutually exclusive
-- choice, and each copied use has its own undoable readying source.
assert(data:find("simultaneousReady=true,unitReadyLevels={normal=2,powered=3}",1,true))
assert(reader:find("choices={{healing=resources.healing}}",1,true))
assert(reader:find('onClick="global/resourceCardsRegenerationReadyClicked"',1,true))
assert(reader:find('unitHistoryCancelReadySource(sourceKey)',1,true))
assert(callbacks:find('"resourceCardsRegenerationReadyClicked"',1,true))

local readyCode=section(reader,
    "function resourceCardsReadySourceValid(sourceKey,seatPos)",
    "function resourceCardsReadyTargetEligible(sourceKey,unitGUID,seatPos)")
local ready=assert(load([[
local unitResourceDefinitions={}
local gameCards={["878d91"]={resourceKey="regeneration"}}
local cardResourceDefinitions={regeneration={unitReadyLevels={normal=2,powered=3}}}
local turnOrder={{seatPos=1}}
local gStates={turnNumber=1}
local record={complete=true,powered=false,resources={healing=1}}
local resourceCardScanBySeat={[1]={cards={["878d91"]=record}}}
local function unitHistorySourceBase(key) return key:match("^[^#]+") end
local function getObjectFromGUID(guid)
    return guid=="878d91" and {is_face_down=false} or nil
end
local function cardPosture(card) return "upright" end
local function cardInSeatPlayArea(guid,seat) return guid=="878d91" and seat==1 end
]]..readyCode..[[
return {valid=resourceCardsReadySourceValid,limit=resourceCardsReadySourceLevelLimit,
    record=record,scans=resourceCardScanBySeat}
]]))()
eq(ready.valid("878d91#ready1",1),true,"One normal Ready")
eq(ready.valid("878d91#ready2",1),false,"No unearned second Ready")
eq(ready.valid("878d91#ready0",1),false,"Zero index rejected")
eq(ready.valid("878d91#ready1",2),false,"Wrong seat rejected")
eq(ready.limit("878d91#ready1",1),2,"Normal level I-II")
ready.record.powered=true
ready.record.resources.healing=2
eq(ready.limit("878d91#ready1",1),3,"Strong level I-III")
ready.record.repeatCount=2
eq(ready.valid("878d91#ready2",1),true,"Copied Ready #2")
eq(ready.valid("878d91#ready3",1),false,"No third copied Ready")
ready.record.repeatCount=3
eq(ready.valid("878d91#ready3",1),true,"Copied Ready #3")
ready.record.repeatCount=1
eq(ready.valid("878d91#ready2",1),false,"Undo copies invalidates excess Ready")
ready.record.complete=false
eq(ready.valid("878d91#ready1",1),false,"Invalid card invalidates Ready")
ready.record.complete=true
ready.scans[1].cards["878d91"]=nil
eq(ready.valid("878d91#ready1",1),false,"Removed card invalidates Ready")

-- Test the actual new object UI callback's left targeting and right undo.
local clickCode=section(reader,
    "function resourceCardsRegenerationReadyClicked(player,value,id)",
    "-- Ready sources need an active effect")
local click=assert(load([[
local gStates={turnNumber=1,unitReadyLinks={}}
local turnOrder={{seatPos=1}}
local targets,removed={},{}
local function resourceCardsPanelOpen() return true end
local function resourceCardsDetailsOpen() return true end
local function resourceCardsPlayerCanEdit(color) return color=="Blue" end
local function resourceCardsReadySourceValid(key) return key=="878d91#ready1" end
local function resourceCardsReadySourceLevelLimit(key,seat) return 2 end
local function attackAssignmentsBeginUnitReady(guid,key,color,limit)
    targets[#targets+1]={guid,key,color,limit}
end
local function unitHistoryCancelReadySource(key)
    removed[#removed+1]=key
    gStates.unitReadyLinks[key]=nil
end
local function resourceCardsSourceChanged() end
]]..clickCode..[[
return {click=resourceCardsRegenerationReadyClicked,targets=targets,removed=removed,
    state=gStates}
]]))()
click.click({color="Blue"},"-1","ResourceCardChoice_878d91_regenReady1")
eq(#click.targets,1,"Ready target initiated")
eq(click.targets[1][4],2,"Ready target level limit")
click.click({color="Blue"},"-1","ResourceCardChoice_878d91_regenReady2")
eq(#click.targets,1,"Cannot target unavailable copied Ready")
click.state.unitReadyLinks["878d91#ready1"]={unitGUID="u1"}
click.click({color="Blue"},"-2","ResourceCardChoice_878d91_regenReady1")
eq(click.removed[1],"878d91#ready1","Right-click undoes linked Ready")
eq(click.state.unitReadyLinks["878d91#ready1"],nil,"Ready link removed")

-- Mountain Lore is a delayed End-Turn effect. A thrown-away Maximal Effect
-- target can be face-down, and copied uses must count independently.
local loreCode=section(reader,
    "function resourceCardsMountainLoreEndTurnBonus(seatPos)",
    "-- Training is resource-neutral")
local mountain=assert(load([[
local terrain="hills"
local tracker=true
local objects={}
local lore={guid="d3995b",is_face_down=false,x=0,requiredColor="Green"}
local maximal={guid="8fac50",is_face_down=false,x=1.4,requiredColor="Red"}
local concentration={guid="450552",is_face_down=false,x=1.4,requiredColor="Green"}
local zone={getObjects=function() return objects end}
local playerPlayAreas={[1]="zone"}
local function currentSpellTerrain() return terrain end
local function getObjectFromGUID(guid) return guid=="zone" and zone or nil end
local function cardPosture(card) return card.posture or "upright" end
local function footprint(card) return {x=card.x,z=0,halfX=1,halfZ=1} end
local function overlapArea(a,b)
    return math.max(0,math.min(a.x+a.halfX,b.x+b.halfX)
        -math.max(a.x-a.halfX,b.x-b.halfX))
end
local function manaColor(obj) return obj.color end
local function matchesCardMana(card,color) return card.requiredColor==color end
local function resourceCardsPanelOpen() return tracker end
local cardResourceDefinitions={
    maximalEffect={requiredLink={mode="repeat",normalCount=3,poweredCount=2}},
    concentration={poweredLink={mode="stronger"}}
}
local gameCards={
    ["8fac50"]={resourceKey="maximalEffect"},
    ["450552"]={resourceKey="concentration"}
}
local record={complete=true,powered=false,repeatCount=3,resources={move=9}}
local resourceCardScanBySeat={[1]={cards={["d3995b"]=record}}}
]]..loreCode..[[
local function token(color,x)
    return {color=color,getPosition=function() return {x,1,0} end}
end
return {
    result=resourceCardsMountainLoreEndTurnBonus,record=record,
    setTerrain=function(t) terrain=t end,
    setTracker=function(t) tracker=t end,
    setCards=function(list)
        for i=#objects,1,-1 do objects[i]=nil end
        for _,item in ipairs(list) do objects[#objects+1]=item end
    end,
    faceDown=function(v) lore.is_face_down=v end,
    lore=lore,maximal=maximal,concentration=concentration,token=token
}
]]))()
mountain.setCards({mountain.lore})
eq(mountain.result(1),3,"Three normal copies on Hills")
mountain.record.powered=true
mountain.record.repeatCount=2
mountain.faceDown(true)
mountain.setTerrain("mountain")
eq(mountain.result(1),4,"Two strong copies on Mountain, face-down card")
mountain.setTerrain("hills")
eq(mountain.result(1),2,"Two strong copies on Hills")
mountain.record.complete=false
eq(mountain.result(1),0,"Invalid play grants no draw")
mountain.record.complete=true
mountain.record.repeatCount=nil
mountain.setTerrain("mountain")
eq(mountain.result(1),2,"Linked stronger action on Mountain")
mountain.setTracker(false)
mountain.faceDown(false)
mountain.setCards({mountain.lore})
eq(mountain.result(1),0,"Closed tracker, unpowered Mountain")
mountain.setTerrain("hills")
eq(mountain.result(1),1,"Closed tracker, unpowered Hills")
mountain.setTerrain("mountain")
mountain.setCards({mountain.lore,mountain.token("Green",0)})
eq(mountain.result(1),2,"Closed tracker, direct Green payment")
mountain.setCards({mountain.lore,mountain.concentration,mountain.token("Green",2.1)})
eq(mountain.result(1),2,"Closed tracker, paid Concentration link")
mountain.faceDown(true)
mountain.setTerrain("hills")
mountain.setCards({mountain.lore,mountain.maximal})
eq(mountain.result(1),3,"Closed tracker, normal Maximal Effect")
mountain.setTerrain("mountain")
mountain.setCards({mountain.lore,mountain.maximal,mountain.token("Red",2.1)})
eq(mountain.result(1),4,"Closed tracker, strong Maximal Effect")
mountain.setCards({})
eq(mountain.result(1),0,"No card yields no draw")
print("Green Advanced Actions: Regeneration and Mountain Lore regressions passed")

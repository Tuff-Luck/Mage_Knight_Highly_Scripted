-- Lock down the existing choice policy before extracting the choice helpers.
-- Run from repository root: lua5.2 tools/test-resource-tracker-choice-policy.lua
package.path="src/?.lua;"..package.path
local f=assert(io.open("src/PlayingGame/PlayerBoard/CardRecognition.lua","r"))
local source=f:read("*a")
f:close()
local function section(first,last)
    local a=assert(source:find(first,1,true),"Missing "..first)
    local b=assert(source:find(last,a+#first,true),"Missing "..last)
    return source:sub(a,b-1)
end
local selected={}
local scans={}
local states={resourceTracker={}}
local env=setmetatable({
    trackerPrivate={},selectedResourceByGUID=selected,
    resourceCardScanBySeat=scans,gStates=states,
    cardPosture=require("PlayingGame.PlayerBoard.ResourceTracker.Scanning.PhysicalObjects").cardPosture
},{__index=_G})
env.require=function(name)
    assert(name=="PlayingGame.PlayerBoard.ResourceTracker.Cards.ResourceChoices")
    return assert(loadfile("src/PlayingGame/PlayerBoard/ResourceTracker/Cards/ResourceChoices.lua","t",env))()
end
local policy=assert(load(table.concat({
    section("trackerPrivate.resourceTotalsKeyByField={","trackerPrivate.attackTransformFamilies="),
    section("local choiceLetters=","local function choiceHasTargetableCombatResource"),
    section("local choiceAvailable=trackerPrivate.choicePolicy.choiceAvailable","-- Only resources that explicitly split"),
    section("local trackerChoiceScores=trackerPrivate.choicePolicy.trackerChoiceScores","local function effectHasTrackedResource"),
    [[return {rank=resourceChoiceRank,column=resourceChoiceColumn,
        sideChoices=sideChoices,category=choiceCategory,available=choiceAvailable,
        current=currentChoice,scores=trackerChoiceScores,
        nearby=trackerPrivate.nearbyCardChoice,guess=guessInitialCardChoice}]]
},"\n"),"Actual choice policy","t",env))()
local function eq(actual,expected,label)
    assert(actual==expected,label..": expected "..tostring(expected)..", got "..tostring(actual))
end

local choices={{attack=2},{move=2},{block=2}}
local rule={normalChoices=choices,powered={attack=4}}
eq(policy.sideChoices(rule,false),choices,"Printed normal options")
eq(policy.sideChoices(rule,true),nil,"Fixed stronger effect must not fall back to weaker options")
eq(policy.category({key="wound",attack=4}),"wound","Explicit option identity")
eq(policy.category(nil),nil,"Absent option")
eq(policy.rank("fireAttack",{attackFire=2}),5,"Fire Attack rank")
eq(policy.rank("other",{key="other",siegeIce=3}),2,"Elemental resource family rank")
eq(policy.column("iceSiege"),"siege","Elemental column")
eq(policy.available(choices,"attack"),true,"Available printed option")
eq(policy.available(choices,"influence"),false,"Unavailable option")

local function card(guid,y)
    return {guid=guid,is_face_down=false,getRotation=function() return {0,y or 0,0} end}
end
local played=card("played")
local function guess(options,definition,sideways,cards,footprints,records)
    policy.guess(played,options,1,definition,sideways,cards or {},footprints or {},records or {})
end
guess(choices,rule,false)
eq(selected.played.effect,"move","Empty totals use tracker family tie order, not printed order")
selected.played=nil
states.resourceTracker={move={move=2},influence={generated=0,reputation=9,cityShields=4}}
scans[1]={cards={played={resources={attack=5}}},totals={attack=5,block=3}}
local scores=policy.scores("played",1)
eq(scores.attack,0,"Subtract own previous contribution")
eq(scores.block,3,"Other card's Block")
eq(scores.move,2,"Manual Move offset")
eq(scores.influence,0,"Reputation and shields must not guess Influence")
guess(choices,rule,false)
eq(selected.played.effect,"block","Highest available generated resource wins")

local neighbor=card("neighbor")
local far=card("far")
local footprints={played={x=0,z=0,halfX=1,halfZ=1},
    neighbor={x=1,z=0,halfX=1,halfZ=1},
    far={x=9,z=0,halfX=1,halfZ=1}}
local records={neighbor={complete=true,resources={attack=2}},
    far={complete=true,resources={move=99}}}
selected.played=nil
guess(choices,rule,false,{played,neighbor,far},footprints,records)
eq(selected.played.effect,"attack","Nearby played Attack outranks remote/global totals")
local old=selected.played
neighbor.is_face_down=true
guess(choices,rule,false,{played,neighbor,far},footprints,records)
eq(selected.played,old,"Manual or established preference must not be replaced")
selected.played=nil
guess(choices,rule,false,{played,neighbor,far},footprints,records)
eq(selected.played.effect,"block","Face-down and distant cards cannot bias spatial guess")
selected.played=nil
guess(choices,{woundConfirmation=true,normalChoices=choices},false)
eq(selected.played,nil,"Never guess a wound-confirmed upright effect")

selected.played={effect="attack",sideways="move"}
local _,key=policy.current("played",false,choices,true)
eq(key,"move","Sideways preference takes priority")
_,key=policy.current("played",false,choices,false)
eq(key,"attack","Printed preference survives sideways use")
_,key=policy.current("played",true,{{healing=2}},false)
eq(key,"healing","Incompatible side shows its printed default")
eq(selected.played.effect,"attack","Fallback must not overwrite preferred resource")
selected.played=nil
states.resourceTracker={move={move=8}}
scans[1]=nil
guess({{attack=1},{move=1}},{normalChoices={{healing=2}}},true)
eq(selected.played.sideways,"move","Incompatible sideways choice stays separate")
eq(selected.played.effect,nil,"Sideways guess must not replace printed preference")
-- The coordinator replaces the selection table on load and turn handoff.
local restored={played={effect="block"}}
env.selectedResourceByGUID=restored
_,key=policy.current("played",false,choices,false)
eq(key,"block","Restored table must be read live")
restored.played=nil
guess(choices,rule,false)
eq(restored.played.effect,"move","New guess must write to current table")
eq(selected.played.sideways,"move","Retired table must remain unchanged")
print("Resource Tracker initial choice, spatial priority and selection preservation passed")

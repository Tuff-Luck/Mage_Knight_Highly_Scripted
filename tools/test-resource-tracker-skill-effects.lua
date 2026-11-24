-- Lock down Skill resource record calculations before extracting them.
-- Run from the repository root using Lua 5.2.
package.path="src/?.lua;"..package.path
local f=assert(io.open("src/PlayingGame/PlayerBoard/CardRecognition.lua","r"))
local source=f:read("*a")
f:close()
local a=assert(source:find("local function calculateSkill(skill,linkedTarget,unitState,inventoryCrystalCounts)",1,true))
local b=assert(source:find("-- Stable modifier instances",a,true))
local tracker={totalsKeys={move=true,attack=true,block=true,blockColdFire=true,
    rangedColdFire=true,influence=true}}
local selected={}
local choices=require("PlayingGame.PlayerBoard.ResourceTracker.ResourceChoices")(
    tracker,function() return selected end,{},nil)
local day=true
local rules={
    normal={normal={attack=2},flipped={block=3}},
    time={day={attack=2},night={block=3}},
    options={choices={{move=1},{attack=2}}},
    chaos={dynamic="masterOfChaos"},
    location={locationInfluence={glade=3,fortified=2,default=1}},
    march={unitCondition={resource="move",ready=true,unwounded=true,max=3}},
    fortune={inventoryDistinctColors={resource="influence",colors={"Red","Blue","Green","White"}}},
    shield={normal={block=3},coldFireCrystals={"Red","Blue"},swiftDoubleCrystals={"Red","Blue"}},
    boost={normal={attack=3},unitBoost={}},
    linked={linkedCard={}},
    targeted={choices={{key="reduce"}},enemyEffect={}},
    neutral={untracked=true,normal={move=1}},
    partial={partial=true,normal={move=1}}
}
local env=setmetatable({
    skillResourceDefinitions=rules,gStates={turnNumber=1,masterOfChaos=0},
    turnOrder={{seatPos=1,avatarLocation="plains"}},
    skillChoicesForCurrentTurn=function(rule) return rule.choices end,
    chosenEffect=choices.chosenEffect,skillUsesDayStrength=function() return day end,
    effectHasTrackedResource=function(effects)
        for key,value in pairs(effects or {}) do
            if tracker.totalsKeys[key] and type(value)=="number" and value~=0 then return true end
        end
        return false
    end
},{__index=_G})
local calculate=assert(load(source:sub(a,b-1).."\nreturn calculateSkill","Skill calculations","t",env))()
local function skill(guid,down,target,units,crystals)
    return calculate({guid=guid,is_face_down=down},target,units,crystals or {})
end
local function eq(actual,expected,label)
    assert(actual==expected,label..": expected "..tostring(expected)..", got "..tostring(actual))
end
local result=skill("normal")
eq(result.resources.attack,2,"Normal resource")
eq(result.kind,"skill","Physical source kind")
eq(result.status,"green","Known effect")
eq(skill("normal",true).resources.block,3,"Flipped skill")
eq(skill("time").resources.attack,2,"Day strength")
day=false
eq(skill("time").resources.block,3,"Night strength")
eq(skill("options").resources.move,1,"Initial printed choice")
selected.options={effect="attack"}
eq(skill("options").resources.attack,2,"Manual selection")
eq(skill("chaos").resources.move,1,"Next Chaos segment")
env.gStates.masterOfChaos=4
eq(skill("chaos").resources.block,3,"Fifth Chaos segment default")
selected.chaos={effect="coldFire"}
eq(skill("chaos").resources.rangedColdFire,1,"Fifth Chaos segment choice")
env.gStates.masterOfChaos=5
eq(skill("chaos").resources.block,3,"Sixth Chaos segment")
eq(skill("location").resources.influence,1,"Ordinary location")
env.turnOrder[1].avatarLocation="glade"
eq(skill("location").resources.influence,3,"Glade location")
env.turnOrder[1].avatarLocation="cityBlue"
eq(skill("location").resources.influence,2,"Fortified location")
local units={units={
    {guid="u1",ready=true,unwounded=true},{guid="u2",ready=true,unwounded=true},
    {guid="u3",ready=true,unwounded=true},{guid="u4",ready=true,unwounded=true},
    {guid="wounded",ready=true,unwounded=false},{guid="spent",ready=false,unwounded=true}
}}
result=skill("march",false,nil,units)
eq(result.resources.move,3,"Ready unwounded Unit cap")
eq(#result.unitSources,3,"Only counted Units are linked")
eq(result.status,"purple","Linked Unit status")
result=skill("march",false,nil,{units={}})
eq(result.resources.move,0,"No qualifying Units")
eq(result.complete,true,"Zero resolved Unit resource is complete")
eq(skill("fortune",false,nil,nil,{Red=3,Blue=1,Gold=1}).resources.influence,2,"Distinct basic crystal colors")
eq(skill("shield",false,nil,nil,{Red=1}).resources.block,3,"Missing crystal leaves physical Block")
result=skill("shield",false,nil,nil,{Red=1,Blue=1})
eq(result.resources.blockColdFire,3,"Crystal combination changes Block")
eq(result.swiftDouble,true,"Crystal combination permits double Swiftness")
eq(skill("boost").resources,nil,"Linked bonus not counted before link resolution")
eq(skill("linked",false,"card").links[1],"card","Linked target retained")
eq(skill("targeted").complete,true,"Non-numeric enemy effect recognized")
eq(skill("neutral").status,"blue","Untracked status")
eq(skill("partial").status,"yellow","Partial status")
eq(skill("unknown").complete,false,"Unknown Skill unresolved")
env.skillResourceDefinitions={new={normal={move=4}}}
eq(skill("new").resources.move,4,"Replaced catalog is read live")
print("Skill resource records, dynamic values, inventory and Unit conditions passed")

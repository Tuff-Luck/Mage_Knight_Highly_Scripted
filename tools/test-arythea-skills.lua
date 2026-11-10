-- Shared Motivation, Arythea Ritual of Pain, and underground mana regressions.
-- Run from repository root: lua5.2 tools/test-arythea-skills.lua
local function equal(actual,expected,message)
    if actual~=expected then error((message or "Mismatch")..": expected "..tostring(expected)..", got "..tostring(actual),2) end
end
local function source(path)
    local file=assert(io.open(path,"r"))
    local data=file:read("*a")
    file:close()
    return data
end
local function sliceBetween(full,first,last)
    local a=assert(full:find(first,1,true),first.." not found")
    local b=assert(full:find(last,a+#first,true),last.." not found")
    return full:sub(a,b-1)
end

gStates={mageSkills={},motivationSkill={},doingTheRounds={},positionMageKnight={[5]="Dummy"}}
turnOrder={{seatPos=1,mage="Arythea",fame=0},
           {seatPos=2,mage="Goldyx",fame=4},
           {seatPos=5,mage="Dummy",fame=0}}
GUID={skill={masterOfChaos="1ff34f",manaSuppression="958209"}}
publishPublicUICallbacks=function() end
playerDropoutInactive=function() return false end
dofile("src/PlayingGame/PlayerBoard/Skills.lua")

-- Only real, active human players participate in the lowest-Fame comparison.
equal(motivationUniqueLowestFamePlayerIndex(),1,"Dummy must not tie Arythea at Fame zero")
turnOrder[2].fame=0
equal(motivationUniqueLowestFamePlayerIndex(),nil,"Tie between human players")
turnOrder[2].fame=1
equal(motivationUniqueLowestFamePlayerIndex(),1,"Solo/unique lowest Fame")
playerDropoutInactive=function(index) return index==1 end
equal(motivationUniqueLowestFamePlayerIndex(),2,"Dropped-out hero excluded")
playerDropoutInactive=function() return false end

-- One Motivation variant must block every other variant owned by the seat.
gStates.motivationSkill={["3d8336"]={pos=1,state="active"},
    ["171244"]={pos=1,state="active"},["14399f"]={pos=2,state="active"}}
equal(motivationSkillCanActivate("3d8336",1),true,"Available Arythea Motivation")
equal(motivationSkillCanActivate("3d8336",2),false,"Wrong seat cannot use Motivation")
gStates.motivationSkill["3d8336"].state="used"
equal(motivationSkillCanActivate("171244",1),false,"Already used Motivation in same round")
gStates.motivationSkill["3d8336"].state="deactive"
gStates.motivationLockBySeat={[1]={currentTurnPending=true}}
equal(motivationSkillCanActivate("171244",1),false,"Lock applies across variants")
motivationOwnerTurnCompleted(2)
equal(gStates.motivationLockBySeat[1]~=nil,true,"Other player's turn cannot unlock")
motivationOwnerTurnCompleted(1)
equal(gStates.motivationLockBySeat[1]~=nil,true,"Activation during owner turn survives first end")
motivationOwnerTurnCompleted(1)
equal(gStates.motivationLockBySeat[1],nil,"Lock expires after owner's next completed turn")
gStates.motivationLockBySeat={[1]={currentTurnPending=false}}
motivationOwnerTurnCompleted(1)
equal(gStates.motivationLockBySeat[1],nil,"Out-of-turn activation unlocks after next owner turn")

-- Test the actual payment helper, isolated from Tabletop Simulator userdata.
local recognition=source("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local manaHelpers=sliceBetween(recognition,
    "local function resourceCardsUsesDayMana()",
    "-- A powered link grants a target Action card")
local loadMana=assert(load(manaHelpers.."\nreturn resourceCardsUsesDayMana,matchesCardMana"))
local isDay,matches=loadMana()
gameCards={spell={cardType="Spell",color={"Red"}},action={cardType="Starting",color={"Red"}}}
gStates.turnNumber=1
gStates.dayRound=true
local spell={guid="spell"},action={guid="action"}
turnOrder[1].avatarLocation="plains"
equal(isDay(),true,"Daytime plains")
equal(matches(action,"Gold"),true,"Daytime Gold can power ordinary action")
equal(matches(spell,"Black"),false,"Daytime Black cannot power Spell")
for _,site in ipairs({"dungeon","tomb"}) do
    turnOrder[1].avatarLocation=site
    equal(isDay(),false,site.." uses Night mana rules")
    equal(matches(action,"Gold"),false,site.." rejects Gold")
    equal(matches(spell,"Black"),true,site.." accepts Black for Spell")
end
turnOrder[1].avatarLocation="plains"
gStates.dayRound=false
equal(matches(spell,"Black"),true,"Nighttime Spell accepts Black")

-- Circulation is the explicit prerequisite for Ritual of Pain's sideways Wound bonus.
local data=source("src/Data.lua")
assert(data:find('["3fba07"]={partial=true,linkedCard={targetKind="wound"',1,true),
    "Ritual of Pain must remain a Wound-only Skill link")
assert(data:find("requiresCirculation=true,sideways={value=3}",1,true),
    "Ritual of Pain must require its following-turn circulation")
assert(recognition:find("(gStates.doingTheRounds or {})[skill.guid]~=nil",1,true),
    "Linked Wound must check the live circulation state")
print("Arythea and shared Motivation regression checks passed")

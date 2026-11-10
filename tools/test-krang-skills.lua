-- Krang skill lifecycle and combat claim regression checks.
-- Run from repository root: lua5.2 tools/test-krang-skills.lua
local function eq(actual,expected,label)
    if actual~=expected then
        error((label or "Mismatch")..": expected "..tostring(expected)..", got "..tostring(actual),2)
    end
end

GUID={skill={manaSuppression="958209",masterOfChaos="1ff34f"}}
gStates={mageSkills={},doingTheRounds={},positionMageKnight={[5]="Dummy"}}
turnOrder={{mage="Krang",seatPos=1,krangArcaneDisguiseIgnoreReputation=nil}}
playerPlayAreas={[1]="play"}
local objects={}
getObjectFromGUID=function(guid) return objects[guid] end
-- Public callback registration is provided by the Global loader in TTS.
publishPublicUICallbacks=function() end
local skill={guid="91c8a0",is_face_down=false}
local playObjects={skill}
objects["91c8a0"]=skill
objects.play={getObjects=function() return playObjects end}

dofile("src/PlayingGame/PlayerBoard/Skills.lua")

eq(krangArcaneDisguiseReputationActive(1),false,"Arcane Disguise front side")
skill.is_face_down=true
eq(krangArcaneDisguiseReputationActive(1),true,"Arcane Disguise played face down")
playObjects={}
eq(krangArcaneDisguiseReputationActive(1),true,"Arcane Disguise lasts after returning home")
turnOrder[1].krangArcaneDisguiseIgnoreReputation=nil
eq(krangArcaneDisguiseReputationActive(1),false,"Face-down skill at home is not active next turn")

-- Used special Flip Back skills must NOT be turned face up at end of each
-- turn. An ordinary Turn skill still resets; End Round resets all skills.
local flipped={}
skillTokens={
    ["0fbcfe"]={skillType="Turn"},
    ["91c8a0"]={skillType="Turn"},
    ["d8824d"]={skillType="Round"},
    ordinary={skillType="Turn"}
}
for guid in pairs(skillTokens) do
    objects[guid]={guid=guid,is_face_down=true,flip=function() flipped[guid]=(flipped[guid] or 0)+1 end}
end
objects.play={getObjects=function() return {} end}
registerDetachedCoopCompSkills=function() end
refreshCoopCompSkillWarnings=function() end
turnOrder[1].krangArcaneDisguiseIgnoreReputation=true
prepareEndTurnSkillRotation(1,1)
eq(flipped.ordinary,1,"Ordinary Turn skill reset")
eq(flipped["0fbcfe"],nil,"Battle Frenzy remains spent")
eq(flipped["91c8a0"],nil,"Arcane Disguise remains spent")
eq(flipped["d8824d"],nil,"Shamanic Ritual remains spent")
eq(turnOrder[1].krangArcaneDisguiseIgnoreReputation,nil,"Arcane effect expires at end turn")

-- The manual copy/paste path uses the same Puppet claim gate as dragging.
monsterPugs={enemy={name="Orcs",pugType="green"}}
darkCrusader={token="dark"}
elementalist={token="elemental"}
dofile("src/PlayingGame/PlayerBoard/PuppetMaster.lua")
puppetMasterUseReason=function() return nil end
local enemy={guid="enemy",is_face_down=false}
local pickup={player=1,fromCombat=true,faceUp=true}
combatEnemyEligibleAsDefeatedPuppet=function() return false end
eq(type(puppetMasterClaimReason(enemy,pickup,1)),"string","Undefeated face-up enemy must be rejected")
combatEnemyEligibleAsDefeatedPuppet=function() return true end
eq(puppetMasterClaimReason(enemy,pickup,1),nil,"Defeated enemy may be kept")
-- The defeated mark may disappear when the enemy leaves the Combat Area.
pickup.calculatorActive=true
pickup.calculatorDefeated=true
combatEnemyEligibleAsDefeatedPuppet=function() return false end
eq(puppetMasterClaimReason(enemy,pickup,1),nil,"Defeat snapshot survives dragging to Inventory")
pickup.calculatorDefeated=false
eq(type(puppetMasterClaimReason(enemy,pickup,1)),"string","Undeafeated snapshot rejected")
pickup.calculatorActive=nil
pickup.calculatorDefeated=nil
pickup.faceUp=false
eq(type(puppetMasterClaimReason(enemy,pickup,1)),"string","Previously face-down enemy rejected")

-- Assert the calculator's mark-backed gate remains strict for untracked
-- enemies, and that Curse's effect-only source survives a targeting rescan.
local function source(path)
    local handle=assert(io.open(path,"r"))
    local data=handle:read("*a")
    handle:close()
    return data
end
local combat=source("src/PlayingGame/Combat.lua")
assert(combat:find("combatDefeatTracked[obj.guid]==true and combatDefeatDefeated[obj.guid]==true",1,true),
    "Puppet claim gate must require actual calculator defeat marks")
local events=source("src/PlayingGame/PlayerBoard/Events.lua")
assert(not events:find("incrementented in turn",1,true),"Master of Chaos state typo returned")
local recognition=source("src/PlayingGame/PlayerBoard/CardRecognition.lua")
assert(recognition:find("record.enemyEffectTargetKeys={skill.guid}",1,true),
    "Curse targeting source must remain registered during selection")

-- Execute the small, side-effect-free calculator helpers with mock data.
-- This tests the actual runtime implementation without loading TTS object APIs.
local function sliceBetween(full,first,last)
    local a=assert(full:find(first,1,true),first.." not found")
    local b=assert(full:find(last,a+#first, true),last.." not found")
    return full:sub(a,b-1)
end
local gate=sliceBetween(combat,
    "function combatEnemyEligibleAsDefeatedPuppet(obj)",
    "local function combatDefeatRefreshTokens")
assert(load(gate))()
local token={guid="enemy",is_face_down=false}
combatDefeatMarksActive=true
combatDefeatTracked={enemy=true}
combatDefeatDefeated={enemy=false}
eq(combatEnemyEligibleAsDefeatedPuppet(token),false,"Undeafeated marked enemy rejected")
combatDefeatDefeated.enemy=true
eq(combatEnemyEligibleAsDefeatedPuppet(token),true,"Red-X defeated enemy accepted")
combatDefeatTracked.enemy=nil
eq(combatEnemyEligibleAsDefeatedPuppet(token),false,"Untracked enemy rejected while calculator is active")
combatDefeatMarksActive=false
eq(combatEnemyEligibleAsDefeatedPuppet(token),true,"Manual face-up fallback when calculator is closed")

local damageChunk=sliceBetween(recognition,
    "local function combatDamageResolve(items,units,heroArmour,targetsOf,mitigation)",
    "local function combatWoundsText")
local damageResolve=assert(load(damageChunk.."\nreturn combatDamageResolve"))()
local noUnits=function() return {} end
local attacks={
    {owner="enemy",key="enemy:1",damage=5,type="P"},
    {owner="enemy",key="enemy:2",damage=3,type="F"}
}
local mitigate={owner="enemy",attackKey="enemy:2",physical=2,nonphysical=1}
local results=damageResolve(attacks,{},2,noUnits,mitigate)
eq(results["enemy:1"].heroWounds,3,"Battle Hardened does not protect another attack")
eq(results["enemy:2"].heroDamage,2,"Battle Hardened prevents one elemental damage")
eq(results["enemy:2"].prevented,1,"Battle Hardened nonphysical prevention")
eq(mitigate.appliedKey,"enemy:2","Battle Hardened correct attack key")
local physical=damageResolve({
    {owner="enemy",key="enemy:1",damage=5,type="P"}
},{},2,noUnits,{owner="enemy",physical=2,nonphysical=1})
eq(physical["enemy:1"].heroDamage,3,"Battle Hardened physical prevention")
combatUnitResists=function() return false end
local unit={guid="unit",wounded=false,armour=3,level=1}
local assigned=damageResolve({
    {owner="enemy",key="enemy:1",damage=5,type="P"}
},{unit=unit},2,function() return {"unit"} end,
    {owner="enemy",physical=2,nonphysical=1})
eq(assigned["enemy:1"].unitWounds,1,"Battle Hardened does not reduce Unit damage")
eq(assigned["enemy:1"].heroWounds,0,"Hero prevention follows Unit assignment")

-- Verify the Reputation tracker applies Arcane Disguise even at -7.
local ui=source("src/PlayingGame/UI.lua")
local reputationChunk=sliceBetween(ui,
    "function refreshResourceTrackerReputation()",
    "function refreshResourceTracker()")
assert(load(reputationChunk))()
resourceCardsPanelOpen=function() return true end
reputationTable={[-7]={repDisplay="No Interaction"},[-2]={repDisplay="-2"}}
gStates.turnNumber=1
gStates.resourceTracker={influence={reputation=0}}
turnOrder[1].reputation=-7
krangArcaneDisguiseReputationActive=function() return true end
refreshResourceTrackerReputation()
eq(gStates.resourceTracker.influence.reputation,0,"Arcane Disguise at -7")
krangArcaneDisguiseReputationActive=function() return false end
refreshResourceTrackerReputation()
eq(gStates.resourceTracker.influence.reputation,-99,"Normal no-interaction restored")
turnOrder[1].reputation=-2
refreshResourceTrackerReputation()
eq(gStates.resourceTracker.influence.reputation,-2,"Ordinary negative Reputation preserved")

print("Krang skill regression checks passed")

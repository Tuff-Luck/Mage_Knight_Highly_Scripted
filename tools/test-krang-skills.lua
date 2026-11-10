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

print("Krang skill regression checks passed")

-- Regression for combat Night rules from Dungeon/Tomb and marked enemy tokens.
-- Run from repo root: lua5.2 tools/test-combat-night-rules.lua
local file=assert(io.open("src/PlayingGame/PlayerBoard/CardRecognition.lua","r"))
local source=file:read("*a")
file:close()

local first=assert(source:find("-- A NightRules token represents",1,true))
local last=assert(source:find("\n-- These are separate permissions.",first,true))
local implementation=source:sub(first,last-1)
    .."\nreturn resourceCardsUsesDayMana, resourceCardsCombatNightFromEnemies"

local enemy={guid="nightMonster",is_face_down=false,
    getDecals=function() return {} end,
    isDestroyed=function() return false end}
local enemies={}
local scans=0
local env={
    gStates={dayRound=true,turnNumber=1,monsterPerks={}},
    turnOrder={{seatPos=1,avatarLocation="plains"}},
    trackerPrivate={},
    playerPlayAreas={"playZone"},
    playerUnitAreas={"unitZone"},
    getObjectFromGUID=function() return nil end,
    combatPlayMonsters=function()
        scans=scans+1
        return enemies
    end,
    combatConfig={amuletMana={gold=false,black=false}},
}
setmetatable(env,{__index=_G})
local dayMana,markedNight=assert(load(implementation,"Night combat rule check","t",env))()
env.resourceCardsUsesDayMana=dayMana

local manaStart=assert(source:find("function resourceCardsGoldAllowed()",1,true))
local manaFinish=assert(source:find("\nlocal function matchesCardMana(",manaStart,true))
local manaCode=source:sub(manaStart,manaFinish-1)
    .."\nreturn resourceCardsGoldAllowed, resourceCardsBlackAllowed"
local goldAllowed,blackAllowed=assert(load(manaCode,"Combat mana permissions","t",env))()

local skillStart=assert(source:find("local function skillUsesDayStrength()",1,true))
local skillFinish=assert(source:find("\n-- Puppet Master tokens",skillStart,true))
local skillStrength=assert(load(source:sub(skillStart,skillFinish-1)
    .."\nreturn skillUsesDayStrength","Night skill strength","t",env))()
assert(source:find("or (skillUsesDayStrength() and rule.day or rule.night)",1,true),
    "Day/Night Skill resources must use the shared combat predicate")

local function verify(expectedDay,label)
    assert(dayMana()==expectedDay,label..": day/night check")
    assert(skillStrength()==expectedDay,label..": day/night Skill strength")
    assert(goldAllowed()==expectedDay,label..": Gold legality")
    assert(blackAllowed()~=expectedDay,label..": Black legality")
end

verify(true,"Day combat with no marked enemies")
enemies.nightMonster=enemy
env.gStates.monsterPerks.nightMonster={nightRules=true}
verify(false,"Day combat against NightRules perk")
assert(markedNight(enemies)==true)
-- A saved token may have the physical decal without the metadata entry.
env.gStates.monsterPerks.nightMonster=nil
enemy.getDecals=function() return {{name="NightRules"}} end
verify(false,"Day combat against a NightRules decal")
enemy.getDecals=function() return {{name="Unrelated"}} end
verify(true,"Unrelated decal does not make combat Night")
enemy.is_face_down=true
env.gStates.monsterPerks.nightMonster={nightRules=true}
verify(true,"Face-down defeated NightRules enemy does not count")
enemy.is_face_down=false
enemies={}
verify(true,"Removing last marked enemy restores Day")
env.turnOrder[1].avatarLocation="dungeon"
verify(false,"Dungeon always uses Night")
env.turnOrder[1].avatarLocation="tomb"
verify(false,"Tomb always uses Night")
env.turnOrder[1].avatarLocation="plains"
env.gStates.dayRound=false
verify(false,"Night round regardless of markers")

-- During a render, the combat zones have already been scanned: use its
-- single snapshot instead of repeatedly querying zones for mana and Skills.
env.gStates.dayRound=true
env.trackerPrivate.renderCombatNight=true
local before=scans
verify(false,"Cached combat Night context")
assert(scans==before,"Render must not rescan enemies for every lookup")
env.trackerPrivate.renderCombatNight=false
verify(true,"Cached combat Day context")
assert(scans==before)
env.trackerPrivate.renderCombatNight=nil

-- Movement terrain rules intentionally continue to use actual round day/night.
assert(source:find("return effect.dayRound==nil or effect.dayRound==(gStates.dayRound==true)",1,true))
assert(source:find("trackerPrivate.renderCombatNight=resourceCardsCombatNightFromEnemies(combatMonsters)",1,true),
    "Active combat must build one shared Night snapshot")
assert(source:find("trackerPrivate.renderCombatNight=nil\nend\n\nlocal function scheduleSeatRender(",1,true),
    "Night context must be cleared after rendering")
print("Combat NightRules regression passed")

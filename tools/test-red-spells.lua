-- Regression checks for the five implemented red Spell pairs.
-- Run at repository root: lua5.2 tools/test-red-spells.lua
local function eq(actual,expected,label)
    if actual~=expected then
        error((label or "Mismatch")..": expected "..tostring(expected)..
            ", got "..tostring(actual),2)
    end
end
local function source(path)
    local file=assert(io.open(path,"r"))
    local text=file:read("*a")
    file:close()
    return text
end
local function contains(text,needle,label)
    assert(text:find(needle,1,true),label or ("missing: "..needle))
end

gStates={monsterPerks={
    wall={fortified=true,wallFortified=true},
    firePerk={fResist=true}
}}
monsterPugs={
    regular={name="Regular"},fire={name="Fire",fResist=true},
    arcane={name="Arcane",arcaneImmunity=true},
    wall={name="Wall"},firePerk={name="Fire by perk"}
}
dofile("src/PlayingGame/PlayerBoard/CombatEffects.lua")

-- Demolish: site bypass is independent of target Fire Resistance. Its
-- enemy-targeted Armour reduction is ineffective against Fire Resistance.
local spec={armourReduce=1,fireSpell=true,all=true}
local effects={}
combatEffectAdd(effects,"regular","2eb8d4",spec)
eq(effects.regular.armourReduce,1,"Demolish reduces ordinary enemy Armour")
combatEffectAdd(effects,"fire","2eb8d4",spec)
eq(effects.fire.armourReduce,0,"Demolish does not reduce Fire Resistant Armour")
combatEffectAdd(effects,"firePerk","2eb8d4",spec)
eq(effects.firePerk.armourReduce,0,"Perk-granted Fire Resistance applies")
combatEffectAdd(effects,"arcane","2eb8d4",spec)
eq(effects.arcane.armourReduce,0,"Arcane Immunity applies")

-- Disintegrate: destruction is Attack-phase only, not premature noAttack/destroy.
local destroy={destroyDuringAttack=true,fireSpell=true}
local targeted={}
combatEffectAdd(targeted,"regular","2eb8d4",destroy)
eq(targeted.regular.destroy,false,"Disintegrate does not destroy before Attack")
eq(targeted.regular.destroyDuringAttack,true,"Disintegrate in Attack phase")
combatEffectAdd(targeted,"fire","2eb8d4",destroy)
eq(targeted.fire.destroyDuringAttack,false,"Fire Resistant enemy survives Disintegrate")

-- Exploding Shield still applies Fire Block to a resistant enemy, but the
-- non-Block destruction effect is negated by Fire Resistance.
local explode={destroyIfBlocked=true,fireSpell=true}
local blocked={}
combatEffectAdd(blocked,"regular","2eb8d7",explode)
eq(blocked.regular.destroyIfBlocked,true,"Exploding Shield may destroy after Block")
combatEffectAdd(blocked,"fire","2eb8d7",explode)
eq(blocked.fire.destroyIfBlocked,false,"Fire Resistance prevents explosion")
eq(blocked.fire.applied[1].fireResistant,true,"UI retains fire immunity reason")

-- The remaining tests guard that the calculator, not an unconditional spell
-- definition, decides when each numeric combat effect becomes available.
local data=source("src/Data.lua")
local reader=source("src/PlayingGame/PlayerBoard/CardRecognition.lua")
contains(data,'ignoreSiteFortification=true',"Demolish site effect")
contains(data,'destroyDuringAttack=true,othersArmourReduce=1',"Disintegrate phase")
contains(data,'conditionalFireAttack=4',"Burning Shield conditional Attack")
contains(data,'splitTargets={"block","attack"}',"Burning Shield's upper effect has independent targets")
contains(data,'enemyEffect={powered={destroyIfBlocked=true,fireSpell=true}}',"Exploding Shield rule")
contains(reader,'successfulSources[item.source.guid]=true',"Source must help Block")
contains(reader,'if entry.explodePending and not entry.destroyed',"Explosion checks its own Block")
contains(reader,'source.conditionalFireAttack~=nil',"Attack granted only after Block")
contains(reader,'counter.conditionalCounterattack=amount',"Counter has a separately targetable Attack source")
contains(reader,'burningShieldTriggered[source.guid]=true',"Counter requires a successful Block")
contains(reader,'source.attack=amount',"Conditional counter contributes only its earned Attack")
assert(not reader:find('source.resources.attackFire=(source.resources.attackFire or 0)+amount',1,true),
    "Burning Shield counter must not be added to its Block target")
contains(reader,'successfulOwners[item.source.guid]=owners',"Block source is tied to attack owner")
contains(reader,'entry.summonedDestroyed[owner]=true',"Exploding Shield destroys summon, not summoner")
contains(reader,'if not immune and owner==entry.guid then',"Fire Resistance evaluated on actual blocked token")
contains(data,'woundConfirmation=true',"Firestorm confirmation rule")
contains(reader,'rule.woundConfirmation==true and not sideways',"No auto-confirmation")
contains(data,'woundPending',"Firestorm unpaid default")
contains(reader,'not combatIsSummonedToken(guid)',"Flame Wave excludes summons")
contains(reader,'local _,_,rangeDefeated=combatRangeResult',"Flame Wave phase count")
contains(reader,'sacrificeCastPairs[card.guid]=snapshot',"Crystal snapshot")
contains(reader,'snapshot.pairs or 0',"Attack survives physical crystal conversion")
contains(reader,'ignoreSiteFortifications=ignoreSiteFortifications',"Site bypass passes into calculator")
print("Red Spell regression checks passed")

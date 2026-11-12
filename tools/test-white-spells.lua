-- White Spell regression checks (base/Lost Legion; no Forgemaster).
-- Run from repository root: lua5.2 tools/test-white-spells.lua
local function read(path)
    local f=assert(io.open(path,"r"))
    local text=f:read("*a")
    f:close()
    return text
end
local function between(s,first,last)
    local a=assert(s:find(first,1,true),"Missing "..first)
    local b=assert(s:find(last,a+#first,true),"Missing "..last)
    return s:sub(a,b-1)
end
local function eq(value,expected,label)
    assert(value==expected,(label or "Mismatch")..": expected "..tostring(expected)
        ..", got "..tostring(value))
end
local data=read("src/Data.lua")
local reader=read("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local offer=read("src/PlayingGame/CallOffer.lua")
local rules=assert(load("return {\n"..between(data,
    "    -- Spell resources are independent","    -- Artifact sides are physical").."\n}"))()
gStates={monsterPerks={}}
monsterPugs={
    first={name="First"},second={name="Second"},
    immune={name="Immune",arcaneImmunity=true}
}
dofile("src/PlayingGame/PlayerBoard/CombatEffects.lua")

-- Expose's Ranged Attack is independent of its selected debuff target.
local expose=rules.spellExpose
eq(expose.normal.ranged,2,"Expose Ranged Attack 2")
eq(expose.separateEffectTarget,true,"Expose has an independent debuff arrow")
local basic=assert(combatEffectSpec(expose,false,nil),"Expose effect")
eq(basic.removeFortify,true,"Expose removes Fortified")
eq(basic.removeResist,true,"Expose removes resistances")
local mass=expose.poweredChoices
eq(mass[1].ranged,3,"Mass Expose Ranged 3 with fortification choice")
eq(mass[2].ranged,3,"Mass Expose Ranged 3 with resistance choice")
local fortify=assert(combatEffectSpec(expose,true,"fortify"))
local resist=assert(combatEffectSpec(expose,true,"resist"))
eq(fortify.all,true,"Mass Expose affects all enemies")
eq(fortify.removeFortify,true,"Mass Expose Fortify option")
eq(fortify.removeResist,nil,"Fortify choice is not Resist choice")
eq(resist.removeFortify,nil,"Resist choice is not Fortify choice")
eq(resist.removeResist,true,"Mass Expose Resist option")
eq(combatEffectSpec(expose,true,"other"),nil,"No unchosen Mass Expose branch")
local effects={}
combatEffectAdd(effects,"first","2eb8e5",basic)
eq(effects.first.removeFortify,true,"Expose affects non-immune target")
eq(effects.first.removeResist,true,"Expose removes resistance")
combatEffectAdd(effects,"immune","2eb8e5",basic)
eq(effects.immune.removeFortify,false,"Arcane Immunity negates Expose")
eq(effects.immune.removeResist,false,"Arcane Immunity negates resistance removal")

-- Retargeting must preserve explicit arrows and reject face-down or
-- attack-only reminder targets for defensive effects.
local targets=between(reader,"local function combatEffectTargetEligible(spec)",
    "local function renderSeat(seatPos)")
local targetLogic=assert(load([[
local selected={}
local function attackAssignmentsTargetGUIDs(key) return selected[key] or {} end
local function combatEnemyData(guid,enemy) return enemy~=nil and enemy.info or nil end
local function combatPlayMonsters() return {} end
local function combatEffectNearestEnemy(area,monsters,areaOf,overlap,eligible)
    for _,guid in ipairs({"first","second","reminder"}) do
        local enemy=monsters[guid]
        if enemy~=nil and enemy.is_face_down~=true
            and (eligible==nil or eligible(enemy,guid)) then return enemy end
    end
end
]]..targets..[[
return {choose=combatEffectChosenEnemy,eligible=combatEffectTargetEligible,
    set=function(key,target) selected[key]={[target]=true} end}
]]))()
local enemies={
    first={guid="first",is_face_down=false,info={name="First"}},
    second={guid="second",is_face_down=false,info={name="Second"}},
    reminder={guid="reminder",is_face_down=false,info={attackOnly=true}}
}
local eligible=targetLogic.eligible(fortify)
eq(eligible(enemies.reminder,"reminder"),false,
    "Fortification cannot be assigned to attack-only reminder")
eq(eligible(enemies.first,"first"),true,"Real enemy accepts Expose")
targetLogic.set("2eb8e5#effect","second")
eq(targetLogic.choose("2eb8e5#effect",{},enemies,eligible).guid,"second",
    "Expose keeps independently selected target")
enemies.second.is_face_down=true
eq(targetLogic.choose("2eb8e5#effect",{},enemies,eligible).guid,"first",
    "Face-down target safely falls back")
enemies.second.is_face_down=false
targetLogic.set("2eb8e5#effect","first")
eq(targetLogic.choose("2eb8e5#effect",{},enemies,eligible).guid,"first",
    "Re-targeting updates the enemy without moving the card")

-- Whirlwind prevents an enemy attack; Tornado destroys in the Attack phase
-- rather than before the Block phase. Arcane immunity is respected.
local whirlwind=rules.spellWhirlwind
local noAttack=assert(combatEffectSpec(whirlwind,false,"other"))
local tornado=assert(combatEffectSpec(whirlwind,true,"other"))
local windEffects={}
combatEffectAdd(windEffects,"first","2eb8e7",noAttack)
eq(windEffects.first.noAttack,true,"Whirlwind suppresses attack")
combatEffectAdd(windEffects,"second","2eb8e7",tornado)
eq(windEffects.second.destroyDuringAttack,true,"Tornado destroys in Attack")
eq(windEffects.second.destroy,false,"Tornado does not prematurely destroy")
combatEffectAdd(windEffects,"immune","2eb8e7",tornado)
eq(windEffects.immune.destroyDuringAttack,false,"Arcane Immune enemy ignores Tornado")

-- Possess uses the printed elemental strikes (including summons), never
-- inherits a dynamic combat bonus, and may not link Arcane Immune enemies.
local possessCode=between(reader,"local function enemyPrintedPossessAttack(enemy,guid)",
    "local function addResourceAmounts(result,totals)")
local possess=assert(load([[
local combatConfig={possessedAttackKeys={
    P="attack",F="attackFire",I="attackIce",IF="attackColdFire",M="attackPsychic"}}
local gStates={monsterPerks={}}
local function combatEnemyPrintedAttacks(enemy)
    return enemy.attacks or {}
end
local function combatSummonedFor(guid) return {} end
]]..possessCode..[[
return {calculate=enemyPrintedPossessAttack,
    block=function(guid) gStates.monsterPerks[guid]={arcaneImmunity=true} end}
]]))()
eq(rules.spellCharm.normal.influence,4,"Charm Influence 4")
eq(rules.spellCharm.enemyAttackLink,true,"Possess consumes enemy printed Attack")
local owned=possess.calculate({attacks={{key="P",value=3},
    {key="F",value=2},{key="I",value=1}}},"first")
eq(owned.attack,3,"Possess printed normal strike")
eq(owned.attackFire,2,"Possess printed Fire strike")
eq(owned.attackIce,1,"Possess printed Ice strike")
eq(possess.calculate({arcaneImmunity=true,attacks={{key="P",value=5}}},"immune"),
    nil,"Printed Arcane Immunity blocks Possess")
possess.block("second")
eq(possess.calculate({attacks={{key="P",value=5}}},"second"),nil,
    "Perk Arcane Immunity blocks Possess")
assert(reader:find("claimedPossessEnemies[guid]~=true",1,true),
    "One physical enemy cannot pay two Possess sources")
assert(reader:find("{noAttack=true,all=true}",1,true),
    "Borrowing an enemy suppresses its outgoing attack")

-- Wings of Night: sequential targets spend cumulative Move exactly once;
-- immune and unaffordable targets cannot suppress enemy attacks.
local wings=rules.spellWingsNight
local wingsStrong=assert(combatEffectSpec(wings,true,nil))
eq(wingsStrong.noAttack,true,"Wings of Night suppression")
eq(wingsStrong.multiTargetMove,true,"Wings of Night multi-target flow")
assert(reader:find("local cost=count",1,true),"Wings escalates each target cost")
assert(reader:find("if not immune and affordable then count=count+1 spent=spent+cost end",1,true),
    "Only eligible targets count towards spent Move")
assert(reader:find("adjusted.move=original-used",1,true),
    "Wings actually consumes Move from its source")
local wingsEffects={}
combatEffectAdd(wingsEffects,"first","2eb8e9",
    {noAttack=true,moveCost=1,insufficientMove=true})
eq(wingsEffects.first.noAttack,false,"Unpaid Wings target has no suppression")
combatEffectAdd(wingsEffects,"immune","2eb8e9",{noAttack=true,moveCost=0})
eq(wingsEffects.immune.noAttack,false,"Arcane Immunity prevents suppression")

-- Call to Arms is a temporary borrowed Unit; Call to Glory is a one-use
-- recruitment. The full physical browser is covered by test-call-offer.lua.
assert(reader:find('local spellRecord=records["2eb8e8"]',1,true),
    "Borrowed Unit must depend on paid Call to Arms")
assert(reader:find("spellRecord.complete==true",1,true),
    "Unpaid Call to Arms cannot activate borrowed Unit")
assert(offer:find("gStates.callOfferGloryClaimed=true",1,true),
    "Call to Glory cannot recruit multiple Units")
assert(offer:find("if spell.is_face_down==true then",1,true),
    "Face-down Spell cannot keep the borrowed Unit")

-- Mind Read/Steal is intentionally manual, not fake numeric Influence.
assert(data:find('name={"Mind Read", "Mind Steal"}',1,true))
eq(rules.spellUtility.normalChoices[1].key,"other","Manual basic Spell")
eq(rules.spellUtility.poweredChoices[1].key,"other","Manual stronger Spell")
print("White Spell regression checks passed")

-- Green Spell regression checks (base/Lost Legion; no Forgemaster).
-- Run from repository root: lua5.2 tools/test-green-spells.lua
local function read(path)
    local f=assert(io.open(path,"r"))
    local s=f:read("*a")
    f:close()
    return s
end
local function between(s,first,last)
    local i=assert(s:find(first,1,true),"Missing "..first)
    local j=assert(s:find(last,i+#first,true),"Missing "..last)
    return s:sub(i,j-1)
end
local function eq(actual,expected,label)
    assert(actual==expected,(label or "Mismatch")..": expected "..tostring(expected)
        ..", got "..tostring(actual))
end
local data=read("src/Data.lua")
local reader=read("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local spells=assert(load("return {\n"..between(data,
    "    -- Spell resources are independent","    -- Artifact sides are physical").."\n}"))()

-- Cure's basic Heal is available without waiting for a Wound draw; the
-- optional per-hand-Wound draw is a confirmed action, not automatic resources.
local cure=spells.spellCure
eq(cure.normal.healing,2,"Cure basic Heal 2")
eq(cure.poweredChoices[1].key,"other","Disease is not extra Heal")
eq(cure.enemyEffect.powered.armourSetIfBlocked,1,"Disease sets Armour to 1")
eq(cure.enemyEffect.powered.all,true,"Disease applies across the encounter")
assert(reader:find('local limit=enemy.effect~=nil and enemy.effect.armourSetIfBlocked or nil',1,true),
    "Disease must be resolved using the blocked-attack result")
assert(reader:find('combatConfig.refreshCureDrawButton(card,',1,true),
    "Cure offers its separate confirmed draw")
local cureLogic=between(reader,"function resourceCardsCureCanDraw(color)",
    "local function resourceCardsDetailsOpen()")
local testCure=assert(load([[
local enabled=true
local record={complete=true,powered=false,resources={healing=2}}
local resourceCardScanBySeat={[1]={cards={["47e71c"]=record}}}
local gStates={turnNumber=1}
local turnOrder={{seatPos=1}}
local function resourceCardsPanelOpen() return enabled end
local function resourceCardsPlayerCanEdit(color) return color=="Blue" end
]]..cureLogic..[[
return {allowed=resourceCardsCureCanDraw,record=record,scan=resourceCardScanBySeat,
    disable=function() enabled=false end,
    enable=function() enabled=true end}
]]))()
eq(testCure.allowed("Blue"),true,"Paid basic Cure offers a draw")
eq(testCure.allowed("Red"),false,"Other player cannot claim Cure draws")
testCure.record.powered=true
eq(testCure.allowed("Blue"),false,"Disease never offers Cure draws")
testCure.record.powered=false
testCure.record.complete=false
eq(testCure.allowed("Blue"),false,"Unpaid Cure cannot draw")
testCure.record.complete=true
testCure.record.resources={}
eq(testCure.allowed("Blue"),false,"Cure must actually Heal")
testCure.record.resources.healing=2
testCure.scan[1].cards["47e71c"]=nil
eq(testCure.allowed("Blue"),false,"Removed Cure cancels drawing")
testCure.scan[1].cards["47e71c"]=testCure.record
testCure.disable()
eq(testCure.allowed("Blue"),false,"Closed tracker disables draw UI")

-- Restoration/Rebirth: base 3 Heal, 5 in Forest, with no fabricated
-- Unit readying. The physical Unit history handles actual ready actions.
local restoration=spells.spellRestoration
eq(restoration.normal.healing,3,"Restoration Heal 3")
eq(restoration.powered.healing,3,"Rebirth Heal 3")
eq(restoration.forestHealing,5,"Forest Heal 5")
assert(reader:find('if currentSpellTerrain()=="forest" then',1,true),
    "Forest modifier uses current Hero terrain")
assert(reader:find('updated.healing=rule.forestHealing',1,true),
    "Forest Heal must replace, not add to, the basic value")

-- Tremor/Earthquake: resolve each option through the production effect
-- descriptor and actual enemy-effect aggregation (not copied constants).
gStates={monsterPerks={}}
monsterPugs={
    plain={name="Plain"},
    fortified={name="Fortified",fortified=true},
    immune={name="Immune",arcaneImmunity=true}
}
dofile("src/PlayingGame/PlayerBoard/CombatEffects.lua")
local tremor=spells.spellTremor
local function apply(powered,choice,target)
    local spec=assert(combatEffectSpec(tremor,powered,choice),
        "Missing Tremor choice "..choice)
    local effects={}
    combatEffectAdd(effects,target,"2eb8d1",spec)
    return effects[target],spec
end
local hit,spec=apply(false,"single","plain")
eq(hit.armourReduce,3,"Tremor reduces one enemy by 3")
eq(spec.all,nil,"Single Tremor is independently targeted")
hit,spec=apply(false,"all","plain")
eq(hit.armourReduce,2,"Tremor reduces all by 2")
eq(spec.all,true,"All Tremor is encounter-wide")
hit,spec=apply(true,"single","fortified")
eq(hit.armourReduce,3,"Earthquake base reduction")
eq(hit.armourReduceFortified,6,"Earthquake Fortified reduction")
eq(spec.armourBeforeFortificationRemoval,nil,"Default Earthquake uses current fortification")
hit=apply(true,"singleBefore","fortified")
eq(hit.armourBeforeFortificationRemoval,3,
    "Explicit first Earthquake preserves Fortified bonus")
hit,spec=apply(true,"allBefore","fortified")
eq(spec.all,true,"All-first Earthquake targets every enemy")
eq(hit.armourReduceFortified,4,"All-first Earthquake Fortified reduction")
eq(hit.armourBeforeFortificationRemoval,2,"All-first Earthquake timing")
hit=apply(false,"single","immune")
eq(hit.armourReduce,0,"Arcane Immunity negates Tremor")
eq(hit.immuneIgnored,true,"Tremor immunity reason recorded")

local disease=assert(combatEffectSpec(cure,true,"other"),
    "Disease must have an effect descriptor")
local diseaseEffects={}
combatEffectAdd(diseaseEffects,"plain","47e71c",disease)
eq(diseaseEffects.plain.armourSetIfBlocked,1,"Disease armour cap stored")
eq(diseaseEffects.plain.noAttack,false,"Disease does not erase enemy attack")
combatEffectAdd(diseaseEffects,"immune","47e71c",disease)
eq(diseaseEffects.immune.armourSetIfBlocked,nil,"Arcane Immunity negates Disease")

-- Four non-numeric Green spells are intentional manual effects. Keep them
-- deliberately neutral, with both sides selectable and no invented totals.
for _,name in ipairs({"Energy Flow","Underground Travel","Meditation"}) do
    assert(data:find('name={"'..name..'",',1,true),
        "Unregistered Green manual Spell "..name)
end
eq(spells.spellUtility.normalChoices[1].key,"other","Manual basic Spell")
eq(spells.spellUtility.poweredChoices[1].key,"other","Manual strong Spell")

print("Green Spell regression checks passed")

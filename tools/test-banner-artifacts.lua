-- Banner Artifact regressions for the official six-card roster.
-- Run: lua5.2 tools/test-banner-artifacts.lua
local function read(path)
    local f=assert(io.open(path,"r"))
    local s=f:read("*a")
    f:close()
    return s
end
local function between(s,a,b)
    local first=assert(s:find(a,1,true),"missing "..a)
    local last=assert(s:find(b,first+#a,true),"missing "..b)
    return s:sub(first+#a,last-1)
end
local recognition=read("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local effects=read("src/PlayingGame/PlayerBoard/CombatEffects.lua")
local layout=read("src/PlayingGame/PlayerBoard/UnitLayout.lua")
local replace=read("src/PlayingGame/PlayerBoard/UnitReplacement.lua")
local event=read("src/PlayingGame/Events.lua")
local data=read("src/Data.lua")

for _,name in ipairs({"Fear","Courage","Glory","Protection","Fortitude","OfCommand"}) do
    assert(data:find("artifactBanner"..name.."=",1,true),"missing official Banner "..name)
end

-- The state and temporary ability helper are the real production source.
local helpers=between(recognition,"trackerPrivate.bannerEffectUses=function()",
    "trackerPrivate.commandPickupForUnits={}")
local helpersTest=assert(load([[
local trackerPrivate={}
local gStates={currentRound=1}
local unitResourceDefinitions={unit={{row=1,key="attack",attack=4}}}
local function unitLayoutResourceState() return nil end
trackerPrivate.bannerEffectUses=function()
]]..helpers..[[
return trackerPrivate,gStates,unitResourceDefinitions
]]))()
local private,states,printed=helpersTest
local use=private.bannerEffectUses()
use.healing.fortitude=true
use.courage.courage={eligible={}}
assert(private.bannerEffectUses()==use,"Banner usage must survive rescans")
states.currentRound=2
assert(private.bannerEffectUses().healing.fortitude==nil
    and private.bannerEffectUses().courage.courage==nil,
    "New Round must reset Banner uses")

local attached={bannersByUnit={unit={["Banner of Fear"]={
    guid="fear",faceDown=false}}}}
local withFear=private.unitAbilitiesFor("unit",attached)
assert(withFear.bannerFearIndex==2 and withFear[2].enemyEffect.cancelOneAttack,
    "Attached Banner of Fear must add a distinct selectable Unit ability")
assert(#printed.unit==1,"Banner of Fear must not mutate shared printed abilities")
attached.bannersByUnit.unit["Banner of Fear"].faceDown=true
assert(private.unitAbilitiesFor("unit",attached)==printed.unit,
    "Broken Fear may not grant an attached Unit ability")

-- The real Damage-phase resolver must use one flipped Fortitude on one
-- selected attack, including prevention of Poison and Paralysis, not both.
local damageSource=between(recognition,
    "local function combatUnitResists(unit,attackKey)",
    "local function combatWoundsText(count)")
local damageTest=assert(load([[
local gStates={currentRound=1}
local fortitude={}
local trackerPrivate={bannerEffectUses=function()
    return {fortitude=fortitude}
end}
local function combatUnitResists(unit,attackKey)
]]..damageSource..[[
return combatDamageResolve
]]))()
local unit={guid="unit",level=2,armour=2,resist={},wounded=false,
    fortitudeUsed=true,fortitudeGUID="fortitude"}
local function hit(key)
    local result=damageTest({{key=key,owner="enemy",type="P",
        damage=3,poison=true,paralyse=true}},
        {unit=unit},2,function() return {"unit"} end)
    return assert(result[key].units[1])
end
local first=hit("enemy#attack1")
assert(first.fortitudePrevented and not first.wounded
    and not first.destroyed and not first.wounds,
    "First Fortitude prevention must block Wound, Poison and Paralysis")
local repeatPreview=hit("enemy#attack1")
assert(repeatPreview.fortitudePrevented,
    "Recalculating same attack must not consume another prevention")
local later=hit("enemy#attack2")
assert(later.wounded and later.destroyed and later.wounds==2,
    "Fortitude may not protect a second printed Attack in that Round")

-- The actual CombatEffects registration must produce one selectable
-- cancellation, and Arcane Immunity must reject the non-attack effect.
local addSource=between(effects,"function combatEffectAdd(",
    "\nend\n")
local register=assert(load([[
local immune=false
local monsterPugs={}
local gStates={monsterPerks={}}
local function combatEffectImmune() return immune end
function combatEffectAdd(
]]..addSource..[[
end
return combatEffectAdd,function(value) immune=value end
]]))()
local add,setImmune=register()
local applied={}
add(applied,"enemy","unit",{cancelOneAttack=true},"unit#effect2")
assert(#applied.enemy.attackReductions==1
    and applied.enemy.attackReductions[1].cancelAttack
    and applied.enemy.attackReductions[1].id=="unit#effect2",
    "Fear must register exactly one independently selectable cancellation")
setImmune(true)
local ignored={}
add(ignored,"immune","unit",{cancelOneAttack=true},"unit#effect2")
assert(#ignored.immune.attackReductions==0,
    "Arcane Immunity must ignore the Fear cancellation")

local attacksCode=between(recognition,
    "local function combatOrderedReductions(effect)",
    "-- Used by Battle Hardened's per-Attack selector.")
local attackTest=assert(load([[
local combatReductionAttackChoice={}
local combatConfig={convertPreyAttacks=function() end}
local function combatEnemyPrintedAttacks()
    return {
        {owner="enemy",slot=1,key="P",label="Physical",value=4},
        {owner="enemy",slot=2,key="F",label="Fire",value=7}
    }
end
local function combatOrderedReductions(effect)
]]..attacksCode..[[
return combatEnemyAttacks,combatReductionAttackChoice
]]))()
local enemyAttacks,choices=attackTest()
local entry={guid="enemy",data={},effect=applied.enemy}
local remaining=enemyAttacks(entry)
assert(#remaining==1 and remaining[1].value==4,
    "Fear defaults to cancel the strongest printed Attack only")
choices.enemy={["unit#effect2"]=1}
remaining=enemyAttacks(entry)
assert(#remaining==1 and remaining[1].value==7,
    "Fear must allow a chosen printed Attack to be cancelled")
assert(#enemyAttacks(entry,true)==2,
    "Attack cycle must retain choices even after one is cancelled")

-- Banner of Courage is snapshotted once, rather than readied on every scan.
assert(recognition:find("if courageUses[card.guid]==nil then",1,true),
    "Broken Courage must capture a one-time eligibility snapshot")
assert(recognition:find("for _,entry in ipairs(courageUses[card.guid].eligible)",1,true),
    "Only snapshotted Units may receive Courage Ready links")
assert(recognition:find("if entry.key==sourceKey then return true end",1,true),
    "Courage must reject unsnapshotted Ready source IDs")
assert(recognition:find("if uses[guid] then return end",1,true)
    and recognition:find("uses[guid]=true",1,true),
    "Broken Fortitude's Heal must not activate twice")
assert(recognition:find("not trackerPrivate.bannerEffectUses().healing[card.guid]",1,true),
    "Consumed Fortitude Heal button must disappear")

-- The replacement picker must never treat Banner of Command as a normal,
-- reusable Command source.
local replacementCode=between(replace,
    "local function replacementSelectable(layout,unit)",
    "local function replacementRender(state)")
local selectable=assert(load([[
local GUID={card={bannerOfCommandToken="banner"}}
local function replacementSelectable(layout,unit)
]]..replacementCode..[[
return replacementSelectable
]]))()
local board={unitSlotByGuid={unit=1},commands={{guid="banner"}}}
assert(not selectable(board,{guid="unit"}),
    "Banner-of-Command Unit may not be silently replaced")
board.commands[1].guid="native"
assert(selectable(board,{guid="unit"}),
    "Normal Command Unit remains replaceable")
assert(layout:find("function unitLayoutReconcileBannerCommand(seatPos)",1,true)
    and layout:find("resourceUnitsRetireUnit(previous)",1,true)
    and layout:find("trash.putObject(old)",1,true),
    "Removing Banner of Command must disband the dependent Unit")
assert(event:find("unitLayoutReconcileBannerCommand(seat)",1,true),
    "Settled drops must reconcile Banner of Command ownership")
print("Official Banner Artifact one-shot, Fear and Command regression checks passed")

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
local boardEvent=read("src/PlayingGame/PlayerBoard/Events.lua")
local data=read("src/Data.lua")

for _,name in ipairs({"Fear","Courage","Glory","Protection","Fortitude","OfCommand"}) do
    assert(data:find("artifactBanner"..name.."=",1,true),"missing official Banner "..name)
end

-- All seven physical card pairs, including the second copy of Glory.
-- Assert each identifier is still registered in Data.lua, then use the same
-- keys with the actual production form-detection helper.
local bannerPairs={
    {"7b9ec1","8e4b92","artifactBannerFear"},
    {"6b4654","986216","artifactBannerCourage"},
    {"085e50","0b5b32","artifactBannerGlory"},
    {"df2eae","e48e44","artifactBannerProtection"},
    {"7d608f","596cfa","artifactBannerFortitude"},
    {"98681f","8dbce4","artifactBannerOfCommand"},
    {"3d50e6","75a627","artifactBannerGlory"}
}
local gameCards={}
for _,pair in ipairs(bannerPairs) do
    local full,half,key=pair[1],pair[2],pair[3]
    assert(data:find(full,1,true) and data:find(half,1,true),
        "Missing full or half Banner GUID for "..key)
    local name=key=="artifactBannerOfCommand" and "Banner of Command"
        or "Banner of "..key:sub(15)
    gameCards[full]={cardType="Artifact",resourceKey=key,half=half,name={name}}
    gameCards[half]={cardType="Artifact",resourceKey=key,full=full,name={name}}
end

-- The state and temporary ability helper are the real production source.
local artifactState=between(recognition,"function resourceCardsArtifactBroken(guid,card)",
    "-- Persist one-shot Banner uses")
local helpers=between(recognition,"trackerPrivate.bannerEffectUses=function()",
    "trackerPrivate.commandPickupForUnits={}")
local private,states,printed,artifactBroken=assert(load([[
local trackerPrivate={}
local gStates={currentRound=1}
local unitResourceDefinitions={unit={{row=1,key="attack",attack=4}}}
local gameCards=...
local function unitLayoutResourceState() return nil end
]].."function resourceCardsArtifactBroken(guid,card)"..artifactState..[[
trackerPrivate.bannerEffectUses=function()
]]..helpers..[[
return trackerPrivate,gStates,unitResourceDefinitions,resourceCardsArtifactBroken
]]))(gameCards)
local use=private.bannerEffectUses()
use.healing.fortitude=true
use.courage.courage={eligible={}}
assert(private.bannerEffectUses()==use,"Banner usage must survive rescans")
states.currentRound=2
assert(private.bannerEffectUses().healing.fortitude==nil
    and private.bannerEffectUses().courage.courage==nil,
    "New Round must reset Banner uses")

for _,pair in ipairs(bannerPairs) do
    local full,half=pair[1],pair[2]
    assert(private.bannerCardForm(full)=="full"
        and private.bannerCardForm(half)=="half",
        "Banner full and half must have separate semantic modes")
    local fullUp={guid=full,is_face_down=false}
    local fullDown={guid=full,is_face_down=true}
    local halfUp={guid=half,is_face_down=false}
    local halfDown={guid=half,is_face_down=true}
    assert(not private.bannerStrongActive(fullUp)
        and private.bannerStrongActive(fullDown)
        and not private.bannerStrongActive(halfUp)
        and not private.bannerStrongActive(halfDown),
        "Only the full-sized Banner may use the manual face-down Throw effect")
    -- The full card also supports explicit Throw/Recover while face up;
    -- even a stale saved flag must never make an attached half throwable.
    states.artifactBreaks={[full]=true,[half]=true}
    assert(artifactBroken(full,fullUp) and private.bannerStrongActive(fullUp),
        "Explicit Throw must activate a face-up full Banner")
    assert(not artifactBroken(half,halfUp) and not artifactBroken(half,halfDown)
        and not private.bannerStrongActive(halfUp),
        "Attached half must remain ineligible for Throw even with a saved flag")
    states.artifactBreaks[full]=false
    assert(not artifactBroken(full,fullUp) and not private.bannerStrongActive(fullUp),
        "Recover must restore the full Banner basic side")
    states.artifactBreaks=nil
    for _,card in ipairs({halfUp,halfDown}) do
        local result=private.bannerAttachedCardResult(card.guid)
        assert(result~=nil and result.powered==false
            and result.fameRep==nil and result.resources==nil,
            "Attached half must never give full-card Influence, Fame or Break resources")
    end
    assert(private.bannerAttachedCardResult(full)==nil,
        "Full Banner must retain normal artifact calculation")
end

-- No printed card, including either Banner form, should render a
-- manual '?' note button. Game-effect controls (e.g. Fortitude HEAL) remain.
assert(not recognition:find('artifactManualNoteVisible',1,true),
    "Banner-specific '?' visibility helper is now obsolete")
assert(not recognition:find('startingControl("manual"',1,true),
    "Generic card '?' button must not be rendered")
assert(not recognition:find('_artifactNote',1,true),
    "Artifact '?' button must not be rendered")
assert(read("src/PlayingGame/PlayerBoard/ResourceTracker/CardControls.lua"):find('"_healAllUnits"',1,true),
    "Banner of Fortitude's actual HEAL button must remain")

-- Exercise UnitLayout's real attachment matching: only half cards
-- grant their own Unit bonuses. Full cards must be played or converted first.
local attachmentSource=between(layout,
    "local function unitLayoutBannersForUnits(layout)",
    "-- Shared by Skills that count ready/unwounded Units")
local attachedUnits=assert(load([[
local gameCards=...
local function unitLayoutBannersForUnits(layout)
]]..attachmentSource..[[
return unitLayoutBannersForUnits
]]))(gameCards)
local sampleUnit={guid="unit",
    getPosition=function() return {x=0} end,
    getBounds=function() return {size={x=2}} end}
for _,pair in ipairs(bannerPairs) do
    local full,half=pair[1],pair[2]
    local name=gameCards[half].name[1]
    if name~="Banner of Command" then
        local fullObj={guid=full,is_face_down=true,
            getPosition=function() return {x=0} end}
        local halfObj={guid=half,is_face_down=true,
            getPosition=function() return {x=0} end}
        assert(next(attachedUnits({objects={fullObj},units={sampleUnit}}))==nil,
            "Full "..name.." must never give an attached basic effect")
        local result=attachedUnits({objects={halfObj},units={sampleUnit}})
        assert(result.unit~=nil and result.unit[name]~=nil
            and result.unit[name].guid==half and result.unit[name].faceDown,
            "Flipped half "..name.." must remain correctly attached")
    end
end

local attached={bannersByUnit={unit={["Banner of Fear"]={
    guid="fear",faceDown=false}}}}
local withFear=private.unitAbilitiesFor("unit",attached)
assert(withFear.bannerFearIndex==2 and withFear[2].enemyEffect.cancelOneAttack,
    "Attached Banner of Fear must add a distinct selectable Unit ability")
assert(#printed.unit==1,"Banner of Fear must not mutate shared printed abilities")
attached.bannersByUnit.unit["Banner of Fear"].faceDown=true
local spentFear=private.unitAbilitiesFor("unit",attached)
assert(spentFear.bannerFearIndex==2,
    "Flipped half Fear must remain a basic Unit effect during its activation")
attached.bannersByUnit.unit["Banner of Fear"]=nil
assert(private.unitAbilitiesFor("unit",attached)==printed.unit,
    "Detaching Fear must remove the Unit's added ability")

-- Banner of Fear's delayed scan awards Fame only when the enemy is
-- not Arcane Immune. The effect module must export its immunity helper so
-- CardRecognition.lua can call it from the same Global script.
local immuneSource=between(effects,
    "-- Arcane Immunity ignores non-attack effects; directly changing an Attack remains legal.\n",
    "-- Unlike a Spell that destroys")
local immuneEnvironment={
    monsterPugs={plain={},printed={arcaneImmunity=true}},
    gStates={monsterPerks={perk={arcaneImmunity=true}}}
}
setmetatable(immuneEnvironment,{__index=_G})
assert(load(immuneSource,"Banner of Fear immunity","t",immuneEnvironment))()
assert(type(immuneEnvironment.combatEffectImmune)=="function",
    "Banner of Fear requires a cross-module callable immunity helper")
assert(immuneEnvironment.combatEffectImmune("printed")
    and immuneEnvironment.combatEffectImmune("perk")
    and not immuneEnvironment.combatEffectImmune("plain"),
    "Banner of Fear must distinguish printed/perk Arcane Immunity from normal enemies")
assert(recognition:find(
    "if ability.bannerFear and not combatEffectImmune(target.guid) then",1,true),
    "Banner of Fear Fame must check the exported immunity helper")

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
local add,setImmune=assert(load([[
local immune=false
local monsterPugs={}
local gStates={monsterPerks={}}
local function combatEffectImmune() return immune end
function combatEffectAdd(
]]..addSource.."\n"..[[
end
return combatEffectAdd,function(value) immune=value end
]]))()
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
local enemyAttacks,choices=assert(load([[
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

-- All scans and strong-effect callbacks must distinguish the full form.
assert(recognition:find('trackerPrivate.bannerCardForm(guid)~="half"',1,true),
    "Half Banners must not enter the play-area Artifact list")
assert(read("src/PlayingGame/PlayerBoard/ResourceTracker/CardEffects.lua"):find('local attachedResult=trackerPrivate.bannerAttachedCardResult(card.guid)',1,true),
    "The card calculator must leave attached halves inert")
assert(recognition:find("and resourceCardsArtifactBroken(card.guid,card)",1,true),
    "Artifact classification must consult the shared Throw/Recover state")
assert(recognition:find('and trackerPrivate.bannerStrongActive(card)',1,true),
    "Fortitude and other strong buttons must check the full-card form")
assert(recognition:find('if trackerPrivate.bannerCardForm(guid)=="full" then',1,true),
    "Courage full and attached Ready paths must be separate")
assert(recognition:find('trackerPrivate.bannerStrongActive(artifact)',1,true),
    "Glory army-wide bonus must only be enabled by full Break")
assert(layout:find('data.cardType=="Artifact" and data.full~=nil',1,true),
    "Only half-sized Banners may be attached as Unit bonuses")
assert(boardEvent:find("bannerPosition[3]>=-38.4 and obj.is_face_down~=true",1,true)
    and boardEvent:find("and not resourceCardsArtifactBroken(objGUID,obj) then",1,true),
    "A broken full card must not be converted into a spendable half")
assert(boardEvent:find("if fullCard.is_face_down==true then fullCard.flip() end",1,true),
    "A spent half must be restored to a face-up full card on detachment")

-- Fear has only targeting links: neither the automatic nearest arrow nor
-- subsequent calculator retargeting may make the first one blue. Enemies
-- targeted by Fear must not be mistaken for Possess/printed-resource links.
local arrowSource=between(effects,"function combatEffectArrowKind(spec)\n",
    "\nend\n")
local arrowKind=assert(load("return function(spec)\n"..arrowSource.."\nend"))()
assert(arrowKind({cancelOneAttack=true})=="other",
    "Attached Fear must use purple arrows")
assert(arrowKind({noAttack=true,maxTargets=3})=="other",
    "Full Fear must use purple arrows")
assert(recognition:find('local arrow=combatEffectArrowKind(spec)',1,true),
    "Calculator effect buttons must use shared classification")
assert(recognition:find('local borrowedEnemy=record~=nil and (record.possessEnemyGUID~=nil',1,true),
    "Fear targets must not receive resource-link outlines")

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
assert(read("src/PlayingGame/PlayerBoard/ResourceTracker/CardControls.lua"):find("not trackerPrivate.bannerEffectUses().healing[card.guid]",1,true),
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

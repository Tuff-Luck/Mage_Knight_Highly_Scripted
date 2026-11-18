-- Regression: a Wounded Unit's red Attack slot must not count toward Result.
-- Run from repository root: lua5.2 tools/test-combat-wounded-attack.lua
local function eq(actual,expected,label)
    if actual~=expected then
        error((label or "Mismatch")..": expected "..tostring(expected)
            ..", got "..tostring(actual),2)
    end
end

local file=assert(io.open("src/PlayingGame/PlayerBoard/CardRecognition.lua","r"))
local recognition=file:read("*a")
file:close()
local function isolated(startMarker,endMarker,returnName)
    local first=assert(recognition:find(startMarker,1,true),startMarker)
    local last=assert(recognition:find(endMarker,first+#startMarker, true),endMarker)
    return assert(load(recognition:sub(first,last-1).."\nreturn "..returnName))()
end
local function contains(needle,label)
    assert(recognition:find(needle,1,true),label)
end

combatConfig={attackTypes={{key="P",attack="attack",ranged="ranged",siege="siege"}},
    COMBAT_GREEN="#8CFF8C"}
combatEnemyHasTrait=function() return false end
combatRich=function(value,color)
    return "<color="..color..">"..value.."</color>"
end
local attackTotal=isolated("local function combatEnemyResists(",
    "-- Blocks of the wrong element", "combatAttackTotal")
local paralysisCards=isolated("combatConfig.paralysisAttackCards=function(sources,results,lock,knockout)",
    "combatConfig.attackPhaseSources=function", "combatConfig.paralysisAttackCards")
local eligibleSources=isolated("combatConfig.attackPhaseSources=function(sources,wounded,paralysisCards)",
    "-- Timing of self-wounding Unit abilities", "combatConfig.attackPhaseSources")
local resultLine=isolated("local function combatGroupAttackLine(meleeTotal,attackArmour)",
    "local combatDefenderMarks=", "combatGroupAttackLine")
local function total(sources)
    return attackTotal({
        {sources=sources,category="attack"},
        {sources=sources,category="ranged"},
        {sources=sources,category="siege"}},{},{})
end

local sources={
    {guid="card1",key="card1",kind="card",resources={attack=1}},
    {guid="card2",key="card2",kind="card",resources={attack=3}},
    {guid="unit",key="unit#use2",kind="unit",resources={attack=2}}
}
eq(total(sources),6,"original total is six")
local afterWound=eligibleSources(sources,{unit=true})
eq(#afterWound,2,"wounded Unit excluded without removing the assignment")
eq(total(afterWound),4,"post-Damage Attack total is four")
eq(resultLine(total(afterWound),6),"Attack 4/6",
    "wounded Unit cannot cause a displayed defeat")
eq(resultLine(total(sources),6),
    "Attack 6/6 <color=#8CFF8C>Defeated</color>",
    "healed Unit restores the original attack")
eq(#eligibleSources(sources,{}),3,"undoing the wound restores eligibility")
eq(resultLine(0,6),nil,"fully ineligible Attack has no result line")
eq(sources[3].resources.attack,2,"excluded source remains available for undo")

-- The physical calculateCard record must carry a kind. This was previously
-- absent, so the filter saw nil for *every* played Attack card and treated
-- Knockout/Paralysis as warnings only.
contains('return {guid=card.guid,kind="card",known=known',
    "real played-card records must be classified as cards")
contains('ambushFirstBlockBonus=record.ambushFirstBlockBonus,kind=record.kind,',
    "the resource calculator must propagate the record kind to combat sources")

-- A pending Hero Paralysis discards staged Attack cards before melee, but
-- never retroactively cancels Unit attacks or earlier Ranged/Siege/Block.
local heroHit={attack1={paralyse=true,heroWounds=1}}
local invalid=paralysisCards(sources,heroHit,nil)
eq(invalid.card1,true,"Paralysis invalidates first staged card")
eq(invalid.card2,true,"Paralysis invalidates second staged card")
eq(invalid.unit,nil,"Paralysis leaves a surviving Unit's Attack available")
local valid=eligibleSources(sources,{},invalid)
eq(#valid,1,"only the Unit can Attack after Hero paralysis")
eq(total(valid),2,"paralyzed hand cards cannot count toward defeat")
eq(resultLine(total(valid),6),"Attack 2/6",
    "Paralysis must prevent false defeated result")
eq(#eligibleSources(sources,{unit=true},invalid),0,
    "Paralysis and Unit wounds independently remove late Attack")
eq(#eligibleSources(sources,{},paralysisCards(sources,{},nil)),3,
    "removing Paralyze restores staged card resources")
local knockedOut=paralysisCards(sources,{},nil,true)
local realCardSource={guid="physicalAttackCard",kind="card",
    resources={attack=2}}
eq(paralysisCards({realCardSource},{},nil,true).physicalAttackCard,true,
    "newly classified physical Attack cards are blocked during Knockout")
eq(knockedOut.card1,true,"Knockout removes a staged Attack card")
eq(knockedOut.card2,true,"Knockout removes both planned card Attacks")
eq(knockedOut.unit,nil,"Knockout cannot remove an active Unit's Attack")
eq(total(eligibleSources(sources,{},knockedOut)),2,
    "Knockout cannot create a false melee defeat")
eq(#eligibleSources(sources,{},paralysisCards(sources,{},nil,false)),3,
    "below Knockout threshold leaves card Attacks intact")
eq(#eligibleSources(sources,{},paralysisCards(sources,{
    attack1={paralyse=false,heroWounds=0}},nil)),3,
    "fully blocked Paralyze does not invalidate cards")
eq(#eligibleSources(sources,{},paralysisCards(sources,{
    attack1={paralyse=false,heroWounds=0,units={{destroyed=true}}}},nil)),3,
    "Paralyzed Unit alone does not discard Hero cards")
local postDamage={
    {guid="card1",key="card1",kind="card",phaseAfterDamage=true,
        resources={attack=1}},
    {guid="newCard",key="newCard",kind="card",phaseAfterDamage=true,
        resources={attack=5}},
    {guid="wound",key="wound",kind="wound",resources={attack=2}}
}
local postInvalid=paralysisCards(postDamage,heroHit,
    {sources={{guid="card1",kind="card"}}})
eq(postInvalid.card1,true,"card staged before Damage stays unavailable")
eq(postInvalid.newCard,nil,"genuinely new card played after Damage is legal")
eq(postInvalid.wound,nil,"Wounds are not non-Wound hand cards")
eq(total(eligibleSources(postDamage,{},postInvalid)),7,
    "later legal card and Wound attack remain usable")
-- The rendered Result must use the exact total from the defeat calculation,
-- never a fresh calculation over group.sources.
contains("group.attackTotal=meleeTotal","save authoritative post-Damage Attack")
contains("combatGroupAttackLine(group.attackTotal,group.attackArmour)",
    "Result uses authoritative Attack total")
contains("wounded=wounded,paralysisCard=paralysisCard,ineffective=paralysisCard",
    "Paralyzed card Attack icon is rendered dark/red")
contains("local knockout=totalHeroWounds+otherCombatWounds>=handLimit",
    "Knockout includes only this combat's Wounds")
contains("local paralysisAttackCards=combatConfig.paralysisAttackCards(sources,damageResults,earlyLock,knockout)",
    "Paralysis and Knockout invalidate Attack using resolved Hero damage")
contains("combatConfig.attackPhaseSources(group.sources,woundedBeforeAttack,paralysisAttackCards)",
    "Defeat calculation excludes paralyzed card Attack")
print("Combat wounded Attack result regressions passed")

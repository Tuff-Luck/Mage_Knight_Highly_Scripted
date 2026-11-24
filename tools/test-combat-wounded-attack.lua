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
local attackTotal=dofile("src/PlayingGame/PlayerBoard/ResourceTracker/EnemyDefences.lua")(combatConfig).attackTotal
local eligibility=dofile("src/PlayingGame/PlayerBoard/ResourceTracker/AttackEligibility.lua")(combatConfig,
    function(seat) return seat~=nil and resourceCardScanBySeat~=nil and resourceCardScanBySeat[seat] or nil end,
    function(guid) return gameCards~=nil and gameCards[guid] or nil end,
    function(key) return cardResourceDefinitions~=nil and cardResourceDefinitions[key] or nil end,
    function(guid) return getObjectFromGUID(guid) end)
local paralysisCards=eligibility.paralysisAttackCards
local eligibleSources=eligibility.attackPhaseSources
local resultLine=dofile("src/PlayingGame/PlayerBoard/ResourceTracker/CombatDisplay.lua")(combatConfig,combatRich,nil).groupAttackLine
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
local cardFile=assert(io.open("src/PlayingGame/PlayerBoard/ResourceTracker/CardEffects.lua","r"))
local cardSource=cardFile:read("*a")
cardFile:close()
assert(cardSource:find('return {guid=card.guid,kind="card",known=known',1,true),
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
-- Burning Shield was PLAYED in Block, and its triggered Fire Attack
-- persists through Knockout. Exploding Shield's nonnumeric pre-Damage effect
-- likewise protects it from Attack-only auto-discard.
local early={objectKeys={burning=true,ranged=true},
    enemyEffects={enemyA={applied={{source="exploding"}}}}}
combatConfig.phasePreview=early
local staged={
    {guid="rage",key="rage",kind="card",attack=2},
    {guid="swiftness",key="swiftness",kind="card",attack=1},
    {guid="burning",key="burning#block",kind="card",block=4},
    {guid="burning",key="burning#attack",kind="card",attack=4,
        conditionalCounterattack=4},
    {guid="exploding",key="exploding",kind="card",block=4},
    {guid="ranged",key="ranged",kind="card",ranged=5},
    {guid="linked",key="linked",kind="card",attack=3},
    {guid="mixed",key="mixed",kind="card",attack=2},
    {guid="uncertain",key="uncertain",kind="card",attack=2},
    {guid="unit",key="unit",kind="unit",attack=6}
}
local invalidKO=paralysisCards(staged,{},nil,true)
eq(invalidKO.rage,true,"staged Rage must lose its planned Attack")
eq(invalidKO.swiftness,true,"staged Swiftness must lose Attack")
eq(invalidKO.burning,nil,"Burning Shield's Block earned the Fire Attack")
eq(invalidKO.exploding,nil,"pre-Damage Exploding Shield effect remains played")
eq(invalidKO.ranged,nil,"already used Ranged/Siege effect remains valid")
eq(invalidKO.unit,nil,"Unit Attack survives Knockout")
local stageOnly=eligibility.knockoutStagedAttackCards
gameCards={rage={cardType="Starting"},swiftness={cardType="Starting"},
    burning={cardType="Spell"},exploding={cardType="Spell"},
    ranged={cardType="Starting"},linked={cardType="Advanced Action"},
    mixed={cardType="Advanced Action"},uncertain={cardType="Starting"}}
resourceCardScanBySeat={[1]={cards={
    rage={kind="card",complete=true,resources={attack=2}},
    swiftness={kind="card",complete=true,resources={attack=1}},
    linked={kind="card",complete=true,links={"mana"},resources={attack=3}},
    mixed={kind="card",complete=true,resources={attack=2,healing=1}},
    uncertain={kind="card",complete=false,resources={attack=2}}}}}
getObjectFromGUID=function(guid)
    return {guid=guid,type="Card",is_face_down=false,
        getGMNotes=function() return "Starting" end}
end
local candidates=stageOnly(staged,invalidKO,1,early)
eq(#candidates,2,"only pure Attack cards are auto-discarded")
eq(candidates[1],"rage","Rage is an Attack-only discard")
eq(candidates[2],"swiftness","Swiftness is an Attack-only discard")
eq(invalidKO.linked,true,"linked Attack is still invalidated")
combatConfig.phasePreview=nil

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
local lateFile=assert(io.open("src/PlayingGame/PlayerBoard/ResourceTracker/LateCombatPhase.lua","r"))
local latePhase=lateFile:read("*a")
lateFile:close()
assert(latePhase:find("group.attackTotal=meleeTotal",1,true),"save authoritative post-Damage Attack")
contains("combatGroupAttackLine(group.attackTotal,group.attackArmour)",
    "Result uses authoritative Attack total")
contains("wounded=wounded,paralysisCard=paralysisCard,ineffective=paralysisCard",
    "Paralyzed card Attack icon is rendered dark/red")
contains("local knockout=totalHeroWounds+otherCombatWounds>=handLimit",
    "Knockout includes only this combat's Wounds")
contains("local paralysisAttackCards=combatConfig.paralysisAttackCards(sources,damageResults,earlyLock,knockout)",
    "Paralysis and Knockout invalidate Attack using resolved Hero damage")
assert(latePhase:find("attackPhaseSources(group.sources,woundedBeforeAttack,paralysisAttackCards)",1,true),
    "Defeat calculation excludes paralyzed card Attack")
-- All historical uses of a wounded physical Unit are excluded, even if a
-- different use was assigned to a second target. Prior phase results stand.
local damaged=eligibility.unitsWoundedByDamage({
    a={units={{unit={guid="unit"},wounded=true},{unit={guid="resisted"},wounded=false}}},
    b={units={{unit={guid="retired"},wounded=true,destroyed=true,alreadyApplied=true}}},
    c={}})
eq(damaged.unit,true,"Wounded Unit identified from resolved damage")
eq(damaged.resisted,nil,"Resisted Unit remains eligible")
eq(damaged.retired,true,"Destroyed historical Unit excluded")
eq(next(eligibility.unitsWoundedByDamage(nil)),nil,"Missing damage yields no wounded Units")
local phaseSources={{guid="unit",key="unit#use1"},{guid="unit",key="unit#use2"},
    {guid="other",key="other",noAttackPhase=true},{guid="resisted",key="resisted"}}
local remaining=eligibleSources(phaseSources,damaged,{})
eq(#remaining,1,"Exclude every wounded Unit use and early-only sources")
eq(remaining[1].guid,"resisted","Resisting Unit can still Attack")
eq(#phaseSources,4,"Eligibility never mutates assigned sources")
-- A prior phase's effect-only card protects its physical source, but an
-- effect explicitly played after Damage is not evidence of earlier play.
local phases={enemyEffects={a={applied={{source="earlyEffect"},
    {source="lateEffect",phaseAfterDamage=true}}}}}
local cards={{guid="earlyEffect",kind="card"},{guid="lateEffect",kind="card"}}
local rejected=paralysisCards(cards,heroHit,phases)
eq(rejected.earlyEffect,nil,"Effect-only earlier source remains played")
eq(rejected.lateEffect,true,"Late effect is not earlier-play evidence")
-- Physical staged discard safeguards must reject Artifacts, Wounds, held
-- face-down cards, unknown physical objects and rules with side effects.
local discardSources={}
local unavailable={}
local scans={}
for _,guid in ipairs({"pure","artifact","wound","faceDown","missing","ruleEffect","split"}) do
    discardSources[#discardSources+1]={guid=guid,kind="card",attack=2}
    unavailable[guid]=true
    scans[guid]={kind="card",complete=true,resources={attack=2}}
    gameCards[guid]={cardType="Starting"}
end
gameCards.artifact.cardType="Artifact"
gameCards.ruleEffect.resourceKey="effect"
cardResourceDefinitions={effect={enemyEffect={}}}
discardSources[#discardSources+1]={guid="split",kind="card",block=1}
resourceCardScanBySeat[1]={cards=scans}
getObjectFromGUID=function(guid)
    if guid=="missing" then return nil end
    return {type="Card",is_face_down=guid=="faceDown",
        getGMNotes=function() return guid=="wound" and "Wound" or "Starting" end}
end
local selected=stageOnly(discardSources,unavailable,1,{})
eq(#selected,1,"Only unambiguously pure Attack is physically discardable")
eq(selected[1],"pure","Every protected physical card remains untouched")
eq(#stageOnly(discardSources,unavailable,nil,{}),0,"Missing scan cannot authorize physical discard")
print("Combat wounded Attack result regressions passed")

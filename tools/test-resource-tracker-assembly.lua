-- Full Resource Tracker assembly audit. Run with Lua 5.2 from the repository root.
-- Historical public and private names are recorded from the pre-refactor
-- baseline (896735a4). This detects accidental global reads/writes after extraction.
local root="src/PlayingGame/PlayerBoard/"
local prefix="PlayingGame.PlayerBoard.ResourceTracker."
local modules=[[
Cards.ActionLinks Cards.CardEffects Cards.CardInteraction Cards.CardInteractions Cards.MovementEffects
Cards.PlayedCardScan Cards.ResourceChoices Cards.SkillEffects Cards.SkillInteractions Cards.SkillLinks
Combat.AttackEligibility Combat.BlockResults Combat.BlockSolver Combat.BossAllocation
Combat.CombatInteraction Combat.CombatTargetPolicy Combat.ConditionalBlockEffects
Combat.DamagePreparation Combat.DamageResolution Combat.DefendAllocation Combat.DivisibleResources
Combat.EarlyCombatPhase Combat.EnemyAttacks Combat.EnemyDefences Combat.EnemyGroups Combat.ExplosiveBolt
Combat.FlameWave Combat.LateCombatPhase Combat.SourceTargetAllocation Core.Diagnostics Core.ObjectEvents
Core.ScanScheduler Core.State Core.TrackerLifecycle Interface.CardControlOptions Interface.CardControls
Interface.CombatDisplay Interface.CombatEffectDisplay Interface.CombatPanelLayout
Interface.CombatPanelRenderer Interface.CombatResourceDisplay Interface.CombatRowRenderer
Interface.UnitControls Scanning.FactionRewardScan Scanning.ManaPayments Scanning.PhysicalObjects
Scanning.ScanFinalization Scanning.ScanObservation Scanning.ScanPayments Scanning.ScanPublication
Units.ReadyPolicy Units.UnitChoices Units.UnitEffects Units.UnitManagement Units.UnitScan
Units.UnitSelfWounds
]]
local publicNames=[[
attackAssignmentReadySourceClicked combatBossAutomationActive combatBossLevelCount combatBossSetManual
combatWoundsEndTurnReminder magicTalentManaPayments magicTalentSpellCastingPaid
magicTalentSpellCastingPaymentCount resourceCardsAfterTurnHandoff resourceCardsAmbushLinkTargets
resourceCardsAmbushSourceActive resourceCardsAmuletSunRevealActive resourceCardsApplyCombatWounds
resourceCardsArtifactBreakClear resourceCardsArtifactBreakClicked resourceCardsArtifactBroken
resourceCardsArtifactGrailFameClicked resourceCardsArtifactHealUnitsClicked
resourceCardsBattleHardenedAttackClicked resourceCardsBeforeTurnHandoff resourceCardsBlackAllowed
resourceCardsBlockLinkSkillActive resourceCardsBlockLinkTargets resourceCardsChoiceClicked
resourceCardsChoicesRestore resourceCardsChoicesSave resourceCardsCombatAdditionalTargetLimit
resourceCardsCombatAssignSource resourceCardsCombatAssignmentClick resourceCardsCombatCalculatorOn
resourceCardsCombatClearOneUnit resourceCardsCombatCycleAttack resourceCardsCombatEffectArrowKind
resourceCardsCombatForgetSource resourceCardsCombatPage resourceCardsCombatPrimaryTarget
resourceCardsCombatSelectOneUnit resourceCardsCombatTargetAcceptsMove
resourceCardsCombatTargetAcceptsSource resourceCardsCombatTargetObjects
resourceCardsCombatTargetRejectMessage resourceCardsCombatToggleGroup resourceCardsCombatToggleResult
resourceCardsCombatWoundsSkipChanged resourceCardsConfirmCombatWounds resourceCardsConversionClicked
resourceCardsCureCanDraw resourceCardsCurrentMovementEffects resourceCardsCurrentTotals
resourceCardsEffectiveCombatMove resourceCardsEffectiveExploreCost resourceCardsEffectiveMove
resourceCardsEffectiveTerrainCost resourceCardsEffectiveValue resourceCardsEnemyEffectivelyUnfortified
resourceCardsEnemyPresent resourceCardsForkedLightningPhaseClicked resourceCardsGeneratedMove
resourceCardsGoldAllowed resourceCardsMaximalEffectBeforeEndTurn resourceCardsMaximalEffectLink
resourceCardsMaximalEffectMark resourceCardsMaximalEffectMarked resourceCardsMaximalEffectMarkerNoop
resourceCardsMaximalEffectOffDrop resourceCardsMaximalEffectSourceManaGUIDs
resourceCardsMaximalEffectSyncMarks resourceCardsMountainLoreEndTurnBonus resourceCardsObjectMoved
resourceCardsObjectPickedUp resourceCardsOnLoad resourceCardsPanelChanged resourceCardsPanelOpen
resourceCardsPanelReady resourceCardsPlayerCanEdit resourceCardsReadySourceLevelLimit
resourceCardsReadySourceValid resourceCardsReadyTargetEligible resourceCardsRefreshCombatEnemies
resourceCardsRegenerationReadyClicked resourceCardsRequestCombatWounds resourceCardsSeatEnabled
resourceCardsSetSeatEnabled resourceCardsSourceChanged resourceCardsStartingCardControlClicked
resourceCardsSteadyTempoPowered resourceCardsThrowAwayReason resourceCardsTimeBendingPaid
resourceCardsTraceCommand resourceCardsTrainingMode resourceCardsTransformedKey resourceCardsUnderAction
resourceCardsUnitTargetRequiresUnfortified resourceCardsZoneEntered resourceCardsZoneLeft
resourceUnitsAdoptCommand resourceUnitsBorrowedUnitEnded resourceUnitsChoiceClicked
resourceUnitsCommandDropped resourceUnitsCommandOwner resourceUnitsCommandPickedUp
resourceUnitsCommandSpent resourceUnitsPruneHistoricalTargets resourceUnitsReconcileChoiceTargets
resourceUnitsReconcileNewUnit resourceUnitsRecordSpentCommands resourceUnitsRefreshButtons
resourceUnitsResetTurn resourceUnitsRetireUnit resourceUnitsSetCommandSpent resourceUnitsSpentCommands
]]
local privateNames=[[
addResourceAmounts applyLinkedResourceBonus calculateCard calculateSideways calculateSkill canPayDiscard
cardCanPlaySideways cardInSeatPlayArea cardPosture cardRotationOffset cardTerrainEffects choiceAvailable
choiceButtonShown choiceCategory choiceExpandedByGUID choiceHasTargetableCombatResource choiceLetters
chosenEffect clearAll clearChoiceButtons clearHighlight combatApplyAttackReductions combatApplyDefend
combatAssignmentActiveSeat combatAssignmentIconButton combatAssignmentJoined combatAssignmentRefreshRows
combatAssignmentRowIndices combatAssignmentRowTargets combatAssignmentSlotSources combatAssignmentSources
combatAssignmentState combatAttackChoiceByRow combatAttackTotal combatBlockEfficient combatBlockLegal
combatBlockResult combatBlockSpent combatBossIdentity combatBossPhasePlan combatCalcOn combatCalcShutdown
combatCalcUpdate combatCompactResultLines combatConfig combatConversionReserved combatCumbersomeActive
combatDamageNotes combatDamageResolve combatDamageUnits combatDefeatFameRep combatDetailPhase
combatEffectChosenEnemy combatEffectOf combatEffectTargetEligible combatEnemyAttacks combatEnemyData
combatEnemyFortificationCount combatEnemyHasTrait combatEnemyInPlay combatEnemyOffenceTraits
combatEnemyPage combatEnemyPrintedAttacks combatEnemyResists combatEnemyTraitsText
combatEntryHasCumbersome combatExpandedResults combatForgetPhysicalSourceTargets combatFrozenCopy
combatGUIDHasCumbersome combatGroupAttackLine combatGroupEntry combatGroupResourceRows
combatGroupTraitsText combatHardenedAttackOptions combatHeroArmour combatIsSummonedToken
combatKeepHeldEnemies combatNatureVengeanceBlockBonus combatNearestEnemyGUID combatOneUnitChosen
combatOneUnitSelect combatOrderedReductions combatPanelSetAttribute combatPhaseLock
combatPhaseLockSources combatPlayMonsters combatPsychicActive combatRangeGroupEntry combatRangeResult
combatReductionActiveSource combatReductionAttackChoice combatReductionChoiceIcon combatRich
combatSetDefenderDecal combatSolveBlocks combatSourceArrowKind combatSourceKeepsLock
combatSummonedAttackPrevented combatSummonedFor combatSyncDefenderMark combatTrackedEnemies
combatTrackedSeat combatTypeRich combatUnitResists combatUnitSitePermits combatUnitSiteRestriction
combatWoundsText convertedManaMatchesCard currentChoice currentLandBlockValue currentSpellTerrain
effectHasTrackedResource effectManaPossibilities effectManaPowerColors enemyPrintedIconBonus
enemyPrintedPossessAttack factionRewardForObject footprint guessInitialCardChoice inventorySetChoice
linkedColorChoices manaColor manaInsideFootprint matchesCardMana matchingSidewaysMana
matchingSidewaysPaymentMana overlapArea overlaps ownedSkillAtSeat puppetResourceOptions queueSeat
refreshCombatEnemyPanel removeChoiceButtons renderSeat resolveActionLinks resolveManaSkillLinks
resolveSkillCardLinks resourceCardsApplyFameRep resourceCardsCombatNightFromEnemies
resourceCardsDetailsOpen resourceCardsHideAutomaticEnemyTarget resourceCardsIgnoreSiteFortification
resourceCardsMoveByRole resourceCardsMoveRole resourceCardsRawValue resourceCardsRecruitInfluenceBonus
resourceCardsRelevantZone resourceCardsSyncInteractionPower resourceCardsUsesDayMana
resourceCardsWeatherTerrainEffects resourceChoiceColumn resourceChoiceFamilies resourceChoiceRank
resourceObjectKind resourceUnitsCancelMovedCommand resourceUnitsRebuildFromTable
scheduleChoiceResetAfterPlay scheduleSeatRender selectedResourceByGUID setHighlight showChoiceButtons
showUnitAbilityButtons shown sideChoices sidewaysManaAvailable sidewaysModifierValue skillChoiceFamily
skillChoicePositions skillChoicesForCurrentTurn skillUsesDayStrength terrainEffectActive
terrainEffectApplies terrainModifierPrecedes trackerChoiceScores trackerPrivate unitAbilityPaid
unitAbilityTargetCategory unitAbilityTargetKey unitManaCounts unitManaDecision unitManaSignature
weatherTerrain
]]
local private={}
for name in privateNames:gmatch("%S+") do private[name]=true end
local expected={}
for name in publicNames:gmatch("%S+") do expected[name]=true end

-- Compile each real module and inspect the _ENV accesses. A formerly private
-- coordinator helper must be passed explicitly, never fall through to _ENV.
-- unitResourceDefinitions is deliberately also an authoritative global.
local compiler
for _,name in ipairs({"luac5.2","luac52","luac"}) do
    local probe=io.popen(name.." -v 2>&1")
    local version=probe:read("*a")
    probe:close()
    if version:find("Lua 5.2",1,true) then compiler=name break end
end
assert(compiler,"Lua 5.2 compiler required for module assembly audit")
local violations={}
local environmentReads=0
local function checkGlobals(path)
    local pipe=assert(io.popen(compiler..' -l -p "'..path..'"'))
    local listing=pipe:read("*a")
    assert(pipe:close(),"Compiler failed: "..path)
    for line in listing:gmatch("[^\n]+") do
        local name=line:match('[_]ENV%s+"([%w_]+)"')
        if name then environmentReads=environmentReads+1 end
        if name and private[name] then
            violations[#violations+1]=path..": "..name.." ("..line..")"
        end
    end
end
for name in modules:gmatch("%S+") do checkGlobals(root.."ResourceTracker/"..name:gsub("%.","/")..".lua") end
checkGlobals(root.."CardRecognition.lua")
assert(environmentReads>100,"Compiler listing did not expose global references")
assert(#violations==0,"Private helper escaped into globals:\n"..table.concat(violations,"\n"))

-- Load the entire coordinator, not extracted snippets. No TTS calls should
-- occur during module initialization. Data and UnitResources are already loaded
-- in TTS; supply their catalogs and callback publisher, not permissive fake globals.
local env=setmetatable({unitResourceDefinitions={},skillResourceDefinitions={},publishPublicUICallbacks=function(callbacks)
    for name,callback in pairs(callbacks) do assert(type(callback)=="function",name) end
end},{__index=_G})
local loaded,loading={},{}
env.require=function(name)
    assert(not loading[name],"Circular require: "..name)
    if loaded[name]~=nil then return loaded[name] end
    assert(name:sub(1,#prefix)==prefix,"Unexpected tracker dependency: "..name)
    loading[name]=true
    local result=assert(loadfile("src/"..name:gsub("%.","/")..".lua","t",env))()
    loading[name]=nil
    assert(result~=nil,"Module returned nil: "..name)
    if type(result)=="function" then
        local factory=result
        result=function(...)
            for index=1,select("#",...) do
                assert(select(index,...)~=nil,name..": nil factory dependency "..index)
            end
            return factory(...)
        end
    end
    loaded[name]=result
    return result
end
assert(loadfile(root.."CardRecognition.lua","t",env))()
for name in modules:gmatch("%S+") do
    assert(loaded[prefix..name]~=nil,"Unreachable tracker module: "..name)
end
for name in pairs(expected) do assert(type(rawget(env,name))=="function","Lost public function: "..name) end
for name,value in pairs(env) do
    if type(value)=="function" and name~="require" and name~="publishPublicUICallbacks" then
        assert(expected[name],"Unexpected public function: "..name)
    end
    assert(not private[name],"Private state leaked into Global: "..name)
end

-- Exercise Mountain Lore through the actual public function. The isolated
-- older regression supplied overlapArea directly and hid a forward-local bug.
local function card(guid,x)
    return {guid=guid,type="Card",is_face_down=false,
        getRotation=function() return {0,180,0} end,
        getPosition=function() return {x,1,0} end,
        getBounds=function() return {size={2,1,3}} end}
end
local lore=card("d3995b",0)
local concentration=card("450552",1.4)
local maximal=card("8fac50",1.4)
local function token(color,x)
    return {type="Figurine",color=color,getPosition=function() return {x,1,0} end}
end
local objects={}
env.gStates={turnNumber=1,firstStarted=false}
env.turnOrder={{seatPos=1}}
env.playerPlayAreas={"zone"}
env.getObjectFromGUID=function(guid)
    if guid=="zone" then return {getObjects=function() return objects end} end
end
local terrain="mountain"
env.fracturedLandsTeleportSourcePosition=function(turn) return {0,1,0} end
env.runtimeMapHexAtPosition=function(position) return nil,nil,nil,nil,nil,nil,terrain end
env.isManaTokenFigurine=function(obj) return obj.type=="Figurine" end
env.manaTokenColor=function(obj) return obj.color end
env.gameCards={
    [lore.guid]={cardType="Advanced Action",color="Green",resourceKey="mountainLore"},
    [concentration.guid]={cardType="Starting",color="Green",resourceKey="concentration"},
    [maximal.guid]={cardType="Advanced Action",color="Red",resourceKey="maximalEffect"}
}
env.cardResourceDefinitions={
    concentration={poweredLink={mode="stronger"}},
    maximalEffect={requiredLink={mode="repeat",normalCount=3,poweredCount=2}}
}
objects={lore,concentration,token("Green",2.1)}
assert(env.resourceCardsMountainLoreEndTurnBonus(1)==2,"Closed tracker Concentration link")
objects={lore,maximal,token("Red",2.1)}
assert(env.resourceCardsMountainLoreEndTurnBonus(1)==4,"Closed tracker powered Maximal Effect")
terrain="hills"
objects={lore,maximal}
assert(env.resourceCardsMountainLoreEndTurnBonus(1)==3,"Closed tracker normal Maximal Effect")
assert(rawget(env,"overlapArea")==nil,"Geometry helper must not leak into Global")

print("Resource Tracker module assembly, lexical boundaries, public API and Mountain Lore audit passed")

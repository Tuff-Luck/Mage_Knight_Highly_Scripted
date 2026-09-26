-- Quest-private helpers share one namespace to avoid Lua's top-level local-variable limit.
local QuestPrivate={}

-- Quest-private helpers. This batch deliberately leaves local-variable headroom for future Quest work.
local apocalypseQuestStageIntoContainer, apocalypseQuestReturnRevealBag, apocalypseQuestRevealSetup, apocalypseQuestUndoSiteToken, apocalypseQuestTokenFaceUp
local apocalypseQuestGainReputation, apocalypseQuestBasicCrystalColor, apocalypseQuestManaTokenColor, apocalypseQuestManaBag, apocalypseQuestBeginMoveAttachmentCapture
local apocalypseQuestEndMoveAttachmentCapture, apocalypseQuestPlannedCardPosition, apocalypseQuestPlannedWorldPosition, apocalypseQuestMoveAttachmentTarget, apocalypseQuestMoveAttachmentOwnerGUID
local apocalypseQuestRegisterMoveAttachment, apocalypseQuestPlaceManaTokenOnCard, apocalypseQuestGiveCrystal, apocalypseQuestPlaceCrystalOnCard, apocalypseQuestFinalizeEnemyFacing
local apocalypseQuestPlaceNamedEnemy, apocalypseQuestPlaceEnemy, apocalypseQuestPlaceFistfulEnemies, apocalypseQuestCardHasEnemyType, apocalypseQuestGiveTuckedCard
local apocalypseQuestGiveProveYourselfReward, apocalypseQuestGiveQuestTokenToInventory, apocalypseQuestSetupDie, apocalypseQuestPhysicalDiceRoll, apocalypseQuestRollVisibleManaDie
local apocalypseQuestRollCrystalRewardDice, apocalypseQuestGoblinAttempt, apocalypseQuestGoblinAttemptReady, apocalypseQuestRegisterGoblin, apocalypseQuestStartGoblinWarrens
local apocalypseQuestResolveRichMerchantRoll, apocalypseQuestResolveHerbalistReward, apocalypseQuestGiveHerbalistReward, apocalypseQuestGiveBardReward, apocalypseQuestFlipSiteToken
local apocalypseQuestPlaceRandomCrystalOnShield, apocalypseQuestBeginCrystalChoice, apocalypseQuestRollManaDie, apocalypseQuestPlaceCrystalAt, apocalypseQuestCardCrystalColor
local apocalypseQuestCardManaColor, apocalypseQuestPlayerCombatEnemies, apocalypseQuestCursedMarkHolder, apocalypseQuestCursedTargetEligible, apocalypseQuestCursedTargetIndex
local apocalypseQuestCursedEligibleTargets, apocalypseQuestCursedAutoShield, apocalypseQuestStepSpecialLegal, apocalypseQuestFailureReady, apocalypseQuestCombatOption
local apocalypseQuestCombatRelevant, apocalypseQuestUsesEnemyAttackButton, apocalypseQuestRemoveEnemyAttackButton, apocalypseQuestClearEnemyAttackButtons, apocalypseQuestEnemyAttackButtonPosition

-- Apocalypse Quest system: quest cards, progression, markers, combat, rewards, offer and scoring.

--Apocalypse Dragon Quest Setup
function apocalypseQuestsUsed()
	return gStates.apocalypseQuestCards==true or gStates.gameScenario=="For the Council" or gStates.gameScenario=="The Fractured Lands Blitz"
end
function apocalypseQuestScoresRequired()
	return gStates.gameScenario=="For the Council" or gStates.gameScenario=="The Fractured Lands Blitz"
end
function apocalypseQuestScoringActive()
	return apocalypseQuestsUsed()==true and (apocalypseQuestScoresRequired()==true or gStates.apocalypseQuestScoringDisabled~=true)
end
local apocalypseQuestData={
	["8939c0"]={number=1, name="The Execution", questType="Simple", starting=true, stepCount=1, usesMarker=false, keepToken=false, steps={{key="1a", point=true, canFail=false, completes=true, repeatCount=0, pointLimit=1}, {key="1b", point=true, canFail=true, completes=true, repeatCount=0, pointLimit=1}, {key="1c", point=true, canFail=false, completes=true, repeatCount=0, pointLimit=1}}},
	["08ffcf"]={number=2, name="Guard Duty", questType="Personal", starting=true, stepCount=2, usesMarker=true, keepToken=false, questTokens={"518afd"}, snapOrder={"1"}, steps={{key="1", point=true, canFail=false, completes=false, repeatCount=0, pointLimit=1}, {key="2", point=true, canFail=true, completes=true, repeatCount=0, pointLimit=1}}},
	["81e795"]={number=3, name="Fragments of Power", questType="Personal", starting=true, stepCount=4, usesMarker=false, keepToken=false, snapOrder={"1", "2", "3"}, steps={{key="1", point=true, canFail=false, completes=false, repeatCount=0, pointLimit=1}, {key="2", point=true, canFail=false, completes=false, repeatCount=0, pointLimit=1}, {key="3", point=true, canFail=false, completes=false, repeatCount=0, pointLimit=1}, {key="4", point=true, canFail=false, completes=true, repeatCount=0, pointLimit=1}}},
	["58a826"]={number=4, name="The Eager Herbalist", questType="Independent", starting=true, stepCount=3, usesMarker=true, keepToken=true, questTokens={"fb29ad"}, snapOrder={"1", "2"}, steps={{key="1", point=true, canFail=false, completes=false, repeatCount=0, pointLimit=1}, {key="2", point=true, canFail=false, completes=false, repeatCount=0, pointLimit=1}, {key="3", point=true, canFail=false, completes=true, repeatCount=0, pointLimit=1}}},
	["734740"]={number=5, name="Prove Yourself", questType="Independent", starting=true, stepCount=3, usesMarker=true, keepToken=true, questTokens={"c48454"}, revealSetup="regularUnitII", snapOrder={"1", "2"}, minimumReputationModifier=0, steps={{key="1", point=true, canFail=false, completes=false, repeatCount=0, pointLimit=1}, {key="2", point=true, canFail=false, completes=false, repeatCount=0, pointLimit=1}, {key="3", point=true, canFail=false, completes=true, repeatCount=0, pointLimit=1}}},
	["72099f"]={number=6, name="The Goblin Warrens", questType="Independent", starting=true, stepCount=2, usesMarker=true, keepToken=true, questTokens={"02f996"}, revealBag="f021d8", siteTypes={["02f996"]="mine"}, snapOrder={"1"}, allPlayersMustCompleteStep=1, steps={{key="1", point=true, canFail=false, completes=false, repeatCount=0, pointLimit=1}, {key="2", point=true, canFail=false, completes=true, repeatCount=0, pointLimit=1}}},
	["11d244"]={number=7, name="Random Objects", questType="Personal", starting=true, stepCount=4, usesMarker=true, keepToken=false, questTokens={"cef3a2", "746a47", "97ba49"}, snapOrder={"1", "2", "3"}, steps={{key="1", point=true, canFail=false, completes=false, repeatCount=0, pointLimit=1}, {key="2", point=true, canFail=false, completes=false, repeatCount=0, pointLimit=1}, {key="3", point=true, canFail=false, completes=false, repeatCount=0, pointLimit=1}, {key="4", point=true, canFail=false, completes=true, repeatCount=0, pointLimit=1}}},
	["8cdac4"]={number=8, name="The Spell Thief", questType="Collective", starting=true, stepCount=3, usesMarker=true, keepToken=false, questTokens={"1dc726"}, revealSetup="spell", snapOrder={"1", "2"}, steps={{key="1", point=true, canFail=false, completes=false, repeatCount=0, pointLimit=1}, {key="2", point=true, canFail=false, completes=false, repeatCount=0, pointLimit=1}, {key="3", point=true, canFail=false, completes=true, repeatCount=0, pointLimit=1}}},
	["66ea80"]={number=9, name="A Fistful of Crystals", questType="Collective", starting=true, stepCount=3, usesMarker=true, keepToken=false, questTokens={"14e54b"}, snapOrder={"1", "2"}, steps={{key="1", point=true, canFail=false, completes=false, repeatCount=0, pointLimit=1}, {key="2", point=true, canFail=false, completes=false, repeatCount=0, pointLimit=1}, {key="3", point=true, canFail=false, completes=true, repeatCount=0, pointLimit=1}}},
	["37e2ce"]={number=10, name="Free Wine!", questType="Simple", starting=false, stepCount=2, usesMarker=false, keepToken=false, steps={{key="1a", point=false, canFail=false, completes=false, repeatCount=0, pointLimit=0}, {key="1b", point=true, canFail=false, completes=true, repeatCount=0, pointLimit=1}, {key="2", point=true, canFail=true, completes=true, repeatCount=0, pointLimit=1}}},
	["485cc5"]={number=11, name="Mine of Doom", questType="Simple", starting=false, stepCount=2, usesMarker=true, keepToken=false, questTokens={"2f238c"}, steps={{key="1", point=false, canFail=false, completes=false, repeatCount=0, pointLimit=0}, {key="2", point=true, canFail=false, completes=true, repeatCount=0, pointLimit=1}}},
	["b401dc"]={number=12, name="A Very Personal Quest", questType="Personal", starting=false, stepCount=2, usesMarker=true, keepToken=false, questTokens={"7e4e4c"}, snapOrder={"1"}, minimumReputationModifier=0, steps={{key="1", point=true, canFail=true, completes=false, repeatCount=0, pointLimit=1}, {key="2", point=true, canFail=true, completes=true, repeatCount=0, pointLimit=1}}},
	["82a935"]={number=13, name="The Burned Monastery", questType="Personal", starting=false, stepCount=2, usesMarker=true, keepToken=false, questTokens={"81b6f2"}, snapOrder={"1"}, steps={{key="1", point=true, canFail=false, completes=false, repeatCount=0, pointLimit=1}, {key="2a", point=false, canFail=false, completes=true, repeatCount=0, pointLimit=1}, {key="2b", point=true, canFail=false, completes=true, repeatCount=0, pointLimit=1}, {key="2c", point=true, canFail=true, completes=true, repeatCount=0, pointLimit=1}}},
	["8455b5"]={number=14, name="The Admiring Bard", questType="Personal", starting=false, stepCount=3, usesMarker=false, keepToken=false, snapOrder={"1", "2a", "2b", "2c"}, steps={{key="1", point=true, canFail=false, completes=false, repeatCount=0, pointLimit=1}, {key="2a", point=true, canFail=false, completes=false, repeatCount=0, pointLimit=1}, {key="2b", point=true, canFail=false, completes=false, repeatCount=0, pointLimit=1}, {key="2c", point=true, canFail=false, completes=false, repeatCount=0, pointLimit=1}, {key="3", point=true, canFail=false, completes=true, repeatCount=0, pointLimit=1}}},
	["a6d5cc"]={number=15, name="Under Siege", questType="Personal", starting=false, stepCount=2, usesMarker=true, keepToken=false, questTokens={"4c5f97"}, snapOrder={"1"}, failOnlySteps={["2b"]=true}, steps={{key="1", point=true, canFail=false, completes=false, repeatCount=0, pointLimit=1}, {key="2a", point=true, canFail=false, completes=true, repeatCount=0, pointLimit=1}, {key="2b", point=false, canFail=true, completes=true, repeatCount=0, pointLimit=1}}},
	["bbd087"]={number=16, name="Noble Warrior", questType="Personal", starting=false, stepCount=3, usesMarker=true, keepToken=false, questTokens={"6e826b"}, snapOrder={"1", "2"}, steps={{key="1", point=false, canFail=false, completes=false, repeatCount=0, pointLimit=1, minimumReputationModifier=1}, {key="2", point=true, canFail=false, completes=false, repeatCount=0, pointLimit=1}, {key="3a", point=true, canFail=false, completes=true, repeatCount=0, pointLimit=1}, {key="3b", point=false, canFail=false, completes=true, repeatCount=0, pointLimit=1}}},
	["8cff07"]={number=17, name="A Rich Merchant", questType="Personal", starting=false, stepCount=2, usesMarker=true, keepToken=false, questTokens={"d32cff"}, snapOrder={"1"}, progressCompletingSteps={["1"]=true}, steps={{key="1", point=true, canFail=false, completes=true, repeatCount=0, pointLimit=1}, {key="2", point=true, canFail=true, completes=true, repeatCount=0, pointLimit=1}}},
	["abd4fb"]={number=18, name="Cursed", questType="Independent", starting=false, stepCount=2, usesMarker=false, keepToken=false, snapOrder={"1"}, globalPointLimits={["1"]=1}, steps={{key="1", point=true, canFail=false, completes=false, repeatCount=0, pointLimit=1}, {key="2a", point=true, canFail=false, completes=false, repeatCount=99, pointLimit=1}, {key="2b", point=true, canFail=false, completes=true, repeatCount=0, pointLimit=1}}},
	["d70436"]={number=19, name="A Mysterious Island", questType="Independent", starting=false, stepCount=3, usesMarker=true, keepToken=false, questTokens={"01c7cc"}, snapOrder={"1"}, steps={{key="1", point=true, canFail=false, completes=false, repeatCount=0, pointLimit=1}, {key="2", point=false, canFail=false, completes=false, repeatCount=0, pointLimit=0}, {key="3", point=true, canFail=true, completes=true, repeatCount=0, pointLimit=1}}},
	["c73a1f"]={number=20, name="Tomb of the Lost King", questType="Independent", starting=false, stepCount=3, usesMarker=true, keepToken=false, questTokens={"994812"}, snapOrder={"1", "2"}, steps={{key="1", point=true, canFail=false, completes=false, repeatCount=0, pointLimit=1}, {key="2", point=true, canFail=false, completes=false, repeatCount=0, pointLimit=1}, {key="3", point=true, canFail=false, completes=true, repeatCount=0, pointLimit=1}}},
	["77bbac"]={number=21, name="The Child Seer", questType="Independent", starting=false, stepCount=2, usesMarker=true, keepToken=false, questTokens={"7e6639"}, snapOrder={"1"}, allPlayersComplete=true, steps={{key="1", point=true, canFail=false, completes=false, repeatCount=0, pointLimit=1}, {key="2", point=true, canFail=false, completes=true, repeatCount=0, pointLimit=1}}},
	["082f39"]={number=22, name="Travelling Merchant", questType="Independent", starting=false, stepCount=1, usesMarker=true, keepToken=false, questTokens={"afcfc1"}, revealSetup="randomCrystal", steps={{key="1", point=true, canFail=false, completes=false, repeatCount=99, pointLimit=1}}},
	["ce70fb"]={number=23, name="Traitor", questType="Collective", starting=false, stepCount=2, usesMarker=true, keepToken=false, questTokens={"c70b5e"}, snapOrder={"1"}, steps={{key="1", point=false, canFail=false, completes=false, repeatCount=0, pointLimit=1}, {key="2a", point=true, canFail=true, completes=true, repeatCount=0, pointLimit=1}, {key="2b", point=true, canFail=false, completes=true, repeatCount=0, pointLimit=1}}},
	["c5dec8"]={number=24, name="Stray", questType="Collective", starting=false, stepCount=3, usesMarker=true, keepToken=true, questTokens={"186613"}, snapOrder={"1", "2"}, steps={{key="1", point=true, canFail=false, completes=false, repeatCount=0, pointLimit=1}, {key="2", point=true, canFail=false, completes=false, repeatCount=0, pointLimit=1}, {key="3", point=true, canFail=false, completes=true, repeatCount=0, pointLimit=1}}},
	["3009b4"]={number=25, name="Ill Omens", questType="Collective", starting=false, stepCount=4, usesMarker=true, keepToken=true, questTokens={"adc752", "c92844", "0143e0", "7a56a0"}, snapOrder={"1", "2", "3"}, steps={{key="1", point=true, canFail=false, completes=false, repeatCount=0, pointLimit=1}, {key="2", point=true, canFail=false, completes=false, repeatCount=0, pointLimit=1}, {key="3", point=true, canFail=false, completes=false, repeatCount=0, pointLimit=1}, {key="4", point=true, canFail=false, completes=true, repeatCount=0, pointLimit=1}}},
	["6175e8"]={number=26, name="Magic Overload", questType="Collective", starting=false, stepCount=3, usesMarker=true, keepToken=true, questTokens={"a4777c", "963031"}, siteTypes={["a4777c"]="monster den", ["963031"]="spawning grounds"}, snapOrder={"1", "2"}, steps={{key="1", point=true, canFail=false, completes=false, repeatCount=0, pointLimit=1}, {key="2", point=true, canFail=false, completes=false, repeatCount=0, pointLimit=1}, {key="3", point=true, canFail=false, completes=true, repeatCount=0, pointLimit=1}}},
	["00a4fe"]={number=27, name="Misadventure", questType="Collective", starting=false, stepCount=2, usesMarker=true, keepToken=true, questTokens={"3c89b8"}, snapOrder={"1"}, minimumReputationModifier=1, steps={{key="1", point=true, canFail=false, completes=false, repeatCount=0, pointLimit=1}, {key="2", point=true, canFail=false, completes=true, repeatCount=0, pointLimit=1}}},
	["dd35bb"]={number=28, name="The Fog", questType="Collective", starting=false, stepCount=3, usesMarker=true, keepToken=false, questTokens={"84ca8f"}, snapOrder={"1", "2"}, steps={{key="1", point=true, canFail=false, completes=false, repeatCount=0, pointLimit=1}, {key="2", point=true, canFail=false, completes=false, repeatCount=0, pointLimit=1}, {key="3", point=true, canFail=false, completes=true, repeatCount=0, pointLimit=1}}},
	["bb2828"]={number=29, name="The Artificer", questType="Collective", starting=false, stepCount=3, usesMarker=true, keepToken=true, questTokens={"cd8313"}, snapOrder={"1", "2"}, steps={{key="1", point=true, canFail=false, completes=false, repeatCount=0, pointLimit=1}, {key="2", point=true, canFail=false, completes=false, repeatCount=3, pointLimit=3}, {key="3", point=true, canFail=false, completes=true, repeatCount=0, pointLimit=1}}},
	["783076"]={number=30, name="Hunter's Moon", questType="Collective", starting=false, stepCount=2, usesMarker=true, keepToken=false, questTokens={"e55059"}, revealSetup="werewolf", snapOrder={"1a", "1b"}, steps={{key="1a", point=true, canFail=false, completes=false, repeatCount=0, pointLimit=1}, {key="1b", point=true, canFail=false, completes=false, repeatCount=0, pointLimit=1}, {key="2", point=true, canFail=true, completes=true, repeatCount=0, pointLimit=1}}},
}

--Quest-specific behavior registers here instead of being spread across unrelated engine dispatchers.
--This first pass centralizes combat-step identity; additional hooks migrate here incrementally.
local apocalypseQuestHandlers={
	["8939c0"]={combatSteps={[1]={key="1b"}}},
	["8cdac4"]={combatSteps={[3]={key="3"}}},
	["66ea80"]={combatSteps={[2]={key="2"},[3]={key="3"}}},
	["37e2ce"]={},
	["485cc5"]={combatSteps={[2]={key="2"}}},
	["82a935"]={combatSteps={[2]={key="2c"}}},
	["8455b5"]={},
	["a6d5cc"]={combatSteps={[2]={key="2a"}}},
	["8cff07"]={combatSteps={[2]={key="2"}}},
	["abd4fb"]={},
	["d70436"]={combatSteps={[3]={key="3"}}},
	["c73a1f"]={combatSteps={[3]={key="3"}}},
	["ce70fb"]={combatSteps={[2]={keys={["2a"]=true,["2b"]=true},defaultKey="2a",branchState="combat"}}},
	["dd35bb"]={combatSteps={[3]={key="3"}}},
	["bb2828"]={},
	["783076"]={combatSteps={[2]={key="2"}}},
}

local function apocalypseQuestHandler(cardOrGUID)
	if cardOrGUID==nil then return nil end
	local valueType=type(cardOrGUID)
	local guid=(valueType=="table" or valueType=="userdata") and cardOrGUID.guid or cardOrGUID
	return guid~=nil and apocalypseQuestHandlers[guid] or nil
end

local function apocalypseQuestRegisterHandler(guid)
	if apocalypseQuestHandlers[guid]==nil then apocalypseQuestHandlers[guid]={} end
	return apocalypseQuestHandlers[guid]
end

local function apocalypseQuestCombatRuleForStep(card,step)
	local handler=apocalypseQuestHandler(card)
	return handler~=nil and handler.combatSteps~=nil and handler.combatSteps[tonumber(step)] or nil
end

local function apocalypseQuestCombatRuleForOption(card,key)
	local handler=apocalypseQuestHandler(card)
	if handler==nil or handler.combatSteps==nil then return nil,nil end
	key=tostring(key)
	for step,rule in pairs(handler.combatSteps) do
		if rule.key==key or (rule.keys~=nil and rule.keys[key]==true) then return rule,step end
	end
	return nil,nil
end

local function apocalypseQuestCombatRuleSelectedKey(card,state)
	if state==nil then return nil,nil end
	local rule=apocalypseQuestCombatRuleForStep(card,state.step)
	if rule==nil then return nil,nil end
	local key=rule.key
	if rule.branchState=="combat" then
		key=(gStates.apocalypseQuestCombatBranch~=nil and gStates.apocalypseQuestCombatBranch[card.guid]) or rule.defaultKey
	end
	return key,rule
end

--Map-placement rules for Quest markers. These mirror the placement notes in the Quest catalogue.
--A marker is only auto-positioned while the matching numbered step is current. If several legal
--spaces exist, the first is used as a default and the marker is highlighted so the player can move it.
apocalypseQuestMarkerPlacementRules={
	--Starter-card markers that say "on your site" go directly under the acting Mage Knight.
	--The step-location test decides whether that Mage Knight is standing somewhere legal.
	["08ffcf"]={["1"]={tokens={"518afd"}, atPlayer=true}},
	["58a826"]={["1"]={tokens={"fb29ad"}, atPlayer=true}},
	["734740"]={["1"]={tokens={"c48454"}, atPlayer=true}},
	["72099f"]={["1"]={tokens={"02f996"}, atPlayer=true}},
	["11d244"]={
		["1"]={tokens={"cef3a2"}, atPlayer=true},
		["2"]={tokens={"746a47"}, atPlayer=true},
		["3"]={tokens={"97ba49"}, atPlayer=true},
	},
	--Spell Thief is the starter-card exception: its marker is deliberately placed away from the Mage Knight.
	["8cdac4"]={
		["1"]={tokens={"1dc726"}, safe=true, noSite=true, distanceFromPlayerMin=3, distanceFromPlayerMax=3,
			nearFeatures={"monster den","spawning grounds","ruin","dungeon","tomb","maze","labyrinth","graveyard","ziggurat","pyramid"}, nearDistanceMin=1, nearDistanceMax=2},
		["2"]={tokens={"1dc726"}, adventureSite=true, distanceFromMarkerMax=2, relocate=true},
	},
	["66ea80"]={["1"]={tokens={"14e54b"}, atPlayer=true}},
	["485cc5"]={["1"]={tokens={"2f238c"}, atPlayer=true}},
	["82a935"]={["1"]={tokens={"81b6f2"}, atPlayer=true}},
	["a6d5cc"]={["1"]={tokens={"4c5f97"}, atPlayer=true}},
	["bbd087"]={["1"]={tokens={"6e826b"}, atPlayer=true}},
	["8cff07"]={["1"]={tokens={"d32cff"}, atPlayer=true}},
	["d70436"]={["1"]={tokens={"01c7cc"}, atPlayer=true}},
	["c73a1f"]={["3"]={tokens={"994812"}, atPlayer=true}},
	["77bbac"]={["1"]={tokens={"7e6639"}, atPlayer=true}},
	["082f39"]={["1"]={tokens={"afcfc1"}, atPlayer=true}},
	["ce70fb"]={["1"]={tokens={"c70b5e"}, safe=true, distanceFromPlayerMin=3, closestToPlayer=true}},
	["c5dec8"]={["1"]={tokens={"186613"}, atPlayer=true}},
	["6175e8"]={["3"]={tokens={"a4777c","963031"}, atPlayer=true}},
	["00a4fe"]={["1"]={tokens={"3c89b8"}, atPlayer=true}},
	["dd35bb"]={["1"]={tokens={"84ca8f"}, atPlayer=true}},
	["bb2828"]={["1"]={tokens={"cd8313"}, atPlayer=true}},
	["783076"]={["1"]={tokens={"e55059"}, atPlayer=true}},
}

--Quest step location rules used by the current scripted Quest implementation.
--Rules use the full printed branch key where branches have different legal locations; missing steps mean Anywhere.
apocalypseQuestStepLocationRules={
	["8939c0"]={["1"]={features={"village","keep","mage tower","oasis"}, requireInteractable=true}},
	["08ffcf"]={
		["1"]={inhabited=true, requireInteractable=true},
		["2"]={inhabited=true, requireInteractable=true, excludeToken="518afd"},
	},
	["81e795"]={
		["1"]={inhabited=true, requireInteractable=true},
		["4"]={features={"glade"}},
	},
	["58a826"]={
		["1"]={features={"village","monastery","oasis","camp"}, requireInteractable=true},
		["2"]={terrains={"plains","forest","wasteland","swamp"}, noSite=true},
		["3"]={sameToken="fb29ad"},
	},
	["734740"]={["1"]={inhabited=true, requireInteractable=true}},
	["72099f"]={
		["1"]={warrens=true},
		["2"]={sameToken="02f996"},
	},
	["11d244"]={
		["1"]={terrains={"hills"}},
		["2"]={terrains={"plains"}},
		["3"]={terrains={"forest"}},
		["4"]={randomObjectsTreasure=true},
	},
	["8cdac4"]={
		["1"]={inhabited=true, requireInteractable=true},
		["2"]={sameToken="1dc726"},
		["3"]={sameToken="1dc726"},
	},
	["66ea80"]={
		["1"]={features={"village"}},
		["2"]={sameToken="14e54b"},
		["3"]={sameToken="14e54b"},
	},
	["37e2ce"]={["1"]={freeWine=true}, ["2"]={features={"keep"}, conqueredThisTurn=true}},
	["485cc5"]={["1"]={features={"mine"}}, ["2"]={sameToken="2f238c"}},
	["b401dc"]={
		["1"]={inhabited=true, requireInteractable=true},
		["2"]={features={"mage tower"}, unconquered=true},
	},
	["82a935"]={
		["1"]={destroyedMonastery=true},
		["2a"]={features={"village","monastery","glade","oasis","camp"}, requireInteractable=true},
		["2b"]={features={"village","monastery","glade","oasis"}, requireInteractable=true},
		["2c"]={features={"village","monastery","glade","oasis"}, requireInteractable=true},
	},
	["8455b5"]={
		["1"]={features={"village","monastery","city","camp","oasis"}, requireInteractable=true},
		["3"]={features={"village","monastery","city","oasis"}, requireInteractable=true},
	},
	["a6d5cc"]={
		["1"]={conqueredThisTurn=true, features={"keep","mage tower"}},
		["2a"]={sameToken="4c5f97"},
	},
	["bbd087"]={
		["1"]={features={"village","keep","city","camp","oasis"}, requireInteractable=true},
		["3a"]={sameToken="6e826b"},
		["3b"]={sameToken="6e826b"},
	},
	["8cff07"]={
		["1"]={features={"village"}},
		["2"]={sameToken="d32cff"},
	},
	["d70436"]={
		["1"]={safe=true, adjacentTerrain="lake"},
		["2"]={sameToken="01c7cc"},
		["3"]={sameToken="01c7cc"},
	},
	["c73a1f"]={
		["1"]={features={"monastery"}, requireInteractable=true},
		["2"]={features={"village"}, requireInteractable=true},
		["3"]={terrains={"wasteland"}},
	},
	["77bbac"]={
		["1"]={features={"mage tower","monastery","city"}, requireInteractable=true},
	},
	["082f39"]={
		["1"]={safe=true},
	},
	["ce70fb"]={
		["1"]={interactionSite=true},
		["2a"]={sameToken="c70b5e"},
		["2b"]={sameToken="c70b5e"},
	},
	["c5dec8"]={
		["1"]={unconqueredAdventure=true},
		["2"]={sameToken="186613", conqueredAdventure=true},
		["3"]={sameToken="186613"},
	},
	["3009b4"]={
		["1"]={features={"village","city","camp"}, requireInteractable=true},
		["2"]={features={"keep","mage tower"}, requireInteractable=true},
		["3"]={features={"village","monastery","city"}, requireInteractable=true},
		["4"]={unconqueredAdventure=true},
	},
	["6175e8"]={
		["3"]={terrains={"plains","hills","forest","wasteland","desert","swamp"}, noSite=true},
	},
	["00a4fe"]={
		["1"]={features={"village"}, nearFeatures={"dungeon","tomb"}, nearDistanceMax=2},
		["2"]={features={"dungeon","tomb"}, nearToken="3c89b8", nearDistanceMax=2},
	},
	["dd35bb"]={
		["1"]={features={"village"}, coastalTile=true},
		["2"]={sameToken="84ca8f"},
		["3"]={sameToken="84ca8f"},
	},
	["bb2828"]={
		["1"]={features={"mage tower","monastery","city"}, requireInteractable=true},
		["2"]={features={"mine"}},
		["3"]={sameToken="cd8313"},
	},
	["783076"]={
		["1"]={features={"village"}, requireInteractable=true},
		["2"]={sameToken="e55059"},
	},
}
local function apocalypseQuestName(card)
	if card==nil then return "Unknown Quest" end
	local details=apocalypseQuestData[card.guid]
	if details~=nil then return details.name end
	local name=card.getName()
	if name~=nil and name~="" then return name end
	return "Quest "..tostring(card.guid)
end
--During a Quest-offer button refresh, several legality checks ask for the same card attachments.
--Cache that snapshot for the duration of the refresh so each card does not repeatedly rescan the entire table.
local apocalypseQuestRefreshObjectsByCard=nil
local apocalypseQuestRefreshOfferCardsCache=nil
local function apocalypseQuestObjectsOnCard(card)
	local objects={}
	if card==nil then return objects end
	if apocalypseQuestRefreshObjectsByCard~=nil and apocalypseQuestRefreshObjectsByCard[card.guid]~=nil then
		return apocalypseQuestRefreshObjectsByCard[card.guid]
	end
	local seen={}
	local source=card.getPosition()
	local known=gStates.apocalypseQuestCardGUIDs or {}
	local areaObjects=QuestPrivate.apocalypseQuestAreaObjects()
	local offerCards=QuestPrivate.apocalypseQuestOfferCards(areaObjects)
	for _, obj in pairs(areaObjects) do
		if obj.guid~=card.guid and known[obj.guid]~=true then
			local explicitOwner=apocalypseQuestMoveAttachmentOwnerGUID~=nil and apocalypseQuestMoveAttachmentOwnerGUID(obj.guid) or nil
			if explicitOwner==card.guid then
				objects[#objects+1]=obj
				seen[obj.guid]=true
			elseif explicitOwner==nil then
				local pos=obj.getPosition()
				local normalFootprint=math.abs(pos[1]-source[1])<1.7 and math.abs(pos[3]-source[3])<2.5 and pos[2]>source[2]-1.5 and pos[2]<source[2]+3.0
				--Independent rows can reach into a neighbouring Quest's normal footprint. Give row Shields/mana
				--tokens to the Quest whose row slot they are actually nearest, rather than letting both cards claim them.
				local rowOwner=QuestPrivate.apocalypseQuestIndependentShieldRowOwnerGUID~=nil and QuestPrivate.apocalypseQuestIndependentShieldRowOwnerGUID(obj,offerCards) or nil
				if rowOwner==card.guid or (rowOwner==nil and normalFootprint) then
					objects[#objects+1]=obj
					seen[obj.guid]=true
				end
			end
		end
	end
	--Future-position pieces can already be outside the card's old footprint during this same action. Keep the
	--actual object handles returned by takeObject() visible to same-frame Quest helpers until the card catches up.
	local capture=apocalypseQuestMoveAttachmentCapture~=nil and apocalypseQuestMoveAttachmentCapture[card.guid] or nil
	if type(capture)=="table" and capture.objects~=nil then
		for guid,obj in pairs(capture.objects) do
			if seen[guid]~=true and obj~=nil then
				objects[#objects+1]=obj
				seen[guid]=true
			end
		end
	end
	return objects
end
local function apocalypseQuestCardTitle(card)
	if card==nil then return "card" end
	local details=gameCards~=nil and gameCards[card.guid] or nil
	if details~=nil and details.name~=nil then
		local name=details.name
		if type(name)=="table" then name=name[1] end
		if name~=nil and tostring(name)~="" then return tostring(name) end
	end
	local name=card.getName()
	if name~=nil and name~="" then return name end
	return "card "..tostring(card.guid)
end
local function apocalypseQuestTuckedCardDestination(card)
	if card==nil then return nil, nil end
	local details=gameCards~=nil and gameCards[card.guid] or nil
	local cardType=details~=nil and details.cardType or nil
	local notes=card.getGMNotes()
	local name=card.getName()
	if cardType=="Advanced Action" or notes=="Advanced Action" or name=="Advanced Action" then return GUID.deck.action, "Advanced Action" end
	if cardType=="Spell" or notes=="Spell" or name=="Spell" then return GUID.deck.spell, "Spell" end
	if cardType=="Artifact" or notes=="Artifact" or name=="Artifact" then return GUID.deck.artifact, "Artifact" end
	if cardType=="Regular Unit" or name=="Regular Unit" then return GUID.deck.regularUnit, "Regular Unit" end
	if cardType=="Elite Unit" or name=="Elite Unit" then return GUID.deck.eliteUnit, "Elite Unit" end
	return nil, nil
end
apocalypseQuestStageIntoContainer=function(obj,container)
	if obj==nil or container==nil then return false end
	local objectGUID=obj.guid
	local containerGUID=container.guid
	local target=container.getPosition()
	obj.unlock()
	--Teleport clear of the Quest first. Direct putObject while a tucked object is still physically under
	--the Quest lets the Quest collider carry it when the Quest card moves in the same cleanup frame.
	obj.setPosition({target[1],target[2]+2.2,target[3]})
	safeWaitFrames("Quests",function()
		local live=getObjectFromGUID(objectGUID)
		local liveContainer=getObjectFromGUID(containerGUID)
		if live~=nil and liveContainer~=nil then liveContainer.putObject(live) end
	end,2)
	return true
end

local function apocalypseQuestReturnTuckedCard(card, questName)
	local destinationGUID, destinationName=apocalypseQuestTuckedCardDestination(card)
	if destinationGUID==nil then
		broadcastToAll(joinLang({"{en}Quest cleanup: Could not identify where \"{ru}Очистка задания: не удалось определить, куда вернуть \"{zh-tw}任務清理：無法判斷 \"{zh-cn}任务清理：无法判断 \"{ko}퀘스트 정리: \"{es}Limpieza de Misión: no se pudo determinar dónde va \"{fr}Nettoyage de Quête : impossible de déterminer où doit aller \"{pt-br}Limpeza da Missão: não foi possível determinar onde \"{de}Quest-Bereinigung: Es konnte nicht ermittelt werden, wohin \"",apocalypseQuestCardTitle(card),"{en}\" from \"{ru}\" из задания \"{zh-tw}\"（來自 \"{zh-cn}\"（来自 \"{ko}\" 카드가 \"{es}\" de \"{fr}\" provenant de \"{pt-br}\" de \"{de}\" aus \"",questName,"{en}\" belongs. It has been left on the table.{ru}\". Карта оставлена на столе.{zh-tw}\"）應歸還到哪裡。它已留在桌上。{zh-cn}\"）应归还到哪里。它已留在桌上。{ko}\"에서 어디로 돌아가야 하는지 확인하지 못했습니다. 테이블에 남겨 두었습니다.{es}\". Se ha dejado sobre la mesa.{fr}\". La carte a été laissée sur la table.{pt-br}\" deve ir. Ela foi deixada na mesa.{de}\" gehört. Die Karte wurde auf dem Tisch liegen gelassen."}), {1,0.55,0.2})
		return false
	end
	--Standard offers can eventually collapse to a single Card, so find the live deck/card in its deck zone
	--instead of assuming the original setup Deck GUID still exists.
	local destination=standardDeckCycleObject(destinationName) or getObjectFromGUID(destinationGUID)
	if destination==nil or destination.guid==card.guid or (destination.type~="Deck" and destination.type~="Card") then
		broadcastToAll(joinLang({"{en}Quest cleanup: The {ru}Очистка задания: колода {zh-tw}任務清理：{zh-cn}任务清理：{ko}퀘스트 정리: {es}Limpieza de Misión: el mazo de {fr}Nettoyage de Quête : le paquet {pt-br}Limpeza da Missão: o baralho {de}Quest-Bereinigung: Der Stapel ",destinationName,"{en} deck was not available for \"{ru} недоступна для \"{zh-tw} 牌庫無法接收 \"{zh-cn} 牌库无法接收 \"{ko} 덱을 \"{es} no estaba disponible para \"{fr} n’était pas disponible pour \"{pt-br} não estava disponível para \"{de} war nicht verfügbar für \"",apocalypseQuestCardTitle(card),"\"{en} from \"{ru} из \"{zh-tw}（來自 \"{zh-cn}（来自 \"{ko} (\"{es} de \"{fr} de \"{pt-br} de \"{de} aus \"",questName,"{en}\". It has been left on the table.{ru}\". Карта оставлена на столе.{zh-tw}\"）。它已留在桌上。{zh-cn}\"）。它已留在桌上。{ko}\"). 테이블에 남겨 두었습니다.{es}\". Se ha dejado sobre la mesa.{fr}\". La carte a été laissée sur la table.{pt-br}\". Ela foi deixada na mesa.{de}\". Die Karte wurde auf dem Tisch liegen gelassen."}), {1,0.55,0.2})
		return false
	end
	local cardGUID=card.guid
	local cardTitle=apocalypseQuestCardTitle(card)
	local destinationRotation=destination.getRotation()
	local target=destination.getPosition()
	card.unlock()
	standardDeckCycleMarkReturned(destinationName, card)
	--First detach the tucked card from the Quest physically; only then merge it with its real deck.
	card.setRotation(destinationRotation)
	card.setPosition({target[1],target[2]+2.2,target[3]})
	safeWaitFrames("Quests",function()
		local liveCard=getObjectFromGUID(cardGUID)
		local liveDestination=standardDeckCycleObject(destinationName) or getObjectFromGUID(destinationGUID)
		if liveCard==nil then return end
		if liveDestination==nil or liveDestination.guid==liveCard.guid or (liveDestination.type~="Deck" and liveDestination.type~="Card") then
			broadcastToAll(joinLang({"{en}Quest cleanup: The {ru}Очистка задания: колода {zh-tw}任務清理：{zh-cn}任务清理：{ko}퀘스트 정리: {es}Limpieza de Misión: el mazo de {fr}Nettoyage de Quête : le paquet {pt-br}Limpeza da Missão: o baralho {de}Quest-Bereinigung: Der Stapel ",destinationName,"{en} deck disappeared before \"{ru} исчезла до того, как удалось вернуть \"{zh-tw} 牌庫在 \"{zh-cn} 牌库在 \"{ko} 덱이 \"{es} desapareció antes de que \"{fr} a disparu avant que \"{pt-br} desapareceu antes que \"{de} verschwand, bevor \"",cardTitle,"{en}\" could be returned.{ru}\".{zh-tw}\" 歸還前消失了。{zh-cn}\" 归还前消失了。{ko}\" 카드를 돌려놓기 전에 사라졌습니다.{es}\" pudiera devolverse.{fr}\" puisse être rendue.{pt-br}\" pudesse ser devolvida.{de}\" zurückgelegt werden konnte."}), {1,0.55,0.2})
			return
		end
		putCardAtBottom(liveDestination,liveCard)
		broadcastToAll(joinLang({"{en}Quest cleanup: \"{ru}Очистка задания: \"{zh-tw}任務清理：\"{zh-cn}任务清理：\"{ko}퀘스트 정리: \"{es}Limpieza de Misión: \"{fr}Nettoyage de Quête : \"{pt-br}Limpeza da Missão: \"{de}Quest-Bereinigung: \"",cardTitle,"{en}\" returned to the bottom of the {ru}\" возвращена на дно колоды {zh-tw}\" 已歸還到 {zh-cn}\" 已归还到 {ko}\" 카드를 {es}\" volvió al fondo del mazo de {fr}\" a été remise sous le paquet {pt-br}\" voltou para o fundo do baralho {de}\" wurde unter den Stapel ",destinationName,"{en} deck.{ru}.{zh-tw} 牌庫底部。{zh-cn} 牌库底部。{ko} 덱 맨 아래로 돌려놓았습니다.{es}.{fr}.{pt-br}.{de} gelegt."}), {1,1,0.5})
	end,2)
	return true
end
function apocalypseQuestTokenBagSetup()
	--Quest marker identity comes from the Quest catalogue, not from enumerating the physical bag.
	--Besides avoiding an unnecessary container scan, this remains reliable while uncached bags are loading.
	gStates.apocalypseQuestTokenGUIDs={}
	if gStates.apocalypseQuestTokenInBag==nil then gStates.apocalypseQuestTokenInBag={} end
	for _,quest in pairs(apocalypseQuestData) do
		for _,tokenGUID in ipairs(quest.questTokens or {}) do
			gStates.apocalypseQuestTokenGUIDs[tokenGUID]=true
			--On fresh setup every unspawned catalogue marker is in the Quest Token bag. This also gives
			--older saves a safe initial state without ever calling getObjects() on the container.
			if gStates.apocalypseQuestTokenInBag[tokenGUID]==nil then
				gStates.apocalypseQuestTokenInBag[tokenGUID]=getObjectFromGUID(tokenGUID)==nil
			end
		end
	end
end

apocalypseQuestReturnRevealBag=function(card)
	local quest=card~=nil and apocalypseQuestData[card.guid] or nil
	if quest==nil or quest.revealBag==nil then return false end
	local bag=getObjectFromGUID(quest.revealBag)
	local tokenBag=getObjectFromGUID(GUID.bag.apocalypseQuestTokens)
	if bag==nil or tokenBag==nil then return false end
	apocalypseQuestStageIntoContainer(bag,tokenBag)
	return true
end

local apocalypseQuestRevealSetupHandlers={
	regularUnitII=function(card,cardPos,track)
		local deck=standardDeckCycleObject("Regular Unit")
		if deck~=nil then
			local unitGUID=nil
			if deck.type=="Deck" then
				for _, data in ipairs(deck.getObjects()) do
					if gameCards[data.guid]~=nil and gameCards[data.guid].cardType=="Regular Unit" and gameCards[data.guid].level==2 and data.guid~="0a2e0b" and data.guid~="d8e49b" then unitGUID=data.guid break end
				end
			elseif deck.type=="Card" and gameCards[deck.guid]~=nil and gameCards[deck.guid].cardType=="Regular Unit" and gameCards[deck.guid].level==2 and deck.guid~="0a2e0b" and deck.guid~="d8e49b" then
				unitGUID=deck.guid
			end
			local tuckPos={cardPos[1], cardPos[2]-0.06, cardPos[3]+1.10}
			if unitGUID~=nil then
				if deck.type=="Deck" then
					track(safeTakeObject("Quests",deck,{guid=unitGUID,position=tuckPos,rotation={0,180,0},smooth=false,callback_function=function(obj) if obj~=nil then obj.lock() end end}))
				else
					deck.setRotationSmooth({0,180,0})
					deck.setPosition(tuckPos)
					deck.lock()
					track(deck)
				end
			else
				broadcastToAll("{en}Quest setup: Prove Yourself could not find a level II Regular Unit.{ru}Подготовка задания: Prove Yourself не смогло найти обычный отряд II уровня.{zh-tw}任務設置：Prove Yourself 找不到 II 級常規部隊。{zh-cn}任务设置：Prove Yourself 找不到 II 级常规部队。{ko}퀘스트 설정: Prove Yourself에서 II레벨 일반 유닛을 찾지 못했습니다.{es}Preparación de Misión: Prove Yourself no pudo encontrar una Unidad Regular de nivel II.{fr}Mise en place de Quête : Prove Yourself n’a pas pu trouver d’Unité Régulière de niveau II.{pt-br}Preparação da Missão: Prove Yourself não conseguiu encontrar uma Unidade Regular de nível II.{de}Quest-Aufbau: Prove Yourself konnte keine reguläre Einheit der Stufe II finden.", {1,0.55,0.2})
			end
		end
	end,
	spell=function(card,cardPos,track)
		local deck=standardDeckCycleObject("Spell")
		if deck~=nil then
			standardDeckCycleShuffleIfReached("Spell", deck)
			local tuckPos={cardPos[1], cardPos[2]-0.06, cardPos[3]+1.10}
			if deck.type=="Deck" then
				track(safeTakeObject("Quests",deck,{position=tuckPos,rotation={0,180,0},smooth=false,callback_function=function(obj) if obj~=nil then obj.lock() end end}))
			elseif deck.type=="Card" then
				deck.setRotationSmooth({0,180,0})
				deck.setPosition(tuckPos)
				deck.lock()
				track(deck)
			end
		else
			broadcastToAll("{en}Quest setup: The Spell Thief could not find the Spell deck.{ru}Подготовка задания: The Spell Thief не смог найти колоду Заклинаний.{zh-tw}任務設置：The Spell Thief 找不到法術牌庫。{zh-cn}任务设置：The Spell Thief 找不到法术牌库。{ko}퀘스트 설정: The Spell Thief에서 주문 덱을 찾지 못했습니다.{es}Preparación de Misión: The Spell Thief no pudo encontrar el mazo de Hechizos.{fr}Mise en place de Quête : The Spell Thief n’a pas pu trouver le paquet de Sorts.{pt-br}Preparação da Missão: The Spell Thief não conseguiu encontrar o baralho de Feitiços.{de}Quest-Aufbau: The Spell Thief konnte den Zauberstapel nicht finden.", {1,0.55,0.2})
		end
	end,
	randomCrystal=function(card,cardPos,track)
		local roll=apocalypseQuestRollManaDie()
		track(apocalypseQuestPlaceManaTokenOnCard(card,roll,0,-0.15,"Travelling Merchant setup"))
	end,
	werewolf=function(card,cardPos,track)
		track(apocalypseQuestPlaceNamedEnemy(card,"tan","Werewolf",true,0))
	end,
}

apocalypseQuestRevealSetup=function(card)
	if card==nil then return false end
	local quest=apocalypseQuestData[card.guid]
	if quest==nil then return false end
	if gStates.apocalypseQuestRevealDone==nil then gStates.apocalypseQuestRevealDone={} end
	if gStates.apocalypseQuestRevealPending==nil then gStates.apocalypseQuestRevealPending={} end
	apocalypseQuestRevealWaitScheduled=apocalypseQuestRevealWaitScheduled or {}
	local cardGUID=card.guid
	if gStates.apocalypseQuestRevealDone[cardGUID]==true then return true end

	local function pendingReady(pending)
		if pending==nil then return true end
		pending.checks=(pending.checks or 0)+1
		for _,guid in ipairs(pending.guids or {}) do
			local obj=getObjectFromGUID(guid)
			if obj==nil then
				if pending.checks<12 then return false end
			elseif obj.spawning==true or obj.isSmoothMoving()==true then return false end
		end
		return true
	end
	local function finishReveal(rebuild)
		local pendingState=gStates.apocalypseQuestRevealPending[cardGUID]
		apocalypseQuestRevealWaitScheduled[cardGUID]=nil
		--If cleanup removed the pending state while this callback was queued, the Quest has already left play.
		if pendingState==nil and gStates.apocalypseQuestRevealDone[cardGUID]~=true then return end
		local live=getObjectFromGUID(cardGUID)
		if live==nil then return end
		gStates.apocalypseQuestRevealDone[cardGUID]=true
		gStates.apocalypseQuestRevealPending[cardGUID]=nil
		live.lock()
		if rebuild==true then QuestPrivate.apocalypseQuestInterfaceAdd(live,true) end
	end
	local function scheduleRevealWait()
		if apocalypseQuestRevealWaitScheduled[cardGUID]==true then return end
		apocalypseQuestRevealWaitScheduled[cardGUID]=true
		safeWaitFrames("Quests",function()
			safeWaitCondition("Quests",function() finishReveal(true) end,function()
				return pendingReady(gStates.apocalypseQuestRevealPending[cardGUID])
			end,5,function() finishReveal(true) end)
		end,1)
	end

	local existingPending=gStates.apocalypseQuestRevealPending[cardGUID]
	if existingPending~=nil then
		if pendingReady(existingPending)==true then finishReveal(false) return true end
		scheduleRevealWait()
		return false
	end

	card.lock()
	local pending={guids={},checks=0}
	gStates.apocalypseQuestRevealPending[cardGUID]=pending
	local function track(obj)
		if obj~=nil and obj.guid~=nil then pending.guids[#pending.guids+1]=obj.guid end
		return obj
	end
	local cardPos=card.getPosition()
	local handler=apocalypseQuestHandler(card)

	--Put this Quest's physical marker(s) face down on the card. Face-down Quest tokens are inert markers;
	--players move them to the printed location, and only a face-up token can become a site/reward/effect.
	local questTokens=quest.questTokens or {}
	if #questTokens>0 then
		local tokenBag=getObjectFromGUID(GUID.bag.apocalypseQuestTokens)
		if tokenBag~=nil then
			for tokenIndex=#questTokens, 1, -1 do
				local tokenGUID=questTokens[tokenIndex]
				local fanOffset=(tokenIndex-1)*0.16
				local layerOffset=(#questTokens-tokenIndex)*0.12
				local tokenPos=handler~=nil and handler.revealTokenPosition~=nil and handler.revealTokenPosition(cardPos,tokenIndex,#questTokens) or
					{cardPos[1],cardPos[2]+0.45+layerOffset,cardPos[3]-0.15+fanOffset}
				track(tokenBag.takeObject({guid=tokenGUID,position=tokenPos,rotation={0,180,0},smooth=false}))
			end
		end
	end

	--Some Quests keep a small reusable reward supply on the card while they are active.
	if quest.revealBag~=nil then
		local revealGUID=quest.revealBag
		local revealPos=handler~=nil and handler.revealBagPosition~=nil and handler.revealBagPosition(cardPos) or {cardPos[1],cardPos[2]+0.62,cardPos[3]+1.35}
		local liveBag=getObjectFromGUID(revealGUID)
		if liveBag~=nil then
			liveBag.unlock()
			liveBag.setRotation({0,180,0})
			liveBag.setPosition(revealPos)
			track(liveBag)
		else
			local tokenBag=getObjectFromGUID(GUID.bag.apocalypseQuestTokens)
			local taken=tokenBag~=nil and safeTakeObject("Quests",tokenBag,{guid=revealGUID,position=revealPos,rotation={0,180,0},smooth=false,callback_function=function(obj) if obj~=nil then obj.unlock() end end}) or nil
			track(taken)
			if taken==nil then broadcastToAll(joinLang({"{en}Quest setup: {ru}Подготовка задания: {zh-tw}任務設置：{zh-cn}任务设置：{ko}퀘스트 설정: {es}Preparación de Misión: {fr}Mise en place de Quête : {pt-br}Preparação da Missão: {de}Quest-Aufbau: ",apocalypseQuestName(card),"{en} could not find its reward-token bag.{ru} не смогло найти мешок жетонов награды.{zh-tw} 找不到獎勵標記袋。{zh-cn} 找不到奖励标记袋。{ko} 보상 토큰 주머니를 찾지 못했습니다.{es} no pudo encontrar su bolsa de fichas de recompensa.{fr} n’a pas pu trouver son sac de jetons de récompense.{pt-br} não conseguiu encontrar sua bolsa de fichas de recompensa.{de} konnte seinen Belohnungsmarker-Beutel nicht finden."}),{1,0.55,0.2}) end
		end
	end

	--Catalogue-defined reveal setups dispatch through named handlers so this lifecycle function stays generic.
	local revealHandler=apocalypseQuestRevealSetupHandlers[quest.revealSetup]
	if revealHandler~=nil then revealHandler(card,cardPos,track) end
	if pendingReady(pending)==true then finishReveal(false) return true end
	scheduleRevealWait()
	return false
end

apocalypseQuestUndoSiteToken=function(tokenGUID)
	if gStates.apocalypseQuestSiteState==nil then return false end
	local state=gStates.apocalypseQuestSiteState[tokenGUID]
	if state==nil then return false end
	local terrainData=terrainTiles[state.terrainGUID]
	if terrainData~=nil then
		runtimeMapSetHexFeature(state.terrainGUID,state.bearing,state.oldFeature or "")
		if terrainData.mineColors~=nil then
			if state.oldMineColors~=nil then terrainData.mineColors[state.bearing]=state.oldMineColors else terrainData.mineColors[state.bearing]=nil end
		end
		if gStates.hexOverideSave[state.terrainGUID]==nil then gStates.hexOverideSave[state.terrainGUID]={} end
		if state.oldOverride~=nil then gStates.hexOverideSave[state.terrainGUID][state.bearing]=state.oldOverride else gStates.hexOverideSave[state.terrainGUID][state.bearing]=nil end
	end
	gStates.apocalypseQuestSiteState[tokenGUID]=nil
	scheduleAvatarDropRefresh()
	return true
end

apocalypseQuestTokenFaceUp=function(token)
	if token==nil then return false end
	local rotation=token.getRotation()
	local z=((rotation[3] or 0)%360+360)%360
	return z>90 and z<270
end

function apocalypseQuestSiteTokenDropped(token)
	if token==nil then return false end
	local site=nil
	if token.guid=="02f996" then site="mine"
	elseif token.guid=="a4777c" then site="monster den"
	elseif token.guid=="963031" then site="spawning grounds"
	else return false end

	--Quest tokens are inert markers while face down. Flipping an active site back down removes its
	--terrain override again; only the printed face-up state ({0,180,180}) can create the site.
	apocalypseQuestUndoSiteToken(token.guid)
	if apocalypseQuestTokenFaceUp(token)~=true then
		token.unlock()
		return true
	end

	local terrain, bearing=terrainHexAtPosition(token.getPosition())
	if terrain==nil or bearing==nil or terrainTiles[terrain.guid]==nil then return true end
	local terrainData=terrainTiles[terrain.guid]
	local oldMineColors=nil
	if terrainData.mineColors~=nil and terrainData.mineColors[bearing]~=nil then
		oldMineColors={}
		for i, color in ipairs(terrainData.mineColors[bearing]) do oldMineColors[i]=color end
	end
	local oldOverride=gStates.hexOverideSave[terrain.guid]~=nil and gStates.hexOverideSave[terrain.guid][bearing] or nil
	if gStates.apocalypseQuestSiteState==nil then gStates.apocalypseQuestSiteState={} end
	gStates.apocalypseQuestSiteState[token.guid]={terrainGUID=terrain.guid, bearing=bearing, oldFeature=terrainData.hexFeature[bearing] or "", oldMineColors=oldMineColors, oldOverride=oldOverride, site=site}
	runtimeMapSetHexFeature(terrain.guid,bearing,site)
	if gStates.hexOverideSave[terrain.guid]==nil then gStates.hexOverideSave[terrain.guid]={} end
	gStates.hexOverideSave[terrain.guid][bearing]=site
	if site=="mine" then
		if terrainData.mineColors==nil then terrainData.mineColors={} end
		terrainData.mineColors[bearing]={"Red","Blue","Green","White"}
		local info=getObjectFromGUID("6b9c02")
		if info~=nil then info.setRotationSmooth({0,180,0}) end
	elseif site=="monster den" then
		local info=getObjectFromGUID("3aef9a")
		if info~=nil then info.setRotationSmooth({0,180,0}) end
	else
		local info=getObjectFromGUID("321d15")
		if info~=nil then info.setRotationSmooth({0,180,0}) end
	end
	token.lock()
	broadcastToAll(joinLang({"{en}Quest site placed: {ru}Место задания размещено: {zh-tw}已放置任務地點：{zh-cn}已放置任务地点：{ko}퀘스트 장소 배치: {es}Lugar de Misión colocado: {fr}Site de Quête placé : {pt-br}Local da Missão colocado: {de}Quest-Ort platziert: ",site,"."}), {1,1,0.5})
	scheduleAvatarDropRefresh()
	return true
end
local function apocalypseQuestLoseReputation(playerIndex, questName, reason)
	local details=turnOrder[playerIndex]
	if details==nil then return false end
	--Queue Quest Reputation losses exactly like the Main UI ShrinkRep button. End-of-turn cleanup applies them.
	refreshPlayerReputationFromShield(playerIndex)
	details.repGain=details.repGain or 0
	local prefix=reason=="abandon" and "Quest abandoned: " or reason=="fail" and "Quest failed: " or reason=="effect" and "Quest effect: " or "Quest cleanup: "
	local explanation=reason=="abandon" and " for abandoning Personal Quest \""..questName.."\"." or reason=="fail" and " for failing Quest \""..questName.."\"." or reason=="effect" and " from completing \""..questName.."\"." or " because their Shield was on Personal Quest \""..questName.."\"."
	if details.repGain>(-7-details.reputation) then
		details.repGain=details.repGain-1
		broadcastToAll(joinLang({prefix,translateWord[details.mage] or tostring(details.mage),"{en} loses 1 Reputation{ru} теряет 1 Репутацию{zh-tw} 失去 1 聲望{zh-cn} 失去 1 声望{ko}이(가) 평판 1을 잃습니다{es} pierde 1 de Reputación{fr} perd 1 Réputation{pt-br} perde 1 de Reputação{de} verliert 1 Ansehen",explanation}), positionToColor(playerIndex))
		if playerIndex==gStates.turnNumber then mainUIUpdate("Quest Reputation loss") end
	else
		broadcastToAll(joinLang({prefix,translateWord[details.mage] or tostring(details.mage),"{en} is already at minimum Reputation after pending changes; no further Reputation can be lost.{ru} уже имеет минимальную Репутацию с учётом ожидающих изменений; больше Репутации потерять нельзя.{zh-tw} 在計入待處理變更後已達最低聲望；不能再失去聲望。{zh-cn} 在计入待处理变更后已达最低声望；不能再失去声望。{ko}은(는) 대기 중인 변경을 반영하면 이미 최저 평판입니다. 더 이상 평판을 잃을 수 없습니다.{es} ya está en la Reputación mínima tras los cambios pendientes; no puede perder más Reputación.{fr} est déjà à la Réputation minimale après les changements en attente ; aucune Réputation supplémentaire ne peut être perdue.{pt-br} já está na Reputação mínima após as alterações pendentes; não pode perder mais Reputação.{de} ist nach den ausstehenden Änderungen bereits beim minimalen Ansehen; weiteres Ansehen kann nicht verloren werden."}), positionToColor(playerIndex))
	end
	return true
end

apocalypseQuestGainReputation=function(playerIndex, questName)
	local details=turnOrder[playerIndex]
	if details==nil then return false end
	--Queue Quest Reputation exactly like the Main UI GrowRep button. End-of-turn cleanup applies it.
	refreshPlayerReputationFromShield(playerIndex)
	details.repGain=details.repGain or 0
	if details.repGain<(7-details.reputation) then
		details.repGain=details.repGain+1
		broadcastToAll(joinLang({"{en}Quest reward: {ru}Награда задания: {zh-tw}任務獎勵：{zh-cn}任务奖励：{ko}퀘스트 보상: {es}Recompensa de Misión: {fr}Récompense de Quête : {pt-br}Recompensa da Missão: {de}Quest-Belohnung: ",translateWord[details.mage] or tostring(details.mage),"{en} gains 1 Reputation from completing \"{ru} получает 1 Репутацию за завершение \"{zh-tw} 完成 \"{zh-cn} 完成 \"{ko}이(가) \"{es} gana 1 de Reputación por completar \"{fr} gagne 1 Réputation pour avoir terminé \"{pt-br} ganha 1 de Reputação por concluir \"{de} erhält 1 Ansehen für den Abschluss von \"",tostring(questName or "a Quest"),"\"."}), positionToColor(playerIndex))
		mainUIUpdate("Quest Reputation reward")
	else
		broadcastToAll(joinLang({"{en}Quest reward: {ru}Награда задания: {zh-tw}任務獎勵：{zh-cn}任务奖励：{ko}퀘스트 보상: {es}Recompensa de Misión: {fr}Récompense de Quête : {pt-br}Recompensa da Missão: {de}Quest-Belohnung: ",translateWord[details.mage] or tostring(details.mage),"{en} is already at maximum Reputation after pending changes.{ru} уже имеет максимальную Репутацию с учётом ожидающих изменений.{zh-tw} 在計入待處理變更後已達最高聲望。{zh-cn} 在计入待处理变更后已达最高声望。{ko}은(는) 대기 중인 변경을 반영하면 이미 최대 평판입니다.{es} ya está en la Reputación máxima tras los cambios pendientes.{fr} est déjà à la Réputation maximale après les changements en attente.{pt-br} já está na Reputação máxima após as alterações pendentes.{de} ist nach den ausstehenden Änderungen bereits beim maximalen Ansehen."}), positionToColor(playerIndex))
	end
	return true
end

apocalypseQuestBasicCrystalColor=function(obj)
	if obj==nil then return nil end
	return ({["Red Mana"]="Red", ["Blue Mana"]="Blue", ["Green Mana"]="Green", ["White Mana"]="White"})[obj.getName()]
end

apocalypseQuestManaTokenColor=function(obj)
	if obj==nil then return nil end
	local basic=apocalypseQuestBasicCrystalColor(obj)
	if basic~=nil then return basic end
	local name=obj.getName()
	if name=="Gold Mana" then return "Gold" end
	if name=="Black Mana" then return "Black" end
	return nil
end

apocalypseQuestManaBag=function(color)
	if color==nil then return nil end
	local key=mineCrystalBagKey[color]
	if key~=nil and GUID.bag.mana[key]~=nil then return getObjectFromGUID(GUID.bag.mana[key]) end
	if GUID.bag.mana[string.lower(color)]~=nil then return getObjectFromGUID(GUID.bag.mana[string.lower(color)]) end
	return nil
end

--Quest steps frequently create a Shield/enemy/crystal immediately before their card moves to the left.
--Do not spawn those pieces over the old card and then race TTS's spawning lifecycle trying to reacquire them.
--While a move is planned, helpers can resolve the card's future position and send new pieces directly there.
apocalypseQuestMoveAttachmentCapture=apocalypseQuestMoveAttachmentCapture or {}
apocalypseQuestBeginMoveAttachmentCapture=function(card,target)
	local cardGUID=card~=nil and card.guid or nil
	if cardGUID==nil then return end
	local source=card.getPosition()
	apocalypseQuestMoveAttachmentCapture[cardGUID]={target=target~=nil and {target[1],source[2],target[3]} or nil,objects={}}
end
apocalypseQuestEndMoveAttachmentCapture=function(card)
	local cardGUID=card~=nil and card.guid or nil
	if cardGUID~=nil then apocalypseQuestMoveAttachmentCapture[cardGUID]=nil end
end
apocalypseQuestPlannedCardPosition=function(card)
	if card==nil then return nil end
	local capture=apocalypseQuestMoveAttachmentCapture[card.guid]
	if type(capture)=="table" and capture.target~=nil then return capture.target end
	return card.getPosition()
end
apocalypseQuestPlannedWorldPosition=function(card,position)
	if card==nil or position==nil then return position end
	local capture=apocalypseQuestMoveAttachmentCapture[card.guid]
	if type(capture)~="table" or capture.target==nil then return position end
	local source=card.getPosition()
	return {position[1]+capture.target[1]-source[1],position[2],position[3]+capture.target[3]-source[3]}
end
apocalypseQuestMoveAttachmentTarget=function(card,obj)
	if card==nil or obj==nil or gStates.apocalypseQuestMoveAttachments==nil then return nil end
	local record=gStates.apocalypseQuestMoveAttachments[card.guid]
	record=record~=nil and record[obj.guid] or nil
	return type(record)=="table" and record.target or nil
end
apocalypseQuestMoveAttachmentOwnerGUID=function(objectGUID)
	if objectGUID==nil or gStates.apocalypseQuestMoveAttachments==nil then return nil end
	for cardGUID,records in pairs(gStates.apocalypseQuestMoveAttachments) do
		if records~=nil and records[objectGUID]~=nil then return cardGUID end
	end
	return nil
end
apocalypseQuestRegisterMoveAttachment=function(card,obj,target)
	local cardGUID=card~=nil and card.guid or nil
	local objectGUID=obj~=nil and obj.guid or nil
	local capture=cardGUID~=nil and apocalypseQuestMoveAttachmentCapture[cardGUID] or nil
	if cardGUID~=nil and objectGUID~=nil and capture~=nil then
		if type(capture)=="table" then
			capture.objects=capture.objects or {}
			capture.objects[objectGUID]=obj
		end
		if gStates.apocalypseQuestMoveAttachments==nil then gStates.apocalypseQuestMoveAttachments={} end
		if gStates.apocalypseQuestMoveAttachments[cardGUID]==nil then gStates.apocalypseQuestMoveAttachments[cardGUID]={} end
		gStates.apocalypseQuestMoveAttachments[cardGUID][objectGUID]=target~=nil and {target={target[1],target[2],target[3]}} or true
	end
	return obj
end

apocalypseQuestPlaceManaTokenOnCard=function(card,color,offsetX,offsetZ,reason)
	if card==nil then return nil end
	local bag=apocalypseQuestManaBag(color)
	if bag==nil or bag.getQuantity()==0 then
		broadcastToAll(joinLang({"{en}Quest effect: no {ru}Эффект задания: нет доступного жетона маны {zh-tw}任務效果：沒有可用的 {zh-cn}任务效果：没有可用的 {ko}퀘스트 효과: 사용할 수 있는 {es}Efecto de Misión: no hay ficha de maná {fr}Effet de Quête : aucun jeton de mana {pt-br}Efeito da Missão: não há ficha de mana {de}Quest-Effekt: Es ist kein ",translateWord[color] or tostring(color),"{en} mana token is available for {ru} для {zh-tw} 魔力標記供 {zh-cn} 魔力标记供 {ko} 마나 토큰이 없습니다: {es} disponible para {fr} disponible pour {pt-br} disponível para {de}-Manamarker verfügbar für ",tostring(reason or "this Quest"),"."}),{1,0.55,0.2})
		return nil
	end
	local pos=apocalypseQuestPlannedCardPosition(card) or card.getPosition()
	local target={pos[1]+(offsetX or 0),pos[2]+0.55,pos[3]+(offsetZ or -0.55)}
	local token=takeManaCrystal(bag,{position=target,smooth=false})
	return apocalypseQuestRegisterMoveAttachment(card,token,target)
end

apocalypseQuestGiveCrystal=function(playerIndex, color, position, reason)
	if turnOrder[playerIndex]==nil or mineCrystalBagKey[color]==nil then return false end
	if mineCrystalCount(playerIndex, color)>=3 then
		broadcastToAll(joinLang({translateWord[turnOrder[playerIndex].mage] or tostring(turnOrder[playerIndex].mage),"{en} could not gain the {ru} не смог получить {zh-tw} 無法獲得 {zh-cn} 无法获得 {ko}이(가) {es} no pudo ganar el cristal {fr} n’a pas pu gagner le cristal {pt-br} não pôde ganhar o cristal {de} konnte den ",translateWord[color] or color,"{en} crystal from {ru} кристалл из {zh-tw} 水晶（來自 {zh-cn} 水晶（来自 {ko} 크리스털을 얻지 못했습니다: {es} de {fr} de {pt-br} de {de}-Kristall aus ",tostring(reason or "a Quest"),"{en} because their Inventory already has 3.{ru}, потому что в Инвентаре уже есть 3.{zh-tw}），因為庫存中已有 3 顆。{zh-cn}），因为库存中已有 3 颗。{ko}. 인벤토리에 이미 3개가 있습니다.{es} porque su Inventario ya tiene 3.{fr} car son Inventaire en contient déjà 3.{pt-br} porque seu Inventário já tem 3.{de} nicht erhalten, da das Inventar bereits 3 enthält."}), positionToColor(playerIndex))
		return false
	end
	local bag=getObjectFromGUID(GUID.bag.mana[mineCrystalBagKey[color]])
	if bag==nil or bag.getQuantity()==0 then
		broadcastToAll(joinLang({"{en}Quest reward: no {ru}Награда задания: в запасе нет {zh-tw}任務獎勵：供應區沒有可用的 {zh-cn}任务奖励：供应区没有可用的 {ko}퀘스트 보상: 공급처에 사용할 수 있는 {es}Recompensa de Misión: no hay cristal {fr}Récompense de Quête : aucun cristal {pt-br}Recompensa da Missão: não há cristal {de}Quest-Belohnung: Im Vorrat ist kein ",translateWord[color] or color,"{en} crystal is available in the supply.{ru} кристалла.{zh-tw} 水晶。{zh-cn} 水晶。{ko} 크리스털이 없습니다.{es} disponible en la reserva.{fr} disponible dans la réserve.{pt-br} disponível na reserva.{de}-Kristall verfügbar."}), {1,0.55,0.2})
		return false
	end
	takeManaCrystal(bag,{position=position or mineInventoryPosition(playerIndex, color),smooth=true})
	broadcastToAll(joinLang({translateWord[turnOrder[playerIndex].mage] or tostring(turnOrder[playerIndex].mage),"{en} gained a {ru} получил {zh-tw} 獲得了 {zh-cn} 获得了 {ko}이(가) {es} ganó un cristal {fr} a gagné un cristal {pt-br} ganhou um cristal {de} erhielt einen ",translateWord[color] or color,"{en} crystal from {ru} кристалл из {zh-tw} 水晶，來源：{zh-cn} 水晶，来源：{ko} 크리스털을 얻었습니다: {es} de {fr} de {pt-br} de {de}-Kristall aus ",tostring(reason or "a Quest"),"."}), positionToColor(playerIndex))
	return true
end

--Quest helpers below can now resolve printed random-mana-crystal rewards when a card's scripted
--completion effect needs them; ordinary resource costs still remain player-confirmed.

apocalypseQuestPlaceCrystalOnCard=function(card, color, offsetX, offsetZ, reason)
	return apocalypseQuestPlaceManaTokenOnCard(card,color,offsetX,offsetZ,reason)
end

apocalypseQuestFinalizeEnemyFacing=function(enemy, faceUp)
	if enemy==nil then return end
	local enemyGUID=enemy.guid
	safeWaitFrames("Quests",function()
		local placed=getObjectFromGUID(enemyGUID)
		if placed~=nil and ((faceUp==true and placed.is_face_down==true) or (faceUp~=true and placed.is_face_down~=true)) then placed.flip() end
	end,2)
end

apocalypseQuestPlaceNamedEnemy=function(card, pileName, enemyName, faceUp, offsetX)
	if card==nil or monsterPiles[pileName]==nil then return nil end
	local bag=getObjectFromGUID(monsterPiles[pileName])
	local discardGUID=({gray=GUID.bag.discard.keepGarrison, purple=GUID.bag.discard.towerGarrison, white=GUID.bag.discard.cityGarrison, tan=GUID.bag.discard.dungeon, red=GUID.bag.discard.draconum, green=GUID.bag.discard.orcs, yellow=GUID.bag.discard.ruin})[pileName]
	local discard=discardGUID~=nil and getObjectFromGUID(discardGUID) or nil
	local wantedGUID=nil
	local source=nil
	if bag~=nil then
		for _, data in ipairs(bag.getObjects() or {}) do
			local details=monsterPugs[data.guid]
			if details~=nil and details.name==enemyName then wantedGUID=data.guid source=bag break end
		end
	end
	--A named Quest enemy can already have been defeated earlier in the game. If it is not in the
	--normal pile, pull that exact token from the matching discard instead of failing the Quest setup.
	if wantedGUID==nil and discard~=nil then
		for _, data in ipairs(discard.getObjects() or {}) do
			local details=monsterPugs[data.guid]
			if details~=nil and details.name==enemyName then wantedGUID=data.guid source=discard break end
		end
	end
	if wantedGUID==nil or source==nil then
		broadcastToAll(joinLang({"{en}Quest setup: no {ru}Подготовка задания: нет доступного врага {zh-tw}任務設置：{zh-cn}任务设置：{ko}퀘스트 설정: {es}Preparación de Misión: no hay {fr}Mise en place de Quête : aucun {pt-br}Preparação da Missão: não há {de}Quest-Aufbau: Kein ",tostring(enemyName),"{en} is available in the {ru} в стопке врагов {zh-tw} 無法從 {zh-cn} 无法从 {ko} 적을 {es} disponible en la pila de enemigos {fr} disponible dans la pile d’ennemis {pt-br} disponível na pilha de inimigos {de} ist im Gegnerstapel ",tostring(pileName),"{en} enemy pile or its discard.{ru} или её сбросе.{zh-tw} 敵人堆或其棄牌中取得。{zh-cn} 敌人堆或其弃牌中取得。{ko} 적 더미나 버린 더미에서 찾을 수 없습니다.{es} ni en su descarte.{fr} ni dans sa défausse.{pt-br} nem em seu descarte.{de} oder dessen Ablage verfügbar."}), {1,0.55,0.2})
		return nil
	end
	if gStates.monsterPlayLocation~=nil then gStates.monsterPlayLocation[wantedGUID]=nil end
	local pos=apocalypseQuestPlannedCardPosition(card) or card.getPosition()
	local target={pos[1]+(offsetX or 0),pos[2]+0.75,pos[3]-0.35}
	local enemy=source.takeObject({guid=wantedGUID,position=target,rotation=faceUp and {0,180,0} or {0,180,180},smooth=true})
	apocalypseQuestRegisterMoveAttachment(card,enemy,target)
	apocalypseQuestFinalizeEnemyFacing(enemy, faceUp)
	return enemy
end

apocalypseQuestPlaceEnemy=function(card, pileName, faceUp, offsetX)
	if card==nil or monsterPiles[pileName]==nil then return nil end
	local bag=getObjectFromGUID(monsterPiles[pileName])
	if bag==nil or bag.getQuantity()==0 then
		broadcastToAll(joinLang({"{en}Quest setup: no {ru}Подготовка задания: нет доступного жетона врага из {zh-tw}任務設置：沒有可用的 {zh-cn}任务设置：没有可用的 {ko}퀘스트 설정: 사용할 수 있는 {es}Preparación de Misión: no hay ficha de enemigo de {fr}Mise en place de Quête : aucun jeton Ennemi de {pt-br}Preparação da Missão: não há ficha de inimigo de {de}Quest-Aufbau: Es ist kein Gegnermarker aus ",tostring(pileName),"{en} enemy token is available.{ru}.{zh-tw} 敵人標記。{zh-cn} 敌人标记。{ko} 적 토큰이 없습니다.{es} disponible.{fr} disponible.{pt-br} disponível.{de} verfügbar."}), {1,0.55,0.2})
		return nil
	end
	local pos=apocalypseQuestPlannedCardPosition(card) or card.getPosition()
	local target={pos[1]+(offsetX or 0),pos[2]+0.75,pos[3]-0.35}
	local enemy=bag.takeObject({position=target,rotation=faceUp and {0,180,0} or {0,180,180},smooth=true})
	apocalypseQuestRegisterMoveAttachment(card,enemy,target)
	apocalypseQuestFinalizeEnemyFacing(enemy, faceUp)
	return enemy
end

apocalypseQuestPlaceFistfulEnemies=function(card, callback)
	if card==nil then
		if callback~=nil then callback(false) end
		return false
	end
	local cardGUID=card.guid
	local offsets={-0.55,0.55}
	local index=1
	local success=true
	local function finish()
		local live=getObjectFromGUID(cardGUID)
		if live~=nil then QuestPrivate.apocalypseQuestInterfaceAdd(live,true) end
		if callback~=nil then callback(success) end
	end
	local function drawNext()
		local live=getObjectFromGUID(cardGUID)
		if live==nil then
			success=false
			finish()
			return
		end
		if apocalypseQuestPlaceEnemy(live,"gray",true,offsets[index])==nil then success=false end
		index=index+1
		if index<=#offsets then safeWaitFrames("Quests",drawNext,2)
		else safeWaitFrames("Quests",finish,2) end
	end
	drawNext()
	return true
end

apocalypseQuestCardHasEnemyType=function(card, pugType)
	for _, obj in ipairs(apocalypseQuestObjectsOnCard(card)) do
		if monsterPugs[obj.guid]~=nil and monsterPugs[obj.guid].pugType==pugType then return true end
	end
	return false
end

apocalypseQuestGiveTuckedCard=function(playerIndex, card, wantedType)
	if card==nil or turnOrder[playerIndex]==nil then return false end
	local tucked=nil
	for _, obj in ipairs(apocalypseQuestObjectsOnCard(card)) do
		if obj.type=="Card" and gameCardType(obj)==wantedType then tucked=obj break end
	end
	if tucked==nil then
		broadcastToAll(joinLang({"{en}Quest reward: \"{ru}Награда задания: \"{zh-tw}任務獎勵：\"{zh-cn}任务奖励：\"{ko}퀘스트 보상: \"{es}Recompensa de Misión: \"{fr}Récompense de Quête : \"{pt-br}Recompensa da Missão: \"{de}Quest-Belohnung: \"",apocalypseQuestName(card),"{en}\" could not find its tucked {ru}\" не смогло найти подложенную карту типа {zh-tw}\" 找不到其收在下方的 {zh-cn}\" 找不到其收在下方的 {ko}\"에서 아래에 넣어 둔 {es}\" no pudo encontrar su carta guardada de tipo {fr}\" n’a pas pu trouver sa carte glissée de type {pt-br}\" não conseguiu encontrar sua carta guardada do tipo {de}\" konnte seine daruntergelegte Karte vom Typ ",wantedType,"{en} card.{ru}.{zh-tw} 牌。{zh-cn} 牌。{ko} 카드를 찾지 못했습니다.{es}.{fr}.{pt-br}.{de} nicht finden."}), {1,0.55,0.2})
		return false
	end
	tucked.unlock()
	local zone=getObjectFromGUID(deedDeckZones[turnOrder[playerIndex].seatPos])
	if wantedType=="Spell" and zone~=nil then
		--Use the same visible, serialized Deed transfer as ordinary claimed cards. This keeps Quest rewards
		--from racing another claim toward the same deck and leaves one place responsible for top-of-deck insertion.
		if queueCardToDeedDeck(playerIndex,tucked)~=true then return false end
		broadcastToAll(joinLang({translateWord[turnOrder[playerIndex].mage] or tostring(turnOrder[playerIndex].mage),"{en} gained the Spell from \"{ru} получил Заклинание из \"{zh-tw} 獲得了 \"{zh-cn} 获得了 \"{ko}이(가) \"{es} ganó el Hechizo de \"{fr} a gagné le Sort de \"{pt-br} ganhou o Feitiço de \"{de} erhielt den Zauber aus \"",apocalypseQuestName(card),"{en}\" on top of their Deed deck.{ru}\" на верх своей колоды Действий.{zh-tw}\" 的法術，放到其行動牌庫頂。{zh-cn}\" 的法术，放到其行动牌库顶。{ko}\"의 주문을 행동 덱 맨 위에 놓았습니다.{es}\" en la parte superior de su mazo de Acciones.{fr}\" au-dessus de son paquet d’Actions.{pt-br}\" no topo de seu baralho de Ações.{de}\" oben auf seinen Aktionsstapel."}), positionToColor(playerIndex))
		return true
	end
	return false
end

apocalypseQuestGiveProveYourselfReward=function(card, playerIndex)
	if card==nil or turnOrder[playerIndex]==nil then return false end
	local token=getObjectFromGUID("c48454")
	local unit=nil
	for _, obj in ipairs(apocalypseQuestObjectsOnCard(card)) do
		if obj.type=="Card" and gameCardType(obj)=="Regular Unit" then unit=obj break end
	end
	if token==nil or unit==nil then
		broadcastToAll("{en}Quest reward: Prove Yourself could not find its Quest token or tucked Unit.{ru}Награда задания: Prove Yourself не смогло найти жетон задания или подложенный отряд.{zh-tw}任務獎勵：Prove Yourself 找不到任務標記或收在下方的部隊。{zh-cn}任务奖励：Prove Yourself 找不到任务标记或收在下方的部队。{ko}퀘스트 보상: Prove Yourself에서 퀘스트 토큰 또는 아래에 넣어 둔 유닛을 찾지 못했습니다.{es}Recompensa de Misión: Prove Yourself no pudo encontrar su ficha de Misión o la Unidad guardada.{fr}Récompense de Quête : Prove Yourself n’a pas pu trouver son jeton de Quête ou l’Unité glissée dessous.{pt-br}Recompensa da Missão: Prove Yourself não conseguiu encontrar sua ficha de Missão ou a Unidade guardada.{de}Quest-Belohnung: Prove Yourself konnte seinen Questmarker oder die daruntergelegte Einheit nicht finden.", {1,0.55,0.2})
		return false
	end
	local area=getObjectFromGUID(playerUnitAreas[turnOrder[playerIndex].seatPos])
	if area==nil then return false end
	local x=unitLayoutNextCommandX(turnOrder[playerIndex].seatPos)
	token.unlock()
	token.setGMNotes("Command Token")
	token.setRotationSmooth({0,180,180})
	token.setPositionSmooth({x,2.0,-31.2})
	unit.unlock()
	--The Unit is tucked underneath the Quest card, so lift it clear before using smooth movement.
	--Otherwise the Quest card's collider can catch the Unit and leave it sitting on top of the Quest.
	local unitGUID=unit.guid
	local unitPos=unit.getPosition()
	local questPos=card.getPosition()
	unit.setPosition({unitPos[1],math.max(unitPos[2]+1.2,questPos[2]+1.25),unitPos[3]})
	unit.setRotation({0,180,0})
	safeWaitFrames("Quests",function()
		local rewardUnit=getObjectFromGUID(unitGUID)
		if rewardUnit~=nil then
			rewardUnit.setRotationSmooth({0,180,0})
			rewardUnit.setPositionSmooth({x,2.0,-34.74})
		end
	end,1)
	scheduleUnitLayoutRefresh(turnOrder[playerIndex].seatPos)
	broadcastToAll(joinLang({translateWord[turnOrder[playerIndex].mage] or tostring(turnOrder[playerIndex].mage),"{en} gained the Prove Yourself Unit and Quest Command token.{ru} получил отряд Prove Yourself и жетон Командования задания.{zh-tw} 獲得 Prove Yourself 部隊與任務指揮標記。{zh-cn} 获得 Prove Yourself 部队与任务指挥标记。{ko}이(가) Prove Yourself 유닛과 퀘스트 지휘 토큰을 얻었습니다.{es} ganó la Unidad de Prove Yourself y la ficha de Mando de Misión.{fr} a gagné l’Unité de Prove Yourself et le jeton de Commandement de Quête.{pt-br} ganhou a Unidade de Prove Yourself e a ficha de Comando da Missão.{de} erhielt die Prove-Yourself-Einheit und den Quest-Befehlsmarker."}), positionToColor(playerIndex))
	return true
end

apocalypseQuestGiveQuestTokenToInventory=function(playerIndex, tokenGUID, reason)
	if turnOrder[playerIndex]==nil then return nil end
	local token=getObjectFromGUID(tokenGUID)
	if token==nil then
		broadcastToAll(joinLang({"{en}Quest reward: the Quest token for {ru}Награда задания: жетон задания для {zh-tw}任務獎勵：找不到 {zh-cn}任务奖励：找不到 {ko}퀘스트 보상: {es}Recompensa de Misión: no se encontró la ficha de Misión de {fr}Récompense de Quête : le jeton de Quête de {pt-br}Recompensa da Missão: a ficha de Missão de {de}Quest-Belohnung: Der Questmarker für ",tostring(reason or "this Quest"),"{en} could not be found.{ru} не найден.{zh-tw} 的任務標記。{zh-cn} 的任务标记。{ko} 퀘스트 토큰을 찾지 못했습니다.{es}.{fr} est introuvable.{pt-br} não foi encontrada.{de} wurde nicht gefunden."}), {1,0.55,0.2})
		return nil
	end
	apocalypseQuestUndoSiteToken(tokenGUID)
	local target=mineInventoryPosition(playerIndex, "Quest")
	target[3]=-33
	token.unlock()
	token.setRotationSmooth({0,180,180})
	token.setPositionSmooth(target)
	broadcastToAll(joinLang({translateWord[turnOrder[playerIndex].mage] or tostring(turnOrder[playerIndex].mage),"{en} gained the Quest token from {ru} получил жетон задания из {zh-tw} 獲得任務標記，來源：{zh-cn} 获得任务标记，来源：{ko}이(가) 퀘스트 토큰을 얻었습니다: {es} ganó la ficha de Misión de {fr} a gagné le jeton de Quête de {pt-br} ganhou a ficha de Missão de {de} erhielt den Questmarker aus ",tostring(reason or "a Quest"),"."}), positionToColor(playerIndex))
	return token, target
end

apocalypseQuestSetupDie=function()
	local die=gStates.apocalypseQuestSetupDieGUID~=nil and getObjectFromGUID(gStates.apocalypseQuestSetupDieGUID) or nil
	if die~=nil and die.type=="Dice" then return die end
	--Fresh Quest setups record this GUID when the convenience die is created. The position lookup only
	--recovers the same physical setup die if its GUID was not recorded for some reason.
	local best=nil
	local bestDistance=4
	for _, obj in pairs(getAllObjects()) do
		if obj.type=="Dice" then
			local pos=obj.getPosition()
			local distance=((pos[1]-69.00)^2)+((pos[3]-15.30)^2)
			if distance<bestDistance then best=obj bestDistance=distance end
		end
	end
	if best~=nil then gStates.apocalypseQuestSetupDieGUID=best.guid end
	return best
end

function apocalypseQuestManaDieColor(die)
	if die==nil or die.type~="Dice" then return nil end
	return ({["Red Mana"]="Red",["Blue Mana"]="Blue",["Green Mana"]="Green",["White Mana"]="White",["Gold Mana"]="Gold",["Black Mana"]="Black"})[die.getRotationValue()]
end

--Quest dice are cloned close to the card, allowed to physically settle, then randomized. Waiting for
--that first settle makes randomize() behave like a player's R press instead of being swallowed by the
--clone's initial fall. The result callback runs only after the actual throw has finished and all dice rest.
apocalypseQuestPhysicalDiceRoll=function(dieGUIDs,onSettled,onFailure)
	local guids=type(dieGUIDs)=="table" and dieGUIDs or {dieGUIDs}
	local started=false
	local finished=false
	local function failRoll()
		if finished==true then return end
		finished=true
		if onFailure~=nil then onFailure() end
	end
	local function allResting()
		for _,guid in ipairs(guids) do
			local die=getObjectFromGUID(guid)
			if die==nil then return true end
			if die.resting~=true then return false end
		end
		return true
	end
	local function throwDice()
		if started==true or finished==true then return end
		started=true
		for _,guid in ipairs(guids) do
			local die=getObjectFromGUID(guid)
			if die==nil then failRoll() return end
			die.unlock()
			die.randomize()
		end
		--resting can remain true for the first frame of a randomize impulse. Give the R-style throw time
		--to start before testing for the final resting state.
		safeWaitFrames("Quests",function()
			safeWaitCondition("Quests",function()
				if finished==true then return end
				finished=true
				if onSettled~=nil then onSettled() end
			end,allResting,10,failRoll)
		end,3)
	end
	--A freshly cloned die may still be in its creation/fall physics. Roll from rest when possible; the
	--timeout still throws it rather than ever leaving a Quest transaction stuck.
	safeWaitFrames("Quests",function() safeWaitCondition("Quests",throwDice,allResting,1.5,throwDice) end,2)
	return true
end

--Roll a real copy of the Quest setup mana die. This is shared by Quest effects that need the player
--to see the die result rather than silently choosing one with math.random().
apocalypseQuestRollVisibleManaDie=function(card,playerIndex,reason,callback,spawnPosition)
	if card==nil or turnOrder[playerIndex]==nil then return false end
	local sourceDie=apocalypseQuestSetupDie()
	if sourceDie==nil then
		broadcastToAll(joinLang({"{en}Quest roll: could not find the Quest setup mana die for {ru}Бросок задания: не удалось найти кубик маны подготовки задания для {zh-tw}任務擲骰：找不到任務設置魔力骰，任務：{zh-cn}任务掷骰：找不到任务设置魔力骰，任务：{ko}퀘스트 굴림: 퀘스트 설정 마나 주사위를 찾지 못했습니다: {es}Tirada de Misión: no se pudo encontrar el dado de maná de preparación para {fr}Jet de Quête : impossible de trouver le dé de mana de mise en place pour {pt-br}Rolagem da Missão: não foi possível encontrar o dado de mana de preparação para {de}Quest-Wurf: Der Quest-Aufbau-Manawürfel wurde nicht gefunden für ",tostring(reason or "this Quest"),"."}),{1,0.55,0.2})
		return false
	end
	local cardGUID=card.guid
	local cardPos=spawnPosition or card.getPosition()
	local rollDie=sourceDie.clone({position={cardPos[1],cardPos[2]+0.70,cardPos[3]+1.10}})
	if rollDie==nil then
		broadcastToAll(joinLang({"{en}Quest roll: could not duplicate the Quest setup mana die for {ru}Бросок задания: не удалось дублировать кубик маны подготовки задания для {zh-tw}任務擲骰：無法複製任務設置魔力骰，任務：{zh-cn}任务掷骰：无法复制任务设置魔力骰，任务：{ko}퀘스트 굴림: 퀘스트 설정 마나 주사위를 복제하지 못했습니다: {es}Tirada de Misión: no se pudo duplicar el dado de maná de preparación para {fr}Jet de Quête : impossible de dupliquer le dé de mana de mise en place pour {pt-br}Rolagem da Missão: não foi possível duplicar o dado de mana de preparação para {de}Quest-Wurf: Der Quest-Aufbau-Manawürfel konnte nicht dupliziert werden für ",tostring(reason or "this Quest"),"."}),{1,0.55,0.2})
		return false
	end
	rollDie.unlock()
	if gStates.apocalypseQuestRollDice==nil then gStates.apocalypseQuestRollDice={} end
	gStates.apocalypseQuestRollDice[rollDie.guid]=true
	QuestPrivate.apocalypseQuestInterfaceRemove(card)
	broadcastToAll(joinLang({tostring(reason or "Quest"),"{en} is rolling a mana die.{ru} бросает кубик маны.{zh-tw} 正在擲魔力骰。{zh-cn} 正在掷魔力骰。{ko}에서 마나 주사위를 굴립니다.{es} está tirando un dado de maná.{fr} lance un dé de mana.{pt-br} está rolando um dado de mana.{de} würfelt einen Manawürfel."}),positionToColor(playerIndex))
	local dieGUID=rollDie.guid
	local function clearRollDie()
		local die=getObjectFromGUID(dieGUID)
		if die~=nil then die.destruct() end
		if gStates.apocalypseQuestRollDice~=nil then gStates.apocalypseQuestRollDice[dieGUID]=nil end
	end
	local function finishRoll()
		local settledDie=getObjectFromGUID(dieGUID)
		local questCard=getObjectFromGUID(cardGUID)
		if settledDie==nil or questCard==nil then
			clearRollDie()
			if callback~=nil then callback(nil,questCard) end
			return
		end
		local rolled=apocalypseQuestManaDieColor(settledDie)
		if rolled==nil then
			broadcastToAll("{en}Quest roll: the mana die settled without a readable result; try the Quest action again.{ru}Бросок задания: кубик маны остановился без читаемого результата; повторите действие задания.{zh-tw}任務擲骰：魔力骰停下後無法讀取結果；請再次嘗試任務動作。{zh-cn}任务掷骰：魔力骰停下后无法读取结果；请再次尝试任务动作。{ko}퀘스트 굴림: 마나 주사위가 판독할 수 없는 결과로 멈췄습니다. 퀘스트 행동을 다시 시도하십시오.{es}Tirada de Misión: el dado de maná se detuvo sin un resultado legible; intenta de nuevo la acción de Misión.{fr}Jet de Quête : le dé de mana s’est arrêté sans résultat lisible ; réessayez l’action de Quête.{pt-br}Rolagem da Missão: o dado de mana parou sem um resultado legível; tente a ação da Missão novamente.{de}Quest-Wurf: Der Manawürfel kam ohne lesbares Ergebnis zum Stillstand; versuche die Quest-Aktion erneut.",{1,0.55,0.2})
			clearRollDie()
			if callback~=nil then callback(nil,questCard) end
			return
		end
		--Leave the face visible briefly before removing the temporary die and applying the result.
		safeWaitTime("Quests",function()
			clearRollDie()
			if callback~=nil then callback(rolled,getObjectFromGUID(cardGUID)) end
		end,0.8)
	end
	local function failRoll()
		clearRollDie()
		if callback~=nil then callback(nil,getObjectFromGUID(cardGUID)) end
	end
	apocalypseQuestPhysicalDiceRoll(dieGUID,finishRoll,failRoll)
	return true
end

local function apocalypseQuestCrystalDiceOffsets(count)
	if count<=1 then return {{0,1.25}} end
	if count==2 then return {{-1.05,1.25},{1.05,1.25}} end
	if count==3 then return {{-1.05,0.55},{1.05,0.55},{0,1.95}} end
	if count==4 then return {{-1.05,0.55},{1.05,0.55},{-1.05,1.95},{1.05,1.95}} end
	local offsets={}
	local columns=math.ceil(math.sqrt(count))
	local rows=math.ceil(count/columns)
	local spacing=1.05
	for index=1,count do
		local column=(index-1)%columns
		local row=math.floor((index-1)/columns)
		offsets[index]={((column-(columns-1)/2)*spacing),0.55+((rows-1-row)*1.15)}
	end
	return offsets
end

--Random Quest crystal rewards use Noble Warrior's presentation by default: clone every required
--Quest mana die, roll the whole group together, leave all faces visible briefly, then resolve them.
apocalypseQuestRollCrystalRewardDice=function(card,playerIndex,count,reason,callback)
	if card==nil or turnOrder[playerIndex]==nil or (count or 0)<1 then return false end
	local sourceDie=apocalypseQuestSetupDie()
	if sourceDie==nil then
		broadcastToAll(joinLang({"{en}Quest roll: could not find the Quest setup mana die for {ru}Бросок задания: не удалось найти кубик маны подготовки задания для {zh-tw}任務擲骰：找不到任務設置魔力骰，任務：{zh-cn}任务掷骰：找不到任务设置魔力骰，任务：{ko}퀘스트 굴림: 퀘스트 설정 마나 주사위를 찾지 못했습니다: {es}Tirada de Misión: no se pudo encontrar el dado de maná de preparación para {fr}Jet de Quête : impossible de trouver le dé de mana de mise en place pour {pt-br}Rolagem da Missão: não foi possível encontrar o dado de mana de preparação para {de}Quest-Wurf: Der Quest-Aufbau-Manawürfel wurde nicht gefunden für ",tostring(reason or "this Quest"),"."}),{1,0.55,0.2})
		return false
	end
	local cardGUID=card.guid
	local cardPos=card.getPosition()
	local offsets=apocalypseQuestCrystalDiceOffsets(count)
	local dice={}
	for index=1,count do
		local offset=offsets[index] or {0,1.25}
		local die=sourceDie.clone({position={cardPos[1]+offset[1],cardPos[2]+0.70,cardPos[3]+offset[2]}})
		if die~=nil then
			die.unlock()
			dice[#dice+1]=die.guid
			if gStates.apocalypseQuestRollDice==nil then gStates.apocalypseQuestRollDice={} end
			gStates.apocalypseQuestRollDice[die.guid]=true
		end
	end
	local function clearDice()
		for _,guid in ipairs(dice) do
			local die=getObjectFromGUID(guid)
			if die~=nil then die.destruct() end
			if gStates.apocalypseQuestRollDice~=nil then gStates.apocalypseQuestRollDice[guid]=nil end
		end
	end
	if #dice~=count then
		clearDice()
		broadcastToAll(joinLang({"{en}Quest roll: could not create every mana die for {ru}Бросок задания: не удалось создать все кубики маны для {zh-tw}任務擲骰：無法建立所有魔力骰，任務：{zh-cn}任务掷骰：无法创建所有魔力骰，任务：{ko}퀘스트 굴림: 모든 마나 주사위를 만들 수 없습니다: {es}Tirada de Misión: no se pudieron crear todos los dados de maná para {fr}Jet de Quête : impossible de créer tous les dés de mana pour {pt-br}Rolagem da Missão: não foi possível criar todos os dados de mana para {de}Quest-Wurf: Es konnten nicht alle Manawürfel erstellt werden für ",tostring(reason or "this Quest"),"."}),{1,0.55,0.2})
		return false
	end
	QuestPrivate.apocalypseQuestInterfaceRemove(card)
	broadcastToAll(joinLang({tostring(reason or "Quest"),"{en} is rolling {ru} бросает {zh-tw} 正在擲 {zh-cn} 正在掷 {ko}에서 마나 주사위 {es} está tirando {fr} lance {pt-br} está rolando {de} würfelt ",tostring(count),count==1 and "{en} mana die.{ru} кубик маны.{zh-tw} 顆魔力骰。{zh-cn} 颗魔力骰。{ko}개를 굴립니다.{es} dado de maná.{fr} dé de mana.{pt-br} dado de mana.{de} Manawürfel." or "{en} mana dice together.{ru} кубика маны вместе.{zh-tw} 顆魔力骰。{zh-cn} 颗魔力骰。{ko}개를 함께 굴립니다.{es} dados de maná juntos.{fr} dés de mana ensemble.{pt-br} dados de mana juntos.{de} Manawürfel gleichzeitig."}),positionToColor(playerIndex))

	local finished=false
	local function failRoll()
		if finished==true then return end
		finished=true
		clearDice()
		if callback~=nil then callback(false,getObjectFromGUID(cardGUID),nil) end
	end
	local function finishRoll()
		if finished==true then return end
		local results={}
		for _,guid in ipairs(dice) do
			local die=getObjectFromGUID(guid)
			if die==nil then failRoll() return end
			local color=apocalypseQuestManaDieColor(die)
			if color==nil then failRoll() return end
			results[#results+1]=color
		end
		finished=true
		safeWaitTime("Quests",function()
			clearDice()
			if callback~=nil then callback(true,getObjectFromGUID(cardGUID),results) end
		end,0.8)
	end
	apocalypseQuestPhysicalDiceRoll(dice,finishRoll,failRoll)
	return true
end

apocalypseQuestGoblinAttempt=function(playerIndex,currentOnly)
	if turnOrder[playerIndex]==nil then return nil end
	if gStates.apocalypseQuestGoblinWarrens==nil then gStates.apocalypseQuestGoblinWarrens={} end
	local mage=turnOrder[playerIndex].mage
	local record=gStates.apocalypseQuestGoblinWarrens[mage]
	if currentOnly==true and record~=nil and record.serial~=(gStates.apocalypseQuestTurnSerial or 0) then
		--The fight should normally resolve during end-turn monster cleanup. If an interrupted old attempt
		--survives into a later turn, clear only its temporary combat record; Step 1 itself is committed
		--when the player chooses 1/2/3 and is advanced when the spawned Goblins are cleaned up.
		gStates.apocalypseQuestGoblinWarrens[mage]=nil
		return nil
	end
	return record
end

apocalypseQuestGoblinAttemptReady=function(playerIndex)
	--Goblin Warrens no longer has a separate Proceed press after combat. Choosing 1/2/3 commits
	--the marker/Shield, and normal combat cleanup advances Step 1 whether the Goblins were beaten or not.
	return false
end

function apocalypseQuestGoblinRecordCleanup(enemyGUID,defeated)
	local enemyRecord=gStates.apocalypseQuestGoblinEnemies~=nil and gStates.apocalypseQuestGoblinEnemies[enemyGUID] or nil
	if enemyRecord==nil then return false end
	local warrens=gStates.apocalypseQuestGoblinWarrens
	if warrens==nil then return false end
	local record=warrens[enemyRecord.mage]
	if record==nil or record.serial~=(gStates.apocalypseQuestTurnSerial or 0) or record.resolvedStep==true then return false end
	if record.resolved==nil then record.resolved={} end
	record.resolved[enemyGUID]=defeated==true
	local resolved=0
	local allDefeated=true
	for _,guid in ipairs(record.enemies or {}) do
		local result=record.resolved[guid]
		if result~=nil then resolved=resolved+1 if result~=true then allDefeated=false end end
	end
	if (record.expected or 0)>0 and #(record.enemies or {})==record.expected and resolved==record.expected then
		record.resolvedStep=true
		record.success=allDefeated
		record.failed=not allDefeated
		local card=getObjectFromGUID("72099f")
		local playerIndex=nil
		for index,details in ipairs(turnOrder or {}) do if details.mage==enemyRecord.mage then playerIndex=index break end end
		if card~=nil and playerIndex~=nil then
			local option=QuestPrivate.apocalypseQuestChoiceOption(card,"1")
			local state,questState=QuestPrivate.apocalypseQuestProgressState(card,playerIndex,true)
			if option~=nil and state~=nil and state.step==1 then
				--The printed condition is only for the Quest point: fighting the chosen Goblins completes
				--Step 1 either way. A win earns the green-check point; a loss simply advances without it.
				if allDefeated==true then QuestPrivate.apocalypseQuestAwardStepPoint(card,playerIndex,option,state,questState) end
				QuestPrivate.apocalypseQuestAdvanceProgress(card,state,option)
				QuestPrivate.apocalypseQuestGoblinWarrensRemoveBagIfReady(card)
			end
			warrens[enemyRecord.mage]=nil
			safeWaitFrames("Quests",function()
				local live=getObjectFromGUID("72099f")
				if live~=nil then apocalypseQuestUpdateProgressButtons(live) end
			end,2)
			broadcastToAll(joinLang({translateWord[enemyRecord.mage] or tostring(enemyRecord.mage),allDefeated and "{en} defeated all Goblins and completed Goblin Warrens Step 1.{ru} победил всех гоблинов и завершил шаг 1 Goblin Warrens.{zh-tw} 擊敗所有哥布林並完成 Goblin Warrens 步驟 1。{zh-cn} 击败所有哥布林并完成 Goblin Warrens 步骤 1。{ko}이(가) 모든 고블린을 쓰러뜨리고 Goblin Warrens 1단계를 완료했습니다.{es} derrotó a todos los Goblins y completó el Paso 1 de Goblin Warrens.{fr} a vaincu tous les Gobelins et terminé l’Étape 1 de Goblin Warrens.{pt-br} derrotou todos os Goblins e concluiu a Etapa 1 de Goblin Warrens.{de} besiegte alle Goblins und schloss Schritt 1 von Goblin Warrens ab." or "{en} completed Goblin Warrens Step 1 but did not defeat all Goblins.{ru} завершил шаг 1 Goblin Warrens, но не победил всех гоблинов.{zh-tw} 完成 Goblin Warrens 步驟 1，但未擊敗所有哥布林。{zh-cn} 完成 Goblin Warrens 步骤 1，但未击败所有哥布林。{ko}이(가) Goblin Warrens 1단계를 완료했지만 모든 고블린을 쓰러뜨리지는 못했습니다.{es} completó el Paso 1 de Goblin Warrens pero no derrotó a todos los Goblins.{fr} a terminé l’Étape 1 de Goblin Warrens sans vaincre tous les Gobelins.{pt-br} concluiu a Etapa 1 de Goblin Warrens, mas não derrotou todos os Goblins.{de} schloss Schritt 1 von Goblin Warrens ab, besiegte aber nicht alle Goblins."}),positionToColor(playerIndex))
		end
	end
	return true
end

apocalypseQuestRegisterGoblin=function(enemy,playerIndex)
	if enemy==nil or turnOrder[playerIndex]==nil then return false end
	--The Warrens source is an Infinite Bag, so there is no contained-object GUID to inspect. Give each
	--fresh clone a small runtime monster record, then put the printed Quest overrides in monsterPerks.
	monsterPugs[enemy.guid]={name=enemy.getName()~="" and enemy.getName() or "Goblin",pugType="green",fame=1,attack={P={0}},armour=0}
	if gStates.monsterPerks==nil then gStates.monsterPerks={} end
	gStates.monsterPerks[enemy.guid]={attack={P={1}},armour=1,fame=0,questGoblinWarrens=true}
	if gStates.apocalypseQuestGoblinEnemies==nil then gStates.apocalypseQuestGoblinEnemies={} end
	gStates.apocalypseQuestGoblinEnemies[enemy.guid]={mage=turnOrder[playerIndex].mage,name=monsterPugs[enemy.guid].name}
	setMonsterObjectButtons(enemy,false)
	return true
end

function apocalypseQuestRestoreGoblinEnemies()
	if type(gStates.apocalypseQuestGoblinEnemies)~="table" then gStates.apocalypseQuestGoblinEnemies={} return end
	for guid,record in pairs(gStates.apocalypseQuestGoblinEnemies) do
		local enemy=getObjectFromGUID(guid)
		if enemy~=nil then
			monsterPugs[guid]={name=record.name or (enemy.getName()~="" and enemy.getName() or "Goblin"),pugType="green",fame=1,attack={P={0}},armour=0}
			if gStates.monsterPerks==nil then gStates.monsterPerks={} end
			local perks=gStates.monsterPerks[guid] or {}
			perks.attack={P={1}}
			perks.armour=1
			perks.fame=0
			perks.questGoblinWarrens=true
			gStates.monsterPerks[guid]=perks
			setMonsterObjectButtons(enemy,false)
		else
			gStates.apocalypseQuestGoblinEnemies[guid]=nil
		end
	end
end

apocalypseQuestStartGoblinWarrens=function(card,playerIndex,chosen)
	if card==nil or card.guid~="72099f" or turnOrder[playerIndex]==nil or chosen==nil or chosen<1 or chosen>3 then return false end
	if apocalypseQuestGoblinAttempt(playerIndex,true)~=nil then return false end
	local option=QuestPrivate.apocalypseQuestChoiceOption(card,"1")
	if option==nil or QuestPrivate.apocalypseQuestStarterLocationLegal(card,playerIndex,option)~=true or QuestPrivate.apocalypseQuestMarkerPlacementAvailable(card,playerIndex,option)~=true then return false end
	if gStates.apocalypseQuestGoblinWarrens==nil then gStates.apocalypseQuestGoblinWarrens={} end
	local mage=turnOrder[playerIndex].mage
	--Reserve immediately, then perform map/card setup without waiting for the offer animation. The Quest
	--marker leaves the card now, the Shield follows the card through the normal attachment move, and the
	--visible die is created directly over slot 1 where the card is already headed.
	local record={serial=gStates.apocalypseQuestTurnSerial or 0,chosen=chosen,preparing=true,rolling=false,expected=0,enemies={}}
	gStates.apocalypseQuestGoblinWarrens[mage]=record
	local function failStart(questCard,message)
		if gStates.apocalypseQuestGoblinWarrens~=nil and gStates.apocalypseQuestGoblinWarrens[mage]==record then gStates.apocalypseQuestGoblinWarrens[mage]=nil end
		if message~=nil then broadcastToAll(message,{1,0.55,0.2}) end
		if questCard~=nil then QuestPrivate.apocalypseQuestInterfaceAdd(questCard,true) end
	end
	if QuestPrivate.apocalypseQuestPlaceStepMarker(card,playerIndex,option,nil)~=true then failStart(card,"The Goblin Warrens could not place its Quest marker.") return false end
	--The map marker must leave from the Quest's current position, but the Shield belongs to the card after
	--it is promoted to offer slot 1. Enter the same planned-move lifecycle used by normal Quest Progress.
	apocalypseQuestBeginMoveAttachmentCapture(card,QuestPrivate.apocalypseQuestOfferPosition(1))
	if QuestPrivate.apocalypseQuestPositionProgressShield(card,playerIndex,option)~=true then
		apocalypseQuestEndMoveAttachmentCapture(card)
		failStart(card,"The Goblin Warrens could not place the required Quest Shield.")
		return false
	end
	apocalypseQuestEndMoveAttachmentCapture(card)
	QuestPrivate.apocalypseQuestCommitStepMarker(card,option)
	record.preparing=false
	record.rolling=true
	local started=apocalypseQuestRollVisibleManaDie(card,playerIndex,"The Goblin Warrens",function(rolled,liveCard)
		local current=apocalypseQuestGoblinAttempt(playerIndex,true)
		if liveCard==nil or current~=record then return end
		if rolled==nil then
			gStates.apocalypseQuestGoblinWarrens[mage]=nil
			QuestPrivate.apocalypseQuestInterfaceAdd(liveCard,true)
			return
		end
		local bonus=(rolled=="Red" or rolled=="Green") and 1 or (rolled=="Black" and 2 or 0)
		local count=chosen+bonus
		local bag=getObjectFromGUID("f021d8")
		if bag==nil then
			broadcastToAll("{en}The Goblin Warrens could not find its Goblin infinite bag.{ru}The Goblin Warrens не смогло найти бесконечный мешок гоблинов.{zh-tw}The Goblin Warrens 找不到哥布林無限袋。{zh-cn}The Goblin Warrens 找不到哥布林无限袋。{ko}The Goblin Warrens에서 고블린 무한 주머니를 찾지 못했습니다.{es}The Goblin Warrens no pudo encontrar su bolsa infinita de Goblins.{fr}The Goblin Warrens n’a pas pu trouver son sac infini de Gobelins.{pt-br}The Goblin Warrens não conseguiu encontrar sua bolsa infinita de Goblins.{de}The Goblin Warrens konnte seinen unendlichen Goblin-Beutel nicht finden.",{1,0.55,0.2})
			gStates.apocalypseQuestGoblinWarrens[mage]=nil
			QuestPrivate.apocalypseQuestInterfaceAdd(liveCard,true)
			return
		end
		record.rolling=false
		record.roll=rolled
		record.expected=count
		record.enemies={}
		if gStates.attackedMonsters==nil then gStates.attackedMonsters={} end
		local bagPos=bag.getPosition()
		for i=1,count do
			local target=QuestPrivate.apocalypseQuestNextCombatTarget(playerIndex)
			local enemy=target~=nil and bag.takeObject({position=target,rotation={0,180,0},smooth=true}) or nil
			if enemy~=nil and apocalypseQuestRegisterGoblin(enemy,playerIndex)==true then
				record.enemies[#record.enemies+1]=enemy.guid
				gStates.attackedMonsters[enemy.guid]={{bagPos[1],2.5,bagPos[3]},{0,180,0}}
				QuestPrivate.apocalypseQuestTrackCombatEnemy(liveCard,enemy)
			end
		end
		if #record.enemies~=count then
			broadcastToAll(joinLang({"{en}The Goblin Warrens could only create {ru}The Goblin Warrens смогло создать только {zh-tw}The Goblin Warrens 只能建立 {zh-cn}The Goblin Warrens 只能建立 {ko}The Goblin Warrens에서 고블린을 {es}The Goblin Warrens solo pudo crear {fr}The Goblin Warrens n’a pu créer que {pt-br}The Goblin Warrens só conseguiu criar {de}The Goblin Warrens konnte nur ",tostring(#record.enemies),"{en} of {ru} из {zh-tw}／{zh-cn}／{ko}/{es} de {fr} sur {pt-br} de {de} von ",tostring(count),"{en} Goblins; this attempt cannot be completed.{ru} гоблинов; эту попытку нельзя завершить.{zh-tw} 個哥布林；此次嘗試無法完成。{zh-cn} 个哥布林；此次尝试无法完成。{ko}마리만 생성했습니다. 이 시도는 완료할 수 없습니다.{es} Goblins; este intento no puede completarse.{fr} Gobelins ; cette tentative ne peut pas être terminée.{pt-br} Goblins; esta tentativa não pode ser concluída.{de} Goblins erzeugen; dieser Versuch kann nicht abgeschlossen werden."}),{1,0.55,0.2})
		else
			combatCameraFocus(playerIndex)
			broadcastToAll(joinLang({translateWord[mage] or tostring(mage),"{en} chose {ru} выбрал {zh-tw} 選擇 {zh-cn} 选择 {ko}이(가) {es} eligió {fr} a choisi {pt-br} escolheu {de} wählte ",tostring(chosen),"{en}, rolled {ru}, выбросил {zh-tw}，擲出 {zh-cn}，掷出 {ko}을(를) 선택하고 {es}, sacó {fr}, a obtenu {pt-br}, rolou {de}, würfelte ",tostring(rolled),"{en}, and must fight {ru} и должен сразиться с {zh-tw}，必須與 {zh-cn}，必须与 {ko}을(를) 굴려 고블린 {es}, y debe luchar contra {fr}, et doit combattre {pt-br}, e deve lutar contra {de} und muss gegen ",tostring(count),count==1 and "{en} Goblin.{ru} гоблином.{zh-tw} 個哥布林戰鬥。{zh-cn} 个哥布林战斗。{ko}마리와 싸워야 합니다.{es} Goblin.{fr} Gobelin.{pt-br} Goblin.{de} Goblin kämpfen." or "{en} Goblins.{ru} гоблинами.{zh-tw} 個哥布林戰鬥。{zh-cn} 个哥布林战斗。{ko}마리와 싸워야 합니다.{es} Goblins.{fr} Gobelins.{pt-br} Goblins.{de} Goblins kämpfen."}),positionToColor(playerIndex))
		end
		QuestPrivate.apocalypseQuestInterfaceAdd(liveCard,true)
	end,QuestPrivate.apocalypseQuestOfferPosition(1))
	if started~=true then failStart(card,"The Goblin Warrens could not start its Quest die roll.") return false end
	--As with Rich Merchant, let the roll result own the next UI rebuild while the offer itself moves now.
	QuestPrivate.apocalypseQuestOfferMoveToLeft(card,function() end)
	return true
end

apocalypseQuestResolveRichMerchantRoll=function(card,playerIndex,roll)
	if card==nil or turnOrder[playerIndex]==nil or roll==nil then return false end
	if gStates.apocalypseQuestRichMerchantRoll==nil then gStates.apocalypseQuestRichMerchantRoll={} end
	gStates.apocalypseQuestRichMerchantRoll[card.guid]={mage=turnOrder[playerIndex].mage,result=roll}
	if mineCrystalBagKey[roll]~=nil then
		apocalypseQuestGiveCrystal(playerIndex,roll,nil,"A Rich Merchant")
	elseif roll=="Gold" then
		turnOrder[playerIndex].fameGain=(turnOrder[playerIndex].fameGain or 0)+1
		mainUIUpdate("Rich Merchant Fame")
	end
	if roll=="Black" then
		if gStates.apocalypseQuestRichMerchantHidden==nil then gStates.apocalypseQuestRichMerchantHidden={} end
		gStates.apocalypseQuestRichMerchantHidden[card.guid]={mage=turnOrder[playerIndex].mage,spawned=false}
		broadcastToAll("{en}A Rich Merchant rolled Black; Step 2 will attack at the start of this Hero's next turn.{ru}A Rich Merchant выбросил чёрный; шаг 2 атакует в начале следующего хода этого Героя.{zh-tw}A Rich Merchant 擲出黑色；步驟 2 將在此英雄下個回合開始時發動攻擊。{zh-cn}A Rich Merchant 掷出黑色；步骤 2 将在此英雄下个回合开始时发动攻击。{ko}A Rich Merchant가 검정을 굴렸습니다. 2단계는 이 영웅의 다음 턴 시작에 공격합니다.{es}A Rich Merchant sacó Negro; el Paso 2 atacará al comienzo del próximo turno de este Héroe.{fr}A Rich Merchant a obtenu Noir ; l’Étape 2 attaquera au début du prochain tour de ce Héros.{pt-br}A Rich Merchant rolou Preto; a Etapa 2 atacará no início do próximo turno deste Herói.{de}A Rich Merchant würfelte Schwarz; Schritt 2 greift zu Beginn des nächsten Zuges dieses Helden an.",positionToColor(playerIndex))
	else
		broadcastToAll(joinLang({"{en}A Rich Merchant rolled {ru}A Rich Merchant выбросил {zh-tw}A Rich Merchant 擲出 {zh-cn}A Rich Merchant 掷出 {ko}A Rich Merchant가 {es}A Rich Merchant sacó {fr}A Rich Merchant a obtenu {pt-br}A Rich Merchant rolou {de}A Rich Merchant würfelte ",translateWord[roll] or tostring(roll),"{en}. Press Complete to finish the Quest.{ru}. Нажмите Complete, чтобы завершить задание.{zh-tw}。按「完成」結束任務。{zh-cn}。按“完成”结束任务。{ko}. 퀘스트를 끝내려면 완료를 누르십시오.{es}. Pulsa Completar para terminar la Misión.{fr}. Appuyez sur Terminer pour achever la Quête.{pt-br}. Pressione Concluir para terminar a Missão.{de}. Drücke Abschließen, um die Quest zu beenden."}),positionToColor(playerIndex))
	end
	return true
end

apocalypseQuestResolveHerbalistReward=function(card, playerIndex, rolled, crystalGUID, crystalColor)
	if card==nil or turnOrder[playerIndex]==nil then return false end
	local token=getObjectFromGUID("fb29ad")
	if token==nil then
		broadcastToAll("{en}Quest reward: The Eager Herbalist Quest token could not be found.{ru}Награда задания: жетон задания The Eager Herbalist не найден.{zh-tw}任務獎勵：找不到 The Eager Herbalist 任務標記。{zh-cn}任务奖励：找不到 The Eager Herbalist 任务标记。{ko}퀘스트 보상: The Eager Herbalist 퀘스트 토큰을 찾지 못했습니다.{es}Recompensa de Misión: no se encontró la ficha de Misión de The Eager Herbalist.{fr}Récompense de Quête : le jeton de Quête The Eager Herbalist est introuvable.{pt-br}Recompensa da Missão: a ficha de Missão de The Eager Herbalist não foi encontrada.{de}Quest-Belohnung: Der Questmarker von The Eager Herbalist wurde nicht gefunden.", {1,0.55,0.2})
		return false
	end
	local target=mineInventoryPosition(playerIndex, "Quest")
	target[3]=-33
	token.unlock()
	token.setRotationSmooth({0,180,180})
	token.setPositionSmooth(target)
	--Transfer the Step 2 crystal only after the visible die has finished rolling. Keep the original crystal
	--on the left half and any different basic crystal rolled at the end on the right half.
	local crystal=crystalGUID~=nil and getObjectFromGUID(crystalGUID) or nil
	if crystal~=nil then
		crystal.unlock()
		crystal.setPositionSmooth({target[1]-0.60,target[2]+0.36,target[3]})
	else
		broadcastToAll("{en}Quest reward: The Eager Herbalist had no basic crystal on the card to place on its token.{ru}Награда задания: на карте The Eager Herbalist нет базового кристалла для размещения на жетоне.{zh-tw}任務獎勵：The Eager Herbalist 牌上沒有可放到標記上的基本水晶。{zh-cn}任务奖励：The Eager Herbalist 牌上没有可放到标记上的基本水晶。{ko}퀘스트 보상: The Eager Herbalist 카드에 토큰 위에 놓을 기본 크리스털이 없습니다.{es}Recompensa de Misión: The Eager Herbalist no tenía un cristal básico en la carta para colocar en su ficha.{fr}Récompense de Quête : The Eager Herbalist n’avait aucun cristal de base sur la carte à placer sur son jeton.{pt-br}Recompensa da Missão: The Eager Herbalist não tinha cristal básico na carta para colocar em sua ficha.{de}Quest-Belohnung: Auf der Karte von The Eager Herbalist lag kein Basiskristall, der auf den Marker gelegt werden konnte.", {1,0.55,0.2})
	end
	if mineCrystalBagKey[rolled]~=nil and rolled~=crystalColor then
		apocalypseQuestPlaceCrystalAt({target[1]+0.60,target[2]+0.36,target[3]},rolled,"The Eager Herbalist")
		broadcastToAll(joinLang({"{en}The Eager Herbalist rolled {ru}The Eager Herbalist выбросил {zh-tw}The Eager Herbalist 擲出 {zh-cn}The Eager Herbalist 掷出 {ko}The Eager Herbalist가 {es}The Eager Herbalist sacó {fr}The Eager Herbalist a obtenu {pt-br}The Eager Herbalist rolou {de}The Eager Herbalist würfelte ",translateWord[rolled] or rolled,"{en}; a second crystal was added to the reward token.{ru}; второй кристалл добавлен на жетон награды.{zh-tw}；第二顆水晶已加入獎勵標記。{zh-cn}；第二颗水晶已加入奖励标记。{ko}. 두 번째 크리스털을 보상 토큰에 추가했습니다.{es}; se añadió un segundo cristal a la ficha de recompensa.{fr} ; un second cristal a été ajouté au jeton de récompense.{pt-br}; um segundo cristal foi adicionado à ficha de recompensa.{de}; ein zweiter Kristall wurde dem Belohnungsmarker hinzugefügt."}),positionToColor(playerIndex))
	else
		broadcastToAll(joinLang({"{en}The Eager Herbalist rolled {ru}The Eager Herbalist выбросил {zh-tw}The Eager Herbalist 擲出 {zh-cn}The Eager Herbalist 掷出 {ko}The Eager Herbalist가 {es}The Eager Herbalist sacó {fr}The Eager Herbalist a obtenu {pt-br}The Eager Herbalist rolou {de}The Eager Herbalist würfelte ",translateWord[rolled] or tostring(rolled),"{en}; no second crystal was added.{ru}; второй кристалл не добавлен.{zh-tw}；未加入第二顆水晶。{zh-cn}；未加入第二颗水晶。{ko}. 두 번째 크리스털은 추가되지 않았습니다.{es}; no se añadió un segundo cristal.{fr} ; aucun second cristal n’a été ajouté.{pt-br}; nenhum segundo cristal foi adicionado.{de}; es wurde kein zweiter Kristall hinzugefügt."}),positionToColor(playerIndex))
	end
	return true
end

apocalypseQuestGiveHerbalistReward=function(card, playerIndex, callback)
	if card==nil or turnOrder[playerIndex]==nil then return false end
	if gStates.apocalypseQuestHerbalistRolls==nil then gStates.apocalypseQuestHerbalistRolls={} end
	if gStates.apocalypseQuestHerbalistRolls[card.guid]~=nil then return true end
	local token=getObjectFromGUID("fb29ad")
	if token==nil then
		broadcastToAll("{en}Quest reward: The Eager Herbalist Quest token could not be found.{ru}Награда задания: жетон задания The Eager Herbalist не найден.{zh-tw}任務獎勵：找不到 The Eager Herbalist 任務標記。{zh-cn}任务奖励：找不到 The Eager Herbalist 任务标记。{ko}퀘스트 보상: The Eager Herbalist 퀘스트 토큰을 찾지 못했습니다.{es}Recompensa de Misión: no se encontró la ficha de Misión de The Eager Herbalist.{fr}Récompense de Quête : le jeton de Quête The Eager Herbalist est introuvable.{pt-br}Recompensa da Missão: a ficha de Missão de The Eager Herbalist não foi encontrada.{de}Quest-Belohnung: Der Questmarker von The Eager Herbalist wurde nicht gefunden.", {1,0.55,0.2})
		return false
	end
	local crystal=nil
	local crystalColor=nil
	for _, obj in ipairs(apocalypseQuestObjectsOnCard(card)) do
		local color=apocalypseQuestBasicCrystalColor(obj)
		if color~=nil then crystal=obj crystalColor=color break end
	end
	local sourceDie=apocalypseQuestSetupDie()
	if sourceDie==nil then
		broadcastToAll("{en}Quest reward: The Eager Herbalist could not find the Quest setup mana die.{ru}Награда задания: The Eager Herbalist не смог найти кубик маны подготовки задания.{zh-tw}任務獎勵：The Eager Herbalist 找不到任務設置魔力骰。{zh-cn}任务奖励：The Eager Herbalist 找不到任务设置魔力骰。{ko}퀘스트 보상: The Eager Herbalist에서 퀘스트 설정 마나 주사위를 찾지 못했습니다.{es}Recompensa de Misión: The Eager Herbalist no pudo encontrar el dado de maná de preparación de la Misión.{fr}Récompense de Quête : The Eager Herbalist n’a pas pu trouver le dé de mana de mise en place de la Quête.{pt-br}Recompensa da Missão: The Eager Herbalist não conseguiu encontrar o dado de mana de preparação da Missão.{de}Quest-Belohnung: The Eager Herbalist konnte den Quest-Aufbau-Manawürfel nicht finden.", {1,0.55,0.2})
		return false
	end
	local cardGUID=card.guid
	local player=playerIndex
	local crystalGUID=crystal~=nil and crystal.guid or nil
	local cardPos=card.getPosition()
	--Clone the visible Quest setup die above the top edge of the card. Dice randomize uses TTS physics,
	--so this visibly tosses the copy rather than choosing a virtual random result.
	local rollDie=sourceDie.clone({position={cardPos[1],cardPos[2]+0.70,cardPos[3]+1.10}})
	if rollDie==nil then
		broadcastToAll("{en}Quest reward: The Eager Herbalist could not duplicate the Quest setup mana die.{ru}Награда задания: The Eager Herbalist не смог дублировать кубик маны подготовки задания.{zh-tw}任務獎勵：The Eager Herbalist 無法複製任務設置魔力骰。{zh-cn}任务奖励：The Eager Herbalist 无法复制任务设置魔力骰。{ko}퀘스트 보상: The Eager Herbalist에서 퀘스트 설정 마나 주사위를 복제하지 못했습니다.{es}Recompensa de Misión: The Eager Herbalist no pudo duplicar el dado de maná de preparación de la Misión.{fr}Récompense de Quête : The Eager Herbalist n’a pas pu dupliquer le dé de mana de mise en place de la Quête.{pt-br}Recompensa da Missão: The Eager Herbalist não conseguiu duplicar o dado de mana de preparação da Missão.{de}Quest-Belohnung: The Eager Herbalist konnte den Quest-Aufbau-Manawürfel nicht duplizieren.", {1,0.55,0.2})
		return false
	end
	rollDie.unlock()
	if gStates.apocalypseQuestRollDice==nil then gStates.apocalypseQuestRollDice={} end
	gStates.apocalypseQuestRollDice[rollDie.guid]=true
	gStates.apocalypseQuestHerbalistRolls[cardGUID]={dieGUID=rollDie.guid,player=player}
	QuestPrivate.apocalypseQuestInterfaceRemove(card)
	broadcastToAll("{en}The Eager Herbalist is rolling the Quest mana die for its second crystal.{ru}The Eager Herbalist бросает кубик маны задания для второго кристалла.{zh-tw}The Eager Herbalist 正在為第二顆水晶擲任務魔力骰。{zh-cn}The Eager Herbalist 正在为第二颗水晶掷任务魔力骰。{ko}The Eager Herbalist가 두 번째 크리스털을 위해 퀘스트 마나 주사위를 굴립니다.{es}The Eager Herbalist está tirando el dado de maná de Misión para su segundo cristal.{fr}The Eager Herbalist lance le dé de mana de Quête pour son second cristal.{pt-br}The Eager Herbalist está rolando o dado de mana da Missão para seu segundo cristal.{de}The Eager Herbalist würfelt den Quest-Manawürfel für seinen zweiten Kristall.",positionToColor(player))
	local dieGUID=rollDie.guid
	local function clearHerbalistRoll()
		local die=getObjectFromGUID(dieGUID)
		if die~=nil then die.destruct() end
		gStates.apocalypseQuestHerbalistRolls[cardGUID]=nil
		if gStates.apocalypseQuestRollDice~=nil then gStates.apocalypseQuestRollDice[dieGUID]=nil end
	end
	local function failRoll()
		clearHerbalistRoll()
		local questCard=getObjectFromGUID(cardGUID)
		if questCard~=nil then QuestPrivate.apocalypseQuestInterfaceAdd(questCard,true) end
	end
	local function finishRoll()
		local settledDie=getObjectFromGUID(dieGUID)
		local questCard=getObjectFromGUID(cardGUID)
		if settledDie==nil or questCard==nil then failRoll() return end
		local rolled=apocalypseQuestManaDieColor(settledDie)
		if rolled==nil then
			broadcastToAll("{en}Quest reward: The Eager Herbalist mana die settled without a readable result; press Complete to roll again.{ru}Награда задания: кубик маны The Eager Herbalist остановился без читаемого результата; нажмите Complete, чтобы бросить снова.{zh-tw}任務獎勵：The Eager Herbalist 的魔力骰停下後無法讀取結果；按「完成」再次擲骰。{zh-cn}任务奖励：The Eager Herbalist 的魔力骰停下后无法读取结果；按“完成”再次掷骰。{ko}퀘스트 보상: The Eager Herbalist 마나 주사위 결과를 읽을 수 없습니다. 완료를 눌러 다시 굴리십시오.{es}Recompensa de Misión: el dado de maná de The Eager Herbalist se detuvo sin resultado legible; pulsa Completar para volver a tirar.{fr}Récompense de Quête : le dé de mana de The Eager Herbalist s’est arrêté sans résultat lisible ; appuyez sur Terminer pour relancer.{pt-br}Recompensa da Missão: o dado de mana de The Eager Herbalist parou sem resultado legível; pressione Concluir para rolar novamente.{de}Quest-Belohnung: Der Manawürfel von The Eager Herbalist kam ohne lesbares Ergebnis zum Stillstand; drücke Abschließen, um erneut zu würfeln.",{1,0.55,0.2})
			failRoll()
			return
		end
		--Leave the settled face visible briefly before removing the temporary copy and moving the reward.
		safeWaitTime("Quests",function()
			clearHerbalistRoll()
			local liveCard=getObjectFromGUID(cardGUID)
			local success=liveCard~=nil and apocalypseQuestResolveHerbalistReward(liveCard,player,rolled,crystalGUID,crystalColor)==true
			if callback~=nil then callback(success,liveCard,rolled) end
		end,0.8)
	end
	apocalypseQuestPhysicalDiceRoll(dieGUID,finishRoll,failRoll)
	return true
end

apocalypseQuestGiveBardReward=function(card, playerIndex)
	if card==nil or turnOrder[playerIndex]==nil then return false end
	local fameByColor={Green=1, Blue=2, Red=3}
	local fame=0
	local crystalColor=nil
	for _, obj in ipairs(apocalypseQuestObjectsOnCard(card)) do
		local color=apocalypseQuestBasicCrystalColor(obj)
		if fameByColor[color]~=nil then
			crystalColor=color
			fame=fameByColor[color]
			break
		end
	end
	apocalypseQuestGainReputation(playerIndex,"The Admiring Bard")
	if fame>0 then
		turnOrder[playerIndex].fameGain=(turnOrder[playerIndex].fameGain or 0)+fame
		broadcastToAll(joinLang({"{en}Quest reward: {ru}Награда задания: {zh-tw}任務獎勵：{zh-cn}任务奖励：{ko}퀘스트 보상: {es}Recompensa de Misión: {fr}Récompense de Quête : {pt-br}Recompensa da Missão: {de}Quest-Belohnung: ",translateWord[turnOrder[playerIndex].mage] or tostring(turnOrder[playerIndex].mage),"{en} gains {ru} получает {zh-tw} 從 The Admiring Bard 的 {zh-cn} 从 The Admiring Bard 的 {ko}이(가) The Admiring Bard의 {es} gana {fr} gagne {pt-br} ganha {de} erhält ",tostring(fame),"{en} Fame from The Admiring Bard's {ru} Славы от кристалла The Admiring Bard: {zh-tw}{zh-cn}{ko} 크리스털에서 명성 {es} de Fama por el cristal {fr} de Renommée grâce au cristal {pt-br} de Fama pelo cristal {de} Ruhm durch den ",translateWord[crystalColor] or tostring(crystalColor),"{en} crystal.{ru}.{zh-tw} 水晶獲得聲望值。{zh-cn} 水晶获得声望值。{ko}을(를) 얻습니다.{es} de The Admiring Bard.{fr} de The Admiring Bard.{pt-br} de The Admiring Bard.{de}-Kristall von The Admiring Bard."}), positionToColor(playerIndex))
		mainUIUpdate("Quest Fame reward")
	else
		broadcastToAll("{en}Quest reward: The Admiring Bard had no Green, Blue or Red crystal on the card, so no Fame was gained.{ru}Награда задания: на карте The Admiring Bard нет зелёного, синего или красного кристалла, поэтому Слава не получена.{zh-tw}任務獎勵：The Admiring Bard 牌上沒有綠色、藍色或紅色水晶，因此沒有獲得聲望值。{zh-cn}任务奖励：The Admiring Bard 牌上没有绿色、蓝色或红色水晶，因此没有获得声望值。{ko}퀘스트 보상: The Admiring Bard 카드에 녹색, 파란색 또는 빨간색 크리스털이 없어 명성을 얻지 못했습니다.{es}Recompensa de Misión: The Admiring Bard no tenía cristal Verde, Azul ni Rojo en la carta, por lo que no se ganó Fama.{fr}Récompense de Quête : The Admiring Bard n’avait aucun cristal Vert, Bleu ou Rouge sur la carte ; aucune Renommée n’a donc été gagnée.{pt-br}Recompensa da Missão: The Admiring Bard não tinha cristal Verde, Azul ou Vermelho na carta, então nenhuma Fama foi ganha.{de}Quest-Belohnung: Auf der Karte von The Admiring Bard lag kein grüner, blauer oder roter Kristall; daher wurde kein Ruhm erhalten.", {1,0.55,0.2})
	end
	return true
end

apocalypseQuestFlipSiteToken=function(tokenGUID)
	local token=getObjectFromGUID(tokenGUID)
	if token==nil then
		broadcastToAll("{en}Quest completion: the permanent-site Quest token could not be found.{ru}Завершение задания: жетон задания постоянного места не найден.{zh-tw}任務完成：找不到永久地點任務標記。{zh-cn}任务完成：找不到永久地点任务标记。{ko}퀘스트 완료: 영구 장소 퀘스트 토큰을 찾지 못했습니다.{es}Finalización de Misión: no se encontró la ficha de Misión del lugar permanente.{fr}Fin de Quête : le jeton de Quête du site permanent est introuvable.{pt-br}Conclusão da Missão: a ficha de Missão do local permanente não foi encontrada.{de}Quest-Abschluss: Der Questmarker des permanenten Ortes wurde nicht gefunden.", {1,0.55,0.2})
		return false
	end
	token.unlock()
	token.setRotationSmooth({0,180,180})
	local tokenGUID=token.guid
	safeWaitCondition("Quests",function()
		local live=getObjectFromGUID(tokenGUID)
		if live~=nil then apocalypseQuestSiteTokenDropped(live) end
	end,function()
		local live=getObjectFromGUID(tokenGUID)
		return live==nil or live.resting
	end,2)
	return true
end

apocalypseQuestPlaceRandomCrystalOnShield=function(card, playerIndex)
	local shield=QuestPrivate.apocalypseQuestPlayerShield(card, playerIndex)
	if shield==nil then return false end
	local color=apocalypseQuestRollManaDie()
	if mineCrystalBagKey[color]~=nil then
		local bag=getObjectFromGUID(GUID.bag.mana[mineCrystalBagKey[color]])
		if bag~=nil and bag.getQuantity()~=0 then
			local pos=apocalypseQuestMoveAttachmentTarget(card,shield) or apocalypseQuestPlannedWorldPosition(card,shield.getPosition())
			local target={pos[1],pos[2]+0.34,pos[3]}
			local crystal=takeManaCrystal(bag,{position=target,smooth=false})
			apocalypseQuestRegisterMoveAttachment(card,crystal,target)
			broadcastToAll(joinLang({"{en}The Child Seer rolled {ru}The Child Seer выбросил {zh-tw}The Child Seer 擲出 {zh-cn}The Child Seer 掷出 {ko}The Child Seer가 {es}The Child Seer sacó {fr}The Child Seer a obtenu {pt-br}The Child Seer rolou {de}The Child Seer würfelte ",translateWord[color] or color,"{en}; the matching mana token was placed on the Quest Shield.{ru}; соответствующий жетон маны помещён на Щит задания.{zh-tw}；相符的魔力標記已放到任務盾牌上。{zh-cn}；相符的魔力标记已放到任务盾牌上。{ko}. 일치하는 마나 토큰을 퀘스트 방패 위에 놓았습니다.{es}; la ficha de maná correspondiente se colocó sobre el Escudo de Misión.{fr} ; le jeton de mana correspondant a été placé sur le Bouclier de Quête.{pt-br}; a ficha de mana correspondente foi colocada no Escudo da Missão.{de}; der passende Manamarker wurde auf den Quest-Schild gelegt."}),positionToColor(playerIndex))
			return true
		end
	end
	broadcastToAll(joinLang({"{en}The Child Seer rolled {ru}The Child Seer выбросил {zh-tw}The Child Seer 擲出 {zh-cn}The Child Seer 掷出 {ko}The Child Seer가 {es}The Child Seer sacó {fr}The Child Seer a obtenu {pt-br}The Child Seer rolou {de}The Child Seer würfelte ",translateWord[color] or tostring(color),"{en}. Place the matching mana token on your Quest Shield manually.{ru}. Вручную поместите соответствующий жетон маны на свой Щит задания.{zh-tw}。請手動將相符的魔力標記放到你的任務盾牌上。{zh-cn}。请手动将相符的魔力标记放到你的任务盾牌上。{ko}. 일치하는 마나 토큰을 퀘스트 방패 위에 수동으로 놓으십시오.{es}. Coloca manualmente la ficha de maná correspondiente sobre tu Escudo de Misión.{fr}. Placez manuellement le jeton de mana correspondant sur votre Bouclier de Quête.{pt-br}. Coloque manualmente a ficha de mana correspondente em seu Escudo da Missão.{de}. Lege den passenden Manamarker manuell auf deinen Quest-Schild."}),positionToColor(playerIndex))
	return true
end

apocalypseQuestBeginCrystalChoice=function(card, playerIndex)
	local colors={}
	for _, color in ipairs({"Red","Blue","Green","White"}) do
		local bag=getObjectFromGUID(GUID.bag.mana[mineCrystalBagKey[color]])
		if mineCrystalCount(playerIndex,color)<3 and bag~=nil and bag.getQuantity()~=0 then colors[#colors+1]=color end
	end
	if #colors==0 then
		broadcastToAll("{en}Quest reward: no basic crystal can be gained; the Inventory/supply has no available color.{ru}Награда задания: базовый кристалл получить нельзя; в Инвентаре/запасе нет доступного цвета.{zh-tw}任務獎勵：無法獲得基本水晶；庫存／供應區沒有可用顏色。{zh-cn}任务奖励：无法获得基本水晶；库存／供应区没有可用颜色。{ko}퀘스트 보상: 기본 크리스털을 얻을 수 없습니다. 인벤토리/공급처에 가능한 색이 없습니다.{es}Recompensa de Misión: no se puede ganar ningún cristal básico; el Inventario/reserva no tiene ningún color disponible.{fr}Récompense de Quête : aucun cristal de base ne peut être gagné ; aucune couleur n’est disponible dans l’Inventaire/la réserve.{pt-br}Recompensa da Missão: nenhum cristal básico pode ser ganho; o Inventário/reserva não tem cor disponível.{de}Quest-Belohnung: Es kann kein Basiskristall erhalten werden; im Inventar/Vorrat ist keine Farbe verfügbar.", positionToColor(playerIndex))
		return false
	end
	gStates.mineClaimPending={source="Quest", playerIndex=playerIndex, colors=colors, questCardGUID=card.guid}
	refreshMineClaimPanel()
	return true
end

apocalypseQuestRollManaDie=function()
	local colors={"Red","Blue","Green","White","Gold","Black"}
	return colors[math.random(1,#colors)]
end

apocalypseQuestPlaceCrystalAt=function(position,color,reason)
	if position==nil or mineCrystalBagKey[color]==nil then return nil end
	local bag=getObjectFromGUID(GUID.bag.mana[mineCrystalBagKey[color]])
	if bag==nil or bag.getQuantity()==0 then
		broadcastToAll(joinLang({"{en}Quest effect: no {ru}Эффект задания: нет доступного кристалла маны {zh-tw}任務效果：沒有可用的 {zh-cn}任务效果：没有可用的 {ko}퀘스트 효과: 사용할 수 있는 {es}Efecto de Misión: no hay cristal de maná {fr}Effet de Quête : aucun cristal de mana {pt-br}Efeito da Missão: não há cristal de mana {de}Quest-Effekt: Es ist kein ",translateWord[color] or tostring(color),"{en} mana crystal is available for {ru} для {zh-tw} 魔力水晶供 {zh-cn} 魔力水晶供 {ko} 마나 크리스털이 없습니다: {es} disponible para {fr} disponible pour {pt-br} disponível para {de}-Manakristall verfügbar für ",tostring(reason or "this Quest"),"."}), {1,0.55,0.2})
		return nil
	end
	return takeManaCrystal(bag,{position=position,smooth=true})
end

apocalypseQuestCardCrystalColor=function(card)
	for _, obj in ipairs(apocalypseQuestObjectsOnCard(card)) do
		local color=apocalypseQuestBasicCrystalColor(obj)
		if color~=nil then return color end
	end
	return nil
end

apocalypseQuestCardManaColor=function(card)
	for _, obj in ipairs(apocalypseQuestObjectsOnCard(card)) do
		local color=apocalypseQuestManaTokenColor(obj)
		if color~=nil then return color end
	end
	return nil
end

apocalypseQuestPlayerCombatEnemies=function(playerIndex, faceUpOnly)
	local found={}
	local details=turnOrder[playerIndex]
	if details==nil then return found end
	for _, zoneGUID in ipairs({playerPlayAreas[details.seatPos],playerUnitAreas[details.seatPos]}) do
		local zone=zoneGUID~=nil and getObjectFromGUID(zoneGUID) or nil
		if zone~=nil then
			for _, obj in pairs(zone.getObjects()) do
				if monsterPugs[obj.guid]~=nil and (faceUpOnly~=true or obj.is_face_down==false) then found[#found+1]=obj end
			end
		end
	end
	return found
end

apocalypseQuestCursedMarkHolder=function(card,playerIndex)
	if card==nil or turnOrder[playerIndex]==nil then return end
	if gStates.apocalypseQuestCursedHistory==nil then gStates.apocalypseQuestCursedHistory={} end
	if gStates.apocalypseQuestCursedHistory[card.guid]==nil then gStates.apocalypseQuestCursedHistory[card.guid]={} end
	gStates.apocalypseQuestCursedHistory[card.guid][turnOrder[playerIndex].mage]=true
end

apocalypseQuestCursedTargetEligible=function(card,playerIndex,targetIndex,allowTargetShield,hexes,mapObjects,source)
	local details=turnOrder[targetIndex]
	if card==nil or targetIndex==playerIndex or details==nil or details.mage==nil or details.mage=="nobody" or details.mage==gStates.positionMageKnight[5] or details.dropoutState~=nil then return false end
	local history=gStates.apocalypseQuestCursedHistory~=nil and gStates.apocalypseQuestCursedHistory[card.guid] or nil
	if history~=nil and history[details.mage]==true then return false end
	if allowTargetShield~=true and QuestPrivate.apocalypseQuestPlayerShield(card,targetIndex)~=nil then return false end
	if hexes==nil then hexes,mapObjects=QuestPrivate.apocalypseQuestMapHexes() end
	source=source or apocalypseQuestPlayerHex(hexes,mapObjects,playerIndex)
	local target=source~=nil and apocalypseQuestPlayerHex(hexes,mapObjects,targetIndex) or nil
	return target~=nil and (runtimeMapHexKey(source)==runtimeMapHexKey(target) or runtimeMapHexesAdjacent(source,target)==true)
end

apocalypseQuestCursedTargetIndex=function(card,playerIndex)
	if card==nil then return nil end
	local hexes,mapObjects=QuestPrivate.apocalypseQuestMapHexes()
	local source=apocalypseQuestPlayerHex(hexes,mapObjects,playerIndex)
	if source==nil then return nil end
	local chosen=nil
	for _, obj in ipairs(apocalypseQuestObjectsOnCard(card)) do
		if obj.getName()=="Shield" then
			local owner=obj.getDescription()
			for index, details in ipairs(turnOrder) do
				if details.mage==owner and apocalypseQuestCursedTargetEligible(card,playerIndex,index,true,hexes,mapObjects,source)==true then
					if chosen~=nil and chosen~=index then return nil end
					chosen=index
					break
				end
			end
		end
	end
	return chosen
end

apocalypseQuestCursedEligibleTargets=function(card,playerIndex)
	local result={}
	local hexes,mapObjects=QuestPrivate.apocalypseQuestMapHexes()
	local source=apocalypseQuestPlayerHex(hexes,mapObjects,playerIndex)
	if source==nil then return result end
	for index, _ in ipairs(turnOrder) do
		if apocalypseQuestCursedTargetEligible(card,playerIndex,index,false,hexes,mapObjects,source)==true then result[#result+1]=index end
	end
	return result
end

apocalypseQuestCursedAutoShield=function(card,playerIndex,targetIndex)
	local sourceShield=QuestPrivate.apocalypseQuestPlayerShield(card,playerIndex)
	if sourceShield==nil or targetIndex==nil then return false end
	--Cursed is the Independent-Quest exception: each new holder covers the previous holder's Shield.
	--Use the source Shield's planned destination if the offer is already moving there.
	local sourcePos=apocalypseQuestMoveAttachmentTarget(card,sourceShield) or apocalypseQuestPlannedWorldPosition(card,sourceShield.getPosition())
	local shield=QuestPrivate.apocalypseQuestPlayerShield(card,targetIndex)
	local target=QuestPrivate.apocalypseQuestRaisedPiecePosition(sourcePos)
	if shield==nil then
		shield=QuestPrivate.apocalypseQuestTakePlayerShield(targetIndex,sourcePos)
	elseif shield.guid~=sourceShield.guid then
		shield.unlock()
		shield.setPositionSmooth(target)
	end
	apocalypseQuestRegisterMoveAttachment(card,shield,target)
	return shield~=nil
end

--Only exceptional legality/failure behavior lives in handlers; ordinary combat readiness comes from combatSteps above.
apocalypseQuestHandlers["8939c0"].specialLegal=function(card,playerIndex,option)
	local key=tostring(option.key)
	local branch=gStates.apocalypseQuestDirectBranch~=nil and gStates.apocalypseQuestDirectBranch[card.guid] or nil
	if branch==nil and key=="1b" then return true,true end
	if branch~=nil then
		if key~=branch then return true,false end
		if key=="1b" then return true,QuestPrivate.apocalypseQuestCombatStartedThisTurn(card,1) end
	end
	return false
end
apocalypseQuestHandlers["82a935"].specialLegal=function(card,playerIndex,option)
	local key=tostring(option.key)
	local branch=gStates.apocalypseQuestDirectBranch~=nil and gStates.apocalypseQuestDirectBranch[card.guid] or nil
	if branch==nil and key=="2c" then return true,true end
	if branch~=nil then
		if key~=branch then return true,false end
		if key=="2c" then return true,QuestPrivate.apocalypseQuestCombatStartedThisTurn(card,2) end
	end
	return false
end
apocalypseQuestHandlers["ce70fb"].specialLegal=function(card,playerIndex,option)
	if QuestPrivate.apocalypseQuestStepNumber(option.key)~=2 then return false end
	local chosen=gStates.apocalypseQuestCombatBranch~=nil and gStates.apocalypseQuestCombatBranch[card.guid] or nil
	if chosen==nil or chosen~=tostring(option.key) then return true,false end
	return true,QuestPrivate.apocalypseQuestCombatStartedThisTurn(card,2)
end
apocalypseQuestHandlers["abd4fb"].specialLegal=function(card,playerIndex,option)
	local key=tostring(option.key)
	local questState=gStates.apocalypseQuestProgress~=nil and gStates.apocalypseQuestProgress[card.guid] or nil
	if key=="1" then return true,questState==nil or questState.globalPoints==nil or (questState.globalPoints["1"] or 0)<1 end
	local cursed=gStates.apocalypseQuestCursedHero~=nil and gStates.apocalypseQuestCursedHero[card.guid] or nil
	if turnOrder[playerIndex]==nil or cursed~=turnOrder[playerIndex].mage then return true,false end
	if key=="2a" then
		if apocalypseQuestCursedTargetIndex(card,playerIndex)~=nil then return true,true end
		return true,#apocalypseQuestCursedEligibleTargets(card,playerIndex)==1
	end
	return false
end
apocalypseQuestHandlers["8455b5"].specialLegal=function(card,playerIndex,option)
	if QuestPrivate.apocalypseQuestStepNumber(option.key)==2 then return true,true end
	return false
end
apocalypseQuestHandlers["bb2828"].specialLegal=function(card,playerIndex,option)
	local key=tostring(option.key)
	if key=="2" then return true,#QuestPrivate.apocalypseQuestArtificerAvailableColors(card,playerIndex)>0 end
	if key=="3" then return true,QuestPrivate.apocalypseQuestArtificerUniqueCrystalCount(card)>=3 end
	return false
end
apocalypseQuestHandlers["37e2ce"].failureReady=function(card,playerIndex,option)
	if tostring(option.key)=="2" then return true,QuestPrivate.apocalypseQuestFreeWineFailureReady(playerIndex or gStates.turnNumber) end
	return false
end
apocalypseQuestHandlers["a6d5cc"].failureReady=function(card,playerIndex,option)
	if tostring(option.key)=="2b" then
		local index=playerIndex or gStates.turnNumber
		return true,QuestPrivate.apocalypseQuestCombatStartedThisTurn(card,2)~=true and QuestPrivate.apocalypseQuestUnderSiegeStep2ChoiceLegal(index,"2b")
	end
	return false
end

apocalypseQuestStepSpecialLegal=function(card,playerIndex,option)
	if card==nil or option==nil then return true end
	local handler=apocalypseQuestHandler(card)
	if handler~=nil and handler.specialLegal~=nil then
		local handled,result=handler.specialLegal(card,playerIndex,option)
		if handled==true then return result==true end
	end
	local combatRule,combatStep=apocalypseQuestCombatRuleForOption(card,option.key)
	if combatRule~=nil then return QuestPrivate.apocalypseQuestCombatStartedThisTurn(card,combatRule.startedStep or combatStep) end
	return true
end

apocalypseQuestFailureReady=function(card,option,playerIndex)
	if card==nil or option==nil then return true end
	local handler=apocalypseQuestHandler(card)
	if handler~=nil and handler.failureReady~=nil then
		local handled,result=handler.failureReady(card,playerIndex,option)
		if handled==true then return result==true end
	end
	local combatRule,combatStep=apocalypseQuestCombatRuleForOption(card,option.key)
	if combatRule~=nil then return QuestPrivate.apocalypseQuestCombatStartedThisTurn(card,combatRule.startedStep or combatStep) end
	return true
end

apocalypseQuestCombatOption=function(card,state)
	if card==nil or state==nil then return nil end
	local key=apocalypseQuestCombatRuleSelectedKey(card,state)
	if key==nil then return nil end
	return QuestPrivate.apocalypseQuestChoiceOption(card,key)
end

apocalypseQuestCombatRelevant=function(card,playerIndex)
	if card==nil then return false end
	local state=QuestPrivate.apocalypseQuestProgressState(card,playerIndex,false)
	return state~=nil and state.completed~=true and apocalypseQuestCombatOption(card,state)~=nil
end

--Quest enemies already sitting on a Quest card use the same floating Attack icon as a
--nearby Rampaging enemy.  Generated combats (Execution, Mine of Doom, etc.) still need
--the card Fight control because there is no enemy object to click until the fight begins.
apocalypseQuestUsesEnemyAttackButton=function(card)
	local handler=apocalypseQuestHandler(card)
	return handler~=nil and handler.enemyAttackButton==true
end

apocalypseQuestRemoveEnemyAttackButton=function(enemy)
	if enemy==nil then return end
	local xml=enemy.UI.getXmlTable() or {}
	local kept={}
	local changed=false
	for _, element in ipairs(xml) do
		local id=element.attributes~=nil and element.attributes.id or nil
		if id~=nil and id:sub(1,8)=="QuestAtk" then changed=true else kept[#kept+1]=element end
	end
	if changed==true then
		if #kept>0 then enemy.UI.setXmlTable(kept) else enemy.UI.setXml("") end
	end
end

apocalypseQuestClearEnemyAttackButtons=function(card)
	if card==nil then return end
	for _, obj in ipairs(apocalypseQuestObjectsOnCard(card)) do
		if monsterPugs[obj.guid]~=nil then apocalypseQuestRemoveEnemyAttackButton(obj) end
	end
end

--Object UI is one-sided. When an enemy token is face down the normal negative-Z UI plane
--sits underneath the token, so put the Quest Attack button on the opposite side and turn its
--front face outward. This mirrors the proven Banner of Command face-down UI handling.
apocalypseQuestEnemyAttackButtonPosition=function(enemy)
	local depth=20/0.9
	return "0 "..tostring(120/0.9).." "..tostring(enemy~=nil and enemy.is_face_down==true and depth or -depth)
end
function QuestPrivate.apocalypseQuestEnemyAttackButtonRotation(enemy)
	return enemy~=nil and enemy.is_face_down==true and "0 180 180" or "0 0 180"
end

apocalypseQuestEnemyAttackRotationGeneration={}
function QuestPrivate.apocalypseQuestRefreshEnemyAttackButtonOrientation(enemyGUID)
	local enemy=getObjectFromGUID(enemyGUID)
	if enemy==nil then return false end
	local xml=enemy.UI.getXmlTable() or {}
	local wantedRotation=QuestPrivate.apocalypseQuestEnemyAttackButtonRotation(enemy)
	local wantedPosition=apocalypseQuestEnemyAttackButtonPosition(enemy)
	local found=false
	local changed=false
	for _, element in ipairs(xml) do
		local id=element.attributes~=nil and element.attributes.id or nil
		if id~=nil and id:sub(1,8)=="QuestAtk" then
			found=true
			if element.attributes.rotation~=wantedRotation then element.attributes.rotation=wantedRotation changed=true end
			if element.attributes.position~=wantedPosition then element.attributes.position=wantedPosition changed=true end
		end
	end
	if changed==true then enemy.UI.setXmlTable(xml) end
	return found
end

function apocalypseQuestScheduleEnemyAttackButtonOrientation(enemyGUID)
	local enemy=getObjectFromGUID(enemyGUID)
	if enemy==nil then return false end
	--Do not create any extra work for ordinary monsters: only schedule a refresh when this
	--token already carries a Quest Attack control.
	local hasQuestButton=false
	for _, element in ipairs(enemy.UI.getXmlTable() or {}) do
		local id=element.attributes~=nil and element.attributes.id or nil
		if id~=nil and id:sub(1,8)=="QuestAtk" then hasQuestButton=true break end
	end
	if hasQuestButton~=true then return false end
	apocalypseQuestEnemyAttackRotationGeneration[enemyGUID]=(apocalypseQuestEnemyAttackRotationGeneration[enemyGUID] or 0)+1
	local generation=apocalypseQuestEnemyAttackRotationGeneration[enemyGUID]
	safeWaitFrames("Quests",function()
		if apocalypseQuestEnemyAttackRotationGeneration[enemyGUID]~=generation then return end
		safeWaitCondition("Quests",function()
			if apocalypseQuestEnemyAttackRotationGeneration[enemyGUID]~=generation then return end
			QuestPrivate.apocalypseQuestRefreshEnemyAttackButtonOrientation(enemyGUID)
		end, function()
			local live=getObjectFromGUID(enemyGUID)
			return apocalypseQuestEnemyAttackRotationGeneration[enemyGUID]~=generation or live==nil or live.resting==true
		end, 2, function()
			if apocalypseQuestEnemyAttackRotationGeneration[enemyGUID]==generation then QuestPrivate.apocalypseQuestRefreshEnemyAttackButtonOrientation(enemyGUID) end
		end)
	end,1)
	return true
end

function QuestPrivate.apocalypseQuestRefreshEnemyAttackButtons(card,playerIndex)
	if card==nil or apocalypseQuestUsesEnemyAttackButton(card)~=true then return end
	--Only the six Quests with enemies sitting on their cards need this work. Snapshot the card objects
	--once so combat availability and the actual button refresh do not each scan the whole table.
	local cardObjects=apocalypseQuestObjectsOnCard(card)
	local active=playerIndex~=nil and QuestPrivate.apocalypseQuestCombatAvailable(card,playerIndex,cardObjects)==true
	for _, enemy in ipairs(cardObjects) do
		if monsterPugs[enemy.guid]~=nil then
			apocalypseQuestRemoveEnemyAttackButton(enemy)
			if active==true then
				local xml=enemy.UI.getXmlTable() or {}
				xml[#xml+1]={tag="Button", attributes={id="QuestAtk"..card.guid..enemy.guid,
					onClick="global/apocalypseQuestEnemyAttack",
					height=70/0.9, width=70/0.9,
					position=apocalypseQuestEnemyAttackButtonPosition(enemy), rotation=QuestPrivate.apocalypseQuestEnemyAttackButtonRotation(enemy),
					color="rgba(0,0,0,0.0)"},
					children={{tag="Image", attributes={image="Attack Button"}}}}
				enemy.UI.setXmlTable(xml)
			end
		end
	end
end

function QuestPrivate.apocalypseQuestCombatLaunchKey(card,state)
	return tostring(card.guid)..":"..tostring(state~=nil and state.step or 0)..":"..tostring(gStates.apocalypseQuestTurnSerial or 0)
end

function QuestPrivate.apocalypseQuestMarkCombatStarted(card,stepNumber)
	if card==nil then return end
	if gStates.apocalypseQuestCombatStarted==nil then gStates.apocalypseQuestCombatStarted={} end
	gStates.apocalypseQuestCombatStarted[card.guid]={serial=gStates.apocalypseQuestTurnSerial or 0,step=tonumber(stepNumber) or 0}
end

function QuestPrivate.apocalypseQuestCombatStartedThisTurn(card,stepNumber)
	if card==nil or gStates.apocalypseQuestCombatStarted==nil then return false end
	local record=gStates.apocalypseQuestCombatStarted[card.guid]
	return record~=nil and record.serial==(gStates.apocalypseQuestTurnSerial or 0) and record.step==(tonumber(stepNumber) or 0)
end

--A combat-gated Complete or Progress can become available during end-turn cleanup, after the player
--has already pressed End Turn. Keep the Quest action pending until it is resolved; the shared
--Rewards Claimed soft-lock window decides how long that pending action may block turn progression.
--Ordinary failed fights must never create this gate: undefeated enemies are face down. The Fog step 2
--is the deliberate exception because its spectral monster cannot be attacked or defeated; completing
--that combat itself is what unlocks Progress.
function QuestPrivate.apocalypseQuestSetRewardCompletionGate(card,playerIndex,action)
	if card==nil or turnOrder[playerIndex]==nil then return false end
	if gStates.apocalypseQuestRewardCompletionPending==nil then gStates.apocalypseQuestRewardCompletionPending={} end
	gStates.apocalypseQuestRewardCompletionPending[card.guid]={player=playerIndex,serial=gStates.apocalypseQuestTurnSerial or 0,action=action or "Complete"}
	return true
end

function apocalypseQuestRewardCompletionPendingForPlayer(playerIndex)
	if gStates.apocalypseQuestRewardCompletionPending==nil or turnOrder[playerIndex]==nil then return false,nil,nil end
	local serial=gStates.apocalypseQuestTurnSerial or 0
	for cardGUID, record in pairs(gStates.apocalypseQuestRewardCompletionPending) do
		if record~=nil and record.player==playerIndex and record.serial==serial then
			if getObjectFromGUID(cardGUID)~=nil then
				return true,cardGUID,record.action or "Complete"
			else
				gStates.apocalypseQuestRewardCompletionPending[cardGUID]=nil
			end
		end
	end
	return false,nil,nil
end

function QuestPrivate.apocalypseQuestRewardCompletionPendingForSeat(seatPos)
	if seatPos==nil then return false,nil end
	for playerIndex, details in ipairs(turnOrder) do
		if details.seatPos==seatPos then return apocalypseQuestRewardCompletionPendingForPlayer(playerIndex) end
	end
	return false,nil
end

function apocalypseQuestCaptureRewardCompletionGate(playerIndex)
	if apocalypseQuestsUsed()~=true or turnOrder[playerIndex]==nil then return false end
	if gStates.apocalypseQuestRewardCompletionPending==nil then gStates.apocalypseQuestRewardCompletionPending={} end
	local serial=gStates.apocalypseQuestTurnSerial or 0
	local captured=false
	for _, card in ipairs(QuestPrivate.apocalypseQuestOfferCards()) do
		local state=QuestPrivate.apocalypseQuestProgressState(card,playerIndex,false)
		local option=state~=nil and state.completed~=true and apocalypseQuestCombatOption(card,state) or nil
		local quest=apocalypseQuestData[card.guid]
		local failOnly=quest~=nil and quest.failOnlySteps~=nil and option~=nil and quest.failOnlySteps[tostring(option.key)]==true
		if state~=nil and option~=nil and failOnly~=true and QuestPrivate.apocalypseQuestCombatStartedThisTurn(card,state.step)==true then
			local tracked=gStates.apocalypseQuestCombatEnemies~=nil and gStates.apocalypseQuestCombatEnemies[card.guid] or nil
			local fought=0
			local allDefeated=true
			for guid,_ in pairs(tracked or {}) do
				--attackedMonsters is rebuilt each turn, so intersecting with it ignores enemies from an
				--older attempt (important for repeatable fights such as Under Siege).
				if gStates.attackedMonsters~=nil and gStates.attackedMonsters[guid]~=nil then
					fought=fought+1
					local enemy=getObjectFromGUID(guid)
					if enemy==nil or enemy.is_face_down==true then allDefeated=false end
				end
			end
			local requiredAction=option.completes==true and "Complete" or "Progress"
			local resolved=fought>0 and allDefeated==true
			local handler=apocalypseQuestHandler(card)
			if handler~=nil and handler.rewardCompletionGate~=nil then
				local handled,handlerResolved,handlerAction=handler.rewardCompletionGate(card,playerIndex,option,fought,allDefeated)
				if handled==true then
					resolved=handlerResolved==true
					requiredAction=handlerAction or requiredAction
				end
			end
			if resolved==true then
				QuestPrivate.apocalypseQuestSetRewardCompletionGate(card,playerIndex,requiredAction)
				captured=true
			else
				gStates.apocalypseQuestRewardCompletionPending[card.guid]=nil
			end
		end
	end
	return captured
end

function QuestPrivate.apocalypseQuestClearRewardCompletionGate(card,playerIndex)
	if card==nil or gStates.apocalypseQuestRewardCompletionPending==nil then return end
	local record=gStates.apocalypseQuestRewardCompletionPending[card.guid]
	if record==nil or playerIndex==nil or record.player==playerIndex then
		gStates.apocalypseQuestRewardCompletionPending[card.guid]=nil
	end
	if gStates.preEndTurn==true then
		if turnOrder[gStates.turnNumber]~=nil and steadyTempoUpdateRewardGate~=nil then steadyTempoUpdateRewardGate(turnOrder[gStates.turnNumber].seatPos) end
		if mainUIUpdate~=nil then mainUIUpdate("Quest reward gate cleared") end
	end
end

function QuestPrivate.apocalypseQuestCombatAvailable(card,playerIndex,cardObjects)
	if card==nil or QuestPrivate.apocalypseQuestPlayerMayAct(card,playerIndex)~=true then return false end
	local state=QuestPrivate.apocalypseQuestProgressState(card,playerIndex,false)
	if state==nil or state.completed==true then return false end
	local handler=apocalypseQuestHandler(card)
	if handler~=nil and handler.combatAvailable~=nil then
		local handled,available=handler.combatAvailable(card,playerIndex,state)
		if handled==true and available~=true then return false end
	end
	local option=apocalypseQuestCombatOption(card,state)
	if option==nil or QuestPrivate.apocalypseQuestStarterLocationLegal(card,playerIndex,option)~=true then return false end
	if gStates.apocalypseQuestCombatLaunches~=nil and gStates.apocalypseQuestCombatLaunches[card.guid]==QuestPrivate.apocalypseQuestCombatLaunchKey(card,state) then return false end
	if apocalypseQuestUsesEnemyAttackButton(card)==true then
		for _, obj in ipairs(cardObjects or apocalypseQuestObjectsOnCard(card)) do if monsterPugs[obj.guid]~=nil then return true end end
		return false
	end
	return true
end

function QuestPrivate.apocalypseQuestTrackCombatEnemy(card,enemy)
	if card==nil or enemy==nil then return end
	if gStates.apocalypseQuestCombatEnemies==nil then gStates.apocalypseQuestCombatEnemies={} end
	if gStates.apocalypseQuestCombatEnemies[card.guid]==nil then gStates.apocalypseQuestCombatEnemies[card.guid]={} end
	gStates.apocalypseQuestCombatEnemies[card.guid][enemy.guid]=true
end

function QuestPrivate.apocalypseQuestNextCombatTarget(playerIndex)
	if turnOrder[playerIndex]==nil then return nil end
	gStates.monsterOffsetX=gStates.monsterOffsetX or 0
	gStates.monsterOffsetZ=gStates.monsterOffsetZ or 0
	local seat=turnOrder[playerIndex].seatPos
	local target={(seat*40)-96+gStates.monsterOffsetX,2.5,-39-gStates.monsterOffsetZ}
	gStates.monsterOffsetX=gStates.monsterOffsetX+2.5
	if gStates.monsterOffsetX>12 then gStates.monsterOffsetX=0 gStates.monsterOffsetZ=gStates.monsterOffsetZ+2.5 end
	return target
end

function QuestPrivate.apocalypseQuestMoveEnemyToPlayer(card,playerIndex,enemy,focusCamera)
	if card==nil or enemy==nil or turnOrder[playerIndex]==nil then return false end
	--The floating Quest Attack icon belongs only to the token while it is waiting on the Quest card.
	apocalypseQuestRemoveEnemyAttackButton(enemy)
	if gStates.attackedMonsters==nil then gStates.attackedMonsters={} end
	local oldPos=enemy.getPosition()
	local oldRot=enemy.getRotation()
	if gStates.monsterPlayLocation==nil then gStates.monsterPlayLocation={} end
	gStates.monsterPlayLocation[enemy.guid]={oldPos[1],oldPos[2],oldPos[3]}
	gStates.attackedMonsters[enemy.guid]={{oldPos[1],oldPos[2],oldPos[3]},{oldRot[1],oldRot[2],oldRot[3]}}
	QuestPrivate.apocalypseQuestTrackCombatEnemy(card,enemy)
	local target=QuestPrivate.apocalypseQuestNextCombatTarget(playerIndex)
	if target==nil then return false end
	enemy.unlock()
	enemy.setRotationSmooth({0,180,0})
	if focusCamera~=false then combatCameraFocus(playerIndex) end
	enemy.setPositionSmooth(target)
	return true,target
end

function QuestPrivate.apocalypseQuestMoveCardEnemiesToPlayer(card,playerIndex,maxCount)
	local moved=0
	for _, enemy in ipairs(apocalypseQuestObjectsOnCard(card)) do
		if monsterPugs[enemy.guid]~=nil and (maxCount==nil or moved<maxCount) then
			if QuestPrivate.apocalypseQuestMoveEnemyToPlayer(card,playerIndex,enemy,moved==0)==true then moved=moved+1 end
		end
	end
	return moved
end

function QuestPrivate.apocalypseQuestSpawnEnemyToCombat(card,playerIndex,pileName,possessed,offset,attackBonus,possessedFaction)
	if card==nil or turnOrder[playerIndex]==nil or monsterPiles[pileName]==nil then return nil end
	local bag=getObjectFromGUID(monsterPiles[pileName])
	if bag==nil or bag.getQuantity()==0 then
		broadcastToAll(joinLang({"{en}Quest combat: no {ru}Бой задания: нет доступного жетона врага из {zh-tw}任務戰鬥：沒有可用的 {zh-cn}任务战斗：没有可用的 {ko}퀘스트 전투: 사용할 수 있는 {es}Combate de Misión: no hay ficha de enemigo de {fr}Combat de Quête : aucun jeton Ennemi de {pt-br}Combate da Missão: não há ficha de inimigo de {de}Quest-Kampf: Es ist kein Gegnermarker aus ",tostring(pileName),"{en} enemy token is available.{ru}.{zh-tw} 敵人標記。{zh-cn} 敌人标记。{ko} 적 토큰이 없습니다.{es} disponible.{fr} disponible.{pt-br} disponível.{de} verfügbar."}), {1,0.55,0.2})
		return nil
	end
	local target=QuestPrivate.apocalypseQuestNextCombatTarget(playerIndex)
	if target==nil then return nil end
	local sourcePos=bag.getPosition()
	--Generated Quest enemies travel directly from their real monster pile to the combat area. They no
	--longer make an invisible intermediate stop on the Quest card.
	local enemy=bag.takeObject({position=target,rotation={0,180,0},smooth=true})
	if enemy==nil then return nil end
	combatCameraFocus(playerIndex)
	--Match normal monster draws: temporary decals from a previous use never leave the pile again.
	enemy.setDecals({})
	if gStates.attackedMonsters==nil then gStates.attackedMonsters={} end
	gStates.attackedMonsters[enemy.guid]={{sourcePos[1],2.5,sourcePos[3]},{0,180,0}}
	QuestPrivate.apocalypseQuestTrackCombatEnemy(card,enemy)
	local enemyGUID=enemy.guid
	if possessed==true then
		local refillImmediate=tokenRefill()
		safeWaitFrames("Quests",function()
			local possessedBag=getObjectFromGUID(GUID.bag.possessed)
			if possessedBag~=nil and possessedBag.getQuantity()~=0 then
				--Send the Possessed token from 9677da to the same X/Z, slightly above the moving enemy.
				--It falls through the player scripting zone and the existing attachment code combines them.
				local possessedToken=possessedBag.takeObject({position={target[1],target[2]+1.10,target[3]},rotation={0,180,0},smooth=true})
				if possessedToken~=nil then
					if gStates.apocalypsePossessedFactionByToken==nil then gStates.apocalypsePossessedFactionByToken={} end
					gStates.apocalypsePossessedFactionByToken[possessedToken.guid]=possessedFaction or "Apoc"
				end
			end
			if attackBonus~=nil and attackBonus~=0 then
				safeWaitFrames("Quests",function() QuestPrivate.apocalypseQuestAddEnemyAttackBonus(enemyGUID,attackBonus) end,24)
			end
		end,refillImmediate and 3 or 15)
	elseif attackBonus~=nil and attackBonus~=0 then
		safeWaitFrames("Quests",function() QuestPrivate.apocalypseQuestAddEnemyAttackBonus(enemyGUID,attackBonus) end,8)
	end
	return enemy
end

function QuestPrivate.apocalypseQuestFogEnemy(card)
	if card==nil then return nil end
	for _, obj in ipairs(apocalypseQuestObjectsOnCard(card)) do
		if monsterPugs[obj.guid]~=nil and monsterPugs[obj.guid].pugType=="tan" then return obj end
	end
	return nil
end

function QuestPrivate.apocalypseQuestFogPossessedReady(card)
	local enemy=QuestPrivate.apocalypseQuestFogEnemy(card)
	if enemy==nil then return false end
	for _, attachment in pairs(enemy.getAttachments() or {}) do
		if monsterPugs[attachment.guid]~=nil and monsterPugs[attachment.guid].pugType=="possessed" then return true end
	end
	return false
end

function QuestPrivate.apocalypseQuestPossessExistingEnemy(card,enemy,faction)
	if card==nil or enemy==nil then return false end
	local possessedBag=getObjectFromGUID(GUID.bag.possessed)
	if possessedBag==nil or possessedBag.getQuantity()==0 then tokenRefill() possessedBag=getObjectFromGUID(GUID.bag.possessed) end
	if possessedBag==nil or possessedBag.getQuantity()==0 then
		broadcastToAll("{en}Quest combat: no Possessed token is available.{ru}Бой задания: жетон Одержимого недоступен.{zh-tw}任務戰鬥：沒有可用的附身標記。{zh-cn}任务战斗：没有可用的附身标记。{ko}퀘스트 전투: 사용할 수 있는 빙의 토큰이 없습니다.{es}Combate de Misión: no hay ficha de Poseído disponible.{fr}Combat de Quête : aucun jeton Possédé n’est disponible.{pt-br}Combate da Missão: não há ficha de Possuído disponível.{de}Quest-Kampf: Es ist kein Besessen-Marker verfügbar.",{1,0.55,0.2})
		return false
	end
	local pos=apocalypseQuestPlannedWorldPosition(card,enemy.getPosition())
	local target={pos[1],pos[2]+1.10,pos[3]}
	local token=possessedBag.takeObject({position=target,rotation={0,180,0},smooth=true})
	if token~=nil then
		if gStates.apocalypsePossessedFactionByToken==nil then gStates.apocalypsePossessedFactionByToken={} end
		gStates.apocalypsePossessedFactionByToken[token.guid]=faction or "Apoc"
		apocalypseQuestRegisterMoveAttachment(card,token,target)
		local tokenGUID=token.guid
		local enemyGUID=enemy.guid
		local checks=0
		local function attachPossessed()
			local live=getObjectFromGUID(tokenGUID)
			if live~=nil then attachEnemy(nil,nil,"attach",live,nil) end
		end
		safeWaitFrames("Quests",function()
			safeWaitCondition("Quests",attachPossessed,function()
				checks=checks+1
				local live=getObjectFromGUID(tokenGUID)
				local liveEnemy=getObjectFromGUID(enemyGUID)
				if live==nil or liveEnemy==nil then return checks>=12 end
				return live.spawning~=true and live.isSmoothMoving()==false and liveEnemy.isSmoothMoving()==false
			end,3,attachPossessed)
		end,1)
		return true
	end
	return false
end

function QuestPrivate.apocalypseQuestAddEnemyAttackBonus(enemyGUID,bonus)
	local enemy=getObjectFromGUID(enemyGUID)
	local base=monsterPugs[enemyGUID]
	if enemy==nil or base==nil or bonus==nil then return false end
	if gStates.monsterPerks[enemyGUID]==nil then gStates.monsterPerks[enemyGUID]={} end
	local source=gStates.monsterPerks[enemyGUID].attack or base.attack
	if source==nil then
		gStates.monsterPerks[enemyGUID].boost=(gStates.monsterPerks[enemyGUID].boost or 0)+bonus
		combatAddAllAttackBonusDecal(enemy,bonus)
		return true
	end
	local adjusted={}
	for attackType,values in pairs(source) do
		adjusted[attackType]={}
		for index,value in pairs(values) do adjusted[attackType][index]=value+bonus end
	end
	gStates.monsterPerks[enemyGUID].attack=adjusted
	combatAddAllAttackBonusDecal(enemy,bonus)
	setMonsterObjectButtons(enemy,true)
	return true
end

function QuestPrivate.apocalypseQuestMineDoomColors(playerIndex)
	local hex=QuestPrivate.apocalypseQuestCurrentPlayerHex(playerIndex)
	if hex==nil or QuestPrivate.apocalypseQuestFeatureMatches(hex.feature,"mine")~=true then return {} end
	local details=terrainTiles[hex.terrainGUID]
	local colors=details~=nil and details.mineColors~=nil and details.mineColors[hex.bearing] or nil
	local result={}
	for _, color in ipairs(colors or {}) do result[#result+1]=color end
	return result
end

function QuestPrivate.apocalypseQuestArtificerAvailableColors(card,playerIndex)
	local available={}
	local used={}
	for _, obj in ipairs(apocalypseQuestObjectsOnCard(card)) do
		local color=apocalypseQuestBasicCrystalColor(obj)
		if color~=nil then used[color]=true end
	end
	for _, color in ipairs(QuestPrivate.apocalypseQuestMineDoomColors(playerIndex)) do
		if used[color]~=true then available[#available+1]=color end
	end
	return available
end

function QuestPrivate.apocalypseQuestArtificerUniqueCrystalCount(card)
	local used={}
	for _, obj in ipairs(apocalypseQuestObjectsOnCard(card)) do
		local color=apocalypseQuestBasicCrystalColor(obj)
		if color~=nil then used[color]=true end
	end
	local count=0
	for _,_ in pairs(used) do count=count+1 end
	return count
end

function QuestPrivate.apocalypseQuestLaunchMineDoom(card,playerIndex,color,attackBonus)
	local recipes={
		Blue={{"purple",true},{"purple",true}},
		Red={{"red",true}},
		Green={{"green",true},{"green",true},{"green",true}},
		White={{"gray",true},{"white",true}},
	}
	local recipe=recipes[color]
	if recipe==nil then return false end
	for index,data in ipairs(recipe) do
		QuestPrivate.apocalypseQuestSpawnEnemyToCombat(card,playerIndex,data[1],data[2],(index-1)*0.25,attackBonus or 0,"Apoc")
	end
	if attackBonus~=nil and attackBonus>0 then
		broadcastToAll("{en}Mine of Doom: this mine has multiple crystal colors; all Quest enemies get +1 to every Attack.{ru}Mine of Doom: в этой шахте несколько цветов кристаллов; все враги задания получают +1 к каждой Атаке.{zh-tw}Mine of Doom：此礦場有多種水晶顏色；所有任務敵人的每次攻擊 +1。{zh-cn}Mine of Doom：此矿场有多种水晶颜色；所有任务敌人的每次攻击 +1。{ko}Mine of Doom: 이 광산에는 여러 색의 크리스털이 있습니다. 모든 퀘스트 적의 각 공격이 +1 됩니다.{es}Mine of Doom: esta mina tiene varios colores de cristal; todos los enemigos de Misión reciben +1 a cada Ataque.{fr}Mine of Doom : cette mine possède plusieurs couleurs de cristal ; tous les ennemis de Quête gagnent +1 à chaque Attaque.{pt-br}Mine of Doom: esta mina tem várias cores de cristal; todos os inimigos da Missão recebem +1 em cada Ataque.{de}Mine of Doom: Diese Mine hat mehrere Kristallfarben; alle Quest-Gegner erhalten +1 auf jeden Angriff.",positionToColor(playerIndex))
	end
	return true
end

function QuestPrivate.apocalypseQuestLaunchCombat(card,playerIndex,playerColor,chosenColor,clickedEnemyGUID)
	if QuestPrivate.apocalypseQuestCombatAvailable(card,playerIndex)~=true and chosenColor==nil then return false end
	local state=QuestPrivate.apocalypseQuestProgressState(card,playerIndex,false)
	if state==nil then return false end
	local combatOption=apocalypseQuestCombatOption(card,state)
	if combatOption~=nil then
		local markerRule=QuestPrivate.apocalypseQuestMarkerRule(card,QuestPrivate.apocalypseQuestStepNumber(combatOption.key))
		if markerRule~=nil and QuestPrivate.apocalypseQuestMarkerPlacementCommitted(markerRule)~=true then
			if QuestPrivate.apocalypseQuestPlaceStepMarker(card,playerIndex,combatOption,playerColor)~=true then return false end
			QuestPrivate.apocalypseQuestCommitStepMarker(card,combatOption)
		end
	end
	if gStates.apocalypseQuestCombatLaunches==nil then gStates.apocalypseQuestCombatLaunches={} end
	gStates.apocalypseQuestCombatLaunches[card.guid]=QuestPrivate.apocalypseQuestCombatLaunchKey(card,state)
	local handler=apocalypseQuestHandler(card)
	if handler~=nil and handler.prepareCombatLaunch~=nil then handler.prepareCombatLaunch(card,playerIndex,chosenColor) end
	local moved=handler~=nil and handler.launchCombat~=nil and handler.launchCombat(card,playerIndex,playerColor,chosenColor,clickedEnemyGUID) or 0

	if moved==0 then
		gStates.apocalypseQuestCombatLaunches[card.guid]=nil
	else
		QuestPrivate.apocalypseQuestMarkCombatStarted(card,state.step)
	end
	apocalypseQuestUpdateProgressButtons(card)
	return moved>0
end

function apocalypseQuestEnemyAttack(player,mouseButton,id)
	if mouseButton~="-1" or player==nil or id==nil or id:sub(1,8)~="QuestAtk" then return end
	local cardGUID=id:sub(9,14)
	local enemyGUID=id:sub(15,20)
	local card=getObjectFromGUID(cardGUID)
	local enemy=getObjectFromGUID(enemyGUID)
	if card~=nil and card.isSmoothMoving()==true then
		local queuedPlayer,queuedButton,queuedID=player,mouseButton,id
		local function retry() apocalypseQuestEnemyAttack(queuedPlayer,queuedButton,queuedID) end
		safeWaitCondition("Quests",retry,function()
			local live=getObjectFromGUID(cardGUID)
			return live==nil or live.isSmoothMoving()==false
		end,5,retry)
		return
	end
	local playerIndex=gStates.turnNumber
	local details=turnOrder[playerIndex]
	if card==nil or enemy==nil or details==nil or legalPlayerCheck(player.color,details.seatPos,"NoDummyException")~=true then return end
	local offered=false
	for _, offerCard in ipairs(QuestPrivate.apocalypseQuestOfferCards()) do if offerCard.guid==cardGUID then offered=true break end end
	if offered~=true or apocalypseQuestUsesEnemyAttackButton(card)~=true or QuestPrivate.apocalypseQuestCombatAvailable(card,playerIndex)~=true then
		QuestPrivate.apocalypseQuestRefreshEnemyAttackButtons(card,playerIndex)
		return
	end
	local handler=apocalypseQuestHandler(card)
	--Most card-enemy Quests launch only the clicked enemy. A handler may explicitly launch the full group.
	local clickedGUID=handler~=nil and handler.enemyAttackMovesAll==true and nil or enemyGUID
	QuestPrivate.apocalypseQuestLaunchCombat(card,playerIndex,player.color,nil,clickedGUID)
	if getObjectFromGUID(cardGUID)~=nil then QuestPrivate.apocalypseQuestInterfaceAdd(card,true) end
end

function QuestPrivate.apocalypseQuestRestoreBurnedMonastery(card,playerIndex)
	local marker=getObjectFromGUID("81b6f2")
	local map=getObjectFromGUID(mapArea)
	if marker==nil or map==nil then return false end
	local hex=runtimeMapHexAtPosition(marker.getPosition())
	if hex==nil then return false end
	local spatial=runtimeMapSpatialSnapshot()
	for _, obj in ipairs(runtimeMapSpatialNearbyObjects(spatial,hex.position,1.1)) do
		local pos=spatial.positions[obj.guid] or obj.getPosition()
		if ((pos[1]-hex.position[1])^2)+((pos[3]-hex.position[3])^2)<1 then
			if gStates.destroyedSites~=nil and gStates.destroyedSites[obj.guid]~=nil and gStates.destroyedSites[obj.guid].hexFeature=="monastery" then
				undoDestroyedSitePlacement(obj)
				local bag=getObjectFromGUID(GUID.bag.destroyedSite)
				if bag~=nil then obj.unlock() bag.putObject(obj) end
				gStates.monasteryCount=(gStates.monasteryCount or 0)+1
				return true
			end
			if obj.getGMNotes()=="Burned Monastery" then
				shieldLocation(obj,map,"remove")
				obj.setGMNotes("")
				obj.destruct()
				return true
			end
		end
	end
	return false
end

function QuestPrivate.apocalypseQuestAddAdvancedActionToUnitOffer()
	local deck=standardDeckCycleObject("Advanced Action")
	local zone=getObjectFromGUID("a3d99b")
	if deck==nil or zone==nil then return false end
	local occupied={}
	for _, obj in pairs(zone.getObjects()) do
		if obj.type=="Card" and gameCardType(obj)=="Advanced Action" and obj.getPosition()[3]<-7 then
			occupied[math.floor((36-obj.getPosition()[1])/4.8+1.5)]=true
		end
	end
	local slot=1
	while slot<=6 and occupied[slot]==true do slot=slot+1 end
	if slot>6 then
		broadcastToAll("{en}Quest effect: the Monastery Advanced Action offer is full; add one Advanced Action manually.{ru}Эффект задания: предложение Продвинутых действий Монастыря заполнено; добавьте одно Продвинутое действие вручную.{zh-tw}任務效果：修道院進階行動供應已滿；請手動加入一張進階行動。{zh-cn}任务效果：修道院进阶行动供应已满；请手动加入一张进阶行动。{ko}퀘스트 효과: 수도원의 고급 행동 제안이 가득 찼습니다. 고급 행동 한 장을 수동으로 추가하십시오.{es}Efecto de Misión: la oferta de Acciones Avanzadas del Monasterio está llena; añade una Acción Avanzada manualmente.{fr}Effet de Quête : l’offre d’Actions Avancées du Monastère est pleine ; ajoutez-en une manuellement.{pt-br}Efeito da Missão: a oferta de Ações Avançadas do Mosteiro está cheia; adicione uma Ação Avançada manualmente.{de}Quest-Effekt: Das Angebot an Fortgeschrittenen Aktionen des Klosters ist voll; füge eine Fortgeschrittene Aktion manuell hinzu.",{1,0.55,0.2})
		return false
	end
	standardDeckCycleShuffleIfReached("Advanced Action")
	deck=standardDeckCycleObject("Advanced Action")
	if deck==nil then return false end
	local pos={36-((slot-1)*4.8),0.98,-10.2}
	local card=nil
	if deck.type=="Deck" then card=deck.takeObject({position=pos,rotation={0,180,0},smooth=true})
	elseif deck.type=="Card" then
		card=deck
		card.setPositionSmooth(pos)
		card.setRotationSmooth({0,180,0})
	end
	if card~=nil then safeWaitCondition("Quests",function() if getObjectFromGUID(card.guid)~=nil then card.lock() end end,function() return card==nil or card.resting end) end
	return card~=nil
end

function QuestPrivate.apocalypseQuestNobleWarriorFinalReward(card,playerIndex,key)
	local color=apocalypseQuestCardCrystalColor(card)
	if key=="3b" then
		local levelText={Green="level I",White="level I-II",Blue="level I-III",Red="level I-IV"}
		broadcastToAll(joinLang({"{en}Noble Warrior: recruit one {ru}Noble Warrior: бесплатно наймите один отряд уровня {zh-tw}Noble Warrior：免費招募一個 {zh-cn}Noble Warrior：免费招募一个 {ko}Noble Warrior: {es}Noble Warrior: recluta gratis una Unidad {fr}Noble Warrior : recrutez gratuitement une Unité {pt-br}Noble Warrior: recrute gratuitamente uma Unidade {de}Noble Warrior: Rekrutiere kostenlos eine ",tostring(levelText[color] or "eligible"),"{en} Unit for free.{ru}.{zh-tw} 部隊。{zh-cn} 部队。{ko} 유닛 하나를 무료로 모집하십시오.{es}.{fr}.{pt-br}.{de}-Einheit."}),positionToColor(playerIndex))
	end
end

function QuestPrivate.apocalypseQuestCrystalChoiceColors(playerIndex,pending)
	local colors={}
	if turnOrder[playerIndex]==nil then return colors end
	pending=pending or {}
	pending.startCounts=pending.startCounts or {}
	pending.granted=pending.granted or {}
	for _,color in ipairs({"Blue","Red","Green","White"}) do
		if pending.startCounts[color]==nil then pending.startCounts[color]=mineCrystalCount(playerIndex,color) end
		local effective=math.max(mineCrystalCount(playerIndex,color),pending.startCounts[color]+(pending.granted[color] or 0))
		if effective<3 then colors[#colors+1]=color end
	end
	if #colors==0 then colors={"NoInventory"} end
	return colors
end

function QuestPrivate.apocalypseQuestFinishGuardDutyChoice(card,playerIndex,distance)
	if card==nil or turnOrder[playerIndex]==nil then return end
	if gStates.apocalypseQuestCombatChoice~=nil then gStates.apocalypseQuestCombatChoice[card.guid]=nil end
	QuestPrivate.apocalypseQuestClearRewardCompletionGate(card,playerIndex)
	broadcastToAll(joinLang({translateWord[turnOrder[playerIndex].mage] or tostring(turnOrder[playerIndex].mage),"{en} completed Guard Duty: distance {ru} завершил Guard Duty: расстояние {zh-tw} 完成 Guard Duty：距離 {zh-cn} 完成 Guard Duty：距离 {ko}이(가) Guard Duty를 완료했습니다: 거리 {es} completó Guard Duty: distancia {fr} a terminé Guard Duty : distance {pt-br} concluiu Guard Duty: distância {de} schloss Guard Duty ab: Entfernung ",tostring(distance or "?"),"{en}, two chosen mana crystals.{ru}, два выбранных кристалла маны.{zh-tw}，兩顆自選魔力水晶。{zh-cn}，两颗自选魔力水晶。{ko}, 선택한 마나 크리스털 2개.{es}, dos cristales de maná elegidos.{fr}, deux cristaux de mana choisis.{pt-br}, dois cristais de mana escolhidos.{de}, zwei gewählte Manakristalle."}),positionToColor(playerIndex))
	QuestPrivate.apocalypseQuestFinishCompletedCard(card)
	safeWaitTime("Quests",function() rewindTransactionFinish("Quest resolve "..tostring(card.guid).." "..tostring(playerIndex)) end,0.5)
end

local function apocalypseQuestFinishCrystalRollReward(card,playerIndex,pending,finishQuestResolution)
	if card==nil or turnOrder[playerIndex]==nil then
		if finishQuestResolution~=nil then finishQuestResolution(0.5) end
		return
	end
	pending=pending or {}
	if gStates.apocalypseQuestCombatChoice~=nil then gStates.apocalypseQuestCombatChoice[card.guid]=nil end
	QuestPrivate.apocalypseQuestClearRewardCompletionGate(card,playerIndex)
	if pending.optionKey~=nil then
		local option=QuestPrivate.apocalypseQuestChoiceOption(card,pending.optionKey)
		if option~=nil then QuestPrivate.apocalypseQuestResolveSpecialEffect(card,playerIndex,option,true) end
	end
	broadcastToAll(joinLang({translateWord[turnOrder[playerIndex].mage] or tostring(turnOrder[playerIndex].mage),"{en} completed {ru} завершил {zh-tw} 完成了 {zh-cn} 完成了 {ko}이(가) {es} completó {fr} a terminé {pt-br} concluiu {de} schloss ",tostring(pending.source or "the Quest"),"{en}; the random crystal reward is resolved.{ru}; награда случайными кристаллами разрешена.{zh-tw}；隨機水晶獎勵已結算。{zh-cn}；随机水晶奖励已结算。{ko}. 무작위 크리스털 보상이 해결되었습니다.{es}; la recompensa aleatoria de cristales está resuelta.{fr} ; la récompense aléatoire de cristaux est résolue.{pt-br}; a recompensa aleatória de cristais foi resolvida.{de}; die zufällige Kristallbelohnung ist abgewickelt."}),positionToColor(playerIndex))
	QuestPrivate.apocalypseQuestFinishCompletedCard(card)
	if finishQuestResolution~=nil then finishQuestResolution(0.5)
	else safeWaitTime("Quests",function() rewindTransactionFinish("Quest resolve "..tostring(card.guid).." "..tostring(playerIndex)) end,0.5) end
end

--Shared interpretation for random Quest crystal rewards. Every die face has one consistent meaning:
--basic colour grants that crystal; Gold queues a player choice; Black grants +1 Fame.
function QuestPrivate.apocalypseQuestResolveCrystalRollResults(card,playerIndex,results,reason,optionKey,finishQuestResolution)
	if card==nil or turnOrder[playerIndex]==nil then
		if finishQuestResolution~=nil then finishQuestResolution(0.5) end
		return false
	end
	local starting={}
	local reserved={}
	for _,color in ipairs({"Blue","Red","Green","White"}) do starting[color]=mineCrystalCount(playerIndex,color) end
	local gold=0
	local black=0
	for _,rolled in ipairs(results or {}) do
		if rolled=="Gold" then gold=gold+1
		elseif rolled=="Black" then black=black+1
		elseif mineCrystalBagKey[rolled]~=nil then
			local effective=math.max(mineCrystalCount(playerIndex,rolled),starting[rolled]+(reserved[rolled] or 0))
			if effective<3 and apocalypseQuestGiveCrystal(playerIndex,rolled,nil,reason)==true then
				reserved[rolled]=(reserved[rolled] or 0)+1
			end
		end
	end
	if black>0 then
		turnOrder[playerIndex].fameGain=(turnOrder[playerIndex].fameGain or 0)+black
		mainUIUpdate("Quest random crystal Black Fame")
		broadcastToAll(joinLang({tostring(reason or "Quest"),"{en} rolled {ru} выбросил {zh-tw} 擲出 {zh-cn} 掷出 {ko}에서 {es} sacó {fr} a obtenu {pt-br} rolou {de} würfelte ",tostring(black),black==1 and "{en} Black result and gained +1 Fame.{ru} чёрный результат и получил +1 Славу.{zh-tw} 次黑色並獲得 +1 聲望值。{zh-cn} 次黑色并获得 +1 声望值。{ko}개의 검정 결과가 나와 명성 +1을 얻었습니다.{es} resultado Negro y ganó +1 Fama.{fr} résultat Noir et gagne +1 Renommée.{pt-br} resultado Preto e ganhou +1 Fama.{de} schwarzes Ergebnis und erhielt +1 Ruhm." or joinLang({"{en} Black results and gained +{ru} чёрных результата и получил +{zh-tw} 次黑色並獲得 +{zh-cn} 次黑色并获得 +{ko}개의 검정 결과가 나와 명성 +{es} resultados Negros y ganó +{fr} résultats Noirs et gagne +{pt-br} resultados Pretos e ganhou +{de} schwarze Ergebnisse und erhielt +",tostring(black),"{en} Fame.{ru} Славы.{zh-tw} 聲望值。{zh-cn} 声望值。{ko}을(를) 얻었습니다.{es} Fama.{fr} Renommée.{pt-br} Fama.{de} Ruhm."})}),positionToColor(playerIndex))
	end
	local pending={playerIndex=playerIndex,mode="QuestCrystalGold",goldRemaining=gold,source=reason,optionKey=optionKey,startCounts=starting,granted=reserved}
	if gold>0 then
		pending.colors=QuestPrivate.apocalypseQuestCrystalChoiceColors(playerIndex,pending)
		if gStates.apocalypseQuestCombatChoice==nil then gStates.apocalypseQuestCombatChoice={} end
		gStates.apocalypseQuestCombatChoice[card.guid]=pending
		QuestPrivate.apocalypseQuestInterfaceAdd(card,true)
		broadcastToAll(joinLang({tostring(reason or "Quest"),"{en} rolled Gold{ru} выбросил золотой{zh-tw} 擲出金色{zh-cn} 掷出金色{ko}에서 금색이 나왔습니다{es} sacó Dorado{fr} a obtenu Or{pt-br} rolou Dourado{de} würfelte Gold",gold>1 and (" x"..tostring(gold)) or "","{en}: choose {ru}: выберите {zh-tw}：選擇 {zh-cn}：选择 {ko}: {es}: elige {fr} : choisissez {pt-br}: escolha {de}: Wähle ",gold==1 and "{en}a basic mana crystal.{ru}базовый кристалл маны.{zh-tw}一顆基本魔力水晶。{zh-cn}一颗基本魔力水晶。{ko}기본 마나 크리스털 1개를 선택하십시오.{es}un cristal básico de maná.{fr}un cristal de mana de base.{pt-br}um cristal básico de mana.{de}einen Basismana-Kristall." or joinLang({tostring(gold),"{en} basic mana crystals.{ru} базовых кристалла маны.{zh-tw} 顆基本魔力水晶。{zh-cn} 颗基本魔力水晶。{ko}개의 기본 마나 크리스털을 선택하십시오.{es} cristales básicos de maná.{fr} cristaux de mana de base.{pt-br} cristais básicos de mana.{de} Basismana-Kristalle."})}),positionToColor(playerIndex))
		return true
	end
	apocalypseQuestFinishCrystalRollReward(card,playerIndex,pending,finishQuestResolution)
	return true
end

function QuestPrivate.apocalypseQuestNobleWarriorRollReward(card,playerIndex,callback)
	if card==nil or turnOrder[playerIndex]==nil then return false end
	local marker=nil
	local markerColor=nil
	for _,obj in ipairs(apocalypseQuestObjectsOnCard(card)) do
		local color=apocalypseQuestBasicCrystalColor(obj)
		if color~=nil then marker=obj markerColor=color break end
	end
	local count=({Green=1,White=2,Blue=3,Red=4})[markerColor] or 0
	local sourceDie=apocalypseQuestSetupDie()
	if marker==nil or count==0 or sourceDie==nil then return false end

	local markerBag=apocalypseQuestManaBag(markerColor)
	if markerBag~=nil then apocalypseQuestStageIntoContainer(marker,markerBag) else marker.destruct() end
	local cardGUID=card.guid
	local cardPos=card.getPosition()
	local offsets=apocalypseQuestCrystalDiceOffsets(count)
	local dice={}
	for i=1,count do
		local die=sourceDie.clone({position={cardPos[1]+offsets[i][1],cardPos[2]+0.70,cardPos[3]+offsets[i][2]}})
		if die~=nil then
			die.unlock()
			dice[#dice+1]=die.guid
			if gStates.apocalypseQuestRollDice==nil then gStates.apocalypseQuestRollDice={} end
			gStates.apocalypseQuestRollDice[die.guid]=true
		end
	end
	if #dice~=count then
		for _,guid in ipairs(dice) do local die=getObjectFromGUID(guid) if die~=nil then die.destruct() end end
		apocalypseQuestPlaceCrystalOnCard(card,markerColor,0,-0.55,"Noble Warrior")
		return false
	end
	QuestPrivate.apocalypseQuestInterfaceRemove(card)
	broadcastToAll(joinLang({"{en}Noble Warrior is rolling {ru}Noble Warrior бросает {zh-tw}Noble Warrior 正在擲 {zh-cn}Noble Warrior 正在掷 {ko}Noble Warrior가 무작위 크리스털 주사위 {es}Noble Warrior está tirando {fr}Noble Warrior lance {pt-br}Noble Warrior está rolando {de}Noble Warrior würfelt ",tostring(count),count==1 and "{en} random crystal die.{ru} случайный кубик кристалла.{zh-tw} 顆隨機水晶骰。{zh-cn} 颗随机水晶骰。{ko}개를 굴립니다.{es} dado aleatorio de cristal.{fr} dé de cristal aléatoire.{pt-br} dado aleatório de cristal.{de} zufälligen Kristallwürfel." or "{en} random crystal dice.{ru} случайных кубика кристалла.{zh-tw} 顆隨機水晶骰。{zh-cn} 颗随机水晶骰。{ko}개를 굴립니다.{es} dados aleatorios de cristal.{fr} dés de cristal aléatoires.{pt-br} dados aleatórios de cristal.{de} zufällige Kristallwürfel."}),positionToColor(playerIndex))

	local finished=false
	local function clearDice()
		for _,guid in ipairs(dice) do
			local die=getObjectFromGUID(guid)
			if die~=nil then die.destruct() end
			if gStates.apocalypseQuestRollDice~=nil then gStates.apocalypseQuestRollDice[guid]=nil end
		end
	end
	local function failRoll()
		if finished==true then return end
		finished=true
		clearDice()
		local liveCard=getObjectFromGUID(cardGUID)
		if liveCard~=nil then apocalypseQuestPlaceCrystalOnCard(liveCard,markerColor,0,-0.55,"Noble Warrior") end
		if callback~=nil then callback(false,liveCard,nil) end
	end
	local function finishRoll()
		if finished==true then return end
		local results={}
		for _,guid in ipairs(dice) do
			local die=getObjectFromGUID(guid)
			if die==nil then failRoll() return end
			local color=apocalypseQuestManaDieColor(die)
			if color==nil then failRoll() return end
			results[#results+1]=color
		end
		finished=true
		safeWaitTime("Quests",function()
			clearDice()
			if callback~=nil then callback(true,getObjectFromGUID(cardGUID),results) end
		end,0.8)
	end
	apocalypseQuestPhysicalDiceRoll(dice,finishRoll,failRoll)
	return true
end

function QuestPrivate.apocalypseQuestUnderSiegeFailure(card,playerIndex)
	local marker=getObjectFromGUID("4c5f97")
	if marker==nil then return end
	local pos=marker.getPosition()
	local spatial=runtimeMapSpatialSnapshot()
	for _, obj in ipairs(runtimeMapSpatialNearbyObjects(spatial,pos,1.1)) do
		if obj.getName()=="Shield" and volkarePursuitShieldRegistered(obj)~=true and turnOrder[playerIndex]~=nil and obj.getDescription()==turnOrder[playerIndex].mage then
			local p=spatial.positions[obj.guid] or obj.getPosition()
			if ((p[1]-pos[1])^2)+((p[3]-pos[3])^2)<1 then obj.destruct() break end
		end
	end
	local enemies={}
	for _, obj in ipairs(apocalypseQuestObjectsOnCard(card)) do if monsterPugs[obj.guid]~=nil then enemies[obj.guid]=obj end end
	if gStates.apocalypseQuestCombatEnemies~=nil and gStates.apocalypseQuestCombatEnemies[card.guid]~=nil then
		for guid,_ in pairs(gStates.apocalypseQuestCombatEnemies[card.guid]) do
			local obj=getObjectFromGUID(guid)
			if obj~=nil and obj.is_face_down==true then enemies[guid]=obj end
		end
	end
	local offset=0
	for guid,obj in pairs(enemies) do
		obj.unlock()
		obj.setRotationSmooth({0,180,0})
		obj.setPositionSmooth({pos[1]+offset,pos[2]+0.6,pos[3]})
		if gStates.attackedMonsters~=nil then gStates.attackedMonsters[guid]=nil end
		if gStates.monsterPlayLocation~=nil then gStates.monsterPlayLocation[guid]=nil end
		offset=offset+0.35
	end
end

local apocalypseQuestEnemyDiscardByType={
	gray=GUID.bag.discard.keepGarrison,
	purple=GUID.bag.discard.towerGarrison,
	white=GUID.bag.discard.cityGarrison,
	red=GUID.bag.discard.draconum,
	green=GUID.bag.discard.orcs,
	tan=GUID.bag.discard.dungeon
}

local function apocalypseQuestDetachPossessedForDiscard(enemy)
	if enemy==nil then return end
	local detached=clearPossessedEnemy(enemy)
	local possessedDiscard=getObjectFromGUID(GUID.bag.discard.possessed)
	for _,token in pairs(detached or {}) do
		if possessedDiscard~=nil then possessedDiscard.putObject(token) else token.destruct() end
	end
end

local function apocalypseQuestEnemyDiscardDestination(enemy)
	if enemy==nil or monsterPugs[enemy.guid]==nil then return nil end
	local discardGUID=apocalypseQuestEnemyDiscardByType[monsterPugs[enemy.guid].pugType]
	return discardGUID~=nil and getObjectFromGUID(discardGUID) or nil
end

local function apocalypseQuestDiscardEnemyNow(enemy)
	if enemy==nil then return false end
	apocalypseQuestDetachPossessedForDiscard(enemy)
	local discard=apocalypseQuestEnemyDiscardDestination(enemy)
	if discard==nil then return false end
	enemy.unlock()
	discard.putObject(enemy)
	return true
end

--Mine of Doom is unusual: an unsuccessful attempt still discards its undefeated enemies instead of
--returning them to a map site. Remove those face-down survivors during normal pre-end-turn cleanup so
--the board is already clear when the Rewards Claimed stage appears. Defeated face-up enemies remain
--for the standard combat cleanup so their normal Fame/reward processing is preserved.
function QuestPrivate.apocalypseQuestMineDoomUndefeatedCleanup(playerIndex)
	if gStates.apocalypseQuestCombatEnemies==nil or gStates.apocalypseQuestCombatEnemies["485cc5"]==nil then return false end
	local removed=false
	for guid,_ in pairs(gStates.apocalypseQuestCombatEnemies["485cc5"]) do
		local enemy=getObjectFromGUID(guid)
		if enemy~=nil and enemy.is_face_down==true then
			apocalypseQuestDiscardEnemyNow(enemy)
			if gStates.attackedMonsters~=nil then gStates.attackedMonsters[guid]=nil end
			if gStates.monsterPlayLocation~=nil then gStates.monsterPlayLocation[guid]=nil end
			removed=true
		end
	end
	if removed==true then broadcastToAll("{en}Mine of Doom: undefeated Quest enemies were discarded at the end of the attempt.{ru}Mine of Doom: непобеждённые враги задания сброшены в конце попытки.{zh-tw}Mine of Doom：本次嘗試結束時，未被擊敗的任務敵人已棄掉。{zh-cn}Mine of Doom：本次尝试结束时，未被击败的任务敌人已弃掉。{ko}Mine of Doom: 시도 종료 시 쓰러뜨리지 못한 퀘스트 적을 버렸습니다.{es}Mine of Doom: los enemigos de Misión no derrotados se descartaron al final del intento.{fr}Mine of Doom : les ennemis de Quête non vaincus ont été défaussés à la fin de la tentative.{pt-br}Mine of Doom: os inimigos da Missão não derrotados foram descartados no fim da tentativa.{de}Mine of Doom: Nicht besiegte Quest-Gegner wurden am Ende des Versuchs abgeworfen.",positionToColor(playerIndex)) end
	return removed
end

function apocalypseQuestMineDoomEndTurnCleanup(playerIndex)
	if gStates.apocalypseQuestCombatEnemies==nil or gStates.apocalypseQuestCombatEnemies["485cc5"]==nil then return false end
	local removed=false
	for guid,_ in pairs(gStates.apocalypseQuestCombatEnemies["485cc5"]) do
		local enemy=getObjectFromGUID(guid)
		if enemy~=nil then
			apocalypseQuestDiscardEnemyNow(enemy)
			removed=true
		end
		if gStates.attackedMonsters~=nil then gStates.attackedMonsters[guid]=nil end
		if gStates.monsterPlayLocation~=nil then gStates.monsterPlayLocation[guid]=nil end
	end
	gStates.apocalypseQuestCombatEnemies["485cc5"]=nil
	gStates.apocalypseQuestCombatLaunches["485cc5"]=nil
	if removed==true then broadcastToAll("{en}Mine of Doom: remaining Quest combat enemy tokens were discarded.{ru}Mine of Doom: оставшиеся жетоны врагов боя задания сброшены.{zh-tw}Mine of Doom：剩餘的任務戰鬥敵人標記已棄掉。{zh-cn}Mine of Doom：剩余的任务战斗敌人标记已弃掉。{ko}Mine of Doom: 남은 퀘스트 전투 적 토큰을 버렸습니다.{es}Mine of Doom: se descartaron las fichas de enemigo restantes del combate de Misión.{fr}Mine of Doom : les jetons Ennemi restants du combat de Quête ont été défaussés.{pt-br}Mine of Doom: as fichas de inimigo restantes do combate da Missão foram descartadas.{de}Mine of Doom: Die verbleibenden Gegner-Marker des Quest-Kampfes wurden abgeworfen.",positionToColor(playerIndex)) end
	return true
end

function QuestPrivate.apocalypseQuestResolveFailureEffect(card,playerIndex,option)
	if card==nil or option==nil then return end
	local handler=apocalypseQuestHandler(card)
	if handler~=nil and handler.failureEffect~=nil then handler.failureEffect(card,playerIndex,option) end
end

function apocalypseQuestRichMerchantStartTurn()
	local card=getObjectFromGUID("8cff07")
	local playerIndex=gStates.turnNumber
	if card==nil or turnOrder[playerIndex]==nil then return false end
	local record=gStates.apocalypseQuestRichMerchantHidden~=nil and gStates.apocalypseQuestRichMerchantHidden[card.guid] or nil
	if record==nil or record.mage~=turnOrder[playerIndex].mage or record.spawned==true then return false end
	local state=QuestPrivate.apocalypseQuestProgressState(card,playerIndex,false)
	if state==nil or state.step~=2 then return false end
	local enemy=QuestPrivate.apocalypseQuestSpawnEnemyToCombat(card,playerIndex,"gray",false,0,0)
	if enemy==nil then return false end
	record.spawned=true
	QuestPrivate.apocalypseQuestMarkCombatStarted(card,2)
	if gStates.apocalypseQuestCombatLaunches==nil then gStates.apocalypseQuestCombatLaunches={} end
	gStates.apocalypseQuestCombatLaunches[card.guid]=QuestPrivate.apocalypseQuestCombatLaunchKey(card,state)
	broadcastToAll(joinLang({"{en}A Rich Merchant: the hidden ally attacks at the start of {ru}A Rich Merchant: скрытый союзник атакует в начале хода {zh-tw}A Rich Merchant：隱藏盟友在 {zh-cn}A Rich Merchant：隐藏盟友在 {ko}A Rich Merchant: 숨겨진 동료가 {es}A Rich Merchant: el aliado oculto ataca al comienzo del turno de {fr}A Rich Merchant : l’allié caché attaque au début du tour de {pt-br}A Rich Merchant: o aliado oculto ataca no início do turno de {de}A Rich Merchant: Der verborgene Verbündete greift zu Beginn des Zuges von ",translateWord[turnOrder[playerIndex].mage] or tostring(turnOrder[playerIndex].mage),"{en}'s turn.{ru}.{zh-tw} 的回合開始時攻擊。{zh-cn} 的回合开始时攻击。{ko}의 턴 시작에 공격합니다.{es}.{fr}.{pt-br}.{de} an."}),positionToColor(playerIndex))
	safeWaitFrames("Quests",function() if getObjectFromGUID(card.guid)~=nil then QuestPrivate.apocalypseQuestInterfaceAdd(card,true) end end,2)
	return true
end

-- Quest-specific resolution effects live on the same per-Quest handlers as legality/combat metadata.
apocalypseQuestRegisterHandler("8939c0").resolveEffect=function(card,playerIndex,option,finalCompletion)
	local key=tostring(option.key)
		if key=="1a" then
			turnOrder[playerIndex].fameGain=(turnOrder[playerIndex].fameGain or 0)+1
			apocalypseQuestGainReputation(playerIndex,"The Execution")
			mainUIUpdate("Quest Fame/Reputation reward")
		elseif key=="1b" then
			turnOrder[playerIndex].fameGain=(turnOrder[playerIndex].fameGain or 0)+1
			mainUIUpdate("Quest Fame reward")
		elseif key=="1c" then
			turnOrder[playerIndex].fameGain=(turnOrder[playerIndex].fameGain or 0)+1
			apocalypseQuestLoseReputation(playerIndex,"The Execution","effect")
			mainUIUpdate("Quest Fame reward")
		end
end

apocalypseQuestRegisterHandler("58a826").resolveEffect=function(card,playerIndex,option,finalCompletion)
	local key=tostring(option.key)
		if key=="2" then
			local hex=QuestPrivate.apocalypseQuestCurrentPlayerHex(playerIndex)
			local terrainColor=hex~=nil and ({plains="White",forest="Green",wasteland="Red",swamp="Blue"})[hex.hexType] or nil
			if terrainColor~=nil then apocalypseQuestPlaceCrystalOnCard(card,terrainColor,0,-0.55,"The Eager Herbalist") end
		end
end

apocalypseQuestRegisterHandler("734740").resolveEffect=function(card,playerIndex,option,finalCompletion)
	local key=tostring(option.key)
	if key=="3" then
		apocalypseQuestGiveProveYourselfReward(card,playerIndex)
	end
end

apocalypseQuestRegisterHandler("72099f").resolveEffect=function(card,playerIndex,option,finalCompletion)
	local key=tostring(option.key)
		if key=="1" and turnOrder[playerIndex]~=nil and gStates.apocalypseQuestGoblinWarrens~=nil then
			gStates.apocalypseQuestGoblinWarrens[turnOrder[playerIndex].mage]=nil
		elseif key=="2" and finalCompletion==true then
			apocalypseQuestFlipSiteToken("02f996")
		end
end

apocalypseQuestRegisterHandler("8cdac4").resolveEffect=function(card,playerIndex,option,finalCompletion)
	local key=tostring(option.key)
		if key=="2" then
			local level=turnOrder[playerIndex].level or 1
			apocalypseQuestPlaceEnemy(card,level<=3 and "gray" or level<=6 and "purple" or "white",true,0)
		elseif key=="3" then
			apocalypseQuestGiveTuckedCard(playerIndex,card,"Spell")
		end
end

apocalypseQuestRegisterHandler("66ea80").resolveEffect=function(card,playerIndex,option,finalCompletion)
	local key=tostring(option.key)
	if key=="1" then
		--Fistful's two gray enemies are placed after the Quest offer finishes moving. Drawing both from the
		--same bag while the card is also relocating can lose a spawn/attachment race in TTS.
		return
	end
end

apocalypseQuestRegisterHandler("37e2ce").resolveEffect=function(card,playerIndex,option,finalCompletion)
	local key=tostring(option.key)
	if key=="1a" then
		QuestPrivate.apocalypseQuestFreeWineStartAssault(card,playerIndex)
	end
end

apocalypseQuestRegisterHandler("485cc5").resolveEffect=function(card,playerIndex,option,finalCompletion)
	local key=tostring(option.key)
	if key=="1" then
		local color=gStates.apocalypseQuestStepColor~=nil and gStates.apocalypseQuestStepColor[card.guid] or nil
		local colors=QuestPrivate.apocalypseQuestMineDoomColors(playerIndex)
		if color~=nil then
			if gStates.apocalypseQuestMineDoomColor==nil then gStates.apocalypseQuestMineDoomColor={} end
			gStates.apocalypseQuestMineDoomColor[card.guid]=color
			local launched=QuestPrivate.apocalypseQuestLaunchMineDoom(card,playerIndex,color,#colors>1 and 1 or 0)
			if launched==true then QuestPrivate.apocalypseQuestMarkCombatStarted(card,2) end
		end
	end
	if key=="2" and finalCompletion==true then
		broadcastToAll("{en}Mine of Doom reward: gain an Artifact.{ru}Награда Mine of Doom: получите Артефакт.{zh-tw}Mine of Doom 獎勵：獲得一件神器。{zh-cn}Mine of Doom 奖励：获得一件神器。{ko}Mine of Doom 보상: 유물 하나를 얻습니다.{es}Recompensa de Mine of Doom: gana un Artefacto.{fr}Récompense de Mine of Doom : gagnez un Artefact.{pt-br}Recompensa de Mine of Doom: ganhe um Artefato.{de}Belohnung für Mine of Doom: Erhalte ein Artefakt.",positionToColor(playerIndex))
	end
end

apocalypseQuestRegisterHandler("b401dc").resolveEffect=function(card,playerIndex,option,finalCompletion)
	local key=tostring(option.key)
		if key=="1" then
			local token=getObjectFromGUID("7e4e4c")
			if token~=nil then QuestPrivate.apocalypseQuestHighlightMarker(token) end
			broadcastToAll("{en}A Very Personal Quest: recruit an eligible Unit here for free and place the highlighted Quest token on that Unit.{ru}A Very Personal Quest: бесплатно наймите здесь подходящий отряд и поместите выделенный жетон задания на этот отряд.{zh-tw}A Very Personal Quest：在此免費招募符合條件的部隊，並將高亮任務標記放在該部隊上。{zh-cn}A Very Personal Quest：在此免费招募符合条件的部队，并将高亮任务标记放在该部队上。{ko}A Very Personal Quest: 여기서 조건에 맞는 유닛 하나를 무료로 모집하고 강조된 퀘스트 토큰을 그 유닛 위에 놓으십시오.{es}A Very Personal Quest: recluta aquí gratis una Unidad válida y coloca la ficha de Misión resaltada sobre esa Unidad.{fr}A Very Personal Quest : recrutez gratuitement ici une Unité éligible et placez le jeton de Quête surligné sur cette Unité.{pt-br}A Very Personal Quest: recrute aqui gratuitamente uma Unidade elegível e coloque a ficha de Missão destacada nessa Unidade.{de}A Very Personal Quest: Rekrutiere hier kostenlos eine geeignete Einheit und lege den hervorgehobenen Questmarker auf diese Einheit.",positionToColor(playerIndex))
		elseif key=="2" then
			if gStates.apocalypseQuestVeryPersonalSuccess==nil then gStates.apocalypseQuestVeryPersonalSuccess={} end
			gStates.apocalypseQuestVeryPersonalSuccess[card.guid]=true
			broadcastToAll("{en}A Very Personal Quest: the protected Unit survived the Mage Tower rescue; its Quest marker will be returned.{ru}A Very Personal Quest: защищаемый отряд пережил спасение Башни мага; его жетон задания будет возвращён.{zh-tw}A Very Personal Quest：受保護部隊在法師塔救援中存活；其任務標記將被歸還。{zh-cn}A Very Personal Quest：受保护部队在法师塔救援中存活；其任务标记将被归还。{ko}A Very Personal Quest: 보호 대상 유닛이 마법사 탑 구출에서 살아남았습니다. 퀘스트 토큰을 반환합니다.{es}A Very Personal Quest: la Unidad protegida sobrevivió al rescate de la Torre de Mago; se devolverá su ficha de Misión.{fr}A Very Personal Quest : l’Unité protégée a survécu au sauvetage de la Tour de Mage ; son jeton de Quête sera rendu.{pt-br}A Very Personal Quest: a Unidade protegida sobreviveu ao resgate da Torre de Mago; sua ficha de Missão será devolvida.{de}A Very Personal Quest: Die geschützte Einheit hat die Rettung am Magierturm überlebt; ihr Questmarker wird zurückgegeben.",positionToColor(playerIndex))
		end
end

apocalypseQuestRegisterHandler("82a935").resolveEffect=function(card,playerIndex,option,finalCompletion)
	local key=tostring(option.key)
	if key=="2a" then
		QuestPrivate.apocalypseQuestRestoreBurnedMonastery(card,playerIndex)
		QuestPrivate.apocalypseQuestAddAdvancedActionToUnitOffer()
		apocalypseQuestGainReputation(playerIndex,"The Burned Monastery")
	end
end

apocalypseQuestRegisterHandler("8455b5").resolveEffect=function(card,playerIndex,option,finalCompletion)
	local key=tostring(option.key)
		if key=="1" then
			broadcastToAll("{en}The Admiring Bard: defeat an enemy token to continue. Non-Red/non-Tan = 2a (Green), Tan = 2b (Blue), Red = 2c (Red).{ru}The Admiring Bard: победите жетон врага, чтобы продолжить. Не красный/не бежевый = 2a (зелёный), бежевый = 2b (синий), красный = 2c (красный).{zh-tw}The Admiring Bard：擊敗一個敵人標記以繼續。非紅／非棕 = 2a（綠），棕 = 2b（藍），紅 = 2c（紅）。{zh-cn}The Admiring Bard：击败一个敌人标记以继续。非红／非棕 = 2a（绿），棕 = 2b（蓝），红 = 2c（红）。{ko}The Admiring Bard: 계속하려면 적 토큰 하나를 처치하십시오. 빨강/황갈색 아님 = 2a(녹색), 황갈색 = 2b(파란색), 빨강 = 2c(빨간색).{es}The Admiring Bard: derrota una ficha de enemigo para continuar. No Rojo/no Canela = 2a (Verde), Canela = 2b (Azul), Rojo = 2c (Rojo).{fr}The Admiring Bard : vainquez un jeton Ennemi pour continuer. Ni Rouge ni Fauve = 2a (Vert), Fauve = 2b (Bleu), Rouge = 2c (Rouge).{pt-br}The Admiring Bard: derrote uma ficha de inimigo para continuar. Não Vermelho/não Bege = 2a (Verde), Bege = 2b (Azul), Vermelho = 2c (Vermelho).{de}The Admiring Bard: Besiege einen Gegnermarker, um fortzufahren. Nicht Rot/nicht Hellbraun = 2a (Grün), Hellbraun = 2b (Blau), Rot = 2c (Rot).",positionToColor(playerIndex))
		elseif key=="2a" then
			apocalypseQuestPlaceCrystalOnCard(card,"Green",0,-0.55,"The Admiring Bard")
			broadcastToAll("{en}The Admiring Bard: return to a Village, Monastery, City or Oasis to finish the song.{ru}The Admiring Bard: вернитесь в Деревню, Монастырь, Город или Оазис, чтобы закончить песню.{zh-tw}The Admiring Bard：返回村莊、修道院、城市或綠洲以完成歌曲。{zh-cn}The Admiring Bard：返回村庄、修道院、城市或绿洲以完成歌曲。{ko}The Admiring Bard: 노래를 마치려면 마을, 수도원, 도시 또는 오아시스로 돌아가십시오.{es}The Admiring Bard: regresa a una Aldea, Monasterio, Ciudad u Oasis para terminar la canción.{fr}The Admiring Bard : retournez dans un Village, Monastère, Cité ou Oasis pour terminer la chanson.{pt-br}The Admiring Bard: volte a uma Vila, Mosteiro, Cidade ou Oásis para terminar a canção.{de}The Admiring Bard: Kehre in ein Dorf, Kloster, eine Stadt oder Oase zurück, um das Lied zu beenden.",positionToColor(playerIndex))
		elseif key=="2b" then
			apocalypseQuestPlaceCrystalOnCard(card,"Blue",0,-0.55,"The Admiring Bard")
			broadcastToAll("{en}The Admiring Bard: return to a Village, Monastery, City or Oasis to finish the song.{ru}The Admiring Bard: вернитесь в Деревню, Монастырь, Город или Оазис, чтобы закончить песню.{zh-tw}The Admiring Bard：返回村莊、修道院、城市或綠洲以完成歌曲。{zh-cn}The Admiring Bard：返回村庄、修道院、城市或绿洲以完成歌曲。{ko}The Admiring Bard: 노래를 마치려면 마을, 수도원, 도시 또는 오아시스로 돌아가십시오.{es}The Admiring Bard: regresa a una Aldea, Monasterio, Ciudad u Oasis para terminar la canción.{fr}The Admiring Bard : retournez dans un Village, Monastère, Cité ou Oasis pour terminer la chanson.{pt-br}The Admiring Bard: volte a uma Vila, Mosteiro, Cidade ou Oásis para terminar a canção.{de}The Admiring Bard: Kehre in ein Dorf, Kloster, eine Stadt oder Oase zurück, um das Lied zu beenden.",positionToColor(playerIndex))
		elseif key=="2c" then
			apocalypseQuestPlaceCrystalOnCard(card,"Red",0,-0.55,"The Admiring Bard")
			broadcastToAll("{en}The Admiring Bard: return to a Village, Monastery, City or Oasis to finish the song.{ru}The Admiring Bard: вернитесь в Деревню, Монастырь, Город или Оазис, чтобы закончить песню.{zh-tw}The Admiring Bard：返回村莊、修道院、城市或綠洲以完成歌曲。{zh-cn}The Admiring Bard：返回村庄、修道院、城市或绿洲以完成歌曲。{ko}The Admiring Bard: 노래를 마치려면 마을, 수도원, 도시 또는 오아시스로 돌아가십시오.{es}The Admiring Bard: regresa a una Aldea, Monasterio, Ciudad u Oasis para terminar la canción.{fr}The Admiring Bard : retournez dans un Village, Monastère, Cité ou Oasis pour terminer la chanson.{pt-br}The Admiring Bard: volte a uma Vila, Mosteiro, Cidade ou Oásis para terminar a canção.{de}The Admiring Bard: Kehre in ein Dorf, Kloster, eine Stadt oder Oase zurück, um das Lied zu beenden.",positionToColor(playerIndex))
		elseif key=="3" then
			apocalypseQuestGiveBardReward(card,playerIndex)
		end
end

apocalypseQuestRegisterHandler("abd4fb").resolveEffect=function(card,playerIndex,option,finalCompletion)
	local key=tostring(option.key)
		if key=="1" then
			if gStates.apocalypseQuestCursedHero==nil then gStates.apocalypseQuestCursedHero={} end
			apocalypseQuestCursedMarkHolder(card,playerIndex)
			gStates.apocalypseQuestCursedHero[card.guid]=turnOrder[playerIndex].mage
			broadcastToAll(joinLang({translateWord[turnOrder[playerIndex].mage] or tostring(turnOrder[playerIndex].mage),"{en} is now the cursed Hero. Apply +1 Armor and +1 to each enemy attack manually while this Quest remains active.{ru} теперь проклятый Герой. Пока это задание активно, вручную добавляйте +1 к Броне и +1 к каждой атаке врагов.{zh-tw} 現在是受詛咒英雄。此任務保持啟用時，請手動讓每個敵人 +1 護甲、每次攻擊 +1。{zh-cn} 现在是受诅咒英雄。此任务保持启用时，请手动让每个敌人 +1 护甲、每次攻击 +1。{ko}이(가) 이제 저주받은 영웅입니다. 이 퀘스트가 활성화된 동안 각 적에게 방어력 +1과 모든 공격 +1을 수동으로 적용하십시오.{es} es ahora el Héroe maldito. Aplica manualmente +1 Armadura y +1 a cada ataque enemigo mientras esta Misión siga activa.{fr} est désormais le Héros maudit. Appliquez manuellement +1 Armure et +1 à chaque attaque ennemie tant que cette Quête reste active.{pt-br} agora é o Herói amaldiçoado. Aplique manualmente +1 Armadura e +1 a cada ataque inimigo enquanto esta Missão permanecer ativa.{de} ist nun der verfluchte Held. Solange diese Quest aktiv ist, wende manuell +1 Rüstung und +1 auf jeden Gegnerangriff an."}),positionToColor(playerIndex))
		elseif key=="2a" then
			local targetIndex=apocalypseQuestCursedTargetIndex(card,playerIndex)
			if targetIndex==nil then
				local eligible=apocalypseQuestCursedEligibleTargets(card,playerIndex)
				if #eligible==1 then targetIndex=eligible[1] end
			end
			if targetIndex~=nil and turnOrder[targetIndex]~=nil and apocalypseQuestCursedAutoShield(card,playerIndex,targetIndex)==true then
				local targetState=QuestPrivate.apocalypseQuestProgressState(card,targetIndex,true)
				if targetState~=nil then targetState.step=2 end
				apocalypseQuestCursedMarkHolder(card,targetIndex)
				gStates.apocalypseQuestCursedHero[card.guid]=turnOrder[targetIndex].mage
				broadcastToAll(joinLang({translateWord[turnOrder[targetIndex].mage] or tostring(turnOrder[targetIndex].mage),"{en} is now the cursed Hero. The enemy +1 Armor/+1 Attack effect remains player-managed.{ru} теперь проклятый Герой. Эффект врагов +1 Броня/+1 Атака по-прежнему отслеживается игроками вручную.{zh-tw} 現在是受詛咒英雄。敵人 +1 護甲／+1 攻擊效果仍由玩家手動管理。{zh-cn} 现在是受诅咒英雄。敌人 +1 护甲／+1 攻击效果仍由玩家手动管理。{ko}이(가) 이제 저주받은 영웅입니다. 적의 방어력 +1/공격 +1 효과는 계속 플레이어가 수동으로 관리합니다.{es} es ahora el Héroe maldito. El efecto enemigo de +1 Armadura/+1 Ataque sigue gestionándose manualmente.{fr} est désormais le Héros maudit. L’effet ennemi +1 Armure/+1 Attaque reste géré manuellement par les joueurs.{pt-br} agora é o Herói amaldiçoado. O efeito inimigo de +1 Armadura/+1 Ataque continua sendo gerenciado manualmente pelos jogadores.{de} ist nun der verfluchte Held. Der Gegner-Effekt +1 Rüstung/+1 Angriff bleibt spielerverwaltet."}),positionToColor(targetIndex))
			else
				broadcastToAll("{en}Cursed: place the chosen adjacent Hero's Shield on this Quest before using Pass the curse on.{ru}Cursed: поместите щит выбранного соседнего Героя на это задание перед использованием Pass the curse on.{zh-tw}Cursed：使用 Pass the curse on 前，先將所選相鄰英雄的盾牌放到此任務上。{zh-cn}Cursed：使用 Pass the curse on 前，先将所选相邻英雄的盾牌放到此任务上。{ko}Cursed: Pass the curse on을 사용하기 전에 선택한 인접 영웅의 방패를 이 퀘스트에 놓으십시오.{es}Cursed: coloca el Escudo del Héroe adyacente elegido sobre esta Misión antes de usar Pass the curse on.{fr}Cursed : placez le Bouclier du Héros adjacent choisi sur cette Quête avant d’utiliser Pass the curse on.{pt-br}Cursed: coloque o Escudo do Herói adjacente escolhido nesta Missão antes de usar Pass the curse on.{de}Cursed: Lege den Schild des gewählten benachbarten Helden auf diese Quest, bevor du Pass the curse on verwendest.",positionToColor(playerIndex))
			end
		elseif key=="2b" then
			apocalypseQuestGainReputation(playerIndex,"Cursed")
			if gStates.apocalypseQuestCursedHero~=nil then gStates.apocalypseQuestCursedHero[card.guid]=nil end
		end
end

apocalypseQuestRegisterHandler("d70436").resolveEffect=function(card,playerIndex,option,finalCompletion)
	local key=tostring(option.key)
		if key=="2" then
			local level=turnOrder[playerIndex].level or 1
			local pile=level<=4 and "tan" or level<=8 and "white" or "red"
			if QuestPrivate.apocalypseQuestSpawnEnemyToCombat(card,playerIndex,pile,false,0,0)~=nil then
				QuestPrivate.apocalypseQuestMarkCombatStarted(card,3)
				local shield=QuestPrivate.apocalypseQuestPlayerShield(card,playerIndex)
				if shield~=nil then
					local p=apocalypseQuestMoveAttachmentTarget(card,shield) or apocalypseQuestPlannedWorldPosition(card,shield.getPosition())
					local target={p[1],p[2],p[3]-0.55}
					shield.setPositionSmooth(target)
					apocalypseQuestRegisterMoveAttachment(card,shield,target)
				end
			end
		elseif key=="3" and finalCompletion==true then
			local level=turnOrder[playerIndex].level or 1
			local reward=level<=4 and "an Advanced Action" or level<=8 and "a Spell" or "an Artifact"
			broadcastToAll(joinLang({"{en}A Mysterious Island reward: gain {ru}Награда A Mysterious Island: получите {zh-tw}A Mysterious Island 獎勵：獲得 {zh-cn}A Mysterious Island 奖励：获得 {ko}A Mysterious Island 보상: {es}Recompensa de A Mysterious Island: gana {fr}Récompense de A Mysterious Island : gagnez {pt-br}Recompensa de A Mysterious Island: ganhe {de}Belohnung für A Mysterious Island: Erhalte ",reward,"."}),positionToColor(playerIndex))
		end
end

apocalypseQuestRegisterHandler("c73a1f").resolveEffect=function(card,playerIndex,option,finalCompletion)
	local key=tostring(option.key)
	if key=="3" and finalCompletion==true then
		broadcastToAll("{en}Tomb of the Lost King reward: gain an Artifact.{ru}Награда Tomb of the Lost King: получите Артефакт.{zh-tw}Tomb of the Lost King 獎勵：獲得一件神器。{zh-cn}Tomb of the Lost King 奖励：获得一件神器。{ko}Tomb of the Lost King 보상: 유물 하나를 얻습니다.{es}Recompensa de Tomb of the Lost King: gana un Artefacto.{fr}Récompense de Tomb of the Lost King : gagnez un Artefact.{pt-br}Recompensa de Tomb of the Lost King: ganhe um Artefato.{de}Belohnung für Tomb of the Lost King: Erhalte ein Artefakt.",positionToColor(playerIndex))
	end
	if key=="2" and apocalypseQuestCardHasEnemyType(card,"white")~=true then
		apocalypseQuestPlaceEnemy(card,"white",false,0)
	end
end

apocalypseQuestRegisterHandler("77bbac").resolveEffect=function(card,playerIndex,option,finalCompletion)
	local key=tostring(option.key)
	if key=="2" then
		broadcastToAll("{en}The Child Seer: resolve the destiny matching the mana token on your Shield (or pay matching mana to choose another destiny).{ru}The Child Seer: разрешите судьбу, соответствующую жетону маны на вашем Щите (или заплатите совпадающую ману, чтобы выбрать другую судьбу).{zh-tw}The Child Seer：結算與你盾牌上魔力標記相符的命運（或支付相符魔力以選擇另一個命運）。{zh-cn}The Child Seer：结算与你盾牌上魔力标记相符的命运（或支付相符魔力以选择另一个命运）。{ko}The Child Seer: 방패 위의 마나 토큰과 일치하는 운명을 해결하십시오(또는 일치하는 마나를 지불해 다른 운명을 선택하십시오).{es}The Child Seer: resuelve el destino que coincida con la ficha de maná de tu Escudo (o paga maná coincidente para elegir otro destino).{fr}The Child Seer : résolvez le destin correspondant au jeton de mana sur votre Bouclier (ou payez le mana correspondant pour choisir un autre destin).{pt-br}The Child Seer: resolva o destino correspondente à ficha de mana em seu Escudo (ou pague mana correspondente para escolher outro destino).{de}The Child Seer: Führe das Schicksal aus, das dem Manamarker auf deinem Schild entspricht (oder zahle passendes Mana, um ein anderes Schicksal zu wählen).",positionToColor(playerIndex))
	end
	if key=="1" then
		apocalypseQuestPlaceRandomCrystalOnShield(card,playerIndex)
	end
end

apocalypseQuestRegisterHandler("8cff07").resolveEffect=function(card,playerIndex,option,finalCompletion)
	local key=tostring(option.key)
	if key=="1" and finalCompletion~=true then
		--A Rich Merchant Step 1 is resolved by the visible physical mana-die path in ResolveStepAction.
		return
	end
end

apocalypseQuestRegisterHandler("082f39").resolveEffect=function(card,playerIndex,option,finalCompletion)
	local key=tostring(option.key)
	if key=="1" then
		QuestPrivate.apocalypseQuestTravellingMerchantRelocate(card,playerIndex)
	end
end

apocalypseQuestRegisterHandler("ce70fb").resolveEffect=function(card,playerIndex,option,finalCompletion)
	local key=tostring(option.key)
	if QuestPrivate.apocalypseQuestStepNumber(key)==2 then
		local level=turnOrder[playerIndex].level or 1
		local reward=nil
		if key=="2a" then reward=level<=4 and "a random mana crystal" or level<=8 and "an Advanced Action" or "a Spell"
		else reward=level<=2 and "an Advanced Action" or level<=6 and "a Spell" or "an Artifact" end
		broadcastToAll(joinLang({"{en}Traitor {ru}Traitor {zh-tw}Traitor {zh-cn}Traitor {ko}Traitor {es}Traitor {fr}Traitor {pt-br}Traitor {de}Traitor ",key,"{en} reward: gain {ru}, награда: получите {zh-tw} 獎勵：獲得 {zh-cn} 奖励：获得 {ko} 보상: {es}, recompensa: gana {fr}, récompense : gagnez {pt-br}, recompensa: ganhe {de}, Belohnung: Erhalte ",reward,"{en}. The generated Possessed enemy is Council of the Void faction.{ru}. Созданный Одержимый враг относится к фракции Совета Пустоты.{zh-tw}。產生的附身敵人屬於虛空議會陣營。{zh-cn}。产生的附身敌人属于虚空议会阵营。{ko}. 생성된 빙의 적은 공허의 의회 진영입니다.{es}. El enemigo Poseído generado pertenece a la facción Consejo del Vacío.{fr}. L’ennemi Possédé généré appartient à la faction Conseil du Vide.{pt-br}. O inimigo Possuído gerado pertence à facção Conselho do Vácuo.{de}. Der erzeugte Besessen-Gegner gehört zur Fraktion Rat der Leere."}),positionToColor(playerIndex))
	end
end

apocalypseQuestRegisterHandler("dd35bb").resolveEffect=function(card,playerIndex,option,finalCompletion)
	local key=tostring(option.key)
		if key=="1" then
			if QuestPrivate.apocalypseQuestFogEnemy(card)==nil then apocalypseQuestPlaceEnemy(card,"tan",true,0) end
		elseif key=="2" then
			local enemy=QuestPrivate.apocalypseQuestFogEnemy(card)
			if enemy~=nil and QuestPrivate.apocalypseQuestFogPossessedReady(card)~=true then QuestPrivate.apocalypseQuestPossessExistingEnemy(card,enemy,"Apoc") end
		elseif key=="3" and finalCompletion==true then
			broadcastToAll("{en}The Fog reward: gain an Artifact.{ru}Награда The Fog: получите Артефакт.{zh-tw}The Fog 獎勵：獲得一件神器。{zh-cn}The Fog 奖励：获得一件神器。{ko}The Fog 보상: 유물 하나를 얻습니다.{es}Recompensa de The Fog: gana un Artefacto.{fr}Récompense de The Fog : gagnez un Artefact.{pt-br}Recompensa de The Fog: ganhe um Artefato.{de}Belohnung für The Fog: Erhalte ein Artefakt.",positionToColor(playerIndex))
		end
end

apocalypseQuestRegisterHandler("783076").resolveEffect=function(card,playerIndex,option,finalCompletion)
	local key=tostring(option.key)
	if key=="2" and finalCompletion==true then
		broadcastToAll("{en}Hunter's Moon reward: gain an Artifact.{ru}Награда Hunter's Moon: получите Артефакт.{zh-tw}Hunter's Moon 獎勵：獲得一件神器。{zh-cn}Hunter's Moon 奖励：获得一件神器。{ko}Hunter's Moon 보상: 유물 하나를 얻습니다.{es}Recompensa de Hunter's Moon: gana un Artefacto.{fr}Récompense de Hunter's Moon : gagnez un Artefact.{pt-br}Recompensa de Hunter's Moon: ganhe um Artefato.{de}Belohnung für Hunter's Moon: Erhalte ein Artefakt.",positionToColor(playerIndex))
	end
	if key=="1b" then
		apocalypseQuestLoseReputation(playerIndex,"Hunter's Moon","effect")
		apocalypseQuestPlaceCrystalOnCard(card,"Black",0.70,-0.65,"Hunter's Moon")
	end
end

apocalypseQuestRegisterHandler("a6d5cc").resolveEffect=function(card,playerIndex,option,finalCompletion)
	local key=tostring(option.key)
	if key=="1" then
		gStates.apocalypseQuestUnderSiegeReady=nil
		gStates.apocalypseQuestUnderSiegeStep2={player=playerIndex,mage=turnOrder[playerIndex].mage,serial=gStates.apocalypseQuestTurnSerial or 0,movedSerial=nil}
		apocalypseQuestPlaceEnemy(card,"gray",true,-0.45)
		apocalypseQuestPlaceEnemy(card,"purple",true,0.45)
	end
end

apocalypseQuestRegisterHandler("bbd087").resolveEffect=function(card,playerIndex,option,finalCompletion)
	local key=tostring(option.key)
		if key=="1" then
			broadcastToAll("{en}Noble Warrior: the companion Quest marker is now at this site.{ru}Noble Warrior: сопровождающий жетон задания теперь находится в этом месте.{zh-tw}Noble Warrior：同伴任務標記現在位於此地點。{zh-cn}Noble Warrior：同伴任务标记现在位于此地点。{ko}Noble Warrior: 동료 퀘스트 마커가 이제 이 장소에 있습니다.{es}Noble Warrior: la ficha de Misión compañera está ahora en este lugar.{fr}Noble Warrior : le marqueur de Quête compagnon se trouve maintenant sur ce site.{pt-br}Noble Warrior: o marcador de Missão companheiro agora está neste local.{de}Noble Warrior: Der begleitende Questmarker befindet sich jetzt an diesem Ort.",positionToColor(playerIndex))
		elseif key=="3a" or key=="3b" then
			QuestPrivate.apocalypseQuestNobleWarriorFinalReward(card,playerIndex,key)
		end
end

apocalypseQuestRegisterHandler("c5dec8").resolveEffect=function(card,playerIndex,option,finalCompletion)
	local key=tostring(option.key)
	if key=="3" then
		apocalypseQuestGiveQuestTokenToInventory(playerIndex,"186613","Stray")
	end
end

apocalypseQuestRegisterHandler("3009b4").resolveEffect=function(card,playerIndex,option,finalCompletion)
	local key=tostring(option.key)
		local tokens={["1"]="adc752",["2"]="c92844",["3"]="0143e0",["4"]="7a56a0"}
		if tokens[key]~=nil then apocalypseQuestGiveQuestTokenToInventory(playerIndex,tokens[key],"Ill Omens") end
end

apocalypseQuestRegisterHandler("6175e8").resolveEffect=function(card,playerIndex,option,finalCompletion)
	local key=tostring(option.key)
	if key=="3" then
		QuestPrivate.apocalypseQuestMagicOverloadPlaceSite(card,playerIndex)
	end
end

apocalypseQuestRegisterHandler("00a4fe").resolveEffect=function(card,playerIndex,option,finalCompletion)
	local key=tostring(option.key)
	if key=="2" then
		apocalypseQuestGiveQuestTokenToInventory(playerIndex,"3c89b8","Misadventure")
	end
end

apocalypseQuestRegisterHandler("bb2828").resolveEffect=function(card,playerIndex,option,finalCompletion)
	local key=tostring(option.key)
	if key=="2" then
		local color=gStates.apocalypseQuestStepColor~=nil and gStates.apocalypseQuestStepColor[card.guid] or nil
		if color~=nil then apocalypseQuestPlaceCrystalOnCard(card,color,0,-0.55,"The Artificer") end
	end
	if key=="3" then
		--The three Step 2 crystals are temporary progress markers. The Artificer keeps its Quest card
		--as a reminder after completion, so normal bottom-deck cleanup never gets a chance to remove them.
		for _,obj in ipairs(apocalypseQuestObjectsOnCard(card)) do
			if apocalypseQuestBasicCrystalColor(obj)~=nil then obj.destruct() end
		end
		apocalypseQuestGiveQuestTokenToInventory(playerIndex,"cd8313","The Artificer")
	end
end

function QuestPrivate.apocalypseQuestResolveSpecialEffect(card, playerIndex, option, finalCompletion)
	if card==nil or option==nil or turnOrder[playerIndex]==nil then return end
	local handler=apocalypseQuestHandler(card)
	if handler~=nil and handler.resolveEffect~=nil then
		return handler.resolveEffect(card,playerIndex,option,finalCompletion)
	end
end

function apocalypseQuestRefreshStrayToken()
	if gStates.apocalypseQuestReminderCards==nil or gStates.apocalypseQuestReminderCards["c5dec8"]==nil then return false end
	local token=getObjectFromGUID("186613")
	if token==nil then return false end
	token.unlock()
	token.setRotationSmooth({0,180,180})
	broadcastToAll("{en}Stray: its once-per-round Quest token refreshed for the new round.{ru}Stray: жетон задания, используемый раз за раунд, обновлён для нового раунда.{zh-tw}Stray：每回合輪一次的任務標記已為新回合輪重置。{zh-cn}Stray：每回合轮一次的任务标记已为新回合轮重置。{ko}Stray: 라운드당 한 번 사용하는 퀘스트 토큰이 새 라운드에 맞춰 갱신되었습니다.{es}Stray: su ficha de Misión de una vez por Ronda se ha renovado para la nueva Ronda.{fr}Stray : son jeton de Quête utilisable une fois par Manche a été réinitialisé pour la nouvelle Manche.{pt-br}Stray: sua ficha de Missão de uma vez por Rodada foi renovada para a nova Rodada.{de}Stray: Sein einmal pro Runde verwendbarer Questmarker wurde für die neue Runde erneuert.",{1,1,0.5})
	return true
end

function apocalypseQuestEndRoundCleanup()
	if apocalypseQuestsUsed()~=true or gStates.firstStarted~=true then return false end
	if gStates.currentRound>=gStates.rounds then return false end
	local cards=QuestPrivate.apocalypseQuestOfferCards()
	if #cards==0 then return false end
	local removeCount=math.min(2,#cards)
	local firstRemoved=#cards-removeCount+1
	local queue={}
	for i=firstRemoved,#cards do if cards[i]~=nil then queue[#queue+1]=cards[i] end end
	broadcastToAll(joinLang({"{en}Quest cleanup started: removing the {ru}Очистка заданий началась: удаляется {zh-tw}任務清理開始：從供應中移除最右側 {zh-cn}任务清理开始：从供应中移除最右侧 {ko}퀘스트 정리 시작: 제안 오른쪽 끝에서 퀘스트 {es}Limpieza de Misiones iniciada: se retiran las {fr}Nettoyage des Quêtes commencé : retrait des {pt-br}Limpeza das Missões iniciada: removendo as {de}Quest-Bereinigung gestartet: Entferne die ",tostring(#queue),#queue==1 and "{en} rightmost Quest from the offer.{ru} крайнее справа задание из предложения.{zh-tw} 張任務。{zh-cn} 张任务。{ko}개를 제거합니다.{es} Misión más a la derecha de la oferta.{fr} Quête la plus à droite de l’offre.{pt-br} Missão mais à direita da oferta.{de} am weitesten rechts liegende Quest aus dem Angebot." or "{en} rightmost Quests from the offer.{ru} крайних справа заданий из предложения.{zh-tw} 張任務。{zh-cn} 张任务。{ko}개를 제거합니다.{es} Misiones más a la derecha de la oferta.{fr} Quêtes les plus à droite de l’offre.{pt-br} Missões mais à direita da oferta.{de} am weitesten rechts liegenden Quests aus dem Angebot."}),{1,1,0.5})

	local function cleanNext(index)
		if index>#queue then
			broadcastToAll("{en}Quest cleanup complete. The Quest offer will refill normally as player turns begin.{ru}Очистка заданий завершена. Предложение заданий будет пополняться обычным образом с началом ходов игроков.{zh-tw}任務清理完成。玩家回合開始後，任務供應將正常補充。{zh-cn}任务清理完成。玩家回合开始后，任务供应将正常补充。{ko}퀘스트 정리가 완료되었습니다. 플레이어 턴이 시작되면 퀘스트 제안이 정상적으로 보충됩니다.{es}Limpieza de Misiones completada. La oferta de Misiones se rellenará normalmente al comenzar los turnos de los jugadores.{fr}Nettoyage des Quêtes terminé. L’offre de Quêtes se remplira normalement au début des tours des joueurs.{pt-br}Limpeza das Missões concluída. A oferta de Missões será reabastecida normalmente quando os turnos dos jogadores começarem.{de}Quest-Bereinigung abgeschlossen. Das Quest-Angebot wird zu Beginn der Spielerzüge normal aufgefüllt.",{1,1,0.5})
			return
		end
		local card=queue[index]
		if card==nil then cleanNext(index+1) return end
		local questName=apocalypseQuestName(card)
		local questDetails=apocalypseQuestData[card.guid] or {}
		local objects=apocalypseQuestObjectsOnCard(card)
		local shieldCount=0
		local penalized={}
		broadcastToAll(joinLang({"{en}Quest cleanup: \"{ru}Очистка задания: \"{zh-tw}任務清理：\"{zh-cn}任务清理：\"{ko}퀘스트 정리: \"{es}Limpieza de Misión: \"{fr}Nettoyage de Quête : \"{pt-br}Limpeza da Missão: \"{de}Quest-Bereinigung: \"",questName,"\" (",tostring(questDetails.questType or "Unknown"),"){en} is leaving the offer.{ru} покидает предложение.{zh-tw} 正在離開供應。{zh-cn} 正在离开供应。{ko}이(가) 제안에서 제거됩니다.{es} sale de la oferta.{fr} quitte l’offre.{pt-br} está saindo da oferta.{de} verlässt das Angebot."}),{1,1,0.5})
		for _,obj in ipairs(objects) do
			if obj.getName()=="Shield" then
				shieldCount=shieldCount+1
				if questDetails.questType=="Personal" then
					local owner=obj.getDescription()
					if owner~=nil and owner~="" and owner~="Neutral" and penalized[owner]~=true then
						for playerIndex,playerDetails in ipairs(turnOrder) do
							if playerDetails.mage==owner then apocalypseQuestLoseReputation(playerIndex,questName) penalized[owner]=true break end
						end
					end
				end
			end
		end
		QuestPrivate.apocalypseQuestBottomDeck(card,function(success)
			if shieldCount>0 then broadcastToAll(joinLang({"{en}Quest cleanup: removed {ru}Очистка задания: удалено {zh-tw}任務清理：從 \"{zh-cn}任务清理：从 \"{ko}퀘스트 정리: \"{es}Limpieza de Misión: se retiraron {fr}Nettoyage de Quête : retrait de {pt-br}Limpeza da Missão: foram removidos {de}Quest-Bereinigung: ",tostring(shieldCount),shieldCount==1 and "{en} Shield from \"{ru} Щит из \"{zh-tw}\" 移除 1 個盾牌。{zh-cn}\" 移除 1 个盾牌。{ko}\"에서 방패 1개를 제거했습니다.{es} Escudo de \"{fr} Bouclier de \"{pt-br} Escudo de \"{de} Schild aus \"" or "{en} Shields from \"{ru} Щитов из \"{zh-tw}\" 移除盾牌。{zh-cn}\" 移除盾牌。{ko}\"에서 방패를 제거했습니다.{es} Escudos de \"{fr} Boucliers de \"{pt-br} Escudos de \"{de} Schilde aus \"",questName,"\"."}),{1,1,0.5}) end
			if gStates.apocalypseQuestReminderCards~=nil and gStates.apocalypseQuestReminderCards[card.guid]~=nil then
				broadcastToAll(joinLang({"{en}Quest cleanup: \"{ru}Очистка задания: \"{zh-tw}任務清理：\"{zh-cn}任务清理：\"{ko}퀘스트 정리: \"{es}Limpieza de Misión: \"{fr}Nettoyage de Quête : \"{pt-br}Limpeza da Missão: \"{de}Quest-Bereinigung: \"",questName,"{en}\" remains beside the Quest Shield bags as a reminder.{ru}\" остаётся рядом с мешками Щитов задания как напоминание.{zh-tw}\" 留在任務盾牌袋旁作為提醒。{zh-cn}\" 留在任务盾牌袋旁作为提醒。{ko}\"이(가) 알림으로 퀘스트 방패 주머니 옆에 남습니다.{es}\" permanece junto a las bolsas de Escudos de Misión como recordatorio.{fr}\" reste à côté des sacs de Boucliers de Quête comme rappel.{pt-br}\" permanece ao lado das bolsas de Escudos da Missão como lembrete.{de}\" bleibt als Erinnerung neben den Quest-Schild-Beuteln."}),{1,1,0.5})
			elseif success==true then
				broadcastToAll(joinLang({"{en}Quest cleanup: \"{ru}Очистка задания: \"{zh-tw}任務清理：\"{zh-cn}任务清理：\"{ko}퀘스트 정리: \"{es}Limpieza de Misión: \"{fr}Nettoyage de Quête : \"{pt-br}Limpeza da Missão: \"{de}Quest-Bereinigung: \"",questName,"{en}\" returned to the bottom of the Quest deck.{ru}\" возвращено на дно колоды заданий.{zh-tw}\" 已歸還到任務牌庫底部。{zh-cn}\" 已归还到任务牌库底部。{ko}\"이(가) 퀘스트 덱 맨 아래로 돌아갔습니다.{es}\" volvió al fondo del mazo de Misiones.{fr}\" a été remis sous le paquet de Quêtes.{pt-br}\" voltou para o fundo do baralho de Missões.{de}\" wurde unter den Queststapel gelegt."}),{1,1,0.5})
			else
				broadcastToAll(joinLang({"{en}Quest cleanup: \"{ru}Очистка задания: \"{zh-tw}任務清理：\"{zh-cn}任务清理：\"{ko}퀘스트 정리: \"{es}Limpieza de Misión: \"{fr}Nettoyage de Quête : \"{pt-br}Limpeza da Missão: \"{de}Quest-Bereinigung: \"",questName,"{en}\" could not be returned to the Quest deck.{ru}\" не удалось вернуть в колоду заданий.{zh-tw}\" 無法歸還到任務牌庫。{zh-cn}\" 无法归还到任务牌库。{ko}\"을(를) 퀘스트 덱으로 돌려놓지 못했습니다.{es}\" no pudo devolverse al mazo de Misiones.{fr}\" n’a pas pu être remise dans le paquet de Quêtes.{pt-br}\" não pôde ser devolvida ao baralho de Missões.{de}\" konnte nicht in den Queststapel zurückgelegt werden."}),{1,0.2,0.2})
			end
			--Only now may the next retiring Quest begin its deck return. This prevents the two loose
			--cards from combining with each other and becoming a stray two-card deck beside the real deck.
			safeWaitFrames("Quests",function() cleanNext(index+1) end,1)
		end)
	end
	cleanNext(1)
	return true
end
function QuestPrivate.apocalypseQuestOfferTarget()
	if gStates.playerCount==1 then return 4 end
	return (gStates.playerCount or 0)+2
end
function QuestPrivate.apocalypseQuestScorePosition(score, seatPos)
	score=math.max(0, math.floor(score or 0))
	local fameToLevel=math.floor(math.sqrt(score+1))
	local startPosition=(score-(fameToLevel*fameToLevel))+2
	local levelRowFameQuantity=(((fameToLevel-1)*cellGainPerLevel)+normalCellAmount)
	if startPosition>levelRowFameQuantity then fameToLevel=fameToLevel+1 startPosition=2 levelRowFameQuantity=levelRowFameQuantity+2 end
	local levelRowLength=((fameToLevel-1)*gStates.rowLengthGainPerLevel)+gStates.normalRowLength
	local xOffset=(1/levelRowFameQuantity*levelRowLength)/2
	local yOffset=(heightOfFameBoard/gStates.rowsOnBoard)/2
	local horizontalValue=leftOfFameBoard+(startPosition/levelRowFameQuantity*levelRowLength)-xOffset-1.05
	local verticalValue=(topOfFameBoard-((fameToLevel/gStates.rowsOnBoard)*heightOfFameBoard))+yOffset-0.35
	return {horizontalValue, 1.55, verticalValue+(((seatPos or 2.5)-2.5)/5)}
end
function apocalypseQuestScoreMarkerSetup(apocalypseBag)
	if apocalypseBag==nil then return end
	gStates.apocalypseQuestScoringDisabled=false
	gStates.apocalypseQuestScoringChoiceLocked=false
	gStates.apocalypseQuestScoreMarkers={}
	gStates.apocalypseQuestScores={}
	local contents=apocalypseBag.getObjects() or {}
	local function normalized(text) return string.lower(tostring(text or '')):gsub('[^%w]', '') end
	for seatPos=1, 4, 1 do
		local mage=gStates.positionMageKnight[seatPos]
		if mage~=nil and mage~='nobody' and mage~='Volkare' then
			local mageKey=normalized(mage)
			local marker=nil
			for _, data in pairs(contents) do
				local name=normalized(data.name)
				local description=normalized(data.description)
				if name==mageKey and description=='questscore' then marker=data break end
			end
			if marker~=nil then
				local mageName=mage
				--Quest Score markers share the physical Fame board with the normal Fame/Reputation shields.
				--Do not smooth-move them across other colliders: an impact can knock an unlocked score marker
				--off (or through) the board without anybody noticing. Normal Fame shields also use direct placement.
				safeTakeObject("Quests",apocalypseBag,{guid=marker.guid, position=QuestPrivate.apocalypseQuestScorePosition(0, seatPos), rotation={0, 180, 0}, smooth=false, callback_function=function(obj)
					if obj==nil then return end
					--If another player's marker was deleted while setup callbacks were still resolving, honor that choice.
					if gStates.apocalypseQuestScoringDisabled==true and apocalypseQuestScoresRequired()~=true then obj.destruct() return end
					obj.setPosition(QuestPrivate.apocalypseQuestScorePosition(0, seatPos))
					obj.setRotation({0,180,0})
					gStates.apocalypseQuestScoreMarkers[mageName]=obj.guid
					gStates.apocalypseQuestScores[mageName]=0
					for _, player in pairs(turnOrder or {}) do if player.mage==mageName then player.questScoreGUID=obj.guid player.questScore=0 break end end
				end})
			else
				print('No Quest Score marker found in Apocalypse Dragon bag for '..tostring(mage))
			end
		end
	end
end
function QuestPrivate.apocalypseQuestAreaZone()
	if gStates==nil then return nil end
	local zone=gStates.apocalypseQuestAreaZoneGUID~=nil and getObjectFromGUID(gStates.apocalypseQuestAreaZoneGUID) or nil
	if zone~=nil then return zone end
	--One permanent scripting zone covers the Quest deck, all six offer slots and anything physically
	--attached to those cards. Quest scans can therefore stay local instead of walking the entire table.
	zone=spawnObject({type="ScriptingTrigger",position={59.44,2.50,8.06},rotation={0,0,0},scale={32,8,8},snap_to_grid=false})
	if zone~=nil then
		zone.setName("Quest Area")
		zone.setDescription("Internal scripting zone for the Apocalypse Quest deck, offer and card attachments.")
		zone.setLock(true)
		gStates.apocalypseQuestAreaZoneGUID=zone.guid
	end
	return zone
end
function QuestPrivate.apocalypseQuestAreaObjects()
	local zone=QuestPrivate.apocalypseQuestAreaZone()
	if zone==nil then return {} end
	local ok,objects=pcall(function() return zone.getObjects() end)
	return ok==true and objects or {}
end
function QuestPrivate.apocalypseQuestOfferPosition(slot)
	return {46.84+(4.20*slot), 1.08, 8.06}
end
function QuestPrivate.apocalypseQuestCardInOffer(questGUID)
	if questGUID==nil or apocalypseQuestsUsed()~=true then return false end
	local card=getObjectFromGUID(questGUID)
	if card==nil or card.type~="Card" then return false end
	local first=QuestPrivate.apocalypseQuestOfferPosition(1)
	local last=QuestPrivate.apocalypseQuestOfferPosition(6)
	local pos=card.getPosition()
	return pos[1]>first[1]-1.8 and pos[1]<last[1]+1.8 and math.abs(pos[3]-first[3])<2.6
end
function apocalypseQuestVillagePlunderBlocked(playerIndex)
	--A Fistful of Crystals protects only the Village carrying its 9.x Quest marker, not every Village.
	if QuestPrivate.apocalypseQuestCardInOffer("66ea80")~=true then return false end
	local marker=getObjectFromGUID("14e54b")
	local avatar=coopAssaultAvatarObject(playerIndex)
	if marker==nil or avatar==nil then return false end
	local markerTerrain, markerBearing=terrainHexAtPosition(marker.getPosition())
	if markerTerrain==nil or markerBearing==nil then return false end
	local avatarTerrain, avatarBearing=terrainHexAtPosition(avatar.getPosition())
	return avatarTerrain~=nil and avatarTerrain.guid==markerTerrain.guid and avatarBearing==markerBearing
end
function QuestPrivate.apocalypseQuestInterfaceRemove(card)
	if card==nil then return end
	apocalypseQuestClearEnemyAttackButtons(card)
	local xml=card.UI.getXmlTable() or {}
	local kept={}
	local removed=false
	for _, element in ipairs(xml) do
		local id=element.attributes~=nil and element.attributes.id or nil
		if id~=nil and id:sub(1, 15)=="ApocalypseQuest" then removed=true else kept[#kept+1]=element end
	end
	if removed==true then
		if #kept>0 then card.UI.setXmlTable(kept) else card.UI.setXml("") end
	end
end
function QuestPrivate.apocalypseQuestStepNumber(key)
	return tonumber(tostring(key or ""):match("^(%d+)"))
end
function QuestPrivate.apocalypseQuestNextStepNumber(quest, currentStep)
	if quest==nil then return nil end
	local nextStep=nil
	for _, option in ipairs(quest.steps or {}) do
		local number=QuestPrivate.apocalypseQuestStepNumber(option.key)
		if number~=nil and number>currentStep and (nextStep==nil or number<nextStep) then nextStep=number end
	end
	return nextStep
end
function QuestPrivate.apocalypseQuestProgressState(card, playerIndex, create)
	if card==nil or playerIndex==nil then return nil, nil end
	local quest=apocalypseQuestData[card.guid]
	local playerDetails=turnOrder[playerIndex]
	if quest==nil or playerDetails==nil then return nil, nil end
	if gStates.apocalypseQuestProgress==nil then
		if create~=true then return nil, nil end
		gStates.apocalypseQuestProgress={}
	end
	local questState=gStates.apocalypseQuestProgress[card.guid]
	if questState==nil then
		if create~=true then return nil, nil end
		questState={players={}, globalPoints={}}
		gStates.apocalypseQuestProgress[card.guid]=questState
	end
	if questState.players==nil then questState.players={} end
	if questState.globalPoints==nil then questState.globalPoints={} end
	local state=nil
	if quest.questType=="Independent" then
		local key=playerDetails.mage
		state=questState.players[key]
		if state==nil and create==true then
			state={step=1, repeats={}, points={}, completed=false}
			questState.players[key]=state
		end
	else
		state=questState.shared
		if state==nil and create==true then
			state={step=1, repeats={}, points={}, completed=false}
			questState.shared=state
		end
	end
	if state~=nil then
		if state.step==nil then state.step=1 end
		if state.repeats==nil then state.repeats={} end
		if state.points==nil then state.points={} end
	end
	return state, questState
end
function QuestPrivate.apocalypseQuestProgressCount(card, playerIndex)
	playerIndex=playerIndex or gStates.turnNumber
	local state=QuestPrivate.apocalypseQuestProgressState(card, playerIndex, false)
	if state==nil then return 0 end
	return math.max(0, (state.step or 1)-1)
end
function QuestPrivate.apocalypseQuestProgressFixed(card)
	return card~=nil and apocalypseQuestData[card.guid]~=nil
end
function QuestPrivate.apocalypseQuestPersonalShieldOwner(card)
	local quest=card~=nil and apocalypseQuestData[card.guid] or nil
	if quest==nil or quest.questType~="Personal" then return nil, nil end
	for _, obj in ipairs(apocalypseQuestObjectsOnCard(card)) do
		if obj.getName()=="Shield" then
			local owner=obj.getDescription()
			if owner~=nil and owner~="" and owner~="Neutral" then
				for playerIndex, playerDetails in ipairs(turnOrder) do
					if playerDetails.mage==owner and playerDetails.mage~=gStates.positionMageKnight[5] then return playerIndex, obj end
				end
			end
		end
	end
	return nil, nil
end
function QuestPrivate.apocalypseQuestNeutralShield(card)
	if card==nil then return nil end
	for _, obj in ipairs(apocalypseQuestObjectsOnCard(card)) do
		if obj.getName()=="Shield" and obj.getDescription()=="Neutral" then return obj end
	end
	return nil
end
function QuestPrivate.apocalypseQuestPlayerShield(card, playerIndex)
	if card==nil or turnOrder[playerIndex]==nil then return nil end
	local mage=turnOrder[playerIndex].mage
	for _, obj in ipairs(apocalypseQuestObjectsOnCard(card)) do
		if obj.getName()=="Shield" and obj.getDescription()==mage then return obj end
	end
	return nil
end

function QuestPrivate.apocalypseQuestGoblinWarrensAllPlayerShields(card)
	if card==nil or card.guid~="72099f" then return false end
	local active=0
	for playerIndex,details in ipairs(turnOrder or {}) do
		if details.mage~=nil and details.mage~="nobody" and details.mage~=gStates.positionMageKnight[5] and details.dropoutState==nil then
			active=active+1
			if QuestPrivate.apocalypseQuestPlayerShield(card,playerIndex)==nil then return false end
		end
	end
	return active>0
end

function QuestPrivate.apocalypseQuestGoblinWarrensRemoveBagIfReady(card)
	if QuestPrivate.apocalypseQuestGoblinWarrensAllPlayerShields(card)~=true then return false end
	local bag=getObjectFromGUID("f021d8")
	if bag~=nil then bag.destruct() end
	return true
end
function QuestPrivate.apocalypseQuestPlayerHasOtherPersonalQuest(playerIndex, excludeGUID)
	if turnOrder[playerIndex]==nil then return false end
	local mage=turnOrder[playerIndex].mage
	for _, questCard in ipairs(QuestPrivate.apocalypseQuestOfferCards()) do
		if questCard.guid~=excludeGUID then
			local quest=apocalypseQuestData[questCard.guid]
			if quest~=nil and quest.questType=="Personal" then
				for _, obj in ipairs(apocalypseQuestObjectsOnCard(questCard)) do
					if obj.getName()=="Shield" and obj.getDescription()==mage then return true end
				end
			end
		end
	end
	return false
end
function QuestPrivate.apocalypseQuestPersonalBlockedByOther(card, playerIndex)
	if card==nil or turnOrder[playerIndex]==nil then return false end
	local quest=apocalypseQuestData[card.guid]
	if quest==nil or quest.questType~="Personal" then return false end
	--A Personal Quest owned by another Hero is unavailable for a different reason. The large restriction
	--notice is specifically for an otherwise claimable/resumable Personal Quest blocked by this Hero
	--already owning a different Personal Quest.
	local ownerIndex=QuestPrivate.apocalypseQuestPersonalShieldOwner(card)
	if ownerIndex~=nil then return false end
	return QuestPrivate.apocalypseQuestPlayerHasOtherPersonalQuest(playerIndex,card.guid)==true
end
function QuestPrivate.apocalypseQuestPlayerBurnedMonastery(playerIndex)
	local details=turnOrder[playerIndex]
	if details==nil or gStates.monasteryBurnedBy==nil then return false end
	for _, mage in pairs(gStates.monasteryBurnedBy) do
		if mage==details.mage then return true end
	end
	return false
end


function QuestPrivate.apocalypseQuestMarkerRule(card, stepNumber)
	if card==nil then return nil end
	local rules=apocalypseQuestMarkerPlacementRules[card.guid]
	if rules==nil then return nil end
	return rules[tostring(stepNumber)]
end

function QuestPrivate.apocalypseQuestMarkerObject(rule)
	if rule==nil then return nil end
	for _, guid in ipairs(rule.tokens or {}) do
		local token=getObjectFromGUID(guid)
		if token~=nil then return token end
	end
	return nil
end

function QuestPrivate.apocalypseQuestMapHexes()
	local refreshCache=apocalypseQuestRefreshMapCache or {}
	if refreshCache~=nil and refreshCache.hexes~=nil and refreshCache.mapObjects~=nil then return refreshCache.hexes,refreshCache.mapObjects end
	local snapshot=runtimeMapSnapshot()
	local hexes=snapshot.hexes or {}
	local objects=snapshot.objects or {}
	if refreshCache~=nil then refreshCache.mapObjects=objects refreshCache.hexes=hexes end
	return hexes,objects
end

--Quest offer refreshes can query occupancy hundreds of times. Reuse one live spatial view for the
--synchronous refresh so shield/enemy checks do not rescan every object on the map for every candidate.
function QuestPrivate.apocalypseQuestMapSpatial()
	local refreshCache=apocalypseQuestRefreshMapCache
	if refreshCache~=nil and refreshCache.mapSpatial~=nil then return refreshCache.mapSpatial end
	local spatial=runtimeMapSpatialSnapshot()
	if refreshCache~=nil then refreshCache.mapSpatial=spatial end
	return spatial
end

--Guard Duty measures the shortest connection between the merchant marker's pickup site and the
--Mage Knight's current drop-off site using revealed map spaces only. QuestPrivate.apocalypseQuestMapHexes()
--already omits unrevealed terrain, so a BFS over its adjacency graph matches the printed wording.
function QuestPrivate.apocalypseQuestGuardDutyDistance(playerIndex)
	local marker=getObjectFromGUID("518afd")
	if marker==nil then return nil end
	local hexes,mapObjects=QuestPrivate.apocalypseQuestMapHexes()
	local markerHex=runtimeMapHexForPosition(hexes,marker.getPosition(),mapObjects)
	local playerHex=apocalypseQuestPlayerHex(hexes,mapObjects,playerIndex)
	if markerHex==nil or playerHex==nil then return nil end
	local distances=runtimeMapHexDistanceMap(hexes,{markerHex})
	return distances[runtimeMapHexKey(playerHex)]
end

function apocalypseQuestPlayerHex(hexes, mapObjects, playerIndex)
	local position=nil
	if fracturedLandsTeleportSourcePosition~=nil then position=fracturedLandsTeleportSourcePosition(playerIndex) end
	if position==nil then
		local avatar=coopAssaultAvatarObject(playerIndex)
		if avatar~=nil then position=avatar.getPosition() end
	end
	return runtimeMapHexForPosition(hexes,position,mapObjects)
end

function apocalypseQuestFeatureIsCity(feature)
	local name=string.lower(tostring(feature or ""))
	return name:find("city",1,true)~=nil or name:sub(1,7)=="raised "
end

function QuestPrivate.apocalypseQuestFeatureMatches(feature, wanted)
	local name=string.lower(tostring(feature or ""))
	local target=string.lower(tostring(wanted or ""))
	if target=="city" then return apocalypseQuestFeatureIsCity(name) end
	return name==target
end

function apocalypseQuestHexHasShield(hex, mapObjects, playerIndex, anyPlayer)
	if hex==nil or hex.position==nil then return false end
	local mage=turnOrder[playerIndex]~=nil and turnOrder[playerIndex].mage or nil
	local spatial=QuestPrivate.apocalypseQuestMapSpatial()
	for _, obj in ipairs(runtimeMapSpatialNearbyObjects(spatial,hex.position,1.1)) do
		if obj.getName()=="Shield" and volkarePursuitShieldRegistered(obj)~=true then
			local pos=spatial.positions[obj.guid] or obj.getPosition()
			local dx=pos[1]-hex.position[1]
			local dz=pos[3]-hex.position[3]
			if (dx*dx)+(dz*dz)<1 then
				local owner=obj.getDescription()
				if anyPlayer==true then
					if owner~=nil and owner~="" and owner~="Neutral" then return true end
				elseif mage~=nil and owner==mage then
					return true
				end
			end
		end
	end
	return false
end

function QuestPrivate.apocalypseQuestHexSiteInteractable(hex, mapObjects, playerIndex)
	local feature=string.lower(tostring(hex.feature or ""))
	if QuestPrivate.apocalypseQuestHexDestroyedMonastery~=nil and QuestPrivate.apocalypseQuestHexDestroyedMonastery(hex)==true then return false end
	if feature=="monastery" and gStates.monasteryBurned~=nil and gStates.monasteryBurned[hex.terrainGUID]==true then return false end
	if feature=="keep" or feature=="mage tower" or apocalypseQuestFeatureIsCity(feature)==true or feature=="volkare's camp" then
		return apocalypseQuestHexHasShield(hex,mapObjects,playerIndex,gStates.coop==1)
	end
	return true
end

function apocalypseQuestHexInteractionSite(hex,mapObjects,playerIndex)
	if hex==nil then return false end
	local feature=string.lower(tostring(hex.feature or ""))
	local interaction=feature=="village" or feature=="monastery" or feature=="keep" or feature=="mage tower" or
		apocalypseQuestFeatureIsCity(feature)==true or feature=="camp" or feature=="oasis" or feature=="volkare's camp"
	if interaction~=true then return false end
	return QuestPrivate.apocalypseQuestHexSiteInteractable(hex,mapObjects,playerIndex)==true
end

function QuestPrivate.apocalypseQuestHexHasEnemy(hex, mapObjects)
	if hex==nil or hex.position==nil then return false end
	local spatial=QuestPrivate.apocalypseQuestMapSpatial()
	for _, obj in ipairs(runtimeMapSpatialNearbyObjects(spatial,hex.position,1.1)) do
		if monsterPugs[obj.guid]~=nil then
			local pos=spatial.positions[obj.guid] or obj.getPosition()
			local dx=pos[1]-hex.position[1]
			local dz=pos[3]-hex.position[3]
			if (dx*dx)+(dz*dz)<1 then return true end
		end
	end
	return false
end

function QuestPrivate.apocalypseQuestHexSafe(hex, mapObjects, playerIndex)
	if hex==nil or hex.hexType=="lake" or hex.hexType=="mountain" or hex.hexType=="ocean" then return false end
	local feature=string.lower(tostring(hex.feature or ""))
	--Rampaging/Draconum labels describe the printed spawn space; once the enemy is gone the space is safe again.
	if QuestPrivate.apocalypseQuestHexHasEnemy(hex,mapObjects)==true then return false end
	if feature=="keep" or feature=="mage tower" or apocalypseQuestFeatureIsCity(feature)==true or feature=="volkare's camp" then
		return QuestPrivate.apocalypseQuestHexSiteInteractable(hex,mapObjects,playerIndex)
	end
	return true
end

function apocalypseQuestHexAdventureSite(hex)
	if hex==nil then return false end
	local feature=string.lower(tostring(hex.feature or ""))
	return feature=="monster den" or feature=="spawning grounds" or feature=="ruin" or feature=="dungeon" or feature=="tomb" or
		feature=="maze" or feature=="labyrinth" or feature=="graveyard" or feature=="ziggurat" or feature=="pyramid"
end

function QuestPrivate.apocalypseQuestStarterLocationRule(card, option)
	if card==nil or option==nil then return nil end
	local rules=apocalypseQuestStepLocationRules[card.guid]
	if rules==nil then return nil end
	return rules[tostring(option.key)] or rules[tostring(QuestPrivate.apocalypseQuestStepNumber(option.key))]
end

function QuestPrivate.apocalypseQuestCurrentPlayerHex(playerIndex)
	local refreshCache=apocalypseQuestRefreshMapCache or {}
	if refreshCache~=nil and refreshCache.playerHexes~=nil and refreshCache.playerHexes[playerIndex]~=nil then
		return refreshCache.playerHexes[playerIndex].hex,refreshCache.mapObjects
	end
	local hexes,mapObjects=QuestPrivate.apocalypseQuestMapHexes()
	local hex=apocalypseQuestPlayerHex(hexes,mapObjects,playerIndex)
	if refreshCache~=nil then
		refreshCache.mapObjects=mapObjects
		refreshCache.playerHexes=refreshCache.playerHexes or {}
		refreshCache.playerHexes[playerIndex]={hex=hex}
	end
	return hex,mapObjects
end

function QuestPrivate.apocalypseQuestInhabitedFeature(feature)
	local name=string.lower(tostring(feature or ""))
	return name=="village" or name=="monastery" or name=="keep" or name=="mage tower" or
		apocalypseQuestFeatureIsCity(name)==true or name=="oasis" or name=="camp"
end

function QuestPrivate.apocalypseQuestHexNoSite(hex)
	if hex==nil then return false end
	local feature=string.lower(tostring(hex.feature or ""))
	if feature=="" or feature=="portal" or feature=="destroyed" or feature=="rampaging" or feature=="draconum" then return true end
	if feature=="monastery" and gStates.monasteryBurned~=nil and gStates.monasteryBurned[hex.terrainGUID]==true then return true end
	return false
end

function QuestPrivate.apocalypseQuestTokenOnHex(tokenGUID, hex, mapObjects)
	if tokenGUID==nil or hex==nil then return false end
	local transit=gStates.apocalypseQuestMarkerTransit~=nil and gStates.apocalypseQuestMarkerTransit[tokenGUID] or nil
	if transit~=nil then
		return transit.terrainGUID==hex.terrainGUID and tostring(transit.bearing)==tostring(hex.bearing)
	end
	local token=getObjectFromGUID(tokenGUID)
	if token==nil then return false end
	local terrain,bearing=terrainHexAtPosition(token.getPosition(),mapObjects)
	return terrain~=nil and bearing~=nil and terrain.guid==hex.terrainGUID and tostring(bearing)==tostring(hex.bearing)
end

function QuestPrivate.apocalypseQuestTrackMarkerMove(token,target,terrainGUID,bearing)
	if token==nil or target==nil then return end
	if gStates.apocalypseQuestMarkerTransit==nil then gStates.apocalypseQuestMarkerTransit={} end
	local tokenGUID=token.guid
	gStates.apocalypseQuestMarkerTransit[tokenGUID]={terrainGUID=terrainGUID,bearing=bearing,position={target[1],target[2],target[3]}}
	local finish=function()
		if gStates.apocalypseQuestMarkerTransit~=nil then gStates.apocalypseQuestMarkerTransit[tokenGUID]=nil end
		--Quest markers are a bottom layer in the shared map-token separator. Scripted Quest movement
		--stays inside the map zone, so explicitly reconcile the destination after the marker settles.
		mapTokenArrangeObject(tokenGUID)
		apocalypseQuestRefreshOfferButtons()
	end
	safeWaitFrames("Quests",function()
		safeWaitCondition("Quests",finish,function()
			local marker=getObjectFromGUID(tokenGUID)
			if marker==nil then return true end
			local pos=marker.getPosition()
			local dx=pos[1]-target[1]
			local dz=pos[3]-target[3]
			return marker.resting and (dx*dx)+(dz*dz)<0.20
		end,2.5,finish)
	end,2)
end

function QuestPrivate.apocalypseQuestHexesInStraightLine(a,b)
	if a==nil or b==nil then return false end
	local dx=b.position[1]-a.position[1]
	local dz=b.position[3]-a.position[3]
	if (dx*dx)+(dz*dz)<0.5 then return false end
	local angle=math.deg(math.atan2(dz,dx))
	if angle<0 then angle=angle+360 end
	local remainder=angle%60
	return remainder<1.5 or remainder>58.5
end

function QuestPrivate.apocalypseQuestRandomObjectsTreasureLocation(hex,mapObjects)
	if hex==nil then return false end
	local tokenGUIDs={"cef3a2","746a47","97ba49"}
	for _, tokenGUID in ipairs(tokenGUIDs) do
		local token=getObjectFromGUID(tokenGUID)
		if token==nil then return false end
		local terrain,bearing=terrainHexAtPosition(token.getPosition(),mapObjects)
		if terrain==nil or bearing==nil then return false end
		local xy=angleToXY(terrain,bearing)
		local tokenHex={terrainGUID=terrain.guid,bearing=bearing,position={xy[1],1.30,xy[2]}}
		if terrain.guid==hex.terrainGUID and tostring(bearing)==tostring(hex.bearing) then return false end
		if QuestPrivate.apocalypseQuestHexesInStraightLine(hex,tokenHex)~=true then return false end
	end
	return true
end

function QuestPrivate.apocalypseQuestFreeWineLocationLegal(hex,mapObjects,playerIndex)
	if hex==nil then return false end
	local originOK=false
	for _, feature in ipairs({"village","monastery","oasis","camp"}) do
		if QuestPrivate.apocalypseQuestFeatureMatches(hex.feature,feature)==true then originOK=true break end
	end
	if originOK~=true or QuestPrivate.apocalypseQuestHexSiteInteractable(hex,mapObjects,playerIndex)~=true then return false end
	local hexes=QuestPrivate.apocalypseQuestMapHexes()
	local start=nil
	for _, candidate in ipairs(hexes) do
		if candidate.terrainGUID==hex.terrainGUID and tostring(candidate.bearing)==tostring(hex.bearing) then start=candidate break end
	end
	if start==nil then return false end
	local distances=runtimeMapHexDistanceMap(hexes,{start})
	for _, candidate in ipairs(hexes) do
		if QuestPrivate.apocalypseQuestFeatureMatches(candidate.feature,"keep")==true then
			local distance=distances[runtimeMapHexKey(candidate)]
			if distance~=nil and distance<=3 and apocalypseQuestHexHasShield(candidate,mapObjects,playerIndex,false)~=true then return true end
		end
	end
	return false
end

function QuestPrivate.apocalypseQuestFreeWineKeepTargets(playerIndex)
	local hexes,mapObjects=QuestPrivate.apocalypseQuestMapHexes()
	local start=apocalypseQuestPlayerHex(hexes,mapObjects,playerIndex)
	if start==nil then return {} end
	local distances=runtimeMapHexDistanceMap(hexes,{start})
	local result={}
	for _, candidate in ipairs(hexes) do
		if QuestPrivate.apocalypseQuestFeatureMatches(candidate.feature,"keep")==true then
			local distance=distances[runtimeMapHexKey(candidate)]
			if distance~=nil and distance<=3 and apocalypseQuestHexHasShield(candidate,mapObjects,playerIndex,false)~=true then result[#result+1]=candidate end
		end
	end
	return result
end

function QuestPrivate.apocalypseQuestFreeWineAssaultRecord(playerIndex)
	local record=gStates.apocalypseQuestFreeWineAssault
	if record==nil or record.player~=playerIndex or turnOrder[playerIndex]==nil then return nil end
	--Quest 10 may still be awaiting its card resolution after a Proxy/other turn has intervened. The
	--committed Keep assault therefore belongs to the Hero, not to the global Quest turn serial.
	if record.mage~=nil and record.mage~=turnOrder[playerIndex].mage then return nil end
	return record
end

function apocalypseQuestFreeWineMarkAssaultStarted(playerIndex)
	local card=getObjectFromGUID("37e2ce")
	local state=card~=nil and QuestPrivate.apocalypseQuestProgressState(card,playerIndex,false) or nil
	if card==nil or state==nil or state.step~=2 or turnOrder[playerIndex]==nil then return false end
	--Once this branch has an outcome, keep it until Complete/Fail is actually pressed. The shared
	--Rewards Claimed soft-lock timeout must not erase which assault Quest 10 is resolving.
	local existing=QuestPrivate.apocalypseQuestFreeWineAssaultRecord(playerIndex)
	if existing~=nil then return true end
	local hex=QuestPrivate.apocalypseQuestCurrentPlayerHex(playerIndex)
	gStates.apocalypseQuestFreeWineAssault={player=playerIndex,mage=turnOrder[playerIndex].mage,serial=gStates.apocalypseQuestTurnSerial or 0,
		terrainGUID=hex~=nil and hex.terrainGUID or nil,bearing=hex~=nil and hex.bearing or nil,result=nil}
	return true
end

function QuestPrivate.apocalypseQuestFreeWineSuccessReady(playerIndex)
	local record=QuestPrivate.apocalypseQuestFreeWineAssaultRecord(playerIndex)
	if record==nil then return false end
	if record.result=="Complete" then return true end
	if record.result=="Fail" then return false end
	local hexes,mapObjects=QuestPrivate.apocalypseQuestMapHexes()
	for _,hex in ipairs(hexes) do
		if (record.terrainGUID==nil or hex.terrainGUID==record.terrainGUID) and (record.bearing==nil or tostring(hex.bearing)==tostring(record.bearing)) then
			if apocalypseQuestHexHasShield(hex,mapObjects,playerIndex,false)==true then record.result="Complete" return true end
			break
		end
	end
	--The conquest record is written at the same moment as the map Shield. Use it as a second path in case
	--the Quest refresh happens before the newly dropped Shield has entered the map scripting-zone snapshot.
	local conquest=gStates.apocalypseQuestConqueredThisTurn~=nil and turnOrder[playerIndex]~=nil and gStates.apocalypseQuestConqueredThisTurn[turnOrder[playerIndex].mage] or nil
	if conquest~=nil and (record.terrainGUID==nil or (conquest.terrainGUID==record.terrainGUID and tostring(conquest.bearing)==tostring(record.bearing))) then
		record.result="Complete"
		return true
	end
	return false
end

function QuestPrivate.apocalypseQuestFreeWineFailureReady(playerIndex)
	local record=QuestPrivate.apocalypseQuestFreeWineAssaultRecord(playerIndex)
	return record~=nil and record.result=="Fail"
end

function QuestPrivate.apocalypseQuestFreeWineCombatOutcome(playerIndex)
	local record=QuestPrivate.apocalypseQuestFreeWineAssaultRecord(playerIndex)
	if record==nil then return nil end
	if record.result=="Complete" or record.result=="Fail" then return record.result end
	if QuestPrivate.apocalypseQuestFreeWineSuccessReady(playerIndex)==true then return "Complete" end
	--At pre-end-turn the Keep Shield has not been dropped yet; that happens later in monster cleanup.
	--Read the actual garrison result while attackedMonsters still contains its original map position.
	local target=nil
	for _,hex in ipairs(QuestPrivate.apocalypseQuestMapHexes()) do
		if (record.terrainGUID==nil or hex.terrainGUID==record.terrainGUID) and (record.bearing==nil or tostring(hex.bearing)==tostring(record.bearing)) then target=hex break end
	end
	if target==nil then return nil end
	for guid,source in pairs(gStates.attackedMonsters or {}) do
		local pos=source~=nil and source[1] or nil
		local enemy=getObjectFromGUID(guid)
		if pos~=nil and enemy~=nil and monsterPugs[guid]~=nil then
			local dx=(pos.x or pos[1] or 0)-target.position[1]
			local dz=(pos.z or pos[3] or 0)-target.position[3]
			if (dx*dx)+(dz*dz)<1 then
				record.result=enemy.is_face_down==false and "Complete" or "Fail"
				return record.result
			end
		end
	end
	return nil
end

function apocalypseQuestCaptureFreeWineResolutionGate(playerIndex)
	local card=getObjectFromGUID("37e2ce")
	local state=card~=nil and QuestPrivate.apocalypseQuestProgressState(card,playerIndex,false) or nil
	local record=QuestPrivate.apocalypseQuestFreeWineAssaultRecord(playerIndex)
	if card==nil or state==nil or state.step~=2 or record==nil then return false end
	local action=QuestPrivate.apocalypseQuestFreeWineCombatOutcome(playerIndex)
	if action==nil then return false end
	--Create the normal pending reward resolution when the combat outcome is known, not when 1A first
	--sends the Hero toward the Keep. The 12-second soft-lock window starts later at Rewards Claimed.
	QuestPrivate.apocalypseQuestSetRewardCompletionGate(card,playerIndex,action)
	apocalypseQuestUpdateProgressButtons(card)
	return true
end

function QuestPrivate.apocalypseQuestFreeWineStartAssault(card,playerIndex)
	if card==nil or turnOrder[playerIndex]==nil then return false end
	local pos=card.getPosition()
	--1A's reminder Shield knows the Quest's planned slot, so send it straight to the matching future position.
	local surface=apocalypseQuestPlannedWorldPosition(card,{pos[1]+0.62,pos[2]+0.65,pos[3]+0.15})
	local target=QuestPrivate.apocalypseQuestRaisedPiecePosition(surface)
	local shield=QuestPrivate.apocalypseQuestTakePlayerShield(playerIndex,surface)
	apocalypseQuestRegisterMoveAttachment(card,shield,target)
	if shield~=nil then shield.unlock() end
	--1A commits the player to resolving this Keep assault. Do not create the Rewards Claimed resolution
	--gate yet: the combat itself can take as long as needed. The outcome gate is created at the rewards
	--boundary after success/failure can actually be determined.
	gStates.apocalypseQuestFreeWineAssault=nil
	local targets=QuestPrivate.apocalypseQuestFreeWineKeepTargets(playerIndex)
	if #targets==1 then
		local avatar=coopAssaultAvatarObject(playerIndex)
		if avatar~=nil then
			local avatarGUID=avatar.guid
			local color=positionToColor(playerIndex)
			local target={targets[1].position[1],5.0,targets[1].position[3]}
			--setPositionSmooth is scripted movement, so TTS never emits the human onObjectPickUp/onObjectDrop
			--pair that normally detects entry into a Keep and starts its assault. Deliberately run that same
			--avatar drop path once the move settles instead of relying on the model merely falling through a zone.
			onObjectPickUp(color,avatar)
			avatar.unlock()
			avatar.setPositionSmooth(target)
			local finished=false
			local function finishMove()
				if finished==true then return end
				finished=true
				local movedAvatar=getObjectFromGUID(avatarGUID)
				if movedAvatar==nil or QuestPrivate.apocalypseQuestFreeWineAssaultRecord(playerIndex)~=nil then return end
				local current=movedAvatar.getPosition()
				local dx=current[1]-targets[1].position[1]
				local dz=current[3]-targets[1].position[3]
				if (dx*dx)+(dz*dz)<1.5 then onObjectDrop(color,movedAvatar) end
			end
			safeWaitFrames("Quests",function() safeWaitCondition("Quests",finishMove,function() local obj=getObjectFromGUID(avatarGUID) return obj==nil or obj.resting end,4.0,finishMove) end,2)
			broadcastToAll(joinLang({"{en}Free Wine!: one eligible Keep was found; {ru}Free Wine!: найдена одна подходящая Крепость; {zh-tw}Free Wine!：找到一座符合條件的要塞；{zh-cn}Free Wine!：找到一座符合条件的要塞；{ko}Free Wine!: 조건에 맞는 성채 하나를 찾았습니다. {es}Free Wine!: se encontró una Fortaleza válida; {fr}Free Wine! : une Forteresse éligible a été trouvée ; {pt-br}Free Wine!: uma Fortaleza elegível foi encontrada; {de}Free Wine!: Eine geeignete Burg wurde gefunden; ",translateWord[turnOrder[playerIndex].mage] or tostring(turnOrder[playerIndex].mage),"{en} is moving there to begin the assault.{ru} перемещается туда, чтобы начать штурм.{zh-tw} 正移動到那裡開始攻城。{zh-cn} 正移动到那里开始攻城。{ko}이(가) 공격을 시작하기 위해 그곳으로 이동합니다.{es} se mueve allí para iniciar el asalto.{fr} s’y déplace pour commencer l’assaut.{pt-br} está se movendo até lá para iniciar o assalto.{de} bewegt sich dorthin, um den Angriff zu beginnen."}),positionToColor(playerIndex))
		end
	elseif #targets>1 then
		broadcastToAll("{en}Free Wine!: several unconquered Keeps are within 3 revealed spaces. Move to the Keep you choose and assault it.{ru}Free Wine!: в пределах 3 открытых клеток есть несколько непокорённых Крепостей. Переместитесь к выбранной Крепости и штурмуйте её.{zh-tw}Free Wine!：3 個已揭示空間內有多座未征服要塞。移動到你選擇的要塞並攻城。{zh-cn}Free Wine!：3 个已揭示空间内有多座未征服要塞。移动到你选择的要塞并攻城。{ko}Free Wine!: 공개된 3칸 이내에 미정복 성채가 여러 개 있습니다. 원하는 성채로 이동해 공격하십시오.{es}Free Wine!: hay varias Fortalezas no conquistadas a 3 espacios revelados. Muévete a la Fortaleza que elijas y asáltala.{fr}Free Wine! : plusieurs Forteresses non conquises se trouvent à 3 cases révélées. Déplacez-vous vers la Forteresse de votre choix et lancez l’assaut.{pt-br}Free Wine!: há várias Fortalezas não conquistadas a 3 espaços revelados. Mova-se para a Fortaleza escolhida e ataque-a.{de}Free Wine!: Mehrere nicht eroberte Burgen liegen innerhalb von 3 aufgedeckten Feldern. Bewege dich zur gewählten Burg und greife sie an.",positionToColor(playerIndex))
	else
		broadcastToAll("{en}Free Wine!: no eligible Keep could be resolved automatically; move to the intended Keep manually.{ru}Free Wine!: подходящую Крепость не удалось определить автоматически; переместитесь к нужной Крепости вручную.{zh-tw}Free Wine!：無法自動決定符合條件的要塞；請手動移動到目標要塞。{zh-cn}Free Wine!：无法自动决定符合条件的要塞；请手动移动到目标要塞。{ko}Free Wine!: 조건에 맞는 성채를 자동으로 결정하지 못했습니다. 원하는 성채로 수동 이동하십시오.{es}Free Wine!: no se pudo resolver automáticamente una Fortaleza válida; muévete manualmente a la Fortaleza prevista.{fr}Free Wine! : aucune Forteresse éligible n’a pu être déterminée automatiquement ; déplacez-vous manuellement vers la Forteresse prévue.{pt-br}Free Wine!: nenhuma Fortaleza elegível pôde ser resolvida automaticamente; mova-se manualmente para a Fortaleza desejada.{de}Free Wine!: Es konnte keine geeignete Burg automatisch bestimmt werden; bewege dich manuell zur gewünschten Burg.",positionToColor(playerIndex))
	end
	return true
end

function QuestPrivate.apocalypseQuestConqueredThisTurnLocationLegal(hex,playerIndex)
	if hex==nil or turnOrder[playerIndex]==nil then return false end
	local records=gStates.apocalypseQuestConqueredThisTurn
	local record=records~=nil and records[turnOrder[playerIndex].mage] or nil
	return record~=nil and record.serial==(gStates.apocalypseQuestTurnSerial or 0) and
		record.terrainGUID==hex.terrainGUID and tostring(record.bearing)==tostring(hex.bearing)
end

--Under Siege Step 1 is a delayed confirmation of the latest Keep/Mage Tower conquest, not an action
--that must be clicked during the tiny post-combat window. Keep that conquest available through the
--other players' turns; it expires only when its Hero starts playing their next turn, or another Hero
--conquers a new eligible site and therefore becomes the latest claimant.
function QuestPrivate.apocalypseQuestUnderSiegeReadyPlayer()
	local ready=gStates.apocalypseQuestUnderSiegeReady
	if ready==nil then return nil,nil end
	local details=turnOrder[ready.player]
	if details==nil or details.mage~=ready.mage or details.mage==gStates.positionMageKnight[5] or details.dropoutState~=nil or QuestPrivate.apocalypseQuestCardInOffer("a6d5cc")~=true then
		gStates.apocalypseQuestUnderSiegeReady=nil
		return nil,nil
	end
	local card=getObjectFromGUID("a6d5cc")
	--Once Step 1 has actually been claimed, the Personal Quest Shield owns the card and this
	--out-of-turn conquest window is finished.
	if card==nil or QuestPrivate.apocalypseQuestPersonalShieldOwner(card)~=nil or QuestPrivate.apocalypseQuestNeutralShield(card)~=nil then
		gStates.apocalypseQuestUnderSiegeReady=nil
		return nil,nil
	end
	return ready.player,ready
end

function apocalypseQuestUnderSiegeRecordConquest(playerIndex,terrainGUID,bearing,feature)
	if apocalypseQuestsUsed()~=true or turnOrder[playerIndex]==nil or turnOrder[playerIndex].mage==gStates.positionMageKnight[5] or QuestPrivate.apocalypseQuestCardInOffer("a6d5cc")~=true then return false end
	local card=getObjectFromGUID("a6d5cc")
	if card==nil or QuestPrivate.apocalypseQuestPersonalShieldOwner(card)~=nil or QuestPrivate.apocalypseQuestNeutralShield(card)~=nil then return false end
	gStates.apocalypseQuestUnderSiegeReady={player=playerIndex,mage=turnOrder[playerIndex].mage,serial=gStates.apocalypseQuestTurnSerial or 0,terrainGUID=terrainGUID,bearing=bearing,feature=feature}
	return true
end

function QuestPrivate.apocalypseQuestUnderSiegeLocationLegal(hex,playerIndex)
	local readyPlayer,ready=QuestPrivate.apocalypseQuestUnderSiegeReadyPlayer()
	if hex==nil or readyPlayer~=playerIndex or ready==nil then return false end
	if ready.terrainGUID~=hex.terrainGUID or tostring(ready.bearing)~=tostring(hex.bearing) then return false end
	local _,mapObjects=QuestPrivate.apocalypseQuestCurrentPlayerHex(playerIndex)
	return apocalypseQuestHexHasShield(hex,mapObjects,playerIndex,false)==true
end

function QuestPrivate.apocalypseQuestUnderSiegeInterfacePlayerIndex(card)
	if card==nil or card.guid~="a6d5cc" then return gStates.turnNumber end
	local ownerIndex=QuestPrivate.apocalypseQuestPersonalShieldOwner(card)
	if ownerIndex~=nil then return ownerIndex end
	local readyPlayer=QuestPrivate.apocalypseQuestUnderSiegeReadyPlayer()
	return readyPlayer or gStates.turnNumber
end

function QuestPrivate.apocalypseQuestUnderSiegeMovedThisTurn(playerIndex)
	local pending=gStates.apocalypseQuestUnderSiegeStep2
	local details=turnOrder[playerIndex]
	if pending==nil or details==nil or pending.player~=playerIndex or pending.mage~=details.mage or (gStates.apocalypseQuestTurnSerial or 0)<= (pending.serial or 0) then return false end
	if pending.movedSerial==(gStates.apocalypseQuestTurnSerial or 0) then return true end
	local start=details.turnStartLoc
	local current=mageKnightAvatarPosition(playerIndex)
	if start==nil or current==nil then return false end
	local startHex=avatarHexIdentity(start)
	local currentHex=avatarHexIdentity(current)
	if startHex~=nil and currentHex~=nil then return startHex.terrainGUID~=currentHex.terrainGUID or tostring(startHex.bearing)~=tostring(currentHex.bearing) end
	return ((current[1]-start[1])^2)+((current[3]-start[3])^2)>2.25
end

function apocalypseQuestUnderSiegeMarkMoved(playerIndex)
	local pending=gStates.apocalypseQuestUnderSiegeStep2
	if pending~=nil and pending.player==playerIndex and pending.mage==(turnOrder[playerIndex]~=nil and turnOrder[playerIndex].mage or nil) and (gStates.apocalypseQuestTurnSerial or 0)>(pending.serial or 0) then
		pending.movedSerial=gStates.apocalypseQuestTurnSerial or 0
	end
end

function QuestPrivate.apocalypseQuestUnderSiegeStep2ChoiceLegal(playerIndex,key)
	local pending=gStates.apocalypseQuestUnderSiegeStep2
	local details=turnOrder[playerIndex]
	if pending==nil or details==nil or pending.player~=playerIndex or pending.mage~=details.mage or gStates.turnNumber~=playerIndex or (gStates.apocalypseQuestTurnSerial or 0)<= (pending.serial or 0) then return false end
	local moved=QuestPrivate.apocalypseQuestUnderSiegeMovedThisTurn(playerIndex)
	--2B is always a legal voluntary failure once Step 2 is active. 2A remains available only while
	--the Hero has stayed at the Quest marker and can still stand and fight.
	if tostring(key)=="2b" then return true end
	if tostring(key)=="2a" then return moved~=true end
	return false
end

function apocalypseQuestUnderSiegeCardPlayed(zone,obj)
	local readyPlayer,ready=QuestPrivate.apocalypseQuestUnderSiegeReadyPlayer()
	if readyPlayer==nil or ready==nil or zone==nil or obj==nil or gStates.turnNumber~=readyPlayer then return false end
	local details=turnOrder[readyPlayer]
	if details==nil or zone.guid~=playerPlayAreas[details.seatPos] or obj.type~="Card" or gameCards[obj.guid]==nil or obj.getGMNotes()=="Wound" then return false end
	--Do not expire the freshly earned window if a late same-turn physical card movement occurs.
	if (gStates.apocalypseQuestTurnSerial or 0)<= (ready.serial or 0) then return false end
	gStates.apocalypseQuestUnderSiegeReady=nil
	local card=getObjectFromGUID("a6d5cc")
	if card~=nil then safeWaitFrames("Quests",function() local live=getObjectFromGUID("a6d5cc") if live~=nil then QuestPrivate.apocalypseQuestInterfaceAdd(live,true) end end,2) end
	return true
end

function QuestPrivate.apocalypseQuestAnyHumanMayConfirm(playerColor)
	if playerColor=="Black" then return true end
	if playerColor==nil or playerColor=="Grey" or Player[playerColor]==nil or Player[playerColor].seated~=true then return false end
	local hand=Player[playerColor].getHandTransform()
	if hand==nil or hand.position==nil then return false end
	local seatPos=math.ceil((hand.position[1]+97.59)/40)
	for _,details in ipairs(turnOrder or {}) do
		if details.seatPos==seatPos and details.mage~=nil and details.mage~="nobody" and details.mage~=gStates.positionMageKnight[5] and details.dropoutState==nil then return true end
	end
	return false
end

function QuestPrivate.apocalypseQuestTravellingMerchantRelocate(card,playerIndex)
	if card==nil then return false end
	for _, obj in ipairs(apocalypseQuestObjectsOnCard(card)) do
		local color=apocalypseQuestManaTokenColor(obj)
		local bag=color~=nil and apocalypseQuestManaBag(color) or nil
		if bag~=nil then obj.unlock() bag.putObject(obj) end
	end
	local nextColor=apocalypseQuestRollManaDie()
	apocalypseQuestPlaceManaTokenOnCard(card,nextColor,0,-0.15,"Travelling Merchant")
	local token=getObjectFromGUID("afcfc1")
	local hexes,mapObjects=QuestPrivate.apocalypseQuestMapHexes()
	local start=apocalypseQuestPlayerHex(hexes,mapObjects,playerIndex)
	if token==nil or start==nil then return false end
	local distances=runtimeMapHexDistanceMap(hexes,{start})
	local candidates={}
	for _, hex in ipairs(hexes) do
		if distances[runtimeMapHexKey(hex)]==3 and QuestPrivate.apocalypseQuestHexSafe(hex,mapObjects,playerIndex)==true and QuestPrivate.apocalypseQuestHexHasOtherQuestMarker(hex,token.guid)~=true then candidates[#candidates+1]=hex end
	end
	if #candidates==0 then
		broadcastToAll("{en}Travelling Merchant: no legal safe space exactly 3 revealed spaces away was found; move the highlighted Quest marker manually.{ru}Travelling Merchant: не найдено допустимой безопасной клетки ровно в 3 открытых клетках; переместите выделенный жетон задания вручную.{zh-tw}Travelling Merchant：找不到正好相距 3 個已揭示空間的合法安全空間；請手動移動高亮任務標記。{zh-cn}Travelling Merchant：找不到正好相距 3 个已揭示空间的合法安全空间；请手动移动高亮任务标记。{ko}Travelling Merchant: 공개된 칸 기준 정확히 3칸 떨어진 합법적인 안전 칸을 찾지 못했습니다. 강조된 퀘스트 마커를 수동으로 이동하십시오.{es}Travelling Merchant: no se encontró un espacio seguro legal exactamente a 3 espacios revelados; mueve manualmente el marcador de Misión resaltado.{fr}Travelling Merchant : aucune case sûre légale à exactement 3 cases révélées n’a été trouvée ; déplacez manuellement le marqueur de Quête surligné.{pt-br}Travelling Merchant: não foi encontrado espaço seguro válido exatamente a 3 espaços revelados; mova manualmente o marcador de Missão destacado.{de}Travelling Merchant: Es wurde kein gültiges sicheres Feld in genau 3 aufgedeckten Feldern Entfernung gefunden; bewege den hervorgehobenen Questmarker manuell.",positionToColor(playerIndex))
		QuestPrivate.apocalypseQuestHighlightMarker(token)
		return true
	end
	local target=candidates[1]
	QuestPrivate.apocalypseQuestTrackMarkerMove(token,{target.position[1],1.45,target.position[3]},target.terrainGUID,target.bearing)
	token.unlock()
	token.setPositionSmooth({target.position[1],1.45,target.position[3]})
	if #candidates>1 then
		QuestPrivate.apocalypseQuestHighlightMarker(token)
		broadcastToAll(joinLang({"{en}Travelling Merchant: {ru}Travelling Merchant: доступно допустимых мест назначения: {zh-tw}Travelling Merchant：共有 {zh-cn}Travelling Merchant：共有 {ko}Travelling Merchant: 합법적인 목적지가 {es}Travelling Merchant: existen {fr}Travelling Merchant : {pt-br}Travelling Merchant: existem {de}Travelling Merchant: Es gibt ",tostring(#candidates),"{en} legal destinations exist. The first was selected; move the highlighted marker if you prefer another.{ru}. Выбрано первое; переместите выделенный жетон, если предпочитаете другое.{zh-tw} 個合法目的地。已選擇第一個；若偏好其他位置，請移動高亮標記。{zh-cn} 个合法目的地。已选择第一个；若偏好其他位置，请移动高亮标记。{ko}개 있습니다. 첫 번째를 선택했습니다. 다른 곳을 원하면 강조된 마커를 이동하십시오.{es} destinos legales. Se seleccionó el primero; mueve el marcador resaltado si prefieres otro.{fr} destinations légales existent. La première a été sélectionnée ; déplacez le marqueur surligné si vous en préférez une autre.{pt-br} destinos válidos. O primeiro foi selecionado; mova o marcador destacado se preferir outro.{de} gültige Ziele. Das erste wurde ausgewählt; bewege den hervorgehobenen Marker, wenn du ein anderes bevorzugst."}),positionToColor(playerIndex))
	else QuestPrivate.apocalypseQuestClearMarkerHighlight(token) end
	return true
end

function QuestPrivate.apocalypseQuestMagicOverloadPlaceSite(card,playerIndex)
	local highest=0
	for _, details in ipairs(turnOrder) do
		if details.mage~=nil and details.mage~="nobody" and details.mage~=gStates.positionMageKnight[5] and details.dropoutState==nil then highest=math.max(highest,details.level or 1) end
	end
	local chosen=highest<=5 and "a4777c" or "963031"
	local unused=chosen=="a4777c" and "963031" or "a4777c"
	local token=getObjectFromGUID(chosen)
	if token==nil then return false end
	if QuestPrivate.apocalypseQuestPlaceMarkerAtPlayer(token,playerIndex)~=true then return false end
	if gStates.apocalypseQuestMarkerPlacements==nil then gStates.apocalypseQuestMarkerPlacements={} end
	gStates.apocalypseQuestMarkerPlacements[chosen]=true
	local spare=getObjectFromGUID(unused)
	local tokenBag=getObjectFromGUID(GUID.bag.apocalypseQuestTokens)
	if spare~=nil and tokenBag~=nil then spare.unlock() tokenBag.putObject(spare) end
	apocalypseQuestFlipSiteToken(chosen)
	broadcastToAll(joinLang({"{en}Magic Overload: highest Hero level is {ru}Magic Overload: наивысший уровень Героя — {zh-tw}Magic Overload：最高英雄等級為 {zh-cn}Magic Overload：最高英雄等级为 {ko}Magic Overload: 최고 영웅 레벨은 {es}Magic Overload: el nivel de Héroe más alto es {fr}Magic Overload : le niveau de Héros le plus élevé est {pt-br}Magic Overload: o maior nível de Herói é {de}Magic Overload: Die höchste Heldenstufe ist ",tostring(highest),"{en}; the new {ru}; создан новый объект: {zh-tw}；已建立新的 {zh-cn}；已建立新的 {ko}입니다. 새로 생성됨: {es}; se creó el nuevo {fr} ; le nouveau site {pt-br}; foi criado o novo {de}; neu erstellt wurde: ",chosen=="a4777c" and "{en}Monster Den{ru}Логово монстров{zh-tw}怪物巢穴{zh-cn}怪物巢穴{ko}괴물 소굴{es}Guarida de Monstruos{fr}Repaire de Monstres{pt-br}Covil de Monstros{de}Monsterhöhle" or "{en}Spawning Grounds{ru}Место появления{zh-tw}繁殖地{zh-cn}繁殖地{ko}산란지{es}Campo de Aparición{fr}Terrain de Reproduction{pt-br}Terreno de Criação{de}Brutstätte","{en} was created.{ru}.{zh-tw}。{zh-cn}。{ko}.{es}.{fr}.{pt-br}.{de}."}),positionToColor(playerIndex))
	return true
end

function QuestPrivate.apocalypseQuestVeryPersonalUnit(card)
	local token=getObjectFromGUID("7e4e4c")
	if token==nil then return nil end
	local pos=token.getPosition()
	local best=nil
	local bestDistance=9
	for _, obj in pairs(QuestPrivate.apocalypseQuestAreaObjects()) do
		if obj.type=="Card" and (gameCardType(obj)=="Regular Unit" or gameCardType(obj)=="Elite Unit") then
			local p=obj.getPosition()
			local d=((p[1]-pos[1])^2)+((p[3]-pos[3])^2)
			if d<bestDistance then best=obj bestDistance=d end
		end
	end
	return bestDistance<2.5 and best or nil
end

function QuestPrivate.apocalypseQuestDisbandVeryPersonalUnit(card)
	local unit=QuestPrivate.apocalypseQuestVeryPersonalUnit(card)
	if unit==nil then return false end
	local cardType=gameCardType(unit)
	local deckName=cardType=="Elite Unit" and "Elite Unit" or cardType=="Regular Unit" and "Regular Unit" or nil
	local deck=deckName~=nil and standardDeckCycleObject(deckName) or nil
	if deck~=nil then
		standardDeckCycleMarkReturned(deckName,unit)
		putCardAtBottom(deck,unit)
		broadcastToAll("{en}A Very Personal Quest: the marked Unit was disbanded when the Quest left play.{ru}A Very Personal Quest: отмеченный отряд был распущен, когда задание покинуло игру.{zh-tw}A Very Personal Quest：任務離場時，帶有標記的部隊已被解散。{zh-cn}A Very Personal Quest：任务离场时，带有标记的部队已被解散。{ko}A Very Personal Quest: 퀘스트가 플레이에서 제거될 때 표시된 유닛이 해산되었습니다.{es}A Very Personal Quest: la Unidad marcada fue disuelta cuando la Misión salió del juego.{fr}A Very Personal Quest : l’Unité marquée a été dissoute lorsque la Quête a quitté le jeu.{pt-br}A Very Personal Quest: a Unidade marcada foi dispensada quando a Missão saiu de jogo.{de}A Very Personal Quest: Die markierte Einheit wurde aufgelöst, als die Quest das Spiel verließ.",{1,1,0.5})
		return true
	end
	return false
end

function QuestPrivate.apocalypseQuestStarterLocationLegal(card,playerIndex,option)
	if card==nil or option==nil then return true end
	local quest=apocalypseQuestData[card.guid]
	if quest==nil then return true end
	local rule=QuestPrivate.apocalypseQuestStarterLocationRule(card,option)
	if rule==nil then return true end
	local hex,mapObjects=QuestPrivate.apocalypseQuestCurrentPlayerHex(playerIndex)
	if hex==nil then return false end

	local handler=apocalypseQuestHandler(card)
	if handler~=nil and handler.starterLocationPrecheck~=nil and handler.starterLocationPrecheck(card,playerIndex,option,hex,mapObjects)~=true then return false end
	if handler~=nil and handler.starterLocationLegal~=nil then
		local handled,result=handler.starterLocationLegal(card,playerIndex,option,hex,mapObjects)
		if handled==true then return result==true end
	end

	if rule.warrens==true then
		if hex.hexType~="hills" or QuestPrivate.apocalypseQuestHexNoSite(hex)~=true then return false end
		local transit=gStates.apocalypseQuestMarkerTransit~=nil and gStates.apocalypseQuestMarkerTransit["02f996"] or nil
		if transit~=nil then return transit.terrainGUID==hex.terrainGUID and tostring(transit.bearing)==tostring(hex.bearing) end
		local token=getObjectFromGUID("02f996")
		local tokenTerrain,tokenBearing=nil,nil
		if token~=nil then tokenTerrain,tokenBearing=terrainHexAtPosition(token.getPosition(),mapObjects) end
		if tokenTerrain~=nil and tokenBearing~=nil then
			return tokenTerrain.guid==hex.terrainGUID and tostring(tokenBearing)==tostring(hex.bearing)
		end
		return true
	end
	if rule.inhabited==true and QuestPrivate.apocalypseQuestInhabitedFeature(hex.feature)~=true then return false end
	if rule.safe==true and QuestPrivate.apocalypseQuestHexSafe(hex,mapObjects,playerIndex)~=true then return false end
	if rule.unconqueredAdventure==true then
		if apocalypseQuestHexAdventureSite(hex)~=true or apocalypseQuestHexHasShield(hex,mapObjects,playerIndex,true)==true then return false end
	end
	--Stray Step 2: the Quest marker identifies the site, while the player's site Shield proves that
	--this Hero actually conquered that adventure site. This keeps Progress locked until conquest resolves.
	if rule.conqueredAdventure==true then
		if apocalypseQuestHexAdventureSite(hex)~=true or apocalypseQuestHexHasShield(hex,mapObjects,playerIndex,false)~=true then return false end
	end
	if rule.adjacentTerrain~=nil then
		local adjacent=false
		for _, other in ipairs(QuestPrivate.apocalypseQuestMapHexes()) do
			if other.hexType==rule.adjacentTerrain and runtimeMapHexesAdjacent(hex,other)==true then adjacent=true break end
		end
		if adjacent~=true then return false end
	end
	if rule.nearToken~=nil then
		local token=getObjectFromGUID(rule.nearToken)
		if token==nil then return false end
		local hexes=QuestPrivate.apocalypseQuestMapHexes()
		local tokenTerrain,tokenBearing=terrainHexAtPosition(token.getPosition(),mapObjects)
		if tokenTerrain==nil or tokenBearing==nil then return false end
		local tokenXY=angleToXY(tokenTerrain,tokenBearing)
		local tokenHex={terrainGUID=tokenTerrain.guid,bearing=tokenBearing,position={tokenXY[1],1.30,tokenXY[2]}}
		local distances=runtimeMapHexDistanceMap(hexes,{tokenHex})
		local distance=distances[runtimeMapHexKey(hex)]
		if distance==nil or (rule.nearDistanceMax~=nil and distance>rule.nearDistanceMax) then return false end
	end
	if rule.nearFeatures~=nil then
		local hexes=QuestPrivate.apocalypseQuestMapHexes()
		local starts={}
		for _, candidate in ipairs(hexes) do
			for _, feature in ipairs(rule.nearFeatures) do if QuestPrivate.apocalypseQuestFeatureMatches(candidate.feature,feature)==true then starts[#starts+1]=candidate break end end
		end
		if #starts==0 then return false end
		local distances=runtimeMapHexDistanceMap(hexes,starts)
		local distance=distances[runtimeMapHexKey(hex)]
		if distance==nil or (rule.nearDistanceMax~=nil and distance>rule.nearDistanceMax) then return false end
	end
	if rule.coastalTile==true then
		local hexes=QuestPrivate.apocalypseQuestMapHexes()
		if QuestPrivate.apocalypseQuestTerrainTileCoastal(hexes,hex.terrain)~=true then return false end
	end
	if rule.features~=nil then
		local matches=false
		for _, feature in ipairs(rule.features) do if QuestPrivate.apocalypseQuestFeatureMatches(hex.feature,feature)==true then matches=true break end end
		if matches~=true then return false end
	end
	if rule.terrains~=nil then
		local matches=false
		for _, terrainType in ipairs(rule.terrains) do if hex.hexType==terrainType then matches=true break end end
		if matches~=true then return false end
	end
	if rule.noSite==true and QuestPrivate.apocalypseQuestHexNoSite(hex)~=true then return false end
	if rule.destroyedMonastery==true and QuestPrivate.apocalypseQuestHexDestroyedMonastery(hex)~=true then return false end
	if rule.unconquered==true and apocalypseQuestHexHasShield(hex,mapObjects,playerIndex,true)==true then return false end
	if rule.freeWine==true and QuestPrivate.apocalypseQuestFreeWineLocationLegal(hex,mapObjects,playerIndex)~=true then return false end
	if rule.conqueredThisTurn==true and QuestPrivate.apocalypseQuestConqueredThisTurnLocationLegal(hex,playerIndex)~=true then return false end
	if rule.interactionSite==true and apocalypseQuestHexInteractionSite(hex,mapObjects,playerIndex)~=true then return false end
	if rule.requireInteractable==true and QuestPrivate.apocalypseQuestHexSiteInteractable(hex,mapObjects,playerIndex)~=true then return false end
	if rule.sameToken~=nil and QuestPrivate.apocalypseQuestTokenOnHex(rule.sameToken,hex,mapObjects)~=true then return false end
	if rule.excludeToken~=nil and QuestPrivate.apocalypseQuestTokenOnHex(rule.excludeToken,hex,mapObjects)==true then return false end
	if rule.randomObjectsTreasure==true and QuestPrivate.apocalypseQuestRandomObjectsTreasureLocation(hex,mapObjects)~=true then return false end
	return true
end

--Quest marker placement temporarily raises/locks an avatar so the marker can settle underneath it.
--Track that lift explicitly: preEndTurn() has its own avatar-lift sequence and must be able to finish a
--pending Quest lift before starting cleanup, otherwise the two delayed lock/unlock sequences can overlap.
function apocalypseQuestRestoreRaisedAvatar(playerIndex,immediate)
	if gStates==nil or gStates.apocalypseQuestRaisedAvatars==nil then return false end
	local lift=gStates.apocalypseQuestRaisedAvatars[playerIndex]
	if lift==nil then return false end
	--Clear first so an older Wait.condition timeout cannot move the avatar a second time later.
	gStates.apocalypseQuestRaisedAvatars[playerIndex]=nil
	local avatar=getObjectFromGUID(lift.guid)
	if avatar~=nil then
		avatar.setLock(false)
		--When another lift is about to start (notably preEndTurn), restore synchronously so it records the
		--real base height instead of the still-moving raised position. Normal quest completion can fall smoothly.
		if immediate==true then avatar.setPosition(lift.position)
		else avatar.setPositionSmooth({lift.position[1],lift.position[2]+1.0,lift.position[3]}) end
	end
	return true
end

--Place an "on your site" Quest marker directly beneath the acting Mage Knight. Raise the avatar first,
--using the same technique as end-of-turn site cleanup, so the token does not strike the model and tip over.
function QuestPrivate.apocalypseQuestPlaceMarkerAtPlayer(token,playerIndex)
	if token==nil then return false end
	local target=fracturedLandsTeleportSourcePosition(playerIndex)
	if target==nil then return false end
	local hex,_,terrain,bearing=runtimeMapHexAtPosition(target)
	if hex==nil or terrain==nil or bearing==nil then return false end
	--Never stack a new Quest lift on top of an unfinished one for this Hero.
	apocalypseQuestRestoreRaisedAvatar(playerIndex,true)
	local avatar=coopAssaultAvatarObject(playerIndex)
	local avatarPos=nil
	if avatar~=nil then
		local pos=avatar.getPosition()
		local dx=pos[1]-target[1]
		local dz=pos[3]-target[3]
		if (dx*dx)+(dz*dz)<1 then
			avatarPos={pos[1],pos[2],pos[3]}
			if gStates.apocalypseQuestRaisedAvatars==nil then gStates.apocalypseQuestRaisedAvatars={} end
			gStates.apocalypseQuestRaisedAvatars[playerIndex]={guid=avatar.guid,position=avatarPos}
			avatar.setPosition({pos[1],pos[2]+2,pos[3]})
			avatar.lock()
		end
	end
	apocalypseQuestUndoSiteToken(token.guid)
	token.unlock()
	token.setRotationSmooth({0,180,0})
	QuestPrivate.apocalypseQuestTrackMarkerMove(token,{target[1],1.22,target[3]},terrain.guid,bearing)
	token.setPositionSmooth({target[1],1.22,target[3]})
	if avatar~=nil and avatarPos~=nil then
		local tokenGUID=token.guid
		safeWaitFrames("Quests",function()
			safeWaitCondition("Quests",function() apocalypseQuestRestoreRaisedAvatar(playerIndex) end,function()
				local marker=getObjectFromGUID(tokenGUID)
				return marker==nil or marker.resting
			end,1.5,function() apocalypseQuestRestoreRaisedAvatar(playerIndex) end)
		end,2)
	end
	return true
end

function QuestPrivate.apocalypseQuestHexDestroyedMonastery(hex)
	if hex==nil then return false end
	if hex.feature=="monastery" and gStates.monasteryBurned~=nil and gStates.monasteryBurned[hex.terrainGUID]==true then return true end
	if hex.feature=="destroyed" and gStates.destroyedSites~=nil then
		for _, details in pairs(gStates.destroyedSites) do
			if details.terrainTile==hex.terrainGUID and tostring(details.hexAngle)==tostring(hex.bearing) and details.hexFeature=="monastery" then return true end
		end
	end
	return false
end

function QuestPrivate.apocalypseQuestHexHasOtherQuestMarker(hex, movingTokenGUID)
	if hex==nil or gStates.apocalypseQuestTokenGUIDs==nil then return false end
	for tokenGUID, _ in pairs(gStates.apocalypseQuestTokenGUIDs) do
		if tokenGUID~=movingTokenGUID then
			local transit=gStates.apocalypseQuestMarkerTransit~=nil and gStates.apocalypseQuestMarkerTransit[tokenGUID] or nil
			if transit~=nil then
				if transit.terrainGUID==hex.terrainGUID and tostring(transit.bearing)==tostring(hex.bearing) then return true end
			else
				local token=getObjectFromGUID(tokenGUID)
				if token~=nil then
					local pos=token.getPosition()
					local dx=pos[1]-hex.position[1]
					local dz=pos[3]-hex.position[3]
					if (dx*dx)+(dz*dz)<1 then return true end
				end
			end
		end
	end
	return false
end

function QuestPrivate.apocalypseQuestTerrainTileOnCurrentMapEdge(hexes, terrainGUID)
	for _, hex in ipairs(hexes or {}) do
		if hex.terrainGUID==terrainGUID then
			local neighbours=0
			for _, other in ipairs(hexes or {}) do
				if runtimeMapHexesAdjacent(hex,other)==true then neighbours=neighbours+1 end
			end
			if neighbours<6 then return true end
		end
	end
	return false
end

function QuestPrivate.apocalypseQuestTerrainTileCoastal(hexes, terrain)
	if terrain==nil then return false end
	local wedgeUsed=false
	for _, hex in ipairs(hexes or {}) do
		if hex.terrainGUID==startTerrain.wedge then wedgeUsed=true break end
	end
	if wedgeUsed==true then
		local start=getObjectFromGUID(startTerrain.wedge)
		if start==nil then return false end
		local startPos=start.getPosition()
		local pos=terrain.getPosition()
		local bearing=math.deg(math.atan2(pos[3]-startPos[3],pos[1]-startPos[1]))
		if bearing<0 then bearing=bearing+360 end
		--This is the same wedge-coast test already used by terrain deployment.
		if bearing<=41 or bearing>=99 then return true end
		return false
	end
	--Open maps do not use the wedge bearing restriction. Use the currently revealed outer edge;
	--the highlighted marker remains movable when several edge villages are available.
	return QuestPrivate.apocalypseQuestTerrainTileOnCurrentMapEdge(hexes,terrain.guid)
end

function QuestPrivate.apocalypseQuestMarkerLegalHexes(card, playerIndex, rule, token)
	if card==nil or rule==nil or token==nil then return {} end
	local hexes,mapObjects=QuestPrivate.apocalypseQuestMapHexes()
	if #hexes==0 then return {} end
	local playerHex=nil
	local playerDistances=nil
	if rule.distanceFromPlayerMax~=nil or rule.distanceFromPlayerMin~=nil then
		playerHex=apocalypseQuestPlayerHex(hexes,mapObjects,playerIndex)
		if playerHex==nil then return {} end
		playerDistances=runtimeMapHexDistanceMap(hexes,{playerHex})
	end
	local nearDistances=nil
	if rule.nearFeatures~=nil then
		local starts={}
		for _, hex in ipairs(hexes) do
			for _, feature in ipairs(rule.nearFeatures) do
				if QuestPrivate.apocalypseQuestFeatureMatches(hex.feature,feature)==true then starts[#starts+1]=hex break end
			end
		end
		if #starts==0 then return {} end
		nearDistances=runtimeMapHexDistanceMap(hexes,starts)
	end
	local markerDistances=nil
	if rule.distanceFromMarkerMax~=nil or rule.distanceFromMarkerMin~=nil then
		local markerHex=runtimeMapHexForPosition(hexes,token.getPosition(),mapObjects)
		if markerHex==nil then return {} end
		markerDistances=runtimeMapHexDistanceMap(hexes,{markerHex})
	end
	local candidates={}
	local coastalCache={}
	for _, hex in ipairs(hexes) do
		local legal=true
		if rule.terrains~=nil then
			legal=false
			for _, terrainType in ipairs(rule.terrains) do if hex.hexType==terrainType then legal=true break end end
		end
		if legal and rule.features~=nil then
			legal=false
			for _, feature in ipairs(rule.features) do if QuestPrivate.apocalypseQuestFeatureMatches(hex.feature,feature)==true then legal=true break end end
		end
		if legal and rule.requireInteractable==true and QuestPrivate.apocalypseQuestHexSiteInteractable(hex,mapObjects,playerIndex)~=true then legal=false end
		if legal and rule.destroyedMonastery==true and QuestPrivate.apocalypseQuestHexDestroyedMonastery(hex)~=true then legal=false end
		if legal and rule.safe==true and QuestPrivate.apocalypseQuestHexSafe(hex,mapObjects,playerIndex)~=true then legal=false end
		if legal and rule.noSite==true and QuestPrivate.apocalypseQuestHexNoSite(hex)~=true then legal=false end
		if legal and rule.unconqueredAdventure==true then
			if apocalypseQuestHexAdventureSite(hex)~=true or apocalypseQuestHexHasShield(hex,mapObjects,playerIndex,true)==true then legal=false end
		end
		if legal and rule.adventureSite==true and apocalypseQuestHexAdventureSite(hex)~=true then legal=false end
		if legal and rule.accessibleNoSite==true then
			local feature=string.lower(tostring(hex.feature or ""))
			local noSite=feature=="" or feature=="portal" or feature=="destroyed" or
				((feature=="rampaging" or feature=="draconum") and QuestPrivate.apocalypseQuestHexHasEnemy(hex,mapObjects)~=true) or
				(feature=="monastery" and gStates.monasteryBurned~=nil and gStates.monasteryBurned[hex.terrainGUID]==true)
			if hex.hexType=="lake" or hex.hexType=="mountain" or hex.hexType=="ocean" or noSite~=true then legal=false end
		end
		if legal and rule.adjacentTerrain~=nil then
			local adjacent=false
			for _, other in ipairs(hexes) do
				if other.hexType==rule.adjacentTerrain and runtimeMapHexesAdjacent(hex,other)==true then adjacent=true break end
			end
			if adjacent~=true then legal=false end
		end
		if legal and playerDistances~=nil then
			local distance=playerDistances[runtimeMapHexKey(hex)]
			if distance==nil then legal=false end
			if legal and rule.distanceFromPlayerMax~=nil and distance>rule.distanceFromPlayerMax then legal=false end
			if legal and rule.distanceFromPlayerMin~=nil and distance<rule.distanceFromPlayerMin then legal=false end
		end
		if legal and nearDistances~=nil then
			local distance=nearDistances[runtimeMapHexKey(hex)]
			if distance==nil then legal=false end
			if legal and rule.nearDistanceMax~=nil and distance>rule.nearDistanceMax then legal=false end
			if legal and rule.nearDistanceMin~=nil and distance<rule.nearDistanceMin then legal=false end
		end
		if legal and markerDistances~=nil then
			local distance=markerDistances[runtimeMapHexKey(hex)]
			if distance==nil then legal=false end
			if legal and rule.distanceFromMarkerMax~=nil and distance>rule.distanceFromMarkerMax then legal=false end
			if legal and rule.distanceFromMarkerMin~=nil and distance<rule.distanceFromMarkerMin then legal=false end
		end
		if legal and rule.coastalTile==true then
			if coastalCache[hex.terrainGUID]==nil then coastalCache[hex.terrainGUID]=QuestPrivate.apocalypseQuestTerrainTileCoastal(hexes,hex.terrain) end
			if coastalCache[hex.terrainGUID]~=true then legal=false end
		end
		if legal and QuestPrivate.apocalypseQuestHexHasOtherQuestMarker(hex,token.guid)==true then legal=false end
		if legal then candidates[#candidates+1]=hex end
	end
	local sourceHex=apocalypseQuestPlayerHex(hexes,mapObjects,playerIndex)
	table.sort(candidates,function(a,b)
		if rule.closestToPlayer==true and playerDistances~=nil then
			local ad=playerDistances[runtimeMapHexKey(a)]
			local bd=playerDistances[runtimeMapHexKey(b)]
			if ad~=nil and bd~=nil and ad~=bd then return ad<bd end
		end
		if sourceHex~=nil then
			local adx=a.position[1]-sourceHex.position[1]
			local adz=a.position[3]-sourceHex.position[3]
			local bdx=b.position[1]-sourceHex.position[1]
			local bdz=b.position[3]-sourceHex.position[3]
			local ad=(adx*adx)+(adz*adz)
			local bd=(bdx*bdx)+(bdz*bdz)
			if ad~=bd then return ad<bd end
		end
		if a.position[3]~=b.position[3] then return a.position[3]>b.position[3] end
		return a.position[1]<b.position[1]
	end)
	return candidates,hexes,mapObjects
end

function QuestPrivate.apocalypseQuestMarkerCurrentHexLegal(token,candidates,hexes,mapObjects)
	if token==nil then return false end
	local current=runtimeMapHexForPosition(hexes,token.getPosition(),mapObjects)
	if current==nil then return false end
	local key=runtimeMapHexKey(current)
	for _, candidate in ipairs(candidates or {}) do
		if runtimeMapHexKey(candidate)==key then return true end
	end
	return false
end

function QuestPrivate.apocalypseQuestHighlightMarker(token)
	if token==nil then return end
	if gStates.apocalypseQuestHighlightedTokens==nil then gStates.apocalypseQuestHighlightedTokens={} end
	token.highlightOn({1,0.9,0})
	gStates.apocalypseQuestHighlightedTokens[token.guid]=true
end

function QuestPrivate.apocalypseQuestClearMarkerHighlight(token)
	if token==nil then return end
	token.highlightOff({1,0.9,0})
	if gStates.apocalypseQuestHighlightedTokens~=nil then gStates.apocalypseQuestHighlightedTokens[token.guid]=nil end
end

function apocalypseQuestClearMarkerHighlights()
	if gStates.apocalypseQuestHighlightedTokens==nil then return end
	for guid, _ in pairs(gStates.apocalypseQuestHighlightedTokens) do
		local token=getObjectFromGUID(guid)
		if token~=nil then token.highlightOff({1,0.9,0}) end
	end
	gStates.apocalypseQuestHighlightedTokens={}
end

function QuestPrivate.apocalypseQuestMarkerPlacementCommitted(rule)
	if rule==nil or gStates.apocalypseQuestMarkerPlacements==nil then return false end
	for _, guid in ipairs(rule.tokens or {}) do
		if gStates.apocalypseQuestMarkerPlacements[guid]==true then return true end
	end
	return false
end

function QuestPrivate.apocalypseQuestCommitStepMarker(card, option)
	if card==nil or option==nil then return end
	local rule=QuestPrivate.apocalypseQuestMarkerRule(card,QuestPrivate.apocalypseQuestStepNumber(option.key))
	if rule==nil then return end
	local token=QuestPrivate.apocalypseQuestMarkerObject(rule)
	if token==nil then return end
	if gStates.apocalypseQuestMarkerPlacements==nil then gStates.apocalypseQuestMarkerPlacements={} end
	gStates.apocalypseQuestMarkerPlacements[token.guid]=true
end

function QuestPrivate.apocalypseQuestPlaceStepMarker(card, playerIndex, option, playerColor)
	if card==nil or option==nil then return true end
	local rule=QuestPrivate.apocalypseQuestMarkerRule(card,QuestPrivate.apocalypseQuestStepNumber(option.key))
	if rule==nil then return true end
	local token=QuestPrivate.apocalypseQuestMarkerObject(rule)
	if token==nil then
		if playerColor~=nil then broadcastToColor("{en}The required Quest marker could not be found.{ru}Не удалось найти требуемый жетон задания.{zh-tw}找不到所需的任務標記。{zh-cn}找不到所需的任务标记。{ko}필요한 퀘스트 마커를 찾지 못했습니다.{es}No se pudo encontrar el marcador de Misión requerido.{fr}Le marqueur de Quête requis est introuvable.{pt-br}O marcador de Missão necessário não foi encontrado.{de}Der erforderliche Questmarker wurde nicht gefunden.", playerColor, {1,0.55,0.2}) end
		return false
	end
	if rule.relocate~=true and QuestPrivate.apocalypseQuestMarkerPlacementCommitted(rule)==true then return true end
	if rule.atPlayer==true then
		if QuestPrivate.apocalypseQuestStarterLocationLegal(card,playerIndex,option)~=true then
			if playerColor~=nil then broadcastToColor("{en}Your Mage Knight is not at a valid location for this Quest step.{ru}Ваш Рыцарь-маг находится не в допустимом месте для этого шага задания.{zh-tw}你的魔法騎士不在此任務步驟的合法地點。{zh-cn}你的魔法骑士不在此任务步骤的合法地点。{ko}마법 기사가 이 퀘스트 단계에 유효한 장소에 있지 않습니다.{es}Tu Caballero Mago no está en un lugar válido para este paso de Misión.{fr}Votre Chevalier-Mage ne se trouve pas sur un lieu valide pour cette étape de Quête.{pt-br}Seu Cavaleiro-Mago não está em um local válido para esta etapa da Missão.{de}Dein Magieritter befindet sich nicht an einem gültigen Ort für diesen Quest-Schritt.", playerColor, warningColor) end
			return false
		end
		local playerHex=QuestPrivate.apocalypseQuestCurrentPlayerHex(playerIndex)
		if playerHex==nil or QuestPrivate.apocalypseQuestHexHasOtherQuestMarker(playerHex,token.guid)==true then
			if playerColor~=nil then broadcastToColor("{en}That map space already contains a Quest marker. Only one Quest marker may be placed in a map space.{ru}На этой клетке карты уже есть жетон задания. На одной клетке может находиться только один жетон задания.{zh-tw}該地圖空間已有任務標記。每個地圖空間只能放置一個任務標記。{zh-cn}该地图空间已有任务标记。每个地图空间只能放置一个任务标记。{ko}해당 지도 칸에 이미 퀘스트 마커가 있습니다. 한 지도 칸에는 퀘스트 마커를 하나만 놓을 수 있습니다.{es}Ese espacio del mapa ya contiene un marcador de Misión. Solo puede colocarse un marcador de Misión en cada espacio.{fr}Cette case de carte contient déjà un marqueur de Quête. Un seul marqueur de Quête peut être placé par case.{pt-br}Esse espaço do mapa já contém um marcador de Missão. Apenas um marcador de Missão pode ser colocado em cada espaço.{de}Dieses Kartenfeld enthält bereits einen Questmarker. Pro Kartenfeld darf nur ein Questmarker platziert werden.", playerColor, warningColor) end
			return false
		end
		local placed=QuestPrivate.apocalypseQuestPlaceMarkerAtPlayer(token,playerIndex)
		if placed~=true and playerColor~=nil then broadcastToColor("{en}The Quest marker could not be placed at your Mage Knight.{ru}Жетон задания не удалось разместить у вашего Рыцаря-мага.{zh-tw}無法在你的魔法騎士位置放置任務標記。{zh-cn}无法在你的魔法骑士位置放置任务标记。{ko}마법 기사 위치에 퀘스트 마커를 놓지 못했습니다.{es}No se pudo colocar el marcador de Misión junto a tu Caballero Mago.{fr}Le marqueur de Quête n’a pas pu être placé sur votre Chevalier-Mage.{pt-br}O marcador de Missão não pôde ser colocado em seu Cavaleiro-Mago.{de}Der Questmarker konnte nicht bei deinem Magieritter platziert werden.", playerColor, {1,0.55,0.2}) end
		return placed==true
	end
	local candidates,hexes,mapObjects=QuestPrivate.apocalypseQuestMarkerLegalHexes(card,playerIndex,rule,token)
	if #candidates==0 then
		QuestPrivate.apocalypseQuestClearMarkerHighlight(token)
		if playerColor~=nil then broadcastToColor("{en}There is no legal map space for this Quest marker yet.{ru}Для этого жетона задания пока нет допустимой клетки карты.{zh-tw}目前沒有可合法放置此任務標記的地圖空間。{zh-cn}目前没有可合法放置此任务标记的地图空间。{ko}아직 이 퀘스트 마커를 놓을 수 있는 합법적인 지도 칸이 없습니다.{es}Todavía no hay un espacio legal en el mapa para este marcador de Misión.{fr}Il n’existe pas encore de case de carte légale pour ce marqueur de Quête.{pt-br}Ainda não há espaço válido no mapa para este marcador de Missão.{de}Es gibt noch kein gültiges Kartenfeld für diesen Questmarker.", playerColor, warningColor) end
		apocalypseQuestUpdateProgressButtons(card)
		return false
	end
	local currentLegal=QuestPrivate.apocalypseQuestMarkerCurrentHexLegal(token,candidates,hexes,mapObjects)
	local target=candidates[1]
	if rule.closestToPlayer==true then
		local current=runtimeMapHexForPosition(hexes,token.getPosition(),mapObjects)
		currentLegal=current~=nil and runtimeMapHexKey(current)==runtimeMapHexKey(target)
	end
	if currentLegal~=true then
		token.unlock()
		QuestPrivate.apocalypseQuestTrackMarkerMove(token,{target.position[1],1.45,target.position[3]},target.terrainGUID,target.bearing)
		token.setPositionSmooth({target.position[1],1.45,target.position[3]})
	end
	if #candidates>1 then
		QuestPrivate.apocalypseQuestHighlightMarker(token)
		if playerColor~=nil then
			broadcastToColor(joinLang({tostring(#candidates),"{en} legal spaces are available. The first was selected; move the highlighted Quest marker if you prefer another.{ru} допустимых клеток доступно. Выбрана первая; переместите выделенный жетон задания, если предпочитаете другую.{zh-tw} 個合法空間可用。已選擇第一個；若偏好其他位置，請移動高亮任務標記。{zh-cn} 个合法空间可用。已选择第一个；若偏好其他位置，请移动高亮任务标记。{ko}개의 합법적인 칸이 있습니다. 첫 번째를 선택했습니다. 다른 곳을 원하면 강조된 퀘스트 마커를 이동하십시오.{es} espacios legales disponibles. Se seleccionó el primero; mueve el marcador de Misión resaltado si prefieres otro.{fr} cases légales disponibles. La première a été sélectionnée ; déplacez le marqueur de Quête surligné si vous en préférez une autre.{pt-br} espaços válidos disponíveis. O primeiro foi selecionado; mova o marcador de Missão destacado se preferir outro.{de} gültige Felder sind verfügbar. Das erste wurde ausgewählt; bewege den hervorgehobenen Questmarker, wenn du ein anderes bevorzugst."}), playerColor, {1,1,0.5})
		end
	else
		QuestPrivate.apocalypseQuestClearMarkerHighlight(token)
	end
	return true
end

function QuestPrivate.apocalypseQuestMarkerPlacementAvailable(card,playerIndex,option)
	if option==nil then return true end
	local rule=QuestPrivate.apocalypseQuestMarkerRule(card,QuestPrivate.apocalypseQuestStepNumber(option.key))
	if rule==nil then return true end
	local token=QuestPrivate.apocalypseQuestMarkerObject(rule)
	if token==nil then return false end
	if rule.relocate~=true and QuestPrivate.apocalypseQuestMarkerPlacementCommitted(rule)==true then return true end
	if rule.atPlayer==true then
		if QuestPrivate.apocalypseQuestStarterLocationLegal(card,playerIndex,option)~=true then return false end
		local playerHex=QuestPrivate.apocalypseQuestCurrentPlayerHex(playerIndex)
		return playerHex~=nil and QuestPrivate.apocalypseQuestHexHasOtherQuestMarker(playerHex,token.guid)~=true
	end
	local candidates,hexes,mapObjects=QuestPrivate.apocalypseQuestMarkerLegalHexes(card,playerIndex,rule,token)
	if QuestPrivate.apocalypseQuestMarkerCurrentHexLegal(token,candidates,hexes,mapObjects)==true then return true end
	return #candidates>0
end

function apocalypseQuestRefreshOfferButtons()
	if apocalypseQuestsUsed()~=true then return end
	--Do not touch Object UI while any Quest-offer movement is active. TTS can throw an engine-side
	--Object reference error when setAttribute overlaps setPositionSmooth/takeObject. Coalesce refreshes.
	if gStates.apocalypseQuestOfferRefilling==true or gStates.apocalypseQuestOfferMoving==true then
		gStates.apocalypseQuestOfferButtonRefreshPending=true
		return
	end

	--Avatar movement can refresh every Quest card at once. All physical Quest attachments live inside
	--the permanent Quest-area scripting zone, so one small zone snapshot replaces a whole-table scan.
	--Identify the offer once and pre-group attachments for every offer card from that same snapshot.
	local allObjects=QuestPrivate.apocalypseQuestAreaObjects()
	local offerCards=QuestPrivate.apocalypseQuestOfferCards(allObjects)
	local objectCache={}
	local cardPositions={}
	for _, questCard in ipairs(offerCards) do
		objectCache[questCard.guid]={}
		cardPositions[questCard.guid]=questCard.getPosition()
	end
	local known=gStates.apocalypseQuestCardGUIDs or {}
	--Make the offer snapshot available while building the object cache so Independent-row ownership
	--doesn't need to rediscover the same six cards for every Shield/mana token.
	apocalypseQuestRefreshOfferCardsCache=offerCards
	for _, obj in pairs(allObjects) do
		if known[obj.guid]~=true then
			local rowOwner=QuestPrivate.apocalypseQuestIndependentShieldRowOwnerGUID(obj,offerCards)
			if rowOwner~=nil and objectCache[rowOwner]~=nil then
				objectCache[rowOwner][#objectCache[rowOwner]+1]=obj
			else
				local pos=obj.getPosition()
				for _, questCard in ipairs(offerCards) do
					local source=cardPositions[questCard.guid]
					if math.abs(pos[1]-source[1])<1.7 and math.abs(pos[3]-source[3])<2.5 and pos[2]>source[2]-1.5 and pos[2]<source[2]+3.0 then
						objectCache[questCard.guid][#objectCache[questCard.guid]+1]=obj
						break
					end
				end
			end
		end
	end
	apocalypseQuestRefreshObjectsByCard=objectCache
	--Map legality is another shared refresh cost. Cache the map objects, revealed hex list and each queried
	--player hex only for this synchronous offer refresh; ordinary calls outside it still read live state.
	apocalypseQuestRefreshMapCache={playerHexes={}}
	for _, questCard in ipairs(offerCards) do
		local ok, err=pcall(apocalypseQuestUpdateProgressButtons, questCard)
		if ok~=true then print("QUEST BUTTON REFRESH ERROR: "..tostring(apocalypseQuestName(questCard))..": "..tostring(err)) end
	end
	apocalypseQuestRefreshMapCache=nil
	apocalypseQuestRefreshObjectsByCard=nil
	apocalypseQuestRefreshOfferCardsCache=nil
end

function QuestPrivate.apocalypseQuestRefreshAfterMarkerChange()
	--Bag returns are effectively immediate, while reward/relocation markers may still be smooth-moving.
	--Refresh once now and once after the motion has had time to clear its old hex.
	safeWaitFrames("Quests",function() apocalypseQuestRefreshOfferButtons() end,3)
	safeWaitFrames("Quests",function() apocalypseQuestRefreshOfferButtons() end,60)
end

--Quest-specific lifecycle hooks. Generic Quest flow dispatches through these instead of
--branching on card GUIDs; individual Quest helpers still own their detailed rules.
local goblinWarrensHandler=apocalypseQuestRegisterHandler("72099f")
--Goblin Warrens has a taller printed header area than the standard Quest marker position. Keep its
--marker aligned to the card rather than a fixed table coordinate so offer-layout changes remain safe.
goblinWarrensHandler.revealTokenPosition=function(cardPos) return {cardPos[1],cardPos[2]+0.45,cardPos[3]+0.77} end
goblinWarrensHandler.revealBagPosition=function(cardPos) return {cardPos[1],cardPos[2]+0.42,cardPos[3]-1.18} end
goblinWarrensHandler.filterOption=function(card,playerIndex,action,option,state,context)
	if tostring(option.key)=="1" and action=="Progress" then context.include=apocalypseQuestGoblinAttemptReady(playerIndex) end
	return context
end
goblinWarrensHandler.directChoices=function(card,playerIndex,state)
	if state.step==1 and apocalypseQuestGoblinAttempt(playerIndex,true)==nil then
		return {{key="Goblin1",action="GoblinWarrens",label="1"},{key="Goblin2",action="GoblinWarrens",label="2"},{key="Goblin3",action="GoblinWarrens",label="3"}}
	end
end
goblinWarrensHandler.directChoiceLegal=function(card,playerIndex,choice)
	if choice.action~="GoblinWarrens" then return false end
	local option=QuestPrivate.apocalypseQuestChoiceOption(card,"1")
	return true,option~=nil and apocalypseQuestGoblinAttempt(playerIndex,true)==nil and QuestPrivate.apocalypseQuestStarterLocationLegal(card,playerIndex,option)==true and QuestPrivate.apocalypseQuestMarkerPlacementAvailable(card,playerIndex,option)==true
end
goblinWarrensHandler.directAction=function(player,card,playerIndex,selected,key)
	if selected.action~="GoblinWarrens" then return false end
	apocalypseQuestStartGoblinWarrens(card,playerIndex,tonumber(key:match("(%d+)$")))
	return true
end
goblinWarrensHandler.buttonState=function(card,playerIndex,questState,result)
	if questState~=nil and questState.step==1 then result.progressLabel="Proceed" end
end
goblinWarrensHandler.bottomDeckBeforeReveal=function() gStates.apocalypseQuestGoblinWarrens={} end

local executionHandler=apocalypseQuestRegisterHandler("8939c0")
executionHandler.directChoices=function(card,playerIndex,state)
	if state.step==1 then return {{key="1a",action="Complete"},{key="1b",action="Combat"},{key="1c",action="Complete"}} end
end
executionHandler.storeDirectBranch=true
executionHandler.storeDirectCombatBranch=true
executionHandler.rewardCompletionGate=function(card,playerIndex,option,fought,allDefeated)
	if tostring(option.key)=="1b" and fought>0 then return true,true,allDefeated==true and "Complete" or "Fail" end
	return false
end
executionHandler.launchCombat=function(card,playerIndex)
	return QuestPrivate.apocalypseQuestSpawnEnemyToCombat(card,playerIndex,"gray",false,0,0)~=nil and 1 or 0
end

local nobleWarriorHandler=apocalypseQuestRegisterHandler("bbd087")
nobleWarriorHandler.filterOption=function(card,playerIndex,action,option,state,context)
	if QuestPrivate.apocalypseQuestStepNumber(option.key)==3 and action=="Complete" then context.include=context.include==true and apocalypseQuestCardCrystalColor(card)~=nil end
	return context
end
nobleWarriorHandler.directChoices=function(card,playerIndex,state)
	if state.step~=3 or apocalypseQuestCardCrystalColor(card)==nil then return nil end
	local option=QuestPrivate.apocalypseQuestChoiceOption(card,"3a")
	if option~=nil and QuestPrivate.apocalypseQuestStarterLocationLegal(card,playerIndex,option)==true then
		return {{key="3a",action="Complete",label="3A"},{key="3b",action="Complete",label="3B"}}
	end
end
nobleWarriorHandler.directChoiceLegal=function(card,playerIndex,choice)
	if QuestPrivate.apocalypseQuestStepNumber(choice.key)==3 and apocalypseQuestCardCrystalColor(card)==nil then return true,false end
	return false
end

local freeWineHandler=apocalypseQuestRegisterHandler("37e2ce")
freeWineHandler.filterOption=function(card,playerIndex,action,option,state,context)
	if state.step==2 and (action=="Complete" or action=="Fail") then
		context.include=action=="Complete" and QuestPrivate.apocalypseQuestFreeWineSuccessReady(playerIndex) or QuestPrivate.apocalypseQuestFreeWineFailureReady(playerIndex)
		context.skipLegality=true
		context.skipMarker=true
	end
	return context
end
freeWineHandler.directChoices=function(card,playerIndex,state)
	if state.step==1 then return {{key="1a",action="Progress"},{key="1b",action="Complete"}} end
end
freeWineHandler.bottomDeckBeforeReveal=function() gStates.apocalypseQuestFreeWineAssault=nil end

local underSiegeHandler=apocalypseQuestRegisterHandler("a6d5cc")
underSiegeHandler.mayAct=function(card,playerIndex)
	local readyPlayer=QuestPrivate.apocalypseQuestUnderSiegeReadyPlayer()
	if readyPlayer~=nil and readyPlayer~=playerIndex then return true,false end
	return false
end
underSiegeHandler.actionEnabled=function(card,playerIndex,action)
	if action=="Abandon" and QuestPrivate.apocalypseQuestPersonalShieldOwner(card)~=nil then return true,false end
	return false
end
underSiegeHandler.directChoices=function(card,playerIndex,state)
	if state.step==2 and QuestPrivate.apocalypseQuestCombatStartedThisTurn(card,2)~=true then
		return {{key="2a",action="Combat",label="2A"},{key="2b",action="Fail",label="{en}2B - Fail{ru}2B - Провал{zh-tw}2B - 失敗{zh-cn}2B - 失败{ko}2B - 실패{es}2B - Fallar{fr}2B - Échouer{pt-br}2B - Falhar{de}2B - Scheitern"}}
	end
end
underSiegeHandler.directChoiceLegal=function(card,playerIndex,choice)
	if QuestPrivate.apocalypseQuestStepNumber(choice.key)==2 and QuestPrivate.apocalypseQuestUnderSiegeStep2ChoiceLegal(playerIndex,choice.key)~=true then return true,false end
	return false
end
underSiegeHandler.buttonState=function(card,playerIndex,questState,result)
	if questState==nil or questState.step==1 then result.progressLabel="Proceed" end
	if questState~=nil and questState.step==2 then result.failLabel="2B - Fail" end
end
underSiegeHandler.combatAvailable=function(card,playerIndex,state)
	if state.step==2 and QuestPrivate.apocalypseQuestUnderSiegeStep2ChoiceLegal(playerIndex,"2a")~=true then return true,false end
	return false
end
underSiegeHandler.storeDirectCombatBranch=false
underSiegeHandler.enemyAttackMovesAll=true
underSiegeHandler.launchCombat=function(card,playerIndex)
	local moved=QuestPrivate.apocalypseQuestMoveCardEnemiesToPlayer(card,playerIndex,nil)
	if moved>0 then broadcastToAll("{en}Under Siege: ignore fortification for this Quest fight and add Block 5 during the Block phase.{ru}Under Siege: игнорируйте укрепление в этом бою задания и добавьте Блок 5 во время фазы Блока.{zh-tw}Under Siege：此任務戰鬥忽略要塞化，並在格擋階段加入格擋 5。{zh-cn}Under Siege：此任务战斗忽略要塞化，并在格挡阶段加入格挡 5。{ko}Under Siege: 이 퀘스트 전투에서는 요새화를 무시하고 방어 단계에 방어 5를 추가합니다.{es}Under Siege: ignora la fortificación en este combate de Misión y añade Bloqueo 5 durante la fase de Bloqueo.{fr}Under Siege : ignorez la fortification pour ce combat de Quête et ajoutez Blocage 5 pendant la phase de Blocage.{pt-br}Under Siege: ignore fortificação neste combate da Missão e adicione Bloqueio 5 durante a fase de Bloqueio.{de}Under Siege: Ignoriere für diesen Quest-Kampf die Befestigung und füge in der Blockphase Block 5 hinzu.",positionToColor(playerIndex)) end
	return moved
end
underSiegeHandler.failureEffect=function(card,playerIndex,option)
	if tostring(option.key)=="2b" then QuestPrivate.apocalypseQuestUnderSiegeFailure(card,playerIndex) end
end
underSiegeHandler.starterLocationLegal=function(card,playerIndex,option,hex)
	if tostring(option.key)=="1" then return true,QuestPrivate.apocalypseQuestUnderSiegeLocationLegal(hex,playerIndex) end
	return false
end
underSiegeHandler.personalAction=function(player,card)
	if QuestPrivate.apocalypseQuestPersonalShieldOwner(card)==nil then return false end
	broadcastToColor("{en}Under Siege must be resolved with 2A or 2B; it cannot be abandoned after Step 1.{ru}Under Siege должно быть разрешено через 2A или 2B; после шага 1 его нельзя покинуть.{zh-tw}Under Siege 必須以 2A 或 2B 結算；步驟 1 後不能放棄。{zh-cn}Under Siege 必须以 2A 或 2B 结算；步骤 1 后不能放弃。{ko}Under Siege는 2A 또는 2B로 해결해야 하며 1단계 이후에는 포기할 수 없습니다.{es}Under Siege debe resolverse con 2A o 2B; no puede abandonarse después del Paso 1.{fr}Under Siege doit être résolu avec 2A ou 2B ; il ne peut pas être abandonné après l’Étape 1.{pt-br}Under Siege deve ser resolvido com 2A ou 2B; não pode ser abandonado após a Etapa 1.{de}Under Siege muss mit 2A oder 2B abgewickelt werden; nach Schritt 1 kann es nicht aufgegeben werden.",player.color,warningColor)
	QuestPrivate.apocalypseQuestInterfaceAdd(card,true)
	return true
end
underSiegeHandler.actionPlayer=function(card,action,defaultIndex)
	if action~="Progress" then return defaultIndex,false end
	local readyPlayer=QuestPrivate.apocalypseQuestUnderSiegeReadyPlayer()
	if readyPlayer~=nil then return readyPlayer,true end
	return defaultIndex,false
end
underSiegeHandler.bottomDeckBeforeReveal=function()
	gStates.apocalypseQuestUnderSiegeReady=nil
	gStates.apocalypseQuestUnderSiegeStep2=nil
end

local burnedMonasteryHandler=apocalypseQuestRegisterHandler("82a935")
burnedMonasteryHandler.mayActBeforeOwnership=function(card,playerIndex)
	if QuestPrivate.apocalypseQuestPlayerBurnedMonastery(playerIndex)==true then return true,false end
	return false
end
burnedMonasteryHandler.actionEnabled=function(card,playerIndex,action)
	if action=="Abandon" and QuestPrivate.apocalypseQuestCombatStartedThisTurn(card,2)==true and gStates.apocalypseQuestDirectBranch~=nil and gStates.apocalypseQuestDirectBranch[card.guid]=="2c" then return true,false end
	return false
end
burnedMonasteryHandler.directChoices=function(card,playerIndex,state)
	if state.step==2 then return {{key="2a",action="Complete"},{key="2b",action="Complete"},{key="2c",action="Combat"}} end
end
burnedMonasteryHandler.storeDirectBranch=true
burnedMonasteryHandler.storeDirectCombatBranch=true
burnedMonasteryHandler.launchCombat=function(card,playerIndex)
	return QuestPrivate.apocalypseQuestSpawnEnemyToCombat(card,playerIndex,"purple",false,0,0)~=nil and 1 or 0
end

local bardHandler=apocalypseQuestRegisterHandler("8455b5")
bardHandler.directChoices=function(card,playerIndex,state)
	if state.step==2 and QuestPrivate.apocalypseQuestPersonalShieldOwner(card)==playerIndex then
		return {{key="2a",action="Progress",label="2A"},{key="2b",action="Progress",label="2B"},{key="2c",action="Progress",label="2C"}}
	end
end
bardHandler.directChoicesAllowAbandon=true

local traitorHandler=apocalypseQuestRegisterHandler("ce70fb")
traitorHandler.actionEnabled=function(card,playerIndex,action)
	if action=="Fail" and gStates.apocalypseQuestCombatBranch~=nil and gStates.apocalypseQuestCombatBranch[card.guid]=="2b" then return true,false end
	return false
end
traitorHandler.directChoices=function(card,playerIndex,state)
	if state.step==2 then return {{key="2a",action="Combat"},{key="2b",action="Combat"}} end
end
traitorHandler.storeDirectCombatBranch=true
traitorHandler.combatBranchChoice=true
traitorHandler.prepareCombatLaunch=function(card,playerIndex,chosenColor)
	if chosenColor~=nil then
		if gStates.apocalypseQuestCombatBranch==nil then gStates.apocalypseQuestCombatBranch={} end
		gStates.apocalypseQuestCombatBranch[card.guid]=chosenColor
	end
end
traitorHandler.launchCombat=function(card,playerIndex)
	local level=turnOrder[playerIndex].level or 1
	local choice=(gStates.apocalypseQuestCombatBranch~=nil and gStates.apocalypseQuestCombatBranch[card.guid]) or "2a"
	local pile=nil
	if choice=="2b" then pile=level<=2 and "gray" or level<=6 and "purple" or "white"
	else pile=level<=4 and "gray" or level<=8 and "purple" or "white" end
	local enemy=QuestPrivate.apocalypseQuestSpawnEnemyToCombat(card,playerIndex,pile,true,0,0,"Coun")
	if enemy==nil then return 0 end
	if choice=="2b" then
		if gStates.monsterPerks[enemy.guid]==nil then gStates.monsterPerks[enemy.guid]={} end
		gStates.monsterPerks[enemy.guid].questHalfFame=true
		broadcastToAll("{en}Traitor 2b: this enemy's Fame reward will be halved, rounded up.{ru}Traitor 2b: награда Славы за этого врага уменьшается вдвое с округлением вверх.{zh-tw}Traitor 2b：此敵人的聲望值獎勵減半並向上取整。{zh-cn}Traitor 2b：此敌人的声望值奖励减半并向上取整。{ko}Traitor 2b: 이 적의 명성 보상은 절반으로 줄이고 올림합니다.{es}Traitor 2b: la recompensa de Fama de este enemigo se reduce a la mitad, redondeando hacia arriba.{fr}Traitor 2b : la récompense de Renommée de cet ennemi est divisée par deux, arrondie au supérieur.{pt-br}Traitor 2b: a recompensa de Fama deste inimigo é reduzida pela metade, arredondando para cima.{de}Traitor 2b: Die Ruhmbelohnung dieses Gegners wird halbiert und aufgerundet.",positionToColor(playerIndex))
	end
	return 1
end

local hunterMoonHandler=apocalypseQuestRegisterHandler("783076")
hunterMoonHandler.directChoices=function(card,playerIndex,state)
	if state.step==1 then return {{key="1a",action="Progress"},{key="1b",action="Progress"}} end
end
hunterMoonHandler.enemyAttackButton=true
hunterMoonHandler.launchCombat=function(card,playerIndex)
	local moved=QuestPrivate.apocalypseQuestMoveCardEnemiesToPlayer(card,playerIndex,1)
	if moved>0 and apocalypseQuestCardManaColor(card)=="Black" and gStates.dayRound==true then broadcastToAll("{en}Hunter's Moon: during Day, the black mana token removes Swift from the werewolf for this combat.{ru}Hunter's Moon: Днём чёрный жетон маны убирает Быстроту у оборотня на этот бой.{zh-tw}Hunter's Moon：白天時，黑色魔力標記在此戰鬥中移除狼人身上的迅捷。{zh-cn}Hunter's Moon：白天时，黑色魔力标记在此战斗中移除狼人身上的迅捷。{ko}Hunter's Moon: 낮에는 검은 마나 토큰이 이 전투 동안 늑대인간의 신속을 제거합니다.{es}Hunter's Moon: durante el Día, la ficha de maná negra elimina Veloz del hombre lobo para este combate.{fr}Hunter's Moon : pendant le Jour, le jeton de mana noir retire Rapide au loup-garou pour ce combat.{pt-br}Hunter's Moon: durante o Dia, a ficha de mana preta remove Rápido do lobisomem neste combate.{de}Hunter's Moon: Am Tag entfernt der schwarze Manamarker für diesen Kampf Schnell vom Werwolf.",positionToColor(playerIndex)) end
	return moved
end

local richMerchantHandler=apocalypseQuestRegisterHandler("8cff07")
richMerchantHandler.filterOption=function(card,playerIndex,action,option,state,context)
	if tostring(option.key)=="1" then
		local rolled=gStates.apocalypseQuestRichMerchantRoll~=nil and gStates.apocalypseQuestRichMerchantRoll[card.guid] or nil
		if action=="Progress" then context.include=rolled==nil end
		if action=="Complete" then context.include=rolled~=nil and rolled.mage==turnOrder[playerIndex].mage and rolled.result~="Black" end
	end
	return context
end
richMerchantHandler.buttonState=function(card,playerIndex,questState,result)
	if questState~=nil and questState.step==1 then
		result.progressLabel="Proceed"
		local rolled=gStates.apocalypseQuestRichMerchantRoll~=nil and gStates.apocalypseQuestRichMerchantRoll[card.guid] or nil
		if rolled~=nil and rolled.mage==turnOrder[playerIndex].mage and rolled.result~="Black" then
			result.progress=false
			result.abandon=false
		end
	end
end
richMerchantHandler.advanceProgress=function(card,state,option)
	if tostring(option.key)~="1" then return false end
	local rolled=gStates.apocalypseQuestRichMerchantRoll~=nil and gStates.apocalypseQuestRichMerchantRoll[card.guid] or nil
	return rolled==nil or rolled.result~="Black"
end
richMerchantHandler.launchCombat=function(card,playerIndex)
	return QuestPrivate.apocalypseQuestSpawnEnemyToCombat(card,playerIndex,"gray",false,0,0)~=nil and 1 or 0
end

local guardDutyHandler=apocalypseQuestRegisterHandler("08ffcf")
guardDutyHandler.filterOption=function(card,playerIndex,action,option,state,context)
	if action=="Fail" then context.skipLocation=true end
	return context
end

local veryPersonalHandler=apocalypseQuestRegisterHandler("b401dc")
veryPersonalHandler.filterOption=function(card,playerIndex,action,option,state,context)
	if state.step==2 and (action=="Complete" or action=="Fail") then
		context.skipLegality=true
		context.skipMarker=true
	end
	return context
end
veryPersonalHandler.bottomDeckAfterReveal=function(card)
	if gStates.apocalypseQuestVeryPersonalSuccess==nil or gStates.apocalypseQuestVeryPersonalSuccess[card.guid]~=true then QuestPrivate.apocalypseQuestDisbandVeryPersonalUnit(card) end
end

local mineDoomHandler=apocalypseQuestRegisterHandler("485cc5")
mineDoomHandler.starterLocationPrecheck=function(card,playerIndex,option,hex,mapObjects)
	if gStates.apocalypseQuestMarkerPlacements~=nil and gStates.apocalypseQuestMarkerPlacements["2f238c"]==true then
		return QuestPrivate.apocalypseQuestTokenOnHex("2f238c",hex,mapObjects)==true
	end
	return true
end
mineDoomHandler.progressColors=function(card,playerIndex,action,option)
	if action=="Progress" and tostring(option.key)=="1" then return true,QuestPrivate.apocalypseQuestMineDoomColors(playerIndex) end
	return false
end
mineDoomHandler.buttonState=function(card,playerIndex,questState,result)
	if questState~=nil and questState.step==2 then
		result.progressLabel="Attack"
		result.progress=QuestPrivate.apocalypseQuestCombatAvailable(card,playerIndex)
		result.fight=false
	end
end
mineDoomHandler.progressCombatLaunch=function(player,card,playerIndex,action)
	if action~="Progress" then return false end
	local questState=QuestPrivate.apocalypseQuestProgressState(card,playerIndex,false)
	if questState==nil or questState.step~=2 then return false end
	QuestPrivate.apocalypseQuestLaunchCombat(card,playerIndex,player.color,nil)
	if getObjectFromGUID(card.guid)~=nil and (gStates.apocalypseQuestCombatChoice==nil or gStates.apocalypseQuestCombatChoice[card.guid]==nil) then QuestPrivate.apocalypseQuestInterfaceAdd(card,true) end
	return true
end
mineDoomHandler.preserveCombatLaunchOnProgressKeys={["1"]=true}
mineDoomHandler.launchCombat=function(card,playerIndex,playerColor,chosenColor)
	if chosenColor==nil then
		local colors=QuestPrivate.apocalypseQuestMineDoomColors(playerIndex)
		if #colors==1 then chosenColor=colors[1]
		elseif #colors>1 then chosenColor=gStates.apocalypseQuestMineDoomColor~=nil and gStates.apocalypseQuestMineDoomColor[card.guid] or colors[1] end
	end
	return QuestPrivate.apocalypseQuestLaunchMineDoom(card,playerIndex,chosenColor,#QuestPrivate.apocalypseQuestMineDoomColors(playerIndex)>1 and 1 or 0) and 1 or 0
end

local fogHandler=apocalypseQuestRegisterHandler("dd35bb")
fogHandler.buttonState=function(card,playerIndex,questState,result)
	if questState~=nil and questState.step==3 then
		result.progressLabel="Proceed"
		result.progress=QuestPrivate.apocalypseQuestFogPossessedReady(card)==true and QuestPrivate.apocalypseQuestCombatAvailable(card,playerIndex)
		result.fight=false
	end
end
fogHandler.progressCombatLaunch=function(player,card,playerIndex,action)
	if action~="Progress" then return false end
	local questState=QuestPrivate.apocalypseQuestProgressState(card,playerIndex,false)
	if questState==nil or questState.step~=3 or QuestPrivate.apocalypseQuestFogPossessedReady(card)~=true then return false end
	QuestPrivate.apocalypseQuestLaunchCombat(card,playerIndex,player.color,nil)
	if getObjectFromGUID(card.guid)~=nil then QuestPrivate.apocalypseQuestInterfaceAdd(card,true) end
	return true
end
fogHandler.launchCombat=function(card,playerIndex)
	broadcastToAll("{en}The Fog: skip the Ranged and Siege Attack phase during this Quest combat.{ru}The Fog: пропустите фазу Дальней и Осадной атаки в этом бою задания.{zh-tw}The Fog：此任務戰鬥跳過遠程與攻城攻擊階段。{zh-cn}The Fog：此任务战斗跳过远程与攻城攻击阶段。{ko}The Fog: 이 퀘스트 전투에서는 원거리 및 공성 공격 단계를 건너뜁니다.{es}The Fog: omite la fase de Ataque a Distancia y de Asedio durante este combate de Misión.{fr}The Fog : ignorez la phase d’Attaque à Distance et de Siège pendant ce combat de Quête.{pt-br}The Fog: pule a fase de Ataque à Distância e de Cerco durante este combate da Missão.{de}The Fog: Überspringe in diesem Quest-Kampf die Fern- und Belagerungsangriffsphase.",positionToColor(playerIndex))
	return QuestPrivate.apocalypseQuestMoveCardEnemiesToPlayer(card,playerIndex,1)
end

local spellThiefHandler=apocalypseQuestRegisterHandler("8cdac4")
local fistfulHandler=apocalypseQuestRegisterHandler("66ea80")
local function launchClickedOrFirstQuestEnemy(card,playerIndex,playerColor,chosenColor,clickedEnemyGUID)
	if clickedEnemyGUID~=nil then
		local clicked=getObjectFromGUID(clickedEnemyGUID)
		local onCard=false
		for _,enemy in ipairs(apocalypseQuestObjectsOnCard(card)) do if enemy.guid==clickedEnemyGUID then onCard=true break end end
		if clicked~=nil and onCard==true and monsterPugs[clicked.guid]~=nil and QuestPrivate.apocalypseQuestMoveEnemyToPlayer(card,playerIndex,clicked)==true then return 1 end
		return 0
	end
	return QuestPrivate.apocalypseQuestMoveCardEnemiesToPlayer(card,playerIndex,1)
end
spellThiefHandler.enemyAttackButton=true
spellThiefHandler.launchCombat=launchClickedOrFirstQuestEnemy
fistfulHandler.enemyAttackButton=true
fistfulHandler.launchCombat=launchClickedOrFirstQuestEnemy
fistfulHandler.fistfulSetupKey="1"

local wanderingOracleHandler=apocalypseQuestRegisterHandler("d70436")
wanderingOracleHandler.preserveCombatLaunchOnProgressKeys={["2"]=true}
wanderingOracleHandler.launchCombat=function(card,playerIndex)
	local level=turnOrder[playerIndex].level or 1
	local pile=level<=4 and "tan" or level<=8 and "white" or "red"
	return QuestPrivate.apocalypseQuestSpawnEnemyToCombat(card,playerIndex,pile,false,0,0)~=nil and 1 or 0
end

local pilgrimageHandler=apocalypseQuestRegisterHandler("c73a1f")
pilgrimageHandler.enemyAttackButton=true
pilgrimageHandler.launchCombat=function(card,playerIndex) return QuestPrivate.apocalypseQuestMoveCardEnemiesToPlayer(card,playerIndex,1) end

local artificerHandler=apocalypseQuestRegisterHandler("bb2828")
artificerHandler.progressColors=function(card,playerIndex,action,option)
	if action=="Progress" and tostring(option.key)=="2" then return true,QuestPrivate.apocalypseQuestArtificerAvailableColors(card,playerIndex) end
	return false
end

local magicOverloadHandler=apocalypseQuestRegisterHandler("6175e8")
magicOverloadHandler.skipGenericStepMarker=function(card,option) return tostring(option.key)=="3" end

local misadventureHandler=apocalypseQuestRegisterHandler("082f39")
misadventureHandler.starterLocationLegal=function(card,playerIndex,option,hex,mapObjects)
	if tostring(option.key)=="1" and gStates.apocalypseQuestMarkerPlacements~=nil and gStates.apocalypseQuestMarkerPlacements["afcfc1"]==true then
		return true,QuestPrivate.apocalypseQuestTokenOnHex("afcfc1",hex,mapObjects)==true
	end
	return false
end

local function apocalypseQuestUsesGenericStepMarker(card,option)
	local handler=apocalypseQuestHandler(card)
	return handler==nil or handler.skipGenericStepMarker==nil or handler.skipGenericStepMarker(card,option)~=true
end

function QuestPrivate.apocalypseQuestPlayerMayAct(card, playerIndex)
	if card==nil or turnOrder[playerIndex]==nil then return false end
	local playerDetails=turnOrder[playerIndex]
	if playerDetails.mage==nil or playerDetails.mage=="nobody" or playerDetails.mage==gStates.positionMageKnight[5] or playerDetails.dropoutState~=nil then return false end
	local quest=apocalypseQuestData[card.guid]
	if quest==nil then return false end
	local handler=apocalypseQuestHandler(card)
	if handler~=nil and handler.mayActBeforeOwnership~=nil then
		local handled,result=handler.mayActBeforeOwnership(card,playerIndex)
		if handled==true then return result==true end
	end
	if quest.questType~="Personal" then return true end
	local ownerIndex=QuestPrivate.apocalypseQuestPersonalShieldOwner(card)
	if ownerIndex~=nil then return ownerIndex==playerIndex end
	if handler~=nil and handler.mayAct~=nil then
		local handled,result=handler.mayAct(card,playerIndex)
		if handled==true then return result==true end
	end
	if QuestPrivate.apocalypseQuestPlayerHasOtherPersonalQuest(playerIndex, card.guid)==true then return false end
	return true
end
function QuestPrivate.apocalypseQuestCurrentOptions(card, playerIndex, action)
	local options={}
	local quest=card~=nil and apocalypseQuestData[card.guid] or nil
	if quest==nil or QuestPrivate.apocalypseQuestPlayerMayAct(card, playerIndex)~=true then return options end
	--An abandoned Personal Quest must be explicitly resumed before any further step action.
	--The Resume button swaps the neutral Shield back to the acting player's Shield in place.
	if quest.questType=="Personal" and QuestPrivate.apocalypseQuestNeutralShield(card)~=nil then return options end
	local state=QuestPrivate.apocalypseQuestProgressState(card, playerIndex, true)
	if state==nil or state.completed==true then return options end
	local groupStepReady=true
	if quest.allPlayersMustCompleteStep~=nil and state.step>quest.allPlayersMustCompleteStep then
		groupStepReady=QuestPrivate.apocalypseQuestAllPlayersCompletedStep(card, quest.allPlayersMustCompleteStep)
	end
	local placementAvailable=nil
	for _, option in ipairs(quest.steps or {}) do
		--Only the acting player's current numeric step can contribute an action. Branched steps (2a/2b/2c)
		--still all pass this gate, but later Quest steps no longer perform needless map/special checks.
		if QuestPrivate.apocalypseQuestStepNumber(option.key)==state.step and groupStepReady==true then
			local include=false
			if action=="Progress" then
				include=option.completes~=true
				if quest.progressCompletingSteps~=nil and quest.progressCompletingSteps[option.key]==true then include=true end
			elseif action=="Complete" then
				local failOnly=quest.failOnlySteps~=nil and quest.failOnlySteps[option.key]==true
				include=option.completes==true and failOnly~=true
			elseif action=="Fail" then
				include=option.canFail==true
			end
			local handler=apocalypseQuestHandler(card)
			local context={include=include,skipLegality=false,skipLocation=false,skipMarker=false}
			if handler~=nil and handler.filterOption~=nil then context=handler.filterOption(card,playerIndex,action,option,state,context) or context end
			include=context.include==true
			if include==true and context.skipLegality~=true then
				local locationReady=context.skipLocation==true or QuestPrivate.apocalypseQuestStarterLocationLegal(card,playerIndex,option)
				local specialReady=action=="Fail" and apocalypseQuestFailureReady(card,option,playerIndex) or apocalypseQuestStepSpecialLegal(card,playerIndex,option)
				include=locationReady==true and specialReady==true
			end
			if include==true and action~="Fail" and context.skipMarker~=true then
				if placementAvailable==nil then
					local ok, available=pcall(QuestPrivate.apocalypseQuestMarkerPlacementAvailable, card, playerIndex, option)
					if ok==true then
						placementAvailable=available
					else
						placementAvailable=false
						print("QUEST MAP CHECK ERROR: "..tostring(apocalypseQuestName(card)).." step "..tostring(option.key)..": "..tostring(available))
					end
				end
				include=placementAvailable==true
			end
			if include==true then options[#options+1]=option end
		end
	end
	return options
end
function QuestPrivate.apocalypseQuestActionEnabled(card, playerIndex, action)
	local handler=apocalypseQuestHandler(card)
	if handler~=nil and handler.actionEnabled~=nil then
		local handled,result=handler.actionEnabled(card,playerIndex,action)
		if handled==true then return result==true end
	end
	if gStates.mineClaimPending~=nil and gStates.mineClaimPending.source=="Quest" and gStates.mineClaimPending.questCardGUID==card.guid then return false end
	if action=="Abandon" then
		local quest=card~=nil and apocalypseQuestData[card.guid] or nil
		if quest==nil or quest.questType~="Personal" then return false end
		local ownerIndex=QuestPrivate.apocalypseQuestPersonalShieldOwner(card)
		if ownerIndex~=nil then return ownerIndex==playerIndex end
		if QuestPrivate.apocalypseQuestNeutralShield(card)~=nil then return QuestPrivate.apocalypseQuestPlayerMayAct(card, playerIndex)==true end
		return false
	end
	return #QuestPrivate.apocalypseQuestCurrentOptions(card, playerIndex, action)>0
end
function QuestPrivate.apocalypseQuestSnapWorldPosition(card, stepKey, leftOffset)
	if card==nil then return nil end
	local quest=apocalypseQuestData[card.guid]
	if quest==nil or quest.snapOrder==nil then return nil end
	local snapIndex=nil
	for index, key in ipairs(quest.snapOrder) do if key==stepKey then snapIndex=index break end end
	if snapIndex==nil then return nil end
	local snaps=card.getSnapPoints() or {}
	table.sort(snaps, function(a,b)
		local az=(a.position~=nil and (a.position.z or a.position[3])) or 0
		local bz=(b.position~=nil and (b.position.z or b.position[3])) or 0
		return az<bz
	end)
	local snap=snaps[snapIndex]
	if snap==nil or snap.position==nil then return nil end
	local pos=snap.position
	local x,y,z=pos.x or pos[1] or 0,pos.y or pos[2] or 0,pos.z or pos[3] or 0
	local base=card.positionToWorld({x,y,z})
	local offset=tonumber(leftOffset) or 0
	if offset==0 then return base end
	--On the Quest cards local +X is visual left. Normalize it so each row slot is exactly
	--one world unit apart regardless of the card's scale.
	local axis=card.positionToWorld({x+1,y,z})
	local bx,bz=base.x or base[1],base.z or base[3]
	local dx,dz=(axis.x or axis[1])-bx,(axis.z or axis[3])-bz
	local length=math.sqrt((dx*dx)+(dz*dz))
	if length<0.001 then return base end
	return {bx+((dx/length)*offset),base.y or base[2],bz+((dz/length)*offset)}
end

function QuestPrivate.apocalypseQuestIndependentShieldRowOwnerGUID(obj,offerCards)
	if obj==nil then return nil end
	local name=obj.getName()
	if name~="Shield" and name~="Red Mana" and name~="Blue Mana" and name~="Green Mana" and name~="White Mana" and name~="Gold Mana" and name~="Black Mana" then return nil end
	local pos=obj.getPosition()
	local bestGUID=nil
	local bestDistance=0.31
	for _, questCard in ipairs(offerCards or QuestPrivate.apocalypseQuestOfferCards()) do
		local quest=apocalypseQuestData[questCard.guid]
		if quest~=nil and quest.questType=="Independent" and quest.snapOrder~=nil then
			local maxSlot=math.max(0,(tonumber(gStates.playerCount) or 4)-1)
			for _, key in ipairs(quest.snapOrder) do
				for slot=0,maxSlot do
					local target=QuestPrivate.apocalypseQuestSnapWorldPosition(questCard,key,slot)
					if target~=nil then
						local dx=pos[1]-target[1]
						local dz=pos[3]-target[3]
						local distance=(dx*dx)+(dz*dz)
						if distance<bestDistance then bestDistance=distance bestGUID=questCard.guid end
					end
				end
			end
		end
	end
	return bestGUID
end

function QuestPrivate.apocalypseQuestNearestRowSlot(position, targets, maxSlot)
	local nearestSlot=nil
	local nearestDistance=nil
	for slot=0,maxSlot do
		local target=targets[slot]
		if target~=nil then
			local dx=position[1]-target[1]
			local dz=position[3]-target[3]
			local distance=(dx*dx)+(dz*dz)
			if nearestDistance==nil or distance<nearestDistance then nearestDistance=distance nearestSlot=slot end
		end
	end
	return nearestSlot,nearestDistance
end

function QuestPrivate.apocalypseQuestIndependentShieldRowPosition(card,stepKey,movingShieldGUID)
	if card==nil then return nil end
	local quest=apocalypseQuestData[card.guid]
	if quest==nil or quest.questType~="Independent" then return QuestPrivate.apocalypseQuestSnapWorldPosition(card,stepKey) end
	local maxSlot=math.max(0,(tonumber(gStates.playerCount) or 4)-1)
	local targets={}
	for slot=0,maxSlot do targets[slot]=QuestPrivate.apocalypseQuestSnapWorldPosition(card,stepKey,slot) end
	if targets[0]==nil then return nil end
	local occupied={}
	local areaObjects=QuestPrivate.apocalypseQuestAreaObjects()
	local offerCards=QuestPrivate.apocalypseQuestOfferCards(areaObjects)
	for _, obj in pairs(areaObjects) do
		if obj.guid~=movingShieldGUID and obj.getName()=="Shield" and obj.getDescription()~="Neutral" then
			local rowOwner=QuestPrivate.apocalypseQuestIndependentShieldRowOwnerGUID(obj,offerCards)
			if rowOwner==nil or rowOwner==card.guid then
				local nearestSlot,nearestDistance=QuestPrivate.apocalypseQuestNearestRowSlot(obj.getPosition(),targets,maxSlot)
				--Each existing Shield claims only its nearest row slot. This keeps a manually shifted Shield
				--from accidentally blocking both neighbouring one-unit slots.
				if nearestSlot~=nil and nearestDistance<0.31 then occupied[nearestSlot]=true end
			end
		end
	end
	--If the moving Shield was manually placed on a free destination slot already, leave it where the player put it.
	local moving=movingShieldGUID~=nil and getObjectFromGUID(movingShieldGUID) or nil
	if moving~=nil then
		local pos=moving.getPosition()
		local nearestSlot,nearestDistance=QuestPrivate.apocalypseQuestNearestRowSlot(pos,targets,maxSlot)
		if nearestSlot~=nil and nearestDistance<0.31 and occupied[nearestSlot]~=true then return pos end
	end
	for slot=0,maxSlot do if occupied[slot]~=true then return targets[slot] end end
	--This should only happen after an unexpected extra Shield; continue the row rather than stacking.
	return QuestPrivate.apocalypseQuestSnapWorldPosition(card,stepKey,maxSlot+1)
end
function QuestPrivate.apocalypseQuestRaisedPiecePosition(position,height)
	if position==nil then return nil end
	return {position[1],position[2]+(height or 0.20),position[3]}
end
function QuestPrivate.apocalypseQuestShieldSupplyBag(owner)
	local bags=gStates.apocalypseQuestShieldBagGUIDs
	if bags==nil then return nil end
	local guid=bags[owner]
	if guid==nil then return nil end
	return getObjectFromGUID(guid)
end
function QuestPrivate.apocalypseQuestTakePlayerShield(playerIndex, position)
	local playerDetails=turnOrder[playerIndex]
	if playerDetails==nil then return nil end
	local shieldBag=QuestPrivate.apocalypseQuestShieldSupplyBag(playerDetails.mage)
	if shieldBag==nil then return nil end
	return shieldBag.takeObject({position=QuestPrivate.apocalypseQuestRaisedPiecePosition(position),rotation={0,180,0},smooth=true})
end
function QuestPrivate.apocalypseQuestTakeNeutralShield(position)
	local shieldBag=QuestPrivate.apocalypseQuestShieldSupplyBag("Neutral")
	if shieldBag==nil then return nil end
	return shieldBag.takeObject({position=QuestPrivate.apocalypseQuestRaisedPiecePosition(position),rotation={0,180,0},smooth=true})
end
function QuestPrivate.apocalypseQuestPositionProgressShield(card, playerIndex, option)
	local quest=card~=nil and apocalypseQuestData[card.guid] or nil
	if quest==nil or quest.questType=="Simple" then return true end
	local world=QuestPrivate.apocalypseQuestSnapWorldPosition(card, option.key)
	if world==nil then
		--Repeatable steps such as Under Siege 2a and Cursed 2a deliberately have no new snap:
		--the Shield remains on the previous numbered step. Travelling Merchant needs no physical move.
		return true
	end
	local shield=nil
	if quest.questType=="Collective" then
		shield=QuestPrivate.apocalypseQuestNeutralShield(card)
	elseif quest.questType=="Independent" then
		shield=QuestPrivate.apocalypseQuestPlayerShield(card, playerIndex)
		world=QuestPrivate.apocalypseQuestIndependentShieldRowPosition(card,option.key,shield~=nil and shield.guid or nil)
	else
		shield=QuestPrivate.apocalypseQuestPlayerShield(card, playerIndex)
		if shield==nil then
			local neutral=QuestPrivate.apocalypseQuestNeutralShield(card)
			if neutral~=nil then neutral.destruct() end
		end
	end
	world=apocalypseQuestPlannedWorldPosition(card,world)
	local target=QuestPrivate.apocalypseQuestRaisedPiecePosition(world)
	if shield==nil then
		shield=quest.questType=="Collective" and QuestPrivate.apocalypseQuestTakeNeutralShield(world) or QuestPrivate.apocalypseQuestTakePlayerShield(playerIndex,world)
	end
	if shield==nil then return false end
	shield.unlock()
	shield.setPositionSmooth(target)
	apocalypseQuestRegisterMoveAttachment(card,shield,target)
	return true
end
function QuestPrivate.apocalypseQuestRemovePlayerShield(card, playerIndex)
	local shield=QuestPrivate.apocalypseQuestPlayerShield(card, playerIndex)
	if shield~=nil and getObjectFromGUID(shield.guid)~=nil then shield.destruct() return true end
	return false
end
function QuestPrivate.apocalypseQuestAwardStepPoint(card, playerIndex, option, state, questState)
	if option==nil or option.point~=true or state==nil or questState==nil then return false end
	local quest=apocalypseQuestData[card.guid]
	local limit=math.max(0, tonumber(option.pointLimit) or 1)
	if limit==0 then return false end
	if quest.globalPointLimits~=nil and quest.globalPointLimits[option.key]~=nil then
		limit=quest.globalPointLimits[option.key]
		local used=questState.globalPoints[option.key] or 0
		if used>=limit then return false end
		questState.globalPoints[option.key]=used+1
	else
		local used=state.points[option.key] or 0
		if used>=limit then return false end
		state.points[option.key]=used+1
	end
	QuestPrivate.apocalypseQuestScoreGain(playerIndex, 1)
	return true
end
function QuestPrivate.apocalypseQuestAdvanceProgress(card, state, option)
	if card==nil or state==nil or option==nil then return end
	local quest=apocalypseQuestData[card.guid]
	local handler=apocalypseQuestHandler(card)
	if handler~=nil and handler.advanceProgress~=nil and handler.advanceProgress(card,state,option)==true then return end
	local repeatCount=math.max(0, tonumber(option.repeatCount) or 0)
	if repeatCount>0 then
		local count=(state.repeats[option.key] or 0)+1
		state.repeats[option.key]=count
		if repeatCount<99 and count>=repeatCount then
			local nextStep=QuestPrivate.apocalypseQuestNextStepNumber(quest, state.step)
			if nextStep~=nil then state.step=nextStep end
		end
	else
		local nextStep=QuestPrivate.apocalypseQuestNextStepNumber(quest, state.step)
		if nextStep~=nil then state.step=nextStep end
	end
end
function QuestPrivate.apocalypseQuestAllPlayersCompleted(card)
	local quest=card~=nil and apocalypseQuestData[card.guid] or nil
	if quest==nil or quest.allPlayersComplete~=true then return false end
	local questState=gStates.apocalypseQuestProgress~=nil and gStates.apocalypseQuestProgress[card.guid] or nil
	if questState==nil or questState.players==nil then return false end
	local active=0
	for playerIndex, playerDetails in ipairs(turnOrder) do
		if playerDetails.mage~=nil and playerDetails.mage~="nobody" and playerDetails.mage~=gStates.positionMageKnight[5] and playerDetails.dropoutState==nil then
			active=active+1
			local state=questState.players[playerDetails.mage]
			if state==nil or state.completed~=true then return false end
		end
	end
	return active>0
end
function QuestPrivate.apocalypseQuestAllPlayersCompletedStep(card, requiredStep)
	local quest=card~=nil and apocalypseQuestData[card.guid] or nil
	local questState=gStates.apocalypseQuestProgress~=nil and gStates.apocalypseQuestProgress[card.guid] or nil
	if quest==nil or quest.questType~="Independent" or questState==nil or questState.players==nil then return false end
	local active=0
	for _, playerDetails in ipairs(turnOrder) do
		if playerDetails.mage~=nil and playerDetails.mage~="nobody" and playerDetails.mage~=gStates.positionMageKnight[5] and playerDetails.dropoutState==nil then
			active=active+1
			local state=questState.players[playerDetails.mage]
			if state==nil or (state.completed~=true and (state.step or 1)<=requiredStep) then return false end
		end
	end
	return active>0
end
function QuestPrivate.apocalypseQuestOptionsNeedChoice(card, action, options)
	if options==nil or #options<=1 then return false end
	--Different printed branches can have the same Quest-point value but different consequences.
	--If more than one Progress/Complete branch is legal, always let the player choose the printed branch.
	return action=="Progress" or action=="Complete"
end
function QuestPrivate.apocalypseQuestChoiceKeys(options)
	local keys={}
	for _, option in ipairs(options or {}) do keys[#keys+1]=option.key end
	return keys
end
function QuestPrivate.apocalypseQuestChoiceOption(card, key)
	local quest=card~=nil and apocalypseQuestData[card.guid] or nil
	if quest==nil then return nil end
	for _, option in ipairs(quest.steps or {}) do if option.key==key then return option end end
	return nil
end
function QuestPrivate.apocalypseQuestShowChoice(card, playerIndex, action, options)
	if card==nil or options==nil or #options==0 then return false end
	if gStates.apocalypseQuestPendingChoice==nil then gStates.apocalypseQuestPendingChoice={} end
	gStates.apocalypseQuestPendingChoice[card.guid]={playerIndex=playerIndex, action=action, keys=QuestPrivate.apocalypseQuestChoiceKeys(options)}
	--Rebuild the card UI in one setXmlTable call. TTS does not apply a UI removal synchronously,
	--so remove-then-add in the same frame could leave the card blank until a later refresh.
	QuestPrivate.apocalypseQuestInterfaceAdd(card, true)
	return true
end

function QuestPrivate.apocalypseQuestDirectChoices(card,playerIndex)
	local choices={}
	if card==nil or QuestPrivate.apocalypseQuestPlayerMayAct(card,playerIndex)~=true then return choices end
	local state=QuestPrivate.apocalypseQuestProgressState(card,playerIndex,false)
	if state==nil or state.completed==true then return choices end
	local already=gStates.apocalypseQuestDirectBranch~=nil and gStates.apocalypseQuestDirectBranch[card.guid] or nil
	if already~=nil then return choices end
	local handler=apocalypseQuestHandler(card)
	if handler~=nil and handler.directChoices~=nil then return handler.directChoices(card,playerIndex,state) or choices end
	return choices
end

function QuestPrivate.apocalypseQuestDirectChoiceLegal(card,playerIndex,choice)
	if card==nil or choice==nil then return false end
	local handler=apocalypseQuestHandler(card)
	if handler~=nil and handler.directChoiceLegal~=nil then
		local handled,result=handler.directChoiceLegal(card,playerIndex,choice)
		if handled==true then return result==true end
	end
	local option=QuestPrivate.apocalypseQuestChoiceOption(card,choice.key)
	if option==nil or QuestPrivate.apocalypseQuestStarterLocationLegal(card,playerIndex,option)~=true then return false end
	if choice.action~="Combat" and QuestPrivate.apocalypseQuestMarkerPlacementAvailable(card,playerIndex,option)~=true then return false end
	return true
end
function QuestPrivate.apocalypseQuestButtonState(card, playerIndex)
	local result={
		progress=QuestPrivate.apocalypseQuestActionEnabled(card,playerIndex,"Progress"),
		progressLabel="Progress",
		complete=QuestPrivate.apocalypseQuestActionEnabled(card,playerIndex,"Complete"),
		abandon=QuestPrivate.apocalypseQuestActionEnabled(card,playerIndex,"Abandon"),
		fail=QuestPrivate.apocalypseQuestActionEnabled(card,playerIndex,"Fail"),
		failLabel="Fail"
	}
	local quest=apocalypseQuestData[card.guid]
	result.abandonLabel=quest~=nil and quest.questType=="Personal" and QuestPrivate.apocalypseQuestPersonalShieldOwner(card)==nil and QuestPrivate.apocalypseQuestNeutralShield(card)~=nil and "Resume" or "Abandon"
	local enemyAttackButton=apocalypseQuestUsesEnemyAttackButton(card)==true
	if enemyAttackButton==true then QuestPrivate.apocalypseQuestRefreshEnemyAttackButtons(card,playerIndex) end
	local questState=QuestPrivate.apocalypseQuestProgressState(card,playerIndex,false)
	result.fight=enemyAttackButton~=true and apocalypseQuestCombatRelevant(card,playerIndex) and QuestPrivate.apocalypseQuestCombatAvailable(card,playerIndex)
	local handler=apocalypseQuestHandler(card)
	if handler~=nil and handler.buttonState~=nil then handler.buttonState(card,playerIndex,questState,result) end
	return result
end

function apocalypseQuestUpdateProgressButtons(card)
	if card==nil then return end
	if gStates.apocalypseQuestOfferRefilling==true or gStates.apocalypseQuestOfferMoving==true then
		gStates.apocalypseQuestOfferButtonRefreshPending=true
		return
	end
	if gStates.apocalypseQuestPendingChoice~=nil and gStates.apocalypseQuestPendingChoice[card.guid]~=nil then return end
	if gStates.apocalypseQuestCombatChoice~=nil and gStates.apocalypseQuestCombatChoice[card.guid]~=nil then return end
	local interfacePlayer=QuestPrivate.apocalypseQuestUnderSiegeInterfacePlayerIndex(card)
	if QuestPrivate.apocalypseQuestPersonalBlockedByOther(card,interfacePlayer)==true then
		QuestPrivate.apocalypseQuestInterfaceAdd(card,true)
		return
	end
	if #QuestPrivate.apocalypseQuestDirectChoices(card,interfacePlayer)>0 then QuestPrivate.apocalypseQuestInterfaceAdd(card,true) return end
	local prefix="ApocalypseQuest"..card.guid
	--A direct branch UI has no normal Fight/Progress/Complete controls to update. Once the branch
	--advances the Quest, rebuild the interface instead of trying to set attributes on missing elements.
	local normalControls=false
	for _,element in ipairs(card.UI.getXmlTable() or {}) do
		if element.attributes~=nil and element.attributes.id==prefix.."Fight" then normalControls=true break end
	end
	if normalControls~=true then QuestPrivate.apocalypseQuestInterfaceAdd(card,true) return end
	local state=QuestPrivate.apocalypseQuestButtonState(card,interfacePlayer)
	local function enabledChanged(id,wanted)
		local current=string.lower(tostring(card.UI.getAttribute(prefix..id,"interactable") or "false"))=="true"
		return current~=(wanted==true)
	end
	local rebuild=enabledChanged("Progress",state.progress) or enabledChanged("Complete",state.complete) or
		enabledChanged("Abandon",state.abandon) or enabledChanged("Fail",state.fail)
	if rebuild==true and card.isSmoothMoving()==false then
		--Quest cards can remain resting=false indefinitely when a Shield/enemy is touching them. Scripted
		--movement is the real lifecycle boundary: once setPositionSmooth has finished, rebuild immediately.
		QuestPrivate.apocalypseQuestInterfaceAdd(card,true)
		return
	end
	--While a scripted offer move is still running, parent Button attributes are safe to update in place.
	--This keeps avatar-dependent legality responsive without treating attachment physics as card movement.
	--Generated Quest combats have no enemy token to carry the normal rampager Attack icon.
	--Show the same icon beneath the Quest controls only when the fight can actually be started here.
	card.UI.setAttribute(prefix.."Fight", "active", state.fight and "true" or "false")
	card.UI.setAttribute(prefix.."Fight", "interactable", state.fight and "true" or "false")
	card.UI.setAttribute(prefix.."Progress", "interactable", state.progress and "true" or "false")
	card.UI.setAttribute(prefix.."Progress", "color", state.progress and "#d8c79d" or "#b5b5b5")
	card.UI.setAttribute(prefix.."ProgressText", "text", state.progressLabel or "{en}Progress{ru}Продолжить{zh-tw}進行{zh-cn}进行{ko}진행{es}Progresar{fr}Progresser{pt-br}Progredir{de}Fortschritt")
	card.UI.setAttribute(prefix.."ProgressText", "color", state.progress and "#000000" or "#777777")
	card.UI.setAttribute(prefix.."Complete", "interactable", state.complete and "true" or "false")
	card.UI.setAttribute(prefix.."Complete", "color", state.complete and "#a8c99a" or "#b5b5b5")
	card.UI.setAttribute(prefix.."CompleteText", "color", state.complete and "#000000" or "#777777")
	card.UI.setAttribute(prefix.."Abandon", "interactable", state.abandon and "true" or "false")
	card.UI.setAttribute(prefix.."Abandon", "color", state.abandon and "#d5b784" or "#b5b5b5")
	card.UI.setAttribute(prefix.."AbandonText", "text", state.abandonLabel)
	card.UI.setAttribute(prefix.."AbandonText", "color", state.abandon and "#000000" or "#777777")
	card.UI.setAttribute(prefix.."Fail", "interactable", state.fail and "true" or "false")
	card.UI.setAttribute(prefix.."Fail", "color", state.fail and "#c99090" or "#b5b5b5")
	card.UI.setAttribute(prefix.."FailText", "text", state.failLabel or "{en}Fail{ru}Провал{zh-tw}失敗{zh-cn}失败{ko}실패{es}Fallar{fr}Échouer{pt-br}Falhar{de}Scheitern")
	card.UI.setAttribute(prefix.."FailText", "color", state.fail and "#000000" or "#777777")
	if rebuild==true then
		local cardGUID=card.guid
		safeWaitCondition("Quests",function()
			local live=getObjectFromGUID(cardGUID)
			if live~=nil then QuestPrivate.apocalypseQuestInterfaceAdd(live,true) end
		end,function()
			local live=getObjectFromGUID(cardGUID)
			return live==nil or live.isSmoothMoving()==false
		end,5,function()
			local live=getObjectFromGUID(cardGUID)
			if live~=nil then QuestPrivate.apocalypseQuestInterfaceAdd(live,true) end
		end)
	end
end
function QuestPrivate.apocalypseQuestWhenResting(objectGUID,callback,timeout)
	local obj=objectGUID~=nil and getObjectFromGUID(objectGUID) or nil
	if obj==nil then return false end
	if obj.resting==true then callback(obj) return true end
	safeWaitCondition("Quests",function()
		local live=getObjectFromGUID(objectGUID)
		if live~=nil then callback(live) end
	end,function()
		local live=getObjectFromGUID(objectGUID)
		return live==nil or live.resting==true
	end,timeout or 5,function()
		--Do not run position-sensitive Quest setup while an object is still moving. Retry the resting
		--gate instead; this helper is intended to be reused as more Quest components return to smooth move.
		if getObjectFromGUID(objectGUID)~=nil then QuestPrivate.apocalypseQuestWhenResting(objectGUID,callback,timeout) end
	end)
	return true
end

function QuestPrivate.apocalypseQuestInterfaceAdd(card, forceRebuild)
	if card==nil or card.type~="Card" then return end
	card.lock()
	--Reminder cards are deliberately parked outside the live Quest offer and must never regain their
	--Progress/Complete UI from a delayed resting/refresh callback left over from their final action.
	if gStates.apocalypseQuestReminderCards~=nil and gStates.apocalypseQuestReminderCards[card.guid]~=nil then
		QuestPrivate.apocalypseQuestInterfaceRemove(card)
		return
	end
	if gStates.apocalypseQuestOfferRefilling==true or gStates.apocalypseQuestOfferMoving==true then
		gStates.apocalypseQuestOfferButtonRefreshPending=true
		return
	end
	if card.isSmoothMoving()==true then
		local cardGUID=card.guid
		safeWaitCondition("Quests",function()
			local live=getObjectFromGUID(cardGUID)
			if live~=nil then QuestPrivate.apocalypseQuestInterfaceAdd(live,forceRebuild) end
		end,function()
			local live=getObjectFromGUID(cardGUID)
			return live==nil or live.isSmoothMoving()==false
		end,5,function()
			local live=getObjectFromGUID(cardGUID)
			if live~=nil then QuestPrivate.apocalypseQuestInterfaceAdd(live,forceRebuild) end
		end)
		return
	end
	local xml=card.UI.getXmlTable() or {}
	local pending=gStates.apocalypseQuestPendingChoice~=nil and gStates.apocalypseQuestPendingChoice[card.guid] or nil
	local combatPending=gStates.apocalypseQuestCombatChoice~=nil and gStates.apocalypseQuestCombatChoice[card.guid] or nil
	local existing=false
	local fightExisting=false
	local kept={}
	for _, element in ipairs(xml) do
		local id=element.attributes~=nil and element.attributes.id or nil
		if id~=nil and id:sub(1, 15)=="ApocalypseQuest" then
			existing=true
			if id=="ApocalypseQuest"..card.guid.."Fight" then fightExisting=true end
		else
			kept[#kept+1]=element
		end
	end
	local interfacePlayer=QuestPrivate.apocalypseQuestUnderSiegeInterfacePlayerIndex(card)
	local directChoices=QuestPrivate.apocalypseQuestDirectChoices(card,interfacePlayer)
	if existing==true and fightExisting==true and forceRebuild~=true and pending==nil and combatPending==nil and #directChoices==0 then
		apocalypseQuestUpdateProgressButtons(card)
		return
	end
	--When changing between the four normal buttons and a branch-choice interface, strip the old
	--Quest elements from the local XML table and write the replacement atomically.
	if existing==true then xml=kept end
	local questDetails=apocalypseQuestData[card.guid]
	if questDetails~=nil and questDetails.questTokens~=nil and #questDetails.questTokens>0 and getObjectFromGUID(GUID.bag.apocalypseQuestTokens)==nil then
		local cardGUID=card.guid
		safeWaitFrames("Quests",function() local questCard=getObjectFromGUID(cardGUID) if questCard~=nil then QuestPrivate.apocalypseQuestInterfaceAdd(questCard) end end, 3)
		return
	end
	if apocalypseQuestRevealSetup(card)~=true then return end
	local prefix="ApocalypseQuest"..card.guid
	local buttonScale="0.22 0.22"
	local function questButton(action, label, x, y, color, interactable)
		return {tag="Button", attributes={id=prefix..action, onClick="global/apocalypseQuestCardAction", width=400, height=150, position=tostring(x).." "..tostring(y).." -12", rotation="0 0 180", scale=buttonScale, color=color, interactable=interactable~=false and "true" or "false"}, children={{tag="Text", attributes={id=prefix..action.."Text", font="Fonts/MKCardText", fontSize=65, color=interactable~=false and "#000000" or "#777777", alignment="MiddleCenter", text=label}}}}
	end
	local function questAttackButton(active)
		return {tag="Button", attributes={id=prefix.."Fight", onClick="global/apocalypseQuestCardAction", width=240, height=240, position="0 274 -12", rotation="0 0 180", scale=buttonScale, color="rgba(0,0,0,0.0)", active=active and "true" or "false", interactable=active and "true" or "false"}, children={{tag="Image", attributes={image="Attack Button"}}}}
	end
	local function questRestrictionButton(label)
		--855x365 at this scale covers the same footprint as the normal 2x2 action-button block.
		return {tag="Button", attributes={id=prefix.."PersonalRestriction", width=855, height=365, position="0 203.5 -12", rotation="0 0 180", scale=buttonScale, color="#b5b5b5", interactable="false"}, children={{tag="Text", attributes={id=prefix.."PersonalRestrictionText", font="Fonts/MKCardText", fontSize=72, color="#777777", alignment="MiddleCenter", text=label}}}}
	end
	if pending~=nil then
		local spots={{50,180},{-50,180},{50,227},{-50,227}}
		for index, key in ipairs(pending.keys or {}) do
			if spots[index]~=nil then xml[#xml+1]=questButton("Choice_"..key, key, spots[index][1], spots[index][2], "#d8c79d", true) end
		end
		if #(pending.keys or {})<4 then
			local cancelSpot=spots[#(pending.keys or {})+1]
			if cancelSpot~=nil then xml[#xml+1]=questButton("ChoiceCancel", "Cancel", cancelSpot[1], cancelSpot[2], "#b5b5b5", true) end
		end
		card.UI.setXmlTable(xml)
		return
	end
	if combatPending~=nil then
		local spots={{50,180},{-50,180},{50,227},{-50,227}}
		local colors={Blue="#779bd1",Red="#cf7777",Green="#82b982",White="#eeeeee",Gold="#e4c869",Black="#666666",NoInventory="#b5b5b5",["2a"]="#d8c79d",["2b"]="#d8c79d"}
		for index, color in ipairs(combatPending.colors or {}) do
			if spots[index]~=nil then
				local label=color=="NoInventory" and "{en}No Inventory{ru}Нет места в Инвентаре{zh-tw}庫存已滿{zh-cn}库存已满{ko}인벤토리 공간 없음{es}Sin espacio en Inventario{fr}Inventaire plein{pt-br}Sem espaço no Inventário{de}Kein Inventarplatz" or (translateWord[color] or color)
				xml[#xml+1]=questButton("CombatColor_"..color,label,spots[index][1],spots[index][2],colors[color] or "#d8c79d",true)
			end
		end
		if combatPending.mode~="QuestCrystalGold" and combatPending.mode~="GuardDutyChoice" then xml[#xml+1]=questButton("CombatCancel","Cancel",0,274,"#b5b5b5",true) end
		card.UI.setXmlTable(xml)
		return
	end
	if QuestPrivate.apocalypseQuestPersonalBlockedByOther(card,interfacePlayer)==true then
		xml[#xml+1]=questRestrictionButton("One Personal\nquest at\na time")
		card.UI.setXmlTable(xml)
		return
	end
	if #directChoices>0 then
		local spots={{50,180},{-50,180},{50,227},{-50,227}}
		for index, choice in ipairs(directChoices) do
			local legal=QuestPrivate.apocalypseQuestDirectChoiceLegal(card,interfacePlayer,choice)
			if spots[index]~=nil then xml[#xml+1]=questButton("Direct_"..choice.key,choice.label or string.upper(choice.key),spots[index][1],spots[index][2],legal and "#d8c79d" or "#b5b5b5",legal) end
		end
		--Admiring Bard Step 2 uses three player-declared outcomes but must retain the Personal Quest
		--Abandon action as the fourth control. Once abandoned, directChoices disappears and Resume returns.
		local handler=apocalypseQuestHandler(card)
		local directState=handler~=nil and handler.directChoicesAllowAbandon==true and QuestPrivate.apocalypseQuestProgressState(card,interfacePlayer,false) or nil
		if directState~=nil and #directChoices==3 then
			local abandon=QuestPrivate.apocalypseQuestActionEnabled(card,interfacePlayer,"Abandon")
			xml[#xml+1]=questButton("Abandon","Abandon",spots[4][1],spots[4][2],abandon and "#d5b784" or "#b5b5b5",abandon)
		end
		card.UI.setXmlTable(xml)
		return
	end
	local state=QuestPrivate.apocalypseQuestButtonState(card,interfacePlayer)
	--The old text Fight button sat at y=133, which puts it on top of the Quest card where the card
	--itself can occlude attached UI. Put the standard Attack icon on a third row below the 2x2 controls.
	xml[#xml+1]=questAttackButton(state.fight)
	xml[#xml+1]=questButton("Progress", state.progressLabel or "Progress", 50, 180, state.progress and "#d8c79d" or "#b5b5b5", state.progress)
	xml[#xml+1]=questButton("Complete", "Complete", -50, 180, state.complete and "#a8c99a" or "#b5b5b5", state.complete)
	xml[#xml+1]=questButton("Abandon", state.abandonLabel, 50, 227, state.abandon and "#d5b784" or "#b5b5b5", state.abandon)
	xml[#xml+1]=questButton("Fail", state.failLabel or "Fail", -50, 227, state.fail and "#c99090" or "#b5b5b5", state.fail)
	card.UI.setXmlTable(xml)
end
function QuestPrivate.apocalypseQuestOfferCards(areaObjects)
	if areaObjects==nil and apocalypseQuestRefreshOfferCardsCache~=nil then return apocalypseQuestRefreshOfferCardsCache end
	local cards={}
	local known=gStates.apocalypseQuestCardGUIDs
	local first=QuestPrivate.apocalypseQuestOfferPosition(1)
	local last=QuestPrivate.apocalypseQuestOfferPosition(6)
	for _, obj in pairs(areaObjects or QuestPrivate.apocalypseQuestAreaObjects()) do
		if obj.type=="Card" and (known==nil or known[obj.guid]==true) then
			local pos=obj.getPosition()
			if pos[1]>first[1]-1.8 and pos[1]<last[1]+1.8 and math.abs(pos[3]-first[3])<2.6 then cards[#cards+1]=obj end
		end
	end
	table.sort(cards, function(a,b) return a.getPosition()[1]<b.getPosition()[1] end)
	return cards
end
function QuestPrivate.apocalypseQuestMoveCard(card, target, areaObjects, offerCards)
	if card==nil or target==nil then return {} end
	areaObjects=areaObjects or QuestPrivate.apocalypseQuestAreaObjects()
	offerCards=offerCards or QuestPrivate.apocalypseQuestOfferCards(areaObjects)
	local source=card.getPosition()
	local dx, dz=target[1]-source[1], target[3]-source[3]
	local carried={}
	local carriedGUIDs={}
	local movedGUIDs={card.guid}
	local known=gStates.apocalypseQuestCardGUIDs or {}
	--Explicit same-frame attachments may still be spawning and therefore absent from both getObjectFromGUID()
	--and the Quest scripting zone. Always include their GUID in the movement set. If the spawning helper
	--already gave one its future position, do not translate it a second time.
	local explicit=gStates.apocalypseQuestMoveAttachments~=nil and gStates.apocalypseQuestMoveAttachments[card.guid] or nil
	if explicit~=nil then
		for guid,record in pairs(explicit) do
			carriedGUIDs[guid]=true
			movedGUIDs[#movedGUIDs+1]=guid
			local obj=getObjectFromGUID(guid)
			if obj~=nil then
				local recordedTarget=type(record)=="table" and record.target or nil
				if recordedTarget~=nil then
					carried[#carried+1]={obj=obj,position={recordedTarget[1],recordedTarget[2],recordedTarget[3]}}
				else
					local pos=obj.getPosition()
					carried[#carried+1]={obj=obj,position={pos[1]+dx,pos[2],pos[3]+dz}}
				end
			end
		end
	end
	for _, obj in pairs(areaObjects) do
		--A committed Quest marker may still be physically over the card while its smooth move to the map is
		--in progress. Do not let offer re-ordering grab it and send it back to the Quest card.
		local objectGUID=obj.guid
		local movingQuestMarker=objectGUID~=nil and gStates.apocalypseQuestMarkerPlacements~=nil and gStates.apocalypseQuestMarkerPlacements[objectGUID]==true
		local explicitOwner=objectGUID~=nil and apocalypseQuestMoveAttachmentOwnerGUID(objectGUID) or nil
		if objectGUID~=nil and objectGUID~=card.guid and carriedGUIDs[objectGUID]~=true and known[objectGUID]~=true and movingQuestMarker~=true and explicitOwner==nil then
			local pos=obj.getPosition()
			local normalFootprint=math.abs(pos[1]-source[1])<1.7 and math.abs(pos[3]-source[3])<2.5 and pos[2]>source[2]-1.5 and pos[2]<source[2]+3.0
			local rowOwner=QuestPrivate.apocalypseQuestIndependentShieldRowOwnerGUID(obj,offerCards)
			if rowOwner==card.guid or (rowOwner==nil and normalFootprint) then
				carried[#carried+1]={obj=obj, position={pos[1]+dx, pos[2], pos[3]+dz}}
				movedGUIDs[#movedGUIDs+1]=obj.guid
			end
		end
	end
	card.lock()
	card.setRotationSmooth({0,180,0})
	card.setPositionSmooth({target[1], source[2], target[3]})
	for _, move in pairs(carried) do
		if move.obj~=nil then move.obj.setPositionSmooth(move.position) end
	end
	return movedGUIDs
end
function QuestPrivate.apocalypseQuestOfferMoveToLeft(card,onSettled)
	if card==nil then return false end
	if gStates.apocalypseQuestOfferMoving==true then
		gStates.apocalypseQuestOfferButtonRefreshPending=true
		return false
	end
	gStates.apocalypseQuestOfferMoving=true
	local cardGUID=card.guid
	local areaObjects=QuestPrivate.apocalypseQuestAreaObjects()
	local offerCards=QuestPrivate.apocalypseQuestOfferCards(areaObjects)
	local ordered={card}
	local movedGUIDs={}
	for _, offerCard in pairs(offerCards) do if offerCard.guid~=card.guid then ordered[#ordered+1]=offerCard end end
	local orderedGUIDs={}
	for i=#ordered, 1, -1 do
		orderedGUIDs[#orderedGUIDs+1]=ordered[i].guid
		for _,guid in ipairs(QuestPrivate.apocalypseQuestMoveCard(ordered[i], QuestPrivate.apocalypseQuestOfferPosition(i), areaObjects, offerCards)) do movedGUIDs[guid]=true end
	end
	--isSmoothMoving() is the offer lifecycle boundary. Quest cards are locked, so physics/resting state is
	--irrelevant; newly spawned explicit attachments only get a short grace period to become addressable.
	local finished=false
	local settleChecks=0
	local function finishMove()
		if finished==true then return end
		finished=true
		for _,guid in ipairs(orderedGUIDs) do
			if gStates.apocalypseQuestMoveAttachments~=nil then gStates.apocalypseQuestMoveAttachments[guid]=nil end
			local questCard=getObjectFromGUID(guid)
			if questCard~=nil then questCard.lock() end
		end
		gStates.apocalypseQuestOfferMoving=false
		local buttonRefresh=gStates.apocalypseQuestOfferButtonRefreshPending==true
		gStates.apocalypseQuestOfferButtonRefreshPending=nil
		local offerRefresh=gStates.apocalypseQuestOfferRefreshPending==true
		if offerRefresh==true then gStates.apocalypseQuestOfferRefreshPending=nil end
		if onSettled==nil or buttonRefresh==true then apocalypseQuestRefreshOfferButtons() end
		if onSettled~=nil then
			safeWaitFrames("Quests",function()
				local live=getObjectFromGUID(cardGUID)
				if live~=nil then onSettled(live) end
			end,1)
		end
		if offerRefresh==true then safeWaitFrames("Quests",function() apocalypseQuestOfferRefresh() end,1) end
	end
	safeWaitFrames("Quests",function()
		safeWaitCondition("Quests",finishMove,function()
			settleChecks=settleChecks+1
			for guid,_ in pairs(movedGUIDs) do
				local obj=getObjectFromGUID(guid)
				if obj==nil then
					if settleChecks<12 then return false end
				elseif obj.spawning==true or obj.isSmoothMoving()==true then return false end
			end
			return true
		end,5,finishMove)
	end,2)
	return true
end
function apocalypseQuestScoreMarkerPlayerIndex(guid)
	if guid==nil then return nil end
	for playerIndex,details in ipairs(turnOrder or {}) do
		if details.questScoreGUID==guid then return playerIndex end
	end
	return nil
end
function apocalypseQuestDisableScoring()
	if apocalypseQuestScoresRequired()==true or gStates.apocalypseQuestScoringChoiceLocked==true then return false end
	gStates.apocalypseQuestScoringDisabled=true
	local markers={}
	for _,details in ipairs(turnOrder or {}) do
		if details.questScoreGUID~=nil then markers[#markers+1]=details.questScoreGUID end
		details.questScoreGUID=nil
		details.questScore=0
	end
	gStates.apocalypseQuestScoreMarkers={}
	gStates.apocalypseQuestScores={}
	for _,guid in ipairs(markers) do
		local marker=getObjectFromGUID(guid)
		if marker~=nil then marker.destruct() end
	end
	return true
end
function apocalypseQuestRestoreScoreMarker(playerIndex, announce)
	if apocalypseQuestScoringActive()~=true then return nil end
	local details=turnOrder[playerIndex]
	if details==nil or details.mage==nil or details.mage==gStates.positionMageKnight[5] then return nil end
	local mage=details.mage
	local score=(gStates.apocalypseQuestScores~=nil and gStates.apocalypseQuestScores[mage]) or details.questScore or 0
	local target=QuestPrivate.apocalypseQuestScorePosition(score, details.seatPos)
	local guid=(gStates.apocalypseQuestScoreMarkers or {})[mage] or details.questScoreGUID
	local marker=guid~=nil and getObjectFromGUID(guid) or nil
	if marker==nil then
		--The dedicated score markers use the same Mage shield model at 125% scale. If physics or an
		--unexpected cleanup ever removes one, rebuild it from that player's Fame shield so the physical
		--Quest score cannot silently disappear for the rest of the game.
		local source=details.fameGUID~=nil and getObjectFromGUID(details.fameGUID) or nil
		if source==nil then return nil end
		marker=source.clone({position=target, rotation={0,180,0}})
		if marker==nil then return nil end
		marker.setName(mage)
		marker.setDescription("{en}Quest Score{ru}Очки задания{zh-tw}任務分數{zh-cn}任务分数{ko}퀘스트 점수{es}Puntuación de Misión{fr}Score de Quête{pt-br}Pontuação de Missão{de}Quest-Punkte")
		marker.setGMNotes("")
		local scale=source.getScale()
		marker.setScale({scale[1]*1.25, scale[2]*1.25, scale[3]*1.25})
		marker.setPosition(target)
		marker.setRotation({0,180,0})
		if gStates.apocalypseQuestScoreMarkers==nil then gStates.apocalypseQuestScoreMarkers={} end
		gStates.apocalypseQuestScoreMarkers[mage]=marker.guid
		details.questScoreGUID=marker.guid
		if announce==true then broadcastToAll(joinLang({"{en}Quest Score marker restored for {ru}Маркер очков задания восстановлен для {zh-tw}已為 {zh-cn}已为 {ko}퀘스트 점수 마커 복구: {es}Marcador de Puntuación de Misión restaurado para {fr}Marqueur de Score de Quête restauré pour {pt-br}Marcador de Pontuação de Missão restaurado para {de}Quest-Punktemarker wiederhergestellt für ",translateWord[mage] or tostring(mage),"{en}.{ru}.{zh-tw} 恢復任務分數標記。{zh-cn} 恢复任务分数标记。{ko}.{es}.{fr}.{pt-br}.{de}."}),{1,1,0.5}) end
		return marker
	end
	local pos=marker.getPosition()
	local dx=pos[1]-target[1]
	local dz=pos[3]-target[3]
	--Manual corrections update questScore on drop, so recentering a badly displaced marker here does
	--not overwrite a player's chosen score. This only catches physics knock-offs/falls between turns.
	if (dx*dx)+(dz*dz)>2.25 or pos[2]<0.8 or pos[2]>4.0 then
		marker.setPosition(target)
		marker.setRotation({0,180,0})
	end
	return marker
end
function apocalypseQuestRefreshScoreMarkers()
	if apocalypseQuestScoringActive()~=true then return end
	for playerIndex, details in ipairs(turnOrder or {}) do
		if details.mage~=nil and details.mage~=gStates.positionMageKnight[5] then apocalypseQuestRestoreScoreMarker(playerIndex,true) end
	end
end
function QuestPrivate.apocalypseQuestScoreGain(playerIndex, amount)
	if apocalypseQuestScoringActive()~=true then return true end
	local details=turnOrder[playerIndex]
	if details==nil then return false end
	local mage=details.mage
	if gStates.apocalypseQuestScores==nil then gStates.apocalypseQuestScores={} end
	local score=math.max(0, (gStates.apocalypseQuestScores[mage] or details.questScore or 0)+(amount or 0))
	gStates.apocalypseQuestScores[mage]=score
	details.questScore=score
	local marker=apocalypseQuestRestoreScoreMarker(playerIndex,false)
	--Match the proven Fame shield movement: direct placement avoids collider impacts on the shared board.
	if marker~=nil then
		marker.setPosition(QuestPrivate.apocalypseQuestScorePosition(score, details.seatPos))
		marker.setRotation({0,180,0})
	end
	return true
end
function refreshPlayerQuestScoreFromMarker(playerIndex)
	if apocalypseQuestScoringActive()~=true then return false end
	local details=turnOrder[playerIndex]
	if details==nil or details.mage==gStates.positionMageKnight[5] then return false end
	local marker=getObjectFromGUID(details.questScoreGUID)
	if marker==nil then return false end
	local markerPos=marker.getPosition()
	local nearestScore=0
	local nearestDistance=nil
	--Quest scores use the Fame-board geometry with a small lane offset. Comparing against the
	--same placement helper keeps manual adjustment in sync even on alternate Fame boards.
	local maxScore=gStates.scoreIfLooped
	for score=0, maxScore do
		local scorePos=QuestPrivate.apocalypseQuestScorePosition(score, details.seatPos)
		local distance=((markerPos[1]-scorePos[1])^2)+((markerPos[3]-scorePos[3])^2)
		if nearestDistance==nil or distance<nearestDistance then nearestDistance=distance nearestScore=score end
	end
	gStates.apocalypseQuestScores[details.mage]=nearestScore
	details.questScore=nearestScore
	return true
end
local function apocalypseQuestRemoveShields(card)
	if card==nil then return end
	local source=card.getPosition()
	local shields={}
	local areaObjects=QuestPrivate.apocalypseQuestAreaObjects()
	local offerCards=QuestPrivate.apocalypseQuestOfferCards(areaObjects)
	for _, obj in pairs(areaObjects) do
		if obj.guid~=card.guid and obj.getName()=="Shield" then
			local pos=obj.getPosition()
			local normalFootprint=math.abs(pos[1]-source[1])<1.7 and math.abs(pos[3]-source[3])<2.5 and pos[2]>source[2]-0.25 and pos[2]<source[2]+3.0
			local rowOwner=QuestPrivate.apocalypseQuestIndependentShieldRowOwnerGUID(obj,offerCards)
			if rowOwner==card.guid or (rowOwner==nil and normalFootprint) then shields[#shields+1]=obj end
		end
	end
	for _, shield in ipairs(shields) do if getObjectFromGUID(shield.guid)~=nil then shield.destruct() end end
end
local function apocalypseQuestMarkReturned(card)
	if card~=nil and gStates.apocalypseQuestFirstReturnedGUID==nil then gStates.apocalypseQuestFirstReturnedGUID=card.guid end
end
local function apocalypseQuestShuffleIfCycleReached(deck)
	local firstReturned=gStates.apocalypseQuestFirstReturnedGUID
	if deck==nil or firstReturned==nil then return false end
	local topGUID=nil
	if deck.type=="Deck" then
		local objects=deck.getObjects()
		if objects[1]~=nil then topGUID=objects[1].guid end
	elseif deck.type=="Card" then
		topGUID=deck.guid
	end
	if topGUID~=firstReturned then return false end
	--The first returned Quest has come back around to the top: every card that was ahead of it
	--has now been seen. Shuffle the available Quest deck before drawing again, then start a new cycle.
	gStates.apocalypseQuestFirstReturnedGUID=nil
	if deck.type=="Deck" and deck.getQuantity()>1 then deck.shuffle() end
	return true
end
function QuestPrivate.apocalypseQuestReminderPosition(slot)
	slot=math.max(1, tonumber(slot) or 1)
	--The first five reminder slots line up directly above the neutral + player Quest Shield bags.
	--Additional reminders wrap into another row while staying in the same Quest component area.
	local column=(slot-1)%5
	local row=math.floor((slot-1)/5)
	return {59.25+(column*4.20), 1.14, 18.61+(row*5.10)}
end
function QuestPrivate.apocalypseQuestReminderSlot(cardGUID)
	if gStates.apocalypseQuestReminderCards==nil then gStates.apocalypseQuestReminderCards={} end
	local existing=gStates.apocalypseQuestReminderCards[cardGUID]
	if existing~=nil then return existing end
	local used={}
	for guid, slot in pairs(gStates.apocalypseQuestReminderCards) do
		if getObjectFromGUID(guid)==nil then gStates.apocalypseQuestReminderCards[guid]=nil
		else used[slot]=true end
	end
	local slot=1
	while used[slot]==true do slot=slot+1 end
	gStates.apocalypseQuestReminderCards[cardGUID]=slot
	return slot
end
function QuestPrivate.apocalypseQuestHasActiveReminderToken(card)
	if card==nil then return false end
	local quest=apocalypseQuestData[card.guid]
	if quest==nil or quest.keepToken~=true or quest.questTokens==nil then return false end
	for _, tokenGUID in ipairs(quest.questTokens) do
		local token=getObjectFromGUID(tokenGUID)
		if token~=nil and apocalypseQuestTokenFaceUp(token)==true then return true end
	end
	return false
end
function QuestPrivate.apocalypseQuestParkReminder(card)
	if card==nil then return false end
	local quest=apocalypseQuestData[card.guid]
	if quest==nil or quest.keepToken~=true then return false end
	apocalypseQuestReturnRevealBag(card)
	if gStates.apocalypseQuestProgress~=nil then gStates.apocalypseQuestProgress[card.guid]=nil end
	if gStates.apocalypseQuestPendingChoice~=nil then gStates.apocalypseQuestPendingChoice[card.guid]=nil end
	QuestPrivate.apocalypseQuestInterfaceRemove(card)
	apocalypseQuestRemoveShields(card)
	local slot=QuestPrivate.apocalypseQuestReminderSlot(card.guid)
	card.lock()
	card.setRotationSmooth({0,180,0})
	card.setPositionSmooth(QuestPrivate.apocalypseQuestReminderPosition(slot))
	broadcastToAll(joinLang({"{en}Quest reminder: \"{ru}Напоминание задания: \"{zh-tw}任務提醒：\"{zh-cn}任务提醒：\"{ko}퀘스트 알림: \"{es}Recordatorio de Misión: \"{fr}Rappel de Quête : \"{pt-br}Lembrete da Missão: \"{de}Quest-Erinnerung: \"",apocalypseQuestName(card),"{en}\" moved beside the Quest Shield bags until its Quest marker(s) are discarded.{ru}\" перемещено рядом с мешками Щитов задания до сброса его жетонов задания.{zh-tw}\" 已移到任務盾牌袋旁，直到其任務標記被棄掉。{zh-cn}\" 已移到任务盾牌袋旁，直到其任务标记被弃掉。{ko}\"을(를) 퀘스트 마커가 버려질 때까지 퀘스트 방패 주머니 옆으로 옮겼습니다.{es}\" se movió junto a las bolsas de Escudos de Misión hasta que se descarten sus marcadores de Misión.{fr}\" a été déplacée près des sacs de Boucliers de Quête jusqu’à ce que ses marqueurs de Quête soient défaussés.{pt-br}\" foi movida para junto das bolsas de Escudos da Missão até que seus marcadores sejam descartados.{de}\" wurde neben die Quest-Schild-Beutel verschoben, bis seine Questmarker abgeworfen wurden."}), {1,1,0.5})
	safeWaitFrames("Quests",function() apocalypseQuestRefreshReminderCards() end, 3)
	QuestPrivate.apocalypseQuestRefreshAfterMarkerChange()
	return true
end
function apocalypseQuestRefreshReminderCards()
	if gStates.apocalypseQuestReminderCards==nil then return false end
	if gStates.apocalypseQuestTokenGUIDs==nil or gStates.apocalypseQuestTokenInBag==nil then apocalypseQuestTokenBagSetup() end
	local ready={}
	for cardGUID, _ in pairs(gStates.apocalypseQuestReminderCards) do
		local card=getObjectFromGUID(cardGUID)
		local quest=apocalypseQuestData[cardGUID]
		--Enforce reminder-card presentation every time this list is checked. This also cleans up UI
		--that may have been restored by an older queued callback during the move to the reminder area.
		if card~=nil then card.lock() QuestPrivate.apocalypseQuestInterfaceRemove(card) end
		if card==nil then
			gStates.apocalypseQuestReminderCards[cardGUID]=nil
		elseif quest~=nil and quest.questTokens~=nil and #quest.questTokens>0 then
			local allReturned=true
			for _,tokenGUID in ipairs(quest.questTokens) do
				if gStates.apocalypseQuestTokenInBag[tokenGUID]~=true then allReturned=false break end
			end
			if allReturned==true then ready[#ready+1]=card end
		end
	end
	for _,card in ipairs(ready) do
		broadcastToAll(joinLang({"{en}Quest reminder: all markers from \"{ru}Напоминание задания: все жетоны из \"{zh-tw}任務提醒：\"{zh-cn}任务提醒：\"{ko}퀘스트 알림: \"{es}Recordatorio de Misión: todos los marcadores de \"{fr}Rappel de Quête : tous les marqueurs de \"{pt-br}Lembrete da Missão: todos os marcadores de \"{de}Quest-Erinnerung: Alle Marker von \"",apocalypseQuestName(card),"{en}\" were returned; the Quest card is returning to the Quest deck cycle.{ru}\" возвращены; карта задания возвращается в цикл колоды заданий.{zh-tw}\" 的所有標記都已歸還；任務牌返回任務牌庫循環。{zh-cn}\" 的所有标记都已归还；任务牌返回任务牌库循环。{ko}\"의 모든 마커가 반환되었습니다. 퀘스트 카드는 퀘스트 덱 순환으로 돌아갑니다.{es}\" fueron devueltos; la carta de Misión vuelve al ciclo del mazo de Misiones.{fr}\" ont été rendus ; la carte de Quête retourne dans le cycle du paquet de Quêtes.{pt-br}\" foram devolvidos; a carta de Missão está voltando ao ciclo do baralho de Missões.{de}\" wurden zurückgegeben; die Questkarte kehrt in den Queststapel-Zyklus zurück."}), {1,1,0.5})
		QuestPrivate.apocalypseQuestBottomDeck(card)
	end
	return #ready>0
end
function QuestPrivate.apocalypseQuestFinishCompletedCard(card)
	if card==nil then return false end
	if gStates.apocalypseQuestMoveAttachments~=nil then gStates.apocalypseQuestMoveAttachments[card.guid]=nil end
	local quest=apocalypseQuestData[card.guid]
	if quest~=nil and quest.keepToken==true then return QuestPrivate.apocalypseQuestParkReminder(card) end
	return QuestPrivate.apocalypseQuestBottomDeck(card)
end
local apocalypseQuestCardRuntimeStores={
	"apocalypseQuestReminderCards",
	"apocalypseQuestProgress",
	"apocalypseQuestPendingChoice",
	"apocalypseQuestCombatChoice",
	"apocalypseQuestCombatLaunches",
	"apocalypseQuestCombatEnemies",
	"apocalypseQuestCombatBranch",
	"apocalypseQuestCursedHero",
	"apocalypseQuestCursedHistory",
	"apocalypseQuestHerbalistRolls",
	"apocalypseQuestDirectBranch",
	"apocalypseQuestCombatStarted",
	"apocalypseQuestRewardCompletionPending",
	"apocalypseQuestMineDoomColor",
	"apocalypseQuestStepColor",
	"apocalypseQuestRichMerchantRoll",
	"apocalypseQuestRichMerchantHidden",
	"apocalypseQuestVeryPersonalSuccess",
	"apocalypseQuestRevealDone",
	"apocalypseQuestRevealPending"
}

local function apocalypseQuestClearCardRuntime(cardGUID)
	if cardGUID==nil then return end
	local herbalist=gStates.apocalypseQuestHerbalistRolls~=nil and gStates.apocalypseQuestHerbalistRolls[cardGUID] or nil
	if herbalist~=nil then
		local die=herbalist.dieGUID~=nil and getObjectFromGUID(herbalist.dieGUID) or nil
		if die~=nil then die.destruct() end
		if gStates.apocalypseQuestRollDice~=nil and herbalist.dieGUID~=nil then gStates.apocalypseQuestRollDice[herbalist.dieGUID]=nil end
	end
	for _,storeName in ipairs(apocalypseQuestCardRuntimeStores) do
		local store=gStates[storeName]
		if store~=nil then store[cardGUID]=nil end
	end
	if apocalypseQuestRevealWaitScheduled~=nil then apocalypseQuestRevealWaitScheduled[cardGUID]=nil end
end

function QuestPrivate.apocalypseQuestBottomDeck(card,onComplete)
	if card==nil then if onComplete~=nil then onComplete(false) end return false end
	local handler=apocalypseQuestHandler(card)
	if handler~=nil and handler.bottomDeckBeforeReveal~=nil then handler.bottomDeckBeforeReveal(card) end
	apocalypseQuestReturnRevealBag(card)
	if handler~=nil and handler.bottomDeckAfterReveal~=nil then handler.bottomDeckAfterReveal(card) end
	--Round refresh/failure can remove an unfinished Quest after it has already granted a reminder marker.
	--Such a card follows the same reminder rule as a normally completed Quest.
	if QuestPrivate.apocalypseQuestHasActiveReminderToken(card)==true and (gStates.apocalypseQuestReminderCards==nil or gStates.apocalypseQuestReminderCards[card.guid]==nil) then
		local parked=QuestPrivate.apocalypseQuestParkReminder(card)
		if onComplete~=nil then onComplete(parked==true) end
		return parked
	end
	apocalypseQuestClearCardRuntime(card.guid)
	QuestPrivate.apocalypseQuestInterfaceRemove(card)
	local deck=QuestPrivate.apocalypseQuestLiveDeck()
	if deck==nil or deck.guid==card.guid then if onComplete~=nil then onComplete(false) end return false end

	--Face-down Quest tokens are only markers, so they always return with the Quest. A keepToken Quest
	--leaves its token behind only after that token has been flipped face up into its lasting reward/site/effect.
	--Look up markers by GUID so cleanup still finds one after a player moved it away from the card.
	local questDetails=apocalypseQuestData[card.guid]
	if questDetails~=nil and questDetails.questTokens~=nil then
		if gStates.apocalypseQuestMarkerPlacements~=nil then
			for _, tokenGUID in ipairs(questDetails.questTokens) do gStates.apocalypseQuestMarkerPlacements[tokenGUID]=nil end
		end
		local tokenBag=getObjectFromGUID(GUID.bag.apocalypseQuestTokens)
		for _, tokenGUID in ipairs(questDetails.questTokens) do
			local token=getObjectFromGUID(tokenGUID)
			if token~=nil and (questDetails.keepToken~=true or apocalypseQuestTokenFaceUp(token)~=true) then
				if tokenBag~=nil then
					apocalypseQuestStageIntoContainer(token,tokenBag)
					broadcastToAll(joinLang({"{en}Quest cleanup: a Quest marker from \"{ru}Очистка задания: жетон задания из \"{zh-tw}任務清理：\"{zh-cn}任务清理：\"{ko}퀘스트 정리: \"{es}Limpieza de Misión: un marcador de Misión de \"{fr}Nettoyage de Quête : un marqueur de Quête de \"{pt-br}Limpeza da Missão: um marcador de Missão de \"{de}Quest-Bereinigung: Ein Questmarker von \"",apocalypseQuestName(card),"{en}\" returned to the Quest Token bag.{ru}\" возвращён в мешок жетонов задания.{zh-tw}\" 的任務標記已歸還任務標記袋。{zh-cn}\" 的任务标记已归还任务标记袋。{ko}\"의 퀘스트 마커가 퀘스트 토큰 주머니로 돌아갔습니다.{es}\" volvió a la bolsa de fichas de Misión.{fr}\" a été remis dans le sac de jetons de Quête.{pt-br}\" voltou para a bolsa de fichas de Missão.{de}\" wurde in den Questmarker-Beutel zurückgelegt."}), {1,1,0.5})
				else
					broadcastToAll(joinLang({"{en}Quest cleanup: a Quest marker from \"{ru}Очистка задания: жетон задания из \"{zh-tw}任務清理：\"{zh-cn}任务清理：\"{ko}퀘스트 정리: \"{es}Limpieza de Misión: un marcador de Misión de \"{fr}Nettoyage de Quête : un marqueur de Quête de \"{pt-br}Limpeza da Missão: um marcador de Missão de \"{de}Quest-Bereinigung: Ein Questmarker von \"",apocalypseQuestName(card),"{en}\" could not be returned because the Quest Token bag is missing.{ru}\" не удалось вернуть, потому что мешок жетонов задания отсутствует.{zh-tw}\" 的任務標記無法歸還，因為任務標記袋遺失。{zh-cn}\" 的任务标记无法归还，因为任务标记袋遗失。{ko}\"의 퀘스트 마커를 반환하지 못했습니다. 퀘스트 토큰 주머니가 없습니다.{es}\" no pudo devolverse porque falta la bolsa de fichas de Misión.{fr}\" n’a pas pu être rendu car le sac de jetons de Quête est manquant.{pt-br}\" não pôde ser devolvido porque a bolsa de fichas de Missão está ausente.{de}\" konnte nicht zurückgegeben werden, da der Questmarker-Beutel fehlt."}), {1,0.55,0.2})
				end
			end
		end
	end

	--Basic crystals used as Quest markers return to the supply when the Quest leaves play.
	--Rewards moved into a player's Inventory are outside the card footprint and are deliberately untouched.
	for _, obj in ipairs(apocalypseQuestObjectsOnCard(card)) do
		local color=apocalypseQuestManaTokenColor(obj)
		local bag=color~=nil and apocalypseQuestManaBag(color) or nil
		if bag~=nil then
			apocalypseQuestStageIntoContainer(obj,bag)
		elseif monsterPugs[obj.guid]~=nil then
			--Quest enemies always leave through their discard piles, defeated or not. Their original source
			--pile is not restored when the Quest leaves play.
			apocalypseQuestDetachPossessedForDiscard(obj)
			local destination=apocalypseQuestEnemyDiscardDestination(obj)
			if destination~=nil then apocalypseQuestStageIntoContainer(obj,destination) end
		elseif obj.type=="Card" then
			--BottomDeck owns tucked-card detachment for completion, failure and end-of-round expiry alike.
			--The attachment-clear gate below keeps the Quest card still until this fast return has finished.
			apocalypseQuestReturnTuckedCard(obj,apocalypseQuestName(card))
		end
	end

	--Player and neutral Quest shields come from infinite bags, so they can be safely deleted when
	--the Quest leaves the offer. Progress/Abandon do not call this function, so their shields remain.
	--Capture everything else still physically overlapping the Quest before deleting its Shields. During
	--round refresh, tucked cards and Quest markers have just been sent back to their own decks/bag; TTS
	--needs a few frames to finish those container moves. Moving the Quest card immediately could carry
	--those objects toward the Quest deck before their return completed (Spell Thief / Prove Yourself).
	local attachmentGUIDs={}
	for _,obj in ipairs(apocalypseQuestObjectsOnCard(card)) do
		if obj.getName()~="Shield" then attachmentGUIDs[#attachmentGUIDs+1]=obj.guid end
	end
	apocalypseQuestRemoveShields(card)

	local cardGUID=card.guid
	local function attachmentsClear()
		local liveCard=getObjectFromGUID(cardGUID)
		if liveCard==nil then return true end
		local source=liveCard.getPosition()
		for _,guid in ipairs(attachmentGUIDs) do
			local obj=getObjectFromGUID(guid)
			if obj~=nil then
				local pos=obj.getPosition()
				if math.abs(pos[1]-source[1])<1.7 and math.abs(pos[3]-source[3])<2.5 and pos[2]>source[2]-1.5 and pos[2]<source[2]+3.0 then return false end
			end
		end
		return true
	end
	local function finishBottomDeck()
		local liveCard=getObjectFromGUID(cardGUID)
		if liveCard==nil then return end
		local liveDeck=QuestPrivate.apocalypseQuestLiveDeck()
		if liveDeck==nil or liveDeck.guid==liveCard.guid then return end
		apocalypseQuestMarkReturned(liveCard)
		liveCard.unlock()
		local deckGUID=liveDeck.guid
		local pos=liveDeck.getPosition()
		--Teleport clear of Quest attachments first. When merging two frames later, stage the card BELOW
		--and beside the Quest deck so TTS deterministically inserts it at the bottom, not the top.
		liveCard.setRotation(liveDeck.getRotation())
		liveCard.setPosition({pos[1]+3.0,math.max(0.2,pos[2]-0.6),pos[3]})
		safeWaitFrames("Quests",function()
			local stagedCard=getObjectFromGUID(cardGUID)
			local stagedDeck=getObjectFromGUID(deckGUID) or QuestPrivate.apocalypseQuestLiveDeck()
			if stagedCard==nil or stagedDeck==nil or stagedDeck.guid==stagedCard.guid then
				if onComplete~=nil then onComplete(false) end
				return
			end
			--The caller may start the next return only after the physical drop has actually merged.
			putCardAtBottom(stagedDeck,stagedCard,function(merged)
				local liveDeck=merged~=nil and (merged.type=="Deck" or merged.type=="Card") and merged or QuestPrivate.apocalypseQuestLiveDeck()
				if liveDeck~=nil then GUID.deck.apocalypseQuest=liveDeck.guid end
				refreshOutOfTurnActions(nil,nil,true)
				QuestPrivate.apocalypseQuestRefreshAfterMarkerChange()
				if onComplete~=nil then onComplete(liveDeck~=nil) end
			end)
		end,2)
	end
	if attachmentsClear()==true then finishBottomDeck()
	else safeWaitCondition("Quests",finishBottomDeck,attachmentsClear,2.0,finishBottomDeck) end
	return true
end
function QuestPrivate.apocalypseQuestClaimAbandonedPersonal(card, playerIndex)
	local quest=card~=nil and apocalypseQuestData[card.guid] or nil
	if quest==nil or quest.questType~="Personal" then return true end
	if QuestPrivate.apocalypseQuestPersonalShieldOwner(card)~=nil then return true end
	local neutral=QuestPrivate.apocalypseQuestNeutralShield(card)
	if neutral==nil then return true end
	local position=neutral.getPosition()
	local rotation=neutral.getRotation()
	--Create the player's replacement before deleting the neutral Shield so a missing player Shield
	--bag cannot lose the Quest marker. If this action is about to reorder the offer, create the replacement
	--at the Quest's planned destination rather than flashing it over the old offer slot first.
	local surface=apocalypseQuestPlannedWorldPosition(card,position)
	local target=QuestPrivate.apocalypseQuestRaisedPiecePosition(surface)
	local shield=QuestPrivate.apocalypseQuestTakePlayerShield(playerIndex, surface)
	if shield==nil then return false end
	neutral.destruct()
	shield.unlock()
	shield.setRotationSmooth(rotation)
	shield.setPositionSmooth(target)
	apocalypseQuestRegisterMoveAttachment(card,shield,target)
	return true
end
local function apocalypseQuestWaitForStepResolution(card,playerIndex,action,option,playerColor,rewindReady)
if card==nil or option==nil or turnOrder[playerIndex]==nil then return false end
if card.isSmoothMoving()==true then
	local cardGUID=card.guid
	safeWaitCondition("Quests",function()
		local live=getObjectFromGUID(cardGUID)
		if live~=nil then QuestPrivate.apocalypseQuestResolveStepAction(live,playerIndex,action,option,playerColor,rewindReady) end
	end,function()
		local live=getObjectFromGUID(cardGUID)
		return live==nil or live.isSmoothMoving()==false
	end,5,function()
		local live=getObjectFromGUID(cardGUID)
		if live~=nil then QuestPrivate.apocalypseQuestResolveStepAction(live,playerIndex,action,option,playerColor,rewindReady) end
	end)
	return true
end
	return nil
end

local function apocalypseQuestValidateStepResolution(card,playerIndex,action,option,playerColor,quest)
local handler=apocalypseQuestHandler(card)
local handledColors,colors=false,nil
if handler~=nil and handler.progressColors~=nil then handledColors,colors=handler.progressColors(card,playerIndex,action,option) end
if handledColors==true then
	colors=colors or {}
	if #colors==0 then return false end
	if gStates.apocalypseQuestStepColor==nil then gStates.apocalypseQuestStepColor={} end
	if gStates.apocalypseQuestStepColor[card.guid]==nil and #colors>1 then
		if gStates.apocalypseQuestCombatChoice==nil then gStates.apocalypseQuestCombatChoice={} end
		gStates.apocalypseQuestCombatChoice[card.guid]={playerIndex=playerIndex,colors=colors,mode="ProgressColor",action=action,key=tostring(option.key)}
		QuestPrivate.apocalypseQuestInterfaceAdd(card,true)
		return true
	end
	if gStates.apocalypseQuestStepColor[card.guid]==nil then gStates.apocalypseQuestStepColor[card.guid]=colors[1] end
end
local minimumReputationModifier=option.minimumReputationModifier or quest.minimumReputationModifier
if minimumReputationModifier~=nil and action~="Fail" then
	refreshPlayerReputationFromShield(playerIndex)
	local effectiveReputation=math.max(-7, math.min(7, (turnOrder[playerIndex].reputation or 0)+(turnOrder[playerIndex].repGain or 0)))
	local repData=reputationTable[effectiveReputation]
	local repModifier=repData~=nil and tonumber(repData.repDisplay) or nil
	if repModifier==nil or repModifier<minimumReputationModifier then
		if playerColor~=nil then broadcastToColor(joinLang({"{en}This Quest step requires a Reputation Modifier of {ru}Этот шаг задания требует модификатор Репутации {zh-tw}此任務步驟需要聲望修正值至少為 {zh-cn}此任务步骤需要声望修正值至少为 {ko}이 퀘스트 단계에는 평판 수정치 {es}Este paso de Misión requiere un Modificador de Reputación de {fr}Cette étape de Quête exige un Modificateur de Réputation de {pt-br}Esta etapa da Missão exige um Modificador de Reputação de {de}Dieser Quest-Schritt erfordert einen Ansehensmodifikator von ",tostring(minimumReputationModifier),"{en} or higher.{ru} или выше.{zh-tw}。{zh-cn}。{ko} 이상이 필요합니다.{es} o superior.{fr} ou plus.{pt-br} ou superior.{de} oder höher."}), playerColor, warningColor) end
		return false
	end
end
if action=="Fail" and apocalypseQuestFailureReady(card,option,playerIndex)~=true then
	if playerColor~=nil then broadcastToColor("{en}Start this Quest combat before resolving Fail.{ru}Начните бой задания перед разрешением Провала.{zh-tw}在結算失敗前先開始此任務戰鬥。{zh-cn}在结算失败前先开始此任务战斗。{ko}실패를 처리하기 전에 이 퀘스트 전투를 시작하십시오.{es}Inicia este combate de Misión antes de resolver Fallar.{fr}Commencez ce combat de Quête avant de résoudre Échouer.{pt-br}Inicie este combate da Missão antes de resolver Falhar.{de}Beginne diesen Quest-Kampf, bevor du Scheitern abwickelst.",playerColor,warningColor) end
	return false
end
if action~="Fail" and apocalypseQuestStepSpecialLegal(card,playerIndex,option)~=true then
	if playerColor~=nil then broadcastToColor(joinLang({"{en}The combat requirement for Quest step {ru}Требование боя для шага задания {zh-tw}尚未偵測到任務步驟 {zh-cn}尚未检测到任务步骤 {ko}퀘스트 단계 {es}Aún no se ha detectado el requisito de combate del paso de Misión {fr}La condition de combat de l’étape de Quête {pt-br}O requisito de combate da etapa da Missão {de}Die Kampfanforderung für Quest-Schritt ",tostring(option.key),"{en} has not been detected yet.{ru} ещё не обнаружено.{zh-tw} 的戰鬥要求。{zh-cn} 的战斗要求。{ko}의 전투 요구 사항이 아직 감지되지 않았습니다.{es}.{fr} n’a pas encore été détectée.{pt-br} ainda não foi detectado.{de} wurde noch nicht erkannt."}),playerColor,warningColor) end
	return false
end
	return nil
end

local function apocalypseQuestFinishResolution(questRewindOwner,delay)
	if delay~=nil and delay>0 then safeWaitTime("Quests",function() rewindTransactionFinish(questRewindOwner) end,delay)
	else rewindTransactionFinish(questRewindOwner) end
end

local function apocalypseQuestResolveRichMerchantProgress(card,playerIndex,option,playerColor,state,finishQuestResolution)
--A Rich Merchant Step 1 must use the face of a real rolled mana die. The die can appear immediately
--over slot 1 because that destination is already known; the Quest card starts moving there at once.
--Black advances to Step 2; the other results leave Step 1 ready to Complete.
if QuestPrivate.apocalypseQuestPlaceStepMarker(card,playerIndex,option,playerColor)~=true then finishQuestResolution(0.5) return false end
if QuestPrivate.apocalypseQuestClaimAbandonedPersonal(card,playerIndex)~=true then
	if playerColor~=nil then broadcastToColor("{en}The Personal Quest Shield could not be claimed.{ru}Щит личного задания не удалось получить.{zh-tw}無法取得個人任務盾牌。{zh-cn}无法取得个人任务盾牌。{ko}개인 퀘스트 방패를 획득하지 못했습니다.{es}No se pudo reclamar el Escudo de Misión Personal.{fr}Le Bouclier de Quête Personnelle n’a pas pu être récupéré.{pt-br}O Escudo de Missão Pessoal não pôde ser recebido.{de}Der Schild der persönlichen Quest konnte nicht beansprucht werden.",playerColor,{1,0.55,0.2}) end
	finishQuestResolution(0.5)
	return false
end
apocalypseQuestBeginMoveAttachmentCapture(card,QuestPrivate.apocalypseQuestOfferPosition(1))
if QuestPrivate.apocalypseQuestPositionProgressShield(card,playerIndex,option)~=true then
	apocalypseQuestEndMoveAttachmentCapture(card)
	if playerColor~=nil then broadcastToColor("{en}Quest progress could not place the required Shield.{ru}При продвижении задания не удалось разместить требуемый Щит.{zh-tw}任務進度無法放置所需盾牌。{zh-cn}任务进度无法放置所需盾牌。{ko}퀘스트 진행 중 필요한 방패를 놓지 못했습니다.{es}El progreso de la Misión no pudo colocar el Escudo requerido.{fr}La progression de la Quête n’a pas pu placer le Bouclier requis.{pt-br}O progresso da Missão não conseguiu colocar o Escudo necessário.{de}Beim Quest-Fortschritt konnte der erforderliche Schild nicht platziert werden.",playerColor,{1,0.55,0.2}) end
	finishQuestResolution(0.5)
	return false
end
apocalypseQuestEndMoveAttachmentCapture(card)
QuestPrivate.apocalypseQuestClearRewardCompletionGate(card,playerIndex)
local started=apocalypseQuestRollVisibleManaDie(card,playerIndex,"A Rich Merchant",function(rolled,liveCard)
	if liveCard==nil then finishQuestResolution(0.5) return end
	if rolled==nil then
		--Stay on Step 1 so Proceed can simply be tried again if the physical die was unreadable.
		QuestPrivate.apocalypseQuestInterfaceAdd(liveCard,true)
		finishQuestResolution(0.5)
		return
	end
	apocalypseQuestResolveRichMerchantRoll(liveCard,playerIndex,rolled)
	if rolled=="Black" then QuestPrivate.apocalypseQuestAdvanceProgress(liveCard,state,option) end
	apocalypseQuestRefreshOfferButtons()
	finishQuestResolution(0.5)
end,QuestPrivate.apocalypseQuestOfferPosition(1))
if started~=true then
	if gStates.apocalypseQuestMoveAttachments~=nil then gStates.apocalypseQuestMoveAttachments[card.guid]=nil end
	QuestPrivate.apocalypseQuestPositionProgressShield(card,playerIndex,option)
	QuestPrivate.apocalypseQuestInterfaceAdd(card,true)
	finishQuestResolution(0.5)
	return false
end
QuestPrivate.apocalypseQuestCommitStepMarker(card,option)
--Suppress the normal settled refresh while the visible die is still resolving; its callback refreshes
--the Quest once the result is known. The physical offer still starts moving immediately.
QuestPrivate.apocalypseQuestOfferMoveToLeft(card,function() end)
return true
end

apocalypseQuestRegisterHandler("8cff07").progressAction=function(card,playerIndex,option,playerColor,state,questState,finishQuestResolution)
	if tostring(option.key)~="1" then return false end
	return true,apocalypseQuestResolveRichMerchantProgress(card,playerIndex,option,playerColor,state,finishQuestResolution)
end

local function apocalypseQuestResolveProgressAction(card,playerIndex,option,playerColor,state,questState,finishQuestResolution)
local handler=apocalypseQuestHandler(card)
if apocalypseQuestUsesGenericStepMarker(card,option)==true and QuestPrivate.apocalypseQuestPlaceStepMarker(card,playerIndex,option,playerColor)~=true then finishQuestResolution(0.5) return false end
--Plan the offer move before any replacement/progress Shield is created so every new Shield
--uses slot 1 immediately and is explicitly owned by this Quest during the reorder.
apocalypseQuestBeginMoveAttachmentCapture(card,QuestPrivate.apocalypseQuestOfferPosition(1))
if QuestPrivate.apocalypseQuestClaimAbandonedPersonal(card, playerIndex)~=true then
	apocalypseQuestEndMoveAttachmentCapture(card)
	if playerColor~=nil then broadcastToColor("{en}The Personal Quest Shield could not be claimed.{ru}Щит личного задания не удалось получить.{zh-tw}無法取得個人任務盾牌。{zh-cn}无法取得个人任务盾牌。{ko}개인 퀘스트 방패를 획득하지 못했습니다.{es}No se pudo reclamar el Escudo de Misión Personal.{fr}Le Bouclier de Quête Personnelle n’a pas pu être récupéré.{pt-br}O Escudo de Missão Pessoal não pôde ser recebido.{de}Der Schild der persönlichen Quest konnte nicht beansprucht werden.", playerColor, {1,0.55,0.2}) end
	finishQuestResolution(0.5)
	return false
end
if QuestPrivate.apocalypseQuestPositionProgressShield(card, playerIndex, option)~=true then
	apocalypseQuestEndMoveAttachmentCapture(card)
	if playerColor~=nil then broadcastToColor("{en}Quest progress could not place the required Shield.{ru}При продвижении задания не удалось разместить требуемый Щит.{zh-tw}任務進度無法放置所需盾牌。{zh-cn}任务进度无法放置所需盾牌。{ko}퀘스트 진행 중 필요한 방패를 놓지 못했습니다.{es}El progreso de la Misión no pudo colocar el Escudo requerido.{fr}La progression de la Quête n’a pas pu placer le Bouclier requis.{pt-br}O progresso da Missão não conseguiu colocar o Escudo necessário.{de}Beim Quest-Fortschritt konnte der erforderliche Schild nicht platziert werden.", playerColor, {1,0.55,0.2}) end
	finishQuestResolution(0.5)
	return false
end
QuestPrivate.apocalypseQuestAwardStepPoint(card, playerIndex, option, state, questState)
QuestPrivate.apocalypseQuestClearRewardCompletionGate(card,playerIndex)
local key=tostring(option.key)
local fistfulSetup=handler~=nil and handler.fistfulSetupKey==key
local launchedNext=handler~=nil and handler.preserveCombatLaunchOnProgressKeys~=nil and handler.preserveCombatLaunchOnProgressKeys[key]==true
--Resolve the step immediately, as before. Anything leaving the Quest card moves away now. New objects
--created on the card are explicitly captured for the imminent offer move, so they travel with the card
--without waiting for the scripting zone to notice them.
QuestPrivate.apocalypseQuestResolveSpecialEffect(card, playerIndex, option, false)
apocalypseQuestEndMoveAttachmentCapture(card)
if gStates.apocalypseQuestStepColor~=nil then gStates.apocalypseQuestStepColor[card.guid]=nil end
QuestPrivate.apocalypseQuestAdvanceProgress(card, state, option)
if launchedNext==true and QuestPrivate.apocalypseQuestCombatStartedThisTurn(card,state.step)==true then
	if gStates.apocalypseQuestCombatLaunches==nil then gStates.apocalypseQuestCombatLaunches={} end
	gStates.apocalypseQuestCombatLaunches[card.guid]=QuestPrivate.apocalypseQuestCombatLaunchKey(card,state)
end
--Commit before the offer snapshot. A Quest marker may still be travelling to the map and must not be
--mistaken for an attachment that should follow the card left.
if apocalypseQuestUsesGenericStepMarker(card,option)==true then QuestPrivate.apocalypseQuestCommitStepMarker(card,option) end
if fistfulSetup==true then
	--Let the card reach slot 1 before drawing from the same gray bag twice. The short gap also
	--ensures the first takeObject has fully left the container before the second extraction.
	QuestPrivate.apocalypseQuestOfferMoveToLeft(card,function(liveCard)
		apocalypseQuestPlaceFistfulEnemies(liveCard,function()
			apocalypseQuestRefreshOfferButtons()
			finishQuestResolution(0.5)
		end)
	end)
else
	QuestPrivate.apocalypseQuestOfferMoveToLeft(card)
	finishQuestResolution(1.0)
end
broadcastToAll(joinLang({translateWord[turnOrder[playerIndex].mage] or tostring(turnOrder[playerIndex].mage),"{en} progressed a Quest ({ru} продвинул задание ({zh-tw} 推進了一個任務（{zh-cn} 推进了一个任务（{ko}이(가) 퀘스트를 진행했습니다 ({es} progresó una Misión ({fr} a fait progresser une Quête ({pt-br} progrediu uma Missão ({de} hat eine Quest vorangebracht (",tostring(option.key),")."}), positionToColor(playerIndex))
return true
end

local function apocalypseQuestPrepareGuardDutyCompletion(card,playerIndex,option,playerColor,finishQuestResolution)
	if tostring(option.key)~="2" then return false,true,nil end
	local distance=QuestPrivate.apocalypseQuestGuardDutyDistance(playerIndex)
	if distance==nil then
		if playerColor~=nil then broadcastToColor("{en}Guard Duty could not measure a revealed-space path back to the merchant marker.{ru}Guard Duty не смог определить путь по открытым клеткам обратно к жетону торговца.{zh-tw}Guard Duty 無法計算沿已揭示空間返回商人標記的路徑。{zh-cn}Guard Duty 无法计算沿已揭示空间返回商人标记的路径。{ko}Guard Duty에서 공개된 칸을 따라 상인 마커로 돌아가는 경로를 계산하지 못했습니다.{es}Guard Duty no pudo calcular una ruta por espacios revelados hasta el marcador del mercader.{fr}Guard Duty n’a pas pu calculer un trajet par les cases révélées jusqu’au marqueur du marchand.{pt-br}Guard Duty não conseguiu calcular uma rota por espaços revelados até o marcador do mercador.{de}Guard Duty konnte keinen Weg über aufgedeckte Felder zurück zum Händlermarker bestimmen.",playerColor,{1,0.55,0.2}) end
		finishQuestResolution(0.5)
		return true,false,nil
	end
	return true,true,{guardDutyDistance=distance}
end

local function apocalypseQuestCrystalRewardFailed(card,playerIndex,finishQuestResolution)
	if card~=nil then
		QuestPrivate.apocalypseQuestClearRewardCompletionGate(card,playerIndex)
		QuestPrivate.apocalypseQuestInterfaceAdd(card,true)
	end
	finishQuestResolution(0.5)
end

local function apocalypseQuestCompleteNobleWarrior(card,playerIndex,option,playerColor,context,finishQuestResolution)
	if tostring(option.key)~="3a" then return false end
	QuestPrivate.apocalypseQuestSetRewardCompletionGate(card,playerIndex,"Complete")
	local started=QuestPrivate.apocalypseQuestNobleWarriorRollReward(card,playerIndex,function(success,questCard,results)
		if questCard==nil then finishQuestResolution(0.5) return end
		if success==true then
			QuestPrivate.apocalypseQuestResolveCrystalRollResults(questCard,playerIndex,results,"Noble Warrior","3a",finishQuestResolution)
		else apocalypseQuestCrystalRewardFailed(questCard,playerIndex,finishQuestResolution) end
	end)
	if started~=true then apocalypseQuestCrystalRewardFailed(card,playerIndex,finishQuestResolution) end
	return true,started
end

local function apocalypseQuestCompleteExecution(card,playerIndex,option,playerColor,context,finishQuestResolution)
	if tostring(option.key)~="1a" then return false end
	QuestPrivate.apocalypseQuestSetRewardCompletionGate(card,playerIndex,"Complete")
	local started=apocalypseQuestRollCrystalRewardDice(card,playerIndex,1,"The Execution",function(success,questCard,results)
		if questCard==nil then finishQuestResolution(0.5) return end
		if success==true then
			QuestPrivate.apocalypseQuestResolveCrystalRollResults(questCard,playerIndex,results,"The Execution","1a",finishQuestResolution)
		else
			if gStates.apocalypseQuestDirectBranch~=nil then gStates.apocalypseQuestDirectBranch[questCard.guid]=nil end
			apocalypseQuestCrystalRewardFailed(questCard,playerIndex,finishQuestResolution)
		end
	end)
	if started~=true then
		if gStates.apocalypseQuestDirectBranch~=nil then gStates.apocalypseQuestDirectBranch[card.guid]=nil end
		apocalypseQuestCrystalRewardFailed(card,playerIndex,finishQuestResolution)
	end
	return true,started
end

local function apocalypseQuestCompleteGuardDuty(card,playerIndex,option,playerColor,context,finishQuestResolution)
	if tostring(option.key)~="2" then return false end
	local guardDutyDistance=context.guardDutyDistance
	QuestPrivate.apocalypseQuestSetRewardCompletionGate(card,playerIndex,"Complete")
	if guardDutyDistance>=7 then
		local pending={playerIndex=playerIndex,mode="GuardDutyChoice",remaining=2,distance=guardDutyDistance,startCounts={},granted={}}
		pending.colors=QuestPrivate.apocalypseQuestCrystalChoiceColors(playerIndex,pending)
		if gStates.apocalypseQuestCombatChoice==nil then gStates.apocalypseQuestCombatChoice={} end
		gStates.apocalypseQuestCombatChoice[card.guid]=pending
		QuestPrivate.apocalypseQuestInterfaceAdd(card,true)
		broadcastToAll(joinLang({"{en}Guard Duty distance is {ru}Расстояние Guard Duty: {zh-tw}Guard Duty 距離為 {zh-cn}Guard Duty 距离为 {ko}Guard Duty 거리: {es}La distancia de Guard Duty es {fr}La distance de Guard Duty est de {pt-br}A distância de Guard Duty é {de}Die Entfernung bei Guard Duty beträgt ",tostring(guardDutyDistance),"{en}: choose two basic mana crystals.{ru}: выберите два базовых кристалла маны.{zh-tw}：選擇兩顆基本魔力水晶。{zh-cn}：选择两颗基本魔力水晶。{ko}: 기본 마나 크리스털 2개를 선택하십시오.{es}: elige dos cristales básicos de maná.{fr} : choisissez deux cristaux de mana de base.{pt-br}: escolha dois cristais básicos de mana.{de}: Wähle zwei Basismana-Kristalle."}),positionToColor(playerIndex))
		return true,true
	end
	local crystalCount=guardDutyDistance<=3 and 1 or 2
	local started=apocalypseQuestRollCrystalRewardDice(card,playerIndex,crystalCount,"Guard Duty",function(success,questCard,results)
		if questCard==nil then finishQuestResolution(0.5) return end
		if success==true then
			QuestPrivate.apocalypseQuestResolveCrystalRollResults(questCard,playerIndex,results,"Guard Duty","2",finishQuestResolution)
		else apocalypseQuestCrystalRewardFailed(questCard,playerIndex,finishQuestResolution) end
	end)
	if started~=true then apocalypseQuestCrystalRewardFailed(card,playerIndex,finishQuestResolution) end
	return true,started
end

local function apocalypseQuestCompleteRandomObjects(card,playerIndex,option,playerColor,context,finishQuestResolution)
	if tostring(option.key)~="4" then return false end
	QuestPrivate.apocalypseQuestSetRewardCompletionGate(card,playerIndex,"Complete")
	local started=apocalypseQuestRollCrystalRewardDice(card,playerIndex,2,"Random Objects",function(success,questCard,results)
		if questCard==nil then finishQuestResolution(0.5) return end
		if success==true then
			QuestPrivate.apocalypseQuestResolveCrystalRollResults(questCard,playerIndex,results,"Random Objects","4",finishQuestResolution)
		else apocalypseQuestCrystalRewardFailed(questCard,playerIndex,finishQuestResolution) end
	end)
	if started~=true then apocalypseQuestCrystalRewardFailed(card,playerIndex,finishQuestResolution) end
	return true,started
end

local function apocalypseQuestCompleteHerbalist(card,playerIndex,option,playerColor,context,finishQuestResolution)
	if tostring(option.key)~="3" then return false end
	--The Herbalist completion stays in the offer while its visible mana die is rolling. This keeps
	--the Quest token/crystal available until the physical result has been read and transferred.
	QuestPrivate.apocalypseQuestSetRewardCompletionGate(card,playerIndex,"Complete")
	local started=apocalypseQuestGiveHerbalistReward(card,playerIndex,function(success,questCard)
		if questCard==nil then finishQuestResolution(0.5) return end
		if success==true then
			QuestPrivate.apocalypseQuestClearRewardCompletionGate(questCard,playerIndex)
			broadcastToAll(joinLang({translateWord[turnOrder[playerIndex].mage] or tostring(turnOrder[playerIndex].mage),"{en} completed a Quest ({ru} завершил задание ({zh-tw} 完成了一個任務（{zh-cn} 完成了一个任务（{ko}이(가) 퀘스트를 완료했습니다 ({es} completó una Misión ({fr} a terminé une Quête ({pt-br} concluiu uma Missão ({de} hat eine Quest abgeschlossen (",tostring(option.key),")."}), positionToColor(playerIndex))
			QuestPrivate.apocalypseQuestFinishCompletedCard(questCard)
		else
			QuestPrivate.apocalypseQuestClearRewardCompletionGate(questCard,playerIndex)
			QuestPrivate.apocalypseQuestInterfaceAdd(questCard,true)
		end
		finishQuestResolution(0.5)
	end)
	if started~=true then
		QuestPrivate.apocalypseQuestClearRewardCompletionGate(card,playerIndex)
		QuestPrivate.apocalypseQuestInterfaceAdd(card,true)
		finishQuestResolution(0.5)
	end
	return true,started
end

apocalypseQuestRegisterHandler("bbd087").completeAction=apocalypseQuestCompleteNobleWarrior
apocalypseQuestRegisterHandler("8939c0").completeAction=apocalypseQuestCompleteExecution
apocalypseQuestRegisterHandler("08ffcf").prepareCompleteAction=apocalypseQuestPrepareGuardDutyCompletion
apocalypseQuestRegisterHandler("08ffcf").completeAction=apocalypseQuestCompleteGuardDuty
apocalypseQuestRegisterHandler("58a826").completeAction=apocalypseQuestCompleteHerbalist
apocalypseQuestRegisterHandler("11d244").completeAction=apocalypseQuestCompleteRandomObjects

local function apocalypseQuestResolveCompleteAction(card,playerIndex,option,playerColor,state,questState,quest,finishQuestResolution)
	local handler=apocalypseQuestHandler(card)
	local completionContext={}
	if handler~=nil and handler.prepareCompleteAction~=nil then
		local handled,proceed,context=handler.prepareCompleteAction(card,playerIndex,option,playerColor,finishQuestResolution)
		if handled==true then
			if proceed~=true then return false end
			completionContext=context or {}
		end
	end
if apocalypseQuestUsesGenericStepMarker(card,option)==true and QuestPrivate.apocalypseQuestPlaceStepMarker(card,playerIndex,option,playerColor)~=true then finishQuestResolution(0.5) return false end
if QuestPrivate.apocalypseQuestClaimAbandonedPersonal(card, playerIndex)~=true then
	if playerColor~=nil then broadcastToColor("{en}The Personal Quest Shield could not be claimed.{ru}Щит личного задания не удалось получить.{zh-tw}無法取得個人任務盾牌。{zh-cn}无法取得个人任务盾牌。{ko}개인 퀘스트 방패를 획득하지 못했습니다.{es}No se pudo reclamar el Escudo de Misión Personal.{fr}Le Bouclier de Quête Personnelle n’a pas pu être récupéré.{pt-br}O Escudo de Missão Pessoal não pôde ser recebido.{de}Der Schild der persönlichen Quest konnte nicht beansprucht werden.", playerColor, {1,0.55,0.2}) end
	finishQuestResolution(0.5)
	return false
end
QuestPrivate.apocalypseQuestAwardStepPoint(card, playerIndex, option, state, questState)
QuestPrivate.apocalypseQuestClearRewardCompletionGate(card,playerIndex)
if apocalypseQuestUsesGenericStepMarker(card,option)==true then QuestPrivate.apocalypseQuestCommitStepMarker(card,option) end
if quest.allPlayersComplete==true then
	state.completed=true
	QuestPrivate.apocalypseQuestRemovePlayerShield(card, playerIndex)
	if QuestPrivate.apocalypseQuestAllPlayersCompleted(card)==true then
		QuestPrivate.apocalypseQuestResolveSpecialEffect(card, playerIndex, option, true)
		broadcastToAll(joinLang({translateWord[turnOrder[playerIndex].mage] or tostring(turnOrder[playerIndex].mage),"{en} completed the final required part of \"{ru} завершил последнюю требуемую часть \"{zh-tw} 完成了 \"{zh-cn} 完成了 \"{ko}이(가) \"{es} completó la última parte requerida de \"{fr} a terminé la dernière partie requise de \"{pt-br} concluiu a última parte necessária de \"{de} hat den letzten erforderlichen Teil von \"",quest.name,"{en}\".{ru}\".{zh-tw}\" 的最後必要部分。{zh-cn}\" 的最后必要部分。{ko}\"의 마지막 필수 부분을 완료했습니다.{es}\".{fr}\".{pt-br}\".{de}\" abgeschlossen."}), positionToColor(playerIndex))
		QuestPrivate.apocalypseQuestFinishCompletedCard(card)
	else
		apocalypseQuestBeginMoveAttachmentCapture(card,QuestPrivate.apocalypseQuestOfferPosition(1))
		QuestPrivate.apocalypseQuestResolveSpecialEffect(card, playerIndex, option, false)
		apocalypseQuestEndMoveAttachmentCapture(card)
		QuestPrivate.apocalypseQuestOfferMoveToLeft(card)
		broadcastToAll(joinLang({translateWord[turnOrder[playerIndex].mage] or tostring(turnOrder[playerIndex].mage),"{en} completed their part of \"{ru} завершил свою часть \"{zh-tw} 完成了自己在 \"{zh-cn} 完成了自己在 \"{ko}이(가) \"{es} completó su parte de \"{fr} a terminé sa partie de \"{pt-br} concluiu sua parte de \"{de} hat seinen Teil von \"",quest.name,"{en}\".{ru}\".{zh-tw}\" 中的部分。{zh-cn}\" 中的部分。{ko}\"에서 자신의 부분을 완료했습니다.{es}\".{fr}\".{pt-br}\".{de}\" abgeschlossen."}), positionToColor(playerIndex))
	end
else
	if handler~=nil and handler.completeAction~=nil then
		local handled,result=handler.completeAction(card,playerIndex,option,playerColor,completionContext,finishQuestResolution)
		if handled==true then return result end
	end
	QuestPrivate.apocalypseQuestResolveSpecialEffect(card, playerIndex, option, true)
	broadcastToAll(joinLang({translateWord[turnOrder[playerIndex].mage] or tostring(turnOrder[playerIndex].mage),"{en} completed a Quest ({ru} завершил задание ({zh-tw} 完成了一個任務（{zh-cn} 完成了一个任务（{ko}이(가) 퀘스트를 완료했습니다 ({es} completó una Misión ({fr} a terminé une Quête ({pt-br} concluiu uma Missão ({de} hat eine Quest abgeschlossen (",tostring(option.key),")."}), positionToColor(playerIndex))
	QuestPrivate.apocalypseQuestFinishCompletedCard(card)
end
finishQuestResolution(1.0)
return true
end

local function apocalypseQuestResolveFailAction(card,playerIndex,option,playerColor,quest,finishQuestResolution)
if QuestPrivate.apocalypseQuestClaimAbandonedPersonal(card, playerIndex)~=true then
	if playerColor~=nil then broadcastToColor("{en}The Personal Quest Shield could not be claimed.{ru}Щит личного задания не удалось получить.{zh-tw}無法取得個人任務盾牌。{zh-cn}无法取得个人任务盾牌。{ko}개인 퀘스트 방패를 획득하지 못했습니다.{es}No se pudo reclamar el Escudo de Misión Personal.{fr}Le Bouclier de Quête Personnelle n’a pas pu être récupéré.{pt-br}O Escudo de Missão Pessoal não pôde ser recebido.{de}Der Schild der persönlichen Quest konnte nicht beansprucht werden.", playerColor, {1,0.55,0.2}) end
	finishQuestResolution(0.5)
	return false
end
QuestPrivate.apocalypseQuestClearRewardCompletionGate(card,playerIndex)
QuestPrivate.apocalypseQuestResolveFailureEffect(card,playerIndex,option)
apocalypseQuestLoseReputation(playerIndex, quest.name, "fail")
broadcastToAll(joinLang({translateWord[turnOrder[playerIndex].mage] or tostring(turnOrder[playerIndex].mage),"{en} failed \"{ru} провалил \"{zh-tw} 任務失敗：\"{zh-cn} 任务失败：\"{ko}이(가) \"{es} falló \"{fr} a échoué à \"{pt-br} falhou em \"{de} ist bei \"",quest.name,"{en}\".{ru}\".{zh-tw}\"。{zh-cn}\"。{ko}\"에 실패했습니다.{es}\".{fr}\".{pt-br}\".{de}\" gescheitert."}), positionToColor(playerIndex))
QuestPrivate.apocalypseQuestBottomDeck(card)
finishQuestResolution(1.0)
return true
end

function QuestPrivate.apocalypseQuestResolveStepAction(card, playerIndex, action, option, playerColor, rewindReady)
	local waiting=apocalypseQuestWaitForStepResolution(card,playerIndex,action,option,playerColor,rewindReady)
	if waiting~=nil then return waiting end

	local quest=apocalypseQuestData[card.guid]
	if quest==nil then return false end
	local state,questState=QuestPrivate.apocalypseQuestProgressState(card,playerIndex,true)
	if state==nil or state.completed==true then return false end

	local validation=apocalypseQuestValidateStepResolution(card,playerIndex,action,option,playerColor,quest)
	if validation~=nil then return validation end

	local questRewindOwner="Quest resolve "..tostring(card.guid).." "..tostring(playerIndex)
	if rewindReady~=true then
		if rewindTransactionOwnerActive(questRewindOwner)==true then return true end
		rewindTransactionStart(function() QuestPrivate.apocalypseQuestResolveStepAction(card,playerIndex,action,option,playerColor,true) end,questRewindOwner)
		return true
	end
	local function finishQuestResolution(delay)
		apocalypseQuestFinishResolution(questRewindOwner,delay)
	end

	local handler=apocalypseQuestHandler(card)
	if action=="Progress" then
		if handler~=nil and handler.progressAction~=nil then
			local handled,result=handler.progressAction(card,playerIndex,option,playerColor,state,questState,finishQuestResolution)
			if handled==true then return result end
		end
		return apocalypseQuestResolveProgressAction(card,playerIndex,option,playerColor,state,questState,finishQuestResolution)
	elseif action=="Complete" then
		return apocalypseQuestResolveCompleteAction(card,playerIndex,option,playerColor,state,questState,quest,finishQuestResolution)
	elseif action=="Fail" then
		return apocalypseQuestResolveFailAction(card,playerIndex,option,playerColor,quest,finishQuestResolution)
	end
	finishQuestResolution(0.5)
	return false
end
local apocalypseQuestCardActionRestWait={}
local function apocalypseQuestRequeueCombatChoice(card,pendingCombat)
	if gStates.apocalypseQuestCombatChoice==nil then gStates.apocalypseQuestCombatChoice={} end
	pendingCombat.colors=QuestPrivate.apocalypseQuestCrystalChoiceColors(pendingCombat.playerIndex,pendingCombat)
	gStates.apocalypseQuestCombatChoice[card.guid]=pendingCombat
	QuestPrivate.apocalypseQuestInterfaceAdd(card,true)
end

local function apocalypseQuestTrackedCrystalChoice(card,playerIndex,color,pendingCombat,source,remainingKey,finish)
	if color=="NoInventory" then
		local available=QuestPrivate.apocalypseQuestCrystalChoiceColors(playerIndex,pendingCombat)
		if #available==1 and available[1]=="NoInventory" then finish(card,playerIndex,pendingCombat)
		else apocalypseQuestRequeueCombatChoice(card,pendingCombat) end
		return
	end
	pendingCombat.granted=pendingCombat.granted or {}
	pendingCombat.startCounts=pendingCombat.startCounts or {}
	if pendingCombat.startCounts[color]==nil then pendingCombat.startCounts[color]=mineCrystalCount(playerIndex,color) end
	local effective=math.max(mineCrystalCount(playerIndex,color),pendingCombat.startCounts[color]+(pendingCombat.granted[color] or 0))
	if effective<3 and apocalypseQuestGiveCrystal(playerIndex,color,nil,source)==true then
		pendingCombat.granted[color]=(pendingCombat.granted[color] or 0)+1
		pendingCombat[remainingKey]=(pendingCombat[remainingKey] or 1)-1
	end
	if (pendingCombat[remainingKey] or 0)<=0 then finish(card,playerIndex,pendingCombat)
	else apocalypseQuestRequeueCombatChoice(card,pendingCombat) end
end

local apocalypseQuestCombatChoiceModes={
	GuardDutyChoice={
		cancelLocked=true,
		refreshAfter=false,
		resolve=function(card,playerIndex,color,pendingCombat)
			apocalypseQuestTrackedCrystalChoice(card,playerIndex,color,pendingCombat,"Guard Duty","remaining",function(questCard,index,pending)
				QuestPrivate.apocalypseQuestFinishGuardDutyChoice(questCard,index,pending.distance)
			end)
		end
	},
	QuestCrystalGold={
		cancelLocked=true,
		refreshAfter=false,
		resolve=function(card,playerIndex,color,pendingCombat)
			apocalypseQuestTrackedCrystalChoice(card,playerIndex,color,pendingCombat,pendingCombat.source or "Quest","goldRemaining",function(questCard,index,pending)
				apocalypseQuestFinishCrystalRollReward(questCard,index,pending,nil)
			end)
		end
	},
	ProgressColor={
		resolve=function(card,playerIndex,color,pendingCombat,player)
			if gStates.apocalypseQuestStepColor==nil then gStates.apocalypseQuestStepColor={} end
			gStates.apocalypseQuestStepColor[card.guid]=color
			local selected=QuestPrivate.apocalypseQuestChoiceOption(card,pendingCombat.key)
			if selected~=nil then QuestPrivate.apocalypseQuestResolveStepAction(card,playerIndex,pendingCombat.action or "Progress",selected,player.color) end
		end
	}
}

local function apocalypseQuestHandleCombatChoiceAction(player,card,playerIndex,action)
	local pendingCombat=gStates.apocalypseQuestCombatChoice~=nil and gStates.apocalypseQuestCombatChoice[card.guid] or nil
	if action=="CombatCancel" then
		local mode=pendingCombat~=nil and apocalypseQuestCombatChoiceModes[pendingCombat.mode] or nil
		if mode~=nil and mode.cancelLocked==true then return end
		if gStates.apocalypseQuestCombatChoice~=nil then gStates.apocalypseQuestCombatChoice[card.guid]=nil end
		QuestPrivate.apocalypseQuestInterfaceAdd(card,true)
		return
	end
	if action:sub(1,12)~="CombatColor_" then return end
	local color=action:sub(13)
	if pendingCombat==nil or pendingCombat.playerIndex~=playerIndex then
		if gStates.apocalypseQuestCombatChoice~=nil then gStates.apocalypseQuestCombatChoice[card.guid]=nil end
		QuestPrivate.apocalypseQuestInterfaceAdd(card,true)
		return
	end
	local allowed=false
	for _,possible in ipairs(pendingCombat.colors or {}) do if possible==color then allowed=true break end end
	gStates.apocalypseQuestCombatChoice[card.guid]=nil
	if allowed==true then
		local mode=apocalypseQuestCombatChoiceModes[pendingCombat.mode]
		if mode~=nil and mode.resolve~=nil then
			mode.resolve(card,playerIndex,color,pendingCombat,player)
			if mode.refreshAfter==false then return end
		else QuestPrivate.apocalypseQuestLaunchCombat(card,playerIndex,player.color,color) end
	end
	if getObjectFromGUID(card.guid)~=nil then QuestPrivate.apocalypseQuestInterfaceAdd(card,true) end
end

local function apocalypseQuestHandleDirectAction(player,card,playerIndex,action)
	if action:sub(1,7)~="Direct_" then return end
	local key=action:sub(8)
	local selected=nil
	for _,choice in ipairs(QuestPrivate.apocalypseQuestDirectChoices(card,playerIndex)) do if choice.key==key then selected=choice break end end
	if selected==nil or QuestPrivate.apocalypseQuestDirectChoiceLegal(card,playerIndex,selected)~=true then QuestPrivate.apocalypseQuestInterfaceAdd(card,true) return end
	local handler=apocalypseQuestHandler(card)
	if handler~=nil and handler.directAction~=nil and handler.directAction(player,card,playerIndex,selected,key)==true then return end
	local option=QuestPrivate.apocalypseQuestChoiceOption(card,key)
	if selected.action=="Combat" then
		if handler==nil or handler.storeDirectCombatBranch~=false then
			if gStates.apocalypseQuestDirectBranch==nil then gStates.apocalypseQuestDirectBranch={} end
			gStates.apocalypseQuestDirectBranch[card.guid]=key
		end
		local chosenColor=nil
		if handler~=nil and handler.combatBranchChoice==true then chosenColor=key end
		QuestPrivate.apocalypseQuestLaunchCombat(card,playerIndex,player.color,chosenColor)
		if getObjectFromGUID(card.guid)~=nil then QuestPrivate.apocalypseQuestInterfaceAdd(card,true) end
	else
		if handler~=nil and handler.storeDirectBranch==true then
			if gStates.apocalypseQuestDirectBranch==nil then gStates.apocalypseQuestDirectBranch={} end
			gStates.apocalypseQuestDirectBranch[card.guid]=key
		end
		QuestPrivate.apocalypseQuestResolveStepAction(card,playerIndex,selected.action,option,player.color)
	end
end

local function apocalypseQuestHandleCombatLaunchAction(player,card,playerIndex,action)
	if action=="Fight" then
		QuestPrivate.apocalypseQuestLaunchCombat(card,playerIndex,player.color,nil)
		if getObjectFromGUID(card.guid)~=nil and (gStates.apocalypseQuestCombatChoice==nil or gStates.apocalypseQuestCombatChoice[card.guid]==nil) then QuestPrivate.apocalypseQuestInterfaceAdd(card,true) end
		return true
	end
	local handler=apocalypseQuestHandler(card)
	if handler~=nil and handler.progressCombatLaunch~=nil then return handler.progressCombatLaunch(player,card,playerIndex,action)==true end
	return false
end

local function apocalypseQuestHandlePendingChoiceAction(player,card,playerIndex,action)
if action=="ChoiceCancel" then
	if gStates.apocalypseQuestPendingChoice~=nil then gStates.apocalypseQuestPendingChoice[card.guid]=nil end
	QuestPrivate.apocalypseQuestInterfaceAdd(card, true)
	return
end
if action:sub(1,7)=="Choice_" then
	local pending=gStates.apocalypseQuestPendingChoice~=nil and gStates.apocalypseQuestPendingChoice[card.guid] or nil
	if pending==nil or pending.playerIndex~=playerIndex then
		if gStates.apocalypseQuestPendingChoice~=nil then gStates.apocalypseQuestPendingChoice[card.guid]=nil end
		QuestPrivate.apocalypseQuestInterfaceAdd(card, true)
		return
	end
	local key=action:sub(8)
	local selected=nil
	for _, option in ipairs(QuestPrivate.apocalypseQuestCurrentOptions(card, playerIndex, pending.action)) do if option.key==key then selected=option break end end
	gStates.apocalypseQuestPendingChoice[card.guid]=nil
	if selected==nil then QuestPrivate.apocalypseQuestInterfaceAdd(card, true) return end
	QuestPrivate.apocalypseQuestResolveStepAction(card, playerIndex, pending.action, selected, player.color)
	if getObjectFromGUID(card.guid)~=nil then QuestPrivate.apocalypseQuestInterfaceAdd(card, true) end
	return
end
end

local function apocalypseQuestHandlePersonalQuestAction(player,card,playerIndex,action,quest,details)
if action=="Abandon" then
	local handler=apocalypseQuestHandler(card)
	if handler~=nil and handler.personalAction~=nil and handler.personalAction(player,card,playerIndex,action)==true then return end
	local ownerIndex, ownerShield=QuestPrivate.apocalypseQuestPersonalShieldOwner(card)
	local neutralShield=QuestPrivate.apocalypseQuestNeutralShield(card)
	if quest.questType=="Personal" and ownerIndex==nil and neutralShield~=nil then
		if QuestPrivate.apocalypseQuestPlayerMayAct(card, playerIndex)~=true then
			broadcastToColor("{en}You cannot resume this Personal Quest while you have another Personal Quest.{ru}Нельзя возобновить это личное задание, пока у вас есть другое личное задание.{zh-tw}當你有另一個個人任務時，不能恢復此個人任務。{zh-cn}当你有另一个个人任务时，不能恢复此个人任务。{ko}다른 개인 퀘스트를 보유한 동안에는 이 개인 퀘스트를 재개할 수 없습니다.{es}No puedes reanudar esta Misión Personal mientras tengas otra Misión Personal.{fr}Vous ne pouvez pas reprendre cette Quête Personnelle tant que vous en avez une autre.{pt-br}Você não pode retomar esta Missão Pessoal enquanto tiver outra Missão Pessoal.{de}Du kannst diese persönliche Quest nicht fortsetzen, solange du eine andere persönliche Quest hast.", player.color, warningColor)
			apocalypseQuestUpdateProgressButtons(card)
			return
		end
		if QuestPrivate.apocalypseQuestClaimAbandonedPersonal(card, playerIndex)~=true then
			broadcastToColor("{en}The Personal Quest Shield could not be resumed.{ru}Щит личного задания не удалось восстановить.{zh-tw}無法恢復個人任務盾牌。{zh-cn}无法恢复个人任务盾牌。{ko}개인 퀘스트 방패를 재개하지 못했습니다.{es}No se pudo reanudar el Escudo de Misión Personal.{fr}Le Bouclier de Quête Personnelle n’a pas pu être repris.{pt-br}O Escudo de Missão Pessoal não pôde ser retomado.{de}Der Schild der persönlichen Quest konnte nicht wieder aufgenommen werden.", player.color, {1,0.55,0.2})
			return
		end
		apocalypseQuestUpdateProgressButtons(card)
		broadcastToAll(joinLang({translateWord[details.mage] or tostring(details.mage),"{en} resumed \"{ru} возобновил \"{zh-tw} 恢復了 \"{zh-cn} 恢复了 \"{ko}이(가) \"{es} reanudó \"{fr} a repris \"{pt-br} retomou \"{de} setzte \"",tostring(quest.name),"{en}\".{ru}\".{zh-tw}\"。{zh-cn}\"。{ko}\"을(를) 재개했습니다.{es}\".{fr}\".{pt-br}\".{de}\" fort."}), positionToColor(playerIndex))
		return
	end
	if quest.questType~="Personal" or ownerIndex~=playerIndex or ownerShield==nil then
		broadcastToColor("{en}You can only abandon a Personal Quest marked with your own Shield.{ru}Вы можете отказаться только от личного задания, отмеченного вашим собственным Щитом.{zh-tw}你只能放棄以自己盾牌標記的個人任務。{zh-cn}你只能放弃以自己盾牌标记的个人任务。{ko}자신의 방패로 표시된 개인 퀘스트만 포기할 수 있습니다.{es}Solo puedes abandonar una Misión Personal marcada con tu propio Escudo.{fr}Vous ne pouvez abandonner qu’une Quête Personnelle marquée de votre propre Bouclier.{pt-br}Você só pode abandonar uma Missão Pessoal marcada com seu próprio Escudo.{de}Du kannst nur eine persönliche Quest aufgeben, die mit deinem eigenen Schild markiert ist.", player.color, warningColor)
		apocalypseQuestUpdateProgressButtons(card)
		return
	end
	if QuestPrivate.apocalypseQuestShieldSupplyBag("Neutral")==nil then
		broadcastToColor("{en}The neutral Quest Shield bag could not be found.{ru}Мешок нейтральных Щитов задания не найден.{zh-tw}找不到中立任務盾牌袋。{zh-cn}找不到中立任务盾牌袋。{ko}중립 퀘스트 방패 주머니를 찾지 못했습니다.{es}No se encontró la bolsa de Escudos de Misión neutrales.{fr}Le sac de Boucliers de Quête neutres est introuvable.{pt-br}A bolsa de Escudos de Missão neutros não foi encontrada.{de}Der Beutel mit neutralen Quest-Schilden wurde nicht gefunden.", player.color, {1,0.55,0.2})
		return
	end
	local shieldPos=ownerShield.getPosition()
	local shieldRot=ownerShield.getRotation()
	apocalypseQuestBeginMoveAttachmentCapture(card,QuestPrivate.apocalypseQuestOfferPosition(1))
	local surface=apocalypseQuestPlannedWorldPosition(card,{shieldPos[1],shieldPos[2]+0.08,shieldPos[3]})
	local target=QuestPrivate.apocalypseQuestRaisedPiecePosition(surface)
	local neutralShield=QuestPrivate.apocalypseQuestTakeNeutralShield(surface)
	if neutralShield==nil then
		apocalypseQuestEndMoveAttachmentCapture(card)
		broadcastToColor("{en}A neutral Quest Shield could not be placed.{ru}Нейтральный Щит задания не удалось разместить.{zh-tw}無法放置中立任務盾牌。{zh-cn}无法放置中立任务盾牌。{ko}중립 퀘스트 방패를 놓지 못했습니다.{es}No se pudo colocar un Escudo de Misión neutral.{fr}Un Bouclier de Quête neutre n’a pas pu être placé.{pt-br}Um Escudo de Missão neutro não pôde ser colocado.{de}Ein neutraler Quest-Schild konnte nicht platziert werden.", player.color, {1,0.55,0.2})
		return
	end
	neutralShield.setRotationSmooth(shieldRot)
	apocalypseQuestRegisterMoveAttachment(card,neutralShield,target)
	apocalypseQuestEndMoveAttachmentCapture(card)
	local ownerMage=details.mage
	for _, shield in ipairs(apocalypseQuestObjectsOnCard(card)) do
		if shield.getName()=="Shield" and shield.getDescription()==ownerMage and getObjectFromGUID(shield.guid)~=nil then shield.destruct() end
	end
	apocalypseQuestLoseReputation(playerIndex, quest.name, "abandon")
	QuestPrivate.apocalypseQuestOfferMoveToLeft(card)
	broadcastToAll(joinLang({translateWord[details.mage] or tostring(details.mage),"{en} abandoned a Quest.{ru} отказался от задания.{zh-tw} 放棄了一個任務。{zh-cn} 放弃了一个任务。{ko}이(가) 퀘스트를 포기했습니다.{es} abandonó una Misión.{fr} a abandonné une Quête.{pt-br} abandonou uma Missão.{de} hat eine Quest aufgegeben."}), positionToColor(playerIndex))
	return
end
end

local function apocalypseQuestHandleStandardAction(player,card,playerIndex,action)
if action~="Progress" and action~="Complete" and action~="Fail" then return end
local options=QuestPrivate.apocalypseQuestCurrentOptions(card, playerIndex, action)
if #options==0 then
	local state=QuestPrivate.apocalypseQuestProgressState(card, playerIndex, false)
	local step=state~=nil and state.step or 1
	broadcastToColor(joinLang({action,"{en} is not available for step {ru} недоступно для шага {zh-tw} 不適用於此任務的步驟 {zh-cn} 不适用于此任务的步骤 {ko}은(는) 이 퀘스트의 {es} no está disponible para el paso {fr} n’est pas disponible pour l’étape {pt-br} não está disponível para a etapa {de} ist für Schritt ",tostring(step),"{en} of this Quest.{ru} этого задания.{zh-tw}。{zh-cn}。{ko}단계에서 사용할 수 없습니다.{es} de esta Misión.{fr} de cette Quête.{pt-br} desta Missão.{de} dieser Quest nicht verfügbar."}), player.color, warningColor)
	apocalypseQuestUpdateProgressButtons(card)
	return
end
if QuestPrivate.apocalypseQuestOptionsNeedChoice(card, action, options)==true then
	QuestPrivate.apocalypseQuestShowChoice(card, playerIndex, action, options)
	return
end
QuestPrivate.apocalypseQuestResolveStepAction(card, playerIndex, action, options[1], player.color)
end

function apocalypseQuestCardAction(player, mouseButton, id)
	if mouseButton=="-3" or player==nil or id==nil then return end
	local guid=id:sub(16, 21)
	local action=id:sub(22)
	local card=getObjectFromGUID(guid)
	--Quest actions serialize with the whole offer movement, not just this card's own animation. A card already
	--at its destination may report isSmoothMoving()==false while neighbouring Quest cards are still crossing.
	--Never wait for resting: locked Quest cards can remain resting=false because pieces are touching them.
	if card~=nil and (card.isSmoothMoving()==true or gStates.apocalypseQuestOfferMoving==true or gStates.apocalypseQuestOfferRefilling==true) then
		if apocalypseQuestCardActionRestWait[guid]~=true then
			apocalypseQuestCardActionRestWait[guid]=true
			local queuedPlayer,queuedButton,queuedID=player,mouseButton,id
			local function retry()
				apocalypseQuestCardActionRestWait[guid]=nil
				apocalypseQuestCardAction(queuedPlayer,queuedButton,queuedID)
			end
			safeWaitCondition("Quests",retry,function()
				local live=getObjectFromGUID(guid)
				return live==nil or (gStates.apocalypseQuestOfferMoving~=true and gStates.apocalypseQuestOfferRefilling~=true and live.isSmoothMoving()==false)
			end,5,retry)
		end
		return
	end
	local playerIndex=gStates.turnNumber
	local anyHumanConfirm=false
	local handler=apocalypseQuestHandler(card)
	if handler~=nil and handler.actionPlayer~=nil then playerIndex,anyHumanConfirm=handler.actionPlayer(card,action,playerIndex) end
	local details=turnOrder[playerIndex]
	if card==nil or details==nil then return end
	if anyHumanConfirm==true then
		if QuestPrivate.apocalypseQuestAnyHumanMayConfirm(player.color)~=true then return end
	elseif legalPlayerCheck(player.color, details.seatPos, "NoDummyException")~=true then return end
	local offered=false
	for _, offerCard in pairs(QuestPrivate.apocalypseQuestOfferCards()) do if offerCard.guid==guid then offered=true break end end
	if offered~=true then QuestPrivate.apocalypseQuestInterfaceRemove(card) return end
	local quest=apocalypseQuestData[card.guid]
	if quest==nil then return end
	if action=="CombatCancel" or action:sub(1,12)=="CombatColor_" then
		apocalypseQuestHandleCombatChoiceAction(player,card,playerIndex,action)
		return
	end
	if action:sub(1,7)=="Direct_" then
		apocalypseQuestHandleDirectAction(player,card,playerIndex,action)
		return
	end
	if action=="Fight" then
		apocalypseQuestHandleCombatLaunchAction(player,card,playerIndex,action)
		return
	end
	if action=="Progress" and apocalypseQuestHandleCombatLaunchAction(player,card,playerIndex,action)==true then return end
	if action=="ChoiceCancel" or action:sub(1,7)=="Choice_" then
		apocalypseQuestHandlePendingChoiceAction(player,card,playerIndex,action)
		return
	end
	if action=="Abandon" then
		apocalypseQuestHandlePersonalQuestAction(player,card,playerIndex,action,quest,details)
		return
	end
	apocalypseQuestHandleStandardAction(player,card,playerIndex,action)
end
--Quest Deck GUIDs can change when TTS collapses/rebuilds a Deck while completed Quests are returned.
--Recover the live pile by its fixed table position and known Quest contents, then remember the new GUID.
function QuestPrivate.apocalypseQuestLiveDeck()
	local deck=getObjectFromGUID(GUID.deck.apocalypseQuest)
	if deck~=nil and (deck.type=="Deck" or deck.type=="Card") then return deck end
	local known=gStates.apocalypseQuestCardGUIDs or {}
	local deckX,deckZ=46.84,8.06
	for _,obj in pairs(QuestPrivate.apocalypseQuestAreaObjects()) do
		if obj.type=="Deck" then
			local pos=obj.getPosition()
			if math.abs(pos[1]-deckX)<2.0 and math.abs(pos[3]-deckZ)<2.0 then
				local ok,contents=pcall(function() return obj.getObjects() end)
				if ok==true then
					for _,data in pairs(contents or {}) do
						if known[data.guid]==true then GUID.deck.apocalypseQuest=obj.guid return obj end
					end
				end
			end
		elseif obj.type=="Card" and known[obj.guid]==true then
			local pos=obj.getPosition()
			if math.abs(pos[1]-deckX)<2.0 and math.abs(pos[3]-deckZ)<2.0 then GUID.deck.apocalypseQuest=obj.guid return obj end
		end
	end
	return nil
end

function apocalypseQuestOfferRefresh(attempt)
	if apocalypseQuestsUsed()~=true or gStates.firstStarted~=true or turnOrder[gStates.turnNumber]==nil then
		return false
	end
	apocalypseQuestClearMarkerHighlights()
	if turnOrder[gStates.turnNumber].mage==gStates.positionMageKnight[5] or coopAssaultVirtualPlayer(gStates.turnNumber)==true then
		return false
	end
	if gStates.apocalypseQuestOfferRefilling==true or gStates.apocalypseQuestOfferMoving==true then
		gStates.apocalypseQuestOfferRefreshPending=true
		return false
	end
	if gStates.apocalypseQuestPendingChoice~=nil then
		for questGUID, pending in pairs(gStates.apocalypseQuestPendingChoice) do
			if pending.playerIndex~=gStates.turnNumber then
				gStates.apocalypseQuestPendingChoice[questGUID]=nil
				local staleCard=getObjectFromGUID(questGUID)
				if staleCard~=nil then QuestPrivate.apocalypseQuestInterfaceRemove(staleCard) end
			end
		end
	end
	local areaObjects=QuestPrivate.apocalypseQuestAreaObjects()
	local cards=QuestPrivate.apocalypseQuestOfferCards(areaObjects)
	local currentQuestTurnSerial=gStates.apocalypseQuestTurnSerial or 0
	if #cards>=QuestPrivate.apocalypseQuestOfferTarget() or gStates.apocalypseQuestOfferDrawSerial==currentQuestTurnSerial then
		--The offer can legitimately remain short. Once this human turn has drawn its one replacement,
		--later UI/location refreshes may rebuild the buttons but must not take another Quest.
		for _, card in pairs(cards) do
			local ok, err=pcall(QuestPrivate.apocalypseQuestInterfaceAdd, card)
			if ok~=true then print("QUEST START-OF-TURN REFRESH ERROR: "..tostring(apocalypseQuestName(card))..": "..tostring(err)) end
		end
		return false
	end

	local deck=QuestPrivate.apocalypseQuestLiveDeck()
	if deck==nil then
		attempt=attempt or 1
		if attempt<12 then
			local refreshTurn=gStates.turnNumber
			safeWaitFrames("Quests",function() if gStates.turnNumber==refreshTurn then apocalypseQuestOfferRefresh(attempt+1) end end,3)
		else print("QUEST REFILL ERROR: Quest deck could not be reacquired at start of turn.") end
		return false
	end

	--Serialize the refill. Existing Quest Object UIs are deliberately left untouched until every card
	--has been shifted and the replacement card has existed for several frames. This prevents TTS from
	--changing Object UI on the same objects while setPositionSmooth/takeObject are rebuilding them.
	--The whole refill is one rewind transaction: never snapshot the offer with cards shifted but no
	--replacement callback remaining to finish the rebuild.
	if rewindTransactionOwnerActive("Quest offer refill")==true then
		gStates.apocalypseQuestOfferRefreshPending=true
		return false
	end
	rewindTransactionStart(function()
	gStates.apocalypseQuestOfferRefilling=true
	gStates.apocalypseQuestOfferMoving=true
	gStates.apocalypseQuestOfferRefreshPending=nil
	gStates.apocalypseQuestOfferButtonRefreshPending=nil
	local refillFinished=false
	local refillWaiting=false
	local refillTimedOut=false
	local expectedCount=#cards+1
	local refillMovedGUIDs={}
	local shiftedCardGUIDs={}
	local settleChecks=0
	local function offerSettled()
		settleChecks=settleChecks+1
		local liveCards=QuestPrivate.apocalypseQuestOfferCards()
		if #liveCards<expectedCount then return false end
		for guid,_ in pairs(refillMovedGUIDs) do
			local obj=getObjectFromGUID(guid)
			if obj==nil then
				if settleChecks<12 then return false end
			elseif obj.spawning==true or obj.isSmoothMoving()==true then return false end
		end
		return true
	end
	local function finishQuestOfferRefill()
		if refillFinished==true then return end
		--Quest cards are locked; isSmoothMoving(), not resting, is the lifecycle boundary for both cards
		--and every attachment carried by the refill.
		if offerSettled()~=true and refillTimedOut~=true then
			if refillWaiting~=true then
				refillWaiting=true
				safeWaitCondition("Quests",function() refillWaiting=false finishQuestOfferRefill() end,offerSettled,15,function()
					refillWaiting=false
					refillTimedOut=true
					gStates.apocalypseQuestOfferRefreshPending=true
					finishQuestOfferRefill()
				end)
			end
			return
		end
		refillFinished=true
		for _,guid in ipairs(shiftedCardGUIDs) do
			if gStates.apocalypseQuestMoveAttachments~=nil then gStates.apocalypseQuestMoveAttachments[guid]=nil end
		end
		local deferredRefresh=gStates.apocalypseQuestOfferRefreshPending==true
		gStates.apocalypseQuestOfferRefilling=false
		gStates.apocalypseQuestOfferMoving=false
		gStates.apocalypseQuestOfferRefreshPending=nil
		gStates.apocalypseQuestOfferButtonRefreshPending=nil
		for _, questCard in pairs(QuestPrivate.apocalypseQuestOfferCards()) do
			questCard.lock()
			local ok, err=pcall(QuestPrivate.apocalypseQuestInterfaceAdd, questCard)
			if ok~=true then print("QUEST REFILL FINAL REFRESH ERROR: "..tostring(apocalypseQuestName(questCard))..": "..tostring(err)) end
		end
		refreshOutOfTurnActions(nil,nil,true)
		rewindTransactionFinish("Quest offer refill")
		--A deferred start-of-turn request may re-enter this helper, but the draw serial prevents a second draw.
		if deferredRefresh==true then safeWaitFrames("Quests",function() apocalypseQuestOfferRefresh() end,1) end
	end

	local shuffled=apocalypseQuestShuffleIfCycleReached(deck)
	for i=#cards, 1, -1 do
		shiftedCardGUIDs[#shiftedCardGUIDs+1]=cards[i].guid
		for _,guid in ipairs(QuestPrivate.apocalypseQuestMoveCard(cards[i], QuestPrivate.apocalypseQuestOfferPosition(i+1), areaObjects, cards)) do refillMovedGUIDs[guid]=true end
	end
	local pos=QuestPrivate.apocalypseQuestOfferPosition(1)
	--A player may manually cut/re-stack the Quest deck while testing. TTS can briefly expose the Deck
	--object before its internal card collection has finished rebuilding; takeObject in that window throws
	--the engine-side "Index was out of range" error. Re-fetch the live deck, wait for that container to settle,
	--then track the replacement itself only with isSmoothMoving().
	local function drawQuestReplacement(attempt)
		attempt=attempt or 1
		local liveDeck=QuestPrivate.apocalypseQuestLiveDeck()
		if liveDeck==nil then
			if attempt<12 then safeWaitFrames("Quests",function() drawQuestReplacement(attempt+1) end, 3)
			else print("QUEST REFILL ERROR: Quest deck could not be found after manual re-stack.") finishQuestOfferRefill() end
			return
		end
		if liveDeck.type=="Card" then
			local cardGUID=liveDeck.guid
			gStates.apocalypseQuestOfferDrawSerial=currentQuestTurnSerial
			liveDeck.lock()
			liveDeck.setRotationSmooth({0,180,0})
			liveDeck.setPositionSmooth(pos)
			refillMovedGUIDs[cardGUID]=true
			safeWaitFrames("Quests",function() finishQuestOfferRefill() end,2)
			return
		end
		if liveDeck.resting==false or liveDeck.spawning==true then
			if attempt<12 then safeWaitFrames("Quests",function() drawQuestReplacement(attempt+1) end, 3)
			else print("QUEST REFILL ERROR: Quest deck did not settle after manual re-stack.") finishQuestOfferRefill() end
			return
		end
		local okObjects,objects=pcall(function() return liveDeck.getObjects() end)
		local topGUID=okObjects==true and objects~=nil and objects[1]~=nil and objects[1].guid or nil
		if topGUID==nil then
			if attempt<12 then safeWaitFrames("Quests",function() drawQuestReplacement(attempt+1) end, 3)
			else print("QUEST REFILL ERROR: Quest deck had no readable top card.") finishQuestOfferRefill() end
			return
		end
		local okTake,takenOrErr=pcall(function()
			return liveDeck.takeObject({guid=topGUID,position=pos,rotation={0,180,0},smooth=true})
		end)
		local taken=okTake==true and takenOrErr or nil
		if taken==nil then
			if attempt<20 then safeWaitFrames("Quests",function() drawQuestReplacement(attempt+1) end,3)
			else
				print("QUEST REFILL ERROR: takeObject returned no Quest card after retries: "..tostring(okTake==true and "nil" or takenOrErr))
				gStates.apocalypseQuestOfferRefreshPending=true
				finishQuestOfferRefill()
			end
		else
			gStates.apocalypseQuestOfferDrawSerial=currentQuestTurnSerial
			taken.lock()
			refillMovedGUIDs[taken.guid]=true
			safeWaitFrames("Quests",function() finishQuestOfferRefill() end,2)
		end
	end
	--A shuffle rebuilds the same internal collection, so always give it a few frames before drawing.
	if shuffled==true then safeWaitFrames("Quests",function() drawQuestReplacement(1) end, 3) else drawQuestReplacement(1) end
	--Failsafe only: normal completion is driven by the tracked smooth-move set above.
	safeWaitFrames("Quests",function()
		if refillFinished~=true then finishQuestOfferRefill() end
	end,360)
	end,"Quest offer refill")
	return true
end
function apocalypseQuestDeckSetup(questDeck)
	QuestPrivate.apocalypseQuestAreaZone()
	gStates.apocalypseQuestSetupReady=false
	gStates.apocalypseQuestCardGUIDs={}
	gStates.apocalypseQuestFirstReturnedGUID=nil
	gStates.apocalypseQuestSiteState={}
	gStates.apocalypseQuestProgress={}
	gStates.apocalypseQuestPendingChoice={}
	gStates.apocalypseQuestRevealDone={}
	gStates.apocalypseQuestRevealPending={}
	apocalypseQuestRevealWaitScheduled={}
	gStates.apocalypseQuestReminderCards={}
	gStates.apocalypseQuestHighlightedTokens={}
	gStates.apocalypseQuestMarkerPlacements={}
	gStates.apocalypseQuestMoveAttachments={}
	--Same-frame attachment capture is transient action state and must never leak across a fresh/restarted setup.
	apocalypseQuestMoveAttachmentCapture={}
	gStates.apocalypseQuestOfferRefilling=false
	gStates.apocalypseQuestOfferMoving=false
	gStates.apocalypseQuestOfferRefreshPending=nil
	gStates.apocalypseQuestOfferButtonRefreshPending=nil
	gStates.apocalypseQuestOfferDrawSerial=nil
	if questDeck~=nil and questDeck.type=="Deck" then
		for _,data in pairs(questDeck.getObjects()) do if data.guid~=nil then gStates.apocalypseQuestCardGUIDs[data.guid]=true end end
	end
	local questDeckPosition={46.84,1.14,8.06}
	local startingQuests={"8939c0","08ffcf","81e795","58a826","734740","72099f","11d244","8cdac4","66ea80"}--The 9 starred starting Quest cards
	for a=#startingQuests,2,-1 do
		local b=math.random(1,a)
		startingQuests[a],startingQuests[b]=startingQuests[b],startingQuests[a]
	end
	local startingCount=gStates.playerCount+2
	if gStates.playerCount==1 then startingCount=4 end
	local reserved={}

	local function currentQuestDeck()
		local deck=getObjectFromGUID(GUID.deck.apocalypseQuest)
		if deck~=nil and deck.type=="Deck" then return deck end
		return nil
	end
	local function deckContains(deck,guid)
		if deck==nil then return false end
		for _,data in pairs(deck.getObjects()) do if data.guid==guid then return true end end
		return false
	end

	local offerReady=0
	local function dealQuestOffer()
		local deck=currentQuestDeck()
		if deck==nil then error("Quest setup lost the Apocalypse Quest deck before dealing the offer.",2) end
		for offer=1,2 do
			local slot=offer
			local drawn=safeTakeObject("Quests",deck,{position=QuestPrivate.apocalypseQuestOfferPosition(offer),rotation={0,180,0},smooth=false,callback_function=function(card)
				if card==nil then error("Quest setup could not draw offer slot "..tostring(slot)..".",2) end
				card.lock()
				print("QUEST SETUP DRAW: slot "..tostring(slot).." <- "..tostring(apocalypseQuestName(card)).." ["..tostring(card.guid).."].")
				safeWaitCondition("Quests",function()
					QuestPrivate.apocalypseQuestInterfaceAdd(card)
					offerReady=offerReady+1
					if offerReady>=2 then gStates.apocalypseQuestSetupReady=true end
				end,function()
					local live=getObjectFromGUID(card.guid)
					return live~=nil and live.resting==true
				end,10,function() error("Quest setup timed out waiting for offer slot "..tostring(slot).." to settle.",2) end)
			end})
			if drawn==nil then error("Quest setup could not extract offer slot "..tostring(slot)..".",2) end
		end
	end

	local returnReserved
	returnReserved=function(index)
		if index>#reserved then dealQuestOffer() return end
		local deck=currentQuestDeck()
		local card=reserved[index]
		if deck==nil then error("Quest setup lost the Apocalypse Quest deck while returning reserved cards.",2) end
		if card==nil or (card.isDestroyed~=nil and card.isDestroyed()==true) then error("Quest setup lost a reserved starting Quest card.",2) end
		local cardGUID=card.guid
		card.unlock()
		deck.putObject(card)
		safeWaitCondition("Quests",function() returnReserved(index+1) end,function()
			return deckContains(currentQuestDeck(),cardGUID)
		end,10,function() error("Quest setup timed out returning reserved card "..tostring(cardGUID)..".",2) end)
	end

	--Serialize extraction through takeObject callbacks. The callback is the real completion signal;
	--no extra frame sleeps are needed between cards.
	local takeReserved
	takeReserved=function(index)
		if index>startingCount then
			local deck=currentQuestDeck()
			if deck==nil then error("Quest setup lost the Apocalypse Quest deck before shuffling.",2) end
			deck.shuffle()--Shuffle the unreserved starting Quests in with all other Quests
			safeWaitCondition("Quests",function() returnReserved(1) end,function()
				local live=currentQuestDeck()
				return live~=nil and live.resting==true
			end,10,function() error("Quest setup timed out waiting for the Apocalypse Quest deck shuffle.",2) end)
			return
		end
		local deck=currentQuestDeck()
		if deck==nil then error("Quest setup lost the Apocalypse Quest deck while reserving starting cards.",2) end
		local extracted=safeTakeObject("Quests",deck,{guid=startingQuests[index],position={questDeckPosition[1],4.00+(index*0.10),questDeckPosition[3]},rotation={0,180,180},smooth=false,callback_function=function(card)
			if card==nil then error("Quest setup could not reserve starting Quest "..tostring(startingQuests[index])..".",2) end
			card.lock()
			reserved[#reserved+1]=card
			takeReserved(index+1)
		end})
		if extracted==nil then error("Quest setup could not extract starting Quest "..tostring(startingQuests[index])..".",2) end
	end
	takeReserved(1)
end

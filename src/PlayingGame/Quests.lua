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

--Quest step location rules transcribed from the Quest Card Summary sheet.
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
	local areaObjects=apocalypseQuestAreaObjects()
	local offerCards=apocalypseQuestOfferCards(areaObjects)
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
				local rowOwner=apocalypseQuestIndependentShieldRowOwnerGUID~=nil and apocalypseQuestIndependentShieldRowOwnerGUID(obj,offerCards) or nil
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
local function standardDeckCycleZone(deckName)
	if deckName=="Advanced Action" then return GUID.zone.actionDeck end
	if deckName=="Spell" then return GUID.zone.spellDeck end
	if deckName=="Regular Unit" then return GUID.zone.regularUnit end
	if deckName=="Elite Unit" then return GUID.zone.eliteUnit end
	return nil
end
function standardDeckCycleObject(deckName)
	if deckName=="Artifact" then return getObjectFromGUID(GUID.deck.artifact) end
	local zoneGUID=standardDeckCycleZone(deckName)
	local zone=zoneGUID~=nil and getObjectFromGUID(zoneGUID) or nil
	if zone~=nil then
		for _, obj in pairs(zone.getObjects()) do if obj.type=="Deck" or obj.type=="Card" then return obj end end
	end
	return nil
end
local function standardDeckCycleMarker(deckName)
	if deckName==nil or gStates==nil or gStates.standardDeckFirstReturnedGUID==nil then return nil end
	return gStates.standardDeckFirstReturnedGUID[deckName]
end
function standardDeckCycleMarkReturned(deckName, card)
	if deckName==nil or gStates==nil or gStates.firstStarted~=true or card==nil then return false end
	if gStates.standardDeckFirstReturnedGUID==nil then gStates.standardDeckFirstReturnedGUID={} end
	if gStates.standardDeckFirstReturnedGUID[deckName]==nil then gStates.standardDeckFirstReturnedGUID[deckName]=card.guid return true end
	return false
end
function putCardAtBottom(container,card)
	if container==nil or card==nil or container.guid==card.guid or (container.type~="Deck" and container.type~="Card") then return nil end
	local pos=container.getPosition()
	card.unlock()
	card.setRotation(container.getRotation())
	--Keep it horizontally clear so physics cannot merge it before putObject sees the deliberately
	--lower Y elevation. TTS then inserts it at the bottom regardless of where it came from.
	card.setPosition({pos[1]+3.0,math.max(0.2,pos[2]-0.6),pos[3]})
	return container.putObject(card)
end

function standardDeckCycleShuffleIfReached(deckName, deck, candidateGUID)
	local firstReturned=standardDeckCycleMarker(deckName)
	if firstReturned==nil then return false end
	deck=deck or standardDeckCycleObject(deckName)
	if deck==nil or (deck.type~="Deck" and deck.type~="Card") then return false end
	local reachedGUID=candidateGUID
	if reachedGUID==nil then
		if deck.type=="Deck" then
			local objects=deck.getObjects()
			if objects[1]~=nil then reachedGUID=objects[1].guid end
		else
			reachedGUID=deck.guid
		end
	end
	if reachedGUID~=firstReturned then return false end
	gStates.standardDeckFirstReturnedGUID[deckName]=nil
	if deck.type=="Deck" and deck.getQuantity()>1 then deck.shuffle() end
	return true
end
function standardDeckCycleClearIfDeckShuffled(deck)
	if deck==nil or deck.type~="Deck" or gStates==nil or gStates.standardDeckFirstReturnedGUID==nil then return false end
	for _, deckName in ipairs({"Artifact", "Regular Unit", "Elite Unit", "Advanced Action", "Spell"}) do
		local current=standardDeckCycleObject(deckName)
		if current~=nil and current.guid==deck.guid then gStates.standardDeckFirstReturnedGUID[deckName]=nil return true end
	end
	return false
end

function apocalypseQuestStageIntoContainer(obj,container)
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
		broadcastToAll("Quest cleanup: Could not identify where \""..apocalypseQuestCardTitle(card).."\" from \""..questName.."\" belongs. It has been left on the table.", {1,0.55,0.2})
		return false
	end
	--Standard offers can eventually collapse to a single Card, so find the live deck/card in its deck zone
	--instead of assuming the original setup Deck GUID still exists.
	local destination=standardDeckCycleObject(destinationName) or getObjectFromGUID(destinationGUID)
	if destination==nil or destination.guid==card.guid or (destination.type~="Deck" and destination.type~="Card") then
		broadcastToAll("Quest cleanup: The "..destinationName.." deck was not available for \""..apocalypseQuestCardTitle(card).."\" from \""..questName.."\". It has been left on the table.", {1,0.55,0.2})
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
			broadcastToAll("Quest cleanup: The "..destinationName.." deck disappeared before \""..cardTitle.."\" could be returned.", {1,0.55,0.2})
			return
		end
		putCardAtBottom(liveDestination,liveCard)
		broadcastToAll("Quest cleanup: \""..cardTitle.."\" returned to the bottom of the "..destinationName.." deck.", {1,1,0.5})
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

function apocalypseQuestReturnRevealBag(card)
	local quest=card~=nil and apocalypseQuestData[card.guid] or nil
	if quest==nil or quest.revealBag==nil then return false end
	local bag=getObjectFromGUID(quest.revealBag)
	local tokenBag=getObjectFromGUID(GUID.bag.apocalypseQuestTokens)
	if bag==nil or tokenBag==nil then return false end
	apocalypseQuestStageIntoContainer(bag,tokenBag)
	return true
end

function apocalypseQuestRevealSetup(card)
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
		if rebuild==true then apocalypseQuestInterfaceAdd(live,true) end
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
				track(tokenBag.takeObject({guid=tokenGUID,position={cardPos[1],cardPos[2]+0.45+layerOffset,cardPos[3]-0.15+fanOffset},rotation={0,180,0},smooth=false}))
			end
		end
	end

	--Some Quests keep a small reusable reward supply on the card while they are active.
	if quest.revealBag~=nil then
		local revealGUID=quest.revealBag
		local revealPos
		if card.guid=="72099f" then revealPos={cardPos[1],cardPos[2]+0.42,cardPos[3]-1.18}
		else revealPos={cardPos[1],cardPos[2]+0.62,cardPos[3]+1.35} end
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
			if taken==nil then broadcastToAll("Quest setup: "..apocalypseQuestName(card).." could not find its reward-token bag.",{1,0.55,0.2}) end
		end
	end

	--Catalogue-defined reveal setups.
	if quest.revealSetup=="regularUnitII" then
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
	elseif quest.revealSetup=="spell" then
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
	elseif quest.revealSetup=="randomCrystal" then
		local roll=apocalypseQuestRollManaDie()
		track(apocalypseQuestPlaceManaTokenOnCard(card,roll,0,-0.15,"Travelling Merchant setup"))
	elseif quest.revealSetup=="werewolf" then
		track(apocalypseQuestPlaceNamedEnemy(card,"tan","Werewolf",true,0))
	end

	if pendingReady(pending)==true then finishReveal(false) return true end
	scheduleRevealWait()
	return false
end

function apocalypseQuestUndoSiteToken(tokenGUID)
	if gStates.apocalypseQuestSiteState==nil then return false end
	local state=gStates.apocalypseQuestSiteState[tokenGUID]
	if state==nil then return false end
	local terrainData=terrainTiles[state.terrainGUID]
	if terrainData~=nil then
		terrainData.hexFeature[state.bearing]=state.oldFeature or ""
		if terrainData.mineColors~=nil then
			if state.oldMineColors~=nil then terrainData.mineColors[state.bearing]=state.oldMineColors else terrainData.mineColors[state.bearing]=nil end
		end
		if gStates.hexOverideSave[state.terrainGUID]==nil then gStates.hexOverideSave[state.terrainGUID]={} end
		if state.oldOverride~=nil then gStates.hexOverideSave[state.terrainGUID][state.bearing]=state.oldOverride else gStates.hexOverideSave[state.terrainGUID][state.bearing]=nil end
	end
	gStates.apocalypseQuestSiteState[tokenGUID]=nil
	fakeDropAvatar()
	return true
end

function apocalypseQuestTokenFaceUp(token)
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
	terrainData.hexFeature[bearing]=site
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
	broadcastToAll("Quest site placed: "..site..".", {1,1,0.5})
	fakeDropAvatar()
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
		broadcastToAll(prefix..tostring(details.mage).." loses 1 Reputation"..explanation, positionToColor(playerIndex))
		if playerIndex==gStates.turnNumber then mainUIUpdate("Quest Reputation loss") end
	else
		broadcastToAll(prefix..tostring(details.mage).." is already at minimum Reputation after pending changes; no further Reputation can be lost.", positionToColor(playerIndex))
	end
	return true
end

function apocalypseQuestGainReputation(playerIndex, questName)
	local details=turnOrder[playerIndex]
	if details==nil then return false end
	--Queue Quest Reputation exactly like the Main UI GrowRep button. End-of-turn cleanup applies it.
	refreshPlayerReputationFromShield(playerIndex)
	details.repGain=details.repGain or 0
	if details.repGain<(7-details.reputation) then
		details.repGain=details.repGain+1
		broadcastToAll("Quest reward: "..tostring(details.mage).." gains 1 Reputation from completing \""..tostring(questName or "a Quest").."\".", positionToColor(playerIndex))
		mainUIUpdate("Quest Reputation reward")
	else
		broadcastToAll("Quest reward: "..tostring(details.mage).." is already at maximum Reputation after pending changes.", positionToColor(playerIndex))
	end
	return true
end

function apocalypseQuestBasicCrystalColor(obj)
	if obj==nil then return nil end
	return ({["Red Mana"]="Red", ["Blue Mana"]="Blue", ["Green Mana"]="Green", ["White Mana"]="White"})[obj.getName()]
end

function apocalypseQuestManaTokenColor(obj)
	if obj==nil then return nil end
	local basic=apocalypseQuestBasicCrystalColor(obj)
	if basic~=nil then return basic end
	local name=obj.getName()
	if name=="Gold Mana" then return "Gold" end
	if name=="Black Mana" then return "Black" end
	return nil
end

--Keep every scripted mana crystal/token draw at the same display angle as a manual bag draw.
--Preserve any intentional X/Z rotation supplied by the caller, but normalize Y to 30 degrees.
function takeManaCrystal(bag, params)
	if bag==nil then return nil end
	params=params or {}
	local rotation=params.rotation or {0,0,0}
	params.rotation={rotation[1] or rotation.x or 0,30,rotation[3] or rotation.z or 0}
	return bag.takeObject(params)
end

function apocalypseQuestManaBag(color)
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
function apocalypseQuestBeginMoveAttachmentCapture(card,target)
	local cardGUID=card~=nil and card.guid or nil
	if cardGUID==nil then return end
	local source=card.getPosition()
	apocalypseQuestMoveAttachmentCapture[cardGUID]={target=target~=nil and {target[1],source[2],target[3]} or nil,objects={}}
end
function apocalypseQuestEndMoveAttachmentCapture(card)
	local cardGUID=card~=nil and card.guid or nil
	if cardGUID~=nil then apocalypseQuestMoveAttachmentCapture[cardGUID]=nil end
end
function apocalypseQuestPlannedCardPosition(card)
	if card==nil then return nil end
	local capture=apocalypseQuestMoveAttachmentCapture[card.guid]
	if type(capture)=="table" and capture.target~=nil then return capture.target end
	return card.getPosition()
end
function apocalypseQuestPlannedWorldPosition(card,position)
	if card==nil or position==nil then return position end
	local capture=apocalypseQuestMoveAttachmentCapture[card.guid]
	if type(capture)~="table" or capture.target==nil then return position end
	local source=card.getPosition()
	return {position[1]+capture.target[1]-source[1],position[2],position[3]+capture.target[3]-source[3]}
end
function apocalypseQuestMoveAttachmentTarget(card,obj)
	if card==nil or obj==nil or gStates.apocalypseQuestMoveAttachments==nil then return nil end
	local record=gStates.apocalypseQuestMoveAttachments[card.guid]
	record=record~=nil and record[obj.guid] or nil
	return type(record)=="table" and record.target or nil
end
function apocalypseQuestMoveAttachmentOwnerGUID(objectGUID)
	if objectGUID==nil or gStates.apocalypseQuestMoveAttachments==nil then return nil end
	for cardGUID,records in pairs(gStates.apocalypseQuestMoveAttachments) do
		if records~=nil and records[objectGUID]~=nil then return cardGUID end
	end
	return nil
end
function apocalypseQuestRegisterMoveAttachment(card,obj,target)
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

function apocalypseQuestPlaceManaTokenOnCard(card,color,offsetX,offsetZ,reason)
	if card==nil then return nil end
	local bag=apocalypseQuestManaBag(color)
	if bag==nil or bag.getQuantity()==0 then
		broadcastToAll("Quest effect: no "..tostring(color).." mana token is available for "..tostring(reason or "this Quest")..".",{1,0.55,0.2})
		return nil
	end
	local pos=apocalypseQuestPlannedCardPosition(card) or card.getPosition()
	local target={pos[1]+(offsetX or 0),pos[2]+0.55,pos[3]+(offsetZ or -0.55)}
	local token=takeManaCrystal(bag,{position=target,smooth=false})
	return apocalypseQuestRegisterMoveAttachment(card,token,target)
end

function apocalypseQuestGiveCrystal(playerIndex, color, position, reason)
	if turnOrder[playerIndex]==nil or mineCrystalBagKey[color]==nil then return false end
	if mineCrystalCount(playerIndex, color)>=3 then
		broadcastToAll(tostring(turnOrder[playerIndex].mage).." could not gain the "..color.." crystal from "..tostring(reason or "a Quest").." because their Inventory already has 3.", positionToColor(playerIndex))
		return false
	end
	local bag=getObjectFromGUID(GUID.bag.mana[mineCrystalBagKey[color]])
	if bag==nil or bag.getQuantity()==0 then
		broadcastToAll("Quest reward: no "..color.." crystal is available in the supply.", {1,0.55,0.2})
		return false
	end
	takeManaCrystal(bag,{position=position or mineInventoryPosition(playerIndex, color),smooth=true})
	broadcastToAll(tostring(turnOrder[playerIndex].mage).." gained a "..color.." crystal from "..tostring(reason or "a Quest")..".", positionToColor(playerIndex))
	return true
end

--Quest helpers below can now resolve printed random-mana-crystal rewards when a card's scripted
--completion effect needs them; ordinary resource costs still remain player-confirmed.

function apocalypseQuestPlaceCrystalOnCard(card, color, offsetX, offsetZ, reason)
	return apocalypseQuestPlaceManaTokenOnCard(card,color,offsetX,offsetZ,reason)
end

function apocalypseQuestFinalizeEnemyFacing(enemy, faceUp)
	if enemy==nil then return end
	local enemyGUID=enemy.guid
	safeWaitFrames("Quests",function()
		local placed=getObjectFromGUID(enemyGUID)
		if placed~=nil and ((faceUp==true and placed.is_face_down==true) or (faceUp~=true and placed.is_face_down~=true)) then placed.flip() end
	end,2)
end

function apocalypseQuestPlaceNamedEnemy(card, pileName, enemyName, faceUp, offsetX)
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
		broadcastToAll("Quest setup: no "..tostring(enemyName).." is available in the "..tostring(pileName).." enemy pile or its discard.", {1,0.55,0.2})
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

function apocalypseQuestPlaceEnemy(card, pileName, faceUp, offsetX)
	if card==nil or monsterPiles[pileName]==nil then return nil end
	local bag=getObjectFromGUID(monsterPiles[pileName])
	if bag==nil or bag.getQuantity()==0 then
		broadcastToAll("Quest setup: no "..tostring(pileName).." enemy token is available.", {1,0.55,0.2})
		return nil
	end
	local pos=apocalypseQuestPlannedCardPosition(card) or card.getPosition()
	local target={pos[1]+(offsetX or 0),pos[2]+0.75,pos[3]-0.35}
	local enemy=bag.takeObject({position=target,rotation=faceUp and {0,180,0} or {0,180,180},smooth=true})
	apocalypseQuestRegisterMoveAttachment(card,enemy,target)
	apocalypseQuestFinalizeEnemyFacing(enemy, faceUp)
	return enemy
end

function apocalypseQuestPlaceFistfulEnemies(card, callback)
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
		if live~=nil then apocalypseQuestInterfaceAdd(live,true) end
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

function apocalypseQuestCardHasEnemyType(card, pugType)
	for _, obj in ipairs(apocalypseQuestObjectsOnCard(card)) do
		if monsterPugs[obj.guid]~=nil and monsterPugs[obj.guid].pugType==pugType then return true end
	end
	return false
end

function apocalypseQuestGiveTuckedCard(playerIndex, card, wantedType)
	if card==nil or turnOrder[playerIndex]==nil then return false end
	local tucked=nil
	for _, obj in ipairs(apocalypseQuestObjectsOnCard(card)) do
		if obj.type=="Card" and gameCardType(obj)==wantedType then tucked=obj break end
	end
	if tucked==nil then
		broadcastToAll("Quest reward: \""..apocalypseQuestName(card).."\" could not find its tucked "..wantedType.." card.", {1,0.55,0.2})
		return false
	end
	tucked.unlock()
	local zone=getObjectFromGUID(deedDeckZones[turnOrder[playerIndex].seatPos])
	if wantedType=="Spell" and zone~=nil then
		--Use the same visible, serialized Deed transfer as ordinary claimed cards. This keeps Quest rewards
		--from racing another claim toward the same deck and leaves one place responsible for top-of-deck insertion.
		if queueCardToDeedDeck(playerIndex,tucked)~=true then return false end
		broadcastToAll(tostring(turnOrder[playerIndex].mage).." gained the Spell from \""..apocalypseQuestName(card).."\" on top of their Deed deck.", positionToColor(playerIndex))
		return true
	end
	return false
end

function apocalypseQuestGiveProveYourselfReward(card, playerIndex)
	if card==nil or turnOrder[playerIndex]==nil then return false end
	local token=getObjectFromGUID("c48454")
	local unit=nil
	for _, obj in ipairs(apocalypseQuestObjectsOnCard(card)) do
		if obj.type=="Card" and gameCardType(obj)=="Regular Unit" then unit=obj break end
	end
	if token==nil or unit==nil then
		broadcastToAll("Quest reward: Prove Yourself could not find its Quest token or tucked Unit.", {1,0.55,0.2})
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
	broadcastToAll(tostring(turnOrder[playerIndex].mage).." gained the Prove Yourself Unit and Quest Command token.", positionToColor(playerIndex))
	return true
end

function apocalypseQuestGiveQuestTokenToInventory(playerIndex, tokenGUID, reason)
	if turnOrder[playerIndex]==nil then return nil end
	local token=getObjectFromGUID(tokenGUID)
	if token==nil then
		broadcastToAll("Quest reward: the Quest token for "..tostring(reason or "this Quest").." could not be found.", {1,0.55,0.2})
		return nil
	end
	apocalypseQuestUndoSiteToken(tokenGUID)
	local target=mineInventoryPosition(playerIndex, "Quest")
	target[3]=-33
	token.unlock()
	token.setRotationSmooth({0,180,180})
	token.setPositionSmooth(target)
	broadcastToAll(tostring(turnOrder[playerIndex].mage).." gained the Quest token from "..tostring(reason or "a Quest")..".", positionToColor(playerIndex))
	return token, target
end

function apocalypseQuestSetupDie()
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
function apocalypseQuestPhysicalDiceRoll(dieGUIDs,onSettled,onFailure)
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
function apocalypseQuestRollVisibleManaDie(card,playerIndex,reason,callback,spawnPosition)
	if card==nil or turnOrder[playerIndex]==nil then return false end
	local sourceDie=apocalypseQuestSetupDie()
	if sourceDie==nil then
		broadcastToAll("Quest roll: could not find the Quest setup mana die for "..tostring(reason or "this Quest")..".",{1,0.55,0.2})
		return false
	end
	local cardGUID=card.guid
	local cardPos=spawnPosition or card.getPosition()
	local rollDie=sourceDie.clone({position={cardPos[1],cardPos[2]+0.70,cardPos[3]+1.10}})
	if rollDie==nil then
		broadcastToAll("Quest roll: could not duplicate the Quest setup mana die for "..tostring(reason or "this Quest")..".",{1,0.55,0.2})
		return false
	end
	rollDie.unlock()
	if gStates.apocalypseQuestRollDice==nil then gStates.apocalypseQuestRollDice={} end
	gStates.apocalypseQuestRollDice[rollDie.guid]=true
	apocalypseQuestInterfaceRemove(card)
	broadcastToAll(tostring(reason or "Quest").." is rolling a mana die.",positionToColor(playerIndex))
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

function apocalypseQuestRollExecutionReward(card,playerIndex,callback)
	if card==nil or turnOrder[playerIndex]==nil then return false end
	return apocalypseQuestRollVisibleManaDie(card,playerIndex,"The Execution",function(rolled,questCard)
		if callback~=nil then callback(rolled,questCard) end
	end)
end

--Resolve Guard Duty's 1-3 / 4-6 rewards with the physical Quest mana die. Every die face counts:
--basic colours grant that crystal, Gold lets the player choose a basic crystal, and Black grants +1 Fame.
function apocalypseQuestGuardDutyRollRandomCrystals(card,playerIndex,count,callback)
	if card==nil or turnOrder[playerIndex]==nil or (count or 0)<1 then return false end
	local cardGUID=card.guid
	local results={}
	local finished=false
	local function finish(success)
		if finished==true then return end
		finished=true
		if callback~=nil then callback(success,getObjectFromGUID(cardGUID),results) end
	end
	local rollNext
	rollNext=function()
		local questCard=getObjectFromGUID(cardGUID)
		if questCard==nil then finish(false) return false end
		local started=apocalypseQuestRollVisibleManaDie(questCard,playerIndex,"Guard Duty",function(rolled,liveCard)
			if liveCard==nil or rolled==nil then finish(false) return end
			results[#results+1]=rolled
			if #results>=count then finish(true) else safeWaitFrames("Quests",rollNext,2) end
		end)
		if started~=true then finish(false) end
		return started
	end
	return rollNext()
end

function apocalypseQuestGoblinAttempt(playerIndex,currentOnly)
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

function apocalypseQuestGoblinAttemptReady(playerIndex)
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
			local option=apocalypseQuestChoiceOption(card,"1")
			local state,questState=apocalypseQuestProgressState(card,playerIndex,true)
			if option~=nil and state~=nil and state.step==1 then
				--The printed condition is only for the Quest point: fighting the chosen Goblins completes
				--Step 1 either way. A win earns the green-check point; a loss simply advances without it.
				if allDefeated==true then apocalypseQuestAwardStepPoint(card,playerIndex,option,state,questState) end
				apocalypseQuestAdvanceProgress(card,state,option)
				apocalypseQuestGoblinWarrensRemoveBagIfReady(card)
			end
			warrens[enemyRecord.mage]=nil
			safeWaitFrames("Quests",function()
				local live=getObjectFromGUID("72099f")
				if live~=nil then apocalypseQuestUpdateProgressButtons(live) end
			end,2)
			broadcastToAll(tostring(enemyRecord.mage)..(allDefeated and " defeated all Goblins and completed Goblin Warrens Step 1." or " completed Goblin Warrens Step 1 but did not defeat all Goblins."),positionToColor(playerIndex))
		end
	end
	return true
end

function apocalypseQuestRegisterGoblin(enemy,playerIndex)
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

function apocalypseQuestStartGoblinWarrens(card,playerIndex,chosen)
	if card==nil or card.guid~="72099f" or turnOrder[playerIndex]==nil or chosen==nil or chosen<1 or chosen>3 then return false end
	if apocalypseQuestGoblinAttempt(playerIndex,true)~=nil then return false end
	local option=apocalypseQuestChoiceOption(card,"1")
	if option==nil or apocalypseQuestStarterLocationLegal(card,playerIndex,option)~=true or apocalypseQuestMarkerPlacementAvailable(card,playerIndex,option)~=true then return false end
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
		if questCard~=nil then apocalypseQuestInterfaceAdd(questCard,true) end
	end
	if apocalypseQuestPlaceStepMarker(card,playerIndex,option,nil)~=true then failStart(card,"The Goblin Warrens could not place its Quest marker.") return false end
	--The map marker must leave from the Quest's current position, but the Shield belongs to the card after
	--it is promoted to offer slot 1. Enter the same planned-move lifecycle used by normal Quest Progress.
	apocalypseQuestBeginMoveAttachmentCapture(card,apocalypseQuestOfferPosition(1))
	if apocalypseQuestPositionProgressShield(card,playerIndex,option)~=true then
		apocalypseQuestEndMoveAttachmentCapture(card)
		failStart(card,"The Goblin Warrens could not place the required Quest Shield.")
		return false
	end
	apocalypseQuestEndMoveAttachmentCapture(card)
	apocalypseQuestCommitStepMarker(card,option)
	record.preparing=false
	record.rolling=true
	local started=apocalypseQuestRollVisibleManaDie(card,playerIndex,"The Goblin Warrens",function(rolled,liveCard)
		local current=apocalypseQuestGoblinAttempt(playerIndex,true)
		if liveCard==nil or current~=record then return end
		if rolled==nil then
			gStates.apocalypseQuestGoblinWarrens[mage]=nil
			apocalypseQuestInterfaceAdd(liveCard,true)
			return
		end
		local bonus=(rolled=="Red" or rolled=="Green") and 1 or (rolled=="Black" and 2 or 0)
		local count=chosen+bonus
		local bag=getObjectFromGUID("f021d8")
		if bag==nil then
			broadcastToAll("{en}The Goblin Warrens could not find its Goblin infinite bag.{ru}The Goblin Warrens не смогло найти бесконечный мешок гоблинов.{zh-tw}The Goblin Warrens 找不到哥布林無限袋。{zh-cn}The Goblin Warrens 找不到哥布林无限袋。{ko}The Goblin Warrens에서 고블린 무한 주머니를 찾지 못했습니다.{es}The Goblin Warrens no pudo encontrar su bolsa infinita de Goblins.{fr}The Goblin Warrens n’a pas pu trouver son sac infini de Gobelins.{pt-br}The Goblin Warrens não conseguiu encontrar sua bolsa infinita de Goblins.{de}The Goblin Warrens konnte seinen unendlichen Goblin-Beutel nicht finden.",{1,0.55,0.2})
			gStates.apocalypseQuestGoblinWarrens[mage]=nil
			apocalypseQuestInterfaceAdd(liveCard,true)
			return
		end
		record.rolling=false
		record.roll=rolled
		record.expected=count
		record.enemies={}
		if gStates.attackedMonsters==nil then gStates.attackedMonsters={} end
		local bagPos=bag.getPosition()
		for i=1,count do
			local target=apocalypseQuestNextCombatTarget(playerIndex)
			local enemy=target~=nil and bag.takeObject({position=target,rotation={0,180,0},smooth=true}) or nil
			if enemy~=nil and apocalypseQuestRegisterGoblin(enemy,playerIndex)==true then
				record.enemies[#record.enemies+1]=enemy.guid
				gStates.attackedMonsters[enemy.guid]={{bagPos[1],2.5,bagPos[3]},{0,180,0}}
				apocalypseQuestTrackCombatEnemy(liveCard,enemy)
			end
		end
		if #record.enemies~=count then
			broadcastToAll("The Goblin Warrens could only create "..tostring(#record.enemies).." of "..tostring(count).." Goblins; this attempt cannot be completed.",{1,0.55,0.2})
		else
			combatCameraFocus(playerIndex)
			broadcastToAll(tostring(mage).." chose "..tostring(chosen)..", rolled "..tostring(rolled)..", and must fight "..tostring(count).." Goblin"..(count==1 and "" or "s")..".",positionToColor(playerIndex))
		end
		apocalypseQuestInterfaceAdd(liveCard,true)
	end,apocalypseQuestOfferPosition(1))
	if started~=true then failStart(card,"The Goblin Warrens could not start its Quest die roll.") return false end
	--As with Rich Merchant, let the roll result own the next UI rebuild while the offer itself moves now.
	apocalypseQuestOfferMoveToLeft(card,function() end)
	return true
end

function apocalypseQuestResolveRichMerchantRoll(card,playerIndex,roll)
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
		broadcastToAll("A Rich Merchant rolled Black; Step 2 will attack at the start of this Hero's next turn.",positionToColor(playerIndex))
	else
		broadcastToAll("A Rich Merchant rolled "..tostring(roll)..". Press Complete to finish the Quest.",positionToColor(playerIndex))
	end
	return true
end

function apocalypseQuestResolveHerbalistReward(card, playerIndex, rolled, crystalGUID, crystalColor)
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
		broadcastToAll("The Eager Herbalist rolled "..rolled.."; a second crystal was added to the reward token.",positionToColor(playerIndex))
	else
		broadcastToAll("The Eager Herbalist rolled "..tostring(rolled).."; no second crystal was added.",positionToColor(playerIndex))
	end
	return true
end

function apocalypseQuestGiveHerbalistReward(card, playerIndex, callback)
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
	apocalypseQuestInterfaceRemove(card)
	broadcastToAll("The Eager Herbalist is rolling the Quest mana die for its second crystal.",positionToColor(player))
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
		if questCard~=nil then apocalypseQuestInterfaceAdd(questCard,true) end
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

function apocalypseQuestGiveBardReward(card, playerIndex)
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
		broadcastToAll("Quest reward: "..tostring(turnOrder[playerIndex].mage).." gains "..tostring(fame).." Fame from The Admiring Bard's "..tostring(crystalColor).." crystal.", positionToColor(playerIndex))
		mainUIUpdate("Quest Fame reward")
	else
		broadcastToAll("{en}Quest reward: The Admiring Bard had no Green, Blue or Red crystal on the card, so no Fame was gained.{ru}Награда задания: на карте The Admiring Bard нет зелёного, синего или красного кристалла, поэтому Слава не получена.{zh-tw}任務獎勵：The Admiring Bard 牌上沒有綠色、藍色或紅色水晶，因此沒有獲得聲望值。{zh-cn}任务奖励：The Admiring Bard 牌上没有绿色、蓝色或红色水晶，因此没有获得声望值。{ko}퀘스트 보상: The Admiring Bard 카드에 녹색, 파란색 또는 빨간색 크리스털이 없어 명성을 얻지 못했습니다.{es}Recompensa de Misión: The Admiring Bard no tenía cristal Verde, Azul ni Rojo en la carta, por lo que no se ganó Fama.{fr}Récompense de Quête : The Admiring Bard n’avait aucun cristal Vert, Bleu ou Rouge sur la carte ; aucune Renommée n’a donc été gagnée.{pt-br}Recompensa da Missão: The Admiring Bard não tinha cristal Verde, Azul ou Vermelho na carta, então nenhuma Fama foi ganha.{de}Quest-Belohnung: Auf der Karte von The Admiring Bard lag kein grüner, blauer oder roter Kristall; daher wurde kein Ruhm erhalten.", {1,0.55,0.2})
	end
	return true
end

function apocalypseQuestFlipSiteToken(tokenGUID)
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

function apocalypseQuestPlaceRandomCrystalOnShield(card, playerIndex)
	local shield=apocalypseQuestPlayerShield(card, playerIndex)
	if shield==nil then return false end
	local color=apocalypseQuestRollManaDie()
	if mineCrystalBagKey[color]~=nil then
		local bag=getObjectFromGUID(GUID.bag.mana[mineCrystalBagKey[color]])
		if bag~=nil and bag.getQuantity()~=0 then
			local pos=apocalypseQuestMoveAttachmentTarget(card,shield) or apocalypseQuestPlannedWorldPosition(card,shield.getPosition())
			local target={pos[1],pos[2]+0.34,pos[3]}
			local crystal=takeManaCrystal(bag,{position=target,smooth=false})
			apocalypseQuestRegisterMoveAttachment(card,crystal,target)
			broadcastToAll("The Child Seer rolled "..color.."; the matching mana token was placed on the Quest Shield.",positionToColor(playerIndex))
			return true
		end
	end
	broadcastToAll("The Child Seer rolled "..tostring(color)..". Place the matching mana token on your Quest Shield manually.",positionToColor(playerIndex))
	return true
end

function apocalypseQuestBeginCrystalChoice(card, playerIndex)
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

function apocalypseQuestRollManaDie()
	local colors={"Red","Blue","Green","White","Gold","Black"}
	return colors[math.random(1,#colors)]
end

function apocalypseQuestGainRandomBasicCrystal(playerIndex, reason)
	for roll=1,20 do
		local color=apocalypseQuestRollManaDie()
		if mineCrystalBagKey[color]~=nil then
			apocalypseQuestGiveCrystal(playerIndex,color,nil,reason)
			return color
		end
	end
	return nil
end

function apocalypseQuestPlaceCrystalAt(position,color,reason)
	if position==nil or mineCrystalBagKey[color]==nil then return nil end
	local bag=getObjectFromGUID(GUID.bag.mana[mineCrystalBagKey[color]])
	if bag==nil or bag.getQuantity()==0 then
		broadcastToAll("Quest effect: no "..tostring(color).." mana crystal is available for "..tostring(reason or "this Quest")..".", {1,0.55,0.2})
		return nil
	end
	return takeManaCrystal(bag,{position=position,smooth=true})
end

function apocalypseQuestCardCrystalColor(card)
	for _, obj in ipairs(apocalypseQuestObjectsOnCard(card)) do
		local color=apocalypseQuestBasicCrystalColor(obj)
		if color~=nil then return color end
	end
	return nil
end

function apocalypseQuestCardManaColor(card)
	for _, obj in ipairs(apocalypseQuestObjectsOnCard(card)) do
		local color=apocalypseQuestManaTokenColor(obj)
		if color~=nil then return color end
	end
	return nil
end

function apocalypseQuestPlayerCombatEnemies(playerIndex, faceUpOnly)
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

function apocalypseQuestCursedMarkHolder(card,playerIndex)
	if card==nil or turnOrder[playerIndex]==nil then return end
	if gStates.apocalypseQuestCursedHistory==nil then gStates.apocalypseQuestCursedHistory={} end
	if gStates.apocalypseQuestCursedHistory[card.guid]==nil then gStates.apocalypseQuestCursedHistory[card.guid]={} end
	gStates.apocalypseQuestCursedHistory[card.guid][turnOrder[playerIndex].mage]=true
end

function apocalypseQuestCursedTargetEligible(card,playerIndex,targetIndex,allowTargetShield,hexes,mapObjects,source)
	local details=turnOrder[targetIndex]
	if card==nil or targetIndex==playerIndex or details==nil or details.mage==nil or details.mage=="nobody" or details.mage==gStates.positionMageKnight[5] or details.dropoutState~=nil then return false end
	local history=gStates.apocalypseQuestCursedHistory~=nil and gStates.apocalypseQuestCursedHistory[card.guid] or nil
	if history~=nil and history[details.mage]==true then return false end
	if allowTargetShield~=true and apocalypseQuestPlayerShield(card,targetIndex)~=nil then return false end
	if hexes==nil then hexes,mapObjects=apocalypseQuestMapHexes() end
	source=source or apocalypseQuestPlayerHex(hexes,mapObjects,playerIndex)
	local target=source~=nil and apocalypseQuestPlayerHex(hexes,mapObjects,targetIndex) or nil
	return target~=nil and (apocalypseQuestMapHexKey(source)==apocalypseQuestMapHexKey(target) or apocalypseQuestHexesAdjacent(source,target)==true)
end

function apocalypseQuestCursedTargetIndex(card,playerIndex)
	if card==nil then return nil end
	local hexes,mapObjects=apocalypseQuestMapHexes()
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

function apocalypseQuestCursedEligibleTargets(card,playerIndex)
	local result={}
	local hexes,mapObjects=apocalypseQuestMapHexes()
	local source=apocalypseQuestPlayerHex(hexes,mapObjects,playerIndex)
	if source==nil then return result end
	for index, _ in ipairs(turnOrder) do
		if apocalypseQuestCursedTargetEligible(card,playerIndex,index,false,hexes,mapObjects,source)==true then result[#result+1]=index end
	end
	return result
end

function apocalypseQuestCursedAutoShield(card,playerIndex,targetIndex)
	local sourceShield=apocalypseQuestPlayerShield(card,playerIndex)
	if sourceShield==nil or targetIndex==nil then return false end
	--Cursed is the Independent-Quest exception: each new holder covers the previous holder's Shield.
	--Use the source Shield's planned destination if the offer is already moving there.
	local sourcePos=apocalypseQuestMoveAttachmentTarget(card,sourceShield) or apocalypseQuestPlannedWorldPosition(card,sourceShield.getPosition())
	local shield=apocalypseQuestPlayerShield(card,targetIndex)
	local target=apocalypseQuestRaisedPiecePosition(sourcePos)
	if shield==nil then
		shield=apocalypseQuestTakePlayerShield(targetIndex,sourcePos)
	elseif shield.guid~=sourceShield.guid then
		shield.unlock()
		shield.setPositionSmooth(target)
	end
	apocalypseQuestRegisterMoveAttachment(card,shield,target)
	return shield~=nil
end

function apocalypseQuestStepSpecialLegal(card,playerIndex,option)
	if card==nil or option==nil then return true end
	local key=tostring(option.key)
	local branch=gStates.apocalypseQuestDirectBranch~=nil and gStates.apocalypseQuestDirectBranch[card.guid] or nil
	if card.guid=="8939c0" and branch~=nil then
		if key~=branch then return false end
		if key=="1b" then return apocalypseQuestCombatStartedThisTurn(card,1) end
	end
	if card.guid=="8cdac4" and key=="3" then return apocalypseQuestCombatStartedThisTurn(card,3) end
	if card.guid=="66ea80" and (key=="2" or key=="3") then return apocalypseQuestCombatStartedThisTurn(card,tonumber(key)) end
	if card.guid=="485cc5" and key=="2" then return apocalypseQuestCombatStartedThisTurn(card,2) end
	if card.guid=="c73a1f" and key=="3" then return apocalypseQuestCombatStartedThisTurn(card,3) end
	if card.guid=="82a935" and branch~=nil then
		if key~=branch then return false end
		if key=="2c" then return apocalypseQuestCombatStartedThisTurn(card,2) end
	end
	if card.guid=="a6d5cc" and key=="2a" then return apocalypseQuestCombatStartedThisTurn(card,2) end
	if card.guid=="8cff07" and key=="2" then return apocalypseQuestCombatStartedThisTurn(card,2) end
	if card.guid=="d70436" and key=="3" then return apocalypseQuestCombatStartedThisTurn(card,3) end
	if card.guid=="dd35bb" and key=="3" then return apocalypseQuestCombatStartedThisTurn(card,3) end
	if card.guid=="783076" and key=="2" then return apocalypseQuestCombatStartedThisTurn(card,2) end
	if card.guid=="abd4fb" then
		local questState=gStates.apocalypseQuestProgress~=nil and gStates.apocalypseQuestProgress[card.guid] or nil
		if key=="1" then return questState==nil or questState.globalPoints==nil or (questState.globalPoints["1"] or 0)<1 end
		local cursed=gStates.apocalypseQuestCursedHero~=nil and gStates.apocalypseQuestCursedHero[card.guid] or nil
		if turnOrder[playerIndex]==nil or cursed~=turnOrder[playerIndex].mage then return false end
		if key=="2a" then
			if apocalypseQuestCursedTargetIndex(card,playerIndex)~=nil then return true end
			return #apocalypseQuestCursedEligibleTargets(card,playerIndex)==1
		end
	end
	if card.guid=="ce70fb" and apocalypseQuestStepNumber(key)==2 then
		local chosen=gStates.apocalypseQuestCombatBranch~=nil and gStates.apocalypseQuestCombatBranch[card.guid] or nil
		if chosen~=nil and chosen~=key then return false end
		return chosen~=nil and apocalypseQuestCombatStartedThisTurn(card,2)
	end
	if card.guid=="8455b5" and apocalypseQuestStepNumber(key)==2 then
		--The player declares which printed enemy category they defeated; do not inspect the combat area.
		return true
	end
	if card.guid=="bb2828" and key=="2" then return #apocalypseQuestArtificerAvailableColors(card,playerIndex)>0 end
	if card.guid=="bb2828" and key=="3" then return apocalypseQuestArtificerUniqueCrystalCount(card)>=3 end
	return true
end

function apocalypseQuestFailureReady(card,option,playerIndex)
	if card==nil or option==nil then return true end
	local key=tostring(option.key)
	if card.guid=="37e2ce" and key=="2" then return apocalypseQuestFreeWineFailureReady(playerIndex or gStates.turnNumber) end
	if card.guid=="a6d5cc" and key=="2b" then return apocalypseQuestCombatStartedThisTurn(card,2)~=true and apocalypseQuestUnderSiegeStep2ChoiceLegal(playerIndex or gStates.turnNumber,"2b") end
	if card.guid=="8939c0" and key=="1b" then return apocalypseQuestCombatStartedThisTurn(card,1) end
	if card.guid=="82a935" and key=="2c" then return apocalypseQuestCombatStartedThisTurn(card,2) end
	if card.guid=="8cff07" and key=="2" then return apocalypseQuestCombatStartedThisTurn(card,2) end
	if card.guid=="d70436" and key=="3" then return apocalypseQuestCombatStartedThisTurn(card,3) end
	if card.guid=="ce70fb" and key=="2a" then return apocalypseQuestCombatStartedThisTurn(card,2) end
	if card.guid=="783076" and key=="2" then return apocalypseQuestCombatStartedThisTurn(card,2) end
	return true
end

function apocalypseQuestCombatOption(card,state)
	if card==nil or state==nil then return nil end
	local wanted=nil
	if card.guid=="8939c0" and state.step==1 then wanted="1b"
	elseif card.guid=="8cdac4" and state.step==3 then wanted="3"
	elseif card.guid=="66ea80" and (state.step==2 or state.step==3) then wanted=tostring(state.step)
	elseif card.guid=="485cc5" and state.step==2 then wanted="2"
	elseif card.guid=="82a935" and state.step==2 then wanted="2c"
	elseif card.guid=="a6d5cc" and state.step==2 then wanted="2a"
	elseif card.guid=="8cff07" and state.step==2 then wanted="2"
	elseif card.guid=="d70436" and state.step==3 then wanted="3"
	elseif card.guid=="c73a1f" and state.step==3 then wanted="3"
	elseif card.guid=="ce70fb" and state.step==2 then wanted=(gStates.apocalypseQuestCombatBranch~=nil and gStates.apocalypseQuestCombatBranch[card.guid]) or "2a"
	elseif card.guid=="dd35bb" and state.step==3 then wanted="3"
	elseif card.guid=="783076" and state.step==2 then wanted="2"
	end
	if wanted==nil then return nil end
	return apocalypseQuestChoiceOption(card,wanted)
end

function apocalypseQuestCombatRelevant(card,playerIndex)
	if card==nil then return false end
	local state=apocalypseQuestProgressState(card,playerIndex,false)
	return state~=nil and state.completed~=true and apocalypseQuestCombatOption(card,state)~=nil
end

--Quest enemies already sitting on a Quest card use the same floating Attack icon as a
--nearby Rampaging enemy.  Generated combats (Execution, Mine of Doom, etc.) still need
--the card Fight control because there is no enemy object to click until the fight begins.
function apocalypseQuestUsesEnemyAttackButton(card)
	return card~=nil and (card.guid=="8cdac4" or card.guid=="66ea80" or card.guid=="c73a1f" or card.guid=="783076")
end

function apocalypseQuestRemoveEnemyAttackButton(enemy)
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

function apocalypseQuestClearEnemyAttackButtons(card)
	if card==nil then return end
	for _, obj in ipairs(apocalypseQuestObjectsOnCard(card)) do
		if monsterPugs[obj.guid]~=nil then apocalypseQuestRemoveEnemyAttackButton(obj) end
	end
end

--Object UI is one-sided. When an enemy token is face down the normal negative-Z UI plane
--sits underneath the token, so put the Quest Attack button on the opposite side and turn its
--front face outward. This mirrors the proven Banner of Command face-down UI handling.
function apocalypseQuestEnemyAttackButtonPosition(enemy)
	local depth=20/0.9
	return "0 "..tostring(120/0.9).." "..tostring(enemy~=nil and enemy.is_face_down==true and depth or -depth)
end
function apocalypseQuestEnemyAttackButtonRotation(enemy)
	return enemy~=nil and enemy.is_face_down==true and "0 180 180" or "0 0 180"
end

apocalypseQuestEnemyAttackRotationGeneration={}
function apocalypseQuestRefreshEnemyAttackButtonOrientation(enemyGUID)
	local enemy=getObjectFromGUID(enemyGUID)
	if enemy==nil then return false end
	local xml=enemy.UI.getXmlTable() or {}
	local wantedRotation=apocalypseQuestEnemyAttackButtonRotation(enemy)
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
			apocalypseQuestRefreshEnemyAttackButtonOrientation(enemyGUID)
		end, function()
			local live=getObjectFromGUID(enemyGUID)
			return apocalypseQuestEnemyAttackRotationGeneration[enemyGUID]~=generation or live==nil or live.resting==true
		end, 2, function()
			if apocalypseQuestEnemyAttackRotationGeneration[enemyGUID]==generation then apocalypseQuestRefreshEnemyAttackButtonOrientation(enemyGUID) end
		end)
	end,1)
	return true
end

function apocalypseQuestRefreshEnemyAttackButtons(card,playerIndex)
	if card==nil or apocalypseQuestUsesEnemyAttackButton(card)~=true then return end
	--Only the six Quests with enemies sitting on their cards need this work. Snapshot the card objects
	--once so combat availability and the actual button refresh do not each scan the whole table.
	local cardObjects=apocalypseQuestObjectsOnCard(card)
	local active=playerIndex~=nil and apocalypseQuestCombatAvailable(card,playerIndex,cardObjects)==true
	for _, enemy in ipairs(cardObjects) do
		if monsterPugs[enemy.guid]~=nil then
			apocalypseQuestRemoveEnemyAttackButton(enemy)
			if active==true then
				local xml=enemy.UI.getXmlTable() or {}
				xml[#xml+1]={tag="Button", attributes={id="QuestAtk"..card.guid..enemy.guid,
					onClick="global/apocalypseQuestEnemyAttack",
					height=70/0.9, width=70/0.9,
					position=apocalypseQuestEnemyAttackButtonPosition(enemy), rotation=apocalypseQuestEnemyAttackButtonRotation(enemy),
					color="rgba(0,0,0,0.0)"},
					children={{tag="Image", attributes={image="Attack Button"}}}}
				enemy.UI.setXmlTable(xml)
			end
		end
	end
end

function apocalypseQuestCombatLaunchKey(card,state)
	return tostring(card.guid)..":"..tostring(state~=nil and state.step or 0)..":"..tostring(gStates.apocalypseQuestTurnSerial or 0)
end

function apocalypseQuestMarkCombatStarted(card,stepNumber)
	if card==nil then return end
	if gStates.apocalypseQuestCombatStarted==nil then gStates.apocalypseQuestCombatStarted={} end
	gStates.apocalypseQuestCombatStarted[card.guid]={serial=gStates.apocalypseQuestTurnSerial or 0,step=tonumber(stepNumber) or 0}
end

function apocalypseQuestCombatStartedThisTurn(card,stepNumber)
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
function apocalypseQuestSetRewardCompletionGate(card,playerIndex,action)
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

function apocalypseQuestRewardCompletionPendingForSeat(seatPos)
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
	for _, card in ipairs(apocalypseQuestOfferCards()) do
		local state=apocalypseQuestProgressState(card,playerIndex,false)
		local option=state~=nil and state.completed~=true and apocalypseQuestCombatOption(card,state) or nil
		local quest=apocalypseQuestData[card.guid]
		local failOnly=quest~=nil and quest.failOnlySteps~=nil and option~=nil and quest.failOnlySteps[tostring(option.key)]==true
		if state~=nil and option~=nil and failOnly~=true and apocalypseQuestCombatStartedThisTurn(card,state.step)==true then
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
			--The Execution 1B must be resolved on the Quest card after either result. A win requires
			--Complete; a loss requires Fail. Unlike ordinary Quest combats, losing this fight therefore
			--still keeps Rewards Claimed behind the Quest-card resolution.
			if card.guid=="8939c0" and tostring(option.key)=="1b" and fought>0 then
				resolved=true
				requiredAction=allDefeated==true and "Complete" or "Fail"
			end
			if resolved==true then
				apocalypseQuestSetRewardCompletionGate(card,playerIndex,requiredAction)
				captured=true
			else
				gStates.apocalypseQuestRewardCompletionPending[card.guid]=nil
			end
		end
	end
	return captured
end

function apocalypseQuestClearRewardCompletionGate(card,playerIndex)
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

function apocalypseQuestCombatAvailable(card,playerIndex,cardObjects)
	if card==nil or apocalypseQuestPlayerMayAct(card,playerIndex)~=true then return false end
	local state=apocalypseQuestProgressState(card,playerIndex,false)
	if state==nil or state.completed==true then return false end
	if card.guid=="a6d5cc" and state.step==2 and apocalypseQuestUnderSiegeStep2ChoiceLegal(playerIndex,"2a")~=true then return false end
	local option=apocalypseQuestCombatOption(card,state)
	if option==nil or apocalypseQuestStarterLocationLegal(card,playerIndex,option)~=true then return false end
	if gStates.apocalypseQuestCombatLaunches~=nil and gStates.apocalypseQuestCombatLaunches[card.guid]==apocalypseQuestCombatLaunchKey(card,state) then return false end
	if apocalypseQuestUsesEnemyAttackButton(card)==true then
		for _, obj in ipairs(cardObjects or apocalypseQuestObjectsOnCard(card)) do if monsterPugs[obj.guid]~=nil then return true end end
		return false
	end
	return true
end

function apocalypseQuestTrackCombatEnemy(card,enemy)
	if card==nil or enemy==nil then return end
	if gStates.apocalypseQuestCombatEnemies==nil then gStates.apocalypseQuestCombatEnemies={} end
	if gStates.apocalypseQuestCombatEnemies[card.guid]==nil then gStates.apocalypseQuestCombatEnemies[card.guid]={} end
	gStates.apocalypseQuestCombatEnemies[card.guid][enemy.guid]=true
end

function apocalypseQuestNextCombatTarget(playerIndex)
	if turnOrder[playerIndex]==nil then return nil end
	gStates.monsterOffsetX=gStates.monsterOffsetX or 0
	gStates.monsterOffsetZ=gStates.monsterOffsetZ or 0
	local seat=turnOrder[playerIndex].seatPos
	local target={(seat*40)-96+gStates.monsterOffsetX,2.5,-39-gStates.monsterOffsetZ}
	gStates.monsterOffsetX=gStates.monsterOffsetX+2.5
	if gStates.monsterOffsetX>12 then gStates.monsterOffsetX=0 gStates.monsterOffsetZ=gStates.monsterOffsetZ+2.5 end
	return target
end

function apocalypseQuestMoveEnemyToPlayer(card,playerIndex,enemy,focusCamera)
	if card==nil or enemy==nil or turnOrder[playerIndex]==nil then return false end
	--The floating Quest Attack icon belongs only to the token while it is waiting on the Quest card.
	apocalypseQuestRemoveEnemyAttackButton(enemy)
	if gStates.attackedMonsters==nil then gStates.attackedMonsters={} end
	local oldPos=enemy.getPosition()
	local oldRot=enemy.getRotation()
	if gStates.monsterPlayLocation==nil then gStates.monsterPlayLocation={} end
	gStates.monsterPlayLocation[enemy.guid]={oldPos[1],oldPos[2],oldPos[3]}
	gStates.attackedMonsters[enemy.guid]={{oldPos[1],oldPos[2],oldPos[3]},{oldRot[1],oldRot[2],oldRot[3]}}
	apocalypseQuestTrackCombatEnemy(card,enemy)
	local target=apocalypseQuestNextCombatTarget(playerIndex)
	if target==nil then return false end
	enemy.unlock()
	enemy.setRotationSmooth({0,180,0})
	if focusCamera~=false then combatCameraFocus(playerIndex) end
	enemy.setPositionSmooth(target)
	return true,target
end

function apocalypseQuestMoveCardEnemiesToPlayer(card,playerIndex,maxCount)
	local moved=0
	for _, enemy in ipairs(apocalypseQuestObjectsOnCard(card)) do
		if monsterPugs[enemy.guid]~=nil and (maxCount==nil or moved<maxCount) then
			if apocalypseQuestMoveEnemyToPlayer(card,playerIndex,enemy,moved==0)==true then moved=moved+1 end
		end
	end
	return moved
end

function apocalypseQuestSpawnEnemyToCombat(card,playerIndex,pileName,possessed,offset,attackBonus,possessedFaction)
	if card==nil or turnOrder[playerIndex]==nil or monsterPiles[pileName]==nil then return nil end
	local bag=getObjectFromGUID(monsterPiles[pileName])
	if bag==nil or bag.getQuantity()==0 then
		broadcastToAll("Quest combat: no "..tostring(pileName).." enemy token is available.", {1,0.55,0.2})
		return nil
	end
	local target=apocalypseQuestNextCombatTarget(playerIndex)
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
	apocalypseQuestTrackCombatEnemy(card,enemy)
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
				safeWaitFrames("Quests",function() apocalypseQuestAddEnemyAttackBonus(enemyGUID,attackBonus) end,24)
			end
		end,refillImmediate and 3 or 15)
	elseif attackBonus~=nil and attackBonus~=0 then
		safeWaitFrames("Quests",function() apocalypseQuestAddEnemyAttackBonus(enemyGUID,attackBonus) end,8)
	end
	return enemy
end

function allAttackBonusDecalURL(bonus)
	bonus=tonumber(bonus) or 0
	if bonus==1 then return "https://steamusercontent-a.akamaihd.net/ugc/15079936556037598648/4230C9B5103E634683302A5818A744A4B14CD8CF/" end
	if bonus==2 then return "https://steamusercontent-a.akamaihd.net/ugc/10898261749964477479/1CE17B450996B940608CA7CEBB7269B0FBC7EB9A/" end
	if bonus==3 then return "https://steamusercontent-a.akamaihd.net/ugc/9640160926418445784/88929ADF524E4BC2A53D4CDB2B942A925BB53625/" end
	return nil
end

function syncNamedAttackBonusDecal(obj,prefix,bonus,position)
	if obj==nil or prefix==nil or position==nil then return false end
	local decals={}
	for _, decalDetails in pairs(obj.getDecals() or {}) do
		if tostring(decalDetails.name or ""):sub(1,#prefix)~=prefix then decals[#decals+1]=decalDetails end
	end
	local url=allAttackBonusDecalURL(bonus)
	if url~=nil then decals[#decals+1]={name=prefix..tostring(bonus), url=url, position=position, rotation={90,180,0}, scale={0.72,0.72,1}} end
	obj.setDecals(decals)
	return true
end

--Visual reminder for temporary +X to every Attack. Use the same decal placement/scale as
--the Green City Poison bonus so this behaves like the mod's existing monster bonus markers.
function addAllAttackBonusDecal(enemy,bonus)
	if enemy==nil then return end
	syncNamedAttackBonusDecal(enemy,"AllAttack+",bonus,{1.1,0.15,0.25})
end

function syncDragonHeadAttackBonusDecal(tokenGUID,bonus)
	local token=tokenGUID~=nil and getObjectFromGUID(tokenGUID) or nil
	if token==nil then return false end
	--The head tokens sit at 180 degrees, so positive local X is visually left.
	--Keep the Control bonus centred vertically rather than using the Quest possessed-token offset.
	syncNamedAttackBonusDecal(token,"DragonAllAttack+",bonus,{1.1,0.15,0})
	return true
end

function apocalypseQuestFogEnemy(card)
	if card==nil then return nil end
	for _, obj in ipairs(apocalypseQuestObjectsOnCard(card)) do
		if monsterPugs[obj.guid]~=nil and monsterPugs[obj.guid].pugType=="tan" then return obj end
	end
	return nil
end

function apocalypseQuestFogPossessedReady(card)
	local enemy=apocalypseQuestFogEnemy(card)
	if enemy==nil then return false end
	for _, attachment in pairs(enemy.getAttachments() or {}) do
		if monsterPugs[attachment.guid]~=nil and monsterPugs[attachment.guid].pugType=="possessed" then return true end
	end
	return false
end

function apocalypseQuestPossessExistingEnemy(card,enemy,faction)
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

function apocalypseQuestAddEnemyAttackBonus(enemyGUID,bonus)
	local enemy=getObjectFromGUID(enemyGUID)
	local base=monsterPugs[enemyGUID]
	if enemy==nil or base==nil or bonus==nil then return false end
	if gStates.monsterPerks[enemyGUID]==nil then gStates.monsterPerks[enemyGUID]={} end
	local source=gStates.monsterPerks[enemyGUID].attack or base.attack
	if source==nil then
		gStates.monsterPerks[enemyGUID].boost=(gStates.monsterPerks[enemyGUID].boost or 0)+bonus
		addAllAttackBonusDecal(enemy,bonus)
		return true
	end
	local adjusted={}
	for attackType,values in pairs(source) do
		adjusted[attackType]={}
		for index,value in pairs(values) do adjusted[attackType][index]=value+bonus end
	end
	gStates.monsterPerks[enemyGUID].attack=adjusted
	addAllAttackBonusDecal(enemy,bonus)
	setMonsterObjectButtons(enemy,true)
	return true
end

function apocalypseQuestMineDoomColors(playerIndex)
	local hex=apocalypseQuestCurrentPlayerHex(playerIndex)
	if hex==nil or apocalypseQuestFeatureMatches(hex.feature,"mine")~=true then return {} end
	local details=terrainTiles[hex.terrainGUID]
	local colors=details~=nil and details.mineColors~=nil and details.mineColors[hex.bearing] or nil
	local result={}
	for _, color in ipairs(colors or {}) do result[#result+1]=color end
	return result
end

function apocalypseQuestArtificerAvailableColors(card,playerIndex)
	local available={}
	local used={}
	for _, obj in ipairs(apocalypseQuestObjectsOnCard(card)) do
		local color=apocalypseQuestBasicCrystalColor(obj)
		if color~=nil then used[color]=true end
	end
	for _, color in ipairs(apocalypseQuestMineDoomColors(playerIndex)) do
		if used[color]~=true then available[#available+1]=color end
	end
	return available
end

function apocalypseQuestArtificerUniqueCrystalCount(card)
	local used={}
	for _, obj in ipairs(apocalypseQuestObjectsOnCard(card)) do
		local color=apocalypseQuestBasicCrystalColor(obj)
		if color~=nil then used[color]=true end
	end
	local count=0
	for _,_ in pairs(used) do count=count+1 end
	return count
end

function apocalypseQuestLaunchMineDoom(card,playerIndex,color,attackBonus)
	local recipes={
		Blue={{"purple",true},{"purple",true}},
		Red={{"red",true}},
		Green={{"green",true},{"green",true},{"green",true}},
		White={{"gray",true},{"white",true}},
	}
	local recipe=recipes[color]
	if recipe==nil then return false end
	for index,data in ipairs(recipe) do
		apocalypseQuestSpawnEnemyToCombat(card,playerIndex,data[1],data[2],(index-1)*0.25,attackBonus or 0,"Apoc")
	end
	if attackBonus~=nil and attackBonus>0 then
		broadcastToAll("{en}Mine of Doom: this mine has multiple crystal colors; all Quest enemies get +1 to every Attack.{ru}Mine of Doom: в этой шахте несколько цветов кристаллов; все враги задания получают +1 к каждой Атаке.{zh-tw}Mine of Doom：此礦場有多種水晶顏色；所有任務敵人的每次攻擊 +1。{zh-cn}Mine of Doom：此矿场有多种水晶颜色；所有任务敌人的每次攻击 +1。{ko}Mine of Doom: 이 광산에는 여러 색의 크리스털이 있습니다. 모든 퀘스트 적의 각 공격이 +1 됩니다.{es}Mine of Doom: esta mina tiene varios colores de cristal; todos los enemigos de Misión reciben +1 a cada Ataque.{fr}Mine of Doom : cette mine possède plusieurs couleurs de cristal ; tous les ennemis de Quête gagnent +1 à chaque Attaque.{pt-br}Mine of Doom: esta mina tem várias cores de cristal; todos os inimigos da Missão recebem +1 em cada Ataque.{de}Mine of Doom: Diese Mine hat mehrere Kristallfarben; alle Quest-Gegner erhalten +1 auf jeden Angriff.",positionToColor(playerIndex))
	end
	return true
end

function apocalypseQuestLaunchCombat(card,playerIndex,playerColor,chosenColor,clickedEnemyGUID)
	if apocalypseQuestCombatAvailable(card,playerIndex)~=true and chosenColor==nil then return false end
	local state=apocalypseQuestProgressState(card,playerIndex,false)
	if state==nil then return false end
	if card.guid=="ce70fb" and chosenColor~=nil then
		if gStates.apocalypseQuestCombatBranch==nil then gStates.apocalypseQuestCombatBranch={} end
		gStates.apocalypseQuestCombatBranch[card.guid]=chosenColor
	end
	local combatOption=apocalypseQuestCombatOption(card,state)
	if combatOption~=nil then
		local markerRule=apocalypseQuestMarkerRule(card,apocalypseQuestStepNumber(combatOption.key))
		if markerRule~=nil and apocalypseQuestMarkerPlacementCommitted(markerRule)~=true then
			if apocalypseQuestPlaceStepMarker(card,playerIndex,combatOption,playerColor)~=true then return false end
			apocalypseQuestCommitStepMarker(card,combatOption)
		end
	end
	if gStates.apocalypseQuestCombatLaunches==nil then gStates.apocalypseQuestCombatLaunches={} end
	gStates.apocalypseQuestCombatLaunches[card.guid]=apocalypseQuestCombatLaunchKey(card,state)
	local moved=0
	if card.guid=="8939c0" then
		if apocalypseQuestSpawnEnemyToCombat(card,playerIndex,"gray",false,0,0)~=nil then moved=1 end
	elseif card.guid=="8cdac4" or card.guid=="66ea80" then
		if clickedEnemyGUID~=nil then
			local clicked=getObjectFromGUID(clickedEnemyGUID)
			local onCard=false
			for _, enemy in ipairs(apocalypseQuestObjectsOnCard(card)) do if enemy.guid==clickedEnemyGUID then onCard=true break end end
			if clicked~=nil and onCard==true and monsterPugs[clicked.guid]~=nil and apocalypseQuestMoveEnemyToPlayer(card,playerIndex,clicked)==true then moved=1 end
		else
			moved=apocalypseQuestMoveCardEnemiesToPlayer(card,playerIndex,1)
		end
	elseif card.guid=="485cc5" then
		if chosenColor==nil then
			local colors=apocalypseQuestMineDoomColors(playerIndex)
			if #colors==1 then chosenColor=colors[1]
			elseif #colors>1 then chosenColor=gStates.apocalypseQuestMineDoomColor~=nil and gStates.apocalypseQuestMineDoomColor[card.guid] or colors[1] end
		end
		moved=apocalypseQuestLaunchMineDoom(card,playerIndex,chosenColor,#apocalypseQuestMineDoomColors(playerIndex)>1 and 1 or 0) and 1 or 0
	elseif card.guid=="82a935" then
		if apocalypseQuestSpawnEnemyToCombat(card,playerIndex,"purple",false,0,0)~=nil then moved=1 end
	elseif card.guid=="a6d5cc" then
		moved=apocalypseQuestMoveCardEnemiesToPlayer(card,playerIndex,nil)
		if moved>0 then broadcastToAll("{en}Under Siege: ignore fortification for this Quest fight and add Block 5 during the Block phase.{ru}Under Siege: игнорируйте укрепление в этом бою задания и добавьте Блок 5 во время фазы Блока.{zh-tw}Under Siege：此任務戰鬥忽略要塞化，並在格擋階段加入格擋 5。{zh-cn}Under Siege：此任务战斗忽略要塞化，并在格挡阶段加入格挡 5。{ko}Under Siege: 이 퀘스트 전투에서는 요새화를 무시하고 방어 단계에 방어 5를 추가합니다.{es}Under Siege: ignora la fortificación en este combate de Misión y añade Bloqueo 5 durante la fase de Bloqueo.{fr}Under Siege : ignorez la fortification pour ce combat de Quête et ajoutez Blocage 5 pendant la phase de Blocage.{pt-br}Under Siege: ignore fortificação neste combate da Missão e adicione Bloqueio 5 durante a fase de Bloqueio.{de}Under Siege: Ignoriere für diesen Quest-Kampf die Befestigung und füge in der Blockphase Block 5 hinzu.",positionToColor(playerIndex)) end
	elseif card.guid=="8cff07" then
		if apocalypseQuestSpawnEnemyToCombat(card,playerIndex,"gray",false,0,0)~=nil then moved=1 end
	elseif card.guid=="d70436" then
		local level=turnOrder[playerIndex].level or 1
		local pile=level<=4 and "tan" or level<=8 and "white" or "red"
		if apocalypseQuestSpawnEnemyToCombat(card,playerIndex,pile,false,0,0)~=nil then moved=1 end
	elseif card.guid=="c73a1f" then
		moved=apocalypseQuestMoveCardEnemiesToPlayer(card,playerIndex,1)
	elseif card.guid=="ce70fb" then
		local level=turnOrder[playerIndex].level or 1
		local choice=(gStates.apocalypseQuestCombatBranch~=nil and gStates.apocalypseQuestCombatBranch[card.guid]) or "2a"
		local pile=nil
		if choice=="2b" then pile=level<=2 and "gray" or level<=6 and "purple" or "white"
		else pile=level<=4 and "gray" or level<=8 and "purple" or "white" end
		local traitorEnemy=apocalypseQuestSpawnEnemyToCombat(card,playerIndex,pile,true,0,0,"Coun")
		if traitorEnemy~=nil then
			moved=1
			if choice=="2b" then
				if gStates.monsterPerks[traitorEnemy.guid]==nil then gStates.monsterPerks[traitorEnemy.guid]={} end
				gStates.monsterPerks[traitorEnemy.guid].questHalfFame=true
				broadcastToAll("{en}Traitor 2b: this enemy's Fame reward will be halved, rounded up.{ru}Traitor 2b: награда Славы за этого врага уменьшается вдвое с округлением вверх.{zh-tw}Traitor 2b：此敵人的聲望值獎勵減半並向上取整。{zh-cn}Traitor 2b：此敌人的声望值奖励减半并向上取整。{ko}Traitor 2b: 이 적의 명성 보상은 절반으로 줄이고 올림합니다.{es}Traitor 2b: la recompensa de Fama de este enemigo se reduce a la mitad, redondeando hacia arriba.{fr}Traitor 2b : la récompense de Renommée de cet ennemi est divisée par deux, arrondie au supérieur.{pt-br}Traitor 2b: a recompensa de Fama deste inimigo é reduzida pela metade, arredondando para cima.{de}Traitor 2b: Die Ruhmbelohnung dieses Gegners wird halbiert und aufgerundet.",positionToColor(playerIndex))
			end
		end
	elseif card.guid=="dd35bb" then
		broadcastToAll("{en}The Fog: skip the Ranged and Siege Attack phase during this Quest combat.{ru}The Fog: пропустите фазу Дальней и Осадной атаки в этом бою задания.{zh-tw}The Fog：此任務戰鬥跳過遠程與攻城攻擊階段。{zh-cn}The Fog：此任务战斗跳过远程与攻城攻击阶段。{ko}The Fog: 이 퀘스트 전투에서는 원거리 및 공성 공격 단계를 건너뜁니다.{es}The Fog: omite la fase de Ataque a Distancia y de Asedio durante este combate de Misión.{fr}The Fog : ignorez la phase d’Attaque à Distance et de Siège pendant ce combat de Quête.{pt-br}The Fog: pule a fase de Ataque à Distância e de Cerco durante este combate da Missão.{de}The Fog: Überspringe in diesem Quest-Kampf die Fern- und Belagerungsangriffsphase.",positionToColor(playerIndex))
		moved=apocalypseQuestMoveCardEnemiesToPlayer(card,playerIndex,1)
	elseif card.guid=="783076" then
		moved=apocalypseQuestMoveCardEnemiesToPlayer(card,playerIndex,1)
		if moved>0 and apocalypseQuestCardManaColor(card)=="Black" and gStates.dayRound==true then broadcastToAll("{en}Hunter's Moon: during Day, the black mana token removes Swift from the werewolf for this combat.{ru}Hunter's Moon: Днём чёрный жетон маны убирает Быстроту у оборотня на этот бой.{zh-tw}Hunter's Moon：白天時，黑色魔力標記在此戰鬥中移除狼人身上的迅捷。{zh-cn}Hunter's Moon：白天时，黑色魔力标记在此战斗中移除狼人身上的迅捷。{ko}Hunter's Moon: 낮에는 검은 마나 토큰이 이 전투 동안 늑대인간의 신속을 제거합니다.{es}Hunter's Moon: durante el Día, la ficha de maná negra elimina Veloz del hombre lobo para este combate.{fr}Hunter's Moon : pendant le Jour, le jeton de mana noir retire Rapide au loup-garou pour ce combat.{pt-br}Hunter's Moon: durante o Dia, a ficha de mana preta remove Rápido do lobisomem neste combate.{de}Hunter's Moon: Am Tag entfernt der schwarze Manamarker für diesen Kampf Schnell vom Werwolf.",positionToColor(playerIndex)) end
	end
	if moved==0 then
		gStates.apocalypseQuestCombatLaunches[card.guid]=nil
	else
		apocalypseQuestMarkCombatStarted(card,state.step)
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
	for _, offerCard in ipairs(apocalypseQuestOfferCards()) do if offerCard.guid==cardGUID then offered=true break end end
	if offered~=true or apocalypseQuestUsesEnemyAttackButton(card)~=true or apocalypseQuestCombatAvailable(card,playerIndex)~=true then
		apocalypseQuestRefreshEnemyAttackButtons(card,playerIndex)
		return
	end
	--Spell Thief and Fistful move the enemy that was actually clicked. Under Siege deliberately
	--launches both enemies when either Attack icon is clicked, matching its single combat step.
	local clickedGUID=card.guid=="a6d5cc" and nil or enemyGUID
	apocalypseQuestLaunchCombat(card,playerIndex,player.color,nil,clickedGUID)
	if getObjectFromGUID(cardGUID)~=nil then apocalypseQuestInterfaceAdd(card,true) end
end

function apocalypseQuestRestoreBurnedMonastery(card,playerIndex)
	local marker=getObjectFromGUID("81b6f2")
	local map=getObjectFromGUID(mapArea)
	if marker==nil or map==nil then return false end
	local terrain,bearing=terrainHexAtPosition(marker.getPosition(),map.getObjects())
	if terrain==nil or bearing==nil then return false end
	for _, obj in pairs(map.getObjects()) do
		local pos=obj.getPosition()
		local xy=angleToXY(terrain,bearing)
		if ((pos[1]-xy[1])^2)+((pos[3]-xy[2])^2)<1 then
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

function apocalypseQuestAddAdvancedActionToUnitOffer()
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

function apocalypseQuestNobleWarriorFinalReward(card,playerIndex,key)
	local color=apocalypseQuestCardCrystalColor(card)
	if key=="3b" then
		local levelText={Green="level I",White="level I-II",Blue="level I-III",Red="level I-IV"}
		broadcastToAll("Noble Warrior: recruit one "..tostring(levelText[color] or "eligible").." Unit for free.",positionToColor(playerIndex))
	end
end

function apocalypseQuestNobleGoldColors(playerIndex,pending)
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

function apocalypseQuestFinishNobleGold(card,playerIndex)
	if card==nil or turnOrder[playerIndex]==nil then return end
	if gStates.apocalypseQuestCombatChoice~=nil then gStates.apocalypseQuestCombatChoice[card.guid]=nil end
	apocalypseQuestClearRewardCompletionGate(card,playerIndex)
	broadcastToAll(tostring(turnOrder[playerIndex].mage).." completed Noble Warrior (3A).",positionToColor(playerIndex))
	apocalypseQuestFinishCompletedCard(card)
	safeWaitTime("Quests",function() rewindTransactionFinish("Quest resolve "..tostring(card.guid).." "..tostring(playerIndex)) end,0.5)
end

function apocalypseQuestFinishGuardDutyChoice(card,playerIndex,distance)
	if card==nil or turnOrder[playerIndex]==nil then return end
	if gStates.apocalypseQuestCombatChoice~=nil then gStates.apocalypseQuestCombatChoice[card.guid]=nil end
	apocalypseQuestClearRewardCompletionGate(card,playerIndex)
	broadcastToAll(tostring(turnOrder[playerIndex].mage).." completed Guard Duty: distance "..tostring(distance or "?")..", two chosen mana crystals.",positionToColor(playerIndex))
	apocalypseQuestFinishCompletedCard(card)
	safeWaitTime("Quests",function() rewindTransactionFinish("Quest resolve "..tostring(card.guid).." "..tostring(playerIndex)) end,0.5)
end

function apocalypseQuestFinishGuardDutyGold(card,playerIndex,distance)
	if card==nil or turnOrder[playerIndex]==nil then return end
	if gStates.apocalypseQuestCombatChoice~=nil then gStates.apocalypseQuestCombatChoice[card.guid]=nil end
	apocalypseQuestClearRewardCompletionGate(card,playerIndex)
	broadcastToAll(tostring(turnOrder[playerIndex].mage).." completed Guard Duty: distance "..tostring(distance or "?")..", random mana reward resolved.",positionToColor(playerIndex))
	apocalypseQuestFinishCompletedCard(card)
	safeWaitTime("Quests",function() rewindTransactionFinish("Quest resolve "..tostring(card.guid).." "..tostring(playerIndex)) end,0.5)
end

function apocalypseQuestNobleWarriorRollReward(card,playerIndex,callback)
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
	local offsets=count==1 and {{0,1.25}} or count==2 and {{-1.05,1.25},{1.05,1.25}} or
		count==3 and {{-1.05,0.55},{1.05,0.55},{0,1.95}} or
		{{-1.05,0.55},{1.05,0.55},{-1.05,1.95},{1.05,1.95}}
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
	apocalypseQuestInterfaceRemove(card)
	broadcastToAll("Noble Warrior is rolling "..tostring(count).." random crystal "..(count==1 and "die." or "dice."),positionToColor(playerIndex))

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

function apocalypseQuestUnderSiegeFailure(card,playerIndex)
	local marker=getObjectFromGUID("4c5f97")
	if marker==nil then return end
	local pos=marker.getPosition()
	local map=getObjectFromGUID(mapArea)
	if map~=nil then
		for _, obj in pairs(map.getObjects()) do
			if obj.getName()=="Shield" and volkarePursuitShieldRegistered(obj)~=true and turnOrder[playerIndex]~=nil and obj.getDescription()==turnOrder[playerIndex].mage then
				local p=obj.getPosition()
				if ((p[1]-pos[1])^2)+((p[3]-pos[3])^2)<1 then obj.destruct() break end
			end
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

--Mine of Doom is unusual: an unsuccessful attempt still discards its undefeated enemies instead of
--returning them to a map site. Remove those face-down survivors during normal pre-end-turn cleanup so
--the board is already clear when the Rewards Claimed stage appears. Defeated face-up enemies remain
--for the standard combat cleanup so their normal Fame/reward processing is preserved.
function apocalypseQuestMineDoomUndefeatedCleanup(playerIndex)
	if gStates.apocalypseQuestCombatEnemies==nil or gStates.apocalypseQuestCombatEnemies["485cc5"]==nil then return false end
	local discardByType={gray=GUID.bag.discard.keepGarrison,purple=GUID.bag.discard.towerGarrison,white=GUID.bag.discard.cityGarrison,red=GUID.bag.discard.draconum,green=GUID.bag.discard.orcs,tan=GUID.bag.discard.dungeon}
	local possessedDiscard=getObjectFromGUID(GUID.bag.discard.possessed)
	local removed=false
	for guid,_ in pairs(gStates.apocalypseQuestCombatEnemies["485cc5"]) do
		local enemy=getObjectFromGUID(guid)
		if enemy~=nil and enemy.is_face_down==true then
			local detached=clearPossessedEnemy(enemy)
			for _, token in pairs(detached or {}) do if possessedDiscard~=nil then possessedDiscard.putObject(token) else token.destruct() end end
			local kind=monsterPugs[guid]~=nil and monsterPugs[guid].pugType or nil
			local discard=kind~=nil and discardByType[kind]~=nil and getObjectFromGUID(discardByType[kind]) or nil
			if discard~=nil then enemy.unlock() discard.putObject(enemy) end
			if gStates.attackedMonsters~=nil then gStates.attackedMonsters[guid]=nil end
			if gStates.monsterPlayLocation~=nil then gStates.monsterPlayLocation[guid]=nil end
			removed=true
		end
	end
	if removed==true then broadcastToAll("Mine of Doom: undefeated Quest enemies were discarded at the end of the attempt.",positionToColor(playerIndex)) end
	return removed
end

function apocalypseQuestMineDoomEndTurnCleanup(playerIndex)
	if gStates.apocalypseQuestCombatEnemies==nil or gStates.apocalypseQuestCombatEnemies["485cc5"]==nil then return false end
	local discardByType={gray=GUID.bag.discard.keepGarrison,purple=GUID.bag.discard.towerGarrison,white=GUID.bag.discard.cityGarrison,red=GUID.bag.discard.draconum,green=GUID.bag.discard.orcs,tan=GUID.bag.discard.dungeon}
	local removed=false
	for guid,_ in pairs(gStates.apocalypseQuestCombatEnemies["485cc5"]) do
		local enemy=getObjectFromGUID(guid)
		if enemy~=nil then
			local detached=clearPossessedEnemy(enemy)
			local possessedDiscard=getObjectFromGUID(GUID.bag.discard.possessed)
			for _, token in pairs(detached or {}) do if possessedDiscard~=nil then possessedDiscard.putObject(token) else token.destruct() end end
			local kind=monsterPugs[guid]~=nil and monsterPugs[guid].pugType or nil
			local discard=kind~=nil and discardByType[kind]~=nil and getObjectFromGUID(discardByType[kind]) or nil
			if discard~=nil then enemy.unlock() discard.putObject(enemy) end
			removed=true
		end
		if gStates.attackedMonsters~=nil then gStates.attackedMonsters[guid]=nil end
		if gStates.monsterPlayLocation~=nil then gStates.monsterPlayLocation[guid]=nil end
	end
	gStates.apocalypseQuestCombatEnemies["485cc5"]=nil
	gStates.apocalypseQuestCombatLaunches["485cc5"]=nil
	if removed==true then broadcastToAll("Mine of Doom: remaining Quest combat enemy tokens were discarded.",positionToColor(playerIndex)) end
	return true
end

function apocalypseQuestResolveFailureEffect(card,playerIndex,option)
	if card==nil or option==nil then return end
	if card.guid=="a6d5cc" and tostring(option.key)=="2b" then apocalypseQuestUnderSiegeFailure(card,playerIndex) end
end

function apocalypseQuestRichMerchantStartTurn()
	local card=getObjectFromGUID("8cff07")
	local playerIndex=gStates.turnNumber
	if card==nil or turnOrder[playerIndex]==nil then return false end
	local record=gStates.apocalypseQuestRichMerchantHidden~=nil and gStates.apocalypseQuestRichMerchantHidden[card.guid] or nil
	if record==nil or record.mage~=turnOrder[playerIndex].mage or record.spawned==true then return false end
	local state=apocalypseQuestProgressState(card,playerIndex,false)
	if state==nil or state.step~=2 then return false end
	local enemy=apocalypseQuestSpawnEnemyToCombat(card,playerIndex,"gray",false,0,0)
	if enemy==nil then return false end
	record.spawned=true
	apocalypseQuestMarkCombatStarted(card,2)
	if gStates.apocalypseQuestCombatLaunches==nil then gStates.apocalypseQuestCombatLaunches={} end
	gStates.apocalypseQuestCombatLaunches[card.guid]=apocalypseQuestCombatLaunchKey(card,state)
	broadcastToAll("A Rich Merchant: the hidden ally attacks at the start of "..tostring(turnOrder[playerIndex].mage).."'s turn.",positionToColor(playerIndex))
	safeWaitFrames("Quests",function() if getObjectFromGUID(card.guid)~=nil then apocalypseQuestInterfaceAdd(card,true) end end,2)
	return true
end

function apocalypseQuestResolveSpecialEffect(card, playerIndex, option, finalCompletion)
	if card==nil or option==nil or turnOrder[playerIndex]==nil then return end
	local key=tostring(option.key)
	if card.guid=="8939c0" then
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
	elseif card.guid=="58a826" then
		if key=="2" then
			local hex=apocalypseQuestCurrentPlayerHex(playerIndex)
			local terrainColor=hex~=nil and ({plains="White",forest="Green",wasteland="Red",swamp="Blue"})[hex.hexType] or nil
			if terrainColor~=nil then apocalypseQuestPlaceCrystalOnCard(card,terrainColor,0,-0.55,"The Eager Herbalist") end
		end
	elseif card.guid=="734740" and key=="3" then
		apocalypseQuestGiveProveYourselfReward(card,playerIndex)
	elseif card.guid=="72099f" then
		if key=="1" and turnOrder[playerIndex]~=nil and gStates.apocalypseQuestGoblinWarrens~=nil then
			gStates.apocalypseQuestGoblinWarrens[turnOrder[playerIndex].mage]=nil
		elseif key=="2" and finalCompletion==true then
			apocalypseQuestFlipSiteToken("02f996")
		end
	elseif card.guid=="8cdac4" then
		if key=="2" then
			local level=turnOrder[playerIndex].level or 1
			apocalypseQuestPlaceEnemy(card,level<=3 and "gray" or level<=6 and "purple" or "white",true,0)
		elseif key=="3" then
			apocalypseQuestGiveTuckedCard(playerIndex,card,"Spell")
		end
	elseif card.guid=="66ea80" and key=="1" then
		--Fistful's two gray enemies are placed after the Quest offer finishes moving. Drawing both from the
		--same bag while the card is also relocating can lose a spawn/attachment race in TTS.
		return
	elseif card.guid=="37e2ce" and key=="1a" then
		apocalypseQuestFreeWineStartAssault(card,playerIndex)
	elseif card.guid=="485cc5" and key=="1" then
		local color=gStates.apocalypseQuestStepColor~=nil and gStates.apocalypseQuestStepColor[card.guid] or nil
		local colors=apocalypseQuestMineDoomColors(playerIndex)
		if color~=nil then
			if gStates.apocalypseQuestMineDoomColor==nil then gStates.apocalypseQuestMineDoomColor={} end
			gStates.apocalypseQuestMineDoomColor[card.guid]=color
			local launched=apocalypseQuestLaunchMineDoom(card,playerIndex,color,#colors>1 and 1 or 0)
			if launched==true then apocalypseQuestMarkCombatStarted(card,2) end
		end
	elseif card.guid=="485cc5" and key=="2" and finalCompletion==true then
		broadcastToAll("{en}Mine of Doom reward: gain an Artifact.{ru}Награда Mine of Doom: получите Артефакт.{zh-tw}Mine of Doom 獎勵：獲得一件神器。{zh-cn}Mine of Doom 奖励：获得一件神器。{ko}Mine of Doom 보상: 유물 하나를 얻습니다.{es}Recompensa de Mine of Doom: gana un Artefacto.{fr}Récompense de Mine of Doom : gagnez un Artefact.{pt-br}Recompensa de Mine of Doom: ganhe um Artefato.{de}Belohnung für Mine of Doom: Erhalte ein Artefakt.",positionToColor(playerIndex))
	elseif card.guid=="b401dc" then
		if key=="1" then
			local token=getObjectFromGUID("7e4e4c")
			if token~=nil then apocalypseQuestHighlightMarker(token) end
			broadcastToAll("{en}A Very Personal Quest: recruit an eligible Unit here for free and place the highlighted Quest token on that Unit.{ru}A Very Personal Quest: бесплатно наймите здесь подходящий отряд и поместите выделенный жетон задания на этот отряд.{zh-tw}A Very Personal Quest：在此免費招募符合條件的部隊，並將高亮任務標記放在該部隊上。{zh-cn}A Very Personal Quest：在此免费招募符合条件的部队，并将高亮任务标记放在该部队上。{ko}A Very Personal Quest: 여기서 조건에 맞는 유닛 하나를 무료로 모집하고 강조된 퀘스트 토큰을 그 유닛 위에 놓으십시오.{es}A Very Personal Quest: recluta aquí gratis una Unidad válida y coloca la ficha de Misión resaltada sobre esa Unidad.{fr}A Very Personal Quest : recrutez gratuitement ici une Unité éligible et placez le jeton de Quête surligné sur cette Unité.{pt-br}A Very Personal Quest: recrute aqui gratuitamente uma Unidade elegível e coloque a ficha de Missão destacada nessa Unidade.{de}A Very Personal Quest: Rekrutiere hier kostenlos eine geeignete Einheit und lege den hervorgehobenen Questmarker auf diese Einheit.",positionToColor(playerIndex))
		elseif key=="2" then
			if gStates.apocalypseQuestVeryPersonalSuccess==nil then gStates.apocalypseQuestVeryPersonalSuccess={} end
			gStates.apocalypseQuestVeryPersonalSuccess[card.guid]=true
			broadcastToAll("{en}A Very Personal Quest: the protected Unit survived the Mage Tower rescue; its Quest marker will be returned.{ru}A Very Personal Quest: защищаемый отряд пережил спасение Башни мага; его жетон задания будет возвращён.{zh-tw}A Very Personal Quest：受保護部隊在法師塔救援中存活；其任務標記將被歸還。{zh-cn}A Very Personal Quest：受保护部队在法师塔救援中存活；其任务标记将被归还。{ko}A Very Personal Quest: 보호 대상 유닛이 마법사 탑 구출에서 살아남았습니다. 퀘스트 토큰을 반환합니다.{es}A Very Personal Quest: la Unidad protegida sobrevivió al rescate de la Torre de Mago; se devolverá su ficha de Misión.{fr}A Very Personal Quest : l’Unité protégée a survécu au sauvetage de la Tour de Mage ; son jeton de Quête sera rendu.{pt-br}A Very Personal Quest: a Unidade protegida sobreviveu ao resgate da Torre de Mago; sua ficha de Missão será devolvida.{de}A Very Personal Quest: Die geschützte Einheit hat die Rettung am Magierturm überlebt; ihr Questmarker wird zurückgegeben.",positionToColor(playerIndex))
		end
	elseif card.guid=="82a935" and key=="2a" then
		apocalypseQuestRestoreBurnedMonastery(card,playerIndex)
		apocalypseQuestAddAdvancedActionToUnitOffer()
		apocalypseQuestGainReputation(playerIndex,"The Burned Monastery")
	elseif card.guid=="8455b5" then
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
	elseif card.guid=="abd4fb" then
		if key=="1" then
			if gStates.apocalypseQuestCursedHero==nil then gStates.apocalypseQuestCursedHero={} end
			apocalypseQuestCursedMarkHolder(card,playerIndex)
			gStates.apocalypseQuestCursedHero[card.guid]=turnOrder[playerIndex].mage
			broadcastToAll(tostring(turnOrder[playerIndex].mage).." is now the cursed Hero. Apply +1 Armor and +1 to each enemy attack manually while this Quest remains active.",positionToColor(playerIndex))
		elseif key=="2a" then
			local targetIndex=apocalypseQuestCursedTargetIndex(card,playerIndex)
			if targetIndex==nil then
				local eligible=apocalypseQuestCursedEligibleTargets(card,playerIndex)
				if #eligible==1 then targetIndex=eligible[1] end
			end
			if targetIndex~=nil and turnOrder[targetIndex]~=nil and apocalypseQuestCursedAutoShield(card,playerIndex,targetIndex)==true then
				local targetState=apocalypseQuestProgressState(card,targetIndex,true)
				if targetState~=nil then targetState.step=2 end
				apocalypseQuestCursedMarkHolder(card,targetIndex)
				gStates.apocalypseQuestCursedHero[card.guid]=turnOrder[targetIndex].mage
				broadcastToAll(tostring(turnOrder[targetIndex].mage).." is now the cursed Hero. The enemy +1 Armor/+1 Attack effect remains player-managed.",positionToColor(targetIndex))
			else
				broadcastToAll("{en}Cursed: place the chosen adjacent Hero's Shield on this Quest before using Pass the curse on.{ru}Cursed: поместите щит выбранного соседнего Героя на это задание перед использованием Pass the curse on.{zh-tw}Cursed：使用 Pass the curse on 前，先將所選相鄰英雄的盾牌放到此任務上。{zh-cn}Cursed：使用 Pass the curse on 前，先将所选相邻英雄的盾牌放到此任务上。{ko}Cursed: Pass the curse on을 사용하기 전에 선택한 인접 영웅의 방패를 이 퀘스트에 놓으십시오.{es}Cursed: coloca el Escudo del Héroe adyacente elegido sobre esta Misión antes de usar Pass the curse on.{fr}Cursed : placez le Bouclier du Héros adjacent choisi sur cette Quête avant d’utiliser Pass the curse on.{pt-br}Cursed: coloque o Escudo do Herói adjacente escolhido nesta Missão antes de usar Pass the curse on.{de}Cursed: Lege den Schild des gewählten benachbarten Helden auf diese Quest, bevor du Pass the curse on verwendest.",positionToColor(playerIndex))
			end
		elseif key=="2b" then
			apocalypseQuestGainReputation(playerIndex,"Cursed")
			if gStates.apocalypseQuestCursedHero~=nil then gStates.apocalypseQuestCursedHero[card.guid]=nil end
		end
	elseif card.guid=="d70436" then
		if key=="2" then
			local level=turnOrder[playerIndex].level or 1
			local pile=level<=4 and "tan" or level<=8 and "white" or "red"
			if apocalypseQuestSpawnEnemyToCombat(card,playerIndex,pile,false,0,0)~=nil then
				apocalypseQuestMarkCombatStarted(card,3)
				local shield=apocalypseQuestPlayerShield(card,playerIndex)
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
			broadcastToAll("A Mysterious Island reward: gain "..reward..".",positionToColor(playerIndex))
		end
	elseif card.guid=="c73a1f" and key=="3" and finalCompletion==true then
		broadcastToAll("{en}Tomb of the Lost King reward: gain an Artifact.{ru}Награда Tomb of the Lost King: получите Артефакт.{zh-tw}Tomb of the Lost King 獎勵：獲得一件神器。{zh-cn}Tomb of the Lost King 奖励：获得一件神器。{ko}Tomb of the Lost King 보상: 유물 하나를 얻습니다.{es}Recompensa de Tomb of the Lost King: gana un Artefacto.{fr}Récompense de Tomb of the Lost King : gagnez un Artefact.{pt-br}Recompensa de Tomb of the Lost King: ganhe um Artefato.{de}Belohnung für Tomb of the Lost King: Erhalte ein Artefakt.",positionToColor(playerIndex))
	elseif card.guid=="77bbac" and key=="2" then
		broadcastToAll("{en}The Child Seer: resolve the destiny matching the mana token on your Shield (or pay matching mana to choose another destiny).{ru}The Child Seer: разрешите судьбу, соответствующую жетону маны на вашем Щите (или заплатите совпадающую ману, чтобы выбрать другую судьбу).{zh-tw}The Child Seer：結算與你盾牌上魔力標記相符的命運（或支付相符魔力以選擇另一個命運）。{zh-cn}The Child Seer：结算与你盾牌上魔力标记相符的命运（或支付相符魔力以选择另一个命运）。{ko}The Child Seer: 방패 위의 마나 토큰과 일치하는 운명을 해결하십시오(또는 일치하는 마나를 지불해 다른 운명을 선택하십시오).{es}The Child Seer: resuelve el destino que coincida con la ficha de maná de tu Escudo (o paga maná coincidente para elegir otro destino).{fr}The Child Seer : résolvez le destin correspondant au jeton de mana sur votre Bouclier (ou payez le mana correspondant pour choisir un autre destin).{pt-br}The Child Seer: resolva o destino correspondente à ficha de mana em seu Escudo (ou pague mana correspondente para escolher outro destino).{de}The Child Seer: Führe das Schicksal aus, das dem Manamarker auf deinem Schild entspricht (oder zahle passendes Mana, um ein anderes Schicksal zu wählen).",positionToColor(playerIndex))
	elseif card.guid=="8cff07" and key=="1" and finalCompletion~=true then
		--A Rich Merchant Step 1 is resolved by the visible physical mana-die path in ResolveStepAction.
		return
	elseif card.guid=="082f39" and key=="1" then
		apocalypseQuestTravellingMerchantRelocate(card,playerIndex)
	elseif card.guid=="ce70fb" and apocalypseQuestStepNumber(key)==2 then
		local level=turnOrder[playerIndex].level or 1
		local reward=nil
		if key=="2a" then reward=level<=4 and "a random mana crystal" or level<=8 and "an Advanced Action" or "a Spell"
		else reward=level<=2 and "an Advanced Action" or level<=6 and "a Spell" or "an Artifact" end
		broadcastToAll("Traitor "..key.." reward: gain "..reward..". The generated Possessed enemy is Council of the Void faction.",positionToColor(playerIndex))
	elseif card.guid=="dd35bb" then
		if key=="1" then
			if apocalypseQuestFogEnemy(card)==nil then apocalypseQuestPlaceEnemy(card,"tan",true,0) end
		elseif key=="2" then
			local enemy=apocalypseQuestFogEnemy(card)
			if enemy~=nil and apocalypseQuestFogPossessedReady(card)~=true then apocalypseQuestPossessExistingEnemy(card,enemy,"Apoc") end
		elseif key=="3" and finalCompletion==true then
			broadcastToAll("{en}The Fog reward: gain an Artifact.{ru}Награда The Fog: получите Артефакт.{zh-tw}The Fog 獎勵：獲得一件神器。{zh-cn}The Fog 奖励：获得一件神器。{ko}The Fog 보상: 유물 하나를 얻습니다.{es}Recompensa de The Fog: gana un Artefacto.{fr}Récompense de The Fog : gagnez un Artefact.{pt-br}Recompensa de The Fog: ganhe um Artefato.{de}Belohnung für The Fog: Erhalte ein Artefakt.",positionToColor(playerIndex))
		end
	elseif card.guid=="783076" and key=="2" and finalCompletion==true then
		broadcastToAll("{en}Hunter's Moon reward: gain an Artifact.{ru}Награда Hunter's Moon: получите Артефакт.{zh-tw}Hunter's Moon 獎勵：獲得一件神器。{zh-cn}Hunter's Moon 奖励：获得一件神器。{ko}Hunter's Moon 보상: 유물 하나를 얻습니다.{es}Recompensa de Hunter's Moon: gana un Artefacto.{fr}Récompense de Hunter's Moon : gagnez un Artefact.{pt-br}Recompensa de Hunter's Moon: ganhe um Artefato.{de}Belohnung für Hunter's Moon: Erhalte ein Artefakt.",positionToColor(playerIndex))
	elseif card.guid=="a6d5cc" and key=="1" then
		gStates.apocalypseQuestUnderSiegeReady=nil
		gStates.apocalypseQuestUnderSiegeStep2={player=playerIndex,mage=turnOrder[playerIndex].mage,serial=gStates.apocalypseQuestTurnSerial or 0,movedSerial=nil}
		apocalypseQuestPlaceEnemy(card,"gray",true,-0.45)
		apocalypseQuestPlaceEnemy(card,"purple",true,0.45)
	elseif card.guid=="bbd087" then
		if key=="1" then
			broadcastToAll("{en}Noble Warrior: the companion Quest marker is now at this site.{ru}Noble Warrior: сопровождающий жетон задания теперь находится в этом месте.{zh-tw}Noble Warrior：同伴任務標記現在位於此地點。{zh-cn}Noble Warrior：同伴任务标记现在位于此地点。{ko}Noble Warrior: 동료 퀘스트 마커가 이제 이 장소에 있습니다.{es}Noble Warrior: la ficha de Misión compañera está ahora en este lugar.{fr}Noble Warrior : le marqueur de Quête compagnon se trouve maintenant sur ce site.{pt-br}Noble Warrior: o marcador de Missão companheiro agora está neste local.{de}Noble Warrior: Der begleitende Questmarker befindet sich jetzt an diesem Ort.",positionToColor(playerIndex))
		elseif key=="3a" or key=="3b" then
			apocalypseQuestNobleWarriorFinalReward(card,playerIndex,key)
		end
	elseif card.guid=="c73a1f" and key=="2" and apocalypseQuestCardHasEnemyType(card,"white")~=true then
		apocalypseQuestPlaceEnemy(card,"white",false,0)
	elseif card.guid=="77bbac" and key=="1" then
		apocalypseQuestPlaceRandomCrystalOnShield(card,playerIndex)
	elseif card.guid=="c5dec8" and key=="3" then
		apocalypseQuestGiveQuestTokenToInventory(playerIndex,"186613","Stray")
	elseif card.guid=="3009b4" then
		local tokens={["1"]="adc752",["2"]="c92844",["3"]="0143e0",["4"]="7a56a0"}
		if tokens[key]~=nil then apocalypseQuestGiveQuestTokenToInventory(playerIndex,tokens[key],"Ill Omens") end
	elseif card.guid=="6175e8" and key=="3" then
		apocalypseQuestMagicOverloadPlaceSite(card,playerIndex)
	elseif card.guid=="00a4fe" and key=="2" then
		apocalypseQuestGiveQuestTokenToInventory(playerIndex,"3c89b8","Misadventure")
	elseif card.guid=="bb2828" and key=="2" then
		local color=gStates.apocalypseQuestStepColor~=nil and gStates.apocalypseQuestStepColor[card.guid] or nil
		if color~=nil then apocalypseQuestPlaceCrystalOnCard(card,color,0,-0.55,"The Artificer") end
	elseif card.guid=="bb2828" and key=="3" then
		--The three Step 2 crystals are temporary progress markers. The Artificer keeps its Quest card
		--as a reminder after completion, so normal bottom-deck cleanup never gets a chance to remove them.
		for _,obj in ipairs(apocalypseQuestObjectsOnCard(card)) do
			if apocalypseQuestBasicCrystalColor(obj)~=nil then obj.destruct() end
		end
		apocalypseQuestGiveQuestTokenToInventory(playerIndex,"cd8313","The Artificer")
	elseif card.guid=="783076" and key=="1b" then
		apocalypseQuestLoseReputation(playerIndex,"Hunter's Moon","effect")
		apocalypseQuestPlaceCrystalOnCard(card,"Black",0.70,-0.65,"Hunter's Moon")
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
	local cards=apocalypseQuestOfferCards()
	if #cards==0 then return false end
	local removeCount=math.min(2,#cards)
	local firstRemoved=#cards-removeCount+1
	local queue={}
	for i=firstRemoved,#cards do if cards[i]~=nil then queue[#queue+1]=cards[i] end end
	broadcastToAll("Quest cleanup started: removing the "..tostring(#queue).." rightmost Quest"..(#queue==1 and "" or "s").." from the offer.",{1,1,0.5})

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
		broadcastToAll("Quest cleanup: \""..questName.."\" ("..tostring(questDetails.questType or "Unknown")..") is leaving the offer.",{1,1,0.5})
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
		apocalypseQuestBottomDeck(card,function(success)
			if shieldCount>0 then broadcastToAll("Quest cleanup: removed "..tostring(shieldCount).." Shield"..(shieldCount==1 and "" or "s").." from \""..questName.."\".",{1,1,0.5}) end
			if gStates.apocalypseQuestReminderCards~=nil and gStates.apocalypseQuestReminderCards[card.guid]~=nil then
				broadcastToAll("Quest cleanup: \""..questName.."\" remains beside the Quest Shield bags as a reminder.",{1,1,0.5})
			elseif success==true then
				broadcastToAll("Quest cleanup: \""..questName.."\" returned to the bottom of the Quest deck.",{1,1,0.5})
			else
				broadcastToAll("Quest cleanup: \""..questName.."\" could not be returned to the Quest deck.",{1,0.2,0.2})
			end
			--Only now may the next retiring Quest begin its deck return. This prevents the two loose
			--cards from combining with each other and becoming a stray two-card deck beside the real deck.
			safeWaitFrames("Quests",function() cleanNext(index+1) end,1)
		end)
	end
	cleanNext(1)
	return true
end
function apocalypseQuestOfferTarget()
	if gStates.playerCount==1 then return 4 end
	return (gStates.playerCount or 0)+2
end
function apocalypseQuestScorePosition(score, seatPos)
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
				safeTakeObject("Quests",apocalypseBag,{guid=marker.guid, position=apocalypseQuestScorePosition(0, seatPos), rotation={0, 180, 0}, smooth=false, callback_function=function(obj)
					if obj==nil then return end
					--If another player's marker was deleted while setup callbacks were still resolving, honor that choice.
					if gStates.apocalypseQuestScoringDisabled==true and apocalypseQuestScoresRequired()~=true then obj.destruct() return end
					obj.setPosition(apocalypseQuestScorePosition(0, seatPos))
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
function apocalypseQuestAreaZone()
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
function apocalypseQuestAreaObjects()
	local zone=apocalypseQuestAreaZone()
	if zone==nil then return {} end
	local ok,objects=pcall(function() return zone.getObjects() end)
	return ok==true and objects or {}
end
function apocalypseQuestOfferPosition(slot)
	return {46.84+(4.20*slot), 1.08, 8.06}
end
function apocalypseQuestCardInOffer(questGUID)
	if questGUID==nil or apocalypseQuestsUsed()~=true then return false end
	local card=getObjectFromGUID(questGUID)
	if card==nil or card.type~="Card" then return false end
	local first=apocalypseQuestOfferPosition(1)
	local last=apocalypseQuestOfferPosition(6)
	local pos=card.getPosition()
	return pos[1]>first[1]-1.8 and pos[1]<last[1]+1.8 and math.abs(pos[3]-first[3])<2.6
end
function apocalypseQuestVillagePlunderBlocked(playerIndex)
	--A Fistful of Crystals protects only the Village carrying its 9.x Quest marker, not every Village.
	if apocalypseQuestCardInOffer("66ea80")~=true then return false end
	local marker=getObjectFromGUID("14e54b")
	local avatar=coopAssaultAvatarObject(playerIndex)
	if marker==nil or avatar==nil then return false end
	local markerTerrain, markerBearing=terrainHexAtPosition(marker.getPosition())
	if markerTerrain==nil or markerBearing==nil then return false end
	local avatarTerrain, avatarBearing=terrainHexAtPosition(avatar.getPosition())
	return avatarTerrain~=nil and avatarTerrain.guid==markerTerrain.guid and avatarBearing==markerBearing
end
function apocalypseQuestInterfaceRemove(card)
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
function apocalypseQuestStepNumber(key)
	return tonumber(tostring(key or ""):match("^(%d+)"))
end
function apocalypseQuestNextStepNumber(quest, currentStep)
	if quest==nil then return nil end
	local nextStep=nil
	for _, option in ipairs(quest.steps or {}) do
		local number=apocalypseQuestStepNumber(option.key)
		if number~=nil and number>currentStep and (nextStep==nil or number<nextStep) then nextStep=number end
	end
	return nextStep
end
function apocalypseQuestProgressState(card, playerIndex, create)
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
function apocalypseQuestProgressCount(card, playerIndex)
	playerIndex=playerIndex or gStates.turnNumber
	local state=apocalypseQuestProgressState(card, playerIndex, false)
	if state==nil then return 0 end
	return math.max(0, (state.step or 1)-1)
end
function apocalypseQuestProgressFixed(card)
	return card~=nil and apocalypseQuestData[card.guid]~=nil
end
function apocalypseQuestPersonalShieldOwner(card)
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
function apocalypseQuestNeutralShield(card)
	if card==nil then return nil end
	for _, obj in ipairs(apocalypseQuestObjectsOnCard(card)) do
		if obj.getName()=="Shield" and obj.getDescription()=="Neutral" then return obj end
	end
	return nil
end
function apocalypseQuestPlayerShield(card, playerIndex)
	if card==nil or turnOrder[playerIndex]==nil then return nil end
	local mage=turnOrder[playerIndex].mage
	for _, obj in ipairs(apocalypseQuestObjectsOnCard(card)) do
		if obj.getName()=="Shield" and obj.getDescription()==mage then return obj end
	end
	return nil
end

function apocalypseQuestGoblinWarrensAllPlayerShields(card)
	if card==nil or card.guid~="72099f" then return false end
	local active=0
	for playerIndex,details in ipairs(turnOrder or {}) do
		if details.mage~=nil and details.mage~="nobody" and details.mage~=gStates.positionMageKnight[5] and details.dropoutState==nil then
			active=active+1
			if apocalypseQuestPlayerShield(card,playerIndex)==nil then return false end
		end
	end
	return active>0
end

function apocalypseQuestGoblinWarrensRemoveBagIfReady(card)
	if apocalypseQuestGoblinWarrensAllPlayerShields(card)~=true then return false end
	local bag=getObjectFromGUID("f021d8")
	if bag~=nil then bag.destruct() end
	return true
end
function apocalypseQuestPlayerHasOtherPersonalQuest(playerIndex, excludeGUID)
	if turnOrder[playerIndex]==nil then return false end
	local mage=turnOrder[playerIndex].mage
	for _, questCard in ipairs(apocalypseQuestOfferCards()) do
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
function apocalypseQuestPlayerBurnedMonastery(playerIndex)
	local details=turnOrder[playerIndex]
	if details==nil or gStates.monasteryBurnedBy==nil then return false end
	for _, mage in pairs(gStates.monasteryBurnedBy) do
		if mage==details.mage then return true end
	end
	return false
end


function apocalypseQuestMarkerRule(card, stepNumber)
	if card==nil then return nil end
	local rules=apocalypseQuestMarkerPlacementRules[card.guid]
	if rules==nil then return nil end
	return rules[tostring(stepNumber)]
end

function apocalypseQuestMarkerObject(rule)
	if rule==nil then return nil end
	for _, guid in ipairs(rule.tokens or {}) do
		local token=getObjectFromGUID(guid)
		if token~=nil then return token end
	end
	return nil
end

function apocalypseQuestMapHexKey(hex)
	if hex==nil then return nil end
	return tostring(hex.terrainGUID).."|"..tostring(hex.bearing)
end

function apocalypseQuestMapHexes()
	local refreshCache=apocalypseQuestRefreshMapCache or {}
	if refreshCache~=nil and refreshCache.hexes~=nil and refreshCache.mapObjects~=nil then return refreshCache.hexes,refreshCache.mapObjects end
	local map=getObjectFromGUID(mapArea)
	if map==nil then return {}, {} end
	local objects=refreshCache~=nil and refreshCache.mapObjects or nil
	if objects==nil then objects=map.getObjects() end
	local hexes={}
	local bearings={"center","0","60","120","180","240","300"}
	for _, terrain in pairs(objects) do
		local details=terrainTiles[terrain.guid]
		if details~=nil and details.hexType~=nil and details.hexFeature~=nil and terrain.is_face_down~=true and details.tileType~="tilePile" then
			for _, bearing in ipairs(bearings) do
				local hexType=details.hexType[bearing]
				if hexType~=nil and hexType~="" and hexType~="ocean" then
					local xy=angleToXY(terrain,bearing)
					hexes[#hexes+1]={
						terrain=terrain, terrainGUID=terrain.guid, bearing=bearing,
						position={xy[1],1.30,xy[2]}, hexType=hexType,
						feature=details.hexFeature[bearing] or ""
					}
				end
			end
		end
	end
	if refreshCache~=nil then refreshCache.mapObjects=objects refreshCache.hexes=hexes end
	return hexes, objects
end

function apocalypseQuestHexesAdjacent(a,b)
	if a==nil or b==nil then return false end
	local dx=a.position[1]-b.position[1]
	local dz=a.position[3]-b.position[3]
	local distanceSquared=(dx*dx)+(dz*dz)
	return distanceSquared>4.2 and distanceSquared<7.4
end

function apocalypseQuestHexDistanceMap(hexes, starts)
	local distances={}
	local queue={}
	for _, startHex in ipairs(starts or {}) do
		local key=apocalypseQuestMapHexKey(startHex)
		if key~=nil and distances[key]==nil then
			distances[key]=0
			queue[#queue+1]=startHex
		end
	end
	local head=1
	while queue[head]~=nil do
		local current=queue[head]
		head=head+1
		local currentDistance=distances[apocalypseQuestMapHexKey(current)] or 0
		for _, candidate in ipairs(hexes or {}) do
			local key=apocalypseQuestMapHexKey(candidate)
			if key~=nil and distances[key]==nil and apocalypseQuestHexesAdjacent(current,candidate)==true then
				distances[key]=currentDistance+1
				queue[#queue+1]=candidate
			end
		end
	end
	return distances
end

--Guard Duty measures the shortest connection between the merchant marker's pickup site and the
--Mage Knight's current drop-off site using revealed map spaces only. apocalypseQuestMapHexes()
--already omits unrevealed terrain, so a BFS over its adjacency graph matches the printed wording.
function apocalypseQuestGuardDutyDistance(playerIndex)
	local marker=getObjectFromGUID("518afd")
	if marker==nil then return nil end
	local hexes,mapObjects=apocalypseQuestMapHexes()
	local markerHex=apocalypseQuestHexForPosition(hexes,marker.getPosition(),mapObjects)
	local playerHex=apocalypseQuestPlayerHex(hexes,mapObjects,playerIndex)
	if markerHex==nil or playerHex==nil then return nil end
	local distances=apocalypseQuestHexDistanceMap(hexes,{markerHex})
	return distances[apocalypseQuestMapHexKey(playerHex)]
end

function apocalypseQuestHexForPosition(hexes, position, mapObjects)
	if position==nil then return nil end
	local terrain,bearing=terrainHexAtPosition(position,mapObjects)
	if terrain==nil or bearing==nil then return nil end
	for _, hex in ipairs(hexes or {}) do
		if hex.terrainGUID==terrain.guid and hex.bearing==bearing then return hex end
	end
	return nil
end

function apocalypseQuestPlayerHex(hexes, mapObjects, playerIndex)
	local position=nil
	if fracturedLandsTeleportSourcePosition~=nil then position=fracturedLandsTeleportSourcePosition(playerIndex) end
	if position==nil then
		local avatar=coopAssaultAvatarObject(playerIndex)
		if avatar~=nil then position=avatar.getPosition() end
	end
	return apocalypseQuestHexForPosition(hexes,position,mapObjects)
end

function apocalypseQuestFeatureIsCity(feature)
	local name=string.lower(tostring(feature or ""))
	return name:find("city",1,true)~=nil or name:sub(1,7)=="raised "
end

function apocalypseQuestFeatureMatches(feature, wanted)
	local name=string.lower(tostring(feature or ""))
	local target=string.lower(tostring(wanted or ""))
	if target=="city" then return apocalypseQuestFeatureIsCity(name) end
	return name==target
end

function apocalypseQuestHexHasShield(hex, mapObjects, playerIndex, anyPlayer)
	local mage=turnOrder[playerIndex]~=nil and turnOrder[playerIndex].mage or nil
	for _, obj in pairs(mapObjects or {}) do
		if obj.getName()=="Shield" and volkarePursuitShieldRegistered(obj)~=true then
			local pos=obj.getPosition()
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

function apocalypseQuestHexSiteInteractable(hex, mapObjects, playerIndex)
	local feature=string.lower(tostring(hex.feature or ""))
	if apocalypseQuestHexDestroyedMonastery~=nil and apocalypseQuestHexDestroyedMonastery(hex)==true then return false end
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
	return apocalypseQuestHexSiteInteractable(hex,mapObjects,playerIndex)==true
end

function apocalypseQuestHexHasEnemy(hex, mapObjects)
	if hex==nil then return false end
	for _, obj in pairs(mapObjects or {}) do
		if monsterPugs[obj.guid]~=nil then
			local pos=obj.getPosition()
			local dx=pos[1]-hex.position[1]
			local dz=pos[3]-hex.position[3]
			if (dx*dx)+(dz*dz)<1 then return true end
		end
	end
	return false
end

function apocalypseQuestHexSafe(hex, mapObjects, playerIndex)
	if hex==nil or hex.hexType=="lake" or hex.hexType=="mountain" or hex.hexType=="ocean" then return false end
	local feature=string.lower(tostring(hex.feature or ""))
	--Rampaging/Draconum labels describe the printed spawn space; once the enemy is gone the space is safe again.
	if apocalypseQuestHexHasEnemy(hex,mapObjects)==true then return false end
	if feature=="keep" or feature=="mage tower" or apocalypseQuestFeatureIsCity(feature)==true or feature=="volkare's camp" then
		return apocalypseQuestHexSiteInteractable(hex,mapObjects,playerIndex)
	end
	return true
end

function apocalypseQuestHexAdventureSite(hex)
	if hex==nil then return false end
	local feature=string.lower(tostring(hex.feature or ""))
	return feature=="monster den" or feature=="spawning grounds" or feature=="ruin" or feature=="dungeon" or feature=="tomb" or
		feature=="maze" or feature=="labyrinth" or feature=="graveyard" or feature=="ziggurat" or feature=="pyramid"
end

function apocalypseQuestStarterLocationRule(card, option)
	if card==nil or option==nil then return nil end
	local rules=apocalypseQuestStepLocationRules[card.guid]
	if rules==nil then return nil end
	return rules[tostring(option.key)] or rules[tostring(apocalypseQuestStepNumber(option.key))]
end

function apocalypseQuestCurrentPlayerHex(playerIndex)
	local refreshCache=apocalypseQuestRefreshMapCache or {}
	if refreshCache~=nil and refreshCache.playerHexes~=nil and refreshCache.playerHexes[playerIndex]~=nil then
		return refreshCache.playerHexes[playerIndex].hex,refreshCache.mapObjects
	end
	local map=getObjectFromGUID(mapArea)
	local position=fracturedLandsTeleportSourcePosition(playerIndex)
	if map==nil or position==nil then return nil, nil end
	local objects=refreshCache~=nil and refreshCache.mapObjects or nil
	if objects==nil then objects=map.getObjects() end
	local terrain,bearing,_,feature,hexType=terrainHexAtPosition(position,objects)
	local hex=nil
	if terrain~=nil and bearing~=nil then
		local xy=angleToXY(terrain,bearing)
		hex={terrain=terrain,terrainGUID=terrain.guid,bearing=bearing,position={xy[1],1.30,xy[2]},feature=feature or "",hexType=hexType or ""}
	end
	if refreshCache~=nil then
		refreshCache.mapObjects=objects
		refreshCache.playerHexes=refreshCache.playerHexes or {}
		refreshCache.playerHexes[playerIndex]={hex=hex}
	end
	return hex,objects
end

function apocalypseQuestInhabitedFeature(feature)
	local name=string.lower(tostring(feature or ""))
	return name=="village" or name=="monastery" or name=="keep" or name=="mage tower" or
		apocalypseQuestFeatureIsCity(name)==true or name=="oasis" or name=="camp"
end

function apocalypseQuestHexNoSite(hex)
	if hex==nil then return false end
	local feature=string.lower(tostring(hex.feature or ""))
	if feature=="" or feature=="portal" or feature=="destroyed" or feature=="rampaging" or feature=="draconum" then return true end
	if feature=="monastery" and gStates.monasteryBurned~=nil and gStates.monasteryBurned[hex.terrainGUID]==true then return true end
	return false
end

function apocalypseQuestTokenOnHex(tokenGUID, hex, mapObjects)
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

function apocalypseQuestTrackMarkerMove(token,target,terrainGUID,bearing)
	if token==nil or target==nil then return end
	if gStates.apocalypseQuestMarkerTransit==nil then gStates.apocalypseQuestMarkerTransit={} end
	local tokenGUID=token.guid
	gStates.apocalypseQuestMarkerTransit[tokenGUID]={terrainGUID=terrainGUID,bearing=bearing,position={target[1],target[2],target[3]}}
	local finish=function()
		if gStates.apocalypseQuestMarkerTransit~=nil then gStates.apocalypseQuestMarkerTransit[tokenGUID]=nil end
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

function apocalypseQuestHexesInStraightLine(a,b)
	if a==nil or b==nil then return false end
	local dx=b.position[1]-a.position[1]
	local dz=b.position[3]-a.position[3]
	if (dx*dx)+(dz*dz)<0.5 then return false end
	local angle=math.deg(math.atan2(dz,dx))
	if angle<0 then angle=angle+360 end
	local remainder=angle%60
	return remainder<1.5 or remainder>58.5
end

function apocalypseQuestRandomObjectsTreasureLocation(hex,mapObjects)
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
		if apocalypseQuestHexesInStraightLine(hex,tokenHex)~=true then return false end
	end
	return true
end

function apocalypseQuestFreeWineLocationLegal(hex,mapObjects,playerIndex)
	if hex==nil then return false end
	local originOK=false
	for _, feature in ipairs({"village","monastery","oasis","camp"}) do
		if apocalypseQuestFeatureMatches(hex.feature,feature)==true then originOK=true break end
	end
	if originOK~=true or apocalypseQuestHexSiteInteractable(hex,mapObjects,playerIndex)~=true then return false end
	local hexes=apocalypseQuestMapHexes()
	local start=nil
	for _, candidate in ipairs(hexes) do
		if candidate.terrainGUID==hex.terrainGUID and tostring(candidate.bearing)==tostring(hex.bearing) then start=candidate break end
	end
	if start==nil then return false end
	local distances=apocalypseQuestHexDistanceMap(hexes,{start})
	for _, candidate in ipairs(hexes) do
		if apocalypseQuestFeatureMatches(candidate.feature,"keep")==true then
			local distance=distances[apocalypseQuestMapHexKey(candidate)]
			if distance~=nil and distance<=3 and apocalypseQuestHexHasShield(candidate,mapObjects,playerIndex,false)~=true then return true end
		end
	end
	return false
end

function apocalypseQuestFreeWineKeepTargets(playerIndex)
	local hexes,mapObjects=apocalypseQuestMapHexes()
	local start=apocalypseQuestPlayerHex(hexes,mapObjects,playerIndex)
	if start==nil then return {} end
	local distances=apocalypseQuestHexDistanceMap(hexes,{start})
	local result={}
	for _, candidate in ipairs(hexes) do
		if apocalypseQuestFeatureMatches(candidate.feature,"keep")==true then
			local distance=distances[apocalypseQuestMapHexKey(candidate)]
			if distance~=nil and distance<=3 and apocalypseQuestHexHasShield(candidate,mapObjects,playerIndex,false)~=true then result[#result+1]=candidate end
		end
	end
	return result
end

function apocalypseQuestFreeWineAssaultRecord(playerIndex)
	local record=gStates.apocalypseQuestFreeWineAssault
	if record==nil or record.player~=playerIndex or turnOrder[playerIndex]==nil then return nil end
	--Quest 10 may still be awaiting its card resolution after a Proxy/other turn has intervened. The
	--committed Keep assault therefore belongs to the Hero, not to the global Quest turn serial.
	if record.mage~=nil and record.mage~=turnOrder[playerIndex].mage then return nil end
	return record
end

function apocalypseQuestFreeWineMarkAssaultStarted(playerIndex)
	local card=getObjectFromGUID("37e2ce")
	local state=card~=nil and apocalypseQuestProgressState(card,playerIndex,false) or nil
	if card==nil or state==nil or state.step~=2 or turnOrder[playerIndex]==nil then return false end
	--Once this branch has an outcome, keep it until Complete/Fail is actually pressed. The shared
	--Rewards Claimed soft-lock timeout must not erase which assault Quest 10 is resolving.
	local existing=apocalypseQuestFreeWineAssaultRecord(playerIndex)
	if existing~=nil then return true end
	local hex=apocalypseQuestCurrentPlayerHex(playerIndex)
	gStates.apocalypseQuestFreeWineAssault={player=playerIndex,mage=turnOrder[playerIndex].mage,serial=gStates.apocalypseQuestTurnSerial or 0,
		terrainGUID=hex~=nil and hex.terrainGUID or nil,bearing=hex~=nil and hex.bearing or nil,result=nil}
	return true
end

function apocalypseQuestFreeWineSuccessReady(playerIndex)
	local record=apocalypseQuestFreeWineAssaultRecord(playerIndex)
	if record==nil then return false end
	if record.result=="Complete" then return true end
	if record.result=="Fail" then return false end
	local hexes,mapObjects=apocalypseQuestMapHexes()
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

function apocalypseQuestFreeWineFailureReady(playerIndex)
	local record=apocalypseQuestFreeWineAssaultRecord(playerIndex)
	return record~=nil and record.result=="Fail"
end

function apocalypseQuestFreeWineCombatOutcome(playerIndex)
	local record=apocalypseQuestFreeWineAssaultRecord(playerIndex)
	if record==nil then return nil end
	if record.result=="Complete" or record.result=="Fail" then return record.result end
	if apocalypseQuestFreeWineSuccessReady(playerIndex)==true then return "Complete" end
	--At pre-end-turn the Keep Shield has not been dropped yet; that happens later in monster cleanup.
	--Read the actual garrison result while attackedMonsters still contains its original map position.
	local target=nil
	for _,hex in ipairs(apocalypseQuestMapHexes()) do
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
	local state=card~=nil and apocalypseQuestProgressState(card,playerIndex,false) or nil
	local record=apocalypseQuestFreeWineAssaultRecord(playerIndex)
	if card==nil or state==nil or state.step~=2 or record==nil then return false end
	local action=apocalypseQuestFreeWineCombatOutcome(playerIndex)
	if action==nil then return false end
	--Create the normal pending reward resolution when the combat outcome is known, not when 1A first
	--sends the Hero toward the Keep. The 12-second soft-lock window starts later at Rewards Claimed.
	apocalypseQuestSetRewardCompletionGate(card,playerIndex,action)
	apocalypseQuestUpdateProgressButtons(card)
	return true
end

function apocalypseQuestFreeWineStartAssault(card,playerIndex)
	if card==nil or turnOrder[playerIndex]==nil then return false end
	local pos=card.getPosition()
	--1A's reminder Shield knows the Quest's planned slot, so send it straight to the matching future position.
	local surface=apocalypseQuestPlannedWorldPosition(card,{pos[1]+0.62,pos[2]+0.65,pos[3]+0.15})
	local target=apocalypseQuestRaisedPiecePosition(surface)
	local shield=apocalypseQuestTakePlayerShield(playerIndex,surface)
	apocalypseQuestRegisterMoveAttachment(card,shield,target)
	if shield~=nil then shield.unlock() end
	--1A commits the player to resolving this Keep assault. Do not create the Rewards Claimed resolution
	--gate yet: the combat itself can take as long as needed. The outcome gate is created at the rewards
	--boundary after success/failure can actually be determined.
	gStates.apocalypseQuestFreeWineAssault=nil
	local targets=apocalypseQuestFreeWineKeepTargets(playerIndex)
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
				if movedAvatar==nil or apocalypseQuestFreeWineAssaultRecord(playerIndex)~=nil then return end
				local current=movedAvatar.getPosition()
				local dx=current[1]-targets[1].position[1]
				local dz=current[3]-targets[1].position[3]
				if (dx*dx)+(dz*dz)<1.5 then onObjectDrop(color,movedAvatar) end
			end
			safeWaitFrames("Quests",function() safeWaitCondition("Quests",finishMove,function() local obj=getObjectFromGUID(avatarGUID) return obj==nil or obj.resting end,4.0,finishMove) end,2)
			broadcastToAll("Free Wine!: one eligible Keep was found; "..tostring(turnOrder[playerIndex].mage).." is moving there to begin the assault.",positionToColor(playerIndex))
		end
	elseif #targets>1 then
		broadcastToAll("Free Wine!: several unconquered Keeps are within 3 revealed spaces. Move to the Keep you choose and assault it.",positionToColor(playerIndex))
	else
		broadcastToAll("Free Wine!: no eligible Keep could be resolved automatically; move to the intended Keep manually.",positionToColor(playerIndex))
	end
	return true
end

function apocalypseQuestConqueredThisTurnLocationLegal(hex,playerIndex)
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
function apocalypseQuestUnderSiegeReadyPlayer()
	local ready=gStates.apocalypseQuestUnderSiegeReady
	if ready==nil then return nil,nil end
	local details=turnOrder[ready.player]
	if details==nil or details.mage~=ready.mage or details.mage==gStates.positionMageKnight[5] or details.dropoutState~=nil or apocalypseQuestCardInOffer("a6d5cc")~=true then
		gStates.apocalypseQuestUnderSiegeReady=nil
		return nil,nil
	end
	local card=getObjectFromGUID("a6d5cc")
	--Once Step 1 has actually been claimed, the Personal Quest Shield owns the card and this
	--out-of-turn conquest window is finished.
	if card==nil or apocalypseQuestPersonalShieldOwner(card)~=nil or apocalypseQuestNeutralShield(card)~=nil then
		gStates.apocalypseQuestUnderSiegeReady=nil
		return nil,nil
	end
	return ready.player,ready
end

function apocalypseQuestUnderSiegeRecordConquest(playerIndex,terrainGUID,bearing,feature)
	if apocalypseQuestsUsed()~=true or turnOrder[playerIndex]==nil or turnOrder[playerIndex].mage==gStates.positionMageKnight[5] or apocalypseQuestCardInOffer("a6d5cc")~=true then return false end
	local card=getObjectFromGUID("a6d5cc")
	if card==nil or apocalypseQuestPersonalShieldOwner(card)~=nil or apocalypseQuestNeutralShield(card)~=nil then return false end
	gStates.apocalypseQuestUnderSiegeReady={player=playerIndex,mage=turnOrder[playerIndex].mage,serial=gStates.apocalypseQuestTurnSerial or 0,terrainGUID=terrainGUID,bearing=bearing,feature=feature}
	return true
end

function apocalypseQuestUnderSiegeLocationLegal(hex,playerIndex)
	local readyPlayer,ready=apocalypseQuestUnderSiegeReadyPlayer()
	if hex==nil or readyPlayer~=playerIndex or ready==nil then return false end
	if ready.terrainGUID~=hex.terrainGUID or tostring(ready.bearing)~=tostring(hex.bearing) then return false end
	local _,mapObjects=apocalypseQuestCurrentPlayerHex(playerIndex)
	return apocalypseQuestHexHasShield(hex,mapObjects,playerIndex,false)==true
end

function apocalypseQuestUnderSiegeInterfacePlayerIndex(card)
	if card==nil or card.guid~="a6d5cc" then return gStates.turnNumber end
	local ownerIndex=apocalypseQuestPersonalShieldOwner(card)
	if ownerIndex~=nil then return ownerIndex end
	local readyPlayer=apocalypseQuestUnderSiegeReadyPlayer()
	return readyPlayer or gStates.turnNumber
end

function apocalypseQuestUnderSiegeMovedThisTurn(playerIndex)
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

function apocalypseQuestUnderSiegeStep2ChoiceLegal(playerIndex,key)
	local pending=gStates.apocalypseQuestUnderSiegeStep2
	local details=turnOrder[playerIndex]
	if pending==nil or details==nil or pending.player~=playerIndex or pending.mage~=details.mage or gStates.turnNumber~=playerIndex or (gStates.apocalypseQuestTurnSerial or 0)<= (pending.serial or 0) then return false end
	local moved=apocalypseQuestUnderSiegeMovedThisTurn(playerIndex)
	--2B is always a legal voluntary failure once Step 2 is active. 2A remains available only while
	--the Hero has stayed at the Quest marker and can still stand and fight.
	if tostring(key)=="2b" then return true end
	if tostring(key)=="2a" then return moved~=true end
	return false
end

function apocalypseQuestUnderSiegeCardPlayed(zone,obj)
	local readyPlayer,ready=apocalypseQuestUnderSiegeReadyPlayer()
	if readyPlayer==nil or ready==nil or zone==nil or obj==nil or gStates.turnNumber~=readyPlayer then return false end
	local details=turnOrder[readyPlayer]
	if details==nil or zone.guid~=playerPlayAreas[details.seatPos] or obj.type~="Card" or gameCards[obj.guid]==nil or obj.getGMNotes()=="Wound" then return false end
	--Do not expire the freshly earned window if a late same-turn physical card movement occurs.
	if (gStates.apocalypseQuestTurnSerial or 0)<= (ready.serial or 0) then return false end
	gStates.apocalypseQuestUnderSiegeReady=nil
	local card=getObjectFromGUID("a6d5cc")
	if card~=nil then safeWaitFrames("Quests",function() local live=getObjectFromGUID("a6d5cc") if live~=nil then apocalypseQuestInterfaceAdd(live,true) end end,2) end
	return true
end

function apocalypseQuestAnyHumanMayConfirm(playerColor)
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

function apocalypseQuestTravellingMerchantRelocate(card,playerIndex)
	if card==nil then return false end
	for _, obj in ipairs(apocalypseQuestObjectsOnCard(card)) do
		local color=apocalypseQuestManaTokenColor(obj)
		local bag=color~=nil and apocalypseQuestManaBag(color) or nil
		if bag~=nil then obj.unlock() bag.putObject(obj) end
	end
	local nextColor=apocalypseQuestRollManaDie()
	apocalypseQuestPlaceManaTokenOnCard(card,nextColor,0,-0.15,"Travelling Merchant")
	local token=getObjectFromGUID("afcfc1")
	local hexes,mapObjects=apocalypseQuestMapHexes()
	local start=apocalypseQuestPlayerHex(hexes,mapObjects,playerIndex)
	if token==nil or start==nil then return false end
	local distances=apocalypseQuestHexDistanceMap(hexes,{start})
	local candidates={}
	for _, hex in ipairs(hexes) do
		if distances[apocalypseQuestMapHexKey(hex)]==3 and apocalypseQuestHexSafe(hex,mapObjects,playerIndex)==true and apocalypseQuestHexHasOtherQuestMarker(hex,token.guid)~=true then candidates[#candidates+1]=hex end
	end
	if #candidates==0 then
		broadcastToAll("Travelling Merchant: no legal safe space exactly 3 revealed spaces away was found; move the highlighted Quest marker manually.",positionToColor(playerIndex))
		apocalypseQuestHighlightMarker(token)
		return true
	end
	local target=candidates[1]
	apocalypseQuestTrackMarkerMove(token,{target.position[1],1.45,target.position[3]},target.terrainGUID,target.bearing)
	token.unlock()
	token.setPositionSmooth({target.position[1],1.45,target.position[3]})
	if #candidates>1 then
		apocalypseQuestHighlightMarker(token)
		broadcastToAll("Travelling Merchant: "..tostring(#candidates).." legal destinations exist. The first was selected; move the highlighted marker if you prefer another.",positionToColor(playerIndex))
	else apocalypseQuestClearMarkerHighlight(token) end
	return true
end

function apocalypseQuestMagicOverloadPlaceSite(card,playerIndex)
	local highest=0
	for _, details in ipairs(turnOrder) do
		if details.mage~=nil and details.mage~="nobody" and details.mage~=gStates.positionMageKnight[5] and details.dropoutState==nil then highest=math.max(highest,details.level or 1) end
	end
	local chosen=highest<=5 and "a4777c" or "963031"
	local unused=chosen=="a4777c" and "963031" or "a4777c"
	local token=getObjectFromGUID(chosen)
	if token==nil then return false end
	if apocalypseQuestPlaceMarkerAtPlayer(token,playerIndex)~=true then return false end
	if gStates.apocalypseQuestMarkerPlacements==nil then gStates.apocalypseQuestMarkerPlacements={} end
	gStates.apocalypseQuestMarkerPlacements[chosen]=true
	local spare=getObjectFromGUID(unused)
	local tokenBag=getObjectFromGUID(GUID.bag.apocalypseQuestTokens)
	if spare~=nil and tokenBag~=nil then spare.unlock() tokenBag.putObject(spare) end
	apocalypseQuestFlipSiteToken(chosen)
	broadcastToAll("Magic Overload: highest Hero level is "..tostring(highest).."; the new "..(chosen=="a4777c" and "Monster Den" or "Spawning Grounds").." was created.",positionToColor(playerIndex))
	return true
end

function apocalypseQuestVeryPersonalUnit(card)
	local token=getObjectFromGUID("7e4e4c")
	if token==nil then return nil end
	local pos=token.getPosition()
	local best=nil
	local bestDistance=9
	for _, obj in pairs(apocalypseQuestAreaObjects()) do
		if obj.type=="Card" and (gameCardType(obj)=="Regular Unit" or gameCardType(obj)=="Elite Unit") then
			local p=obj.getPosition()
			local d=((p[1]-pos[1])^2)+((p[3]-pos[3])^2)
			if d<bestDistance then best=obj bestDistance=d end
		end
	end
	return bestDistance<2.5 and best or nil
end

function apocalypseQuestDisbandVeryPersonalUnit(card)
	local unit=apocalypseQuestVeryPersonalUnit(card)
	if unit==nil then return false end
	local cardType=gameCardType(unit)
	local deckGUID=cardType=="Elite Unit" and GUID.deck.eliteUnit or GUID.deck.regularUnit
	local deck=getObjectFromGUID(deckGUID)
	if deck~=nil then
		unit.unlock()
		deck.putObject(unit)
		broadcastToAll("{en}A Very Personal Quest: the marked Unit was disbanded when the Quest left play.{ru}A Very Personal Quest: отмеченный отряд был распущен, когда задание покинуло игру.{zh-tw}A Very Personal Quest：任務離場時，帶有標記的部隊已被解散。{zh-cn}A Very Personal Quest：任务离场时，带有标记的部队已被解散。{ko}A Very Personal Quest: 퀘스트가 플레이에서 제거될 때 표시된 유닛이 해산되었습니다.{es}A Very Personal Quest: la Unidad marcada fue disuelta cuando la Misión salió del juego.{fr}A Very Personal Quest : l’Unité marquée a été dissoute lorsque la Quête a quitté le jeu.{pt-br}A Very Personal Quest: a Unidade marcada foi dispensada quando a Missão saiu de jogo.{de}A Very Personal Quest: Die markierte Einheit wurde aufgelöst, als die Quest das Spiel verließ.",{1,1,0.5})
		return true
	end
	return false
end

function apocalypseQuestStarterLocationLegal(card,playerIndex,option)
	if card==nil or option==nil then return true end
	local quest=apocalypseQuestData[card.guid]
	if quest==nil then return true end
	local rule=apocalypseQuestStarterLocationRule(card,option)
	if rule==nil then return true end
	local hex,mapObjects=apocalypseQuestCurrentPlayerHex(playerIndex)
	if hex==nil then return false end

	if card.guid=="a6d5cc" and tostring(option.key)=="1" then return apocalypseQuestUnderSiegeLocationLegal(hex,playerIndex) end

	if card.guid=="082f39" and tostring(option.key)=="1" and gStates.apocalypseQuestMarkerPlacements~=nil and gStates.apocalypseQuestMarkerPlacements["afcfc1"]==true then
		return apocalypseQuestTokenOnHex("afcfc1",hex,mapObjects)==true
	end

	--Mine of Doom is not failed by an unsuccessful fight. Once its marker has been committed, it
	--identifies the specific mine being investigated, so later attempts must return to that mine.
	if card.guid=="485cc5" and gStates.apocalypseQuestMarkerPlacements~=nil and gStates.apocalypseQuestMarkerPlacements["2f238c"]==true then
		if apocalypseQuestTokenOnHex("2f238c",hex,mapObjects)~=true then return false end
	end

	if rule.warrens==true then
		if hex.hexType~="hills" or apocalypseQuestHexNoSite(hex)~=true then return false end
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
	if rule.inhabited==true and apocalypseQuestInhabitedFeature(hex.feature)~=true then return false end
	if rule.safe==true and apocalypseQuestHexSafe(hex,mapObjects,playerIndex)~=true then return false end
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
		for _, other in ipairs(apocalypseQuestMapHexes()) do
			if other.hexType==rule.adjacentTerrain and apocalypseQuestHexesAdjacent(hex,other)==true then adjacent=true break end
		end
		if adjacent~=true then return false end
	end
	if rule.nearToken~=nil then
		local token=getObjectFromGUID(rule.nearToken)
		if token==nil then return false end
		local hexes=apocalypseQuestMapHexes()
		local tokenTerrain,tokenBearing=terrainHexAtPosition(token.getPosition(),mapObjects)
		if tokenTerrain==nil or tokenBearing==nil then return false end
		local tokenXY=angleToXY(tokenTerrain,tokenBearing)
		local tokenHex={terrainGUID=tokenTerrain.guid,bearing=tokenBearing,position={tokenXY[1],1.30,tokenXY[2]}}
		local distances=apocalypseQuestHexDistanceMap(hexes,{tokenHex})
		local distance=distances[apocalypseQuestMapHexKey(hex)]
		if distance==nil or (rule.nearDistanceMax~=nil and distance>rule.nearDistanceMax) then return false end
	end
	if rule.nearFeatures~=nil then
		local hexes=apocalypseQuestMapHexes()
		local starts={}
		for _, candidate in ipairs(hexes) do
			for _, feature in ipairs(rule.nearFeatures) do if apocalypseQuestFeatureMatches(candidate.feature,feature)==true then starts[#starts+1]=candidate break end end
		end
		if #starts==0 then return false end
		local distances=apocalypseQuestHexDistanceMap(hexes,starts)
		local distance=distances[apocalypseQuestMapHexKey(hex)]
		if distance==nil or (rule.nearDistanceMax~=nil and distance>rule.nearDistanceMax) then return false end
	end
	if rule.coastalTile==true then
		local hexes=apocalypseQuestMapHexes()
		if apocalypseQuestTerrainTileCoastal(hexes,hex.terrain)~=true then return false end
	end
	if rule.features~=nil then
		local matches=false
		for _, feature in ipairs(rule.features) do if apocalypseQuestFeatureMatches(hex.feature,feature)==true then matches=true break end end
		if matches~=true then return false end
	end
	if rule.terrains~=nil then
		local matches=false
		for _, terrainType in ipairs(rule.terrains) do if hex.hexType==terrainType then matches=true break end end
		if matches~=true then return false end
	end
	if rule.noSite==true and apocalypseQuestHexNoSite(hex)~=true then return false end
	if rule.destroyedMonastery==true and apocalypseQuestHexDestroyedMonastery(hex)~=true then return false end
	if rule.unconquered==true and apocalypseQuestHexHasShield(hex,mapObjects,playerIndex,true)==true then return false end
	if rule.freeWine==true and apocalypseQuestFreeWineLocationLegal(hex,mapObjects,playerIndex)~=true then return false end
	if rule.conqueredThisTurn==true and apocalypseQuestConqueredThisTurnLocationLegal(hex,playerIndex)~=true then return false end
	if rule.interactionSite==true and apocalypseQuestHexInteractionSite(hex,mapObjects,playerIndex)~=true then return false end
	if rule.requireInteractable==true and apocalypseQuestHexSiteInteractable(hex,mapObjects,playerIndex)~=true then return false end
	if rule.sameToken~=nil and apocalypseQuestTokenOnHex(rule.sameToken,hex,mapObjects)~=true then return false end
	if rule.excludeToken~=nil and apocalypseQuestTokenOnHex(rule.excludeToken,hex,mapObjects)==true then return false end
	if rule.randomObjectsTreasure==true and apocalypseQuestRandomObjectsTreasureLocation(hex,mapObjects)~=true then return false end
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
function apocalypseQuestPlaceMarkerAtPlayer(token,playerIndex)
	if token==nil then return false end
	local target=fracturedLandsTeleportSourcePosition(playerIndex)
	local map=getObjectFromGUID(mapArea)
	if target==nil or map==nil then return false end
	local terrain,bearing=terrainHexAtPosition(target,map.getObjects())
	if terrain==nil or bearing==nil then return false end
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
	apocalypseQuestTrackMarkerMove(token,{target[1],1.22,target[3]},terrain.guid,bearing)
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

function apocalypseQuestHexDestroyedMonastery(hex)
	if hex==nil then return false end
	if hex.feature=="monastery" and gStates.monasteryBurned~=nil and gStates.monasteryBurned[hex.terrainGUID]==true then return true end
	if hex.feature=="destroyed" and gStates.destroyedSites~=nil then
		for _, details in pairs(gStates.destroyedSites) do
			if details.terrainTile==hex.terrainGUID and tostring(details.hexAngle)==tostring(hex.bearing) and details.hexFeature=="monastery" then return true end
		end
	end
	return false
end

function apocalypseQuestHexHasOtherQuestMarker(hex, movingTokenGUID)
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

function apocalypseQuestTerrainTileOnCurrentMapEdge(hexes, terrainGUID)
	for _, hex in ipairs(hexes or {}) do
		if hex.terrainGUID==terrainGUID then
			local neighbours=0
			for _, other in ipairs(hexes or {}) do
				if apocalypseQuestHexesAdjacent(hex,other)==true then neighbours=neighbours+1 end
			end
			if neighbours<6 then return true end
		end
	end
	return false
end

function apocalypseQuestTerrainTileCoastal(hexes, terrain)
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
	return apocalypseQuestTerrainTileOnCurrentMapEdge(hexes,terrain.guid)
end

function apocalypseQuestMarkerLegalHexes(card, playerIndex, rule, token)
	if card==nil or rule==nil or token==nil then return {} end
	local hexes,mapObjects=apocalypseQuestMapHexes()
	if #hexes==0 then return {} end
	local playerHex=nil
	local playerDistances=nil
	if rule.distanceFromPlayerMax~=nil or rule.distanceFromPlayerMin~=nil then
		playerHex=apocalypseQuestPlayerHex(hexes,mapObjects,playerIndex)
		if playerHex==nil then return {} end
		playerDistances=apocalypseQuestHexDistanceMap(hexes,{playerHex})
	end
	local nearDistances=nil
	if rule.nearFeatures~=nil then
		local starts={}
		for _, hex in ipairs(hexes) do
			for _, feature in ipairs(rule.nearFeatures) do
				if apocalypseQuestFeatureMatches(hex.feature,feature)==true then starts[#starts+1]=hex break end
			end
		end
		if #starts==0 then return {} end
		nearDistances=apocalypseQuestHexDistanceMap(hexes,starts)
	end
	local markerDistances=nil
	if rule.distanceFromMarkerMax~=nil or rule.distanceFromMarkerMin~=nil then
		local markerHex=apocalypseQuestHexForPosition(hexes,token.getPosition(),mapObjects)
		if markerHex==nil then return {} end
		markerDistances=apocalypseQuestHexDistanceMap(hexes,{markerHex})
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
			for _, feature in ipairs(rule.features) do if apocalypseQuestFeatureMatches(hex.feature,feature)==true then legal=true break end end
		end
		if legal and rule.requireInteractable==true and apocalypseQuestHexSiteInteractable(hex,mapObjects,playerIndex)~=true then legal=false end
		if legal and rule.destroyedMonastery==true and apocalypseQuestHexDestroyedMonastery(hex)~=true then legal=false end
		if legal and rule.safe==true and apocalypseQuestHexSafe(hex,mapObjects,playerIndex)~=true then legal=false end
		if legal and rule.noSite==true and apocalypseQuestHexNoSite(hex)~=true then legal=false end
		if legal and rule.unconqueredAdventure==true then
			if apocalypseQuestHexAdventureSite(hex)~=true or apocalypseQuestHexHasShield(hex,mapObjects,playerIndex,true)==true then legal=false end
		end
		if legal and rule.adventureSite==true and apocalypseQuestHexAdventureSite(hex)~=true then legal=false end
		if legal and rule.accessibleNoSite==true then
			local feature=string.lower(tostring(hex.feature or ""))
			local noSite=feature=="" or feature=="portal" or feature=="destroyed" or
				((feature=="rampaging" or feature=="draconum") and apocalypseQuestHexHasEnemy(hex,mapObjects)~=true) or
				(feature=="monastery" and gStates.monasteryBurned~=nil and gStates.monasteryBurned[hex.terrainGUID]==true)
			if hex.hexType=="lake" or hex.hexType=="mountain" or hex.hexType=="ocean" or noSite~=true then legal=false end
		end
		if legal and rule.adjacentTerrain~=nil then
			local adjacent=false
			for _, other in ipairs(hexes) do
				if other.hexType==rule.adjacentTerrain and apocalypseQuestHexesAdjacent(hex,other)==true then adjacent=true break end
			end
			if adjacent~=true then legal=false end
		end
		if legal and playerDistances~=nil then
			local distance=playerDistances[apocalypseQuestMapHexKey(hex)]
			if distance==nil then legal=false end
			if legal and rule.distanceFromPlayerMax~=nil and distance>rule.distanceFromPlayerMax then legal=false end
			if legal and rule.distanceFromPlayerMin~=nil and distance<rule.distanceFromPlayerMin then legal=false end
		end
		if legal and nearDistances~=nil then
			local distance=nearDistances[apocalypseQuestMapHexKey(hex)]
			if distance==nil then legal=false end
			if legal and rule.nearDistanceMax~=nil and distance>rule.nearDistanceMax then legal=false end
			if legal and rule.nearDistanceMin~=nil and distance<rule.nearDistanceMin then legal=false end
		end
		if legal and markerDistances~=nil then
			local distance=markerDistances[apocalypseQuestMapHexKey(hex)]
			if distance==nil then legal=false end
			if legal and rule.distanceFromMarkerMax~=nil and distance>rule.distanceFromMarkerMax then legal=false end
			if legal and rule.distanceFromMarkerMin~=nil and distance<rule.distanceFromMarkerMin then legal=false end
		end
		if legal and rule.coastalTile==true then
			if coastalCache[hex.terrainGUID]==nil then coastalCache[hex.terrainGUID]=apocalypseQuestTerrainTileCoastal(hexes,hex.terrain) end
			if coastalCache[hex.terrainGUID]~=true then legal=false end
		end
		if legal and apocalypseQuestHexHasOtherQuestMarker(hex,token.guid)==true then legal=false end
		if legal then candidates[#candidates+1]=hex end
	end
	local sourceHex=apocalypseQuestPlayerHex(hexes,mapObjects,playerIndex)
	table.sort(candidates,function(a,b)
		if rule.closestToPlayer==true and playerDistances~=nil then
			local ad=playerDistances[apocalypseQuestMapHexKey(a)]
			local bd=playerDistances[apocalypseQuestMapHexKey(b)]
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

function apocalypseQuestMarkerCurrentHexLegal(token,candidates,hexes,mapObjects)
	if token==nil then return false end
	local current=apocalypseQuestHexForPosition(hexes,token.getPosition(),mapObjects)
	if current==nil then return false end
	local key=apocalypseQuestMapHexKey(current)
	for _, candidate in ipairs(candidates or {}) do
		if apocalypseQuestMapHexKey(candidate)==key then return true end
	end
	return false
end

function apocalypseQuestHighlightMarker(token)
	if token==nil then return end
	if gStates.apocalypseQuestHighlightedTokens==nil then gStates.apocalypseQuestHighlightedTokens={} end
	token.highlightOn({1,0.9,0})
	gStates.apocalypseQuestHighlightedTokens[token.guid]=true
end

function apocalypseQuestClearMarkerHighlight(token)
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

function apocalypseQuestMarkerPlacementCommitted(rule)
	if rule==nil or gStates.apocalypseQuestMarkerPlacements==nil then return false end
	for _, guid in ipairs(rule.tokens or {}) do
		if gStates.apocalypseQuestMarkerPlacements[guid]==true then return true end
	end
	return false
end

function apocalypseQuestCommitStepMarker(card, option)
	if card==nil or option==nil then return end
	local rule=apocalypseQuestMarkerRule(card,apocalypseQuestStepNumber(option.key))
	if rule==nil then return end
	local token=apocalypseQuestMarkerObject(rule)
	if token==nil then return end
	if gStates.apocalypseQuestMarkerPlacements==nil then gStates.apocalypseQuestMarkerPlacements={} end
	gStates.apocalypseQuestMarkerPlacements[token.guid]=true
end

function apocalypseQuestPlaceStepMarker(card, playerIndex, option, playerColor)
	if card==nil or option==nil then return true end
	local rule=apocalypseQuestMarkerRule(card,apocalypseQuestStepNumber(option.key))
	if rule==nil then return true end
	local token=apocalypseQuestMarkerObject(rule)
	if token==nil then
		if playerColor~=nil then broadcastToColor("The required Quest marker could not be found.", playerColor, {1,0.55,0.2}) end
		return false
	end
	if rule.relocate~=true and apocalypseQuestMarkerPlacementCommitted(rule)==true then return true end
	if rule.atPlayer==true then
		if apocalypseQuestStarterLocationLegal(card,playerIndex,option)~=true then
			if playerColor~=nil then broadcastToColor("Your Mage Knight is not at a valid location for this Quest step.", playerColor, warningColor) end
			return false
		end
		local playerHex=apocalypseQuestCurrentPlayerHex(playerIndex)
		if playerHex==nil or apocalypseQuestHexHasOtherQuestMarker(playerHex,token.guid)==true then
			if playerColor~=nil then broadcastToColor("That map space already contains a Quest marker. Only one Quest marker may be placed in a map space.", playerColor, warningColor) end
			return false
		end
		local placed=apocalypseQuestPlaceMarkerAtPlayer(token,playerIndex)
		if placed~=true and playerColor~=nil then broadcastToColor("The Quest marker could not be placed at your Mage Knight.", playerColor, {1,0.55,0.2}) end
		return placed==true
	end
	local candidates,hexes,mapObjects=apocalypseQuestMarkerLegalHexes(card,playerIndex,rule,token)
	if #candidates==0 then
		apocalypseQuestClearMarkerHighlight(token)
		if playerColor~=nil then broadcastToColor("There is no legal map space for this Quest marker yet.", playerColor, warningColor) end
		apocalypseQuestUpdateProgressButtons(card)
		return false
	end
	local currentLegal=apocalypseQuestMarkerCurrentHexLegal(token,candidates,hexes,mapObjects)
	local target=candidates[1]
	if rule.closestToPlayer==true then
		local current=apocalypseQuestHexForPosition(hexes,token.getPosition(),mapObjects)
		currentLegal=current~=nil and apocalypseQuestMapHexKey(current)==apocalypseQuestMapHexKey(target)
	end
	if currentLegal~=true then
		token.unlock()
		apocalypseQuestTrackMarkerMove(token,{target.position[1],1.45,target.position[3]},target.terrainGUID,target.bearing)
		token.setPositionSmooth({target.position[1],1.45,target.position[3]})
	end
	if #candidates>1 then
		apocalypseQuestHighlightMarker(token)
		if playerColor~=nil then
			broadcastToColor(tostring(#candidates).." legal spaces are available. The first was selected; move the highlighted Quest marker if you prefer another.", playerColor, {1,1,0.5})
		end
	else
		apocalypseQuestClearMarkerHighlight(token)
	end
	return true
end

function apocalypseQuestMarkerPlacementAvailable(card,playerIndex,option)
	if option==nil then return true end
	local rule=apocalypseQuestMarkerRule(card,apocalypseQuestStepNumber(option.key))
	if rule==nil then return true end
	local token=apocalypseQuestMarkerObject(rule)
	if token==nil then return false end
	if rule.relocate~=true and apocalypseQuestMarkerPlacementCommitted(rule)==true then return true end
	if rule.atPlayer==true then
		if apocalypseQuestStarterLocationLegal(card,playerIndex,option)~=true then return false end
		local playerHex=apocalypseQuestCurrentPlayerHex(playerIndex)
		return playerHex~=nil and apocalypseQuestHexHasOtherQuestMarker(playerHex,token.guid)~=true
	end
	local candidates,hexes,mapObjects=apocalypseQuestMarkerLegalHexes(card,playerIndex,rule,token)
	if apocalypseQuestMarkerCurrentHexLegal(token,candidates,hexes,mapObjects)==true then return true end
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
	local allObjects=apocalypseQuestAreaObjects()
	local offerCards=apocalypseQuestOfferCards(allObjects)
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
			local rowOwner=apocalypseQuestIndependentShieldRowOwnerGUID(obj,offerCards)
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

function apocalypseQuestRefreshAfterMarkerChange()
	--Bag returns are effectively immediate, while reward/relocation markers may still be smooth-moving.
	--Refresh once now and once after the motion has had time to clear its old hex.
	safeWaitFrames("Quests",function() apocalypseQuestRefreshOfferButtons() end,3)
	safeWaitFrames("Quests",function() apocalypseQuestRefreshOfferButtons() end,60)
end

function apocalypseQuestPlayerMayAct(card, playerIndex)
	if card==nil or turnOrder[playerIndex]==nil then return false end
	local playerDetails=turnOrder[playerIndex]
	if playerDetails.mage==nil or playerDetails.mage=="nobody" or playerDetails.mage==gStates.positionMageKnight[5] or playerDetails.dropoutState~=nil then return false end
	local quest=apocalypseQuestData[card.guid]
	if quest==nil then return false end
	if card.guid=="82a935" and apocalypseQuestPlayerBurnedMonastery(playerIndex)==true then return false end
	if quest.questType~="Personal" then return true end
	local ownerIndex=apocalypseQuestPersonalShieldOwner(card)
	if ownerIndex~=nil then return ownerIndex==playerIndex end
	if card.guid=="a6d5cc" then
		local readyPlayer=apocalypseQuestUnderSiegeReadyPlayer()
		if readyPlayer~=nil and readyPlayer~=playerIndex then return false end
	end
	if apocalypseQuestPlayerHasOtherPersonalQuest(playerIndex, card.guid)==true then return false end
	return true
end
function apocalypseQuestCurrentOptions(card, playerIndex, action)
	local options={}
	local quest=card~=nil and apocalypseQuestData[card.guid] or nil
	if quest==nil or apocalypseQuestPlayerMayAct(card, playerIndex)~=true then return options end
	--An abandoned Personal Quest must be explicitly resumed before any further step action.
	--The Resume button swaps the neutral Shield back to the acting player's Shield in place.
	if quest.questType=="Personal" and apocalypseQuestNeutralShield(card)~=nil then return options end
	local state=apocalypseQuestProgressState(card, playerIndex, true)
	if state==nil or state.completed==true then return options end
	local groupStepReady=true
	if quest.allPlayersMustCompleteStep~=nil and state.step>quest.allPlayersMustCompleteStep then
		groupStepReady=apocalypseQuestAllPlayersCompletedStep(card, quest.allPlayersMustCompleteStep)
	end
	local placementAvailable=nil
	for _, option in ipairs(quest.steps or {}) do
		--Only the acting player's current numeric step can contribute an action. Branched steps (2a/2b/2c)
		--still all pass this gate, but later Quest steps no longer perform needless map/special checks.
		if apocalypseQuestStepNumber(option.key)==state.step and groupStepReady==true then
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
			if card.guid=="72099f" and tostring(option.key)=="1" and action=="Progress" then
				include=apocalypseQuestGoblinAttemptReady(playerIndex)
			end
			if card.guid=="bbd087" and apocalypseQuestStepNumber(option.key)==3 and action=="Complete" then
				include=include==true and apocalypseQuestCardCrystalColor(card)~=nil
			end
			if card.guid=="8cff07" and tostring(option.key)=="1" then
				local rolled=gStates.apocalypseQuestRichMerchantRoll~=nil and gStates.apocalypseQuestRichMerchantRoll[card.guid] or nil
				--Before the roll, Proceed is the Step-1 action. Once a non-Black result has resolved, the only
				--remaining Step-1 action is Complete; Proceed must not be rolled again.
				if action=="Progress" then include=rolled==nil end
				if action=="Complete" then include=rolled~=nil and rolled.mage==turnOrder[playerIndex].mage and rolled.result~="Black" end
			end
			local veryPersonalManual=card.guid=="b401dc" and state.step==2 and (action=="Complete" or action=="Fail")
			local freeWineResolution=card.guid=="37e2ce" and state.step==2 and (action=="Complete" or action=="Fail")
			if freeWineResolution==true then
				--Quest 10 resolves the already committed Keep assault. Its result remains valid after a Proxy or
				--other turn intervenes, so do not run the generic conquered-*this-turn* location gate here.
				include=action=="Complete" and apocalypseQuestFreeWineSuccessReady(playerIndex) or apocalypseQuestFreeWineFailureReady(playerIndex)
			elseif include==true and veryPersonalManual~=true then
				local failIgnoresLocation=action=="Fail" and card.guid=="08ffcf"
				local locationReady=failIgnoresLocation or apocalypseQuestStarterLocationLegal(card,playerIndex,option)
				local specialReady=action=="Fail" and apocalypseQuestFailureReady(card,option,playerIndex) or apocalypseQuestStepSpecialLegal(card,playerIndex,option)
				include=locationReady==true and specialReady==true
			end
			if include==true and action~="Fail" and veryPersonalManual~=true and freeWineResolution~=true then
				if placementAvailable==nil then
					local ok, available=pcall(apocalypseQuestMarkerPlacementAvailable, card, playerIndex, option)
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
function apocalypseQuestActionEnabled(card, playerIndex, action)
	if action=="Fail" and card~=nil and card.guid=="ce70fb" and gStates.apocalypseQuestCombatBranch~=nil and gStates.apocalypseQuestCombatBranch[card.guid]=="2b" then return false end
	if gStates.mineClaimPending~=nil and gStates.mineClaimPending.source=="Quest" and gStates.mineClaimPending.questCardGUID==card.guid then return false end
	if action=="Abandon" then
		local quest=card~=nil and apocalypseQuestData[card.guid] or nil
		if quest==nil or quest.questType~="Personal" then return false end
		if card.guid=="a6d5cc" and apocalypseQuestPersonalShieldOwner(card)~=nil then return false end
		if card.guid=="82a935" and apocalypseQuestCombatStartedThisTurn(card,2)==true and gStates.apocalypseQuestDirectBranch~=nil and gStates.apocalypseQuestDirectBranch[card.guid]=="2c" then return false end
		local ownerIndex=apocalypseQuestPersonalShieldOwner(card)
		if ownerIndex~=nil then return ownerIndex==playerIndex end
		if apocalypseQuestNeutralShield(card)~=nil then return apocalypseQuestPlayerMayAct(card, playerIndex)==true end
		return false
	end
	return #apocalypseQuestCurrentOptions(card, playerIndex, action)>0
end
function apocalypseQuestSnapWorldPosition(card, stepKey, leftOffset)
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

function apocalypseQuestIndependentShieldRowOwnerGUID(obj,offerCards)
	if obj==nil then return nil end
	local name=obj.getName()
	if name~="Shield" and name~="Red Mana" and name~="Blue Mana" and name~="Green Mana" and name~="White Mana" and name~="Gold Mana" and name~="Black Mana" then return nil end
	local pos=obj.getPosition()
	local bestGUID=nil
	local bestDistance=0.31
	for _, questCard in ipairs(offerCards or apocalypseQuestOfferCards()) do
		local quest=apocalypseQuestData[questCard.guid]
		if quest~=nil and quest.questType=="Independent" and quest.snapOrder~=nil then
			local maxSlot=math.max(0,(tonumber(gStates.playerCount) or 4)-1)
			for _, key in ipairs(quest.snapOrder) do
				for slot=0,maxSlot do
					local target=apocalypseQuestSnapWorldPosition(questCard,key,slot)
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

function apocalypseQuestNearestRowSlot(position, targets, maxSlot)
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

function apocalypseQuestIndependentShieldRowPosition(card,stepKey,movingShieldGUID)
	if card==nil then return nil end
	local quest=apocalypseQuestData[card.guid]
	if quest==nil or quest.questType~="Independent" then return apocalypseQuestSnapWorldPosition(card,stepKey) end
	local maxSlot=math.max(0,(tonumber(gStates.playerCount) or 4)-1)
	local targets={}
	for slot=0,maxSlot do targets[slot]=apocalypseQuestSnapWorldPosition(card,stepKey,slot) end
	if targets[0]==nil then return nil end
	local occupied={}
	local areaObjects=apocalypseQuestAreaObjects()
	local offerCards=apocalypseQuestOfferCards(areaObjects)
	for _, obj in pairs(areaObjects) do
		if obj.guid~=movingShieldGUID and obj.getName()=="Shield" and obj.getDescription()~="Neutral" then
			local rowOwner=apocalypseQuestIndependentShieldRowOwnerGUID(obj,offerCards)
			if rowOwner==nil or rowOwner==card.guid then
				local nearestSlot,nearestDistance=apocalypseQuestNearestRowSlot(obj.getPosition(),targets,maxSlot)
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
		local nearestSlot,nearestDistance=apocalypseQuestNearestRowSlot(pos,targets,maxSlot)
		if nearestSlot~=nil and nearestDistance<0.31 and occupied[nearestSlot]~=true then return pos end
	end
	for slot=0,maxSlot do if occupied[slot]~=true then return targets[slot] end end
	--This should only happen after an unexpected extra Shield; continue the row rather than stacking.
	return apocalypseQuestSnapWorldPosition(card,stepKey,maxSlot+1)
end
function apocalypseQuestRaisedPiecePosition(position,height)
	if position==nil then return nil end
	return {position[1],position[2]+(height or 0.20),position[3]}
end
function apocalypseQuestShieldSupplyBag(owner)
	local bags=gStates.apocalypseQuestShieldBagGUIDs
	if bags==nil then return nil end
	local guid=bags[owner]
	if guid==nil then return nil end
	return getObjectFromGUID(guid)
end
function apocalypseQuestTakePlayerShield(playerIndex, position)
	local playerDetails=turnOrder[playerIndex]
	if playerDetails==nil then return nil end
	local shieldBag=apocalypseQuestShieldSupplyBag(playerDetails.mage)
	if shieldBag==nil then return nil end
	return shieldBag.takeObject({position=apocalypseQuestRaisedPiecePosition(position),rotation={0,180,0},smooth=true})
end
function apocalypseQuestTakeNeutralShield(position)
	local shieldBag=apocalypseQuestShieldSupplyBag("Neutral")
	if shieldBag==nil then return nil end
	return shieldBag.takeObject({position=apocalypseQuestRaisedPiecePosition(position),rotation={0,180,0},smooth=true})
end
function apocalypseQuestPositionProgressShield(card, playerIndex, option)
	local quest=card~=nil and apocalypseQuestData[card.guid] or nil
	if quest==nil or quest.questType=="Simple" then return true end
	local world=apocalypseQuestSnapWorldPosition(card, option.key)
	if world==nil then
		--Repeatable steps such as Under Siege 2a and Cursed 2a deliberately have no new snap:
		--the Shield remains on the previous numbered step. Travelling Merchant needs no physical move.
		return true
	end
	local shield=nil
	if quest.questType=="Collective" then
		shield=apocalypseQuestNeutralShield(card)
	elseif quest.questType=="Independent" then
		shield=apocalypseQuestPlayerShield(card, playerIndex)
		world=apocalypseQuestIndependentShieldRowPosition(card,option.key,shield~=nil and shield.guid or nil)
	else
		shield=apocalypseQuestPlayerShield(card, playerIndex)
		if shield==nil then
			local neutral=apocalypseQuestNeutralShield(card)
			if neutral~=nil then neutral.destruct() end
		end
	end
	world=apocalypseQuestPlannedWorldPosition(card,world)
	local target=apocalypseQuestRaisedPiecePosition(world)
	if shield==nil then
		shield=quest.questType=="Collective" and apocalypseQuestTakeNeutralShield(world) or apocalypseQuestTakePlayerShield(playerIndex,world)
	end
	if shield==nil then return false end
	shield.unlock()
	shield.setPositionSmooth(target)
	apocalypseQuestRegisterMoveAttachment(card,shield,target)
	return true
end
function apocalypseQuestRemovePlayerShield(card, playerIndex)
	local shield=apocalypseQuestPlayerShield(card, playerIndex)
	if shield~=nil and getObjectFromGUID(shield.guid)~=nil then shield.destruct() return true end
	return false
end
function apocalypseQuestAwardStepPoint(card, playerIndex, option, state, questState)
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
	apocalypseQuestScoreGain(playerIndex, 1)
	return true
end
function apocalypseQuestAdvanceProgress(card, state, option)
	if card==nil or state==nil or option==nil then return end
	local quest=apocalypseQuestData[card.guid]
	if card.guid=="8cff07" and tostring(option.key)=="1" then
		local rolled=gStates.apocalypseQuestRichMerchantRoll~=nil and gStates.apocalypseQuestRichMerchantRoll[card.guid] or nil
		if rolled==nil or rolled.result~="Black" then return end
	end
	local repeatCount=math.max(0, tonumber(option.repeatCount) or 0)
	if repeatCount>0 then
		local count=(state.repeats[option.key] or 0)+1
		state.repeats[option.key]=count
		if repeatCount<99 and count>=repeatCount then
			local nextStep=apocalypseQuestNextStepNumber(quest, state.step)
			if nextStep~=nil then state.step=nextStep end
		end
	else
		local nextStep=apocalypseQuestNextStepNumber(quest, state.step)
		if nextStep~=nil then state.step=nextStep end
	end
end
function apocalypseQuestAllPlayersCompleted(card)
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
function apocalypseQuestAllPlayersCompletedStep(card, requiredStep)
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
function apocalypseQuestOptionsNeedChoice(card, action, options)
	if options==nil or #options<=1 then return false end
	--Different printed branches can have the same Quest-point value but different consequences.
	--If more than one Progress/Complete branch is legal, always let the player choose the printed branch.
	return action=="Progress" or action=="Complete"
end
function apocalypseQuestChoiceKeys(options)
	local keys={}
	for _, option in ipairs(options or {}) do keys[#keys+1]=option.key end
	return keys
end
function apocalypseQuestChoiceOption(card, key)
	local quest=card~=nil and apocalypseQuestData[card.guid] or nil
	if quest==nil then return nil end
	for _, option in ipairs(quest.steps or {}) do if option.key==key then return option end end
	return nil
end
function apocalypseQuestShowChoice(card, playerIndex, action, options)
	if card==nil or options==nil or #options==0 then return false end
	if gStates.apocalypseQuestPendingChoice==nil then gStates.apocalypseQuestPendingChoice={} end
	gStates.apocalypseQuestPendingChoice[card.guid]={playerIndex=playerIndex, action=action, keys=apocalypseQuestChoiceKeys(options)}
	--Rebuild the card UI in one setXmlTable call. TTS does not apply a UI removal synchronously,
	--so remove-then-add in the same frame could leave the card blank until a later refresh.
	apocalypseQuestInterfaceAdd(card, true)
	return true
end

function apocalypseQuestDirectChoices(card,playerIndex)
	local choices={}
	if card==nil or apocalypseQuestPlayerMayAct(card,playerIndex)~=true then return choices end
	local state=apocalypseQuestProgressState(card,playerIndex,false)
	if state==nil or state.completed==true then return choices end
	local already=gStates.apocalypseQuestDirectBranch~=nil and gStates.apocalypseQuestDirectBranch[card.guid] or nil
	if already~=nil then return choices end
	if card.guid=="72099f" and state.step==1 and apocalypseQuestGoblinAttempt(playerIndex,true)==nil then
		choices={{key="Goblin1",action="GoblinWarrens",label="1"},{key="Goblin2",action="GoblinWarrens",label="2"},{key="Goblin3",action="GoblinWarrens",label="3"}}
	elseif card.guid=="8939c0" and state.step==1 then choices={{key="1a",action="Complete"},{key="1b",action="Combat"},{key="1c",action="Complete"}}
	elseif card.guid=="bbd087" and state.step==3 and apocalypseQuestCardCrystalColor(card)~=nil then
		local option=apocalypseQuestChoiceOption(card,"3a")
		if option~=nil and apocalypseQuestStarterLocationLegal(card,playerIndex,option)==true then
			choices={{key="3a",action="Complete",label="3A"},{key="3b",action="Complete",label="3B"}}
		end
	elseif card.guid=="37e2ce" and state.step==1 then choices={{key="1a",action="Progress"},{key="1b",action="Complete"}}
	elseif card.guid=="a6d5cc" and state.step==2 and apocalypseQuestCombatStartedThisTurn(card,2)~=true then choices={{key="2a",action="Combat",label="2A"},{key="2b",action="Fail",label="2B - Fail"}}
	elseif card.guid=="82a935" and state.step==2 then choices={{key="2a",action="Complete"},{key="2b",action="Complete"},{key="2c",action="Combat"}}
	elseif card.guid=="8455b5" and state.step==2 and apocalypseQuestPersonalShieldOwner(card)==playerIndex then
		--The Admiring Bard's defeated-enemy branch is player-declared. Combat cleanup removes defeated
		--tokens before the Quest can reliably inspect them, so keep all three printed outcomes available.
		choices={{key="2a",action="Progress",label="2A"},{key="2b",action="Progress",label="2B"},{key="2c",action="Progress",label="2C"}}
	elseif card.guid=="ce70fb" and state.step==2 then choices={{key="2a",action="Combat"},{key="2b",action="Combat"}}
	elseif card.guid=="783076" and state.step==1 then choices={{key="1a",action="Progress"},{key="1b",action="Progress"}} end
	return choices
end

function apocalypseQuestDirectChoiceLegal(card,playerIndex,choice)
	if card==nil or choice==nil then return false end
	if card.guid=="bbd087" and apocalypseQuestStepNumber(choice.key)==3 and apocalypseQuestCardCrystalColor(card)==nil then return false end
	if card.guid=="72099f" and choice.action=="GoblinWarrens" then
		local option=apocalypseQuestChoiceOption(card,"1")
		return option~=nil and apocalypseQuestGoblinAttempt(playerIndex,true)==nil and apocalypseQuestStarterLocationLegal(card,playerIndex,option)==true and apocalypseQuestMarkerPlacementAvailable(card,playerIndex,option)==true
	end
	local option=apocalypseQuestChoiceOption(card,choice.key)
	if option==nil or apocalypseQuestStarterLocationLegal(card,playerIndex,option)~=true then return false end
	if card.guid=="a6d5cc" and apocalypseQuestStepNumber(choice.key)==2 and apocalypseQuestUnderSiegeStep2ChoiceLegal(playerIndex,choice.key)~=true then return false end
	if choice.action~="Combat" and apocalypseQuestMarkerPlacementAvailable(card,playerIndex,option)~=true then return false end
	return true
end
function apocalypseQuestButtonState(card, playerIndex)
	local progressEnabled=apocalypseQuestActionEnabled(card, playerIndex, "Progress")
	local completeEnabled=apocalypseQuestActionEnabled(card, playerIndex, "Complete")
	local abandonEnabled=apocalypseQuestActionEnabled(card, playerIndex, "Abandon")
	local quest=apocalypseQuestData[card.guid]
	local abandonLabel=quest~=nil and quest.questType=="Personal" and apocalypseQuestPersonalShieldOwner(card)==nil and apocalypseQuestNeutralShield(card)~=nil and "Resume" or "Abandon"
	local failEnabled=apocalypseQuestActionEnabled(card, playerIndex, "Fail")
	local enemyAttackButton=apocalypseQuestUsesEnemyAttackButton(card)==true
	if enemyAttackButton==true then apocalypseQuestRefreshEnemyAttackButtons(card,playerIndex) end
	local questState=apocalypseQuestProgressState(card,playerIndex,false)
	local mineDoomAttack=card.guid=="485cc5" and questState~=nil and questState.step==2
	local fogFinalFight=card.guid=="dd35bb" and questState~=nil and questState.step==3
	local fightRelevant=enemyAttackButton~=true and mineDoomAttack~=true and fogFinalFight~=true and apocalypseQuestCombatRelevant(card,playerIndex)
	local progressLabel="Progress"
	local failLabel="Fail"
	if mineDoomAttack==true then
		--Mine of Doom uses the normal Quest action slot as its combat launcher instead of adding
		--the separate Attack icon beneath the card controls.
		progressLabel="Attack"
		progressEnabled=apocalypseQuestCombatAvailable(card,playerIndex)
	elseif fogFinalFight==true then
		progressLabel="Proceed"
		progressEnabled=apocalypseQuestFogPossessedReady(card)==true and apocalypseQuestCombatAvailable(card,playerIndex)
	elseif card.guid=="72099f" and questState~=nil and questState.step==1 then
		progressLabel="Proceed"
	elseif card.guid=="8cff07" and questState~=nil and questState.step==1 then
		progressLabel="Proceed"
		local rolled=gStates.apocalypseQuestRichMerchantRoll~=nil and gStates.apocalypseQuestRichMerchantRoll[card.guid] or nil
		if rolled~=nil and rolled.mage==turnOrder[playerIndex].mage and rolled.result~="Black" then
			progressEnabled=false
			abandonEnabled=false
		end
	elseif card.guid=="a6d5cc" then
		if questState==nil or questState.step==1 then progressLabel="Proceed" end
		if questState~=nil and questState.step==2 then failLabel="2B - Fail" end
	end
	return {progress=progressEnabled,progressLabel=progressLabel,complete=completeEnabled,abandon=abandonEnabled,abandonLabel=abandonLabel,fail=failEnabled,failLabel=failLabel,
		fight=fightRelevant and apocalypseQuestCombatAvailable(card,playerIndex)}
end

function apocalypseQuestUpdateProgressButtons(card)
	if card==nil then return end
	if gStates.apocalypseQuestOfferRefilling==true or gStates.apocalypseQuestOfferMoving==true then
		gStates.apocalypseQuestOfferButtonRefreshPending=true
		return
	end
	if gStates.apocalypseQuestPendingChoice~=nil and gStates.apocalypseQuestPendingChoice[card.guid]~=nil then return end
	if gStates.apocalypseQuestCombatChoice~=nil and gStates.apocalypseQuestCombatChoice[card.guid]~=nil then return end
	local interfacePlayer=apocalypseQuestUnderSiegeInterfacePlayerIndex(card)
	if #apocalypseQuestDirectChoices(card,interfacePlayer)>0 then apocalypseQuestInterfaceAdd(card,true) return end
	local prefix="ApocalypseQuest"..card.guid
	--A direct branch UI has no normal Fight/Progress/Complete controls to update. Once the branch
	--advances the Quest, rebuild the interface instead of trying to set attributes on missing elements.
	local normalControls=false
	for _,element in ipairs(card.UI.getXmlTable() or {}) do
		if element.attributes~=nil and element.attributes.id==prefix.."Fight" then normalControls=true break end
	end
	if normalControls~=true then apocalypseQuestInterfaceAdd(card,true) return end
	local state=apocalypseQuestButtonState(card,interfacePlayer)
	local function enabledChanged(id,wanted)
		local current=string.lower(tostring(card.UI.getAttribute(prefix..id,"interactable") or "false"))=="true"
		return current~=(wanted==true)
	end
	local rebuild=enabledChanged("Progress",state.progress) or enabledChanged("Complete",state.complete) or
		enabledChanged("Abandon",state.abandon) or enabledChanged("Fail",state.fail)
	if rebuild==true and card.isSmoothMoving()==false then
		--Quest cards can remain resting=false indefinitely when a Shield/enemy is touching them. Scripted
		--movement is the real lifecycle boundary: once setPositionSmooth has finished, rebuild immediately.
		apocalypseQuestInterfaceAdd(card,true)
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
	card.UI.setAttribute(prefix.."ProgressText", "text", state.progressLabel or "Progress")
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
	card.UI.setAttribute(prefix.."FailText", "text", state.failLabel or "Fail")
	card.UI.setAttribute(prefix.."FailText", "color", state.fail and "#000000" or "#777777")
	if rebuild==true then
		local cardGUID=card.guid
		safeWaitCondition("Quests",function()
			local live=getObjectFromGUID(cardGUID)
			if live~=nil then apocalypseQuestInterfaceAdd(live,true) end
		end,function()
			local live=getObjectFromGUID(cardGUID)
			return live==nil or live.isSmoothMoving()==false
		end,5,function()
			local live=getObjectFromGUID(cardGUID)
			if live~=nil then apocalypseQuestInterfaceAdd(live,true) end
		end)
	end
end
function apocalypseQuestWhenResting(objectGUID,callback,timeout)
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
		if getObjectFromGUID(objectGUID)~=nil then apocalypseQuestWhenResting(objectGUID,callback,timeout) end
	end)
	return true
end

function apocalypseQuestInterfaceAdd(card, forceRebuild)
	if card==nil or card.type~="Card" then return end
	card.lock()
	--Reminder cards are deliberately parked outside the live Quest offer and must never regain their
	--Progress/Complete UI from a delayed resting/refresh callback left over from their final action.
	if gStates.apocalypseQuestReminderCards~=nil and gStates.apocalypseQuestReminderCards[card.guid]~=nil then
		apocalypseQuestInterfaceRemove(card)
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
			if live~=nil then apocalypseQuestInterfaceAdd(live,forceRebuild) end
		end,function()
			local live=getObjectFromGUID(cardGUID)
			return live==nil or live.isSmoothMoving()==false
		end,5,function()
			local live=getObjectFromGUID(cardGUID)
			if live~=nil then apocalypseQuestInterfaceAdd(live,forceRebuild) end
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
	local interfacePlayer=apocalypseQuestUnderSiegeInterfacePlayerIndex(card)
	local directChoices=apocalypseQuestDirectChoices(card,interfacePlayer)
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
		safeWaitFrames("Quests",function() local questCard=getObjectFromGUID(cardGUID) if questCard~=nil then apocalypseQuestInterfaceAdd(questCard) end end, 3)
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
				local label=color=="NoInventory" and "No Inventory" or color
				xml[#xml+1]=questButton("CombatColor_"..color,label,spots[index][1],spots[index][2],colors[color] or "#d8c79d",true)
			end
		end
		if combatPending.mode~="ExecutionGold" and combatPending.mode~="NobleWarriorGold" and combatPending.mode~="GuardDutyChoice" and combatPending.mode~="GuardDutyGold" then xml[#xml+1]=questButton("CombatCancel","Cancel",0,274,"#b5b5b5",true) end
		card.UI.setXmlTable(xml)
		return
	end
	if #directChoices>0 then
		local spots={{50,180},{-50,180},{50,227},{-50,227}}
		for index, choice in ipairs(directChoices) do
			local legal=apocalypseQuestDirectChoiceLegal(card,interfacePlayer,choice)
			if spots[index]~=nil then xml[#xml+1]=questButton("Direct_"..choice.key,choice.label or string.upper(choice.key),spots[index][1],spots[index][2],legal and "#d8c79d" or "#b5b5b5",legal) end
		end
		--Admiring Bard Step 2 uses three player-declared outcomes but must retain the Personal Quest
		--Abandon action as the fourth control. Once abandoned, directChoices disappears and Resume returns.
		local bardState=card.guid=="8455b5" and apocalypseQuestProgressState(card,interfacePlayer,false) or nil
		if bardState~=nil and bardState.step==2 and #directChoices==3 then
			local abandon=apocalypseQuestActionEnabled(card,interfacePlayer,"Abandon")
			xml[#xml+1]=questButton("Abandon","Abandon",spots[4][1],spots[4][2],abandon and "#d5b784" or "#b5b5b5",abandon)
		end
		card.UI.setXmlTable(xml)
		return
	end
	local state=apocalypseQuestButtonState(card,interfacePlayer)
	--The old text Fight button sat at y=133, which puts it on top of the Quest card where the card
	--itself can occlude attached UI. Put the standard Attack icon on a third row below the 2x2 controls.
	xml[#xml+1]=questAttackButton(state.fight)
	xml[#xml+1]=questButton("Progress", state.progressLabel or "Progress", 50, 180, state.progress and "#d8c79d" or "#b5b5b5", state.progress)
	xml[#xml+1]=questButton("Complete", "Complete", -50, 180, state.complete and "#a8c99a" or "#b5b5b5", state.complete)
	xml[#xml+1]=questButton("Abandon", state.abandonLabel, 50, 227, state.abandon and "#d5b784" or "#b5b5b5", state.abandon)
	xml[#xml+1]=questButton("Fail", state.failLabel or "Fail", -50, 227, state.fail and "#c99090" or "#b5b5b5", state.fail)
	card.UI.setXmlTable(xml)
end
function apocalypseQuestOfferCards(areaObjects)
	if areaObjects==nil and apocalypseQuestRefreshOfferCardsCache~=nil then return apocalypseQuestRefreshOfferCardsCache end
	local cards={}
	local known=gStates.apocalypseQuestCardGUIDs
	local first=apocalypseQuestOfferPosition(1)
	local last=apocalypseQuestOfferPosition(6)
	for _, obj in pairs(areaObjects or apocalypseQuestAreaObjects()) do
		if obj.type=="Card" and (known==nil or known[obj.guid]==true) then
			local pos=obj.getPosition()
			if pos[1]>first[1]-1.8 and pos[1]<last[1]+1.8 and math.abs(pos[3]-first[3])<2.6 then cards[#cards+1]=obj end
		end
	end
	table.sort(cards, function(a,b) return a.getPosition()[1]<b.getPosition()[1] end)
	return cards
end
function apocalypseQuestMoveCard(card, target, areaObjects, offerCards)
	if card==nil or target==nil then return {} end
	areaObjects=areaObjects or apocalypseQuestAreaObjects()
	offerCards=offerCards or apocalypseQuestOfferCards(areaObjects)
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
			local rowOwner=apocalypseQuestIndependentShieldRowOwnerGUID(obj,offerCards)
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
function apocalypseQuestOfferMoveToLeft(card,onSettled)
	if card==nil then return false end
	if gStates.apocalypseQuestOfferMoving==true then
		gStates.apocalypseQuestOfferButtonRefreshPending=true
		return false
	end
	gStates.apocalypseQuestOfferMoving=true
	local cardGUID=card.guid
	local areaObjects=apocalypseQuestAreaObjects()
	local offerCards=apocalypseQuestOfferCards(areaObjects)
	local ordered={card}
	local movedGUIDs={}
	for _, offerCard in pairs(offerCards) do if offerCard.guid~=card.guid then ordered[#ordered+1]=offerCard end end
	local orderedGUIDs={}
	for i=#ordered, 1, -1 do
		orderedGUIDs[#orderedGUIDs+1]=ordered[i].guid
		for _,guid in ipairs(apocalypseQuestMoveCard(ordered[i], apocalypseQuestOfferPosition(i), areaObjects, offerCards)) do movedGUIDs[guid]=true end
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
	local target=apocalypseQuestScorePosition(score, details.seatPos)
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
		marker.setDescription("Quest Score")
		marker.setGMNotes("")
		local scale=source.getScale()
		marker.setScale({scale[1]*1.25, scale[2]*1.25, scale[3]*1.25})
		marker.setPosition(target)
		marker.setRotation({0,180,0})
		if gStates.apocalypseQuestScoreMarkers==nil then gStates.apocalypseQuestScoreMarkers={} end
		gStates.apocalypseQuestScoreMarkers[mage]=marker.guid
		details.questScoreGUID=marker.guid
		if announce==true then broadcastToAll("Quest Score marker restored for "..tostring(mage)..".",{1,1,0.5}) end
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
function apocalypseQuestScoreGain(playerIndex, amount)
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
		marker.setPosition(apocalypseQuestScorePosition(score, details.seatPos))
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
		local scorePos=apocalypseQuestScorePosition(score, details.seatPos)
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
	local areaObjects=apocalypseQuestAreaObjects()
	local offerCards=apocalypseQuestOfferCards(areaObjects)
	for _, obj in pairs(areaObjects) do
		if obj.guid~=card.guid and obj.getName()=="Shield" then
			local pos=obj.getPosition()
			local normalFootprint=math.abs(pos[1]-source[1])<1.7 and math.abs(pos[3]-source[3])<2.5 and pos[2]>source[2]-0.25 and pos[2]<source[2]+3.0
			local rowOwner=apocalypseQuestIndependentShieldRowOwnerGUID(obj,offerCards)
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
function apocalypseQuestReminderPosition(slot)
	slot=math.max(1, tonumber(slot) or 1)
	--The first five reminder slots line up directly above the neutral + player Quest Shield bags.
	--Additional reminders wrap into another row while staying in the same Quest component area.
	local column=(slot-1)%5
	local row=math.floor((slot-1)/5)
	return {59.25+(column*4.20), 1.14, 18.61+(row*5.10)}
end
function apocalypseQuestReminderSlot(cardGUID)
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
function apocalypseQuestHasActiveReminderToken(card)
	if card==nil then return false end
	local quest=apocalypseQuestData[card.guid]
	if quest==nil or quest.keepToken~=true or quest.questTokens==nil then return false end
	for _, tokenGUID in ipairs(quest.questTokens) do
		local token=getObjectFromGUID(tokenGUID)
		if token~=nil and apocalypseQuestTokenFaceUp(token)==true then return true end
	end
	return false
end
function apocalypseQuestParkReminder(card)
	if card==nil then return false end
	local quest=apocalypseQuestData[card.guid]
	if quest==nil or quest.keepToken~=true then return false end
	apocalypseQuestReturnRevealBag(card)
	if gStates.apocalypseQuestProgress~=nil then gStates.apocalypseQuestProgress[card.guid]=nil end
	if gStates.apocalypseQuestPendingChoice~=nil then gStates.apocalypseQuestPendingChoice[card.guid]=nil end
	apocalypseQuestInterfaceRemove(card)
	apocalypseQuestRemoveShields(card)
	local slot=apocalypseQuestReminderSlot(card.guid)
	card.lock()
	card.setRotationSmooth({0,180,0})
	card.setPositionSmooth(apocalypseQuestReminderPosition(slot))
	broadcastToAll("Quest reminder: \""..apocalypseQuestName(card).."\" moved beside the Quest Shield bags until its Quest marker(s) are discarded.", {1,1,0.5})
	safeWaitFrames("Quests",function() apocalypseQuestRefreshReminderCards() end, 3)
	apocalypseQuestRefreshAfterMarkerChange()
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
		if card~=nil then card.lock() apocalypseQuestInterfaceRemove(card) end
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
		broadcastToAll("Quest reminder: all markers from \""..apocalypseQuestName(card).."\" were returned; the Quest card is returning to the Quest deck cycle.", {1,1,0.5})
		apocalypseQuestBottomDeck(card)
	end
	return #ready>0
end
function apocalypseQuestFinishCompletedCard(card)
	if card==nil then return false end
	if gStates.apocalypseQuestMoveAttachments~=nil then gStates.apocalypseQuestMoveAttachments[card.guid]=nil end
	local quest=apocalypseQuestData[card.guid]
	if quest~=nil and quest.keepToken==true then return apocalypseQuestParkReminder(card) end
	return apocalypseQuestBottomDeck(card)
end
function apocalypseQuestBottomDeck(card,onComplete)
	if card==nil then if onComplete~=nil then onComplete(false) end return false end
	if card.guid=="a6d5cc" then gStates.apocalypseQuestUnderSiegeReady=nil gStates.apocalypseQuestUnderSiegeStep2=nil end
	if card.guid=="37e2ce" then gStates.apocalypseQuestFreeWineAssault=nil end
	if card.guid=="72099f" then gStates.apocalypseQuestGoblinWarrens={} end
	apocalypseQuestReturnRevealBag(card)
	if card.guid=="b401dc" and (gStates.apocalypseQuestVeryPersonalSuccess==nil or gStates.apocalypseQuestVeryPersonalSuccess[card.guid]~=true) then apocalypseQuestDisbandVeryPersonalUnit(card) end
	--Round refresh/failure can remove an unfinished Quest after it has already granted a reminder marker.
	--Such a card follows the same reminder rule as a normally completed Quest.
	if apocalypseQuestHasActiveReminderToken(card)==true and (gStates.apocalypseQuestReminderCards==nil or gStates.apocalypseQuestReminderCards[card.guid]==nil) then
		local parked=apocalypseQuestParkReminder(card)
		if onComplete~=nil then onComplete(parked==true) end
		return parked
	end
	if gStates.apocalypseQuestReminderCards~=nil then gStates.apocalypseQuestReminderCards[card.guid]=nil end
	if gStates.apocalypseQuestProgress~=nil then gStates.apocalypseQuestProgress[card.guid]=nil end
	if gStates.apocalypseQuestPendingChoice~=nil then gStates.apocalypseQuestPendingChoice[card.guid]=nil end
	if gStates.apocalypseQuestCombatChoice~=nil then gStates.apocalypseQuestCombatChoice[card.guid]=nil end
	if gStates.apocalypseQuestCombatLaunches~=nil then gStates.apocalypseQuestCombatLaunches[card.guid]=nil end
	if gStates.apocalypseQuestCombatEnemies~=nil then gStates.apocalypseQuestCombatEnemies[card.guid]=nil end
	if gStates.apocalypseQuestCombatBranch~=nil then gStates.apocalypseQuestCombatBranch[card.guid]=nil end
	if gStates.apocalypseQuestCursedHero~=nil then gStates.apocalypseQuestCursedHero[card.guid]=nil end
	if gStates.apocalypseQuestCursedHistory~=nil then gStates.apocalypseQuestCursedHistory[card.guid]=nil end
	if gStates.apocalypseQuestHerbalistRolls~=nil and gStates.apocalypseQuestHerbalistRolls[card.guid]~=nil then
		local roll=gStates.apocalypseQuestHerbalistRolls[card.guid]
		local die=roll.dieGUID~=nil and getObjectFromGUID(roll.dieGUID) or nil
		if die~=nil then die.destruct() end
		if gStates.apocalypseQuestRollDice~=nil and roll.dieGUID~=nil then gStates.apocalypseQuestRollDice[roll.dieGUID]=nil end
		gStates.apocalypseQuestHerbalistRolls[card.guid]=nil
	end
	if gStates.apocalypseQuestDirectBranch~=nil then gStates.apocalypseQuestDirectBranch[card.guid]=nil end
	if gStates.apocalypseQuestCombatStarted~=nil then gStates.apocalypseQuestCombatStarted[card.guid]=nil end
	if gStates.apocalypseQuestRewardCompletionPending~=nil then gStates.apocalypseQuestRewardCompletionPending[card.guid]=nil end
	if gStates.apocalypseQuestMineDoomColor~=nil then gStates.apocalypseQuestMineDoomColor[card.guid]=nil end
	if gStates.apocalypseQuestStepColor~=nil then gStates.apocalypseQuestStepColor[card.guid]=nil end
	if gStates.apocalypseQuestRichMerchantRoll~=nil then gStates.apocalypseQuestRichMerchantRoll[card.guid]=nil end
	if gStates.apocalypseQuestRichMerchantHidden~=nil then gStates.apocalypseQuestRichMerchantHidden[card.guid]=nil end
	if gStates.apocalypseQuestVeryPersonalSuccess~=nil then gStates.apocalypseQuestVeryPersonalSuccess[card.guid]=nil end
	if gStates.apocalypseQuestRevealDone~=nil then gStates.apocalypseQuestRevealDone[card.guid]=nil end
	if gStates.apocalypseQuestRevealPending~=nil then gStates.apocalypseQuestRevealPending[card.guid]=nil end
	if apocalypseQuestRevealWaitScheduled~=nil then apocalypseQuestRevealWaitScheduled[card.guid]=nil end
	apocalypseQuestInterfaceRemove(card)
	local deck=apocalypseQuestLiveDeck()
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
					broadcastToAll("Quest cleanup: a Quest marker from \""..apocalypseQuestName(card).."\" returned to the Quest Token bag.", {1,1,0.5})
				else
					broadcastToAll("Quest cleanup: a Quest marker from \""..apocalypseQuestName(card).."\" could not be returned because the Quest Token bag is missing.", {1,0.55,0.2})
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
			local detached=clearPossessedEnemy(obj)
			local possessedDiscard=getObjectFromGUID(GUID.bag.discard.possessed)
			for _, token in ipairs(detached or {}) do if possessedDiscard~=nil then possessedDiscard.putObject(token) else token.destruct() end end
			local pugType=monsterPugs[obj.guid].pugType
			local discardGUID=({gray=GUID.bag.discard.keepGarrison,purple=GUID.bag.discard.towerGarrison,white=GUID.bag.discard.cityGarrison,
				red=GUID.bag.discard.draconum,green=GUID.bag.discard.orcs,tan=GUID.bag.discard.dungeon})[pugType]
			local destination=discardGUID~=nil and getObjectFromGUID(discardGUID) or nil
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
		local liveDeck=apocalypseQuestLiveDeck()
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
			local stagedDeck=getObjectFromGUID(deckGUID) or apocalypseQuestLiveDeck()
			if stagedCard==nil or stagedDeck==nil or stagedDeck.guid==stagedCard.guid then
				if onComplete~=nil then onComplete(false) end
				return
			end
			local merged=putCardAtBottom(stagedDeck,stagedCard)
			local liveDeck=merged~=nil and (merged.type=="Deck" or merged.type=="Card") and merged or apocalypseQuestLiveDeck()
			if liveDeck~=nil then GUID.deck.apocalypseQuest=liveDeck.guid end
			refreshOutOfTurnActions(nil,nil,true)
			apocalypseQuestRefreshAfterMarkerChange()
			if onComplete~=nil then
				--The caller may start the next return only after TTS has produced the resulting live deck.
				safeWaitFrames("Quests",function() onComplete(liveDeck~=nil) end,1)
			end
		end,2)
	end
	if attachmentsClear()==true then finishBottomDeck()
	else safeWaitCondition("Quests",finishBottomDeck,attachmentsClear,2.0,finishBottomDeck) end
	return true
end
function apocalypseQuestClaimAbandonedPersonal(card, playerIndex)
	local quest=card~=nil and apocalypseQuestData[card.guid] or nil
	if quest==nil or quest.questType~="Personal" then return true end
	if apocalypseQuestPersonalShieldOwner(card)~=nil then return true end
	local neutral=apocalypseQuestNeutralShield(card)
	if neutral==nil then return true end
	local position=neutral.getPosition()
	local rotation=neutral.getRotation()
	--Create the player's replacement before deleting the neutral Shield so a missing player Shield
	--bag cannot lose the Quest marker. If this action is about to reorder the offer, create the replacement
	--at the Quest's planned destination rather than flashing it over the old offer slot first.
	local surface=apocalypseQuestPlannedWorldPosition(card,position)
	local target=apocalypseQuestRaisedPiecePosition(surface)
	local shield=apocalypseQuestTakePlayerShield(playerIndex, surface)
	if shield==nil then return false end
	neutral.destruct()
	shield.unlock()
	shield.setRotationSmooth(rotation)
	shield.setPositionSmooth(target)
	apocalypseQuestRegisterMoveAttachment(card,shield,target)
	return true
end
function apocalypseQuestResolveStepAction(card, playerIndex, action, option, playerColor, rewindReady)
	if card==nil or option==nil or turnOrder[playerIndex]==nil then return false end
	if card.isSmoothMoving()==true then
		local cardGUID=card.guid
		safeWaitCondition("Quests",function()
			local live=getObjectFromGUID(cardGUID)
			if live~=nil then apocalypseQuestResolveStepAction(live,playerIndex,action,option,playerColor,rewindReady) end
		end,function()
			local live=getObjectFromGUID(cardGUID)
			return live==nil or live.isSmoothMoving()==false
		end,5,function()
			local live=getObjectFromGUID(cardGUID)
			if live~=nil then apocalypseQuestResolveStepAction(live,playerIndex,action,option,playerColor,rewindReady) end
		end)
		return true
	end
	local quest=apocalypseQuestData[card.guid]
	if quest==nil then return false end
	local state, questState=apocalypseQuestProgressState(card, playerIndex, true)
	if state==nil or state.completed==true then return false end
	if action=="Progress" and (card.guid=="485cc5" and tostring(option.key)=="1" or card.guid=="bb2828" and tostring(option.key)=="2") then
		local colors=card.guid=="485cc5" and apocalypseQuestMineDoomColors(playerIndex) or apocalypseQuestArtificerAvailableColors(card,playerIndex)
		if #colors==0 then return false end
		if gStates.apocalypseQuestStepColor==nil then gStates.apocalypseQuestStepColor={} end
		if gStates.apocalypseQuestStepColor[card.guid]==nil and #colors>1 then
			if gStates.apocalypseQuestCombatChoice==nil then gStates.apocalypseQuestCombatChoice={} end
			gStates.apocalypseQuestCombatChoice[card.guid]={playerIndex=playerIndex,colors=colors,mode="ProgressColor",action=action,key=tostring(option.key)}
			apocalypseQuestInterfaceAdd(card,true)
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
			if playerColor~=nil then broadcastToColor("This Quest step requires a Reputation Modifier of "..tostring(minimumReputationModifier).." or higher.", playerColor, warningColor) end
			return false
		end
	end
	if action=="Fail" and apocalypseQuestFailureReady(card,option,playerIndex)~=true then
		if playerColor~=nil then broadcastToColor("Start this Quest combat before resolving Fail.",playerColor,warningColor) end
		return false
	end
	if action~="Fail" and apocalypseQuestStepSpecialLegal(card,playerIndex,option)~=true then
		if playerColor~=nil then broadcastToColor("The combat requirement for Quest step "..tostring(option.key).." has not been detected yet.",playerColor,warningColor) end
		return false
	end
	local questRewindOwner="Quest resolve "..tostring(card.guid).." "..tostring(playerIndex)
	if rewindReady~=true then
		if rewindTransactionOwnerActive(questRewindOwner)==true then return true end
		rewindTransactionStart(function() apocalypseQuestResolveStepAction(card,playerIndex,action,option,playerColor,true) end,questRewindOwner)
		return true
	end
	local function finishQuestResolution(delay)
		if delay~=nil and delay>0 then safeWaitTime("Quests",function() rewindTransactionFinish(questRewindOwner) end,delay)
		else rewindTransactionFinish(questRewindOwner) end
	end
	local guardDutyDistance=nil
	if action=="Complete" and card.guid=="08ffcf" and tostring(option.key)=="2" then
		guardDutyDistance=apocalypseQuestGuardDutyDistance(playerIndex)
		if guardDutyDistance==nil then
			if playerColor~=nil then broadcastToColor("Guard Duty could not measure a revealed-space path back to the merchant marker.",playerColor,{1,0.55,0.2}) end
			finishQuestResolution(0.5)
			return false
		end
	end
	--A Rich Merchant Step 1 must use the face of a real rolled mana die. The die can appear immediately
	--over slot 1 because that destination is already known; the Quest card starts moving there at once.
	--Black advances to Step 2; the other results leave Step 1 ready to Complete.
	if action=="Progress" and card.guid=="8cff07" and tostring(option.key)=="1" then
		if apocalypseQuestPlaceStepMarker(card,playerIndex,option,playerColor)~=true then finishQuestResolution(0.5) return false end
		if apocalypseQuestClaimAbandonedPersonal(card,playerIndex)~=true then
			if playerColor~=nil then broadcastToColor("The Personal Quest Shield could not be claimed.",playerColor,{1,0.55,0.2}) end
			finishQuestResolution(0.5)
			return false
		end
		apocalypseQuestBeginMoveAttachmentCapture(card,apocalypseQuestOfferPosition(1))
		if apocalypseQuestPositionProgressShield(card,playerIndex,option)~=true then
			apocalypseQuestEndMoveAttachmentCapture(card)
			if playerColor~=nil then broadcastToColor("Quest progress could not place the required Shield.",playerColor,{1,0.55,0.2}) end
			finishQuestResolution(0.5)
			return false
		end
		apocalypseQuestEndMoveAttachmentCapture(card)
		apocalypseQuestClearRewardCompletionGate(card,playerIndex)
		local started=apocalypseQuestRollVisibleManaDie(card,playerIndex,"A Rich Merchant",function(rolled,liveCard)
			if liveCard==nil then finishQuestResolution(0.5) return end
			if rolled==nil then
				--Stay on Step 1 so Proceed can simply be tried again if the physical die was unreadable.
				apocalypseQuestInterfaceAdd(liveCard,true)
				finishQuestResolution(0.5)
				return
			end
			apocalypseQuestResolveRichMerchantRoll(liveCard,playerIndex,rolled)
			if rolled=="Black" then apocalypseQuestAdvanceProgress(liveCard,state,option) end
			apocalypseQuestRefreshOfferButtons()
			finishQuestResolution(0.5)
		end,apocalypseQuestOfferPosition(1))
		if started~=true then
			if gStates.apocalypseQuestMoveAttachments~=nil then gStates.apocalypseQuestMoveAttachments[card.guid]=nil end
			apocalypseQuestPositionProgressShield(card,playerIndex,option)
			apocalypseQuestInterfaceAdd(card,true)
			finishQuestResolution(0.5)
			return false
		end
		apocalypseQuestCommitStepMarker(card,option)
		--Suppress the normal settled refresh while the visible die is still resolving; its callback refreshes
		--the Quest once the result is known. The physical offer still starts moving immediately.
		apocalypseQuestOfferMoveToLeft(card,function() end)
		return true
	end
	if action=="Progress" then
		if not (card.guid=="6175e8" and tostring(option.key)=="3") and apocalypseQuestPlaceStepMarker(card, playerIndex, option, playerColor)~=true then finishQuestResolution(0.5) return false end
		--Plan the offer move before any replacement/progress Shield is created so every new Shield
		--uses slot 1 immediately and is explicitly owned by this Quest during the reorder.
		apocalypseQuestBeginMoveAttachmentCapture(card,apocalypseQuestOfferPosition(1))
		if apocalypseQuestClaimAbandonedPersonal(card, playerIndex)~=true then
			apocalypseQuestEndMoveAttachmentCapture(card)
			if playerColor~=nil then broadcastToColor("The Personal Quest Shield could not be claimed.", playerColor, {1,0.55,0.2}) end
			finishQuestResolution(0.5)
			return false
		end
		if apocalypseQuestPositionProgressShield(card, playerIndex, option)~=true then
			apocalypseQuestEndMoveAttachmentCapture(card)
			if playerColor~=nil then broadcastToColor("Quest progress could not place the required Shield.", playerColor, {1,0.55,0.2}) end
			finishQuestResolution(0.5)
			return false
		end
		apocalypseQuestAwardStepPoint(card, playerIndex, option, state, questState)
		apocalypseQuestClearRewardCompletionGate(card,playerIndex)
		local fistfulSetup=card.guid=="66ea80" and tostring(option.key)=="1"
		local launchedNext=(card.guid=="485cc5" and tostring(option.key)=="1") or (card.guid=="d70436" and tostring(option.key)=="2")
		--Resolve the step immediately, as before. Anything leaving the Quest card moves away now. New objects
		--created on the card are explicitly captured for the imminent offer move, so they travel with the card
		--without waiting for the scripting zone to notice them.
		apocalypseQuestResolveSpecialEffect(card, playerIndex, option, false)
		apocalypseQuestEndMoveAttachmentCapture(card)
		if gStates.apocalypseQuestStepColor~=nil then gStates.apocalypseQuestStepColor[card.guid]=nil end
		apocalypseQuestAdvanceProgress(card, state, option)
		if launchedNext==true and apocalypseQuestCombatStartedThisTurn(card,state.step)==true then
			if gStates.apocalypseQuestCombatLaunches==nil then gStates.apocalypseQuestCombatLaunches={} end
			gStates.apocalypseQuestCombatLaunches[card.guid]=apocalypseQuestCombatLaunchKey(card,state)
		end
		--Commit before the offer snapshot. A Quest marker may still be travelling to the map and must not be
		--mistaken for an attachment that should follow the card left.
		apocalypseQuestCommitStepMarker(card, option)
		if fistfulSetup==true then
			--Let the card reach slot 1 before drawing from the same gray bag twice. The short gap also
			--ensures the first takeObject has fully left the container before the second extraction.
			apocalypseQuestOfferMoveToLeft(card,function(liveCard)
				apocalypseQuestPlaceFistfulEnemies(liveCard,function()
					apocalypseQuestRefreshOfferButtons()
					finishQuestResolution(0.5)
				end)
			end)
		else
			apocalypseQuestOfferMoveToLeft(card)
			finishQuestResolution(1.0)
		end
		broadcastToAll(tostring(turnOrder[playerIndex].mage).." progressed a Quest ("..tostring(option.key)..").", positionToColor(playerIndex))
		return true
	elseif action=="Complete" then
		if not (card.guid=="6175e8" and tostring(option.key)=="3") and apocalypseQuestPlaceStepMarker(card, playerIndex, option, playerColor)~=true then finishQuestResolution(0.5) return false end
		if apocalypseQuestClaimAbandonedPersonal(card, playerIndex)~=true then
			if playerColor~=nil then broadcastToColor("The Personal Quest Shield could not be claimed.", playerColor, {1,0.55,0.2}) end
			finishQuestResolution(0.5)
			return false
		end
		apocalypseQuestAwardStepPoint(card, playerIndex, option, state, questState)
		apocalypseQuestClearRewardCompletionGate(card,playerIndex)
		if not (card.guid=="6175e8" and tostring(option.key)=="3") then apocalypseQuestCommitStepMarker(card, option) end
		if quest.allPlayersComplete==true then
			state.completed=true
			apocalypseQuestRemovePlayerShield(card, playerIndex)
			if apocalypseQuestAllPlayersCompleted(card)==true then
				apocalypseQuestResolveSpecialEffect(card, playerIndex, option, true)
				broadcastToAll(tostring(turnOrder[playerIndex].mage).." completed the final required part of \""..quest.name.."\".", positionToColor(playerIndex))
				apocalypseQuestFinishCompletedCard(card)
			else
				apocalypseQuestBeginMoveAttachmentCapture(card,apocalypseQuestOfferPosition(1))
				apocalypseQuestResolveSpecialEffect(card, playerIndex, option, false)
				apocalypseQuestEndMoveAttachmentCapture(card)
				apocalypseQuestOfferMoveToLeft(card)
				broadcastToAll(tostring(turnOrder[playerIndex].mage).." completed their part of \""..quest.name.."\".", positionToColor(playerIndex))
			end
		else
			if card.guid=="bbd087" and tostring(option.key)=="3a" then
				apocalypseQuestSetRewardCompletionGate(card,playerIndex,"Complete")
				local started=apocalypseQuestNobleWarriorRollReward(card,playerIndex,function(success,questCard,results)
					if questCard==nil then finishQuestResolution(0.5) return end
					if success==true then
						local reserved={}
						local starting={}
						for _,basic in ipairs({"Blue","Red","Green","White"}) do starting[basic]=mineCrystalCount(playerIndex,basic) end
						local gold=0
						local black=0
						for _,color in ipairs(results or {}) do
							if color=="Gold" then gold=gold+1
							elseif color=="Black" then black=black+1
							elseif mineCrystalBagKey[color]~=nil then
								local effective=math.max(mineCrystalCount(playerIndex,color),starting[color]+(reserved[color] or 0))
								if effective<3 and apocalypseQuestGiveCrystal(playerIndex,color,nil,"Noble Warrior")==true then reserved[color]=(reserved[color] or 0)+1 end
							end
						end
						if black>0 then
							turnOrder[playerIndex].fameGain=(turnOrder[playerIndex].fameGain or 0)+black
							mainUIUpdate("Noble Warrior Black Fame")
						end
						if gold>0 then
							local pending={playerIndex=playerIndex,mode="NobleWarriorGold",goldRemaining=gold,startCounts={},granted={}}
							for _,color in ipairs({"Blue","Red","Green","White"}) do pending.startCounts[color]=mineCrystalCount(playerIndex,color) end
							pending.colors=apocalypseQuestNobleGoldColors(playerIndex,pending)
							if gStates.apocalypseQuestCombatChoice==nil then gStates.apocalypseQuestCombatChoice={} end
							gStates.apocalypseQuestCombatChoice[questCard.guid]=pending
							apocalypseQuestInterfaceAdd(questCard,true)
							--Keep the Quest rewind transaction open until every Gold has been chosen, or No Inventory
							--clears the remaining Golds.
							return
						end
						apocalypseQuestClearRewardCompletionGate(questCard,playerIndex)
						broadcastToAll(tostring(turnOrder[playerIndex].mage).." completed Noble Warrior (3A).",positionToColor(playerIndex))
						apocalypseQuestFinishCompletedCard(questCard)
					else
						apocalypseQuestClearRewardCompletionGate(questCard,playerIndex)
						apocalypseQuestInterfaceAdd(questCard,true)
					end
					finishQuestResolution(0.5)
				end)
				if started~=true then
					apocalypseQuestClearRewardCompletionGate(card,playerIndex)
					apocalypseQuestInterfaceAdd(card,true)
					finishQuestResolution(0.5)
				end
				return started
			end
			if card.guid=="8939c0" and tostring(option.key)=="1a" then
				--The Execution 1A awards a random mana-die reward. Resolve it with the same visible Quest die;
				--basic colours grant that crystal, Gold chooses a colour, and Black grants +1 Fame.
				apocalypseQuestSetRewardCompletionGate(card,playerIndex,"Complete")
				local started=apocalypseQuestRollExecutionReward(card,playerIndex,function(rolled,questCard)
					if questCard==nil then finishQuestResolution(0.5) return end
					if rolled==nil then
						if gStates.apocalypseQuestDirectBranch~=nil then gStates.apocalypseQuestDirectBranch[questCard.guid]=nil end
						apocalypseQuestInterfaceAdd(questCard,true)
						finishQuestResolution(0.5)
						return
					end
					if mineCrystalBagKey[rolled]~=nil then
						apocalypseQuestGiveCrystal(playerIndex,rolled,nil,"The Execution")
						apocalypseQuestClearRewardCompletionGate(questCard,playerIndex)
						apocalypseQuestResolveSpecialEffect(questCard,playerIndex,option,true)
						broadcastToAll(tostring(turnOrder[playerIndex].mage).." completed a Quest ("..tostring(option.key)..").",positionToColor(playerIndex))
						apocalypseQuestFinishCompletedCard(questCard)
						finishQuestResolution(0.5)
					elseif rolled=="Black" then
						--Black replaces the crystal reward with +1 Fame, in addition to 1A's normal Fame/Reputation.
						turnOrder[playerIndex].fameGain=(turnOrder[playerIndex].fameGain or 0)+1
						apocalypseQuestClearRewardCompletionGate(questCard,playerIndex)
						apocalypseQuestResolveSpecialEffect(questCard,playerIndex,option,true)
						mainUIUpdate("The Execution Black Fame")
						broadcastToAll(tostring(turnOrder[playerIndex].mage).." rolled Black for The Execution and gained +1 Fame instead of a crystal.",positionToColor(playerIndex))
						apocalypseQuestFinishCompletedCard(questCard)
						finishQuestResolution(0.5)
					elseif rolled=="Gold" then
						--Gold lets the player choose any basic crystal. Keep the Quest transaction open until that
						--mandatory choice is made, just as other Quest colour selections do.
						if gStates.apocalypseQuestCombatChoice==nil then gStates.apocalypseQuestCombatChoice={} end
						gStates.apocalypseQuestCombatChoice[questCard.guid]={playerIndex=playerIndex,colors={"Blue","Red","Green","White"},mode="ExecutionGold"}
						apocalypseQuestInterfaceAdd(questCard,true)
					end
				end)
				if started~=true then
					apocalypseQuestClearRewardCompletionGate(card,playerIndex)
					if gStates.apocalypseQuestDirectBranch~=nil then gStates.apocalypseQuestDirectBranch[card.guid]=nil end
					apocalypseQuestInterfaceAdd(card,true)
					finishQuestResolution(0.5)
				end
				return started
			end
			if card.guid=="08ffcf" and tostring(option.key)=="2" then
				--Guard Duty pays from the shortest revealed-space distance back to the merchant marker:
				--1-3 = one random basic crystal; 4-6 = two random basic crystals; 7+ = two chosen basic crystals.
				apocalypseQuestSetRewardCompletionGate(card,playerIndex,"Complete")
				if guardDutyDistance>=7 then
					local pending={playerIndex=playerIndex,mode="GuardDutyChoice",remaining=2,distance=guardDutyDistance,startCounts={},granted={}}
					pending.colors=apocalypseQuestNobleGoldColors(playerIndex,pending)
					if gStates.apocalypseQuestCombatChoice==nil then gStates.apocalypseQuestCombatChoice={} end
					gStates.apocalypseQuestCombatChoice[card.guid]=pending
					apocalypseQuestInterfaceAdd(card,true)
					broadcastToAll("Guard Duty distance is "..tostring(guardDutyDistance)..": choose two basic mana crystals.",positionToColor(playerIndex))
					return true
				end
				local crystalCount=guardDutyDistance<=3 and 1 or 2
				local started=apocalypseQuestGuardDutyRollRandomCrystals(card,playerIndex,crystalCount,function(success,questCard,results)
					if questCard==nil then finishQuestResolution(0.5) return end
					if success==true then
						local gold=0
						local black=0
						for _,rolled in ipairs(results or {}) do
							if rolled=="Gold" then gold=gold+1
							elseif rolled=="Black" then black=black+1
							elseif mineCrystalBagKey[rolled]~=nil then apocalypseQuestGiveCrystal(playerIndex,rolled,nil,"Guard Duty") end
						end
						if black>0 then
							turnOrder[playerIndex].fameGain=(turnOrder[playerIndex].fameGain or 0)+black
							mainUIUpdate("Guard Duty Black Fame")
							broadcastToAll("Guard Duty rolled "..tostring(black).." Black"..(black==1 and "" or " results").." and gained +"..tostring(black).." Fame.",positionToColor(playerIndex))
						end
						if gold>0 then
							local pending={playerIndex=playerIndex,mode="GuardDutyGold",goldRemaining=gold,distance=guardDutyDistance,startCounts={},granted={}}
							for _,color in ipairs({"Blue","Red","Green","White"}) do pending.startCounts[color]=mineCrystalCount(playerIndex,color) end
							pending.colors=apocalypseQuestNobleGoldColors(playerIndex,pending)
							if gStates.apocalypseQuestCombatChoice==nil then gStates.apocalypseQuestCombatChoice={} end
							gStates.apocalypseQuestCombatChoice[questCard.guid]=pending
							apocalypseQuestInterfaceAdd(questCard,true)
							broadcastToAll("Guard Duty rolled Gold"..(gold>1 and " x"..tostring(gold) or "")..": choose "..(gold==1 and "a basic mana crystal." or tostring(gold).." basic mana crystals."),positionToColor(playerIndex))
							return
						end
						apocalypseQuestClearRewardCompletionGate(questCard,playerIndex)
						broadcastToAll(tostring(turnOrder[playerIndex].mage).." completed Guard Duty: distance "..tostring(guardDutyDistance)..", random mana reward resolved.",positionToColor(playerIndex))
						apocalypseQuestFinishCompletedCard(questCard)
					else
						apocalypseQuestClearRewardCompletionGate(questCard,playerIndex)
						apocalypseQuestInterfaceAdd(questCard,true)
					end
					finishQuestResolution(0.5)
				end)
				if started~=true then
					apocalypseQuestClearRewardCompletionGate(card,playerIndex)
					apocalypseQuestInterfaceAdd(card,true)
					finishQuestResolution(0.5)
				end
				return started
			end
			if card.guid=="58a826" and tostring(option.key)=="3" then
				--The Herbalist completion stays in the offer while its visible mana die is rolling. This keeps
				--the Quest token/crystal available until the physical result has been read and transferred.
				apocalypseQuestSetRewardCompletionGate(card,playerIndex,"Complete")
				local started=apocalypseQuestGiveHerbalistReward(card,playerIndex,function(success,questCard)
					if questCard==nil then finishQuestResolution(0.5) return end
					if success==true then
						apocalypseQuestClearRewardCompletionGate(questCard,playerIndex)
						broadcastToAll(tostring(turnOrder[playerIndex].mage).." completed a Quest ("..tostring(option.key)..").", positionToColor(playerIndex))
						apocalypseQuestFinishCompletedCard(questCard)
					else
						apocalypseQuestClearRewardCompletionGate(questCard,playerIndex)
						apocalypseQuestInterfaceAdd(questCard,true)
					end
					finishQuestResolution(0.5)
				end)
				if started~=true then
					apocalypseQuestClearRewardCompletionGate(card,playerIndex)
					apocalypseQuestInterfaceAdd(card,true)
					finishQuestResolution(0.5)
				end
				return started
			end
			apocalypseQuestResolveSpecialEffect(card, playerIndex, option, true)
			broadcastToAll(tostring(turnOrder[playerIndex].mage).." completed a Quest ("..tostring(option.key)..").", positionToColor(playerIndex))
			apocalypseQuestFinishCompletedCard(card)
		end
		finishQuestResolution(1.0)
		return true
	elseif action=="Fail" then
		if apocalypseQuestClaimAbandonedPersonal(card, playerIndex)~=true then
			if playerColor~=nil then broadcastToColor("The Personal Quest Shield could not be claimed.", playerColor, {1,0.55,0.2}) end
			finishQuestResolution(0.5)
			return false
		end
		apocalypseQuestClearRewardCompletionGate(card,playerIndex)
		apocalypseQuestResolveFailureEffect(card,playerIndex,option)
		apocalypseQuestLoseReputation(playerIndex, quest.name, "fail")
		broadcastToAll(tostring(turnOrder[playerIndex].mage).." failed \""..quest.name.."\".", positionToColor(playerIndex))
		apocalypseQuestBottomDeck(card)
		finishQuestResolution(1.0)
		return true
	end
	finishQuestResolution(0.5)
	return false
end
local apocalypseQuestCardActionRestWait={}
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
	local underSiegeConfirm=false
	if card~=nil and card.guid=="a6d5cc" and action=="Progress" then
		local readyPlayer=apocalypseQuestUnderSiegeReadyPlayer()
		if readyPlayer~=nil then playerIndex=readyPlayer underSiegeConfirm=true end
	end
	local details=turnOrder[playerIndex]
	if card==nil or details==nil then return end
	if underSiegeConfirm==true then
		if apocalypseQuestAnyHumanMayConfirm(player.color)~=true then return end
	elseif legalPlayerCheck(player.color, details.seatPos, "NoDummyException")~=true then return end
	local offered=false
	for _, offerCard in pairs(apocalypseQuestOfferCards()) do if offerCard.guid==guid then offered=true break end end
	if offered~=true then apocalypseQuestInterfaceRemove(card) return end
	local quest=apocalypseQuestData[card.guid]
	if quest==nil then return end

	if action=="CombatCancel" then
		local pendingCombat=gStates.apocalypseQuestCombatChoice~=nil and gStates.apocalypseQuestCombatChoice[card.guid] or nil
		if pendingCombat~=nil and (pendingCombat.mode=="ExecutionGold" or pendingCombat.mode=="NobleWarriorGold" or pendingCombat.mode=="GuardDutyChoice" or pendingCombat.mode=="GuardDutyGold") then return end
		if gStates.apocalypseQuestCombatChoice~=nil then gStates.apocalypseQuestCombatChoice[card.guid]=nil end
		apocalypseQuestInterfaceAdd(card,true)
		return
	end
	if action:sub(1,12)=="CombatColor_" then
		local pendingCombat=gStates.apocalypseQuestCombatChoice~=nil and gStates.apocalypseQuestCombatChoice[card.guid] or nil
		local color=action:sub(13)
		if pendingCombat==nil or pendingCombat.playerIndex~=playerIndex then
			if gStates.apocalypseQuestCombatChoice~=nil then gStates.apocalypseQuestCombatChoice[card.guid]=nil end
			apocalypseQuestInterfaceAdd(card,true)
			return
		end
		local allowed=false
		for _, possible in ipairs(pendingCombat.colors or {}) do if possible==color then allowed=true break end end
		gStates.apocalypseQuestCombatChoice[card.guid]=nil
		if allowed==true and pendingCombat.mode=="GuardDutyChoice" then
			if color=="NoInventory" then
				--Nothing more can legally be gained. Consume the remaining printed choices and finish cleanly.
				if #apocalypseQuestNobleGoldColors(playerIndex,pendingCombat)==1 and apocalypseQuestNobleGoldColors(playerIndex,pendingCombat)[1]=="NoInventory" then
					apocalypseQuestFinishGuardDutyChoice(card,playerIndex,pendingCombat.distance)
				else
					pendingCombat.colors=apocalypseQuestNobleGoldColors(playerIndex,pendingCombat)
					gStates.apocalypseQuestCombatChoice[card.guid]=pendingCombat
					apocalypseQuestInterfaceAdd(card,true)
				end
				return
			end
			pendingCombat.granted=pendingCombat.granted or {}
			pendingCombat.startCounts=pendingCombat.startCounts or {}
			if pendingCombat.startCounts[color]==nil then pendingCombat.startCounts[color]=mineCrystalCount(playerIndex,color) end
			local effective=math.max(mineCrystalCount(playerIndex,color),pendingCombat.startCounts[color]+(pendingCombat.granted[color] or 0))
			if effective<3 and apocalypseQuestGiveCrystal(playerIndex,color,nil,"Guard Duty")==true then
				pendingCombat.granted[color]=(pendingCombat.granted[color] or 0)+1
				pendingCombat.remaining=(pendingCombat.remaining or 1)-1
			end
			if (pendingCombat.remaining or 0)<=0 then
				apocalypseQuestFinishGuardDutyChoice(card,playerIndex,pendingCombat.distance)
			else
				pendingCombat.colors=apocalypseQuestNobleGoldColors(playerIndex,pendingCombat)
				gStates.apocalypseQuestCombatChoice[card.guid]=pendingCombat
				apocalypseQuestInterfaceAdd(card,true)
			end
			return
		elseif allowed==true and pendingCombat.mode=="GuardDutyGold" then
			if color=="NoInventory" then
				if #apocalypseQuestNobleGoldColors(playerIndex,pendingCombat)==1 and apocalypseQuestNobleGoldColors(playerIndex,pendingCombat)[1]=="NoInventory" then
					apocalypseQuestFinishGuardDutyGold(card,playerIndex,pendingCombat.distance)
				else
					pendingCombat.colors=apocalypseQuestNobleGoldColors(playerIndex,pendingCombat)
					gStates.apocalypseQuestCombatChoice[card.guid]=pendingCombat
					apocalypseQuestInterfaceAdd(card,true)
				end
				return
			end
			pendingCombat.granted=pendingCombat.granted or {}
			pendingCombat.startCounts=pendingCombat.startCounts or {}
			if pendingCombat.startCounts[color]==nil then pendingCombat.startCounts[color]=mineCrystalCount(playerIndex,color) end
			local effective=math.max(mineCrystalCount(playerIndex,color),pendingCombat.startCounts[color]+(pendingCombat.granted[color] or 0))
			if effective<3 and apocalypseQuestGiveCrystal(playerIndex,color,nil,"Guard Duty")==true then
				pendingCombat.granted[color]=(pendingCombat.granted[color] or 0)+1
				pendingCombat.goldRemaining=(pendingCombat.goldRemaining or 1)-1
			end
			if (pendingCombat.goldRemaining or 0)<=0 then
				apocalypseQuestFinishGuardDutyGold(card,playerIndex,pendingCombat.distance)
			else
				pendingCombat.colors=apocalypseQuestNobleGoldColors(playerIndex,pendingCombat)
				gStates.apocalypseQuestCombatChoice[card.guid]=pendingCombat
				apocalypseQuestInterfaceAdd(card,true)
			end
			return
		elseif allowed==true and pendingCombat.mode=="NobleWarriorGold" then
			if color=="NoInventory" then
				--This button is only offered when all four basic-crystal inventories are full. It consumes
				--any remaining Gold results so the Quest can always be cleared.
				if #apocalypseQuestNobleGoldColors(playerIndex,pendingCombat)==1 and apocalypseQuestNobleGoldColors(playerIndex,pendingCombat)[1]=="NoInventory" then
					apocalypseQuestFinishNobleGold(card,playerIndex)
				else
					pendingCombat.colors=apocalypseQuestNobleGoldColors(playerIndex,pendingCombat)
					gStates.apocalypseQuestCombatChoice[card.guid]=pendingCombat
					apocalypseQuestInterfaceAdd(card,true)
				end
				return
			end
			pendingCombat.granted=pendingCombat.granted or {}
			pendingCombat.startCounts=pendingCombat.startCounts or {}
			if pendingCombat.startCounts[color]==nil then pendingCombat.startCounts[color]=mineCrystalCount(playerIndex,color) end
			local effective=math.max(mineCrystalCount(playerIndex,color),pendingCombat.startCounts[color]+(pendingCombat.granted[color] or 0))
			if effective<3 and apocalypseQuestGiveCrystal(playerIndex,color,nil,"Noble Warrior")==true then
				pendingCombat.granted[color]=(pendingCombat.granted[color] or 0)+1
				pendingCombat.goldRemaining=(pendingCombat.goldRemaining or 1)-1
			end
			if (pendingCombat.goldRemaining or 0)<=0 then
				apocalypseQuestFinishNobleGold(card,playerIndex)
			else
				pendingCombat.colors=apocalypseQuestNobleGoldColors(playerIndex,pendingCombat)
				gStates.apocalypseQuestCombatChoice[card.guid]=pendingCombat
				apocalypseQuestInterfaceAdd(card,true)
			end
			return
		elseif allowed==true and pendingCombat.mode=="ExecutionGold" then
			local selected=apocalypseQuestChoiceOption(card,"1a")
			if selected~=nil and apocalypseQuestGiveCrystal(playerIndex,color,nil,"The Execution")==true then
				apocalypseQuestClearRewardCompletionGate(card,playerIndex)
				apocalypseQuestResolveSpecialEffect(card,playerIndex,selected,true)
				broadcastToAll(tostring(turnOrder[playerIndex].mage).." chose a "..tostring(color).." crystal for The Execution.",positionToColor(playerIndex))
				apocalypseQuestFinishCompletedCard(card)
				safeWaitTime("Quests",function() rewindTransactionFinish("Quest resolve "..tostring(card.guid).." "..tostring(playerIndex)) end,0.5)
			else
				--If the chosen crystal cannot be taken (for example the Inventory already has 3), keep the
				--Gold choice open so the player may choose another basic colour.
				if gStates.apocalypseQuestCombatChoice==nil then gStates.apocalypseQuestCombatChoice={} end
				gStates.apocalypseQuestCombatChoice[card.guid]=pendingCombat
				apocalypseQuestInterfaceAdd(card,true)
			end
			return
		elseif allowed==true and pendingCombat.mode=="ProgressColor" then
			if gStates.apocalypseQuestStepColor==nil then gStates.apocalypseQuestStepColor={} end
			gStates.apocalypseQuestStepColor[card.guid]=color
			local selected=apocalypseQuestChoiceOption(card,pendingCombat.key)
			if selected~=nil then apocalypseQuestResolveStepAction(card,playerIndex,pendingCombat.action or "Progress",selected,player.color) end
		elseif allowed==true then apocalypseQuestLaunchCombat(card,playerIndex,player.color,color) end
		if getObjectFromGUID(card.guid)~=nil then apocalypseQuestInterfaceAdd(card,true) end
		return
	end
	if action:sub(1,7)=="Direct_" then
		local key=action:sub(8)
		local selected=nil
		for _, choice in ipairs(apocalypseQuestDirectChoices(card,playerIndex)) do if choice.key==key then selected=choice break end end
		if selected==nil or apocalypseQuestDirectChoiceLegal(card,playerIndex,selected)~=true then apocalypseQuestInterfaceAdd(card,true) return end
		if card.guid=="72099f" and selected.action=="GoblinWarrens" then
			apocalypseQuestStartGoblinWarrens(card,playerIndex,tonumber(key:match("(%d+)$")))
			return
		end
		local option=apocalypseQuestChoiceOption(card,key)
		if selected.action=="Combat" then
			if card.guid~="a6d5cc" then
				if gStates.apocalypseQuestDirectBranch==nil then gStates.apocalypseQuestDirectBranch={} end
				gStates.apocalypseQuestDirectBranch[card.guid]=key
			end
			if card.guid=="ce70fb" then
				if gStates.apocalypseQuestCombatBranch==nil then gStates.apocalypseQuestCombatBranch={} end
				gStates.apocalypseQuestCombatBranch[card.guid]=key
				apocalypseQuestLaunchCombat(card,playerIndex,player.color,key)
			else apocalypseQuestLaunchCombat(card,playerIndex,player.color,nil) end
			if getObjectFromGUID(card.guid)~=nil then apocalypseQuestInterfaceAdd(card,true) end
		else
			if card.guid=="8939c0" or card.guid=="82a935" then
				if gStates.apocalypseQuestDirectBranch==nil then gStates.apocalypseQuestDirectBranch={} end
				gStates.apocalypseQuestDirectBranch[card.guid]=key
			end
			--ResolveStepAction owns the refresh after its rewind transaction has advanced the Quest state.
			--Rebuilding here used the old state and could put the just-clicked branch choices straight back.
			apocalypseQuestResolveStepAction(card,playerIndex,selected.action,option,player.color)
		end
		return
	end
	if action=="Fight" then
		apocalypseQuestLaunchCombat(card,playerIndex,player.color,nil)
		if getObjectFromGUID(card.guid)~=nil and (gStates.apocalypseQuestCombatChoice==nil or gStates.apocalypseQuestCombatChoice[card.guid]==nil) then apocalypseQuestInterfaceAdd(card,true) end
		return
	end

	--The Fog Step 3 uses Proceed as its final combat launcher. It becomes available only after the
	--Possessed token has physically linked to the brown enemy on the Quest card.
	if action=="Progress" and card.guid=="dd35bb" then
		local questState=apocalypseQuestProgressState(card,playerIndex,false)
		if questState~=nil and questState.step==3 and apocalypseQuestFogPossessedReady(card)==true then
			apocalypseQuestLaunchCombat(card,playerIndex,player.color,nil)
			if getObjectFromGUID(card.guid)~=nil then apocalypseQuestInterfaceAdd(card,true) end
			return
		end
	end

	--Mine of Doom Step 2 presents its combat launcher in the normal Progress/Proceed slot.
	--It performs exactly the same launch path as the old separate Attack icon.
	if action=="Progress" and card.guid=="485cc5" then
		local questState=apocalypseQuestProgressState(card,playerIndex,false)
		if questState~=nil and questState.step==2 then
			apocalypseQuestLaunchCombat(card,playerIndex,player.color,nil)
			if getObjectFromGUID(card.guid)~=nil and (gStates.apocalypseQuestCombatChoice==nil or gStates.apocalypseQuestCombatChoice[card.guid]==nil) then apocalypseQuestInterfaceAdd(card,true) end
			return
		end
	end

	if action=="ChoiceCancel" then
		if gStates.apocalypseQuestPendingChoice~=nil then gStates.apocalypseQuestPendingChoice[card.guid]=nil end
		apocalypseQuestInterfaceAdd(card, true)
		return
	end
	if action:sub(1,7)=="Choice_" then
		local pending=gStates.apocalypseQuestPendingChoice~=nil and gStates.apocalypseQuestPendingChoice[card.guid] or nil
		if pending==nil or pending.playerIndex~=playerIndex then
			if gStates.apocalypseQuestPendingChoice~=nil then gStates.apocalypseQuestPendingChoice[card.guid]=nil end
			apocalypseQuestInterfaceAdd(card, true)
			return
		end
		local key=action:sub(8)
		local selected=nil
		for _, option in ipairs(apocalypseQuestCurrentOptions(card, playerIndex, pending.action)) do if option.key==key then selected=option break end end
		gStates.apocalypseQuestPendingChoice[card.guid]=nil
		if selected==nil then apocalypseQuestInterfaceAdd(card, true) return end
		apocalypseQuestResolveStepAction(card, playerIndex, pending.action, selected, player.color)
		if getObjectFromGUID(card.guid)~=nil then apocalypseQuestInterfaceAdd(card, true) end
		return
	end

	if action=="Abandon" then
		if card.guid=="a6d5cc" and apocalypseQuestPersonalShieldOwner(card)~=nil then
			broadcastToColor("Under Siege must be resolved with 2A or 2B; it cannot be abandoned after Step 1.",player.color,warningColor)
			apocalypseQuestInterfaceAdd(card,true)
			return
		end
		local ownerIndex, ownerShield=apocalypseQuestPersonalShieldOwner(card)
		local neutralShield=apocalypseQuestNeutralShield(card)
		if quest.questType=="Personal" and ownerIndex==nil and neutralShield~=nil then
			if apocalypseQuestPlayerMayAct(card, playerIndex)~=true then
				broadcastToColor("You cannot resume this Personal Quest while you have another Personal Quest.", player.color, warningColor)
				apocalypseQuestUpdateProgressButtons(card)
				return
			end
			if apocalypseQuestClaimAbandonedPersonal(card, playerIndex)~=true then
				broadcastToColor("The Personal Quest Shield could not be resumed.", player.color, {1,0.55,0.2})
				return
			end
			apocalypseQuestUpdateProgressButtons(card)
			broadcastToAll(tostring(details.mage).." resumed \""..tostring(quest.name).."\".", positionToColor(playerIndex))
			return
		end
		if quest.questType~="Personal" or ownerIndex~=playerIndex or ownerShield==nil then
			broadcastToColor("You can only abandon a Personal Quest marked with your own Shield.", player.color, warningColor)
			apocalypseQuestUpdateProgressButtons(card)
			return
		end
		if apocalypseQuestShieldSupplyBag("Neutral")==nil then
			broadcastToColor("The neutral Quest Shield bag could not be found.", player.color, {1,0.55,0.2})
			return
		end
		local shieldPos=ownerShield.getPosition()
		local shieldRot=ownerShield.getRotation()
		apocalypseQuestBeginMoveAttachmentCapture(card,apocalypseQuestOfferPosition(1))
		local surface=apocalypseQuestPlannedWorldPosition(card,{shieldPos[1],shieldPos[2]+0.08,shieldPos[3]})
		local target=apocalypseQuestRaisedPiecePosition(surface)
		local neutralShield=apocalypseQuestTakeNeutralShield(surface)
		if neutralShield==nil then
			apocalypseQuestEndMoveAttachmentCapture(card)
			broadcastToColor("A neutral Quest Shield could not be placed.", player.color, {1,0.55,0.2})
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
		apocalypseQuestOfferMoveToLeft(card)
		broadcastToAll(tostring(details.mage).." abandoned a Quest.", positionToColor(playerIndex))
		return
	end

	if action~="Progress" and action~="Complete" and action~="Fail" then return end
	local options=apocalypseQuestCurrentOptions(card, playerIndex, action)
	if #options==0 then
		local state=apocalypseQuestProgressState(card, playerIndex, false)
		local step=state~=nil and state.step or 1
		broadcastToColor(action.." is not available for step "..tostring(step).." of this Quest.", player.color, warningColor)
		apocalypseQuestUpdateProgressButtons(card)
		return
	end
	if apocalypseQuestOptionsNeedChoice(card, action, options)==true then
		apocalypseQuestShowChoice(card, playerIndex, action, options)
		return
	end
	apocalypseQuestResolveStepAction(card, playerIndex, action, options[1], player.color)
end
--Quest Deck GUIDs can change when TTS collapses/rebuilds a Deck while completed Quests are returned.
--Recover the live pile by its fixed table position and known Quest contents, then remember the new GUID.
function apocalypseQuestLiveDeck()
	local deck=getObjectFromGUID(GUID.deck.apocalypseQuest)
	if deck~=nil and (deck.type=="Deck" or deck.type=="Card") then return deck end
	local known=gStates.apocalypseQuestCardGUIDs or {}
	local deckX,deckZ=46.84,8.06
	for _,obj in pairs(apocalypseQuestAreaObjects()) do
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
				if staleCard~=nil then apocalypseQuestInterfaceRemove(staleCard) end
			end
		end
	end
	local areaObjects=apocalypseQuestAreaObjects()
	local cards=apocalypseQuestOfferCards(areaObjects)
	local currentQuestTurnSerial=gStates.apocalypseQuestTurnSerial or 0
	if #cards>=apocalypseQuestOfferTarget() or gStates.apocalypseQuestOfferDrawSerial==currentQuestTurnSerial then
		--The offer can legitimately remain short. Once this human turn has drawn its one replacement,
		--later UI/location refreshes may rebuild the buttons but must not take another Quest.
		for _, card in pairs(cards) do
			local ok, err=pcall(apocalypseQuestInterfaceAdd, card)
			if ok~=true then print("QUEST START-OF-TURN REFRESH ERROR: "..tostring(apocalypseQuestName(card))..": "..tostring(err)) end
		end
		return false
	end

	local deck=apocalypseQuestLiveDeck()
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
		local liveCards=apocalypseQuestOfferCards()
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
		for _, questCard in pairs(apocalypseQuestOfferCards()) do
			questCard.lock()
			local ok, err=pcall(apocalypseQuestInterfaceAdd, questCard)
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
		for _,guid in ipairs(apocalypseQuestMoveCard(cards[i], apocalypseQuestOfferPosition(i+1), areaObjects, cards)) do refillMovedGUIDs[guid]=true end
	end
	local pos=apocalypseQuestOfferPosition(1)
	--A player may manually cut/re-stack the Quest deck while testing. TTS can briefly expose the Deck
	--object before its internal card collection has finished rebuilding; takeObject in that window throws
	--the engine-side "Index was out of range" error. Re-fetch the live deck, wait for that container to settle,
	--then track the replacement itself only with isSmoothMoving().
	local function drawQuestReplacement(attempt)
		attempt=attempt or 1
		local liveDeck=apocalypseQuestLiveDeck()
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
	apocalypseQuestAreaZone()
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
		for _, data in pairs(questDeck.getObjects()) do if data.guid~=nil then gStates.apocalypseQuestCardGUIDs[data.guid]=true end end
	end
	local questDeckPosition={46.84, 1.14, 8.06}
	local startingQuests={"8939c0", "08ffcf", "81e795", "58a826", "734740", "72099f", "11d244", "8cdac4", "66ea80"}--The 9 starred starting Quest cards
	for a=#startingQuests, 2, -1 do
		local b=math.random(1, a)
		startingQuests[a], startingQuests[b]=startingQuests[b], startingQuests[a]
	end
	local startingCount=gStates.playerCount+2
	if gStates.playerCount==1 then startingCount=4 end
	local reserved={}
	local function currentQuestDeck()
		local deck=getObjectFromGUID(GUID.deck.apocalypseQuest)
		if deck~=nil and deck.type=="Deck" then return deck end
		return nil
	end
	local function dealQuestOffer()
		local deck=currentQuestDeck()
		if deck==nil then return end
		for offer=1,2 do
			local slot=offer
			safeTakeObject("Quests",deck,{position=apocalypseQuestOfferPosition(offer),rotation={0,180,0},smooth=false,callback_function=function(card)
				if card~=nil then card.lock() print("QUEST SETUP DRAW: slot "..tostring(slot).." <- "..tostring(apocalypseQuestName(card)).." ["..tostring(card.guid).."].") end
				safeWaitFrames("Quests",function() apocalypseQuestInterfaceAdd(card) end,2)
			end})
		end
	end
	local returnReserved
	returnReserved=function(index)
		if index>#reserved then safeWaitFrames("Quests",dealQuestOffer,2) return end
		local deck=currentQuestDeck()
		local card=reserved[index]
		if deck==nil or card==nil or (card.isDestroyed~=nil and card.isDestroyed()==true) then return end
		card.unlock()
		deck.putObject(card)
		safeWaitFrames("Quests",function() returnReserved(index+1) end,1)
	end
	--Instant movement is fast, but serialize each extraction so TTS always has a stable Quest Deck object.
	local takeReserved
	takeReserved=function(index)
		if index>startingCount then
			local deck=currentQuestDeck()
			if deck==nil then return end
			deck.shuffle()--Shuffle the unreserved starting Quests in with all other Quests
			safeWaitFrames("Quests",function() returnReserved(1) end,2)
			return
		end
		local deck=currentQuestDeck()
		if deck==nil then return end
		safeTakeObject("Quests",deck,{guid=startingQuests[index],position={questDeckPosition[1],4.00+(index*0.10),questDeckPosition[3]},rotation={0,180,180},smooth=false,callback_function=function(card)
			if card==nil then return end
			card.lock()
			reserved[#reserved+1]=card
			safeWaitFrames("Quests",function() takeReserved(index+1) end,1)
		end})
	end
	takeReserved(1)
end

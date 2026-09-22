-- Deck construction, shuffling and setup-time card-pool preparation.

--Deck Setup
function deckSetup()
	gStates.standardDeckFirstReturnedGUID={}
	--Shuffle all the decks
	local ToBeShuffled = {	GUID.deck.action, GUID.deck.artifact, GUID.deck.regularUnit, GUID.deck.eliteUnit, GUID.deck.spell,--Advanced Actions, Artifacts, Regular Units, Elite Units, Spells,
							GUID.deck.villageQuest, GUID.deck.monasteryQuest, GUID.deck.cityQuest, GUID.deck.uniqueQuest, GUID.deck.dayWeather,--Village Quests, Monastery Quests, City Quests, Unique Quests, Day Weather
							GUID.bag.skill.arythea,GUID.bag.skill.goldyx,GUID.bag.skill.norowas,GUID.bag.skill.tovak,GUID.bag.skill.krang,GUID.bag.skill.braevalar,GUID.bag.skill.ymirgh,GUID.bag.skill.wolfhawk,GUID.bag.skill.jormund,GUID.bag.skill.malek,GUID.bag.skill.zirtae}--skill containers
	for i=1, #ToBeShuffled, 1 do
		if getObjectFromGUID(ToBeShuffled[i])~=nil then getObjectFromGUID(ToBeShuffled[i]).shuffle() end
	end

	--Add and organise Apocalypse Dragon Quests
	if apocalypseQuestsUsed()==true then
		local apocalypseBag=getObjectFromGUID(GUID.bag.apocalypseDragon)
		if apocalypseBag~=nil then
			apocalypseQuestScoreMarkerSetup(apocalypseBag)
			safeTakeObject("SetupGame",apocalypseBag,{guid=GUID.bag.apocalypseQuestTokens, position={46.84, 1.00, 13.61}, rotation={0, 180, 0}, smooth=true, callback_function=function(_) apocalypseQuestTokenBagSetup() end})
			apocalypseBag.takeObject({guid="b26e9b", position={51.04, 0.98, 13.61}, rotation={0, 180, 0}, smooth=true})
			apocalypseBag.takeObject({guid="4ce329", position={55.24, 0.98, 13.61}, rotation={0, 180, 0}, smooth=true})
			--Dedicated Quest Shield supplies. Keep the normal Neutral / player-board bags untouched:
			--all shields created by Apocalypse Quests are drawn from these clones instead.
			gStates.apocalypseQuestShieldBagGUIDs={}
			local neutralSource=getObjectFromGUID(GUID.bag.neutralShield)
			if neutralSource==nil then
				neutralSource=apocalypseBag.takeObject({guid=GUID.bag.neutralShield,position={8.00,1.03,16.00},rotation={0,180,0},smooth=false})
			end
			if neutralSource~=nil then
				local neutralBag=neutralSource.clone()
				neutralBag.setPositionSmooth({59.55,1.03,13.60})
				neutralBag.setRotationSmooth({0,180,0})
				neutralBag.lock()
				gStates.apocalypseQuestShieldBagGUIDs.Neutral=neutralBag.guid
			end
			--Clone each active Mage Knight's existing infinite Shield bag immediately to the right of Neutral.
			--Active players pack left-to-right at +1.70 x with no gaps for empty seats.
			local questShieldSlot=1
			for seatPos=1, 4, 1 do
				local mage=gStates.positionMageKnight[seatPos]
				if mage~=nil and mage~="nobody" then
					for _, details in pairs(mageKnights) do
						if details.mage==mage then
							local source=getObjectFromGUID(details.shieldContainer)
							if source~=nil then
								local bag=source.clone()
								bag.setPositionSmooth({59.55+(questShieldSlot*1.70),1.03,13.60})
								bag.setRotationSmooth({0,180,0})
								bag.lock()
								gStates.apocalypseQuestShieldBagGUIDs[mage]=bag.guid
								questShieldSlot=questShieldSlot+1
							end
							break
						end
					end
				end
			end
			--Quest convenience supplies: Red, Green, Blue, White, Gold, Black in one row,
			--starting at x=58.70 and increasing x by 1.70 for each bag.
			local questManaKeys={"red","green","blue","white","gold","black"}
			for manaIndex, manaKey in ipairs(questManaKeys) do
				local source=getObjectFromGUID(GUID.bag.mana[manaKey])
				if source~=nil then
					local bag=source.clone()
					bag.setRotationSmooth({0,180,0})
					bag.setPositionSmooth({58.70+((manaIndex-1)*1.70), 1.28, 15.30})
					bag.lock()
				end
			end
			local spareDice=getObjectFromGUID(GUID.bag.spareDice)
			if spareDice~=nil then
				local questSetupDie=spareDice.takeObject({position={69.00,1.47,15.30},rotation={0,180,0},smooth=true})
				if questSetupDie~=nil then gStates.apocalypseQuestSetupDieGUID=questSetupDie.guid end
			end
			safeTakeObject("SetupGame",apocalypseBag,{guid=GUID.deck.apocalypseQuest,position={46.84,1.14,8.06},rotation={0,180,180},smooth=true,callback_function=function(obj)
				safeWaitCondition("SetupGame",function() apocalypseQuestDeckSetup(obj) end,function()
					return obj~=nil and getObjectFromGUID(obj.guid)~=nil and obj.isSmoothMoving()==false
				end,10,function() error("SetupGame timed out waiting for the Apocalypse Quest deck to settle.",2) end)
			end})
		end
	end

	--Ensure a Village unit is in the first draw for First Reconnaissance. Expansion filtering already
	--happened, so choose only from cards that are physically still in the Regular Unit deck.
	local villageUnits={"db04a7", "00ebf3", "506ea7", "c1f77c", "d55e5c", "b33811", "004558", "794e16", "484fa3", "a0a6cb", "e8acd7", "4339c4", "ff2a54", "246b0d", "bd1011"}
	if gStates.gameScenario=="First Reconnaissance" then
		local regularDeck=getObjectFromGUID(GUID.deck.regularUnit)
		local present={}
		for _,entry in ipairs(regularDeck.getObjects()) do present[entry.guid]=true end
		local available={}
		for _,guid in ipairs(villageUnits) do if present[guid]==true then available[#available+1]=guid end end
		if #available==0 then error("SetupGame could not find an eligible Village unit for First Reconnaissance.",2) end
		local unit=safeTakeObject("SetupGame",regularDeck,{guid=available[math.random(1,#available)],position={40.8,2.0,-4.2}})
		if unit==nil then error("SetupGame could not extract the First Reconnaissance Village unit.",2) end
	end

	--Organise the Artefact deck for "Quest for the Golden Grail" and "The Chaos Rift"
	if gStates.gameScenario=="Quest for the Golden Grail" or gStates.gameScenario=="The Chaos Rift" then
		getObjectFromGUID(GUID.deck.artifact).setPosition({46.84, 2.0, 2.31})--Raise Artifact Deck
		local card="085e59"
		if gStates.riseOfTheForgemasters>0 then card="00e5e2" end
		if gStates.gameScenario=="The Chaos Rift" then card="085e61" end
		getObjectFromGUID(GUID.deck.artifact).takeObject({guid=card, position={46.84, 1.0, 2.31}})--Put Golden Grail under artifact Deck
		if gStates.removeBonusCards==false then
			getObjectFromGUID(GUID.deck.artifact).takeObject({guid="085e69"}).destruct()--Delete Mysterious Box if not removed allready
		end
	end

	--Organise the Spell deck for "The Chaos Rift"
	if gStates.gameScenario=="The Chaos Rift" then
		getObjectFromGUID(GUID.deck.spell).setPosition({40.80, 2.0, -22.20})--Raise spell Deck
		getObjectFromGUID(GUID.deck.spell).takeObject({guid="2eb8e2", position={40.80, 1.07, -22.20}})--Put Golden Grail under artifact Deck
	end

	--Remove City-only units for scenarios without city access. Expansion filtering already removed
	--disabled cards, so this only touches City units that are actually still present.
	local cityUnits={"bb1660", "0fe22e", "5726ab", "f288ea", "f288e1", "5c2da0", "9c5c38"}
	if gStates.gameScenario=="The Lost Relic Blitz" or gStates.gameScenario=="The Chaos Rift" or gStates.gameScenario=="First Conquest" then
		local eliteDeck=getObjectFromGUID(GUID.deck.eliteUnit)
		local present={}
		for _,entry in ipairs(eliteDeck.getObjects()) do present[entry.guid]=true end
		for _,guid in ipairs(cityUnits) do
			if present[guid]==true then
				local unit=safeTakeObject("SetupGame",eliteDeck,{guid=guid,smooth=false})
				if unit~=nil then unit.destruct() end
			end
		end
	end

	--Forgemaster replacements should tolerate a card already being absent because another setup filter
	--removed it. Keep the deck layer safe rather than relying on SetupInterface option invariants.
	local function removeForgemasterReplacedCard(deckGUID,cardGUID)
		local deck=getObjectFromGUID(deckGUID)
		if deck==nil then return false end
		local present=false
		for _,entry in ipairs(deck.getObjects()) do
			if entry.guid==cardGUID then present=true break end
		end
		if present~=true then return false end
		local replaced=safeTakeObject("SetupGame",deck,{guid=cardGUID,smooth=false})
		if replaced==nil then return false end
		replaced.destruct()
		return true
	end

	--remove cards replaced by Rise of the Forgemaster
	local cardsReplaced={["2eb8d9"]=1, ["2eb8d3"]=1, ["2eb8d0"]=3}--spells
	for card, level in pairs(cardsReplaced) do
		if gStates.riseOfTheForgemasters>=level and gStates.riseOfTheForgemasters~=0 then removeForgemasterReplacedCard(GUID.deck.spell,card) end
	end
	local cardsReplaced={["085e56"]=1, ["085e59"]=1, ["085e65"]=1, ["085e50"]=1}--artifacts
	for card, level in pairs(cardsReplaced) do
		if gStates.riseOfTheForgemasters>=level and gStates.riseOfTheForgemasters~=0 then removeForgemasterReplacedCard(GUID.deck.artifact,card) end
	end
	local cardsReplaced={["65a1d5"]=1, ["05ef61"]=1, ["474418"]=1, ["6fdeb0"]=1, ["878d85"]=1, ["878d93"]=1, ["878d90"]=1, ["35aee6"]=1,
						 ["3d832c"]=1, ["1f362f"]=1, ["9de475"]=1, ["20cb85"]=1, ["d75285"]=2, ["141527"]=2, ["409fe8"]=2, ["1a1c02"]=2, ["8fac50"]=1}--advanced actions
	for card, level in pairs(cardsReplaced) do
		if gStates.riseOfTheForgemasters>=level and gStates.riseOfTheForgemasters~=0 then removeForgemasterReplacedCard(GUID.deck.action,card) end
	end
	if gStates.riseOfTheForgemasters>1 then
		offerAdjust(player, "-1", "e4372aOfferUp")
		if getObjectFromGUID(GUID.deck.goldyx)~=nil then--Goldyx modified Starting Card
			getObjectFromGUID(GUID.deck.goldyx).takeObject({guid="acd316"}).destruct()
			getObjectFromGUID(GUID.deck.goldyx).putObject(getObjectFromGUID(GUID.bag.forgemaster).takeObject({guid="911ddb", smooth=false}))
			getObjectFromGUID(GUID.deck.goldyx).shuffle()
		end
		if getObjectFromGUID(GUID.deck.krang)~=nil then--Krang modified Starting Card
			getObjectFromGUID(GUID.deck.krang).takeObject({guid="450573"}).destruct()
			getObjectFromGUID(GUID.deck.krang).putObject(getObjectFromGUID(GUID.bag.forgemaster).takeObject({guid="e8747d", smooth=false}))
			getObjectFromGUID(GUID.deck.krang).shuffle()
		end
		local concentrationSwap={["73b4e9"]="450562", ["1b9c29"]="450568", ["5d8084"]="450595", ["8bc5fe"]="450581", [GUID.deck.krang]="450575", ["c75919"]="450588", ["e2c66d"]="450552", ["8ad524"]="9a67a9", ["c05bd0"]="124af4", ["160535"]="e77fa9", ["3c7b00"]="8ec305"}
		local swapped={"d339f6", "0b071b", "4db67c", "0f7f81", "66fcf4"}
		local count=1
		for Deck, swap in pairs(concentrationSwap) do
			if getObjectFromGUID(Deck)~=nil then
				getObjectFromGUID(Deck).takeObject({guid=swap}).destruct()
				getObjectFromGUID(Deck).putObject(getObjectFromGUID(GUID.bag.forgemaster).takeObject({guid=swapped[count], smooth=false}))
				getObjectFromGUID(Deck).shuffle()
				count=count+1
			end
		end
	end
end

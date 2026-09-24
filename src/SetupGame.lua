-- Game construction and delayed setup: builds the selected game once Start is pressed.

-----------------
-- Setup the Game
-----------------
function randomCitiesAllowedForScenario(scenario)
	scenario=scenario or gStates.gameScenario
	return scenario~="First Reconnaissance" and scenario~="The Lost Relic" and scenario~="The Lost Relic Blitz" and scenario~="The Gauntlet"
end

function megapolisMaximumForSetup(scenarioRef, playersRef)
	scenarioRef=scenarioRef or gStates.scenarioRef
	playersRef=playersRef or gStates.playersRef
	local scenario=scenarioList~=nil and scenarioList[scenarioRef] or nil
	local setup=scenario~=nil and scenario[playersRef] or nil
	if scenario==nil or setup==nil or scenario.scenarioDetails==nil or scenario.scenarioDetails.megapolisPossible~=true or gStates.volkareCampAsCity==true then return 0 end
	local cityTiles=tonumber(setup.cityTiles) or 0
	if cityTiles<=0 then return 0 end
	if cityTiles<=2 then return math.min(2,cityTiles) end
	if cityTiles==3 then return 1 end
	return 0
end

function ensureSetupMegapolisMinimumLevels()
	local setup=scenarioList~=nil and scenarioList[gStates.scenarioRef]~=nil and scenarioList[gStates.scenarioRef][gStates.playersRef] or nil
	if setup==nil or setup.cityLevels==nil then return end
	local cityTiles=tonumber(setup.cityTiles) or 0
	if (gStates.megapolis or 0)>=1 and cityTiles>=1 and tonumber(setup.cityLevels[cityTiles])~=nil and setup.cityLevels[cityTiles]>0 and setup.cityLevels[cityTiles]<2 then setup.cityLevels[cityTiles]=2 end
	if (gStates.megapolis or 0)>=2 and cityTiles==2 then
		for index=1,2 do if tonumber(setup.cityLevels[index])~=nil and setup.cityLevels[index]>0 and setup.cityLevels[index]<2 then setup.cityLevels[index]=2 end end
	end
end

--Volkare's Camp terrain now lives permanently in the City tile bag. Keep one authoritative
--eligibility check so terrain filtering and the visible support setup cannot disagree.
local function setupUsesVolkareCampCity()
	return gStates~=nil and gStates.volkareCampAsCity==true and gStates.removeLostLegionExpansion~=true and
		gStates.gameScenario~="The War of Four" and gStates.gameScenario~="Volkare's Return" and
		gStates.gameScenario~="Volkare's Return Blitz" and gStates.gameScenario~="Volkare's Quest"
end

--Rise of the Forgemaster remains additive. Track its actual outstanding card-pack merges so fast
--machines continue immediately and slower machines wait only for the objects they really need.
local setupDeckMergesPending=0
local setupDeckExpectedQuantity={}
local setupRewindRequestPending=false

local function setupReleaseRewind()
	setupRewindRequestPending=false
	if rewindTransactionOwnerActive~=nil and rewindTransactionOwnerActive("Game setup")==true then
		rewindTransactionFinish("Game setup")
	end
end

local function setupQueueDeckMerge(container,deckGUID,objectGUID)
	local deck=getObjectFromGUID(deckGUID)
	if deck==nil then error("SetupGame missing destination deck "..tostring(deckGUID).." while merging "..tostring(objectGUID),2) end
	--Capture the destination quantity before any asynchronous merge callbacks can modify it. Several
	--expansions may target the same deck, so deriving this baseline inside the first callback can count
	--an earlier completed merge twice.
	if setupDeckExpectedQuantity[deckGUID]==nil then setupDeckExpectedQuantity[deckGUID]=deck.getQuantity() end
	setupDeckMergesPending=setupDeckMergesPending+1
	local p=deck.getPosition()
	local extracted=safeTakeObject("SetupGame",container,{
		guid=objectGUID,
		position={p[1],-2,p[3]},
		smooth=false,
		callback_function=function(obj)
			local added=(obj~=nil and obj.type=="Deck") and obj.getQuantity() or 1
			setupDeckExpectedQuantity[deckGUID]=setupDeckExpectedQuantity[deckGUID]+math.max(tonumber(added) or 1,1)
			deck.putObject(obj)
			setupDeckMergesPending=setupDeckMergesPending-1
		end})
	if extracted==nil then
		setupDeckMergesPending=setupDeckMergesPending-1
		error("SetupGame could not extract "..tostring(objectGUID).." for deck "..tostring(deckGUID),2)
	end
	return extracted
end

local function setupQueuedDeckMergesComplete()
	if setupDeckMergesPending~=0 then return false end
	for guid,expected in pairs(setupDeckExpectedQuantity) do
		local deck=getObjectFromGUID(guid)
		if deck==nil or deck.getQuantity()<expected then return false end
	end
	return true
end

local function setupRemoveCardRoster(cardsByDeck)
	for deckGUID,cardGUIDs in pairs(cardsByDeck or {}) do
		local deck=getObjectFromGUID(deckGUID)
		if deck==nil then error("SetupGame missing preloaded card deck "..tostring(deckGUID),2) end
		for _,cardGUID in ipairs(cardGUIDs or {}) do
			local card=safeTakeObject("SetupGame",deck,{guid=cardGUID,smooth=false})
			if card==nil then error("SetupGame missing preloaded card "..tostring(cardGUID).." in deck "..tostring(deckGUID),2) end
			card.destruct()
		end
	end
end

local function setupRemoveUnselectedCards()
	if gStates.removeLostLegionExpansion==true then setupRemoveCardRoster(setupContentRoster.lostLegion.cards) end
	if gStates.removeBonusCards==true then setupRemoveCardRoster(setupContentRoster.bonusCards.cards) end
	if gStates.coop~=0 and gStates.WarOfFourComp~=true then setupRemoveCardRoster(setupContentRoster.competitiveSpells.cards) end
	if gStates.gameScenario=="First Reconnaissance" then setupRemoveCardRoster(setupContentRoster.firstReconnaissanceExcluded.cards) end
end

local function setupMainDecksSettled()
	for _,guid in ipairs({GUID.deck.action,GUID.deck.artifact,GUID.deck.regularUnit,GUID.deck.eliteUnit,GUID.deck.spell}) do
		local deck=getObjectFromGUID(guid)
		if deck==nil or deck.resting~=true then return false end
	end
	return true
end

local function setupFinishDeckStage()
	local Wounds={[GUID.deck.spell]={"5c38e4","ab778d"},[GUID.deck.regularUnit]={"b5048c","718f39"}}
	if gStates.mageKnightLevels==false then
		afterLoad()
		for _,woundCard in pairs(Wounds) do getObjectFromGUID(woundCard[1]).destruct() getObjectFromGUID(woundCard[2]).destruct() end
	else
		for destDeck,woundCards in pairs(Wounds) do
			for a=1,2 do
				getObjectFromGUID(woundCards[a]).unlock()
				getObjectFromGUID(destDeck).putObject(getObjectFromGUID(woundCards[a]))
			end
		end
		gStates.magesSetup=true
		mageLevelBoard()
		UI.show("LevelUpRules")
		--Automated setup has handed control to the players. Do not hold the rewind transaction
		--open while they spend an arbitrary amount of time choosing their higher-level start.
		setupReleaseRewind()
	end
end

local function setupStartDeckStage()
	deckSetup()
	safeWaitCondition("SetupGame",setupFinishDeckStage,setupMainDecksSettled,10,function()
		setupReleaseRewind()
		error("SetupGame timed out waiting for the main decks to settle after deck setup.",2)
	end)
end

local setupFinalizationStarted=false
local setupMapStarted=false

--Configure each deployed rulebook independently. A single book that keeps moving must not block
--the page/lock state of every other manual.
local function setupConfigureRulebook(rulebook,page)
	if rulebook==nil then return end
	local configured=false
	local function apply()
		if configured==true or rulebook==nil then return end
		configured=true
		local numeric=tonumber(page)
		if numeric~=nil and rulebook.book~=nil then rulebook.book.setPage(math.floor(numeric)-1) end
		rulebook.lock()
	end
	--TTS can report a Book taken from a bag as resting before its Book component has finished
	--initialising. The old setup deliberately gave manuals five seconds before touching page/lock
	--state. Keep that asynchronous grace period; it does not hold up any other setup stage.
	safeWaitTime("SetupGame",function()
		if rulebook~=nil and rulebook.resting==true then
			apply()
			return
		end
		safeWaitCondition("SetupGame",apply,function()
			return rulebook~=nil and rulebook.resting==true
		end,10,function()
			--Reference manuals are not setup dependencies. Apply their final state even if TTS never
			--reports resting, rather than leaving every manual unconfigured.
			apply()
			print("SETUP WARNING: rulebook "..tostring(rulebook.guid).." did not report resting within 10 seconds after its initialization delay; configured anyway.")
		end)
	end,5)
end

local function setupCoreSystemsReady()
	if gStates.monsterSetupReady~=true then return false end
	if setupPlayersReady~=nil and setupPlayersReady()~=true then return false end
	if gStates.volkareCampSupportReady~=true then return false end
	if apocalypseQuestsUsed()==true and gStates.apocalypseQuestSetupReady~=true then return false end
	if apocalypseDragonScenario()==true and gStates.apocalypseDragonHeadsSetupReady~=true then return false end
	return true
end

--Layout everything needed for the game
local function setupGameRaw(player, mouseButton, id, rewindReady)
	if mouseButton=="-1" then
		if rewindReady~=true then
			if setupRewindRequestPending==true then return end
			setupRewindRequestPending=true
			rewindTransactionStart(function()
				setupRewindRequestPending=false
				setupGame(player,mouseButton,id,true)
			end,"Game setup",function() setupRewindRequestPending=false end)
			return
		end
		setupDeckMergesPending=0
		setupDeckExpectedQuantity={}
		setupFinalizationStarted=false
		setupMapStarted=false
		gStates.volkareCampSupportReady=true
		gStates.apocalypseQuestSetupReady=apocalypseQuestsUsed()~=true

		--Close the setup menu and update the Help button
		UI.setAttribute("Setup", "active", "false")
		UI.setAttribute("helpButtonRealText", "Text", "{en}Help{ru}Помощь{zh-tw}帮  助{zh-cn}帮  助{ko}도움말{es}Ayudar{fr}Aider{pt-br}Ajuda{de}Hilfe")
		UI.setAttribute("helpButtonReal", "onClick", "DisplayHelp")
		UI.setAttribute("helpButtonRealImage", "image", "Sliced Button/Button New Active")
		UI.setAttribute("helpButtonReal", "interactable", "true")
		UI.setAttribute("MonsterButtonRealImage", "image", "Sliced Button/Button New Active")
		UI.setAttribute("MonsterButtonReal", "interactable", "true")

		--New User and Mystery Solo setup. Build the player shell first, then run the chosen scenario
		--through the same default/lock path used by the normal setup UI. Quick starts should never inherit
		--rules-affecting state from whichever setup happened to be visible before the button was pressed.
		if id=="NewUser" or id=="RandomGame" then
			for a=1,4 do gStates.positionMageKnight[a]="nobody" end
			gStates.positionMageKnight[2]="Random"
			gStates.positionMageKnight[5]="Random"
			gStates.setupDummyMageChoice="Random"
			gStates.volkareSkills="Random"
			gStates.playerCount=1
			gStates.coop=1
			gStates.WarOfFourComp=false
			gStates.dayRound=false
			--Hero Challenges intentionally survive ordinary scenario browsing, but a quick start must begin
			--from a known baseline. Mystery Solo may roll them back on below when the selected setup permits it.
			gStates.heroChallenges=false

			if id=="NewUser" then
				applyScenarioSetupDefaults("First Reconnaissance")
			else
				--Choose from scenarios that actually provide a Solo setup row instead of maintaining a name blacklist.
				--First Reconnaissance remains reserved for the dedicated walkthrough button; Custom remains excluded
				--by the historical #scenarioList-1 range.
				local soloScenarios={}
				for scenarioRef=2,#scenarioList-1 do
					local scenario=scenarioList[scenarioRef]
					local soloSetup=scenario~=nil and scenario[5] or nil
					if scenario~=nil and scenario[1]~="First Reconnaissance" and soloSetup~=nil and soloSetup.rounds~=nil then
						soloScenarios[#soloScenarios+1]=scenarioRef
					end
				end
				if #soloScenarios==0 then error("Mystery Solo could not find a scenario with a valid Solo setup.",2) end
				local selectedRef=soloScenarios[math.random(1,#soloScenarios)]
				applyScenarioSetupDefaults(scenarioList[selectedRef][1])

				--Preserve Mystery Solo's existing option roster/probabilities, but respect the canonical locks
				--that scenarioSelection just rebuilt instead of duplicating scenario-name special cases here.
				local function rollOption(optionId,threshold)
					if UI.getAttribute(optionId,"interactable")=="True" then
						optionsUpdate(nil,math.random(1,10)>=threshold and "True" or "False",optionId)
					end
				end
				rollOption("removeShadesOfTezlaMonsters",7)
				rollOption("removeApocalypseTerrain",7)
				rollOption("randomTileOrientation",8)
				rollOption("randomCities",8)
				if gStates.gameScenario~="Druid Nights" then
					rollOption("startAtNight",8)
					rollOption("darknessComing",8)
				end
				rollOption("useCustomMageKnights",8)
				if gStates.useCustomMageKnights~=true and (gStates.riseOfTheForgemasters or 0)==0 then rollOption("heroChallenges",8) end
				rollOption("apocalypseQuestCards",8)
				rollOption("rampageAmbush",8)
				if gStates.rampageAmbush~=true then rollOption("rampagePursuit",8) end
				rollOption("volkareCampAsCity",8)

				if UI.getAttribute("RampageSelection","interactable")=="True" and math.random(1,10)>=8 then
					local rampageMode=math.random(0,2)
					if rampageMode==1 then
						RampageSelection(nil,"True","RampageSelection")
					elseif rampageMode==2 then
						MoreRampageSelection(nil,"True","MoreRampageSelection")
					end
				end

				local megapolisMaximum=megapolisMaximumForSetup(gStates.scenarioRef,gStates.playersRef)
				if gStates.volkareCampAsCity==false and megapolisMaximum>0 and math.random(1,10)>=8 then
					gStates.megapolis=math.random(0,megapolisMaximum)
					ensureSetupMegapolisMinimumLevels()
				end
			end
		end

		--Apply the chosen starting time immediately. setupPreview updates the Source board, rules state,
		--movement costs/UI and terrain tint without running round-transition-only work.
		dayNight(gStates.startAtNight~=true,true)

		--Put solo player in prefered positions
		if gStates.playerCount==1 then
			for posPriority=1, 4, 1 do
				if gStates.positionMageKnight[posPriority]~="nobody" and posPriority~=2 then
					broadcastToAll("{en}Changed setup Positions to be more central.{ru}Позиции игроков были передвинуты ближе к центру.{zh-tw}更改摆件位置，使其更加集中。{zh-cn}更改摆件位置，使其更加集中。{ko}설정의 위치를 좀더 중앙에 맞게 하였습니다.{es}Se cambiaron las posiciones de configuración para que sean más centrales.{fr}Positions de configuration modifiées pour être plus centrales.{pt-br}Mudou a Configuração das posições para ser mais central.{de}Die Aufstellungspositionen wurden geändert, um zentraler zu sein.", {1, 1, 1})
					gStates.positionMageKnight[2]=gStates.positionMageKnight[posPriority]
					gStates.positionMageKnight[posPriority]="nobody"
					break
				end
			end
		end

		--war of Four Competative flag
		gStates.WarOfFourComp=false
		if id=="WarOfFourStartButton" then
			gStates.WarOfFourComp=true
			local levels={{2, 2, 4, 4}, {3, 3, 6, 6}, {4, 4, 8, 8}}
			scenarioList[gStates.scenarioRef][gStates.playersRef].cityLevels=levels[gStates.volkareCombatLevel]
		end

		--Record scenario setting to gStates to be saved
		gStates.rounds=scenarioList[gStates.scenarioRef][gStates.playersRef].rounds
		gStates.mapShape=scenarioList[gStates.scenarioRef][gStates.playersRef].mapShape
		gStates.mapShapeKey=scenarioList[gStates.scenarioRef][gStates.playersRef].mapShapeKey
		gStates.cityTiles=scenarioList[gStates.scenarioRef][gStates.playersRef].cityTiles
		gStates.cityLevels={}
		for _, cityLevel in ipairs(scenarioList[gStates.scenarioRef][gStates.playersRef].cityLevels) do gStates.cityLevels[#gStates.cityLevels+1]=cityLevel end
		gStates.discardTactics=scenarioList[gStates.scenarioRef][gStates.playersRef].discardTactics

		--Change to correct Fame board for scenario
		local fameBoard=getObjectFromGUID("5c9b8c")
		if gStates.blitz==1 then
			fameBoard.setCustomObject({image="https://steamusercontent-a.akamaihd.net/ugc/764972854705018775/7566B1CF2002F976E385A6A37D83ADFCDEE615E6/"})
			fameBoard.reload()
		end
		if gStates.gameScenario=="Ultimate Conquest" then
			fameBoard.setCustomObject({image="https://steamusercontent-a.akamaihd.net/ugc/767235996519631520/F2D0503D843584DA283D0187F7C628F7AD2A8082/"})
			gStates.rowLengthGainPerLevel=1.59
			gStates.normalRowLength=14.23
			gStates.rowsOnBoard=12
			gStates.scoreIfLooped=168
			fameBoard.reload()
		end

		--switch rules to the matching page for scenario. Rulebooks are presentation/reference objects,
		--so configure each returned object independently rather than making them a chained setup dependency.
		local ruleBag=getObjectFromGUID(GUID.bag.rules)
		local r={main="b850ab", expansion="700e93", apocalypse="65f2b6"}
		local scenarioRuleStates=scenarioList[gStates.scenarioRef].scenarioDetails.ruleStates or {}
		local needExpansionRules=scenarioRuleStates.expansion~=nil or gStates.removeShadesOfTezlaMonsters~=true or gStates.removeLostLegionExpansion==false
		local needApocalypseRules=scenarioRuleStates.apocalypse~=nil or gStates.removeApocalypseTerrain~=true
		if ruleBag~=nil then
			local mainRules=safeTakeObject("SetupGame",ruleBag,{rotation={0.0,180.0,0.0},position={52.13,0.98,35.00},guid=r.main,smooth=false})
			setupConfigureRulebook(mainRules,scenarioRuleStates.main)
			if needExpansionRules then
				local expansionRules=safeTakeObject("SetupGame",ruleBag,{rotation={0.0,180.0,0.0},position={63.12,0.96,35.00},guid=r.expansion,smooth=false})
				setupConfigureRulebook(expansionRules,scenarioRuleStates.expansion)
			end
			if needApocalypseRules then
				local apocalypseRules=safeTakeObject("SetupGame",ruleBag,{rotation={0.0,180.0,0.0},position={73.60,0.97,35.00},guid=r.apocalypse,smooth=false})
				setupConfigureRulebook(apocalypseRules,scenarioRuleStates.apocalypse)
			end
			local extraRules=nil
			if gStates.gameScenario=="First Reconnaissance" then extraRules=safeTakeObject("SetupGame",ruleBag,{rotation={0.0,180.0,0.0},position={41.00,0.96,35.00},guid="9ea4ed",smooth=false}) end
			if gStates.gameScenario=="Quest for the Golden Grail" then extraRules=safeTakeObject("SetupGame",ruleBag,{rotation={0.0,180.0,0.0},position={41.00,0.96,35.00},guid="826bf9",smooth=false}) end
			if gStates.gameScenario=="The Chaos Rift" then extraRules=safeTakeObject("SetupGame",ruleBag,{rotation={0.0,180.0,0.0},position={41.00,0.96,35.00},guid="fd700f",smooth=false}) end
			if gStates.gameScenario=="The Gauntlet" then extraRules=safeTakeObject("SetupGame",ruleBag,{rotation={0.0,180.0,0.0},position={41.00,0.96,35.00},guid="a7aa4a",smooth=false}) end
			if gStates.gameScenario=="Ultimate Conquest" then extraRules=safeTakeObject("SetupGame",ruleBag,{rotation={0.0,180.0,0.0},position={41.00,0.96,35.00},guid="7c7e53",smooth=false}) end
			if gStates.gameScenario=="The War of Four" then extraRules=safeTakeObject("SetupGame",ruleBag,{rotation={0.0,180.0,0.0},position={41.00,0.96,35.00},guid="bf27ee",smooth=false}) end
			setupConfigureRulebook(extraRules,nil)
			ruleBag.destruct()
		else
			print("SETUP WARNING: rules bag d4a866 was unavailable; continuing setup without deploying rulebooks.")
		end

		--Add Weather Mod if being used
		if gStates.weatherMod==true then
			local weatherBag=getObjectFromGUID(GUID.bag.weatherMod)
			local weatherObjs={[GUID.deck.dayWeather]={-25.90, 1.08, -23.95}, [GUID.bag.weather.blazingSun]={-30.84, 1.04, -22.49}, [GUID.bag.weather.overcast]={-28.84, 1.04, -22.49}, [GUID.bag.weather.snowfall]={-32.84, 1.13, -24.49}, [GUID.bag.weather.rain]={-30.84, 1.04, -24.49}, [GUID.bag.weather.thunder]={-28.84, 1.04, -24.49}}
			local deployedWeather={}
			for weatherGUID, location in pairs(weatherObjs) do
				local obj=safeTakeObject("SetupGame",weatherBag,{rotation={0.0, 180.0, 180.0}, position=location, guid=weatherGUID, smooth=false})
				if obj==nil then error("SetupGame could not deploy Weather object "..tostring(weatherGUID),2) end
				obj.lock()
				deployedWeather[weatherGUID]=obj
			end
			local weatherRules=safeTakeObject("SetupGame",weatherBag,{rotation={0.0, 180.0, 0.0}, position={64.46, 0.98, 18.89}, guid="e03548", smooth=false})
			if weatherRules==nil then error("SetupGame could not deploy the Weather rules.",2) end
			weatherRules.lock()
			deployedWeather[GUID.deck.dayWeather].unlock()
			dayNight(gStates.startAtNight~=true,true)
		end
		if getObjectFromGUID(GUID.bag.weatherMod)~=nil then getObjectFromGUID(GUID.bag.weatherMod).destruct() end

		--Add Quest Mod if being used
		if gStates.questMod==true then
			local questBag=getObjectFromGUID(GUID.bag.quest)
			local questObjs={[GUID.deck.villageQuest]={46.84, 1.14, 8.06}, [GUID.deck.monasteryQuest]={46.91, 1.14, 13.61}, [GUID.deck.cityQuest]={46.84, 1.08, 19.07}, [GUID.deck.uniqueQuest]={46.84, 1.09, 24.57}}
			for questGUID, location in pairs(questObjs) do
				if safeTakeObject("SetupGame",questBag,{rotation={0.0, 180.0, 180.0}, position=location, guid=questGUID, smooth=false})==nil then
					error("SetupGame could not deploy Quest object "..tostring(questGUID),2)
				end
			end
			local questRules=safeTakeObject("SetupGame",questBag,{rotation={0.0, 180.0, 0.0}, position={74.77, 1.00, 18.89}, guid="1f65f1", smooth=false})
			if questRules==nil then error("SetupGame could not deploy the Quest rules.",2) end
			questRules.lock()
		end
		if getObjectFromGUID(GUID.bag.quest)~=nil then getObjectFromGUID(GUID.bag.quest).destruct() end

		--Add Item Shop Mod if being used
		if gStates.itemShopMod==true then
			local itemShopObjs={ ["b367f0"]={74.77, 0.98, 5.67},--rules
								 ["74af8f"]={-74.0, 0.97, 19.3},--One token
								 ["bec03d"]={-74.0, 0.97, 20.8},--Five token
								 ["cda170"]={-74.0, 0.97, 22.3},--Ten Token
								 ["71f87e"]={-74.0, 1.30, 23.8}}--Dice
			for itemShopObj, location in pairs(itemShopObjs) do
				getObjectFromGUID(GUID.bag.itemShop).takeObject({rotation={0.0, 180.0, 0.0}, position=location, guid=itemShopObj, smooth=false})
			end
			getObjectFromGUID(GUID.bag.itemShop).takeObject({rotation={0.0, 180.0, 180.0}, position={-74.00, 1.19, 15.0}, guid="81f056", smooth=false})--deck
		end
		if getObjectFromGUID(GUID.bag.itemShop)~=nil then getObjectFromGUID(GUID.bag.itemShop).destruct() end

		--Remove Dungeon Lord Tokens if not being used
		if gStates.gameScenario~="Dungeon Lords" then
			if getObjectFromGUID("29ea66")~=nil then getObjectFromGUID("29ea66").destruct() end--Secret Dungeon Token
			if getObjectFromGUID("663952")~=nil then getObjectFromGUID("663952").destruct() end--Secret Tomb Token
		end

		--remove some tactic cards for Fast Forwarded Conquest scenario.
		if gStates.gameScenario=="Fast Forwarded Conquest" then
			local destroyedCard={}
			for a=1, 6, 1 do
				local b=0
				while tacticCard[b]==nil or destroyedCard[tacticCard[b]]==true do
					b=math.random(1,6)--4 night tactics
					if a>4 then b=math.random(7,12) end--2 day tactics
				end
				if getObjectFromGUID(tacticCard[b])~=nil then getObjectFromGUID(tacticCard[b]).destruct() end
				destroyedCard[tacticCard[b]]=true
			end
		end

		--record dummy all skills state
		if gStates.positionMageKnight[5]=="All Skills" or gStates.volkareSkills=="All Skills" then gStates.dummyAllSkills=true end

		--Remove City models, City Cards, and City Reminders for Lost Relic scenario.
		if gStates.gameScenario=="The Lost Relic Blitz" then
			local cityDelete={	"79a723", "bd6ab1", "8de450", "a37b57",--City Cards
								cityModel.blue, cityModel.red, cityModel.green, cityModel.white}--City Reminders
			for _, cityStuffGUID in pairs(cityDelete) do
				if getObjectFromGUID(cityStuffGUID)~=nil then getObjectFromGUID(cityStuffGUID).destruct() end
			end
		end

		--Add mana dice
		gStates.diceNeeded=gStates.playerCount+2+gStates.blitz
		if gStates.positionMageKnight[5]=="Volkare" or proxyPlayerActive()==true or gStates.gameScenario=="The Chaos Rift" then gStates.diceNeeded=gStates.diceNeeded+1 end
		for i=1, gStates.diceNeeded do
			local obj=getObjectFromGUID(GUID.bag.spareDice).takeObject({position={-12+(math.random()*6), 2.7+(1.1*i), -25+(math.random()*4)}, smooth=false})--Mana Dice Container {-12+(math.random()*6), 2.7+(1.1*i), -25+(math.random()*4)}
			obj.randomize()
			onObjectRandomize({type="Dice"})
		end

		--Deploy Volkare City support pieces whenever the Camp is eligible. These stay visible even if the hidden terrain draw does not select the Camp tile.
		if setupUsesVolkareCampCity() then
			gStates.volkareCampSupportReady=false
			getObjectFromGUID(GUID.bag.volkare).takeObject({rotation={0.0, 180.0, 0.0}, position={-57.75, 0.98, -2.95}, smooth=false, guid=volkare.disc})--Volkares Mat
			getObjectFromGUID(GUID.bag.volkare).takeObject({rotation={0.0, 180.0, 0.0}, position={-62.2, 0.98, 0.5}, smooth=false, guid=volkare.terrainHex})--Volkare's Camp Hex
			local campCityCardGUID=cityScriptZones[volkare.discZone].cityCard
			safeWaitCondition("SetupGame",function()
				local campHex=getObjectFromGUID(volkare.terrainHex)
				local cityCard=getObjectFromGUID(campCityCardGUID)
				local bag=getObjectFromGUID(GUID.bag.volkare)
				campHex.lock()
				local p=cityCard.getPosition()
				local reminder=safeTakeObject("SetupGame",bag,{rotation={0.0,180.0,0.0},position={p[1]+2.2,1.5,p[3]+2.2},smooth=false,guid=GUID.bag.volkareReminder})
				if reminder==nil then error("SetupGame could not deploy the Volkare Camp reminder.",2) end
				gStates.volkareCampSupportReady=true
			end,function()
				return getObjectFromGUID(volkare.terrainHex)~=nil and getObjectFromGUID(campCityCardGUID)~=nil and getObjectFromGUID(GUID.bag.volkare)~=nil
			end,10,function() error("SetupGame timed out waiting for Volkare Camp support objects.",2) end)
			safeTakeObject("SetupGame",getObjectFromGUID(GUID.bag.volkare),{rotation={0.0, 180.0, 0.0}, position={39.16, 0.97, 35.00}, callback_function=function(spawnedObject) spawnedObject.setScale({7.05, 1.00, 6.51}) end, smooth=false, guid="b2ec85"})--Volkare Level Chart
			getObjectFromGUID(GUID.bag.volkare).takeObject({rotation={0.0,  45.0, 0.0}, position={-57.60, 1.57, -2.45}, smooth=false, guid=GUID.object.volkareDie})--Volker Dice
		end

		--display the help button
		UI.show("HelpButton")
		gStates.help=false

		--The five standard decks start fully populated with every non-Forgemaster optional card.
		--Subtract disabled card pools before any additive Forgemaster packs are merged.
		setupRemoveUnselectedCards()
		--Apocalypse/Council rewards and Possessed tokens are preloaded in their normal table positions.
		--Keep complete source/discard cycles when any enabled system can use them; otherwise remove them.
		local apocalypseTokenSupportNeeded=gStates.removeApocalypseTerrain~=true or apocalypseQuestsUsed()==true or
			gStates.gameScenario=="Against the Horsemen Blitz" or apocalypseDragonScenario()==true
		for _,guid in ipairs({
			monsterPiles.rewardApoc,GUID.bag.discard.apocReward,
			monsterPiles.rewardCouncil,GUID.bag.discard.councilReward,
			monsterPiles.possessed,GUID.bag.discard.possessed
		}) do
			local bag=getObjectFromGUID(guid)
			if apocalypseTokenSupportNeeded==true then
				if bag==nil then error("SetupGame missing preloaded Apocalypse token bag "..tostring(guid),2) end
				bag.lock()
			elseif bag~=nil then
				bag.destruct()
			end
		end
		if apocalypseTokenSupportNeeded==true then
			getObjectFromGUID(GUID.bag.apocalypseDragon).takeObject({guid="c584ff", position={-53.50, 0.98, 21.50}, rotation={0, 180, 0}, smooth=false}).lock()--Apocalypse Cult Reward Card
			getObjectFromGUID(GUID.bag.apocalypseDragon).takeObject({guid="071cc6", position={-49.50, 0.98, 21.50}, rotation={0, 180, 0}, smooth=false}).lock()--Council of the Void Reward Card
		end

		--The Apocalypse systems share the same infinite Neutral Shield bag.
		if (gStates.removeApocalypseTerrain~=true or apocalypseQuestsUsed()==true or apocalypseDragonScenario()==true) and getObjectFromGUID(GUID.bag.neutralShield)==nil then
			getObjectFromGUID(GUID.bag.apocalypseDragon).takeObject({guid=GUID.bag.neutralShield,position={8.00,1.03,16.00},rotation={0,180,0},smooth=false})
		end

		--The remaining Apocalypse components belong to the terrain/scenario package rather than the Quest deck.
		if gStates.removeApocalypseTerrain~=true then
			getObjectFromGUID(GUID.bag.apocalypseDragon).takeObject({guid=monsterPiles.pyramidTrap, position={-43.00, 1.30, 20.00}, rotation={0, 180, 0}, smooth=false}).lock()--Pyramid Trap Tokens
			getObjectFromGUID(GUID.bag.apocalypseDragon).takeObject({guid=monsterPiles.zigguratTrap, position={-43.00, 1.30, 23.00}, rotation={0, 180, 0}, smooth=false}).lock()--Zigurat Trap Tokens
			getObjectFromGUID(GUID.bag.apocalypseDragon).takeObject({guid=GUID.token.oasisReminder, position={-51.63, 0.97, 45.88}, rotation={0, 180, 0}, smooth=false}).lock()--Oasis Reminder token
			if gStates.gameScenario=="Against the Apocalypse Blitz" then
				getObjectFromGUID(GUID.bag.apocalypseDragon).takeObject({guid="f64a50", position={-38.50, 0.98, 21.50}, rotation={0, 180, 0}, smooth=false}).lock()--Against the Apocalypse Reminder Card
				local startPosition={1, 4, 5, 6, 7, 9}
				gStates.againstTheApocSitePosition=startPosition[math.random(1,6)]
				getObjectFromGUID(GUID.bag.apocalypseDragon).takeObject({guid="e735d3", position={-40.87, 1.05, 21.50+2.895-(0.685*gStates.againstTheApocSitePosition)}, rotation={0, 90, 0}, smooth=false}).lock()--Neutral pointer shield token measured offf center of card.
				getObjectFromGUID(GUID.bag.apocalypseDragon).takeObject({guid=GUID.bag.destroyedSite, position={-43.00, 1.02, 26.00}, rotation={0, 180, 0}, smooth=false}).lock()--Destroyed Site Bag

			end
		end

		--Dragon scenarios destroy sites even when the optional Apocalypse terrain mix is off.
		if apocalypseDragonScenario()==true and getObjectFromGUID(GUID.bag.destroyedSite)==nil then
			getObjectFromGUID(GUID.bag.apocalypseDragon).takeObject({guid=GUID.bag.destroyedSite,position={-43.00,1.02,26.00},rotation={0,180,0},smooth=false}).lock()
		end

		--Set up the Apocalypse Dragon large head tokens for Dragon scenarios.
		if apocalypseDragonScenario()==true then setupApocalypseDragonHeads() end
		if apocalypseIsHereSetup~=nil then apocalypseIsHereSetup() end

		--include or remove Rise of the Forgemaster
		if gStates.riseOfTheForgemasters>=1 then
			setupQueueDeckMerge(getObjectFromGUID(GUID.bag.forgemaster),GUID.deck.action,"db5f9f")--Advanced Actions
			setupQueueDeckMerge(getObjectFromGUID(GUID.bag.forgemaster),GUID.deck.artifact,"c48f76")--artifacts
			setupQueueDeckMerge(getObjectFromGUID(GUID.bag.forgemaster),GUID.deck.spell,"cfe630")--Spells
			local forgemasterBag=getObjectFromGUID(GUID.bag.forgemaster)
			local forgemasterRules=safeTakeObject("SetupGame",forgemasterBag,{rotation={0.0, 180.0, 0.0}, position={54.25, 0.98, 18.86}, guid="0a657b", smooth=false})
			if forgemasterRules==nil then error("SetupGame could not deploy Rise of the Forgemasters rules.",2) end
			forgemasterRules.lock()
			if gStates.riseOfTheForgemasters>=2 then
				setupQueueDeckMerge(forgemasterBag,GUID.deck.action,"c89aea")--Advanced Actions
				local forgemasterTwo=safeTakeObject("SetupGame",forgemasterBag,{rotation={0.0, 180.0, 0.0}, position={-75.16, 0.99, -16.00}, guid="5ad84f", smooth=false})
				if forgemasterTwo==nil then error("SetupGame could not deploy Rise of the Forgemasters level 2 component.",2) end
				forgemasterTwo.lock()
				if gStates.riseOfTheForgemasters==3 then
					setupQueueDeckMerge(forgemasterBag,GUID.deck.action,"3b0ed8")--Advanced Actions
					setupQueueDeckMerge(forgemasterBag,GUID.deck.spell,"09fd8d")--Spells
					for _,details in ipairs({
						{guid="bbec6b",position={-75.16,0.99,-19.50}},
						{guid="786414",position={-75.16,0.99,-23.00}},
						{guid="a28a71",position={-75.16,0.99,-12.50}},
						{guid="c14096",position={-75.16,0.99,-9.00}}
					}) do
						local component=safeTakeObject("SetupGame",forgemasterBag,{rotation={0.0,180.0,0.0},position=details.position,guid=details.guid,smooth=false})
						if component==nil then error("SetupGame could not deploy Rise of the Forgemasters component "..details.guid,2) end
						component.lock()
					end
				end
			end
		end

		--Monster Pug Setup
		monsterSetup()

		--Go through the five player positions and put out pieces based on the game settings
		playerSetup()

		--Clean up the All Skills bag independently; only its Dummy-board placement needs to wait.
		local allSkills=getObjectFromGUID(GUID.bag.allSkills)
		if gStates.dummyAllSkills==true then
			if gStates.playersRef==5 then
				safeWaitCondition("SetupGame",function()
					local board=getObjectFromGUID(dummyBoard)
					allSkills.setPosition({board.getPosition()[1]-5.62,1.25,board.getPosition()[3]+6.97})
					for skillGUID,skillDetails in pairs(skillTokens) do
						if (skillDetails.mage==turnOrder[1].mage or (customMages[skillDetails.mage]~=nil and gStates.useCustomMageKnights==false) or (skillDetails.mage=="Jormund" and gStates.riseOfTheForgemasters<3)) and
							skillDetails.skillType~="Comp" and skillGUID~="d90de4" and skillGUID~="9f5dc0" and skillGUID~="bfd0c5" then
							local obj=allSkills.takeObject({guid=skillGUID})
							obj.destruct()
						end
					end
					allSkills.shuffle()
				end,function() return getObjectFromGUID(dummyBoard)~=nil end,5,function()
					error("SetupGame timed out waiting for the Dummy board before positioning All Skills.",2)
				end)
			end
		else
			allSkills.destruct()
		end

		--Deck setup can begin as soon as every queued additive Forgemaster pack has joined its destination
		--deck. Check merged quantities before deckSetup intentionally removes scenario/replaced cards.
		if setupQueuedDeckMergesComplete()==true then
			setupStartDeckStage()
		else
			safeWaitCondition("SetupGame",setupStartDeckStage,setupQueuedDeckMergesComplete,10,function()
				error("SetupGame timed out waiting for Forgemaster cards to merge into the main decks.",2)
			end)
		end
	end
end

----------------
-- Delayed Setup
----------------
local function sendTerrainTileToTrash(bag,tileGUID)
	if bag==nil or tileGUID==nil then return end
	local trash=getObjectFromGUID(trashCan)
	if trash==nil then return end
	local tile=safeTakeObject("SetupGame",bag,{guid=tileGUID,smooth=false})
	if tile~=nil then trash.putObject(tile) end
end

--All normal terrain now starts in the three Country/Core/City bags. Remove anything excluded by
--the finalized setup options before mapSetup reads bag quantities or selects scenario-specific GUIDs.
local function removeUnselectedTerrain()
	local countryBag=getObjectFromGUID(GUID.bag.terrain.leftCountry)
	local coreBag=getObjectFromGUID(GUID.bag.terrain.leftCore)
	local cityBag=getObjectFromGUID(GUID.bag.terrain.leftCity)
	if gStates.removeLostLegionExpansion==true then
		for _,guid in ipairs(setupContentRoster.lostLegion.terrain.country) do sendTerrainTileToTrash(countryBag,guid) end
		for _,guid in ipairs(setupContentRoster.lostLegion.terrain.core) do sendTerrainTileToTrash(coreBag,guid) end
	end
	if gStates.removeApocalypseTerrain==true then
		for _,guid in ipairs(setupContentRoster.apocalypse.terrain.country) do sendTerrainTileToTrash(countryBag,guid) end
		for _,guid in ipairs(setupContentRoster.apocalypse.terrain.core) do sendTerrainTileToTrash(coreBag,guid) end
	end
	--Against the Horsemen requires Countryside 1 as its centre even if stale saved/random state says otherwise.
	if gStates.removeTerrain==true and gStates.gameScenario~="Against the Horsemen Blitz" then
		for _,guid in ipairs({GUID.tile.country01,GUID.tile.country02}) do sendTerrainTileToTrash(countryBag,guid) end
	end
	--When Volkare is the automated opponent, their scenario setup has already pulled this same tile from the City bag.
	if gStates.positionMageKnight[5]~="Volkare" and setupUsesVolkareCampCity()~=true then sendTerrainTileToTrash(cityBag,GUID.tile.volkareCamp) end
end

--Volkare is deployed before map construction, so his final lock belongs to the map-complete path.
--Waiting for the known map resting height here is safe: unlike the old readiness gate, the terrain now exists.
local function lockSetupVolkareOnMap(callback)
	if gStates.positionMageKnight[5]~="Volkare" then callback() return end
	local volkareGUID=gStates.volkareModel or volkare.model
	local model=getObjectFromGUID(volkareGUID)
	if model==nil then
		setupReleaseRewind()
		error("SetupGame could not find Volkare after map construction.",2)
	end
	model.unlock()
	safeWaitFrames("SetupGame",function()
		safeWaitCondition("SetupGame",function()
			local settled=getObjectFromGUID(volkareGUID)
			if settled~=nil then
				settled.setRotation({0,180,0})
				settled.lock()
			end
			callback()
		end,function()
			local settled=getObjectFromGUID(volkareGUID)
			if settled==nil then return false end
			local y=settled.getPosition()[2]
			return settled.resting==true and settled.isSmoothMoving()==false and math.abs(y-1.08)<0.06
		end,10,function()
			setupReleaseRewind()
			error("SetupGame timed out waiting for Volkare to settle on the completed map.",2)
		end)
	end,1)
end

--Finalize setup only after all chained setup work and initial map population are actually complete.
local function finalizeSetup()
	if setupFinalizationStarted==true then return end
	setupFinalizationStarted=true
	dayNight(gStates.startAtNight~=true)--repeat after map setup for map-dependent reveal/weather work and final terrain tint
	gStates.firstStarted=true
	gStates.turnNumber=1
	refreshAllPlayerFameReputationFromShields()
	refreshMageSkillLocations()
	tacticToggle()
	--Map setup is now complete and startingMapSetup has been released. Build the first EXPLORE view
	--from the final physical terrain positions instead of whichever setup callback happened last.
	refreshTerrainExploreOptions()
	--Delete Player Bags could this be done during setup
	local ToBeDeleted={	GUID.bag.component.arythea,--Arythea
						GUID.bag.component.norowas,--Norowas
						GUID.bag.component.goldyx,--Goldyx
						GUID.bag.component.tovak,--Tovak
						GUID.bag.component.krang,--Krang
						GUID.bag.component.braevalar,--Braevalar
						GUID.bag.component.ymirgh,--Ymirgh
						GUID.bag.component.wolfhawk,--Wolfhawk
						GUID.bag.component.coral,--Coral
						GUID.bag.component.jormund,--Jormund
						GUID.bag.volkare,--Volkare
						GUID.bag.common,--Common Piecies
						GUID.bag.terrain.shuffler,--Tile Shuffler
						GUID.bag.forgemaster,--Rise of the Forgemasters
						GUID.bag.tezla,--Shades of Tesla
						GUID.bag.apocalypseDragon,--Apocalypse Dragon
						GUID.bag.lostLegion,--Lost Legion
						GUID.bag.component.mevok,--Mevok
						GUID.bag.component.duscenia,--Duscenia
						GUID.bag.component.zirtae,--Zirtae
						GUID.bag.component.malek}--Malek

	for _, dest in pairs(ToBeDeleted) do
		if getObjectFromGUID(dest)~=nil then getObjectFromGUID(dest).destruct() end
	end
	--finalize mirrored source.
	getObjectFromGUID("b5a6ce").destruct()
	mirrorSourceUpdate("first started game")
	--Draw all the offers will double draw if I don't get the timing right.
	gStates.totalUnitCount=gStates.playerCount+gStates.blitz+2
	if gStates.positionMageKnight[5]=="Volkare" or proxyPlayerActive()==true then gStates.totalUnitCount=gStates.totalUnitCount+1 end
	unitOffer()
	fillSlide()
	--display the help boxes
	DisplayHelp(nil, "-1", nil)
	getObjectFromGUID(GUID.deck.artifact).UI.setAttribute("ac75c4ArtifactDownImage", "image", "Overkill Down")
	getObjectFromGUID(GUID.deck.artifact).UI.setAttribute("ac75c4ArtifactOfferImage", "image", "Sliced Button/Button Object Active")
	getObjectFromGUID(GUID.deck.artifact).UI.setAttribute("ac75c4ArtifactUpImage", "image", "Overkill Up")
	getObjectFromGUID(GUID.deck.artifact).UI.setAttribute("ac75c4ArtifactDown", "active", "true")
	getObjectFromGUID(GUID.deck.artifact).UI.setAttribute("ac75c4ArtifactOffer", "active", "true")
	getObjectFromGUID(GUID.deck.artifact).UI.setAttribute("ac75c4ArtifactUp", "active", "true")
	getObjectFromGUID(GUID.deck.artifact).UI.setAttribute("ac75c4ArtifactOfferText", "text", joinLang({"{en}Reward {ru}Награда {zh-tw}獎勵{zh-cn}奖励{ko}보상 {es}Premiar {fr}Reward {pt-br}Premiar {de}Belohnung ", gStates.artifactRewards}))
	UI.setAttribute("ResourceTracker", "active", "true")
	UI.setAttribute("cameraControl", "active", "true")
	if gStates.gameScenario=="One to Return" then UI.hide("ScoreButton") end

	broadcastToAll("-------------------", {1,1,0.5})
	--Stop player boards and dummy board from alt zooming
	local megaFreeze=  {"3d4319", "519f96",	playerBoard[1], playerBoard[2], playerBoard[3], playerBoard[4], dummyBoard}--player mats
	for i=1, #megaFreeze, 1 do
		local obj=getObjectFromGUID(megaFreeze[i])
		if obj~=nil then obj.interactable=false end --some boards may be missing depending on their states
	end
	addAvatarButtons()
	applyColorBarButtons()
	refreshPlayerSeatColors()
	getObjectFromGUID(GUID.deck.spell).UI.setXmlTable({	{tag="Button", attributes={id="e4372aOfferUp", onClick="global/offerAdjust", onMouseDown="global/buttonClicked", onMouseUp="global/buttonClicked", height=150, width=240, position="60 190 -10", rotation="0 180 180", scale="0.32 0.32"},
													children={	{tag="Image", attributes={id="e4372aOfferUpImage", image="Sliced Button/Button Object Active", type="Sliced"}},
																{tag="Text", attributes={font="Fonts/MKCardText", fontSize="90", fontStyle="Normal", alignment="MiddleCenter", text=">"}}}},
													{tag="Button", attributes={id="e4372aOfferDown", onClick="global/offerAdjust", onMouseDown="global/buttonClicked", onMouseUp="global/buttonClicked", height=150, width=240, position="-60 190 -10", rotation="0 180 180", scale="0.32 0.32"},
													children={	{tag="Image", attributes={id="e4372aOfferDownImage", image="Sliced Button/Button Object Active", type="Sliced"}},
																{tag="Text", attributes={font="Fonts/MKCardText", fontSize="90", fontStyle="Normal", alignment="MiddleCenter", text="<"}}}}})
	--record data
	safeWaitTime("SetupGame",function()
            if getObjectFromGUID("e7de55")~=nil then SendDataRequest("skip", "-1", "SendDataRequestYes") end
		--UI.setAttribute("SendDataRequest", "active", "true")
	end, 400)--time in seconds, 1800=1/2 hour, 3600=1 hour 400
	safeWaitTime("SetupGame",function() straightenCrooked() end, 10)
	dealStartingHandsWhenReady()
	--All automated setup dependencies have completed. Any remaining smooth movement is presentation-only,
	--so release the setup rewind guard immediately rather than relying on its 59-second failsafe.
	setupReleaseRewind()
end

--Build the map only after monster/player/component setup has reached its real readiness conditions.
function afterLoad()
	if setupMapStarted==true then return end
	local function beginMap()
		if setupMapStarted==true then return end
		setupMapStarted=true
		removeUnselectedTerrain()
		if apocalypseDragonScenario()==true then positionApocalypseDragonHeads() end
		mapSetup(function(success,reason)
			if success~=true then
				setupReleaseRewind()
				error(reason or "SetupGame map setup failed.",2)
			end
			lockSetupVolkareOnMap(finalizeSetup)
		end)
	end
	if setupCoreSystemsReady()==true then
		beginMap()
	else
		safeWaitCondition("SetupGame",beginMap,setupCoreSystemsReady,20,function()
			setupReleaseRewind()
			error("SetupGame timed out waiting for setup components before map construction.",2)
		end)
	end
end

--Keep setup-specific validation and rulebook deployment with the setup owner rather than a late wrapper module.
function setupGame(player, mouseButton, id, rewindReady)
	return safeCallback("setupGame",function()
		if mouseButton=="-1" and rewindReady==true and gStates~=nil then
			--Book.setPage expects a CLR Int32. Normalize scenario rule-page values before the delayed
			--rulebook callback runs, including values restored from a string.
			local scenario=scenarioList~=nil and scenarioList[gStates.scenarioRef] or nil
			local details=scenario~=nil and scenario.scenarioDetails or nil
			local ruleStates=details~=nil and details.ruleStates or nil
			if type(ruleStates)=="table" then
				for key,page in pairs(ruleStates) do
					local numeric=tonumber(page)
					if numeric~=nil then ruleStates[key]=math.floor(numeric) end
				end
			end
			--Fury's manual comes from the Apocalypse Dragon rules bag and is locked by the normal
			--delayed rulebook pass alongside the other manuals.
			if gStates.gameScenario=="Fury of the Apocalypse Dragon" and getObjectFromGUID(GUID.card.furyOfDragonRules)==nil then
				local ruleBag=getObjectFromGUID(GUID.bag.rules)
				if ruleBag~=nil then
					local furyRules=safeTakeObject("SetupGame",ruleBag,{guid=GUID.card.furyOfDragonRules,position={41.00,0.96,35.00},rotation={0,180,0},smooth=false})
					setupConfigureRulebook(furyRules,nil)
				end
			end
		end
		return setupGameRaw(player,mouseButton,id,rewindReady)
	end,function() return setupGameErrorContext(player,id,rewindReady) end)
end

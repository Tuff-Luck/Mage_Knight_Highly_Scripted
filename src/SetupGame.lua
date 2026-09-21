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

--Layout everything needed for the game
local setupRewindRequestPending=false
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
		--Close the setup menu and update the Help button
		UI.setAttribute("Setup", "active", "false")
		UI.setAttribute("helpButtonRealText", "Text", "{en}Help{ru}Помощь{zh-tw}帮  助{zh-cn}帮  助{ko}도움말{es}Ayudar{fr}Aider{pt-br}Ajuda{de}Hilfe")
		UI.setAttribute("helpButtonReal", "onClick", "DisplayHelp")
		UI.setAttribute("helpButtonRealImage", "image", "Sliced Button/Button New Active")
		UI.setAttribute("helpButtonReal", "interactable", "true")
		UI.setAttribute("MonsterButtonRealImage", "image", "Sliced Button/Button New Active")
		UI.setAttribute("MonsterButtonReal", "interactable", "true")

		--New User and Random Game setup
		if id=="NewUser" or id=="RandomGame" then
			for a=1, 4 do gStates.positionMageKnight[a]="nobody" end
			gStates.positionMageKnight[2]="Random"
			gStates.positionMageKnight[5]="Random"
			gStates.setupDummyMageChoice="Random"
			gStates.volkareSkills="Random"
			gStates.playerCount=1
			gStates.scenarioRef=1
			gStates.playersRef=5
			gStates.coop=1
			if id=="NewUser" then
				gStates.gameScenario="First Reconnaissance"
				gStates.scenarioRef=1
				gStates.removeLostLegionExpansion=true
				gStates.removeBonusCards=true
			else--"RandomGame"
				--Mystery Solo can be pressed after changing setup options, so build the roll from a clean baseline
				--instead of inheriting any settings from the menu state that happened to be active beforehand.
				gStates.rampage=0
				gStates.megapolis=0
				gStates.volkareCampAsCity=false
				gStates.randomTileOrientation=false
				gStates.randomCities=false
				gStates.dayRound=false
				gStates.startAtNight=false
				gStates.darknessComing=false
				gStates.removeShadesOfTezlaMonsters=false
				gStates.removeApocalypseTerrain=false
				gStates.useCustomMageKnights=false
				gStates.heroChallenges=false
				gStates.apocalypseQuestCards=false
				gStates.questMod=false
				gStates.weatherMod=false
				gStates.itemShopMod=false
				gStates.rampageAmbush=false
				gStates.rampagePursuit=false
				gStates.mageKnightLevels=false
				gStates.removeTerrain=false
				gStates.removeLostLegionExpansion=false
				gStates.removeBonusCards=false
				gStates.useAlternatePugs=false
				gStates.riseOfTheForgemasters=0
				while 	scenarioList[gStates.scenarioRef][1]=="First Reconnaissance" or
						scenarioList[gStates.scenarioRef][1]=="Conquer and Hold" or
						scenarioList[gStates.scenarioRef][1]=="One to Return" do gStates.scenarioRef=math.random(2, #scenarioList-1) end--19,9,8 aren't solo
				gStates.gameScenario=scenarioList[gStates.scenarioRef][1]
				if gStates.gameScenario:reverse():sub(1, 5)=="ztilB" then gStates.blitz=1 else gStates.blitz=0 end
				if math.random(1,10)>=8 then gStates.rampage=math.random(0,2) end
				if gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz" or gStates.gameScenario=="Volkare's Quest" or gStates.gameScenario=="The War of Four" then gStates.positionMageKnight[5]="Volkare" end
				if gStates.gameScenario=="First Reconnaissance" then
					gStates.removeShadesOfTezlaMonsters=true
				elseif gStates.gameScenario=="Life and Death" or gStates.gameScenario=="The Realm of the Dead Blitz" or gStates.gameScenario=="The Hidden Valley Blitz" or gStates.gameScenario=="The War of Four" then
					gStates.removeShadesOfTezlaMonsters=false
				else
					if math.random(1,10)>=7 then gStates.removeShadesOfTezlaMonsters=true else gStates.removeShadesOfTezlaMonsters=false end
				end
				if gStates.gameScenario=="Against the Apocalypse Blitz" then
					gStates.removeApocalypseTerrain=false
				elseif gStates.gameScenario=="First Reconnaissance" then
					gStates.removeApocalypseTerrain=true
				else
					if math.random(1,10)>=7 then gStates.removeApocalypseTerrain=true else gStates.removeApocalypseTerrain=false end
				end
				if gStates.gameScenario=="The Fractured Lands Blitz" then gStates.randomTileOrientation=false elseif math.random(1,10)>=8 then gStates.randomTileOrientation=true else gStates.randomTileOrientation=false end
				if randomCitiesAllowedForScenario() and math.random(1,10)>=8 then gStates.randomCities=true else gStates.randomCities=false end
				--afterLoad/dayNight expects dayRound=false before the first flip; randomize the actual Start at Night option instead.
				if gStates.gameScenario=="Fast Forwarded Conquest" or (gStates.gameScenario~="Druid Nights" and math.random(1,10)>=8) then gStates.startAtNight=true else gStates.startAtNight=false end
				if math.random(1,10)>=8 and gStates.gameScenario~="Druid Nights" then gStates.darknessComing=true else gStates.darknessComing=false end
				if math.random(1,10)>=8 then gStates.useCustomMageKnights=true else gStates.useCustomMageKnights=false end
				--Hero Challenges use the same random-option chance, but are mutually exclusive with fan-made Mage Knights.
				if gStates.useCustomMageKnights~=true and (gStates.riseOfTheForgemasters or 0)==0 and math.random(1,10)>=8 then gStates.heroChallenges=true else gStates.heroChallenges=false end
				if gStates.gameScenario=="For the Council" or gStates.gameScenario=="The Fractured Lands Blitz" then
					gStates.apocalypseQuestCards=true
				else
					if math.random(1,10)>=8 then gStates.apocalypseQuestCards=true else gStates.apocalypseQuestCards=false end
				end
				if math.random(1,10)>=8 then gStates.rampageAmbush=true else gStates.rampageAmbush=false end
				if math.random(1,10)>=8 and gStates.rampageAmbush==false then gStates.rampagePursuit=true else gStates.rampagePursuit=false end
				--gStates.questMod=false
				--gStates.weatherMod=false
				if gStates.gameScenario=="First Conquest" or gStates.gameScenario=="Conquest" or gStates.gameScenario=="Conquest Blitz" or gStates.gameScenario=="Ultimate Conquest"
					or gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz" or gStates.gameScenario=="Volkare's Quest" or gStates.gameScenario=="The War of Four"
					or gStates.gameScenario=="Quest for the Golden Grail" or gStates.gameScenario=="Fast Forwarded Conquest" or gStates.gameScenario=="The Fractured Lands Blitz" or gStates.gameScenario=="Against the Horsemen Blitz" then
					if math.random(1,10)>=8 then gStates.volkareCampAsCity=true else gStates.volkareCampAsCity=false end
					if gStates.gameScenario=="Ultimate Conquest" then gStates.volkareCampAsCity=true end
					if gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz" or gStates.gameScenario=="Volkare's Quest" or gStates.gameScenario=="The War of Four" then gStates.volkareCampAsCity=false end
				end
				local megapolisMaximum=megapolisMaximumForSetup(gStates.scenarioRef,gStates.playersRef)
				if gStates.volkareCampAsCity==false and megapolisMaximum>0 and math.random(1,10)>=8 then
					gStates.megapolis=math.random(0,megapolisMaximum)
					ensureSetupMegapolisMinimumLevels()
				end
				if gStates.gameScenario=="The Lost Relic Blitz" or gStates.gameScenario=="Fast Forwarded Conquest" then gStates.mageKnightLevels=true end
			end
		end

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

		--switch rules to the matching page for scenario. The rules bag is ancillary to setup; a rare
		--rewind/load timing miss must not abort setup before terrain/decks are built.
		local ruleBag=getObjectFromGUID("d4a866")
		local r={main="b850ab", expansion="700e93", apocalypse="65f2b6"}
		local extraRules=nil
		if ruleBag~=nil then
			ruleBag.takeObject({rotation={0.0, 180.0, 0.0}, position={52.13, 0.98, 35.00}, guid=r.main, smooth=false})
			if scenarioList[gStates.scenarioRef].scenarioDetails.ruleStates[2]~=1 or gStates.removeShadesOfTezlaMonsters~=true or gStates.removeLostLegionExpansion==false then ruleBag.takeObject({rotation={0.0, 180.0, 0.0}, position={63.12, 0.96, 35.00}, guid=r.expansion, smooth=false}) end
			if scenarioList[gStates.scenarioRef].scenarioDetails.ruleStates.apocalypse~=nil or gStates.removeApocalypseTerrain~=true then ruleBag.takeObject({rotation={0.0, 180.0, 0.0}, position={73.60, 0.97, 35.00}, guid=r.apocalypse, smooth=false}) end
			if gStates.gameScenario=="First Reconnaissance" then extraRules=ruleBag.takeObject({rotation={0.0, 180.0, 0.0}, position={41.00, 0.96, 35.00}, guid="9ea4ed", smooth=false}) end
			if gStates.gameScenario=="Quest for the Golden Grail" then extraRules=ruleBag.takeObject({rotation={0.0, 180.0, 0.0}, position={41.00, 0.96, 35.00}, guid="826bf9", smooth=false}) end
			if gStates.gameScenario=="The Chaos Rift" then extraRules=ruleBag.takeObject({rotation={0.0, 180.0, 0.0}, position={41.00, 0.96, 35.00}, guid="fd700f", smooth=false}) end
			if gStates.gameScenario=="The Gauntlet" then extraRules=ruleBag.takeObject({rotation={0.0, 180.0, 0.0}, position={41.00, 0.96, 35.00}, guid="a7aa4a", smooth=false}) end
			if gStates.gameScenario=="Ultimate Conquest" then extraRules=ruleBag.takeObject({rotation={0.0, 180.0, 0.0}, position={41.00, 0.96, 35.00}, guid="7c7e53", smooth=false}) end
			if gStates.gameScenario=="The War of Four" then extraRules=ruleBag.takeObject({rotation={0.0, 180.0, 0.0}, position={41.00, 0.96, 35.00}, guid="bf27ee", smooth=false}) end
		else
			print("SETUP WARNING: rules bag d4a866 was unavailable; continuing setup without deploying rulebooks.")
		end
		if ruleBag~=nil then
			safeWaitTime("SetupGame",function() safeWaitCondition("SetupGame",function()
				local mainRules=getObjectFromGUID(r.main)
				local expansionRules=getObjectFromGUID(r.expansion)
				local apocalypseRules=getObjectFromGUID(r.apocalypse)
				local furyRules=gStates.gameScenario=="Fury of the Apocalypse Dragon" and getObjectFromGUID("8d7fb9") or nil
				if scenarioList[gStates.scenarioRef].scenarioDetails.ruleStates.main~=nil and mainRules~=nil then mainRules.book.setPage(scenarioList[gStates.scenarioRef].scenarioDetails.ruleStates.main-1) end
				if scenarioList[gStates.scenarioRef].scenarioDetails.ruleStates.expansion~=nil and expansionRules~=nil then expansionRules.book.setPage(scenarioList[gStates.scenarioRef].scenarioDetails.ruleStates.expansion-1) end
				if scenarioList[gStates.scenarioRef].scenarioDetails.ruleStates.apocalypse~=nil and apocalypseRules~=nil then apocalypseRules.book.setPage(scenarioList[gStates.scenarioRef].scenarioDetails.ruleStates.apocalypse-1) end
				if mainRules~=nil then mainRules.lock() end
				if expansionRules~=nil then expansionRules.lock() end
				if apocalypseRules~=nil then apocalypseRules.lock() end
				if furyRules~=nil then furyRules.lock() end
				if extraRules~=nil then extraRules.lock() end
			end, function() local mainRules=getObjectFromGUID(r.main) return mainRules~=nil and mainRules.resting end) end, 5)
		ruleBag.destruct()
		end

		--Add Weather Mod if being used
		if gStates.weatherMod==true then
			local weatherObjs={[GUID.deck.dayWeather]={-25.90, 1.08, -23.95}, [GUID.bag.weather.blazingSun]={-30.84, 1.04, -22.49}, [GUID.bag.weather.overcast]={-28.84, 1.04, -22.49}, [GUID.bag.weather.snowfall]={-32.84, 1.13, -24.49}, [GUID.bag.weather.rain]={-30.84, 1.04, -24.49}, [GUID.bag.weather.thunder]={-28.84, 1.04, -24.49}}
			for weatherObj, location in pairs(weatherObjs) do
				getObjectFromGUID(GUID.bag.weatherMod).takeObject({rotation={0.0, 180.0, 180.0}, position=location, guid=weatherObj, smooth=false})
				getObjectFromGUID(weatherObj).lock()
			end
			getObjectFromGUID(GUID.bag.weatherMod).takeObject({rotation={0.0, 180.0, 0.0}, position={64.46, 0.98, 18.89}, guid="e03548", smooth=false})
			getObjectFromGUID("e03548").lock()
			getObjectFromGUID(GUID.deck.dayWeather).unlock()
		end
		if getObjectFromGUID(GUID.bag.weatherMod)~=nil then getObjectFromGUID(GUID.bag.weatherMod).destruct() end

		--Add Quest Mod if being used
		if gStates.questMod==true then
			local questObjs={[GUID.deck.villageQuest]={46.84, 1.14, 8.06}, [GUID.deck.monasteryQuest]={46.91, 1.14, 13.61}, [GUID.deck.cityQuest]={46.84, 1.08, 19.07}, [GUID.deck.uniqueQuest]={46.84, 1.09, 24.57}}
			for questObj, location in pairs(questObjs) do
				getObjectFromGUID(GUID.bag.quest).takeObject({rotation={0.0, 180.0, 180.0}, position=location, guid=questObj, smooth=false})
			end
			getObjectFromGUID(GUID.bag.quest).takeObject({rotation={0.0, 180.0, 0.0}, position={74.77, 1.00, 18.89}, guid="1f65f1", smooth=false})
			getObjectFromGUID("1f65f1").lock()
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
			getObjectFromGUID(GUID.bag.volkare).takeObject({rotation={0.0, 180.0, 0.0}, position={-57.75, 0.98, -2.95}, smooth=false, guid=volkare.disc})--Volkares Mat
			getObjectFromGUID(GUID.bag.volkare).takeObject({rotation={0.0, 180.0, 0.0}, position={-62.2, 0.98, 0.5}, smooth=false, guid=volkare.terrainHex})--Volkare's Camp Hex
			safeWaitTime("SetupGame",function()
				getObjectFromGUID(volkare.terrainHex).lock()
				getObjectFromGUID(GUID.bag.volkare).takeObject({rotation={0.0, 180.0, 0.0}, position={getObjectFromGUID(cityScriptZones[volkare.discZone].cityCard).getPosition()[1]+2.2, 1.5, getObjectFromGUID(cityScriptZones[volkare.discZone].cityCard).getPosition()[3]+2.2}, smooth=false, guid=GUID.bag.volkareReminder})
			end, 1)
			safeTakeObject("SetupGame",getObjectFromGUID(GUID.bag.volkare),{rotation={0.0, 180.0, 0.0}, position={39.16, 0.97, 35.00}, callback_function=function(spawnedObject) spawnedObject.setScale({7.05, 1.00, 6.51}) end, smooth=false, guid="b2ec85"})--Volkare Level Chart
			getObjectFromGUID(GUID.bag.volkare).takeObject({rotation={0.0,  45.0, 0.0}, position={-57.60, 1.57, -2.45}, smooth=false, guid="9a686a"})--Volker Dice
		end

		--display the help button
		UI.show("HelpButton")
		gStates.help=false

		--Add or destroy the 4 competitive spell cards
		if gStates.coop==0 or gStates.WarOfFourComp==true then
			safeTakeObject("SetupGame",getObjectFromGUID(GUID.bag.common),{position={getObjectFromGUID(GUID.deck.spell).getPosition()[1], -2, getObjectFromGUID(GUID.deck.spell).getPosition()[3]},
				guid="9b3c8c", smooth=false, callback_function=function(obj) safeWaitFrames("SetupGame",function() getObjectFromGUID(GUID.deck.spell).putObject(obj) end) end})--Spells
		end

		--Add or destroy the Advanced action Cards removed for First Reconnaissance
		if gStates.gameScenario~="First Reconnaissance" then
			safeTakeObject("SetupGame",getObjectFromGUID(GUID.bag.common),{position={getObjectFromGUID(GUID.deck.action).getPosition()[1], -2, getObjectFromGUID(GUID.deck.action).getPosition()[3]},
				guid="268194", smooth=false, callback_function=function(obj) safeWaitFrames("SetupGame",function() getObjectFromGUID(GUID.deck.action).putObject(obj) end) end})--Advanced Actions
		end

		--Merge Lost Legion Components
		local lostLegionDecks={[GUID.deck.action]="d7f7a5", [GUID.deck.spell]="8edf39", [GUID.deck.artifact]="00e7f4", [GUID.deck.regularUnit]="892e01", [GUID.deck.eliteUnit]="6d42f9"}
								--12 Advanced Actions, 4 Spells, 8 Artifacts, 8 Regular Units, 8 Elite Units
		if gStates.removeLostLegionExpansion==false then
			for mainDeck, lostLegionDeck in pairs(lostLegionDecks) do
				safeTakeObject("SetupGame",getObjectFromGUID(GUID.bag.lostLegion),{position={getObjectFromGUID(mainDeck).getPosition()[1], -2, getObjectFromGUID(mainDeck).getPosition()[3]},
					guid=lostLegionDeck, smooth=false, callback_function=function(obj) safeWaitFrames("SetupGame",function() getObjectFromGUID(mainDeck).putObject(obj) end) end})
			end
		end
		--Apocalypse Quest cards can call the Apocalypse/Council reward systems and Possessed enemies even
		--even when Apocalypse terrain itself is removed. Put the five shared support objects in their
		--normal Apocalypse locations whenever either system is in use.
		if gStates.removeApocalypseTerrain~=true or apocalypseQuestsUsed()==true or gStates.gameScenario=="Against the Horsemen Blitz" or apocalypseDragonScenario()==true then
			getObjectFromGUID(GUID.bag.apocalypseDragon).takeObject({guid=monsterPiles.rewardApoc, position={-46.13, 0.97, 20.00}, rotation={0, 180, 0}, smooth=false}).lock()--Apocalypse Cult Reward
			getObjectFromGUID(GUID.bag.apocalypseDragon).takeObject({guid=monsterPiles.rewardCouncil, position={-46.13, 0.97, 23.00}, rotation={0, 180, 0}, smooth=false}).lock()--Council of the Void Reward
			getObjectFromGUID(GUID.bag.apocalypseDragon).takeObject({guid="c584ff", position={-53.50, 0.98, 21.50}, rotation={0, 180, 0}, smooth=false}).lock()--Apocalypse Cult Reward Card
			getObjectFromGUID(GUID.bag.apocalypseDragon).takeObject({guid="071cc6", position={-49.50, 0.98, 21.50}, rotation={0, 180, 0}, smooth=false}).lock()--Council of the Void Reward Card
			getObjectFromGUID(GUID.bag.apocalypseDragon).takeObject({guid=monsterPiles.possessed, position={-46.13, 2.12, 11.50}, rotation={0, 180, 0}, smooth=false}).lock()--Possessed tokens
		end

		--The Apocalypse systems share the same infinite Neutral Shield bag.
		if (gStates.removeApocalypseTerrain~=true or apocalypseQuestsUsed()==true or apocalypseDragonScenario()==true) and getObjectFromGUID(GUID.bag.neutralShield)==nil then
			getObjectFromGUID(GUID.bag.apocalypseDragon).takeObject({guid=GUID.bag.neutralShield,position={8.00,1.03,16.00},rotation={0,180,0},smooth=false})
		end

		--The remaining Apocalypse components belong to the terrain/scenario package rather than the Quest deck.
		if gStates.removeApocalypseTerrain~=true then
			getObjectFromGUID(GUID.bag.apocalypseDragon).takeObject({guid=GUID.bag.discard.apocReward, position={2.00, 0.98, 16.00}, rotation={0, 180, 0}, smooth=false}).lock()--Apocalypse Cult Reward Discard
			getObjectFromGUID(GUID.bag.apocalypseDragon).takeObject({guid=GUID.bag.discard.councilReward, position={2.00, 0.97, 19.00}, rotation={0, 180, 0}, smooth=false}).lock()--Council of the Void Reward Discard
			getObjectFromGUID(GUID.bag.apocalypseDragon).takeObject({guid=monsterPiles.pyramidTrap, position={-43.00, 1.30, 20.00}, rotation={0, 180, 0}, smooth=false}).lock()--Pyramid Trap Tokens
			getObjectFromGUID(GUID.bag.apocalypseDragon).takeObject({guid=monsterPiles.zigguratTrap, position={-43.00, 1.30, 23.00}, rotation={0, 180, 0}, smooth=false}).lock()--Zigurat Trap Tokens
			getObjectFromGUID(GUID.bag.apocalypseDragon).takeObject({guid=GUID.bag.discard.possessed, position={-1.00, 1.07, 19.00}, rotation={0, 180, 0}, smooth=false}).lock()--Possessed token discard Bag
			getObjectFromGUID(GUID.bag.apocalypseDragon).takeObject({guid="a8bf9c", position={-51.63, 0.97, 45.88}, rotation={0, 180, 0}, smooth=false}).lock()--Oasis Reminder token
			if gStates.gameScenario=="Against the Apocalypse Blitz" then
				getObjectFromGUID(GUID.bag.apocalypseDragon).takeObject({guid="f64a50", position={-38.50, 0.98, 21.50}, rotation={0, 180, 0}, smooth=false}).lock()--Against the Apocalypse Reminder Card
				local startPosition={1, 4, 5, 6, 7, 9}
				gStates.againstTheApocSitePosition=startPosition[math.random(1,6)]
				getObjectFromGUID(GUID.bag.apocalypseDragon).takeObject({guid="e735d3", position={-40.87, 1.05, 21.50+2.895-(0.685*gStates.againstTheApocSitePosition)}, rotation={0, 90, 0}, smooth=false}).lock()--Neutral pointer shield token measured offf center of card.
				getObjectFromGUID(GUID.bag.apocalypseDragon).takeObject({guid=GUID.bag.destroyedSite, position={-43.00, 1.02, 26.00}, rotation={0, 180, 0}, smooth=false}).lock()--Destroyed Site Bag

			end
		end

		--Dragon scenarios use Possessed enemies and Apocalypse faction rewards even when the optional
		--Apocalypse terrain mix is removed. Keep both discard cycles available independently of terrain.
		if apocalypseDragonScenario()==true then
			local apocalypseBag=getObjectFromGUID(GUID.bag.apocalypseDragon)
			if apocalypseBag~=nil and getObjectFromGUID(GUID.bag.discard.apocReward)==nil then
				apocalypseBag.takeObject({guid=GUID.bag.discard.apocReward, position={2.00,0.98,16.00}, rotation={0,180,0}, smooth=false}).lock()
			end
			if apocalypseBag~=nil and getObjectFromGUID(GUID.bag.discard.possessed)==nil then
				apocalypseBag.takeObject({guid=GUID.bag.discard.possessed, position={-1.00,1.07,19.00}, rotation={0,180,0}, smooth=false}).lock()
			end
		end

		--Dragon scenarios destroy sites even when the optional Apocalypse terrain mix is off.
		if apocalypseDragonScenario()==true and getObjectFromGUID(GUID.bag.destroyedSite)==nil then
			getObjectFromGUID(GUID.bag.apocalypseDragon).takeObject({guid=GUID.bag.destroyedSite,position={-43.00,1.02,26.00},rotation={0,180,0},smooth=false}).lock()
		end

		--Set up the Apocalypse Dragon large head tokens for Dragon scenarios.
		if apocalypseDragonScenario()==true then setupApocalypseDragonHeads() end
		if apocalypseIsHereSetup~=nil then apocalypseIsHereSetup() end

		--Merge Ultimate Edition Components
		if gStates.removeBonusCards==false then
			safeTakeObject("SetupGame",getObjectFromGUID(GUID.bag.common),{position={getObjectFromGUID(GUID.deck.action).getPosition()[1], -2, getObjectFromGUID(GUID.deck.action).getPosition()[3]},
				guid="96f761", smooth=false, callback_function=function(obj) safeWaitFrames("SetupGame",function() getObjectFromGUID(GUID.deck.action).putObject(obj) end) end})--Advanced Actions
			safeTakeObject("SetupGame",getObjectFromGUID(GUID.bag.common),{position={getObjectFromGUID(GUID.deck.artifact).getPosition()[1], -2, getObjectFromGUID(GUID.deck.artifact).getPosition()[3]},
				guid="085e69", smooth=false, callback_function=function(obj) safeWaitFrames("SetupGame",function() getObjectFromGUID(GUID.deck.artifact).putObject(obj) end) end})--artifacts
		end

		--include or remove Rise of the Forgemaster
		if gStates.riseOfTheForgemasters>=1 then
			safeTakeObject("SetupGame",getObjectFromGUID(GUID.bag.forgemaster),{position={getObjectFromGUID(GUID.deck.action).getPosition()[1], -2, getObjectFromGUID(GUID.deck.action).getPosition()[3]},
				smooth=false, guid="db5f9f", callback_function=function(obj) safeWaitFrames("SetupGame",function() getObjectFromGUID(GUID.deck.action).putObject(obj) end) end})--Advanced Actions
			safeTakeObject("SetupGame",getObjectFromGUID(GUID.bag.forgemaster),{position={getObjectFromGUID(GUID.deck.artifact).getPosition()[1], -2, getObjectFromGUID(GUID.deck.artifact).getPosition()[3]},
				smooth=false, guid="c48f76", callback_function=function(obj) safeWaitFrames("SetupGame",function() getObjectFromGUID(GUID.deck.artifact).putObject(obj) end) end})--artifacts
			safeTakeObject("SetupGame",getObjectFromGUID(GUID.bag.forgemaster),{position={getObjectFromGUID(GUID.deck.spell).getPosition()[1], -2, getObjectFromGUID(GUID.deck.spell).getPosition()[3]},
				smooth=false, guid="cfe630", callback_function=function(obj) safeWaitFrames("SetupGame",function() getObjectFromGUID(GUID.deck.spell).putObject(obj) end) end})--Spells
			getObjectFromGUID(GUID.bag.forgemaster).takeObject({rotation={0.0, 180.0, 0.0}, position={54.25, 0.98, 18.86}, guid="0a657b", smooth=false}) getObjectFromGUID("0a657b").lock()
			if gStates.riseOfTheForgemasters>=2 then
				safeTakeObject("SetupGame",getObjectFromGUID(GUID.bag.forgemaster),{position={getObjectFromGUID(GUID.deck.action).getPosition()[1], -2, getObjectFromGUID(GUID.deck.action).getPosition()[3]},
					smooth=false, guid="c89aea", callback_function=function(obj) safeWaitFrames("SetupGame",function() getObjectFromGUID(GUID.deck.action).putObject(obj) end) end})--Advanced Actions
				getObjectFromGUID(GUID.bag.forgemaster).takeObject({rotation={0.0, 180.0, 0.0}, position={-75.16, 0.99, -16.00}, guid="5ad84f", smooth=false}) getObjectFromGUID("5ad84f").lock()
				if gStates.riseOfTheForgemasters==3 then
					safeTakeObject("SetupGame",getObjectFromGUID(GUID.bag.forgemaster),{position={getObjectFromGUID(GUID.deck.action).getPosition()[1], -2, getObjectFromGUID(GUID.deck.action).getPosition()[3]},
						smooth=false, guid="3b0ed8", callback_function=function(obj) safeWaitFrames("SetupGame",function() getObjectFromGUID(GUID.deck.action).putObject(obj) end) end})--Advanced Actions
					safeTakeObject("SetupGame",getObjectFromGUID(GUID.bag.forgemaster),{position={getObjectFromGUID(GUID.deck.spell).getPosition()[1], -2, getObjectFromGUID(GUID.deck.spell).getPosition()[3]},
						smooth=false, guid="09fd8d", callback_function=function(obj) safeWaitFrames("SetupGame",function() getObjectFromGUID(GUID.deck.spell).putObject(obj) end) end})--Spells
					getObjectFromGUID(GUID.bag.forgemaster).takeObject({rotation={0.0, 180.0, 0.0}, position={-75.16, 0.99, -19.50}, guid="bbec6b", smooth=false}) getObjectFromGUID("bbec6b").lock()
					getObjectFromGUID(GUID.bag.forgemaster).takeObject({rotation={0.0, 180.0, 0.0}, position={-75.16, 0.99, -23.00}, guid="786414", smooth=false}) getObjectFromGUID("786414").lock()
					getObjectFromGUID(GUID.bag.forgemaster).takeObject({rotation={0.0, 180.0, 0.0}, position={-75.16, 0.99, -12.50}, guid="a28a71", smooth=false}) getObjectFromGUID("a28a71").lock()
					getObjectFromGUID(GUID.bag.forgemaster).takeObject({rotation={0.0, 180.0, 0.0}, position={-75.16, 0.99, -9.00}, guid="c14096", smooth=false}) getObjectFromGUID("c14096").lock()
				end
			end
		end

		--Monster Pug Setup
		monsterSetup()

		--Go through the five player positions and put out pieces based on the game settings
		playerSetup()

		--stagered setup
		local delay=0.5--was 1.6
		if gStates.playerCount==1 then delay=0.5 end
		safeWaitTime("SetupGame",function()
			--Setup all the decks and shuffles everything
			deckSetup()

			--Cleans up the "All skills" bag
			local allSkills=getObjectFromGUID(GUID.bag.allSkills)
			if gStates.dummyAllSkills==true then
				if gStates.playersRef==5 then
					safeWaitTime("SetupGame",function()
						allSkills.setPosition({getObjectFromGUID(dummyBoard).getPosition()[1]-5.62, 1.25, getObjectFromGUID(dummyBoard).getPosition()[3]+6.97})
						for skillGUID, skillDetails in pairs(skillTokens) do
							if (skillDetails.mage==turnOrder[1].mage or (customMages[skillDetails.mage]~=nil and gStates.useCustomMageKnights==false) or (skillDetails.mage=="Jormund" and gStates.riseOfTheForgemasters<3)) and
								skillDetails.skillType~="Comp" and skillGUID~="d90de4" and skillGUID~="9f5dc0" and skillGUID~="bfd0c5" then
								local obj=allSkills.takeObject({guid=skillGUID})
								obj.destruct()
							end
						end
						allSkills.shuffle()
					end, 1)
				end
			else
				allSkills.destruct()
			end

			safeWaitTime("SetupGame",function()
				--Add wounds to decks to allow allow max cards to be pooled
				local Wounds={[GUID.deck.spell]={"5c38e4", "ab778d"}, [GUID.deck.regularUnit]={"b5048c", "718f39"}}
				if gStates.mageKnightLevels==false then
					afterLoad()
					for _, woundCard in pairs(Wounds) do getObjectFromGUID(woundCard[1]).destruct() getObjectFromGUID(woundCard[2]).destruct() end
				else
					for destDeck, woundCards in pairs(Wounds) do
						for a=1, 2, 1 do
							getObjectFromGUID(woundCards[a]).unlock()
							getObjectFromGUID(destDeck).putObject(getObjectFromGUID(woundCards[a]))
						end
					end
					gStates.magesSetup=true
					mageLevelBoard()
					UI.show("LevelUpRules")
				end
				--Deal out Weather Cards
			end, 1.5)
		end, (delay))--*(gStates.playerCount+gStates.coop)
	end
end

--Monster Pug Setup
function monsterSetup()
	function mergeBags(source, destination, container)
		local temp=getObjectFromGUID(container).takeObject({position={getObjectFromGUID(destination).getPosition()[1], -2, getObjectFromGUID(destination).getPosition()[3]}, smooth=false, guid=source})
		safeWaitFrames("SetupGame",function()
			for b=1, #temp.getObjects(), 1 do
				getObjectFromGUID(destination).putObject(temp.takeObject())
			end
			getObjectFromGUID(source).destruct()
		end, 5)
	end
	if gStates.removeLostLegionExpansion==false then
		local LostLegion={["89a23e"]=monsterPiles.green, ["77e1c6"]=monsterPiles.tan, ["143108"]=monsterPiles.red, ["88ff48"]=monsterPiles.gray, ["bf4140"]=monsterPiles.purple, ["fe25be"]=monsterPiles.white, ["b65694"]=monsterPiles.yellow}
		for mergeBag, destinationBag in pairs(LostLegion) do
			mergeBags(mergeBag, destinationBag, GUID.bag.lostLegion)
		end
	end
	if gStates.removeShadesOfTezlaMonsters~=true then
		local darkCrusaderLocations={[monsterPiles.greenDark]={-48.63, 0.98, -6.00}, [monsterPiles.tanDark]={-48.63, 0.98, -3.50}, [monsterPiles.redDark]={-48.63, 0.98, -1.00},
							[darkCrusader.disc]={-52.00, 0.97, 6.50}, [darkCrusader.token]={-55.30, 0.97, 10.20}, [darkCrusader.terrainHex]={-34.70, 0.98, -27.00},
							["f8c83e"]={-65.16, 0.98, -5.50}, [GUID.bag.cemetery]={-36.09, 0.97, -24.87}, [monsterPiles.rewardDark]={-46.13, 0.98, 13.99}, ["2ca34f"]={-53.50, 0.98, 15.50}}
							--Necropolis Info Card, Graveyards, Rewards, Reward info card
		local elementalistLocations={[monsterPiles.greenElem]={-51.13, 0.98, -6.00}, [monsterPiles.tanElem]={-51.13, 0.98, -3.50}, [monsterPiles.redElem]={-51.13, 0.98, -1.00},
							[elementalist.disc]={-63.50, 0.97, 6.50}, [elementalist.token]={-67.00, 0.97, 10.20}, [elementalist.terrainHex]={-37.49, 0.98, -27.00},
							["7121c7"]={-70.16, 0.98, -5.50}, [monsterPiles.rewardElem]={-46.13, 0.98, 16.99}, ["8fe07e"]={-49.50, 0.98, 15.50}}
							--Hidden Valley Info Card, Rewards, Reward info card
		local mergeDestination={[monsterPiles.greenDark]=monsterPiles.green, [monsterPiles.tanDark]=monsterPiles.tan, [monsterPiles.redDark]=monsterPiles.red, [monsterPiles.greenElem]=monsterPiles.green, [monsterPiles.tanElem]=monsterPiles.tan, [monsterPiles.redElem]=monsterPiles.red}
		local allowed={[monsterPiles.rewardDark]=true, ["2ca34f"]=true, [monsterPiles.rewardElem]=true, ["8fe07e"]=true}
		local workingOn=darkCrusaderLocations
		for a=1, 2, 1 do
			for objGuid, location in pairs(workingOn) do
				if mergeDestination[objGuid]~=nil and gStates.gameScenario~="Life and Death" and gStates.gameScenario~="The War of Four" and
					((a==1 and gStates.gameScenario~="The Realm of the Dead Blitz") or (a==2 and gStates.gameScenario~="The Hidden Valley Blitz")) then
					mergeBags(objGuid, mergeDestination[objGuid], GUID.bag.tezla)
				else
					if allowed[objGuid]~=nil or gStates.gameScenario=="Life and Death" or gStates.gameScenario=="The War of Four" or gStates.gameScenario=="Ultimate Conquest" or
						(a==1 and gStates.gameScenario=="The Realm of the Dead Blitz") or (a==2 and gStates.gameScenario=="The Hidden Valley Blitz") then
						local flip=0
						if mergeDestination[objGuid]~=nil or objGuid==GUID.bag.cemetery then flip=180 end
						local obj=getObjectFromGUID(GUID.bag.tezla).takeObject({guid=objGuid, position=location, rotation={0, 180, flip}, smooth=false}).lock()
					end
				end
			end
			workingOn=elementalistLocations
		end
		if gStates.gameScenario=="Life and Death" then getObjectFromGUID(GUID.bag.tezla).takeObject({guid="27911e", smooth=false, position={-50.63, 1.47, 1.16}}) end --Faction Die
	end
	if gStates.removeShadesOfTezlaMonsters==true and gStates.useCustomMageKnights==true then
		getObjectFromGUID(GUID.bag.tezla).takeObject({guid=monsterPiles.rewardElem, position={-46.13, 0.98, 16.99}, rotation={0, 180, 0}, smooth=false}).lock()
		getObjectFromGUID(GUID.bag.tezla).takeObject({guid="8fe07e", position={-49.50, 0.98, 15.50}, rotation={0, 180, 0}, smooth=false}).lock()
		getObjectFromGUID(GUID.bag.tezla).takeObject({guid=monsterPiles.rewardDark, position={-46.13, 0.98, 13.99}, rotation={0, 180, 0}, smooth=false}).lock()
		getObjectFromGUID(GUID.bag.tezla).takeObject({guid="2ca34f", position={-53.50, 0.98, 15.50}, rotation={0, 180, 0}, smooth=false}).lock()
	end
	--set faction leader levels
	local leaderLevel=gStates.cityLevels[1]
	safeWaitFrames("SetupGame",function()
		if gStates.gameScenario~="Ultimate Conquest" then
			if getObjectFromGUID(elementalist.disc)~=nil then
				getObjectFromGUID(elementalist.disc).setCustomObject({image=leaderData[elementalist.terrainHex][leaderLevel].discImg})
				getObjectFromGUID(elementalist.disc).reload()
				getObjectFromGUID(elementalist.token).setCustomObject({image=leaderData[elementalist.terrainHex][leaderLevel].tokenImg})
				getObjectFromGUID(elementalist.token).setName("Elementalist Leader Level "..leaderLevel)
				getObjectFromGUID(elementalist.token).reload()
				monsterPugs[elementalist.token]=leaderData[elementalist.terrainHex][leaderLevel].abilities
				gStates.elementalistLevel=leaderLevel
				gStates.cityMonsterQty[elementalist.terrainHex]={[elementalist.token]="alive", extra={}}
				gStates.monsterPlayLocation[elementalist.token]={-55.3, 3.0, 15.3}
			end
			if getObjectFromGUID(darkCrusader.disc)~=nil then
				getObjectFromGUID(darkCrusader.disc).setCustomObject({image=leaderData[darkCrusader.terrainHex][leaderLevel].discImg})
				getObjectFromGUID(darkCrusader.disc).reload()
				getObjectFromGUID(darkCrusader.token).setCustomObject({image=leaderData[darkCrusader.terrainHex][leaderLevel].tokenImg})
				getObjectFromGUID(darkCrusader.token).setName("Dark Crusader Leader Level "..leaderLevel)
				getObjectFromGUID(darkCrusader.token).reload()
				monsterPugs[darkCrusader.token]=leaderData[darkCrusader.terrainHex][leaderLevel].abilities
				gStates.darkCrusaderLevel=leaderLevel
				gStates.cityMonsterQty[darkCrusader.terrainHex]={[darkCrusader.token]="alive", extra={}}
				gStates.monsterPlayLocation[darkCrusader.token]={-55.3, 3.0, 6.7}
			end
		end
		if getObjectFromGUID(darkCrusader.token)~=nil then
			getObjectFromGUID(darkCrusader.token).addDecal({name="NightRules", position={0.85, 0.15, -0.85}, rotation={90, 180, 0}, scale={0.6, 0.6, 1}, url=nightRulesDecal})
			if gStates.monsterPerks[darkCrusader.token]==nil then gStates.monsterPerks[darkCrusader.token]={nightRules=true} else gStates.monsterPerks[darkCrusader.token].nightRules=true end
		end
	end, 5)

	--shuffle all monster piles
	safeWaitTime("SetupGame",function()
		local ToBeShuffled={monsterPiles.redElem, monsterPiles.tanElem, monsterPiles.greenElem, monsterPiles.rewardElem,								 --Dragons Ele,  Dungeon Ele,  Orcs Ele,  Rewards Ele
							monsterPiles.redDark, monsterPiles.tanDark, monsterPiles.greenDark, monsterPiles.rewardDark,								 --Dragons Dark, Dungeon Dark, Orcs Dark, Rewards Dark
							monsterPiles.rewardApoc, monsterPiles.rewardCouncil, monsterPiles.possessed,								 --Apocalypse Cult Rewards, Council of the Void Rewards, Possessed Tokens
							monsterPiles.tan, monsterPiles.green, monsterPiles.red, monsterPiles.purple, monsterPiles.white, monsterPiles.gray, monsterPiles.yellow}--Dungeon, Orcs, Dragons, Mage Tower, City, Keep, Ruins
		for a=1, #ToBeShuffled, 1 do
			if getObjectFromGUID(ToBeShuffled[a])~=nil then getObjectFromGUID(ToBeShuffled[a]).shuffle() end
		end
	end, 1)--same as the deck shuffling
end

--Go through the five player positions and put out pieces based on the game settings
function playerSetup()
	if gStates.heroChallenges==true then gStates.heroChallengeReservedSkills={} end
	--generate random Mage Knights if needed
	gStates.originalChoiceMageKnights={gStates.positionMageKnight[1], gStates.positionMageKnight[2], gStates.positionMageKnight[3], gStates.positionMageKnight[4], gStates.positionMageKnight[5]}
	for a=1, 5, 1 do
		if gStates.positionMageKnight[a]=="Random" or gStates.positionMageKnight[a]=="All Skills" then
			local randomMK=""
			local duplicate=true
			while duplicate==true do
				duplicate=false
				randomMK=mageKnights[math.random(1, #mageKnights-3)].mage
				for a=1, 5, 1 do
					if randomMK==gStates.positionMageKnight[a] then duplicate=true break end
				end
				if gStates.useCustomMageKnights==false and customMages[randomMK]~=nil then duplicate=true end
				if gStates.riseOfTheForgemasters~=3 and randomMK=="Jormund" then duplicate=true end
				if duplicate==false and gStates.heroChallenges==true then
					if heroChallengesData[randomMK]==nil then
						duplicate=true
					else
						--Quick Random Game bypasses the setup Start-button legality check. Temporarily test the
						--candidate here so a random Hero never creates an impossible Challenge terrain setup.
						local oldChoice=gStates.positionMageKnight[a]
						gStates.positionMageKnight[a]=randomMK
						local assignment=heroChallengeCountryAssignment(false)
						gStates.positionMageKnight[a]=oldChoice
						if assignment==nil then duplicate=true end
					end
				end
			end
			gStates.positionMageKnight[a]=randomMK
		end
	end

	--The selected Mage Knight's normal Shield source may belong to a player position that is cleaned
	--before the Dummy/Proxy position is built. Preserve a dedicated Proxy copy first.
	if proxyPlayerActive()==true then proxyStageShieldBag() end

	--Setup Players Mats.
	local DummyPlayed=0
	local positionOrder={2, 3, 4, 1, 5}--positions are built in this order so dummy is put in the middle
	local startPos=		{0, 0, 0, 0, 0}--records if a position has been used for a turn order token.
	local time=0
	local delay=1.6
	local DummyPlayedTiming=0
	for a=1, 5, 1 do
		--Wait.time(function()
			local offsetPosition=positionOrder[a]*40-40
			local CommonParts={	{-72.50, 0.98, -38.00}, {-68.60, 1.37, -30.80}, {-68.60, 1.37, -32.40},							--Dummy Board, Black Mana, Gold Mana
								{-67.30, 1.37, -30.80}, {-67.30, 1.37, -32.40}, {-65.90, 1.37, -30.80}, {-65.9, 1.37, -32.40},	--Blue Mana, Green Mana, Red Mana, White Mana
								{-41.95, 1.08, -36.10}, {-41.76, 1.14, -31.10}, {-41.76, 1.16, -34.41},							--Wound Cards, Wound Tokens, Keep Token
								{-69.30, 1.35, -29.30}, {-68.00, 1.35, -29.30}, {-66.70, 1.35, -29.30}, {-65.40, 1.35, -29.30}, --Blue Shard, Green Shard, Red Shard, White Shard
								{-76.30, 1.35, -29.30}, {-75.00, 1.35, -29.30}, {-73.70, 1.35, -29.30}, {-72.40, 1.35, -29.30}} --Blue Potion, Green Potion, Red Potion, White Potion
			--Checks if the position has a player, dummy or Volkare required
			if (gStates.positionMageKnight[positionOrder[a]]~="nobody" and positionOrder[a]<=4) or (gStates.positionMageKnight[5]~="nobody" and DummyPlayed==0) then
				--Layout everything from the Common Bag if needed
				local CommonBag=getObjectFromGUID(GUID.bag.common).clone()
				CommonBag.setPosition({-60.0+offsetPosition, 1.5, -38.0})
				for i=1, #CommonParts, 1 do
					local skip=0
					local params={position=CommonParts[i], rotation={0, 180, 0}, smooth=false}
					params.position[1]=params.position[1]+offsetPosition
					if (i>=2 and i<=7) or (i>=11 and i<=14) then params.rotation={0, 30, 0} end
					if positionOrder[a]==5 then params.position[1]=params.position[1]-25.2 params.position[3]=params.position[3]+21.1 end
					if i==1 and positionOrder[a]<=4 and gStates.positionMageKnight[positionOrder[a]]~="nobody" then local obj=CommonBag.takeObject() obj.destruct() skip=1 end--destroy the Dummy Board if this is a player
					if i==1 and positionOrder[a]<=4 and gStates.positionMageKnight[positionOrder[a]]=="nobody" then--change a player position into a dummy position
						getObjectFromGUID(playerBoard[positionOrder[a]]).destruct()
						getObjectFromGUID(colorBand[positionOrder[a]]).setScale({7.48, 0.01, 2.5})
						getObjectFromGUID(colorBand[positionOrder[a]]).setColorTint("Black")
						getObjectFromGUID(colorBand[positionOrder[a]]).setPosition({getObjectFromGUID(colorBand[positionOrder[a]]).getPosition()[1]-12.5, 0.98, -30.0})
						if getObjectFromGUID(playAreaGuideText[positionOrder[a]])~=nil then getObjectFromGUID(playAreaGuideText[positionOrder[a]]).destruct() end
						if getObjectFromGUID(playAreaGuideBackground[positionOrder[a]])~=nil then getObjectFromGUID(playAreaGuideBackground[positionOrder[a]]).destruct() end
					end
					if i==8 and positionOrder[a]<=4 and gStates.positionMageKnight[positionOrder[a]]~="nobody" then--snuck the new poison card in with the regular wound cards
						CommonBag.takeObject({guid="d1e6c3", position={-40.86+offsetPosition, 1.08, -36.10}, smooth=false}).lock()
					end
					if (gStates.positionMageKnight[positionOrder[a]]=="nobody" or positionOrder[a]==5) and ((i>=2 and gStates.positionMageKnight[5]=="Volkare") or (i>=8 and gStates.positionMageKnight[5]~="nobody")) then DummyPlayed=1 break end--just dummy board for Volkare
					if i>=11 and gStates.riseOfTheForgemasters<=1 then break end
					if i>=15 and gStates.riseOfTheForgemasters<=2 then break end
					if skip==0 then local obj=safeTakeObject("SetupGame",CommonBag,params).lock() end
				end
				CommonBag.destruct()

				--mirror source
				if (gStates.positionMageKnight[positionOrder[a]]~="nobody" and positionOrder[a]~=5) then
					local obj=getObjectFromGUID("b5a6ce").clone()
					obj.setPosition({-58.25+offsetPosition, 0.98, -28.53})
					safeWaitTime("SetupGame",function() safeWaitCondition("SetupGame",function()
						obj.lock()
						obj.setRotation({0, 180, 0})
						obj.registerCollisions()
						gStates.mirrorSource[#gStates.mirrorSource+1]=obj.guid
					end, function() return obj.resting end) end, 0.1)
				end

				--Figure out which Mage Knight is assigned to a position
				local PlayerBag={}
				for i=1, #mageKnights, 1 do
					if gStates.positionMageKnight[positionOrder[a]]==mageKnights[i].mage or (gStates.positionMageKnight[positionOrder[a]]=="nobody" and gStates.positionMageKnight[5]==mageKnights[i].mage) then
						PlayerBag=getObjectFromGUID(mageKnights[i].bag).clone()
						PlayerBag.setPosition({-60.0+offsetPosition, 1.5, -38.0})
						break
					end
				end

				--Layout everything from the mage bag assigned to the position
				local UniqueParts={	{  0.40, 1.55, -19.17}, {-74.19, 1.50, -43.16}, {-72.89, 1.10, -35.13}, {-67.46, 1.60, -36.88}, {-77.30, 1.05, -49.00}, {-73.90, 1.05, -49.00}, --{-67.33, 1.99, -36.88}, {-67.33, 1.99, -36.88},
									{-10.00, 1.25, -27.50}, { 12.10, 1.25,  24.5}, { 40.15, 1.25,  18.6}, {-66.40, 1.16, -34.25}, {-41.76, 1.16, -32.78},
									{-63.57, 1.50, -31.19},	{-68.24, 1.10, -34.4}}
									--1-Turn Order, 2-Unique Cards, 3-Dummy Inventory, 4-Skills, 5-Skill Reference Card 1, 6-Skill Reference Card 2,
									--7-Avatar, 8-Shield Fame, 9-Shield Rep, 10-Shield Control, 11-Quest Marker,
									--12-Comand token Blank, 13-5 Command Tokens
				local turnRef=1
				for i=1, #UniqueParts, 1 do
					local skip=0
					local params={position=UniqueParts[i], smooth=false, setColorTint=""}
					params.position[1]=params.position[1]+offsetPosition
					--turn markers all go in Shuffled Order
					if i==1 then
						if (gStates.positionMageKnight[positionOrder[a]]=="nobody" or positionOrder[a]==5) then--Dummy and Volkare
							local dummyStats={	seatPos=positionOrder[a], mage=gStates.positionMageKnight[5], fame=0, fameGain=0, reputation=0, repGain=0, scoreLoop=0, hand=5, baseHand=5, handBonus=0, tactic=1, keepsBeat=0, gladesMarked={}, deedCount=11, discardCount=0, defeatedCities={}, deadDeckInventory={}, score={Glade=0, GraveYard=0},
												dummyCrystals={["Red"]=0, Blue=0, Green=0, ["White"]=0}}
							if scenarioList[gStates.scenarioRef][gStates.playersRef].dummyTacticSelection=="F" then
								params.position={-1.9, 0.96, -19.4}--if dummy draws first
								startPos[1]=1
								turnOrder[1]=dummyStats
							else
								params.position={-1.9, 0.96, -19.4-(gStates.playerCount*1.4)}--if dummy draw last
								startPos[gStates.playerCount+1]=1
								turnOrder[gStates.playerCount+1]=dummyStats
								turnOrder[gStates.playerCount+1].tactic=gStates.playerCount+1
								turnRef=gStates.playerCount+1
							end
						else--Mage Knights
							local duplicate=true
							while duplicate==true do
								duplicate=false
								turnRef=math.random(1, gStates.playerCount)
								if scenarioList[gStates.scenarioRef][gStates.playersRef].dummyTacticSelection=="F" then turnRef=turnRef+1 end
								if startPos[turnRef]==1 then duplicate=true else startPos[turnRef]=1 end
							end
							params.position={-1.9, 0.96, -19.4-((turnRef-1)*1.4)}
							turnOrder[turnRef]={seatPos=positionOrder[a],mage=gStates.positionMageKnight[positionOrder[a]], fame=0, fameGain=0, reputation=0, repGain=0, scoreLoop=0, level=1, levelUp=0, influence=6, hand=5, baseHand=5, handBonus=0, tactic=turnRef, keepsBeat=0, gladesMarked={}, deedCount=11, discardCount=0, combatIconHide="None", defeatedCities={}, levelUpComplete=false, avatarLocation="portal", deadDeckInventory={}, levelingStats={}, score={Glade=0, GraveYard=0}}
						end
					end

					--Player Deed Deck
					if i==2 then
						params.rotation={180, 0, 0}--Orient cards face down
						if (gStates.positionMageKnight[positionOrder[a]]=="nobody" or positionOrder[a]==5) then--Dummy and Volkare deck go in different spot
							params.position={-67.96+offsetPosition, 1.17, -43.17}
						end
						params.callback_function=function(obj) obj.shuffle() end
					end

					--Dummy Invetory Card
					if i==3 and (gStates.positionMageKnight[positionOrder[a]]~="nobody" and positionOrder[a]<5) then local destr=safeTakeObject("SetupGame",PlayerBag,params) destr.destruct() skip=1 end--Delete Dummy Inventory when this is a player

					--Skills Container or Volkare's Level Chart
					if i==4 then
						if (gStates.positionMageKnight[positionOrder[a]]=="nobody" or positionOrder[a]==5) then--Checks if this position is a dummy
							if gStates.positionMageKnight[5]=="Volkare" then
								params.position={39.16, 0.97, 35.00}
								params.guid="b2ec85"--Volkare Level Chart: explicit GUID pull rather than relying on bag order.
							else
								if gStates.playerCount==1 and gStates.dummyAllSkills==false then
									params.position={-78.12+offsetPosition, 1.6, -31.03}--Skills container Position
								else
									local destr=safeTakeObject("SetupGame",PlayerBag,params) destr.destruct() skip=1
								end
							end
						end
					end

					--Skill Refernce Card 1
					if i==5 and (gStates.positionMageKnight[positionOrder[a]]=="nobody" or positionOrder[a]==5) and ((gStates.positionMageKnight[5]=="Volkare" or gStates.playerCount~=1) or gStates.dummyAllSkills==true) then
						local destr=safeTakeObject("SetupGame",PlayerBag,params) destr.destruct() skip=1
					end

					--Skill Refernce Card 2
					if i==6 then
						if (gStates.positionMageKnight[positionOrder[a]]=="nobody" or positionOrder[a]==5) and ((gStates.positionMageKnight[5]=="Volkare" or gStates.playerCount~=1) or gStates.dummyAllSkills==true) then
							local destr=safeTakeObject("SetupGame",PlayerBag,params) destr.destruct() skip=1
						else
							params.callback_function=function(obj) obj.lock() end
							if (gStates.coop==0 or gStates.WarOfFourComp==true) and gStates.positionMageKnight[positionOrder[a]]~="Ymirgh" and gStates.positionMageKnight[positionOrder[a]]~="Malek" and gStates.positionMageKnight[positionOrder[a]]~="Duscenia" and gStates.positionMageKnight[positionOrder[a]]~="Mevok"then--"Mevok"
								params.callback_function=function(ob) local obj=ob.setState(1) obj.lock() end
							end
						end
					end

					--Player Avater or Volkare's Wound Card
					if i==7 then
						if (gStates.positionMageKnight[positionOrder[a]]=="nobody" or positionOrder[a]==5) then--Checks if this position is a dummy
							if gStates.positionMageKnight[5]=="Volkare" then
								params.rotation={180, 0, 0}
								params.position={-67.96+offsetPosition, 1.17, -50.17}--Flip wound card over if Volkare
								params.callback_function=volkareSetup
							elseif proxyPlayerActive()==true then
								--Use one of the same four Portal-card positions as a normal player whenever one is free.
								--With four human players there is no fifth Portal position, so the Proxy starts on the Dummy board instead.
								local proxyPos,onPortal=proxySetupAvatarPosition()
								params.position=proxyPos
								params.callback_function=function(obj)
									obj.unlock()
									gStates.proxyAvatarOffMap=(onPortal~=true)
									local proxyIndex=proxyPlayerIndex()
									if proxyIndex~=nil and turnOrder[proxyIndex]~=nil then turnOrder[proxyIndex].avatarLocation=onPortal==true and "portal" or nil end
								end
							else
								local destr=safeTakeObject("SetupGame",PlayerBag,params) destr.destruct() skip=1
							end
						else
							--params.position[1]=params.position[1]-(offsetPosition/1.07)--Avatar
							local portalPosition={{-42.5, 1.3, -11.4}, {-45.5, 1.3, -13.2}, {-42.5, 1.3, -13.2}, {-45.5, 1.3, -11.4}, {-43.94, 1.3, -12.36}}
							params.position=portalPosition[a]
						end
					end

					--Fame Marker, Volkare's Terrain Tile or Dummy's Crystals. Dummy is Setup
					if i==8 then
						if (gStates.positionMageKnight[positionOrder[a]]=="nobody" or positionOrder[a]==5) then--Checks if this position is a dummy
							if positionOrder[a]<5 then
								getObjectFromGUID(deedDeckZones[positionOrder[a]]).setPosition({offsetPosition-68, 1.15, -43.20})
								getObjectFromGUID(deedDeckDiscardZones[positionOrder[a]]).setPosition({offsetPosition-77.21, 1.15, -43.20})
						 	end
							if gStates.positionMageKnight[5]=="Volkare" then
								if gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz" then
									params.position={-37.2305, 2.0, -5.6911}--Volkare's Return camp tile position
								else
									params.position={-12.0297, 2.0,  8.8586}--Volkare's Quest and The War of Four camp tile position
								end
								terrainTiles["835c91"].hexFeature.center=""
								gStates.hexOverideSave["835c91"]={center=""}
								if gStates.randomTileOrientation==false then params.rotation={0, 180, 180} else params.rotation={0, math.random(1, 6)*60, 180} end
								params.guid="835c91"
								local obj=safeTakeObject("SetupGame",getObjectFromGUID(GUID.bag.terrain.leftCity),params)
								if obj==nil then error("Volkare setup missing Camp terrain tile 835c91 from City terrain bag",2) end
								skip=1
							else
								local params={position={-69.4, 1.41, -36.5}, rotation={0, 30, 0}, smooth=false, index=0}
								if positionOrder[a]==5 then params.position[1]=params.position[1]-25.2 params.position[3]=params.position[3]+21.1 end
								params.position[1]=params.position[1]+offsetPosition
								for a=1, 3, 1 do
									params.position[1]=params.position[1]-(1.7)
									local obj=safeTakeObject("SetupGame",PlayerBag,params)
								 	obj.lock()
									local b=obj.getDescription()
									if scenarioList[gStates.scenarioRef][gStates.playersRef].dummyTacticSelection=="F" then
										turnOrder[1].dummyCrystals[b]=turnOrder[1].dummyCrystals[b]+1
									else
										turnOrder[gStates.playerCount+1].dummyCrystals[b]=turnOrder[gStates.playerCount+1].dummyCrystals[b]+1
									end
								end
								break
							end
						else
							params.position[1]=(params.position[1]-(offsetPosition/1.032))+(5.3*gStates.blitz)--Fame Marker
						end
					end

					--Reputation Marker or Volkare's Avatar
					local colorReputation={	{{34.02, 1.14, 21.26}, {34.50, 1.14, 22.57}, {34.99, 1.14, 23.91}, {33.53, 1.21, 19.98}},--(-2)
											{{36.70, 1.20, 20.25}, {37.33, 1.14, 21.45}, {38.02, 1.14, 22.63}, {36.11, 1.14, 19.04}},--(-1)
											{{39.87, 1.13, 19.41}, {38.79, 1.13, 18.75}, {41.16, 1.13, 19.20}, {40.33, 1.13, 20.87}},--(0)
											{{39.03, 1.13, 16.00}, {40.18, 1.13, 16.30}, {41.37, 1.13, 16.56}, {37.87, 1.13, 15.74}}}--(+1)
					if i==9 then
						if (gStates.positionMageKnight[positionOrder[a]]=="nobody" or positionOrder[a]==5) then--Checks if this position is a dummy
							if gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz" then
								params.position={-37.2305, 1.6, -5.6911}--Volkare's Return Avatar position
							else
								params.position={-12.0297, 1.6, 8.8586}--Volkare's Quest Avatar position
							end
							local obj=safeTakeObject("SetupGame",PlayerBag,params)
							skip=1
						else
							local blitzSub=gStates.blitz
							params.position=colorReputation[0+blitzSub-gStates.rampage+3][positionOrder[a]]--Reputation Marker
							turnOrder[turnRef].reputation=(0+blitzSub-gStates.rampage)*2
						end
					end

					-- or Volkare's Arrow Guide or Volkares Dice
					if i==10 then
						if ((positionOrder[a]<5 and gStates.positionMageKnight[positionOrder[a]]=="nobody" and gStates.positionMageKnight[5]=="Volkare") or gStates.positionMageKnight[positionOrder[a]]=="Volkare") then
							params.position={-72.89+offsetPosition,1.5,-33.0}--Volkare Dice
						end
					end

					--or Volkares Scenario Reference Card
					if i==11 then
						if (positionOrder[a]<5 and gStates.positionMageKnight[positionOrder[a]]=="nobody" and gStates.positionMageKnight[5]=="Volkare") or gStates.positionMageKnight[positionOrder[a]]=="Volkare" then
							params.position={-72.5+offsetPosition, 1.06, -48.23}
							params.callback_function=function(obj) obj.lock() end
							if gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz" then
								params.callback_function=function(ob) local obj=ob.setState(2) obj.lock() end
							end
						end
					end

					--Volkare's Marker
					if i==12 then
						if (positionOrder[a]<5 and gStates.positionMageKnight[positionOrder[a]]=="nobody" and gStates.positionMageKnight[5]=="Volkare") or gStates.positionMageKnight[positionOrder[a]]=="Volkare" then
							params.position={-76+offsetPosition, 1.16, -31}
							params.callback_function=function(obj) obj.lock() end
						else
							params.rotation={0.00, 180.00, 180.00}
						end
					end

					if i==13 then
						if (positionOrder[a]<5 and gStates.positionMageKnight[positionOrder[a]]=="nobody" and gStates.positionMageKnight[5]=="Volkare") or gStates.positionMageKnight[positionOrder[a]]=="Volkare" then
							if gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz" then
								params.position={-37.23, 2.5, -5.69}
								params.rotation={0.0, 210.0, 0.0}--Volkare's Return Guide position
								params.callback_function=function() safeWaitFrames("SetupGame",function() getObjectFromGUID("bc4dcc").jointTo(getObjectFromGUID(volkare.model), {["type"]="Fixed"}) end, 5) end
							else
								params.position={-12.03, 2.5, 8.86}--Volkare's Quest Guide position
								params.rotation={0.0, 210.0, 0.0}
								params.callback_function=function() safeWaitFrames("SetupGame",function() getObjectFromGUID("bc4dcc").setState(2) safeWaitFrames("SetupGame",function() getObjectFromGUID("be2dc2").jointTo(getObjectFromGUID(volkare.model), {["type"]="Fixed"}) end, 5) end, 5) end
							end
							skip=1
						end
					end

					--Volkare is Setup
					if i==13 and (gStates.positionMageKnight[positionOrder[a]]=="nobody" or positionOrder[a]==5) then break end

					if positionOrder[a]==5 and i~=1 then params.position[1]=params.position[1]-25.2 params.position[3]=params.position[3]+21.1 end
					if skip==0 then
						local obj=safeTakeObject("SetupGame",PlayerBag,params)
						if (i==4 or i==5 or i==10 or i==11 or i==13) and gStates.positionMageKnight[positionOrder[a]]~="nobody" and positionOrder[a]<5 then obj.lock() end--lock player board components
						if (i==1 or i==3 or i==4 or i==5 or i==11) and (gStates.positionMageKnight[positionOrder[a]]=="nobody" or positionOrder[a]==5) then obj.lock() end--lock dummy board components
						if i==1 then turnOrder[turnRef].turnOrderTokenGUID=obj.guid end
						if (i==4 and gStates.positionMageKnight[positionOrder[a]]~="nobody" and positionOrder[a]<=4) or (i==4 and gStates.playerCount==1) then
							turnOrder[turnRef].skillBagGUID=obj.guid
							--Hero Challenges reserve the prescribed first Skill before the Hero's remaining Skill bag is shuffled.
							if gStates.heroChallenges==true and positionOrder[a]<=4 and gStates.positionMageKnight[positionOrder[a]]~="nobody" then
								local challenge=heroChallengesData[turnOrder[turnRef].mage]
								if challenge~=nil then
									local reserved=obj.takeObject({guid=challenge.skillGUID,position={(positionOrder[a]*40)-113.0,1.5,-48.9},rotation={0,180,0},smooth=false})
									--turnOrder is re-sorted during play, so reserve by stable Mage Knight identity rather than array index.
									if reserved~=nil then reserved.lock() gStates.heroChallengeReservedSkills[turnOrder[turnRef].mage]=reserved.guid end
								end
							end
							obj.shuffle()
						end
						if i==8 and gStates.positionMageKnight[positionOrder[a]]~="nobody" and positionOrder[a]<=4 then turnOrder[turnRef].fameGUID=obj.guid end
						if i==9 and gStates.positionMageKnight[positionOrder[a]]~="nobody" and positionOrder[a]<=4 then turnOrder[turnRef].reputationGUID=obj.guid end
						if i==13 and gStates.positionMageKnight[positionOrder[a]]~="nobody" and positionOrder[a]<=4 then turnOrder[turnRef].commandGUID=obj.guid end
						local inventories={	["Arythea"]="https://steamusercontent-a.akamaihd.net/ugc/1688270498378077447/DA7FA05E7349C9E1C99C318032043429816C861D/",
											["Braevalar"]="https://steamusercontent-a.akamaihd.net/ugc/1688270498378077718/DCE81E61A3E1B96D8BA93A4F8793A10FB665FB6B/",
											["Goldyx"]="https://steamusercontent-a.akamaihd.net/ugc/1688270498378077961/390B23321D1B2E3F34B1A029FFB2FB9C84262763/",
											["Jormund"]="https://steamusercontent-a.akamaihd.net/ugc/1795241588983562972/1557BE3291E3A706D57FBFDBE5A72E7FAAB2CDF1/",
											["Mevok"]="https://steamusercontent-a.akamaihd.net/ugc/2546304515601825153/FC93E96C09CB79AC93C52094C1B5287D811FA482/",
											["Duscenia"]="https://steamusercontent-a.akamaihd.net/ugc/2546304515601824613/3B452F1B422F9671596713E2AFAAD60D41D3D16F/",
											["Malek"]="https://steamusercontent-a.akamaihd.net/ugc/14943218316842257893/D58F0F6FCC4FE321C759297C11AE9F56BE11B0FD/",
											["Krang"]="https://steamusercontent-a.akamaihd.net/ugc/1688270498378078687/F80D82EF2E26084CEB57089D002A0302D97DEC6B/",
											["Norowas"]="https://steamusercontent-a.akamaihd.net/ugc/1688270498378079060/8711BC1DD995631FD7EEEC2747ADB204C806CE5C/",
											["Tovak"]="https://steamusercontent-a.akamaihd.net/ugc/1688270498378079257/2B4D0055D769A2F0A24EEBC1940C0A50F834A9C0/",
											["Wolfhawk"]="https://steamusercontent-a.akamaihd.net/ugc/1688270498378079469/999F91445334DECE8125779EB46C1A5C46687A9D/",
											["Coral"]="https://steamusercontent-a.akamaihd.net/ugc/14667008316248124108/D5989267D0EA9DC649819CA8E597860FA8B9F92C/",
											["Zirtae"]="https://steamusercontent-a.akamaihd.net/ugc/17952541848407306110/B100358117F2DBF3F181B3FD347B14C77AA26308/",
											["Ymirgh"]="https://steamusercontent-a.akamaihd.net/ugc/1688270498378079688/47CE3F5B6A9F817FB562B5E9864E7F761CC62F97/"}
						if i==1 and gStates.positionMageKnight[positionOrder[a]]~="nobody" and positionOrder[a]<=4 then
							local inventoryImage=inventories[gStates.positionMageKnight[positionOrder[a]]]
							if inventoryImage~=nil then getObjectFromGUID(playerBoard[positionOrder[a]]).addDecal({name="Mage Inventory", url=inventoryImage, position={1.735, 0.11, -0.32}, rotation={90.0, 180.0, 0.0}, scale={1.164, 1.219, 10}}) end
							turnOrder[turnRef].playerBoardGUID=playerBoard[positionOrder[a]]
						end
					end
				end
				if gStates.positionMageKnight[positionOrder[a]]=="Mevok" then
					local obj=safeTakeObject("SetupGame",PlayerBag,{guid="32bc89", position={-77.30+offsetPosition, 1.05, -53.65}, smooth=false, setColorTint="", callback_function=function(obj) obj.lock() end})
					local obj=safeTakeObject("SetupGame",PlayerBag,{guid="2dbfde", position={-73.90+offsetPosition, 1.05, -53.65}, smooth=false, setColorTint="", callback_function=function(obj) obj.lock() end})
				end
				PlayerBag.destruct()
			else
				--clean up that positions area
				getObjectFromGUID(deedDeckZones[positionOrder[a]]).destruct()
				getObjectFromGUID(deedDeckDiscardZones[positionOrder[a]]).destruct()
				getObjectFromGUID(colorBand[positionOrder[a]]).destruct()
				if a~=5 then getObjectFromGUID(playerBoard[positionOrder[a]]).destruct() end
				if getObjectFromGUID(playAreaGuideText[positionOrder[a]])~=nil then getObjectFromGUID(playAreaGuideText[positionOrder[a]]).destruct() end
				if getObjectFromGUID(playAreaGuideBackground[positionOrder[a]])~=nil then getObjectFromGUID(playAreaGuideBackground[positionOrder[a]]).destruct() end
			end
		--end, time)
		--if a<5 then
		--	if (gStates.positionMageKnight[positionOrder[a+1]]~="nobody" and positionOrder[a+1]<=4) or (gStates.positionMageKnight[5]~="nobody" and DummyPlayedTiming==0) then
		--		time=time+delay
		--	end
		--	if (gStates.positionMageKnight[positionOrder[a+1]]=="nobody" or positionOrder[a+1]==5) and gStates.positionMageKnight[5]~="nobody" then DummyPlayedTiming=1 end
		--end
	end
	--The Proxy uses a visible copy of their Mage Knight's infinite Shield bag beside the Dummy setup,
	--plus the two Apocalypse Proxy reference cards immediately to the right of the Skill reference cards.
	if proxyPlayerActive()==true then
		safeWaitFrames("SetupGame",function()
			proxySetupReferenceCards()
			proxySetupShieldBag()
		end,10)
	end
end

--Setup additional volkare components (Skill for Solo, Unit Crytals, And Monster Pugs)
function volkareSetup()
	--Add wounds to Volkare's Deck
	local VolkareWounds=20
	local PlayerBag={}
	if gStates.gameScenario=="The War of Four" then gStates.volkareRaceLevel=3 end
	if gStates.gameScenario=="Volkare's Quest" or gStates.gameScenario=="The War of Four" then VolkareWounds=24-(4*gStates.volkareRaceLevel) else VolkareWounds=21-(3*gStates.volkareRaceLevel)-(2*gStates.blitz) end
	if gStates.gameScenario=="Custom" then VolkareWounds=0 end
	for i=1, VolkareWounds, 1 do
		getObjectFromGUID(GUID.deck.volkare).putObject(getObjectFromGUID("a8e73d").clone({position={getObjectFromGUID(GUID.deck.volkare).getPosition()[1], -2, getObjectFromGUID(GUID.deck.volkare).getPosition()[3]}}))--The wound card to Volkare's Deck
	end
	getObjectFromGUID(GUID.deck.volkare).shuffle()
	if gStates.gameScenario~="Custom" then getObjectFromGUID("a8e73d").destruct() end--The wound card

	--Add a random skill set if solo playing
	if gStates.playerCount==1 and gStates.volkareSkills~="All Skills" then
		local duplicate=true
		local randomMKIndex=1
		if gStates.volkareSkills=="Random" then
			while duplicate==true do
				duplicate=false
				randomMKIndex=math.random(1, #mageKnights-3)
				local randomMK=mageKnights[randomMKIndex].mage
				for i=1, 4, 1 do
					if randomMK==gStates.positionMageKnight[i] then duplicate=true end
				end
				if gStates.useCustomMageKnights==false and customMages[randomMK]~=nil then duplicate=true end
				if gStates.riseOfTheForgemasters~=3 and randomMK=="Jormund" then duplicate=true end
			end
		else
			for index, mageDetails in ipairs(mageKnights) do
				if mageDetails.mage==gStates.volkareSkills then randomMKIndex=index break end
			end
		end
		local PlayerBag=getObjectFromGUID(mageKnights[randomMKIndex].bag).clone({position={getObjectFromGUID(dummyBoard).getPosition()[1]-10.16, 5.15, getObjectFromGUID(dummyBoard).getPosition()[3]+12.14}})
		local skillBag=PlayerBag.takeObject({index=12})--Skill Container
		skillBag.lock()
		turnOrder[2].skillBagGUID=skillBag.guid--he doesn't get skills in more than solo
		skillBag.setPosition({getObjectFromGUID(dummyBoard).getPosition()[1]-5.62, 1.6, getObjectFromGUID(dummyBoard).getPosition()[3]+6.97})
		skillBag.shuffle()
		local skillRef=PlayerBag.takeObject({index=10})
		skillRef.lock()
		skillRef.setPosition({getObjectFromGUID(dummyBoard).getPosition()[1]-4.4, 1.05, -49})
		local skillRef=PlayerBag.takeObject({index=10})
		skillRef.lock()
		skillRef.setPosition({getObjectFromGUID(dummyBoard).getPosition()[1]-7.8, 1.05, -49})
		PlayerBag.destruct()
	end

	--Add Volkare unit crystals based on Player count and Race Level.
	--Each die face owns a physical Unit-offer slot; the broad offer zone replaces the old slot zones.
	gStates.volkareUnitCrystals={}
	if gStates.gameScenario~="The War of Four" then
		local VolkareUnits=gStates.playerCount+(gStates.volkareRaceLevel-1)
		local PlayerBag=getObjectFromGUID(GUID.bag.volkare).clone()
		local obj=PlayerBag.takeObject({position={37, 1.29, -1.14}, guid="1212f3"})--Crystal Container
		obj.shuffle()
		for i=1, VolkareUnits, 1 do
			local obj2=obj.takeObject()
			obj2.lock()
			obj2.setPosition({36.0-(4.8*(i-1)), 1.29, -1.15})
			obj2.setRotation({0, 30, 0})
			gStates.volkareUnitCrystals[obj2.getName()]={slot=i,crystalGUID=obj2.guid}
		end
		PlayerBag.destruct()
		obj.destruct()
	end

	--add unit tokens based on Volkare's Level
	gStates.volkareLevel=gStates.cityLevels[#gStates.cityLevels]
	table.remove(gStates.cityLevels, #gStates.cityLevels)
	safeWaitTime("SetupGame",function() volkareArmy() end, 5)--time for monster stacks to fill

	--Move reminder Tokens
	getObjectFromGUID(GUID.bag.volkare).takeObject({rotation={0.0, 180.0, 0.0}, position={getObjectFromGUID(cityScriptZones[volkare.discZone].cityCard).getPosition()[1]+2.2, 1.5, getObjectFromGUID(cityScriptZones[volkare.discZone].cityCard).getPosition()[3]+2.2}, guid=GUID.bag.volkareReminder})
end

--add unit tokens based on Volkare's Level
function volkareArmy()
	gStates.cityMonsterQty[volkare.model]={}
	if gStates.gameScenario~="Custom" then
		local VolkareArmy={	{},		  {},		{},		  {0,1,1,2},{1,0,1,2}, {1,0,1,3}, {1,0,2,2}, {1,1,2,2}, {1,1,2,3}, {1,1,2,5}, {2,0,2,5}, {2,0,2,6}, {2,0,2,7}, {2,0,3,6}, {2,1,3,6},
							{2,2,4,4},{2,2,4,5},{2,2,4,6},{2,2,4,8},{2,2,4,10},{3,1,4,10},{4,0,4,10},{4,0,4,11},{4,0,4,12},{4,0,4,13},{4,0,4,14},{4,0,5,13},{4,0,6,12},{4,1,6,12},{4,2,6,12}}
		--{no. White Units, No. Gray Units, No. Red Units, No. Green Units}(Level 4 to 15 shown, other levels made by adding levels togeather)
		local PugDraw={monsterPiles.white,monsterPiles.gray,monsterPiles.red,monsterPiles.green}
		--{White Unit Bag, Gray Unit Bag, Red Unit Bag, Green Unit Bag}
		if (gStates.volkareLevel<=20 and gStates.removeShadesOfTezlaMonsters==true and gStates.removeLostLegionExpansion==true) or (gStates.volkareLevel<=30 and (gStates.removeShadesOfTezlaMonsters~=true or gStates.removeLostLegionExpansion==false)) or (gStates.removeShadesOfTezlaMonsters~=true and gStates.removeLostLegionExpansion==false) then
			for i=1, 4, 1 do
				local LoopsNeeded=math.ceil(gStates.volkareLevel/30)
				local levelConverted=math.floor(gStates.volkareLevel/LoopsNeeded)
				local leftover=gStates.volkareLevel-(LoopsNeeded*levelConverted)+levelConverted
				getObjectFromGUID(PugDraw[i]).shuffle()
				for x=1, LoopsNeeded, 1 do
					if x==LoopsNeeded then levelConverted=leftover end
					for a=1, VolkareArmy[levelConverted][i], 1 do
						local params={position={0, 0, 0}, rotation={0, 180, 180}}
						params.position[1]=getObjectFromGUID(dummyBoard).getPosition()[1]+(0.2*a)+(2.2*x)+2.5
						params.position[2]=getObjectFromGUID(dummyBoard).getPosition()[2]+(0.2*a)+1
						params.position[3]=getObjectFromGUID(dummyBoard).getPosition()[3]+(0.2*a)+(2.2*i)-2.9
						local obj2=getObjectFromGUID(PugDraw[i]).takeObject(params)
						gStates.cityMonsterQty[volkare.model][obj2.guid]="alive"
						gStates.monsterPlayLocation[obj2.guid]={params.position[1], params.position[2], params.position[3]}
					end
				end
			end
		else
			broadcastToAll("{en}Volkare's Army is too large with your setup. You will need to create it when you fight him for the first time{ru}Армия Волкара слишком велика с вашей настройкой. Вам нужно будет создать ее, когда вы сразитесь с ним в первый раз{zh-tw}现在不用设置沃里卡的军队, 你将在首次和他交锋时设置这些{zh-cn}现在不用设置沃里卡的军队, 你将在首次和他交锋时设置这些{ko}볼케어의 군대 규모가 너무 큽니다. 플레이어가 직접 첫 전투 세팅을 준비해주세요.{es}El ejército de Volkare es demasiado grande con tu configuración. Necesitarás crearlo cuando luches contra él por primera vez.{fr}L'armée de Volkare est trop grande avec votre configuration. Vous devrez le créer lorsque vous le combattrez pour la première fois{pt-br}O exército de Volkare é muito grande com a sua configuração. Você precisará criá-lo quando você for lutar com ele pela primeira vez{de}Volkare's Armee ist mit deiner Aufstellung zu groß. Du musst sie erstellen, wenn du zum ersten Mal gegen ihn kämpfst.", warningColor)
		end
		--Change his models level
		getObjectFromGUID(volkare.model).setCustomObject({diffuse=cityLevelImage[volkare.model][math.floor(gStates.volkareLevel/math.ceil(gStates.volkareLevel/15))]})
		getObjectFromGUID(volkare.model).reload()
		safeWaitTime("SetupGame",function() getObjectFromGUID(volkare.model).lock() end, 3)
		cityLevelButtons(volkare.model, "Volkar")
	end
end

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
			safeTakeObject("SetupGame",apocalypseBag,{guid=GUID.deck.apocalypseQuest, position={46.84, 1.14, 8.06}, rotation={0, 180, 180}, smooth=true, callback_function=function(obj) safeWaitFrames("SetupGame",function() apocalypseQuestDeckSetup(obj) end, 2) end})
		end
	end

	--Ensure a village units is in the first draw for First Reconnaissance
	local villageUnits={"db04a7", "00ebf3", "506ea7", "c1f77c", "d55e5c", "b33811", "004558", "794e16", "484fa3", "a0a6cb", "e8acd7", "4339c4", "ff2a54", "246b0d", "bd1011"}
	if gStates.gameScenario=="First Reconnaissance" then
		local randAmount=15
		if gStates.removeLostLegionExpansion==true then randAmount=11 end
		local a=math.random(1, randAmount)
		getObjectFromGUID(GUID.deck.regularUnit).takeObject({guid=villageUnits[a], position={40.8, 2.0, -4.2}})
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

	--Remove City only units for scenarios without city access
	local cityUnits={"bb1660", "0fe22e", "5726ab", "f288ea", "f288e1", "5c2da0", "9c5c38"}
	if gStates.gameScenario=="The Lost Relic Blitz" or gStates.gameScenario=="The Chaos Rift" or gStates.gameScenario=="First Conquest" then
		for a=1, #cityUnits, 1 do
			if gStates.removeLostLegionExpansion==false or (gStates.removeLostLegionExpansion==true and a<=5) then
				getObjectFromGUID(GUID.deck.eliteUnit).takeObject({guid=cityUnits[a]}).destruct()
			end
		end
	end

	--remove cards replaced by Rise of the Forgemaster
	local cardsReplaced={["2eb8d9"]=1, ["2eb8d3"]=1, ["2eb8d0"]=3}--spells
	for card, level in pairs(cardsReplaced) do
		if gStates.riseOfTheForgemasters>=level and gStates.riseOfTheForgemasters~=0 then getObjectFromGUID(GUID.deck.spell).takeObject({guid=card}).destruct() end
	end
	local cardsReplaced={["085e56"]=1, ["085e59"]=1, ["085e65"]=1, ["085e50"]=1}--artifacts
	for card, level in pairs(cardsReplaced) do
		if gStates.riseOfTheForgemasters>=level and gStates.riseOfTheForgemasters~=0 then getObjectFromGUID(GUID.deck.artifact).takeObject({guid=card}).destruct() end
	end
	local cardsReplaced={["65a1d5"]=1, ["05ef61"]=1, ["474418"]=1, ["6fdeb0"]=1, ["878d85"]=1, ["878d93"]=1, ["878d90"]=1, ["35aee6"]=1,
 						 ["3d832c"]=1, ["1f362f"]=1, ["9de475"]=1, ["20cb85"]=1, ["d75285"]=2, ["141527"]=2, ["409fe8"]=2, ["1a1c02"]=2, ["8fac50"]=1}--advanced actions
	for card, level in pairs(cardsReplaced) do
 		if gStates.riseOfTheForgemasters>=level and gStates.riseOfTheForgemasters~=0 then getObjectFromGUID(GUID.deck.action).takeObject({guid=card}).destruct() end
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

--------------------------
-- Start at a Higher Level
--------------------------
--Move Higher Level Regular Unit selections from the main play area to an available command-token slot.
--The printed player board has six native Unit columns. Extra Command sources compress the same width instead of creating a hard seventh/eighth layout.
unitLayoutConfig={nativeSlots=6, firstOffset=-103.57, nativeSpacing=3.84, cardScale=1.5, associationRadius=2.05}
unitLayoutWait=unitLayoutWait or {}
unitLayoutExpanded=unitLayoutExpanded or {}

--Each native Unit slot has six attached player-board snap points:
--1 Banner, 2 Command (one also tagged Unit), and 3 Wound. When overflow compresses the
--Unit columns, rebuild only this snap family at the same dynamic X centres.
function unitLayoutSnapType(point)
	if point==nil then return nil end
	local banner=false
	local wound=false
	local command=false
	local unit=false
	for _,tag in ipairs(point.tags or {}) do
		if tag=="Banner" then banner=true
		elseif tag=="Wound" then wound=true
		elseif tag=="Command" then command=true
		elseif tag=="Unit" then unit=true end
	end
	if banner then return "banner" end
	if wound then return "wound" end
	if command and unit then return "unitCommand" end
	if command then return "command" end
	return nil
end

function refreshUnitLayoutSnapPoints(seatPos,commandCount)
	if seatPos==nil then return end
	local board=getObjectFromGUID(playerBoard[seatPos])
	if board==nil then return end
	local slotCount=math.max(unitLayoutConfig.nativeSlots,commandCount or 0)
	local snaps=board.getSnapPoints() or {}
	local kept={}
	local counts={banner=0,wound=0,unitCommand=0,command=0}
	for _,point in ipairs(snaps) do
		local snapType=unitLayoutSnapType(point)
		if snapType~=nil then counts[snapType]=counts[snapType]+1 else kept[#kept+1]=point end
	end

	--The stock board has 6/18/6/6 of these points. Dynamic versions preserve the same 1:3:1:1 ratio.
	--If a future board asset changes that family, leave it untouched rather than deleting unknown snaps.
	local currentSlots=counts.banner
	if currentSlots<1 or counts.wound~=currentSlots*3 or counts.unitCommand~=currentSlots or counts.command~=currentSlots then
		print("UNIT LAYOUT SNAP ERROR: Player "..tostring(seatPos).." board snap family was not recognised.")
		return
	end
	if currentSlots==slotCount then return end

	local boardPos=board.getPosition()
	for slot=1,slotCount do
		--positionToLocal automatically accounts for each board's 180 degree rotation and 8.2 scale.
		local localCenter=board.positionToLocal({unitLayoutX(seatPos,slot,slotCount),boardPos[2],boardPos[3]})
		local centerX=localCenter.x or localCenter[1]
		kept[#kept+1]={position={centerX,0,-0.155},tags={"Banner"}}
		kept[#kept+1]={position={centerX,0,-0.398},tags={"Unit","Command"}}
		kept[#kept+1]={position={centerX+0.070,0,-0.574},tags={"Wound"}}
		kept[#kept+1]={position={centerX,0,-0.574},tags={"Wound"}}
		kept[#kept+1]={position={centerX-0.070,0,-0.574},tags={"Wound"}}
		kept[#kept+1]={position={centerX,0,-0.830},tags={"Command"}}
	end
	board.setSnapPoints(kept)
end

function unitLayoutIsUnit(obj)
	if obj==nil then return false end
	local cardType=gameCardType(obj)
	return cardType=="Regular Unit" or cardType=="Elite Unit"
end

function unitLayoutIsCommand(obj)
	if obj==nil then return false end
	--Bonds of Loyalty is physically a Skill token, but while claimed in Norowas' Unit Area it provides
	--an extra Command slot exactly like Banner of Command. Its asset does not reliably carry the GM Note.
	return obj.getGMNotes()=="Command Token" or obj.getGMNotes()=="Bonds of Loyalty" or obj.guid=="f30dd4" or obj.guid=="8dbce4"
end

function unitLayoutCommandPriority(obj)
	if obj==nil then return 9 end
	if obj.getGMNotes()=="Command Token" then return 1 end
	if obj.getGMNotes()=="Bonds of Loyalty" or obj.guid=="f30dd4" then return 2 end
	if obj.guid=="8dbce4" then return 3 end
	return 9
end

function unitLayoutX(seatPos, slot, commandCount)
	local displayCount=math.max(unitLayoutConfig.nativeSlots, commandCount or unitLayoutConfig.nativeSlots)
	local width=unitLayoutConfig.nativeSpacing*(unitLayoutConfig.nativeSlots-1)
	local spacing=width/(displayCount-1)
	return (seatPos*40)+unitLayoutConfig.firstOffset+((slot-1)*spacing)
end

function unitLayoutCardScale(commandCount)
	if commandCount==nil or commandCount<=unitLayoutConfig.nativeSlots then return unitLayoutConfig.cardScale end
	return unitLayoutConfig.cardScale*((unitLayoutConfig.nativeSlots-1)/(commandCount-1))
end

--Only the Unit scripting zone defines Unit capacity; this preserves the Banner/Bonds behaviour the recruitment code already relied on.
function unitLayoutObjects(seatPos)
	local unitZone=getObjectFromGUID(playerUnitAreas[seatPos])
	if unitZone==nil then return {} end
	return unitZone.getObjects()
end

function unitLayoutSnapshot(seatPos)
	local objects=unitLayoutObjects(seatPos)
	local commands={}
	local units={}
	local unitByGuid={}
	for _, obj in pairs(objects) do
		if unitLayoutIsCommand(obj) then commands[#commands+1]=obj end
		if unitLayoutIsUnit(obj) then units[#units+1]=obj unitByGuid[obj.guid]=obj end
	end
	table.sort(commands, function(a,b)
		local ax=a.getPosition()[1]
		local bx=b.getPosition()[1]
		if math.abs(ax-bx)<0.05 then
			local ap=unitLayoutCommandPriority(a)
			local bp=unitLayoutCommandPriority(b)
			if ap==bp then return a.guid<b.guid end
			return ap<bp
		end
		return ax<bx
	end)
	table.sort(units, function(a,b)
		local ax=a.getPosition()[1]
		local bx=b.getPosition()[1]
		if math.abs(ax-bx)<0.05 then return a.guid<b.guid end
		return ax<bx
	end)

	local unitBySlot={}
	local unitSlotByGuid={}
	local usedCommand={}
	for _, unit in ipairs(units) do
		local unitX=unit.getPosition()[1]
		local bestSlot=nil
		local bestDistance=nil
		for slot, command in ipairs(commands) do
			if usedCommand[slot]~=true then
				local distance=math.abs(unitX-command.getPosition()[1])
				if bestDistance==nil or distance<bestDistance then bestDistance=distance bestSlot=slot end
			end
		end
		if bestSlot~=nil then
			usedCommand[bestSlot]=true
			unitBySlot[bestSlot]=unit
			unitSlotByGuid[unit.guid]=bestSlot
		end
	end

	local expanded=unitLayoutExpanded[seatPos]==true or #commands>unitLayoutConfig.nativeSlots
	if expanded==false and #commands<=unitLayoutConfig.nativeSlots then
		for _, unit in ipairs(units) do
			local scale=unit.getScale()
			local sx=scale.x or scale[1]
			if sx~=nil and sx<unitLayoutConfig.cardScale-0.02 then expanded=true break end
		end
	end
	local slotX={}
	for slot, command in ipairs(commands) do
		if #commands>unitLayoutConfig.nativeSlots or expanded==true then slotX[slot]=unitLayoutX(seatPos, slot, #commands)
		else slotX[slot]=command.getPosition()[1] end
	end
	return {objects=objects, commands=commands, units=units, unitByGuid=unitByGuid, unitBySlot=unitBySlot, unitSlotByGuid=unitSlotByGuid, slotX=slotX, expanded=expanded}
end

function unitLayoutFirstFreeCommand(seatPos)
	local layout=unitLayoutSnapshot(seatPos)
	if #layout.commands>unitLayoutConfig.nativeSlots then refreshUnitLayout(seatPos) end
	for slot, command in ipairs(layout.commands) do
		if layout.unitBySlot[slot]==nil then return slot, layout.slotX[slot], command, layout end
	end
	return nil, nil, nil, layout
end

--Before overflow, new Command sources fill an unused printed column. From the seventh onward they enter at the right edge and trigger a reflow.
function unitLayoutNextCommandX(seatPos)
	local layout=unitLayoutSnapshot(seatPos)
	local count=#layout.commands
	if count>=unitLayoutConfig.nativeSlots or layout.expanded==true then
		local newCount=count+1
		return unitLayoutX(seatPos, newCount, newCount), newCount
	end
	local used={}
	for _, command in ipairs(layout.commands) do
		local commandX=command.getPosition()[1]
		local bestSlot=1
		local bestDistance=math.abs(commandX-unitLayoutX(seatPos,1,unitLayoutConfig.nativeSlots))
		for slot=2, unitLayoutConfig.nativeSlots do
			local distance=math.abs(commandX-unitLayoutX(seatPos,slot,unitLayoutConfig.nativeSlots))
			if distance<bestDistance then bestDistance=distance bestSlot=slot end
		end
		used[bestSlot]=true
	end
	for slot=1, unitLayoutConfig.nativeSlots do
		if used[slot]~=true then return unitLayoutX(seatPos,slot,unitLayoutConfig.nativeSlots), count+1 end
	end
	return unitLayoutX(seatPos,count+1,count+1), count+1
end

function unitLayoutNearestUnit(objects, x)
	local nearest=nil
	local nearestDistance=nil
	for _, obj in pairs(objects or {}) do
		if unitLayoutIsUnit(obj) then
			local distance=math.abs(x-obj.getPosition()[1])
			if nearestDistance==nil or distance<nearestDistance then nearest=obj nearestDistance=distance end
		end
	end
	return nearest, nearestDistance
end

function unitLayoutIsCompanion(obj)
	if obj==nil or unitLayoutIsUnit(obj) or unitLayoutIsCommand(obj) then return false end
	if obj.getGMNotes()=="Unit Wound" or obj.type=="Dice" or obj.type=="Figurine" then return true end
	if skillTokens[obj.guid]~=nil or monsterPugs[obj.guid]~=nil then return true end
	if gameCards[obj.guid]~=nil and gameCards[obj.guid].full~=nil then return true end
	return false
end

function unitLayoutObjectInAnyUnitArea(guid)
	for seatPos=1,4 do
		local zone=getObjectFromGUID(playerUnitAreas[seatPos])
		if zone~=nil then for _, obj in pairs(zone.getObjects()) do if obj.guid==guid then return true end end end
	end
	return false
end

function refreshUnitLayout(seatPos)
	if seatPos==nil then return end
	local layout=unitLayoutSnapshot(seatPos)
	local commandCount=#layout.commands
	if commandCount<=unitLayoutConfig.nativeSlots and layout.expanded~=true then return end
	refreshUnitLayoutSnapPoints(seatPos,commandCount)
	local targetScale=unitLayoutCardScale(commandCount)
	local unitMoves={}

	for slot, command in ipairs(layout.commands) do
		local targetX=unitLayoutX(seatPos,slot,commandCount)
		local pos=command.getPosition()
		if math.abs(pos[1]-targetX)>0.02 and (command.held_by_color==nil or command.held_by_color=="") then command.setPositionSmooth({targetX,pos[2],pos[3]}) end
	end

	for _, unit in ipairs(layout.units) do
		local slot=layout.unitSlotByGuid[unit.guid]
		local scale=unit.getScale()
		local sx=scale.x or scale[1]
		local sz=scale.z or scale[3]
		if sx==nil or sz==nil or math.abs(sx-targetScale)>0.01 or math.abs(sz-targetScale)>0.01 then unit.setScale({targetScale,1,targetScale}) end
		if slot~=nil then
			local pos=unit.getPosition()
			local targetX=unitLayoutX(seatPos,slot,commandCount)
			unitMoves[#unitMoves+1]={oldX=pos[1], targetX=targetX}
			if math.abs(pos[1]-targetX)>0.02 and (unit.held_by_color==nil or unit.held_by_color=="") then unit.setPositionSmooth({targetX,pos[2],pos[3]}) end
		end
	end

	--Keep wounds, Mana, Unit reminders, combat tokens and attached Banner cards with the Unit column they were sitting on.
	for _, obj in pairs(layout.objects) do
		if unitLayoutIsCompanion(obj) then
			local pos=obj.getPosition()
			local bestMove=nil
			local bestDistance=nil
			for _, move in ipairs(unitMoves) do
				local distance=math.abs(pos[1]-move.oldX)
				if bestDistance==nil or distance<bestDistance then bestDistance=distance bestMove=move end
			end
			if bestMove~=nil and bestDistance<=unitLayoutConfig.associationRadius and (obj.held_by_color==nil or obj.held_by_color=="") then
				--Preserve the object's offset from its Unit (notably the three left/centre/right Wound snaps)
				--while moving the whole Unit column to its compressed position.
				local targetX=bestMove.targetX+(pos[1]-bestMove.oldX)
				if math.abs(pos[1]-targetX)>0.02 then obj.setPositionSmooth({targetX,pos[2],pos[3]}) end
			end
		end
	end
	unitLayoutExpanded[seatPos]=commandCount>unitLayoutConfig.nativeSlots
end

function scheduleUnitLayoutRefresh(seatPos)
	if seatPos==nil then return end
	if unitLayoutWait[seatPos]~=nil then Wait.stop(unitLayoutWait[seatPos]) end
	unitLayoutWait[seatPos]=safeWaitTime("SetupGame",function()
		unitLayoutWait[seatPos]=nil
		refreshUnitLayout(seatPos)
	end,0.2)
end

function unitLayoutObjectInUnitArea(guid,seatPos)
	local zone=seatPos~=nil and getObjectFromGUID(playerUnitAreas[seatPos]) or nil
	if zone~=nil then for _,obj in pairs(zone.getObjects()) do if obj.guid==guid then return true end end end
	return false
end

--Players routinely lift Command tokens to place them on Units. Do not temporarily re-expand the whole
--Unit layout while a permanent Command source is in their hand; only resize if it is actually dropped away.
function scheduleUnitLayoutRefreshAfterCommandRelease(seatPos,commandGUID)
	if seatPos==nil or commandGUID==nil then return end
	safeWaitCondition("SetupGame",function()
		safeWaitFrames("SetupGame",function()
			if unitLayoutObjectInUnitArea(commandGUID,seatPos)==false then scheduleUnitLayoutRefresh(seatPos) end
		end,2)
	end,function()
		local command=getObjectFromGUID(commandGUID)
		if command==nil then return true end
		local released=command.held_by_color==nil or command.held_by_color==""
		return released and command.resting==true
	end)
end

function higherLevelRelocateUnits(playerIndex)
	local playerData=turnOrder[playerIndex]
	if playerData==nil or playerData.poolCreated~=true or playerData.seatPos==nil then return end
	local playArea=getObjectFromGUID(playerPlayAreas[playerData.seatPos])
	if playArea==nil then return end
	local layout=unitLayoutSnapshot(playerData.seatPos)
	local alreadyInUnitArea=layout.unitByGuid
	for _, obj in pairs(playArea.getObjects()) do
		if obj.type=="Card" and gameCardType(obj)=="Regular Unit" and alreadyInUnitArea[obj.guid]~=nil then
			--The overlapping Play/Unit zones report cards already placed below; leave them alone.
		elseif obj.type=="Card" and gameCardType(obj)=="Regular Unit" then
			for slot, command in ipairs(layout.commands) do
				if layout.unitBySlot[slot]==nil then
					obj.setRotationSmooth({0,180,0})
					local scale=unitLayoutCardScale(#layout.commands)
					obj.setScale({scale,1,scale})
					obj.setPositionSmooth({layout.slotX[slot],2.0,-34.74})
					layout.unitBySlot[slot]=obj
					break
				end
			end
		end
	end
	scheduleUnitLayoutRefresh(playerData.seatPos)
end

--Create and Update Level Interface for Player count
local higherLevelUIPause=true
function mageLevelBoard()
	if higherLevelUIPause==true then safeWaitFrames("SetupGame",function()
		if gStates.magesSetup==true then
			--Create an interface for all players in the game
			for a=1, #turnOrder, 1 do
				if turnOrder[a].mage~=gStates.positionMageKnight[5] then
					if turnOrder[a].seatPos>0 then
						UI.setAttribute("Mage"..turnOrder[a].seatPos.."levelText", "Text", joinLang({"{en}Start at Level {ru}Начать с уровнем {zh-tw}起始等级：{zh-cn}起始等级：{ko}시작 레벨: {es}Empezar en el Nivel {fr}Début Niveau {pt-br}Iníciar no Nível {de}Starte auf Level ", turnOrder[a].level}))
						UI.setAttribute("Mage"..turnOrder[a].seatPos.."influenceText", "Text", joinLang({turnOrder[a].influence, "{en} Influence Per Level{ru} Влияние(я) за ур.{zh-tw}每级构筑点数{zh-cn}每级构筑点数{ko} 영향력*레벨{es} Influencia por Nivel{fr} Influence par Niveau{pt-br} Influência por Nível{de} Einfluss pro Stufe"}))
						UI.setAttribute("Mage"..turnOrder[a].seatPos.."influenceTotalText", "Text", joinLang({"{en}Influence to Spend : {ru}Доступно влияния: {zh-tw}影响力额度：{zh-cn}影响力额度：{ko}주어진 영향력: {es}Influencia para Gastar : {fr}Influence à Dépenser : {pt-br}Influência para Gastar : {de}Einfluss zum Ausgeben : ", (turnOrder[a].influence*turnOrder[a].level)+gStates.bondsOfLoyalty[a]}))
						UI.setAttribute("Mage"..turnOrder[a].seatPos.."AdvancedActionFreeText", "Text", joinLang({math.floor((turnOrder[a].level-1)/2), "{en} Free Advanced Action(s){ru} Бесплатное(ых) особое(ых) действие(ия/ий){zh-tw} 張免費的高級行動卡{zh-cn} 張免費的高級行動卡{ko}장의 무료 상급 액션{es} Acción Avanzada Gratuita{fr} Action Avancée Gratuite{pt-br} Cartas de Ação Avançadas Gratuitas{de} Freie Fortgeschrittene Aktion(en)"}))
						UI.setAttribute("Mage"..turnOrder[a].seatPos.."NameText", "Text", translateWord[turnOrder[a].mage])
						UI.setAttribute("Mage"..turnOrder[a].seatPos.."NamePanel", "Color", positionToColor(a))
						if gStates.showboards[a]==true then
							turnOrder[a].level=2
							if gStates.gameScenario=="Fast Forwarded Conquest" then turnOrder[a].level=6 end
							if gStates.gameScenario=="The Lost Relic Blitz" then turnOrder[a].level=3 end
							gStates.showboards[a]=false
							playArea=getObjectFromGUID(turnOrder[a].playerBoardGUID).getPosition()
							Player[positionToColor(a)].lookAt({position={playArea[1], playArea[2], playArea[3]+2}, pitch=65, yaw=0, distance=28})
							UI.setAttribute("Mage"..turnOrder[a].seatPos.."levelText", "Text", joinLang({"{en}Start at Level {ru}Начать с уровнем {zh-tw}起始等级：{zh-cn}起始等级：{ko}시작 레벨: {es}Empezar en el Nivel {fr}Début Niveau {pt-br}Iníciar no Nível {de}Starte auf Level ", turnOrder[a].level}))
							UI.setAttribute("Mage"..turnOrder[a].seatPos.."influenceTotalText", "Text", joinLang({"{en}Influence to Spend : {ru}Доступно влияния: {zh-tw}影响力额度：{zh-cn}影响力额度：{ko}주어진 영향력: {es}Influencia para Gastar : {fr}Influence à Dépenser : {pt-br}Influência para Gastar : {de}Einfluss zum Ausgeben : ", (turnOrder[a].influence*turnOrder[a].level)+gStates.bondsOfLoyalty[a]}))
							UI.show("Mage"..turnOrder[a].seatPos.."LevelBoard")
						end
						--Move any Regular Unit selection accidentally dropped in the main play area to its command-token slot.
						higherLevelRelocateUnits(a)
						--Zero the stats
						local badPlay=false
						local stats={"AdvancedActions", "Spells", "SpellCrystals", "Artifacts", "RegularUnits", "RegularUnitsWorth", "Crystals"}
						for b, c in pairs(stats) do
							turnOrder[a].levelingStats[c]=0
						end
						safeWaitFrames("SetupGame",function()
							--Count Everything in the player's play area
							local spellColors={}
							local crystalColors={}
							local countedUnits={}--Play and Unit zones can overlap; only value each selected Unit once.
							for b, c in pairs(getObjectFromGUID(playerPlayAreas[turnOrder[a].seatPos]).getObjects()) do
								if c.type=="Card" then
									if c.getGMNotes()=="Advanced Action" then turnOrder[a].levelingStats.AdvancedActions=turnOrder[a].levelingStats.AdvancedActions+1 end
									if gameCardType(c)=="Regular Unit" and countedUnits[c.guid]==nil then
										countedUnits[c.guid]=true
										turnOrder[a].levelingStats.RegularUnits=turnOrder[a].levelingStats.RegularUnits+1
										turnOrder[a].levelingStats.RegularUnitsWorth=turnOrder[a].levelingStats.RegularUnitsWorth-gameCards[c.guid].influence
									end
									if c.getGMNotes()=="Spell" then
										turnOrder[a].levelingStats.Spells=turnOrder[a].levelingStats.Spells+1
										spellColors[#spellColors+1]=c.getDescription()
									end
									if c.getGMNotes()=="Artifact" then turnOrder[a].levelingStats.Artifacts=turnOrder[a].levelingStats.Artifacts+1 end
								end
								if c.type=="Figurine" then
									if gStates.startingHigherLevelCrystal[c.guid]~=nil then
										turnOrder[a].levelingStats.SpellCrystals=turnOrder[a].levelingStats.SpellCrystals+1
										crystalColors[#crystalColors+1]=c.getDescription()
									end
								end
							end
							--Count Everything in the player's Unit area
							for b, c in pairs(getObjectFromGUID(playerUnitAreas[turnOrder[a].seatPos]).getObjects()) do
								if c.type=="Card" then
									if gameCardType(c)=="Regular Unit" and countedUnits[c.guid]==nil then
										countedUnits[c.guid]=true
										turnOrder[a].levelingStats.RegularUnits=turnOrder[a].levelingStats.RegularUnits+1
										turnOrder[a].levelingStats.RegularUnitsWorth=turnOrder[a].levelingStats.RegularUnitsWorth-gameCards[c.guid].influence
									end
								end
							end
							local commandCount=#unitLayoutSnapshot(turnOrder[a].seatPos).commands
							if turnOrder[a].levelingStats.RegularUnits>commandCount then badPlay=true end
							gStates.higherLevelUnitWarning=gStates.higherLevelUnitWarning or {}
							if turnOrder[a].poolCreated==true and turnOrder[a].levelingStats.RegularUnits>commandCount then
								if gStates.higherLevelUnitWarning[a]~=true then
									broadcastToAll(joinLang({"{en}Warning: {ru}Внимание: {zh-tw}警告：{zh-cn}警告：{ko}경고: {es}Advertencia: {fr}Attention : {pt-br}Aviso: {de}Warnung: ", translateWord[turnOrder[a].mage], "{en} has selected more Units than available Command tokens. One or more Units cannot be placed.{ru} выбрал(а) больше отрядов, чем доступно жетонов командования. Один или несколько отрядов нельзя разместить.{zh-tw}选择的部队数量超过了可用的指挥标记数量。一个或多个部队无法放置。{zh-cn}选择的部队数量超过了可用的指挥标记数量。一个或多个部队无法放置。{ko}이 사용 가능한 지휘 토큰보다 많은 유닛을 선택했습니다. 하나 이상의 유닛을 배치할 수 없습니다.{es} ha seleccionado más Unidades que fichas de Mando disponibles. Una o más Unidades no pueden colocarse.{fr} a sélectionné plus d'Unités que de jetons de Commandement disponibles. Une ou plusieurs Unités ne peuvent pas être placées.{pt-br} selecionou mais Unidades do que Fichas de Comando disponíveis. Uma ou mais Unidades não podem ser colocadas.{de} hat mehr Einheiten als verfügbare Befehlsplättchen gewählt. Eine oder mehrere Einheiten können nicht platziert werden."}), positionToColor(a))
								end
								gStates.higherLevelUnitWarning[a]=true
							else
								gStates.higherLevelUnitWarning[a]=nil
							end
							--Count Everything in the player's Inventory area
							for b, c in pairs(getObjectFromGUID(playerCrystalAreas[turnOrder[a].seatPos]).getObjects()) do
								if c.type=="Figurine" then
									if gStates.startingHigherLevelCrystal[c.guid]==nil then
										turnOrder[a].levelingStats.Crystals=turnOrder[a].levelingStats.Crystals+1
									end
								end
							end
							--score Advanced Actions in the play area
							turnOrder[a].levelingStats.AdvancedActionsWorth=(turnOrder[a].levelingStats.AdvancedActions-math.floor((turnOrder[a].level-1)/2))*-6
							if turnOrder[a].levelingStats.AdvancedActionsWorth>0 then turnOrder[a].levelingStats.AdvancedActionsWorth=0 end
							--score Artifacts in the play area
							turnOrder[a].levelingStats.ArtifactsWorth=turnOrder[a].levelingStats.Artifacts*-12
							--score Crystals in the play area
							turnOrder[a].levelingStats.CrystalsWorth=turnOrder[a].levelingStats.Crystals*-3
							--score Spells in the play area .getDescription()
							turnOrder[a].levelingStats.SpellsWorth=(turnOrder[a].levelingStats.Spells*-9)
							local count=0
							for b, c in pairs(crystalColors) do
								for d, e in pairs(spellColors) do
									if c==e then turnOrder[a].levelingStats.SpellsWorth=turnOrder[a].levelingStats.SpellsWorth+2 count=count+1 break end
								end
							end
							if #crystalColors~=count then badPlay=true end
							--update UI
							local influence=turnOrder[a].level*turnOrder[a].influence+gStates.bondsOfLoyalty[a]
							if turnOrder[a].level==1 then influence=0 end
							local remain=influence+turnOrder[a].levelingStats.AdvancedActionsWorth+turnOrder[a].levelingStats.RegularUnitsWorth+turnOrder[a].levelingStats.SpellsWorth+turnOrder[a].levelingStats.ArtifactsWorth+turnOrder[a].levelingStats.CrystalsWorth
							if remain~=turnOrder[a].remain then
								UI.setAttribute("Mage"..turnOrder[a].seatPos.."AdvancedActionCostText", "Text", joinLang({turnOrder[a].levelingStats.AdvancedActions, "{en} Advanced Action(s) : {ru} Особое(ых) действие(ия/ий): {zh-tw} 張高級行動卡：{zh-cn} 張高級行動卡：{ko}장의 상급 액션 : {es} Acción Avanzada : {fr} Action Avancée : {pt-br} Ações Avançadas : {de} Fortgeschrittene Aktion(en) : ", turnOrder[a].levelingStats.AdvancedActionsWorth}))
								UI.setAttribute("Mage"..turnOrder[a].seatPos.."RegularUnitCostText", "Text", joinLang({turnOrder[a].levelingStats.RegularUnits, "{en} Regular Unit(s) : {ru} Обычный(ых) отряд(а/ов): {zh-tw} 支常规部队：{zh-cn} 支常规部队：{ko}개의 일반 유닛 : {es} Unidad(es) Regulares : {fr} Unité(s) Régulières : {pt-br} Unidade(s) Regulares : {de} Normale Einheit(en) : ", turnOrder[a].levelingStats.RegularUnitsWorth}))
								UI.setAttribute("Mage"..turnOrder[a].seatPos.."SpellCostText", "Text", joinLang({turnOrder[a].levelingStats.Spells, "{en} Spell(s) : {ru} Заклинание(я/ий): {zh-tw} 張法術卡：{zh-cn} 張法術卡：{ko}장의 마법 : {es} Hechizo(s) : {fr} Sort(s) : {pt-br} Feitiços : {de} Zauber : ", turnOrder[a].levelingStats.SpellsWorth}))
								UI.setAttribute("Mage"..turnOrder[a].seatPos.."ArtifactCostText", "Text", joinLang({turnOrder[a].levelingStats.Artifacts, "{en} Artifact(s) : {ru} Артефакт(а/ов): {zh-tw} 張神器卡：{zh-cn} 張神器卡：{ko}장의 유물 : {es} Artefacto(s) : {fr} Artefact(s) : {pt-br} Artefatos : {de} Artefakt(e) : ", turnOrder[a].levelingStats.ArtifactsWorth}))
								UI.setAttribute("Mage"..turnOrder[a].seatPos.."CrystalCostText", "Text", joinLang({turnOrder[a].levelingStats.Crystals, "{en} Mana Crystal(s) : {ru} Кристалл(а/ов) маны: {zh-tw} 顆魔晶：{zh-cn} 顆魔晶：{ko}개의 수정 : {es} Cristales de Maná : {fr} Cristaux de Mana : {pt-br} Cristais de Mana : {de} Manakristall(e) : ", turnOrder[a].levelingStats.CrystalsWorth}))
								UI.setAttribute("Mage"..turnOrder[a].seatPos.."RemainingText", "Text", joinLang({"{en}Remaining : {ru}Остаток: {zh-tw}剩餘：{zh-cn}剩餘：{ko}남은 영향력 : {es}Restante : {fr}Restant : {pt-br}Restando : {de}Verbleibend : ", remain}))
								turnOrder[a].remain=remain
								turnOrder[a].levelUpComplete=false
								if remain>=0 and badPlay==false then
									UI.setAttribute("Mage"..turnOrder[a].seatPos.."RemainingText", "Color", "Black")
									UI.setAttribute("Mage"..turnOrder[a].seatPos.."CompleteButton", "interactable", "true")
									UI.setAttribute("Mage"..turnOrder[a].seatPos.."CompleteButtonImage", "image", "Sliced Button/Button New Active")
								else
									if remain<0 then UI.setAttribute("Mage"..turnOrder[a].seatPos.."RemainingText", "Color", "Red") end
									UI.setAttribute("Mage"..turnOrder[a].seatPos.."CompleteButton", "interactable", "false")
									UI.setAttribute("Mage"..turnOrder[a].seatPos.."CompleteButtonImage", "image", "Sliced Button/Button New Deactive")
								end
							end
						end, 5)
					end
				else
					if a==1 then gStates.turnNumber=2 end
				end
			end
		end
		higherLevelUIPause=true
	end, 5)	end
	higherLevelUIPause=false
end

--Change level and Infuence for Player(s)
function mageKnightLevel(player, mouseButton, id)
	if mouseButton=="-1" then
		--check if player was alowed to click those buttons
		local playerPosition=id:sub(5,5)
		if legalPlayerCheck(player.color, tonumber(playerPosition))==true then
			for a, b in pairs(turnOrder) do
				if tostring(b.seatPos)==playerPosition then
					local c=11
					if id:sub(6, 12)~="levelUp" and id:sub(6, 14)~="levelDown" then c=15 end
					if id:sub(c, c+1)=="Up" then
						local levelSum=0
						for c, d in pairs(turnOrder) do
							if d.mage~=gStates.positionMageKnight[5] then levelSum=levelSum+d.level end
						end
						if 	(id:sub(6, 12)~="levelUp" and b[id:sub(6, c-1)]<10) or
							(((levelSum<20 and gStates.coop==1 and gStates.WarOfFourComp~=true) or (levelSum<24 and (gStates.coop==0 or gStates.WarOfFourComp==true))) and b[id:sub(6, c-1)]<10) then
							b[id:sub(6, c-1)]=b[id:sub(6, c-1)]+1
						end
					else
						if b[id:sub(6, c-1)]>1 then b[id:sub(6, c-1)]=b[id:sub(6, c-1)]-1 end
					end
					mageLevelBoard()
					break
				end
			end
		end
	end
end

--Create Start at Higher level Card Pool for Player
function cardPool(player, mouseButton, id)
	if mouseButton=="-1" then
		local playerPosition=id:sub(5,5)
		if legalPlayerCheck(player.color, tonumber(playerPosition))==true then
			--lock clicking players "Create Card Pool" button
			UI.setAttribute("Mage"..playerPosition.."CompleteButton", "onClick", "startHigherLevel")
			UI.setAttribute("Mage"..playerPosition.."CompleteText", "text", "{en}Complete{ru}Завершить{zh-tw}完成{zh-cn}完成{ko}완료{es}Completo{fr}Compléter{pt-br}Completo{de}Fertig")
			UI.setAttribute("Mage"..playerPosition.."CompleteButton", "interactable", "true")
			UI.setAttribute("Mage"..playerPosition.."CompleteButtonImage", "image", "Sliced Button/Button New Active")
			--lock clicking players "+" & "-" Level buttons
			UI.setAttribute("Mage"..playerPosition.."levelDown", "interactable", "false")
			UI.setAttribute("Mage"..playerPosition.."levelUp", "interactable", "false")
			--find the turnOrder List that matches the position
			for _, mageDetails in pairs(turnOrder) do
				if tostring(mageDetails.seatPos)==playerPosition then
					--Create Card Pool
					mageDetails.poolCreated=true
					local poolDraw={[GUID.deck.action]={ 2, 100},--Advanced Actions
					 				[GUID.deck.regularUnit]={ 1, 96 },--Regular Units
									[GUID.deck.spell]={ 0, 92 },--Spells
									[GUID.deck.artifact]={-1, 88 }}--Artifacts
					for deck, numbers in pairs(poolDraw) do
						for _=1, mageDetails.level+numbers[1], 1 do
							getObjectFromGUID(deck).takeObject({position={(mageDetails.seatPos*40)-numbers[2], 3.0, -48.4}, smooth=false, rotation={0, 180, 0}})
						end
					end
					--Give Starting Crystals to player(s)
					if mageDetails.level>1 then
						for c, d in pairs(mageKnights) do
							if d.mage==mageDetails.mage then
								for e=1, 2, 1 do
									local container={["Red"]=GUID.bag.mana.red, ["Blue"]=GUID.bag.mana.blue, ["Green"]=GUID.bag.mana.green, ["White"]=GUID.bag.mana.white}
									local obj=takeManaCrystal(getObjectFromGUID(container[d.crystals[e]]),{position={(mageDetails.seatPos*40)-116.53+(1.76*e), 2.00, -36.80},smooth=false})
									--obj.setVar("state", "Starting")
									if obj~=nil then gStates.startingHigherLevelCrystal[obj.guid]=true end
								end
								break
							end
						end
					end
					--Hero Challenges replace the level-2 pair with the reserved Skill. Higher even levels still flip two of this Hero's own Skills.
					--Keep the consumed level-2 row physically reserved too: the optional level-4+ pairs belong one row below it.
					local skillRows=math.floor(mageDetails.level/2)
					local skillRowOffset=0
					if gStates.heroChallenges==true and mageDetails.level>=2 and heroChallengesData[mageDetails.mage]~=nil then
						for playerIndex,details in pairs(turnOrder) do if details==mageDetails then heroChallengeClaimReservedSkill(playerIndex,true) break end end
						skillRows=math.max(0,skillRows-1)
						skillRowOffset=1
					end
					--draw two skills for each remaining even level
					local obj=nil
					for c=1, skillRows, 1 do
						for d=1, 2, 1 do
							local pos={(mageDetails.seatPos*40)-108.5+(d*3.65), 2.0, -37.19-((c+skillRowOffset)*1.48)}
							obj=getObjectFromGUID(mageDetails.skillBagGUID).takeObject({position=pos, smooth=true, rotation={0, 180, 0}})
							gStates.mageSkills[obj.guid]=pos
						end
					end
					--Add claim buttons
					safeWaitFrames("SetupGame",function() safeWaitCondition("SetupGame",function()
						higherLevelSkillClaimButons()
					end, function() return obj==nil or obj.resting end) end, 5)
					--Deploy Command Token(s). Slot 1 is the printed starting token already on the board.
					local setupCommandCount=1+math.floor((mageDetails.level-1)/2)
					for c=1, setupCommandCount-1 do
						getObjectFromGUID(mageDetails.commandGUID).takeObject({position={unitLayoutX(mageDetails.seatPos,c+1,setupCommandCount),2.00,-31.2}, rotation={0,180,180}})
					end
					scheduleUnitLayoutRefresh(mageDetails.seatPos)
					break
				end
			end
		end
	end
end

--activate skill buttons for non claimed skills.
function higherLevelSkillClaimButons()
	for skillGUID, skillDetails in pairs(skillTokens) do
		if getObjectFromGUID(skillGUID)~=nil and getObjectFromGUID(skillGUID).UI.getXml()=="" then
			local objPos=getObjectFromGUID(skillGUID).getPosition()
			if 	not (objPos[3]>-25 or
				(objPos[3]<-35 and objPos[1]>-68 and objPos[1]<-66) or
				(objPos[3]<-35 and objPos[1]>-28 and objPos[1]<-26) or
				(objPos[3]<-35 and objPos[1]>12 and objPos[1]<14) or
				(objPos[3]<-35 and objPos[1]>52 and objPos[1]<54)) then
				getObjectFromGUID(skillGUID).UI.setXmlTable({createClaimButton(skillGUID, "higherLevelSkill")})
			end
		end
	end
end

function higherLevelSkillAreaPlayer(position)
	if position==nil or position[3]>=-35 then return nil end
	for playerPosition=1, 4, 1 do
		local skillAreaX=(playerPosition*40)-107
		if position[1]>skillAreaX-1 and position[1]<skillAreaX+1 then return playerPosition end
	end
	return nil
end

--Claim and store skills. pairPosition is supplied when the player drags a choice into their skill area,
--so the original row can still identify the other offered skill even if the chosen token was moved vertically.
function higherLevelSkill(player, mouseButton, id, pairPosition)
	if mouseButton=="-1" then
		local selectedSkill=getObjectFromGUID(id:sub(1,6))
		if selectedSkill==nil then return end
		local playerPosition=(math.ceil((selectedSkill.getPosition()[1]+95)/40))
		local pairZ=pairPosition~=nil and pairPosition[3] or selectedSkill.getPosition()[3]
		if legalPlayerCheck(player.color, tonumber(playerPosition))==true then
			--Bonds of Loyalty goes to unit area
			if id:sub(1,6)=="f30dd4" then
				local bondsX=unitLayoutNextCommandX(playerPosition)
				gStates.mageSkills[id:sub(1,6)]={bondsX,1.1,-31.19}
				selectedSkill.setPositionSmooth({bondsX,1.1,-31.19})
				scheduleUnitLayoutRefresh(playerPosition)
				--Place Unit Cards
				local unitDeck=getObjectFromGUID(GUID.zone.regularUnit).getObjects()[1]
				for a=1, 2, 1 do
					standardDeckCycleShuffleIfReached("Regular Unit", unitDeck)
					unitDeck=getObjectFromGUID(GUID.zone.regularUnit).getObjects()[1]
					unitDeck.takeObject({position={(playerPosition*40)-101, 3.0, -48.4}, smooth=true, rotation={0, 180, 0}})
				end
				for a=1, #turnOrder, 1 do
					if turnOrder[a].seatPos==playerPosition then
						gStates.bondsOfLoyalty[a]=5
						UI.setAttribute("Mage"..playerPosition.."influenceTotalText", "Text", joinLang({"{en}Influence to Spend : {ru}Доступно влияния: {zh-tw}影响力额度：{zh-cn}影响力额度：{ko}주어진 영향력: {es}Influencia para Gastar : {fr}Influence à Dépenser : {pt-br}Influência para Gastar : {de}Einfluss zum Ausgeben : ", (turnOrder[a].influence*turnOrder[a].level)+gStates.bondsOfLoyalty[a]}))
						break
					end
				end
				broadcastToAll("{en}Two more Regular units and 5 influence given to Norowas.{ru}Два дополнительных обычных отряда и 5 влияния даны Норовас{zh-tw}给诺罗瓦斯增加两个常规部队供应和5影响力{zh-cn}给诺罗瓦斯增加两个常规部队供应和5影响力{ko}노로워즈에게 일반 유닛 두 개와 영향력 5가 추가 지급되었습니다. {es}Dos unidades regulares más y 5 influencia dadas a Norowas.{fr}Deux autres unités régulières et 5 d'influence donnés à Norowas.{pt-br}2 unidades Regulares a mais e 5 influência dadas a Norowas{de}Zwei weitere reguläre Einheiten und 5 Einfluss an Norowas gegeben.", {1,1,0.5})
			end
			--Master of Chaos
			if id:sub(1,6)=="1ff34f" then
				masterOfChaosSetup(playerPosition)
			end
			--move claimed skill to skill column. Bonds of Loyalty already moved to/recorded in the Unit Area above.
			selectedSkill.unlock()
			if id:sub(1,6)~="f30dd4" then
				local skillHome={(playerPosition*40)-107.45, 1.5, selectedSkill.getPosition()[3]}
				selectedSkill.setPositionSmooth(skillHome)
				gStates.mageSkills[id:sub(1,6)]=skillHome
			end
			selectedSkill.UI.setXmlTable({{}})
			if gStates.motivationSkill[id:sub(1,6)]~=nil then
				gStates.motivationSkill[id:sub(1,6)].state="active"
				gStates.motivationSkill[id:sub(1,6)].pos=playerPosition
			end
			--find other Skill
			for skillGUID, skillDetails in pairs(skillTokens) do
				if getObjectFromGUID(skillGUID)~=nil then
					local otherSkill=getObjectFromGUID(skillGUID)
					local otherPosition=(math.ceil((otherSkill.getPosition()[1]+95)/40))
					if otherPosition==playerPosition and skillGUID~=id:sub(1,6) and otherSkill.getPosition()[3]>pairZ-1 and otherSkill.getPosition()[3]<pairZ+1 then
						--move other skill to communal area
						local exist=0
						for skillGUID, skillPos in pairs(gStates.mageSkills) do
							if math.floor(skillPos[1])==math.floor((playerPosition*3.7)+7.3) and skillPos[3]>-25 then exist=exist+1 end
						end
						local pos={(playerPosition*3.7)+7.3, 2.00, -23.95+(exist*1.35)}
						otherSkill.unlock()
						otherSkill.setPositionSmooth(pos)
						otherSkill.UI.setXmlTable({{}})
						gStates.mageSkills[skillGUID]=pos
						break
					end
				end
			end
		end
	end
end

--run after all complete's on the start at higher level panel(s) are clicked
function startHigherLevel(player, mouseButton, id)
	if mouseButton=="-1" then
		local playerPosition=id:sub(5,5)
		if legalPlayerCheck(player.color, tonumber(playerPosition))==true then
			--lock clicking players "Complete" button
			UI.setAttribute("Mage"..playerPosition.."CompleteButton", "interactable", "false")
			UI.setAttribute("Mage"..playerPosition.."CompleteButtonImage", "image", "Sliced Button/Button New Deactive")
			--lock clicking players "+" & "-" Influence buttons
			UI.setAttribute("Mage"..playerPosition.."influenceDown", "interactable", "false")
			UI.setAttribute("Mage"..playerPosition.."influenceUp", "interactable", "false")
			local shieldNumber={}
			local startFame={}
			for a=0, 145, 1 do shieldNumber[a]=1 end
			for a=0, 145, 1 do startFame[a]={} end
			--Check if every player is complete
			local finalComplete=true
			for _, b in pairs(turnOrder) do
				if b.seatPos==tonumber(playerPosition) then
					b.levelUpComplete=true
				else
					if b.levelUpComplete~=true and b.mage~=gStates.positionMageKnight[5] then finalComplete=false end
				end
			end
			if finalComplete==true then
				--build a list of fame tokens and where they start
				for a, b in pairs(turnOrder) do
					if turnOrder[a].mage~=gStates.positionMageKnight[5] then
						local fame=gStates.blitz  +  math.ceil(b.remain/150)  +  ((b.level-1)*3)  +  (((b.level-1)*2)/2)
						startFame[fame][#startFame[fame]+1]=true
					end
				end
				--Loop through all playing player positions
				for a=1, #turnOrder, 1 do
					--Make sure it's not the dummy
					if turnOrder[a].mage~=gStates.positionMageKnight[5] then
						--Hide Interface
						UI.hide("Mage"..turnOrder[a].seatPos.."LevelBoard")
						--Return unbought cards
						local deckReturn={["Advanced Action"]=GUID.deck.action, ["Regular Unit"]=GUID.deck.regularUnit, ["Spell"]=GUID.deck.spell, ["Artifact"]=GUID.deck.artifact}
						for b, c in pairs(getObjectFromGUID(handZones[turnOrder[a].seatPos]).getObjects()) do
							if c.type=="Card" then
								getObjectFromGUID(deckReturn[gameCardType(c)]).putObject(c)
							end
						end
						for _, deckGUID in pairs(deckReturn) do getObjectFromGUID(deckGUID).shuffle() end
						--loop through all card in play area
						local deedDeck=nil
						for _, possibleDeck in pairs(getObjectFromGUID(deedDeckZones[turnOrder[a].seatPos]).getObjects()) do
							if possibleDeck.type=="Deck" then deedDeck=possibleDeck break end
						end
						for _, playAreaObj in pairs(getObjectFromGUID(playerPlayAreas[turnOrder[a].seatPos]).getObjects()) do
							if playAreaObj.type=="Card" and (playAreaObj.getGMNotes()=="Advanced Action" or playAreaObj.getGMNotes()=="Spell" or playAreaObj.getGMNotes()=="Artifact") and deedDeck~=nil then
								deedDeck.putObject(playAreaObj)
							end
							--delete any spent Crystals
							if playAreaObj.type=="Figurine" then playAreaObj.destruct() end
						end
						if deedDeck~=nil then deedDeck.shuffle() end
						--Hand Size Increase
						if turnOrder[a].level>4 then
							turnOrder[a].baseHand=turnOrder[a].baseHand+1
							turnOrder[a].hand=turnOrder[a].hand+1
						end
						if turnOrder[a].level>8 then
							turnOrder[a].baseHand=turnOrder[a].baseHand+1
							turnOrder[a].hand=turnOrder[a].hand+1
						end
						--place Fame Token (add 1 fame for any remaining influence)
						local startPosition=1+gStates.blitz+math.ceil(turnOrder[a].remain/150)
						local levelRowFameQuantity=(((turnOrder[a].level-1)*cellGainPerLevel)+normalCellAmount)
						local levelRowLength=((turnOrder[a].level-1)*gStates.rowLengthGainPerLevel)+gStates.normalRowLength
						local fame=startPosition  +  ((turnOrder[a].level-1)*3)  +  (((turnOrder[a].level-1)*2)/2) -  1
						local xOffset=(((1/levelRowFameQuantity*levelRowLength)   /   (#startFame[fame]+1)))   *   (shieldNumber[fame])
						local yOffset=(((heightOfFameBoard/gStates.rowsOnBoard)/(#startFame[fame]+1)))*(shieldNumber[fame])
						local horizontalValue=leftOfFameBoard+(startPosition/levelRowFameQuantity*levelRowLength)-xOffset
						local verticalValue=(topOfFameBoard-((turnOrder[a].level/gStates.rowsOnBoard)*heightOfFameBoard))+yOffset-0.25
						getObjectFromGUID(turnOrder[a].fameGUID).setPosition({horizontalValue, 1.5, verticalValue})
						shieldNumber[fame]=shieldNumber[fame]+1
						turnOrder[a].fame=fame
					end
				end
				--remove wond card deck holders
				local woundCards={[GUID.deck.spell]={"5c38e4", "ab778d"}, [GUID.deck.regularUnit]={"b5048c", "718f39"}}
				for deck, wounds in pairs(woundCards) do
					for a=1, 2, 1 do
						local objToDel=getObjectFromGUID(deck).takeObject({guid=wounds[a], position={40.8, 8.0, -10.2}})
						objToDel.destruct()
					end
				end
				--Return to regular setup
				UI.hide("LevelUpRules")
				safeWaitTime("SetupGame",afterLoad, 0.1)
			end
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
		for _,guid in ipairs({GUID.tile.country12,GUID.tile.country13,GUID.tile.country14}) do sendTerrainTileToTrash(countryBag,guid) end
		for _,guid in ipairs({GUID.tile.core09,GUID.tile.core10}) do sendTerrainTileToTrash(coreBag,guid) end
	end
	if gStates.removeApocalypseTerrain==true then
		for _,guid in ipairs({GUID.tile.country15,GUID.tile.country16,GUID.tile.country17}) do sendTerrainTileToTrash(countryBag,guid) end
		for _,guid in ipairs({GUID.tile.core11,GUID.tile.core12}) do sendTerrainTileToTrash(coreBag,guid) end
	end
	--Against the Horsemen requires Countryside 1 as its centre even if stale saved/random state says otherwise.
	if gStates.removeTerrain==true and gStates.gameScenario~="Against the Horsemen Blitz" then
		for _,guid in ipairs({GUID.tile.country01,GUID.tile.country02}) do sendTerrainTileToTrash(countryBag,guid) end
	end
	--When Volkare is the automated opponent, their scenario setup has already pulled this same tile from the City bag.
	if gStates.positionMageKnight[5]~="Volkare" and setupUsesVolkareCampCity()~=true then sendTerrainTileToTrash(cityBag,"835c91") end
end

--destroy all the setup bags
function afterLoad()
	removeUnselectedTerrain()
	--Deploy the scenario map from the already-filtered terrain bags.
	mapSetup()
	if apocalypseDragonScenario()==true then safeWaitTime("SetupGame",function() positionApocalypseDragonHeads() end,2) end
	safeWaitTime("SetupGame",function()
		if gStates.startAtNight==true then gStates.dayRound=true end
		dayNight()--dayNight need to be after map setup to change the tile tint
		gStates.firstStarted=true
		gStates.turnNumber=1
		refreshAllPlayerFameReputationFromShields()
		refreshMageSkillLocations()
		tacticToggle()
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
	end, 0.7)
end

--Layout starting map tiles
firstTile=nil
startingMapSetup=false
startingMapTiles={}
-- Apocalypse Dragon Hero Challenges play variant.
-- The variant overlays the selected scenario; the scenario's own end condition remains authoritative.
function heroChallengeCountryGUID(number)
	return GUID.tile["country"..tostring(number)]
end

function heroChallengeCountryAvailable(guid)
	if guid==nil then return false end
	if gStates.removeTerrain==true and (guid==GUID.tile.country01 or guid==GUID.tile.country02) then return false end
	if gStates.removeLostLegionExpansion==true and (guid==GUID.tile.country12 or guid==GUID.tile.country13 or guid==GUID.tile.country14) then return false end
	if gStates.removeApocalypseTerrain==true and (guid==GUID.tile.country15 or guid==GUID.tile.country16 or guid==GUID.tile.country17) then return false end
	return terrainTiles[guid]~=nil and terrainTiles[guid].tileType=="country"
end

function heroChallengeCountryIn(guid, numbers)
	for _, number in ipairs(numbers or {}) do if guid==heroChallengeCountryGUID(number) then return true end end
	return false
end

function heroChallengeCountryHasVillage(guid)
	local data=terrainTiles[guid]
	if data==nil or data.hexFeature==nil then return false end
	for _, feature in pairs(data.hexFeature) do if feature=="village" then return true end end
	return false
end

--Mirror the scenario-specific Countryside pools used by mapSetup(). This lets setup legality be tested
--before Start is pressed and lets Hero Challenges safely combine the requirements of several Heroes.
function heroChallengeCountrySlotAllows(guid, slot)
	if heroChallengeCountryAvailable(guid)~=true then return false end
	local scenario=gStates.gameScenario
	local countryCount=scenarioList[gStates.scenarioRef][gStates.playersRef].countryTiles
	if scenario=="First Reconnaissance" then
		local order={"03","04","05","06","07","08","09","10","11","02","01"}
		local index=slot
		if slot>=countryCount-1 then index=slot+(11-countryCount) end
		return guid==heroChallengeCountryGUID(order[index])
	end
	if scenario=="Mines Liberation" then
		if slot<=4 then return heroChallengeCountryIn(guid,{"02","03","05","06","13","14","15","17"}) end
		return heroChallengeCountryIn(guid,{"01","04","07","08","09","10","11","12","16"})
	end
	if scenario=="Conquer and Hold" then return heroChallengeCountryIn(guid,{"03","04","09","10","11","13","14","15","17"}) end
	if scenario=="The Gauntlet" then return heroChallengeCountryIn(guid,{"01","02","03","04","05","06","07","08","09","10","12","13","14","15","16","17"}) end
	if scenario=="Druid Nights" then
		local gladeSlots=0
		for _,number in ipairs({"01","02","05","07","08","13","16"}) do
			if heroChallengeCountryAvailable(heroChallengeCountryGUID(number))==true then gladeSlots=gladeSlots+1 end
		end
		gladeSlots=math.min(gladeSlots,countryCount)
		if slot<=gladeSlots then return heroChallengeCountryIn(guid,{"01","02","05","07","08","13","16"}) end
		return heroChallengeCountryIn(guid,{"03","04","06","09","10","11","12","14","15","17"})
	end
	if scenario=="Dungeon Lords" and slot<=2 then return heroChallengeCountryIn(guid,{"07","09"}) end
	if scenario=="Quest for the Golden Grail" or scenario=="The Chaos Rift" then
		if slot<=4 then return heroChallengeCountryIn(guid,{"04","05","07","09","11","12","13","15"}) end
		return heroChallengeCountryIn(guid,{"01","02","03","06","08","10","14","16","17"})
	end
	if scenario=="Life and Death" then
		local gladeSlots=gStates.playerCount>=2 and gStates.playerCount+1 or 3
		if slot<=gladeSlots then return heroChallengeCountryIn(guid,{"01","02","05","07","08","13","16"}) end
		return heroChallengeCountryIn(guid,{"03","04","06","09","10","11","12","14","15","17"})
	end
	if scenario=="The Realm of the Dead Blitz" then
		local gladeSlots=gStates.coop==1 and gStates.playerCount+1 or gStates.playerCount
		if slot<=gladeSlots then return heroChallengeCountryIn(guid,{"01","02","05","07","08","13","16"}) end
		return heroChallengeCountryIn(guid,{"03","04","06","09","10","11","12","14","15","17"})
	end
	if scenario=="Raiders of the Crusader Temple" and slot<=3 then return heroChallengeCountryIn(guid,{"08","10","11"}) end
	if scenario=="Against the Apocalypse Blitz" then
		local zigguratSlots=gStates.playerCount>1 and 2 or 1
		if slot<=zigguratSlots then return heroChallengeCountryIn(guid,{"16","17"}) end
		return heroChallengeCountryIn(guid,{"01","02","03","04","05","06","07","08","09","10","11","12","13","14","15"})
	end
	--Against the Horsemen has one compulsory terrain tile: Countryside 1 is the face-up centre.
	--All other Countryside slots are unrestricted after the normal expansion/variant availability checks.
	if scenario=="Against the Horsemen Blitz" and slot==1 then return guid==GUID.tile.country01 end
	return true
end

function heroChallengeShuffleCopy(array)
	local result={}
	for i,value in ipairs(array or {}) do result[i]=value end
	for i=#result,2,-1 do local j=math.random(i) result[i],result[j]=result[j],result[i] end
	return result
end

function heroChallengeRequirementSets()
	local sets={{}}
	for seat=1,4 do
		local mage=gStates.positionMageKnight[seat]
		if mage~=nil and mage~="nobody" then
			local data=heroChallengesData[mage]
			if data==nil then return nil,"Hero Challenges: Unsupported Mage Knight" end
			for _, alternatives in ipairs(data.country or {}) do
				local expanded={}
				for _, existing in ipairs(sets) do
					for _, number in ipairs(alternatives) do
						local copy={}
						for guid,_ in pairs(existing) do copy[guid]=true end
						copy[heroChallengeCountryGUID(number)]=true
						expanded[#expanded+1]=copy
					end
				end
				sets=expanded
			end
		end
	end
	return sets,nil
end

--Return a complete legal Countryside assignment, not just the forced tiles. When Hero Challenges are on,
--using the complete assignment avoids duplicate GUID selection after several Heroes reserve overlapping pools.
function heroChallengeCountryAssignment(randomize)
	if gStates.heroChallenges~=true then return nil,nil end
	local countryCount=scenarioList[gStates.scenarioRef][gStates.playersRef].countryTiles
	local requirementSets,reason=heroChallengeRequirementSets()
	if requirementSets==nil then return nil,reason end
	local available={}
	for number=1,17 do
		local guid=heroChallengeCountryGUID(string.format("%02d",number))
		if heroChallengeCountryAvailable(guid)==true then available[#available+1]=guid end
	end
	if randomize==true then available=heroChallengeShuffleCopy(available) end
	local expandedSets={}
	for _,required in ipairs(requirementSets) do
		local hasVillage=false
		for guid,_ in pairs(required) do if heroChallengeCountryHasVillage(guid)==true then hasVillage=true break end end
		if apocalypseQuestsUsed()==true and hasVillage==false then
			for _,guid in ipairs(available) do
				if heroChallengeCountryHasVillage(guid)==true then
					local copy={} for existing,_ in pairs(required) do copy[existing]=true end copy[guid]=true
					expandedSets[#expandedSets+1]=copy
				end
			end
		else expandedSets[#expandedSets+1]=required end
	end
	if randomize==true then expandedSets=heroChallengeShuffleCopy(expandedSets) end

	for _,requiredSet in ipairs(expandedSets) do
		local required={}
		local possible=true
		for guid,_ in pairs(requiredSet) do
			if heroChallengeCountryAvailable(guid)~=true then possible=false break end
			required[#required+1]=guid
		end
		if possible==true and #required<=countryCount then
			table.sort(required,function(a,b)
				local ca,cb=0,0
				for slot=1,countryCount do if heroChallengeCountrySlotAllows(a,slot) then ca=ca+1 end if heroChallengeCountrySlotAllows(b,slot) then cb=cb+1 end end
				return ca<cb
			end)
			if randomize==true then
				--Shuffle equal-flexibility groups without undoing the useful constrained-first ordering.
				local i=1
				while i<=#required do
					local count=0 for slot=1,countryCount do if heroChallengeCountrySlotAllows(required[i],slot) then count=count+1 end end
					local j=i+1
					while j<=#required do local c=0 for slot=1,countryCount do if heroChallengeCountrySlotAllows(required[j],slot) then c=c+1 end end if c~=count then break end j=j+1 end
					local group={} for k=i,j-1 do group[#group+1]=required[k] end group=heroChallengeShuffleCopy(group) for k=i,j-1 do required[k]=group[k-i+1] end i=j
				end
			end
			local forcedSlots,usedTiles={},{}
			local result=nil
			local function fillRemaining()
				local tileMatch={}
				local remainingSlots={}
				for slot=1,countryCount do if forcedSlots[slot]==nil then remainingSlots[#remainingSlots+1]=slot end end
				table.sort(remainingSlots,function(a,b)
					local ca,cb=0,0
					for _,guid in ipairs(available) do if usedTiles[guid]~=true and heroChallengeCountrySlotAllows(guid,a) then ca=ca+1 end if usedTiles[guid]~=true and heroChallengeCountrySlotAllows(guid,b) then cb=cb+1 end end
					return ca<cb
				end)
				local function augment(slot,seen)
					local candidates=randomize==true and heroChallengeShuffleCopy(available) or available
					for _,guid in ipairs(candidates) do
						if usedTiles[guid]~=true and seen[guid]~=true and heroChallengeCountrySlotAllows(guid,slot)==true then
							seen[guid]=true
							if tileMatch[guid]==nil or augment(tileMatch[guid],seen)==true then tileMatch[guid]=slot return true end
						end
					end
					return false
				end
				for _,slot in ipairs(remainingSlots) do if augment(slot,{})~=true then return nil end end
				local assignment={}
				for slot,guid in pairs(forcedSlots) do assignment[slot]=guid end
				for guid,slot in pairs(tileMatch) do assignment[slot]=guid end
				return assignment
			end
			local function placeRequired(index)
				if index>#required then result=fillRemaining() return result~=nil end
				local guid=required[index]
				local slots={} for slot=1,countryCount do if forcedSlots[slot]==nil and heroChallengeCountrySlotAllows(guid,slot) then slots[#slots+1]=slot end end
				if randomize==true then slots=heroChallengeShuffleCopy(slots) end
				for _,slot in ipairs(slots) do
					forcedSlots[slot]=guid usedTiles[guid]=true
					if placeRequired(index+1)==true then return true end
					forcedSlots[slot]=nil usedTiles[guid]=nil
				end
				return false
			end
			if placeRequired(1)==true then return result,nil end
		end
	end
	return nil,"Hero Challenges: Required terrain cannot fit this setup"
end

function heroChallengeSetupLegal()
	if gStates.heroChallenges~=true then return true,nil end
	if gStates.useCustomMageKnights==true then return false,"Hero Challenges cannot use fan-made Mage Knights" end
	if (gStates.riseOfTheForgemasters or 0)>0 then return false,"Hero Challenges cannot use Rise of the Forgemasters" end
	local humans=0
	for seat=1,4 do
		local mage=gStates.positionMageKnight[seat]
		if mage~=nil and mage~="nobody" then
			humans=humans+1
			if mage=="Random" or mage=="All Skills" then return false,"Hero Challenges: Choose specific Mage Knights" end
			if heroChallengesData[mage]==nil then return false,"Hero Challenges: Unsupported Mage Knight" end
		end
	end
	if humans==0 then return false,"Hero Challenges: Choose a Mage Knight" end
	local assignment,reason=heroChallengeCountryAssignment(false)
	if assignment==nil then return false,reason end
	return true,nil
end

--Append the active Heroes' personal Challenge objectives to the Scenario End help box.
--The printed objectives are currently English; repeat them inside every language branch so the information
--is never hidden merely because the user is viewing another translated Scenario End entry.
function heroChallengeScenarioEndText(baseText)
	local text=tostring(baseText or "")
	if gStates==nil or gStates.heroChallenges~=true then return text end
	local lines={}
	for seat=1,4 do
		local mage=gStates.positionMageKnight~=nil and gStates.positionMageKnight[seat] or nil
		local challenge=mage~=nil and heroChallengesData[mage] or nil
		if challenge~=nil then lines[#lines+1]=tostring(mage)..": "..tostring(challenge.objective or "") end
	end
	if #lines==0 then return text end
	local suffix="\n\nHero Challenges:\n"..table.concat(lines,"\n")
	local firstTagStart=text:find("{[%a%-]+}")
	if firstTagStart==nil then return text..suffix end
	local out={}
	if firstTagStart>1 then out[#out+1]=text:sub(1,firstTagStart-1) end
	local pos=firstTagStart
	while pos<=#text do
		local tagStart,tagEnd=text:find("{[%a%-]+}",pos)
		if tagStart==nil then break end
		local nextTagStart=text:find("{[%a%-]+}",tagEnd+1)
		local body=nextTagStart~=nil and text:sub(tagEnd+1,nextTagStart-1) or text:sub(tagEnd+1)
		out[#out+1]=text:sub(tagStart,tagEnd)..body..suffix
		if nextTagStart==nil then break end
		pos=nextTagStart
	end
	return table.concat(out)
end

function applyForgemasterExpansionRequirements()
	local level=gStates.riseOfTheForgemasters or 0
	if level<=0 then return end
	UI.setAttribute("removeLostLegionExpansion", "interactable", "false")
	UI.setAttribute("removeLostLegionExpansion", "isOn", "false")
	gStates.removeLostLegionExpansion=false
	UI.setAttribute("removeBonusCards", "interactable", "false")
	UI.setAttribute("removeBonusCards", "isOn", level==1 and "true" or "false")
	gStates.removeBonusCards=level==1
end

function refreshHeroChallengeOptionLocks()
	if gStates==nil then return end
	local heroOn=gStates.heroChallenges==true
	local rotf=(gStates.riseOfTheForgemasters or 0)>0
	local custom=gStates.useCustomMageKnights==true
	local firstRecon=gStates.gameScenario=="First Reconnaissance"
	UI.setAttribute("heroChallenges","interactable",(not custom and not rotf) and "True" or "False")
	if heroOn==true then
		UI.setAttribute("useCustomMageKnights","interactable","False")
		UI.setAttribute("ROTFSelection","interactable","False")
		UI.setAttribute("ROTFSelectionImage","image","Sliced Button/Button New Deactive")
	else
		UI.setAttribute("useCustomMageKnights","interactable",(not firstRecon and not rotf) and "True" or "False")
		local rotfAllowed=not firstRecon and gStates.removeLostLegionExpansion~=true
		UI.setAttribute("ROTFSelection","interactable",rotfAllowed and "True" or "False")
		UI.setAttribute("ROTFSelectionImage","image",rotfAllowed and "Sliced Button/Button New Active" or "Sliced Button/Button New Deactive")
	end
end

--Fury of the Apocalypse Dragon uses the standalone single-hex Dragon token (42b581)
--stored directly in the Apocalypse Dragon bag. Keep the Core 1 object returned by takeObject()
--rather than relying on an immediate GUID lookup while TTS is still registering the deployed tile.
function furyDragonSetupLair(tile)
	if gStates==nil or gStates.gameScenario~="Fury of the Apocalypse Dragon" then return false end
	tile=tile or getObjectFromGUID(GUID.tile.core01)
	if tile==nil then return false end
	local bearing="240"
	local xy=angleToXY(tile,bearing)
	local hexPos={xy[1],1.00,xy[2]}
	local markerPos={xy[1],1.18,xy[2]}
	gStates.apocalypseDragonLairRevealed=true
	gStates.apocalypseDragonLair={tileGUID=tile.guid,hexes={{bearing=bearing,position=hexPos}},position=markerPos,rotation={0,180,0},fury=true,cityHexKey=tile.guid.."|"..bearing}
	--Fury alternates Landed/In Flight for the entire game. The selected flight target is the state
	--that makes the Dragon "in flight"; do not reset it at the start of later Rounds.
	gStates.furyDragonCurrentHexKey=tile.guid.."|"..bearing
	gStates.furyDragonFlightTarget=nil
	gStates.furyDragonManaDieGUID=nil
	gStates.furyDragonAwaitingCombat=nil
	gStates.furyDragonRoundPrepared=nil
	--Core tile 1's Tomb is the Dragon Lair in Fury and no longer counts as a Tomb.
	terrainTiles[tile.guid].hexFeature[bearing]=""
	gStates.hexOverideSave=gStates.hexOverideSave or {}
	gStates.hexOverideSave[tile.guid]=gStates.hexOverideSave[tile.guid] or {}
	gStates.hexOverideSave[tile.guid][bearing]=""

	local marker=getObjectFromGUID(apocalypseDragon.furyMarker)
	if marker==nil then
		local bag=getObjectFromGUID(GUID.bag.apocalypseDragon)
		if bag~=nil then
			local tilePos=tile.getPosition()
			marker=safeTakeObject("SetupGame",bag,{guid=apocalypseDragon.furyMarker,position={xy[1],tilePos[2]+1.0,xy[2]},rotation={0,180,0},smooth=false})
		end
	end
	if marker==nil then
		broadcastToAll("{en}Fury setup could not deploy the single-space Apocalypse Dragon marker (42b581).{ru}При подготовке «Ярости Дракона Апокалипсиса» не удалось разместить одиночный маркер Дракона Апокалипсиса (42b581).{zh-tw}「末日巨龍之怒」設置無法部署單格末日巨龍標記（42b581）。{zh-cn}“末日巨龙之怒”设置无法部署单格末日巨龙标记（42b581）。{ko}아포칼립스 드래곤의 분노 설정에서 단일 칸 아포칼립스 드래곤 마커(42b581)를 배치하지 못했습니다.{es}La preparación de Furia del Dragón del Apocalipsis no pudo desplegar el marcador de un espacio del Dragón del Apocalipsis (42b581).{fr}La mise en place de la Fureur du Dragon de l’Apocalypse n’a pas pu déployer le marqueur d’une case du Dragon de l’Apocalypse (42b581).{pt-br}A preparação de Fúria do Dragão do Apocalipse não conseguiu posicionar o marcador de um espaço do Dragão do Apocalipse (42b581).{de}Beim Aufbau von Zorn des Apokalypse-Drachen konnte der einfeldrige Apokalypse-Drachenmarker (42b581) nicht eingesetzt werden.",warningColor)
		return false
	end
	marker.unlock()
	marker.setRotation({0,180,0})
	return true
end

--Fury begins with Regular Units even though all Core tiles are already face up. Elite Units only
--join subsequent Round offers after a Countryside tile adjacent to a City has been revealed, or after
--a Hero has entered either City at least once.
function furyDragonEliteConditionMet()
	if gStates==nil or gStates.gameScenario~="Fury of the Apocalypse Dragon" then return false end
	if gStates.furyHeroEnteredCity==true then return true end
	local map=getObjectFromGUID(mapArea)
	if map==nil then return false end
	local countries,cities={},{}
	for _,obj in ipairs(map.getObjects() or {}) do
		local data=terrainTiles[obj.guid]
		if data~=nil and obj.is_face_down==false then
			if data.tileType=="country" then countries[#countries+1]=obj
			elseif data.tileType=="core" and data.hexFeature~=nil and tostring(data.hexFeature.center or ""):sub(1,4)=="city" then cities[#cities+1]=obj end
		end
	end
	for _,city in ipairs(cities) do
		local cp=city.getPosition()
		for _,country in ipairs(countries) do
			local pp=country.getPosition()
			local distance=((cp[1]-pp[1])^2)+((cp[3]-pp[3])^2)
			--Adjacent map-tile centres are 6.35 units apart (40.32 squared).
			if distance>36 and distance<45 then return true end
		end
	end
	return false
end

function furyDragonPrepareEliteUnits()
	if gStates==nil or gStates.gameScenario~="Fury of the Apocalypse Dragon" or gStates.eliteUnitsUsed==true then return false end
	if furyDragonEliteConditionMet()~=true then return false end
	gStates.eliteUnitsUsed=true
	broadcastToAll("{en}Fury of the Apocalypse Dragon: Elite Units are included in this Round's Unit Offer.{ru}Ярость Дракона Апокалипсиса: элитные отряды включены в предложение отрядов этого раунда.{zh-tw}末日巨龍之怒：本回合輪的部隊供應包含精英部隊。{zh-cn}末日巨龙之怒：本回合轮的部队供应包含精英部队。{ko}아포칼립스 드래곤의 분노: 이번 라운드의 유닛 제안에 정예 유닛이 포함됩니다.{es}Furia del Dragón del Apocalipsis: las Unidades de Élite están incluidas en la Oferta de Unidades de esta Ronda.{fr}Fureur du Dragon de l’Apocalypse : les Unités d’Élite sont incluses dans l’Offre d’Unités de cette Manche.{pt-br}Fúria do Dragão do Apocalipse: Unidades de Elite estão incluídas na Oferta de Unidades desta Rodada.{de}Zorn des Apokalypse-Drachen: Eliteeinheiten sind in diesem Einheitenangebot der Runde enthalten.",{1,1,0.5})
	return true
end

function mapSetup()
	startingMapSetup=true
	startingMapTiles={}
	local TileShuffler=		getObjectFromGUID(GUID.bag.terrain.shuffler)
	local CityTileStack=	getObjectFromGUID(GUID.bag.terrain.leftCity)
	local CoreTileStack=	getObjectFromGUID(GUID.bag.terrain.leftCore)
	local CountryTileStack=	getObjectFromGUID(GUID.bag.terrain.leftCountry)
	local customPredefined=gStates.gameScenario=="Custom" and scenarioList[gStates.scenarioRef][gStates.playersRef].mapShape:sub(5,5)=="P"
	if customPredefined then
		--Predefined Custom maps are built by the players. Leave all three selected terrain pools untouched.
		--Store every available tile face down so manual pulls from these bags begin hidden.
		local function faceDownTerrainPool(bag)
			if bag==nil then return end
			local pos=bag.getPosition()
			local guids={}
			for _,contained in ipairs(bag.getObjects()) do guids[#guids+1]=contained.guid end
			for _,guid in ipairs(guids) do
				local tile=bag.takeObject({guid=guid,position={pos.x,pos.y+2,pos.z},rotation={0,180,180},smooth=false})
				if tile~=nil then bag.putObject(tile) end
			end
		end
		faceDownTerrainPool(CityTileStack)
		faceDownTerrainPool(CoreTileStack)
		faceDownTerrainPool(CountryTileStack)
		local openStartPos={-36.0305,0.98,-11.9267}
		local startTile=getObjectFromGUID(startTerrain.wedge)
		local portalObj=getObjectFromGUID(portal.terrainHex)
		if startTile~=nil then
			startTile.unlock()
			if portalObj~=nil then portalObj.unlock() end
			startTile.setPosition(openStartPos)
			if portalObj~=nil then portalObj.setPosition({openStartPos[1],1.1,openStartPos[3]}) end
			startTile.setState(2)
			safeWaitFrames("SetupGame",function()
				local openStart=getObjectFromGUID(startTerrain.open)
				if openStart~=nil then openStart.unlock() end
				local currentPortal=getObjectFromGUID(portal.terrainHex)
				if currentPortal~=nil then currentPortal.unlock() end
			end,5)
		else
			local openStart=getObjectFromGUID(startTerrain.open)
			if openStart~=nil then openStart.unlock() end
			if portalObj~=nil then portalObj.unlock() end
		end
		if TileShuffler~=nil then TileShuffler.destruct() end
		Global.setDecals({})
		startingMapSetup=false
		return
	end
	CityTileStack.shuffle()
	CoreTileStack.shuffle()
	CountryTileStack.shuffle()
	local againstHorsemenMap=gStates.gameScenario=="Against the Horsemen Blitz"
	local furyMap=gStates.gameScenario=="Fury of the Apocalypse Dragon"
	local againstHorsemenCountryTilePos={}
	local againstHorsemenCoreTilePos={}
	local againstHorsemenCityTilePos={}
	local againstHorsemenCoreTileGUIDs={}
	local furyCountrySlots={}
	local furyCoreTilePos={}
	local furyCityTilePos={}
	local furyRevealGUIDs={}
	local furyLairTile=nil
	if furyMap then
		--Exact predefined layouts from the Fury scenario sheet. Place every selected tile face down first;
		--the slots that begin revealed are flipped later in a stepped sequence so normal terrain-entry
		--population logic gets a clean event for each tile.
		local start={-36.0305,1.15,-11.9267}
		local basisA,basisB,countryCoords,faceUpCoords,coreCoords,cityCoords
		if gStates.playerCount<=2 then
			--Solo/two-player Fury uses the normal Wedge start tile and its recorded grid position.
			start={-24.0301,1.15,-16.0837}
			basisA=terrainPlacementNeighbourOffsets[1] basisB=terrainPlacementNeighbourOffsets[2]
			countryCoords={{0,1},{1,0},{1,1},{2,0},{0,2},{0,3},{3,0}}
			faceUpCoords={{0,1},{1,0}}
			coreCoords={{2,2},{1,2},{2,1}}
			cityCoords={{1,3},{3,1}}
		elseif gStates.playerCount==3 then
			basisA=terrainPlacementNeighbourOffsets[1] basisB=terrainPlacementNeighbourOffsets[2]
			countryCoords={{0,1},{1,0},{1,-1},{1,1},{2,0},{2,-1},{3,-1},{4,-1},{0,2},{1,2}}
			faceUpCoords={{0,1},{1,0},{1,-1}}
			coreCoords={{3,1},{2,1},{3,0}}
			cityCoords={{2,2},{4,0}}
		else
			--Four-player Fury uses the open start on the nearest recorded grid point to {-30.03,-13.99}.
			start={-30.0303,1.15,-14.0052}
			basisA=terrainPlacementNeighbourOffsets[6] basisB=terrainPlacementNeighbourOffsets[5]
			countryCoords={{0,-1},{1,-1},{1,0},{1,-4},{1,-3},{0,-3},{4,-3},{0,-2},{1,-2},{2,-2},{3,-2},{2,-1}}
			faceUpCoords={{0,-1},{1,-1},{1,0}}
			coreCoords={{3,-4},{2,-3},{3,-3}}
			cityCoords={{2,-4},{4,-4}}
		end
		local function key(coord) return tostring(coord[1])..","..tostring(coord[2]) end
		local faceUp={} for _,coord in ipairs(faceUpCoords) do faceUp[key(coord)]=true end
		local function furyPos(coord) return {start[1]+coord[1]*basisA[1]+coord[2]*basisB[1],start[2],start[3]+coord[1]*basisA[2]+coord[2]*basisB[2]} end
		for _,coord in ipairs(countryCoords) do furyCountrySlots[#furyCountrySlots+1]={position=furyPos(coord),faceUp=faceUp[key(coord)]==true} end
		for _,coord in ipairs(coreCoords) do furyCoreTilePos[#furyCoreTilePos+1]=furyPos(coord) end
		for _,coord in ipairs(cityCoords) do furyCityTilePos[#furyCityTilePos+1]=furyPos(coord) end
		gStates.furyHeroEnteredCity=false
		--Suppress the Tomb before Core 1 enters the map zone, so setup never treats the Fury Lair as a Tomb.
		terrainTiles[GUID.tile.core01].hexFeature["240"]=""
		gStates.hexOverideSave=gStates.hexOverideSave or {}
		gStates.hexOverideSave[GUID.tile.core01]=gStates.hexOverideSave[GUID.tile.core01] or {}
		gStates.hexOverideSave[GUID.tile.core01]["240"]=""
	end
	if againstHorsemenMap then
		--Radius-two predefined map from the Apocalypse rulebook. Use the existing terrain-placement
		--vectors so these positions stay on exactly the same lattice as every other scripted map.
		--The temporary normal portal/start tile remains separate; avatars are transferred later in setup.
		local centre={-16.8299,1.15,4.7015}
		local east=terrainPlacementNeighbourOffsets[6]
		local northEast=terrainPlacementNeighbourOffsets[1]
		local function horsemenMapPos(q,r)
			return {centre[1]+(q*east[1])+(r*northEast[1]),centre[2],centre[3]+(q*east[2])+(r*northEast[2])}
		end
		againstHorsemenCountryTilePos[1]=horsemenMapPos(0,0)
		for _,coord in ipairs({{-1,1},{0,1},{1,0},{1,-1},{0,-1},{-1,0}}) do
			againstHorsemenCountryTilePos[#againstHorsemenCountryTilePos+1]=horsemenMapPos(coord[1],coord[2])
		end
		--Outer ring, clockwise from the top: Core, Country, City, Core, City, Country,
		--Core, Country, City, Core, City, Country (matching the printed scenario diagram).
		local outer={
			{{-2,2},"core"},{{-1,2},"country"},{{0,2},"city"},{{1,1},"core"},
			{{2,0},"city"},{{2,-1},"country"},{{2,-2},"core"},{{1,-2},"country"},
			{{0,-2},"city"},{{-1,-1},"core"},{{-2,0},"city"},{{-2,1},"country"}
		}
		for _,entry in ipairs(outer) do
			local p=horsemenMapPos(entry[1][1],entry[1][2])
			if entry[2]=="country" then againstHorsemenCountryTilePos[#againstHorsemenCountryTilePos+1]=p
			elseif entry[2]=="core" then againstHorsemenCoreTilePos[#againstHorsemenCoreTilePos+1]=p
			else againstHorsemenCityTilePos[#againstHorsemenCityTilePos+1]=p end
		end
	end
	--Reserve the complete Hero Challenge Countryside assignment before Ultimate Conquest moves
	--surplus Countryside tiles into its mixed Core/Country stack. Otherwise a required GUID can
	--be moved out of CountryTileStack before the later fixed-GUID takeObject() calls.
	local heroCountryAssignment=nil
	if gStates.heroChallenges==true then
		heroCountryAssignment=heroChallengeCountryAssignment(true)
		if heroCountryAssignment==nil then
			print("HERO CHALLENGE SETUP ERROR: no legal Countryside assignment")
			startingMapSetup=false
			return
		end
	end
	local pos=getObjectFromGUID(GUID.bag.terrain.stack).getPosition()--tile stack location
	local tUp=2--Starts building the final tile stack from this high
	--Layout Starting map tile. The Horsemen predefined map temporarily keeps this normal reference
	--during terrain-entry setup, then removes it once every real map tile has settled.
	local a=scenarioList[gStates.scenarioRef][gStates.playersRef].mapShape:sub(5,5)
	local furyWedgeStart=furyMap and gStates.playerCount<=2
	if (a=="O" or a=="F" or a=="P") and furyWedgeStart~=true then
		local openStartPos={-36.0305,0.98,-11.9267}
		if furyMap and gStates.playerCount>=4 then openStartPos={-30.0303,0.98,-14.0052} end
		getObjectFromGUID(startTerrain.wedge).unlock()
		getObjectFromGUID(portal.terrainHex).unlock()
		getObjectFromGUID(startTerrain.wedge).setPosition(openStartPos)--start terrain tile gets moved and state changed
		getObjectFromGUID(portal.terrainHex).setPosition({openStartPos[1],1.1,openStartPos[3]})--portal overlay follows the start tile
		getObjectFromGUID(startTerrain.wedge).setState(2)
		safeWaitFrames("SetupGame",function() getObjectFromGUID(startTerrain.open).lock() getObjectFromGUID(portal.terrainHex).lock() end, 5)
	end

	--Add Grid
	local gridType=""
	if scenarioList[gStates.scenarioRef][gStates.playersRef].mapShape=="{en}Open Limited to 4 Columns{ru}Открытое поле с ограничением в 4 ряда{zh-tw}4 列的限制開放地圖{zh-cn}4 列的限制开放地图 {ko}4열 제한{es}Abierto Limitado a 4 Columnas{fr}Ouvert Limité à 4 Colonnes{pt-br}Aberto Limitado a 4 Colunas{de}Offen Begrenzt auf 4 Spalten" then gridType="https://steamusercontent-a.akamaihd.net/ugc/1674736055049111266/7BC768B7CD64E6018EBEC720559690409F4BA555/" end--4
	if scenarioList[gStates.scenarioRef][gStates.playersRef].mapShape=="{en}Open Limited to 3 Columns{ru}Открытое поле с ограничением в 3 ряда{zh-tw}3 列的限制開放地圖{zh-cn}3 列的限制开放地图 {ko}3열 제한{es}Abierto Limitado a 3 Columnas{fr}Ouvert Limité à 3 Colonnes{pt-br}Aberto Limitado a 3 Colunas{de}Offen Begrenzt auf 3 Spalten" then gridType="https://steamusercontent-a.akamaihd.net/ugc/1674736055049110361/978D612A44ADDE6E1630965A311722114BA28AE5/" end--3
	if scenarioList[gStates.scenarioRef][gStates.playersRef].mapShape=="{en}Fully Open{ru}Полностью открытое поле{zh-tw}完全開放地圖{zh-cn}完全开放地图{ko}전체 개방형{es}Totalmente Abierto{fr}Entièrement Ouvert{pt-br}Totalmente Aberto{de}Vollständig Offen" then gridType="https://steamusercontent-a.akamaihd.net/ugc/1674736055049031257/2457D03CE33118D57CD456183026FEB596CF6A3A/" end--fully
	if scenarioList[gStates.scenarioRef][gStates.playersRef].mapShape=="{en}Wedge{ru}Клиновидное поле{zh-tw}錐形地圖{zh-cn}锥形地图{ko}쐐기형{es}En Cuña{fr}Coin{pt-br}Cônico{de}Keil" then gridType="https://steamusercontent-a.akamaihd.net/ugc/1674736055049113832/44EE3C6AA10498BCD1B46040AD18631BFD580AC4/" end--Wedge
	if gStates.gameScenario=="The Gauntlet" then gridType="https://steamusercontent-a.akamaihd.net/ugc/1673610837369514853/1BBAD048566E753F09184CBAE7022049D90B5471/" end
	if againstHorsemenMap then gridType="" end
	Global.setDecals({})
	if gridType~="" then Global.addDecal({name="Terrain Grid", url=gridType, position={-16.825, 0.99, 0.55}, rotation={90.0, 0.0, 0.0}, scale={60, 60, 1}}) end

	--shuffle the order of data in a table
	function listShuffle(array)
		--Remove lost legion GUIDs
		if gStates.removeLostLegionExpansion==true then
			local tempArray={}
			local lostLegionTiles={GUID.tile.country12, GUID.tile.country13, GUID.tile.country14, GUID.tile.core09, GUID.tile.core10}--12, 13, 14, *9*, *10*
			for a=1, #array, 1 do
				local found=false
				for b=1, #lostLegionTiles, 1 do
					if array[a]==lostLegionTiles[b] then found=true end
				end
				if found==false then tempArray[#tempArray+1]=array[a] end
			end
			array=tempArray
		end
		if gStates.removeApocalypseTerrain==true then
			local tempArray={}
			local ApocalypseTiles={GUID.tile.country15, GUID.tile.country16, GUID.tile.country17, GUID.tile.core11, GUID.tile.core12}--15, 16, 17, *11*, *12*
			for a=1, #array, 1 do
				local found=false
				for b=1, #ApocalypseTiles, 1 do
					if array[a]==ApocalypseTiles[b] then found=true end
				end
				if found==false then tempArray[#tempArray+1]=array[a] end
			end
			array=tempArray
		end
		if gStates.removeTerrain==true then
			local tempArray={}
			local EasyTiles={GUID.tile.country01, GUID.tile.country02}
			for a=1, #array, 1 do
				local found=false
				for b=1, #EasyTiles, 1 do
					if array[a]==EasyTiles[b] then found=true end
				end
				if found==false then tempArray[#tempArray+1]=array[a] end
			end
			array=tempArray
		end
		--shuffle the list
		local tReturn={}
		for a=#array, 1, -1 do
			local b=math.random(a)
			array[a], array[b]=array[b], array[a]
			table.insert(tReturn, array[a])
		end
		return tReturn
	end
	--Pull City Tiles
	local warOfFourCityTilePos={{-32.4304, 1.15, -1.5341}, {-25.2302, 1.15, -9.8482}, {-28.8303, 1.15, 8.8586}, {-22.8301, 1.15, 6.7794}, {-15.6299, 1.15, -1.5341}, {-14.4298, 1.15, -7.7696}}
	local warOfFourCoreTilePos={{-24.0301, 1.15, 13.0156}, {-16.8299, 1.15,  4.7015}, {-9.6297, 1.15, -3.6126}}
	for i=1, gStates.cityTiles, 1 do
		local noShuffle=0
		local params={rotation={0, 180, 180}, smooth=false}
		if gStates.randomTileOrientation==true then params.rotation={0, math.random(1,6)*60, 180} end
		if i==1 and (gStates.gameScenario=="Mines Liberation" or gStates.gameScenario=="Life and Death" or gStates.gameScenario=="The Chaos Rift" or gStates.gameScenario=="Raiders of the Crusader Temple") then params.guid=GUID.tile.city08 end--Use Red City
		if i==1 and (gStates.gameScenario=="Dungeon Lords" or gStates.gameScenario=="The Realm of the Dead Blitz") then params.guid=GUID.tile.city06 end--Use Blue City
		if i==1 and (gStates.gameScenario=="Conquer and Hold" or gStates.gameScenario=="The Hidden Valley Blitz") then params.guid=GUID.tile.city07 end--Use White City
		if (gStates.gameScenario=="Druid Nights" and i==1) or (gStates.gameScenario=="The Realm of the Dead Blitz" and i==2) or (gStates.gameScenario=="Life and Death" and i==2) or (gStates.gameScenario=="The Hidden Valley Blitz" and i==2) then params.guid=GUID.tile.city05 end--Use Green City
		if (gStates.gameScenario=="Volkare's Return" and i==1) or gStates.gameScenario=="Volkare's Return Blitz" or gStates.gameScenario=="The Chaos Rift" then params.position={pos.x, pos.y+tUp, pos.z} tUp=tUp+0.5 noShuffle=1 end--puts city at bottom of stack
		if gStates.gameScenario=="The Gauntlet" and i==1 then params.guid=GUID.tile.city08 params.position={4.7708, 0.96, 8.8586} noShuffle=1 end
		if againstHorsemenMap then params.position=againstHorsemenCityTilePos[i] noShuffle=1 end
		if furyMap then
			params.position=furyCityTilePos[i]
			params.rotation={0,gStates.randomTileOrientation==true and math.random(1,6)*60 or 180,180}
			noShuffle=1
		end
		if gStates.gameScenario=="The War of Four" then
			local randPos=math.random(1,#warOfFourCityTilePos)
			if warOfFourCityTilePos[randPos][1]==-28.8303 or warOfFourCityTilePos[randPos][1]==-15.6299 then
				warOfFourCoreTilePos[#warOfFourCoreTilePos+1]=warOfFourCityTilePos[randPos+1]
				table.remove(warOfFourCityTilePos, randPos+1)
			end
			params.position=warOfFourCityTilePos[randPos]
			noShuffle=1
			if warOfFourCityTilePos[randPos][1]==-22.8301 or warOfFourCityTilePos[randPos][1]==-14.4298 then
				warOfFourCoreTilePos[#warOfFourCoreTilePos+1]=warOfFourCityTilePos[randPos-1]
				table.remove(warOfFourCityTilePos, randPos-1)
				table.remove(warOfFourCityTilePos, randPos-1)
			else
				table.remove(warOfFourCityTilePos, randPos)
			end
		end
		local obj=safeTakeObject("SetupGame",CityTileStack,params)--take from the City Tile Bag
		if furyMap and obj~=nil then furyRevealGUIDs[#furyRevealGUIDs+1]=obj.guid end
		if noShuffle==0 then TileShuffler.putObject(obj) end--Place in the Core Tile Shuffler if it is shuffled
	end

	--Pull Core Tiles
	local CoreKeepMageTiles=	{GUID.tile.core02, GUID.tile.core03, GUID.tile.core04, GUID.tile.core09, GUID.tile.core10} CoreKeepMageTiles=listShuffle(CoreKeepMageTiles)
	local CoreGauntletTiles=	{GUID.tile.core02, GUID.tile.core04, GUID.tile.core09, GUID.tile.core10} CoreGauntletTiles=listShuffle(CoreGauntletTiles)
	local CoreMineTiles=		{GUID.tile.core02, GUID.tile.core03, GUID.tile.core04} CoreMineTiles=listShuffle(CoreMineTiles)
	local CoreRuinTiles=		{GUID.tile.core02, GUID.tile.core03, GUID.tile.core04, GUID.tile.core11} CoreRuinTiles=listShuffle(CoreRuinTiles)
	local CorePyramidTiles=		{GUID.tile.core11, GUID.tile.core12} CorePyramidTiles=listShuffle(CorePyramidTiles)
	local CoreNotPyramidTiles=	{GUID.tile.core01, GUID.tile.core02, GUID.tile.core03, GUID.tile.core04, GUID.tile.core09, GUID.tile.core10} CoreNotPyramidTiles=listShuffle(CoreNotPyramidTiles)
	local CoreNotDragonLairTiles={GUID.tile.core01, GUID.tile.core02, GUID.tile.core04, GUID.tile.core09, GUID.tile.core10, GUID.tile.core11, GUID.tile.core12} CoreNotDragonLairTiles=listShuffle(CoreNotDragonLairTiles)
	local CoreNotFuryLairTiles={GUID.tile.core02, GUID.tile.core03, GUID.tile.core04, GUID.tile.core09, GUID.tile.core10, GUID.tile.core11, GUID.tile.core12} CoreNotFuryLairTiles=listShuffle(CoreNotFuryLairTiles)
	local coreTilesToUse=scenarioList[gStates.scenarioRef][gStates.playersRef].coreTiles
	if gStates.gameScenario=="Ultimate Conquest" then coreTilesToUse=CoreTileStack.getQuantity() end
	for i=1, coreTilesToUse, 1 do
		local params={rotation={0, 180, 180}, smooth=false}
		if againstHorsemenMap and gStates.randomTileOrientation==true then params.rotation={0, math.random(1,6)*60, 180} end
		if gStates.gameScenario=="Mines Liberation" then params.guid=CoreMineTiles[i] end
		if gStates.gameScenario=="Conquer and Hold" then params.guid=CoreKeepMageTiles[i] end
		if gStates.gameScenario=="Dungeon Lords" and i==1 then params.guid=GUID.tile.core01 end
		if gStates.gameScenario=="The Gauntlet" and i<=4 then params.guid=CoreGauntletTiles[i] end
		if gStates.gameScenario=="Raiders of the Crusader Temple" and (i<=3 or (i<=4 and gStates.removeApocalypseTerrain~=true)) then params.guid=CoreRuinTiles[i] end
		if gStates.gameScenario=="Against the Apocalypse Blitz" and i==1 then params.guid=CorePyramidTiles[i] end
		if gStates.gameScenario=="Against the Apocalypse Blitz" and i>=2 then params.guid=CoreNotPyramidTiles[i-1] end
		if gStates.gameScenario=="Against the Dragon Blitz" and i==1 then params.guid=GUID.tile.core03 end
		if gStates.gameScenario=="Against the Dragon Blitz" and i>=2 then params.guid=CoreNotDragonLairTiles[i-1] end
		if gStates.gameScenario=="Fury of the Apocalypse Dragon" and i==1 then params.guid=GUID.tile.core01 end
		if gStates.gameScenario=="Fury of the Apocalypse Dragon" and i>=2 then params.guid=CoreNotFuryLairTiles[i-1] end
		if againstHorsemenMap then
			params.position=againstHorsemenCoreTilePos[i]
			local coreTile=safeTakeObject("SetupGame",CoreTileStack,params)
			if coreTile==nil then print("HORSEMEN SETUP ERROR: Core tile "..tostring(i).." was not available") startingMapSetup=false return end
			againstHorsemenCoreTileGUIDs[i]=coreTile.guid
		elseif furyMap then
			params.position=furyCoreTilePos[i]
			params.rotation={0,gStates.randomTileOrientation==true and math.random(1,6)*60 or 180,180}
			local coreTile=safeTakeObject("SetupGame",CoreTileStack,params)
			if coreTile==nil then print("FURY SETUP ERROR: Core tile "..tostring(i).." was not available") startingMapSetup=false return end
			if i==1 then furyLairTile=coreTile end
			furyRevealGUIDs[#furyRevealGUIDs+1]=coreTile.guid
		else
			TileShuffler.putObject(safeTakeObject("SetupGame",CoreTileStack,params))--Core Tile Shuffler
		end
	end
	--Ultimate Conquest Country mix. With Hero Challenges, move only tiles that are not reserved
	--for the Countryside section that sits on top of the mixed stack.
	if gStates.gameScenario=="Ultimate Conquest" then
		local megaCountry=math.max(CountryTileStack.getQuantity()-scenarioList[gStates.scenarioRef][gStates.playersRef].countryTiles,0)
		if heroCountryAssignment~=nil then
			local reserved={}
			for _,guid in pairs(heroCountryAssignment) do reserved[guid]=true end
			local surplusGUIDs={}
			for _,contained in ipairs(CountryTileStack.getObjects()) do
				if contained.guid~=nil and reserved[contained.guid]~=true then surplusGUIDs[#surplusGUIDs+1]=contained.guid end
			end
			surplusGUIDs=heroChallengeShuffleCopy(surplusGUIDs)
			for i=1, megaCountry, 1 do
				local guid=surplusGUIDs[i]
				if guid==nil then print("ULTIMATE CONQUEST SETUP ERROR: not enough unreserved Countryside tiles") startingMapSetup=false return end
				local countryTile=CountryTileStack.takeObject({guid=guid,rotation={0, 180, 180},smooth=false})
				if countryTile==nil then print("ULTIMATE CONQUEST SETUP ERROR: could not reserve Hero Challenge Countryside tile set") startingMapSetup=false return end
				TileShuffler.putObject(countryTile)
			end
		else
			for i=1, megaCountry, 1 do
				local params={rotation={0, 180, 180}, smooth=false}
				TileShuffler.putObject(safeTakeObject("SetupGame",CountryTileStack,params))
			end
		end
	end

	--place core and city tiles on stack shuffled
	TileShuffler.shuffle()
	local VolQuestTilePos=		{{-18.0299, 1.15, 10.9371}, {-16.8299, 1.15,  4.7015}, {-22.8301, 1.15,  6.7794}, {-10.8297, 1.15,  2.6230}, {-15.6299, 1.15, -1.5341}, {-9.6297, 1.15, -3.6126}, {-14.4298, 1.15, -7.7696}, {-21.6300, 1.15, 0.5445}}
	local ConquerAndHoldTilePos={{-27.6302, 1.15,  2.6230}, {-21.6300, 1.15,  0.5445}, {-26.4302, 1.15, -3.6126}, {-20.4300, 1.15, -5.6911}}
	local GauntletTilePos=		{{ -0.0294, 1.15,  4.7015}, { -4.8295, 1.15,  0.5445}, { -9.6297, 1.15, -3.6126}}
	for i=1, TileShuffler.getQuantity(), 1 do
		local params={smooth=false}
		if gStates.randomTileOrientation==false then params.rotation={0, 180, 180} else params.rotation={0, math.random(1,6)*60, 180} end
		if gStates.gameScenario=="Volkare's Quest" then
			if i==6 and gStates.playersRef==5 then
				params.position=VolQuestTilePos[8]
			else
				params.position=VolQuestTilePos[i]
			end
		end
		if gStates.gameScenario=="The War of Four" then
			params.position=warOfFourCoreTilePos[i]
		end
		if gStates.gameScenario=="Conquer and Hold" then params.position=ConquerAndHoldTilePos[i] end
		if gStates.gameScenario=="The Gauntlet" then params.position=GauntletTilePos[i] end
		if params.position==nil then params.position={pos.x, pos.y+tUp, pos.z} tUp=tUp+0.5 end
		safeTakeObject("SetupGame",TileShuffler,params)
	end

	--Pull Country Tiles
	local CountryGauntletTiles=			{GUID.tile.country01, GUID.tile.country02, GUID.tile.country03, GUID.tile.country04, GUID.tile.country05, GUID.tile.country06, GUID.tile.country07, GUID.tile.country08, GUID.tile.country09, GUID.tile.country10, GUID.tile.country12, GUID.tile.country13, GUID.tile.country14, GUID.tile.country15, GUID.tile.country16, GUID.tile.country17} CountryGauntletTiles=listShuffle(CountryGauntletTiles)
	local function countryTileHasVillage(guid)
		local data=terrainTiles[guid]
		if data==nil or data.hexFeature==nil then return false end
		for _, feature in pairs(data.hexFeature) do if feature=="village" then return true end end
		return false
	end
	local function questVillageFirst(array)
		if apocalypseQuestsUsed()==false then return array end
		for i, guid in ipairs(array) do
			if countryTileHasVillage(guid) then array[1], array[i]=array[i], array[1] break end
		end
		return array
	end
	local CountryVillageTiles={}
	for guid, data in pairs(terrainTiles) do if data.tileType=="country" and countryTileHasVillage(guid) then CountryVillageTiles[#CountryVillageTiles+1]=guid end end
	CountryVillageTiles=listShuffle(CountryVillageTiles)
	local CountryTileOrder=				{GUID.tile.country03, GUID.tile.country04, GUID.tile.country05, GUID.tile.country06, GUID.tile.country07, GUID.tile.country08, GUID.tile.country09, GUID.tile.country10, GUID.tile.country11, GUID.tile.country02, GUID.tile.country01}--tiles 01 and 02 at end to deploy corectly at start
	local CountryNonMonasteryTiles=		{GUID.tile.country01, GUID.tile.country02, GUID.tile.country03, GUID.tile.country04, GUID.tile.country06, GUID.tile.country08, GUID.tile.country09, GUID.tile.country10, GUID.tile.country11, GUID.tile.country13, GUID.tile.country14, GUID.tile.country15, GUID.tile.country16, GUID.tile.country17} CountryNonMonasteryTiles=listShuffle(CountryNonMonasteryTiles)
	local CountryNonMineTiles=			{GUID.tile.country01, GUID.tile.country04, GUID.tile.country07, GUID.tile.country08, GUID.tile.country09, GUID.tile.country10, GUID.tile.country11, GUID.tile.country12, GUID.tile.country16}	CountryNonMineTiles=listShuffle(CountryNonMineTiles)
	local CountryNotGladeTiles=			{GUID.tile.country03, GUID.tile.country04, GUID.tile.country06, GUID.tile.country09, GUID.tile.country10, GUID.tile.country11, GUID.tile.country12, GUID.tile.country14, GUID.tile.country15, GUID.tile.country17} CountryNotGladeTiles=listShuffle(CountryNotGladeTiles)
	local CountryMonasteryMageTiles=	{GUID.tile.country04, GUID.tile.country05, GUID.tile.country07, GUID.tile.country09, GUID.tile.country11, GUID.tile.country12, GUID.tile.country13, GUID.tile.country15} CountryMonasteryMageTiles=listShuffle(CountryMonasteryMageTiles)
	local CountryNotMonasteryMageTiles=	{GUID.tile.country01, GUID.tile.country02, GUID.tile.country03, GUID.tile.country06, GUID.tile.country08, GUID.tile.country10, GUID.tile.country14, GUID.tile.country16, GUID.tile.country17}	CountryNotMonasteryMageTiles=listShuffle(CountryNotMonasteryMageTiles)
	local CountryKeepMageTiles=			{GUID.tile.country03, GUID.tile.country04, GUID.tile.country09, GUID.tile.country10, GUID.tile.country11, GUID.tile.country13, GUID.tile.country14, GUID.tile.country15, GUID.tile.country17} CountryKeepMageTiles=listShuffle(CountryKeepMageTiles)
	local CountryGladeTiles=			{GUID.tile.country01, GUID.tile.country02, GUID.tile.country05, GUID.tile.country07, GUID.tile.country08, GUID.tile.country13, GUID.tile.country16} CountryGladeTiles=listShuffle(CountryGladeTiles)
	local CountryMineTiles=				{GUID.tile.country02, GUID.tile.country03, GUID.tile.country05, GUID.tile.country06, GUID.tile.country13, GUID.tile.country14, GUID.tile.country15, GUID.tile.country17} CountryMineTiles=listShuffle(CountryMineTiles)
	local CountryMonasteryTiles=		{GUID.tile.country05, GUID.tile.country07, GUID.tile.country12} CountryMonasteryTiles=listShuffle(CountryMonasteryTiles)
	local CountryDungeonTiles=			{GUID.tile.country07, GUID.tile.country09}
	local CountryRuinTiles=				{GUID.tile.country08, GUID.tile.country10, GUID.tile.country11} CountryRuinTiles=listShuffle(CountryRuinTiles)
	local CountryZigguratTiles=			{GUID.tile.country16, GUID.tile.country17} CountryZigguratTiles=listShuffle(CountryZigguratTiles)
	local CountryNotZigguratTiles=		{GUID.tile.country01, GUID.tile.country02, GUID.tile.country03, GUID.tile.country04, GUID.tile.country05, GUID.tile.country06, GUID.tile.country07, GUID.tile.country08, GUID.tile.country09, GUID.tile.country10, GUID.tile.country11, GUID.tile.country12, GUID.tile.country13, GUID.tile.country14, GUID.tile.country15} CountryNotZigguratTiles=listShuffle(CountryNotZigguratTiles)
	--Quest games need a Village in the selected Countryside set. Promote a compatible Village inside each
	--scenario-specific pool so the existing Mine/Glade/Keep/Ruin/etc. terrain rules still choose their normal tile types.
	if apocalypseQuestsUsed()==true then
		CountryGauntletTiles=questVillageFirst(CountryGauntletTiles)
		CountryKeepMageTiles=questVillageFirst(CountryKeepMageTiles)
		CountryGladeTiles=questVillageFirst(CountryGladeTiles)
		CountryMonasteryMageTiles=questVillageFirst(CountryMonasteryMageTiles)
		CountryRuinTiles=questVillageFirst(CountryRuinTiles)
		CountryZigguratTiles=questVillageFirst(CountryZigguratTiles)
	end
	local questVillageGUID=nil
	local count=0
	local druidGladeSlots=math.min(#CountryGladeTiles,scenarioList[gStates.scenarioRef][gStates.playersRef].countryTiles)
	local params={}
	for i=1, scenarioList[gStates.scenarioRef][gStates.playersRef].countryTiles, 1 do
		params={rotation={0, 180, 180}, smooth=false}
		if againstHorsemenMap and gStates.randomTileOrientation==true then params.rotation={0, math.random(1,6)*60, 180} end
		if againstHorsemenMap and i==1 then params.guid=GUID.tile.country01 end
		if gStates.gameScenario=="First Reconnaissance" and i<=scenarioList[gStates.scenarioRef][gStates.playersRef].countryTiles-2 then params.guid=CountryTileOrder[i] end
		if gStates.gameScenario=="First Reconnaissance" and i>=scenarioList[gStates.scenarioRef][gStates.playersRef].countryTiles-1 then params.guid=CountryTileOrder[i+(11-scenarioList[gStates.scenarioRef][gStates.playersRef].countryTiles)] end
		if gStates.gameScenario=="Mines Liberation" and i<=4 then params.guid=CountryMineTiles[i] end
		if gStates.gameScenario=="Mines Liberation" and i>=5 then params.guid=CountryNonMineTiles[i-4] end
		if gStates.gameScenario=="Conquer and Hold" then params.guid=CountryKeepMageTiles[i] end
		if gStates.gameScenario=="The Gauntlet" then params.guid=CountryGauntletTiles[i] end
		if gStates.gameScenario=="Druid Nights" and i<=druidGladeSlots then params.guid=CountryGladeTiles[i] end
		if gStates.gameScenario=="Druid Nights" and i>druidGladeSlots then params.guid=CountryNotGladeTiles[i-druidGladeSlots] end
		if gStates.gameScenario=="Dungeon Lords" and i<=2 then params.guid=CountryDungeonTiles[i] end
		if (gStates.gameScenario=="Quest for the Golden Grail" or gStates.gameScenario=="The Chaos Rift") and i<=4 then params.guid=CountryMonasteryMageTiles[i] end
		if (gStates.gameScenario=="Quest for the Golden Grail" or gStates.gameScenario=="The Chaos Rift") and i>=5 then params.guid=CountryNotMonasteryMageTiles[i-4] end
		if gStates.gameScenario=="Life and Death" and ((i<=gStates.playerCount+1 and gStates.playerCount>=2) or (i<=3 and gStates.playerCount==1)) then params.guid=CountryGladeTiles[i] count=count+1 end
		if gStates.gameScenario=="Life and Death" and ((i>=gStates.playerCount+2 and gStates.playerCount>=2) or (i>=4 and gStates.playerCount==1)) then params.guid=CountryNotGladeTiles[i-count] end
		if gStates.gameScenario=="The Realm of the Dead Blitz" and ((i<=gStates.playerCount+1 and gStates.coop==1) or (i<=gStates.playerCount and gStates.coop==0)) then params.guid=CountryGladeTiles[i] count=count+1 end
		if gStates.gameScenario=="The Realm of the Dead Blitz" and ((i>=gStates.playerCount+2 and gStates.coop==1) or (i>=gStates.playerCount+1 and gStates.coop==0)) then params.guid=CountryNotGladeTiles[i-count] end
		if gStates.gameScenario=="Raiders of the Crusader Temple" and i<=3 then params.guid=CountryRuinTiles[i] end
		if gStates.gameScenario=="Against the Apocalypse Blitz" and i==1 then params.guid=CountryZigguratTiles[i] count=count+1 end
		if gStates.gameScenario=="Against the Apocalypse Blitz" and i==2 and gStates.playerCount>1 then params.guid=CountryZigguratTiles[i] count=count+1 end
		if gStates.gameScenario=="Against the Apocalypse Blitz" and ((i>=3 and gStates.playerCount>1) or (i>=2 and gStates.playerCount==1)) then params.guid=CountryNotZigguratTiles[i-count] end
		--Hero Challenges use a complete pre-validated assignment. It already satisfies the scenario's slot rule,
		--all selected Heroes' required tiles, expansion/removal settings, and the Quest Village requirement.
		if heroCountryAssignment~=nil then params.guid=heroCountryAssignment[i] end
		--Record a Village supplied by the scenario scheme. If this is an unrestricted slot and none has been
		--selected yet, use an available Village here instead of overriding a scenario-specific terrain requirement.
		if apocalypseQuestsUsed()==true and questVillageGUID==nil then
			if params.guid~=nil and countryTileHasVillage(params.guid) then
				questVillageGUID=params.guid
			elseif params.guid==nil and CountryVillageTiles[1]~=nil then
				params.guid=CountryVillageTiles[1]
				questVillageGUID=params.guid
			end
		end
		if againstHorsemenMap then
			params.position=againstHorsemenCountryTilePos[i]
			if i==1 then
				params.callback_function=function(obj)
					safeWaitTime("SetupGame",function() gStates.firstStarted=true firstTile=obj.guid obj.flip() end,1)
				end
			end
		elseif furyMap then
			local slot=furyCountrySlots[i]
			params.position=slot.position
			params.rotation={0,gStates.randomTileOrientation==true and math.random(1,6)*60 or 180,180}
		end
		local countryTile=safeTakeObject("SetupGame",CountryTileStack,params)
		if countryTile==nil then
			print("COUNTRYSIDE SETUP ERROR: tile "..tostring(params.guid).." was not available for slot "..tostring(i))
			startingMapSetup=false
			return
		end
		if furyMap and furyCountrySlots[i].faceUp==true then furyRevealGUIDs[#furyRevealGUIDs+1]=countryTile.guid end
		if not againstHorsemenMap and not furyMap then TileShuffler.putObject(countryTile) end
	end

	if furyMap then
		--Everything in Fury is already on the table. Core 1's former Tomb is the one-space Dragon Lair.
		if furyDragonSetupLair(furyLairTile)~=true then print("FURY SETUP ERROR: could not establish the Dragon Lair") end
		--Like the Volkare's Quest opening tiles, reveal from a settled face-down state in steps. This makes
		--each reveal re-enter the normal terrain population path instead of arriving already face up.
		for revealIndex,revealGUID in ipairs(furyRevealGUIDs) do
			local guid=revealGUID
			safeWaitTime("SetupGame",function()
				local tile=getObjectFromGUID(guid)
				if tile~=nil and tile.is_face_down==true then tile.flip() end
			end,revealIndex)
		end
		safeWaitTime("SetupGame",function() startingMapSetup=false fakeDropAvatar() end,#furyRevealGUIDs+2)
		return
	end

	--The predefined terrain is now complete. Keep Mage Knights physically parked on the Portal card,
	--but make Country01's central Glade their shared logical start, then place the four hidden Horsemen.
	if againstHorsemenMap then
		againstHorsemenSetStartingAvatarLocations()
		againstHorsemenSetupTokens(againstHorsemenCoreTileGUIDs,againstHorsemenCoreTilePos)
		safeWaitTime("SetupGame",function()
			--Country01's central Magical Glade replaces the normal starting terrain in this scenario.
			--Remove either state of the start tile plus only its map Portal overlay; the Portal card stays
			--in place as the shared-avatar parking area.
			local startObj=getObjectFromGUID(startTerrain.wedge) or getObjectFromGUID(startTerrain.open)
			local portalObj=getObjectFromGUID(portal.terrainHex)
			if startObj~=nil then startObj.destruct() end
			if portalObj~=nil then portalObj.destruct() end
			startingMapSetup=false
		end,4)
		return
	end

	--place Country tiles on stack shuffled
	if gStates.gameScenario~="First Reconnaissance" then TileShuffler.shuffle() end
	--When Apocalypse Dragon Quests are in use, explicitly draw the selected Village as the first Countryside tile.
	--This is done after the scenario has built its terrain set, so its selection scheme remains intact.
	local function takeStartingCountry(params)
		if questVillageGUID~=nil then params.guid=questVillageGUID questVillageGUID=nil end
		return safeTakeObject("SetupGame",TileShuffler,params)
	end
	local rot={}
	if scenarioList[gStates.scenarioRef][gStates.playersRef].mapShape:sub(5,5)=="W" then
		if gStates.randomTileOrientation==false then rot={0, 180, 180} else rot={0, math.random(1,6)*60, 180} end
		takeStartingCountry({position={-25.2302, 1.07, -9.8482}, rotation=rot, smooth=false, callback_function=function(obj) safeWaitTime("SetupGame",function() gStates.firstStarted=true firstTile=obj.guid obj.flip() end, 1) end})
		if gStates.randomTileOrientation==false then rot={0, 180, 180} else rot={0, math.random(1,6)*60, 180} end
		takeStartingCountry({position={-19.2300, 1.07, -11.9267}, rotation=rot, smooth=false, callback_function=function(obj) safeWaitTime("SetupGame",function() obj.flip() end, 2) end})
		if gStates.gameScenario=="The Chaos Rift" then
			if gStates.randomTileOrientation==false then rot={0, 180, 180} else rot={0, math.random(1,6)*60, 180} end
			takeStartingCountry({position={-20.4300, 1.09, -5.6911}, rotation=rot, smooth=false})
		end
	else
		if gStates.randomTileOrientation==false then rot={0, 180, 180} else rot={0, math.random(1,6)*60, 180} end
		if gStates.gameScenario~="The Gauntlet" and gStates.gameScenario~="Volkare's Return" and gStates.gameScenario~="Volkare's Return Blitz" then takeStartingCountry({position={-37.2305, 1.07, -5.6911}, rotation=rot, smooth=false, callback_function=function(obj) tile1=obj safeWaitTime("SetupGame",function() gStates.firstStarted=true firstTile=tile1.guid tile1.flip() end, 1) end}) end
		if gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz" then safeWaitTime("SetupGame",function() getObjectFromGUID("835c91").setPosition({-37.2305, 1.15, -5.6911}) getObjectFromGUID("835c91").flip() end, 1) end
		if gStates.randomTileOrientation==false then rot={0, 180, 180} else rot={0, math.random(1,6)*60, 180} end
		takeStartingCountry({position={-31.2303, 1.07, -7.7696}, rotation=rot, smooth=false, callback_function=function(obj) safeWaitTime("SetupGame",function() obj.flip() end, 2) end})
		if gStates.randomTileOrientation==false then rot={0, 180, 180} else rot={0, math.random(1,6)*60, 180} end
		if gStates.gameScenario~="The Gauntlet" then takeStartingCountry({position={-30.0303, 1.07, -14.0000}, rotation=rot, smooth=false, callback_function=function(obj) safeWaitTime("SetupGame",function() obj.flip() end, 3) end}) end
		if gStates.gameScenario=="Volkare's Quest" or gStates.gameScenario=="The War of Four" then safeWaitTime("SetupGame",function() getObjectFromGUID("835c91").setPosition({-12.0297, 1.15, 8.8586}) getObjectFromGUID("835c91").flip() end, 3) end
	end
	local VolQuestTilePos=		  {{-32.4304, 1.15, -1.5341}, {-27.6302, 1.15,   2.6230}, {-26.4302, 1.15, -3.6126}, {-25.2302, 1.15, -9.8482}, {-20.4300, 1.15,  -5.6911}, {-21.6300, 1.15,   0.5445}, {-24.0301, 1.15, -16.0837}, {-19.2300, 1.15, -11.9267}, {-14.4298, 0.15, -7.7696}}
	local warOfFourCountryTilePos={{-38.4306, 1.15,  0.5445}, {-27.6302, 1.15,   2.6230}, {-26.4302, 1.15, -3.6126}, {-33.6304, 1.15, 4.7015},  {-20.4300, 1.15,  -5.6911}, {-21.6300, 1.15,   0.5445}, {-24.0301, 1.15, -16.0837}, {-19.2300, 1.15, -11.9267}, {-18.0299, 1.15, 10.9371}, {-10.8297, 1.15, 2.6230}}
	local GauntletTilePos=		  {{-14.4298, 1.15, -7.7696}, {-19.2300, 1.15, -11.9267}, {-12.0297, 1.15,  8.8586}, {-16.8299, 1.15,  4.7015}, {-21.6300, 1.15,   0.5445}, {-26.4302, 1.15,  -3.6126}}
	local ConquerAndHoldTilePos=  {{-32.4304, 1.15, -1.5341}, {-25.2302, 1.15,  -9.8482}}
	for i=1, TileShuffler.getQuantity(), 1 do
		local params={smooth=false}
		if gStates.randomTileOrientation==false then params.rotation={0, 180, 180} else params.rotation={0, math.random(1,6)*60, 180} end
		if gStates.gameScenario=="Volkare's Quest" then params.position=VolQuestTilePos[i] end
		if gStates.gameScenario=="Conquer and Hold" then params.position=ConquerAndHoldTilePos[i] end
		if gStates.gameScenario=="The War of Four" then params.position=warOfFourCountryTilePos[i] end
		if gStates.gameScenario=="The Gauntlet" then params.position=GauntletTilePos[i] end
		if params.position==nil then params.position={pos.x, pos.y+tUp, pos.z} tUp=tUp+0.5 end
		safeTakeObject("SetupGame",TileShuffler,params)
	end
	--Starting country tiles reveal on 1/2/3 second timers. They are part of setup and do not
	--count toward Apocalypse is Here Horseman reveal thresholds.
	safeWaitTime("SetupGame",function() startingMapSetup=false end, 4)
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
			if gStates.gameScenario=="Fury of the Apocalypse Dragon" and getObjectFromGUID("8d7fb9")==nil then
				local ruleBag=getObjectFromGUID("d4a866")
				if ruleBag~=nil then
					safeTakeObject("SetupGame",ruleBag,{guid="8d7fb9",position={41.00,0.96,35.00},rotation={0,180,0},smooth=false})
				end
			end
		end
		return setupGameRaw(player,mouseButton,id,rewindReady)
	end,function() return setupGameErrorContext(player,id,rewindReady) end)
end

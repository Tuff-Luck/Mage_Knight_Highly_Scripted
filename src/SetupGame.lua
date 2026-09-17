-- Game construction and delayed setup: builds the selected game once Start is pressed.

-----------------
-- Setup the Game
-----------------
warningColor={1,0.8,0.2}

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

--Layout everything needed for the game
setupRewindRequestPending=false
function setupGame(player, mouseButton, id, rewindReady)
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
		UI.setAttribute("helpButtonRealText", "Text", "{en}Help{ru}Помощь{zh-cn}帮  助{ko}도움말{es}Ayudar{fr}Aider{pt-br}Ajuda{de}Hilfe")
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
					broadcastToAll("{en}Changed setup Positions to be more central.{ru}Позиции игроков были передвинуты ближе к центру.{zh-cn}更改摆件位置，使其更加集中。{ko}설정의 위치를 좀더 중앙에 맞게 하였습니다.{es}Se cambiaron las posiciones de configuración para que sean más centrales.{fr}Positions de configuration modifiées pour être plus centrales.{pt-br}Mudou a Configuração das posições para ser mais central.{de}Die Aufstellungspositionen wurden geändert, um zentraler zu sein.", {1, 1, 1})
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
			Wait.time(function() Wait.condition(function()
				local mainRules=getObjectFromGUID(r.main)
				local expansionRules=getObjectFromGUID(r.expansion)
				local apocalypseRules=getObjectFromGUID(r.apocalypse)
				if scenarioList[gStates.scenarioRef].scenarioDetails.ruleStates.main~=nil and mainRules~=nil then mainRules.book.setPage(scenarioList[gStates.scenarioRef].scenarioDetails.ruleStates.main-1) end
				if scenarioList[gStates.scenarioRef].scenarioDetails.ruleStates.expansion~=nil and expansionRules~=nil then expansionRules.book.setPage(scenarioList[gStates.scenarioRef].scenarioDetails.ruleStates.expansion-1) end
				if scenarioList[gStates.scenarioRef].scenarioDetails.ruleStates.apocalypse~=nil and apocalypseRules~=nil then apocalypseRules.book.setPage(scenarioList[gStates.scenarioRef].scenarioDetails.ruleStates.apocalypse-1) end
				if mainRules~=nil then mainRules.lock() end
				if expansionRules~=nil then expansionRules.lock() end
				if apocalypseRules~=nil then apocalypseRules.lock() end
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

		--Include Volkare's Camp as a City
		if gStates.volkareCampAsCity==true and gStates.gameScenario~="The War of Four" and gStates.gameScenario~="Volkare's Return" and gStates.gameScenario~="Volkare's Return Blitz" and gStates.gameScenario~="Volkare's Quest" then
			if gStates.gameScenario=="Ultimate Conquest" then
				getObjectFromGUID(GUID.bag.terrain.shuffler).putObject(getObjectFromGUID(GUID.bag.volkare).takeObject({rotation={0.0, 180.0, 180.0}, smooth=false, position={-42.0, 3.0, -17.2}, guid="835c91"}))
			else
				getObjectFromGUID(GUID.bag.terrain.leftCity).putObject(getObjectFromGUID(GUID.bag.volkare).takeObject({rotation={0.0, 180.0, 180.0}, smooth=false, position={-42.0, 3.0, -17.2}, guid="835c91"}))
			end
			getObjectFromGUID(GUID.bag.volkare).takeObject({rotation={0.0, 180.0, 0.0}, position={-57.75, 0.98, -2.95}, smooth=false, guid=volkare.disc})--Volkares Mat
			getObjectFromGUID(GUID.bag.volkare).takeObject({rotation={0.0, 180.0, 0.0}, position={-62.2, 0.98, 0.5}, smooth=false, guid=volkare.terrainHex})--Volkare's Camp Hex
			Wait.time(function()
				getObjectFromGUID(volkare.terrainHex).lock()
				getObjectFromGUID(GUID.bag.volkare).takeObject({rotation={0.0, 180.0, 0.0}, position={getObjectFromGUID(cityScriptZones[volkare.discZone].cityCard).getPosition()[1]+2.2, 1.5, getObjectFromGUID(cityScriptZones[volkare.discZone].cityCard).getPosition()[3]+2.2}, smooth=false, guid=GUID.bag.volkareReminder})
			end, 1)
			getObjectFromGUID(GUID.bag.volkare).takeObject({rotation={0.0, 180.0, 0.0}, position={39.16, 0.97, 35.00}, callback_function=function(spawnedObject) spawnedObject.setScale({7.05, 1.00, 6.51}) end, smooth=false, guid="b2ec85"})--Volkare Level Chart
			getObjectFromGUID(GUID.bag.volkare).takeObject({rotation={0.0,  45.0, 0.0}, position={-57.60, 1.57, -2.45}, smooth=false, guid="9a686a"})--Volker Dice
		end

		--display the help button
		UI.show("HelpButton")
		gStates.help=false

		--Add or destroy the 4 competitive spell cards
		if gStates.coop==0 or gStates.WarOfFourComp==true then
			getObjectFromGUID(GUID.bag.common).takeObject({position={getObjectFromGUID(GUID.deck.spell).getPosition()[1], -2, getObjectFromGUID(GUID.deck.spell).getPosition()[3]},
				guid="9b3c8c", smooth=false, callback_function=function(obj) Wait.frames(function() getObjectFromGUID(GUID.deck.spell).putObject(obj) end) end})--Spells
		end

		--Add or destroy the Advanced action Cards removed for First Reconnaissance
		if gStates.gameScenario~="First Reconnaissance" then
			getObjectFromGUID(GUID.bag.common).takeObject({position={getObjectFromGUID(GUID.deck.action).getPosition()[1], -2, getObjectFromGUID(GUID.deck.action).getPosition()[3]},
				guid="268194", smooth=false, callback_function=function(obj) Wait.frames(function() getObjectFromGUID(GUID.deck.action).putObject(obj) end) end})--Advanced Actions
		end

		--Merge Lost Legion Components
		local lostLegionDecks={[GUID.deck.action]="d7f7a5", [GUID.deck.spell]="8edf39", [GUID.deck.artifact]="00e7f4", [GUID.deck.regularUnit]="892e01", [GUID.deck.eliteUnit]="6d42f9"}
								--12 Advanced Actions, 4 Spells, 8 Artifacts, 8 Regular Units, 8 Elite Units
		if gStates.removeLostLegionExpansion==false then
			for mainDeck, lostLegionDeck in pairs(lostLegionDecks) do
				getObjectFromGUID(GUID.bag.lostLegion).takeObject({position={getObjectFromGUID(mainDeck).getPosition()[1], -2, getObjectFromGUID(mainDeck).getPosition()[3]},
					guid=lostLegionDeck, smooth=false, callback_function=function(obj) Wait.frames(function() getObjectFromGUID(mainDeck).putObject(obj) end) end})
			end
			for a=1, 3, 1 do getObjectFromGUID(GUID.bag.terrain.leftCountry).putObject(getObjectFromGUID(GUID.bag.terrain.lostLegionCountry).takeObject({position={getObjectFromGUID(GUID.bag.terrain.leftCountry).getPosition()[1], -2, getObjectFromGUID(GUID.bag.terrain.leftCountry).getPosition()[3]}, smooth=false})) end--3 Country Tiles
			for a=1, 2, 1 do getObjectFromGUID(GUID.bag.terrain.leftCore).putObject(getObjectFromGUID(GUID.bag.terrain.lostLegionCore).takeObject({position={getObjectFromGUID(GUID.bag.terrain.leftCore).getPosition()[1], -2, getObjectFromGUID(GUID.bag.terrain.leftCore).getPosition()[3]}, smooth=false})) end--2 Core Tiles
		end
		--Delete Lost Legion terrain bags
		getObjectFromGUID(GUID.bag.terrain.lostLegionCountry).destruct()--3 Country Tiles
		getObjectFromGUID(GUID.bag.terrain.lostLegionCore).destruct()--2 Core Tiles

		--Apocalypse Dragon terrain is part of the normal pool unless explicitly removed
		if gStates.removeApocalypseTerrain~=true then
			for a=1, 3, 1 do getObjectFromGUID(GUID.bag.terrain.leftCountry).putObject(getObjectFromGUID(GUID.bag.terrain.apocCountry).takeObject({position={getObjectFromGUID(GUID.bag.terrain.leftCountry).getPosition()[1], -2, getObjectFromGUID(GUID.bag.terrain.leftCountry).getPosition()[3]}, smooth=false})) end--3 Country Tiles
			for a=1, 2, 1 do getObjectFromGUID(GUID.bag.terrain.leftCore).putObject(getObjectFromGUID(GUID.bag.terrain.apocCore).takeObject({position={getObjectFromGUID(GUID.bag.terrain.leftCore).getPosition()[1], -2, getObjectFromGUID(GUID.bag.terrain.leftCore).getPosition()[3]}, smooth=false})) end--2 Core Tiles
		end
		--Delete Apocalypse Dragon Terrain bags
		getObjectFromGUID(GUID.bag.terrain.apocCountry).destruct()--3 Country Tiles
		getObjectFromGUID(GUID.bag.terrain.apocCore).destruct()--2 Core Tiles

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

		--Dragon scenarios destroy sites even when the optional Apocalypse terrain mix is off.
		if apocalypseDragonScenario()==true and getObjectFromGUID(GUID.bag.destroyedSite)==nil then
			getObjectFromGUID(GUID.bag.apocalypseDragon).takeObject({guid=GUID.bag.destroyedSite,position={-43.00,1.02,26.00},rotation={0,180,0},smooth=false}).lock()
		end

		--Set up the Apocalypse Dragon large head tokens for Dragon scenarios.
		if apocalypseDragonScenario()==true then setupApocalypseDragonHeads() end
		if apocalypseIsHereSetup~=nil then apocalypseIsHereSetup() end

		--Merge Ultimate Edition Components
		if gStates.removeBonusCards==false then
			getObjectFromGUID(GUID.bag.common).takeObject({position={getObjectFromGUID(GUID.deck.action).getPosition()[1], -2, getObjectFromGUID(GUID.deck.action).getPosition()[3]},
				guid="96f761", smooth=false, callback_function=function(obj) Wait.frames(function() getObjectFromGUID(GUID.deck.action).putObject(obj) end) end})--Advanced Actions
			getObjectFromGUID(GUID.bag.common).takeObject({position={getObjectFromGUID(GUID.deck.artifact).getPosition()[1], -2, getObjectFromGUID(GUID.deck.artifact).getPosition()[3]},
				guid="085e69", smooth=false, callback_function=function(obj) Wait.frames(function() getObjectFromGUID(GUID.deck.artifact).putObject(obj) end) end})--artifacts
		end

		--include or remove Rise of the Forgemaster
		if gStates.riseOfTheForgemasters>=1 then
			getObjectFromGUID(GUID.bag.forgemaster).takeObject({position={getObjectFromGUID(GUID.deck.action).getPosition()[1], -2, getObjectFromGUID(GUID.deck.action).getPosition()[3]},
				smooth=false, guid="db5f9f", callback_function=function(obj) Wait.frames(function() getObjectFromGUID(GUID.deck.action).putObject(obj) end) end})--Advanced Actions
			getObjectFromGUID(GUID.bag.forgemaster).takeObject({position={getObjectFromGUID(GUID.deck.artifact).getPosition()[1], -2, getObjectFromGUID(GUID.deck.artifact).getPosition()[3]},
				smooth=false, guid="c48f76", callback_function=function(obj) Wait.frames(function() getObjectFromGUID(GUID.deck.artifact).putObject(obj) end) end})--artifacts
			getObjectFromGUID(GUID.bag.forgemaster).takeObject({position={getObjectFromGUID(GUID.deck.spell).getPosition()[1], -2, getObjectFromGUID(GUID.deck.spell).getPosition()[3]},
				smooth=false, guid="cfe630", callback_function=function(obj) Wait.frames(function() getObjectFromGUID(GUID.deck.spell).putObject(obj) end) end})--Spells
			getObjectFromGUID(GUID.bag.forgemaster).takeObject({rotation={0.0, 180.0, 0.0}, position={54.25, 0.98, 18.86}, guid="0a657b", smooth=false}) getObjectFromGUID("0a657b").lock()
			if gStates.riseOfTheForgemasters>=2 then
				getObjectFromGUID(GUID.bag.forgemaster).takeObject({position={getObjectFromGUID(GUID.deck.action).getPosition()[1], -2, getObjectFromGUID(GUID.deck.action).getPosition()[3]},
					smooth=false, guid="c89aea", callback_function=function(obj) Wait.frames(function() getObjectFromGUID(GUID.deck.action).putObject(obj) end) end})--Advanced Actions
				getObjectFromGUID(GUID.bag.forgemaster).takeObject({rotation={0.0, 180.0, 0.0}, position={-75.16, 0.99, -16.00}, guid="5ad84f", smooth=false}) getObjectFromGUID("5ad84f").lock()
				if gStates.riseOfTheForgemasters==3 then
					getObjectFromGUID(GUID.bag.forgemaster).takeObject({position={getObjectFromGUID(GUID.deck.action).getPosition()[1], -2, getObjectFromGUID(GUID.deck.action).getPosition()[3]},
						smooth=false, guid="3b0ed8", callback_function=function(obj) Wait.frames(function() getObjectFromGUID(GUID.deck.action).putObject(obj) end) end})--Advanced Actions
					getObjectFromGUID(GUID.bag.forgemaster).takeObject({position={getObjectFromGUID(GUID.deck.spell).getPosition()[1], -2, getObjectFromGUID(GUID.deck.spell).getPosition()[3]},
						smooth=false, guid="09fd8d", callback_function=function(obj) Wait.frames(function() getObjectFromGUID(GUID.deck.spell).putObject(obj) end) end})--Spells
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
		Wait.time(function()
			--Setup all the decks and shuffles everything
			deckSetup()

			--Cleans up the "All skills" bag
			local allSkills=getObjectFromGUID(GUID.bag.allSkills)
			if gStates.dummyAllSkills==true then
				if gStates.playersRef==5 then
					Wait.time(function()
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

			Wait.time(function()
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
		Wait.frames(function()
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
				if mergeDestination[objGuid]~=nil and gStates.gameScenario~="Life and Death" and gStates.gameScenario~="Custom" and gStates.gameScenario~="The War of Four" and
					((a==1 and gStates.gameScenario~="The Realm of the Dead Blitz") or (a==2 and gStates.gameScenario~="The Hidden Valley Blitz")) then
					mergeBags(objGuid, mergeDestination[objGuid], GUID.bag.tezla)
				else
					if allowed[objGuid]~=nil or gStates.gameScenario=="Life and Death" or gStates.gameScenario=="Custom" or gStates.gameScenario=="The War of Four" or gStates.gameScenario=="Ultimate Conquest" or
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
	Wait.frames(function()
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
	Wait.time(function()
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
					if skip==0 then local obj=CommonBag.takeObject(params).lock() end
				end
				CommonBag.destruct()

				--mirror source
				if (gStates.positionMageKnight[positionOrder[a]]~="nobody" and positionOrder[a]~=5) then
					local obj=getObjectFromGUID("b5a6ce").clone()
					obj.setPosition({-58.25+offsetPosition, 0.98, -28.53})
					Wait.time(function() Wait.condition(function()
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
					if i==3 and (gStates.positionMageKnight[positionOrder[a]]~="nobody" and positionOrder[a]<5) then local destr=PlayerBag.takeObject(params) destr.destruct() skip=1 end--Delete Dummy Inventory when this is a player

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
									local destr=PlayerBag.takeObject(params) destr.destruct() skip=1
								end
							end
						end
					end

					--Skill Refernce Card 1
					if i==5 and (gStates.positionMageKnight[positionOrder[a]]=="nobody" or positionOrder[a]==5) and ((gStates.positionMageKnight[5]=="Volkare" or gStates.playerCount~=1) or gStates.dummyAllSkills==true) then
						local destr=PlayerBag.takeObject(params) destr.destruct() skip=1
					end

					--Skill Refernce Card 2
					if i==6 then
						if (gStates.positionMageKnight[positionOrder[a]]=="nobody" or positionOrder[a]==5) and ((gStates.positionMageKnight[5]=="Volkare" or gStates.playerCount~=1) or gStates.dummyAllSkills==true) then
							local destr=PlayerBag.takeObject(params) destr.destruct() skip=1
						else
							params.callback_function=function(obj) obj.lock() end
							if (gStates.coop==0 or gStates.WarOfFourComp==true) and gStates.positionMageKnight[positionOrder[a]]~="Ymirgh" and gStates.positionMageKnight[positionOrder[a]]~="Malek" and gStates.positionMageKnight[positionOrder[a]]~="Duscenia" and gStates.positionMageKnight[positionOrder[a]]~="Mevok"then--"Mevok"
								params.callback_function=function(ob) obj=ob.setState(1) obj.lock() end
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
								local destr=PlayerBag.takeObject(params) destr.destruct() skip=1
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
								local obj=PlayerBag.takeObject(params)
								skip=1
							else
								local params={position={-69.4, 1.41, -36.5}, rotation={0, 30, 0}, smooth=false, index=0}
								if positionOrder[a]==5 then params.position[1]=params.position[1]-25.2 params.position[3]=params.position[3]+21.1 end
								params.position[1]=params.position[1]+offsetPosition
								for a=1, 3, 1 do
									params.position[1]=params.position[1]-(1.7)
									local obj=PlayerBag.takeObject(params)
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
							local obj=PlayerBag.takeObject(params)
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
								params.callback_function=function(ob) obj=ob.setState(2) obj.lock() end
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
								params.callback_function=function() Wait.frames(function() getObjectFromGUID("bc4dcc").jointTo(getObjectFromGUID(volkare.model), {["type"]="Fixed"}) end, 5) end
							else
								params.position={-12.03, 2.5, 8.86}--Volkare's Quest Guide position
								params.rotation={0.0, 210.0, 0.0}
								params.callback_function=function() Wait.frames(function() getObjectFromGUID("bc4dcc").setState(2) Wait.frames(function() getObjectFromGUID("be2dc2").jointTo(getObjectFromGUID(volkare.model), {["type"]="Fixed"}) end, 5) end, 5) end
							end
							skip=1
						end
					end

					--Volkare is Setup
					if i==13 and (gStates.positionMageKnight[positionOrder[a]]=="nobody" or positionOrder[a]==5) then break end

					if positionOrder[a]==5 and i~=1 then params.position[1]=params.position[1]-25.2 params.position[3]=params.position[3]+21.1 end
					if skip==0 then
						local obj=PlayerBag.takeObject(params)
						if (i==4 or i==5 or i==10 or i==11 or i==13) and gStates.positionMageKnight[positionOrder[a]]~="nobody" and positionOrder[a]<5 then obj.lock() end--lock player board components
						if (i==1 or i==3 or i==4 or i==5 or i==11) and (gStates.positionMageKnight[positionOrder[a]]=="nobody" or positionOrder[a]==5) then obj.lock() end--lock dummy board components
						if i==1 then turnOrder[turnRef].turnOrderTokenGUID=obj.guid end
						if (i==4 and gStates.positionMageKnight[positionOrder[a]]~="nobody" and positionOrder[a]<=4) or (i==4 and gStates.playerCount==1) then
							turnOrder[turnRef].skillBagGUID=obj.guid
							if proxyPlayerActive()==true and turnOrder[turnRef].mage==gStates.positionMageKnight[5] then
								local p=obj.getPosition()
								gStates.proxySkillBagPosition={p[1],p[2],p[3]}
								proxySetupShieldBag(obj)
							end
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
					local obj=PlayerBag.takeObject({guid="32bc89", position={-77.30+offsetPosition, 1.05, -53.65}, smooth=false, setColorTint="", callback_function=function(obj) obj.lock() end})
					local obj=PlayerBag.takeObject({guid="2dbfde", position={-73.90+offsetPosition, 1.05, -53.65}, smooth=false, setColorTint="", callback_function=function(obj) obj.lock() end})
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
		proxySetupReferenceCards()
		Wait.frames(function() proxySetupShieldBag() end,10)
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

	--Add Volkare unit crystals based on Player count and Race Level
	if gStates.gameScenario~="The War of Four" then
		local VolkareUnits=gStates.playerCount+(gStates.volkareRaceLevel-1)
		local PlayerBag=getObjectFromGUID(GUID.bag.volkare).clone()
		local obj=PlayerBag.takeObject({position={37, 1.29, -1.14}, guid="1212f3"})--Crystal Container
		local unitZone={"c75fb0", "f25213", "e393d7", "1821db", "5c85c9", "ff65ef"}
		obj.shuffle()
		for i=1, VolkareUnits, 1 do
			local obj2=obj.takeObject()
			obj2.lock()
			obj2.setPosition({36.0-(4.8*(i-1)), 1.29, -1.15})
			obj2.setRotation({0, 30, 0})
			gStates.volkareUnitCrystals[obj2.getName()]=unitZone[i]
		end
		PlayerBag.destruct()
		obj.destruct()
	end

	--add unit tokens based on Volkare's Level
	gStates.volkareLevel=gStates.cityLevels[#gStates.cityLevels]
	table.remove(gStates.cityLevels, #gStates.cityLevels)
	Wait.time(function() volkareArmy() end, 5)--time for monster stacks to fill

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
			broadcastToAll("{en}Volkare's Army is too large with your setup. You will need to create it when you fight him for the first time{ru}Армия Волкара слишком велика с вашей настройкой. Вам нужно будет создать ее, когда вы сразитесь с ним в первый раз{zh-cn}现在不用设置沃里卡的军队, 你将在首次和他交锋时设置这些{ko}볼케어의 군대 규모가 너무 큽니다. 플레이어가 직접 첫 전투 세팅을 준비해주세요.{es}El ejército de Volkare es demasiado grande con tu configuración. Necesitarás crearlo cuando luches contra él por primera vez.{fr}L'armée de Volkare est trop grande avec votre configuration. Vous devrez le créer lorsque vous le combattrez pour la première fois{pt-br}O exército de Volkare é muito grande com a sua configuração. Você precisará criá-lo quando você for lutar com ele pela primeira vez{de}Volkare's Armee ist mit deiner Aufstellung zu groß. Du musst sie erstellen, wenn du zum ersten Mal gegen ihn kämpfst.", warningColor)
		end
		--Change his models level
		getObjectFromGUID(volkare.model).setCustomObject({diffuse=cityLevelImage[volkare.model][math.floor(gStates.volkareLevel/math.ceil(gStates.volkareLevel/15))]})
		getObjectFromGUID(volkare.model).reload()
		Wait.time(function() getObjectFromGUID(volkare.model).lock() end, 3)
		cityLevelButtons(volkare.model, "Volkar")
	end
end

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
local function standardDeckCycleObject(deckName)
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
local function standardDeckCycleMarkReturned(deckName, card)
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

local function standardDeckCycleShuffleIfReached(deckName, deck, candidateGUID)
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
local function standardDeckCycleClearIfDeckShuffled(deck)
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
	Wait.frames(function()
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
	Wait.frames(function()
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
		Wait.frames(function()
			Wait.condition(function() finishReveal(true) end,function()
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
		local revealPos={cardPos[1],cardPos[2]+0.62,cardPos[3]+1.35}
		local liveBag=getObjectFromGUID(revealGUID)
		if liveBag~=nil then
			liveBag.unlock()
			liveBag.setRotation({0,180,0})
			liveBag.setPosition(revealPos)
			track(liveBag)
		else
			local tokenBag=getObjectFromGUID(GUID.bag.apocalypseQuestTokens)
			local taken=tokenBag~=nil and tokenBag.takeObject({guid=revealGUID,position=revealPos,rotation={0,180,0},smooth=false,callback_function=function(obj) if obj~=nil then obj.unlock() end end}) or nil
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
					track(deck.takeObject({guid=unitGUID,position=tuckPos,rotation={0,180,0},smooth=false,callback_function=function(obj) if obj~=nil then obj.lock() end end}))
				else
					deck.setRotationSmooth({0,180,0})
					deck.setPosition(tuckPos)
					deck.lock()
					track(deck)
				end
			else
				broadcastToAll("Quest setup: Prove Yourself could not find a level II Regular Unit.", {1,0.55,0.2})
			end
		end
	elseif quest.revealSetup=="spell" then
		local deck=standardDeckCycleObject("Spell")
		if deck~=nil then
			standardDeckCycleShuffleIfReached("Spell", deck)
			local tuckPos={cardPos[1], cardPos[2]-0.06, cardPos[3]+1.10}
			if deck.type=="Deck" then
				track(deck.takeObject({position=tuckPos,rotation={0,180,0},smooth=false,callback_function=function(obj) if obj~=nil then obj.lock() end end}))
			elseif deck.type=="Card" then
				deck.setRotationSmooth({0,180,0})
				deck.setPosition(tuckPos)
				deck.lock()
				track(deck)
			end
		else
			broadcastToAll("Quest setup: The Spell Thief could not find the Spell deck.", {1,0.55,0.2})
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
	Wait.frames(function()
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
	Wait.frames(function()
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
		Wait.frames(function()
			Wait.condition(function()
				if finished==true then return end
				finished=true
				if onSettled~=nil then onSettled() end
			end,allResting,10,failRoll)
		end,3)
	end
	--A freshly cloned die may still be in its creation/fall physics. Roll from rest when possible; the
	--timeout still throws it rather than ever leaving a Quest transaction stuck.
	Wait.frames(function() Wait.condition(throwDice,allResting,1.5,throwDice) end,2)
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
			broadcastToAll("Quest roll: the mana die settled without a readable result; try the Quest action again.",{1,0.55,0.2})
			clearRollDie()
			if callback~=nil then callback(nil,questCard) end
			return
		end
		--Leave the face visible briefly before removing the temporary die and applying the result.
		Wait.time(function()
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
			if #results>=count then finish(true) else Wait.frames(rollNext,2) end
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
			end
			warrens[enemyRecord.mage]=nil
			Wait.frames(function()
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
			broadcastToAll("The Goblin Warrens could not find its Goblin infinite bag.",{1,0.55,0.2})
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
		broadcastToAll("Quest reward: The Eager Herbalist Quest token could not be found.", {1,0.55,0.2})
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
		broadcastToAll("Quest reward: The Eager Herbalist had no basic crystal on the card to place on its token.", {1,0.55,0.2})
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
		broadcastToAll("Quest reward: The Eager Herbalist Quest token could not be found.", {1,0.55,0.2})
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
		broadcastToAll("Quest reward: The Eager Herbalist could not find the Quest setup mana die.", {1,0.55,0.2})
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
		broadcastToAll("Quest reward: The Eager Herbalist could not duplicate the Quest setup mana die.", {1,0.55,0.2})
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
			broadcastToAll("Quest reward: The Eager Herbalist mana die settled without a readable result; press Complete to roll again.",{1,0.55,0.2})
			failRoll()
			return
		end
		--Leave the settled face visible briefly before removing the temporary copy and moving the reward.
		Wait.time(function()
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
		broadcastToAll("Quest reward: The Admiring Bard had no Green, Blue or Red crystal on the card, so no Fame was gained.", {1,0.55,0.2})
	end
	return true
end

function apocalypseQuestFlipSiteToken(tokenGUID)
	local token=getObjectFromGUID(tokenGUID)
	if token==nil then
		broadcastToAll("Quest completion: the permanent-site Quest token could not be found.", {1,0.55,0.2})
		return false
	end
	token.unlock()
	token.setRotationSmooth({0,180,180})
	local tokenGUID=token.guid
	Wait.condition(function()
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
		broadcastToAll("Quest reward: no basic crystal can be gained; the Inventory/supply has no available color.", positionToColor(playerIndex))
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
	Wait.frames(function()
		if apocalypseQuestEnemyAttackRotationGeneration[enemyGUID]~=generation then return end
		Wait.condition(function()
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
--has already pressed End Turn. Keep Rewards Claimed locked for a successfully resolved Quest fight
--until that Quest action is pressed, but only for 30 seconds. This is deliberately a fail-safe: if a
--Quest state or scripted reward gets stuck, the players can eventually continue the turn manually.
--Ordinary failed fights must never create this gate: undefeated enemies are face down. The Fog step 2
--is the deliberate exception because its spectral monster cannot be attacked or defeated; completing
--that combat itself is what unlocks Progress.
function apocalypseQuestSetRewardCompletionGate(card,playerIndex,action)
	if card==nil or turnOrder[playerIndex]==nil then return false end
	if gStates.apocalypseQuestRewardCompletionPending==nil then gStates.apocalypseQuestRewardCompletionPending={} end
	gStates.apocalypseQuestRewardCompletionPending[card.guid]={player=playerIndex,serial=gStates.apocalypseQuestTurnSerial or 0,action=action or "Complete",expiresAt=os.time()+30}
	return true
end

function apocalypseQuestRewardCompletionPendingForPlayer(playerIndex)
	if gStates.apocalypseQuestRewardCompletionPending==nil or turnOrder[playerIndex]==nil then return false,nil,nil end
	local serial=gStates.apocalypseQuestTurnSerial or 0
	local now=os.time()
	for cardGUID, record in pairs(gStates.apocalypseQuestRewardCompletionPending) do
		if record~=nil and record.player==playerIndex and record.serial==serial then
			--Compatibility with saves made before the timeout existed: give an old pending gate one final
			--30-second window from the first time it is checked after loading.
			if record.expiresAt==nil then record.expiresAt=now+30 end
			if now>=record.expiresAt then
				gStates.apocalypseQuestRewardCompletionPending[cardGUID]=nil
			elseif getObjectFromGUID(cardGUID)~=nil then
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
	if gStates.preEndTurn==true and turnOrder[gStates.turnNumber]~=nil and steadyTempoUpdateRewardGate~=nil then
		steadyTempoUpdateRewardGate(turnOrder[gStates.turnNumber].seatPos)
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
		Wait.frames(function()
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
				Wait.frames(function() apocalypseQuestAddEnemyAttackBonus(enemyGUID,attackBonus) end,24)
			end
		end,refillImmediate and 3 or 15)
	elseif attackBonus~=nil and attackBonus~=0 then
		Wait.frames(function() apocalypseQuestAddEnemyAttackBonus(enemyGUID,attackBonus) end,8)
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
		broadcastToAll("Quest combat: no Possessed token is available.",{1,0.55,0.2})
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
		Wait.frames(function()
			Wait.condition(attachPossessed,function()
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
		broadcastToAll("Mine of Doom: this mine has multiple crystal colors; all Quest enemies get +1 to every Attack.",positionToColor(playerIndex))
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
		if moved>0 then broadcastToAll("Under Siege: ignore fortification for this Quest fight and add Block 5 during the Block phase.",positionToColor(playerIndex)) end
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
				broadcastToAll("Traitor 2b: this enemy's Fame reward will be halved, rounded up.",positionToColor(playerIndex))
			end
		end
	elseif card.guid=="dd35bb" then
		broadcastToAll("The Fog: skip the Ranged and Siege Attack phase during this Quest combat.",positionToColor(playerIndex))
		moved=apocalypseQuestMoveCardEnemiesToPlayer(card,playerIndex,1)
	elseif card.guid=="783076" then
		moved=apocalypseQuestMoveCardEnemiesToPlayer(card,playerIndex,1)
		if moved>0 and apocalypseQuestCardManaColor(card)=="Black" and gStates.dayRound==true then broadcastToAll("Hunter's Moon: during Day, the black mana token removes Swift from the werewolf for this combat.",positionToColor(playerIndex)) end
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
		Wait.condition(retry,function()
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
		broadcastToAll("Quest effect: the Monastery Advanced Action offer is full; add one Advanced Action manually.",{1,0.55,0.2})
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
	if card~=nil then Wait.condition(function() if getObjectFromGUID(card.guid)~=nil then card.lock() end end,function() return card==nil or card.resting end) end
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
	Wait.time(function() rewindTransactionFinish("Quest resolve "..tostring(card.guid).." "..tostring(playerIndex)) end,0.5)
end

function apocalypseQuestFinishGuardDutyChoice(card,playerIndex,distance)
	if card==nil or turnOrder[playerIndex]==nil then return end
	if gStates.apocalypseQuestCombatChoice~=nil then gStates.apocalypseQuestCombatChoice[card.guid]=nil end
	apocalypseQuestClearRewardCompletionGate(card,playerIndex)
	broadcastToAll(tostring(turnOrder[playerIndex].mage).." completed Guard Duty: distance "..tostring(distance or "?")..", two chosen mana crystals.",positionToColor(playerIndex))
	apocalypseQuestFinishCompletedCard(card)
	Wait.time(function() rewindTransactionFinish("Quest resolve "..tostring(card.guid).." "..tostring(playerIndex)) end,0.5)
end

function apocalypseQuestFinishGuardDutyGold(card,playerIndex,distance)
	if card==nil or turnOrder[playerIndex]==nil then return end
	if gStates.apocalypseQuestCombatChoice~=nil then gStates.apocalypseQuestCombatChoice[card.guid]=nil end
	apocalypseQuestClearRewardCompletionGate(card,playerIndex)
	broadcastToAll(tostring(turnOrder[playerIndex].mage).." completed Guard Duty: distance "..tostring(distance or "?")..", random mana reward resolved.",positionToColor(playerIndex))
	apocalypseQuestFinishCompletedCard(card)
	Wait.time(function() rewindTransactionFinish("Quest resolve "..tostring(card.guid).." "..tostring(playerIndex)) end,0.5)
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
		Wait.time(function()
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
	Wait.frames(function() if getObjectFromGUID(card.guid)~=nil then apocalypseQuestInterfaceAdd(card,true) end end,2)
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
		--These enemies are created directly at the card's known future offer position while the card moves.
		apocalypseQuestPlaceEnemy(card,"gray",true,-0.55)
		apocalypseQuestPlaceEnemy(card,"gray",true,0.55)
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
		broadcastToAll("Mine of Doom reward: gain an Artifact.",positionToColor(playerIndex))
	elseif card.guid=="b401dc" then
		if key=="1" then
			local token=getObjectFromGUID("7e4e4c")
			if token~=nil then apocalypseQuestHighlightMarker(token) end
			broadcastToAll("A Very Personal Quest: recruit an eligible Unit here for free and place the highlighted Quest token on that Unit.",positionToColor(playerIndex))
		elseif key=="2" then
			if gStates.apocalypseQuestVeryPersonalSuccess==nil then gStates.apocalypseQuestVeryPersonalSuccess={} end
			gStates.apocalypseQuestVeryPersonalSuccess[card.guid]=true
			broadcastToAll("A Very Personal Quest: the protected Unit survived the Mage Tower rescue; its Quest marker will be returned.",positionToColor(playerIndex))
		end
	elseif card.guid=="82a935" and key=="2a" then
		apocalypseQuestRestoreBurnedMonastery(card,playerIndex)
		apocalypseQuestAddAdvancedActionToUnitOffer()
		apocalypseQuestGainReputation(playerIndex,"The Burned Monastery")
	elseif card.guid=="8455b5" then
		if key=="1" then
			broadcastToAll("The Admiring Bard: defeat an enemy token to continue. Non-Red/non-Tan = 2a (Green), Tan = 2b (Blue), Red = 2c (Red).",positionToColor(playerIndex))
		elseif key=="2a" then
			apocalypseQuestPlaceCrystalOnCard(card,"Green",0,-0.55,"The Admiring Bard")
			broadcastToAll("The Admiring Bard: return to a Village, Monastery, City or Oasis to finish the song.",positionToColor(playerIndex))
		elseif key=="2b" then
			apocalypseQuestPlaceCrystalOnCard(card,"Blue",0,-0.55,"The Admiring Bard")
			broadcastToAll("The Admiring Bard: return to a Village, Monastery, City or Oasis to finish the song.",positionToColor(playerIndex))
		elseif key=="2c" then
			apocalypseQuestPlaceCrystalOnCard(card,"Red",0,-0.55,"The Admiring Bard")
			broadcastToAll("The Admiring Bard: return to a Village, Monastery, City or Oasis to finish the song.",positionToColor(playerIndex))
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
				broadcastToAll("Cursed: place the chosen adjacent Hero's Shield on this Quest before using Pass the curse on.",positionToColor(playerIndex))
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
		broadcastToAll("Tomb of the Lost King reward: gain an Artifact.",positionToColor(playerIndex))
	elseif card.guid=="77bbac" and key=="2" then
		broadcastToAll("The Child Seer: resolve the destiny matching the mana token on your Shield (or pay matching mana to choose another destiny).",positionToColor(playerIndex))
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
			broadcastToAll("The Fog reward: gain an Artifact.",positionToColor(playerIndex))
		end
	elseif card.guid=="783076" and key=="2" and finalCompletion==true then
		broadcastToAll("Hunter's Moon reward: gain an Artifact.",positionToColor(playerIndex))
	elseif card.guid=="a6d5cc" and key=="1" then
		gStates.apocalypseQuestUnderSiegeReady=nil
		gStates.apocalypseQuestUnderSiegeStep2={player=playerIndex,mage=turnOrder[playerIndex].mage,serial=gStates.apocalypseQuestTurnSerial or 0,movedSerial=nil}
		apocalypseQuestPlaceEnemy(card,"gray",true,-0.45)
		apocalypseQuestPlaceEnemy(card,"purple",true,0.45)
	elseif card.guid=="bbd087" then
		if key=="1" then
			broadcastToAll("Noble Warrior: the companion Quest marker is now at this site.",positionToColor(playerIndex))
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
	broadcastToAll("Stray: its once-per-round Quest token refreshed for the new round.",{1,1,0.5})
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
			broadcastToAll("Quest cleanup complete. The Quest offer will refill normally as player turns begin.",{1,1,0.5})
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
			Wait.frames(function() cleanNext(index+1) end,1)
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
				apocalypseBag.takeObject({guid=marker.guid, position=apocalypseQuestScorePosition(0, seatPos), rotation={0, 180, 0}, smooth=false, callback_function=function(obj)
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
	Wait.frames(function()
		Wait.condition(finish,function()
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
	--Once this branch has an outcome, keep it until Complete/Fail is actually pressed. The 30-second
	--Rewards Claimed gate is only a fail-safe and must not erase which assault Quest 10 is resolving.
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
	--Start the normal 30-second fail-safe when the combat outcome is known, not when 1A first sends the
	--Hero toward the Keep. A real Keep assault normally takes far longer than 30 seconds to play.
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
	--1A commits the player to resolving this Keep assault. Do not start the 30-second Rewards Claimed
	--fail-safe yet: the combat itself can easily take longer than that. The outcome gate is created at
	--the rewards boundary after success/failure can actually be determined.
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
			Wait.frames(function() Wait.condition(finishMove,function() local obj=getObjectFromGUID(avatarGUID) return obj==nil or obj.resting end,4.0,finishMove) end,2)
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
	if card~=nil then Wait.frames(function() local live=getObjectFromGUID("a6d5cc") if live~=nil then apocalypseQuestInterfaceAdd(live,true) end end,2) end
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
		broadcastToAll("A Very Personal Quest: the marked Unit was disbanded when the Quest left play.",{1,1,0.5})
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
		Wait.frames(function()
			Wait.condition(function() apocalypseQuestRestoreRaisedAvatar(playerIndex) end,function()
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
	Wait.frames(function() apocalypseQuestRefreshOfferButtons() end,3)
	Wait.frames(function() apocalypseQuestRefreshOfferButtons() end,60)
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
function apocalypseQuestTakePlayerShield(playerIndex, position)
	local playerDetails=turnOrder[playerIndex]
	if playerDetails==nil then return nil end
	for _, mageDetails in pairs(mageKnights) do
		if mageDetails.mage==playerDetails.mage then
			local shieldBag=getObjectFromGUID(mageDetails.shieldContainer)
			if shieldBag~=nil then
				return shieldBag.takeObject({position=apocalypseQuestRaisedPiecePosition(position),rotation={0,180,0},smooth=true})
			end
			break
		end
	end
	return nil
end
function apocalypseQuestTakeNeutralShield(position)
	local shieldBag=getObjectFromGUID(GUID.bag.neutralShield)
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
		Wait.condition(function()
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
	Wait.condition(function()
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
		Wait.condition(function()
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
		Wait.frames(function() local questCard=getObjectFromGUID(cardGUID) if questCard~=nil then apocalypseQuestInterfaceAdd(questCard) end end, 3)
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
			Wait.frames(function()
				local live=getObjectFromGUID(cardGUID)
				if live~=nil then onSettled(live) end
			end,1)
		end
		if offerRefresh==true then Wait.frames(function() apocalypseQuestOfferRefresh() end,1) end
	end
	Wait.frames(function()
		Wait.condition(finishMove,function()
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
local function apocalypseQuestScoreMarkerPlayerIndex(guid)
	if guid==nil then return nil end
	for playerIndex,details in ipairs(turnOrder or {}) do
		if details.questScoreGUID==guid then return playerIndex end
	end
	return nil
end
local function apocalypseQuestDisableScoring()
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
local function apocalypseQuestRestoreScoreMarker(playerIndex, announce)
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
	Wait.frames(function() apocalypseQuestRefreshReminderCards() end, 3)
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
		Wait.frames(function()
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
				Wait.frames(function() onComplete(liveDeck~=nil) end,1)
			end
		end,2)
	end
	if attachmentsClear()==true then finishBottomDeck()
	else Wait.condition(finishBottomDeck,attachmentsClear,2.0,finishBottomDeck) end
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
		Wait.condition(function()
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
		if delay~=nil and delay>0 then Wait.time(function() rewindTransactionFinish(questRewindOwner) end,delay)
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
		apocalypseQuestOfferMoveToLeft(card)
		broadcastToAll(tostring(turnOrder[playerIndex].mage).." progressed a Quest ("..tostring(option.key)..").", positionToColor(playerIndex))
		finishQuestResolution(1.0)
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
			Wait.condition(retry,function()
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
				Wait.time(function() rewindTransactionFinish("Quest resolve "..tostring(card.guid).." "..tostring(playerIndex)) end,0.5)
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
		local neutralBag=getObjectFromGUID(GUID.bag.neutralShield)
		if neutralBag==nil then
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
			Wait.frames(function() if gStates.turnNumber==refreshTurn then apocalypseQuestOfferRefresh(attempt+1) end end,3)
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
				Wait.condition(function() refillWaiting=false finishQuestOfferRefill() end,offerSettled,15,function()
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
		if deferredRefresh==true then Wait.frames(function() apocalypseQuestOfferRefresh() end,1) end
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
			if attempt<12 then Wait.frames(function() drawQuestReplacement(attempt+1) end, 3)
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
			Wait.frames(function() finishQuestOfferRefill() end,2)
			return
		end
		if liveDeck.resting==false or liveDeck.spawning==true then
			if attempt<12 then Wait.frames(function() drawQuestReplacement(attempt+1) end, 3)
			else print("QUEST REFILL ERROR: Quest deck did not settle after manual re-stack.") finishQuestOfferRefill() end
			return
		end
		local okObjects,objects=pcall(function() return liveDeck.getObjects() end)
		local topGUID=okObjects==true and objects~=nil and objects[1]~=nil and objects[1].guid or nil
		if topGUID==nil then
			if attempt<12 then Wait.frames(function() drawQuestReplacement(attempt+1) end, 3)
			else print("QUEST REFILL ERROR: Quest deck had no readable top card.") finishQuestOfferRefill() end
			return
		end
		local okTake,takenOrErr=pcall(function()
			return liveDeck.takeObject({guid=topGUID,position=pos,rotation={0,180,0},smooth=true})
		end)
		local taken=okTake==true and takenOrErr or nil
		if taken==nil then
			if attempt<20 then Wait.frames(function() drawQuestReplacement(attempt+1) end,3)
			else
				print("QUEST REFILL ERROR: takeObject returned no Quest card after retries: "..tostring(okTake==true and "nil" or takenOrErr))
				gStates.apocalypseQuestOfferRefreshPending=true
				finishQuestOfferRefill()
			end
		else
			gStates.apocalypseQuestOfferDrawSerial=currentQuestTurnSerial
			taken.lock()
			refillMovedGUIDs[taken.guid]=true
			Wait.frames(function() finishQuestOfferRefill() end,2)
		end
	end
	--A shuffle rebuilds the same internal collection, so always give it a few frames before drawing.
	if shuffled==true then Wait.frames(function() drawQuestReplacement(1) end, 3) else drawQuestReplacement(1) end
	--Failsafe only: normal completion is driven by the tracked smooth-move set above.
	Wait.frames(function()
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
			deck.takeObject({position=apocalypseQuestOfferPosition(offer),rotation={0,180,0},smooth=false,callback_function=function(card)
				if card~=nil then card.lock() print("QUEST SETUP DRAW: slot "..tostring(slot).." <- "..tostring(apocalypseQuestName(card)).." ["..tostring(card.guid).."].") end
				Wait.frames(function() apocalypseQuestInterfaceAdd(card) end,2)
			end})
		end
	end
	local returnReserved
	returnReserved=function(index)
		if index>#reserved then Wait.frames(dealQuestOffer,2) return end
		local deck=currentQuestDeck()
		local card=reserved[index]
		if deck==nil or card==nil or (card.isDestroyed~=nil and card.isDestroyed()==true) then return end
		card.unlock()
		deck.putObject(card)
		Wait.frames(function() returnReserved(index+1) end,1)
	end
	--Instant movement is fast, but serialize each extraction so TTS always has a stable Quest Deck object.
	local takeReserved
	takeReserved=function(index)
		if index>startingCount then
			local deck=currentQuestDeck()
			if deck==nil then return end
			deck.shuffle()--Shuffle the unreserved starting Quests in with all other Quests
			Wait.frames(function() returnReserved(1) end,2)
			return
		end
		local deck=currentQuestDeck()
		if deck==nil then return end
		deck.takeObject({guid=startingQuests[index],position={questDeckPosition[1],4.00+(index*0.10),questDeckPosition[3]},rotation={0,180,180},smooth=false,callback_function=function(card)
			if card==nil then return end
			card.lock()
			reserved[#reserved+1]=card
			Wait.frames(function() takeReserved(index+1) end,1)
		end})
	end
	takeReserved(1)
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
			apocalypseBag.takeObject({guid=GUID.bag.apocalypseQuestTokens, position={46.84, 1.00, 13.61}, rotation={0, 180, 0}, smooth=true, callback_function=function(_) apocalypseQuestTokenBagSetup() end})
			apocalypseBag.takeObject({guid="b26e9b", position={51.04, 0.98, 13.61}, rotation={0, 180, 0}, smooth=true})
			apocalypseBag.takeObject({guid="4ce329", position={55.24, 0.98, 13.61}, rotation={0, 180, 0}, smooth=true})
			if getObjectFromGUID(GUID.bag.neutralShield)==nil then apocalypseBag.takeObject({guid=GUID.bag.neutralShield,position={8.00,1.03,16.00},rotation={0,180,0},smooth=true}) end--Infinite neutral Shield bag for Quest progress/abandonment
			--Clone each active Mage Knight's existing infinite Shield bag immediately to the right of Neutral.
			--Neutral is x=59.55; active players pack left-to-right at +1.70 x with no gaps for empty seats.
			--The player-board copies survive setup, so this does not depend on the temporary Mage Knight setup bags.
			local questShieldSlot=1
			for seatPos=1, 4, 1 do
				local mage=gStates.positionMageKnight[seatPos]
				if mage~=nil and mage~="nobody" then
					for _, details in pairs(mageKnights) do
						if details.mage==mage then
							local source=getObjectFromGUID(details.shieldContainer)
							if source~=nil then
								local bag=source.clone()
								bag.setPositionSmooth({59.55+(questShieldSlot*1.70), 1.03, 13.60})
								bag.setRotationSmooth({0, 180, 0})
								bag.lock()
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
			apocalypseBag.takeObject({guid=GUID.deck.apocalypseQuest, position={46.84, 1.14, 8.06}, rotation={0, 180, 180}, smooth=true, callback_function=function(obj) Wait.frames(function() apocalypseQuestDeckSetup(obj) end, 2) end})
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
	unitLayoutWait[seatPos]=Wait.time(function()
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
	Wait.condition(function()
		Wait.frames(function()
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
	if higherLevelUIPause==true then Wait.frames(function()
		if gStates.magesSetup==true then
			--Create an interface for all players in the game
			for a=1, #turnOrder, 1 do
				if turnOrder[a].mage~=gStates.positionMageKnight[5] then
					if turnOrder[a].seatPos>0 then
						UI.setAttribute("Mage"..turnOrder[a].seatPos.."levelText", "Text", joinLang({"{en}Start at Level {ru}Начать с уровнем {zh-cn}起始等级：{ko}시작 레벨: {es}Empezar en el Nivel {fr}Début Niveau {pt-br}Iníciar no Nível {de}Starte auf Level ", turnOrder[a].level}))
						UI.setAttribute("Mage"..turnOrder[a].seatPos.."influenceText", "Text", joinLang({turnOrder[a].influence, "{en} Influence Per Level{ru} Влияние(я) за ур.{zh-cn}每级构筑点数{ko} 영향력*레벨{es} Influencia por Nivel{fr} Influence par Niveau{pt-br} Influência por Nível{de} Einfluss pro Stufe"}))
						UI.setAttribute("Mage"..turnOrder[a].seatPos.."influenceTotalText", "Text", joinLang({"{en}Influence to Spend : {ru}Доступно влияния: {zh-cn}影响力额度：{ko}주어진 영향력: {es}Influencia para Gastar : {fr}Influence à Dépenser : {pt-br}Influência para Gastar : {de}Einfluss zum Ausgeben : ", (turnOrder[a].influence*turnOrder[a].level)+gStates.bondsOfLoyalty[a]}))
						UI.setAttribute("Mage"..turnOrder[a].seatPos.."AdvancedActionFreeText", "Text", joinLang({math.floor((turnOrder[a].level-1)/2), "{en} Free Advanced Action(s){ru} Бесплатное(ых) особое(ых) действие(ия/ий){zh-cn} 張免費的高級行動卡{ko}장의 무료 상급 액션{es} Acción Avanzada Gratuita{fr} Action Avancée Gratuite{pt-br} Cartas de Ação Avançadas Gratuitas{de} Freie Fortgeschrittene Aktion(en)"}))
						UI.setAttribute("Mage"..turnOrder[a].seatPos.."NameText", "Text", translateWord[turnOrder[a].mage])
						UI.setAttribute("Mage"..turnOrder[a].seatPos.."NamePanel", "Color", positionToColor(a))
						if gStates.showboards[a]==true then
							turnOrder[a].level=2
							if gStates.gameScenario=="Fast Forwarded Conquest" then turnOrder[a].level=6 end
							if gStates.gameScenario=="The Lost Relic Blitz" then turnOrder[a].level=3 end
							gStates.showboards[a]=false
							playArea=getObjectFromGUID(turnOrder[a].playerBoardGUID).getPosition()
							Player[positionToColor(a)].lookAt({position={playArea[1], playArea[2], playArea[3]+2}, pitch=65, yaw=0, distance=28})
							UI.setAttribute("Mage"..turnOrder[a].seatPos.."levelText", "Text", joinLang({"{en}Start at Level {ru}Начать с уровнем {zh-cn}起始等级：{ko}시작 레벨: {es}Empezar en el Nivel {fr}Début Niveau {pt-br}Iníciar no Nível {de}Starte auf Level ", turnOrder[a].level}))
							UI.setAttribute("Mage"..turnOrder[a].seatPos.."influenceTotalText", "Text", joinLang({"{en}Influence to Spend : {ru}Доступно влияния: {zh-cn}影响力额度：{ko}주어진 영향력: {es}Influencia para Gastar : {fr}Influence à Dépenser : {pt-br}Influência para Gastar : {de}Einfluss zum Ausgeben : ", (turnOrder[a].influence*turnOrder[a].level)+gStates.bondsOfLoyalty[a]}))
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
						Wait.frames(function()
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
									broadcastToAll(joinLang({"{en}Warning: {ru}Внимание: {zh-cn}警告：{ko}경고: {es}Advertencia: {fr}Attention : {pt-br}Aviso: {de}Warnung: ", translateWord[turnOrder[a].mage], "{en} has selected more Units than available Command tokens. One or more Units cannot be placed.{ru} выбрал(а) больше отрядов, чем доступно жетонов командования. Один или несколько отрядов нельзя разместить.{zh-cn}选择的部队数量超过了可用的指挥标记数量。一个或多个部队无法放置。{ko}이 사용 가능한 지휘 토큰보다 많은 유닛을 선택했습니다. 하나 이상의 유닛을 배치할 수 없습니다.{es} ha seleccionado más Unidades que fichas de Mando disponibles. Una o más Unidades no pueden colocarse.{fr} a sélectionné plus d'Unités que de jetons de Commandement disponibles. Une ou plusieurs Unités ne peuvent pas être placées.{pt-br} selecionou mais Unidades do que Fichas de Comando disponíveis. Uma ou mais Unidades não podem ser colocadas.{de} hat mehr Einheiten als verfügbare Befehlsplättchen gewählt. Eine oder mehrere Einheiten können nicht platziert werden."}), positionToColor(a))
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
								UI.setAttribute("Mage"..turnOrder[a].seatPos.."AdvancedActionCostText", "Text", joinLang({turnOrder[a].levelingStats.AdvancedActions, "{en} Advanced Action(s) : {ru} Особое(ых) действие(ия/ий): {zh-cn} 張高級行動卡：{ko}장의 상급 액션 : {es} Acción Avanzada : {fr} Action Avancée : {pt-br} Ações Avançadas : {de} Fortgeschrittene Aktion(en) : ", turnOrder[a].levelingStats.AdvancedActionsWorth}))
								UI.setAttribute("Mage"..turnOrder[a].seatPos.."RegularUnitCostText", "Text", joinLang({turnOrder[a].levelingStats.RegularUnits, "{en} Regular Unit(s) : {ru} Обычный(ых) отряд(а/ов): {zh-cn} 支常规部队：{ko}개의 일반 유닛 : {es} Unidad(es) Regulares : {fr} Unité(s) Régulières : {pt-br} Unidade(s) Regulares : {de} Normale Einheit(en) : ", turnOrder[a].levelingStats.RegularUnitsWorth}))
								UI.setAttribute("Mage"..turnOrder[a].seatPos.."SpellCostText", "Text", joinLang({turnOrder[a].levelingStats.Spells, "{en} Spell(s) : {ru} Заклинание(я/ий): {zh-cn} 張法術卡：{ko}장의 마법 : {es} Hechizo(s) : {fr} Sort(s) : {pt-br} Feitiços : {de} Zauber : ", turnOrder[a].levelingStats.SpellsWorth}))
								UI.setAttribute("Mage"..turnOrder[a].seatPos.."ArtifactCostText", "Text", joinLang({turnOrder[a].levelingStats.Artifacts, "{en} Artifact(s) : {ru} Артефакт(а/ов): {zh-cn} 張神器卡：{ko}장의 유물 : {es} Artefacto(s) : {fr} Artefact(s) : {pt-br} Artefatos : {de} Artefakt(e) : ", turnOrder[a].levelingStats.ArtifactsWorth}))
								UI.setAttribute("Mage"..turnOrder[a].seatPos.."CrystalCostText", "Text", joinLang({turnOrder[a].levelingStats.Crystals, "{en} Mana Crystal(s) : {ru} Кристалл(а/ов) маны: {zh-cn} 顆魔晶：{ko}개의 수정 : {es} Cristales de Maná : {fr} Cristaux de Mana : {pt-br} Cristais de Mana : {de} Manakristall(e) : ", turnOrder[a].levelingStats.CrystalsWorth}))
								UI.setAttribute("Mage"..turnOrder[a].seatPos.."RemainingText", "Text", joinLang({"{en}Remaining : {ru}Остаток: {zh-cn}剩餘：{ko}남은 영향력 : {es}Restante : {fr}Restant : {pt-br}Restando : {de}Verbleibend : ", remain}))
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
			UI.setAttribute("Mage"..playerPosition.."CompleteText", "text", "{en}Complete{ru}Завершить{zh-cn}完成{ko}완료{es}Completo{fr}Compléter{pt-br}Completo{de}Fertig")
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
					Wait.frames(function() Wait.condition(function()
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

local function higherLevelSkillAreaPlayer(position)
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
						UI.setAttribute("Mage"..playerPosition.."influenceTotalText", "Text", joinLang({"{en}Influence to Spend : {ru}Доступно влияния: {zh-cn}影响力额度：{ko}주어진 영향력: {es}Influencia para Gastar : {fr}Influence à Dépenser : {pt-br}Influência para Gastar : {de}Einfluss zum Ausgeben : ", (turnOrder[a].influence*turnOrder[a].level)+gStates.bondsOfLoyalty[a]}))
						break
					end
				end
				broadcastToAll("{en}Two more Regular units and 5 influence given to Norowas.{ru}Два дополнительных обычных отряда и 5 влияния даны Норовас{zh-cn}给诺罗瓦斯增加两个常规部队供应和5影响力{ko}노로워즈에게 일반 유닛 두 개와 영향력 5가 추가 지급되었습니다. {es}Dos unidades regulares más y 5 influencia dadas a Norowas.{fr}Deux autres unités régulières et 5 d'influence donnés à Norowas.{pt-br}2 unidades Regulares a mais e 5 influência dadas a Norowas{de}Zwei weitere reguläre Einheiten und 5 Einfluss an Norowas gegeben.", {1,1,0.5})
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
				Wait.time(afterLoad, 0.1)
			end
		end
	end
end

----------------
-- Delayed Setup
----------------
--destroy all the setup bags
function afterLoad()
	--Deploy the scenario map
	mapSetup()
	if apocalypseDragonScenario()==true then Wait.time(function() positionApocalypseDragonHeads() end,2) end
	Wait.time(function()
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
		Wait.time(function()
            if getObjectFromGUID("e7de55")~=nil then SendDataRequest("skip", "-1", "SendDataRequestYes") end
			--UI.setAttribute("SendDataRequest", "active", "true")
		end, 400)--time in seconds, 1800=1/2 hour, 3600=1 hour 400
		Wait.time(function() straightenCrooked() end, 10)
		dealStartingHandsWhenReady()
	end, 0.7)
end

--Layout starting map tiles
local firstTile=nil
local startingMapSetup=false
local startingMapTiles={}
--The Dragon data table is assigned later in the file, but Fury map setup needs its GUIDs here.
local apocalypseDragon

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

--Fury of the Apocalypse Dragon uses the small one-space Dragon marker rather than the normal
--three-space figure. The marker (42b581) is an attachment inside the Dragon model in the Apocalypse
--component bag, so pull the model out long enough to detach the marker before that setup bag is deleted.
function furyDragonExtractMarker(target)
	if gStates==nil or gStates.gameScenario~="Fury of the Apocalypse Dragon" or apocalypseDragon==nil then return nil end
	local marker=getObjectFromGUID(apocalypseDragon.furyMarker)
	if marker==nil then
		local bag=getObjectFromGUID(GUID.bag.apocalypseDragon)
		if bag==nil then return nil end
		local dragon=bag.takeObject({guid=apocalypseDragon.model,position={-65.5,4,22},rotation={0,180,180},smooth=false})
		if dragon~=nil then
			local function attachmentParent(parent)
				if parent==nil or parent.getAttachments==nil then return nil end
				for _,attachment in ipairs(parent.getAttachments() or {}) do
					if attachment.guid==apocalypseDragon.furyMarker then return parent end
					local found=attachmentParent(attachment)
					if found~=nil then return found end
				end
				return nil
			end
			local parent=attachmentParent(dragon)
			if parent~=nil then
				for _,detached in ipairs(parent.removeAttachments() or {}) do
					if detached.guid==apocalypseDragon.furyMarker then marker=detached
					else parent.addAttachment(detached) end
				end
			end
			bag.putObject(dragon)
		end
	end
	if marker~=nil then
		marker.unlock()
		marker.setRotation({0,180,0})
		marker.setPosition(target)
	end
	return marker
end

function furyDragonSetupLair()
	if gStates==nil or gStates.gameScenario~="Fury of the Apocalypse Dragon" then return false end
	local tile=getObjectFromGUID(GUID.tile.core01)
	if tile==nil then return false end
	local bearing="240"
	local xy=angleToXY(tile,bearing)
	local hexPos={xy[1],1.00,xy[2]}
	local markerPos={xy[1],1.18,xy[2]}
	gStates.apocalypseDragonLairRevealed=true
	gStates.apocalypseDragonLair={tileGUID=tile.guid,hexes={{bearing=bearing,position=hexPos}},position=markerPos,rotation={0,180,0},fury=true,cityHexKey=tile.guid.."|"..bearing}
	--Core tile 1's Tomb is the Dragon Lair in Fury and no longer counts as a Tomb.
	terrainTiles[tile.guid].hexFeature[bearing]=""
	gStates.hexOverideSave=gStates.hexOverideSave or {}
	gStates.hexOverideSave[tile.guid]=gStates.hexOverideSave[tile.guid] or {}
	gStates.hexOverideSave[tile.guid][bearing]=""
	local marker=furyDragonExtractMarker(markerPos)
	if marker==nil then
		broadcastToAll("Fury setup could not deploy the single-space Apocalypse Dragon marker (42b581).",warningColor)
		return false
	end
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
	broadcastToAll("Fury of the Apocalypse Dragon: Elite Units are included in this Round's Unit Offer.",{1,1,0.5})
	return true
end

function mapSetup()
	startingMapSetup=true
	startingMapTiles={}
	local TileShuffler=		getObjectFromGUID(GUID.bag.terrain.shuffler)
	local CityTileStack=	getObjectFromGUID(GUID.bag.terrain.leftCity)
	local CoreTileStack=	getObjectFromGUID(GUID.bag.terrain.leftCore)
	local CountryTileStack=	getObjectFromGUID(GUID.bag.terrain.leftCountry)
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
		Wait.frames(function() getObjectFromGUID(startTerrain.open).lock() getObjectFromGUID(portal.terrainHex).lock() end, 5)
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
	--Remove easier terrain before Ultimate Conquest moves the remaining country tiles into its mixed stack.
	--Against the Horsemen requires Countryside 1 as its central tile, so a stale/random saved flag is ignored here too.
	if gStates.removeTerrain==true and not againstHorsemenMap then
		for _, easyTileGUID in ipairs({GUID.tile.country01, GUID.tile.country02}) do
			local easyTile=CountryTileStack.takeObject({guid=easyTileGUID})
			if easyTile~=nil then getObjectFromGUID(trashCan).putObject(easyTile) end
		end
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
		local obj=CityTileStack.takeObject(params)--take from the City Tile Bag
		if furyMap and obj~=nil then furyRevealGUIDs[#furyRevealGUIDs+1]=obj.guid end
		if noShuffle==0 then TileShuffler.putObject(obj) end--Place in the Core Tile Shuffler if it is shuffled
		if gStates.gameScenario=="Ultimate Conquest" and i==4 then break end
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
			local coreTile=CoreTileStack.takeObject(params)
			if coreTile==nil then print("HORSEMEN SETUP ERROR: Core tile "..tostring(i).." was not available") startingMapSetup=false return end
			againstHorsemenCoreTileGUIDs[i]=coreTile.guid
		elseif furyMap then
			params.position=furyCoreTilePos[i]
			params.rotation={0,gStates.randomTileOrientation==true and math.random(1,6)*60 or 180,180}
			local coreTile=CoreTileStack.takeObject(params)
			if coreTile==nil then print("FURY SETUP ERROR: Core tile "..tostring(i).." was not available") startingMapSetup=false return end
			furyRevealGUIDs[#furyRevealGUIDs+1]=coreTile.guid
		else
			TileShuffler.putObject(CoreTileStack.takeObject(params))--Core Tile Shuffler
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
				TileShuffler.putObject(CountryTileStack.takeObject(params))
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
		TileShuffler.takeObject(params)
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
					Wait.time(function() gStates.firstStarted=true firstTile=obj.guid obj.flip() end,1)
				end
			end
		elseif furyMap then
			local slot=furyCountrySlots[i]
			params.position=slot.position
			params.rotation={0,gStates.randomTileOrientation==true and math.random(1,6)*60 or 180,180}
		end
		local countryTile=CountryTileStack.takeObject(params)
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
		if furyDragonSetupLair()~=true then print("FURY SETUP ERROR: could not establish the Dragon Lair") end
		--Like the Volkare's Quest opening tiles, reveal from a settled face-down state in steps. This makes
		--each reveal re-enter the normal terrain population path instead of arriving already face up.
		for revealIndex,revealGUID in ipairs(furyRevealGUIDs) do
			local guid=revealGUID
			Wait.time(function()
				local tile=getObjectFromGUID(guid)
				if tile~=nil and tile.is_face_down==true then tile.flip() end
			end,revealIndex)
		end
		Wait.time(function() startingMapSetup=false fakeDropAvatar() end,#furyRevealGUIDs+2)
		return
	end

	--The predefined terrain is now complete. Keep Mage Knights physically parked on the Portal card,
	--but make Country01's central Glade their shared logical start, then place the four hidden Horsemen.
	if againstHorsemenMap then
		againstHorsemenSetStartingAvatarLocations()
		againstHorsemenSetupTokens(againstHorsemenCoreTileGUIDs,againstHorsemenCoreTilePos)
		Wait.time(function()
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
		return TileShuffler.takeObject(params)
	end
	local rot={}
	if scenarioList[gStates.scenarioRef][gStates.playersRef].mapShape:sub(5,5)=="W" then
		if gStates.randomTileOrientation==false then rot={0, 180, 180} else rot={0, math.random(1,6)*60, 180} end
		takeStartingCountry({position={-25.2302, 1.07, -9.8482}, rotation=rot, smooth=false, callback_function=function(obj) Wait.time(function() gStates.firstStarted=true firstTile=obj.guid obj.flip() end, 1) end})
		if gStates.randomTileOrientation==false then rot={0, 180, 180} else rot={0, math.random(1,6)*60, 180} end
		takeStartingCountry({position={-19.2300, 1.07, -11.9267}, rotation=rot, smooth=false, callback_function=function(obj) Wait.time(function() obj.flip() end, 2) end})
		if gStates.gameScenario=="The Chaos Rift" then
			if gStates.randomTileOrientation==false then rot={0, 180, 180} else rot={0, math.random(1,6)*60, 180} end
			takeStartingCountry({position={-20.4300, 1.09, -5.6911}, rotation=rot, smooth=false})
		end
	else
		if gStates.randomTileOrientation==false then rot={0, 180, 180} else rot={0, math.random(1,6)*60, 180} end
		if gStates.gameScenario~="The Gauntlet" and gStates.gameScenario~="Volkare's Return" and gStates.gameScenario~="Volkare's Return Blitz" then takeStartingCountry({position={-37.2305, 1.07, -5.6911}, rotation=rot, smooth=false, callback_function=function(obj) tile1=obj Wait.time(function() gStates.firstStarted=true firstTile=tile1.guid tile1.flip() end, 1) end}) end
		if gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz" then Wait.time(function() getObjectFromGUID("835c91").setPosition({-37.2305, 1.15, -5.6911}) getObjectFromGUID("835c91").flip() end, 1) end
		if gStates.randomTileOrientation==false then rot={0, 180, 180} else rot={0, math.random(1,6)*60, 180} end
		takeStartingCountry({position={-31.2303, 1.07, -7.7696}, rotation=rot, smooth=false, callback_function=function(obj) Wait.time(function() obj.flip() end, 2) end})
		if gStates.randomTileOrientation==false then rot={0, 180, 180} else rot={0, math.random(1,6)*60, 180} end
		if gStates.gameScenario~="The Gauntlet" then takeStartingCountry({position={-30.0303, 1.07, -14.0000}, rotation=rot, smooth=false, callback_function=function(obj) Wait.time(function() obj.flip() end, 3) end}) end
		if gStates.gameScenario=="Volkare's Quest" or gStates.gameScenario=="The War of Four" then Wait.time(function() getObjectFromGUID("835c91").setPosition({-12.0297, 1.15, 8.8586}) getObjectFromGUID("835c91").flip() end, 3) end
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
		TileShuffler.takeObject(params)
	end
	--Starting country tiles reveal on 1/2/3 second timers. They are part of setup, not newly explored terrain.
	Wait.time(function() startingMapSetup=false end, 4)
end

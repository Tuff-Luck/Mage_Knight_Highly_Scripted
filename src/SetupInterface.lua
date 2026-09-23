-- Pre-game setup interface: scenario/variant selection, setup options and setup-menu controls.

---------------
-- UI Functions
---------------
--Keep a pristine copy of the Optional Scenario Tweaks so changing scenario can
--return the selected scenario to the correct defaults for the current Mage Knight count.
local scenarioTweakDefaults=nil

local function copyScenarioCityLevels(source)
	local result={}
	for a,value in ipairs(source or {}) do result[a]=value end
	return result
end

function cacheScenarioTweakDefaults()
	if scenarioTweakDefaults~=nil then return end
	scenarioTweakDefaults={}
	for scenarioRef,scenario in ipairs(scenarioList) do
		scenarioTweakDefaults[scenarioRef]={}
		for playersRef=2,8 do
			local source=scenario[playersRef]
			if source~=nil then
				scenarioTweakDefaults[scenarioRef][playersRef]={
					rounds=source.rounds,
					mapShape=source.mapShape,
					mapShapeKey=source.mapShapeKey,
					countryTiles=source.countryTiles,
					coreTiles=source.coreTiles,
					cityTiles=source.cityTiles,
					discardTactics=source.discardTactics,
					dTW=source.dTW,
					cityLevels=copyScenarioCityLevels(source.cityLevels)}
			end
		end
	end
end

function setupPlayersRef()
	local playersRef=gStates.playerCount
	if (gStates.coop==0 or gStates.WarOfFourComp==true) and playersRef<=1 then playersRef=2 end
	if gStates.coop==1 then playersRef=playersRef+4 if playersRef==4 then playersRef=5 end end
	if gStates.gameScenario=="The Gauntlet" or gStates.gameScenario=="Quest for the Golden Grail" or gStates.gameScenario=="The Chaos Rift" or gStates.gameScenario=="First Conquest" then playersRef=5 end
	--Browsing/randomizing can preserve a dummy while entering a scenario that has no multiplayer co-op row.
	--Use that scenario's normal player-count row for the info panel; refreshSetupStartButton() still blocks the illegal setup.
	local scenarioRef=nil
	for a=1,#scenarioList do if scenarioList[a][1]==gStates.gameScenario then scenarioRef=a break end end
	local scenario=scenarioRef~=nil and scenarioList[scenarioRef] or nil
	if scenario~=nil and (scenario[playersRef]==nil or scenario[playersRef].rounds==nil) then
		local fallbackRef=math.max(gStates.playerCount,2)
		if scenario[fallbackRef]~=nil and scenario[fallbackRef].rounds~=nil then playersRef=fallbackRef end
	end
	return playersRef
end

function resetCurrentScenarioTweaks()
	cacheScenarioTweakDefaults()
	local scenarioRef=nil
	for a=1,#scenarioList do if scenarioList[a][1]==gStates.gameScenario then scenarioRef=a break end end
	local playersRef=setupPlayersRef()
	if scenarioRef==nil or scenarioTweakDefaults==nil or scenarioTweakDefaults[scenarioRef]==nil or scenarioTweakDefaults[scenarioRef][playersRef]==nil then return end
	local defaults=scenarioTweakDefaults[scenarioRef][playersRef]
	local target=scenarioList[scenarioRef][playersRef]
	target.rounds=defaults.rounds
	target.mapShape=defaults.mapShape
	target.mapShapeKey=defaults.mapShapeKey
	target.countryTiles=defaults.countryTiles
	target.coreTiles=defaults.coreTiles
	target.cityTiles=defaults.cityTiles
	target.discardTactics=defaults.discardTactics
	target.dTW=defaults.dTW
	target.cityLevels=copyScenarioCityLevels(defaults.cityLevels)
	gStates.scenarioRef=scenarioRef
	gStates.playersRef=playersRef
	gStates.megapolis=0
end

--Apply the same scenario defaults whether the scenario came from the setup menu, a randomizer,
--or one of the quick-start buttons. Blitz variants are normalized through the ordinary scenario
--selection path first so forced/selectable Blitz rules cannot drift into separate implementations.
function applyScenarioSetupDefaults(scenarioName)
	if type(scenarioName)~="string" or scenarioName=="" then return false end
	local requested=scenarioName
	local baseScenario=requested
	if requested:sub(-6)==" Blitz" then baseScenario=requested:sub(1,-7) end
	scenarioSelection(nil, "-1", baseScenario)
	if requested:sub(-6)==" Blitz" and gStates.gameScenario~=requested then
		BlitzSelection(nil, "True", "BlitzSelection")
	end
	return gStates.gameScenario==requested
end

function randomSetup(player, value, id)
	local value=scenarioList[math.random(2, #scenarioList-1)][1]
	applyScenarioSetupDefaults(value)
	--scenarioSelection updates setup state synchronously; randomize immediately instead of sleeping a frame.
	local randomOptions={"volkareCampAsCity", "randomTileOrientation", "randomCities", "removeShadesOfTezlaMonsters", "removeApocalypseTerrain",	"startAtNight", "darknessComing", "heroChallenges", "useCustomMageKnights", "weatherMod", "questMod", "apocalypseQuestCards", "proxyPlayer", "itemShopMod", "rampageAmbush", "rampagePursuit", "removeTerrain"}
	for a=1, #randomOptions, 1 do
		if UI.getAttribute(randomOptions[a], "interactable")=="True" then
			--Random must explicitly roll both ON and OFF. This matters for options such as Hero Challenges
			--that intentionally survive scenario browsing instead of being reset by scenarioSelection().
			optionsUpdate(nil, math.random(1,10)>7 and "True" or "False", randomOptions[a])
		end
	end
	ToolTipUpdate(id)
	if math.random(1,10)>7 then MoreRampageSelection(nil, "True", "MoreRampageSelection") end
	if math.random(1,10)>7 then RampageSelection(nil, "True", "RampageSelection") end
	--Do not let Interface Random bypass option lockouts (notably Hero Challenges vs Forgemasters).
	if math.random(1,10)>7 and UI.getAttribute("ROTFSelection", "interactable")=="True" then
		UI.setAttribute("DropDown", "active", "false")
		dropDownIdLink="ROTFSelection"
		local choice={"ROTF1Selection", "ROTF2Selection", "ROTF3Selection"}
		riseOfTheForgemastersOption(nil, "-1", choice[math.random(1,3)])
	end
end

function switchSetup(player, mouseButton, id)
	if mouseButton=="-1" then
		if id=="Setup2Selection" then
			UI.setAttribute("Setup1Details", "active", "false")
			UI.setAttribute("Setup2Details", "active", "true")
		else
			UI.setAttribute("Setup1Details", "active", "true")
			UI.setAttribute("Setup2Details", "active", "false")
		end
	end
end

function scenarioSelection(player, mouseButton, id)
	if mouseButton=="-1" then
		local IDConvert={	["ConquestSelection"]={"Conquest"},
							["FirstReconnaissanceSelection"]={"First Reconnaissance"},
							["FirstConquestSelection"]={"First Conquest"},
							["MinesLiberationSelection"]={"Mines Liberation"},
							["DruidNightsSelection"]={"Druid Nights"},
							["DungeonLordsSelection"]={"Dungeon Lords"},
							["ConquerAndHoldSelection"]={"Conquer and Hold"},
							["OneToReturnSelection"]={"One to Return"},
							["VolkaresReturnSelection"]={"Volkare's Return"},
							["VolkaresQuestSelection"]={"Volkare's Quest"},
							["LifeAndDeathSelection"]={"Life and Death"},
							["TheRealmOfTheDeadSelection"]={"The Realm of the Dead"},
							["TheHiddenValleySelection"]={"The Hidden Valley"},
							["AgainsttheApocalypseSelection"]={"Against the Apocalypse"},
							["AgainsttheHorsemenSelection"]={"Against the Horsemen"},
							["AgainsttheDragonSelection"]={"Against the Dragon"},
							["ApocalypseIsHereSelection"]={"Apocalypse is Here"},
							["FuryOfTheApocalypseDragonSelection"]={"Fury of the Apocalypse Dragon"},
							["TheLostRelicSelection"]={"The Lost Relic"},
							["TheGauntletSelection"]={"The Gauntlet"},
							["QuestForTheGoldenGrailSelection"]={"Quest for the Golden Grail"},
							["TheChaosRiftSelection"]={"The Chaos Rift"},
							["UltimateConquestSelection"]={"Ultimate Conquest"},
							["FastForwardedConquestSelection"]={"Fast Forwarded Conquest"},
							["TheWarOfFourSelection"]={"The War of Four"},
							["RaidersOfTheCrusaderTempleSelection"]={"Raiders of the Crusader Temple"},
							["ForTheCouncilSelection"]={"For the Council"},
							["TheFracturedLandsSelection"]={"The Fractured Lands"},
							["CustomSelection"]={"Custom"}}
		--Preserve the dummy choice while browsing scenarios. Volkare uses the same remembered Mage Knight as his skill set.
		--Scenario-forced "nobody" does not erase the remembered choice, so it survives scenarios that disallow a dummy.
		if gStates.positionMageKnight[5]=="Volkare" then
			if gStates.volkareSkills~=nil and gStates.volkareSkills~="nobody" then gStates.setupDummyMageChoice=gStates.volkareSkills end
		elseif gStates.positionMageKnight[5]~=nil and gStates.positionMageKnight[5]~="nobody" then
			gStates.setupDummyMageChoice=gStates.positionMageKnight[5]
		elseif gStates.setupDummyMageChoice==nil then
			gStates.setupDummyMageChoice="nobody"
		end
		gStates.gameScenario=id
		if IDConvert[id]~=nil then gStates.gameScenario=IDConvert[id][1] end
		UI.setAttribute("ScenarioSelectionText", "text", translateWord[gStates.gameScenario])
		UI.setAttribute("ScenarioSelectionImage", "image", "Sliced Button/Button New Active")
		UI.setAttribute("DropDown", "active", "false")
		--Keep the selected Mage Knights when browsing scenarios. The dummy is retained too, except where the scenario forces it off or replaces it with Volkare.
		local MKDropDownUI={"firstMKSelection", "secondMKSelection", "thirdMKSelection", "fourthMKSelection"}
		gStates.playerCount=0
		for a=1, 4, 1 do
			local mage=gStates.positionMageKnight[a] or "nobody"
			gStates.positionMageKnight[a]=mage
			if mage~="nobody" then gStates.playerCount=gStates.playerCount+1 end
			UI.setAttribute(MKDropDownUI[a], "interactable", "true")
			UI.setAttribute(MKDropDownUI[a].."Image", "image", "Sliced Button/Button New Active")
			UI.setAttribute(MKDropDownUI[a].."Text", "text", translateWord[mage])
		end
		gStates.positionMageKnight[5]=gStates.setupDummyMageChoice or "nobody"
		UI.setAttribute("dummyMKSelection", "interactable", "true")
		UI.setAttribute("dummyMKSelectionImage", "image", "Sliced Button/Button New Active")
		UI.setAttribute("dummyMKSelectionText", "text", translateWord[gStates.positionMageKnight[5]] or translateWord["nobody"])
		dropDownIdLink="none"
		UI.setAttribute("DropDown", "active", "false")
		gStates.megapolis=0
		gStates.coop=gStates.positionMageKnight[5]~="nobody" and 1 or 0
		--Dummy Menu Access
		UI.setAttribute("VolkareLevelSelectionRow", "active", "false")
		UI.setAttribute("VolkareRaceSelectionRow", "active", "false")
		UI.setAttribute("MageKnightDetails", "height", "180")
		UI.setAttribute("Setup1Details", "height", "466")
		UI.setAttribute("Setup2Details", "height", "466")
		UI.setAttribute("Setup1DetailsSub", "height", "406")
		UI.setAttribute("Setup2DetailsSub", "height", "406")
		refreshProxySetupLabel()
		if gStates.gameScenario=="Conquer and Hold" or gStates.gameScenario=="One to Return" or gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Quest" or gStates.gameScenario=="The War of Four" then
			if gStates.gameScenario=="Conquer and Hold" or gStates.gameScenario=="One to Return" then
				UI.setAttribute("dummyMKSelection", "interactable", "false")
				UI.setAttribute("dummyMKSelectionImage", "image", "Sliced Button/Button New Deactive")
				UI.setAttribute("dummyMKSelectionText", "text", "{en}nobody{ru}никто{zh-tw}無玩家{zh-cn}无玩家{ko}없음{es}ninguno{fr}personne{pt-br}ninguém{de}Niemand")
				gStates.positionMageKnight[5]="nobody"
				gStates.coop=0
			else
				--UI.setAttribute("dummyMKSelectionText", "text", "{en}Volkare{ru}Волкар{zh-tw}沃卡里{zh-cn}沃卡里{ko}볼케어{es}Volkare{fr}Volkare{pt-br}Volkare{de}Volkare")
				UI.setAttribute("DummyPosText", "text", "{en}Volkare Skills -{ru}Навыки Волкаре -{zh-tw}沃卡里技能：{zh-cn}沃卡里技能：{ko}볼케어의 스킬 -{es}Habilidades de Volkare -{fr}Compétences de Volkare -{pt-br}Habilidades de Volkare -{de}Volkare-Fähigkeiten -")
				if gStates.setupDummyMageChoice~=nil and gStates.setupDummyMageChoice~="nobody" then gStates.volkareSkills=gStates.setupDummyMageChoice else gStates.volkareSkills="Random" end
				UI.setAttribute("dummyMKSelectionText", "text", translateWord[gStates.volkareSkills] or translateWord["Random"])
				UI.setAttribute("VolkareLevelSelectionRow", "active", "true")
				UI.setAttribute("MageKnightDetails", "height", "210")
				UI.setAttribute("Setup1Details", "height", "436")
				UI.setAttribute("Setup2Details", "height", "436")
				UI.setAttribute("Setup1DetailsSub", "height", "376")
				UI.setAttribute("Setup2DetailsSub", "height", "376")
				if gStates.gameScenario~="The War of Four" then
					UI.setAttribute("VolkareRaceSelectionRow", "active", "true")
					UI.setAttribute("MageKnightDetails", "height", "240")
					UI.setAttribute("Setup1Details", "height", "406")
					UI.setAttribute("Setup2Details", "height", "406")
					UI.setAttribute("Setup1DetailsSub", "height", "346")
					UI.setAttribute("Setup2DetailsSub", "height", "346")
				end
				gStates.positionMageKnight[5]="Volkare"
				gStates.coop=1
			end
		end
		--Blitz Menu Access
		UI.setAttribute("BlitzSelection", "textColor", "rgb(0.0,0.0,0.0)")
		UI.setAttribute("BlitzSelection", "interactable", "True")
		UI.setAttribute("BlitzSelection", "isOn", "false")
		gStates.blitz=0
		if gStates.gameScenario=="First Reconnaissance" then
			UI.setAttribute("BlitzSelection", "interactable", "False")
		else
			if gStates.gameScenario=="The Realm of the Dead" or gStates.gameScenario=="The Hidden Valley" or gStates.gameScenario=="The Lost Relic" or gStates.gameScenario=="Against the Apocalypse" or gStates.gameScenario=="Against the Horsemen" or gStates.gameScenario=="Against the Dragon" or gStates.gameScenario=="The Fractured Lands" then
			 	UI.setAttribute("BlitzSelection", "isOn", "true")
				gStates.blitz=1
			end
			for a=1, #scenarioList, 1 do
				if gStates.blitz==1 and gStates.gameScenario.." Blitz"==scenarioList[a][1] then gStates.gameScenario=gStates.gameScenario.." Blitz" break end
				if gStates.blitz==0 and gStates.gameScenario:sub(1, -7)==scenarioList[a][1] then gStates.gameScenario=gStates.gameScenario:sub(1, -7) break end
			end
			if gStates.gameScenario=="Against the Horsemen Blitz" or gStates.gameScenario=="Against the Dragon Blitz" then UI.setAttribute("BlitzSelection", "interactable", "False") end
		end
		--Volkare's Camp Menu Access
		UI.setAttribute("volkareCampAsCity", "interactable", "True")
		UI.setAttribute("volkareCampAsCity", "isOn", "false")
		gStates.volkareCampAsCity=false
		if gStates.gameScenario~="First Conquest" and gStates.gameScenario~="Conquest" and gStates.gameScenario~="Ultimate Conquest" and gStates.gameScenario~="Fast Forwarded Conquest" and gStates.gameScenario~="The Lost Relic Blitz" and gStates.gameScenario~="The Fractured Lands Blitz" and gStates.gameScenario~="One to Return" and gStates.gameScenario~="Against the Horsemen Blitz" then UI.setAttribute("volkareCampAsCity", "interactable", "False") end
		--Lost Legion Menu Access
		UI.setAttribute("removeLostLegionExpansion", "interactable", "True")
		UI.setAttribute("removeLostLegionExpansion", "isOn", "false")
		gStates.removeLostLegionExpansion=false
		refreshLostLegionExpansionOption()
		--Rotated Terrain Menu access
		UI.setAttribute("randomTileOrientation", "interactable", "True")
		UI.setAttribute("randomTileOrientation", "isOn", "false")
		gStates.randomTileOrientation=false
		if gStates.gameScenario=="First Reconnaissance" or gStates.gameScenario=="The Fractured Lands Blitz" then UI.setAttribute("randomTileOrientation", "interactable", "False") end
		--Random Cities Menu access - could be locked off for scenarios without city fighting
		UI.setAttribute("randomCities", "interactable", "True")
		UI.setAttribute("randomCities", "isOn", "false")
		gStates.randomCities=false
		if randomCitiesAllowedForScenario()==false then UI.setAttribute("randomCities", "interactable", "False") end
		--Shades of Tezla monsters are included by default.
		UI.setAttribute("removeShadesOfTezlaMonsters", "interactable", "True")
		UI.setAttribute("removeShadesOfTezlaMonsters", "isOn", "false")
		gStates.removeShadesOfTezlaMonsters=false
		if gStates.gameScenario=="First Reconnaissance" then
			UI.setAttribute("removeShadesOfTezlaMonsters", "isOn", "true")
			UI.setAttribute("removeShadesOfTezlaMonsters", "interactable", "False")
			gStates.removeShadesOfTezlaMonsters=true
		elseif gStates.gameScenario=="Life and Death" or gStates.gameScenario=="The Realm of the Dead Blitz" or gStates.gameScenario=="The Hidden Valley Blitz" or gStates.gameScenario=="The War of Four" then
			UI.setAttribute("removeShadesOfTezlaMonsters", "isOn", "false")
			UI.setAttribute("removeShadesOfTezlaMonsters", "interactable", "False")
			gStates.removeShadesOfTezlaMonsters=false
		end
		--Apocalypse Dragon Terrain is included by default. Only scenarios that require a specific state lock this removal option.
		UI.setAttribute("removeApocalypseTerrain", "interactable", "True")
		UI.setAttribute("removeApocalypseTerrain", "isOn", "false")
		gStates.removeApocalypseTerrain=false
		if gStates.gameScenario=="First Reconnaissance" then
			UI.setAttribute("removeApocalypseTerrain", "isOn", "true")
			gStates.removeApocalypseTerrain=true
		elseif gStates.gameScenario=="Against the Apocalypse Blitz" then
			UI.setAttribute("removeApocalypseTerrain", "isOn", "false")
			gStates.removeApocalypseTerrain=false
		end
		if gStates.gameScenario=="First Reconnaissance" or gStates.gameScenario=="Against the Apocalypse Blitz" then UI.setAttribute("removeApocalypseTerrain", "interactable", "False") end
		--Rampage Menu Access
		UI.setAttribute("RampageSelection", "interactable", "True")
		UI.setAttribute("MoreRampageSelection", "interactable", "True")
		UI.setAttribute("RampageSelection", "isOn", "false")
		UI.setAttribute("MoreRampageSelection", "isOn", "false")
		gStates.rampage=0
		if gStates.gameScenario=="First Reconnaissance" then
			UI.setAttribute("RampageSelection", "interactable", "False")
			UI.setAttribute("MoreRampageSelection", "interactable", "False")
		end
		--Day Night Menu Access
		UI.setAttribute("startAtNight", "interactable", "True")
		UI.setAttribute("startAtNight", "isOn", "False")
		UI.setAttribute("darknessComing", "text", "{en}Darkness is Coming{ru}Надвигается тьма{zh-tw}黑暗侵袭{zh-cn}黑暗侵袭{ko}어둠의 도래{es}La Oscuridad se Acerca{fr}Les Ombres Arrivent{pt-br}Trevas Chegando{de}Es Wird Dunkel")
		gStates.startAtNight=false
		if gStates.gameScenario=="First Reconnaissance" or gStates.gameScenario=="Fast Forwarded Conquest" then
			UI.setAttribute("startAtNight", "interactable", "False")
			if gStates.gameScenario=="Fast Forwarded Conquest" then
				UI.setAttribute("startAtNight", "isOn", "True")
				gStates.startAtNight=true
			end
		end
		--Ambush Menu Access
		UI.setAttribute("rampageAmbush", "interactable", "True")
		UI.setAttribute("rampageAmbush", "isOn", "False")
		gStates.rampageAmbush=false
		if gStates.gameScenario=="First Reconnaissance" then UI.setAttribute("rampageAmbush", "interactable", "False") end
		if gStates.gameScenario=="The Hidden Valley Blitz" then
			UI.setAttribute("rampageAmbush", "isOn", "True")
			UI.setAttribute("rampageAmbush", "interactable", "False")
			gStates.rampageAmbush=true
		end
		--Pursuit Menu Access
		UI.setAttribute("rampagePursuit", "interactable", "True")
		UI.setAttribute("rampagePursuit", "isOn", "False")
		gStates.rampagePursuit=false
		if gStates.gameScenario=="First Reconnaissance" then UI.setAttribute("rampagePursuit", "interactable", "False") end
		if gStates.gameScenario=="The Realm of the Dead Blitz" then
			UI.setAttribute("rampagePursuit", "isOn", "True")
			UI.setAttribute("rampagePursuit", "interactable", "False")
			gStates.rampagePursuit=true
		end
		--Darkness is Coming Menu Access
		UI.setAttribute("darknessComing", "interactable", "True")
		UI.setAttribute("darknessComing", "isOn", "false")
		gStates.darknessComing=false
		if gStates.gameScenario=="First Reconnaissance" then UI.setAttribute("darknessComing", "interactable", "False") end
		--Mage Knight Level Menu access
		UI.setAttribute("mageKnightLevels", "interactable", "True")
		UI.setAttribute("mageKnightLevels", "isOn", "False")
		gStates.mageKnightLevels=false
		if gStates.gameScenario=="First Reconnaissance" or gStates.gameScenario=="The Lost Relic Blitz" or gStates.gameScenario=="Quest for the Golden Grail" or gStates.gameScenario=="The Chaos Rift" or gStates.gameScenario=="Fast Forwarded Conquest" then
			UI.setAttribute("mageKnightLevels", "interactable", "False")
			if gStates.gameScenario=="The Lost Relic Blitz" or gStates.gameScenario=="Fast Forwarded Conquest" then
				UI.setAttribute("mageKnightLevels", "isOn", "True")
				gStates.mageKnightLevels=true
			end
		end
		--Ymirgh Menu Access
		UI.setAttribute("useCustomMageKnights", "interactable", "True")
		UI.setAttribute("useCustomMageKnights", "isOn", "false")
		gStates.useCustomMageKnights=false
		if gStates.gameScenario=="First Reconnaissance" then UI.setAttribute("useCustomMageKnights", "interactable", "False") end
		--Bonus Cards Menu Access
		UI.setAttribute("removeBonusCards", "interactable", "True")
		UI.setAttribute("removeBonusCards", "isOn", "false")
		gStates.removeBonusCards=false
		if gStates.gameScenario=="First Reconnaissance" then
			UI.setAttribute("removeBonusCards", "interactable", "False")
			UI.setAttribute("removeBonusCards", "isOn", "true")
			gStates.removeBonusCards=true
		end
		--Weather Menu Access
		UI.setAttribute("weatherMod", "interactable", "True")
		UI.setAttribute("weatherMod", "isOn", "false")
		gStates.weatherMod=false
		if gStates.gameScenario=="First Reconnaissance" then UI.setAttribute("weatherMod", "interactable", "False") end
		--Quest Menu Access
		UI.setAttribute("questMod", "interactable", "True")
		UI.setAttribute("questMod", "isOn", "false")
		gStates.questMod=false
		if gStates.gameScenario=="First Reconnaissance" then UI.setAttribute("questMod", "interactable", "False") end
		--Official Apocalypse Dragon Quest Cards Menu Access
		UI.setAttribute("apocalypseQuestCards", "interactable", "True")
		UI.setAttribute("apocalypseQuestCards", "isOn", "false")
		gStates.apocalypseQuestCards=false
		if gStates.gameScenario=="First Reconnaissance" then UI.setAttribute("apocalypseQuestCards", "interactable", "False") end
		if gStates.gameScenario=="For the Council" or gStates.gameScenario=="The Fractured Lands Blitz" then
			UI.setAttribute("questMod", "isOn", "false")
			UI.setAttribute("questMod", "interactable", "false")
			gStates.questMod=false
			UI.setAttribute("apocalypseQuestCards", "isOn", "true")
			UI.setAttribute("apocalypseQuestCards", "interactable", "false")
			gStates.apocalypseQuestCards=true
		end
		--Proxy Player Menu Access
		UI.setAttribute("proxyPlayer", "interactable", "True")
		UI.setAttribute("proxyPlayer", "isOn", "false")
		gStates.proxyPlayer=false
		if gStates.gameScenario=="First Reconnaissance" or gStates.gameScenario=="Conquer and Hold" or gStates.gameScenario=="One to Return" or
			gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz" or gStates.gameScenario=="Volkare's Quest" or gStates.gameScenario=="The War of Four" then
			UI.setAttribute("proxyPlayer", "interactable", "False")
		end
		refreshProxySetupLabel()
		--Item Shop Menu Access
		UI.setAttribute("itemShopMod", "interactable", "True")
		UI.setAttribute("itemShopMod", "isOn", "false")
		gStates.itemShopMod=false
		if gStates.gameScenario=="First Reconnaissance" then UI.setAttribute("itemShopMod", "interactable", "False") end
		--Volkare's Race and Combat Level Menu Access
		if gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Quest" or gStates.gameScenario=="The War of Four" then
			UI.setAttribute("VolkareLevelSelection", "interactable", "True")
			UI.setAttribute("VolkareLevelSelection", "text", "{en}Daring{ru}Смелый{zh-tw}大膽{zh-cn}大胆{ko}대담한{es}Atrevido{fr}Audacieux{pt-br}Ousado{de}Wagemutig")
			gStates.volkareCombatLevel=1
			UI.setAttribute("VolkareRaceSelection", "interactable", "True")
			UI.setAttribute("VolkareRaceSelection", "text", translateWord["Fair"])
			gStates.volkareRaceLevel=1
		else
			UI.setAttribute("VolkareLevelSelection", "interactable", "False")
			UI.setAttribute("VolkareLevelSelection", "text", "{en}Not Used{ru}Не используется{zh-tw}未使用{zh-cn}未使用{ko}사용 안 함{es}No se Utiliza{fr}Non Utilisé{pt-br}Não Utilizado{de}Nicht Verwendet")
			UI.setAttribute("VolkareRaceSelection", "interactable", "False")
			UI.setAttribute("VolkareRaceSelection", "text", "{en}Not Used{ru}Не используется{zh-tw}未使用{zh-cn}未使用{ko}사용 안 함{es}No se Utiliza{fr}Non Utilisé{pt-br}Não Utilizado{de}Nicht Verwendet")
		end
		--Rise of the forgemaster Menu Access
		UI.setAttribute("ROTFSelection", "interactable", "True")
		UI.setAttribute("ROTFSelectionText", "text", "{en}Not Used{ru}Не используется{zh-tw}未使用{zh-cn}未使用{ko}사용 안 함{es}No se Utiliza{fr}Non Utilisé{pt-br}Não Utilizado{de}Nicht Verwendet")
		UI.setAttribute("ROTFSelectionImage", "image", "Sliced Button/Button New Active")
		gStates.riseOfTheForgemasters=0
		if gStates.gameScenario=="First Reconnaissance" then
			UI.setAttribute("ROTFSelection", "interactable", "False")
			UI.setAttribute("ROTFSelectionImage", "image", "Sliced Button/Button New Deactive")
	 	end
		--Remove terrain Tiles Menu Access
		UI.setAttribute("removeTerrain", "interactable", "True")
		UI.setAttribute("removeTerrain", "ison", "False")
		gStates.removeTerrain=false
		if gStates.gameScenario=="First Reconnaissance" or gStates.gameScenario=="Mines Liberation" or gStates.gameScenario=="The Gauntlet" or gStates.gameScenario=="Druid Nights" or gStates.gameScenario=="Quest for the Golden Grail" or gStates.gameScenario=="The Chaos Rift" or gStates.gameScenario=="Life and Death" or gStates.gameScenario=="The Realm of the Dead Blitz" or gStates.gameScenario=="Against the Horsemen Blitz" then
			UI.setAttribute("removeTerrain", "interactable", "False")
	 	end
		--Alternate Monster Tokens Menu Access
		UI.setAttribute("useAlternatePugs", "interactable", "True")
		UI.setAttribute("useAlternatePugs", "ison", "False")
		gStates.useAlternatePugs=false
		--Changing scenario discards any previous Optional Scenario Tweaks and reloads
		--the defaults for this scenario and the currently selected Mage Knight count.
		resetCurrentScenarioTweaks()
		refreshHeroChallengeOptionLocks()
		scenarioInfoUpdate()
	end
end

function BlitzSelection(player, value, id)
	if gStates.gameScenario=="Against the Horsemen Blitz" and value~="True" then
		UI.setAttribute("BlitzSelection", "isOn", "true")
		UI.setAttribute("BlitzSelection", "interactable", "False")
		gStates.blitz=1
		return
	end
	if value=="True" then
		UI.setAttribute("BlitzSelection", "isOn", "true")
		gStates.blitz=1
	else
		UI.setAttribute("BlitzSelection", "isOn", "false")
		gStates.blitz=0
	end
	for a=1, #scenarioList, 1 do
		if gStates.blitz==1 and gStates.gameScenario.." Blitz"==scenarioList[a][1] then gStates.gameScenario=gStates.gameScenario.." Blitz" break end
		if gStates.blitz==0 and gStates.gameScenario:sub(1, -7)==scenarioList[a][1] then gStates.gameScenario=gStates.gameScenario:sub(1, -7) break end
	end
	resetCurrentScenarioTweaks()
	refreshHeroChallengeOptionLocks()
	scenarioInfoUpdate()
	if scenarioList[gStates.scenarioRef].scenarioDetails.blitzPossible~="Yes" then
		if scenarioList[gStates.scenarioRef].scenarioDetails.blitzPossible=="On Only" then
			if gStates.blitz==0 then UI.setAttribute("BlitzSelection", "textColor", "rgb(1.0,0.0,0.0)") else UI.setAttribute("BlitzSelection", "textColor", "rgb(0.0,0.0,0.0)") end
		else
			if gStates.blitz==1 then UI.setAttribute("BlitzSelection", "textColor", "rgb(1.0,0.0,0.0)") else UI.setAttribute("BlitzSelection", "textColor", "rgb(0.0,0.0,0.0)") end
		end
	else
		UI.setAttribute("BlitzSelection", "textColor", "rgb(0.0,0.0,0.0)")
	end
	scenarioInfoUpdate()
	ToolTipUpdate(id)
end

-- Cross-option setup locks for Rise of the Forgemasters and Hero Challenges.
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

function refreshLostLegionExpansionOption()
	if gStates==nil then return end
	local firstRecon=gStates.gameScenario=="First Reconnaissance"
	local required=gStates.gameScenario=="The Gauntlet" or
		(gStates.gameScenario=="The Lost Relic Blitz" and gStates.coop==1 and (gStates.playerCount or 0)>=4)
	if firstRecon then
		gStates.removeLostLegionExpansion=true
		UI.setAttribute("removeLostLegionExpansion", "isOn", "true")
		UI.setAttribute("removeLostLegionExpansion", "interactable", "False")
	elseif required then
		gStates.removeLostLegionExpansion=false
		UI.setAttribute("removeLostLegionExpansion", "isOn", "false")
		UI.setAttribute("removeLostLegionExpansion", "interactable", "False")
	else
		UI.setAttribute("removeLostLegionExpansion", "interactable", "True")
	end
	if gStates.removeLostLegionExpansion==true then
		gStates.volkareCampAsCity=false
		UI.setAttribute("volkareCampAsCity", "isOn", "false")
		UI.setAttribute("volkareCampAsCity", "interactable", "False")
	end
end

function optionsUpdate(player, value, id)
	if id=="heroChallenges" and value=="True" and (gStates.useCustomMageKnights==true or (gStates.riseOfTheForgemasters or 0)>0) then
		UI.setAttribute("heroChallenges","isOn","false")
		gStates.heroChallenges=false
		refreshHeroChallengeOptionLocks()
		refreshSetupStartButton()
		return
	end
	if id=="volkareCampAsCity" and value=="True" and gStates.megapolis>0 then
		UI.setAttribute("volkareCampAsCity", "isOn", "false")
		gStates.volkareCampAsCity=false
		scenarioInfoUpdate()
		return
	end
	if value=="True" then
		UI.setAttribute(id, "isOn", "true")
		gStates[id]=true
		--The two Quest systems cannot be used together.
		if id=="questMod" then UI.setAttribute("apocalypseQuestCards", "interactable", "false") elseif id=="apocalypseQuestCards" then UI.setAttribute("questMod", "interactable", "false") end
		if id=="startAtNight" then UI.setAttribute("darknessComing", "text", "{en}Daylight is Coming{ru}Надвигается рассвет{zh-tw}白晝侵襲{zh-cn}白昼侵袭{ko}빛의 도래{es}Se Acerca la luz del Día{fr}Lendemain Arrive{pt-br}A Luz do dia está Chegando{de}Es Wird Hell") end
		if id=="removeLostLegionExpansion" then
			UI.setAttribute("ROTFSelection", "interactable", "False")
			UI.setAttribute("ROTFSelectionImage", "image", "Sliced Button/Button New Deactive")
			gStates.volkareCampAsCity=false
			UI.setAttribute("volkareCampAsCity", "isOn", "false")
			UI.setAttribute("volkareCampAsCity", "interactable", "False")
		end
	else
		UI.setAttribute(id, "isOn", "false")
		gStates[id]=false
		if id=="questMod" then UI.setAttribute("apocalypseQuestCards", "interactable", "true") elseif id=="apocalypseQuestCards" then UI.setAttribute("questMod", "interactable", "true") end
		if id=="startAtNight" then UI.setAttribute("darknessComing", "text", "{en}Darkness is Coming{ru}Надвигается тьма{zh-tw}黑暗侵襲{zh-cn}黑暗侵袭{ko}어둠의 도래{es}La Oscuridad se Acerca{fr}Les Ombres Arrivent{pt-br}Trevas Chegando{de}Es Wird Dunkel") end
		if id=="removeLostLegionExpansion" then --and gStates.removeBonusCards==false) or (id=="removeBonusCards" and gStates.removeLostLegionExpansion==false)
			UI.setAttribute("ROTFSelection", "interactable", "True")
			UI.setAttribute("ROTFSelectionImage", "image", "Sliced Button/Button New Active")
		end
		if id=="useCustomMageKnights" then
			local MKDropDownUI={"firstMKSelection", "secondMKSelection", "thirdMKSelection", "fourthMKSelection", "dummyMKSelection"}
			for position, mageKnight in pairs(gStates.positionMageKnight) do
				if customMages[mageKnight]~=nil then
					dropDownIdLink=MKDropDownUI[position]
					PlayerChosen(nil, "-1", "nobodySelection")
				end
			end
			if gStates.positionMageKnight[5]=="Volkare" and customMages[gStates.volkareSkills]~=nil then
				gStates.volkareSkills="Random"
				gStates.setupDummyMageChoice="Random"
				UI.setAttribute("dummyMKSelectionText", "text", translateWord["Random"])
			elseif customMages[gStates.setupDummyMageChoice]~=nil then
				gStates.setupDummyMageChoice="nobody"
			end
		end
	end
	if id=="removeApocalypseTerrain" or id=="removeTerrain" or id=="removeLostLegionExpansion" then
		if id=="removeLostLegionExpansion" and gStates.removeLostLegionExpansion==true then
			local setup=scenarioList[gStates.scenarioRef][gStates.playersRef]
			if setup.cityTiles>4 then
				setup.cityTiles=4
				while #setup.cityLevels>4 do table.remove(setup.cityLevels) end
			end
		end
		local max=14
		if gStates.removeTerrain==true then max=max-2 end
		if gStates.removeApocalypseTerrain~=true then max=max+3 end
		if gStates.removeLostLegionExpansion==true then max=max-3 end
		if scenarioList[gStates.scenarioRef][gStates.playersRef].countryTiles>max then
			scenarioList[gStates.scenarioRef][gStates.playersRef].countryTiles=max
		end
		max=6
		if gStates.removeApocalypseTerrain~=true then max=max+2 end
		if gStates.removeLostLegionExpansion==true then max=max-2 end
		if scenarioList[gStates.scenarioRef][gStates.playersRef].coreTiles>max then
			scenarioList[gStates.scenarioRef][gStates.playersRef].coreTiles=max
		end
	end
	refreshHeroChallengeOptionLocks()
	ToolTipUpdate(id)
	scenarioInfoUpdate()
	if id=="proxyPlayer" then refreshProxySetupLabel() end
	toggleDropDown(nil, "-1", dropDownIdLink)
end

function RampageSelection(player, value, id)
	if value=="True" then
		gStates.rampage=1
		UI.setAttribute("MoreRampageSelection", "interactable", "False")
		UI.setAttribute("MoreRampageSelection", "isOn", "false")
		UI.setAttribute("RampageSelection", "interactable", "True")
		UI.setAttribute("RampageSelection", "isOn", "true")
	else
		gStates.rampage=0
		UI.setAttribute("MoreRampageSelection", "interactable", "True")
		UI.setAttribute("RampageSelection", "isOn", "false")
	end
	scenarioInfoUpdate()
	ToolTipUpdate(id)
end

function riseOfTheForgemastersOption(player, mouseButton, id)
	if mouseButton=="-1" then
		local IDConvert={["ROTF0Selection"]="{en}Not Used{ru}Не используется{zh-tw}未使用{zh-cn}未使用{ko}사용 안 함{es}No se Utiliza{fr}Non Utilisé{pt-br}Não Utilizado{de}Nicht Verwendet",
							["ROTF1Selection"]="{en}1. New Beginning{ru}1. Новое начало{zh-tw}新的開始{zh-cn}新的开始{ko}1.새로운 시작{es}1. Un nuevo comienzo{fr}1. Nouveau départ{pt-br}1. Novo Começo{de}1. Neubeginn",
							["ROTF2Selection"]="{en}2. Spoils of War{ru}2. Военные трофеи{zh-tw}戰爭犒賞{zh-cn}战争犒赏{ko}2.전쟁의 전리품{es}2. Botín de Guerra{fr}2. Butin de Guerre{pt-br}2. Despojos de Guerra{de}2. Kriegsbeute",
							["ROTF3Selection"]="{en}3. Elixir of Life{ru}3. Эликсир Жизни{zh-tw}⽣命靈藥{zh-cn}⽣命灵药{ko}3.생명의 엘릭서{es}3. El Elixir de la Vida{fr}3. Élixir de vie{pt-br}3. Elixir da Vida{de}3. Lebenselixier"}
		UI.setAttribute(dropDownIdLink.."Text", "text", IDConvert[id])
		UI.setAttribute(dropDownIdLink.."Image", "image", "Sliced Button/Button New Active")
		UI.setAttribute("DropDown", "active", "false")
		dropDownIdLink="none"
		gStates.riseOfTheForgemasters=tonumber(id:sub(5,5))
		UI.setAttribute("removeLostLegionExpansion", "interactable", "true")
		UI.setAttribute("removeBonusCards", "interactable", "true")
		UI.setAttribute("useCustomMageKnights", "interactable", "true")
		if gStates.riseOfTheForgemasters>0 then
			applyForgemasterExpansionRequirements()
			UI.setAttribute("useCustomMageKnights", "interactable", "false")
			UI.setAttribute("useCustomMageKnights", "isOn", "true")
			gStates.useCustomMageKnights=true
		end
		if gStates.riseOfTheForgemasters<3 then
			local MKDropDownUI={"firstMKSelection", "secondMKSelection", "thirdMKSelection", "fourthMKSelection", "dummyMKSelection"}
			for position, mageKnight in pairs(gStates.positionMageKnight) do
				if customMages[mageKnight]~=nil then
					dropDownIdLink=MKDropDownUI[position]
					PlayerChosen(nil, "-1", "nobodySelection")
				end
			end
		end
		refreshHeroChallengeOptionLocks()
		ToolTipUpdate(id)
		scenarioInfoUpdate()
	end
end

function MoreRampageSelection(player, value, id)
	if value=="True" then
		gStates.rampage=2
		UI.setAttribute("RampageSelection", "interactable", "False")
		UI.setAttribute("RampageSelection", "isOn", "false")
		UI.setAttribute("MoreRampageSelection", "interactable", "True")
		UI.setAttribute("MoreRampageSelection", "isOn", "true")
	else
		gStates.rampage=0
		UI.setAttribute("RampageSelection", "interactable", "True")
		UI.setAttribute("MoreRampageSelection", "isOn", "false")
	end
	scenarioInfoUpdate()
	ToolTipUpdate(id)
end

dropDownIdLink="none"
function toggleDropDown(player, mouseButton, id)
	if mouseButton=="-1" then
		local IDConvert={	["firstMKSelection"]={1,"MageDropDown",-275},
							["secondMKSelection"]={2,"MageDropDown",-275},
							["thirdMKSelection"]={3, "MageDropDown",-275},
							["fourthMKSelection"]={4,"MageDropDown",-275},
							["dummyMKSelection"]={5,"MageDropDown",-275},
							["ScenarioSelection"]={0,"ScenarioDropDown", 90},
							["ROTFSelection"]={0,"ROTFDropDown", -115},
							["VolkareLevelSelection"]={0,"VolkareLevelDropDown",-305},
							["VolkareRaceSelection"]={0,"VolkareRaceDropDown",-335}}
		UI.setAttribute(dropDownIdLink.."Image", "image", "Sliced Button/Button New Active")
		if dropDownIdLink==id then
			dropDownIdLink="none"
			UI.setAttribute("DropDown", "active", "false")
			UI.setAttribute(id.."Image", "image", "Sliced Button/Button New Active")
		else
			dropDownIdLink=id
			local dropDownData={["nobodyRow"]={"nobody", "nobodySelectionImage", "MageDropDown"},
								["AllSkillsRow"]={"All Skills", "AllSkillsSelectionImage", "MageDropDown"},
								["RANDOMRow"]={"Random", "RANDOMSelectionImage", "MageDropDown"},
								["ArytheaRow"]={"Arythea", "ArytheaSelectionImage", "MageDropDown"},
								["GoldyxRow"]={"Goldyx", "GoldyxSelectionImage", "MageDropDown"},
								["NorowasRow"]={"Norowas", "NorowasSelectionImage", "MageDropDown"},
								["TovakRow"]={"Tovak", "TovakSelectionImage", "MageDropDown"},
								["BraevalarRow"]={"Braevalar", "BraevalarSelectionImage", "MageDropDown"},
								["KrangRow"]={"Krang", "KrangSelectionImage", "MageDropDown"},
								["WolfhawkRow"]={"Wolfhawk", "WolfhawkSelectionImage", "MageDropDown"},
								["CoralRow"]={"Coral", "CoralSelectionImage", "MageDropDown"},
								["YmirghRow"]={"Ymirgh", "YmirghSelectionImage", "MageDropDown"},
								["MevokRow"]={"Mevok", "MevokSelectionImage", "MageDropDown"},
								["DusceniaRow"]={"Duscenia", "DusceniaSelectionImage", "MageDropDown"},
								["JormundRow"]={"Jormund", "JormundSelectionImage", "MageDropDown"},
								["MalekRow"]={"Malek", "MalekSelectionImage", "MageDropDown"},
								["ZirtaeRow"]={"Zirtae", "ZirtaeSelectionImage", "MageDropDown"},
								["DaringRow"]={"Daring", "DaringSelectionImage", "VolkareLevelDropDown", 1},
								["HeroicRow"]={"Heroic", "HeroicSelectionImage", "VolkareLevelDropDown", 2},
								["LegendaryRow"]={"Legendary", "LegendarySelectionImage", "VolkareLevelDropDown", 3},
								["FairRow"]={"Fair", "FairSelectionImage", "VolkareRaceDropDown", 1},
								["TightRow"]={"Tight", "TightSelectionImage", "VolkareRaceDropDown", 2},
								["ThrillingRow"]={"Thrilling", "ThrillingSelectionImage", "VolkareRaceDropDown", 3},
								["ConquestRow"]={"Conquest", "ConquestSelectionImage", "ScenarioDropDown"},
								["FirstReconnaissanceRow"]={"First Reconnaissance", "FirstReconnaissanceSelectionImage", "ScenarioDropDown"},
								["FirstConquestRow"]={"First Conquest", "FirstConquestSelectionImage", "ScenarioDropDown"},
								["MinesLiberationRow"]={"Mines Liberation", "MinesLiberationSelectionImage", "ScenarioDropDown"},
								["DruidNightsRow"]={"Druid Nights", "DruidNightsSelectionImage", "ScenarioDropDown"},
								["DungeonLordsRow"]={"Dungeon Lords", "DungeonLordsSelectionImage", "ScenarioDropDown"},
								["ConquerAndHoldRow"]={"Conquer and Hold", "ConquerAndHoldSelectionImage", "ScenarioDropDown"},
								["OneToReturnRow"]={"One to Return", "OneToReturnSelectionImage", "ScenarioDropDown"},
								["VolkaresReturnRow"]={"Volkare's Return", "VolkaresReturnSelectionImage", "ScenarioDropDown"},
								["VolkaresQuestRow"]={"Volkare's Quest", "VolkaresQuestSelectionImage", "ScenarioDropDown"},
								["LifeAndDeathRow"]={"Life and Death", "LifeAndDeathSelectionImage", "ScenarioDropDown"},
								["TheRealmOfTheDeadRow"]={"The Realm of the Dead Blitz", "TheRealmOfTheDeadSelectionImage", "ScenarioDropDown"},
								["TheHiddenValleyRow"]={"The Hidden Valley Blitz", "TheHiddenValleySelectionImage", "ScenarioDropDown"},
								["AgainsttheApocalypseRow"]={"Against the Apocalypse Blitz", "AgainsttheApocalypseSelectionImage", "ScenarioDropDown"},
								["AgainsttheHorsemenRow"]={"Against the Horsemen Blitz", "AgainsttheHorsemenSelectionImage", "ScenarioDropDown"},
								["AgainsttheDragonRow"]={"Against the Dragon Blitz", "AgainsttheDragonSelectionImage", "ScenarioDropDown"},
								["ApocalypseIsHereRow"]={"Apocalypse is Here", "ApocalypseIsHereSelectionImage", "ScenarioDropDown"},
								["FuryOfTheApocalypseDragonRow"]={"Fury of the Apocalypse Dragon", "FuryOfTheApocalypseDragonSelectionImage", "ScenarioDropDown"},
								["TheLostRelicRow"]={"The Lost Relic Blitz", "TheLostRelicSelectionImage", "ScenarioDropDown"},
								["TheGauntletRow"]={"The Gauntlet", "TheGauntletSelectionImage", "ScenarioDropDown"},
								["QuestForTheGoldenGrailRow"]={"Quest for the Golden Grail", "QuestForTheGoldenGrailSelectionImage", "ScenarioDropDown"},
								["TheChaosRiftRow"]={"The Chaos Rift", "TheChaosRiftSelectionImage", "ScenarioDropDown"},
								["UltimateConquestRow"]={"Ultimate Conquest", "UltimateConquestSelectionImage", "ScenarioDropDown"},
								["FastForwardedConquestRow"]={"Fast Forwarded Conquest", "FastForwardedConquestSelectionImage", "ScenarioDropDown"},
								["TheWarOfFourRow"]={"The War of Four", "TheWarOfFourSelectionImage", "ScenarioDropDown"},
								["RaidersOfTheCrusaderTempleRow"]={"Raiders of the Crusader Temple", "RaidersOfTheCrusaderTempleSelectionImage", "ScenarioDropDown"},
								["ForTheCouncilRow"]={"For the Council", "ForTheCouncilSelectionImage", "ScenarioDropDown"},
								["TheFracturedLandsRow"]={"The Fractured Lands Blitz", "TheFracturedLandsSelectionImage", "ScenarioDropDown"},
								["CustomRow"]={"Custom", "CustomSelectionImage", "ScenarioDropDown"},
								["ROTF0Row"]={"Not Used", "ROTF0SelectionImage", "ROTFDropDown"},
								["ROTF1Row"]={"1. New Beginning", "ROTF1SelectionImage", "ROTFDropDown"},
								["ROTF2Row"]={"2. Spoils of War", "ROTF2SelectionImage", "ROTFDropDown"},
								["ROTF3Row"]={"3. Elixir of Life", "ROTF3SelectionImage", "ROTFDropDown"}}
			local count=0
			for UiId, data in pairs(dropDownData) do
				UI.setAttribute(data[2], "image", "Sliced Button/Button New Active")
				local skip=false
				if data[1]=="All Skills" and IDConvert[id][1]~=5 then skip=true end
				if customMages[data[1]]~=nil and gStates.useCustomMageKnights==false then skip=true end
				--if data[1]=="Jormund" and gStates.riseOfTheForgemasters~=3 then skip=true end
				if IDConvert[id][2]=="MageDropDown" and (data[3]=="VolkareLevelDropDown" or data[3]=="VolkareRaceDropDown" or data[3]=="ScenarioDropDown" or data[3]=="ROTFDropDown") then skip=true end
				if IDConvert[id][2]=="VolkareLevelDropDown" and (data[3]=="MageDropDown" or data[3]=="VolkareRaceDropDown" or data[3]=="ScenarioDropDown" or data[3]=="ROTFDropDown") then skip=true end
				if IDConvert[id][2]=="VolkareRaceDropDown" and (data[3]=="MageDropDown" or data[3]=="VolkareLevelDropDown" or data[3]=="ScenarioDropDown" or data[3]=="ROTFDropDown") then skip=true end
				if IDConvert[id][2]=="ScenarioDropDown" and (data[3]=="MageDropDown" or data[3]=="VolkareLevelDropDown" or data[3]=="VolkareRaceDropDown" or data[3]=="ROTFDropDown") then skip=true end
				if IDConvert[id][2]=="ROTFDropDown" and (data[3]=="MageDropDown" or data[3]=="VolkareLevelDropDown" or data[3]=="VolkareRaceDropDown" or data[3]=="ScenarioDropDown") then skip=true end
				if IDConvert[id][2]=="MageDropDown" then
					for x=1, 5, 1 do
						if gStates.positionMageKnight[x]==data[1] and data[1]~="nobody" and data[1]~="Random" then skip=true end
						if IDConvert[id][1]==x and gStates.positionMageKnight[x]==data[1] then skip=true end
						if IDConvert[id][1]==x and gStates.positionMageKnight[x]==data[1] then UI.setAttribute(data[2], "image", "Sliced Button/Button New Active") end
					end
				end
				--if data[1]==gStates.gameScenario then skip=true end
				if data[1]==gStates.gameScenario then UI.setAttribute(data[2], "image", "Sliced Button/Button New Deactive") end
				if data[3]=="VolkareLevelDropDown" and data[4]==gStates.volkareCombatLevel then UI.setAttribute(data[2], "image", "Sliced Button/Button New Active") end
				if data[3]=="VolkareRaceDropDown" and data[4]==gStates.volkareRaceLevel then UI.setAttribute(data[2], "image", "Sliced Button/Button New Active") end
				if skip==false then UI.setAttribute(UiId, "active", "true") count=count+1 else UI.setAttribute(UiId, "active", "false") end
			end
			UI.setAttribute(id.."Image", "image", "Sliced Button/Button New Deactive")
			local dropDownHeight=count*(330/12)
			--Scenario rows are 30 px high; use an exact whole-row height to avoid pixel gaps.
			if IDConvert[id][2]=="ScenarioDropDown" then dropDownHeight=count*30 end
			UI.setAttribute("DropDown", "height", tostring(dropDownHeight))
			UI.setAttribute("DropDown", "width", "120")
			if IDConvert[id][2]=="ScenarioDropDown" then UI.setAttribute("DropDown", "width", "220") end
			if IDConvert[id][2]=="ROTFDropDown" then UI.setAttribute("DropDown", "width", "150") end
			UI.setAttribute("DropDown", "offsetXY", "-100 "..tostring(IDConvert[id][3]))
			UI.setAttribute("DropDown", "active", "true")
		end
	end
end

function PlayerChosen(player, mouseButton, id)
	if mouseButton=="-1" then
		local IDConvert={	["nobodySelection"]="nobody",
							["AllSkillsSelection"]="All Skills",
							["RANDOMSelection"]="Random",
							["ArytheaSelection"]="Arythea",
							["GoldyxSelection"]="Goldyx",
							["NorowasSelection"]="Norowas",
							["TovakSelection"]="Tovak",
							["BraevalarSelection"]="Braevalar",
							["KrangSelection"]="Krang",
							["WolfhawkSelection"]="Wolfhawk",
							["CoralSelection"]="Coral",
							["YmirghSelection"]="Ymirgh",
							["MevokSelection"]="Mevok",
							["DusceniaSelection"]="Duscenia",
							["JormundSelection"]="Jormund",
							["MalekSelection"]="Malek",
							["ZirtaeSelection"]="Zirtae"}
		UI.setAttribute(dropDownIdLink.."Text", "text", translateWord[IDConvert[id]])
		UI.setAttribute(dropDownIdLink.."Image", "image", "Sliced Button/Button New Active")
		UI.setAttribute("DropDown", "active", "false")
		--adjust number of players
		local MKDropDownUI={["firstMKSelection"]=1, ["secondMKSelection"]=2, ["thirdMKSelection"]=3, ["fourthMKSelection"]=4, ["dummyMKSelection"]=5}
		if dropDownIdLink~="dummyMKSelection" then
			if IDConvert[id]=="nobody" then
				if gStates.playerCount>0 then gStates.playerCount=gStates.playerCount-1 end
			else
				if gStates.positionMageKnight[MKDropDownUI[dropDownIdLink]]=="nobody" then gStates.playerCount=gStates.playerCount+1 end
			end
		end
		if dropDownIdLink=="dummyMKSelection" and gStates.positionMageKnight[MKDropDownUI[dropDownIdLink]]=="Volkare" then
			gStates.volkareSkills=IDConvert[id]
			gStates.setupDummyMageChoice=IDConvert[id]
		else
			gStates.positionMageKnight[MKDropDownUI[dropDownIdLink]]=IDConvert[id]
			if dropDownIdLink=="dummyMKSelection" then gStates.setupDummyMageChoice=IDConvert[id] end
		end

		--Locks player mage choice when scenario player cap reached
		if IDConvert[id]=="Jormund" then
			UI.setAttribute("ROTFSelectionText", "text", "{en}3. Elixir of Life{ru}3. Эликсир Жизни{zh-tw}⽣命靈藥{zh-cn}⽣命灵药{ko}3.생명의 엘릭서{es}3. El Elixir de la Vida{fr}3. Élixir de vie{pt-br}3. Elixir da Vida{de}3. Lebenselixier")
			gStates.riseOfTheForgemasters=3
			applyForgemasterExpansionRequirements()
		end
		if IDConvert[id]~="nobody" and ((dropDownIdLink=="dummyMKSelection" and gStates.playerCount==1)
		or (dropDownIdLink~="dummyMKSelection" and gStates.playerCount==1 and (gStates.positionMageKnight[5]~="nobody" or gStates.gameScenario=="First Conquest" or gStates.gameScenario=="Fast Forwarded Conquest" or gStates.gameScenario=="The Gauntlet" or gStates.gameScenario=="The Chaos Rift" or gStates.gameScenario=="Quest for the Golden Grail")))
		and (gStates.gameScenario=="First Reconnaissance" or gStates.gameScenario=="First Conquest" or gStates.gameScenario=="Fast Forwarded Conquest" or gStates.gameScenario=="Quest for the Golden Grail" or gStates.gameScenario=="The Chaos Rift" or gStates.gameScenario=="The Gauntlet" or gStates.gameScenario=="Druid Nights" or gStates.gameScenario=="Dungeon Lords" or gStates.gameScenario=="Mines Liberation") then
			for a, pos in pairs(MKDropDownUI) do
				if gStates.positionMageKnight[pos]=="nobody" then
					UI.setAttribute(a, "interactable", "False")
					UI.setAttribute(a, "text", "{en}nobody{ru}никто{zh-tw}無玩家{zh-cn}无玩家{ko}없음{es}ninguno{fr}personne{pt-br}ninguém{de}Niemand")
					UI.setAttribute(a.."Image", "image", "Sliced Button/Button New Deactive")
				end
			end
		else
			for a, pos in pairs(MKDropDownUI) do
				UI.setAttribute(a, "interactable", "True")
				UI.setAttribute(a.."Image", "image", "Sliced Button/Button New Active")
			end
		end
		--locks Dummy Mage choice for scenario setups that don't use him
		if (dropDownIdLink~="dummyMKSelection" and ((gStates.playerCount>=2 and IDConvert[id]~="nobody") or (gStates.playerCount>=2 and IDConvert[id]=="nobody"))
		and (gStates.gameScenario=="First Reconnaissance" or gStates.gameScenario=="Quest for the Golden Grail" or gStates.gameScenario=="The Chaos Rift" or gStates.gameScenario=="The Gauntlet" or gStates.gameScenario=="Druid Nights" or gStates.gameScenario=="Dungeon Lords" or gStates.gameScenario=="Mines Liberation"))
		or (gStates.gameScenario=="Conquer and Hold" or gStates.gameScenario=="One to Return") then--or gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz" or gStates.gameScenario=="Volkare's Quest" or gStates.gameScenario=="The War of Four"
			UI.setAttribute("dummyMKSelection", "interactable", "False")
			UI.setAttribute("dummyMKSelectionImage", "image", "Sliced Button/Button New Deactive")
		else
			UI.setAttribute("dummyMKSelection", "interactable", "True")
			UI.setAttribute("dummyMKSelectionImage", "image", "Sliced Button/Button New Active")
		end
		refreshProxySetupLabel()
		ToolTipUpdate(IDConvert[id])
		--Set Coop flag
		if gStates.positionMageKnight[5]=="nobody" then gStates.coop=0 UI.setAttribute("StartButtonText", "text", "{en}Start - Competitive{ru}Начало - Соревновательный{zh-tw}開始 - 對抗模式{zh-cn}开始 - 对抗模式{ko}시작 - 경쟁{es}Comenzar - Competitivo{fr}Démarrer - Compétitif{pt-br}Início - Competitivo{de}Start - Wettbewerbsfähig") else gStates.coop=1 UI.setAttribute("StartButtonText", "text", "{en}Start - Cooperative{ru}Начало - Кооперативный{zh-tw}開始 - 合作模式{zh-cn}开始 - 合作模式{ko}시작 - 협력{es}Comenzar - Cooperativo{fr}Démarrer - Coopératif{pt-br}Início - Cooperativo{de}Start - Genossenschaft") end
		if gStates.playerCount==1 then UI.setAttribute("StartButtonText", "text", "{en}Start - Solo{ru}Начало - Одиночный{zh-tw}開始 - 單人遊戲{zh-cn}开始 - 单人游戏{ko}시작 - 솔로{es}Comenzar - Solo{fr}Démarrer - Solo{pt-br}Início - Solo{de}Start - Solo") end
		--reset megapolis
		gStates.megapolis=0
		scenarioInfoUpdate()
		dropDownIdLink="none"
	end
end

function VolkareLevelSelection(player, mouseButton, id)
	if mouseButton=="-1" then
		local IDConvert={	["DaringSelection"]={"Daring", 1},
							["HeroicSelection"]={"Heroic", 2},
							["LegendarySelection"]={"Legendary", 3}}
		UI.setAttribute("VolkareLevelSelectionText", "text", translateWord[IDConvert[id][1]])
		UI.setAttribute("VolkareLevelSelectionImage", "image", "Sliced Button/Button New Active")
		UI.setAttribute("DropDown", "active", "false")
		gStates.volkareCombatLevel=IDConvert[id][2]
		--adjust city levels of volkare scenarios
		local cityAdjust=	{{["Volkare's Return"]={{4,5}, {6,10}, {8,15}, {10,20}}, ["Volkare's Return Blitz"]={{3,4}, {4,8}, {5,12}, {6,16}}, ["Volkare's Quest"]={{3,3,8}, {4,4,14}, {4,4,4,20}, {5,5,5,26}}, ["The War of Four"]={{2,2,4,4,16}, {4,4,6,6,32}, {6,6,8,8,46}, {8,8,10,10,58}}}, --daring
							{["Volkare's Return"]={{6,8}, {9,16}, {12,24}, {16,32}}, ["Volkare's Return Blitz"]={{4,6}, {6,12}, {8,18}, {10,24}}, ["Volkare's Quest"]={{4,4,10}, {4,4,18}, {5,5,5,26}, {5,5,5,34}}, ["The War of Four"]={{3,3,6,6,18}, {5,5,9,9,36}, {8,8,12,12,52}, {10,10,15,15,66}}}, --Heroic
							{["Volkare's Return"]={{10,12}, {14,24}, {18,36}, {22,48}}, ["Volkare's Return Blitz"]={{5,8}, {8,16}, {11,24}, {14,32}}, ["Volkare's Quest"]={{4,4,14}, {5,5,26}, {5,5,5,38}, {6,6,6,50}}, ["The War of Four"]={{4,4,8,8,22}, {6,6,12,12,44}, {10,10,16,16,64}, {12,12,20,20,72}}}}--Legendary
							--Volkare's Return, 							Volkare's Return Blitz, 					Volkare's Quest.
		for a=1, 4, 1 do
			for b=1, #cityAdjust[gStates.volkareCombatLevel][gStates.gameScenario][a], 1 do
				scenarioList[gStates.scenarioRef][a+4].cityLevels[b]=cityAdjust[gStates.volkareCombatLevel][gStates.gameScenario][a][b]
			end
		end
		scenarioInfoUpdate()
		ToolTipUpdate(dropDownIdLink)
		dropDownIdLink="none"
	end
end

function VolkareRaceSelection(player, mouseButton, id)
	if mouseButton=="-1" then
		local IDConvert={	["FairSelection"]={"Fair", 1},
							["TightSelection"]={"Tight", 2},
							["ThrillingSelection"]={"Thrilling", 3}}
		UI.setAttribute("VolkareRaceSelectionText", "text", translateWord[IDConvert[id][1]])
		UI.setAttribute("VolkareRaceSelectionImage", "image", "Sliced Button/Button New Active")
		UI.setAttribute("DropDown", "active", "false")
		gStates.volkareRaceLevel=IDConvert[id][2]
		scenarioInfoUpdate()
		ToolTipUpdate(dropDownIdLink)
		dropDownIdLink="none"
	end
end

function ToolTipUpdate(id)
	UI.show("toolTip")
	UI.setAttribute("toolTipTitle", "text", tooltip[id].title)
	UI.setAttribute("toolTipText", "text", tooltip[id].text)
	UI.setAttribute("toolTip", "height", tooltip[id].height)
end

function scenarioMapIsPredefined()
	local scenario=gStates~=nil and scenarioList[gStates.scenarioRef] or nil
	local setup=scenario~=nil and scenario[gStates.playersRef] or nil
	--Custom Predefined is a player-built sandbox, so only scenario-owned predefined maps lock these setup controls.
	return setup~=nil and setup.mapShapeKey=="predefined" and gStates.gameScenario~="Custom"
end

function refreshScenarioTerrainTweakLocks()
	local locked=scenarioMapIsPredefined()
	for _,control in ipairs({"MapDown","MapUp","CountryDown","CountryUp","CoreDown","CoreUp","CityDown","CityUp"}) do
		UI.setAttribute(control,"interactable",locked and "False" or "True")
		UI.setAttribute(control.."Image","image",locked and "Sliced Button/Button New Deactive" or "Sliced Button/Button New Active")
	end
end

function baseValueTweak(player, mouseButton, id)
	if mouseButton=="-1" then
		if scenarioMapIsPredefined() and (id=="MapDown" or id=="MapUp" or id=="CountryDown" or id=="CountryUp" or id=="CoreDown" or id=="CoreUp" or id=="CityDown" or id=="CityUp") then return end
		if gStates.volkareCampAsCity==true and (id=="MegapolisDown" or id=="MegapolisUp") then return end
		if gStates.gameScenario~="First Reconnaissance" then
			if id=="RoundsDown" or id=="RoundsUp" then
				if id=="RoundsDown" then
					if scenarioList[gStates.scenarioRef][gStates.playersRef].rounds>1 then
						scenarioList[gStates.scenarioRef][gStates.playersRef].rounds=scenarioList[gStates.scenarioRef][gStates.playersRef].rounds-1
					end
				else
					scenarioList[gStates.scenarioRef][gStates.playersRef].rounds=scenarioList[gStates.scenarioRef][gStates.playersRef].rounds+1
				end
				scenarioList[gStates.scenarioRef][gStates.playersRef].discardTactics=scenarioList[gStates.scenarioRef][gStates.playersRef].dTW
				if scenarioList[gStates.scenarioRef][gStates.playersRef].rounds>6 and scenarioList[gStates.scenarioRef][gStates.playersRef].discardTactics==2 then scenarioList[gStates.scenarioRef][gStates.playersRef].discardTactics=1 end
				if scenarioList[gStates.scenarioRef][gStates.playersRef].rounds>14-(2*(gStates.playerCount+gStates.coop)) and scenarioList[gStates.scenarioRef][gStates.playersRef].discardTactics==1 then scenarioList[gStates.scenarioRef][gStates.playersRef].discardTactics=0 end
			end

			if id=="MapDown" or id=="MapUp" then
				local mapShapes={"wedge","open3","open4","open"}
				if gStates.gameScenario=="Custom" then mapShapes[#mapShapes+1]="predefined" end
				local setup=scenarioList[gStates.scenarioRef][gStates.playersRef]
				for a=1,#mapShapes do
					if setup.mapShapeKey==mapShapes[a] then
						local b=id=="MapDown" and a-1 or a+1
						if b<1 then b=#mapShapes elseif b>#mapShapes then b=1 end
						setup.mapShapeKey=mapShapes[b]
						setup.mapShape=mapShapeText[setup.mapShapeKey]
						if setup.mapShapeKey~="wedge" and setup.countryTiles==2 then setup.countryTiles=3 end
						break
					end
				end
			end

			if id=="CountryDown" or id=="CountryUp" then
				if id=="CountryDown" then
					countryMin=3
					if scenarioList[gStates.scenarioRef][gStates.playersRef].mapShapeKey=="wedge" then countryMin=4 end--Enough to get to the legal core positions
					if scenarioList[gStates.scenarioRef][gStates.playersRef].countryTiles>countryMin then
						scenarioList[gStates.scenarioRef][gStates.playersRef].countryTiles=scenarioList[gStates.scenarioRef][gStates.playersRef].countryTiles-1
					end
				else
					local max=14
					if gStates.removeTerrain==true then max=max-2 end
					if gStates.removeApocalypseTerrain~=true then max=max+3 end
					if gStates.removeLostLegionExpansion==true then max=max-3 end
					if scenarioList[gStates.scenarioRef][gStates.playersRef].countryTiles<max then
						scenarioList[gStates.scenarioRef][gStates.playersRef].countryTiles=scenarioList[gStates.scenarioRef][gStates.playersRef].countryTiles+1
					end
				end
			end

			if id=="CoreDown" or id=="CoreUp" then
				if id=="CoreDown" then
					if scenarioList[gStates.scenarioRef][gStates.playersRef].coreTiles>0 then
						scenarioList[gStates.scenarioRef][gStates.playersRef].coreTiles=scenarioList[gStates.scenarioRef][gStates.playersRef].coreTiles-1
					end
				else
					local max=6
					if gStates.removeApocalypseTerrain~=true then max=max+2 end
					if gStates.removeLostLegionExpansion==true then max=max-2 end
					if scenarioList[gStates.scenarioRef][gStates.playersRef].coreTiles<max then
						scenarioList[gStates.scenarioRef][gStates.playersRef].coreTiles=scenarioList[gStates.scenarioRef][gStates.playersRef].coreTiles+1
					end
				end
			end

			if (id=="CityDown" or id=="CityUp") and gStates.gameScenario~="The Gauntlet" and gStates.gameScenario~="Volkare's Return" and gStates.gameScenario~="First Conquest" and gStates.gameScenario~="Conquer and Hold" then
				local setup=scenarioList[gStates.scenarioRef][gStates.playersRef]
				local cityTiles=setup.cityTiles
				local minimum=gStates.gameScenario=="Custom" and 0 or 1
				if id=="CityDown" then
					if cityTiles>minimum then
						setup.cityTiles=cityTiles-1
						--Custom keeps one hidden level value at zero cities because it also sets the
						--Shades of Tezla faction leaders. Other scenarios remove the final city level normally.
						if gStates.gameScenario=="Custom" and setup.cityTiles==0 then
							if setup.cityLevels[1]~=nil and setup.cityLevels[1]>12 then setup.cityLevels[1]=12 end
						else
							table.remove(setup.cityLevels)
						end
						gStates.megapolis=0
					end
				else
					local max=5
					if gStates.removeLostLegionExpansion==true or gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz" or gStates.gameScenario=="Volkare's Quest" or gStates.gameScenario=="The War of Four" then max=4 end
					if cityTiles<max then
						setup.cityTiles=cityTiles+1
						--At zero cities Custom's remaining value is the faction-leader level. The
						--first city reuses that same value; later cities duplicate the last city level.
						if not (gStates.gameScenario=="Custom" and cityTiles==0) then
							if setup.cityLevels[#setup.cityLevels]>22 then setup.cityLevels[#setup.cityLevels]=22 end
							table.insert(setup.cityLevels, setup.cityLevels[#setup.cityLevels])
						end
						gStates.megapolis=0
					end
				end
			end
			if id=="MegapolisDown" or id=="MegapolisUp" then
				if id=="MegapolisDown" then
					if gStates.megapolis>0 then gStates.megapolis=gStates.megapolis-1 end
					if gStates.megapolis==0 and scenarioList[gStates.scenarioRef][gStates.playersRef].cityLevels[#scenarioList[gStates.scenarioRef][gStates.playersRef].cityLevels]>22 then scenarioList[gStates.scenarioRef][gStates.playersRef].cityLevels[#scenarioList[gStates.scenarioRef][gStates.playersRef].cityLevels]=22 end
					if gStates.megapolis==1 and scenarioList[gStates.scenarioRef][gStates.playersRef].cityLevels[#scenarioList[gStates.scenarioRef][gStates.playersRef].cityLevels-1]>22 then scenarioList[gStates.scenarioRef][gStates.playersRef].cityLevels[#scenarioList[gStates.scenarioRef][gStates.playersRef].cityLevels-1]=22 end
				else
					local megapolisMaximum=megapolisMaximumForSetup(gStates.scenarioRef,gStates.playersRef)
					if gStates.megapolis<megapolisMaximum then gStates.megapolis=gStates.megapolis+1 ensureSetupMegapolisMinimumLevels() end
				end
			end

			for a=1, 5, 1 do
				if id=="CityLevel"..a.."Down" or id=="CityLevel"..a.."Up" then
					if scenarioList[gStates.scenarioRef][gStates.playersRef].cityLevels[a]>0 then
						if id=="CityLevel"..a.."Down" then
							local min=1
							if gStates.megapolis==2 or (gStates.megapolis==1 and scenarioList[gStates.scenarioRef][gStates.playersRef].cityTiles==a) then min=2 end
							if scenarioList[gStates.scenarioRef][gStates.playersRef].cityLevels[a]>min then
								scenarioList[gStates.scenarioRef][gStates.playersRef].cityLevels[a]=scenarioList[gStates.scenarioRef][gStates.playersRef].cityLevels[a]-1
							else
								break
							end
						else
							local max=22
							if gStates.megapolis==2 or (gStates.megapolis==1 and scenarioList[gStates.scenarioRef][gStates.playersRef].cityTiles==a) then max=22 end
							if gStates.gameScenario=="Life and Death" or gStates.gameScenario=="The Realm of the Dead Blitz" or gStates.gameScenario=="The Hidden Valley Blitz" or
								(gStates.gameScenario=="Custom" and scenarioList[gStates.scenarioRef][gStates.playersRef].cityTiles==0) then max=12 end
							if a==scenarioList[gStates.scenarioRef][gStates.playersRef].cityTiles+1 and
								(gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz" or gStates.gameScenario=="Volkare's Quest" or gStates.gameScenario=="The War of Four") then max=80 end
							if scenarioList[gStates.scenarioRef][gStates.playersRef].cityLevels[a]<max then
								scenarioList[gStates.scenarioRef][gStates.playersRef].cityLevels[a]=scenarioList[gStates.scenarioRef][gStates.playersRef].cityLevels[a]+1
							else
								break
							end
						end
						if gStates.gameScenario=="Life and Death" and (a==1 or a==2) then
							if a==1 then
								scenarioList[gStates.scenarioRef][gStates.playersRef].cityLevels[2]=scenarioList[gStates.scenarioRef][gStates.playersRef].cityLevels[1]
							else
								scenarioList[gStates.scenarioRef][gStates.playersRef].cityLevels[1]=scenarioList[gStates.scenarioRef][gStates.playersRef].cityLevels[2]
							end
						end
					end
				end
			end
		end
		scenarioInfoUpdate()
	end
end

function setupScenarioMaxMageKnights()
	--These scenarios are always solo. The other limited scenarios only become solo when a dummy is selected.
	if gStates.gameScenario=="First Conquest" or gStates.gameScenario=="Fast Forwarded Conquest" or
		gStates.gameScenario=="Quest for the Golden Grail" or gStates.gameScenario=="The Chaos Rift" or gStates.gameScenario=="The Gauntlet" then return 1 end
	if gStates.positionMageKnight[5]~="nobody" and (gStates.gameScenario=="First Reconnaissance" or gStates.gameScenario=="Druid Nights" or
		gStates.gameScenario=="Dungeon Lords" or gStates.gameScenario=="Mines Liberation") then return 1 end
	return 4
end

function refreshMageKnightSetupAvailability()
	local MKDropDownUI={"firstMKSelection", "secondMKSelection", "thirdMKSelection", "fourthMKSelection"}
	gStates.playerCount=0
	local customSelected=false
	local jormundSelected=false
	for a=1,4 do
		local mage=gStates.positionMageKnight[a] or "nobody"
		if mage~="nobody" then gStates.playerCount=gStates.playerCount+1 end
		if customMages[mage]~=nil then customSelected=true end
		if mage=="Jormund" then jormundSelected=true end
	end
	local rememberedDummy=gStates.setupDummyMageChoice or (gStates.positionMageKnight[5]=="Volkare" and gStates.volkareSkills) or gStates.positionMageKnight[5]
	if customMages[rememberedDummy]~=nil then customSelected=true end
	if rememberedDummy=="Jormund" then jormundSelected=true end
	gStates.coop=gStates.positionMageKnight[5]~="nobody" and 1 or 0

	local maxPlayers=setupScenarioMaxMageKnights()
	for a=1,4 do
		local available=gStates.positionMageKnight[a]~="nobody" or gStates.playerCount<maxPlayers
		UI.setAttribute(MKDropDownUI[a], "interactable", available and "True" or "False")
		UI.setAttribute(MKDropDownUI[a].."Image", "image", available and "Sliced Button/Button New Active" or "Sliced Button/Button New Deactive")
	end

	local dummyLocked=gStates.gameScenario=="Conquer and Hold" or gStates.gameScenario=="One to Return"
	local dummyPlayerLimited=gStates.gameScenario=="First Reconnaissance" or gStates.gameScenario=="Quest for the Golden Grail" or
		gStates.gameScenario=="The Chaos Rift" or gStates.gameScenario=="The Gauntlet" or gStates.gameScenario=="Druid Nights" or
		gStates.gameScenario=="Dungeon Lords" or gStates.gameScenario=="Mines Liberation"
	local dummyAvailable=not dummyLocked and (gStates.positionMageKnight[5]=="Volkare" or not dummyPlayerLimited or gStates.playerCount<2)
	UI.setAttribute("dummyMKSelection", "interactable", dummyAvailable and "True" or "False")
	UI.setAttribute("dummyMKSelectionImage", "image", dummyAvailable and "Sliced Button/Button New Active" or "Sliced Button/Button New Deactive")

	--Retained optional Mage Knights keep the options they require when the scenario defaults are rebuilt.
	if customSelected then
		gStates.useCustomMageKnights=true
		UI.setAttribute("useCustomMageKnights", "isOn", "true")
	end
	if jormundSelected then
		gStates.riseOfTheForgemasters=3
		UI.setAttribute("ROTFSelectionText", "text", "{en}3. Elixir of Life{ru}3. Эликсир Жизни{zh-tw}⽣命靈藥{zh-cn}⽣命灵药{ko}3.생명의 엘릭서{es}3. El Elixir de la Vida{fr}3. Élixir de vie{pt-br}3. Elixir da Vida{de}3. Lebenselixier")
		applyForgemasterExpansionRequirements()
	end
end

function refreshSetupStartButton()
	refreshMageKnightSetupAvailability()
	UI.setAttribute("WarOfFourStartButton", "active", "false")
	UI.setAttribute("StartButton", "active", "false")
	UI.setAttribute("StartButton", "width", "1000")
	local tooMany=gStates.playerCount>setupScenarioMaxMageKnights()
	local heroChallengeLegal,heroChallengeReason=heroChallengeSetupLegal()
	if tooMany then
		UI.setAttribute("StartButton", "interactable", "False")
		UI.setAttribute("StartButtonImage", "image", "Sliced Button/Button New Deactive")
		UI.setAttribute("StartButtonText", "text", "{en}Too Many Mage Knights{ru}Слишком много Рыцарей-магов{zh-tw}魔法騎士過多{zh-cn}魔法骑士过多{ko}메이지 나이트가 너무 많습니다{es}Demasiados Mage Knights{fr}Trop de Mage Knights{pt-br}Mage Knights demais{de}Zu viele Mage Knights")
		UI.setAttribute("StartButton", "active", "true")
	elseif heroChallengeLegal~=true then
		UI.setAttribute("StartButton", "interactable", "False")
		UI.setAttribute("StartButtonImage", "image", "Sliced Button/Button New Deactive")
		UI.setAttribute("StartButtonText", "text", heroChallengeReason or "{en}Hero Challenges: Invalid setup{ru}Испытания героев: недопустимая настройка{zh-tw}英雄挑戰：無效設置{zh-cn}英雄挑战：无效设置{ko}영웅 도전: 잘못된 설정{es}Desafíos de Héroes: configuración no válida{fr}Défis des Héros : configuration invalide{pt-br}Desafios de Heróis: configuração inválida{de}Heldenherausforderungen: ungültiger Aufbau")
		UI.setAttribute("StartButton", "active", "true")
	elseif gStates.playerCount>=2 or (gStates.playerCount>=1 and gStates.positionMageKnight[5]~="nobody") then
		UI.setAttribute("StartButton", "interactable", "True")
		UI.setAttribute("StartButtonImage", "image", "Sliced Button/Button New Active")
		if gStates.playerCount==1 then
			UI.setAttribute("StartButtonText", "text", "{en}Start - Solo{ru}Начало - Одиночный{zh-tw}開始 - 單人遊戲{zh-cn}开始 - 单人游戏{ko}시작 - 솔로{es}Comenzar - Solo{fr}Démarrer - Solo{pt-br}Início - Solo{de}Start - Solo")
		elseif gStates.positionMageKnight[5]=="nobody" then
			UI.setAttribute("StartButtonText", "text", "{en}Start - Competitive{ru}Начало - Соревновательный{zh-tw}開始 - 對抗模式{zh-cn}开始 - 对抗模式{ko}시작 - 경쟁{es}Comenzar - Competitivo{fr}Démarrer - Compétitif{pt-br}Início - Competitivo{de}Start - Wettbewerbsfähig")
		else
			UI.setAttribute("StartButtonText", "text", "{en}Start - Cooperative{ru}Начало - Кооперативный{zh-tw}開始 - 合作模式{zh-cn}开始 - 合作模式{ko}시작 - 협력{es}Comenzar - Cooperativo{fr}Démarrer - Coopératif{pt-br}Início - Cooperativo{de}Start - Genossenschaft")
		end
		if gStates.gameScenario=="The War of Four" and gStates.playerCount>=2 then
			UI.setAttribute("WarOfFourStartButton", "active", "True")
			UI.setAttribute("StartButton", "width", "500")
		end
		UI.setAttribute("StartButton", "active", "true")
	else
		UI.setAttribute("StartButton", "interactable", "False")
		UI.setAttribute("StartButtonImage", "image", "Sliced Button/Button New Deactive")
		UI.setAttribute("StartButtonText", "text", "{en}Start - Select at least two Mage Knights first{ru}Начало - Сначала выберите как минимум двух Рыцарей-магов.{zh-tw}開始 - 首先選擇至少兩位魔法騎士{zh-cn}开始 - 首先选择两位魔法骑士{ko}시작 - 먼저 두 명 이상의 플레이어를 선택하세요{es}Comenzar - Selecciona al menos dos Mage Knight {fr}Démarrer - Sélectionnez d'abord au moins deux Mages{pt-br}Início - Selecione ao menos dois Mage Knights primeiro{de}Start - Wähle vorher mindestens 2 Mage Knights")
		UI.setAttribute("StartButton", "active", "true")
	end
end

function scenarioInfoUpdate()
	--convert Mage Knight count/setup type to the scenario's matching reference
	gStates.playersRef=setupPlayersRef()
	refreshLostLegionExpansionOption()
	if gStates.megapolis>0 then gStates.volkareCampAsCity=false end
	--Convert Scenario to a reference then read the round count
	for i=1, #scenarioList, 1 do
		if gStates.gameScenario==scenarioList[i][1] then gStates.scenarioRef=i break end
	end
	--Update Scenario Infos
	UI.setAttribute("ScenarioDetails", "Active", "True")
	UI.setAttribute("IntroBoard", "Active", "False")
	UI.setAttribute("ScenarioName", "text", joinLang({translateWord[gStates.gameScenario], "{en} Purpose{ru} Цель{zh-tw} 目的{zh-cn} 目的{ko} 목적{es} Propósito{fr} Objectif{pt-br} Finalidade{de} Zweck"}))
	UI.setAttribute("PlayerCount", "text", scenarioList[gStates.scenarioRef].scenarioDetails.playerDetails)
	UI.setAttribute("ScenarioLength", "text", joinLang({"{en}Length - {ru}Продолжительность - {zh-tw}遊戲時長：{zh-cn}游戏时长：{ko}길이 - {es}Duración - {fr}Longueur - {pt-br}Duração - {de}Länge - ", scenarioList[gStates.scenarioRef][gStates.playersRef].rounds, "{en} Rounds{ru} Раунд(а/ов){zh-tw} 輪次{zh-cn} 轮次{ko}라운드{es} Rondas{fr} Rounds{pt-br} Rodadas{de} Runden"}))
	UI.setAttribute("ScenarioPurpose", "text", scenarioList[gStates.scenarioRef].scenarioDetails.scenarioPurpose)
	UI.setAttribute("ScenarioShape", "text", joinLang({"{en}Map Shape - {ru}Форма поля - {zh-tw}地圖形狀：{zh-cn}地图形状：{ko}지도 모양 - {es}Forma del Mapa - {fr}Forme de la Carte - {pt-br}Formato de Mapa - {de}Karten Form - ", scenarioList[gStates.scenarioRef][gStates.playersRef].mapShape}))
	--Display the amount of country tiles and any rules
	if scenarioList[gStates.scenarioRef].scenarioDetails.countryRules~=nil then
		if scenarioList[gStates.scenarioRef].scenarioDetails.countryRules[1]==nil then
			UI.setAttribute("ScenarioCountry", "text", joinLang({"{en}Country Tiles - {ru}Дикие земли - {zh-tw}鄉村板塊：{zh-cn}乡村板块：{ko}교외 타일 - {es}Losetas de Campo - {fr}Tuiles Pays - {pt-br}Peças de Campo - {de}Land Teile - ", scenarioList[gStates.scenarioRef][gStates.playersRef].countryTiles.." ", scenarioList[gStates.scenarioRef].scenarioDetails.countryRules}))
		else
			UI.setAttribute("ScenarioCountry", "text", joinLang({"{en}Country Tiles - {ru}Дикие земли - {zh-tw}鄉村板塊：{zh-cn}乡村板块：{ko}교외 타일 - {es}Losetas de Campo - {fr}Tuiles Pays - {pt-br}Peças de Campo - {de}Land Teile - ", scenarioList[gStates.scenarioRef][gStates.playersRef].countryTiles.." ", scenarioList[gStates.scenarioRef].scenarioDetails.countryRules[gStates.playersRef]}))
		end
	else
		UI.setAttribute("ScenarioCountry", "text", joinLang({"{en}Country Tiles - {ru}Дикие земли - {zh-tw}鄉村板塊：{zh-cn}乡村板块：{ko}교외 타일 - {es}Losetas de Campo - {fr}Tuiles Pays - {pt-br}Peças de Campo - {de}Land Teile - ", scenarioList[gStates.scenarioRef][gStates.playersRef].countryTiles}))
	end
	--Display the amount of core tiles and any rules
	if scenarioList[gStates.scenarioRef].scenarioDetails.coreRules~=nil then
		UI.setAttribute("ScenarioCore", "text", joinLang({"{en}Core Tiles - {ru}Развитые земли - {zh-tw}核心板塊：{zh-cn}核心板块：{ko}중심부 타일 - {es}Losetas Centrales - {fr}Tuiles de Base - {pt-br}Peças Centrais - {de}Core Teile - ", scenarioList[gStates.scenarioRef][gStates.playersRef].coreTiles.." ", scenarioList[gStates.scenarioRef].scenarioDetails.coreRules}))
	else
		UI.setAttribute("ScenarioCore", "text", joinLang({"{en}Core Tiles - {ru}Развитые земли - {zh-tw}核心板塊：{zh-cn}核心板块：{ko}중심부 타일 - {es}Losetas Centrales - {fr}Tuiles de Base - {pt-br}Peças Centrais - {de}Core Teile - ", scenarioList[gStates.scenarioRef][gStates.playersRef].coreTiles}))
	end
	--Display the amount of city tiles and any rules
	if scenarioList[gStates.scenarioRef].scenarioDetails.cityRules~=nil then
		UI.setAttribute("ScenarioCity", "text", joinLang({"{en}City Tiles - {ru}Земли с городом - {zh-tw}城市板塊：{zh-cn}城市板块：{ko}도시 타일 - {es}Losetas de Ciudad - {fr}Tuiles Ville - {pt-br} Peças Cidade - {de}Stadt Teile - ", scenarioList[gStates.scenarioRef][gStates.playersRef].cityTiles.." ", scenarioList[gStates.scenarioRef].scenarioDetails.cityRules}))
	else
		UI.setAttribute("ScenarioCity", "text", joinLang({"{en}City Tiles - {ru}Земли с городом - {zh-tw}城市板塊：{zh-cn}城市板块：{ko}도시 타일 - {es}Losetas de Ciudad - {fr}Tuiles Ville - {pt-br} Peças Cidade - {de}Stadt Teile - ", scenarioList[gStates.scenarioRef][gStates.playersRef].cityTiles}))
	end
	--Display's City Levels and activates megapolis with the right settings.
	if gStates.megapolis==0 then
		for index, level in pairs(scenarioList[gStates.scenarioRef][gStates.playersRef].cityLevels) do
			if index~=scenarioList[gStates.scenarioRef][gStates.playersRef].cityTiles+1 and (gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz" or gStates.gameScenario=="Volkare's Quest" or gStates.gameScenario=="The War of Four") then
				if level>22 then scenarioList[gStates.scenarioRef][gStates.playersRef].cityLevels[index]=22 end
			end
		end
	end
	UI.setAttribute("MegapolisReminder", "active", "false")
	local megapolisMaximum=megapolisMaximumForSetup(gStates.scenarioRef,gStates.playersRef)
	if gStates.megapolis>megapolisMaximum then gStates.megapolis=megapolisMaximum end
	ensureSetupMegapolisMinimumLevels()
	local currentCitySetup=scenarioList[gStates.scenarioRef][gStates.playersRef]
	local customLeaderOnly=gStates.gameScenario=="Custom" and currentCitySetup.cityTiles==0 and gStates.removeShadesOfTezlaMonsters~=true
	if currentCitySetup.cityLevels[1]~=nil and currentCitySetup.cityLevels[1]>0 and (currentCitySetup.cityTiles>0 or customLeaderOnly) then
		UI.setAttribute("CityNote", "active", "false")
		UI.setAttribute("CityLevelsRow", "active", "true")
		UI.setAttribute("CityDescriptionRow", "active", "false")
		UI.setAttribute("CityLevelschange", "active", "false")
		--local b="<b>City Level(s) - </b>"
		local layout="28"
		if #scenarioList[gStates.scenarioRef][gStates.playersRef].cityLevels>3 or megapolisMaximum==0 then layout="0" end
		for a=1, 5, 1 do
			if a<=#scenarioList[gStates.scenarioRef][gStates.playersRef].cityLevels then
				UI.setAttribute("CL"..a, "active", "true")
				layout=layout.." 0"
				if #scenarioList[gStates.scenarioRef][gStates.playersRef].cityLevels<=3 then
					if (gStates.megapolis==1 and a==scenarioList[gStates.scenarioRef][gStates.playersRef].cityTiles) or (gStates.megapolis==2) and not (a==scenarioList[gStates.scenarioRef][gStates.playersRef].cityTiles+1 and (gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz" or gStates.gameScenario=="Volkare's Quest" or gStates.gameScenario=="The War of Four")) then
						UI.setAttribute("ScenarioCity"..a.."Level", "text", joinLang({"{en}Megapolis, Lvl {ru}Мегаполис, ур. {zh-tw}大型城市，等級 {zh-cn}大型城市，等级 {ko}거대도시, 레벨 {es}Megapolis, Niv {fr}Megapolis, Niv {pt-br}Megápolis, Nvl {de}Metropoe, Lvl ", scenarioList[gStates.scenarioRef][gStates.playersRef].cityLevels[a]}))
					else
						if (customLeaderOnly and a==1) or (a==1 and (gStates.gameScenario=="Life and Death" or gStates.gameScenario=="The Realm of the Dead Blitz" or gStates.gameScenario=="The Hidden Valley Blitz" or gStates.gameScenario=="The War of Four")) or (a==2 and (gStates.gameScenario=="Life and Death" or gStates.gameScenario=="The War of Four")) then
							UI.setAttribute("ScenarioCity"..a.."Level", "text", joinLang({"{en}Leader, Level {ru}Лидер, ур. {zh-tw}領袖，等級 {zh-cn}领袖，等级 {ko}지도자, 레벨 {es}Líder, Nivel {fr}Chef, Niveau {pt-br}Líder, Nível {de}Leiter, Level ", scenarioList[gStates.scenarioRef][gStates.playersRef].cityLevels[a]}))
						else
							if scenarioList[gStates.scenarioRef][gStates.playersRef].cityLevels[a]==0 then
								UI.setAttribute("ScenarioCity"..a.."Level", "text", "{en}Friendly City{ru}Друж. город{zh-tw}友方城市{zh-cn}友方城市{ko}도시(우호적){es}Ciudad Amistosa{fr}Ville Amicale{pt-br}Cidade Amigável{de}Freundliche Stadt")
							else
								if a==scenarioList[gStates.scenarioRef][gStates.playersRef].cityTiles+1 and (gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz" or gStates.gameScenario=="Volkare's Quest" or gStates.gameScenario=="The War of Four") then
									UI.setAttribute("ScenarioCity"..a.."Level", "text", joinLang({"{en}Volkare, Level {ru}Волкар, ур. {zh-tw}沃卡里，等級 {zh-cn}沃卡里，等级 {ko}볼케어, 레벨{es}Volkare, Nivel {fr}Volkare, Niveau {pt-br}Volkare, Nível {de}Volkare, Ebene ", scenarioList[gStates.scenarioRef][gStates.playersRef].cityLevels[a]}))
								else
									UI.setAttribute("ScenarioCity"..a.."Level", "text", joinLang({"{en}City, Level {ru}Город, ур. {zh-tw}城市，等級 {zh-cn}城市，等级 {ko}도시, 레벨 {es}Ciudad, Nivel {fr}Ville, Niveau {pt-br}Cidade, Nível {de}Stadt, Level ", scenarioList[gStates.scenarioRef][gStates.playersRef].cityLevels[a]}))
								end
							end
						end
					end
					if megapolisMaximum>0 then
						UI.setAttribute("MegapolisLeft", "active", "true")
						UI.setAttribute("MegapolisRight", "active", "true")
						local canUp=gStates.megapolis<megapolisMaximum
						local canDown=gStates.megapolis>0
						UI.setAttribute("MegapolisUp", "interactable", canUp and "True" or "False") UI.setAttribute("MegapolisDown", "interactable", canDown and "True" or "False")
						UI.setAttribute("MegapolisUpImage", "image", canUp and "Sliced Button/Button New Active" or "Sliced Button/Button New Deactive") UI.setAttribute("MegapolisDownImage", "image", canDown and "Sliced Button/Button New Active" or "Sliced Button/Button New Deactive")
						UI.setAttribute("MegapolisReminder", "active", "true")
					else
						UI.setAttribute("MegapolisLeft", "active", "false")
						UI.setAttribute("MegapolisRight", "active", "false")
						UI.setAttribute("MegapolisReminder", "active", "false")
					end
				else
					if (a==1 or a==2) and gStates.gameScenario=="The War of Four" then
						UI.setAttribute("ScenarioCity"..a.."Level", "text", joinLang({"{en}Leader-{ru}Лидер-{zh-tw}領袖{zh-cn}领袖{ko}지도자-{es}Líder-{fr}Chef-{pt-br}Líder-{de}Leiter-", scenarioList[gStates.scenarioRef][gStates.playersRef].cityLevels[a]}))
					else
						if a==scenarioList[gStates.scenarioRef][gStates.playersRef].cityTiles+1 and (gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz" or gStates.gameScenario=="Volkare's Quest" or gStates.gameScenario=="The War of Four") then
							UI.setAttribute("ScenarioCity"..a.."Level", "text", joinLang({"{en}Volkare-{ru}Волкар-{zh-tw}沃卡里{zh-cn}沃卡里{ko}볼케어-{es}Volkare-{fr}Volkare-{pt-br}Volkare-{de}Volkare-", scenarioList[gStates.scenarioRef][gStates.playersRef].cityLevels[a]}))
						else
							UI.setAttribute("ScenarioCity"..a.."Level", "text", joinLang({"{en}City-{ru}Город-{zh-tw}城市{zh-cn}城市{ko}도시-{es}Ciudad-{fr}Ville-{pt-br}Cidade-{de}Stadt-", scenarioList[gStates.scenarioRef][gStates.playersRef].cityLevels[a]}))
						end
					end
					UI.setAttribute("MegapolisLeft", "active", "false")
					UI.setAttribute("MegapolisRight", "active", "false")
				end
			else
				UI.setAttribute("CL"..a, "active", "false")
			end
		end
		if #scenarioList[gStates.scenarioRef][gStates.playersRef].cityLevels<=3 then layout=layout.." 28" end
		UI.setAttribute("CityLevelschange", "columnWidths", layout)
		UI.setAttribute("CityLevelschange", "active", "true")
	elseif currentCitySetup.cityTiles==0 then
		--With no cities and no Tezla faction leaders there is no city-level information to show.
		UI.setAttribute("CityLevelschange", "active", "false")
		UI.setAttribute("CityLevelsRow", "active", "false")
		UI.setAttribute("CityDescriptionRow", "active", "false")
		UI.setAttribute("CityNote", "active", "false")
	else
		UI.setAttribute("CityLevelschange", "active", "false")
		UI.setAttribute("CityLevelsRow", "active", "false")
		UI.setAttribute("CityDescriptionRow", "active", "true")
		UI.setAttribute("CityNote", "active", "true")
		local b="{en}Cities are {ru}Города {zh-tw}城市{zh-cn}城市{ko}도시들은 {es}Las Ciudades {fr}Les villes sont {pt-br}Cidades são {de}Städte sind "
		local c="{en}Friendly, but no one is the leader.{ru}дружественные, но никто не является их владельцем.{zh-tw}是友方勢力，沒有領袖。{zh-cn}是友方势力，没有领袖。{ko}우호적이며 아무도 지도자가 아닙니다.{es}son Amistosas, pero nadie es el líder.{fr}Amical, mais personne n'est le leader.{pt-br}Amistosas, mas ninguém é o líder.{de}Freundlich, aber niemand ist der Anführer."
		if gStates.gameScenario=="First Reconnaissance" then c="{en}meant to be discovered only.{ru}только должны быть разведаны.{zh-tw}只能被探索發現。{zh-cn}只能被探索发现。{ko}오직 발견될 목적에만 있습니다.{es}deben ser descubiertas.{fr}destiné à être uniquement découvert.{pt-br}Para serem descobertas apenas.{de}soll nur entdeckt werden." end
		if gStates.gameScenario=="Conquer and Hold" then c="{en}Barred, No players may enter.{ru}закрыты, ни один игрок не может войти.{zh-tw}被封鎖，玩家都不能進入。{zh-cn}被封锁，玩家都不能进入。{ko}닫혀있습니다. 아무도 들어갈 수 없습니다.{es}están bloqueadas. Ningún jugador puede entrar.{fr}Interdit, aucun joueur ne peut entrer.{pt-br}Barradas, nenhum jogador pode entrar.{de}Gesperrt, kein Spieler darf eintreten." end
		if gStates.gameScenario=="The Lost Relic Blitz" then c="{en}Ruined, find only dragons there.{ru}разрушены, там можно найти только драконов.{zh-tw}已被摧毀，只有巨龍出沒。{zh-cn}已被摧毁，只有巨龙出没。{ko}파괴됐습니다. 오직 용만이 존재할뿐.{es}están en ruinas, solo hay dragones en ellas.{fr}Ruiné, on n'y trouve que des dragons.{pt-br}Arruinadas, encontre apenas Dragões lá.{de}Ruiniert, finde dort nur Drachen." end
		b=joinLang({b, c})
		UI.setAttribute("CityNote", "text", b)
	end
	--Volkare's Camp as City Menu Access
	if gStates.removeLostLegionExpansion==true then
		UI.setAttribute("volkareCampAsCity", "interactable", "False")
		UI.setAttribute("volkareCampAsCity", "isOn", "false")
		gStates.volkareCampAsCity=false
	elseif gStates.megapolis>0 then
		UI.setAttribute("volkareCampAsCity", "interactable", "False")
		UI.setAttribute("volkareCampAsCity", "isOn", "false")
		gStates.volkareCampAsCity=false
	elseif #scenarioList[gStates.scenarioRef][gStates.playersRef].cityLevels==5 and gStates.gameScenario~="Volkare's Return" and gStates.gameScenario~="Volkare's Return Blitz" and gStates.gameScenario~="Volkare's Quest" and gStates.gameScenario~="The War of Four" then
		UI.setAttribute("volkareCampAsCity", "interactable", "False")
		UI.setAttribute("volkareCampAsCity", "isOn", "true")
		gStates.volkareCampAsCity=true
	else
		--UI.setAttribute("volkareCampAsCity", "interactable", "True")
		if gStates.gameScenario=="First Conquest" or
			gStates.gameScenario=="Conquest" or
			gStates.gameScenario=="Conquest Blitz" or
			gStates.gameScenario=="One to Return" or
			gStates.gameScenario=="Fast Forwarded Conquest" or
			gStates.gameScenario=="The Lost Relic Blitz" or
			gStates.gameScenario=="Ultimate Conquest" or
			gStates.gameScenario=="The Fractured Lands Blitz" or
			gStates.gameScenario=="Against the Horsemen Blitz" then
			UI.setAttribute("volkareCampAsCity", "interactable", "True")
		else
			UI.setAttribute("volkareCampAsCity", "interactable", "False")
			UI.setAttribute("volkareCampAsCity", "isOn", "false")
			gStates.volkareCampAsCity=false
		end
	end
	--Display the Scenario End rules
	UI.setAttribute("ScenarioEnd", "text", scenarioList[gStates.scenarioRef].scenarioDetails.scenarioEnd)
	refreshScenarioTerrainTweakLocks()
	--Only allow Start button if the current player selection is legal
	refreshSetupStartButton()
end

function SetupMenu(player, mouseButton, id)
	if mouseButton=="-1" then
		UI.setAttribute("Setup", "active", "true")
		UI.setAttribute("helpButtonRealImage", "image", "Sliced Button/Button New Deactive")
		UI.setAttribute("helpButtonReal", "interactable", "false")
		--UI.hide("HelpButton")
	end
end

-- Preserve/restore the pre-game setup presentation without making Events.lua own setup UI state.
--Preserve the complete pre-game setup display and the scenario values that are edited directly in scenarioList.
local setupUISaveAttributes={
	{id="Setup1Details",attribute="active"},{id="Setup2Details",attribute="active"},
	{id="Setup1Details",attribute="height"},{id="Setup2Details",attribute="height"},
	{id="Setup1DetailsSub",attribute="height"},{id="Setup2DetailsSub",attribute="height"},
	{id="MageKnightDetails",attribute="height"},
	{id="ScenarioSelection",attribute="interactable"},{id="ScenarioSelectionText",attribute="text"},{id="ScenarioSelectionImage",attribute="image"},
	{id="firstMKSelection",attribute="interactable"},{id="firstMKSelectionText",attribute="text"},{id="firstMKSelectionImage",attribute="image"},
	{id="secondMKSelection",attribute="interactable"},{id="secondMKSelectionText",attribute="text"},{id="secondMKSelectionImage",attribute="image"},
	{id="thirdMKSelection",attribute="interactable"},{id="thirdMKSelectionText",attribute="text"},{id="thirdMKSelectionImage",attribute="image"},
	{id="fourthMKSelection",attribute="interactable"},{id="fourthMKSelectionText",attribute="text"},{id="fourthMKSelectionImage",attribute="image"},
	{id="dummyMKSelection",attribute="interactable"},{id="dummyMKSelectionText",attribute="text"},{id="dummyMKSelectionImage",attribute="image"},
	{id="DummyPosText",attribute="text"},
	{id="VolkareLevelSelectionRow",attribute="active"},{id="VolkareRaceSelectionRow",attribute="active"},
	{id="VolkareLevelSelection",attribute="interactable"},{id="VolkareLevelSelection",attribute="text"},
	{id="VolkareLevelSelectionText",attribute="text"},{id="VolkareLevelSelectionImage",attribute="image"},
	{id="VolkareRaceSelection",attribute="interactable"},{id="VolkareRaceSelection",attribute="text"},
	{id="VolkareRaceSelectionText",attribute="text"},{id="VolkareRaceSelectionImage",attribute="image"},
	{id="ROTFSelection",attribute="interactable"},{id="ROTFSelectionText",attribute="text"},{id="ROTFSelectionImage",attribute="image"},
	{id="BlitzSelection",attribute="interactable"},{id="BlitzSelection",attribute="isOn"},{id="BlitzSelection",attribute="textColor"},
	{id="RampageSelection",attribute="interactable"},{id="RampageSelection",attribute="isOn"},
	{id="MoreRampageSelection",attribute="interactable"},{id="MoreRampageSelection",attribute="isOn"},
	{id="volkareCampAsCity",attribute="interactable"},{id="volkareCampAsCity",attribute="isOn"},
	{id="randomTileOrientation",attribute="interactable"},{id="randomTileOrientation",attribute="isOn"},
	{id="randomCities",attribute="interactable"},{id="randomCities",attribute="isOn"},
	{id="removeShadesOfTezlaMonsters",attribute="interactable"},{id="removeShadesOfTezlaMonsters",attribute="isOn"},
	{id="removeApocalypseTerrain",attribute="interactable"},{id="removeApocalypseTerrain",attribute="isOn"},
	{id="removeLostLegionExpansion",attribute="interactable"},{id="removeLostLegionExpansion",attribute="isOn"},
	{id="startAtNight",attribute="interactable"},{id="startAtNight",attribute="isOn"},
	{id="darknessComing",attribute="interactable"},{id="darknessComing",attribute="isOn"},{id="darknessComing",attribute="text"},
	{id="rampageAmbush",attribute="interactable"},{id="rampageAmbush",attribute="isOn"},
	{id="rampagePursuit",attribute="interactable"},{id="rampagePursuit",attribute="isOn"},
	{id="mageKnightLevels",attribute="interactable"},{id="mageKnightLevels",attribute="isOn"},
	{id="useCustomMageKnights",attribute="interactable"},{id="useCustomMageKnights",attribute="isOn"},
	{id="heroChallenges",attribute="interactable"},{id="heroChallenges",attribute="isOn"},
	{id="removeBonusCards",attribute="interactable"},{id="removeBonusCards",attribute="isOn"},
	{id="weatherMod",attribute="interactable"},{id="weatherMod",attribute="isOn"},
	{id="questMod",attribute="interactable"},{id="questMod",attribute="isOn"},
	{id="apocalypseQuestCards",attribute="interactable"},{id="apocalypseQuestCards",attribute="isOn"},
	{id="proxyPlayer",attribute="interactable"},{id="proxyPlayer",attribute="isOn"},
	{id="itemShopMod",attribute="interactable"},{id="itemShopMod",attribute="isOn"},
	{id="removeTerrain",attribute="interactable"},{id="removeTerrain",attribute="isOn"},
	{id="useAlternatePugs",attribute="interactable"},{id="useAlternatePugs",attribute="isOn"}}

local function setupScenarioRef()
	if gStates==nil then return nil end
	if gStates.scenarioRef~=nil and scenarioList[gStates.scenarioRef]~=nil and scenarioList[gStates.scenarioRef][1]==gStates.gameScenario then return gStates.scenarioRef end
	for a=1,#scenarioList do if scenarioList[a][1]==gStates.gameScenario then return a end end
	return nil
end

function saveSetupState()
	if gStates==nil or gStates.firstStarted==true then return end
	gStates.setupUI={}
	for _,details in ipairs(setupUISaveAttributes) do
		local value=UI.getAttribute(details.id,details.attribute)
		if value~=nil then gStates.setupUI[details.id.."|"..details.attribute]=value end
	end
	local scenarioRef=setupScenarioRef()
	local playersRef=gStates.playersRef
	if scenarioRef==nil or playersRef==nil or scenarioList[scenarioRef][playersRef]==nil then return end
	local source=scenarioList[scenarioRef][playersRef]
	gStates.setupScenarioState={scenario=gStates.gameScenario,playersRef=playersRef,rounds=source.rounds,mapShape=source.mapShape,mapShapeKey=source.mapShapeKey,
		countryTiles=source.countryTiles,coreTiles=source.coreTiles,cityTiles=source.cityTiles,discardTactics=source.discardTactics,cityLevels={}}
	for a,value in ipairs(source.cityLevels or {}) do gStates.setupScenarioState.cityLevels[a]=value end
end

function restoreSetupScenarioState()
	if gStates==nil or gStates.setupScenarioState==nil then return end
	local saved=gStates.setupScenarioState
	local scenarioRef=nil
	for a=1,#scenarioList do if scenarioList[a][1]==saved.scenario then scenarioRef=a break end end
	if scenarioRef==nil or saved.playersRef==nil or scenarioList[scenarioRef][saved.playersRef]==nil then return end
	local target=scenarioList[scenarioRef][saved.playersRef]
	if saved.rounds~=nil then target.rounds=saved.rounds end
	if saved.mapShape~=nil then target.mapShape=saved.mapShape end
	if saved.mapShapeKey~=nil then target.mapShapeKey=saved.mapShapeKey end
	if saved.countryTiles~=nil then target.countryTiles=saved.countryTiles end
	if saved.coreTiles~=nil then target.coreTiles=saved.coreTiles end
	if saved.cityTiles~=nil then target.cityTiles=saved.cityTiles end
	if saved.discardTactics~=nil then target.discardTactics=saved.discardTactics end
	if saved.cityLevels~=nil then
		target.cityLevels={}
		for a,value in ipairs(saved.cityLevels) do target.cityLevels[a]=value end
	end
	gStates.scenarioRef=scenarioRef
	gStates.playersRef=saved.playersRef
end

local function restoreSetupUIFromState()
	local toggles={"volkareCampAsCity","randomTileOrientation","randomCities","removeShadesOfTezlaMonsters","removeApocalypseTerrain",
		"removeLostLegionExpansion","startAtNight","darknessComing","rampageAmbush","rampagePursuit","mageKnightLevels",
		"useCustomMageKnights","heroChallenges","removeBonusCards","weatherMod","questMod","apocalypseQuestCards","proxyPlayer","itemShopMod","removeTerrain","useAlternatePugs"}
	for _,id in ipairs(toggles) do if gStates[id]~=nil then UI.setAttribute(id,"isOn",gStates[id] and "true" or "false") end end
	UI.setAttribute("BlitzSelection","isOn",gStates.blitz==1 and "true" or "false")
	UI.setAttribute("RampageSelection","isOn",gStates.rampage==1 and "true" or "false")
	UI.setAttribute("MoreRampageSelection","isOn",gStates.rampage==2 and "true" or "false")
	if translateWord[gStates.gameScenario]~=nil then UI.setAttribute("ScenarioSelectionText","text",translateWord[gStates.gameScenario]) end
	local rotfText={
		[0]="{en}Not Used{ru}Не используется{zh-tw}未使用{zh-cn}未使用{ko}사용 안 함{es}No se Utiliza{fr}Non Utilisé{pt-br}Não Utilizado{de}Nicht Verwendet",
		[1]="{en}1. New Beginning{ru}1. Новое начало{zh-tw}新的開始{zh-cn}新的开始{ko}1.새로운 시작{es}1. Un nuevo comienzo{fr}1. Nouveau départ{pt-br}1. Novo Começo{de}1. Neubeginn",
		[2]="{en}2. Spoils of War{ru}2. Военные трофеи{zh-tw}戰爭犒賞{zh-cn}战争犒赏{ko}2.전쟁의 전리품{es}2. Botín de Guerra{fr}2. Butin de Guerre{pt-br}2. Despojos de Guerra{de}2. Kriegsbeute",
		[3]="{en}3. Elixir of Life{ru}3. Эликсир Жизни{zh-tw}⽣命靈藥{zh-cn}⽣命灵药{ko}3.생명의 엘릭서{es}3. El Elixir de la Vida{fr}3. Élixir de vie{pt-br}3. Elixir da Vida{de}3. Lebenselixier"}
	if rotfText[gStates.riseOfTheForgemasters or 0]~=nil then UI.setAttribute("ROTFSelectionText","text",rotfText[gStates.riseOfTheForgemasters or 0]) end
	local combat={"Daring","Heroic","Legendary"}
	local race={"Fair","Tight","Thrilling"}
	if combat[gStates.volkareCombatLevel or 1]~=nil then UI.setAttribute("VolkareLevelSelectionText","text",translateWord[combat[gStates.volkareCombatLevel or 1]]) end
	if race[gStates.volkareRaceLevel or 1]~=nil then UI.setAttribute("VolkareRaceSelectionText","text",translateWord[race[gStates.volkareRaceLevel or 1]]) end
	UI.setAttribute("darknessComing","text",gStates.startAtNight==true and
		"{en}Daylight is Coming{ru}Надвигается рассвет{zh-tw}白晝侵襲{zh-cn}白昼侵袭{ko}빛의 도래{es}Se Acerca la luz del Día{fr}Lendemain Arrive{pt-br}A Luz do dia está Chegando{de}Es Wird Hell" or
		"{en}Darkness is Coming{ru}Надвигается тьма{zh-tw}黑暗侵襲{zh-cn}黑暗侵袭{ko}어둠의 도래{es}La Oscuridad se Acerca{fr}Les Ombres Arrivent{pt-br}Trevas Chegando{de}Es Wird Dunkel")
	refreshProxySetupLabel()
end

function restoreSetupUI()
	if gStates==nil then return end
	if gStates.setupUI==nil then restoreSetupUIFromState() return end
	for _,details in ipairs(setupUISaveAttributes) do
		local value=gStates.setupUI[details.id.."|"..details.attribute]
		if value~=nil then UI.setAttribute(details.id,details.attribute,value) end
	end
	--Never reopen a dropdown just because it happened to be open when the game was saved.
	UI.setAttribute("DropDown","active","false")
end

--Section 3 has derived layout/content when Volkare occupies the dummy position.
--Rebuild it from the saved game state after restoring the general setup snapshot.
function restoreMageKnightSetupSection()
	if gStates==nil then return end
	local volkareOn=gStates.positionMageKnight~=nil and gStates.positionMageKnight[5]=="Volkare"
	if volkareOn==true then
		UI.setAttribute("DummyPosText","text","{en}Volkare Skills -{ru}Навыки Волкаре -{zh-tw}沃卡里技能：{zh-cn}沃卡里技能：{ko}볼케어의 스킬 -{es}Habilidades de Volkare -{fr}Compétences de Volkare -{pt-br}Habilidades de Volkare -{de}Volkare-Fähigkeiten -")
		local skillText=translateWord[gStates.volkareSkills or "Random"] or translateWord["Random"]
		if skillText~=nil then UI.setAttribute("dummyMKSelectionText","text",skillText) end
		UI.setAttribute("dummyMKSelection","interactable","true")
		UI.setAttribute("dummyMKSelectionImage","image","Sliced Button/Button New Active")
		UI.setAttribute("VolkareLevelSelectionRow","active","true")
		UI.setAttribute("MageKnightDetails","height","210")
		UI.setAttribute("Setup1Details","height","436")
		UI.setAttribute("Setup2Details","height","436")
		UI.setAttribute("Setup1DetailsSub","height","376")
		UI.setAttribute("Setup2DetailsSub","height","376")
		if gStates.gameScenario~="The War of Four" then
			UI.setAttribute("VolkareRaceSelectionRow","active","true")
			UI.setAttribute("MageKnightDetails","height","240")
			UI.setAttribute("Setup1Details","height","406")
			UI.setAttribute("Setup2Details","height","406")
			UI.setAttribute("Setup1DetailsSub","height","346")
			UI.setAttribute("Setup2DetailsSub","height","346")
		else
			UI.setAttribute("VolkareRaceSelectionRow","active","false")
		end
	else
		UI.setAttribute("VolkareLevelSelectionRow","active","false")
		UI.setAttribute("VolkareRaceSelectionRow","active","false")
		UI.setAttribute("MageKnightDetails","height","180")
		UI.setAttribute("Setup1Details","height","466")
		UI.setAttribute("Setup2Details","height","466")
		UI.setAttribute("Setup1DetailsSub","height","406")
		UI.setAttribute("Setup2DetailsSub","height","406")
		UI.setAttribute("DummyPosText","text","{en}Dummy Mage Knight -{ru}Виртуальный Рыцарь-маг -{zh-tw}虛擬玩家：{zh-cn}虚拟玩家：{ko}가상 플레이어 -{es}Mage Knight Virtual -{fr}Mage fantôme -{pt-br}Mage Knight Fictício -{de}Dummy-Magier-Ritter -")
	end
end

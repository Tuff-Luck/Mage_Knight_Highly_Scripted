-- Pre-game setup interface: scenario/variant selection, setup options and setup-menu controls.

---------------
-- UI Functions
---------------
--Keep a pristine copy of the Optional Scenario Tweaks so changing scenario can
--return the selected scenario to the correct defaults for the current Mage Knight count.
local scenarioTweakDefaults=nil


local SETUP_TEXT={
	notUsed="{en}Not Used{ru}Не используется{zh-tw}未使用{zh-cn}未使用{ko}사용 안 함{es}No se Utiliza{fr}Non Utilisé{pt-br}Não Utilizado{de}Nicht Verwendet",
	rotf1="{en}1. New Beginning{ru}1. Новое начало{zh-tw}新的開始{zh-cn}新的开始{ko}1.새로운 시작{es}1. Un nuevo comienzo{fr}1. Nouveau départ{pt-br}1. Novo Começo{de}1. Neubeginn",
	rotf2="{en}2. Spoils of War{ru}2. Военные трофеи{zh-tw}戰爭犒賞{zh-cn}战争犒赏{ko}2.전쟁의 전리품{es}2. Botín de Guerra{fr}2. Butin de Guerre{pt-br}2. Despojos de Guerra{de}2. Kriegsbeute",
	rotf3="{en}3. Elixir of Life{ru}3. Эликсир Жизни{zh-tw}⽣命靈藥{zh-cn}⽣命灵药{ko}3.생명의 엘릭서{es}3. El Elixir de la Vida{fr}3. Élixir de vie{pt-br}3. Elixir da Vida{de}3. Lebenselixier",
	darknessComing="{en}Darkness is Coming{ru}Надвигается тьма{zh-tw}黑暗侵襲{zh-cn}黑暗侵袭{ko}어둠의 도래{es}La Oscuridad se Acerca{fr}Les Ombres Arrivent{pt-br}Trevas Chegando{de}Es Wird Dunkel",
	daylightComing="{en}Daylight is Coming{ru}Надвигается рассвет{zh-tw}白晝侵襲{zh-cn}白昼侵袭{ko}빛의 도래{es}Se Acerca la luz del Día{fr}Lendemain Arrive{pt-br}A Luz do dia está Chegando{de}Es Wird Hell",
	startSolo="{en}Start - Solo{ru}Начало - Одиночный{zh-tw}開始 - 單人遊戲{zh-cn}开始 - 单人游戏{ko}시작 - 솔로{es}Comenzar - Solo{fr}Démarrer - Solo{pt-br}Início - Solo{de}Start - Solo",
	startCompetitive="{en}Start - Competitive{ru}Начало - Соревновательный{zh-tw}開始 - 對抗模式{zh-cn}开始 - 对抗模式{ko}시작 - 경쟁{es}Comenzar - Competitivo{fr}Démarrer - Compétitif{pt-br}Início - Competitivo{de}Start - Wettbewerbsfähig",
	startCooperative="{en}Start - Cooperative{ru}Начало - Кооперативный{zh-tw}開始 - 合作模式{zh-cn}开始 - 合作模式{ko}시작 - 협력{es}Comenzar - Cooperativo{fr}Démarrer - Coopératif{pt-br}Início - Cooperativo{de}Start - Genossenschaft",
	volkareSkills="{en}Volkare Skills -{ru}Навыки Волкаре -{zh-tw}沃卡里技能：{zh-cn}沃卡里技能：{ko}볼케어의 스킬 -{es}Habilidades de Volkare -{fr}Compétences de Volkare -{pt-br}Habilidades de Volkare -{de}Volkare-Fähigkeiten -",
	dummyMageKnight="{en}Dummy Mage Knight -{ru}Виртуальный Рыцарь-маг -{zh-tw}虛擬玩家：{zh-cn}虚拟玩家：{ko}가상 플레이어 -{es}Mage Knight Virtual -{fr}Mage fantôme -{pt-br}Mage Knight Fictício -{de}Dummy-Magier-Ritter -",
	countryTilesPrefix="{en}Country Tiles - {ru}Дикие земли - {zh-tw}鄉村板塊：{zh-cn}乡村板块：{ko}교외 타일 - {es}Losetas de Campo - {fr}Tuiles Pays - {pt-br}Peças de Campo - {de}Land Teile - ",
	coreTilesPrefix="{en}Core Tiles - {ru}Развитые земли - {zh-tw}核心板塊：{zh-cn}核心板块：{ko}중심부 타일 - {es}Losetas Centrales - {fr}Tuiles de Base - {pt-br}Peças Centrais - {de}Core Teile - ",
	cityTilesPrefix="{en}City Tiles - {ru}Земли с городом - {zh-tw}城市板塊：{zh-cn}城市板块：{ko}도시 타일 - {es}Losetas de Ciudad - {fr}Tuiles Ville - {pt-br} Peças Cidade - {de}Stadt Teile - "}

local ROTF_TEXT_BY_LEVEL={[0]=SETUP_TEXT.notUsed,[1]=SETUP_TEXT.rotf1,[2]=SETUP_TEXT.rotf2,[3]=SETUP_TEXT.rotf3}

local SCENARIO_SELECTION_BY_ID={
	ConquestSelection="Conquest",
	FirstReconnaissanceSelection="First Reconnaissance",
	FirstConquestSelection="First Conquest",
	MinesLiberationSelection="Mines Liberation",
	DruidNightsSelection="Druid Nights",
	DungeonLordsSelection="Dungeon Lords",
	ConquerAndHoldSelection="Conquer and Hold",
	OneToReturnSelection="One to Return",
	VolkaresReturnSelection="Volkare's Return",
	VolkaresQuestSelection="Volkare's Quest",
	LifeAndDeathSelection="Life and Death",
	TheRealmOfTheDeadSelection="The Realm of the Dead",
	TheHiddenValleySelection="The Hidden Valley",
	AgainsttheApocalypseSelection="Against the Apocalypse",
	AgainsttheHorsemenSelection="Against the Horsemen",
	AgainsttheDragonSelection="Against the Dragon",
	ApocalypseIsHereSelection="Apocalypse is Here",
	FuryOfTheApocalypseDragonSelection="Fury of the Apocalypse Dragon",
	TheLostRelicSelection="The Lost Relic",
	TheGauntletSelection="The Gauntlet",
	QuestForTheGoldenGrailSelection="Quest for the Golden Grail",
	TheChaosRiftSelection="The Chaos Rift",
	UltimateConquestSelection="Ultimate Conquest",
	FastForwardedConquestSelection="Fast Forwarded Conquest",
	TheWarOfFourSelection="The War of Four",
	RaidersOfTheCrusaderTempleSelection="Raiders of the Crusader Temple",
	ForTheCouncilSelection="For the Council",
	TheFracturedLandsSelection="The Fractured Lands",
	CustomSelection="Custom"}

local ROTF_SELECTION_LEVEL_BY_ID={ROTF0Selection=0,ROTF1Selection=1,ROTF2Selection=2,ROTF3Selection=3}

local SETUP_DROPDOWN_CONTROL_BY_ID={
	firstMKSelection={1,"MageDropDown",-275},
	secondMKSelection={2,"MageDropDown",-275},
	thirdMKSelection={3,"MageDropDown",-275},
	fourthMKSelection={4,"MageDropDown",-275},
	dummyMKSelection={5,"MageDropDown",-275},
	ScenarioSelection={0,"ScenarioDropDown",90},
	ROTFSelection={0,"ROTFDropDown",-115},
	VolkareLevelSelection={0,"VolkareLevelDropDown",-305},
	VolkareRaceSelection={0,"VolkareRaceDropDown",-335}}

local SETUP_DROPDOWN_ROWS={
	nobodyRow={"nobody","nobodySelectionImage","MageDropDown"},
	AllSkillsRow={"All Skills","AllSkillsSelectionImage","MageDropDown"},
	RANDOMRow={"Random","RANDOMSelectionImage","MageDropDown"},
	ArytheaRow={"Arythea","ArytheaSelectionImage","MageDropDown"},
	GoldyxRow={"Goldyx","GoldyxSelectionImage","MageDropDown"},
	NorowasRow={"Norowas","NorowasSelectionImage","MageDropDown"},
	TovakRow={"Tovak","TovakSelectionImage","MageDropDown"},
	BraevalarRow={"Braevalar","BraevalarSelectionImage","MageDropDown"},
	KrangRow={"Krang","KrangSelectionImage","MageDropDown"},
	WolfhawkRow={"Wolfhawk","WolfhawkSelectionImage","MageDropDown"},
	CoralRow={"Coral","CoralSelectionImage","MageDropDown"},
	YmirghRow={"Ymirgh","YmirghSelectionImage","MageDropDown"},
	MevokRow={"Mevok","MevokSelectionImage","MageDropDown"},
	DusceniaRow={"Duscenia","DusceniaSelectionImage","MageDropDown"},
	JormundRow={"Jormund","JormundSelectionImage","MageDropDown"},
	MalekRow={"Malek","MalekSelectionImage","MageDropDown"},
	ZirtaeRow={"Zirtae","ZirtaeSelectionImage","MageDropDown"},
	DaringRow={"Daring","DaringSelectionImage","VolkareLevelDropDown",1},
	HeroicRow={"Heroic","HeroicSelectionImage","VolkareLevelDropDown",2},
	LegendaryRow={"Legendary","LegendarySelectionImage","VolkareLevelDropDown",3},
	FairRow={"Fair","FairSelectionImage","VolkareRaceDropDown",1},
	TightRow={"Tight","TightSelectionImage","VolkareRaceDropDown",2},
	ThrillingRow={"Thrilling","ThrillingSelectionImage","VolkareRaceDropDown",3},
	ConquestRow={"Conquest","ConquestSelectionImage","ScenarioDropDown"},
	FirstReconnaissanceRow={"First Reconnaissance","FirstReconnaissanceSelectionImage","ScenarioDropDown"},
	FirstConquestRow={"First Conquest","FirstConquestSelectionImage","ScenarioDropDown"},
	MinesLiberationRow={"Mines Liberation","MinesLiberationSelectionImage","ScenarioDropDown"},
	DruidNightsRow={"Druid Nights","DruidNightsSelectionImage","ScenarioDropDown"},
	DungeonLordsRow={"Dungeon Lords","DungeonLordsSelectionImage","ScenarioDropDown"},
	ConquerAndHoldRow={"Conquer and Hold","ConquerAndHoldSelectionImage","ScenarioDropDown"},
	OneToReturnRow={"One to Return","OneToReturnSelectionImage","ScenarioDropDown"},
	VolkaresReturnRow={"Volkare's Return","VolkaresReturnSelectionImage","ScenarioDropDown"},
	VolkaresQuestRow={"Volkare's Quest","VolkaresQuestSelectionImage","ScenarioDropDown"},
	LifeAndDeathRow={"Life and Death","LifeAndDeathSelectionImage","ScenarioDropDown"},
	TheRealmOfTheDeadRow={"The Realm of the Dead Blitz","TheRealmOfTheDeadSelectionImage","ScenarioDropDown"},
	TheHiddenValleyRow={"The Hidden Valley Blitz","TheHiddenValleySelectionImage","ScenarioDropDown"},
	AgainsttheApocalypseRow={"Against the Apocalypse Blitz","AgainsttheApocalypseSelectionImage","ScenarioDropDown"},
	AgainsttheHorsemenRow={"Against the Horsemen Blitz","AgainsttheHorsemenSelectionImage","ScenarioDropDown"},
	AgainsttheDragonRow={"Against the Dragon Blitz","AgainsttheDragonSelectionImage","ScenarioDropDown"},
	ApocalypseIsHereRow={"Apocalypse is Here","ApocalypseIsHereSelectionImage","ScenarioDropDown"},
	FuryOfTheApocalypseDragonRow={"Fury of the Apocalypse Dragon","FuryOfTheApocalypseDragonSelectionImage","ScenarioDropDown"},
	TheLostRelicRow={"The Lost Relic Blitz","TheLostRelicSelectionImage","ScenarioDropDown"},
	TheGauntletRow={"The Gauntlet","TheGauntletSelectionImage","ScenarioDropDown"},
	QuestForTheGoldenGrailRow={"Quest for the Golden Grail","QuestForTheGoldenGrailSelectionImage","ScenarioDropDown"},
	TheChaosRiftRow={"The Chaos Rift","TheChaosRiftSelectionImage","ScenarioDropDown"},
	UltimateConquestRow={"Ultimate Conquest","UltimateConquestSelectionImage","ScenarioDropDown"},
	FastForwardedConquestRow={"Fast Forwarded Conquest","FastForwardedConquestSelectionImage","ScenarioDropDown"},
	TheWarOfFourRow={"The War of Four","TheWarOfFourSelectionImage","ScenarioDropDown"},
	RaidersOfTheCrusaderTempleRow={"Raiders of the Crusader Temple","RaidersOfTheCrusaderTempleSelectionImage","ScenarioDropDown"},
	ForTheCouncilRow={"For the Council","ForTheCouncilSelectionImage","ScenarioDropDown"},
	TheFracturedLandsRow={"The Fractured Lands Blitz","TheFracturedLandsSelectionImage","ScenarioDropDown"},
	CustomRow={"Custom","CustomSelectionImage","ScenarioDropDown"},
	ROTF0Row={"Not Used","ROTF0SelectionImage","ROTFDropDown"},
	ROTF1Row={"1. New Beginning","ROTF1SelectionImage","ROTFDropDown"},
	ROTF2Row={"2. Spoils of War","ROTF2SelectionImage","ROTFDropDown"},
	ROTF3Row={"3. Elixir of Life","ROTF3SelectionImage","ROTFDropDown"}}

local MAGE_KNIGHT_SELECTION_BY_ID={
	nobodySelection="nobody",AllSkillsSelection="All Skills",RANDOMSelection="Random",
	ArytheaSelection="Arythea",GoldyxSelection="Goldyx",NorowasSelection="Norowas",TovakSelection="Tovak",
	BraevalarSelection="Braevalar",KrangSelection="Krang",WolfhawkSelection="Wolfhawk",CoralSelection="Coral",
	YmirghSelection="Ymirgh",MevokSelection="Mevok",DusceniaSelection="Duscenia",JormundSelection="Jormund",
	MalekSelection="Malek",ZirtaeSelection="Zirtae"}

local MAGE_KNIGHT_CONTROL_POSITION={
	firstMKSelection=1,secondMKSelection=2,thirdMKSelection=3,fourthMKSelection=4,dummyMKSelection=5}
local MAGE_KNIGHT_CONTROL_IDS={"firstMKSelection","secondMKSelection","thirdMKSelection","fourthMKSelection","dummyMKSelection"}

local VOLKARE_COMBAT_SELECTION_BY_ID={
	DaringSelection={"Daring",1},HeroicSelection={"Heroic",2},LegendarySelection={"Legendary",3}}
local VOLKARE_RACE_SELECTION_BY_ID={
	FairSelection={"Fair",1},TightSelection={"Tight",2},ThrillingSelection={"Thrilling",3}}

local scenarioRefByName={}
for scenarioRef,scenario in ipairs(scenarioList) do scenarioRefByName[scenario[1]]=scenarioRef end

local function scenarioRefForName(name)
	return type(name)=="string" and scenarioRefByName[name] or nil
end

local function scenarioRefForSelection(name)
	return scenarioRefForName(name) or scenarioRefForName(type(name)=="string" and name.." Blitz" or nil)
end

local function blitzPolicyForScenarioSelection(name)
	local scenarioRef=scenarioRefForSelection(name)
	local details=scenarioRef~=nil and scenarioList[scenarioRef].scenarioDetails or nil
	return details~=nil and details.blitzPossible or nil
end

local function setScenarioBlitzIdentity(enabled)
	local current=gStates.gameScenario
	local base=current
	if type(base)=="string" and base:sub(-6)==" Blitz" then base=base:sub(1,-7) end
	local desired=enabled and base.." Blitz" or base
	if scenarioRefForName(desired)~=nil then gStates.gameScenario=desired end
end

local function setSetupToggle(id,value,interactable)
	if value~=nil then
		UI.setAttribute(id,"isOn",value and "true" or "false")
		gStates[id]=value
	end
	if interactable~=nil then UI.setAttribute(id,"interactable",interactable and "True" or "False") end
end

local SETUP_TOGGLE_DEFAULTS={
	volkareCampAsCity={false,false},
	removeLostLegionExpansion={false,true},
	randomTileOrientation={false,true},
	randomCities={false,true},
	removeShadesOfTezlaMonsters={false,true},
	removeApocalypseTerrain={false,true},
	startAtNight={false,true},
	rampageAmbush={false,true},
	rampagePursuit={false,true},
	darknessComing={false,true},
	mageKnightLevels={false,true},
	useCustomMageKnights={false,true},
	removeBonusCards={false,true},
	weatherMod={false,true},
	questMod={false,true},
	apocalypseQuestCards={false,true},
	proxyPlayer={false,true},
	itemShopMod={false,true},
	removeTerrain={false,true},
	useAlternatePugs={false,true}}

local SCENARIO_OPTION_OVERRIDES={
	["First Reconnaissance"]={
		randomTileOrientation={false,false},removeShadesOfTezlaMonsters={true,false},removeApocalypseTerrain={true,false},
		startAtNight={false,false},rampageAmbush={false,false},rampagePursuit={false,false},darknessComing={false,false},
		mageKnightLevels={false,false},useCustomMageKnights={false,false},removeBonusCards={true,false},weatherMod={false,false},
		questMod={false,false},apocalypseQuestCards={false,false},proxyPlayer={false,false},itemShopMod={false,false},
		heroChallenges={false,false},removeTerrain={false,false}},
	["First Conquest"]={volkareCampAsCity={false,true}},
	["Conquest"]={volkareCampAsCity={false,true}},
	["Conquest Blitz"]={volkareCampAsCity={false,true}},
	["Ultimate Conquest"]={volkareCampAsCity={false,true}},
	["Fast Forwarded Conquest"]={volkareCampAsCity={false,true},startAtNight={true,false},mageKnightLevels={true,false}},
	["The Lost Relic Blitz"]={volkareCampAsCity={false,true},mageKnightLevels={true,false}},
	["The Fractured Lands Blitz"]={volkareCampAsCity={false,true},randomTileOrientation={false,false},questMod={false,false},apocalypseQuestCards={true,false}},
	["One to Return"]={volkareCampAsCity={false,true},proxyPlayer={false,false}},
	["Against the Horsemen Blitz"]={volkareCampAsCity={false,true},removeTerrain={false,false}},
	["Mines Liberation"]={removeTerrain={false,false}},
	["Druid Nights"]={removeTerrain={false,false}},
	["The Gauntlet"]={removeTerrain={false,false}},
	["Quest for the Golden Grail"]={removeTerrain={false,false},mageKnightLevels={false,false}},
	["The Chaos Rift"]={removeTerrain={false,false},mageKnightLevels={false,false}},
	["Life and Death"]={removeTerrain={false,false},removeShadesOfTezlaMonsters={false,false}},
	["The Realm of the Dead Blitz"]={removeTerrain={false,false},removeShadesOfTezlaMonsters={false,false},rampagePursuit={true,false}},
	["The Hidden Valley Blitz"]={removeShadesOfTezlaMonsters={false,false},rampageAmbush={true,false}},
	["Against the Apocalypse Blitz"]={removeApocalypseTerrain={false,false}},
	["For the Council"]={questMod={false,false},apocalypseQuestCards={true,false}},
	["Conquer and Hold"]={proxyPlayer={false,false}},
	["Volkare's Return"]={proxyPlayer={false,false}},
	["Volkare's Return Blitz"]={proxyPlayer={false,false}},
	["Volkare's Quest"]={proxyPlayer={false,false}},
	["The War of Four"]={proxyPlayer={false,false},removeShadesOfTezlaMonsters={false,false}}}

local function applyScenarioToggleDefaults()
	for id,details in pairs(SETUP_TOGGLE_DEFAULTS) do setSetupToggle(id,details[1],details[2]) end
	local overrides=SCENARIO_OPTION_OVERRIDES[gStates.gameScenario]
	if overrides~=nil then
		for id,details in pairs(overrides) do setSetupToggle(id,details[1],details[2]) end
	end
	UI.setAttribute("darknessComing","text",gStates.startAtNight==true and SETUP_TEXT.daylightComing or SETUP_TEXT.darknessComing)
end


local function scenarioOptionHardLock(id)
	local overrides=SCENARIO_OPTION_OVERRIDES[gStates.gameScenario]
	local details=overrides~=nil and overrides[id] or nil
	if details~=nil and details[2]==false then return true,details[1] end
	return false,nil
end

local function clearCustomMageKnightSelections(preserveRememberedDummy)
	for position=1,4 do
		local mage=gStates.positionMageKnight[position]
		if customMages[mage]~=nil then
			gStates.positionMageKnight[position]="nobody"
			UI.setAttribute(MAGE_KNIGHT_CONTROL_IDS[position].."Text","text",translateWord["nobody"])
		end
	end
	if gStates.positionMageKnight[5]=="Volkare" then
		if customMages[gStates.volkareSkills]~=nil then
			gStates.volkareSkills="Random"
			if preserveRememberedDummy~=true then gStates.setupDummyMageChoice="Random" end
			UI.setAttribute("dummyMKSelectionText","text",translateWord["Random"])
		end
	elseif customMages[gStates.positionMageKnight[5]]~=nil then
		gStates.positionMageKnight[5]="nobody"
		if preserveRememberedDummy~=true then gStates.setupDummyMageChoice="nobody" end
		UI.setAttribute("dummyMKSelectionText","text",translateWord["nobody"])
	end
	if preserveRememberedDummy~=true and customMages[gStates.setupDummyMageChoice]~=nil then gStates.setupDummyMageChoice="nobody" end
end

local function renderDummySetupSection()
	local volkareOn=gStates.positionMageKnight~=nil and gStates.positionMageKnight[5]=="Volkare"
	UI.setAttribute("VolkareLevelSelectionRow","active",volkareOn and "true" or "false")
	UI.setAttribute("VolkareRaceSelectionRow","active",volkareOn and gStates.gameScenario~="The War of Four" and "true" or "false")
	if volkareOn then
		UI.setAttribute("DummyPosText","text",SETUP_TEXT.volkareSkills)
		UI.setAttribute("dummyMKSelectionText","text",translateWord[gStates.volkareSkills or "Random"] or translateWord["Random"])
		local showRace=gStates.gameScenario~="The War of Four"
		UI.setAttribute("MageKnightDetails","height",showRace and "240" or "210")
		UI.setAttribute("Setup1Details","height",showRace and "406" or "436")
		UI.setAttribute("Setup2Details","height",showRace and "406" or "436")
		UI.setAttribute("Setup1DetailsSub","height",showRace and "346" or "376")
		UI.setAttribute("Setup2DetailsSub","height",showRace and "346" or "376")
	else
		UI.setAttribute("DummyPosText","text",SETUP_TEXT.dummyMageKnight)
		local dummy=gStates.positionMageKnight~=nil and (gStates.positionMageKnight[5] or "nobody") or "nobody"
		UI.setAttribute("dummyMKSelectionText","text",translateWord[dummy] or translateWord["nobody"])
		UI.setAttribute("MageKnightDetails","height","180")
		UI.setAttribute("Setup1Details","height","466")
		UI.setAttribute("Setup2Details","height","466")
		UI.setAttribute("Setup1DetailsSub","height","406")
		UI.setAttribute("Setup2DetailsSub","height","406")
	end
end

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
	local scenarioRef=scenarioRefForName(gStates.gameScenario)
	local scenario=scenarioRef~=nil and scenarioList[scenarioRef] or nil
	if scenario~=nil and (scenario[playersRef]==nil or scenario[playersRef].rounds==nil) then
		local fallbackRef=math.max(gStates.playerCount,2)
		if scenario[fallbackRef]~=nil and scenario[fallbackRef].rounds~=nil then playersRef=fallbackRef end
	end
	return playersRef
end

function resetCurrentScenarioTweaks()
	cacheScenarioTweakDefaults()
	local scenarioRef=scenarioRefForName(gStates.gameScenario)
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
		riseOfTheForgemasterOption(nil, "-1", choice[math.random(1,3)])
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
		--Preserve the dummy choice while browsing scenarios. Volkare uses the same remembered Mage Knight as his skill set.
		--Scenario-forced "nobody" does not erase the remembered choice, so it survives scenarios that disallow a dummy.
		if gStates.positionMageKnight[5]=="Volkare" then
			if gStates.volkareSkills~=nil and gStates.volkareSkills~="nobody" then gStates.setupDummyMageChoice=gStates.volkareSkills end
		elseif gStates.positionMageKnight[5]~=nil and gStates.positionMageKnight[5]~="nobody" then
			gStates.setupDummyMageChoice=gStates.positionMageKnight[5]
		elseif gStates.setupDummyMageChoice==nil then
			gStates.setupDummyMageChoice="nobody"
		end
		gStates.gameScenario=SCENARIO_SELECTION_BY_ID[id] or id
		UI.setAttribute("ScenarioSelectionText", "text", translateWord[gStates.gameScenario])
		UI.setAttribute("ScenarioSelectionImage", "image", "Sliced Button/Button New Active")
		UI.setAttribute("DropDown", "active", "false")
		--Keep the selected Mage Knights when browsing scenarios. The dummy is retained too, except where the scenario forces it off or replaces it with Volkare.
		local MKDropDownUI=MAGE_KNIGHT_CONTROL_IDS
		gStates.playerCount=0
		for a=1, 4, 1 do
			local mage=gStates.positionMageKnight[a] or "nobody"
			gStates.positionMageKnight[a]=mage
			if mage~="nobody" then gStates.playerCount=gStates.playerCount+1 end
			setUIButtonEnabled(MKDropDownUI[a],true)
			UI.setAttribute(MKDropDownUI[a].."Text", "text", translateWord[mage])
		end
		gStates.positionMageKnight[5]=gStates.setupDummyMageChoice or "nobody"
		setUIButtonEnabled("dummyMKSelection",true)
		UI.setAttribute("dummyMKSelectionText", "text", translateWord[gStates.positionMageKnight[5]] or translateWord["nobody"])
		dropDownIdLink="none"
		UI.setAttribute("DropDown", "active", "false")
		gStates.megapolis=0
		gStates.coop=gStates.positionMageKnight[5]~="nobody" and 1 or 0
		--Scenario-specific dummy state; layout is rendered by the shared helper.
		if gStates.gameScenario=="Conquer and Hold" or gStates.gameScenario=="One to Return" then
			gStates.positionMageKnight[5]="nobody"
			gStates.coop=0
		elseif gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Quest" or gStates.gameScenario=="The War of Four" then
			if gStates.setupDummyMageChoice~=nil and gStates.setupDummyMageChoice~="nobody" then gStates.volkareSkills=gStates.setupDummyMageChoice else gStates.volkareSkills="Random" end
			gStates.positionMageKnight[5]="Volkare"
			gStates.coop=1
		end
		renderDummySetupSection()
		--Blitz is normally player-selectable. Some scenarios default it on; First Recon locks it off.
		UI.setAttribute("BlitzSelection","textColor","rgb(0.0,0.0,0.0)")
		local selectedScenario=gStates.gameScenario
		local blitzOn=blitzPolicyForScenarioSelection(selectedScenario)=="On Only"
		gStates.blitz=blitzOn and 1 or 0
		UI.setAttribute("BlitzSelection","isOn",blitzOn and "true" or "false")
		setScenarioBlitzIdentity(blitzOn)
		UI.setAttribute("BlitzSelection","interactable",selectedScenario=="First Reconnaissance" and "False" or "True")

		--Reset ordinary setup toggles from one policy table, then apply scenario-specific overrides.
		--Hero Challenges intentionally survives scenario browsing and is therefore not part of this reset.
		applyScenarioToggleDefaults()
		if scenarioAllowsRandomCities()==false then UI.setAttribute("randomCities","interactable","False") end
		refreshProxySetupLabel()

		--Rampage uses a three-state value instead of a normal boolean toggle.
		UI.setAttribute("RampageSelection","interactable","True")
		UI.setAttribute("MoreRampageSelection","interactable","True")
		UI.setAttribute("RampageSelection","isOn","false")
		UI.setAttribute("MoreRampageSelection","isOn","false")
		gStates.rampage=0
		if gStates.gameScenario=="First Reconnaissance" then
			UI.setAttribute("RampageSelection","interactable","False")
			UI.setAttribute("MoreRampageSelection","interactable","False")
		end
		--Volkare's Race and Combat Level Menu Access
		if gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Quest" or gStates.gameScenario=="The War of Four" then
			UI.setAttribute("VolkareLevelSelection", "interactable", "True")
			UI.setAttribute("VolkareLevelSelectionText", "text", translateWord["Daring"])
			gStates.volkareCombatLevel=1
			UI.setAttribute("VolkareRaceSelection", "interactable", "True")
			UI.setAttribute("VolkareRaceSelectionText", "text", translateWord["Fair"])
			gStates.volkareRaceLevel=1
		else
			UI.setAttribute("VolkareLevelSelection", "interactable", "False")
			UI.setAttribute("VolkareLevelSelectionText", "text", SETUP_TEXT.notUsed)
			UI.setAttribute("VolkareRaceSelection", "interactable", "False")
			UI.setAttribute("VolkareRaceSelectionText", "text", SETUP_TEXT.notUsed)
		end
		--Rise of the forgemaster Menu Access
		setUIButtonEnabled("ROTFSelection",true)
		UI.setAttribute("ROTFSelectionText", "text", SETUP_TEXT.notUsed)
		gStates.riseOfTheForgemasters=0
		if gStates.gameScenario=="First Reconnaissance" then
			setUIButtonEnabled("ROTFSelection",false)
	 	end
		--Changing scenario discards any previous Optional Scenario Tweaks and reloads
		--the defaults for this scenario and the currently selected Mage Knight count.
		resetCurrentScenarioTweaks()
		scenarioInfoUpdate()
	end
end

function BlitzSelection(player, value, id)
	if gStates.gameScenario=="First Reconnaissance" and value=="True" then
		UI.setAttribute("BlitzSelection","isOn","false")
		UI.setAttribute("BlitzSelection","interactable","False")
		gStates.blitz=0
		return
	end

	gStates.blitz=value=="True" and 1 or 0
	UI.setAttribute("BlitzSelection","isOn",gStates.blitz==1 and "true" or "false")
	setScenarioBlitzIdentity(gStates.blitz==1)
	UI.setAttribute("BlitzSelection","interactable",gStates.gameScenario=="First Reconnaissance" and "False" or "True")

	resetCurrentScenarioTweaks()
	scenarioInfoUpdate()

	--Keep the historical red warning when the chosen Blitz state differs from the scenario's
	--published expectation, without preventing the player from making that choice.
	local blitzPolicy=blitzPolicyForScenarioSelection(gStates.gameScenario)
	local invalid=(blitzPolicy=="On Only" and gStates.blitz==0) or (blitzPolicy=="Off Only" and gStates.blitz==1)
	UI.setAttribute("BlitzSelection","textColor",invalid and "rgb(1.0,0.0,0.0)" or "rgb(0.0,0.0,0.0)")
	ToolTipUpdate(id)
end

-- Cross-option setup locks for Rise of the Forgemasters and Hero Challenges.
function applyForgemasterExpansionRequirements()
	local level=gStates.riseOfTheForgemasters or 0
	if level<=0 then return end
	gStates.useCustomMageKnights=true
	gStates.removeLostLegionExpansion=false
	gStates.removeBonusCards=level==1
end

function refreshHeroChallengeOptionLocks()
	if gStates==nil then return end
	local heroOn=gStates.heroChallenges==true
	local rotf=(gStates.riseOfTheForgemasters or 0)>0
	local custom=gStates.useCustomMageKnights==true
	local firstRecon=gStates.gameScenario=="First Reconnaissance"
	UI.setAttribute("heroChallenges","isOn",heroOn and "true" or "false")
	UI.setAttribute("heroChallenges","interactable",(not firstRecon and not custom and not rotf) and "True" or "False")
	if heroOn==true then
		UI.setAttribute("useCustomMageKnights","interactable","False")
		setUIButtonEnabled("ROTFSelection",false)
	else
		UI.setAttribute("useCustomMageKnights","interactable",(not firstRecon and not rotf) and "True" or "False")
		local rotfAllowed=not firstRecon and gStates.removeLostLegionExpansion~=true
		setUIButtonEnabled("ROTFSelection",rotfAllowed)
	end
end

local function setupLostLegionExpansionRequired()
	return gStates.gameScenario=="The Gauntlet" or
		(gStates.gameScenario=="The Lost Relic Blitz" and gStates.coop==1 and (gStates.playerCount or 0)>=4)
end

local function reconcileLostLegionExpansionState()
	if gStates.gameScenario=="First Reconnaissance" then
		gStates.removeLostLegionExpansion=true
	elseif setupLostLegionExpansionRequired() then
		gStates.removeLostLegionExpansion=false
	end
	if gStates.removeLostLegionExpansion==true then gStates.volkareCampAsCity=false end
end

local function renderLostLegionExpansionOption()
	local rotf=(gStates.riseOfTheForgemasters or 0)>0
	local locked=gStates.gameScenario=="First Reconnaissance" or setupLostLegionExpansionRequired() or rotf
	UI.setAttribute("removeLostLegionExpansion","isOn",gStates.removeLostLegionExpansion==true and "true" or "false")
	UI.setAttribute("removeLostLegionExpansion","interactable",locked and "False" or "True")
	if gStates.removeLostLegionExpansion==true then
		UI.setAttribute("volkareCampAsCity","isOn","false")
		UI.setAttribute("volkareCampAsCity","interactable","False")
	end
end

function refreshLostLegionExpansionOption()
	if gStates==nil then return end
	reconcileLostLegionExpansionState()
	renderLostLegionExpansionOption()
end

function optionsUpdate(player, value, id)
	if id=="heroChallenges" and value=="True" and (gStates.gameScenario=="First Reconnaissance" or gStates.useCustomMageKnights==true or (gStates.riseOfTheForgemasters or 0)>0) then
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
		if id=="startAtNight" then UI.setAttribute("darknessComing", "text", SETUP_TEXT.daylightComing) end
		if id=="removeLostLegionExpansion" then
			setUIButtonEnabled("ROTFSelection",false)
			gStates.volkareCampAsCity=false
			UI.setAttribute("volkareCampAsCity", "isOn", "false")
			UI.setAttribute("volkareCampAsCity", "interactable", "False")
		end
	else
		UI.setAttribute(id, "isOn", "false")
		gStates[id]=false
		if id=="questMod" then UI.setAttribute("apocalypseQuestCards", "interactable", "true") elseif id=="apocalypseQuestCards" then UI.setAttribute("questMod", "interactable", "true") end
		if id=="startAtNight" then UI.setAttribute("darknessComing", "text", SETUP_TEXT.darknessComing) end
		if id=="removeLostLegionExpansion" then --and gStates.removeBonusCards==false) or (id=="removeBonusCards" and gStates.removeLostLegionExpansion==false)
			setUIButtonEnabled("ROTFSelection",true)
		end
		if id=="useCustomMageKnights" then clearCustomMageKnightSelections(false) end
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

function riseOfTheForgemasterOption(player, mouseButton, id)
	if mouseButton=="-1" then
		local level=ROTF_SELECTION_LEVEL_BY_ID[id]
		if level==nil then return end
		UI.setAttribute(dropDownIdLink.."Text", "text", ROTF_TEXT_BY_LEVEL[level])
		UI.setAttribute(dropDownIdLink.."Image", "image", "Sliced Button/Button New Active")
		UI.setAttribute("DropDown", "active", "false")
		dropDownIdLink="none"
		gStates.riseOfTheForgemasters=level
		if gStates.riseOfTheForgemasters>0 then applyForgemasterExpansionRequirements() end
		if gStates.riseOfTheForgemasters<3 then clearCustomMageKnightSelections(false) end
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
	if mouseButton~="-1" then return end
	local control=SETUP_DROPDOWN_CONTROL_BY_ID[id]
	if control==nil then return end
	UI.setAttribute(dropDownIdLink.."Image", "image", "Sliced Button/Button New Active")
	if dropDownIdLink==id then
		dropDownIdLink="none"
		UI.setAttribute("DropDown", "active", "false")
		UI.setAttribute(id.."Image", "image", "Sliced Button/Button New Active")
		return
	end

	dropDownIdLink=id
	local count=0
	for uiId,data in pairs(SETUP_DROPDOWN_ROWS) do
		UI.setAttribute(data[2], "image", "Sliced Button/Button New Active")
		local skip=data[3]~=control[2]
		if skip==false and data[1]=="All Skills" and control[1]~=5 then skip=true end
		if skip==false and customMages[data[1]]~=nil and gStates.useCustomMageKnights==false then skip=true end
		if skip==false and control[2]=="MageDropDown" then
			for x=1,5 do
				if gStates.positionMageKnight[x]==data[1] and data[1]~="nobody" and data[1]~="Random" then skip=true break end
				if control[1]==x and gStates.positionMageKnight[x]==data[1] then skip=true break end
			end
		end
		if data[1]==gStates.gameScenario then UI.setAttribute(data[2], "image", "Sliced Button/Button New Deactive") end
		if data[3]=="VolkareLevelDropDown" and data[4]==gStates.volkareCombatLevel then UI.setAttribute(data[2], "image", "Sliced Button/Button New Active") end
		if data[3]=="VolkareRaceDropDown" and data[4]==gStates.volkareRaceLevel then UI.setAttribute(data[2], "image", "Sliced Button/Button New Active") end
		if skip==false then UI.setAttribute(uiId, "active", "true") count=count+1 else UI.setAttribute(uiId, "active", "false") end
	end
	UI.setAttribute(id.."Image", "image", "Sliced Button/Button New Deactive")
	local dropDownHeight=count*(330/12)
	--Scenario rows are 30 px high; use an exact whole-row height to avoid pixel gaps.
	if control[2]=="ScenarioDropDown" then dropDownHeight=count*30 end
	UI.setAttribute("DropDown", "height", tostring(dropDownHeight))
	UI.setAttribute("DropDown", "width", control[2]=="ScenarioDropDown" and "220" or control[2]=="ROTFDropDown" and "150" or "120")
	UI.setAttribute("DropDown", "offsetXY", "-100 "..tostring(control[3]))
	UI.setAttribute("DropDown", "active", "true")
end

function PlayerChosen(player, mouseButton, id)
	if mouseButton=="-1" then
		UI.setAttribute(dropDownIdLink.."Text", "text", translateWord[MAGE_KNIGHT_SELECTION_BY_ID[id]])
		UI.setAttribute(dropDownIdLink.."Image", "image", "Sliced Button/Button New Active")
		UI.setAttribute("DropDown", "active", "false")
		--adjust number of players
		local MKDropDownUI=MAGE_KNIGHT_CONTROL_POSITION
		if dropDownIdLink~="dummyMKSelection" then
			if MAGE_KNIGHT_SELECTION_BY_ID[id]=="nobody" then
				if gStates.playerCount>0 then gStates.playerCount=gStates.playerCount-1 end
			else
				if gStates.positionMageKnight[MKDropDownUI[dropDownIdLink]]=="nobody" then gStates.playerCount=gStates.playerCount+1 end
			end
		end
		if dropDownIdLink=="dummyMKSelection" and gStates.positionMageKnight[MKDropDownUI[dropDownIdLink]]=="Volkare" then
			gStates.volkareSkills=MAGE_KNIGHT_SELECTION_BY_ID[id]
			gStates.setupDummyMageChoice=MAGE_KNIGHT_SELECTION_BY_ID[id]
		else
			gStates.positionMageKnight[MKDropDownUI[dropDownIdLink]]=MAGE_KNIGHT_SELECTION_BY_ID[id]
			if dropDownIdLink=="dummyMKSelection" then gStates.setupDummyMageChoice=MAGE_KNIGHT_SELECTION_BY_ID[id] end
		end

		if MAGE_KNIGHT_SELECTION_BY_ID[id]=="Jormund" then
			UI.setAttribute("ROTFSelectionText","text",ROTF_TEXT_BY_LEVEL[3])
			gStates.riseOfTheForgemasters=3
		end
		refreshProxySetupLabel()
		ToolTipUpdate(MAGE_KNIGHT_SELECTION_BY_ID[id])
		--Set Coop flag
		gStates.coop=gStates.positionMageKnight[5]=="nobody" and 0 or 1
		--reset megapolis
		gStates.megapolis=0
		scenarioInfoUpdate()
		dropDownIdLink="none"
	end
end

function VolkareLevelSelection(player, mouseButton, id)
	if mouseButton=="-1" then
		UI.setAttribute("VolkareLevelSelectionText", "text", translateWord[VOLKARE_COMBAT_SELECTION_BY_ID[id][1]])
		UI.setAttribute("VolkareLevelSelectionImage", "image", "Sliced Button/Button New Active")
		UI.setAttribute("DropDown", "active", "false")
		gStates.volkareCombatLevel=VOLKARE_COMBAT_SELECTION_BY_ID[id][2]
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
		UI.setAttribute("VolkareRaceSelectionText", "text", translateWord[VOLKARE_RACE_SELECTION_BY_ID[id][1]])
		UI.setAttribute("VolkareRaceSelectionImage", "image", "Sliced Button/Button New Active")
		UI.setAttribute("DropDown", "active", "false")
		gStates.volkareRaceLevel=VOLKARE_RACE_SELECTION_BY_ID[id][2]
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
		setUIButtonEnabled(control,not locked)
	end
end

function baseValueTweak(player, mouseButton, id)
	if mouseButton=="-1" then
		local setup=scenarioList[gStates.scenarioRef][gStates.playersRef]
		if scenarioMapIsPredefined() and (id=="MapDown" or id=="MapUp" or id=="CountryDown" or id=="CountryUp" or id=="CoreDown" or id=="CoreUp" or id=="CityDown" or id=="CityUp") then return end
		if gStates.volkareCampAsCity==true and (id=="MegapolisDown" or id=="MegapolisUp") then return end
		if gStates.gameScenario~="First Reconnaissance" then
			if id=="RoundsDown" or id=="RoundsUp" then
				if id=="RoundsDown" then
					if setup.rounds>1 then
						setup.rounds=setup.rounds-1
					end
				else
					setup.rounds=setup.rounds+1
				end
				setup.discardTactics=setup.dTW
				if setup.rounds>6 and setup.discardTactics==2 then setup.discardTactics=1 end
				if setup.rounds>14-(2*(gStates.playerCount+gStates.coop)) and setup.discardTactics==1 then setup.discardTactics=0 end
			end

			if id=="MapDown" or id=="MapUp" then
				local mapShapes={"wedge","open3","open4","open"}
				if gStates.gameScenario=="Custom" then mapShapes[#mapShapes+1]="predefined" end
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
					local countryMin=3
					if setup.mapShapeKey=="wedge" then countryMin=4 end--Enough to get to the legal core positions
					if setup.countryTiles>countryMin then
						setup.countryTiles=setup.countryTiles-1
					end
				else
					local max=14
					if gStates.removeTerrain==true then max=max-2 end
					if gStates.removeApocalypseTerrain~=true then max=max+3 end
					if gStates.removeLostLegionExpansion==true then max=max-3 end
					if setup.countryTiles<max then
						setup.countryTiles=setup.countryTiles+1
					end
				end
			end

			if id=="CoreDown" or id=="CoreUp" then
				if id=="CoreDown" then
					if setup.coreTiles>0 then
						setup.coreTiles=setup.coreTiles-1
					end
				else
					local max=6
					if gStates.removeApocalypseTerrain~=true then max=max+2 end
					if gStates.removeLostLegionExpansion==true then max=max-2 end
					if setup.coreTiles<max then
						setup.coreTiles=setup.coreTiles+1
					end
				end
			end

			if (id=="CityDown" or id=="CityUp") and gStates.gameScenario~="The Gauntlet" and gStates.gameScenario~="Volkare's Return" and gStates.gameScenario~="First Conquest" and gStates.gameScenario~="Conquer and Hold" then
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
					if gStates.megapolis==0 and setup.cityLevels[#setup.cityLevels]>22 then setup.cityLevels[#setup.cityLevels]=22 end
					if gStates.megapolis==1 and setup.cityLevels[#setup.cityLevels-1]>22 then setup.cityLevels[#setup.cityLevels-1]=22 end
				else
					local megapolisMaximum=megapolisMaximumForSetup(gStates.scenarioRef,gStates.playersRef)
					if gStates.megapolis<megapolisMaximum then gStates.megapolis=gStates.megapolis+1 ensureSetupMegapolisMinimumLevels() end
				end
			end

			for a=1, 5, 1 do
				if id=="CityLevel"..a.."Down" or id=="CityLevel"..a.."Up" then
					if setup.cityLevels[a]>0 then
						if id=="CityLevel"..a.."Down" then
							local min=1
							if gStates.megapolis==2 or (gStates.megapolis==1 and setup.cityTiles==a) then min=2 end
							if setup.cityLevels[a]>min then
								setup.cityLevels[a]=setup.cityLevels[a]-1
							else
								break
							end
						else
							local max=22
							if gStates.megapolis==2 or (gStates.megapolis==1 and setup.cityTiles==a) then max=22 end
							if gStates.gameScenario=="Life and Death" or gStates.gameScenario=="The Realm of the Dead Blitz" or gStates.gameScenario=="The Hidden Valley Blitz" or
								(gStates.gameScenario=="Custom" and setup.cityTiles==0) then max=12 end
							if a==setup.cityTiles+1 and
								(gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz" or gStates.gameScenario=="Volkare's Quest" or gStates.gameScenario=="The War of Four") then max=80 end
							if setup.cityLevels[a]<max then
								setup.cityLevels[a]=setup.cityLevels[a]+1
							else
								break
							end
						end
						if gStates.gameScenario=="Life and Death" and (a==1 or a==2) then
							if a==1 then
								setup.cityLevels[2]=setup.cityLevels[1]
							else
								setup.cityLevels[1]=setup.cityLevels[2]
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

local function recountSetupMageKnights()
	gStates.playerCount=0
	local customSelected=false
	local jormundSelected=false
	for position=1,4 do
		local mage=gStates.positionMageKnight[position] or "nobody"
		if mage~="nobody" then gStates.playerCount=gStates.playerCount+1 end
		if customMages[mage]~=nil then customSelected=true end
		if mage=="Jormund" then jormundSelected=true end
	end
	local rememberedDummy=gStates.setupDummyMageChoice or
		(gStates.positionMageKnight[5]=="Volkare" and gStates.volkareSkills) or gStates.positionMageKnight[5]
	if customMages[rememberedDummy]~=nil then customSelected=true end
	if rememberedDummy=="Jormund" then jormundSelected=true end
	gStates.coop=gStates.positionMageKnight[5]~="nobody" and 1 or 0
	return customSelected,jormundSelected
end

local function scenarioUsesVolkareArmyLevel()
	return gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz" or
		gStates.gameScenario=="Volkare's Quest" or gStates.gameScenario=="The War of Four"
end

local function volkareCampAsCitySelectable()
	return gStates.gameScenario=="First Conquest" or gStates.gameScenario=="Conquest" or
		gStates.gameScenario=="Conquest Blitz" or gStates.gameScenario=="One to Return" or
		gStates.gameScenario=="Fast Forwarded Conquest" or gStates.gameScenario=="The Lost Relic Blitz" or
		gStates.gameScenario=="Ultimate Conquest" or gStates.gameScenario=="The Fractured Lands Blitz" or
		gStates.gameScenario=="Against the Horsemen Blitz"
end

local function reconcileScenarioHardLocks()
	local overrides=SCENARIO_OPTION_OVERRIDES[gStates.gameScenario]
	if overrides==nil then return end
	for id,details in pairs(overrides) do
		if details[2]==false then gStates[id]=details[1] end
	end
end

local function renderScenarioHardLocks()
	local overrides=SCENARIO_OPTION_OVERRIDES[gStates.gameScenario]
	if overrides==nil then return end
	for id,details in pairs(overrides) do
		if details[2]==false then
			UI.setAttribute(id,"isOn",details[1] and "true" or "false")
			UI.setAttribute(id,"interactable","False")
		end
	end
end

local function reconcileScenarioSetupValues()
	gStates.playersRef=setupPlayersRef()
	gStates.scenarioRef=scenarioRefForName(gStates.gameScenario)
	local scenario=scenarioList[gStates.scenarioRef]
	local setup=scenario~=nil and scenario[gStates.playersRef] or nil
	if setup==nil then return end

	if gStates.megapolis==0 and scenarioUsesVolkareArmyLevel() then
		for index,level in pairs(setup.cityLevels) do
			if index~=setup.cityTiles+1 and level>22 then setup.cityLevels[index]=22 end
		end
	end

	local megapolisMaximum=megapolisMaximumForSetup(gStates.scenarioRef,gStates.playersRef)
	if gStates.megapolis>megapolisMaximum then gStates.megapolis=megapolisMaximum end
	ensureSetupMegapolisMinimumLevels()

	if gStates.removeLostLegionExpansion==true or gStates.megapolis>0 then
		gStates.volkareCampAsCity=false
	elseif #setup.cityLevels==5 and not scenarioUsesVolkareArmyLevel() then
		gStates.volkareCampAsCity=true
	elseif not volkareCampAsCitySelectable() then
		gStates.volkareCampAsCity=false
	end
end

local function renderVolkareCampAsCityOption(setup)
	local forcedFiveCities=#setup.cityLevels==5 and not scenarioUsesVolkareArmyLevel()
	local enabled=not gStates.removeLostLegionExpansion and gStates.megapolis==0 and not forcedFiveCities and volkareCampAsCitySelectable()
	UI.setAttribute("volkareCampAsCity","isOn",gStates.volkareCampAsCity==true and "true" or "false")
	UI.setAttribute("volkareCampAsCity","interactable",enabled and "True" or "False")
end

function reconcileSetupState()
	if gStates==nil then return end

	local customLocked,customValue=scenarioOptionHardLock("useCustomMageKnights")
	if customLocked and customValue==false then clearCustomMageKnightSelections(true) end
	reconcileScenarioHardLocks()
	if gStates.gameScenario=="First Reconnaissance" then gStates.riseOfTheForgemasters=0 end

	local customSelected,jormundSelected=recountSetupMageKnights()
	if customLocked then
		gStates.useCustomMageKnights=customValue==true
	elseif customSelected then
		gStates.useCustomMageKnights=true
	end
	if gStates.gameScenario~="First Reconnaissance" and jormundSelected then gStates.riseOfTheForgemasters=3 end
	if (gStates.riseOfTheForgemasters or 0)>0 then applyForgemasterExpansionRequirements() end

	local bonusLocked,bonusValue=scenarioOptionHardLock("removeBonusCards")
	if bonusLocked then gStates.removeBonusCards=bonusValue==true end

	recountSetupMageKnights()
	reconcileLostLegionExpansionState()
	reconcileScenarioSetupValues()
end

local function renderMageKnightSetupAvailability()
	local maxPlayers=setupScenarioMaxMageKnights()
	for position=1,4 do
		local available=gStates.positionMageKnight[position]~="nobody" or gStates.playerCount<maxPlayers
		local id=MAGE_KNIGHT_CONTROL_IDS[position]
		setUIButtonEnabled(id,available)
	end

	local dummyLocked=gStates.gameScenario=="Conquer and Hold" or gStates.gameScenario=="One to Return"
	local dummyPlayerLimited=gStates.gameScenario=="First Reconnaissance" or gStates.gameScenario=="Quest for the Golden Grail" or
		gStates.gameScenario=="The Chaos Rift" or gStates.gameScenario=="The Gauntlet" or gStates.gameScenario=="Druid Nights" or
		gStates.gameScenario=="Dungeon Lords" or gStates.gameScenario=="Mines Liberation"
	local dummyAvailable=not dummyLocked and (gStates.positionMageKnight[5]=="Volkare" or not dummyPlayerLimited or gStates.playerCount<2)
	setUIButtonEnabled("dummyMKSelection",dummyAvailable)

	UI.setAttribute("useCustomMageKnights","isOn",gStates.useCustomMageKnights==true and "true" or "false")
	UI.setAttribute("ROTFSelectionText","text",ROTF_TEXT_BY_LEVEL[gStates.riseOfTheForgemasters or 0] or SETUP_TEXT.notUsed)

	local bonusLocked=scenarioOptionHardLock("removeBonusCards")
	local rotf=(gStates.riseOfTheForgemasters or 0)>0
	UI.setAttribute("removeBonusCards","isOn",gStates.removeBonusCards==true and "true" or "false")
	UI.setAttribute("removeBonusCards","interactable",(not bonusLocked and not rotf) and "True" or "False")

	renderLostLegionExpansionOption()
	renderScenarioHardLocks()
	refreshHeroChallengeOptionLocks()
end

function refreshMageKnightSetupAvailability()
	reconcileSetupState()
	renderMageKnightSetupAvailability()
end

function refreshSetupStartButton()
	UI.setAttribute("WarOfFourStartButton", "active", "false")
	UI.setAttribute("StartButton", "active", "false")
	UI.setAttribute("StartButton", "width", "1000")
	local tooMany=gStates.playerCount>setupScenarioMaxMageKnights()
	local heroChallengeLegal,heroChallengeReason=heroChallengeSetupIsLegal()
	if tooMany then
		setUIButtonEnabled("StartButton",false)
		UI.setAttribute("StartButtonText", "text", "{en}Too Many Mage Knights{ru}Слишком много Рыцарей-магов{zh-tw}魔法騎士過多{zh-cn}魔法骑士过多{ko}메이지 나이트가 너무 많습니다{es}Demasiados Mage Knights{fr}Trop de Mage Knights{pt-br}Mage Knights demais{de}Zu viele Mage Knights")
		UI.setAttribute("StartButton", "active", "true")
	elseif heroChallengeLegal~=true then
		setUIButtonEnabled("StartButton",false)
		UI.setAttribute("StartButtonText", "text", heroChallengeReason or "{en}Hero Challenges: Invalid setup{ru}Испытания героев: недопустимая настройка{zh-tw}英雄挑戰：無效設置{zh-cn}英雄挑战：无效设置{ko}영웅 도전: 잘못된 설정{es}Desafíos de Héroes: configuración no válida{fr}Défis des Héros : configuration invalide{pt-br}Desafios de Heróis: configuração inválida{de}Heldenherausforderungen: ungültiger Aufbau")
		UI.setAttribute("StartButton", "active", "true")
	elseif gStates.playerCount>=2 or (gStates.playerCount>=1 and gStates.positionMageKnight[5]~="nobody") then
		setUIButtonEnabled("StartButton",true)
		if gStates.playerCount==1 then
			UI.setAttribute("StartButtonText", "text", SETUP_TEXT.startSolo)
		elseif gStates.positionMageKnight[5]=="nobody" then
			UI.setAttribute("StartButtonText", "text", SETUP_TEXT.startCompetitive)
		else
			UI.setAttribute("StartButtonText", "text", SETUP_TEXT.startCooperative)
		end
		if gStates.gameScenario=="The War of Four" and gStates.playerCount>=2 then
			UI.setAttribute("WarOfFourStartButton", "active", "True")
			UI.setAttribute("StartButton", "width", "500")
		end
		UI.setAttribute("StartButton", "active", "true")
	else
		setUIButtonEnabled("StartButton",false)
		UI.setAttribute("StartButtonText", "text", "{en}Start - Select at least two Mage Knights first{ru}Начало - Сначала выберите как минимум двух Рыцарей-магов.{zh-tw}開始 - 首先選擇至少兩位魔法騎士{zh-cn}开始 - 首先选择两位魔法骑士{ko}시작 - 먼저 두 명 이상의 플레이어를 선택하세요{es}Comenzar - Selecciona al menos dos Mage Knight {fr}Démarrer - Sélectionnez d'abord au moins deux Mages{pt-br}Início - Selecione ao menos dois Mage Knights primeiro{de}Start - Wähle vorher mindestens 2 Mage Knights")
		UI.setAttribute("StartButton", "active", "true")
	end
end

function scenarioInfoUpdate()
	reconcileSetupState()
	local scenario=scenarioList[gStates.scenarioRef]
	local setup=scenario[gStates.playersRef]
	local details=scenario.scenarioDetails
	renderMageKnightSetupAvailability()
	renderDummySetupSection()
	--Update Scenario Infos
	UI.setAttribute("ScenarioDetails", "active", "true")
	UI.setAttribute("IntroBoard", "active", "false")
	UI.setAttribute("ScenarioName", "text", joinLang({translateWord[gStates.gameScenario], "{en} Purpose{ru} Цель{zh-tw} 目的{zh-cn} 目的{ko} 목적{es} Propósito{fr} Objectif{pt-br} Finalidade{de} Zweck"}))
	UI.setAttribute("PlayerCount", "text", details.playerDetails)
	UI.setAttribute("ScenarioLength", "text", joinLang({"{en}Length - {ru}Продолжительность - {zh-tw}遊戲時長：{zh-cn}游戏时长：{ko}길이 - {es}Duración - {fr}Longueur - {pt-br}Duração - {de}Länge - ", setup.rounds, "{en} Rounds{ru} Раунд(а/ов){zh-tw} 輪次{zh-cn} 轮次{ko}라운드{es} Rondas{fr} Rounds{pt-br} Rodadas{de} Runden"}))
	UI.setAttribute("ScenarioPurpose", "text", details.scenarioPurpose)
	UI.setAttribute("ScenarioShape", "text", joinLang({"{en}Map Shape - {ru}Форма поля - {zh-tw}地圖形狀：{zh-cn}地图形状：{ko}지도 모양 - {es}Forma del Mapa - {fr}Forme de la Carte - {pt-br}Formato de Mapa - {de}Karten Form - ", setup.mapShape}))
	--Display the amount of country tiles and any rules
	if details.countryRules~=nil then
		if details.countryRules[1]==nil then
			UI.setAttribute("ScenarioCountry", "text", joinLang({SETUP_TEXT.countryTilesPrefix, setup.countryTiles.." ", details.countryRules}))
		else
			UI.setAttribute("ScenarioCountry", "text", joinLang({SETUP_TEXT.countryTilesPrefix, setup.countryTiles.." ", details.countryRules[gStates.playersRef]}))
		end
	else
		UI.setAttribute("ScenarioCountry", "text", joinLang({SETUP_TEXT.countryTilesPrefix, setup.countryTiles}))
	end
	--Display the amount of core tiles and any rules
	if details.coreRules~=nil then
		UI.setAttribute("ScenarioCore", "text", joinLang({SETUP_TEXT.coreTilesPrefix, setup.coreTiles.." ", details.coreRules}))
	else
		UI.setAttribute("ScenarioCore", "text", joinLang({SETUP_TEXT.coreTilesPrefix, setup.coreTiles}))
	end
	--Display the amount of city tiles and any rules
	if details.cityRules~=nil then
		UI.setAttribute("ScenarioCity", "text", joinLang({SETUP_TEXT.cityTilesPrefix, setup.cityTiles.." ", details.cityRules}))
	else
		UI.setAttribute("ScenarioCity", "text", joinLang({SETUP_TEXT.cityTilesPrefix, setup.cityTiles}))
	end
	--Display City Levels and Megapolis controls from the reconciled setup state.
	local megapolisMaximum=megapolisMaximumForSetup(gStates.scenarioRef,gStates.playersRef)
	local currentCitySetup=setup
	local customLeaderOnly=gStates.gameScenario=="Custom" and currentCitySetup.cityTiles==0 and gStates.removeShadesOfTezlaMonsters~=true
	local hasCityLevelControls=currentCitySetup.cityLevels[1]~=nil and currentCitySetup.cityLevels[1]>0 and (currentCitySetup.cityTiles>0 or customLeaderOnly)
	local showMegapolisControls=hasCityLevelControls and #currentCitySetup.cityLevels<=3 and megapolisMaximum>0
	UI.setAttribute("MegapolisLeft","active",showMegapolisControls and "true" or "false")
	UI.setAttribute("MegapolisRight","active",showMegapolisControls and "true" or "false")
	UI.setAttribute("MegapolisReminder","active",showMegapolisControls and "true" or "false")
	if showMegapolisControls then
		local canUp=gStates.megapolis<megapolisMaximum
		local canDown=gStates.megapolis>0
		setUIButtonEnabled("MegapolisUp",canUp)
		setUIButtonEnabled("MegapolisDown",canDown)
	end
	if hasCityLevelControls then
		UI.setAttribute("CityNote", "active", "false")
		UI.setAttribute("CityLevelsRow", "active", "true")
		UI.setAttribute("CityDescriptionRow", "active", "false")
		UI.setAttribute("CityLevelschange", "active", "false")
		--local b="<b>City Level(s) - </b>"
		local layout="28"
		if #setup.cityLevels>3 or megapolisMaximum==0 then layout="0" end
		for a=1, 5, 1 do
			if a<=#setup.cityLevels then
				UI.setAttribute("CL"..a, "active", "true")
				layout=layout.." 0"
				if #setup.cityLevels<=3 then
					if (gStates.megapolis==1 and a==setup.cityTiles) or (gStates.megapolis==2) and not (a==setup.cityTiles+1 and (gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz" or gStates.gameScenario=="Volkare's Quest" or gStates.gameScenario=="The War of Four")) then
						UI.setAttribute("ScenarioCity"..a.."Level", "text", joinLang({"{en}Megapolis, Lvl {ru}Мегаполис, ур. {zh-tw}大型城市，等級 {zh-cn}大型城市，等级 {ko}거대도시, 레벨 {es}Megapolis, Niv {fr}Megapolis, Niv {pt-br}Megápolis, Nvl {de}Metropoe, Lvl ", setup.cityLevels[a]}))
					else
						if (customLeaderOnly and a==1) or (a==1 and (gStates.gameScenario=="Life and Death" or gStates.gameScenario=="The Realm of the Dead Blitz" or gStates.gameScenario=="The Hidden Valley Blitz" or gStates.gameScenario=="The War of Four")) or (a==2 and (gStates.gameScenario=="Life and Death" or gStates.gameScenario=="The War of Four")) then
							UI.setAttribute("ScenarioCity"..a.."Level", "text", joinLang({"{en}Leader, Level {ru}Лидер, ур. {zh-tw}領袖，等級 {zh-cn}领袖，等级 {ko}지도자, 레벨 {es}Líder, Nivel {fr}Chef, Niveau {pt-br}Líder, Nível {de}Leiter, Level ", setup.cityLevels[a]}))
						else
							if setup.cityLevels[a]==0 then
								UI.setAttribute("ScenarioCity"..a.."Level", "text", "{en}Friendly City{ru}Друж. город{zh-tw}友方城市{zh-cn}友方城市{ko}도시(우호적){es}Ciudad Amistosa{fr}Ville Amicale{pt-br}Cidade Amigável{de}Freundliche Stadt")
							else
								if a==setup.cityTiles+1 and (gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz" or gStates.gameScenario=="Volkare's Quest" or gStates.gameScenario=="The War of Four") then
									UI.setAttribute("ScenarioCity"..a.."Level", "text", joinLang({"{en}Volkare, Level {ru}Волкар, ур. {zh-tw}沃卡里，等級 {zh-cn}沃卡里，等级 {ko}볼케어, 레벨{es}Volkare, Nivel {fr}Volkare, Niveau {pt-br}Volkare, Nível {de}Volkare, Ebene ", setup.cityLevels[a]}))
								else
									UI.setAttribute("ScenarioCity"..a.."Level", "text", joinLang({"{en}City, Level {ru}Город, ур. {zh-tw}城市，等級 {zh-cn}城市，等级 {ko}도시, 레벨 {es}Ciudad, Nivel {fr}Ville, Niveau {pt-br}Cidade, Nível {de}Stadt, Level ", setup.cityLevels[a]}))
								end
							end
						end
					end

				else
					if (a==1 or a==2) and gStates.gameScenario=="The War of Four" then
						UI.setAttribute("ScenarioCity"..a.."Level", "text", joinLang({"{en}Leader-{ru}Лидер-{zh-tw}領袖{zh-cn}领袖{ko}지도자-{es}Líder-{fr}Chef-{pt-br}Líder-{de}Leiter-", setup.cityLevels[a]}))
					else
						if a==setup.cityTiles+1 and (gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz" or gStates.gameScenario=="Volkare's Quest" or gStates.gameScenario=="The War of Four") then
							UI.setAttribute("ScenarioCity"..a.."Level", "text", joinLang({"{en}Volkare-{ru}Волкар-{zh-tw}沃卡里{zh-cn}沃卡里{ko}볼케어-{es}Volkare-{fr}Volkare-{pt-br}Volkare-{de}Volkare-", setup.cityLevels[a]}))
						else
							UI.setAttribute("ScenarioCity"..a.."Level", "text", joinLang({"{en}City-{ru}Город-{zh-tw}城市{zh-cn}城市{ko}도시-{es}Ciudad-{fr}Ville-{pt-br}Cidade-{de}Stadt-", setup.cityLevels[a]}))
						end
					end

				end
			else
				UI.setAttribute("CL"..a, "active", "false")
			end
		end
		if #setup.cityLevels<=3 then layout=layout.." 28" end
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
	--Volkare's Camp as City state was reconciled before rendering.
	renderVolkareCampAsCityOption(setup)
	--Display the Scenario End rules
	UI.setAttribute("ScenarioEnd", "text", details.scenarioEnd)
	refreshScenarioTerrainTweakLocks()
	--Only allow Start button if the current player selection is legal
	refreshSetupStartButton()
end

function SetupMenu(player, mouseButton, id)
	if mouseButton=="-1" then
		UI.setAttribute("Setup", "active", "true")
		UI.setAttribute("helpButtonRealImage", "image", "Sliced Button/Button New Deactive")
		UI.setAttribute("helpButtonReal", "interactable", "false")
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
	{id="VolkareLevelSelection",attribute="interactable"},
	{id="VolkareLevelSelectionText",attribute="text"},{id="VolkareLevelSelectionImage",attribute="image"},
	{id="VolkareRaceSelection",attribute="interactable"},
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
	return scenarioRefForName(gStates.gameScenario)
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
	local scenarioRef=scenarioRefForName(saved.scenario)
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
	if ROTF_TEXT_BY_LEVEL[gStates.riseOfTheForgemasters or 0]~=nil then UI.setAttribute("ROTFSelectionText","text",ROTF_TEXT_BY_LEVEL[gStates.riseOfTheForgemasters or 0]) end
	local combat={"Daring","Heroic","Legendary"}
	local race={"Fair","Tight","Thrilling"}
	if combat[gStates.volkareCombatLevel or 1]~=nil then UI.setAttribute("VolkareLevelSelectionText","text",translateWord[combat[gStates.volkareCombatLevel or 1]]) end
	if race[gStates.volkareRaceLevel or 1]~=nil then UI.setAttribute("VolkareRaceSelectionText","text",translateWord[race[gStates.volkareRaceLevel or 1]]) end
	UI.setAttribute("darknessComing","text",gStates.startAtNight==true and
		SETUP_TEXT.daylightComing or
		SETUP_TEXT.darknessComing)
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
	renderDummySetupSection()
end

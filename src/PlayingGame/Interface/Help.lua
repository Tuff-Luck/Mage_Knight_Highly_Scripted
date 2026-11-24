-- Cross-module help/reminder UI callback.
-- DisplayHelp is called by setup, gameplay UI and Global XML, so it must live in a module-global scope.

local function helpUtf8Length(value)
	local count=0
	for i=1,#value do
		local byte=value:byte(i)
		if byte<128 or byte>=192 then count=count+1 end
	end
	return count
end

local function helpEstimateLines(value,charsPerLine)
	local totalLines=0
	local lineStart=1
	while true do
		local lineEnd=string.find(value,"\n",lineStart,true)
		local line=lineEnd~=nil and string.sub(value,lineStart,lineEnd-1) or string.sub(value,lineStart)
		local length=helpUtf8Length(line)
		totalLines=totalLines+(length==0 and 1 or math.ceil(length/charsPerLine))
		if lineEnd==nil then break end
		lineStart=lineEnd+1
	end
	return math.max(totalLines,1)
end

local function helpMaxTranslatedLines(translatedText,charsPerLine)
	translatedText=tostring(translatedText or "")
	local maxLines=1
	local pos=1
	local foundTag=false
	while true do
		local tagStart,tagEnd=translatedText:find("{([%a%-]+)}",pos)
		if tagStart==nil then break end
		foundTag=true
		local nextTagStart=translatedText:find("{([%a%-]+)}",tagEnd+1)
		local translation=nextTagStart~=nil and translatedText:sub(tagEnd+1,nextTagStart-1) or translatedText:sub(tagEnd+1)
		maxLines=math.max(maxLines,helpEstimateLines(translation,charsPerLine))
		if nextTagStart==nil then break end
		pos=nextTagStart
	end
	if foundTag~=true then return helpEstimateLines(translatedText,charsPerLine) end
	return maxLines
end

local function setHelpNotesHeight(height)
	local helpNotes={"0b2a31","a3d667",
		playAreaGuideBackground[1],playAreaGuideText[1],
		playAreaGuideBackground[2],playAreaGuideText[2],
		playAreaGuideBackground[3],playAreaGuideText[3],
		playAreaGuideBackground[4],playAreaGuideText[4]}
	for _,guid in ipairs(helpNotes) do
		local obj=getObjectFromGUID(guid)
		if obj~=nil then
			local position=obj.getPosition()
			obj.setPosition({position[1],height,position[3]})
		end
	end
end

local function helpDistinctCurrentLevels(source,orderedNames)
	if type(source)~="table" then return nil end
	local seen,levels={},{}
	local function add(level)
		level=tonumber(level)
		if level~=nil and level>0 then
			level=math.floor(level)
			if seen[level]~=true then seen[level]=true levels[#levels+1]=level end
		end
	end
	if orderedNames~=nil then
		for _,name in ipairs(orderedNames) do
			local state=source[name]
			if state~=nil and state.defeated~=true and state.retired~=true then add(state.level) end
		end
	else
		for _,level in pairs(source) do add(level) end
	end
	table.sort(levels)
	return #levels>0 and levels or nil
end

local function helpLevelList(levels)
	local values={}
	for _,level in ipairs(levels or {}) do values[#values+1]=tostring(level) end
	return table.concat(values,", ")
end

function DisplayHelp(player, mouseButton, id)
	if mouseButton~="-1" then return end
	if gStates.help==true then
		UI.hide("PlayerSeating")
		UI.hide("ObjectRotating")
		UI.hide("PlayAreaRules")
		UI.hide("GameReminder")
		UI.hide("EndReminder")
		gStates.help=false
		setHelpNotesHeight(-2)
		return
	end
		local gameReminderText=joinLang({translateWord[gStates.gameScenario], "{en} Scenario{it} - Scenario{ru} Сценарий{zh-tw}剧本{zh-cn}剧本{ko} 시나리오{es} Guión{fr} Scénario{pt-br} Cenário{de} Szenario"})
		local gameReminderHeight=48
		local lineFeed=18
		if gStates.blitz==1 then gameReminderText=joinLang({gameReminderText, "{en}\nBlitz Rules{it}\nRegole Blitz{ru}\nСокращенный (Блиц){zh-tw}\n快速规则{zh-cn}\n快速规则{ko}\n기습 규칙{es}\nReglas de Blitz{fr}\nRègles du Blitz{pt-br}\nRegras Relâmpago{de}\nBlitz-Regeln"}) gameReminderHeight=gameReminderHeight+lineFeed end
		if gStates.removeLostLegionExpansion==false then
			gameReminderText=joinLang({gameReminderText,"{en}\nLost Legion Monsters and Cards Included{it}\nMostri e Carte Lost Legion Inclusi{ru}\nПотерянный Легион включен{zh-tw}\n使用失落军团怪物和卡牌{zh-cn}\n使用失落军团怪物和卡牌{ko}\n사라진 군단 확장 포함{es}\nMonstruos y Cartas de Lost Legion Incluidos{fr}\nMonstres et Cartes de la Légion Perdue Incluses{pt-br}\nMonstros e Cartas da Legião Perdida são incluídos{de}\nLost Legion-Monster und -Karten enthalten"})
		else
			gameReminderText=joinLang({gameReminderText,"{en}\nLost Legion Expansion Removed{it}\nEspansione Lost Legion Rimossa{ru}\nПотерянный Легион убран{zh-tw}\n已移除失落軍團擴充{zh-cn}\n已移除失落军团扩展{ko}\n사라진 군단 확장 제거됨{es}\nExpansión La Legión Perdida eliminada{fr}\nExtension Lost Legion supprimée{pt-br}\nExpansão Legião Perdida removida{de}\nLost Legion-Erweiterung entfernt"})
		end
		gameReminderHeight=gameReminderHeight+lineFeed
		if gStates.removeShadesOfTezlaMonsters==true then
			gameReminderText=joinLang({gameReminderText, "{en}\nShades of Tezla Monsters Removed{it}\nMostri Shades of Tezla Rimossi{ru}\nВраги из «Теней Тезлы» убраны{zh-tw}\n已移除「特茲拉之影」怪物{zh-cn}\n已移除“特兹拉之影”怪物{ko}\n'테즐라의 그림자' 적 토큰 제거{es}\nMonstruos de 'Sombras de Tezla' eliminados{fr}\nMonstres de 'Ombres de Tezla' retirés{pt-br}\nMonstros de 'Sombras de Tezla' removidos{de}\n'Shades of Tezla'-Monster entfernt"})
		else
			gameReminderText=joinLang({gameReminderText, "{en}\nShades of Tezla Monsters Included{it}\nMostri Shades of Tezla Inclusi{ru}\nВраги из «Теней Тезлы» включены{zh-tw}\n使用「特茲拉之影」怪物{zh-cn}\n使用“特兹拉之影”怪物{ko}\n'테즐라의 그림자' 적 토큰 포함{es}\nMonstruos de 'Sombras de Tezla' incluidos{fr}\nMonstres de 'Ombres de Tezla' inclus{pt-br}\nMonstros de 'Sombras de Tezla' incluídos{de}\n'Shades of Tezla'-Monster enthalten"})
		end
		gameReminderHeight=gameReminderHeight+lineFeed
		if gStates.removeApocalypseTerrain==true then
			gameReminderText=joinLang({gameReminderText, "{en}\nApocalypse Dragon Terrain Removed{it}\nTerreno Apocalypse Dragon Rimosso{ru}\nЛандшафт «Апокалиптический дракон» удалён{zh-tw}\n已移除末日巨龍地形{zh-cn}\n已移除末日巨龙地形{ko}\n아포칼립스 드래곤 지형 제거{es}\nTerreno del Dragón del Apocalipsis eliminado{fr}\nTerrain Apocalypse Dragon supprimé{pt-br}\nTerreno do Dragão do Apocalipse removido{de}\nApocalypse-Dragon-Gelände entfernt"})
		else
			gameReminderText=joinLang({gameReminderText, "{en}\nApocalypse Dragon Terrain Included{it}\nTerreno Apocalypse Dragon Incluso{ru}\nЛандшафт «Апокалиптический дракон» включён{zh-tw}\n使用末日巨龍地形{zh-cn}\n使用末日巨龙地形{ko}\n아포칼립스 드래곤 지형 포함{es}\nTerreno del Dragón del Apocalipsis incluido{fr}\nTerrain Apocalypse Dragon inclus{pt-br}\nTerreno do Dragão do Apocalipse incluído{de}\nApocalypse-Dragon-Gelände enthalten"})
		end
		gameReminderHeight=gameReminderHeight+lineFeed
		if gStates.removeBonusCards==true then gameReminderText=joinLang({gameReminderText, "{en}\nUltimate Edition Cards Removed{it}\nCarte Ultimate Edition Rimosse{ru}\nПолное издание не включено{zh-tw}\n移除终极版的额外卡牌{zh-cn}\n移除终极版的额外卡牌{ko}\nUE 카드 제외{es}\nTarjetas de Ultimate Edition Eliminadas{fr}\nCartes Ultimate Edition Supprimées{pt-br}\nCartas da Edição Definitiva Removidas{de}\nUltimate Edition Karten entfernt"}) gameReminderHeight=gameReminderHeight+lineFeed else
			gameReminderText=joinLang({gameReminderText, "{en}\nUltimate Edition Cards Included{it}\nCarte Ultimate Edition Incluse{ru}\nПолное издание включено{zh-tw}\n使用终极版的额外卡牌{zh-cn}\n使用终极版的额外卡牌{ko}\nUE 카드 포함{es}\nTarjetas de Ultimate Edition Incluidas{fr}\nCartes Ultimate Edition incluses{pt-br}\nCartas da Edição Definitiva Incluídas{de}\nUltimate Edition Karten enthalten"}) gameReminderHeight=gameReminderHeight+lineFeed end
		if gStates.rampage==1 then gameReminderText=joinLang({gameReminderText, "{en}\nRampage Variant{it}\nVariante Devastazione{ru}\nТемные времена!{zh-tw}\n怪物肆虐{zh-cn}\n怪物肆虐{ko}\n광분하라!{es}\nVariante de Rampage{fr}\nVariante Rampage{pt-br}\nVariante Tempos de Violência{de}\nRampage-Variante"}) gameReminderHeight=gameReminderHeight+lineFeed end
		if gStates.rampage==2 then gameReminderText=joinLang({gameReminderText, "{en}\nMore Rampage Variant{it}\nVariante Ancora Devastazione{ru}\nТьма сгущается!{zh-tw}\n怪物横行{zh-cn}\n怪物横行{ko}\n더욱더 광분하라!{es}\nMás Variante de Rampage{fr}\nPlus de variante Rampage{pt-br}\nVariante Mais Violência{de}\nMehr Rampage-Variante"}) gameReminderHeight=gameReminderHeight+lineFeed end
		if gStates.rampageAmbush==true then gameReminderText=joinLang({gameReminderText, "{en}\nAmbushing Rampagers Variant{it}\nVariante Nemici Erranti in Agguato{ru}\nВраги в Засаде{zh-tw}\n怪物伏击{zh-cn}\n怪物伏击{ko}\n매복하는 적{es}\nVariante Emboscada de Rampagers{fr}\nVariante de Rampagers Embusqués{pt-br}\nVariante Irascíveis Emboscadores{de}\nAmbushing Rampagers-Variante"}) gameReminderHeight=gameReminderHeight+lineFeed end
		if gStates.rampagePursuit==true then gameReminderText=joinLang({gameReminderText, "{en}\nPursuing Rampagers Variant{it}\nVariante Nemici Erranti Inseguitori{ru}\nПреследующие враги{zh-tw}\n怪物追击{zh-cn}\n怪物追击{ko}\n추적하는 적{es}\nPersiguiendo la Variante de Violentos{fr}\nVariante Poursuite des Rampagers{pt-br}\nVariante Irascíveis Perseguidores{de}\nVerfolgende Rampager-Variante"}) gameReminderHeight=gameReminderHeight+lineFeed end
		if gStates.randomTileOrientation==true then gameReminderText=joinLang({gameReminderText, "{en}\nRandom Terrain Tile Orientation Variant{it}\nVariante Orientamento Casuale del Terreno{ru}\nСлучайная ориентация Земель{zh-tw}\n随机地图方向{zh-cn}\n随机地图方向{ko}\n타일 방향 무작위로 놓기{es}\nVariante de Orientación de Mosaico de Terreno Aleatorio{fr}\nVariante d'Orientation des Tuiles de Terrain Aléatoire{pt-br}\nVariante Orientação aleatória de Terreno{de}\nVariante mit zufälliger Ausrichtung der Geländekacheln"}) gameReminderHeight=gameReminderHeight+lineFeed end
		if gStates.removeTerrain==true then gameReminderText=joinLang({gameReminderText, "{en}\nRemoved Easier Terrain Tiles{it}\nTessere Terreno più Facili Rimosse{ru}\nУдалены более простые плитки местности{zh-tw}\n已移除較簡單的地圖板塊{zh-cn}\n已移除较简单的地图板块{ko}\n쉬운 지형 타일 제거됨{es}\nSe retiraron las losetas de terreno más fáciles{fr}\nTuiles de terrain plus faciles retirées{pt-br}\nPeças de terreno mais fáceis removidas{de}\nEinfachere Geländeteile entfernt"}) gameReminderHeight=gameReminderHeight+lineFeed end
		local setupLevels={cityTiles=gStates.cityTiles,cityLevels=gStates.cityLevels}
		local levelGroups={city={},megapolis={},leader={},friendly={},destroyed={},volkare={}}
		for index,level in ipairs(gStates.cityLevels or {}) do
			local role=scenarioSetupLevelRole(gStates.gameScenario,setupLevels,index,gStates.removeShadesOfTezlaMonsters,gStates.megapolis)
			if role~=nil then levelGroups[role][#levelGroups[role]+1]=level end
		end
		local function appendLevelGroup(levels,countLabel)
			if #levels<1 then return end
			local levelText={}
			for _,level in ipairs(levels) do levelText[#levelText+1]=tostring(level) end
			gameReminderText=joinLang({gameReminderText,"\n"..#levels,countLabel,
				"{en} at Level(s): {it} ai Livelli: {ru} с уровнем(ями): {zh-tw}，起始等級：{zh-cn}，起始等级：{ko} 의 레벨: {es} en el Nivel(s): {fr} aux Niveaux : {pt-br} no Nível: {de} auf Stufe(n): ",
				table.concat(levelText,", ")})
			gameReminderHeight=gameReminderHeight+lineFeed
		end
		appendLevelGroup(levelGroups.city,"{en} City(s){it} Città{ru} Город(а){zh-tw} 城市{zh-cn} 城市{ko} 도시{es} Ciudad(s){fr} Ville(s){pt-br} Cidade(s){de} Stadt(en)")
		appendLevelGroup(levelGroups.megapolis,"{en} Megapolis{it} Megapoli{ru} Мегаполис{zh-tw} 大型城市{zh-cn} 大型城市{ko} 거대도시{es} Megapolis{fr} Megapolis{pt-br} Megalópole{de} Megapolis")
		appendLevelGroup(levelGroups.leader,"{en} Leader(s){it} Capi{ru} Лидер(ы){zh-tw} 领袖{zh-cn} 领袖{ko} 지도자{es} Líder(s){fr} Leader(s){pt-br} Líder(es){de} Anführer")
		if #levelGroups.destroyed>0 then
			gameReminderText=joinLang({gameReminderText,"\n"..#levelGroups.destroyed,"{en} Destroyed City(s){it} Città Distrutte{ru} Разрушенный(е) город(а){zh-tw} 被摧毀城市{zh-cn} 被摧毁城市{ko} 파괴된 도시{es} Ciudad(es) Destruida(s){fr} Ville(s) Détruite(s){pt-br} Cidade(s) Destruída(s){de} Zerstörte Stadt/Städte"})
			gameReminderHeight=gameReminderHeight+lineFeed
		end
		if #levelGroups.friendly>0 then
			gameReminderText=joinLang({gameReminderText,"\n"..#levelGroups.friendly,"{en} Friendly City(s){it} Città Amiche{ru} Дружелюбный(х) город(а){zh-tw} 友方势力城市{zh-cn} 友方势力城市{ko} 우호적인 도시{es} Ciudad(s) Amiga{fr} Ville(s) Amie{pt-br} Cidade(s) Amigável{de} Befreundete Stadt(en)"})
			gameReminderHeight=gameReminderHeight+lineFeed
		end
		if #levelGroups.volkare>0 then
			gameReminderText=joinLang({gameReminderText,"{en}\nVolkare, Level {it}\nVolkare, Livello {ru}\nВолкар, ур. {zh-tw}\n沃卡里，等級 {zh-cn}\n沃卡里，等级 {ko}\n볼케어, 레벨 {es}\nVolkare, Nivel {fr}\nVolkare, Niveau {pt-br}\nVolkare, Nível {de}\nVolkare, Ebene ",tostring(levelGroups.volkare[1])})
			gameReminderHeight=gameReminderHeight+lineFeed
		end

		local horsemanLevels=helpDistinctCurrentLevels(gStates.horsemen,{"Famine","Pestilence","Death","War"})
		if horsemanLevels==nil and scenarioUsesHorsemen()==true and type(horsemanStartingLevel)=="function" then
			local level=horsemanStartingLevel()
			if level~=nil then horsemanLevels={level} end
		end
		if horsemanLevels~=nil then
			gameReminderText=joinLang({gameReminderText,"{en}\nHorsemen, Level(s) {it}\nCavalieri, Livelli {ru}\nВсадники, ур. {zh-tw}\n騎士，等級 {zh-cn}\n骑士，等级 {ko}\n기수, 레벨 {es}\nJinetes, Nivel {fr}\nCavaliers, Niveau {pt-br}\nCavaleiros, Nível {de}\nReiter, Level ",helpLevelList(horsemanLevels)})
			gameReminderHeight=gameReminderHeight+lineFeed
		end
		local dragonLevels=helpDistinctCurrentLevels(gStates.apocalypseDragonHeadLevels)
		if dragonLevels==nil and scenarioUsesApocalypseDragon()==true and type(apocalypseDragonStartingLevel)=="function" then
			local level=apocalypseDragonStartingLevel()
			if level~=nil then dragonLevels={level} end
		end
		if dragonLevels~=nil then
			gameReminderText=joinLang({gameReminderText,"{en}\nDragon, Level(s) {it}\nDrago, Livelli {ru}\nДракон, ур. {zh-tw}\n巨龍，等級 {zh-cn}\n巨龙，等级 {ko}\n드래곤, 레벨 {es}\nDragón, Nivel {fr}\nDragon, Niveau {pt-br}\nDragão, Nível {de}\nDrache, Level ",helpLevelList(dragonLevels)})
			gameReminderHeight=gameReminderHeight+lineFeed
		end
		if gStates.gameScenario=="Ultimate Conquest" and gStates.removeShadesOfTezlaMonsters~=true then gameReminderText=joinLang({gameReminderText, "{en}\n2 Leaders - Level of last City revealed{it}\n2 Capi - Livello dell'ultima Città rivelata{ru}\n2 Лидеры - Уровень последнего раскрытого города{zh-tw}\n2 领袖 - 最后揭示的城市等级{zh-cn}\n2 领袖 - 最后揭示的城市等级{ko}\n2 지도자 - 마지막 도시 레벨 공개{es}\n2 líderes - Nivel de la última Ciudad Revelada{fr}\n2 Leaders - Niveau de la Dernière Ville Révélé{pt-br}\n2 Líderes - Nível da última cidade revelada{de}\n2 Anführer - Level der letzten aufgedeckten Stadt"}) gameReminderHeight=gameReminderHeight+lineFeed end
		--Volkare race/combat reminders.
		if gStates.positionMageKnight[5]=="Volkare" then
			if gStates.gameScenario~="The War of Four" then
				local volkareRaceLevel={"Fair","Tight","Thrilling"}
				gameReminderText=joinLang({gameReminderText,"\n",translateWord[volkareRaceLevel[gStates.volkareRaceLevel]],"{en} Volkare Race Level{it} Livello Corsa contro Volkare{ru} Уровень гонки Волкара{zh-tw} - 沃卡里竞速等级{zh-cn} - 沃卡里竞速等级{ko} 볼케어 레이스 레벨{es} Nivel de Carrera Volkare{fr} Niveau de Course Volkare{pt-br} Nível de Corrida de Volkare{de} Volkare Ethnie Stufe"})
				gameReminderHeight=gameReminderHeight+lineFeed
			end
			local volkareCombatLevel={"Daring", "Heroic", "Legendary"}
			gameReminderText=joinLang({gameReminderText, "\n", translateWord[volkareCombatLevel[gStates.volkareCombatLevel]], "{en} Volkare Combat Level{it} Livello Combattimento di Volkare{ru} Уровень битвы Волкара{zh-tw} - 沃卡里战斗等级{zh-cn} - 沃卡里战斗等级{ko} 볼케어 전투 레벨{es} Nivel de Carrera Volkare{fr} Volkare Niveau de Combat{pt-br} Nível de Combate de Volkare{de} Volkare Kampfstufe"}) gameReminderHeight=gameReminderHeight+lineFeed
		end
		if gStates.volkareCampAsCity==true then gameReminderText=joinLang({gameReminderText, "{en}\nVolkare's Camp as a City Variant{it}\nVariante Accampamento di Volkare come Città{ru}\nЛагерь Волкара как возможный город{zh-tw}\n沃卡里军营作为城市{zh-cn}\n沃卡里军营作为城市{ko}\n볼케어 진형을 도시 중 하나로 추가{es}\nEl Campamento de Volkare como Variante de la Ciudad{fr}\nLe camp de Volkare Comme Variante de la Ville{pt-br}\nVariante Acampamento de Volkare como uma Cidade{de}\nVolkare's Camp als Stadtvariante"}) gameReminderHeight=gameReminderHeight+lineFeed end
		if gStates.randomCities==true then gameReminderText=joinLang({gameReminderText, "{en}\nRandom Cities Variant{it}\nVariante Città Casuali{ru}\nСлучайные города{zh-tw}\n随机城市{zh-cn}\n随机城市{ko}\n무작위의 도시들{es}\nVariante de ciudades Aleatorias{fr}\nVariante de Villes Aléatoires{pt-br}\nVariante Cidades Aleatórias{de}\nZufallsstädte-Variante"}) gameReminderHeight=gameReminderHeight+lineFeed end
		--Only list scenario variants that are active, matching the other in-game reminders.
		local dragonCityMode=math.floor(tonumber(gStates.apocalypseDragonCityMode) or 0)
		if dragonCityMode==1 then
			gameReminderText=joinLang({gameReminderText,"{en}\nApocalypse Dragon as a City - Last City{it}\nDrago dell'Apocalisse come Città - Ultima Città{ru}\nДракон Апокалипсиса вместо города — Последний город{zh-tw}\n末日巨龍取代城市 - 最後城市{zh-cn}\n末日巨龙取代城市 - 最后城市{ko}\n아포칼립스 드래곤이 도시 대체 - 마지막 도시{es}\nDragón del Apocalipsis como Ciudad - Última Ciudad{fr}\nDragon de l'Apocalypse comme Cité - Dernière Cité{pt-br}\nDragão do Apocalipse como Cidade - Última Cidade{de}\nApokalypse-Drache als Stadt - Letzte Stadt"})
			gameReminderHeight=gameReminderHeight+lineFeed
		elseif dragonCityMode==2 then
			gameReminderText=joinLang({gameReminderText,"{en}\nApocalypse Dragon as a City - Random City{it}\nDrago dell'Apocalisse come Città - Città Casuale{ru}\nДракон Апокалипсиса вместо города — Случайный город{zh-tw}\n末日巨龍取代城市 - 隨機城市{zh-cn}\n末日巨龙取代城市 - 随机城市{ko}\n아포칼립스 드래곤이 도시 대체 - 무작위 도시{es}\nDragón del Apocalipsis como Ciudad - Ciudad Aleatoria{fr}\nDragon de l'Apocalypse comme Cité - Cité aléatoire{pt-br}\nDragão do Apocalipse como Cidade - Cidade Aleatória{de}\nApokalypse-Drache als Stadt - Zufällige Stadt"})
			gameReminderHeight=gameReminderHeight+lineFeed
		end
		if gStates.randomizedDragonHeads==true then
			gameReminderText=joinLang({gameReminderText,"{en}\nRandom Dragon Heads Variant{it}\nVariante Teste Casuali del Drago{ru}\nВариант случайных голов Дракона{zh-tw}\n隨機龍首變體{zh-cn}\n随机龙首变体{ko}\n드래곤 머리 무작위 변형{es}\nVariante de Cabezas Aleatorias del Dragón{fr}\nVariante des têtes aléatoires du Dragon{pt-br}\nVariante Cabeças Aleatórias do Dragão{de}\nDrachenköpfe-Zufallsvariante"})
			gameReminderHeight=gameReminderHeight+lineFeed
		end
		if gStates.horsemenHorses==true then
			gameReminderText=joinLang({gameReminderText,"{en}\nHorsemen's Horses Variant{it}\nVariante Cavalcature dei Cavalieri{ru}\nВариант с лошадьми Всадников{zh-tw}\n騎士戰馬變體{zh-cn}\n骑士战马变体{ko}\n기수들의 말 변형{es}\nVariante de Caballos de los Jinetes{fr}\nVariante des chevaux des Cavaliers{pt-br}\nVariante dos Cavalos dos Cavaleiros{de}\nReiterpferde-Variante"})
			gameReminderHeight=gameReminderHeight+lineFeed
		end
		if gStates.removeFactionRewards==true then
			gameReminderText=joinLang({gameReminderText,"{en}\nFaction Rewards Removed{it}\nRicompense di Fazione Rimosse{ru}\nНаграды фракций убраны{zh-tw}\n已移除派系獎勵{zh-cn}\n已移除派系奖励{ko}\n세력 보상 제거됨{es}\nRecompensas de Facción Eliminadas{fr}\nRécompenses de faction retirées{pt-br}\nRecompensas de Facção Removidas{de}\nFraktionsbelohnungen entfernt"})
			gameReminderHeight=gameReminderHeight+lineFeed
		end
		if gStates.startAtNight==true then gameReminderText=joinLang({gameReminderText, "{en}\nStart at Night Variant{it}\nVariante Inizia di Notte{ru}\nНочное прибытие{zh-tw}\n黑夜降临{zh-cn}\n黑夜降临{ko}\n야간 도착{es}\nComience en la Variante Nocturna{fr}\nVariante de Démarrage de Nuit{pt-br}\nVariante Início a Noite{de}\nStart bei Nacht Variante"}) gameReminderHeight=gameReminderHeight+lineFeed end
		if gStates.darknessComing==true then
			if gStates.dayRound==true then gameReminderText=joinLang({gameReminderText, "{en}\nDarkness is Coming Variant{it}\nVariante Arriva l'Oscurità{ru}\nНадвигается тьма{zh-tw}\n黑夜侵袭{zh-cn}\n黑夜侵袭{ko}\n어둠의 도래{es}\nLa oscuridad se Acerca Variante{fr}\nVariante des Ténèbres à Venir{pt-br}\nVariante Trevas estão Vindo{de}\nDunkelheit kommt Variante"}) gameReminderHeight=gameReminderHeight+lineFeed end
			if gStates.dayRound==false then gameReminderText=joinLang({gameReminderText, "{en}\nDaylight is Coming Variant{it}\nVariante Arriva la Luce{ru}\nНадвигается рассвет{zh-tw}\n白昼侵袭{zh-cn}\n白昼侵袭{ko}\n빛의 도래{es}\nLa luz del día está llegando Variante{fr}\nLa Lumière du Jour Arrive Variante{pt-br}\nVariante Luz do dia está vindo{de}\nVariante „Tageslicht kommt"}) gameReminderHeight=gameReminderHeight+lineFeed end
		end
		if gStates.questMod==true then gameReminderText=joinLang({gameReminderText, "{en}\nQuest Cards Variant{it}\nVariante Carte Missione{ru}\nМод Квест карт{zh-tw}\n自制任务卡{zh-cn}\n自制任务卡{ko}\n퀘스트 카드{es}\nVariante de Cartas de Misión{fr}\nVariante de Cartes de Quête{pt-br}\nVariante Cartas de Missões{de}\nQuest-Karten-Variante"}) gameReminderHeight=gameReminderHeight+lineFeed end
		if gStates.apocalypseQuestCards==true then gameReminderText=joinLang({gameReminderText, "{en}\nApocalypse Dragon Quest Cards{it}\nCarte Missione Apocalypse Dragon{ru}\nКарты заданий Apocalypse Dragon{zh-tw}\n末日巨龍任務卡{zh-cn}\n末日巨龙任务卡{ko}\n아포칼립스 드래곤 퀘스트 카드{es}\nCartas de Misión de Apocalypse Dragon{fr}\nCartes Quête d'Apocalypse Dragon{pt-br}\nCartas de Missão de Apocalypse Dragon{de}\nApocalypse-Dragon-Questkarten"}) gameReminderHeight=gameReminderHeight+lineFeed end
		if gStates.heroChallenges==true then gameReminderText=joinLang({gameReminderText, "{en}\nHero Challenges Variant{it}\nVariante Sfide degli Eroi{ru}\nHero Challenges Variant{zh-tw}\nHero Challenges Variant{zh-cn}\nHero Challenges Variant{ko}\nHero Challenges Variant{es}\nHero Challenges Variant{fr}\nHero Challenges Variant{pt-br}\nHero Challenges Variant{de}\nHero Challenges Variant"}) gameReminderHeight=gameReminderHeight+lineFeed end
		if gStates.proxyPlayer==true then gameReminderText=joinLang({gameReminderText, "{en}\nProxy Player Variant{it}\nVariante Giocatore Proxy{ru}\nВариант Прокси-игрока{zh-tw}\n代理玩家變體{zh-cn}\n代理玩家变体{ko}\n프록시 플레이어 변형{es}\nVariante Jugador Proxy{fr}\nVariante Joueur Proxy{pt-br}\nVariante Jogador Proxy{de}\nProxy-Spieler-Variante"}) gameReminderHeight=gameReminderHeight+lineFeed end
		if gStates.itemShopMod==true then gameReminderText=joinLang({gameReminderText, "{en}\nItem Shop Cards Variant{it}\nVariante Negozio di Oggetti{ru}\nМод магазина предметов{zh-tw}\n物品商店{zh-cn}\n物品商店{ko}\n아이템 상점 카드{es}\nVariante de las tarjetas de la tienda de artículos{fr}\nVariante des cartes de la boutique d'articles{pt-br}\nVariante de Cartões da Loja de Itens{de}\nArtikel-Shop-Karten-Variante"}) gameReminderHeight=gameReminderHeight+lineFeed end
		if gStates.weatherMod==true then gameReminderText=joinLang({gameReminderText, "{en}\nAtlantean Weather Variant{it}\nVariante Meteo Atlantideo{ru}\nМод Погоды Атлантиды{zh-tw}\n亚特兰蒂斯天气{zh-cn}\n亚特兰蒂斯天气{ko}\n아틀란티스 날씨{es}\nVariante Meteorológica Atlante{fr}\nVariante Météo Atlante{pt-br}\nVariante Clima Atlântico{de}\nAtlantische Wettervariante"}) gameReminderHeight=gameReminderHeight+lineFeed end
		if gStates.riseOfTheForgemasters==1 then gameReminderText=joinLang({gameReminderText, "{en}\nRise of the Forgemaster - 1 New Beginning{it}\nRise of the Forgemaster - 1 Nuovo Inizio{ru}\nВосхождение мастера-кузнеца — 1. Новое начало{zh-tw}\n锻造师崛起 - 新的开始{zh-cn}\n锻造师崛起 - 新的开始{ko}\n대장장이의 부상 - 1 새로운 시작{es}\nEl ascenso del maestro forjador - 1 Un nuevo comienzo{fr}\nRise of the Forgemaster - 1 Un nouveau départ{pt-br}\nA Ascensão do Mestre da Forja - 1 Um Novo Começo{de}\nRise of the Forgemaster – 1 Neuanfang"}) gameReminderHeight=gameReminderHeight+lineFeed end
		if gStates.riseOfTheForgemasters==2 then gameReminderText=joinLang({gameReminderText, "{en}\nRise of the Forgemaster - 2 Spoils of War{it}\nRise of the Forgemaster - 2 Bottino di Guerra{ru}\nВосхождение мастера-кузнеца — 2. Военные трофеи{zh-tw}\n锻造师崛起 - 战争犒赏{zh-cn}\n锻造师崛起 - 战争犒赏{ko}\n대장장이의 부상 - 2 전리품{es}\nEl ascenso del maestro forjador - 2 El botín de guerra{fr}\nRise of the Forgemaster - 2 Le butin de guerre{pt-br}\nA Ascensão do Mestre da Forja - 2 Despojos de Guerra{de}\nRise of the Forgemaster – 2 Kriegsbeute"}) gameReminderHeight=gameReminderHeight+lineFeed end
		if gStates.riseOfTheForgemasters==3 then gameReminderText=joinLang({gameReminderText, "{en}\nRise of the Forgemaster - 3 Elixir of Life{it}\nRise of the Forgemaster - 3 Elisir di Vita{ru}\nВосхождение мастера-кузнеца — 3. Эликсир жизни{zh-tw}\n锻造师崛起 - ⽣命灵药{zh-cn}\n锻造师崛起 - ⽣命灵药{ko}\n대장장이의 부상 - 3 생명의 엘릭서{es}\nEl ascenso del maestro forjador - 3 El elixir de la vida{fr}\nRise of the Forgemaster - 3 L'élixir de vie{pt-br}\nA Ascensão do Mestre da Forja - 3 Elixir da Vida{de}\nRise of the Forgemaster – 3 Elixier des Lebens"}) gameReminderHeight=gameReminderHeight+lineFeed end
		gameReminderHeight=math.max(gameReminderHeight,30+(lineFeed*helpMaxTranslatedLines(gameReminderText,48)))
		UI.setAttribute("GameReminderText","text",gameReminderText)
		UI.setAttribute("GameReminder","height",gameReminderHeight)
		for _, scenarioFull in pairs(scenarioList) do
			if scenarioFull[1]==gStates.gameScenario then
				local endReminderText=heroChallengeScenarioEndText(scenarioFull.scenarioDetails.scenarioEnd)
				UI.setAttribute("EndReminderText", "text", endReminderText)

				local maxLines=helpMaxTranslatedLines(endReminderText,106)
				local boxSize=math.max(117,(lineFeed*1.43)*maxLines)
				UI.setAttribute("EndReminder","height",boxSize)
				break
			end
		end
		UI.show("PlayerSeating")
		UI.show("ObjectRotating")
		UI.show("PlayAreaRules")
		UI.show("GameReminder")
		UI.show("EndReminder")
		gStates.help=true
		setHelpNotesHeight(3)
end

-- Cross-module help/reminder UI callback.
-- DisplayHelp is called by setup, gameplay UI and Global XML, so it must live in a module-global scope.

function DisplayHelp(player, mouseButton, id)
	if mouseButton=="-1" then
		--update Game Reminder text scenarioList[gStates.gameScenario][scenarioEnd]
		local gameReminderText=joinLang({translateWord[gStates.gameScenario], "{en} Scenario{ru} Сценарий{zh-tw}剧本{zh-cn}剧本{ko} 시나리오{es} Guión{fr} Scénario{pt-br} Cenário{de} Szenario"})
		local gameReminderHeight=48
		local lineFeed=18
		--if gStates.gameScenario:reverse():sub(1, 5)=="ztilB" then gameReminderText=gStates.gameScenario:sub(1, string.len(gStates.gameScenario)-6).." Scenario" end
		if gStates.blitz==1 then gameReminderText=joinLang({gameReminderText, "{en}\nBlitz Rules{ru}\nСокращенный (Блиц){zh-tw}\n快速规则{zh-cn}\n快速规则{ko}\n기습 규칙{es}\nReglas de Blitz{fr}\nRègles du Blitz{pt-br}\nRegras Relâmpago{de}\nBlitz-Regeln"}) gameReminderHeight=gameReminderHeight+lineFeed end
		if gStates.removeLostLegionExpansion==false then gameReminderText=joinLang({gameReminderText, "{en}\nLost Legion Monsters and Cards Included{ru}\nПотерянный Легион включен{zh-tw}\n使用失落军团怪物和卡牌{zh-cn}\n使用失落军团怪物和卡牌{ko}\n사라진 군단 확장 포함{es}\nMonstruos y Cartas de Lost Legion Incluidos{fr}\nMonstres et Cartes de la Légion Perdue Incluses{pt-br}\nMonstros e Cartas da Legião Perdida são incluídos{de}\nLost Legion-Monster und -Karten enthalten"}) gameReminderHeight=gameReminderHeight+lineFeed 	end
		-- else
		-- 	gameReminderText=joinLang({gameReminderText, "{en}\nLost Legion Monsters and Cards Removed{ru}\nПотерянный Легион не включен{zh-tw}\n移除失落军团怪物和卡牌{zh-cn}\n移除失落军团怪物和卡牌{ko}\n사라진 군단 확장 제외{es}\nMonstruos y Cartas de Lost Legion Eliminados{fr}\nMonstres et Cartes de la Légion Perdue Retirés{pt-br}\nMonstros e Cartas da Legião Perdidão são removidos{de}\nEntfernte Monster und Karten der verlorenen Legion"}) gameReminderHeight=gameReminderHeight+lineFeed
		-- end
		if gStates.removeShadesOfTezlaMonsters==true then
			gameReminderText=joinLang({gameReminderText, "{en}\nShades of Tezla Monsters Removed{ru}\nВраги из «Теней Тезлы» убраны{zh-tw}\n已移除「特茲拉之影」怪物{zh-cn}\n已移除“特兹拉之影”怪物{ko}\n'테즐라의 그림자' 적 토큰 제거{es}\nMonstruos de 'Sombras de Tezla' eliminados{fr}\nMonstres de 'Ombres de Tezla' retirés{pt-br}\nMonstros de 'Sombras de Tezla' removidos{de}\n'Shades of Tezla'-Monster entfernt"})
		else
			gameReminderText=joinLang({gameReminderText, "{en}\nShades of Tezla Monsters Included{ru}\nВраги из «Теней Тезлы» включены{zh-tw}\n使用「特茲拉之影」怪物{zh-cn}\n使用“特兹拉之影”怪物{ko}\n'테즐라의 그림자' 적 토큰 포함{es}\nMonstruos de 'Sombras de Tezla' incluidos{fr}\nMonstres de 'Ombres de Tezla' inclus{pt-br}\nMonstros de 'Sombras de Tezla' incluídos{de}\n'Shades of Tezla'-Monster enthalten"})
		end
		gameReminderHeight=gameReminderHeight+lineFeed
		--else gameReminderText=joinLang({gameReminderText, "{en}\nShades of Tezla Monsters Removed{ru}\nТени Тезлы не включены{zh-tw}\n移除特兹拉之影怪物{zh-cn}\n移除特兹拉之影怪物{ko}\n테즐라의 그림자 확장 포함{es}\nSe han Eliminado las Sombras de los Monstruos de Tezla{fr}\nMonstres Shades of Tezla Supprimés{pt-br}\nMonstros de Sombras de Tezla Removidos{de}\nSchatten von Tezla-Monster entfernt"}) gameReminderHeight=gameReminderHeight+lineFeed end
		if gStates.removeApocalypseTerrain==true then
			gameReminderText=joinLang({gameReminderText, "{en}\nApocalypse Dragon Terrain Removed{ru}\nЛандшафт «Апокалиптический дракон» удалён{zh-tw}\n已移除末日巨龍地形{zh-cn}\n已移除末日巨龙地形{ko}\n아포칼립스 드래곤 지형 제거{es}\nTerreno del Dragón del Apocalipsis eliminado{fr}\nTerrain Apocalypse Dragon supprimé{pt-br}\nTerreno do Dragão do Apocalipse removido{de}\nApocalypse-Dragon-Gelände entfernt"})
		else
			gameReminderText=joinLang({gameReminderText, "{en}\nApocalypse Dragon Terrain Included{ru}\nЛандшафт «Апокалиптический дракон» включён{zh-tw}\n使用末日巨龍地形{zh-cn}\n使用末日巨龙地形{ko}\n아포칼립스 드래곤 지형 포함{es}\nTerreno del Dragón del Apocalipsis incluido{fr}\nTerrain Apocalypse Dragon inclus{pt-br}\nTerreno do Dragão do Apocalipse incluído{de}\nApocalypse-Dragon-Gelände enthalten"})
		end
		gameReminderHeight=gameReminderHeight+lineFeed
		if gStates.removeBonusCards==true then gameReminderText=joinLang({gameReminderText, "{en}\nUltimate Edition Cards Removed{ru}\nПолное издание не включено{zh-tw}\n移除终极版的额外卡牌{zh-cn}\n移除终极版的额外卡牌{ko}\nUE 카드 제외{es}\nTarjetas de Ultimate Edition Eliminadas{fr}\nCartes Ultimate Edition Supprimées{pt-br}\nCartas da Edição Definitiva Removidas{de}\nUltimate Edition Karten entfernt"}) gameReminderHeight=gameReminderHeight+lineFeed else
			gameReminderText=joinLang({gameReminderText, "{en}\nUltimate Edition Cards Included{ru}\nПолное издание включено{zh-tw}\n使用终极版的额外卡牌{zh-cn}\n使用终极版的额外卡牌{ko}\nUE 카드 포함{es}\nTarjetas de Ultimate Edition Incluidas{fr}Cartes Ultimate Edition incluses{pt-br}\nCartas da Edição Definitiva Incluídas{de}\nUltimate Edition Karten enthalten"}) gameReminderHeight=gameReminderHeight+lineFeed end
		if gStates.rampage==1 then gameReminderText=joinLang({gameReminderText, "{en}\nRampage Variant{ru}\nТемные времена!{zh-tw}\n怪物肆虐{zh-cn}\n怪物肆虐{ko}\n광분하라!{es}\nVariante de Rampage{fr}Variante Rampage{pt-br}\nVariante Tempos de Violência{de}\nRampage-Variante"}) gameReminderHeight=gameReminderHeight+lineFeed end
		if gStates.rampage==2 then gameReminderText=joinLang({gameReminderText, "{en}\nMore Rampage Variant{ru}\nТьма сгущается!{zh-tw}\n怪物横行{zh-cn}\n怪物横行{ko}\n더욱더 광분하라!{es}\nMás Variante de Rampage{fr}Plus de variante Rampage{pt-br}\nVariante Mais Violência{de}\nMehr Rampage-Variante"}) gameReminderHeight=gameReminderHeight+lineFeed end
		if gStates.rampageAmbush==true then gameReminderText=joinLang({gameReminderText, "{en}\nAmbushing Rampagers Variant{ru}\nВраги в Засаде{zh-tw}\n怪物伏击{zh-cn}\n怪物伏击{ko}\n매복하는 적{es}\nVariante Emboscada de Rampagers{fr}\nVariante de Rampagers Embusqués{pt-br}\nVariante Irascíveis Emboscadores{de}\nAmbushing Rampagers-Variante"}) gameReminderHeight=gameReminderHeight+lineFeed end
		if gStates.rampagePursuit==true then gameReminderText=joinLang({gameReminderText, "{en}\nPursuing Rampagers Variant{ru}\nПреследующие враги{zh-tw}\n怪物追击{zh-cn}\n怪物追击{ko}\n추적하는 적{es}\nPersiguiendo la Variante de Violentos{fr}\nVariante Poursuite des Rampagers{pt-br}\nVariante Irascíveis Perseguidores{de}\nVerfolgende Rampager-Variante"}) gameReminderHeight=gameReminderHeight+lineFeed end
		--gameReminderText=joinLang({gameReminderText, "\n", gStates.mapShape, "{en} Map{ru} {zh-tw}{zh-cn}{ko} 지도 모양{es} Mapa{fr} Carte{pt-br} Mapa{de} Karte"}) gameReminderHeight=gameReminderHeight+lineFeed
		if gStates.randomTileOrientation==true then gameReminderText=joinLang({gameReminderText, "{en}\nRandom Terrain Tile Orientation Variant{ru}\nСлучайная ориентация Земель{zh-tw}\n随机地图方向{zh-cn}\n随机地图方向{ko}\n타일 방향 무작위로 놓기{es}\nVariante de Orientación de Mosaico de Terreno Aleatorio{fr}\nVariante d'Orientation des Tuiles de Terrain Aléatoire{pt-br}\nVariante Orientação aleatória de Terreno{de}\nVariante mit zufälliger Ausrichtung der Geländekacheln"}) gameReminderHeight=gameReminderHeight+lineFeed end
		if gStates.removeTerrain==true then gameReminderText=joinLang({gameReminderText, "\nRemoved Easier Terrain Tiles"}) gameReminderHeight=gameReminderHeight+lineFeed end
		if gStates.gameScenario~="Life and Death" and gStates.gameScenario~="The Realm of the Dead Blitz" and gStates.gameScenario~="The Hidden Valley Blitz" then
			if gStates.cityTiles-gStates.megapolis>0 then gameReminderText=joinLang({gameReminderText, "\n"..gStates.cityTiles-gStates.megapolis, "{en} City(s){ru} Город(а){zh-tw} 城市{zh-cn} 城市{ko} 도시{es} Ciudad(s){fr} Ville(s){pt-br} Cidade(s){de} Stadt(en)"}) gameReminderHeight=gameReminderHeight+lineFeed end
			if gStates.cityTiles-gStates.megapolis==0 and gStates.megapolis>0 then gameReminderText=joinLang({gameReminderText, "\n"}) gameReminderHeight=gameReminderHeight+lineFeed end
			if gStates.cityTiles-gStates.megapolis>0 and gStates.megapolis>0 then gameReminderText=joinLang({gameReminderText, " & "}) end
			if gStates.megapolis>0 then gameReminderText=joinLang({gameReminderText, gStates.megapolis, "{en} Megapolis{ru} Мегаполис{zh-tw} 大型城市{zh-cn} 大型城市{ko} 거대도시{es} Megapolis{fr} Megapolis{pt-br} Megalópole{de} Megapolis"}) end
		else
			gameReminderText=joinLang({gameReminderText, "{en}\n1 Friendly City(s){ru}\n1 Дружелюбный(х) город(а){zh-tw}\n1 友方势力城市{zh-cn}\n1 友方势力城市{ko}\n1 우호적인 도시{es}\n1 Ciudad(s) Amiga{fr}\n1 Ville(s) Amie{pt-br}\n1 Cidade Amigável{de}\n1 Befreundete Stadt(en)"}) gameReminderHeight=gameReminderHeight+lineFeed
			gameReminderText=joinLang({gameReminderText, "\n"..(gStates.cityTiles-1), "{en} Leader(s){ru} Лидер(ы){zh-tw} 领袖{zh-cn} 领袖{ko} 지도자{es} Líder(s){fr} Leader(s){pt-br} Líder(es){de} Anführer(n)"}) gameReminderHeight=gameReminderHeight+lineFeed
		end
		if gStates.cityTiles>0 and gStates.cityLevels[1]>0 then
			gameReminderText=joinLang({gameReminderText, "{en} at Level(s): {ru} с уровнем(ями): {zh-tw}起始等级：{zh-cn}起始等级：{ko} 의 레벨: {es} en el Nivel(s):{fr} aux Niveaux:{pt-br} no Nível: {de} auf Stufe(n):"})
			for a, b in pairs(gStates.cityLevels) do
				if a==1 and b~=0 then gameReminderText=joinLang({gameReminderText, tostring(b)}) end
				if a~=1 and b~=0 then gameReminderText=joinLang({gameReminderText, ", "..b}) end
			end
			gameReminderHeight=gameReminderHeight+lineFeed
		end
		if gStates.cityLevels[1]==0 and gStates.gameScenario~="The Lost Relic Blitz" then gameReminderText=joinLang({gameReminderText, "{en} Friendly{ru} Дружелюбный(ых){zh-tw} 友方势力{zh-cn} 友方势力{ko} 우호적{es} Simpático{fr} Amical{pt-br} Amigável{de} Freundlich"}) end
		if gStates.cityLevels[1]==0 and gStates.gameScenario=="The Lost Relic Blitz" then gameReminderText=joinLang({gameReminderText, "{en} Destroyed{ru} Уничтоженный(ые){zh-tw} 被摧毁{zh-cn} 被摧毁{ko} 파괴됨{es} Destruido{fr} Détruit{pt-br} Destruído{de}Zerstört"}) end
		if gStates.gameScenario=="Ultimate Conquest" and gStates.removeShadesOfTezlaMonsters~=true then gameReminderText=joinLang({gameReminderText, "{en}\n2 Leaders - Level of last City revealed{ru}\n2 Лидеры - Уровень последнего раскрытого города{zh-tw}\n2 领袖 - 最后揭示的城市等级{zh-cn}\n2 领袖 - 最后揭示的城市等级{ko}\n2 지도자 - 마지막 도시 레벨 공개{es}\n2 líderes - Nivel de la última Ciudad Revelada{fr}\n2 Leaders - Niveau de la Dernière Ville Révélé{pt-br}\n2 Líderes - Nível da última cidade revelada{de}\n2 Anführer - Level der letzten aufgedeckten Stadt"}) gameReminderHeight=gameReminderHeight+lineFeed end
		--need leader and frindly city notes
		if gStates.positionMageKnight[5]=="Volkare" then
			local volkareRaceLevel={"Fair", "Tight", "Thrilling"}
			gameReminderText=joinLang({gameReminderText, "\n", translateWord[volkareRaceLevel[gStates.volkareRaceLevel]], "{en} Volkare Race Level{ru} Уровень гонки Волкара{zh-tw} - 沃卡里竞速等级{zh-cn} - 沃卡里竞速等级{ko} 볼케어 레이스 레벨{es} Nivel de Carrera Volkare{fr} Niveau de Course Volkare{pt-br} Nível de Corrida de Volkare{de} Volkare Ethnie Stufe"}) gameReminderHeight=gameReminderHeight+lineFeed
			local volkareCombatLevel={"Daring", "Heroic", "Legendary"}
			gameReminderText=joinLang({gameReminderText, "\n", translateWord[volkareCombatLevel[gStates.volkareCombatLevel]], "{en} Volkare Combat Level{ru} Уровень битвы Волкара{zh-tw} - 沃卡里战斗等级{zh-cn} - 沃卡里战斗等级{ko} 볼케어 전투 레벨{es} Nivel de Carrera Volkare{fr} Volkare Niveau de Combat{pt-br} Nível de Combate de Volkare{de} Volkare Kampfstufe"}) gameReminderHeight=gameReminderHeight+lineFeed
		end
		if gStates.volkareCampAsCity==true then gameReminderText=joinLang({gameReminderText, "{en}\nVolkare's Camp as a City Variant{ru}\nЛагерь Волкара как возможный город{zh-tw}\n沃卡里军营作为城市{zh-cn}\n沃卡里军营作为城市{ko}\n볼케어 진형을 도시 중 하나로 추가{es}\nEl Campamento de Volkare como Variante de la Ciudad{fr}\nLe camp de Volkare Comme Variante de la Ville{pt-br}\nVariante Acampamento de Volkare como uma Cidade{de}\nVolkare's Camp als Stadtvariante"}) gameReminderHeight=gameReminderHeight+lineFeed end
		if gStates.randomCities==true then gameReminderText=joinLang({gameReminderText, "{en}\nRandom Cities Variant{ru}\nСлучайные города{zh-tw}\n随机城市{zh-cn}\n随机城市{ko}\n무작위의 도시들{es}\nVariante de ciudades Aleatorias{fr}\nVariante de Villes Aléatoires{pt-br}\nVariante Cidades Aleatórias{de}\nZufallsstädte-Variante"}) gameReminderHeight=gameReminderHeight+lineFeed end
		if gStates.startAtNight==true then gameReminderText=joinLang({gameReminderText, "{en}\nStart at Night Variant{ru}\nНочное прибытие{zh-tw}\n黑夜降临{zh-cn}\n黑夜降临{ko}\n야간 도착{es}\nComience en la Variante Nocturna{fr}\nVariante de Démarrage de Nuit{pt-br}\nVariante Início a Noite{de}\nStart bei Nacht Variante"}) gameReminderHeight=gameReminderHeight+lineFeed end
		if gStates.darknessComing==true then
			if gStates.dayRound==true then gameReminderText=joinLang({gameReminderText, "{en}\nDarkness is Comming Variant{ru}\nНадвигается тьма{zh-tw}\n黑夜侵袭{zh-cn}\n黑夜侵袭{ko}\n어둠의 도래{es}\nLa oscuridad se Acerca Variante{fr}\nVariante des Ténèbres à Venir{pt-br}\nVariante Trevas estão Vindo{de}\nDunkelheit kommt Variante"}) gameReminderHeight=gameReminderHeight+lineFeed end
			if gStates.dayRound==false then gameReminderText=joinLang({gameReminderText, "{en}\nDaylight is Comming Variant{ru}\nНадвигается рассвет{zh-tw}\n白昼侵袭{zh-cn}\n白昼侵袭{ko}\n빛의 도래{es}\nLa luz del día está llegando Varian{fr}\nLa Lumière du Jour Arrive Varian{pt-br}\nVariante Luz do dia está vindo{de}\nVariante „Tageslicht kommt"}) gameReminderHeight=gameReminderHeight+lineFeed end
		end
		if gStates.questMod==true then gameReminderText=joinLang({gameReminderText, "{en}\nQuest Cards Variant{ru}\nМод Квест карт{zh-tw}\n自制任务卡{zh-cn}\n自制任务卡{ko}\n퀘스트 카드{es}\nVariante de Cartas de Misión{fr}\nVariante de Cartes de Quête{pt-br}\nVariante Cartas de Missões{de}\nQuest-Karten-Variante"}) gameReminderHeight=gameReminderHeight+lineFeed end
		if gStates.apocalypseQuestCards==true then gameReminderText=joinLang({gameReminderText, "{en}\nApocalypse Dragon Quest Cards{ru}\nApocalypse Dragon Quest Cards{zh-tw}\nApocalypse Dragon Quest Cards{zh-cn}\nApocalypse Dragon Quest Cards{ko}\nApocalypse Dragon Quest Cards{es}\nApocalypse Dragon Quest Cards{fr}\nApocalypse Dragon Quest Cards{pt-br}\nApocalypse Dragon Quest Cards{de}\nApocalypse Dragon Quest Cards"}) gameReminderHeight=gameReminderHeight+lineFeed end
		if gStates.heroChallenges==true then gameReminderText=joinLang({gameReminderText, "{en}\nHero Challenges Variant{ru}\nHero Challenges Variant{zh-tw}\nHero Challenges Variant{zh-cn}\nHero Challenges Variant{ko}\nHero Challenges Variant{es}\nHero Challenges Variant{fr}\nHero Challenges Variant{pt-br}\nHero Challenges Variant{de}\nHero Challenges Variant"}) gameReminderHeight=gameReminderHeight+lineFeed end
		if gStates.proxyPlayer==true then gameReminderText=joinLang({gameReminderText, "{en}\nProxy Player Variant{ru}\nВариант Прокси-игрока{zh-tw}\n代理玩家變體{zh-cn}\n代理玩家变体{ko}\n프록시 플레이어 변형{es}\nVariante Jugador Proxy{fr}\nVariante Joueur Proxy{pt-br}\nVariante Jogador Proxy{de}\nProxy-Spieler-Variante"}) gameReminderHeight=gameReminderHeight+lineFeed end
		if gStates.itemShopMod==true then gameReminderText=joinLang({gameReminderText, "{en}\nItem Shop Cards Variant{ru}\nМод магазина предметов{zh-tw}\n物品商店{zh-cn}\n物品商店{ko}\n아이템 상점 카드{es}\nVariante de las tarjetas de la tienda de artículos{fr}\nVariante des cartes de la boutique d'articles{pt-br}\nVariante de Cartões da Loja de Itens{de}\nArtikel-Shop-Karten-Variante"}) gameReminderHeight=gameReminderHeight+lineFeed end
		if gStates.weatherMod==true then gameReminderText=joinLang({gameReminderText, "{en}\nAtlantean Weather Variant{ru}\nМод Погоды Атлантиды{zh-tw}\n亚特兰蒂斯天气{zh-cn}\n亚特兰蒂斯天气{ko}\n아틀란티스 날씨{es}\nVariante Meteorológica Atlante{fr}\nVariante Météo Atlante{pt-br}\nVariante Clima Atlântico{de}\nAtlantische Wettervariante"}) gameReminderHeight=gameReminderHeight+lineFeed end
		if gStates.riseOfTheForgemasters==1 then gameReminderText=joinLang({gameReminderText, "{en}\nRise of the Forgemaster - 1 New Beginning{ru}\nВосхождение мастера-кузнеца — 1. Новое начало{zh-tw}\n锻造师崛起 - 新的开始{zh-cn}\n锻造师崛起 - 新的开始{ko}\n대장장이의 부상 - 1 새로운 시작{es}\nEl ascenso del maestro forjador - 1 Un nuevo comienzo{fr}\nRise of the Forgemaster - 1 Un nouveau départ{pt-br}\nA Ascensão do Mestre da Forja - 1 Um Novo Começo{de}\nRise of the Forgemaster – 1 Neuanfang"}) gameReminderHeight=gameReminderHeight+lineFeed end
		if gStates.riseOfTheForgemasters==2 then gameReminderText=joinLang({gameReminderText, "{en}\nRise of the Forgemaster - 2 Spoils of War{ru}\nВосхождение мастера-кузнеца — 2. Военные трофеи{zh-tw}\n锻造师崛起 - 战争犒赏{zh-cn}\n锻造师崛起 - 战争犒赏{ko}\n대장장이의 부상 - 2 전리품{es}\nEl ascenso del maestro forjador - 2 El botín de guerra{fr}\nRise of the Forgemaster - 2 Le butin de guerre{pt-br}\nA Ascensão do Mestre da Forja - 2 Despojos de Guerra{de}\nRise of the Forgemaster – 2 Kriegsbeute"}) gameReminderHeight=gameReminderHeight+lineFeed end
		if gStates.riseOfTheForgemasters==3 then gameReminderText=joinLang({gameReminderText, "{en}\nRise of the Forgemaster - 3 Elixir of Life{ru}\nВосхождение мастера-кузнеца — 3. Эликсир жизни{zh-tw}\n锻造师崛起 - ⽣命灵药{zh-cn}\n锻造师崛起 - ⽣命灵药{ko}\n대장장이의 부상 - 3 생명의 엘릭서{es}\nEl ascenso del maestro forjador - 3 El elixir de la vida{fr}\nRise of the Forgemaster - 3 L'élixir de vie{pt-br}\nA Ascensão do Mestre da Forja - 3 Elixir da Vida{de}\nRise of the Forgemaster – 3 Elixier des Lebens"}) gameReminderHeight=gameReminderHeight+lineFeed end
		UI.setAttribute("GameReminderText", "text", gameReminderText)
		UI.setAttribute("GameReminder", "height", gameReminderHeight)
		for _, scenarioFull in pairs(scenarioList) do
			if scenarioFull[1]==gStates.gameScenario then
				local endReminderText=heroChallengeScenarioEndText(scenarioFull.scenarioDetails.scenarioEnd)
				UI.setAttribute("EndReminderText", "text", endReminderText)

				-- Estimate the rendered height from the largest translation rather than
				-- the combined raw translation string. Explicit line feeds are preserved,
				-- and long lines are estimated to wrap at roughly charsPerLine characters.
				local function utf8Length(value)
					local count=0
					for i=1, #value do
						local byte=value:byte(i)
						if byte<128 or byte>=192 then count=count+1 end
					end
					return count
				end

				local function estimateTranslationLines(value, charsPerLine)
					local totalLines=0
					local lineStart=1
					while true do
						local lineEnd=string.find(value, "\n", lineStart, true)
						local line
						if lineEnd~=nil then line=string.sub(value, lineStart, lineEnd-1) else line=string.sub(value, lineStart) end
						local length=utf8Length(line)
						if length==0 then totalLines=totalLines+1 else totalLines=totalLines+math.ceil(length/charsPerLine) end
						if lineEnd==nil then break end
						lineStart=lineEnd+1
					end
					return math.max(totalLines, 1)
				end

				local charsPerLine=106
				local maxLines=1
				local maxLanguage="unknown"
				local translatedText=endReminderText or ""
				local pos=1
				while true do
					local tagStart, tagEnd, language=translatedText:find("{([%a%-]+)}", pos)
					if tagStart==nil then break end
					local nextTagStart=translatedText:find("{([%a%-]+)}", tagEnd+1)
					local translation
					if nextTagStart~=nil then translation=translatedText:sub(tagEnd+1, nextTagStart-1) else translation=translatedText:sub(tagEnd+1) end
					local estimatedLines=estimateTranslationLines(translation, charsPerLine)
					if estimatedLines>maxLines or maxLanguage=="unknown" then
						maxLines=estimatedLines
						maxLanguage=language
					end
					if nextTagStart==nil then break end
					pos=nextTagStart
				end

				local boxSize=math.max(117, (lineFeed*1.43)*maxLines) --30% more vertical room so translated/Hero Challenge text does not shrink excessively
				UI.setAttribute("EndReminder", "height", boxSize)
				break
			end
		end
		local height=0
		if gStates.help==false then
			UI.show("PlayerSeating")
			UI.show("ObjectRotating")
			UI.show("PlayAreaRules")
			UI.show("GameReminder")
			UI.show("EndReminder")
			height=3
			gStates.help=true
		else
			UI.hide("PlayerSeating")
			UI.hide("ObjectRotating")
			UI.hide("PlayAreaRules")
			UI.hide("GameReminder")
			UI.hide("EndReminder")
			height=-2
			gStates.help=false
		end
		local helpNotes={	"0b2a31", "a3d667", --Fame and Reputaion
							playAreaGuideBackground[1], playAreaGuideText[1], --Player Area 1
							playAreaGuideBackground[2], playAreaGuideText[2], --Player Area 2
							playAreaGuideBackground[3], playAreaGuideText[3], --Player Area 3
							playAreaGuideBackground[4], playAreaGuideText[4]} --Player Area 4
		for a, b in pairs(helpNotes) do
			if getObjectFromGUID(b)~=nil then
				getObjectFromGUID(b).setPosition({getObjectFromGUID(b).getPosition()[1], height, getObjectFromGUID(b).getPosition()[3]})
			end
		end
	end
end

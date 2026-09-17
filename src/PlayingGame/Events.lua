-- TTS persistence, raw event handling, maintenance and automatic error-report infrastructure.

function tryObjectEnterContainer(container, object)
    if gStates.preEndTurn==false and container.type=="Card" and object.type=="Card" then
		for _, turnDetails in pairs(turnOrder) do
			if turnDetails.seatPos~=nil then
				for _, c in pairs(getObjectFromGUID(playerPlayAreas[turnDetails.seatPos]).getObjects()) do --players Play Areas
					if c.guid==container.guid or c.guid==object.guid then return false end
				end
				for _, c in pairs(getObjectFromGUID(playerUnitAreas[turnDetails.seatPos]).getObjects()) do --players Unit Areas
					if c.guid==container.guid or c.guid==object.guid then return false end
				end
			end
		end
	end
    return true -- Allows object to enter.
end

-- Event Handling functions
---------------
--Save and load settings
function __onLoad_raw(saved_data)
	cacheScenarioTweakDefaults()
	local megaFreeze=  {"3d4319", "519f96",	playerBoard[1], playerBoard[2], playerBoard[3], playerBoard[4], dummyBoard, "a02b0f"}--player mats
	for i=1, #megaFreeze, 1 do
		local obj=getObjectFromGUID(megaFreeze[i])
		if obj~=nil then obj.interactable=false end --some boards may be missing depending on their states
	end
	--fix hand positions
	for _, seat in pairs(Player.getAvailableColors()) do
		Player[seat].setHandTransform({position={Player[seat].getHandTransform().position[1], 3.1, -48.4}, scale={18, 3.8, 1}}, 1)
	end
	--load saved data
	if saved_data~="" then
		local loaded_data=JSON.decode(saved_data)
		turnOrder=loaded_data.turnOrder
		gStates=loaded_data.gStates
	end
	--Quest scoring was previously inseparable from Apocalypse Quest Cards. Old in-progress saves keep it enabled.
	if type(gStates.apocalypseQuestScoringDisabled)~="boolean" then gStates.apocalypseQuestScoringDisabled=false end
	if type(gStates.apocalypseQuestScoringChoiceLocked)~="boolean" then gStates.apocalypseQuestScoringChoiceLocked=gStates.firstStarted==true end
	if apocalypseQuestScoresRequired()==true then gStates.apocalypseQuestScoringDisabled=false end
	--Older Quest saves predate the permanent Quest-area scripting zone. Create it once after load so
	--all subsequent offer/card scans use the small local object set instead of getAllObjects().
	safeWaitFrames("Events",function() if apocalypseQuestsUsed()==true then apocalypseQuestAreaZone() end end,1)
	--Follow Enemy is a global Camera Control option, enabled by default. Migrate the earlier per-player table state.
	if type(gStates.cameraFollowEnemy)~="boolean" then gStates.cameraFollowEnemy=true end
	--Hero Challenge reservations used to be keyed by turnOrder index, but turnOrder is re-sorted during play.
	--Rebuild them from each Hero's prescribed Skill GUID so old saves cannot hand one Hero another Hero's Skill.
	if gStates.heroChallenges==true then
		local stableHeroChallengeSkills={}
		for _,details in pairs(turnOrder or {}) do
			local challenge=heroChallengesData[details.mage]
			if challenge~=nil and getObjectFromGUID(challenge.skillGUID)~=nil then stableHeroChallengeSkills[details.mage]=challenge.skillGUID end
		end
		gStates.heroChallengeReservedSkills=stableHeroChallengeSkills
	elseif type(gStates.heroChallengeReservedSkills)~="table" then gStates.heroChallengeReservedSkills={} end
	--Fractured Lands always uses Blitz rules. Migrate saves made before its internal scenario name carried the Blitz suffix.
	if gStates.gameScenario=="The Fractured Lands" then gStates.gameScenario="The Fractured Lands Blitz" gStates.blitz=1 end
	if gStates.competitiveSkillReminders==nil then gStates.competitiveSkillReminders={} end
	if gStates.coopCompSkillActivation==nil then gStates.coopCompSkillActivation={} end
	if gStates.tomeSkillSwapPending==nil then gStates.tomeSkillSwapPending={} end
	if type(gStates.puppetMasterPuppets)~="table" then gStates.puppetMasterPuppets={} end
	--Refresh saved Puppets so presentation changes (decal/hover data) also apply to existing accepted Puppets.
	safeWaitFrames("Events",function() for guid,record in pairs(gStates.puppetMasterPuppets) do puppetMasterRefreshPresentation(getObjectFromGUID(guid),record) end end,2)
	--Goblin Warrens enemies come from an Infinite Bag and therefore receive new GUIDs. Restore their
	--runtime monster registration before a saved mid-combat game can inspect or clean them up.
	safeWaitFrames("Events",function() apocalypseQuestRestoreGoblinEnemies() end,2)
	--Proxy Heroes are normal movable figures between automated moves; migrate older saves that left them locked.
	safeWaitFrames("Events",function()
		if proxyPlayerActive()==true then local avatar=proxyAvatarObject() if avatar~=nil then avatar.unlock() end end
	end,2)
	--Restore any saved live Proxy choice, including terrain, offer-card, enemy, and Source-mana controls.
	safeWaitFrames("Events",function() proxyRestorePendingChoiceUI() end,4)
	local legacyMineLocation={["mine red"]=true,["mine green"]=true,["mine blue"]=true,["mine white"]=true}
	for _, details in pairs(turnOrder or {}) do if legacyMineLocation[details.avatarLocation]==true then details.avatarLocation="mine" end end
	safeWaitFrames("Events",function() refreshMineClaimPanel() end, 1)
	--Reapply explicit ALT zoom directions to any City/avatar objects already out on the table.
	safeWaitFrames("Events",function() refreshAltViewAngles() end, 2)
	--Remove TTS's multi-digit typing delay from existing player Deed Decks after load.
	safeWaitFrames("Events",function() for seatPos, _ in pairs(deedDeckZones) do setDeedDeckImmediateNumberTyping(seatPos) end end, 1)
	if gStates.finalTurnReason~=nil then ensureFinalTurnBoundary() end
	safeWaitFrames("Events",function() againstHorsemenRestoreRuntimeState() end,2)
	startMaintenanceTick()
	--Updated already saved variable by putting a copy here, delete after saving one time.

	-----------
	UI.setAttribute("sendBugReportButtonRealText", "text", "{en}Feedback{ru}Обратная связь{zh-tw}回饋意見{zh-cn}反馈{ko}피드백{es}Realimentación{fr}Retour{pt-br}Comentários{de}Feedback")
	UI.setAttribute("AutoFlipButtonRealText", "text", "{en}Auto Flip{ru}Авто-переворот{zh-cn}自动翻转{ko}자동 공개{es}Volteo Automático{fr}Retournement auto{pt-br}Auto-Virar{de}Auto-Flip")
	UI.setAttribute("helpButtonRealText", "text", "{en}Setup{ru}Настройки{zh-cn}设  置{ko}설정{es}Preparación{fr}Préparation{pt-br}Preparação{de}Einrichtung")
	UI.setAttribute("ScoreButtonRealText", "text", "{en}Score{ru}Результат{zh-cn}得  分{ko}점수{es}Puntuación{fr}Score{pt-br}Pontuação{de}Ergebnis")
	UI.setAttribute("TableButtonRealText", "text", "{en}Switch Table{ru}Дизайн стола{zh-cn}开关表{ko}테이블 전환{es}Cambiar Mesa{fr}Table de commutation{pt-br}Mudar de mesa{de}Tabelle wechseln")
	UI.setAttribute("MonsterButtonRealText", "text", "{en}Switch Enemy{ru}Дизайн врагов{zh-cn}切换敌人{ko}적 토큰 전환{es}Cambiar Enemigo{fr}Changement d'ennemi{pt-br}Trocar o inimigo{de}Feind wechseln")
	UI.setAttribute("drawOneCardText", "text", "{en}Draw One Card{ru}Вытянуть одну карту{zh-tw}抽一張牌{zh-cn}抽一张牌{ko}카드 1장 뽑기{es}Roba Una Carta{fr}Prendre Une Carte{pt-br}Compre Uma Carta{de}Ziehe eine Karte")
	UI.setAttribute("EndTurnButtonAltText", "text", "{en}End Turn{ru}Конец хода{zh-tw}結束回合{zh-cn}结束回合{ko}차례 종료{es}Fin de Turno{fr}Fin de Tour{pt-br}Fim de Turno{de}Zug Beenden")
	UI.setAttribute("resourceTrackerText", "text", "{en}Resource Tracker{ru}Трекер Ресурсов{zh-tw}資源追蹤器{zh-cn}资源追踪器{ko}자원 추적표{es}Rastreador de Recursos{fr}Suivi des Ressources{pt-br}Rastreador de Recursos{de}Ressourcen-Tracker")
	refreshResourceTrackerText()--Refresh the tracker from saved values so TTS resolves its language tags on load.
	UI.setAttribute("GameReminderTitleText", "text", "{en}Scenario Info{ru}Информация о сценарии{zh-cn}剧本信息{ko}시나리오 정보{es}Información del escenario{fr}Informations sur le scénario{pt-br}Informação do cenário{de}Szenario-Infos")
    UI.setAttribute("EndReminderTitleText", "text", "{en}Scenario Ends{ru}Конец Cценария{zh-tw}劇本結束條件{zh-cn}剧本结束条件{ko}시나리오 종료{es}Fin del Escenario{fr}Fin du Scénario{pt-br}Fim do Cenário{de}Szenario Endet")
    UI.setAttribute("PlayerSeatingText1", "text", "{en}This mod runs it own Turn System, which makes 'Hot Seat' unnecessary.<size=6>\n\n</size>To switch to another Mage Knight Click the name to the right and <b>'Change Color'</b>. For Multi Hand play you should choose the <b>Black Game Master Color</b> in the Center.<size=6>\n\n</size><b>Cooperative</b> Players should also choose the same team to see each others hands.{ru}Этот мод использует собственную Систему Ходов, что делает «Hot seat» ненужным.<size=6>\n\n</size>Чтобы переключиться на другого героя, щелкните имя в правом верхем углу экрана и <b>«Изменить цвет»</b>. Для игры сразу несколькими героями вам следует выбрать <b>«Черный Game Master»</b> в центре.<size=6>\n\n</size><b>Кооперативные</b> Игроки также должны выбрать одну и ту же команду, чтобы видеть руки друг друга.{zh-cn}这个模组使用它自己的回合系统，\n所以你无需使用“热座”模式。<size=6>\n\n</size>切换到另一个魔法骑士点击右边\n的名字和<b>'改变颜色'。</b> 对于多人游\n戏，您应该在版图中间选<b>黑色。</b><size=6>\n\n</size><b>合作模式</b> 玩家们应该选择同一\n支队伍以便看队友的手牌。{ko}이 모드는 자체 턴 시스템을 실행하므로 '핫 시트'를 따로 필요로 하지 않습니다.<size=6>\n\n</size>다른 자리로 바꾸려면 우측 상단의 이름을 클릭하고 <b> '색상 변경'</b>을 클릭하세요. 다중 핸드로 플레이할 경우 중앙에서 <b> 검정(게임 마스터 색상) </b>을 선택하세요.<size=6>\n\n</size><b> 협동 임무</b>  플레이시, 같은 팀을 선택해야 서로의 핸드를 볼 수 있습니다. {es}Este mod lleva su propio sistema de turnos, lo que hace que el 'Hot Seat' sea innecesario.<size=6>\n\n</size>Para cambiar a otro Mage Knight pulsa el nombre a la derecha y <b>'Change Color'</b>. Para jugar con múltiples magos deberías escoger el <b>Black Game Master Color</b> en el centro.<size=6>\n\n</size><b>Cooperativo</b> Los jugadores deberían elegir el mismo equipo para poder verse las manos.{fr}Ce mod exécute son propre système de virage, ce qui rend inutile le « siège chaud ».<size=6>\n\n</size>Pour passer à un autre Mage Cliquez sur le nom à droite et <b>'Changer de couleur'</b>. Pour le jeu à plusieurs mains, vous devez choisir la <b>Couleur Black Game Master</b> au centre.<size=6>\n\n</size><b>Coopératif</b> Les joueurs doivent également choisir la même équipe pour se voir les mains.{pt-br}Este Mod usa seu próprio sistema de turnos, o que faz 'Hot sear' desnecessário.<size=6>\n\n</size>Para mudar para outro Mage Knight clique o nome a direita e <b>'Mudar Cor'</b>. Para jogar com multi jogadores escolha a <b>Cor Negra de Mestre de jogo</b> no Centro.<size=6>\n\n</size><b>Cooperativo</b> Jogadores deveriam também escolher o mesmo time para ver a mão um do outro.{de}Dieser Mod verfügt über ein eigenes Turn-System, das den „Hot Seat“ überflüssig macht.<size=6>\n\n</size>To switch to another Mage Knight Click the name to the right and <b>'Change Color'</b>. For Multi Hand play you should choose the <b>Black Game Master Color</b> in the Center.<size=6>\n\n</size><b>Kooperativ</b> Die Spieler sollten auch das gleiche Team wählen, um die Hände der anderen zu sehen.")
    UI.setAttribute("MegapolisReminderTitle", "text", "{en}Megapolis Available{ru}Мегаполис Доступен{zh-tw}可以使用大型城市{zh-cn}可以使用大型城市{ko}거대도시 옵션{es}Megapolis Disponible{fr}Megapolis Disponible{pt-br}Megalópole Disponível{de}Metropole Vorhanden")
	UI.setAttribute("MegapolisReminderText1", "text", "{en}Use the arrows next to the City Levels, to change a City into a Megapolis.<size=6>\n\n</size>When a city deploys in game, a second random city also deploys with it (each at half the level chosen here). Their two garrisons combine and get the bonuses from both cities applied.<size=6>\n\n</size>After conquering the Megapolis, interactions from either city can be accessed.{ru}Используйте стрелки рядом с ур. города, чтобы из Города сделать Мегаполис.<size=6>\n\n</size>Вместо одного Города, появятся сразу два. Уровень каждого равен половине ур. выбранного здесь. Оба их гарнизона объединяются и получают бонусы от обоих городов.<size=6>\n\n</size>Завоеванный Мегаполис позволяет взаимодействовать с каждым из городов.{zh-tw}使用城市等級選項旁邊的箭頭按鈕，\n來將一個城市更換成大型城市。<size=3>\n\n</size>當一個城市在遊戲中部署時，\n會跟著部屬另一個隨機城市在它旁邊。\n（每座城市的等級為選項中的一半。）\n兩座城市的守軍會合併，全部具有城防，\n並同時受到兩座城市的戰鬥加成。<size=3>\n\n</size>征服大型城市後，無論位於哪片城區，\n在交涉時都可以選擇任意城區的購買選項。{zh-cn}使用城市等级选项旁边的箭头按钮，\n来将一个城市更换成大型城市。<size=3>\n\n</size>当一个城市在游戏中部署时，\n会跟着部属另一个随机城市在它旁边。\n（每座城市的等级为选项中的一半。）\n两座城市的守军会合并，全部具有城防，\n并同时受到两座城市的战斗加成。<size=3>\n\n</size>征服大型城市后，无论位于哪片城区，\n在交涉时都可以选择任意城区的购买选项。{ko}거대도시를 사용하려면, 도시 레벨 옆 화살표를 누르세요.<size=6>\n\n</size>도시가 놓일 때, 두 번째 도시가 무작위로 선택되어 좌측에 같이 놓입니다.(각각 절반의 레벨)두 도시의 수비대가 합쳐지고 두 도시의 전투 보너스를 동시에 적용받습니다.<size=6>\n\n</size>정복된 후, 플레이어는 도시 어느 부분에 있던지 두 도시의 모든 교류 혜택을 사용할 수 있습니다.{es}Usa las flechas al lado de los niveles de la ciudad para convertir una ciudad en una Megapolis.<size=6>\n\n</size>Cuando una ciudad se despliega en el juego, también se despliega una segunda ciudad aleatoria con ella (cada una a la mitad del nivel elegido aquí). Sus dos guarniciones se combinan y se aplican las bonificaciones de ambas ciudades.<size=6>\n\n</size>Después de conquistar la Megalópolis, se puede acceder a las interacciones de cualquiera de las ciudades.{fr}Utilisez les flèches à côté des niveaux de la ville pour transformer une ville en Mégapole.<size=6>\n\n</size>Lorsqu'une ville se déploie en jeu, une seconde ville aléatoire se déploie également avec elle (chacune à la moitié du niveau choisi ici). Leurs deux garnisons se combinent et obtiennent les bonus des deux villes appliqués.<size=6>\n\n</size>Après avoir conquis la Mégapole, les interactions de l'une ou l'autre ville sont accessibles.{pt-br}Use as setas próximas ao níveis da Cidade, para transformar uma Cidade em uma Megalópole.<size=6>\n\n</size>Quando uma cidade é implementada no jogo, uma segunda cidade aleatória também é implementada com ela (cada uma a metade do nível escolhido aqui). Suas duas Guarnições combinam e ganham os bônus de ambas as cidades.<size=6>\n\n</size>Depois de conquistar a Megalópolis, interações de ambras cidades podem ser acessadas.{de}Verwenden Sie die Pfeile neben den Stadtebenen, um eine Stadt in eine Metropole zu verwandeln.<size=6>\n\n</size>Wenn eine Stadt im Spiel aufgestellt wird, wird auch eine zweite zufällige Stadt aufgestellt (jeweils auf der Hälfte des hier gewählten Levels). Ihre beiden Garnisonen verbinden sich und bekommen die Boni aus beiden Städten zugerechnet.<size=6>\n\n</size>Nach der Eroberung der Metropole kann auf Interaktionen aus beiden Städten zugegriffen werden.")
    UI.setAttribute("ObjectRotatingText", "text", "{en}<b>30deg</b> Rotation will allow everthing to align properly.{ru}Поворот на <b>30 градусов</b> позволит всему работать правильно.{zh-cn}<b>30 度</b> 旋转将使所有东西正确对齐。{ko}편리한 정렬을 위해 <b> 30도 </b> 회전 세팅을 추천합니다.{es}La rotación de <b> 30 grados </b> permitirá que todo se alinee correctamente.{fr}<b>30 deg</b> La rotation permettra à tout de s'aligner correctement.{pt-br}Rotação de <b>30deg</b> permitirá que tudo se alinhe adequadamente.{de}Eine <b>30 Grad</b> Drehung ermöglicht es, alles richtig auszurichten.")
	UI.setAttribute("ScoreBoardTableTitleText1", "text", "{en}Mage Knight Current Score{ru}Текущий счет{zh-cn}魔法骑士当前得分{ko}현재 점수{es}Puntuación Actual de Mage Knight{fr}Mage Knight Score Actuel{pt-br}Pontuação atual do Mage Knight{de}Mage Knight Aktueller Spielstand")
	UI.setAttribute("ScoreBoardTableTitleText2", "text", "{en}Scores are calculated as if the game has been completed{ru}Очки подсчитываются так, как будто игра уже завершена{zh-cn}此分数视为游戏结束而统计{ko}점수는 게임이 종료된 것으로 간주하여 계산합니다{es}Las puntuaciones se calculan como si el juego se ubiera completado.{fr}Les scores sont calculés comme si le jeu était terminé{pt-br}Pontuação é calculada como se o jogo tivesse sido completado{de}Der Punktestand wird so berechnet, als ob das Spiel abgeschlossen wäre.")
	UI.setAttribute("QuestScoreHeadingText", "text", "{en}Quests{ru}Quests{zh-tw}Quests{zh-cn}Quests{ko}Quests{es}Quests{fr}Quests{pt-br}Quests{de}Quests")
	UI.setAttribute("ReputationScoreHeadingText", "text", "{en}Reputation{ru}Reputation{zh-tw}Reputation{zh-cn}Reputation{ko}Reputation{es}Reputation{fr}Reputation{pt-br}Reputation{de}Reputation")
	UI.setAttribute("KnowledgeScoreHeadingText", "text", "{en}Knowledge{ru}Мудрец{zh-cn}博古通今{ko}지식{es}Conocimiento{fr}Connaissances{pt-br}Conhecimento{de}Wissen")
	UI.setAttribute("LootScoreHeadingText", "text", "{en}Loot{ru}Добыча{zh-cn}富可敌国{ko}전리품{es}Botín{fr}Butin{pt-br}Saque{de}Beute")
	UI.setAttribute("LeaderScoreHeadingText", "text", "{en}Leader{ru}Лидер{zh-cn}至高领袖{ko}지도자{es}Líder{fr}Chef{pt-br}Líder{de}Anführer")
	UI.setAttribute("ConquerorScoreHeadingText", "text", "{en}Conqueror{ru}Завоеватель{zh-cn}战无不胜{ko}정복자{es}Conquistador{fr}Conquérant{pt-br}Conquistador{de}Eroberer")
	UI.setAttribute("AdventurerScoreHeadingText", "text", "{en}Adventurer{ru}Искатель приключений{zh-cn}披荆斩棘{ko}모험가{es}Aventurero{fr}Aventurier{pt-br}Aventureiro{de}Abenteurer")
	UI.setAttribute("LiberatorScoreHeadingText", "text", "{en}Liberator{ru}Исследователь подземелий{zh-cn}解放邻邦{ko}해방자{es}Libertador{fr}Libérateur{pt-br}Libertador{de}Befreier")
	UI.setAttribute("BeatingScoreHeadingText", "text", "{en}Beating{ru}Поражение{zh-cn}满身疮痍{ko}패배자{es}Golpeando{fr}Battement{pt-br}Espancamento{de}Schlagen")
	UI.setAttribute("RelicScoreHeadingText", "text", "{en}Relic Hunter{ru}Охотник за древностями{zh-cn}圣器猎者{ko}유물 사냥꾼{es}Cazador de Reliquias{fr}Chasseur de Reliques{pt-br}Caçador de Relíquia{de}Reliquienjäger")
	UI.setAttribute("RewardScoreHeadingText", "text", "{en}Faction Rewards{ru}Награды фракций{zh-cn}派系奖励{ko}세력 보상{es}Recompensas de Facción{fr}Récompenses de Faction{pt-br}Recompensa de Facção{de}Fraktionsbelohnungen")
	UI.setAttribute("CityScoreHeadingText", "text", "{en}Conquered Cities{ru}Захваченный город{zh-cn}被征服的城市{ko}정복한 도시{es}Ciudades Conquistadas{fr}Villes Conquises{pt-br}Cidades Conquistadas{de}Eroberte Städte")
	UI.setAttribute("TezlaScoreHeadingText", "text", "{en}Faction Greatest Enemy{ru}Величайший враг фракций{zh-cn}派系的至高敌人{ko}세력의 위대한 적{es}El Mayor Enemigo de la Facción{fr}Le Plus Grand Ennemi de la Faction{pt-br}Maior Inimigo da Facção{de}Größter Feind der Fraktion")
	UI.setAttribute("VolkareScoreHeadingText", "text", "{en}General Volkare{ru}Генерал Волкар{zh-cn}沃卡里将军{ko}볼케어 장군{es}General Volkare{fr}Général Volkare{pt-br}General Volkare{de}General Volkare")
	UI.setAttribute("EfficiencyScoreHeadingText", "text", "{en}Efficiency{ru}Эффектиность{zh-cn}效率{ko}효율 점수{es}Eficiencia{fr}Efficacité{pt-br}Eficiência{de}Effizienz")
	UI.setAttribute("TotalScoreText", "text", "{en}Total{ru}Итого{zh-cn}合计{ko}총합{es}Total{fr}Le Total{pt-br}Total{de}Gesamt")
	UI.setAttribute("EndGameButtonText", "text", "{en}Scenario End Achieved - No{ru}Конец сценария достигнут - Нет{zh-cn}声明结束剧本-否{ko}시나리오 종료 조건 충족 전{es}Escenario Fin Realizados - No{fr}Scénario Fin Atteint - Non{pt-br}Fim do Cenário Alcançado - Não{de}Szenarioziel Erreicht – Nein")
	UI.setAttribute("OutOfTurnActionsTitle", "text", "{en}Optional Actions{ru}Дополнительные действия{zh-tw}可選操作{zh-cn}可选操作{ko}추가 행동{es}Acciones Opcionales{fr}Actions Facultatives{pt-br}Ações Opcionais{de}Optionale Aktionen")
	UI.setAttribute("CoopAssaultMainTableText1", "text", "{en}Combined Assault Possible{ru}Доступен Совместный штурм города{zh-tw}可以進行合作突襲{zh-cn}可以进行合作突袭{ko}협력 강습 가능{es}Asalto Combinado Posible{fr}Assaut Combiné Possible{pt-br}Ataque Combinado Possível{de}Gemeinsamer Angriff möglich")
	UI.setAttribute("CoopAssaultMainTableText2", "text", "{en}Nearby Mage Knights can choose to join this assault by skipping their next turn. This tool randomly gives the amount of defenders chosen to each player. (Remember to pay movement costs){ru}Герои, находящиеся на соседней с городом клетке, могут присоединиться к штурму. Этот инструмент случайным образом выдаст каждому игроку защитников согласно выбранному количеству, а также перевернет их Жетоны Порядка хода лицом вниз.{zh-tw}附近的魔法騎士可以選擇加入突襲。\n此工具會依據數量隨機分配敵人給每位參與者，\n同時也會將這些玩家的輪次順位標記翻面。\n{zh-cn}附近的魔法骑士可以选择加入突袭。 \n此工具会依据数量随机分配敌人给每位参与者，\n同时也会将这些玩家的轮次顺位标记翻面。 \n{ko}근처의 메이지 나이트들은 이 강습에 참여할 수 있습니다. 이 툴은 참여한 각 플레이어에게 무작위로 선택된 수비자 토큰을 배분합니다. 그리고 라운드 순서 토큰을 뒤집습니다.{es}Los caballeros magos cercanos pueden elegir unirse al asalto. Esta herramienta da al azar la cantidad de defensores elegidos para cada jugador, mientras que también coloca boca abajo su Ficha de Orden de Turno.{fr}Les chevaliers mages à proximité peuvent choisir de se joindre à l'assaut. Cet outil donne au hasard le nombre de défenseurs choisis à chaque joueur, tout en retournant son jeton d'ordre du tour face cachée.{pt-br}Os Mage Knights próximos podem escolher se juntar ao ataque. Esta ferramenta fornece aleatoriamente a quantidade de defensores escolhidos para cada jogador, ao mesmo tempo que vira a ficha de ordem do turno para baixo.{de}Mage Knights in der Nähe können sich dem Angriff anschließen. Mit diesem Werkzeug erhält jeder Spieler zufällig die gewählte Anzahl an Verteidigern und dreht gleichzeitig sein Zugreihenfolgeplättchen um.")
	UI.setAttribute("CoopAssaultMainTableText3", "active", "false")
	UI.setAttribute("startAssaultText", "text", "{en}Begin Assault{ru}Начать штурм{zh-tw}開始突襲{zh-cn}开始突袭{ko}강습 시작{es}Empezar Asalto{fr}Commencer l'Assaut{pt-br}Comece o Assalto{de}Angriff Starten")
	UI.setAttribute("WallAssaultChoiceTitle", "text", "{en}Wall Fortification{ru}Укрепление стеной{zh-cn}城墙防御{ko}성벽 요새화{es}Fortificación de Muralla{fr}Fortification du mur{pt-br}Fortificação de Muralha{de}Mauerbefestigung")
	UI.setAttribute("WallAssaultChoiceQuestion", "text", "{en}The assault approach is unclear.\nDid your assault cross a wall?{ru}Направление штурма неясно.\nВаш штурм проходил через стену?{zh-tw}突襲的進入方向不明確。\n你的突襲是否穿過城牆？{zh-cn}突袭的进入方向不明确。\n你的突袭是否穿过城墙？{ko}강습 진입 방향이 불분명합니다.\n강습 중 성벽을 넘었습니까?{es}La dirección del asalto no está clara.\n¿Tu asalto cruzó una muralla?{fr}La direction de l'assaut n'est pas claire.\nVotre assaut a-t-il franchi un mur ?{pt-br}A direção do ataque não está clara.\nSeu ataque atravessou uma muralha?{de}Die Angriffsrichtung ist unklar.\nHat dein Angriff eine Mauer überquert?")
	UI.setAttribute("WallAssaultChoiceYesText", "text", "{en}Crossed Wall{ru}Через стену{zh-cn}穿过城墙{ko}성벽 통과{es}Cruzó Muralla{fr}Mur franchi{pt-br}Atravessou Muralha{de}Über Mauer")
	UI.setAttribute("WallAssaultChoiceNoText", "text", "{en}Open Side{ru}Без стены{zh-cn}无墙一侧{ko}열린 쪽{es}Lado abierto{fr}Côté ouvert{pt-br}Lado aberto{de}Offene Seite")
	--The wall assault interface is only shown when the assault entry side cannot be determined automatically.
	UI.hide("WallAssaultChoice")
	UI.hide("ExtraTurnChoice")
	UI.setAttribute("ExtraTurnChoiceTitle", "text", "{en}Extra Turn{ru}Дополнительный ход{zh-tw}額外回合{zh-cn}额外回合{ko}추가 턴{es}Turno Extra{fr}Tour Supplémentaire{pt-br}Turno Extra{de}Extra-Zug")
	UI.setAttribute("ExtraTurnChoiceQuestion", "text", "{en}Which effect gives the extra turn?{ru}Какой эффект даёт дополнительный ход?{zh-tw}哪個效果提供額外回合？{zh-cn}哪个效果提供额外回合？{ko}어떤 효과로 추가 턴을 받습니까?{es}¿Qué efecto concede el turno extra?{fr}Quel effet accorde le tour supplémentaire ?{pt-br}Qual efeito concede o turno extra?{de}Welcher Effekt gewährt den Extra-Zug?")
	UI.setAttribute("ExtraTurnChoiceTimeBendingText", "text", "{en}Time Bending{ru}Изгиб Времени{zh-tw}時間扭曲{zh-cn}时间扭曲{ko}시간 왜곡{es}Salto en el Tiempo{fr}Courbe du Temps{pt-br}Dobrar Tempo{de}Zeitkrümmung")
	UI.setAttribute("ExtraTurnChoiceTactic6Text", "text", "{en}Day Tactic 6{ru}Дневная Тактика 6{zh-tw}白天戰術卡 6{zh-cn}白天战术卡 6{ko}낮 전략 6{es}Táctica de Día 6{fr}Tactique de Jour 6{pt-br}Tática do Dia 6{de}Tagestaktik 6")
	UI.setAttribute("SendScoreRequestText1", "text", "{en}Record Your Score{ru}Записать свой результат{zh-tw}記錄你的分數{zh-cn}记录你的分数{ko}점수 기록{es}Registre su puntaje{fr}Enregistrez votre score{pt-br}Grave Sua Pontuação{de}Punktzahl Aufzeichnen")
	UI.setAttribute("SendScoreRequestText2", "text", "{en}Would you like to record this games score(s) on the Public List? (Find a link to it on the Mod's Workshop Page)<size=6>\n\n</size>The list contains the game setups and scores of other players across the world. You can see how well you did compared to others. See what the average score is for a scenario. Try to beat your existing score.<size=6>\n\n</size>Optionally type something to help you find your entry in the list. Ie 'Volkare killed by epic fireball attack'{ru}Хотите ли вы записать результаты этой игры в публичный список? (Ссылку на него можно найти на странице мастерской мода)<size=6>\n\n</size>Список содержит настройки игры и результаты других игроков по всему миру. Вы можете увидеть, насколько хорошо вы справились по сравнению с другими. Увидеть, какой средний результат за сценарий. Попробуйте превзойти свой текущий результат!<size=6>\n\n</size>При желании, можно написать что-нибудь, что поможет вам найти вашу запись в списке. Например, «Волкар был убит эпической атакой огненного шара».{zh-tw}你想要將你的分數紀錄在公開的清單嗎？\n(可以在此mod的頁面看到這個連結)<size=6>\n\n</size>清單中會有世界各地玩家的遊戲設置與分數。\n你可以跟其它人比較你的成績如何。\n看看劇本的平均分數是多少。\n試著超越你原有的分數。<size=6>\n\n</size>你可以隨意輸入些什麼來幫助你從列表中找\n到你的項目，例如沃卡里被史詩級火球擊殺。{zh-cn}你想要将你的分数纪录在公开的列表吗？\n(可以在此mod的页面看到这个链接)<size=6>\n\n</size>列表中会有世界各地玩家的游戏设置与分数。\n你可以跟其它人比较你的成绩如何。\n看看剧本的平均分数是多少。\n试着超越你原有的分数。<size=6>\n\n</size>你可以随意输入些什么来帮助你从列表中找\n到你的项目，例如沃卡里被史诗级火球击杀。{ko}공개 리스트에 점수를 기록할까요? (스팀 워크샵에 링크가 있습니다)<size=6>\n\n</size>공개 리스트는 전세계의 플레이어들의 점수를 기록합니다. 평균 점수를 확인하고 비교해보세요. 그리고 기존 기록을 갱신해보세요.<size=6>\n\n</size>리스트에서 쉽게 찾으려면, '정의의 검으로 볼케어 뚝배기를 깼다'와 같은 특별한 메모를 하셔도 됩니다.{es}¿Le gustaría registrar la (s) puntuación (s) de este juego en la lista pública? (Encuentre un enlace en la página de taller del Mod)<size=6>\n\n</size>La lista contiene las configuraciones del juego y las puntuaciones de otros jugadores de todo el mundo. Puede ver lo bien que lo hizo en comparación con los demás. Vea cuál es la puntuación media de un escenario. Intenta superar tu puntuación actual.<size=6>\n\n</size>Opcionalmente, escriba algo que le ayude a encontrar su entrada en la lista. Es decir, 'Volkare asesinado por un épico ataque con bola de fuego'{fr}Souhaitez-vous enregistrer le(s) score(s) de ce jeu sur la liste publique ? (Trouvez un lien vers celui-ci sur la page de l'atelier du mod)<size=6>\n\n</size>La liste contient les configurations de jeu et les scores des autres joueurs à travers le monde. Vous pouvez voir à quel point vous avez réussi par rapport aux autres. Voyez quel est le score moyen pour un scénario. Essayez de battre votre score existant.<size=6>\n\n</size>Tapez éventuellement quelque chose pour vous aider à trouver votre entrée dans la liste. C'est-à-dire 'Volkare tué par une attaque épique de boule de feu'{pt-br}Você gostaria de gravar a pontuação destes jogos numa lista pública? (Encontre um link para ele na página da Oficina do Mod)<size=6>\n\n</size>A lista contém as configurações dos jogos e pontuações dos jogadores ao redor do mundo. Você pode ver o quão bem você foi comparado aos outros. Veja qual a pontuação média de um cenário. Tente derrotar sua pontuação existente.<size=6>\n\n</size>Opcionalmente digite algo para ajudar você a encontrar sua entrada na lista. Ex. 'Volkare morto por ataque épico de Bola de fogo'{de}Möchten Sie diese Spielergebnisse in die öffentliche Liste aufnehmen? (Einen Link dazu finden Sie auf der Workshop-Seite des Mods)<size=6>\n\n</size>Die Liste enthält die Spielaufbauten und Punktzahlen anderer Spieler auf der ganzen Welt. Sie können sehen, wie gut Sie im Vergleich zu anderen abgeschnitten haben. Sehen Sie, was die durchschnittliche Punktzahl für ein Szenario ist. Versuchen Sie, Ihre vorhandene Punktzahl zu schlagen.<size=6>\n\n</size>Geben Sie optional etwas ein, das Ihnen hilft, Ihren Eintrag in der Liste zu finden. Dh 'Volkare durch epischen Feuerballangriff getötet'")
	UI.setAttribute("SendScoreRequestYesText", "text", "{en}Send Score{ru}Отправить Результат{zh-tw}上傳分數{zh-cn}上传分数{ko}점수 입력{es}Enviar puntuación{fr}Envoyer la note{pt-br}Enviar pontuação{de}Punkte Eintragen")
	UI.setAttribute("SendScoreRequestNoText", "text", "{en}No Thanks{ru}Нет, спасибо{zh-tw}不了謝謝{zh-cn}不了谢谢{ko}다음에{es}No, gracias{fr}Non merci{pt-br}Não, obrigado{de}Nein Danke")
	UI.setAttribute("Mage1CompleteText", "text", "{en}Create Card Pool{ru}Создать пул карт{zh-cn}创建卡池{ko}카드 풀 생성{es}Crear Grupo de Cartas{fr}Créer un Pool de Cartes{pt-br}Criar Conjunto de Cartas{de}Kartenpool erstellen")
	UI.setAttribute("Mage2CompleteText", "text", "{en}Create Card Pool{ru}Создать пул карт{zh-cn}创建卡池{ko}카드 풀 생성{es}Crear Grupo de Cartas{fr}Créer un Pool de Cartes{pt-br}Criar Conjunto de Cartas{de}Kartenpool erstellen")
	UI.setAttribute("Mage3CompleteText", "text", "{en}Create Card Pool{ru}Создать пул карт{zh-cn}创建卡池{ko}카드 풀 생성{es}Crear Grupo de Cartas{fr}Créer un Pool de Cartes{pt-br}Criar Conjunto de Cartas{de}Kartenpool erstellen")
	UI.setAttribute("Mage4CompleteText", "text", "{en}Create Card Pool{ru}Создать пул карт{zh-cn}创建卡池{ko}카드 풀 생성{es}Crear Grupo de Cartas{fr}Créer un Pool de Cartes{pt-br}Criar Conjunto de Cartas{de}Kartenpool erstellen")
	UI.setAttribute("FeedbackTitle", "text", "{en}Feedback{ru}Обратная связь{zh-tw}回饋意見{zh-cn}反馈{ko}피드백{es}Realimentación{fr}Retour{pt-br}Comentários{de}Feedback")
	UI.setAttribute("FeedbackText1", "text", "{en}I'm just one guy, and I can't test every possible combination of this mod before releasing a patch. Your feedback is appreciated, and will improve the mod for everyone else.<size=6>\n\n</size>Let me know anything, big or small, that has caused you problems, or could make your game better. I have programmed for the way I play, so I may not have considered every interaction possible.<size=6>\n\n</size>While I read all the Feedback, if you want me to reply about your problem, it's best to post to the Mod's Workshop page instead.{ru}Я в одиночку работаю над модом, и я не могу протестировать все возможные комбинации этого мода перед выпуском патча. Обратная связь приветствуется, и позволит улучшить мод для всех остальных.<size=6>\n\n</size>Дайте мне знать о любой мелочи, которая вызывает у вас проблемы, или которая может улучшить вашу игру. При разработке я учитывал свой стиль игры, поэтому я мог не учесть все возможные взаимодействия.<size=6>\n\n</size>Я читаю все отзывы, но если вы хотите, чтобы я ответил на вашу проблему, лучше всего разместить сообщение на странице Мастерской этого мода.{zh-tw}我只有一個人，無法在發布更新前測試模組的每種可能。\n感謝你的意見，這能協助改善模組讓玩家有更好的體驗。<size=6>\n\n</size>無論問題大小，只要有造成你困擾的地方，或是改善遊戲\n的建議，歡迎告訴我。我在製作此模組時，主要是照自己\n的遊玩方式來製作，因此可能會沒考慮到其他情境。<size=6>\n\n</size>我會閱讀所有的意見，但若希望我直接回覆你，建議直接\n留言在模組的工作坊頁面。{zh-cn}我只有一个人，无法在发布更新前测试模组的每种可能。\n感谢你的反馈，这能协助改善模组让玩家有更好的体验。<size=6>\n\n</size>无论问题大小，只要有造成你困扰的地方，或是改善游戏\n的建议，欢迎告诉我。我在制作此模组时，主要是照自己\n的游玩方式来制作，因此可能会没考虑到其他情境。<size=6>\n\n</size>我会阅读所有的反馈，但若希望我直接回覆你，建议直接\n留言在模组的创意工坊页面。{ko}피드백 해주셔서 감사합니다. 모든 사항이 패치에 반영되지 않을 수 있음에 양해바랍니다.<size=6>\n\n</size>심각하거나 사소하거나, 어떤 버그나 질문이 있다면 스크립트의 발전을 위해 보고해주세요.  만약 직접 답변을 원한다면, 스팀워크샵에 문의하세요.<size=6>\n\n</size>한국어 번역에 문의 사항이 있다면, chamena1110@gmail.com으로 메일하시면 피드백 드리겠습니다.{es}Solo soy un tipo y no puedo probar todas las combinaciones posibles de este mod antes de lanzar un parche. Se agradecen sus comentarios y mejorarán la modificación para todos los demás.<size=6>\n\n</size>Dime cualquier cosa, grande o pequeña, que te haya causado problemas o que pueda mejorar tu juego. He programado para mi forma de jugar, por lo que es posible que no haya considerado todas las interacciones posibles.<size=6>\n\n</size>Mientras leo todos los comentarios, si quieres que te responda sobre tu problema, lo mejor es publicar en la página del taller del mod.{fr}Je ne suis qu'un gars, et je ne peux pas tester toutes les combinaisons possibles de ce mod avant de sortir un patch. Vos commentaires sont appréciés et amélioreront le mod pour tout le monde.<size=6>\n\n</size>Faites-moi savoir tout ce qui, petit ou grand, vous a causé des problèmes ou pourrait améliorer votre jeu. J'ai programmé pour ma façon de jouer, donc je n'ai peut-être pas envisagé toutes les interactions possibles.<size=6>\n\n</size>Pendant que je lis tous les commentaires, si vous voulez que je réponde à votre problème, il est préférable de poster à la place sur la page de l'atelier du mod.{pt-br}Eu sou apenas um cara, e Eu não posso testar cada possível combinação deste mod antes de liberar uma atualização. Seu comentário é apreciado e melhorará o mod para todo mundo.<size=6>\n\n</size>deixe-me saber de tudo, coisas grandes ou pequenas, que causaram problemas, ou poderia fazer seu jogo melhor. Eu tenho programado pela forma que Eu jogo, então Eu posso não ter considerado toda interação possível.<size=6>\n\n</size>Apesar de eu ler todos os comentários, se você me quiser respondendo sobre o seu problema, é melhor postá-lo na página do Mod na Oficina.{de}Ich bin nur ein Typ, und ich kann nicht jede mögliche Kombination dieses Mods testen, bevor ich einen Patch veröffentliche. Ihr Feedback wird geschätzt und wird den Mod für alle anderen verbessern.<size=6>\n\n</size>Lassen Sie mich alles wissen, ob groß oder klein, das Ihnen Probleme bereitet hat oder Ihr Spiel verbessern könnte. Ich habe für meine Spielweise programmiert, also habe ich vielleicht nicht jede Interaktion für möglich gehalten.<size=6>\n\n</size>Ich lese zwar das gesamte Feedback, aber wenn Sie möchten, dass ich auf Ihr Problem antworte, ist es am besten, stattdessen auf der Mod-Workshop-Seite zu posten.")
	UI.setAttribute("SendBUGRequestYesText", "text", "{en}Send Feedback{ru}Отправить отзыв{zh-tw}送出意見{zh-cn}发送反馈{ko}피드백 전송{es}Enviar comentarios{fr}Envoyer des commentaires{pt-br}Envie Comentário{de}Feedback Senden")
	UI.setAttribute("SendBugRequestNoText", "text", "{en}Cancel{ru}Отмена{zh-tw}取消{zh-cn}取消{ko}취소{es}Cancelar{fr}Annuler{pt-br}Cancelar{de}Abbrechen")
	UI.setAttribute("StartingAtAHigherLevelTitle", "text", "{en}Starting at a Higher Level{ru}Старт с высоким уровнем{zh-cn}从较高等级开始游戏{ko}높은 레벨로 시작{es}Empezar en Nivel Más Alto{fr}Commencer à un Niveau Supérieur{pt-br}Iniciar em um Nível mais Alto{de}Start auf höherem Level")
	UI.setAttribute("StartingAtAHigherLevelRules1", "text", "{en}1) Select the desired Starting level in your Mage Knight's panel.\n2) Optionaly, adjust the Influence per Level value. Increasing makes things easier.\n3) Click the 'Create Card Pool' button to fill your hand with Cards you can choose from.\n4) Place cards and Crystals in your play area to update the amount you have spent.\n5) Clicking 'Complete' lets everyone else know you’re ready.**{ru}1) Выберите желаемый начальный уровень на панели вашего героя.\n2) При желании, отрегулируйте значение Влияния за уровень. Чем больше значение, тем легче.\n3) Нажмите кнопку «Создать пул карт», чтобы заполнить руку картами, которые можно выбрать.\n4) Разместите карты и кристаллы в своей игровой зоне. Скрипт обновится и отразит остаток.\n5) Кнопка «Завершить» даст всем остальным знать, что вы готовы**.\n\nСтоимость:{zh-cn}1) 在魔法骑士面板中调整起始等级。\n2) 点击“创建卡池”按钮，卡牌会抽到手牌区来供你选择。\n3) 非强制：调整每个等级所获得的影响力。增加会使游戏较为容易。\n4) 将想要的卡牌和魔晶放在你的玩家面板上，选单会更新你的花费。\n5) 点击“完成”让其他人知道你准备好了。**{ko}1) 메이지 나이트 패널에서 원하는 시작 레벨을 선택하세요.\n2) 원한다면 레벨당 영향력 값을 조정하세요. 값을 높이면 진행이 더 수월해집니다.\n3) ‘카드 풀 생성’ 버튼을 클릭하여 선택할 수 있는 카드로 패를 채우세요.\n4) 플레이 영역에 카드와 크리스탈을 배치하여 사용한 양을 업데이트하세요.\n5) '완료'를 클릭하면 다른 플레이어들에게 준비가 끝났음을 알릴 수 있습니다.**{es}1) Selecciona el nivel inicial que desees en el panel de tu Mage Knight.\n2) Si lo deseas, ajusta el valor de 'Influencia por nivel'. Si lo aumentas, te resultará más fácil.\n3) Haz clic en el botón 'Crear mazo' para llenar tu mano con cartas entre las que podrás elegir.\n4) Coloca cartas y cristales en tu zona de juego para actualizar la cantidad que has gastado.\n5) Al hacer clic en 'Completar', les indicas a los demás que estás listo.**{fr}1) Sélectionnez le niveau de départ souhaité dans le panneau de votre Mage Knight.\n2) Si vous le souhaitez, ajustez la valeur 'Influence par niveau'. L'augmenter facilite les choses.\n3) Cliquez sur le bouton 'Créer un paquet de cartes' pour remplir votre main de cartes parmi lesquelles vous pourrez choisir.\n4) Placez les cartes et les cristaux dans votre zone de jeu pour mettre à jour le montant que vous avez dépensé.\n5) En cliquant sur 'Terminer', vous indiquez à tous les autres joueurs que vous êtes prêt.**{pt-br}1) Selecione o nível inicial desejado no painel do seu Mage Knight.\n2) Se desejar, ajuste o valor de Influência por Nível. Aumentar esse valor facilita as coisas.\n3) Clique no botão 'Criar Baralho de Cartas' para preencher sua mão com cartas que você pode escolher.\n4) Coloque cartas e cristais na sua área de jogo para atualizar a quantidade que você gastou.\n5) Clicar em “Concluir' avisa a todos que você está pronto.**{de}1) Wähle das gewünschte Startlevel im Panel deines Mage Knights.\n2) Optional: Passe den Wert für Einfluss pro Level an. Ein höherer Wert macht den Start einfacher.\n3) Klicke auf „Kartenauswahl erzeugen“, um deine Hand mit Karten zu füllen, aus denen du wählen kannst.\n4) Lege Karten und Kristalle in deinen Spielbereich, um den bereits ausgegebenen Einfluss zu aktualisieren.\n5) Mit einem Klick auf „Fertig“ zeigst du an, dass du bereit bist. Sobald alle „Fertig“ klicken, wird das Spiel vollständig vorbereitet.**")
	UI.setAttribute("StartingAtAHigherLevelRules2", "text", "{en}Crystals\nAdvanced Actions\nSpells\nArtifacts\nUnits{ru}Кристаллы\nОсобые действия\nЗаклинания\nАртефакты\nОтряды{zh-cn}魔晶\n高级行动卡\n法术卡\n神器\n部队{ko}수정\n상급 액션\n마법\n유물\n유닛{es}Cristales\nAcciones Avanzadas\nHechizos\nArtefactos\nUnidades{fr}Cristaux\nActions Avancées\nSorts\nArtefacts\nUnités{pt-br}Cristais\nAções Avançadas\nFeitiços\nArtefatos\nUnidades{de}Kristalle\nFortgeschrittene Aktionen\nZauber\nArtefakte\nEinheiten")
	UI.setAttribute("StartingAtAHigherLevelRules3", "text", "{en}- 3 Influence each (put in your inventory)\n- 6 Influence each\n- 9 Influence each (7 Influence with a crystal of the same color)*\n- 12 Influence each\n- Their normal Influence cost each{ru}- 3 Влияния каждый (положите в свой инвентарь)\n- 6 Влияний каждая\n- 9 Влияний или 7 Влияний плюс кристалл того же цвета*\n- 12 Влияний каждый\n- их обычная стоимость Влияния{zh-cn}- 每颗花费 3 点影响力（放入你的物品栏）。\n- 每张花费 6 点影响力。\n- 每张花费 9 点影响力（或 7 点 + 1 颗同色魔晶。）*\n- 每张花费 12 点影响力。\n- 本身的部队费用。{ko}- 각각 3 영향력 (인벤토리에 넣기)\n- 각각 6 영향력\n- 각각 9 영향력 (같은 색상의 크리스탈을 사용하면 7 영향력)*\n- 각각 12 영향력\n- 각각 일반 영향력 소모량{es}- 3 de influencia cada uno (añádelos a tu inventario)\n- 6 de influencia cada uno\n- 9 de influencia cada uno (7 de influencia con un cristal del mismo color)*\n- 12 de influencia cada uno\n- Su coste normal de influencia cada uno{fr}- 3 points d'influence chacun (à ajouter à votre inventaire)\n- 6 points d'influence chacun\n- 9 points d'influence chacun (7 points d'influence avec un cristal de la même couleur)*\n- 12 points d'influence chacun\n- Leur coût normal en points d'influence chacun{pt-br}- 3 de Influência cada (colocar no seu inventário)\n- 6 de Influência cada\n- 9 de Influência cada (7 de Influência com um cristal da mesma cor)*\n- 12 de Influência cada\n- Seu custo normal de Influência cada{de}- je 3 Einfluss (legt in dein Inventar)\n- 6 Einfluss jeweils\n- 9 Einfluss oder 7, wenn ein Kristall derselben Farbe gelegt wird*\n- 12 Einfluss jeweils\n- jeweils die normalen Einflusskosten")
	UI.setAttribute("StartingAtAHigherLevelRules4", "text", "{en}*Put starting crystal from your inventory on the spell\n**When everyone clicks 'Complete', the game will finish setting up.{ru}*Положите начальный кристалл из своего инвентаря на Заклинание.\n**Когда все нажмут «Завершить», игра завершит настройку.{zh-cn}*获得你英雄卡牌底部上显示的两个不同颜色魔晶\n**当所有人点击“完成”时， 游戏将完成设置。{ko}*마법을 구매할때 수정을 사용하려면, 주어진 저장 칸의 수정을 마법 위에 올려두면 됩니다.\n**모든 플레이어가 '완료' 버튼을 누르고 난 뒤 게임이 시작됩니다. {es}*Coloca un cristal inicial de tu inventario en el hechizo.\n**Cuando todos los jugadores pulsen 'Completo', el mod finalizará la preparación.{fr}*Mettez le cristal de départ de votre inventaire sur le sort.\n**Lorsque tout le monde clique sur 'Terminer', la configuration du jeu est terminée.{pt-br}*Coloque cristais iniciais do seu inventário no feitiço.\n**Quando todos clicam em 'Completo', o jogo irá terminar a preparação.{de}*Legt den Startkristall aus eurem Inventar auf den Zauber.\n**Wenn alle auf „Fertig stellen“ klicken, wird der Spielaufbau abgeschlossen.")
	UI.setAttribute("SetupTitle", "text", "{en}MAGE KNIGHT (HIGHLY SCRIPTED) - SETUP{ru}MAGE KNIGHT (HIGHLY SCRIPTED) - НАСТРОЙКИ{zh-tw}魔法騎士（高度腳本化）－設置{zh-cn}魔法骑士（高度脚本化）－设置{ko}메이지 나이트 (하이 스크립트) - 설정{es}MAGE KNIGHT (HIGHLY SCRIPTED) - CONFIGURACION{fr}MAGE KNIGHT (HIGHLY SCRIPTED) - INSTALLER{pt-br}MAGE KNIGHT (HIGHLY SCRIPTED) - Preparação{de}MAGE KNIGHT (HOCHGRADIG GESCRIPTET) - EINRICHTUNG")
	UI.setAttribute("StartButtonText", "text", "{en}Start - Select at least two Mage Knights first{ru}Начало - Сначала выберите как минимум двух Рыцарей-магов.{zh-tw}開始 - 首先選擇至少兩位魔法騎士{zh-cn}开始 - 首先选择至少两位魔法骑士{ko}시작 - 먼저 두 명 이상의 플레이어를 선택하세요{es}Comenzar - Selecciona al menos dos Mage Knight {fr}Démarrer - Sélectionnez d'abord au moins deux Mages{pt-br}Início - Selecione ao menos dois Mage Knights primeiro{de}Start - Wähle vorher mindestens 2 Mage Knights")
	UI.setAttribute("SWarOfFourtartButtonText", "text", "{en}Start - Competitive{ru}Начало - Соревновательный{zh-tw}開始 - 對抗模式{zh-cn}开始 - 对抗模式{ko}시작 - 경쟁{es}Comenzar - Competitivo{fr}Démarrer - Compétitif{pt-br}Início - Competitivo{de}Start - Wettbewerbsfähig")
	UI.setAttribute("RandomButtonText", "text", "{en}Random{ru}Случайный{zh-tw}隨機{zh-cn}随机{ko}무작위{es}Aleatorio{fr}Aléatoire{pt-br}Aleatório{de}Zufällig")
	UI.setAttribute("ScenarioText", "text", "{en}Scenario -{ru}Сценарий -{zh-tw}選擇劇本：{zh-cn}选择剧本：{ko}시나리오{es}Escenario -{fr}Scénario -{pt-br}Cenário -{de}Szenario -")
	UI.setAttribute("ScenarioSettingsTitle", "text", "{en}1. Scenario Selection{ru}1. Выбор сценария{zh-tw}1. 劇本選擇{zh-cn}1. 剧本选择{ko}1. 시나리오 선택{es}1. Selección del Escenario{fr}1. Sélection des Scénarios{pt-br}1. Seleção de Cenários{de}1. Auswahl des Szenarios")
	UI.setAttribute("GameSettings1Title", "text", "{en}2. Optional Variants{ru}2. Дополнительные параметры{zh-tw}2. 可選變體規則{zh-cn}2. 可选变体规则{ko}2. 게임 설정{es}2. Variantes opcionales{fr}2. Variantes facultatives{pt-br}2. Variantes opcionais{de}2. Optionale Varianten")
	UI.setAttribute("GameSettings2Title", "text", "{en}2. Optional Variants{ru}2. Дополнительные параметры{zh-tw}2. 可選變體規則{zh-cn}2. 可选变体规则{ko}2. 게임 설정{es}2. Variantes opcionales{fr}2. Variantes facultatives{pt-br}2. Variantes opcionais{de}2. Optionale Varianten")
	UI.setAttribute("Setup1SelectionText", "text", "{en}Setup Variants{ru}<size=16>Параметры сценария</size>{zh-tw}變體設定{zh-cn}变体设置{ko}세팅 설정{es}Variantes de Instalación{fr}Variantes d'Installation{pt-br}Variantes de Instalação{de}Setup-Varianten")
	UI.setAttribute("Setup1Text", "text", "{en}Setup Variants{ru}<size=16>Параметры сценария</size>{zh-tw}變體設定{zh-cn}变体设置{ko}세팅 설정{es}Variantes de Instalación{fr}Variantes d'Installation{pt-br}Variantes de Instalação{de}Setup-Varianten")
	UI.setAttribute("Setup2SelectionText", "text", "{en}Play Variants{ru}<size=16>Опциональные правила</size>{zh-tw}變體玩法{zh-cn}变体玩法{ko}플레이 설정{es}Variantes de Juego{fr}Variantes de Jeu{pt-br}Variantes de Jogo{de}Spiel-Varianten")
	UI.setAttribute("Setup2Text", "text", "{en}Play Variants{ru}<size=16>Опциональные правила</size>{zh-tw}變體玩法{zh-cn}变体玩法{ko}플레이 설정{es}Variantes de Juego{fr}Variantes de Jeu{pt-br}Variantes de Jogo{de}Spiel-Varianten")
	UI.setAttribute("MageAssignmentTitle", "text", "{en}3. Mage Knight Assignment{ru}3. Выбор Рыцарей-магов{zh-tw}3. 分配魔法騎士{zh-cn}3. 分配魔法骑士{ko}3. 메이지 나이트 선택{es}3. Asignación de Mage Knight{fr}3. Affectation du Mage Knight{pt-br}3. Seleção de Mage Knight{de}3. Mage Knight Auftrag")
	UI.setAttribute("scenarioTweaksText", "text", "{en}4. Optional Scenario Tweaks{ru}4. Дополнительные настройки сценария{zh-tw}4. 劇本設定調整{zh-cn}4. 剧本设置调整{ko}4. 시나리오 조정{es}4. Ajustes Opcionales del Escenario{fr}4. Ajustements Facultatifs du Scénario{pt-br}4. Ajustes Opcionais do Cenário{de}4. Optionale Änderungen am Szenario")
	UI.setAttribute("ScenarioEndText", "text", "{en}Scenario End{ru}Конец сценария{zh-tw}劇本結束{zh-cn}剧本结束{ko}시나리오 종료{es}Fin del Escenario{fr}Fin du Scénario{pt-br}Fim do Cenário{de}Szenario Ende")
	UI.setAttribute("FirstPosText", "text", "{en}1st Position Mage Knight -{ru}1-ый Рыцарь-маг -{zh-tw}1號位魔法騎士：{zh-cn}1号位魔法骑士：{ko}메이지 나이트 플레이어 1 -{es}Primer Mage Knight -{fr}1ère position Mage Knight -{pt-br}Mage Knight da 1ª Posição -{de}Position 1 Magier-Ritter -")
	UI.setAttribute("SecondPosText", "text", "{en}2nd Position Mage Knight -{ru}2-ой Рыцарь-маг -{zh-tw}2號位魔法騎士：{zh-cn}2号位魔法骑士：{ko}메이지 나이트 플레이어 2 -{es}Segundo Mage Knight -{fr}2ème position Mage Knight -{pt-br}Mage Knight da 2ª Posição -{de}Position 2 Magier-Ritter -")
	UI.setAttribute("ThirdPosText", "text", "{en}3rd Position Mage Knight -{ru}3-ий Рыцарь-маг -{zh-tw}3號位魔法騎士：{zh-cn}3号位魔法骑士：{ko}메이지 나이트 플레이어 3 -{es}Tercer Mage Knight -{fr}3ème position Mage Knight -{pt-br}Mage Knight da 3ª Posição -{de}Position 3 Magier-Ritter -")
	UI.setAttribute("FourthPosText", "text", "{en}4th Position Mage Knight -{ru}4-ый Рыцарь-маг -{zh-tw}4號位魔法騎士：{zh-cn}4号位魔法骑士：{ko}메이지 나이트 플레이어 4 -{es}Cuarto Mage Knight -{fr}4ème Position Mage Knight -{pt-br}Mage Knight da 4ª Posição -{de}Position 4 Magier-Ritter -")
	refreshProxySetupLabel()
	UI.setAttribute("VolkareCombatText", "text", "{en}Volkare's Combat Level -{ru}Уровень битвы Волкара -{zh-tw}沃卡里的戰鬥等級：{zh-cn}沃卡里的战斗等级： {ko}볼케어 전투 레벨 -{es}Nivel de Combate de Volkare -{fr}Niveau de Combat de Volkare -{pt-br}Nível de combate de Volkare -{de}Volkare´s Kampf Level -")
	UI.setAttribute("VolkareRaceText", "text", "{en}Volkare's Race Level -{ru}Уровень гонки Волкара -{zh-tw}沃卡里的競速等級：{zh-cn}沃卡里的竞速等级： {ko}볼케어 레이스 레벨 -{es}Nivel de Carrera de Volkare -{fr}Niveau de Course Volkare -{pt-br}Nível da Corrida de Volkare -{de}Volkares Rennstufe -")
	UI.setAttribute("RandomGameButtonText", "text", "{en}Give me a Mystery Solo Setup{ru}Дайте мне одиночный сценарий со случайными параметрами{zh-tw}幫我設置一場神秘的單人遊戲{zh-cn}帮我设置一局神秘的单人游戏{ko}랜덤 솔로 시나리오 빠른 시작{es}Dame una preparación misteriosa en Solitario{fr}Donnez-moi une configuration aléatoire Solo{pt-br}Me dê um Cenário Misterioso Aleatório{de}Gib mir ein Mystery-Solo-Setup")
	UI.setAttribute("newPlayerText", "text", "{en}I'm a new Player and want the Walkthrough Scenario{ru}Я новый игрок и хочу пройти Обучающий сценарий{zh-tw}我是一名新玩家，開始“首次勘察”劇本{zh-cn}我是一名新玩家，开始“首次勘察”剧本{ko}입문자를 위한 튜토리얼 시나리오{es}Soy un jugador novel y quiero el escenario de introducción{fr}Je suis un nouveau joueur et je veux le scénario pas à pas{pt-br}Sou um jogador novo e quero o Cenário Tutorial{de}Ich bin ein neuer Spieler und möchte das Walkthrough-Szenario")
	UI.setAttribute("ROTFText", "text", "{en}Rise of the Forgemasters -{ru}<size=16>Восстание Мастеров Кузни -</size>{zh-tw}鍛造師崛起{zh-cn}锻造师崛起{ko}라이즈 오브 포지마스터{es}El Ascenso de los Forjadores - {fr}L'essor des Maîtres de Forge -{pt-br}Ascensão dos Forjadores -{de}Aufstieg der Schmiedemeister -")
	UI.setAttribute("heroChallenges", "text", "Hero Challenges")
	UI.setAttribute("proxyPlayer", "text", "{en}Proxy Player [BETA]{ru}Прокси-игрок [BETA]{zh-tw}代理玩家 [BETA]{zh-cn}代理玩家 [BETA]{ko}프록시 플레이어 [BETA]{es}Jugador Proxy [BETA]{fr}Joueur Proxy [BETA]{pt-br}Jogador Proxy [BETA]{de}Proxy-Spieler [BETA]")
	UI.setAttribute("ScenarioPlayerLimitText", "text", "{en}Scenario Player Limit{ru}Ограничение количества игроков в сценарии{zh-tw}劇本人數限制{zh-cn}剧本人数限制{ko}시나리오 플레이어 수{es}Escenario Límite de Jugadores{fr}Scénario Limite de Joueurs{pt-br}Limite de Jogadores do Cenário{de}Szenario Spielerlimit")
	UI.setAttribute("DaringSelectionText", "text", "{en}Daring{ru}Смельчак{zh-tw}勇者{zh-cn}勇者{ko}웅장한{es}Atrevido{fr}Audacieux{pt-br}Ousado{de}Gewagt")
	UI.setAttribute("HeroicSelectionText", "text", "{en}Heroic{ru}Герой{zh-tw}英雄{zh-cn}英雄{ko}영웅적{es}Heroico{fr}Héroïque{pt-br}Heróico{de}Heroisch")
	UI.setAttribute("LegendarySelectionText", "text", "{en}Legendary{ru}Легенда{zh-tw}傳奇{zh-cn}传奇{ko}전설적{es}Legendario{fr}Légendaire{pt-br}Lendário{de}Legendär")
	UI.setAttribute("FairSelectionText", "text", "{en}Fair{ru}Шаг{zh-tw}正常{zh-cn}正常{ko}평범한{es}Justo{fr}Équitable{pt-br}Justo{de}Messe")
	UI.setAttribute("TightSelectionText", "text", "{en}Tight{ru}Рысь{zh-tw}緊急{zh-cn}紧急{ko}빠듯한{es}Apretado{fr}Serré{pt-br}Acirrado{de}Dichtes")
	UI.setAttribute("ThrillingSelectionText", "text", "{en}Thrilling{ru}Галоп{zh-tw}狂飆{zh-cn}狂飙{ko}스릴있는{es}Emocionante{fr}Palpitant{pt-br}Emocionante{de}Spannend")
	UI.setAttribute("ROTF0SelectionText", "text", "{en}Not Used{ru}Не используется{zh-tw}未使用{zh-cn}未使用{ko}사용 안 함{es}No se Utiliza{fr}Non Utilisé{pt-br}Não Utilizado{de}Nicht Verwendet")
	UI.setAttribute("ROTF1SelectionText", "text", "{en}1. New Beginning{ru}1. Новое начало{zh-tw}新的開始{zh-cn}新的开始{ko}1.새로운 시작{es}1. Un nuevo comienzo{fr}1. Nouveau départ{pt-br}1. Novo Começo{de}1. Neubeginn")
	UI.setAttribute("ROTF2SelectionText", "text", "{en}2. Spoils of War{ru}2. Военные трофеи{zh-tw}戰爭犒賞{zh-cn}战争犒赏{ko}2.전쟁의 전리품{es}2. Botín de Guerra{fr}2. Butin de Guerre{pt-br}2. Despojos de Guerra{de}2. Kriegsbeute")
	UI.setAttribute("ROTF3SelectionText", "text", "{en}3. Elixir of Life{ru}3. Эликсир Жизни{zh-tw}⽣命靈藥{zh-cn}⽣命灵药{ko}3.생명의 엘릭서{es}3. El Elixir de la Vida{fr}3. Élixir de vie{pt-br}3. Elixir da Vida{de}3. Lebenselixier")
	UI.setAttribute("VolkareLevelSelectionText", "text", "{en}Daring{ru}Смельчак{zh-tw}勇者{zh-cn}勇者{ko}웅장한{es}Atrevido{fr}Audacieux{pt-br}Ousado{de}Gewagt")
	UI.setAttribute("VolkareRaceSelectionText", "text", "{en}Fair{ru}Шаг{zh-tw}正常{zh-cn}正常{ko}평범한{es}Justo{fr}Équitable{pt-br}Justo{de}Messe")
	UI.setAttribute("ROTFSelectionText", "text", "{en}Not Used{ru}Не используется{zh-tw}未使用{zh-cn}未使用{ko}사용 안 함{es}No se Utiliza{fr}Non Utilisé{pt-br}Não Utilizado{de}Nicht Verwendet")
	UI.setAttribute("cameraControlText", "text", "{en}Camera Control{ru}Управление Камерой{zh-tw}視角控制{zh-cn}摄像机控制{ko}카메라 제어{es}Control de la Cámara{fr}Contrôle de la Caméra{pt-br}Controle de Câmera{de}Kamera-Steuerung")
	UI.setAttribute("tacticViewText", "text", "{en}Tactics{ru}Тактики{zh-tw}戰術卡{zh-cn}战术卡{ko}전술{es}Tácticas{fr}Tactique{pt-br}Táticas{de}Taktik")
	UI.setAttribute("mapViewText", "text", "{en}Map{ru}Игровое поле{zh-tw}地圖{zh-cn}地图{ko}맵{es}Mapa{fr}Carte{pt-br}Mapa{de}Karte")
	UI.setAttribute("playAreaViewText", "text", "{en}Player Board{ru}Доска игрока{zh-tw}玩家面板{zh-cn}玩家面板{ko}플레이어 보드{es}Tablero del jugador{fr}Tableau des joueurs{pt-br}Quadro do jogador{de}Spielertafel")
	UI.setAttribute("followEnemyView", "text", "{en}Follow Enemy{ru}Следовать за врагом{zh-tw}跟隨敵人{zh-cn}跟随敌人{ko}적 따라가기{es}Seguir al enemigo{fr}Suivre l'ennemi{pt-br}Seguir inimigo{de}Feind folgen")
	UI.setAttribute("followEnemyView", "isOn", gStates.cameraFollowEnemy and "true" or "false")
	UI.setAttribute("offerViewText", "text", "{en}Card Offers{ru}Доступные карты{zh-tw}卡牌供應區{zh-cn}卡牌供应区{ko}카드 공급처{es}Ofertas de cartas{fr}Offres de cartes{pt-br}Ofertas de cartas{de}Kartenangebote")
	UI.setAttribute("questViewText", "text", "{en}Quests{ru}Квесты{zh-tw}任務{zh-cn}任务{ko}퀘스트{es}Misiones{fr}Quêtes{pt-br}Missões{de}Quests")
	UI.setAttribute("questViewText", "color", "Black")
	UI.setAttribute("questView", "active", "false")
	UI.setAttribute("siteInfoViewText", "text", "{en}Site Info{ru}Описание Мест{zh-tw}地點資訊{zh-cn}地点信息{ko}장소 정보{es}Información{fr}Site Info{pt-br}Informações do site{de}Standort-Infos")
	UI.setAttribute("monsterInfoViewText", "text", "{en}Monster Info{ru}Описание врагов{zh-tw}敵人資訊{zh-cn}敌人信息{ko}몬스터 정보{es}Monstruos{fr}Infos sur les monstres{pt-br}Informações sobre monstros{de}Monster-Infos")
	UI.setAttribute("fameViewText", "text", "{en}Fame Board{ru}Планшет славы{zh-tw}名望面板{zh-cn}名望面板{ko}명성 보드{es}Fama{fr}Tableau de la renommée{pt-br}Quadro da Fama{de}Ruhm-Tafel")
	UI.setAttribute("rulesViewText", "text", "{en}Rules{ru}Правила{zh-tw}規則書{zh-cn}规则书{ko}규칙서{es}Reglas{fr}Règles{pt-br}Regras{de}Regeln")
	UI.setAttribute("dummyViewText", "text", "{en}Dummy Board{ru}Доска виртуального игрока{zh-tw}虛擬玩家面板{zh-cn}虚拟玩家面板{ko}가상 플레이어{es}Tablero Dummy{fr}Tableau factice{pt-br}Quadro de Jog. Fictício{de}Dummy-Brett")
	UI.setAttribute("topDownView", "text", "{en}Top Down View{ru}Вид сверху вниз{zh-tw}俯視視角{zh-cn}俯视视角{ko}탑뷰{es}Vista superior{fr}Vue de haut en bas{pt-br}Visão de cima para baixo{de}Top-Down-Ansicht")
	UI.setAttribute("IntroBoard1", "text", "{en}Welcome to my Mage Knight Highly Scripted Table.{ru}Добро пожаловать в мой мод с высоким уровнем заскриптованности сценариев для настольной игры Mage Knight.{zh-tw}歡迎遊玩我製作的高度腳本化魔法騎士。{zh-cn}欢迎游玩我制作的智能脚本版魔法骑士。{ko}메이지 나이트(하이 스크립트)에 오신 것을 환영합니다.{es}Bienvenido a mi mesa altamente escrita de Mage Knight.{fr}Bienvenue sur ma table hautement scriptée Mage Knight.{pt-br}Bem-vindo à minha mesa de Mage Knight Altamente Scriptada.{de}Willkommen zu Mage Knight fully scripted")
	UI.setAttribute("IntroBoard2", "text", "{en}Use this menu to configure your game, and have it setup for you. Mage Knight has lots of Variants and Adjustments experienced players can apply to increase the challenge if they wish. Despite this, the default settings are recommended for most games.<size=6>\n\n</size>During the Game, a LOT of things are automated. I tried to make things intuitive to use, or work with multiple play styles. I recommend not being shy, and just experimenting. The scripts save their data properly, making the 'Rewind' button safe to use.<size=6>\n\n</size>My work on this Table is never ending and feels like it's constantly evolving. I'm always keen to hear of ways I can improve things, or new ideas entirely. You can leave me a comment using the feedback button (top left of Screen), or on the workshop page.<size=6>\n\n</size>Mage Knight is designed by Vlaada Chvátil and published by the good folk at WizKids Games using amazing art from J.Lonnee. It is highly encouraged you purchase a copy for yourself.<size=6>\n\n</size><b>----------------------\n1. Choose your Scenario\n2. Select any Optional Variants.\n3. Pick the Mage Knights that are playing.\n4. Customize the Scenario if desired.\n5. Click Start.\n----------------------</b><size=6>\n\n</size>The Start Button unlocks when you have two or more Mage Knights selected. Picking a Dummy Mage Knight implies you are playing Solo or Cooperative, otherwise it's Competitive.{ru}Используйте это меню для настройки игры и автоматической настройки параметров. В игре «Mage Knight» предусмотрено множество вариантов и настроек, которые опытные игроки могут применять по желанию, чтобы повысить уровень сложности. Тем не менее для большинства партий рекомендуется использовать настройки по умолчанию.<size=6>\n\n</size>В ходе игры ОЧЕНЬ МНОГОЕ происходит автоматически. Я постарался сделать интерфейс интуитивно понятным и адаптированным к различным стилям игры. Рекомендую не стесняться и просто экспериментировать. Скрипты надёжно сохраняют данные, поэтому кнопку «Перемотка» можно использовать без опасений.<size=6>\n\n</size>Моя работа над этой таблицей никогда не заканчивается, и мне кажется, что она постоянно развивается. Я всегда рад услышать предложения по улучшению или совершенно новые идеи. Вы можете оставить мне комментарий, воспользовавшись кнопкой обратной связи (в левом верхнем углу экрана) или на странице в Workshop.<size=6>\n\n</size>Игра «Mage Knight» разработана Владой Чватилом и издана замечательной командой WizKids Games с использованием потрясающих иллюстраций от J.Lonnee. Настоятельно рекомендую приобрести себе экземпляр этой игры.<size=6>\n\n</size><b>----------------------\n1. Выберите сценарий.\n2. Выберите любые дополнительные варианты.\n3. Выберите «Маг-рыцарей», которые будут участвовать в игре.\n4. При желании настройте сценарий.\n5. Нажмите «Старт».\n--------------------- -</b><size=6>\n\n</size>Кнопка «Старт» становится доступной, когда выбраны два или более «Магических рыцарей». Выбор фиктивного «Магического рыцаря» означает, что вы играете в одиночном или кооперативном режиме, в противном случае игра проходит в соревновательном режиме.{zh-tw}使用此選單調整你的遊戲，系統將幫你自動完成設置。\n魔法騎士有許多變體規則和調整選項，\n經驗豐富的玩家可以根據需求，調整選項來增加遊戲難度。\n儘管如此，建議大多數遊戲仍然使用預設設置。<size=6>\n\n</size>遊戲中有許多操作會由腳本自動完成，\n我儘量讓操作介面簡單易用，並支援各種遊玩方式。\n建議你不用拘謹，多嘗試操作。\n腳本會自動儲存數據，所以你可以放心使用“回溯”按鈕。<size=8>\n\n</size>我對這個模組的開發永無止境，讓它會不斷進化與改進。\n我很樂意接受各種改善建議，或是任何新的想法。\n你可以透過回饋按鈕（螢幕左上角）或是工作坊頁面來留言給我。<size=6>\n\n</size>魔法騎士是規則由Vlaada Chvátil設計，插圖由J.Lonnee繪製，\n並由WizKids Games出版的遊戲。強烈建議你自己購買一份實體版。<size=6>\n\n</size><b>----------------------\n1. 選擇要玩的劇本\n2. 調整任何變體規則選項\n3. 挑選要遊玩的魔法騎士。\n4. 如果有需要，調整劇本的設置內容\n5. 點擊“開始”。\n----------------------</b><size=6>\n\n</size>“開始遊戲”按鈕會在你選擇至少兩個魔法騎士出場後解鎖，\n要進行單人或合作模式需要再選一個“虛擬玩家”的魔法騎士，\n否則會以對抗模式開始遊戲。{zh-cn}使用此菜单调整你的游戏，系统将帮你自动完成设置。\n魔法骑士有许多变体规则和调整选项，\n经验丰富的玩家可以根据需求，调整选项来增加游戏难度。\n尽管如此，建议大多数游戏仍然使用默认设置。 <size=6>\n\n</size>游戏中有许多操作会由脚本自动完成，\n我尽量让操作介面简单易用，并支援各种游玩方式。\n建议你不用拘谨，多尝试操作。\n脚本会自动保存数据，所以你可以放心使用“回溯”按钮。 <size=8>\n\n</size>我对这个模组的开发永无止尽，让它会不断进化与改进。\n我很乐意接受各种改善建议，或是任何新的想法。\n你可以通过反馈按钮（屏幕左上角）或是创意工坊页面来留言给我。 <size=6>\n\n</size>魔法骑士是规则由Vlaada Chvátil设计，插图由J.Lonnee绘制，\n并由WizKids Games出版的游戏。强烈建议你自己购买一份实体版。 <size=6>\n\n</size><b>----------------------\n1. 选择要玩的剧本\n2. 调整任何变体规则选项\n3. 挑选要游玩的魔法骑士。 \n4. 如果有需要，调整剧本的设置内容\n5. 点击“开始”。 \n----------------------</b><size=6>\n\n</size>“开始游戏”按钮会在你选择至少两个魔法骑士出场后解锁，\n要进行单人或合作模式需要再选一个“虚拟玩家”的魔法骑士，\n否则会以对抗模式开始游戏。{ko}이 메뉴를 사용하여 게임을 구성하고, 원하는 대로 설정을 조정하세요. 숙련된 플레이어를 위한 더 높은 난도를 적용할 수 있는 다양한 변형 규칙과 조정 사항을 제공합니다. 그러나 대부분의 게임에서 기본 설정을 사용하는 것을 권장합니다.<size=6>\n\n</size>게임 중에는 정말 많은 부분이 자동화되어 있습니다. 사용법이 직관적이고 다양한 플레이 스타일에 맞게 작동하도록 노력했습니다. 주저하지 말고 마음껏 실험해 보시길 권합니다. 스크립트가 데이터를 제대로 저장하므로 ‘되감기’ 버튼을 안전하게 사용할 수 있습니다.<size=6>\n\n</size>이 테이블에 대한 제 작업은 끝이 없으며, 끊임없이 진화하고 있는 느낌입니다. 개선할 수 있는 방법이나 완전히 새로운 아이디어가 있다면 언제든지 기꺼이 듣고 싶습니다. 화면 왼쪽 상단의 피드백 버튼을 이용하거나 워크숍 페이지에 댓글을 남겨 주시면 됩니다.<size=6>\n\n</size>『Mage Knight』는 Vlaada Chvátil이 디자인했으며, J.Lonnee의 멋진 일러스트와 함께 WizKids Games에서 출시했습니다. 실물 게임을 구매해 보시기를 적극 권장합니다.<size=6>\n\n</size><b>----------------------\n1. 시나리오를 선택하세요.\n2. 원하는 추가 설정을 선택하세요.\n3. 플레이할 메이지 나이트를 선택하세요.\n4. 원한다면 시나리오를 커스텀 설정하세요.\n5. ‘시작’을 클릭하세요.\n--------------------- -</b><size=6>\n\n</size>시작 버튼은 두 명 이상의 영웅(Mage Knight)을 선택했을 때 활성화됩니다. 더미 플레이어의 영웅을 설정하면 솔로 또는 협동 모드로 플레이하는 것이며, 그렇지 않은 경우 경쟁 모드로 진행됩니다.{es}Utiliza este menú para configurar tu partida y dejar que el juego se ajuste automáticamente a tus preferencias. Mage Knight cuenta con numerosas variantes y ajustes que los jugadores experimentados pueden aplicar para aumentar la dificultad si así lo desean. A pesar de ello, se recomienda utilizar la configuración predeterminada para la mayoría de las partidas.<size=6>\n\n</size>Durante la partida, MUCHAS cosas están automatizadas. He intentado que todo resulte intuitivo y se adapte a distintos estilos de juego. Te recomiendo que no te cortes y simplemente experimentes. Los scripts guardan los datos correctamente, por lo que el botón «Rebobinar» es seguro de usar.<size=6>\n\n</size>Mi trabajo en esta mesa es interminable y parece que está en constante evolución. Siempre estoy dispuesto a escuchar sugerencias sobre cómo puedo mejorar las cosas o ideas completamente nuevas. Puedes dejarme un comentario utilizando el botón de comentarios (arriba a la izquierda de la pantalla) o en la página del taller.<size=6>\n\n</size>«Mage Knight» ha sido diseñado por Vlaada Chvátil y publicado por la gente de WizKids Games, con las increíbles ilustraciones de J. Lonnee. Te recomiendo encarecidamente que compres un ejemplar para ti.<size=6>\n\n</size><b>----------------------\n1. Elige tu escenario\n2. Selecciona cualquier variante opcional.\n3. Elige los Mage Knights que van a jugar.\n4. Personaliza el escenario si lo deseas.\n5. Haz clic en «Empezar».\n--------------------- -</b><size=6>\n\n</size>El botón «Empezar» se desbloquea cuando tienes seleccionados dos o más Caballeros Magos. Elegir un Caballero Mago ficticio implica que estás jugando en modo individual o cooperativo; de lo contrario, se trata de un modo competitivo.{fr}Utilisez ce menu pour configurer votre partie et la personnaliser selon vos préférences. Mage Knight propose de nombreuses variantes et options que les joueurs expérimentés peuvent appliquer pour augmenter la difficulté s’ils le souhaitent. Malgré cela, les paramètres par défaut sont recommandés pour la plupart des parties.<size=6>\n\n</size>Pendant la partie, de TRÈS nombreux éléments sont automatisés. J’ai essayé de rendre l’interface intuitive et adaptée à différents styles de jeu. Je vous recommande de ne pas hésiter et de vous lancer dans l’expérimentation. Les scripts enregistrent correctement leurs données, ce qui permet d’utiliser le bouton « Rewind » en toute sécurité.<size=6>\n\n</size>Mon travail sur cette table est sans fin et j’ai l’impression qu’elle évolue constamment. Je suis toujours ravi d’entendre des suggestions d’amélioration ou de découvrir de nouvelles idées. Vous pouvez me laisser un commentaire via le bouton « Feedback » (en haut à gauche de l’écran) ou sur la page de l’Atelier.<size=6>\n\n</size>Mage Knight a été conçu par Vlaada Chvátil et publié par la formidable équipe de WizKids Games, avec les superbes illustrations de J.Lonnee. Je vous encourage vivement à vous procurer un exemplaire.<size=6>\n\n</size><b>----------------------\n1. Choisissez votre scénario\n2. Sélectionnez les variantes optionnelles de votre choix.\n3. Choisissez les Mage Knights qui participent à la partie.\n4. Personnalisez le scénario si vous le souhaitez.\n5. Cliquez sur « Démarrer ».\n--------------------- -</b><size=6>\n\n</size>Le bouton « Démarrer » se déverrouille lorsque vous avez sélectionné au moins deux Mage Knights. Choisir un Mage Knight factice signifie que vous jouez en solo ou en mode coopératif ; dans le cas contraire, le jeu se déroule en mode compétitif.{pt-br}Use este menu para configurar seu jogo e deixar tudo pronto para você. O Mage Knight possui diversas variantes e ajustes que jogadores experientes podem aplicar para aumentar o desafio, se assim desejarem. Apesar disso, as configurações padrão são recomendadas para a maioria das partidas.<size=6>\n\n</size>Durante o jogo, MUITAS coisas são automatizadas. Tentei tornar tudo intuitivo de usar e compatível com vários estilos de jogo. Recomendo que você não tenha vergonha e simplesmente experimente. Os scripts salvam seus dados corretamente, tornando o botão “Rewind” seguro para uso.<size=6>\n\n</size>Meu trabalho nesta mesa é interminável e parece estar em constante evolução. Estou sempre aberto a sugestões de como posso melhorar as coisas ou a novas ideias completamente diferentes. Você pode me deixar um comentário usando o botão de feedback (canto superior esquerdo da tela) ou na página do Workshop.<size=6>\n\n</size>Mage Knight foi criado por Vlaada Chvátil e publicado pela equipe da WizKids Games, com a incrível arte de J.Lonnee. Recomendo fortemente que você compre um exemplar para si mesmo.<size=6>\n\n</size><b>----------------------\n1. Escolha seu Cenário\n2. Selecione quaisquer Variantes Opcionais.\n3. Escolha os Mage Knights que vão jogar.\n4. Personalize o Cenário, se desejar.\n5. Clique em Iniciar.\n--------------------- -</b><size=6>\n\n</size>O botão “Iniciar” é desbloqueado quando você seleciona dois ou mais Cavaleiros Magos. Escolher um Cavaleiro Mago fictício significa que você está jogando no modo Solo ou Cooperativo; caso contrário, o modo é Competitivo.{de}Verwende dieses Menü, um dein Spiel zu konfigurieren und die Einstellungen für dich vornehmen zu lassen. Mage Knight bietet zahlreiche Varianten und Anpassungsmöglichkeiten, mit denen erfahrene Spieler den Schwierigkeitsgrad nach Belieben erhöhen können. Dennoch werden für die meisten Spiele die Standardeinstellungen empfohlen.<size=6>\n\n</size>Während des Spiels laufen VIELE Abläufe automatisch ab. Ich habe versucht, die Bedienung intuitiv zu gestalten und sie für verschiedene Spielstile geeignet zu machen. Ich empfehle, sich nicht zu scheuen und einfach zu experimentieren. Die Skripte speichern ihre Daten ordnungsgemäß, sodass die Rewind-Schaltfläche sicher verwendet werden kann.<size=6>\n\n</size>Meine Arbeit an diesem Spieltisch ist nie abgeschlossen und es fühlt sich an, als würde er sich ständig weiterentwickeln. Ich bin immer daran interessiert, Vorschläge zur Verbesserung oder ganz neue Ideen zu hören. Ihr könnt mir über die Feedback-Schaltfläche (oben links auf dem Bildschirm) oder auf der Workshop-Seite einen Kommentar hinterlassen.<size=6>\n\n</size>Mage Knight wurde von Vlaada Chvátil entworfen und von den netten Leuten bei WizKids Games unter Verwendung der fantastischen Illustrationen von J. Lonnee veröffentlicht. Ich kann euch nur wärmstens empfehlen, euch ein Exemplar zu kaufen.<size=6>\n\n</size><b>--------------------\n1. Wähle dein Szenario aus.\n2. Wähle beliebige optionale Varianten aus.\n3. Wähle die Mage Knights aus, die mitspielen sollen.\n4. Passe das Szenario nach Wunsch an.\n5. Klicke auf Start.\n--------------------- -</b><size=6>\n\n</size>Die Schaltfläche Start wird freigeschaltet, sobald Sie zwei oder mehr Magierritter ausgewählt haben. Die Auswahl eines Dummy-Magierritters bedeutet, dass Sie im Solo- oder Kooperationsmodus spielen; andernfalls handelt es sich um einen Wettkampfangang.")
	UI.setAttribute("itemShopMod", "text", "{en}Item Shop Custom Mod{ru}<size=16>Пользовательский мод магазина предметов</size>{zh-tw}物品商店{zh-cn}物品商店{ko}아이템 상점{es}Tienda de artículos{fr}Boutique d'articles{pt-br}Loja de itens{de}Artikel Shop")
	UI.setAttribute("useAlternatePugs", "text", "{en}Use Alternate Monster Tokens{ru}<size=15>Использовать альтернативные жетоны врагов</size>{zh-tw}使用另一種怪物標記{zh-cn}使用另一種怪物標記{ko}몬스터 토큰 대체{es}Usar Fichas de Monstruo Alternativas{fr}Utiliser des Jetons de Monstres Alternatifs{pt-br}Use Fichas de Monstro Alternativas{de}Alternative Monstermarken Verwenden")
	UI.setAttribute("useCustomMageKnights", "text", "{en}Add custom Mage Knights{ru}<size=17>Добавить пользовательских Рыцарей-магов</size>{zh-tw}加入玩家自創的魔法騎士{zh-cn}加入玩家自创的魔法骑士{ko}커스텀 영웅 추가{es}Añadir Caballeros Mago personalizados{fr}Ajouter des chevaliers mages personnalisés{pt-br}Adicionar Mage Knights personalizados{de}Magier-Ritter hinzufügen")
	UI.setAttribute("ConquestSelectionText", "text", "{en}Conquest{ru}Завоевание{zh-tw}征服{zh-cn}征服{ko}정식 정복{es}Conquista{fr}Conquête{pt-br}Conquista{de}Eroberung")
	UI.setAttribute("FirstReconnaissanceSelectionText", "text", "{en}First Reconnaissance{ru}Первая Вылазка{zh-tw}首次勘察{zh-cn}首次勘察{ko}첫 번째 정찰{es}Primer reconocimiento{fr}Première Reconnaissance{pt-br}Primeiro Reconhecimento{de}Blitz-Eroberung")
	UI.setAttribute("FirstConquestSelectionText", "text", "{en}First Conquest{ru}Первое Завоевание{zh-tw}首次征服{zh-cn}首次征服{ko}첫 번째 정복{es}Primera Conquista{fr}Première Conquête{pt-br}Conquista Final{de}Solo-Eroberung")
	UI.setAttribute("MinesLiberationSelectionText", "text", "{en}Mines Liberation{ru}Освобождение Шахт{zh-tw}解放礦山{zh-cn}解放矿山{ko}광산 해방{es}Liberación de Minas{fr}Libération des Mines{pt-br}Liberação das MInas{de}Befreiung der Minen")
	UI.setAttribute("DruidNightsSelectionText", "text", "{en}Druid Nights{ru}Ночи Друидов{zh-tw}德魯伊之夜{zh-cn}德鲁伊之夜{ko}드루이드의 밤{es}Noches de Druidas{fr}Nuits de Druide{pt-br}Noites Druídicas{de}Druiden Nächte")
	UI.setAttribute("DungeonLordsSelectionText", "text", "{en}Dungeon Lords{ru}Владыки Подземелий{zh-tw}地下城領主{zh-cn}地下城领主{ko}던전 로드{es}Señores de las Mazmorras{fr}Seigneurs des Donjons{pt-br}Senhores das Marmorras{de}Kerkerfürsten")
	UI.setAttribute("ConquerAndHoldSelectionText", "text", "{en}Conquer and Hold{ru}Захват и Удержание{zh-tw}征服與掌控{zh-cn}征服与掌控{ko}정복과 유지{es}Conquistar y Mantener{fr}Conquérir et Tenir{pt-br}Conquistar e Defender{de}Erobern und Halten")
	UI.setAttribute("OneToReturnSelectionText", "text", "{en}One to Return{ru}Вернется только Один{zh-tw}絕地求生{zh-cn}绝地求生{ko}돌아갈 수 있는 자{es}Uno Para Volver{fr}Un Seul Revenu{pt-br}Um Para Retornar{de}Einer zum Zurückkehren")
	UI.setAttribute("VolkaresReturnSelectionText", "text", "{en}Volkare's Return{ru}Возвращение Волкара{zh-tw}沃卡里的歸來{zh-cn}沃卡里的归来{ko}볼케어의 귀환{es}El Regreso de Volkare{fr}Le Retour de Volkare{pt-br}Retorno de Volkare{de}Volkare's Rückkehr")
	UI.setAttribute("VolkaresQuestSelectionText", "text", "{en}Volkare's Quest{ru}Поход Волкара{zh-tw}沃卡里的使命{zh-cn}沃卡里的使命{ko}볼케어의 원정{es}La Búsqueda de Volkare{fr}La Quête de Volkare{pt-br}Missão de Volkare{de}Volkare's Suche")
	UI.setAttribute("LifeAndDeathSelectionText", "text", "{en}Life and Death{ru}Жизнь и Смерть{zh-tw}生死之間{zh-cn}生死之间{ko}삶과 죽음{es}Vida y Muerte{fr}Vie et Mort{pt-br}Vida e Morte{de}Leben und Tod")
	UI.setAttribute("TheRealmOfTheDeadSelectionText", "text", "{en}The Realm of the Dead{ru}Царство Мертвых{zh-tw}亡靈國度{zh-cn}亡灵国度{ko}죽은 자의 왕국{es}El Reino de los Muertos{fr}Le Royaume des Morts{pt-br}O Reino dos Mortos{de}Das Reich der Toten")
	UI.setAttribute("TheHiddenValleySelectionText", "text", "{en}The Hidden Valley{ru}Скрытая Долина{zh-tw}神秘幽谷{zh-cn}神秘幽谷{ko}숨겨진 계곡{es}El Valle Escondido{fr}La Vallée Cachée{pt-br}O Vale Escondido{de}Das verborgene Tal")
	UI.setAttribute("TheLostRelicSelectionText", "text", "{en}The Lost Relic{ru}Потерянная Реликвия{zh-tw}失落聖器{zh-cn}失落圣器{ko}사라진 유물{es}La Reliquia Perdida{fr}La Relique Perdue{pt-br}A Relíquia Perdida{de}Die verlorene Reliquie")
	UI.setAttribute("AgainsttheApocalypseSelectionText", "text", "{en}Against the Apocalypse{ru}Против Апокалипсиса{zh-tw}抵禦末日{zh-cn}抵禦末日{ko}아포칼립스에 맞서{es}Contra el Apocalipsis{fr}Contre l'Apocalypse{pt-br}Contra o Apocalipse{de}Gegen die Apokalypse")
	UI.setAttribute("AgainsttheHorsemenSelectionText", "text", "{en}Against the Horsemen{ru}Against the Horsemen{zh-tw}Against the Horsemen{zh-cn}Against the Horsemen{ko}Against the Horsemen{es}Against the Horsemen{fr}Against the Horsemen{pt-br}Against the Horsemen{de}Against the Horsemen")
	UI.setAttribute("AgainsttheDragonSelectionText", "text", "{en}Against the Dragon{ru}Против Дракона{zh-tw}對抗巨龍{zh-cn}对抗巨龙{ko}드래곤에 맞서{es}Contra el Dragón{fr}Contre le Dragon{pt-br}Contra o Dragão{de}Gegen den Drachen")
	UI.setAttribute("ApocalypseIsHereSelectionText", "text", "{en}Apocalypse is Here{ru}Апокалипсис наступил{zh-tw}末日降臨{zh-cn}末日降临{ko}아포칼립스가 왔다{es}El Apocalipsis Está Aquí{fr}L'Apocalypse est Là{pt-br}O Apocalipse Chegou{de}Die Apokalypse ist da")
	UI.setAttribute("FuryOfTheApocalypseDragonSelectionText", "text", "{en}Fury of the Apocalypse Dragon{ru}Ярость Дракона Апокалипсиса{zh-tw}末日巨龍之怒{zh-cn}末日巨龙之怒{ko}아포칼립스 드래곤의 분노{es}La Furia del Dragón del Apocalipsis{fr}La Fureur du Dragon de l'Apocalypse{pt-br}A Fúria do Dragão do Apocalipse{de}Der Zorn des Apokalypse-Drachen")
	UI.setAttribute("TheGauntletSelectionText", "text", "{en}The Gauntlet{ru}Вызов{zh-tw}大漠尋寶{zh-cn}大漠寻宝{ko}건틀릿{es}El Guantelete{fr}Le Gantelet{pt-br}A Manopla{de}Der Fehdehandschuh")
	UI.setAttribute("QuestForTheGoldenGrailSelectionText", "text", "{en}Quest for the Golden Grail{ru}В поисках Золотого Грааля{zh-tw}搜尋金色聖杯{zh-cn}搜寻金色圣杯{ko}황금 성배 원정{es}Búsqueda del Grial Dorado{fr}Quête du Graal d'or{pt-br}Busca pelo Graal Dourado{de}Die Suche nach dem Goldenen Gral")
	UI.setAttribute("TheChaosRiftSelectionText", "text", "{en}The Chaos Rift{ru}Разлом Хаоса{zh-tw}混沌裂縫{zh-cn}混沌裂缝{ko}혼돈의 균열{es}La Grieta del Caos{fr}La Faille du Chaos{pt-br}A Fenda Caótica{de}Der Chaos-Spalt")
	UI.setAttribute("UltimateConquestSelectionText", "text", "{en}Ultimate Conquest{ru}Абсолютное Завоевание{zh-tw}終極征服{zh-cn}终极征服{ko}궁극의 정복{es}Conquista Definitiva{fr}Conquête Ultime{pt-br}Conquista Derradeira{de}Ultimative Eroberung")
	UI.setAttribute("FastForwardedConquestSelectionText", "text", "{en}Fast Forwarded Conquest{ru}Ускоренное Завоевание{zh-tw}快速征服{zh-cn}快速征服{ko}앞서간 정복{es}Conquista Acelerada{fr}Conquête Rapide{pt-br}Conquista Acelerada{de}Blitz-Eroberung")
	UI.setAttribute("TheWarOfFourSelectionText", "text", "{en}The War of Four{ru}Война Четырех{zh-tw}四國爭霸{zh-cn}四国争霸{ko}워 오브 포{es}A Guerra dos Quatro{fr}La Gerre des Quatres{pt-br}A Guerra dos Quatro{de}Der Krieg der Vier")
	UI.setAttribute("RaidersOfTheCrusaderTempleSelectionText", "text", "{en}Raiders of the Crusader Temple{ru}Рейдеры храма крестоносцев{zh-tw}聖教軍奇兵{zh-cn}圣教军奇兵{ko}십자군 성전의 침입자{es}Asaltantes del Templo de los Cruzados{fr}Les aventuriers du temple des croisés{pt-br}Salteadores do Templo dos Cruzados{de}Räuber des Kreuzrittertempels")
	UI.setAttribute("ForTheCouncilSelectionText", "text", "{en}For the Council{ru}For the Council{zh-tw}For the Council{zh-cn}For the Council{ko}For the Council{es}For the Council{fr}For the Council{pt-br}For the Council{de}For the Council")
	UI.setAttribute("TheFracturedLandsSelectionText", "text", "{en}The Fractured Lands{ru}The Fractured Lands{zh-tw}The Fractured Lands{zh-cn}The Fractured Lands{ko}The Fractured Lands{es}The Fractured Lands{fr}The Fractured Lands{pt-br}The Fractured Lands{de}The Fractured Lands")
	UI.setAttribute("apocalypseQuestCards", "text", "{en}Apocalypse Dragon Quest Cards [BETA]{ru}Apocalypse Dragon Quest Cards [BETA]{zh-tw}Apocalypse Dragon Quest Cards [BETA]{zh-cn}Apocalypse Dragon Quest Cards [BETA]{ko}Apocalypse Dragon Quest Cards [BETA]{es}Apocalypse Dragon Quest Cards [BETA]{fr}Apocalypse Dragon Quest Cards [BETA]{pt-br}Apocalypse Dragon Quest Cards [BETA]{de}Apocalypse Dragon Quest Cards [BETA]")
	UI.setAttribute("CustomSelectionText", "text", "{en}Custom{ru}Пользовательский{zh-tw}自訂{zh-cn}自定义{ko}커스텀{es}Personalizado{fr}Personnalisé{pt-br}Customizado{de}Benutzerdefiniert")
	UI.setAttribute("ScenarioSelectionText", "text", "{en}Conquest{ru}Завоевание{zh-tw}征服{zh-cn}征服{ko}정식 정복{es}Conquista{fr}Conquête{pt-br}Conquista{de}Eroberung")
	--Restore the visible setup selections from saved state. Previously these labels were always reset to "nobody" on load,
	--which could make a saved Mage Knight appear missing because the dropdown correctly hides already-selected characters.
	local setupMageText={"firstMKSelectionText", "secondMKSelectionText", "thirdMKSelectionText", "fourthMKSelectionText"}
	for a=1, 4, 1 do
		local savedMage=(gStates.positionMageKnight~=nil and gStates.positionMageKnight[a]) or "nobody"
		UI.setAttribute(setupMageText[a], "text", translateWord[savedMage] or translateWord["nobody"])
	end
	local savedDummy=(gStates.positionMageKnight~=nil and gStates.positionMageKnight[5]) or "nobody"
	if savedDummy=="Volkare" then savedDummy=gStates.volkareSkills or "Random" end
	UI.setAttribute("dummyMKSelectionText", "text", translateWord[savedDummy] or translateWord["nobody"])
	UI.setAttribute("nobodySelectionText", "text", "{en}nobody{ru}никто{zh-tw}無玩家{zh-cn}无玩家{ko}없음{es}ninguno{fr}personne{pt-br}ninguém{de}Niemand")
	UI.setAttribute("RANDOMSelectionText", "text", "{en}Random{ru}Случайный{zh-tw}隨機{zh-cn}随机{ko}무작위{es}Aleatorio{fr}Aléatoire{pt-br}Aleatório{de}Zufällig")
	UI.setAttribute("AllSkillsSelectionText", "text", "{en}All Skills{ru}Все навыки{zh-tw}所有技能{zh-cn}所有技能{ko}모든 스킬{es}Todas las Habilidades{fr}Toutes les Compétences{pt-br}Todas Habilidades{de}Alle skills")
	UI.setAttribute("ArytheaSelectionText", "text", "{en}Arythea{ru}Аритея{zh-tw}艾莉西亞{zh-cn}艾莉西亚{ko}아리시아{es}Arythea{fr}Arythea{pt-br}Arythea{de}Arythea")
	UI.setAttribute("GoldyxSelectionText", "text", "{en}Goldyx{ru}Голдикс{zh-tw}歌狄克斯{zh-cn}歌狄克斯{ko}골딕스{es}Goldyx{fr}Goldyx{pt-br}Goldyx{de}Goldyx")
	UI.setAttribute("NorowasSelectionText", "text", "{en}Norowas{ru}Норовас{zh-tw}諾羅瓦斯{zh-cn}诺罗瓦斯{ko}노로워즈{es}Norowas{fr}Norowas{pt-br}Norowas{de}Norowas")
	UI.setAttribute("TovakSelectionText", "text", "{en}Tovak{ru}Товак{zh-tw}托維克{zh-cn}托维克{ko}토백{es}Tovak{fr}Tovak{pt-br}Tovak{de}Tovak")
	UI.setAttribute("BraevalarSelectionText", "text", "{en}Braevalar{ru}Бравалар{zh-tw}布雷維勒{zh-cn}布雷维勒{ko}브레이바라{es}Braevalar{fr}Braevalar{pt-br}Braevalar{de}Braevalar")
	UI.setAttribute("KrangSelectionText", "text", "{en}Krang{ru}Крэнг{zh-tw}朗格{zh-cn}朗格{ko}크랑{es}Krang{fr}Krang{pt-br}Krang{de}Krang")
	UI.setAttribute("WolfhawkSelectionText", "text", "{en}Wolfhawk{ru}Вульфхок{zh-tw}狼鷹{zh-cn}狼鹰{ko}울프호크{es}Wolfhawk{fr}Wolfhawk{pt-br}Wolfhawk{de}Wolfhawk")
	UI.setAttribute("CoralSelectionText", "text", "{en}Coral{ru}Coral{zh-tw}Coral{zh-cn}Coral{ko}Coral{es}Coral{fr}Coral{pt-br}Coral{de}Coral")
	UI.setAttribute("JormundSelectionText", "text", "{en}Jormund{ru}Йормунд{zh-tw}約爾蒙德{zh-cn}约尔蒙德{ko}요르문{es}Jormund{fr}Jormund{pt-br}Jormund{de}Jormund")
	UI.setAttribute("YmirghSelectionText", "text", "{en}Ymirgh{ru}Имирх{zh-tw}伊米爾{zh-cn}伊米尔{ko}유미르{es}Ymirgh{fr}Ymirgh{pt-br}Ymirgh{de}Ymirgh")
	UI.setAttribute("MevokSelectionText", "text", "{en}Mevok{ru}Мевок{zh-tw}梅沃克{zh-cn}梅沃克{ko}Mevok{es}Mevok{fr}Mevok{pt-br}Mevok{de}Mevok")
	UI.setAttribute("ZirtaeSelectionText", "text", "{en}Zirtae{ru}Zirtae{zh-tw}齊爾泰{zh-cn}齐尔泰{ko}Zirtae{es}Zirtae{fr}Zirtae{pt-br}Zirtae{de}Zirtae")
	UI.setAttribute("MalekSelectionText", "text", "{en}Malek{ru}Malek{zh-tw}馬萊克{zh-cn}马莱克{ko}Malek{es}Malek{fr}Malek{pt-br}Malek{de}Malek")
	UI.setAttribute("DusceniaSelectionText", "text", "{en}Duscenia{ru}Дусцения{zh-tw}達塞尼亞{zh-cn}达塞尼亚{ko}Duscenia{es}Duscenia{fr}Duscenia{pt-br}Duscenia{de}Duscenia")
	--UI.setAttribute("GameOverText", "text", "{en}Game over<size=6>\n\n</size>You have gone past the Round Limit and incurred the wrath of the Council of the Void.<size=6>\n\n</size>Check your Score if you still feel worthy, then grovel for a second chance if you dare!{ru}Игра окончена<size=6>\n\n</size>Вы превысили лимит Раундов и навлекли на себя гнев Совета Пустоты.<size=6>\n\n</size>Проверьте свой счет, если вы все еще чувствуете себя достойным, а затем пресмыкайтесь ради второго шанса, если осмелитесь!{zh-tw}遊戲結束\n\n你已經超出了時間限制，\n並因此觸怒了虛空議會。<size=6>\n\n</size>若你仍感覺自己表現還算不錯，\n那麼就去看看你的分數吧。\n接著提起勇氣去乞求虛空議會，\n能給予機會再挑戰一次。{zh-cn}游戏结束\n\n你已经超出了时间限制，\n并因此触怒了虚空议会。<size=6>\n\n</size>若你仍感觉自己表现还算不错，\n那么就去看看你的分数吧。\n然后提起勇气去乞求虚空议会，\n能给予机会再挑战一次。{ko}게임 종료<size=6>\n\n</size>정해진 라운드 제한을 넘겨버려 공허 위원회의 분노를 사버렸네요.<size=6>\n\n</size>점수를 계산해보거나, 그들에게 두 번째 기회를 요청해보세요, 자신 있다면 말이죠!{es}Fin de Partida<size=6>\n\n</size>Has superado el límite de Rondas y provocado la Ira del Concilio del Vacío.<size=6>\n\n</size>Comprueba tu Puntuación Final si crees que lo mereces, y arrástrate a una segunda oportunidad si te atreves!{fr}Jeu terminé<size=6>\n\n</size>Vous avez dépassé la limite de round et encouru la colère du Conseil du Vide.<size=6>\n\n</size>Vérifiez votre score si vous vous sentez toujours digne, que gravissez pour une seconde chance si vous l'osez !{pt-br}Jogo encerrado<size=6>\n\n</size>Você passou do limite de Rodadas e causou a ira do Conselho do Vácuo.<size=6>\n\n</size>Cheque sua pontuação se você ainda se acha merecedor, então chore por uma segunda chance se ousar!{de}Spiel vorbei<size=6>\n\n</size>Du hast das Rundenlimit überschritten und dir den Zorn des Rates der Leere zugezogen.<size=6>\n\n</size>Überprüfe deinen Punktestand, wenn du dich noch würdig fühlst, und bitte dann um eine zweite Chance, wenn du dich traust!")
	--Object UIs can finish loading after Global onLoad. Refresh them on the next frame without aborting the rest of onLoad if either object is unavailable.
	safeWaitFrames("Events",function()
		local artifactDeck=getObjectFromGUID(GUID.deck.artifact)
		if artifactDeck~=nil then artifactDeck.UI.setAttribute("ac75c4ArtifactOfferText", "text", "{en}Reward 1{ru}Награда 1{zh-cn}奖励1{ko}보상 1{es}Premiar 1{fr}Reward 1{pt-br}Premiar 1{de}Belohnung 1") end
		local monsterReplenish=getObjectFromGUID("d7a165")
		if monsterReplenish~=nil then
			monsterReplenish.UI.setAttribute("d7a165replenishMonsterPilesText", "text", "{en}Restock Empty Piles{ru}Восполнить пустые стопки{zh-cn}补齐抽空的标记{ko}빈 토큰더미채우기{es}Reabastecer Vacío Pilas{fr}Réapprovisionner Vider Les piles{pt-br}Reestocar Pilhas Vazias{de}Leere Stapel auffüllen")
			monsterReplenish.UI.setAttribute("d7a165swapTableText", "text", "{en}Use Other Table{ru}Другой вид стола{zh-cn}使用其他表{ko}다른 테이블 사용{es}Usar otra tabla{fr}Utiliser un autre tableau{pt-br}Usar outra tabela{de}Andere Tabelle verwenden")
		end
	end, 1)

	UI.show("ScoreButton")
	UI.show("HelpButton")
	UI.show("AutoFlipButton")
	UI.show("sendBugReportButton")
	UI.show("TableButton")
	UI.show("MonsterButton")
	UI.hide("welcome")
	UI.setAttribute("currentTurnButtonRealText", "text", gStates.turnCount)
	if gStates.firstStarted~=true then
		if gStates.mageKnightLevels==true then
			for a=1, 4, 1 do
				for _, mageDetails in pairs(turnOrder) do
					if mageDetails.seatPos==a and mageDetails.mage~=gStates.positionMageKnight[5] then
					 	if mageDetails.poolCreated~=nil then
							UI.setAttribute("Mage"..a.."CompleteButton", "onClick", "startHigherLevel")
							UI.setAttribute("Mage"..a.."CompleteText", "text", "{en}Complete{ru}Завершить{zh-cn}完成{ko}완료{es}Completo{fr}Compléter{pt-br}Completo{de}Fertig")
							UI.setAttribute("Mage"..a.."CompleteButton", "interactable", "true")
							UI.setAttribute("Mage"..a.."CompleteButtonImage", "image", "Sliced Button/Button New Active")
							UI.setAttribute("Mage"..a.."levelDown", "interactable", "false")
							UI.setAttribute("Mage"..a.."levelUp", "interactable", "false")
						end
						UI.show("Mage"..a.."LevelBoard")
						break
					end
				end
			end
			mageLevelBoard()
			UI.show("LevelUpRules")
		else
			UI.setAttribute("Setup", "active", "true")
			--Restore the saved setup exactly as it was without firing setup callbacks or dismissing the welcome screen.
			restoreSetupScenarioState()
			restoreSetupUI()
			restoreMageKnightSetupSection()
			refreshSetupStartButton()
		end
	else
		UI.setAttribute("helpButtonRealImage", "image", "Sliced Button/Button New Active")
		UI.setAttribute("helpButtonReal", "interactable", "true")
		UI.setAttribute("MonsterButtonRealImage", "image", "Sliced Button/Button New Active")
		UI.setAttribute("MonsterButtonReal", "interactable", "true")
		UI.setAttribute("ResourceTracker", "active", "true")
		UI.setAttribute("cameraControl", "active", "true")
		recourceTrackerReset("update")
		getObjectFromGUID(GUID.deck.spell).UI.setXmlTable({	{tag="Button", attributes={id="e4372aOfferUp", onClick="global/offerAdjust", onMouseDown="global/buttonClicked", onMouseUp="global/buttonClicked", height=150, width=240, position="60 190 -10", rotation="0 180 180", scale="0.32 0.32"},
														children={	{tag="Image", attributes={id="e4372aOfferUpImage", image="Sliced Button/Button Object Active", type="Sliced"}},
																	{tag="Text", attributes={font="Fonts/MKCardText", fontSize="90", fontStyle="Normal", alignment="MiddleCenter", text=">"}}}},
														{tag="Button", attributes={id="e4372aOfferDown", onClick="global/offerAdjust", onMouseDown="global/buttonClicked", onMouseUp="global/buttonClicked", height=150, width=240, position="-60 190 -10", rotation="0 180 180", scale="0.32 0.32"},
														children={	{tag="Image", attributes={id="e4372aOfferDownImage", image="Sliced Button/Button Object Active", type="Sliced"}},
																	{tag="Text", attributes={font="Fonts/MKCardText", fontSize="90", fontStyle="Normal", alignment="MiddleCenter", text="<"}}}}})
		if gStates.preEndTurn==true then UI.show("EndGameButton") end
		UI.setAttribute("helpButtonRealText", "Text", "{en}Help{ru}Помощь{zh-cn}帮  助{ko}도움말{es}Ayudar{fr}Aider{pt-br}Ajuda{de}Hilfe")
		UI.setAttribute("helpButtonReal", "onClick", "DisplayHelp")
		if gStates.gameScenario=="One to Return" then UI.hide("ScoreButton") end
		if gStates.autoFlip==true then UI.setAttribute("AutoFlipButtonRealImage", "image", "Sliced Button/Button New Deactive") end
		if gStates.tacticShown==true or gStates.tacticRemove==true then
		 	UI.show("NoticeBoard")
		 	UI.setAttribute("DrawOne", "interactable", "False")
			UI.setAttribute("DrawOneImage", "image", "Sliced Button/Button New Deactive")
			UI.setAttribute("ScoreButtonReal", "interactable", "False")
			UI.setAttribute("ScoreButtonRealImage", "image", "Sliced Button/Button New Deactive")
		 	UI.setAttribute("EndTurnButton", "interactable", "False")
			UI.setAttribute("EndTurnButtonImage", "image", "Sliced Button/Button New Deactive")
		else
			UI.setAttribute("ScoreButtonReal", "interactable", "True")
			UI.setAttribute("ScoreButtonRealImage", "image", "Sliced Button/Button New Active")
		end
		--Restore the centre panel through the same owner/state renderer used during live play.
		automatedMainPanelRefresh()
		for terrainGUID, hexOveride in pairs(gStates.hexOverideSave) do
			for location, hexFeature in pairs(hexOveride) do
				terrainTiles[terrainGUID].hexFeature[location]=hexFeature
			end
		end
		if getObjectFromGUID("8dbce4")~=nil then bannerOfCommandDecal() end
		--Add decals back to Pursuing and Ambushing tokens
		if gStates.rampageAmbush==true and gStates.rampagePursuit==false then
			for monsterGUID, _ in pairs(gStates.ambushingMonsters) do
				if getObjectFromGUID(monsterGUID)~=nil and getObjectFromGUID(monsterGUID).getPosition()[3]>-20.5 then
					local existingButtons=getObjectFromGUID(monsterGUID).UI.getXmlTable()
					for xmlKey, xmlParent in pairs(existingButtons) do
						if xmlParent.attributes~=nil and xmlParent.attributes.id=="Ambush Circle" then table.remove(existingButtons, xmlKey) end
					end
					existingButtons[#existingButtons+1]={tag="Image", attributes={id="Ambush Circle", height=1100, width=1100, position="0 0 -1", rotation="0 0 0", image="Ambush Circle"}}
					getObjectFromGUID(monsterGUID).UI.setXmlTable(existingButtons)
				end
			end
		end
		if gStates.rampagePursuit==true then
			for mage1, monsters in pairs(gStates.pursuingMonsters) do
				for monsterGUID, _ in pairs(monsters) do
					if getObjectFromGUID(monsterGUID)~=nil and getObjectFromGUID(monsterGUID).getPosition()[3]>-20.5 then
						for _, mage2 in pairs(mageKnights) do
							if mage2.mage==mage1 then
								local existingButtons=getObjectFromGUID(monsterGUID).UI.getXmlTable()
								for xmlKey=#existingButtons, 1, -1 do
									local xmlParent=existingButtons[xmlKey]
									if xmlParent.attributes~=nil and (xmlParent.attributes.id=="Pursue Shield" or xmlParent.attributes.id=="Ambush Circle" or xmlParent.attributes.id=="Pursuit Stunned") then table.remove(existingButtons, xmlKey) end
								end
								if gStates.ambushingMonsters[monsterGUID]~=nil then existingButtons[#existingButtons+1]={tag="Image", attributes={id="Ambush Circle", height=1100, width=1100, position="0 0 -1", rotation="0 0 0", image="Ambush Circle"}} end
								existingButtons[#existingButtons+1]={tag="Image", attributes={id="Pursue Shield", height=90, width=90, position="0 0 -15", rotation="0 0 180", image="Shield Button "..mage1}}
								local pursuit=monsters[monsterGUID]
								if pursuit.stunned==true or pursuit.state=="Stunned" then existingButtons[#existingButtons+1]={tag="Image", attributes={id="Pursuit Stunned", height=110, width=110, position="0 0 -15", rotation="0 0 180", image=pursuitStunnedImageURL}} end
								getObjectFromGUID(monsterGUID).UI.setXmlTable(existingButtons)
								break
							end
						end
					end
				end
			end
		end
		if gStates.darkCrusaderLevel~=nil and gStates.darkCrusaderLevel>0 then monsterPugs[darkCrusader.token]=leaderData[darkCrusader.terrainHex][gStates.darkCrusaderLevel].abilities end
		if gStates.elementalistLevel~=nil and gStates.elementalistLevel>0 then monsterPugs[elementalist.token]=leaderData[elementalist.terrainHex][gStates.elementalistLevel].abilities end
		for horsemanName,horsemanState in pairs(gStates.horsemen or {}) do
			local data=horsemanData[horsemanName]
			if data~=nil and horsemanState.level~=nil then monsterPugs[data.tokenGUID]=horsemanMonsterData(horsemanName,horsemanState.level) end
		end
		safeWaitFrames("Events",function() againstHorsemenRefreshReveals() end,4)
		--Rewind/load restores the Leader token and saved overkill value, but not its object UI.
		safeWaitFrames("Events",function() refreshLeaderOverkillButtons() end, 3)
		getObjectFromGUID("f2291a").UI.setXmlTable(gStates.exploreButtons)
		skillButtonActivate()
		refreshCoopCompSkillXs()
		claimButtonRefresh()
		dayTactic2ButtonActivate()
		safeWaitFrames("Events",function() refreshMeditationTrance() steadyTempoRefreshAll() end, 3)
		refreshCityScriptZones()
		refreshAllPlayerFameReputationFromShields()
		refreshTactic4HandBonus(false)
		mainUIUpdate("Save Loaded")
		restoreZigguratPyramidUI()
		addAvatarButtons()
		addCityButtons()
		applyColorBarButtons()
		refreshPlayerSeatColors()
		for _, mirrorGUID in pairs(gStates.mirrorSource) do getObjectFromGUID(mirrorGUID).registerCollisions() end
		straightenCrooked()
		for seatPos=1,4 do scheduleUnitLayoutRefresh(seatPos) end

		--stop unit wound creep and keep units cards under all the tokens.
		for _, obj in pairs(getObjects()) do
			if obj.getGMNotes()=="Unit Wound" then
				obj.setPosition({obj.getPosition()[1], obj.getPosition()[2], -33.29})
			end
			if gameCards[obj.guid]~=nil and (gameCards[obj.guid].cardType=="Regular Unit" or gameCards[obj.guid].cardType=="Elite Unit") then
				obj.setPosition({obj.getPosition()[1], 1.09, obj.getPosition()[3]})
			end
		end
		--A rewind taken immediately before the round reset restores this checkpoint, but not the callback
		--that originally entered endRound(). Resume it once the loaded table and UI have finished rebuilding.
		if gStates.endRoundResetPending==true then
			safeWaitFrames("Events",function() if gStates.endRoundResetPending==true then endRound() end end,10)
		end
	end
end

function onSave()
	saveZigguratPyramidUI()
	saveSetupState()
	local data_to_save={
		turnOrder=turnOrder,
		gStates=gStates}
	saved_data=JSON.encode(data_to_save)
	return saved_data
end


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
	gStates.setupScenarioState={scenario=gStates.gameScenario,playersRef=playersRef,rounds=source.rounds,mapShape=source.mapShape,
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

local zigguratPyramidUISaveAttributes={
    {id="zigguratPyramidInteract", attribute="active"},
    {id="zigguratPyramidInteractClimb1", attribute="interactable"},
    {id="zigguratPyramidInteractClimb2", attribute="interactable"},
    {id="zigguratPyramidInteractFight1", attribute="interactable"},
    {id="zigguratPyramidInteractFight2", attribute="interactable"},
    {id="zigguratPyramidInteractFight3", attribute="interactable"},
    {id="zigguratPyramidInteractClimb1Image", attribute="color"},
    {id="zigguratPyramidInteractClimb2Image", attribute="color"},
    {id="zigguratPyramidInteractFight1Image", attribute="color"},
    {id="zigguratPyramidInteractFight2Image", attribute="color"},
    {id="zigguratPyramidInteractFight3Image", attribute="color"},
	{id="zigguratPyramidInteractFight1Text", attribute="text"},
	{id="zigguratPyramidInteractFight2Text", attribute="text"},
	{id="zigguratPyramidInteractFight3Text", attribute="text"},
	{id="zigguratPyramidInteractText1", attribute="text"},
	{id="zigguratPyramidInteractText2", attribute="text"},
	{id="zigguratPyramidInteractClimb1Text", attribute="text"},
	{id="zigguratPyramidInteractClimb2Text", attribute="text"}}
function saveZigguratPyramidUI()
    if gStates==nil then return end
    gStates.zigguratPyramidUI={}
    for _, details in ipairs(zigguratPyramidUISaveAttributes) do
        gStates.zigguratPyramidUI[details.id.."|"..details.attribute]=UI.getAttribute(details.id, details.attribute)
    end
end
function restoreZigguratPyramidUI()
    if gStates==nil or gStates.zigguratPyramidUI==nil then return end
    for _, details in ipairs(zigguratPyramidUISaveAttributes) do
        local value=gStates.zigguratPyramidUI[details.id.."|"..details.attribute]
        if value~=nil then UI.setAttribute(details.id, details.attribute, value)
        end
    end
end

--city pickup warning.
function __onObjectPickUp_raw(player_color, picked_up_object)
	puppetMasterTrackPickup(player_color,picked_up_object)
	--Unlocking and lifting an active Destroyed token undoes that placement without awarding a restoration.
	if player_color~=nil and picked_up_object.getGMNotes()=="Destroyed" and gStates.destroyedSites~=nil and gStates.destroyedSites[picked_up_object.guid]~=nil then
		if undoDestroyedSitePlacement(picked_up_object)==true then
			broadcastToAll("Destroyed Site placement undone")
			fakeDropAvatar()
		end
	end
	if 	picked_up_object.guid==cityModel.blue or
		picked_up_object.guid==cityModel.red or
		picked_up_object.guid==cityModel.green or
		picked_up_object.guid==cityModel.white or
		picked_up_object.guid==volkare.terrainHex or
		picked_up_object.guid==darkCrusader.terrainHex or
		picked_up_object.guid==elementalist.terrainHex then
		broadcastToAll("{en}City Models are placed by the script. There is really no reason for a player to be manipulating them.\nInteract with the cities by using the city cards{ru}Модели городов размещаются по скрипту. Игрокам нет смысла их трогать.\nВзаимодействуйте с городами, используя карты городов{zh-cn}城市模型由脚本自动放置, 玩家不需手动干预{ko}도시 피규어는 스크립트에 의해 자동으로 처리됩니다. 직접 조작할 필요는 없습니다.\n도시 카드를 통해 상호작용 하시면 됩니다. {es}Los modelos de ciudad son colocados por el guión. Realmente no hay ninguna razón para que un jugador los manipule.\nInteractuar con las ciudades usando las tarjetas de la ciudad{fr}Les modèles de ville sont placés par le script. Il n'y a vraiment aucune raison pour qu'un joueur les manipule.\nInteragissez avec les villes en utilisant les cartes de ville{pt-br}Modelo das Cidades são colocadas no mapa pelo Script. Não há motivo para um jogador manipulá-las.\nInteraja com as cidades usando as cartas de cidade.{de}Die Stadtmodelle werden durch das Skript platziert. Es gibt wirklich keinen Grund für einen Spieler, sie zu manipulieren.\nInteragieren Sie mit den Städten, indem Sie die Stadtkarten benutzen", {1,1,0.5})
	end

	--Record where the current player's avatar was picked up. Cleanup waits until a human actually drops it on a new hex.
	for _, avatar in pairs(mageKnights) do
		if player_color~=nil and (picked_up_object.guid==avatar.model or picked_up_object.guid==avatar.standee or picked_up_object.guid==avatar.token) and turnOrder[gStates.turnNumber].mage==avatar.mage then
			playerPickedUpPos=picked_up_object.getPosition()
			playerPickedUpHex=avatarHexIdentity(playerPickedUpPos)
			--Avatar buttons describe the current hex. Remove them while the avatar is in transit so
			--the previous hex's controls cannot briefly reappear at the new location. Keep the XML
			--signature cache in sync with that physical clear so the settled drop is allowed to restore
			--an otherwise-identical button layout on the same hex.
			applyAvatarButtonXml(picked_up_object, {{}}, "empty")
			break
		end
	end
end

--blank Deck summary if not allowed to view
function __onObjectHover_raw(player_color, hover_object)
	--Make deck dsecription unreadable to other players
	if hover_object~=nil and hover_object.type=="Deck" and hover_object.getGMNotes()~=nil and hover_object.getGMNotes()~="" then
		if hover_object.getGMNotes()~=player_color and player_color~="Black" and gStates.coop==0 then
			hover_object.setDescription("Deck contents are only visible for this player.")
		end
	end

	--monster token tooltip update.
	if hover_object~=nil and (monsterPugs[hover_object.guid]~=nil or gStates.monsterPerks[hover_object.guid]~=nil) then
		local monsterDescription=""
		if hover_object.is_face_down==false then
			--Attack Descriptions
			--Trap Blurb
			if hover_object.getGMNotes()=="Trap Reminder Token" then
				monsterDescription="{en}(If flipped, this token will be removed when you Ascend)\n\n{ru}(Если этот жетон перевернуть, он будет удален при «Восхождении»)\n\n{zh-tw}（如果翻面，此標記會在你爬升至下一層時移除）\n\n{zh-cn}（如果翻面，此标记会在你爬升至下一层时移除）\n\n{ko}(뒤집은 함정 토큰은 다음 층 등반 시 제거)\n\n{es}(Si se da la vuelta a esta ficha, se retirará cuando asciendas)\n\n{fr}(Si cette carte est retournée, elle sera retirée lorsque vous atteindrez l'Ascension)\n\n{pt-br}(Se virada, esta ficha será removida quando você Ascender)\n\n{de}(Wenn diese Karte umgedreht wird, wird sie entfernt, sobald du aufsteigst)\n\n"
			end
			--Volkare Blurb
			if hover_object.getName()=="{en}Volkare Reminder Token{zh-cn}沃里卡提醒标记{ko}볼케어 공격 토큰{es}Token de recordatorio de Volkare{fr}Jeton de rappel Volkare{pt-br}Token de lembrete de Volkare" then
				monsterDescription="{en}He can't be attacked directly, but Volkare attacks along with his army.\n\nDefeat Volkare's Army and you Defeat General Volkare.\n\n{zh-cn}他不能直接被打败，但沃里卡随他的军队一起进攻。\n\n击败沃里卡的军队，你就打败了沃里卡将军。\n\n{ko}볼케어는 직접 처치될 수 없고, 대신 그의 군대와 함께 전투합니다.\n\n모든 군대를 처치하면 볼케어가 처치됩니다.\n\n{es}No puede ser derrotado directamente, pero Volkare ataca junto con su ejército.\n\nDerrota al ejército de Volkare y derrotarás al general Volkare.\n\n{fr}Il ne peut pas être vaincu directement, mais Volkare attaque avec son armée.\n\nBattez l'armée de Volkare et vous vaincrez le général Volkare.\n\n{pt-br}Ele não pode ser derrotado diretamente, mas Volkare ataca junto com seu exército.\n\nDerrote o Exército de Volkare e você derrota o General Volkare.\n\n"
			end
			--Leader Blurb
			if hover_object.guid==darkCrusader.token or hover_object.guid==elementalist.token then
				monsterDescription="{en}Faction Leaders are attacked and blocked in the same way as other enemies.\n\nDealing damage to beat the Leaders armour value will reduce his level by 1.\n\nYou may attack with enough damage to do multiple of the Leaders armour value and reduce his level more.\n\nThe leader will reduce level for the next fight if not reduced to zero level\n\n{ru}Лидеры фракций атакуются и блокируются так же, как и другие враги.\n\nНанесение урона, превышающего значение брони лидера, снизит его уровень на 1.\n\nВы можете нанести урон, превышающий значение брони лидера, и снизить его уровень еще больше.\n\nЛидер снизит уровень для следующего боя, если он не будет снижен до нуля.{zh-cn}派系首领的攻击与防御机制与其他敌人相同。\n\n造成超过首领护甲值的伤害可使其等级降低1级。\n\n若单次攻击伤害值达到首领护甲值的倍数，可使其等级多次递减。\n\n若首领未被降至零级，其等级将在下次战斗中继续递减。{ko}파벌 지도자는 다른 적과 동일한 방식으로 공격 및 차단됩니다.\n\n지도자의 방어력 수치를 초과하는 피해를 입히면 그의 레벨이 1 감소합니다.\n\n지도자의 방어력 수치보다 큰 피해를 입혀 레벨을 더 많이 감소시킬 수 있습니다.\n\n지도자의 레벨이 0이 되지 않은 경우, 다음 전투에서 레벨이 감소합니다.{es}Los líderes de facción son atacados y bloqueados de la misma manera que otros enemigos.\n\nInfligir daño que supere el valor de armadura del líder reducirá su nivel en 1.\n\nPuedes atacar con suficiente daño como para superar varias veces el valor de armadura del líder y reducir aún más su nivel.\n\nEl líder reducirá su nivel para la siguiente lucha si no se reduce a cero.{fr}Les chefs de faction sont attaqués et bloqués de la même manière que les autres ennemis.\n\nInfliger des dégâts supérieurs à la valeur d'armure du chef réduira son niveau de 1.\n\nVous pouvez attaquer en infligeant des dégâts supérieurs à la valeur d'armure du chef et réduire davantage son niveau.\n\nLe chef réduira son niveau pour le prochain combat s'il n'est pas réduit à zéro.{pt-br}Os líderes das facções são atacados e bloqueados da mesma forma que outros inimigos.\n\nCausar danos que superem o valor da armadura do líder reduzirá o seu nível em 1.\n\nPode atacar com danos suficientes para causar múltiplos do valor da armadura do líder e reduzir ainda mais o seu nível.\n\nO líder reduzirá o nível para a próxima luta se não for reduzido ao nível zero.{de}Fraktionsanführer werden genauso angegriffen und geblockt wie andere Gegner. \n\nWenn du Schaden verursachst, der den Rüstungswert des Anführers übersteigt, sinkt sein Level um 1. \n\nDu kannst mit ausreichend Schaden angreifen, um den Rüstungswert des Anführers mehrfach zu übertreffen und sein Level weiter zu senken. \n\nDer Anführer senkt sein Level für den nächsten Kampf, wenn es nicht auf Null gesunken ist. \n\n"
			end
			--Airborne Dragon attacks reuse the normal attack/ability renderer, but the heads are attackers only:
			--no Armour/resistance data is registered and the displayed Fame is the single Round reward.
			local airbornePerks=gStates.monsterPerks~=nil and gStates.monsterPerks[hover_object.guid] or nil
			if airbornePerks~=nil and airbornePerks.dragonAirborne==true then
				local airborneRound=tonumber(airbornePerks.dragonAirborneRound) or tonumber(gStates.currentRound) or 1
				monsterDescription=joinLang({monsterDescription,"{en}[ffda00]AIRBORNE DRAGON ATTACK — ROUND ",tostring(airborneRound),"[-]\n[i]This head is only attacking; it cannot be attacked or defeated in this combat. Flip the chosen heads face down if you are site fortified.[/i]\n\n[00ff00]DRAGON ATTACK REWARD: [-]",tostring(airborneRound)," Fame\n\n"})
			end
			--Horseman priorities. Combat stats/abilities below continue through the normal monster hover renderer.
			local horsemanName=horsemanTokenToName~=nil and horsemanTokenToName[hover_object.guid] or nil
			if horsemanName~=nil then monsterDescription=joinLang({monsterDescription,"{en}"..horsemanPriorityDescription(horsemanName)}) end
			--Night Rules
			if gStates.monsterPerks[hover_object.guid]~=nil and gStates.monsterPerks[hover_object.guid].nightRules~=nil and gStates.summonStates[hover_object.guid]~="summoned" then monsterDescription=joinLang({monsterDescription, "{en}[00ff00]NIGHT RULES[-][i] - For this fight, Gold mana can't be used, Black mana can be used, and affected Skills use their night version.[/i]\n\n{ru}[00ff00]НОЧНЫЕ ПРАВИЛА[-][i] - Считайте, что битва проходит ночью: нельзя использовать золотую ману, можно использовать черную ману, а навыки используют свою ночную версию.[/i]\n\n{zh-cn}[00ff00]夜晚規則[-][i] - 在這場戰鬥中，金色法力不能使用，黑色法力可以使用，受影響的技能使用其夜間版本。[/i]\n\n{ko}[00ff00]밤 규칙[-][i] - 이 전투에서 금색 마나를 사용할 수 없고, 흑색 마나를 사용할 수 있으며, 스킬 또한 밤 효과로 사용합니다.[/i]\n\n{es}[00ff00]REGLAS NOCTURNAS[-][i] - Para este combate, no se puede usar Maná Dorado, se puede usar Maná Negro y las Habilidades afectadas usan su versión nocturna.[/i]\n\n{fr}[00ff00]RÈGLES DE LA NUIT[-][i] - Pour ce combat, le mana d'or ne peut pas être utilisé, le mana noir peut être utilisé et les compétences affectées utilisent leur version nocturne.[/i]\n\n{pt-br}[00ff00]REGRAS NOTURNAS[-][i] - Nesta luta, a mana dourada não pode ser usada, a mana preta pode ser usada e as habilidades afetadas usam sua versão noturna.[/i]\n\n{de}[00ff00]REGELN FÜR DIE NACHT[-][i] - Für diesen Kampf kann kein Goldmana verwendet werden, Schwarzmana kann verwendet werden, und die betroffenen Fertigkeiten verwenden ihre Nachtversion.[/i]\n\n"}) end
			--No Units
			if gStates.monsterPerks[hover_object.guid]~=nil and gStates.monsterPerks[hover_object.guid].noUnits~=nil and gStates.summonStates[hover_object.guid]~="summoned" then monsterDescription=joinLang({monsterDescription, "{en}[00ff00]NO UNITS[-][i] - No Units can be used for this Fight.[/i]\n\n{ru}[00ff00]БЕЗ ОТРЯДОВ[-][i] - В этом бою герой не может использовать отряды.[/i]\n\n{zh-cn}[00ff00]禁用部队[-][i] - 本次战斗不能使用任何部队。[/i]\n\n{ko}[00ff00]유닛 사용불가[-][i] - 이 전투에는 유닛을 사용할 수 없습니다.[/i]\n\n{es}[00ff00]SIN UNIDADES[-][i] - No se pueden utilizar unidades para este combate.[/i]\n\n{fr}[00ff00]PAS D'UNITÉS[-][i] - Aucune unité ne peut être utilisée pour ce combat.[/i]\n\n{pt-br}[00ff00]SEM UNIDADES[-][i] - Nenhuma unidade pode ser usada para essa luta.[/i]\n\n{de}[00ff00]KEINE EINHEITEN[-][i] - Für diesen Kampf können keine Einheiten verwendet werden.[/i]\n\n"}) end
			--One Unit
			if gStates.monsterPerks[hover_object.guid]~=nil and gStates.monsterPerks[hover_object.guid].oneUnit~=nil and gStates.summonStates[hover_object.guid]~="summoned" then monsterDescription=joinLang({monsterDescription, "{en}[00ff00]ONE UNIT[-][i] - Only one Unit can be used for this Fight[/i]\n\n{ru}[00ff00]ОДИН ОТРЯД[-][i] - В этом бою герой может использовать только один отряд.[/i]\n\n{zh-cn}[00ff00]单个部队[-][i] - 本场比赛只能使用一个部队。[/i]\n\n{ko}[00ff00]유닛 하나[-][i] - 이 전투에는 유닛 하나만 사용할 수 있습니다.[/i]\n\n{es}[00ff00]UNA UNIDAD[-][i] - Sólo se puede utilizar una unidad para este combate.[/i]\n\n{fr}[00ff00]UNE UNITÉ[-][i] - Une seule unité peut être utilisée pour ce combat.[/i]\n\n{pt-br}[00ff00]UMA UNIDADE[-][i] - Somente uma unidade pode ser usada para essa luta.[/i]\n\n{de}[00ff00]EINE EINHEIT[-][i] - Für diesen Kampf kann nur eine Einheit verwendet werden.[/i]\n\n"}) end
			--Attack values
			if ((monsterPugs[hover_object.guid]~=nil and monsterPugs[hover_object.guid].attack~=nil and monsterPugs[hover_object.guid].monsters==nil) or (gStates.monsterPerks[hover_object.guid]~=nil and gStates.monsterPerks[hover_object.guid].attack~=nil)) then
				local attackTypeConvert={
					["P"]="{en}[00ff00]PHYSICAL ATTACK: [-]{ru}[00ff00]ФИЗИЧЕСКАЯ АТАКА: [-]{zh-cn}[00ff00]物理攻击：[-]{ko}[00ff00]물리 공격: [-]{es}[00ff00]ATAQUE FÍSICO: [-]{fr}[00ff00]ATTAQUE PHYSIQUE : [-]{pt-br}[00ff00]ATAQUE FÍSICO: [-]{de}[00ff00]PHYSISCHER ANGRIFF: [-]",
					["F"]="{en}[ff0000]FIRE ATTACK: [-]{ru}[ff0000]ОГНЕННАЯ АТАКА: [-]{zh-cn}[ff0000]火焰攻击：[-]{ko}[ff0000]불 공격: [-]{es}[ff0000]ATAQUE DE FUEGO: [-]{fr}[ff0000]ATTENTAT DE FEU : [-]{pt-br}[ff0000]ATAQUE DE FOGO: [-]{de}[ff0000]FEUERANSCHLAG: [-]",
					["I"]="{en}[5a5aff]ICE ATTACK: [-]{ru}[5a5aff]ЛЕДЯНАЯ АТАКА: [-]{zh-cn}[5a5aff]寒冰攻击：[-]{ko}[5a5aff]얼음 공격: [-]{es}[5a5aff]ATAQUE DE HIELO: [-]{fr}[5a5aff]ATTAQUE DE GLACE : [-]{pt-br}[5a5aff]ATAQUE DE GELO: [-]{de}[5a5aff]EIS-ATTACK: [-]",
					["M"]="{en}[ffda00]PSYCHIC ATTACK: [-]{ru}[ffda00]ПСИХИЧЕСКОЕ НАПАДЕНИЕ: [-]{zh-tw}[ffda00]心靈攻擊：[-]{zh-cn}[ffda00]心灵攻击：[-]{ko}[ffda00]정신 공격: [-]{es}[ffda00]ATAQUE PSÍQUICO: [-]{fr}[ffda00]ATTAQUE PSYCHIQUE : [-]{pt-br}[ffda00]ATAQUE PSÍQUICO: [-]{de}[ffda00]PSYCHISCHER ANGRIFF: [-]",
					["IF"]="{en}[ff00fe]COLD FIRE ATTACK: [-]{ru}[ff00fe]ОГНЕННО-ЛЕДЯНАЯ АТАКА: [-]{zh-cn}[ff00fe]冰火攻击：[-]{ko}[ff00fe]차가운불 공격: [-]{es}[ff00fe]ATAQUE DE FUEGO FRÍO: [-]{fr}[ff00fe]ATTENTAT DE FEU FROID : [-]{pt-br}[ff00fe]ATAQUE DE FOGO FRIO: [-]{de}[ff00fe]KALTER FEUERANSCHLAG: [-]"}
				local attackTypeDescription={
					["F"]="{en}(Your Physical and Fire Blocks are halved){ru}(Значения Физических и Огненных блоков делятся на 2, с округлением вниз){zh-cn}（您的物理和火焰属性减半）{ko}(물리 및 불 방어가 절반으로 감소합니다.){es}(Tus Bloques Físicos y de Fuego se reducen a la mitad){fr}(Vos blocs de physique et de feu sont réduits de moitié){pt-br}(Seus bloqueios Físico e de Fogo são reduzidos à metade){de}(Deine Physikalischen und Feuer-Blöcke werden halbiert)",
					["I"]="{en}(Your Physical and Ice Blocks are halved){ru}(Значения Физических и Ледяных блоков делятся на 2, с округлением вниз){zh-cn}（您的物理和寒冰属性减半）{ko}(물리 및 얼음 방어가 절반으로 감소합니다.){es}(Tus Bloques Físicos y de Hielo se reducen a la mitad){fr}(Vos blocs de physique et de glace sont divisés par deux){pt-br}(Seus bloqueios Físico e de Gelo são reduzidos à metade){de}(Ihre physischen und Eis-Blöcke werden halbiert)",
					["M"]="{en}(All your Blocks are halved. Influence points may be spent as full Psychic Block){ru}(Все ваши блоки уменьшаются вдвое. Очки влияния можно тратить как полноценный психический блок){zh-tw}（你所有的格檔效果減半，影響力可以完全轉換成心靈格檔）{zh-cn}（你所有的格档效果减半，影响力可以完全转换成心灵格档）{ko}(모든 방어 수치가 절반으로 감소. 영향력을 지불하여 온전한 정신 방어로 사용 가능){es}(Todos tus bloqueos se reducen a la mitad. Los puntos de influencia se pueden gastar como un bloqueo psíquico completo){fr}(Tous vos blocages sont réduits de moitié. Les points d'influence peuvent être utilisés pour obtenir un blocage psychique complet.){pt-br}(Todos os seus bloqueios são reduzidos pela metade. Os pontos de influência podem ser usados como um bloqueio psíquico completo){de}(Alle deine Blöcke werden halbiert. Einflusspunkte können als vollständiger psychischer Block ausgegeben werden.)",
					["IF"]="{en}(Your Physical, Fire and Ice Blocks are halved){ru}(Значения Физических, Ледяных и Огненных блоков делятся на 2, с округлением вниз){zh-cn}（你的物理、火焰和寒冰格挡减半）{ko}(물리, 불, 얼음 방어가 절반으로 감소합니다.){es}(Tus Bloques Físico, Fuego y Hielo se reducen a la mitad){fr}(Vos blocs de physique, de feu et de glace sont réduits de moitié){pt-br}(Seus bloqueios Físico, de Fogo e de Gelo são reduzidos à metade){de}(Deine Physischen, Feuer- und Eis-Blöcke werden halbiert)"}
				--this method works as Volkare token, Trap Tokens and Possessed tokens don't overlap they're damage types. Suspect in future I may need to add the two.
				local boostDone=false
				for attackType, _ in pairs(attackTypeConvert) do
					if (monsterPugs[hover_object.guid]~=nil and monsterPugs[hover_object.guid].attack~=nil and monsterPugs[hover_object.guid].attack[attackType]~=nil) or
						(gStates.monsterPerks[hover_object.guid]~=nil and gStates.monsterPerks[hover_object.guid].attack~=nil and gStates.monsterPerks[hover_object.guid].attack[attackType]~=nil) then
						local elementalBonus=0
						if gStates.monsterPerks[hover_object.guid]~=nil and gStates.monsterPerks[hover_object.guid].elemental~=nil then if attackType=="IF" then elementalBonus=1 else elementalBonus=2 end end
						local damageToScan={}--monsterPugs[hover_object.guid].attack[attackType]
						if monsterPugs[hover_object.guid]~=nil and monsterPugs[hover_object.guid].attack~=nil and monsterPugs[hover_object.guid].attack[attackType]~=nil then damageToScan=monsterPugs[hover_object.guid].attack[attackType] end
						if gStates.monsterPerks[hover_object.guid]~=nil and gStates.monsterPerks[hover_object.guid].attack~=nil and gStates.monsterPerks[hover_object.guid].attack[attackType]~=nil then damageToScan=gStates.monsterPerks[hover_object.guid].attack[attackType] end
						for count, v in pairs(damageToScan) do
							local boost=0
							if count==1 and boostDone==false and gStates.monsterPerks[hover_object.guid]~=nil and gStates.monsterPerks[hover_object.guid].boost~=nil then boost=gStates.monsterPerks[hover_object.guid].boost boostDone=true end
							monsterDescription=joinLang({monsterDescription, attackTypeConvert[tostring(attackType)], tostring(v+elementalBonus+boost), "\n"})
						end
						if tostring(attackType)~="P" and hover_object.getGMNotes()~="Puppet Master" then monsterDescription=joinLang({monsterDescription, "[i]", attackTypeDescription[tostring(attackType)], "[/i]\n"}) end
					end
				end
			end
			--Block values. Puppet Master uses this generic monsterPerks field so kept tokens can reuse
			--the normal hover system without pretending the Puppet is still an enemy.
			if gStates.monsterPerks[hover_object.guid]~=nil and type(gStates.monsterPerks[hover_object.guid].block)=="table" then
				--Puppets only show their usable Attack and Block values. Put the visual separator
				--between those groups instead of leaving an empty line at the bottom of the tooltip.
				if hover_object.getGMNotes()=="Puppet Master" then monsterDescription=joinLang({monsterDescription, "\n"}) end
				local blockTypeConvert={
					["P"]="{en}[00ff00]PHYSICAL BLOCK: [-]{ru}[00ff00]ФИЗИЧЕСКИЙ БЛОК: [-]{zh-cn}[00ff00]物理格挡：[-]{ko}[00ff00]물리 방어: [-]{es}[00ff00]BLOQUEO FÍSICO: [-]{fr}[00ff00]BLOC PHYSIQUE : [-]{pt-br}[00ff00]BLOQUEIO FÍSICO: [-]{de}[00ff00]PHYSISCHER BLOCK: [-]",
					["F"]="{en}[ff0000]FIRE BLOCK: [-]{ru}[ff0000]ОГНЕННЫЙ БЛОК: [-]{zh-cn}[ff0000]火焰格挡：[-]{ko}[ff0000]불 방어: [-]{es}[ff0000]BLOQUEO DE FUEGO: [-]{fr}[ff0000]BLOC DE FEU : [-]{pt-br}[ff0000]BLOQUEIO DE FOGO: [-]{de}[ff0000]FEUER-BLOCK: [-]",
					["I"]="{en}[5a5aff]ICE BLOCK: [-]{ru}[5a5aff]ЛЕДЯНОЙ БЛОК: [-]{zh-cn}[5a5aff]寒冰格挡：[-]{ko}[5a5aff]얼음 방어: [-]{es}[5a5aff]BLOQUEO DE HIELO: [-]{fr}[5a5aff]BLOC DE GLACE : [-]{pt-br}[5a5aff]BLOQUEIO DE GELO: [-]{de}[5a5aff]EIS-BLOCK: [-]",
					["M"]="{en}[ffda00]PSYCHIC BLOCK: [-]{ru}[ffda00]ПСИХИЧЕСКИЙ БЛОК: [-]{zh-tw}[ffda00]心靈格檔：[-]{zh-cn}[ffda00]心灵格挡：[-]{ko}[ffda00]정신 방어: [-]{es}[ffda00]BLOQUEO PSÍQUICO: [-]{fr}[ffda00]BLOC PSYCHIQUE : [-]{pt-br}[ffda00]BLOQUEIO PSÍQUICO: [-]{de}[ffda00]PSYCHISCHER BLOCK: [-]",
					["IF"]="{en}[ff00fe]COLD FIRE BLOCK: [-]{ru}[ff00fe]ОГНЕННО-ЛЕДЯНОЙ БЛОК: [-]{zh-cn}[ff00fe]冰火格挡：[-]{ko}[ff00fe]차가운불 방어: [-]{es}[ff00fe]BLOQUEO DE FUEGO FRÍO: [-]{fr}[ff00fe]BLOC DE FEU FROID : [-]{pt-br}[ff00fe]BLOQUEIO DE FOGO FRIO: [-]{de}[ff00fe]KALTFEUER-BLOCK: [-]"}
				for _, blockType in ipairs({"P","F","I","IF","M"}) do
					local values=gStates.monsterPerks[hover_object.guid].block[blockType]
					if type(values)=="table" then for _, value in ipairs(values) do monsterDescription=joinLang({monsterDescription,blockTypeConvert[blockType],tostring(value),"\n"}) end end
				end
			end
			--summoners
			if monsterPugs[hover_object.guid]~=nil and monsterPugs[hover_object.guid].monsters~=nil and monsterPugs[hover_object.guid].pugType~="yellow" then
				local count=0
				for _, summon in pairs(monsterPugs[hover_object.guid].monsters) do count=count+1 end
				if count>1 then
					monsterDescription=joinLang({monsterDescription, "{en}[00ff00]ENEMY SUMMONS: [-]{ru}[00ff00]ПРИЗЫВ: [-]{zh-cn}[00ff00]敌人召唤：[-]{ko}[00ff00]적 소환수: [-]{es}[00ff00]CONVOCATORIA ENEMIGA: [-]{fr}[00ff00]SOMMES ENNEMIES: [-]{pt-br}[00ff00]CONVOCAÇÕES INIMIGAS: [-]{de}[00ff00]ENEMY SUMMONS: [-]", tostring(count), "\n"})
				else
					monsterDescription=joinLang({monsterDescription, "{en}[00ff00]ENEMY SUMMON: [-]1\n{ru}[00ff00]ПРИЗЫВ: [-]1\n{zh-cn}[00ff00]敌人召唤：[-]1\n{ko}[00ff00]적 소환수: [-]1\n{es}[00ff00]CONVOCATORIA ENEMIGA: [-]1\n{fr}[00ff00]SOMME DE L'ENNEMI : [-]1\n{pt-br}[00ff00]CONVOCAÇÃO DO INIMIGO: [-]1\n{de}[00ff00]Feindlicher SUMMON: [-]1\n"})
				end
			end
			--ruins
			if monsterPugs[hover_object.guid]~=nil and monsterPugs[hover_object.guid].monsters~=nil and monsterPugs[hover_object.guid].pugType=="yellow" and hover_object.guid~="f3c6e3" and hover_object.guid~="28cc9c" and hover_object.guid~="2f9a1f" then
				colorConvert={
					["gray"]="{en}Keep Garison (Gray){ru}Гарнизон крепости (Серый){zh-cn}要塞守军（灰色）{ko}성 수비대 (회색){es}Mantener Garison (Gris){fr}Garder Garison (Gris){pt-br}Forte Guarnição (Cinza){de}Garison behalten (Grau)",
					["tan"]="{en}Dungeon Monster (Tan){ru}Монстр из подземелья (Коричневый){zh-cn}地下城怪物（棕色）{ko}던전 몬스터 (갈색){es}Monstruo de Mazmorra (Marrón){fr}Monstre du donjon (Tan){pt-br}Monstro de Masmorra (Bronze){de}Kerkermonster (Braun)",
					["green"]="{en}Maraudering Orcs (Green){ru}Орк-мародер (Зеленый){zh-cn}兽人劫掠队（绿色）{ko}오크 습격자 (녹색){es}Orkos Merodeadores (Verde){fr}Orques maraudeurs (Vert){pt-br}Orks saqueadores (Verde){de}Marodierende Orks (Grün)",
					["red"]="{en}Draconum (Red){ru}Драконум (красный){zh-tw}龍族（紅色）{zh-cn}龙族（红色）{ko}드라코넘 (적색){es}Draconum (Rojo){fr}Draconum (Rouge){pt-br}Draconum (Vermelho){de}Draconum (Rot)",
					["purple"]="{en}Mage Tower Garison (Purple){ru}Гарнизон башни магов (Фиолетовый){zh-cn}法师塔守军（紫色）{ko}마법사 탑 수비대 (보라색){es}Torre de Mago Garison (Morado){fr}Tour des mages Garison (Violet){pt-br}Guarnição da Torre do Mago (Roxo){de}Magierturm Garison (Violett)",
					["white"]="{en}City Garison (white){ru}Гарнизон города (Белый){zh-cn}城市守军（白色）{ko}도시 수비대 (흰색){es}Ciudad Garison (Blanco){fr}Garison de la ville (Blanc){pt-br}Guarnição da cidade (Branco){de}Stadt Garison (Weiß)"}
				monsterDescription=joinLang({monsterDescription, "{en}[00ff00]ENEMIES DEFENDING: [-]One {ru}[00ff00]ОХРАНА: [-]Один {zh-cn}[00ff00]防守的敌人：[-]一个{ko}[00ff00]방어 중인 적: [-]1개의 {es}[00ff00]ENEMIGOS DEFENDIENDO: [-]Uno {fr}[00ff00]ENNEMIS EN DÉFENSE : [-]Un {pt-br}[00ff00]INIMIGOS DEFENDENDO: [-]Um {de}[00ff00]ENEMIES DEFENDING: [-]Einer ", colorConvert[monsterPugs[hover_object.guid].monsters[1]], "{en} and one {ru} и один {zh-cn}和一个{ko} 그리고 1개의 {es} y uno {fr} et un {pt-br} e um {de} und einer ", colorConvert[monsterPugs[hover_object.guid].monsters[2]], "{en}.\n{zh-cn}。\n"})
			end
			if hover_object.guid=="f3c6e3" then monsterDescription=joinLang({monsterDescription, "{en}[00ff00]ENEMIES DEFENDING: [-]Two Maraudering Orcs(Green).\n{ru}[00ff00]ОХРАНА: [-]Два Орка-мародер (Зеленый).\n{zh-cn}[00ff00]驻守敌人：[-]两个兽人劫掠队（绿色）。\n{ko}[00ff00]방어 중인 적: [-]2개의 오크(녹색).\n{es}[00ff00]ENEMIGOS DEFENDIENDO: [-]Dos Orkos Merodeadores(Verde).\n{fr}[00ff00]ENNEMIES DEFENDANTS : [-]Deux Orks maraudeurs (vert).\n{pt-br}[00ff00]INIMIGOS DEFENDENDO: [-]Dois Orks saqueadores(verde).\n{de}[00ff00]ENEMIES DEFENDING: [-]Zwei marodierende Orks(grün).\n"}) end
			if hover_object.guid=="28cc9c" then monsterDescription=joinLang({monsterDescription, "{en}[00ff00]ENEMIES DEFENDING: [-]Two Mage Tower Garisons(Purple).\n{ru}[00ff00]ОХРАНА: [-]Два Гарнизона башни магов (Фиолетовый).\n{zh-cn}[00ff00]驻守敌人：[-]两个法师塔守军（紫色）。\n{ko}[00ff00]방어 중인 적: [-]2개의 마법사 탑 수비대(보라색).\n{es}[00ff00]ENEMIGOS DEFENDIENDO: [-]Dos Mage Tower Garisons(Purple).\n{fr}[00ff00]ENEMIS EN DEFENSE : [-]Deux Garisons de la Tour des Mages (Pourpre).\n{pt-br}[00ff00]INIMIGOS DEFENDENDO: [-]Duas Guarnições da Torre do Mago (Roxo).\n{de}[00ff00]ENEMIES DEFENDING: [-]Zwei Magierturm-Garisons(Lila).\n"}) end
			if hover_object.guid=="2f9a1f" then monsterDescription=joinLang({monsterDescription, "{en}[00ff00]ENEMIES DEFENDING: [-]Three Maraudering Orcs(Green).\n{ru}[00ff00]ОХРАНА: [-]Три Орка-мародер (Зеленый).\n{zh-cn}[00ff00]驻守敌人：[-]三个兽人劫掠队（绿色）。\n{ko}[00ff00]방어 중인 적: [-]3개의 오크(녹색).\n{es}[00ff00]ENEMIGOS DEFENDIENDO: [-]Tres Orkos Merodeadores(Verde).\n{fr}[00ff00]ENEMIS EN DEFENSE : [-]Trois Orks maraudeurs(Vert).\n{pt-br}[00ff00]INIMIGOS DEFENDENDO: [-]Três Orcs Saqueadores(Verde).\n{de}[00ff00]ENEMIES DEFENDING: [-]Drei marodierende Orks(Grün).\n"}) end
			if monsterPugs[hover_object.guid]~=nil and monsterPugs[hover_object.guid].required~=nil then monsterDescription=joinLang({monsterDescription, "{en}[00ff00]ALTER REQUIRES: [-]{ru}[00ff00]ПОДНОШЕНИЕ АЛТАРЮ: [-]{zh-cn}[00ff00]改变要求：[-]{ko}[00ff00]재단 활성화: [-]{es}[00ff00]ALTER REQUIRE: [-]{fr}[00ff00]ALTER REQUIRES : [-]{pt-br}[00ff00]ALTERAR REQUISITOS: [-]{de}[00ff00]ALTER ERFORDERT: [-]", monsterPugs[hover_object.guid].required, "{en}.\n{zh-cn}。\n"}) end
			if hover_object.getGMNotes()~="Puppet Master" then monsterDescription=joinLang({monsterDescription, "\n"}) end
			if monsterPugs[hover_object.guid]~=nil and monsterPugs[hover_object.guid].reward~=nil and monsterPugs[hover_object.guid].pugType=="yellow" then monsterDescription=joinLang({monsterDescription, "{en}[00ff00]REWARD FOR DEFEATING: [-]{ru}[00ff00]НАГРАДА ЗА ПОБЕДУ: [-]{zh-cn}[00ff00]击败奖励：[-]{ko}[00ff00]정복 보상: [-]{es}[00ff00]RECOMPENSA POR DERROTA: [-]{fr}[00ff00]RÉCOMPENSE POUR LA DÉFENSE : [-]{pt-br}[00ff00]RECOMPENSA PELA DEFESA: [-]{de}[00ff00]BELOHNUNG FÜR DIE BESIEGUNG: [-]", monsterPugs[hover_object.guid].reward, "{en}.{zh-cn}。"}) end
			--swiftness
			if (monsterPugs[hover_object.guid]~=nil and monsterPugs[hover_object.guid].swiftness~=nil) or (gStates.monsterPerks[hover_object.guid]~=nil and gStates.monsterPerks[hover_object.guid].swiftness~=nil) then monsterDescription=joinLang({monsterDescription, "{en}[00ff00]SWIFTNESS[-][i] - This enemy's attack is doubled when trying to Block it.[/i]\n\n{ru}[00ff00]БЫСТРАЯ АТАКА[-][i] - Блокирование атаки врага требует вдвое больше очков блока, чем обычно.[/i]\n\n{zh-cn}[00ff00]迅捷[-][i] - 当试图阻挡敌人时，该敌人的攻击力会加倍。[/i]\n\n{ko}[00ff00]신속[-][i] - 이 공격을 방어할 때는 두 배의 수치가 필요.[/i]\n\n{es}[00ff00]VELOCIDAD[-][i] - El ataque de este enemigo se duplica al intentar Bloquearlo[/i]\n\n{fr}[00ff00]SOUPLESSE[-][i] - L'attaque de cet ennemi est doublée lorsque l'on tente de le bloquer.[/i]\n\n{pt-br}[00ff00]AGILIDADE[-][i] - O ataque deste inimigo é dobrado ao tentar bloqueá-lo.[/i]\n\n{de}[00ff00]GESCHWINDIGKEIT[-][i] - Der Angriff dieses Gegners wird verdoppelt, wenn man versucht, ihn zu blocken.[/i]\n\n"}) end
			--cumbersome
			if (monsterPugs[hover_object.guid]~=nil and monsterPugs[hover_object.guid].cumbersome~=nil) or (gStates.monsterPerks[hover_object.guid]~=nil and gStates.monsterPerks[hover_object.guid].cumbersome~=nil) then monsterDescription=joinLang({monsterDescription, "{en}[00ff00]CUMBERSOME[-][i] - This enemy's attack can be reduced by the amount of Move a player spends.[/i]\n\n{ru}[00ff00]НЕПОВОРОТЛИВЫЙ[-][i] - В фазе блока вы можете потратить очки Движения, уменьшив значение Атаки врага на 1 за каждое очко. Атака, уменьшенная до 0, успешно заблокирована.[/i]\n\n{zh-cn}[00ff00]笨重[-][i] - 该敌人的攻击力可以被玩家消耗的移动力减少。[/i]\n\n{ko}[00ff00]육중함[-][i] - 플레이어가 소비한 이동력만큼 이 적의 공격력이 감소.[/i]\n\n{es}[00ff00]CUMBERSOME[-][i] - El ataque de este enemigo puede ser reducido por la cantidad de Movimiento que gaste el jugador.[/i]\n\n{fr}[00ff00]CUMBERSOME[-][i] - L'attaque de cet ennemi peut être réduite par la quantité de Mouvement dépensée par le joueur.[/i]\n\n{pt-br}[00ff00]CORPULENTO-][i] - O ataque desse inimigo pode ser reduzido pela quantidade de movimento que o jogador gasta.[/i]\n\n{de}[00ff00]GESCHWINDIGKEIT[-][i] - Der Angriff dieses Gegners kann um die Menge an Bewegung reduziert werden, die ein Spieler ausgibt.[/i]\n\n"}) end
			--poison
			if (monsterPugs[hover_object.guid]~=nil and monsterPugs[hover_object.guid].poison~=nil) or (gStates.monsterPerks[hover_object.guid]~=nil and gStates.monsterPerks[hover_object.guid].poison~=nil) then monsterDescription=joinLang({monsterDescription, "{en}[00ff00]POISON[-][i] - The Player adds an extra wound to their discard pile for each wound from this enemy. Units get two wounds if taking a wound.[/i]\n\n{ru}[00ff00]ЯДОВИТАЯ АТАКА[-][i] - Отряд получает две карты ран вместо одной от атаки ядовитого врага. За каждую рану, полученную героем от этой атаки, он также кладет одну карту раны в свой сброс.[/i]\n\n{zh-cn}[00ff00]剧毒[-][i] - 此敌人每造成一次伤害，玩家就会在弃牌堆中额外增加一次伤害。如果受伤，单位会获得两个伤口。[/i]\n\n{ko}[00ff00]독성[-][i] - 이 적에게 받는 부상 하나당, 자신의 버린 카드 더미에 부상 하나를 추가. 유닛이 부상을 받을 경우 두 개를 받음.[/i]\n\n{es}[00ff00]VENENO[-][i] - El Jugador añade una herida extra a su pila de descartes por cada herida de este enemigo. Las unidades reciben dos heridas si reciben una herida.[/i]\n\n{fr}[00ff00]POISON[-][i] - Le joueur ajoute une blessure supplémentaire à sa pile de défausse pour chaque blessure infligée par cet ennemi.[/i]\n\n{pt-br}[00ff00]VENENO[-][i] - O jogador adiciona um ferimento extra à sua pilha de descarte para cada ferimento desse inimigo. As unidades recebem dois ferimentos se receberem um ferimento.[/i]\n\n{de}[00ff00]GIFT[-][i] - Der Spieler legt für jede Verwundung durch diesen Feind eine zusätzliche Wunde auf seinen Ablagestapel. Einheiten erhalten zwei Verwundungen, wenn sie eine Verwundung erleiden.[/i]\n\n"}) end
			--brutal
			if (monsterPugs[hover_object.guid]~=nil and monsterPugs[hover_object.guid].brutal~=nil) or (gStates.monsterPerks[hover_object.guid]~=nil and gStates.monsterPerks[hover_object.guid].brutal~=nil) then monsterDescription=joinLang({monsterDescription, "{en}[00ff00]BRUTAL[-][i] - This enemy's attack is doubled if not blocked.[/i]\n\n{ru}[00ff00]ЖЕСТОКАЯ АТАКА[-][i] - Если враг не заблокирован, он наносит вдвое больше урона, чем его значение Атаки.[/i]\n\n{zh-cn}[00ff00]残暴[-][i] - 如果没有被阻挡，这个敌人的攻击会加倍。[/i]\n\n{ko}[00ff00]난폭[-][i] - 방어하지 못하면, 공격력의 두 배만큼의 대미지를 받음.[/i]\n\n{es}[00ff00]BRUTAL[-][i] - El ataque de este enemigo se duplica si no es bloqueado.[/i]\n\n{fr}[00ff00]BRUTAL[-][i] - L'attaque de cet ennemi est doublée si elle n'est pas bloquée.[/i]\n\n{pt-br}[00ff00]BRUTAL[-][i] - O ataque desse inimigo é dobrado se não for bloqueado.[/i]\n\n{de}[00ff00]BRUTAL[-][i] - Der Angriff dieses Feindes wird verdoppelt, wenn er nicht geblockt wird.[/i]\n\n"}) end
			--vampiric
			if monsterPugs[hover_object.guid]~=nil and monsterPugs[hover_object.guid].vampiric~=nil then monsterDescription=joinLang({monsterDescription, "{en}[00ff00]VAMPIRIC[-][i] - Increase the armour of this enemy by the amount of wounds this enemy has dealt to the player and units.[/i]\n\n{ru}[00ff00]ВАМПИРИЗМ[-][i] - Броня врага с вампиризмом увеличивается на 1 до конца битвы каждый раз, когда в результате его атаки отряд получает рану или игрок берёт карту раны в руку.[/i]\n\n{zh-cn}[00ff00]吸血[-][i] - 增加该敌人的护甲，数值为该敌人对玩家和单位造成的伤害值。[/i]\n\n{ko}[00ff00]흡혈[-][i] - 이 적의 방어구가, 플레이어와 유닛에게 준 부상의 개수만큼 증가합니다.[/i]\n\n{es}[00ff00]VAMPÍRICO[-][i] - Aumenta la armadura de este enemigo por la cantidad de heridas que este enemigo haya infligido al jugador y a las unidades.[/i]\n\n{fr}[00ff00]VAMPIRIC[-][i] - Augmente l'armure de cet ennemi du nombre de blessures qu'il a infligées au joueur et à ses unités.[/i]\n\n{pt-br}[00ff00]VAMPÍRICO[-][i] - Aumenta a armadura desse inimigo pela quantidade de ferimentos que esse inimigo causou ao jogador e às unidades.[/i]\n\n{de}[00ff00]VAMPIRISCH[-][i] - Erhöht die Rüstung dieses Feindes um die Anzahl der Wunden, die dieser Feind dem Spieler und seinen Einheiten zugefügt hat.[/i]\n\n"}) end
			--Paralyse
			if (monsterPugs[hover_object.guid]~=nil and monsterPugs[hover_object.guid].paralyse~=nil) or (gStates.monsterPerks[hover_object.guid]~=nil and gStates.monsterPerks[hover_object.guid].paralyse~=nil) then monsterDescription=joinLang({monsterDescription, "{en}[00ff00]PARALYZE[-][i] - Player discards all non-wound cards when taking a wound from this enemy. Units are destroyed if taking a wound.[/i]\n\n{ru}[00ff00]ПАРАЛИЗУЮЩАЯ АТАКА[-][i] - Отряд, получивший рану от такой атаки, немедленно уничтожается. Если герой получает раны от такой атаки, управляющий им игрок немедленно сбрасывает с руки все карты, кроме карт ран.[/i]\n\n{zh-cn}[00ff00]瘫痪[-][i] - 玩家在受到该敌人的伤害时会丢弃所有非受伤的牌。如果受伤，单位将被摧毁。[/i]\n\n{ko}[00ff00]마비[-][i] - 플레이어가 이 공격으로 한 장 이상의 부상을 받으면, 즉시 손에서 부상을 제외한 모든 카드를 버림. 부상을 받은 유닛은 게임에서 제거됨.[/i]\n\n{es}[00ff00]PARALYSE[-][i] - El jugador descarta todas las cartas no heridas al recibir una herida de este enemigo. Las unidades son destruidas si reciben una herida.[/i]\n\n{fr}[00ff00]PARALYSE[-][i] - Le joueur défausse toutes les cartes non blessées lorsqu'il est blessé par cet ennemi. Les unités sont détruites si elles subissent une blessure.[/i]\n\n{pt-br}[00ff00]PARALISIA[-][i] - O jogador descarta todas as cartas não feridas ao receber um ferimento desse inimigo. As unidades são destruídas se receberem um ferimento.[/i]\n\n{de}[00ff00]PARALYSE[-][i] - Der Spieler wirft alle Karten ab, die nicht verwundet sind, wenn er eine Verwundung durch diesen Feind erleidet. Einheiten werden zerstört, wenn sie eine Verwundung erleiden.[/i]\n\n"}) end
			--assassination
			if (monsterPugs[hover_object.guid]~=nil and monsterPugs[hover_object.guid].assassination~=nil) or (gStates.monsterPerks[hover_object.guid]~=nil and gStates.monsterPerks[hover_object.guid].assassination~=nil) then monsterDescription=joinLang({monsterDescription, "{en}[00ff00]ASSASSINATION[-][i] - This enemy's attack damage can only be assigned to the player.[/i]\n\n{ru}[00ff00]НАЕМНЫЙ УБИЙЦА[-][i] - Урон от атаки врага не может быть распределён на отряды. Если враг не заблокирован, урон получает только герой.[/i]\n\n{zh-cn}[00ff00]刺杀[-][i] - 该敌人的攻击伤害只能分配给玩家。[/i]\n\n{ko}[00ff00]암살[-][i] - 이 적의 대미지는 유닛에게 할당 불가.[/i]\n\n{es}[00ff00]ASESINATO[-][i] - El daño de ataque de este enemigo sólo puede ser asignado al jugador.[/i]\n\n{fr}[00ff00]ASSASSINATION[-][i] - Les dégâts d'attaque de cet ennemi ne peuvent être attribués qu'au joueur.[/i]\n\n{pt-br}[00ff00]ASSASSINATO[-][i] - O dano de ataque desse inimigo só pode ser atribuído ao jogador.[/i]\n\n{de}[00ff00]ASSASSINATION[-][i] - Der Angriffsschaden dieses Feindes kann nur dem Spieler zugewiesen werden.[/i]\n\n"}) end
			if gStates.summonStates[hover_object.guid]~="summoned" then
				--armour
				local bonus=0
				if gStates.monsterPerks[hover_object.guid]~=nil and gStates.monsterPerks[hover_object.guid].armour~=nil then bonus=gStates.monsterPerks[hover_object.guid].armour end
				if monsterPugs[hover_object.guid]~=nil and monsterPugs[hover_object.guid].armour~=nil and monsterPugs[hover_object.guid].elusive==nil then monsterDescription=joinLang({monsterDescription, "{en}[00ff00]ARMOUR: [-]{ru}[00ff00]БРОНЯ: [-]{zh-cn}[00ff00]护甲：[-]{ko}[00ff00]방어구: [-]{es}[00ff00]ARMADURA: [-]{fr}[00ff00]ARMURE : [-]{pt-br}[00ff00] ARMADURA: [-]{de}[00ff00]RÜSTUNG: [-]", tostring(monsterPugs[hover_object.guid].armour+bonus), "\n\n"}) end
				if monsterPugs[hover_object.guid]~=nil and monsterPugs[hover_object.guid].armour~=nil and monsterPugs[hover_object.guid].elusive~=nil then monsterDescription=joinLang({monsterDescription, "{en}[00ff00]ARMOUR: [-]{ru}[00ff00]БРОНЯ: [-]{zh-cn}[00ff00]护甲：[-]{ko}[00ff00]방어구: [-]{es}[00ff00]ARMADURA: [-]{fr}[00ff00]ARMURE : [-]{pt-br}[00ff00] ARMADURA: [-]{de}[00ff00]RÜSTUNG: [-]", tostring(monsterPugs[hover_object.guid].armour+bonus), "[7b7b7b]/", tostring((monsterPugs[hover_object.guid].armour*2)+bonus), "[-]\n\n"}) end
				--Elusive
				if monsterPugs[hover_object.guid]~=nil and monsterPugs[hover_object.guid].elusive~=nil then monsterDescription=joinLang({monsterDescription, "{en}[00ff00]ELUSIVE[-][i] - This enemy's higher Armour value is used until successfully Blocked.[/i]\n\n{ru}[00ff00]НЕУЛОВИМЫЙ[-][i] - Меньшее значение брони используется только в фазе ближнего боя и только если все атаки этого врага были успешно заблокированы.[/i]\n\n{zh-cn}[00ff00]盾逸 [-][i]-该敌人的较高护甲值会被使用，直到成功阻挡。[/i]\n\n{ko}[00ff00]은밀함[-][i] - 이 공격을 성공적으로 방어하기 전 까지, 더 높은 방어구 수치를 적용.[/i]\n\n{es}[00ff00]ELUSIVO[-][i] - El valor de Armadura más alto de este enemigo se utiliza hasta que es Bloqueado con éxito.[/i]\n\n{fr}[00ff00]ELUSIVE[-][i] - La valeur d'armure la plus élevée de cet ennemi est utilisée jusqu'à ce qu'il soit bloqué avec succès.[/i]\n\n{pt-br}[00ff00]ELUSIVO[-][i] - O valor mais alto de Armadura desse inimigo é usado até que ele seja bloqueado com sucesso[/i]\n\n{de}[00ff00]ELUSIV[-][i] - Der höhere Rüstungswert dieses Gegners wird verwendet, bis er erfolgreich geblockt wird[/i]\n\n"}) end
				--defender
				if monsterPugs[hover_object.guid]~=nil and monsterPugs[hover_object.guid].defend~=nil then monsterDescription=joinLang({monsterDescription, "{en}[00ff00]DEFENDER[-][i] - The first enemy attacked by the player gets {ru}[00ff00]ПРИКРЫТИЕ[-][i] - Первый враг, атакованный игроком, получает {zh-cn}[00ff00]守护[-][i] - 第一个被玩家攻击的敌人会被增加护甲。{ko}[00ff00]수비[-][i] - 플레이어가 처음 공격하는 적에게{es}[00ff00]DEFENSOR[-][i] - El primer enemigo atacado por el jugador obtiene {fr}[00ff00]DEFENDER[-][i] - Le premier ennemi attaqué par le joueur voit son armure augmentée {pt-br}[00ff00]DEFENSOR[-][i] - O primeiro inimigo atacado pelo jogador recebe {de}[00ff00]VERTEIDIGER[-][i] - Der erste vom Spieler angegriffene Feind erhält ", monsterPugs[hover_object.guid].defend, "{en} added to its armour.[/i]\n\n{ru} к его броне.[/i]\n\n{zh-cn}增加其护甲。[/i]\n\n{ko}방어구를 추가.[/i]\n\n{es} se añade a su armadura.[/i]\n\n{fr}ajouté à son armure.[/i]\n\n{pt-br} adicionado à sua armadura.[/i]\n\n{de} zu seiner Rüstung hinzugefügt.[/i]\n\n"}) end
				--Fortified
				if (monsterPugs[hover_object.guid]~=nil and monsterPugs[hover_object.guid].fortified~=nil and (gStates.monsterPerks[hover_object.guid]==nil or (gStates.monsterPerks[hover_object.guid].fortified==nil and gStates.monsterPerks[hover_object.guid].wallFortified==nil))) or (monsterPugs[hover_object.guid]~=nil and monsterPugs[hover_object.guid].fortified==nil and gStates.monsterPerks[hover_object.guid]~=nil and gStates.monsterPerks[hover_object.guid].fortified~=nil) then monsterDescription=joinLang({monsterDescription, "{en}[00ff00]FORTIFIED[-][i] - This enemy can't be attacked with Ranged attacks in the Range phase.[/i]\n\n{ru}[00ff00]УКРЕПЛЕННЫЙ[-][i] - Во время фазы боя на расстоянии против врага можно играть только Осадные атаки.[/i]\n\n{zh-cn}[00ff00]城防[-][i] - 在远程攻击阶段，该敌人无法受到远程攻击。[/i]\n\n{ko}[00ff00]요새화[-][i] - 이 적을 원거리 단계에서 원거리 공격으로 공격할 수 없음.[/i]\n\n{es}[00ff00]FORTIFICADO[-][i] - Este enemigo no puede ser atacado con ataques a distancia en la fase de Alcance.[/i]\n\n{fr}[00ff00]FORTIFIÉ[-][i] - Cet ennemi ne peut pas être attaqué avec des attaques à distance lors de la phase de portée.[/i]\n\n{pt-br}[00ff00]FORTIFICADO[-][i] - Esse inimigo não pode ser atacado com ataques de longo alcance na fase de alcance[/i]\n\n{de}[00ff00]VERTEIDIGT[-][i] - Dieser Gegner kann in der Fernkampfphase nicht mit Fernkampfangriffen angegriffen werden.[/i]\n\n"}) end
				--double Fortified
				if monsterPugs[hover_object.guid]~=nil and monsterPugs[hover_object.guid].fortified~=nil and gStates.monsterPerks[hover_object.guid]~=nil and (gStates.monsterPerks[hover_object.guid].fortified~=nil or gStates.monsterPerks[hover_object.guid].wallFortified~=nil) then monsterDescription=joinLang({monsterDescription, "{en}[00ff00]DOUBLE FORTIFIED[-][i] - This enemy can't be attacked with Ranged or Siege attacks in the Range phase.[/i]\n\n{ru}[00ff00]ДВАЖДЫ УКРЕПЛЕННЫЙ[-][i] - Враг не может быть атакован во время фазы боя на расстоянии.[/i]\n\n{zh-cn}[00ff00]双重城防[-][i] - 在远程攻击阶段不能使用远程攻击或攻城攻击攻击该敌人。[/i]\n\n{ko}[00ff00]이중 요새화[-][i] - 이 적을 원거리 단계에서 원거리 공격이나 공성 공격으로 공격할 수 없음.[/i]\n\n{es}[00ff00]DOBLE FORTIFICADO[-][i] - Este enemigo no puede ser atacado con ataques a distancia o de asedio en la fase de alcance.[/i]\n\n{fr}[00ff00]DOUBLE FORTIFIÉ[-][i] - Cet ennemi ne peut pas être attaqué avec des attaques à distance ou de siège lors de la phase à distance.[/i]\n\n{pt-br}[00ff00]DUPLAMENTE FORTIFIED[-][i] - Esse inimigo não pode ser atacado com ataques de longo alcance ou de cerco na fase de alcance[/i]\n\n{de}[00ff00]DOPPEL-FORTIFIED[-][i] - Dieser Feind kann in der Fernkampfphase nicht mit Fernkampf- oder Belagerungsangriffen angegriffen werden[/i]\n\n"}) end
				--Wall Fortified
				if gStates.monsterPerks[hover_object.guid]~=nil and gStates.monsterPerks[hover_object.guid].wallFortified~=nil and (monsterPugs[hover_object.guid]==nil or monsterPugs[hover_object.guid].fortified==nil) then monsterDescription=joinLang({monsterDescription, "{en}[00ff00]WALL FORTIFIED[-][i] - This enemy can't be attacked with Ranged attacks in the Range phase.[/i]\n\n{ru}[00ff00]УКРЕПЛЕННЫЙ ЗА СТЕНОЙ[-][i] - Во время фазы боя на расстоянии против врага можно играть только Осадные атаки.[/i]\n\n{zh-cn}[00ff00]城防[-][i] - 在远程攻击阶段，该敌人无法受到远程攻击。[/i]\n\n{ko}[00ff00]벽 요새화[-][i] - 이 적을 원거리 단계에서 원거리 공격으로 공격할 수 없음.[/i]\n\n{es}[00ff00]PARED FORTIFICADA[-][i] - Este enemigo no puede ser atacado con ataques a distancia en la fase de Alcance.[/i]\n\n{fr}[00ff00]WALL FORTIFIED[-][i] - Cet ennemi ne peut pas être attaqué avec des attaques à distance lors de la phase de portée.[/i]\n\n{pt-br}[00ff00]PAREDE FORTIFICADA[-][i] - Esse inimigo não pode ser atacado com ataques de longo alcance na fase de alcance[/i]\n\n{de}[00ff00]WALL FORTIFIED[-][i] - Dieser Gegner kann in der Fernkampfphase nicht mit Fernkampfangriffen angegriffen werden.[/i]\n\n"}) end
				--Unfortified
				if monsterPugs[hover_object.guid]~=nil and monsterPugs[hover_object.guid].unfortified~=nil then monsterDescription=joinLang({monsterDescription, "{en}[00ff00]UN-FORTIFIED[-][i] - This enemy ignores site fortifications, and can be attacked with Range and Siege attacks.[/i]\n\n{ru}[00ff00]НЕУКРЕПЛЕННЫЙ[-][i] - Этот враг игнорирует все местные укрепления и может быть атакован с помощью Дальних и Осадных атак.[/i]\n\n{zh-cn}[00ff00]不设城防[-][i] - 该敌人无视地点城防，可以使用远程攻击和攻城攻击。[/i]\n\n{ko}[00ff00]무방비[-][i] - 이 적을 요새화를 무시하고 원거리 및 공성 공격으로 공격할 수 있음.[/i]\n\n{es}[00ff00]NO FORTIFICADO[-][i] - Este enemigo ignora las fortificaciones del sitio, y puede ser atacado con ataques de Alcance y Asedio.[/i]\n\n{fr}[00ff00]NON FORTIFIE[-][i] - Cet ennemi ignore les fortifications du site et peut être attaqué avec des attaques à distance et de siège.[/i]\n\n{pt-br}[00ff00]NÃO FORTIFICADO[-][i] - Esse inimigo ignora as fortificações do local e pode ser atacado com ataques de longo alcance e de cerco.[/i]\n\n{de}[00ff00]UNVERBESSERT[-][i] - Dieser Feind ignoriert Standortbefestigungen und kann mit Fernkampf- und Belagerungsangriffen angegriffen werden.[/i]\n\n"}) end
				--physical resistance
				if monsterPugs[hover_object.guid]~=nil and monsterPugs[hover_object.guid].pResist~=nil then monsterDescription=joinLang({monsterDescription, "{en}[00ff00]PHYSICAL RESISTANCE[-][i] - Physical attacks are halved against this enemy.[/i]\n\n{ru}[00ff00]ФИЗИЧЕСКОЕ СОПРОТИВЛЕНИЕ[-][i] - Значения Физических атак делятся на 2, с округлением вниз[/i]\n\n{zh-cn}[00ff00]物理抗性[-][i] - 对该敌人的物理攻击减半。[/i]\n\n{ko}[00ff00]물리 저항[-][i] - 모든 물리 공격이 반감됨.[/i]\n\n{es}[00ff00]RESISTENCIA FÍSICA[-][i] - Los ataques físicos se reducen a la mitad contra este enemigo.[/i]\n\n{fr}[00ff00]RÉSISTANCE PHYSIQUE[-][i] - Les attaques physiques sont réduites de moitié contre cet ennemi.[/i]\n\n{pt-br}[00ff00]RESISTÊNCIA FÍSICA[-][i] - Os ataques físicos são reduzidos à metade contra esse inimigo.[/i]\n\n{de}[00ff00]PHYSISCHE RESISTENZ[-][i] - Physische Angriffe werden gegen diesen Feind halbiert.[/i]\n\n"}) end
				--fire resistance
				if monsterPugs[hover_object.guid]~=nil and monsterPugs[hover_object.guid].fResist~=nil and monsterPugs[hover_object.guid].iResist==nil then monsterDescription=joinLang({monsterDescription, "{en}[ff0000]FIRE RESISTANCE[-][i] - Fire attacks are halved against this enemy. This enemy can't be targeted by Unit abilities powered by Red Mana, nor from non-attack effects of Red cards.[/i]\n\n{ru}[ff0000]СОПРОТИВЛЕНИЕ ОГНЮ[-][i] - Значения Огненных атак делятся на 2, с округлением вниз. Этот отряд игнорирует все эффекты карт и способности отрядов, сыгранные за красную ману (кроме эффектов Атак).[/i]\n\n{zh-cn}[ff0000]火焰抗性[-][i] - 对该敌人的火焰攻击减半。该敌人无法成为由红色法力驱动的单位能力的目标，也无法成为红色卡牌的非攻击效果的目标。[/i]\n\n{ko}[ff0000]불 저항[-][i] - 모든 불 공격이 반감됨. 이 적은 적색 카드나 적색 마나로 강화한 유닛의 (공격이 아닌) 특수 효과를 무시함.[/i]\n\n{es}[ff0000]RESISTENCIA AL FUEGO[-][i] - Los ataques de fuego se reducen a la mitad contra este enemigo. Este enemigo no puede ser objetivo de habilidades de Unidad potenciadas con Maná Rojo, ni de efectos de no-ataque de cartas Rojas.[/i]\n\n{fr}[ff0000]RÉSISTANCE AU FEU[-][i] - Les attaques de feu sont réduites de moitié contre cet ennemi. Cet ennemi ne peut pas être ciblé par des capacités d'unité alimentées par du mana rouge, ni par des effets de cartes rouges qui n'attaquent pas.[/i]\n\n{pt-br}[ff0000]RESISTÊNCIA AO FOGO[-][i] - Os ataques de fogo são reduzidos à metade contra esse inimigo. Esse inimigo não pode ser alvo de habilidades de unidade alimentadas por Mana vermelha nem de efeitos de cartas vermelhas que não sejam de ataque.[/i]\n\n{de}[ff0000]FEUERWIDERSTAND[-][i] - Feuerangriffe werden gegen diesen Feind halbiert. Dieser Feind kann weder von Einheitenfähigkeiten, die durch rotes Mana angetrieben werden, noch von Nicht-Angriffseffekten roter Karten angegriffen werden.[/i]\n\n"}) end
				--ice resistance
				if monsterPugs[hover_object.guid]~=nil and monsterPugs[hover_object.guid].iResist~=nil and monsterPugs[hover_object.guid].fResist==nil then monsterDescription=joinLang({monsterDescription, "{en}[5a5aff]ICE RESISTANCE[-][i] - Ice attacks are halved against this enemy. This enemy can't be targeted by Unit abilities powered by Blue Mana, nor from non-attack effects of Blue cards.[/i]\n\n{ru}[5a5aff]СОПРОТИВЛЕНИЕ ЛЬДУ[-][i] - Значения Ледяных атак делятся на 2, с округлением вниз. Этот отряд игнорирует все эффекты карт и способности отрядов, сыгранные за синюю ману (кроме эффектов Атак).[/i]\n\n{zh-cn}[5a5aff]寒冰抗性[-][i] - 此敌人受到的寒冰攻击减半。该敌人不能成为由蓝色法力驱动的单位异能的目标，也不能成为蓝色卡牌非攻击效果的目标。[/i]\n\n{ko}[5a5aff]얼음 저항[-][i] - 모든 얼음 공격이 반감됨. 이 적은 청색 카드나 총색 마나로 강화한 유닛의 (공격이 아닌) 특수 효과를 무시함.[/i]\n\n{es}[5a5aff]RESISTENCIA AL HIELO[-][i] - Los ataques de hielo se reducen a la mitad contra este enemigo. Este enemigo no puede ser objetivo de habilidades de Unidad potenciadas con Maná Azul, ni de efectos de no-ataque de cartas Azules.[/i]\n\n{fr}[5a5aff]RÉSISTANCE À LA GLACE[-][i] - Les attaques de glace sont réduites de moitié contre cet ennemi. Cet ennemi ne peut pas être ciblé par les capacités d'unité alimentées par du mana bleu, ni par les effets non offensifs des cartes bleues.[/i]\n\n{pt-br}[5a5aff]RESISTÊNCIA AO GELO[-][i] - Os ataques de gelo são reduzidos à metade contra esse inimigo. Esse inimigo não pode ser alvo de habilidades de Unidade alimentadas por Mana Azul nem de efeitos de cartas Azuis que não sejam de ataque.[/i]\n\n{de}[5a5aff]EISWIDERSTAND[-][i] - Eisangriffe werden gegen diesen Feind halbiert. Dieser Feind kann weder von Einheitenfähigkeiten, die durch blaues Mana angetrieben werden, noch von Nicht-Angriffseffekten blauer Karten angegriffen werden.[/i]\n\n"}) end
				--cold fire resistance
				if monsterPugs[hover_object.guid]~=nil and monsterPugs[hover_object.guid].iResist~=nil and monsterPugs[hover_object.guid].fResist~=nil then monsterDescription=joinLang({monsterDescription, "{en}[ff00fe]COLD FIRE RESISTANCE[-][i] - Fire, Ice and Cold Fire attacks are halved against this enemy. This enemy can't be targeted by Unit abilities powered by Red or Blue Mana, nor from non-attack effects of Red or Blue cards.[/i]\n\n{ru}[ff00fe]СОПРОТИВЛЕНИЕ ОГНЮ И ЛЬДУ[-][i] - Значения Огненных, Ледяных и Огненно-ледяных атак делятся на 2, с округлением вниз. Этот отряд игнорирует все эффекты карт и способности отрядов, сыгранные за красную или синюю ману (кроме эффектов Атак).[/i]\n\n{zh-cn}[ff00fe]冰火抗性[-][i] - 此敌人受到的火、冰和冰火攻击减半。该敌人不能成为由红色或蓝色法力驱动的单位能力的目标，也不能成为红色或蓝色卡牌的非攻击效果的目标。[/i]\n\n{ko}[ff00fe]차가운불 저항[-][i] - 모든 불, 얼음, 차가운 불 공격이 반감됨. 이 적은 청,적색 카드나 청,적색 마나로 강화한 유닛의 (공격이 아닌) 특수 효과를 무시함..[/i]\n\n{es}[ff00fe]RESISTENCIA AL FUEGO FRÍO[-][i] - Los ataques de Fuego, Hielo y Fuego Frío se reducen a la mitad contra este enemigo. Este enemigo no puede ser objetivo de habilidades de Unidad potenciadas con Maná Rojo o Azul, ni de efectos de no-ataque de cartas Rojas o Azules.[/i]\n\n{fr}[ff00fe]RÉSISTANCE AU FEU FROID[-][i] - Les attaques de Feu, de Glace et de Feu froid sont réduites de moitié contre cet ennemi. Cet ennemi ne peut pas être ciblé par des capacités d'unité alimentées par du mana rouge ou bleu, ni par des effets non offensifs de cartes rouges ou bleues.[/i]\n\n{pt-br}[ff00fe]RESISTÊNCIA A FOGO FRIO[-][i] - Os ataques de Fogo, Gelo e Fogo Frio são reduzidos à metade contra esse inimigo. Esse inimigo não pode ser alvo de habilidades de unidade alimentadas por Mana vermelha ou azul, nem de efeitos que não sejam de ataque de cartas vermelhas ou azuis.[/i]\n\n{de}[ff00fe]KALTE FEUERWIDERSTAND[-][i] - Feuer-, Eis- und Kältefeuer-Angriffe werden gegen diesen Feind halbiert. Dieser Feind kann weder von Einheitenfähigkeiten, die durch rotes oder blaues Mana angetrieben werden, noch von Nicht-Angriffseffekten roter oder blauer Karten angegriffen werden.[/i]\n\n"}) end
				--arcane immunity
				if (monsterPugs[hover_object.guid]~=nil and monsterPugs[hover_object.guid].arcaneImmunity~=nil) or (gStates.monsterPerks[hover_object.guid]~=nil and gStates.monsterPerks[hover_object.guid].arcaneImmunity~=nil) then monsterDescription=joinLang({monsterDescription, "{en}[00ff00]ARCANE IMMUNITY[-][i] - This enemy can't be targeted by non-Attack or non-Block effects from any source. Effects that directly affect an enemy's attack(s) still apply.[/i]\n\n{ru}[00ff00]ЗАЩИТА ОТ МАГИИ[-][i] - На врага не влияют никакие эффекты, кроме атак и блоков. Эффекты, действующие напрямую на атаку этого врага, по-прежнему можно использовать.[/i]\n\n{zh-cn}[00ff00]魔法免疫[-][i] - 该敌人无法成为任何来源的非攻击或非阻断效果的目标。直接影响敌人攻击的效果仍然适用。[/i]\n\n{ko}[00ff00]마법 면역[-][i] - 이 적은 공격, 방어를 제외한 그 어떠한 특수 효과를 무시함. 적의 공격에 직접 영향을 주는 효과는 여전히 적용.[/i]\n\n{es}[00ff00]INMUNIDAD ARCANA[-][i] - Este enemigo no puede ser objetivo de efectos que no sean de Ataque o Bloqueo de ninguna fuente. Los efectos que afectan directamente a los ataques de un enemigo se siguen aplicando.[/i]\n\n{fr}[00ff00]IMMUNITÉ DE L'ARCANE[-][i] - Cet ennemi ne peut pas être ciblé par des effets autres qu'une attaque ou un blocage, quelle qu'en soit la source. Les effets qui affectent directement les attaques de l'ennemi s'appliquent toujours.[/i]\n\n{pt-br}[00ff00]IMUNIDADE ARCANA[-][i] - Esse inimigo não pode ser alvo de efeitos que não sejam de ataque ou de bloqueio de nenhuma fonte. Os efeitos que afetam diretamente o(s) ataque(s) de um inimigo ainda se aplicam.[/i]\n\n{de}[00ff00]ARKANE IMMUNITÄT[-][i] - Dieser Feind kann nicht durch Nicht-Angriffs- oder Nicht-Block-Effekte aus irgendeiner Quelle angegriffen werden. Effekte, die sich direkt auf die Attacke(n) des Feindes auswirken, gelten weiterhin.[/i]\n\n"}) end
				--reward
				local factionTranslate=({	["Dark"]="{en}Dark Crusader{ru}Тёмный крестоносец{zh-tw}黑暗遠征軍{zh-cn}黑暗远征军{ko}암흑 십자군{es}Cruzado Oscuro{fr}Croisé des ténèbres{pt-br}Cruzado das Trevas{de}Dunkler Kreuzritter",
											["Elem"]="{en}Elementalist{ru}Элементалист{zh-tw}元素之力{zh-cn}元素之力{ko}원소술사{es}Elementalista{fr}Élémentaliste{pt-br}Elementalista{de}Elementarist",
											["Apoc"]="{en}Apocalypse Cult{ru}Культ Апокалипсиса{zh-tw}末日教團{zh-cn}末日教团{ko}아포칼립스 컬트{es}Culto del Apocalipsis{fr}Culte de l'Apocalypse{pt-br}Culto do Apocalipse{de}Apokalypse-Kult",
											["Coun"]="{en}Council of the Void{ru}Совет Пустоты{zh-tw}虛空議會{zh-cn}虚空议会{ko}공허 의회{es}Consejo del Vacío{fr}Conseil du Vide{pt-br}Conselho do Vazio{de}Rat der Leere"})
				local used=false
				local rewardLabel="{en}[00ff00]FACTION REWARD:[-] {ru}[00ff00]НАГРАДЫ ФРАКЦИИ:[-] {zh-cn}[00ff00]派系奖励：[-] {ko}[00ff00]세력 보상:[-] {es}[00ff00]RECOMPENSA DE FACCIÓN:[-] {fr}[00ff00]RÉCOMPENSE DE FACTION:[-] {pt-br}[00ff00]RECOMPENSA DE FAÇÃO:[-] {de}[00ff00]FACTION REWARD:[-] "
				local printed=monsterPugs[hover_object.guid]
				if printed~=nil and printed.pugType~="yellow" and type(printed.reward)=="number" and printed.reward>0 and factionRewardUsesJustFame(printed.faction)~=true then
					local faction=factionTranslate[printed.faction]
					if faction~=nil then monsterDescription=joinLang({monsterDescription,rewardLabel,faction}) used=true end
				end
				local perks=gStates.monsterPerks[hover_object.guid]
				if perks~=nil and type(perks.reward)=="number" and perks.reward>0 and factionRewardUsesJustFame(perks.faction)~=true then
					local faction=factionTranslate[perks.faction]
					if faction~=nil then
						if used==true then monsterDescription=joinLang({monsterDescription,"\n"}) end
						monsterDescription=joinLang({monsterDescription,rewardLabel,faction})
						used=true
					end
				end
				if used==true then monsterDescription=joinLang({monsterDescription,"\n\n"}) end
				--fame: each faction independently uses +1 Fame when its own reward pile has been removed.
				local rewardPug,rewardPerk=monsterFactionRewardFameFallback(hover_object.guid)
				local reward=rewardPug+rewardPerk
				local bonus=0
				if gStates.monsterPerks[hover_object.guid]~=nil and gStates.monsterPerks[hover_object.guid].fame~=nil then bonus=gStates.monsterPerks[hover_object.guid].fame end
				if monsterPugs[hover_object.guid]~=nil and monsterPugs[hover_object.guid].fame~=nil and monsterPugs[hover_object.guid].fame>0 then monsterDescription=joinLang({monsterDescription, "{en}[00ff00]FAME: [-]{ru}[00ff00]СЛАВА: [-]{zh-tw}[00ff00]名望：[-]{zh-cn}[00ff00]名望：[-]{ko}[00ff00]명성: [-]{es}[00ff00]FAMA: [-]{fr}[00ff00]FAME : [-]{pt-br}[00ff00]FAMA: [-]{de}[00ff00]RUHM: [-]", tostring(monsterPugs[hover_object.guid].fame+reward+bonus)}) end
				if gStates.monsterPerks[hover_object.guid]~=nil and gStates.monsterPerks[hover_object.guid].dragonGround==true then
					local headName=apocalypseDragonGroundHeadNameForGUID(hover_object.guid)
					if headName=="Control" then monsterDescription=joinLang({monsterDescription,"\n[00ff00]CONTROL HEAD[-] - This head may never be attacked."}) end
				end
			end
		end
		hover_object.setDescription(monsterDescription)
	end
end

--Face-down cards in a player play area get a physical decal instead of Object UI.
local cardRemoveDecalURL="https://steamusercontent-a.akamaihd.net/ugc/1661232230977162756/90D8AEB60005119DD4182B5FD24D7BDD8243B5F3/"
local function cardInPlayerPlayArea(cardGUID)
	for a=1, 4 do
		local zone=getObjectFromGUID(playerPlayAreas[a])
		if zone~=nil then for _, card in pairs(zone.getObjects()) do if card.guid==cardGUID then return true end end end
	end
	return false
end
local function removeCardRemoveDecal(card)
	if card==nil then return end
	local decals={}
	local changed=false
	for _, decal in pairs(card.getDecals() or {}) do
		if decal.name=="Card Remove" then changed=true else decals[#decals+1]=decal end
	end
	if changed==true then card.setDecals(decals) end
end
local function refreshCardRemoveDecal(card)
	if card==nil or card.type~="Card" or not (gameCards[card.guid]==nil or gameCards[card.guid].full==nil) then return end
	removeCardRemoveDecal(card)
	if card.is_face_down==true and cardInPlayerPlayArea(card.guid)==true then
		--Face-down cards are rotated over, so put the decal on the card's local underside.
		card.addDecal({name="Card Remove", url=cardRemoveDecalURL, position={0,-0.5,0}, rotation={270,180,180}, scale={1.7,2.0,1}})
	end
end

--Update skill Locations, Update Players Location details, and Update the UI and trigger a Level up if a mage shield was moved manually
function __onObjectDrop_raw(player_color, dropped_object)
	local droppedGUID=dropped_object.guid
	if gStates.gameScenario=="Against the Horsemen Blitz" and (terrainTiles[droppedGUID]~=nil or (horsemanTokenToName~=nil and horsemanTokenToName[droppedGUID]~=nil)) then
		safeWaitFrames("Events",function() againstHorsemenRefreshReveals() end,2)
	end
	puppetMasterDropped(dropped_object)
	puppetMasterCheckManualCopyWhenResting(dropped_object)
	if dropped_object~=nil and monsterPugs[dropped_object.guid]~=nil and monsterPugs[dropped_object.guid].pugType=="possessed" then
		attachEnemy(nil,nil,"attach",dropped_object,nil)
	end
	if dropped_object~=nil and dropped_object.getName()=="Shield" and apocalypseQuestsUsed()==true then
		safeWaitFrames("Events",function() apocalypseQuestRefreshOfferButtons() end, 2)
	end
	if dropped_object~=nil and gStates.apocalypseQuestTokenGUIDs~=nil and gStates.apocalypseQuestTokenGUIDs[droppedGUID]==true then
		safeWaitFrames("Events",function() apocalypseQuestRefreshOfferButtons() end, 2)
	end
	if droppedGUID~=nil and gStates.apocalypseQuestGoblinEnemies~=nil and gStates.apocalypseQuestGoblinEnemies[droppedGUID]~=nil then
		safeWaitFrames("Events",function() apocalypseQuestRefreshOfferButtons() end,2)
	end
	--Avatar Quest eligibility is refreshed after the avatar has settled and its new hex has been
	--recorded in avatarlocationDetails(). Do not do an earlier full-offer refresh against the old hex.
	if dropped_object~=nil and dropped_object.type=="Card" then
		safeWaitFrames("Events",function() local card=getObjectFromGUID(droppedGUID) if card~=nil then refreshCardRemoveDecal(card) end end, 2)
	end
	if droppedGUID==meditationTranceCardGUID or gStates.meditationTranceState~=nil then
		safeWaitFrames("Events",function() if droppedGUID~=nil then meditationTranceCheckLooseCard(droppedGUID) end refreshMeditationTrance() end, 2)
	end
	if droppedGUID~=nil and isSteadyTempoGUID(droppedGUID)==true and gStates.steadyTempoPending~=nil and gStates.steadyTempoPending[droppedGUID]~=nil then
		safeWaitFrames("Events",function() steadyTempoRefreshCard(droppedGUID) end, 2)
	end
	--Update skill Locations
	if skillTokens[dropped_object.guid]~=nil then
		--During Start at a Higher Level, dragging one of the two offered skills into that player's skill
		--column counts exactly like clicking its Claim button. Keep its original row so the paired skill
		--can still be found and moved to the communal/co-op area if the chosen token was shifted vertically.
		if gStates.firstStarted~=true and gStates.mageKnightLevels==true and gStates.magesSetup==true then
			local originalSkillPos=gStates.mageSkills[dropped_object.guid]
			local wasAlreadyClaimed=higherLevelSkillAreaPlayer(originalSkillPos)~=nil
			safeWaitFrames("Events",function() safeWaitCondition("Events",function()
				local skill=getObjectFromGUID(dropped_object.guid)
				if skill~=nil then
					local playerPosition=higherLevelSkillAreaPlayer(skill.getPosition())
					local originalPlayer=originalSkillPos~=nil and math.ceil((originalSkillPos[1]+95)/40) or nil
					if player_color~=nil and playerPosition~=nil and wasAlreadyClaimed==false and originalPlayer==playerPosition and originalSkillPos[3]<-35 then
						higherLevelSkill({color=player_color}, "-1", dropped_object.guid.."higherLevelSkill", originalSkillPos)
					else
						higherLevelSkillClaimButons()
					end
				end
			end, function() return getObjectFromGUID(dropped_object.guid)==nil or getObjectFromGUID(dropped_object.guid).resting end) end, 5)
			return
		end
		tomeSkillDropped(dropped_object.guid, dropped_object.getPosition())
		local coopCompSkill=(skillTokens[dropped_object.guid].skillType=="Coop" or skillTokens[dropped_object.guid].skillType=="Comp")
		if coopCompSkill==true then coopCompSkillDropped(dropped_object.guid, dropped_object.getPosition()) end
		local coopCompLockedAtDrop=coopCompSkill==true and coopCompSkillPlayLocked()==true
		safeWaitFrames("Events",function() safeWaitCondition("Events",function()
			if getObjectFromGUID(dropped_object.guid)~=nil then
				if coopCompSkill==true then
					local playAreaPlayer=coopCompSkillPlayAreaPlayer(dropped_object.guid)
					if playAreaPlayer~=nil then
						local paused=gStates.coopCompSkillPaused~=nil and gStates.coopCompSkillPaused[dropped_object.guid]~=nil
						local inRotation=gStates.doingTheRounds[dropped_object.guid]~=nil and paused==false
						if coopCompLockedAtDrop==true and inRotation==false then pauseLateCoopCompSkill(dropped_object.guid, playAreaPlayer)
						elseif coopCompLockedAtDrop==false then
							if gStates.coopCompSkillLegalThisRound==nil then gStates.coopCompSkillLegalThisRound={} end
							gStates.coopCompSkillLegalThisRound[dropped_object.guid]=true
						end
					end
				end
				local objPos=getObjectFromGUID(dropped_object.guid).getPosition()
				if 	(objPos[3]>-25 or
					(objPos[3]<-35 and objPos[1]>-68 and objPos[1]<-66) or
					(objPos[3]<-35 and objPos[1]>-28 and objPos[1]<-26) or
					(objPos[3]<-35 and objPos[1]>12 and objPos[1]<14) or
					(objPos[3]<-35 and objPos[1]>52 and objPos[1]<54)) then
					if gStates.mageSkills[dropped_object.guid]~=nil then
						if objPos[3]<-35 then
							if gStates.skillButtons>0 then skillMove({color="Black"}, "-1", dropped_object.guid..((math.ceil((gStates.mageSkills[dropped_object.guid][1]-12.85)/3.7)*8)+math.ceil((gStates.mageSkills[dropped_object.guid][3]+24.625)/1.35))) return end
							if gStates.motivationSkill[dropped_object.guid]~=nil and dropped_object.is_face_down==false then gStates.motivationSkill[dropped_object.guid].state="active" end
							if gStates.motivationSkill[dropped_object.guid]~=nil and dropped_object.is_face_down==true then gStates.motivationSkill[dropped_object.guid].state="used" end
						end
					--else
						--gStates.mageSkills[dropped_object.guid]={}
					end
					gStates.mageSkills[dropped_object.guid]={objPos[1], objPos[2], objPos[3]}
					skillButtonActivate()
				end
			end
		end, function() return getObjectFromGUID(dropped_object.guid)==nil or getObjectFromGUID(dropped_object.guid).resting end) end, 5)
		return
	end

	--Quest tokens that become permanent sites update the terrain database as soon as the player places them.
	if apocalypseQuestSiteTokenDropped(dropped_object)==true then return end

	--A human-dropped Destroyed Site token uses the same state change as scripted destruction.
	if player_color~=nil and dropped_object.getGMNotes()=="Destroyed" and (gStates.destroyedSites==nil or gStates.destroyedSites[dropped_object.guid]==nil) then
		local terrain, bearing=terrainHexAtPosition(dropped_object.getPosition())
		if terrain~=nil then
			if destroySite(dropped_object, terrain, bearing)==true then fakeDropAvatar()
			else broadcastToAll("That location cannot be destroyed", {1,1,0.5}) end
		end
		return
	end

	--Update Players Location details
	local keepShieldMatch={	{keep=false, keepShield=false, city=false, cityShield=false},
							{keep=false, keepShield=false, city=false, cityShield=false},
							{keep=false, keepShield=false, city=false, cityShield=false},
							{keep=false, keepShield=false, city=false, cityShield=false},
							{keep=false, keepShield=false, city=false, cityShield=false},
							{keep=false, keepShield=false, city=false, cityShield=false},
							{keep=false, keepShield=false, city=false, cityShield=false}}
	local keepFound=false
	local cityFound="False"
	for _, avatar in pairs(mageKnights) do
		if (dropped_object.guid==avatar.model or dropped_object.guid==avatar.standee or dropped_object.guid==avatar.token) then --and avatar.mage~="Volkare" then
			local avatarPlayerIndex=nil
			for playerIndex, playerDetails in pairs(turnOrder) do if playerDetails.mage==avatar.mage then avatarPlayerIndex=playerIndex break end end
			local currentMage=turnOrder[gStates.turnNumber]~=nil and turnOrder[gStates.turnNumber].mage or nil
			--A human may correct the Proxy Hero's physical location. Track that drop, but never run the
			--normal player's assault/site/hand-size machinery for the automated Proxy.
			if player_color~=nil and gStates.firstStarted==true and proxyPlayerActive()==true and avatar.mage==gStates.positionMageKnight[5] and avatarPlayerIndex~=nil then
				local function finishProxyManualDrop()
					if getObjectFromGUID(dropped_object.guid)~=nil then
						refreshAvatarLocationOnly(avatarPlayerIndex,dropped_object)
						--Do not infer off-map status from avatarLocation: featureless terrain legitimately has no
						--location label. Record whether the physical figure is actually on a revealed map hex.
						local proxyHexes,proxyMapObjects=apocalypseQuestMapHexes()
						gStates.proxyAvatarOffMap=apocalypseQuestHexForPosition(proxyHexes,dropped_object.getPosition(),proxyMapObjects)==nil
					end
				end
				safeWaitCondition("Events",finishProxyManualDrop,function() return getObjectFromGUID(dropped_object.guid)==nil or dropped_object.resting end,1.5,finishProxyManualDrop)
				return
			end
			if player_color~=nil and gStates.firstStarted==true and avatar.mage~="Volkare" and avatarPlayerIndex~=nil and currentMage~=avatar.mage then
				safeWaitCondition("Events",function() if coopAssaultVirtualPlayer(avatarPlayerIndex)==false then refreshAvatarLocationOnly(avatarPlayerIndex, dropped_object) end end, function() return getObjectFromGUID(dropped_object.guid)==nil or dropped_object.resting end, 1.5, function() if getObjectFromGUID(dropped_object.guid)~=nil and coopAssaultVirtualPlayer(avatarPlayerIndex)==false then refreshAvatarLocationOnly(avatarPlayerIndex, dropped_object) end end)
				return
			end
			function avatarlocationDetails()
				local attackedLocation=nil
				local horsemenGladeAssault=false
				local avatarChangedHex=false
				if player_color~=nil and turnOrder[gStates.turnNumber].mage==avatar.mage then
					avatarChangedHex=avatarMovedFromPickedUpHex(dropped_object.getPosition())
					if avatarChangedHex==true then
						apocalypseQuestUnderSiegeMarkMoved(gStates.turnNumber)
						clearWallAssaultChoice()
						assaultApproachOrigin=nil
						assaultTargetPosition=nil
						leaveAvatarSite(turnOrder[gStates.turnNumber])
						clearPendingCoopAssault()
					end
				end
				playerPickedUpHex=nil
				if getObjectFromGUID(dropped_object.guid)~=nil then
					for _, playerDetails in pairs(turnOrder) do
						if playerDetails.mage==avatar.mage then
							playerDetails.avatarLocation=""
							playerDetails.avatarSharedHex=nil
							local droppedPos=dropped_object.getPosition()
							local avatarPos={droppedPos[1], droppedPos[2], droppedPos[3]}--copy so neighbour math can safely mutate it
							--check if avatar dropped on city card, then use the city model as the avatar location
							local cityZoneFound=false
							for zone, citySearch in pairs(cityScriptZones) do
								local zoneObj=getObjectFromGUID(zone)
								if zoneObj~=nil then
									for _, detail in pairs(zoneObj.getObjects()) do
										if detail.guid==dropped_object.guid then
											local cityObj=nil
											if zone==volkare.discZone and (gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz" or gStates.gameScenario=="Volkare's Quest" or gStates.gameScenario=="The War of Four") then cityObj=getObjectFromGUID(gStates.volkareModel)
											else cityObj=getObjectFromGUID(citySearch.cityGUID) end
											if cityObj~=nil then local cityPos=cityObj.getPosition() avatarPos={cityPos[1],1.5,cityPos[3]} end
											cityZoneFound=true
											break
										end
									end
								end
								if cityZoneFound==true then break end
							end
							--Use one cached map snapshot for the current hex and its six neighbours.
							local volkareCampKeepAllowed=volkareCampAsCityConquered()==true and volkareCampContributionShieldCount(playerDetails)>0
							local mapObjects, mapObjectPositions, mapTerrainObjects, mapTerrainRotations, mapObjectBuckets=avatarLocationMapSnapshot()
								for keepSearch=1, 7, 1 do
									--Volkare can remove a City model during this loop, so retain the old live-refresh behaviour for him.
									if keepSearch>1 and playerDetails.mage=="Volkare" then
										mapObjects, mapObjectPositions, mapTerrainObjects, mapTerrainRotations, mapObjectBuckets=avatarLocationMapSnapshot()
									end
									local locatedTerrain, bearing, _, hexFeature=terrainHexAtPosition(avatarPos, mapTerrainObjects, mapObjectPositions, mapTerrainRotations)
								hexFeature=hexFeature or ""
									for _, terrain in ipairs(avatarLocationRelevantObjects(locatedTerrain, avatarPos, mapObjectBuckets)) do--terrain tile + nearby physical objects only
										--work with terrain tiles
										local tilePos=mapObjectPositions[terrain.guid] or terrain.getPosition()
										local avatarToTileDistSquared=((avatarPos[1]-tilePos[1])^2)+((avatarPos[3]-tilePos[3])^2)
									if terrain==locatedTerrain then
										if keepSearch==1 then
											playerDetails.avatarLocation=hexFeature
											if gStates.gameScenario=="Fury of the Apocalypse Dragon" and avatarChangedHex==true and playerDetails.mage~="Volkare" and
												turnOrder[gStates.turnNumber].mage==avatar.mage and player_color~=nil and playerDetails.avatarLocation:sub(1,4)=="city" then
												gStates.furyHeroEnteredCity=true
											end
											if againstHorsemenCentralGladeHex(locatedTerrain,bearing)==true then
												if gStates.againstHorsemenRitualStarted~=true then playerDetails.avatarSharedHex=againstHorsemenSharedHexKey
												elseif playerDetails.mage~="Volkare" and turnOrder[gStates.turnNumber].mage==avatar.mage and player_color~=nil and gStates.preEndTurn==false and avatarChangedHex==true then horsemenGladeAssault=true end
											end
											if playerDetails.mage~="Volkare" and turnOrder[gStates.turnNumber].mage==avatar.mage and player_color~=nil and gStates.preEndTurn==false and attackedLocation==nil and horsemenGladeAssault==false
												and (avatarChangedHex==true or next(gStates.attackedMonsters)==nil)
												and (playerDetails.avatarLocation=="keep" or playerDetails.avatarLocation=="mage tower" or playerDetails.avatarLocation:sub(1, 4)=="city" or playerDetails.avatarLocation=="Volkare's Camp" or playerDetails.avatarLocation=="hidden valley" or playerDetails.avatarLocation=="necropolis") then
												attackedLocation="Attack"..playerDetails.mage--was "Locati" instead of "Attack"
											end
											if playerDetails.mage=="Volkare" and gStates.preEndTurn==false and attackedLocation==nil and playerDetails.avatarLocation:sub(1, 4)=="city" then
												if gStates.gameScenario~="Volkare's Quest" then
													for index, modelTerrain in pairs(gStates.cityRevealed) do
														if modelTerrain.terrain==terrain.guid then
															getObjectFromGUID(trashCan).putObject(getObjectFromGUID(modelTerrain.model))
															gStates.cityRevealed[index].state="defeated"
															break
														end
													end
												end
											end
										end
										if hexFeature=="keep" or (volkareCampKeepAllowed==true and (hexFeature=="Volkare's Camp" or (gStates.cityVolkareTile==terrain.guid and bearing=="center"))) then
											keepShieldMatch[keepSearch]["keep"]=true
											if keepShieldMatch[keepSearch]["keepShield"]==true then keepFound=true end
										end
										if (hexFeature or ""):sub(1,4)=="city" then
											keepShieldMatch[keepSearch]["city"]=true
											if keepShieldMatch[keepSearch]["cityShield"]==true then cityFound=terrain.getName() end
										end
									end
										if avatarToTileDistSquared<1 then
										--work with Shields
										if terrain.getName()=="Shield" and volkarePursuitShieldRegistered(terrain)~=true and ((terrain.getDescription()==playerDetails.mage and (gStates.coop==0 or gStates.WarOfFourComp==true)) or (gStates.coop==1 and gStates.WarOfFourComp~=true)) then
											keepShieldMatch[keepSearch]["keepShield"]=true
											if keepShieldMatch[keepSearch]["keep"]==true then keepFound=true end
										end

										--work with Cities
										local temp=terrain.guid
										if terrain.guid=="938cd3" or terrain.guid=="a0d7b3" then temp=volkare.model end
										if temp==cityModel.white or	temp==cityModel.blue or	temp==cityModel.red or temp==cityModel.green or temp==volkare.terrainHex or	temp==volkare.model then
											--flip garrisons during the day
											if turnOrder[gStates.turnNumber].mage==avatar.mage and gStates.preEndTurn==false and gStates.cityMonsterQty[temp]~=nil and gStates.autoFlip==true and temp~=volkare.model then
												local broadcast=false
												for monsterGUID, monster in pairs(gStates.cityMonsterQty[temp]) do
													if monsterGUID~="extra" then
														local monsterObj=getObjectFromGUID(monsterGUID)
														if monsterObj~=nil and monsterObj.is_face_down==true then monsterObj.flip() broadcast=true end
													end
												end
												if broadcast==true then
													if temp==volkare.model then
														broadcastToAll("{en}Volkare's Army Revealed{ru}Армия Волкара раскрыта{zh-cn}沃里卡军队揭示了{ko}볼케어의 군대가 공개되었습니다{es}Se revela el ejército de Volkare{fr}L'armée de Volkare révélée{pt-br}Exército de Volkare Revelado{de}Volkare's Armee aufgedeckt", {1,1,0.5})
													else
														broadcastToAll("{en}Site Garrison Revealed{ru}Гарнизон Укрепленного места раскрыт{zh-cn}守军揭示了{ko}수비자가 공개되었습니다.{es}Guarnición del Sitio Revelada{fr}La Garnison du Site Révélée{pt-br}Lugar de Guarnição Revelada{de}Standort Garnison aufgedeckt", {1,1,0.5})
													end
												end
											end
											--Assult Volkare
											if playerDetails.mage~="Volkare" and keepSearch==1 and temp==volkare.model then
												playerDetails.avatarLocation="Volkare's Camp"
												if player_color~=nil and gStates.preEndTurn==false and attackedLocation~="Volkar"..playerDetails.mage and (avatarChangedHex==true or next(gStates.attackedMonsters)==nil) then
													attackedLocation="Volkar"..playerDetails.mage
												end
											end
											--
											if terrain.getName()~="Volkare's Camp" then
												if playerDetails.defeatedCities[terrain.guid]~=nil then
													keepShieldMatch[keepSearch]["cityShield"]=true
													if keepShieldMatch[keepSearch]["city"]==true then cityFound=terrain.getGMNotes() end
												end
											else
												if volkareCampKeepAllowed==true and playerDetails.defeatedCities[terrain.guid]~=nil then
													keepShieldMatch[keepSearch]["keepShield"]=true
													if keepShieldMatch[keepSearch]["keep"]==true then keepFound=true end
												end
											end
											if gStates.gameScenario=="The Gauntlet" or gStates.gameScenario=="The Hidden Valley Blitz"
												or gStates.gameScenario=="The Hidden Valley Blitz" or gStates.gameScenario=="The Realm of the Dead Blitz"
												or gStates.gameScenario=="Life and Death" or gStates.gameScenario=="Dungeon Lords"
												or gStates.gameScenario=="Druid Nights" or gStates.gameScenario=="Mines Liberation" then
												keepShieldMatch[keepSearch]["cityShield"]=true
												if keepShieldMatch[keepSearch]["city"]==true then cityFound=terrain.getGMNotes() end
												playerDetails.defeatedCities[terrain.guid]="Assist"
											end
										end
										--flip garrisons during the day
										if gStates.autoFlip==true and gStates.dayRound==true and turnOrder[gStates.turnNumber].mage==avatar.mage and terrain.getRotationValues()[2]~=nil and (terrain.getRotationValues()[2].value=="Mage Tower Garrison" or terrain.getRotationValues()[2].value=="Keep Garrison" or terrain.getRotationValues()[2].value=="Marauding Elementalist") then--and gStates.preEndTurn==false
											if terrain.is_face_down==true then terrain.flip() broadcastToAll("{en}Site Garrison Revealed{ru}Гарнизон Укрепленного места раскрыт{zh-cn}守军揭示了{ko}수비자가 공개되었습니다.{es}Guarnición del Sitio Revelada{fr}La Garnison du Site Révélée{pt-br}Lugar de Guarnição Revelada{de}Standort Garnison aufgedeckt", {1,1,0.5}) end
										end
										--flip ruins at night and Lost Relic dragons day or night
										if gStates.autoFlip==true and turnOrder[gStates.turnNumber].mage==avatar.mage and ((playerDetails.avatarLocation=="ruin" and keepSearch==1) or (terrain.getRotationValues()[2]~=nil and terrain.getRotationValues()[2].value:sub(-8)=="Draconum")) then--and gStates.preEndTurn==false
											if terrain.is_face_down==true then
												terrain.flip()
												if playerDetails.avatarLocation=="ruin" then broadcastToAll("{en}Ruin Site Revealed{ru}Руины были раскрыты{zh-cn}废墟板块被揭示了{ko}유적 장소 공개됨{es}Sitio de Ruinas Revelado{fr}Site de Ruines Révélé{pt-br}Lugar de Ruinas Revelado{de}Ruinenstätte aufgedeckt", {1,1,0.5}) end
												if playerDetails.avatarLocation~="ruin" then broadcastToAll("Draconum Revealed", {1,1,0.5}) end
											end
										end
									end
								end
								local avatarAdjust={{-2.39, 0}, {1.2, -2.05}, {2.39, 0}, {1.2, 2.05}, {-1.2, 2.05}, {-2.39, 0}, {0, 0}}
								avatarPos[1]=avatarPos[1]+avatarAdjust[keepSearch][1]
								avatarPos[3]=avatarPos[3]+avatarAdjust[keepSearch][2]
								if cityFound=="False" then playerDetails.nearCity=false
								else playerDetails.nearCity=true end
								if keepFound==true then	playerDetails.nearKeep=true
								else playerDetails.nearKeep=false end
							end
							if avatarPos[3]<-20 then playerDetails.avatarLocation="portal" end
							break
						end
					end
					if turnOrder[gStates.turnNumber].mage==avatar.mage and player_color~=nil and gStates.preEndTurn==false and avatarChangedHex==true and
						apocalypseDragonLairContainsPosition~=nil and apocalypseDragonLairContainsPosition(dropped_object.getPosition())==true and
						gStates.apocalypseDragonDefeated~=true then
						turnOrder[gStates.turnNumber].avatarLocation="apocalypse dragon"
						attackedLocation=nil
						local dragonApproach=nil
						if avatarChangedHex==true and playerPickedUpPos[1]~=nil then dragonApproach={playerPickedUpPos[1],playerPickedUpPos[2],playerPickedUpPos[3]} end
						apocalypseDragonBeginLairAssault(gStates.turnNumber,dragonApproach)
					end
					if horsemenGladeAssault==true then
						if avatarChangedHex==true and playerPickedUpPos[1]~=nil then assaultApproachOrigin={playerPickedUpPos[1],playerPickedUpPos[2],playerPickedUpPos[3]} end
						local target=dropped_object.getPosition()
						assaultTargetPosition={target[1],target[2],target[3]}
						againstHorsemenBeginGladeAssault(gStates.turnNumber,assaultApproachOrigin)
					elseif attackedLocation~=nil then
						--Keep the actual hex this assault location was entered from. Long moves are deliberately
						--left ambiguous so the wall interface can ask which side was used.
						if avatarChangedHex==true and playerPickedUpPos[1]~=nil then assaultApproachOrigin={playerPickedUpPos[1], playerPickedUpPos[2], playerPickedUpPos[3]} end
						local target=dropped_object.getPosition()
						assaultTargetPosition={target[1], target[2], target[3]}
						local targetFeature=turnOrder[gStates.turnNumber].avatarLocation
						if (targetFeature=="keep" or targetFeature=="mage tower") and wallAssaultChoiceResult==nil and wallAssaultChoiceNeeded(assaultTargetPosition, assaultApproachOrigin)==true then showWallAssaultChoice("attackLocation", attackedLocation, player_color)
						else attackLocation(nil, "-1", attackedLocation) end
					end
					--adjust the hand size
					local cityConversion={["White City"]=GUID.zone.whiteCity, ["Blue City"]=GUID.zone.blueCity, ["Red City"]=GUID.zone.redCity, ["Green City"]=GUID.zone.greenCity}
					local previousHand=turnOrder[gStates.turnNumber].hand
					local handBonusSource=nil
					local raisedReturnCity=(gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz") and gStates.volkareRaisedCity==true
					local nearCityForHand=turnOrder[gStates.turnNumber].nearCity==true and raisedReturnCity~=true
					if (turnOrder[gStates.turnNumber].mage==avatar.mage and turnOrder[gStates.turnNumber].nearKeep==true) or nearCityForHand then
						if nearCityForHand and cityFound~="False" then
							if turnOrder[gStates.turnNumber].defeatedCities[cityScriptZones[cityConversion[cityFound]].cityGUID]=="Lead" then turnOrder[gStates.turnNumber].hand=turnOrder[gStates.turnNumber].baseHand+2 handBonusSource="City" end
							if turnOrder[gStates.turnNumber].defeatedCities[cityScriptZones[cityConversion[cityFound]].cityGUID]=="Assist" then turnOrder[gStates.turnNumber].hand=turnOrder[gStates.turnNumber].baseHand+1 handBonusSource="City" end
						end
						if (turnOrder[gStates.turnNumber].nearKeep==true and nearCityForHand==false) or
							(turnOrder[gStates.turnNumber].nearKeep==true and nearCityForHand==true and turnOrder[gStates.turnNumber].keepsBeat>1) then
							turnOrder[gStates.turnNumber].hand=turnOrder[gStates.turnNumber].baseHand+turnOrder[gStates.turnNumber].keepsBeat
							if turnOrder[gStates.turnNumber].keepsBeat>0 then handBonusSource="Keep" end
						end
					else
						turnOrder[gStates.turnNumber].hand=turnOrder[gStates.turnNumber].baseHand
					end
					if turnOrder[gStates.turnNumber].hand~=previousHand then
						if handBonusSource=="City" then broadcastToAll("{en}Hand size increased from proximity to City{ru}Предел карт в руке увеличен из-за близости города{zh-cn}手牌数量因靠近城市而增加{ko}인접한 도시에 의해 카드 보유 제한이 증가했습니다{es}El tamaño de la mano aumentó de la proximidad a la Ciudad.{fr}La taille de la main a augmenté de la proximité à la Ville{pt-br}O tamanho da mão aumentou devido à proximidade da Cidade{de}Handgröße durch Nähe zur Stadt erhöht", positionToColor(gStates.turnNumber)) end
						if handBonusSource=="Keep" then broadcastToAll("{en}Hand size increased from proximity to Keep{ru}Предел карт в руке увеличен из-за близости крепости{zh-cn}手牌数量增加到最大值{ko}인접한 성에 의해 카드 보유 제한이 증가했습니다{es}El tamaño de la mano aumentó de la proximidad a la Fortaleza{fr}La taille de la main a augmenté de la proximité à la Keep{pt-br}O tamanho da mão aumentou com a proximidade de Keep{de}Handgröße erhöht sich durch die Nähe zu Keep", positionToColor(gStates.turnNumber)) end
					end
					--Reset attack icon and interaction after leaving a hex, but preserve an interaction if the avatar was only repositioned on the same hex.
					if turnOrder[gStates.turnNumber].mage==avatar.mage and attackedLocation==nil and horsemenGladeAssault==false and (avatarChangedHex==true or (next(gStates.attackedMonsters)==nil and UI.getAttribute("zigguratPyramidInteract", "active")~="true")) then
						turnOrder[gStates.turnNumber].combatIconHide="None" gStates.monsterOffsetX=0 gStates.monsterOffsetZ=0
					end
					--Avatar location directly changes Plunder/Pursuit availability.
					--Invalidate the cached menu; the normal location UI refresh will rebuild it when relevant.
					outOfTurnUIStateKey=nil
					mainUIUpdate("Updated player location Details")
					--Quest step availability can depend on the active Mage Knight's current map hex.
					--Use the serialized offer refresh instead of touching Object UI directly here. fakeDropAvatar()
					--can reach this delayed location callback while a Quest offer refill is still physically moving cards;
					--apocalypseQuestRefreshOfferButtons() defers safely until that refill has settled.
					if apocalypseQuestsUsed()==true then apocalypseQuestRefreshOfferButtons() end
					if turnOrder[gStates.turnNumber].mage==avatar.mage then refreshFracturedLandsTeleportHighlights() end
					addAvatarButtons()
					if gStates.rampagePursuit==true and gStates.preEndTurn==false then pursuingRampagers(nil, "-1", nil) end
				end
			end
			safeWaitCondition("Events",function() avatarlocationDetails() end, function() return getObjectFromGUID(dropped_object.guid)==nil or dropped_object.resting end, 1.5, function() avatarlocationDetails() end)
			return
		end
	end

	--Update the UI and trigger a Level up if a mage shield was moved manually
	if gStates.firstStarted==true then
		--Fame, Reputation and Quest Score are cached values. If a player manually corrects a physical
		--marker, read the settled marker position back into the same state used by scoring/reporting.
		for a=1, #turnOrder, 1 do
			local fameMoved=dropped_object.guid==turnOrder[a].fameGUID
			local reputationMoved=dropped_object.guid==turnOrder[a].reputationGUID
			local questScoreMoved=dropped_object.guid==turnOrder[a].questScoreGUID
			if fameMoved or reputationMoved or questScoreMoved then
				local playerIndex=a
				safeWaitCondition("Events",function()
					if fameMoved then refreshPlayerFameFromShield(playerIndex)
					elseif reputationMoved then refreshPlayerReputationFromShield(playerIndex)
					else refreshPlayerQuestScoreFromMarker(playerIndex) end
					mainUIUpdate(questScoreMoved and "Quest Score Marker Dropped" or "Fame and Rep Shield Dropped")
				end, function() return dropped_object.resting end)
				break
			end
		end
	end

	--delete a crystal dropped over the crystal area
	if dropped_object.type=="Figurine" then
		local pos=dropped_object.getPosition()
		if pos[3]>=-33 and pos[3]<=-30 and ((pos[1]>=-69 and pos[1]<=-65.5) or (pos[1]>=-29 and pos[1]<=-25.5) or (pos[1]>=11 and pos[1]<=14.5) or (pos[1]>=51 and pos[1]<=54.5)) then
			dropped_object.destruct()
		end
	end
end

--fix for new objects getting existing GUID, and update competative skill location
function __onObjectSpawn_raw(spawn_object)
	if spawn_object==nil or spawn_object.guid==nil then return end
	applyAltViewAngle(spawn_object)
	puppetMasterCheckManualCopyWhenResting(spawn_object)
	--code stops objects getting a GUID of a registered object.
	if spawn_object.getGMNotes()=="Wound" or spawn_object.type=="Figurine" or spawn_object.type=="Deck" then
		if gameCards[spawn_object.guid]~=nil or terrainTiles[spawn_object.guid]~=nil or monsterPugs[spawn_object.guid]~=nil or skillTokens[spawn_object.guid]~=nil then
			safeWaitFrames("Events",function()
				if getObjectFromGUID(spawn_object.guid)~=nil then
					spawn_object.clone({position={spawn_object.getPosition()[1], spawn_object.getPosition()[2]+1, spawn_object.getPosition()[3]}})
					safeWaitFrames("Events",function() spawn_object.destruct() end, 2)
				end
			end, 50)
		end
	end

	--Update icons on state changing Avatar
	if gStates.firstStarted==true then
		for a, details in pairs(mageKnights) do
			if details.model==spawn_object.guid or details.token==spawn_object.guid or details.standee==spawn_object.guid then
				avatarButtonXmlState[spawn_object.guid]=nil
				addAvatarButtons()
				break
			end
		end
	end

	--add volkare's arrows and update GUID used in script
	if spawn_object.guid==mageKnights[#mageKnights-2].model or spawn_object.guid==mageKnights[#mageKnights-2].token or spawn_object.guid==mageKnights[#mageKnights-2].standee then
		gStates.volkareModel=spawn_object.guid
		local scale=spawn_object.getScale()
		if gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz" then
			safeWaitFrames("Events",function() getObjectFromGUID(gStates.volkareModel).addDecal({name="Volkare's Return Guide", url="https://steamusercontent-a.akamaihd.net/ugc/1617311764022517379/17F0D137572FE6672A880B1865AF9D7B66D8061F/",
				position={-1.7, 0.05, 0.0}, rotation={90, 180, 0}, scale={3.24/scale[1], 5.508/scale[3], 1}}) end, 20)
		end
		if gStates.gameScenario=="Volkare's Quest" or gStates.gameScenario=="The War of Four" then
			safeWaitFrames("Events",function() getObjectFromGUID(gStates.volkareModel).addDecal({name="Volkare's Quest Guide", url="https://steamusercontent-a.akamaihd.net/ugc/1617311764022517042/4160839B27C5F84E3D4D860408AE19780E48AEC4/",
				position={1.6, 0.05, 1.4}, rotation={90, 180, 0}, scale={3.6/scale[1], 3.5/scale[3], 1}}) end, 20)
		end
		safeWaitTime("Events",function() getObjectFromGUID(gStates.volkareModel).lock() getObjectFromGUID(gStates.volkareModel).setRotation({0, 180, 0}) end, 3)
		cityLevelButtons(gStates.volkareModel, "Volkar")
	end

	--update Competitive skills
	if (spawn_object.guid=="d90de4" or spawn_object.guid=="676856" or spawn_object.guid=="3bd08e" or spawn_object.guid=="c4546c" or
		spawn_object.guid=="a92d73" or spawn_object.guid=="958209" or spawn_object.guid=="19daf9" or
		spawn_object.guid=="335290" or spawn_object.guid=="e68fed" or spawn_object.guid=="676855" or spawn_object.guid=="c82406") then
		gStates.mageSkills[spawn_object.guid]={spawn_object.getPosition()[1], spawn_object.getPosition()[2], spawn_object.getPosition()[3]}
		if gStates.firstStarted==true then skillButtonActivate() else higherLevelSkillClaimButons() end
	end
	if skillTokens[spawn_object.guid]~=nil and (skillTokens[spawn_object.guid].skillType=="Coop" or skillTokens[spawn_object.guid].skillType=="Comp") and coopCompSkillPlayLocked()==true then safeWaitFrames("Events",function() refreshCoopCompSkillXs() end, 2) end
end

--Alter Fame board Values, Skill register, and Add icons when changing avatar **This script runs when exiting the game**
function __onObjectDestroy_raw(destroyedObj)
	if destroyedObj==nil then return end
	local destroyedGuid=destroyedObj.guid
	local questScorePlayer=apocalypseQuestScoreMarkerPlayerIndex(destroyedGuid)
	if questScorePlayer~=nil then
		if apocalypseQuestScoresRequired()==true then
			broadcastToAll("This scenario can't be run without Quest Scores",{1,1,0.5})
			safeWaitFrames("Events",function() apocalypseQuestRestoreScoreMarker(questScorePlayer,false) end,1)
		elseif gStates.apocalypseQuestScoringDisabled~=true then
			if gStates.apocalypseQuestScoringChoiceLocked==true then
				safeWaitFrames("Events",function() apocalypseQuestRestoreScoreMarker(questScorePlayer,false) end,1)
			else
				apocalypseQuestDisableScoring()
			end
		end
	end
	if destroyedGuid~=nil then
		avatarButtonXmlState[destroyedGuid]=nil
		local puppetPickup=puppetMasterPickup[destroyedGuid]
		if puppetMasterUndoFreshClaim(destroyedGuid,puppetPickup~=nil and puppetPickup.color or nil)~=true then
			if gStates.puppetMasterPuppets~=nil and gStates.puppetMasterPuppets[destroyedGuid]~=nil then
				gStates.puppetMasterPuppets[destroyedGuid]=nil
				if gStates.monsterPerks~=nil then gStates.monsterPerks[destroyedGuid]=nil end
			end
			puppetMasterPickup[destroyedGuid]=nil
		end

		--Remove a skill from register if returned to the bag
		if gStates.mageSkills[destroyedGuid]~=nil and getObjectFromGUID(destroyedGuid)==nil then gStates.mageSkills[destroyedGuid]=nil end
	end

	--Check if a shield has been removed
	local destroyedPursuit=volkarePursuitShieldRegistered(destroyedObj)
	if destroyedPursuit==true and destroyedGuid~=nil and gStates.volkarePursuitShields~=nil then gStates.volkarePursuitShields[destroyedGuid]=nil end
	if destroyedObj.getName()~=nil and (destroyedObj.getName()=="Shield" or destroyedObj.getGMNotes()=="Burned Monastery" or destroyedObj.getName()=="Secret Dungeon" or destroyedObj.getName()=="Secret Tomb") then
		shieldLocation(destroyedObj, {guid=mapArea}, "remove")
	end
end

--Plays pugs for terrain tiles, Disables end turn button, Reduces monastery offer
local zoneEntered=false--used to check if an object hasn't just pased through a zone.
dieRollEnterPause=nil
workingOnTerrain={}
shieldLocationWait=nil
masterOfChaosWait=nil
function __onObjectEnterZone_raw(zone, obj)
	if obj~=nil and apocalypseDragonGroundCombatToken~=nil then
		local active,headName,owner=apocalypseDragonGroundCombatToken(obj.guid)
		if active==true and headName~="Control" and owner~=nil then safeWaitFrames("Events",function() apocalypseDragonRefreshGroundFameGain(owner) end,1) end
	end
	--A scripted Deed transfer may physically cross unrelated scripting zones. Only its destination Deed zone
	--is allowed to react while the card is travelling.
	if zone~=nil and obj~=nil and deedTransferState~=nil and deedTransferState.transit[obj.guid]~=nil and zone.guid~=deedTransferState.transit[obj.guid] then return end
	--Fractured Lands holds a new tile above the map scripting zone while it is being oriented.
	--Done only unlocks it. Its actual fall into this zone clears the orientation controls/state,
	--then continues through the ordinary terrain-entry handler below.
	if zone~=nil and obj~=nil and zone.guid==mapArea and gStates.fracturedLandsOrientation~=nil and gStates.fracturedLandsOrientation.guid==obj.guid then
		if obj.getLock()==true then return end
		obj.clearButtons()
		obj.UI.setXmlTable({{}})
		gStates.fracturedLandsOrientation=nil
		explorePause=false
	end
	--A pending Steady Tempo may be picked up while the player is deciding. Rebuild its controls
	--when it returns to that player's play area, or accept a manual move to Deed/discard as resolution.
	if obj~=nil and isSteadyTempoGUID(obj.guid)==true and gStates.steadyTempoPending~=nil and gStates.steadyTempoPending[obj.guid]~=nil then
		local seatPos=gStates.steadyTempoPending[obj.guid]
		if zone.guid==playerPlayAreas[seatPos] then safeWaitFrames("Events",function() steadyTempoRefreshCard(obj.guid) end, 2)
		elseif zone.guid==deedDeckZones[seatPos] or zone.guid==deedDeckDiscardZones[seatPos] then steadyTempoClearPending(obj.guid) end
	end
	--Meditation / Trance needs its object UI as soon as the played card reaches a player area.
	if obj~=nil and obj.guid==meditationTranceCardGUID and playerZoneLookup[zone.guid]~=nil and playerZoneLookup[zone.guid].kind=="play" then
		safeWaitFrames("Events",function() refreshMeditationTrance() end, 2)
	end
	if gStates.firstStarted==true then
		apocalypseQuestUnderSiegeCardPlayed(zone,obj)
		if obj~=nil and skillTokens[obj.guid]~=nil then
			for playerIndex, details in pairs(turnOrder) do
				if details.seatPos~=nil and zone.guid==playerPlayAreas[details.seatPos] then
					tomeSkillEnteredPlay(obj.guid, playerIndex)
					if skillTokens[obj.guid].skillType=="Coop" or skillTokens[obj.guid].skillType=="Comp" then activateCoopCompSkill(obj.guid, playerIndex) end
					break
				end
			end
		end
		--Check if a turn marker has been flipped
		if zone.guid==turnOrderArea then
			for c, d in pairs(turnOrder) do
				if obj.guid==d.turnOrderTokenGUID then
					safeWaitFrames("Events",function() safeWaitCondition("Events",function()
						local turnOrderTokens=getObjectFromGUID(turnOrderArea).getObjects()
						table.sort(turnOrderTokens, function (k1, k2) return k1.getPosition()[3]>k2.getPosition()[3] end)
						--check if all turn order tokens are present
						if #turnOrderTokens==gStates.playerCount+gStates.coop then
							local posOne=-19.4
							local inOrder=true
							--check turn order tokens fill from 1st to last position
							for a, b in pairs(turnOrderTokens) do
								if b.getPosition()[3]>posOne-0.5 and b.getPosition()[3]<posOne+0.6 then
									posOne=posOne-1.4
									for c, d in pairs(turnOrder) do
										if b.guid==d.turnOrderTokenGUID then turnOrder[c].cutomSort=a break end
									end
								else
									inOrder=false break
								end
							end
							--update turnorder sequence to match token order
							if inOrder==true then
								if getObjectFromGUID("0934f2")~=nil then table.sort(turnOrder, function (k1, k2) return k1.cutomSort < k2.cutomSort end) end
								broadcastToAll("{en}Turn order updated{ru}Порядок хода обновлен{zh-cn}回合顺序更新了{ko}라운드 순서가 업데이트되었습니다{es}Orden de giro actualizado{fr}Ordre de rotation mis à jour{pt-br}Ordem de Turno atualizada{de}Zugreihenfolge aktualisiert", {1,1,0.5})
								mainUIUpdate("Turn marker entered it's zone")
							end
						end
					end, function() return obj.resting end) end, 2)
					break
				end
			end
		end

		--Check if a terrain tile has entered the play area
		if zone.guid==mapArea and terrainTiles[obj.guid]~=nil and workingOnTerrain[obj.guid]~=true then
			if startingMapSetup==true then startingMapTiles[obj.guid]=true end
			workingOnTerrain[obj.guid]=true
				safeWaitTime("Events",function() addAvatarButtons() end, 1.5)
				local playAreaObjects=getObjectFromGUID(mapArea).getObjects()
				local faceUpTerrain={}
				local mapObjectPositions={}
				for _, mapObject in pairs(playAreaObjects) do
					local mapObjectPosition=mapObject.getPosition()
					mapObjectPositions[#mapObjectPositions+1]={guid=mapObject.guid, position=mapObjectPosition}
					if terrainTiles[mapObject.guid]~=nil and mapObject.is_face_down==false then faceUpTerrain[#faceUpTerrain+1]={guid=mapObject.guid, position=mapObjectPosition} end
				end
			local core=0
			local faceUp=	{0.0, 180.0,   0.0}
			local faceDown=	{0.0, 180.0, 180.0}
			local y=2
			--figure out which angle is the north south line
			local northBearing=40
			local startTileGUID=startTerrain.open
			local startBearing=0
			if getObjectFromGUID(startTileGUID)==nil then
				if gStates.gameScenario=="Against the Horsemen Blitz" then startTileGUID=GUID.tile.country01
				else startTileGUID=startTerrain.wedge northBearing=70 end
			end
			local startTileObject=getObjectFromGUID(startTileGUID)
			if startTileObject==nil then workingOnTerrain[obj.guid]=nil return end
			local startTilePosition=startTileObject.getPosition()
			local enteredTilePosition=obj.getPosition()
			startBearing=math.deg(math.atan2(enteredTilePosition[3]-startTilePosition[3], enteredTilePosition[1]-startTilePosition[1]))

			local faceDownTerrain=false
			local errorBroadcast=""
			local function positionLegal(obj)--.guid .is_face_down .getPosition() .getName()
				--Against the Horsemen uses a completely predefined map. Its face-down tiles are already in
				--their legal positions, so ordinary wedge/open/neighbour placement rules must never reject
				--a tile when it is revealed. Keep face-down tiles dormant; once revealed, always populate them.
				if gStates.gameScenario=="Against the Horsemen Blitz" or gStates.gameScenario=="Fury of the Apocalypse Dragon" then
					if obj.faceDown==true then faceDownTerrain=true return false end
					return true
				end

				--Check if a core tile is on the coast of a wedge map
				if terrainTiles[obj.guid].tileType=="core" and northBearing==70 and (obj.bearing<=41 or obj.bearing>=99) and gStates.gameScenario~="Fast Forwarded Conquest" then errorBroadcast="{en}Core Terrain Tiles aren't allowed on the coast{ru}Плитки Развитых земель не могут располагаться на берегу{zh-cn}海岸边不可以部署核心城市板块{ko}중심부 타일은 해안선에 놓일 수 없습니다{es}Las baldosas de terreno del núcleo no están permitidas en la costa{fr}Les tuiles de terrain de base ne sont pas autorisées sur la côte{pt-br}Peças Mapa Centrais não são permitidas na Costa{de}Kernterrainplättchen sind an der Küste nicht erlaubt" return false end

				--Check if a tile is outside of a wedge map
				if northBearing==70 and (obj.bearing<=35 or obj.bearing>=105) then errorBroadcast="{en}Terrain Tile isn't in the Wedge{ru}Плитка земель не находится в форме{zh-cn}地图块不在锥形里 (出界了){ko}지도 타일이 쐐기 안에 있지 않습니다{es}Terrain Tile no está en la cuña{fr}La tuile de terrain n'est pas dans le coin{pt-br}Peça de Terreno não está no Cone{de}Das Geländeplättchen liegt nicht im Keil" return false end

				--Check if tile is on the 4th or 5th column of a limited open map
				if gStates.mapShape:sub(5,5)=="O" or gStates.mapShape:sub(5,5)=="F" then --Open Limited to ? Columns
					local checkUpTo=3
					if gStates.mapShape:sub(21, 21)=="4" then checkUpTo=8 end
					if gStates.mapShape:sub(21, 21)=="3" then checkUpTo=15 end
					local pos=obj.position
					for b=1, checkUpTo, 1 do
						local edge=terrainPlacementEdgeCoordinates[b]
						if ((pos[1]-edge[1])^2)+((pos[3]-edge[2])^2)<1 then
							errorBroadcast=joinLang({"{en}You are playing a {ru}Форма игрового поля - {zh-cn}正在玩的剧本名: {ko}플레이 중인 맵: {es}Estás jugando un {fr}Vous jouez à un {pt-br}Você está jogando um(a) {de}Du spielst gerade ein ", gStates.mapShape, "{en} Game{ru} {zh-cn}. {ko}{es} juegos{fr} Game{pt-br} Jogo{de} Spiel"})
							return false
						end
					end
				end

				--Check if Core tile has at least two neighbor Tiles
				--Check if Country tile has at least one neighbor that has two neighbor Tiles
				--check if an excess terrain tile has at least three neighbors.
				if gStates.gameScenario~="The Gauntlet" and obj.guid~=firstTile and not (obj.guid=="835c91" and (gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz" or gStates.gameScenario=="Volkare's Quest" or gStates.gameScenario=="The War of Four")) then
					local neighboursFound=0
					local neighbourTile=nil
					local adjacentPositions={}
					for c=1, 6, 1 do
						local offset=terrainPlacementNeighbourOffsets[c]
						adjacentPositions[c]={obj.position[1]+offset[1], obj.position[3]+offset[2]}
					end
					for _, b in pairs(faceUpTerrain) do
						if b.guid~=obj.guid then
							local tested=b.position
							for c=1, 6, 1 do
								local toCheck=adjacentPositions[c]
								if ((tested[1]-toCheck[1])^2)+((tested[3]-toCheck[2])^2)<1 then neighboursFound=neighboursFound+1 neighbourTile=b break end
							end
						end
					end
					if neighboursFound==0 then return false end
					if terrainTiles[obj.guid].tileType=="core" and neighboursFound<2 then errorBroadcast="{en}Core Terrain Tiles need two or more neighbours{ru}Плитки Развитых земель должны находиться по соседству с двумя другими землями{zh-cn}核心城市板块需要紧邻两个以上的其他板块{ko}중심부 타일은 최소 2개의 타일과 인접해야 합니다{es}Las baldosas de terreno central necesitan dos o más vecinos{fr}Les tuiles de terrain de base ont besoin de deux voisins ou plus{pt-br}Peças Mapa Centrais precisam de 2 ou mais Vizinhos{de}Kernterrainplättchen benötigen zwei oder mehr Nachbarn" return false end
					if obj.objName=="excess" and neighboursFound<3 then errorBroadcast="{en}Excess Terrain Tiles need three or more neighbours, They're meant to fill holes in the map.{ru}Запасные земели должны примыкать хотя бы к трём другим землям (чтобы заполнить дыры).{zh-cn}多余的地形块需要临近3个或更多板块, 这是为了填补地图上的空位{ko}추가 지도 타일은 최소 3개의 다른 타일과 인접해야 합니다. 구멍을 메운다는 느낌과 유사합니다.{es}Los mosaicos de terreno en exceso necesitan tres o más vecinos. Están destinados a rellenar huecos en el mapa.{fr}Les tuiles de terrain excédentaire ont besoin de trois voisins ou plus, elles sont destinées à combler les trous sur la carte.{pt-br}Peças de Terreno Excessivas precisam de 3 ou mais vizinhos. Elas são para preencher buracos no mapa{de}Überschüssige Geländeplättchen brauchen drei oder mehr Nachbarn, sie sollen Löcher auf der Karte füllen." return false end
					if terrainTiles[obj.guid].tileType~="core" and neighboursFound<=1 then
						neighboursFound=0
						if neighbourTile~=nil then
							local neighbourPositions={}
							for c=1, 6, 1 do
								local offset=terrainPlacementNeighbourOffsets[c]
								neighbourPositions[c]={neighbourTile.position[1]+offset[1], neighbourTile.position[3]+offset[2]}
							end
							for _, b in pairs(faceUpTerrain) do
								if b.guid~=obj.guid then
									local tested=b.position
									for c=1, 6, 1 do
										local toCheck=neighbourPositions[c]
										if ((tested[1]-toCheck[1])^2)+((tested[3]-toCheck[2])^2)<1 then neighboursFound=neighboursFound+1 break end
									end
								end
							end
							if neighboursFound<2 then errorBroadcast="{en}Country Terrain Tiles can't be strung out that far{ru}Плитки Диких земель не могут вытягиваться так далеко{zh-cn}乡村板块不能铺那么远{ko}교외 타일은 그렇게 놓일 수 없습니다{es}Las baldosas de terreno rural no se pueden colocar tan lejos{fr}Les tuiles de terrain de campagne ne peuvent pas être enfilées aussi loin{pt-br}Peças Mapa de Campo não podem ser colocados tão longe{de}Land-Terrainplättchen können nicht so weit aufgereiht werden" return false end
						end
					end
				end

				--Check if a City tile is played to wrong side in Life and Death
				if gStates.gameScenario=="Life and Death" and getObjectFromGUID(GUID.bag.terrain.stack).getQuantity()==1 then
					if obj.guid==GUID.tile.city08 and obj.bearing<=northBearing-1 then --red city
						errorBroadcast="{en}Red City needs to be placed in the Northern section{ru}Земля с красным городом не может быть размещена на юге{zh-cn}红色城市需要放在靠北边{ko}빨간색 도시는 북쪽에 놓여야합니다.{es}Red City debe colocarse en la sección Norte{fr}Red City doit être placé dans la section Nord{pt-br}Cidade Vermelha precisa ser colocada na sessão Norte{de}Die rote Stadt muss in den nördlichen Abschnitt gelegt werden"
						return false
					end
					if obj.guid==GUID.tile.city05 and obj.bearing>=northBearing+1 then --green city
						errorBroadcast="{en}Green City needs to be placed in the Southern section{ru}Земля с зелёным городом не может быть размещена на севере{zh-cn}绿色城市需要放置在南边部分{ko}녹색 도시는 남쪽에 놓여야합니다{es}Green City debe colocarse en la sección Sur{fr}Green City doit être placé dans la section Sud{pt-br}Cidade Verde precisa ser colocada na parte Sul do mapa{de}Grüne Stadt muss in die südliche Sektion gelegt werden"
						return false
					end
				end

				--Check if a terrain tile is face up
				if obj.faceDown==true then faceDownTerrain=true return false end
				return true
			end

			--make predefined maps highlight red
			if gStates.mapShape:sub(5,5)=="P" and gStates.gameScenario~="The Gauntlet" and gStates.gameScenario~="Against the Horsemen Blitz" and gStates.gameScenario~="Fury of the Apocalypse Dragon" then--predefined
				for _, mightBeMap in pairs(playAreaObjects) do
					if terrainTiles[mightBeMap.guid]~=nil then
						if positionLegal({guid=mightBeMap.guid, faceDown=false, bearing=startBearing, objName=mightBeMap.getName(), position={mightBeMap.getPosition()[1], 0, mightBeMap.getPosition()[3]}})==false then
							mightBeMap.setColorTint({r=1.0, g=0.7, b=0.7})--colour tint red
						else
							if gStates.nightTint==true then mightBeMap.setColorTint({r=0.6, g=0.6, b=0.6}) else mightBeMap.setColorTint({r=1.0, g=1.0, b=1.0}) end--colour off
						end
					end
				end
			end

			--deploy monster token if terrain tile is deployed correctly
			if positionLegal({guid=obj.guid, faceDown=obj.is_face_down, bearing=startBearing, objName=obj.getName(), position={obj.getPosition()[1], 0, obj.getPosition()[3]}})==true then
				againstDragonRevealLair(obj)
				if apocalypseIsHereTerrainRevealed~=nil then apocalypseIsHereTerrainRevealed(obj) end
				--Check if the object is a core tile and unlock elite units
				if terrainTiles[obj.guid].tileType=="core" and (obj.guid~="835c91" or (obj.guid=="835c91" and gStates.volkareCampAsCity==true)) and gStates.gameScenario~="First Reconnaissance" and gStates.gameScenario~="Conquer and Hold" and gStates.gameScenario~="Fury of the Apocalypse Dragon" then
					gStates.playedCoreTiles=gStates.playedCoreTiles+1
					gStates.eliteUnitsUsed=true
					if gStates.playedCoreTiles==1 then broadcastToAll("{en}Elite Units are included in the next Offer{ru}Элитные отряды будут доступны в следующем Раунде{zh-cn}精英部队包含在下个供应区{ko}다음 라운드부터 엘리트 유닛이 추가됩니다{es}Las Unidades Elite están incluidas en la próxima Oferta{fr}Les unités Elite sont incluses dans la prochaine Offre{pt-br}Unidades Elite estão incluídas na próxima oferta{de}Eliteeinheiten sind im nächsten Angebot enthalten", {1,1,0.5}) end
					core=1
				end

				--Highlight legal tile plays
				if gStates.gameScenario~="Volkare's Quest" and gStates.gameScenario~="The Gauntlet" and gStates.gameScenario~="The War of Four" and gStates.gameScenario~="Against the Horsemen Blitz" and gStates.gameScenario~="Fury of the Apocalypse Dragon" then
					local gridType=""
					if scenarioList[gStates.scenarioRef][gStates.playersRef].mapShape=="{en}Open Limited to 4 Columns{ru}Открытое поле с ограничением в 4 ряда{zh-tw}4 列的限制開放地圖{zh-cn}4 列的限制开放地图 {ko}4열 제한{es}Abierto Limitado a 4 Columnas{fr}Ouvert Limité à 4 Colonnes{pt-br}Aberto Limitado a 4 Colunas{de}Offen Begrenzt auf 4 Spalten" then gridType="https://steamusercontent-a.akamaihd.net/ugc/1674736055049111266/7BC768B7CD64E6018EBEC720559690409F4BA555/" end--4
					if scenarioList[gStates.scenarioRef][gStates.playersRef].mapShape=="{en}Open Limited to 3 Columns{ru}Открытое поле с ограничением в 3 ряда{zh-tw}3 列的限制開放地圖{zh-cn}3 列的限制开放地图 {ko}3열 제한{es}Abierto Limitado a 3 Columnas{fr}Ouvert Limité à 3 Colonnes{pt-br}Aberto Limitado a 3 Colunas{de}Offen Begrenzt auf 3 Spalten" then gridType="https://steamusercontent-a.akamaihd.net/ugc/1674736055049110361/978D612A44ADDE6E1630965A311722114BA28AE5/" end--3
					if scenarioList[gStates.scenarioRef][gStates.playersRef].mapShape=="{en}Fully Open{ru}Полностью открытое поле{zh-tw}完全開放地圖{zh-cn}完全开放地图{ko}전체 개방형{es}Totalmente Abierto{fr}Entièrement Ouvert{pt-br}Totalmente Aberto{de}Vollständig Offen" then gridType="https://steamusercontent-a.akamaihd.net/ugc/1674736055049031257/2457D03CE33118D57CD456183026FEB596CF6A3A/" end--fully
					if scenarioList[gStates.scenarioRef][gStates.playersRef].mapShape=="{en}Wedge{ru}Клиновидное поле{zh-tw}錐形地圖{zh-cn}锥形地图{ko}쐐기형{es}En Cuña{fr}Coin{pt-br}Cônico{de}Keil" then gridType="https://steamusercontent-a.akamaihd.net/ugc/1674736055049113832/44EE3C6AA10498BCD1B46040AD18631BFD580AC4/" end--Wedge
					local terrainDecals={}
					gStates.exploreButtons={{}}
					if gridType~="" then terrainDecals[#terrainDecals+1]={name="Terrain Grid", url=gridType, position={-16.825, 0.99, 0.55}, rotation={90.0, 0.0, 0.0}, scale={60, 60, 1}} end
					local terrainSpots={{-24.0301, 0.99, -16.0837}, {-30.0303, 0.99, -14.0052}, {-36.0305, 0.99, -11.9267}, {-19.2300, 0.99, -11.9267},
										{-25.2302, 0.99,  -9.8482}, {-31.2303, 0.99,  -7.7696}, {-14.4298, 0.99,  -7.7696}, {-20.4300, 0.99,  -5.6911},
										{-37.2305, 0.99,  -5.6911}, { -9.6297, 0.99,  -3.6126}, {-26.4302, 0.99,  -3.6126}, {-32.4304, 0.99,  -1.5341},
										{-15.6299, 0.99,  -1.5341}, { -4.8295, 0.99,   0.5445}, {-38.4306, 0.99,   0.5445}, {-21.6300, 0.99,   0.5445},
										{-10.8297, 0.99,   2.6230}, {-27.6302, 0.99,   2.6230}, {-33.6304, 0.99,   4.7015}, {-16.8299, 0.99,   4.7015},
										{-0.02940, 0.99,   4.7015}, { -6.0278, 0.99,   6.7794}, {-22.8301, 0.99,   6.7794}, {-28.8303, 0.99,   8.8586},
										{-12.0297, 0.99,   8.8586}, {  4.7708, 0.99,   8.8586}, {-18.0299, 0.99,  10.9371}, { -1.2294, 0.99,  10.9371},
									{ -7.2296, 0.99,  13.0156}, {-24.0301, 0.99,  13.0156}, {-30.0303, 0.99,  15.0941}, {-13.2298, 0.99,  15.0941},
									{-19.2300, 0.99,  17.0727}, {-25.2302, 0.99,  19.2512}, {-31.2303, 0.99,  21.3297}}
					local testTerrain="core"
					local nameTerrain="dud"
					local terrainStack=getObjectFromGUID(GUID.bag.terrain.stack)
					local leftCountry=getObjectFromGUID(GUID.bag.terrain.leftCountry)
					local leftCore=getObjectFromGUID(GUID.bag.terrain.leftCore)
					local terrainStackObjects=terrainStack.getObjects()
					if #terrainStackObjects>0 then
						local nextTerrainIndex=terrainStack.getQuantity()-1
						testTerrain=terrainStackObjects[#terrainStackObjects].guid
						for _, containedTerrain in pairs(terrainStackObjects) do
							if containedTerrain.index==nextTerrainIndex then testTerrain=containedTerrain.guid break end
						end
					else
						nameTerrain="excess"
						testTerrain="country"
					end
					if terrainStack.getQuantity()>0 or leftCountry.getQuantity()>0 or leftCore.getQuantity()>0 then
						for _, terTile in pairs(terrainSpots) do
							local found=false
							for _, mightBeMap in pairs(faceUpTerrain) do
								local existingTile=mightBeMap.position
								if ((terTile[1]-existingTile[1])^2)+((terTile[3]-existingTile[3])^2)<1 then found=true break end
							end
							if found==false and positionLegal({guid=testTerrain, faceDown=false, objName=nameTerrain, position=terTile, bearing=math.deg(math.atan2(terTile[3]-startTilePosition[3], terTile[1]-startTilePosition[1]))})==true then--country tile guid stand-in
								terrainDecals[#terrainDecals+1]={name="Legal Play", url="https://steamusercontent-a.akamaihd.net/ugc/1833526258732421084/29942DB5776ABA4145E9E115D1C893574C9A737A/", position=terTile, rotation={90.0, 0.0, 0.0}, scale={6, 6, 1}}
								gStates.exploreButtons[#gStates.exploreButtons+1]={tag="Button", attributes={id="f2291a"..terTile[1]..","..terTile[3], onClick="global/exploreMap", onMouseDown="global/buttonClicked", onMouseUp="global/buttonClicked", height=150, width=500, tilePosX=terTile[1], tilePosZ=terTile[3], position=(-terTile[1]*100).." "..(-terTile[3]*100).." -1100", rotation="0 0 180", scale="0.38 0.38"},
										children={	{tag="Image", attributes={id="f2291a"..terTile[1]..","..terTile[3].."Image", image="Sliced Button/Button Object Active", type="Sliced"}},
													{tag="HorizontalLayout", attributes={padding="25 25 25 25"},
													children={{tag="Text", attributes={id="f2291a"..terTile[1]..","..terTile[3].."Text", font="Fonts/MKCardText", offsetXY="0 1", fontSize="90", fontStyle="Normal", alignment="MiddleCenter", resizeTextForBestFit="true", resizeTextMaxSize="90", text="{en}EXPLORE{ru}ИССЛЕДОВАТЬ{zh-cn}探索{ko}타일 공개{es}EXPLORAR{fr}EXPLORER{pt-br}EXPLORAR{de}ERKUNDEN SIE"}}}}}}
								--record all the potential future hexes as "explore" so the move can calculate for it.
							end
							end
						end
						for _, teleportDecal in pairs(fracturedLandsTeleportDecals()) do terrainDecals[#terrainDecals+1]=teleportDecal end
						Global.setDecals(terrainDecals)
						getObjectFromGUID("f2291a").UI.setXmlTable(gStates.exploreButtons)
						--Now that the complete legal EXPLORE set is known, place each City card once at its closest legal position.
						compactCityCardsAfterExplore(mapObjectPositions)
				end

				--Against the Apocalypse destroyed terrain
				if gStates.gameScenario=="Against the Apocalypse Blitz" and gStates.tacticShown==false and obj.getName()~="excess" then
					destroyRestoreLocation(nil, "-1", "id", "destroy", obj)
				end

					--Play the correct pugs for the terrain tile
					local tokenWait=0
					local tokenRefillFrame=nil
					local tileRotation=math.floor(((180-(180-obj.getRotation()[2]))/60)+0.5)*60
					if tileRotation<0 then tileRotation=tileRotation+360 end
					if tileRotation>=360 then tileRotation=tileRotation-360 end
					for hexLocation, hexFeature in pairs(terrainTiles[obj.guid].hexFeature) do
						--Only run the all-pile refill once at each deployment step. Several hexes often share the same tokenWait.
						if tokenRefillFrame~=tokenWait+2 then tokenRefillFrame=tokenWait+2 safeWaitFrames("Events",function() tokenRefill() end, tokenRefillFrame) end
					safeWaitFrames("Events",function()
						local params={}
						--don't deploy token if megapolis is being played
						local free=true
						if gStates.megapolis>gStates.cityTiles-#gStates.citiesPlayed
							and (obj.guid==GUID.tile.city05 or obj.guid==GUID.tile.city06 or obj.guid==GUID.tile.city07 or obj.guid==GUID.tile.city08)
							and tonumber(hexLocation)==tileRotation then
							megapolisSuppressTerrainHex(obj,hexFeature,false)
							free=false
						end
						--deploy monster token if hex is free.
						if free==true then
							if gStates.playedAllready[obj.guid]~=true then
								if gStates.gameScenario=="Dungeon Lords" and gStates.tacticShown==false and (hexFeature=="village" or hexFeature=="monastery") then
									dungeonLordsQueueSecretSite(obj,hexLocation,hexFeature)
								end
								--if a monastery tile is placed start dealing advanced actions
								if hexFeature=="monastery" then playMonastery() end

								local tokenPileGreen=monsterPiles.green--Standard green Tokens
								local tokenPileBrown=monsterPiles.tan--Standard Brown Tokens
								local tokenPileRed=	 monsterPiles.red--Standard Red Tokens
								--Rampaging Orcs & Draconum
								if hexFeature=="rampaging" or hexFeature=="draconum" or
									(gStates.gameScenario=="The Chaos Rift" and (hexFeature=="village" or ((hexFeature=="mine" or hexFeature=="") and obj.guid==GUID.tile.city08))) then
									playRampagingTokens(obj, startBearing, northBearing, hexLocation, hexFeature, true, startingMapTiles[obj.guid]~=true)
								end

								--Mine
								if hexFeature=="mine" and gStates.gameScenario=="Mines Liberation" then
									if core==1 then tokenPileGreen=tokenPileRed end
									if getObjectFromGUID(tokenPileBrown).getQuantity()>0 and getObjectFromGUID(tokenPileGreen).getQuantity()>0 then
										local pos={angleToXY(obj, hexLocation)[1]-0.1, y, angleToXY(obj, hexLocation)[2]-0.1}
										local token=getObjectFromGUID(tokenPileBrown).takeObject({rotation=faceDown, position=pos})
										gStates.monsterPlayLocation[token.guid]=pos
										gStates.mineMonsterQty[obj.guid]={[token.guid]="alive"}
										token.addDecal({name="NightRules", position={0.85, 0.15, -0.85}, rotation={90, 180, 0}, scale={0.6, 0.6, 1}, url=nightRulesDecal})
										if gStates.monsterPerks[token.guid]==nil then gStates.monsterPerks[token.guid]={nightRules=true} else gStates.monsterPerks[token.guid].nightRules=true end
										local token=getObjectFromGUID(tokenPileGreen).takeObject({rotation=faceUp, position={pos[1]+0.2, pos[2]+0.5, pos[3]+0.2}})
										gStates.monsterPlayLocation[token.guid]={pos[1]+0.2, pos[2]+0.5, pos[3]+0.2}
										gStates.mineMonsterQty[obj.guid][token.guid]="alive"
										token.addDecal({name="NightRules", position={0.85, 0.15, -0.85}, rotation={90, 180, 0}, scale={0.6, 0.6, 1}, url=nightRulesDecal})
										if gStates.monsterPerks[token.guid]==nil then gStates.monsterPerks[token.guid]={nightRules=true} else gStates.monsterPerks[token.guid].nightRules=true end
									else
										broadcastToAll("{en}Sorry, there are no tokens left to deploy{zh-cn}抱歉，没有token可供部署{ko}여분의 토큰이 없습니다{es}Lo sentimos, no quedan tokens para implementar{fr}Désolé, il n'y a plus de jetons à déployer{pt-br}Desculpe, Não tem Fichas sobrando para distribuir", warningColor)
									end
									tokenPileGreen=monsterPiles.green
								end

								--glade
								if hexFeature=="glade" then --and obj.guid~=GUID.tile.city05 then--stopped it happening on the green city tile but can't figure out why...
									local pos=obj.getPosition()
									local warOfFourDeploy=false
									local edgeCoordinates={	{-38.43,  0.54},  {-33.63,  4.70},  {-28.83,  8.86}, {-24.03, 13.02}, {0, 0},--Far North Column Coordinates
															{-37.23, -5.69},  {-32.43, -1.52},  {-27.63,  2.62}, {-22.83,  6.79}, {-18.02, 10.94},--North Column Coordinates
															{-30.03, -14.01}, {-25.23, -9.84},  {-20.43, -5.69}, {-15.63, -1.54}, {-10.81,  2.63},--South Column Coordinates
															{-24.03, -16.08}, {-19.23, -11.93}, {-14.43, -7.77}, {-9.63,  -3.61}}--Far South Column Coordinates
									for tileLoc, coords in pairs(edgeCoordinates) do
										if math.sqrt(((pos[1]-coords[1])^2)+((pos[3]-coords[2])^2))<1 then warOfFourDeploy=true break end
									end
									if (gStates.gameScenario=="Life and Death" or (gStates.gameScenario=="The War of Four" and warOfFourDeploy==true)) then -- and core==0
										local tokenFaction=nil
										if startBearing<=northBearing or
											(((startBearing<=northBearing+1 and gStates.coop==1) or (gStates.coop==0 and obj.getPosition()[3]<-7 and obj.getPosition()[3]>-8 and obj.getPosition()[1]<-31 and obj.getPosition()[1]>-32)) and math.random(1,2)==1) then
												tokenFaction="Elem"
											if getObjectFromGUID(monsterPiles.greenElem).getQuantity()>0 then tokenPileGreen=monsterPiles.greenElem end
											if getObjectFromGUID(monsterPiles.tanElem).getQuantity()>0 then tokenPileBrown=monsterPiles.tanElem end--elementalist Tokens
										else
											tokenFaction="Dark"
											if getObjectFromGUID(monsterPiles.greenDark).getQuantity()>0 then tokenPileGreen=monsterPiles.greenDark end
											if getObjectFromGUID(monsterPiles.tanDark).getQuantity()>0 then tokenPileBrown=monsterPiles.tanDark end---Dark Crusader Tokens
											local pos={angleToXY(obj,hexLocation)[1], 1.09, angleToXY(obj,hexLocation)[2]}
											local graveyard=getObjectFromGUID(GUID.bag.cemetery).takeObject({rotation=faceUp, position=pos})
											graveyard.lock()
											terrainTiles[obj.guid].hexFeature[hexLocation]="graveyard"
											if gStates.hexOverideSave[obj.guid]==nil then gStates.hexOverideSave[obj.guid]={} end
											gStates.hexOverideSave[obj.guid][hexLocation]="graveyard"
										end
										if getObjectFromGUID(tokenPileBrown).getQuantity()>0 and getObjectFromGUID(tokenPileGreen).getQuantity()>0 then
											local pos={angleToXY(obj,hexLocation)[1]-0.1, y, angleToXY(obj,hexLocation)[2]-0.1}
											for i=1, 2, 1 do
												local monsterPile={tokenPileBrown, tokenPileGreen}
												local token=getObjectFromGUID(monsterPile[i]).takeObject({rotation=faceUp, position={pos[1]+(0.2*(i-1)), pos[2]+(0.5*(i-1)), pos[3]+(0.2*(i-1))}})
												markMonsterFactionSubstitute(token, tokenFaction)
												if terrainTiles[obj.guid].hexFeature[hexLocation]=="graveyard" then
													token.addDecal({name="NightRules", position={0.85, 0.15, -0.85}, rotation={90, 180, 0}, scale={0.6, 0.6, 1}, url=nightRulesDecal})
													if gStates.monsterPerks[token.guid]==nil then gStates.monsterPerks[token.guid]={nightRules=true} else gStates.monsterPerks[token.guid].nightRules=true end
												end
												gStates.monsterPlayLocation[token.guid]={pos[1]+(0.2*(i-1)), pos[2]+(0.5*(i-1)), pos[3]+(0.2*(i-1))}
												if gStates.mineMonsterQty[obj.guid]==nil then gStates.mineMonsterQty[obj.guid]={[token.guid]="alive"} else gStates.mineMonsterQty[obj.guid][token.guid]="alive" end
											end
										else
											broadcastToAll("{en}Sorry, there are no tokens left to deploy{zh-cn}抱歉，没有token可供部署{ko}여분의 토큰이 없습니다{es}Lo sentimos, no quedan tokens para implementar{fr}Désolé, il n'y a plus de jetons à déployer{pt-br}Desculpe, Não tem Fichas sobrando para distribuir", warningColor)
										end
									end

									if gStates.gameScenario=="The Realm of the Dead Blitz" and terrainTiles[obj.guid].tileType=="country" then
										local deploy={	{monster={{monsterPiles.greenDark, -0.1}, {monsterPiles.greenDark, 0.1}}, reward={advancedActionRewardDecal}},
														{monster={{monsterPiles.tanDark, -0.1}, {monsterPiles.greenDark, 0.1}}, reward={spellRewardDecal}},
														{monster={{monsterPiles.redDark,  0.0}}, reward={unitRewardDecal}},
														{monster={{monsterPiles.redDark, -0.1}, {monsterPiles.greenDark, 0.1}}, reward={artifactRewardDecal}},
														{monster={{monsterPiles.redDark, -0.1}, {monsterPiles.tanDark, 0.1}}, reward={artifactRewardDecal, advancedActionRewardDecal}},
														{monster={{monsterPiles.redDark, -0.1}, {monsterPiles.tanDark, 0.0}, {monsterPiles.greenDark, 0.1}}, reward={artifactRewardDecal, spellRewardDecal}}}--this is for five player games, which is currently imposible
										--play Graveyard Token
										params.position={angleToXY(obj,hexLocation)[1], 1.09, angleToXY(obj,hexLocation)[2]}
										params.rotation=faceDown
										local graveyard=getObjectFromGUID(GUID.bag.cemetery).takeObject(params)
										graveyard.lock()
										terrainTiles[obj.guid].hexFeature[hexLocation]="graveyard"
										if gStates.hexOverideSave[obj.guid]==nil then gStates.hexOverideSave[obj.guid]={} end
										gStates.hexOverideSave[obj.guid][hexLocation]="graveyard"
										for index, reward in pairs(deploy[gStates.playedGladeTiles+1].reward) do
											local posOnToken={{0.35, -0.21, 0.35}, {0.0, -0.2, 0.25}}
											graveyard.addDecal({name="Reward", url=reward, position=posOnToken[index], rotation={-90, 0, 0}, scale={0.5, 0.7, 1}})
										end
										--play Monster tokens
										local params2={}
										for index, monsterPile in pairs(deploy[gStates.playedGladeTiles+1].monster) do
											local token=nil
											local monsterPileConvert={[monsterPiles.greenDark]=monsterPiles.green, [monsterPiles.tanDark]=monsterPiles.tan, [monsterPiles.redDark]=monsterPiles.red}
											params2.position={params.position[1]+monsterPile[2], y+(index/2), params.position[3]+monsterPile[2]}
											if getObjectFromGUID(monsterPile[1]).getQuantity()>0 then token=getObjectFromGUID(monsterPile[1]).takeObject(params2) else token=getObjectFromGUID(monsterPileConvert[monsterPile[1]]).takeObject(params2) end
											markMonsterFactionSubstitute(token, "Dark")
											token.addDecal({name="NightRules", position={0.85, 0.15, -0.85}, rotation={90, 180, 0}, scale={0.6, 0.6, 1}, url=nightRulesDecal})
											if gStates.monsterPerks[token.guid]==nil then gStates.monsterPerks[token.guid]={nightRules=true} else gStates.monsterPerks[token.guid].nightRules=true end
											gStates.monsterPlayLocation[token.guid]=params2.position
											if gStates.mineMonsterQty[obj.guid]==nil then gStates.mineMonsterQty[obj.guid]={[token.guid]="alive"} else gStates.mineMonsterQty[obj.guid][token.guid]="alive" end
										end
										gStates.playedGladeTiles=gStates.playedGladeTiles+1
									end
								end

								--Mage Tower
								if hexFeature=="mage tower" then
									params.position={angleToXY(obj, hexLocation)[1], y, angleToXY(obj,hexLocation)[2]}
									params.rotation=faceDown
									if getObjectFromGUID(monsterPiles.purple).getQuantity()>0 then
										local token=getObjectFromGUID(monsterPiles.purple).takeObject(params)
										gStates.monsterPlayLocation[token.guid]=params.position
									else
										broadcastToAll("{en}Sorry, there are no Purple tokens left to deploy{ru}Извините, фиолетовые жетоны закончились.{zh-cn}抱歉，没有棕色标记可供部署{ko}여분의 보라색 토큰이 없습니다{es}Lo sentimos, no quedan tokens púrpuras para implementar{fr}Désolé, il n'y a plus de jetons violets à déployer{pt-br}Desculpe, Não tem Fichas Roxas sobrando para distribuir{de}Leider gibt es keine violetten Plättchen mehr zum Einsetzen", warningColor)
									end
								end

								--Keep
								if hexFeature=="keep" then
									local token={}
									params.position={angleToXY(obj,hexLocation)[1], y, angleToXY(obj, hexLocation)[2]}
									params.rotation=faceDown
									if gStates.gameScenario=="The Hidden Valley Blitz" and obj.guid==GUID.tile.city07 then
										gStates.mineMonsterQty[obj.guid]=gStates.mineMonsterQty[obj.guid] or {}
										local center=angleToXY(obj,hexLocation)
										for i, offset in ipairs({-0.1, 0.1}) do
											params.position={center[1]+offset, y, center[2]+offset}
											local token=takeFactionMonster("green", "Elem", params)
											if token~=nil then
												gStates.monsterPlayLocation[token.guid]=params.position
												gStates.hiddenValleyKeep[i]=token.guid
												gStates.mineMonsterQty[obj.guid][token.guid]="alive"
											else
												broadcastToAll("{en}Sorry, there are no Green tokens left to deploy{ru}Извините, зеленые жетоны закончились.{zh-cn}抱歉，没有绿色标记可供部署{ko}여분의 녹색 토큰이 없습니다{es}Lo sentimos, no quedan tokens verdes para implementar{fr}Désolé, il n'y a plus de jetons verts à déployer{pt-br}Desculpe, Não tem Fichas Verde sobrando para distribuir{de}Tut mir leid, es gibt keine grünen Plättchen mehr zum Einsetzen", warningColor)
											end
										end
									else
										if getObjectFromGUID(monsterPiles.gray).getQuantity()>0 then
											local token=getObjectFromGUID(monsterPiles.gray).takeObject(params)
											gStates.monsterPlayLocation[token.guid]=params.position
										else
											broadcastToAll("{en}Sorry, there are no Gray tokens left to deploy{ru}Извините, серые жетоны закончились.{zh-cn}抱歉，没有灰色标记可供部署{ko}여분의 회색 토큰이 없습니다.{es}Lo sentimos, no quedan tokens grises para desplegar{fr}Désolé, il n'y a plus de jetons gris à déployer{pt-br}Desculpe, Não tem Fichas Cinza sobrando para distribuir{de}Entschuldigung, es gibt keine grauen Plättchen mehr zum Auslegen", warningColor)
										end
									end
								end

								--Ruins
								if hexFeature=="ruin" then
									if gStates.dayRound==false then faceUp=faceDown end
									params.position={angleToXY(obj, hexLocation)[1], y, angleToXY(obj, hexLocation)[2]}
									params.rotation=faceUp
									local token=getObjectFromGUID(monsterPiles.yellow).takeObject(params)
									gStates.monsterPlayLocation[token.guid]=params.position
									faceUp={0.0, 180.0, 0.0}
								end

								--City
								if ((hexFeature or ""):sub(1, 4)=="city" or hexFeature=="Volkare's Camp")
									and (obj.guid~="835c91" or (obj.guid=="835c91" and gStates.volkareCampAsCity==true))
									or (hexLocation=="center" and gStates.removeShadesOfTezlaMonsters~=true and gStates.gameScenario=="Ultimate Conquest" and (obj.guid==GUID.tile.core03 or obj.guid==GUID.tile.core10)) then
									playCity(obj, hexFeature, true)
								end
							end
						end
					end, tokenWait+8)
					if gStates.playedAllready[obj.guid]~=true and
						(hexFeature=="rampaging" or hexFeature=="draconum" or hexFeature=="mage tower" or hexFeature=="keep" or	hexFeature=="ruin" or hexFeature=="Volkare's Camp" or (hexFeature or ""):sub(1, 4)=="city" or
						(hexFeature=="mine" and gStates.gameScenario=="Mines Liberation") or
						(hexFeature=="glade" and (gStates.gameScenario=="Life and Death" or gStates.gameScenario=="The War of Four" or gStates.gameScenario=="The Realm of the Dead Blitz"))) then--and obj.guid~=GUID.tile.city05
						tokenWait=tokenWait+8
					end
				end
				--lock terrain tile if succesfuly deployed all tokens
				safeWaitCondition("Events",function() obj.lock() end, function() return obj.resting end)
				safeWaitFrames("Events",function()
					gStates.playedAllready[obj.guid]=true
					workingOnTerrain[obj.guid]=false
					--Terrain deployment changes the movement graph directly. Refresh it here instead of relying on
					--the later fake avatar drop to eventually trigger a full UI update.
					if gStates.firstStarted==true then
						moveDisplayTerrainCache={signature=nil,hexMap=nil}
						updateMoveDisplay()
					end
					if gStates.gameScenario=="Against the Horsemen Blitz" then againstHorsemenRefreshReveals() end
					fakeDropAvatar()
					apocalypseQuestRefreshOfferButtons()
				end, tokenWait+10)

				--fame gain for played tiles in First Reconnaissance, Lost Relic and The Fractured Lands
				if (gStates.gameScenario=="First Reconnaissance" or gStates.gameScenario=="The Lost Relic Blitz" or gStates.gameScenario=="The Fractured Lands Blitz") and gStates.tacticShown==false then
					turnOrder[gStates.turnNumber].fameGain=turnOrder[gStates.turnNumber].fameGain+1
					local centerFeature=terrainTiles[obj.guid].hexFeature["center"] or ""
					if gStates.gameScenario=="The Lost Relic Blitz" and (centerFeature:sub(1,4)=="city" or centerFeature=="Volkare's Camp") then
						turnOrder[gStates.turnNumber].fameGain=turnOrder[gStates.turnNumber].fameGain+1
					end
					broadcastToAll("{en}Exploring gives fame gain in this Scenario{ru}Исследование дает Славу в этом сценарии{zh-cn}在这个剧本探索板块会增加名望{ko}이 시나리오에선 탐험시 명성을 얻습니다{es}Explorar da fama en este Escenario{fr}L'exploration donne un gain de renommée dans ce Scénario{pt-br}Explorar dá Fama neste Cenário{de}Erkunden bringt in diesem Szenario Ruhmgewinn", {1,1,0.5})
					mainUIUpdate("Fame Gain from exploring")
				end
			else
				workingOnTerrain[obj.guid]=false
				if errorBroadcast~="" then broadcastToAll(errorBroadcast, warningColor) end
				if faceDownTerrain==false then obj.setColorTint({r=1.0, g=0.7, b=0.7}) end
			end
		end

        -- Flip Info cards that match the terrain
        if zone.guid==mapArea and terrainTiles[obj.guid]~=nil and (obj.getRotation()[3] <= 5 or obj.getRotation()[3] >= 355) then
			for hexLocation, hexFeature in pairs(terrainTiles[obj.guid].hexFeature) do
				local infocard={["rampaging"]="cb9285",
								["mage tower"]="29ef37",
								["village"]="3a89e4",
								["draconum"]="c2ada0",
								["keep"]="9c74a9",
								["monastery"]="8dd3c2",
								["maze"]="ad6e2b",
								["monster den"]="3aef9a",
								["dungeon"]="57dcab",
								["glade"]="938554",
								["labyrinth"]="36762b",
								["spawning grounds"]="321d15",
								["tomb"]="1cab50",
								["mine"]="6b9c02", ["camp"]="6b9c02",
			["pyramid"]="467846",
			["ziggurat"]="4efb28",
			["Volkare's Camp"]="0bb2dc",
			["city green"]="8de450", ["city red"]="bd6ab1", ["city blue"]="79a723", ["city white"]="a37b57",
								["oasis"]="4e4bda",
								["ruin"]="0b5e05"}
				local infoGUID=infocard[hexFeature]
				if hexFeature=="mine" then
					local mineColors=terrainTiles[obj.guid].mineColors~=nil and terrainTiles[obj.guid].mineColors[hexLocation] or nil
					if mineColors~=nil and #mineColors==1 then infoGUID="938554" end
				end
				if infoGUID~=nil then
					local citySpecificInfo=hexFeature=="city green" or hexFeature=="city red" or hexFeature=="city blue" or hexFeature=="city white"
					--City colour can change later in playCity() (duplicate/random City replacement).
					--Reveal coloured City cards there, after the final deployed City GUID is known.
					if citySpecificInfo==false then
						local infoCard=getObjectFromGUID(infoGUID)
						if infoCard~=nil then infoCard.setRotationSmooth({0.00, 180.00, 0.00}) end
					end
				end
			end
			local wallList=terrainTiles[obj.guid].wallList
				if wallList~=nil and next(wallList)~=nil then
					local wallInfoCard=getObjectFromGUID("767084")
					if wallInfoCard~=nil then wallInfoCard.setRotationSmooth({0.00, 180.00, 0.00}) end
				end
	        end
		if zone.guid==mapArea and terrainTiles[obj.guid]~=nil then return end

			--Check if a shield, avatar, secret Dungeon, or Secret Tomb has been played to cities or board
		if zone.guid==mapArea or zone.guid==GUID.zone.blueCity or zone.guid==GUID.zone.redCity or zone.guid==GUID.zone.greenCity or zone.guid==GUID.zone.whiteCity or zone.guid==volkare.discZone or zone.guid==darkCrusader.discZone or zone.guid==elementalist.discZone then
			if (obj.getName()=="Shield" or obj.getGMNotes()=="Burned Monastery" or obj.getName()=="Secret Dungeon" or obj.getName()=="Secret Tomb") and obj.getLock()==false then
				if shieldLocationWait==nil then
					shieldLocationWait=safeWaitFrames("Events",function()
						shieldLocation(obj, zone, "enter")
						mainUIUpdate("Shield Dropped")
						if apocalypseQuestsUsed()==true then apocalypseQuestRefreshOfferButtons() end
						shieldLocationWait=nil
					end, 2)
				else
					Wait.stop(shieldLocationWait)
					shieldLocationWait=nil
				end
			else
				if zone.guid==GUID.zone.blueCity or zone.guid==GUID.zone.redCity or zone.guid==GUID.zone.greenCity or zone.guid==GUID.zone.whiteCity or zone.guid==volkare.discZone then
					--Record if avatar is dropped on city card
					for b, mageSearch in pairs(turnOrder) do
						if mageSearch.mage==obj.getName() then
							local found=false
							if gStates.cityMonsterQty[cityScriptZones[zone.guid].cityGUID]~=nil then
								for cityguid, monsters in pairs(gStates.cityMonsterQty[cityScriptZones[zone.guid].cityGUID]) do
									if monsters=="alive" then found=true end
								end
							end
							if found==false then
								if zone.guid~=volkare.discZone then
									broadcastToAll(joinLang({translateWord[mageSearch.mage], "{en} has entered the City.{ru} заходит в Город.{zh-cn}已经进入城市了{ko}: 도시에 입장했습니다.{es} ha entrado en la Ciudad.{fr} est entré dans la Ville.{pt-br} entrou na Cidade.{de} hat die Stadt betreten."}), positionToColor(b))
								else
									broadcastToAll(joinLang({translateWord[mageSearch.mage], "{en} has entered the Camp.{ru} заходит в Лагерь.{zh-cn}已经进入营地了{ko}: 볼케어 진영에 입장했습니다.{es} ha entrado en el Campamento.{fr} est entré dans le Camp.{pt-br} entrou no Acampamento.{de} hat das Lager betreten."}), positionToColor(b))
								end
							else
								if zone.guid~=volkare.discZone then
									broadcastToAll(joinLang({translateWord[mageSearch.mage], "{en} is Assaulting the City.{ru} штурмует Город.{zh-cn}正在突袭城市{ko}: 도시를 강습합니다.{es} está Asaltando la Ciudad.{fr} est à l'assaut de la Ville.{pt-br} invadiu a Cidade.{de} greift die Stadt an."}), positionToColor(b))
								else
									broadcastToAll(joinLang({translateWord[mageSearch.mage], "{en} is Assaulting the Camp.{ru} штурмует Лагерь.{zh-cn}正在突袭营地{ko}: 볼케어 진영을 강습합니다.{es} está Asaltando el Campamento.{fr} est à l'assaut du Camp.{pt-br} invadiu o Acampamento.{de} greift das Lager an."}), positionToColor(b))
								end
							end
							break
						end
					end
				end
			end
			if obj.getName()=="Shield" then gStates.shieldsDropped[obj.guid]=true end
		end

		--Manually destroy a hex
		--if zone.guid==mapArea and obj.getGMnotes()="Destroyed" then
		--	destroyRestoreLocation(nil, "-1", "id", "manualDestroy", obj)
		--end

		--Add xml Image back to Pursuing and Ambushing monster tokens. Non-monsters entering the map
		--never need this Object UI pass, which is relatively expensive in TTS.
		if zone.guid==mapArea and monsterPugs[obj.guid]~=nil and (gStates.rampageAmbush==true or gStates.rampagePursuit==true) then
			local existingButtons=obj.UI.getXmlTable() or {}
			local keptButtons={}
			local uiChanged=false
			for _, xmlParent in pairs(existingButtons) do
				if xmlParent.tag=="Image" then uiChanged=true else keptButtons[#keptButtons+1]=xmlParent end
			end
			existingButtons=keptButtons
			--Ambushing Circle
			if gStates.ambushingMonsters[obj.guid]~=nil then
				uiChanged=true
				existingButtons[#existingButtons+1]={tag="Image", attributes={id="Ambush Circle", height=1100, width=1100,
					position="0 0 -1", rotation="0 0 0", image="Ambush Circle"}}
			end
			--pursuit Shield
			for mage1, monsters in pairs(gStates.pursuingMonsters) do
				if monsters[obj.guid]~=nil then
					for _, mage2 in pairs(mageKnights) do
						if mage2.mage==mage1 then
							uiChanged=true
							existingButtons[#existingButtons+1]={tag="Image", attributes={id="Pursue Shield", height=90, width=90,
								position="0 0 -15", rotation="0 0 180", image="Shield Button "..mage1}}
							local pursuit=monsters[obj.guid]
							if pursuit.stunned==true or pursuit.state=="Stunned" then existingButtons[#existingButtons+1]={tag="Image", attributes={id="Pursuit Stunned", height=110, width=110, position="0 0 -15", rotation="0 0 180", image=pursuitStunnedImageURL}} end
						end
					end
				end
			end
			if uiChanged==true then
				if #existingButtons==0 then existingButtons={{}} end
				obj.UI.setXmlTable(existingButtons)
			end
		end

		--Remove transient decals from anything entering the map, but only write the decal table back
		--when at least one decal actually needs removing.
		if zone.guid==mapArea and obj.guid~=gStates.volkareModel then
			local existingDecals=obj.getDecals() or {}
			local decalTable={}
			local decalsChanged=false
			for _, decalDetails in pairs(existingDecals) do
				if decalDetails.name=="Fortified" or decalDetails.name=="Elemental" or decalDetails.name=="Brutal" or decalDetails.name=="Poison" or decalDetails.name=="Defense" or decalDetails.name:sub(1,4)=="Mine" or decalDetails.name=="NightRules" or decalDetails.name=="Reward" then
					decalTable[#decalTable+1]=decalDetails
				else
					decalsChanged=true
				end
			end
			if decalsChanged==true then obj.setDecals(decalTable) end
			--reset wallFortified
			if gStates.monsterPerks[obj.guid]~=nil and gStates.monsterPerks[obj.guid].wallFortified~=nil then gStates.monsterPerks[obj.guid].wallFortified=nil end
		end

		--Add decals to monster tokens
		if (zone.guid==mapArea or zone.guid==GUID.zone.blueCity or zone.guid==GUID.zone.redCity or zone.guid==GUID.zone.greenCity or zone.guid==GUID.zone.whiteCity) and gStates.monsterPlayLocation[obj.guid]~=nil then
			--fortified
			if monsterPugs[obj.guid]~=nil and monsterPugs[obj.guid].unfortified==nil then
				local target=gStates.monsterPlayLocation[obj.guid]
				local mapObjects=getObjectFromGUID(mapArea).getObjects()
				local terTile, monsterhexBearing=terrainHexAtPosition(target, mapObjects)
				if terTile~=nil and monsterhexBearing~=nil then
					--Add Fortified Site Icon
					if terrainTiles[terTile.guid].hexFeature[monsterhexBearing]=="mage tower" or terrainTiles[terTile.guid].hexFeature[monsterhexBearing]=="keep" then
						--Add Icon
						local found=false
						if obj.getDecals()~=nil then
							for _, decalDetails in pairs(obj.getDecals()) do
								if decalDetails.name=="Fortified" then found=true break end
							end
						end
						if found==false then
							obj.addDecal({name="Fortified", url="https://steamusercontent-a.akamaihd.net/ugc/15769941683634999180/45D8BF9859C1F2C026A3B40DA634B74286E2C3EB/", position={0.7, 0.15, -0.9}, rotation={90, 180, 0}, scale={0.72, 0.72, 1}})
							if gStates.monsterPerks[obj.guid]==nil then gStates.monsterPerks[obj.guid]={fortified=true} else gStates.monsterPerks[obj.guid].fortified=true end
						end
					end
				end
			end
			--City Bonus
			cityBonusDecals(obj, obj)
			safeWaitFrames("Events",function() addAvatarButtons() end, 5)
		end

		--Day Tactic 4 hand bonus only changes when the current player's hand changes.
		if obj~=nil and obj.type=="Card" and gStates.turnNumber>0 and turnOrder[gStates.turnNumber]~=nil and zone.guid==handZones[turnOrder[gStates.turnNumber].seatPos] then scheduleTactic4HandBonusRefresh() end

		--Record Cards in hand as part of a players deed deck
		if obj~=nil and obj.type=="Card" and playerZoneLookup[zone.guid]~=nil and playerZoneLookup[zone.guid].kind=="hand" then
			local handPlayerIndex=turnOrderIndexAtSeat(playerZoneLookup[zone.guid].seatPos)
			if handPlayerIndex~=nil and gameCardType(obj)~="Regular Unit" and gameCardType(obj)~="Elite Unit" then
				for b=1, #turnOrder, 1 do
					local found=false
					for c=1, #turnOrder[b].deadDeckInventory, 1 do
						if obj.guid==turnOrder[b].deadDeckInventory[c] then table.remove(turnOrder[b].deadDeckInventory, c) found=true break end
					end
					if found==true then break end
				end
				turnOrder[handPlayerIndex].deadDeckInventory[#turnOrder[handPlayerIndex].deadDeckInventory+1]=obj.guid
				mainUIUpdate("Card Entered Hand")
			end
		end

		--Offer zone claim buttons and ownership removal
		if obj.guid~=nil and gameCards[obj.guid]~=nil and cardClaimingZones[zone.guid]~=nil then
			local cardSource=cardClaimingZones[zone.guid]
			--Remove card ownership if returned to offer
			for b=1, #turnOrder, 1 do
				local found=false
				for c=1, #turnOrder[b].deadDeckInventory, 1 do
					if obj.guid==turnOrder[b].deadDeckInventory[c] then table.remove(turnOrder[b].deadDeckInventory, c) found=true break end
				end
				if found==true then break end
			end
			--add claim buttons
			if gStates.tacticShown==false and gStates.tacticRemove==false then
				obj.UI.setXmlTable({createClaimButton(obj.guid, cardSource)})
			end
		end

		--protect skill zone from passing through objects
		if zone.guid==GUID.zone.skillOffer then
			zoneEntered=true
			safeWaitFrames("Events",function() zoneEntered=false end, 50)
		end

		--tactic zone claim buttons
		if tacticClaimingZones[zone.guid]~=nil then claimButtonRefresh() end

		--Updates Main UI buttons when anything is played to a mage's play area/deed deck/discard.
		--Keep play-area refreshes distinct so mainUIUpdate can skip deck bookkeeping that cannot have changed.
		if gStates.turnNumber>0 then--makes sure end of round doesn't have errors
			local zoneInfo=playerZoneLookup[zone.guid]
			if zoneInfo~=nil and (zoneInfo.kind=="play" or zoneInfo.kind=="deed" or zoneInfo.kind=="discard") and turnOrderIndexAtSeat(zoneInfo.seatPos)~=nil then
				local seatPos=zoneInfo.seatPos
				if zoneInfo.kind=="deed" and obj~=nil and (obj.type=="Card" or obj.type=="Deck") then
					if obj.type=="Deck" then obj.max_typed_number=1 end
					scheduleEndRoundDeedStateRefresh(seatPos)
				end
				--remove banner card from register if returned to deck.
				if zoneInfo.kind=="discard" and gameCards[obj.guid]~=nil and gameCards[obj.guid].half~=nil then gStates.bannercard[gameCards[obj.guid].half]=nil end
				if zoneInfo.kind=="play" then
					updatePlayAreaObjectState(seatPos, obj, true)
					dayTactic2ExpireIfCardPlayed(seatPos)
					schedulePlayAreaCardScale(seatPos)
					mainUIUpdate("Object entered into play area")
				else mainUIUpdate("Object entered into deed deck or discard") end
			end
		end

		--Object entered player board
		if playerZoneLookup[zone.guid]~=nil and playerZoneLookup[zone.guid].kind=="play" then
			--increment Master of chaos skill
			if obj.guid=="1ff34f" then
				if masterOfChaosPause==false then
					masterOfChaosPause=true
					if masterOfChaosWait~=nil then Wait.stop(masterOfChaosWait) end
					local temp=gStates.masterOfChaos+1
					if temp==7 then temp=1 end
					getObjectFromGUID("1ff34f").setCustomObject({image=masterOfChaosData[temp].image})
					for a=1, #turnOrder, 1 do
						if turnOrder[a].masterOfChaos~=nil then turnOrder[a].masterOfChaos="used" break end
					end
					--Wait.frames(function()
					getObjectFromGUID("1ff34f").reload()
					--end, 50)
					safeWaitFrames("Events",function() masterOfChaosPause=false end, 10)
				end
				return
			end

			--Add combat buttons to monster tokens.
			local addedButtons=monsterObjectButtons(obj)


			--Add fortified symbol
			if gStates.monsterPlayLocation[obj.guid]~=nil and monsterPugs[obj.guid]~=nil and monsterPugs[obj.guid].unfortified==nil then
				local target=gStates.monsterPlayLocation[obj.guid]
				local attackingVolkare=false
				if gStates.cityMonsterQty[volkare.model]~=nil then
					for guid, state in pairs(gStates.cityMonsterQty[volkare.model]) do
						if guid==obj.guid then
							local volkareObj=gStates.volkareModel~=nil and getObjectFromGUID(gStates.volkareModel) or nil
							if volkareObj~=nil then target={volkareObj.getPosition()[1], volkareObj.getPosition()[2], volkareObj.getPosition()[3]} end
							attackingVolkare=true
						end
					end
				end
				local mapObjects=getObjectFromGUID(mapArea).getObjects()
				local terTile, monsterhexBearing=terrainHexAtPosition(target, mapObjects)
				if terTile~=nil and monsterhexBearing~=nil and gStates.volkareState~=nil and gStates.volkareState:sub(1, 9)~="Attacking" then

					--fortified for Volkare's Army
					if attackingVolkare==true and monsterPugs[obj.guid].unfortified==nil and (terrainTiles[terTile.guid].hexFeature[monsterhexBearing]=="mage tower" or terrainTiles[terTile.guid].hexFeature[monsterhexBearing]=="keep") then
						local found=false
						if obj.getDecals()~=nil then
							for _, decalDetails in pairs(obj.getDecals()) do
								if decalDetails.name=="Fortified" then found=true break end
							end
						end
						if found==false then
							obj.addDecal({name="Fortified", url="https://steamusercontent-a.akamaihd.net/ugc/15769941683634999180/45D8BF9859C1F2C026A3B40DA634B74286E2C3EB/", position={0.8, 0.15, -0.8}, rotation={90, 180, 0}, scale={0.72, 0.72, 1}})
							if gStates.monsterPerks[obj.guid]==nil then gStates.monsterPerks[obj.guid]={fortified=true} else gStates.monsterPerks[obj.guid].fortified=true end
						end
					end


				end
			end
			--Manual monster movement cannot assume the current avatar crossed a particular wall.
			--If the avatar is not on an adjacent hex, use the existing wall-choice interface.
			resolveManualMonsterWallFortified(obj)
			if #addedButtons>0 then obj.UI.setXmlTable(addedButtons) end

			--Toggle Half Cards
			if gameCards[obj.guid]~=nil and gameCards[obj.guid].half~=nil then
				if obj.getPosition()[3]>=-38.4 then
					local pass=obj.getPosition()[1]
					obj.setState(2)
					local bannerSeat=playerZoneLookup[zone.guid].seatPos
					safeWaitFrames("Events",function()
						if getObjectFromGUID(gameCards[obj.guid].half)~=nil then
							getObjectFromGUID(gameCards[obj.guid].half).setScale({0.65, 1, 0.65})
							getObjectFromGUID(gameCards[obj.guid].half).setPosition({pass, 1.2, -38.12})
							scheduleUnitLayoutRefresh(bannerSeat)
						end
					end, 3)
				end
			end

			--Add/remove the Card Remove decal when a normal card enters the player play area.
			if obj~=nil and obj.type=="Card" and (gameCards[obj.guid]==nil or gameCards[obj.guid].full==nil) then
				safeWaitFrames("Events",function() local card=getObjectFromGUID(obj.guid) if card~=nil then refreshCardRemoveDecal(card) end end, 2)
			end

			--Add command decal to banner of Command
			if obj.guid=="8dbce4" then
				bannerOfCommandDecal()
				scheduleUnitLayoutRefresh(playerZoneLookup[zone.guid].seatPos)
			end

			--if object is a crystal then alter it's animation.
			local crystalGlow={["Red Mana"]={1, 0, 0}, ["Green Mana"]={0, 1, 0}, ["Blue Mana"]={0, 0, 1}, ["White Mana"]={1, 1, 1}, ["Black Mana"]={0.3, 0.0, 0.6}, ["Gold Mana"]={1, 0.9, 0}}
			if crystalGlow[obj.getName()]~=nil then
				safeWaitTime("Events",function() if getObjectFromGUID(obj.guid)~=nil then obj.AssetBundle.playTriggerEffect(0) end end, 0.1)
				safeWaitTime("Events",function() if getObjectFromGUID(obj.guid)~=nil then obj.AssetBundle.playLoopingEffect(1) end end, 1)
			end
		end

		--Unit Area work is event-driven: split accidental two-card Unit decks only when this area changes.
		local unitZoneInfo=playerZoneLookup[zone.guid]
		if unitZoneInfo~=nil and unitZoneInfo.kind=="unit" then
			local unitSeatPos=unitZoneInfo.seatPos
			if obj.type=="Card" or obj.type=="Deck" then safeWaitFrames("Events",function() separateCombinedUnitsInArea(unitSeatPos) end, 2) end
			scheduleUnitLayoutRefresh(unitSeatPos)
			--Monster tokens may be dropped directly on Units. Give them the same combat controls and reward refresh as Play Area monsters.
			if monsterPugs[obj.guid]~=nil then
				local monsterGUID=obj.guid
				safeWaitFrames("Events",function()
					local monster=getObjectFromGUID(monsterGUID)
					if monster~=nil and objectInPlayerCombatArea(monsterGUID)==true then
						local addedButtons=monsterObjectButtons(monster)
						if #addedButtons>0 then monster.UI.setXmlTable(addedButtons) end
						mainUIUpdate("Monster entered unit area")
					end
				end, 2)
			end
		end

		--Re-add avatar buttons when an avatar enters a non-map zone. Entering the map scripting
		--zone happens before onObjectDrop has recalculated its new hex, so refreshing here would
		--briefly attach the previous location's buttons. The settled drop owns the map refresh.
		if mageKnightAvatarGUIDs[obj.guid]==true and zone.guid~=mapArea then addAvatarButtons() end

		--Change wound cards dropped on units to wound token.
		if playerZoneLookup[zone.guid]~=nil and playerZoneLookup[zone.guid].kind=="unit"
			and obj.type=="Card" and obj.getGMNotes()=="Wound" and obj.getPosition()[3]>=-37
			and ((obj.getPosition()[1]>-65.3 and obj.getPosition()[1]<-42.7) or	(obj.getPosition()[1]>-25.3 and obj.getPosition()[1]<-2.7) or
			(obj.getPosition()[1]>14.7 and obj.getPosition()[1]<37.3) or (obj.getPosition()[1]>54.7 and obj.getPosition()[1]<77.3)) then
			getObjectFromGUID("ab56f3").takeObject({position={obj.getPosition()[1], obj.getPosition()[2], -33.29}, smooth=false})
			obj.destruct()
		end

        --flip ruin down if one of its monsters is Down
        if gStates.ruinMonsters~=nil and gStates.ruinMonsters[obj.guid]~=nil then
            local ruinObj=getObjectFromGUID(gStates.ruinMonsters[obj.guid])
            if ruinObj==nil then
                --The monster token has been reused after its Ruin was removed; discard the stale link.
                gStates.ruinMonsters[obj.guid]=nil
            elseif obj.is_face_down==true then
                if ruinObj.is_face_down==false then ruinObj.flip() end
            else
                local flip=true
                for monsterGUID, _ in pairs(gStates.ruinMonsters) do
                    local monsterObj=getObjectFromGUID(monsterGUID)
                    if monsterObj~=nil and monsterObj.is_face_down==true then flip=false break end
                end
                if flip==true and ruinObj.is_face_down==true then ruinObj.flip() end
            end
        end

		--record potion return locationTest
		if playerZoneLookup[zone.guid]~=nil and playerZoneLookup[zone.guid].kind=="crystal" and
		 	obj.getName():reverse():sub(1, 6)=="noitoP" then
			gStates.mageSkills[obj.guid]={obj.getPosition()[1], obj.getPosition()[2], obj.getPosition()[3]}
		end

		--Lock possesed token on to nearest monster
		if (zone.guid==mapArea or (playerZoneLookup[zone.guid]~=nil and playerZoneLookup[zone.guid].kind=="play"))
			and monsterPugs[obj.guid]~=nil and monsterPugs[obj.guid].pugType=="possessed" then
			attachEnemy(nil, nil, "attach", obj, zone)
		end
	else
		--Update Mage Level Boards before the game starts.
		if gStates.mageKnightLevels==true then
			local zoneInfo=playerZoneLookup[zone.guid]
			if zoneInfo~=nil and (zoneInfo.kind=="play" or zoneInfo.kind=="unit" or zoneInfo.kind=="crystal") then mageLevelBoard() end
		end
	end
	--Mirror dice in source and Start of rounds should have half or more standard color Mana Dice
	if zone.guid==GUID.zone.mana and obj.type=="Dice" then
		if dieRollEnterPause~=nil then Wait.stop(dieRollEnterPause) end
		dieRollEnterPause=safeWaitCondition("Events",function()
			--Start of rounds should have half or more standard color Mana Dice
			local safe=true
			if gStates.tacticRemove==true or gStates.tacticShown==true or gStates.firstStarted~=true then
				local bad={}
				for _, manaDie in pairs(getObjectFromGUID(GUID.zone.mana).getObjects()) do
					if manaDie.type=="Dice" and (manaDie.getRotationValue()=="Black Mana" or manaDie.getRotationValue()=="Gold Mana") then bad[#bad+1]=manaDie end
				end
				if #bad>gStates.diceNeeded/2 or (gStates.startAtNight==true and gStates.currentRound==1) then
					for _, badManaDie in pairs(bad) do badManaDie.randomize() end
					onObjectRandomize({type="Dice"})
					if #bad>0 then safe=false end
				end
			end
			--Mirror mana source dice
			if gStates.firstStarted==true and safe==true then
				mirrorSourceUpdate("dice entered zone")
			end
		end, function()
			local allResting=true
			for _, manaDie in pairs(getObjectFromGUID(GUID.zone.mana).getObjects()) do
				if manaDie.type=="Dice" and manaDie.resting==false then allResting=false break end
			end
			return allResting
		end)
	end
end

--Undo a monastery & re-enable end turn button
dieRollExitPause=nil
function __onObjectLeaveZone_raw(zone, obj)
	if obj~=nil and apocalypseDragonGroundCombatToken~=nil then
		local active,headName,owner=apocalypseDragonGroundCombatToken(obj.guid)
		if active==true and headName~="Control" and owner~=nil then safeWaitFrames("Events",function() apocalypseDragonRefreshGroundFameGain(owner) end,1) end
	end
	--Ignore unrelated zone exits caused solely by a scripted Deed transfer crossing the table.
	if zone~=nil and obj~=nil and deedTransferState~=nil and deedTransferState.transit[obj.guid]~=nil and zone.guid~=deedTransferState.transit[obj.guid] then return end
	--if (obj==nil or obj.name==nil) then return end
	--if getObjectFromGUID(obj.guid)==nil then return end
	if gStates.firstStarted==true then
		if obj~=nil and skillTokens[obj.guid]~=nil and (skillTokens[obj.guid].skillType=="Coop" or skillTokens[obj.guid].skillType=="Comp") then
			for playerIndex, details in pairs(turnOrder) do
				if details.seatPos~=nil and zone.guid==playerPlayAreas[details.seatPos] then coopCompSkillLeftPlayArea(obj.guid, playerIndex) break end
			end
		end
		if gStates.turnNumber>0 and turnOrder[gStates.turnNumber]~=nil and zone.guid==handZones[turnOrder[gStates.turnNumber].seatPos] then scheduleTactic4HandBonusRefresh() end
		if (zone.guid==playerPlayAreas[2] or zone.guid==playerPlayAreas[3] or zone.guid==playerPlayAreas[1] or zone.guid==playerPlayAreas[4]) and getObjectFromGUID(obj.guid)~=nil then
			--remove icons from monsters
			obj.UI.setXmlTable({{}})
			--Only remove the face-down card decal once the card is confirmed outside all player play areas.
			if obj.type=="Card" then
				local cardGUID=obj.guid
				safeWaitFrames("Events",function() local card=getObjectFromGUID(cardGUID) if card~=nil and cardInPlayerPlayArea(cardGUID)==false then removeCardRemoveDecal(card) end end, 2)
			end

			--restore card size, except Unit cards still owned by the overlapping Unit Area layout.
			if ((gameCards[obj.guid]~=nil and gameCards[obj.guid].full==nil) or obj.getGMNotes()=="Wound")
				and not (unitLayoutIsUnit(obj) and unitLayoutObjectInAnyUnitArea(obj.guid)) then obj.setScale({1.5,1,1.5}) end

			safeWaitTime("Events",function()
				--Toggle half cards when picked up.
				if getObjectFromGUID(obj.guid)~=nil then
					if gameCards[obj.guid]~=nil and gameCards[obj.guid].full~=nil and obj.getPosition()[2]>2 then
						obj.setState(1)
						safeWaitFrames("Events",function() if getObjectFromGUID(gameCards[obj.guid].full)~=nil then getObjectFromGUID(gameCards[obj.guid].full).setScale({1.5, 1, 1.5}) end end, 1)
					end

					--if object is a crystal then remove highlight.
					local crystalGlow={["Red Mana"]={1, 0, 0}, ["Green Mana"]={0, 1, 0}, ["Blue Mana"]={0, 0, 1}, ["White Mana"]={1, 1, 1}, ["Black Mana"]={0.3, 0.0, 0.6}, ["Gold Mana"]={1, 0.9, 0}}
					if crystalGlow[obj.getName()]~=nil then
						obj.AssetBundle.playLoopingEffect(0)
					end
				end
			end, 0.22)
			--Decrement Master of chaos skill
			if obj.guid=="1ff34f" and masterOfChaosPause==false then
				if masterOfChaosWait~=nil then Wait.stop(masterOfChaosWait) end
				safeWaitFrames("Events",function() masterOfChaosWait=safeWaitCondition("Events",function()
					for a=1, #turnOrder, 1 do
						if turnOrder[a].masterOfChaos~=nil and turnOrder[a].masterOfChaos~="incrementented in turn" then turnOrder[a].masterOfChaos="available" break end
					end
					getObjectFromGUID("1ff34f").setCustomObject({image=masterOfChaosData[gStates.masterOfChaos].image})
					getObjectFromGUID("1ff34f").reload()
					masterOfChaosWait=nil
				end, function() return getObjectFromGUID("1ff34f").resting end) end, 5)
			end
		end
		--A Card or whole Deck leaving the deed pile can make End Round available.
		if obj~=nil and (obj.type=="Card" or obj.type=="Deck") then
			for _, details in pairs(turnOrder) do if zone.guid==deedDeckZones[details.seatPos] then scheduleEndRoundDeedStateRefresh(details.seatPos) break end end
		end
		--Updates Main UI buttons when anything is removed from a mages play Area
		if gStates.turnNumber>0 then
			for a=1, #turnOrder, 1 do
				local seatPos=turnOrder[a].seatPos
				if zone.guid==playerPlayAreas[seatPos] then
					updatePlayAreaObjectState(seatPos, obj, false)
					schedulePlayAreaCardScale(seatPos)
					if unitLayoutIsCommand(obj) then scheduleUnitLayoutRefreshAfterCommandRelease(seatPos,obj.guid) end
					mainUIUpdate("Object removed from zone")
					break
				elseif zone.guid==deedDeckDiscardZones[seatPos] then
					mainUIUpdate("Object removed from zone")
					break
				end
			end
		end

		--A monster leaving a Unit Area can change pending fame/reputation just like leaving the Play Area.
		local leftUnitArea=false
		local leftUnitSeat=nil
		for seatPos=1,4 do if zone.guid==playerUnitAreas[seatPos] then leftUnitArea=true leftUnitSeat=seatPos break end end
		if leftUnitArea==true then
			if unitLayoutIsCommand(obj) then scheduleUnitLayoutRefreshAfterCommandRelease(leftUnitSeat,obj.guid) else scheduleUnitLayoutRefresh(leftUnitSeat) end
			if unitLayoutIsUnit(obj) then
				local unitGUID=obj.guid
				safeWaitFrames("Events",function()
					local unit=getObjectFromGUID(unitGUID)
					if unit~=nil and unitLayoutObjectInAnyUnitArea(unitGUID)==false then unit.setScale({unitLayoutConfig.cardScale,1,unitLayoutConfig.cardScale}) end
				end,2)
			end
		end
		if leftUnitArea==true and monsterPugs[obj.guid]~=nil then
			local monsterGUID=obj.guid
			safeWaitFrames("Events",function()
				local monster=getObjectFromGUID(monsterGUID)
				if monster~=nil and objectInPlayerCombatArea(monsterGUID)==false then monster.UI.setXmlTable({{}}) end
				mainUIUpdate("Monster removed from unit area")
			end, 2)
		end

		--Remove offer claim buttons
		for zoneGUID, cardSource in pairs(cardClaimingZones) do
			if zone.guid==zoneGUID then
				obj.UI.setXmlTable({{}})
			end
		end

		--Remove tactic claim buttons
		for zoneGUID, cardSource in pairs(tacticClaimingZones) do
			if zone.guid==zoneGUID then
				obj.UI.setXmlTable({{}})
			end
		end

		--Remove Skill claim buttons
		if zone.guid==GUID.zone.skillOffer and zoneEntered==false and gStates.mageSkills[obj.guid]~=nil then
			for skillGUID, _ in pairs(gStates.mageSkills) do
				if getObjectFromGUID(skillGUID)~=nil then getObjectFromGUID(skillGUID).UI.setXmlTable({{}}) end
			end
		end

		--remove decals from anything lifted from the map.
		if zone.guid==mapArea and obj.guid~=gStates.volkareModel and obj.getDecals()~=nil then
			local decalTable={}
			for _, decalDetails in pairs(obj.getDecals()) do
				if decalDetails.name=="Fortified" or decalDetails.name=="Elemental" or decalDetails.name=="Brutal" or decalDetails.name=="Poison" or decalDetails.name=="Defense" or decalDetails.name:sub(1,4)=="Mine" or decalDetails.name=="NightRules" or decalDetails.name=="Reward" then
					decalTable[#decalTable+1]=decalDetails
				end
			end
			obj.setDecals(decalTable)
		end

		if zone.guid==mapArea and obj.guid~=volkare.model and obj.guid~=elementalist.terrainHex and obj.guid~=darkCrusader.terrainHex then
			obj.UI.setXmlTable({{}})
		end

		--Check if a shield has been removed
		if (zone.guid==mapArea)--or zone.guid==GUID.zone.blueCity or zone.guid==GUID.zone.redCity or zone.guid==GUID.zone.greenCity or zone.guid==GUID.zone.whiteCity or zone.guid==volkare.discZone or zone.guid==darkCrusader.discZone or zone.guid==elementalist.discZone)
			and (obj.getName()=="Shield" or obj.getGMNotes()=="Burned Monastery" or obj.getName()=="Secret Dungeon" or obj.getName()=="Secret Tomb") and obj.getLock()==false then
			if shieldLocationWait==nil then
				shieldLocationWait=safeWaitFrames("Events",function() if getObjectFromGUID(obj.guid)~=nil then shieldLocation(obj, zone, "remove") mainUIUpdate("Shield Removed") end shieldLocationWait=nil end, 2)
			else
				Wait.stop(shieldLocationWait)
				shieldLocationWait=nil
			end
		end

		--remove red tint when lifting out terrain tile.
		if zone.guid==mapArea and terrainTiles[obj.guid]~=nil then
			if gStates.dayRound==false then obj.setColorTint({r=0.6, g=0.6, b=0.6}) else obj.setColorTint({r=1.0, g=1.0, b=1.0}) end
		end

		--updata Mirrored source
		if zone.guid==GUID.zone.mana and obj.type=="Dice" then
			if dieRollEnterPause~=nil then Wait.stop(dieRollEnterPause) end
			dieRollEnterPause=safeWaitTime("Events",function()
				mirrorSourceUpdate("object left zone")
			end, 0.5)
		end
	else
		--Update Mage Level Boards before the game starts.
		if gStates.mageKnightLevels==true then
			local playerZones={	"004cca", "9ef3c1", "182df2", "813d11",--Play Area
								"98a462", "0d6195", "648671", "8d6d93",--Unit Area
								"13f39d", "5bb87a", "621d88", "2936ad"}--Crystal inventory
			for _, zoneGUID in pairs(playerZones) do
				if zone.guid==zoneGUID then
					mageLevelBoard()
					break
				end
			end
		end
	end
end

--dice changed or added to mirrored source.
function __onObjectCollisionEnter_raw(registered_object, info)
	if (info==nil or info.collision_object.type==nil) then return end
	if info.collision_object.type=="Dice" then diceResting(info.collision_object, "enter") end
end

--dice removed from mirrored source
function __onObjectCollisionExit_raw(registered_object, info)
	if (info==nil or info.collision_object.type==nil) then return end
	if info.collision_object.type=="Dice" then
		--Return forgotten Mana steal dice.
		if registered_object.guid=="fbd7fd" then
			info.collision_object.setPosition({-12.5+(math.random()*7), 1.5 , -24.0+(math.random()*3.5)})
			return
		end

		--Mirror Source update
		diceResting(info.collision_object, "exit")
	end
end

--Container Shuffling, Image Updating and size changing
function __onObjectEnterContainer_raw(bag, obj)
	--Putting a just-created Puppet in the Trash chest is the physical undo gesture for Puppet Master.
	if bag~=nil and obj~=nil and bag.guid==trashCan then
		local puppetPickup=puppetMasterPickup[obj.guid]
		puppetMasterUndoFreshClaim(obj.guid,puppetPickup~=nil and puppetPickup.color or nil)
	end
	if bag~=nil and obj~=nil and bag.guid==GUID.bag.apocalypseQuestTokens then
		if gStates.apocalypseQuestTokenGUIDs==nil or gStates.apocalypseQuestTokenInBag==nil then apocalypseQuestTokenBagSetup() end
		if gStates.apocalypseQuestTokenGUIDs[obj.guid]==true then
			gStates.apocalypseQuestTokenInBag[obj.guid]=true
			safeWaitFrames("Events",function() apocalypseQuestRefreshReminderCards() end,2)
		end
	end
	if obj~=nil and monsterPugs[obj.guid]~=nil and monsterPugs[obj.guid].pugType=="possessed" and gStates.apocalypsePossessedEnemyByToken~=nil then
		gStates.apocalypsePossessedEnemyByToken[obj.guid]=nil
	end
	if obj~=nil and isSteadyTempoGUID(obj.guid)==true and gStates.steadyTempoPending~=nil and gStates.steadyTempoPending[obj.guid]~=nil then steadyTempoClearPending(obj.guid) end
	meditationTranceContainerEnter(bag, obj)
	scaleBags(bag, obj, "enter")
	scheduleContainerDeckDescriptionRefresh(bag)
	scheduleContainerEndRoundStateRefresh(bag)

	--Shuffles the contents of certain bags when items are dropped in
	local ToBeShuffled = {GUID.bag.skill.arythea,GUID.bag.skill.goldyx,GUID.bag.skill.norowas,GUID.bag.skill.tovak,GUID.bag.skill.krang,GUID.bag.skill.braevalar,GUID.bag.skill.ymirgh,GUID.bag.skill.wolfhawk,GUID.bag.skill.jormund, "8c8a04","46f93a",GUID.bag.terrain.leftCity,GUID.bag.terrain.leftCore,GUID.bag.terrain.leftCountry,GUID.bag.allSkills,"8929f0","3e1fdf",GUID.bag.skill.malek,GUID.bag.skill.zirtae,GUID.bag.skill.coral}
		--Arythea Skills, Goldyx Skills, Norowas Skills, Tovak Skills, Krang Skills, Braevalar Skills, Ymirgh Skills, Wolfhawk Skills, Coral Skills, round order container, City Monster Shuffler, City Tiles, Core Tiles, Country Tiles, All Skill. terrain pile, Mevok Skills, Duscenia Skills, Malek Skills
	local found=false
	if gStates.firstStarted==true then
		for a=1, #ToBeShuffled, 1 do
			if ToBeShuffled[a]==bag.guid then found=true getObjectFromGUID(ToBeShuffled[a]).shuffle() break end
		end
	end

	--removes location data from monster pugs
	if found==false then
		local fracturedRampagePos=nil
		if obj~=nil and gStates.rampagingMonsters[obj.guid]==true and gStates.monsterPlayLocation[obj.guid]~=nil then
			local p=gStates.monsterPlayLocation[obj.guid]
			fracturedRampagePos={p[1],p[2],p[3]}
		end
		if fracturedRampagePos~=nil then fracturedLandsTeleportRecordDefeatedRampager(fracturedRampagePos) end
		gStates.monsterPlayLocation[obj.guid]=nil
		gStates.rampagingMonsters[obj.guid]=nil
		for mage, monster in pairs(gStates.pursuingMonsters) do monster[obj.guid]=nil end
		gStates.ambushingMonsters[obj.guid]=nil
		if fracturedRampagePos~=nil then safeWaitFrames("Events",function() refreshFracturedLandsTeleportHighlights() end, 1) end
	end
	--A Ruin monster stops belonging to that Ruin once it is returned to a container.
	if gStates.ruinMonsters~=nil and gStates.ruinMonsters[obj.guid]~=nil then gStates.ruinMonsters[obj.guid]=nil end
	if gStates.firstStarted==true then
		mainUIUpdate("Object entered container or formed Deck")
	end
end

function __onObjectLeaveContainer_raw(bag, obj)
	if bag~=nil and obj~=nil and bag.guid==GUID.bag.apocalypseQuestTokens then
		if gStates.apocalypseQuestTokenGUIDs==nil or gStates.apocalypseQuestTokenInBag==nil then apocalypseQuestTokenBagSetup() end
		if gStates.apocalypseQuestTokenGUIDs[obj.guid]==true then gStates.apocalypseQuestTokenInBag[obj.guid]=false end
	end
	applyAltViewAngle(obj)
	scheduleContainerDeckDescriptionRefresh(bag)
	scheduleContainerEndRoundStateRefresh(bag)
	--Manual Coral draw: a player-dragged card is held immediately after it leaves the Deed Deck.
	--Scripted takeObject/deal calls also leave the Deck, but are not held, so they pass through untouched.
	if obj~=nil and obj.type=="Card" and obj.guid~="6ecbc6" and coralDrawPending==nil and bagSearch~=bag.guid then
		local playerIndex=coralManualQuickWittedLeaveSource(bag)
		if playerIndex~=nil then
			local seatPos=turnOrder[playerIndex].seatPos
			local deckGuid=bag.guid
			safeWaitFrames("Events",function()
				if obj==nil or obj.isDestroyed() then return end
				local playerColor=obj.held_by_color
				if playerColor~=nil and playerColor~="" and coralDrawPending==nil then
					local authorized=legalPlayerCheck(playerColor, seatPos, "NoDummyException")==true
					coralRestoreManualDraw(playerIndex, deckGuid, obj, authorized)
				end
			end, 3)
		end
	end
	--swap coop skill state when drawn
	if (obj.guid=="3fba07" or obj.guid=="4ac9f6" or obj.guid=="3b3273" or obj.guid=="725de9" or obj.guid=="a598f6" or obj.guid=="b66704" or
		obj.guid=="55e5e5" or obj.guid=="818aea" or obj.guid=="564392" or obj.guid=="784a07" or obj.guid=="ebbbfc" or obj.guid=="b13d5f" or obj.guid=="9d866a") then
		if (gStates.coop==0 or gStates.WarOfFourComp==true) and gStates.firstStarted==true then
			local coopGUID=obj.guid
			safeWaitFrames("Events",function() safeWaitCondition("Events",function()
				local locking=obj.setState(2)
				if locking~=nil and gStates.mageSkills~=nil and gStates.mageSkills[coopGUID]~=nil then
					gStates.mageSkills[locking.guid]=gStates.mageSkills[coopGUID]
					gStates.mageSkills[coopGUID]=nil
				end
				safeWaitFrames("Events",function()
					if locking~=nil then locking.lock() end
					--setState replaces the object/GUID and clears its object UI. Rebuild reward Claim buttons on the live state.
					if gStates.skillButtons~=nil and gStates.skillButtons>0 then skillButtonActivate() end
					if coopCompSkillPlayLocked()==true then refreshCoopCompSkillXs() end
				end, 2)
			end, function() return obj.resting end) end, 10)
		end
	end
	local soloDescription={
							["3fba07"]="{en}Once a round (Except during combat):\n\nThrow away up to two Wound cards from your hand. (Put this skill token in your Play Area to activated it)\n\nNext turn only:\n\nYou may play a Wound card sideways for +3.{ru}Один раз в раунд (не в битве):\n\nУдалите до двух карт раны с руки. (Положите навык в вашу игровую зону для активации эффекта)\n\nТолько в следующий ход:\n\nМожете сыграть карту раны боком, получив бонус +3.{zh-cn}每轮一次，非战斗中使用\n\n从手牌中去除最多两张创伤卡。将本技能标记放在桌子中央。\n\n仅下回合： 你可以横置打出一张创伤卡，效果+3{ko}라운드에 한번, 전투에서 제외:\n\n손에 든 부상을 2개까지 제거한다. (스킬을 플레이 영역에 놓아 활성화)\n\n다음 차례에 한번,\n\n부상 하나를 다른 행동 카드처럼 가로로 시용해, +1 대신 +3을 받는다.{es}Una vez por Ronda (excepto durante el combate):\n\nTira hasta dos cartas de Herida de tu mano. (Pon esta ficha de habilidad en tu Área de juego para activarla)\n\nSólo en el próximo turno:\n\nPuedes jugar una carta de Herida de lado por +3.{fr}Une fois par Rounde (Sauf pendant le combat):\n\nJetez jusqu'à deux cartes Blessure de votre main. (Mettez ce jeton de compétence dans votre zone de jeu pour l'activer)\n\nTour suivant uniquement:\n\nVous pouvez jouer une carte Blessure latéralement pour +3.{pt-br}Uma vez por rodada (Exceto durante combate):\n\nJogue fora 2 cartas de ferimento da sua mão. (Coloque esta habilidade na sua área de jogo para ativá-la)\n\nPróximo turno turno apenas:\n\nVocê pode jogar uma carta de Ferimento de lado como +3.{de}Einmal pro Runde (außer im Kampf):\n\nWirf bis zu zwei Wundenkarten aus deiner Hand weg. (Lege dieses Fertigkeitsplättchen in deinen Spielbereich, um es zu aktivieren)\n\nNur im nächsten Zug:\n\nDu darfst eine Wundenkarte seitwärts für +3 ausspielen.",
							["4ac9f6"]="{en}Once a Round:\n\nReduce one attack of an enemy by 1. That enemy gains Cumbersome this turn. (Put this skill token in your Play Area to activated it)\n\nNext turn only:\n\nYou may reduce one attack of an enemy by 1. That enemy gains Cumbersome.{ru}Один раз в раунд:\n\nУменьшите значение одной Атаки врага на 1. Этот враг становится Неповоротливым до конца хода. (Положите навык в вашу игровую зону для активации эффекта)\n\nТолько в следующий ход:\n\nУменьшите значение одной Атаки врага на 1. Этот враг становится Неповоротливым до конца хода.{zh-cn}每轮一次：\n\n将敌人的一次攻击减少1。该敌人在本回合变得笨重（将此标记放在桌子中央以激活它）\n\n仅下一回合：\n\n您可以将敌人的一次攻击减少1。该敌人变得笨重。{ko}라운드에 한번:\n\n적 공격 하나를 1 줄인다. 이번 차례에 그 적의 공격은 육중함을 얻는다.  (스킬을 플레이 영역에 놓아 활성화)\n\n다음 자기 차례에:\n\n적 공격 하나를 1 줄인다. 이번 차례에 그 적의 공격은 육중함을 얻는다.{es}Una vez por Ronda:\n\nReduce un ataque de un enemigo en 1. Ese enemigo gana Engorroso este turno. (Pon esta ficha de habilidad en tu área de juego para activarla)\n\nSolo en el próximo turno:\n\nPuedes reducir un ataque de un enemigo en 1. Ese enemigo se vuelve engorroso.{fr}Une fois par Rounde:\n\nRéduisez une attaque d'un ennemi de 1. Cet ennemi devient Encombrant ce tour-ci. (Mettez ce jeton de compétence dans votre zone de jeu pour l'activer)\n\nTour suivant uniquement:\n\nVous pouvez réduire une attaque d'un ennemi de 1. Cet ennemi devient Encombrant.{pt-br}Uma vez por Rodada:\n\nReduz um ataque de um inimigo em 1.Este inimigo ganha Corpulento este turno. (Coloque esta habilidade na sua área de jogo para ativá-la)\n\nPróximo Turno apenas:\n\nVocê pode reduzir um ataque de 1 inimigo em 1. Este inimigo ganha Corpulento.{de}Einmal pro Runde:\n\nReduziere einen Angriff eines Feindes um 1. Dieser Feind wird in diesem Zug schwerfällig. (Lege dieses Fertigkeitsplättchen in deinen Spielbereich, um es zu aktivieren)\n\nNur im nächsten Zug:\n\nDu kannst einen Angriff eines Gegners um 1 reduzieren. Dieser Gegner wird schwerfällig.",
							["3b3273"]="{en}Once a Round:\n\nYou may Reroll a mana die in the source. (Put this skill token in your Play Area to activated it)\n\nNext turn only:\n\nYou may use an extra die from the source. Also gain a crystal of the same color. You may decide whether to reroll that die or not at the end of your turn.{ru}Один раз в раунд:\n\nМожете перебросить кубик маны в источнике. (Положите навык в вашу игровую зону для активации эффекта)\n\nТолько в следующий ход:\n\nМожете использовать дополнительный кубик маны основного цвета и взять кристалл этого цвета. Вы решаете, перебрасывать взятый кубик или нет.{zh-cn}每回合一次:\n\n你可以重掷来源中的一个法力骰子. (将此技能令牌放入你的游戏区域以激活它).\n\n仅限下一回合:\n\n你可以使用一个额外的法力骰子, 同时获得一个相同颜色的水晶. 在你的回合结束时, 你可以决定是否重掷该骰子.{ko}1라운드에 한 번:\n\n당신은 소스의 마나 주사위를 다시 굴릴 수 있습니다. (이 스킬 토큰을 자신의 플레이 영역에 놓아 활성화합니다).\n\n다음 턴에만 가능합니다:\n\n당신은 소스에서 주사위 한 개를 추가로 사용할 수 있습니다. 또한 같은 색의 수정 하나를 얻습니다. 자신의 턴이 끝날 때 주사위를 다시 굴릴지 여부를 결정할 수 있습니다.{es}Una vez por Ronda:\n\nPuedes volver a lanzar un dado de maná en la fuente. (Pon esta ficha de habilidad en tu Área de Juego para activarla)\n\nSólo en el siguiente turno:\n\nPuedes usar un dado extra de la fuente. También ganas un cristal del mismo color. Puedes decidir si volver a lanzar ese dado o no al final de tu turno.{fr}Une fois par round :\n\nVous pouvez relancer un dé de mana dans la source. (Placez ce jeton de compétence dans votre zone de jeu pour l'activer).\n\nAu prochain tour seulement :\n\nVous pouvez utiliser un dé supplémentaire de la source. Vous gagnez également un cristal de la même couleur. Vous pouvez décider de relancer ou non ce dé à la fin de votre tour.{pt-br}Uma vez por rodada:\n\nVocê pode fazer o Reroll de um dado de mana na fonte. (Coloque esse token de habilidade em sua Área de Jogo para ativá-lo).\n\nSomente no próximo turno:\n\nVocê pode usar um dado extra da fonte. Também ganha um cristal da mesma cor. Você pode decidir se quer rolar novamente esse dado ou não no final do seu turno.{de}Einmal pro Runde:\n\nDu darfst einen Manawürfel in der Quelle neu würfeln. (Lege dieses Fertigkeitsplättchen in deinen Spielbereich, um es zu aktivieren)\n\nNur in der nächsten Runde:\n\nDu darfst einen zusätzlichen Würfel aus der Quelle verwenden. Außerdem erhältst du einen Kristall der gleichen Farbe. Am Ende deines Zuges darfst du entscheiden, ob du diesen Würfel neu würfelst oder nicht.",
							["725de9"]="{en}Once a Round:\n\nWhen you spend a mana of a basic color, gain a Crystal of that color. (Put this skill token in your Play Area to activated it, and place another crystal of the same color on it)\n\nNext turn only:\n\nYou may gain the mana token on this skill.{ru}Один раз в раунд:\n\nПотратив ману основного цвета, возьмите кристалл того же цвета. (Положите навык в вашу игровую зону для активации эффекта, и положите на него жетон маны того же цвета из резерва)\n\nТолько в следующий ход:\n\nМожете использовать ману, лежащую на этом навыке.{zh-cn}每轮一次：\n\n当你花费一个基本颜色的魔力时，获得一个该颜色的魔晶（将此技能标记放置在桌子中央以激活它，并在其上放置另一个相同颜色的水晶）\n\n仅下一回合：\n\n您可以获得此技能上的魔力标记。{ko}라운드에 한번:\n\n기본 색상 마나 1개를 지불할 때,  이 스킬을 사용하여 해당 색상 수정 1개를 얻는다.(같은 색의 마나 토큰으로 스킬 위에 표시하고 플레이 영역에 놓아 활성화)\n\n다음 차례에:\n\n이 마나 토큰을 얻을 수 있다.{es}Una vez por Ronda:\n\nCuando gastas un maná de un color básico, obtienes un cristal de ese color. (Pon esta ficha de habilidad en tu Área de juego para activarla y coloca otro cristal del mismo color sobre ella)\n\nSolo en el próximo turno:\n\nPuedes obtener la ficha de maná en esta habilidad.{fr}Une fois par Rounde:\n\nLorsque vous dépensez un mana d'une couleur de base, gagnez un cristal de cette couleur. (Mettez ce jeton de compétence dans votre zone de jeu pour l'activer et placez-y un autre cristal de la même couleur)\n\nTour suivant uniquement:\n\nVous pouvez gagner le jeton mana de cette compétence.{pt-br}Uma vez por Rodada:\n\nQuando você gastar uma mana de cor básica, ganhe um cristal daquela cor. (coloque essa habilidade na sua área de jogo para ativá-la e coloque outro cristal da mesma cor nela)\n\nPróximo Turno apenas:\n\nVocê pode ganhar o marcador de mana desta habilidade.{de}Einmal pro Runde:\n\nWenn du ein Mana einer Grundfarbe ausgibst, erhältst du einen Kristall dieser Farbe (lege dieses Fertigkeitsplättchen in deinen Spielbereich, um es zu aktivieren, und lege einen weiteren Kristall derselben Farbe darauf).\n\nNur im nächsten Zug:\n\nDu darfst das Mana-Token für diese Fähigkeit erhalten.",
							["55e5e5"]="{en}Once a Round:\n\nReduce the Move cost of all terrains by 2 (to a minimum of 1). (Put this skill token in your Play Area to activated it)\n\nNext turn only:\n\nYou may reduce the move cost of all terrains by 1 (to a minimum of 1).{ru}Один раз в раунд:\n\nВаш герой двигается по любой местности, тратя на 2 очка Движения меньше (но не меньше 1) в этот ход. (Положите навык в вашу игровую зону для активации эффекта)\n\nТолько в следующий ход:\n\nВаш герой двигается по любой местности, тратя на 1 очко Движения меньше (но не меньше 1) в этот ход.{zh-cn}每轮一次: \n\n将本技能标记放在桌子中央以激活效果. \n将所有地形移动消耗减少2 (最少至1)\n\n仅下回合: \n将所有地形移动消耗减少1 (最低至1){ko}라운드에 한번:\n\n이번 차례에 당신에게 모든 지형의 이동 비용은 2(최하 1) 감소한다.(스킬을 플레이 영역에 놓아 활성화)\n\n다음 차례에 한번만:\n\n이번 차례에 모든 지형의 이동 비용이 1 감소한다.{es}Una vez por Ronda:\n\nReduce el coste de movimiento de todos los terrenos en 2 (hasta un mínimo de 1). (Pon esta ficha de habilidad en tu Área de juego para activarla)\n\nSolo en el próximo turno:\n\nPuedes reducir el costo de movimiento de todos los terrenos en 1 (hasta un mínimo de 1).{fr}Une fois par Rounde:\n\nRéduisez le coût de déplacement de tous les terrains de 2 (jusqu'à un minimum de 1). (Mettez ce jeton de compétence dans votre zone de jeu pour l'activer)\n\nTour suivant uniquement :\n\nVous pouvez réduire le coût de déplacement de tous les terrains de 1 (jusqu'à un minimum de 1).{pt-br}Uma vez por Rodada:\n\nReduz o custo de movimento de todos os terrenos em 2 (a um mínimo de 1). (Coloque esta Habilidade na sua área de jogo para ativá-la).\n\nPróximo Turno apenas:\n\nVocê pode reduzir o custo de movimento de todos os terrenos em 1 (a um mínimo de 1).{de}Einmal pro Runde:\n\nVerringere die Bewegungskosten aller Terrains um 2 (auf ein Minimum von 1). (Lege dieses Fertigkeitsplättchen in deinen Spielbereich, um es zu aktivieren)\n\nNur in der nächsten Runde:\n\nDu darfst die Bewegungskosten aller Geländefelder um 1 reduzieren (auf ein Minimum von 1).",
							["818aea"]="{en}Once a Round:\n\nGain a mana token of any color except Gold. (Put this skill token in your Play Area to activated it, and place another crystal of the same color on it)\n\nNext turn only:\n\nIf you use a Mana of this same Color to power a Deed Card that gives Move, Influence, or any type of Attack or Block, it gets +4 from that card.{ru}Один раз в раунд:\n\nВозьмите жетон маны любого цвета, кроме золотого. (Положите навык в вашу игровую зону для активации эффекта, и положите на него жетон маны того же цвета из резерва)\n\nТолько в следующий ход:\n\nЕсли вы используете ману этого цвета для усиления карты с очками Движения, Влияния, любой Атаки или Блока, вы получаете +4 к значению этого эффекта.{zh-cn}每回合一次：\n\n获得一个任意颜色的法力令牌，金色除外。（将此技能令牌放入你的游戏区域以激活它，并在其上放置另一个相同颜色的水晶）。\n\n仅限下一回合：\n\n如果你使用一张同色的法力牌为一张可提供移动、影响或任何类型的攻击或格挡的契约牌提供能量，它将从该牌中获得 +4。{ko}라운드에 한 번:\n\n금색이 아닌 색상 마나 토큰 1개를 선택해 받는다.(같은 색의 마나 토큰으로 스킬 위에 표시하고 플레이 영역에 놓아 활성화)\n\n다음 차례에 한번:\n\n이동, 영향력, 또는 아무 종류의 공격이나 방어를 제공하는 카드 하나를, 표시돤 색상과 동일한 색의 마나로 강화 사용한다면 해당 수치에 +4를 추가로 얻는다.{es}Una vez por ronda:\n\nGana una ficha de maná de cualquier color excepto oro. (Pon esta ficha de habilidad en tu Área de juego para activarla y coloca otro cristal del mismo color sobre ella)\n\nSolo en el próximo turno:\n\nSi usas un Mana de este mismo Color para potenciar una Carta de Escritura que otorga Movimiento, Influencia o cualquier tipo de Ataque o Bloqueo, obtiene +4 de esa carta.{fr}Une fois par Rounde:\n\nGagnez un jeton de mana de n'importe quelle couleur à l'exception de l'or. (Mettez ce jeton de compétence dans votre zone de jeu pour l'activer et placez-y un autre cristal de la même couleur)\n\nTour suivant uniquement:\n\nSi vous utilisez un mana de cette même couleur pour alimenter une carte d'action qui donne un mouvement, une influence ou tout type d'attaque ou de blocage, elle obtient +4 de cette carte.{pt-br}Uma vez por rodada:\n\nGanhe uma ficha de mana de qualquer cor, exceto ouro. (Coloque esta ficha de habilidade em sua área de jogo para ativá-la e coloque outro cristal da mesma cor sobre ela)\n\nPróxima curva apenas:\n\nSe você usar um Mana desta mesma Cor para energizar uma Carta de Ação que conceda Movimento, Influência ou qualquer tipo de Ataque ou Bloqueio, ela recebe +4 daquela carta.{de}Einmal pro Runde:\n\nErhalte ein Mana-Token einer beliebigen Farbe außer Gold. (Lege dieses Fertigkeitsplättchen in deinen Spielbereich, um es zu aktivieren, und lege einen weiteren Kristall derselben Farbe darauf)\n\nNur in der nächsten Zug:\n\nWenn du Mana dieser Farbe nutzt, um eine Handlungs­karte mit Bewegung, Einfluss, Angriff oder Block zu aktivieren, erhält +4 von dieser Karte.",
							["564392"]="{en}Once a Round (Except during Interactions): (Put this skill token in your Play Area to activated it)\n\nOne card played sideways is worth +4. For each command token without a Unit gain an extra +1.\n\nNext turn only:\n\nYou may reduce the Armour of an enemy by 1, and one attack of the same or another enemy by 1{ru}Один раз в раунд (не при взаимодействии): (Положите навык в вашу игровую зону для активации эффекта)\n\nОдна карта, сыгранная боком, дает бонус +4 вместо +1. Каждый свободной жетон командования увеличивает бонус еще на +1.\n\nТолько в следующий ход:\n\nВы можете уменьшить Броню одного врага на 1 и значение одной Атаки на 1 (этого или другого врага).{zh-cn}每轮一次，交涉中除外：\n\n一张横置打出的卡牌效果+4而非+1。你没有一个未分配给部队的指挥标记额外+1。将本技能放在桌子中间。\n仅下回合： 你的一个敌人护甲-1，同时同一个或另一个敌人的攻击-1{ko}라운드에 한번, 교류에서 제외:\n\n가로로 사용한 카드 1장은 +1 대신 +4를 준다. 이 수치는 유닛이 배정되지 않은 지휘 토큰 하나당 +1씩 증가한다. (스킬을 플레이 영역에 놓아 활성화)\n\n다음 차례에 한 번:\n\n선택한 적 하나의 방어구를 1 감소시키고, 같은 적이나 다른 적 공격 하나도 1 감소시킨다.{es}Una vez por Ronda (excepto durante las interacciones): (Pon esta ficha de habilidad en tu Área de juego para activarla)\n\nUna carta jugada de lado vale +4. Por cada ficha de Mando sin una Unidad, obtienes un +1 extra.\n\nSolo en el próximo turno:\n\nPuedes reducir la armadura de un enemigo en 1 y un ataque del mismo u otro enemigo en 1{fr}Une fois par Rounde (sauf pendant les interactions): (Mettez ce jeton de compétence dans votre zone de jeu pour l'activer)\n\nUne carte jouée de côté vaut +4. Pour chaque jeton de commandement sans Unité, gagnez un +1 supplémentaire.\n\nTour suivant uniquement:\n\nVous pouvez réduire l'armure d'un ennemi de 1 et une attaque du même ennemi ou d'un autre de 1{pt-br}Uma vez por Rodada (Exceto durante interações): (Coloque esta habilidade na sua área de jogo para ativá-la)\n\nUma carta jogada de lado vale +4. Para cada Ficha de Comando sem uma unidade ganhe +1 extra.\n\nNo Próximo Turno apenas:\n\nVocê pode reduzir a armadura de um inimigo em 1 e um ataque do mesmo inimigo em 1.{de}Einmal pro Runde (außer bei Interaktionen): (Lege dieses Fertigkeitsplättchen in deinen Spielbereich, um es zu aktivieren)\n\nEine seitwärts gespielte Karte ist +4 wert. Für jedes Befehlsplättchen ohne Einheit erhältst du zusätzlich +1.\n\nNur in der nächsten Zug:\n\nDu kannst die Rüstung eines Gegners um 1 und einen Angriff desselben oder eines anderen Gegners um 1 reduzieren.",
							["ebbbfc"]="{en}Once a Round:\n\nChoose one card from your discard pile and place it on top  of your deed deck.\n\nIf the dummy hasn't called end of round, place the top card from the Advanced Action Deck in his deck.{zh-cn}每轮一次：\n\n你和其他所有玩家从弃牌堆中选择一张牌，将这张牌放到功能牌库顶。单人游戏时，再将高级行动牌堆顶部的1张牌放到虚拟玩家的功能牌库顶，即使虚拟玩家的 功能牌库没有牌也可以这样做。\n如果虚拟玩家已经声明本轮结束，则忽略此效果。{ko}라운드에 한번:\n\n이 토큰을 뒤집어 버린 더미에서 카드 한장을 선택해 더미 위에 올려둔다.\n\n가상 플레이어가 라운드 종료를 선언Cards하지 않았다면, 가장 아래 위치한 상급 액션을 그의 더미에 추가한다.{es}Una vez por Ronda:\n\nElige una carta de tu pila de descarte y colócala encima de tu mazo de escrituras.\n\nSi el muerto no ha dicho fin de ronda, coloca la carta superior del Mazo de Acción Avanzada en su mazo.{fr}Une fois par Rounde:\n\nChoisissez une carte de votre défausse et placez-la au-dessus de votre deck d'actes.\n\nSi le mannequin n'a pas appelé à la fin du tour, placez la première carte du paquet d'action avancée dans son paquet.{pt-br}Uma vez por Rodada:\n\nEscolha uma carta de sua pilha de descarte e coloque-a no topo de seu baralho de ações.\n\nSe o morto não tiver chamado o final da rodada, coloque a carta do topo do Baralho de Ação Avançada em seu baralho.",
							["a598f6"]="{en}Once a round (Except during combat):\n\nGain a Potion. (Put this skill token in your Play Area to activated it).\n\nNext turn only:\n\nYou may add +3 to any Move, Influence, or any type of Attack or Block provided by your next card or Unit ability that required no mana.",
							["3d8336"]="{en}Once a Round:\n\nFlip this to draw two cards, and gain a Red mana token.\n\nYou cannot use another Motivation Skill until the end of your next turn.{ru}Один раз в раунд:\n\nПереверните навык и возьмите 2 карты и жетон красной маны.\n\nНельзя использовать другие навыки Мотивации до конца вашего следующего хода.{zh-cn}每轮一次：\n\n使用此技能抽两张牌，并获得一个红色魔力标记。\n\n在下一回合结束之前，您不能使用其他激励技能。{ko}라운드에 한번:\n\n이 토큰을 뒤집어 카드 2장을 뽑는다. 그리고 적색 마나 토큰을 얻는다.\n\n다음 차례를 마칠 때 까지 다른 동기 부여를 사용할 수 없다.{es}Una vez por Ronda:\n\nDale la vuelta para robar dos cartas y ganar una ficha de maná roja.\n\nNo puedes usar otra habilidad de motivación hasta el final de tu próximo turno.{fr}Une fois par Rounde :\n\nRetournez-le pour piocher deux cartes et gagner un jeton de mana rouge.\n\nVous ne pouvez pas utiliser une autre compétence de motivation jusqu'à la fin de votre prochain tour.{pt-br}Uma vez por Rodada:\n\nVire esta para comprar duas cartas e ganhar um marcador de mana Vermelha.\n\nVocê não pode usar habilidades Motivacionais até o fim do seu próximo turno.{de}Einmal pro Runde:\n\nDrehe dies um, um zwei Karten zu ziehen und einen roten Mana-Token zu erhalten.\n\nDu kannst bis zum Ende deines nächsten Zuges keine weitere Motivationsfähigkeit nutzen.",
							["171244"]="{en}Once a Round:\n\nFlip this to draw two cards, and gain a Green mana token.\n\nYou cannot use another Motivation Skill until the end of your next turn.{ru}Один раз в раунд:\n\nПереверните навык и возьмите 2 карты и жетон зеленой маны.\n\nНельзя использовать другие навыки Мотивации до конца вашего следующего хода.{zh-cn}每轮一次：\n\n使用此技能抽两张牌，并获得一个绿色魔力标记。\n\n在下一回合结束之前，您不能使用其他激励技能。{ko}라운드에 한번:\n\n이 토큰을 뒤집어 카드 2장을 뽑는다. 그리고 녹색 마나 토큰을 얻는다.\n\n다음 차례를 마칠 때 까지 다른 동기 부여를 사용할 수 없다.{es}Una vez por Ronda:\n\nDale la vuelta para robar dos cartas y ganar una ficha de maná verde.\n\nNo puedes usar otra habilidad de motivación hasta el final de tu próximo turno.{fr}Une fois par Rounde:\n\nRetournez-le pour piocher deux cartes et gagner un jeton de mana vert.\n\nVous ne pouvez pas utiliser une autre compétence de motivation jusqu'à la fin de votre prochain tour.{pt-br}Uma vez por Rodada:\n\nVire esta para comprar duas cartas e ganhar um marcador de mana Verde.\n\nVocê não pode usar habilidades Motivacionais até o fim do seu próximo turno.{de}Einmal pro Runde:\n\nDrehe dies um, um zwei Karten zu ziehen und einen grünen Mana-Token zu erhalten.\n\nDu kannst bis zum Ende deines nächsten Zuges keine weitere Motivationsfähigkeit nutzen.",
							["14399f"]="{en}Once a Round:\n\nFlip this to draw two cards, and gain a White mana token.\n\nYou cannot use another Motivation Skill until the end of your next turn.{ru}Один раз в раунд:\n\nПереверните навык и возьмите 2 карты и жетон белой маны.\n\nНельзя использовать другие навыки Мотивации до конца вашего следующего хода.{zh-cn}每轮一次：\n\n将本标记翻面以抽取两张卡牌。获得一个白色魔力标记。你的下回合结束前无法使用其他激励技能{ko}라운드에 한번:\n\n이 토큰을 뒤집어 카드 2장을 뽑는다. 그리고 백색 마나 토큰을 얻는다.\n\n다음 차례를 마칠 때 까지 다른 동기 부여를 사용할 수 없다.{es}Una vez por Ronda:\n\nDale la vuelta para robar dos cartas y ganar una ficha de maná blanca.\n\nNo puedes usar otra habilidad de motivación hasta el final de tu próximo turno.{fr}Une fois par Rounde:\n\nRetournez-le pour piocher deux cartes et gagner un jeton de mana blanc.\n\nVous ne pouvez pas utiliser une autre compétence de motivation jusqu'à la fin de votre prochain tour.{pt-br}Uma vez por Rodada:\n\nVire esta para comprar duas cartas e ganhar um marcador de mana Branca.\n\nVocê não pode usar habilidades Motivacionais até o fim do seu próximo turno.{de}Einmal pro Runde:\n\nDrehe dies um, um zwei Karten zu ziehen und ein weißes Mana-Token zu erhalten.\n\nDu kannst bis zum Ende deines nächsten Zuges keine weitere Motivationsfähigkeit nutzen.",
							["527b47"]="{en}Once a Round:\n\nFlip this to draw two cards, and gain Fame 1.\n\nYou cannot use another Motivation Skill until the end of your next turn.{ru}Один раз в раунд:\n\nПереверните навык и возьмите 2 карты и 1 очко Славы.\n\nНельзя использовать другие навыки Мотивации до конца вашего следующего хода.{zh-cn}每轮一次：\n\n使用此技能抽两张牌，并获得声望1。\n\n在下一回合结束之前，您不能使用其他激励技能。{ko}라운드에 한번:\n\n이 토큰을 뒤집어 카드 2장을 뽑는다. 그리고 명성 1을 얻는다.\n\n다음 차례를 마칠 때 까지 다른 동기 부여를 사용할 수 없다.{es}Una vez por Ronda:\n\nDale la vuelta para robar dos cartas y ganar Fama 1.\n\nNo puedes usar otra habilidad de motivación hasta el final de tu próximo turno.{fr}Une fois par Rounde:\n\nRetournez-le pour piocher deux cartes et gagner de la renommée 1.\n\nVous ne pouvez pas utiliser une autre compétence de motivation jusqu'à la fin de votre prochain tour.{pt-br}Uma vez por Rodada:\n\nVire esta para comprar duas cartas e ganhar 1 de fama.\n\nVocê não pode usar habilidades Motivacionais até o fim do seu próximo turno.{de}Einmal pro Runde:\n\nDrehe dies um, um zwei Karten zu ziehen und 1 Ruhm zu erhalten.\n\nDu kannst bis zum Ende deines nächsten Zuges keine weitere Motivationsfähigkeit nutzen.",
							["ba4df5"]="{en}Once a Round:\n\nFlip this to draw two cards, and gain a Blue mana token.\n\nYou cannot use another Motivation Skill until the end of your next turn.{ru}Один раз в раунд:\n\nПереверните навык и возьмите 2 карты и жетон синей маны.\n\nНельзя использовать другие навыки Мотивации до конца вашего следующего хода.{zh-cn}每轮一次：\n\n使用此技能抽两张牌，并获得蓝色魔力标记。\n下回合结束前，你不能使用其他激励技能。{ko}라운드에 한번:\n\n이 토큰을 뒤집어 카드 2장을 뽑는다. 그리고 청색 마나 토큰을 얻는다.\n\n다음 차례를 마칠 때 까지 다른 동기 부여를 사용할 수 없다.{es}Una vez por Ronda:\n\nDale la vuelta para robar dos cartas y ganar una ficha de maná azul.\n\nNo puedes usar otra habilidad de motivación hasta el final de tu próximo turno.{fr}Une fois par Rounde:\n\nRetournez-le pour piocher deux cartes et gagner un jeton de mana bleu.\n\nVous ne pouvez pas utiliser une autre compétence de motivation jusqu'à la fin de votre prochain tour.{pt-br}Uma vez por Rodada:\n\nVire esta para comprar duas cartas e ganhar um marcador de mana Azul.\n\nVocê não pode usar habilidades Motivacionais até o fim do seu próximo turno.{de}Einmal pro Runde:\n\nDrehe dies um, um zwei Karten zu ziehen und ein blaues Mana-Token zu erhalten.\n\nDu kannst bis zum Ende deines nächsten Zuges keine weitere Motivationsfähigkeit nutzen.",
							["48fd35"]="{en}Once a turn:\n\nPay a mana of any color and throw away a Wound from your hand. Also draw a card.{ru}Один раз в ход:\n\nПотратьте ману любого цвета и удалите карту раны с руки. Возьмите одну карту.{zh-cn}每回合一次：\n\n支付一点任意颜色的魔力，从手牌中去除一张创伤卡，抽一张卡牌。{ko}차례에 한번:\n\n아무 색상 마나를 지불하고 손에 든 부상 하나를 제거한다. 추가로 카드 1장을 뽑는다.{es}Una vez por Turno:\n\nPaga un maná de cualquier color y tira una herida de tu mano. También roba una carta.{fr}Une fois par Tour:\n\nPayez un mana de n'importe quelle couleur et jetez une Blessure de votre main. Piochez également une carte.{pt-br}Uma vez por Turno:\n\nPague uma mana de qualquer cor e jogue fora um Ferimento da sua mão. Também compre uma carta.{de}Einmal pro Zug:\n\nBezahle ein Mana beliebiger Farbe und wirf eine Wundenkarte aus deiner Hand ab. Ziehe außerdem eine Karte.",
							["b13d5f"]="Change up to 4 Black Mana Tokens or Die into unique Basic Mana colours, even during the day. Place this skill in the source until Mevok’s next turn. This allows a friendly Knight to reroll Black (day) or Gold (night) mana in the source. If any Black (day) or Gold (night) mana remains after rolling, return this skill face down to Mevok.",
							["68f864"]="{en}Once a Round:\n\nFlip this token to Ignore all Attack effects of one enemy token (Put this skill token in your Play Area to activate it).\n\nNext turn only:\n\nYou may use this skill to ignore One Attack effect of one enemy token.{pt-br}Uma vez por Rodada:\n\nVire esta ficha para ignorar todos os efeitos de Ataque de uma ficha inimiga (coloque esta ficha de habilidade na sua Área de Jogo para ativá-la).\n\nApenas no próximo turno:\n\nVocê pode usar esta habilidade para ignorar um efeito de Ataque de uma ficha inimiga.",
							["784a07"]="{en}Once a round:\n\nFlip this Token to draw a card.\n\nYou may also discard a card and draw a card.\n\nNext turn only:\n\nYou may use this skill to draw a card.{ru}Один раз за раунд:\n\nПереверните этот жетон, чтобы взять карту.\n\nВы также можете сбросить карту и взять карту.\n\nТолько в следующем ходу:\n\nВы можете использовать этот навык, чтобы взять карту.{zh-tw}每輪一次：\n\n將此技能翻面來抽一張卡牌。\n\n你可以再棄一張牌來抽一張卡牌。\n\n僅下回合：\n\n你可以使用此技能來抽一張卡牌。{zh-cn}每轮一次：\n\n将此技能翻面来抽一张卡牌。\n\n你可以再弃一张牌来抽一张卡牌。\n\n仅下回合：\n\n你可以使用此技能来抽一张卡牌。{ko}매 턴마다 한 번:\n\n이 토큰을 뒤집어 카드를 한 장 뽑을 수 있습니다.\n\n카드를 버리고 한 장 뽑을 수도 있습니다.\n\n다음 턴에만:\n\n이 능력을 사용하여 카드를 한 장 뽑을 수 있습니다.{es}Una vez por ronda:\n\nVoltea esta ficha para robar una carta.\n\nTambién puedes descartar una carta y robar una carta.\n\nSolo en el siguiente turno:\n\nPuedes usar esta habilidad para robar una carta.{fr}Une fois par tour :\n\nRetournez ce jeton pour piocher une carte.\n\nVous pouvez également défausser une carte et en piocher une.\n\nAu prochain tour uniquement :\n\nVous pouvez utiliser cette capacité pour piocher une carte.{pt-br}Uma vez por rodada:\n\nVire este marcador para comprar uma carta.\n\nVocê também pode descartar uma carta e comprar uma carta.\n\nSomente no próximo turno:\n\nVocê pode usar esta habilidade para comprar uma carta.{de}Einmal pro Runde:\n\nDrehe diesen Spielstein um, um eine Karte zu ziehen.\n\nDu kannst auch eine Karte ablegen und eine Karte ziehen.\n\nNur im nächsten Zug:\n\nDu kannst diese Fähigkeit nutzen, um eine Karte zu ziehen.",
							["b66704"]="{en}Once a Round:\n\nYou may play a wound as a sideways card for +3.\n\nIf your reputation is nagative add half your reputation score rounded up (x=7).\n\nNext turn only:\n\nGain +1 on the Reputation Track.",
							["9d866a"]="Double your armour when assigning damage. Gain 1 extra wound per damage source to your hand and 2 to the discard pile. Knock Out requires 1 extra wound. After combat, throw out wounds equal to defeated enemies. Place this skill into the source. A friendly knight gains 1 Block or Block equal to your unsigned reputation. Return face down at the start of next turn.",
							["adf8ab"]="{en}Once a turn:\n\nPay a mana of any color and throw away a Wound from your hand. Also draw a card.{ru}Один раз в ход:\n\nПотратьте ману любого цвета и удалите карту раны с руки. Возьмите одну карту.{zh-cn}每回合一次：\n\n支付一点任意颜色的魔力，从手牌中去除一张创伤卡，抽一张卡牌。{ko}차례에 한번:\n\n아무 색상 마나를 지불하고 손에 든 부상 하나를 제거한다. 추가로 카드 1장을 뽑는다.{es}Una vez por Turno:\n\nPaga un maná de cualquier color y tira una herida de tu mano. También roba una carta.{fr}Une fois par Tour:\n\nPayez un mana de n'importe quelle couleur et jetez une Blessure de votre main. Piochez également une carte.{pt-br}Uma vez por Turno:\n\nPague uma mana de qualquer cor e jogue fora um Ferimento da sua mão. Também compre uma carta.{de}Einmal pro Zug:\n\nBezahle ein Mana beliebiger Farbe und wirf eine Wundenkarte aus deiner Hand ab. Ziehe außerdem eine Karte."}
	if gStates.playerCount==1 and soloDescription[obj.guid]~=nil then
		obj.setDescription(soloDescription[obj.guid])
	end

	--randomizes Volker's Reminder Token
	if bag.guid==GUID.bag.volkareReminder then
		volkareTokenRandomize(obj)
	end

	--randomizes Pyramid and Ziggurat Trap Tokens
	if bag.guid==monsterPiles.pyramidTrap or bag.guid==monsterPiles.zigguratTrap then
		local trapImage={[monsterPiles.pyramidTrap]={"https://steamusercontent-a.akamaihd.net/ugc/9508097467808968985/1AD863210453EFF576A15527777E7C5E31F9EC93/",--Gold Trap Pyramid
									 "https://steamusercontent-a.akamaihd.net/ugc/13810202743907142900/76AF5A7290CA73D540748F724C7BE2B2E5A777C5/",--Black Trap Pyramid
									 "https://steamusercontent-a.akamaihd.net/ugc/14739918052302431123/46BE9CE8E240D292A486F5A7CCD623D9880626D6/",--Red Trap Pyramid
									 "https://steamusercontent-a.akamaihd.net/ugc/13951722604068836390/C3578979A8A14BF4F10ACC0A49B0EF95B171BBD9/",--Green Trap Pyramid
									 "https://steamusercontent-a.akamaihd.net/ugc/10610671779031444146/6E1CFD8561A99C833C63A96110899BBA3267275E/",--Blue Trap Pyramid
									 "https://steamusercontent-a.akamaihd.net/ugc/12287773203439696041/71B8553A65F222526279CD17461A9EBA9657154C/"},--White Trap Pyramid
						 [monsterPiles.zigguratTrap]={"https://steamusercontent-a.akamaihd.net/ugc/10191292085001539923/E38D99F821EA897C948D77925F4D7651A8BA9F8F/",--Gold Trap Ziggurat
									 "https://steamusercontent-a.akamaihd.net/ugc/17636661188554526922/7DC7714EA95B3B4517E3105CAD85A111C2878B63/",--Black Trap Ziggurat
									 "https://steamusercontent-a.akamaihd.net/ugc/11039385731712809880/156DE139292E6D662CD5549B6053DA4326DF2836/",--Red Trap Ziggurat
									 "https://steamusercontent-a.akamaihd.net/ugc/10752341567973322991/65535F357B15C26D51E62C3C8A39DBE4D26EE9A6/",--Green Trap Ziggurat
									 "https://steamusercontent-a.akamaihd.net/ugc/17579437605089059358/89A6345E965E798021FA181063DE02FF79B9C7A5/",--Blue Trap Ziggurat
									 "https://steamusercontent-a.akamaihd.net/ugc/9254811815622642090/26E41B4769CC5BDBF5B22A14B31295C35106B8B1/"}}--White Trap Ziggurat
		--roll volkares dice and read result
		local randomTrap=math.random(6)
		local damageAdjust=0
		if bag.guid==monsterPiles.pyramidTrap then damageAdjust=1 end
		safeWaitFrames("Events",function() safeWaitCondition("Events",function()
			if obj~=nil then
				obj.setCustomObject({image=trapImage[bag.guid][randomTrap]})
				obj.reload()
				if gStates.monsterPerks[obj.guid]==nil then gStates.monsterPerks[obj.guid]={} end
				if randomTrap==1 then gStates.monsterPerks[obj.guid].attack={M={4+damageAdjust}} end
				if randomTrap==2 then gStates.monsterPerks[obj.guid].brutal=true gStates.monsterPerks[obj.guid].cumbersome=true	gStates.monsterPerks[obj.guid].attack={P={4+damageAdjust}} end
				if randomTrap==3 then gStates.monsterPerks[obj.guid].attack={F={2+damageAdjust}} end
				if randomTrap==4 then gStates.monsterPerks[obj.guid].poison=true gStates.monsterPerks[obj.guid].attack={P={3+damageAdjust}} end
				if randomTrap==5 then gStates.monsterPerks[obj.guid].attack={I={2+damageAdjust}} end
				if randomTrap==6 then gStates.monsterPerks[obj.guid].swiftness=true gStates.monsterPerks[obj.guid].attack={P={3+damageAdjust}} end
			end
		end, function() return obj==nil or obj.resting end) end, 2)
	end

	--Give warning when drawing Terain tiles from the reserve.
	if (bag.guid==GUID.bag.terrain.leftCountry or bag.guid==GUID.bag.terrain.leftCore) and gStates.firstStarted==true then
		obj.setName("excess")
		if getObjectFromGUID(GUID.bag.terrain.stack).getQuantity()>0 then
			broadcastToAll("{en}The Rules say you should only access these when the main pile is empty.{ru}Правила гласят, что к ним можно обращаться только тогда, когда основная стопка пуста.{zh-cn}规则说只有当菜单是空的时才能访问这些{ko}메인 더미가 비어있을 때만 접근 가능합니다{es}Las Reglas dicen que solo debes acceder a ellas cuando la pila principal esté vacía.{fr}Les règles disent que vous ne devez y accéder que lorsque la pile principale est vide.{pt-br}As Regras dizem que você deveria apenas acessar estas quando a pilha principal está vazia.{de}Die Regeln besagen, dass man auf diese nur zugreifen darf, wenn der Hauptstapel leer ist.", positionToColor(gStates.turnNumber))
		end
	end

	--Use new monster pug images
	if gStates.useAlternatePugs==true and monsterPugs[obj.guid]~=nil and monsterPugs[obj.guid].alternate~=nil and monsterPugs[obj.guid].alternate~="" then
		obj.setCustomObject({image=monsterPugs[obj.guid].alternate})
	end

	--Use original monster pug images
	if gStates.useAlternatePugs==false and monsterPugs[obj.guid]~=nil and monsterPugs[obj.guid].original~=nil and monsterPugs[obj.guid].original~="" then
		obj.setCustomObject({image=monsterPugs[obj.guid].original})
	end

	--scaleBags reapplies monster-bag ALT orientation after setting the final scale.
	scaleBags(bag, obj, "exit")
end

function __onObjectSearchStart_raw(object, player_color)
	safeWaitFrames("Events",function() bagSearch=object.guid end, 5)
end
function __onObjectSearchEnd_raw(object, player_color)
	bagSearch=nil
end

randomizePause=nil
function __onObjectRandomize_raw(randomize_object, player_color)
	if randomize_object.type=="Bag" or randomize_object.type=="Deck" then safeWaitFrames("Events",function() scaleBags(randomize_object, "dud", "shuffle") end, 5) end
	if randomize_object.type=="Deck" and gStates~=nil and gStates.firstStarted==true then standardDeckCycleClearIfDeckShuffled(randomize_object) end
	--If Coral's Deed Deck is manually shuffled, restore Quick Witted to the bottom after the shuffle settles.
	if randomize_object.type=="Deck" then
		for _, playerDetails in pairs(turnOrder) do
			if playerDetails.mage=="Coral" and playerDetails.mage~=gStates.positionMageKnight[5] and playerDetails.dropoutState==nil then
				local deedZone=getObjectFromGUID(deedDeckZones[playerDetails.seatPos])
				if deedZone~=nil then
					local coralDeck=false
					for _, obj in pairs(deedZone.getObjects()) do if obj.guid==randomize_object.guid then coralDeck=true break end end
					if coralDeck==true then
						for _, cardData in pairs(randomize_object.getObjects()) do
							if cardData.guid=="6ecbc6" then
								scheduleCoralQuickWittedBottom(5)
								break
							end
						end
					end
				end
				break
			end
		end
	end

	if randomize_object.type=="Dice" and gStates~=nil and gStates.apocalypseQuestRollDice~=nil and gStates.apocalypseQuestRollDice[randomize_object.guid]==true then return end
	if randomize_object.type=="Dice" then
		--R/shake waits for the final resting face, then updates existing mirrors in place when possible.
		if scheduleMirrorRandomizeSync(randomize_object, "mirrored Source die randomized")~=true then scheduleRealSourceRefresh(randomize_object, "real Source die randomized", true) end
		local randomizeFences={{"7e09c6", 7.40}, {"0a7c95", 3.60}, {"ec49dd", 7.40}, {"c17ca2", 3.60}}
		for _, fenceDetails in ipairs(randomizeFences) do
			local fence=getObjectFromGUID(fenceDetails[1])
			if fence~=nil then fence.setScale({0.10, 20.00, fenceDetails[2]}) end
		end
		if randomizePause~=nil then Wait.stop(randomizePause) end
		randomizePause=safeWaitTime("Events",function()
			for _, fenceDetails in ipairs(randomizeFences) do
				local fence=getObjectFromGUID(fenceDetails[1])
				if fence~=nil then fence.setScale({0.10, 0.1, fenceDetails[2]}) end
			end
		end, 3)
	end
end

cardEffectRotationGeneration={}
function refreshCardEffectAfterRotation(cardGUID)
	if cardGUID==nil then return end
	cardEffectRotationGeneration[cardGUID]=(cardEffectRotationGeneration[cardGUID] or 0)+1
	local generation=cardEffectRotationGeneration[cardGUID]
	--onObjectRotate can fire before TTS has finished applying a Q/E rotation. Give the
	--transform a frame to start, then read the actual card angle once the object is resting.
	safeWaitFrames("Events",function()
		local card=getObjectFromGUID(cardGUID)
		if card==nil or cardEffectRotationGeneration[cardGUID]~=generation then return end
		safeWaitCondition("Events",function()
			if cardEffectRotationGeneration[cardGUID]~=generation then return end
			local settledCard=getObjectFromGUID(cardGUID)
			if settledCard==nil then return end
			if cardGUID==meditationTranceCardGUID then
				refreshMeditationTrance()
			elseif isSteadyTempoGUID(cardGUID)==true then
				steadyTempoRefreshCard(cardGUID)
			elseif cardGUID=="a000a4" and cardInPlayerPlayArea(cardGUID)==true then
				dayTactic2ButtonActivate()
			end
		end, function()
			local settlingCard=getObjectFromGUID(cardGUID)
			return cardEffectRotationGeneration[cardGUID]~=generation or settlingCard==nil or settlingCard.resting==true
		end, 2, function()
			--If physics never reports resting, still refresh from the card's current real angle.
			if cardEffectRotationGeneration[cardGUID]~=generation then return end
			local settledCard=getObjectFromGUID(cardGUID)
			if settledCard==nil then return end
			if cardGUID==meditationTranceCardGUID then refreshMeditationTrance()
			elseif isSteadyTempoGUID(cardGUID)==true then steadyTempoRefreshCard(cardGUID)
			elseif cardGUID=="a000a4" and cardInPlayerPlayArea(cardGUID)==true then dayTactic2ButtonActivate() end
		end)
	end, 1)
end

function __onObjectRotate_raw(object, spin, flip, player_color, old_spin, old_flip)
	if object==nil then return end
	if apocalypseDragonGroundHeadToken~=nil and select(1,apocalypseDragonGroundHeadToken(object.guid))==true then
		local _,dragonHeadName=apocalypseDragonGroundHeadToken(object.guid)
		local dragonHeadOwner=dragonHeadName~=nil and apocalypseDragonGroundHeadOwner(dragonHeadName) or nil
		safeWaitFrames("Events",function()
			apocalypseDragonRefreshGroundAttackSuppression()
			if dragonHeadOwner~=nil then apocalypseDragonRefreshGroundFameGain(dragonHeadOwner) end
			mainUIUpdate("Dragon Head Flipped")
		end,1)
	end
	if gStates.gameScenario=="Against the Horsemen Blitz" and terrainTiles[object.guid]~=nil then
		safeWaitFrames("Events",function() againstHorsemenRefreshReveals() end,2)
	end
	--Quest enemy tokens can be manually flipped while waiting on a Quest card. Refresh only
	--an existing Quest Attack control after TTS has applied the new face.
	if monsterPugs[object.guid]~=nil then
		apocalypseQuestScheduleEnemyAttackButtonOrientation(object.guid)
		refreshCityRevealForMonster(object.guid)
	end
	if object.guid=="02f996" or object.guid=="a4777c" or object.guid=="963031" then
		local tokenGUID=object.guid
		safeWaitFrames("Events",function()
			local token=getObjectFromGUID(tokenGUID)
			if token~=nil then apocalypseQuestSiteTokenDropped(token) end
		end, 2)
		return
	end
	if object.type=="Dice" then
		--Q/E-style player rotation does not cause a collision event, so mirror it explicitly after TTS applies the new face.
		if scheduleMirrorFaceSync(object, "mirrored Source die rotated")~=true then scheduleRealSourceRefresh(object, "real Source die rotated", false) end
		return
	end
	if object.type~="Card" then return end
	local cardGUID=object.guid
	if cardGUID==meditationTranceCardGUID or isSteadyTempoGUID(cardGUID)==true or cardGUID=="a000a4" then refreshCardEffectAfterRotation(cardGUID) end
end

function __onPlayerChangeColor_raw(color)
	if gStates.firstStarted==true then
		refreshPlayerSeatColors()
		outOfTurnUIStateKey=nil
		mainUIUpdate("Player Changed Colour")
	end
end

--Picking up or long-clicking Coral's whole Deed Deck is not a draw.
--Manual single-card draws are detected only when an actual Card leaves the Deed Deck container.
function onPlayerAction(player, action, targets) return true end

function __onObjectNumberTyped_raw(object, player_color, number, alt)
	--Number keys directly choose a die face without a collision event.
	if object~=nil and object.type=="Dice" then
		if scheduleMirrorFaceSync(object, "mirrored Source die number-selected")~=true then scheduleRealSourceRefresh(object, "real Source die number-selected", false) end
	end
	--Typing a number over Coral's Deed Deck is also a manual draw. Suppress the native action and use the same Quick Witted choice.
	local playerIndex=coralManualQuickWittedDeck(object)
	if playerIndex~=nil and number~=nil and number>0 then
		if legalPlayerCheck(player_color, turnOrder[playerIndex].seatPos, "NoDummyException")~=true then return true end
		local drawCount=math.min(number, object.getQuantity())
		if drawCount>0 and coralDrawPending==nil then showCoralDrawChoice(playerIndex, drawCount, "DrawOne") end
		return true
	end
	if object.getGMNotes()=="Wound Cards" or object.getGMNotes()=="Poison Cards" then
		local conversion={["Poison Cards"]="DealPoison", ["Wound Cards"]="DealWound"}
		for a=1, number, 1 do
			safeWaitTime("Events",function() DealWound({guid=object.guid, player={color=player_color}, id=conversion[object.getGMNotes()]}) end, a/10)
		end
		return true
	end
end

--Globals intentionally avoid consuming the main-chunk local limit.
maintenanceWait=nil
liftHeightLowDetected=false

function refreshLiftHeightWarning()
	local lowDetected=false
	for _, color in pairs(Player.getAvailableColors()) do
		if Player[color].lift_height~=-1 and Player[color].lift_height<0.1 then lowDetected=true break end
	end
	if lowDetected==true and liftHeightLowDetected~=true then
		UI.setAttribute("NoticeText", "Text", "'Lift Height' needs to be higher to avoid the scripting zones.          (Top Right Icon of a Man Lifting Weights)")
		UI.setAttribute("NoticeBoard", "visibility", "")
		UI.setAttribute("NoticeBoard", "height", "50")
		UI.show("NoticeBoard")
		liftHeightLowDetected=true
	elseif lowDetected~=true and liftHeightLowDetected==true then
		UI.hide("NoticeBoard")
		liftHeightLowDetected=false
	end
end

function __maintenanceTick_raw()
	refreshCityRevealControls()
	refreshLiftHeightWarning()
end

function maintenanceTick()
	safeCallback("maintenanceTick", function() __maintenanceTick_raw() end)
	maintenanceWait=safeWaitTime("Events",maintenanceTick, 2)
end

function startMaintenanceTick()
	if maintenanceWait~=nil then Wait.stop(maintenanceWait) end
	maintenanceWait=safeWaitTime("Events",maintenanceTick, 2)
end

--stop crystal entering command token bag
function filterObjectEnterContainer(container, enter_object)
	if container.getGMNotes()=="Command Tokens" and enter_object.getGMNotes()~="Command Token" then return false end
	if container.getGMNotes()=="Skills" and skillTokens[enter_object.guid]==nil then return false end
	return true -- Allows object to enter.
end

-- Automatic Lua error reporting
automaticLuaErrorReporting=false
automaticLuaErrorLastReport=0 --kept for the manual test hook / compatibility
automaticLuaErrorCooldown=10
automaticLuaErrorSignatures={}
automaticLuaErrorBreadcrumbs={}
automaticLuaErrorBreadcrumbLimit=10
automaticLuaErrorURL="https://script.google.com/macros/s/AKfycbzU1dSg2mafsUbUTNqOHce0cdWId2I8fkYiNO1JUgG73wtV9E2DCvm7uZ02bXviO-vnFw/exec"
automaticLuaErrorReporterVersion="412"

function automaticLuaErrorValue(callback, fallback)
	local ok, value=pcall(callback)
	if ok==true and value~=nil then return value end
	return fallback
end

function automaticLuaErrorStateValue(key, fallback)
	return automaticLuaErrorValue(function()
		if gStates==nil then return nil end
		return gStates[key]
	end, fallback)
end

function automaticLuaErrorScenarioValue(key, fallback)
	return automaticLuaErrorValue(function()
		return scenarioList[gStates.scenarioRef][gStates.playersRef][key]
	end, fallback)
end

function automaticLuaErrorMageValue(position)
	local value=automaticLuaErrorValue(function() return gStates.positionMageKnight[position] end, "")
	local randomChoice=automaticLuaErrorValue(function() return gStates.originalChoiceMageKnights[position] end, "")
	if value~="" and (randomChoice=="Random" or randomChoice=="All Skills") then value=tostring(value).." [R]" end
	return value
end

function automaticLuaErrorMapShape()
	local mapShape=automaticLuaErrorScenarioValue("mapShape", "")
	if mapShape=="{en}Open Limited to 4 Columns{ru}Открытое поле с ограничением в 4 ряда{zh-tw}4 列的限制開放地圖{zh-cn}4 列的限制开放地图 {ko}4열 제한{es}Abierto Limitado a 4 Columnas{fr}Ouvert Limité à 4 Colonnes{pt-br}Aberto Limitado a 4 Colunas{de}Offen Begrenzt auf 4 Spalten" then return "4 Columns" end
	if mapShape=="{en}Open Limited to 3 Columns{ru}Открытое поле с ограничением в 3 ряда{zh-tw}3 列的限制開放地圖{zh-cn}3 列的限制开放地图 {ko}3열 제한{es}Abierto Limitado a 3 Columnas{fr}Ouvert Limité à 3 Colonnes{pt-br}Aberto Limitado a 3 Colunas{de}Offen Begrenzt auf 3 Spalten" then return "3 Columns" end
	if mapShape=="{en}Wedge with No Limitations{ru}Клиновидное поле без ограничений{zh-tw}錐形無限制地圖{zh-cn}锥形无限制地图{ko}쐐기형(무제한){es}En Cuña sin Límites{fr}Coin sans Limites{pt-br}Cônico sem Limitações{de}Keil ohne Begrenzungen" then return "Wedge" end
	if mapShape=="{en}Wedge{ru}Клиновидное поле{zh-tw}錐形地圖{zh-cn}锥形地图{ko}쐐기형{es}En Cuña{fr}Coin{pt-br}Cônico{de}Keil" then return "Wedge" end
	if mapShape=="{en}Fully Open{ru}Полностью открытое поле{zh-tw}完全開放地圖{zh-cn}完全开放地图{ko}전체 개방형{es}Totalmente Abierto{fr}Entièrement Ouvert{pt-br}Totalmente Aberto{de}Vollständig Offen" then return "Fully Open" end
	if mapShape=="{en}Predefined{ru}Предопределенное поле{zh-tw}按劇本預設{zh-cn}按剧本预设{ko}미리 정해짐{es}Predefinido{fr}Prédéfini{pt-br}Pré-definido{de}Vordefiniert" then return "Predefined" end
	return mapShape
end

function automaticLuaErrorCityLevel()
	return automaticLuaErrorValue(function()
		local text="[ "
		for _, level in pairs(gStates.cityLevels) do text=text..tostring(level).." " end
		return text.."]"
	end, "")
end

function automaticLuaErrorGameType()
	return automaticLuaErrorValue(function()
		if gStates.playerCount==1 then return "Solo" end
		if gStates.playerCount>1 and (gStates.coop==0 or gStates.WarOfFourComp==true) then return "Comp" end
		if gStates.playerCount>1 and gStates.coop==1 and gStates.WarOfFourComp==false then return "Coop" end
	end, "")
end

function automaticLuaErrorMultiHand()
	return automaticLuaErrorValue(function()
		local count=0
		for _, color in pairs(Player.getAvailableColors()) do if Player[color].seated==true then count=count+1 end end
		if Player["Black"].seated==true then count=count+1 end
		return count==1 and gStates.playerCount>1
	end, "")
end

function sendAutomaticLuaErrorRequest(comment)
	-- Build the normal bug-report context, but protect every lookup independently.
	-- A broken game-state field must never be able to stop the emergency report.
	local gameRecord={Comment=comment, reporter="Automatic Lua Error", reporterVersion=automaticLuaErrorReporterVersion,
		gameScenario=automaticLuaErrorStateValue("gameScenario", ""),
		gameType=automaticLuaErrorGameType(),
		blitz=automaticLuaErrorStateValue("blitz", ""),
		rounds=automaticLuaErrorScenarioValue("rounds", ""),
		mapShape=automaticLuaErrorMapShape(),
		countryTiles=automaticLuaErrorScenarioValue("countryTiles", ""),
		coreTiles=automaticLuaErrorScenarioValue("coreTiles", ""),
		cityTiles=automaticLuaErrorScenarioValue("cityTiles", ""),
		cityLevel=automaticLuaErrorCityLevel(),
		randomTileOrientation=automaticLuaErrorStateValue("randomTileOrientation", ""),
		volkareCampAsCity=automaticLuaErrorStateValue("volkareCampAsCity", ""),
		megapolis=automaticLuaErrorStateValue("megapolis", ""),
		randomCities=automaticLuaErrorStateValue("randomCities", ""),
		positionMageKnight1=automaticLuaErrorMageValue(1),
		positionMageKnight2=automaticLuaErrorMageValue(2),
		positionMageKnight3=automaticLuaErrorMageValue(3),
		positionMageKnight4=automaticLuaErrorMageValue(4),
		positionMageKnight5=automaticLuaErrorMageValue(5),
		proxyPlayer=automaticLuaErrorStateValue("proxyPlayer", false),
		multihand=automaticLuaErrorMultiHand(),
		includeYmirgh=automaticLuaErrorStateValue("useCustomMageKnights", ""),
		dummyAllSkills=automaticLuaErrorStateValue("dummyAllSkills", ""),
		mageKnightLevels=automaticLuaErrorStateValue("mageKnightLevels", ""),
		rampagePursuit=automaticLuaErrorStateValue("rampagePursuit", ""),
		rampageAmbush=automaticLuaErrorStateValue("rampageAmbush", ""),
		rampage=automaticLuaErrorStateValue("rampage", ""),
		removeLostLegionExpansion=automaticLuaErrorStateValue("removeLostLegionExpansion", ""),
		removeShadesOfTezlaMonsters=automaticLuaErrorStateValue("removeShadesOfTezlaMonsters", ""),
		removeApocalypseTerrain=automaticLuaErrorStateValue("removeApocalypseTerrain", ""),
		removeBonusCards=automaticLuaErrorStateValue("removeBonusCards", ""),
		volkareCombatLevel=" ", volkareRaceLevel=" ",
		darknessComing=automaticLuaErrorStateValue("darknessComing", ""),
		startAtNight=automaticLuaErrorStateValue("startAtNight", ""),
		heroChallenges=automaticLuaErrorStateValue("heroChallenges", ""),
		questMod=automaticLuaErrorStateValue("questMod", ""),
		weatherMod=automaticLuaErrorStateValue("weatherMod", ""),
		itemShopMod=automaticLuaErrorStateValue("itemShopMod", ""),
		removeTerrain=automaticLuaErrorStateValue("removeTerrain", ""),
		useAlternatePugs=automaticLuaErrorStateValue("useAlternatePugs", ""),
		riseOfTheForgemasters=automaticLuaErrorStateValue("riseOfTheForgemasters", ""),
		autoFlip=automaticLuaErrorStateValue("autoFlip", ""),
		offerSize=automaticLuaErrorStateValue("offerSize", ""),
		table=automaticLuaErrorValue(function()
			local obj=getObjectFromGUID("519f96")
			if obj~=nil and obj.getScale().x==1 then return "Original" end
			if obj~=nil then return "New" end
		end, "")}
	if automaticLuaErrorValue(function() return gStates.positionMageKnight[5]=="Volkare" end, false)==true then
		gameRecord.volkareCombatLevel=automaticLuaErrorStateValue("volkareCombatLevel", " ")
		gameRecord.volkareRaceLevel=automaticLuaErrorStateValue("volkareRaceLevel", " ")
	end
	--WebRequest.post form tables require string keys and values. Preserve boolean false/true explicitly;
	--nil/error lookups have already been converted to their fallback (normally an empty string).
	for key, value in pairs(gameRecord) do gameRecord[tostring(key)]=tostring(value) end
	WebRequest.post(automaticLuaErrorURL, gameRecord, function(w)
		log("Automatic Lua error report response: "..tostring(w.text))
	end)
end

function automaticLuaBreadcrumb(label)
	label=tostring(label or "")
	if label=="" or label=="maintenanceTick" or label=="onObjectHover" or label:find(" / Wait.",1,true)~=nil then return end
	if automaticLuaErrorBreadcrumbs[#automaticLuaErrorBreadcrumbs]==label then return end
	automaticLuaErrorBreadcrumbs[#automaticLuaErrorBreadcrumbs+1]=label
	while #automaticLuaErrorBreadcrumbs>automaticLuaErrorBreadcrumbLimit do table.remove(automaticLuaErrorBreadcrumbs,1) end
end

function automaticLuaBreadcrumbText()
	if #automaticLuaErrorBreadcrumbs==0 then return "" end
	return table.concat(automaticLuaErrorBreadcrumbs," -> ")
end

function automaticLuaErrorSignature(functionName,errorText)
	local firstLine=tostring(errorText or ""):match("[^\n]+") or ""
	return tostring(functionName).."|"..firstLine
end

function reportAutomaticLuaError(functionName, errorText, context)
	if automaticLuaErrorReporting then return end
	local now=os.time()
	local signature=automaticLuaErrorSignature(functionName,errorText)
	local last=automaticLuaErrorSignatures[signature]
	if last~=nil and now-last<automaticLuaErrorCooldown then return end
	automaticLuaErrorSignatures[signature]=now
	automaticLuaErrorLastReport=now
	--Keep the signature table bounded during very long sessions.
	local signatureCount=0
	for key,when in pairs(automaticLuaErrorSignatures) do
		signatureCount=signatureCount+1
		if now-when>300 then automaticLuaErrorSignatures[key]=nil end
	end
	if signatureCount>100 then automaticLuaErrorSignatures={} automaticLuaErrorSignatures[signature]=now end
	automaticLuaErrorReporting=true
	local comment="AUTOMATIC LUA ERROR\nReporter Version: "..tostring(automaticLuaErrorReporterVersion).."\nFunction: "..tostring(functionName)
	if context~=nil and context~="" then comment=comment.."\n"..tostring(context) end
	local breadcrumbs=automaticLuaBreadcrumbText()
	if breadcrumbs~="" then comment=comment.."\nRecent script actions: "..breadcrumbs end
	comment=comment.."\n\n"..tostring(errorText)
	pcall(function() UI.setAttribute("SendBugComment", "text", comment) end)
	local ok, reportError=pcall(function() sendAutomaticLuaErrorRequest(comment) end)
	if not ok then log("Automatic Lua error report failed: "..tostring(reportError).."\n"..comment) end
	automaticLuaErrorReporting=false
end

function safeCallback(functionName, callback, contextCallback)
	automaticLuaBreadcrumb(functionName)
	local ok, result=xpcall(callback, automaticLuaTraceback)
	if not ok then
		local context=nil
		if contextCallback~=nil then
			local contextOK, contextText=pcall(contextCallback)
			if contextOK==true then context=contextText end
		end
		reportAutomaticLuaError(functionName, result, context)
		return false
	end
	return result
end

--Lighter boundary for high-frequency events. Avoid breadcrumbs and traceback collection on the normal path;
--the event still reports its error and optional context if it fails.
function safeHotCallback(functionName, callback, contextCallback)
	local ok, result=pcall(callback)
	if not ok then
		local context=nil
		if contextCallback~=nil then
			local contextOK, contextText=pcall(contextCallback)
			if contextOK==true then context=contextText end
		end
		reportAutomaticLuaError(functionName, tostring(result), context)
		return false
	end
	return result
end

-- Temporary test hook: type !testerror in chat as an admin.
-- Reports the captured traceback, then rethrows the same error so TTS also shows the player-facing error.
function testAutomaticLuaError()
	local rawError=nil
	local ok, err=xpcall(function()
		error("Intentional automatic Lua error reporting test", 0)
	end, function(e)
		rawError=tostring(e)
		if debug and debug.traceback then return debug.traceback(rawError, 2) end
		return rawError
	end)
	if ok==true then return end
	automaticLuaErrorLastReport=0
	automaticLuaErrorSignatures={}
	reportAutomaticLuaError("TEST - automatic Lua error reporting", err, "Intentional test error triggered with !testerror")
	error(rawError or "Intentional automatic Lua error reporting test", 0)
end

function testAutomaticLuaAsyncError()
	automaticLuaErrorSignatures={}
	safeWaitFrames("TEST async",function() error("Intentional asynchronous automatic Lua error reporting test",0) end,1)
end

function automaticLuaZoneContext(zone, obj)
	local objectGUID=obj~=nil and obj.guid or "nil"
	local zoneGUID=zone~=nil and zone.guid or "nil"
	local objectName=""
	if obj~=nil then
		local ok, name=pcall(function() return obj.getName() end)
		if ok==true and name~=nil then objectName=tostring(name) end
	end
	return "Object: "..tostring(objectGUID)..(objectName~="" and " ("..objectName..")" or "").."\nZone: "..tostring(zoneGUID)
end

function SendDataRequest(player, mouseButton, id)
	if mouseButton=="-1" and (player=="skip" or player=="auto" or (player.color~=nil and Player[player.color].admin==true)) then
		UI.setAttribute("SendDataRequest", "active", "false")
		UI.setAttribute("SendBugRequest", "active", "false")
		UI.setAttribute("SendScoreRequest", "active", "false")
		if id=="SendDataRequestYes" or id=="SendBugRequestYes" or id=="SendScoreRequestYes" then
			local STAT_URL="https://script.google.com/macros/s/AKfycbyivB9o1wmTXvdmKu9SNz6x5Lq8osELhIGNgkNJq2mvP0X5sNIQUQtidETq7ZeqXMm6xw/exec"
			if id=="SendBugRequestYes" then STAT_URL="https://script.google.com/macros/s/AKfycbzU1dSg2mafsUbUTNqOHce0cdWId2I8fkYiNO1JUgG73wtV9E2DCvm7uZ02bXviO-vnFw/exec" end
			if id=="SendScoreRequestYes" then STAT_URL="https://script.google.com/macros/s/AKfycbzLnjL_IH1gOb1hwgfDLrnrsnRkHM9bve20ph4PVqViMe5lhYtBzTOndL4T6DWo4HFXbQ/exec" end
			log("Writing stats.")
			local GameRecord={gameScenario=gStates.gameScenario,
				blitz=gStates.blitz,
				rounds=scenarioList[gStates.scenarioRef][gStates.playersRef].rounds,
				mapShape=scenarioList[gStates.scenarioRef][gStates.playersRef].mapShape,
				countryTiles=scenarioList[gStates.scenarioRef][gStates.playersRef].countryTiles,
				coreTiles=scenarioList[gStates.scenarioRef][gStates.playersRef].coreTiles,
				cityTiles=scenarioList[gStates.scenarioRef][gStates.playersRef].cityTiles,
				randomTileOrientation=gStates.randomTileOrientation,
				volkareCampAsCity=gStates.volkareCampAsCity,
				megapolis=gStates.megapolis,
				randomCities=gStates.randomCities,
				positionMageKnight1=gStates.positionMageKnight[1],
				positionMageKnight2=gStates.positionMageKnight[2],
				positionMageKnight3=gStates.positionMageKnight[3],
				positionMageKnight4=gStates.positionMageKnight[4],
				positionMageKnight5=gStates.positionMageKnight[5],
				proxyPlayer=gStates.proxyPlayer==true,
				includeYmirgh=gStates.useCustomMageKnights,
				dummyAllSkills=gStates.dummyAllSkills,
				mageKnightLevels=gStates.mageKnightLevels,
				rampagePursuit=gStates.rampagePursuit,
				rampageAmbush=gStates.rampageAmbush,
				rampage=gStates.rampage,
				removeLostLegionExpansion=gStates.removeLostLegionExpansion,
				removeShadesOfTezlaMonsters=gStates.removeShadesOfTezlaMonsters,
				removeApocalypseTerrain=gStates.removeApocalypseTerrain,
				removeBonusCards=gStates.removeBonusCards,
				volkareCombatLevel=" ",
				volkareRaceLevel=" ",
				darknessComing=gStates.darknessComing,
				startAtNight=gStates.startAtNight,
				heroChallenges=gStates.heroChallenges,
				apocalypseQuestCards=gStates.apocalypseQuestCards,
				questMod=gStates.questMod,
				weatherMod=gStates.weatherMod,
				itemShopMod=gStates.itemShopMod,
				removeTerrain=gStates.removeTerrain,
				useAlternatePugs=gStates.useAlternatePugs,
				riseOfTheForgemasters=gStates.riseOfTheForgemasters,
				autoFlip=gStates.autoFlip,
				offerSize=gStates.offerSize}
			if GameRecord.mapShape=="{en}Open Limited to 4 Columns{ru}Открытое поле с ограничением в 4 ряда{zh-tw}4 列的限制開放地圖{zh-cn}4 列的限制开放地图 {ko}4열 제한{es}Abierto Limitado a 4 Columnas{fr}Ouvert Limité à 4 Colonnes{pt-br}Aberto Limitado a 4 Colunas{de}Offen Begrenzt auf 4 Spalten" then GameRecord.mapShape="4 Columns" end
			if GameRecord.mapShape=="{en}Open Limited to 3 Columns{ru}Открытое поле с ограничением в 3 ряда{zh-tw}3 列的限制開放地圖{zh-cn}3 列的限制开放地图 {ko}3열 제한{es}Abierto Limitado a 3 Columnas{fr}Ouvert Limité à 3 Colonnes{pt-br}Aberto Limitado a 3 Colunas{de}Offen Begrenzt auf 3 Spalten" then GameRecord.mapShape="3 Columns" end
			if GameRecord.mapShape=="{en}Wedge with No Limitations{ru}Клиновидное поле без ограничений{zh-tw}錐形無限制地圖{zh-cn}锥形无限制地图{ko}쐐기형(무제한){es}En Cuña sin Límites{fr}Coin sans Limites{pt-br}Cônico sem Limitações{de}Keil ohne Begrenzungen" then GameRecord.mapShape="Wedge" end
			if GameRecord.mapShape=="{en}Wedge{ru}Клиновидное поле{zh-tw}錐形地圖{zh-cn}锥形地图{ko}쐐기형{es}En Cuña{fr}Coin{pt-br}Cônico{de}Keil" then GameRecord.mapShape="Wedge" end
			if GameRecord.mapShape=="{en}Fully Open{ru}Полностью открытое поле{zh-tw}完全開放地圖{zh-cn}完全开放地图{ko}전체 개방형{es}Totalmente Abierto{fr}Entièrement Ouvert{pt-br}Totalmente Aberto{de}Vollständig Offen" then GameRecord.mapShape="Fully Open" end
			if GameRecord.mapShape=="{en}Predefined{ru}Предопределенное поле{zh-tw}按劇本預設{zh-cn}按剧本预设{ko}미리 정해짐{es}Predefinido{fr}Prédéfini{pt-br}Pré-definido{de}Vordefiniert" then GameRecord.mapShape="Predefined" end
			if gStates.positionMageKnight[5]=="Volkare" then
				GameRecord.volkareCombatLevel=gStates.volkareCombatLevel
				GameRecord.volkareRaceLevel=gStates.volkareRaceLevel
			end
			GameRecord["cityLevel"]="[ "
			for a, b in pairs(gStates.cityLevels) do
				GameRecord["cityLevel"]=GameRecord["cityLevel"]..tostring(b).." "
			end
			for a=1, 5, 1 do
				if gStates.originalChoiceMageKnights[a]=="Random" or gStates.originalChoiceMageKnights[a]=="All Skills" then GameRecord["positionMageKnight"..tostring(a)]=GameRecord["positionMageKnight"..tostring(a)].." [R]" end
			end
			GameRecord["cityLevel"]=GameRecord["cityLevel"].."]"
			GameRecord["Comment"]=UI.getAttribute("SendBugComment", "text")
			if id=="SendScoreRequestYes" then GameRecord["Comment"]=UI.getAttribute("SendScoreComment", "text") end
			local count=0
			for index, color in pairs(Player.getAvailableColors()) do
				if Player[color].seated==true then count=count+1 end
			end
			if Player["Black"].seated==true then count=count+1 end
			GameRecord.multihand=false
			if count==1 and gStates.playerCount>1 then GameRecord.multihand=true end
			if gStates.playerCount==1 then GameRecord.gameType="Solo" end
			if gStates.playerCount>1 and (gStates.coop==0 or gStates.WarOfFourComp==true) then GameRecord.gameType="Comp" end
			if gStates.playerCount>1 and (gStates.coop==1 and gStates.WarOfFourComp==false) then GameRecord.gameType="Coop" end
			if getObjectFromGUID("519f96").getScale().x==1 then GameRecord["table"]="Original" else GameRecord["table"]="New" end
			if id=="SendBugRequestYes" then
				if player=="auto" then GameRecord["reporter"]="Automatic Lua Error" else GameRecord["reporter"]=Player[player.color].steam_name end
			end
			for _, playerDetails in pairs(turnOrder) do
				--if playerDetails.score==nil then playerDetails["score"]={["finalScore"]=0} end
				if playerDetails.score.finalScore==nil then playerDetails.score.finalScore=0 end
			end
			table.sort(turnOrder, function (k1, k2) return k1.score.finalScore>k2.score.finalScore end)
			if id=="SendScoreRequestYes" then for c=1, 4, 1 do GameRecord["positionMageKnight"..c]="" end end
			for playerNo=1, #turnOrder, 1 do
				for _, color in pairs(Player.getAvailableColors()) do
					local colorPos=math.ceil((Player[color].getHandTransform().position[1]+97.59)/40)
					if turnOrder[playerNo].seatPos==colorPos then
						--steam user name
						if gStates.positionMageKnight[colorPos]~="nobody" then
							local recordPos=colorPos
							if id=="SendScoreRequestYes" then recordPos=playerNo end
							GameRecord["steamName"..recordPos]=Player[color].steam_name
							if GameRecord["steamName"..recordPos]==nil then
								if player.color~=nil then GameRecord["steamName"..recordPos]=Player[player.color].steam_name end
								if player.color==nil then GameRecord["steamName"..recordPos]=Player["black"].steam_name end
								if GameRecord["steamName"..recordPos]==nil then GameRecord["steamName"..recordPos]="No Player" end
							end
						end
						if id=="SendScoreRequestYes" then
							--Mage knight used
							GameRecord["positionMageKnight"..playerNo]=gStates.positionMageKnight[colorPos]
							if GameRecord["positionMageKnight"..playerNo]=="nobody" then GameRecord["positionMageKnight"..playerNo]="" end
							--score achieved
							GameRecord["score"..playerNo]=turnOrder[playerNo].score.finalScore
							if GameRecord["score"..playerNo]==0 then GameRecord["score"..playerNo]="" end
							if GameRecord["riseOfTheForgemasters"]==0 then GameRecord["riseOfTheForgemasters"]="" end
						end
						break
					end
				end
			end
			table.sort(turnOrder, function (k1, k2) return k1.tactic<k2.tactic end)
			WebRequest.post(STAT_URL, GameRecord, function(w)
				log(w.text)
				if id=="SendBugRequestYes" or id=="SendScoreRequestYes" then
					broadcastToAll("{en}Data Received, Thank You{ru}Данные получены, спасибо!{zh-tw}數據已收到，謝謝{zh-cn}数据已收到，谢谢{ko}데이터 수신 완료. 감사합니다.{es}Datos Recibidos, Gracias{fr}Données Reçues, Merci{pt-br}Dados recebidos, obrigado{de}Daten Erfasst, Danke", {1,1,0.5})
				end
			end)
		end
	end
end

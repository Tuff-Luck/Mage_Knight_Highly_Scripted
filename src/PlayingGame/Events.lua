-- TTS persistence, raw event handling, maintenance and runtime event dispatch.

function __tryObjectEnterContainer_raw(container, object)
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
	--Refresh saved Puppets so presentation changes (decal/hover data) also apply to existing accepted Puppets.
	safeWaitFrames("Events",function() for guid,record in pairs(gStates.puppetMasterPuppets or {}) do puppetMasterRefreshPresentation(getObjectFromGUID(guid),record) end end,2)
	--Goblin Warrens enemies come from an Infinite Bag and therefore receive new GUIDs. Restore their
	--runtime monster registration before a saved mid-combat game can inspect or clean them up.
	safeWaitFrames("Events",function() apocalypseQuestRestoreGoblinEnemies() end,2)
	--Restore any saved live Proxy choice, including terrain, offer-card, enemy, and Source-mana controls.
	safeWaitFrames("Events",function() proxyRestorePendingChoiceUI() end,4)
	safeWaitFrames("Events",function() refreshMineClaimPanel() end, 1)
	--Reapply explicit ALT zoom directions to any City/avatar objects already out on the table.
	safeWaitFrames("Events",function() refreshAltViewAngles() end, 2)
	--Remove TTS's multi-digit typing delay from existing player Deed Decks after load.
	safeWaitFrames("Events",function() for seatPos, _ in pairs(deedDeckZones) do setDeedDeckImmediateNumberTyping(seatPos) end end, 1)
	if gStates.finalTurnReason~=nil then ensureFinalTurnBoundary() end
	safeWaitFrames("Events",function() horsemanRestoreRuntimeState() end,2)
	startMaintenanceTick()
	--Static translated UI text lives in Global.xml; reapply it once so TTS resolves language tags.
	reapplyXmlText()
	-----------
	refreshResourceTrackerText()--Refresh the tracker from saved values so TTS resolves its language tags on load.
	UI.setAttribute("CoopAssaultMainTableText3", "active", "false")
	--The wall assault interface is only shown when the assault entry side cannot be determined automatically.
	UI.hide("WallAssaultChoice")
	UI.hide("ExtraTurnChoice")
	refreshProxySetupLabel()
	UI.setAttribute("followEnemyView", "isOn", gStates.cameraFollowEnemy and "true" or "false")
	--UI.setAttribute("questViewText", "color", "Black")
	--UI.setAttribute("questView", "active", "false")
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
	--Dynamic object UIs are refreshed by PlayingGame.Lifecycle after the complete Global load path returns.
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
							UI.setAttribute("Mage"..a.."CompleteText", "text", "{en}Complete{ru}Завершить{zh-tw}完成{zh-cn}完成{ko}완료{es}Completo{fr}Compléter{pt-br}Completo{de}Fertig")
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
		UI.setAttribute("helpButtonRealText", "Text", "{en}Help{ru}Помощь{zh-tw}帮  助{zh-cn}帮  助{ko}도움말{es}Ayudar{fr}Aider{pt-br}Ajuda{de}Hilfe")
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
		refreshTerrainExploreOptions(false)
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
		for _, mirrorGUID in pairs(gStates.mirrorSource or {}) do
			local mirrorObj=getObjectFromGUID(mirrorGUID)
			if mirrorObj~=nil then mirrorObj.registerCollisions() end
		end
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
	return safeCallback("onSave",function()
		saveZigguratPyramidUI()
		saveSetupState()
		local data_to_save={
			turnOrder=turnOrder,
			gStates=gStates,
			rollerDice=rollerOnSave()}
		saved_data=JSON.encode(data_to_save)
		return saved_data
	end)
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
	if picked_up_object~=nil and mapTokenNeedsArrangement~=nil and mapTokenNeedsArrangement(picked_up_object)==true then
		mapTokenReleaseObject(picked_up_object)
	end
	puppetMasterTrackPickup(player_color,picked_up_object)
	--Unlocking and lifting an active Destroyed token undoes that placement without awarding a restoration.
	if player_color~=nil and picked_up_object.getGMNotes()=="Destroyed" and gStates.destroyedSites~=nil and gStates.destroyedSites[picked_up_object.guid]~=nil then
		if undoDestroyedSitePlacement(picked_up_object)==true then
			broadcastToAll("{en}Destroyed Site placement undone.{ru}Размещение жетона разрушенного места отменено.{zh-tw}已撤銷「被摧毀地點」標記的放置。{zh-cn}已撤销“被摧毁地点”标记的放置。{ko}파괴된 장소 토큰 배치를 취소했습니다.{es}Se deshizo la colocación del Sitio Destruido.{fr}Le placement du Site Détruit a été annulé.{pt-br}A colocação do Local Destruído foi desfeita.{de}Die Platzierung des zerstörten Ortes wurde rückgängig gemacht.")
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
		broadcastToAll("{en}City Models are placed by the script. There is really no reason for a player to be manipulating them.\nInteract with the cities by using the city cards{ru}Модели городов размещаются по скрипту. Игрокам нет смысла их трогать.\nВзаимодействуйте с городами, используя карты городов{zh-tw}城市模型由脚本自动放置, 玩家不需手动干预{zh-cn}城市模型由脚本自动放置, 玩家不需手动干预{ko}도시 피규어는 스크립트에 의해 자동으로 처리됩니다. 직접 조작할 필요는 없습니다.\n도시 카드를 통해 상호작용 하시면 됩니다. {es}Los modelos de ciudad son colocados por el guión. Realmente no hay ninguna razón para que un jugador los manipule.\nInteractuar con las ciudades usando las tarjetas de la ciudad{fr}Les modèles de ville sont placés par le script. Il n'y a vraiment aucune raison pour qu'un joueur les manipule.\nInteragissez avec les villes en utilisant les cartes de ville{pt-br}Modelo das Cidades são colocadas no mapa pelo Script. Não há motivo para um jogador manipulá-las.\nInteraja com as cidades usando as cartas de cidade.{de}Die Stadtmodelle werden durch das Skript platziert. Es gibt wirklich keinen Grund für einen Spieler, sie zu manipulieren.\nInteragieren Sie mit den Städten, indem Sie die Stadtkarten benutzen", {1,1,0.5})
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
			hover_object.setDescription("{en}Deck contents are only visible for this player.{ru}Содержимое колоды видно только этому игроку.{zh-tw}牌庫內容僅此玩家可見。{zh-cn}牌库内容仅此玩家可见。{ko}덱 내용은 이 플레이어에게만 보입니다.{es}El contenido del mazo solo es visible para este jugador.{fr}Le contenu du paquet n’est visible que par ce joueur.{pt-br}O conteúdo do baralho só é visível para este jogador.{de}Der Inhalt des Decks ist nur für diesen Spieler sichtbar.")
		end
	end

	refreshMonsterHoverDescription(hover_object)
end

--Update skill Locations, Update Players Location details, and Update the UI and trigger a Level up if a mage shield was moved manually
function __onObjectDrop_raw(player_color, dropped_object)
	local droppedGUID=dropped_object.guid
	if terrainTiles[droppedGUID]~=nil then
		runtimeMapInvalidateTerrain()
		--EXPLORE legality is derived from the settled physical map. onObjectEnterZone can fire while a
		--dragged tile is still crossing the map zone, so rebuild only after the final drop has settled.
		safeWaitCondition("Events",function() refreshTerrainExploreOptions() end,function()
			local tile=getObjectFromGUID(droppedGUID)
			return tile==nil or (tile.held_by_color==nil and tile.resting==true and tile.isSmoothMoving()==false)
		end,5,function() refreshTerrainExploreOptions() end)
	end
	local droppedHorseman=horsemanTokenToName~=nil and horsemanTokenToName[droppedGUID] or nil
	if gStates.gameScenario=="Against the Horsemen Blitz" and (terrainTiles[droppedGUID]~=nil or droppedHorseman~=nil) then
		safeWaitFrames("Events",function() againstHorsemenRefreshReveals() end,2)
	end
	if mapTokenNeedsArrangement~=nil and mapTokenNeedsArrangement(dropped_object)==true then
		--The map scripting zone is intentionally short. A token dropped from high enough can still be
		--above it three frames later, so do not gamble on a later zone-entry callback. Claim the manual
		--drop now; the shared settle helper waits for the real physics landing before arranging the hex.
		mapTokenSettleArrival(droppedGUID,nil,{force=true})
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
	--recorded by the Map avatar-location handler. Do not do an earlier full-offer refresh against the old hex.
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
			else broadcastToAll("{en}That location cannot be destroyed.{ru}Это место нельзя уничтожить.{zh-tw}該地點不能被摧毀。{zh-cn}该地点不能被摧毁。{ko}그 장소는 파괴할 수 없습니다.{es}Ese lugar no puede ser destruido.{fr}Ce lieu ne peut pas être détruit.{pt-br}Esse local não pode ser destruído.{de}Dieser Ort kann nicht zerstört werden.", {1,1,0.5}) end
		end
		return
	end

	--Update Players Location details.
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
			local avatarGUID=dropped_object.guid
			local function updateAvatarLocation()
				local liveAvatar=getObjectFromGUID(avatarGUID)
				if liveAvatar~=nil then mapAvatarLocationDetails(player_color,avatar,liveAvatar) end
			end
			safeWaitCondition("Events",updateAvatarLocation,function()
				local liveAvatar=getObjectFromGUID(avatarGUID)
				return liveAvatar==nil or liveAvatar.resting
			end,1.5,updateAvatarLocation)
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
			local volkareGUID=gStates.volkareModel
			safeWaitFrames("Events",function()
				local volkareObj=getObjectFromGUID(volkareGUID)
				if volkareObj~=nil then volkareObj.addDecal({name="Volkare's Return Guide", url="https://steamusercontent-a.akamaihd.net/ugc/1617311764022517379/17F0D137572FE6672A880B1865AF9D7B66D8061F/",
					position={-1.7, 0.05, 0.0}, rotation={90, 180, 0}, scale={3.24/scale[1], 5.508/scale[3], 1}}) end
			end, 20)
		end
		if gStates.gameScenario=="Volkare's Quest" or gStates.gameScenario=="The War of Four" then
			local volkareGUID=gStates.volkareModel
			safeWaitFrames("Events",function()
				local volkareObj=getObjectFromGUID(volkareGUID)
				if volkareObj~=nil then volkareObj.addDecal({name="Volkare's Quest Guide", url="https://steamusercontent-a.akamaihd.net/ugc/1617311764022517042/4160839B27C5F84E3D4D860408AE19780E48AEC4/",
					position={1.6, 0.05, 1.4}, rotation={90, 180, 0}, scale={3.6/scale[1], 3.5/scale[3], 1}}) end
			end, 20)
		end
		--Setup owns Volkare's initial lock. Locking from onObjectSpawn races map construction because
		--the model is spawned/reloaded before the starting terrain exists beneath it.
		spawn_object.setRotation({0, 180, 0})
		cityLevelButtons(gStates.volkareModel, "Volkar")
	end

	--Update competitive-state skills from the canonical skill metadata.
	if skillTokens[spawn_object.guid]~=nil and skillTokens[spawn_object.guid].competitiveState==true then
		gStates.mageSkills[spawn_object.guid]={spawn_object.getPosition()[1], spawn_object.getPosition()[2], spawn_object.getPosition()[3]}
		if gStates.firstStarted==true then skillButtonActivate() else higherLevelSkillClaimButons() end
	end
	if skillTokens[spawn_object.guid]~=nil and (skillTokens[spawn_object.guid].skillType=="Coop" or skillTokens[spawn_object.guid].skillType=="Comp") and coopCompSkillPlayLocked()==true then safeWaitFrames("Events",function() refreshCoopCompSkillXs() end, 2) end
end

--Alter Fame board Values, Skill register, and Add icons when changing avatar **This script runs when exiting the game**
function __onObjectDestroy_raw(destroyedObj)
	if destroyedObj==nil then return end
	local destroyedGuid=destroyedObj.guid
	if runtimeMapContainsGUID(destroyedGuid)==true then
		if terrainTiles[destroyedGuid]~=nil then runtimeMapInvalidateTerrain() else runtimeMapInvalidateObjects() end
	end
	if mapTokenNeedsArrangement~=nil and mapTokenNeedsArrangement(destroyedObj)==true then mapTokenReleaseObject(destroyedObj) end
	local questScorePlayer=apocalypseQuestScoreMarkerPlayerIndex(destroyedGuid)
	if questScorePlayer~=nil then
		if apocalypseQuestScoresRequired()==true then
			broadcastToAll("{en}This scenario can't be run without Quest Scores.{ru}Этот сценарий нельзя запустить без очков заданий.{zh-tw}此劇本必須啟用任務分數。{zh-cn}此剧本必须启用任务分数。{ko}이 시나리오는 퀘스트 점수 없이 진행할 수 없습니다.{es}Este escenario no puede jugarse sin Puntuación de Misiones.{fr}Ce scénario ne peut pas être joué sans Scores de Quête.{pt-br}Este cenário não pode ser jogado sem Pontuação de Missões.{de}Dieses Szenario kann nicht ohne Quest-Punkte gespielt werden.",{1,1,0.5})
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
local skillOfferEntrySerial={}--Per-object pass-through guard for the Skill Offer zone.
dieRollEnterPause=nil
workingOnTerrain={}
local shieldLocationWait={}--Per-object debounce so simultaneous shield/site moves cannot cancel each other.
masterOfChaosWait=nil
randomizePause=nil
local sourceRandomizeFences={{"7e09c6", 7.40}, {"0a7c95", 3.60}, {"ec49dd", 7.40}, {"c17ca2", 3.60}}
local function pulseSourceRandomizeFences()
	for _, fenceDetails in ipairs(sourceRandomizeFences) do
		local fence=getObjectFromGUID(fenceDetails[1])
		if fence~=nil then fence.setScale({0.10, 20.00, fenceDetails[2]}) end
	end
	if randomizePause~=nil then Wait.stop(randomizePause) end
	randomizePause=safeWaitTime("Events",function()
		for _, fenceDetails in ipairs(sourceRandomizeFences) do
			local fence=getObjectFromGUID(fenceDetails[1])
			if fence~=nil then fence.setScale({0.10, 0.1, fenceDetails[2]}) end
		end
	end, 3)
end

local function scheduleShieldLocation(obj, zone, status)
	local guid=obj~=nil and obj.guid or nil
	local zoneGUID=zone~=nil and zone.guid or nil
	if guid==nil or zoneGUID==nil then return end
	if shieldLocationWait[guid]~=nil then Wait.stop(shieldLocationWait[guid]) end
	shieldLocationWait[guid]=safeWaitFrames("Events",function()
		shieldLocationWait[guid]=nil
		local liveObj=getObjectFromGUID(guid)
		local liveZone=getObjectFromGUID(zoneGUID)
		if liveObj==nil or liveZone==nil then return end
		shieldLocation(liveObj, liveZone, status)
		mainUIUpdate(status=="enter" and "Shield Dropped" or "Shield Removed")
		if status=="enter" and apocalypseQuestsUsed()==true then apocalypseQuestRefreshOfferButtons() end
	end,2)
end
local function zoneEventContext(zone, obj)
	if zone==nil or obj==nil then return nil end
	local zoneGUID=zone.guid
	local objGUID=obj.guid
	if zoneGUID==nil or objGUID==nil then return nil end
	local zoneInfo=playerZoneLookup[zoneGUID]
	return {
		zone=zone,
		obj=obj,
		zoneGUID=zoneGUID,
		objGUID=objGUID,
		zoneInfo=zoneInfo,
		objType=obj.type,
		isMap=zoneGUID==mapArea,
		playerZoneKind=zoneInfo~=nil and zoneInfo.kind or nil
	}
end

local settledZoneEntrySerial={}
local function zoneContainsGUID(zone,guid)
	if zone==nil or guid==nil then return false end
	for _,candidate in pairs(zone.getObjects()) do if candidate.guid==guid then return true end end
	return false
end

local function scheduleSettledZoneEntry(ctx,callback,channel)
	if ctx==nil or callback==nil then return end
	local zoneGUID=ctx.zoneGUID
	local objGUID=ctx.objGUID
	if zoneGUID==nil or objGUID==nil then return end
	local key=tostring(channel or "default").."|"..zoneGUID.."|"..objGUID
	local serial=(settledZoneEntrySerial[key] or 0)+1
	settledZoneEntrySerial[key]=serial
	safeWaitCondition("Events",function()
		if settledZoneEntrySerial[key]~=serial then return end
		settledZoneEntrySerial[key]=nil
		local liveZone=getObjectFromGUID(zoneGUID)
		local liveObj=getObjectFromGUID(objGUID)
		if liveZone==nil or liveObj==nil or zoneContainsGUID(liveZone,objGUID)~=true then return end
		local liveCtx=zoneEventContext(liveZone,liveObj)
		if liveCtx~=nil then callback(liveCtx) end
	end,function()
		local liveObj=getObjectFromGUID(objGUID)
		return liveObj==nil or (liveObj.resting==true and liveObj.isSmoothMoving()==false)
	end)
end

local function handleZoneEnterPrelude(ctx)
	local zone=ctx.zone
	local obj=ctx.obj
	local zoneGUID=ctx.zoneGUID
	local objGUID=ctx.objGUID
	if ctx.isMap and mapTokenNeedsArrangement~=nil and mapTokenNeedsArrangement(obj)==true then
		--A held object will be handled once by onObjectDrop; retries here are only for scripted arrivals.
		if obj.held_by_color==nil then mapTokenScheduleObject(objGUID) end
	end
	if gStates.apocalypseDragonGroundCombat~=nil and apocalypseDragonGroundCombatToken~=nil then
		local active,headName,owner=apocalypseDragonGroundCombatToken(objGUID)
		if active==true and headName~="Control" and owner~=nil then safeWaitFrames("Events",function() apocalypseDragonRefreshGroundFameGain(owner) end,1) end
	end
	--A scripted Deed transfer may physically cross unrelated scripting zones. Only its destination Deed zone
	--is allowed to react while the card is travelling.
	if deedTransferState~=nil and deedTransferState.transit[objGUID]~=nil and zoneGUID~=deedTransferState.transit[objGUID] then return true end
	--Fractured Lands holds a new tile above the map scripting zone while it is being oriented.
	--Done only unlocks it. Its actual fall into this zone clears the orientation controls/state,
	--then continues through the ordinary terrain-entry handler below.
	if ctx.isMap and gStates.fracturedLandsOrientation~=nil and gStates.fracturedLandsOrientation.guid==objGUID then
		if obj.getLock()==true then return true end
		obj.clearButtons()
		obj.UI.setXmlTable({{}})
		gStates.fracturedLandsOrientation=nil
		explorePause=false
	end
	--A pending Steady Tempo may be picked up while the player is deciding. Rebuild its controls
	--when it returns to that player's play area, or accept a manual move to Deed/discard as resolution.
	if gStates.steadyTempoPending~=nil and gStates.steadyTempoPending[objGUID]~=nil and isSteadyTempoGUID(objGUID)==true then
		local seatPos=gStates.steadyTempoPending[objGUID]
		if zoneGUID==playerPlayAreas[seatPos] then safeWaitFrames("Events",function() steadyTempoRefreshCard(objGUID) end, 2)
		elseif zoneGUID==deedDeckZones[seatPos] or zoneGUID==deedDeckDiscardZones[seatPos] then steadyTempoClearPending(objGUID) end
	end
	--Meditation / Trance needs its object UI as soon as the played card reaches a player area.
	if objGUID==meditationTranceCardGUID and ctx.playerZoneKind=="play" then
		safeWaitFrames("Events",function() refreshMeditationTrance() end, 2)
	end
	return false
end

local function handleStartedZoneEnterPrelude(ctx)
	local objGUID=ctx.objGUID
	if ctx.playerZoneKind=="play" and (gStates.apocalypseQuestUnderSiegeReady~=nil or skillTokens[objGUID]~=nil) then
		scheduleSettledZoneEntry(ctx,function(liveCtx)
			local liveGUID=liveCtx.objGUID
			if gStates.apocalypseQuestUnderSiegeReady~=nil then apocalypseQuestUnderSiegeCardPlayed(liveCtx.zone,liveCtx.obj) end
			local enteredSkill=skillTokens[liveGUID]
			if enteredSkill~=nil and liveCtx.zoneInfo~=nil and liveCtx.zoneInfo.kind=="play" then
				local playerIndex=turnOrderIndexAtSeat(liveCtx.zoneInfo.seatPos)
				if playerIndex~=nil then
					tomeSkillEnteredPlay(liveGUID, playerIndex)
					if enteredSkill.skillType=="Coop" or enteredSkill.skillType=="Comp" then activateCoopCompSkill(liveGUID, playerIndex) end
				end
			end
		end,"started")
	end
end

local function handleTurnOrderZoneEnter(ctx)
	local obj=ctx.obj
	local zoneGUID=ctx.zoneGUID
	local objGUID=ctx.objGUID
	--Check if a turn marker has been flipped
	if zoneGUID==turnOrderArea then
		for c, d in pairs(turnOrder) do
			if objGUID==d.turnOrderTokenGUID then
				safeWaitFrames("Events",function() safeWaitCondition("Events",function()
					local turnOrderTokens=getObjectFromGUID(turnOrderArea).getObjects()
					table.sort(turnOrderTokens, function (k1, k2) return k1.getPosition()[3]>k2.getPosition()[3] end)
					--check if all turn order tokens are present
					if #turnOrderTokens==gStates.playerCount+gStates.coop then
						local posOne=-19.4
						local inOrder=true
						--check turn order tokens fill from 1st to last position
						for a, b in ipairs(turnOrderTokens) do
							if b.getPosition()[3]>posOne-0.5 and b.getPosition()[3]<posOne+0.6 then
								posOne=posOne-1.4
								for c, d in pairs(turnOrder) do
									if b.guid==d.turnOrderTokenGUID then turnOrder[c].customSort=a break end
								end
							else
								inOrder=false break
							end
						end
						--update turnorder sequence to match token order
						if inOrder==true then
							if getObjectFromGUID("0934f2")~=nil then table.sort(turnOrder, function (k1, k2) return k1.customSort < k2.customSort end) end
							broadcastToAll("{en}Turn order updated{ru}Порядок хода обновлен{zh-tw}回合顺序更新了{zh-cn}回合顺序更新了{ko}라운드 순서가 업데이트되었습니다{es}Orden de giro actualizado{fr}Ordre de rotation mis à jour{pt-br}Ordem de Turno atualizada{de}Zugreihenfolge aktualisiert", {1,1,0.5})
							mainUIUpdate("Turn marker entered it's zone")
						end
					end
				end, function() return obj.resting end) end, 2)
				break
			end
		end
	end

end

local function handleMapLocationZoneEnter(ctx)
	local zone=ctx.zone
	local obj=ctx.obj
	local zoneGUID=ctx.zoneGUID
	local objGUID=ctx.objGUID
		--Check if a shield, avatar, secret Dungeon, or Secret Tomb has been played to cities or board
	if zoneGUID==mapArea or zoneGUID==GUID.zone.blueCity or zoneGUID==GUID.zone.redCity or zoneGUID==GUID.zone.greenCity or zoneGUID==GUID.zone.whiteCity or zoneGUID==volkare.discZone or zoneGUID==darkCrusader.discZone or zoneGUID==elementalist.discZone then
		local objectName=obj.getName()
		local objectNotes=obj.getGMNotes()
		if (objectName=="Shield" or objectNotes=="Burned Monastery" or objectName=="Secret Dungeon" or objectName=="Secret Tomb") and obj.getLock()==false then
			scheduleShieldLocation(obj, zone, "enter")
		else
			if zoneGUID==GUID.zone.blueCity or zoneGUID==GUID.zone.redCity or zoneGUID==GUID.zone.greenCity or zoneGUID==GUID.zone.whiteCity or zoneGUID==volkare.discZone then
				--Record if avatar is dropped on city card
				for b, mageSearch in pairs(turnOrder) do
					if mageSearch.mage==objectName then
						local found=false
						if gStates.cityMonsterQty[cityScriptZones[zoneGUID].cityGUID]~=nil then
							for cityguid, monsters in pairs(gStates.cityMonsterQty[cityScriptZones[zoneGUID].cityGUID]) do
								if monsters=="alive" then found=true end
							end
						end
						if found==false then
							if zoneGUID~=volkare.discZone then
								broadcastToAll(joinLang({translateWord[mageSearch.mage], "{en} has entered the City.{ru} заходит в Город.{zh-tw}已经进入城市了{zh-cn}已经进入城市了{ko}: 도시에 입장했습니다.{es} ha entrado en la Ciudad.{fr} est entré dans la Ville.{pt-br} entrou na Cidade.{de} hat die Stadt betreten."}), positionToColor(b))
							else
								broadcastToAll(joinLang({translateWord[mageSearch.mage], "{en} has entered the Camp.{ru} заходит в Лагерь.{zh-tw}已经进入营地了{zh-cn}已经进入营地了{ko}: 볼케어 진영에 입장했습니다.{es} ha entrado en el Campamento.{fr} est entré dans le Camp.{pt-br} entrou no Acampamento.{de} hat das Lager betreten."}), positionToColor(b))
							end
						else
							if zoneGUID~=volkare.discZone then
								broadcastToAll(joinLang({translateWord[mageSearch.mage], "{en} is Assaulting the City.{ru} штурмует Город.{zh-tw}正在突袭城市{zh-cn}正在突袭城市{ko}: 도시를 강습합니다.{es} está Asaltando la Ciudad.{fr} est à l'assaut de la Ville.{pt-br} invadiu a Cidade.{de} greift die Stadt an."}), positionToColor(b))
							else
								broadcastToAll(joinLang({translateWord[mageSearch.mage], "{en} is Assaulting the Camp.{ru} штурмует Лагерь.{zh-tw}正在突袭营地{zh-cn}正在突袭营地{ko}: 볼케어 진영을 강습합니다.{es} está Asaltando el Campamento.{fr} est à l'assaut du Camp.{pt-br} invadiu o Acampamento.{de} greift das Lager an."}), positionToColor(b))
							end
						end
						break
					end
				end
			end
		end
		if objectName=="Shield" then gStates.shieldsDropped[objGUID]=true end
	end

	--Manually destroy a hex
	--if zoneGUID==mapArea and obj.getGMnotes()="Destroyed" then
	--	destroyRestoreLocation(nil, "-1", "id", "manualDestroy", obj)
	--end

end

local function handleMapVisualZoneEnter(ctx)
	local obj=ctx.obj
	local zoneGUID=ctx.zoneGUID
	local objGUID=ctx.objGUID
	--Add xml Image back to Pursuing and Ambushing monster tokens. Non-monsters entering the map
	--never need this Object UI pass, which is relatively expensive in TTS.
	if zoneGUID==mapArea and monsterPugs[objGUID]~=nil and (gStates.rampageAmbush==true or gStates.rampagePursuit==true) then
		local existingButtons=obj.UI.getXmlTable() or {}
		local keptButtons={}
		local uiChanged=false
		for _, xmlParent in pairs(existingButtons) do
			if xmlParent.tag=="Image" then uiChanged=true else keptButtons[#keptButtons+1]=xmlParent end
		end
		existingButtons=keptButtons
		--Ambushing Circle
		if gStates.ambushingMonsters[objGUID]~=nil then
			uiChanged=true
			existingButtons[#existingButtons+1]={tag="Image", attributes={id="Ambush Circle", height=1100, width=1100,
				position="0 0 -1", rotation="0 0 0", image="Ambush Circle"}}
		end
		--pursuit Shield
		for mage1, monsters in pairs(gStates.pursuingMonsters) do
			if monsters[objGUID]~=nil then
				for _, mage2 in pairs(mageKnights) do
					if mage2.mage==mage1 then
						uiChanged=true
						existingButtons[#existingButtons+1]={tag="Image", attributes={id="Pursue Shield", height=90, width=90,
							position="0 0 -15", rotation="0 0 180", image="Shield Button "..mage1}}
						local pursuit=monsters[objGUID]
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
	if zoneGUID==mapArea and objGUID~=gStates.volkareModel then
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
		if gStates.monsterPerks[objGUID]~=nil and gStates.monsterPerks[objGUID].wallFortified~=nil then gStates.monsterPerks[objGUID].wallFortified=nil end
	end

	--Add decals to monster tokens
	if (zoneGUID==mapArea or zoneGUID==GUID.zone.blueCity or zoneGUID==GUID.zone.redCity or zoneGUID==GUID.zone.greenCity or zoneGUID==GUID.zone.whiteCity) and gStates.monsterPlayLocation[objGUID]~=nil then
		--fortified
		if monsterPugs[objGUID]~=nil and monsterPugs[objGUID].unfortified==nil then
			local target=gStates.monsterPlayLocation[objGUID]
			local mapObjects=getObjectFromGUID(mapArea).getObjects()
			local terTile, monsterhexBearing=terrainHexAtPosition(target, mapObjects)
			if terTile~=nil and monsterhexBearing~=nil then
				--Add Fortified Site Icon
				if terrainTiles[terTile.guid].hexFeature[monsterhexBearing]=="mage tower" or terrainTiles[terTile.guid].hexFeature[monsterhexBearing]=="keep" then
					--Add Icon
					local found=false
					local existingDecals=obj.getDecals() or {}
					for _, decalDetails in pairs(existingDecals) do
						if decalDetails.name=="Fortified" then found=true break end
					end
					if found==false then
						obj.addDecal({name="Fortified", url="https://steamusercontent-a.akamaihd.net/ugc/15769941683634999180/45D8BF9859C1F2C026A3B40DA634B74286E2C3EB/", position={0.7, 0.15, -0.9}, rotation={90, 180, 0}, scale={0.72, 0.72, 1}})
						if gStates.monsterPerks[objGUID]==nil then gStates.monsterPerks[objGUID]={fortified=true} else gStates.monsterPerks[objGUID].fortified=true end
					end
				end
			end
		end
		--City Bonus
		cityBonusDecals(obj, obj)
		safeWaitFrames("Events",function() addAvatarButtons() end, 5)
	end

end

local function handleHandZoneEnter(ctx)
	local zoneGUID=ctx.zoneGUID
	local objGUID=ctx.objGUID
	local zoneInfo=ctx.zoneInfo
	local objType=ctx.objType
	--Day Tactic 4 hand bonus only changes when the current player's hand changes.
	if objType=="Card" and gStates.turnNumber>0 and turnOrder[gStates.turnNumber]~=nil and zoneGUID==handZones[turnOrder[gStates.turnNumber].seatPos] then scheduleTactic4HandBonusRefresh() end

	--Record Cards in hand as part of a players deed deck
	if objType=="Card" and zoneInfo~=nil and zoneInfo.kind=="hand" then
		scheduleSettledZoneEntry(ctx,function(liveCtx)
			local handPlayerIndex=turnOrderIndexAtSeat(liveCtx.zoneInfo.seatPos)
			local cardType=gameCardType(liveCtx.obj)
			if handPlayerIndex~=nil and cardType~="Regular Unit" and cardType~="Elite Unit" then
				for b=1, #turnOrder, 1 do
					local found=false
					for cc=1, #turnOrder[b].deadDeckInventory, 1 do
						if liveCtx.objGUID==turnOrder[b].deadDeckInventory[cc] then table.remove(turnOrder[b].deadDeckInventory, cc) found=true break end
					end
					if found==true then break end
				end
				turnOrder[handPlayerIndex].deadDeckInventory[#turnOrder[handPlayerIndex].deadDeckInventory+1]=liveCtx.objGUID
				mainUIUpdate("Card Entered Hand")
			end
		end,"hand")
	end

end

local function handleClaimZoneEnter(ctx)
	local obj=ctx.obj
	local zoneGUID=ctx.zoneGUID
	local objGUID=ctx.objGUID
	--Offer cards can enter a broad zone while still moving toward their final row. Wait until the
	--card is resting before deciding whether it is a Unit, Monastery AA, normal AA, or Spell.
	if cardClaimingZones[zoneGUID]~=nil then
		local offerZoneGUID=zoneGUID
		local offerCardGUID=objGUID
		safeWaitCondition("Events",function()
			local offerZone=getObjectFromGUID(offerZoneGUID)
			local offerCard=getObjectFromGUID(offerCardGUID)
			if offerZone==nil or offerCard==nil then return end
			local stillInZone=false
			for _,zoneObj in pairs(offerZone.getObjects()) do
				if zoneObj.guid==offerCardGUID then stillInZone=true break end
			end
			if stillInZone~=true then return end
			local cardSource=offerClaimSource(offerZoneGUID,offerCard)
			if gameCards[offerCardGUID]==nil or cardSource==nil then return end
			--Remove card ownership if returned to an offer.
			for b=1,#turnOrder do
				local found=false
				for c=1,#turnOrder[b].deadDeckInventory do
					if offerCardGUID==turnOrder[b].deadDeckInventory[c] then table.remove(turnOrder[b].deadDeckInventory,c) found=true break end
				end
				if found==true then break end
			end
			if gStates.tacticShown==false and gStates.tacticRemove==false then
				offerCard.UI.setXmlTable({createClaimButton(offerCardGUID,cardSource)})
			end
		end,function()
			local offerCard=getObjectFromGUID(offerCardGUID)
			return offerCard==nil or offerCard.resting
		end)
	end

	--protect skill zone from passing through objects
	if zoneGUID==GUID.zone.skillOffer then
		local serial=(skillOfferEntrySerial[objGUID] or 0)+1
		skillOfferEntrySerial[objGUID]=serial
		safeWaitFrames("Events",function()
			if skillOfferEntrySerial[objGUID]==serial then skillOfferEntrySerial[objGUID]=nil end
		end,50)
	end

	--A tactic returned to its slot only needs its own claim button restored. Wait until the card
	--has settled so a card merely crossing the zone cannot acquire a claim button mid-move.
	local tacticSource=tacticClaimingZones[zoneGUID]
	if tacticSource~=nil and isTacticCard(obj) then
		local tacticZoneGUID=zoneGUID
		local tacticCardGUID=objGUID
		safeWaitCondition("Events",function()
			local tacticZone=getObjectFromGUID(tacticZoneGUID)
			local tacticCardObj=getObjectFromGUID(tacticCardGUID)
			if tacticZone==nil or tacticCardObj==nil then return end
			local stillInZone=false
			for _,zoneObj in pairs(tacticZone.getObjects()) do
				if zoneObj.guid==tacticCardGUID then stillInZone=true break end
			end
			if stillInZone~=true then return end
			if gStates.tacticShown==true then
				if turnOrder[gStates.turnNumber].mage~=gStates.positionMageKnight[5] then
					tacticCardObj.UI.setXmlTable({createClaimButton(tacticCardGUID,tacticSource)})
				end
			elseif gStates.tacticRemove==true and gStates.discardTactics~=2 then
				tacticCardObj.UI.setXmlTable({createClaimButton(tacticCardGUID,"removeTactic"..tacticSource:sub(7,8))})
			end
		end,function()
			local tacticCardObj=getObjectFromGUID(tacticCardGUID)
			return tacticCardObj==nil or tacticCardObj.resting
		end)
	end

end

local function handlePlayerBoardZoneEnter(ctx)
	local zoneInfo=ctx.zoneInfo
	if ctx.settledPlayerZoneEntry~=true and zoneInfo~=nil and (zoneInfo.kind=="play" or zoneInfo.kind=="unit" or zoneInfo.kind=="crystal") then
		scheduleSettledZoneEntry(ctx,function(liveCtx)
			liveCtx.settledPlayerZoneEntry=true
			playerBoardZoneEnterSettled(liveCtx)
		end,"playerBoard")
		return false
	end
	return playerBoardZoneEnterSettled(ctx)
end

local function handlePreGameZoneEnter(ctx)
	local zoneInfo=ctx.zoneInfo
	--Update Mage Level Boards before the game starts.
	if gStates.mageKnightLevels==true then
		if zoneInfo~=nil and (zoneInfo.kind=="play" or zoneInfo.kind=="unit" or zoneInfo.kind=="crystal") then mageLevelBoard() end
	end
end

local function handleManaZoneEnter(ctx)
	local zoneGUID=ctx.zoneGUID
	local objType=ctx.objType
	--Mirror dice in source and Start of rounds should have half or more standard color Mana Dice
	if zoneGUID==GUID.zone.mana and objType=="Dice" then
		if dieRollEnterPause~=nil then Wait.stop(dieRollEnterPause) end
		dieRollEnterPause=safeWaitCondition("Events",function()
			--Start of rounds should have half or more standard color Mana Dice
			local safe=true
			if gStates.tacticRemove==true or gStates.tacticShown==true or gStates.firstStarted~=true then
				local bad={}
				local manaZone=getObjectFromGUID(GUID.zone.mana)
				for _, manaDie in pairs(manaZone.getObjects()) do
					if manaDie.type=="Dice" and (manaDie.getRotationValue()=="Black Mana" or manaDie.getRotationValue()=="Gold Mana") then bad[#bad+1]=manaDie end
				end
				if #bad>gStates.diceNeeded/2 or (gStates.startAtNight==true and gStates.currentRound==1) then
					for _, badManaDie in pairs(bad) do badManaDie.randomize() end
					pulseSourceRandomizeFences()
					if #bad>0 then safe=false end
				end
			end
			--Mirror mana source dice
			if gStates.firstStarted==true and safe==true then
				mirrorSourceUpdate("dice entered zone")
			end
		end, function()
			local allResting=true
			local manaZone=getObjectFromGUID(GUID.zone.mana)
			for _, manaDie in pairs(manaZone.getObjects()) do
				if manaDie.type=="Dice" and manaDie.resting==false then allResting=false break end
			end
			return allResting
		end)
	end
end

function __onObjectEnterZone_raw(zone, obj)
	if zone~=nil and zone.guid==mapArea then
		if obj~=nil and terrainTiles[obj.guid]~=nil then runtimeMapInvalidateTerrain() else runtimeMapInvalidateObjects() end
	end
	local ctx=zoneEventContext(zone,obj)
	if ctx==nil then return end
	if handleZoneEnterPrelude(ctx)==true then return end
	if gStates.firstStarted==true then
		handleStartedZoneEnterPrelude(ctx)
		handleTurnOrderZoneEnter(ctx)
		if mapHandleTerrainZoneEnter(ctx)==true then return end
		handleMapLocationZoneEnter(ctx)
		handleMapVisualZoneEnter(ctx)
		handleHandZoneEnter(ctx)
		handleClaimZoneEnter(ctx)
		if handlePlayerBoardZoneEnter(ctx)==true then return end
	else
		handlePreGameZoneEnter(ctx)
	end
	handleManaZoneEnter(ctx)
end

--Undo a monastery & re-enable end turn button
dieRollExitPause=nil
local function handleZoneLeavePrelude(ctx)
	local zoneGUID=ctx.zoneGUID
	local objGUID=ctx.objGUID
	if apocalypseDragonGroundCombatToken~=nil then
		local active,headName,owner=apocalypseDragonGroundCombatToken(objGUID)
		if active==true and headName~="Control" and owner~=nil then safeWaitFrames("Events",function() apocalypseDragonRefreshGroundFameGain(owner) end,1) end
	end
	--Ignore unrelated zone exits caused solely by a scripted Deed transfer crossing the table.
	if deedTransferState~=nil and deedTransferState.transit[objGUID]~=nil and zoneGUID~=deedTransferState.transit[objGUID] then return true end
	return false
end


local function handleClaimZoneLeave(ctx)
	local zone=ctx.zone
	local obj=ctx.obj
	--Remove offer claim buttons
	if offerClaimSource(zone.guid,obj)~=nil then obj.UI.setXmlTable({{}}) end

	--Remove tactic claim buttons
	if tacticClaimingZones[zone.guid]~=nil then obj.UI.setXmlTable({{}}) end

	--Remove Skill claim buttons
	if zone.guid==GUID.zone.skillOffer and skillOfferEntrySerial[obj.guid]==nil and gStates.mageSkills[obj.guid]~=nil then
		for skillGUID, _ in pairs(gStates.mageSkills) do
			local skillObj=getObjectFromGUID(skillGUID)
			if skillObj~=nil then skillObj.UI.setXmlTable({{}}) end
		end
	end
end

local function handleMapZoneLeave(ctx)
	local zone=ctx.zone
	local obj=ctx.obj
	--remove decals from anything lifted from the map.
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
	end

	if zone.guid==mapArea and obj.guid~=volkare.model and obj.guid~=elementalist.terrainHex and obj.guid~=darkCrusader.terrainHex then
		obj.UI.setXmlTable({{}})
	end

	--Check if a shield has been removed
	if (zone.guid==mapArea)--or zone.guid==GUID.zone.blueCity or zone.guid==GUID.zone.redCity or zone.guid==GUID.zone.greenCity or zone.guid==GUID.zone.whiteCity or zone.guid==volkare.discZone or zone.guid==darkCrusader.discZone or zone.guid==elementalist.discZone)
		and (obj.getName()=="Shield" or obj.getGMNotes()=="Burned Monastery" or obj.getName()=="Secret Dungeon" or obj.getName()=="Secret Tomb") and obj.getLock()==false then
		scheduleShieldLocation(obj, zone, "remove")
	end

	--remove red tint when lifting out terrain tile.
	if zone.guid==mapArea and terrainTiles[obj.guid]~=nil then
		if startingMapSetup==true then
			if gStates.startAtNight==true then obj.setColorTint({r=0.6, g=0.6, b=0.6}) else obj.setColorTint({r=1.0, g=1.0, b=1.0}) end
		elseif gStates.dayRound==false then
			obj.setColorTint({r=0.6, g=0.6, b=0.6})
		else
			obj.setColorTint({r=1.0, g=1.0, b=1.0})
		end
	end
end

local function handleManaZoneLeave(ctx)
	local zone=ctx.zone
	local obj=ctx.obj
	--updata Mirrored source
	if zone.guid==GUID.zone.mana and obj.type=="Dice" then
		if dieRollEnterPause~=nil then Wait.stop(dieRollEnterPause) end
		dieRollEnterPause=safeWaitTime("Events",function()
			mirrorSourceUpdate("object left zone")
		end, 0.5)
	end
end

local function handlePreGameZoneLeave(ctx)
	local zoneInfo=ctx.zoneInfo
	--Update Mage Level Boards before the game starts.
	if gStates.mageKnightLevels==true and zoneInfo~=nil and (zoneInfo.kind=="play" or zoneInfo.kind=="unit" or zoneInfo.kind=="crystal") then
		mageLevelBoard()
	end
end

function __onObjectLeaveZone_raw(zone, obj)
	if zone~=nil and zone.guid==mapArea then
		if obj~=nil and terrainTiles[obj.guid]~=nil then runtimeMapInvalidateTerrain() else runtimeMapInvalidateObjects() end
	end
	local ctx=zoneEventContext(zone,obj)
	if ctx==nil then return end
	if handleZoneLeavePrelude(ctx)==true then return end
	if gStates.firstStarted==true then
		playerBoardZoneLeave(ctx)
		handleClaimZoneLeave(ctx)
		handleMapZoneLeave(ctx)
		handleManaZoneLeave(ctx)
	else
		handlePreGameZoneLeave(ctx)
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
local shuffleOnContainerEnter=nil
local function containerShufflesOnEntry(guid)
	if shuffleOnContainerEnter==nil then
		shuffleOnContainerEnter={
			[GUID.bag.skill.arythea]=true,[GUID.bag.skill.goldyx]=true,[GUID.bag.skill.norowas]=true,[GUID.bag.skill.tovak]=true,
			[GUID.bag.skill.krang]=true,[GUID.bag.skill.braevalar]=true,[GUID.bag.skill.ymirgh]=true,[GUID.bag.skill.wolfhawk]=true,
			[GUID.bag.skill.jormund]=true,["8c8a04"]=true,["46f93a"]=true,[GUID.bag.terrain.leftCity]=true,
			[GUID.bag.terrain.leftCore]=true,[GUID.bag.terrain.leftCountry]=true,[GUID.bag.allSkills]=true,["8929f0"]=true,
			["3e1fdf"]=true,[GUID.bag.skill.malek]=true,[GUID.bag.skill.zirtae]=true,[GUID.bag.skill.coral]=true
		}
	end
	return shuffleOnContainerEnter[guid]==true
end

function __onObjectEnterContainer_raw(bag, obj)
	if obj~=nil and runtimeMapContainsGUID(obj.guid)==true then
		if terrainTiles[obj.guid]~=nil then runtimeMapInvalidateTerrain() else runtimeMapInvalidateObjects() end
	end
	if obj~=nil and mapTokenNeedsArrangement~=nil and mapTokenNeedsArrangement(obj)==true then mapTokenReleaseObject(obj) end
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

	--Shuffle bags whose contents are randomized whenever an object returns.
	local found=gStates.firstStarted==true and containerShufflesOnEntry(bag.guid)
	if found==true then bag.shuffle() end

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

local soloDescription={
							["3fba07"]="{en}Once a round (Except during combat):\n\nThrow away up to two Wound cards from your hand. (Put this skill token in your Play Area to activated it)\n\nNext turn only:\n\nYou may play a Wound card sideways for +3.{ru}Один раз в раунд (не в битве):\n\nУдалите до двух карт раны с руки. (Положите навык в вашу игровую зону для активации эффекта)\n\nТолько в следующий ход:\n\nМожете сыграть карту раны боком, получив бонус +3.{zh-tw}每轮一次，非战斗中使用\n\n从手牌中去除最多两张创伤卡。将本技能标记放在桌子中央。\n\n仅下回合： 你可以横置打出一张创伤卡，效果+3{zh-cn}每轮一次，非战斗中使用\n\n从手牌中去除最多两张创伤卡。将本技能标记放在桌子中央。\n\n仅下回合： 你可以横置打出一张创伤卡，效果+3{ko}라운드에 한번, 전투에서 제외:\n\n손에 든 부상을 2개까지 제거한다. (스킬을 플레이 영역에 놓아 활성화)\n\n다음 차례에 한번,\n\n부상 하나를 다른 행동 카드처럼 가로로 시용해, +1 대신 +3을 받는다.{es}Una vez por Ronda (excepto durante el combate):\n\nTira hasta dos cartas de Herida de tu mano. (Pon esta ficha de habilidad en tu Área de juego para activarla)\n\nSólo en el próximo turno:\n\nPuedes jugar una carta de Herida de lado por +3.{fr}Une fois par Rounde (Sauf pendant le combat):\n\nJetez jusqu'à deux cartes Blessure de votre main. (Mettez ce jeton de compétence dans votre zone de jeu pour l'activer)\n\nTour suivant uniquement:\n\nVous pouvez jouer une carte Blessure latéralement pour +3.{pt-br}Uma vez por rodada (Exceto durante combate):\n\nJogue fora 2 cartas de ferimento da sua mão. (Coloque esta habilidade na sua área de jogo para ativá-la)\n\nPróximo turno turno apenas:\n\nVocê pode jogar uma carta de Ferimento de lado como +3.{de}Einmal pro Runde (außer im Kampf):\n\nWirf bis zu zwei Wundenkarten aus deiner Hand weg. (Lege dieses Fertigkeitsplättchen in deinen Spielbereich, um es zu aktivieren)\n\nNur im nächsten Zug:\n\nDu darfst eine Wundenkarte seitwärts für +3 ausspielen.",
							["4ac9f6"]="{en}Once a Round:\n\nReduce one attack of an enemy by 1. That enemy gains Cumbersome this turn. (Put this skill token in your Play Area to activated it)\n\nNext turn only:\n\nYou may reduce one attack of an enemy by 1. That enemy gains Cumbersome.{ru}Один раз в раунд:\n\nУменьшите значение одной Атаки врага на 1. Этот враг становится Неповоротливым до конца хода. (Положите навык в вашу игровую зону для активации эффекта)\n\nТолько в следующий ход:\n\nУменьшите значение одной Атаки врага на 1. Этот враг становится Неповоротливым до конца хода.{zh-tw}每轮一次：\n\n将敌人的一次攻击减少1。该敌人在本回合变得笨重（将此标记放在桌子中央以激活它）\n\n仅下一回合：\n\n您可以将敌人的一次攻击减少1。该敌人变得笨重。{zh-cn}每轮一次：\n\n将敌人的一次攻击减少1。该敌人在本回合变得笨重（将此标记放在桌子中央以激活它）\n\n仅下一回合：\n\n您可以将敌人的一次攻击减少1。该敌人变得笨重。{ko}라운드에 한번:\n\n적 공격 하나를 1 줄인다. 이번 차례에 그 적의 공격은 육중함을 얻는다.  (스킬을 플레이 영역에 놓아 활성화)\n\n다음 자기 차례에:\n\n적 공격 하나를 1 줄인다. 이번 차례에 그 적의 공격은 육중함을 얻는다.{es}Una vez por Ronda:\n\nReduce un ataque de un enemigo en 1. Ese enemigo gana Engorroso este turno. (Pon esta ficha de habilidad en tu área de juego para activarla)\n\nSolo en el próximo turno:\n\nPuedes reducir un ataque de un enemigo en 1. Ese enemigo se vuelve engorroso.{fr}Une fois par Rounde:\n\nRéduisez une attaque d'un ennemi de 1. Cet ennemi devient Encombrant ce tour-ci. (Mettez ce jeton de compétence dans votre zone de jeu pour l'activer)\n\nTour suivant uniquement:\n\nVous pouvez réduire une attaque d'un ennemi de 1. Cet ennemi devient Encombrant.{pt-br}Uma vez por Rodada:\n\nReduz um ataque de um inimigo em 1.Este inimigo ganha Corpulento este turno. (Coloque esta habilidade na sua área de jogo para ativá-la)\n\nPróximo Turno apenas:\n\nVocê pode reduzir um ataque de 1 inimigo em 1. Este inimigo ganha Corpulento.{de}Einmal pro Runde:\n\nReduziere einen Angriff eines Feindes um 1. Dieser Feind wird in diesem Zug schwerfällig. (Lege dieses Fertigkeitsplättchen in deinen Spielbereich, um es zu aktivieren)\n\nNur im nächsten Zug:\n\nDu kannst einen Angriff eines Gegners um 1 reduzieren. Dieser Gegner wird schwerfällig.",
							["3b3273"]="{en}Once a Round:\n\nYou may Reroll a mana die in the source. (Put this skill token in your Play Area to activated it)\n\nNext turn only:\n\nYou may use an extra die from the source. Also gain a crystal of the same color. You may decide whether to reroll that die or not at the end of your turn.{ru}Один раз в раунд:\n\nМожете перебросить кубик маны в источнике. (Положите навык в вашу игровую зону для активации эффекта)\n\nТолько в следующий ход:\n\nМожете использовать дополнительный кубик маны основного цвета и взять кристалл этого цвета. Вы решаете, перебрасывать взятый кубик или нет.{zh-tw}每回合一次:\n\n你可以重掷来源中的一个法力骰子. (将此技能令牌放入你的游戏区域以激活它).\n\n仅限下一回合:\n\n你可以使用一个额外的法力骰子, 同时获得一个相同颜色的水晶. 在你的回合结束时, 你可以决定是否重掷该骰子.{zh-cn}每回合一次:\n\n你可以重掷来源中的一个法力骰子. (将此技能令牌放入你的游戏区域以激活它).\n\n仅限下一回合:\n\n你可以使用一个额外的法力骰子, 同时获得一个相同颜色的水晶. 在你的回合结束时, 你可以决定是否重掷该骰子.{ko}1라운드에 한 번:\n\n당신은 소스의 마나 주사위를 다시 굴릴 수 있습니다. (이 스킬 토큰을 자신의 플레이 영역에 놓아 활성화합니다).\n\n다음 턴에만 가능합니다:\n\n당신은 소스에서 주사위 한 개를 추가로 사용할 수 있습니다. 또한 같은 색의 수정 하나를 얻습니다. 자신의 턴이 끝날 때 주사위를 다시 굴릴지 여부를 결정할 수 있습니다.{es}Una vez por Ronda:\n\nPuedes volver a lanzar un dado de maná en la fuente. (Pon esta ficha de habilidad en tu Área de Juego para activarla)\n\nSólo en el siguiente turno:\n\nPuedes usar un dado extra de la fuente. También ganas un cristal del mismo color. Puedes decidir si volver a lanzar ese dado o no al final de tu turno.{fr}Une fois par round :\n\nVous pouvez relancer un dé de mana dans la source. (Placez ce jeton de compétence dans votre zone de jeu pour l'activer).\n\nAu prochain tour seulement :\n\nVous pouvez utiliser un dé supplémentaire de la source. Vous gagnez également un cristal de la même couleur. Vous pouvez décider de relancer ou non ce dé à la fin de votre tour.{pt-br}Uma vez por rodada:\n\nVocê pode fazer o Reroll de um dado de mana na fonte. (Coloque esse token de habilidade em sua Área de Jogo para ativá-lo).\n\nSomente no próximo turno:\n\nVocê pode usar um dado extra da fonte. Também ganha um cristal da mesma cor. Você pode decidir se quer rolar novamente esse dado ou não no final do seu turno.{de}Einmal pro Runde:\n\nDu darfst einen Manawürfel in der Quelle neu würfeln. (Lege dieses Fertigkeitsplättchen in deinen Spielbereich, um es zu aktivieren)\n\nNur in der nächsten Runde:\n\nDu darfst einen zusätzlichen Würfel aus der Quelle verwenden. Außerdem erhältst du einen Kristall der gleichen Farbe. Am Ende deines Zuges darfst du entscheiden, ob du diesen Würfel neu würfelst oder nicht.",
							["725de9"]="{en}Once a Round:\n\nWhen you spend a mana of a basic color, gain a Crystal of that color. (Put this skill token in your Play Area to activated it, and place another crystal of the same color on it)\n\nNext turn only:\n\nYou may gain the mana token on this skill.{ru}Один раз в раунд:\n\nПотратив ману основного цвета, возьмите кристалл того же цвета. (Положите навык в вашу игровую зону для активации эффекта, и положите на него жетон маны того же цвета из резерва)\n\nТолько в следующий ход:\n\nМожете использовать ману, лежащую на этом навыке.{zh-tw}每轮一次：\n\n当你花费一个基本颜色的魔力时，获得一个该颜色的魔晶（将此技能标记放置在桌子中央以激活它，并在其上放置另一个相同颜色的水晶）\n\n仅下一回合：\n\n您可以获得此技能上的魔力标记。{zh-cn}每轮一次：\n\n当你花费一个基本颜色的魔力时，获得一个该颜色的魔晶（将此技能标记放置在桌子中央以激活它，并在其上放置另一个相同颜色的水晶）\n\n仅下一回合：\n\n您可以获得此技能上的魔力标记。{ko}라운드에 한번:\n\n기본 색상 마나 1개를 지불할 때,  이 스킬을 사용하여 해당 색상 수정 1개를 얻는다.(같은 색의 마나 토큰으로 스킬 위에 표시하고 플레이 영역에 놓아 활성화)\n\n다음 차례에:\n\n이 마나 토큰을 얻을 수 있다.{es}Una vez por Ronda:\n\nCuando gastas un maná de un color básico, obtienes un cristal de ese color. (Pon esta ficha de habilidad en tu Área de juego para activarla y coloca otro cristal del mismo color sobre ella)\n\nSolo en el próximo turno:\n\nPuedes obtener la ficha de maná en esta habilidad.{fr}Une fois par Rounde:\n\nLorsque vous dépensez un mana d'une couleur de base, gagnez un cristal de cette couleur. (Mettez ce jeton de compétence dans votre zone de jeu pour l'activer et placez-y un autre cristal de la même couleur)\n\nTour suivant uniquement:\n\nVous pouvez gagner le jeton mana de cette compétence.{pt-br}Uma vez por Rodada:\n\nQuando você gastar uma mana de cor básica, ganhe um cristal daquela cor. (coloque essa habilidade na sua área de jogo para ativá-la e coloque outro cristal da mesma cor nela)\n\nPróximo Turno apenas:\n\nVocê pode ganhar o marcador de mana desta habilidade.{de}Einmal pro Runde:\n\nWenn du ein Mana einer Grundfarbe ausgibst, erhältst du einen Kristall dieser Farbe (lege dieses Fertigkeitsplättchen in deinen Spielbereich, um es zu aktivieren, und lege einen weiteren Kristall derselben Farbe darauf).\n\nNur im nächsten Zug:\n\nDu darfst das Mana-Token für diese Fähigkeit erhalten.",
							["55e5e5"]="{en}Once a Round:\n\nReduce the Move cost of all terrains by 2 (to a minimum of 1). (Put this skill token in your Play Area to activated it)\n\nNext turn only:\n\nYou may reduce the move cost of all terrains by 1 (to a minimum of 1).{ru}Один раз в раунд:\n\nВаш герой двигается по любой местности, тратя на 2 очка Движения меньше (но не меньше 1) в этот ход. (Положите навык в вашу игровую зону для активации эффекта)\n\nТолько в следующий ход:\n\nВаш герой двигается по любой местности, тратя на 1 очко Движения меньше (но не меньше 1) в этот ход.{zh-tw}每轮一次: \n\n将本技能标记放在桌子中央以激活效果. \n将所有地形移动消耗减少2 (最少至1)\n\n仅下回合: \n将所有地形移动消耗减少1 (最低至1){zh-cn}每轮一次: \n\n将本技能标记放在桌子中央以激活效果. \n将所有地形移动消耗减少2 (最少至1)\n\n仅下回合: \n将所有地形移动消耗减少1 (最低至1){ko}라운드에 한번:\n\n이번 차례에 당신에게 모든 지형의 이동 비용은 2(최하 1) 감소한다.(스킬을 플레이 영역에 놓아 활성화)\n\n다음 차례에 한번만:\n\n이번 차례에 모든 지형의 이동 비용이 1 감소한다.{es}Una vez por Ronda:\n\nReduce el coste de movimiento de todos los terrenos en 2 (hasta un mínimo de 1). (Pon esta ficha de habilidad en tu Área de juego para activarla)\n\nSolo en el próximo turno:\n\nPuedes reducir el costo de movimiento de todos los terrenos en 1 (hasta un mínimo de 1).{fr}Une fois par Rounde:\n\nRéduisez le coût de déplacement de tous les terrains de 2 (jusqu'à un minimum de 1). (Mettez ce jeton de compétence dans votre zone de jeu pour l'activer)\n\nTour suivant uniquement :\n\nVous pouvez réduire le coût de déplacement de tous les terrains de 1 (jusqu'à un minimum de 1).{pt-br}Uma vez por Rodada:\n\nReduz o custo de movimento de todos os terrenos em 2 (a um mínimo de 1). (Coloque esta Habilidade na sua área de jogo para ativá-la).\n\nPróximo Turno apenas:\n\nVocê pode reduzir o custo de movimento de todos os terrenos em 1 (a um mínimo de 1).{de}Einmal pro Runde:\n\nVerringere die Bewegungskosten aller Terrains um 2 (auf ein Minimum von 1). (Lege dieses Fertigkeitsplättchen in deinen Spielbereich, um es zu aktivieren)\n\nNur in der nächsten Runde:\n\nDu darfst die Bewegungskosten aller Geländefelder um 1 reduzieren (auf ein Minimum von 1).",
							["818aea"]="{en}Once a Round:\n\nGain a mana token of any color except Gold. (Put this skill token in your Play Area to activated it, and place another crystal of the same color on it)\n\nNext turn only:\n\nIf you use a Mana of this same Color to power a Deed Card that gives Move, Influence, or any type of Attack or Block, it gets +4 from that card.{ru}Один раз в раунд:\n\nВозьмите жетон маны любого цвета, кроме золотого. (Положите навык в вашу игровую зону для активации эффекта, и положите на него жетон маны того же цвета из резерва)\n\nТолько в следующий ход:\n\nЕсли вы используете ману этого цвета для усиления карты с очками Движения, Влияния, любой Атаки или Блока, вы получаете +4 к значению этого эффекта.{zh-tw}每回合一次：\n\n获得一个任意颜色的法力令牌，金色除外。（将此技能令牌放入你的游戏区域以激活它，并在其上放置另一个相同颜色的水晶）。\n\n仅限下一回合：\n\n如果你使用一张同色的法力牌为一张可提供移动、影响或任何类型的攻击或格挡的契约牌提供能量，它将从该牌中获得 +4。{zh-cn}每回合一次：\n\n获得一个任意颜色的法力令牌，金色除外。（将此技能令牌放入你的游戏区域以激活它，并在其上放置另一个相同颜色的水晶）。\n\n仅限下一回合：\n\n如果你使用一张同色的法力牌为一张可提供移动、影响或任何类型的攻击或格挡的契约牌提供能量，它将从该牌中获得 +4。{ko}라운드에 한 번:\n\n금색이 아닌 색상 마나 토큰 1개를 선택해 받는다.(같은 색의 마나 토큰으로 스킬 위에 표시하고 플레이 영역에 놓아 활성화)\n\n다음 차례에 한번:\n\n이동, 영향력, 또는 아무 종류의 공격이나 방어를 제공하는 카드 하나를, 표시돤 색상과 동일한 색의 마나로 강화 사용한다면 해당 수치에 +4를 추가로 얻는다.{es}Una vez por ronda:\n\nGana una ficha de maná de cualquier color excepto oro. (Pon esta ficha de habilidad en tu Área de juego para activarla y coloca otro cristal del mismo color sobre ella)\n\nSolo en el próximo turno:\n\nSi usas un Mana de este mismo Color para potenciar una Carta de Escritura que otorga Movimiento, Influencia o cualquier tipo de Ataque o Bloqueo, obtiene +4 de esa carta.{fr}Une fois par Rounde:\n\nGagnez un jeton de mana de n'importe quelle couleur à l'exception de l'or. (Mettez ce jeton de compétence dans votre zone de jeu pour l'activer et placez-y un autre cristal de la même couleur)\n\nTour suivant uniquement:\n\nSi vous utilisez un mana de cette même couleur pour alimenter une carte d'action qui donne un mouvement, une influence ou tout type d'attaque ou de blocage, elle obtient +4 de cette carte.{pt-br}Uma vez por rodada:\n\nGanhe uma ficha de mana de qualquer cor, exceto ouro. (Coloque esta ficha de habilidade em sua área de jogo para ativá-la e coloque outro cristal da mesma cor sobre ela)\n\nPróxima curva apenas:\n\nSe você usar um Mana desta mesma Cor para energizar uma Carta de Ação que conceda Movimento, Influência ou qualquer tipo de Ataque ou Bloqueio, ela recebe +4 daquela carta.{de}Einmal pro Runde:\n\nErhalte ein Mana-Token einer beliebigen Farbe außer Gold. (Lege dieses Fertigkeitsplättchen in deinen Spielbereich, um es zu aktivieren, und lege einen weiteren Kristall derselben Farbe darauf)\n\nNur in der nächsten Zug:\n\nWenn du Mana dieser Farbe nutzt, um eine Handlungs­karte mit Bewegung, Einfluss, Angriff oder Block zu aktivieren, erhält +4 von dieser Karte.",
							["564392"]="{en}Once a Round (Except during Interactions): (Put this skill token in your Play Area to activated it)\n\nOne card played sideways is worth +4. For each command token without a Unit gain an extra +1.\n\nNext turn only:\n\nYou may reduce the Armour of an enemy by 1, and one attack of the same or another enemy by 1{ru}Один раз в раунд (не при взаимодействии): (Положите навык в вашу игровую зону для активации эффекта)\n\nОдна карта, сыгранная боком, дает бонус +4 вместо +1. Каждый свободной жетон командования увеличивает бонус еще на +1.\n\nТолько в следующий ход:\n\nВы можете уменьшить Броню одного врага на 1 и значение одной Атаки на 1 (этого или другого врага).{zh-tw}每轮一次，交涉中除外：\n\n一张横置打出的卡牌效果+4而非+1。你没有一个未分配给部队的指挥标记额外+1。将本技能放在桌子中间。\n仅下回合： 你的一个敌人护甲-1，同时同一个或另一个敌人的攻击-1{zh-cn}每轮一次，交涉中除外：\n\n一张横置打出的卡牌效果+4而非+1。你没有一个未分配给部队的指挥标记额外+1。将本技能放在桌子中间。\n仅下回合： 你的一个敌人护甲-1，同时同一个或另一个敌人的攻击-1{ko}라운드에 한번, 교류에서 제외:\n\n가로로 사용한 카드 1장은 +1 대신 +4를 준다. 이 수치는 유닛이 배정되지 않은 지휘 토큰 하나당 +1씩 증가한다. (스킬을 플레이 영역에 놓아 활성화)\n\n다음 차례에 한 번:\n\n선택한 적 하나의 방어구를 1 감소시키고, 같은 적이나 다른 적 공격 하나도 1 감소시킨다.{es}Una vez por Ronda (excepto durante las interacciones): (Pon esta ficha de habilidad en tu Área de juego para activarla)\n\nUna carta jugada de lado vale +4. Por cada ficha de Mando sin una Unidad, obtienes un +1 extra.\n\nSolo en el próximo turno:\n\nPuedes reducir la armadura de un enemigo en 1 y un ataque del mismo u otro enemigo en 1{fr}Une fois par Rounde (sauf pendant les interactions): (Mettez ce jeton de compétence dans votre zone de jeu pour l'activer)\n\nUne carte jouée de côté vaut +4. Pour chaque jeton de commandement sans Unité, gagnez un +1 supplémentaire.\n\nTour suivant uniquement:\n\nVous pouvez réduire l'armure d'un ennemi de 1 et une attaque du même ennemi ou d'un autre de 1{pt-br}Uma vez por Rodada (Exceto durante interações): (Coloque esta habilidade na sua área de jogo para ativá-la)\n\nUma carta jogada de lado vale +4. Para cada Ficha de Comando sem uma unidade ganhe +1 extra.\n\nNo Próximo Turno apenas:\n\nVocê pode reduzir a armadura de um inimigo em 1 e um ataque do mesmo inimigo em 1.{de}Einmal pro Runde (außer bei Interaktionen): (Lege dieses Fertigkeitsplättchen in deinen Spielbereich, um es zu aktivieren)\n\nEine seitwärts gespielte Karte ist +4 wert. Für jedes Befehlsplättchen ohne Einheit erhältst du zusätzlich +1.\n\nNur in der nächsten Zug:\n\nDu kannst die Rüstung eines Gegners um 1 und einen Angriff desselben oder eines anderen Gegners um 1 reduzieren.",
							["ebbbfc"]="{en}Once a Round:\n\nChoose one card from your discard pile and place it on top  of your deed deck.\n\nIf the dummy hasn't called end of round, place the top card from the Advanced Action Deck in his deck.{ru}Один раз за раунд:\n\nВыберите одну карту из своей стопки сброса и положите её на верх колоды действий.\n\nЕсли виртуальный игрок не объявил конец раунда, положите верхнюю карту колоды Продвинутых действий в его колоду.{zh-tw}每轮一次：\n\n你和其他所有玩家从弃牌堆中选择一张牌，将这张牌放到功能牌库顶。单人游戏时，再将高级行动牌堆顶部的1张牌放到虚拟玩家的功能牌库顶，即使虚拟玩家的 功能牌库没有牌也可以这样做。\n如果虚拟玩家已经声明本轮结束，则忽略此效果。{zh-cn}每轮一次：\n\n你和其他所有玩家从弃牌堆中选择一张牌，将这张牌放到功能牌库顶。单人游戏时，再将高级行动牌堆顶部的1张牌放到虚拟玩家的功能牌库顶，即使虚拟玩家的 功能牌库没有牌也可以这样做。\n如果虚拟玩家已经声明本轮结束，则忽略此效果。{ko}라운드에 한번:\n\n이 토큰을 뒤집어 버린 더미에서 카드 한장을 선택해 더미 위에 올려둔다.\n\n가상 플레이어가 라운드 종료를 선언Cards하지 않았다면, 가장 아래 위치한 상급 액션을 그의 더미에 추가한다.{es}Una vez por Ronda:\n\nElige una carta de tu pila de descarte y colócala encima de tu mazo de escrituras.\n\nSi el muerto no ha dicho fin de ronda, coloca la carta superior del Mazo de Acción Avanzada en su mazo.{fr}Une fois par Rounde:\n\nChoisissez une carte de votre défausse et placez-la au-dessus de votre deck d'actes.\n\nSi le mannequin n'a pas appelé à la fin du tour, placez la première carte du paquet d'action avancée dans son paquet.{pt-br}Uma vez por Rodada:\n\nEscolha uma carta de sua pilha de descarte e coloque-a no topo de seu baralho de ações.\n\nSe o morto não tiver chamado o final da rodada, coloque a carta do topo do Baralho de Ação Avançada em seu baralho.{de}Einmal pro Runde:\n\nWähle eine Karte aus deinem Ablagestapel und lege sie oben auf dein Aktionsdeck.\n\nFalls der Dummy das Rundenende noch nicht ausgerufen hat, lege die oberste Karte des Decks der Fortgeschrittenen Aktionen in sein Deck.",
							["a598f6"]="{en}Once a round (Except during combat):\\n\\nGain a Potion. (Put this skill token in your Play Area to activate it).\\n\\nNext turn only:\\n\\nYou may add +3 to any Move, Influence, or any type of Attack or Block provided by your next card or Unit ability that requires no mana.{ru}Один раз за раунд (кроме боя):\\n\\nПолучите Зелье. (Положите этот жетон навыка в свою игровую зону, чтобы активировать его.)\\n\\nТолько в следующий ход:\\n\\nВы можете добавить +3 к Движению, Влиянию или любому типу Атаки или Блока от следующей карты или способности Отряда, не требующей маны.{zh-tw}每輪一次（戰鬥期間除外）：\\n\\n獲得一瓶藥劑。（將此技能標記放入你的遊戲區以啟動它。）\\n\\n僅限下一回合：\\n\\n你的下一張牌或不需要魔力的部隊能力所提供的移動、影響力或任何類型的攻擊／格擋可獲得 +3。{zh-cn}每轮一次（战斗期间除外）：\\n\\n获得一瓶药剂。（将此技能标记放入你的游戏区以启动它。）\\n\\n仅限下一回合：\\n\\n你的下一张牌或不需要魔力的部队能力所提供的移动、影响力或任何类型的攻击／格挡可获得 +3。{ko}라운드당 한 번(전투 중 제외):\\n\\n물약 1개를 얻습니다. (이 스킬 토큰을 자신의 플레이 영역에 놓아 활성화합니다.)\\n\\n다음 턴에만:\\n\\n마나가 필요하지 않은 다음 카드 또는 유닛 능력이 제공하는 이동, 영향력, 모든 종류의 공격 또는 방어 중 하나에 +3을 더할 수 있습니다.{es}Una vez por ronda (excepto durante el combate):\\n\\nGana una Poción. (Pon esta ficha de habilidad en tu Área de Juego para activarla).\\n\\nSolo durante tu próximo turno:\\n\\nPuedes añadir +3 a cualquier Movimiento, Influencia o tipo de Ataque o Bloque proporcionado por tu próxima carta o habilidad de Unidad que no requiera maná.{fr}Une fois par manche (sauf pendant un combat) :\\n\\nGagnez une Potion. (Placez ce jeton de compétence dans votre Zone de Jeu pour l’activer.)\\n\\nAu prochain tour uniquement :\\n\\nVous pouvez ajouter +3 à un Mouvement, une Influence ou tout type d’Attaque ou de Bloc fourni par votre prochaine carte ou capacité d’Unité ne nécessitant aucun mana.{pt-br}Uma vez por rodada (exceto durante combate):\\n\\nGanhe uma Poção. (Coloque esta ficha de habilidade na sua Área de Jogo para ativá-la.)\\n\\nApenas no próximo turno:\\n\\nVocê pode adicionar +3 a qualquer Movimento, Influência ou tipo de Ataque ou Bloqueio fornecido pela sua próxima carta ou habilidade de Unidade que não exija mana.{de}Einmal pro Runde (außer während eines Kampfes):\\n\\nErhalte einen Trank. (Lege diesen Fähigkeitsmarker in deinen Spielbereich, um ihn zu aktivieren.)\\n\\nNur im nächsten Zug:\\n\\nDu darfst +3 zu Bewegung, Einfluss oder einer beliebigen Angriffs- oder Blockart deiner nächsten Karte oder Einheitenfähigkeit addieren, sofern dafür kein Mana benötigt wird.",
							["3d8336"]="{en}Once a Round:\n\nFlip this to draw two cards, and gain a Red mana token.\n\nYou cannot use another Motivation Skill until the end of your next turn.{ru}Один раз в раунд:\n\nПереверните навык и возьмите 2 карты и жетон красной маны.\n\nНельзя использовать другие навыки Мотивации до конца вашего следующего хода.{zh-tw}每轮一次：\n\n使用此技能抽两张牌，并获得一个红色魔力标记。\n\n在下一回合结束之前，您不能使用其他激励技能。{zh-cn}每轮一次：\n\n使用此技能抽两张牌，并获得一个红色魔力标记。\n\n在下一回合结束之前，您不能使用其他激励技能。{ko}라운드에 한번:\n\n이 토큰을 뒤집어 카드 2장을 뽑는다. 그리고 적색 마나 토큰을 얻는다.\n\n다음 차례를 마칠 때 까지 다른 동기 부여를 사용할 수 없다.{es}Una vez por Ronda:\n\nDale la vuelta para robar dos cartas y ganar una ficha de maná roja.\n\nNo puedes usar otra habilidad de motivación hasta el final de tu próximo turno.{fr}Une fois par Rounde :\n\nRetournez-le pour piocher deux cartes et gagner un jeton de mana rouge.\n\nVous ne pouvez pas utiliser une autre compétence de motivation jusqu'à la fin de votre prochain tour.{pt-br}Uma vez por Rodada:\n\nVire esta para comprar duas cartas e ganhar um marcador de mana Vermelha.\n\nVocê não pode usar habilidades Motivacionais até o fim do seu próximo turno.{de}Einmal pro Runde:\n\nDrehe dies um, um zwei Karten zu ziehen und einen roten Mana-Token zu erhalten.\n\nDu kannst bis zum Ende deines nächsten Zuges keine weitere Motivationsfähigkeit nutzen.",
							["171244"]="{en}Once a Round:\n\nFlip this to draw two cards, and gain a Green mana token.\n\nYou cannot use another Motivation Skill until the end of your next turn.{ru}Один раз в раунд:\n\nПереверните навык и возьмите 2 карты и жетон зеленой маны.\n\nНельзя использовать другие навыки Мотивации до конца вашего следующего хода.{zh-tw}每轮一次：\n\n使用此技能抽两张牌，并获得一个绿色魔力标记。\n\n在下一回合结束之前，您不能使用其他激励技能。{zh-cn}每轮一次：\n\n使用此技能抽两张牌，并获得一个绿色魔力标记。\n\n在下一回合结束之前，您不能使用其他激励技能。{ko}라운드에 한번:\n\n이 토큰을 뒤집어 카드 2장을 뽑는다. 그리고 녹색 마나 토큰을 얻는다.\n\n다음 차례를 마칠 때 까지 다른 동기 부여를 사용할 수 없다.{es}Una vez por Ronda:\n\nDale la vuelta para robar dos cartas y ganar una ficha de maná verde.\n\nNo puedes usar otra habilidad de motivación hasta el final de tu próximo turno.{fr}Une fois par Rounde:\n\nRetournez-le pour piocher deux cartes et gagner un jeton de mana vert.\n\nVous ne pouvez pas utiliser une autre compétence de motivation jusqu'à la fin de votre prochain tour.{pt-br}Uma vez por Rodada:\n\nVire esta para comprar duas cartas e ganhar um marcador de mana Verde.\n\nVocê não pode usar habilidades Motivacionais até o fim do seu próximo turno.{de}Einmal pro Runde:\n\nDrehe dies um, um zwei Karten zu ziehen und einen grünen Mana-Token zu erhalten.\n\nDu kannst bis zum Ende deines nächsten Zuges keine weitere Motivationsfähigkeit nutzen.",
							["14399f"]="{en}Once a Round:\n\nFlip this to draw two cards, and gain a White mana token.\n\nYou cannot use another Motivation Skill until the end of your next turn.{ru}Один раз в раунд:\n\nПереверните навык и возьмите 2 карты и жетон белой маны.\n\nНельзя использовать другие навыки Мотивации до конца вашего следующего хода.{zh-tw}每轮一次：\n\n将本标记翻面以抽取两张卡牌。获得一个白色魔力标记。你的下回合结束前无法使用其他激励技能{zh-cn}每轮一次：\n\n将本标记翻面以抽取两张卡牌。获得一个白色魔力标记。你的下回合结束前无法使用其他激励技能{ko}라운드에 한번:\n\n이 토큰을 뒤집어 카드 2장을 뽑는다. 그리고 백색 마나 토큰을 얻는다.\n\n다음 차례를 마칠 때 까지 다른 동기 부여를 사용할 수 없다.{es}Una vez por Ronda:\n\nDale la vuelta para robar dos cartas y ganar una ficha de maná blanca.\n\nNo puedes usar otra habilidad de motivación hasta el final de tu próximo turno.{fr}Une fois par Rounde:\n\nRetournez-le pour piocher deux cartes et gagner un jeton de mana blanc.\n\nVous ne pouvez pas utiliser une autre compétence de motivation jusqu'à la fin de votre prochain tour.{pt-br}Uma vez por Rodada:\n\nVire esta para comprar duas cartas e ganhar um marcador de mana Branca.\n\nVocê não pode usar habilidades Motivacionais até o fim do seu próximo turno.{de}Einmal pro Runde:\n\nDrehe dies um, um zwei Karten zu ziehen und ein weißes Mana-Token zu erhalten.\n\nDu kannst bis zum Ende deines nächsten Zuges keine weitere Motivationsfähigkeit nutzen.",
							["527b47"]="{en}Once a Round:\n\nFlip this to draw two cards, and gain Fame 1.\n\nYou cannot use another Motivation Skill until the end of your next turn.{ru}Один раз в раунд:\n\nПереверните навык и возьмите 2 карты и 1 очко Славы.\n\nНельзя использовать другие навыки Мотивации до конца вашего следующего хода.{zh-tw}每轮一次：\n\n使用此技能抽两张牌，并获得声望1。\n\n在下一回合结束之前，您不能使用其他激励技能。{zh-cn}每轮一次：\n\n使用此技能抽两张牌，并获得声望1。\n\n在下一回合结束之前，您不能使用其他激励技能。{ko}라운드에 한번:\n\n이 토큰을 뒤집어 카드 2장을 뽑는다. 그리고 명성 1을 얻는다.\n\n다음 차례를 마칠 때 까지 다른 동기 부여를 사용할 수 없다.{es}Una vez por Ronda:\n\nDale la vuelta para robar dos cartas y ganar Fama 1.\n\nNo puedes usar otra habilidad de motivación hasta el final de tu próximo turno.{fr}Une fois par Rounde:\n\nRetournez-le pour piocher deux cartes et gagner de la renommée 1.\n\nVous ne pouvez pas utiliser une autre compétence de motivation jusqu'à la fin de votre prochain tour.{pt-br}Uma vez por Rodada:\n\nVire esta para comprar duas cartas e ganhar 1 de fama.\n\nVocê não pode usar habilidades Motivacionais até o fim do seu próximo turno.{de}Einmal pro Runde:\n\nDrehe dies um, um zwei Karten zu ziehen und 1 Ruhm zu erhalten.\n\nDu kannst bis zum Ende deines nächsten Zuges keine weitere Motivationsfähigkeit nutzen.",
							["ba4df5"]="{en}Once a Round:\n\nFlip this to draw two cards, and gain a Blue mana token.\n\nYou cannot use another Motivation Skill until the end of your next turn.{ru}Один раз в раунд:\n\nПереверните навык и возьмите 2 карты и жетон синей маны.\n\nНельзя использовать другие навыки Мотивации до конца вашего следующего хода.{zh-tw}每轮一次：\n\n使用此技能抽两张牌，并获得蓝色魔力标记。\n下回合结束前，你不能使用其他激励技能。{zh-cn}每轮一次：\n\n使用此技能抽两张牌，并获得蓝色魔力标记。\n下回合结束前，你不能使用其他激励技能。{ko}라운드에 한번:\n\n이 토큰을 뒤집어 카드 2장을 뽑는다. 그리고 청색 마나 토큰을 얻는다.\n\n다음 차례를 마칠 때 까지 다른 동기 부여를 사용할 수 없다.{es}Una vez por Ronda:\n\nDale la vuelta para robar dos cartas y ganar una ficha de maná azul.\n\nNo puedes usar otra habilidad de motivación hasta el final de tu próximo turno.{fr}Une fois par Rounde:\n\nRetournez-le pour piocher deux cartes et gagner un jeton de mana bleu.\n\nVous ne pouvez pas utiliser une autre compétence de motivation jusqu'à la fin de votre prochain tour.{pt-br}Uma vez por Rodada:\n\nVire esta para comprar duas cartas e ganhar um marcador de mana Azul.\n\nVocê não pode usar habilidades Motivacionais até o fim do seu próximo turno.{de}Einmal pro Runde:\n\nDrehe dies um, um zwei Karten zu ziehen und ein blaues Mana-Token zu erhalten.\n\nDu kannst bis zum Ende deines nächsten Zuges keine weitere Motivationsfähigkeit nutzen.",
							["48fd35"]="{en}Once a turn:\n\nPay a mana of any color and throw away a Wound from your hand. Also draw a card.{ru}Один раз в ход:\n\nПотратьте ману любого цвета и удалите карту раны с руки. Возьмите одну карту.{zh-tw}每回合一次：\n\n支付一点任意颜色的魔力，从手牌中去除一张创伤卡，抽一张卡牌。{zh-cn}每回合一次：\n\n支付一点任意颜色的魔力，从手牌中去除一张创伤卡，抽一张卡牌。{ko}차례에 한번:\n\n아무 색상 마나를 지불하고 손에 든 부상 하나를 제거한다. 추가로 카드 1장을 뽑는다.{es}Una vez por Turno:\n\nPaga un maná de cualquier color y tira una herida de tu mano. También roba una carta.{fr}Une fois par Tour:\n\nPayez un mana de n'importe quelle couleur et jetez une Blessure de votre main. Piochez également une carte.{pt-br}Uma vez por Turno:\n\nPague uma mana de qualquer cor e jogue fora um Ferimento da sua mão. Também compre uma carta.{de}Einmal pro Zug:\n\nBezahle ein Mana beliebiger Farbe und wirf eine Wundenkarte aus deiner Hand ab. Ziehe außerdem eine Karte.",
							["b13d5f"]="{en}Change up to 4 Black Mana Tokens or Dice into unique Basic Mana colours, even during the day. Place this skill in the Source until Mevok’s next turn. This allows a friendly Knight to reroll Black (day) or Gold (night) mana in the Source. If any Black (day) or Gold (night) mana remains after rolling, return this skill face down to Mevok.{ru}Измените до 4 жетонов или кубиков чёрной маны на разные основные цвета маны, даже днём. Поместите этот навык в Источник до следующего хода Мевока. Дружественный Рыцарь-маг может перебросить чёрную ману днём или золотую ночью в Источнике. Если после броска остаётся чёрная мана днём или золотая ночью, верните этот навык Мевоку лицом вниз.{zh-tw}將最多 4 個黑色魔力標記或骰子改為彼此不同的基本魔力顏色，即使在白天也可以。將此技能放入魔力源，直到梅沃克的下一回合。友方魔法騎士可重擲魔力源中的黑色（白天）或金色（夜晚）魔力。若重擲後仍有黑色（白天）或金色（夜晚）魔力，將此技能面朝下歸還梅沃克。{zh-cn}将最多 4 个黑色魔力标记或骰子改为彼此不同的基本魔力颜色，即使在白天也可以。将此技能放入魔力源，直到梅沃克的下一回合。友方魔法骑士可重掷魔力源中的黑色（白天）或金色（夜晚）魔力。若重掷后仍有黑色（白天）或金色（夜晚）魔力，将此技能面朝下归还梅沃克。{ko}검은색 마나 토큰이나 주사위를 최대 4개까지 서로 다른 기본 마나 색으로 바꿉니다. 낮에도 사용할 수 있습니다. 이 스킬을 메복의 다음 차례까지 마나 원천에 놓습니다. 아군 마법기사는 원천의 검은색(낮) 또는 금색(밤) 마나를 다시 굴릴 수 있습니다. 굴린 뒤에도 검은색(낮) 또는 금색(밤) 마나가 남아 있다면 이 스킬을 뒷면으로 메복에게 돌려놓습니다.{es}Cambia hasta 4 fichas o dados de Maná Negro a colores básicos de Maná distintos, incluso durante el día. Coloca esta habilidad en la Fuente hasta el próximo turno de Mevok. Esto permite a un Caballero aliado volver a tirar Maná Negro (día) o Dorado (noche) de la Fuente. Si queda Maná Negro (día) o Dorado (noche) después de tirar, devuelve esta habilidad boca abajo a Mevok.{fr}Transformez jusqu’à 4 jetons ou dés de Mana Noir en couleurs de Mana de base différentes, même pendant le jour. Placez cette compétence dans la Source jusqu’au prochain tour de Mevok. Un Chevalier allié peut relancer le Mana Noir (jour) ou Or (nuit) de la Source. S’il reste du Mana Noir (jour) ou Or (nuit) après le lancer, rendez cette compétence face cachée à Mevok.{pt-br}Mude até 4 fichas ou dados de Mana Preto para cores básicas de Mana diferentes, mesmo durante o dia. Coloque esta habilidade na Fonte até o próximo turno de Mevok. Um Cavaleiro aliado pode rolar novamente Mana Preto (dia) ou Dourado (noite) da Fonte. Se restar Mana Preto (dia) ou Dourado (noite) após a rolagem, devolva esta habilidade virada para baixo a Mevok.{de}Ändere bis zu 4 schwarze Mana-Marker oder -Würfel in unterschiedliche Grundmanafarben, sogar am Tag. Lege diese Fertigkeit bis zu Mevoks nächstem Zug in die Quelle. Ein verbündeter Ritter darf schwarzes Mana (Tag) oder goldenes Mana (Nacht) in der Quelle neu würfeln. Bleibt danach schwarzes Mana (Tag) oder goldenes Mana (Nacht) übrig, gib diese Fertigkeit verdeckt an Mevok zurück.",
							["68f864"]="{en}Once a Round:\\n\\nFlip this token to ignore all Attack effects of one enemy token (Put this skill token in your Play Area to activate it).\\n\\nNext turn only:\\n\\nYou may use this skill to ignore one Attack effect of one enemy token.{ru}Один раз за раунд:\\n\\nПереверните этот жетон, чтобы игнорировать все эффекты Атаки одного жетона врага. (Положите этот жетон навыка в свою игровую зону, чтобы активировать его.)\\n\\nТолько в следующий ход:\\n\\nВы можете использовать этот навык, чтобы игнорировать один эффект Атаки одного жетона врага.{zh-tw}每輪一次：\\n\\n翻轉此標記以忽略一個敵人標記的所有攻擊效果。（將此技能標記放入你的遊戲區以啟動它。）\\n\\n僅限下一回合：\\n\\n你可以使用此技能忽略一個敵人標記的一項攻擊效果。{zh-cn}每轮一次：\\n\\n翻转此标记以忽略一个敌人标记的所有攻击效果。（将此技能标记放入你的游戏区以启动它。）\\n\\n仅限下一回合：\\n\\n你可以使用此技能忽略一个敌人标记的一项攻击效果。{ko}라운드당 한 번:\\n\\n이 토큰을 뒤집어 적 토큰 하나의 모든 공격 효과를 무시합니다. (이 스킬 토큰을 자신의 플레이 영역에 놓아 활성화합니다.)\\n\\n다음 턴에만:\\n\\n이 스킬을 사용해 적 토큰 하나의 공격 효과 하나를 무시할 수 있습니다.{es}Una vez por ronda:\\n\\nVoltea esta ficha para ignorar todos los efectos de Ataque de una ficha enemiga. (Pon esta ficha de habilidad en tu Área de Juego para activarla.)\\n\\nSolo durante tu próximo turno:\\n\\nPuedes usar esta habilidad para ignorar un efecto de Ataque de una ficha enemiga.{fr}Une fois par manche :\\n\\nRetournez ce jeton pour ignorer tous les effets d’Attaque d’un jeton ennemi. (Placez ce jeton de compétence dans votre Zone de Jeu pour l’activer.)\\n\\nAu prochain tour uniquement :\\n\\nVous pouvez utiliser cette compétence pour ignorer un effet d’Attaque d’un jeton ennemi.{pt-br}Uma vez por rodada:\\n\\nVire esta ficha para ignorar todos os efeitos de Ataque de uma ficha inimiga. (Coloque esta ficha de habilidade na sua Área de Jogo para ativá-la.)\\n\\nApenas no próximo turno:\\n\\nVocê pode usar esta habilidade para ignorar um efeito de Ataque de uma ficha inimiga.{de}Einmal pro Runde:\\n\\nDrehe diesen Marker um, um alle Angriffseffekte eines gegnerischen Markers zu ignorieren. (Lege diesen Fähigkeitsmarker in deinen Spielbereich, um ihn zu aktivieren.)\\n\\nNur im nächsten Zug:\\n\\nDu darfst mit dieser Fähigkeit einen Angriffseffekt eines gegnerischen Markers ignorieren.",
							["784a07"]="{en}Once a round:\n\nFlip this Token to draw a card.\n\nYou may also discard a card and draw a card.\n\nNext turn only:\n\nYou may use this skill to draw a card.{ru}Один раз за раунд:\n\nПереверните этот жетон, чтобы взять карту.\n\nВы также можете сбросить карту и взять карту.\n\nТолько в следующем ходу:\n\nВы можете использовать этот навык, чтобы взять карту.{zh-tw}每輪一次：\n\n將此技能翻面來抽一張卡牌。\n\n你可以再棄一張牌來抽一張卡牌。\n\n僅下回合：\n\n你可以使用此技能來抽一張卡牌。{zh-cn}每轮一次：\n\n将此技能翻面来抽一张卡牌。\n\n你可以再弃一张牌来抽一张卡牌。\n\n仅下回合：\n\n你可以使用此技能来抽一张卡牌。{ko}매 턴마다 한 번:\n\n이 토큰을 뒤집어 카드를 한 장 뽑을 수 있습니다.\n\n카드를 버리고 한 장 뽑을 수도 있습니다.\n\n다음 턴에만:\n\n이 능력을 사용하여 카드를 한 장 뽑을 수 있습니다.{es}Una vez por ronda:\n\nVoltea esta ficha para robar una carta.\n\nTambién puedes descartar una carta y robar una carta.\n\nSolo en el siguiente turno:\n\nPuedes usar esta habilidad para robar una carta.{fr}Une fois par tour :\n\nRetournez ce jeton pour piocher une carte.\n\nVous pouvez également défausser une carte et en piocher une.\n\nAu prochain tour uniquement :\n\nVous pouvez utiliser cette capacité pour piocher une carte.{pt-br}Uma vez por rodada:\n\nVire este marcador para comprar uma carta.\n\nVocê também pode descartar uma carta e comprar uma carta.\n\nSomente no próximo turno:\n\nVocê pode usar esta habilidade para comprar uma carta.{de}Einmal pro Runde:\n\nDrehe diesen Spielstein um, um eine Karte zu ziehen.\n\nDu kannst auch eine Karte ablegen und eine Karte ziehen.\n\nNur im nächsten Zug:\n\nDu kannst diese Fähigkeit nutzen, um eine Karte zu ziehen.",
							["b66704"]="{en}Once a Round:\\n\\nYou may play a Wound as a sideways card for +3.\\n\\nIf your reputation is negative, add half your reputation score rounded up (x=7).\\n\\nNext turn only:\\n\\nGain +1 on the Reputation Track.{ru}Один раз за раунд:\\n\\nВы можете сыграть Рану боком как карту со значением +3.\\n\\nЕсли ваша репутация отрицательная, добавьте половину значения репутации, округляя вверх (x=7).\\n\\nТолько в следующий ход:\\n\\nПолучите +1 на шкале Репутации.{zh-tw}每輪一次：\\n\\n你可以將一張創傷牌橫置打出，視為 +3。\\n\\n若你的聲望為負數，加入你聲望值的一半並向上取整（x=7）。\\n\\n僅限下一回合：\\n\\n聲望軌提升 +1。{zh-cn}每轮一次：\\n\\n你可以将一张创伤牌横置打出，视为 +3。\\n\\n若你的声望为负数，加入你声望值的一半并向上取整（x=7）。\\n\\n仅限下一回合：\\n\\n声望轨提升 +1。{ko}라운드당 한 번:\\n\\n부상 카드 한 장을 옆으로 내어 +3으로 사용할 수 있습니다.\\n\\n평판이 음수라면 평판 수치의 절반을 올림하여 더합니다(x=7).\\n\\n다음 턴에만:\\n\\n평판 트랙에서 +1을 얻습니다.{es}Una vez por ronda:\\n\\nPuedes jugar una Herida de lado como una carta de +3.\\n\\nSi tu reputación es negativa, añade la mitad de tu puntuación de reputación redondeando hacia arriba (x=7).\\n\\nSolo durante tu próximo turno:\\n\\nGana +1 en la Pista de Reputación.{fr}Une fois par manche :\\n\\nVous pouvez jouer une Blessure de côté comme une carte valant +3.\\n\\nSi votre réputation est négative, ajoutez la moitié de votre valeur de réputation, arrondie au supérieur (x=7).\\n\\nAu prochain tour uniquement :\\n\\nGagnez +1 sur la Piste de Réputation.{pt-br}Uma vez por rodada:\\n\\nVocê pode jogar um Ferimento de lado como uma carta de +3.\\n\\nSe sua reputação for negativa, adicione metade do valor de reputação, arredondado para cima (x=7).\\n\\nApenas no próximo turno:\\n\\nGanhe +1 na Trilha de Reputação.{de}Einmal pro Runde:\\n\\nDu darfst eine Wunde seitlich als Karte mit +3 spielen.\\n\\nIst dein Ruf negativ, addiere die Hälfte deines Rufwerts, aufgerundet (x=7).\\n\\nNur im nächsten Zug:\\n\\nErhalte +1 auf der Rufleiste.",
							["9d866a"]="{en}Double your Armour when assigning damage. Gain 1 extra Wound per damage source to your hand and 2 to the discard pile. Knock Out requires 1 extra Wound. After combat, throw out Wounds equal to defeated enemies. Place this skill into the Source. A friendly Knight gains 1 Block or Block equal to your unsigned Reputation. Return face down at the start of next turn.{ru}Удвойте свою Броню при распределении урона. За каждый источник урона получите дополнительно 1 Рану в руку и 2 в сброс. Для нокаута требуется на 1 Рану больше. После боя удалите столько Ран, сколько врагов было побеждено. Поместите этот навык в Источник. Дружественный Рыцарь-маг получает 1 Блок или Блок, равный абсолютному значению вашей Репутации. В начале следующего хода верните навык лицом вниз.{zh-tw}分配傷害時，你的護甲加倍。每個傷害來源額外獲得 1 張創傷到手牌、2 張創傷到棄牌堆。被擊倒需要多 1 張創傷。戰鬥後，移除等同於被擊敗敵人數量的創傷。將此技能放入魔力源。友方魔法騎士獲得 1 點格擋，或等同於你聲望絕對值的格擋。下一回合開始時將此技能面朝下歸還。{zh-cn}分配伤害时，你的护甲加倍。每个伤害来源额外获得 1 张创伤到手牌、2 张创伤到弃牌堆。被击倒需要多 1 张创伤。战斗后，移除等同于被击败敌人数量的创伤。将此技能放入魔力源。友方魔法骑士获得 1 点格挡，或等同于你声望绝对值的格挡。下一回合开始时将此技能面朝下归还。{ko}피해를 배정할 때 방어력을 두 배로 계산합니다. 피해 원천마다 손에 부상 1장을 추가로 받고 버린 카드 더미에 2장을 받습니다. 쓰러지려면 부상 1장이 더 필요합니다. 전투 후 처치한 적 수만큼 부상을 제거합니다. 이 스킬을 마나 원천에 놓습니다. 아군 마법기사는 방어 1 또는 당신의 평판 절댓값만큼 방어를 얻습니다. 다음 차례 시작에 뒷면으로 되돌립니다.{es}Duplica tu Armadura al asignar daño. Recibe 1 Herida adicional en tu mano y 2 en el descarte por cada fuente de daño. Quedar Inconsciente requiere 1 Herida adicional. Después del combate, elimina tantas Heridas como enemigos derrotados. Coloca esta habilidad en la Fuente. Un Caballero aliado obtiene 1 Bloqueo o Bloqueo igual al valor absoluto de tu Reputación. Devuélvela boca abajo al comienzo del siguiente turno.{fr}Doublez votre Armure lors de l’attribution des dégâts. Pour chaque source de dégâts, gagnez 1 Blessure supplémentaire en main et 2 dans la défausse. Être Assommé nécessite 1 Blessure supplémentaire. Après le combat, retirez autant de Blessures que d’ennemis vaincus. Placez cette compétence dans la Source. Un Chevalier allié gagne 1 Blocage ou un Blocage égal à la valeur absolue de votre Réputation. Remettez-la face cachée au début du prochain tour.{pt-br}Dobre sua Armadura ao atribuir dano. Para cada fonte de dano, receba 1 Ferimento extra na mão e 2 na pilha de descarte. Ser Nocauteado exige 1 Ferimento extra. Após o combate, remova Ferimentos em quantidade igual aos inimigos derrotados. Coloque esta habilidade na Fonte. Um Cavaleiro aliado ganha 1 Bloqueio ou Bloqueio igual ao valor absoluto da sua Reputação. Devolva-a virada para baixo no início do próximo turno.{de}Verdopple deine Rüstung beim Zuweisen von Schaden. Erhalte pro Schadensquelle 1 zusätzliche Wunde auf die Hand und 2 in den Ablagestapel. Für das K.-o.-Gehen ist 1 zusätzliche Wunde nötig. Entferne nach dem Kampf so viele Wunden, wie Gegner besiegt wurden. Lege diese Fertigkeit in die Quelle. Ein verbündeter Ritter erhält 1 Block oder Block in Höhe des Absolutwerts deines Rufs. Lege sie zu Beginn des nächsten Zuges verdeckt zurück.",
							["adf8ab"]="{en}Once a turn:\n\nPay a mana of any color and throw away a Wound from your hand. Also draw a card.{ru}Один раз в ход:\n\nПотратьте ману любого цвета и удалите карту раны с руки. Возьмите одну карту.{zh-tw}每回合一次：\n\n支付一点任意颜色的魔力，从手牌中去除一张创伤卡，抽一张卡牌。{zh-cn}每回合一次：\n\n支付一点任意颜色的魔力，从手牌中去除一张创伤卡，抽一张卡牌。{ko}차례에 한번:\n\n아무 색상 마나를 지불하고 손에 든 부상 하나를 제거한다. 추가로 카드 1장을 뽑는다.{es}Una vez por Turno:\n\nPaga un maná de cualquier color y tira una herida de tu mano. También roba una carta.{fr}Une fois par Tour:\n\nPayez un mana de n'importe quelle couleur et jetez une Blessure de votre main. Piochez également une carte.{pt-br}Uma vez por Turno:\n\nPague uma mana de qualquer cor e jogue fora um Ferimento da sua mão. Também compre uma carta.{de}Einmal pro Zug:\n\nBezahle ein Mana beliebiger Farbe und wirf eine Wundenkarte aus deiner Hand ab. Ziehe außerdem eine Karte."}

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
				if locking~=nil then
					--setState destroys the old Coop object and creates the competitive-state GUID. Combat cleanup
					--may already have captured the old GUID, so retain the live replacement for that delayed callback.
					skillStateReplacement=skillStateReplacement or {}
					skillStateReplacement[coopGUID]=locking.guid
				end
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
			broadcastToAll("{en}The Rules say you should only access these when the main pile is empty.{ru}Правила гласят, что к ним можно обращаться только тогда, когда основная стопка пуста.{zh-tw}规则说只有当菜单是空的时才能访问这些{zh-cn}规则说只有当菜单是空的时才能访问这些{ko}메인 더미가 비어있을 때만 접근 가능합니다{es}Las Reglas dicen que solo debes acceder a ellas cuando la pila principal esté vacía.{fr}Les règles disent que vous ne devez y accéder que lorsque la pile principale est vide.{pt-br}As Regras dizem que você deveria apenas acessar estas quando a pilha principal está vazia.{de}Die Regeln besagen, dass man auf diese nur zugreifen darf, wenn der Hauptstapel leer ist.", positionToColor(gStates.turnNumber))
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

local bagSearchPending={}
function __onObjectSearchStart_raw(object, player_color)
	if object==nil or object.guid==nil then return end
	local guid=object.guid
	local serial=(bagSearchPending[guid] or 0)+1
	bagSearchPending[guid]=serial
	--Keep the delayed handoff: when a player opens a second bag without closing the first,
	--the first bag's SearchEnd may arrive after this SearchStart. The later commit lets the new bag win.
	safeWaitFrames("Events",function()
		if bagSearchPending[guid]~=serial then return end
		bagSearchPending[guid]=nil
		bagSearch=guid
	end, 5)
end
function __onObjectSearchEnd_raw(object, player_color)
	local guid=object~=nil and object.guid or nil
	if guid==nil then
		bagSearchPending={}
		bagSearch=nil
		return
	end
	--Invalidate a pending delayed start so a very short search cannot become active after it already ended.
	bagSearchPending[guid]=nil
	--An old bag ending must not clear a newer bag that has already become the active search.
	if bagSearch==guid then bagSearch=nil end
end

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
		pulseSourceRandomizeFences()
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
	if terrainTiles[object.guid]~=nil then runtimeMapInvalidateTerrain() end
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
function __onPlayerAction_raw(player, action, targets) return true end

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

local maintenanceWait=nil
local liftHeightLowDetected=false

function refreshLiftHeightWarning()
	local lowDetected=false
	for _, color in pairs(Player.getAvailableColors()) do
		if Player[color].lift_height~=-1 and Player[color].lift_height<0.1 then lowDetected=true break end
	end
	if lowDetected==true and liftHeightLowDetected~=true then
		UI.setAttribute("NoticeText", "Text", "{en}'Lift Height' needs to be higher to avoid the scripting zones.          (Top Right Icon of a Man Lifting Weights){ru}Параметр 'Lift Height' нужно увеличить, чтобы не задевать скриптовые зоны.          (значок человека с гирей справа вверху){zh-tw}需要提高「Lift Height」，以避開腳本區域。          （右上角舉重人物圖示）{zh-cn}需要提高“Lift Height”，以避开脚本区域。          （右上角举重人物图标）{ko}스크립팅 영역을 피하려면 'Lift Height'를 더 높여야 합니다.          (오른쪽 위 역기를 드는 사람 아이콘){es}'Lift Height' debe estar más alto para evitar las zonas de script.          (Icono superior derecho de una persona levantando pesas){fr}'Lift Height' doit être plus élevé pour éviter les zones de script.          (Icône en haut à droite d’une personne soulevant des poids){pt-br}'Lift Height' precisa estar mais alto para evitar as zonas de script.          (Ícone no canto superior direito de uma pessoa levantando pesos){de}'Lift Height' muss höher eingestellt sein, damit die Skriptzonen nicht berührt werden.          (Symbol oben rechts mit einer gewichthebenden Person)")
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
function __filterObjectEnterContainer_raw(container, enter_object)
	if container.getGMNotes()=="Command Tokens" and enter_object.getGMNotes()~="Command Token" then return false end
	if container.getGMNotes()=="Skills" and skillTokens[enter_object.guid]==nil then return false end
	return true -- Allows object to enter.
end

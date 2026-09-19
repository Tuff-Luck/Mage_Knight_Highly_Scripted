-- Turn, round, tactic and final-turn runtime.

local dropoutMatImage="https://steamusercontent-a.akamaihd.net/ugc/9970617178500111609/C9D8D7517B7FAF114F10D8195AC38269F0504E37/"

--Player seat colors only change during setup/load or when a player uses the color controls.
--Keep physical tinting out of mainUIUpdate so ordinary card play never recolors unchanged objects.
local function setDropoutMatImage(playerData, droppingOut)
	if playerData==nil or playerData.playerBoardGUID==nil then return end
	local board=getObjectFromGUID(playerData.playerBoardGUID)
	if board==nil then return end
	if droppingOut==true then
		local custom=board.getCustomObject()
		if playerData.preDropoutMatImage==nil and custom~=nil and custom.image~=nil then playerData.preDropoutMatImage=custom.image end
		board.setCustomObject({image=dropoutMatImage})
	elseif playerData.preDropoutMatImage~=nil then
		board.setCustomObject({image=playerData.preDropoutMatImage})
		playerData.preDropoutMatImage=nil
	else
		return
	end
	board.reload()
end

function dropOutPlayer(player, mouseButton, id)
	if mouseButton~="-1" then return end
	local barGUID=id:sub(1,6)
	local playerIndex=nil
	local playerData=nil
	for position, testGUID in pairs(colorBand) do
		if testGUID==barGUID then
			for a, details in pairs(turnOrder) do
				if details.seatPos==position and details.mage~=gStates.positionMageKnight[5] then playerIndex=a playerData=details break end
			end
			break
		end
	end
	if playerData==nil or legalPlayerCheck(player.color, playerData.seatPos, "NoDummyException")~=true then return end
	if dropoutCoopLocked()==true then
		broadcastToAll("Players cannot drop out while a cooperative assault or defense is being resolved.", positionToColor(playerIndex))
		applyColorBarButtons()
		return
	end
	if gStates.firstStarted==true and playerIndex==gStates.turnNumber then
		broadcastToAll("You cannot drop out during your own turn.", positionToColor(playerIndex))
		applyColorBarButtons()
		return
	end
	if playerData.dropoutState=="dropped" then return end
	if playerData.dropoutState=="pending" then
		playerData.dropoutState=nil
		setDropoutMatImage(playerData, false)
		broadcastToAll(joinLang({translateWord[playerData.mage], "{en} cancelled dropping out.{ru} отменил выход из игры.{zh-tw} 取消了退出遊戲。{zh-cn} 取消了退出游戏。{ko} 게임 나가기를 취소했습니다.{es} canceló su abandono de la partida.{fr} a annulé son départ de la partie.{pt-br} cancelou a saída do jogo.{de} hat das Verlassen des Spiels abgebrochen."}), positionToColor(playerIndex))
	else
		--Never allow dropouts to reduce the game below two active Mage Knights.
		if activeMageKnightCount()<3 then
			broadcastToAll("At least two Mage Knights must remain in the game.", positionToColor(playerIndex))
			applyColorBarButtons()
			return
		end
		playerData.dropoutState="pending"
		setDropoutMatImage(playerData, true)
		broadcastToAll(joinLang({translateWord[playerData.mage], "{en} will drop out when turn order next advances. Press Undo Drop Out before then to cancel.{ru} выйдет из игры при следующем переходе хода. До этого можно отменить выход.{zh-tw} 將在下一次推進回合順序時退出遊戲；在此之前可按撤銷退出。{zh-cn} 将在下一次推进回合顺序时退出游戏；在此之前可按撤销退出。{ko} 다음 차례 진행 시 게임에서 나갑니다. 그 전까지 나가기 취소를 누를 수 있습니다.{es} abandonará la partida cuando avance el orden de turno. Puede deshacerlo antes de entonces.{fr} quittera la partie au prochain changement de tour. Vous pouvez annuler avant cela.{pt-br} sairá do jogo quando a ordem de turno avançar. Você pode desfazer antes disso.{de} verlässt das Spiel beim nächsten Zugwechsel. Bis dahin kann der Austritt rückgängig gemacht werden."}), positionToColor(playerIndex))
	end
	applyColorBarButtons()
end


--Tactic Showing and Hiding
function tacticToggle()
	--rearanges the turn order tokens
	function turnOrderSort()
		for a=1, #turnOrder, 1 do
			getObjectFromGUID(turnOrder[a].turnOrderTokenGUID).unlock()
			getObjectFromGUID(turnOrder[a].turnOrderTokenGUID).setPositionSmooth({-1.90, 1.2, -18.00-(1.4*a)})
		end
		if againstDragonPositionRoundOrderToken~=nil then againstDragonPositionRoundOrderToken() end
		if apocalypseIsHerePositionRoundOrderToken~=nil then apocalypseIsHerePositionRoundOrderToken() end
	end

	if againstDragonRoundStart~=nil then againstDragonRoundStart() end

	--Show all tactics available
	if gStates.tacticShown==true then
		broadcastToAll("{en}Turn order Re-Organised based on tactic card selection{ru}Порядок хода игроков изменился в соответствии с выбранными Тактиками{zh-cn}玩家行动顺序基于战术卡的选择改变了{ko}라운드 순서가 전략 카드에 따라 배치되었습니다{es}Orden de turnos reorganizado según la selección de la tarjeta de táctica{fr}Ordre de tour réorganisé en fonction de la sélection de la carte tactique{pt-br}Ordem de Turno re-organizada baseada nas seleções de táticas{de}Zugreihenfolge neu organisiert basierend auf der Auswahl der Taktikkarten", {1,1,0.5})
		turnOrderSort()
		safeWaitTime("Turn",function()
			local depth=-8
			if gStates.dayRound==true then depth=-4 end
			for a=1, 6, 1 do
				for _, obj in pairs(getObjectFromGUID(tacticZones[a]).getObjects()) do
					if isTacticCard(obj) then
						obj.lock()
						obj.setPosition({obj.getPosition()[1], depth, obj.getPosition()[3]})
						break
					end
				end
			end
		end, 0.5)--allow time for the smooth claim to pull the cards out of the zone
		UI.setAttribute("ScoreButtonReal", "interactable", "True")
		UI.setAttribute("ScoreButtonRealImage", "image", "Sliced Button/Button New Active")
		gStates.tacticShown=false
		if apocalypseIsHereRoundStart~=nil then apocalypseIsHereRoundStart() end
		refreshTactic4HandBonus(true)
		--Day Tactic 2's button cannot replace the central tactic UI while tactics are being chosen.
		--Refresh it now that tactic selection has fully closed.
		safeWaitFrames("Turn",function()
			dayTactic2ButtonActivate()
		end, 5)
		--remove note about re-areanging turn tokens
		if getObjectFromGUID("0934f2")~=nil then getObjectFromGUID("0934f2").destruct()	end
	else
		gStates.tacticSixState="notClaimed"
		gStates.tacticShown=true
		refreshTactic4HandBonus(false)
		broadcastToAll("{en}Start of a Round. Please select a tactic Card for the round.{ru}Начало раунда. Пожалуйста, выберите Тактику на этот раунд из центра.{zh-cn}轮次开始了, 请选择本轮战术卡.{ko}라운드가 시작되었습니다. 전략 카드를 고르세요.{es}Inicio de una Ronda. Selecciona una carta de táctica para la Ronda.{fr}Début d'une Manche. Veuillez sélectionner une carte tactique pour le Rounde.{pt-br}Início de Rodada. Por favor selecione uma carta de Tática para a Rodada.{de}Beginn einer Runde. Bitte wählen Sie eine taktische Karte für die Runde", {1,1,0.5})
		local hide=0
		local show=6
		local depth=-8
		if gStates.dayRound==true then hide=6 show=0 depth=-4 end
		for a=1, 6, 1 do
			if getObjectFromGUID(tacticCard[a+hide])~=nil then
				getObjectFromGUID(tacticCard[a+hide]).setPosition({-16.50+(4*a), depth, 24.00})
				getObjectFromGUID(tacticCard[a+hide]).lock()
			end
			if getObjectFromGUID(tacticCard[a+show])~=nil then
				getObjectFromGUID(tacticCard[a+show]).unlock()
				getObjectFromGUID(tacticCard[a+show]).setRotation({0.00, 180, 0.00})
				getObjectFromGUID(tacticCard[a+show]).setPosition({-16.50+(4*a), 1.5, -14.00})
				getObjectFromGUID(tacticCard[a+show]).lock()
			end
		end
		UI.setAttribute("ScoreButtonReal", "interactable", "False")
		UI.setAttribute("ScoreButtonRealImage", "image", "Sliced Button/Button New Deactive")
		if getObjectFromGUID("0934f2")==nil then turnOrderSort() end
		mainUIUpdate("Tactic Togle")
	end
	claimButtonRefresh()
	cameraControl(nil, "-1", "tacticChanged")
end


function startOfTurn()
	--Setup is complete once the first real turn begins; token pile maintenance is safe from this point onward.
	gStates.tokenRefillEnabled=true
	if apocalypseQuestsUsed()==true then gStates.apocalypseQuestScoringChoiceLocked=true end
	local currentPlayer=turnOrder[gStates.turnNumber]
	if currentPlayer~=nil then currentPlayer.puppetMasterUsed=false end
	gStates.volkarePursuitEnemies={}
	gStates.volkarePursuitCombat=nil
	gStates.volkarePursuitChoicePlayer=nil
	--Camera-choice suppression belongs only to the combat choice that created it. A new turn always starts clean.
	combatCameraChoiceSuppressedPlayer=nil
	resetMeditationTranceState()
	--Quest Score markers are physical/unlocked so players can correct them manually. Revalidate them
	--once per turn in case board physics displaced one between score changes.
	apocalypseQuestRefreshScoreMarkers()
	local virtualCoopCombat=coopAssaultVirtualPlayer(gStates.turnNumber)
	local horsemenGladeReturned=false
	if virtualCoopCombat==false and currentPlayer~=nil and gStates.gameScenario=="Against the Horsemen Blitz" and gStates.againstHorsemenRitualStarted~=true and
		(againstHorsemenPlayerAtCentralGlade(currentPlayer)==true or currentPlayer.horsemenGladeParked==true) then
		portalSwap("startOfTurn", gStates.turnNumber)
		horsemenGladeReturned=true
	end
	local proxyStart=virtualCoopCombat==false and proxyPlayerActive()==true and currentPlayer~=nil and currentPlayer.mage==gStates.positionMageKnight[5]
	if virtualCoopCombat==false and currentPlayer~=nil and currentPlayer.mage==gStates.positionMageKnight[5] and gStates.positionMageKnight[5]~="Volkare" then
		currentPlayer.dummyProcessedThisTurn=false
		if proxyStart==true then gStates.proxyState="Start" end
	end
	--The Proxy has a turn in the order, but is not a normal Mage Knight player. Do only the shared turn
	--cleanup above plus the UI/avatar parking needed to process them. In particular, do not run Quest
	--start hooks, hand/discard/tactic bookkeeping, pursuit start-position tracking, or site benefits such
	--as Glades and Oases.
	if proxyStart==true then
		mainUIUpdate("New Turn")
		portalSwap("startOfTurn", gStates.turnNumber)
		return
	end
	if virtualCoopCombat==false then
		gStates.apocalypseQuestTurnSerial=(gStates.apocalypseQuestTurnSerial or 0)+1
		if gStates.apocalypseQuestConqueredThisTurn==nil then gStates.apocalypseQuestConqueredThisTurn={} end
		--Do Object-UI XML work after the turn-advance click callback has fully unwound.
		local questRefreshTurn=gStates.turnNumber
		safeWaitFrames("Turn",function()
			if gStates.turnNumber==questRefreshTurn then
				apocalypseQuestRichMerchantStartTurn()
				apocalypseQuestOfferRefresh()
			end
		end, 1)
	end
	safeWaitFrames("Turn",function() refreshFracturedLandsTeleportHighlights() end, 1)
	if gStates.gladeDiscardHealUsed==nil then gStates.gladeDiscardHealUsed={} end
	if virtualCoopCombat==false and turnOrder[gStates.turnNumber]~=nil then gStates.gladeDiscardHealUsed[turnOrder[gStates.turnNumber].seatPos]=nil end
	--Records current amount of discarded cards
	turnOrder[gStates.turnNumber].discardCount=0
	for _, b in pairs(getObjectFromGUID(deedDeckDiscardZones[turnOrder[gStates.turnNumber].seatPos]).getObjects()) do
		if b.type=="Card" then turnOrder[gStates.turnNumber].discardCount=1 break end
		if b.type=="Deck" then turnOrder[gStates.turnNumber].discardCount=b.getQuantity() break end
	end

	--remove the manual increase to hand size
	turnOrder[gStates.turnNumber].handBonus=0
	refreshTactic4HandBonus(false)

	--record avatar start location
	for b, details in pairs(mageKnights) do
		if details.mage==turnOrder[gStates.turnNumber].mage then
			if getObjectFromGUID(details.model)~=nil then turnOrder[gStates.turnNumber].turnStartLoc=getObjectFromGUID(details.model).getPosition() end
			if getObjectFromGUID(details.token)~=nil then turnOrder[gStates.turnNumber].turnStartLoc=getObjectFromGUID(details.token).getPosition() end
			if getObjectFromGUID(details.standee)~=nil then turnOrder[gStates.turnNumber].turnStartLoc=getObjectFromGUID(details.standee).getPosition() end
		end
	end
	if againstHorsemenPlayerAtCentralGlade(turnOrder[gStates.turnNumber])==true then
		local gladePos=againstHorsemenCentralGladePosition(1.5)
		if gladePos~=nil then turnOrder[gStates.turnNumber].turnStartLoc=gladePos end
	end
	if turnOrder[gStates.turnNumber].avatarLocation~=nil and (turnOrder[gStates.turnNumber].avatarLocation:sub(1, 4)=="city" or turnOrder[gStates.turnNumber].avatarLocation=="Volkare's Camp") then
		--figure out which city avatar is in
		for zone, citySearch in pairs(cityScriptZones) do
			for obj, detail in pairs(getObjectFromGUID(zone).getObjects()) do
				if detail.getName()==turnOrder[gStates.turnNumber].mage then
					turnOrder[gStates.turnNumber].turnStartLoc=getObjectFromGUID(citySearch.cityGUID).getPosition()
					break
				end
			end
		end
	end

	--A co-op assistant's combat step is not a new turn at the temporary assault location.
	--Do not grant Glade/Hidden Valley/Necropolis/Graveyard/Oasis start-of-turn benefits.
	if virtualCoopCombat==false and (turnOrder[gStates.turnNumber].avatarLocation=="glade" or turnOrder[gStates.turnNumber].avatarLocation=="graveyard"
	 	or turnOrder[gStates.turnNumber].avatarLocation=="hidden valley" or turnOrder[gStates.turnNumber].avatarLocation=="necropolis") then
		--check if glade is conquered
		if gladeFreeCheck()==true then
			local params={position={(turnOrder[gStates.turnNumber].seatPos*40)-103, 1.65, -39}, rotation={0, 0, 0}, smooth=false}
			if gStates.dayRound==true and turnOrder[gStates.turnNumber].avatarLocation~="graveyard" and turnOrder[gStates.turnNumber].avatarLocation~="necropolis" then
				getObjectFromGUID("4a836f").takeObject(params)
				broadcastToAll(joinLang({translateWord[turnOrder[gStates.turnNumber].mage],"{en} gained a Gold Mana Token from the Magical Glade.{ru} получает Золотой жетон маны от Магической поляны.{zh-cn}从魔法林地中获得一个金色魔晶{ko}: 마법 숲속 빈터에서 금색 마나 획득{es} ganó una ficha de Maná de Oro del Claro Mágico.{fr} gagné un jeton de Mana D'or de la Clairière Magique.{pt-br} marcador de Mana Dourada ganho da Clareira Mágica.{de} erhält ein goldenes Mana-Plättchen von der magischen Lichtung."}), positionToColor(gStates.turnNumber))
			end
			if gStates.dayRound==false then
				getObjectFromGUID("74d666").takeObject(params)
				if turnOrder[gStates.turnNumber].avatarLocation~="graveyard" and turnOrder[gStates.turnNumber].avatarLocation~="necropolis" then
					broadcastToAll(joinLang({translateWord[turnOrder[gStates.turnNumber].mage],"{en} gained a Black Mana Token from the Magical Glade.{ru} получает Черный жетон маны от Магической поляны.{zh-cn}从魔法林地中获得一个黑色魔晶{ko}: 마법 숲속 빈터에서 흑색 마나 획득{es} ganó una ficha de Maná Negra del Claro Mágico.{fr} gagné un jeton de Mana Noir de la Clairière Magique.{pt-br} marcador de Mana Preta ganho da Clareira Mágica.{de} ein schwarzes Mana-Plättchen von der Magischen Lichtung erhalten."}), positionToColor(gStates.turnNumber))
				else
					broadcastToAll(joinLang({translateWord[turnOrder[gStates.turnNumber].mage],"{en} gained a Black Mana Token from the Graveyard.{ru} получает Черный жетон маны от Кладбища.{zh-cn}从墓地增加一个黑色魔力{ko}: 묘지에서 흑색 마나 획득{es} ganó una ficha de Maná Negra del Cementerio.{fr} gagné un jeton de Mana Noir du Cimetière.{pt-br} marcador de Mana Preta ganho do Cemitério.{de} ein schwarzes Mana-Plättchen vom Friedhof erhalten."}), positionToColor(gStates.turnNumber))
				end
			end
		end
	end

	--Gain Reminder token from oasis
	if virtualCoopCombat==false and turnOrder[gStates.turnNumber].avatarLocation=="oasis" then
		getObjectFromGUID("a8bf9c").clone({position={(turnOrder[gStates.turnNumber].seatPos*40)-103, 1.65, -39}, rotation={0.00, 180.00, 0.00}, smooth=false}).unlock()
	end

	mainUIUpdate("New Turn")

	--During a co-op assault an assistant is only virtually at the assault location until the result is known.
	if virtualCoopCombat==false and horsemenGladeReturned==false then portalSwap("startOfTurn", gStates.turnNumber) end
end

function playerDropoutInactive(playerIndex)
	if turnOrder[playerIndex]==nil then return false end
	return turnOrder[playerIndex].dropoutState=="pending" or turnOrder[playerIndex].dropoutState=="dropped"
end

function dropoutCoopLocked()
	return dropoutCoopDefensePrompt==true or gStates.coopAssaultPhase~=nil or (gStates.coopAssaultCityGUID~=nil and gStates.assaultData~=nil and next(gStates.assaultData)~=nil)
end

function activeMageKnightCount()
	local count=0
	for a, playerData in pairs(turnOrder) do
		if playerData.mage~=gStates.positionMageKnight[5] and playerDropoutInactive(a)==false then count=count+1 end
	end
	return count
end


function commitPendingDropouts()
	if dropoutCoopLocked()==true then return false end
	local changed=false
	for a, playerData in pairs(turnOrder) do
		if playerData.dropoutState=="pending" then
			playerData.dropoutState="dropped"
			gStates.skipTurn[a]=nil
			local token=getObjectFromGUID(playerData.turnOrderTokenGUID)
			if token~=nil and token.is_face_down==true then token.flip() end
			broadcastToAll(joinLang({translateWord[playerData.mage], "{en} has dropped out of the game.{ru} вышел из игры.{zh-tw} 已退出遊戲。{zh-cn} 已退出游戏。{ko} 게임에서 나갔습니다.{es} ha abandonado la partida.{fr} a quitté la partie.{pt-br} saiu do jogo.{de} hat das Spiel verlassen."}), positionToColor(a))
			changed=true
		end
	end
	if changed==true then
		applyColorBarButtons()
		volkareQuestCheckSkipTurn()
	end
	return changed
end

--Time Bending is set aside for the rest of the round when its extra-turn button is actually used.
--Keep its owner seat so the card can be recovered from the trash chest at round end or before final scoring.
timeBendingGUID="2eb8e2"
local timeBendingRecoveryPending=false
function reclaimTimeBending(callback)
	if gStates==nil or gStates.timeBendingRemovedSeat==nil then if callback~=nil then callback() end return false end
	if timeBendingRecoveryPending==true then return true end
	local seatPos=gStates.timeBendingRemovedSeat
	local existing=getObjectFromGUID(timeBendingGUID)
	if existing~=nil then
		gStates.timeBendingRemovedSeat=nil
		if callback~=nil then callback() end
		return false
	end
	local trash=getObjectFromGUID(trashCan)
	local discardZone=deedDeckDiscardZones~=nil and deedDeckDiscardZones[seatPos]~=nil and getObjectFromGUID(deedDeckDiscardZones[seatPos]) or nil
	if trash==nil or discardZone==nil then
		log("Unable to reclaim Time Bending: trash chest or owner discard zone is missing.")
		return false
	end
	local inTrash=false
	for _, obj in pairs(trash.getObjects()) do if obj.guid==timeBendingGUID then inTrash=true break end end
	if inTrash==false then
		gStates.timeBendingRemovedSeat=nil
		if callback~=nil then callback() end
		return false
	end
	timeBendingRecoveryPending=true
	local pos=discardZone.getPosition()
	local recovered=safeTakeObject("Turn",trash,{guid=timeBendingGUID, position={pos[1], pos[2]+1.5, pos[3]}, rotation={0,180,0}, smooth=false, callback_function=function()
		gStates.timeBendingRemovedSeat=nil
		timeBendingRecoveryPending=false
		safeWaitFrames("Turn",function() if callback~=nil then callback() end end, 2)
	end})
	if recovered==nil then
		timeBendingRecoveryPending=false
		log("Unable to reclaim Time Bending from the trash chest.")
		return false
	end
	return true
end

--Returns which immediate extra-turn effects are currently available to the active player.
function extraTurnOptions(playerIndex)
	local details=turnOrder[playerIndex]
	if details==nil then return false, false end
	local tacticSixAvailable=details.tactic==6 and gStates.dayRound==true and gStates.tacticSixState~="Used" and gStates.tacticRemove==false and gStates.tacticShown==false
	local timeBendingAvailable=false
	local playArea=getObjectFromGUID(playerPlayAreas[details.seatPos])
	if playArea~=nil then
		for _, obj in pairs(playArea.getObjects()) do if obj.guid=="2eb8e2" then timeBendingAvailable=true break end end
	end
	return tacticSixAvailable, timeBendingAvailable
end

--The normal extra-turn button opens a choice only when both effects are genuinely available.
function extraTurnButton(player, mouseButton, id)
	if mouseButton~="-1" or legalPlayerCheck(player.color, turnOrder[gStates.turnNumber].seatPos)~=true then return end
	local tacticSixAvailable, timeBendingAvailable=extraTurnOptions(gStates.turnNumber)
	if tacticSixAvailable and timeBendingAvailable then
		UI.setAttribute("ExtraTurnChoice", "visibility", positionToColor(gStates.turnNumber).."|Black")
		UI.show("ExtraTurnChoice")
		return
	end
	UI.hide("ExtraTurnChoice")
	if tacticSixAvailable then
		preEndTurn(player, "-1", "ExtraTurnChoiceTactic6")
	elseif timeBendingAvailable then
		preEndTurn(player, "-1", "ExtraTurnChoiceTimeBending")
	end
end

function extraTurnChoice(player, mouseButton, id)
	if mouseButton~="-1" or legalPlayerCheck(player.color, turnOrder[gStates.turnNumber].seatPos)~=true then return end
	local tacticSixAvailable, timeBendingAvailable=extraTurnOptions(gStates.turnNumber)
	if id=="ExtraTurnChoiceTimeBending" and timeBendingAvailable then
		UI.hide("ExtraTurnChoice")
		preEndTurn(player, "-1", "ExtraTurnChoiceTimeBending")
	elseif id=="ExtraTurnChoiceTactic6" and tacticSixAvailable then
		UI.hide("ExtraTurnChoice")
		preEndTurn(player, "-1", "ExtraTurnChoiceTactic6")
	end
end

--Deals player Hand then increments turn
function __endTurn_raw(player, mouseButton, id, rewindReady)
	if legalPlayerCheck(player.color, turnOrder[gStates.turnNumber].seatPos)==true then --and slightPause==false
		local rewardSeat=turnOrder[gStates.turnNumber].seatPos
		local questRewardPending,_,questRewardAction=apocalypseQuestRewardCompletionPendingForPlayer(gStates.turnNumber)
		if questRewardPending==true then
			apocalypseQuestRefreshOfferButtons()
			rewardReminderCameraFocus(player.color,"questView")
			local questGateMessage=(questRewardAction=="Fail" or questRewardAction=="CompleteOrFail") and "Complete/Fail the Quest First" or "Complete/Progress the Quest First"
			broadcastToColor(questGateMessage,player.color,warningColor)
			if rewindReady==true then rewindTransactionFinish("End turn") end
			return
		end
		if steadyTempoPendingForSeat~=nil and steadyTempoPendingForSeat(rewardSeat)==true then
			steadyTempoRefreshAll() steadyTempoUpdateRewardGate(rewardSeat)
			broadcastToAll("Resolve Steady Tempo before claiming rewards.", positionToColor(gStates.turnNumber))
			if rewindReady==true then rewindTransactionFinish("End turn") end
			return
		end
		if gStates.mineClaimPending~=nil then
			broadcastToColor("Resolve the pending crystal choice before proceeding to the next player.", player.color, warningColor)
			if rewindReady==true then rewindTransactionFinish("End turn") end
			return
		end
		if rewindReady~=true and rewindTransactionOwnerActive("End turn")==true then return end
		if gStates.coopAssaultPhase=="rewards" then
			if gStates.skillButtons==0 then
				if rewindReady~=true then
					rewindTransactionStart(function() endTurn(player,mouseButton,id,true) end,"End turn")
					return
				end
				local function finishCoopRewardAdvance()
					advanceCoopRewardPhase()
					safeWaitFrames("Turn",function() rewindTransactionFinish("End turn") end,10)
				end
				--Co-op hand draw is delayed until Rewards Claimed, after the city result has set the final hand limit.
				if (gStates.timeBending~="Started" or gStates.turnNumber~=gStates.realTurn) and turnOrder[nextTurnMerged("nextMage")].endCalled~=true and turnOrder[nextTurnMerged("nextMageSkipDummy")].endCalled~=true then drawUpTo(player, "-1", "DrawHand") end
				--Don't switch reward players while a visible Deed transfer is still travelling or queued.
				if cardClaim==true or deedTransferAnyBusy()==true then
					safeWaitCondition("Turn",finishCoopRewardAdvance,function() return cardClaim~=true and deedTransferAnyBusy()~=true end,10,finishCoopRewardAdvance)
				else
					finishCoopRewardAdvance()
				end
			else
				if rewindReady==true then rewindTransactionFinish("End turn") end
				rewardReminderCameraFocus(player.color,"offerView")
				broadcastToAll(joinLang({translateWord[turnOrder[gStates.turnNumber].mage],"{en} needs to select a skill before claiming these rewards.{ru} должен выбрать Навык перед получением наград.{zh-cn}需要先选择一项技能再领取奖励.{ko}: 보상을 받기 전에 스킬을 선택하세요.{es} necesita seleccionar una habilidad antes de reclamar estas recompensas.{fr} doit sélectionner une compétence avant de réclamer ces récompenses.{pt-br} precisa selecionar uma habilidade antes de pegar estas recompensas.{de} muss eine Fertigkeit auswählen, bevor diese Belohnungen beansprucht werden."}), warningColor)
			end
			return
		end
		--slightPause=true
		if gStates.skillButtons==0 then--must choose from offered skill to proceed
			if rewindReady~=true then
				rewindTransactionStart(function() endTurn(player,mouseButton,id,true) end,"End turn")
				return
			end

			apocalypseQuestMineDoomEndTurnCleanup(gStates.turnNumber)
			apocalypseQuestClearMarkerHighlights()
			UI.setAttribute("NightTacticSix", "active", "false")
			UI.setAttribute("zigguratPyramidInteract", "active", "false")
			gStates.preEndTurn=false
			gStates.levelingUp=false
			gStates.crytalRuin=false
			gStates.volkareArmyReduced=false
			turnOrder[gStates.turnNumber].fameGain=0 gStates.gainList={}
			turnOrder[gStates.turnNumber].repGain=0
			turnOrder[gStates.turnNumber].combatIconHide="None"
			turnOrder[gStates.turnNumber].pillagedVillage=false
			gStates.skippedMove=false
			gStates.druidNightsSummon=nil
			gStates.druidNightsCrystalReward=nil
			gStates.locationPlace={}
			gStates.summonStates={}
			gStates.shieldsDropped={}
			if gStates.endGameAchieved=="started" then gStates.endGameAchieved="true" end
			--Update all pursuing monsters, new deployed or stunned will be on the move.
			if gStates.pursuingMonsters[turnOrder[gStates.turnNumber].mage]~=nil then
				for guid, monster in pairs(gStates.pursuingMonsters[turnOrder[gStates.turnNumber].mage]) do
					if getObjectFromGUID(guid)~=nil then
						local monsterObj=getObjectFromGUID(guid)
						if monster.state=="Deployed" and monsterObj.is_face_down==true then monsterObj.flip() end
						if monster.state=="Stunned" then monster.stunned=true monster.state="Deployed" else if monster.state=="Deployed" then monster.stunned=nil setPursuitStunnedImage(monsterObj, false) end monster.state="Pursuing" end
						monster.location={monsterObj.getPosition()[1], monsterObj.getPosition()[2], monsterObj.getPosition()[3]}
						gStates.monsterPlayLocation[guid]=monster.location
					end
				end
				--delete the help arrows
				for guid, _ in pairs(gStates.arrowDelete) do
					if getObjectFromGUID(guid)~=nil then getObjectFromGUID(guid).destruct() end
				end
				gStates.arrowDelete={}
			end

			if (gStates.timeBending~="Started" or gStates.turnNumber~=gStates.realTurn) and gStates.coopAssaultPhase~="combat" then
				--Normal turns draw here. Co-op assault hands wait until that player clicks Rewards Claimed.
				if turnOrder[nextTurnMerged("nextMage")].endCalled~=true and turnOrder[nextTurnMerged("nextMageSkipDummy")].endCalled~=true then
					drawUpTo(player, "-1", "DrawHand")
				end
			end

			--remove any wound cards played because of glade, regardless of which face is showing.
			for _, playAreaObj in pairs(getObjectFromGUID(playerPlayAreas[turnOrder[gStates.turnNumber].seatPos]).getObjects()) do
				if playAreaObj.getGMNotes()=="Wound" then
					getObjectFromGUID(trashCan).putObject(playAreaObj)
				end
			end

			--re-enable night tactic six buttons
			if turnOrder[gStates.turnNumber].tactic==6 and gStates.tacticSixState~="Used" and gStates.dayRound==false then
				gStates.tacticSixState="notClaimed"
			end

			--Update Motivation Skill status
			for a, stats in pairs(gStates.motivationSkill) do
				if stats.state=="used" then stats.state="deactive" end
			end

			--During a co-op Dragon assault this player's physical head tokens have now been read and
			--returned. Mark their combat complete before asking whether another assaulter remains.
			if gStates.coopAssaultPhase=="combat" and coopAssaultTargetType()=="dragon" and apocalypseDragonGroundPlayerFinished~=nil then apocalypseDragonGroundPlayerFinished(gStates.turnNumber) end
			--During a co-op assault finish every combat before starting the reward queue.
			if gStates.coopAssaultPhase=="combat" and coopAssaultPendingCombat()==false then
				startCoopRewardPhase()
			elseif gStates.volkareMovementStepPending==true and gStates.volkareMovementPaused==true and gStates.volkarePendingCombatMage==turnOrder[gStates.turnNumber].mage then
				--A first-half Volkare attack consumed this Mage Knight's turn. Release the second movement only now, after combat/rewards are finished.
				gStates.volkareMovementPaused=false
				gStates.volkareAdvanceAfterMovement=true
				gStates.volkarePendingCombatMage=nil
			elseif againstDragonFullAttendInProgress~=nil and againstDragonFullAttendInProgress(gStates.turnNumber)==true then
				--The target just took their normal turn in advance. Resolve the airborne attack and release
				--the suspended Dragon turn directly; do not return to a Dragon Processed interface.
				againstDragonFinishAttackForPlayer(gStates.turnNumber,true)
			elseif apocalypseDragonGroundCombatForPlayer~=nil and apocalypseDragonGroundCombatForPlayer(gStates.turnNumber)==true then
				--Dragon levels only move after the whole ground combat is over. The pre-end-turn pass has
				--already read every physical head token and placed the player's level-marking Shields.
				apocalypseDragonFinalizeGroundCombat(gStates.turnNumber)
				nextTurnMerged("incrementTurn")
			else
				volkareQuestCombatWithdrawalReminder(turnOrder[gStates.turnNumber].mage)
				nextTurnMerged("incrementTurn")
			end
			recourceTrackerReset()
			if gStates.coopAssaultPhase~="combat" then claimButtonRefresh() end
			addAvatarButtons()
			safeWaitFrames("Turn",function() rewindTransactionFinish("End turn") end,10)
		else
			if rewindReady==true then rewindTransactionFinish("End turn") end
			rewardReminderCameraFocus(player.color,"offerView")
			broadcastToAll(joinLang({translateWord[turnOrder[gStates.turnNumber].mage],"{en} needs to select a skill before you can end their Turn.{ru} должен выбрать Навык перед окончанием хода.{zh-cn}需要先选择一项技能, 然后才能结束他们的回合. {ko}: 차례를 넘기기 전에 스킬을 선택하세요.{es} necesita seleccionar una habilidad antes de que pueda finalizar su turno.{fr} doit sélectionner une compétence avant de pouvoir terminer son tour.{pt-br} precisa selecionar uma habilidade antes que você possa encerrar seu turno.{de} muss eine Fertigkeit wählen, bevor du seinen Zug beenden kannst."}), warningColor)
		end
	end
end

--The first finish-line event owns the final-turn circuit.
--End of Round: stop when play returns to the caller; the caller gets no extra turn.
--Player victory: return to the victory player, give them one final turn, then stop.
--Volkare victory: Volkare is the owner but is never given a final turn.
function clearFinalTurnBoundary()
	gStates.finalTurnReason=nil
	gStates.finalTurnOwnerMage=nil
	gStates.finalTurnOwnerGetsTurn=nil
	gStates.finalTurnOwnerTurnStarted=false
end

function ensureFinalTurnBoundary()
	if gStates==nil or gStates.finalTurnReason==nil then return nil end
	if gStates.finalTurnOwnerMage==nil then
		local marker=gStates.finalTurnReason=="victory" and "gameEnder" or "endCalled"
		for _, details in pairs(turnOrder) do
			if details[marker]==true then gStates.finalTurnOwnerMage=details.mage break end
		end
	end
	if gStates.finalTurnOwnerGetsTurn==nil then
		gStates.finalTurnOwnerGetsTurn=gStates.finalTurnReason=="victory" and gStates.finalTurnOwnerMage~=nil and gStates.finalTurnOwnerMage~=gStates.positionMageKnight[5]
	end
	if gStates.finalTurnOwnerTurnStarted==nil then gStates.finalTurnOwnerTurnStarted=false end
	return gStates.finalTurnOwnerMage
end

function establishFinalTurnBoundary(reason, playerIndex)
	if gStates.finalTurnReason~=nil then ensureFinalTurnBoundary() return false end
	local details=turnOrder[playerIndex]
	if details==nil then return false end
	gStates.finalTurnReason=reason
	gStates.finalTurnOwnerMage=details.mage
	gStates.finalTurnOwnerGetsTurn=reason=="victory" and details.mage~=gStates.positionMageKnight[5]
	gStates.finalTurnOwnerTurnStarted=false
	return true
end

local function finalTurnOwnerIs(playerIndex)
	local owner=ensureFinalTurnBoundary()
	return owner~=nil and turnOrder[playerIndex]~=nil and turnOrder[playerIndex].mage==owner
end

local function finalTurnBoundaryActive()
	if gStates.finalTurnReason=="endRound" then return gStates.endRoundCalled==true end
	if gStates.finalTurnReason=="victory" then return gStates.endGameAchieved=="true" end
	return false
end

--Commit a Mage Knight/Dummy/Volkare turn after any interstitial scenario turn has finished.
function mergedTurnCommit(nextTurnNumber,newOutOfTurn,sameTurn)
	gStates.turnNumber=nextTurnNumber
	if newOutOfTurn==false then gStates.realTurn=gStates.turnNumber end
	if sameTurn==false and gStates.finalTurnReason=="victory" and gStates.finalTurnOwnerGetsTurn==true and
		finalTurnBoundaryActive()==true and finalTurnOwnerIs(gStates.turnNumber) then gStates.finalTurnOwnerTurnStarted=true end
	applyColorBarButtons()
	broadcastToAll(joinLang({"{en}It is now {ru}Ходит {zh-cn}现在是{ko}{es}Ahora es el turno de {fr}C'est maintenant au tour de {pt-br}é agora turno de {de}Jetzt ist ", translateWord[turnOrder[gStates.turnNumber].mage], "{en}'s turn.{ru} {zh-cn}的回合{ko}의 차례입니다.{es}.{fr}.{pt-br}.{de} an der Reihe."}), positionToColor(gStates.turnNumber))
	if gStates.coopAssaultPhase=="combat" and coopAssaultTargetType~=nil and coopAssaultTargetType()=="dragon" and apocalypseDragonGroundCombatForPlayer~=nil and apocalypseDragonGroundCombatForPlayer(gStates.turnNumber)==true then apocalypseDragonRefreshGroundAttackSuppression() end
	if gStates.tacticShown==false then startOfTurn() else claimButtonRefresh() end
	fakeDropAvatar()
	return gStates.turnNumber
end

--Return the value of the next turn
function nextTurnMerged(type)--"nextMage", "nextMageSkipDummy", "incrementTurn",
	local extraTurnStarted=gStates.tacticSixState=="Started" or gStates.timeBending=="Started"
	--A wrap while players are choosing Tactics closes tactic selection; it is not the end of a
	--real turn circuit and must not give the Dragon a turn before the first Mage Knight acts.
	local startedDuringTacticSelection=gStates.tacticShown==true
	ensureFinalTurnBoundary()

	--A real victory owner ends the game only after completing the extra final turn.
	if type=="incrementTurn" and gStates.finalTurnReason=="victory" and gStates.finalTurnOwnerGetsTurn==true and
		gStates.finalTurnOwnerTurnStarted==true and finalTurnOwnerIs(gStates.turnNumber) and extraTurnStarted==false then
		gStates.gameOver=true
		mainUIUpdate("Game Over")
		return gStates.turnNumber
	end

	--finds all players with a flipped down turn order token
	local nextTurnNumber=gStates.realTurn
	local wrappedCircuit=false
	local function advanceTurnNumber()
		nextTurnNumber=nextTurnNumber+1
		if nextTurnNumber>#turnOrder then
			nextTurnNumber=1
			wrappedCircuit=true
			--Work out new turn order from tactics after all active players have chosen.
			if gStates.tacticShown==true and type=="incrementTurn" then
				table.sort(turnOrder, function (k1, k2) return k1.tactic < k2.tactic end)
				tacticToggle()
			end
		end
	end
	local turnSearch=nextTurnNumber+1
	if turnSearch>#turnOrder then turnSearch=1 end
	local newOutOfTurn=false
	--I search in turn order for any new face down turn order tokens. If I find a new one, I record it and jump to it's turn imediately.
	for a=1, #turnOrder, 1 do
		local turnToken=nil
		if playerDropoutInactive(turnSearch)==false and gStates.skipTurn[turnSearch]==nil and gStates.firstStarted==true then turnToken=getObjectFromGUID(turnOrder[turnSearch].turnOrderTokenGUID) end
		if turnToken~=nil and turnToken.is_face_down==true then --and gStates.turnNumber~=turnSearch
			if type=="incrementTurn" then gStates.skipTurn[turnSearch]=true end
			if turnOrder[turnSearch].mage~="Volkare" then
				nextTurnNumber=turnSearch
				newOutOfTurn=true
				break
			end
		end
		turnSearch=turnSearch+1
		if turnSearch>#turnOrder then turnSearch=1 end
	end

	local finalBoundaryReached=false
	local function candidateEndsFinalCircuit()
		if type~="incrementTurn" or extraTurnStarted==true or finalTurnBoundaryActive()==false or finalTurnOwnerIs(nextTurnNumber)==false then return false end
		--End-of-Round owners and Volkare stop before receiving another turn.
		if gStates.finalTurnOwnerGetsTurn~=true then return true end
		--Never start the owner's final turn twice (important after save/load or unusual out-of-order play).
		if gStates.finalTurnOwnerTurnStarted==true then return true end
		--A dropped owner or an owner who already spent this turn out of order has no normal final turn left to start.
		if playerDropoutInactive(nextTurnNumber)==true or gStates.skipTurn[nextTurnNumber]==true then return true end
		return false
	end

	--if no new out of order mages find next legit mage's turn
	--A pending extra turn returns to the real-turn player before normal turn-order advancement.
	--This preserves co-op assistants' skipTurn markers until their actual positions in the later turn circuit.
	if newOutOfTurn==false and extraTurnStarted==false then
		if type=="incrementTurn" then gStates.volkareState="Start" end
		advanceTurnNumber()

		local function skipDummy()
			if candidateEndsFinalCircuit()==true then finalBoundaryReached=true return true end
			--Otherwise skip dummy during final turns as normal.
			if (type=="nextMageSkipDummy" or ((gStates.endGameAchieved=="true" or gStates.endRoundCalled==true) and type=="incrementTurn")) and gStates.tacticShown~=true and turnOrder[nextTurnNumber].mage==gStates.positionMageKnight[5] then
				if type=="incrementTurn" then broadcastToAll(joinLang({translateWord[turnOrder[nextTurnNumber].mage], "{en} isn't included in the final round of turns{ru} не участвует в последнем ходе Раунда.{zh-cn}不包括在最后一轮的回合中{ko}: 마지막 턴 중에서 제외됨{es} no está incluido en la ronda final de turnos{fr} n'est pas inclus dans le dernier rounde de tours{pt-br} não está incluído na rodada final de turnos.{de} ist nicht in der letzten Runde dabei"}), {1,1,0.5}) end
				advanceTurnNumber()
				return false
			end
			return true
		end
		skipDummy()

		if finalBoundaryReached==false then
			--skip players who played out of turn or have dropped out
			for a=1, #turnOrder+1, 1 do
				local validTurn=true
				if playerDropoutInactive(nextTurnNumber)==true then
					validTurn=false
					advanceTurnNumber()
				elseif gStates.skipTurn[nextTurnNumber]==true then
					validTurn=false
					if type=="incrementTurn" then
						gStates.skipTurn[nextTurnNumber]=nil
						if turnOrder[nextTurnNumber].mage~="Volkare" then
							broadcastToAll(joinLang({translateWord[turnOrder[nextTurnNumber].mage], "{en} skips their turn. They played out of order. Turn order token flipped back upright.{ru} пропускает ход. Их ход был сыгран не по порядку. Жетон порядка хода переворачивается обратно вверх.{zh-cn}跳过他们的回合. 他们打乱了顺序. 顺位指示标记翻转. {ko}: 차례를 건너뜁니다. 다시 라운드 순서 토큰이 앞면으로 뒤집힙니다.{es} omite su turno. Jugaron fuera de orden. Ficha de orden de giro volteada hacia atrás.{fr} passe leur tour. Ils ont joué dans le désordre. Jeton d'ordre de tour retourné à la verticale.{pt-br} pule seus turnos. Eles jogaram fora de ordem. Marcador de ordem de turno virado de volta para cima.{de} überspringt seinen Zug. Sie haben außer der Reihe gespielt. Das Zugreihenfolgeplättchen wird wieder aufgedreht."}), positionToColor(nextTurnNumber))
						else
							broadcastToAll("{en}Volkare skips his turn. He's recovering from the battle.{ru}Волкар пропускает ход. Он восстанавливается после битвы.{zh-cn}沃尔卡雷跳过了他的回合. 他正在从战斗中恢复过来. {ko}볼케어는 전투 후 정비 중입니다. 볼케어의 차례를 건너뜁니다.{es}Volkare se salta su turno. Se está recuperando de la batalla.{fr}Volkare passe son tour. Il se remet de la bataille.{pt-br}Volkare pula sua vez. Ele está se recuperando da batalha.{de}Volkare überspringt seinen Zug. Er erholt sich von dem Kampf.", positionToColor(nextTurnNumber))
						end
						local token=getObjectFromGUID(turnOrder[nextTurnNumber].turnOrderTokenGUID)
						if token~=nil and token.is_face_down==true then token.flip() end
					end
					advanceTurnNumber()
				end
				--Skip dummy if end of game started
				local dummyValidTurn=skipDummy()
				if finalBoundaryReached==true then break end
				if validTurn==true and dummyValidTurn==true then break end
			end
		end
	end

	if type=="incrementTurn" and finalBoundaryReached==true then
		for ownerIndex, details in pairs(turnOrder) do
			if details.mage==gStates.finalTurnOwnerMage then
				if gStates.skipTurn[ownerIndex]==true then
					gStates.skipTurn[ownerIndex]=nil
					local token=getObjectFromGUID(details.turnOrderTokenGUID)
					if token~=nil and token.is_face_down==true then token.flip() end
				end
				if gStates.finalTurnReason=="endRound" then details.endCalled=false end
				break
			end
		end
		if gStates.finalTurnReason=="endRound" then
			if gStates.endGameAchieved=="true" then
				if gStates.currentRound>=gStates.rounds and gStates.gameScenario=="One to Return" then oneToReturnResolveWinner() end
				if gStates.currentRound>=gStates.rounds and (gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz") and volkareArmyStillAlive()==true then
					gStates.volkareWon=true
					gStates.volkareReturnTimeoutLoss=true
					gStates.blurb="{en}The final Round ended while Volkare still had an army.<size=6>\n\n</size>You have Lost.{ru}Последний раунд закончился, пока у Волкара еще оставалась армия.<size=6>\n\n</size>Вы проиграли.{zh-tw}最後一輪結束時沃卡里仍有軍隊。<size=6>\n\n</size>你輸了。{zh-cn}最后一轮结束时沃卡里仍有军队。<size=6>\n\n</size>你输了。{ko}마지막 라운드가 끝났지만 볼케어의 군대가 남아 있습니다.<size=6>\n\n</size>패배했습니다.{es}La Ronda final terminó mientras Volkare aún tenía un ejército.<size=6>\n\n</size>Has perdido.{fr}La dernière Manche s'est terminée alors que Volkare avait encore une armée.<size=6>\n\n</size>Vous avez perdu.{pt-br}A Rodada final terminou enquanto Volkare ainda tinha um exército.<size=6>\n\n</size>Você perdeu.{de}Die letzte Runde endete, während Volkare noch eine Armee hatte.<size=6>\n\n</size>Ihr habt verloren."
					UI.setAttribute("DummyNotes", "Text", gStates.blurb)
				end
				gStates.gameOver=true
				mainUIUpdate("Game Over")
			else endRound() end
		else
			gStates.gameOver=true
			mainUIUpdate("Game Over")
		end
		return gStates.turnNumber
	end

	--have another turn option replaces found next turn.
	local sameTurn=false
	if extraTurnStarted==true then
		sameTurn=true
		if newOutOfTurn==false then
			nextTurnNumber=gStates.realTurn
			--Only consume the extra-turn effect when the turn engine actually returns to the real-turn player.
			--During a co-op assault, handoffs to face-down assisting players must leave it Started until combat/rewards finish.
			if type=="incrementTurn" then
				if gStates.timeBending=="Started" then gStates.timeBending="Used" end
				if gStates.tacticSixState=="Started" then gStates.tacticSixState="Used" end
			end
		end
	end
	--Pending dropouts become permanent only when play genuinely advances to another turn.
	if type=="incrementTurn" and sameTurn==false then commitPendingDropouts() end

	--Against the Dragon acts after each complete normal turn circuit. Out-of-order and extra turns do
	--not create extra Dragon turns, and End of Round / first lair attack suppresses them in the helper.
	if type=="incrementTurn" and sameTurn==false and newOutOfTurn==false and wrappedCircuit==true and startedDuringTacticSelection==false and gStates.tacticShown==false and againstDragonBeginTurn~=nil then
		if againstDragonBeginTurn(nextTurnNumber,newOutOfTurn,sameTurn)==true then return nextTurnNumber end
	end
	if type=="incrementTurn" and sameTurn==false and newOutOfTurn==false and wrappedCircuit==true and startedDuringTacticSelection==false and gStates.tacticShown==false and apocalypseIsHereBeginHorsemenTurn~=nil then
		if apocalypseIsHereBeginHorsemenTurn(nextTurnNumber,newOutOfTurn,sameTurn)==true then return nextTurnNumber end
	end

	--increment the turn
	if type=="incrementTurn" then mergedTurnCommit(nextTurnNumber,newOutOfTurn,sameTurn) end
	return nextTurnNumber
end

--record the player who called end of round
function __PreEndRound_raw(player, mouseButton, id)
	if gStates.apocalypseHereHorsemenTurnActive==true then
		if player~=nil and player.color~=nil then broadcastToColor("Finish the Horsemen turn first.",player.color,warningColor) end
		return
	end
	if gStates.apocalypseDragonTurnActive==true then
		if player~=nil and player.color~=nil then broadcastToColor("Finish the Apocalypse Dragon turn first.",player.color,warningColor) end
		return
	end
	if gStates.endGameAchieved~="false" then return end
	if mouseButton=="-1" and legalPlayerCheck(player.color, turnOrder[gStates.turnNumber].seatPos)==true then
		turnOrder[gStates.turnNumber].endCalled=true
		gStates.endRoundCalled=true
		establishFinalTurnBoundary("endRound", gStates.turnNumber)
		--Show Game over Screen
		if gStates.currentRound==gStates.rounds and gStates.endGameAchieved~="true" then
		    gStates.endGameAchieved="true"
			if gStates.gameScenario=="One to Return" then oneToReturnLockFinalWinner() end
		end
		-- if gStates.currentRound==gStates.rounds and gStates.endGameAchieved~="true" then
		-- 	if gStates.playersRef==5 and turnOrder[gStates.turnNumber].mage~=gStates.positionMageKnight[5] then UI.setAttribute("GameOver", "active", "true") layoutClaimedCards() return end
		-- 	gStates.endGameAchieved="true"
		-- end--GameOver

		--move on coop skills
		local nextPlayer=nextTurnMerged("nextMageSkipDummy")
		local count=0
		for skillGUID, details in pairs(gStates.doingTheRounds) do
			if gStates.coopCompSkillPaused==nil or gStates.coopCompSkillPaused[skillGUID]==nil then
				data=doingTheRounds(skillGUID, nextPlayer, count)
				count=data[2]
			end
		end
		refreshCoopCompSkillXs()

		--unlock second action for control over the offer.
		for _, object in pairs(getObjectFromGUID("109d8e").getObjects()) do
			if object.type=="Card" then object.unlock() break end
		end
		for _, object in pairs(getObjectFromGUID("e88f19").getObjects()) do
			if object.type=="Card" then object.unlock() break end
		end

		if activeMageKnightCount()>1 or turnOrder[gStates.turnNumber].mage==gStates.positionMageKnight[5] then
			broadcastToAll(joinLang({translateWord[turnOrder[gStates.turnNumber].mage],"{en} called End of Round. Everyone else has one final turn.{ru} объявил конец Раунда. Остальные делают по одному ходу.{zh-cn}宣布结束轮次, 所有其他玩家还有最后一回合{ko}: 라운드 종료 선언. 모두 마지막 차례를 한 번씩 더 갖습니다.{es} llamado Fin de Ronda. Todos los demás tienen un turno final.{fr} appelé la Fin de Rounde. Tout le monde a un dernier tour.{pt-br} chamado o fim de Rodada. Todos outros tem um turno final.{de} ende der Runde ausgerufen. Alle anderen haben einen letzten Zug."}), positionToColor(gStates.turnNumber))
			--Delete mana token given by glade
			for a, playAreaObj in pairs(getObjectFromGUID(playerPlayAreas[turnOrder[gStates.turnNumber].seatPos]).getObjects()) do
				if playAreaObj.type=="Figurine" then playAreaObj.destruct() end
			end
			nextTurnMerged("incrementTurn")
		else
			preEndTurn({color="Black"}, "-1", "EndTurnButton")
		end
	end
end

--Run all the End of Round Tasks
endRoundRewindRequestPending=false
function __endRound_raw(rewindReady)
	if rewindReady~=true then
		if endRoundRewindRequestPending==true then return end
		--Unlike the other protected actions, the true round-reset boundary has no player button to press
		--again after a rewind. Save a durable checkpoint marker so onLoad can resume this reset automatically.
		gStates.endRoundResetPending=true
		endRoundRewindRequestPending=true
		rewindTransactionStart(function()
			endRoundRewindRequestPending=false
			--The stored rewind state keeps the marker; the live game clears it before any reset mutation.
			gStates.endRoundResetPending=false
			endRound(true)
		end,"End of round",function()
			endRoundRewindRequestPending=false
			gStates.endRoundResetPending=false
		end)
		return
	end
	--Time Bending returns before the round reset rebuilds and shuffles the owner's Deed deck.
	if gStates.timeBendingRemovedSeat~=nil then if reclaimTimeBending(endRound)==true then return end end
	--Against the Horsemen resolves its Round 1/2 approach, or the Round 3 ritual move, before tactics or the round reset.
	if againstHorsemenBeginEndRoundMovement()==true then return end
	--A Proxy objective is part of its Deed deck between rounds, just like the physical rules.
	if proxyPlayerActive()==true and gStates.proxyObjectiveGUID~=nil then proxyClearObjective(true) end
	--One to Return closes the starting Portal after the first Day's final-turn circuit is complete.
	if gStates.gameScenario=="One to Return" and gStates.currentRound==1 then
		oneToReturnClosePortal()
		if gStates.gameOver==true then return end
	end
	--Update round count and check for end of game
	broadcastToAll("-------------------",{1,1,0.5})
	apocalypseQuestEndRoundCleanup()
	gStates.currentRound=gStates.currentRound+1
	apocalypseQuestRefreshStrayToken()
	gStates.powerStored={}
	for _, details in pairs(turnOrder) do if details.tactic==6 then scheduleDeedPileDescriptionRefresh(details.seatPos, "deed") end end

	--Switch Day/Night Objects for Darkness is Comming
	local dieValue={"{en}Red{ru}Красный{zh-cn}红色的{ko}빨간색{es}Rojo{fr}Rouge{pt-br}Vermelho{de}Rote",
					"{en}Green{ru}Зеленый{zh-cn}绿色的{ko}녹색{es}Verde{fr}Vert{pt-br}Verde{de}Grüne",
					"{en}Blue{ru}Синий{zh-cn}蓝色的{ko}파란색{es}Azul{fr}Bleu{pt-br}Azul{de}Blaue",
					"{en}White{ru}Белый{zh-cn}白色的{ko}흰색{es}Blanco{fr}Blanc{pt-br}Branco{de}Weiße",
					"{en}Gold{ru}Золотой{zh-cn}金色的{ko}금색{es}Oro{fr}Or{pt-br}Ouro{de}Gold",
					"{en}Black{ru}Черный{zh-cn}黑色的{ko}흑색{es}Negro{fr}Noir{pt-br}Preto{de}Schwarz"}
	local virtualDie1=math.random(1,6)
	local virtualDie2=math.random(1,6)
	if gStates.darknessComing==true then broadcastToAll(joinLang({"{en}Virtual Dice rolled {ru}Виртуальный бросок кубика выпал на {zh-cn}投掷出{ko}다음의 색 주사위 굴려짐: {es}Dados virtuales enrollados en {fr}Dés virtuels lancés {pt-br}Dados Virtuais Rolados {de}Virtuelle Würfel gewürfelt ", dieValue[virtualDie1], "{en} and {ru} и {zh-cn}和{ko}그리고{es} y {fr} et {pt-br} e {de} und ", dieValue[virtualDie2]}), {1,1,0.5}) end
	if gStates.darknessComing==true and (virtualDie1==6 or virtualDie2==6) then broadcastToAll("{en}Time of day has changed permenantly{ru}Время дня изменилось до конца игры{zh-cn}白昼/黑夜停止交替了{ko}낮 또는 밤이 영원히 지속됩니다{es}La hora del día ha cambiado permanentemente{fr}L'heure de la journée a changé en permanence{pt-br}Tempo do dia mudado permanentemente.{de}Die Tageszeit hat sich dauerhaft geändert", {1,1,0.5}) end
	if gStates.darknessComing==false or (gStates.darknessComing==true and (virtualDie1==6 or virtualDie2==6) and gStates.timeChanged==false) then
	 	gStates.timeChanged=true
	 	dayNight()
	end

	--return unused mana steal die
	if getObjectFromGUID("fbd7fd")~=nil then --day tactic 3
		getObjectFromGUID("fbd7fd").registerCollisions()
		getObjectFromGUID("fbd7fd").lock()
	end
	safeWaitFrames("Turn",function()
		if getObjectFromGUID("fbd7fd")~=nil then getObjectFromGUID("fbd7fd").unregisterCollisions() end

		--Reroll all mana dice
		broadcastToAll("{en}Mana Dice Reset{ru}Кубики маны переброшены{zh-cn}魔力骰子重置{ko}마나 주사위 리셋{es}Reinicio de Dados de Maná{fr}Réinitialisation des dés de Mana{pt-br}Dado de Mana Reiniciado.{de}Manawürfel zurückgesetzt", {1,1,0.5})
		for a, die in pairs(getObjectFromGUID(GUID.zone.mana).getObjects()) do
			if die.getName()=="Mana Dice" then
				die.randomize()
			end
		end
	end, 5)

	--Rampage defeated sites
	if gStates.rampage>=1 then
		broadcastToAll("{en}Rampaging Tokens have been Replenished{ru}Клетки с яростными врагами получили новые жетоны{zh-cn}肆虐怪物标记已经补充{ko}광분하는 적 토큰이 보충되었습니다.{es}Se han reabastecido las fichas violentas.{fr}Les jetons déchaînés ont été réapprovisionnés{pt-br}Fichas Irascíveis foram Reabastecidas{de}Zornige Spielsteine wurden aufgefüllt", {1,1,0.5})
		local northBearing=40
		local startTileGUID=gStates.gameScenario=="Against the Horsemen Blitz" and GUID.tile.country01 or startTerrain.open
		if getObjectFromGUID(startTileGUID)==nil and gStates.gameScenario~="Against the Horsemen Blitz" then startTileGUID=startTerrain.wedge northBearing=70 end
		local startBearing=0
		for a, terrain in pairs(getObjectFromGUID(mapArea).getObjects()) do
			--Find terrain with rampaging or draconum
			if terrainTiles[terrain.guid]~=nil then
				if terrain.is_face_down==false then--check if terrain is face up
					for hexLocation, hexFeature in pairs(terrainTiles[terrain.guid].hexFeature) do
						if hexFeature=="rampaging" or hexFeature=="draconum" then
							startBearing=math.deg(math.atan2(terrain.getPosition()[3]-getObjectFromGUID(startTileGUID).getPosition()[3], terrain.getPosition()[1]-getObjectFromGUID(startTileGUID).getPosition()[1]))
							playRampagingTokens(terrain, startBearing, northBearing, hexLocation, hexFeature, false)
						end
					end
				end
			end
		end
	end

	--Update Dummy Player
	safeWaitTime("Turn",function()
		if gStates.positionMageKnight[5]~="nobody" and gStates.positionMageKnight[5]~="Volkare" then
			--Put advanced action in dummy deck
			broadcastToAll(proxyPlayerActive()==true and "{en}Proxy Collected The First Advanced Action Card{ru}Прокси получил первую карту Продвинутого действия{zh-cn}代理玩家拿到了第一张高级行动卡{ko}프록시가 첫 번째 상급 액션 카드를 가져갔습니다{es}Proxy consiguió la primera carta de Acción Avanzada.{fr}Le Proxy a récupéré la première carte d’Action Avancée{pt-br}Proxy pegou a primeira Carta de Ação Avançada{de}Proxy hat die erste Fortgeschrittene Aktionskarte genommen" or "{en}Dummy Collected The First Advance Action Card{ru}Нижняя карта из доступных Особых действий, добавлена в колоду деяний виртуального игрока{zh-cn}虚拟玩家拿到了第一张行动卡{ko}마지막 상급 액션이 가상 플레이어 더미에 추가되었습니다{es}El muñeco ha conseguido la Primera carta de Acción Avanzada.{fr}Mannequin a récupéré la Première carte d'Action Avancée{pt-br}Jog. Fictício Clamou a primeira Carta de Ação{de}Dummy hat die erste Vorstoß-Aktionskarte gesammelt", {1,1,0.5})
			local objCard=getObjectFromGUID(GUID.zone.actionOffer).getObjects()
			for i=1, #objCard, 1 do
				if objCard[i].type=="Card" then
					getObjectFromGUID(objCard[i].guid).unlock()
					getObjectFromGUID(objCard[i].guid).setRotationSmooth({0,180,180})
					getObjectFromGUID(objCard[i].guid).setPositionSmooth({getObjectFromGUID(dummyBoard).getPosition()[1]+4.5, 1.17, getObjectFromGUID(dummyBoard).getPosition()[3]-5.2})
					break
				end
			end
			--Put spell colored crystal in the automated player's inventory. A damaged/empty Spell offer
			--must not leave obj pointing at a mana bag and then try to count the bag as a crystal.
			local spellColor=""--read information from the card in the first spell position
			for _, card in pairs(getObjectFromGUID(GUID.zone.spellOffer).getObjects()) do
				if card.type=="Card" then spellColor=card.getDescription() break end
			end
			if spellColor=="Red" or spellColor=="Blue" or spellColor=="Green" or spellColor=="White" then
				broadcastToAll(joinLang({proxyPlayerActive()==true and "{en}Proxy added a {ru}Прокси получил {zh-cn}代理玩家添加了一个{ko}프록시 저장 칸에 {es}Proxy agregó un cristal de maná {fr}Le Proxy a ajouté un cristal de mana {pt-br}Proxy adicionou um(a) {de}Der Proxy hat einen " or "{en}Dummy added a {ru}Виртуальный игрок получил {zh-cn}虚拟玩家添加了一个{ko}가상 플레이어 저장 칸에 {es}Dummy agregó un cristal de maná {fr}Le mannequin a ajouté un cristal de mana {pt-br}Jog. Fictício adicionou um(a) {de}Die Puppe hat einen ", translateWord[spellColor], "{en} mana crystal to its inventory.{ru} кристалл маны{zh-cn}魔晶到他的装备区. {ko}수정을 추가했습니다{es} a su inventario.{fr} à son inventaire.{pt-br} Cristal de Mana para seu inventário.{de} manakristall in sein Inventar aufgenommen."}), {1,1,0.5})
				local params={position={0, 1.65, 0}, rotation={0, 30, 0}, smooth=false}
				local obj=nil
				local crystalsPerRow=3
				if gStates.rounds>6 then crystalsPerRow=4 end
				if gStates.rounds>8 then crystalsPerRow=5 end
				params.position[1]=getObjectFromGUID(dummyBoard).getPosition()[1]-2.0+((3.4/(crystalsPerRow-1))*(gStates.currentRound-2))-(((3.4/(crystalsPerRow-1))*crystalsPerRow)*math.floor((gStates.currentRound-2)/crystalsPerRow))
				params.position[3]=getObjectFromGUID(dummyBoard).getPosition()[3]+0.3-(1.2*math.floor((gStates.currentRound-2)/crystalsPerRow))
				if spellColor=="Red" then obj=takeManaCrystal(getObjectFromGUID(GUID.bag.mana.red),params) end
				if spellColor=="Blue" then obj=takeManaCrystal(getObjectFromGUID(GUID.bag.mana.blue),params) end
				if spellColor=="Green" then obj=takeManaCrystal(getObjectFromGUID(GUID.bag.mana.green),params) end
				if spellColor=="White" then obj=takeManaCrystal(getObjectFromGUID(GUID.bag.mana.white),params) end
				if obj~=nil then
					obj.lock()
					for a=1, #turnOrder, 1 do
						if turnOrder[a].mage==gStates.positionMageKnight[5] then
							local b=obj.getDescription()
							if turnOrder[a].dummyCrystals[b]==nil then turnOrder[a].dummyCrystals[b]=0 end
							turnOrder[a].dummyCrystals[b]=turnOrder[a].dummyCrystals[b]+1
							break
						end
					end
				end
			else
				broadcastToAll("Automated player found no valid Spell card during round preparation; no crystal was added.",{1,0.65,0.2})
			end
		else
			--Discards an Advance Action
			local MainDeck=getObjectFromGUID(GUID.zone.actionDeck).getObjects()
			local discard=getObjectFromGUID(GUID.zone.actionOffer).getObjects()
			if discard[1]~=nil and MainDeck[1]~=nil then
				discard[1].unlock()
				standardDeckCycleMarkReturned("Advanced Action", discard[1])
				MainDeck[1].putObject(discard[1])
			end
		end
		--Discards the last Spell
		local MainDeck=getObjectFromGUID(GUID.zone.spellDeck).getObjects()
		local discard=getObjectFromGUID(GUID.zone.spellOffer).getObjects()
		if discard[1]~=nil and MainDeck[1]~=nil then
			discard[1].unlock()
			standardDeckCycleMarkReturned("Spell", discard[1])
			MainDeck[1].putObject(discard[1])
		end

		--Fury delays Elite Units until exploration reaches a City or a Hero has entered one.
		if furyDragonPrepareEliteUnits~=nil then furyDragonPrepareEliteUnits() end

		--Turn on advanced units for last half of game in "Conquer and Hold"
		if gStates.currentRound > gStates.rounds/2 and gStates.gameScenario=="Conquer and Hold" then
			gStates.eliteUnitsUsed=true
			broadcastToAll("{en}Elite Units are included in the next Offer{zh-cn}精英部队包含在下个供应区{ko}다음 라운드부터 엘리트 유닛이 추가됩니다{es}Las Unidades Elite están incluidas en la próxima Oferta{fr}Les unités Elite sont incluses dans la prochaine Offre{pt-br}Unidades Elite estão incluídas na próxima oferta", {1,1,0.5})
		end

		--Cycle all the offers
		safeWaitTime("Turn",function()
			broadcastToAll("{en}Unit Offer Refreshed{ru}Доступные отряды обновлены{zh-cn}部队供应区刷新了{ko}유닛 공급처가 갱신되었습니다{es}Oferta de Unidad Actualizada{fr}Offre Unitaire Rafraîchie{pt-br}Oferta de Unidades Atualizadas{de}Einheitenangebot aufgefrischt", {1,1,0.5})
			broadcastToAll("{en}Advanced Actions and Spells cycled.{ru}Особые действия и Заклинания обновлены.{zh-cn}高级动作卡和法术卡供应区更新了{ko}상급 액션과 마법 카드 공급처가 갱신되었습니다.{es}Acciones Avanzadas y Hechizos ciclados.{fr}Actions Avancées et Sorts cyclés.{pt-br}Ações Avançadas e Feitiços reciclados.{de}Fortgeschrittene Aktionen und Zaubersprüche gewirkt.", {1,1,0.5})
			broadcastToAll("-------------------", {1,1,0.5})
			unitOffer()
			fillSlide()
		end, 1)
	end, 1)

	--Flip all skills
	broadcastToAll("{en}All Mage Knight Skills Reset{ru}Жетоны навыков снова готовы к использованию{zh-cn}所有魔法骑士的技能重置{ko}모든 스킬이 리셋 되었습니다{es}Restablecimiento de Todas las Habilidades de Mage Knight{fr}Réinitialisation de Toutes les Compétences de Mage Knight{pt-br}Todas as Hab. de MK Redefinidas{de}Alle Magier-Ritter-Fähigkeiten zurückgesetzt", {1,1,0.5})
	for skillGUID, skillDetails in pairs(skillTokens) do
		if getObjectFromGUID(skillGUID)~=nil then getObjectFromGUID(skillGUID).setRotationSmooth({0.0, 180.0, 0.0}) end
	end
	--Update Motivation Skills status
	for a, stats in pairs(gStates.motivationSkill) do
		if stats.state~="notClaimed" then stats.state="active" end
	end
	--Reset Coop and Comp Skills, including any that were illegally played after the previous round ended.
	for skillGUID, details in pairs(gStates.doingTheRounds) do
		doingTheRounds(skillGUID, "", 0, true)
	end
	for skillGUID, _ in pairs(gStates.competitiveSkillReminders or {}) do clearCompetitiveSkillReminders(skillGUID) end
	gStates.coopCompSkillPaused={}
	gStates.coopCompSkillLegalThisRound={}
	gStates.coopCompSkillActivation={}
	gStates.tomeSkillSwapPending={}

	--Ready all units
	broadcastToAll ("{en}All Units are Ready for combat again{ru}Все отряды готовы к бою{zh-cn}所有部队准备好再次迎战了{ko}유닛이 다시 전투할 준비가 되었습니다{es}Todas las unidades están listas para el combate de nuevo.{fr}Toutes les unités sont à nouveau prêtes pour le combat{pt-br}Todas Unidades estão prontas para combater novamente{de}Alle Einheiten sind wieder bereit für den Kampf", {1,1,0.5})
	local commandTokens={"12e399", "87cff0", "7a2083", "4af106", "ab5b0d", "88f6c1",--Braevalar Command
						 "07eec8", "d9f39d", "ea80e4", "dbc3f1", "442ad5", "4aa025",--Krang command
						 "a0f780", "47d922", "a8f242", "d960d3", "493833", "6bfe5b",--Ymirgh command
						 "104cff", "20a938", "2c51b2", "519062", "31e29d", "ab61c0",--Arythea command
						 "a345a3", "77dd3d", "c53d0a", "d55244", "4c1c1b", "2eb846",--Norowas command
						 "c5b17e", "7c0270", "4ea3a1", "4bbe27", "867634", "0162e7",--Goldyx command
						 "aa0a9d", "fa99cf", "10295b", "92bd25", "7e91b7", "7e6c4f",--Tovak command
						 "07661c", "bf879c", "6b7e70", "439a0a", "fb74bd", "361a24",--Wolfhawk command
						 "005290", "10feb1", "ff9201", "af501e", "cc32e5", "2b6131",--Coral command
						 "22a7bb", "bb619e", "6688df", "2a2da1", "f3f02c", "8e1952",--Jormund command
						 "fbf2cb", "405221", "787513", "2e1d38", "832228", "4b661b",--Malek command
						 "f30dd4"}--Norowas Skill is also a command token
	for _, commandGUID in pairs (commandTokens) do
		if getObjectFromGUID(commandGUID)~=nil then
			local token=getObjectFromGUID(commandGUID)
			if commandGUID~="f30dd4" or (commandGUID=="f30dd4" and token.getPosition()[3]<-25) then token.setPosition({token.getPosition()[1],token.getPosition()[2],-31.19}) end
		end
	end

	--Flip banner Cards
	for _, bannerGUID in pairs({"596cfa", "986216", "0b5b32", "e48e44", "8dbce4", "8e4b92", "75a627"}) do
		if getObjectFromGUID(bannerGUID)~=nil then getObjectFromGUID(bannerGUID).setRotationSmooth({0, 180, 0}) end
	end
	if getObjectFromGUID("8dbce4")~=nil then
		safeWaitFrames("Turn",function() safeWaitCondition("Turn",function()
			bannerOfCommandDecal()
		end, function() return getObjectFromGUID("8dbce4").resting end) end, 10)
	end

	--Move any player claimed Magic familiars down to indicate they need a new crystal
	local magicFamiliars={"d8e49b", "0a2e0b"}
	local blurbed=false
	for _, magicFamiliarGUID in pairs(magicFamiliars) do
		if getObjectFromGUID(magicFamiliarGUID)~=nil and getObjectFromGUID(magicFamiliarGUID).getPosition()[3]<-30 then
			local pos=getObjectFromGUID(magicFamiliarGUID).getPosition()
			getObjectFromGUID(magicFamiliarGUID).setPositionSmooth({pos[1], pos[2], pos[3]-3})
			if blurbed==false then broadcastToAll("{en}Magic Familiars are looking for more Mana to sustain them.{ru}Магические фамильяры жаждут ману для поддержания своей жизни.{zh-cn}法师们正在寻找更多的法力来供能他们。 {ko}마법 패밀리어가 힘을 유지하기 위한 마나를 요구합니다.{es}Los Familiares Mágicos buscan más Maná para sustentarlos.{fr}Les Familiers Magiques recherchent plus de Mana pour les soutenir.{pt-br}Familiares Mágicos estão procurando por mais Mana para sustentá-los.{de}Magische Vertraute suchen nach mehr Mana, um sie zu unterstützen.", {1,1,0.5}) blurbed=true end
		end
	end

	--Shuffle all discarded player decks and loose cards back to starting position and remove Magic Familiar Crystals
	for _, playerDetails in pairs(turnOrder) do
		--Volkare does not reset his deck
		if playerDetails.dropoutState==nil and getObjectFromGUID(deedDeckDiscardZones[playerDetails.seatPos])~=nil and playerDetails.mage~="Volkare" then
			local newDeck=nil
			local test=0
			for _, obj in pairs(getObjectFromGUID(deedDeckDiscardZones[playerDetails.seatPos]).getObjects()) do
				if obj.type=="Deck" then
					newDeck=obj
					newDeck.setRotationSmooth({0.0, 180.0, 180.0})
					newDeck.setPosition({getObjectFromGUID(deedDeckZones[playerDetails.seatPos]).getPosition()[1], 1.2, getObjectFromGUID(deedDeckZones[playerDetails.seatPos]).getPosition()[3]})
					test=1
					break
				end
			end
			--If testing (or cheating) their won't be a discard pile, so assign the normal deck as the destination for loose cards
			if test==0 then
				for _, obj in pairs(getObjectFromGUID(deedDeckZones[playerDetails.seatPos]).getObjects()) do
					if obj.type=="Deck" then
						newDeck=obj
						break
					end
				end
			end
			--remove crystals from unit area likely for magic familiars
			for _, obj in pairs(getObjectFromGUID(playerUnitAreas[playerDetails.seatPos]).getObjects()) do
				if obj.type=="Figurine" and obj.getGMNotes()~="Unit Wound" then getObjectFromGUID(trashCan).putObject(obj) end
			end

			--remove shields from glades in druid nights scenario
			if gStates.currentRound==3 or gStates.currentRound==5 or gStates.currentRound==7 then
				for _, shieldGuid in pairs(playerDetails.gladesMarked) do
					if getObjectFromGUID(shieldGuid)~=nil then
						getObjectFromGUID(shieldGuid).unlock()
						getObjectFromGUID(trashCan).putObject(getObjectFromGUID(shieldGuid))
					end
				end
				playerDetails.gladesMarked={}
			end

			--pull all the cards recorded as part of that players hand back to the floating deed deck, then it will fall into any existing cards
			for _, playerCard in pairs(playerDetails.deadDeckInventory) do
				if getObjectFromGUID(playerCard)~=nil then
					if ((gameCards[playerCard]~=nil and gameCards[playerCard].full==nil) or
						getObjectFromGUID(playerCard).getGMNotes()=="Wound") and newDeck~=nil then
						newDeck.putObject(getObjectFromGUID(playerCard))
					end
				end
			end
		end
	end
	broadcastToAll ("{en}Deed Decks reset and shuffled{ru}Колоды деяний собраны и перетасованы{zh-cn}功能牌区重置并洗牌{ko}카드 더미를 셔플했습니다{es}Deed Decks reiniciados y barajados{fr}Deed Decks réinitialisés et mélangés{pt-br}Baralhos de Façanhas reiniciados e embaralhados{de}Deed Decks werden zurückgesetzt und neu gemischt", {1,1,0.5})

	--Work out new tactics picking order
	table.sort(turnOrder, function (k1, k2) return k1.fame < k2.fame end)
	for a=1, #turnOrder-1, 1 do
		if turnOrder[a].fame==turnOrder[a+1].fame and turnOrder[a].tactic<turnOrder[a+1].tactic then
		 	local temp=turnOrder[a]
			turnOrder[a]=turnOrder[a+1]
			turnOrder[a+1]=temp
		end
	end
	gStates.turnNumber=1
	for a=1, #turnOrder, 1 do if playerDropoutInactive(a)==false then gStates.turnNumber=a break end end
	gStates.realTurn=gStates.turnNumber
	applyColorBarButtons()
	broadcastToAll(joinLang({"{en}It is now {ru}Ходит {zh-cn}现在是{ko}{es}Ahora es el turno de {fr}C'est maintenant au tour de {pt-br}é agora turno de {de}Jetzt ist ", translateWord[turnOrder[gStates.turnNumber].mage], "{en}'s turn.{ru} {zh-cn}的回合{ko}의 차례입니다.{es}.{fr}.{pt-br}.{de} an der Reihe."}), positionToColor(gStates.turnNumber))
	gStates.tacticTwoState="notUsed"
	gStates.tacticFourState="notUsed"
	gStates.tacticSixState="notClaimed"
	gStates.timeBending="notUsed"
	gStates.endRoundCalled=false
	clearFinalTurnBoundary()
	for _, details in pairs(turnOrder) do details.endCalled=false end
	refreshCoopCompSkillXs()

	--Lay out tactics for removal
	safeWaitFrames("Turn",function()
		--No tactics removed Scenarios
		if gStates.darknessComing==true or gStates.discardTactics==0 or gStates.currentRound>gStates.rounds-1 then
			tacticToggle()
		else
			--Remove the player's tactic Scenarios
			gStates.tacticRemove=true
			local d=1
			for a=1, 6, 1 do
				for b=1, #turnOrder, 1 do
					local c=0
					if gStates.dayRound==true then c=6 end
					if turnOrder[b].tactic==a and ((turnOrder[b].mage~=gStates.positionMageKnight[5] and gStates.discardTactics==1) or gStates.discardTactics==2) then
						getObjectFromGUID(tacticCard[turnOrder[b].tactic+c]).setRotation({0.0, 180.0, 0.0})
						getObjectFromGUID(tacticCard[turnOrder[b].tactic+c]).setPosition({-12.50+(4*d), 1.5, -14.00})
						getObjectFromGUID(tacticCard[turnOrder[b].tactic+c]).lock()
						d=d+1
						break
					end
					if turnOrder[b].tactic==a and turnOrder[b].mage==gStates.positionMageKnight[5] then
						local depth=-8
						if gStates.dayRound==true then depth=-4 end
						getObjectFromGUID(tacticCard[turnOrder[b].tactic+c]).setPosition({-16.50+(4*a), depth, -14.00})
						getObjectFromGUID(tacticCard[turnOrder[b].tactic+c]).lock()
					end
				end
			end
			claimButtonRefresh()
		end
	end, 20)--long enough for dice collision on mana steal to complete

	--shuffles, deals cards
	safeWaitTime("Turn",function()
		--shuffle and scale decks down for more room
		for a=1, #turnOrder, 1 do
			if getObjectFromGUID(deedDeckZones[turnOrder[a].seatPos])~=nil and turnOrder[a].mage~="Volkare" then
				for _, obj in pairs(getObjectFromGUID(deedDeckZones[turnOrder[a].seatPos]).getObjects()) do
					if obj.type=="Deck" then
						obj.shuffle()
						break
					end
				end
			end
		end
		--After shuffling, force Quick Witted back to the bottom of Coral's Deed Deck.
		coralSetAsideQuickWitted()

		--deal once Quick Witted is definitely back inside Coral's Deed Deck.
		safeWaitCondition("Turn",function()
			dealAllHands()
			safeWaitTime("Turn",function()
				--Records current amount of cards in deed deck
				for a=1, #turnOrder, 1 do
					turnOrder[a].deedCount=0
					for _, b in pairs(getObjectFromGUID(deedDeckZones[turnOrder[a].seatPos]).getObjects()) do
						if b.type=="Card" then turnOrder[a].deedCount=1 break end
						if b.type=="Deck" then turnOrder[a].deedCount=b.getQuantity() break end
					end
				end
				gStates.endRoundResetPending=false
				rewindTransactionFinish("End of round")
			end, 1)
		end, function() return coralQuickWittedReadyForDraw() end)
	end, 2)

	--set discards count to 0
	for a, b in pairs(turnOrder) do	b.discardCount=0 end

	--Stops the button on last round
	if gStates.currentRound==gStates.rounds then broadcastToAll("{en}Final Round{ru}Последний Раунд{zh-cn}最终回合{ko}마지막 라운드{es}Ronda Final{fr}Tour Final{pt-br}Rodada Final{de}Letzte Runde", {1,1,0.5}) end
end

function dayNight()
	--Swith day night board
	local tileColor={}
	if gStates.dayRound==false then
		tileColor={r=1.0, g=1.0, b=1.0}
		local nightObject={"43fa2e", "0f95b7", "9e7de3", "ee9e66", "717bcc", "39ca3f", GUID.deck.nightWeather}
					--Day Board, 5 Weather Tokens, weather deck
		broadcastToAll("{en}Day has Risen{ru}Наступает день{zh-cn}天亮了{ko}아침이 밝았습니다{es}El Día ha Resucitado{fr}Le Jour s'est Levé{pt-br}A Manhã Chegou{de}Der Tag ist auferstanden", {1,1,0.5})
		for i=1, #nightObject, 1 do
			if getObjectFromGUID(nightObject[i])~=nil then getObjectFromGUID(nightObject[i]).setState(1) end
		end
		local ruinPugs={"2721c8", "3ac2d6", "3ae05e", "8ca894", "f3c6e3", "2f9a1f", "0e09cf", "a59f0b", "40fd40", "f172a4", "28cc9c", "58c5ab", "1e5666", "09a519", "21dc40"}
					--Day Board, 5 Weather Tokens, weather deck
		local found=false
		for _, ruinGUID in pairs(ruinPugs) do
			if getObjectFromGUID(ruinGUID)~=nil and getObjectFromGUID(ruinGUID).is_face_down==true then getObjectFromGUID(ruinGUID).flip() found=true end
		end
		if found==true then broadcastToAll("{en}Ruins are revealed{ru}Все руины были раскрыты{zh-cn}废墟被探索了{ko}유적 공개됨{es}Las Ruinas se Revelan{fr}Les Ruines sont Révélées{pt-br}Ruinas são Reveladas{de}Ruinen werden aufgedeckt", {1,1,0.5}) end
		safeWaitFrames("Turn",function()
			if getObjectFromGUID(GUID.deck.dayWeather)~=nil then getObjectFromGUID(GUID.deck.dayWeather).shuffle() end
			if getObjectFromGUID("a02b0f")~=nil then getObjectFromGUID("a02b0f").interactable=false end
		end, 5)--shuffle day weather
		gStates.dayRound=true
		gStates.nightTint=false
		gStates.moveCost["forest"]=3
		gStates.moveCost["desert"]=5
		UI.setAttribute("MoveCostDeserText", "text", "Deserts : 5")
		UI.setAttribute("MoveCostForesText", "text", "Forests : 3")
		fakeDropAvatar()
	else
		tileColor={r=0.6, g=0.6, b=0.6}
		local dayObject={"a02b0f", GUID.bag.weather.blazingSun, GUID.bag.weather.overcast, GUID.bag.weather.snowfall, GUID.bag.weather.rain, GUID.bag.weather.thunder, GUID.deck.dayWeather}
					--Day Board, 5 Weather Tokens, weather deck
		broadcastToAll("{en}Night has Fallen{ru}Наступает ночь{zh-cn}黑夜降临了{ko}밤이 되었습니다{es}La Noche ha Caído{fr}La Nuit est Tombée{pt-br}A Noite Caiu{de}Die Nacht ist hereingebrochen", {1,1,0.5})
		for i=1, #dayObject, 1 do
			if getObjectFromGUID(dayObject[i])~=nil then getObjectFromGUID(dayObject[i]).setState(2) end
		end
		safeWaitFrames("Turn",function()
			if getObjectFromGUID(GUID.deck.nightWeather)~=nil then getObjectFromGUID(GUID.deck.nightWeather).shuffle() end
			if getObjectFromGUID("43fa2e")~=nil then
				getObjectFromGUID("43fa2e").UI.setXmlTable({{tag="Button", attributes={id="43fa2eNightTint", active="true", onMouseDown="global/buttonClicked", onMouseUp="global/buttonClicked", onClick="global/nightTint", height="150", width="500", color="rgba(0,0,0,0.0)", position="70 -110 -6", rotation="0 0 180", scale="0.16 0.16"},
					children={	{tag="Image",  attributes={id="43fa2eNightTintImage", image="Sliced Button/Button Object Active", type="Sliced"}},
				    			{tag="Text",  attributes={id="43fa2eNightTintText", font="Fonts/MKCardText", fontSize="90", color="black", fontStyle="Normal", alignment="MiddleCenter", text="No Tint"}}}}})
				getObjectFromGUID("43fa2e").interactable=false
			end
		end, 5)--shuffle night weather
		gStates.dayRound=false
		gStates.nightTint=true
		gStates.moveCost["forest"]=5
		gStates.moveCost["desert"]=3
		UI.setAttribute("MoveCostDeserText", "text", "Deserts : 3")
		UI.setAttribute("MoveCostForesText", "text", "Forests : 5")
	end

	--Make terrain tile light or dark
	for a, _ in pairs(terrainTiles) do
		local obj=getObjectFromGUID(a)
		if obj~=nil then obj.setColorTint(tileColor) end
	end
	--re tints red terrain tiles on predefined maps.
	if gStates.mapShape:sub(5,5)=="P" and gStates.gameScenario~="The Gauntlet" and gStates.gameScenario~="Against the Horsemen Blitz" then
		local terrainDummy=getObjectFromGUID(startTerrain.open)
		if terrainDummy==nil then terrainDummy=getObjectFromGUID(startTerrain.wedge) end
		onObjectEnterZone({guid=mapArea}, terrainDummy)
	end
end

function removeTactic(player, mouseButton, id)
	if mouseButton=="-1" then
		local testTactic=id:sub(1, 6)
		if id:sub(7,string.len(id))=="removeTactic5" then
			for b=1, 6, 1 do
				for _, obj in pairs(getObjectFromGUID(tacticZones[b]).getObjects()) do
					if isTacticCard(obj) then
						getObjectFromGUID(trashCan).putObject(obj)
						testTactic=obj.guid
						break
					end
				end
			end
		else
			getObjectFromGUID(trashCan).putObject(getObjectFromGUID(testTactic))
		end
		gStates.tacticRemove=false
		safeWaitCondition("Turn",function() tacticToggle() end, function() return getObjectFromGUID(testTactic)==nil end)
	end
end


--Day Tactic 2 is fully Global-owned. The physical tactic card only hosts this XML-style button.
--Use the tactic card's actual board position to identify its owner. During tactic selection,
--turnOrder can temporarily contain duplicate tactic numbers until everybody has chosen.
function dayTactic2Owner()
	local tactic=getObjectFromGUID("a000a4")
	if tactic==nil or gStates.dayRound~=true or gStates.tacticRemove==true then return nil, nil end
	local tacticPos=tactic.getPosition()
	if tacticPos[3]>=-15 then return nil, nil end
	local seatPos=math.ceil((tacticPos[1]+78)/40)
	for a=1, #turnOrder, 1 do
		if turnOrder[a].seatPos==seatPos and turnOrder[a].tactic==2 and turnOrder[a].mage~=gStates.positionMageKnight[5] then return a, seatPos end
	end
	return nil, nil
end

function dayTactic2ButtonActivate()
	local tactic=getObjectFromGUID("a000a4")
	if tactic==nil then return end
	--While the card is still in the tactic offer, leave its normal claim/remove UI alone.
	--Once it has reached its owner's board, Rethink can be available immediately even while
	--other players are still choosing tactics.
	local ownerIndex=dayTactic2Owner()
	if ownerIndex==nil then
		return
	end
	tactic.UI.setXmlTable({{}})
	safeWaitFrames("Turn",function()
		local card=getObjectFromGUID("a000a4")
		local currentOwner=dayTactic2Owner()
		if card==nil or currentOwner==nil then return end
		if cardEffectIsVertical(card)==true and gStates.tacticTwoState~="Used" then
			local scale=0.32*0.6521739130434783
			local text="{en}Day Tactic 2\nClick after Card(s) have been discarded{ru}Тактика дня 2\nЩелкните после сброса карт{zh-cn}白天战术卡2\n弃牌后单击此处{ko}낮 전략 2\n버릴 카드를 놓고 클릭하세요.{es}Táctica del día 2\nHaz clic después de descartar carta(s){fr}Tactique de Jour 2\nCliquez après avoir défaussé la/les carte(s){pt-br}Tática do Dia 2\nClique depois de descartar a(s) carta(s){de}Tagestaktik 2\nNach dem Abwerfen der Karte(n) klicken"
			card.UI.setXmlTable({{tag="Button", attributes={id="a000a4DayTactic2Discard", onClick="global/dayTactic2Discarded", onMouseDown="global/buttonClicked", onMouseUp="global/buttonClicked", height="300", width="650", position="-317 -140 -1", rotation="0 0 180", scale=tostring(scale).." "..tostring(scale)},
				children={{tag="Image", attributes={id="a000a4DayTactic2DiscardImage", image="Sliced Button/Button Object Active", type="Sliced"}},
					{tag="HorizontalLayout", attributes={padding="20 20 20 20"}, children={{tag="Text", attributes={id="a000a4DayTactic2DiscardText", font="Fonts/MKCardText", fontSize="65", fontStyle="Normal", alignment="MiddleCenter", resizeTextForBestFit="true", resizeTextMaxSize="65", text=text}}}}}}})
		end
	end, 10)
end

function dayTactic2SetUsed()
	if gStates.tacticTwoState=="Used" then return end
	gStates.tacticTwoState="Used"
	local tactic=getObjectFromGUID("a000a4")
	if tactic~=nil and tactic.is_face_down==false then tactic.flip() end
	dayTactic2ButtonActivate()
end

--Rethink is only available before its owner has played a card. This is deliberately based on
--the tactic owner's play area, not the active turn, so the tactic can be used during another
--player's turn.
function dayTactic2ExpireIfCardPlayed(seatPos)
	if gStates.tacticTwoState=="Used" then return end
	local ownerIndex, ownerSeat=dayTactic2Owner()
	if ownerIndex==nil or ownerSeat~=seatPos then return end
	local cardCount=cachedPlayAreaCounts(ownerSeat)
	if cardCount<1 then return end
	dayTactic2SetUsed()
end

--Give replacement cards for Day Tactic 2, then shuffle the discarded cards back into the Deed Deck.
function dayTactic2Discarded(player, mouseButton, id)
	if mouseButton~="-1" or player==nil then return end
	local tactic=getObjectFromGUID("a000a4")
	if tactic==nil then return end
	if gStates.tacticTwoState=="Used" then dayTactic2ButtonActivate() return end
	local playerColor=player.color
	local playerPosition=math.ceil((tactic.getPosition()[1]+78)/40)
	if Player[playerColor]~=nil and Player[playerColor].seated==true and playerColor~="Black" and Player[playerColor].getHandTransform()~=nil then playerPosition=math.ceil((Player[playerColor].getHandTransform().position[1]+97.59)/40) end
	local tacticPosition=math.ceil((tactic.getPosition()[1]+78)/40)
	if playerPosition~=tacticPosition then broadcastToAll("That's not for you to decide", warningColor) return end
	local playerIndex=nil
	local playerMage=nil
	for a, details in pairs(turnOrder) do if details.seatPos==playerPosition then playerIndex=a playerMage=details.mage break end end
	if playerIndex==nil or turnOrder[playerIndex].tactic~=2 then return end

	--Clean that player's play area in case cards were discarded there instead of directly onto the discard pile.
	local cardDestination=nil
	local waitTime=0
	for _, playAreaObj in pairs(getObjectFromGUID(playerPlayAreas[playerPosition]).getObjects()) do
		if playAreaObj.tag=="Card" then
			local found=false
			for _, bannerGUID in pairs({"596cfa", "986216", "0b5b32", "e48e44", "8dbce4", "8e4b92", "75a627"}) do if playAreaObj.guid==bannerGUID then found=true break end end
			if playAreaObj.getDescription()=="Quest" then found=true end
			if found==false then
				waitTime=1
				if cardDestination==nil then
					playAreaObj.setRotation({0,180,0})
					playAreaObj.setPosition({(playerPosition*40)-110.32, 1.12, -43.20})
					cardDestination=playAreaObj
				else
					playAreaObj.setPosition({playAreaObj.getPosition()[1], 1.9, playAreaObj.getPosition()[3]})
					cardDestination=cardDestination.putObject(playAreaObj)
				end
			end
		end
	end

	safeWaitTime("Turn",function()
		local discards=nil
		for _, possibleDiscards in pairs(getObjectFromGUID(deedDeckDiscardZones[playerPosition]).getObjects()) do
			if possibleDiscards.tag=="Deck" or possibleDiscards.tag=="Card" then discards=possibleDiscards break end
		end
		if discards==nil then return end
		local drawCount=discards.tag=="Deck" and discards.getQuantity() or 1
		if drawCount>3 then broadcastToAll("You have discarded too many cards", warningColor) return end
		--The use is committed once a valid discard pile has been found. Remove the button now
		--rather than leaving a second click available while the replacement draws are resolving.
		dayTactic2SetUsed()

		local function finishDayTactic2()
			local deedDeck=nil
			for _, possibleDeck in pairs(getObjectFromGUID(deedDeckZones[playerPosition]).getObjects()) do if possibleDeck.tag=="Deck" or possibleDeck.tag=="Card" then deedDeck=possibleDeck break end end
			if deedDeck~=nil then
				safeWaitTime("Turn",function()
					if deedDeck~=nil and discards~=nil then deedDeck.putObject(discards) end
					safeWaitTime("Turn",function()
						local currentDeck=nil
						for _, possibleDeck in pairs(getObjectFromGUID(deedDeckZones[playerPosition]).getObjects()) do if possibleDeck.tag=="Deck" then currentDeck=possibleDeck break end end
						if currentDeck~=nil then currentDeck.shuffle() end
						if playerMage=="Coral" then safeWaitTime("Turn",function() coralSetAsideQuickWitted() end, 0.5) end
					end, 1)
				end, 0.5)
			else
				local deckPos=getObjectFromGUID(deedDeckZones[playerPosition]).getPosition()
				discards.setRotation({0,180,180})
				discards.setPosition({deckPos[1],1.5,deckPos[3]})
				safeWaitTime("Turn",function()
					if discards~=nil and discards.tag=="Deck" then discards.shuffle() end
					if playerMage=="Coral" then safeWaitTime("Turn",function() coralSetAsideQuickWitted() end, 0.5) end
				end, 1)
			end
			mainUIUpdate("Day Tactic 2 Used")
		end

		if playerMage=="Coral" then
			coralExternalQuickWittedDraw({seatPos=playerPosition, count=drawCount, sourceId="DrawOne"})
			safeWaitCondition("Turn",function() safeWaitTime("Turn",finishDayTactic2, 0.5) end, function() return coralExternalDrawPending({seatPos=playerPosition})~=true end)
		else
			local deedDeck=nil
			for _, possibleDeck in pairs(getObjectFromGUID(deedDeckZones[playerPosition]).getObjects()) do if possibleDeck.tag=="Deck" or possibleDeck.tag=="Card" then deedDeck=possibleDeck break end end
			if deedDeck~=nil then
				if deedDeck.tag=="Deck" then for a=1, drawCount, 1 do deedDeck.takeObject({position={(playerPosition*40)-100-(a*0.2), 4.59, -47.55}, rotation={0,180,0}}) end
				elseif drawCount>0 then deedDeck.setPositionSmooth({(playerPosition*40)-100, 4.59, -47.55}) deedDeck.setRotationSmooth({0,180,0}) end
			end
			safeWaitTime("Turn",finishDayTactic2, 0.5)
		end
	end, waitTime)
end

function nightTactic2(player, mouseButton, id)
	if mouseButton=="-1" then
		if legalPlayerCheck(player.color, tonumber(id:sub(14,14)))==true then
			for a=1, #turnOrder, 1 do
				if turnOrder[a].seatPos==tonumber(id:sub(14,14)) then
					--Find Discard Deck
					for b, discards in pairs(getObjectFromGUID(deedDeckDiscardZones[turnOrder[a].seatPos]).getObjects()) do
						if discards.type=="Deck" then
							--shuffle discard
							discards.shuffle()
							--put three discards in deed deck
							safeWaitTime("Turn",function()
								local deckPos={-74.19+(40*(turnOrder[a].seatPos-1)), 1.50, -43.16}
								discards.takeObject({position=deckPos, smooth=true, rotation={0, 180, 180}})
								discards.takeObject({position=deckPos, smooth=true, rotation={0, 180, 180}})
								discards.takeObject({position=deckPos, smooth=true, rotation={0, 180, 180}})
							end, 0.5)
							break
						end
					end
					--stop from repeating
					gStates.tacticTwoState="Used"
					--flip over tactic
					if getObjectFromGUID("f6ad01").is_face_down==false then getObjectFromGUID("f6ad01").flip() end
					broadcastToAll(joinLang({translateWord[turnOrder[a].mage], "{en} used Tactic to refill Deed Deck with 3 Random discards{ru} использует Тактику 2 и кладет 3 карты из сброса в Колоду деяний{zh-cn}使用战术从弃牌堆中随机拿了3张手牌{ko}: 전략 카드 2 사용. 3장의 버려진 카드로 더미를 채웁니다.{es} usó Táctica para rellenar Deed Deck con 3 descartes aleatorios{fr} utilisé Tactic pour remplir Deed Deck avec 3 défausse aléatoires{pt-br} usou Tática para preencher o Baralho de Façanhas com 3 cartas aleatórias do Discarte.{de} taktik benutzt, um das Tatendeck mit 3 zufälligen Abwürfen aufzufüllen"}), positionToColor(a))
					mainUIUpdate("Night Tactic 2 Used")
					break
				end
			end
		end
	end
end

function nightTactic4(player, mouseButton, id)
	if mouseButton=="-1" then
		local playerPosition=tonumber(id:sub(14,14))
		if legalPlayerCheck(player.color, playerPosition)==true then
			for a=1, #turnOrder, 1 do
				if turnOrder[a].seatPos==playerPosition then
					--find positions deed deck
					local deedDeck=nil
					for b, possibleDeck in pairs(getObjectFromGUID(deedDeckZones[playerPosition]).getObjects()) do
						if possibleDeck.type=="Deck" or possibleDeck.type=="Card" then deedDeck=possibleDeck break end
					end
					--Shuffle Deed Deck
					if deedDeck~=nil then
						--Record the redraw amount before Quick Witted is temporarily removed/reinserted.
						local deckQuantity=deedDeck.type=="Deck" and deedDeck.getQuantity() or 1
						local redrawCount=math.max(0, deckQuantity-turnOrder[a].deedCount)
						deedDeck.shuffle()
						if turnOrder[a].mage=="Coral" then scheduleCoralQuickWittedBottom(5) end
						safeWaitTime("Turn",function()
							--Run one redraw request for the full amount. For Coral this opens the Quick Witted choice
							--with the correct remaining count and keeps the Draw Full button available.
							if redrawCount>0 then coralTactic4Draw(a, redrawCount) end
							--flip Tactic face down
							if getObjectFromGUID("db7aaa").is_face_down==false then getObjectFromGUID("db7aaa").flip() end
							--Update states and buttons
							gStates.tacticFourState="Used"
							broadcastToAll(joinLang({translateWord[turnOrder[a].mage], "{en} used Tactic 4 to redraw hand{ru} использует Тактику 4 для добора{zh-cn}使用战术4重抽手牌{ko}: 전략 카드 4 사용. 카드를 다시 뽑습니다. {es} usé la Táctica 4 para volver a dibujar la mano{fr} utilisé Tactic 4 pour redessiner la main{pt-br} usou a Tática 4 para re-comprar mão.{de} taktik 4 verwendet, um die Hand neu zu ziehen"}), positionToColor(a))
							mainUIUpdate("night Tactic 4 Used")
						end, 1)
					end
				end
			end
		end
	end
end

--Claim Night Tactic 6 cards from the GUIDs recorded when they were stored. Stored cards may
--be loose or may have merged into a Deck, so resolve one GUID at a time and reacquire its container.
local function claimNightTactic6StoredCards(seatPos, callback)
	local storedGUIDs={}
	for _, stored in ipairs(gStates.powerStored or {}) do if stored.guid~=nil then storedGUIDs[#storedGUIDs+1]=stored.guid end end
	local destination={(seatPos*40)-100, 4.59, -47.55}
	local failed={}
	local function moveCard(card, index)
		card.setPosition({destination[1]+((index-1)*0.15), destination[2], destination[3]})
		card.setRotation({0, 180, 0})
	end
	local function resolve(index)
		if index>#storedGUIDs then if callback~=nil then callback(failed) end return end
		local guid=storedGUIDs[index]
		local card=getObjectFromGUID(guid)
		if card~=nil and card.type=="Card" then
			moveCard(card, index)
			safeWaitFrames("Turn",function() resolve(index+1) end, 1)
			return
		end

		--A stored pile can become a Deck. Find the current Deck containing this exact GUID.
		for _, object in pairs(getObjects()) do
			if object.type=="Deck" then
				for _, cardData in pairs(object.getObjects()) do
					if cardData.guid==guid then
						safeTakeObject("Turn",object,{guid=guid, position={destination[1]+((index-1)*0.15), destination[2], destination[3]}, rotation={0,180,0}, smooth=false, callback_function=function(taken)
							moveCard(taken, index)
							safeWaitFrames("Turn",function() resolve(index+1) end, 1)
						end})
						return
					end
				end
			end
		end
		failed[#failed+1]=guid
		resolve(index+1)
	end
	resolve(1)
end

function nightTactic6(player, mouseButton, id)
	if mouseButton=="-1" then
		if legalPlayerCheck(player.color, tonumber(id:sub(18,18)))==true then
			if id:sub(1,17)=="NightTactic6Store" then
				local tactic=getObjectFromGUID("e2af14")
				local seatPos=tonumber(id:sub(18,18)) or math.ceil((tactic.getPosition()[1]+78)/40)
				local playerIndex=nil
				for a, details in pairs(turnOrder) do if details.seatPos==seatPos then playerIndex=a break end end
				if playerIndex==nil then return end

				local function storeTopCard()
					local deedZone=getObjectFromGUID(deedDeckZones[seatPos])
					if deedZone==nil then return end
					local drawn=nil
					for _, deedZoneObj in pairs(deedZone.getObjects()) do
						if deedZoneObj.type=="Card" then
							--Quick Witted is set aside, so skip it and keep looking for a normal Deed card.
							if not (turnOrder[playerIndex].mage=="Coral" and deedZoneObj.guid=="6ecbc6") then
								deedZoneObj.setPositionSmooth({tactic.getPosition()[1], 1.2, tactic.getPosition()[3]})
								deedZoneObj.setRotation({0, 180, 180})
								drawn=deedZoneObj
								break
							end
						end
						if deedZoneObj.type=="Deck" then
							local normalCards=deedZoneObj.getQuantity()
							if turnOrder[playerIndex].mage=="Coral" then
								for _, cardData in pairs(deedZoneObj.getObjects()) do if cardData.guid=="6ecbc6" then normalCards=normalCards-1 break end end
							end
							if normalCards>0 then
								drawn=deedZoneObj.takeObject({position={tactic.getPosition()[1], 1.2, tactic.getPosition()[3]}, rotation={0, 180, 180}})
								break
							end
						end
					end
					if drawn==nil then
						if turnOrder[playerIndex].mage=="Coral" then broadcastToAll("Night Tactic 6: Coral has no normal Deed card available to store.", positionToColor(playerIndex)) end
						return
					end

					--The stored card is no longer in the Deed deck and will later be claimed to hand.
					turnOrder[playerIndex].deedCount=math.max(0,(turnOrder[playerIndex].deedCount or 0)-1)
					gStates.powerStored[#gStates.powerStored+1]={["guid"]=drawn.guid}
					gStates.tacticSixState="Stored"
					scheduleDeedPileDescriptionRefresh(seatPos, "deed")
					mainUIUpdate("Night Tactic 6 Stored")
				end

				--Let Coral's physical set-aside card settle back on the bottom before taking the top card.
				if turnOrder[playerIndex].mage=="Coral" then coralSetAsideQuickWitted() safeWaitFrames("Turn",storeTopCard, 5)
				else storeTopCard() end
				tactic.setPositionSmooth({tactic.getPosition()[1], 4, tactic.getPosition()[3]})
			end
			if id:sub(1,17)=="NightTactic6Claim" then
				local seatPos=tonumber(id:sub(18,18))\n\t\t\t\tif seatPos==nil then return end
				claimNightTactic6StoredCards(seatPos, function(failed)
					if #failed>0 then
						broadcastToAll("Night Tactic 6 could not find "..tostring(#failed).." stored card(s).", warningColor)
						return
					end
					--Only finish the tactic after every recorded stored card has actually been returned.
					local tactic=getObjectFromGUID("e2af14")\n\t\t\t\t\tif tactic~=nil and tactic.is_face_down==false then tactic.flip() end
					gStates.powerStored={}
					gStates.tacticSixState="Used"
					scheduleDeedPileDescriptionRefresh(seatPos, "deed")
					outOfTurnUIStateKey=nil
					mainUIUpdate("Night Tactic 6 Claimed")
				end)
			end
		end
	end
end

--Motivation Skill Usage. To run via script-motivation({color="Black"}, -1, skillGUID.."xxxxxxxxxxx"..PlayerPos)

local tactic4HandBonusPause=nil
function refreshTactic4HandBonus(updateUI)
	if gStates==nil or gStates.turnNumber==nil or turnOrder[gStates.turnNumber]==nil then return false end
	local playerData=turnOrder[gStates.turnNumber]
	local bonus=0
	if playerData.tactic==4 and gStates.dayRound==true and gStates.tacticShown==false and playerData.seatPos~=nil and playerData.seatPos<5 then
		local handZone=getObjectFromGUID(handZones[playerData.seatPos])
		if handZone~=nil then
			local cardsInHand=0
			for _, obj in pairs(handZone.getObjects()) do
				if obj.type=="Card" then
					cardsInHand=cardsInHand+1
					if cardsInHand>=2 then bonus=1 break end
				end
			end
		end
	end
	local changed=gStates.tactic4HandBonus~=bonus
	gStates.tactic4HandBonus=bonus
	if changed==true and updateUI==true and gStates.firstStarted==true then mainUIUpdate("Tactic 4 Hand Bonus Changed") end
	return changed
end
function scheduleTactic4HandBonusRefresh()
	if tactic4HandBonusPause~=nil then Wait.stop(tactic4HandBonusPause) end
	tactic4HandBonusPause=safeWaitTime("Turn",function()
		tactic4HandBonusPause=nil
		refreshTactic4HandBonus(true)
	end, 0.05)
end

--Add a row of buttons to allow changing of hand color

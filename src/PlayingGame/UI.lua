-- Gameplay presentation, cached interface state and camera/object UI helpers.

local volkarePursuitButtonImageURL="https://steamusercontent-a.akamaihd.net/ugc/13293042467654760772/E72DCC400EC451ABB80DC722F3657A631FC30C70/"

--Repair the saved home locations for live skill tokens. This is skill bookkeeping, not UI bookkeeping,
--so only run it when skill state is being initialized/refreshed rather than on every main UI update.
--Cache play-area membership from zone enter/leave events so mainUIUpdate never has to rescan the physical zone just to count cards/skills.
local playAreaObjectState={}
local function syncPlayAreaObjectState(seatPos)
	local state={}
	local zone=seatPos~=nil and getObjectFromGUID(playerPlayAreas[seatPos]) or nil
	if zone~=nil then
		for _, obj in pairs(zone.getObjects()) do state[obj.guid]={wound=obj.getGMNotes()=="Wound"} end
	end
	playAreaObjectState[seatPos]=state
	return state
end
function updatePlayAreaObjectState(seatPos, obj, entered)
	if seatPos==nil or obj==nil then return end
	local state=playAreaObjectState[seatPos] or syncPlayAreaObjectState(seatPos)
	if entered==true then state[obj.guid]={wound=obj.getGMNotes()=="Wound"}
	else state[obj.guid]=nil end
end
function cachedPlayAreaCounts(seatPos)
	local state=playAreaObjectState[seatPos] or syncPlayAreaObjectState(seatPos)
	local cardCount=0
	local skillCount=0
	for guid, details in pairs(state) do
		local card=gameCards[guid]
		if (card~=nil and card.full==nil) or (card~=nil and gStates.bannercard[guid]==nil) or details.wound==true then cardCount=cardCount+1 end
		if skillTokens[guid]~=nil and gStates.doingTheRounds[guid]==nil then skillCount=skillCount+1 end
	end
	return cardCount, skillCount
end

--End-round availability only changes when the deed pile, current play area, turn/round state, or tactic state changes.
--Track deed-pile emptiness from Card/Deck zone/container events so ordinary main UI refreshes never rescan the pile.
endRoundDeedHasCards={}
deedPileCardCount={}
local endRoundDeedStateWait={}
endRoundUIStateKey=nil
outOfTurnUIStateKey=nil
local outOfTurnHotStateKey=nil
function readDeedPileCardCount(seatPos)
	local zone=seatPos~=nil and getObjectFromGUID(deedDeckZones[seatPos]) or nil
	if zone==nil then return 0 end
	local count=0
	for _, obj in pairs(zone.getObjects()) do
		if obj.type=="Deck" then count=count+obj.getQuantity()
		elseif obj.type=="Card" then count=count+1 end
	end
	return count
end
local function readDeedPileHasCards(seatPos) return readDeedPileCardCount(seatPos)>0 end
local function countEndRoundPlayAreaCards(seatPos)
	local cardCount=cachedPlayAreaCounts(seatPos)
	return cardCount
end
function refreshEndRoundState(playerAreaCardCount)
	if gStates.turnNumber==nil or gStates.turnNumber<1 or turnOrder[gStates.turnNumber]==nil then return end
	local playerStats=turnOrder[gStates.turnNumber]
	local seatPos=playerStats.seatPos
	local hasDeedCards=endRoundDeedHasCards[seatPos]
	if hasDeedCards==nil then
		local deedCount=readDeedPileCardCount(seatPos)
		deedPileCardCount[seatPos]=deedCount
		hasDeedCards=deedCount>0
	end
	endRoundDeedHasCards[seatPos]=hasDeedCards
	if playerAreaCardCount==nil then playerAreaCardCount=countEndRoundPlayAreaCards(seatPos) end
	local turnToken=getObjectFromGUID(playerStats.turnOrderTokenGUID)
	local tokenFaceDown=turnToken~=nil and turnToken.is_face_down==true
	local stateKey=table.concat({gStates.turnNumber, seatPos, tostring(hasDeedCards), playerAreaCardCount, gStates.currentRound, gStates.rounds, tostring(gStates.endRoundCalled), tostring(gStates.endGameAchieved), tostring(gStates.finalTurnReason), tostring(gStates.tacticShown), tostring(gStates.tacticRemove), tostring(tokenFaceDown), tostring(playerStats.mage), tostring(playerStats.dummyProcessedThisTurn), tostring(gStates.positionMageKnight[5]), tostring(gStates.volkareWon), tostring(gStates.volkareFrenzied), tostring(gStates.volkareState), tostring(gStates.proxyState)}, "|")
	if endRoundUIStateKey==stateKey then return end
	endRoundUIStateKey=stateKey

	UI.setAttribute("EndRoundButton", "interactable", "False")
	UI.setAttribute("EndRoundButtonImage", "image", "Sliced Button/Button New Deactive")
	UI.setAttribute("EndRoundButtonText", "text", joinLang({"{en}Call End of Round {ru}Объявить конец Раунда {zh-tw}聲明結束輪次 {zh-cn}声明结束轮次 {ko}라운드 종료 선언 {es}Llamar a Fin de Ronda {fr}Appel fin de Round{pt-br}Fim da Rodada {de}Ende der Runde Einläuten ", gStates.currentRound, "{en} of {ru} из {zh-tw} / {zh-cn} / {ko} / {es} / {fr} de {pt-br} de {de} von ", gStates.rounds}))
	if gStates.currentRound>=gStates.rounds then UI.setAttribute("EndRoundButtonText", "text", "{en}Call End of Game{ru}Объявить конец игры{zh-tw}宣告遊戲結束{zh-cn}宣布游戏结束{ko}게임 종료 선언{es}Declarar Fin del Juego{fr}Déclarer la Fin de la Partie{pt-br}Declarar Fim do Jogo{de}Spielende Ausrufen") end
	if hasDeedCards==false and playerStats.mage~=gStates.positionMageKnight[5] and tokenFaceDown==false and gStates.tacticShown==false and gStates.tacticRemove==false and gStates.endRoundCalled==false and gStates.endGameAchieved=="false" and playerAreaCardCount<1 then
		UI.setAttribute("EndRoundButton", "interactable", "True")
		UI.setAttribute("EndRoundButtonImage", "image", "Sliced Button/Button New Active")
	end
	if gStates.endRoundCalled==true then
		UI.setAttribute("EndRoundButtonText", "text", joinLang({"{en}Ending Round {ru}Завершение Раунда {zh-tw}正在結束輪次 {zh-cn}正在结束轮次 {ko}라운드 종료 중 {es}Terminando Ronda {fr}Fin du Round {pt-br}Terminando Rodada {de}Runde wird beendet ", gStates.currentRound, "{en} of {ru} из {zh-tw} / {zh-cn} / {ko} / {es} de {fr} sur {pt-br} de {de} von ", gStates.rounds}))
		if gStates.currentRound>=gStates.rounds then UI.setAttribute("EndRoundButtonText", "text", "{en}Ending Game{ru}Завершение игры{zh-tw}正在結束遊戲{zh-cn}正在结束游戏{ko}게임 종료 중{es}Terminando Juego{fr}Fin de la Partie{pt-br}Fim do Jogo{de}Spiel wird beendet") end
	end
end
function scheduleEndRoundDeedStateRefresh(seatPos)
	if seatPos==nil or deedDeckZones[seatPos]==nil then return end
	if endRoundDeedStateWait[seatPos]~=nil then Wait.stop(endRoundDeedStateWait[seatPos]) end
	endRoundDeedStateWait[seatPos]=safeWaitTime("UI",function()
		endRoundDeedStateWait[seatPos]=nil
		local oldCount=deedPileCardCount[seatPos]
		local newCount=readDeedPileCardCount(seatPos)
		deedPileCardCount[seatPos]=newCount
		endRoundDeedHasCards[seatPos]=newCount>0
		if gStates.turnNumber~=nil and turnOrder[gStates.turnNumber]~=nil and turnOrder[gStates.turnNumber].seatPos==seatPos then
			endRoundUIStateKey=nil
			refreshEndRoundState()
		end
		if oldCount~=newCount and gStates.firstStarted==true then
			outOfTurnUIStateKey=nil
			mainUIUpdate("Deed pile state changed")
		end
	end, 0.2)
end
function scheduleContainerEndRoundStateRefresh(container)
	if container==nil or container.type~="Deck" then return end
	for _, details in pairs(turnOrder) do
		local deedZone=getObjectFromGUID(deedDeckZones[details.seatPos])
		if containerInsideDeckZone(container, deedZone)==true then scheduleEndRoundDeedStateRefresh(details.seatPos) return end
	end
end

local function buildOutOfTurnUIStateKey(playerAreaCardCount, playerAreaSkillCount)
	if gStates.turnNumber==nil or turnOrder[gStates.turnNumber]==nil then return "no-turn" end
	local current=turnOrder[gStates.turnNumber]
	local parts={gStates.turnNumber, tostring(gStates.tacticRemove), tostring(gStates.tacticShown), tostring(gStates.dayRound), tostring(gStates.tacticTwoState), tostring(gStates.tacticFourState), tostring(gStates.tacticSixState), tostring(gStates.skippedMove), tostring(gStates.preEndTurn), tostring(#gStates.powerStored), playerAreaCardCount or 0, playerAreaSkillCount or 0, tostring(gStates.positionMageKnight[5])}

	--Pursuit availability depends on whether a pursuer exists and whether the current avatar is still at its turn-start location.
	local pursuitFound=false
	if gStates.pursuingMonsters[current.mage]~=nil then
		for _, state in pairs(gStates.pursuingMonsters[current.mage]) do if state~=nil and state.state=="Pursuing" then pursuitFound=true break end end
	end
	local pursuitAtStart=false
	if pursuitFound==true and current.turnStartLoc~=nil then
		local playerPos=mageKnightAvatarPositionByName(current.mage)
		if playerPos~=nil then pursuitAtStart=math.sqrt(((current.turnStartLoc.x-playerPos[1])^2)+((current.turnStartLoc.z-playerPos[3])^2))<1.5 end
	end
	parts[#parts+1]=tostring(pursuitFound)
	parts[#parts+1]=tostring(pursuitAtStart)

	--Master of Chaos availability depends on the physical skill token's player-board position.
	local chaosSeat=0
	local chaos=getObjectFromGUID("1ff34f")
	if chaos~=nil then
		local pos=chaos.getPosition()
		if pos[3]<-25 then chaosSeat=math.floor(((pos[1]+107.3)/40)+0.5) end
	end
	parts[#parts+1]=chaosSeat

	for a=1, #turnOrder do
		local player=turnOrder[a]
		local seatPos=player.seatPos
		local deedCount=deedPileCardCount[seatPos]
		if deedCount==nil then
			deedCount=readDeedPileCardCount(seatPos)
			deedPileCardCount[seatPos]=deedCount
			endRoundDeedHasCards[seatPos]=deedCount>0
		end
		parts[#parts+1]=table.concat({a, seatPos, tostring(player.dropoutState), tostring(player.mage), tostring(player.avatarLocation), tostring(player.pillagedVillage), tostring(player.tactic), deedCount, tostring(player.deedCount), tostring(player.masterOfChaos), tostring(player.fame)}, ":")
	end

	--Motivation buttons depend on skill owner/state and the lowest-fame comparison.
	local motivationGUIDs={}
	for skillGUID in pairs(gStates.motivationSkill) do motivationGUIDs[#motivationGUIDs+1]=skillGUID end
	table.sort(motivationGUIDs)
	for _, skillGUID in ipairs(motivationGUIDs) do
		local stats=gStates.motivationSkill[skillGUID]
		parts[#parts+1]=table.concat({skillGUID, tostring(stats.pos), tostring(stats.state), tostring(stats.bonus)}, ":")
	end
	return table.concat(parts, "|")
end

local function currentOutOfTurnPlayAreaCounts()
	if gStates.turnNumber==nil or turnOrder[gStates.turnNumber]==nil then return 0, 0 end
	return cachedPlayAreaCounts(turnOrder[gStates.turnNumber].seatPos)
end
function refreshOutOfTurnActions(playerAreaCardCount, playerAreaSkillCount, force, hotPlayAreaOnly)
	if gStates.firstStarted~=true or gStates.turnNumber==nil or turnOrder[gStates.turnNumber]==nil then return false end
	if playerAreaCardCount==nil or playerAreaSkillCount==nil then playerAreaCardCount, playerAreaSkillCount=currentOutOfTurnPlayAreaCounts() end
	--Ordinary play-area enter/leave only matters to this menu when the current area crosses empty/non-empty.
	--Use a cheap signature first; all other UI sources still build the full safety key below.
	local playAreaEmpty=(playerAreaCardCount+playerAreaSkillCount)<1
	local hotStateKey=table.concat({gStates.turnNumber, tostring(gStates.tacticRemove), tostring(gStates.tacticShown), tostring(gStates.dayRound), tostring(gStates.tacticTwoState), tostring(gStates.tacticFourState), tostring(gStates.tacticSixState), tostring(gStates.skippedMove), tostring(gStates.preEndTurn), tostring(#gStates.powerStored), tostring(gStates.positionMageKnight[5]), tostring(playAreaEmpty)}, "|")
	if force~=true and hotPlayAreaOnly==true and outOfTurnUIStateKey~=nil and outOfTurnHotStateKey==hotStateKey then return false end
	local newOutOfTurnUIStateKey=buildOutOfTurnUIStateKey(playerAreaCardCount, playerAreaSkillCount)
	outOfTurnHotStateKey=hotStateKey
	if force~=true and outOfTurnUIStateKey==newOutOfTurnUIStateKey then return false end
	outOfTurnUIStateKey=newOutOfTurnUIStateKey
		UI.setAttribute("OutOfTurnActions", "active", "false")
	local count=0
	if gStates.tacticRemove==false and gStates.tacticShown==false then
		for a=1, #turnOrder, 1 do
			UI.setAttribute("Plunder"..tostring(turnOrder[a].seatPos), "active", "false")
			UI.setAttribute("Pursuit"..tostring(turnOrder[a].seatPos), "active", "false")
			UI.setAttribute("NightTactic2-"..tostring(turnOrder[a].seatPos), "active", "false")
			UI.setAttribute("NightTactic4-"..tostring(turnOrder[a].seatPos), "interactable", "false")
			UI.setAttribute("NightTactic4-"..tostring(turnOrder[a].seatPos), "active", "false")
			UI.setAttribute("NightTactic6Store"..tostring(turnOrder[a].seatPos), "active", "false")
			UI.setAttribute("NightTactic6Claim"..tostring(turnOrder[a].seatPos), "active", "false")
			UI.setAttribute("MasterOfChaos"..tostring(turnOrder[a].seatPos), "active", "false")
			for skillGUID, stats in pairs(gStates.motivationSkill) do
				UI.setAttribute(skillGUID.."-Motivation"..tostring(turnOrder[a].seatPos), "active", "false")
			end

			--Plunder Village Buttons
			if playerDropoutInactive(a)==false and turnOrder[a].mage~=gStates.positionMageKnight[5] and turnOrder[a].avatarLocation~=nil and turnOrder[a].avatarLocation=="village" and (deedPileCardCount[turnOrder[a].seatPos] or 0)>0 and (a~=gStates.turnNumber or (a==gStates.turnNumber and playerAreaCardCount+playerAreaSkillCount<1 and gStates.preEndTurn~=true)) and turnOrder[a].pillagedVillage~=true and apocalypseQuestVillagePlunderBlocked(a)~=true then
				UI.setAttribute("Plunder"..tostring(turnOrder[a].seatPos), "active", "true")
				UI.setAttribute("Plunder"..tostring(turnOrder[a].seatPos.."Text"), "text", joinLang({translateWord[turnOrder[a].mage], "{en} Plunders the Village{ru} разграбляет деревню{zh-tw} 洗劫村莊{zh-cn} 洗劫村庄{ko} 마을약탈{es} Saquea la Aldea{fr} Pille le Village{pt-br} saqueia a Vila{de} Plündert das Dorf"}))
				UI.setAttribute("Plunder"..tostring(turnOrder[a].seatPos.."Image"), "color", positionToColor(a))
				count=count+1
			end

			--skip movement button.
			local found=false
			if gStates.pursuingMonsters[turnOrder[gStates.turnNumber].mage]~=nil then
				for _, state in pairs(gStates.pursuingMonsters[turnOrder[gStates.turnNumber].mage]) do
					if state~=nil and state.state=="Pursuing" then found=true end
				end
			end
			if playerDropoutInactive(a)==false and found==true and a==gStates.turnNumber and gStates.skippedMove==false and gStates.preEndTurn==false then
				local playerPos=mageKnightAvatarPosition(gStates.turnNumber) or {}
				if math.sqrt(((turnOrder[gStates.turnNumber].turnStartLoc.x-playerPos[1])^2)+((turnOrder[gStates.turnNumber].turnStartLoc.z-playerPos[3])^2))<1.5 then
					UI.setAttribute("Pursuit"..tostring(turnOrder[gStates.turnNumber].seatPos), "active", "true")
					UI.setAttribute("Pursuit"..tostring(turnOrder[gStates.turnNumber].seatPos.."Text"), "text", joinLang({translateWord[turnOrder[gStates.turnNumber].mage], "{en} skips their Move Phase{ru} пропускает свою фазу движения{zh-tw} 跳過移動階段{zh-cn} 跳过移动阶段{ko} 이동 단계 건너뛰기{es} se salta su Fase de Movimiento{fr} saute sa Phase de Mouvement{pt-br} Pula sua fase de movimentação{de} überspringt seine Bewegungsphase"}))
					UI.setAttribute("Pursuit"..tostring(turnOrder[gStates.turnNumber].seatPos.."Image"), "color", positionToColor(a))
					count=count+1
				end
			end

			--Night tactic 2 buttons
			if playerDropoutInactive(a)==false and turnOrder[a].tactic==2 and gStates.dayRound==false and gStates.tacticTwoState~="Used" and turnOrder[a].mage~=gStates.positionMageKnight[5] then
				local found=(deedPileCardCount[turnOrder[a].seatPos] or 0)>0
				if found==false then
					UI.setAttribute("NightTactic2-"..tostring(turnOrder[a].seatPos), "active", "true")
					UI.setAttribute("NightTactic2-"..tostring(turnOrder[a].seatPos.."Text"), "text", joinLang({translateWord[turnOrder[a].mage], "{en} Uses Night Tactic 2{ru} Использует ночную Тактику 2{zh-tw} 使用戰術卡 2{zh-cn} 使用战术卡 2{ko} 밤 전략 2 사용{es} Usa Táctica de Noche 2{fr} Utilise de nuit 2{pt-br} Usa Tática da Noite 2{de} Benutzt Nacht-Taktik 2"}))
					UI.setAttribute("NightTactic2-"..tostring(turnOrder[a].seatPos.."Image"), "color", positionToColor(a))
					count=count+1
				end
			end

			--Night Tactic 4 Buttons
			if playerDropoutInactive(a)==false and turnOrder[a].tactic==4 and (a~=gStates.turnNumber or (a==gStates.turnNumber and playerAreaCardCount+playerAreaSkillCount<1)) and gStates.dayRound==false and gStates.tacticFourState~="Used" and turnOrder[a].mage~=gStates.positionMageKnight[5] then
				local deedDeckSize=deedPileCardCount[turnOrder[a].seatPos] or 0
				if deedDeckSize>0 then
					UI.setAttribute("NightTactic4-"..tostring(turnOrder[a].seatPos), "active", "true")
					UI.setAttribute("NightTactic4-"..tostring(turnOrder[a].seatPos.."Text"), "text", joinLang({translateWord[turnOrder[a].mage], "{en} Tactic 4 ReDraw {ru} Тактика 4 - Вытянуть {zh-tw} 戰術卡 4 - 重抽 {zh-cn} 战术卡 4 - 重抽 {ko} 전략 4 사용 {es} Táctica 4 Volver a Robar {fr} Tactique 4 Redessiner {pt-br} Tatica 4 Re-Compre {de} Taktik 4 Nachziehen ", deedDeckSize-turnOrder[a].deedCount, "{en} Card(s){ru} Карт(у/ы){zh-tw} 張卡{zh-cn} 张卡{ko} 장의 카드 {es} Carta(s){fr} Cartes){pt-br} Carta(s){de} Karte(n)"}))
					UI.setAttribute("NightTactic4-"..tostring(turnOrder[a].seatPos.."Image"), "color", positionToColor(a))
					count=count+1
					if turnOrder[a].deedCount<deedDeckSize and deedDeckSize-turnOrder[a].deedCount>0 and deedDeckSize-turnOrder[a].deedCount<6 then UI.setAttribute("NightTactic4-"..tostring(turnOrder[a].seatPos), "interactable", "true") end
				end
			end

			--Night Tactic 6 Buttons - and a~=gStates.turnNumber
			if playerDropoutInactive(a)==false and turnOrder[a].tactic==6 and (a~=gStates.turnNumber or (a==gStates.turnNumber and playerAreaCardCount+playerAreaSkillCount<1)) and gStates.dayRound==false and gStates.tacticSixState~="Stored" and gStates.tacticSixState~="Used" and turnOrder[a].mage~=gStates.positionMageKnight[5] then
				local found=(deedPileCardCount[turnOrder[a].seatPos] or 0)>0
				if found==true then
					UI.setAttribute("NightTactic6Store"..tostring(turnOrder[a].seatPos), "active", "true")
					UI.setAttribute("NightTactic6Store"..tostring(turnOrder[a].seatPos).."Text", "text", joinLang({translateWord[turnOrder[a].mage], "{en} Tactic 6 - Store a Card{ru} Тактика 6 — Сберечь карту{zh-tw} 戰術卡 6 - 儲存一張卡牌{zh-cn} 战术卡 6 - 储存一张卡牌{ko} 전략 6 - 카드 비축{es} Táctica 6 - Almacenar Carta{fr} Tactique 6 - Stocker une Carte{pt-br} Tática 6 - Guardar uma Carta{de} Taktik 6 - Eine Karte aufbewahren"}))
					UI.setAttribute("NightTactic6Store"..tostring(turnOrder[a].seatPos).."Image", "color", positionToColor(a))
					count=count+1
				else nightTactic6({color="Black"}, "-1", "NightTactic6Claim"..tostring(turnOrder[a].seatPos)) end
				if #gStates.powerStored>0 then
					UI.setAttribute("NightTactic6Claim"..tostring(turnOrder[a].seatPos), "active", "true")
					UI.setAttribute("NightTactic6Claim"..tostring(turnOrder[a].seatPos).."Text", "text", joinLang({translateWord[turnOrder[a].mage], "{en} Tactic 6 - Claim {ru} Тактика 6 - Забрать {zh-tw} 戰術卡 6 - 拿取 {zh-cn} 战术卡 6 - 拿取 {ko} 전략 6 사용 - {es} Táctica 6 - Reclamar {fr} Tactique 6 - Réclamation {pt-br} Tática 6 - Clamar {de} Taktik 6 – Anspruch ", tostring(#gStates.powerStored), "{en} Card(s){ru} Карт(у/ы){zh-tw} 張卡{zh-cn} 张卡{ko} 장의 카드 {es} Carta(s){fr} Cartes){pt-br} Carta(s){de} Karte(n)"}))
					UI.setAttribute("NightTactic6Claim"..tostring(turnOrder[a].seatPos).."Image", "color", positionToColor(a))
					count=count+1
				end
			end

			--Motivation Skills
			for skillGUID, stats in pairs(gStates.motivationSkill) do
				if playerDropoutInactive(a)==false and stats.pos==turnOrder[a].seatPos and stats.state=="active" then
					--check if another motivation skill has been used
					local test=false
					for _, stats2 in pairs(gStates.motivationSkill) do
						if stats2.pos==turnOrder[a].seatPos and stats2.state=="used" then test=true end
					end
					if test==false then
						UI.setAttribute(skillGUID.."-Motivation"..tostring(turnOrder[a].seatPos), "active", "true")
						UI.setAttribute(skillGUID.."-Motivation"..tostring(turnOrder[a].seatPos).."Text", "text", joinLang({"{en}Use {ru}{zh-tw}使用{zh-cn}使用{ko}{es}Usa la Habilidad Motivación de {fr}Utilisez la compétence de motivation de {pt-br}Habilidade Motivacional de {de}Verwenden ", translateWord[skillTokens[skillGUID].mage], "{en}'s Motivation Skill{ru} использует навык Мотивация{zh-tw}的激勵技能{zh-cn}的激励技能{ko}의 동기부여 스킬 사용{es}.{fr}.{pt-br}.{de}'s Motivations Fähigkeit"}))
						UI.setAttribute(skillGUID.."-Motivation"..tostring(turnOrder[a].seatPos), "tooltip", "Draw two cards")
						local lowestFame=1
						--Work out lowest fame
						for b=2, #turnOrder, 1 do
							if turnOrder[b].mage~=gStates.positionMageKnight[5] then
								if turnOrder[b].fame<turnOrder[lowestFame].fame or turnOrder[lowestFame].mage==gStates.positionMageKnight[5] then lowestFame=b end
							end
						end
						for b=1, #turnOrder, 1 do if turnOrder[b].fame==turnOrder[lowestFame].fame and b~=lowestFame then lowestFame=0 break end end--find tied lowest fame
						if a==lowestFame then
							UI.setAttribute(skillGUID.."-Motivation"..tostring(turnOrder[a].seatPos).."Text", "text", joinLang({"{en}Use {ru}{zh-tw}使用{zh-cn}使用{ko}{es}Usa la Habilidad Motivación de {fr}Utilisez la compétence de motivation de {pt-br}Habilidade Motivacional de {de}Verwenden ", translateWord[skillTokens[skillGUID].mage], "{en}'s Motivation Skill (+){ru} использует навык Мотивация (+){zh-tw}的激勵技能（+）{zh-cn}的激励技能（+）{ko}의 동기부여 스킬 사용 (+){es}. (+){fr}. (+){pt-br}. (+){de}'s Motivations Fähigkeit (+)"}))
							local motivationBonus=joinLangParse(tostring(stats.bonus or ""))
							if type(motivationBonus)=="table" then motivationBonus=motivationBonus.en or "" end
							UI.setAttribute(skillGUID.."-Motivation"..tostring(turnOrder[a].seatPos), "tooltip", "Draw 2 Cards"..tostring(motivationBonus))
						end
						UI.setAttribute(skillGUID.."-Motivation"..tostring(turnOrder[a].seatPos).."Image", "color", positionToColor(a))
						count=count+1
					end
				end
			end

			--Master of Chaos
			if playerDropoutInactive(a)==false and getObjectFromGUID("1ff34f")~=nil and getObjectFromGUID("1ff34f").getPosition()[3]<-25 and math.floor(((getObjectFromGUID("1ff34f").getPosition()[1]+107.3)/40)+0.5)==turnOrder[a].seatPos and (a~=gStates.turnNumber or (a==gStates.turnNumber and playerAreaCardCount+playerAreaSkillCount<1)) and turnOrder[a].masterOfChaos=="available" and turnOrder[a].mage~=gStates.positionMageKnight[5] then
				UI.setAttribute("MasterOfChaos"..tostring(turnOrder[a].seatPos).."Text", "text", "{en}Increment 'Master of Chaos' Skill{ru}Передвинуть навык «Мастер магии Хаоса»{zh-tw} 推進“混亂大師”技能{zh-cn} 推进“混乱大师”技能{ko} '혼돈의 달인' 스킬 한 칸 이동{es}Incrementa la Habilidad 'Maestro del Caos'{fr}Augmenter la Compétence 'Maître du Chaos'{pt-br}Incrementar a Habilidade 'Mestre do Caos'{de}Erhöht die Fertigkeit 'Meister des Chaos'")
				UI.setAttribute("MasterOfChaos"..tostring(turnOrder[a].seatPos), "active", "true")
				UI.setAttribute("MasterOfChaos"..tostring(turnOrder[a].seatPos).."Image", "color", positionToColor(a))
				count=count+1
			end
		end
	end
		if count>0 then
			UI.setAttribute("OutOfTurnActions", "active", "true")
			UI.setAttribute("OutOfTurnActions", "height", 35+(count*30))
			UI.setAttribute("OutOfTurnActionsSub", "height", 5+(count*30))
			UI.setAttribute("OutOfTurnActions", "offsetXY", "0 "..tostring(55+(count*30)))
		end
	return true
end

--Play-area card scaling is driven directly by the play-area zones rather than mainUIUpdate.
--Cards cannot merge into Decks in the play area during normal play, so use the same loose-object counts as the original UI logic.
local playAreaScaleWait={}
function refreshPlayAreaCardScale(seatPos)
	local zone=seatPos~=nil and getObjectFromGUID(playerPlayAreas[seatPos]) or nil
	if zone==nil then return end
	local objects=zone.getObjects()
	local playerAreaCards=0
	local playerAreaObjects=0
	for _, obj in pairs(objects) do
		local inUnitArea=unitLayoutObjectInAnyUnitArea(obj.guid)
		local unitInUnitArea=unitLayoutIsUnit(obj) and inUnitArea
		if inUnitArea==false then playerAreaObjects=playerAreaObjects+1 end
		if unitInUnitArea==false and ((gameCards[obj.guid]~=nil and gameCards[obj.guid].full==nil) or (gameCards[obj.guid]~=nil and gStates.bannercard[obj.guid]==nil) or obj.getGMNotes()=="Wound") then playerAreaCards=playerAreaCards+1 end
	end
	local targetScale=(playerAreaCards>7 or playerAreaObjects>10) and 1.2 or 1.5
	for _, obj in pairs(objects) do
		local unitInUnitArea=unitLayoutIsUnit(obj) and unitLayoutObjectInAnyUnitArea(obj.guid)
		if unitInUnitArea==false and ((gameCards[obj.guid]~=nil and gameCards[obj.guid].full==nil) or obj.getGMNotes()=="Wound") then
			local scale=obj.getScale()
			if math.abs(scale.x-targetScale)>0.01 or math.abs(scale.z-targetScale)>0.01 then obj.setScale({targetScale, 1, targetScale}) end
		end
	end
end
function schedulePlayAreaCardScale(seatPos)
	if seatPos==nil then return end
	if playAreaScaleWait[seatPos]~=nil then Wait.stop(playAreaScaleWait[seatPos]) end
	playAreaScaleWait[seatPos]=safeWaitTime("UI",function()
		playAreaScaleWait[seatPos]=nil
		refreshPlayAreaCardScale(seatPos)
	end, 0.2)
end

--Fame and reputation are cached in turnOrder and resynchronised only when their physical shields actually move.
function refreshPlayerFameFromShield(playerIndex)
	local player=turnOrder[playerIndex]
	if player==nil or player.mage==gStates.positionMageKnight[5] then return false end
	local shield=getObjectFromGUID(player.fameGUID)
	if shield==nil then return false end
	local position=shield.getPosition()
	local fameVerticle=math.ceil((topOfFameBoard-position[3])/heightOfFameBoard*gStates.rowsOnBoard)
	local levelRowFameQuantity=(((fameVerticle-1)*cellGainPerLevel)+normalCellAmount)
	local levelRowLength=(((fameVerticle-1)*gStates.rowLengthGainPerLevel)+gStates.normalRowLength)
	local fameHorizontal=math.ceil((position[1]-leftOfFameBoard)/levelRowLength*levelRowFameQuantity)
	local fameValue=(3*(fameVerticle-1)+2*(fameVerticle-2)*(fameVerticle-1)/2-1+fameHorizontal)+(gStates.scoreIfLooped*player.scoreLoop)
	local difference=fameValue-player.fame
	player.fame=fameValue
	if difference<-20 then player.scoreLoop=player.scoreLoop+1 player.fame=fameValue+gStates.scoreIfLooped end
	if difference>80 then player.scoreLoop=player.scoreLoop-1 player.fame=fameValue-gStates.scoreIfLooped end
	if player.scoreLoop>0 then shield.highlightOn({1, 0.9, 0}) end
	return true
end
function refreshPlayerReputationFromShield(playerIndex)
	local player=turnOrder[playerIndex]
	if player==nil or player.mage==gStates.positionMageKnight[5] then return false end
	for repValue, repDetail in pairs(reputationTable) do
		local zone=getObjectFromGUID(repDetail.repZone)
		if zone~=nil then
			for _, obj in pairs(zone.getObjects()) do
				if obj.guid==player.reputationGUID then player.reputation=repValue return true end
			end
		end
	end
	return false
end
function refreshAllPlayerFameReputationFromShields()
	for a=1, #turnOrder do
		if turnOrder[a].mage~=gStates.positionMageKnight[5] then
			refreshPlayerFameFromShield(a)
			refreshPlayerReputationFromShield(a)
		end
	end
end
function recordPlayerFameChange(playerIndex, amount)
	local player=turnOrder[playerIndex]
	if player==nil or amount==nil then return end
	player.fame=player.fame+amount
	player.scoreLoop=math.max(0, math.floor(player.fame/gStates.scoreIfLooped))
	local shield=getObjectFromGUID(player.fameGUID)
	if player.scoreLoop>0 and shield~=nil then shield.highlightOn({1, 0.9, 0}) end
end

function unitRecruitableAtCurrentLocation(playerIndex,card)
	local player=turnOrder[playerIndex]
	local data=card~=nil and gameCards[card.guid] or nil
	if player==nil or data==nil or data.recruit==nil then return true end
	local location=player.avatarLocation or ""
	if gStates.gameScenario=="The Hidden Valley Blitz" and location=="hidden valley" and hiddenValleyLiberated()~=true then return false end
	if gStates.gameScenario=="The Lost Relic Blitz" and (location:sub(1,4)=="city" or location=="Volkare's Camp") then return false end
	local campInteraction=volkareCampPlayerHexInfo(playerIndex)~=nil
	for _,recruitLocation in pairs(data.recruit) do
		if recruitLocation==location then return true end
		if recruitLocation==location:sub(1,4) or location=="city white" then return true end
		if gStates.gameScenario=="The Chaos Rift" and location=="keep" and recruitLocation=="village" then return true end
		if campInteraction==true and (recruitLocation=="keep" or recruitLocation=="village") then return true end
	end
	return false
end

local mainUIPause=nil
levelUpcalled=false
gameOver=false
local handMainTextCache=nil
local endTurnFameRepCache=nil
--City influence is only relevant while standing on a conquered city. Keep this lookup local to that case
--so normal Main UI refreshes do not add another map scan. Megapolis linked zones are de-duplicated.
local function currentCityShieldInfluence(player)
	if player==nil or player.mage==nil or player.defeatedCities==nil then return 0 end
	local shields=0
	local location=player.avatarLocation or ""
	if location:sub(1,4)=="city" or location:sub(1,6)=="raised" then
		local cityByLocation={["city blue"]=cityModel.blue,["raised blue"]=cityModel.blue,["city red"]=cityModel.red,["raised red"]=cityModel.red,
			["city green"]=cityModel.green,["raised green"]=cityModel.green,["city white"]=cityModel.white,["raised white"]=cityModel.white}
		local cityGUID=player.avatarSwapCity or cityByLocation[location]
		if cityGUID~=nil and player.defeatedCities[cityGUID]~=nil then
			local cityGUIDs={cityGUID}
			local cityData=gStates.cityMonsterQty~=nil and gStates.cityMonsterQty[cityGUID] or nil
			local pair=cityData~=nil and cityData.extra~=nil and cityData.extra.megapolisPair or nil
			if pair~=nil then
				if pair~=cityGUID then cityGUIDs[#cityGUIDs+1]=pair
				else
					for otherCity,otherData in pairs(gStates.cityMonsterQty) do if otherCity~=cityGUID and otherData.extra~=nil and otherData.extra.megapolisPair==cityGUID then cityGUIDs[#cityGUIDs+1]=otherCity break end end
				end
			end
			local seen={}
			for _,targetCity in ipairs(cityGUIDs) do
				for zoneGUID,details in pairs(cityScriptZones) do
					if details.cityGUID==targetCity then
						local zone=getObjectFromGUID(zoneGUID)
						if zone~=nil then for _,obj in pairs(zone.getObjects()) do if seen[obj.guid]~=true and obj.getName()=="Shield" and obj.getDescription()==player.mage then seen[obj.guid]=true shields=shields+1 end end end
						break
					end
				end
			end
		end
	end
	local playerIndex=nil
	for index,details in pairs(turnOrder) do if details==player then playerIndex=index break end end
	if playerIndex~=nil and volkareCampPlayerHexInfo(playerIndex)~=nil then shields=shields+volkareCampContributionShieldCount(playerIndex) end
	return shields
end

local function signedBonus(value)
	if value>0 then return "+"..tostring(value) end
	return tostring(value)
end

function turnOrderIndexAtSeat(seatPos)
	for playerIndex, details in pairs(turnOrder) do if details.seatPos==seatPos then return playerIndex end end
	return nil
end

--Only inspect a Unit Area when that area actually changes; routine UI refreshes no longer scan it.
function separateCombinedUnitsInArea(seatPos)
	local zoneGUID=playerUnitAreas[seatPos]
	local unitArea=zoneGUID~=nil and getObjectFromGUID(zoneGUID) or nil
	if unitArea==nil then return end
	for _, unitObj in pairs(unitArea.getObjects()) do
		if unitObj.type=="Deck" and unitObj.getQuantity()==2 then
			local pos=unitObj.getPosition()
			unitObj.takeObject({position={pos[1]+0.8, pos[2]+0.1, pos[3]+0.8}})
		end
	end
end

--Shared presentation layer for every scripted/non-player turn that borrows the centre Dummy panel.
--Gameplay stays in the owning system; these helpers only decide and render the current UI state.
function automatedAttackResponseButton(id,textId,imageId,spec)
	if spec==nil then UI.setAttribute(id,"active","false") return end
	local visible=spec.active~=false
	local enabled=visible and spec.interactable~=false
	UI.setAttribute(id,"active",visible and "true" or "false")
	if spec.onClick~=nil then UI.setAttribute(id,"onClick",spec.onClick) end
	if spec.text~=nil then UI.setAttribute(textId,"text",spec.text) end
	UI.setAttribute(id,"tooltip",spec.tooltip or "")
	UI.setAttribute(id,"interactable",enabled and "true" or "false")
	UI.setAttribute(imageId,"image",enabled and "Sliced Button/Button New Active" or "Sliced Button/Button New Deactive")
end

function automatedAttackResponseUI(spec)
	if spec==nil then UI.setAttribute("VolkareAttacked","active","false") return false end
	if spec.visible~=nil then UI.setAttribute("VolkareAttacked","active",spec.visible and "true" or "false") end
	automatedAttackResponseButton("VolkareAttackedFull","VolkareAttackedFullText","VolkareAttackedFullImage",spec.full)
	automatedAttackResponseButton("VolkareAttackedPartial","VolkareAttackedPartialText","VolkareAttackedPartialImage",spec.partial)
	automatedAttackResponseButton("VolkareRetreat","VolkareRetreatText","VolkareRetreatImage",spec.retreat)
	return spec.visible~=false
end

function automatedPanelHasDeedCards(stats)
	if stats==nil or stats.seatPos==nil then return false end
	local cached=endRoundDeedHasCards[stats.seatPos]
	if cached~=nil then return cached end
	local count=readDeedPileCardCount(stats.seatPos)
	deedPileCardCount[stats.seatPos]=count
	endRoundDeedHasCards[stats.seatPos]=count>0
	return count>0
end

function automatedPanelEndRoundText()
	if gStates.currentRound>=gStates.rounds then return "{en}Call End of Game{ru}Объявить конец игры{zh-tw}宣告遊戲結束{zh-cn}宣布游戏结束{ko}게임 종료 선언{es}Declarar Fin del Juego{fr}Déclarer la Fin de la Partie{pt-br}Declarar Fim do Jogo{de}Spielende Ausrufen" end
	return joinLang({"{en}Call End of Round {ru}Объявить конец Раунда {zh-tw}聲明結束輪次 {zh-cn}声明结束轮次 {ko}라운드 종료 선언 {es}Llamar a Fin de Ronda {fr}Appel fin de Round{pt-br}Fim da Rodada {de}Ende der Runde Einläuten ",gStates.currentRound,"{en} of {ru} из {zh-tw} / {zh-cn} / {ko} / {es} / {fr} de {pt-br} de {de} von ",gStates.rounds})
end

function automatedProxyPanelSpec(stats,stateOverride)
	local state=stateOverride or gStates.proxyState or "Start"
	local spec={actor="proxy",onClick="proxyTurn",interactable=true,label="{en}Process Proxy{ru}Ход прокси{zh-tw}代理玩家行動{zh-cn}代理玩家行动{ko}프록시 진행{es}Procesar Proxy{fr}Traiter le Proxy{pt-br}Processar Proxy{de}Proxy aktivieren"}
	local atStart=stateOverride==nil and stats.dummyProcessedThisTurn~=true
	if atStart and automatedPanelHasDeedCards(stats)==false and gStates.endRoundCalled==false and gStates.endGameAchieved=="false" then
		spec.onClick="PreEndRound"
		spec.label=automatedPanelEndRoundText()
		spec.notes="{en}The Proxy's Deed deck is empty. Call End of Round.{ru}Колода действий Прокси пуста. Объявите конец Раунда.{zh-tw}代理玩家的行動牌庫已空。請宣告輪次結束。{zh-cn}代理玩家的行动牌库已空。请宣布轮次结束。{ko}프록시의 액션 덱이 비었습니다. 라운드 종료를 선언하세요.{es}El mazo de acciones del Proxy está vacío. Llama al Fin de Ronda.{fr}Le deck d'actions du Proxy est vide. Appelez la Fin du Round.{pt-br}O baralho de ações do Proxy está vazio. Declare o Fim da Rodada.{de}Das Aktionsdeck des Proxy ist leer. Ruft das Rundenende aus."
		return spec
	end
	if state=="Processing" then
		spec.label="{en}Processing Proxy...{ru}Обработка прокси...{zh-tw}代理玩家行動處理中...{zh-cn}代理玩家行动处理中...{ko}프록시 처리 중...{es}Procesando Proxy...{fr}Traitement du Proxy...{pt-br}Processando Proxy...{de}Proxy wird verarbeitet...}"
		if stateOverride==nil then
			spec.notes=gStates.proxyTurnReport~=nil and proxyTurnReportText() or "Proxy is preparing their movement."
		end
		spec.interactable=false
	elseif state=="PickDestination" or state=="PickRoute" or state=="PickCard" or state=="PickEnemy" or state=="PickMana" then
		local pending=gStates.proxyPendingChoice
		spec.label=proxyChoiceWaitingText~=nil and proxyChoiceWaitingText(pending~=nil and pending.type or nil) or "{en}Make Proxy Choice{ru}Сделать выбор за Прокси{zh-tw}進行代理玩家選擇{zh-cn}进行代理玩家选择{ko}프록시 선택하기{es}Elegir por el Proxy{fr}Faire le choix du Proxy{pt-br}Fazer escolha do Proxy{de}Proxy-Auswahl treffen"
		spec.notes=proxyTurnReportText~=nil and proxyTurnReportText() or ""
		spec.interactable=false
		if pending~=nil and pending.type=="mana" then spec.proxyManaChoice=pending end
	elseif state=="ReadyToEnd" then
		spec.label="{en}Proxy Processed{ru}Прокси обработан{zh-tw}代理玩家行動結束{zh-cn}代理玩家行动结束{ko}프록시 처리 완료{es}Proxy Procesado{fr}Proxy traité{pt-br}Proxy Processado{de}Proxy verarbeitet"
		spec.notes=proxyTurnReportText~=nil and proxyTurnReportText() or ""
	else
		if stats.dummyProcessedThisTurn==true then
			spec.label="{en}Dummy Processed{ru}Виртуальный игрок сходил{zh-tw}虛擬玩家行動結束{zh-cn}虚拟玩家行动结束{ko}진행 완료{es}Jugador Virtual Procesado{fr}Fantôme préparé{pt-br}Jog.Fictício Processado{de}Dummy verarbeitet"
			spec.interactable=false
		else
			spec.notes="{en}Proxy reveals its objective, calculates movement, then moves across the map and resolves its action. If a legal destination, card, or enemy choice is tied, the lowest-Fame player chooses using the highlighted board buttons.{ru}Прокси раскрывает цель, рассчитывает движение, затем перемещается по карте и выполняет действие.{zh-tw}代理玩家會揭示目標、計算移動，然後在地圖上移動並執行行動。{zh-cn}代理玩家会揭示目标、计算移动，然后在地图上移动并执行行动。{ko}프록시는 목표를 공개하고 이동력을 계산한 뒤 지도에서 이동하고 행동을 해결합니다.{es}El Proxy revela su objetivo, calcula el movimiento, se desplaza por el mapa y resuelve su acción.{fr}Le Proxy révèle son objectif, calcule son déplacement, se déplace sur la carte puis résout son action.{pt-br}O Proxy revela seu objetivo, calcula o movimento, percorre o mapa e resolve sua ação.{de}Der Proxy deckt sein Ziel auf, berechnet seine Bewegung, bewegt sich über die Karte und führt seine Aktion aus."
		end
	end
	if gStates.tacticRemove==true or gStates.tacticShown==true then
		spec.notes="{en}Click the button in the Center to claim a random tactic.{ru}Нажмите кнопку в центре, чтобы выбрать случайную Тактику.{zh-tw}點擊中間的按鈕來隨機選擇戰術卡。{zh-cn}点击中间的按钮来随机选择战术卡。{ko}중앙에 있는 버튼을 클릭하여 무작위 전략 카드를 고르세요.{es}Pulsar el Botón del Centro para Robar una Táctica al Azar.{fr}Cliquez sur le bouton dans le Centre pour réclamer une tactique aléatoire.{pt-br}Clique no botão no centro para pegar uma tática aleatória.{de}Klicken Sie auf die Schaltfläche in der Mitte, um eine zufällige Taktik zu fordern."
		if gStates.tacticRemove==true then spec.interactable=false end
	end
	return spec
end

function automatedDummyPanelSpec(stats)
	local spec={actor="dummy",onClick="dummyTurn",interactable=true,label="{en}Process Dummy{ru}Ход виртуального игрока{zh-tw}虛擬玩家行動{zh-cn}虚拟玩家行动{ko}가상 플레이어 진행{es}Procesar Jugador Virtual{fr}Processus fantôme{pt-br}Processar Jog.Fictício{de}Dummy aktivieren"}
	if stats.dummyProcessedThisTurn~=true and automatedPanelHasDeedCards(stats)==false and gStates.endRoundCalled==false and gStates.endGameAchieved=="false" then
		spec.onClick="PreEndRound"
		spec.label=automatedPanelEndRoundText()
		spec.notes="{en}The Dummy's Deed deck is empty. Call End of Round.{ru}Колода действий виртуального игрока пуста. Объявите конец Раунда.{zh-tw}虛擬玩家的行動牌庫已空。請宣告輪次結束。{zh-cn}虚拟玩家的行动牌库已空。请宣布轮次结束。{ko}가상 플레이어의 액션 덱이 비었습니다. 라운드 종료를 선언하세요.{es}El mazo de acciones del Jugador Virtual está vacío. Llama al Fin de Ronda.{fr}Le deck d'actions du fantôme est vide. Appelez la Fin du Round.{pt-br}O baralho de ações do Jogador Fictício está vazio. Declare o Fim da Rodada.{de}Das Aktionsdeck des Dummys ist leer. Ruft das Rundenende aus."
		return spec
	end
	if stats.dummyProcessedThisTurn==true then
		spec.label="{en}Dummy Processed{ru}Виртуальный игрок сходил{zh-tw}虛擬玩家行動結束{zh-cn}虚拟玩家行动结束{ko}진행 완료{es}Jugador Virtual Procesado{fr}Fantôme préparé{pt-br}Jog.Fictício Processado{de}Dummy verarbeitet"
		spec.interactable=false
	else
		spec.notes="{en}Dummy will draw three cards.\nHe then draws cards up to the amount of Crystals that match the third card.{ru}Виртуальный игрок вытащит три карты.\nЗатем он вытащит дополнительно столько карт, сколько он имеет Кристаллов цвета последней перевернутой карты.{zh-tw}虛擬玩家將抽三張牌。\n\n如果它有與第三張牌相同顏色的\n魔晶，則會再抽取等同於該顏色\n魔晶數量的卡牌。{zh-cn}虚拟玩家将抽三张牌。\n\n如果它有与第三张牌相同颜色的\n魔晶，则会再抽取等同于该颜色\n魔晶数量的卡牌。{ko}가상 플레이어의 더미에서\n카드 세 장을 뒤집습니다.\n가상 플레이어의 저장 칸에서, 마지막으로 뒤집힌 카드 색상과 동일한 수정의 개수 만큼 더 뒤집습니다.{es}El Jugador Virtual robará tres cartas\nDespués robará una carta más por cada cristal del color de la última carta robada.{fr}Le fantôme piochera trois cartes.\nIl pioche ensuite des cartes jusqu'à concurrence du nombre de cristaux correspondant à la troisième carte.{pt-br}Jog. Fictício comprará 3 cartas.\nEle então compra cartas equivalentes ao número de cristais que possui da cor da terceira carta.{de}Der Dummy zieht drei Karten.\nEr zieht dann Karten bis zu der Menge an Kristallen, die zur dritten Karte passen."
	end
	if gStates.tacticRemove==true or gStates.tacticShown==true then
		spec.notes="{en}Click the button in the Center to claim a random tactic.{ru}Нажмите кнопку в центре, чтобы выбрать случайную Тактику.{zh-tw}點擊中間的按鈕來隨機選擇戰術卡。{zh-cn}点击中间的按钮来随机选择战术卡。{ko}중앙에 있는 버튼을 클릭하여 무작위 전략 카드를 고르세요.{es}Pulsar el Botón del Centro para Robar una Táctica al Azar.{fr}Cliquez sur le bouton dans le Centre pour réclamer une tactique aléatoire.{pt-br}Clique no botão no centro para pegar uma tática aleatória.{de}Klicken Sie auf die Schaltfläche in der Mitte, um eine zufällige Taktik zu fordern."
		if gStates.tacticRemove==true then spec.interactable=false end
	end
	return spec
end

function automatedVolkarePanelSpec(stats)
	local state=gStates.volkareState or "Start"
	local spec={actor="volkare",onClick="volkareTurn",interactable=true,preserveResponse=true,label="{en}Process Volkare{ru}Ход Волкара{zh-tw}沃卡里行動{zh-cn}沃卡里行动{ko}볼케어 진행{es}Procesar Volkare{fr}Processus Volkare{pt-br}Processar Volkare{de}Volkare Aktivieren"}
	if state=="Start" then
		spec.notes="{en}Volkare is close to fully programmed.<size=6>\n\n</size>If you feel he has moved incorrectly, unlock and move him where he should have gone.{ru}Волкар почти полностью заскриптован.<size=6>\n\n</size>Если вы считаете, что он двигается неправильно, разблокируйте его и переместите туда, куда он должен был пойти.{zh-tw}沃卡里會完全按照腳本移動。<size=6>\n\n</size>如果你發現他走錯位置的話，\n將他解鎖並移動到正確的位置。{zh-cn}沃卡里会完全按照脚本移动。<size=6>\n\n</size>如果你发现他走错位置的话，\n将他解锁并移动到正确的位置。{ko}볼케어의 스크립트는 거의 문제을 일으키지 않으나,<size=6>\n\n</size>만약 잘못된다면 볼케어의 고정을 풀고 직접 원하는 곳에 놓으세요.{es}Volkare está cerca de estar completamente programado.\nSi crees que se ha movido incorrectamente, desbloquealo y muévelo a donde debería haberse movido.{fr}Volkare est presque entièrement programmé.<size=6>\n\n</size>Si vous pensez qu'il a mal bougé, déverrouillez-le et déplacez-le là où il aurait dû aller.{pt-br}Volkare está perto de ser completamente programado.<size=6>\n\n</size>Se você sentir que ele está morrendo de forma incorreta, desbloqueie-o e o mova para aonde ele deveria ter ido.{de}Volkare ist so gut wie fertig programmiert.<size=6>\n\n</size>Wenn Sie das Gefühl haben, dass er sich falsch bewegt hat, entsperren Sie ihn und bewegen Sie ihn dorthin, wo er hingehört."
	elseif state=="ReadyToEnd" then
		spec.label="{en}Volkare Processed{ru}Волкар сходил{zh-tw}沃卡里行動結束{zh-cn}沃卡里行动结束{ko}진행 완료{es}Volkare Procesado{fr}Volkare Traité{pt-br}Volkare Processado{de}Volkare Verarbeitet"
		spec.notes=gStates.blurb
	else
		spec.label="{en}Processing Volkare...{ru}Обработка Волкара...{zh-tw}沃卡里行動處理中...{zh-cn}沃卡里行动处理中...{ko}볼케어 처리 중...{es}Procesando Volkare...{fr}Traitement de Volkare...{pt-br}Processando Volkare...{de}Volkare wird verarbeitet..."
		spec.notes=gStates.blurb
		spec.interactable=false
	end
	if automatedPanelHasDeedCards(stats)==false and gStates.volkareWon==false and gStates.volkareFrenzied==true then
		if state=="Start" then
			spec.label="{en}Process Frenzied Volkare{ru}Ход Волкара в состоянии Ярости{zh-tw}狂暴沃卡里行動{zh-cn}狂暴沃卡里行动{ko}볼케어(광폭) 진행{es}Procesar Volkare en Frenesí{fr}Processus Volkare Frénétique{pt-br}Processar Volkare em Frenesi{de}Rasender Volkare wird verarbeitet"
			spec.notes="{en}Volkare's Deck is Empty.\n-< FRENZY >-\nVolkare acts as if he drew a Blue Spell and doesn't Reroll any Die.{ru}Колода Волкара пуста.\n-< ЯРОСТЬ >-\nВолкар действует так, как будто он вытащил Синее Заклинание, и не перебрасывает кубики.{zh-tw}沃卡里牌的牌庫已空。\n-<狂暴>-\n接下來的每一回合，\n沃卡里視為翻開一張藍色法術卡\n來行動。（即移動或攻擊兩次）\n此次行動不重擲任何骰子。{zh-cn}沃卡里牌的牌库已空。\n-<狂暴>-\n接下来的每一回合，\n沃卡里视为翻开一张蓝色法术卡\n来行动。（即移动或攻击两次）\n此次行动不重掷任何骰子。{ko}볼케어의 더미가 비었습니다.\n-< 광폭 >-\n이제 볼케어는 파란색 마법을 뽑은 것처럼 행동하며, 주사위를 굴리지 않습니다.{es}El mazo de Volkare está vacío.\n-< FRENESÍ >-\nVolkare actúa como si hubiera robado un Hechizo Azul, y no vuelve a lanzar ningún dado.{fr}Le Deck de Volkare est vide.\n-< FRÈSIE >-\nVolkare agit comme s'il avait pioché un sort bleu et ne relance aucun dé.{pt-br}Deck do Volkare está vazio.\n-< FRENESI >-\nVolkare age como se ele tirasse um Feitiço azul e não re-rola nenhum dado.{de}Volkare Deck ist leer.\n-< FRENZY >-\nVolkare tut so, als ob er einen blauen Zauberspruch gezogen hätte und würfelt nicht neu."
		else
			spec.label="{en}Frenzied Volkare Processed{ru}Волкар в состоянии Ярости сходил{zh-tw}狂暴沃卡里行動結束{zh-cn}狂暴沃卡里行动结束{ko}진행 완료{es}Volkare en Frenesí Procesado{fr}Volkare Frénétique Traité{pt-br}Volkare em Frenesi Processado{de}Rasender Volkare verarbeitet"
		end
	end
	if gStates.tacticRemove==true or gStates.tacticShown==true then
		spec.notes="{en}Click the button in the Center to claim a random tactic.{ru}Нажмите кнопку в центре, чтобы выбрать случайную Тактику.{zh-tw}點擊中間的按鈕來隨機選擇戰術卡。{zh-cn}点击中间的按钮来随机选择战术卡。{ko}중앙에 있는 버튼을 클릭하여 무작위 전략 카드를 고르세요.{es}Pulsar el Botón del Centro para Robar una Táctica al Azar.{fr}Cliquez sur le bouton dans le Centre pour réclamer une tactique aléatoire.{pt-br}Clique no botão no centro para pegar uma tática aleatória.{de}Klicken Sie auf die Schaltfläche in der Mitte, um eine zufällige Taktik zu fordern."
		if gStates.tacticRemove==true then spec.interactable=false end
	end
	if ((gStates.endRoundCalled==true and gStates.currentRound>=gStates.rounds) or gStates.volkareWon==true) and state=="Start" then
		spec.notes="{en}Final round of turns is complete. For most players this would have meant just flipping your Turn Order token back upright.{ru}Завершен последний круг ходов. Для большинства игроков это означало бы просто перевернуть жетон очередности хода обратно в вертикальное положение.{zh-tw}最後一輪的最終回合已結束。\n對於大多數玩家只需將你的順位\n標記翻轉回來即可。{zh-cn}最后一轮的最终回合已結束。\n對於大多数玩家只需将你的順位\n标记翻转回来即可。{ko}차례의 마지막 순서가 끝났습니다. 대부분의 플레이어들은 라운드 순서 토큰을 앞면으로 뒤집었을겁니다.{es}La Última Ronda de Turnos se ha completado. Para la mayoría de jugadores esto significa simplemente poner boca arriba el marcador de turno.{fr}Le dernier tour est terminé. Pour la plupart des joueurs, cela aurait signifié simplement retourner votre jeton Ordre du tour à la verticale.{pt-br}Rodada Final de turnos está completa. Para a maioria dos jogadores isso significa apenas virar sua ficha de ordem de turno de volta para cima.{de}Die letzte Zugrundelegung ist abgeschlossen. Für die meisten Spieler würde dies bedeuten, dass sie ihr Zugreihenfolgeplättchen einfach wieder umdrehen."
		if gStates.volkareReturnTimeoutLoss==true then spec.notes=gStates.blurb end
	end
	return spec
end

function automatedCurrentPlayerPanelSpec()
	if gStates==nil or gStates.turnNumber==nil or turnOrder[gStates.turnNumber]==nil or gStates.positionMageKnight==nil then return nil end
	local stats=turnOrder[gStates.turnNumber]
	if stats.mage~=gStates.positionMageKnight[5] then return nil end
	if gStates.positionMageKnight[5]=="Volkare" then return automatedVolkarePanelSpec(stats) end
	if proxyPlayerActive~=nil and proxyPlayerActive()==true then return automatedProxyPanelSpec(stats) end
	return automatedDummyPanelSpec(stats)
end

function automatedMainPanelApply(spec)
	if spec==nil then
		UI.setAttribute("DummyTurn","active","false")
		UI.setAttribute("ExtraTurnTactic","active","false")
		UI.setAttribute("DummyChoiceButtons","active","false")
		automatedAttackResponseUI(nil)
		return false
	end
	if spec.preserveResponse~=true then
		if spec.responseSpec~=nil then automatedAttackResponseUI(spec.responseSpec) else automatedAttackResponseUI(nil) end
	end
	UI.setAttribute("ExtraTurnTactic","active","false")
	if spec.panelActive==false then
		UI.setAttribute("DummyTurn","active","false")
		UI.setAttribute("DummyChoiceButtons","active","false")
		return true
	end
	UI.setAttribute("DummyTurn","active","true")
	if spec.mainText~=nil then UI.setAttribute("MainGameNotes","text",spec.mainText) UI.setAttribute("MainGameNotes","color","white") end
	if spec.notes~=nil then UI.setAttribute("DummyNotes","Text",spec.notes) end
	if spec.actor=="proxy" and proxyManaChoiceUI~=nil then proxyManaChoiceUI(nil) else UI.setAttribute("DummyChoiceButtons","active","false") end
	UI.setAttribute("DummyButton","active",spec.buttonVisible==false and "false" or "true")
	if spec.onClick~=nil then UI.setAttribute("DummyButton","onClick",spec.onClick) end
	if spec.label~=nil then UI.setAttribute("DummyButtonText","Text",spec.label) end
	local enabled=spec.interactable~=false
	UI.setAttribute("DummyButton","interactable",enabled and "True" or "False")
	UI.setAttribute("DummyButtonImage","image",enabled and "Sliced Button/Button New Active" or "Sliced Button/Button New Deactive")
	if spec.proxyManaChoice~=nil and proxyManaChoiceUI~=nil then proxyManaChoiceUI(spec.proxyManaChoice) end
	return true
end

function automatedMainPanelRefresh(overrideSpec)
	local spec=overrideSpec
	--Against the Horsemen uses the same Automated Turn panel as Volkare's timeout loss.
	--Unlike Volkare, the final-turn owner may be a normal Mage Knight, so force the panel visible
	--instead of depending on the automated seat being the current turn when the loss is registered.
	if spec==nil and gStates~=nil and gStates.againstHorsemenTimeoutLoss==true then
		spec={
			actor="horsemen",
			onClick="layoutClaimedCards",
			interactable=true,
			label="{en}Game Over - Show Score{ru}Игра окончена — показать счёт{zh-tw}遊戲結束－顯示分數{zh-cn}游戏结束－显示分数{ko}게임 종료 - 점수 보기{es}Fin de Partida - Mostrar Puntuación{fr}Partie Terminée - Afficher le Score{pt-br}Fim de Jogo - Mostrar Pontuação{de}Spiel Beendet - Wertung Anzeigen",
			notes=gStates.blurb,
			mainText="{en}<size=25>Against the Horsemen</size>{ru}<size=25>Против Всадников</size>{zh-tw}<size=25>對抗四騎士</size>{zh-cn}<size=25>对抗四骑士</size>{ko}<size=25>묵시록의 기사들에 맞서</size>{es}<size=25>Contra los Jinetes</size>{fr}<size=25>Contre les Cavaliers</size>{pt-br}<size=25>Contra os Cavaleiros</size>{de}<size=25>Gegen die Reiter</size>"
		}
	end
	if spec==nil and gStates~=nil and gStates.apocalypseDragonTurnActive==true and apocalypseDragonMainUIPanelSpec~=nil then spec=apocalypseDragonMainUIPanelSpec() end
	if spec==nil and gStates~=nil and gStates.apocalypseHereHorsemenTurnActive==true and apocalypseIsHereMainUIPanelSpec~=nil then spec=apocalypseIsHereMainUIPanelSpec() end
	if spec==nil then spec=automatedCurrentPlayerPanelSpec() end
	return automatedMainPanelApply(spec)
end

function mainUIUpdate(source)
	if gStates.firstStarted==true then
		if mainUIPause~=nil then Wait.stop(mainUIPause) end
		mainUIPause=safeWaitTime("UI",function()
			local playerAreaCardCount=0
			local playerAreaSkillCount=0
			local nextPlayer=nextTurnMerged("nextMage")
			local nextPlayerEndCalled=turnOrder[nextPlayer].endCalled
			if nextPlayerEndCalled~=true and turnOrder[nextPlayer].mage==gStates.positionMageKnight[5] then nextPlayerEndCalled=turnOrder[nextTurnMerged("nextMageSkipDummy")].endCalled end
			--if nextPlayerEndCalled~=true then nextPlayerEndCalled=turnOrder[nextPlayer].gameEnder end
			--if nextPlayerEndCalled~=true then nextPlayerEndCalled=turnOrder[nextTurnMerged("nextMageSkipDummy")].gameEnder end

			--Check for Game Over state. Normal final-turn completion is promoted to
			--gStates.gameOver by nextTurnMerged("incrementTurn"), after Rewards Claimed
			--has finished the last player's cleanup.
			gameOver=gStates.gameOver==true or gStates.volkareWon==true

			local currentPlayerGameEnder=turnOrder[gStates.turnNumber].gameEnder==true

			--Card/skill counts come from the play-area GUID registry maintained by zone enter/leave events.
			playerAreaCardCount, playerAreaSkillCount=cachedPlayAreaCounts(turnOrder[gStates.turnNumber].seatPos)


			--Play-area card scaling is handled by the play-area zone callbacks.
			--This keeps physical setScale calls out of the full main UI refresh.

			--Fame is cached when a fame shield moves; ordinary UI refreshes do not reread every fame shield.

			--Out of Turn Menu visibility is event-driven/cached. Ordinary card movement uses the cheap empty/non-empty hot path.
			local outOfTurnHotPlayAreaOnly=source=="Object entered into play area" or source=="Object removed from zone"
			refreshOutOfTurnActions(playerAreaCardCount, playerAreaSkillCount, false, outOfTurnHotPlayAreaOnly)


			--change End turn button to say End Round on the last player turn
			UI.setAttribute("EndTurnButton", "interactable", "True")
			UI.setAttribute("EndTurnButton", "tooltip", "At least one card must be played or discarded to 'End Your Turn'.")
			UI.setAttribute("EndTurnButtonImage", "image", "Sliced Button/Button New Active")
			UI.setAttribute("EndTurnButtonAlt", "interactable", "True")
			UI.setAttribute("EndTurnButtonAltImage", "image", "Sliced Button/Button New Active")
			UI.setAttribute("ExtraTurnTacticButton", "interactable", "True")
			UI.setAttribute("ExtraTurnTacticButtonImage", "image", "Sliced Button/Button New Active")
			UI.setAttribute("PreEndTurnText", "text", "{en}Rewards Claimed{ru}Награды получены{zh-tw}獲得獎勵{zh-cn}获得奖励{ko}보상 처리 완료{es}Recompensas Reclamadas{fr}Récompenses réclamées{pt-br}Recompensas Coletadas{de}Belohnungen Beansprucht")
			local endText="{en}End Turn{ru}Конец хода{zh-tw}結束回合{zh-cn}结束回合{ko}차례 종료{es}Fin de Turno{fr}Fin de Tour{pt-br}Fim de Turno{de}Zug Beenden"
			if nextPlayerEndCalled==true then
				endText="{en}End Turn and Round{ru}Конец хода и Раунда{zh-tw}結束回合及本輪次{zh-cn}结束回合及本轮次{ko}차례 및 라운드 종료{es}Fin de Turno y Ronda{fr}Fin du Tour et du Round{pt-br}Fim de Turno e Rodada{de}Zug und Runde Beenden" end
			if gStates.endGameAchieved=="true" and ((gStates.finalTurnReason=="victory" and currentPlayerGameEnder==true) or (gStates.finalTurnReason=="endRound" and nextPlayerEndCalled==true))==true then
				endText="{en}End Game{ru}Конец игры{zh-tw}結束遊戲{zh-cn}结束游戏{ko}게임 종료{es}Fin del Juego{fr}Fin du Jeu{pt-br}Fim de Jogo{de}Spiel Beenden" end
			local nextIsCoopAssaulter=gStates.coopAssaultPhase=="combat" and gStates.coopAssaultParticipants~=nil and gStates.coopAssaultParticipants[nextPlayer]~=nil
			local nextTurnToken=nextIsCoopAssaulter and getObjectFromGUID(turnOrder[nextPlayer].turnOrderTokenGUID) or nil
			if nextIsCoopAssaulter and turnOrder[nextPlayer].mage~=gStates.positionMageKnight[5] and nextTurnToken~=nil and nextTurnToken.is_face_down==true then
				endText="{en}Next Assaulter{ru}Следующий штурмующий{zh-tw}換下一個襲擊者{zh-cn}换下一个袭击者{ko}다음 강습자{es}Siguiente Asaltante{fr}Prochain Agresseur{pt-br}Próximo Invasor{de}Nächster Spieler" end
			UI.setAttribute("EndTurnButtonText", "text", endText)
			UI.setAttribute("EndTurnButtonAltText", "text", endText)


			--Automated-player presentation is centralized in automatedMainPanelRefresh().
			--Keep only the gameplay branch split here so normal-player Fame/Rep work is never run for the automated seat.
			local fameForUp=0
			if turnOrder[gStates.turnNumber].mage==gStates.positionMageKnight[5] then
				if scenarioList[gStates.scenarioRef][gStates.playersRef].dummyTacticSelection=="F" then turnOrder[gStates.turnNumber].fame=-1 else turnOrder[gStates.turnNumber].fame=999 end
			else--normal players
				if againstDragonAttendanceUIRefresh==nil or againstDragonAttendanceUIRefresh()~=true then UI.setAttribute("VolkareAttacked", "active", "false") end
				--Reputation is cached when its shield moves; no reputation-track zone scan is needed here.
				--Resource Tracker is manually controlled by the player; mainUIUpdate does not redraw it.

				--Work out how much more fame is needed until a level up is required.
				--Fame is already cached when the shield moves, so derive its board row instead of rereading the physical shield.
				local currentPlayer=turnOrder[gStates.turnNumber]
				local boardFame=currentPlayer.fame-(gStates.scoreIfLooped*currentPlayer.scoreLoop)
				if boardFame<0 then boardFame=0 end
				local fameVerticle=math.floor(math.sqrt(boardFame+1))
				if fameVerticle>gStates.rowsOnBoard then fameVerticle=gStates.rowsOnBoard end
				if currentPlayer.level<gStates.rowsOnBoard then
					local fameToLevel=math.floor(math.sqrt(currentPlayer.fame+1))
					if fameToLevel>gStates.rowsOnBoard then fameToLevel=gStates.rowsOnBoard end
					if fameVerticle<gStates.rowsOnBoard then fameForUp=((fameToLevel+1)*(fameToLevel+1))-1-currentPlayer.fame end
					--see if the current fame value would cause a level up
					currentPlayer.levelUp=0
					if fameToLevel>currentPlayer.level then
						if fameToLevel==2 or fameToLevel==4 or fameToLevel==6 or fameToLevel==8 or fameToLevel==10 or fameToLevel==12 or fameToLevel-currentPlayer.level>1 then gStates.levelingUp=true end
						currentPlayer.levelUp=fameToLevel-currentPlayer.level
						if gStates.preEndTurn==true and gStates.coopAssaultPhase~="combat" and levelUpcalled==false then levelUpcalled=true levelUp(gStates.turnNumber) end
					end
				end


				--Read all objects found in play area. Used to decide on off states of "End.." buttons, plus fame and rep gains
				local timeBending=false
				local avatarLocation=turnOrder[gStates.turnNumber].avatarLocation
				for a, b in pairs(gStates.gainList) do b.exists=false end
				if gStates.preEndTurn==false then
					local hiddenValleyKeep=false
					for _, obj in pairs(playerCombatObjects(turnOrder[gStates.turnNumber].seatPos)) do
						--Read Monster tokens in the current player's Play/Unit areas and update fame and reputation gain values.
						if obj.guid=="2eb8e2" then timeBending=true end
						if monsterPugs[obj.guid]~=nil and gStates.summonStates[obj.guid]~="summoned" and monsterPugs[obj.guid].pugType~="possessed" then
							local doMath=false
							local cityRepLoss=false
							for cityguid, monsters in pairs(gStates.cityMonsterQty) do
								if monsters[obj.guid]=="alive" then cityRepLoss=true break end
							end
							--If no entry found create a new entry for this token
							if gStates.gainList[obj.guid]==nil then
								--record token orientation and do the math if face up.
								gStates.gainList[obj.guid]={exists=true, siteRepLoss=0, keepHalfFame=false}
								if obj.is_face_down==false then
									gStates.gainList[obj.guid].tokenDirection=1
									doMath=true
								else
									gStates.gainList[obj.guid].tokenDirection=-1
								end
								--store leader overkil value
								if obj.guid==darkCrusader.token or obj.guid==elementalist.token then gStates.gainList[obj.guid].overkill=0 end
								--just existing is enough orientation has no effect
								--city rep loss
								for cityguid, monsters in pairs(gStates.cityMonsterQty) do
									if cityguid~=darkCrusader.terrainHex and cityguid~=elementalist.terrainHex and cityguid~=volkare.model and cityguid~=volkare.terrainHex and monsters[obj.guid]=="alive" and gStates.gainList[cityguid]==nil then
									 	turnOrder[gStates.turnNumber].repGain=turnOrder[gStates.turnNumber].repGain-1
										gStates.gainList[cityguid]={exists=true}
										if monsters.extra.megapolisPair~=nil and monsters.extra.megapolisPair~=cityguid then gStates.gainList[monsters.extra.megapolisPair]={exists=true} end
										break
									end
								end
								--Mage Tower and keep rep loss
								local count=0
								for c, d in pairs(gStates.gainList) do
									if c==gStates.hiddenValleyKeep[1] or c==gStates.hiddenValleyKeep[2] then count=count+1 end
								end
								if count==2 then hiddenValleyKeep=true end
								if cityRepLoss==false and
								   ((monsterPugs[obj.guid].pugType=="gray" and avatarLocation=="keep") or
	   							   (monsterPugs[obj.guid].pugType=="purple" and avatarLocation=="mage tower") or
								   ((obj.guid==gStates.hiddenValleyKeep[1] or obj.guid==gStates.hiddenValleyKeep[2]) and hiddenValleyKeep==false)) then
									turnOrder[gStates.turnNumber].repGain=turnOrder[gStates.turnNumber].repGain-1
									gStates.gainList[obj.guid].siteRepLoss=1
									if obj.guid==gStates.hiddenValleyKeep[1] or obj.guid==gStates.hiddenValleyKeep[2] then hiddenValleyKeep=true end
								end
								--monastery rep loss
								if avatarLocation~=nil then
									if monsterPugs[obj.guid].pugType=="purple" and gStates.monsterPlayLocation[obj.guid]==nil and avatarLocation=="monastery" then
										turnOrder[gStates.turnNumber].repGain=turnOrder[gStates.turnNumber].repGain-3
										gStates.gainList[obj.guid].siteRepLoss=3
									end
								end
								--Keep defenders use half Fame; remember this so reset does not depend on the avatar still being on the Keep.
								gStates.gainList[obj.guid].keepHalfFame=gStates.monsterPlayLocation[obj.guid]==nil and monsterPugs[obj.guid].pugType=="gray" and avatarLocation=="keep"
							end
							--existing token found, but it has been flipped
							if (obj.is_face_down==false and gStates.gainList[obj.guid].tokenDirection==-1)
							or (obj.is_face_down==true and gStates.gainList[obj.guid].tokenDirection==1) then
								gStates.gainList[obj.guid].tokenDirection=gStates.gainList[obj.guid].tokenDirection*-1
								doMath=true
							end
							--mines liberation corect fame and rep
							local minesLibMonster=false
							for terrainguid, monsters in pairs(gStates.mineMonsterQty) do
								if monsters[obj.guid]~=nil and gStates.gameScenario~="The Hidden Valley Blitz" then
									minesLibMonster=true--current monster has come from a mine
									if gStates.gameScenario~="The Realm of the Dead Blitz" then
										for monsterGUID, state in pairs(monsters) do
											if monsterGUID~=obj.guid then--found second mine monster
												if (state=="alive" and gStates.gainList[monsterGUID]~=nil) or state=="dead" then
													local x=1
													if terrainTiles[terrainguid].tileType=="core" then x=2 end--and gStates.gameScenario~="Mines Liberation"
													if gStates.gainList[terrainguid]==nil then
														gStates.gainList[terrainguid]={exists=true}
														gStates.gainList[terrainguid].tokenDirection=-1
														if gStates.gainList[obj.guid].tokenDirection==1 and (state=="dead" or gStates.gainList[monsterGUID].tokenDirection==1) then
															gStates.gainList[terrainguid].tokenDirection=1
															turnOrder[gStates.turnNumber].repGain=turnOrder[gStates.turnNumber].repGain+(x*gStates.gainList[terrainguid].tokenDirection)
														end
													else
														gStates.gainList[terrainguid].exists=true
														if (gStates.gainList[obj.guid].tokenDirection==1 and (state=="dead" or gStates.gainList[monsterGUID].tokenDirection==1) and gStates.gainList[terrainguid].tokenDirection==-1)
														or ((gStates.gainList[obj.guid].tokenDirection==-1 or (state=="alive" and gStates.gainList[monsterGUID].tokenDirection==-1)) and gStates.gainList[terrainguid].tokenDirection==1) then
															gStates.gainList[terrainguid].tokenDirection=gStates.gainList[terrainguid].tokenDirection*-1
															turnOrder[gStates.turnNumber].repGain=turnOrder[gStates.turnNumber].repGain+(x*gStates.gainList[terrainguid].tokenDirection)
														end
													end
													break
												end
											end
										end
									end
									break
								end
							end
							--Check if leader Overkill Changed
							if gStates.gainList[obj.guid].overkill~=nil and gStates.gainList[obj.guid].overkill~=gStates.leaderOverkill and obj.is_face_down==false then doMath=true end
							--if allowed add or subtract fame and reputation
							if doMath==true then
								--All tokens Fame
								if gStates.gainList[obj.guid].keepHalfFame==true then
									turnOrder[gStates.turnNumber].fameGain=turnOrder[gStates.turnNumber].fameGain+(math.ceil(monsterPugs[obj.guid].fame/2)*gStates.gainList[obj.guid].tokenDirection)
								else
									local multiple=1
									if obj.guid==darkCrusader.token or obj.guid==elementalist.token then
										if gStates.gainList[obj.guid].overkill~=gStates.leaderOverkill then turnOrder[gStates.turnNumber].fameGain=turnOrder[gStates.turnNumber].fameGain-(monsterPugs[obj.guid].fame*gStates.gainList[obj.guid].overkill) end
										multiple=gStates.leaderOverkill
										gStates.gainList[obj.guid].overkill=gStates.leaderOverkill
									end
									if gStates.druidNightsSummon~=nil then multiple=2 end
									local perks=0
									if gStates.monsterPerks[obj.guid]~=nil and gStates.monsterPerks[obj.guid].fame~=nil then perks=gStates.monsterPerks[obj.guid].fame end
									local questFame=monsterPugs[obj.guid].fame+perks
									--Dragon heads use custom reward resolution: airborne gives Round Fame once, while
									--landed heads give 1 Fame for each selected level reduction at combat cleanup.
									if gStates.monsterPerks[obj.guid]~=nil and (gStates.monsterPerks[obj.guid].dragonAirborne==true or gStates.monsterPerks[obj.guid].dragonGround==true) then questFame=0 end
									if gStates.monsterPerks[obj.guid]~=nil and gStates.monsterPerks[obj.guid].questHalfFame==true then questFame=math.ceil(questFame/2) end
									turnOrder[gStates.turnNumber].fameGain=turnOrder[gStates.turnNumber].fameGain+(questFame*multiple*gStates.gainList[obj.guid].tokenDirection)
								end
								local rewardPug,rewardPerk=monsterFactionRewardFameFallback(obj.guid)
								if rewardPug>0 or rewardPerk>0 then
									turnOrder[gStates.turnNumber].fameGain=turnOrder[gStates.turnNumber].fameGain+((rewardPug+rewardPerk)*gStates.gainList[obj.guid].tokenDirection)
									if gStates.druidNightsSummon~=nil then turnOrder[gStates.turnNumber].fameGain=turnOrder[gStates.turnNumber].fameGain+(rewardPug*gStates.gainList[obj.guid].tokenDirection) end
								end
								--Rampaging Reputation
								if gStates.monsterPlayLocation[obj.guid]~=nil and minesLibMonster==false and cityRepLoss==false and (gStates.ruinMonsters==nil or gStates.ruinMonsters[obj.guid]==nil) and
									(gStates.volkarePursuitEnemies==nil or gStates.volkarePursuitEnemies[obj.guid]~=true) and
									obj.guid~=gStates.hiddenValleyKeep[1] and obj.guid~=gStates.hiddenValleyKeep[2] then
									if monsterPugs[obj.guid].pugType=="green" or monsterPugs[obj.guid].pugType=="tan" then turnOrder[gStates.turnNumber].repGain=turnOrder[gStates.turnNumber].repGain+(1*gStates.gainList[obj.guid].tokenDirection) end --Why do I have Tan??
									if monsterPugs[obj.guid].pugType=="red" and gStates.gameScenario~="The Lost Relic Blitz" then turnOrder[gStates.turnNumber].repGain=turnOrder[gStates.turnNumber].repGain+(2*gStates.gainList[obj.guid].tokenDirection) end
								end
								--add hero and thug reputation
								if monsterPugs[obj.guid].reputation~=nil and (gStates.volkarePursuitEnemies==nil or gStates.volkarePursuitEnemies[obj.guid]~=true) then turnOrder[gStates.turnNumber].repGain=turnOrder[gStates.turnNumber].repGain+(monsterPugs[obj.guid].reputation*gStates.gainList[obj.guid].tokenDirection) end
							end
							gStates.gainList[obj.guid].exists=true
						end
					end
					--if a token has been removed subtract it's values
					hiddenValleyKeep=false
					for a, b in pairs(gStates.gainList) do
						if b.exists==false and monsterPugs[a]~=nil then
							local cityRepLoss=false
							for cityguid, monsters in pairs(gStates.cityMonsterQty) do
								if monsters[a]=="alive" then cityRepLoss=true break end
							end
							if b.tokenDirection==1 then
								--fame
								if b.keepHalfFame==true then
									turnOrder[gStates.turnNumber].fameGain=turnOrder[gStates.turnNumber].fameGain-math.ceil(monsterPugs[a].fame/2)
								else
									local multiple=1
									if a==darkCrusader.token or a==elementalist.token then multiple=gStates.leaderOverkill end
									if gStates.druidNightsSummon~=nil then multiple=2 end
									local perks=0
									if gStates.monsterPerks[a]~=nil and gStates.monsterPerks[a].fame~=nil then perks=gStates.monsterPerks[a].fame end
									local questFame=monsterPugs[a].fame+perks
									--Dragon rewards are owned by their custom combat tracker. Mirror the add-side suppression
									--here so removing a Dragon head cannot subtract ordinary monster Fame behind its back.
									if gStates.monsterPerks[a]~=nil and (gStates.monsterPerks[a].dragonAirborne==true or gStates.monsterPerks[a].dragonGround==true) then questFame=0 end
									if gStates.monsterPerks[a]~=nil and gStates.monsterPerks[a].questHalfFame==true then questFame=math.ceil(questFame/2) end
									turnOrder[gStates.turnNumber].fameGain=turnOrder[gStates.turnNumber].fameGain-(questFame*multiple)
								end
								local rewardPug,rewardPerk=monsterFactionRewardFameFallback(a)
								if rewardPug>0 or rewardPerk>0 then
									turnOrder[gStates.turnNumber].fameGain=turnOrder[gStates.turnNumber].fameGain-rewardPug-rewardPerk
									if gStates.druidNightsSummon~=nil then turnOrder[gStates.turnNumber].fameGain=turnOrder[gStates.turnNumber].fameGain-rewardPug end
								end
								--Mine Liberation Reputation gStates.gameScenario=="Mines Liberation"
								local minesLibMonster=false
								for terrainguid, monsters in pairs(gStates.mineMonsterQty) do
									if monsters[a]~=nil then
										minesLibMonster=true--current monster has come from a mine
										if gStates.gainList[terrainguid]~=nil and gStates.gainList[terrainguid].tokenDirection==1 then
											local x=1
											if terrainTiles[terrainguid].tileType=="core" then x=2 end
											turnOrder[gStates.turnNumber].repGain=turnOrder[gStates.turnNumber].repGain-x
											gStates.gainList[terrainguid]=nil
										end
										break
									end
								end
								--Rampaging reputation
								if gStates.monsterPlayLocation[a]~=nil and minesLibMonster==false and cityRepLoss==false and (gStates.ruinMonsters==nil or gStates.ruinMonsters[a]==nil) and
									(gStates.volkarePursuitEnemies==nil or gStates.volkarePursuitEnemies[a]~=true) and
									a~=gStates.hiddenValleyKeep[1] and a~=gStates.hiddenValleyKeep[2] then
									if monsterPugs[a].pugType=="green" or monsterPugs[a].pugType=="tan" then turnOrder[gStates.turnNumber].repGain=turnOrder[gStates.turnNumber].repGain-1 end
									if monsterPugs[a].pugType=="red" and gStates.gameScenario~="The Lost Relic Blitz" then turnOrder[gStates.turnNumber].repGain=turnOrder[gStates.turnNumber].repGain-2 end
								end
								--Hero and thug reputation
								if monsterPugs[a].reputation~=nil and (gStates.volkarePursuitEnemies==nil or gStates.volkarePursuitEnemies[a]~=true) then turnOrder[gStates.turnNumber].repGain=turnOrder[gStates.turnNumber].repGain-monsterPugs[a].reputation end
							end
							--City monsters
							for cityguid, monsters in pairs(gStates.cityMonsterQty) do
								if cityguid~=darkCrusader.terrainHex and cityguid~=elementalist.terrainHex and monsters[a]=="alive" and gStates.gainList[cityguid]~=nil then
									local found=false
									for monsterGUID, state in pairs(monsters) do
										if gStates.gainList[monsterGUID]~=nil then
											if gStates.gainList[monsterGUID].exists==true then found=true end
										end
									end
									if found==false then
										turnOrder[gStates.turnNumber].repGain=turnOrder[gStates.turnNumber].repGain+1
										gStates.gainList[cityguid]=nil
										if monsters.extra.megapolisPair~=nil and monsters.extra.megapolisPair~=cityguid then gStates.gainList[monsters.extra.megapolisPair]=nil end
									end
									break
								end
							end
							--Refund the exact temporary Keep/Mage Tower/Hidden Valley/Monastery assault loss applied when this token entered combat.
							--The avatar may already have been moved away to cancel/reset the combat, so do not re-check avatarLocation here.
							if (b.siteRepLoss or 0)>0 then turnOrder[gStates.turnNumber].repGain=turnOrder[gStates.turnNumber].repGain+b.siteRepLoss end
							gStates.gainList[a]=nil
						end
					end
					--Cap the gain values if exceeding limits
					if turnOrder[gStates.turnNumber].fameGain<0 then turnOrder[gStates.turnNumber].fameGain=0 end
				end


				--Change End turn button text if level up expected
				if gStates.coopAssaultPhase~="combat" and (fameForUp<=turnOrder[gStates.turnNumber].fameGain or turnOrder[gStates.turnNumber].levelUp>0) and turnOrder[gStates.turnNumber].fame<gStates.scoreIfLooped and fameVerticle<gStates.rowsOnBoard then
					UI.setAttribute("EndTurnButtonText", "text", "{en}End Turn & Level Up{ru}Конец хода и Повышение уровня{zh-tw}結束回合並升級{zh-cn}结束回合并升级{ko}차례 종료 & 레벨 업{es}Fin de turno y Subir Nivel{fr}Fin du Tour et Level Up{pt-br}Finalizar Turno e Subir Nível{de}Zug beenden und aufleveln")
					UI.setAttribute("EndTurnButtonAltText", "text", "{en}End Turn & Level Up{ru}Конец хода и Повышение уровня{zh-tw}結束回合並升級{zh-cn}结束回合并升级{ko}차례 종료 & 레벨 업{es}Fin de turno y Subir Nivel{fr}Fin du Tour et Level Up{pt-br}Finalizar Turno e Subir Nível{de}Zug beenden und aufleveln")
					local expectedFame=turnOrder[gStates.turnNumber].fame+turnOrder[gStates.turnNumber].fameGain
					local excessLevels=math.floor(math.sqrt(expectedFame+1))-turnOrder[gStates.turnNumber].level
					expectedFame=expectedFame+(1*excessLevels*gStates.blitz)
					excessLevels=math.floor(math.sqrt(expectedFame+1))-turnOrder[gStates.turnNumber].level
					if excessLevels>1 then
						UI.setAttribute("EndTurnButtonText", "text", joinLang({"{en}End Turn & {ru}Конец хода и {zh-tw}結束回合 & {zh-cn}结束回合 & {ko}차례 종료 & {es}Fin de Turno & {fr}Fin du tour & {pt-br}Fim do turno & {de}Zug beenden & ", excessLevels, "{en} Level Ups{ru} Повышения уровня{zh-tw} 等提升{zh-cn} 等提升{ko} 레벨 업{es} Subidas de nivel{fr} Montée en niveau{pt-br} Subidas de nível{de}Stufenaufstiege"}))
						UI.setAttribute("EndTurnButtonAltText", "text", joinLang({"{en}End Turn & {ru}Конец хода и {zh-tw}結束回合 & {zh-cn}结束回合 & {ko}차례 종료 & {es}Fin de Turno & {fr}Fin du tour & {pt-br}Fim do turno & {de}Zug beenden & ", excessLevels, "{en} Level Ups{ru} Повышения уровня{zh-tw} 等提升{zh-cn} 等提升{ko} 레벨 업{es} Subidas de nivel{fr} Montée en niveau{pt-br} Subidas de nível{de}Stufenaufstiege"}))
					end
					if nextPlayerEndCalled==true then
						UI.setAttribute("EndTurnButtonText", "text", "{en}End Turn, Rnd & Lev Up{ru}Завершить ход, раунд и повысить уровень{zh-tw}結束回合、回合輪並升級{zh-cn}结束回合、回合轮并升级{ko}턴·라운드 종료 및 레벨업{es}Fin de Turno, Ronda y Subir Nivel{fr}Fin du Tour, de la Manche et Niveau +{pt-br}Fim do Turno, Rodada e Subir Nível{de}Zug & Runde beenden, Stufe aufsteigen")
						UI.setAttribute("EndTurnButtonAltText", "text", "{en}End Turn, Rnd & Lev Up{ru}Завершить ход, раунд и повысить уровень{zh-tw}結束回合、回合輪並升級{zh-cn}结束回合、回合轮并升级{ko}턴·라운드 종료 및 레벨업{es}Fin de Turno, Ronda y Subir Nivel{fr}Fin du Tour, de la Manche et Niveau +{pt-br}Fim do Turno, Rodada e Subir Nível{de}Zug & Runde beenden, Stufe aufsteigen")
						if excessLevels>1 then
							UI.setAttribute("EndTurnButtonText", "text", joinLang({"{en}End Turn, Rnd & {ru}Конец хода, Раунда и {zh-tw}結束回合，輪次 & {zh-cn}结束回合，轮次 & {ko}차례 및 라운드 종료 & {es}Fin de turno, ronda y {fr}Fin du tour, Rnd & {pt-br}Fim de turno, ronda & {de}Zug, Runde beenden & ", excessLevels, "{en} Level Ups{ru} Повышения уровня{zh-tw} 等提升{zh-cn} 等提升{ko} 레벨 업{es} Subidas de nivel{fr} Montée en niveau{pt-br} Subidas de nível{de}Stufenaufstiege"}))
							UI.setAttribute("EndTurnButtonAltText", "text", joinLang({"{en}End Turn, Rnd & {ru}Конец хода, Раунда и {zh-tw}結束回合，輪次 & {zh-cn}结束回合，轮次 & {ko}차례 및 라운드 종료 & {es}Fin de turno, ronda y {fr}Fin du tour, Rnd & {pt-br}Fim de turno, ronda & {de}Zug, Runde beenden & ", excessLevels, "{en} Level Ups{ru} Повышения уровня{zh-tw} 等提升{zh-cn} 等提升{ko} 레벨 업{es} Subidas de nivel{fr} Montée en niveau{pt-br} Subidas de nível{de}Stufenaufstiege"}))
						end
					end
				end


				local function defeatedElementalistRampagerThisTurn()
					if gStates.gameScenario~="The Hidden Valley Blitz" then return false end
					for guid, gain in pairs(gStates.gainList or {}) do
						if gain.tokenDirection==1 and gStates.rampagingMonsters~=nil and gStates.rampagingMonsters[guid]==true and monsterEffectiveFaction(guid)=="Elem" then return true end
					end
					return false
				end

				--Change Reward text to be player location sensitive
				local rewardChecklistActive=(gStates.preEndTurn==true and gStates.coopAssaultPhase~="combat") or gameOver==true
				if rewardChecklistActive then
					local count=1
					local rewardText="{en}Have you:-\n{ru}Проверьте, что вы:-\n{zh-tw}你是否已經：\n{zh-cn}你是否已经：\n{ko}차례 종료 과정 진행:-\n{es}Has:-\n{fr}Avez-vous:-\n{pt-br}Você já:-\n{de}Hast du:-\n"
					local linefeed=false
					local questRewardPending,_,questRewardAction=apocalypseQuestRewardCompletionPendingForPlayer(gStates.turnNumber)
					if questRewardPending==true then
						local questReminder=(questRewardAction=="Fail" or questRewardAction=="CompleteOrFail") and "{en}. Completed/Failed the Quest.{ru}. Завершили/провалили задание.{zh-tw}. 完成／失敗任務。{zh-cn}. 完成/失败任务。{ko}. 퀘스트를 완료/실패 처리했습니다.{es}. Completaste/Fallaste la Misión.{fr}. Terminé/Échoué la Quête.{pt-br}. Concluiu/Falhou a Missão.{de}. Die Quest abgeschlossen/fehlgeschlagen." or "{en}. Completed/Progressed the Quest.{ru}. Завершили/продвинули задание.{zh-tw}. 完成／推進任務。{zh-cn}. 完成/推进任务。{ko}. 퀘스트를 완료/진행했습니다.{es}. Completaste/Avanzaste la Misión.{fr}. Terminé/Progressé dans la Quête.{pt-br}. Concluiu/Avançou a Missão.{de}. Die Quest abgeschlossen/fortgesetzt."
						rewardText=joinLang({rewardText,count,questReminder})
						count=count+1 linefeed=true
					end
					if apocalypseIsHereActive~=nil and apocalypseIsHereActive()==true and gStates.apocalypseHereForcedRevealPending==true then
						rewardText=joinLang({rewardText,count,"{en}. Explored for Horsemen.{ru}. Исследовали местность для Всадников.{zh-tw}. 為騎士探索了地圖。{zh-cn}. 为骑士探索了地图。{ko}. 기마병을 위해 탐험했습니다.{es}. Exploraste para los Jinetes.{fr}. Exploré pour les Cavaliers.{pt-br}. Explorou para os Cavaleiros.{de}. Für die Reiter erkundet."})
						count=count+1 linefeed=true
					end
					if steadyTempoPendingForSeat~=nil and steadyTempoPendingForSeat(currentPlayer.seatPos)==true then
						rewardText=joinLang({rewardText,count,"{en}. Resolved Steady Tempo.{ru}. Разыграли «Ровный темп».{zh-tw}. 已處理「穩定節奏」。{zh-cn}. 已处理“稳定节奏”。{ko}. 'Steady Tempo'를 처리했습니다.{es}. Resolviste Ritmo Constante.{fr}. Résolu Rythme Régulier.{pt-br}. Resolveu Ritmo Constante.{de}. Gleichmäßiges Tempo abgehandelt."})
						count=count+1 linefeed=true
					end
					local pendingCrystal=gStates.mineClaimPending
					if pendingCrystal~=nil and pendingCrystal.playerIndex==gStates.turnNumber then
						local crystalSource=pendingCrystal.source=="Quest" and "{en}Quest{ru}задания{zh-tw}任務{zh-cn}任务{ko}퀘스트{es}Misión{fr}Quête{pt-br}Missão{de}Quest" or "{en}Mine{ru}шахты{zh-tw}礦山{zh-cn}矿山{ko}광산{es}Mina{fr}Mine{pt-br}Mina{de}Mine"
						rewardText=joinLang({rewardText,count,"{en}. Claimed your {ru}. Получили кристалл {zh-tw}. 已領取你的{zh-cn}. 已领取你的{ko}. {es}. Reclamaste tu Cristal de {fr}. Récupéré votre Cristal de {pt-br}. Coletou seu Cristal de {de}. Deinen ",crystalSource,"{en} Crystal.{ru}.{zh-tw}水晶。{zh-cn}水晶。{ko} 크리스털을 획득했습니다.{es}.{fr}.{pt-br}.{de}-Kristall genommen."})
						count=count+1 linefeed=true
					end
					if linefeed==true then rewardText=joinLang({rewardText,"\n"}) linefeed=false end
					if gStates.gameScenario=="Mines Liberation" and gStates.endRoundCalled==true and gStates.turnForfeited==false then
						rewardText=joinLang({rewardText, count, "{en}. Collected 1 Crystal from your Liberated Mine(s){ru}. Получили 1 кристалл из ваших освобожденных шахт{zh-tw}. 從你解放的礦山獲得 1 顆魔晶{zh-cn}. 从你解放的矿山获得 1 块魔晶{ko}. 해방한 광산에서 수정 1개 획득{es}. Obtenido 1 Cristal de tus Minas liberadas{fr}. Obtenu 1 cristal de vos Mines libérées{pt-br}. Ganhou 1 Cristal das suas Minas libertadas{de}. 1 Kristall aus deinen befreiten Minen erhalten"})
						count=count+1 linefeed=true
					end
					if gStates.gameScenario=="Druid Nights" and gStates.druidNightsSummon~=nil then
						local crystalReward=gStates.druidNightsCrystalReward or gStates.druidNightsSummon
						rewardText=joinLang({rewardText, count, "{en}. Gained {ru}. Получено {zh-tw}。獲得 {zh-cn}。获得 {ko}. 획득: {es}. Obtuvo {fr}. Gagné {pt-br}. Ganhou {de}. Erhalten: ", tostring(crystalReward), "{en} Random Crystal(s) from incantation{ru} случайных кристалла(ов) от заклинания{zh-tw} 個由咒語產生的隨機魔力水晶{zh-cn} 个由咒语产生的随机魔力水晶{ko}개의 주문으로 얻은 무작위 마나 수정{es} Cristal(es) aleatorio(s) por el encantamiento{fr} Cristal(aux) aléatoire(s) grâce à l’incantation{pt-br} Cristal(is) aleatório(s) da invocação{de} zufällige(n) Kristall(e) durch die Beschwörung"})
						count=count+1 linefeed=true
					end
					if defeatedElementalistRampagerThisTurn()==true then
						rewardText=joinLang({rewardText, count, "{en}. Explored (Defeated Elementalist){ru}. Исследовали (победили Элементалиста){zh-tw}. 已探索（擊敗元素使）{zh-cn}. 已探索（击败元素使）{ko}. 탐험 완료 (원소술사 처치){es}. Exploraste (Elementalista derrotado){fr}. Exploré (Élémentaliste vaincu){pt-br}. Explorou (Elementalista derrotado){de}. Erkundet (Elementarmagier besiegt)"})
						count=count+1 linefeed=true
					end
					if avatarLocation~=nil then
						--see if a matching shield is near the avatar
						local nearbyOwnShield=rewardNearbyOwnShield(gStates.turnNumber,avatarLocation)

						--Victory Shield
						if (avatarLocation=="glade" and gStates.gameScenario=="Druid Nights") then
							if nearbyOwnShield=="false" and gStates.turnForfeited==false then
								rewardText=joinLang({rewardText, count, "{en}. Placed a Victory Shield{ru}. Разместили Жетон щита{zh-tw}. 放置勝利盾徽{zh-cn}. 放置胜利盾徽{ko}. 방패 토큰 놓기{es}. Colocado un Escudo de Conquista.{fr}. Placé un Bouclier de Victoire{pt-br}. Colocou um Escudo de Vitória.{de}. Einen Siegesschild platziert"})
								count=count+1 linefeed=true
							end
						end
						--Victory Shield
						if avatarLocation=="graveyard" and gStates.gameScenario=="The Realm of the Dead Blitz" and nearbyOwnShield=="false" and gStates.turnForfeited==false then
							rewardText=joinLang({rewardText, count, "{en}. Paid to Seal the Graveyard{ru}. Заплатили за запечатывание Кладбища{zh-tw}. 支付魔力來封印墓地{zh-cn}. 支付魔力来封印墓地{ko}. 묘지 봉인 마나 지불(선택){es}. Pagado para Sellar el Cementerio{fr}. Payé pour Sceller le Cimetière{pt-br}Pago para Selar o Cemitério{de}. Für die Versiegelung des Friedhofs bezahlt."})
							count=count+1 linefeed=true
						end
						if linefeed==true then rewardText=joinLang({rewardText, "\n"}) linefeed=false end
						if rewardRetreatRequired(gStates.turnNumber,avatarLocation,nearbyOwnShield)==true then
							rewardText=joinLang({rewardText, count, "{en}. Retreated to a Safe space{ru}. Отступили в Безопасное место{zh-tw}. 撤離到一個安全位置{zh-cn}. 撤离到一个安全位置{ko}. 안전한 칸으로 후퇴{es}. Acabado en un Espacio Seguro{fr}. Retraité dans un espace sûr{pt-br}. Recuou para um espaço seguro{de}. Dich in ein sicheres Feld zurückgezogen"})
							count=count+1 linefeed=true
						end
						if linefeed==true then rewardText=joinLang({rewardText, "\n"}) linefeed=false end
						if gStates.turnForfeited==false and gladeFreeCheck()==true and (avatarLocation=="glade" or avatarLocation=="hidden valley" or
						(gStates.gameScenario=="The War of Four" and (avatarLocation=="necropolis" or avatarLocation=="graveyard"))) then
							rewardText=joinLang({rewardText, count, "{en}. Removed One Wound{ru}. Вернули в стопку одну рану{zh-tw}. 移除一點創傷{zh-cn}. 移除一点创伤{ko}. 부상 하나 제거{es}. Eliminado una Herida{fr}. Suppression d'une blessure{pt-br}. Removeu Um Ferimento{de}. Eine Wunde wurde entfernt"})
							count=count+1 linefeed=true
						end
						if linefeed==true then rewardText=joinLang({rewardText, "\n"}) linefeed=false end
						if gStates.turnForfeited==false and ((gStates.shieldsDropped[nearbyOwnShield]~=nil and (avatarLocation=="mage tower" or avatarLocation=="labyrinth"	or avatarLocation=="maze" or avatarLocation=="monastery" or avatarLocation=="monster den" or avatarLocation=="dungeon" or avatarLocation=="spawning grounds" or avatarLocation=="tomb" or avatarLocation=="ziggurat" or avatarLocation=="pyramid"
						or (avatarLocation=="ruin" and gStates.crytalRuin~=true)
						or ((avatarLocation=="graveyard" or avatarLocation=="glade") and gStates.gameScenario=="Life and Death")))
						or (avatarLocation=="graveyard" and gStates.gameScenario=="The Realm of the Dead Blitz")) then
							rewardText=joinLang({rewardText, count, "{en}. Gained Site Conquest Rewards{ru}. Получили награды за завоевание Места{zh-tw}. 獲得地點的征服獎勵{zh-cn}. 获得地点的征服奖励{ko}. 장소 정복 보상 획득{es}. Obtenido la Recompensa de Conquista{fr}. Récompenses de conquête de site obtenues{pt-br}. Ganhou As Recompensas de Conquista{de}. Gewonnene Eroberungsbelohnungen"})
							count=count+1 linefeed=true
						end
					end
					if linefeed==true then rewardText=joinLang({rewardText, "\n"}) linefeed=false end
					if gStates.levelingUp==true then
						if currentPlayer.skipHeroChallengeSkillReminder~=true then
							rewardText=joinLang({rewardText, count, "{en}. Gained a New Skill Token{ru}. Получили новый Жетон навыка{zh-tw}. 獲得新的技能{zh-cn}. 获得新的技能{ko}. 새로운 스킬 획득{es}. Obtuvo una ficha de habilidad nueva{fr}. Vous avez obtenu un nouveau jeton de compétence{pt-br}. Ganhou uma Nova Ficha de Habilidade{de}. Einen neuen Fertigkeitsmarker erhalten"})
							count=count+1 rewardText=joinLang({rewardText, "\n"})
						end
						rewardText=joinLang({rewardText, count, "{en}. Gained a New Advanced Action{ru}. Получили новое Особое действие{zh-tw}. 獲得新的高級行動卡{zh-cn}. 获得新的高级行动卡{ko}. 새로운 상급 액션 획득{es}. Obtuvo una nueva acción avanzada{fr}. Vous avez obtenu une nouvelle action avancée{pt-br}. Ganhou uma Nova Ação Avançada{de}. Eine neue fortgeschrittene Aktion erhalten"})
						count=count+1 linefeed=true
					end
					if linefeed==true then rewardText=joinLang({rewardText, "\n"}) linefeed=false end
					if gStates.volkareArmyReduced==true and gStates.endGameAchieved=="false" and gStates.volkareState=="Attacking City" then
						if gStates.volkareModel~=nil and getObjectFromGUID(gStates.volkareModel)~=nil then getObjectFromGUID(gStates.volkareModel).unlock() end
					end
					if gStates.turnForfeited==true then
						rewardText=joinLang({rewardText, count, "{en}. Forfeit Turn, no site Rewards{ru}. Пропустили ход, и не получаете Награды за Места{zh-tw}. 放棄回合，無地點獎勵{zh-cn}. 放弃回合，无地点奖励{ko}. 차례 포기, 장소 혜택 사용불가{es}. Saltar Turno, sin Recompensas de Lugar{fr}. Forfait Turn, pas de récompenses de site{pt-br}. Desistir do Turno. Sem Recompensas de Local{de}. Zug ausgelassen, keine Ortsbelohnung"})
						count=count+1 linefeed=true
					end
					if linefeed==true then rewardText=joinLang({rewardText, "\n"}) linefeed=false end
					if gameOver==false then
						rewardText=joinLang({rewardText, count, "{en}. Confirmed your hand size{ru}. Проверили предел карт в вашей руке{zh-tw}. 更新你的手牌上限{zh-cn}. 更新你的手牌上限{ko}. 카드 보유 제한 체크{es}. Confirmado tu tamaño de Mano{fr}. Confirmé votre taille de main{pt-br}. Confirmou seu tamanho de Mão{de}. Handkartenzahl bestätigt"})
					else
						rewardText=joinLang({rewardText, count, "{en}. Looked at your final Score{ru}. Посмотрели на ваш окончательный результат{zh-tw}. 查看你的最終分數{zh-cn}. 查看你的最终分数{ko}. 최종 점수 확인{es}. Revisado tu Puntuación Final{fr}. Regardé votre score final{pt-br}. Ollhou para a sua Pontuação Final{de}. Deine Endpunktzahl angesehen"})
					end
					UI.setAttribute("RewardNotes", "text", rewardText)
				end


				--lock end turn button if no cards are played or discarded
				--discard object detection
				local discardAreaCards=0
				local discardZoneGUID=deedDeckDiscardZones[turnOrder[gStates.turnNumber].seatPos]
				local discardZone=discardZoneGUID~=nil and getObjectFromGUID(discardZoneGUID) or nil
				if discardZone==nil then return end
				for _, b in pairs(discardZone.getObjects()) do
					if b.type=="Card" then discardAreaCards=1 break end
					if b.type=="Deck" then discardAreaCards=b.getQuantity() break end
				end
				UI.setAttribute("EndTurnButton", "tooltip", "At least one card must be played or discarded to 'End Your Turn'.")
				if gStates.endRoundCalled==true then UI.setAttribute("EndTurnButton", "tooltip", "") end
				local coopCombatButtonLocked=gStates.coopAssaultPhase=="combat" and (gStates.preEndTurn==true or playerAreaCardCount<1)
				if (playerAreaCardCount<1 and gStates.endRoundCalled==false and discardAreaCards==turnOrder[gStates.turnNumber].discardCount) or coopCombatButtonLocked or gStates.tacticShown==true or gStates.tacticRemove==true then
					UI.setAttribute("EndTurnButton", "interactable", "False")
					UI.setAttribute("EndTurnButtonImage", "image", "Sliced Button/Button New Deactive")
					UI.setAttribute("EndTurnButtonAlt", "interactable", "False")
					UI.setAttribute("EndTurnButtonAltImage", "image", "Sliced Button/Button New Deactive")
					UI.setAttribute("ExtraTurnTacticButton", "interactable", "False")
					UI.setAttribute("ExtraTurnTacticButtonImage", "image", "Sliced Button/Button New Deactive")
				end

				--Show extra-turn button. If Time Bending and Day Tactic 6 are both available, ask which one is being used.
				local tacticSixAvailable=turnOrder[gStates.turnNumber].tactic==6 and gStates.dayRound==true and gStates.tacticSixState~="Used"
				local timeBendingAvailable=timeBending==true
				if (tacticSixAvailable or timeBendingAvailable) and gStates.tacticRemove==false and gStates.tacticShown==false then
					UI.setAttribute("ExtraTurnTactic", "active", "true")
					if tacticSixAvailable and timeBendingAvailable then
						UI.setAttribute("ExtraTurnTacticButtonText", "text", "{en}Extra Turn{ru}Дополнительный ход{zh-tw}額外回合{zh-cn}额外回合{ko}추가 턴{es}Turno Extra{fr}Tour Supplémentaire{pt-br}Turno Extra{de}Extra-Zug")
					elseif timeBendingAvailable then
						UI.setAttribute("ExtraTurnTacticButtonText", "text", "{en}Time Bend{ru}Изгиб Времени{zh-tw}時間扭曲{zh-cn}时间扭曲{ko}시간 왜곡{es}Salto en el Tiempo{fr}Courbe du Temps{pt-br}Dobrar Tempo{de}Zeitkrümmung")
					else
						UI.setAttribute("ExtraTurnTacticButtonText", "text", "{en}Use Tactic{ru}Использовать Тактику{zh-tw}使用戰術卡{zh-cn}使用战术卡{ko}전략카드 사용{es}Usar la Táctica{fr}Utiliser la Tactique{pt-br}Usar Tática{de}Taktik Benutzen")
					end
				end

				--Update Fame and Reputation menus only when their displayed values change.
				local fameRepPlayer=turnOrder[gStates.turnNumber]
				local fameRepKey=table.concat({gStates.turnNumber, fameRepPlayer.fameGain, fameRepPlayer.repGain, fameRepPlayer.reputation}, "|")
				if endTurnFameRepCache~=fameRepKey then
					endTurnFameRepCache=fameRepKey
					local limetedRepGain=fameRepPlayer.repGain
					if limetedRepGain<(-7-fameRepPlayer.reputation) then limetedRepGain=(-7-fameRepPlayer.reputation) end
					if limetedRepGain>(7-fameRepPlayer.reputation) then limetedRepGain=(7-fameRepPlayer.reputation) end
					UI.setAttribute("EndRoundPlusFameText", "text", joinLang({"{en}Gain {ru}Получить {zh-tw}增加 {zh-cn}增加 {ko}획득 {es}Ganar {fr}Gagner {pt-br}Ganhe {de}Erhalte ", tostring(fameRepPlayer.fameGain), "{en} Fame{ru} Славу(ы){zh-tw} 名望{zh-cn} 名望{ko} 명성{es} Fama{fr} Gloire{pt-br} Fama{de} Ruhm"}))
					local prefix="{en}Lose {ru}Потерять {zh-tw}減少 {zh-cn}减少 {ko}감소 {es}Perder {fr}Perdez {pt-br}Perca {de}Verliere "
					if limetedRepGain>-1 then prefix="{en}Gain {ru}Получить {zh-tw}增加 {zh-cn}增加 {ko}획득 {es}Ganar {fr}Gagner {pt-br}Ganhe {de}Erhalte " end
					local sufix1="{en} Reputation{ru} Репутацию(и){zh-tw} 聲譽{zh-cn} 声誉{ko} 평판{es} Reputación{fr} Réputation{pt-br} Reputação{de} Ansehen"
					if limetedRepGain~=0 and (limetedRepGain<=(-7-fameRepPlayer.reputation) or limetedRepGain>=(7-fameRepPlayer.reputation)) then
						sufix1="{en} Rep. Max.{ru} Макс. Реп.{zh-tw} 聲譽到最底{zh-cn} 声誉到最底{ko} 최대 평판{es} Rep. Máx.{fr} Rép. Max.{pt-br} Rep. Máx.{de} Ruf Max."
					end
					local sufix2=""
					if limetedRepGain~=0 and reputationTable[fameRepPlayer.reputation+limetedRepGain]~=nil then
						sufix2=" ('"..reputationTable[fameRepPlayer.reputation+limetedRepGain].repDisplay.."')"
						if fameRepPlayer.reputation+limetedRepGain<=-7 then sufix2=" ('X')" end
					end
					UI.setAttribute("EndRoundPlusRepText", "text", joinLang({prefix, tostring(math.abs(limetedRepGain)), sufix1, sufix2}))
				end
			end


			--Deed-pile events refresh End Round directly. During routine play/discard object updates,
			--played-card count only matters once the current deed pile is actually empty.
			local routineZoneUpdate=source=="Object entered into play area" or source=="Object removed from zone"
			local currentSeat=turnOrder[gStates.turnNumber].seatPos
			if routineZoneUpdate~=true or endRoundDeedHasCards[currentSeat]~=true then refreshEndRoundState(playerAreaCardCount) end


			local notice=false
			local UIColor=positionToColor(gStates.turnNumber)
			--Display Info Pannel if pursuing monsters have two options.
			if gStates.pursuitTwoOption==true then
				UI.setAttribute("NoticeText", "Text", "{en}Pursuing Monster(s) have two Options for the current Player to decide between.{ru}Игрок, чьего героя преследуют, решает, на какую из двух клеток переместится враг.{zh-tw}追击的怪物有两个选项供当前玩家选择. {zh-cn}追击的怪物有两个选项供当前玩家选择. {ko}현재 플레이어는 추적 중인 몬스터의 두 옵션 중 하나를 결정하세요.{es}Los Monstruos que persiguen tienen dos Opciones para que el Jugador actual decida entre ellas.{fr}Les Monstres Poursuivants ont deux Options entre lesquelles le Joueur actuel doit choisir.{pt-br}Monstro(s) Perseguidor(es) tem 2 opções para o jogador atual escolher.{de}Verfolgende Monster haben zwei Optionen, zwischen denen der aktuelle Spieler wählen kann.")
				UI.setAttribute("NoticeBoard", "visibility", "")
				UI.setAttribute("NoticeBoard", "height", "50")
				notice=true
			end

			--Display Info pannel if player needs to deploy a tomb or dungeon token
			if #gStates.locationPlace>0 then
				local pendingSecretName=dungeonLordsPendingSecretName(gStates.locationPlace[#gStates.locationPlace])
				local site="{en}Village{ru}Деревней{zh-tw}\n要求2: 挨着刚翻开的村庄{zh-cn}\n要求2: 挨着刚翻开的村庄{ko}마을{es}una Aldea{fr}Village{pt-br}Vila{de}Dorf"
				if pendingSecretName=="Secret Tomb" then site="{en}Monastery{ru}Монастырем{zh-tw}\n要求2: 挨着刚翻开的修道院{zh-cn}\n要求2: 挨着刚翻开的修道院{ko}수도원{es}un Monasterio{fr}Monastère{pt-br}Mosteiro{de}Kloster" end
				UI.setAttribute("NoticeText", "Text", joinLang({"{en}Place a {ru}Поместите жетон {zh-tw}在地图上放置一个{zh-cn}在地图上放置一个{ko}{es}Coloca una ficha de {fr}Placer un{pt-br}Coloque uma ficha de {de}Platziere ein ", translateWord[pendingSecretName], "{en} token on an accessible non-swamp, non-feature space next to the {ru} на любую доступную клетку без болота на которой нет никаких мест, соседнюю с {zh-tw}\n要求1: 可进入、非沼泽、上面无地点{zh-cn}\n要求1: 可进入、非沼泽、上面无地点{ko}을 비어있고, 늪이 아니면서 다음의 장소 주변인 칸에 설치하세요: {es} en un espacio accesible que no sea un pantano, o no tenga ningún elemento adyacente a {fr} jeton sur un espace non marécageux accessible à côté du {pt-br} em um espaço acessível sem ser pântano ou que já tenha algo próximo a {de} plättchen auf ein zugängliches Nicht-Sumpf-, Nicht-Feature-Feld neben dem ", site}))
				UI.setAttribute("NoticeBoard", "visibility", "")
				UI.setAttribute("NoticeBoard", "height", "50")
				notice=true
			end

			--Display Info pannel if End of round is immenant
			if ((nextPlayerEndCalled==true and gStates.playerCount>1) or (gStates.endRoundCalled==true and gStates.playerCount==1)) and
				(gStates.preEndTurn==true or turnOrder[gStates.turnNumber].mage==gStates.positionMageKnight[5]) and gStates.currentRound<gStates.rounds then
				local boxHeight=50
				local endRoundText="{en}The game is about to experience end of round updates.\nPut Banners in discard if desired.{ru}Конец раунда. Скрипт произведет нужные обновления.\nЕсли хотите, можете сбросить знамёна с отрядов.{zh-tw}回合即将结束, 如果需要, 将清理弃牌区{zh-cn}回合即将结束, 如果需要, 将清理弃牌区{ko}이제 라운드가 종료됩니다.\n원한다면 지금 깃발 장착을 해제하세요.{es}El juego está a punto de experimentar actualizaciones de fin de ronda.\nDescarte los Banners si lo desea.{fr}Le jeu est sur le point de connaître des mises à jour de fin de manche.\nMettez les bannières au rebut si vous le souhaitez.{pt-br}O jogo está prestes a executar as atualizações de fim de Rodada.<size=6>\n\n</size>Coloque os Estandartes na pilha de descarte se assim desejar.{de}Das Spiel wird zum Ende der Runde aktualisiert.\nLegt die Banner auf den Ablagestapel, falls gewünscht."
				if gStates.playerCount==1 then endRoundText=joinLang({endRoundText, "{en}\nDiscard the 2nd offer if playing 'Control over the Offers'{ru}\nПри 'Контроле над доступными картами', сбросьте среднюю доступную карту{zh-tw}\n如果使用“控制供应区”变体规则, 弃掉最左侧两个供应的卡牌{zh-cn}\n如果使用“控制供应区”变体规则, 弃掉最左侧两个供应的卡牌{ko}\n변형 규칙 '공급처 갱신 조정'을 적용하려면 지금 하세요.{es}\nDescarta la segunda oferta si juegas 'Control sobre las Ofertas'{fr}\nJetez la 2e offre si vous jouez à 'Contrôle des Offres'{pt-br}\nDiscarte a 2a oferta se estiver jogando com 'Controle sobre ofertas'{de}\nWirf das 2. Angebot ab, wenn du 'Kontrolle über die Angebote' spielst."}) boxHeight=boxHeight+20 end
				if gStates.gameScenario=="Mines Liberation" then endRoundText=joinLang({endRoundText, "{en}\nCollect 1 Crystal from your liberated Mine(s).{ru}Получите 1 кристалл из каждой освобожденной вами шахты.{zh-tw}从你解放的每个矿山获得 1 块魔晶。{zh-cn}从你解放的每个矿山获得 1 块魔晶。{ko}\n해방한 각 광산에서 수정 1개를 얻으세요.{es}\nRecoge 1 Cristal de cada Mina que hayas liberado.{fr}\nRécupérez 1 cristal de chaque Mine que vous avez libérée.{pt-br}\nColete 1 Cristal de cada Mina que você libertou.{de}\nSammle 1 Kristall aus jeder Mine, die du befreit hast."}) boxHeight=boxHeight+20 end
				UI.setAttribute("NoticeBoard", "height", boxHeight)
				UI.setAttribute("NoticeText", "Text", endRoundText)
				UI.setAttribute("NoticeBoard", "visibility", "")
				notice=true
			end

			--Display Info pannel if tactics are shown
			UI.setAttribute("DrawOne", "interactable", "true")
			UI.setAttribute("DrawOneImage", "image", "Sliced Button/Button New Active")
			if gStates.tacticRemove==true or gStates.tacticShown==true then
				if gStates.tacticRemove==true then
					UI.setAttribute("NoticeText", "Text", "{en}Choose tactic(s) to be removed from the Game{ru}Выберите тактику(и), которая будет удалена из игры{zh-tw}选择要从游戏中移除的战术卡{zh-cn}选择要从游戏中移除的战术卡{ko}게임에서 제거할 전략 카드를 고르세요.{es}Elige la táctica(s) que quieres eliminar del Juego{fr}Choisissez la tactique(s) à retirer du Jeu{pt-br}Escolha tática(s) a ser(em) removida(s) do jogo.{de}Wähle die Taktik(en), die aus dem Spiel entfernt werden sollen")
				else
					UI.setAttribute("NoticeText", "Text", joinLang({translateWord[turnOrder[gStates.turnNumber].mage], "{en} needs to choose a tactic from the center{ru} должен(на) выбрать Тактику из центра{zh-tw}需要从中间选择一个战术{zh-cn}需要从中间选择一个战术{ko}의 전략 카드를 선택하세요.{es} necesita elegir una táctica del centro{fr} doit choisir une tactique du centre{pt-br} precisa escolher uma tática do centro.{de} muss eine Taktik aus dem Zentrum wählen"}))
				end
				UI.setAttribute("DrawOne", "interactable", "False")
				UI.setAttribute("DrawOneImage", "image", "Sliced Button/Button New Deactive")
				UI.setAttribute("NoticeBoard", "visibility", "")
				UI.setAttribute("NoticeBoard", "height", "50")
				notice=true
			else --turn off help notes after first round of tactic selection
				if gStates.help==true then DisplayHelp(nil, "-1", "Game Started") end
			end

			--Remove or Display the notice board as needed
			if notice==false and gStates.noticeShown==true then
				UI.hide("NoticeBoard")
				gStates.noticeShown=false
			end
			if notice==true and gStates.noticeShown==false then
				UI.show("NoticeBoard")
				gStates.noticeShown=true
			end



			UI.setAttribute("RewardCheck", "active", "false")
			UI.setAttribute("EndGameButton", "active", "false")
			if (gStates.preEndTurn==true and gStates.coopAssaultPhase~="combat") or gameOver==true then
				UI.setAttribute("RewardCheck", "active", "true")
				UI.setAttribute("EndGameButton", "active", "true")
				if gStates.timeBending=="Started" and gStates.turnNumber==gStates.realTurn then--or (gStates.endRoundCalled==true and gStates.currentRound>=gStates.rounds)
					UI.setAttribute("EndGameButton", "active", "false")
				end
			end
			--Steady Tempo must resolve before Rewards Claimed can refresh the hand, because Top can be the next card drawn.
			if steadyTempoUpdateRewardGate~=nil and turnOrder[gStates.turnNumber]~=nil then steadyTempoUpdateRewardGate(turnOrder[gStates.turnNumber].seatPos) end
			--Rewards Claimed remains clickable during a soft lock; a faint orange tint shows that clicking it
			--will currently produce a reminder instead of advancing. The tint clears when the requirement is
			--resolved or when the shared soft-lock window expires.
			local rewardSoftLockTint=rewardClaimSoftLockPending~=nil and rewardClaimSoftLockPending(gStates.turnNumber)
			UI.setAttribute("PreEndTurnImage","color",rewardSoftLockTint and "rgb(1,0.86,0.68)" or "white")
			if UIColor=="Black" then UIColor="rgb(0,0,0)" end
			UI.setAttribute("MainGameNotes", "color", UIColor)
			UI.setAttribute("RewardNotes", "color", UIColor)


			local currentPlayer=turnOrder[gStates.turnNumber]
			local meditationBonus=(gStates.meditationDrawBonus~=nil and gStates.meditationDrawBonus[gStates.turnNumber]) or 0
			local drawHandSize=currentPlayer.hand+currentPlayer.handBonus+gStates.tactic4HandBonus+meditationBonus
			local cityShields=currentCityShieldInfluence(currentPlayer)
			local handMainKey=table.concat({gStates.turnNumber, currentPlayer.mage, currentPlayer.hand, currentPlayer.handBonus, gStates.tactic4HandBonus, meditationBonus, currentPlayer.baseHand, currentPlayer.reputation, cityShields, currentPlayer.fame, currentPlayer.level, fameForUp, gStates.positionMageKnight[5]}, "|")
			if handMainTextCache~=handMainKey then
				handMainTextCache=handMainKey
				UI.setAttribute("DrawHandText", "text", joinLang({"{en}Draw up to {ru}Добрать до {zh-tw}抽滿至 {zh-cn}抽满至 {ko}카드 보유 제한 {es}Roba hasta {fr}Piochez jusqu'à {pt-br}Compre até {de}Zieh auf ", tostring(drawHandSize), "{en} cards{ru} карт{zh-tw} 張手牌{zh-cn} 张手牌{ko} 장{es} cartas{fr} cartes{pt-br} cartas{de} karten"}))
				UI.setAttribute("DrawHandText", "color", drawHandSize>currentPlayer.baseHand and "rgb(0.4, 0.1, 0.2)" or "Black")
				if currentPlayer.mage~=gStates.positionMageKnight[5] then
					local repDisplay=reputationTable[currentPlayer.reputation].repDisplay
					local repLabel="{en}'s Turn</size><size=6>\n\n</size>Reputation = {ru} Ходит</size><size=6>\n\n</size>Репутация =  {zh-tw}的回合</size><size=6>\n\n</size>聲譽 = {zh-cn}的回合</size><size=6>\n\n</size>声誉 = {ko} 차례</size><size=6>\n\n</size>평판 = {es}</size><size=6>\n\n</size>Reputación = {fr}</size><size=6>\n\n</size>Réputation = {pt-br}</size><size=6>\n\n</size>Reputação = {de}'s Zug</size><size=6>\n\n</size>Ansehen = "
					if cityShields>0 and repDisplay~="No Interaction" then
						local repValue=tonumber(repDisplay) or 0
						repLabel="{en}'s Turn</size><size=6>\n\n</size>Rep Bonus = {ru} Ходит</size><size=6>\n\n</size>Бонус реп. = {zh-tw}的回合</size><size=6>\n\n</size>聲譽加成 = {zh-cn}的回合</size><size=6>\n\n</size>声誉加成 = {ko} 차례</size><size=6>\n\n</size>평판 보너스 = {es}</size><size=6>\n\n</size>Bonif. Rep. = {fr}</size><size=6>\n\n</size>Bonus Rép. = {pt-br}</size><size=6>\n\n</size>Bônus Rep. = {de}'s Zug</size><size=6>\n\n</size>Rufbonus = "
						repDisplay=joinLang({signedBonus(repValue+cityShields), " (", signedBonus(repValue), "{en} Rep + {ru} Реп. + {zh-tw} 聲譽 + {zh-cn} 声誉 + {ko} 평판 + {es} Rep. + {fr} Rép. + {pt-br} Rep. + {de} Ruf + ", cityShields, "{en} City){ru} Город){zh-tw} 城市){zh-cn} 城市){ko} 도시){es} Ciudad){fr} Ville){pt-br} Cidade){de} Stadt)"})
					end
					local mainText=joinLang({"{en}<size=25>{ru}<size=25>{zh-tw}<size=25>{zh-cn}<size=25>{ko}<size=25>{es}<size=25>Turno de {fr}<size=25>Au tour de {pt-br}<size=25>Turno de {de}<size=25>", translateWord[currentPlayer.mage], repLabel, repDisplay, "{en}\nFame = {ru}\nСлава = {zh-tw}\n名望 = {zh-cn}\n名望 = {ko}\n명성 = {es}\nFama = {fr}\nGloire = {pt-br}\nFama = {de}\nRuhm = ", currentPlayer.fame})
					local levelUpType="{en}\n(Skill & Advanced Action){ru}\n(Навык и Особое действие){zh-tw}\n（技能和高級行動）{zh-cn}\n（技能和高级行动）{ko}\n(스킬 및 상급 액션){es}\n(Habilidad y Acción Avanzada){fr}\n(Compétence et Action Avancée){pt-br}\n(Habilidade e Ação Avançada){de}\n(Fähigkeit & Fortgeschrittene Aktion)"
					if currentPlayer.level==2 or currentPlayer.level==4 or currentPlayer.level==6 or currentPlayer.level==8 or currentPlayer.level==10 or currentPlayer.level==12 then levelUpType="{en}\n(Command Token){ru}\n(Жетон командования){zh-tw}\n（指揮標記）{zh-cn}\n（指挥标记）{ko}\n(지휘 토큰){es}\n(Token de Comando){fr}\n(Jeton de Commande){pt-br}\n(Token de Comando){de}\n(Befehlsplättchen)" end
					if fameForUp>0 then mainText=joinLang({mainText, "{en}<size=6>\n\n</size>Next Level in {ru}<size=6>\n\n</size>До повышения уровня {zh-tw}<size=6>\n\n</size>升級還需 {zh-cn}<size=6>\n\n</size>升级还需 {ko}<size=6>\n\n</size>다음 레벨까지 {es}<size=6>\n\n</size>Siguiente nivel en {fr}<size=6>\n\n</size>Niveau suivant dans {pt-br}<size=6>\n\n</size>Próximo Nível em {de}<size=6>\n\n</size>Nächstes Level in ", fameForUp, "{en} Fame{ru} Слава(ы){zh-tw} 名望{zh-cn} 名望{ko} 명성 남음{es} Fama{fr} Gloire{pt-br} Fama{de} Ruhm", levelUpType}) else mainText=joinLang({mainText, "\n "}) end
					UI.setAttribute("MainGameNotes", "text", mainText)
				else
					if proxyPlayerActive()==true then
						UI.setAttribute("MainGameNotes", "text", joinLang({"{en}<size=25>Proxy {ru}<size=25>Прокси {zh-tw}<size=25>代理玩家 {zh-cn}<size=25>代理玩家 {ko}<size=25>프록시 {es}<size=25>Proxy {fr}<size=25>Proxy {pt-br}<size=25>Proxy {de}<size=25>Proxy ", translateWord[currentPlayer.mage], "{en}'s Turn</size>{ru} Ходит</size>{zh-tw}的回合</size>{zh-cn}的回合</size>{ko} 차례</size>{es}</size>{fr}</size>{pt-br}</size>{de}'s Zug</size>"}))
					else
						UI.setAttribute("MainGameNotes", "text", joinLang({"{en}<size=25>Dummy {ru}<size=25>Манекен {zh-tw}<size=25>虛擬玩家 {zh-cn}<size=25>虚拟玩家 {ko}<size=25>더미{es}<size=25>Turno de Maniquí {fr}<size=25>Au tour de Mannequin {pt-br}<size=25>Turno de Manequim {de}<size=25>Dummy ", translateWord[currentPlayer.mage], "{en}'s Turn</size>{ru} Ходит</size>{zh-tw}的回合</size>{zh-cn}的回合</size>{ko} 차례</size>{es}</size>{fr}</size>{pt-br}</size>{de}'s Zug</size>"}))
					end
				end
			end


			automatedMainPanelRefresh()

			UI.setAttribute("PreEndTurn", "onClick", "endTurn")
			if gStates.coopAssaultPhase=="combat" and gStates.preEndTurn==false then
				UI.setAttribute("EndTurnButtonText", "text", "{en}Combat Complete{ru}Бой завершён{zh-tw}戰鬥完成{zh-cn}战斗完成{ko}전투 완료{es}Combate Completo{fr}Combat Terminé{pt-br}Combate Concluído{de}Kampf Abgeschlossen")
				UI.setAttribute("EndTurnButtonAltText", "text", UI.getAttribute("EndTurnButtonText", "text"))
			elseif gStates.coopAssaultPhase=="rewards" then
				local nextText="{en}Finish Co-op Rewards{ru}Завершить совместные награды{zh-tw}完成合作獎勵{zh-cn}完成合作奖励{ko}협력 보상 완료{es}Finalizar Recompensas Coop.{fr}Terminer les Récompenses Coop.{pt-br}Finalizar Recompensas Coop.{de}Koop-Belohnungen Beenden"
				if gStates.coopRewardIndex<#gStates.coopRewardQueue then nextText="{en}Rewards Claimed - Next Reward{ru}Награды получены - Следующая награда{zh-tw}獎勵完成－下一位{zh-cn}奖励完成－下一位{ko}보상 완료 - 다음 보상{es}Recompensas Reclamadas - Siguiente{fr}Récompenses Réclamées - Suivant{pt-br}Recompensas Coletadas - Próximo{de}Belohnungen Beansprucht - Weiter" end
				UI.setAttribute("PreEndTurnText", "text", nextText)
				UI.setAttribute("EndTurnButtonText", "text", "{en}Co-op Rewards{ru}Совместные награды{zh-tw}合作獎勵{zh-cn}合作奖励{ko}협력 보상{es}Recompensas Coop.{fr}Récompenses Coop.{pt-br}Recompensas Coop.{de}Koop-Belohnungen")
				UI.setAttribute("EndTurnButtonAltText", "text", UI.getAttribute("EndTurnButtonText", "text"))
				UI.setAttribute("EndTurnButton", "interactable", "false")
				UI.setAttribute("EndTurnButtonImage", "image", "Sliced Button/Button New Deactive")
				UI.setAttribute("EndTurnButtonAlt", "interactable", "false")
				UI.setAttribute("EndTurnButtonAltImage", "image", "Sliced Button/Button New Deactive")
			end
			UI.setAttribute("ScoreButtonReal", "onClick", "displayScore")
			if gameOver==true then
				UI.setAttribute("PreEndTurn", "onClick", "layoutClaimedCards")
				UI.setAttribute("PreEndTurnText", "text", "{en}Game Over - Show Score{ru}Игра окончена{zh-tw}遊戲結束{zh-cn}游戏结束{ko}게임 종료{es}Fin de Partida{fr}Jeu Terminé{pt-br}Fim de Jogo{de}Spiel Beendet")
				UI.setAttribute("DummyButton", "onClick", "layoutClaimedCards")
				UI.setAttribute("DummyButtonText", "Text", "{en}Game Over - Show Score{ru}Игра окончена{zh-tw}遊戲結束{zh-cn}游戏结束{ko}게임 종료{es}Fin de Partida{fr}Jeu Terminé{pt-br}Fim de Jogo{de}Spiel Beendet")
				UI.setAttribute("ScoreButtonReal", "onClick", "layoutClaimedCards")
				local noTurnsLeftToUndoInto=gStates.endRoundCalled==true and nextPlayerEndCalled==true and gStates.currentRound>=gStates.rounds
				local victoryRegistered=false
				for _, turnDetails in pairs(turnOrder) do if turnDetails.gameEnder==true then victoryRegistered=true break end end
				local canUndoVictory=victoryRegistered==true and noTurnsLeftToUndoInto==false
				UI.setAttribute("EndGameButton", "active", canUndoVictory and "true" or "false")
			end


			refreshGladeDiscardHealButton()
			UI.show("MainGame")
			mainUIPause=nil
		end, 0.1)
	end
end

--Add Icons to players Avatar and Rampaging Monsters
local addAvatarPause=true
avatarButtonXmlState={}
avatarButtonSpatialCell=3

function avatarButtonBucketKey(pos)
	return tostring(math.floor(pos[1]/avatarButtonSpatialCell))..":"..tostring(math.floor(pos[3]/avatarButtonSpatialCell))
end

function avatarButtonNearbyObjects(buckets, pos)
	local nearby={}
	local baseX=math.floor(pos[1]/avatarButtonSpatialCell)
	local baseZ=math.floor(pos[3]/avatarButtonSpatialCell)
	for x=baseX-1, baseX+1 do
		for z=baseZ-1, baseZ+1 do
			local bucket=buckets[tostring(x)..":"..tostring(z)]
			if bucket~=nil then for _, details in ipairs(bucket) do nearby[#nearby+1]=details end end
		end
	end
	return nearby
end

function avatarButtonXmlSignature(xml, scale, rotation)
	if xml==nil or xml[1]==nil or xml[1].tag==nil then return "empty" end
	local signature={tostring(scale), tostring(math.floor((rotation or 0)*10+0.5)/10)}
	for _, child in ipairs(xml[1].children or {}) do
		local attributes=child.attributes or {}
		local image=""
		if child.children~=nil and child.children[1]~=nil and child.children[1].attributes~=nil then image=child.children[1].attributes.image or "" end
		signature[#signature+1]=table.concat({child.tag or "", attributes.id or "", attributes.onClick or "", attributes.position or "", image}, "~")
	end
	return table.concat(signature, "|")
end

function applyAvatarButtonXml(obj, xml, signature)
	if obj==nil then return end
	local guid=obj.guid
	if avatarButtonXmlState[guid]~=signature then
		obj.UI.setXmlTable(xml)
		avatarButtonXmlState[guid]=signature
	end
end

function addAvatarButtons()
	if addAvatarPause==true then safeWaitFrames("UI",function()
		--Snapshot relevant map objects once. Nearby shield/marker/ruin checks use spatial buckets;
		--rampager/destroyed-site controls remain a small dedicated list because stale remote buttons must be cleared.
		local mapButtonBuckets={}
		local mapActionObjects={}
		local mapObj=getObjectFromGUID(mapArea)
		if mapObj~=nil then
			for _, playObj in pairs(mapObj.getObjects()) do
				local guid=playObj.guid
				local name=playObj.getName()
				if name=="Shield" or name:sub(-6)=="Marker" or monsterPugs[guid]~=nil or gStates.rampagingMonsters[guid]==true or (gStates.destroyedSites~=nil and gStates.destroyedSites[guid]~=nil) then
					local position=playObj.getPosition()
					local details={obj=playObj, guid=guid, name=name, position=position, description=name=="Shield" and playObj.getDescription() or nil}
					local key=avatarButtonBucketKey(position)
					if mapButtonBuckets[key]==nil then mapButtonBuckets[key]={} end
					mapButtonBuckets[key][#mapButtonBuckets[key]+1]=details
					if gStates.rampagingMonsters[guid]==true or (gStates.destroyedSites~=nil and gStates.destroyedSites[guid]~=nil) then mapActionObjects[#mapActionObjects+1]=details end
				end
			end
		end

		--Only active turn-order Mage Knights can need avatar buttons. Resolve each physical avatar once.
		for order, player in pairs(turnOrder) do
			local details=mageKnightsByName[player.mage]
			if details~=nil and playerDropoutInactive(order)==true then
				for _, avatarGUID in ipairs({details.model, details.token, details.standee}) do
					local inactiveAvatar=getObjectFromGUID(avatarGUID)
					if inactiveAvatar~=nil then applyAvatarButtonXml(inactiveAvatar, {{}}, "empty") end
				end
			end
			if details~=nil and details.shieldContainer~=nil and playerDropoutInactive(order)==false and player.mage~=gStates.positionMageKnight[5] then
				local modelObj=getObjectFromGUID(details.model)
				local tokenObj=getObjectFromGUID(details.token)
				local standeeObj=getObjectFromGUID(details.standee)
				local avatarObj=standeeObj or tokenObj or modelObj
				if avatarObj~=nil then
					local scale=standeeObj~=nil and 1 or (tokenObj~=nil and 0.53 or 0.9)
					local rotation=avatarObj.getRotation()[2]
					local avPos=avatarObj.getPosition()
					local mageShield=nil
					local mageMarker={}
					local avatarButton={{tag="Panel", attributes={id=details.markerContainer.."RotationPlane",
						height=300, width=300,
						position="0 0 "..tostring(-25/scale), rotation="0 0 "..tostring(rotation-180),
						color="rgba(0,0,0,0.0)"},
						children={}}}
					local cityHasMonsters=false
					local cityHasShields=true
					local turnTokenObj=getObjectFromGUID(player.turnOrderTokenGUID)
					local turnTokenFaceUp=turnTokenObj~=nil and turnTokenObj.is_face_down==false

					--Use City Model location as Avatar Location if in City.
					if player.avatarLocation:sub(1, 4)=="city" or player.avatarLocation=="Volkare's Camp" then
						for zoneGUID, citySearch in pairs(cityScriptZones) do
							local zoneObj=getObjectFromGUID(zoneGUID)
							if zoneObj~=nil then
								local mageFound=false
								for _, detail in pairs(zoneObj.getObjects()) do
									if detail.getName()==player.mage then mageFound=true break end
								end
								if mageFound==true then
									if zoneGUID==volkare.discZone and (gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz" or gStates.gameScenario=="Volkare's Quest" or gStates.gameScenario=="The War of Four") then
										local volkareObj=getObjectFromGUID(gStates.volkareModel)
										if volkareObj~=nil then avPos=volkareObj.getPosition() end
									else
										local cityObj=getObjectFromGUID(citySearch.cityGUID)
										if cityObj~=nil then avPos=cityObj.getPosition() end
									end
									local cityMonsters=gStates.cityMonsterQty[citySearch.cityGUID]
									if cityMonsters~=nil then
										for _, state in pairs(cityMonsters) do
											if state=="alive" then cityHasMonsters=true cityHasShields=false break end
										end
									end
									break
								end
							end
						end
					end

					--Only inspect objects in this avatar's neighbouring spatial buckets for local controls.
					local ruin="fight"
					local shieldCount=0
					for _, mapDetails in ipairs(avatarButtonNearbyObjects(mapButtonBuckets, avPos)) do
						local mapObject=mapDetails.obj
						local avatarToObjDistSquared=((mapDetails.position[1]-avPos[1])^2)+((mapDetails.position[3]-avPos[3])^2)
						if gStates.preEndTurn==false and monsterPugs[mapDetails.guid]~=nil and monsterPugs[mapDetails.guid].pugType=="yellow" and monsterPugs[mapDetails.guid].monsters==nil and avatarToObjDistSquared<1 and mapObject.is_face_down==false then
							ruin="offer"
							avatarButton[1].children[#avatarButton[1].children+1]={tag="Button", attributes={id="Attack"..details.mage,
								onClick="global/attackLocation",
								height=70/scale, width=50/scale,
								position="0 "..tostring(100/scale).." "..tostring(-25/scale), rotation="0 0 180",
								color="rgba(0,0,0,0.0)"},
								children={{tag="Image", attributes={image="Offer Button"}}}}
						end
						if mapDetails.name=="Shield" and volkarePursuitShieldRegistered(mapObject)~=true and avatarToObjDistSquared<1.44 then
							if mageShield==nil then mageShield={} end
							mageShield[mapDetails.description]=true
							shieldCount=shieldCount+1
						end
						if mapDetails.name:sub(-6)=="Marker" and avatarToObjDistSquared<1 then
							mageMarker[mapDetails.name:sub(1, #mapDetails.name-7)]=true
						end
					end

					--Rampager and destroyed-site buttons can remain on remote objects, so refresh this small list for the active player.
					if order==gStates.turnNumber and gStates.preEndTurn==false then
						for _, mapDetails in ipairs(mapActionObjects) do
							local mapObject=mapDetails.obj
							local avatarToObjDistSquared=((mapDetails.position[1]-avPos[1])^2)+((mapDetails.position[3]-avPos[3])^2)
							if gStates.rampagingMonsters[mapDetails.guid]==true then
								local existingButtons=mapObject.UI.getXmlTable() or {}
								local keptButtons={}
								for _, xmlParent in pairs(existingButtons) do if xmlParent.tag~="Button" then keptButtons[#keptButtons+1]=xmlParent end end
								existingButtons=keptButtons
								if player.combatIconHide~="Both" and turnTokenFaceUp==true and (avatarToObjDistSquared<9.61 or (avatarToObjDistSquared<26.01 and gStates.ambushingMonsters[mapDetails.guid]~=nil)) then
									existingButtons[#existingButtons+1]={tag="Button", attributes={id=mapDetails.guid..details.mage,
										onClick="global/attackLocation",
										height=70/0.9, width=70/0.9,
										position="0 "..tostring(120/0.9).." "..tostring(-20/0.9), rotation="0 0 180",
										color="rgba(0,0,0,0.0)"},
									children={{tag="Image", attributes={image="Attack Button"}}}}
								end
								if #existingButtons==0 then existingButtons={{}} end
								mapObject.UI.setXmlTable(existingButtons)
							end
							if gStates.gameScenario=="Against the Apocalypse Blitz" and gStates.destroyedSites~=nil and gStates.destroyedSites[mapDetails.guid]~=nil then
								local existingButtons=mapObject.UI.getXmlTable() or {}
								local keptButtons={}
								for _, xmlParent in pairs(existingButtons) do if xmlParent.tag~="Button" then keptButtons[#keptButtons+1]=xmlParent end end
								existingButtons=keptButtons
								if player.combatIconHide~="Both" and turnTokenFaceUp==true and avatarToObjDistSquared<9.61 and avatarToObjDistSquared>1 then
									existingButtons[#existingButtons+1]={tag="Button", attributes={id=mapDetails.guid..details.mage,
										onClick="global/destroyRestoreLocation",
										height=100/0.9, width=100/0.9,
										position="0 "..tostring(120/0.9).." "..tostring(-20/0.9), rotation="0 0 180",
										color="rgba(0,0,0,0.0)"},
									children={{tag="Image", attributes={image="Restore Button"}}}}
								end
								if #existingButtons==0 then existingButtons={{}} end
								mapObject.UI.setXmlTable(existingButtons)
							end
						end
					end

					local dungeonLordsConqueredSite=gStates.gameScenario=="Dungeon Lords" and (player.avatarLocation=="dungeon" or player.avatarLocation=="tomb") and mageShield~=nil

					--Marker can be dropped
					if mageMarker[details.mage]==nil then
						avatarButton[1].children[#avatarButton[1].children+1]={tag="Button", attributes={id=details.markerContainer.."MarkerDrop",
							onClick="global/shieldDrop",
							height=70/scale, width=70/scale,
							position=tostring(-70/scale).." "..tostring(100/scale).." "..tostring(-25/scale), rotation="0 0 180",
							color="rgba(0,0,0,0.0)"},
							children={{tag="Image", attributes={image="Marker Button "..details.mage}}}}
					end
					--Shield can be dropped
					if player.avatarLocation~=nil and ((mageShield==nil and (player.avatarLocation=="keep" or player.avatarLocation=="mage tower"
							or player.avatarLocation=="monastery" or player.avatarLocation=="ruin"
							or ((player.avatarLocation=="dungeon" or player.avatarLocation=="tomb") and gStates.gameScenario~="Dungeon Lords")
							or player.avatarLocation=="monster den" or player.avatarLocation=="spawning grounds"
							or (player.avatarLocation=="glade" and (gStates.gameScenario=="Life and Death" or gStates.gameScenario=="Druid Nights"))
							or (player.avatarLocation=="graveyard" and (gStates.gameScenario~="The Realm of the Dead Blitz" or realmDeadEnemiesAtPosition(avPos)~=true)))
						or ((player.avatarLocation=="maze" or player.avatarLocation=="labyrinth") and shieldCount<3 and (mageShield==nil or mageShield[details.mage]==nil))
						or ((player.avatarLocation=="ziggurat" or player.avatarLocation=="pyramid") and shieldCount<3 and (mageShield==nil or mageShield[details.mage]==nil))
						or (player.avatarLocation=="glade" and mageShield~=nil and mageShield[details.mage]==nil)
						or ((player.avatarLocation:sub(1, 4)=="city" or player.avatarLocation=="Volkare's Camp") and cityHasShields==false and scenarioList[gStates.scenarioRef][gStates.playersRef].cityLevels[#scenarioList[gStates.scenarioRef][gStates.playersRef].cityLevels]~=0))) then
						avatarButton[1].children[#avatarButton[1].children+1]={tag="Button", attributes={id=details.shieldContainer.."ShieldDrop",
							onClick="global/shieldDrop",
							height=70/scale, width=70/scale,
							position=tostring(62/scale).." "..tostring(100/scale).." "..tostring(-25/scale), rotation="0 0 180",
							color="rgba(0,0,0,0.0)"},
							children={{tag="Image", attributes={image="Shield Button "..details.mage}}}}
					end
					--Attack / Volkare Pursuit / Druid Ritual share one compact vertical stack.
					--Each available action takes the next 70-unit slot, so unavailable actions leave no gaps.
					local specialActionY=100
					--monster can be fought at avatar location
					if gStates.preEndTurn==false and player.avatarLocation~=nil and order==gStates.turnNumber and player.combatIconHide=="None" and turnTokenFaceUp==true
						and ((mageShield==nil and (player.avatarLocation=="mage tower"
							or player.avatarLocation=="monster den" or player.avatarLocation=="spawning grounds"
							or (player.avatarLocation=="glade" and gStates.gameScenario=="Life and Death") or player.avatarLocation=="graveyard"
							or (player.avatarLocation=="mine" and gStates.gameScenario=="Mines Liberation")
							or (player.avatarLocation:sub(1, 4)=="city" and gStates.gameScenario=="The Lost Relic Blitz")
							or player.avatarLocation=="monastery" or (player.avatarLocation=="ruin" and ruin=="fight")))
						or (((player.avatarLocation=="dungeon" or player.avatarLocation=="tomb") and dungeonLordsConqueredSite~=true)
							or player.avatarLocation=="hidden valley"
							or player.avatarLocation=="necropolis"
							or (player.avatarLocation=="keep"
								and (((mageShield==nil or mageShield[details.mage]==nil)
								and (gStates.coop==0 or gStates.WarOfFourComp==true))
									or (mageShield==nil and gStates.coop==1 and gStates.WarOfFourComp~=true)))
							or ((player.avatarLocation=="maze" or player.avatarLocation=="labyrinth") and shieldCount<3 and (mageShield==nil or mageShield[details.mage]==nil))
							or ((player.avatarLocation=="ziggurat" or player.avatarLocation=="pyramid") and shieldCount<3 and (mageShield==nil or mageShield[details.mage]==nil))
							or ((player.avatarLocation:sub(1, 4)=="city" or player.avatarLocation=="Volkare's Camp") and cityHasMonsters==true and scenarioList[gStates.scenarioRef][gStates.playersRef].cityLevels[#scenarioList[gStates.scenarioRef][gStates.playersRef].cityLevels]~=0))) then
						avatarButton[1].children[#avatarButton[1].children+1]={tag="Button", attributes={id="Attack"..details.mage,
							onClick="global/attackLocation",
							height=70/scale, width=70/scale,
							position="0 "..tostring(specialActionY/scale).." "..tostring(-25/scale), rotation="0 0 180",
							color="rgba(0,0,0,0.0)"},
							children={{tag="Image", attributes={image="Attack Button"}}}}
						specialActionY=specialActionY+70
					end
					--Against the Horsemen: a Horseman can only be attacked from the same hex. Keep this as a
					--separate Avatar action so an unconquered site's normal Attack can be chosen without also
					--adding the Horseman. If the Horseman action is chosen on a fortified site, attackLocation
					--still brings that site's mandatory defenders into the same combat.
					if gStates.preEndTurn==false and order==gStates.turnNumber and player.combatIconHide~="Both" and turnTokenFaceUp==true then
						for _,horseOption in ipairs(horsemanAttackOptions(order,avPos)) do
							avatarButton[1].children[#avatarButton[1].children+1]={tag="Button",attributes={id="Horse|"..horseOption.key.."|"..details.mage,
								onClick="global/horsemanAttackAction",height=70/scale,width=70/scale,
								position="0 "..tostring(specialActionY/scale).." "..tostring(-25/scale),rotation="0 0 180",color="rgba(0,0,0,0.0)"},
								children={{tag="Image",attributes={image="https://steamusercontent-a.akamaihd.net/ugc/12647478740119221952/A4E3602A20A7A1C0FA03DA5C0FBEDF8910DE1E7D/"}}}}
							specialActionY=specialActionY+70
						end
					end
					--Once the Volkare's Quest portal is closed it is an ordinary hex; if Volkare shares it with the active Mage Knight, use his dedicated army attack path.
					if gStates.preEndTurn==false and order==gStates.turnNumber and player.combatIconHide=="None" and turnTokenFaceUp==true
						and gStates.gameScenario=="Volkare's Quest" and gStates.volkarePortalClosed==true and player.avatarLocation=="portal"
						and gStates.volkareModel~=nil then
						local volkareObj=getObjectFromGUID(gStates.volkareModel)
						if volkareObj~=nil then
							local volkarePos=volkareObj.getPosition()
							if ((volkarePos[1]-avPos[1])^2)+((volkarePos[3]-avPos[3])^2)<1 then
								avatarButton[1].children[#avatarButton[1].children+1]={tag="Button", attributes={id="Volkar"..details.mage,
									onClick="global/attackLocation",
									height=70/scale, width=70/scale,
									position="0 "..tostring(specialActionY/scale).." "..tostring(-25/scale), rotation="0 0 180",
									color="rgba(0,0,0,0.0)"},
									children={{tag="Image", attributes={image="Attack Button"}}}}
								specialActionY=specialActionY+70
							end
						end
					end
					--Conquered Camp-as-City Pursuit. The fourth slot is shared with Druid Nights; if both are legal, Druid moves one slot higher.
					local pursuitInfo=volkarePursuitAvailable(order)
					if pursuitInfo~=nil then
						if gStates.volkarePursuitChoicePlayer==order then
							local choices={{"Green",-58,"rgb(0.25,0.72,0.25)"},{"Red",0,"rgb(0.78,0.22,0.22)"},{"Both",58,"rgb(0.75,0.75,0.75)"}}
							for _,choice in ipairs(choices) do
								avatarButton[1].children[#avatarButton[1].children+1]={tag="Button",attributes={id="VPursuit"..choice[1].."|"..details.mage,onClick="global/volkarePursuitAction",
									height=58/scale,width=54/scale,position=tostring(choice[2]/scale).." "..tostring(specialActionY/scale).." "..tostring(-25/scale),rotation="0 0 180",color=choice[3]},
									children={{tag="Text",attributes={text=choice[1]=="Both" and "G+R" or choice[1]:sub(1,1),fontSize=24/scale,color="rgb(1,1,1)",alignment="MiddleCenter"}}}}
							end
						else
							avatarButton[1].children[#avatarButton[1].children+1]={tag="Button",attributes={id="VPursuitOpen|"..details.mage,onClick="global/volkarePursuitAction",
								height=70/scale,width=70/scale,position="0 "..tostring(specialActionY/scale).." "..tostring(-25/scale),rotation="0 0 180",color="rgba(0,0,0,0.0)"},
								children={{tag="Image",attributes={image=volkarePursuitButtonImageURL}}}}
						end
						specialActionY=specialActionY+70
					end
					--Druid nights
					if player.avatarLocation~=nil and order==gStates.turnNumber and player.combatIconHide=="None" and turnTokenFaceUp==true and gStates.gameScenario=="Druid Nights" and #player.gladesMarked>=1 and gStates.dayRound==false and player.druidNightsLastRitualRound~=gStates.currentRound and druidNightsCanIncantHere(order)==true then
						avatarButton[1].children[#avatarButton[1].children+1]={tag="Button", attributes={id="Incant"..details.mage,
							onClick="global/druidNightsRitualAction",height=70/scale,width=70/scale,
							position="0 "..tostring(specialActionY/scale).." "..tostring(-25/scale),rotation="0 0 180",color="rgba(0,0,0,0.0)"},children={{tag="Image",attributes={image="Incantation Button"}}}}
					end
					--Restore Site. The Apocalypse expansion only permits restoration in Against the Apocalypse.
					if gStates.gameScenario=="Against the Apocalypse Blitz" and player.avatarLocation~=nil and order==gStates.turnNumber and player.combatIconHide=="None" and turnTokenFaceUp==true and player.avatarLocation=="destroyed" then
						avatarButton[1].children[#avatarButton[1].children+1]={tag="Button", attributes={id="Restor"..details.mage,
							onClick="global/destroyRestoreLocation",
							height=70/scale, width=70/scale,
							position="0 "..tostring(100/scale).." "..tostring(-25/scale), rotation="0 0 180",
							color="rgba(0,0,0,0.0)"},
							children={{tag="Image", attributes={image="Restore Button"}}}}
					end
					if #avatarButton[1].children==0 then avatarButton={{}} end
					local avatarXmlSignature=avatarButtonXmlSignature(avatarButton, scale, rotation)
					applyAvatarButtonXml(modelObj, avatarButton, avatarXmlSignature)
					applyAvatarButtonXml(tokenObj, avatarButton, avatarXmlSignature)
					applyAvatarButtonXml(standeeObj, avatarButton, avatarXmlSignature)
				end
			end
		end
		addAvatarPause=true
	end, 5) end
	addAvatarPause=false
end

--drop a shield or marker on avatar location

function refreshPlayerSeatColors()
	if gStates==nil or gStates.handColors==nil then return end
	for _, playerData in pairs(turnOrder) do
		if playerData.seatPos~=nil and playerData.mage~=gStates.positionMageKnight[5] then
			local color=nil
			for handColor, seatPos in pairs(gStates.handColors) do if seatPos==playerData.seatPos then color=handColor break end end
			if color~=nil then
				for _, mageData in pairs(mageKnights) do
					if mageData.mage==playerData.mage then
						local model=getObjectFromGUID(mageData.model)
						local standee=getObjectFromGUID(mageData.standee)
						local bar=getObjectFromGUID(colorBand[playerData.seatPos])
						if model~=nil then model.setColorTint(color) end
						if standee~=nil then standee.setColorTint(color) end
						if bar~=nil then bar.setColorTint(color) end
						break
					end
				end
			end
		end
	end
end

function applyColorBarButtons()
	for position, barGUID in pairs(colorBand) do
		local buttons={{tag="Button", attributes={id=barGUID.."changeMatDown",
			onClick="global/changeMatImage", onMouseDown="global/buttonClicked", onMouseUp="global/buttonClicked",
			height=29, width=3, color="rgba(0,0,0,0.0)",
			position="-90 30 -40", rotation="0 0 180"},
				children={{tag="Image", attributes={id=barGUID.."changeMatDownImage", image="Overkill Down"}}}},
			{tag="Button", attributes={id=barGUID.."changeMatUp",
			onClick="global/changeMatImage", onMouseDown="global/buttonClicked", onMouseUp="global/buttonClicked",
			height=29, width=3, color="rgba(0,0,0,0.0)",
			position="-95 30 -40", rotation="0 0 180"},
				children={{tag="Image", attributes={id=barGUID.."changeMatUpImage", image="Overkill Up"}}}}}
		if getObjectFromGUID(barGUID)~=nil then
			local barSkip=false
			local barPlayerIndex=nil
			local barPlayerData=nil
			for playerIndex, playerData in pairs(turnOrder) do
				if playerData.seatPos==position then
					if playerData.mage==gStates.positionMageKnight[5] then barSkip=true
					else barPlayerIndex=playerIndex barPlayerData=playerData end
					break
				end
			end
			local handColorList={"White", "Brown", "Red", "Orange", "Yellow", "Green", "Teal", "Blue", "Purple", "Pink"}
			local loopCount=1
			for _, handColor in pairs(handColorList) do
				local available=true
				for _, playerData in pairs(turnOrder) do
					for _, seat in pairs(Player.getAvailableColors()) do
						if playerData.mage~=gStates.positionMageKnight[5] and math.ceil((Player[seat].getHandTransform().position[1]+97.59)/40)==playerData.seatPos and seat==handColor then available=false break end
					end
				end
				if available==true then
					buttons[#buttons+1]={tag="Button", attributes={id=barGUID..handColor,
						onClick="global/changePositionColor",
						height=25, width=3,
						position=tostring(102-(loopCount*5)).." 30 -40", rotation="0 0 180",
						color=handColor}}
					loopCount=loopCount+1
				end
			end
			if barPlayerData~=nil then
				local dropText="{en}DROP OUT{ru}ВЫЙТИ{zh-tw}退出{zh-cn}退出{ko}이탈{es}ABANDONAR{fr}ABANDONNER{pt-br}SAIR{de}AUSSTEIGEN"
				local dropVisible=false
				local dropInteractable=false
				local dropImage="Sliced Button/Button Object Active"
				if barPlayerData.dropoutState=="dropped" then
					dropText="{en}DROPPED OUT{ru}ВЫШЕЛ{zh-tw}已退出{zh-cn}已退出{ko}이탈함{es}ABANDONÓ{fr}ABANDONNÉ{pt-br}SAIU{de}AUSGESTIEGEN" dropVisible=true dropImage="Sliced Button/Button Object Deactive"
				elseif barPlayerData.dropoutState=="pending" then
					dropText="{en}UNDO DROP OUT{ru}ОТМЕНИТЬ ВЫХОД{zh-tw}取消退出{zh-cn}取消退出{ko}이탈 취소{es}DESHACER ABANDONO{fr}ANNULER L’ABANDON{pt-br}DESFAZER SAÍDA{de}AUSSTIEG RÜCKGÄNGIG" dropVisible=dropoutCoopLocked()==false dropInteractable=dropVisible
				elseif gStates.firstStarted==true and barPlayerIndex~=gStates.turnNumber and dropoutCoopLocked()==false and activeMageKnightCount()>=3 then
					dropVisible=true dropInteractable=true
				end
				if dropVisible==true then
					--The color bar is a cube scaled {19.80, 0.01, 2.50}; counter-scale X/Z so this renders like a normal Claim-style button.
					buttons[#buttons+1]={tag="Button", attributes={id=barGUID.."DropOut", onClick="global/dropOutPlayer", onMouseDown="global/buttonClicked", onMouseUp="global/buttonClicked",
						height=200, width=800, position="-70 30 -40", rotation="0 0 0", scale="0.01778 0.1408", interactable=dropInteractable},
						children={{tag="Image", attributes={id=barGUID.."DropOutImage", image=dropImage, type="Sliced"}},
							{tag="Text", attributes={id=barGUID.."DropOutText", font="Fonts/MKCardText", fontSize=90, fontStyle="Normal", alignment="MiddleCenter", resizeTextForBestFit="true", resizeTextMaxSize=90, text=dropText}}}}
				end
			end
			if barSkip==false then getObjectFromGUID(barGUID).UI.setXmlTable(buttons) end
		end
	end
end


function bugReport(player, value, id)
	UI.setAttribute("SendBugRequest", "active", true)
end

function updateComment(player, value, id)
	UI.setAttribute(id, "text", value)
end

function lowerTable(player, mouseButton, id)
	if mouseButton=="-1" then
		if getObjectFromGUID("3d4319").getPosition()[2]==0 then
			getObjectFromGUID("3d4319").setPosition({0.00, -0.2, -5.00})
			getObjectFromGUID("519f96").setScale({200, 1, 200})
			getObjectFromGUID("519f96").setPosition({0.00, 0.77, -5.00})
			skillButtonActivate()
			return
		end
		if getObjectFromGUID("3d4319").getPosition()[2]<0 then
			getObjectFromGUID("3d4319").setPosition({0.00, 0.0, -5.00})
			getObjectFromGUID("519f96").setScale({1, 1, 1})
			getObjectFromGUID("519f96").setPosition({0.00, -0.2, -5.00})
			skillButtonActivate()
		end
	end
end


cameraControlViewing=cameraControlViewing or {}
function cameraControl(player, mouseButton, id)
	if mouseButton=="-1" then
		--Expand Camera Control only for the players currently viewing its detail panel.
		if gStates.cameraControlTopDown==nil then gStates.cameraControlTopDown=75 end
		if type(gStates.cameraFollowEnemy)~="boolean" then gStates.cameraFollowEnemy=true end
		if id=="cameraControlStart" or id=="tacticChanged" then
			UI.setAttribute("followEnemyView", "isOn", gStates.cameraFollowEnemy and "true" or "false")
			local height=329--Base height without the optional Quest camera button; includes both checkbox rows.
			UI.setAttribute("tacticView", "active", "true")
			UI.setAttribute("dummyView", "active", "true")
			UI.setAttribute("questView", "active", "false")
			if apocalypseQuestsUsed()==true or gStates.questMod==true then height=height+28 UI.setAttribute("questView", "active", "true") end
			if gStates.tacticShown==false then height=height-28 UI.setAttribute("tacticView", "active", "false") end
			if gStates.coop==0 then height=height-28 UI.setAttribute("dummyView", "active", "false") end

			--tacticChanged only refreshes the contents/height; it must not change who has the menu open.
			if id=="cameraControlStart" then
				local alreadyViewing=false
				local temp={}
				for a=1, #cameraControlViewing, 1 do
					if cameraControlViewing[a]==player.color then
						alreadyViewing=true
					else
						temp[#temp+1]=cameraControlViewing[a]
					end
				end
				if alreadyViewing then cameraControlViewing=temp else cameraControlViewing[#cameraControlViewing+1]=player.color end
			end

			--As with the ScoreBoard, never use an empty visibility string: empty means visible to everyone.
			if #cameraControlViewing<1 then
				UI.setAttribute("cameraControlDetail", "active", "false")
				UI.setAttribute("cameraControl", "height", "35")
				UI.setAttribute("cameraControlDetail", "height", "0")
				return
			end

			local visibility=""
			for a=1, #cameraControlViewing, 1 do
				visibility=visibility..cameraControlViewing[a]
				if a<#cameraControlViewing then visibility=visibility.."|" end
			end
			UI.setAttribute("cameraControlDetail", "visibility", visibility)
			UI.setAttribute("cameraControlDetail", "active", "true")
			UI.setAttribute("cameraControl", "height", tostring(height))
			UI.setAttribute("cameraControlDetail", "height", tostring(height-35))
			return
		end
		--move player camera to desired position
		if player.color~="Grey" then
			--Player Board and Follow Enemy deliberately share this exact resolver/focus point.
			if id=="playAreaView" then
				local view=cameraControlPlayerBoardView(player.color)
				if view~=nil then Player[player.color].lookAt(view) end
				return
			end
			local lookAtPos={0, 0, 0}
			if id=="dummyView" and getObjectFromGUID(dummyBoard)~=nil then lookAtPos=getObjectFromGUID(dummyBoard).getPosition() end--dummy board position
			for turn, playerDetails in pairs(turnOrder) do
				if (player.color~="Black" and Player[player.color].getHandTransform()~=nil and playerDetails.seatPos==math.ceil((Player[player.color].getHandTransform().position[1]+97.59)/40)) or
				   (player.color=="Black" and turn==gStates.turnNumber) then
					if id=="mapView" then
						for indexMage=1, #mageKnights, 1 do
							if mageKnights[indexMage].mage==playerDetails.mage then--figures out which Mage is in that position
								if getObjectFromGUID(mageKnights[indexMage].model)~=nil then lookAtPos=getObjectFromGUID(mageKnights[indexMage].model).getPosition() end
								if getObjectFromGUID(mageKnights[indexMage].standee)~=nil then lookAtPos=getObjectFromGUID(mageKnights[indexMage].standee).getPosition() end
								if getObjectFromGUID(mageKnights[indexMage].token)~=nil then lookAtPos=getObjectFromGUID(mageKnights[indexMage].token).getPosition() end
								if lookAtPos[1]<-42 then
									if gStates.gameScenario=="Against the Horsemen Blitz" then
										lookAtPos=againstHorsemenCentralGladePosition(0) or lookAtPos
									elseif getObjectFromGUID(startTerrain.wedge)~=nil then lookAtPos=getObjectFromGUID(startTerrain.wedge).getPosition()
									elseif getObjectFromGUID(startTerrain.open)~=nil then lookAtPos=getObjectFromGUID(startTerrain.open).getPosition() end
								end
								break
							end
						end
					end
					break
				end
			end
			local offerPreset=cameraControlPresetView("offerView")
			local questPreset=cameraControlPresetView("questView")
			local data={["mapView"]={pos={lookAtPos[1]+4,0,lookAtPos[3]+1}, pitch=gStates.cameraControlTopDown, yaw=0, dist=20},--clicking players avatar
						["playAreaView"]={pos={lookAtPos[1]+4,0,lookAtPos[3]-1}, pitch=gStates.cameraControlTopDown, yaw=0, dist=27},--clicking player board
						["dummyView"]={pos={lookAtPos[1],0,lookAtPos[3]-1}, pitch=gStates.cameraControlTopDown, yaw=0, dist=20},--dummy board
						["offerView"]={pos=offerPreset.position, pitch=offerPreset.pitch, yaw=offerPreset.yaw, dist=offerPreset.distance},
						["questView"]={pos=questPreset.position, pitch=questPreset.pitch, yaw=questPreset.yaw, dist=questPreset.distance},--Quest setup area (Apocalypse Dragon or fan-made Quest Variant)
						["tacticView"]={pos={0, 0, -15.00}, pitch=gStates.cameraControlTopDown, yaw=0, dist=20},
						["fameView"]={pos={30.0, 0, 12.0}, pitch=gStates.cameraControlTopDown, yaw=0, dist=30},
						["rulesView"]={pos={63.12, 0, 34.0}, pitch=gStates.cameraControlTopDown, yaw=0, dist=20},
						["monsterInfoView"]={pos={-12.7, 0, 34.5}, pitch=gStates.cameraControlTopDown, yaw=0, dist=17},
						["siteInfoView"]={pos={-62.0, 0, -16.5}, pitch=gStates.cameraControlTopDown, yaw=0, dist=18}}
			Player[player.color].lookAt({position=data[id].pos, pitch=data[id].pitch, yaw=data[id].yaw, distance=data[id].dist})
		end
	end
end

function cameraControlFollowEnemy(player, value, id)
	gStates.cameraFollowEnemy=value=="True"
end

function cameraControlTopDown(player, value, id)
	if value=="True" then
		gStates.cameraControlTopDown=90
	else
		gStates.cameraControlTopDown=75
	end
end

function resourceTracker(player, mouseButton, id)
	if mouseButton=="-1" then--and legalPlayerCheck(player.color, turnOrder[gStates.turnNumber].seatPos)==true then
		--expand Resource Tracker
		if id=="DisplayResourceTrackerDetails" then
			local temp="245"
			local temp2="true"
			if tonumber(UI.getAttribute("ResourceTracker", "height"))>200 then temp="35" temp2="false" end
			UI.setAttribute("ResourceTracker", "height", temp)
			UI.setAttribute("ResourceTrackerDetail", "active", temp2)
			UI.setAttribute("ResourceTrackerDetail", "height", "210")
			UI.setAttribute("MoveCosts", "active", "false")
			UI.setAttribute("SiegeAmountDetails", "active", "false")
			UI.setAttribute("RangeAmountDetails", "active", "false")
			UI.setAttribute("BlockAmountDetails", "active", "false")
			UI.setAttribute("AttacAmountDetails", "active", "false")
			UI.setAttribute("InfluAmountDetails", "active", "false")
			return
		end
		--expander buttons
		local IDConvert={	["DisplayMoveCosts"]={"MoveCosts", 240},
							["DisplaySiegeDetails"]={"SiegeAmountDetails", 120},
							["DisplayRangeDetails"]={"RangeAmountDetails", 120},
							["DisplayBlockDetails"]={"BlockAmountDetails", 120},
							["DisplayAttacDetails"]={"AttacAmountDetails", 120},
							["DisplayInfluDetails"]={"InfluAmountDetails", 90}}
		if IDConvert[id]~=nil then
			local temp="false"
			local temp2=-1
			if UI.getAttribute(IDConvert[id][1], "active")=="false" then temp="true" temp2=1 end
			UI.setAttribute(IDConvert[id][1], "active", temp)
			local existingHeight=tonumber(UI.getAttribute("ResourceTracker", "height"))
			UI.setAttribute("ResourceTracker", "height", tonumber(UI.getAttribute("ResourceTracker", "height"))+(IDConvert[id][2]*temp2))
			UI.setAttribute("ResourceTrackerDetail", "height", tonumber(UI.getAttribute("ResourceTrackerDetail", "height"))+(IDConvert[id][2]*temp2))
			return
		end
		--resource tracking
		local IDConvert={	["MovemAmountPlain"]={"move", "move", "{en}Move : {ru}Движение: {zh-tw}移動：{zh-cn}移动：{ko}이동 : {es}Mover : {fr}Se déplacer : {pt-br}Mover : {de}Bewegen : "},
							["SiegeAmountPlain"]={"siege", "physical", "{en}Siege : {ru}Осадная: {zh-tw}攻城：{zh-cn}攻城：{ko}공성 : {es}Asedio : {fr}Siège : {pt-br}Cerco : {de}Belagerung : "},
							["SiegeAmountPhysi"]={"siege", "physical", "{en}Physical : {ru}Физическая(ий): {zh-tw}物理：{zh-cn}物理：{ko}물리 : {es}Físico : {fr}Physique : {pt-br}Físico : {de}Physikalisch : "},
							["SiegeAmountFirex"]={"siege", "fire", "{en}Fire : {ru}Огненная(ый): {zh-tw}火焰：{zh-cn}火焰：{ko}불 : {es}Fuego : {fr}Feu : {pt-br}Fogo : {de}Feuer : "},
							["SiegeAmountIcexx"]={"siege", "ice", "{en}Ice : {ru}Ледяная(ой): {zh-tw}寒冰：{zh-cn}寒冰：{ko}얼음 : {es}Hielo : {fr}Glace : {pt-br}Gelo : {de}Eis : "},
							["SiegeAmountColdF"]={"siege", "iceFire", "{en}Cold Fire : {ru}Холодный огонь: {zh-tw}冰火：{zh-cn}冰火：{ko}차가운 불 : {es}Fuego Frío :{fr}Feu Froid : {pt-br}Fogo Frio : {de}Kaltes Feuer : "},
							["RangeAmountPlain"]={"ranged", "physical", "{en}Range : {ru}Дальняя: {zh-tw}遠程：{zh-cn}远程：{ko}원거리 : {es}Rango : {fr}Gamme : {pt-br}Distância : {de}Reichweite : "},
							["RangeAmountPhysi"]={"ranged", "physical", "{en}Physical : {ru}Физическая(ий): {zh-tw}物理：{zh-cn}物理：{ko}물리 : {es}Físico : {fr}Physique : {pt-br}Físico : {de}Physikalisch : "},
							["RangeAmountFirex"]={"ranged", "fire", "{en}Fire : {ru}Огненная(ый): {zh-tw}火焰：{zh-cn}火焰：{ko}불 : {es}Fuego : {fr}Feu : {pt-br}Fogo : {de}Feuer : "},
							["RangeAmountIcexx"]={"ranged", "ice", "{en}Ice : {ru}Ледяная(ой): {zh-tw}寒冰：{zh-cn}寒冰：{ko}얼음 : {es}Hielo : {fr}Glace : {pt-br}Gelo : {de}Eis : "},
							["RangeAmountColdF"]={"ranged", "iceFire", "{en}Cold Fire : {ru}Холодный огонь: {zh-tw}冰火：{zh-cn}冰火：{ko}차가운 불 : {es}Fuego Frío :{fr}Feu Froid : {pt-br}Fogo Frio : {de}Kaltes Feuer : "},
							["BlockAmountPlain"]={"block", "physical", "{en}Block : {ru}Блок: {zh-tw}格擋：{zh-cn}格档：{ko}방어 : {es}Bloqueo : {fr}Blocage : {pt-br}Bloqueio : {de}Blockieren : "},
							["BlockAmountPhysi"]={"block", "physical", "{en}Physical : {ru}Физическая(ий): {zh-tw}物理：{zh-cn}物理：{ko}물리 : {es}Físico : {fr}Physique : {pt-br}Físico : {de}Physikalisch : "},
							["BlockAmountFirex"]={"block", "fire", "{en}Fire : {ru}Огненная(ый): {zh-tw}火焰：{zh-cn}火焰：{ko}불 : {es}Fuego : {fr}Feu : {pt-br}Fogo : {de}Feuer : "},
							["BlockAmountIcexx"]={"block", "ice", "{en}Ice : {ru}Ледяная(ой): {zh-tw}寒冰：{zh-cn}寒冰：{ko}얼음 : {es}Hielo : {fr}Glace : {pt-br}Gelo : {de}Eis : "},
							["BlockAmountColdF"]={"block", "iceFire", "{en}Cold Fire : {ru}Холодный огонь: {zh-tw}冰火：{zh-cn}冰火：{ko}차가운 불 : {es}Fuego Frío :{fr}Feu Froid : {pt-br}Fogo Frio : {de}Kaltes Feuer : "},
							["AttacAmountPlain"]={"attack", "physical", "{en}Attack : {ru}Атака: {zh-tw}攻擊：{zh-cn}攻击：{ko}공격 : {es}Ataque : {fr}Attaque : {pt-br}Ataque : {de}Angriff : "},
							["AttacAmountPhysi"]={"attack", "physical", "{en}Physical : {ru}Физическая(ий): {zh-tw}物理：{zh-cn}物理：{ko}물리 : {es}Físico : {fr}Physique : {pt-br}Físico : {de}Physikalisch : "},
							["AttacAmountFirex"]={"attack", "fire", "{en}Fire : {ru}Огненная(ый): {zh-tw}火焰：{zh-cn}火焰：{ko}불 : {es}Fuego : {fr}Feu : {pt-br}Fogo : {de}Feuer : "},
							["AttacAmountIcexx"]={"attack", "ice", "{en}Ice : {ru}Ледяная(ой): {zh-tw}寒冰：{zh-cn}寒冰：{ko}얼음 : {es}Hielo : {fr}Glace : {pt-br}Gelo : {de}Eis : "},
							["AttacAmountColdF"]={"attack", "iceFire", "{en}Cold Fire : {ru}Холодный огонь: {zh-tw}冰火：{zh-cn}冰火：{ko}차가운 불 : {es}Fuego Frío :{fr}Feu Froid : {pt-br}Fogo Frio : {de}Kaltes Feuer : "},
							["InfluAmountPlain"]={"influence", "generated", "{en}Influence : {ru}Влияние: {zh-tw}影響力：{zh-cn}影响力：{ko}영향력 : {es}Influencia : {fr}Influence : {pt-br}Influência : {de}Einfluss : "},
							["InfluAmountPhysi"]={"influence", "generated", "{en}Generated : {ru}Сгенерировано: {zh-tw}產生的：{zh-cn}产生的：{ko}사용 : {es}Generación : {fr}Généré : {pt-br}Gerado : {de}Erzeugt : "},
							["InfluAmountReput"]={"influence", "reputation", "{en}Reputation : {ru}Репутация: {zh-tw}聲譽：{zh-cn}声誉：{ko}평판 : {es}Reputación : {fr}Réputation : {pt-br}Reputação : {de}Reputation : "},
							["InfluAmountCityS"]={"influence", "cityShields", "{en}City Shields : {ru}Щиты на городе: {zh-tw}城市的盾徽：{zh-cn}城市的盾徽：{ko}도시 방패 토큰 : {es}Escudos de la Ciudad : {fr}Boucliers de Ville : {pt-br}Escudos das Cidades : {de}Stadtschilde : "},
							["HealiAmountPlain"]={"healing", "healing", "{en}Healing : {ru}Лечение: {zh-tw}治療：{zh-cn}治疗：{ko}치유 : {es}Curación : {fr}Guérison : {pt-br}Cura : {de}Heilung : "}}
		if IDConvert[id:sub(1,16)]~=nil then
			local resourceTotal=0
			for type, value in pairs(gStates.resourceTracker[IDConvert[id:sub(1,16)][1]]) do
				resourceTotal=resourceTotal+value
			end
			if ((id:sub(17,20)=="Down" and (gStates.resourceTracker[IDConvert[id:sub(1,16)][1]][IDConvert[id:sub(1,16)][2]]>0 or id:sub(1,16)=="InfluAmountReput" or id:sub(1,16)=="InfluAmountPlain")) or id:sub(17,18)=="Up")
				and not (id:sub(1,16)=="MovemAmountPlain" and id:sub(17,18)=="Up" and gStates.resourceTracker.move.move>=99) then
				local temp=1
				if id:sub(17,28)=="Down" then temp=-1 end
				gStates.resourceTracker[IDConvert[id:sub(1,16)][1]][IDConvert[id:sub(1,16)][2]]=gStates.resourceTracker[IDConvert[id:sub(1,16)][1]][IDConvert[id:sub(1,16)][2]]+temp
				resourceTotal=resourceTotal+temp
				temp=id:sub(1,16)
				if id:sub(12,16)=="Plain" and id:sub(1,16)~="MovemAmountPlain" and id:sub(1,16)~="HealiAmountPlain" then temp=id:sub(1,11).."Physi" end
				UI.setAttribute(temp.."Text", "text", joinLang({IDConvert[temp][3], gStates.resourceTracker[IDConvert[temp][1]][IDConvert[temp][2]]}))
				if id:sub(1,16)~="MovemAmountPlain" and id:sub(1,16)~="HealiAmountPlain" then
					UI.setAttribute(id:sub(1,11).."PlainText", "text", joinLang({IDConvert[id:sub(1,11).."Plain"][3], resourceTotal}))
				end
			end
		end
		--move costs
		if id:sub(1,8)=="MoveCost" then
			local temp="1"
			if id:sub(14,17)=="Down" then temp="-1" end
			local convert={	["Plain"]={"plains", "{en}Plains : {ru}Равнины: {zh-tw}平原：{zh-cn}平原：{ko}평지 :{es}Llanuras : {fr}Plaines : {pt-br}Planícies : {de}Ebenen : "},
							["Hills"]={"hills", "{en}Hills : {ru}Холмы: {zh-tw}丘陵：{zh-cn}丘陵：{ko}언덕 : {es}Colinas : {fr}Collines : {pt-br}Colinas : {de}Hügel : "},
							["Fores"]={"forest", "{en}Forests : {ru}Леса: {zh-tw}森林：{zh-cn}森林：{ko}숲 : {es}Bosques : {fr}Forêts : {pt-br}Florestas : {de}Wälder : "},
							["Waste"]={"wasteland", "{en}Wastelands : {ru}Пустоши: {zh-tw}荒原：{zh-cn}荒原：{ko}황무지 : {es}Páramos : {fr}Terrains Vagues : {pt-br}Terras Devastadas : {de}Ödland : "},
							["Deser"]={"desert", "{en}Deserts : {ru}Пустыни: {zh-tw}沙漠：{zh-cn}沙漠：{ko}사막 : {es}Desiertos : {fr}Déserts : {pt-br}Desertos : {de}Wüsten : "},
							["Swamp"]={"swamp", "{en}Swamps : {ru}Болота: {zh-tw}沼澤：{zh-cn}沼泽：{ko}늪 : {es}Pantanos : {fr}Marécages : {pt-br}Pântanos : {de}Sümpfe : "},
							["Lakes"]={"lake", "{en}Lakes : {ru}Озера: {zh-tw}湖泊：{zh-cn}湖泊：{ko}호수 : {es}Lagos : {fr}Lacs : {pt-br}Lagos : {de}Seen : "},
							["Mount"]={"mountain", "{en}Mountains : {ru}Горы: {zh-tw}山脈：{zh-cn}山脉：{ko}산 : {es}Montañas : {fr}Montagnes : {pt-br}Montanhas : {de}Berge : "}}
			if (temp=="1" and gStates.moveCost[convert[id:sub(9,13)][1]]<900) or (temp=="-1" and gStates.moveCost[convert[id:sub(9,13)][1]]>0) then
				gStates.moveCost[convert[id:sub(9,13)][1]]=gStates.moveCost[convert[id:sub(9,13)][1]]+tonumber(temp)
			end
			if gStates.moveCost[convert[id:sub(9,13)][1]]==998 then gStates.moveCost[convert[id:sub(9,13)][1]]=6 end
			if gStates.moveCost[convert[id:sub(9,13)][1]]>6 then gStates.moveCost[convert[id:sub(9,13)][1]]=999 end
			temp=tostring(gStates.moveCost[convert[id:sub(9,13)][1]])
			if gStates.moveCost[convert[id:sub(9,13)][1]]>900 then temp="X" end
			UI.setAttribute(id:sub(1,13).."Text", "text", joinLang({convert[id:sub(9,13)][2], temp}))
		end
		if id~="DisplayMoveCosts" then updateMoveDisplay(id) end
	end
end

function refreshResourceTrackerText()
	if gStates.resourceTracker==nil or gStates.moveCost==nil then return end
	local mountain="X" if gStates.moveCost.mountain<7 then mountain=tostring(gStates.moveCost.mountain) end
	local lake="X" if gStates.moveCost.lake<7 then lake=tostring(gStates.moveCost.lake) end
	local resourceTotal={siege=0, ranged=0, block=0, attack=0, influence=0}
	for type, value in pairs(resourceTotal) do
		for _, value2 in pairs(gStates.resourceTracker[type]) do
			resourceTotal[type]=resourceTotal[type]+value2
		end
	end
	local baseValues={	HealiAmountPlainText=joinLang({"{en}Healing : {ru}Лечение: {zh-tw}治療：{zh-cn}治疗：{ko}치유 : {es}Curación : {fr}Guérison : {pt-br}Cura : {de}Heilung : ", gStates.resourceTracker.healing.healing}),
						SiegeAmountPlainText=joinLang({"{en}Siege : {ru}Осадная: {zh-tw}攻城：{zh-cn}攻城：{ko}공성 : {es}Asedio : {fr}Siège : {pt-br}Cerco : {de}Belagerung : ", resourceTotal.siege}),
							SiegeAmountPhysiText=joinLang({"{en}Physical : {ru}Физическая(ий): {zh-tw}物理：{zh-cn}物理：{ko}물리 : {es}Físico : {fr}Physique : {pt-br}Físico : {de}Physikalisch : ", gStates.resourceTracker.siege.physical}),
							SiegeAmountFirexText=joinLang({"{en}Fire : {ru}Огненная(ый): {zh-tw}火焰：{zh-cn}火焰：{ko}불 : {es}Fuego : {fr}Feu : {pt-br}Fogo : {de}Feuer : ", gStates.resourceTracker.siege.fire}),
							SiegeAmountIcexxText=joinLang({"{en}Ice : {ru}Ледяная(ой): {zh-tw}寒冰：{zh-cn}寒冰：{ko}얼음 : {es}Hielo : {fr}Glace : {pt-br}Gelo : {de}Eis : ", gStates.resourceTracker.siege.ice}),
							SiegeAmountColdFText=joinLang({"{en}Cold Fire : {ru}Холодный огонь: {zh-tw}冰火：{zh-cn}冰火：{ko}차가운 불 : {es}Fuego Frío :{fr}Feu Froid : {pt-br}Fogo Frio : {de}Kaltes Feuer : ", gStates.resourceTracker.siege.iceFire}),
						RangeAmountPlainText=joinLang({"{en}Range : {ru}Дальняя: {zh-tw}遠程：{zh-cn}远程：{ko}원거리 : {es}Rango : {fr}Gamme : {pt-br}Distância : {de}Reichweite : ", resourceTotal.ranged}),
							RangeAmountPhysiText=joinLang({"{en}Physical : {ru}Физическая(ий): {zh-tw}物理：{zh-cn}物理：{ko}물리 : {es}Físico : {fr}Physique : {pt-br}Físico : {de}Physikalisch : ", gStates.resourceTracker.ranged.physical}),
							RangeAmountFirexText=joinLang({"{en}Fire : {ru}Огненная(ый): {zh-tw}火焰：{zh-cn}火焰：{ko}불 : {es}Fuego : {fr}Feu : {pt-br}Fogo : {de}Feuer : ", gStates.resourceTracker.ranged.fire}),
							RangeAmountIcexxText=joinLang({"{en}Ice : {ru}Ледяная(ой): {zh-tw}寒冰：{zh-cn}寒冰：{ko}얼음 : {es}Hielo : {fr}Glace : {pt-br}Gelo : {de}Eis : ", gStates.resourceTracker.ranged.ice}),
							RangeAmountColdFText=joinLang({"{en}Cold Fire : {ru}Холодный огонь: {zh-tw}冰火：{zh-cn}冰火：{ko}차가운 불 : {es}Fuego Frío :{fr}Feu Froid : {pt-br}Fogo Frio : {de}Kaltes Feuer : ", gStates.resourceTracker.ranged.iceFire}),
						BlockAmountPlainText=joinLang({"{en}Block : {ru}Блок: {zh-tw}格擋：{zh-cn}格档：{ko}방어 : {es}Bloqueo : {fr}Blocage : {pt-br}Bloqueio : {de}Blockieren : ", resourceTotal.block}),
							BlockAmountPhysiText=joinLang({"{en}Physical : {ru}Физическая(ий): {zh-tw}物理：{zh-cn}物理：{ko}물리 : {es}Físico : {fr}Physique : {pt-br}Físico : {de}Physikalisch : ", gStates.resourceTracker.block.physical}),
							BlockAmountFirexText=joinLang({"{en}Fire : {ru}Огненная(ый): {zh-tw}火焰：{zh-cn}火焰：{ko}불 : {es}Fuego : {fr}Feu : {pt-br}Fogo : {de}Feuer : ", gStates.resourceTracker.block.fire}),
							BlockAmountIcexxText=joinLang({"{en}Ice : {ru}Ледяная(ой): {zh-tw}寒冰：{zh-cn}寒冰：{ko}얼음 : {es}Hielo : {fr}Glace : {pt-br}Gelo : {de}Eis : ", gStates.resourceTracker.block.ice}),
							BlockAmountColdFText=joinLang({"{en}Cold Fire : {ru}Холодный огонь: {zh-tw}冰火：{zh-cn}冰火：{ko}차가운 불 : {es}Fuego Frío :{fr}Feu Froid : {pt-br}Fogo Frio : {de}Kaltes Feuer : ", gStates.resourceTracker.block.iceFire}),
						AttacAmountPlainText=joinLang({"{en}Attack : {ru}Атака: {zh-tw}攻擊：{zh-cn}攻击：{ko}공격 : {es}Ataque : {fr}Attaque : {pt-br}Ataque : {de}Angriff : ", resourceTotal.attack}),
							AttacAmountPhysiText=joinLang({"{en}Physical : {ru}Физическая(ий): {zh-tw}物理：{zh-cn}物理：{ko}물리 : {es}Físico : {fr}Physique : {pt-br}Físico : {de}Physikalisch : ", gStates.resourceTracker.attack.physical}),
							AttacAmountFirexText=joinLang({"{en}Fire : {ru}Огненная(ый): {zh-tw}火焰：{zh-cn}火焰：{ko}불 : {es}Fuego : {fr}Feu : {pt-br}Fogo : {de}Feuer : ", gStates.resourceTracker.attack.fire}),
							AttacAmountIcexxText=joinLang({"{en}Ice : {ru}Ледяная(ой): {zh-tw}寒冰：{zh-cn}寒冰：{ko}얼음 : {es}Hielo : {fr}Glace : {pt-br}Gelo : {de}Eis : ", gStates.resourceTracker.attack.ice}),
							AttacAmountColdFText=joinLang({"{en}Cold Fire : {ru}Холодный огонь: {zh-tw}冰火：{zh-cn}冰火：{ko}차가운 불 : {es}Fuego Frío :{fr}Feu Froid : {pt-br}Fogo Frio : {de}Kaltes Feuer : ", gStates.resourceTracker.attack.iceFire}),
						InfluAmountPlainText=joinLang({"{en}Influence : {ru}Влияние: {zh-tw}影響力：{zh-cn}影响力：{ko}영향력 : {es}Influencia : {fr}Influence : {pt-br}Influência : {de}Einfluss : ", resourceTotal.influence}),
							InfluAmountPhysiText=joinLang({"{en}Generated : {ru}Сгенерировано: {zh-tw}產生的：{zh-cn}产生的：{ko}사용 : {es}Generación : {fr}Généré : {pt-br}Gerado : {de}Erzeugt : ", gStates.resourceTracker.influence.generated}),
							InfluAmountReputText=joinLang({"{en}Reputation : {ru}Репутация: {zh-tw}聲譽：{zh-cn}声誉：{ko}평판 : {es}Reputación : {fr}Réputation : {pt-br}Reputação : {de}Reputation : ", gStates.resourceTracker.influence.reputation}),
							InfluAmountCitySText=joinLang({"{en}City Shields : {ru}Щиты на городе: {zh-tw}城市的盾徽：{zh-cn}城市的盾徽：{ko}도시 방패 토큰 : {es}Escudos de la Ciudad : {fr}Boucliers de Ville : {pt-br}Escudos das Cidades : {de}Stadtschilde : ", gStates.resourceTracker.influence.cityShields}),
						MovemAmountPlainText=joinLang({"{en}Move : {ru}Движение: {zh-tw}移動：{zh-cn}移动：{ko}이동 : {es}Mover : {fr}Se déplacer : {pt-br}Mover : {de}Bewegen : ", gStates.resourceTracker.move.move}),
							MoveCostPlainText=joinLang({"{en}Plains : {ru}Равнины: {zh-tw}平原：{zh-cn}平原：{ko}평지 :{es}Llanuras : {fr}Plaines : {pt-br}Planícies : {de}Ebenen : ", gStates.moveCost.plains}),
							MoveCostHillsText=joinLang({"{en}Hills : {ru}Холмы: {zh-tw}丘陵：{zh-cn}丘陵：{ko}언덕 : {es}Colinas : {fr}Collines : {pt-br}Colinas : {de}Hügel : ", gStates.moveCost.hills}),
							MoveCostForesText=joinLang({"{en}Forests : {ru}Леса: {zh-tw}森林：{zh-cn}森林：{ko}숲 : {es}Bosques : {fr}Forêts : {pt-br}Florestas : {de}Wälder : ", gStates.moveCost.forest}),
							MoveCostWasteText=joinLang({"{en}Wastelands : {ru}Пустоши: {zh-tw}荒原：{zh-cn}荒原：{ko}황무지 : {es}Páramos : {fr}Terrains Vagues : {pt-br}Terras Devastadas : {de}Ödland : ", gStates.moveCost.wasteland}),
							MoveCostDeserText=joinLang({"{en}Deserts : {ru}Пустыни: {zh-tw}沙漠：{zh-cn}沙漠：{ko}사막 : {es}Desiertos : {fr}Déserts : {pt-br}Desertos : {de}Wüsten : ", gStates.moveCost.desert}),
							MoveCostSwampText=joinLang({"{en}Swamps : {ru}Болота: {zh-tw}沼澤：{zh-cn}沼泽：{ko}늪 : {es}Pantanos : {fr}Marécages : {pt-br}Pântanos : {de}Sümpfe : ", gStates.moveCost.swamp}),
							MoveCostLakesText=joinLang({"{en}Lakes : {ru}Озера: {zh-tw}湖泊：{zh-cn}湖泊：{ko}호수 : {es}Lagos : {fr}Lacs : {pt-br}Lagos : {de}Seen : ", lake}),
							MoveCostMountText=joinLang({"{en}Mountains : {ru}Горы: {zh-tw}山脈：{zh-cn}山脉：{ko}산 : {es}Montañas : {fr}Montagnes : {pt-br}Montanhas : {de}Berge : ", mountain})}
	for element, value in pairs(baseValues) do
		UI.setAttribute(element, "text", value)
	end
end

function recourceTrackerReset(type)
	if type~="update" then
		gStates.resourceTracker={move=		{move=0},
								siege=		{physical=0, fire=0, ice=0, iceFire=0},
								ranged=		{physical=0, fire=0, ice=0, iceFire=0},
								block=		{physical=0, fire=0, ice=0, iceFire=0},
								attack=		{physical=0, fire=0, ice=0, iceFire=0},
								influence=	{generated=0, reputation=0, cityShields=0},
								healing=	{healing=0}}
		gStates.moveCost={["plains"]=2, ["hills"]=3, ["forest"]=5, ["wasteland"]=4, ["desert"]=3, ["swamp"]=5, ["lake"]=999, ["mountain"]=999, ["city"]=2, ["explore"]=2}
		if gStates.dayRound==true then gStates.moveCost={["plains"]=2, ["hills"]=3, ["forest"]=3, ["wasteland"]=4, ["desert"]=5, ["swamp"]=5, ["lake"]=999, ["mountain"]=999, ["city"]=2, ["explore"]=2} end
	end
	updateMoveDisplay()
	gStates.resourceTracker.influence.reputation=-99
	if reputationTable[turnOrder[gStates.turnNumber].reputation].repDisplay~="No Interaction" then
		gStates.resourceTracker.influence.reputation=tonumber(reputationTable[turnOrder[gStates.turnNumber].reputation].repDisplay)
	end
	refreshResourceTrackerText()
end
function legacyObjectButtonImage(id,image)
	if id==nil then return false end
	local obj=getObjectFromGUID(tostring(id):sub(1,6))
	if obj==nil then return false end
	obj.UI.setAttribute(tostring(id).."Image","image",image)
	return true
end

--Some permanent object UIs (notably the Artifact deck) are stored on the object itself and
--still call these handlers. They were lost when the common animation helper was consolidated.
function ButtonClickDown(player,mouseButton,id)
	if mouseButton~="-1" then return end
	legacyObjectButtonImage(id,"Sliced Button/Button Object Deactive")
end
function ButtonClickUp(player,mouseButton,id)
	if mouseButton~="-1" then return end
	legacyObjectButtonImage(id,"Sliced Button/Button Object Active")
end
function ButtonClickDownOverkill(player,mouseButton,id)
	if mouseButton~="-1" then return end
	local image=tostring(id):find("Down",1,true)~=nil and "Overkill Down Deactive" or "Overkill Up Deactive"
	legacyObjectButtonImage(id,image)
end
function ButtonClickUpOverkill(player,mouseButton,id)
	if mouseButton~="-1" then return end
	local image=tostring(id):find("Down",1,true)~=nil and "Overkill Down" or "Overkill Up"
	legacyObjectButtonImage(id,image)
end

buttonImageResetGeneration={}
function buttonClicked(player, mouseButton, ButtonPressed)
	if mouseButton~="-1" then return end

	local obj=getObjectFromGUID(ButtonPressed:sub(1,6))
	local ui=obj and obj.UI or UI
	local active, deactive

	if ButtonPressed:find("LevelUp",1,true)~=nil or ButtonPressed:find("OverkillUp",1,true)~=nil or ButtonPressed:find("ArtifactUp",1,true)~=nil or ButtonPressed:find("changeMatUp",1,true)~=nil then
		active, deactive="Overkill Up", "Overkill Up Deactive"
	elseif ButtonPressed:find("LevelDown",1,true)~=nil or ButtonPressed:find("OverkillDown",1,true)~=nil or ButtonPressed:find("ArtifactDown",1,true)~=nil or ButtonPressed:find("changeMatDown",1,true)~=nil then
		active, deactive="Overkill Down", "Overkill Down Deactive"
	elseif obj then
		active, deactive="Sliced Button/Button Object Active", "Sliced Button/Button Object Deactive"
	else
		active, deactive="Sliced Button/Button New Active", "Sliced Button/Button New Deactive"
	end

	local image=ButtonPressed.."Image"
	ui.setAttribute(image, "image", ui.getAttribute(image, "image")==active and deactive or active)

	--onClick can rebuild an object's XML before TTS delivers onMouseUp. That used to leave
	--triangle controls (Artifact rewards, faction Leaders, Dragon heads, etc.) permanently in
	--their pressed image. Give every animated button the same delayed return-to-active safety.
	buttonImageResetGeneration[ButtonPressed]=(buttonImageResetGeneration[ButtonPressed] or 0)+1
	local resetGeneration=buttonImageResetGeneration[ButtonPressed]
	local objectGUID=obj~=nil and obj.guid or nil
	safeWaitTime("UI",function()
		if buttonImageResetGeneration[ButtonPressed]~=resetGeneration then return end
		local resetUI=UI
		if objectGUID~=nil then
			local currentObject=getObjectFromGUID(objectGUID)
			if currentObject==nil then buttonImageResetGeneration[ButtonPressed]=nil return end
			resetUI=currentObject.UI
		end
		local currentImage=resetUI.getAttribute(image, "image")
		local interactable=resetUI.getAttribute(ButtonPressed, "interactable")
		if currentImage~=nil and currentImage~="" and interactable~="false" then resetUI.setAttribute(image, "image", active) end
		buttonImageResetGeneration[ButtonPressed]=nil
	end, 0.35)
end

function valueAdjust(player, mouseButton, id)
	if mouseButton=="-1" and legalPlayerCheck(player.color, turnOrder[gStates.turnNumber].seatPos)==true then
		if id=="GrowHand" and turnOrder[gStates.turnNumber].hand+turnOrder[gStates.turnNumber].handBonus+gStates.tactic4HandBonus<20 then turnOrder[gStates.turnNumber].handBonus=turnOrder[gStates.turnNumber].handBonus+1 end
		if id=="ShrinkHand" and turnOrder[gStates.turnNumber].hand+turnOrder[gStates.turnNumber].handBonus+gStates.tactic4HandBonus>turnOrder[gStates.turnNumber].baseHand then turnOrder[gStates.turnNumber].handBonus=turnOrder[gStates.turnNumber].handBonus-1 end
		if id=="GrowFame" then turnOrder[gStates.turnNumber].fameGain=turnOrder[gStates.turnNumber].fameGain+1 end
		if id=="ShrinkFame" and turnOrder[gStates.turnNumber].fameGain>0 then turnOrder[gStates.turnNumber].fameGain=turnOrder[gStates.turnNumber].fameGain-1 end
		if id=="GrowRep" and turnOrder[gStates.turnNumber].repGain< (7-turnOrder[gStates.turnNumber].reputation) then turnOrder[gStates.turnNumber].repGain=turnOrder[gStates.turnNumber].repGain+1 end
		if id=="ShrinkRep" and turnOrder[gStates.turnNumber].repGain>(-7-turnOrder[gStates.turnNumber].reputation) then turnOrder[gStates.turnNumber].repGain=turnOrder[gStates.turnNumber].repGain-1 end
		mainUIUpdate("Value Adjusted")
	end
end

function closeSplash() UI.hide("welcome") end

function buildMageKnightFastLookups()
	mageKnightsByName={}
	mageKnightAvatarGUIDs={}
	for _, details in pairs(mageKnights) do
		mageKnightsByName[details.mage]=details
		if details.mage~="Volkare" and details.mage~="Random" and details.mage~="nobody" then
			if details.model~=nil and details.model~="" then mageKnightAvatarGUIDs[details.model]=true end
			if details.token~=nil and details.token~="" then mageKnightAvatarGUIDs[details.token]=true end
			if details.standee~=nil and details.standee~="" then mageKnightAvatarGUIDs[details.standee]=true end
		end
	end
end
buildMageKnightFastLookups()

function mageKnightAvatarObjectByName(mage, preferStandee)
	local details=mageKnightsByName[mage]
	if details==nil then return nil end
	local first=preferStandee==true and details.standee or details.model
	local second=details.token
	local third=preferStandee==true and details.model or details.standee
	local avatar=first~=nil and first~="" and getObjectFromGUID(first) or nil
	if avatar~=nil then return avatar end
	avatar=second~=nil and second~="" and getObjectFromGUID(second) or nil
	if avatar~=nil then return avatar end
	return third~=nil and third~="" and getObjectFromGUID(third) or nil
end
function mageKnightAvatarPositionByName(mage)
	local avatar=mageKnightAvatarObjectByName(mage,true)
	return avatar~=nil and avatar.getPosition() or nil
end
function mageKnightAvatarObject(playerIndex, preferStandee)
	return turnOrder[playerIndex]~=nil and mageKnightAvatarObjectByName(turnOrder[playerIndex].mage,preferStandee) or nil
end
function mageKnightAvatarPosition(playerIndex)
	return turnOrder[playerIndex]~=nil and mageKnightAvatarPositionByName(turnOrder[playerIndex].mage) or nil
end


function applyAltViewAngle(obj)
	if obj==nil then return end
	for _, cityGUID in pairs(cityModel) do
		if obj.guid==cityGUID then
			obj.alt_view_angle={CITY_ALT_VIEW_ANGLE[1], CITY_ALT_VIEW_ANGLE[2], CITY_ALT_VIEW_ANGLE[3]}
			return
		end
	end
	for _, details in pairs(mageKnights) do
		if details.mage~="Volkare" and details.mage~="Random" and details.mage~="nobody" and
			(obj.guid==details.model or obj.guid==details.token or obj.guid==details.standee) then
			obj.alt_view_angle={AVATAR_ALT_VIEW_ANGLE[1], AVATAR_ALT_VIEW_ANGLE[2], AVATAR_ALT_VIEW_ANGLE[3]}
			return
		end
	end
	--These bag meshes change their effective ALT axis at different stack-height thresholds. Y scale equals effective token count.
	if obj.guid==monsterPiles.rewardElem or obj.guid==monsterPiles.rewardDark or obj.guid==monsterPiles.rewardCouncil or obj.guid==monsterPiles.rewardApoc then
		local angle=REWARD_BAG_ALT_VIEW_ANGLE
		if obj.getScale()[2]<=11 then angle=REWARD_BAG_LOW_COUNT_ALT_VIEW_ANGLE end
		obj.alt_view_angle={angle[1], angle[2], angle[3]}
		return
	end
	if obj.guid==monsterPiles.yellow then
		local angle=RUIN_BAG_ALT_VIEW_ANGLE
		if obj.getScale()[2]<=10 then angle=RUIN_BAG_LOW_COUNT_ALT_VIEW_ANGLE end
		obj.alt_view_angle={angle[1], angle[2], angle[3]}
		return
	end
	if obj.guid==monsterPiles.possessed then
		obj.alt_view_angle={POSSESSED_BAG_ALT_VIEW_ANGLE[1], POSSESSED_BAG_ALT_VIEW_ANGLE[2], POSSESSED_BAG_ALT_VIEW_ANGLE[3]}
		return
	end
	if obj.guid==monsterPiles.zigguratTrap or obj.guid==monsterPiles.pyramidTrap then
		obj.alt_view_angle={ZIGGURAT_PYRAMID_BAG_ALT_VIEW_ANGLE[1], ZIGGURAT_PYRAMID_BAG_ALT_VIEW_ANGLE[2], ZIGGURAT_PYRAMID_BAG_ALT_VIEW_ANGLE[3]}
		return
	end
	for pileName, bagGUID in pairs(monsterPiles) do
		if pileName~="rewardElem" and pileName~="rewardDark" and pileName~="rewardCouncil" and pileName~="rewardApoc" and obj.guid==bagGUID then
			local angle=MONSTER_BAG_ALT_VIEW_ANGLE
			if obj.getScale()[2]<=11 then angle=MONSTER_BAG_LOW_COUNT_ALT_VIEW_ANGLE end
			obj.alt_view_angle={angle[1], angle[2], angle[3]}
			return
		end
	end
	--Discard stacks switch ALT axis as they grow. Ruin discard reaches the mesh boundary earlier than the other flipped discard bags.
	if obj.guid==GUID.bag.discard.ruin or obj.guid==GUID.bag.discard.possessed or
		obj.guid==GUID.bag.discard.darkReward or obj.guid==GUID.bag.discard.elementalistReward or
		obj.guid==GUID.bag.discard.apocReward or obj.guid==GUID.bag.discard.councilReward then
		local angle=FLIPPED_DISCARD_BAG_ALT_VIEW_ANGLE
		local highCountThreshold=obj.guid==GUID.bag.discard.ruin and 11 or 13
		if obj.getScale()[2]>=highCountThreshold then
			if obj.guid==GUID.bag.discard.ruin then angle=RUIN_DISCARD_BAG_HIGH_COUNT_ALT_VIEW_ANGLE
			elseif obj.guid==GUID.bag.discard.darkReward or obj.guid==GUID.bag.discard.elementalistReward or obj.guid==GUID.bag.discard.apocReward or obj.guid==GUID.bag.discard.councilReward then angle=REWARD_DISCARD_BAG_HIGH_COUNT_ALT_VIEW_ANGLE
			else angle=FLIPPED_DISCARD_BAG_HIGH_COUNT_ALT_VIEW_ANGLE end
		end
		obj.alt_view_angle={angle[1], angle[2], angle[3]}
		return
	end
	for _, bagGUID in pairs(GUID.bag.discard) do
		if obj.guid==bagGUID then
			local angle=DISCARD_BAG_ALT_VIEW_ANGLE
			if obj.getScale()[2]>=13 then angle=DISCARD_BAG_HIGH_COUNT_ALT_VIEW_ANGLE end
			obj.alt_view_angle={angle[1], angle[2], angle[3]}
			return
		end
	end
end

function refreshAltViewAngles()
	for _, cityGUID in pairs(cityModel) do applyAltViewAngle(getObjectFromGUID(cityGUID)) end
	for _, details in pairs(mageKnights) do
		if details.mage~="Volkare" and details.mage~="Random" and details.mage~="nobody" then
			if details.model~=nil and details.model~="" then applyAltViewAngle(getObjectFromGUID(details.model)) end
			if details.token~=nil and details.token~="" then applyAltViewAngle(getObjectFromGUID(details.token)) end
			if details.standee~=nil and details.standee~="" then applyAltViewAngle(getObjectFromGUID(details.standee)) end
		end
	end
	for _, bagGUID in pairs(monsterPiles) do applyAltViewAngle(getObjectFromGUID(bagGUID)) end
	for _, bagGUID in pairs(GUID.bag.discard) do applyAltViewAngle(getObjectFromGUID(bagGUID)) end
end

-- End-turn/end-round entry points are also callback boundaries. Most cleanup is synchronous, so wrapping
-- these catches errors from nested cleanup such as monster/Quest disposal that TTS UI callbacks would
-- otherwise report only locally. Keep the public names unchanged for XML and internal callers.

--Monster Replenish no longer carries its own Lua/XML. Rebuild its physical Restock button from
--Global, and keep the old status ids as hidden targets for existing swap/status helpers.
function monsterReplenishObjectOnLoad()
	local obj=getObjectFromGUID("d7a165")
	if obj==nil then return end
	obj.UI.setXml([=[
<Button id="d7a165replenishMonsterPiles" interactable="true"
    onClick="global/returnPugs"
    tooltipPosition="Left" tooltipBackgroundColor="clear" tooltipOffset="20"
    width="900" height="200" color="#7F7F7F" textColor="#FFFFFF"
    position="200 270 -100" rotation="0 0 0" scale="0.48 0.48"
    shadow="rgb(0, 0, 0)" shadowDistance="0 -0">
    <Image id="d7a165replenishMonsterPilesImage" image="Sliced Button/Button Object Active" type="Sliced"/>
    <HorizontalLayout padding="30 30 30 30">
        <Text id="d7a165replenishMonsterPilesText" fontSize="90" font="Fonts/MKCardText" fontStyle="Normal"
            textColor="rgb(0, 0, 0)" offsetXY="0 1" alignment="MiddleCenter"
            resizeTextForBestFit="true" resizeTextMaxSize="90">{en}Restock Empty Piles{ru}Восполнить пустые стопки{zh-tw}補齊抽空的標記{zh-cn}补齐抽空的标记{ko}빈 토큰더미채우기{es}Reabastecer Vacío Pilas{fr}Réapprovisionner Vider Les piles{pt-br}Reestocar Pilhas Vazias{de}Leere Stapel auffüllen</Text>
    </HorizontalLayout>
</Button>
<Text id="d7a165swapMonsterImageText" active="false"></Text>
<Text id="d7a165swapTableText" active="false"></Text>
]=])
end

local ARTIFACT_GUID = "ac75c4"
local ARTIFACT_UI = [=[
<Button id="ac75c4ArtifactDown" active="false" onMouseDown="global/ButtonClickDownOverkill" onMouseUp="global/ButtonClickUpOverkill" onClick="global/artifactAdjust"
    height="150" width="150" color="rgba(0,0,0,0.0)" position="-120 190 5" rotation="0 180 180" scale="0.32 0.32">
    <Image id="ac75c4ArtifactDownImage" image="Overkill Down"></Image>
</Button>
<Button id="ac75c4ArtifactOffer" active="false" onMouseDown="global/ButtonClickDown" onMouseUp="global/ButtonClickUp" onClick="global/offerArtifacts"
    height="150" width="540" color="rgba(0,0,0,0.0)" position="0 190 5" rotation="0 180 180" scale="0.32 0.32">
    <Image id="ac75c4ArtifactOfferImage" image="Sliced Button/Button Object Active" type="Sliced"></Image>
    <Text id="ac75c4ArtifactOfferText" font="Fonts/MKCardText" fontSize="90" color="black" fontStyle="Normal" alignment="MiddleCenter">{en}Reward 1{ru}Награда 1{zh-tw}獎勵1{zh-cn}奖励1{ko}보상 1{es}Recompensa 1{fr}Récompense 1{pt-br}Recompensa 1{de}Belohnung 1</Text>
</Button>
<Button id="ac75c4ArtifactUp" active="false" onMouseDown="global/ButtonClickDownOverkill" onMouseUp="global/ButtonClickUpOverkill" onClick="global/artifactAdjust"
    height="150" width="150" color="rgba(0,0,0,0.0)" position="120 190 5" rotation="0 180 180" scale="0.32 0.32">
    <Image id="ac75c4ArtifactUpImage" image="Overkill Up"></Image>
</Button>
]=]

local function installArtifactUI(attempt)
    local artifacts = getObjectFromGUID(ARTIFACT_GUID)
    if artifacts ~= nil then
        --Keep the localization tags in the XML itself. TTS resolves those when setXml loads the
        --object UI; reapplying the same tagged string through setAttribute displays every language.
        artifacts.UI.setXml(ARTIFACT_UI)
        return
    end
    if attempt < 60 then safeWaitFrames("UI",function() installArtifactUI(attempt + 1) end, 1) end
end

function artifactOnLoad()
    installArtifactUI(1)
end

-- Day/night tint control
function nightTint(player, mouseButton, id)
	if mouseButton=="-1" then
		local tileColor={}
		if getObjectFromGUID("43fa2e").UI.getAttribute("43fa2eNightTintText", "text")=="No Tint" then
			getObjectFromGUID("43fa2e").UI.setAttribute("43fa2eNightTintText", "text", "{en}Add Tint{ru}Добавить оттенок{zh-tw}加入色調{zh-cn}加入色调{ko}색조 추가{es}Añadir Tinte{fr}Ajouter une Teinte{pt-br}Adicionar Tonalidade{de}Tönung hinzufügen")
			tileColor={r=1.0, g=1.0, b=1.0}
			gStates.nightTint=false
		else
			getObjectFromGUID("43fa2e").UI.setAttribute("43fa2eNightTintText", "text", "{en}No Tint{ru}Без оттенка{zh-tw}無色調{zh-cn}无色调{ko}색조 없음{es}Sin Tinte{fr}Sans Teinte{pt-br}Sem Tonalidade{de}Keine Tönung")
			tileColor={r=0.6, g=0.6, b=0.6}
			gStates.nightTint=true
		end
		--Make terrain tile light or dark
		for a, _ in pairs(terrainTiles) do
			local obj=getObjectFromGUID(a)
			if obj~=nil then obj.setColorTint(tileColor) end
		end
		if gStates.mapShape:sub(5,5)=="P" and gStates.gameScenario~="The Gauntlet" and gStates.gameScenario~="Against the Horsemen Blitz" then
			local terrainDummy=getObjectFromGUID(startTerrain.open)
			if terrainDummy==nil then terrainDummy=getObjectFromGUID(startTerrain.wedge) end
			onObjectEnterZone({guid=mapArea}, terrainDummy)
		end
	end
end

-- Shared object claim button builder
function createClaimButton(objGUID, source)
	local onClick="global/claimMove"
	local width=500
	local height=150
	local scale=0.32
	local position="0 190 -10"
	local rotation="0 0 180"
	local text="{en}^ CLAIM{ru}^ ЗАБРАТЬ{zh-tw}^ 選取{zh-cn}^ 选取{ko}^ 선택{es}^ RECLAMO{fr}^ Demande{pt-br}^ CLAMAR{de}^ ANSPRUCH"
	local fontSize="90"
	--Meditation / Trance uses the exact same proven object-UI structure as Claim.
	--Coordinates are tuned for four target spots marked during testing:
	--red pair = Meditation, green pair = Trance.
	if source=="meditationTop" or source=="meditationBot" or source=="tranceTop" or source=="tranceBot" then
		width=250
		onClick=(source=="meditationTop" or source=="tranceTop") and "global/meditationTranceTop" or "global/meditationTranceBot"
		text=(source=="meditationTop" or source=="tranceTop") and "Top" or "Bot"
		if source=="meditationTop" then position="155 -105 -10" end
		if source=="meditationBot" then position="155 -50 -10" end
		if source=="tranceTop" then position="155 35 -10" end
		if source=="tranceBot" then position="155 105 -10" end
	end
	--Steady Tempo reuses the same small object-button style. These sit beside the
	--upper, middle and lower sections of the card: Discard, Bottom, Top.
	if source=="steadyTempoDiscard" or source=="steadyTempoBot" or source=="steadyTempoTop" then
		width=250
		onClick="global/steadyTempoChoice"
		if source=="steadyTempoDiscard" then text="{en}Dis{ru}Сбр{zh-tw}棄{zh-cn}弃{ko}버림{es}Des{fr}Déf{pt-br}Des{de}Abl" position="155 -130 -10" end
		if source=="steadyTempoBot" then text="{en}Bot{ru}Низ{zh-tw}底{zh-cn}底{ko}아래{es}Inf{fr}Bas{pt-br}Inf{de}Unt" position="155 0 -10" end
		if source=="steadyTempoTop" then text="{en}Top{ru}Верх{zh-tw}頂{zh-cn}顶{ko}위{es}Sup{fr}Haut{pt-br}Sup{de}Oben" position="155 130 -10" end
	end
	for a=1, 32, 1 do
		if source==tostring(a) or source=="higherLevelSkill" then
			if source==tostring(a) then	onClick="global/skillMove" else onClick="global/higherLevelSkill" end
			width=175
			position="-270 0 -1"
			text="<"
			scale=scale*2.307692307692308
			break
		end
	end
	if source:sub(1,6)=="tactic" or source:sub(1,12)=="removeTactic" then
		position="0 130 -1"
		scale=scale*0.6521739130434783
		if source:sub(1,12)=="removeTactic" then
			text="{en}^ REMOVE{ru}^ УДАЛИТЬ{zh-tw}^ 移除{zh-cn}^ 移除{ko}^ 제거{es}^ QUITAR{fr}^ Supprimer{pt-br}^ REMOVER{de}^ ENTFERNEN"
			onClick="global/removeTactic"
		end
		if source=="tactic7" or source=="removeTactic5" then
			width=1200
			scale=scale*2.416666666666667
			rotation="180 180 180"
			if source=="tactic7" then
				position="0 211 -29"
				onClick=("global/"..automatedPlayerTurnFunction())
				text="{en}Pick Random for Dummy{ru}Случайный для виртуального игрока{zh-tw}為虛擬玩家隨機選擇戰術卡{zh-cn}为虚拟玩家随机选择战术卡{ko}가상 플레이어 무작위 선택{es}Elija al Azar para el Maniquí{fr}Elija al Azar Para el Maniquí{pt-br}Escolha Aleatória para o Dummy{de}Zufallsauswahl für Dummy"
				if proxyPlayerActive()==true then text="{en}Pick Random for Proxy{ru}Случайная тактика для прокси{zh-tw}為代理玩家隨機選擇戰術卡{zh-cn}为代理玩家随机选择战术卡{ko}프록시 무작위 선택{es}Elegir al Azar para Proxy{fr}Tirer au Sort pour le Proxy{pt-br}Escolha Aleatória para o Proxy{de}Zufallsauswahl für Proxy" end
				if gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz" or gStates.gameScenario=="Volkare's Quest" then
					text="{en}Pick Random for Volkare{ru}Случайный для Волкара{zh-tw}為沃卡里隨機選擇戰術卡{zh-cn}为沃卡里随机选择战术卡{ko}볼케어 무작위 선택{es}Elige al Azar para Volkare{fr}Tirez au Sort pour Volkare{pt-br}Escolha Aleatório para Volkare{de}Zufallsauswahl für Volkare"
				end
			else
				position="-400 211 -29"
				onClick="global/removeTactic"
				text="{en}^ Remove Both ^{ru}^ Удалить обе ^{zh-tw}^ 雙雙移除 ^{zh-cn}^ 双双移除 ^{ko}^ 둘 다 제거 ^{es}^ Quitar Ambos ^{fr}^ Supprimer les Deux ^{pt-br}^ Remover Ambos ^{de}^ Beide Entfernen ^"
			end
		end
	end
    return {tag="Button", attributes={id=objGUID..source, onClick=onClick, onMouseDown="global/buttonClicked", onMouseUp="global/buttonClicked", height=height, width=width, position=position, rotation=rotation, scale=tostring(scale).." "..tostring(scale)},
		children={{tag="Image", attributes={id=objGUID..source.."Image", image="Sliced Button/Button Object Active", type="Sliced"}},
				  {tag="HorizontalLayout", attributes={padding="25 25 25 25"},
				  children={{tag="Text", attributes={id=objGUID..source.."Text", font="Fonts/MKCardText", fontSize=fontSize, fontStyle="Normal", alignment="MiddleCenter", resizeTextForBestFit="true", resizeTextMaxSize=fontSize, text=text}}}}}}
end

-- Player colour and board presentation controls
function changePositionColor(player, mouseButton, id)
	local barConversion={[colorBand[1]]=1, [colorBand[2]]=2, [colorBand[3]]=3, [colorBand[4]]=4}
	local barGUID=id:sub(1,6)
	local newColor=id:sub(7, string.len(id))
	local currentColor=Hands.getHands()[barConversion[barGUID]].getValue()
	if mouseButton=="-1" and legalPlayerCheck(player.color, gStates.handColors[currentColor], "NoDummyException")==true then
		--swap an existing unused color to stop two hands having the same colour
		if gStates.handColors[newColor]~=nil then
			for _, freeHandColor in pairs(Player.getColors()) do
				if gStates.handColors[freeHandColor]==nil then
					Hands.getHands()[gStates.handColors[newColor]].setValue(freeHandColor)
					gStates.handColors[freeHandColor]=gStates.handColors[newColor]
					gStates.handColors[newColor]=nil
					break
				end
			end
		end
		--change hand colour
		gStates.handColors[newColor]=gStates.handColors[currentColor]
		gStates.handColors[currentColor]=nil
		Hands.getHands()[barConversion[barGUID]].setValue(newColor)
		Player[currentColor].changeColor(newColor)
		applyColorBarButtons()
		refreshPlayerSeatColors()
		outOfTurnUIStateKey=nil
		mainUIUpdate("Player Changed Colour")
		safeWaitFrames("UI",function() Player[newColor].lookAt({position={getObjectFromGUID(barGUID).getPosition()[1], getObjectFromGUID(barGUID).getPosition()[2], getObjectFromGUID(barGUID).getPosition()[3]-10}, pitch=75, yaw=0, distance=30}) end, 2)
	end
end

function changeMatImage(player, mouseButton, id)
	local barConversion={[colorBand[1]]=1, [colorBand[2]]=2, [colorBand[3]]=3, [colorBand[4]]=4}
	if mouseButton=="-1" and legalPlayerCheck(player.color, gStates.handColors[Hands.getHands()[barConversion[id:sub(1,6)]].getValue()], "NoDummyException")==true then
		local convert={[colorBand[1]]=playerBoard[1], [colorBand[2]]=playerBoard[2], [colorBand[3]]=playerBoard[3], [colorBand[4]]=playerBoard[4]}
		local board=getObjectFromGUID(convert[id:sub(1, 6)])
		local direction=1
		local boardImages={	"https://steamusercontent-a.akamaihd.net/ugc/1684895445424376912/3EE3230EE7EDE9465FBACB66989433E76889EE1B/",
							"https://steamusercontent-a.akamaihd.net/ugc/1684895445424553574/3C342119E5460E99D2CBA90E02703DEFE192A8D2/",
							"https://steamusercontent-a.akamaihd.net/ugc/1684895445424553344/A14FCE5B44805580B609C6331AE493DBF57DFF16/",
							"https://steamusercontent-a.akamaihd.net/ugc/1684895445424553120/FDF4B2E37BB40F81AD7A1DFC45FD3080EDBDD479/",
							"https://steamusercontent-a.akamaihd.net/ugc/1684895445424552867/531D8782F39294923F405B4A8BD33749FFCDC397/",
							"https://steamusercontent-a.akamaihd.net/ugc/1684895445424552298/DCE7288AD482269EF78E138258AEF64E02FB75F0/",
							"https://steamusercontent-a.akamaihd.net/ugc/1684895445424551898/6ED5EFA1552854F7F03E318B5DF1181E4A6388F1/",
							"https://steamusercontent-a.akamaihd.net/ugc/1684895445424551449/B2E1AD69C97515E4AA0B3B99B899DF3F00303E3A/",
							"https://steamusercontent-a.akamaihd.net/ugc/1684895445424553771/4BC2365C114D1D2EFA40127F12FE662927D7A658/",
							"https://steamusercontent-a.akamaihd.net/ugc/1684895445424553972/80BE3DDEAA19CADEAACE68ED263F52DB65465CF6/",
							"https://steamusercontent-a.akamaihd.net/ugc/1684895445424554181/1E919EDF42F1F900A53EE84DC6B24E0CCAE551B0/",
							"https://steamusercontent-a.akamaihd.net/ugc/1684895445424555147/6F7C91142DBDC2CC969E4C55760359791F0D89F8/",
							"https://steamusercontent-a.akamaihd.net/ugc/1684895445424601741/960077146FB0A7EFA4F5F54B6BD5B477BDFF5A6F/",
							"https://steamusercontent-a.akamaihd.net/ugc/1684895445424554674/5FC29A5A6972EED68545A897F9280FA3C954179F/",
							"https://steamusercontent-a.akamaihd.net/ugc/1684895445424554433/5E1CAFCDD9764C7370E9CA387E1E250FFBE95EEA/",
							"https://steamusercontent-a.akamaihd.net/ugc/1684895445424467915/9C5DD81B7345C49DB8ED3F9A5BA9E1E867855EF7/",
							"https://steamusercontent-a.akamaihd.net/ugc/1684895445424555440/E6D119CAA5633518305C512D82D87D033BCD27F2/",
							"https://steamusercontent-a.akamaihd.net/ugc/1684895445440810937/BD5AB7FC76EBA62C6041C19BEDFF187A191B9A3C/",
							"https://steamusercontent-a.akamaihd.net/ugc/1684895445440811336/57CCCDB1CA59C7EC8D78F36A8F41D867232E751A/",
							"https://steamusercontent-a.akamaihd.net/ugc/1684895445440811734/D2494176727E75376EC01F16BBB70E8AE1799238/",
							"https://steamusercontent-a.akamaihd.net/ugc/2546304515596768692/19801470032E2AD7FBC69C3817AD64A01998963F/",
							"https://steamusercontent-a.akamaihd.net/ugc/2546304515596768226/A7A269B1B5492AF4E3692015A1588B3EBD7A0414/"}
		if id:sub(7, 17)=="changeMatUp" then direction=-1 end
		for a=1, #boardImages, 1 do
			if boardImages[a]==board.getCustomObject().image and ((a>1 and direction==-1) or (a<#boardImages and direction==1)) then
				board.setCustomObject({image=boardImages[a+direction]})
				break
			end
			if boardImages[a]==board.getCustomObject().image and a==#boardImages then
				board.setCustomObject({image=boardImages[1]})
				break
			end
			if boardImages[a]==board.getCustomObject().image and a==1 then
				board.setCustomObject({image=boardImages[#boardImages]})
				break
			end
		end
		board.reload()
		safeWaitTime("UI",function() getObjectFromGUID(convert[id:sub(1, 6)]).interactable=false end, 0.2)
	end
end

function bannerOfCommandDecal()
	if getObjectFromGUID("8dbce4").is_face_down==true then
		getObjectFromGUID("8dbce4").UI.setXmlTable({{tag="Image", attributes={id="Command", image="Banner Command",
			height=240, width=125, position="0 -520 40", rotation="0 180 180"}}})
	else
		getObjectFromGUID("8dbce4").UI.setXmlTable({{tag="Image", attributes={id="Command", image="Banner Command",
			height=240, width=125, position="0 -1066 -40", rotation="0 0 180"}}})
	end
end

-- Monster image and auto-flip presentation controls
function monsterImageSwap(player, mouseButton, id)
	if mouseButton=="-1" then
		for monsterGuid, monsterDetails in pairs(monsterPugs) do
			if getObjectFromGUID(monsterGuid)~=nil then
				if gStates.useAlternatePugs==false and (monsterDetails.original~="" or monsterDetails.alternate~="") then
					getObjectFromGUID(monsterGuid).setCustomObject({image=monsterDetails.alternate})
				else
					getObjectFromGUID(monsterGuid).setCustomObject({image=monsterDetails.original})
				end
				getObjectFromGUID(monsterGuid).reload()
			end
		end
		if gStates.useAlternatePugs==false then
			gStates.useAlternatePugs=true
			getObjectFromGUID("d7a165").UI.setAttribute("d7a165swapMonsterImageText", "text", "{en}Stefano Colombo's Monster Tokens - ON{ru}Жетоны монстров Stefano Colombo — ВКЛ.{zh-tw}Stefano Colombo 的怪物標記－開{zh-cn}Stefano Colombo 的怪物标记－开{ko}Stefano Colombo 몬스터 토큰 - 켬{es}Fichas de Monstruo de Stefano Colombo - ACTIVADAS{fr}Jetons de Monstre de Stefano Colombo - ACTIVÉS{pt-br}Fichas de Monstro de Stefano Colombo - ATIVADAS{de}Stefano Colombos Monstermarker - AN")
		else
			gStates.useAlternatePugs=false
			getObjectFromGUID("d7a165").UI.setAttribute("d7a165swapMonsterImageText", "text", "{en}Stefano Colombo's Monster Tokens - OFF{ru}Жетоны монстров Stefano Colombo — ВЫКЛ.{zh-tw}Stefano Colombo 的怪物標記－關{zh-cn}Stefano Colombo 的怪物标记－关{ko}Stefano Colombo 몬스터 토큰 - 끔{es}Fichas de Monstruo de Stefano Colombo - DESACTIVADAS{fr}Jetons de Monstre de Stefano Colombo - DÉSACTIVÉS{pt-br}Fichas de Monstro de Stefano Colombo - DESATIVADAS{de}Stefano Colombos Monstermarker - AUS")
		end
		--discard containers
		local discardContainers={GUID.bag.discard.towerGarrison, GUID.bag.discard.keepGarrison, GUID.bag.discard.cityGarrison, GUID.bag.discard.ruin, GUID.bag.discard.draconum, GUID.bag.discard.dungeon, GUID.bag.discard.orcs, GUID.bag.discard.darkDraconum, GUID.bag.discard.darkDungeon, GUID.bag.discard.darkMarauders, GUID.bag.discard.darkReward, GUID.bag.discard.elementalistDraconum, GUID.bag.discard.elementalistDungeon, GUID.bag.discard.elementalistOrcs, GUID.bag.discard.elementalistReward, GUID.bag.discard.apocReward, GUID.bag.discard.councilReward}
		for _, containerGuid in pairs(discardContainers) do
			if getObjectFromGUID(containerGuid)~=nil and getObjectFromGUID(containerGuid).getQuantity()>0 then
				temp=getObjectFromGUID(containerGuid).takeObject({position={getObjectFromGUID(containerGuid).getPosition()[1], 5, getObjectFromGUID(containerGuid).getPosition()[3]}, smooth=false})
			end
		end
	end
end

---------------
function autoflip()
	if gStates.autoFlip==true then
		gStates.autoFlip=false
		UI.setAttribute("AutoFlipButtonRealImage", "image", "Sliced Button/Button New Active")
		broadcastToAll("{en}Monster tokens need to be flipped manually.{ru}Жетоны врагов необходимо переворачивать вручную.{zh-tw}怪物标记需要手动翻转{zh-cn}怪物标记需要手动翻转{ko}규칙에 따라 직접 토큰을 뒤집어야 합니다{es}Las fichas de monstruo deben voltearse manualmente.{fr}Les jetons Monstre doivent être retournés manuellement.{pt-br}Fichas de Monstros precisam ser viradas manualmente{de}Monsterplättchen müssen manuell umgedreht werden.", {1,1,0.5})
	else
		gStates.autoFlip=true
		UI.setAttribute("AutoFlipButtonRealImage", "image", "Sliced Button/Button New Deactive")
		broadcastToAll("{en}Script will flip monster tokens for you.{ru}Скрипт будет переворачивать жетоны врагов за вас.{zh-tw}脚本将为你翻转怪物标记. {zh-cn}脚本将为你翻转怪物标记. {ko}스크립트가 자동으로 토큰을 뒤집습니다.{es}Script le dará la vuelta a las fichas de monstruos.{fr}Le script retournera les jetons monstre pour vous.{pt-br}O Script virará as fichas de monstros por você.{de}Das Skript dreht die Monsterplättchen für dich um.", {1,1,0.5})
	end
end

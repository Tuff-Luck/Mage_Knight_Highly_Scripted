-- Core scenario lifecycle, original-game rules, and shared scenario entry points.
local oneToReturnPortalTile, oneToReturnSetPortalClosedDecal, oneToReturnPortalOccupant, mineLiberatedForClaim, mineClaimData, clearScenarioEndAchieved, dungeonLordsSecretSourceFeature, dungeonLordsSecretSourcePosition
local dungeonLordsSecretSpaceBasicLegal, dungeonLordsFindAdjacentSecretSource, dungeonLordsSecretDestinationLegal, dungeonLordsSecretLegalDestinationCount, dungeonLordsSecretRequestMatches, dungeonLordsQueueSecretRequest, dungeonLordsPruneImpossibleSecretRequests

function scenarioEliminatePlayersAtPortal(message)
	local eliminated=0
	for playerIndex,details in pairs(turnOrder) do
		if details.mage~=gStates.positionMageKnight[5] and playerDropoutInactive(playerIndex)==false and details.avatarLocation=="portal" then
			details.dropoutState="dropped"
			gStates.skipTurn[playerIndex]=nil
			local token=getObjectFromGUID(details.turnOrderTokenGUID)
			if token~=nil and token.is_face_down==true then token.flip() end
			broadcastToAll(joinLang({translateWord[details.mage],message}),positionToColor(playerIndex))
			eliminated=eliminated+1
		end
	end
	return eliminated
end

--One to Return: the starting Portal closes after the first Day, eliminating anyone still on it.
--After that it is an ordinary single-occupancy plains hex until it reopens at the end of the second Night.
oneToReturnPortalTile=function()
	return volkareQuestPortalTile()
end

oneToReturnSetPortalClosedDecal=function(closed)
	local portalTile=oneToReturnPortalTile()
	if portalTile==nil then return end
	local decals=portalTile.getDecals() or {}
	local kept={}
	local marked=false
	for _, decal in pairs(decals) do
		if decal.name=="Portal Closed" then marked=true else kept[#kept+1]=decal end
	end
	if closed==true then
		if marked==false then portalTile.addDecal({name="Portal Closed",url=volkarePortalClosedDecalURL,position={0,0.15,0},rotation={90,180,0},scale={0.88,0.88,1}}) end
	elseif marked==true then portalTile.setDecals(kept) end
end

function oneToReturnClosePortal()
	if gStates.gameScenario~="One to Return" or gStates.oneToReturnPortalClosed==true then return false end
	gStates.oneToReturnPortalClosed=true
	oneToReturnSetPortalClosedDecal(true)
	broadcastToAll("{en}The Portal has closed. From now on it is an ordinary plains space until the end of the second Night.{it}Il Portale si è chiuso. Ora è un normale spazio pianura fino alla fine della seconda Notte.{ru}Портал закрылся. До конца второй Ночи это обычная клетка Равнины.{zh-tw}傳送門已關閉。從現在起直到第二個夜晚結束，它視為一般平原空間。{zh-cn}传送门已关闭。从现在起直到第二个夜晚结束，它视为一般平原空间。{ko}포털이 닫혔습니다. 두 번째 밤이 끝날 때까지 일반 평원 칸으로 취급합니다.{es}El Portal se ha cerrado. Hasta el final de la segunda Noche es un espacio normal de Llanura.{fr}Le Portail s’est fermé. Jusqu’à la fin de la deuxième Nuit, il s’agit d’une case de Plaine ordinaire.{pt-br}O Portal se fechou. Até o fim da segunda Noite ele é um espaço comum de Planície.{de}Das Portal hat sich geschlossen. Bis zum Ende der zweiten Nacht ist es ein normales Ebenenfeld.", warningColor)
	scenarioEliminatePlayersAtPortal("{en} was still on the Portal when it closed and is out of the game.{it} era ancora sul Portale alla chiusura ed è fuori dalla partita.{ru} оставался на Портале, когда он закрылся, и выбывает из игры.{zh-tw} 在傳送門關閉時仍站在其上，因此退出遊戲。{zh-cn} 在传送门关闭时仍站在其上，因此退出游戏。{ko} 포탈이 닫힐 때 그 위에 있어 게임에서 탈락합니다.{es} seguía en el Portal cuando se cerró y queda fuera de la partida.{fr} se trouvait encore sur le Portail lorsqu'il s'est fermé et est éliminé de la partie.{pt-br} ainda estava no Portal quando ele se fechou e está fora do jogo.{de} befand sich noch auf dem Portal, als es sich schloss, und scheidet aus dem Spiel aus.")
	applyColorBarButtons()
	addAvatarButtons()
	if activeMageKnightCount()==0 then
		gStates.oneToReturnWinner=nil
		gStates.oneToReturnWinnerLocked=true
		gStates.blurb="{en}The Portal closed with every Mage Knight still upon it.<size=6>\n\n</size>No Hero remains to return. There is no winner.{it}Il Portale si è chiuso con tutti i Mage Knight ancora sopra.<size=6>\n\n</size>Nessun Eroe può tornare. Non c'è vincitore.{ru}Портал закрылся, когда все Рыцари-Маги оставались на нем.<size=6>\n\n</size>Никто не сможет вернуться. Победителя нет.{zh-tw}傳送門關閉時所有魔法騎士都還在其上。<size=6>\n\n</size>沒有英雄能夠返回。無人獲勝。{zh-cn}传送门关闭时所有魔法骑士都还在其上。<size=6>\n\n</size>没有英雄能够返回。无人获胜。{ko}포탈이 닫힐 때 모든 마법기사가 그 위에 남아 있었습니다.<size=6>\n\n</size>돌아갈 영웅이 없습니다. 승자는 없습니다.{es}El Portal se cerró con todos los Caballeros Mago todavía sobre él.<size=6>\n\n</size>No queda ningún Héroe que pueda regresar. No hay ganador.{fr}Le Portail s'est fermé alors que tous les Chevaliers-Mages s'y trouvaient encore.<size=6>\n\n</size>Aucun Héros ne peut rentrer. Il n'y a pas de vainqueur.{pt-br}O Portal se fechou com todos os Cavaleiros Magos ainda sobre ele.<size=6>\n\n</size>Nenhum Herói resta para retornar. Não há vencedor.{de}Das Portal schloss sich, während noch alle Mage Knights darauf standen.<size=6>\n\n</size>Kein Held kann zurückkehren. Es gibt keinen Gewinner."
		UI.setAttribute("DummyNotes", "Text", gStates.blurb)
		gStates.endGameAchieved="true"
		gStates.gameOver=true
		mainUIUpdate("One to Return portal closure eliminated all players")
	end
	return true
end

oneToReturnPortalOccupant=function()
	if gStates.gameScenario~="One to Return" then return nil,nil end
	local portalTile=oneToReturnPortalTile()
	if portalTile==nil then return nil,nil end
	local portalPos=portalTile.getPosition()
	for playerIndex, details in pairs(turnOrder) do
		if details.mage~=gStates.positionMageKnight[5] and playerDropoutInactive(playerIndex)==false then
			local avatarObj=nil
			for _, avatar in pairs(mageKnights) do
				if avatar.mage==details.mage then
					avatarObj=getObjectFromGUID(avatar.model) or getObjectFromGUID(avatar.standee) or getObjectFromGUID(avatar.token)
					break
				end
			end
			if avatarObj~=nil then
				local pos=avatarObj.getPosition()
				if ((pos[1]-portalPos[1])^2)+((pos[3]-portalPos[3])^2)<1 then return playerIndex,details end
			end
		end
	end
	return nil,nil
end

function oneToReturnLockFinalWinner()
	if gStates.gameScenario~="One to Return" then return false end
	oneToReturnSetPortalClosedDecal(false)
	local _,winner=oneToReturnPortalOccupant()
	if winner==nil then
		gStates.oneToReturnWinner=nil
		gStates.oneToReturnWinnerLocked=false
		return false
	end
	if oneToReturnEnsureChosenMages~=nil then oneToReturnEnsureChosenMages() end
	local teamVariant=gStates.oneToReturnChosenMages~=nil
	local team=mageKnightSeatTeam(winner.seatPos)
	gStates.oneToReturnWinner=(not teamVariant or gStates.oneToReturnChosenMages[team]==winner.mage) and winner.mage or nil
	gStates.oneToReturnWinnerLocked=true
	if gStates.oneToReturnWinner==nil then
		broadcastToAll("{en}A Hero occupies the Portal, but they are not the chosen member of their team. No team wins.{it}Un eroe occupa il Portale, ma non è il prescelto della sua squadra. Nessuna squadra vince.{ru}Герой занял Портал, но он не избранный участник команды. Победителей нет.{zh-tw}傳送門有人佔據，但不是該隊選定的英雄。無隊伍獲勝。{zh-cn}传送门有人占据，但不是该队选定的英雄。无队伍获胜。{ko}포털에 영웅이 있지만 팀의 선택된 영웅이 아닙니다. 승자는 없습니다.{es}Un héroe ocupa el Portal, pero no es el elegido de su equipo. Ningún equipo gana.{fr}Un héros occupe le Portail, mais ce n'est pas l'élu de son équipe. Aucune équipe ne gagne.{pt-br}Um herói ocupa o Portal, mas não é o escolhido de sua equipe. Nenhuma equipe vence.{de}Ein Held besetzt das Portal, aber nicht der Auserwählte seines Teams. Kein Team gewinnt.",{1,1,0.5})
	else
		broadcastToAll(joinLang({translateWord[winner.mage], "{en} occupies the Portal as End of Night is announced and is the One to Return. Player vs. Player combat may not be initiated after End of Night is called.{it} occupa il Portale all'annuncio della fine della Notte ed è l'Unico a Tornare. Dopo l'annuncio non si possono iniziare combattimenti tra giocatori.{ru} занимает Портал в момент объявления конца Ночи и становится Единственным, кто вернется. После объявления конца Ночи нельзя начинать бой между игроками.{zh-tw} 在宣告黑夜輪結束時佔據傳送門，成為唯一能返回的英雄。宣告黑夜輪結束後不能再發起玩家對玩家戰鬥。{zh-cn} 在宣布黑夜轮结束时占据传送门，成为唯一能返回的英雄。宣布黑夜轮结束后不能再发起玩家对玩家战斗。{ko} 밤 종료가 선언될 때 포탈을 차지하고 있어 돌아갈 단 한 명의 영웅이 됩니다. 밤 종료 선언 후에는 PvP 전투를 시작할 수 없습니다.{es} ocupa el Portal cuando se anuncia el Fin de la Noche y es el Único que Regresa. No se puede iniciar combate entre jugadores después de anunciar el Fin de la Noche.{fr} occupe le Portail lorsque la Fin de la Nuit est annoncée et devient l'Unique à Revenir. Aucun combat entre joueurs ne peut être initié après l'annonce de la Fin de la Nuit.{pt-br} ocupa o Portal quando o Fim da Noite é anunciado e é o Único a Retornar. Combate entre jogadores não pode ser iniciado depois que o Fim da Noite é anunciado.{de} besetzt das Portal, als das Ende der Nacht ausgerufen wird, und ist der Eine, der zurückkehrt. Nach dem Ausrufen des Nachtendes darf kein PvP-Kampf mehr begonnen werden."}), {1,1,0.5})
	end
	return gStates.oneToReturnWinner~=nil
end

function oneToReturnResolveWinner()
	if gStates.gameScenario~="One to Return" then return false end
	oneToReturnSetPortalClosedDecal(false)
	local winnerMage=gStates.oneToReturnWinnerLocked==true and gStates.oneToReturnWinner or nil
	if winnerMage==nil and gStates.oneToReturnWinnerLocked~=true then
		local _,winner=oneToReturnPortalOccupant()
		if winner~=nil then
			local chosen=gStates.oneToReturnChosenMages
			local team=mageKnightSeatTeam(winner.seatPos)
			if chosen==nil or chosen[team]==winner.mage then winnerMage=winner.mage end
		end
	end
	gStates.oneToReturnWinner=winnerMage
	if winnerMage~=nil then
		gStates.blurb=joinLang({translateWord[winnerMage], "{en} is the One to Return.<size=6>\n\n</size>They occupy the Portal as the second Night ends and win the game.{it} è l'Unico a Tornare.<size=6>\n\n</size>Occupa il Portale alla fine della seconda Notte e vince la partita.{ru} — Единственный, кто вернется.<size=6>\n\n</size>Он занимает Портал в конце второй Ночи и выигрывает игру.{zh-tw} 是唯一能返回的英雄。<size=6>\n\n</size>第二個黑夜輪結束時佔據傳送門並贏得遊戲。{zh-cn} 是唯一能返回的英雄。<size=6>\n\n</size>第二个黑夜轮结束时占据传送门并赢得游戏。{ko} 돌아갈 단 한 명의 영웅입니다.<size=6>\n\n</size>두 번째 밤이 끝날 때 포탈을 차지해 승리합니다.{es} es el Único que Regresa.<size=6>\n\n</size>Ocupa el Portal cuando termina la segunda Noche y gana la partida.{fr} est l'Unique à Revenir.<size=6>\n\n</size>Ce Héros occupe le Portail à la fin de la deuxième Nuit et remporte la partie.{pt-br} é o Único a Retornar.<size=6>\n\n</size>Ocupa o Portal quando a segunda Noite termina e vence o jogo.{de} ist der Eine, der zurückkehrt.<size=6>\n\n</size>Dieser Held besetzt das Portal am Ende der zweiten Nacht und gewinnt das Spiel."})
	else
		gStates.blurb="{en}The second Night has ended and no Hero occupies the Portal.<size=6>\n\n</size>There is no winner.{it}La seconda Notte è finita e nessun Eroe occupa il Portale.<size=6>\n\n</size>Non c'è vincitore.{ru}Вторая Ночь закончилась, но Портал никто не занимает.<size=6>\n\n</size>Победителя нет.{zh-tw}第二個黑夜輪已結束，但沒有英雄佔據傳送門。<size=6>\n\n</size>無人獲勝。{zh-cn}第二个黑夜轮已结束，但没有英雄占据传送门。<size=6>\n\n</size>无人获胜。{ko}두 번째 밤이 끝났지만 포탈을 차지한 영웅이 없습니다.<size=6>\n\n</size>승자는 없습니다.{es}La segunda Noche ha terminado y ningún Héroe ocupa el Portal.<size=6>\n\n</size>No hay ganador.{fr}La deuxième Nuit est terminée et aucun Héros n'occupe le Portail.<size=6>\n\n</size>Il n'y a pas de vainqueur.{pt-br}A segunda Noite terminou e nenhum Herói ocupa o Portal.<size=6>\n\n</size>Não há vencedor.{de}Die zweite Nacht ist beendet und kein Held besetzt das Portal.<size=6>\n\n</size>Es gibt keinen Gewinner."
	end
	UI.setAttribute("DummyNotes", "Text", gStates.blurb)
	broadcastToAll(gStates.blurb, {1,1,0.5})
	return winnerMage~=nil
end

currentMageAvatarPosition=function(playerIndex)
	local player=turnOrder[playerIndex]
	if player==nil then return nil end
	for _, avatar in pairs(mageKnights) do
		if avatar.mage==player.mage then
			if getObjectFromGUID(avatar.model)~=nil then return getObjectFromGUID(avatar.model).getPosition() end
			if getObjectFromGUID(avatar.token)~=nil then return getObjectFromGUID(avatar.token).getPosition() end
			if getObjectFromGUID(avatar.standee)~=nil then return getObjectFromGUID(avatar.standee).getPosition() end
		end
	end
	return nil
end

function scenarioRestLocationIsAvailable()
	local player=turnOrder[gStates.turnNumber]
	if player==nil then return true end
	local location=player.avatarLocation
	if gStates.gameScenario=="The Realm of the Dead Blitz" then
		if location=="graveyard" then return realmDeadEnemiesAtPosition(currentMageAvatarPosition(gStates.turnNumber))~=true end
		if location=="necropolis" then return (gStates.defeatedFaction or 0)>0 end
		return true
	end
	if gStates.gameScenario=="The Hidden Valley Blitz" then
		if location=="hidden valley" then return hiddenValleyLiberated() end
		return true
	end
	local gladeOpen=true
	if (gStates.gameScenario=="Life and Death" or gStates.gameScenario=="The War of Four") and (location=="glade" or location=="graveyard") then
		gladeOpen=false
		local avatarLocation=currentMageAvatarPosition(gStates.turnNumber)
		if avatarLocation==nil then return false end
		local objectsInPlay=getObjectFromGUID(mapArea).getObjects()
		table.sort(objectsInPlay, function (k1, k2) return k1.getPosition()[2]>k2.getPosition()[2] end)
		for _, obj in pairs(objectsInPlay) do
			if isShieldObject(obj) and volkarePursuitShieldRegistered(obj)~=true then
				if math.sqrt(((obj.getPosition()[1]-avatarLocation[1])^2)+((obj.getPosition()[3]-avatarLocation[3])^2))<1 then
					gladeOpen=true
					break
				end
			end
		end
	end
	return gladeOpen
end

function conqueredCityObjectiveCount()
	local count=gStates~=nil and gStates.defeatedCities~=nil and (tonumber(gStates.defeatedCities.amount) or 0) or 0
	if gStates~=nil and gStates.apocalypseDragonCityPlaced==true and gStates.apocalypseDragonDefeated==true then count=count+1 end
	return count
end

function cityConquestScenarioEndAchieved()
	if gStates==nil then return false end
	local count=conqueredCityObjectiveCount()
	if gStates.gameScenario=="Conquest" or gStates.gameScenario=="Conquest Blitz" then return count==gStates.cityTiles end
	if gStates.gameScenario=="The Council versus the Apocalypse" then return count>=2 end
	return fanScenarioConquestEndAchieved(count)
end

function coopLeaderScenarioEndAchieved()
	if gStates.endGameAchieved~="false" then return false end
	refreshCityDefeatState()
	if gStates.gameScenario=="Life and Death" then return gStates.defeatedFaction==2 end
	if gStates.gameScenario=="The Hidden Valley Blitz" then return gStates.defeatedFaction==1 end
	if gStates.gameScenario=="Ultimate Conquest" then return fanScenarioConquestEndAchieved(conqueredCityObjectiveCount()) end
	if gStates.gameScenario=="The Realm of the Dead Blitz" then
		local graveYardCount=0
		local graveYardTileCount=0
		local objectsInPlay=getObjectFromGUID(mapArea).getObjects()
		for _, obj in pairs(objectsInPlay) do
			if scriptObjectId(obj)=="GraveYard" then graveYardTileCount=graveYardTileCount+1 end
			if isShieldObject(obj) and volkarePursuitShieldRegistered(obj)~=true then
				local shieldPos=obj.getPosition()
				for _, graveYard in pairs(objectsInPlay) do
					if scriptObjectId(graveYard)=="GraveYard" then
						local gravePos=graveYard.getPosition()
						if math.sqrt(((shieldPos[1]-gravePos[1])^2)+((shieldPos[3]-gravePos[3])^2))<1 then graveYardCount=graveYardCount+1 break end
					end
				end
			end
		end
		return gStates.defeatedFaction==1 and graveYardCount==graveYardTileCount
	end
	return false
end

local combatCleanupMineTiles={
	[GUID.tile.core02]=true,[GUID.tile.core04]=true,[GUID.tile.core03]=true,[GUID.tile.country03]=true,
	[GUID.tile.country06]=true,[GUID.tile.country02]=true,[GUID.tile.country05]=true,[GUID.tile.city08]=true,
	[GUID.tile.country13]=true,[GUID.tile.country14]=true,[GUID.tile.country15]=true,[GUID.tile.country17]=true,[GUID.tile.core10]=true
}
local combatCleanupDungeonTombTiles={
	[GUID.tile.core01]=true,[GUID.tile.core03]=true,[GUID.tile.country07]=true,[GUID.tile.country09]=true
}

--Combat calls this only after returned enemies and shields have settled. Scenario owns victory
--conditions and Volkare's Return defense resolution; Combat only owns when this boundary is reached.
function scenarioCombatCleanupCheck(cleanupPlayer)
	if gStates.endGameAchieved~="false" or gStates.tacticShown~=false then return end
	local cleanupLocation=turnOrder[cleanupPlayer]~=nil and turnOrder[cleanupPlayer].avatarLocation or ""
	local dungeonCount,dungeonHexCount=0,0
	local mineCount,mineTileCount=0,0
	local graveYardCount,graveYardTileCount=0,0
	local relicCount=0

	if gStates.gameScenario=="Mines Liberation" or gStates.gameScenario=="The Realm of the Dead Blitz" or
		gStates.gameScenario=="Dungeon Lords" or gStates.gameScenario=="The Lost Relic Blitz" or
		gStates.gameScenario=="Against the Apocalypse Blitz" then
		local map=getObjectFromGUID(mapArea)
		local objectsInPlay=map~=nil and map.getObjects() or {}
		table.sort(objectsInPlay,function(k1,k2) return k1.getPosition()[2]>k2.getPosition()[2] end)
		for _, playAreaObject in pairs(objectsInPlay) do
			if isShieldObject(playAreaObject) and volkarePursuitShieldRegistered(playAreaObject)~=true then
				local found=false
				local shieldPos=playAreaObject.getPosition()
				local locatedTerrain,_,_,locatedFeature=terrainHexAtPosition(shieldPos,objectsInPlay)
				for _, terTile in pairs(objectsInPlay) do
					local tilePos=terTile.getPosition()
					local shieldToTileDist=math.sqrt(((shieldPos[1]-tilePos[1])^2)+((shieldPos[3]-tilePos[3])^2))
					if terTile==locatedTerrain then
						found=true
						if locatedFeature=="dungeon" or locatedFeature=="tomb" then dungeonCount=dungeonCount+1 end
						if locatedFeature=="mine" then mineCount=mineCount+1 end
						if locatedFeature~=nil and (locatedFeature:sub(1,4)=="city" or locatedFeature=="Volkare's Camp") and gStates.gameScenario=="The Lost Relic Blitz" then relicCount=relicCount+1 end
					end
					if shieldToTileDist<1 and scriptObjectId(terTile)=="GraveYard" then graveYardCount=graveYardCount+1 found=true end
					if found==true then break end
				end
			end
			if terrainTiles[playAreaObject.guid]~=nil and combatCleanupMineTiles[playAreaObject.guid]==true then mineTileCount=mineTileCount+1 end
			if scriptObjectId(playAreaObject)=="GraveYard" then graveYardTileCount=graveYardTileCount+1 end
			if terrainTiles[playAreaObject.guid]~=nil and combatCleanupDungeonTombTiles[playAreaObject.guid]==true then dungeonHexCount=dungeonHexCount+1 end
			if scriptObjectId(playAreaObject)=="Secret Tomb" or scriptObjectId(playAreaObject)=="Secret Dungeon" then dungeonHexCount=dungeonHexCount+1 end
		end
	end

	local allRituals=true
	if gStates.gameScenario=="Druid Nights" then
		for _, playerDetails in pairs(turnOrder) do
			if playerDetails.mage~=gStates.positionMageKnight[5] and playerDetails.druidNightsFinalRitual~=true then allRituals=false break end
		end
	end

	local cardInHand=false
	if gStates.gameScenario=="Quest for the Golden Grail" and turnOrder[cleanupPlayer]~=nil then
		local handZone=getObjectFromGUID(handZones[turnOrder[cleanupPlayer].seatPos])
		for _, handobject in pairs(handZone~=nil and handZone.getObjects() or {}) do
			if handobject.guid=="085e59" then cardInHand=true break end
		end
	end

	local volkareBeaten=true
	local volkareObj=gStates.volkareModel~=nil and getObjectFromGUID(gStates.volkareModel) or nil
	if volkareObj~=nil then
		for _, state in pairs(gStates.cityMonsterQty[volkare.model]) do if state=="alive" then volkareBeaten=false break end end
		if volkareBeaten==true then
			local trash=getObjectFromGUID(trashCan)
			if trash~=nil then trash.putObject(volkareObj) end
		end
	end

	local terrainStack=getObjectFromGUID(GUID.bag.terrain.stack)
	local terrainEmpty=terrainStack~=nil and terrainStack.getQuantity()==0
	local complete=
		((gStates.gameScenario=="Conquest" or gStates.gameScenario=="Conquest Blitz") and conqueredCityObjectiveCount()==gStates.cityTiles) or
		((gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz" or gStates.gameScenario=="Volkare's Quest") and volkareBeaten==true) or
		(gStates.gameScenario=="First Reconnaissance" and #gStates.citiesPlayed>=1) or
		(gStates.gameScenario=="The Council versus the Apocalypse" and conqueredCityObjectiveCount()>=2) or
		(gStates.gameScenario=="The Hidden Valley Blitz" and gStates.defeatedFaction==1) or
		(gStates.gameScenario=="Mines Liberation" and terrainEmpty and mineCount==mineTileCount) or
		(gStates.gameScenario=="Dungeon Lords" and terrainEmpty and dungeonCount==dungeonHexCount-2) or
		(gStates.gameScenario=="The Realm of the Dead Blitz" and gStates.defeatedFaction==1 and graveYardCount==graveYardTileCount) or
		(gStates.gameScenario=="The Lost Relic Blitz" and relicCount==gStates.cityTiles) or
		(gStates.gameScenario=="Druid Nights" and gStates.currentRound==gStates.rounds and allRituals==true) or
		(gStates.gameScenario=="Life and Death" and gStates.defeatedFaction==2) or
		fanScenarioCombatEndAchieved(cleanupLocation,cardInHand,volkareBeaten) or
		(gStates.gameScenario=="Against the Horsemen Blitz" and againstHorsemenAllDefeated()==true) or
		(gStates.gameScenario=="Against the Dragon Blitz" and apocalypseDragonColoredHeadsDefeated()==true) or
		(gStates.gameScenario=="Against the Apocalypse Blitz" and againstApocalypseObjectivesComplete~=nil and againstApocalypseObjectivesComplete()==true)
	if complete==true then
		if gStates.coopAssaultPhase=="combat" then gStates.coopAssaultScenarioEndPending=true else markScenarioEndAchieved() end
	end

	--Judge Volkare's Return city defense only when the entire defense is complete; co-op kills are combined across all defenders.
	local volkareReturnDefense=gStates.positionMageKnight[5]=="Volkare" and gStates.volkareState=="Attacking City" and
		(gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz")
	local volkareReturnDefenseFinished=volkareReturnDefense and (gStates.coopAssaultPhase~="combat" or coopAssaultPendingCombat()==false)
	if volkareReturnDefenseFinished then
		if gStates.volkareArmyDefeated<gStates.playerCount then
			gStates.volkareCityDefenseMove=nil
			local trash=getObjectFromGUID(trashCan)
			local liveVolkare=gStates.volkareModel~=nil and getObjectFromGUID(gStates.volkareModel) or nil
			if trash~=nil and liveVolkare~=nil then trash.putObject(liveVolkare) end
			gStates.volkareWon=true
			mainUIUpdate("Volkare Won")
		else volkareReturnCityDefenseMove() end
	end
end

--Mine crystal claim: resolve before cleanup/rewards so Deep Mine choice follows the End of Turn sequence.
mineCrystalBagKey={Red="red", Blue="blue", Green="green", White="white"}

function mineCrystalCount(playerIndex, color)
	local details=turnOrder[playerIndex]
	if details==nil then return 0 end
	local zone=getObjectFromGUID(playerCrystalAreas[details.seatPos])
	if zone==nil then return 0 end
	local count=0
	for _, obj in pairs(zone.getObjects()) do
		if manaTokenColor(obj)==color then count=count+1 end
	end
	return count
end

mineLiberatedForClaim=function(playerIndex, terrainGUID, hexPos)
	if gStates.gameScenario~="Mines Liberation" then return true end
	local map=getObjectFromGUID(mapArea)
	if map~=nil then
		for _, obj in pairs(map.getObjects()) do
			if isShieldObject(obj) and volkarePursuitShieldRegistered(obj)~=true then
				local p=obj.getPosition()
				if ((p[1]-hexPos[1])^2)+((p[3]-hexPos[3])^2)<1 then return true end
			end
		end
	end
	--A mine conquered this turn does not receive its Shield until cleanup. Treat its face-up
	--mine enemies in this player's play area as defeated-pending so the crystal can be chosen first.
	local monsters=gStates.mineMonsterQty~=nil and gStates.mineMonsterQty[terrainGUID] or nil
	if monsters==nil then return false end
	local playArea=getObjectFromGUID(playerPlayAreas[turnOrder[playerIndex].seatPos])
	local pendingDefeat={}
	if playArea~=nil then
		for _, obj in pairs(playArea.getObjects()) do if obj.is_face_down==false then pendingDefeat[obj.guid]=true end end
	end
	local found=false
	for monsterGUID, state in pairs(monsters) do
		found=true
		if state~="dead" and pendingDefeat[monsterGUID]~=true then return false end
	end
	return found
end

mineClaimData=function(playerIndex)
	local avatar=coopAssaultAvatarObject(playerIndex)
	if avatar==nil then return nil end
	local terrain, bearing, hexPos, feature=terrainHexAtPosition(avatar.getPosition())
	if terrain==nil or bearing==nil or feature~="mine" then return nil end
	local details=terrainTiles[terrain.guid]
	local colors=details~=nil and details.mineColors~=nil and details.mineColors[bearing] or nil
	if colors==nil or #colors==0 or mineLiberatedForClaim(playerIndex, terrain.guid, hexPos)==false then return nil end
	return {terrainGUID=terrain.guid, bearing=bearing, colors=colors}
end

function mineInventoryPosition(playerIndex, color)
	local seatPos=turnOrder[playerIndex].seatPos
	local board=getObjectFromGUID(playerBoard[seatPos])
	local zone=getObjectFromGUID(playerCrystalAreas[seatPos])
	if board==nil or zone==nil then return {(seatPos*40)-114, 2.0, -36.8} end
	local zonePos, zoneScale=zone.getPosition(), zone.getScale()
	local objects=zone.getObjects()
	local matching={}
	for _, obj in pairs(objects) do
		if manaTokenColor(obj)==color then matching[#matching+1]=obj.getPosition() end
	end
	local choices={}
	for _, snap in pairs(board.getSnapPoints() or {}) do
		local p=board.positionToWorld(snap.position)
		if math.abs(p[1]-zonePos[1])<=zoneScale[1]/2 and math.abs(p[3]-zonePos[3])<=zoneScale[3]/2 then
			local occupied=false
			for _, obj in pairs(objects) do
				local op=obj.getPosition()
				if ((op[1]-p[1])^2)+((op[3]-p[3])^2)<0.56 then occupied=true break end
			end
			if occupied==false then
				local nearest=999999
				for _, mp in pairs(matching) do nearest=math.min(nearest, ((mp[1]-p[1])^2)+((mp[3]-p[3])^2)) end
				choices[#choices+1]={position={p[1], 2.0, p[3]}, score=nearest}
			end
		end
	end
	if #choices>0 then
		table.sort(choices, function(a,b) if a.score==b.score then return a.position[1]<b.position[1] end return a.score<b.score end)
		return choices[1].position
	end
	--No board snap is free (usually because reward tokens were placed over them). Find the clearest
	--physical point in the inventory instead of stacking the new crystal on an existing object.
	local best={position={zonePos[1],2.0,zonePos[3]}, clearance=-1}
	for i=1, 24 do
		local p={zonePos[1]-((zoneScale[1]/2)-0.6)+(math.random()*math.max(0.1,zoneScale[1]-1.2)), 2.0,
			zonePos[3]-((zoneScale[3]/2)-0.6)+(math.random()*math.max(0.1,zoneScale[3]-1.2))}
		local clearance=999999
		for _, obj in pairs(objects) do local op=obj.getPosition() clearance=math.min(clearance, ((op[1]-p[1])^2)+((op[3]-p[3])^2)) end
		if clearance>best.clearance then best={position=p, clearance=clearance} end
	end
	return best.position
end

function refreshMineClaimPanel()
	local pending=gStates.mineClaimPending
	if pending==nil or turnOrder[pending.playerIndex]==nil then UI.hide("MineClaimChoice") return end
	UI.setAttribute("MineClaimChoiceTitle", "text", pending.source=="Quest" and "{en}Quest Crystal{it}Cristallo Missione{ru}Кристалл задания{zh-tw}任務水晶{zh-cn}任务水晶{ko}퀘스트 크리스털{es}Cristal de Misión{fr}Cristal de Quête{pt-br}Cristal de Missão{de}Quest-Kristall" or "{en}Mined Crystal{it}Cristallo Estratto{ru}Добытый кристалл{zh-tw}開採水晶{zh-cn}开采水晶{ko}채굴한 크리스털{es}Cristal Extraído{fr}Cristal Extrait{pt-br}Cristal Minerado{de}Abgebauter Kristall")
	for i=1, 4 do
		local color=pending.colors[i]
		UI.setAttribute("MineClaimButton"..i, "active", color~=nil and "true" or "false")
		if color~=nil then UI.setAttribute("MineClaimButtonText"..i, "text", translateWord[color] or color) end
	end
	UI.setAttribute("MineClaimRow2", "active", #pending.colors>2 and "true" or "false")
	setUIVisibility("MineClaimChoice",{positionToColor(pending.playerIndex),"Black"})
	UI.show("MineClaimChoice")
end

function beginMineCrystalClaim(playerIndex, messageColor)
	local data=mineClaimData(playerIndex)
	if data==nil then return false end
	local available={}
	for _, color in ipairs(data.colors) do if mineCrystalCount(playerIndex, color)<3 then available[#available+1]=color end end
	if #available==0 then
		if messageColor~=nil then broadcastToColor("{en}No crystal gained from the Mine: your Inventory already has 3 of every available color.{it}Nessun cristallo ottenuto dalla Miniera: hai già 3 cristalli di ogni colore disponibile nell'Inventario.{ru}Кристалл из Шахты не получен: в вашем Инвентаре уже по 3 кристалла каждого доступного цвета.{zh-tw}未從礦場獲得水晶：你的庫存中每種可用顏色都已有 3 顆水晶。{zh-cn}未从矿场获得水晶：你的库存中每种可用颜色都已有 3 颗水晶。{ko}광산에서 크리스털을 얻지 못했습니다. 인벤토리에 사용 가능한 모든 색의 크리스털이 이미 3개씩 있습니다.{es}No se obtuvo cristal de la Mina: tu Inventario ya tiene 3 de cada color disponible.{fr}Aucun cristal gagné de la Mine : votre Inventaire contient déjà 3 cristaux de chaque couleur disponible.{pt-br}Nenhum cristal foi ganho da Mina: seu Inventário já tem 3 de cada cor disponível.{de}Kein Kristall aus der Mine erhalten: Dein Inventar enthält bereits 3 Kristalle jeder verfügbaren Farbe.", messageColor, warningColor)
		else broadcastToAll("{en}No crystal gained from the Mine: your Inventory already has 3 of every available color.{it}Nessun cristallo ottenuto dalla Miniera: hai già 3 cristalli di ogni colore disponibile nell'Inventario.{ru}Кристалл из Шахты не получен: в вашем Инвентаре уже по 3 кристалла каждого доступного цвета.{zh-tw}未從礦場獲得水晶：你的庫存中每種可用顏色都已有 3 顆水晶。{zh-cn}未从矿场获得水晶：你的库存中每种可用颜色都已有 3 颗水晶。{ko}광산에서 크리스털을 얻지 못했습니다. 인벤토리에 사용 가능한 모든 색의 크리스털이 이미 3개씩 있습니다.{es}No se obtuvo cristal de la Mina: tu Inventario ya tiene 3 de cada color disponible.{fr}Aucun cristal gagné de la Mine : votre Inventaire contient déjà 3 cristaux de chaque couleur disponible.{pt-br}Nenhum cristal foi ganho da Mina: seu Inventário já tem 3 de cada cor disponível.{de}Kein Kristall aus der Mine erhalten: Dein Inventar enthält bereits 3 Kristalle jeder verfügbaren Farbe.", warningColor) end
		return false
	end
	gStates.mineClaimPending={source="Mine", playerIndex=playerIndex, terrainGUID=data.terrainGUID, bearing=data.bearing, colors=available}
	refreshMineClaimPanel()
	if mainUIUpdate~=nil then mainUIUpdate("Mine crystal pending") end
	return true
end

function mineClaimChoice(player, mouseButton, id)
	if mouseButton~="-1" or player==nil then return end
	local pending=gStates.mineClaimPending
	if pending==nil or turnOrder[pending.playerIndex]==nil then UI.hide("MineClaimChoice") return end
	local claimantColor=positionToColor(pending.playerIndex)
	local sourceName=pending.source=="Quest" and "Quest" or "Mine"
	if player.color~=claimantColor and player.color~="Black" then
		broadcastToColor(joinLang({"{en}Only the claiming player can choose this {it}Solo il giocatore che lo riceve può scegliere questo {ru}Только получающий игрок может выбрать этот кристалл из {zh-tw}只有領取的玩家可以選擇這顆來自 {zh-cn}只有领取的玩家可以选择这颗来自 {ko}이 크리스털은 획득하는 플레이어만 선택할 수 있습니다: {es}Solo el jugador que reclama puede elegir este cristal de {fr}Seul le joueur qui réclame peut choisir ce cristal de {pt-br}Apenas o jogador que está recebendo pode escolher este cristal de {de}Nur der beanspruchende Spieler kann diesen Kristall aus ",sourceName,"."}), player.color, {1,0.3,0.3})
		return
	end
	local index=tonumber(id:match("(%d+)$"))
	local color=index~=nil and pending.colors[index] or nil
	if color==nil then return end
	if mineCrystalCount(pending.playerIndex, color)>=3 then
		broadcastToColor(joinLang({"{en}You already have 3 {it}Hai già 3 cristalli {ru}В вашем Инвентаре уже есть 3 {zh-tw}你的庫存中已有 3 顆 {zh-cn}你的库存中已有 3 颗 {ko}인벤토리에 이미 {es}Ya tienes 3 cristales {fr}Vous avez déjà 3 cristaux {pt-br}Você já tem 3 cristais {de}Du hast bereits 3 ",translateWord[color] or color,"{en} crystals in your Inventory.{it} nell'Inventario.{ru} кристалла.{zh-tw} 水晶。{zh-cn} 水晶。{ko} 크리스털이 3개 있습니다.{es} en tu Inventario.{fr} dans votre Inventaire.{pt-br} no seu Inventário.{de}-Kristalle in deinem Inventar."}), player.color, warningColor)
		return
	end
	local bagKey=mineCrystalBagKey[color]
	local bag=bagKey~=nil and getObjectFromGUID(GUID.bag.mana[bagKey]) or nil
	if bag==nil or bag.getQuantity()==0 then
		broadcastToColor(joinLang({"{en}No {it}Nessun {ru}В запасе нет {zh-tw}供應區沒有可用的 {zh-cn}供应区没有可用的 {ko}공급처에 사용할 수 있는 {es}No hay ningún cristal {fr}Aucun cristal {pt-br}Não há cristal {de}Im Vorrat ist kein ",translateWord[color] or color,"{en} crystal is available in the supply.{it} disponibile nella riserva.{ru} кристалла.{zh-tw} 水晶。{zh-cn} 水晶。{ko} 크리스털이 없습니다.{es} disponible en la reserva.{fr} disponible dans la réserve.{pt-br} disponível na reserva.{de}-Kristall verfügbar."}), player.color, {1,0.3,0.3})
		return
	end
	local questCardGUID=pending.questCardGUID
	takeManaCrystal(bag,{position=mineInventoryPosition(pending.playerIndex, color),smooth=false})
	broadcastToColor(joinLang({"{en}Claimed a {it}Ottenuto un cristallo {ru}Получен {zh-tw}已領取 {zh-cn}已领取 {ko}획득: {es}Se reclamó un Cristal {fr}Cristal {pt-br}Recebeu um Cristal {de}Beansprucht: ",translateWord[color] or color,"{en} Crystal from the {it} da {ru} кристалл из {zh-tw} 水晶，來源：{zh-cn} 水晶，来源：{ko} 크리스털, 출처: {es} de {fr} réclamé depuis {pt-br} de {de}-Kristall aus ",sourceName,"."}), player.color, {1,1,0.5})
	gStates.mineClaimPending=nil
	UI.hide("MineClaimChoice")
	if questCardGUID~=nil and getObjectFromGUID(questCardGUID)~=nil then apocalypseQuestUpdateProgressButtons(getObjectFromGUID(questCardGUID)) end
	if mainUIUpdate~=nil then mainUIUpdate("Mine crystal claimed") end
end

function markScenarioEndAchieved(endImmediately)
	if gStates.endGameAchieved~="false" then return false end
	UI.setAttribute("EndGameButtonText", "text", "{en}Scenario End Achieved - Yes{it}Fine Scenario Raggiunta - Sì{ru}Конец сценария достигнут - Да{zh-tw}達成劇本結束 - 是{zh-cn}達成剧本结束 - 是{ko}시나리오 종료 조건 충족 됨{es}Escenario Fin Realizados - Sí{fr}Scénario Fin Atteint - Oui{pt-br}Fim do Cenário Alcançado - Sim{de}Szenarioziel Erreicht – Ja")
	UI.setAttribute("EndGameButtonImage", "image", "Sliced Button/Button New Deactive")
	UI.setAttribute("EndGameButtonImage", "color", "rgb(1.0,0.7,0.2)")
	gStates.endGameAchieved="started"
	turnOrder[gStates.realTurn].gameEnder=true
	establishFinalTurnBoundary("victory", gStates.realTurn)
	if gStates.gameScenario=="The Gauntlet" or gStates.gameScenario=="Quest for the Golden Grail" then
		broadcastToAll("{en}Congratulations{it}Congratulazioni{ru}Поздравляем{zh-tw}恭喜{zh-cn}恭喜{ko}축하합니다{es}Felicidades{fr}Toutes nos félicitations{pt-br}Parabéns{de}Glückwunsch", {1,1,0.5})
		gStates.endGameAchieved="true"
		gStates.gameOver=true
		mainUIUpdate("Scenario End")
	elseif endImmediately==true then
		gStates.endGameAchieved="true"
		gStates.gameOver=true
		mainUIUpdate("Game Over")
	else
		broadcastToAll("{en}Final Round of Turns Started{it}Iniziato l'Ultimo Giro di Turni{ru}Начался последний круг ходов{zh-tw}最终轮的回合开始了{zh-cn}最终轮的回合开始了{ko}마지막 턴 시작{es}Inicio de la Ultima Ronda de Turnos{fr}Dernier Rounde de Tours Commencé{pt-br}Rodada Final de Turnos começou{de}Die letzte Runde hat begonnen", {1,1,0.5})
	end
	refreshCoopCompSkillWarnings()
	return true
end

clearScenarioEndAchieved=function()
	if gStates.endGameAchieved=="false" then return false end
	UI.setAttribute("EndGameButtonText", "text", "{en}Scenario End Achieved - No{it}Fine Scenario Raggiunta - No{ru}Конец сценария достигнут - Нет{zh-tw}達成劇本結束 - 否{zh-cn}達成剧本结束 - 否{ko}시나리오 종료 조건 충족 전{es}Escenario Fin Realizados - No{fr}Scénario Fin Atteint - Non{pt-br}Fim do Cenário Alcançado - Não{de}Szenarioziel Erreicht – Nein")
	UI.setAttribute("EndGameButtonImage", "image", "Sliced Button/Button New Active")
	UI.setAttribute("EndGameButtonImage", "color", "white")
	UI.setAttribute("PreEndTurnImage", "image", "Sliced Button/Button New Active")
	UI.setAttribute("PreEndTurn", "interactable", "True")
	gStates.gameOver=false
	for _, turnDetails in pairs(turnOrder) do turnDetails.gameEnder=false end
	if gStates.finalTurnReason=="victory" then clearFinalTurnBoundary() else ensureFinalTurnBoundary() end
	gStates.endGameAchieved=(gStates.finalTurnReason=="endRound" and gStates.currentRound==gStates.rounds) and "true" or "false"
	broadcastToAll("{en}Turn order resumed{it}Ordine dei turni ripreso{ru}Порядок хода восстановлен{zh-tw}回合顺序恢复了{zh-cn}回合顺序恢复了{ko}턴 순서가 재개되었습니다{es}Se reanudó el orden de turno{fr}L'ordre des tours a repris{pt-br}Ordem de Turno retomada{de}Reihenfolge der Drehung wieder aufgenommen", {1,1,0.5})
	mainUIUpdate("Scenario End")
	refreshCoopCompSkillWarnings()
	return true
end

function toggleScenarioEndAchieved(player, mouseButton, id)
	if gStates.endGameAchieved=="false" then return markScenarioEndAchieved(false) end
	return clearScenarioEndAchieved()
end

--Dungeon Lords secret entrances remember the exact Village/Monastery that created each placement request.
--That lets the drop validator enforce the scenario's adjacency rule instead of accepting any empty map hex.
function dungeonLordsPendingSecretName(entry)
	if type(entry)=="table" then return entry.siteType or entry.name end
	return entry
end

dungeonLordsSecretSourceFeature=function(secretName)
	if secretName=="Secret Dungeon" then return "village" end
	if secretName=="Secret Tomb" then return "monastery" end
	return nil
end

dungeonLordsSecretSourcePosition=function(entry)
	if type(entry)~="table" then return nil end
	local terrain=entry.sourceTerrainGUID~=nil and getObjectFromGUID(entry.sourceTerrainGUID) or nil
	if terrain~=nil and entry.sourceBearing~=nil then
		local xy=angleToXY(terrain,tostring(entry.sourceBearing))
		return {xy[1],terrain.getPosition()[2],xy[2]}
	end
	return entry.sourcePosition
end

dungeonLordsSecretSpaceBasicLegal=function(terrain,bearing)
	if terrain==nil or bearing==nil or terrainTiles[terrain.guid]==nil then return false end
	local details=terrainTiles[terrain.guid]
	local key=tostring(bearing)
	local feature=details.hexFeature~=nil and details.hexFeature[key] or nil
	local terrainType=details.hexType~=nil and details.hexType[key] or nil
	local noSite=feature=="" or feature=="rampaging" or feature=="draconum"
	return noSite==true and terrainType~=nil and terrainType~="swamp" and terrainType~="lake" and terrainType~="mountain" and terrainType~="ocean"
end

dungeonLordsFindAdjacentSecretSource=function(secretName,destinationPosition)
	local sourceFeature=dungeonLordsSecretSourceFeature(secretName)
	local map=getObjectFromGUID(mapArea)
	if sourceFeature==nil or destinationPosition==nil or map==nil then return nil end
	for _,terrain in pairs(map.getObjects()) do
		local details=terrainTiles[terrain.guid]
		if details~=nil and terrain.is_face_down==false then
			for sourceBearing,feature in pairs(details.hexFeature or {}) do
				if feature==sourceFeature then
					local xy=angleToXY(terrain,sourceBearing)
					local sourcePos={xy[1],terrain.getPosition()[2],xy[2]}
					if runtimeMapWorldHexDistance(sourcePos,destinationPosition)==1 then
						return {siteType=secretName,sourceTerrainGUID=terrain.guid,sourceBearing=tostring(sourceBearing),sourcePosition=sourcePos}
					end
				end
			end
		end
	end
	return nil
end

dungeonLordsSecretDestinationLegal=function(terrain,bearing,request)
	if dungeonLordsSecretSpaceBasicLegal(terrain,bearing)~=true then return false,nil end
	local xy=angleToXY(terrain,tostring(bearing))
	local destinationPosition={xy[1],terrain.getPosition()[2],xy[2]}
	local normalized=request
	if type(normalized)~="table" then normalized=dungeonLordsFindAdjacentSecretSource(dungeonLordsPendingSecretName(request),destinationPosition) end
	local sourcePosition=dungeonLordsSecretSourcePosition(normalized)
	if sourcePosition==nil or runtimeMapWorldHexDistance(sourcePosition,destinationPosition)~=1 then return false,normalized end
	return true,normalized
end

dungeonLordsSecretLegalDestinationCount=function(request)
	local map=getObjectFromGUID(mapArea)
	if map==nil then return 0 end
	local count=0
	for _,terrain in pairs(map.getObjects()) do
		local details=terrainTiles[terrain.guid]
		if details~=nil and terrain.is_face_down==false then
			for destinationBearing,_ in pairs(details.hexType or {}) do
				if dungeonLordsSecretDestinationLegal(terrain,destinationBearing,request)==true then count=count+1 end
			end
		end
	end
	return count
end

dungeonLordsSecretRequestMatches=function(a,b)
	if dungeonLordsPendingSecretName(a)~=dungeonLordsPendingSecretName(b) then return false end
	if type(a)~="table" or type(b)~="table" then return false end
	return a.sourceTerrainGUID==b.sourceTerrainGUID and tostring(a.sourceBearing)==tostring(b.sourceBearing)
end

dungeonLordsQueueSecretRequest=function(request,quiet)
	if request==nil then return false end
	gStates.locationPlace=gStates.locationPlace or {}
	for _,existing in ipairs(gStates.locationPlace) do if dungeonLordsSecretRequestMatches(existing,request)==true then return false end end
	if dungeonLordsSecretLegalDestinationCount(request)==0 then
		if quiet~=true then
			local source=dungeonLordsSecretSourceFeature(dungeonLordsPendingSecretName(request)) or "site"
			broadcastToAll(joinLang({"{en}Dungeon Lords: no legal space exists next to the revealed {it}Signori dei Sotterranei: nessuno spazio valido accanto al sito rivelato {ru}Владыки Подземелий: рядом с открытым объектом нет подходящей клетки: {zh-tw}地下城領主：新揭示的 {zh-cn}地下城领主：新揭示的 {ko}던전 로드: 공개된 {es}Señores de las Mazmorras: no existe ningún espacio legal junto a {fr}Seigneurs des Donjons : aucune case légale n’existe à côté de {pt-br}Senhores das Masmorras: não existe espaço válido ao lado de {de}Kerkerfürsten: Neben dem aufgedeckten ",source,"{en}; no secret entrance is placed.{it}; nessun ingresso segreto posizionato.{ru}; тайный вход не размещается.{zh-tw} 旁沒有合法空間；不放置秘密入口。{zh-cn} 旁没有合法空间；不放置秘密入口。{ko} 옆에 합법적인 칸이 없어 비밀 입구를 배치하지 않습니다.{es}; no se coloca ninguna entrada secreta.{fr} ; aucune entrée secrète n’est placée.{pt-br}; nenhuma entrada secreta é colocada.{de} gibt es kein gültiges Feld; es wird kein Geheimeingang platziert."}),{1,0.75,0.2})
		end
		return false
	end
	gStates.locationPlace[#gStates.locationPlace+1]=request
	return true
end

dungeonLordsPruneImpossibleSecretRequests=function()
	gStates.locationPlace=gStates.locationPlace or {}
	local removed=false
	for i=#gStates.locationPlace,1,-1 do
		local request=gStates.locationPlace[i]
		if dungeonLordsSecretLegalDestinationCount(request)==0 then
			local source=dungeonLordsSecretSourceFeature(dungeonLordsPendingSecretName(request)) or "site"
			broadcastToAll(joinLang({"{en}Dungeon Lords: no legal space remains next to the revealed {it}Signori dei Sotterranei: nessuno spazio valido rimasto accanto al sito rivelato {ru}Владыки Подземелий: рядом с открытым объектом больше нет подходящей клетки: {zh-tw}地下城領主：新揭示的 {zh-cn}地下城领主：新揭示的 {ko}던전 로드: 공개된 {es}Señores de las Mazmorras: ya no queda ningún espacio legal junto a {fr}Seigneurs des Donjons : aucune case légale ne reste à côté de {pt-br}Senhores das Masmorras: não resta espaço válido ao lado de {de}Kerkerfürsten: Neben dem aufgedeckten ",source,"{en}; that secret entrance is skipped.{it}; questo ingresso segreto viene saltato.{ru}; этот тайный вход пропускается.{zh-tw} 旁已無合法空間；跳過該秘密入口。{zh-cn} 旁已无合法空间；跳过该秘密入口。{ko} 옆에 합법적인 칸이 남아 있지 않아 그 비밀 입구를 건너뜁니다.{es}; se omite esa entrada secreta.{fr} ; cette entrée secrète est ignorée.{pt-br}; essa entrada secreta é ignorada.{de} ist kein gültiges Feld mehr frei; dieser Geheimeingang wird übersprungen."}),{1,0.75,0.2})
			table.remove(gStates.locationPlace,i)
			removed=true
		end
	end
	return removed
end

function dungeonLordsQueueSecretSite(terrain,bearing,sourceFeature)
	if gStates.gameScenario~="Dungeon Lords" or terrain==nil then return false end
	local secretName=sourceFeature=="village" and "Secret Dungeon" or sourceFeature=="monastery" and "Secret Tomb" or nil
	if secretName==nil then return false end
	local xy=angleToXY(terrain,tostring(bearing))
	local request={siteType=secretName,sourceTerrainGUID=terrain.guid,sourceBearing=tostring(bearing),sourcePosition={xy[1],terrain.getPosition()[2],xy[2]}}
	local queued=dungeonLordsQueueSecretRequest(request,false)
	if queued==true then mainUIUpdate("Need Token") end
	return queued
end

function dungeonLordsHandleSecretSiteToken(obj,status,terrain,bearing,hexFeature)
	if gStates.gameScenario~="Dungeon Lords" or obj==nil or terrain==nil or bearing==nil then return false end
	local secretName=scriptObjectId(obj)
	if secretName~="Secret Dungeon" and secretName~="Secret Tomb" then return false end
	local site=secretName=="Secret Dungeon" and "dungeon" or "tomb"
	gStates.locationPlace=gStates.locationPlace or {}
	gStates.dungeonLordsSecretSiteOrigins=gStates.dungeonLordsSecretSiteOrigins or {}
	if status=="enter" then
		local pending=gStates.locationPlace[#gStates.locationPlace]
		local pendingName=dungeonLordsPendingSecretName(pending)
		if pendingName~=secretName then
			if pendingName~=nil then broadcastToAll(joinLang({"{en}Dungeon Lords: place the requested {it}Signori dei Sotterranei: posiziona prima il sito richiesto: {ru}Владыки Подземелий: сначала разместите требуемый {zh-tw}地下城領主：請先放置要求的 {zh-cn}地下城领主：请先放置要求的 {ko}던전 로드: 먼저 요청된 {es}Señores de las Mazmorras: coloca primero la entrada solicitada {fr}Seigneurs des Donjons : placez d’abord l’entrée demandée {pt-br}Senhores das Masmorras: coloque primeiro a entrada solicitada {de}Kerkerfürsten: Platziere zuerst den angeforderten ",tostring(pendingName),"{en} first.{it}.{ru}.{zh-tw}。{zh-cn}。{ko}을(를) 배치하십시오.{es}.{fr}.{pt-br}.{de}."}),{1,0.55,0.2})
			else broadcastToAll("{en}Dungeon Lords: that secret entrance has not been requested by a newly revealed Village or Monastery.{it}Signori dei Sotterranei: questo ingresso segreto non è stato richiesto da un Villaggio o Monastero appena rivelato.{ru}Владыки Подземелий: этот тайный вход не был запрошен недавно открытой Деревней или Монастырём.{zh-tw}地下城領主：新揭示的村莊或修道院並未要求放置此秘密入口。{zh-cn}地下城领主：新揭示的村庄或修道院并未要求放置此秘密入口。{ko}던전 로드: 새로 공개된 마을이나 수도원이 이 비밀 입구를 요청하지 않았습니다.{es}Señores de las Mazmorras: esta entrada secreta no fue solicitada por una Aldea o Monasterio recién revelados.{fr}Seigneurs des Donjons : cette entrée secrète n’a pas été demandée par un Village ou un Monastère récemment révélé.{pt-br}Senhores das Masmorras: esta entrada secreta não foi solicitada por uma Vila ou Mosteiro recém-revelado.{de}Kerkerfürsten: Dieser Geheimeingang wurde nicht von einem neu aufgedeckten Dorf oder Kloster angefordert.",{1,0.55,0.2}) end
			return true
		end
		local legal,normalized=dungeonLordsSecretDestinationLegal(terrain,bearing,pending)
		if legal~=true then
			broadcastToAll("{en}Dungeon Lords: the secret entrance must be on an accessible, non-Swamp empty space adjacent to the Village or Monastery that created it.{it}Signori dei Sotterranei: l'ingresso segreto deve essere su uno spazio vuoto accessibile, non Palude, adiacente al Villaggio o Monastero che l'ha creato.{ru}Владыки Подземелий: тайный вход должен находиться на доступной пустой клетке, не являющейся Болотом, рядом с создавшей его Деревней или Монастырём.{zh-tw}地下城領主：秘密入口必須放在建立它的村莊或修道院旁，一個可進入、非沼澤且空置的空間。{zh-cn}地下城领主：秘密入口必须放在建立它的村庄或修道院旁，一个可进入、非沼泽且空置的空间。{ko}던전 로드: 비밀 입구는 이를 생성한 마을 또는 수도원에 인접한, 접근 가능하고 늪이 아닌 빈 칸에 있어야 합니다.{es}Señores de las Mazmorras: la entrada secreta debe estar en un espacio vacío accesible, que no sea Pantano, adyacente a la Aldea o Monasterio que la creó.{fr}Seigneurs des Donjons : l’entrée secrète doit se trouver sur une case vide accessible, non-Marais, adjacente au Village ou au Monastère qui l’a créée.{pt-br}Senhores das Masmorras: a entrada secreta deve ficar em um espaço vazio acessível, que não seja Pântano, adjacente à Vila ou ao Mosteiro que a criou.{de}Kerkerfürsten: Der Geheimeingang muss auf einem zugänglichen, leeren Nicht-Sumpf-Feld neben dem Dorf oder Kloster liegen, das ihn erzeugt hat.",{1,0.55,0.2})
			return true
		end
		runtimeMapSetHexFeature(terrain.guid,bearing,site)
		if gStates.hexOverideSave[terrain.guid]==nil then gStates.hexOverideSave[terrain.guid]={} end
		gStates.hexOverideSave[terrain.guid][tostring(bearing)]=site
		normalized.destinationTerrainGUID=terrain.guid
		normalized.destinationBearing=tostring(bearing)
		gStates.dungeonLordsSecretSiteOrigins[obj.guid]=normalized
		obj.lock()
		broadcastToAll(joinLang({translateWord[secretName], "{en} located.{it} individuato.{ru} размещена(о).{zh-tw} 坐落于{zh-cn} 坐落于{ko} 설치됨{es} situado.{fr} situé.{pt-br} localizado.{de} liegt."}), {1,1,0.5})
		table.remove(gStates.locationPlace)
		dungeonLordsPruneImpossibleSecretRequests()
		mainUIUpdate("Need Token")
		local infoGUID=site=="tomb" and "1cab50" or "57dcab"
		local info=getObjectFromGUID(infoGUID)
		if info~=nil then info.setRotationSmooth({0.0,180.0,0.0}) end
		moveDisplayTerrainCache={signature=nil,hexMap=nil}
		updateMoveDisplay()
		return true
	end
	if status=="remove" and hexFeature==site then
		local origin=gStates.dungeonLordsSecretSiteOrigins[obj.guid]
		if origin==nil then
			local xy=angleToXY(terrain,tostring(bearing))
			origin=dungeonLordsFindAdjacentSecretSource(secretName,{xy[1],terrain.getPosition()[2],xy[2]}) or secretName
		end
		runtimeMapSetHexFeature(terrain.guid,bearing,"")
		if gStates.hexOverideSave[terrain.guid]==nil then gStates.hexOverideSave[terrain.guid]={} end
		gStates.hexOverideSave[terrain.guid][tostring(bearing)]=""
		gStates.dungeonLordsSecretSiteOrigins[obj.guid]=nil
		broadcastToAll(joinLang({translateWord[secretName], "{en} removed.{it} rimosso.{ru} удалена(о).{zh-tw} 移除的{zh-cn} 移除的{ko} 제거됨{es} remoto.{fr} supprimé.{pt-br} removido.{de} entfernt."}), {1,1,0.5})
		dungeonLordsQueueSecretRequest(origin,true)
		dungeonLordsPruneImpossibleSecretRequests()
		mainUIUpdate("Need Token")
		moveDisplayTerrainCache={signature=nil,hexMap=nil}
		updateMoveDisplay()
		return true
	end
	return true
end

--Druid Nights Incantation is legal anywhere the Mage Knight cannot Interact with Locals.
--Use the map's interaction helper first so burned Monasteries and conquered/unconquered sites resolve correctly;
--the logical-location fallback also covers Portal/City parking where the physical avatar may be off the map.

function druidNightsCanIncantHere(playerIndex)
	local player=turnOrder[playerIndex]
	if player==nil or gStates.gameScenario~="Druid Nights" then return false end
	local hexes,mapObjects=runtimeMapHexesAndObjects()
	local hex=apocalypseQuestPlayerHex(hexes,mapObjects,playerIndex)
	if hex~=nil then return apocalypseQuestHexInteractionSite(hex,mapObjects,playerIndex)~=true end
	local location=string.lower(tostring(player.avatarLocation or ""))
	if location=="village" or location=="monastery" or location=="keep" or location=="mage tower" or location=="camp" or location=="oasis" or location=="volkare's camp" or location:sub(1,4)=="city" then return false end
	return true
end

--Druid Nights Ritual is a separate combat action from a site attack. Keep it out of attackLocation
--so a legal site defender cannot intercept or add its assault side effects to the Incantation.
function druidNightsRitualAction(playerDud, mouseButton, id)
	if mouseButton~="-1" then return end
	local mage=tostring(id or ""):match("^Incant(.+)$")
	if mage==nil then return end
	local playerIndex=nil
	for index, details in pairs(turnOrder) do if details.mage==mage then playerIndex=index break end end
	if playerIndex==nil or playerIndex~=gStates.turnNumber then return end
	local player=turnOrder[playerIndex]
	if player==nil or gStates.gameScenario~="Druid Nights" or gStates.dayRound~=false or player.combatIconHide~="None" or player.gladesMarked==nil or #player.gladesMarked<1 or player.druidNightsLastRitualRound==gStates.currentRound or druidNightsCanIncantHere(playerIndex)~=true then return end
	local turnToken=getObjectFromGUID(player.turnOrderTokenGUID)
	if turnToken==nil or turnToken.is_face_down==true then return end
	if playerDud~=nil and playerDud.color~=nil and legalPlayerCheck(playerDud.color,player.seatPos)~=true then return end

	combatCameraChoiceSuppressedPlayer=nil
	gStates.monsterOffsetX=0
	gStates.monsterOffsetZ=0
	player.combatIconHide="Both"
	player.druidNightsLastRitualRound=gStates.currentRound
	player.druidNightsRitualCount=(player.druidNightsRitualCount or 0)+1
	broadcastToAll("{en}Performed Incantation to summon Monster(s) to your Player Board{it}Rituale eseguito per evocare Mostri sulla tua Plancia Giocatore{ru}Прочтено заклинание, чтобы призвать Монстра(ов) на вашу игровую доску.{zh-tw}执行了咒语召唤怪物到你的玩家板{zh-cn}执行了咒语召唤怪物到你的玩家板{ko}주문을 시전하여 몬스터를 소환합니다{es}Encantamiento realizado para convocar Monstruos a tu Tablero de Jugador{fr}Incantation exécutée pour invoquer des monstres sur votre plateau de joueur{pt-br}Realizou um Encantamento para invocar Monstro(S) para seu Tabuleiro de Jogador{de}Beschwörung durchgeführt, um Monster auf dein Spielerbrett zu beschwören", positionToColor(playerIndex))
	if gStates.currentRound==gStates.rounds then player.druidNightsFinalRitual=true end
	local ritualCount=#player.gladesMarked
	local crystalMultiple=gStates.currentRound>=5 and 3 or (gStates.currentRound>=3 and 2 or 1)
	gStates.druidNightsSummon=ritualCount
	gStates.druidNightsCrystalReward=ritualCount*crystalMultiple
	local monsterSummoned=gStates.currentRound>=3 and monsterPiles.red or monsterPiles.tan
	for _=1, ritualCount do safeWaitFrames("Scenario",function() drawMonster(monsterSummoned,player,id) end,10) end
	if gStates.currentRound>=5 then
		for _=1, ritualCount do safeWaitFrames("Scenario",function() drawMonster(monsterPiles.tan,player,id) end,10) end
	end
	--Activated Glade shields remain on the map until the end of the Night; round reset removes them.
	addAvatarButtons()
end

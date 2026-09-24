-- Combat, enemy staging, cooperative assault and combat reward runtime.

local coopAssaultNormalText="{en}Nearby Mage Knights can choose to join this assault by skipping their next turn. This tool randomly gives the amount of defenders chosen to each player. (Remember to pay movement costs){ru}Ближайшие Рыцари-маги могут присоединиться к этому штурму, пропустив свой следующий ход. Этот инструмент случайно распределяет выбранное количество защитников между игроками. (Не забудьте оплатить стоимость движения.){zh-tw}附近的魔法騎士可以選擇加入突襲。此工具會依據數量隨機分配守軍給每位參與者。（記得支付移動點數）{zh-cn}附近的魔法骑士可以选择加入突袭。此工具会依据数量随机分配守军给每位参与者。（记得支付移动点数）{ko}근처의 메이지 나이트들은 다음 차례를 건너뛰고 이 강습에 참여할 수 있습니다. 이 도구는 선택한 수의 수비자를 각 플레이어에게 무작위로 배정합니다. (이동 비용을 지불하는 것을 잊지 마세요){es}Los Caballeros Mago cercanos pueden unirse a este asalto saltándose su próximo turno. Esta herramienta reparte al azar entre los jugadores la cantidad de defensores elegida. (Recuerda pagar los costes de movimiento){fr}Les Chevaliers-Mages proches peuvent rejoindre cet assaut en sautant leur prochain tour. Cet outil répartit aléatoirement entre les joueurs le nombre de défenseurs choisi. (N’oubliez pas de payer les coûts de mouvement){pt-br}Mage Knights próximos podem participar deste ataque pulando o próximo turno. Esta ferramenta distribui aleatoriamente entre os jogadores a quantidade escolhida de defensores. (Lembre-se de pagar os custos de movimento){de}Mage Knights in der Nähe können sich diesem Angriff anschließen, indem sie ihren nächsten Zug aussetzen. Dieses Werkzeug verteilt die gewählte Anzahl Verteidiger zufällig auf die Spieler. (Denke daran, die Bewegungskosten zu bezahlen)"
local combatFactionRewards={
	Dark={pile=monsterPiles.rewardDark,key="dark"},Elem={pile=monsterPiles.rewardElem,key="elementalist"},
	Apoc={pile=monsterPiles.rewardApoc,key="apocalypse"},Coun={pile=monsterPiles.rewardCouncil,key="council"}
}
local combatRewardDiscardByNotes={
	["Dark Crusader Reward"]=GUID.bag.discard.darkReward,["Elementalist Reward"]=GUID.bag.discard.elementalistReward,
	["Apocalypse Cult Reward"]=GUID.bag.discard.apocReward,["Council of the Void Reward"]=GUID.bag.discard.councilReward
}
local combatCityZones={
	[cityModel.blue]=GUID.zone.blueCity,[cityModel.red]=GUID.zone.redCity,[cityModel.green]=GUID.zone.greenCity,
	[cityModel.white]=GUID.zone.whiteCity,[volkare.terrainHex]=volkare.discZone
}
local combatPursuitMageNames={Arythea=true,Braevalar=true,Goldyx=true,Krang=true,Norowas=true,Tovak=true,Wolfhawk=true,Coral=true,Ymirgh=true,Novak=true,Duscenia=true,Jormund=true,Volkare=true}
local combatPursuitArrowRotation={[0]=270,[30]=240,[60]=210,[90]=180,[120]=150,[150]=120,[180]=90,[210]=60,[240]=30,[270]=0,[300]=330,[330]=300,[360]=270}
local combatMonsterDiscardRoutes={
	["Dark Crusader Draconum"]={discard=GUID.bag.discard.darkDraconum,standardDiscard=GUID.bag.discard.draconum,faction="Dark"},
	["Dark Crusader Dungeon Monster"]={discard=GUID.bag.discard.darkDungeon,standardDiscard=GUID.bag.discard.dungeon,faction="Dark"},
	["Marauding Dark Crusader"]={discard=GUID.bag.discard.darkMarauders,standardDiscard=GUID.bag.discard.orcs,faction="Dark"},
	["Elementalist Draconum"]={discard=GUID.bag.discard.elementalistDraconum,standardDiscard=GUID.bag.discard.draconum,faction="Elem"},
	["Elementalist Dungeon Monster"]={discard=GUID.bag.discard.elementalistDungeon,standardDiscard=GUID.bag.discard.dungeon,faction="Elem"},
	["Marauding Elementalist"]={discard=GUID.bag.discard.elementalistOrcs,standardDiscard=GUID.bag.discard.orcs,faction="Elem"},
	["Draconum"]={discard=GUID.bag.discard.draconum},["Dungeon Monster"]={discard=GUID.bag.discard.dungeon},
	["Marauding Orcs"]={discard=GUID.bag.discard.orcs},["City Garrison"]={discard=GUID.bag.discard.cityGarrison},
	["Ruin"]={discard=GUID.bag.discard.ruin},["Mage Tower Garrison"]={discard=GUID.bag.discard.towerGarrison},
	["Keep Garrison"]={discard=GUID.bag.discard.keepGarrison},["Possessed"]={discard=GUID.bag.discard.possessed,possessed=true}
}

--Combat monsters may be placed either in the main Play Area or directly on a Unit.
--Return every Play Area object plus Unit Area monsters, de-duplicated by GUID in case the zones overlap.
function playerCombatObjects(seatPos)
	local objects={}
	local seen={}
	local function addZone(zoneGUID, monstersOnly)
		local zone=zoneGUID~=nil and getObjectFromGUID(zoneGUID) or nil
		if zone==nil then return end
		for _, obj in pairs(zone.getObjects()) do
			if seen[obj.guid]~=true and (monstersOnly~=true or monsterPugs[obj.guid]~=nil) then
				seen[obj.guid]=true
				objects[#objects+1]=obj
			end
		end
	end
	addZone(playerPlayAreas[seatPos], false)
	addZone(playerUnitAreas[seatPos], true)
	return objects
end
function objectInPlayerCombatArea(objectGUID)
	if objectGUID==nil then return false end
	for seatPos=1, 4 do
		for _, zoneGUID in ipairs({playerPlayAreas[seatPos], playerUnitAreas[seatPos]}) do
			local zone=zoneGUID~=nil and getObjectFromGUID(zoneGUID) or nil
			if zone~=nil then
				for _, obj in pairs(zone.getObjects()) do if obj.guid==objectGUID then return true end end
			end
		end
	end
	return false
end

--Co-op assault combat is resolved first; rewards are then claimed by each participant in fight order.
function coopAssaultPendingCombat()
	if gStates.coopAssaultPhase~="combat" or gStates.coopAssaultParticipants==nil then return false end
	for playerIndex, _ in pairs(gStates.coopAssaultParticipants) do
		if playerIndex~=gStates.turnNumber and turnOrder[playerIndex]~=nil and playerDropoutInactive(playerIndex)==false then
			local token=getObjectFromGUID(turnOrder[playerIndex].turnOrderTokenGUID)
			if token~=nil and token.is_face_down==true and gStates.skipTurn[playerIndex]==nil then return true end
		end
	end
	return false
end

--Faction-leader co-op participants get unlocked planning copies. These clones are visual only and are never registered as monsters.
function clearCoopLeaderPreviewClones()
	for playerIndex, cloneGUID in pairs(gStates.coopLeaderPreviewClones or {}) do
		local clone=getObjectFromGUID(cloneGUID)
		if clone~=nil then clone.destruct() end
	end
	gStates.coopLeaderPreviewClones={}
end

function clearCoopAssaultRuntime(keepAssignments)
	gStates.coopAssaultPhase=nil
	if keepAssignments~=true then
		gStates.assaultData={}
		gStates.coopAssaultUnassigned={}
	end
	gStates.coopAssaultParticipants={}
	gStates.coopAssaultCityGUID=nil
	gStates.coopAssaultLocation=nil
	gStates.coopAssaultType=nil
	gStates.coopAssaultInitiator=nil
	gStates.coopAssaultConquered=nil
	gStates.coopAssaultScenarioEndPending=false
	gStates.coopAssaultMode=nil
end

function createCoopLeaderPreviewClones()
	clearCoopLeaderPreviewClones()
	if gStates.coopAssaultPhase~="combat" or coopAssaultTargetType()~="leader" then return end
	local leaderGUID=elementalist.token
	if gStates.coopAssaultCityGUID==darkCrusader.terrainHex then leaderGUID=darkCrusader.token end
	local leaderObj=getObjectFromGUID(leaderGUID)
	if leaderObj==nil then return end
	for playerIndex, _ in pairs(gStates.coopAssaultParticipants or {}) do
		if playerIndex~=gStates.turnNumber and turnOrder[playerIndex]~=nil then
			local clone=leaderObj.clone({position={turnOrder[playerIndex].seatPos*40-100, 1.5, -39.41}, rotation={0, 180, 0}, smooth=false})
			if clone~=nil then
				clone.unlock()
				clone.interactable=true
				clone.UI.setXmlTable({{}})
				gStates.coopLeaderPreviewClones[playerIndex]=clone.guid
			end
		end
	end
end

--Replace the next player's movable planning copy with the real leader token and its combat controls.
function promoteCoopLeaderPreview(playerIndex, leaderObj)
	if leaderObj==nil or turnOrder[playerIndex]==nil then return end
	local destination={turnOrder[playerIndex].seatPos*40-100, 1.5, -39.41}
	local cloneGUID=gStates.coopLeaderPreviewClones~=nil and gStates.coopLeaderPreviewClones[playerIndex] or nil
	local clone=cloneGUID~=nil and getObjectFromGUID(cloneGUID) or nil
	if clone~=nil then
		--Respect where the player moved the preview as long as it is still inside that player's combat area.
		local playZone=getObjectFromGUID(playerPlayAreas[turnOrder[playerIndex].seatPos])
		if playZone~=nil then
			for _, obj in pairs(playZone.getObjects()) do
				if obj.guid==clone.guid then
					local clonePos=clone.getPosition()
					destination={clonePos[1], 1.5, clonePos[3]}
					break
				end
			end
		end
		clone.destruct()
	end
	if gStates.coopLeaderPreviewClones~=nil then gStates.coopLeaderPreviewClones[playerIndex]=nil end
	leaderObj.unlock()
	leaderObj.setPositionSmooth(destination,false,false)
	leaderObj.setRotation({0, 180, 0})
	setMonsterObjectButtons(leaderObj)
end

--Assisting Mage Knights are treated as being in the assaulted city without moving their avatar until the assault result is known.
function coopAssaultAvatarObject(playerIndex)
	return mageKnightAvatarObject(playerIndex,false)
end

function coopAssaultVirtualPlayer(playerIndex)
	return gStates.coopAssaultPhase=="combat" and gStates.coopAssaultParticipants~=nil and gStates.coopAssaultParticipants[playerIndex]~=nil
end

function moveCoopAssaultAvatarToCityCard(playerIndex)
	local cityGUID=gStates.coopAssaultCityGUID
	local cardGUID=cityGUID~=nil and gStates.cityCard[cityGUID] or nil
	local cardObj=cardGUID~=nil and getObjectFromGUID(cardGUID) or nil
	if cardObj==nil then return false end
	local cardPos=cardObj.getPosition()
	local destination={cardPos[1]+(turnOrder[playerIndex].seatPos*1.83)-4.58, cardPos[2]+1, cardPos[3]-0.66}
	local avatar=coopAssaultAvatarObject(playerIndex)
	if avatar~=nil then avatar.setPositionSmooth(destination,false,false) end
	turnOrder[playerIndex].avatarSwapCity=cityGUID
	return true
end

--Co-op assaults share combat/reward handling, but their post-combat movement is different.
--Cities (including Volkare's Camp when used as a city) move successful assistants into the city.
--Moving Volkare and Shades of Tezla faction leaders return assisting players to their original spaces;
--the player who initiated the assault is already on the assaulted space and remains there on victory.
--The Dragon data is forward-declared with the map-setup helpers above.
function coopAssaultTargetType()
	local target=gStates.coopAssaultCityGUID
	if target==apocalypseDragon.model and apocalypseDragonScenario~=nil and apocalypseDragonScenario()==true then return "dragon" end
	if gStates.gameScenario=="Against the Horsemen Blitz" and gStates.againstHorsemenRitualStarted==true and target==GUID.tile.country01 then return "horsemen" end
	if target==volkare.model then return "volkare" end
	if target==darkCrusader.terrainHex or target==elementalist.terrainHex then return "leader" end
	return "city"
end

function coopAssaultTargetDefeated()
	local target=gStates.coopAssaultCityGUID
	local assaultType=coopAssaultTargetType()

	if assaultType=="dragon" then return apocalypseDragonColoredHeadsDefeated() end
	if assaultType=="horsemen" then return againstHorsemenAllDefeated() end

	if assaultType=="volkare" then
		if gStates.cityMonsterQty[target]==nil then return false end
		for monsterGUID, state in pairs(gStates.cityMonsterQty[target]) do
			if monsterGUID~="extra" and state=="alive" then return false end
		end
		return true
	end

	if assaultType=="leader" then
		if cityTargetDefeated(target)==true then return true end
		--The leader's followers are discarded shortly after the leader reaches level 0, so use the
		--leader token/level as an immediate fallback while that delayed cleanup is still finishing.
		if target==darkCrusader.terrainHex then
			return (gStates.darkCrusaderLevel or 1)<=0 or (gStates.cityMonsterQty[target]~=nil and gStates.cityMonsterQty[target][darkCrusader.token]=="dead")
		end
		if target==elementalist.terrainHex then
			return (gStates.elementalistLevel or 1)<=0 or (gStates.cityMonsterQty[target]~=nil and gStates.cityMonsterQty[target][elementalist.token]=="dead")
		end
		return false
	end

	return cityTargetDefeated(target)
end

function restoreCoopAssaultAvatar(playerIndex, original)
	if turnOrder[playerIndex]==nil or original==nil then return end
	turnOrder[playerIndex].avatarLocation=original.avatarLocation
	turnOrder[playerIndex].avatarSharedHex=original.avatarSharedHex
	turnOrder[playerIndex].avatarSwapCity=original.avatarSwapCity
	local avatar=coopAssaultAvatarObject(playerIndex)
	if avatar~=nil and original.position~=nil then avatar.setPositionSmooth(original.position,false,false) end
end

function resolveCoopAssaultLocations()
	if gStates.coopAssaultParticipants==nil or gStates.coopAssaultCityGUID==nil then return end
	gStates.coopAssaultType=coopAssaultTargetType()
	gStates.coopAssaultConquered=coopAssaultTargetDefeated()
	local volkareCampCity=gStates.volkareCampAsCity==true and gStates.coopAssaultCityGUID==volkare.terrainHex
	if volkareCampCity and gStates.coopAssaultConquered==true then registerVolkareCampAsCityKeep() end

	for playerIndex, original in pairs(gStates.coopAssaultParticipants) do
		if turnOrder[playerIndex]~=nil then
			if gStates.coopAssaultType=="dragon" then
				--Only the initiator enters the Dragon space on victory. All assisting Mage Knights
				--remain where they started; a failed assault withdraws the initiator as well.
				if gStates.coopAssaultConquered==true and playerIndex==gStates.coopAssaultInitiator then
					local avatar=coopAssaultAvatarObject(playerIndex)
					if avatar~=nil then refreshAvatarLocationOnly(playerIndex,avatar) end
				else restoreCoopAssaultAvatar(playerIndex,original) end
			elseif gStates.coopAssaultType=="horsemen" and gStates.coopAssaultConquered==true then
				--The rules place only the initiating Mage Knight in the Glade after a successful combined attack.
				if playerIndex==gStates.coopAssaultInitiator then
					turnOrder[playerIndex].avatarLocation="glade"
					turnOrder[playerIndex].avatarSharedHex=nil
					turnOrder[playerIndex].avatarSwapCity=nil
				else restoreCoopAssaultAvatar(playerIndex, original) end
			elseif volkareCampCity and gStates.coopAssaultConquered==true then
				--Camp-as-City keeps Volkare's cooperative assault movement: initiator stays, assistants return.
				if playerIndex==gStates.coopAssaultInitiator then
					turnOrder[playerIndex].avatarLocation=gStates.coopAssaultLocation
					turnOrder[playerIndex].avatarSwapCity=nil
				else restoreCoopAssaultAvatar(playerIndex, original) end
			elseif gStates.coopAssaultType=="city" and gStates.coopAssaultConquered==true then
				turnOrder[playerIndex].avatarLocation=gStates.coopAssaultLocation
				moveCoopAssaultAvatarToCityCard(playerIndex)
			else
				--Moving Volkare/leader assistants always return. Unconquered city participants also return.
				restoreCoopAssaultAvatar(playerIndex, original)
			end
		end
	end

	--The Volkare initiator stays where the assault was made. Once Volkare is defeated, refresh the
	--stored location from the terrain under the avatar so reward reminders no longer see "Volkare's Camp".
	if gStates.coopAssaultType=="volkare" and gStates.coopAssaultConquered==true and gStates.coopAssaultInitiator~=nil then
		local initiator=gStates.coopAssaultInitiator
		local avatar=coopAssaultAvatarObject(initiator)
		if turnOrder[initiator]~=nil and avatar~=nil then
			local terrain, bearing=terrainHexAtPosition(avatar.getPosition())
			if terrain~=nil and bearing~=nil and terrainTiles[terrain.guid]~=nil then
				turnOrder[initiator].avatarLocation=terrainTiles[terrain.guid].hexFeature[bearing]
				turnOrder[initiator].avatarSwapCity=nil
			end
		end
	end
end

function combatApplyPlayerFameReputationBase(playerIndex)
	local player=turnOrder[playerIndex]
	local startingFameToLevel=math.floor(math.sqrt((player.fame-(gStates.scoreIfLooped*player.scoreLoop))+1))
	local newFame=player.fame+player.fameGain-(gStates.scoreIfLooped*player.scoreLoop)
	local scoreLooped=false
	if newFame>=gStates.scoreIfLooped then newFame=newFame-gStates.scoreIfLooped scoreLooped=true end
	local fameToLevel=math.floor(math.sqrt(newFame+1))
	local startPosition=(newFame-(fameToLevel*fameToLevel))+2
	if scoreLooped==false then startPosition=startPosition+((fameToLevel-startingFameToLevel)*gStates.blitz) end
	local levelRowFameQuantity=(((fameToLevel-1)*cellGainPerLevel)+normalCellAmount)
	if startPosition>levelRowFameQuantity then fameToLevel=fameToLevel+1 startPosition=2 levelRowFameQuantity=levelRowFameQuantity+2 end
	local levelRowLength=((fameToLevel-1)*gStates.rowLengthGainPerLevel)+gStates.normalRowLength
	local xOffset=(1/levelRowFameQuantity*levelRowLength)/2
	local yOffset=(heightOfFameBoard/gStates.rowsOnBoard)/2
	local horizontalValue=leftOfFameBoard+(startPosition/levelRowFameQuantity*levelRowLength)-xOffset
	local verticalValue=(topOfFameBoard-((fameToLevel/gStates.rowsOnBoard)*heightOfFameBoard))+yOffset-0.35
	getObjectFromGUID(player.fameGUID).setPosition({horizontalValue, 1.5, verticalValue+((player.seatPos-2.5)/5)})
	recordPlayerFameChange(playerIndex, player.fameGain)

	if player.repGain<(-7-player.reputation) then player.repGain=(-7-player.reputation) end
	if player.repGain>(7-player.reputation) then player.repGain=(7-player.reputation) end
	local repPos=reputationTable[player.reputation+player.repGain].reputationPos
	getObjectFromGUID(player.reputationGUID).setPosition({repPos[1], repPos[2], repPos[3]})
	player.reputation=player.reputation+player.repGain
end

function factionRewardPileGUID(faction)
	local reward=combatFactionRewards[faction]
	return reward~=nil and reward.pile or nil
end

--A missing reward pile means that faction is using the Just Fame variant. An existing empty pile
--stays in token mode and may refill from its matching discard pile.
function factionRewardUsesJustFame(faction)
	local pileGUID=factionRewardPileGUID(faction)
	return pileGUID==nil or getObjectFromGUID(pileGUID)==nil
end

function monsterFactionRewardFameFallback(monsterGUID)
	local printedReward, perkReward=0,0
	local data=monsterPugs~=nil and monsterPugs[monsterGUID] or nil
	if data~=nil and data.pugType~="yellow" and type(data.reward)=="number" and data.reward>0 and factionRewardUsesJustFame(data.faction)==true then
		printedReward=tonumber(data.reward) or 0
	end
	local perks=gStates.monsterPerks~=nil and gStates.monsterPerks[monsterGUID] or nil
	if perks~=nil and type(perks.reward)=="number" and perks.reward>0 and factionRewardUsesJustFame(perks.faction)==true then
		perkReward=tonumber(perks.reward) or 0
	end
	return printedReward, perkReward
end

function takeFactionRewardToken(playerIndex, pileGUID, position)
	local pile=pileGUID~=nil and getObjectFromGUID(pileGUID) or nil
	if pile==nil then return false, "justFame" end
	if pile.getQuantity()==0 then
		tokenRefill()
		pile=getObjectFromGUID(pileGUID)
	end
	if pile~=nil and pile.getQuantity()>0 then
		position=position or {(turnOrder[playerIndex].seatPos*40)-117.2+(math.random()*6.5), 2, -35+(math.random()*3.2)}
		pile.takeObject({position=position})
		return true
	end
	return false, "empty"
end

function awardFactionRewardToken(playerIndex, pileGUID, coopCombatReward, rewardKey)
	if pileGUID==nil or getObjectFromGUID(pileGUID)==nil then return false, "justFame" end
	if coopCombatReward~=nil then
		coopCombatReward.factionRewards[rewardKey]=(coopCombatReward.factionRewards[rewardKey] or 0)+1
		if coopCombatReward.factionRewardsGiven~=true then return true end
		playerIndex=coopCombatReward.player
	end
	return takeFactionRewardToken(playerIndex, pileGUID)
end

function giveQueuedFactionReward(playerIndex, pileGUID)
	local claimed, reason=takeFactionRewardToken(playerIndex, pileGUID)
	if claimed~=true and reason~="justFame" then broadcastToAll("{en}No faction reward tokens remain to claim.{ru}Жетонов наград фракции для получения больше не осталось.{zh-tw}沒有剩餘的派系獎勵標記可供領取。{zh-cn}没有剩余的派系奖励标记可供领取。{ko}획득할 수 있는 세력 보상 토큰이 더 이상 없습니다.{es}No quedan fichas de recompensa de facción por reclamar.{fr}Il ne reste plus de jetons de récompense de faction à réclamer.{pt-br}Não restam fichas de recompensa de facção para reivindicar.{de}Es sind keine Fraktionsbelohnungsmarker mehr zum Beanspruchen übrig.", positionToColor(playerIndex)) end
end

local function combatMonsterDiscardDestination(playAreaObj)
	if playAreaObj==nil then return nil,nil end
	local rotationValues=playAreaObj.getRotationValues()
	local selected=rotationValues~=nil and rotationValues[2] or nil
	local value=selected~=nil and selected.value or nil
	local route=value~=nil and combatMonsterDiscardRoutes[value] or nil
	if route==nil then return nil,nil end
	local discardGUID=route.discard
	if route.faction=="Dark" and gStates.gameScenario~="Life and Death" and gStates.gameScenario~="The Realm of the Dead Blitz" then discardGUID=route.standardDiscard end
	if route.faction=="Elem" and gStates.gameScenario~="Life and Death" and gStates.gameScenario~="The Hidden Valley Blitz" then discardGUID=route.standardDiscard end
	return discardGUID~=nil and getObjectFromGUID(discardGUID) or nil,route
end

local function combatDiscardMonster(playAreaObj, giveRewards, context)
	if playAreaObj==nil then return false end
	context=context or {}
	local cleanupPlayer=context.player or gStates.turnNumber
	if cleanupPlayer==nil or turnOrder[cleanupPlayer]==nil then return false end
	local monsterGUID=playAreaObj.guid
	local monsterData=monsterPugs[monsterGUID]
	if monsterData==nil then return false end

	if gStates.apocalypseQuestGoblinEnemies~=nil and gStates.apocalypseQuestGoblinEnemies[monsterGUID]~=nil then
		--Goblin Warrens enemies come from an Infinite Bag and are not members of a normal discard cycle.
		apocalypseQuestGoblinRecordCleanup(monsterGUID,playAreaObj.is_face_down==false)
		gStates.apocalypseQuestGoblinEnemies[monsterGUID]=nil
		if gStates.monsterPerks~=nil then gStates.monsterPerks[monsterGUID]=nil end
		if gStates.attackedMonsters~=nil then gStates.attackedMonsters[monsterGUID]=nil end
		if gStates.monsterPlayLocation~=nil then gStates.monsterPlayLocation[monsterGUID]=nil end
		if gStates.summonStates~=nil then gStates.summonStates[monsterGUID]=nil end
		monsterPugs[monsterGUID]=nil
		playAreaObj.destruct()
		return true
	end

	local discardBag,route=combatMonsterDiscardDestination(playAreaObj)
	if discardBag==nil or route==nil then return false end
	playAreaObj.setRotation({0,180,0})
	local summoned=gStates.summonStates~=nil and gStates.summonStates[monsterGUID]=="summoned"

	if route.faction=="Dark" or route.faction=="Elem" then
		if giveRewards==true and summoned~=true and playAreaObj.is_face_down==false then
			local reward=combatFactionRewards[route.faction]
			local claimed,reason=awardFactionRewardToken(cleanupPlayer,reward.pile,context.coopCombatReward,reward.key)
			if claimed~=true and reason=="empty" then
				local message=route.faction=="Dark" and "{en}Sorry, there are no more Dark Crusader Faction Reward Tokens to claim.{ru}Извините, жетонов наград фракции Тёмных крестоносцев больше не осталось.{zh-tw}抱歉，沒有更多黑暗十字軍派系獎勵標記可供領取。{zh-cn}抱歉，没有更多黑暗十字军派系奖励标记可供领取。{ko}죄송합니다. 획득할 수 있는 다크 크루세이더 세력 보상 토큰이 더 이상 없습니다.{es}Lo sentimos, no quedan fichas de recompensa de la facción Cruzados Oscuros por reclamar.{fr}Désolé, il ne reste plus de jetons de récompense de la faction Croisés Sombres à réclamer.{pt-br}Desculpe, não restam fichas de recompensa da facção Cruzados Sombrios para reivindicar.{de}Es sind keine Fraktionsbelohnungsmarker der Dunklen Kreuzritter mehr zum Beanspruchen übrig." or "{en}Sorry, there are no more Elementalist Faction Reward Tokens to claim.{ru}Извините, жетонов наград фракции Элементалистов больше не осталось.{zh-tw}抱歉，沒有更多元素使派系獎勵標記可供領取。{zh-cn}抱歉，没有更多元素使派系奖励标记可供领取。{ko}죄송합니다. 획득할 수 있는 엘리멘탈리스트 세력 보상 토큰이 더 이상 없습니다.{es}Lo sentimos, no quedan fichas de recompensa de la facción Elementalista por reclamar.{fr}Désolé, il ne reste plus de jetons de récompense de la faction Élémentaliste à réclamer.{pt-br}Desculpe, não restam fichas de recompensa da facção Elementalista para reivindicar.{de}Es sind keine Fraktionsbelohnungsmarker der Elementalisten mehr zum Beanspruchen übrig."
				broadcastToAll(message,positionToColor(cleanupPlayer))
			end
		end
	elseif route.possessed==true then
		local possessedFaction=(gStates.apocalypsePossessedFactionByToken~=nil and gStates.apocalypsePossessedFactionByToken[monsterGUID]) or "Apoc"
		local reward=combatFactionRewards[possessedFaction] or combatFactionRewards.Apoc
		if giveRewards==true and summoned~=true and playAreaObj.is_face_down==false then
			local claimed,reason=awardFactionRewardToken(cleanupPlayer,reward.pile,context.coopCombatReward,reward.key)
			if claimed~=true and reason=="empty" then broadcastToAll("{en}Sorry, there are no more Faction Reward Tokens to claim.{ru}Извините, жетонов наград фракции больше не осталось.{zh-tw}抱歉，沒有更多派系獎勵標記可供領取。{zh-cn}抱歉，没有更多派系奖励标记可供领取。{ko}죄송합니다. 획득할 수 있는 세력 보상 토큰이 더 이상 없습니다.{es}Lo sentimos, no quedan fichas de recompensa de facción por reclamar.{fr}Désolé, il ne reste plus de jetons de récompense de faction à réclamer.{pt-br}Desculpe, não restam fichas de recompensa da facção para reivindicar.{de}Es sind keine Fraktionsbelohnungsmarker mehr zum Beanspruchen übrig.",positionToColor(cleanupPlayer)) end
		end
		if gStates.apocalypsePossessedFactionByToken~=nil then gStates.apocalypsePossessedFactionByToken[monsterGUID]=nil end
	end

	for cityguid, monsters in pairs(gStates.cityMonsterQty) do
		if monsters[monsterGUID]~=nil then
			monsters[monsterGUID]="dead"
			if monsters.extra~=nil and (monsters.extra.megapolisPair==nil or monsters.extra.megapolisPair~=cityguid) then
				local cityZoneObj=combatCityZones[cityguid]~=nil and getObjectFromGUID(combatCityZones[cityguid]) or nil
				if cityZoneObj~=nil then
					local zonePos=cityZoneObj.getPosition()
					local location={zonePos[1]+(-2+monsters.extra.shieldsThere),1.13,zonePos[3]+1}
					if monsters.extra.shieldsThere>4 then location[1]=location[1]-5 location[3]=location[3]-0.5 end
					local volkareCityShield=context.volkareCityShield or 0
					if cityguid==volkare.terrainHex and (monsterData.pugType=="green" or monsterData.pugType=="gray") then volkareCityShield=volkareCityShield+0.5 end
					if cityguid~=volkare.terrainHex or (monsterData.pugType=="red" or monsterData.pugType=="white") or volkareCityShield==1 then
						if volkareCityShield==1 then volkareCityShield=0 end
						monsters.extra.shieldsThere=monsters.extra.shieldsThere+1
						dropShield(location,true)
					end
					context.volkareCityShield=volkareCityShield
				end
			end
			if cityguid==volkare.model then
				gStates.volkareArmyDefeated=gStates.volkareArmyDefeated+1
				gStates.volkareArmyReduced=true
				if gStates.gameScenario=="Volkare's Quest" and context.volkarePaused~=true and volkareQuestCheckSkipTurn()==true then context.volkarePaused=true end
			end
		end
	end

	if monsterData.pugType=="yellow" and monsterData.fame>0 then gStates.crytalRuin=true end
	local cleanupLocation=turnOrder[cleanupPlayer].avatarLocation or ""
	local avatarPos=context.avatarPos or {}
	if playAreaObj.is_face_down==false and gStates.druidNightsSummon==nil and
		(gStates.volkarePursuitEnemies==nil or gStates.volkarePursuitEnemies[monsterGUID]~=true) and (
		(monsterData.pugType=="gray" and cleanupLocation=="keep") or
		(monsterData.pugType=="yellow" and cleanupLocation=="ruin") or
		(monsterData.pugType=="red" and (cleanupLocation=="tomb" or cleanupLocation=="labyrinth" or ((cleanupLocation:sub(1,4)=="city" or cleanupLocation=="Volkare's Camp") and gStates.gameScenario=="The Lost Relic Blitz"))) or
		(monsterData.pugType=="tan" and (cleanupLocation=="maze" or cleanupLocation=="monster den" or cleanupLocation=="dungeon")) or
		(monsterData.pugType=="possessed" and (cleanupLocation=="ziggurat" or cleanupLocation=="pyramid")) or
		(monsterData.pugType=="purple" and (cleanupLocation=="mage tower" or cleanupLocation=="monastery"))) then
		local shieldExists=false
		local trackSiteShield=cleanupLocation~="ziggurat" and cleanupLocation~="pyramid" and cleanupLocation~="maze" and cleanupLocation~="labyrinth" and avatarPos[1]~=nil and avatarPos[3]~=nil
		if trackSiteShield==true then
			if context.siteShieldExists~=nil then
				shieldExists=context.siteShieldExists
			else
				local mapSpatial=context.mapSpatial or runtimeMapSpatialSnapshot()
				for _, shield in ipairs(runtimeMapSpatialNearbyObjects(mapSpatial,avatarPos,1)) do
					local shieldPos=mapSpatial.positions[shield.guid] or shield.getPosition()
					if shield.getName()=="Shield" and volkarePursuitShieldRegistered(shield)~=true and math.sqrt(((shieldPos[1]-avatarPos[1])^2)+((shieldPos[3]-avatarPos[3])^2))<1 then
						shieldExists=true
						if cleanupLocation=="keep" and shield.getDescription()~=turnOrder[cleanupPlayer].mage then shield.destruct() shieldExists=false end
						if cleanupLocation=="dungeon" or cleanupLocation=="tomb" then gStates.shieldsDropped[shield.guid]=true end
						break
					end
				end
				context.siteShieldExists=shieldExists
			end
		end
		if shieldExists==false then
			if gStates.monsterPlayLocation[monsterGUID]~=nil then
				dropShield(gStates.monsterPlayLocation[monsterGUID],true)
				if trackSiteShield==true then context.siteShieldExists=true end
				coralTalesSiteShield(cleanupLocation)
			elseif avatarPos[1]~=nil and avatarPos[3]~=nil then
				local shieldPos={avatarPos[1],2,avatarPos[3]}
				local shieldRotation=nil
				if cleanupLocation=="ziggurat" or cleanupLocation=="pyramid" then
					local floor=gStates.zigguratPyramidFightFloor
					local terrain,_,sitePos=terrainHexAtPosition(avatarPos)
					if terrain~=nil then shieldRotation={0,terrain.getRotation()[2],0} end
					if floor~=nil then shieldPos=zigguratPyramidFloorPosition(terrain,sitePos or avatarPos,floor) end
				end
				dropShield(shieldPos,true,shieldRotation)
				if trackSiteShield==true then context.siteShieldExists=true end
				coralTalesSiteShield(cleanupLocation)
			end
		end
	end

	if playAreaObj.is_face_down==false and monsterData.pugType=="tan" and cleanupLocation=="spawning grounds" then
		context.spawningGroundMonstersBeat=(context.spawningGroundMonstersBeat or 0)+1
	end
	if gStates.gameScenario=="Mines Liberation" or gStates.gameScenario=="Life and Death" or gStates.gameScenario=="The Hidden Valley Blitz" then
		for _, monsters in pairs(gStates.mineMonsterQty) do
			if monsters[monsterGUID]~=nil then
				for otherGUID, monsterState in pairs(monsters) do
					if otherGUID~=monsterGUID and monsterState=="dead" and avatarPos[1]~=nil and avatarPos[3]~=nil then dropShield({avatarPos[1],2,avatarPos[3]},true) break end
				end
				break
			end
		end
	end
	if gStates.monsterPerks~=nil then gStates.monsterPerks[monsterGUID]=nil end
	discardBag.putObject(playAreaObj)
	return true
end

function showCoopReward()
	local entry=gStates.coopRewardQueue[gStates.coopRewardIndex]
	if entry==nil then return end
	gStates.turnNumber=entry.player
	refreshTactic4HandBonus(false)
	gStates.preEndTurn=true
	rewardClaimSoftLockStart()
	gStates.levelingUp=false
	--The conquered city hand bonus is known now, before this player claims rewards and draws their new hand.
	if gStates.coopAssaultType=="city" and gStates.coopAssaultConquered==true and gStates.coopAssaultCityGUID~=nil then
		local cityRole=turnOrder[entry.player].defeatedCities[gStates.coopAssaultCityGUID]
		if gStates.volkareCampAsCity==true and gStates.coopAssaultCityGUID==volkare.terrainHex then
			turnOrder[entry.player].hand=turnOrder[entry.player].baseHand
			if cityRole~=nil then turnOrder[entry.player].hand=turnOrder[entry.player].baseHand+turnOrder[entry.player].keepsBeat end
		elseif cityRole=="Lead" then turnOrder[entry.player].hand=turnOrder[entry.player].baseHand+2
		elseif cityRole=="Assist" then turnOrder[entry.player].hand=turnOrder[entry.player].baseHand+1 end
	end
	turnOrder[entry.player].fameGain=entry.fame
	turnOrder[entry.player].repGain=entry.reputation
	applyPlayerFameReputation(entry.player)
	if entry.factionRewardsGiven~=true then
		for a=1, entry.factionRewards.dark do giveQueuedFactionReward(entry.player, monsterPiles.rewardDark) end
		for a=1, entry.factionRewards.elementalist do giveQueuedFactionReward(entry.player, monsterPiles.rewardElem) end
		for a=1, entry.factionRewards.apocalypse do giveQueuedFactionReward(entry.player, monsterPiles.rewardApoc) end
		for a=1, (entry.factionRewards.council or 0) do giveQueuedFactionReward(entry.player, monsterPiles.rewardCouncil) end
		entry.factionRewardsGiven=true
	end
	claimButtonRefresh()
	safeWaitFrames("Combat",function() mainUIUpdate("Co-op Rewards") end, 2)
end

function coopAssaultAvatarsSettled()
	if gStates.coopAssaultParticipants==nil then return true end
	for playerIndex, _ in pairs(gStates.coopAssaultParticipants) do
		local avatar=coopAssaultAvatarObject(playerIndex)
		if avatar~=nil and avatar.resting~=true then return false end
	end
	return true
end

--Faction-leader level changes are resolved only after every participant in a cooperative assault has finished combat.
function finalizeCoopLeaderCombat()
	if gStates.coopAssaultPhase~="combat" or coopAssaultTargetType()~="leader" then return end
	clearCoopLeaderPreviewClones()
	if (gStates.leaderReduction or 0)<=0 then return end
	local currentLeader=elementalist
	local currentLevel=gStates.elementalistLevel
	if gStates.coopAssaultCityGUID==darkCrusader.terrainHex then currentLeader=darkCrusader currentLevel=gStates.darkCrusaderLevel end
	if currentLevel==nil then gStates.leaderReduction=0 return end
	local finalLevel=math.max(0, currentLevel-gStates.leaderReduction)
	gStates.leaderReduction=0
	if currentLeader==darkCrusader then gStates.darkCrusaderLevel=finalLevel else gStates.elementalistLevel=finalLevel end
	local leaderObj=getObjectFromGUID(currentLeader.token)
	if finalLevel==0 then
		if leaderObj~=nil then getObjectFromGUID(trashCan).putObject(leaderObj) end
		if gStates.cityMonsterQty[currentLeader.terrainHex]~=nil then gStates.cityMonsterQty[currentLeader.terrainHex][currentLeader.token]="dead" end
		local disc=getObjectFromGUID(currentLeader.disc)
		if disc~=nil then disc.setCustomObject({image=leaderData[currentLeader.terrainHex]["dead"].discImg}) disc.reload() end
		--The whole cooperative assault is now over, so surviving followers may finally flee.
		if gStates.cityMonsterQty[currentLeader.terrainHex]~=nil then
			for monsterGUID, state in pairs(gStates.cityMonsterQty[currentLeader.terrainHex]) do
				if monsterGUID~="extra" and monsterGUID~=currentLeader.token and state~="dead" then
					local monster=getObjectFromGUID(monsterGUID)
					if monster~=nil and monster.getRotationValues()[2]~=nil then combatDiscardMonster(monster,false,{player=gStates.turnNumber,avatarPos=mageKnightAvatarPosition(gStates.turnNumber) or {}}) end
				end
			end
		end
	else
		if leaderObj~=nil then
			if gStates.monsterPlayLocation[leaderObj.guid]~=nil then leaderObj.setPositionSmooth(gStates.monsterPlayLocation[leaderObj.guid],false,false) end
			leaderObj.setCustomObject({image=leaderData[currentLeader.terrainHex][finalLevel].tokenImg})
			leaderObj.setName(joinLang({currentLeader==darkCrusader and "{en}Dark Crusader Leader Level {ru}Уровень лидера Тёмных крестоносцев: {zh-tw}黑暗十字軍領袖等級 {zh-cn}黑暗十字军领袖等级 {ko}다크 크루세이더 지도자 레벨 {es}Nivel del líder Cruzado Oscuro {fr}Niveau du chef Croisé Sombre {pt-br}Nível do líder Cruzado Sombrio {de}Stufe des Anführers der Dunklen Kreuzritter " or "{en}Elementalist Leader Level {ru}Уровень лидера Элементалистов: {zh-tw}元素使領袖等級 {zh-cn}元素使领袖等级 {ko}엘리멘탈리스트 지도자 레벨 {es}Nivel del líder Elementalista {fr}Niveau du chef Élémentaliste {pt-br}Nível do líder Elementalista {de}Stufe des Elementalisten-Anführers ", finalLevel}))
			leaderObj.reload()
			monsterPugs[currentLeader.token]=leaderData[currentLeader.terrainHex][finalLevel].abilities
		end
		local disc=getObjectFromGUID(currentLeader.disc)
		if disc~=nil then disc.setCustomObject({image=leaderData[currentLeader.terrainHex][finalLevel].discImg}) disc.reload() end
	end
end

--A cooperative faction-leader assault finalizes the leader after the normal end-of-combat scenario check has already run.
--Re-check only scenario conditions that can become true specifically because that deferred leader was just defeated.
function startCoopRewardPhase()
	if coopAssaultTargetType()=="dragon" then finalizeCoopDragonCombat() end
	finalizeCoopLeaderCombat()
	local assaultType=coopAssaultTargetType()
	if gStates.endGameAchieved=="false" and ((assaultType=="leader" and coopLeaderScenarioEndAchieved()==true) or (assaultType=="horsemen" and againstHorsemenAllDefeated()==true) or (assaultType=="dragon" and apocalypseDragonColoredHeadsDefeated()==true)) then gStates.coopAssaultScenarioEndPending=true end
	resolveCoopAssaultLocations()
	if gStates.coopRewardQueue==nil or #gStates.coopRewardQueue==0 then
		local scenarioEndPending=gStates.coopAssaultScenarioEndPending==true
		gStates.coopAssaultPhase=nil
		gStates.coopAssaultScenarioEndPending=false
		if scenarioEndPending then
			--Do not end immediately after a victorious co-op assault. The normal turn
			--engine must first consume assisting players' flipped turn tokens, then
			--return to the victory owner for their final turn.
			scenarioEnd(false)
			if gStates.gameOver==true then return end
			if gStates.endGameAchieved=="started" then gStates.endGameAchieved="true" end
		end
		nextTurnMerged("incrementTurn")
		return
	end
	gStates.coopRewardIndex=1
	local function beginRewards() gStates.coopAssaultPhase="rewards" showCoopReward() end
	safeWaitFrames("Combat",function() safeWaitCondition("Combat",beginRewards, coopAssaultAvatarsSettled, 3, beginRewards) end, 2)
end

function combatAdvanceCoopRewardPhaseBase()
	local entry=gStates.coopRewardQueue[gStates.coopRewardIndex]
	if entry~=nil then
		turnOrder[entry.player].fameGain=0
		turnOrder[entry.player].repGain=0
	end
	gStates.levelingUp=false
	gStates.coopRewardIndex=gStates.coopRewardIndex+1
	if gStates.coopRewardIndex<=#gStates.coopRewardQueue then
		showCoopReward()
	else
		local scenarioEndPending=gStates.coopAssaultScenarioEndPending==true
		gStates.coopRewardQueue={}
		gStates.coopRewardIndex=1
		clearCoopAssaultRuntime()
		gStates.preEndTurn=false
		rewardClaimSoftLockClear()
		if scenarioEndPending then
			--Victory is registered here, but gameOver waits for nextTurnMerged.
			--That lets an assister's skipped turn flip their token upright and lets
			--the initiating victory owner receive their required final turn.
			scenarioEnd(false)
			if gStates.gameOver==true then return end
			if gStates.endGameAchieved=="started" then gStates.endGameAchieved="true" end
		end
		nextTurnMerged("incrementTurn")
		recourceTrackerReset()
		claimButtonRefresh()
		addAvatarButtons()
	end
end

--Clears a players board area and Asks if rewards are claimed
--Keep Rewards Claimed locked briefly while cleanup objects/UI are still settling.
rewardClaimDelayActive=false
local rewardClaimDelayWait=nil
--local slightPause=true
local function combatPreEndTurnOpenRewardBoundary(cleanupPlayer)
	volkarePursuitResolveCombat(cleanupPlayer)
	puppetMasterCleanupPlayedPuppets(cleanupPlayer)
	--A Quest marker may still be settling under this Hero. Finish that temporary lift before the older
	--end-turn site-cleanup lift records avatarPos/locks the same object, or it can be left floating.
	apocalypseQuestRestoreRaisedAvatar(cleanupPlayer,true)
	local coopCombatReward=nil
	if gStates.coopAssaultPhase=="combat" then
		coopCombatReward={player=cleanupPlayer, mage=turnOrder[cleanupPlayer].mage, fame=turnOrder[cleanupPlayer].fameGain, reputation=turnOrder[cleanupPlayer].repGain, factionRewards={dark=0, elementalist=0, apocalypse=0, council=0}}
		gStates.coopRewardQueue[#gStates.coopRewardQueue+1]=coopCombatReward
		UI.setAttribute("EndTurnButton", "interactable", "false")
		UI.setAttribute("EndTurnButtonImage", "image", "Sliced Button/Button New Deactive")
		UI.setAttribute("EndTurnButtonAlt", "interactable", "false")
		UI.setAttribute("EndTurnButtonAltImage", "image", "Sliced Button/Button New Deactive")
	end
	--reset variables for next turn
	gStates.preEndTurn=true
	--Before combat cleanup moves/discards Quest enemies, remember successful combat-gated Quest
	--resolutions. This gives Rewards Claimed its soft warning gate while that Quest action is pending.
	apocalypseQuestCaptureRewardCompletionGate(cleanupPlayer)
	--Free Wine uses a normal Keep assault rather than a Quest-spawned combat, so capture its outcome
	--separately now that the rewards boundary has been reached.
	apocalypseQuestCaptureFreeWineResolutionGate(cleanupPlayer)
	--Mine of Doom enemies now use the normal end-of-turn combat cleanup with every other enemy.
	rewardClaimDelayActive=true
	if rewardClaimDelayWait~=nil then Wait.stop(rewardClaimDelayWait) rewardClaimDelayWait=nil end
	gStates.monsterOffsetX=0
	gStates.monsterOffsetZ=0
	gStates.attackedMonsters={}
	combatCameraChoiceSuppressedPlayer=nil
	turnOrder[cleanupPlayer].combatIconHide="Both"
	if turnOrder[cleanupPlayer].masterOfChaos~=nil then turnOrder[cleanupPlayer].masterOfChaos="available" end
	addAvatarButtons()
	if gStates.coopAssaultPhase~="combat" then claimButtonRefresh() end
	UI.setAttribute("PreEndTurn", "interactable", "false")
	UI.setAttribute("PreEndTurnImage", "image", "Sliced Button/Button New Deactive")
	rewardClaimDelayWait=safeWaitTime("Combat",function()
		rewardClaimDelayWait=nil
		local function finishRewardDelay()
			rewardClaimDelayActive=false
			if gStates.preEndTurn==true and turnOrder[cleanupPlayer]~=nil then
				rewardClaimSoftLockStart()
				if steadyTempoUpdateRewardGate~=nil then steadyTempoUpdateRewardGate(turnOrder[cleanupPlayer].seatPos)
				else
					UI.setAttribute("PreEndTurn", "interactable", "true")
					UI.setAttribute("PreEndTurnImage", "image", "Sliced Button/Button New Active")
				end
			end
			rewindTransactionFinish("Pre-end-turn cleanup")
		end
		local dragonCombat=gStates.apocalypseDragonGroundCombat
		if dragonCombat~=nil and dragonCombat.coop~=true and dragonCombat.playerIndex==cleanupPlayer and dragonCombat.levelsApplied~=true then
			safeWaitCondition("Combat",finishRewardDelay,function()
				local current=gStates.apocalypseDragonGroundCombat
				return current==nil or current.levelsApplied==true
			end,5,finishRewardDelay)
		else
			finishRewardDelay()
		end
	end, 2.0)
	return coopCombatReward
end

local function combatPreEndTurnRaiseAvatar(cleanupPlayer)
	--lift player Avatar for token(s) to go under
	local tokenRaised=0
	local avatarPos={}
	local avatarModel=nil
	if (turnOrder[cleanupPlayer].avatarLocation=="mine" and gStates.gameScenario=="Mines Liberation")
		or (turnOrder[cleanupPlayer].avatarLocation:sub(1, 4)=="city" and gStates.gameScenario=="The Lost Relic Blitz")
		or (turnOrder[cleanupPlayer].avatarLocation=="glade" and gStates.gameScenario=="Life and Death")
		or turnOrder[cleanupPlayer].avatarLocation=="graveyard"
		or turnOrder[cleanupPlayer].avatarLocation=="keep"	or turnOrder[cleanupPlayer].avatarLocation=="mage tower"
		or turnOrder[cleanupPlayer].avatarLocation=="tomb"	or turnOrder[cleanupPlayer].avatarLocation=="dungeon"
		or turnOrder[cleanupPlayer].avatarLocation=="labyrinth" or turnOrder[cleanupPlayer].avatarLocation=="maze"
		or turnOrder[cleanupPlayer].avatarLocation=="ziggurat" or turnOrder[cleanupPlayer].avatarLocation=="pyramid"
		or turnOrder[cleanupPlayer].avatarLocation=="ruin"
		or turnOrder[cleanupPlayer].avatarLocation=="monster den" or turnOrder[cleanupPlayer].avatarLocation=="spawning grounds"
		or turnOrder[cleanupPlayer].avatarLocation=="monastery"
		or (againstDragonFullAttendInProgress~=nil and againstDragonFullAttendInProgress(cleanupPlayer)==true
			and againstDragonAirborneProtectionDestroysSite~=nil and againstDragonAirborneProtectionDestroysSite(turnOrder[cleanupPlayer].avatarLocation)==true) then
		avatarModel=mageKnightAvatarObject(cleanupPlayer,false)
		if avatarModel~=nil then
			avatarPos=avatarModel.getPosition()
			avatarModel.setPosition({avatarPos[1],avatarPos[2]+2,avatarPos[3]})
			avatarModel.lock()
			tokenRaised=cleanupPlayer
		end
	end
	return tokenRaised,avatarPos,avatarModel
end

local function combatReturnPreEndTurnDie(cleanupPlayer,diceGUID)
	--make sure coop assault isn't happening before returning dice.
	gStates.coopAssaultDice[#gStates.coopAssaultDice+1]=diceGUID
	if getObjectFromGUID(turnOrder[nextTurnMerged("nextMageSkipDummy")].turnOrderTokenGUID).is_face_down==false or #turnOrder<=2 then
		for _, diceG in pairs(gStates.coopAssaultDice) do
			local die=getObjectFromGUID(diceG)
			if die~=nil then
				die.setPosition({-12.5+(math.random()*7),2.7,-25.0+(math.random()*4.0)})
				die.randomize()
				onObjectRandomize({type="Dice"})
			end
		end
		gStates.coopAssaultDice={}
	end
end

local function combatPreEndTurnPreparePlayArea(cleanupPlayer)
	--locate discard deck
	local cardDestination=nil
	for _, deckSearch in pairs(getObjectFromGUID(deedDeckDiscardZones[turnOrder[cleanupPlayer].seatPos]).getObjects()) do
		if deckSearch.type=="Card" or deckSearch.type=="Deck" then cardDestination=deckSearch break end
	end

	--separate any decks and possessed tokens found. Unit Area monsters use the same combat cleanup path.
	local tokenWait=0
	for _, playAreaObj in pairs(playerCombatObjects(turnOrder[cleanupPlayer].seatPos)) do
		--separate decks
		if playAreaObj.type=="Deck" then
			for count=1, #playAreaObj.getObjects()-1, 1 do
				playAreaObj.takeObject({position={playAreaObj.getPosition()[1]+(0.8*count), playAreaObj.getPosition()[2]+(0.06*count), playAreaObj.getPosition()[3]+(0.8*count)}, smooth=false})
			end
		end
		--Separate possessed tokens only after the base enemy was actually defeated.
		--An undefeated face-down rampager returns to the map with its possession still attached.
		if playAreaObj.getAttachments()[1]~=nil and playAreaObj.is_face_down==false then
			local destroyedSiteRewards=againstApocalypseRampagerDestroyedSiteRewards~=nil and againstApocalypseRampagerDestroyedSiteRewards(playAreaObj) or 0
			if destroyedSiteRewards>0 then
				local destroyedBag=getObjectFromGUID(GUID.bag.destroyedSite)
				if destroyedBag~=nil then
					for _=1,destroyedSiteRewards do
						destroyedBag.takeObject({position={(turnOrder[cleanupPlayer].seatPos*40)-117.2+(math.random()*6.5), 2, -35+(math.random()*3.2)}})
					end
				end
			end
			attachEnemy(nil, nil, "detach", playAreaObj, nil)
		end
		tokenWait=40
	end
	return cardDestination,tokenWait
end

local function combatSchedulePreEndTurnAvatarDrop(cleanupPlayer,tokenRaised,avatarPos,avatarModel,state,tokenWait)
	--Drop Avatar after a pause. A returning undefeated monster can still be smooth-moving when the
	--two-second settle check expires (Quest failures make this common). The old wait had no timeout
	--handler, so the avatar could remain locked at +2 height forever. Run the same finish routine on
	--either a normal settle or timeout.
	safeWaitFrames("Combat",function()
		local avatarDropFinished=false
		local function finishAvatarDrop()
			if avatarDropFinished==true then return end
			avatarDropFinished=true
			--place shield or replenish monster in spawning grounds
			if turnOrder[cleanupPlayer]~=nil and turnOrder[cleanupPlayer].avatarLocation=="spawning grounds" then
				if state.cleanupContext.spawningGroundMonstersBeat==2 then dropShield({avatarPos[1], 2, avatarPos[3]}, true) coralTalesSiteShield("spawning grounds") end
				if state.spawningGroundMonstersReturned==1 then
					local newMonster=getObjectFromGUID(monsterPiles.tan).takeObject({position={avatarPos[1]+0.22, 2.12, avatarPos[3]}, smooth=false})
					gStates.monsterPlayLocation[newMonster.guid]={avatarPos[1]+0.22, 2.12, avatarPos[3]}
				end
			end
			local horsemenReturn=againstHorsemenFinishSoloAssault(cleanupPlayer)
			if horsemenReturn~=nil then
				if avatarModel~=nil then
					avatarPos={horsemenReturn[1],horsemenReturn[2],horsemenReturn[3]}
				else
					local horsemenAvatar=coopAssaultAvatarObject(cleanupPlayer)
					if horsemenAvatar~=nil then horsemenAvatar.setPositionSmooth(horsemenReturn,false,false) end
				end
			end
			if avatarModel~=nil then
				avatarModel.setLock(false)
				avatarModel.setPositionSmooth({avatarPos[1], avatarPos[2]+1.0, avatarPos[3]},false,false)
			end
		end
		safeWaitCondition("Combat",finishAvatarDrop, function()
			if tokenRaised<=0 or (state.lastObject~=nil and state.lastObject.resting~=true) then return false end
			local pendingDragonAttack=gStates~=nil and gStates.apocalypseDragonPendingAttack or nil
			local destroyedGUID=pendingDragonAttack~=nil and pendingDragonAttack.destroyedSiteTokenGUID or nil
			if destroyedGUID~=nil then
				local destroyed=getObjectFromGUID(destroyedGUID)
				if destroyed==nil then return false end
				local destroyedPos=destroyed.getPosition()
				if math.abs(destroyedPos[2]-1.13)>0.05 then return false end
			end
			return true
		end, 5, finishAvatarDrop)
	end, tokenWait+3)
end

local function combatSchedulePreEndTurnStateRefresh(player,cleanupPlayer,state,tokenWait)
	--Adjust hand size and Check for scenario completion to Start the final round of turns.
	--A completed City assault has just changed both monster state and physical shields. Rebuild ownership once,
	--at this settled cleanup boundary, before fakeDropAvatar reads Lead/Assist for the new hand limit.
	--Other cleanup only needs the cheaper defeat-state refresh; co-op combat rebuilds ownership in its reward phase.
	safeWaitFrames("Combat",function() safeWaitCondition("Combat",function()
		local cleanupLocation=turnOrder[cleanupPlayer]~=nil and turnOrder[cleanupPlayer].avatarLocation or ""
		if gStates.coopAssaultPhase~="combat" and (cleanupLocation:sub(1,4)=="city" or cleanupLocation:sub(1,6)=="raised") then cityBeatCheck()
		else refreshCityDefeatState() end
		fakeDropAvatar(cleanupPlayer)
		scenarioCombatCleanupCheck(cleanupPlayer)
		--Combat Complete is the only confirmation during the combat stage. Advance as soon as cleanup is finished.
		if gStates.endGameAchieved=="false" and gStates.tacticShown==false and gStates.coopAssaultPhase=="combat" then
			safeWaitFrames("Combat",function()
				if gStates.coopAssaultPhase=="combat" and gStates.preEndTurn==true then endTurn(player,"-1","CoopCombatComplete") end
			end,2)
		end
	end, function() return state.lastObject==nil or state.lastObject.resting end, 2, function()
		if gStates.coopAssaultPhase=="combat" and gStates.preEndTurn==true then endTurn(player, "-1", "CoopCombatComplete") end
	end) end, tokenWait+50)
end

local function combatSchedulePreEndTurnSkillCleanup(cleanupPlayer,tokenWait)
	--Skills own circulation/return rules; Combat retains the same delayed cleanup boundary.
	local nextPlayer=nextTurnMerged("nextMageSkipDummy")
	safeWaitFrames("Combat",function()
		local keepSafe=prepareEndTurnSkillRotation(cleanupPlayer,nextPlayer)
		local playArea=getObjectFromGUID(playerPlayAreas[turnOrder[cleanupPlayer].seatPos])
		local trash=getObjectFromGUID(trashCan)
		for _, playAreaObj in pairs(playArea~=nil and playArea.getObjects() or {}) do
			if (playAreaObj.type=="Figurine" and keepSafe[playAreaObj.guid]~=true)
			or playAreaObj.getName()=="Blue Defender Bonus Reminder" or playAreaObj.getName()=="Green Defender Bonus Reminder"
			or playAreaObj.getName()=="White Defender Bonus Reminder" or playAreaObj.getName()=="Red Defender Bonus Reminder" then
				if trash~=nil then trash.putObject(playAreaObj) end
			end
		end
	end,tokenWait+3)
end

local function combatCleanupPreEndTurnUnitArea(cleanupPlayer)
	--Remove crystals and dice used to power Units
	local crystalsToDestroy={}
	local unitAreaObjects=getObjectFromGUID(playerUnitAreas[turnOrder[cleanupPlayer].seatPos]).getObjects()
	for _, unitAreaObj in pairs(unitAreaObjects) do
		--Return any Mana dice
		if unitAreaObj.type=="Dice" then
			combatReturnPreEndTurnDie(cleanupPlayer,unitAreaObj.guid)
		end
		cleanupUnitAreaSkillAtEndTurn(unitAreaObj,cleanupPlayer)
		--Record Crystals in the Unit Area. Registered skill tokens are never disposable crystals.
		if unitAreaObj.type=="Figurine" and unitAreaObj.getGMNotes()~="Unit Wound" and skillTokens[unitAreaObj.guid]==nil and monsterPugs[unitAreaObj.guid]==nil then crystalsToDestroy[#crystalsToDestroy+1]=unitAreaObj.guid end
	end
	for _, crystals in pairs(crystalsToDestroy) do
		local crystal=getObjectFromGUID(crystals)
		local delete=true
		if crystal~=nil then
			local nearestUnit, distance=unitLayoutNearestUnit(unitAreaObjects,crystal.getPosition()[1])
			if nearestUnit~=nil and distance<=1.5 and (nearestUnit.guid=="0a2e0b" or nearestUnit.guid=="d8e49b") then delete=false end
		end
		if delete==true and crystal~=nil then getObjectFromGUID(trashCan).putObject(crystal) end
	end

	--Fame and Reputation are held until every participant has finished a co-op assault.
	if gStates.coopAssaultPhase~="combat" then applyPlayerFameReputation(cleanupPlayer) end

	--Use the player whose cleanup started, not whatever turn happens to be current when
	--this delayed callback fires. This prevents two Mage Knights being left on the portal.
	if coopAssaultVirtualPlayer(cleanupPlayer)==false then portalSwap("endOfTurn", cleanupPlayer) end
end

local function combatSchedulePreEndTurnCleanup(player,cleanupPlayer,coopCombatReward,tokenRaised,avatarPos,avatarModel,cardDestination,tokenWait)
	safeWaitFrames("Combat",function()
		--Get objects from player area to clean them up
		local state={
			lastObject=nil,
			spawningGroundMonstersReturned=0,
			cleanupContext={player=cleanupPlayer,coopCombatReward=coopCombatReward,avatarPos=avatarPos,volkareCityShield=0,volkarePaused=false,spawningGroundMonstersBeat=0,mapSpatial=runtimeMapSpatialSnapshot()}
		}
		gStates.turnForfeited=true
		--Goblin Warrens is resolved by the normal monster-cleanup result below. Fresh Goblins begin
		--face up, so checking them here would incorrectly count an untouched/failed fight as success.
		for _, playAreaObj in pairs(playerCombatObjects(turnOrder[cleanupPlayer].seatPos)) do
			local cleanupObjectGUID=playAreaObj.guid
			safeWaitFrames("Combat",function()
				--Returning an airborne Dragon head restores its real image with reload(), which invalidates
				--the old TTS Object userdata for all four captured head objects. Identify them by GUID before
				--touching that userdata, return the set once, and stop this object's ordinary cleanup here.
				local dragonAirborneCleanup=againstDragonFullAttendInProgress~=nil and againstDragonFullAttendInProgress(cleanupPlayer)==true and againstDragonAirborneHeadGUID~=nil and againstDragonAirborneHeadGUID(cleanupObjectGUID)==true
				if dragonAirborneCleanup==true then
					againstDragonReturnAirborneHeads()
					--The avatar is still raised at this cleanup boundary. Resolve site protection now so
					--the Destroyed Site marker can settle underneath it before the avatar comes back down.
					local pendingDragonAttack=gStates~=nil and gStates.apocalypseDragonPendingAttack or nil
					if againstDragonResolveAirborneProtection~=nil then againstDragonResolveAirborneProtection(pendingDragonAttack) end
					return
				end
				playAreaObj=getObjectFromGUID(cleanupObjectGUID)
				if playAreaObj==nil then return end

				--Return any Mana dice
				if playAreaObj.type=="Dice" then
					combatReturnPreEndTurnDie(cleanupPlayer,playAreaObj.guid)
				end

				--Delete wound tokens, shards and face up potions.
				if playAreaObj.getGMNotes()=="Unit Wound" or playAreaObj.getGMNotes()=="Volkare Reminder Token" or playAreaObj.getGMNotes()=="Trap Reminder Token" or playAreaObj.getGMNotes()=="Oasis Reminder Token" or
					playAreaObj.getName()=="Green Shard" or playAreaObj.getName()=="Red Shard" or playAreaObj.getName()=="Blue Shard" or playAreaObj.getName()=="White Shard" or
					((playAreaObj.getName()=="Green Potion" or playAreaObj.getName()=="Red Potion" or playAreaObj.getName()=="Blue Potion" or playAreaObj.getName()=="White Potion") and playAreaObj.is_face_down==false) or
					(playAreaObj.getName()=="" and playAreaObj.type=="Tile" and monsterPugs[playAreaObj.guid]==nil) then
					getObjectFromGUID(trashCan).putObject(playAreaObj)
				end

				--Return face down Potion
				if ((playAreaObj.getName()=="Green Potion" or playAreaObj.getName()=="Red Potion" or playAreaObj.getName()=="Blue Potion" or playAreaObj.getName()=="White Potion") and playAreaObj.is_face_down==true) then
					if gStates.mageSkills[playAreaObj.guid]~=nil then playAreaObj.setPositionSmooth(gStates.mageSkills[playAreaObj.guid],false,false) end
				end

				--Mark mine monster as defeated
				for _, monsters in pairs(gStates.mineMonsterQty) do
					if monsters[playAreaObj.guid]~=nil and playAreaObj.is_face_down==false then
						monsters[playAreaObj.guid]="dead"
						break
					end
				end

				local dragonGroundCleanup=apocalypseDragonGroundCombatForPlayer~=nil and apocalypseDragonGroundCombatForPlayer(cleanupPlayer)==true and apocalypseDragonGroundCombatToken~=nil and select(1,apocalypseDragonGroundCombatToken(playAreaObj.guid))==true
				if dragonGroundCleanup==true then
					apocalypseDragonGroundResolveToken(playAreaObj)
					apocalypseDragonGroundTryApplyLevelsBeforeRewards(cleanupPlayer)
					return
				end

				--Return undefeated face down tokens
				if monsterPugs[playAreaObj.guid]~=nil and playAreaObj.is_face_down==true and dragonGroundCleanup~=true then
					if gStates.monsterPlayLocation[playAreaObj.guid]==nil or turnOrder[cleanupPlayer].avatarLocation=="spawning grounds" then
						--if manual drawn assign the avatar location as return spot.
						if (gStates.volkarePursuitEnemies==nil or gStates.volkarePursuitEnemies[playAreaObj.guid]~=true) and gStates.summonStates[playAreaObj.guid]~="summoned" and (turnOrder[cleanupPlayer].avatarLocation=="monster den" or turnOrder[cleanupPlayer].avatarLocation=="spawning grounds" or turnOrder[cleanupPlayer].avatarLocation=="ruin") then
							gStates.monsterPlayLocation[playAreaObj.guid]={avatarPos[1], 2.5, avatarPos[3]}
						end
					end
					if gStates.monsterPlayLocation[playAreaObj.guid]~=nil then
						if gStates.pursuingMonsters[turnOrder[cleanupPlayer].mage]~=nil and gStates.pursuingMonsters[turnOrder[cleanupPlayer].mage][playAreaObj.guid]~=nil then
							local pursuit=gStates.pursuingMonsters[turnOrder[cleanupPlayer].mage][playAreaObj.guid]
							pursuit.state="Stunned" pursuit.stunned=true
							playAreaObj.setRotation({0, 180, 0})
							broadcastToAll(joinLang({translateWord[turnOrder[cleanupPlayer].mage],"{en} Stunned the Pursuing Rampager (Skips next turns Movement){ru} «оглушает» преследователя (тот пропускает одно Движение){zh-tw} 暈眩了狂暴追擊者（它會跳過下次移動）{zh-cn}晕眩了狂暴追击者(它跳过下次行动){ko}: 추적하는 적 기절시킴. (다음 추적 단계 건너뜀.){es} Aturdido al agresor que lo persigue (se salta el movimiento del siguiente turno){fr} Étourdi le saccageur à la poursuite (ignore le mouvement des tours suivants){pt-br} Atordoou o Irascível Perseguidor (Pule próximos turnos de movimento).{de} hat den Verfolger betäubt (überspringt die Bewegung des nächsten Zuges)"}), positionToColor(cleanupPlayer))
						else
							local returningMonsterGUID=playAreaObj.guid
							safeWaitTime("Combat",function()
								local returningMonster=getObjectFromGUID(returningMonsterGUID)
								if returningMonster~=nil then returningMonster.setRotation({0,180,0}) end
							end,3)--long enough to have traveled back to the board.
						end
						if gStates.coopAssaultPhase=="combat" and coopAssaultTargetType()=="horsemen" and horsemanTokenToName~=nil and horsemanTokenToName[playAreaObj.guid]~=nil then
							--Each Horseman is assigned to exactly one participant; a survivor returns to its Portal-card slot.
							playAreaObj.setRotation({0,180,0})
							playAreaObj.setPositionSmooth(gStates.monsterPlayLocation[playAreaObj.guid],false,false)
							state.lastObject=playAreaObj
						elseif gStates.coopAssaultPhase=="combat" and coopAssaultTargetType()=="leader" and (playAreaObj.guid==elementalist.token or playAreaObj.guid==darkCrusader.token) then
							--A face-down leader means this player defeated no leader levels. Advance the real token through
							--the same preview handoff used by a face-up surviving leader so the next planning copy is consumed.
							if coopAssaultPendingCombat()==true then
								local nextPlayer=nextTurnMerged("nextMage")
								promoteCoopLeaderPreview(nextPlayer, playAreaObj)
							else
								clearCoopLeaderPreviewClones()
								playAreaObj.setRotation({0, 180, 0})
								playAreaObj.setPositionSmooth(gStates.monsterPlayLocation[playAreaObj.guid],false,false)
							end
						elseif getObjectFromGUID(turnOrder[nextTurnMerged("nextMage")].turnOrderTokenGUID).is_face_down==true and playAreaObj.getRotationValues()[2]==nil then
							--Move to next players play area.
							playAreaObj.setPositionSmooth({turnOrder[nextTurnMerged("nextMage")].seatPos*40-100, 1.5, -39.41},false,false)
						else
							if turnOrder[cleanupPlayer].avatarLocation=="spawning grounds" and (gStates.volkarePursuitEnemies==nil or gStates.volkarePursuitEnemies[playAreaObj.guid]~=true) then
								gStates.monsterPlayLocation[playAreaObj.guid][1]=gStates.monsterPlayLocation[playAreaObj.guid][1]-0.22+(state.spawningGroundMonstersReturned*0.44)
								gStates.monsterPlayLocation[playAreaObj.guid][2]=gStates.monsterPlayLocation[playAreaObj.guid][2]+(state.spawningGroundMonstersReturned*0.12)
								state.spawningGroundMonstersReturned=state.spawningGroundMonstersReturned+1
							end
							if gStates.monsterPerks[playAreaObj.guid]~=nil and gStates.monsterPerks[playAreaObj.guid].wallFortified~=nil then setAssaultWallFortified(playAreaObj, false) end
							playAreaObj.setPositionSmooth(gStates.monsterPlayLocation[playAreaObj.guid],false,false)
							state.lastObject=playAreaObj
						end
					end
				end

				--Process and Discard Face up monsters. Horsemen are persistent Custom Tiles, so identify
				--them before any generic rotation-value discard route can mistake them for a normal token.
				if monsterPugs[playAreaObj.guid]~=nil and dragonGroundCleanup~=true and (playAreaObj.is_face_down==false or gStates.monsterPlayLocation[playAreaObj.guid]==nil) then
					if horsemanTokenToName~=nil and horsemanTokenToName[playAreaObj.guid]~=nil then
						horsemanResolveDefeat(playAreaObj,cleanupPlayer,coopCombatReward)
					elseif playAreaObj.getRotationValues()[2]~=nil then
						combatDiscardMonster(playAreaObj,true,state.cleanupContext)
					else--process leaders
						local currentLeader=elementalist
						if playAreaObj.guid==darkCrusader.token then currentLeader=darkCrusader end
						--drop shield(s) on leader disc
						for b=1, gStates.leaderOverkill, 1 do
							local leaderDisc=getObjectFromGUID(currentLeader.disc)
							if leaderDisc~=nil then
								local hexRotationRad=math.rad(-1*(-120+tonumber(30*(gStates.elementalistLevel-gStates.leaderReduction-(b-1)))))
								if playAreaObj.guid==darkCrusader.token then hexRotationRad=math.rad(-1*(-120+tonumber(30*(gStates.darkCrusaderLevel-gStates.leaderReduction-(b-1))))) end
								local discPos=leaderDisc.getPosition()
								local location={discPos[1]+(math.cos(hexRotationRad)*2.9),2+(b*1.5),discPos[3]+(math.sin(hexRotationRad)*2.9)}
								dropShield(location,false)
							end
						end
						--Record damage to the faction leader, but during a cooperative assault do not move its
						--actual level marker/state until every participating player has finished combat.
						gStates.leaderReduction=gStates.leaderReduction+gStates.leaderOverkill
						local leaderStartingLevel=gStates.elementalistLevel
						if playAreaObj.guid==darkCrusader.token then leaderStartingLevel=gStates.darkCrusaderLevel end
						local leaderDefeatedNow=gStates.leaderReduction>=leaderStartingLevel
						gStates.leaderOverkill=1
						if gStates.coopAssaultPhase=="combat" and coopAssaultTargetType()=="leader" then
							--The next participant already has a planning clone. Swap the real leader into that copy's
							--current position so the combat controls move with the real token. If the leader was fully
							--marked, remove every remaining preview because later participants no longer face it.
							if coopAssaultPendingCombat()==true and leaderDefeatedNow==false then
								local nextPlayer=nextTurnMerged("nextMage")
								promoteCoopLeaderPreview(nextPlayer, playAreaObj)
							else
								clearCoopLeaderPreviewClones()
								if gStates.monsterPlayLocation[playAreaObj.guid]~=nil then playAreaObj.setPositionSmooth(gStates.monsterPlayLocation[playAreaObj.guid],false,false) end
							end
						else
							--Solo/non-co-op leader combat keeps the existing immediate resolution.
							local currenLeaderLevel=math.max(0, leaderStartingLevel-gStates.leaderReduction)
							if playAreaObj.guid==darkCrusader.token then gStates.darkCrusaderLevel=currenLeaderLevel else gStates.elementalistLevel=currenLeaderLevel end
							gStates.leaderReduction=0
							if currenLeaderLevel==0 then
								getObjectFromGUID(trashCan).putObject(playAreaObj)
								gStates.cityMonsterQty[currentLeader.terrainHex][currentLeader.token]="dead"
								local leaderDisc=getObjectFromGUID(currentLeader.disc)
								if leaderDisc~=nil then leaderDisc.setCustomObject({image=leaderData[currentLeader.terrainHex]["dead"].discImg}) leaderDisc.reload() end
								safeWaitTime("Combat",function()
									for monsterGUID, state in pairs(gStates.cityMonsterQty[currentLeader.terrainHex]) do
										local monster=getObjectFromGUID(monsterGUID)
									if monster~=nil and monster.getRotationValues()[2]~=nil then combatDiscardMonster(monster,false,state.cleanupContext) end
									end
								end, 2)
							else
								playAreaObj.setPositionSmooth(gStates.monsterPlayLocation[playAreaObj.guid],false,false)
								safeWaitFrames("Combat",function()
									local levelData=leaderData[currentLeader.terrainHex]~=nil and leaderData[currentLeader.terrainHex][currenLeaderLevel] or nil
									if levelData==nil then return end
									local leaderDisc=getObjectFromGUID(currentLeader.disc)
									if leaderDisc~=nil then leaderDisc.setCustomObject({image=levelData.discImg}) leaderDisc.reload() end
									local leaderToken=getObjectFromGUID(currentLeader.token)
									if leaderToken~=nil then
										leaderToken.setCustomObject({image=levelData.tokenImg})
										leaderToken.setName(joinLang({currentLeader==darkCrusader and "{en}Dark Crusader Leader Level {ru}Уровень лидера Тёмных крестоносцев: {zh-tw}黑暗十字軍領袖等級 {zh-cn}黑暗十字军领袖等级 {ko}다크 크루세이더 지도자 레벨 {es}Nivel del líder Cruzado Oscuro {fr}Niveau du chef Croisé Sombre {pt-br}Nível do líder Cruzado Sombrio {de}Stufe des Anführers der Dunklen Kreuzritter " or "{en}Elementalist Leader Level {ru}Уровень лидера Элементалистов: {zh-tw}元素使領袖等級 {zh-cn}元素使领袖等级 {ko}엘리멘탈리스트 지도자 레벨 {es}Nivel del líder Elementalista {fr}Niveau du chef Élémentaliste {pt-br}Nível do líder Elementalista {de}Stufe des Elementalisten-Anführers ", currenLeaderLevel}))
										leaderToken.reload()
									end
									monsterPugs[currentLeader.token]=levelData.abilities
								end,100)
							end
						end
					end
				end

				--Discard Reward Tokens
				local rewardDiscardGUID=combatRewardDiscardByNotes[playAreaObj.getGMNotes()]
				if rewardDiscardGUID~=nil then
					playAreaObj.setRotation({0,180,180})
					local rewardDiscard=getObjectFromGUID(rewardDiscardGUID)
					if rewardDiscard~=nil then rewardDiscard.putObject(playAreaObj) end
				end

				if playAreaObj.type=="Card" then cardDestination=cleanupPlayedCardAtEndTurn(playAreaObj,cleanupPlayer,cardDestination) end
				cleanupPlayedSkillAtEndTurn(playAreaObj,cleanupPlayer)
			end, tokenWait+3)
			tokenWait=tokenWait+3
		end
		safeWaitFrames("Combat",function() tokenRefill() end,tokenWait+1)

		combatSchedulePreEndTurnAvatarDrop(cleanupPlayer,tokenRaised,avatarPos,avatarModel,state,tokenWait)
		combatSchedulePreEndTurnStateRefresh(player,cleanupPlayer,state,tokenWait)
		combatSchedulePreEndTurnSkillCleanup(cleanupPlayer,tokenWait)
		combatCleanupPreEndTurnUnitArea(cleanupPlayer)
	end,tokenWait)
end

function __preEndTurn_raw(player, mouseButton, id, rewindReady)
	if gStates.apocalypseDragonTurnActive==true and (againstDragonFullAttendInProgress==nil or againstDragonFullAttendInProgress(gStates.turnNumber)~=true) then
		if player~=nil and player.color~=nil then broadcastToColor("{en}Finish the Apocalypse Dragon turn first.{ru}Сначала завершите ход Дракона Апокалипсиса.{zh-tw}請先完成末日巨龍的回合。{zh-cn}请先完成末日巨龙的回合。{ko}먼저 아포칼립스 드래곤의 차례를 끝내세요.{es}Primero termina el turno del Dragón del Apocalipsis.{fr}Terminez d’abord le tour du Dragon de l’Apocalypse.{pt-br}Termine primeiro o turno do Dragão do Apocalipse.{de}Beende zuerst den Zug des Apokalypse-Drachen.",player.color,warningColor) end
		return
	end
	if mouseButton~="-1" or legalPlayerCheck(player.color,turnOrder[gStates.turnNumber].seatPos)~=true then return end
	if gStates.mineClaimPending~=nil then
		broadcastToColor("{en}Resolve the pending crystal choice before ending the turn.{ru}Завершите ожидающий выбор кристалла, прежде чем заканчивать ход.{zh-tw}結束回合前，請先完成尚未處理的魔晶選擇。{zh-cn}结束回合前，请先完成尚未处理的魔晶选择。{ko}턴을 끝내기 전에 대기 중인 수정 선택을 완료하세요.{es}Resuelve la elección de cristal pendiente antes de terminar el turno.{fr}Résolvez le choix de cristal en attente avant de terminer le tour.{pt-br}Resolva a escolha de cristal pendente antes de encerrar o turno.{de}Schließe die ausstehende Kristallauswahl ab, bevor du den Zug beendest.",player.color,warningColor)
		if rewindReady==true then rewindTransactionFinish("Pre-end-turn cleanup") end
		return
	end
	if rewindReady~=true then
		if rewindTransactionOwnerActive("Pre-end-turn cleanup")==true then return end
		rewindTransactionStart(function() preEndTurn(player,mouseButton,id,true) end,"Pre-end-turn cleanup")
		return
	end

	local cleanupPlayer=gStates.turnNumber
	local coopCombatReward=combatPreEndTurnOpenRewardBoundary(cleanupPlayer)
	turnPreparePreEndTurn(cleanupPlayer,player.color,id)
	local tokenRaised,avatarPos,avatarModel=combatPreEndTurnRaiseAvatar(cleanupPlayer)
	local cardDestination,tokenWait=combatPreEndTurnPreparePlayArea(cleanupPlayer)
	combatSchedulePreEndTurnCleanup(player,cleanupPlayer,coopCombatReward,tokenRaised,avatarPos,avatarModel,cardDestination,tokenWait)
end

assaultApproachOrigin=nil
assaultTargetPosition=nil
wallAssaultChoiceResult=nil
local wallAssaultPending=nil

--The initiator's pickup position only tells us the entry side when it was an adjacent hex.
function assaultOriginAdjacent(targetPos, attackerPos)
	if targetPos==nil or attackerPos==nil then return false end
	local _, _, targetHexPos=terrainHexAtPosition(targetPos)
	local _, _, attackerHexPos=terrainHexAtPosition(attackerPos)
	if targetHexPos==nil or attackerHexPos==nil then return false end
	local dist=math.sqrt(((targetHexPos[1]-attackerHexPos[1])^2)+((targetHexPos[3]-attackerHexPos[3])^2))
	return dist>1 and dist<2.8
end

function assaultTargetHasWall(targetPos)
	if targetPos==nil then return false end
	local terrain, targetBearing=terrainHexAtPosition(targetPos)
	return terrain~=nil and targetBearing~=nil and terrainTiles[terrain.guid]~=nil and terrainTiles[terrain.guid].wallList~=nil and terrainTiles[terrain.guid].wallList[targetBearing]~=nil and next(terrainTiles[terrain.guid].wallList[targetBearing])~=nil
end

function wallAssaultChoiceNeeded(targetPos, attackerPos)
	if attackerPos==nil then attackerPos=assaultApproachOrigin end
	return assaultTargetHasWall(targetPos)==true and assaultOriginAdjacent(targetPos, attackerPos)==false
end

function showWallAssaultChoice(mode, id, viewerColor)
	wallAssaultPending={mode=mode, id=id}
	UI.setAttribute("WallAssaultChoice", "visibility", (viewerColor or positionToColor(gStates.turnNumber)).."|Black")
	if mode=="rampagerAttack" or mode=="manualMonster" then
		UI.setAttribute("WallAssaultChoiceQuestion", "text", "{en}The attack approach is unclear.\nDid your attack cross a wall?{ru}Направление атаки неясно.\nВаша атака проходила через стену?{zh-tw}攻擊的方向不明確。\n你的攻擊是否穿過城牆？{zh-cn}攻击的方向不明确。\n你的攻击是否穿过城墙？{ko}공격 방향이 불분명합니다.\n공격 중 성벽을 넘었습니까?{es}La dirección del ataque no está clara.\n¿Tu ataque cruzó una muralla?{fr}La direction de l'attaque n'est pas claire.\nVotre attaque a-t-elle franchi un mur ?{pt-br}A direção do ataque não está clara.\nSeu ataque atravessou uma muralha?{de}Die Angriffsrichtung ist unklar.\nHat dein Angriff eine Mauer überquert?")
	else
		UI.setAttribute("WallAssaultChoiceQuestion", "text", "{en}The assault approach is unclear.\nDid your assault cross a wall?{ru}Направление штурма неясно.\nВаш штурм проходил через стену?{zh-tw}突襲的進入方向不明確。\n你的突襲是否穿過城牆？{zh-cn}突袭的进入方向不明确。\n你的突袭是否穿过城墙？{ko}강습 진입 방향이 불분명합니다.\n강습 중 성벽을 넘었습니까?{es}La dirección del asalto no está clara.\n¿Tu asalto cruzó una muralla?{fr}La direction de l'assaut n'est pas claire.\nVotre assaut a-t-il franchi un mur ?{pt-br}A direção do ataque não está clara.\nSeu ataque atravessou uma muralha?{de}Die Angriffsrichtung ist unklar.\nHat dein Angriff eine Mauer überquert?")
	end
	UI.show("WallAssaultChoice")
end

function clearWallAssaultChoice()
	wallAssaultChoiceResult=nil
	wallAssaultPending=nil
	UI.hide("WallAssaultChoice")
end

function wallAssaultChoice(player, mouseButton, id)
	if mouseButton~="-1" or player==nil or legalPlayerCheck(player.color, turnOrder[gStates.turnNumber].seatPos)~=true then return end
	if id=="WallAssaultChoiceYes" then wallAssaultChoiceResult=true
	elseif id=="WallAssaultChoiceNo" then wallAssaultChoiceResult=false
	else return end
	local pending=wallAssaultPending
	wallAssaultPending=nil
	UI.hide("WallAssaultChoice")
	if pending~=nil then
		if pending.mode=="attackLocation" or pending.mode=="rampagerAttack" then attackLocation(nil, "-1", pending.id)
		elseif pending.mode=="attackCity" then attackCity(nil, "-1", pending.id)
		elseif pending.mode=="manualMonster" then
			local monster=getObjectFromGUID(pending.id)
			if monster~=nil then
				setAssaultWallFortified(monster, wallAssaultChoiceResult)
				settleAssaultWallFortified(monster.guid, wallAssaultChoiceResult)
			end
			wallAssaultChoiceResult=nil
		end
	end
end

function resolveAssaultWallFortified(targetPos, attackerPos, useManualChoice)
	if targetPos==nil or assaultTargetHasWall(targetPos)~=true then return false end
	if useManualChoice~=false and wallAssaultChoiceResult~=nil and assaultOriginAdjacent(targetPos, attackerPos)==false then return wallAssaultChoiceResult end
	return assaultCrossesWall(targetPos, attackerPos)
end

--Moving the initiating avatar away before Begin Assault cancels the pending co-op proposal.
function clearPendingCoopAssault()
	if gStates.coopAssaultPhase~=nil or gStates.coopAssaultCityGUID==nil then return end
	UI.hide("CoopAssault")
	clearCoopAssaultRuntime()
	gStates.againstHorsemenAssaultOrigin=nil
	gStates.apocalypseDragonAssaultOrigin=nil
	locationAttacked=false
	applyColorBarButtons()
end

--Test whether an assault from attackerPos to targetPos crosses a printed wall on the target terrain tile.
function assaultCrossesWall(targetPos, attackerPos)
	if targetPos==nil or attackerPos==nil then return false end
	local terrain, targetBearing=terrainHexAtPosition(targetPos)
	if terrain==nil or targetBearing==nil or terrainTiles[terrain.guid]==nil or terrainTiles[terrain.guid].wallList==nil or terrainTiles[terrain.guid].wallList[targetBearing]==nil then return false end
	local attackerBearing=terrainHexBearing(terrain, attackerPos)
	if attackerBearing==nil then return false end
	return terrainTiles[terrain.guid].wallList[targetBearing][attackerBearing]~=nil
end

function setAssaultWallFortified(monster, fortified)
	if monster==nil or monsterPugs[monster.guid]==nil then return end
	local wallFound=false
	for _, decal in pairs(monster.getDecals() or {}) do if decal.name=="WallFortified" then wallFound=true break end end
	if fortified==true and monsterPugs[monster.guid].unfortified==nil then
		if wallFound==false then monster.addDecal({name="WallFortified", url="https://steamusercontent-a.akamaihd.net/ugc/11147958722484508587/09808504747D568FFAECC06537C487DF223C3872/", position={0.85, 0.15, -0.85}, rotation={90, 180, 0}, scale={0.85, 0.85, 1}}) end
		if gStates.monsterPerks[monster.guid]==nil then gStates.monsterPerks[monster.guid]={wallFortified=true} else gStates.monsterPerks[monster.guid].wallFortified=true end
	else
		if wallFound==true then
			local decals={}
			for _, decal in pairs(monster.getDecals() or {}) do if decal.name~="WallFortified" then decals[#decals+1]=decal end end
			monster.setDecals(decals)
		end
		if gStates.monsterPerks[monster.guid]~=nil then gStates.monsterPerks[monster.guid].wallFortified=nil end
	end
end

--Smooth movement can trigger zone decal cleanup after fortification was assigned. Re-apply the visual once the defender settles.
function settleAssaultWallFortified(monsterGUID, fortified)
	local function apply() local monster=getObjectFromGUID(monsterGUID) if monster~=nil then setAssaultWallFortified(monster, fortified) end end
	safeWaitFrames("Combat",function() safeWaitCondition("Combat",apply, function() local monster=getObjectFromGUID(monsterGUID) return monster==nil or monster.resting==true end, 3, apply) end, 2)
end

--A monster dragged directly from the map to a player area may not have a legal adjacent avatar position.
--Use the current avatar when that proves the wall crossing; otherwise ask rather than silently guessing.
function resolveManualMonsterWallFortified(monster)
	if monster==nil or monsterPugs[monster.guid]==nil or monsterPugs[monster.guid].unfortified~=nil then return end
	if gStates.attackedMonsters~=nil and gStates.attackedMonsters[monster.guid]~=nil then return end--scripted attacks resolve their own approach
	local target=gStates.monsterPlayLocation[monster.guid]
	if target==nil then return end
	if assaultTargetHasWall(target)~=true then
		setAssaultWallFortified(monster, false)
		return
	end
	local avatar=coopAssaultAvatarObject(gStates.turnNumber)
	local attackerPos=nil
	if avatar~=nil then
		local pos=avatar.getPosition()
		attackerPos={pos[1], pos[2], pos[3]}
	end
	if wallAssaultChoiceNeeded(target, attackerPos)==true then
		showWallAssaultChoice("manualMonster", monster.guid, positionToColor(gStates.turnNumber))
		return
	end
	local fortified=resolveAssaultWallFortified(target, attackerPos, false)
	setAssaultWallFortified(monster, fortified)
	settleAssaultWallFortified(monster.guid, fortified)
end

function applyCurrentAssaultWallFortified(fortified)
	for monsterGUID, _ in pairs(gStates.attackedMonsters) do
		local monster=getObjectFromGUID(monsterGUID)
		if monster~=nil and monsterPugs[monsterGUID]~=nil then
			setAssaultWallFortified(monster, fortified)
			settleAssaultWallFortified(monsterGUID, fortified)
		end
	end
end

--Build the buttons that live on a monster token so attaching/detaching Possessed updates them immediately.
function monsterObjectButtons(obj, forcedPossessed)
	local addedButtons={}
	if obj==nil or obj.guid==nil or monsterPugs[obj.guid]==nil then return addedButtons end
	local possessedAttached=forcedPossessed
	if possessedAttached==nil then
		possessedAttached=false
		for _, attachment in pairs(obj.getAttachments()) do
			if monsterPugs[attachment.guid]~=nil and monsterPugs[attachment.guid].pugType=="possessed" then possessedAttached=true break end
		end
	end
	if monsterPugs[obj.guid].monsters~=nil and monsterPugs[obj.guid].pugType~="yellow" and gStates.summonStates[obj.guid]~="SummonDone" then
		local summonButtonX=possessedAttached and 200 or 120
		addedButtons[#addedButtons+1]={tag="Button", attributes={id=obj.guid, onClick="global/summonMonster", height=70/0.9, width=70/0.9,
			position=tostring(summonButtonX/0.9).." 0 "..tostring(-15/0.9), rotation="0 0 180", color="rgba(0,0,0,0.0)"},
			children={{tag="Image", attributes={image="Attack Button"}}}}
	end
	local dragonGroundButtons=apocalypseDragonGroundHeadButtons~=nil and apocalypseDragonGroundHeadButtons(obj) or {}
	for _,button in ipairs(dragonGroundButtons) do addedButtons[#addedButtons+1]=button end
	if obj.guid==darkCrusader.token or obj.guid==elementalist.token then
		addedButtons[#addedButtons+1]={tag="Button", attributes={id=obj.guid.."OverkillUp", onMouseDown="global/buttonClicked", onMouseUp="global/buttonClicked", onClick="global/adjustOverkill", height=50/0.9, width=50/0.9,
			color="rgba(0,0,0,0.0)", position="-62 "..tostring(-120/0.9).." "..tostring(-15/0.9), rotation="0 0 180"}, children={{tag="Image", attributes={id=obj.guid.."OverkillUpImage", image="Overkill Up"}}}}
		addedButtons[#addedButtons+1]={tag="Image", attributes={image="Overkill Text", height=50/0.9, width=55/0.9, position="0 "..tostring(-120/0.9).." "..tostring(-15/0.9), rotation="0 0 180"},
			children={{tag="Text", attributes={id=obj.guid.."Overkill", color="rgb(0,0,0)", fontSize="45", fontStyle="Bold", alignment="MiddleCenter", text=gStates.leaderOverkill}}}}
		addedButtons[#addedButtons+1]={tag="Button", attributes={id=obj.guid.."OverkillDown", onMouseDown="global/buttonClicked", onMouseUp="global/buttonClicked", onClick="global/adjustOverkill", height=50/0.9, width=50/0.9,
			color="rgba(0,0,0,0.0)", position="62 "..tostring(-120/0.9).." "..tostring(-15/0.9), rotation="0 0 180"}, children={{tag="Image", attributes={id=obj.guid.."OverkillDownImage", image="Overkill Down"}}}}
	end
	if possessedAttached then
		addedButtons[#addedButtons+1]={tag="Button", attributes={id="detach"..obj.guid, onClick="global/attachEnemy", height=30, width=30, color="rgba(0,0,0,0.0)", position="62 -100 -15", rotation="0 0 180"},
			children={{tag="Image", attributes={id=obj.guid.."detachImage", image="Unlink Button"}}}}
	end
	return addedButtons
end

--Refresh monster object UI without passing an empty table to TTS.
function setMonsterObjectButtons(obj, forcedPossessed)
	if obj==nil then return end
	local buttons=monsterObjectButtons(obj, forcedPossessed)
	if #buttons>0 then obj.UI.setXmlTable(buttons) else obj.UI.setXmlTable({{}}) end
end

--Object UI is not reliably restored by TTS after load/rewind. Rebuild a faction Leader's
--combat controls when the real Leader token is in either a player's Play Area or Unit Area.
function refreshLeaderOverkillButtons()
	for _, leaderGUID in ipairs({darkCrusader.token, elementalist.token}) do
		local leaderObj=getObjectFromGUID(leaderGUID)
		if leaderObj~=nil and objectInPlayerCombatArea(leaderGUID)==true then setMonsterObjectButtons(leaderObj) end
	end
end

--Remove Possessed from an enemy and return the detached token references.
function clearPossessedEnemy(obj)
	local detached={}
	if obj==nil then return detached end
	if #obj.getAttachments()>0 then detached=obj.removeAttachments() end
	if gStates.apocalypsePossessedEnemyByToken~=nil then
		for _, token in pairs(detached or {}) do gStates.apocalypsePossessedEnemyByToken[token.guid]=nil end
	end
	if gStates.apocalypsePossessedFactionByEnemy~=nil then gStates.apocalypsePossessedFactionByEnemy[obj.guid]=nil end
	--Keep detached Possessed-token faction data until the token itself is discarded. Quest-generated
	--Possessed tokens need that identity to award the correct faction reward after separation.
	if gStates.monsterPerks[obj.guid]~=nil then
		gStates.monsterPerks[obj.guid].fame=nil
		gStates.monsterPerks[obj.guid].attack=nil
		gStates.monsterPerks[obj.guid].reward=nil
		gStates.monsterPerks[obj.guid].boost=nil
		gStates.monsterPerks[obj.guid].armour=nil
		gStates.monsterPerks[obj.guid].faction=nil
		gStates.monsterPerks[obj.guid].questHalfFame=nil
	end
	local tokenValues=obj.getRotationValues()
	for _, rotationData in pairs(tokenValues) do
		for type, data in pairs(rotationData) do
			if type=="value" and data:sub(1, 10)=="Possessed " then rotationData[type]=data:sub(11) end
		end
	end
	obj.setRotationValues(tokenValues)
	setMonsterObjectButtons(obj, false)
	return detached
end

--Link and Unlink the chosen enemy
local justDetached={}
function combatAttachEnemyBase(player, mouseButton, id, obj, zone)
	--find nearest monster
	if id=="attach" and obj~=nil then
		local possessedGUID=obj.guid
		local attachZoneGUID=zone~=nil and zone.guid or nil
		local attachPlayer=nil
		for playerIndex, details in pairs(turnOrder) do
			if details.seatPos~=nil and playerPlayAreas[details.seatPos]==attachZoneGUID then attachPlayer=playerIndex break end
		end
		safeWaitFrames("Combat",function() safeWaitCondition("Combat",function()
			local possessed=getObjectFromGUID(possessedGUID)
			if possessed~=nil then
				if gStates.apocalypsePossessedEnemyByToken~=nil and gStates.apocalypsePossessedEnemyByToken[possessedGUID]~=nil then return end
				local zoneObj=attachZoneGUID~=nil and getObjectFromGUID(attachZoneGUID) or nil
				local candidates=zoneObj~=nil and zoneObj.getObjects() or getAllObjects()
				for _, nearEnemy in pairs(candidates) do
					if nearEnemy.guid~=possessedGUID and monsterPugs[nearEnemy.guid]~=nil and monsterPugs[nearEnemy.guid].pugType~="possessed" and justDetached[nearEnemy.guid]~=true and
						nearEnemy.getPosition()[1]-possessed.getPosition()[1]>-0.5 and nearEnemy.getPosition()[1]-possessed.getPosition()[1]<0.5 and nearEnemy.getPosition()[3]-possessed.getPosition()[3]>-0.5 and nearEnemy.getPosition()[3]-possessed.getPosition()[3]<0.5 then
						--Assign perks to monster token
						local perkToCheck={"fame", "attack", "reward", "boost", "armour"}
						for _, perk in pairs(perkToCheck) do
							if not (perk=="attack" and monsterPugs[nearEnemy.guid].monsters~=nil) then
								if monsterPugs[possessedGUID][perk]~=nil then
									if gStates.monsterPerks[nearEnemy.guid]==nil then
										gStates.monsterPerks[nearEnemy.guid]={[perk]=monsterPugs[possessedGUID][perk]}
									else if gStates.monsterPerks[nearEnemy.guid][perk]==nil then
										gStates.monsterPerks[nearEnemy.guid][perk]=monsterPugs[possessedGUID][perk]
									else
										local current=gStates.monsterPerks[nearEnemy.guid][perk]
										local added=monsterPugs[possessedGUID][perk]
										if perk=="attack" and type(current)=="table" and type(added)=="table" then
											--Attack perks are tables of damage-type lists, not numbers. Preserve every attack instead
											--of trying to add the tables (which caused the second Possessed token to error).
											for attackType, values in pairs(added) do
												if current[attackType]==nil then current[attackType]={} end
												for _, value in pairs(values) do current[attackType][#current[attackType]+1]=value end
											end
										elseif type(current)=="number" and type(added)=="number" then
											gStates.monsterPerks[nearEnemy.guid][perk]=current+added
										else
											gStates.monsterPerks[nearEnemy.guid][perk]=added
										end
									end end
								end
							end
						end
						local possessedFaction=(gStates.apocalypsePossessedFactionByToken~=nil and gStates.apocalypsePossessedFactionByToken[possessedGUID]) or "Apoc"
						gStates.monsterPerks[nearEnemy.guid].faction=possessedFaction
						if gStates.apocalypsePossessedFactionByEnemy==nil then gStates.apocalypsePossessedFactionByEnemy={} end
						gStates.apocalypsePossessedFactionByEnemy[nearEnemy.guid]=possessedFaction
						--Add "Possessed" to enemy name.
						local tokenValues=nearEnemy.getRotationValues()
						for rot, rotationData in pairs(tokenValues) do
							for type, data in pairs(rotationData) do
								if type=="value" then tokenValues[rot][type]="Possessed "..data end
							end
						end
						nearEnemy.setRotationValues(tokenValues)
						--Link Enemy and possessed token
						possessed.setPosition({nearEnemy.getPosition()[1],nearEnemy.getPosition()[2]+0.05,nearEnemy.getPosition()[3]})
						possessed.setRotation({0.00, 180.00, 0.00})
						if gStates.apocalypsePossessedEnemyByToken==nil then gStates.apocalypsePossessedEnemyByToken={} end
						gStates.apocalypsePossessedEnemyByToken[possessedGUID]=nearEnemy.guid
						nearEnemy.addAttachment(possessed)
						local summonedPossessed=gStates.summonStates~=nil and (gStates.summonStates[nearEnemy.guid]=="summoned" or gStates.summonStates[possessedGUID]=="summoned")
						if summonedPossessed~=true and attachPlayer~=nil and turnOrder[attachPlayer]~=nil then
							turnOrder[attachPlayer].fameGain=turnOrder[attachPlayer].fameGain+gStates.monsterPerks[nearEnemy.guid].fame
							if factionRewardUsesJustFame(possessedFaction)==true then turnOrder[attachPlayer].fameGain=turnOrder[attachPlayer].fameGain+1 end
						end
						--Refresh the monster UI now that Possessed is attached.
						setMonsterObjectButtons(nearEnemy, true)
						if apocalypseQuestsUsed()==true then safeWaitFrames("Combat",function() apocalypseQuestRefreshOfferButtons() end,2) end
						safeWaitFrames("Combat",function() mainUIUpdate("possessed") end, 5)
						broadcastToAll("{en}Enemy Possessed{ru}Враг одержим{zh-tw}敵人已被附身{zh-cn}敌人已被附身{ko}적이 빙의되었습니다{es}Enemigo poseído{fr}Ennemi possédé{pt-br}Inimigo possuído{de}Gegner besessen}")
						break
					end
				end
			end
		end, function() local possessed=getObjectFromGUID(possessedGUID) return possessed==nil or possessed.resting end) end,5)
	end
	--Unlink Object
	--separate possessed tokens
	if id:sub(1, 6)=="detach" then
		if obj==nil then obj=getObjectFromGUID(id:sub(7,13)) end
		if obj==nil then return end
		local detachedGUID=obj.guid
		justDetached[detachedGUID]=true
		clearPossessedEnemy(obj)
		safeWaitTime("Combat",function() justDetached[detachedGUID]=false end,2)
		broadcastToAll("{en}Enemy Separated{ru}Враг отделён{zh-tw}敵人已分離{zh-cn}敌人已分离{ko}적이 분리되었습니다{es}Enemigo separado{fr}Ennemi séparé{pt-br}Inimigo separado{de}Gegner getrennt}")
	end
end

--Optional combat camera support. Follow Enemy is a global Camera Control option and also drives the Black Game Master camera.
--It now uses the exact Player Board camera view directly; no camera is attached to moving enemy objects.
function combatCameraPlayerIndex(playerRef)
	if type(playerRef)=="number" then return turnOrder[playerRef]~=nil and playerRef or nil end
	if type(playerRef)~="table" then return nil end
	for playerIndex, details in pairs(turnOrder) do
		if details==playerRef or (playerRef.mage~=nil and details.mage==playerRef.mage) then return playerIndex end
	end
	return nil
end

--Resolve the same Player Board view used by the Camera Control button.
--Normal colours resolve from their hand/seat; Black always views the current Mage Knight.
function cameraControlPlayerBoardView(color)
	if color==nil or color=="Grey" or Player[color]==nil then return nil end
	local hand=color~="Black" and Player[color].getHandTransform() or nil
	for turn, details in pairs(turnOrder) do
		local match=(color=="Black" and turn==gStates.turnNumber) or
			(color~="Black" and hand~=nil and details.seatPos==math.ceil((hand.position[1]+97.59)/40))
		if match then
			local board=details.playerBoardGUID~=nil and getObjectFromGUID(details.playerBoardGUID) or nil
			if board==nil then return nil end
			local pos=board.getPosition()
			return {position={pos[1]+4,0,pos[3]-1}, pitch=gStates.cameraControlTopDown or 75, yaw=0, distance=27}
		end
	end
	return nil
end

--Avatar drops can immediately begin a Keep/Mage Tower assault before addAvatarButtons has refreshed
--the new hex. Resolve nearby optional Rampagers directly so Follow Enemy does not pull the camera away
--before the player has had a chance to add one to that combat.
function combatNearbyRampagerChoice(playerIndex)
	local details=turnOrder[playerIndex]
	if details==nil or gStates.preEndTurn==true or details.combatIconHide=="Both" then return false end
	local turnToken=getObjectFromGUID(details.turnOrderTokenGUID)
	if turnToken==nil or turnToken.is_face_down==true then return false end
	local avatar=mageKnightAvatarPositionByName(details.mage)
	if avatar==nil or avatar[1]==nil then return false end
	local mapSpatial=runtimeMapSpatialSnapshot()
	for _,obj in ipairs(runtimeMapSpatialNearbyObjects(mapSpatial,avatar,5.1)) do
		if gStates.rampagingMonsters~=nil and gStates.rampagingMonsters[obj.guid]==true then
			local pos=mapSpatial.positions[obj.guid] or obj.getPosition()
			local distance=((pos[1]-avatar[1])^2)+((pos[3]-avatar[3])^2)
			if distance<9.61 or (distance<26.01 and gStates.ambushingMonsters~=nil and gStates.ambushingMonsters[obj.guid]~=nil) then return true end
		end
	end
	return false
end

--Count the attack choices that are actually being offered right now rather than duplicating all of
--addAvatarButtons' legality rules. IDs are de-duplicated because an Avatar UI can be mirrored onto its
--model/token/standee representation.
function combatAttackOptionCount(playerIndex)
	if turnOrder[playerIndex]==nil then return 0 end
	local cached=combatAttackOptionCounts~=nil and (combatAttackOptionCounts[playerIndex] or 0) or 0
	local cachedHorse=combatAttackHorsemanOptionCounts~=nil and (combatAttackHorsemanOptionCounts[playerIndex] or 0) or 0
	local liveHorse=#horsemanAttackOptions(playerIndex)
	return math.max(0,cached-cachedHorse)+liveHorse
end

--Resolve the current player's nearby conquest/ownership marker for Rewards Claimed checks.
function rewardNearbyOwnShield(playerIndex,avatarLocation)
	local details=turnOrder[playerIndex]
	if details==nil then return "false" end
	avatarLocation=avatarLocation or details.avatarLocation or ""
	local avPos=mageKnightAvatarPosition(playerIndex) or {}
	if avPos[1]==nil or avPos[3]==nil then return "false" end
	if (gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz" or gStates.gameScenario=="Volkare's Quest" or gStates.gameScenario=="The War of Four") and gStates.volkareModel~=nil then
		local volkareObj=getObjectFromGUID(gStates.volkareModel)
		if volkareObj~=nil then
			local volkarePos=volkareObj.getPosition()
			if math.sqrt(((volkarePos[1]-avPos[1])^2)+((volkarePos[3]-avPos[3])^2))<1 then return volkare.model end
		end
	end
	if avatarLocation:sub(1,4)=="city" or avatarLocation=="Volkare's Camp" or avatarLocation=="necropolis" or avatarLocation=="hidden valley" then
		refreshCityDefeatState()
		for zone,citySearch in pairs(cityScriptZones) do
			local scriptZone=getObjectFromGUID(zone)
			if scriptZone~=nil then
				for _,detail in pairs(scriptZone.getObjects()) do
					for _,avatar in pairs(mageKnights) do
						if detail.guid==avatar.model or detail.guid==avatar.standee or detail.guid==avatar.token then
							if zone==volkare.discZone and (gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz" or gStates.gameScenario=="Volkare's Quest" or gStates.gameScenario=="The War of Four") then
								return volkare.model
							end
							return citySearch.cityGUID
						end
					end
				end
			end
		end
	end
	local mapSpatial=runtimeMapSpatialSnapshot()
	for _,shieldCheck in ipairs(runtimeMapSpatialNearbyObjects(mapSpatial,avPos,1)) do
		if ((shieldCheck.getName()=="Shield" and volkarePursuitShieldRegistered(shieldCheck)~=true and shieldCheck.getDescription()==details.mage) or
			shieldCheck.getName()=="Hidden Valley" or shieldCheck.getName()=="Necropolis" or shieldCheck.getName()=="Volkare's Camp" or shieldCheck.getName()=="Volkare" or
			shieldCheck.getGMNotes()=="White City" or shieldCheck.getGMNotes()=="Red City" or shieldCheck.getGMNotes()=="Green City" or shieldCheck.getGMNotes()=="Blue City") then
			local shieldPos=mapSpatial.positions[shieldCheck.guid] or shieldCheck.getPosition()
			if math.sqrt(((shieldPos[1]-avPos[1])^2)+((shieldPos[3]-avPos[3])^2))<1 then return shieldCheck.guid end
		end
	end
	return "false"
end

--Mandatory retreat is a soft Rewards Claimed lock. Keep this detection shared with the checklist so
--the warning and reminder cannot disagree about whether the player still needs to leave an unsafe site.
function rewardRetreatRequired(playerIndex,avatarLocation,nearbyOwnShield)
	local details=turnOrder[playerIndex]
	if details==nil or gStates.turnForfeited==true then return false end
	avatarLocation=avatarLocation or details.avatarLocation or ""
	nearbyOwnShield=nearbyOwnShield or rewardNearbyOwnShield(playerIndex,avatarLocation)
	local coopLeaderCombat=gStates.coopAssaultPhase=="combat" and coopAssaultTargetType()=="leader"
	local leaderDefeatedPendingCleanup=false
	local factionLeaderDefeated=false
	if avatarLocation=="necropolis" or avatarLocation=="hidden valley" then
		local currentLeader=avatarLocation=="necropolis" and darkCrusader or elementalist
		local leaderLevel=avatarLocation=="necropolis" and gStates.darkCrusaderLevel or gStates.elementalistLevel
		factionLeaderDefeated=(leaderLevel or 1)<=0 or
			(gStates.cityMonsterQty[currentLeader.terrainHex]~=nil and gStates.cityMonsterQty[currentLeader.terrainHex][currentLeader.token]=="dead") or
			(gStates.defeatedFactionTest~=nil and gStates.defeatedFactionTest[currentLeader.terrainHex]=="Beat")
		local leaderObj=getObjectFromGUID(currentLeader.token)
		if factionLeaderDefeated==false and leaderObj~=nil and leaderObj.is_face_down==false and leaderLevel~=nil and ((gStates.leaderReduction or 0)+(gStates.leaderOverkill or 0))>=leaderLevel then
			local playArea=getObjectFromGUID(playerPlayAreas[details.seatPos])
			if playArea~=nil then
				for _,obj in pairs(playArea.getObjects()) do if obj.guid==currentLeader.token then leaderDefeatedPendingCleanup=true break end end
			end
		end
	end
	local dragonRetreatRequired=false
	if gStates.apocalypseDragonDefeated~=true and apocalypseDragonLairContainsPosition~=nil then
		local dragonAvatarPos=mageKnightAvatarPosition(playerIndex)
		dragonRetreatRequired=dragonAvatarPos~=nil and apocalypseDragonLairContainsPosition(dragonAvatarPos)==true
	end
	return dragonRetreatRequired==true or
		((avatarLocation=="keep" or avatarLocation=="mage tower") and nearbyOwnShield=="false") or
		((avatarLocation:sub(1,4)=="city" or avatarLocation=="Volkare's Camp") and gStates.friendlyCity[nearbyOwnShield]~=true and
			((gStates.gameScenario~="The Lost Relic Blitz" and gStates.defeatedCities[nearbyOwnShield]~=true) or (gStates.gameScenario=="The Lost Relic Blitz" and nearbyOwnShield=="false"))) or
		((avatarLocation=="necropolis" or avatarLocation=="hidden valley") and coopLeaderCombat==false and leaderDefeatedPendingCleanup==false and factionLeaderDefeated==false) or
		(nearbyOwnShield==volkare.model)
end

function cameraControlPresetView(id)
	local pitch=gStates.cameraControlTopDown or 75
	local presets={
		offerView={position={32.0,0,-13.35},pitch=pitch,yaw=0,distance=30},
		questView={position={55.24,0.98,8.06},pitch=pitch,yaw=0,distance=27},
	}
	return presets[id]
end

--Rewards Claimed reminders use the same Follow Enemy opt-out as automatic combat camera movement.
--Move the clicking player's camera, plus Black when it is being used as the seated Game Master view.
function rewardReminderCameraFocus(playerColor,id)
	if gStates.cameraFollowEnemy~=true then return false end
	local view=cameraControlPresetView(id)
	if view==nil then return false end
	local function focus(color)
		if color==nil or color=="Grey" or Player[color]==nil or Player[color].seated~=true then return end
		Player[color].lookAt(view)
	end
	focus(playerColor)
	if playerColor~="Black" then focus("Black") end
	return true
end

function combatCameraFocus(playerRef)
	if gStates.cameraFollowEnemy~=true then return end
	local playerIndex=combatCameraPlayerIndex(playerRef)
	if playerIndex==nil then return end
	if combatCameraChoiceSuppressedPlayer==playerIndex then return end
	local color=positionToColor(playerIndex)
	local function focusViewer(viewColor)
		if viewColor==nil or viewColor=="Grey" or Player[viewColor]==nil then return end
		local view=cameraControlPlayerBoardView(viewColor)
		if view~=nil then Player[viewColor].lookAt(view) end
	end
	focusViewer(color)
	--Black is the intended multi-hand/Game Master view. Give it the same Player Board jump as its Camera Control button.
	if color~="Black" and Player["Black"]~=nil and Player["Black"].seated==true then focusViewer("Black") end
end

function attackLocation(playerDud, mouseButton, id)
	if mouseButton=="-1" then
		if turnOrder[gStates.turnNumber].mage~=gStates.positionMageKnight[5] or (id:sub(1,6)=="Volkar" and id~="VolkareAttack") then
			if id=="VolkareAttack" then id="Volkar"..turnOrder[gStates.turnNumber].mage end
			for playerIndex, player in pairs(turnOrder) do
				if player.mage==id:sub(7, string.len(id)) then
					--If the map is still offering another legal attack, keep the camera on the map while the
					--player decides which fight they actually want. Adventure Site combat cannot pull in
					--neighbouring enemies, so once that fight starts always follow its enemies to the board.
					local sameHexAttack=id:sub(1,6)=="Attack"
					local adventureSiteAttack=sameHexAttack and ({["monster den"]=true,["spawning grounds"]=true,maze=true,labyrinth=true,ruin=true,dungeon=true,tomb=true,ziggurat=true,pyramid=true,monastery=true})[player.avatarLocation]==true
					local nearbyRampagerChoice=sameHexAttack and adventureSiteAttack~=true and combatNearbyRampagerChoice(playerIndex)
					combatCameraChoiceSuppressedPlayer=adventureSiteAttack~=true and (combatAttackOptionCount(playerIndex)>1 or nearbyRampagerChoice==true) and playerIndex or nil
					--Work out clicking avatar location
					local avPos=mageKnightAvatarPositionByName(id:sub(7,string.len(id))) or {}
					local attackMapSpatial=nil
					local function attackMapSpatialView()
						if attackMapSpatial==nil then attackMapSpatial=runtimeMapSpatialSnapshot() end
						return attackMapSpatial
					end
					local clickedObj=getObjectFromGUID(id:sub(1,6))
					local rampagerAttack=clickedObj~=nil and gStates.rampagingMonsters[clickedObj.guid]==true
					local sameHexAvatarAttack=sameHexAttack
					local volkareAttack=id:sub(1,6)=="Volkar"
					if avPos[1]~=nil and rampagerAttack==false then
						assaultTargetPosition={avPos[1], avPos[2], avPos[3]}
						local _, _, _, assaultTargetFeature=terrainHexAtPosition(assaultTargetPosition)
						local fortifiedSiteAttack=sameHexAvatarAttack==true and (assaultTargetFeature=="keep" or assaultTargetFeature=="mage tower")
						--Keep and Mage Tower assaults can gain a second fortification from a printed wall,
						--so resolve the target from the map and ask when their entry side is unclear.
						if (sameHexAvatarAttack==false or fortifiedSiteAttack==true) and volkareAttack==false and wallAssaultChoiceResult==nil and wallAssaultChoiceNeeded(assaultTargetPosition)==true then
							showWallAssaultChoice("attackLocation", id)
							return
						end
					elseif avPos[1]~=nil and rampagerAttack==true then
						local target=clickedObj.getPosition()
						assaultTargetPosition={target[1], target[2], target[3]}
						if gStates.ambushingMonsters[clickedObj.guid]~=nil and monsterPugs[clickedObj.guid]~=nil and monsterPugs[clickedObj.guid].unfortified==nil
							and wallAssaultChoiceResult==nil and wallAssaultChoiceNeeded(assaultTargetPosition, avPos)==true then
							showWallAssaultChoice("rampagerAttack", id)
							return
						end
					end
					--Free Wine uses an ordinary Keep assault rather than a Quest combat. Record the actual
					--attack entry here so a failed assault can legally expose Quest 10's Fail action later.
					if sameHexAvatarAttack==true and player.avatarLocation=="keep" then apocalypseQuestFreeWineMarkAssaultStarted(playerIndex) end
					--move any monster token with the same co-ordinate as the avatar
					local ruinGUID=""
					local cityGUID=nil
					local cameraFollowed=false
					if (clickedObj==nil and id:sub(1,6)~="Volkar") or (clickedObj~=nil and (player.avatarLocation=="keep" or player.avatarLocation=="mage tower" or player.avatarLocation:sub(1,4)=="city" or player.avatarLocation=="Volkare's Camp")) then
						local horseSelection=gStates.horsemanAttackSelection
						local mapSpatial=attackMapSpatialView()
						for _, monster in ipairs(runtimeMapSpatialNearbyObjects(mapSpatial,avPos,1)) do
							local monsterPos=mapSpatial.positions[monster.guid] or monster.getPosition()
							if monsterPugs[monster.guid]~=nil then
								local horsemanName=horsemanTokenToName~=nil and horsemanTokenToName[monster.guid] or nil
								local horsemanSelected=horsemanName==nil or (horseSelection~=nil and horseSelection.player==playerIndex and horseSelection.targets~=nil and horseSelection.targets[monster.guid]==true)
								if horsemanSelected==true and math.sqrt(((monsterPos[1]-avPos[1])^2)+((monsterPos[3]-avPos[3])^2))<1 then
									local originalPos={monsterPos[1],monsterPos[2],monsterPos[3]}
									gStates.attackedMonsters[monster.guid]={originalPos, monster.getRotation()}
									if horsemanName~=nil then gStates.monsterPlayLocation[monster.guid]={originalPos[1],originalPos[2],originalPos[3]} end
									if cameraFollowed==false then combatCameraFocus(playerIndex) cameraFollowed=true end
									monster.setPositionSmooth({(player.seatPos*40)-96+gStates.monsterOffsetX, 2.5, -39-gStates.monsterOffsetZ},false,false)
									monster.setRotation({0.00, 180.00, 0.00})
									gStates.monsterOffsetX=gStates.monsterOffsetX+2.5
									if monsterPugs[monster.guid].monsters~=nil and monsterPugs[monster.guid].name=="Ruin" then ruinGUID=monster.guid end
								end
							end
							if player.avatarLocation:sub(1, 4)=="city" then
								if (monster.getGMNotes()=="Blue City" or monster.getGMNotes()=="Green City" or monster.getGMNotes()=="Red City" or monster.getGMNotes()=="White City")
									and math.sqrt(((monsterPos[1]-avPos[1])^2)+((monsterPos[3]-avPos[3])^2))<1 then
									cityGUID=monster.guid
								end
							end
						end
					end
					--The explicit selection only controls this staging pass. Wall-choice retries keep it until they reach here.
					gStates.horsemanAttackSelection=nil
					--draw monsters for ruin token if undefeated tokens don't exist.
					if ruinGUID~="" and gStates.monsterOffsetX==2.5 then
						broadcastToAll("{en}Monster Drawn to Player Board{ru}Жетон врага был помещен на стол игрока{zh-tw}怪物已移到玩家面板{zh-cn}怪物被抽到玩家面板了{ko}몬스터와 전투합니다{es}Monstruo Dibujado al Tablero del Jugador{fr}Monstre Dessiné sur le Plateau du Joueur{pt-br}Monstro Puxado para o Tabuleiro do Jogador{de}Monster auf das Spielerbrett gezogen", positionToColor(gStates.turnNumber))
						local tokenWait=0
						for _, monsterColor in pairs(monsterPugs[ruinGUID].monsters) do
							local pileGUID=monsterPiles[monsterColor]
							safeWaitFrames("Combat",function()
								withTokenPoolReady(pileGUID,function()
									local pile=getObjectFromGUID(pileGUID)
									if pile==nil or pile.getQuantity()==0 then return end
									local pilePos=pile.getPosition()
									local monster=pile.takeObject({position={(player.seatPos*40)-96+gStates.monsterOffsetX,2.5,-39-gStates.monsterOffsetZ},rotation={0.00,180.00,0.00}})
									if monster==nil then return end
									combatCameraFocus(playerIndex)
									gStates.attackedMonsters[monster.guid]={{pilePos[1],2+((tokenWait/5)/10),pilePos[3]},{0.00,0.00,0.00}}
									if gStates.ruinMonsters==nil then gStates.ruinMonsters={[monster.guid]=ruinGUID} else gStates.ruinMonsters[monster.guid]=ruinGUID end
									gStates.monsterOffsetX=gStates.monsterOffsetX+2.5
								end,"Combat")
							end,tokenWait)
							tokenWait=tokenWait+5
						end
					end
					--draw all monsters left on city card
					if clickedObj==nil and (player.avatarLocation:sub(1,4)=="city" or player.avatarLocation=="Volkare's Camp" or player.avatarLocation=="hidden valley" or player.avatarLocation=="necropolis" or id:sub(1,6)=="Volkar") then
						--figure out which city avatar is in if not dropped on the city model
						if player.avatarLocation:sub(1, 4)=="city" and cityGUID==nil then
							for zone, citySearch in pairs(cityScriptZones) do
								local zoneObj=getObjectFromGUID(zone)
								for _, detail in pairs(zoneObj~=nil and zoneObj.getObjects() or {}) do
									if detail.getName()==player.mage then
										cityGUID=citySearch.cityGUID
										break
									end
								end
							end
						end
						if player.avatarLocation=="hidden valley" then cityGUID=elementalist.terrainHex end
						if player.avatarLocation=="necropolis" then cityGUID=darkCrusader.terrainHex end
						if player.avatarLocation=="Volkare's Camp" or id:sub(1, 6)=="Volkar" then
							cityGUID=volkare.terrainHex
							if gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz" or gStates.gameScenario=="Volkare's Quest" or gStates.gameScenario=="The War of Four" then
								cityGUID=volkare.model
							end
						end
						--detect if coop assault possible
						if cityGUID~=nil and gStates.gameScenario~="The Lost Relic Blitz" then
							local cityPositionGUID=cityGUID
							if cityGUID==volkare.model and gStates.volkareModel~=nil then cityPositionGUID=gStates.volkareModel end
							local cityPositionObj=getObjectFromGUID(cityPositionGUID)
							if cityPositionObj==nil then return end
							local cityPosition=cityPositionObj.getPosition()
							local magesInRange=findNearbyMages({cityPosition[1], cityPosition[2], cityPosition[3]}, 2.5)
							if gStates.cityMonsterQty[cityGUID].extra~=nil and gStates.cityMonsterQty[cityGUID].extra.megapolisPair~=nil then
								local secondCity=getObjectFromGUID(gStates.cityMonsterQty[cityGUID].extra.megapolisPair)
								if gStates.cityMonsterQty[cityGUID].extra.megapolisPair==cityGUID then
									for secCityGuid, secDetails in pairs(gStates.cityMonsterQty) do
										if secDetails.extra.megapolisPair==cityGUID and secCityGuid~=cityGUID then
											secondCity=getObjectFromGUID(secCityGuid)
											break
										end
									end
								end
								local magesInRangeTwo=findNearbyMages({secondCity.getPosition()[1], secondCity.getPosition()[2], secondCity.getPosition()[3]}, 2.5)
								for _, mageNameTwo in pairs (magesInRangeTwo) do
									local found=false
									for _, mageName in pairs (magesInRange) do
										if mageName.mage==mageNameTwo.mage then found=true end
									end
									if found==false then magesInRange[#magesInRange+1]=mageNameTwo end
								end
							end
							local count=1
							local mcount=0
							local volkareAssignment=cityGUID==volkare.model
							gStates.coopAssaultUnassigned={primary={}, secondary={}}
							gStates.assaultData={[player.mage]={primary={}, secondary={}, UIPos={count}, joined=true}}
							for monsterGUID, state in pairs(gStates.cityMonsterQty[cityGUID]) do
								if monsterGUID~="extra" and getObjectFromGUID(monsterGUID)~=nil and state~="dead" then
									local dividable=monsterGUID~=elementalist.token and monsterGUID~=darkCrusader.token
									if dividable then mcount=mcount+1 end
									local primary=(player.avatarLocation~="Volkare's Camp" and id:sub(1, 6)~="Volkar") or ((player.avatarLocation=="Volkare's Camp" or id:sub(1, 6)=="Volkar") and (monsterPugs[monsterGUID].pugType=="green" or monsterPugs[monsterGUID].pugType=="gray"))
									local secondary=(player.avatarLocation=="Volkare's Camp" or id:sub(1, 6)=="Volkar") and (monsterPugs[monsterGUID].pugType=="red" or monsterPugs[monsterGUID].pugType=="white")
									if primary then
										local destination=volkareAssignment and dividable and gStates.coopAssaultUnassigned.primary or gStates.assaultData[player.mage].primary
										destination[#destination+1]=monsterGUID
									end
									if secondary then
										local destination=volkareAssignment and dividable and gStates.coopAssaultUnassigned.secondary or gStates.assaultData[player.mage].secondary
										destination[#destination+1]=monsterGUID
									end
								end
							end
							local cityDefense=gStates.coopAssaultMode=="defense"
							for _, mageName in pairs(magesInRange) do
								if mageName.mage~=player.mage and gStates.volkareState~="Attacking Player" then count=count+1 gStates.assaultData[mageName.mage]={primary={}, secondary={}, UIPos={count}, joined=cityDefense} end
							end
							--Volkare's shared fight can be combined even with only one army enemy; that enemy starts unassigned.
							if count>=2 and (mcount>=2 or (volkareAssignment and mcount>=1)) then
								if cityDefense~=true then gStates.coopAssaultMode="assault" end
								gStates.coopAssaultCityGUID=cityGUID
								gStates.coopAssaultLocation=player.avatarLocation
								applyColorBarButtons()
								coopAssaultUIUpdate()
							else
								--No cooperative assault is actually available. For Volkare, his army was staged in the
								--shared unassigned pools while we checked whether a combined defense was possible.
								--With only one defender, give every staged enemy back to that defender before attackCity.
								local currentAssault=gStates.assaultData[player.mage]
								if volkareAssignment==true then
									for _, army in pairs({"primary", "secondary"}) do
										for _, monsterGUID in pairs(gStates.coopAssaultUnassigned[army] or {}) do
											currentAssault[army][#currentAssault[army]+1]=monsterGUID
										end
									end
								end
								gStates.assaultData={[player.mage]=currentAssault}
								gStates.coopAssaultUnassigned={}
								gStates.coopAssaultMode=nil
								attackCity(nil,"-1",id:sub(1,6))
							end
						end
					end
					--Work out if avatar or rampage was clicked
					player.combatIconHide="Avatar"
					if id:sub(1,6)~="Volkar" then
						if getObjectFromGUID(id:sub(1,6))==nil then
							--use avatar location to draw Monsters if none exist
							if gStates.monsterOffsetX==0 then
								if (player.avatarLocation=="dungeon" or player.avatarLocation=="monster den" or player.avatarLocation=="maze"--brown
									or player.avatarLocation=="spawning grounds") and id:sub(1, 6)=="Attack" then--two browns
									broadcastToAll("{en}Monster Drawn to Player Board{ru}Жетон врага был помещен на стол игрока{zh-tw}怪物已移到玩家面板{zh-cn}怪物被抽到玩家面板了{ko}몬스터와 전투합니다{es}Monstruo Dibujado al Tablero del Jugador{fr}Monstre Dessiné sur le Plateau du Joueur{pt-br}Monstro Puxado para o Tabuleiro do Jogador{de}Monster auf das Spielerbrett gezogen", positionToColor(gStates.turnNumber))
									drawMonster(monsterPiles.tan, player, id)
									if player.avatarLocation=="spawning grounds" then safeWaitFrames("Combat",function() drawMonster(monsterPiles.tan, player, id) end, 10)	end
								end
								if player.avatarLocation=="monastery" and id:sub(1, 6)=="Attack" then drawMonster(monsterPiles.purple, player, id) broadcastToAll("{en}Monastery Defender Drawn to Player Board{ru}Жетон защитника Монастыря был помещен на стол игрока{zh-tw}修道院守軍已移到玩家面板{zh-cn}修道院驻军移到玩家面板上{ko}수도원의 수비자와 전투합니다{es}Defensor del Monasterio dibujado en el tablero del jugador{fr}Défenseur du Monastère dessiné sur le plateau du joueur{pt-br}Defensor do Monastério puxado para o tabuleiro do jogador{de}Verteidiger des Klosters auf Spielertafel gezogen", positionToColor(gStates.turnNumber)) end
								if (player.avatarLocation=="tomb" or player.avatarLocation=="labyrinth") and id:sub(1, 6)=="Attack" then drawMonster(monsterPiles.red, player, id) broadcastToAll("{en}Dragon Drawn to Player Board{ru}Жетон Драконума был помещен на стол игрока{zh-tw}巨龍已移到玩家面板{zh-cn}将龙放到玩家面板{ko}드래곤과 전투하세요{es}Dragón dibujado al tablero del jugador{fr}Dragon dessiné sur le plateau du joueur{pt-br}Dragão Puxado para o tabuleiro do jogador{de}Drache auf Spielertafel gezogen", positionToColor(gStates.turnNumber)) end
								if player.avatarLocation=="keep" and id:sub(1, 6)=="Attack" then
									local found=false
									local mapSpatial=attackMapSpatialView()
									for _, shield in ipairs(runtimeMapSpatialNearbyObjects(mapSpatial,avPos,1)) do
										local shieldPos=mapSpatial.positions[shield.guid] or shield.getPosition()
										if shield.getName()=="Shield" and volkarePursuitShieldRegistered(shield)~=true and (shield.getDescription()==player.mage or gStates.coop==1) and math.sqrt(((shieldPos[1]-avPos[1])^2)+((shieldPos[3]-avPos[3])^2))<1 then found=true break end
									end
									if found==false then drawMonster(monsterPiles.gray, player, id) broadcastToAll("{en}Keep Defender Drawn to Player Board{ru}Защитник крепости был помещен на стол игрока{zh-tw}堡壘守軍已移到玩家面板{zh-cn}保持防御者在玩家板上{ko}성의 수비자와 전투합니다{es}Mantenga al Defensor atraído al tablero del jugador{fr}Gardez le Défenseur dessiné sur le plateau du joueur{pt-br}Defensor do Forte puxado para o tabuleiro do jogador{de}Verteidiger auf Spielerbrett gezogen halten", positionToColor(gStates.turnNumber)) end
								end
								if (player.avatarLocation=="ziggurat" or player.avatarLocation=="pyramid") then
									--update Interface to be fresh and match the location.
									gStates.zigguratPyramidFightFloor=nil
									UI.setAttribute("zigguratPyramidInteractClimb1", "interactable", "true")
									UI.setAttribute("zigguratPyramidInteractClimb2", "interactable", "false")
									UI.setAttribute("zigguratPyramidInteractFight1", "interactable", "true")
									UI.setAttribute("zigguratPyramidInteractFight2", "interactable", "false")
									UI.setAttribute("zigguratPyramidInteractFight3", "interactable", "false")
									UI.setAttribute("zigguratPyramidInteractFight1Image", "color", "White")
									UI.setAttribute("zigguratPyramidInteractFight2Image", "color", "Gray")
									UI.setAttribute("zigguratPyramidInteractFight3Image", "color", "Gray")
									UI.setAttribute("zigguratPyramidInteractClimb1Image", "color", "White")
									UI.setAttribute("zigguratPyramidInteractClimb2Image", "color", "Gray")
									UI.setAttribute("zigguratPyramidInteractText1", "text", "{en}Ziggurat Interaction{ru}Взаимодействие с зиккуратом{zh-tw}階梯神廟互動{zh-cn}阶梯神庙互动{ko}지구라트 상호작용{es}Interacción con el zigurat{fr}Interaction avec la ziggourat{pt-br}Interação com a Zigurate{de}Zikkurat-Interaktion")
									UI.setAttribute("zigguratPyramidInteractText2", "text", "{en}Entered Floor 1. Pick one of the three Trap Tokens\nto Deal with. Then either:-{ru}Вышли на 1-й этаж. Выберите один из трёх жетонов ловушки,\nс которым нужно разобраться. Затем либо:—{zh-tw}進入第一層，從三個陷阱中，處理其中一個。 \n然後選擇：{zh-cn}进入第一层，从三个陷阱中，处理其中一个。 \n然后选择：{ko}1층에 진입했습니다. 3개의 함정 중 하나 선택하여 방어.\n그 후 다음 중 선택:-{es}Has entrado en la planta 1. Elige una de las tres fichas de trampa\ncon las que quieres lidiar. A continuación, puedes: -{fr}Entrée au 1er étage. Choisissez l'un des trois jetons 'Piège'\nà gérer. Ensuite, vous pouvez soit : -{pt-br}Entrou no 1º andar. Escolha uma das três fichas de armadilha\npara lidar com ela. Em seguida, faça uma das seguintes opções:-{de}Du betrittst Etage 1. Wähle einen der drei Fallenzettel aus,\nmit dem du dich befassen möchtest. Dann entweder:-")
									UI.setAttribute("zigguratPyramidInteractClimb1Text", "text", "{en}Ascend to Floor 2 and Pick one of two Trap Tokens to Deal with.{ru}Поднимитесь на 2-й этаж и выберите один из двух жетонов ловушки, с которым нужно разобраться.{zh-tw}前往第二層，\n從兩個陷阱中，\n處理其中一個。{zh-cn}前往第二层，\n从两个陷阱中，\n处理其中一个。{ko}2층 등반 후 2개의 함정 중 하나 선택하여 방어{es}Subir a la planta 2 y elegir una de las dos fichas de trampa con las que enfrentarte.{fr}Monter au niveau 2 et choisir l'un des deux jetons de piège à éliminer.{pt-br}Subir para o 2º andar e escolher uma das duas fichas de armadilha para lidar.{de}Steige zu Etage 2 auf und wähle einen der beiden Fallenzettel aus, um ihn zu bewältigen.")
									UI.setAttribute("zigguratPyramidInteractFight1Text", "text", "{en}Fight the Floor 1 Apocalypse Possessed Green Enemy for 2 random Crystals.{ru}Сразитесь с зеленым врагом, одержимым Апокалипсисом, на 1-м этаже, чтобы получить 2 случайных кристалла.{zh-tw}擊敗第一層的末日附身\n綠色敵人，獲得兩顆隨機\n魔晶。{zh-cn}击败第一层的末日附身\n绿色敌人，获得两颗随机\n魔晶。{ko}1층의 '빙의된 아포칼립스' 녹색 적과 전투,  보상: 무작위 수정 2개{es}Lucha contra el enemigo verde poseído por el Apocalipsis del piso 1 para conseguir 2 cristales aleatorios.{fr}Combattez l'ennemi vert possédé par l'Apocalypse du niveau 1 pour obtenir 2 cristaux aléatoires.{pt-br}Lute contra o inimigo verde possuído pelo Apocalipse do 1º andar para ganhar 2 cristais aleatórios.{de}Bekämpfe den von der Apokalypse besessenen grünen Gegner auf Etage 1 für 2 zufällige Kristalle.")
									UI.setAttribute("zigguratPyramidInteractClimb2Text", "text", "{en}Ascend to Floor 3 and Deal with the last Trap Token.{ru}Поднимитесь на 3-й этаж и разберитесь с последним жетоном ловушки.{zh-tw}前往第三層，\n處理最後一個\n陷阱。{zh-cn}前往第三层，\n处理最后一个\n陷阱。{ko}3층 등반 후 함정 1개 방어{es}Sube al piso 3 y ocúpate de la última ficha de trampa.{fr}Montez au niveau 3 et occupez-vous du dernier jeton Piège.{pt-br}Suba para o 3º andar e lide com a última ficha de armadilha.{de}Steige zu Etage 3 auf und kümmere dich um den letzten Fallenzettel.")
									UI.setAttribute("zigguratPyramidInteractFight2Text", "text", "{en}Fight the Floor 2 Apocalypse Possessed Purple Enemy for a Spell.{ru}Сразитесь с фиолетовым врагом, одержимым Апокалипсисом, на 2-м этаже, чтобы получить заклинание.{zh-tw}擊敗第二層的末日附身\n紫色敵人，獲得一張法術{zh-cn}击败第二层的末日附身\n紫色敌人，获得一张法术{ko}2층의 '빙의된 아포칼립스' 보라색 적과 전투, 보상: 마법 카드{es}Lucha contra el enemigo morado poseído por el Apocalipsis del piso 2 para conseguir un hechizo.{fr}Combattez l'ennemi violet possédé par l'Apocalypse du niveau 2 pour obtenir un sort.{pt-br}Lute contra o inimigo roxo possuído pelo Apocalipse do 2º andar para ganhar um feitiço.{de}Bekämpfe den von der Apokalypse besessenen violetten Gegner auf Etage 2 für einen Zauber.")
									UI.setAttribute("zigguratPyramidInteractFight3Text", "text", "{en}Fight the Floor 3 Apocalypse Possessed Tan Enemy for an Artifact.{ru}Сразитесь с коричневым врагом, одержимым Апокалипсисом, на 3-м этаже, чтобы получить артефакт.{zh-tw}擊敗第三層的末日附身棕色敵人，獲得一件神器。{zh-cn}击败第三层的末日附身棕色敌人，获得一件神器。{ko}3층의 ‘빙의된 아포칼립스'  갈색 적과 전투, 보상: 유물{es}Lucha contra el enemigo marrón claro poseído por el Apocalipsis del piso 3 para conseguir un artefacto.{fr}Combattez l'ennemi beige possédé par l'Apocalypse de l'étage 3 pour obtenir un artefact.{pt-br}Lute contra o inimigo bege possuído pelo Apocalipse do Piso 3 para ganhar um artefato.{de}Kämpfe gegen den apokalypsebesessenen hellbraunen Gegner auf Etage 3 um ein Artefakt.")
									if player.avatarLocation=="pyramid" then
										UI.setAttribute("zigguratPyramidInteractText1", "text", "{en}Pyramid Interaction{ru}Взаимодействие с пирамидой{zh-tw}金字塔互動{zh-cn}金字塔互动{ko}피라미드 상호작용{es}Interacción con la pirámide{fr}Interaction avec la pyramide{pt-br}Interação com a Pirâmide{de}Pyramiden-Interaktion")
										UI.setAttribute("zigguratPyramidInteractFight1Text", "text", "{en}Fight the Floor 1 Apocalypse Possessed Gray Enemy for 2 Crystals of your choice.{ru}Сразитесь с серым врагом, одержимым Апокалипсисом, на 1-м этаже, чтобы получить 2 кристалла на ваш выбор.{zh-tw}擊敗第一層的末日附身\n灰色敵人，獲得兩顆任意\n魔晶。{zh-cn}击败第一层的末日附身\n灰色敌人，获得两颗任意\n魔晶。{ko}1층의 ‘빙의된 아포칼립스’ 회색 적과 전투, 보상: 선택 수정 2개 {es}Lucha contra el enemigo gris poseído por el Apocalipsis del piso 1 para conseguir 2 cristales de tu elección.{fr}Combattez l'ennemi gris possédé par l'Apocalypse de l'étage 1 pour obtenir 2 cristaux de votre choix.{pt-br}Lute contra o inimigo cinza possuído pelo Apocalipse do Piso 1 para ganhar 2 cristais à sua escolha.{de}Kämpfe gegen den apokalypsebesessenen grauen Gegner auf Etage 1 um 2 Kristalle deiner Wahl.")
										UI.setAttribute("zigguratPyramidInteractFight2Text", "text", "{en}Fight the Floor 2 Apocalypse Possessed White Enemy for a Spell & 2 Crystals of your choice.{ru}Сразитесь с белым врагом, одержимым Апокалипсисом, на 2-м этаже, чтобы получить заклинание и 2 кристалла на ваш выбор.{zh-tw}擊敗第二層的末日附身\n白色敵人，獲得一張法術\n和兩顆任意魔晶。{zh-cn}击败第二层的末日附身\n白色敌人，获得一张法术\n和两颗任意魔晶。{ko}2층의 ‘빙의된 아포칼립스’ 흰색 적과 전투, 보상: 마법 1장과 선택 수정 2개{es}Lucha contra el enemigo blanco poseído por el Apocalipsis del piso 2 para conseguir un hechizo y 2 cristales de tu elección.{fr}Combattez l'ennemi blanc possédé par l'Apocalypse de l'étage 2 pour obtenir un sort et 2 cristaux de votre choix.{pt-br}Lute contra o inimigo branco possuído pelo Apocalipse do Piso 2 para ganhar um feitiço e 2 cristais à sua escolha.{de}Kämpfe gegen den apokalypsebesessenen weißen Gegner auf Etage 2 um einen Zauber und 2 Kristalle deiner Wahl.")
										UI.setAttribute("zigguratPyramidInteractFight3Text", "text", "{en}Fight the Floor 3 Apocalypse Possessed Red Enemy for an Artifact & 2 Crystals of your choice.{ru}Сразитесь с красным врагом, одержимым Апокалипсисом, на 3-м этаже, чтобы получить артефакт и 2 кристалла на ваш выбор.{zh-tw}擊敗第三層的末日附身紅色敵人，\n獲得一件神器和兩顆任意魔晶。{zh-cn}击败第三层的末日附身红色敌人，\n获得一件神器和两颗任意魔晶。{ko}3층의 ‘빙의된 아포칼립스’ 적색 적과 전투, 보상: 유물 1장과 선택 수정 2개{es}Lucha contra el enemigo rojo poseído por el Apocalipsis del piso 3 para conseguir un artefacto y 2 cristales de tu elección.{fr}Combattez l'ennemi rouge possédé par l'Apocalypse de l'étage 3 pour obtenir un artefact et 2 cristaux de votre choix.{pt-br}Lute contra o inimigo vermelho possuído pelo Apocalipse do Piso 3 para ganhar um artefato e 2 cristais à sua escolha.{de}Kämpfe gegen den apokalypsebesessenen roten Gegner auf Etage 3 um ein Artefakt und 2 Kristalle deiner Wahl.")
									end
									--check for existing shields and lock off buttons.
									local avPos=mageKnightAvatarPosition(gStates.turnNumber) or {}
									local terrain, _, sitePos=terrainHexAtPosition(avPos)
									if sitePos~=nil then avPos=sitePos else avPos[3]=(math.floor(((avPos[3]-1)/2.0785)+0.5)*2.0785)+0.5 end
									local fight2Done, fight3Done=false, false
									local mapSpatial=attackMapSpatialView()
									for _, shieldCheck in ipairs(runtimeMapSpatialNearbyObjects(mapSpatial,avPos,1.5)) do
										local shieldPos=mapSpatial.positions[shieldCheck.guid] or shieldCheck.getPosition()
										if shieldCheck.getName()=="Shield" and volkarePursuitShieldRegistered(shieldCheck)~=true and math.sqrt(((shieldPos[1]-avPos[1])^2)+((shieldPos[3]-avPos[3])^2))<1.5 then
											local floor=zigguratPyramidFloorFromPosition(terrain,avPos,shieldPos)
											if floor==1 then
												UI.setAttribute("zigguratPyramidInteractFight1Image", "color", "Red")
												UI.setAttribute("zigguratPyramidInteractFight1", "interactable", "false")
											elseif floor==3 then
												UI.setAttribute("zigguratPyramidInteractFight3Image", "color", "Red")
												UI.setAttribute("zigguratPyramidInteractClimb2Image", "color", "Red")
												UI.setAttribute("zigguratPyramidInteractFight3", "interactable", "false")
												UI.setAttribute("zigguratPyramidInteractClimb2", "interactable", "false")
												fight3Done=true
											else
												UI.setAttribute("zigguratPyramidInteractFight2Image", "color", "Red")
												UI.setAttribute("zigguratPyramidInteractFight2", "interactable", "false")
												fight2Done=true
											end
										end
									end
									if fight3Done==true and fight2Done==true then
										UI.setAttribute("zigguratPyramidInteractClimb1Image", "color", "Red")
										UI.setAttribute("zigguratPyramidInteractClimb1", "interactable", "false")
									end
									UI.setAttribute("zigguratPyramidInteract", "active", "true")
									--deploy three trap tokens.
									local trapBag=monsterPiles.pyramidTrap
									if player.avatarLocation=="ziggurat" then trapBag=monsterPiles.zigguratTrap end
									drawMonster(trapBag, player, id)
									safeWaitFrames("Combat",function() drawMonster(trapBag, player, id) end, 10)
									safeWaitFrames("Combat",function() drawMonster(trapBag, player, id) end, 10)
								end
							end
							--Hide button
							if player.avatarLocation~="keep" and player.avatarLocation~="mage tower" and player.avatarLocation:sub(1, 4)~="city" and player.avatarLocation~="Volkare's Camp" and player.avatarLocation~="hidden valley" and player.avatarLocation~="necropolis" then player.combatIconHide="Both" end
							locationAttacked=true
							if gStates.coopAssaultCityGUID==nil and assaultTargetHasWall(assaultTargetPosition)==true then
								local wallFortified=resolveAssaultWallFortified(assaultTargetPosition, assaultApproachOrigin, true)
								safeWaitFrames("Combat",function() applyCurrentAssaultWallFortified(wallFortified) end, 15)
							end
						else
							--Rampager attacks are not assaults: the avatar stays put, so adjacent wall crossing is always known.
							--Only an Ambushing Rampager attacked from its extended range can need the manual wall answer above.
							local rampagerGUID=id:sub(1,6)
							local rampager=getObjectFromGUID(rampagerGUID)
							local target=rampager.getPosition()
							local rampagerTargetPos={target[1], target[2], target[3]}
							local wallFortified=resolveAssaultWallFortified(rampagerTargetPos, avPos, true)
							gStates.attackedMonsters[rampagerGUID]={rampager.getPosition(), rampager.getRotation()}
							setAssaultWallFortified(rampager, wallFortified)
							if cameraFollowed==false then combatCameraFocus(playerIndex) cameraFollowed=true end
							rampager.setPositionSmooth({(player.seatPos*40)-96+gStates.monsterOffsetX, 2.5, -39-gStates.monsterOffsetZ},false,false)
							settleAssaultWallFortified(rampagerGUID, wallFortified)
							rampager.setRotation({0.00, 180.00, 0.00})
							safeWaitFrames("Combat",function() local obj=getObjectFromGUID(rampagerGUID) if obj~=nil then obj.UI.setXmlTable({{}}) end end, 10)
							gStates.monsterOffsetX=gStates.monsterOffsetX+2.5
							locationAttacked=false
							clearWallAssaultChoice()
							assaultTargetPosition=nil
						end
					end
					addAvatarButtons()
					break
				end
			end
		else
			broadcastToAll("{en}Flip the Turn Order token of the Mage Knight who Volkare is attacking, and finish Volkare's turn.\n(If not fully Attending the battle, manually move his tokens){ru}Переверните жетон порядка хода Героя, которого атакует Волкар, и завершите ход Волкара\n(Если вы не используете долгую подготовку к битве, вручную переместите его жетоны){zh-tw}翻轉沃卡里正在攻擊的魔法騎士之回合順序標記，並完成沃卡里的回合。\n（若未完整參與戰鬥，請手動移動他的標記）{zh-cn}翻转沃卡里正在攻击的玩家的顺位板，并完成沃卡里的回合\n（如果没有完成，请手动移动他的标记）{ko}볼케어가 공격하는 플레이어의 라운드 순서 토큰을 뒤집고, 볼케어의 차례를 종료합니다.\n(부분적인 전투 참여의 경우 직접 뒤집으세요.){es}Da la vuelta a la ficha de Orden de turno del Caballero mago que Volkare está atacando y termina el turno de Volkare.\n(Si no asiste por completo a la batalla, mueva manualmente sus fichas){fr}Retournez le jeton Ordre du Tour du Chevalier Mage que Volkare attaque et terminez le tour de Volkare\n(Si vous n'assistez pas complètement à la bataille, déplacez manuellement ses jetons){pt-br}Vire a ficha de ordem de turno do Mage Knight que Volkare está atacando, e termine o Turno de Volkare\n(Se não estiver Atendendo por completo a batalha, então manualmente mova suas fichas){de}Drehe das Zugreihenfolgeplättchen des Magierritters, den Volkare angreift, um und beende Volkares Zug.\n(Wenn er nicht vollständig am Kampf teilnimmt, verschiebe seine Spielsteine manuell)", warningColor)
		end
	end
end

function drawMonster(color, player, id, possessedFaction)
	local drawID=tostring(id or "")
	local volkarePursuitDraw=drawID:sub(1,7)=="VPDraw|"
	local function takeDraw()
		local pile=getObjectFromGUID(color)
		if pile==nil or pile.getQuantity()==0 then
			broadcastToAll("{en}Sorry, there are no tokens left to deploy{ru}Извините, жетонов для размещения больше не осталось.{zh-tw}抱歉，沒有可部署的標記了。{zh-cn}抱歉，没有token可供部署{ko}여분의 토큰이 없습니다{es}Lo sentimos, no quedan tokens para implementar{fr}Désolé, il n'y a plus de jetons à déployer{pt-br}Desculpe, Não tem Fichas sobrando para distribuir{de}Entschuldigung, es sind keine Marker mehr zum Platzieren übrig.",warningColor)
			return
		end
		local monsterDrawn=pile.takeObject({position={(player.seatPos*40)-96+gStates.monsterOffsetX,2.5,-39-gStates.monsterOffsetZ},rotation={0.00,180.00,0.00}})
		if monsterDrawn==nil then return end
		if color==monsterPiles.possessed and possessedFaction~=nil then
			if gStates.apocalypsePossessedFactionByToken==nil then gStates.apocalypsePossessedFactionByToken={} end
			gStates.apocalypsePossessedFactionByToken[monsterDrawn.guid]=possessedFaction
		end
		if color~=monsterPiles.pyramidTrap and color~=monsterPiles.zigguratTrap then
			local pilePos=pile.getPosition()
			local returnPos={pilePos[1],2,pilePos[3]}
			gStates.attackedMonsters[monsterDrawn.guid]={returnPos,{0.00,0.00,0.00}}
			if volkarePursuitDraw==true then
				gStates.volkarePursuitEnemies[monsterDrawn.guid]=true
				--Pursuit enemies are spent once drawn: defeated or not, end-turn cleanup sends them to
				--their normal discard bag. Do not give them a map/source return location. Defeated
				--Shades of Tezla enemies still pass through discardMonster(..., true), so their native
				--faction reward token is awarded normally; face-down undefeated enemies get no reward.
				gStates.monsterPlayLocation[monsterDrawn.guid]=nil
				if gStates.volkarePursuitCombat~=nil then gStates.volkarePursuitCombat.monsters[monsterDrawn.guid]=true end
			end
			combatCameraFocus(player)
		end
		monsterDrawn.setDecals({})
		if color~=monsterPiles.possessed then
			gStates.monsterOffsetX=gStates.monsterOffsetX+2.5
			if gStates.monsterOffsetX>12 then gStates.monsterOffsetX=0 gStates.monsterOffsetZ=gStates.monsterOffsetZ+2.5 end

			--add no units and night rules Decals
			safeWaitTime("Combat",function()
				if drawID:sub(1,6)~="Incant" and volkarePursuitDraw~=true then
					if player.avatarLocation=="dungeon" or player.avatarLocation=="tomb" or player.avatarLocation=="monastery" or player.avatarLocation=="ziggurat" or player.avatarLocation=="pyramid" then
						monsterDrawn.addDecal({name="NoUnits", position={-0.85, 0.15, -0.85}, rotation={90, 180, 0}, scale={0.4, 0.6, 1}, url="https://steamusercontent-a.akamaihd.net/ugc/12623966286982295316/7CFECB9A34CA9DBEBB8A04DC44B488E56360781B/"})
						if gStates.monsterPerks[monsterDrawn.guid]==nil then gStates.monsterPerks[monsterDrawn.guid]={noUnits=true} else gStates.monsterPerks[monsterDrawn.guid].noUnits=true end
					end
					if player.avatarLocation=="maze" or player.avatarLocation=="labyrinth" then
						monsterDrawn.addDecal({name="OneUnit", position={-0.85, 0.15, -0.85}, rotation={90, 180, 0}, scale={0.4, 0.6, 1}, url="https://steamusercontent-a.akamaihd.net/ugc/10559851086144974805/566B77BBAB91B7B7B5848E26BE14B17F4B96F44F/"})
						if gStates.monsterPerks[monsterDrawn.guid]==nil then gStates.monsterPerks[monsterDrawn.guid]={oneUnit=true} else gStates.monsterPerks[monsterDrawn.guid].oneUnit=true end
					end
					if player.avatarLocation=="dungeon" or player.avatarLocation=="tomb" or player.avatarLocation=="graveyard" or player.avatarLocation=="necropolis" then
						monsterDrawn.addDecal({name="NightRules", position={0.85, 0.15, -0.85}, rotation={90, 180, 0}, scale={0.6, 0.6, 1}, url=nightRulesDecal})
						if gStates.monsterPerks[monsterDrawn.guid]==nil then gStates.monsterPerks[monsterDrawn.guid]={nightRules=true} else gStates.monsterPerks[monsterDrawn.guid].nightRules=true end
					end
				end
			end, 0.5)
		end
	end
	withTokenPoolReady(color,takeDraw,"Combat")
end

--Move armies and garrisons to player boards
function attackCity(player, mouseButton, id)
	if mouseButton=="-1" then
		local coopStart=id=="startAssault"
		local coopDefense=coopStart==true and gStates.coopAssaultMode=="defense"
		local wallTargetPos=assaultTargetPosition
		local coopTarget=coopStart==true and gStates.coopAssaultCityGUID~=nil and getObjectFromGUID(gStates.coopAssaultCityGUID) or nil
		if coopTarget~=nil then
			local target=coopTarget.getPosition()
			wallTargetPos={target[1],target[2],target[3]}
		end
		local startAssaultType=coopStart==true and coopAssaultTargetType() or nil
		--Dragon heads are not city defenders and never gain printed wall fortification from the
		--lair hex. The three Dragon spaces keep their normal terrain but the Dragon combat itself
		--uses only the heads' printed abilities.
		if startAssaultType=="dragon" then wallTargetPos=nil end
		local wallTargetHasWall=wallTargetPos~=nil and assaultTargetHasWall(wallTargetPos)==true
		if coopStart==true then
			if coopAssaultReadyToBegin()==false then coopAssaultUIUpdate() return end
			local participants=0
			for _, assignedMonsters in pairs(gStates.assaultData) do
				if assignedMonsters.joined==true then participants=participants+1 end
				if #assignedMonsters.secondary>=1 then id="111111" end
			end
			if wallTargetHasWall==true and wallAssaultChoiceResult==nil and wallAssaultChoiceNeeded(wallTargetPos)==true then
				UI.hide("CoopAssault")
				showWallAssaultChoice("attackCity", "startAssault")
				return
			end
			if participants>=2 then
				gStates.coopAssaultPhase="combat" gStates.coopRewardQueue={} gStates.coopRewardIndex=1 gStates.coopAssaultParticipants={} gStates.coopAssaultScenarioEndPending=false
				gStates.coopAssaultType=startAssaultType
				gStates.coopAssaultInitiator=gStates.turnNumber
				local leadMage=turnOrder[gStates.turnNumber].mage
				local cityAssault=gStates.coopAssaultType=="city"
				local volkareAssault=gStates.coopAssaultType=="volkare"
				local horsemenAssault=gStates.coopAssaultType=="horsemen"
				local dragonAssault=gStates.coopAssaultType=="dragon"
				for playerIndex, playerData in pairs(turnOrder) do
					local assigned=gStates.assaultData[playerData.mage]
					if assigned~=nil and assigned.joined==true and (playerData.mage~=leadMage or cityAssault or volkareAssault or horsemenAssault or dragonAssault) then
						local avatar=coopAssaultAvatarObject(playerIndex)
						if playerData.mage~=leadMage and avatar~=nil then refreshAvatarLocationOnly(playerIndex, avatar) end
						local assaultFromPosition=avatar~=nil and avatar.getPosition() or nil
						if playerData.mage==leadMage and assaultApproachOrigin~=nil then assaultFromPosition={assaultApproachOrigin[1], assaultApproachOrigin[2], assaultApproachOrigin[3]} end
						local original={avatarLocation=playerData.avatarLocation,avatarSharedHex=playerData.avatarSharedHex,avatarSwapCity=playerData.avatarSwapCity,position=avatar~=nil and avatar.getPosition() or nil,assaultFromPosition=assaultFromPosition,lead=playerData.mage==leadMage}
						if horsemenAssault==true and playerData.mage==leadMage and gStates.againstHorsemenAssaultOrigin~=nil then
							local saved=gStates.againstHorsemenAssaultOrigin
							original.avatarLocation=saved.avatarLocation
							original.avatarSharedHex=saved.avatarSharedHex
							original.avatarSwapCity=saved.avatarSwapCity
							original.position=saved.position or original.position
							original.assaultFromPosition=saved.position or original.assaultFromPosition
						elseif dragonAssault==true and playerData.mage==leadMage and gStates.apocalypseDragonAssaultOrigin~=nil then
							local saved=gStates.apocalypseDragonAssaultOrigin
							original.avatarLocation=saved.avatarLocation
							original.avatarSharedHex=saved.avatarSharedHex
							original.avatarSwapCity=saved.avatarSwapCity
							original.position=saved.position or original.position
							original.assaultFromPosition=saved.position or original.assaultFromPosition
						end
						gStates.coopAssaultParticipants[playerIndex]=original
						if playerData.mage~=leadMage and gStates.coopAssaultLocation~=nil then playerData.avatarLocation=gStates.coopAssaultLocation end
					end
				end
				if dragonAssault==true then apocalypseDragonBeginCoopGroundCombat() end
			else
				--If every helper declines the Dragon assault, fall back to the ordinary one-player
				--ground fight instead of moving its persistent heads through generic city cleanup.
				if startAssaultType=="dragon" then
					UI.hide("CoopAssault")
					clearCoopAssaultRuntime()
					gStates.apocalypseDragonAssaultOrigin=nil
					applyColorBarButtons()
					apocalypseDragonBeginGroundCombat(gStates.turnNumber)
					return
				end
				--A lone Mage Knight fighting the ritual garrison is a normal solo assault. Keep only the
				--approach origin so a failed assault can still retreat after surviving Horsemen return.
				if startAssaultType=="horsemen" then
					gStates.againstHorsemenSoloAssault={player=gStates.turnNumber,origin=gStates.againstHorsemenAssaultOrigin}
				end
				clearCoopAssaultRuntime(true)
				applyColorBarButtons()
			end
		end
		--move the card's monsters
		local played=false
		local OffsetX=0
		local OffsetZ=0
		local token=nil
		for playerIndex, playerData in pairs(turnOrder) do
			if gStates.assaultData[playerData.mage]~=nil and (coopStart==false or gStates.assaultData[playerData.mage].joined==true) then
				local assaultFromPosition=nil
				if wallTargetHasWall==true then
					if coopStart==true and gStates.coopAssaultParticipants[playerIndex]~=nil then assaultFromPosition=gStates.coopAssaultParticipants[playerIndex].assaultFromPosition
					elseif playerData.mage==turnOrder[gStates.turnNumber].mage then
						if assaultApproachOrigin~=nil then assaultFromPosition={assaultApproachOrigin[1], assaultApproachOrigin[2], assaultApproachOrigin[3]}
						else local avatar=coopAssaultAvatarObject(playerIndex) if avatar~=nil then assaultFromPosition=avatar.getPosition() end end
					end
				end
				local wallFortified=false
				if wallTargetHasWall==true then
					if playerData.mage==turnOrder[gStates.turnNumber].mage then wallFortified=resolveAssaultWallFortified(wallTargetPos, assaultFromPosition, true)
					else wallFortified=resolveAssaultWallFortified(wallTargetPos, assaultFromPosition, false) end
				end
				if playerData.mage~=turnOrder[gStates.turnNumber].mage then
					OffsetX=0 OffsetZ=0
					local playerTurnToken=getObjectFromGUID(playerData.turnOrderTokenGUID)
					if playerTurnToken~=nil and playerTurnToken.is_face_down==false and id~="Volkar" and
						(coopStart==false or gStates.assaultData[playerData.mage].joined==true) then
						token=playerTurnToken
						token.flip()
					end
				else
					OffsetX=gStates.monsterOffsetX OffsetZ=gStates.monsterOffsetZ
				end
				local inFight=false
				local cameraFollowed=false
				--Dragon co-op reserves slot 1 for Control; distributed coloured heads start at slot 2.
				local dragonCombatSlot=(coopStart==true and gStates.coopAssaultType=="dragon") and 2 or 1
				for _, army in pairs({"primary", "secondary"}) do
					for _, monsterGUID in pairs(gStates.assaultData[playerData.mage][army]) do
						local monsterObj=getObjectFromGUID(monsterGUID)
						if monsterObj~=nil then
							gStates.attackedMonsters[monsterGUID]={monsterObj.getPosition(), monsterObj.getRotation()}
							if wallTargetHasWall==true then setAssaultWallFortified(monsterObj, wallFortified) end
							monsterObj.unlock()
							if cameraFollowed==false then combatCameraFocus(playerIndex) cameraFollowed=true end
							local destination={(playerData.seatPos*40)-96+OffsetX, 2.5, -39-OffsetZ}
							if coopStart==true and gStates.coopAssaultType=="dragon" and apocalypseDragonGroundTokenPosition~=nil then
								local dragonPosition=apocalypseDragonGroundTokenPosition(playerIndex,dragonCombatSlot)
								if dragonPosition~=nil then destination={dragonPosition[1],2.5,dragonPosition[3]} end
								dragonCombatSlot=dragonCombatSlot+1
							end
							monsterObj.setPositionSmooth(destination,false,false)
							if wallTargetHasWall==true then settleAssaultWallFortified(monsterGUID,wallFortified) end
							monsterObj.setRotation({0.00,180.00,0.00})
							if coopStart~=true or gStates.coopAssaultType~="dragon" then
								OffsetX=OffsetX+2.5
								if OffsetX>12 then OffsetX=0 OffsetZ=OffsetZ+2.5 end
							end
							played=true
							inFight=true
						end
					end
				end
				local sharedVolkare=coopStart==true and gStates.coopAssaultType=="volkare" and gStates.assaultData[playerData.mage].joined==true
				if (playerData.avatarLocation=="Volkare's Camp" or id=="111111" or id=="Volkar" or sharedVolkare) and (inFight==true or sharedVolkare) then
					local reminderBag=getObjectFromGUID(GUID.bag.volkareReminder)
					local reminderPos=reminderBag~=nil and reminderBag.getPosition() or nil
					local monster=reminderBag~=nil and reminderBag.takeObject({position={(playerData.seatPos*40)-98.5,2.5,-39}}) or nil
					if monster~=nil and reminderPos~=nil then gStates.attackedMonsters[monster.guid]={{reminderPos[1],2,reminderPos[3]},{0.00,0.00,0.00}} end
				end
				if turnOrder[gStates.turnNumber].mage==playerData.mage then gStates.monsterOffsetX=OffsetX gStates.monsterOffsetZ=OffsetZ end
			end
		end
		if played==true then
			if coopStart==true and gStates.coopAssaultType=="dragon" then broadcastToAll("{en}The Apocalypse Dragon heads have been distributed to the participating Mage Knights.{ru}Головы Дракона Апокалипсиса распределены между участвующими Рыцарями-магами.{zh-tw}末日巨龍的龍首已分配給參與的魔法騎士。{zh-cn}末日巨龙的龙首已分配给参与的魔法骑士。{ko}아포칼립스 드래곤 머리가 참여한 메이지 나이트들에게 분배되었습니다.{es}Las cabezas del Dragón del Apocalipsis se han repartido entre los Caballeros Mago participantes.{fr}Les têtes du Dragon de l’Apocalypse ont été réparties entre les Chevaliers-Mages participants.{pt-br}As cabeças do Dragão do Apocalipse foram distribuídas entre os Mage Knights participantes.{de}Die Köpfe des Apokalypse-Drachen wurden unter den teilnehmenden Mage Knights verteilt.",{1,0.75,0.2})
			else broadcastToAll("{en}Garrison moved to Player Board.{ru}Гарнизон был помещен на стол игрока{zh-tw}守軍已移到玩家面板。{zh-cn}守军移动到玩家面板{ko}수비자와 전투합니다{es}Garrison se movió al tablero de jugador.{fr}La garnison a été transférée au plateau des joueurs.{pt-br}Guarnição movida para o tabuleiro do jogador{de}Garrison wird auf die Spielertafel verschoben.", positionToColor(gStates.turnNumber)) end
		end
		--Give later faction-leader participants an unlocked, buttonless copy now so they can plan their combat.
		if coopStart==true and gStates.coopAssaultPhase=="combat" and gStates.coopAssaultType=="leader" then createCoopLeaderPreviewClones() end
		gStates.assaultData={}
		gStates.coopAssaultUnassigned={}
		if coopStart==true then gStates.againstHorsemenAssaultOrigin=nil gStates.apocalypseDragonAssaultOrigin=nil end
		if coopDefense==true then
			if token~=nil then
				safeWaitCondition("Combat",function()
					nextTurnMerged("incrementTurn")
				end, function() return token.resting end)
			end
		end
		gStates.coopAssaultMode=nil
		UI.setAttribute("CoopAssaultMainTableText1","text","{en}Combined Assault Possible{ru}Доступен Совместный штурм города{zh-tw}可以進行合作突襲{zh-cn}可以进行合作突袭{ko}협력 강습 가능{es}Asalto Combinado Posible{fr}Assaut Combiné Possible{pt-br}Ataque Combinado Possível{de}Gemeinsamer Angriff möglich")
		UI.setAttribute("CoopAssaultMainTableText2","text",coopAssaultNormalText)
		UI.setAttribute("CoopAssaultMainTableText3", "active", "false")
		UI.setAttribute("startAssaultText", "text", "{en}Begin Assault{ru}Начать штурм{zh-tw}開始突襲{zh-cn}开始突袭{ko}강습 시작{es}Empezar Asalto{fr}Commencer l'Assaut{pt-br}Comece o Assalto{de}Angriff Starten")
		UI.hide("CoopAssault")
		if coopStart==true then clearWallAssaultChoice() assaultApproachOrigin=nil assaultTargetPosition=nil end
	end
end

--Faction leader tokens stay with the assault flow and are passed between participants, but are not defenders to divide.
function coopAssaultDividableCount(monsters)
	local count=0
	for _, monsterGUID in pairs(monsters or {}) do
		if monsterGUID~=elementalist.token and monsterGUID~=darkCrusader.token then count=count+1 end
	end
	return count
end

function coopAssaultHasLeader(monsters)
	for _, monsterGUID in pairs(monsters or {}) do
		if monsterGUID==elementalist.token or monsterGUID==darkCrusader.token then return true end
	end
	return false
end

function coopAssaultLeadMage()
	local leadMage=turnOrder[gStates.turnNumber].mage
	if leadMage==gStates.positionMageKnight[5] then
		for mage, assignedMonsters in pairs(gStates.assaultData) do if assignedMonsters.UIPos[1]==1 then leadMage=mage break end end
	end
	return leadMage
end

function coopAssaultAssignmentSource(army)
	if coopAssaultTargetType()=="volkare" then
		if gStates.coopAssaultUnassigned==nil then gStates.coopAssaultUnassigned={primary={}, secondary={}} end
		if gStates.coopAssaultUnassigned[army]==nil then gStates.coopAssaultUnassigned[army]={} end
		return gStates.coopAssaultUnassigned[army]
	end
	local leadMage=coopAssaultLeadMage()
	return gStates.assaultData[leadMage]~=nil and gStates.assaultData[leadMage][army] or nil
end

function coopAssaultCityMinimumEnemyRule()
	local assaultType=coopAssaultTargetType()
	return (assaultType=="city" or assaultType=="horsemen" or assaultType=="dragon") and gStates.coopAssaultMode~="defense"
end

function coopAssaultReadyToBegin()
	local assaultType=coopAssaultTargetType()
	local joined=0
	if assaultType=="volkare" then
		if coopAssaultDividableCount(gStates.coopAssaultUnassigned~=nil and gStates.coopAssaultUnassigned.primary or {})>0 or coopAssaultDividableCount(gStates.coopAssaultUnassigned~=nil and gStates.coopAssaultUnassigned.secondary or {})>0 then return false end
	end
	for _, assignedMonsters in pairs(gStates.assaultData) do
		if assignedMonsters.joined==true then
			joined=joined+1
			if (assaultType=="city" or assaultType=="horsemen" or assaultType=="dragon") and coopAssaultDividableCount(assignedMonsters.primary)+coopAssaultDividableCount(assignedMonsters.secondary)==0 and coopAssaultHasLeader(assignedMonsters.primary)==false and coopAssaultHasLeader(assignedMonsters.secondary)==false then return false end
		end
	end
	if assaultType=="city" or assaultType=="horsemen" or assaultType=="dragon" then return joined>=1 end
	return joined>=2
end

function coopAssaultUIUpdate()
	local entry=0
	local rowCount=0
	local size="half"
	local assaultType=coopAssaultTargetType()
	local defense=gStates.coopAssaultMode=="defense"
	local notParticipating=defense and "{en}not Defending{ru}не защищается{zh-tw}不防守{zh-cn}不防守{ko}수비 안함{es}no Defendiendo{fr}ne pas Défendre{pt-br}não Defendendo{de}nicht verteidigend" or "{en}not Assaulting{ru}не нападает{zh-tw}不突襲{zh-cn}不突袭{ko}강습 안함{es}no Agredir{fr}ne pas Agresser{pt-br}não Agredindo{de}nicht angreifend"
	local noneText="{en}No{ru}Нет{zh-tw}無{zh-cn}无{ko}없음{es}No{fr}Non{pt-br}Não{de}Nein"
	local normalAssaultText=coopAssaultNormalText
	local defenseText="{en}The City is under attack. Players must skip their next turn and Defend. This tool randomly gives the amount of attackers chosen to each player. All must face Volkare{ru}Город атакован. Игроки должны пропустить свой следующий ход и защищаться. Этот инструмент случайным образом распределяет выбранное число нападающих между игроками. Все должны сражаться с Волкаром.{zh-tw}城市正遭受攻擊。玩家必須跳過下一回合並進行防守。此工具會將選定數量的攻擊者隨機分配給每位玩家。所有人都必須面對沃卡里。{zh-cn}城市正遭受攻击。玩家必须跳过下一回合并进行防守。此工具会将选定数量的攻击者随机分配给每位玩家。所有人都必须面对沃卡里。{ko}도시가 공격받고 있습니다. 플레이어들은 다음 차례를 건너뛰고 방어해야 합니다. 이 도구는 선택한 수의 공격자를 각 플레이어에게 무작위로 배정합니다. 모두 볼케어와 맞서야 합니다.{es}La Ciudad está bajo ataque. Los jugadores deben saltarse su próximo turno y defender. Esta herramienta reparte al azar entre los jugadores la cantidad de atacantes elegida. Todos deben enfrentarse a Volkare.{fr}La Cité est attaquée. Les joueurs doivent sauter leur prochain tour et défendre. Cet outil répartit aléatoirement entre les joueurs le nombre d’attaquants choisi. Tous doivent affronter Volkare.{pt-br}A Cidade está sob ataque. Os jogadores devem pular o próximo turno e defender. Esta ferramenta distribui aleatoriamente entre os jogadores a quantidade escolhida de atacantes. Todos devem enfrentar Volkare.{de}Die Stadt wird angegriffen. Die Spieler müssen ihren nächsten Zug aussetzen und verteidigen. Dieses Werkzeug verteilt die gewählte Anzahl Angreifer zufällig auf die Spieler. Alle müssen sich Volkare stellen."
	for _, assignedMonsters in pairs(gStates.assaultData) do if #assignedMonsters.secondary>=1 then size="full" break end end
	if assaultType=="volkare" and gStates.coopAssaultUnassigned~=nil and #gStates.coopAssaultUnassigned.secondary>=1 then size="full" end
	UI.setAttribute("Mage3Assault", "active", "false")
	UI.setAttribute("Mage4Assault", "active", "false")
	local leadMage=coopAssaultLeadMage()
	local sourcePrimary=coopAssaultAssignmentSource("primary") or {}
	local sourceSecondary=coopAssaultAssignmentSource("secondary") or {}
	for mage, assignedMonsters in pairs(gStates.assaultData) do
		entry=assignedMonsters.UIPos[1]
		if entry>rowCount then rowCount=entry end
		local primaryCount=coopAssaultDividableCount(assignedMonsters.primary)
		local secondaryCount=coopAssaultDividableCount(assignedMonsters.secondary)
		local hasLeader=coopAssaultHasLeader(assignedMonsters.primary) or coopAssaultHasLeader(assignedMonsters.secondary)
		local joined=assignedMonsters.joined==true
		if entry>=3 then UI.setAttribute("Mage"..entry.."Assault", "active", "true") end
		UI.setAttribute("Mage"..entry.."AssaultJoin", "interactable", (defense or entry==1) and "false" or "true")
		UI.setAttribute("Mage"..entry.."AssaultJoinImage", "image", joined and "Sliced Button/Button New Active" or "Sliced Button/Button New Deactive")
		UI.setAttribute("Mage"..entry.."AssaulterMageName", "text", joinLang({translateWord[mage], joined and " ✓" or "{en} - Join{ru} - Присоединиться{zh-tw} - 加入{zh-cn} - 加入{ko} - 참가{es} - Unirse{fr} - Rejoindre{pt-br} - Participar{de} - Beitreten"}))
		if size=="half" then
			UI.setAttribute("Mage"..entry.."VolkareCellOne", "active", "false")
			UI.setAttribute("Mage"..entry.."VolkareCellTwo", "active", "false")
			local opponentText=assaultType=="dragon" and "{en}Dragon Heads{ru}Головы Дракона{zh-tw}龍首{zh-cn}龙首{ko}드래곤 머리{es}Cabezas de Dragón{fr}Têtes de Dragon{pt-br}Cabeças do Dragão{de}Drachenköpfe" or "{en}Defenders{ru}Защитником(ами){zh-tw}守軍{zh-cn}守军{ko}수비자{es}Defensores{fr}Défenseurs{pt-br}Defensores{de}Verteidiger"
			UI.setAttribute("Mage"..entry.."AssaulterOpponentType", "text", joined and opponentText or notParticipating)
			UI.setAttribute("Mage"..entry.."AssaulterOpponentType", "alignment", "MiddleLeft")
		else
			UI.setAttribute("Mage"..entry.."VolkareCellOne", "active", "true")
			UI.setAttribute("Mage"..entry.."VolkareCellTwo", "active", "true")
			UI.setAttribute("Mage"..entry.."AssaulterOpponentType", "text", joined and "{en}Regular and{ru}Обычные и{zh-tw}常規和{zh-cn}常规和{ko}일반 및{es}Regular y{fr}Régulier et{pt-br}Regular e{de}Normale und" or "")
			UI.setAttribute("Mage"..entry.."AssaulterOpponentType", "alignment", "MiddleCenter")
			UI.setAttribute("Mage"..entry.."AssaulterOpponentTypeTwo", "text", joined and "{en}Elite Units{ru}Элитные отряды{zh-tw}精英部隊{zh-cn}精英部队{ko}엘리트 유닛{es}Unidades de Elite{fr}Unités d'élite{pt-br}Unidades Elites{de}Elite-Einheiten" or notParticipating)
		end
		if primaryCount>=1 then UI.setAttribute("Mage"..entry.."AssaulterAmountOne", "text", tostring(primaryCount)) elseif joined then UI.setAttribute("Mage"..entry.."AssaulterAmountOne", "text", noneText) else UI.setAttribute("Mage"..entry.."AssaulterAmountOne", "text", "") end
		local canAdjust=entry~=1 or assaultType=="volkare"
		local cityMinimum=coopAssaultCityMinimumEnemyRule()
		local assignedTotal=primaryCount+secondaryCount
		local sourceTotal=coopAssaultDividableCount(sourcePrimary)+coopAssaultDividableCount(sourceSecondary)
		local canGiveBack=cityMinimum==false or assignedTotal>1
		local canTakeFromSource=cityMinimum==false or sourceTotal>1
		if primaryCount>=1 and canAdjust and canGiveBack then UI.setAttribute("Mage"..entry.."AssaultAdjustPrimDo", "interactable", "true") UI.setAttribute("Mage"..entry.."AssaultAdjustPrimDoImage", "image", "Sliced Button/Button New Active")
		else UI.setAttribute("Mage"..entry.."AssaultAdjustPrimDo", "interactable", "false") UI.setAttribute("Mage"..entry.."AssaultAdjustPrimDoImage", "image", "Sliced Button/Button New Deactive") end
		if coopAssaultDividableCount(sourcePrimary)>=1 and canAdjust and canTakeFromSource then UI.setAttribute("Mage"..entry.."AssaultAdjustPrimUp", "interactable", "true") UI.setAttribute("Mage"..entry.."AssaultAdjustPrimUpImage", "image", "Sliced Button/Button New Active")
		else UI.setAttribute("Mage"..entry.."AssaultAdjustPrimUp", "interactable", "false") UI.setAttribute("Mage"..entry.."AssaultAdjustPrimUpImage", "image", "Sliced Button/Button New Deactive") end
		if secondaryCount>=1 then UI.setAttribute("Mage"..entry.."AssaulterAmountTwo", "text", tostring(secondaryCount)) elseif joined then UI.setAttribute("Mage"..entry.."AssaulterAmountTwo", "text", noneText) else UI.setAttribute("Mage"..entry.."AssaulterAmountTwo", "text", "") end
		if secondaryCount>=1 and canAdjust and canGiveBack then UI.setAttribute("Mage"..entry.."AssaultAdjustSecoDo", "interactable", "true") UI.setAttribute("Mage"..entry.."AssaultAdjustSecoDoImage", "image", "Sliced Button/Button New Active")
		else UI.setAttribute("Mage"..entry.."AssaultAdjustSecoDo", "interactable", "false") UI.setAttribute("Mage"..entry.."AssaultAdjustSecoDoImage", "image", "Sliced Button/Button New Deactive") end
		if coopAssaultDividableCount(sourceSecondary)>=1 and canAdjust and canTakeFromSource then UI.setAttribute("Mage"..entry.."AssaultAdjustSecoUp", "interactable", "true") UI.setAttribute("Mage"..entry.."AssaultAdjustSecoUpImage", "image", "Sliced Button/Button New Active")
		else UI.setAttribute("Mage"..entry.."AssaultAdjustSecoUp", "interactable", "false") UI.setAttribute("Mage"..entry.."AssaultAdjustSecoUpImage", "image", "Sliced Button/Button New Deactive") end
		if size=="full" then UI.setAttribute("Mage"..entry.."AssaultAdjustSecoUp", "active", "true") UI.setAttribute("Mage"..entry.."AssaultAdjustSecoDo", "active", "true") else UI.setAttribute("Mage"..entry.."AssaultAdjustSecoUp", "active", "false") UI.setAttribute("Mage"..entry.."AssaultAdjustSecoDo", "active", "false") end
	end
	if assaultType=="dragon" then
		UI.setAttribute("CoopAssaultMainTableText2", "text", "{en}Mage Knights adjacent to any Dragon space can join by skipping their next turn. Divide every undefeated coloured Dragon head between the participants. The Control head attacks every participant and is not divided.{ru}Рыцари-маги, находящиеся рядом с любой клеткой Дракона, могут присоединиться, пропустив свой следующий ход. Распределите все непобеждённые цветные головы Дракона между участниками. Контрольная голова атакует каждого участника и не распределяется.{zh-tw}與任一巨龍空間相鄰的魔法騎士可以跳過下一回合加入。將所有尚未擊敗的彩色龍首分配給參與者。控制龍首會攻擊每位參與者，不進行分配。{zh-cn}与任一巨龙空间相邻的魔法骑士可以跳过下一回合加入。将所有尚未击败的彩色龙首分配给参与者。控制龙首会攻击每位参与者，不进行分配。{ko}드래곤 칸에 인접한 메이지 나이트는 다음 차례를 건너뛰고 참여할 수 있습니다. 아직 쓰러뜨리지 않은 모든 색상 드래곤 머리를 참가자들에게 나누어 배정하세요. 컨트롤 머리는 모든 참가자를 공격하며 배분하지 않습니다.{es}Los Caballeros Mago adyacentes a cualquier espacio del Dragón pueden unirse saltándose su próximo turno. Reparte entre los participantes todas las cabezas de Dragón de color no derrotadas. La cabeza de Control ataca a todos los participantes y no se reparte.{fr}Les Chevaliers-Mages adjacents à n’importe quel espace du Dragon peuvent participer en sautant leur prochain tour. Répartissez entre les participants toutes les têtes colorées du Dragon encore invaincues. La tête de Contrôle attaque chaque participant et n’est pas répartie.{pt-br}Mage Knights adjacentes a qualquer espaço do Dragão podem participar pulando o próximo turno. Divida entre os participantes todas as cabeças coloridas do Dragão ainda não derrotadas. A cabeça de Controle ataca todos os participantes e não é dividida.{de}Mage Knights neben einem beliebigen Drachenfeld können teilnehmen, indem sie ihren nächsten Zug aussetzen. Verteilt alle noch unbesiegten farbigen Drachenköpfe auf die Teilnehmer. Der Kontrollkopf greift jeden Teilnehmer an und wird nicht verteilt.")
		UI.setAttribute("CoopAssaultMainTableText3", "active", "false")
	elseif assaultType=="horsemen" then
		UI.setAttribute("CoopAssaultMainTableText2", "text", "{en}Nearby Mage Knights can join the assault on the Magical Glade by skipping their next turn. Divide the surviving Horsemen between all participating Mage Knights.{ru}Ближайшие Рыцари-маги могут присоединиться к штурму Волшебной поляны, пропустив свой следующий ход. Распределите выживших Всадников между всеми участвующими Рыцарями-магами.{zh-tw}附近的魔法騎士可以跳過下一回合加入對魔法林地的突襲。將存活的天啟騎士分配給所有參與的魔法騎士。{zh-cn}附近的魔法骑士可以跳过下一回合加入对魔法林地的突袭。将存活的天启骑士分配给所有参与的魔法骑士。{ko}근처의 메이지 나이트는 다음 차례를 건너뛰고 마법의 숲 공터 강습에 참여할 수 있습니다. 살아남은 묵시록의 기사들을 모든 참가 메이지 나이트에게 나누어 배정하세요.{es}Los Caballeros Mago cercanos pueden unirse al asalto de la Arboleda Mágica saltándose su próximo turno. Reparte los Jinetes supervivientes entre todos los Caballeros Mago participantes.{fr}Les Chevaliers-Mages proches peuvent rejoindre l’assaut de la Clairière Magique en sautant leur prochain tour. Répartissez les Cavaliers survivants entre tous les Chevaliers-Mages participants.{pt-br}Mage Knights próximos podem participar do ataque à Clareira Mágica pulando o próximo turno. Divida os Cavaleiros sobreviventes entre todos os Mage Knights participantes.{de}Mage Knights in der Nähe können sich dem Angriff auf die Magische Lichtung anschließen, indem sie ihren nächsten Zug aussetzen. Verteilt die überlebenden Reiter auf alle teilnehmenden Mage Knights.")
		UI.setAttribute("CoopAssaultMainTableText3", "active", "false")
	elseif assaultType=="volkare" then
		local unassignedPrimary=coopAssaultDividableCount(sourcePrimary)
		local unassignedSecondary=coopAssaultDividableCount(sourceSecondary)
		UI.setAttribute("CoopAssaultMainTableText2", "text", defense and defenseText or normalAssaultText)
		UI.setAttribute("CoopAssaultMainTableText3", "active", "true")
		UI.setAttribute("CoopAssaultMainTableText3", "text", joinLang({"{en}Unassigned Volkare army enemies: Regular {ru}Нераспределённые враги армии Волкара: обычные {zh-tw}未分配的沃卡里軍隊敵人：一般 {zh-cn}未分配的沃卡里军队敌人：普通 {ko}배정되지 않은 볼케어 군대 적: 일반 {es}Enemigos sin asignar del ejército de Volkare: Regulares {fr}Ennemis non assignés de l’armée de Volkare : réguliers {pt-br}Inimigos não atribuídos do exército de Volkare: Regulares {de}Nicht zugewiesene Gegner aus Volkares Armee: Regulär ", tostring(unassignedPrimary), "{en} | Elite {ru} | элитные {zh-tw} | 菁英 {zh-cn} | 精英 {ko} | 정예 {es} | Élite {fr} | élites {pt-br} | Elite {de} | Elite ", tostring(unassignedSecondary)}))
	else
		UI.setAttribute("CoopAssaultMainTableText2", "text", defense and defenseText or normalAssaultText)
		UI.setAttribute("CoopAssaultMainTableText3", "active", "false")
	end
	local ready=coopAssaultReadyToBegin()
	UI.setAttribute("startAssault", "interactable", ready and "true" or "false")
	UI.setAttribute("startAssaultImage", "image", ready and "Sliced Button/Button New Active" or "Sliced Button/Button New Deactive")
	UI.setAttribute("CoopAssault", "width", "525")
	UI.setAttribute("CoopAssault", "height", tostring(((rowCount+1)*30)+90))
	UI.setAttribute("CoopAssaultMainTableHeading", "columnSpan", "5")
	UI.setAttribute("CoopAssaultMainTableHeading", "preferredHeight", "56")
	UI.setAttribute("CoopAssaultMainTable", "columnWidths", "135 85 100 85 120")
	if size=="half" then
		UI.setAttribute("CoopAssault", "width", "340")
		UI.setAttribute("CoopAssault", "height", tostring(((rowCount+1)*30)+95))
		UI.setAttribute("CoopAssaultMainTableHeading", "columnSpan", "3")
		UI.setAttribute("CoopAssaultMainTableHeading", "preferredHeight", "61")
		UI.setAttribute("CoopAssaultMainTable", "columnWidths", "135 85 120 85 120")
	end
	UI.show("CoopAssault")
end

function coopAssaultJoin(player, mouseButton, id)
	if mouseButton~="-1" then return end
	local uiPos=tonumber(id:sub(5,5))
	local leadMage=coopAssaultLeadMage()
	for mage, assignedMonsters in pairs(gStates.assaultData) do
		if assignedMonsters.UIPos[1]==uiPos then
			if mage==leadMage then return end
			local playerIndex=nil
			for index, details in pairs(turnOrder) do if details.mage==mage then playerIndex=index break end end
			if playerIndex==nil or legalPlayerCheck(player.color, turnOrder[playerIndex].seatPos)~=true then return end
			if assignedMonsters.joined==true then
				local sourcePrimary=coopAssaultAssignmentSource("primary")
				local sourceSecondary=coopAssaultAssignmentSource("secondary")
				for _, army in pairs({{"primary", sourcePrimary}, {"secondary", sourceSecondary}}) do
					for i=#assignedMonsters[army[1]], 1, -1 do
						local guid=assignedMonsters[army[1]][i]
						if guid~=elementalist.token and guid~=darkCrusader.token and army[2]~=nil then army[2][#army[2]+1]=guid table.remove(assignedMonsters[army[1]], i) end
					end
				end
				assignedMonsters.joined=false
			else
				if coopAssaultCityMinimumEnemyRule()==true then
					local sourcePrimary=coopAssaultAssignmentSource("primary") or {}
					local sourceSecondary=coopAssaultAssignmentSource("secondary") or {}
					local sourceTotal=coopAssaultDividableCount(sourcePrimary)+coopAssaultDividableCount(sourceSecondary)
					if sourceTotal<=1 then
						broadcastToAll("{en}Each Mage Knight joining a combined assault must have at least one defender assigned.{ru}Каждому Рыцарю-магу, участвующему в совместном штурме, должен быть назначен как минимум один защитник.{zh-tw}每位加入合作突襲的魔法騎士至少必須分配一名守軍。{zh-cn}每位加入合作突袭的魔法骑士至少必须分配一名守军。{ko}협력 강습에 참가하는 각 메이지 나이트에게 최소 한 명의 수비자가 배정되어야 합니다.{es}Cada Caballero Mago que se una a un asalto combinado debe tener al menos un defensor asignado.{fr}Chaque Chevalier-Mage participant à un assaut combiné doit avoir au moins un défenseur assigné.{pt-br}Cada Mage Knight que participar de um ataque combinado deve ter pelo menos um defensor atribuído.{de}Jedem Mage Knight, der an einem gemeinsamen Angriff teilnimmt, muss mindestens ein Verteidiger zugewiesen sein.", positionToColor(playerIndex))
						break
					end
					local choices={}
					for i, guid in pairs(sourcePrimary) do if guid~=elementalist.token and guid~=darkCrusader.token then choices[#choices+1]={army="primary", index=i} end end
					for i, guid in pairs(sourceSecondary) do if guid~=elementalist.token and guid~=darkCrusader.token then choices[#choices+1]={army="secondary", index=i} end end
					if #choices==0 then break end
					local pick=choices[math.random(1,#choices)]
					local source=pick.army=="primary" and sourcePrimary or sourceSecondary
					assignedMonsters[pick.army][#assignedMonsters[pick.army]+1]=source[pick.index]
					table.remove(source,pick.index)
				end
				assignedMonsters.joined=true
			end
			break
		end
	end
	coopAssaultUIUpdate()
end

function assaultAdjust(player, mouseButton, id)
	if mouseButton~="-1" then return end
	local uiPos=tonumber(id:sub(5,5))
	local army=id:sub(19,22)=="Seco" and "secondary" or "primary"
	local action=id:sub(23,24)
	local source=coopAssaultAssignmentSource(army)
	for mage, assignedMonsters in pairs(gStates.assaultData) do
		if assignedMonsters.UIPos[1]==uiPos then
			local playerIndex=nil
			for index, details in pairs(turnOrder) do if details.mage==mage then playerIndex=index break end end
			if playerIndex==nil or legalPlayerCheck(player.color, turnOrder[playerIndex].seatPos)~=true then return end
			local cityMinimum=coopAssaultCityMinimumEnemyRule()
			local sourcePrimary=coopAssaultAssignmentSource("primary") or {}
			local sourceSecondary=coopAssaultAssignmentSource("secondary") or {}
			local sourceTotal=coopAssaultDividableCount(sourcePrimary)+coopAssaultDividableCount(sourceSecondary)
			local assignedTotal=coopAssaultDividableCount(assignedMonsters.primary)+coopAssaultDividableCount(assignedMonsters.secondary)
			if action=="Up" and source~=nil and coopAssaultDividableCount(source)>0 and (cityMinimum==false or sourceTotal>1) then
				local choices={}
				for i, guid in pairs(source) do if guid~=elementalist.token and guid~=darkCrusader.token then choices[#choices+1]=i end end
				if #choices>0 then local pick=choices[math.random(1,#choices)] assignedMonsters[army][#assignedMonsters[army]+1]=source[pick] table.remove(source,pick) assignedMonsters.joined=true end
			elseif action=="Do" and source~=nil and coopAssaultDividableCount(assignedMonsters[army])>0 and (cityMinimum==false or assignedTotal>1) then
				local choices={}
				for i, guid in pairs(assignedMonsters[army]) do if guid~=elementalist.token and guid~=darkCrusader.token then choices[#choices+1]=i end end
				if #choices>0 then local pick=choices[math.random(1,#choices)] source[#source+1]=assignedMonsters[army][pick] table.remove(assignedMonsters[army],pick) end
			end
			break
		end
	end
	coopAssaultUIUpdate()
end

--Faction identity can come from printed monster data or temporarily from monsterPerks when a normal
--enemy token substitutes for an exhausted faction pile. Faction-dependent behaviour uses this globally.
function monsterEffectiveFaction(monsterGUID)
	local perks=gStates.monsterPerks~=nil and gStates.monsterPerks[monsterGUID] or nil
	if perks~=nil and perks.faction~=nil then return perks.faction end
	local data=monsterPugs~=nil and monsterPugs[monsterGUID] or nil
	return data~=nil and data.faction or nil
end

function markMonsterFactionSubstitute(token, faction)
	if token==nil or faction==nil then return token end
	local printed=monsterPugs~=nil and monsterPugs[token.guid] or nil
	if printed~=nil and printed.faction==faction then return token end
	if gStates.monsterPerks[token.guid]==nil then gStates.monsterPerks[token.guid]={} end
	gStates.monsterPerks[token.guid].faction=faction
	return token
end

function factionMonsterPreferredPileGUID(standardGUID, faction)
	if monsterPiles[standardGUID]~=nil then standardGUID=monsterPiles[standardGUID] end
	local suffix=faction=="Dark" and "Dark" or faction=="Elem" and "Elem" or nil
	if suffix~=nil then
		for _, color in ipairs({"green","tan","red"}) do
			if standardGUID==monsterPiles[color] then return monsterPiles[color..suffix] or standardGUID end
		end
	end
	return standardGUID
end

function factionMonsterPileGUID(standardGUID, faction)
	local suffix=faction=="Dark" and "Dark" or faction=="Elem" and "Elem" or nil
	if suffix~=nil then
		for _, color in ipairs({"green","tan","red"}) do
			if standardGUID==monsterPiles[color] then
				local factionGUID=monsterPiles[color..suffix]
				local factionPile=factionGUID~=nil and getObjectFromGUID(factionGUID) or nil
				if factionPile~=nil and factionPile.getQuantity()>0 then return factionGUID, false end
				return standardGUID, true
			end
		end
	end
	return standardGUID, false
end

function takeFactionMonster(standardGUID, faction, params)
	if monsterPiles[standardGUID]~=nil then standardGUID=monsterPiles[standardGUID] end
	local pileGUID, substitute=factionMonsterPileGUID(standardGUID, faction)
	local pile=pileGUID~=nil and getObjectFromGUID(pileGUID) or nil
	if pile==nil or pile.getQuantity()==0 then return nil, pileGUID end
	local token=pile.takeObject(params)
	if substitute==true then markMonsterFactionSubstitute(token, faction) end
	return token, pileGUID
end

--summon monsters to the left of a summoner.
function summonMonster(player, mouseButton, id)
	if mouseButton~="-1" then return end
	local summoner=getObjectFromGUID(id)
	local monsterData=monsterPugs[id]
	if summoner==nil or monsterData==nil or monsterData.monsters==nil then return end
	broadcastToAll("{en}Monster Summoned some support{ru}Враг призвал подмогу{zh-tw}怪物召喚了支援{zh-cn}怪物叫了些同谋{ko}몬스터가 소환되었습니다{es}Monster convocó algo de apoyo{fr}Monstre a invoqué du soutien{pt-br}Monstro Invocou algum suporte.{de}Monster beschwört etwas Unterstützung",positionToColor(gStates.turnNumber))
	local location=summoner.getPosition()
	local summonerFaction=monsterEffectiveFaction(id)
	local tokenWait=0
	local cameraFocused=false
	for order, monsterColor in pairs(monsterData.monsters) do
		local preferredPile=factionMonsterPreferredPileGUID(monsterColor,summonerFaction)
		safeWaitFrames("Combat",function()
			withTokenPoolReady(preferredPile,function()
				local summonTarget={location[1]-(2.5*order),2.5,location[3]}
				local summonedMonster,summonPileGUID=takeFactionMonster(monsterColor,summonerFaction,{position=summonTarget,rotation={0.00,180.00,0.00}})
				if summonedMonster==nil then
					broadcastToAll("{en}Sorry, there are no tokens left to deploy{ru}Извините, жетонов для размещения больше не осталось.{zh-tw}抱歉，沒有可部署的標記了。{zh-cn}抱歉，没有token可供部署{ko}여분의 토큰이 없습니다{es}Lo sentimos, no quedan tokens para implementar{fr}Désolé, il n'y a plus de jetons à déployer{pt-br}Desculpe, Não tem Fichas sobrando para distribuir{de}Entschuldigung, es sind keine Marker mehr zum Platzieren übrig.",warningColor)
					return
				end
				local summonPile=getObjectFromGUID(summonPileGUID)
				local summonPilePos=summonPile~=nil and summonPile.getPosition() or location
				local returnPos={summonPilePos[1],2,summonPilePos[3]}
				if cameraFocused==false then combatCameraFocus(turnOrder[gStates.turnNumber]) cameraFocused=true end
				gStates.attackedMonsters[summonedMonster.guid]={returnPos,{0.00,0.00,0.00},"summoned",id}
				if id==darkCrusader.token or (summonerFaction=="Dark" and turnOrder[gStates.turnNumber].avatarLocation=="graveyard") then
					summonedMonster.addDecal({name="NightRules",position={0.85,0.15,-0.85},rotation={90,180,0},scale={0.6,0.6,1},url=nightRulesDecal})
				end
				gStates.summonStates[summonedMonster.guid]="summoned"
				local dragonControl=apocalypseDragonGroundControlToken~=nil and select(1,apocalypseDragonGroundControlToken(id))==true
				if dragonControl==true and gStates.apocalypseDragonGroundCombat~=nil then apocalypseDragonPossessSummonedEnemy(summonedMonster.guid,summonTarget) end
				if gStates.monsterPerks[summonedMonster.guid]==nil then gStates.monsterPerks[summonedMonster.guid]={nightRules=true}
				else gStates.monsterPerks[summonedMonster.guid].nightRules=true end
				cityBonusDecals(summoner,summonedMonster)
				local attachments=summoner.getAttachments()
				if attachments[1]~=nil and tokenWait==5 then
					local possessedToken=attachments[1].guid
					if monsterPugs[possessedToken]~=nil then
						if monsterPugs[possessedToken].attack~=nil then
							if gStates.monsterPerks[summonedMonster.guid]==nil then gStates.monsterPerks[summonedMonster.guid]={} end
							gStates.monsterPerks[summonedMonster.guid].attack=monsterPugs[possessedToken].attack
						end
						if monsterPugs[possessedToken].boost~=nil then
							if gStates.monsterPerks[summonedMonster.guid]==nil then gStates.monsterPerks[summonedMonster.guid]={} end
							gStates.monsterPerks[summonedMonster.guid].boost=monsterPugs[possessedToken].boost
						end
					end
				end
			end,"Combat")
		end,tokenWait)
		tokenWait=tokenWait+5
	end
	gStates.summonStates[id]="SummonDone"
	setMonsterObjectButtons(summoner)
end

--Leader overkill adjust
function adjustOverkill(player, mouseButton, id)
	if mouseButton=="-1" then
		local level=gStates.elementalistLevel-gStates.leaderReduction
		if id:sub(1,6)==darkCrusader.token then level=gStates.darkCrusaderLevel-gStates.leaderReduction end
		if id:sub(7,16)=="OverkillUp" and gStates.leaderOverkill<level then
			gStates.leaderOverkill=gStates.leaderOverkill+1
		end
		if id:sub(7,18)=="OverkillDown" and gStates.leaderOverkill>1 then
			gStates.leaderOverkill=gStates.leaderOverkill-1
		end
		local leaderObj=getObjectFromGUID(id:sub(1,6))
		if leaderObj~=nil then leaderObj.UI.setAttribute(id:sub(1,14),"Text",gStates.leaderOverkill) end
		mainUIUpdate("Leader Overkilled")
	end
end

pursuitStunnedImageURL="https://steamusercontent-a.akamaihd.net/ugc/9820771160644960489/29318B61F2A30E0E941F355C3664303B0C95BC60/"
function setPursuitStunnedImage(monsterObj, stunned)
	if monsterObj==nil then return end
	local xml=monsterObj.UI.getXmlTable() or {}
	for a=#xml, 1, -1 do if xml[a].attributes~=nil and xml[a].attributes.id=="Pursuit Stunned" then table.remove(xml, a) end end
	if stunned==true then xml[#xml+1]={tag="Image", attributes={id="Pursuit Stunned", height=110, width=110, position="0 0 -15", rotation="0 0 180", image=pursuitStunnedImageURL}} end
	if #xml==0 then xml={{}} end
	monsterObj.UI.setXmlTable(xml)
end

--Moves all rampaging tokens when Pursuit Variant Used
function pursuingRampagers(player, mouseButton, id)
	if mouseButton=="-1" then
		gStates.pursuitTwoOption=false
		--loop through all recorded pursuing monsters
		if gStates.pursuingMonsters[turnOrder[gStates.turnNumber].mage]~=nil and gStates.tacticShown==false then
			--delete the help arrows
			for guid, _ in pairs(gStates.arrowDelete) do
				local arrow=getObjectFromGUID(guid)
				if arrow~=nil then arrow.destruct() end
			end
			gStates.arrowDelete={}
			local height=0.2
			local mapSpatial=runtimeMapSpatialSnapshot()
			local mapSnapshot=mapSpatial.topology
			for monsterGUID, monsterDetails in pairs(gStates.pursuingMonsters[turnOrder[gStates.turnNumber].mage]) do
				if monsterDetails.state=="Pursuing" then
					--find initial vector to move closer to the player
					local playerPos=mageKnightAvatarPosition(gStates.turnNumber) or {}
					local playerRealPos={playerPos[1],playerPos[2],playerPos[3]}
					if turnOrder[gStates.turnNumber].avatarLocation:sub(1, 4)=="city" or turnOrder[gStates.turnNumber].avatarLocation=="Volkare's Camp" then
						--figure out which city avatar is in
						for zone, citySearch in pairs(cityScriptZones) do
							local zoneObj=getObjectFromGUID(zone)
							for _, detail in pairs(zoneObj~=nil and zoneObj.getObjects() or {}) do
								if detail.getName()==turnOrder[gStates.turnNumber].mage then
									local cityObj=getObjectFromGUID(citySearch.cityGUID)
									if cityObj~=nil then playerPos=cityObj.getPosition() end
									break
								end
							end
						end
					end
					local realBearing=(math.floor((math.deg(math.atan2(monsterDetails.location[3]-playerPos[3], monsterDetails.location[1]-playerPos[1]))/2)+0.5)*2)+2
					local playerBearing=math.floor((realBearing/60)+0.5)*60
					local inline=false
					if realBearing>=360 then playerBearing=playerBearing-360 realBearing=realBearing-360 end
					if realBearing<0 then playerBearing=playerBearing+360 realBearing=realBearing+360 end
					if realBearing<playerBearing+10 and realBearing>playerBearing-10 then inline=true end
					local clockwise=1
					if realBearing<playerBearing then clockwise=-1 end
					local canAttack=false
					local protection="none"
					local rampageNewPos={}
					local function hexCheck()
						local targetHex, _, terTile, hexBearing=runtimeMapHexAtPosition(rampageNewPos,mapSnapshot)
						local terrainFound=false
						local nearby=runtimeMapSpatialNearbyObjects(mapSpatial,rampageNewPos,3)
						if targetHex~=nil and terTile~=nil and hexBearing~=nil then
							local hexFeature=targetHex.feature or ""
							--make sure the hex isn't a fortified site
							if hexFeature~="keep" and hexFeature~="mage tower" and hexFeature:sub(1,4)~="city" then
								terrainFound=true
								if hexFeature=="village" or hexFeature=="camp" or
									hexFeature=="monastery" and gStates.monasteryBurned[terTile.guid]~=true then
									protection="Interaction"
								end
								if terrainTiles[terTile.guid].wallList~=nil and terrainTiles[terTile.guid].wallList[hexBearing]~=nil then
									local hexOriginBearing=terrainHexBearing(terTile,monsterDetails.location,mapSnapshot.terrainPositions[terTile.guid],mapSnapshot.terrainRotations[terTile.guid])
									if hexOriginBearing~=nil and terrainTiles[terTile.guid].wallList[hexBearing][hexOriginBearing]~=nil then protection="Wall" end
								end
							else
								protection="Fortified"
								if hexFeature:sub(1,4)=="city" then
									for _, obj in ipairs(nearby) do
										if combatCityZones[obj.guid]~=nil and obj.guid~=volkare.terrainHex then
											local found=false
											local cityZoneObj=getObjectFromGUID(combatCityZones[obj.guid])
											for _, obj2 in pairs(cityZoneObj~=nil and cityZoneObj.getObjects() or {}) do
												if obj2.getName()==turnOrder[gStates.turnNumber].mage then
													local objPos=mapSpatial.positions[obj.guid] or obj.getPosition()
													if math.sqrt(((rampageNewPos[1]-objPos[1])^2)+((rampageNewPos[3]-objPos[3])^2))<1 then
														protection="City"
														if turnOrder[gStates.turnNumber].defeatedCities[obj.guid]==nil and gStates.cityLevels[#gStates.cityLevels]~=0 then canAttack=true end
														found=true
														break
													end
												end
											end
											if found==true then break end
										end
									end
								end
							end
						end
						local avatarToRampageDist=math.sqrt(((rampageNewPos[1]-playerPos[1])^2)+((rampageNewPos[3]-playerPos[3])^2))
						if terrainFound==true then
							--make sure there isnt an other player
							local magefound=false
							for _, obj in ipairs(nearby) do
								if obj.getName()~=turnOrder[gStates.turnNumber].mage and combatPursuitMageNames[obj.getName()]==true then
									local objPos=mapSpatial.positions[obj.guid] or obj.getPosition()
									if math.sqrt(((rampageNewPos[1]-objPos[1])^2)+((rampageNewPos[3]-objPos[3])^2))<1 then
										magefound=true
										break
									end
								end
							end
							if magefound==false then
								--see if it moves on to player boards
								if avatarToRampageDist<0.5 and protection=="none" then canAttack=true end
								return "Good"
							end
						end
						if terrainFound==false and protection~="none" and avatarToRampageDist<0.5 then
							--need to check if the site has a shield or not to determine if he attacks or stays
							local shieldfound=false
							for _, obj in ipairs(nearby) do
								if obj.getName()=="Shield" and volkarePursuitShieldRegistered(obj)~=true and obj.getDescription()==turnOrder[gStates.turnNumber].mage then
									local objPos=mapSpatial.positions[obj.guid] or obj.getPosition()
									if math.sqrt(((rampageNewPos[1]-objPos[1])^2)+((rampageNewPos[3]-objPos[3])^2))<1 then
										shieldfound=true
										break
									end
								end
							end
							if shieldfound==false and protection~="City" then canAttack=true end
							return "Good"
						end
						return "Bad"
					end

					--check he won't move out of bounds and alter his course
					local hexIncrement={60, -120, 180, -240, 300}
					local hexFound=false
					local count=0
					while hexFound==false do
						rampageNewPos={monsterDetails.location[1]-(2.39*math.cos(math.rad(playerBearing))), monsterDetails.location[2], monsterDetails.location[3]-(2.39*math.sin(math.rad(playerBearing)))}
						if hexCheck()=="Bad" and count<5 then
							count=count+1
							playerBearing=playerBearing+(hexIncrement[count]*clockwise)
						else
							hexFound=true
						end
					end

					--check for secondary option
					local otherBearing=math.floor((math.deg(math.atan2(monsterDetails.location[3]-playerPos[3], monsterDetails.location[1]-playerPos[1]))/2)+0.5)*2
					if otherBearing>=360 then otherBearing=otherBearing-360 end
					if otherBearing<0 then otherBearing=otherBearing+360 end
					local twoOptions=1
					if (inline==true and count>0 and count<4) or (inline==false and (count==0 or count==2)) then
						if inline==false and count==0 then otherBearing=playerBearing+(hexIncrement[count+1]*clockwise) end
						if inline==false and count==2 and (clockwise==1 or (otherBearing~=30 and otherBearing~=90 and otherBearing~=150 and otherBearing~=210 and otherBearing~=270 and otherBearing~=330)) then
							otherBearing=playerBearing+(hexIncrement[count-1]*clockwise) end
						if inline==false and count==2 and clockwise==-1 and (otherBearing==30 or otherBearing==90 or otherBearing==150 or otherBearing==210 or otherBearing==270 or otherBearing==330) then
							otherBearing=playerBearing+(hexIncrement[count+1]*clockwise) end
						if inline==true and (count==1 or count==3) then otherBearing=playerBearing+(hexIncrement[count+1]*clockwise) end
						if otherBearing>=360 then otherBearing=otherBearing-360 end
						if otherBearing<0 then otherBearing=otherBearing+360 end
						rampageNewPos={monsterDetails.location[1]-(2.39*math.cos(math.rad(otherBearing))), monsterDetails.location[2], monsterDetails.location[3]-(2.39*math.sin(math.rad(otherBearing)))}
						if hexCheck()=="Good" then
							twoOptions=2
							gStates.pursuitTwoOption=true
						end
					end

					--move rampage monster one hex in a closer direction
					local noMove=false
					local rampageNewPos={monsterDetails.location[1]-(2.39*math.cos(math.rad(playerBearing))), monsterDetails.location[2]+height, monsterDetails.location[3]-(2.39*math.sin(math.rad(playerBearing)))}
					if math.sqrt(((turnOrder[gStates.turnNumber].turnStartLoc.x-playerRealPos[1])^2)+((turnOrder[gStates.turnNumber].turnStartLoc.z-playerRealPos[3])^2))<2 and id==nil then
						rampageNewPos=monsterDetails.location
						noMove=true
						gStates.pursuitTwoOption=false
					else
						if id~=nil then gStates.skippedMove=true else gStates.skippedMove=false end
						if math.sqrt(((rampageNewPos[1]-playerPos[1])^2)+((rampageNewPos[3]-playerPos[3])^2))<0.5 or count>3 then
							rampageNewPos=monsterDetails.location
							noMove=true
							if count<4 and canAttack==false then
								if protection=="Interaction" or protection=="City" then broadcastToAll(joinLang({translateWord[turnOrder[gStates.turnNumber].mage], "{en} avoids pursuit at an Interaction site.{ru} избегает преследования в месте взаимодействия.{zh-tw} 在互動地點避開追擊。{zh-cn}避免在有交涉的板块追击{ko}: 교류 장소에선 추적을 회피합니다.{es} evita la persecución en un sitio de Interacción.{fr} évite les poursuites sur un site d'Interaction.{pt-br} Evita perseguir em um lugar de interação.{de} vermeidet die Verfolgung an einem Interaktionsort."}), positionToColor(gStates.turnNumber)) end
								if protection=="Wall" then broadcastToAll(joinLang({translateWord[turnOrder[gStates.turnNumber].mage], "{en} avoids pursuit behind the wall.{ru} избегает преследования, находясь за стеной.{zh-tw} 在城牆後避開追擊。{zh-cn}避免在有城墙的板块追击{ko}: 벽 뒤에선 추적을 회피합니다.{es} evita la persecución detrás de la pared.{fr} évite les poursuites derrière le mur.{pt-br} Evita perseguir atrás de um Muro.{de} vermeidet die Verfolgung hinter einer Mauer."}), positionToColor(gStates.turnNumber)) end
								if protection=="Fortified" then broadcastToAll(joinLang({translateWord[turnOrder[gStates.turnNumber].mage], "{en} avoids pursuit at a Fortified site.{ru} избегает преследования в укрепленном месте.{zh-tw} 在要塞地點避開追擊。{zh-cn}避免在有城防的板块追击{ko}: 요새화된 장소에선 추적을 회피합니다.{es} evita la persecución en un sitio Fortificado.{fr} évite les poursuites sur un site Fortifié.{pt-br} Evita perseguir em um local Fortificado.{de} vermeidet die Verfolgung an einem befestigten Ort."}), positionToColor(gStates.turnNumber)) end
							end
						end
						if canAttack==true then
							--Use the shared combat grid so pursuing attackers cannot overlap defenders deployed at the same time.
							rampageNewPos={(turnOrder[gStates.turnNumber].seatPos*40)-96+gStates.monsterOffsetX, 2.5, -39-gStates.monsterOffsetZ}
							gStates.monsterOffsetX=gStates.monsterOffsetX+2.5
							if gStates.monsterOffsetX>12 then gStates.monsterOffsetX=0 gStates.monsterOffsetZ=gStates.monsterOffsetZ+2.5 end
							noMove=false
							gStates.monsterPlayLocation[monsterGUID]=monsterDetails.location
							getObjectFromGUID(monsterGUID).UI.setXmlTable({{}})
							broadcastToAll(joinLang({"{en}Pursuing Monster Attacked {ru}Преследующие враги напали на {zh-tw}追擊怪物攻擊了 {zh-cn}被追击怪物所攻击{ko}추적 중인 몬스터의 공격: {es}Persecución de Monstruos Atacados por {fr}Poursuivant le Monstre Attaqué {pt-br}Monstro Perseguidor Atacado {de}Verfolgtes Monster angegriffen ", translateWord[turnOrder[gStates.turnNumber].mage]}), positionToColor(gStates.turnNumber))
						end
					end
					local movingMonster=getObjectFromGUID(monsterGUID)
					if movingMonster~=nil then
						if noMove==false and canAttack==false and mapTokenSettleArrival~=nil then
							--Pursuit movement stays inside the map zone, so explicitly register this as a
							--new moving-token arrival and let the shared hex arranger keep it top-right.
							mapTokenSettleArrival(monsterGUID,rampageNewPos,{releaseOrigin=true})
						elseif canAttack==true then
							--The Pursuer is leaving the map for the combat grid; close up its old hex only.
							if mapTokenReleaseObject~=nil then mapTokenReleaseObject(movingMonster) end
							movingMonster.setPositionSmooth(rampageNewPos,false,false)
						else
							movingMonster.setPositionSmooth(rampageNewPos,false,false)
						end
					end

					if canAttack==false then gStates.monsterPlayLocation[monsterGUID]=rampageNewPos end
					height=height+0.2

					--Add an arrow to help find which tokens moved
					if noMove==false then
						for i=1, twoOptions, 1 do
							local arrowPos={monsterDetails.location[1]-(1.1*math.cos(math.rad(playerBearing))), 1.11, monsterDetails.location[3]-(1.1*math.sin(math.rad(playerBearing)))}
							local arrow=getObjectFromGUID("6647eb").clone({position=arrowPos})
							if playerBearing>=360 then playerBearing=playerBearing-360 end
							if playerBearing<0 then playerBearing=playerBearing+360 end
							arrow.setRotation({90.00, combatPursuitArrowRotation[playerBearing], 0.00})
							arrow.setColorTint("Orange")
							arrow.setPosition(arrowPos) arrow.lock() gStates.arrowDelete[arrow.guid]="Del"
							playerBearing=otherBearing
						end
					end
					mainUIUpdate("pursuit")
				end
			end
			safeWaitFrames("Combat",function() addAvatarButtons() end, 60)
		end
	end
end

--Adjust the offer size

-- Leaving site combat cleanup
function leaveAvatarSite(player)
	local playArea=getObjectFromGUID(playerPlayAreas[player.seatPos])
	if playArea~=nil then
		--Undo Possessed before returning the enemy so the attachment becomes a real token again.
		for _, obj in pairs(playArea.getObjects()) do
			if monsterPugs[obj.guid]~=nil then
				local possessedAttached=false
				for _, attachment in pairs(obj.getAttachments()) do
					if monsterPugs[attachment.guid]~=nil and monsterPugs[attachment.guid].pugType=="possessed" then possessedAttached=true break end
				end
				if possessedAttached then
					for _, attachment in pairs(clearPossessedEnemy(obj)) do
						local details=gStates.attackedMonsters[attachment.guid]
						if details~=nil then
							attachment.setRotation(details[2])
							attachment.setPositionSmooth(details[1],false,false)
							gStates.attackedMonsters[attachment.guid]=nil
						end
					end
				end
				if gStates.summonStates[obj.guid]=="SummonDone" then gStates.summonStates[obj.guid]=nil end
			end
		end
	end

	for guid, details in pairs(gStates.attackedMonsters) do
		if details[3]=="summoned" then
			gStates.summonStates[guid]=nil
			if details[4]~=nil then gStates.summonStates[details[4]]=nil end
		end
		local attackedObj=getObjectFromGUID(guid)
		if attackedObj~=nil then
			if attackedObj.getGMNotes()=="Volkare Reminder Token" then attackedObj.destruct()
			else
				attackedObj.setRotation(details[2])
				attackedObj.setPositionSmooth(details[1],false,false)
			end
		end
	end
	gStates.attackedMonsters={}
	gStates.monsterOffsetX=0
	gStates.monsterOffsetZ=0
	gStates.volkarePursuitCombat=nil
	gStates.volkarePursuitChoicePlayer=nil
	combatCameraChoiceSuppressedPlayer=nil
	player.combatIconHide="None"

	--Pyramid/Ziggurat trap reminders only belong to the site being interacted with.
	if playArea~=nil then
		for _, obj in pairs(playArea.getObjects()) do
			if obj.getGMNotes()=="Trap Reminder Token" then
				gStates.monsterPerks[obj.guid]=nil
				obj.destruct()
			end
		end
	end
	UI.setAttribute("zigguratPyramidInteract", "active", "false")
	gStates.zigguratPyramidUI=nil
	gStates.zigguratPyramidFightFloor=nil
end

-- Ziggurat and Pyramid interaction
function zigguratPyramidInteract(_, mouseButton, id)
	if mouseButton=="-1" then
		local trapBag=monsterPiles.pyramidTrap
		local firstFight=monsterPiles.gray
		local secondFight=monsterPiles.white
		local thirdFight=monsterPiles.red
		if turnOrder[gStates.turnNumber].avatarLocation=="ziggurat" then
			trapBag=monsterPiles.zigguratTrap
			firstFight=monsterPiles.green
			secondFight=monsterPiles.purple
			thirdFight=monsterPiles.tan
		end
		--remove face down traps
		local playArea=getObjectFromGUID(playerPlayAreas[turnOrder[gStates.turnNumber].seatPos])
		local playAreaObjects=playArea~=nil and playArea.getObjects() or {}
		for _, obj in pairs(playAreaObjects) do
			if obj.getGMNotes()=="Trap Reminder Token" and obj.is_face_down==true then obj.destruct() end
			local adjust=0
			if id=="zigguratPyramidInteractFight3" then adjust=0 end
			if obj.getGMNotes()=="Trap Reminder Token" and obj.is_face_down==false and obj.getPosition()[3]<=-39-gStates.monsterOffsetZ+adjust+0.5 then
				obj.setPosition({(turnOrder[gStates.turnNumber].seatPos*40)-101, 2.5, -39-gStates.monsterOffsetZ+adjust})
			end
		end
		--adjust interface
		if id=="zigguratPyramidInteractClimb1" then
			UI.setAttribute("zigguratPyramidInteractClimb1Image", "color", "Gray")
			UI.setAttribute("zigguratPyramidInteractClimb1", "interactable", "false")
			UI.setAttribute("zigguratPyramidInteractFight1Image", "color", "Gray")
			UI.setAttribute("zigguratPyramidInteractFight1", "interactable", "false")
			UI.setAttribute("zigguratPyramidInteractClimb2Image","color","White")
			UI.setAttribute("zigguratPyramidInteractClimb2","interactable","true")
			UI.setAttribute("zigguratPyramidInteractFight2Image","color","White")
			UI.setAttribute("zigguratPyramidInteractFight2","interactable","true")
			--Ascend first, then deploy both Floor 2 traps on that row. drawMonster() can now
			--complete immediately when the pool is ready, so changing rows between the two draws
			--would leave the first trap behind on Floor 1.
			gStates.monsterOffsetZ=gStates.monsterOffsetZ+2.5
			gStates.monsterOffsetX=0
			drawMonster(trapBag, turnOrder[gStates.turnNumber], id)
			safeWaitFrames("Combat",function() drawMonster(trapBag, turnOrder[gStates.turnNumber], id) end, 10)
		end
		if id=="zigguratPyramidInteractClimb2" then
			UI.setAttribute("zigguratPyramidInteractClimb2Image", "color", "Gray")
			UI.setAttribute("zigguratPyramidInteractClimb2", "interactable", "false")
			UI.setAttribute("zigguratPyramidInteractFight2Image", "color", "Gray")
			UI.setAttribute("zigguratPyramidInteractFight2", "interactable", "false")
			UI.setAttribute("zigguratPyramidInteractFight3Image", "color", "White")
			UI.setAttribute("zigguratPyramidInteractFight3", "interactable", "true")
			gStates.monsterOffsetX=0
			gStates.monsterOffsetZ=gStates.monsterOffsetZ+2.5
			drawMonster(trapBag, turnOrder[gStates.turnNumber], id)
		end
		if id=="zigguratPyramidInteractFight1" then
			gStates.zigguratPyramidFightFloor=1
			UI.setAttribute("zigguratPyramidInteractClimb1Image", "color", "Gray")
			UI.setAttribute("zigguratPyramidInteractClimb2Image", "color", "Gray")
			UI.setAttribute("zigguratPyramidInteractFight2Image", "color", "Gray")
			UI.setAttribute("zigguratPyramidInteractFight3Image", "color", "Gray")
			UI.setAttribute("zigguratPyramidInteractClimb1", "interactable", "false")
			UI.setAttribute("zigguratPyramidInteractFight1", "interactable", "false")
			UI.setAttribute("zigguratPyramidInteractFight1Image", "color", "Yellow")
			drawMonster(monsterPiles.possessed, turnOrder[gStates.turnNumber], id, "Apoc")
			drawMonster(firstFight, turnOrder[gStates.turnNumber], id)
		end
		if id=="zigguratPyramidInteractFight2" then
			gStates.zigguratPyramidFightFloor=2
			UI.setAttribute("zigguratPyramidInteractClimb2Image", "color", "Gray")
			UI.setAttribute("zigguratPyramidInteractFight3Image", "color", "Gray")
			UI.setAttribute("zigguratPyramidInteractClimb2", "interactable", "false")
			UI.setAttribute("zigguratPyramidInteractFight2", "interactable", "false")
			UI.setAttribute("zigguratPyramidInteractFight2Image", "color", "Yellow")
			drawMonster(monsterPiles.possessed, turnOrder[gStates.turnNumber], id, "Apoc")
			drawMonster(secondFight, turnOrder[gStates.turnNumber], id)
		end
		if id=="zigguratPyramidInteractFight3" then
			gStates.zigguratPyramidFightFloor=3
			UI.setAttribute("zigguratPyramidInteractFight3", "interactable", "false")
			UI.setAttribute("zigguratPyramidInteractFight3Image", "color", "Yellow")
			drawMonster(monsterPiles.possessed, turnOrder[gStates.turnNumber], id, "Apoc")
			drawMonster(thirdFight, turnOrder[gStates.turnNumber], id)
		end
	end
end

-- Public Fame/Reputation-integrated entry points. The cross-cutting accounting service is loaded
-- later, but all TTS/UI calls occur after the complete Global bundle has initialized.
function applyPlayerFameReputation(playerIndex)
	return fameReputationApplyPlayerFameReputation(playerIndex)
end

function advanceCoopRewardPhase()
	return fameReputationAdvanceCoopRewardPhase()
end

function attachEnemy(player, mouseButton, id, obj, zone)
	return fameReputationAttachEnemy(player, mouseButton, id, obj, zone)
end

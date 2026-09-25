-- Horsemen-private helpers. Predeclared so forward references keep resolving locally.
local horsemanDefeatedInventoryPosition, horsemanMarkDefeatedToken

-- Shared Four Horsemen entity/combat helpers.
-- Scenario-specific reveal, movement, ritual and AI rules remain in Scenario.lua.

--Four Horsemen helpers. The Horsemen use one persistent Custom_Tile GUID each; setHorsemanLevel()
--swaps only the front image (once level art is supplied) and replaces that GUID's normal monster data.
--Cards/neutral level Shields are therefore not required by the scripted implementation.
function horsemanDataFor(ref)
	if ref==nil or horsemanData==nil then return nil, nil end
	local key=tostring(ref)
	if horsemanData[key]~=nil then return horsemanData[key], key end
	local name=horsemanTokenToName~=nil and horsemanTokenToName[key] or nil
	if name~=nil then return horsemanData[name], name end
	return nil, nil
end

function horsemanMonsterData(ref, level)
	local data,name=horsemanDataFor(ref)
	level=math.max(1,math.min(6,tonumber(level) or 1))
	local levelData=data~=nil and data.levels~=nil and data.levels[level] or nil
	if data==nil or levelData==nil then return nil end
	---@type table<string, any>
	local abilities={
		name="Horseman - "..name,
		pugType="horseman",
		horseman=name,
		fame=levelData.fame,
		armour=levelData.armour,
		attack={[data.attackType]={[1]=levelData.attack}},
		reward=1,
		faction="Apoc",
	}
	for ability,value in pairs(data.abilities or {}) do abilities[ability]=value end
	return abilities
end

function setHorsemanLevel(ref, level, hideIdentity)
	local data,name=horsemanDataFor(ref)
	level=math.max(1,math.min(6,tonumber(level) or 1))
	local levelData=data~=nil and data.levels~=nil and data.levels[level] or nil
	if data==nil or name==nil or levelData==nil then return false end
	local token=getObjectFromGUID(data.tokenGUID)
	if token~=nil then
		--The physical rotation now hides an unrevealed Horseman's face, so load the real level art
		--from setup onward instead of swapping to a separate blank image.
		local displayName=hideIdentity==true and "" or (name.." Level "..tostring(level))
		local imageURL=levelData.tokenImg
		if type(imageURL)=="string" and imageURL~="" then
			token.setCustomObject({image=imageURL})
			token.setName(displayName)
			token.reload()
		else
			token.setName(displayName)
		end
	end
	monsterPugs[data.tokenGUID]=horsemanMonsterData(name,level)
	if gStates.horsemen==nil then gStates.horsemen={} end
	local state=gStates.horsemen[name] or {}
	state.level=level
	state.tokenGUID=data.tokenGUID
	if state.defeated==nil then state.defeated=false end
	gStates.horsemen[name]=state
	return true
end

--Rebuild shared Horseman combat state after loading/rewinding a current save.
function horsemanRestoreRuntimeState()
	if gStates==nil or (gStates.gameScenario~="Against the Horsemen Blitz" and gStates.gameScenario~="Apocalypse is Here") then return end
	if type(gStates.horsemenDefeatedBy)~="table" then gStates.horsemenDefeatedBy={} end
	for name,state in pairs(gStates.horsemen or {}) do
		local data=horsemanData~=nil and horsemanData[name] or nil
		if data~=nil and state~=nil then
			if state.defeated==true or state.retired==true then
				monsterPugs[data.tokenGUID]=nil
				if gStates.monsterPerks~=nil then gStates.monsterPerks[data.tokenGUID]=nil end
			else
				monsterPugs[data.tokenGUID]=horsemanMonsterData(name,state.level)
			end
		end
	end
	if gStates.gameScenario=="Against the Horsemen Blitz" and againstHorsemenRestoreScenarioState~=nil then againstHorsemenRestoreScenarioState() end
	if gStates.gameScenario=="Apocalypse is Here" and apocalypseIsHereRestoreScenarioState~=nil then apocalypseIsHereRestoreScenarioState() end
end

--Scenario scoring uses the actual Horseman defeats rather than inventory reward tokens. This remains
--stable if a reward token is temporarily unavailable, and also preserves exactly who earned each kill.
function horsemanDefeatSummary()
	local summary={total=0,byMage={},fameByMage={}}
	if gStates==nil or (gStates.gameScenario~="Against the Horsemen Blitz" and gStates.gameScenario~="Apocalypse is Here") then return summary end
	for name,state in pairs(gStates.horsemen or {}) do
		if state~=nil and state.defeated==true then
			summary.total=summary.total+1
			local mage=state.defeatedBy or (gStates.horsemenDefeatedBy~=nil and gStates.horsemenDefeatedBy[name] or nil)
			if mage~=nil then
				summary.byMage[mage]=(summary.byMage[mage] or 0)+1
				local data=horsemanData~=nil and horsemanData[name] or nil
				local level=math.max(1,math.min(6,tonumber(state.level) or 1))
				local fame=data~=nil and data.levels~=nil and data.levels[level]~=nil and tonumber(data.levels[level].fame) or 0
				summary.fameByMage[mage]=(summary.fameByMage[mage] or 0)+fame
			end
		end
	end
	return summary
end

--The all-players-Horseman cooperative bonus is scenario-specific: +6 in Against the Horsemen and
--+5 in Apocalypse is Here. This helper only checks whether the scoring Mage Knights qualify;
--the standard Dummy/optional Proxy never counts toward that requirement.
function horsemanEveryScoringPlayerDefeatedOne(summary)
	if gStates==nil or (gStates.gameScenario~="Against the Horsemen Blitz" and gStates.gameScenario~="Apocalypse is Here") or gStates.playerCount<=1 then return false end
	summary=summary or horsemanDefeatSummary()
	local found=false
	for _,details in pairs(turnOrder or {}) do
		if details.mage~=nil and details.mage~="nobody" and details.mage~=gStates.positionMageKnight[5] then
			found=true
			if (summary.byMage[details.mage] or 0)<1 then return false end
		end
	end
	return found
end

--Defeated Horsemen are trophies as well as saved scoring state. Keep a tidy 2x2 group in the
--slayer's Inventory and make their defeated status obvious without changing the level artwork.
horsemanDefeatedInventoryPosition=function(playerIndex,name)
	local player=turnOrder[playerIndex]
	local state=name~=nil and gStates.horsemen~=nil and gStates.horsemen[name] or nil
	if player==nil then return {55,2,20} end
	local slot=math.max(1,math.min(4,tonumber(state~=nil and state.mapSlot) or 1))
	local col=(slot-1)%2
	local row=math.floor((slot-1)/2)
	return {(player.seatPos*40)-115.8+(col*3.2),1.35,-32.7-(row*2.7)}
end

horsemanMarkDefeatedToken=function(token,name,playerIndex,smooth)
	local state=name~=nil and gStates.horsemen~=nil and gStates.horsemen[name] or nil
	local player=turnOrder[playerIndex]
	if token==nil or state==nil or player==nil then return false end
	local level=math.max(1,math.min(6,tonumber(state.level) or 1))
	mapTokenReleaseObject(token)
	token.setName("DEFEATED - "..name.." Level "..tostring(level))
	token.setDescription("Defeated by "..tostring(player.mage))
	token.setGMNotes("Defeated Horseman")
	token.setRotation({0,180,0})
	local destination=horsemanDefeatedInventoryPosition(playerIndex,name)
	if smooth==false then token.setPosition(destination) else token.setPositionSmooth(destination,false) end
	return true
end

--A revealed Horseman is a same-space attack option in both Horseman scenarios.
--Against the Horsemen disables these individual attacks once the Round-4 ritual begins; the central
--Glade assault then owns combat against every surviving Horseman instead.
function horsemanAttackOptions(playerIndex,mapPosition)
	if gStates==nil or (gStates.gameScenario~="Against the Horsemen Blitz" and gStates.gameScenario~="Apocalypse is Here") or (gStates.gameScenario=="Against the Horsemen Blitz" and gStates.againstHorsemenRitualStarted==true) then return {} end
	local player=turnOrder[playerIndex]
	if player==nil or player.mage==nil then return {} end
	if gStates.gameScenario=="Against the Horsemen Blitz" then againstHorsemenRefreshReveals() end
	local avPos=mapPosition or mageKnightAvatarPositionByName(player.mage)
	--City/Volkare-Camp avatars can be physically parked on their shared city card. Convert that
	--parking position back to the actual map location just as addAvatarButtons does for site attacks.
	if mapPosition==nil and player.avatarLocation~=nil and (player.avatarLocation:sub(1,4)=="city" or player.avatarLocation=="Volkare's Camp") then
		for zoneGUID,citySearch in pairs(cityScriptZones) do
			local zoneObj=getObjectFromGUID(zoneGUID)
			if zoneObj~=nil then
				local found=false
				for _,obj in pairs(zoneObj.getObjects()) do if obj.getName()==player.mage then found=true break end end
				if found==true then
					local cityObj=nil
					if zoneGUID==volkare.discZone and (gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz" or gStates.gameScenario=="Volkare's Quest" or gStates.gameScenario=="The War of Four") then cityObj=getObjectFromGUID(gStates.volkareModel)
					else cityObj=getObjectFromGUID(citySearch.cityGUID) end
					if cityObj~=nil then avPos=cityObj.getPosition() end
					break
				end
			end
		end
	end
	if avPos==nil then return {} end
	local avTerrain,avBearing,avHexCenter=terrainHexAtPosition(avPos)
	if avTerrain==nil or avBearing==nil then return {} end
	local here={}
	for name,state in pairs(gStates.horsemen or {}) do
		local data=horsemanData~=nil and horsemanData[name] or nil
		local token=data~=nil and getObjectFromGUID(data.tokenGUID) or nil
		if state~=nil and data~=nil and state.defeated~=true and state.retired~=true and state.revealed==true and token~=nil then
			local tokenPos=token.getPosition()
			local terrain,bearing=terrainHexAtPosition(tokenPos)
			local sameHex=terrain~=nil and terrain.guid==avTerrain.guid and tostring(bearing)==tostring(avBearing)
			--Occupied sites can physically nudge the Horseman when the Mage Knight is dropped on top.
			--Allow a small centre tolerance without reaching the neighbouring hex 2.39 units away.
			if sameHex~=true and avHexCenter~=nil then
				sameHex=((tokenPos[1]-avHexCenter[1])^2)+((tokenPos[3]-avHexCenter[3])^2)<2.25
			end
			if sameHex==true then here[#here+1]={name=name,guid=data.tokenGUID,slot=tonumber(state.mapSlot) or 99} end
		end
	end
	table.sort(here,function(a,b) if a.slot==b.slot then return a.name<b.name end return a.slot<b.slot end)
	local options={}
	for _,entry in ipairs(here) do options[#options+1]={key=entry.guid,name=entry.name,label=entry.name:sub(1,1),targets={[entry.guid]=true}} end
	return options
end

function horsemanAttackAction(playerDud,mouseButton,id)
	if mouseButton~="-1" then return end
	local key,mage=tostring(id or ""):match("^Horse|([^|]+)|(.+)$")
	if key==nil or mage==nil then return end
	local playerIndex=nil
	for index,details in pairs(turnOrder) do if details.mage==mage then playerIndex=index break end end
	if playerIndex==nil or playerIndex~=gStates.turnNumber then return end
	local player=turnOrder[playerIndex]
	--"Avatar" means a first defender has already been staged, but further optional enemies may still
	--be added to that combat. Only "Both" closes the Horseman choice completely.
	if player==nil or player.combatIconHide=="Both" then return end
	local turnToken=getObjectFromGUID(player.turnOrderTokenGUID)
	if turnToken==nil or turnToken.is_face_down==true then return end
	if playerDud~=nil and playerDud.color~=nil and legalPlayerCheck(playerDud.color,player.seatPos)~=true then return end
	local chosen=nil
	for _,option in ipairs(horsemanAttackOptions(playerIndex)) do if option.key==key then chosen=option break end end
	if chosen==nil then addAvatarButtons() return end
	gStates.horsemanAttackSelection={player=playerIndex,targets=chosen.targets}
	attackLocation(playerDud,mouseButton,"Attack"..mage)
end

--Horseman tokens are persistent Custom Tiles, so normal monster-discard logic must not treat them as
--Faction Leaders. A face-up Horseman at cleanup was defeated: record the slayer, award the Apocalypse
--Faction token, and keep the marked Horseman as a trophy in that player's Inventory. Failed face-down
--combats use monsterPlayLocation and the existing undefeated-monster return path instead.
function horsemanResolveDefeat(token,playerIndex,coopCombatReward)
	local name=horsemanTokenToName~=nil and horsemanTokenToName[token~=nil and token.guid or ""] or nil
	local state=name~=nil and gStates.horsemen~=nil and gStates.horsemen[name] or nil
	local player=turnOrder[playerIndex]
	if token==nil or name==nil or state==nil or player==nil then return false end
	if state.defeated==true then
		horsemanMarkDefeatedToken(token,name,playerIndex,true)
		return true
	end
	state.defeated=true
	state.defeatedLevel=tonumber(state.level) or 1
	state.defeatedBy=player.mage
	state.defeatedRound=gStates.currentRound
	state.atCentralGlade=false
	if gStates.horsemenDefeatedBy==nil then gStates.horsemenDefeatedBy={} end
	gStates.horsemenDefeatedBy[name]=player.mage
	local rewardBag=getObjectFromGUID(monsterPiles.rewardApoc)
	if rewardBag~=nil and rewardBag.getQuantity()>0 then
		if coopCombatReward~=nil then
			coopCombatReward.factionRewards.apocalypse=(coopCombatReward.factionRewards.apocalypse or 0)+1
			if coopCombatReward.factionRewardsGiven==true then rewardBag.takeObject({position={(player.seatPos*40)-117.2+(math.random()*6.5),2,-35+(math.random()*3.2)}}) end
		else
			rewardBag.takeObject({position={(player.seatPos*40)-117.2+(math.random()*6.5),2,-35+(math.random()*3.2)}})
		end
	else
		broadcastToAll("{en}Sorry, there are no more Apocalypse Faction Reward Tokens. Use a reminder and collect one when a token becomes available.{ru}Жетоны наград фракции Апокалипсиса закончились. Используйте напоминание и возьмите жетон, когда он станет доступен.{zh-tw}末日陣營獎勵標記已用完。請放置提醒，待標記可用時再領取。{zh-cn}末日阵营奖励标记已用完。请放置提醒，待标记可用时再领取。{ko}아포칼립스 진영 보상 토큰이 더 이상 없습니다. 알림을 사용하고 토큰이 생기면 수령하십시오.{es}No quedan fichas de Recompensa de Facción del Apocalipsis. Usa un recordatorio y recoge una cuando haya una disponible.{fr}Il ne reste plus de jetons de Récompense de Faction de l’Apocalypse. Utilisez un rappel et prenez-en un lorsqu’un jeton sera disponible.{pt-br}Não há mais fichas de Recompensa de Facção do Apocalipse. Use um lembrete e pegue uma quando houver ficha disponível.{de}Es sind keine Apokalypse-Fraktionsbelohnungsmarker mehr verfügbar. Verwende eine Erinnerung und nimm einen Marker, sobald wieder einer verfügbar ist.",positionToColor(playerIndex))
	end
	if gStates.monsterPlayLocation~=nil then gStates.monsterPlayLocation[token.guid]=nil end
	if gStates.monsterPerks~=nil then gStates.monsterPerks[token.guid]=nil end
	if gStates.attackedMonsters~=nil then gStates.attackedMonsters[token.guid]=nil end
	monsterPugs[token.guid]=nil
	horsemanMarkDefeatedToken(token,name,playerIndex,true)
	broadcastToAll(joinLang({translateWord[player.mage] or player.mage,"{en} defeated {ru} победил {zh-tw} 擊敗了 {zh-cn} 击败了 {ko}이(가) {es} derrotó a {fr} a vaincu {pt-br} derrotou {de} besiegte ",name,"{en}. The Horseman has been placed in their Inventory.{ru}. Жетон Всадника помещён в его Инвентарь.{zh-tw}。騎士已放入其庫存。{zh-cn}。骑士已放入其库存。{ko}을(를) 쓰러뜨렸습니다. 기사 토큰이 인벤토리에 놓였습니다.{es}. El Jinete se ha colocado en su Inventario.{fr}. Le Cavalier a été placé dans son Inventaire.{pt-br}. O Cavaleiro foi colocado no Inventário.{de}. Der Reiter wurde in das Inventar gelegt."}),positionToColor(playerIndex))
	return true
end

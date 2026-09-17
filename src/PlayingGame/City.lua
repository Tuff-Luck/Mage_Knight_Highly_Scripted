-- City, Megapolis, garrison, City-card placement and ownership runtime.

--Keep City scripting zones and stored defender return positions aligned with their City cards.
--City cards only move during City/map bookkeeping, so this should not run on ordinary UI refreshes.
function refreshCityScriptZones()
	for _, cityDetails in pairs(cityScriptZones) do
		if gStates.cityCard[cityDetails.cityGUID]~=nil then cityDetails.cityCard=gStates.cityCard[cityDetails.cityGUID] end
	end
	for zoneGUID, cityDetails in pairs(cityScriptZones) do
		local zoneObj=getObjectFromGUID(zoneGUID)
		local cityCardObj=getObjectFromGUID(cityDetails.cityCard)
		local cityMonsters=gStates.cityMonsterQty[cityDetails.cityGUID]
		if zoneObj~=nil and cityCardObj~=nil and cityMonsters~=nil and (cityMonsters.extra.megapolisPair==nil or cityMonsters.extra.megapolisPair~=cityDetails.cityGUID) then
			local zoneScale={x=4.6, y=1, z=3.3}
			local monsterOffset={1.15, -0.7}
			if zoneGUID==volkare.discZone then zoneScale={x=7.5, y=1, z=7.5} monsterOffset={5.5, -1}
			elseif zoneGUID==darkCrusader.discZone or zoneGUID==elementalist.discZone then zoneScale={x=7.5, y=1, z=7.5} monsterOffset={-5.5, -1} end
			if cityCardObj.getScale()[1]==1.5 then zoneScale={x=4.6, y=1, z=4.6} end
			local cityPos=cityCardObj.getPosition()
			zoneObj.setScale(zoneScale)
			zoneObj.setPosition({cityPos[1], 1.4, cityPos[3]})
			local count=0
			for monsterGUID, _ in pairs(cityMonsters) do
				if monsterGUID~="shieldNeeded" and gStates.monsterPlayLocation[monsterGUID]~=nil and getObjectFromGUID(monsterGUID)~=nil then
					gStates.monsterPlayLocation[monsterGUID][1]=cityPos[1]+monsterOffset[1]
					gStates.monsterPlayLocation[monsterGUID][2]=1+(0.6*count)
					gStates.monsterPlayLocation[monsterGUID][3]=cityPos[3]+monsterOffset[2]+(0.4*count)
					count=count+1
				end
			end
		end
	end
end

--Standard cities use the printed level data through 11. Higher levels keep the level 11 model art
--and extend the garrison by repeating the 9/10/11 pattern with one extra White token every 3 levels.
function isStandardCityGUID(cityGUID)
	return cityGUID==cityModel.red or cityGUID==cityModel.green or cityGUID==cityModel.blue or cityGUID==cityModel.white
end

function cityModelDisplayLevel(cityGUID, cityLevel)
	if isStandardCityGUID(cityGUID) then return math.min(tonumber(cityLevel) or 1, 11) end
	return tonumber(cityLevel) or 1
end

--Static City deployment data. Keeping this outside playCity() avoids rebuilding the same large tables
--every time a City is deployed or its level is changed.
function initializeCityStaticData()
	CITY_NAME_BY_GUID={[cityModel.green]="city green", [cityModel.blue]="city blue", [cityModel.white]="city white", [cityModel.red]="city red", [volkare.terrainHex]="Volkare's Camp"}
	CITY_BASE_CARD={[cityModel.white]="a37b57", [cityModel.blue]="79a723", [cityModel.red]="bd6ab1", [cityModel.green]="8de450"}
	CITY_START_LOCATION={
		[cityModel.white]={{-51.24, 1.08, -10.5}, {-50.16, 0.99, -10.5}},
		[cityModel.blue]={{-51.24, 1.08, -14.0}, {-50.16, 0.99, -14.0}},
		[cityModel.red]={{-51.24, 1.08, -17.5}, {-50.16, 0.99, -17.5}},
		[cityModel.green]={{-51.24, 1.08, -21.0}, {-50.16, 0.99, -21.0}}
	}
	CITY_MEGAPOLIS_MATRIX={
		[cityModel.white]={[cityModel.blue]=2, [cityModel.red]=3, [cityModel.green]=4},
		[cityModel.blue]={[cityModel.white]=2, [cityModel.red]=3, [cityModel.green]=4},
		[cityModel.red]={[cityModel.white]=2, [cityModel.blue]=3, [cityModel.green]=4},
		[cityModel.green]={[cityModel.white]=2, [cityModel.blue]=3, [cityModel.red]=4}
	}
	CITY_PERK={[cityModel.blue]="Elemental", [cityModel.red]="Brutal", [cityModel.green]="Poison", [cityModel.white]="Defense"}
	CITY_ARMY_DATA={
		[cityModel.red]={{1,0,0,0,0,0},{0,1,1,0,0,0},{1,0,1,0,0,0},{0,2,1,0,0,0},{1,1,1,0,0,0},{0,2,2,0,0,0},{1,2,1,0,0,0},{2,1,1,0,0,0},{1,2,2,0,0,0},{2,1,2,0,0,0},{3,1,1,0,0,0}},
		[cityModel.green]={{0,0,1,1,0,0},{0,0,2,0,0,0},{0,0,1,2,0,0},{1,0,1,1,0,0},{1,0,2,0,0,0},{1,0,1,2,0,0},{1,0,2,1,0,0},{2,0,2,0,0,0},{1,0,3,1,0,0},{2,0,2,1,0,0},{3,0,2,0,0,0}},
		[cityModel.blue]={{0,1,0,1,0,0},{0,2,0,0,0,0},{1,1,0,0,0,0},{1,1,0,1,0,0},{1,2,0,0,0,0},{2,1,0,0,0,0},{1,2,0,1,0,0},{2,2,0,0,0,0},{3,1,0,0,0,0},{2,2,0,1,0,0},{3,2,0,0,0,0}},
		[cityModel.white]={{1,0,0,0,0,0},{1,0,0,1,0,0},{2,0,0,0,0,0},{1,0,0,2,0,0},{2,0,0,1,0,0},{1,0,0,3,0,0},{2,0,0,2,0,0},{3,0,0,1,0,0},{2,0,0,3,0,0},{3,0,0,2,0,0},{4,0,0,1,0,0}},
		[volkare.terrainHex]={{0,0,0,0,0,1},{0,0,0,0,0,2},{0,0,0,0,1,2},{0,0,0,1,1,2},{1,0,0,0,1,2},{1,0,0,0,1,3},{1,0,0,0,2,2},{1,0,0,1,2,2},{1,0,0,1,2,3},{1,0,0,1,2,5},{2,0,0,0,2,5},{2,0,0,0,2,6},{2,0,0,0,2,7},{2,0,0,0,3,6},{2,0,0,1,3,6}},
		[darkCrusader.terrainHex]={{0,0,1,0,0,0},{0,0,0,0,1,0},{0,0,0,0,1,1},{0,0,1,0,1,0},{0,0,1,0,1,1},{0,0,1,0,1,2},{0,0,2,0,1,1},{0,0,1,0,2,1},{0,0,1,0,2,2},{0,0,2,0,2,1},{0,0,2,0,2,2},{0,0,2,0,2,3}},
		[elementalist.terrainHex]={{0,0,0,0,0,2},{0,0,1,0,0,1},{0,0,1,0,0,2},{0,0,0,0,1,2},{0,0,1,0,1,1},{0,0,1,0,1,2},{0,0,1,0,1,3},{0,0,2,0,1,2},{0,0,1,0,2,2},{0,0,1,0,2,3},{0,0,2,0,2,2},{0,0,2,0,2,3}}
	}
	CITY_STANDARD_PILES={monsterPiles.white, monsterPiles.purple, monsterPiles.tan, monsterPiles.gray, monsterPiles.red, monsterPiles.green}
	CITY_DARK_PILES={nil, nil, monsterPiles.tanDark, nil, monsterPiles.redDark, monsterPiles.greenDark}
	CITY_ELEMENTALIST_PILES={nil, nil, monsterPiles.tanElem, nil, monsterPiles.redElem, monsterPiles.greenElem}
	CITY_DEFENDER_PILE_BY_NAME={
		["Dark Crusader Draconum"]=monsterPiles.redDark, ["Dark Crusader Dungeon Monster"]=monsterPiles.tanDark, ["Marauding Dark Crusader"]=monsterPiles.greenDark,
		["Elementalist Draconum"]=monsterPiles.redElem, ["Elementalist Dungeon Monster"]=monsterPiles.tanElem, ["Marauding Elementalist"]=monsterPiles.greenElem,
		["Draconum"]=monsterPiles.red, ["Dungeon Monster"]=monsterPiles.tan, ["Marauding Orcs"]=monsterPiles.green,
		["City Garrison"]=monsterPiles.white, ["Mage Tower Garrison"]=monsterPiles.purple, ["Keep Garrison"]=monsterPiles.gray
	}
	CITY_DEFENDER_FALLBACK={
		["Dark Crusader Draconum"]="Draconum", ["Elementalist Draconum"]="Draconum",
		["Dark Crusader Dungeon Monster"]="Dungeon Monster", ["Elementalist Dungeon Monster"]="Dungeon Monster",
		["Marauding Dark Crusader"]="Marauding Orcs", ["Marauding Elementalist"]="Marauding Orcs"
	}
end

cityRebuildPause={}

function cityMegapolisPair(cityGUID)
	local data=gStates.cityMonsterQty~=nil and gStates.cityMonsterQty[cityGUID] or nil
	if data==nil or data.extra==nil then return nil end
	return data.extra.megapolisPair
end

function cityMegapolisPending(cityGUID)
	local data=gStates.cityMonsterQty~=nil and gStates.cityMonsterQty[cityGUID] or nil
	return data~=nil and data.extra~=nil and data.extra.megapolisPending==true
end

function cityHasMegapolis(cityGUID)
	return cityMegapolisPair(cityGUID)~=nil or cityMegapolisPending(cityGUID)==true
end

function cityPlayedContains(cityGUID)
	for _, playedGUID in ipairs(gStates.citiesPlayed or {}) do if playedGUID==cityGUID then return true end end
	return false
end

function cityRemoveFromPlayed(cityGUID)
	for index=#(gStates.citiesPlayed or {}), 1, -1 do if gStates.citiesPlayed[index]==cityGUID then table.remove(gStates.citiesPlayed, index) end end
end

function refreshUltimateConquestCityCounts()
	if gStates.gameScenario~="Ultimate Conquest" then return 0 end
	local cityCount=-(gStates.megapolisPlayed or 0)
	gStates.ultimateLeaders=0
	for _, playedCityGUID in ipairs(gStates.citiesPlayed or {}) do
		if playedCityGUID==darkCrusader.terrainHex or playedCityGUID==elementalist.terrainHex then
			gStates.ultimateLeaders=gStates.ultimateLeaders+1
		else
			cityCount=cityCount+1
		end
	end
	return cityCount
end

function ultimateConquestLeaderLevel(cityCount)
	if cityCount>0 and gStates.cityLevels[cityCount]~=nil then return gStates.cityLevels[cityCount] end
	local lowest=nil
	for cityIndex=1, gStates.cityTiles do
		local cityLevel=gStates.cityLevels[cityIndex]
		if cityLevel~=nil and (lowest==nil or cityLevel<lowest) then lowest=cityLevel end
	end
	return lowest or 1
end

cityMaintenanceLockSeen={}

--Once a City/Volkare garrison or faction leader reveals new information, its setup controls are permanently locked.
--The physical checks remain here as a last-line guard so a fast click can never beat the UI refresh.
function cityControlLockedByReveal(cityGUID, terrainGUID)
	if cityGUID==nil then return false end
	local data=gStates.cityMonsterQty~=nil and gStates.cityMonsterQty[cityGUID] or nil
	if data==nil and terrainGUID=="Volkar" and gStates.cityMonsterQty~=nil then
		data=gStates.cityMonsterQty[gStates.volkareModel] or gStates.cityMonsterQty[volkare.model]
	end
	if type(data)=="table" then
		local extra=rawget(data,"extra")
		if type(extra)=="table" and extra.levelLocked==true then return true end
	end

	local revealed=false
	if cityGUID==elementalist.terrainHex or cityGUID==darkCrusader.terrainHex then
		local leader=cityGUID==elementalist.terrainHex and elementalist or darkCrusader
		local token=getObjectFromGUID(leader.token)
		local disc=getObjectFromGUID(leader.disc)
		if token~=nil and disc~=nil then revealed=math.floor(token.getPosition()[1]-disc.getPosition()[1])~=-4 end
	elseif type(data)=="table" then
		for monsterGUID, state in pairs(data) do
			if monsterGUID~="extra" then
				local monsterObj=getObjectFromGUID(monsterGUID)
				if state=="dead" or (monsterObj~=nil and monsterObj.is_face_down==false) then revealed=true break end
			end
		end
	end

	if revealed==true then
		if type(data)=="table" then
			if type(rawget(data,"extra"))~="table" then rawset(data,"extra",{}) end
			data.extra.levelLocked=true
		end
		if terrainGUID=="Volkar" then gStates.volkareLevelLocked=true end
	end
	if terrainGUID=="Volkar" and gStates.volkareLevelLocked==true then return true end
	return revealed
end

function cityControlState(cityGUID, terrainGUID)
	local state={level=0, minLevel=0, maxLevel=0, canLevelUp=false, canLevelDown=false, canAddMegapolis=false, canRemoveMegapolis=false, showLevel=false}
	if terrainGUID=="Volkar" then
		state.level=tonumber(gStates.volkareLevel) or 4
		state.minLevel=4 state.maxLevel=60
		local locked=cityControlLockedByReveal(cityGUID, terrainGUID)
		state.canLevelUp=locked~=true and state.level<state.maxLevel
		state.canLevelDown=locked~=true and state.level>state.minLevel
		state.showLevel=state.level>15
		return state
	end
	local order=gStates.cityDeployOrder~=nil and gStates.cityDeployOrder[cityGUID] or nil
	local data=gStates.cityMonsterQty~=nil and gStates.cityMonsterQty[cityGUID] or nil
	if order==nil or data==nil or data.extra==nil or gStates.cityLevels==nil then return state end
	state.level=tonumber(gStates.cityLevels[order]) or 0
	local pair=data.extra.megapolisPair
	local pending=data.extra.megapolisPending==true
	if isStandardCityGUID(cityGUID) then state.minLevel=pair~=nil and 2 or 1 state.maxLevel=22
	elseif cityGUID==volkare.terrainHex then state.minLevel=1 state.maxLevel=15
	elseif cityGUID==elementalist.terrainHex or cityGUID==darkCrusader.terrainHex then state.minLevel=1 state.maxLevel=12
	else return state end
	local locked=cityControlLockedByReveal(cityGUID, terrainGUID)
	if state.level>0 and pending==false and locked~=true then
		state.canLevelUp=state.level<state.maxLevel
		state.canLevelDown=state.level>state.minLevel
	end
	if isStandardCityGUID(cityGUID) and pending==false and locked~=true then
		local megapolisMaximum=megapolisMaximumForSetup(gStates.scenarioRef,gStates.playersRef)
		state.canAddMegapolis=pair==nil and state.level>0 and (gStates.megapolis or 0)<megapolisMaximum
		state.canRemoveMegapolis=pair~=nil and pair~=cityGUID and (gStates.megapolis or 0)>0
	end
	state.showLevel=(cityGUID==darkCrusader.terrainHex or cityGUID==elementalist.terrainHex or (isStandardCityGUID(cityGUID) and state.level>11))
	return state
end

function setCityDisplayLevel(cityGUID, level)
	local cityObj=getObjectFromGUID(cityGUID)
	local images=cityLevelImage[cityGUID]
	local imageLevel=cityModelDisplayLevel(cityGUID, level)
	if cityObj==nil or images==nil or images[imageLevel]==nil then return false end
	cityObj.setCustomObject({diffuse=images[imageLevel]})
	cityObj.reload()
	Wait.frames(function()
		local currentCity=getObjectFromGUID(cityGUID)
		if currentCity~=nil then applyAltViewAngle(currentCity) end
	end, 2)
	return true
end


function factionLeaderForCity(cityGUID)
	if cityGUID==elementalist.terrainHex then return elementalist end
	if cityGUID==darkCrusader.terrainHex then return darkCrusader end
	return nil
end

function setFactionLeaderLevel(cityGUID, level)
	local currentLeader=factionLeaderForCity(cityGUID)
	local levelData=currentLeader~=nil and leaderData[currentLeader.terrainHex] or nil
	level=math.min(tonumber(level) or 1, 12)
	if currentLeader==nil or levelData==nil or levelData[level]==nil then return false end
	local disc=getObjectFromGUID(currentLeader.disc)
	local token=getObjectFromGUID(currentLeader.token)
	if disc~=nil then disc.setCustomObject({image=levelData[level].discImg}) disc.reload() end
	if token~=nil then
		token.setCustomObject({image=levelData[level].tokenImg})
		token.setName((currentLeader==elementalist and "Elementalist" or "Dark Crusader").." Leader Level "..level)
		token.reload()
	end
	monsterPugs[currentLeader.token]=levelData[level].abilities
	if currentLeader==elementalist then gStates.elementalistLevel=level else gStates.darkCrusaderLevel=level end
	if gStates.cityMonsterQty[cityGUID]~=nil then gStates.cityMonsterQty[cityGUID][currentLeader.token]="alive" end
	return true
end

function cityArmyLevelData(cityGUID, cityLevel)
	cityLevel=tonumber(cityLevel)
	local cityArmy=CITY_ARMY_DATA[cityGUID]
	local cityArmyLevel=cityArmy~=nil and cityLevel~=nil and cityArmy[cityLevel] or nil
	if cityArmyLevel==nil and isStandardCityGUID(cityGUID) and cityLevel~=nil and cityLevel>11 then
		local baseLevel=9+((cityLevel-9)%3)
		local extraWhite=math.floor((cityLevel-baseLevel)/3)
		cityArmyLevel={}
		for index=1, 6 do cityArmyLevel[index]=cityArmy[baseLevel][index] end
		cityArmyLevel[1]=cityArmyLevel[1]+extraWhite
	end
	return cityArmyLevel
end

function cityDefenderPile(cityGUID, tokenType)
	local standardGUID=CITY_STANDARD_PILES[tokenType]
	local faction=cityGUID==elementalist.terrainHex and "Elem" or cityGUID==darkCrusader.terrainHex and "Dark" or nil
	local pileGUID, substitute=factionMonsterPileGUID(standardGUID, faction)
	local pile=pileGUID~=nil and getObjectFromGUID(pileGUID) or nil
	if pile~=nil and pile.getQuantity()>0 then return pile, substitute==true and faction or nil end
	return nil, nil
end

function takeCityDefender(cityGUID, tokenType, position, rotation)
	local pile, substituteFaction=cityDefenderPile(cityGUID, tokenType)
	if pile==nil then
		broadcastToAll("{en}Sorry, there are no tokens left to deploy{zh-cn}抱歉，没有token可供部署{ko}여분의 토큰이 없습니다{es}Lo sentimos, no quedan tokens para implementar{fr}Désolé, il n'y a plus de jetons à déployer{pt-br}Desculpe, Não tem Fichas sobrando para distribuir", warningColor)
		return nil
	end
	local token=pile.takeObject({position=position, rotation=rotation, smooth=true})
	if token==nil then return nil end
	markMonsterFactionSubstitute(token, substituteFaction)
	gStates.monsterPlayLocation[token.guid]={position[1], position[2], position[3]}
	if cityGUID==darkCrusader.terrainHex then
		token.addDecal({name="NightRules", position={0.85, 0.15, -0.85}, rotation={90, 180, 0}, scale={0.6, 0.6, 1}, url=nightRulesDecal})
		if gStates.monsterPerks[token.guid]==nil then gStates.monsterPerks[token.guid]={nightRules=true} else gStates.monsterPerks[token.guid].nightRules=true end
	end
	return token
end

function cityGarrisonBasePosition(cityGUID, ownerGUID, megapolis)
	local currentLeader=factionLeaderForCity(cityGUID)
	if cityGUID==volkare.terrainHex then
		local disc=getObjectFromGUID(volkare.disc)
		if disc~=nil then local pos=disc.getPosition() return {pos[1]+5.5, 1.0, pos[3]-1.3}, {0,180,180} end
	elseif currentLeader~=nil then
		local disc=getObjectFromGUID(currentLeader.disc)
		if disc~=nil then local pos=disc.getPosition() return {pos[1]-5.5, 1.0, pos[3]-1.3}, {0,180,0} end
	end
	local cardGUID=gStates.cityCard[ownerGUID or cityGUID]
	local card=cardGUID~=nil and getObjectFromGUID(cardGUID) or nil
	if card~=nil then
		local pos=card.getPosition()
		return {pos[1]+1.16, 1.0, pos[3]-(megapolis==true and 1.8 or 1.0)}, {0,180,180}
	end
	return {-49,1.0,0}, {0,180,180}
end

--Standalone City army deployment. startDelay/stackIndex let both halves of a Megapolis share one orderly stack
--without relying on a closure created inside playCity(). Returns the next delay and stack index.
function cityArmyPlace(cityGUID, cityLevel, basePosition, rotation, startDelay, stackIndex, ownerGUID)
	local army=cityArmyLevelData(cityGUID, cityLevel)
	if army==nil then
		broadcastToAll("Unable to deploy City army: no data for GUID "..tostring(cityGUID).." at level "..tostring(cityLevel)..".", warningColor)
		return startDelay or 0, stackIndex or 0
	end
	ownerGUID=ownerGUID or cityGUID
	local ownerData=gStates.cityMonsterQty[ownerGUID]
	if ownerData==nil then return startDelay or 0, stackIndex or 0 end
	local delay=startDelay or 0
	local stack=stackIndex or 0
	for tokenType=1, 6 do
		local quantity=army[tokenType] or 0
		if tokenType==3 and gStates.gameScenario=="The Chaos Rift" then quantity=quantity+1 end
		for _=1, quantity do
			delay=delay+5
			stack=stack+1
			local tokenDelay=delay
			local tokenStack=stack
			Wait.frames(function() tokenRefill() end, math.max(1, tokenDelay-4))
			Wait.frames(function()
				local pos={basePosition[1], basePosition[2]+(0.2*tokenStack), basePosition[3]+(0.4*tokenStack)}
				local token=takeCityDefender(cityGUID, tokenType, pos, rotation)
				if token~=nil and gStates.cityMonsterQty[ownerGUID]~=nil then gStates.cityMonsterQty[ownerGUID][token.guid]="alive" end
			end, tokenDelay)
		end
	end
	ownerData.extra.shieldsThere=0
	if CITY_PERK[cityGUID]~=nil then
		if ownerData.extra.monsterPerk==nil then ownerData.extra.monsterPerk={"Fortified"} end
		ownerData.extra.monsterPerk[#ownerData.extra.monsterPerk+1]=CITY_PERK[cityGUID]
	end
	return delay, stack
end

function returnCityGarrisonTokens(cityGUID)
	local data=gStates.cityMonsterQty~=nil and gStates.cityMonsterQty[cityGUID] or nil
	if data==nil then return end
	local leader=factionLeaderForCity(cityGUID)
	local leaderToken=leader~=nil and leader.token or nil
	for monsterGUID, _ in pairs(data) do
		if monsterGUID~="extra" and monsterGUID~="shieldNeeded" and monsterGUID~=leaderToken then
			local monster=getObjectFromGUID(monsterGUID)
			if monster~=nil then
				local rotationValues=monster.getRotationValues()
				local pugType=rotationValues~=nil and rotationValues[2]~=nil and rotationValues[2].value or nil
				local pileGUID=pugType~=nil and CITY_DEFENDER_PILE_BY_NAME[pugType] or nil
				if pileGUID~=nil and getObjectFromGUID(pileGUID)==nil and CITY_DEFENDER_FALLBACK[pugType]~=nil then pileGUID=CITY_DEFENDER_PILE_BY_NAME[CITY_DEFENDER_FALLBACK[pugType]] end
				local pile=pileGUID~=nil and getObjectFromGUID(pileGUID) or nil
				if pile~=nil then
					gStates.monsterPerks[monsterGUID]=nil
					gStates.monsterPlayLocation[monsterGUID]=nil
					monster.setDecals({})
					pile.putObject(monster)
				end
			end
		end
	end
end

function resetCityGarrisonData(cityGUID)
	cityMaintenanceLockSeen[cityGUID]=nil
	local oldData=gStates.cityMonsterQty[cityGUID] or {extra={}}
	local storedExtra=rawget(oldData,"extra")
	local newExtra={}
	if type(storedExtra)=="table" then
		newExtra.terainGUID=storedExtra.terainGUID
		newExtra.levelLocked=storedExtra.levelLocked
		newExtra.megapolisPair=storedExtra.megapolisPair
		newExtra.megapolisPending=storedExtra.megapolisPending
		newExtra.megapolisOriginalFeature=storedExtra.megapolisOriginalFeature
	end
	local newData={extra=newExtra}
	local leader=factionLeaderForCity(cityGUID)
	if leader~=nil then rawset(newData,leader.token,"alive") end
	gStates.cityMonsterQty[cityGUID]=newData
	local pair=newData.extra.megapolisPair
	if pair~=nil and pair~=cityGUID then gStates.cityMonsterQty[pair]=newData end
	return newData
end

function cityObjectsReady(cityGUID)
	if cityMegapolisPending(cityGUID)==true then return false end
	local cityObj=getObjectFromGUID(cityGUID)
	if cityObj~=nil and cityObj.resting~=true then return false end
	local pair=cityMegapolisPair(cityGUID)
	if pair~=nil and pair~=cityGUID then
		local pairObj=getObjectFromGUID(pair)
		if pairObj~=nil and pairObj.resting~=true then return false end
	end
	local cardGUID=gStates.cityCard~=nil and gStates.cityCard[cityGUID] or nil
	local card=cardGUID~=nil and getObjectFromGUID(cardGUID) or nil
	if card~=nil and card.resting~=true then return false end
	return true
end

function disableCityControls(cityGUID, terrainGUID)
	local cityObj=getObjectFromGUID(cityGUID)
	if cityObj==nil then return end
	for _, suffix in ipairs({"LevelUp", "LevelDown", "MegapolisAdd", "MegapolisSubtract"}) do cityObj.UI.setAttribute(cityGUID..terrainGUID..suffix, "onClick", "") end
end

function rebuildCityGarrisonNow(cityGUID, terrainGUID)
	if terrainGUID=="Volkar" then volkareArmy() cityLevelButtons(cityGUID, terrainGUID) return end
	local order=gStates.cityDeployOrder[cityGUID]
	local level=order~=nil and gStates.cityLevels[order] or nil
	if level==nil or level<=0 then addCityButtons() return end
	returnCityGarrisonTokens(cityGUID)
	local data=resetCityGarrisonData(cityGUID)
	local delay=0
	local stack=0
	local leader=factionLeaderForCity(cityGUID)
	if leader~=nil then
		setFactionLeaderLevel(cityGUID, level)
		local basePos, rotation=cityGarrisonBasePosition(cityGUID, cityGUID, false)
		delay, stack=cityArmyPlace(cityGUID, level, basePos, rotation, delay, stack, cityGUID)
	else
		local pair=data.extra.megapolisPair
		local hasPair=pair~=nil and pair~=cityGUID
		local basePos, rotation=cityGarrisonBasePosition(cityGUID, cityGUID, hasPair)
		if hasPair then
			local firstLevel=math.ceil(level/2)
			local secondLevel=math.floor(level/2)
			setCityDisplayLevel(cityGUID, firstLevel)
			setCityDisplayLevel(pair, secondLevel)
			gStates.cityMonsterQty[pair]=data
			delay, stack=cityArmyPlace(cityGUID, firstLevel, basePos, rotation, delay, stack, cityGUID)
			delay, stack=cityArmyPlace(pair, secondLevel, basePos, rotation, delay, stack, cityGUID)
		else
			setCityDisplayLevel(cityGUID, level)
			delay, stack=cityArmyPlace(cityGUID, level, basePos, rotation, delay, stack, cityGUID)
		end
	end
	Wait.frames(function()
		refreshCityScriptZones()
		mainUIUpdate("City garrison rebuilt")
		addCityButtons()
	end, delay+5)
end

function rebuildCityGarrison(cityGUID, terrainGUID)
	Wait.condition(function() rebuildCityGarrisonNow(cityGUID, terrainGUID) end, function() return cityObjectsReady(cityGUID) end)
end

function scheduleCityRebuild(cityGUID, terrainGUID)
	if cityRebuildPause[cityGUID]~=nil then Wait.stop(cityRebuildPause[cityGUID]) end
	cityRebuildPause[cityGUID]=Wait.time(function()
		cityRebuildPause[cityGUID]=nil
		disableCityControls(cityGUID, terrainGUID)
		rebuildCityGarrison(cityGUID, terrainGUID)
	end, 0.5)
end

function megapolisTerrainBearingData(terrainObj)
	local northBearing=40
	local startTileGUID=gStates.gameScenario=="Against the Horsemen Blitz" and GUID.tile.country01 or startTerrain.open
	if getObjectFromGUID(startTileGUID)==nil and gStates.gameScenario~="Against the Horsemen Blitz" then startTileGUID=startTerrain.wedge northBearing=70 end
	local startTile=getObjectFromGUID(startTileGUID)
	if terrainObj==nil or startTile==nil then return 0,northBearing end
	local pos=terrainObj.getPosition()
	local startPos=startTile.getPosition()
	return math.deg(math.atan2(pos[3]-startPos[3],pos[1]-startPos[1])),northBearing
end

function megapolisReturnHexMonsters(terrainObj,hexLocation)
	if terrainObj==nil then return end
	local center=angleToXY(terrainObj,hexLocation)
	local returning={}
	for monsterGUID,pos in pairs(gStates.monsterPlayLocation or {}) do
		if type(pos)=="table" and pos[1]~=nil and pos[3]~=nil and ((pos[1]-center[1])^2)+((pos[3]-center[2])^2)<0.85 then returning[#returning+1]=monsterGUID end
	end
	for _,monsterGUID in ipairs(returning) do
		local monster=getObjectFromGUID(monsterGUID)
		if monster~=nil and monsterPugs[monsterGUID]~=nil then
			local rotationValues=monster.getRotationValues()
			local tokenName=rotationValues~=nil and rotationValues[2]~=nil and rotationValues[2].value or nil
			local pileGUID=tokenName~=nil and CITY_DEFENDER_PILE_BY_NAME[tokenName] or nil
			if pileGUID==nil then pileGUID=monsterPiles[monsterPugs[monsterGUID].pugType] end
			local pile=pileGUID~=nil and getObjectFromGUID(pileGUID) or nil
			if gStates.mineMonsterQty~=nil and gStates.mineMonsterQty[terrainObj.guid]~=nil then gStates.mineMonsterQty[terrainObj.guid][monsterGUID]=nil end
			if pile~=nil then pile.putObject(monster) else monster.destruct() end
		end
	end
end

function megapolisRemoveGraveyardMarker(terrainObj,hexLocation)
	if terrainObj==nil then return end
	local center=angleToXY(terrainObj,hexLocation)
	local map=getObjectFromGUID(mapArea)
	if map==nil then return end
	for _,obj in pairs(map.getObjects()) do
		if obj.guid~=terrainObj.guid and monsterPugs[obj.guid]==nil and terrainTiles[obj.guid]==nil then
			local pos=obj.getPosition()
			if ((pos[1]-center[1])^2)+((pos[3]-center[2])^2)<0.35 and (obj.type=="Custom_Tile" or obj.tag=="Custom_Tile") then obj.destruct() break end
		end
	end
end

function megapolisRemoveMonasteryOffer()
	if (gStates.monasteryCount or 0)<=0 then return end
	local monasteryOffer={"b7cb3b","d925e4","caf03e","5c4c6d","d51391","7700a8"}
	for i=#monasteryOffer,1,-1 do
		local zone=getObjectFromGUID(monasteryOffer[i])
		if zone~=nil then
			for _,card in pairs(zone.getObjects()) do
				if card.type=="Card" and gameCardType(card)=="Advanced Action" then
					local deck=standardDeckCycleObject("Advanced Action")
					if deck~=nil then standardDeckCycleMarkReturned("Advanced Action",card) putCardAtBottom(deck,card) else card.destruct() end
					gStates.monasteryCount=math.max(0,(gStates.monasteryCount or 0)-1)
					return
				end
			end
		end
	end
	gStates.monasteryCount=math.max(0,(gStates.monasteryCount or 0)-1)
end

function megapolisSuppressTerrainHex(terrainObj,originalFeature,removeDeployedObjects)
	if terrainObj==nil or terrainTiles[terrainObj.guid]==nil then return nil,nil end
	local hexLocation=cityTerrainRotationKey(terrainObj)
	local feature=originalFeature
	if feature==nil or feature=="city" then feature=terrainTiles[terrainObj.guid].hexFeature[hexLocation] end
	gStates.megapolisOriginalFeatureByTerrain=gStates.megapolisOriginalFeatureByTerrain or {}
	if gStates.megapolisOriginalFeatureByTerrain[terrainObj.guid]==nil then gStates.megapolisOriginalFeatureByTerrain[terrainObj.guid]=feature end
	if removeDeployedObjects==true then
		megapolisReturnHexMonsters(terrainObj,hexLocation)
		if feature=="graveyard" then megapolisRemoveGraveyardMarker(terrainObj,hexLocation) end
		if feature=="monastery" then megapolisRemoveMonasteryOffer() end
	end
	terrainTiles[terrainObj.guid].hexFeature[hexLocation]="city"
	gStates.hexOverideSave[terrainObj.guid]=gStates.hexOverideSave[terrainObj.guid] or {}
	gStates.hexOverideSave[terrainObj.guid][hexLocation]="city"
	return feature,hexLocation
end

function megapolisWarOfFourGladeOnFactionEdge(terrainObj)
	if terrainObj==nil then return false end
	local pos=terrainObj.getPosition()
	local edgeCoordinates={{-38.43,0.54},{-33.63,4.70},{-28.83,8.86},{-24.03,13.02},{0,0},{-37.23,-5.69},{-32.43,-1.52},{-27.63,2.62},{-22.83,6.79},{-18.02,10.94},{-30.03,-14.01},{-25.23,-9.84},{-20.43,-5.69},{-15.63,-1.54},{-10.81,2.63},{-24.03,-16.08},{-19.23,-11.93},{-14.43,-7.77},{-9.63,-3.61}}
	for _,coords in pairs(edgeCoordinates) do if ((pos[1]-coords[1])^2)+((pos[3]-coords[2])^2)<1 then return true end end
	return false
end

function megapolisDeployWarOfFourGlade(terrainObj,hexLocation,faction,graveyard)
	local center=angleToXY(terrainObj,hexLocation)
	gStates.mineMonsterQty[terrainObj.guid]=gStates.mineMonsterQty[terrainObj.guid] or {}
	if graveyard==true then
		local grave=getObjectFromGUID(GUID.bag.cemetery).takeObject({rotation={0,180,0},position={center[1],1.09,center[2]}})
		if grave~=nil then grave.lock() end
	end
	local piles=faction=="Dark" and {monsterPiles.tanDark,monsterPiles.greenDark} or {monsterPiles.tanElem,monsterPiles.greenElem}
	for i,pileGUID in ipairs(piles) do
		local pile=getObjectFromGUID(pileGUID)
		if pile~=nil and pile.getQuantity()>0 then
			local offset=(i-1)*0.2
			local token=pile.takeObject({rotation={0,180,0},position={center[1]-0.1+offset,2+((i-1)*0.5),center[2]-0.1+offset}})
			if token~=nil then
				markMonsterFactionSubstitute(token,faction)
				gStates.monsterPlayLocation[token.guid]=token.getPosition()
				gStates.mineMonsterQty[terrainObj.guid][token.guid]="alive"
				if graveyard==true then
					token.addDecal({name="NightRules",position={0.85,0.15,-0.85},rotation={90,180,0},scale={0.6,0.6,1},url=nightRulesDecal})
					gStates.monsterPerks[token.guid]=gStates.monsterPerks[token.guid] or {}
					gStates.monsterPerks[token.guid].nightRules=true
				end
			end
		end
	end
end

function megapolisRestoreTerrainHex(terrainObj,feature)
	if terrainObj==nil or terrainTiles[terrainObj.guid]==nil then return end
	local hexLocation=cityTerrainRotationKey(terrainObj)
	terrainTiles[terrainObj.guid].hexFeature[hexLocation]=feature or ""
	gStates.hexOverideSave[terrainObj.guid]=gStates.hexOverideSave[terrainObj.guid] or {}
	gStates.hexOverideSave[terrainObj.guid][hexLocation]=feature or ""
	if feature=="monastery" then playMonastery() return end
	if feature=="keep" then
		local pile=getObjectFromGUID(monsterPiles.gray)
		if pile~=nil and pile.getQuantity()>0 then local pos=angleToXY(terrainObj,hexLocation) local token=pile.takeObject({rotation={0,180,180},position={pos[1],2,pos[2]}}) if token~=nil then gStates.monsterPlayLocation[token.guid]={pos[1],2,pos[2]} end end
		return
	end
	if feature=="ruin" then
		local pile=getObjectFromGUID(monsterPiles.yellow)
		if pile~=nil and pile.getQuantity()>0 then local pos=angleToXY(terrainObj,hexLocation) local rotation=gStates.dayRound==false and {0,180,180} or {0,180,0} local token=pile.takeObject({rotation=rotation,position={pos[1],2,pos[2]}}) if token~=nil then gStates.monsterPlayLocation[token.guid]={pos[1],2,pos[2]} end end
		return
	end
	if gStates.gameScenario=="The War of Four" and feature=="graveyard" then megapolisDeployWarOfFourGlade(terrainObj,hexLocation,"Dark",true) return end
	if gStates.gameScenario=="The War of Four" and feature=="glade" and megapolisWarOfFourGladeOnFactionEdge(terrainObj)==true then
		local startBearing,northBearing=megapolisTerrainBearingData(terrainObj)
		local pos=terrainObj.getPosition()
		local elementalist=startBearing<=northBearing or (((startBearing<=northBearing+1 and gStates.coop==1) or (gStates.coop==0 and pos[3]<-7 and pos[3]>-8 and pos[1]<-31 and pos[1]>-32)) and math.random(1,2)==1)
		if elementalist then megapolisDeployWarOfFourGlade(terrainObj,hexLocation,"Elem",false)
		else
			terrainTiles[terrainObj.guid].hexFeature[hexLocation]="graveyard"
			gStates.hexOverideSave[terrainObj.guid][hexLocation]="graveyard"
			megapolisDeployWarOfFourGlade(terrainObj,hexLocation,"Dark",true)
		end
		return
	end
	if feature=="rampaging" or feature=="draconum" or (gStates.gameScenario=="The Chaos Rift" and (feature=="village" or ((feature=="mine" or feature=="") and terrainObj.guid==GUID.tile.city08))) then
		local startBearing,northBearing=megapolisTerrainBearingData(terrainObj)
		playRampagingTokens(terrainObj,startBearing,northBearing,hexLocation,feature,true,startingMapTiles[terrainObj.guid]~=true)
	end
end

function chooseMegapolisPair(cityGUID)
	local choices={}
	for _, possible in ipairs({cityModel.red, cityModel.green, cityModel.blue, cityModel.white}) do if possible~=cityGUID and cityPlayedContains(possible)==false then choices[#choices+1]=possible end end
	if #choices<1 then return nil end
	return choices[math.random(1,#choices)]
end

function cityTerrainRotationKey(terrainObj)
	local rotation=math.floor(((terrainObj.getRotation()[2] or 0)/60)+0.5)*60
	if rotation<0 then rotation=rotation+360 end
	if rotation>=360 then rotation=rotation-360 end
	return tostring(rotation)
end

function createCityMegapolisPair(cityGUID, terrainObj)
	local data=gStates.cityMonsterQty[cityGUID]
	if data==nil or data.extra==nil or data.extra.megapolisPair~=nil or data.extra.megapolisPending==true then return false end
	local pair=chooseMegapolisPair(cityGUID)
	if pair==nil then return false end
	data.extra.megapolisPending=true
	data.extra.megapolisPair=pair
	gStates.cityMonsterQty[pair]=data
	if cityPlayedContains(pair)==false then table.insert(gStates.citiesPlayed, pair) end
	gStates.megapolisPlayed=(gStates.megapolisPlayed or 0)+1
	if terrainObj~=nil then
		local terrainGUID=terrainObj.guid
		local rotationKey=cityTerrainRotationKey(terrainObj)
		local storedOriginal=gStates.megapolisOriginalFeatureByTerrain~=nil and gStates.megapolisOriginalFeatureByTerrain[terrainGUID] or nil
		if storedOriginal==nil then storedOriginal=megapolisSuppressTerrainHex(terrainObj,nil,true) end
		data.extra.megapolisOriginalFeature=storedOriginal
		if gStates.megapolisOriginalFeatureByTerrain~=nil then gStates.megapolisOriginalFeatureByTerrain[terrainGUID]=nil end
		terrainTiles[terrainGUID].hexFeature[rotationKey]=CITY_NAME_BY_GUID[pair]
		if gStates.hexOverideSave[terrainGUID]==nil then gStates.hexOverideSave[terrainGUID]={} end
		gStates.hexOverideSave[terrainGUID][rotationKey]=CITY_NAME_BY_GUID[pair]
		local terrainPos=terrainObj.getPosition()
		local pairObj=getObjectFromGUID(pair)
		if pairObj~=nil then pairObj.setPositionSmooth({terrainPos[1]+2.38, 1.1, terrainPos[3]}) end
	end
	local cardGUID=gStates.cityCard[cityGUID]
	local card=cardGUID~=nil and getObjectFromGUID(cardGUID) or nil
	local state=CITY_MEGAPOLIS_MATRIX[cityGUID]~=nil and CITY_MEGAPOLIS_MATRIX[cityGUID][pair] or nil
	if card==nil or state==nil then data.extra.megapolisPending=nil return true end
	Wait.frames(function()
		Wait.condition(function()
			local currentCard=getObjectFromGUID(gStates.cityCard[cityGUID])
			if currentCard==nil then data.extra.megapolisPending=nil return end
			local pos=currentCard.getPosition()
			currentCard.setPosition({pos[1], 0.98, pos[3]+0.65})
			local combined=currentCard.setState(state)
			gStates.cityCard[cityGUID]=combined.guid
			gStates.cityCard[pair]=combined.guid
			combined.lock()
			data.extra.megapolisPending=nil
			refreshCityScriptZones()
		end, function()
			local currentCard=getObjectFromGUID(gStates.cityCard[cityGUID])
			return currentCard==nil or currentCard.resting==true
		end)
	end, 10)
	return true
end

function addCityMegapolis(cityGUID, terrainGUID)
	local state=cityControlState(cityGUID, terrainGUID)
	if state.canAddMegapolis~=true then return false end
	local terrain=getObjectFromGUID(terrainGUID)
	local order=gStates.cityDeployOrder~=nil and gStates.cityDeployOrder[cityGUID] or nil
	if order~=nil and tonumber(gStates.cityLevels[order])~=nil and gStates.cityLevels[order]<2 then gStates.cityLevels[order]=2 end
	gStates.megapolis=(gStates.megapolis or 0)+1
	if createCityMegapolisPair(cityGUID, terrain)==false then gStates.megapolis=gStates.megapolis-1 return false end
	refreshUltimateConquestCityCounts()
	return true
end

function removeCityMegapolis(cityGUID, terrainGUID)
	local state=cityControlState(cityGUID, terrainGUID)
	local data=gStates.cityMonsterQty[cityGUID]
	local pair=data~=nil and data.extra~=nil and data.extra.megapolisPair or nil
	if state.canRemoveMegapolis~=true or pair==nil or pair==cityGUID then return false end
	returnCityGarrisonTokens(cityGUID)
	gStates.megapolis=math.max(0,(gStates.megapolis or 0)-1)
	gStates.megapolisPlayed=math.max(0,(gStates.megapolisPlayed or 0)-1)
	cityRemoveFromPlayed(pair)
	local terrain=getObjectFromGUID(terrainGUID)
	local originalFeature=data.extra.megapolisOriginalFeature or ""
	local start=CITY_START_LOCATION[pair]
	local pairObj=getObjectFromGUID(pair)
	if pairObj~=nil and start~=nil then pairObj.setPositionSmooth(start[1]) end
	local baseCardGUID=CITY_BASE_CARD[pair]
	local baseCard=baseCardGUID~=nil and getObjectFromGUID(baseCardGUID) or nil
	if baseCard~=nil and start~=nil then baseCard.setPositionSmooth(start[2]) baseCard.setRotation({0,180,180}) end
	local cardGUID=gStates.cityCard[cityGUID]
	local card=cardGUID~=nil and getObjectFromGUID(cardGUID) or nil
	if card~=nil then
		local pos=card.getPosition()
		card.setPosition({pos[1],0.98,pos[3]-0.65})
		if card.getStateId()~=1 then card=card.setState(1) end
		gStates.cityCard[cityGUID]=card.guid
		card.lock()
	end
	gStates.cityCard[pair]=baseCardGUID
	gStates.cityMonsterQty[pair]=nil
	data.extra.megapolisPair=nil
	data.extra.megapolisPending=nil
	data.extra.megapolisOriginalFeature=nil
	if terrain~=nil and terrainTiles[terrainGUID]~=nil then Wait.frames(function() megapolisRestoreTerrainHex(terrain,originalFeature) end,5) end
	resetCityGarrisonData(cityGUID)
	refreshUltimateConquestCityCounts()
	refreshCityScriptZones()
	return true
end

function cityShouldCreateMegapolis(cityGUID, ultimateCitiesPlayed)
	if (gStates.megapolis or 0)<=0 or (gStates.megapolisPlayed or 0)>=(gStates.megapolis or 0) or isStandardCityGUID(cityGUID)==false then return false end
	if gStates.gameScenario=="Ultimate Conquest" then return ultimateCitiesPlayed>(gStates.cityTiles-gStates.megapolis) end
	return gStates.megapolis>gStates.cityTiles-#gStates.citiesPlayed
end

function cityInitialCardPosition(cityGUID, terrainObj)
	local cardGUID=gStates.cityCard[cityGUID]
	local card=cardGUID~=nil and getObjectFromGUID(cardGUID) or nil
	if card==nil then return nil end
	local terrainPos=terrainObj.getPosition()
	local cityPos={terrainPos[1],1.09,terrainPos[3]}
	local mapObjects=cityCardMapSnapshot()
	local movingGUIDs={[cityGUID]=true,[cardGUID]=true}
	local preferred=gStates.gameScenario=="The Gauntlet" and 3 or nil
	local desired=findCityCardPosition(cityPos, mapObjects, movingGUIDs, nil, nil, preferred)
	if desired~=nil then card.setPositionSmooth(desired) return desired end
	return card.getPosition()
end

function cityRegisterDeployOrder(cityGUID, ultimateCitiesPlayed)
	if gStates.cityDeployOrder[cityGUID]~=nil then return gStates.cityDeployOrder[cityGUID] end
	local playedCities=#gStates.citiesPlayed-(gStates.megapolisPlayed or 0)
	if gStates.gameScenario=="Ultimate Conquest" then playedCities=ultimateCitiesPlayed end
	if gStates.gameScenario=="The War of Four" then table.insert(gStates.cityLevels, playedCities, gStates.cityLevels[4]) table.remove(gStates.cityLevels, 5) end
	gStates.cityDeployOrder[cityGUID]=playedCities
	return playedCities
end

function cityLeaderDeployOrder(cityGUID, ultimateCitiesPlayed, leaderLevel)
	if gStates.cityDeployOrder[cityGUID]~=nil then return gStates.cityDeployOrder[cityGUID], gStates.cityLevels[gStates.cityDeployOrder[cityGUID]] end
	local leaderOrder=#gStates.citiesPlayed-(gStates.megapolisPlayed or 0)
	if gStates.gameScenario=="Ultimate Conquest" then leaderOrder=#gStates.cityLevels+1 gStates.cityLevels[leaderOrder]=leaderLevel end
	gStates.cityDeployOrder[cityGUID]=leaderOrder
	return leaderOrder, leaderLevel
end

function deployFriendlyCityShields(cityGUID)
	if gStates.friendlyCity==nil then gStates.friendlyCity={} end
	gStates.friendlyCity[cityGUID]=true
	local cityObj=getObjectFromGUID(cityGUID)
	Wait.frames(function()
		Wait.condition(function()
			refreshCityScriptZones()
			mainUIUpdate("City card move")
			if cityGUID==darkCrusader.terrainHex or cityGUID==elementalist.terrainHex then return end
			local cardGUID=gStates.cityCard[cityGUID]
			local card=cardGUID~=nil and getObjectFromGUID(cardGUID) or nil
			if card==nil then return end
			local tempPos=card.getPosition()
			for seatPos=1,4 do
				local mageName=gStates.positionMageKnight[seatPos]
				local mage=mageKnightsByName~=nil and mageKnightsByName[mageName] or nil
				if mage~=nil and mageName~="nobody" then getObjectFromGUID(mage.shieldContainer).takeObject({position={tempPos[1]-2.5+seatPos,2,tempPos[3]}}) end
			end
			--Standard Dummies never place friendly-City shields. The Proxy is a map player and does.
			if proxyPlayerActive()==true then proxyTakeShield({tempPos[1]+2.5,2,tempPos[3]},false) end
		end, function() return cityObj==nil or cityObj.resting==true end)
	end,10)
end

function resolveCityForTerrain(obj, hexFeature, dropped)
	local cityGUID=""
	if gStates.gameScenario~="Life and Death" and (hexFeature or ""):sub(6,8)=="red" then cityGUID=cityModel.red end
	if gStates.gameScenario~="Life and Death" and (hexFeature or ""):sub(6,10)=="green" then cityGUID=cityModel.green end
	if gStates.gameScenario~="The Realm of the Dead Blitz" and (hexFeature or ""):sub(6,9)=="blue" then cityGUID=cityModel.blue end
	if gStates.gameScenario~="The Hidden Valley Blitz" and (hexFeature or ""):sub(6,10)=="white" then cityGUID=cityModel.white end
	if hexFeature=="Volkare's Camp" then cityGUID=volkare.terrainHex end
	if gStates.hexOverideSave[obj.guid]==nil then gStates.hexOverideSave[obj.guid]={} end
	local randomizeThisCity=gStates.randomCities==true or cityPlayedContains(cityGUID)==true
	if randomizeThisCity==true and dropped==true then
		local choices={cityModel.green,cityModel.blue,cityModel.white,cityModel.red}
		if gStates.volkareCampAsCity==true then choices[#choices+1]=volkare.terrainHex end
		local available={}
		for _, possible in ipairs(choices) do if cityPlayedContains(possible)==false then available[#available+1]=possible end end
		if #available>0 then cityGUID=available[math.random(1,#available)] end
		terrainTiles[obj.guid].hexFeature.center=CITY_NAME_BY_GUID[cityGUID]
		gStates.hexOverideSave[obj.guid].center=CITY_NAME_BY_GUID[cityGUID]
	end
	if gStates.gameScenario=="The Gauntlet" and (hexFeature or ""):sub(6,8)=="red" then cityGUID=cityModel.red end
	if gStates.gameScenario=="Life and Death" and ((hexFeature or ""):sub(6,8)=="red" or hexFeature=="necropolis") then cityGUID=darkCrusader.terrainHex end
	if gStates.gameScenario=="Life and Death" and ((hexFeature or ""):sub(6,10)=="green" or hexFeature=="hidden valley") then cityGUID=elementalist.terrainHex end
	if gStates.gameScenario=="The Realm of the Dead Blitz" and ((hexFeature or ""):sub(6,9)=="blue" or hexFeature=="necropolis") then cityGUID=darkCrusader.terrainHex end
	if gStates.gameScenario=="The Hidden Valley Blitz" and ((hexFeature or ""):sub(6,10)=="white" or hexFeature=="hidden valley") then cityGUID=elementalist.terrainHex end
	if gStates.gameScenario=="Ultimate Conquest" and obj.guid==GUID.tile.core03 then cityGUID=darkCrusader.terrainHex end
	if gStates.gameScenario=="Ultimate Conquest" and obj.guid==GUID.tile.core10 then cityGUID=elementalist.terrainHex end
	local objPos=obj.getPosition()
	if gStates.gameScenario=="The War of Four" and objPos[1]<-22 and objPos[3]>6 then cityGUID=darkCrusader.terrainHex end
	if gStates.gameScenario=="The War of Four" and objPos[1]>-16 and objPos[3]>-8 then cityGUID=elementalist.terrainHex end
	return cityGUID
end

function revealCityInfoCard(cityGUID)
	local infoGUID=CITY_BASE_CARD[cityGUID]
	if infoGUID==nil then return end
	local info=getObjectFromGUID(infoGUID)
	if info~=nil then info.setRotationSmooth({0,180,0}) end
	local generalInfo=getObjectFromGUID("452c86")
	if generalInfo~=nil then generalInfo.setRotationSmooth({0,180,0}) end
end

--Initial City deployment only. Mid-game level and Megapolis controls rebuild the registered City directly and
--never re-run this selection/registration path.
function playCity(obj, hexFeature, dropped)
	local cityGUID=resolveCityForTerrain(obj, hexFeature, dropped)
	if cityGUID==nil or cityGUID=="" then return end
	if gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz" then gStates.cityRevealed={{model=cityGUID,terrain=obj.guid}} end
	revealCityInfoCard(cityGUID)
	local cityObj=getObjectFromGUID(cityGUID)
	if cityObj~=nil and gStates.gameScenario~="The Lost Relic Blitz" then
		local terrainPos=obj.getPosition()
		cityObj.setPositionSmooth({terrainPos[1],1.09,terrainPos[3]})
		if gStates.cityCard[cityGUID]~=nil and dropped==true then cityInitialCardPosition(cityGUID,obj) end
		table.insert(gStates.citiesPlayed,cityGUID)
		if gStates.ultimateLeaders==nil then gStates.ultimateLeaders=0 end
		if cityGUID==volkare.terrainHex then gStates.cityVolkareTile=obj.guid end
		if gStates.cityMonsterQty[cityGUID]==nil then gStates.cityMonsterQty[cityGUID]={extra={terainGUID=obj.guid}} else gStates.cityMonsterQty[cityGUID].extra.terainGUID=obj.guid end
		local ultimateCitiesPlayed=refreshUltimateConquestCityCounts()
		local leader=factionLeaderForCity(cityGUID)
		if leader~=nil then
			local leaderLevel=gStates.cityLevels[#gStates.citiesPlayed-(gStates.megapolisPlayed or 0)-math.ceil((gStates.megapolisPlayed or 0)/2)]
			if gStates.gameScenario=="Ultimate Conquest" then leaderLevel=ultimateConquestLeaderLevel(ultimateCitiesPlayed) end
			if gStates.gameScenario=="The War of Four" then
				leaderLevel=999
				for _, level in pairs(gStates.cityLevels) do if level<leaderLevel then leaderLevel=level end end
			end
			local order
			order, leaderLevel=cityLeaderDeployOrder(cityGUID, ultimateCitiesPlayed, leaderLevel)
			leaderLevel=math.min(tonumber(leaderLevel) or 1,12)
			gStates.cityLevels[order]=leaderLevel
			setFactionLeaderLevel(cityGUID,leaderLevel)
			if leader==elementalist then
				terrainTiles[obj.guid].hexFeature.center="hidden valley"
				gStates.hexOverideSave[obj.guid].center="hidden valley"
				gStates.monsterPlayLocation[elementalist.token]={-55.3,1.5,15.3}
			else
				terrainTiles[obj.guid].hexFeature.center="necropolis"
				gStates.hexOverideSave[obj.guid].center="necropolis"
				gStates.monsterPlayLocation[darkCrusader.token]={-55.3,1.5,6.7}
			end
			local basePos, rotation=cityGarrisonBasePosition(cityGUID,cityGUID,false)
			local delay=cityArmyPlace(cityGUID,leaderLevel,basePos,rotation,0,0,cityGUID)
			Wait.frames(function() refreshCityScriptZones() mainUIUpdate("City card move") addCityButtons() end, delay+5)
		else
			if cityShouldCreateMegapolis(cityGUID,ultimateCitiesPlayed)==true then createCityMegapolisPair(cityGUID,obj) end
			ultimateCitiesPlayed=refreshUltimateConquestCityCounts()
			local playedCities=cityRegisterDeployOrder(cityGUID,ultimateCitiesPlayed)
			local level=gStates.cityLevels~=nil and gStates.cityLevels[playedCities] or nil
			if level~=nil and level>0 and gStates.gameScenario~="The Lost Relic Blitz" and gStates.gameScenario~="The Realm of the Dead Blitz" and gStates.gameScenario~="Life and Death" and gStates.gameScenario~="The Hidden Valley Blitz" then
				if gStates.gameScenario=="Fury of the Apocalypse Dragon" then deployFriendlyCityShields(cityGUID) end
				Wait.frames(function() rebuildCityGarrison(cityGUID,obj.guid) end,10)
			elseif level~=nil then
				if cityGUID~=darkCrusader.terrainHex and cityGUID~=elementalist.terrainHex then table.insert(gStates.cityLevels,#gStates.citiesPlayed,0) table.remove(gStates.cityLevels,#gStates.cityLevels) end
				deployFriendlyCityShields(cityGUID)
			end
		end
		local cardGUID=gStates.cityCard[cityGUID]
		if cardGUID~=nil then
			Wait.frames(function()
				Wait.condition(function() local card=getObjectFromGUID(gStates.cityCard[cityGUID]) if card~=nil then card.lock() end end,
					function() local card=getObjectFromGUID(gStates.cityCard[cityGUID]) return card==nil or card.resting==true end)
			end,10)
		end
	end
	if gStates.gameScenario=="The Lost Relic Blitz" then
		local pos=obj.getPosition()
		local token=getObjectFromGUID(monsterPiles.red).takeObject({rotation=faceDown,position={pos[1],2,pos[3]}})
		gStates.monsterPlayLocation[token.guid]={pos[1],2,pos[3]}
	end
end

--Keep the non-interactive City level readout visible after its garrison is revealed.
function cityLevelReadoutOnly(cityGUID, terrainGUID)
	local cityObj=getObjectFromGUID(cityGUID)
	if cityObj==nil then return end
	local state=cityControlState(cityGUID,terrainGUID)
	if state.showLevel then
		cityObj.UI.setXmlTable({{tag="Image",attributes={image="Overkill Text",height=50,width=50,position="0 60 -30",rotation="0 0 180"},children={{tag="Text",attributes={id=cityGUID..terrainGUID.."Overkill",color="rgb(0,0,0)",fontSize="35",fontStyle="Bold",alignment="MiddleCenter",text=state.level}}}}})
	else
		cityObj.UI.setXmlTable({{}})
	end
end

--Add arrows to City models. UI visibility and click validation use the same control-state function.
function cityLevelButtons(cityGUID, terrainGUID)
	Wait.time(function()
		local cityObj=getObjectFromGUID(cityGUID)
		if cityObj==nil then return end
		local state=cityControlState(cityGUID,terrainGUID)
		local buttonXML={}
		if state.canLevelUp then
			buttonXML[#buttonXML+1]={tag="Button",attributes={id=cityGUID..terrainGUID.."LevelUp",onMouseDown="global/buttonClicked",onMouseUp="global/buttonClicked",onClick="global/addjustCityLevel",height=50,width=50,color="rgba(0,0,0,0.0)",position="-65 60 -30",rotation="0 0 180"},children={{tag="Image",attributes={id=cityGUID..terrainGUID.."LevelUpImage",image="Overkill Up"}}}}
		end
		if state.showLevel then
			buttonXML[#buttonXML+1]={tag="Image",attributes={image="Overkill Text",height=50,width=50,position="0 60 -30",rotation="0 0 180"},children={{tag="Text",attributes={id=cityGUID..terrainGUID.."Overkill",color="rgb(0,0,0)",fontSize="35",fontStyle="Bold",alignment="MiddleCenter",text=state.level}}}}
		end
		if state.canLevelDown then
			buttonXML[#buttonXML+1]={tag="Button",attributes={id=cityGUID..terrainGUID.."LevelDown",onMouseDown="global/buttonClicked",onMouseUp="global/buttonClicked",onClick="global/addjustCityLevel",height=50,width=50,color="rgba(0,0,0,0.0)",position="65 60 -30",rotation="0 0 180"},children={{tag="Image",attributes={id=cityGUID..terrainGUID.."LevelDownImage",image="Overkill Down"}}}}
		end
		if state.canAddMegapolis then
			buttonXML[#buttonXML+1]={tag="Button",attributes={id=cityGUID..terrainGUID.."MegapolisAdd",onMouseDown="global/buttonClicked",onMouseUp="global/buttonClicked",onClick="global/addjustCityLevel",height=80,width=80,color="rgba(0,0,0,0.0)",position="-100 0 -25",rotation="0 0 180"},children={{tag="Image",attributes={id=cityGUID..terrainGUID.."MegapolisAddImage",image="Megapolis Add"}}}}
		end
		if state.canRemoveMegapolis then
			buttonXML[#buttonXML+1]={tag="Button",attributes={id=cityGUID..terrainGUID.."MegapolisSubtract",onMouseDown="global/buttonClicked",onMouseUp="global/buttonClicked",onClick="global/addjustCityLevel",height=80,width=80,color="rgba(0,0,0,0.0)",position="-100 0 -25",rotation="0 0 180"},children={{tag="Image",attributes={id=cityGUID..terrainGUID.."MegapolisSubtractImage",image="Megapolis Subtract"}}}}
		end
		if #buttonXML==0 then buttonXML={{}} end
		cityObj.UI.setXmlTable(buttonXML)
	end,0.5)
end

--Change an already-deployed City's stored level/Megapolis state, then rebuild only its display and garrison.
function addjustCityLevel(player, mouseButton, id)
	if mouseButton~="-1" then return end
	local cityGUID=id:sub(1,6)
	local terrainGUID=id:sub(7,12)
	local state=cityControlState(cityGUID,terrainGUID)
	local changed=false
	if id:find("LevelUp",1,true)~=nil and state.canLevelUp then
		if terrainGUID=="Volkar" then gStates.volkareLevel=state.level+1 else gStates.cityLevels[gStates.cityDeployOrder[cityGUID]]=state.level+1 end
		changed=true
	elseif id:find("LevelDown",1,true)~=nil and state.canLevelDown then
		if terrainGUID=="Volkar" then gStates.volkareLevel=state.level-1 else gStates.cityLevels[gStates.cityDeployOrder[cityGUID]]=state.level-1 end
		changed=true
	elseif id:find("MegapolisAdd",1,true)~=nil and state.canAddMegapolis then
		changed=addCityMegapolis(cityGUID,terrainGUID)
	elseif id:find("MegapolisSubtract",1,true)~=nil and state.canRemoveMegapolis then
		changed=removeCityMegapolis(cityGUID,terrainGUID)
	end
	if changed then scheduleCityRebuild(cityGUID,terrainGUID) end
end

--Refresh all deployed City level/Megapolis controls from their authoritative stored state.
function addCityButtons()
	if gStates.gameScenario~="The Lost Relic Blitz" then
		for deployedCityGUID, _ in pairs(gStates.cityDeployOrder or {}) do
			local data=gStates.cityMonsterQty~=nil and gStates.cityMonsterQty[deployedCityGUID] or nil
			local terrainGUID=data~=nil and data.extra~=nil and data.extra.terainGUID or nil
			if terrainGUID~=nil and getObjectFromGUID(deployedCityGUID)~=nil then cityLevelButtons(deployedCityGUID,terrainGUID) end
		end
		if gStates.volkareModel~=nil and getObjectFromGUID(gStates.volkareModel)~=nil then cityLevelButtons(gStates.volkareModel,"Volkar") end
	end
end

function cityCardMapSnapshot()
	local mapObj=getObjectFromGUID(mapArea)
	if mapObj==nil then return {} end
	local mapObjects={}
	for _, playObj in pairs(mapObj.getObjects()) do mapObjects[#mapObjects+1]={guid=playObj.guid, position=playObj.getPosition()} end
	return mapObjects
end

function cityCardExploreGroup(cityZone)
	local details=cityScriptZones[cityZone]
	local cityGUID=details~=nil and details.cityGUID or nil
	local cityData=cityGUID~=nil and gStates.cityMonsterQty[cityGUID] or nil
	local cardGUID=cityGUID~=nil and gStates.cityCard[cityGUID] or nil
	local card=cardGUID~=nil and getObjectFromGUID(cardGUID) or nil
	local cityModelObj=cityGUID~=nil and getObjectFromGUID(cityGUID) or nil
	if cityData==nil or cityData.extra==nil or cityData.extra.megapolisPending==true or card==nil or cityModelObj==nil then return nil end
	--A Megapolis shares one physical card. The City whose pair points outward owns the card movement.
	if cityData.extra.megapolisPair~=nil and cityData.extra.megapolisPair==cityGUID then return nil end
	local zonesToMove={[cityZone]=true}
	if cityData.extra.megapolisPair~=nil then
		local cityModelToZone={[cityModel.blue]=GUID.zone.blueCity, [cityModel.red]=GUID.zone.redCity, [cityModel.green]=GUID.zone.greenCity, [cityModel.white]=GUID.zone.whiteCity}
		local pairZone=cityModelToZone[cityData.extra.megapolisPair]
		if pairZone~=nil then zonesToMove[pairZone]=true end
	end
	local movingGUIDs={[card.guid]=true}
	for zoneGUID, _ in pairs(zonesToMove) do
		local zoneObj=getObjectFromGUID(zoneGUID)
		if zoneObj~=nil then for _, obj in pairs(zoneObj.getObjects()) do movingGUIDs[obj.guid]=true end end
	end
	return {cityGUID=cityGUID, card=card, city=cityModelObj, zones=zonesToMove, movingGUIDs=movingGUIDs}
end

function cityCardPositionForbidden(desiredLocation)
	local x=desiredLocation[1]
	local z=desiredLocation[3]
	return (x>-18.5 and x<-18.0 and z>-18.5 and z<-18.0) or (x>-13.5 and x<-13.0 and z>-14.5 and z<-13.5)
end

function cityCardExploreSpaceFree(mapObjects, desiredLocation, movingGUIDs, extraBlockedPos, reservedPositions)
	if cityCardPositionForbidden(desiredLocation)==true then return false end
	if extraBlockedPos~=nil then
		local blockZ=extraBlockedPos[3] or extraBlockedPos[2]
		if ((desiredLocation[1]-extraBlockedPos[1])^2)+((desiredLocation[3]-blockZ)^2)<9.61 then return false end
	end
	for _, reservedPos in ipairs(reservedPositions or {}) do
		if ((desiredLocation[1]-reservedPos[1])^2)+((desiredLocation[3]-reservedPos[3])^2)<9.61 then return false end
	end
	for _, button in pairs(gStates.exploreButtons or {}) do
		if button.attributes~=nil and button.attributes.tilePosX~=nil and button.attributes.tilePosZ~=nil and
			((desiredLocation[1]-tonumber(button.attributes.tilePosX))^2)+((desiredLocation[3]-tonumber(button.attributes.tilePosZ))^2)<9.61 then return false end
	end
	movingGUIDs=movingGUIDs or {}
	for _, playObj in pairs(mapObjects or {}) do
		if movingGUIDs[playObj.guid]~=true and ((desiredLocation[1]-playObj.position[1])^2)+((desiredLocation[3]-playObj.position[3])^2)<9.61 then return false end
	end
	return true
end

--Shared placement engine used both when a City first deploys and whenever EXPLORE positions later force
--City-card groups to move. preferredOffset is used by The Gauntlet's fixed City-card side when it is legal.
function findCityCardPosition(cityPos, mapObjects, movingGUIDs, extraBlockedPos, reservedPositions, preferredOffset)
	if preferredOffset~=nil and cityCardExploreOffsets[preferredOffset]~=nil then
		local offset=cityCardExploreOffsets[preferredOffset]
		local preferred={cityPos[1]+offset[1],1.09,cityPos[3]+offset[3]}
		if cityCardExploreSpaceFree(mapObjects,preferred,movingGUIDs,extraBlockedPos,reservedPositions)==true then
			local distance=math.sqrt((offset[1]^2)+(offset[3]^2))
			return preferred,distance
		end
	end
	local best=nil
	local bestDistance=nil
	for _, offset in ipairs(cityCardExploreOffsets) do
		local desired={cityPos[1]+offset[1],1.09,cityPos[3]+offset[3]}
		if cityCardExploreSpaceFree(mapObjects,desired,movingGUIDs,extraBlockedPos,reservedPositions)==true then
			local distance=math.sqrt((offset[1]^2)+(offset[3]^2))
			if bestDistance==nil or distance<bestDistance-0.05 then best=desired bestDistance=distance end
		end
	end
	return best,bestDistance
end

function moveCityCardExploreGroup(group, desiredLocation, movedCityZones, mapObjects)
	local cardPos=group.card.getPosition()
	local deltaX=desiredLocation[1]-cardPos[1]
	local deltaZ=desiredLocation[3]-cardPos[3]
	if math.sqrt((deltaX^2)+(deltaZ^2))<0.25 then return false end
	local movedObjects={}
	for zoneGUID, _ in pairs(group.zones) do
		local zoneObj=getObjectFromGUID(zoneGUID)
		if zoneObj~=nil then
			if movedCityZones~=nil then movedCityZones[zoneGUID]=true end
			for _, cityCardObj in pairs(zoneObj.getObjects()) do
				if movedObjects[cityCardObj.guid]~=true and cityCardObj.guid~='3d4319' and cityCardObj.guid~='519f96' then
					movedObjects[cityCardObj.guid]=true
					local originalPos=cityCardObj.getPosition()
					local relocation={originalPos[1]+deltaX, originalPos[2], originalPos[3]+deltaZ}
					cityCardObj.setPositionSmooth(relocation)
					if gStates.monsterPlayLocation[cityCardObj.guid]~=nil then gStates.monsterPlayLocation[cityCardObj.guid]=relocation end
				end
			end
			local zonePos=zoneObj.getPosition()
			zoneObj.setPosition({zonePos[1]+deltaX, zonePos[2], zonePos[3]+deltaZ})
		end
	end
	if movedObjects[group.card.guid]~=true then group.card.setPositionSmooth(desiredLocation) end
	if mapObjects~=nil then
		for _, playObj in pairs(mapObjects) do
			if group.movingGUIDs[playObj.guid]==true then playObj.position={playObj.position[1]+deltaX, playObj.position[2], playObj.position[3]+deltaZ} end
		end
	end
	return true
end

--Place one City-card group at the closest currently legal ring position. If its present position is already
--equally close and legal, leave it alone. If the present position is blocked by EXPLORE, moving outward is allowed.
function positionCityCardForExplore(cityZone, extraBlockedPos, movedCityZones, reservedPositions, mapObjects)
	if movedCityZones~=nil and movedCityZones[cityZone]==true then return false end
	local group=cityCardExploreGroup(cityZone)
	if group==nil then return false end
	if mapObjects==nil then mapObjects=cityCardMapSnapshot() end
	local cityPos=group.city.getPosition()
	local cardPos=group.card.getPosition()
	local currentDistance=math.sqrt(((cardPos[1]-cityPos[1])^2)+((cardPos[3]-cityPos[3])^2))
	local currentFree=cityCardExploreSpaceFree(mapObjects,cardPos,group.movingGUIDs,extraBlockedPos,reservedPositions)
	local best,bestDistance=findCityCardPosition(cityPos,mapObjects,group.movingGUIDs,extraBlockedPos,reservedPositions)
	if best==nil then return false end
	if currentFree==true and currentDistance<=bestDistance+0.25 then return false end
	if reservedPositions~=nil then reservedPositions[#reservedPositions+1]=best end
	return moveCityCardExploreGroup(group,best,movedCityZones,mapObjects)
end

--Used immediately before a chosen EXPLORE tile is placed. Normally the refresh pass has already moved cards,
--but this protects against a card being manually moved back over the selected terrain position.
function relocateCityCardForExplore(pos, movedCityZones)
	local mapObj=getObjectFromGUID(mapArea)
	if mapObj==nil then return false end
	local posX=pos[1]
	local posZ=pos[3] or pos[2]
	local cityCardTest={}
	for _, cityZone in ipairs({GUID.zone.whiteCity, GUID.zone.blueCity, GUID.zone.redCity, GUID.zone.greenCity}) do
		local cityGUID=cityScriptZones[cityZone].cityGUID
		cityCardTest[gStates.cityCard[cityGUID]]=cityZone
	end
	for _, mightBeCityCard in pairs(mapObj.getObjects()) do
		local cityZone=cityCardTest[mightBeCityCard.guid]
		if cityZone~=nil and (movedCityZones==nil or movedCityZones[cityZone]~=true) then
			local cardPos=mightBeCityCard.getPosition()
			if math.sqrt(((posX-cardPos[1])^2)+((posZ-cardPos[3])^2))<3 then return positionCityCardForExplore(cityZone, pos, movedCityZones) end
		end
	end
	return false
end

--After the complete EXPLORE set is rebuilt, every City card gets one placement decision from the finished state.
--This both pushes blocked cards outward and brings displaced cards back inward without racing two smooth moves.
function compactCityCardsAfterExplore(mapObjects)
	local movedCityZones={}
	local reservedPositions={}
	for _, cityZone in ipairs({GUID.zone.blueCity, GUID.zone.redCity, GUID.zone.greenCity, GUID.zone.whiteCity}) do positionCityCardForExplore(cityZone, nil, movedCityZones, reservedPositions, mapObjects) end
	positionApocalypseDragonHeads()
end

function cityBonusDecals(obj1, obj2)--obj2 is the rare case of a summoned monster. otherwise will be a duplicate of obj1
	local cityFound=false
	for _, cityDetail in pairs(gStates.cityMonsterQty) do
		for monsterGUID, monsterDetail in pairs(cityDetail) do
			if obj1.guid==monsterGUID then
				cityFound=true
				if cityDetail.extra~=nil and cityDetail.extra.monsterPerk~=nil then
					for _, perk in pairs(cityDetail.extra.monsterPerk) do
						--defense white city
						if perk=="Defense" and obj1.guid==obj2.guid then
							local found=false
							if obj2.getDecals()~=nil then
								for _, decalDetails in pairs(obj2.getDecals()) do
									if decalDetails.name=="Defense" then found=true break end
								end
							end
							if found==false then
								obj2.addDecal({name="Defense", url="https://steamusercontent-a.akamaihd.net/ugc/14077412532545838280/E5508FB0ADB512C72FA29D49665D051B12B8C015/",	position={0.0, 0.15, -1.2}, rotation={90, 180, 0}, scale={0.72, 0.72, 1}})
								if gStates.monsterPerks[obj2.guid]==nil then
									gStates.monsterPerks[obj2.guid]={armour=1}
								else if gStates.monsterPerks[obj2.guid].armour==nil then
									gStates.monsterPerks[obj2.guid].armour=1
								else
									gStates.monsterPerks[obj2.guid].armour=gStates.monsterPerks[obj2.guid].armour+1
								end end
							end
						end
						--working
						if (perk=="Poison" or perk=="Brutal") and monsterPugs[obj2.guid].attack~=nil and monsterPugs[obj2.guid].attack.P~=nil then
							--poison green city
							if perk=="Poison" and monsterPugs[obj2.guid].poison==nil then
								local found=false
								if obj2.getDecals()~=nil then
									for _, decalDetails in pairs(obj2.getDecals()) do
										if decalDetails.name=="Poison" then found=true break end
									end
								end
								if found==false then
									obj2.addDecal({name="Poison", url="https://steamusercontent-a.akamaihd.net/ugc/14643102332043313249/96E1CF040B17404D1588A4605EE52C1D965BDB91/", position={-1.1, 0.15, 0.25}, rotation={90, 180, 0}, scale={0.72, 0.72, 1}})
									if gStates.monsterPerks[obj2.guid]==nil then gStates.monsterPerks[obj2.guid]={poison=true} else gStates.monsterPerks[obj2.guid].poison=true end
								end
							end
							--brutal red city
							if perk=="Brutal" and monsterPugs[obj2.guid].brutal==nil then
								local found=false
								if obj2.getDecals()~=nil then
									for _, decalDetails in pairs(obj2.getDecals()) do
										if decalDetails.name=="Brutal" then found=true break end
									end
								end
								if found==false then
									obj2.addDecal({name="Brutal", url="https://steamusercontent-a.akamaihd.net/ugc/14173504696154614110/C885A392A7488395AEB158E0DAA7EA420F9C4560/", position={-1.1, 0.15, -0.25}, rotation={90, 180, 0}, scale={0.72, 0.72, 1}})
									if gStates.monsterPerks[obj2.guid]==nil then gStates.monsterPerks[obj2.guid]={brutal=true} else gStates.monsterPerks[obj2.guid].brutal=true end
								end
							end
						end
						--Elemental blue city
						if perk=="Elemental" and monsterPugs[obj2.guid].attack~=nil and (monsterPugs[obj2.guid].attack.F~=nil or monsterPugs[obj2.guid].attack.I~=nil or monsterPugs[obj2.guid].attack.IF~=nil) then
							local found=false
							if obj2.getDecals()~=nil then
								for _, decalDetails in pairs(obj2.getDecals()) do
									if decalDetails.name=="Elemental" then found=true break end
								end
							end
							if found==false then
								if monsterPugs[obj2.guid].attack.F~=nil then obj2.addDecal({name="Elemental", url="https://steamusercontent-a.akamaihd.net/ugc/16538185383378416975/FF72CBB04DFA1D89DCB6C3356177742E8DB1E158/",
								position={1.2, 0.15, 0}, rotation={90, 180, 0}, scale={0.72, 0.72, 1}}) end
								if monsterPugs[obj2.guid].attack.I~=nil then obj2.addDecal({name="Elemental", url="https://steamusercontent-a.akamaihd.net/ugc/9791017606312731760/513FDEBA51FAA3B632DB8AF7B771FA55C313812C/",
								position={1.2, 0.15, 0.05}, rotation={90, 180, 0}, scale={0.72, 0.72, 1}}) end
								if monsterPugs[obj2.guid].attack.IF~=nil then obj2.addDecal({name="Elemental", url="https://steamusercontent-a.akamaihd.net/ugc/14515872358476191157/9FEEB6A9316CEA6B6B261E39E1DD399A22BE0A78/",
								position={1.2, 0.15, 0}, rotation={90, 180, 0}, scale={0.72, 0.72, 1}}) end
								if gStates.monsterPerks[obj2.guid]==nil then gStates.monsterPerks[obj2.guid]={elemental=true} else gStates.monsterPerks[obj2.guid].elemental=true end
							end
						end
						--fortified
						if perk=="Fortified" and monsterPugs[obj2.guid].unfortified==nil and gStates.gameScenario~="The Chaos Rift" and obj1.guid==obj2.guid then
							local found=false
							if obj2.getDecals()~=nil then
								for _, decalDetails in pairs(obj2.getDecals()) do
									if decalDetails.name=="Fortified" then found=true break end
								end
							end
							if found==false then
								obj2.addDecal({name="Fortified", url="https://steamusercontent-a.akamaihd.net/ugc/15769941683634999180/45D8BF9859C1F2C026A3B40DA634B74286E2C3EB/", position={0.8, 0.15, -0.8}, rotation={90, 180, 0}, scale={0.72, 0.72, 1}})
								if gStates.monsterPerks[obj2.guid]==nil then gStates.monsterPerks[obj2.guid]={fortified=true} else gStates.monsterPerks[obj2.guid].fortified=true end
							end
						end
					end
					break
				end
			end
		end
		if cityFound==true then break end
	end
end

function cityControlTerrainGUID(city, monsterList)
	if city==volkare.model or city==gStates.volkareModel then return "Volkar" end
	if type(monsterList)=="table" and type(rawget(monsterList,"extra"))=="table" and monsterList.extra.terainGUID~=nil then return monsterList.extra.terainGUID end
	return city
end

function refreshLockedCityControl(city, monsterList, force)
	local terrainGUID=cityControlTerrainGUID(city, monsterList)
	if cityControlLockedByReveal(city, terrainGUID)~=true then cityMaintenanceLockSeen[city]=nil return false end
	if force~=true and cityMaintenanceLockSeen[city]==true then return true end

	if city==elementalist.terrainHex or city==darkCrusader.terrainHex then
		local cityObj=getObjectFromGUID(city)
		local deployIndex=gStates.cityDeployOrder~=nil and gStates.cityDeployOrder[city] or nil
		local displayLevel=deployIndex~=nil and gStates.cityLevels[deployIndex] or 0
		if cityObj~=nil then
			cityObj.UI.setXmlTable({{tag="Image", attributes={image="Overkill Text", height=50, width=50, position="0 60 -25", rotation="0 0 180"},
				children={{tag="Text", attributes={id=city.."Overkill", color="rgb(0,0,0)",
				fontSize="35", fontStyle="Bold", alignment="MiddleCenter", text=displayLevel}}}}})
		end
	elseif terrainGUID=="Volkar" then
		if gStates.volkareModel~=nil and getObjectFromGUID(gStates.volkareModel)~=nil then cityLevelReadoutOnly(gStates.volkareModel,"Volkar") end
	else
		local cityObj=getObjectFromGUID(city)
		if cityObj~=nil then
			if terrainGUID~=nil then cityLevelReadoutOnly(city,terrainGUID) else cityObj.UI.setXmlTable({{}}) end
		end
	end
	gStates.volkareLock=false
	cityMaintenanceLockSeen[city]=true
	return true
end

function refreshCityRevealControls()
	for city, monsterList in pairs(gStates.cityMonsterQty or {}) do refreshLockedCityControl(city, monsterList, false) end
end

--Manual/automatic flips can remove the controls immediately; the slow maintenance tick remains a fallback
--for defeated tokens, leader movement and unusual TTS interactions.
function refreshCityRevealForMonster(monsterGUID)
	if monsterGUID==nil then return end
	Wait.frames(function()
		for city, monsterList in pairs(gStates.cityMonsterQty or {}) do
			if type(monsterList)=="table" and rawget(monsterList,monsterGUID)~=nil then refreshLockedCityControl(city, monsterList, true) return end
		end
	end, 1)
end

function cityTargetDefeated(cityGUID)
	if gStates.cityMonsterQty==nil or gStates.cityMonsterQty[cityGUID]==nil then return false end
	for monsterGUID, state in pairs(gStates.cityMonsterQty[cityGUID]) do
		if monsterGUID~="extra" and state=="alive" then return false end
	end
	return true
end

--Refresh only city/faction defeat state. This deliberately avoids city-zone shield sorting and scoring work.
function refreshCityDefeatState()
	gStates.defeatedFaction=0
	gStates.defeatedCities={amount=0}
	gStates.defeatedFactionTest={}
	for cityZone, cityStuff in pairs(cityScriptZones) do
		local cityGUID=cityStuff.cityGUID
		---@diagnostic disable-next-line: assign-type-mismatch --mixed table: amount is integer, city GUID entries are booleans
		if gStates.defeatedCities[cityGUID]==nil then gStates.defeatedCities[cityGUID]=false end
		local cityMonsters=gStates.cityMonsterQty~=nil and gStates.cityMonsterQty[cityGUID] or nil
		if cityMonsters~=nil and cityMonsters.extra~=nil and cityMonsters.extra.megapolisPair~=cityGUID and cityTargetDefeated(cityGUID)==true then
			if cityGUID==darkCrusader.terrainHex or cityGUID==elementalist.terrainHex then
				gStates.defeatedFaction=gStates.defeatedFaction+1
				gStates.defeatedFactionTest[cityGUID]="Beat"
			else
				--War of Four needs conquered cities recorded when beaten rather than when first revealed.
				if gStates.gameScenario=="The War of Four" and cityZone~=darkCrusader.discZone and cityZone~=elementalist.discZone then
					local found=false
					for _, city in pairs(gStates.cityRevealed) do if city.model==cityGUID then found=true break end end
					if found==false then gStates.cityRevealed[#gStates.cityRevealed+1]={model=cityGUID, terrain=cityMonsters.extra.terainGUID} end
				end
				local deployIndex=gStates.cityDeployOrder~=nil and gStates.cityDeployOrder[cityGUID] or nil
				local cityLevel=deployIndex~=nil and gStates.cityLevels~=nil and gStates.cityLevels[deployIndex] or nil
				local friendly=gStates.friendlyCity~=nil and gStates.friendlyCity[cityGUID]==true
				if cityLevel~=0 and friendly==false then
					gStates.defeatedCities.amount=gStates.defeatedCities.amount+1
					---@diagnostic disable-next-line: assign-type-mismatch --mixed table: amount is integer, city GUID entries are booleans
					gStates.defeatedCities[cityGUID]=true
					local megapolisPair=cityMonsters.extra.megapolisPair
					if megapolisPair~=nil then gStates.defeatedCities[megapolisPair]=true end
				end
			end
		end
	end
end

--Authoritative rebuild of city/faction ownership and scoring. Use only when shields/scoring can have changed.
function cityBeatCheck()
	refreshCityDefeatState()
	local leadTest={}
	local factionAssistTest={}
	local bothTest=0
	gStates.allPlayersFoughtAFactionLeaderCheck=false
	gStates.allPlayersFoughtBothFactionLeaderCheck=false
	gStates.allLeaderCheck=false
	--Zero out any existing city/faction scores and ownership.
	local scoreVariable={"CityLead", "CityAssist", "ElemFactionAssist", "DarkFactionAssist", "ElemFactionLead", "DarkFactionLead"}
	for a=1, #turnOrder, 1 do
		turnOrder[a].defeatedCities={}
		for _, scoreName in ipairs(scoreVariable) do turnOrder[a].score[scoreName]=0 end
	end
	--Read each city/faction zone.
	for cityZone, cityStuff in pairs(cityScriptZones) do
		local cityGUID=cityStuff.cityGUID
		local cityMonsters=gStates.cityMonsterQty~=nil and gStates.cityMonsterQty[cityGUID] or nil
		local zoneObj=getObjectFromGUID(cityZone)
		if cityMonsters~=nil and cityMonsters.extra~=nil and cityMonsters.extra.megapolisPair~=cityGUID and zoneObj~=nil then
			local firstShield=true
			local objectsOnCity=zoneObj.getObjects()
			--Add Megapolis second-city items so either half contributes to the same ownership result.
			if cityMonsters.extra.megapolisPair~=nil then
				for cityZone2, cityStuff2 in pairs(cityScriptZones) do
					if cityStuff2.cityGUID==cityMonsters.extra.megapolisPair then
						local pairedZone=getObjectFromGUID(cityZone2)
						if pairedZone~=nil then
							for _, object in pairs(pairedZone.getObjects()) do
								local found=false
								for _, testObject in ipairs(objectsOnCity) do if testObject.guid==object.guid then found=true break end end
								if found==false then objectsOnCity[#objectsOnCity+1]=object end
							end
						end
					end
				end
			end
			--Sort shields into the physical tie-break order used for City/Faction leadership.
			if cityZone==darkCrusader.discZone or cityZone==elementalist.discZone then
				local tilePos=zoneObj.getPosition()
				table.sort(objectsOnCity, function(k1, k2)
					local rot=math.rad(90)
					local p1=k1.getPosition()
					local p2=k2.getPosition()
					local var1=math.atan2(((p1[3]-tilePos[3])*math.cos(rot))+((p1[1]-tilePos[1])*math.sin(rot)), ((p1[1]-tilePos[1])*math.cos(rot))-((p1[3]-tilePos[3])*math.sin(rot)))
					local var2=math.atan2(((p2[3]-tilePos[3])*math.cos(rot))+((p2[1]-tilePos[1])*math.sin(rot)), ((p2[1]-tilePos[1])*math.cos(rot))-((p2[3]-tilePos[3])*math.sin(rot)))
					return var1<var2
				end)
			else
				table.sort(objectsOnCity, function(k1, k2) return k1.getPosition()[1]<k2.getPosition()[1] end)
			end
			local cityScoring={}
			for _, shield in ipairs(objectsOnCity) do
				if shield.getName()=="Shield" then
					local mage=shield.getDescription()
					if cityScoring[mage]~=nil then cityScoring[mage]=cityScoring[mage]+1
					elseif firstShield==true then cityScoring[mage]=1.5 firstShield=false
					else cityScoring[mage]=1 end
				end
			end
			--Faction areas also count the scenario-specific Graveyard/Glade contributions.
			if (cityZone==darkCrusader.discZone or cityZone==elementalist.discZone) and (gStates.coop==0 or gStates.WarOfFourComp==true) then
				for c=1, #turnOrder, 1 do
					if turnOrder[c].mage~=gStates.positionMageKnight[5] then
						if cityScoring[turnOrder[c].mage]==nil then cityScoring[turnOrder[c].mage]=0 end
						if cityZone==elementalist.discZone then cityScoring[turnOrder[c].mage]=cityScoring[turnOrder[c].mage]+turnOrder[c].score.Glade end
						if cityZone==darkCrusader.discZone then cityScoring[turnOrder[c].mage]=cityScoring[turnOrder[c].mage]+turnOrder[c].score.GraveYard end
					end
				end
			end
			local highest={0, nil}
			--City control and City scoring are deliberately separate. A scenario-friendly City gives every
			--player with a Shield the normal Assist hand-size benefit, but has no Leader and never awards
			--City scoring or counts toward conquered-city victory conditions.
			local standardCity=cityGUID~=darkCrusader.terrainHex and cityGUID~=elementalist.terrainHex
			local conqueredCity=gStates.defeatedCities[cityGUID]==true
			local friendlyCity=gStates.friendlyCity~=nil and gStates.friendlyCity[cityGUID]==true
			if standardCity and (conqueredCity or friendlyCity) then
				for mage, value in pairs(cityScoring) do
					for c=1, #turnOrder, 1 do
						if turnOrder[c].mage==mage then
							if conqueredCity then turnOrder[c].score.CityAssist=turnOrder[c].score.CityAssist+1 end
							turnOrder[c].defeatedCities[cityGUID]="Assist"
							if cityMonsters.extra.megapolisPair~=nil then turnOrder[c].defeatedCities[cityMonsters.extra.megapolisPair]="Assist" end
							if highest[1]<value then highest[1]=value highest[2]=mage end
							break
						end
					end
				end
				if conqueredCity then
					for c=1, #turnOrder, 1 do
						if turnOrder[c].mage==highest[2] then
							turnOrder[c].score.CityAssist=turnOrder[c].score.CityAssist-1
							turnOrder[c].score.CityLead=turnOrder[c].score.CityLead+1
							leadTest[c]=true
							turnOrder[c].defeatedCities[cityGUID]="Lead"
							if cityMonsters.extra.megapolisPair~=nil then turnOrder[c].defeatedCities[cityMonsters.extra.megapolisPair]="Lead" end
							break
						end
					end
				end
			end
			--Faction Leader scoring retains the existing contribution behaviour.
			if cityZone==darkCrusader.discZone or cityZone==elementalist.discZone then
				local factionBothAssistTest={}
				highest={0, nil}
				for mage, value in pairs(cityScoring) do
					if value>0 then
						for c=1, #turnOrder, 1 do
							if turnOrder[c].mage==mage then
								if cityZone==elementalist.discZone then turnOrder[c].score.ElemFactionAssist=turnOrder[c].score.ElemFactionAssist+1 end
								if cityZone==darkCrusader.discZone then turnOrder[c].score.DarkFactionAssist=turnOrder[c].score.DarkFactionAssist+1 end
								if highest[1]<value then highest[1]=value highest[2]=mage end
								factionAssistTest[turnOrder[c].mage]=true
								factionBothAssistTest[turnOrder[c].mage]=true
								break
							end
						end
					end
				end
				for c=1, #turnOrder, 1 do
					if turnOrder[c].mage==highest[2] then
						if cityZone==darkCrusader.discZone then
							turnOrder[c].score.DarkFactionAssist=turnOrder[c].score.DarkFactionAssist-1
							turnOrder[c].score.DarkFactionLead=turnOrder[c].score.DarkFactionLead+1
						end
						if cityZone==elementalist.discZone then
							turnOrder[c].score.ElemFactionAssist=turnOrder[c].score.ElemFactionAssist-1
							turnOrder[c].score.ElemFactionLead=turnOrder[c].score.ElemFactionLead+1
						end
						break
					end
				end
				local count=0
				for _ in pairs(factionBothAssistTest) do count=count+1 end
				if count==#turnOrder-1 then bothTest=bothTest+1 end
			end
		end
	end
	local count=0
	for _ in pairs(leadTest) do count=count+1 end
	if count==#turnOrder-1 then gStates.allLeaderCheck=true end
	if bothTest==2 then gStates.allPlayersFoughtBothFactionLeaderCheck=true end
	count=0
	for _ in pairs(factionAssistTest) do count=count+1 end
	if count==#turnOrder-1 then gStates.allPlayersFoughtAFactionLeaderCheck=true end
end

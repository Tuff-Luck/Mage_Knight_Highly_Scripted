-- Player movement guidance and digital movement-cost display.

--Fractured Lands: show the folding-corridor marker on every other explored hex matching
--the active Mage Knight's current terrain type. These are guidance only; movement stays manual.
fracturedLandsTeleportDecalName="Fractured Lands Teleport"
fracturedLandsTeleportDecalURL="https://steamusercontent-a.akamaihd.net/ugc/9408415852573608798/AAD04981F964B49DD1479EFE6DFBD6D294294B82/"
function fracturedLandsTeleportHexLegal(hexType)
	if hexType==nil or hexType=="" or hexType=="ocean" then return false end
	if gStates.moveCost~=nil and gStates.moveCost[hexType]~=nil then return gStates.moveCost[hexType]<900 end
	return hexType~="lake" and hexType~="mountain"
end
function fracturedLandsTeleportRampageKey(terrainGUID, bearing)
	return tostring(terrainGUID).."|"..tostring(bearing)
end
function fracturedLandsTeleportRecordDefeatedRampager(position)
	if gStates.gameScenario~="The Fractured Lands Blitz" or position==nil then return end
	local hex=runtimeMapHexAtPosition(position)
	if hex==nil or (hex.feature~="rampaging" and hex.feature~="draconum") then return end
	if gStates.fracturedLandsDefeatedRampagingHexes==nil then gStates.fracturedLandsDefeatedRampagingHexes={} end
	gStates.fracturedLandsDefeatedRampagingHexes[fracturedLandsTeleportRampageKey(hex.terrainGUID,hex.bearing)]=true
end
function fracturedLandsTeleportHexSafeNoSite(hex,spatial)
	if hex==nil or hex.position==nil or spatial==nil then return false end
	local feature=hex.feature or ""
	local noSite=feature=="" or feature=="portal"
	if feature=="monastery" and gStates.monasteryBurned~=nil and gStates.monasteryBurned[hex.terrainGUID]==true then noSite=true end
	if feature=="rampaging" or feature=="draconum" then
		local cleared=gStates.fracturedLandsDefeatedRampagingHexes or {}
		noSite=cleared[fracturedLandsTeleportRampageKey(hex.terrainGUID,hex.bearing)]==true
	end
	if noSite~=true then return false end
	--A safe destination cannot currently contain an enemy or another Mage Knight.
	for _, obj in ipairs(runtimeMapSpatialNearbyObjects(spatial,hex.position,1.1)) do
		local pos=spatial.positions[obj.guid] or obj.getPosition()
		if ((pos[1]-hex.position[1])^2)+((pos[3]-hex.position[3])^2)<1 then
			if monsterPugs[obj.guid]~=nil then return false end
			if feature~="portal" then
				for _, details in pairs(mageKnights) do
					if obj.guid==details.model or obj.guid==details.token or obj.guid==details.standee then return false end
				end
			end
		end
	end
	return true
end
function fracturedLandsTeleportSourcePosition(playerIndex)
	local player=turnOrder[playerIndex]
	if player==nil or player.mage==gStates.positionMageKnight[5] or coopAssaultVirtualPlayer(playerIndex)==true then return nil end
	local avatar=coopAssaultAvatarObject(playerIndex)
	if avatar==nil then return nil end
	local position=avatar.getPosition()
	--Avatars physically sit on City cards after entering a City, so translate that back to the map hex.
	for zone, citySearch in pairs(cityScriptZones) do
		local zoneObj=getObjectFromGUID(zone)
		if zoneObj~=nil then
			for _, obj in pairs(zoneObj.getObjects()) do
				if obj.guid==avatar.guid then
					local cityObj=nil
					if zone==volkare.discZone and gStates.volkareModel~=nil then cityObj=getObjectFromGUID(gStates.volkareModel) else cityObj=getObjectFromGUID(citySearch.cityGUID) end
					if cityObj~=nil then position=cityObj.getPosition() end
					return position
				end
			end
		end
	end
	return position
end
function fracturedLandsTeleportDecals()
	local decals={}
	if gStates.gameScenario~="The Fractured Lands Blitz" or gStates.firstStarted~=true or turnOrder[gStates.turnNumber]==nil then return decals end
	local sourcePos=fracturedLandsTeleportSourcePosition(gStates.turnNumber)
	if sourcePos==nil then return decals end
	local spatial=runtimeMapSpatialSnapshot()
	local snapshot=spatial.topology
	local sourceHex=runtimeMapHexAtPosition(sourcePos,snapshot)
	if sourceHex==nil or fracturedLandsTeleportHexLegal(sourceHex.hexType)~=true then return decals end
	local sourceKey=runtimeMapHexKey(sourceHex)
	for _, hex in ipairs(snapshot.hexes or {}) do
		if hex.hexType==sourceHex.hexType and fracturedLandsTeleportHexLegal(hex.hexType)==true and runtimeMapHexKey(hex)~=sourceKey then
			if fracturedLandsTeleportHexSafeNoSite(hex,spatial)==true then
				decals[#decals+1]={name=fracturedLandsTeleportDecalName, url=fracturedLandsTeleportDecalURL,
					position={hex.position[1],1.12,hex.position[3]}, rotation={90,0,0}, scale={2.0,2.0,1}}
			end
		end
	end
	return decals
end
function refreshFracturedLandsTeleportHighlights()
	--Fresh-start games never switch scenarios mid-game, so non-Fractured-Lands games do not need to touch Global decals every turn.
	if gStates.gameScenario~="The Fractured Lands Blitz" then return end
	local existing=Global.getDecals() or {}
	local decals={}
	for _, decal in pairs(existing) do if decal.name~=fracturedLandsTeleportDecalName then decals[#decals+1]=decal end end
	for _, decal in pairs(fracturedLandsTeleportDecals()) do decals[#decals+1]=decal end
	Global.setDecals(decals)
end

moveDisplayAutoPause=nil
moveDisplayBaseVectorLines=nil
moveDisplayRefreshDelay=0.75
moveDisplayTerrainCache={signature=nil, hexMap=nil}
moveDisplayTextSlotRequests={}
moveDisplayTextSpawning={}
MOVE_DISPLAY_BEARING_ADJUST={center={0,0}, ["0"]={0,-1}, ["60"]={-1,-1}, ["120"]={-1,0}, ["180"]={0,1}, ["240"]={1,1}, ["300"]={1,0}}
MOVE_DISPLAY_WALL_ADJUST={
	["0"]={ ["300"]={0.5,-0.5}, ["center"]={0,-0.5}, ["60"]={-0.5,-0.5}},
	["60"]={ ["0"]={-0.5,-1}, ["center"]={-0.5,-0.5}, ["120"]={-1,-0.5}},
	["120"]={ ["60"]={-1,-0.5}, ["center"]={-0.5,0}, ["180"]={-0.5,0.5}},
	["180"]={ ["120"]={-0.5,0.5}, ["center"]={0,0.5}, ["240"]={0.5,1}},
	["240"]={ ["180"]={0.5,1}, ["center"]={0.5,0.5}, ["300"]={1,0.5}},
	["300"]={ ["240"]={1,0.5}, ["center"]={0.5,0}, ["0"]={0.5,-0.5}},
	["center"]={ ["0"]={0,-0.5}, ["60"]={-0.5,-0.5}, ["120"]={-0.5,0}, ["180"]={0,0.5}, ["240"]={0.5,0.5}, ["300"]={0.5,0}}
}
MOVE_DISPLAY_VECTORS={{0,-1}, {-1,-1}, {-1,0}, {0,1}, {1,1}, {1,0}}
MOVE_DISPLAY_RAMPAGE_ADJACENT={{1,0}, {0,-1}, {-1,-1}, {-1,0}, {0,1}, {1,1}, {1,0}, {0,-1}}
MOVE_DISPLAY_RAMPAGE_WALL={{0.5,-0.5}, {-0.5,-1}, {-1,-0.5}, {-0.5,0.5}, {0.5,1}, {1,0.5}, {0.5,-0.5}}
MOVE_DISPLAY_CITY_GUIDS=nil
function moveDisplayCityGUIDLookup()
	if MOVE_DISPLAY_CITY_GUIDS==nil then
		MOVE_DISPLAY_CITY_GUIDS={
			[cityModel.white]=true, [cityModel.blue]=true, [cityModel.red]=true, [cityModel.green]=true,
			[volkare.terrainHex]=true, [darkCrusader.terrainHex]=true, [elementalist.terrainHex]=true
		}
	end
	return MOVE_DISPLAY_CITY_GUIDS
end

function moveDisplayCloneHexMap(source)
	local copy={}
	for hor, row in pairs(source or {}) do
		local rowCopy={}
		copy[hor]=rowCopy
		for vec, hex in pairs(row) do
			local hexCopy={}
			rowCopy[vec]=hexCopy
			for key, value in pairs(hex) do hexCopy[key]=value end
		end
	end
	return copy
end

--Dungeon Lords turns every conquered Dungeon/Tomb into an underground network node. The tunnel
--distance ignores terrain costs and walls but can only cross revealed spaces, and may not cross Lakes/Swamps.
--Store the measured path as well as its 2+distance cost so the display can show how the price was found.
function moveDisplayDungeonLordsTunnelNetwork(hexMap,playAreaObjects,startTilePos)
	if gStates.gameScenario~="Dungeon Lords" then return {} end
	local nodes={}
	local nodeList={}
	local function gridForPosition(pos)
		local vec,hor=runtimeMapWorldToAxial(pos,startTilePos)
		return hor,vec
	end
	for _,obj in pairs(playAreaObjects or {}) do
		if isShieldObject(obj) and volkarePursuitShieldRegistered(obj)~=true then
			local hor,vec=gridForPosition(obj.getPosition())
			local row=hexMap[tostring(hor)]
			local hex=row~=nil and row[tostring(vec)] or nil
			if hex~=nil and (hex.feature=="dungeon" or hex.feature=="tomb") then
				local key=tostring(hor)..":"..tostring(vec)
				if nodes[key]==nil then
					nodes[key]={hor=hor,vec=vec,key=key}
					nodeList[#nodeList+1]=nodes[key]
				end
			end
		end
	end
	if #nodeList<2 then return {} end

	local function openForDistance(hor,vec)
		local row=hexMap[tostring(hor)]
		local hex=row~=nil and row[tostring(vec)] or nil
		if hex==nil or hex.tileGUID==nil then return false end
		local terrain=hex.terrainType or hex.hexType
		return terrain~=nil and terrain~="lake" and terrain~="swamp" and terrain~="ocean"
	end
	local network={}
	for _,source in ipairs(nodeList) do
		local visited={[source.key]={hor=source.hor,vec=source.vec,distance=0,prev=nil}}
		local queue={{hor=source.hor,vec=source.vec,key=source.key}}
		local head=1
		while head<=#queue do
			local current=queue[head]
			head=head+1
			local currentVisit=visited[current.key]
			for _,vector in ipairs(MOVE_DISPLAY_VECTORS) do
				local hor=current.hor+vector[1]
				local vec=current.vec+vector[2]
				local key=tostring(hor)..":"..tostring(vec)
				if visited[key]==nil and openForDistance(hor,vec)==true then
					visited[key]={hor=hor,vec=vec,distance=currentVisit.distance+1,prev=current.key}
					queue[#queue+1]={hor=hor,vec=vec,key=key}
				end
			end
		end
		for _,destination in ipairs(nodeList) do
			if destination.key~=source.key and visited[destination.key]~=nil then
				local path={}
				local cursor=destination.key
				while cursor~=nil do
					local step=visited[cursor]
					table.insert(path,1,{hor=step.hor,vec=step.vec})
					cursor=step.prev
				end
				if network[source.key]==nil then network[source.key]={} end
				network[source.key][#network[source.key]+1]={hor=destination.hor,vec=destination.vec,cost=2+visited[destination.key].distance,path=path}
			end
		end
	end
	return network
end

--Cache only the terrain/wall portion of the digital movement map. Dynamic shields, Cities and
--monsters are overlaid fresh each render. Position, rotation and printed hex data are part of the
--signature so a changed tile/site automatically rebuilds the base graph.
function moveDisplayBaseHexMap(startTileGUID, startTilePos)
	local snapshot=runtimeMapSnapshot()
	local terrainEntries=snapshot.terrainEntries or {}
	local signature=startTileGUID.."@"..string.format("%.3f,%.3f", startTilePos[1], startTilePos[3]).."|"..(snapshot.terrainSignature or "")
	if moveDisplayTerrainCache.signature==signature and moveDisplayTerrainCache.hexMap~=nil then return moveDisplayCloneHexMap(moveDisplayTerrainCache.hexMap) end

	local hexMap={}
	for _, entry in pairs(terrainEntries) do
		local details=entry.details
		local hexGridAxial,hexGridHorizontal=runtimeMapWorldToAxial(entry.position,startTilePos)
		for hexBearing, hexType in pairs(details.hexType) do
			local fixedBearing="center"
			if hexBearing~="center" then
				local adjusted=tonumber(hexBearing)-entry.rotationAdjust
				if adjusted<0 then adjusted=adjusted+360 end
				fixedBearing=tostring(adjusted)
			end
			local adjust=MOVE_DISPLAY_BEARING_ADJUST[fixedBearing]
			local mapHor=tostring(hexGridHorizontal+adjust[1])
			local mapVec=tostring(hexGridAxial+adjust[2])
			if hexMap[mapHor]==nil then hexMap[mapHor]={} end
			if hexMap[mapHor][mapVec]==nil then hexMap[mapHor][mapVec]={} end
			local mapHex=hexMap[mapHor][mapVec]
			mapHex.terrainType=hexType
			mapHex.feature=details.hexFeature[hexBearing]
			mapHex.tileGUID=entry.guid
			mapHex.bearing=hexBearing
			if mapHex.hexType==nil then mapHex.hexType=hexType end
			if (mapHex.feature=="keep" or mapHex.feature=="mage tower") and mapHex.fortified==nil then mapHex.fortified=mapHex.feature end
		end
		if details.wallList~=nil then
			for hexBearing, hexAdjacent in pairs(details.wallList) do
				for hexAdjacentBearing, _ in pairs(hexAdjacent) do
					local fixedBearing="center"
					if hexBearing~="center" then
						local adjusted=tonumber(hexBearing)-entry.rotationAdjust
						if adjusted<0 then adjusted=adjusted+360 end
						fixedBearing=tostring(adjusted)
					end
					local fixedAdjacentBearing="center"
					if hexAdjacentBearing~="center" then
						local adjusted=tonumber(hexAdjacentBearing)-entry.rotationAdjust
						if adjusted<0 then adjusted=adjusted+360 end
						fixedAdjacentBearing=tostring(adjusted)
					end
					local adjust=MOVE_DISPLAY_WALL_ADJUST[fixedBearing][fixedAdjacentBearing]
					local wallHor=tostring(hexGridHorizontal+adjust[1])
					local wallVec=tostring(hexGridAxial+adjust[2])
					if hexMap[wallHor]==nil then hexMap[wallHor]={} end
					hexMap[wallHor][wallVec]={hexType="wall"}
				end
			end
		end
	end
	moveDisplayTerrainCache={signature=signature, hexMap=hexMap}
	return moveDisplayCloneHexMap(hexMap)
end

function moveDisplayParkTextMarker(marker)
	if marker~=nil then marker.setPosition({0, -10, 0}) end
end

function moveDisplayApplyTextMarker(marker, request, slot, delayPosition)
	if marker==nil or request==nil then return end
	if marker.TextTool~=nil then
		marker.TextTool.setValue(request.value)
		marker.TextTool.setFontSize(request.fontSize)
		marker.TextTool.setFontColor(request.color)
	end
	if delayPosition==true then
		local markerGUID=marker.guid
		safeWaitFrames("Movement",function()
			local liveMarker=getObjectFromGUID(markerGUID)
			local latest=moveDisplayTextSlotRequests[slot]
			if liveMarker==nil then return end
			if latest~=nil and latest.generation==gStates.moveDisplayGeneration and slot<=(gStates.moveDisplayTextActiveCount or 0) then liveMarker.setPosition(latest.position)
			else moveDisplayParkTextMarker(liveMarker) end
		end, 2)
	else
		marker.setPosition(request.position)
	end
end

function moveDisplayRequestTextMarker(slot, request)
	moveDisplayTextSlotRequests[slot]=request
	gStates.moveDisplayTextGUIDs=gStates.moveDisplayTextGUIDs or {}
	local markerGUID=gStates.moveDisplayTextGUIDs[slot]
	local marker=markerGUID~=nil and getObjectFromGUID(markerGUID) or nil
	if marker~=nil then moveDisplayApplyTextMarker(marker, request, slot, false) return end
	if moveDisplayTextSpawning[slot]==true then return end
	moveDisplayTextSpawning[slot]=true
	safeSpawnObject("Movement",{type="3DText", position={request.position[1], -10, request.position[3]}, rotation={90,0,0}, scale={0.70,0.70,0.70}, sound=false, callback_function=function(newMarker)
		moveDisplayTextSpawning[slot]=nil
		gStates.moveDisplayTextGUIDs=gStates.moveDisplayTextGUIDs or {}
		gStates.moveDisplayTextGUIDs[slot]=newMarker.guid
		newMarker.setName("Move Cost Indicator")
		newMarker.setGMNotes("Move Cost Indicator")
		newMarker.interactable=false
		newMarker.setLock(true)
		local latest=moveDisplayTextSlotRequests[slot]
		if latest~=nil and latest.generation==gStates.moveDisplayGeneration and slot<=(gStates.moveDisplayTextActiveCount or 0) then moveDisplayApplyTextMarker(newMarker, latest, slot, true)
		else moveDisplayParkTextMarker(newMarker) end
	end})
end

function moveDisplayHideUnusedText(usedCount)
	usedCount=usedCount or 0
	gStates.moveDisplayTextActiveCount=usedCount
	gStates.moveDisplayTextGUIDs=gStates.moveDisplayTextGUIDs or {}
	for slot=usedCount+1, #gStates.moveDisplayTextGUIDs do
		moveDisplayTextSlotRequests[slot]=nil
		local marker=getObjectFromGUID(gStates.moveDisplayTextGUIDs[slot])
		if marker~=nil then moveDisplayParkTextMarker(marker) end
	end
end

function clearMoveDisplayVisuals()
	if moveDisplayAutoPause~=nil then Wait.stop(moveDisplayAutoPause) moveDisplayAutoPause=nil end
	gStates.moveDisplayGeneration=(gStates.moveDisplayGeneration or 0)+1
	moveDisplayTextSlotRequests={}
	moveDisplayHideUnusedText(0)
	if moveDisplayBaseVectorLines~=nil then
		Global.setVectorLines(moveDisplayBaseVectorLines)
		moveDisplayBaseVectorLines=nil
	end
end

function updateMoveDisplay(id)
	--With zero Move and no active markers there is nothing for the movement display to do.
	local moveValue=gStates.resourceTracker~=nil and gStates.resourceTracker.move~=nil and gStates.resourceTracker.move.move or 0
	local hasMoveMarkers=(gStates.moveDisplayTextActiveCount or 0)>0
	if moveValue<=0 and hasMoveMarkers==false then
		clearMoveDisplayVisuals()
		return
	end

	--Resource Tracker clicks redraw immediately. Background object/map refreshes retain their quiet period
	--so newly explored terrain still has time to settle before its map snapshot is taken.
	if id~=nil then
		if moveDisplayAutoPause~=nil then Wait.stop(moveDisplayAutoPause) moveDisplayAutoPause=nil end
		renderMoveDisplay(id)
		return
	end
	if moveDisplayAutoPause~=nil then Wait.stop(moveDisplayAutoPause) end
	moveDisplayAutoPause=safeWaitTime("Movement",function() moveDisplayAutoPause=nil renderMoveDisplay() end, moveDisplayRefreshDelay)
end

function renderMoveDisplay(id)
	--Preserve Global vector lines that existed before the movement display started.
	local moveValue=gStates.resourceTracker~=nil and gStates.resourceTracker.move~=nil and gStates.resourceTracker.move.move or 0
	if moveValue>0 and moveDisplayBaseVectorLines==nil then moveDisplayBaseVectorLines=Global.getVectorLines() or {} end

	gStates.moveDisplayGeneration=(gStates.moveDisplayGeneration or 0)+1
	local displayGeneration=gStates.moveDisplayGeneration
	moveDisplayTextSlotRequests={}
	gStates.moveDisplayTextGUIDs=gStates.moveDisplayTextGUIDs or {}
	gStates.moveDisplayTextActiveCount=0

	if moveValue<=0 then
		clearMoveDisplayVisuals()
		return
	end

	--Reuse movement text objects by slot. Only a larger display grows the pool; normal +/- clicks update
	--the existing TextTools in place instead of destroying and respawning every label.
	local moveTextZOffset=0.65
	local moveTextUsed=0
	local function addMoveCostText(value, x, z, affordable, combat, multipleCosts, dualCosts)
		local function addPart(partValue, partX, partAffordable, partCombat, fontSize, partY)
			moveTextUsed=moveTextUsed+1
			gStates.moveDisplayTextActiveCount=moveTextUsed
			local color={r=0.95,g=0.20,b=0.20}
			if partAffordable==true and partCombat==true then color={r=1.00,g=0.50,b=0.00}
			elseif partAffordable==true then color={r=1,g=1,b=1} end
			moveDisplayRequestTextMarker(moveTextUsed, {generation=displayGeneration,value=tostring(partValue),fontSize=fontSize,color=color,position={partX,partY or 1.35,z+moveTextZOffset}})
		end
		if multipleCosts==true and dualCosts~=nil then
			--3DText has one colour per object, so split a dual cost into three pooled markers.
			--Keep the smaller slash underneath the two numbers so it cannot visually cut through them.
			local lowText=tostring(dualCosts.low)
			local highText=tostring(dualCosts.high)
			local charWidth=0.29
			local centerGap=0.68
			local lowX=x-(centerGap/2)-((#lowText*charWidth)/2)
			local highX=x+(centerGap/2)+((#highText*charWidth)/2)
			addPart("/",x,dualCosts.low<=moveValue,false,58,1.33)
			addPart(lowText,lowX,dualCosts.low<=moveValue,dualCosts.lowCombat==true,80,1.37)
			addPart(highText,highX,dualCosts.high<=moveValue,dualCosts.highCombat==true,80,1.37)
		else
			addPart(value,x,affordable,combat,multipleCosts==true and 80 or 120)
		end
	end

	--Snapshot the map once. The static terrain/wall graph is cached; dynamic objects are overlaid below.
	--Against the Horsemen deliberately removes the normal start tile, so use Country01 as the grid origin.
	local startTileGUID=gStates.gameScenario=="Against the Horsemen Blitz" and GUID.tile.country01 or startTerrain.open
	local startTile=getObjectFromGUID(startTileGUID)
	if startTile==nil and gStates.gameScenario~="Against the Horsemen Blitz" then startTileGUID=startTerrain.wedge startTile=getObjectFromGUID(startTileGUID) end
	if startTile==nil or getObjectFromGUID(mapArea)==nil then clearMoveDisplayVisuals() return end
	local startTilePos=startTile.getPosition()
	local snapshot=runtimeMapSnapshot()
	local playAreaObjects=snapshot.objects or {}
	local hexMap=moveDisplayBaseHexMap(startTileGUID, startTilePos)
	--Dragon combat spaces keep their printed Move cost, but entering one starts the assault.
	--Against the Dragon uses its three-space Lair; Fury uses the single space where its marker is
	--currently landed. An in-flight Fury Dragon therefore contributes no combat destination.
	local dragonCombatScenario=gStates.gameScenario=="Against the Dragon Blitz" or gStates.gameScenario=="Fury of the Apocalypse Dragon" or gStates.apocalypseDragonCityPlaced==true
	if dragonCombatScenario==true and gStates.apocalypseDragonLairRevealed==true and gStates.apocalypseDragonDefeated~=true and apocalypseDragonCombatHexes~=nil then
		for _,dragonHex in ipairs(apocalypseDragonCombatHexes()) do
			local p=dragonHex.position
			if p~=nil then
				local lairVecNumber,lairHorNumber=runtimeMapWorldToAxial(p,startTilePos)
				local lairHor=tostring(lairHorNumber)
				local lairVec=tostring(lairVecNumber)
				if hexMap[lairHor]~=nil and hexMap[lairHor][lairVec]~=nil then hexMap[lairHor][lairVec].dragonLair=true end
			end
		end
	end
	local rampagerHexes={}
	local cityGUIDs=moveDisplayCityGUIDLookup()
	for _, mightBeMap in pairs(playAreaObjects) do
		local guid=mightBeMap.guid
		local cityObject=cityGUIDs[guid]==true
		local monsterDetails=monsterPugs[guid]
		local rampager=monsterDetails~=nil and gStates.rampagingMonsters~=nil and gStates.rampagingMonsters[guid]==true
		local shield=false
		if cityObject==false and rampager==false and mightBeMap.getName()=="Shield" and volkarePursuitShieldRegistered(mightBeMap)~=true then
			shield=(gStates.coop==1 or mightBeMap.getDescription()==turnOrder[gStates.turnNumber].mage)
		end
		if cityObject==true or shield==true or rampager==true then
			local objectPosition=mightBeMap.getPosition()
			local hexGridAxial,hexGridHorizontal=runtimeMapWorldToAxial(objectPosition,startTilePos)
			local hor=tostring(hexGridHorizontal)
			local vec=tostring(hexGridAxial)
			if hexMap[hor]==nil then hexMap[hor]={} end
			if shield==true then
				if hexMap[hor][vec]==nil then hexMap[hor][vec]={} end
				hexMap[hor][vec].fortified="shield"
			end
			if cityObject==true then
				if hexMap[hor][vec]==nil then hexMap[hor][vec]={} end
				local cityHex=hexMap[hor][vec]
				if cityHex.terrainType==nil and cityHex.hexType~=nil and cityHex.hexType~="city" then cityHex.terrainType=cityHex.hexType end
				cityHex.hexType="city"
				cityHex.fortified="city"
				local cityBeaten=gStates.friendlyCity[guid]==true
				local cityMonsters=gStates.cityMonsterQty[guid]
				if cityBeaten==false and cityMonsters~=nil then
					cityBeaten=true
					for monsterGUID, state in pairs(cityMonsters) do if monsterGUID~="extra" and state=="alive" then cityBeaten=false break end end
					local cityOrder=gStates.cityDeployOrder[guid]
					if cityOrder~=nil and gStates.cityLevels[cityOrder]==0 then cityBeaten=false end
				end
				if cityBeaten==true then cityHex.fortified="shield" end
			end
			if rampager==true then
				if hexMap[hor][vec]==nil then hexMap[hor][vec]={} end
				local rampagerHex=hexMap[hor][vec]
				if rampagerHex.terrainType==nil and rampagerHex.hexType~=nil and rampagerHex.hexType~="rampager" then rampagerHex.terrainType=rampagerHex.hexType end
				rampagerHex.hexType="rampager"
				rampagerHex.rampager=true
				rampagerHexes[#rampagerHexes+1]={hor=hexGridHorizontal, vec=hexGridAxial, ambushing=gStates.ambushingMonsters[guid]~=nil}
			end
		end
	end

		local dungeonLordsTunnelNetwork=moveDisplayDungeonLordsTunnelNetwork(hexMap,playAreaObjects,startTilePos)

		--Fractured Lands: index every revealed safe no-site destination by its printed terrain.
		--Teleporting costs 1 Move, ignores intervening spaces/walls/rampagers, and can be mixed with normal movement repeatedly.
		local fracturedLandsTeleport=gStates.gameScenario=="The Fractured Lands Blitz"
		local teleportHexesByTerrain={}
		if fracturedLandsTeleport==true then
			local teleportSpatial=runtimeMapSpatialSnapshot()
			for _,runtimeHex in ipairs(teleportSpatial.topology.hexes or {}) do
				if fracturedLandsTeleportHexLegal(runtimeHex.hexType)==true and fracturedLandsTeleportHexSafeNoSite(runtimeHex,teleportSpatial)==true then
					local vecNumber,horNumber=runtimeMapWorldToAxial(runtimeHex.position,startTilePos)
					local hor=tostring(horNumber)
					local vec=tostring(vecNumber)
					local row=hexMap[hor]
					local hex=row~=nil and row[vec] or nil
					local terrain=hex~=nil and (hex.terrainType or hex.hexType) or runtimeHex.hexType
					if terrain~=nil then
						if teleportHexesByTerrain[terrain]==nil then teleportHexesByTerrain[terrain]={} end
						teleportHexesByTerrain[terrain][#teleportHexesByTerrain[terrain]+1]={coord={horNumber,vecNumber}}
					end
				end
			end
		end

		--Pre-calculate each Ambushing Rampager's own two-hex threat area. Keeping the maps separate is important: both spaces of a move must be threatened by the same Rampager.
		local rampagerVectors=MOVE_DISPLAY_VECTORS
		local ambusherRangeMaps={}
		local function wallBetween(hor1, vec1, hor2, vec2)
			local wallHor=tostring((hor1+hor2)/2)
			local wallVec=tostring((vec1+vec2)/2)
			return hexMap[wallHor]~=nil and hexMap[wallHor][wallVec]~=nil
		end
		local function rangeHexOpen(hor, vec)
			local row=hexMap[tostring(hor)]
			local hex=row and row[tostring(vec)] or nil
			return hex~=nil and hex.hexType~="mountain" and hex.hexType~="lake"
		end
		local function addRangeHex(rangeMap, hor, vec)
			hor=tostring(hor) vec=tostring(vec)
			if rangeMap[hor]==nil then rangeMap[hor]={} end
			rangeMap[hor][vec]=true
		end
		for _, rampager in pairs(rampagerHexes) do
			if rampager.ambushing==true then
				local rangeMap={}
				local fringe={{rampager.hor, rampager.vec}}
				addRangeHex(rangeMap, rampager.hor, rampager.vec)
				for distance=1, 2 do
					local nextFringe={}
					for _, fromHex in pairs(fringe) do
						for _, vector in pairs(rampagerVectors) do
							local hor=fromHex[1]+vector[1]
							local vec=fromHex[2]+vector[2]
							local already=rangeMap[tostring(hor)]~=nil and rangeMap[tostring(hor)][tostring(vec)]==true
							if already==false and rangeHexOpen(hor, vec)==true and wallBetween(fromHex[1], fromHex[2], hor, vec)==false then
								addRangeHex(rangeMap, hor, vec)
								nextFringe[#nextFringe+1]={hor, vec}
							end
						end
					end
					fringe=nextFringe
				end
				ambusherRangeMaps[#ambusherRangeMaps+1]=rangeMap
			end
		end
		local function ambusherProvoked(fromHor, fromVec, toHor, toVec)
			fromHor=tostring(fromHor) fromVec=tostring(fromVec) toHor=tostring(toHor) toVec=tostring(toVec)
			for _, rangeMap in pairs(ambusherRangeMaps) do
				if rangeMap[fromHor]~=nil and rangeMap[fromHor][fromVec]==true and rangeMap[toHor]~=nil and rangeMap[toHor][toVec]==true then return true end
			end
			return false
		end
		--work out players hex grid position from the actual start tile; Fury's four-player
		--predefined map deliberately relocates the open start tile.
		local playerPos={startTilePos[1],0.97,startTilePos[3]}
		if gStates.gameScenario=="Against the Horsemen Blitz" then
			local gladePos=againstHorsemenCentralGladePosition(0.97)
			if gladePos~=nil then playerPos=gladePos end
		end
		local currentTurn=turnOrder[gStates.turnNumber]
		--Dummy and other non-avatar turns intentionally have no avatarLocation. Resource Tracker
		--controls can still fire on those turns, but there is no player movement map to render.
		if currentTurn==nil or currentTurn.avatarLocation==nil then
			clearMoveDisplayVisuals()
			return
		end
		local turnStartLoc=currentTurn.turnStartLoc
		if gStates.resourceTracker.playerPos==nil and turnStartLoc~=nil and turnStartLoc[1]~=nil and turnStartLoc[1]>-42 then
			gStates.resourceTracker.playerPos={turnStartLoc[1], turnStartLoc[2], turnStartLoc[3]}--{0, 0, 0}
		end
		if id=="MovemAmountUpdate" then
			for _, details in pairs(mageKnights) do
				if details.mage==currentTurn.mage then
					if getObjectFromGUID(details.model)~=nil then gStates.resourceTracker.playerPos={getObjectFromGUID(details.model).getPosition()[1], getObjectFromGUID(details.model).getPosition()[2], getObjectFromGUID(details.model).getPosition()[3]} end
					if getObjectFromGUID(details.token)~=nil then gStates.resourceTracker.playerPos=getObjectFromGUID(details.token).getPosition() end
					if getObjectFromGUID(details.standee)~=nil then gStates.resourceTracker.playerPos=getObjectFromGUID(details.standee).getPosition() end
				end
			end
			local avatarLocation=currentTurn.avatarLocation
			if avatarLocation:sub(1, 4)=="city" or avatarLocation=="Volkare's Camp" then
				--figure out which city avatar is in
				for zone, citySearch in pairs(cityScriptZones) do
					local zoneObj=getObjectFromGUID(zone)
					if zoneObj~=nil then
						for _, detail in pairs(zoneObj.getObjects()) do
							if joinLangEnglish(tostring(detail.getName() or ""))==currentTurn.mage then
								local cityObj=getObjectFromGUID(citySearch.cityGUID)
								if cityObj~=nil then gStates.resourceTracker.playerPos=cityObj.getPosition() end
								break
							end
						end
					end
				end
			end
		end
		if gStates.resourceTracker.playerPos~=nil then playerPos=gStates.resourceTracker.playerPos end
		--The shared Magical Glade is authoritative while the active Horsemen-scenario avatar is parked
		--off-map between turns; never let an old Portal/start-tile position override that logical hex.
		if againstHorsemenPlayerAtCentralGlade(currentTurn)==true then
			local gladePos=againstHorsemenCentralGladePosition(0.97)
			if gladePos~=nil then playerPos=gladePos end
		end

		local playerHexGridAxial,playerHexGridHorizontal=runtimeMapWorldToAxial(playerPos,startTilePos)
		local moveMap={[tostring(playerHexGridHorizontal)]={[tostring(playerHexGridAxial)]={safe=0}}}
		local fringe={{coord={playerHexGridHorizontal, playerHexGridAxial}}}
		local tempFringe={}
		local tempFringeSet={}
		local searchLimit=10
		local noMove=false

		local function moveDestination(hor,vec)
			local horKey=tostring(hor)
			local vecKey=tostring(vec)
			if moveMap[horKey]==nil then moveMap[horKey]={} end
			if moveMap[horKey][vecKey]==nil then moveMap[horKey][vecKey]={} end
			return moveMap[horKey][vecKey]
		end

		local function queueMoveFringe(hor,vec)
			local fringeKey=tostring(hor)..":"..tostring(vec)
			if tempFringeSet[fringeKey]==true then return end
			tempFringeSet[fringeKey]=true
			tempFringe[#tempFringe+1]={coord={hor,vec}}
			noMove=false
		end

		local function recordMoveDestination(hor,vec,state,hexCost,predecessor,allowFringe)
			if hexCost>=gStates.resourceTracker.move.move+searchLimit then return false end
			local destinationMove=moveDestination(hor,vec)
			local recordedCost=destinationMove[state] or 100
			if hexCost>recordedCost then return false end
			if hexCost<recordedCost then
				destinationMove[state]=hexCost
				destinationMove[state.."Prev"]=predecessor
				if state=="safe" and allowFringe==true then queueMoveFringe(hor,vec) end
			end
			return true
		end

		while noMove==false do
			noMove=true
			--Only safe states are ever queued. Combat-ending routes remain displayable but can never
			--become the source of later movement.
			for _,hexDetail in pairs(fringe) do
				local sourceRow=moveMap[tostring(hexDetail.coord[1])]
				local sourceMove=sourceRow~=nil and sourceRow[tostring(hexDetail.coord[2])] or nil
				local moveSpent=sourceMove~=nil and sourceMove.safe or 99

				--figure out the move cost to reach surrounding hexs
				for currentVector, vector in pairs(MOVE_DISPLAY_VECTORS) do
					local hor=hexDetail.coord[1]+vector[1]
					local vec=hexDetail.coord[2]+vector[2]
					local destinationHex=hexMap~=nil and hexMap[tostring(hor)]~=nil and hexMap[tostring(hor)][tostring(vec)] or nil
					if destinationHex~=nil then
						local hexCost=999
						if destinationHex.hexType~=nil and gStates.moveCost[destinationHex.hexType]~=nil then hexCost=gStates.moveCost[destinationHex.hexType]+moveSpent end
						local wallhor=hexDetail.coord[1]+(vector[1]/2)
						local wallvec=hexDetail.coord[2]+(vector[2]/2)
						if hexMap[tostring(wallhor)]~=nil and hexMap[tostring(wallhor)][tostring(wallvec)]~=nil then hexCost=hexCost+1 end
						if hexCost<=99 and hexCost<gStates.resourceTracker.move.move+searchLimit then
							--Don't add hex to fringe if passing a rampager.
							local rampageHor={tostring(hexDetail.coord[1]+MOVE_DISPLAY_RAMPAGE_ADJACENT[currentVector][1]), tostring(hexDetail.coord[1]+MOVE_DISPLAY_RAMPAGE_ADJACENT[currentVector+2][1])}
							local rampageVec={tostring(hexDetail.coord[2]+MOVE_DISPLAY_RAMPAGE_ADJACENT[currentVector][2]), tostring(hexDetail.coord[2]+MOVE_DISPLAY_RAMPAGE_ADJACENT[currentVector+2][2])}
							local rampageWallHor={tostring(hexDetail.coord[1]+MOVE_DISPLAY_RAMPAGE_WALL[currentVector][1]), tostring(hexDetail.coord[1]+MOVE_DISPLAY_RAMPAGE_WALL[currentVector+1][1])}
							local rampageWallVec={tostring(hexDetail.coord[2]+MOVE_DISPLAY_RAMPAGE_WALL[currentVector][2]), tostring(hexDetail.coord[2]+MOVE_DISPLAY_RAMPAGE_WALL[currentVector+1][2])}
							local normalRampager=(hexMap[rampageHor[1]]~=nil and hexMap[rampageHor[1]][rampageVec[1]]~=nil and hexMap[rampageHor[1]][rampageVec[1]].hexType=="rampager" and (hexMap[rampageWallHor[1]]==nil or hexMap[rampageWallHor[1]][rampageWallVec[1]]==nil)) or
								(hexMap[rampageHor[2]]~=nil and hexMap[rampageHor[2]][rampageVec[2]]~=nil and hexMap[rampageHor[2]][rampageVec[2]].hexType=="rampager" and (hexMap[rampageWallHor[2]]==nil or hexMap[rampageWallHor[2]][rampageWallVec[2]]==nil))
							local rampageNeighbor=normalRampager or ambusherProvoked(hexDetail.coord[1],hexDetail.coord[2],hor,vec)
							local fortifiedDestination=destinationHex.hexType~="explore" and destinationHex.fortified~=nil and destinationHex.fortified~="shield"
							local combatDestination=rampageNeighbor or destinationHex.dragonLair==true or fortifiedDestination
							local predecessor={hor=hexDetail.coord[1],vec=hexDetail.coord[2],state="safe",teleport=false}
							if combatDestination==true then
								recordMoveDestination(hor,vec,"combat",hexCost,predecessor,false)
							else
								local canContinue=destinationHex.hexType~="explore"
								recordMoveDestination(hor,vec,"safe",hexCost,predecessor,canContinue)
							end
						end
					end
				end

				--Dungeon Lords underground edges. Another conquered Dungeon/Tomb costs 2 Move plus the
				--shortest revealed-space distance that avoids Lakes and Swamps; tunnel travel never provokes Rampagers.
				local tunnelSourceKey=tostring(hexDetail.coord[1])..":"..tostring(hexDetail.coord[2])
				for _,tunnel in ipairs(dungeonLordsTunnelNetwork[tunnelSourceKey] or {}) do
					local hor=tunnel.hor
					local vec=tunnel.vec
					local hexCost=moveSpent+tunnel.cost
					local predecessor={hor=hexDetail.coord[1],vec=hexDetail.coord[2],state="safe",teleport=false,tunnel=true,tunnelPath=tunnel.path}
					recordMoveDestination(hor,vec,"safe",hexCost,predecessor,true)
				end

				--Fractured Lands teleport edges. A teleport is always a safe, non-combat route and can itself become
				--the source of later normal moves or further teleports.
				if fracturedLandsTeleport==true then
					local sourceHexRow=hexMap[tostring(hexDetail.coord[1])]
					local sourceHex=sourceHexRow~=nil and sourceHexRow[tostring(hexDetail.coord[2])] or nil
					local sourceTerrain=sourceHex~=nil and (sourceHex.terrainType or sourceHex.hexType) or nil
					for _,teleportHex in pairs(teleportHexesByTerrain[sourceTerrain] or {}) do
						local hor=teleportHex.coord[1]
						local vec=teleportHex.coord[2]
						if hor~=hexDetail.coord[1] or vec~=hexDetail.coord[2] then
							local hexCost=moveSpent+1
							local predecessor={hor=hexDetail.coord[1],vec=hexDetail.coord[2],state="safe",teleport=true}
							recordMoveDestination(hor,vec,"safe",hexCost,predecessor,true)
						end
					end
				end
			end
			fringe=tempFringe
			tempFringe={}
			tempFringeSet={}
		end
		--Draw the predecessor tree used by the displayed cheapest routes. Each retained
		--route state is walked once rather than retracing every destination back to the avatar.
		local routeLines={}
		for _, line in pairs(moveDisplayBaseVectorLines or {}) do routeLines[#routeLines+1]=line end
		local routeSegmentSeen={}
		local routeStateSeen={}
		local routeStack={}
		local function routeWorldPosition(hor, vec)
			return runtimeMapAxialToWorld(vec,hor,startTilePos,1.22)
		end
		local function addRouteSegment(fromHor, fromVec, toHor, toVec, teleport, tunnelPath)
			local function addOne(aHor,aVec,bHor,bVec,mode)
				local key=tostring(aHor)..":"..tostring(aVec)..">"..tostring(bHor)..":"..tostring(bVec)..":"..tostring(mode)
				if routeSegmentSeen[key]==true then return end
				routeSegmentSeen[key]=true
				local color={0.50,0.50,0.50}
				local thickness=0.07
				if mode=="teleport" then color={0.20,0.70,1.00} thickness=0.12
				elseif mode=="tunnel" then color={0.72,0.45,1.00} end
				routeLines[#routeLines+1]={points={routeWorldPosition(aHor,aVec),routeWorldPosition(bHor,bVec)},color=color,thickness=thickness,rotation={0,0,0}}
			end
			if tunnelPath~=nil and #tunnelPath>1 then
				for i=1,#tunnelPath-1 do addOne(tunnelPath[i].hor,tunnelPath[i].vec,tunnelPath[i+1].hor,tunnelPath[i+1].vec,"tunnel") end
			else
				addOne(fromHor,fromVec,toHor,toVec,teleport==true and "teleport" or "normal")
			end
		end
		local function queueRouteState(hor, vec, state)
			local key=tostring(hor)..":"..tostring(vec)..":"..state
			if routeStateSeen[key]==true then return end
			routeStateSeen[key]=true
			routeStack[#routeStack+1]={hor=hor, vec=vec, state=state}
		end
		for hor, rowOfHexes in pairs(moveMap) do
			for vec, moveDetails in pairs(rowOfHexes) do
				local routeCost=moveDetails.safe
				local routeState="safe"
				if moveDetails.combat~=nil and (routeCost==nil or moveDetails.combat<routeCost) then routeCost=moveDetails.combat routeState="combat" end
				if routeCost~=nil and routeCost<=99 and routeCost<moveValue+searchLimit then queueRouteState(tonumber(hor),tonumber(vec),routeState) end
			end
		end
		while #routeStack>0 do
			local current=table.remove(routeStack)
			if current.hor~=playerHexGridHorizontal or current.vec~=playerHexGridAxial then
				local routeRow=moveMap[tostring(current.hor)]
				local routeMove=routeRow~=nil and routeRow[tostring(current.vec)] or nil
				local previous=routeMove~=nil and routeMove[current.state.."Prev"] or nil
				if previous~=nil then
					addRouteSegment(previous.hor, previous.vec, current.hor, current.vec, previous.teleport, previous.tunnelPath)
					--Only a safe state used by a retained onward route deserves an alternate slash value.
					local sourceRow=moveMap[tostring(previous.hor)]
					local sourceMove=sourceRow~=nil and sourceRow[tostring(previous.vec)] or nil
					if sourceMove~=nil and previous.state=="safe" then sourceMove.safeUsedOnward=1 end
					queueRouteState(previous.hor,previous.vec,previous.state or "safe")
				end
			end
		end
		Global.setVectorLines(routeLines)

		--Highlight movement costs with spawned text instead of numbered image decals.
		for hor,rowOfHexes in pairs(moveMap) do
			for vec,hexCost in pairs(rowOfHexes) do
				local safeCost=hexCost.safe
				local combatCost=hexCost.combat
				local lowestHex=safeCost
				local lowestCombat=false
				if combatCost~=nil and (lowestHex==nil or combatCost<lowestHex) then lowestHex=combatCost lowestCombat=true end
				if lowestHex~=nil then
					local displayCost=tostring(lowestHex)
					local multipleCosts=false
					local dualCosts=nil
					--A cheaper combat route cannot be used onward. If a more expensive safe route is actually
					--part of the retained route tree, show both values so the onward path remains explainable.
					if combatCost~=nil and safeCost~=nil and combatCost<safeCost and hexCost.safeUsedOnward==1 then
						displayCost=tostring(combatCost).."/"..tostring(safeCost)
						multipleCosts=true
						dualCosts={low=combatCost,high=safeCost,lowCombat=true,highCombat=false}
					end
					local world=runtimeMapAxialToWorld(tonumber(vec),tonumber(hor),startTilePos,1.22)
					if world~=nil then
						local hexGridX,hexGridZ=world[1],world[3]
						local startingHex=tonumber(hor)==playerHexGridHorizontal and tonumber(vec)==playerHexGridAxial
						if startingHex==false then
							if lowestHex<=gStates.resourceTracker.move.move then
								addMoveCostText(displayCost,hexGridX,hexGridZ,true,lowestCombat,multipleCosts,dualCosts)
							elseif lowestHex<=99 and lowestHex<gStates.resourceTracker.move.move+searchLimit then
								addMoveCostText(displayCost,hexGridX,hexGridZ,false,lowestCombat,multipleCosts,dualCosts)
							end
						end
					end
				end
			end
		end
		moveDisplayHideUnusedText(moveTextUsed)
end

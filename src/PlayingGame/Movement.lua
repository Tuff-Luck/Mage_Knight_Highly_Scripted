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
	local map=getObjectFromGUID(mapArea)
	if map==nil then return end
	local terrain, bearing, _, feature=terrainHexAtPosition(position, map.getObjects())
	if terrain==nil or bearing==nil or (feature~="rampaging" and feature~="draconum") then return end
	if gStates.fracturedLandsDefeatedRampagingHexes==nil then gStates.fracturedLandsDefeatedRampagingHexes={} end
	gStates.fracturedLandsDefeatedRampagingHexes[fracturedLandsTeleportRampageKey(terrain.guid, bearing)]=true
end
function fracturedLandsTeleportHexSafeNoSite(terrain, bearing, feature, hexPos, objectsInPlay)
	if terrain==nil or bearing==nil or hexPos==nil then return false end
	feature=feature or ""
	local noSite=feature=="" or feature=="portal"
	if feature=="monastery" and gStates.monasteryBurned~=nil and gStates.monasteryBurned[terrain.guid]==true then noSite=true end
	if feature=="rampaging" or feature=="draconum" then
		local cleared=gStates.fracturedLandsDefeatedRampagingHexes or {}
		noSite=cleared[fracturedLandsTeleportRampageKey(terrain.guid, bearing)]==true
	end
	if noSite~=true then return false end
	--A safe destination cannot currently contain an enemy or another Mage Knight.
	for _, obj in pairs(objectsInPlay or {}) do
		local pos=obj.getPosition()
		if ((pos[1]-hexPos[1])^2)+((pos[3]-hexPos[3])^2)<1 then
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
	local map=getObjectFromGUID(mapArea)
	if sourcePos==nil or map==nil then return decals end
	local objectsInPlay=map.getObjects()
	local cachedPositions={}
	for _, obj in pairs(objectsInPlay) do if terrainTiles[obj.guid]~=nil then cachedPositions[obj.guid]=obj.getPosition() end end
	local sourceTerrain, sourceBearing, _, _, sourceType=terrainHexAtPosition(sourcePos, objectsInPlay, cachedPositions)
	if sourceTerrain==nil or sourceBearing==nil or fracturedLandsTeleportHexLegal(sourceType)~=true then return decals end
	for _, terrain in pairs(objectsInPlay) do
		local details=terrainTiles[terrain.guid]
		if details~=nil and terrain.is_face_down==false then
			for bearing, hexType in pairs(details.hexType or {}) do
				if hexType==sourceType and fracturedLandsTeleportHexLegal(hexType)==true and not (terrain.guid==sourceTerrain.guid and tostring(bearing)==tostring(sourceBearing)) then
					local xy=angleToXY(terrain, bearing)
					local feature=(details.hexFeature or {})[bearing]
					local hexPos={xy[1],1.12,xy[2]}
					if fracturedLandsTeleportHexSafeNoSite(terrain, bearing, feature, hexPos, objectsInPlay)==true then
						decals[#decals+1]={name=fracturedLandsTeleportDecalName, url=fracturedLandsTeleportDecalURL, position=hexPos, rotation={90,0,0}, scale={2.0,2.0,1}}
					end
				end
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
moveDisplayLegacyDecalsCleaned=false
moveDisplayTextSlotRequests={}
moveDisplayTextSpawning={}
MOVE_DISPLAY_HEX_BEARINGS={"center", "0", "60", "120", "180", "240", "300"}
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
		local hor=math.floor(((pos[3]-startTilePos[3])/2.0785)+0.5)
		local vec=math.floor(((pos[1]-startTilePos[1])/2.4)+(hor/2)+0.5)
		return hor,vec
	end
	for _,obj in pairs(playAreaObjects or {}) do
		if obj.getName()=="Shield" and volkarePursuitShieldRegistered(obj)~=true then
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
function moveDisplayBaseHexMap(playAreaObjects, startTileGUID, startTilePos)
	local snapshot=runtimeMapSnapshot()
	local terrainEntries=snapshot.terrainEntries or {}
	local signature=startTileGUID.."@"..string.format("%.3f,%.3f", startTilePos[1], startTilePos[3]).."|"..(snapshot.terrainSignature or "")
	if moveDisplayTerrainCache.signature==signature and moveDisplayTerrainCache.hexMap~=nil then return moveDisplayCloneHexMap(moveDisplayTerrainCache.hexMap) end

	local hexMap={}
	for _, entry in pairs(terrainEntries) do
		local details=entry.details
		local hexGridHorizontal=math.floor(((entry.position[3]-startTilePos[3])/2.0785)+0.5)
		local hexGridAxial=math.floor(((entry.position[1]-startTilePos[1])/2.4)+(hexGridHorizontal/2)+0.5)
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

function updateMoveDisplay(id)
	--With zero Move and no active markers there is nothing for the movement display to do.
	local moveValue=gStates.resourceTracker~=nil and gStates.resourceTracker.move~=nil and gStates.resourceTracker.move.move or 0
	local hasMoveMarkers=(gStates.moveDisplayTextActiveCount or 0)>0
	if moveValue<=0 and hasMoveMarkers==false then
		if moveDisplayAutoPause~=nil then Wait.stop(moveDisplayAutoPause) moveDisplayAutoPause=nil end
		if moveDisplayBaseVectorLines~=nil then Global.setVectorLines(moveDisplayBaseVectorLines) moveDisplayBaseVectorLines=nil end
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

	--Old saves may still contain the image-based movement highlights. Remove those once; the current
	--3DText display never creates them, so rereading/replacing every Global decal on each redraw is wasted work.
	if moveDisplayLegacyDecalsCleaned~=true then
		local existingDecals=Global.getDecals()
		local cleanedDecals={}
		if existingDecals~=nil then
			for _, decal in pairs(existingDecals) do if decal.name~="Hex Highlight" then cleanedDecals[#cleanedDecals+1]=decal end end
		end
		Global.setDecals(cleanedDecals)
		moveDisplayLegacyDecalsCleaned=true
	end
	if moveValue<=0 then
		moveDisplayHideUnusedText(0)
		if moveDisplayBaseVectorLines~=nil then Global.setVectorLines(moveDisplayBaseVectorLines) moveDisplayBaseVectorLines=nil end
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
	local mapObject=getObjectFromGUID(mapArea)
	if startTile==nil or mapObject==nil then moveDisplayHideUnusedText(0) return end
	local startTilePos=startTile.getPosition()
	local snapshot=runtimeMapSnapshot()
	local playAreaObjects=snapshot.objects or {}
	local hexMap=moveDisplayBaseHexMap(playAreaObjects, startTileGUID, startTilePos)
	--The Dragon's three lair spaces keep their printed terrain Move cost, but entering any of them
	--starts the Dragon assault. Mark them as combat-only destinations so the movement helper shows
	--the cost in orange and never routes onward through the Lair as though it were a safe space.
	if gStates.gameScenario=="Against the Dragon Blitz" and gStates.apocalypseDragonLairRevealed==true and gStates.apocalypseDragonDefeated~=true and gStates.apocalypseDragonLair~=nil then
		for _,lairHex in ipairs(gStates.apocalypseDragonLair.hexes or {}) do
			local p=lairHex.position
			if p~=nil then
				local lairHor=tostring(math.floor(((p[3]-startTilePos[3])/2.0785)+0.5))
				local lairHorNumber=tonumber(lairHor)
				local lairVec=tostring(math.floor(((p[1]-startTilePos[1])/2.4)+(lairHorNumber/2)+0.5))
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
		local rampager=monsterDetails~=nil and (monsterDetails.pugType=="green" or monsterDetails.pugType=="red")
		local shield=false
		if cityObject==false and rampager==false and mightBeMap.getName()=="Shield" and volkarePursuitShieldRegistered(mightBeMap)~=true then
			shield=(gStates.coop==1 or mightBeMap.getDescription()==turnOrder[gStates.turnNumber].mage)
		end
		if cityObject==true or shield==true or rampager==true then
			local objectPosition=mightBeMap.getPosition()
			local hexGridHorizontal=math.floor(((objectPosition[3]-startTilePos[3])/2.0785)+0.5)
			local hexGridAxial=math.floor(((objectPosition[1]-startTilePos[1])/2.4)+(hexGridHorizontal/2)+0.5)
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
			if rampager==true and objectPosition[2]<1.09 then
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
			local occupiedByOtherMage={}
			for playerIndex, playerDetails in pairs(turnOrder) do
				if playerIndex~=gStates.turnNumber and playerDetails.mage~="Volkare" then
					local otherPos=fracturedLandsTeleportSourcePosition(playerIndex)
					if otherPos~=nil then
						local otherHor=math.floor(((otherPos[3]-startTilePos[3])/2.0785)+0.5)
						local otherVec=math.floor(((otherPos[1]-startTilePos[1])/2.4)+(otherHor/2)+0.5)
						occupiedByOtherMage[tostring(otherHor)..":"..tostring(otherVec)]=true
					end
				end
			end
			--Match the teleport-logo safety test: any enemy token physically occupying a hex blocks teleporting there.
			--Do not rely on the rampager map flag here, because that flag has extra movement-specific filtering.
			local occupiedByMonster={}
			for _, mapObject in pairs(playAreaObjects) do
				if monsterPugs[mapObject.guid]~=nil then
					local monsterPos=mapObject.getPosition()
					local monsterHor=math.floor(((monsterPos[3]-startTilePos[3])/2.0785)+0.5)
					local monsterVec=math.floor(((monsterPos[1]-startTilePos[1])/2.4)+(monsterHor/2)+0.5)
					occupiedByMonster[tostring(monsterHor)..":"..tostring(monsterVec)]=true
				end
			end
			for hor, rowOfHexes in pairs(hexMap) do
				for vec, hex in pairs(rowOfHexes) do
					local terrain=hex.terrainType
					local feature=hex.feature or ""
					local clearedRampager=false
					if (feature=="rampaging" or feature=="draconum") and hex.tileGUID~=nil and hex.bearing~=nil then
						local cleared=gStates.fracturedLandsDefeatedRampagingHexes or {}
						clearedRampager=cleared[fracturedLandsTeleportRampageKey(hex.tileGUID,hex.bearing)]==true
					end
					local noSite=feature=="" or feature=="portal" or clearedRampager or
						(feature=="monastery" and gStates.monasteryBurned[hex.tileGUID]==true)
					local terrainAccessible=terrain~=nil and gStates.moveCost[terrain]~=nil and gStates.moveCost[terrain]<900
					local occupancyKey=tostring(hor)..":"..tostring(vec)
					local occupied=(feature~="portal" and occupiedByOtherMage[occupancyKey]==true) or occupiedByMonster[occupancyKey]==true
					if noSite==true and terrainAccessible==true and occupied==false and hex.rampager~=true then
						if teleportHexesByTerrain[terrain]==nil then teleportHexesByTerrain[terrain]={} end
						teleportHexesByTerrain[terrain][#teleportHexesByTerrain[terrain]+1]={coord={tonumber(hor), tonumber(vec)}}
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
		--add explore hex to boundary
		-- for _, buttonDetail in pairs(gStates.exploreButtons) do
		-- 	if buttonDetail.attributes~=nil then
		-- 		local hexGridHorizontal=math.floor(((buttonDetail.attributes.tilePosZ-startTilePos[3])/2.0785)+0.5)
		-- 		local hexGridAxial=math.floor(((buttonDetail.attributes.tilePosX-startTilePos[1])/2.4)+(hexGridHorizontal/2)+0.5)
		-- 		local bearingAdjust={{1,0}, {0,-1}, {-1,-1}, {-1,0}, {0,1}, {1,1}, {1,0}, {0,-1}}--Each end are wrap around values.
		-- 		for primaryHexLoop=2, 7 ,1 do
		-- 			local hexGridHorizontal2=hexGridHorizontal+bearingAdjust[primaryHexLoop][1]
		-- 			local hexGridAxial2=hexGridAxial+bearingAdjust[primaryHexLoop][2]
		-- 			for secondaryHexLoop=primaryHexLoop-1, primaryHexLoop+1, 1 do
		-- 				local hexGridHorizontal3=hexGridHorizontal2+bearingAdjust[secondaryHexLoop][1]
		-- 				local hexGridAxial3=hexGridAxial2+bearingAdjust[secondaryHexLoop][2]
		-- 				if hexMap[tostring(hexGridHorizontal3)]~=nil and hexMap[tostring(hexGridHorizontal3)][tostring(hexGridAxial3)]~=nil then
		-- 					if hexMap[tostring(hexGridHorizontal2)]==nil then hexMap[tostring(hexGridHorizontal2)]={} end
		-- 					hexMap[tostring(hexGridHorizontal2)][tostring(hexGridAxial2)]={hexType="explore"}
		-- 					break
		-- 				end
		-- 			end
		-- 		end
		-- 	end
		-- end

		--work out players hex grid position from the actual start tile; Fury's four-player
		--predefined map deliberately relocates the open start tile.
		local playerPos={startTilePos[1],0.97,startTilePos[3]}
		if gStates.gameScenario=="Against the Horsemen Blitz" then
			local gladePos=againstHorsemenCentralGladePosition(0.97)
			if gladePos~=nil then playerPos=gladePos end
		end
		if gStates.resourceTracker.playerPos==nil and turnOrder[gStates.turnNumber].turnStartLoc[1]~=nil and turnOrder[gStates.turnNumber].turnStartLoc[1]>-42 then
			gStates.resourceTracker.playerPos={turnOrder[gStates.turnNumber].turnStartLoc[1], turnOrder[gStates.turnNumber].turnStartLoc[2], turnOrder[gStates.turnNumber].turnStartLoc[3]}--{0, 0, 0}
		end
		if id=="MovemAmountUpdate" then
			for b, details in pairs(mageKnights) do
				if details.mage==turnOrder[gStates.turnNumber].mage then
					if getObjectFromGUID(details.model)~=nil then gStates.resourceTracker.playerPos={getObjectFromGUID(details.model).getPosition()[1], getObjectFromGUID(details.model).getPosition()[2], getObjectFromGUID(details.model).getPosition()[3]} end
					if getObjectFromGUID(details.token)~=nil then gStates.resourceTracker.playerPos=getObjectFromGUID(details.token).getPosition() end
					if getObjectFromGUID(details.standee)~=nil then gStates.resourceTracker.playerPos=getObjectFromGUID(details.standee).getPosition() end
				end
			end
			if turnOrder[gStates.turnNumber].avatarLocation:sub(1, 4)=="city" or turnOrder[gStates.turnNumber].avatarLocation=="Volkare's Camp" then
				--figure out which city avatar is in
				for zone, citySearch in pairs(cityScriptZones) do
					for obj, detail in pairs(getObjectFromGUID(zone).getObjects()) do
						if detail.getName()==turnOrder[gStates.turnNumber].mage then
							gStates.resourceTracker.playerPos=getObjectFromGUID(citySearch.cityGUID).getPosition()
							break
						end
					end
				end
			end
		end
		if gStates.resourceTracker.playerPos~=nil then playerPos=gStates.resourceTracker.playerPos end
		--The shared Magical Glade is authoritative while the active Horsemen-scenario avatar is parked
		--off-map between turns; never let an old Portal/start-tile position override that logical hex.
		if againstHorsemenPlayerAtCentralGlade(turnOrder[gStates.turnNumber])==true then
			local gladePos=againstHorsemenCentralGladePosition(0.97)
			if gladePos~=nil then playerPos=gladePos end
		end

		local playerHexGridHorizontal=math.floor(((playerPos[3]-startTilePos[3])/2.0785)+0.5)
		local playerHexGridAxial=math.floor(((playerPos[1]-startTilePos[1])/2.4)+(playerHexGridHorizontal/2)+0.5)
		local moveMap={[tostring(playerHexGridHorizontal)]={[tostring(playerHexGridAxial)]={main=0}}}
		local fringe={{coord={playerHexGridHorizontal, playerHexGridAxial}}}
		local tempFringe={}
		local tempFringeSet={}
		--When two onward routes cost the same, prefer the predecessor that is already using its
		--cheapest state. This avoids choosing the 5 side of a 4/5 hex when an ordinary 5 route is equal.
		local function continuationPenalty(hor, vec, state)
			local row=moveMap[tostring(hor)]
			local move=row~=nil and row[tostring(vec)] or nil
			if move==nil or move[state or "main"]==nil then return 0 end
			local cheapest=move.main or 99
			if move.tricky~=nil and move.tricky<cheapest then cheapest=move.tricky end
			return move[state or "main"]>cheapest and 1 or 0
		end

		--Search fringe hexes recorded from the previous loop
		local searchLimit=10
		local noMove=false
		while noMove==false do
			noMove=true
			--check every hex added in the last round
			for checkingHex, hexDetail in pairs(fringe) do
				local moveSpent=99
				local sourceState="main"
				if moveMap[tostring(hexDetail.coord[1])]~=nil and moveMap[tostring(hexDetail.coord[1])][tostring(hexDetail.coord[2])]~=nil then
					local sourceMove=moveMap[tostring(hexDetail.coord[1])][tostring(hexDetail.coord[2])]
					moveSpent=sourceMove.main
					if sourceMove.tricky~=nil then moveSpent=sourceMove.tricky sourceState="tricky" end
				end

				--figure out the move cost to reach surrounding hexs
				for currentVector, vector in pairs(MOVE_DISPLAY_VECTORS) do
					local hor=hexDetail.coord[1]+vector[1]
					local vec=hexDetail.coord[2]+vector[2]
					--See if the destination hex has a recorded terrain type
					if hexMap~=nil and hexMap[tostring(hor)]~=nil and hexMap[tostring(hor)][tostring(vec)]~=nil then
						local hexCost=999
						if hexMap[tostring(hor)][tostring(vec)].hexType~=nil and gStates.moveCost[hexMap[tostring(hor)][tostring(vec)].hexType]~=nil then hexCost=gStates.moveCost[hexMap[tostring(hor)][tostring(vec)].hexType]+moveSpent end
						local wallhor=hexDetail.coord[1]+(vector[1]/2)
						local wallvec=hexDetail.coord[2]+(vector[2]/2)
						if hexMap[tostring(wallhor)]~=nil and hexMap[tostring(wallhor)][tostring(wallvec)]~=nil then hexCost=hexCost+1 end
						local recordedMoveTotal=100
						if moveMap[tostring(hor)]~=nil and moveMap[tostring(hor)][tostring(vec)]~=nil then
							recordedMoveTotal=moveMap[tostring(hor)][tostring(vec)].main
							if moveMap[tostring(hor)][tostring(vec)].tricky~=nil then recordedMoveTotal=moveMap[tostring(hor)][tostring(vec)].tricky end
						end
						if hexCost<=99 and hexCost<gStates.resourceTracker.move.move+searchLimit and hexCost<=recordedMoveTotal then
							if moveMap[tostring(hor)]==nil then moveMap[tostring(hor)]={} end
							if moveMap[tostring(hor)][tostring(vec)]==nil then moveMap[tostring(hor)][tostring(vec)]={} end
							--Don't add hex to fringe if passing a rampager
							local rampageHor={tostring(hexDetail.coord[1]+MOVE_DISPLAY_RAMPAGE_ADJACENT[currentVector][1]), tostring(hexDetail.coord[1]+MOVE_DISPLAY_RAMPAGE_ADJACENT[currentVector+2][1])}
							local rampageVec={tostring(hexDetail.coord[2]+MOVE_DISPLAY_RAMPAGE_ADJACENT[currentVector][2]), tostring(hexDetail.coord[2]+MOVE_DISPLAY_RAMPAGE_ADJACENT[currentVector+2][2])}
							local rampageWallHor={tostring(hexDetail.coord[1]+MOVE_DISPLAY_RAMPAGE_WALL[currentVector][1]), tostring(hexDetail.coord[1]+MOVE_DISPLAY_RAMPAGE_WALL[currentVector+1][1])}
							local rampageWallVec={tostring(hexDetail.coord[2]+MOVE_DISPLAY_RAMPAGE_WALL[currentVector][2]), tostring(hexDetail.coord[2]+MOVE_DISPLAY_RAMPAGE_WALL[currentVector+1][2])}
							local normalRampager=(hexMap[rampageHor[1]]~=nil and hexMap[rampageHor[1]][rampageVec[1]]~=nil and hexMap[rampageHor[1]][rampageVec[1]].hexType=="rampager" and (hexMap[rampageWallHor[1]]==nil or hexMap[rampageWallHor[1]][rampageWallVec[1]]==nil)) or
								(hexMap[rampageHor[2]]~=nil and hexMap[rampageHor[2]][rampageVec[2]]~=nil and hexMap[rampageHor[2]][rampageVec[2]].hexType=="rampager" and (hexMap[rampageWallHor[2]]==nil or hexMap[rampageWallHor[2]][rampageWallVec[2]]==nil))
							local rampageNeighbor=normalRampager or ambusherProvoked(hexDetail.coord[1], hexDetail.coord[2], hor, vec)
							local dragonLairDestination=hexMap[tostring(hor)][tostring(vec)].dragonLair==true
							local forcedCombatDestination=rampageNeighbor or dragonLairDestination
							local destinationMove=moveMap[tostring(hor)][tostring(vec)]
							local predecessor={hor=hexDetail.coord[1], vec=hexDetail.coord[2], state=sourceState, teleport=false}
							if hexCost==recordedMoveTotal then
								--Equal-cost safe routes do not change reachability, but a cleaner predecessor can
								--remove an otherwise unnecessary dual-cost label from the displayed route tree.
								if forcedCombatDestination==false then
									local existingPrev=destinationMove.tricky~=nil and destinationMove.trickyPrev or destinationMove.mainPrev
									if existingPrev~=nil and continuationPenalty(predecessor.hor,predecessor.vec,predecessor.state)<continuationPenalty(existingPrev.hor,existingPrev.vec,existingPrev.state) then
										if destinationMove.tricky~=nil then destinationMove.trickyPrev=predecessor else destinationMove.mainPrev=predecessor end
									end
								end
							else
								if forcedCombatDestination==true then
									if destinationMove.main~=nil then
										destinationMove.tricky=destinationMove.main
										destinationMove.trickyPrev=destinationMove.mainPrev
										destinationMove.trickyCombat=destinationMove.mainCombat==true
										destinationMove.main=hexCost
										destinationMove.mainPrev=predecessor
										destinationMove.mainCombat=true
									else
										destinationMove.main=hexCost
										destinationMove.mainPrev=predecessor
										destinationMove.tricky=99--combat-only route is displayable but cannot be used to continue movement
										destinationMove.trickyPrev=nil
										destinationMove.trickyCombat=false
										destinationMove.mainCombat=true
									end
								else
									if destinationMove.tricky==nil then
										destinationMove.main=hexCost
										destinationMove.mainPrev=predecessor
										destinationMove.mainCombat=false
									else
										destinationMove.tricky=hexCost
										destinationMove.trickyPrev=predecessor
										destinationMove.trickyCombat=false
									end
								end
								--Fortified sites and forced-combat destinations may be reached but never used as onward fringe.
								if forcedCombatDestination==false and hexMap[tostring(hor)][tostring(vec)].hexType~="explore" and (hexMap[tostring(hor)][tostring(vec)].fortified==nil or hexMap[tostring(hor)][tostring(vec)].fortified=="shield") then
									local fringeKey=tostring(hor)..":"..tostring(vec)
									if tempFringeSet[fringeKey]~=true then
										tempFringeSet[fringeKey]=true
										tempFringe[#tempFringe+1]={coord={hor, vec}}
										noMove=false
									end
								end
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
					local recordedMoveTotal=100
					if moveMap[tostring(hor)]~=nil and moveMap[tostring(hor)][tostring(vec)]~=nil then
						recordedMoveTotal=moveMap[tostring(hor)][tostring(vec)].main
						if moveMap[tostring(hor)][tostring(vec)].tricky~=nil then recordedMoveTotal=moveMap[tostring(hor)][tostring(vec)].tricky end
					end
					if hexCost<gStates.resourceTracker.move.move+searchLimit and hexCost<=recordedMoveTotal then
						if moveMap[tostring(hor)]==nil then moveMap[tostring(hor)]={} end
						if moveMap[tostring(hor)][tostring(vec)]==nil then moveMap[tostring(hor)][tostring(vec)]={} end
						local destinationMove=moveMap[tostring(hor)][tostring(vec)]
						local predecessor={hor=hexDetail.coord[1],vec=hexDetail.coord[2],state=sourceState,teleport=false,tunnel=true,tunnelPath=tunnel.path}
						if hexCost==recordedMoveTotal then
							local existingPrev=destinationMove.tricky~=nil and destinationMove.trickyPrev or destinationMove.mainPrev
							if existingPrev~=nil and continuationPenalty(predecessor.hor,predecessor.vec,predecessor.state)<continuationPenalty(existingPrev.hor,existingPrev.vec,existingPrev.state) then
								if destinationMove.tricky~=nil then destinationMove.trickyPrev=predecessor else destinationMove.mainPrev=predecessor end
							end
						else
							if destinationMove.tricky==nil then
								destinationMove.main=hexCost
								destinationMove.mainPrev=predecessor
								destinationMove.mainCombat=false
							else
								destinationMove.tricky=hexCost
								destinationMove.trickyPrev=predecessor
								destinationMove.trickyCombat=false
							end
							local fringeKey=tostring(hor)..":"..tostring(vec)
							if tempFringeSet[fringeKey]~=true then
								tempFringeSet[fringeKey]=true
								tempFringe[#tempFringe+1]={coord={hor,vec}}
								noMove=false
							end
						end
					end
				end

				--Fractured Lands teleport edges. A teleport is always a safe, non-combat route and can itself become
				--the source of later normal moves or further teleports.
				if fracturedLandsTeleport==true then
					local sourceRow=hexMap[tostring(hexDetail.coord[1])]
					local sourceHex=sourceRow~=nil and sourceRow[tostring(hexDetail.coord[2])] or nil
					local sourceTerrain=sourceHex~=nil and (sourceHex.terrainType or sourceHex.hexType) or nil
					for _, teleportHex in pairs(teleportHexesByTerrain[sourceTerrain] or {}) do
						local hor=teleportHex.coord[1]
						local vec=teleportHex.coord[2]
						if hor~=hexDetail.coord[1] or vec~=hexDetail.coord[2] then
							local hexCost=moveSpent+1
							local recordedMoveTotal=100
							if moveMap[tostring(hor)]~=nil and moveMap[tostring(hor)][tostring(vec)]~=nil then
								recordedMoveTotal=moveMap[tostring(hor)][tostring(vec)].main
								if moveMap[tostring(hor)][tostring(vec)].tricky~=nil then recordedMoveTotal=moveMap[tostring(hor)][tostring(vec)].tricky end
							end
							if hexCost<gStates.resourceTracker.move.move+searchLimit and hexCost<=recordedMoveTotal then
								if moveMap[tostring(hor)]==nil then moveMap[tostring(hor)]={} end
								if moveMap[tostring(hor)][tostring(vec)]==nil then moveMap[tostring(hor)][tostring(vec)]={} end
								local destinationMove=moveMap[tostring(hor)][tostring(vec)]
								local predecessor={hor=hexDetail.coord[1], vec=hexDetail.coord[2], state=sourceState, teleport=true}
								if hexCost==recordedMoveTotal then
									local existingPrev=destinationMove.tricky~=nil and destinationMove.trickyPrev or destinationMove.mainPrev
									if existingPrev~=nil and continuationPenalty(predecessor.hor,predecessor.vec,predecessor.state)<continuationPenalty(existingPrev.hor,existingPrev.vec,existingPrev.state) then
										if destinationMove.tricky~=nil then destinationMove.trickyPrev=predecessor else destinationMove.mainPrev=predecessor end
									end
								else
									if destinationMove.tricky==nil then
										destinationMove.main=hexCost
										destinationMove.mainPrev=predecessor
										destinationMove.mainCombat=false
									else
										destinationMove.tricky=hexCost
										destinationMove.trickyPrev=predecessor
										destinationMove.trickyCombat=false
									end
									local fringeKey=tostring(hor)..":"..tostring(vec)
									if tempFringeSet[fringeKey]~=true then
										tempFringeSet[fringeKey]=true
										tempFringe[#tempFringe+1]={coord={hor, vec}}
										noMove=false
									end
								end
							end
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
			return {((vec-(hor/2))*2.4)+startTilePos[1], 1.22, (hor*2.0785)+startTilePos[3]}
		end
		local function addRouteSegment(fromHor, fromVec, toHor, toVec, teleport, tunnelPath)
			local function addOne(aHor,aVec,bHor,bVec,mode)
				local key=tostring(aHor)..":"..tostring(aVec)..">"..tostring(bHor)..":"..tostring(bVec)..":"..tostring(mode)
				if routeSegmentSeen[key]==true then return end
				routeSegmentSeen[key]=true
				local color={0.50,0.50,0.50}
				if mode=="teleport" then color={0.20,0.70,1.00} elseif mode=="tunnel" then color={0.72,0.45,1.00} end
				routeLines[#routeLines+1]={points={routeWorldPosition(aHor,aVec),routeWorldPosition(bHor,bVec)},color=color,thickness=0.07,rotation={0,0,0}}
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
				local routeCost=moveDetails.main
				local routeState="main"
				if moveDetails.tricky~=nil and moveDetails.tricky<routeCost then routeCost=moveDetails.tricky routeState="tricky" end
				if routeCost~=nil and routeCost<=99 and routeCost<moveValue+searchLimit then queueRouteState(tonumber(hor), tonumber(vec), routeState) end
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
					--Only a state that lies on the retained cheapest-route tree deserves an alternate
					--slash value. Discovered-but-redundant continuations no longer create 4/5-style noise.
					local sourceRow=moveMap[tostring(previous.hor)]
					local sourceMove=sourceRow~=nil and sourceRow[tostring(previous.vec)] or nil
					if sourceMove~=nil then sourceMove[(previous.state or "main").."UsedOnward"]=1 end
					queueRouteState(previous.hor, previous.vec, previous.state or "main")
				end
			end
		end
		Global.setVectorLines(routeLines)

		--Highlight movement costs with spawned text instead of numbered image decals.
		for hor, rowOfHexes in pairs(moveMap) do
			local hexGridZ=((hor*2.0785)+startTilePos[3])
			for vec, hexCost in pairs(rowOfHexes) do
				local lowestHex=hexCost.main
				local lowestState="main"
				if hexCost.tricky~=nil and hexCost.tricky<lowestHex then lowestHex=hexCost.tricky lowestState="tricky" end
				local displayCost=tostring(lowestHex)
				local multipleCosts=false
				local dualCosts=nil
				local destinationHex=hexMap[tostring(hor)]~=nil and hexMap[tostring(hor)][tostring(vec)] or nil
				local destinationCombat=destinationHex~=nil and (destinationHex.dragonLair==true or (destinationHex.hexType~="explore" and destinationHex.fortified~=nil and destinationHex.fortified~="shield"))
				local combatMove=destinationCombat or (lowestState=="main" and hexCost.mainCombat==true) or (lowestState=="tricky" and hexCost.trickyCombat==true)
				if hexCost.main~=nil and hexCost.main<99 and hexCost.tricky~=nil and hexCost.tricky<99 and hexCost.main~=hexCost.tricky then
					local higherHex=math.max(hexCost.main, hexCost.tricky)
					local higherState=higherHex==hexCost.main and "main" or "tricky"
					if hexCost[higherState.."UsedOnward"]==1 then
						displayCost=tostring(lowestHex).."/"..tostring(higherHex)
						multipleCosts=true
						dualCosts={low=lowestHex,high=higherHex,
							lowCombat=destinationCombat or (lowestState=="main" and hexCost.mainCombat==true) or (lowestState=="tricky" and hexCost.trickyCombat==true),
							highCombat=destinationCombat or (higherState=="main" and hexCost.mainCombat==true) or (higherState=="tricky" and hexCost.trickyCombat==true)}
					end
				end
				local hexGridX=((vec-(hor/2))*2.4)+startTilePos[1]
				local startingHex=tonumber(hor)==playerHexGridHorizontal and tonumber(vec)==playerHexGridAxial
				if startingHex==false then
					if lowestHex<=gStates.resourceTracker.move.move then
						addMoveCostText(displayCost, hexGridX, hexGridZ, true, combatMove, multipleCosts, dualCosts)
					elseif lowestHex<=99 and lowestHex<gStates.resourceTracker.move.move+searchLimit then
						addMoveCostText(displayCost, hexGridX, hexGridZ, false, combatMove, multipleCosts, dualCosts)
					end
				end
			end
		end
		moveDisplayHideUnusedText(moveTextUsed)
end

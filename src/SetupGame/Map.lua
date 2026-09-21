-- Starting-map construction, Fury lair setup and scenario terrain layouts.

--Layout starting map tiles
firstTile=nil
startingMapSetup=false
startingMapTiles={}

--Fury of the Apocalypse Dragon uses the standalone single-hex Dragon token (42b581)
--stored directly in the Apocalypse Dragon bag. Keep the Core 1 object returned by takeObject()
--rather than relying on an immediate GUID lookup while TTS is still registering the deployed tile.
function furyDragonSetupLair(tile)
	if gStates==nil or gStates.gameScenario~="Fury of the Apocalypse Dragon" then return false end
	tile=tile or getObjectFromGUID(GUID.tile.core01)
	if tile==nil then return false end
	local bearing="240"
	local xy=angleToXY(tile,bearing)
	local hexPos={xy[1],1.00,xy[2]}
	local markerPos={xy[1],1.18,xy[2]}
	gStates.apocalypseDragonLairRevealed=true
	gStates.apocalypseDragonLair={tileGUID=tile.guid,hexes={{bearing=bearing,position=hexPos}},position=markerPos,rotation={0,180,0},fury=true,cityHexKey=tile.guid.."|"..bearing}
	--Fury alternates Landed/In Flight for the entire game. The selected flight target is the state
	--that makes the Dragon "in flight"; do not reset it at the start of later Rounds.
	gStates.furyDragonCurrentHexKey=tile.guid.."|"..bearing
	gStates.furyDragonFlightTarget=nil
	gStates.furyDragonManaDieGUID=nil
	gStates.furyDragonAwaitingCombat=nil
	gStates.furyDragonRoundPrepared=nil
	--Core tile 1's Tomb is the Dragon Lair in Fury and no longer counts as a Tomb.
	terrainTiles[tile.guid].hexFeature[bearing]=""
	gStates.hexOverideSave=gStates.hexOverideSave or {}
	gStates.hexOverideSave[tile.guid]=gStates.hexOverideSave[tile.guid] or {}
	gStates.hexOverideSave[tile.guid][bearing]=""

	local marker=getObjectFromGUID(apocalypseDragon.furyMarker)
	if marker==nil then
		local bag=getObjectFromGUID(GUID.bag.apocalypseDragon)
		if bag~=nil then
			local tilePos=tile.getPosition()
			marker=safeTakeObject("SetupGame",bag,{guid=apocalypseDragon.furyMarker,position={xy[1],tilePos[2]+1.0,xy[2]},rotation={0,180,0},smooth=false})
		end
	end
	if marker==nil then
		broadcastToAll("{en}Fury setup could not deploy the single-space Apocalypse Dragon marker (42b581).{ru}При подготовке «Ярости Дракона Апокалипсиса» не удалось разместить одиночный маркер Дракона Апокалипсиса (42b581).{zh-tw}「末日巨龍之怒」設置無法部署單格末日巨龍標記（42b581）。{zh-cn}“末日巨龙之怒”设置无法部署单格末日巨龙标记（42b581）。{ko}아포칼립스 드래곤의 분노 설정에서 단일 칸 아포칼립스 드래곤 마커(42b581)를 배치하지 못했습니다.{es}La preparación de Furia del Dragón del Apocalipsis no pudo desplegar el marcador de un espacio del Dragón del Apocalipsis (42b581).{fr}La mise en place de la Fureur du Dragon de l’Apocalypse n’a pas pu déployer le marqueur d’une case du Dragon de l’Apocalypse (42b581).{pt-br}A preparação de Fúria do Dragão do Apocalipse não conseguiu posicionar o marcador de um espaço do Dragão do Apocalipse (42b581).{de}Beim Aufbau von Zorn des Apokalypse-Drachen konnte der einfeldrige Apokalypse-Drachenmarker (42b581) nicht eingesetzt werden.",warningColor)
		return false
	end
	marker.unlock()
	marker.setRotation({0,180,0})
	return true
end

function mapSetup()
	startingMapSetup=true
	startingMapTiles={}
	local TileShuffler=		getObjectFromGUID(GUID.bag.terrain.shuffler)
	local CityTileStack=	getObjectFromGUID(GUID.bag.terrain.leftCity)
	local CoreTileStack=	getObjectFromGUID(GUID.bag.terrain.leftCore)
	local CountryTileStack=	getObjectFromGUID(GUID.bag.terrain.leftCountry)
	local customPredefined=gStates.gameScenario=="Custom" and scenarioList[gStates.scenarioRef][gStates.playersRef].mapShape:sub(5,5)=="P"
	if customPredefined then
		--Predefined Custom maps are built by the players. Leave all three selected terrain pools untouched.
		--Store every available tile face down so manual pulls from these bags begin hidden.
		local function faceDownTerrainPool(bag)
			if bag==nil then return end
			local pos=bag.getPosition()
			local guids={}
			for _,contained in ipairs(bag.getObjects()) do guids[#guids+1]=contained.guid end
			for _,guid in ipairs(guids) do
				local tile=bag.takeObject({guid=guid,position={pos.x,pos.y+2,pos.z},rotation={0,180,180},smooth=false})
				if tile~=nil then bag.putObject(tile) end
			end
		end
		faceDownTerrainPool(CityTileStack)
		faceDownTerrainPool(CoreTileStack)
		faceDownTerrainPool(CountryTileStack)
		local openStartPos={-36.0305,0.98,-11.9267}
		local startTile=getObjectFromGUID(startTerrain.wedge)
		local portalObj=getObjectFromGUID(portal.terrainHex)
		if startTile~=nil then
			startTile.unlock()
			if portalObj~=nil then portalObj.unlock() end
			startTile.setPosition(openStartPos)
			if portalObj~=nil then portalObj.setPosition({openStartPos[1],1.1,openStartPos[3]}) end
			startTile.setState(2)
			safeWaitFrames("SetupGame",function()
				local openStart=getObjectFromGUID(startTerrain.open)
				if openStart~=nil then openStart.unlock() end
				local currentPortal=getObjectFromGUID(portal.terrainHex)
				if currentPortal~=nil then currentPortal.unlock() end
			end,5)
		else
			local openStart=getObjectFromGUID(startTerrain.open)
			if openStart~=nil then openStart.unlock() end
			if portalObj~=nil then portalObj.unlock() end
		end
		if TileShuffler~=nil then TileShuffler.destruct() end
		Global.setDecals({})
		startingMapSetup=false
		return
	end
	CityTileStack.shuffle()
	CoreTileStack.shuffle()
	CountryTileStack.shuffle()
	local againstHorsemenMap=gStates.gameScenario=="Against the Horsemen Blitz"
	local furyMap=gStates.gameScenario=="Fury of the Apocalypse Dragon"
	local againstHorsemenCountryTilePos={}
	local againstHorsemenCoreTilePos={}
	local againstHorsemenCityTilePos={}
	local againstHorsemenCoreTileGUIDs={}
	local furyCountrySlots={}
	local furyCoreTilePos={}
	local furyCityTilePos={}
	local furyRevealGUIDs={}
	local furyLairTile=nil
	if furyMap then
		--Exact predefined layouts from the Fury scenario sheet. Place every selected tile face down first;
		--the slots that begin revealed are flipped later in a stepped sequence so normal terrain-entry
		--population logic gets a clean event for each tile.
		local start={-36.0305,1.15,-11.9267}
		local basisA,basisB,countryCoords,faceUpCoords,coreCoords,cityCoords
		if gStates.playerCount<=2 then
			--Solo/two-player Fury uses the normal Wedge start tile and its recorded grid position.
			start={-24.0301,1.15,-16.0837}
			basisA=terrainPlacementNeighbourOffsets[1] basisB=terrainPlacementNeighbourOffsets[2]
			countryCoords={{0,1},{1,0},{1,1},{2,0},{0,2},{0,3},{3,0}}
			faceUpCoords={{0,1},{1,0}}
			coreCoords={{2,2},{1,2},{2,1}}
			cityCoords={{1,3},{3,1}}
		elseif gStates.playerCount==3 then
			basisA=terrainPlacementNeighbourOffsets[1] basisB=terrainPlacementNeighbourOffsets[2]
			countryCoords={{0,1},{1,0},{1,-1},{1,1},{2,0},{2,-1},{3,-1},{4,-1},{0,2},{1,2}}
			faceUpCoords={{0,1},{1,0},{1,-1}}
			coreCoords={{3,1},{2,1},{3,0}}
			cityCoords={{2,2},{4,0}}
		else
			--Four-player Fury uses the open start on the nearest recorded grid point to {-30.03,-13.99}.
			start={-30.0303,1.15,-14.0052}
			basisA=terrainPlacementNeighbourOffsets[6] basisB=terrainPlacementNeighbourOffsets[5]
			countryCoords={{0,-1},{1,-1},{1,0},{1,-4},{1,-3},{0,-3},{4,-3},{0,-2},{1,-2},{2,-2},{3,-2},{2,-1}}
			faceUpCoords={{0,-1},{1,-1},{1,0}}
			coreCoords={{3,-4},{2,-3},{3,-3}}
			cityCoords={{2,-4},{4,-4}}
		end
		local function key(coord) return tostring(coord[1])..","..tostring(coord[2]) end
		local faceUp={} for _,coord in ipairs(faceUpCoords) do faceUp[key(coord)]=true end
		local function furyPos(coord) return {start[1]+coord[1]*basisA[1]+coord[2]*basisB[1],start[2],start[3]+coord[1]*basisA[2]+coord[2]*basisB[2]} end
		for _,coord in ipairs(countryCoords) do furyCountrySlots[#furyCountrySlots+1]={position=furyPos(coord),faceUp=faceUp[key(coord)]==true} end
		for _,coord in ipairs(coreCoords) do furyCoreTilePos[#furyCoreTilePos+1]=furyPos(coord) end
		for _,coord in ipairs(cityCoords) do furyCityTilePos[#furyCityTilePos+1]=furyPos(coord) end
		gStates.furyHeroEnteredCity=false
		--Suppress the Tomb before Core 1 enters the map zone, so setup never treats the Fury Lair as a Tomb.
		terrainTiles[GUID.tile.core01].hexFeature["240"]=""
		gStates.hexOverideSave=gStates.hexOverideSave or {}
		gStates.hexOverideSave[GUID.tile.core01]=gStates.hexOverideSave[GUID.tile.core01] or {}
		gStates.hexOverideSave[GUID.tile.core01]["240"]=""
	end
	if againstHorsemenMap then
		--Radius-two predefined map from the Apocalypse rulebook. Use the existing terrain-placement
		--vectors so these positions stay on exactly the same lattice as every other scripted map.
		--The temporary normal portal/start tile remains separate; avatars are transferred later in setup.
		local centre={-16.8299,1.15,4.7015}
		local east=terrainPlacementNeighbourOffsets[6]
		local northEast=terrainPlacementNeighbourOffsets[1]
		local function horsemenMapPos(q,r)
			return {centre[1]+(q*east[1])+(r*northEast[1]),centre[2],centre[3]+(q*east[2])+(r*northEast[2])}
		end
		againstHorsemenCountryTilePos[1]=horsemenMapPos(0,0)
		for _,coord in ipairs({{-1,1},{0,1},{1,0},{1,-1},{0,-1},{-1,0}}) do
			againstHorsemenCountryTilePos[#againstHorsemenCountryTilePos+1]=horsemenMapPos(coord[1],coord[2])
		end
		--Outer ring, clockwise from the top: Core, Country, City, Core, City, Country,
		--Core, Country, City, Core, City, Country (matching the printed scenario diagram).
		local outer={
			{{-2,2},"core"},{{-1,2},"country"},{{0,2},"city"},{{1,1},"core"},
			{{2,0},"city"},{{2,-1},"country"},{{2,-2},"core"},{{1,-2},"country"},
			{{0,-2},"city"},{{-1,-1},"core"},{{-2,0},"city"},{{-2,1},"country"}
		}
		for _,entry in ipairs(outer) do
			local p=horsemenMapPos(entry[1][1],entry[1][2])
			if entry[2]=="country" then againstHorsemenCountryTilePos[#againstHorsemenCountryTilePos+1]=p
			elseif entry[2]=="core" then againstHorsemenCoreTilePos[#againstHorsemenCoreTilePos+1]=p
			else againstHorsemenCityTilePos[#againstHorsemenCityTilePos+1]=p end
		end
	end
	--Reserve the complete Hero Challenge Countryside assignment before Ultimate Conquest moves
	--surplus Countryside tiles into its mixed Core/Country stack. Otherwise a required GUID can
	--be moved out of CountryTileStack before the later fixed-GUID takeObject() calls.
	local heroCountryAssignment=nil
	if gStates.heroChallenges==true then
		heroCountryAssignment=heroChallengeCountryAssignment(true)
		if heroCountryAssignment==nil then
			print("HERO CHALLENGE SETUP ERROR: no legal Countryside assignment")
			startingMapSetup=false
			return
		end
	end
	local pos=getObjectFromGUID(GUID.bag.terrain.stack).getPosition()--tile stack location
	local tUp=2--Starts building the final tile stack from this high
	--Layout Starting map tile. The Horsemen predefined map temporarily keeps this normal reference
	--during terrain-entry setup, then removes it once every real map tile has settled.
	local a=scenarioList[gStates.scenarioRef][gStates.playersRef].mapShape:sub(5,5)
	local furyWedgeStart=furyMap and gStates.playerCount<=2
	if (a=="O" or a=="F" or a=="P") and furyWedgeStart~=true then
		local openStartPos={-36.0305,0.98,-11.9267}
		if furyMap and gStates.playerCount>=4 then openStartPos={-30.0303,0.98,-14.0052} end
		getObjectFromGUID(startTerrain.wedge).unlock()
		getObjectFromGUID(portal.terrainHex).unlock()
		getObjectFromGUID(startTerrain.wedge).setPosition(openStartPos)--start terrain tile gets moved and state changed
		getObjectFromGUID(portal.terrainHex).setPosition({openStartPos[1],1.1,openStartPos[3]})--portal overlay follows the start tile
		getObjectFromGUID(startTerrain.wedge).setState(2)
		safeWaitFrames("SetupGame",function() getObjectFromGUID(startTerrain.open).lock() getObjectFromGUID(portal.terrainHex).lock() end, 5)
	end

	--Add Grid
	local gridType=""
	if scenarioList[gStates.scenarioRef][gStates.playersRef].mapShape=="{en}Open Limited to 4 Columns{ru}Открытое поле с ограничением в 4 ряда{zh-tw}4 列的限制開放地圖{zh-cn}4 列的限制开放地图 {ko}4열 제한{es}Abierto Limitado a 4 Columnas{fr}Ouvert Limité à 4 Colonnes{pt-br}Aberto Limitado a 4 Colunas{de}Offen Begrenzt auf 4 Spalten" then gridType="https://steamusercontent-a.akamaihd.net/ugc/1674736055049111266/7BC768B7CD64E6018EBEC720559690409F4BA555/" end--4
	if scenarioList[gStates.scenarioRef][gStates.playersRef].mapShape=="{en}Open Limited to 3 Columns{ru}Открытое поле с ограничением в 3 ряда{zh-tw}3 列的限制開放地圖{zh-cn}3 列的限制开放地图 {ko}3열 제한{es}Abierto Limitado a 3 Columnas{fr}Ouvert Limité à 3 Colonnes{pt-br}Aberto Limitado a 3 Colunas{de}Offen Begrenzt auf 3 Spalten" then gridType="https://steamusercontent-a.akamaihd.net/ugc/1674736055049110361/978D612A44ADDE6E1630965A311722114BA28AE5/" end--3
	if scenarioList[gStates.scenarioRef][gStates.playersRef].mapShape=="{en}Fully Open{ru}Полностью открытое поле{zh-tw}完全開放地圖{zh-cn}完全开放地图{ko}전체 개방형{es}Totalmente Abierto{fr}Entièrement Ouvert{pt-br}Totalmente Aberto{de}Vollständig Offen" then gridType="https://steamusercontent-a.akamaihd.net/ugc/1674736055049031257/2457D03CE33118D57CD456183026FEB596CF6A3A/" end--fully
	if scenarioList[gStates.scenarioRef][gStates.playersRef].mapShape=="{en}Wedge{ru}Клиновидное поле{zh-tw}錐形地圖{zh-cn}锥形地图{ko}쐐기형{es}En Cuña{fr}Coin{pt-br}Cônico{de}Keil" then gridType="https://steamusercontent-a.akamaihd.net/ugc/1674736055049113832/44EE3C6AA10498BCD1B46040AD18631BFD580AC4/" end--Wedge
	if gStates.gameScenario=="The Gauntlet" then gridType="https://steamusercontent-a.akamaihd.net/ugc/1673610837369514853/1BBAD048566E753F09184CBAE7022049D90B5471/" end
	if againstHorsemenMap then gridType="" end
	Global.setDecals({})
	if gridType~="" then Global.addDecal({name="Terrain Grid", url=gridType, position={-16.825, 0.99, 0.55}, rotation={90.0, 0.0, 0.0}, scale={60, 60, 1}}) end

	--shuffle the order of data in a table
	function listShuffle(array)
		--Remove lost legion GUIDs
		if gStates.removeLostLegionExpansion==true then
			local tempArray={}
			local lostLegionTiles={GUID.tile.country12, GUID.tile.country13, GUID.tile.country14, GUID.tile.core09, GUID.tile.core10}--12, 13, 14, *9*, *10*
			for a=1, #array, 1 do
				local found=false
				for b=1, #lostLegionTiles, 1 do
					if array[a]==lostLegionTiles[b] then found=true end
				end
				if found==false then tempArray[#tempArray+1]=array[a] end
			end
			array=tempArray
		end
		if gStates.removeApocalypseTerrain==true then
			local tempArray={}
			local ApocalypseTiles={GUID.tile.country15, GUID.tile.country16, GUID.tile.country17, GUID.tile.core11, GUID.tile.core12}--15, 16, 17, *11*, *12*
			for a=1, #array, 1 do
				local found=false
				for b=1, #ApocalypseTiles, 1 do
					if array[a]==ApocalypseTiles[b] then found=true end
				end
				if found==false then tempArray[#tempArray+1]=array[a] end
			end
			array=tempArray
		end
		if gStates.removeTerrain==true then
			local tempArray={}
			local EasyTiles={GUID.tile.country01, GUID.tile.country02}
			for a=1, #array, 1 do
				local found=false
				for b=1, #EasyTiles, 1 do
					if array[a]==EasyTiles[b] then found=true end
				end
				if found==false then tempArray[#tempArray+1]=array[a] end
			end
			array=tempArray
		end
		--shuffle the list
		local tReturn={}
		for a=#array, 1, -1 do
			local b=math.random(a)
			array[a], array[b]=array[b], array[a]
			table.insert(tReturn, array[a])
		end
		return tReturn
	end
	--Pull City Tiles
	local warOfFourCityTilePos={{-32.4304, 1.15, -1.5341}, {-25.2302, 1.15, -9.8482}, {-28.8303, 1.15, 8.8586}, {-22.8301, 1.15, 6.7794}, {-15.6299, 1.15, -1.5341}, {-14.4298, 1.15, -7.7696}}
	local warOfFourCoreTilePos={{-24.0301, 1.15, 13.0156}, {-16.8299, 1.15,  4.7015}, {-9.6297, 1.15, -3.6126}}
	for i=1, gStates.cityTiles, 1 do
		local noShuffle=0
		local params={rotation={0, 180, 180}, smooth=false}
		if gStates.randomTileOrientation==true then params.rotation={0, math.random(1,6)*60, 180} end
		if i==1 and (gStates.gameScenario=="Mines Liberation" or gStates.gameScenario=="Life and Death" or gStates.gameScenario=="The Chaos Rift" or gStates.gameScenario=="Raiders of the Crusader Temple") then params.guid=GUID.tile.city08 end--Use Red City
		if i==1 and (gStates.gameScenario=="Dungeon Lords" or gStates.gameScenario=="The Realm of the Dead Blitz") then params.guid=GUID.tile.city06 end--Use Blue City
		if i==1 and (gStates.gameScenario=="Conquer and Hold" or gStates.gameScenario=="The Hidden Valley Blitz") then params.guid=GUID.tile.city07 end--Use White City
		if (gStates.gameScenario=="Druid Nights" and i==1) or (gStates.gameScenario=="The Realm of the Dead Blitz" and i==2) or (gStates.gameScenario=="Life and Death" and i==2) or (gStates.gameScenario=="The Hidden Valley Blitz" and i==2) then params.guid=GUID.tile.city05 end--Use Green City
		if (gStates.gameScenario=="Volkare's Return" and i==1) or gStates.gameScenario=="Volkare's Return Blitz" or gStates.gameScenario=="The Chaos Rift" then params.position={pos.x, pos.y+tUp, pos.z} tUp=tUp+0.5 noShuffle=1 end--puts city at bottom of stack
		if gStates.gameScenario=="The Gauntlet" and i==1 then params.guid=GUID.tile.city08 params.position={4.7708, 0.96, 8.8586} noShuffle=1 end
		if againstHorsemenMap then params.position=againstHorsemenCityTilePos[i] noShuffle=1 end
		if furyMap then
			params.position=furyCityTilePos[i]
			params.rotation={0,gStates.randomTileOrientation==true and math.random(1,6)*60 or 180,180}
			noShuffle=1
		end
		if gStates.gameScenario=="The War of Four" then
			local randPos=math.random(1,#warOfFourCityTilePos)
			if warOfFourCityTilePos[randPos][1]==-28.8303 or warOfFourCityTilePos[randPos][1]==-15.6299 then
				warOfFourCoreTilePos[#warOfFourCoreTilePos+1]=warOfFourCityTilePos[randPos+1]
				table.remove(warOfFourCityTilePos, randPos+1)
			end
			params.position=warOfFourCityTilePos[randPos]
			noShuffle=1
			if warOfFourCityTilePos[randPos][1]==-22.8301 or warOfFourCityTilePos[randPos][1]==-14.4298 then
				warOfFourCoreTilePos[#warOfFourCoreTilePos+1]=warOfFourCityTilePos[randPos-1]
				table.remove(warOfFourCityTilePos, randPos-1)
				table.remove(warOfFourCityTilePos, randPos-1)
			else
				table.remove(warOfFourCityTilePos, randPos)
			end
		end
		local obj=safeTakeObject("SetupGame",CityTileStack,params)--take from the City Tile Bag
		if furyMap and obj~=nil then furyRevealGUIDs[#furyRevealGUIDs+1]=obj.guid end
		if noShuffle==0 then TileShuffler.putObject(obj) end--Place in the Core Tile Shuffler if it is shuffled
	end

	--Pull Core Tiles
	local CoreKeepMageTiles=	{GUID.tile.core02, GUID.tile.core03, GUID.tile.core04, GUID.tile.core09, GUID.tile.core10} CoreKeepMageTiles=listShuffle(CoreKeepMageTiles)
	local CoreGauntletTiles=	{GUID.tile.core02, GUID.tile.core04, GUID.tile.core09, GUID.tile.core10} CoreGauntletTiles=listShuffle(CoreGauntletTiles)
	local CoreMineTiles=		{GUID.tile.core02, GUID.tile.core03, GUID.tile.core04} CoreMineTiles=listShuffle(CoreMineTiles)
	local CoreRuinTiles=		{GUID.tile.core02, GUID.tile.core03, GUID.tile.core04, GUID.tile.core11} CoreRuinTiles=listShuffle(CoreRuinTiles)
	local CorePyramidTiles=		{GUID.tile.core11, GUID.tile.core12} CorePyramidTiles=listShuffle(CorePyramidTiles)
	local CoreNotPyramidTiles=	{GUID.tile.core01, GUID.tile.core02, GUID.tile.core03, GUID.tile.core04, GUID.tile.core09, GUID.tile.core10} CoreNotPyramidTiles=listShuffle(CoreNotPyramidTiles)
	local CoreNotDragonLairTiles={GUID.tile.core01, GUID.tile.core02, GUID.tile.core04, GUID.tile.core09, GUID.tile.core10, GUID.tile.core11, GUID.tile.core12} CoreNotDragonLairTiles=listShuffle(CoreNotDragonLairTiles)
	local CoreNotFuryLairTiles={GUID.tile.core02, GUID.tile.core03, GUID.tile.core04, GUID.tile.core09, GUID.tile.core10, GUID.tile.core11, GUID.tile.core12} CoreNotFuryLairTiles=listShuffle(CoreNotFuryLairTiles)
	local coreTilesToUse=scenarioList[gStates.scenarioRef][gStates.playersRef].coreTiles
	if gStates.gameScenario=="Ultimate Conquest" then coreTilesToUse=CoreTileStack.getQuantity() end
	for i=1, coreTilesToUse, 1 do
		local params={rotation={0, 180, 180}, smooth=false}
		if againstHorsemenMap and gStates.randomTileOrientation==true then params.rotation={0, math.random(1,6)*60, 180} end
		if gStates.gameScenario=="Mines Liberation" then params.guid=CoreMineTiles[i] end
		if gStates.gameScenario=="Conquer and Hold" then params.guid=CoreKeepMageTiles[i] end
		if gStates.gameScenario=="Dungeon Lords" and i==1 then params.guid=GUID.tile.core01 end
		if gStates.gameScenario=="The Gauntlet" and i<=4 then params.guid=CoreGauntletTiles[i] end
		if gStates.gameScenario=="Raiders of the Crusader Temple" and (i<=3 or (i<=4 and gStates.removeApocalypseTerrain~=true)) then params.guid=CoreRuinTiles[i] end
		if gStates.gameScenario=="Against the Apocalypse Blitz" and i==1 then params.guid=CorePyramidTiles[i] end
		if gStates.gameScenario=="Against the Apocalypse Blitz" and i>=2 then params.guid=CoreNotPyramidTiles[i-1] end
		if gStates.gameScenario=="Against the Dragon Blitz" and i==1 then params.guid=GUID.tile.core03 end
		if gStates.gameScenario=="Against the Dragon Blitz" and i>=2 then params.guid=CoreNotDragonLairTiles[i-1] end
		if gStates.gameScenario=="Fury of the Apocalypse Dragon" and i==1 then params.guid=GUID.tile.core01 end
		if gStates.gameScenario=="Fury of the Apocalypse Dragon" and i>=2 then params.guid=CoreNotFuryLairTiles[i-1] end
		if againstHorsemenMap then
			params.position=againstHorsemenCoreTilePos[i]
			local coreTile=safeTakeObject("SetupGame",CoreTileStack,params)
			if coreTile==nil then print("HORSEMEN SETUP ERROR: Core tile "..tostring(i).." was not available") startingMapSetup=false return end
			againstHorsemenCoreTileGUIDs[i]=coreTile.guid
		elseif furyMap then
			params.position=furyCoreTilePos[i]
			params.rotation={0,gStates.randomTileOrientation==true and math.random(1,6)*60 or 180,180}
			local coreTile=safeTakeObject("SetupGame",CoreTileStack,params)
			if coreTile==nil then print("FURY SETUP ERROR: Core tile "..tostring(i).." was not available") startingMapSetup=false return end
			if i==1 then furyLairTile=coreTile end
			furyRevealGUIDs[#furyRevealGUIDs+1]=coreTile.guid
		else
			TileShuffler.putObject(safeTakeObject("SetupGame",CoreTileStack,params))--Core Tile Shuffler
		end
	end
	--Ultimate Conquest Country mix. With Hero Challenges, move only tiles that are not reserved
	--for the Countryside section that sits on top of the mixed stack.
	if gStates.gameScenario=="Ultimate Conquest" then
		local megaCountry=math.max(CountryTileStack.getQuantity()-scenarioList[gStates.scenarioRef][gStates.playersRef].countryTiles,0)
		if heroCountryAssignment~=nil then
			local reserved={}
			for _,guid in pairs(heroCountryAssignment) do reserved[guid]=true end
			local surplusGUIDs={}
			for _,contained in ipairs(CountryTileStack.getObjects()) do
				if contained.guid~=nil and reserved[contained.guid]~=true then surplusGUIDs[#surplusGUIDs+1]=contained.guid end
			end
			surplusGUIDs=heroChallengeShuffleCopy(surplusGUIDs)
			for i=1, megaCountry, 1 do
				local guid=surplusGUIDs[i]
				if guid==nil then print("ULTIMATE CONQUEST SETUP ERROR: not enough unreserved Countryside tiles") startingMapSetup=false return end
				local countryTile=CountryTileStack.takeObject({guid=guid,rotation={0, 180, 180},smooth=false})
				if countryTile==nil then print("ULTIMATE CONQUEST SETUP ERROR: could not reserve Hero Challenge Countryside tile set") startingMapSetup=false return end
				TileShuffler.putObject(countryTile)
			end
		else
			for i=1, megaCountry, 1 do
				local params={rotation={0, 180, 180}, smooth=false}
				TileShuffler.putObject(safeTakeObject("SetupGame",CountryTileStack,params))
			end
		end
	end

	--place core and city tiles on stack shuffled
	TileShuffler.shuffle()
	local VolQuestTilePos=		{{-18.0299, 1.15, 10.9371}, {-16.8299, 1.15,  4.7015}, {-22.8301, 1.15,  6.7794}, {-10.8297, 1.15,  2.6230}, {-15.6299, 1.15, -1.5341}, {-9.6297, 1.15, -3.6126}, {-14.4298, 1.15, -7.7696}, {-21.6300, 1.15, 0.5445}}
	local ConquerAndHoldTilePos={{-27.6302, 1.15,  2.6230}, {-21.6300, 1.15,  0.5445}, {-26.4302, 1.15, -3.6126}, {-20.4300, 1.15, -5.6911}}
	local GauntletTilePos=		{{ -0.0294, 1.15,  4.7015}, { -4.8295, 1.15,  0.5445}, { -9.6297, 1.15, -3.6126}}
	for i=1, TileShuffler.getQuantity(), 1 do
		local params={smooth=false}
		if gStates.randomTileOrientation==false then params.rotation={0, 180, 180} else params.rotation={0, math.random(1,6)*60, 180} end
		if gStates.gameScenario=="Volkare's Quest" then
			if i==6 and gStates.playersRef==5 then
				params.position=VolQuestTilePos[8]
			else
				params.position=VolQuestTilePos[i]
			end
		end
		if gStates.gameScenario=="The War of Four" then
			params.position=warOfFourCoreTilePos[i]
		end
		if gStates.gameScenario=="Conquer and Hold" then params.position=ConquerAndHoldTilePos[i] end
		if gStates.gameScenario=="The Gauntlet" then params.position=GauntletTilePos[i] end
		if params.position==nil then params.position={pos.x, pos.y+tUp, pos.z} tUp=tUp+0.5 end
		safeTakeObject("SetupGame",TileShuffler,params)
	end

	--Pull Country Tiles
	local CountryGauntletTiles=			{GUID.tile.country01, GUID.tile.country02, GUID.tile.country03, GUID.tile.country04, GUID.tile.country05, GUID.tile.country06, GUID.tile.country07, GUID.tile.country08, GUID.tile.country09, GUID.tile.country10, GUID.tile.country12, GUID.tile.country13, GUID.tile.country14, GUID.tile.country15, GUID.tile.country16, GUID.tile.country17} CountryGauntletTiles=listShuffle(CountryGauntletTiles)
	local function countryTileHasVillage(guid)
		local data=terrainTiles[guid]
		if data==nil or data.hexFeature==nil then return false end
		for _, feature in pairs(data.hexFeature) do if feature=="village" then return true end end
		return false
	end
	local function questVillageFirst(array)
		if apocalypseQuestsUsed()==false then return array end
		for i, guid in ipairs(array) do
			if countryTileHasVillage(guid) then array[1], array[i]=array[i], array[1] break end
		end
		return array
	end
	local CountryVillageTiles={}
	for guid, data in pairs(terrainTiles) do if data.tileType=="country" and countryTileHasVillage(guid) then CountryVillageTiles[#CountryVillageTiles+1]=guid end end
	CountryVillageTiles=listShuffle(CountryVillageTiles)
	local CountryTileOrder=				{GUID.tile.country03, GUID.tile.country04, GUID.tile.country05, GUID.tile.country06, GUID.tile.country07, GUID.tile.country08, GUID.tile.country09, GUID.tile.country10, GUID.tile.country11, GUID.tile.country02, GUID.tile.country01}--tiles 01 and 02 at end to deploy corectly at start
	local CountryNonMonasteryTiles=		{GUID.tile.country01, GUID.tile.country02, GUID.tile.country03, GUID.tile.country04, GUID.tile.country06, GUID.tile.country08, GUID.tile.country09, GUID.tile.country10, GUID.tile.country11, GUID.tile.country13, GUID.tile.country14, GUID.tile.country15, GUID.tile.country16, GUID.tile.country17} CountryNonMonasteryTiles=listShuffle(CountryNonMonasteryTiles)
	local CountryNonMineTiles=			{GUID.tile.country01, GUID.tile.country04, GUID.tile.country07, GUID.tile.country08, GUID.tile.country09, GUID.tile.country10, GUID.tile.country11, GUID.tile.country12, GUID.tile.country16}	CountryNonMineTiles=listShuffle(CountryNonMineTiles)
	local CountryNotGladeTiles=			{GUID.tile.country03, GUID.tile.country04, GUID.tile.country06, GUID.tile.country09, GUID.tile.country10, GUID.tile.country11, GUID.tile.country12, GUID.tile.country14, GUID.tile.country15, GUID.tile.country17} CountryNotGladeTiles=listShuffle(CountryNotGladeTiles)
	local CountryMonasteryMageTiles=	{GUID.tile.country04, GUID.tile.country05, GUID.tile.country07, GUID.tile.country09, GUID.tile.country11, GUID.tile.country12, GUID.tile.country13, GUID.tile.country15} CountryMonasteryMageTiles=listShuffle(CountryMonasteryMageTiles)
	local CountryNotMonasteryMageTiles=	{GUID.tile.country01, GUID.tile.country02, GUID.tile.country03, GUID.tile.country06, GUID.tile.country08, GUID.tile.country10, GUID.tile.country14, GUID.tile.country16, GUID.tile.country17}	CountryNotMonasteryMageTiles=listShuffle(CountryNotMonasteryMageTiles)
	local CountryKeepMageTiles=			{GUID.tile.country03, GUID.tile.country04, GUID.tile.country09, GUID.tile.country10, GUID.tile.country11, GUID.tile.country13, GUID.tile.country14, GUID.tile.country15, GUID.tile.country17} CountryKeepMageTiles=listShuffle(CountryKeepMageTiles)
	local CountryGladeTiles=			{GUID.tile.country01, GUID.tile.country02, GUID.tile.country05, GUID.tile.country07, GUID.tile.country08, GUID.tile.country13, GUID.tile.country16} CountryGladeTiles=listShuffle(CountryGladeTiles)
	local CountryMineTiles=				{GUID.tile.country02, GUID.tile.country03, GUID.tile.country05, GUID.tile.country06, GUID.tile.country13, GUID.tile.country14, GUID.tile.country15, GUID.tile.country17} CountryMineTiles=listShuffle(CountryMineTiles)
	local CountryMonasteryTiles=		{GUID.tile.country05, GUID.tile.country07, GUID.tile.country12} CountryMonasteryTiles=listShuffle(CountryMonasteryTiles)
	local CountryDungeonTiles=			{GUID.tile.country07, GUID.tile.country09}
	local CountryRuinTiles=				{GUID.tile.country08, GUID.tile.country10, GUID.tile.country11} CountryRuinTiles=listShuffle(CountryRuinTiles)
	local CountryZigguratTiles=			{GUID.tile.country16, GUID.tile.country17} CountryZigguratTiles=listShuffle(CountryZigguratTiles)
	local CountryNotZigguratTiles=		{GUID.tile.country01, GUID.tile.country02, GUID.tile.country03, GUID.tile.country04, GUID.tile.country05, GUID.tile.country06, GUID.tile.country07, GUID.tile.country08, GUID.tile.country09, GUID.tile.country10, GUID.tile.country11, GUID.tile.country12, GUID.tile.country13, GUID.tile.country14, GUID.tile.country15} CountryNotZigguratTiles=listShuffle(CountryNotZigguratTiles)
	--Quest games need a Village in the selected Countryside set. Promote a compatible Village inside each
	--scenario-specific pool so the existing Mine/Glade/Keep/Ruin/etc. terrain rules still choose their normal tile types.
	if apocalypseQuestsUsed()==true then
		CountryGauntletTiles=questVillageFirst(CountryGauntletTiles)
		CountryKeepMageTiles=questVillageFirst(CountryKeepMageTiles)
		CountryGladeTiles=questVillageFirst(CountryGladeTiles)
		CountryMonasteryMageTiles=questVillageFirst(CountryMonasteryMageTiles)
		CountryRuinTiles=questVillageFirst(CountryRuinTiles)
		CountryZigguratTiles=questVillageFirst(CountryZigguratTiles)
	end
	local questVillageGUID=nil
	local count=0
	local druidGladeSlots=math.min(#CountryGladeTiles,scenarioList[gStates.scenarioRef][gStates.playersRef].countryTiles)
	local params={}
	for i=1, scenarioList[gStates.scenarioRef][gStates.playersRef].countryTiles, 1 do
		params={rotation={0, 180, 180}, smooth=false}
		if againstHorsemenMap and gStates.randomTileOrientation==true then params.rotation={0, math.random(1,6)*60, 180} end
		if againstHorsemenMap and i==1 then params.guid=GUID.tile.country01 end
		if gStates.gameScenario=="First Reconnaissance" and i<=scenarioList[gStates.scenarioRef][gStates.playersRef].countryTiles-2 then params.guid=CountryTileOrder[i] end
		if gStates.gameScenario=="First Reconnaissance" and i>=scenarioList[gStates.scenarioRef][gStates.playersRef].countryTiles-1 then params.guid=CountryTileOrder[i+(11-scenarioList[gStates.scenarioRef][gStates.playersRef].countryTiles)] end
		if gStates.gameScenario=="Mines Liberation" and i<=4 then params.guid=CountryMineTiles[i] end
		if gStates.gameScenario=="Mines Liberation" and i>=5 then params.guid=CountryNonMineTiles[i-4] end
		if gStates.gameScenario=="Conquer and Hold" then params.guid=CountryKeepMageTiles[i] end
		if gStates.gameScenario=="The Gauntlet" then params.guid=CountryGauntletTiles[i] end
		if gStates.gameScenario=="Druid Nights" and i<=druidGladeSlots then params.guid=CountryGladeTiles[i] end
		if gStates.gameScenario=="Druid Nights" and i>druidGladeSlots then params.guid=CountryNotGladeTiles[i-druidGladeSlots] end
		if gStates.gameScenario=="Dungeon Lords" and i<=2 then params.guid=CountryDungeonTiles[i] end
		if (gStates.gameScenario=="Quest for the Golden Grail" or gStates.gameScenario=="The Chaos Rift") and i<=4 then params.guid=CountryMonasteryMageTiles[i] end
		if (gStates.gameScenario=="Quest for the Golden Grail" or gStates.gameScenario=="The Chaos Rift") and i>=5 then params.guid=CountryNotMonasteryMageTiles[i-4] end
		if gStates.gameScenario=="Life and Death" and ((i<=gStates.playerCount+1 and gStates.playerCount>=2) or (i<=3 and gStates.playerCount==1)) then params.guid=CountryGladeTiles[i] count=count+1 end
		if gStates.gameScenario=="Life and Death" and ((i>=gStates.playerCount+2 and gStates.playerCount>=2) or (i>=4 and gStates.playerCount==1)) then params.guid=CountryNotGladeTiles[i-count] end
		if gStates.gameScenario=="The Realm of the Dead Blitz" and ((i<=gStates.playerCount+1 and gStates.coop==1) or (i<=gStates.playerCount and gStates.coop==0)) then params.guid=CountryGladeTiles[i] count=count+1 end
		if gStates.gameScenario=="The Realm of the Dead Blitz" and ((i>=gStates.playerCount+2 and gStates.coop==1) or (i>=gStates.playerCount+1 and gStates.coop==0)) then params.guid=CountryNotGladeTiles[i-count] end
		if gStates.gameScenario=="Raiders of the Crusader Temple" and i<=3 then params.guid=CountryRuinTiles[i] end
		if gStates.gameScenario=="Against the Apocalypse Blitz" and i==1 then params.guid=CountryZigguratTiles[i] count=count+1 end
		if gStates.gameScenario=="Against the Apocalypse Blitz" and i==2 and gStates.playerCount>1 then params.guid=CountryZigguratTiles[i] count=count+1 end
		if gStates.gameScenario=="Against the Apocalypse Blitz" and ((i>=3 and gStates.playerCount>1) or (i>=2 and gStates.playerCount==1)) then params.guid=CountryNotZigguratTiles[i-count] end
		--Hero Challenges use a complete pre-validated assignment. It already satisfies the scenario's slot rule,
		--all selected Heroes' required tiles, expansion/removal settings, and the Quest Village requirement.
		if heroCountryAssignment~=nil then params.guid=heroCountryAssignment[i] end
		--Record a Village supplied by the scenario scheme. If this is an unrestricted slot and none has been
		--selected yet, use an available Village here instead of overriding a scenario-specific terrain requirement.
		if apocalypseQuestsUsed()==true and questVillageGUID==nil then
			if params.guid~=nil and countryTileHasVillage(params.guid) then
				questVillageGUID=params.guid
			elseif params.guid==nil and CountryVillageTiles[1]~=nil then
				params.guid=CountryVillageTiles[1]
				questVillageGUID=params.guid
			end
		end
		if againstHorsemenMap then
			params.position=againstHorsemenCountryTilePos[i]
			if i==1 then
				params.callback_function=function(obj)
					safeWaitTime("SetupGame",function() gStates.firstStarted=true firstTile=obj.guid obj.flip() end,1)
				end
			end
		elseif furyMap then
			local slot=furyCountrySlots[i]
			params.position=slot.position
			params.rotation={0,gStates.randomTileOrientation==true and math.random(1,6)*60 or 180,180}
		end
		local countryTile=safeTakeObject("SetupGame",CountryTileStack,params)
		if countryTile==nil then
			print("COUNTRYSIDE SETUP ERROR: tile "..tostring(params.guid).." was not available for slot "..tostring(i))
			startingMapSetup=false
			return
		end
		if furyMap and furyCountrySlots[i].faceUp==true then furyRevealGUIDs[#furyRevealGUIDs+1]=countryTile.guid end
		if not againstHorsemenMap and not furyMap then TileShuffler.putObject(countryTile) end
	end

	if furyMap then
		--Everything in Fury is already on the table. Core 1's former Tomb is the one-space Dragon Lair.
		if furyDragonSetupLair(furyLairTile)~=true then print("FURY SETUP ERROR: could not establish the Dragon Lair") end
		--Like the Volkare's Quest opening tiles, reveal from a settled face-down state in steps. This makes
		--each reveal re-enter the normal terrain population path instead of arriving already face up.
		for revealIndex,revealGUID in ipairs(furyRevealGUIDs) do
			local guid=revealGUID
			safeWaitTime("SetupGame",function()
				local tile=getObjectFromGUID(guid)
				if tile~=nil and tile.is_face_down==true then tile.flip() end
			end,revealIndex)
		end
		safeWaitTime("SetupGame",function() startingMapSetup=false fakeDropAvatar() end,#furyRevealGUIDs+2)
		return
	end

	--The predefined terrain is now complete. Keep Mage Knights physically parked on the Portal card,
	--but make Country01's central Glade their shared logical start, then place the four hidden Horsemen.
	if againstHorsemenMap then
		againstHorsemenSetStartingAvatarLocations()
		againstHorsemenSetupTokens(againstHorsemenCoreTileGUIDs,againstHorsemenCoreTilePos)
		safeWaitTime("SetupGame",function()
			--Country01's central Magical Glade replaces the normal starting terrain in this scenario.
			--Remove either state of the start tile plus only its map Portal overlay; the Portal card stays
			--in place as the shared-avatar parking area.
			local startObj=getObjectFromGUID(startTerrain.wedge) or getObjectFromGUID(startTerrain.open)
			local portalObj=getObjectFromGUID(portal.terrainHex)
			if startObj~=nil then startObj.destruct() end
			if portalObj~=nil then portalObj.destruct() end
			startingMapSetup=false
		end,4)
		return
	end

	--place Country tiles on stack shuffled
	if gStates.gameScenario~="First Reconnaissance" then TileShuffler.shuffle() end
	--When Apocalypse Dragon Quests are in use, explicitly draw the selected Village as the first Countryside tile.
	--This is done after the scenario has built its terrain set, so its selection scheme remains intact.
	local function takeStartingCountry(params)
		if questVillageGUID~=nil then params.guid=questVillageGUID questVillageGUID=nil end
		return safeTakeObject("SetupGame",TileShuffler,params)
	end
	local rot={}
	if scenarioList[gStates.scenarioRef][gStates.playersRef].mapShape:sub(5,5)=="W" then
		if gStates.randomTileOrientation==false then rot={0, 180, 180} else rot={0, math.random(1,6)*60, 180} end
		takeStartingCountry({position={-25.2302, 1.07, -9.8482}, rotation=rot, smooth=false, callback_function=function(obj) safeWaitTime("SetupGame",function() gStates.firstStarted=true firstTile=obj.guid obj.flip() end, 1) end})
		if gStates.randomTileOrientation==false then rot={0, 180, 180} else rot={0, math.random(1,6)*60, 180} end
		takeStartingCountry({position={-19.2300, 1.07, -11.9267}, rotation=rot, smooth=false, callback_function=function(obj) safeWaitTime("SetupGame",function() obj.flip() end, 2) end})
		if gStates.gameScenario=="The Chaos Rift" then
			if gStates.randomTileOrientation==false then rot={0, 180, 180} else rot={0, math.random(1,6)*60, 180} end
			takeStartingCountry({position={-20.4300, 1.09, -5.6911}, rotation=rot, smooth=false})
		end
	else
		if gStates.randomTileOrientation==false then rot={0, 180, 180} else rot={0, math.random(1,6)*60, 180} end
		if gStates.gameScenario~="The Gauntlet" and gStates.gameScenario~="Volkare's Return" and gStates.gameScenario~="Volkare's Return Blitz" then takeStartingCountry({position={-37.2305, 1.07, -5.6911}, rotation=rot, smooth=false, callback_function=function(obj) tile1=obj safeWaitTime("SetupGame",function() gStates.firstStarted=true firstTile=tile1.guid tile1.flip() end, 1) end}) end
		if gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz" then safeWaitTime("SetupGame",function() getObjectFromGUID("835c91").setPosition({-37.2305, 1.15, -5.6911}) getObjectFromGUID("835c91").flip() end, 1) end
		if gStates.randomTileOrientation==false then rot={0, 180, 180} else rot={0, math.random(1,6)*60, 180} end
		takeStartingCountry({position={-31.2303, 1.07, -7.7696}, rotation=rot, smooth=false, callback_function=function(obj) safeWaitTime("SetupGame",function() obj.flip() end, 2) end})
		if gStates.randomTileOrientation==false then rot={0, 180, 180} else rot={0, math.random(1,6)*60, 180} end
		if gStates.gameScenario~="The Gauntlet" then takeStartingCountry({position={-30.0303, 1.07, -14.0000}, rotation=rot, smooth=false, callback_function=function(obj) safeWaitTime("SetupGame",function() obj.flip() end, 3) end}) end
		if gStates.gameScenario=="Volkare's Quest" or gStates.gameScenario=="The War of Four" then safeWaitTime("SetupGame",function() getObjectFromGUID("835c91").setPosition({-12.0297, 1.15, 8.8586}) getObjectFromGUID("835c91").flip() end, 3) end
	end
	local VolQuestTilePos=		  {{-32.4304, 1.15, -1.5341}, {-27.6302, 1.15,   2.6230}, {-26.4302, 1.15, -3.6126}, {-25.2302, 1.15, -9.8482}, {-20.4300, 1.15,  -5.6911}, {-21.6300, 1.15,   0.5445}, {-24.0301, 1.15, -16.0837}, {-19.2300, 1.15, -11.9267}, {-14.4298, 0.15, -7.7696}}
	local warOfFourCountryTilePos={{-38.4306, 1.15,  0.5445}, {-27.6302, 1.15,   2.6230}, {-26.4302, 1.15, -3.6126}, {-33.6304, 1.15, 4.7015},  {-20.4300, 1.15,  -5.6911}, {-21.6300, 1.15,   0.5445}, {-24.0301, 1.15, -16.0837}, {-19.2300, 1.15, -11.9267}, {-18.0299, 1.15, 10.9371}, {-10.8297, 1.15, 2.6230}}
	local GauntletTilePos=		  {{-14.4298, 1.15, -7.7696}, {-19.2300, 1.15, -11.9267}, {-12.0297, 1.15,  8.8586}, {-16.8299, 1.15,  4.7015}, {-21.6300, 1.15,   0.5445}, {-26.4302, 1.15,  -3.6126}}
	local ConquerAndHoldTilePos=  {{-32.4304, 1.15, -1.5341}, {-25.2302, 1.15,  -9.8482}}
	for i=1, TileShuffler.getQuantity(), 1 do
		local params={smooth=false}
		if gStates.randomTileOrientation==false then params.rotation={0, 180, 180} else params.rotation={0, math.random(1,6)*60, 180} end
		if gStates.gameScenario=="Volkare's Quest" then params.position=VolQuestTilePos[i] end
		if gStates.gameScenario=="Conquer and Hold" then params.position=ConquerAndHoldTilePos[i] end
		if gStates.gameScenario=="The War of Four" then params.position=warOfFourCountryTilePos[i] end
		if gStates.gameScenario=="The Gauntlet" then params.position=GauntletTilePos[i] end
		if params.position==nil then params.position={pos.x, pos.y+tUp, pos.z} tUp=tUp+0.5 end
		safeTakeObject("SetupGame",TileShuffler,params)
	end
	--Starting country tiles reveal on 1/2/3 second timers. They are part of setup and do not
	--count toward Apocalypse is Here Horseman reveal thresholds.
	safeWaitTime("SetupGame",function() startingMapSetup=false end, 4)
end

-- Shared helpers used by more than one Global source module.
-- Keep subsystem-owned game logic in its owning module.

-- Error-report boundaries for callbacks that TTS invokes after the originating function has returned.
-- These helpers deliberately keep the native Wait signatures so existing timing/return behaviour is unchanged.
function automaticLuaTraceback(errorText)
	if debug and debug.traceback then return debug.traceback(tostring(errorText),2) end
	return tostring(errorText)
end

function automaticLuaAsyncLabel(scope, kind)
	local label=tostring(scope or "Async").." / "..tostring(kind or "callback")
	local ok,info=pcall(function() if debug and debug.getinfo then return debug.getinfo(3,"l") end end)
	if ok==true and info~=nil and info.currentline~=nil and info.currentline>0 then label=label.." @"..tostring(info.currentline) end
	return label
end

function safeAsyncCallback(label, callback, contextCallback)
	if type(callback)~="function" then return callback end
	return function(...)
		local args={n=select("#",...),...}
		return safeCallback(label,function() return callback(table.unpack(args,1,args.n)) end,contextCallback)
	end
end

function safeObjectCallbackParams(scope, params)
	if type(params)~="table" or type(params.callback_function)~="function" then return params end
	params.callback_function=safeAsyncCallback(automaticLuaAsyncLabel(scope,"callback_function"),params.callback_function)
	return params
end

function safeTakeObject(scope, container, params)
	if container==nil then return nil end
	return container.takeObject(safeObjectCallbackParams(scope,params))
end

function safeSpawnObject(scope, params)
	return spawnObject(safeObjectCallbackParams(scope,params))
end

function safeSpawnObjectData(scope, params)
	return spawnObjectData(safeObjectCallbackParams(scope,params))
end

function safeWaitFrames(scope, callback, frames)
	local label=automaticLuaAsyncLabel(scope,"Wait.frames")
	return Wait.frames(safeAsyncCallback(label,callback),frames)
end

function safeWaitTime(scope, callback, seconds, repetitions)
	local label=automaticLuaAsyncLabel(scope,"Wait.time")
	if repetitions==nil then return Wait.time(safeAsyncCallback(label,callback),seconds) end
	return Wait.time(safeAsyncCallback(label,callback),seconds,repetitions)
end

function safeWaitCondition(scope, callback, condition, timeout, timeoutCallback)
	local label=automaticLuaAsyncLabel(scope,"Wait.condition")
	local predicateFailed=false
	local safeCondition=function(...)
		if predicateFailed==true then return true end
		local args={n=select("#",...),...}
		local ok,result=xpcall(function() return condition(table.unpack(args,1,args.n)) end,automaticLuaTraceback)
		if ok~=true then
			predicateFailed=true
			reportAutomaticLuaError(label.." predicate",result)
			return true --terminate the Wait without running the success callback
		end
		return result
	end
	local safeCallbackRun=safeAsyncCallback(label,function(...) if predicateFailed~=true then return callback(...) end end)
	local safeTimeout=timeoutCallback~=nil and safeAsyncCallback(label.." timeout",timeoutCallback) or nil
	if timeout==nil then return Wait.condition(safeCallbackRun,safeCondition) end
	if safeTimeout==nil then return Wait.condition(safeCallbackRun,safeCondition,timeout) end
	return Wait.condition(safeCallbackRun,safeCondition,timeout,safeTimeout)
end

--Used to join a table of strings with translation brackets
JOIN_LANG_ORDER={"en", "ru", "zh-tw", "zh-cn", "ko", "es", "fr", "pt-br", "de"}
JOIN_LANG_TAGS={"{en}", "{ru}", "{zh-tw}", "{zh-cn}", "{ko}", "{es}", "{fr}", "{pt-br}", "{de}"}
joinLangParseCache={}
joinLangCacheCount=0
JOIN_LANG_CACHE_LIMIT=2048

function joinLangParse(text)
	local cached=joinLangParseCache[text]
	if cached~=nil then return cached end
	local firstStart, firstEnd, firstLang=text:find("{([%a%-]+)}", 1)
	if firstStart==nil then return text end
	local parsed={}
	local tagStart, tagEnd, lang=firstStart, firstEnd, firstLang
	while tagStart~=nil do
		local nextStart, nextEnd, nextLang=text:find("{([%a%-]+)}", tagEnd+1)
		parsed[lang]=text:sub(tagEnd+1, (nextStart or (#text+1))-1)
		tagStart, tagEnd, lang=nextStart, nextEnd, nextLang
	end
	if joinLangCacheCount>=JOIN_LANG_CACHE_LIMIT then joinLangParseCache={} joinLangCacheCount=0 end
	joinLangParseCache[text]=parsed
	joinLangCacheCount=joinLangCacheCount+1
	return parsed
end

--Join strings/numbers while preserving TTS translation tags. Tagged strings are parsed once and cached.
function joinLang(full_string)
	local parts={}
	for i=1, #full_string do parts[i]=joinLangParse(tostring(full_string[i])) end
	local output={}
	for langIndex, lang in ipairs(JOIN_LANG_ORDER) do
		output[#output+1]=JOIN_LANG_TAGS[langIndex]
		for i=1, #parts do
			local part=parts[i]
			if type(part)=="string" then output[#output+1]=part
			else
				local translated=part[lang] or part.en
				if translated~=nil then output[#output+1]=translated end
			end
		end
	end
	return table.concat(output)
end

-- Turn / seat helpers
--work out which color hand has the current turns mage
function positionToColor(turnNumber)
	local color="Black"
	local turnDetails=turnOrder[turnNumber]
	if turnDetails==nil then return color end
	if turnDetails.mage~=gStates.positionMageKnight[5] then
		for _, handColor in pairs(Player.getAvailableColors()) do
			local handPlayer=Player[handColor]
			local handTransform=handPlayer~=nil and handPlayer.getHandTransform() or nil
			if handTransform~=nil and handTransform.position~=nil and turnDetails.seatPos==math.ceil((handTransform.position[1]+97.59)/40) then color=handColor break end
		end
	end
	return color
end

-- Rewind transaction helpers
--Short scripted transactions can span several delayed/physics callbacks. Store one known-good rewind point
--before the first mutation, then suppress TTS automatic rewind snapshots until every nested transaction is stable.
--Owners make the guard nestable: a Quest refill can safely run inside End of Round, and several queued card claims
--for one seat can share the same rewind transaction without releasing the outer transaction early.
rewindTransactionStorePending=false
rewindTransactionBlocked=false
rewindTransactionGeneration=0
rewindTransactionOwners={}
rewindTransactionPending={}
rewindTransactionPendingOwners={}

function rewindTransactionOwnerActive(owner)
	owner=owner or "Automated turn"
	return rewindTransactionOwners[owner]==true or rewindTransactionPendingOwners[owner]==true
end

function rewindTransactionStart(andThen,owner,onFailure)
	owner=owner or "Automated turn"
	if type(andThen)~="function" then return false end
	if rewindTransactionBlocked==true then
		rewindTransactionOwners[owner]=true
		andThen()
		return true
	end
	if type(storeRewindState)~="function" then
		rewindTransactionOwners[owner]=true
		andThen()
		return true
	end
	rewindTransactionPending[#rewindTransactionPending+1]={owner=owner,run=andThen,fail=onFailure}
	rewindTransactionPendingOwners[owner]=true
	if rewindTransactionStorePending==true then return true end
	rewindTransactionStorePending=true
	storeRewindState(function(success,didSave)
		local pending=rewindTransactionPending
		rewindTransactionPending={}
		rewindTransactionPendingOwners={}
		rewindTransactionStorePending=false
		if success~=true then
			for _,entry in ipairs(pending) do if type(entry.fail)=="function" then entry.fail() end end
			broadcastToAll("Could not store a safe rewind point. The scripted action was not started.",{1,0.25,0.25})
			return
		end
		rewindTransactionBlocked=true
		rewindTransactionGeneration=(rewindTransactionGeneration or 0)+1
		local rewindGeneration=rewindTransactionGeneration
		for _,entry in ipairs(pending) do rewindTransactionOwners[entry.owner]=true end
		--TTS automatically lifts block_further_stores after 60 seconds. Mirror that expiry so the Lua
		--owner table cannot remain stuck if a protected sequence hands control to a long human decision.
		safeWaitTime("Shared",function()
			if rewindTransactionBlocked==true and rewindTransactionGeneration==rewindGeneration then rewindTransactionForceRelease() end
		end,59)
		for _,entry in ipairs(pending) do entry.run() end
	end,true)
	return true
end

function rewindTransactionFinish(owner)
	owner=owner or "Automated turn"
	rewindTransactionOwners[owner]=nil
	if next(rewindTransactionOwners)~=nil then return end
	if rewindTransactionBlocked==true and type(allowRewindStore)=="function" then allowRewindStore() end
	rewindTransactionBlocked=false
	rewindTransactionGeneration=(rewindTransactionGeneration or 0)+1
end

function rewindTransactionForceRelease()
	rewindTransactionOwners={}
	rewindTransactionPending={}
	rewindTransactionPendingOwners={}
	rewindTransactionStorePending=false
	if rewindTransactionBlocked==true and type(allowRewindStore)=="function" then allowRewindStore() end
	rewindTransactionBlocked=false
	rewindTransactionGeneration=(rewindTransactionGeneration or 0)+1
end

-- Map geometry helpers
--used to workout the offset for each hex on a terrain tile
function angleToXY(obj, ang, cachedPos, cachedRotation)
	local pos=cachedPos or obj.getPosition()
	if ang=="center" then return {pos[1], pos[3]} end
	local rotation=cachedRotation or obj.getRotation()
	local hexRotationRad=math.rad(360-rotation[2]+tonumber(ang))
	return {pos[1]+(math.cos(hexRotationRad)*2.39), pos[3]+(math.sin(hexRotationRad)*2.39)}
end

--Find a world position's bearing on one terrain tile. This is also used when a wall needs both bearings relative to the same tile.
function terrainHexBearing(terrain, pos, cachedTerrainPos, cachedTerrainRotation)
	if terrain==nil or pos==nil or terrainTiles[terrain.guid]==nil then return end
	local tilePos=cachedTerrainPos or terrain.getPosition()
	local dist=math.sqrt(((pos[1]-tilePos[1])^2)+((pos[3]-tilePos[3])^2))
	if dist>=3.1 then return end
	local bearing="center"
	if dist>1 then
		local rotation=cachedTerrainRotation or terrain.getRotation()
		local temp=60*math.floor((math.deg(math.atan2(pos[3]-tilePos[3], pos[1]-tilePos[1]))+rotation[2]+30)/60)
		if temp>=360 then temp=temp-360 end
		if temp<0 then temp=temp+360 end
		bearing=tostring(temp)
	end
	return bearing
end

--Find the terrain tile, bearing, exact centre, feature and terrain type under a world position.
--Cached map object, position and rotation tables can be supplied by callers already scanning the map.
function terrainHexAtPosition(pos, objectsInPlay, cachedPositions, cachedRotations)
	if pos==nil then return end
	if objectsInPlay==nil then
		local map=getObjectFromGUID(mapArea)
		if map==nil then return end
		objectsInPlay=map.getObjects()
	end
	for _, terrain in pairs(objectsInPlay) do
		local terrainPos=cachedPositions~=nil and cachedPositions[terrain.guid] or nil
		local terrainRotation=cachedRotations~=nil and cachedRotations[terrain.guid] or nil
		local bearing=terrainHexBearing(terrain, pos, terrainPos, terrainRotation)
		if bearing~=nil then
			local hexPos=angleToXY(terrain, bearing, terrainPos, terrainRotation)
			local details=terrainTiles[terrain.guid]
			local feature=details.hexFeature~=nil and details.hexFeature[bearing] or nil
			local hexType=details.hexType~=nil and details.hexType[bearing] or nil
			return terrain, bearing, {hexPos[1], pos[2], hexPos[2]}, feature, hexType
		end
	end
end

-- Player permission helpers
--checks the clicking player matches the current turn
function legalPlayerCheck(clickingPlayersColor, playerPosExpected, rule)
	--converts player color in to a posiion value
	local playerPosition=0
	if clickingPlayersColor~="Grey" and clickingPlayersColor~="Black" and Player[clickingPlayersColor].seated==true and Player[clickingPlayersColor].getHandTransform()~=nil then playerPosition=math.ceil((Player[clickingPlayersColor].getHandTransform().position[1]+97.59)/40) end
	if playerPosition==playerPosExpected or clickingPlayersColor=="Black" or (rule==nil and turnOrder[gStates.turnNumber].mage==gStates.positionMageKnight[5]) then
		return true
	else
		for a=1, #turnOrder, 1 do
			if turnOrder[a].seatPos==playerPosExpected then
				broadcastToAll(joinLang({"{en}Only player sitting at {ru}Только игрок, сидящий на месте {zh-cn}只有{ko}오직 플레이어 {es}Solo el jugador sentado en {fr}Seul le joueur assis à {pt-br}Único jogador sentando em {de}Nur Spieler, die auf ", translateWord[turnOrder[a].mage], "{en} or Game Master(Black) may press this.\n(Change seats by left clicking your Name found in the upper right corner){ru} или на месте Game Master (Черный) может нажать сюда.\n(Чтобы сменить место, щелкните ЛКМ по своему имени, указанному в правом верхнем углу){zh-cn}和黑色玩家可以操作(你可以单击右上角你的名字更改颜色){ko}본인이나 게임 마스터(검정)만이 클릭할 수 있습니다.\n(자리를 바꾸려면 우상단의 버튼에서 닉네임을 클릭하세요){es} o Game Master (Negro) puede presionar esto.\n(Cambie de asiento haciendo clic izquierdo en su nombre que se encuentra en la esquina superior derecha){fr} ou au Game Master (Black) peut appuyer dessus.\n(Changez de siège en cliquant avec le bouton gauche sur votre nom trouvé dans le coin supérieur droit){pt-br} Jogador Mestre (Preto) pode pressionar isto.\nMude assentos apertando no seu nome no canto superior direito{de} oder Game Master(Black) kann dies drücken.\n(Wechseln Sie den Sitzplatz, indem Sie mit der linken Maustaste auf Ihren Namen in der oberen rechten Ecke klicken)"}), warningColor)
				break
			end
		end
		return false
	end
end

-- Stable card identity helpers
--Card identity helpers. Object Nicknames are display/search text and may be translated,
--so script logic must use stable GUID-backed card data instead.
function gameCardType(obj)
	if obj==nil or gameCards[obj.guid]==nil then return nil end
	return gameCards[obj.guid].cardType
end
function isTacticCard(obj)
	if obj==nil then return false end
	for i=1, #tacticCard do if obj.guid==tacticCard[i] then return true end end
	return false
end

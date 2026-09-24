-- Shared helpers used by more than one Global source module.
-- Keep subsystem-owned game logic in its owning module.

-- Core runtime state. Current saved data replaces these tables during onLoad.
turnOrder={}
gStates={}
warningColor={1,0.8,0.2}

---@overload fun(scope: "SetupGame", container: any, params: table): any
function safeTakeObject(scope, container, params)
	local ref=type(params)=="table" and (params.guid or params.index) or "unknown"
	if container==nil then
		if scope=="SetupGame" then error("SetupGame missing required container while taking "..tostring(ref),2) end
		return nil
	end
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
	--Wait.condition predicates can run every frame while objects are moving. Keep that hot poll native;
	--only the one-shot success/timeout callbacks need the automatic error boundary.
	local safeCallbackRun=safeAsyncCallback(label,callback)
	local safeTimeout=timeoutCallback~=nil and safeAsyncCallback(label.." timeout",timeoutCallback) or nil
	if timeout==nil then return Wait.condition(safeCallbackRun,condition) end
	if safeTimeout==nil then return Wait.condition(safeCallbackRun,condition,timeout) end
	return Wait.condition(safeCallbackRun,condition,timeout,safeTimeout)
end

local UI_BUTTON_ACTIVE_IMAGE="Sliced Button/Button New Active"
local UI_BUTTON_DEACTIVE_IMAGE="Sliced Button/Button New Deactive"

--Keep a button's input state and standard Active/Deactive presentation in sync.
function setUIButtonEnabled(id,enabled,imageId)
	UI.setAttribute(id,"interactable",enabled and "true" or "false")
	UI.setAttribute(imageId or id.."Image","image",enabled and UI_BUTTON_ACTIVE_IMAGE or UI_BUTTON_DEACTIVE_IMAGE)
end

--Used to join a table of strings with translation brackets
local JOIN_LANG_ORDER={"en", "ru", "zh-tw", "zh-cn", "ko", "es", "fr", "pt-br", "de"}
local JOIN_LANG_TAGS={"{en}", "{ru}", "{zh-tw}", "{zh-cn}", "{ko}", "{es}", "{fr}", "{pt-br}", "{de}"}
local joinLangParseCache={}
local joinLangCacheCount=0
local JOIN_LANG_CACHE_LIMIT=2048

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

--Reapply translated static UI text once at load so TTS resolves language tags.
--Use TTS's parsed XML table instead of pattern-matching the whole raw XML string.
--Only Text/Toggle contents need this workaround. TTS does not resolve translation tags in tooltip
--attributes, so tooltips stay plain English and are intentionally not reapplied here.
function reapplyXmlText()
	local xml=UI.getXmlTable() or {}
	local reapplied=0
	local function visit(node)
		if type(node)~="table" then return end
		local attributes=node.attributes or {}
		local id=attributes.id
		if id~=nil then
			if node.tag=="Text" or node.tag=="Toggle" then
				local value=attributes.text
				if value==nil then value=node.value end
				if type(value)=="string" and value:find("{en}",1,true)~=nil then
					UI.setAttribute(id,"text",value)
					reapplied=reapplied+1
				end
			end
		end
		for _,child in ipairs(node.children or {}) do visit(child) end
	end
	for _,node in ipairs(xml) do visit(node) end
	return reapplied
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

--Rewards Claimed soft locks are player reminders, not hard disables. They share one short window
--from the moment the Rewards Claimed stage begins, then allow the player to continue manually.
REWARD_CLAIM_SOFT_LOCK_SECONDS=30

function rewardClaimSoftLockStart()
	if gStates==nil then return end
	gStates.rewardClaimSoftLockStartedAt=os.time()
	gStates.rewardClaimSoftLockGeneration=(gStates.rewardClaimSoftLockGeneration or 0)+1
	local generation=gStates.rewardClaimSoftLockGeneration
	--Refresh once when the soft lock starts so any outstanding requirement can tint Rewards Claimed,
	--and once at expiry so the tint clears even if the player is still reading the reward checklist.
	if mainUIUpdate~=nil then safeWaitFrames("Shared",function() mainUIUpdate("Rewards Claimed soft lock started") end,1) end
	safeWaitTime("Shared",function()
		if gStates~=nil and gStates.rewardClaimSoftLockGeneration==generation and gStates.preEndTurn==true and mainUIUpdate~=nil then
			mainUIUpdate("Rewards Claimed soft lock expired")
		end
	end,REWARD_CLAIM_SOFT_LOCK_SECONDS)
end

function rewardClaimSoftLockActive()
	if gStates==nil or gStates.preEndTurn~=true then return false end
	local started=tonumber(gStates.rewardClaimSoftLockStartedAt)
	return started~=nil and os.time()<started+REWARD_CLAIM_SOFT_LOCK_SECONDS
end

function rewardClaimSoftLockClear()
	if gStates~=nil then gStates.rewardClaimSoftLockStartedAt=nil end
end

-- Rewind transaction helpers
--Short scripted transactions can span several delayed/physics callbacks. Store one known-good rewind point
--before the first mutation, then suppress TTS automatic rewind snapshots until every nested transaction is stable.
--Owners make the guard nestable: a Quest refill can safely run inside End of Round, and several queued card claims
--for one seat can share the same rewind transaction without releasing the outer transaction early.
--TTS storeRewindState captures a full engine rewind snapshot before protected scripted actions.
--Keep the transaction ownership/sequencing and store the safe rewind point before mutations begin.
local rewindTransactionStoreEnabled=true
local rewindTransactionStorePending=false
local rewindTransactionBlocked=false
local rewindTransactionGeneration=0
local rewindTransactionOwners={}
local rewindTransactionPending={}
local rewindTransactionPendingOwners={}

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
	if rewindTransactionStoreEnabled~=true or type(storeRewindState)~="function" then
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
			broadcastToAll("{en}Could not store a safe rewind point. The scripted action was not started.{ru}Не удалось сохранить безопасную точку перемотки. Скриптовое действие не было запущено.{zh-tw}無法儲存安全的回溯點。腳本動作未開始。{zh-cn}无法储存安全的回溯点。脚本动作未开始。{ko}안전한 되돌리기 지점을 저장하지 못했습니다. 스크립트 동작이 시작되지 않았습니다.{es}No se pudo guardar un punto de rebobinado seguro. La acción del script no se inició.{fr}Impossible d’enregistrer un point de retour sûr. L’action scriptée n’a pas été lancée.{pt-br}Não foi possível salvar um ponto de retorno seguro. A ação do script não foi iniciada.{de}Es konnte kein sicherer Rückspulpunkt gespeichert werden. Die Skriptaktion wurde nicht gestartet.",{1,0.25,0.25})
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

--Return one loose card to the bottom of a live deck using the same physical drop used by
--Artifact cleanup: lift the deck, move the card into its old resting position, and let the deck fall
--back onto it. A one-card source has no Deck to lift, so use putObject for that edge case.
function putCardAtBottom(container,card,onComplete)
	if container==nil or card==nil or container.guid==card.guid or (container.type~="Deck" and container.type~="Card") then return nil end
	local pos=container.getPosition()
	card.unlock()
	card.setRotation(container.getRotation())
	if container.type=="Card" then
		card.setPosition({pos[1]+3.0,math.max(0.2,pos[2]-0.6),pos[3]})
		local merged=container.putObject(card)
		if onComplete~=nil then safeWaitFrames("Shared",function() onComplete(merged) end,1) end
		return merged
	end

	local deckGUID=container.guid
	local expectedQuantity=container.getQuantity()+1
	container.setPositionSmooth({pos[1],pos[2]+2.0,pos[3]},false,false)
	card.setPositionSmooth({pos[1],pos[2],pos[3]},false,false)
	if onComplete~=nil then
		local function finish()
			onComplete(getObjectFromGUID(deckGUID))
		end
		safeWaitCondition("Shared",finish,function()
			local live=getObjectFromGUID(deckGUID)
			return live==nil or (live.type=="Deck" and live.getQuantity()>=expectedQuantity and live.isSmoothMoving()==false and live.resting==true)
		end,5,finish)
	end
	return container
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
		local snapshot=runtimeMapSnapshot()
		objectsInPlay=snapshot.terrainObjects or {}
		cachedPositions=snapshot.terrainPositions
		cachedRotations=snapshot.terrainRotations
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


-- Shared runtime map snapshots. The physical TTS table is authoritative; these are only derived
-- in-memory indexes and must never be persisted in gStates. Ordinary map membership changes invalidate
-- only the cheap object list. Terrain membership/transform/face changes also invalidate the expensive
-- terrain hex topology.
runtimeMapObjectCache=nil
runtimeMapTerrainCache=nil
runtimeMapSnapshotCache=nil

function runtimeMapInvalidateObjects()
	runtimeMapObjectCache=nil
	runtimeMapSnapshotCache=nil
end

function runtimeMapInvalidateTerrain()
	runtimeMapObjectCache=nil
	runtimeMapTerrainCache=nil
	runtimeMapSnapshotCache=nil
end

--Compatibility for any external/custom call sites: the old broad invalidation remains safe.
function runtimeMapInvalidate()
	runtimeMapInvalidateTerrain()
end

function runtimeMapContainsGUID(guid)
	return guid~=nil and runtimeMapObjectCache~=nil and runtimeMapObjectCache.objectGUIDs~=nil and runtimeMapObjectCache.objectGUIDs[guid]==true
end

local RUNTIME_MAP_HEX_X_STEP=2.4
local RUNTIME_MAP_HEX_Z_STEP=2.0785

function runtimeMapHexKey(hexOrTerrainGUID,bearing)
	if hexOrTerrainGUID==nil then return nil end
	if type(hexOrTerrainGUID)=="table" then
		return tostring(hexOrTerrainGUID.terrainGUID).."|"..tostring(hexOrTerrainGUID.bearing)
	end
	return tostring(hexOrTerrainGUID).."|"..tostring(bearing)
end

function runtimeMapHexesAdjacent(a,b)
	if a==nil or b==nil or a.position==nil or b.position==nil then return false end
	local dx=a.position[1]-b.position[1]
	local dz=a.position[3]-b.position[3]
	local distanceSquared=(dx*dx)+(dz*dz)
	return distanceSquared>4.2 and distanceSquared<7.4
end

function runtimeMapWorldToAxial(position,origin)
	if position==nil or origin==nil then return nil,nil end
	local r=math.floor(((position[3]-origin[3])/RUNTIME_MAP_HEX_Z_STEP)+0.5)
	local q=math.floor(((position[1]-origin[1])/RUNTIME_MAP_HEX_X_STEP)+(r/2)+0.5)
	return q,r
end

function runtimeMapAxialToWorld(q,r,origin,y)
	if q==nil or r==nil or origin==nil then return nil end
	return {
		origin[1]+(RUNTIME_MAP_HEX_X_STEP*(q-(r/2))),
		y or origin[2],
		origin[3]+(RUNTIME_MAP_HEX_Z_STEP*r)
	}
end

function runtimeMapAxialDistance(q,r)
	if q==nil or r==nil then return nil end
	return math.max(math.abs(q),math.abs(r),math.abs(q-r))
end

function runtimeMapWorldHexDistance(fromPos,toPos)
	if fromPos==nil or toPos==nil then return nil end
	local function nearest(value)
		if value>=0 then return math.floor(value+0.5) end
		return math.ceil(value-0.5)
	end
	local r=nearest((toPos[3]-fromPos[3])/RUNTIME_MAP_HEX_Z_STEP)
	local q=nearest(((toPos[1]-fromPos[1])/RUNTIME_MAP_HEX_X_STEP)+(r/2))
	return runtimeMapAxialDistance(q,r)
end

function terrainHexChoiceUIPlacement(key,buttonScale,splitIndex,splitCount,referenceScale)
	if key==nil then return nil,nil end
	local terrainGUID,bearing=tostring(key):match("^([^|]+)|(.+)$")
	local terrain=terrainGUID~=nil and getObjectFromGUID(terrainGUID) or nil
	if terrain==nil or bearing==nil then return nil,nil end
	local hexXY=angleToXY(terrain,bearing)
	local tilePos=terrain.getPosition()
	local localHex=terrain.positionToLocal({hexXY[1],tilePos[2],hexXY[2]})
	local tileScale=terrain.getScale()
	local scaleX=tileScale.x or tileScale[1] or 2.25
	local scaleZ=tileScale.z or tileScale[3] or 2.25
	buttonScale=tonumber(buttonScale) or 0.38
	referenceScale=tonumber(referenceScale) or buttonScale
	local uiFactor=referenceScale~=0 and buttonScale/referenceScale or 1
	local uiX=(localHex.x or localHex[1])*scaleX*110*uiFactor
	local uiY=(localHex.z or localHex[3])*scaleZ*110*uiFactor
	local count=math.max(1,tonumber(splitCount) or 1)
	local slot=math.max(1,tonumber(splitIndex) or 1)
	local height=320/count
	if count>1 then uiY=uiY+(((count+1)/2)-slot)*height*buttonScale end
	return terrain,{
		x=uiX,y=uiY,depth=-40*uiFactor,
		rotation=terrain.getRotation()[2] or 180,
		height=height,count=count,scale=buttonScale
	}
end

local function runtimeMapObjectSnapshot()
	if runtimeMapObjectCache~=nil then return runtimeMapObjectCache end
	local map=getObjectFromGUID(mapArea)
	if map==nil then
		runtimeMapObjectCache={objects={},objectGUIDs={}}
		return runtimeMapObjectCache
	end
	local objects=map.getObjects()
	local objectGUIDs={}
	for _,obj in pairs(objects) do objectGUIDs[obj.guid]=true end
	runtimeMapObjectCache={objects=objects,objectGUIDs=objectGUIDs}
	return runtimeMapObjectCache
end

local function runtimeMapTerrainSnapshot()
	if runtimeMapTerrainCache~=nil then return runtimeMapTerrainCache end
	local objectSnapshot=runtimeMapObjectSnapshot()
	local terrainObjects={}
	local terrainPositions={}
	local terrainRotations={}
	local terrainEntries={}
	local hexes={}
	local signatureParts={}
	local bearings={"center","0","60","120","180","240","300"}

	for _,obj in pairs(objectSnapshot.objects or {}) do
		local details=terrainTiles[obj.guid]
		if details~=nil then
			local position=obj.getPosition()
			local rotation=obj.getRotation()
			terrainObjects[#terrainObjects+1]=obj
			terrainPositions[obj.guid]=position
			terrainRotations[obj.guid]=rotation
			if obj.is_face_down~=true then
				local rotationAdjust=math.floor(((rotation[2]-180)/60)+0.5)*60
				if rotationAdjust<0 then rotationAdjust=rotationAdjust+360 end
				local printed={}
				for _,bearing in ipairs(bearings) do
					local hexType=details.hexType~=nil and details.hexType[bearing] or ""
					local feature=details.hexFeature~=nil and details.hexFeature[bearing] or ""
					printed[#printed+1]=tostring(hexType)..":"..tostring(feature)
				end
				signatureParts[#signatureParts+1]=obj.guid.."@"..string.format("%.3f,%.3f,%d",position[1],position[3],rotationAdjust).."@"..table.concat(printed,",")
				terrainEntries[#terrainEntries+1]={guid=obj.guid,object=obj,details=details,position=position,rotation=rotation,rotationAdjust=rotationAdjust}

				if details.tileType~="tilePile" and details.hexType~=nil and details.hexFeature~=nil then
					for _,bearing in ipairs(bearings) do
						local hexType=details.hexType[bearing]
						if hexType~=nil and hexType~="" and hexType~="ocean" then
							local xy=angleToXY(obj,bearing,position,rotation)
							hexes[#hexes+1]={
								terrain=obj,terrainGUID=obj.guid,bearing=bearing,
								position={xy[1],1.30,xy[2]},hexType=hexType,
								feature=details.hexFeature[bearing] or ""
							}
						end
					end
				end
			end
		end
	end
	local hexByKey={}
	local neighbors={}
	local neighborSet={}
	for _,hex in ipairs(hexes) do
		local key=runtimeMapHexKey(hex)
		if key~=nil then
			hexByKey[key]=hex
			neighbors[key]={}
			neighborSet[key]={}
		end
	end
	for a=1,#hexes do
		local first=hexes[a]
		local firstKey=runtimeMapHexKey(first)
		if firstKey~=nil then
			for b=a+1,#hexes do
				local second=hexes[b]
				if runtimeMapHexesAdjacent(first,second)==true then
					local secondKey=runtimeMapHexKey(second)
					if secondKey~=nil then
						neighbors[firstKey][#neighbors[firstKey]+1]=second
						neighbors[secondKey][#neighbors[secondKey]+1]=first
						neighborSet[firstKey][secondKey]=true
						neighborSet[secondKey][firstKey]=true
					end
				end
			end
		end
	end

	table.sort(signatureParts)
	runtimeMapTerrainCache={
		terrainObjects=terrainObjects,terrainPositions=terrainPositions,terrainRotations=terrainRotations,
		terrainEntries=terrainEntries,hexes=hexes,hexByKey=hexByKey,neighbors=neighbors,neighborSet=neighborSet,
		terrainSignature=table.concat(signatureParts,"|")
	}
	return runtimeMapTerrainCache
end

function runtimeMapSnapshot()
	if runtimeMapSnapshotCache~=nil then return runtimeMapSnapshotCache end
	local objectSnapshot=runtimeMapObjectSnapshot()
	local terrainSnapshot=runtimeMapTerrainSnapshot()
	runtimeMapSnapshotCache={
		objects=objectSnapshot.objects,objectGUIDs=objectSnapshot.objectGUIDs,
		terrainObjects=terrainSnapshot.terrainObjects,terrainPositions=terrainSnapshot.terrainPositions,
		terrainRotations=terrainSnapshot.terrainRotations,terrainEntries=terrainSnapshot.terrainEntries,
		hexes=terrainSnapshot.hexes,hexByKey=terrainSnapshot.hexByKey,neighbors=terrainSnapshot.neighbors,
		neighborSet=terrainSnapshot.neighborSet,terrainSignature=terrainSnapshot.terrainSignature
	}
	return runtimeMapSnapshotCache
end

function runtimeMapHexDistanceMap(hexes,starts)
	local distances={}
	local queue={}
	local snapshot=runtimeMapSnapshot()
	local useCachedTopology=hexes==snapshot.hexes
	for _,startHex in ipairs(starts or {}) do
		local key=runtimeMapHexKey(startHex)
		if key~=nil and distances[key]==nil then
			distances[key]=0
			queue[#queue+1]=startHex
		end
	end
	local head=1
	while queue[head]~=nil do
		local current=queue[head]
		head=head+1
		local currentKey=runtimeMapHexKey(current)
		local currentDistance=distances[currentKey] or 0
		if useCachedTopology==true then
			for _,candidate in ipairs(snapshot.neighbors[currentKey] or {}) do
				local key=runtimeMapHexKey(candidate)
				if key~=nil and distances[key]==nil then
					distances[key]=currentDistance+1
					queue[#queue+1]=candidate
				end
			end
		else
			for _,candidate in ipairs(hexes or {}) do
				local key=runtimeMapHexKey(candidate)
				if key~=nil and distances[key]==nil and runtimeMapHexesAdjacent(current,candidate)==true then
					distances[key]=currentDistance+1
					queue[#queue+1]=candidate
				end
			end
		end
	end
	return distances
end

function runtimeMapHexesAndObjects()
	local snapshot=runtimeMapSnapshot()
	return snapshot.hexes or {},snapshot.objects or {}
end

--Build a live spatial view on top of the shared runtime map. Object membership comes from the
--invalidated runtime map cache, while positions are intentionally sampled fresh so ordinary movement
--inside the map zone is immediately authoritative without persisting another map copy in gStates.
runtimeMapSpatialCell=3
function runtimeMapSpatialSnapshot(cellSize)
	cellSize=cellSize or runtimeMapSpatialCell
	local snapshot=runtimeMapSnapshot()
	local positions={}
	local terrainObjects={}
	local terrainRotations={}
	local buckets={}
	for _, obj in pairs(snapshot.objects or {}) do
		local pos=obj.getPosition()
		positions[obj.guid]=pos
		if terrainTiles[obj.guid]~=nil then
			terrainObjects[#terrainObjects+1]=obj
			terrainRotations[obj.guid]=obj.getRotation()
		end
		local key=tostring(math.floor(pos[1]/cellSize))..":"..tostring(math.floor(pos[3]/cellSize))
		if buckets[key]==nil then buckets[key]={} end
		buckets[key][#buckets[key]+1]=obj
	end
	return {
		objects=snapshot.objects or {},positions=positions,buckets=buckets,cellSize=cellSize,
		terrainObjects=terrainObjects,terrainRotations=terrainRotations,
		terrainPositions=positions,topology=snapshot
	}
end

--Return objects from the spatial buckets around a world position. Callers still apply their exact
--distance/rules test; this only avoids rescanning unrelated map objects.
function runtimeMapSpatialNearbyObjects(spatial,pos,radius,includeObject)
	local result={}
	local seen={}
	if spatial==nil or pos==nil then return result end
	if includeObject~=nil then result[#result+1]=includeObject seen[includeObject.guid]=true end
	local cellSize=spatial.cellSize or runtimeMapSpatialCell
	local cellRadius=math.max(1,math.ceil((radius or cellSize)/cellSize))
	local baseX=math.floor(pos[1]/cellSize)
	local baseZ=math.floor(pos[3]/cellSize)
	for x=baseX-cellRadius,baseX+cellRadius do
		for z=baseZ-cellRadius,baseZ+cellRadius do
			local bucket=spatial.buckets[tostring(x)..":"..tostring(z)]
			if bucket~=nil then
				for _, obj in ipairs(bucket) do
					if seen[obj.guid]~=true then result[#result+1]=obj seen[obj.guid]=true end
				end
			end
		end
	end
	return result
end

--Resolve a world position against the same revealed-hex topology used by Movement, Proxy and Quests.
function runtimeMapHexAtPosition(pos,snapshot)
	snapshot=snapshot or runtimeMapSnapshot()
	local terrain,bearing,hexPos,feature,hexType=terrainHexAtPosition(pos,snapshot.terrainObjects,snapshot.terrainPositions,snapshot.terrainRotations)
	if terrain==nil or bearing==nil then return nil,nil,terrain,bearing,hexPos,feature,hexType end
	local key=runtimeMapHexKey(terrain.guid,bearing)
	return snapshot.hexByKey[key],key,terrain,bearing,hexPos,feature,hexType
end

--Resolve a position against a supplied revealed-hex list. Quests can pass their synchronous refresh
--cache; ordinary callers can omit both collections and use the shared runtime snapshot directly.
function runtimeMapHexForPosition(hexes,position,mapObjects)
	if position==nil then return nil end
	local snapshot=runtimeMapSnapshot()
	if hexes==nil or (hexes==snapshot.hexes and (mapObjects==nil or mapObjects==snapshot.objects)) then
		return runtimeMapHexAtPosition(position,snapshot)
	end
	local terrain,bearing=terrainHexAtPosition(position,mapObjects)
	if terrain==nil or bearing==nil then return nil end
	local key=runtimeMapHexKey(terrain.guid,bearing)
	for _,hex in ipairs(hexes or {}) do
		if runtimeMapHexKey(hex)==key then return hex end
	end
	return nil
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
				broadcastToAll(joinLang({"{en}Only player sitting at {ru}Только игрок, сидящий на месте {zh-tw}只有{zh-cn}只有{ko}오직 플레이어 {es}Solo el jugador sentado en {fr}Seul le joueur assis à {pt-br}Único jogador sentando em {de}Nur Spieler, die auf ", translateWord[turnOrder[a].mage], "{en} or Game Master(Black) may press this.\n(Change seats by left clicking your Name found in the upper right corner){ru} или на месте Game Master (Черный) может нажать сюда.\n(Чтобы сменить место, щелкните ЛКМ по своему имени, указанному в правом верхнем углу){zh-tw}和黑色玩家可以操作(你可以单击右上角你的名字更改颜色){zh-cn}和黑色玩家可以操作(你可以单击右上角你的名字更改颜色){ko}본인이나 게임 마스터(검정)만이 클릭할 수 있습니다.\n(자리를 바꾸려면 우상단의 버튼에서 닉네임을 클릭하세요){es} o Game Master (Negro) puede presionar esto.\n(Cambie de asiento haciendo clic izquierdo en su nombre que se encuentra en la esquina superior derecha){fr} ou au Game Master (Black) peut appuyer dessus.\n(Changez de siège en cliquant avec le bouton gauche sur votre nom trouvé dans le coin supérieur droit){pt-br} Jogador Mestre (Preto) pode pressionar isto.\nMude assentos apertando no seu nome no canto superior direito{de} oder Game Master(Black) kann dies drücken.\n(Wechseln Sie den Sitzplatz, indem Sie mit der linken Maustaste auf Ihren Namen in der oberen rechten Ecke klicken)"}), warningColor)
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

-- Shared table copy helper
function tableCopy(obj, seen)
	local seen=seen or {}
	if type(obj)~='table' then return obj end
	if seen[obj] then return seen[obj] end
	local res=setmetatable({}, getmetatable(obj))
	seen[obj]=res
	for key, value in pairs(obj) do res[tableCopy(key, seen)]=tableCopy(value, seen) end
	return res
end

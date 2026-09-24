-- Shared physical map-token arrival, stacking and shared-hex layout.
-- Runtime-only ordering stays rebuildable from the physical table and is never persisted in gStates.

--Small map tokens can legitimately share one hex. Keep enemy-like tokens slightly separated so
--each remains visible/clickable, while physical site markers stay underneath them.
--Enemy model origins depend on face orientation: face-up rests at Y 1.08, face-down at Y 1.18.
--Each physical token layer below adds 0.10. A Graveyard itself rests centred at Y 1.08 and raises
--an enemy resting on it by 0.08 (face-up Y 1.16, face-down Y 1.26). Destroyed Site has the same
--top surface as a face-up enemy but its model origin is 0.05 higher, so its map-floor origin is Y 1.13.
local mapTokenArrangeGeneration={}
--One pending generation per arriving token deduplicates map-zone callbacks and scripted moves.
local mapTokenArrivalPending={}
--Arrival order only needs to exist while this Lua session is running. After a load, the already-laid-out
--physical diagonal is the source of truth until a token genuinely arrives again.
local mapTokenArrivalCounter=0
local mapTokenRuntimeArrivalOrder={}

function mapTokenHasPendingArrival(guid)
	return guid~=nil and mapTokenArrivalPending[guid]~=nil
end
local mapTokenSpreadSpacing=0.20
local mapTokenSpreadDiagonalComponent=mapTokenSpreadSpacing/math.sqrt(2)
local mapTokenEnemyFaceUpBaseY=1.08
local mapTokenEnemyFaceDownBaseY=1.18
local mapTokenGraveyardBaseY=1.08
local mapTokenGraveyardSupportY=0.08
local mapTokenDestroyedBaseY=1.13
local mapTokenQuestBaseY=1.11
local mapTokenQuestSupportY=0.10
local mapTokenShieldBaseY=1.14

function mapTokenDestroyedSiteBaseY()
	return mapTokenDestroyedBaseY
end
local mapTokenStackStepY=0.10

--The model pivot moves by one token thickness when an enemy is flipped. Stack height therefore
--starts from the orientation-specific resting origin, then adds one physical layer per earlier slot.
local function mapTokenEnemySlotY(obj,index,supportY)
	index=math.max(1,tonumber(index) or 1)
	local baseY=(obj~=nil and obj.is_face_down==true) and mapTokenEnemyFaceDownBaseY or mapTokenEnemyFaceUpBaseY
	return baseY+(tonumber(supportY) or 0)+((index-1)*mapTokenStackStepY)
end

--Normalize an enemy's origin height before using it as the fallback physical stack order. Without
--this, a face-down token looks one whole layer higher even when it is resting directly on the map.
local function mapTokenEnemyPhysicalLayerY(obj)
	if obj==nil then return 0 end
	local y=obj.getPosition()[2]
	if obj.is_face_down==true then y=y-mapTokenStackStepY end
	return y
end

--Return an evenly spaced WORLD-space point on one diagonal through the hex centre.
--The group is always centred: 3 tokens are -1/0/+1 steps, 4 are -1.5/-0.5/+0.5/+1.5.
--The tested table orientation is -X/-Z for the lower/older (visual bottom-left) end and
--+X/+Z for the higher/newest (visual upper-right) end.
local function mapTokenSpreadOffset(index,count)
	count=math.max(1,tonumber(count) or 1)
	index=math.max(1,math.min(count,tonumber(index) or 1))
	local steps=((count+1)/2)-index
	local component=-steps*mapTokenSpreadDiagonalComponent
	return {x=component,z=component}
end

function mapTokenIsDestroyedSite(obj)
	return obj~=nil and obj.getGMNotes~=nil and obj.getGMNotes()=="Destroyed"
end

function mapTokenIsGraveyard(obj)
	return obj~=nil and obj.getName~=nil and obj.getName()=="GraveYard"
end

function mapTokenIsQuestMarker(obj)
	return obj~=nil and obj.guid~=nil and gStates~=nil and gStates.apocalypseQuestTokenGUIDs~=nil and gStates.apocalypseQuestTokenGUIDs[obj.guid]==true
end

function mapTokenIsShield(obj)
	return obj~=nil and obj.getName~=nil and obj.getName()=="Shield"
end

function mapTokenIsBaseSite(obj)
	--Graveyards, Destroyed Sites and Quest markers are floor layers. Ruins participate in the enemy diagonal.
	return mapTokenIsGraveyard(obj)==true or mapTokenIsDestroyedSite(obj)==true or mapTokenIsQuestMarker(obj)==true
end

function mapTokenIsSpreadEnemy(obj)
	if obj==nil then return false end
	if apocalypseDragon~=nil and obj.guid==apocalypseDragon.furyMarker then return true end
	local details=monsterPugs~=nil and monsterPugs[obj.guid] or nil
	if details==nil then return false end
	--Possessed markers are physically linked overlays, not independent tokens. Ruins are spread normally.
	if details.pugType=="possessed" then return false end
	return true
end

function mapTokenNeedsArrangement(obj)
	return mapTokenIsSpreadEnemy(obj)==true or mapTokenIsBaseSite(obj)==true or mapTokenIsShield(obj)==true
end

--Horsemen, the single-hex Fury Dragon and Pursuit monsters are always the moving/top group.
--Their own arrival order still matters when more than one moving token shares a hex.
function mapTokenIsMovingPriority(obj)
	if obj==nil or obj.guid==nil then return false end
	if horsemanTokenToName~=nil and horsemanTokenToName[obj.guid]~=nil then return true end
	if apocalypseDragon~=nil and obj.guid==apocalypseDragon.furyMarker then return true end
	for _,monsters in pairs(gStates~=nil and gStates.pursuingMonsters or {}) do
		if monsters~=nil and monsters[obj.guid]~=nil then return true end
	end
	return false
end

--New arrivals need deterministic ordering when several tokens settle together, but that ordering is
--derived table state and does not belong in gStates. Existing tokens after a load fall back to their
--physical diagonal/Y order; a new arrival gets a fresh runtime sequence and is newer than either.
local function mapTokenRecordArrival(guid)
	if guid==nil then return nil end
	mapTokenArrivalCounter=mapTokenArrivalCounter+1
	mapTokenRuntimeArrivalOrder[guid]=mapTokenArrivalCounter
	return mapTokenArrivalCounter
end

local function mapTokenArrivalOrder(guid)
	if guid==nil then return nil end
	return mapTokenRuntimeArrivalOrder[guid]
end

local function mapTokenOnHex(obj,hex)
	if obj==nil or hex==nil or hex.position==nil then return false end
	local pos=obj.getPosition()
	local dx=pos[1]-hex.position[1]
	local dz=pos[3]-hex.position[3]
	return (dx*dx)+(dz*dz)<1.5
end

--Smooth separator moves stay inside the map zone and never unlock their participants, so one
--per-object arrival generation is sufficient; the old whole-stack claim/relock layers are unnecessary.
function mapTokenAfterSettled(guid,callback)
	if guid==nil or callback==nil then return end
	safeWaitCondition("MapTokens",function()
		safeWaitFrames("MapTokens",function()
			safeWaitCondition("MapTokens",function()
				callback(getObjectFromGUID(guid))
			end,function()
				local obj=getObjectFromGUID(guid)
				return obj==nil or obj.resting==true
			end,5,function()
				callback(getObjectFromGUID(guid))
			end)
		end,1)
	end,function()
		local obj=getObjectFromGUID(guid)
		return obj==nil or obj.isSmoothMoving()==false
	end,5,function()
		callback(getObjectFromGUID(guid))
	end)
end

local function mapTokenUpdatePlayLocation(obj,pos)
	if obj==nil or pos==nil or gStates==nil or gStates.monsterPlayLocation==nil then return end
	if gStates.monsterPlayLocation[obj.guid]~=nil then
		gStates.monsterPlayLocation[obj.guid]={pos[1],pos[2],pos[3]}
	end
end

--Smooth one token to its final shared-hex slot. Scripted transforms work on locked objects, so the
--separator never unlocks/relocks pieces just to correct X/Z/Y. collide=false also prevents the small
--separation movement from physically shoving another token in the same stack.
local function mapTokenMoveToSlot(obj,targetX,targetY,targetZ)
	if obj==nil then return false end
	local pos=obj.getPosition()
	if obj.isSmoothMoving()==true then return false end
	local already=math.abs(pos[1]-targetX)<0.025 and math.abs(pos[2]-targetY)<0.025 and math.abs(pos[3]-targetZ)<0.025
	if already==true then return false end
	obj.setPositionSmooth({targetX,targetY,targetZ},false)
	mapTokenUpdatePlayLocation(obj,{targetX,targetY,targetZ})
	return true
end

--Arrange one resolved map hex. Graveyard is a centred floor/support token and never consumes a
--horizontal spread slot. Destroyed, when present, is the first spread token above that support.
--Ordinary enemies follow in arrival order. Horsemen, the single-hex Dragon and pursuing enemies
--form the moving group at the top-right end, also in arrival order.
function mapTokenArrangeHex(hex,mapObjects,ignoreGUID,extraObject)
	if hex==nil or hex.position==nil then return false end
	local objects={}
	local seen={}
	for _,obj in pairs(mapObjects or {}) do
		if obj~=nil and obj.guid~=ignoreGUID and mapTokenOnHex(obj,hex)==true and mapTokenNeedsArrangement(obj)==true then
			objects[#objects+1]=obj
			seen[obj.guid]=true
		end
	end
	if extraObject~=nil and extraObject.guid~=ignoreGUID and seen[extraObject.guid]~=true and mapTokenNeedsArrangement(extraObject)==true then
		objects[#objects+1]=extraObject
		seen[extraObject.guid]=true
	end

	local questMarkers={}
	local graveyard=nil
	local destroyed=nil
	local enemies={}
	local shields={}
	for _,obj in ipairs(objects) do
		if mapTokenIsQuestMarker(obj)==true then
			questMarkers[#questMarkers+1]=obj
		elseif mapTokenIsGraveyard(obj)==true then
			if graveyard==nil then graveyard=obj end
		elseif mapTokenIsDestroyedSite(obj)==true then
			if destroyed==nil then destroyed=obj end
		elseif mapTokenIsShield(obj)==true then
			shields[#shields+1]=obj
		elseif mapTokenIsSpreadEnemy(obj)==true then
			enemies[#enemies+1]=obj
		end
	end
	table.sort(questMarkers,function(a,b) return tostring(a.guid)<tostring(b.guid) end)
	table.sort(enemies,function(a,b)
		local aMoving=mapTokenIsMovingPriority(a)
		local bMoving=mapTokenIsMovingPriority(b)
		--Ordinary/site enemies always precede the moving group, regardless of which one physically
		--arrived later. This keeps a pre-deployed Horseman above a site token revealed afterward.
		if aMoving~=bMoving then return aMoving~=true end

		local aOrder=mapTokenArrivalOrder(a.guid)
		local bOrder=mapTokenArrivalOrder(b.guid)
		if aOrder~=bOrder then
			--An unrecorded token is necessarily older than a newly recorded arrival in this game.
			if aOrder==nil then return true end
			if bOrder==nil then return false end
			return aOrder<bOrder
		end

		--Fallback only for tokens with no distinct recorded arrival (for example pieces already present
		--when this layout first runs). Preserve an existing diagonal, then physical low-to-high stack order.
		local ap=a.getPosition()
		local bp=b.getPosition()
		local aProjection=ap[1]+ap[3]
		local bProjection=bp[1]+bp[3]
		if math.abs(aProjection-bProjection)>0.05 then return aProjection<bProjection end
		local aLayerY=mapTokenEnemyPhysicalLayerY(a)
		local bLayerY=mapTokenEnemyPhysicalLayerY(b)
		if math.abs(aLayerY-bLayerY)>0.01 then return aLayerY<bLayerY end
		return tostring(a.guid)<tostring(b.guid)
	end)
	table.sort(shields,function(a,b)
		local ap=a.getPosition()
		local bp=b.getPosition()
		local aProjection=ap[1]+ap[3]
		local bProjection=bp[1]+bp[3]
		if math.abs(aProjection-bProjection)>0.05 then return aProjection<bProjection end
		return tostring(a.guid)<tostring(b.guid)
	end)

	local centerX,centerZ=hex.position[1],hex.position[3]
	local changed=false
	local supportY=0

	--Quest markers are always bottom objects. They normally cannot share a hex with another Quest
	--marker, but stack deterministically if a future rule ever allows it.
	for index,obj in ipairs(questMarkers) do
		changed=mapTokenMoveToSlot(obj,centerX,mapTokenQuestBaseY+((index-1)*mapTokenStackStepY),centerZ) or changed
	end
	supportY=supportY+(#questMarkers*mapTokenQuestSupportY)

	--Graveyard remains a centred floor/support token. If an unusual future state combines it with a
	--Quest marker, keep the Quest marker below it rather than allowing the two floor pieces to overlap.
	if graveyard~=nil then
		changed=mapTokenMoveToSlot(graveyard,centerX,mapTokenGraveyardBaseY+supportY,centerZ) or changed
		supportY=supportY+mapTokenGraveyardSupportY
	end

	local spreadCount=#enemies+(destroyed~=nil and 1 or 0)
	--Destroyed is the lowest spread token above any floor support.
	if destroyed~=nil then
		local offset=#enemies>0 and mapTokenSpreadOffset(1,spreadCount) or {x=0,z=0}
		local targetX,targetZ=centerX+offset.x,centerZ+offset.z
		local targetY=mapTokenDestroyedBaseY+supportY
		destroyed.setRotation({0,180,0})
		changed=mapTokenMoveToSlot(destroyed,targetX,targetY,targetZ) or changed
	end

	for _,obj in ipairs(enemies) do if obj.isSmoothMoving()==true then return changed end end
	if #enemies>0 then
		--A lone enemy stays centred. Floor layers raise it without changing the measured face-up/down origin.
		if destroyed==nil and #enemies==1 then
			changed=mapTokenMoveToSlot(enemies[1],centerX,mapTokenEnemySlotY(enemies[1],1,supportY),centerZ) or changed
		else
			local firstEnemyIndex=destroyed~=nil and 2 or 1
			for index,obj in ipairs(enemies) do
				local spreadIndex=firstEnemyIndex+index-1
				local offset=mapTokenSpreadOffset(spreadIndex,spreadCount)
				changed=mapTokenMoveToSlot(obj,centerX+offset.x,mapTokenEnemySlotY(obj,spreadIndex,supportY),centerZ+offset.z) or changed
			end
		end
	end

	--Player/Quest Shields are always the top layer. Multiple Shields share that top layer with a small
	--horizontal spread so co-op markers remain individually visible.
	local shieldY=mapTokenShieldBaseY+supportY+(spreadCount*mapTokenStackStepY)
	for index,obj in ipairs(shields) do
		local offset=#shields>1 and mapTokenSpreadOffset(index,#shields) or {x=0,z=0}
		changed=mapTokenMoveToSlot(obj,centerX+offset.x,shieldY,centerZ+offset.z) or changed
	end
	return changed
end

function mapTokenArrangeObject(guid)
	local obj=guid~=nil and getObjectFromGUID(guid) or nil
	if obj==nil or mapTokenNeedsArrangement(obj)~=true then return false end
	local hexes,mapObjects=runtimeMapHexesAndObjects()
	local hex=runtimeMapHexForPosition(hexes,obj.getPosition(),mapObjects)
	if hex==nil then return false end
	return mapTokenArrangeHex(hex,mapObjects,nil,obj)
end

--Terrain population records the intended destination in monsterPlayLocation immediately after a token
--is taken from its pile. The token can cross another revealed hex while travelling there, so a passive
--map-zone event must not treat that intermediate position as its final hex and snap it into that stack.
local function mapTokenPassiveArrivalReachedPlannedHex(obj)
	if obj==nil or obj.guid==nil or gStates==nil or gStates.monsterPlayLocation==nil then return true end
	local planned=gStates.monsterPlayLocation[obj.guid]
	if planned==nil then return true end
	local hexes,mapObjects=runtimeMapHexesAndObjects()
	local plannedHex=runtimeMapHexForPosition(hexes,planned,mapObjects)
	--A recorded destination outside the revealed map means this map-zone entry is only transit.
	if plannedHex==nil then return false end
	local currentHex=runtimeMapHexForPosition(hexes,obj.getPosition(),mapObjects)
	if currentHex==nil then return false end
	return runtimeMapHexKey(currentHex)==runtimeMapHexKey(plannedHex)
end

--All map-token arrivals use this one settle path. A scripted mover registers before crossing the
--map zone; a physical drop is normally registered by the map-zone entry itself. Each token can own
--only one pending generation, so duplicate callbacks become no-ops without claiming the whole stack.
function mapTokenSettleArrival(guid,target,options,callback)
	options=options or {}
	if guid==nil then return false end
	local obj=getObjectFromGUID(guid)
	if obj==nil then return false end

	--A scripted move first releases the old hex so survivors can close up. force is reserved for
	--authoritative scripted deployments that may be reusing an object with a stale passive arrival.
	if options.releaseOrigin==true then
		mapTokenReleaseObject(obj)
	elseif options.force==true then
		mapTokenArrivalPending[guid]=nil
		mapTokenArrangeGeneration[guid]=(mapTokenArrangeGeneration[guid] or 0)+1
	end
	if mapTokenArrivalPending[guid]~=nil then return false end

	local generation=(mapTokenArrangeGeneration[guid] or 0)+1
	mapTokenArrangeGeneration[guid]=generation
	mapTokenArrivalPending[guid]=generation
	mapTokenRecordArrival(guid)

	if target~=nil then
		--Scripted transforms work while locked, so preserve the object's lock state throughout.
		if options.rotation~=nil then obj.setRotation(options.rotation) end
		obj.setPositionSmooth(target,false)
	end

	mapTokenAfterSettled(guid,function(current)
		--A newer arrival/release for this same object wins.
		if mapTokenArrivalPending[guid]~=generation then
			if callback~=nil then callback(current,false) end
			return
		end
		if current==nil then
			mapTokenArrivalPending[guid]=nil
			if callback~=nil then callback(nil,false) end
			return
		end

		--A token travelling across the map can enter the scripting zone above the wrong hex. Only passive
		--zone arrivals need this check; the explicit mover already knows its intended destination.
		if options.passive==true and mapTokenPassiveArrivalReachedPlannedHex(current)~=true then
			mapTokenArrivalPending[guid]=nil
			if callback~=nil then callback(current,false) end
			return
		end

		--A destructive mover can defer its own spread until the replacement Destroyed Site arrives,
		--avoiding an intermediate arrange that would immediately be invalidated.
		local arranged=false
		if options.deferArrange~=true then arranged=mapTokenArrangeObject(guid) end
		--Keep this generation pending until any final smooth separator correction has settled. This also
		--makes the delayed onObjectDrop fallback a guaranteed no-op when the map-zone path already owns it.
		mapTokenAfterSettled(guid,function(finalObj)
			if mapTokenArrivalPending[guid]==generation then mapTokenArrivalPending[guid]=nil end
			if callback~=nil then callback(finalObj,arranged) end
		end)
	end)
	return true
end

--The map-zone entry is the normal physical-arrival trigger. onObjectDrop only calls this later as
--insurance for a token that entered the short map zone while it was still being held.
function mapTokenScheduleObject(guid)
	return mapTokenSettleArrival(guid,nil,{passive=true})
end

--Run work only after the token's complete arrival transaction has finished, including any final
--separator correction. This is intentionally later than mapTokenAfterSettled(), which is also used
--inside mapTokenSettleArrival while its generation is still pending.
function mapTokenAfterArrivalComplete(guid,callback)
	if guid==nil or callback==nil then return end
	safeWaitCondition("MapTokens.mapTokenArrivalComplete",function()
		callback(getObjectFromGUID(guid))
	end,function()
		local obj=getObjectFromGUID(guid)
		return obj==nil or (mapTokenArrivalPending[guid]==nil and obj.isSmoothMoving()==false and obj.resting==true)
	end)
end

--Re-arrange the hex an object is leaving while deliberately ignoring that object. This recentres a
--remaining lone enemy and keeps a Destroyed Site marker fixed underneath anything still on the hex.
function mapTokenReleaseObject(obj)
	if obj==nil or mapTokenNeedsArrangement(obj)~=true then return false end
	local position=obj.getPosition()
	local ignoreGUID=obj.guid
	--Invalidate delayed arrival/manual-drop work for the object now being carried away.
	mapTokenArrivalPending[ignoreGUID]=nil
	mapTokenArrangeGeneration[ignoreGUID]=(mapTokenArrangeGeneration[ignoreGUID] or 0)+1
	safeWaitFrames("MapTokens",function()
		local hexes,mapObjects=runtimeMapHexesAndObjects()
		local hex=runtimeMapHexForPosition(hexes,position,mapObjects)
		if hex~=nil then mapTokenArrangeHex(hex,mapObjects,ignoreGUID,nil) end
	end,1)
	return true
end

local mapTokenTerrainReconcilePending={}

local function mapTokenTerrainReadyForReconcile(terrainGUID)
	local hexes,mapObjects=runtimeMapHexesAndObjects()
	for _,obj in pairs(mapObjects or {}) do
		if mapTokenNeedsArrangement(obj)==true then
			local hex=runtimeMapHexForPosition(hexes,obj.getPosition(),mapObjects)
			if hex~=nil and (terrainGUID==nil or hex.terrainGUID==terrainGUID) then
				if mapTokenArrivalPending[obj.guid]~=nil or obj.isSmoothMoving()==true or obj.resting~=true then return false end
			end
		end
	end
	return true
end

local function mapTokenArrangeAllOccupiedHexesNow(terrainGUID)
	local hexes,mapObjects=runtimeMapHexesAndObjects()
	local touched={}
	for _,obj in pairs(mapObjects or {}) do
		if mapTokenNeedsArrangement(obj)==true then
			local hex=runtimeMapHexForPosition(hexes,obj.getPosition(),mapObjects)
			local key=hex~=nil and runtimeMapHexKey(hex) or nil
			--Terrain completion only reconciles shared stacks on the tile that just finished population.
			if hex~=nil and key~=nil and touched[key]~=true and (terrainGUID==nil or hex.terrainGUID==terrainGUID) then
				touched[key]=true
				local participantCount=0
				for _,candidate in pairs(mapObjects or {}) do
					if candidate~=nil and mapTokenNeedsArrangement(candidate)==true and mapTokenOnHex(candidate,hex)==true then
						participantCount=participantCount+1
					end
				end
				--A lone token has nothing to separate. Leaving it alone avoids the old Keep/Mage Tower shimmer.
				if participantCount>1 then mapTokenArrangeHex(hex,mapObjects,nil,nil) end
			end
		end
	end
	return true
end

local function mapTokenAfterTerrainReconcile(terrainGUID,callback)
	if callback==nil then return end
	safeWaitCondition("MapTokens",callback,function()
		return mapTokenTerrainReconcilePending[terrainGUID]~=true and mapTokenTerrainReadyForReconcile(terrainGUID)==true
	end,5,callback)
end

function mapTokenArrangeAllOccupiedHexes(terrainGUID,afterReconcile)
	if terrainGUID==nil or mapTokenTerrainReadyForReconcile(terrainGUID)==true then
		local result=mapTokenArrangeAllOccupiedHexesNow(terrainGUID)
		mapTokenAfterTerrainReconcile(terrainGUID,afterReconcile)
		return result
	end
	if mapTokenTerrainReconcilePending[terrainGUID]==true then
		mapTokenAfterTerrainReconcile(terrainGUID,afterReconcile)
		return false
	end
	mapTokenTerrainReconcilePending[terrainGUID]=true
	local function finish()
		mapTokenTerrainReconcilePending[terrainGUID]=nil
		mapTokenArrangeAllOccupiedHexesNow(terrainGUID)
		mapTokenAfterTerrainReconcile(terrainGUID,afterReconcile)
	end
	--Script-deployed map pieces can still be falling when terrain population code itself is finished.
	--Wait for their own arrival/separator work to finish, then perform one final shared-stack pass.
	safeWaitCondition("MapTokens",finish,function()
		return mapTokenTerrainReadyForReconcile(terrainGUID)
	end,5,finish)
	return false
end

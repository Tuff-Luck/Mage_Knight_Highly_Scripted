-- Module-private helpers. Predeclared so forward references keep resolving locally.
local removeCardRemoveDecal

-- Crystal visual effects belong to play-area membership, not to the physics-settled
-- path used by positional card/Unit logic. A shallow zone is crossed again when
-- objects are lifted, so invalidate old timers on every boundary transition.
local playAreaCrystalAnimation={}
-- Entry/exit callbacks are authoritative for the looping animation; only
-- ambiguous drops and genuine departures need an expensive physical recheck.
local playAreaCrystalMembership={}

local function playAreaCrystalZoneGUID(ctx)
    if ctx==nil then return nil end
    if ctx.zoneGUID~=nil then return ctx.zoneGUID end
    local seat=ctx.zoneInfo~=nil and ctx.zoneInfo.seatPos or nil
    return seat~=nil and playerPlayAreas[seat] or nil
end

local function playAreaCrystalSetMembership(ctx,inside)
    local guid=ctx~=nil and ctx.objGUID or nil
    local zoneGUID=playAreaCrystalZoneGUID(ctx)
    if guid==nil or zoneGUID==nil then return end
    local known=playAreaCrystalMembership[guid]
    if inside then
        if known==nil then known={} playAreaCrystalMembership[guid]=known end
        known[zoneGUID]=true
    elseif known~=nil then
        known[zoneGUID]=nil
        if next(known)==nil then playAreaCrystalMembership[guid]=nil end
    end
end

local function playAreaCrystalInZone(guid,verifyPhysical)
    if verifyPhysical~=true then
        local known=playAreaCrystalMembership[guid]
        return known~=nil and next(known)~=nil
    end
    -- A drop can occur above a shallow zone or after a missed boundary
    -- transition. Refresh this token's membership only on that ambiguity.
    local found={}
    for _,zoneGUID in pairs(playerPlayAreas or {}) do
        local zone=zoneGUID~=nil and getObjectFromGUID(zoneGUID) or nil
        if zone~=nil then
            for _,candidate in ipairs(zone.getObjects()) do
                if candidate.guid==guid then found[zoneGUID]=true break end
            end
        end
    end
    playAreaCrystalMembership[guid]=next(found)~=nil and found or nil
    return next(found)~=nil
end

local function playAreaCrystalCancelTimer(state,key)
    if state[key]~=nil then Wait.stop(state[key]) state[key]=nil end
end

local function playAreaCrystalBurst(obj,state)
    if obj==nil or state==nil or state.inPlay~=true then return end
    local guid=obj.guid
    state.awaitingDrop=false
    playAreaCrystalCancelTimer(state,"loopTimer")
    if obj.AssetBundle~=nil then obj.AssetBundle.playTriggerEffect(0) end
    local serial=state.serial
    state.loopTimer=safeWaitTime("PlayerBoard.Events",function()
        state.loopTimer=nil
        if playAreaCrystalAnimation[guid]~=state or state.serial~=serial or state.inPlay~=true then return end
        local live=getObjectFromGUID(guid)
        if live~=nil and live.AssetBundle~=nil and playAreaCrystalInZone(guid) then
            live.AssetBundle.playLoopingEffect(1)
        end
    end,1)
end

function playerBoardCrystalEnteredPlayArea(ctx)
    local obj=ctx~=nil and ctx.obj or nil
    if obj==nil or not isManaTokenFigurine(obj) then return end
    local guid=obj.guid
    playAreaCrystalSetMembership(ctx,true)
    local state=playAreaCrystalAnimation[guid]
    if state==nil then state={serial=0} playAreaCrystalAnimation[guid]=state end
    if state.inPlay==true then return end
    state.serial=state.serial+1
    state.inPlay=true
    playAreaCrystalCancelTimer(state,"stopTimer")
    -- A crossing while held is not placement: the drop callback handles it.
    if obj.held_by_color~=nil then state.awaitingDrop=true
    else playAreaCrystalBurst(obj,state) end
end

function playerBoardCrystalLeftPlayArea(ctx)
    local obj=ctx~=nil and ctx.obj or nil
    if obj==nil or not isManaTokenFigurine(obj) then return end
    local guid=obj.guid
    playAreaCrystalSetMembership(ctx,false)
    if playAreaCrystalInZone(guid) then return end
    local state=playAreaCrystalAnimation[guid]
    if state==nil then state={serial=0} playAreaCrystalAnimation[guid]=state end
    state.serial=state.serial+1
    state.inPlay=false
    state.awaitingDrop=false
    playAreaCrystalCancelTimer(state,"loopTimer")
    playAreaCrystalCancelTimer(state,"stopTimer")
    local serial=state.serial
    state.stopTimer=safeWaitTime("PlayerBoard.Events",function()
        state.stopTimer=nil
        if playAreaCrystalAnimation[guid]~=state or state.serial~=serial or state.inPlay==true then return end
        local live=getObjectFromGUID(guid)
        if live==nil then playAreaCrystalAnimation[guid]=nil return end
        -- Do not switch off a token still held above the mat.
        if live.held_by_color~=nil then return end
        if playAreaCrystalInZone(guid,true) then return end
        if live.AssetBundle~=nil then live.AssetBundle.playLoopingEffect(0) end
        playAreaCrystalAnimation[guid]=nil
    end,0.22)
end

function playerBoardCrystalDropped(obj)
    if obj==nil or not isManaTokenFigurine(obj) then return end
    local state=playAreaCrystalAnimation[obj.guid]
    if state==nil then return end
    local inside=playAreaCrystalInZone(obj.guid,true)
    if state.inPlay==true and state.awaitingDrop==true and inside then
        playAreaCrystalBurst(obj,state)
    elseif not inside and obj.held_by_color==nil then
        -- A missed exit event must not leave an endless crystal glow.
        state.inPlay=false
        state.awaitingDrop=false
        state.serial=state.serial+1
        playAreaCrystalCancelTimer(state,"stopTimer")
        playAreaCrystalCancelTimer(state,"loopTimer")
        if obj.AssetBundle~=nil then obj.AssetBundle.playLoopingEffect(0) end
        playAreaCrystalAnimation[obj.guid]=nil
    end
end

-- Player-board scripting-zone reactions dispatched by PlayingGame.Events.

-- The main turn UI needs cards, skills, wounds and enemies, not every
-- die, decoration or mana token briefly crossing a shallow play zone.
local function playerBoardPlayAreaAffectsMainUI(obj)
    if obj==nil or obj.guid==nil then return false end
    if obj.type=="Card" or skillTokens[obj.guid]~=nil
        or monsterPugs[obj.guid]~=nil then return true end
    if unitLayoutIsCommand(obj) or unitLayoutIsWound(obj) then return true end
    return obj.getGMNotes()=="Wound"
end

--Face-down cards in a player play area get a physical decal instead of Object UI.
local cardRemoveDecalURL="https://steamusercontent-a.akamaihd.net/ugc/1661232230977162756/90D8AEB60005119DD4182B5FD24D7BDD8243B5F3/"
function cardInPlayerPlayArea(cardGUID)
	for a=1, 4 do
		local zone=getObjectFromGUID(playerPlayAreas[a])
		if zone~=nil then for _, card in pairs(zone.getObjects()) do if card.guid==cardGUID then return true end end end
	end
	return false
end
removeCardRemoveDecal=function(card)
	if card==nil then return end
	local decals={}
	local changed=false
	for _, decal in pairs(card.getDecals() or {}) do
		if decal.name=="Card Remove" then changed=true else decals[#decals+1]=decal end
	end
	if changed==true then card.setDecals(decals) end
end
function refreshCardRemoveDecal(card, knownInPlayArea)
	if card==nil or card.type~="Card" or not (gameCards[card.guid]==nil or gameCards[card.guid].full==nil) then return end
	removeCardRemoveDecal(card)
	if card.is_face_down==true and (knownInPlayArea==true or cardInPlayerPlayArea(card.guid)==true) then
		--Face-down cards are rotated over, so put the decal on the card's local underside.
		card.addDecal({name="Card Remove", url=cardRemoveDecalURL, position={0,-0.5,0}, rotation={270,180,180}, scale={1.7,2.0,1}})
	end
end

function playerBoardPlayAreaZoneEnterImmediate(ctx)
	if ctx==nil then return end
	local zoneInfo=ctx.zoneInfo
	if zoneInfo==nil or zoneInfo.kind~="play" then return end
	-- Crystal bursts are visual feedback for placement, not a settled-position calculation.
	playerBoardCrystalEnteredPlayArea(ctx)
	if gStates.turnNumber<=0 or turnOrderIndexAtSeat(zoneInfo.seatPos)==nil then return end
	local obj=ctx.obj
	if obj==nil then return end
	local seatPos=zoneInfo.seatPos
	local affectsMainUI=playerBoardPlayAreaAffectsMainUI(obj)
    if affectsMainUI then updatePlayAreaObjectState(seatPos,obj,true) end
	playAreaScaleApplyObject(seatPos,obj)
	--The face-down remove image depends only on play-area membership and face state, not final position.
	--Apply it on zone entry so it appears while the card is still falling/sliding into place.
	if obj.type=="Card" and (gameCards[obj.guid]==nil or gameCards[obj.guid].full==nil) then refreshCardRemoveDecal(obj,true) end
    if affectsMainUI then
        dayTactic2ExpireIfCardPlayed(seatPos)
        mainUIUpdate("Object entered into play area")
    end
	schedulePlayAreaScale(seatPos)
end

function playerBoardZoneEnterSettled(ctx)
	local zone=ctx.zone
	local obj=ctx.obj
	local zoneGUID=ctx.zoneGUID
	local objGUID=ctx.objGUID
	local zoneInfo=ctx.zoneInfo
	local objType=ctx.objType
	--Deed/discard bookkeeping can run on entry. Play-area UI bookkeeping already ran immediately
	--before the settled player-board path so the interface does not wait for physics to finish.
	if gStates.turnNumber>0 then--makes sure end of round doesn't have errors
		if zoneInfo~=nil and (zoneInfo.kind=="deed" or zoneInfo.kind=="discard") and turnOrderIndexAtSeat(zoneInfo.seatPos)~=nil then
			local seatPos=zoneInfo.seatPos
			if zoneInfo.kind=="deed" and (objType=="Card" or objType=="Deck") then
				if objType=="Deck" then obj.max_typed_number=1 end
				scheduleEndRoundDeedStateRefresh(seatPos)
			end
			--remove banner card from register if returned to deck.
			if zoneInfo.kind=="discard" and gameCards[objGUID]~=nil and gameCards[objGUID].half~=nil then gStates.bannercard[gameCards[objGUID].half]=nil end
			mainUIUpdate("Object entered into deed deck or discard")
		end
	end

	--Object entered player board
	if zoneInfo~=nil and zoneInfo.kind=="play" then
		--increment Master of chaos skill
		if objGUID==GUID.skill.masterOfChaos then
			if masterOfChaosPause==false then
				masterOfChaosPause=true
				if masterOfChaosWait~=nil then Wait.stop(masterOfChaosWait) end
				local temp=gStates.masterOfChaos+1
				if temp==7 then temp=1 end
				obj.setCustomObject({image=masterOfChaosData[temp].image})
				for a=1, #turnOrder, 1 do
					if turnOrder[a].masterOfChaos~=nil then turnOrder[a].masterOfChaos="used" break end
				end
				obj.reload()
				safeWaitFrames("PlayerBoard.Events",function() masterOfChaosPause=false end, 10)
			end
			return true
		end

		--Add combat buttons to monster tokens.
		local addedButtons=monsterObjectButtons(obj)


		--Add fortified symbol
		if gStates.monsterPlayLocation[objGUID]~=nil and monsterPugs[objGUID]~=nil and monsterPugs[objGUID].unfortified==nil then
			local target=gStates.monsterPlayLocation[objGUID]
			local attackingVolkare=false
			if gStates.cityMonsterQty[volkare.model]~=nil then
				for guid, state in pairs(gStates.cityMonsterQty[volkare.model]) do
					if guid==objGUID then
						local volkareObj=gStates.volkareModel~=nil and getObjectFromGUID(gStates.volkareModel) or nil
						if volkareObj~=nil then target={volkareObj.getPosition()[1], volkareObj.getPosition()[2], volkareObj.getPosition()[3]} end
						attackingVolkare=true
					end
				end
			end
			local targetHex, _, terTile, monsterhexBearing=runtimeMapHexAtPosition(target)
			if targetHex~=nil and terTile~=nil and monsterhexBearing~=nil and gStates.volkareState~=nil and gStates.volkareState:sub(1, 9)~="Attacking" then

				--fortified for Volkare's Army
				if attackingVolkare==true and monsterPugs[objGUID].unfortified==nil and (targetHex.feature=="mage tower" or targetHex.feature=="keep") then
					local found=false
					local existingDecals=obj.getDecals() or {}
					for _, decalDetails in pairs(existingDecals) do
						if decalDetails.name=="Fortified" then found=true break end
					end
					if found==false then
						obj.addDecal({name="Fortified", url="https://steamusercontent-a.akamaihd.net/ugc/15769941683634999180/45D8BF9859C1F2C026A3B40DA634B74286E2C3EB/", position={0.8, 0.15, -0.8}, rotation={90, 180, 0}, scale={0.72, 0.72, 1}})
						if gStates.monsterPerks[objGUID]==nil then gStates.monsterPerks[objGUID]={fortified=true} else gStates.monsterPerks[objGUID].fortified=true end
					end
				end


			end
		end
		--Manual monster movement cannot assume the current avatar crossed a particular wall.
		--If the avatar is not on an adjacent hex, use the existing wall-choice interface.
		resolveManualMonsterWallFortified(obj)
		if #addedButtons>0 then obj.UI.setXmlTable(addedButtons) end

		--Toggle Half Cards
		if gameCards[objGUID]~=nil and gameCards[objGUID].half~=nil then
			local bannerPosition=obj.getPosition()
			-- A thrown full Banner stays face up. Only Recover restores its
			-- eligibility for conversion to the attached half-card state.
			if bannerPosition[3]>=-38.4 and obj.is_face_down~=true
				and not resourceCardsArtifactBroken(objGUID,obj) then
				local pass=bannerPosition[1]
				local halfGUID=gameCards[objGUID].half
				obj.setState(2)
				local bannerSeat=zoneInfo.seatPos
				safeWaitFrames("PlayerBoard.Events",function()
					local halfCard=getObjectFromGUID(halfGUID)
					if halfCard~=nil then
						halfCard.setScale({0.65, 1, 0.65})
						halfCard.setPosition({pass, 1.2, -38.12})
						scheduleUnitLayoutRefresh(bannerSeat)
					end
				end, 3)
			end
		end


		--Add command decal to banner of Command
		if objGUID==GUID.card.bannerOfCommandToken then
			bannerOfCommandDecal()
			scheduleUnitLayoutRefresh(zoneInfo.seatPos)
		end

	end

	--Unit Area work is event-driven: split accidental two-card Unit decks only when this area changes.
	local unitZoneInfo=zoneInfo
	if unitZoneInfo~=nil and unitZoneInfo.kind=="unit" then
		local unitSeatPos=unitZoneInfo.seatPos
		if objType=="Card" or objType=="Deck" then safeWaitFrames("PlayerBoard.Events",function() separateCombinedUnitsInArea(unitSeatPos) end, 2) end
		scheduleUnitLayoutRefresh(unitSeatPos)
        -- A manually added Unit may replace one that was trashed earlier.
        -- Once released, X/Z identifies its Command column even if the
        -- card is falling. Lifts never clear spent Command history.
        if objType=="Card" and unitLayoutIsUnit(obj) then
            local incomingGUID=objGUID
            safeWaitCondition("PlayerBoard.Events",function()
                local incoming=getObjectFromGUID(incomingGUID)
                if incoming~=nil and unitLayoutObjectInAnyUnitArea(incomingGUID)
                    and resourceUnitsReconcileNewUnit~=nil then
                    resourceUnitsReconcileNewUnit(incomingGUID,unitSeatPos)
                end
            end,function()
                local incoming=getObjectFromGUID(incomingGUID)
                return incoming==nil or ((incoming.held_by_color==nil or incoming.held_by_color=="")
                    and incoming.isSmoothMoving()==false)
            end,8)
        end
		--Monster tokens may be dropped directly on Units. Give them the same combat controls and reward refresh as Play Area monsters.
		if monsterPugs[objGUID]~=nil then
			local monsterGUID=objGUID
			safeWaitFrames("PlayerBoard.Events",function()
				local monster=getObjectFromGUID(monsterGUID)
				if monster~=nil and objectInPlayerCombatArea(monsterGUID)==true then
					local addedButtons=monsterObjectButtons(monster)
					if #addedButtons>0 then monster.UI.setXmlTable(addedButtons) end
					mainUIUpdate("Monster entered unit area")
				end
			end, 2)
		end
	end

	--Re-add avatar buttons when an avatar enters a non-map zone. Entering the map scripting
	--zone happens before onObjectDrop has recalculated its new hex, so refreshing here would
	--briefly attach the previous location's buttons. The settled drop owns the map refresh.
	if mageKnightAvatarGUIDs[objGUID]==true and zoneGUID~=mapArea then addAvatarButtons() end

	--Change wound cards dropped on units to wound token.
	if zoneInfo~=nil and zoneInfo.kind=="unit" and objType=="Card" and obj.getGMNotes()=="Wound" then
		local woundPosition=obj.getPosition()
		local woundX=woundPosition[1]
		if woundPosition[3]>=-37 and ((woundX>-65.3 and woundX<-42.7) or (woundX>-25.3 and woundX<-2.7) or
			(woundX>14.7 and woundX<37.3) or (woundX>54.7 and woundX<77.3)) then
			local bag=getObjectFromGUID("ab56f3")
			local token=bag~=nil and safeTakeObject("PlayerBoard.Events",bag,
				{position={woundX, woundPosition[2], -33.29}, smooth=false}) or nil
			-- Do not lose a Wound if the replacement token cannot be taken.
			if token~=nil then
				deedRemoveWoundCard(obj)
			end
		end
	end

	-- Only defenders belonging to this Ruin can affect its face state.
	local ruinGUID=gStates.ruinMonsters~=nil and gStates.ruinMonsters[objGUID] or nil
	if ruinGUID~=nil then
		local ruinObj=getObjectFromGUID(ruinGUID)
		if ruinObj==nil then
			-- A recycled enemy cannot keep a link to a removed Ruin.
			gStates.ruinMonsters[objGUID]=nil
		elseif obj.is_face_down==true then
			if ruinObj.is_face_down==false then ruinObj.flip() end
		else
			local anyUndefeated=false
			for monsterGUID,linkedRuinGUID in pairs(gStates.ruinMonsters) do
				if linkedRuinGUID==ruinGUID then
					local monsterObj=getObjectFromGUID(monsterGUID)
					if monsterObj~=nil and monsterObj.is_face_down==true then
						anyUndefeated=true
						break
					end
				end
			end
			if not anyUndefeated and ruinObj.is_face_down==true then ruinObj.flip() end
		end
	end

	--record potion return locationTest
	if zoneInfo~=nil and zoneInfo.kind=="crystal" and scriptObjectId(obj):sub(-6)=="Potion" then
		local potionPosition=obj.getPosition()
		gStates.mageSkills[objGUID]={potionPosition[1], potionPosition[2], potionPosition[3]}
	end

	--Lock possesed token on to nearest monster
	if (zoneGUID==mapArea or (zoneInfo~=nil and zoneInfo.kind=="play"))
		and monsterPugs[objGUID]~=nil and monsterPugs[objGUID].pugType=="possessed" then
		attachEnemy(nil, nil, "attach", obj, zone)
	end
	return false
end

-- Remove only tracker-owned root controls. Claim/offer/ability UIs may
-- already have been installed by the object entering a different zone.
local function playerBoardClearObjectUIIfPresent(obj)
    if obj==nil or obj.UI==nil then return false end
    local xml=obj.UI.getXmlTable() or {}
    local kept,changed={},false
    for _,node in ipairs(xml) do
        local attrs=type(node)=="table" and node.attributes or nil
        local id=attrs~=nil and attrs.id or nil
        local trackerOwned=type(id)=="string" and (
            id:sub(1,19)=="ResourceCardChoice_"
            or id:sub(1,23)=="AttackAssignmentSource_")
        if trackerOwned then changed=true
        elseif type(node)=="table" and node.tag~=nil then kept[#kept+1]=node end
    end
    if changed then obj.UI.setXmlTable(#kept>0 and kept or {{}}) end
    return changed
end

-- A card can be released above the deliberately shallow Play Area trigger.
-- Use the zone's X/Z transform rather than getBounds(), which can be zero.
local function playerBoardPlayMatSeat(obj)
    local pos=obj~=nil and obj.getPosition() or nil
    if pos==nil then return nil end
    local x,z=pos.x or pos[1],pos.z or pos[3]
    if x==nil or z==nil then return nil end
    for seat=1,4 do
        local zone=getObjectFromGUID(playerPlayAreas[seat])
        if zone~=nil then
            local center,size=zone.getPosition(),zone.getScale()
            local cx,cz=center.x or center[1],center.z or center[3]
            local width,depth=size.x or size[1],size.z or size[3]
            if width>0 and depth>0 then
                local rotation=zone.getRotation()
                local yaw=math.rad(rotation.y or rotation[2] or 0)
                local dx,dz=x-cx,z-cz
                local localX=dx*math.cos(yaw)-dz*math.sin(yaw)
                local localZ=dx*math.sin(yaw)+dz*math.cos(yaw)
                if math.abs(localX)<width*0.5 and math.abs(localZ)<depth*0.5 then
                    return seat
                end
            end
        end
    end
    return nil
end

local function playerBoardObjectOnPlayMat(obj)
    return playerBoardPlayMatSeat(obj)~=nil
end

-- A lifted card must never have its buttons destroyed on the exit frame.
-- One pending cleanup per GUID is resumed by onObjectDrop if still held.
local playerBoardPendingUICleanup={}
local function playerBoardScheduleUICleanup(guid)
    if guid==nil then return end
    local serial=(playerBoardPendingUICleanup[guid] or 0)+1
    playerBoardPendingUICleanup[guid]=serial
    local function apply()
        if playerBoardPendingUICleanup[guid]~=serial then return end
        local live=getObjectFromGUID(guid)
        if live==nil then playerBoardPendingUICleanup[guid]=nil return end
        if live.held_by_color~=nil or live.isSmoothMoving()==true then return end
        playerBoardPendingUICleanup[guid]=nil
        if unitLayoutIsUnit(live) and unitLayoutObjectInAnyUnitArea(guid) then return end
        if monsterPugs[guid]~=nil then
            -- Map entry has its own UI renderer; never overwrite its controls.
            if objectInPlayerCombatArea(guid)==false and runtimeMapContainsGUID(guid)~=true then
                for _,node in ipairs(live.UI.getXmlTable() or {}) do
                    if type(node)=="table" and node.tag~=nil then
                        live.UI.setXmlTable({{}})
                        break
                    end
                end
            end
        elseif not cardInPlayerPlayArea(guid) and not playerBoardObjectOnPlayMat(live) then
            playerBoardClearObjectUIIfPresent(live)
        end
    end
    safeWaitFrames("PlayerBoard.Events",function()
        if playerBoardPendingUICleanup[guid]~=serial then return end
        local live=getObjectFromGUID(guid)
        if live==nil then playerBoardPendingUICleanup[guid]=nil return end
        if live.held_by_color~=nil then return end
        if live.isSmoothMoving()==false then apply() return end
        safeWaitCondition("PlayerBoard.Events",apply,function()
            if playerBoardPendingUICleanup[guid]~=serial then return true end
            local candidate=getObjectFromGUID(guid)
            return candidate==nil or ((candidate.held_by_color==nil or candidate.held_by_color=="")
                and candidate.isSmoothMoving()==false)
        end,8,function()
            if playerBoardPendingUICleanup[guid]~=serial then return end
            local candidate=getObjectFromGUID(guid)
            if candidate==nil or (candidate.held_by_color==nil
                and candidate.isSmoothMoving()==false) then apply() end
        end)
    end,2)
end

-- A deliberately crooked played card is a request to tuck it under ONE
-- overlapping played card. Native U has no callable Lua equivalent, and
-- putObject would merge the two cards into a Deck (losing individual UIs).
local playerBoardCrookedUnderPending={}
local function playerBoardCrookedUnderRotation(card)
    local rot=card.getRotation()
    local yaw=(rot.y or rot[2] or 0)%90
    local pitch=(rot.x or rot[1] or 0)%180
    local roll=(rot.z or rot[3] or 0)%180
    return math.min(yaw,90-yaw)>5
        and math.min(pitch,180-pitch)<12 and math.min(roll,180-roll)<12
end

local function playerBoardCrookedUnderOverlaps(a,b)
    local aBounds,bBounds=a.getBounds(),b.getBounds()
    local as=aBounds~=nil and aBounds.size or nil
    local bs=bBounds~=nil and bBounds.size or nil
    if as==nil or bs==nil then return false end
    local ax,az=as.x or as[1],as.z or as[3]
    local bx,bz=bs.x or bs[1],bs.z or bs[3]
    if ax==nil or az==nil or bx==nil or bz==nil
        or math.min(ax,az,bx,bz)<=0 then return false end
    local ap,bp=a.getPosition(),b.getPosition()
    local overlapX=(ax+bx)*0.5-math.abs((ap.x or ap[1])-(bp.x or bp[1]))
    local overlapZ=(az+bz)*0.5-math.abs((ap.z or ap[3])-(bp.z or bp[3]))
    -- A marginal corner touch must not rearrange adjacent played cards.
    return overlapX>math.min(ax,bx)*0.35 and overlapZ>math.min(az,bz)*0.35
end

function playerBoardSendCardUnder(card,top,finished,isCurrent)
    local guid,topGUID=card.guid,top.guid
    local topPosition=top.getPosition()
    local topX,topY,topZ=topPosition.x or topPosition[1],
        topPosition.y or topPosition[2],topPosition.z or topPosition[3]
    local cardPosition=card.getPosition()
    local cardX,cardZ=cardPosition.x or cardPosition[1],
        cardPosition.z or cardPosition[3]
    -- Preserve explicit card options/target locks through the move.
    if resourceCardsObjectPickedUp~=nil then
        resourceCardsObjectPickedUp(card)
        resourceCardsObjectPickedUp(top)
    end
    -- With collision disabled during smooth movement, both cards can
    -- exchange Y order directly. No large lift across the shallow zone
    -- (or deck-merging putObject call) is necessary.
    top.setPositionSmooth({topX,topY+0.13,topZ},false,false)
    card.setPositionSmooth({cardX,topY,cardZ},false,false)
    local function reconcile()
        if isCurrent~=nil and not isCurrent() then return end
        local lower=getObjectFromGUID(guid)
        local upper=getObjectFromGUID(topGUID)
        if resourceCardsObjectMoved~=nil then
            if lower~=nil and lower.held_by_color==nil then
                resourceCardsObjectMoved(lower)
            end
            if upper~=nil and upper.held_by_color==nil then
                resourceCardsObjectMoved(upper)
            end
        end
        if finished~=nil then finished() end
    end
    safeWaitCondition("PlayerBoard.Events.crookedUnder",reconcile,function()
        local lower=getObjectFromGUID(guid)
        local upper=getObjectFromGUID(topGUID)
        if lower==nil or upper==nil then return true end
        if lower.held_by_color~=nil or upper.held_by_color~=nil then return true end
        return not lower.isSmoothMoving() and not upper.isSmoothMoving()
    end,4,reconcile)
end

local function playerBoardScheduleCrookedUnder(obj)
    if gStates==nil or gStates.firstStarted~=true or obj==nil
        or obj.type~="Card" or gameCards[obj.guid]==nil
        or not playerBoardCrookedUnderRotation(obj) then return end
    local guid=obj.guid
    local state={tries=0,stable=0}
    playerBoardCrookedUnderPending[guid]=state
    local function finish()
        if playerBoardCrookedUnderPending[guid]==state then
            playerBoardCrookedUnderPending[guid]=nil
        end
    end
    local function released(card,seat)
        return card~=nil and (card.isDestroyed==nil or not card.isDestroyed())
            and card.held_by_color==nil and not card.isSmoothMoving()
            and playerBoardPlayMatSeat(card)==seat
    end
    local function sendUnder(card,top,seat)
        playerBoardSendCardUnder(card,top,finish,function()
            return playerBoardCrookedUnderPending[guid]==state
        end)
    end
    local function sample()
        if playerBoardCrookedUnderPending[guid]~=state then return end
        state.tries=state.tries+1
        local card=getObjectFromGUID(guid)
        local seat=card~=nil and playerBoardPlayMatSeat(card) or nil
        if seat==nil or not released(card,seat)
            or not playerBoardCrookedUnderRotation(card) then finish() return end
        local p,rot=card.getPosition(),card.getRotation()
        local x,y,z=p.x or p[1],p.y or p[2],p.z or p[3]
        local yaw=rot.y or rot[2] or 0
        local prior=state.previous
        if prior~=nil and math.abs(x-prior.x)<0.04
            and math.abs(z-prior.z)<0.04
            and math.abs((yaw-prior.yaw+180)%360-180)<1 then
            state.stable=state.stable+1
        else state.stable=0 end
        state.previous={x=x,z=z,yaw=yaw}
        if state.stable>=2 then
            if state.targetGUID==nil then
                local candidate
                for _,other in ipairs(getAllObjects()) do
                    if other.guid~=guid and other.type=="Card"
                        and gameCards[other.guid]~=nil
                        and playerBoardPlayMatSeat(other)==seat
                        and playerBoardCrookedUnderOverlaps(card,other) then
                        if candidate~=nil then finish() return end
                        candidate=other
                    end
                end
                if candidate==nil then finish() return end
                state.targetGUID=candidate.guid
            end
            local top=getObjectFromGUID(state.targetGUID)
            if top==nil or not playerBoardCrookedUnderOverlaps(card,top)
                or playerBoardPlayMatSeat(top)~=seat then finish() return end
            local tp=top.getPosition()
            local delta=y-(tp.y or tp[2])
            if delta<=0.008 then finish() return end
            if delta<=0.45 and released(top,seat) then
                sendUnder(card,top,seat)
                return
            end
        end
        -- Falling through the shallow zone need not become 'resting'.
        -- Give it a bounded height/XZ sampling window after the drop.
        if state.tries>=90 then finish()
        else safeWaitFrames("PlayerBoard.Events",sample,1) end
    end
    safeWaitFrames("PlayerBoard.Events",sample,1)
end

function playerBoardObjectDropped(obj)
    if obj~=nil and obj.guid~=nil
        and playerBoardPendingUICleanup[obj.guid]~=nil then
        playerBoardScheduleUICleanup(obj.guid)
    end
    playerBoardScheduleCrookedUnder(obj)
end

function playerBoardZoneLeave(ctx)
	local zone=ctx.zone
	local obj=ctx.obj
	local zoneGUID=ctx.zoneGUID
	local objGUID=ctx.objGUID
	local zoneInfo=ctx.zoneInfo
	if zoneInfo~=nil and zoneInfo.kind=="play" then playerBoardCrystalLeftPlayArea(ctx) end
	local objType=ctx.objType
	if obj~=nil and skillTokens[obj.guid]~=nil and (skillTokens[obj.guid].skillType=="Coop" or skillTokens[obj.guid].skillType=="Comp") then
		for playerIndex, details in pairs(turnOrder) do
			if details.seatPos~=nil and zone.guid==playerPlayAreas[details.seatPos] then coopCompSkillLeftPlayArea(obj.guid, playerIndex) break end
		end
	end
	if gStates.turnNumber>0 and turnOrder[gStates.turnNumber]~=nil and zone.guid==handZones[turnOrder[gStates.turnNumber].seatPos] then scheduleTactic4HandBonusRefresh() end
	if (zone.guid==playerPlayAreas[2] or zone.guid==playerPlayAreas[3] or zone.guid==playerPlayAreas[1] or zone.guid==playerPlayAreas[4]) and getObjectFromGUID(obj.guid)~=nil then
		-- Preserve Object UI during temporary lifts. Only clear owned
        -- controls after a confirmed departure/drop, never on zone exit.
        if not isManaTokenFigurine(obj) and objType~="Dice" then
            playerBoardScheduleUICleanup(objGUID)
        end
		--Only remove the face-down card decal once the card is confirmed outside all player play areas.
		if obj.type=="Card" then
			local cardGUID=obj.guid
			safeWaitFrames("PlayerBoard.Events",function() local card=getObjectFromGUID(cardGUID) if card~=nil and cardInPlayerPlayArea(cardGUID)==false then removeCardRemoveDecal(card) end end, 2)
		end

		-- Manual play-area scaling restores the object's own natural size on departure.

		safeWaitTime("PlayerBoard.Events",function()
			local live=getObjectFromGUID(objGUID)
			if live~=nil then
				--Toggle half cards when picked up.
				if gameCards[objGUID]~=nil and gameCards[objGUID].full~=nil and live.getPosition()[2]>2 then
					local fullGUID=gameCards[objGUID].full
					live.setState(1)
					safeWaitFrames("PlayerBoard.Events",function()
						local fullCard=getObjectFromGUID(fullGUID)
						if fullCard~=nil then
                        -- A half Banner's face-down state means its attached
                        -- ability was spent, NOT that the full card was broken.
                        -- Reset it on detachment before scanning as a card.
                        if fullCard.is_face_down==true then fullCard.flip() end
                        fullCard.setScale({1.5, 1, 1.5})
                    end
					end, 1)
				end

			end
		end, 0.22)
		--Decrement Master of chaos skill
		if obj.guid==GUID.skill.masterOfChaos and masterOfChaosPause==false then
			if masterOfChaosWait~=nil then Wait.stop(masterOfChaosWait) end
			safeWaitFrames("PlayerBoard.Events",function() masterOfChaosWait=safeWaitCondition("PlayerBoard.Events",function()
				masterOfChaosWait=nil
				local skill=getObjectFromGUID(GUID.skill.masterOfChaos)
				if skill==nil then return end
				for a=1, #turnOrder, 1 do
					if turnOrder[a].masterOfChaos~=nil and turnOrder[a].masterOfChaos~="incremented in turn" and turnOrder[a].masterOfChaos~="used" then turnOrder[a].masterOfChaos="available" break end
				end
				skill.setCustomObject({image=masterOfChaosData[gStates.masterOfChaos].image})
				skill.reload()
			end, function() local skill=getObjectFromGUID(GUID.skill.masterOfChaos) return skill==nil or skill.resting end) end, 5)
		end
	end
	--A Card or whole Deck leaving the deed pile can make End Round available.
	if obj~=nil and (obj.type=="Card" or obj.type=="Deck") then
		for _, details in pairs(turnOrder) do if zone.guid==deedDeckZones[details.seatPos] then scheduleEndRoundDeedStateRefresh(details.seatPos) break end end
	end
	--Updates Main UI buttons when anything is removed from a mages play Area
	if gStates.turnNumber>0 then
		for a=1, #turnOrder, 1 do
			local seatPos=turnOrder[a].seatPos
			if zone.guid==playerPlayAreas[seatPos] then
                if playerBoardPlayAreaAffectsMainUI(obj) then
                    updatePlayAreaObjectState(seatPos,obj,false)
                    mainUIUpdate("Object removed from zone")
                end
				schedulePlayAreaScale(seatPos)
				if unitLayoutIsCommand(obj) then scheduleUnitLayoutRefreshAfterCommandRelease(seatPos,obj.guid) end
				break
			elseif zone.guid==deedDeckDiscardZones[seatPos] then
				mainUIUpdate("Object removed from zone")
				break
			end
		end
	end

	--A monster leaving a Unit Area can change pending fame/reputation just like leaving the Play Area.
	local leftUnitArea=false
	local leftUnitSeat=nil
	for seatPos=1,4 do if zone.guid==playerUnitAreas[seatPos] then leftUnitArea=true leftUnitSeat=seatPos break end end
	if leftUnitArea==true then
		schedulePlayAreaScale(leftUnitSeat)
		if unitLayoutIsCommand(obj) then scheduleUnitLayoutRefreshAfterCommandRelease(leftUnitSeat,obj.guid) else scheduleUnitLayoutRefresh(leftUnitSeat) end
		if unitLayoutIsUnit(obj) then
			local unitGUID=obj.guid
			safeWaitFrames("PlayerBoard.Events",function()
				local unit=getObjectFromGUID(unitGUID)
				if unit~=nil and unitLayoutObjectInAnyUnitArea(unitGUID)==false then unit.setScale({unitLayoutConfig.cardScale,1,unitLayoutConfig.cardScale}) end
			end,2)
		end
	end
	if leftUnitArea==true and monsterPugs[obj.guid]~=nil then
        playerBoardScheduleUICleanup(obj.guid)
        safeWaitFrames("PlayerBoard.Events",function()
            mainUIUpdate("Monster removed from unit area")
        end,2)
	end
end

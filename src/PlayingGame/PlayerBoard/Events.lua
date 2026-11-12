-- Module-private helpers. Predeclared so forward references keep resolving locally.
local removeCardRemoveDecal

-- Crystal visual effects belong to play-area membership, not to the physics-settled
-- path used by positional card/Unit logic. A shallow zone is crossed again when
-- objects are lifted, so invalidate old timers on every boundary transition.
local playAreaCrystalAnimation={}

local function playAreaCrystalCancelTimer(state,key)
    if state[key]~=nil then Wait.stop(state[key]) state[key]=nil end
end

local function playAreaCrystalInZone(guid)
    for _,zoneGUID in pairs(playerPlayAreas or {}) do
        local zone=zoneGUID~=nil and getObjectFromGUID(zoneGUID) or nil
        if zone~=nil then
            for _,candidate in ipairs(zone.getObjects()) do
                if candidate.guid==guid then return true end
            end
        end
    end
    return false
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
    if not isManaTokenFigurine(obj) then return end
    local guid=obj.guid
    local state=playAreaCrystalAnimation[guid]
    if state==nil then state={serial=0} playAreaCrystalAnimation[guid]=state end
    if state.inPlay==true then return end
    state.serial=state.serial+1
    state.inPlay=true
    playAreaCrystalCancelTimer(state,"stopTimer")
    -- Passing through the zone while held is not yet a placement. The
    -- drop callback will play the burst without waiting for physics to rest.
    if obj.held_by_color~=nil then state.awaitingDrop=true
    else playAreaCrystalBurst(obj,state) end
end

function playerBoardCrystalLeftPlayArea(ctx)
    local obj=ctx~=nil and ctx.obj or nil
    if not isManaTokenFigurine(obj) then return end
    local guid=obj.guid
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
        if playAreaCrystalInZone(guid) then return end
        -- Picking up a token is temporary; stop the loop only after it has
        -- actually been dropped outside the play area.
        if live.held_by_color~=nil then return end
        if live.AssetBundle~=nil then live.AssetBundle.playLoopingEffect(0) end
        playAreaCrystalAnimation[guid]=nil
    end,0.22)
end

function playerBoardCrystalDropped(obj)
    if not isManaTokenFigurine(obj) then return end
    local state=playAreaCrystalAnimation[obj.guid]
    if state==nil then return end
    if state.inPlay==true then
        if state.awaitingDrop==true and playAreaCrystalInZone(obj.guid) then
            playAreaCrystalBurst(obj,state)
        end
    elseif obj.held_by_color==nil and not playAreaCrystalInZone(obj.guid) then
        playAreaCrystalCancelTimer(state,"stopTimer")
        if obj.AssetBundle~=nil then obj.AssetBundle.playLoopingEffect(0) end
        playAreaCrystalAnimation[obj.guid]=nil
    end
end

-- Player-board scripting-zone reactions dispatched by PlayingGame.Events.

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
	updatePlayAreaObjectState(seatPos,obj,true)
	playAreaScaleApplyObject(seatPos,obj)
	--The face-down remove image depends only on play-area membership and face state, not final position.
	--Apply it on zone entry so it appears while the card is still falling/sliding into place.
	if obj.type=="Card" and (gameCards[obj.guid]==nil or gameCards[obj.guid].full==nil) then refreshCardRemoveDecal(obj,true) end
	dayTactic2ExpireIfCardPlayed(seatPos)
	schedulePlayAreaScale(seatPos)
	mainUIUpdate("Object entered into play area")
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
			if bannerPosition[3]>=-38.4 then
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
			getObjectFromGUID("ab56f3").takeObject({position={woundX, woundPosition[2], -33.29}, smooth=false})
			obj.destruct()
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
		--remove icons from monsters
		obj.UI.setXmlTable({{}})
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
						if fullCard~=nil then fullCard.setScale({1.5, 1, 1.5}) end
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
				updatePlayAreaObjectState(seatPos, obj, false)
				schedulePlayAreaScale(seatPos)
				if unitLayoutIsCommand(obj) then scheduleUnitLayoutRefreshAfterCommandRelease(seatPos,obj.guid) end
				mainUIUpdate("Object removed from zone")
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
		local monsterGUID=obj.guid
		safeWaitFrames("PlayerBoard.Events",function()
			local monster=getObjectFromGUID(monsterGUID)
			if monster~=nil and objectInPlayerCombatArea(monsterGUID)==false then monster.UI.setXmlTable({{}}) end
			mainUIUpdate("Monster removed from unit area")
		end, 2)
	end
end

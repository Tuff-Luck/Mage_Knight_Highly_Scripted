-- Player-board scripting-zone reactions dispatched by PlayingGame.Events.

local crystalManaNames={["Red Mana"]=true,["Green Mana"]=true,["Blue Mana"]=true,["White Mana"]=true,["Black Mana"]=true,["Gold Mana"]=true}

--Face-down cards in a player play area get a physical decal instead of Object UI.
local cardRemoveDecalURL="https://steamusercontent-a.akamaihd.net/ugc/1661232230977162756/90D8AEB60005119DD4182B5FD24D7BDD8243B5F3/"
function cardInPlayerPlayArea(cardGUID)
	for a=1, 4 do
		local zone=getObjectFromGUID(playerPlayAreas[a])
		if zone~=nil then for _, card in pairs(zone.getObjects()) do if card.guid==cardGUID then return true end end end
	end
	return false
end
function removeCardRemoveDecal(card)
	if card==nil then return end
	local decals={}
	local changed=false
	for _, decal in pairs(card.getDecals() or {}) do
		if decal.name=="Card Remove" then changed=true else decals[#decals+1]=decal end
	end
	if changed==true then card.setDecals(decals) end
end
function refreshCardRemoveDecal(card)
	if card==nil or card.type~="Card" or not (gameCards[card.guid]==nil or gameCards[card.guid].full==nil) then return end
	removeCardRemoveDecal(card)
	if card.is_face_down==true and cardInPlayerPlayArea(card.guid)==true then
		--Face-down cards are rotated over, so put the decal on the card's local underside.
		card.addDecal({name="Card Remove", url=cardRemoveDecalURL, position={0,-0.5,0}, rotation={270,180,180}, scale={1.7,2.0,1}})
	end
end

function playerBoardZoneEnterSettled(ctx)
	local zone=ctx.zone
	local obj=ctx.obj
	local zoneGUID=ctx.zoneGUID
	local objGUID=ctx.objGUID
	local zoneInfo=ctx.zoneInfo
	local objType=ctx.objType
	--Updates Main UI buttons when anything is played to a mage's play area/deed deck/discard.
	--Keep play-area refreshes distinct so mainUIUpdate can skip deck bookkeeping that cannot have changed.
	if gStates.turnNumber>0 then--makes sure end of round doesn't have errors
		if zoneInfo~=nil and (zoneInfo.kind=="play" or zoneInfo.kind=="deed" or zoneInfo.kind=="discard") and turnOrderIndexAtSeat(zoneInfo.seatPos)~=nil then
			local seatPos=zoneInfo.seatPos
			if zoneInfo.kind=="deed" and (objType=="Card" or objType=="Deck") then
				if objType=="Deck" then obj.max_typed_number=1 end
				scheduleEndRoundDeedStateRefresh(seatPos)
			end
			--remove banner card from register if returned to deck.
			if zoneInfo.kind=="discard" and gameCards[objGUID]~=nil and gameCards[objGUID].half~=nil then gStates.bannercard[gameCards[objGUID].half]=nil end
			if zoneInfo.kind=="play" then
				updatePlayAreaObjectState(seatPos, obj, true)
				dayTactic2ExpireIfCardPlayed(seatPos)
				schedulePlayAreaCardScale(seatPos)
				mainUIUpdate("Object entered into play area")
			else mainUIUpdate("Object entered into deed deck or discard") end
		end
	end

	--Object entered player board
	if zoneInfo~=nil and zoneInfo.kind=="play" then
		--increment Master of chaos skill
		if objGUID=="1ff34f" then
			if masterOfChaosPause==false then
				masterOfChaosPause=true
				if masterOfChaosWait~=nil then Wait.stop(masterOfChaosWait) end
				local temp=gStates.masterOfChaos+1
				if temp==7 then temp=1 end
				obj.setCustomObject({image=masterOfChaosData[temp].image})
				for a=1, #turnOrder, 1 do
					if turnOrder[a].masterOfChaos~=nil then turnOrder[a].masterOfChaos="used" break end
				end
				--Wait.frames(function()
				obj.reload()
				--end, 50)
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
			local mapObjects=getObjectFromGUID(mapArea).getObjects()
			local terTile, monsterhexBearing=terrainHexAtPosition(target, mapObjects)
			if terTile~=nil and monsterhexBearing~=nil and gStates.volkareState~=nil and gStates.volkareState:sub(1, 9)~="Attacking" then

				--fortified for Volkare's Army
				if attackingVolkare==true and monsterPugs[objGUID].unfortified==nil and (terrainTiles[terTile.guid].hexFeature[monsterhexBearing]=="mage tower" or terrainTiles[terTile.guid].hexFeature[monsterhexBearing]=="keep") then
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

		--Add/remove the Card Remove decal when a normal card enters the player play area.
		if objType=="Card" and (gameCards[objGUID]==nil or gameCards[objGUID].full==nil) then
			safeWaitFrames("PlayerBoard.Events",function() local card=getObjectFromGUID(objGUID) if card~=nil then refreshCardRemoveDecal(card) end end, 2)
		end

		--Add command decal to banner of Command
		if objGUID=="8dbce4" then
			bannerOfCommandDecal()
			scheduleUnitLayoutRefresh(zoneInfo.seatPos)
		end

		--if object is a crystal then alter it's animation.
		if crystalManaNames[obj.getName()]==true then
			safeWaitTime("PlayerBoard.Events",function() if getObjectFromGUID(objGUID)~=nil then obj.AssetBundle.playTriggerEffect(0) end end, 0.1)
			safeWaitTime("PlayerBoard.Events",function() if getObjectFromGUID(objGUID)~=nil then obj.AssetBundle.playLoopingEffect(1) end end, 1)
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

        --flip ruin down if one of its monsters is Down
        if gStates.ruinMonsters~=nil and gStates.ruinMonsters[objGUID]~=nil then
            local ruinObj=getObjectFromGUID(gStates.ruinMonsters[objGUID])
            if ruinObj==nil then
                --The monster token has been reused after its Ruin was removed; discard the stale link.
                gStates.ruinMonsters[objGUID]=nil
            elseif obj.is_face_down==true then
                if ruinObj.is_face_down==false then ruinObj.flip() end
            else
                local flip=true
                for monsterGUID, _ in pairs(gStates.ruinMonsters) do
                    local monsterObj=getObjectFromGUID(monsterGUID)
                    if monsterObj~=nil and monsterObj.is_face_down==true then flip=false break end
                end
                if flip==true and ruinObj.is_face_down==true then ruinObj.flip() end
            end
        end

	--record potion return locationTest
	if zoneInfo~=nil and zoneInfo.kind=="crystal" and obj.getName():reverse():sub(1, 6)=="noitoP" then
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

		--restore card size, except Unit cards still owned by the overlapping Unit Area layout.
		if ((gameCards[obj.guid]~=nil and gameCards[obj.guid].full==nil) or obj.getGMNotes()=="Wound")
			and not (unitLayoutIsUnit(obj) and unitLayoutObjectInAnyUnitArea(obj.guid)) then obj.setScale({1.5,1,1.5}) end

		safeWaitTime("PlayerBoard.Events",function()
			--Toggle half cards when picked up.
			if getObjectFromGUID(obj.guid)~=nil then
				if gameCards[obj.guid]~=nil and gameCards[obj.guid].full~=nil and obj.getPosition()[2]>2 then
					obj.setState(1)
					safeWaitFrames("PlayerBoard.Events",function() if getObjectFromGUID(gameCards[obj.guid].full)~=nil then getObjectFromGUID(gameCards[obj.guid].full).setScale({1.5, 1, 1.5}) end end, 1)
				end

				--if object is a crystal then remove highlight.
				local crystalGlow={["Red Mana"]={1, 0, 0}, ["Green Mana"]={0, 1, 0}, ["Blue Mana"]={0, 0, 1}, ["White Mana"]={1, 1, 1}, ["Black Mana"]={0.3, 0.0, 0.6}, ["Gold Mana"]={1, 0.9, 0}}
				if crystalGlow[obj.getName()]~=nil then
					obj.AssetBundle.playLoopingEffect(0)
				end
			end
		end, 0.22)
		--Decrement Master of chaos skill
		if obj.guid=="1ff34f" and masterOfChaosPause==false then
			if masterOfChaosWait~=nil then Wait.stop(masterOfChaosWait) end
			safeWaitFrames("PlayerBoard.Events",function() masterOfChaosWait=safeWaitCondition("PlayerBoard.Events",function()
				for a=1, #turnOrder, 1 do
					if turnOrder[a].masterOfChaos~=nil and turnOrder[a].masterOfChaos~="incrementented in turn" then turnOrder[a].masterOfChaos="available" break end
				end
				getObjectFromGUID("1ff34f").setCustomObject({image=masterOfChaosData[gStates.masterOfChaos].image})
				getObjectFromGUID("1ff34f").reload()
				masterOfChaosWait=nil
			end, function() return getObjectFromGUID("1ff34f").resting end) end, 5)
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
				schedulePlayAreaCardScale(seatPos)
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

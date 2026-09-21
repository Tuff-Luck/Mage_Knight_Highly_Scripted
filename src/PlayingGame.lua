-- Runtime game systems, event handling, gameplay UI, state, scoring and callbacks.

------------------
-- During the Game
------------------
local gladeDiscardHealButtonGUID=nil

function removeGladeDiscardHealButton(obj)
	if obj==nil then return end
	local remove={}
	for _, button in pairs(obj.getButtons() or {}) do if button.click_function=="gladeDiscardHeal" then remove[#remove+1]=button.index end end
	table.sort(remove, function(a,b) return a>b end)
	for _, index in ipairs(remove) do obj.removeButton(index) end
	local xml=obj.UI.getXmlTable() or {}
	local changed=false
	for i=#xml, 1, -1 do
		if xml[i].attributes~=nil and xml[i].attributes.id=="GladeDiscardHealButton" then table.remove(xml, i) changed=true end
	end
	if changed==true then
		if #xml>0 then obj.UI.setXmlTable(xml) else obj.UI.setXmlTable({{}}) end
	end
end
local function clearGladeDiscardHealButtons()
	if gladeDiscardHealButtonGUID~=nil then removeGladeDiscardHealButton(getObjectFromGUID(gladeDiscardHealButtonGUID)) gladeDiscardHealButtonGUID=nil end
	for _, details in pairs(turnOrder or {}) do
		if details.seatPos~=nil then
			local zone=getObjectFromGUID(deedDeckDiscardZones[details.seatPos])
			if zone~=nil then for _, obj in pairs(zone.getObjects()) do removeGladeDiscardHealButton(obj) end end
		end
	end
end
local function gladeDiscardWound(playerIndex)
	local details=turnOrder[playerIndex]
	local zone=details~=nil and getObjectFromGUID(deedDeckDiscardZones[details.seatPos]) or nil
	if zone==nil then return nil, nil end
	for _, obj in pairs(zone.getObjects()) do
		if obj.type=="Card" and obj.getGMNotes()=="Wound" then return obj, obj.guid end
		if obj.type=="Deck" then
			for _, data in pairs(obj.getObjects()) do if data.gm_notes=="Wound" then return obj, data.guid end end
		end
	end
	return nil, nil
end
function refreshGladeDiscardHealButton()
	clearGladeDiscardHealButtons()
	local playerIndex=gStates.turnNumber
	local details=turnOrder[playerIndex]
	if details==nil or details.mage==gStates.positionMageKnight[5] or playerDropoutInactive(playerIndex)==true then return end
	if gStates.preEndTurn~=true or gStates.coopAssaultPhase=="combat" or gameOver==true or UI.getAttribute("RewardCheck", "active")~="true" then return end
	if details.avatarLocation~="glade" and not (gStates.gameScenario=="The Hidden Valley Blitz" and details.avatarLocation=="hidden valley") then return end
	if gladeFreeCheck()~=true then return end
	if gStates.gladeDiscardHealUsed==nil then gStates.gladeDiscardHealUsed={} end
	if gStates.gladeDiscardHealUsed[details.seatPos]==true then return end
	local discardObj=gladeDiscardWound(playerIndex)
	if discardObj==nil then return end
	removeGladeDiscardHealButton(discardObj)
	local xml=discardObj.UI.getXmlTable() or {}
	xml[#xml+1]={tag="Button", attributes={id="GladeDiscardHealButton", onClick="global/gladeDiscardHealUI", width=100, height=100, position="0 0 -100", rotation="0 0 0", colors="#00000000|#00000000|#00000000|#00000000"},
		children={{tag="Image", attributes={image="Glade Heal Button", width=100, height=100, rotation="0 0 180", preserveAspect="true"}}}}
	discardObj.UI.setXmlTable(xml)
	gladeDiscardHealButtonGUID=discardObj.guid
end
function gladeDiscardHealUI(player, value, id)
	local obj=gladeDiscardHealButtonGUID~=nil and getObjectFromGUID(gladeDiscardHealButtonGUID) or nil
	if obj~=nil and player~=nil then gladeDiscardHeal(obj, player.color, false) end
end
function gladeDiscardHeal(obj, playerColor, altClick)
	local playerIndex=gStates.turnNumber
	local details=turnOrder[playerIndex]
	if details==nil or legalPlayerCheck(playerColor, details.seatPos)~=true then return end
	if gStates.preEndTurn~=true or gStates.coopAssaultPhase=="combat" or gameOver==true or UI.getAttribute("RewardCheck", "active")~="true" or
		(details.avatarLocation~="glade" and not (gStates.gameScenario=="The Hidden Valley Blitz" and details.avatarLocation=="hidden valley")) or gladeFreeCheck()~=true then refreshGladeDiscardHealButton() return end
	if gStates.gladeDiscardHealUsed==nil then gStates.gladeDiscardHealUsed={} end
	if gStates.gladeDiscardHealUsed[details.seatPos]==true then refreshGladeDiscardHealButton() return end
	local source, woundGUID=gladeDiscardWound(playerIndex)
	if source==nil or woundGUID==nil then refreshGladeDiscardHealButton() return end
	gStates.gladeDiscardHealUsed[details.seatPos]=true
	clearGladeDiscardHealButtons()
	local playArea=getObjectFromGUID(playerPlayAreas[details.seatPos])
	local pos=playArea~=nil and playArea.getPosition() or {(details.seatPos*40)-100,1.5,-39.4}
	local destination={pos[1],2.7,pos[3]}
	local function finishHeal(wound)
		if wound==nil then return end
		wound.setScale({1.5,1,1.5})
	end
	if source.type=="Deck" then
		safeTakeObject("PlayingGame",source,{guid=woundGUID, position=destination, rotation={0,180,0}, smooth=true, callback_function=finishHeal})
	else
		source.setScale({1.5,1,1.5})
		source.setRotationSmooth({0,180,0})
		source.setPositionSmooth(destination)
		finishHeal(source)
	end
end

function portalSwap(state, playerIndex)
	playerIndex=playerIndex or gStates.turnNumber
	local player=turnOrder[playerIndex]
	--There is no Portal map hex in Against the Horsemen. Normalize any setup Portal state
	--to the shared central Glade before deciding where the active avatar belongs. Also remember when a
	--Mage Knight was deliberately parked from that Glade so later callbacks cannot lose the logical hex.
	if player~=nil and gStates.gameScenario=="Against the Horsemen Blitz" and gStates.againstHorsemenRitualStarted~=true then
		if player.avatarLocation=="portal" or (state=="startOfTurn" and player.horsemenGladeParked==true) then
			player.avatarLocation="glade"
			player.avatarSharedHex=againstHorsemenSharedHexKey
		end
	end
	local horsemenGlade=againstHorsemenPlayerAtCentralGlade(player) and gStates.againstHorsemenRitualStarted~=true
	if player==nil or player.avatarLocation==nil or (player.avatarLocation~="portal" and player.avatarLocation:sub(1, 4)~="city" and horsemenGlade~=true) or gStates.gameScenario=="The Lost Relic Blitz" then return end
	--A closed Portal is an ordinary single-occupancy map hex. City avatar swapping remains unchanged.
	local portalClosed=(gStates.gameScenario=="Volkare's Quest" and gStates.volkarePortalClosed==true) or
		(gStates.gameScenario=="One to Return" and gStates.oneToReturnPortalClosed==true)
	if player.avatarLocation=="portal" and portalClosed==true then return end
	local portalPosition={{-45.5, 1.1, -11.4}, {-42.5, 1.1, -11.4}, {-45.5, 1.1, -13.2}, {-42.5, 1.1, -13.2}}
	local cityConvert={["red"]=cityModel.red, ["whi"]=cityModel.white, ["blu"]=cityModel.blue, ["gre"]=cityModel.green}
	local isProxy=proxyPlayerActive()==true and player.mage==gStates.positionMageKnight[5]
	local parkingSeat=isProxy==true and gStates.proxyParkingSeat or player.seatPos

	local function dummyBoardParking()
		local board=getObjectFromGUID(dummyBoard)
		if board~=nil then local p=board.getPosition() return {p[1],1.4,p[3]} end
		return {-43.94,1.4,-12.36}
	end

	local function portalParking(index)
		local details=turnOrder[index]
		if details==nil then return nil end
		if proxyPlayerActive()==true and details.mage==gStates.positionMageKnight[5] then
			local seat=gStates.proxyParkingSeat
			return seat~=nil and portalPosition[seat] or dummyBoardParking()
		end
		return portalPosition[details.seatPos]
	end

	local function moveAvatar(index, destination)
		if turnOrder[index]==nil or destination==nil then return end
		for _, details in pairs(mageKnights) do
			if details.mage==turnOrder[index].mage then
				if getObjectFromGUID(details.model)~=nil then getObjectFromGUID(details.model).setPositionSmooth(destination) end
				if getObjectFromGUID(details.token)~=nil then getObjectFromGUID(details.token).setPositionSmooth(destination) end
				if getObjectFromGUID(details.standee)~=nil then getObjectFromGUID(details.standee).setPositionSmooth(destination) end
				break
			end
		end
	end

	local avatarDestination={-24.03, 1.11, -16.08}--fallback wedge portal hex location
	local startTile=getObjectFromGUID(startTerrain.wedge) or getObjectFromGUID(startTerrain.open)
	if startTile~=nil then
		local startPos=startTile.getPosition()
		avatarDestination={startPos[1],1.11,startPos[3]}
	end
	if state=="startOfTurn" then
		if player.avatarLocation=="portal" then
			--Only the active Mage Knight belongs on the physical portal hex. Park every other
			--portal Mage Knight on their own portal-card slot (or the Dummy board for a 4-player Proxy).
			for otherIndex, other in pairs(turnOrder) do
				if otherIndex~=playerIndex and other.avatarLocation=="portal" then moveAvatar(otherIndex,portalParking(otherIndex)) end
			end
		elseif horsemenGlade==true then
			--Country01's centre is a shared space in this scenario. Inactive occupants remain parked
			--on the Portal card; only the active Mage Knight is represented on the Glade itself.
			for otherIndex, other in pairs(turnOrder) do
				if otherIndex~=playerIndex and againstHorsemenPlayerAtCentralGlade(other)==true then
					other.horsemenGladeParked=true
					moveAvatar(otherIndex,portalParking(otherIndex))
				end
			end
			avatarDestination=againstHorsemenCentralGladePosition(1.5)
			if avatarDestination==nil then return end
			player.horsemenGladeParked=false
		else
			local cityObj=getObjectFromGUID(cityConvert[player.avatarLocation:sub(6, 8)])
			if cityObj==nil then return end
			avatarDestination=cityObj.getPosition()
			if player.avatarSwapCity~=nil and getObjectFromGUID(player.avatarSwapCity)~=nil then avatarDestination=getObjectFromGUID(player.avatarSwapCity).getPosition() end
			avatarDestination[2]=avatarDestination[2]+2
		end
		player.avatarSwapCity=nil
	else
		local parkedPosition=portalParking(playerIndex)
		if parkedPosition==nil then return end
		avatarDestination=parkedPosition
		if horsemenGlade==true then player.horsemenGladeParked=true end
		if player.avatarLocation:sub(1, 4)=="city" then
			local cityGUID=cityConvert[player.avatarLocation:sub(6, 8)]
			local cardGUID=gStates.cityCard[cityGUID]
			local cityCard=cardGUID~=nil and getObjectFromGUID(cardGUID) or nil
			if cityCard==nil then return end
			if isProxy==true and parkingSeat==nil then
				--Four human players already occupy every normal City-card parking slot.
				avatarDestination=dummyBoardParking()
			else
				avatarDestination=cityCard.getPosition()
				local seat=parkingSeat or player.seatPos
				avatarDestination[1]=(avatarDestination[1]+(seat*1.83))-4.58
				avatarDestination[2]=avatarDestination[2]+1
				avatarDestination[3]=avatarDestination[3]-0.66
			end
			player.avatarSwapCity=cityGUID
		end
	end
	moveAvatar(playerIndex, avatarDestination)
end

--Physical activation state is kept separately from doingTheRounds. Tome/Circlet can move a real token
--after it has been played, while the effect that token created may still need to survive.
function dropShield(location, lockToken, rotation)
	for a, details in pairs(mageKnights) do
		if details.mage==turnOrder[gStates.turnNumber].mage then
			local shield=getObjectFromGUID(details.shieldContainer).takeObject({position=location, rotation=rotation, smooth=false})
			if lockToken==true then
				safeWaitTime("PlayingGame",function() safeWaitCondition("PlayingGame",function()
					shield.lock()
				end, function() return shield.resting end) end, 1.5)
			end
			UI.setAttribute("PreEndTurn", "interactable", "false")
			UI.setAttribute("PreEndTurnImage", "image", "Sliced Button/Button New Deactive")
			safeWaitTime("PlayingGame",function()
				UI.setAttribute("PreEndTurn", "interactable", "true")
				UI.setAttribute("PreEndTurnImage", "image", "Sliced Button/Button New Active")
			end, 2.1)
			break
		end
	end
end

--Coral's Tales skills collect a shield when Coral marks the matching type of site.
function coralTalesSiteShield(siteType)
	local playerDetails=turnOrder[gStates.turnNumber]
	if playerDetails==nil or playerDetails.mage~="Coral" then return end
	local adventureSites={['monster den']=true, ['spawning grounds']=true, maze=true, labyrinth=true, ruin=true, dungeon=true, tomb=true, ziggurat=true, pyramid=true}
	local skillGUID=nil
	if adventureSites[siteType]==true then skillGUID="9cf272"--Tales of Adventure
	elseif siteType=="keep" or siteType=="mage tower" then skillGUID="de5b04" end--Tales of Conquest
	if skillGUID==nil then return end
	local skill=getObjectFromGUID(skillGUID)
	local recordedPos=gStates.mageSkills~=nil and gStates.mageSkills[skillGUID] or nil
	if skill==nil or recordedPos==nil then return end
	--Claimed skills live in the owner's skill column; communal/pool skills are recorded elsewhere.
	local claimedX=(playerDetails.seatPos*40)-107.45
	if math.abs(recordedPos[1]-claimedX)>2 or recordedPos[3]>-35 then return end
	local shieldContainer=nil
	for _, details in pairs(mageKnights) do if details.mage=="Coral" then shieldContainer=getObjectFromGUID(details.shieldContainer) break end end
	if shieldContainer==nil then return end
	local location=skill.getPosition()
	local snapPoints=skill.getSnapPoints()
	if snapPoints~=nil and snapPoints[1]~=nil then location=skill.positionToWorld(snapPoints[1].position) end
	--Drop above the snap point so the first shield snaps to the skill and later shields can stack naturally.
	location={location[1], skill.getPosition()[2]+2.5, location[3]}
	shieldContainer.takeObject({position=location, rotation={0, skill.getRotation()[2], 0}, smooth=false})
end

--Claim the Skill reserved by Hero Challenges. higherLevel=true mirrors the Start-at-Higher-Level
--Bonds of Loyalty setup rather than adding cards to the live Unit Offer.
function layoutClaimedCards()
	--A Time Bending set aside on the victorious final round still belongs to its owner and must be present for scoring.
	if gStates~=nil and gStates.timeBendingRemovedSeat~=nil then if reclaimTimeBending(layoutClaimedCards)==true then return end end
	--Never dismantle live deed decks/hands while the active turn is still waiting
	--for Rewards Claimed. The final boundary must be crossed first.
	if gStates~=nil and gStates.preEndTurn==true then
		log("layoutClaimedCards ignored: Rewards Claimed is still pending.")
		return
	end
	--Score the untouched deck/discard/hand/play-area state before dismantling Deck objects.
	--TTS zone membership can lag behind takeObject/setPosition by a frame, and Deck remainders below
	--are deliberately moved later, so scoring after the layout could temporarily miss claimed cards.
	displayScore("all", "-1", nil)
	for _, turnDetails in pairs(turnOrder) do
		if turnDetails.mage~=gStates.positionMageKnight[5] then
			--UI.setAttribute("PreEndTurn", "interactable", "False")
			--UI.setAttribute("PreEndTurnImage", "image", "Sliced Button/Button New Deactive")
			local obj={}
			local OffsetX={["Advanced Action"]=0, ["Spell"]=0, ["Artifact"]=0, ["Wound"]=0}
			local OffsetY={["Advanced Action"]=0, ["Spell"]=0, ["Artifact"]=0, ["Wound"]=0}
			local OffsetZ={["Advanced Action"]=0, ["Spell"]=0, ["Artifact"]=0, ["Wound"]=0}
			local OffsetStart={["Advanced Action"]=-97, ["Spell"]=-91, ["Artifact"]=-85, ["Wound"]=-103}
			local xOffset=0.4
			local yOffset=0.04
			local zOffset=0.8
			--Look for Cards
			for _, c in pairs(getObjectFromGUID(deedDeckZones[turnDetails.seatPos]).getObjects()) do obj[#obj+1]=c end
			for _, c in pairs(getObjectFromGUID(deedDeckDiscardZones[turnDetails.seatPos]).getObjects()) do obj[#obj+1]=c end
			for _, c in pairs(getObjectFromGUID(handZones[turnDetails.seatPos]).getObjects()) do obj[#obj+1]=c end
			for _, c in pairs(obj) do
				if c.type=="Deck" then
					for _, card in pairs(c.getObjects()) do
						if c.remainder~=nil and (card.gm_notes=="Advanced Action" or card.gm_notes=="Spell" or card.gm_notes=="Artifact" or card.gm_notes=="Wound") then
							local lastCard=c.remainder
							safeWaitFrames("PlayingGame",function()
								lastCard.setPosition({(turnDetails.seatPos*40)+OffsetStart[card.gm_notes]+OffsetX[card.gm_notes], 1.1+OffsetY[card.gm_notes], -39.4-OffsetZ[card.gm_notes]})
								OffsetX[card.gm_notes]=OffsetX[card.gm_notes]+xOffset
								OffsetY[card.gm_notes]=OffsetY[card.gm_notes]+yOffset
								OffsetZ[card.gm_notes]=OffsetZ[card.gm_notes]+zOffset
								if OffsetZ[card.gm_notes]>4.8 then OffsetZ[card.gm_notes]=0 end
							end, 10)
							break
						end
						if card.gm_notes=="Advanced Action" or card.gm_notes=="Spell" or card.gm_notes=="Artifact" or card.gm_notes=="Wound" then
							c.takeObject({position={(turnDetails.seatPos*40)+OffsetStart[card.gm_notes]+OffsetX[card.gm_notes], 1.1+OffsetY[card.gm_notes], -39.4-OffsetZ[card.gm_notes]}, rotation={0, 180, 0}, guid=card.guid, smooth=false})
							OffsetX[card.gm_notes]=OffsetX[card.gm_notes]+xOffset
							OffsetY[card.gm_notes]=OffsetY[card.gm_notes]+yOffset
							OffsetZ[card.gm_notes]=OffsetZ[card.gm_notes]+zOffset
							if OffsetZ[card.gm_notes]>4.8 then OffsetZ[card.gm_notes]=0 end
						end
					end
				end
				if c.type=="Card" and (c.getGMNotes()=="Advanced Action" or c.getGMNotes()=="Spell" or c.getGMNotes()=="Artifact" or c.getGMNotes()=="Wound") then
					c.setPosition({(turnDetails.seatPos*40)+OffsetStart[c.getGMNotes()]+OffsetX[c.getGMNotes()], 1.1+OffsetY[c.getGMNotes()], -39.4-OffsetZ[c.getGMNotes()]})
					OffsetX[c.getGMNotes()]=OffsetX[c.getGMNotes()]+xOffset
					OffsetY[c.getGMNotes()]=OffsetY[c.getGMNotes()]+yOffset
					OffsetZ[c.getGMNotes()]=OffsetZ[c.getGMNotes()]+zOffset
					if OffsetZ[c.getGMNotes()]>4.8 then OffsetZ[c.getGMNotes()]=0 end
				end
			end
		end
	end
end

--Swap Day and Night items
function nightTint(player, mouseButton, id)
	if mouseButton=="-1" then
		local tileColor={}
		if getObjectFromGUID("43fa2e").UI.getAttribute("43fa2eNightTintText", "text")=="No Tint" then
			getObjectFromGUID("43fa2e").UI.setAttribute("43fa2eNightTintText", "text", "{en}Add Tint{ru}Добавить оттенок{zh-tw}加入色調{zh-cn}加入色调{ko}색조 추가{es}Añadir Tinte{fr}Ajouter une Teinte{pt-br}Adicionar Tonalidade{de}Tönung hinzufügen")
			tileColor={r=1.0, g=1.0, b=1.0}
			gStates.nightTint=false
		else
			getObjectFromGUID("43fa2e").UI.setAttribute("43fa2eNightTintText", "text", "{en}No Tint{ru}Без оттенка{zh-tw}無色調{zh-cn}无色调{ko}색조 없음{es}Sin Tinte{fr}Sans Teinte{pt-br}Sem Tonalidade{de}Keine Tönung")
			tileColor={r=0.6, g=0.6, b=0.6}
			gStates.nightTint=true
		end
		--Make terrain tile light or dark
		for a, _ in pairs(terrainTiles) do
			local obj=getObjectFromGUID(a)
			if obj~=nil then obj.setColorTint(tileColor) end
		end
		if gStates.mapShape:sub(5,5)=="P" and gStates.gameScenario~="The Gauntlet" and gStates.gameScenario~="Against the Horsemen Blitz" then
			local terrainDummy=getObjectFromGUID(startTerrain.open)
			if terrainDummy==nil then terrainDummy=getObjectFromGUID(startTerrain.wedge) end
			onObjectEnterZone({guid=mapArea}, terrainDummy)
		end
	end
end

function shieldLocation(obj, zone, status)
	if volkarePursuitShieldRegistered(obj)==true then return end
	if zone.guid==mapArea then
		local objectsInPlay=nil
		if getObjectFromGUID(mapArea)~=nil then objectsInPlay=getObjectFromGUID(mapArea).getObjects() end
		if objectsInPlay~=nil then
			table.sort(objectsInPlay, function (k1, k2) return k1.getPosition()[2]<k2.getPosition()[2] end)
			local shieldPos=obj.getPosition()
			local terTile, bearing, _, hexFeature=terrainHexAtPosition(shieldPos, objectsInPlay)
			local secretPlacement=gStates.dungeonLordsSecretSiteOrigins~=nil and gStates.dungeonLordsSecretSiteOrigins[obj.guid] or nil
			if status=="remove" and secretPlacement~=nil and secretPlacement.destinationTerrainGUID~=nil and secretPlacement.destinationBearing~=nil then
				local recordedTerrain=getObjectFromGUID(secretPlacement.destinationTerrainGUID)
				if recordedTerrain~=nil and terrainTiles[recordedTerrain.guid]~=nil then
					terTile=recordedTerrain
					bearing=tostring(secretPlacement.destinationBearing)
					hexFeature=terrainTiles[recordedTerrain.guid].hexFeature[bearing]
				end
			end
			if terTile~=nil and bearing~=nil then
				local hexLocation=bearing
				if obj.getName()=="Secret Dungeon" or obj.getName()=="Secret Tomb" then
					dungeonLordsHandleSecretSiteToken(obj,status,terTile,bearing,hexFeature)
					addAvatarButtons()
					return
				end
				local found=false
				for b, mageSearch in pairs(turnOrder) do
					if mageSearch.mage==obj.getDescription() or obj.getGMNotes()=="Burned Monastery" then
						found=true
						if status=="remove" then
							if hexFeature=="keep" and obj.getGMNotes()~="Burned Monastery" then
								broadcastToAll("{en}Keep Released{ru}Крепость освобождена{zh-tw}保持释放{zh-cn}保持释放{ko}성 정복 해제됨{es}Mantener Liberado{fr}Garder Libéré{pt-br}Forte Liberado{de}Behalten freigelassen", positionToColor(b))
								mageSearch.keepsBeat=mageSearch.keepsBeat-1
								fakeDropAvatar()
							end
							if hexFeature=="monastery" and gStates.monasteryBurned[terTile.guid]==true then
								if gStates.monasteryBurnedBy~=nil then gStates.monasteryBurnedBy[terTile.guid]=nil end
								broadcastToAll("{en}Monastery got Repaired, somehow?{ru}Монастырь как-то починился... Магия, не иначе!{zh-tw}修道院被复原了{zh-cn}修道院被复原了{ko}수도원이 복구되었습니다, 띠용?{es}Monasterio quedó Reparado, de alguna manera?{fr}Le Monastère a été réparé, d'une manière ou d'une autre ?{pt-br}Monastério Reparado, de alguma forma?{de}Kloster wurde repariert, irgendwie?", positionToColor(b))
								gStates.monasteryCount=gStates.monasteryCount+1
								gStates.monasteryBurned[terTile.guid]=false
							end
							if hexFeature=="glade" and obj.getGMNotes()~="Burned Monastery" and (gStates.gameScenario=="Druid Nights" or gStates.gameScenario=="Life and Death") then
								broadcastToAll("{en}Glade Deactivated{ru}Магическая поляна деактивирована{zh-tw}林地解除了{zh-cn}林地解除了{ko}숲속 빈터 비활성화{es}Glade Desactivado{fr}Clairière Désactivée{pt-br}Clareira Desativada{de}Lichtung Deaktiviert", positionToColor(b))
								if gStates.gameScenario=="Druid Nights" then
									for index, shields in pairs(mageSearch.gladesMarked) do
										if shields==obj.guid then table.remove(mageSearch.gladesMarked, index) end
									end
								end
							end
							if hexFeature=="graveyard" and obj.getGMNotes()~="Burned Monastery" then
								if gStates.gameScenario=="The Realm of the Dead Blitz" then
									broadcastToAll("{en}Graveyard Unsealed{ru}Кладбище распечатано{zh-tw}墓地解封了{zh-cn}墓地解封了{ko}봉인되지 않은 묘지{es}Cementerio Sin Sellar{fr}Cimetière Non Scellé{pt-br}Cemitério Não Selado{de}Friedhof Unversiegelt", positionToColor(b))
								else
									broadcastToAll("{en}Graveyard Deactivated{ru}Кладбище деактивировано{zh-tw}墓地停用了{zh-cn}墓地停用了{ko}묘지 비활성화{es}Cementerio Desactivado{fr}Cimetière Désactivé{pt-br}Cemitério Desativado{de}Friedhof Deaktiviert", positionToColor(b))
								end
							end
							if hexFeature=="mine" and obj.getGMNotes()~="Burned Monastery" and gStates.gameScenario=="Mines Liberation" then
								broadcastToAll("{en}Mine Undone{ru}Шахта больше не побеждена{zh-tw}矿山未解放{zh-cn}矿山未解放{ko}광산 해방 해제됨{es}Mina Deshecha{fr}Mine Défaite{pt-br}Mina Desfeita{de}Mine rückgängig gemacht", positionToColor(b))
							end
							if hexFeature=="mage tower" and obj.getGMNotes()~="Burned Monastery" then
								broadcastToAll("{en}Mage Tower Released{ru}Башня магов освобождена{zh-tw}法师塔释放{zh-cn}法师塔释放{ko}마법사의 탑 정복 해제됨{es}Lanzamiento de la Torre de Magos{fr}Sortie de la Tour des Mages{pt-br}Torre do Mago Liberada{de}Magierturm befreit", positionToColor(b))
							end
							if (hexFeature=="monster den" or hexFeature=="spawning grounds" or hexFeature=="maze" or hexFeature=="labyrinth" or hexFeature=="ruin" or hexFeature=="dungeon" or hexFeature=="tomb" or hexFeature=="ziggurat" or hexFeature=="pyramid") and obj.getGMNotes()~="Burned Monastery" then
								broadcastToAll("{en}Adventure Site Undone{ru}Место для приключений больше не побеждено{zh-tw}冒险地点未击败{zh-cn}冒险地点未击败{ko}모험 장소 정복 해제됨{es}Sitio de Aventuras Deshecho{fr}Site d'Aventure Annulé{pt-br}Lugar de Aventura Desfeito{de}Abenteuerseite rückgängig gemacht", positionToColor(b))
							end
							if (hexFeature or ""):sub(1, 4)=="city" and obj.getGMNotes()~="Burned Monastery" and gStates.gameScenario=="The Lost Relic Blitz" then
								broadcastToAll("{en}Relic Piece Replaced{ru}Часть древней реликвии была заменена{zh-tw}圣物碎片重置了{zh-cn}圣物碎片重置了{ko}유물 조각 교체됨{es}Pieza de Reliquia Reemplazada{fr}Pièce de Relique Remplacée{pt-br}Pedaço da Relíquia Substituído{de}Reliktteil ausgetauscht", positionToColor(b))
							end
							break
						else
							if (hexFeature=="keep" or hexFeature=="mage tower") and obj.getGMNotes()~="Burned Monastery" then
								if gStates.apocalypseQuestConqueredThisTurn==nil then gStates.apocalypseQuestConqueredThisTurn={} end
								gStates.apocalypseQuestConqueredThisTurn[mageSearch.mage]={serial=gStates.apocalypseQuestTurnSerial or 0, terrainGUID=terTile.guid, bearing=hexLocation, feature=hexFeature}
								apocalypseQuestUnderSiegeRecordConquest(b,terTile.guid,hexLocation,hexFeature)
							end
							if hexFeature=="monastery" and gStates.monasteryBurned[terTile.guid]~=true then
								if gStates.monasteryBurnedBy~=nil and turnOrder[gStates.turnNumber]~=nil then gStates.monasteryBurnedBy[terTile.guid]=turnOrder[gStates.turnNumber].mage end
								broadcastToAll("{en}'You maniacs! You Burned it! You burned it all to Hell!'{ru}Маньяки! Вы всё сожгли! Черт, чтоб вы все сгорели в аду!'{zh-tw}“你们这些疯子! 你烧了它! 你把它烧的如同地狱! “{zh-cn}“你们这些疯子! 你烧了它! 你把它烧的如同地狱! “{ko}‘곧, 심판의 날이 오리라.’ – 요엘 3장 14절{es}Monasterio Quemado{fr}Monastère Incendié{pt-br}'Seu maníaco! Você queimou tudo! Você queimou tudo pro inferno!'{de}Ihr Wahnsinnigen! Ihr habt es verbrannt! Ihr habt alles zur Hölle verbrannt!'", positionToColor(b))
								gStates.monasteryCount=gStates.monasteryCount-1
								gStates.monasteryBurned[terTile.guid]=true
							end
							if hexFeature=="keep" and obj.getGMNotes()~="Burned Monastery" then
								broadcastToAll("{en}'War is too serious a matter to leave to soldiers.'{ru}Война - слишком серьезная вещь, чтобы доверять её военным'{zh-tw}对于小兵来说, 战争太过残酷了{zh-cn}对于小兵来说, 战争太过残酷了{ko}성 정복됨.{es}Mantener Atacado con Exito{fr}Gardez avec Succès Agressé{pt-br}'Guerra é um assunto sério demais para deixar na mão de soldados'{de}Krieg ist eine zu ernste Angelegenheit, um sie Soldaten zu überlassen.'", positionToColor(b))
								mageSearch.keepsBeat=mageSearch.keepsBeat+1
								fakeDropAvatar()
								break
							end
							if hexFeature=="glade" and obj.getGMNotes()~="Burned Monastery" and gStates.gameScenario=="Druid Nights" then
								broadcastToAll("{en}Glade Activated{ru}Магическая поляна активирована{zh-tw}林地激活了{zh-cn}林地激活了{ko}숲속 빈터 활성화{es}Glade Activado{fr}Clairière Activée{pt-br}Clareira Ativada{de}Glade Aktiviert", positionToColor(b))
								mageSearch.gladesMarked[#mageSearch.gladesMarked+1]=obj.guid
							end
							if hexFeature=="glade" and obj.getGMNotes()~="Burned Monastery" and gStates.gameScenario=="Life and Death" then
								broadcastToAll("{en}Glade Liberated{ru}Магическая поляна освобождена{zh-tw}林地解放了{zh-cn}林地解放了{ko}숲속 빈터 해방됨{es}Glade Liberado{fr}Clairière Libérée{pt-br}Clareira Liberada{de}Lichtung befreit", positionToColor(b))
							end
							if hexFeature=="graveyard" and obj.getGMNotes()~="Burned Monastery" then
								if gStates.gameScenario=="The Realm of the Dead Blitz" then
									broadcastToAll("{en}Graveyard Sealed{ru}Кладбище запечатано{zh-tw}墓地封印了{zh-cn}墓地封印了{ko}봉인된 묘지{es}Cementerio Sellado{fr}Cimetière Scellé{pt-br}Cemitério Selado{de}Friedhof versiegelt", positionToColor(b))
								else
									broadcastToAll("{en}Graveyard Liberated{ru}Кладбище освобождено{zh-tw}墓地解放了{zh-cn}墓地解放了{ko}묘지 해방됨{es}Cementerio Liberado{fr}Cimetière Libéré{pt-br}Cemitério Liberado{de}Friedhof befreit", positionToColor(b))
								end
							end
							if hexFeature=="mine" and obj.getGMNotes()~="Burned Monastery" and gStates.gameScenario=="Mines Liberation" then
								broadcastToAll("{en}Mine Liberated{ru}Шахта освобождена{zh-tw}矿山解放了{zh-cn}矿山解放了{ko}광산 해방됨{es}Mina Liberada{fr}Mine Libérée{pt-br}Mina Liberada{de}Mine befreit", positionToColor(b))
							end
							if hexFeature=="mage tower" and obj.getGMNotes()~="Burned Monastery" then
								broadcastToAll("{en}Mage Tower Conquered{ru}Башня мага захвачена{zh-tw}法師塔已被征服{zh-cn}法师塔被征服{ko}마법사의 탑 정복됨{es}Torre de Magos Conquistada{fr}Tour des Mages Conquise{pt-br}Torre do Mago Conquistada{de}Magierturm erobert", positionToColor(b))
							end
							if (hexFeature=="monster den" or hexFeature=="spawning grounds") and obj.getGMNotes()~="Burned Monastery" then
								broadcastToAll("{en}'They mostly come at night...Mostly.'{ru}«Они в основном приходят ночью... В основном.»{zh-tw}“他们大多是晚上来的……大多是. ”{zh-cn}“他们大多是晚上来的……大多是. ”{ko}‘징한 놈의 이 세상, 한탕 신나게 놀고 가면 그 뿐.’{es}'Vienen sobre todo por la noche ... sobre todo.'{fr}'Ils viennent surtout la nuit… surtout.'{pt-br}'Eles vem a maioria das vezes a noite....a maioria das vezes.'{de}Sie kommen meistens nachts ... meistens.", positionToColor(b))
							end
							if (hexFeature=="maze" or hexFeature=="labyrinth" or hexFeature=="ruin" or hexFeature=="dungeon" or hexFeature=="tomb" or hexFeature=="ziggurat" or hexFeature=="pyramid") and obj.getGMNotes()~="Burned Monastery" then
								broadcastToAll("{en}Adventure Site Beaten{ru}Место для приключений побеждено{zh-tw}冒险地点被打败{zh-cn}冒险地点被打败{ko}모험 장소 정복됨{es}Sitio de Aventuras Batido{fr}Site d'Aventure Battu{pt-br}Lugar de Aventura Vencido{de}Abenteuerstätte besiegt", positionToColor(b))
							end
							if (hexFeature or ""):sub(1, 4)=="city" and obj.getGMNotes()~="Burned Monastery" and gStates.gameScenario=="The Lost Relic Blitz" then
								broadcastToAll("{en}Relic Piece Recovered{ru}Часть древней реликвии была найдена{zh-tw}找到了圣物碎片{zh-cn}找到了圣物碎片{ko}유물 조각 복구{es}Pieza de Reliquia Recuperada{fr}Pièce de Relique Récupérée{pt-br}Pedaço da Relíquia Recuperado{de}Reliktstück wiederhergestellt", positionToColor(b))
							end
							break
						end
					end
				end
			end
			addAvatarButtons()
			if gStates.gameScenario=="The Fractured Lands Blitz" and obj.getGMNotes()=="Burned Monastery" then safeWaitFrames("PlayingGame",function() refreshFracturedLandsTeleportHighlights() end, 1) end
		end
	end
	if zone.guid~=mapArea then
		if pause==false then pause=true safeWaitFrames("PlayingGame",function()
			for b, mageSearch in pairs(turnOrder) do
				if mageSearch.mage==obj.getDescription() then
					if zone.guid~=elementalist.discZone and zone.guid~=darkCrusader.discZone and (gStates.gameScenario=="The Gauntlet"
					or gStates.gameScenario=="The Hidden Valley Blitz" or gStates.gameScenario=="The Realm of the Dead Blitz"
					or gStates.gameScenario=="Life and Death" or gStates.gameScenario=="Dungeon Lords"
					or gStates.gameScenario=="Druid Nights" or gStates.gameScenario=="Mines Liberation") then
						broadcastToAll(joinLang({"{en}City is Friendly to {ru}Город дружественный для {zh-tw}城市友善的对象: {zh-cn}城市友善的对象: {ko}도시는 우호적입니다: {es}La Ciudad es Amigable con {fr}La Ville est Amicale avec {pt-br}Cidade é Amistosa a {de}Stadt ist befreundet mit ", translateWord[mageSearch.mage]}), positionToColor(b))
					else
						if zone.guid==GUID.zone.blueCity or zone.guid==GUID.zone.redCity or zone.guid==GUID.zone.greenCity or zone.guid==GUID.zone.whiteCity then
							cityBeatCheck()
							if mageSearch.defeatedCities[cityScriptZones[zone.guid].cityGUID]~=nil then
								broadcastToAll("{en}City has been Conquered{ru}Город был захвачен{zh-tw}城市被征服了{zh-cn}城市被征服了{ko}도시가 정복되었습니다{es}La Ciudad ha sido Conquistada{fr}La Ville a été Conquise{pt-br}Cidade foi Conquistada.{de}Die Stadt wurde erobert", positionToColor(b))
							else
								broadcastToAll("{en}City Defender Defeated{ru}Защитник города побежден{zh-tw}城防守军被击败了{zh-cn}城防守军被击败了{ko}도시 수비자를 처치했습니다{es}Defensor de la Ciudad Derrotado{fr}Défenseur de la Ville Vaincu{pt-br}Defensor da Cidade Derrotado.{de}Stadtverteidiger besiegt", positionToColor(b))
							end
						end
					end
					if zone.guid==darkCrusader.discZone or zone.guid==elementalist.discZone then
						cityBeatCheck()
						if gStates.defeatedFactionTest[cityScriptZones[zone.guid].cityGUID]~=nil then
							broadcastToAll("{en}Leader has been Defeated{ru}Лидер был побежден{zh-tw}首领被打败了{zh-cn}首领被打败了{ko}지도자를 처치했습니다{es}El Líder ha sido Derrotado{fr}Le Chef a été Vaincu{pt-br}Líder foi Derrotado{de}Anführer wurde besiegt", positionToColor(b))
						else
							broadcastToAll("{en}Leader Level Reduced{ru}Уровень лидера понижен{zh-tw}首领级别降低{zh-cn}首领级别降低{ko}지도자 레벨 감소됨{es}Nivel de Líder Reducido{fr}Niveau de Leader Réduit{pt-br}Nível do Líder foi Reduzido{de}Anführerlevel reduziert", positionToColor(b))
						end
					end
					if zone.guid==volkare.discZone then
						cityBeatCheck()
						if mageSearch.defeatedCities[cityScriptZones[zone.guid].cityGUID]~=nil then
							broadcastToAll("{en}Volkare is Defeated{ru}Волкар побежден{zh-tw}沃里卡认怂了{zh-cn}沃里卡认怂了{ko}볼케어 장군을 처치했습니다{es}Volkare es derrotado{fr}Volkare est vaincu{pt-br}Volkare foi Derrotado{de}Volkare ist besiegt", positionToColor(b))
							registerVolkareCampAsCityKeep()
						else
							broadcastToAll("{en}Volkare's Army Reduced{ru}Армия Волкара уменьшилась{zh-tw}沃里卡军队减少了{zh-cn}沃里卡军队减少了{ko}볼케어의 군대가 줄었습니다{es}Ejército de Volkare reducido{fr}Armée de Volkare réduite{pt-br}Exército de Volkare Reduzido{de}Volkares Armee wurde verkleinert", positionToColor(b))
						end
					end
					fakeDropAvatar()
					break
				end
			end
			pause=false
			addAvatarButtons()
		end, 5) end
	end
end

--new XML buttons on skills, offer and tactic cards
function createClaimButton(objGUID, source)
	local onClick="global/claimMove"
	local width=500
	local height=150
	local scale=0.32
	local position="0 190 -10"
	local rotation="0 0 180"
	local text="{en}^ CLAIM{ru}^ ЗАБРАТЬ{zh-tw}^ 選取{zh-cn}^ 选取{ko}^ 선택{es}^ RECLAMO{fr}^ Demande{pt-br}^ CLAMAR{de}^ ANSPRUCH"
	local fontSize="90"
	--Meditation / Trance uses the exact same proven object-UI structure as Claim.
	--Coordinates are tuned for four target spots marked during testing:
	--red pair = Meditation, green pair = Trance.
	if source=="meditationTop" or source=="meditationBot" or source=="tranceTop" or source=="tranceBot" then
		width=250
		onClick=(source=="meditationTop" or source=="tranceTop") and "global/meditationTranceTop" or "global/meditationTranceBot"
		text=(source=="meditationTop" or source=="tranceTop") and "Top" or "Bot"
		if source=="meditationTop" then position="155 -105 -10" end
		if source=="meditationBot" then position="155 -50 -10" end
		if source=="tranceTop" then position="155 35 -10" end
		if source=="tranceBot" then position="155 105 -10" end
	end
	--Steady Tempo reuses the same small object-button style. These sit beside the
	--upper, middle and lower sections of the card: Discard, Bottom, Top.
	if source=="steadyTempoDiscard" or source=="steadyTempoBot" or source=="steadyTempoTop" then
		width=250
		onClick="global/steadyTempoChoice"
		if source=="steadyTempoDiscard" then text="Dis" position="155 -130 -10" end
		if source=="steadyTempoBot" then text="Bot" position="155 0 -10" end
		if source=="steadyTempoTop" then text="Top" position="155 130 -10" end
	end
	for a=1, 32, 1 do
		if source==tostring(a) or source=="higherLevelSkill" then
			if source==tostring(a) then	onClick="global/skillMove" else onClick="global/higherLevelSkill" end
			width=175
			position="-270 0 -1"
			text="<"
			scale=scale*2.307692307692308
			break
		end
	end
	if source:sub(1,6)=="tactic" or source:sub(1,12)=="removeTactic" then
		position="0 130 -1"
		scale=scale*0.6521739130434783
		if source:sub(1,12)=="removeTactic" then
			text="{en}^ REMOVE{ru}^ УДАЛИТЬ{zh-tw}^ 移除{zh-cn}^ 移除{ko}^ 제거{es}^ QUITAR{fr}^ Supprimer{pt-br}^ REMOVER{de}^ ENTFERNEN"
			onClick="global/removeTactic"
		end
		if source=="tactic7" or source=="removeTactic5" then
			width=1200
			scale=scale*2.416666666666667
			rotation="180 180 180"
			if source=="tactic7" then
				position="0 211 -29"
				onClick=("global/"..automatedPlayerTurnFunction())
				text="{en}Pick Random for Dummy{ru}Случайный для виртуального игрока{zh-tw}為虛擬玩家隨機選擇戰術卡{zh-cn}为虚拟玩家随机选择战术卡{ko}가상 플레이어 무작위 선택{es}Elija al Azar para el Maniquí{fr}Elija al Azar Para el Maniquí{pt-br}Escolha Aleatória para o Dummy{de}Zufallsauswahl für Dummy"
				if proxyPlayerActive()==true then text="{en}Pick Random for Proxy{ru}Случайная тактика для прокси{zh-tw}為代理玩家隨機選擇戰術卡{zh-cn}为代理玩家随机选择战术卡{ko}프록시 무작위 선택{es}Elegir al Azar para Proxy{fr}Tirer au Sort pour le Proxy{pt-br}Escolha Aleatória para o Proxy{de}Zufallsauswahl für Proxy" end
				if gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz" or gStates.gameScenario=="Volkare's Quest" then
					text="{en}Pick Random for Volkare{ru}Случайный для Волкара{zh-tw}為沃卡里隨機選擇戰術卡{zh-cn}为沃卡里随机选择战术卡{ko}볼케어 무작위 선택{es}Elige al Azar para Volkare{fr}Tirez au Sort pour Volkare{pt-br}Escolha Aleatório para Volkare{de}Zufallsauswahl für Volkare"
				end
			else
				position="-400 211 -29"
				onClick="global/removeTactic"
				text="{en}^ Remove Both ^{ru}^ Удалить обе ^{zh-tw}^ 雙雙移除 ^{zh-cn}^ 双双移除 ^{ko}^ 둘 다 제거 ^{es}^ Quitar Ambos ^{fr}^ Supprimer les Deux ^{pt-br}^ Remover Ambos ^{de}^ Beide Entfernen ^"
			end
		end
	end
    return {tag="Button", attributes={id=objGUID..source, onClick=onClick, onMouseDown="global/buttonClicked", onMouseUp="global/buttonClicked", height=height, width=width, position=position, rotation=rotation, scale=tostring(scale).." "..tostring(scale)},
		children={{tag="Image", attributes={id=objGUID..source.."Image", image="Sliced Button/Button Object Active", type="Sliced"}},
				  {tag="HorizontalLayout", attributes={padding="25 25 25 25"},
				  children={{tag="Text", attributes={id=objGUID..source.."Text", font="Fonts/MKCardText", fontSize=fontSize, fontStyle="Normal", alignment="MiddleCenter", resizeTextForBestFit="true", resizeTextMaxSize=fontSize, text=text}}}}}}
end

local adjustHandSizePause=nil

function fakeDropAvatar(playerIndex)
	local dropPlayer=playerIndex or gStates.turnNumber
	if turnOrder[dropPlayer]==nil then return end
	if coopAssaultVirtualPlayer(dropPlayer)==true then
		if gStates.preEndTurn~=true then mainUIUpdate("Co-op virtual city location") end
		return
	end
	if adjustHandSizePause~=nil then Wait.stop(adjustHandSizePause) end
	adjustHandSizePause=safeWaitTime("PlayingGame",function()
		if turnOrder[dropPlayer]==nil then return end
		local found=false
		for _, avatar in pairs(mageKnights) do
			if turnOrder[dropPlayer].mage==avatar.mage and avatar.mage~="Volkare" then
				local modelGUID, tokenGUID, standeeGUID=avatar.model, avatar.token, avatar.standee
				local avatarObj=getObjectFromGUID(modelGUID) or getObjectFromGUID(tokenGUID) or getObjectFromGUID(standeeGUID)
				if avatarObj~=nil then
					found=true
					safeWaitFrames("PlayingGame",function()
						--The active avatar representation can be replaced while this delayed fake drop is waiting.
						--Resolve all three forms again so we never deliberately call onObjectDrop with a stale nil object.
						local currentAvatar=getObjectFromGUID(modelGUID) or getObjectFromGUID(tokenGUID) or getObjectFromGUID(standeeGUID)
						if currentAvatar~=nil then onObjectDrop(nil, currentAvatar) end
					end, 50)
				end
				break
			end
		end
		if found==false then mainUIUpdate("Incremented to Dummy's Turn") end
	end, 0.1)
end

--refill empty token piles. Both onObjectEnterScriptingZone and endRound call this routine
function tokenRefill(reportResult)
	--Token piles cannot need refilling during initial setup, and some Apocalypse piles are still being extracted then.
	if gStates==nil or gStates.tokenRefillEnabled~=true then return true end
	local tokenPileLink={	{discard=GUID.bag.discard.towerGarrison, destination=monsterPiles.purple},--Mage Towers Discard-->Main
							{discard=GUID.bag.discard.keepGarrison, destination=monsterPiles.gray},--Keeps Discard-->Main
							{discard=GUID.bag.discard.cityGarrison, destination=monsterPiles.white},--Cities Discard-->Main
							{discard=GUID.bag.discard.ruin, destination=monsterPiles.yellow},--Ruins Discard-->Main
							{discard=GUID.bag.discard.draconum, destination=monsterPiles.red},--Draconum Discard-->Main
							{discard=GUID.bag.discard.dungeon, destination=monsterPiles.tan},--Dungeon Discard-->Main
							{discard=GUID.bag.discard.orcs, destination=monsterPiles.green},--Orc Discard-->Main
							{discard=GUID.bag.discard.darkDraconum, destination=monsterPiles.redDark},--Dark Crusader Draconum Discard-->Main
							{discard=GUID.bag.discard.darkDungeon, destination=monsterPiles.tanDark},--Dark Crusader Dungeon Discard-->Main
							{discard=GUID.bag.discard.darkMarauders, destination=monsterPiles.greenDark},--Dark Crusader Orc Discard-->Main
							{discard=GUID.bag.discard.darkReward, destination=monsterPiles.rewardDark},--Dark Crusader Reward Discard-->Main
							{discard=GUID.bag.discard.elementalistDraconum, destination=monsterPiles.redElem},--Elementalist Draconum Discard-->Main
							{discard=GUID.bag.discard.elementalistDungeon, destination=monsterPiles.tanElem},--Elementalist Dungeon Discard-->Main
							{discard=GUID.bag.discard.elementalistOrcs, destination=monsterPiles.greenElem},--Elementalist Orc Discard-->Main
							{discard=GUID.bag.discard.elementalistReward, destination=monsterPiles.rewardElem},--Elementalist Reward Discard-->Main
							{discard=GUID.bag.discard.possessed, destination=monsterPiles.possessed},--Possessed-->Main
							{discard=GUID.bag.discard.apocReward, destination=monsterPiles.rewardApoc},--Apocalypse Cult Reward Discard-->Main
							{discard=GUID.bag.discard.councilReward, destination=monsterPiles.rewardCouncil}}--Council of the Void Reward Discard-->Main
	local noWait=true
	local emptyPile=false
	for a=1, #tokenPileLink, 1 do
		local discardObj=getObjectFromGUID(tokenPileLink[a].discard)
		local destinationObj=getObjectFromGUID(tokenPileLink[a].destination)
		if destinationObj~=nil and discardObj~=nil then
			if #destinationObj.getObjects()==0 then
				emptyPile=true
				local discardObjects=discardObj.getObjects()
				if #discardObjects>0 then
					discardObj.shuffle()
					for _=1, #discardObjects do
						local obj=discardObj.takeObject()
						gStates.monsterPlayLocation[obj.guid]=nil
						destinationObj.putObject(obj)
					end
					noWait=false
				end
			end
		end
	end
	if reportResult==true and noWait==true then
		if emptyPile==true then
			broadcastToAll("{en}Sorry, I have no discard tokens to fill those empty stacks{ru}Извините, у меня нет жетонов в сбросе, чтобы заполнить эти пустые стопки.{zh-tw}抱歉，我没有废弃标记来填充那些空的标记堆{zh-cn}抱歉，我没有废弃标记来填充那些空的标记堆{ko}버린 토큰을 찾을 수 없어 더미를 채우지 못했습니다.{es}Lo siento, no tengo tokens de descarte para llenar esas pilas vacías{fr}Désolé, je n'ai pas de jetons de défausse pour remplir ces piles vides{pt-br}Desculpe, Eu tenho nenhuma ficha de descarte para preencher as estas pilhas vazias{de}Leider habe ich keine Abwurfmarken, um diese leeren Stapel zu füllen.", {0, 0.5, 1})
		else
			broadcastToAll("{en}All token piles still have tokens to play{ru}Во всех стопках жетонов все еще есть жетоны для игры.{zh-tw}所有标记都还够用呢，先不用返还{zh-cn}所有标记都还够用呢，先不用返还{ko}빈 토큰 더미가 없습니다.{es}Todas las pilas de fichas todavía tienen fichas para jugar.{fr}Toutes les piles de jetons ont encore des jetons à jouer{pt-br}Todas as pilhas de fichas ainda tem fichas para jogar{de}Alle Spielsteinstapel haben noch Spielsteine zum Spielen", {0, 0.5, 1})
		end
	end
	return noWait
end

--Object UI callback for the Monster Replenish panel. The refill logic itself is shared with automatic refills.
function returnPugs(player, mouseButton, id)
	if mouseButton=="-1" then tokenRefill(true) end
end

terrainPlacementNeighbourOffsets={
	{math.cos(math.rad(41))*6.35, math.sin(math.rad(41))*6.35},
	{math.cos(math.rad(101))*6.35, math.sin(math.rad(101))*6.35},
	{math.cos(math.rad(161))*6.35, math.sin(math.rad(161))*6.35},
	{math.cos(math.rad(221))*6.35, math.sin(math.rad(221))*6.35},
	{math.cos(math.rad(281))*6.35, math.sin(math.rad(281))*6.35},
	{math.cos(math.rad(341))*6.35, math.sin(math.rad(341))*6.35}
}

--Avatar-location scans repeatedly inspect the current hex plus its six neighbours. Snapshot map
--positions once and bucket physical objects so each neighbour only checks nearby pieces, while
--terrain lookup works from terrain tiles only.
avatarLocationSpatialCell=3
function avatarLocationMapSnapshot()
	local mapObj=getObjectFromGUID(mapArea)
	if mapObj==nil then return {}, {}, {}, {}, {} end
	local mapObjects=mapObj.getObjects()
	local positions={}
	local terrainObjects={}
	local terrainRotations={}
	local buckets={}
	for _, mapObject in pairs(mapObjects) do
		local pos=mapObject.getPosition()
		positions[mapObject.guid]=pos
		if terrainTiles[mapObject.guid]~=nil then
			terrainObjects[#terrainObjects+1]=mapObject
			terrainRotations[mapObject.guid]=mapObject.getRotation()
		end
		local key=tostring(math.floor(pos[1]/avatarLocationSpatialCell))..":"..tostring(math.floor(pos[3]/avatarLocationSpatialCell))
		if buckets[key]==nil then buckets[key]={} end
		buckets[key][#buckets[key]+1]=mapObject
	end
	return mapObjects, positions, terrainObjects, terrainRotations, buckets
end

function avatarLocationRelevantObjects(locatedTerrain, pos, buckets)
	local result={}
	local seen={}
	if locatedTerrain~=nil then result[#result+1]=locatedTerrain seen[locatedTerrain.guid]=true end
	local baseX=math.floor(pos[1]/avatarLocationSpatialCell)
	local baseZ=math.floor(pos[3]/avatarLocationSpatialCell)
	for x=baseX-1, baseX+1 do
		for z=baseZ-1, baseZ+1 do
			local bucket=buckets[tostring(x)..":"..tostring(z)]
			if bucket~=nil then
				for _, obj in ipairs(bucket) do
					if seen[obj.guid]~=true then result[#result+1]=obj seen[obj.guid]=true end
				end
			end
		end
	end
	return result
end

--Refresh only the stored location of a manually moved off-turn Mage Knight.
--This deliberately avoids attack, site, hand-size, reward and pursuit side effects.
function refreshAvatarLocationOnly(playerIndex, avatarObj)
	local player=turnOrder[playerIndex]
	if player==nil or avatarObj==nil then return false end
	local avatarPos=avatarObj.getPosition()
	local previousSharedHex=player.avatarSharedHex
	player.avatarLocation=""
	player.avatarSharedHex=nil
	player.avatarSwapCity=nil
	local cityFound=false
	for zone, citySearch in pairs(cityScriptZones) do
		local zoneObj=getObjectFromGUID(zone)
		if zoneObj~=nil then
			for _, detail in pairs(zoneObj.getObjects()) do
				if detail.guid==avatarObj.guid then
					local locationObj=nil
					if zone==volkare.discZone and (gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz" or gStates.gameScenario=="Volkare's Quest" or gStates.gameScenario=="The War of Four") then locationObj=getObjectFromGUID(gStates.volkareModel)
					else locationObj=getObjectFromGUID(citySearch.cityGUID) if gStates.cityCard[citySearch.cityGUID]~=nil then player.avatarSwapCity=citySearch.cityGUID end end
					if locationObj~=nil then avatarPos=locationObj.getPosition() end
					cityFound=true break
				end
			end
		end
		if cityFound==true then break end
	end
	local terrain, bearing=terrainHexAtPosition(avatarPos)
	if terrain~=nil and bearing~=nil and terrainTiles[terrain.guid]~=nil then
		player.avatarLocation=terrainTiles[terrain.guid].hexFeature[bearing]
		if againstHorsemenCentralGladeHex(terrain,bearing)==true and gStates.againstHorsemenRitualStarted~=true then player.avatarSharedHex=againstHorsemenSharedHexKey end
	elseif avatarPos[1]<-42 then
		--Scripted parking on the Portal card does not change the Mage Knight's logical shared-Glade location.
		if gStates.gameScenario=="Against the Horsemen Blitz" and gStates.againstHorsemenRitualStarted~=true and previousSharedHex==againstHorsemenSharedHexKey then
			player.avatarLocation="glade"
			player.avatarSharedHex=againstHorsemenSharedHexKey
		else player.avatarLocation="portal" end
	end
	return true
end

playerPickedUpPos={}
playerPickedUpHex=nil
locationAttacked=false
--Pyramid/Ziggurat shield spots match the Shield snap points at the normal 180 degree terrain orientation
local zigguratPyramidFloorOffsets={{-0.4275,-0.405},{0.6975,-0.0225},{-0.09,0.6975}}
function zigguratPyramidFloorPosition(terrain, sitePos, floor)
	local offset=zigguratPyramidFloorOffsets[floor]
	local angle=0
	if terrain~=nil then angle=math.rad(180-terrain.getRotation()[2]) end
	local x=(offset[1]*math.cos(angle))-(offset[2]*math.sin(angle))
	local z=(offset[1]*math.sin(angle))+(offset[2]*math.cos(angle))
	return {sitePos[1]+x, 2, sitePos[3]+z}
end

function zigguratPyramidFloorFromPosition(terrain, sitePos, shieldPos)
	local closestFloor, closestDist=nil, math.huge
	for floor=1, 3 do
		local floorPos=zigguratPyramidFloorPosition(terrain, sitePos, floor)
		local dist=((shieldPos[1]-floorPos[1])^2)+((shieldPos[3]-floorPos[3])^2)
		if dist<closestDist then closestFloor, closestDist=floor, dist end
	end
	return closestFloor
end

--Plays rampaging tokens. Both onObjectEnterScriptingZone and endRound call this routine
function playRampagingTokens(obj, startBearing, northBearing, hexLocation, hexFeature, dropped, ambushEligible)
	if ambushEligible==nil then ambushEligible=true end
	local free=true
	--set position of terrain hex in real world coordinates
	local params={position={angleToXY(obj, hexLocation)[1], 2, angleToXY(obj, hexLocation)[2]}}
	--Check if the hex has any existing tokens for Rampage Variant
	if gStates.rampage>0 then
		for _, shield in pairs(getObjectFromGUID(mapArea).getObjects()) do
			if math.sqrt(((shield.getPosition()[1]-params.position[1])^2)+((shield.getPosition()[3]-params.position[3])^2))<1 then
				local name=nil
				if shield.getRotationValues()[2]~=nil then name=shield.getRotationValues()[2].value else name=shield.getName() end
				local nameList={"Marauding Orcs", "Marauding Elementalist", "Marauding Dark Crusader",
								"Draconum", "Elementalist Draconum", "Dark Crusader Draconum",
								"Arythea", "Braevalar", "Goldyx", "Krang", "Norowas", "Tovak", "Volkare", "Wolfhawk", "Coral", "Ymirgh", "Jormund", "Mevok", "Duscenia", "Malek", "Zirtae"}
				for _, h in pairs(nameList) do
					if name==h then free=false break end
				end
			end
		end
	end
	local dice=nil
	if free==true and dropped==false then
		if gStates.rampage==1 then dice=getObjectFromGUID("95ca17").clone(params) end
		if gStates.rampage==2 then dice=getObjectFromGUID("48089f").clone(params) end
	end
	if dice~=nil then safeWaitTime("PlayingGame",function() dice.destruct() end, 10) end
	safeWaitFrames("PlayingGame",function()--wait for clone to spawn
		if dice~=nil then dice.unlock() dice.shuffle() end
		safeWaitFrames("PlayingGame",function()
			safeWaitCondition("PlayingGame",function()
				if dice~=nil then
					dice.setPosition({params.position[1], 3.0, params.position[3]})
					dice.lock()
				end
				tokenRefill()
				if dropped==true or (gStates.rampage==1 and dice~=nil and dice.getRotationValue():sub(1,7)=="Rampage" and free==true) or (gStates.rampage==2 and free==true) then
					local tokenPileGreen=	monsterPiles.green--Standard green Tokens
					local tokenPileBrown=	monsterPiles.tan--Standard Brown Tokens
					local tokenPileRed=		monsterPiles.red--Standard Red Tokens
					local tokenFaction=nil
					if gStates.gameScenario=="Life and Death" or gStates.gameScenario=="The War of Four" then
						--War of four which column
						local warOfFourLoc="center"
						if gStates.gameScenario=="The War of Four" then --Open Limited to ? Columns
							local pos=obj.getPosition()
							local edgeCoordinates={	{-38.43,  0.54},  {-33.63,  4.70},  {-28.83,  8.86}, {-24.03, 13.02}, {0, 0},--Far North Column Coordinates
													{-37.23, -5.69},  {-32.43, -1.52},  {-27.63,  2.62}, {-22.83,  6.79}, {-18.02, 10.94},--North Column Coordinates
													{-30.03, -14.01}, {-25.23, -9.84},  {-20.43, -5.69}, {-15.63, -1.54}, {-10.81,  2.63},--South Column Coordinates
													{-24.03, -16.08}, {-19.23, -11.93}, {-14.43, -7.77}, {-9.63,  -3.61}}--Far South Column Coordinates
							for tileLoc, coords in pairs(edgeCoordinates) do
								if math.sqrt(((pos[1]-coords[1])^2)+((pos[3]-coords[2])^2))<1 then
									if math.ceil(tileLoc/5)==1 then warOfFourLoc="FarNorth" end
									if math.ceil(tileLoc/5)==2 then warOfFourLoc="North" end
									if math.ceil(tileLoc/5)==3 then warOfFourLoc="South" end
									if math.ceil(tileLoc/5)==4 then warOfFourLoc="FarSouth" end
									break
								end
							end
						end
						--deploy faction tokens
						local factionPlayed=math.random(1,2)
						if 	(gStates.gameScenario=="Life and Death" and ((startBearing<northBearing-1) or
								(startBearing<=northBearing+1 and startBearing>=northBearing-1 and gStates.coop==1 and factionPlayed==1) or
								(gStates.coop==0 and factionPlayed==1 and obj.getPosition()[3]<-7 and obj.getPosition()[3]>-8 and obj.getPosition()[1]<-31 and obj.getPosition()[1]>-32))) or
							(gStates.gameScenario=="The War of Four" and ((warOfFourLoc=="South" and math.random(1,2)==1) or (warOfFourLoc=="FarSouth" and math.random(1,3)==1))) then
								tokenFaction="Elem"
							if getObjectFromGUID(monsterPiles.greenElem).getQuantity()>0 then tokenPileGreen=monsterPiles.greenElem end
							if getObjectFromGUID(monsterPiles.tanElem).getQuantity()>0 then tokenPileBrown=monsterPiles.tanElem end
							if getObjectFromGUID(monsterPiles.redElem).getQuantity()>0 then tokenPileRed=monsterPiles.redElem end --elementalist Tokens
						end
						if 	(gStates.gameScenario=="Life and Death" and ((startBearing>northBearing+1) or
								(startBearing<=northBearing+1 and startBearing>=northBearing-1 and gStates.coop==1 and factionPlayed==2) or
								(gStates.coop==0 and factionPlayed==2 and obj.getPosition()[3]<-7 and obj.getPosition()[3]>-8 and obj.getPosition()[1]<-31 and obj.getPosition()[1]>-32))) or
							(gStates.gameScenario=="The War of Four" and ((warOfFourLoc=="North" and math.random(1,2)==1) or (warOfFourLoc=="FarNorth" and math.random(1,3)==1))) then
								tokenFaction="Dark"
							if getObjectFromGUID(monsterPiles.greenDark).getQuantity()>0 then tokenPileGreen=monsterPiles.greenDark end
							if getObjectFromGUID(monsterPiles.tanDark).getQuantity()>0 then tokenPileBrown=monsterPiles.tanDark end
							if getObjectFromGUID(monsterPiles.redDark).getQuantity()>0 then tokenPileRed=monsterPiles.redDark end---Dark Crusader Tokens
						end
					end
					if gStates.gameScenario=="The Realm of the Dead Blitz" then
						tokenFaction="Dark"
						if getObjectFromGUID(monsterPiles.greenDark).getQuantity()>0 then tokenPileGreen=monsterPiles.greenDark end
						if getObjectFromGUID(monsterPiles.tanDark).getQuantity()>0 then tokenPileBrown=monsterPiles.tanDark end
						if getObjectFromGUID(monsterPiles.redDark).getQuantity()>0 then tokenPileRed=monsterPiles.redDark end---Dark Crusader Tokens
					end
					if gStates.gameScenario=="The Hidden Valley Blitz" then
						tokenFaction="Elem"
						if getObjectFromGUID(monsterPiles.greenElem).getQuantity()>0 then tokenPileGreen=monsterPiles.greenElem end
						if getObjectFromGUID(monsterPiles.tanElem).getQuantity()>0 then tokenPileBrown=monsterPiles.tanElem end
						if getObjectFromGUID(monsterPiles.redElem).getQuantity()>0 then tokenPileRed=  monsterPiles.redElem end --elementalist Tokens
					end
					params.rotation={0.0, 180.0, 0.0}
					if (hexFeature=="draconum" or hexFeature=="mine") and gStates.gameScenario~="The Lost Relic Blitz" then tokenPileGreen=tokenPileRed end
					if hexFeature=="village" or (hexFeature=="" and obj.guid==GUID.tile.city08) then tokenPileGreen=tokenPileBrown end
					--play Green token
					if getObjectFromGUID(tokenPileGreen)~=nil and getObjectFromGUID(tokenPileGreen).getQuantity()>0 then
						local token=getObjectFromGUID(tokenPileGreen).takeObject(params)
						markMonsterFactionSubstitute(token, tokenFaction)
						gStates.monsterPlayLocation[token.guid]=params.position
						gStates.rampagingMonsters[token.guid]=true
						if gStates.rampageAmbush==true and gStates.tacticShown==false and dropped==true and ambushEligible==true then
							gStates.ambushingMonsters[token.guid]=params.position
						end
						if gStates.rampagePursuit==true and gStates.tacticShown==false and dropped==true and turnOrder[gStates.turnNumber].mage~=gStates.positionMageKnight[5] then
							for _, mage in pairs(mageKnights) do
								if mage.mage==turnOrder[gStates.turnNumber].mage then
									if gStates.pursuingMonsters[mage.mage]==nil then gStates.pursuingMonsters[mage.mage]={} end
									gStates.pursuingMonsters[mage.mage][token.guid]={state="Deployed", location=params.position}
								end
							end
						end
						--brutal red city
						if gStates.gameScenario=="The Chaos Rift" and obj.guid==GUID.tile.city08 and monsterPugs[token.guid].brutal==nil then
							token.addDecal({name="Brutal", url="https://steamusercontent-a.akamaihd.net/ugc/14173504696154614110/C885A392A7488395AEB158E0DAA7EA420F9C4560/",
							position={-1.1, 0.15, -0.25}, rotation={90, 180, 0}, scale={0.72, 0.72, 1}})
							if gStates.monsterPerks[token.guid]==nil then gStates.monsterPerks[token.guid]={brutal=true} else gStates.monsterPerks[token.guid].brutal=true end
						end
					else
						broadcastToAll("{en}Sorry, there are no Rampage tokens left to deploy{ru}Извините, жетоны яростных врагов закончились.{zh-tw}抱歉，没有紫色标记可供部署{zh-cn}抱歉，没有紫色标记可供部署{ko}여분의 광분하는 적 토큰이 없습니다{es}Lo sentimos, no quedan tokens de Rampage para implementar{fr}Désolé, il n'y a plus de jetons Rampage à déployer{pt-br}Desculpe, Não tem Fichas Irascíveis sobrando para distribuir{de}Leider gibt es keine Rampage-Plättchen mehr zum Einsetzen", warningColor)
					end
					--play Brown token
					if dropped==false and gStates.rampage>0 and dice~=nil and dice.getRotationValue()=="Rampage Full" then
						params.position[1]=params.position[1]+0.2
						params.position[2]=params.position[2]+0.5
						params.position[3]=params.position[3]+0.2
						if getObjectFromGUID(tokenPileBrown).getQuantity()>0 then
							local token=getObjectFromGUID(tokenPileBrown).takeObject(params)
							markMonsterFactionSubstitute(token, tokenFaction)
							gStates.monsterPlayLocation[token.guid]=params.position
							gStates.rampagingMonsters[token.guid]=true
						else
							broadcastToAll("{en}Sorry, there are no Brown tokens left to deploy{ru}Извините, коричневые жетоны закончились.{zh-tw}抱歉，没有棕色标记可供部署{zh-cn}抱歉，没有棕色标记可供部署{ko}여분의 갈색 토큰이 없습니다{es}Lo sentimos, no quedan tokens marrones para implementar{fr}Désolé, il n'y a plus de jetons bruns à déployer{pt-br}Desculpe, Não tem Fichas Marrons sobrando para distribuir{de}Tut mir leid, es gibt keine braunen Plättchen mehr zum Auslegen", warningColor)
						end
					end
				end
			end, function() return dice==nil or dice.resting end)
		end, 5)
	end, 5)
end

--Pillage Village, draw two cards for chosen mage and reduce Reputation by 1
function plunderVillage(player, mouseButton, id)
	if mouseButton=="-1" then
		if legalPlayerCheck(player.color, tonumber(id:sub(8,8)))==true then
			for a=1, #turnOrder, 1 do
				if turnOrder[a].seatPos==tonumber(id:sub(8,8)) then
					broadcastToAll(joinLang({translateWord[turnOrder[a].mage], "{en} just Plundered their Village.{ru} разграбляет деревню.{zh-tw}刚刚劫掠了他们的村庄{zh-cn}刚刚劫掠了他们的村庄{ko}: 마을을 약탈했습니다.{es} acaba de saquear su aldea.{fr} vient de Piller leur Village.{pt-br} acabou de Saquear a Vila{de} hat gerade ihr Dorf geplündert. "}), positionToColor(a))
					--One exact two-card request avoids competing Quick Witted prompts for Coral.
					drawExactDeedCards(a, 2, "DrawOne")
					--reduce Reputation by 1
					local repPos=reputationTable[turnOrder[a].reputation-1].reputationPos
					getObjectFromGUID(turnOrder[a].reputationGUID).setPosition({repPos[1], repPos[2], repPos[3]})
					turnOrder[a].reputation=turnOrder[a].reputation-1
					--only alow once per turn
					turnOrder[a].pillagedVillage=true
					mainUIUpdate("Village Pillaged")
					break
				end
			end
		end
	end
end

local coralQuickWittedShufflePause=nil
function scheduleCoralQuickWittedBottom(delayFrames)
	if coralQuickWittedShufflePause~=nil then Wait.stop(coralQuickWittedShufflePause) end
	coralQuickWittedShufflePause=safeWaitFrames("PlayingGame",function() coralQuickWittedShufflePause=nil coralSetAsideQuickWitted() end, delayFrames or 5)
end

function motivation(player, mouseButton, id)
	if mouseButton=="-1" then
		if legalPlayerCheck(player.color, tonumber(id:sub(18, 18)))==true then
			for a=1, #turnOrder, 1 do
				if turnOrder[a].seatPos==tonumber(id:sub(18, 18)) then
					broadcastToAll(joinLang({translateWord[turnOrder[a].mage], "{en} used a Motivation skill.{ru} использует навык Мотивация.{zh-tw}使用了激励技能{zh-cn}使用了激励技能{ko}: 스킬 '동기 부여' 사용{es} usó una habilidad de Motivación.{fr} utilisé une compétence de Motivation.{pt-br} usou uma Habilidade de Motivação{de} eine Motivationsfertigkeit eingesetzt."}), positionToColor(a))
					--One exact two-card request keeps the whole Motivation draw inside one Quick Witted choice flow.
					drawExactDeedCards(a, 2, "DrawOne")
					--Gain Fame or mana token
					local lowestFame=1
					for b=2, #turnOrder, 1 do
						if turnOrder[b].mage~=gStates.positionMageKnight[5] then
							if turnOrder[b].fame<turnOrder[lowestFame].fame or turnOrder[lowestFame].mage==gStates.positionMageKnight[5] then lowestFame=b end
						end
					end
					for b=1, #turnOrder, 1 do if turnOrder[b].fame==turnOrder[lowestFame].fame and b~=lowestFame then lowestFame=0 break end end--find ties
					if lowestFame~=0 and turnOrder[lowestFame].seatPos==tonumber(id:sub(18, 18)) then
						local params={position={(gStates.motivationSkill[id:sub(1, 6)].pos*40)-101, 1.65, -39}, rotation={0, 0, 0}, smooth=false}
						if gStates.motivationSkill[id:sub(1, 6)].bonus:sub(11, 13)=="Red" then
							takeManaCrystal(getObjectFromGUID(GUID.bag.mana.red),params)
							broadcastToAll("{en}Also gained a Red Mana Token.{ru}Также получает Красный жетон маны.{zh-tw}同时增加了一个红色魔晶{zh-cn}同时增加了一个红色魔晶{ko}빨간색 마나 추가 획득.{es}También ganó una ficha de Maná Roja.{fr}A également gagné un jeton de Mana Rouge.{pt-br}Também ganhou um Marcador de Mana Vermelha.{de}Außerdem erhielt er ein rotes Mana-Plättchen.", positionToColor(a))
						end
						if gStates.motivationSkill[id:sub(1, 6)].bonus:sub(11, 14)=="Blue" then
							takeManaCrystal(getObjectFromGUID(GUID.bag.mana.blue),params)
							broadcastToAll("{en}Also gained a Blue Mana Token.{ru}Также получает Синий жетон маны.{zh-tw}同时增加了一个蓝色魔晶{zh-cn}同时增加了一个蓝色魔晶{ko}파란색 마나 추가 획득.{es}También ganó una ficha de Maná Azul.{fr}A également gagné un jeton de Mana Bleu.{pt-br}Também ganhou um Marcador de Mana Azul.{de}Außerdem ein blaues Mana-Plättchen erhalten.", positionToColor(a))
						end
						if gStates.motivationSkill[id:sub(1, 6)].bonus:sub(11, 15)=="White" then
							takeManaCrystal(getObjectFromGUID(GUID.bag.mana.white),params)
							broadcastToAll("{en}Also gained a White Mana Token.{ru}Также получает Белый жетон маны.{zh-tw}同时增加了一个白色魔晶{zh-cn}同时增加了一个白色魔晶{ko}흰색 마나 추가 획득.{es}También ganó una ficha de Maná Blanca.{fr}A également gagné un jeton de Mana Blanc.{pt-br}Também ganhou um Marcador de Mana Branca.{de}Außerdem erhielt er ein weißes Mana-Plättchen.", positionToColor(a))
						end
						if gStates.motivationSkill[id:sub(1, 6)].bonus:sub(11, 15)=="Green" then
							takeManaCrystal(getObjectFromGUID(GUID.bag.mana.green),params)
							broadcastToAll("{en}Also gained a Green Mana Token.{ru}Также получает Зеленый жетон маны.{zh-tw}同时增加了一个绿色魔晶{zh-cn}同时增加了一个绿色魔晶{ko}녹색 마나 추가 획득.{es}También ganó una ficha de Maná Verde.{fr}A également gagné un jeton de Mana Vert.{pt-br}Também ganhou um Marcador de Mana Verde.{de}Hat auch ein grünes Mana-Plättchen erhalten.", positionToColor(a))
						end
						if gStates.motivationSkill[id:sub(1, 6)].bonus:sub(11, 14)=="Fame" then
							local startingFameToLevel=math.floor(math.sqrt((turnOrder[a].fame-(gStates.scoreIfLooped*turnOrder[a].scoreLoop))+1))
							local newFame=turnOrder[a].fame+1-(gStates.scoreIfLooped*turnOrder[a].scoreLoop)
							local scoreLooped=false
							if newFame>=gStates.scoreIfLooped then newFame=newFame-gStates.scoreIfLooped scoreLooped=true end
							local fameToLevel=math.floor(math.sqrt(newFame+1))
							local startPosition=(newFame-(fameToLevel*fameToLevel))+2
							if scoreLooped==false then startPosition=startPosition+((fameToLevel-startingFameToLevel)*gStates.blitz) end
							local levelRowFameQuantity=(((fameToLevel-1)*cellGainPerLevel)+normalCellAmount)
							local levelRowLength=((fameToLevel-1)*gStates.rowLengthGainPerLevel)+gStates.normalRowLength
							local xOffset=(1/levelRowFameQuantity*levelRowLength)/2
							local yOffset=(heightOfFameBoard/gStates.rowsOnBoard)/2
							local horizontalValue=leftOfFameBoard+(startPosition/levelRowFameQuantity*levelRowLength)-xOffset
							local verticalValue=(topOfFameBoard-((fameToLevel/gStates.rowsOnBoard)*heightOfFameBoard))+yOffset-0.25
							getObjectFromGUID(turnOrder[a].fameGUID).setPosition({horizontalValue, 1.5, verticalValue+((turnOrder[a].seatPos-2.5)/5)})
							recordPlayerFameChange(a, 1)
							broadcastToAll("{en}and gained a Fame also{ru}и получает Славу{zh-tw}也增加了1名望{zh-cn}也增加了1名望{ko}명성 1 추가 획득.{es}y ganó Fama también{fr}et a également gagné une renommée{pt-br}e também ganhou uma Fama.{de}und auch einen Ruhmespunkt gewonnen", positionToColor(a))
						end
					end
					--flip skill down.
					getObjectFromGUID(id:sub(1, 6)).setRotationSmooth({0, 180, 180})
					getObjectFromGUID(id:sub(1, 6)).setPositionSmooth({gStates.mageSkills[id:sub(1, 6)][1], 1.5, gStates.mageSkills[id:sub(1, 6)][3]})
					--only allow once per round
					gStates.motivationSkill[id:sub(1, 6)].state="used"
					mainUIUpdate("Motivation Skill activated")
					break
				end
			end
		end
	end
end

--Adjust artifact rewards claim amount
function artifactAdjust(player, mouseButton, id)
	if mouseButton=="-1" then
		if id=="ac75c4ArtifactDown" then
			gStates.artifactRewards=gStates.artifactRewards-1
			if gStates.artifactRewards<1 then gStates.artifactRewards=1 end
		else
			gStates.artifactRewards=gStates.artifactRewards+1
			if gStates.artifactRewards>4 then gStates.artifactRewards=4 end
		end
		getObjectFromGUID(GUID.deck.artifact).UI.setAttribute("ac75c4ArtifactOfferText", "text", joinLang({"{en}Reward {ru}Награда {zh-tw}獎勵{zh-cn}奖励{ko}보상 {es}Premiar {fr}Reward {pt-br}Premiar {de}Belohnung ", gStates.artifactRewards}))
	end
end

--Deploys artifacts to be claimed
function offerArtifacts(player, mouseButton, id)
	if mouseButton=="-1" then
		if legalPlayerCheck(player.color, turnOrder[gStates.turnNumber].seatPos)==true and turnOrder[gStates.turnNumber].mage~=gStates.positionMageKnight[5] then
			--check if the game is in a state to claim artifacts
			if gStates.tacticShown~=true and gStates.tacticRemove~=true then
				--deal out cards
				local artifactDeck=getObjectFromGUID(GUID.deck.artifact)
				gStates.dealtArtifacts={}
				local hide={}
				if gStates.coop==0 then
					for _, seatColor in pairs(Player.getColors()) do
						if seatColor~=player.color then hide[#hide+1]=seatColor end
					end
				end
				for a=1, gStates.artifactRewards+1, 1 do
					standardDeckCycleShuffleIfReached("Artifact", artifactDeck)
					--artifactDeck=getObjectFromGUID(GUID.deck.artifact)
					local dealtArtifact=artifactDeck.takeObject({position={artifactDeck.getPosition()[1]+(((artifactDeck.getScale()[1]/1.5)*4.8)*a), 2.0, artifactDeck.getPosition()[3]}, rotation={0, 180, 0}, smooth=true})
					dealtArtifact.setHiddenFrom(hide)
					dealtArtifact.UI.setXmlTable({createClaimButton(dealtArtifact.guid, "artifactReward")})
					safeWaitCondition("PlayingGame",function() dealtArtifact.lock() end, function() return dealtArtifact.resting end)
					gStates.dealtArtifacts[dealtArtifact.guid]=true
				end
				--remove reward and arrow buttons.
				getObjectFromGUID(GUID.deck.artifact).UI.setAttribute("ac75c4ArtifactDown", "active", "false")
				getObjectFromGUID(GUID.deck.artifact).UI.setAttribute("ac75c4ArtifactOffer", "active", "false")
				getObjectFromGUID(GUID.deck.artifact).UI.setAttribute("ac75c4ArtifactUp", "active", "false")
			else
				broadcastToAll("{en}Choose a tactic first{ru}Сперва выберите Тактику{zh-tw}先选一张战术卡吧{zh-cn}先选一张战术卡吧{ko}먼저 전략 카드를 고르세요{es}Elige una táctica primero{fr}Choisissez d'abord une tactique{pt-br}Escolha uma Tática primeiro{de}Wähle zuerst eine Taktik",warningColor)
			end
		else
			if turnOrder[gStates.turnNumber].mage==gStates.positionMageKnight[5] then
				broadcastToAll("{en}Dummy doesn't claim artifacts{ru}Виртуальный игрок не получает артефактов{zh-tw}虚拟玩家不选择圣器{zh-cn}虚拟玩家不选择圣器{ko}가상 플레이어는 유물을 얻지 않습니다!{es}Dummy no reclama artefactos{fr}Le mannequin ne revendique pas d'artefacts{pt-br}Jog. Fictício não clama Artefatos{de}Dummy beansprucht keine Artefakte",warningColor)
			end
		end
	end
end

--Unit Offer uses eight printed positions spanning X=36.0 to X=2.4.
--Overflow (normally Bonds of Loyalty) compresses extra cards inside those fixed endpoints. The
--snap points are rebuilt to the same centres, while one broad scripting zone handles every Unit card.
unitOfferLayoutConfig={nativeSlots=8,firstX=36.0,lastX=2.4,y=0.98,z=-4.2,cardScale=1.5}

function unitOfferLayoutX(slot,count)
	local displayCount=math.max(unitOfferLayoutConfig.nativeSlots,count or unitOfferLayoutConfig.nativeSlots)
	local spacing=(unitOfferLayoutConfig.firstX-unitOfferLayoutConfig.lastX)/(displayCount-1)
	return unitOfferLayoutConfig.firstX-((slot-1)*spacing)
end

function unitOfferCardScale(count)
	if count==nil or count<=unitOfferLayoutConfig.nativeSlots then return unitOfferLayoutConfig.cardScale end
	return unitOfferLayoutConfig.cardScale*((unitOfferLayoutConfig.nativeSlots-1)/(count-1))
end

function unitOfferPosition(slot,count,y)
	return {unitOfferLayoutX(slot,count),y or unitOfferLayoutConfig.y,unitOfferLayoutConfig.z}
end

function volkareUnitCrystalRefreshPositions(count)
	if gStates==nil or gStates.volkareUnitCrystals==nil then return end
	local displayCount=math.max(unitOfferLayoutConfig.nativeSlots,tonumber(count) or tonumber(gStates.unitOfferDisplayCount) or tonumber(gStates.totalUnitCount) or unitOfferLayoutConfig.nativeSlots)
	for _,details in pairs(gStates.volkareUnitCrystals) do
		if type(details)=="table" and details.slot~=nil and details.crystalGUID~=nil then
			local crystal=getObjectFromGUID(details.crystalGUID)
			if crystal~=nil then
				crystal.setPositionSmooth({unitOfferLayoutX(details.slot,displayCount),1.29,-1.15})
			end
		end
	end
end

--Advanced Action and Spell rows share one resizable scripting zone. Derive slot order from the
--cards themselves so expanding/shrinking the offer never needs matching per-slot zones.
function mainOfferCards(cardType)
	local cards={}
	local zone=getObjectFromGUID(GUID.zone.offer)
	if zone~=nil then
		for _,obj in pairs(zone.getObjects()) do
			if obj.type=="Card" and gameCardType(obj)==cardType then cards[#cards+1]=obj end
		end
	end
	table.sort(cards,function(a,b) return a.getPosition()[1]<b.getPosition()[1] end)
	return cards
end

function mainOfferFirstCard(cardType)
	return mainOfferCards(cardType)[1]
end

function unitOfferIsUnit(obj)
	if obj==nil or obj.type~="Card" then return false end
	local cardType=gameCardType(obj)
	return cardType=="Regular Unit" or cardType=="Elite Unit"
end

function monasteryOfferIsCard(obj)
	if obj==nil or obj.type~="Card" or gameCardType(obj)~="Advanced Action" then return false end
	return math.abs(obj.getPosition()[3]+10.2)<=1
end

function monasteryOfferCards()
	local cards={}
	local zone=getObjectFromGUID(GUID.zone.unitOffer)
	if zone~=nil then
		for _,obj in pairs(zone.getObjects()) do
			if monasteryOfferIsCard(obj) then cards[#cards+1]=obj end
		end
	end
	--Smallest X is the highest-numbered printed slot, matching the old reverse zone scan.
	table.sort(cards,function(a,b) return a.getPosition()[1]<b.getPosition()[1] end)
	return cards
end

--Offer claims use two broad scripting zones. The upper zone distinguishes Units from Monastery
--Advanced Actions by card type/row; the lower zone already covers both Advanced Actions and Spells.
function offerClaimSource(zoneGUID,obj)
	local source=cardClaimingZones[zoneGUID]
	if source~="unitOffer" then return source end
	if unitOfferIsUnit(obj) then return "unit" end
	if monasteryOfferIsCard(obj) then return "monastery" end
	return nil
end

local function unitOfferSnapWorld(owner,point,isGlobal)
	if point==nil or point.position==nil then return nil end
	if isGlobal==true then return point.position end
	return owner.positionToWorld(point.position)
end

local function unitOfferSnapInRow(worldPos)
	if worldPos==nil then return false end
	local x=worldPos.x or worldPos[1]
	local z=worldPos.z or worldPos[3]
	if x==nil or z==nil then return false end
	return x>=unitOfferLayoutConfig.lastX-0.4 and x<=unitOfferLayoutConfig.firstX+0.4 and math.abs(z-unitOfferLayoutConfig.z)<=0.5
end

--The eight offer snaps may be global table snaps or attached to the offer mat. Find whichever owns
--the row, preserve every unrelated snap, then rebuild this row at the same dynamic centres as the cards.
local function unitOfferSnapTarget()
	local snaps=Global.getSnapPoints() or {}
	local matches=0
	for _,point in ipairs(snaps) do if unitOfferSnapInRow(point.position) then matches=matches+1 end end
	if matches>=unitOfferLayoutConfig.nativeSlots then return Global,snaps,true end
	for _,obj in ipairs(getAllObjects()) do
		local objSnaps=obj.getSnapPoints() or {}
		if #objSnaps>=unitOfferLayoutConfig.nativeSlots then
			matches=0
			for _,point in ipairs(objSnaps) do
				if unitOfferSnapInRow(unitOfferSnapWorld(obj,point,false)) then matches=matches+1 end
			end
			if matches>=unitOfferLayoutConfig.nativeSlots then return obj,objSnaps,false end
		end
	end
	return nil,nil,nil
end

function refreshUnitOfferSnapPoints(count)
	local displayCount=math.max(unitOfferLayoutConfig.nativeSlots,count or unitOfferLayoutConfig.nativeSlots)
	gStates.unitOfferDisplayCount=displayCount
	volkareUnitCrystalRefreshPositions(displayCount)
	local owner,snaps,isGlobal=unitOfferSnapTarget()
	if owner==nil then return false end
	local kept={}
	local template=nil
	local templateWorld=nil
	for _,point in ipairs(snaps) do
		local world=unitOfferSnapWorld(owner,point,isGlobal)
		if unitOfferSnapInRow(world) then
			if template==nil then template=point templateWorld=world end
		else
			kept[#kept+1]=point
		end
	end
	if template==nil or templateWorld==nil then return false end
	local y=templateWorld.y or templateWorld[2] or 0
	local z=templateWorld.z or templateWorld[3] or unitOfferLayoutConfig.z
	for slot=1,displayCount do
		local world={unitOfferLayoutX(slot,displayCount),y,z}
		local position=world
		if isGlobal~=true then position=owner.positionToLocal(world) end
		kept[#kept+1]={position=position,rotation=template.rotation,rotation_snap=template.rotation_snap,tags=template.tags}
	end
	owner.setSnapPoints(kept)
	return true
end

function unitOfferCards()
	local cards={}
	local zone=getObjectFromGUID(GUID.zone.unitOffer)
	if zone~=nil then
		for _,obj in pairs(zone.getObjects()) do
			if unitOfferIsUnit(obj) then cards[#cards+1]=obj end
		end
	end
	table.sort(cards,function(a,b) return a.getPosition()[1]>b.getPosition()[1] end)
	return cards
end

--Resolve a physical Unit-offer slot without collapsing gaps left by claimed or removed cards.
--This also follows the compressed spacing used when more than eight Units are displayed.
function unitOfferCardAtSlot(slot,count)
	slot=tonumber(slot)
	if slot==nil then return nil end
	local displayCount=math.max(unitOfferLayoutConfig.nativeSlots,tonumber(count) or tonumber(gStates.unitOfferDisplayCount) or tonumber(gStates.totalUnitCount) or unitOfferLayoutConfig.nativeSlots)
	if slot<1 or slot>displayCount then return nil end
	local spacing=(unitOfferLayoutConfig.firstX-unitOfferLayoutConfig.lastX)/(displayCount-1)
	local targetX=unitOfferLayoutX(slot,displayCount)
	local tolerance=math.max(0.45,spacing*0.45)
	local best=nil
	local bestDistance=nil
	for _,card in ipairs(unitOfferCards()) do
		local pos=card.getPosition()
		local x=pos.x or pos[1]
		local z=pos.z or pos[3]
		if x~=nil and z~=nil and math.abs(z-unitOfferLayoutConfig.z)<=0.8 then
			local distance=math.abs(x-targetX)
			if distance<=tolerance and (bestDistance==nil or distance<bestDistance) then
				best=card
				bestDistance=distance
			end
		end
	end
	return best
end

local function moveUnitOfferCard(obj,slot,count)
	if obj==nil then return end
	local guid=obj.guid
	local pos=obj.getPosition()
	local scale=unitOfferCardScale(count)
	obj.unlock()
	obj.setScale({scale,1,scale})
	obj.setPositionSmooth(unitOfferPosition(slot,count,pos[2]))
	safeWaitCondition("PlayingGame",function()
		local card=getObjectFromGUID(guid)
		if card~=nil then card.lock() end
	end,function()
		local card=getObjectFromGUID(guid)
		return card==nil or card.resting
	end)
end

function reflowUnitOffer(targetCount)
	local cards=unitOfferCards()
	local displayCount=math.max(targetCount or #cards,#cards)
	refreshUnitOfferSnapPoints(displayCount)
	for slot,obj in ipairs(cards) do moveUnitOfferCard(obj,slot,displayCount) end
	safeWaitTime("PlayingGame",function() if claimButtonRefresh~=nil then claimButtonRefresh() end end,0.5)
	return #cards,displayCount
end

function addRegularUnitsToOffer(amount)
	amount=math.max(0,math.floor(amount or 0))
	if amount==0 then return 0 end
	local cards=unitOfferCards()
	local existing=#cards
	local finalCount=existing+amount
	refreshUnitOfferSnapPoints(finalCount)
	for slot,obj in ipairs(cards) do moveUnitOfferCard(obj,slot,finalCount) end
	local added=0
	for slot=existing+1,finalCount do
		standardDeckCycleShuffleIfReached("Regular Unit")
		local zone=getObjectFromGUID(GUID.zone.regularUnit)
		local deck=nil
		if zone~=nil then
			for _,obj in pairs(zone.getObjects()) do if obj.type=="Deck" or obj.type=="Card" then deck=obj break end end
		end
		if deck~=nil then
			local scale=unitOfferCardScale(finalCount)
			safeTakeObject("PlayingGame",deck,{
				position=unitOfferPosition(slot,finalCount,1.25),
				rotation={0,180,0},
				smooth=true,
				callback_function=function(drawnCard)
					drawnCard.setScale({scale,1,scale})
					safeWaitCondition("PlayingGame",function() if drawnCard~=nil then drawnCard.lock() end end,function() return drawnCard==nil or drawnCard.resting end)
				end
			})
			added=added+1
		end
	end
	safeWaitTime("PlayingGame",function() if claimButtonRefresh~=nil then claimButtonRefresh() end end,0.5)
	return added
end

--Unit and Monastery Offer update
function unitOffer()
	refreshUnitOfferSnapPoints(gStates.totalUnitCount)
	local monasteryPlace=	{{36.0, 0.98, -10.2}, {31.2, 0.98, -10.2}, {26.4, 0.98, -10.2}, {21.6, 0.98, -10.2}, {16.8, 0.98, -10.2}, {12.0, 0.98, -10.2}}
	local drawDecks=		{["Regular Unit"]=GUID.zone.regularUnit, ["Elite Unit"]=GUID.zone.eliteUnit, ["Advanced Action"]=GUID.zone.actionDeck}--Zone covering Regular units draw deck, Elite Units Draw Deck, Advanced Actions Draw Deck
	local skip=false
	--Place existing cards under raised decks
	for _, offerCards in pairs(getObjectFromGUID("a3d99b").getObjects()) do--Zone where units and monastery cards are played
		local offerCardType=gameCardType(offerCards)
		if offerCards.type=="Card" and drawDecks[offerCardType]~=nil then
			offerCards.unlock()
			if offerCardType=="Regular Unit" or offerCardType=="Elite Unit" then offerCards.setScale({unitOfferLayoutConfig.cardScale,1,unitOfferLayoutConfig.cardScale}) end
			standardDeckCycleMarkReturned(offerCardType, offerCards)
			getObjectFromGUID(getObjectFromGUID(drawDecks[offerCardType]).getObjects()[1].guid).putObject(offerCards)
		end
		if offerCards.type=="Deck" then
			for j=1, offerCards.getQuantity(), 1 do
				local pos=offerCards.getPosition()
				local params={position={pos.x-j*0.85+1, pos.y+0.15, pos.z}}
				offerCards.takeObject(params)
			end
			broadcastToAll("{en}Sorry, I seem to have double dealt. Manual cleaning of Offer required{ru}Извините, что-то пошло не так. Требуется ручное исправление доступных карт{zh-tw}抱歉，我可能做了双重结算，请手动清除部队供应区{zh-cn}抱歉，我可能做了双重结算，请手动清除部队供应区{ko}죄송합니다, 공급처가 이중으로 겹쳐진 모양이네요. 직접 정리 부탁드립니다.{es}Lo siento, parece que he hecho un doblete. Se requiere limpieza manual de la Oferta{fr}Désolé, j'ai l'impression d'avoir joué deux fois. Nettoyage manuel de l'offre requis{pt-br}Desculpe, Parece que ofertei em dobro. Limpeza Manual da Oferta requerida.{de}Entschuldigung, ich habe wohl doppelt gehandelt. Manuelle Bereinigung des Angebots erforderlich", warningColor)
			skip=true
		end
	end
	if skip==false then
		local params={smooth=true, rotation={0, 180, 0}}
		standardDeckCycleShuffleIfReached("Regular Unit")
		standardDeckCycleShuffleIfReached("Elite Unit")
		standardDeckCycleShuffleIfReached("Advanced Action")
		--Place Unit Cards
		local function getUnitDrawList(drawDecks)
			local unitsInOffer={}
			local deckInfo={}
			local drawList={}
			--Prepare a deck's contents the first time we need it
			local function getDeckInfo(zoneGUID)
				if deckInfo[zoneGUID]~=nil then return deckInfo[zoneGUID] end
				local zone=getObjectFromGUID(zoneGUID)
				local deck=nil
				for _, obj in ipairs(zone.getObjects()) do
					if obj.type=="Deck" or obj.type=="Card" then deck=obj break end
				end
				if deck==nil then return nil end
				local cards={}
				if deck.type=="Deck" then cards=deck.getObjects() else cards={{guid=deck.guid}}	end
				deckInfo[zoneGUID]={deck=deck, cards=cards, nextCard=1, rejected={}}
				return deckInfo[zoneGUID]
			end

			--Find the next unit whose name is not already in the offer
			local function getNextUniqueUnit(zoneGUID, deckName)
				local info=getDeckInfo(zoneGUID)
				if info==nil then return nil end
				while info.nextCard<=#info.cards do
					local card=info.cards[info.nextCard]
					info.nextCard=info.nextCard+1
					local unitData=gameCards[card.guid]
					--Fallback to GUID if this card isn't in gameCards
					local unitName=card.guid
					if unitData~=nil and unitData.name~=nil and unitData.name[1]~=nil then unitName=unitData.name[1] end
					if unitsInOffer[unitName]~=true then
						if standardDeckCycleShuffleIfReached(deckName, info.deck, card.guid)==true then
							info.cards=info.deck.type=="Deck" and info.deck.getObjects() or {{guid=info.deck.guid}}
							info.nextCard=1
						else
							unitsInOffer[unitName]=true
							return {deck=info.deck, guid=card.guid}
						end
					end
				end
				return nil
			end

			--Work out every unit we want BEFORE physically drawing anything
			for a=1, gStates.totalUnitCount do
				local drawDeckName="Regular Unit"
				if gStates.eliteUnitsUsed==true	and (a==1 or a==3 or a==5 or a==7 or a==9) then drawDeckName="Elite Unit" end
				local drawDeckType=drawDecks[drawDeckName]
				local chosenUnit=getNextUniqueUnit(drawDeckType, drawDeckName)
				if chosenUnit~=nil then drawList[a]=chosenUnit else broadcastToAll("{en}Could not find enough unique units for the offer.{ru}Не удалось найти достаточно уникальных отрядов для предложения.{zh-tw}找不到足夠不同的部隊來填滿供應。{zh-cn}找不到足够不同的部队来填满供应。{ko}제안에 필요한 서로 다른 유닛을 충분히 찾지 못했습니다.{es}No se pudieron encontrar suficientes unidades diferentes para la oferta.{fr}Impossible de trouver suffisamment d’unités différentes pour l’offre.{pt-br}Não foi possível encontrar unidades diferentes suficientes para a oferta.{de}Es konnten nicht genügend unterschiedliche Einheiten für das Angebot gefunden werden.",	warningColor) break end
			end
			return drawList, deckInfo
		end
		local unitDrawList=getUnitDrawList(drawDecks)
		for a, draw in ipairs(unitDrawList) do
			safeTakeObject("PlayingGame",draw.deck,{
				guid=draw.guid,
				position=unitOfferPosition(a,gStates.totalUnitCount),
				rotation={0,180,0},
				smooth=true,
				callback_function=function(drawnCard)
					local scale=unitOfferCardScale(gStates.totalUnitCount)
					drawnCard.setScale({scale,1,scale})
					safeWaitCondition("PlayingGame",function()
						drawnCard.lock()
					end, function() return drawnCard.resting end)
				end
			})
		end
		--Place Monastery offer cards
		for i=1, gStates.monasteryCount, 1 do
			params.position=monasteryPlace[i]
			standardDeckCycleShuffleIfReached("Advanced Action")
			local drawnCard=getObjectFromGUID(getObjectFromGUID(drawDecks["Advanced Action"]).getObjects()[1].guid).takeObject(params)
			safeWaitCondition("PlayingGame",function() drawnCard.lock() end, function() return drawnCard.resting end)
		end
	end
end

function shieldDrop(player, mouseButton, id)
	if mouseButton=="-1" then
		for _, details in pairs(mageKnights) do
			local tempPos={}
			if getObjectFromGUID(details.model)~=nil then tempPos=getObjectFromGUID(details.model).getPosition() end
			if getObjectFromGUID(details.token)~=nil then tempPos=getObjectFromGUID(details.token).getPosition() end
			if getObjectFromGUID(details.standee)~=nil then tempPos=getObjectFromGUID(details.standee).getPosition() end
			if details.shieldContainer==id:sub(1, 6) then
				local sitePlayer=nil
				local sitePlayerIndex=nil
				for playerIndex,candidate in pairs(turnOrder) do if candidate.mage==details.mage then sitePlayer=candidate sitePlayerIndex=playerIndex break end end
				if gStates.gameScenario=="The Lost Relic Blitz" and sitePlayer~=nil and (sitePlayer.avatarLocation:sub(1,4)=="city" or sitePlayer.avatarLocation=="Volkare's Camp") then
					broadcastToAll("{en}Defeat the Draconum to recover this Relic piece.{ru}Победите драконида, чтобы вернуть эту часть Реликвии.{zh-tw}擊敗龍人以取回這塊聖物碎片。{zh-cn}击败龙人以取回这块圣物碎片。{ko}드라코넘을 쓰러뜨려 이 유물 조각을 되찾으십시오.{es}Derrota al Draconum para recuperar esta pieza de la Reliquia.{fr}Vainquez le Draconum pour récupérer ce morceau de Relique.{pt-br}Derrote o Draconum para recuperar esta parte da Relíquia.{de}Besiegt das Draconum, um dieses Reliktstück zurückzuerlangen.", warningColor)
					addAvatarButtons()
					return
				end
				if gStates.gameScenario=="The Realm of the Dead Blitz" and sitePlayer~=nil and sitePlayer.avatarLocation=="graveyard" and realmDeadEnemiesAtPosition(tempPos)==true then
					broadcastToAll("{en}Defeat the Graveyard enemies before sealing it.{ru}Победите врагов на Кладбище, прежде чем запечатать его.{zh-tw}封印墓地前先擊敗其中的敵人。{zh-cn}封印墓地前先击败其中的敌人。{ko}묘지를 봉인하기 전에 그곳의 적을 쓰러뜨리십시오.{es}Derrota a los enemigos del Cementerio antes de sellarlo.{fr}Vainquez les ennemis du Cimetière avant de le sceller.{pt-br}Derrote os inimigos do Cemitério antes de selá-lo.{de}Besiegt die Gegner auf dem Friedhof, bevor ihr ihn versiegelt.", warningColor)
					addAvatarButtons()
					return
				end
				if gStates.gameScenario=="Dungeon Lords" and sitePlayer~=nil and (sitePlayer.avatarLocation=="dungeon" or sitePlayer.avatarLocation=="tomb") then
					broadcastToAll("{en}Dungeon Lords: Dungeons and Tombs are marked only after their combat is won.{ru}Владыки Подземелий: Подземелья и Гробницы отмечаются только после победы в их бою.{zh-tw}地下城領主：只有在戰鬥獲勝後才標記地下城與墓穴。{zh-cn}地下城领主：只有在战斗获胜后才标记地下城与墓穴。{ko}던전 로드: 던전과 무덤은 전투에서 승리한 뒤에만 표시됩니다.{es}Señores de las Mazmorras: las Mazmorras y Tumbas solo se marcan después de ganar su combate.{fr}Seigneurs des Donjons : les Donjons et Tombeaux ne sont marqués qu’après avoir remporté leur combat.{pt-br}Senhores das Masmorras: Masmorras e Tumbas só são marcadas após vencer o combate.{de}Kerkerfürsten: Kerker und Gräber werden erst markiert, nachdem ihr Kampf gewonnen wurde.",positionToColor(gStates.turnNumber))
					addAvatarButtons()
					return
				end
				local shield=getObjectFromGUID(details.shieldContainer).takeObject({position={tempPos[1], 3, tempPos[3]}})
				if shield~=nil and gStates.gameScenario=="The Realm of the Dead Blitz" and sitePlayer~=nil and sitePlayer.avatarLocation=="graveyard" and sitePlayerIndex~=nil then
					refreshPlayerReputationFromShield(sitePlayerIndex)
					if sitePlayer.repGain<(7-sitePlayer.reputation) then
						sitePlayer.repGain=sitePlayer.repGain+1
						broadcastToAll(tostring(sitePlayer.mage).." sealed a Graveyard: +1 Reputation pending.", positionToColor(sitePlayerIndex))
						mainUIUpdate("Graveyard sealed")
					end
				end
				safeWaitFrames("PlayingGame",function() safeWaitCondition("PlayingGame",function()
					shield.lock()
					addAvatarButtons()
				end, function() return shield.resting end) end, 10)
				break
			end
			if details.markerContainer==id:sub(1, 6) then
				local marker=getObjectFromGUID(details.markerContainer).takeObject({position={tempPos[1], 3, tempPos[3]}})
				safeWaitFrames("PlayingGame",function() safeWaitCondition("PlayingGame",function()
					marker.lock()
					addAvatarButtons()
				end, function() return marker.resting end) end, 10)
				break
			end
		end
	end
end

--move monster tokens to player board
--gStates.attackedMonsters={}--guid={location, rotation}
--Record/compare the actual map hex so picking an avatar up does not undo a site interaction unless it leaves the hex.
function avatarHexIdentity(pos)
	local terrain, bearing=terrainHexAtPosition(pos)
	if terrain~=nil then return {terrainGUID=terrain.guid, bearing=bearing} end
end
function avatarMovedFromPickedUpHex(pos)
	local droppedHex=avatarHexIdentity(pos)
	if playerPickedUpHex~=nil and droppedHex~=nil then
		return playerPickedUpHex.terrainGUID~=droppedHex.terrainGUID or playerPickedUpHex.bearing~=droppedHex.bearing
	end
	if playerPickedUpPos[1]==nil then return false end
	return math.sqrt(((pos[1]-playerPickedUpPos[1])^2)+((pos[3]-playerPickedUpPos[3])^2))>1.5
end

--Undo temporary site/combat state only after a human moves the current avatar to a different hex.
function leaveAvatarSite(player)
	local playArea=getObjectFromGUID(playerPlayAreas[player.seatPos])
	if playArea~=nil then
		--Undo Possessed before returning the enemy so the attachment becomes a real token again.
		for _, obj in pairs(playArea.getObjects()) do
			if monsterPugs[obj.guid]~=nil then
				local possessedAttached=false
				for _, attachment in pairs(obj.getAttachments()) do
					if monsterPugs[attachment.guid]~=nil and monsterPugs[attachment.guid].pugType=="possessed" then possessedAttached=true break end
				end
				if possessedAttached then
					for _, attachment in pairs(clearPossessedEnemy(obj)) do
						local details=gStates.attackedMonsters[attachment.guid]
						if details~=nil then
							attachment.setRotation(details[2])
							attachment.setPositionSmooth(details[1])
							gStates.attackedMonsters[attachment.guid]=nil
						end
					end
				end
				if gStates.summonStates[obj.guid]=="SummonDone" then gStates.summonStates[obj.guid]=nil end
			end
		end
	end

	for guid, details in pairs(gStates.attackedMonsters) do
		if details[3]=="summoned" then
			gStates.summonStates[guid]=nil
			if details[4]~=nil then gStates.summonStates[details[4]]=nil end
		end
		if getObjectFromGUID(guid)~=nil then
			if getObjectFromGUID(guid).getName()=="{en}Volkare Reminder Token{zh-cn}沃里卡提醒标记{ko}볼케어 공격 토큰{es}Token de recordatorio de Volkare{fr}Jeton de rappel Volkare{pt-br}Token de lembrete de Volkare" then
				getObjectFromGUID(guid).destruct()
			else
				getObjectFromGUID(guid).setRotation(details[2])
				getObjectFromGUID(guid).setPositionSmooth(details[1])
			end
		end
	end
	gStates.attackedMonsters={}
	gStates.monsterOffsetX=0
	gStates.monsterOffsetZ=0
	gStates.volkarePursuitCombat=nil
	gStates.volkarePursuitChoicePlayer=nil
	combatCameraChoiceSuppressedPlayer=nil
	player.combatIconHide="None"

	--Pyramid/Ziggurat trap reminders only belong to the site being interacted with.
	if playArea~=nil then
		for _, obj in pairs(playArea.getObjects()) do
			if obj.getGMNotes()=="Trap Reminder Token" then
				gStates.monsterPerks[obj.guid]=nil
				obj.destruct()
			end
		end
	end
	UI.setAttribute("zigguratPyramidInteract", "active", "false")
	gStates.zigguratPyramidUI=nil
end

function monasteryOfferFirstEmptySlot()
	local occupied={}
	local zone=getObjectFromGUID(GUID.zone.unitOffer)
	if zone~=nil then
		for _,obj in pairs(zone.getObjects()) do
			if obj.type=="Card" or obj.type=="Deck" then
				local pos=obj.getPosition()
				if math.abs(pos[3]+10.2)<=1 then
					local slot=math.floor(((40.8-pos[1])/4.8)+0.5)
					if slot>=1 and slot<=6 then occupied[slot]=true end
				end
			end
		end
	end
	for slot=1,6 do if occupied[slot]~=true then return slot end end
	return nil
end

function playMonastery()
	gStates.monasteryCount=gStates.monasteryCount+1
	if gStates.monasteryCount>=0 then
		--Find the first free printed Monastery slot directly from the broad offer zone.
		local slot=monasteryOfferFirstEmptySlot()
		if slot==nil then return end
		local params={rotation={0,180,0},position={40.8-slot*4.8,0.98,-10.2}}
		local drawDecks={GUID.zone.regularUnit,GUID.zone.eliteUnit,GUID.zone.actionDeck} --Zone covering Regular units draw deck, Elite Units Draw Deck, Advanced Actions Draw Deck
		--Play an advanced action card
		standardDeckCycleShuffleIfReached("Advanced Action")
		local MonasteryDeck=getObjectFromGUID(GUID.zone.actionDeck).getObjects()
		while MonasteryDeck==nil do safeWaitFrames("PlayingGame",function() MonasteryDeck=getObjectFromGUID(GUID.zone.actionDeck).getObjects() end, 10) end
		local drawnCard=getObjectFromGUID(MonasteryDeck[1].guid).takeObject(params)
		safeWaitCondition("PlayingGame",function() drawnCard.lock() end, function() return drawnCard.resting end)
		broadcastToAll("{en}Monastery is teaching a new Advanced Action{ru}Монастырь обучает новому Особому действию{zh-tw}修道院现在传授新的高级行动{zh-cn}修道院现在传授新的高级行动{ko}수도원에 새로운 상급 액션이 추가되었습니다{es}El Monasterio está enseñando una nueva Acción Avanzada{fr}Le Monastère enseigne une nouvelle Action Avancée{pt-br}Monastério está encinsando uma nova Ação Avançada{de}Das Kloster lehrt eine neue fortgeschrittene Aktion", {1,1,0.5})
	end
end

function zigguratPyramidInteract(_, mouseButton, id)
	if mouseButton=="-1" then
		local trapBag=monsterPiles.pyramidTrap
		local firstFight=monsterPiles.gray
		local secondFight=monsterPiles.white
		local thirdFight=monsterPiles.red
		if turnOrder[gStates.turnNumber].avatarLocation=="ziggurat" then
			trapBag=monsterPiles.zigguratTrap
			firstFight=monsterPiles.green
			secondFight=monsterPiles.purple
			thirdFight=monsterPiles.tan
		end
		--remove face down traps
		local playAreaObjects={}
		if getObjectFromGUID(playerPlayAreas[turnOrder[gStates.turnNumber].seatPos])~=nil then playAreaObjects=getObjectFromGUID(playerPlayAreas[turnOrder[gStates.turnNumber].seatPos]).getObjects() end
		for _, obj in pairs(playAreaObjects) do
			if obj.getGMNotes()=="Trap Reminder Token" and obj.is_face_down==true then obj.destruct() end
			local adjust=0
			if id=="zigguratPyramidInteractFight3" then adjust=0 end
			if obj.getGMNotes()=="Trap Reminder Token" and obj.is_face_down==false and obj.getPosition()[3]<=-39-gStates.monsterOffsetZ+adjust+0.5 then
				obj.setPosition({(turnOrder[gStates.turnNumber].seatPos*40)-101, 2.5, -39-gStates.monsterOffsetZ+adjust})
			end
		end
		--adjust interface
		if id=="zigguratPyramidInteractClimb1" then
			UI.setAttribute("zigguratPyramidInteractClimb1Image", "color", "Gray")
			UI.setAttribute("zigguratPyramidInteractClimb1", "interactable", "false")
			UI.setAttribute("zigguratPyramidInteractFight1Image", "color", "Gray")
			UI.setAttribute("zigguratPyramidInteractFight1", "interactable", "false")
			if UI.getAttribute("zigguratPyramidInteractClimb2Image", "color")=="Gray" then
				UI.setAttribute("zigguratPyramidInteractClimb2Image", "color", "White")
				UI.setAttribute("zigguratPyramidInteractClimb2", "interactable", "true")
			end
			if UI.getAttribute("zigguratPyramidInteractFight2Image", "color")=="Gray" then
				UI.setAttribute("zigguratPyramidInteractFight2Image", "color", "White")
				UI.setAttribute("zigguratPyramidInteractFight2", "interactable", "true")
			end
			drawMonster(trapBag, turnOrder[gStates.turnNumber], id)
			gStates.monsterOffsetZ=gStates.monsterOffsetZ+2.5
			gStates.monsterOffsetX=0
			safeWaitFrames("PlayingGame",function() drawMonster(trapBag, turnOrder[gStates.turnNumber], id) end, 10)
		end
		if id=="zigguratPyramidInteractClimb2" then
			UI.setAttribute("zigguratPyramidInteractClimb2Image", "color", "Gray")
			UI.setAttribute("zigguratPyramidInteractClimb2", "interactable", "false")
			UI.setAttribute("zigguratPyramidInteractFight2Image", "color", "Gray")
			UI.setAttribute("zigguratPyramidInteractFight2", "interactable", "false")
			UI.setAttribute("zigguratPyramidInteractFight3Image", "color", "White")
			UI.setAttribute("zigguratPyramidInteractFight3", "interactable", "true")
			gStates.monsterOffsetX=0
			gStates.monsterOffsetZ=gStates.monsterOffsetZ+2.5
			drawMonster(trapBag, turnOrder[gStates.turnNumber], id)
		end
		if id=="zigguratPyramidInteractFight1" then
			UI.setAttribute("zigguratPyramidInteractClimb1Image", "color", "Gray")
			UI.setAttribute("zigguratPyramidInteractClimb2Image", "color", "Gray")
			UI.setAttribute("zigguratPyramidInteractFight2Image", "color", "Gray")
			UI.setAttribute("zigguratPyramidInteractFight3Image", "color", "Gray")
			UI.setAttribute("zigguratPyramidInteractClimb1", "interactable", "false")
			UI.setAttribute("zigguratPyramidInteractFight1", "interactable", "false")
			UI.setAttribute("zigguratPyramidInteractFight1Image", "color", "Yellow")
			drawMonster(monsterPiles.possessed, turnOrder[gStates.turnNumber], id, "Apoc")
			drawMonster(firstFight, turnOrder[gStates.turnNumber], id)
		end
		if id=="zigguratPyramidInteractFight2" then
			UI.setAttribute("zigguratPyramidInteractClimb2Image", "color", "Gray")
			UI.setAttribute("zigguratPyramidInteractFight3Image", "color", "Gray")
			UI.setAttribute("zigguratPyramidInteractClimb2", "interactable", "false")
			UI.setAttribute("zigguratPyramidInteractFight2", "interactable", "false")
			UI.setAttribute("zigguratPyramidInteractFight2Image", "color", "Yellow")
			drawMonster(monsterPiles.possessed, turnOrder[gStates.turnNumber], id, "Apoc")
			drawMonster(secondFight, turnOrder[gStates.turnNumber], id)
		end
		if id=="zigguratPyramidInteractFight3" then
			UI.setAttribute("zigguratPyramidInteractFight3", "interactable", "false")
			UI.setAttribute("zigguratPyramidInteractFight3Image", "color", "Yellow")
			drawMonster(monsterPiles.possessed, turnOrder[gStates.turnNumber], id, "Apoc")
			drawMonster(thirdFight, turnOrder[gStates.turnNumber], id)
		end
	end
end

local OfferPause=false
function offerAdjust(player, mouseButton, id)
	if mouseButton=="-1" and OfferPause==false then
		OfferPause=true
		--update Offer size expected.
		if id=="e4372aOfferUp" then gStates.offerSize=gStates.offerSize+1 else gStates.offerSize=gStates.offerSize-1 end
		--move both decks and their detecting Zones, drop the decks onto existing cards.
		getObjectFromGUID(GUID.deck.spell).setPositionSmooth({(4.8*(gStates.offerSize+1))+21.6, 2.5, -22.2})
		getObjectFromGUID(GUID.deck.action).setPositionSmooth({(4.8*(gStates.offerSize+1))+21.6, 2.5, -16.2})
		getObjectFromGUID(GUID.zone.spellDeck).setPosition({(4.8*(gStates.offerSize+1))+21.6, 2.05, -22.2})
		getObjectFromGUID(GUID.zone.actionDeck).setPosition({(4.8*(gStates.offerSize+1))+21.6, 2.05, -16.2})
		--change size of offer Zone
		getObjectFromGUID(GUID.zone.offer).setScale({4.8*gStates.offerSize, 0.3, 9.57})
		getObjectFromGUID(GUID.zone.offer).setPosition({(2.4*(gStates.offerSize-1))+26.4, 1.13, -19.2})
		if id=="e4372aOfferUp" then
			--run fill slide after a wait frame.
			fillSlide()
			--Wait.condition(function() fillSlide() end, function() return getObjectFromGUID(GUID.deck.spell).resting end)
		else
			--flip existing cards if shrinking the offer.
			for _, card in pairs(getObjectFromGUID(GUID.zone.offer).getObjects()) do
				if math.floor(((card.getPosition()[1]-21.6)/4.8)+0.5)==gStates.offerSize+1 and card.type=="Card" then
					standardDeckCycleMarkReturned(gameCardType(card), card)
					card.unlock()
					card.setRotation({0.00, 180.00, 180.00})
				end
			end
		end
		safeWaitFrames("PlayingGame",function()
			OfferPause=false
			getObjectFromGUID(GUID.deck.spell).UI.setXmlTable({	{tag="Button", attributes={id="e4372aOfferUp", onClick="global/offerAdjust", onMouseDown="global/buttonClicked", onMouseUp="global/buttonClicked", height=150, width=240, position="60 190 -10", rotation="0 180 180", scale="0.32 0.32"},
															children={	{tag="Image", attributes={id="e4372aOfferUpImage", image="Sliced Button/Button Object Active", type="Sliced"}},
																		{tag="Text", attributes={fontSize="90", fontStyle="Normal", alignment="MiddleCenter", text=">"}}}},
															{tag="Button", attributes={id="e4372aOfferDown", onClick="global/offerAdjust", onMouseDown="global/buttonClicked", onMouseUp="global/buttonClicked", height=150, width=240, position="-60 190 -10", rotation="0 180 180", scale="0.32 0.32"},
															children={	{tag="Image", attributes={id="e4372aOfferDownImage", image="Sliced Button/Button Object Active", type="Sliced"}},
																		{tag="Text", attributes={fontSize="90", fontStyle="Normal", alignment="MiddleCenter", text="<"}}}}})
		end, 60)
	end
end

--Change a hand's color and refresh.
function changePositionColor(player, mouseButton, id)
	local barConversion={[colorBand[1]]=1, [colorBand[2]]=2, [colorBand[3]]=3, [colorBand[4]]=4}
	local barGUID=id:sub(1,6)
	local newColor=id:sub(7, string.len(id))
	local currentColor=Hands.getHands()[barConversion[barGUID]].getValue()
	if mouseButton=="-1" and legalPlayerCheck(player.color, gStates.handColors[currentColor], "NoDummyException")==true then
		--swap an existing unused color to stop two hands having the same colour
		if gStates.handColors[newColor]~=nil then
			for _, freeHandColor in pairs(Player.getColors()) do
				if gStates.handColors[freeHandColor]==nil then
					Hands.getHands()[gStates.handColors[newColor]].setValue(freeHandColor)
					gStates.handColors[freeHandColor]=gStates.handColors[newColor]
					gStates.handColors[newColor]=nil
					break
				end
			end
		end
		--change hand colour
		gStates.handColors[newColor]=gStates.handColors[currentColor]
		gStates.handColors[currentColor]=nil
		Hands.getHands()[barConversion[barGUID]].setValue(newColor)
		Player[currentColor].changeColor(newColor)
		applyColorBarButtons()
		refreshPlayerSeatColors()
		outOfTurnUIStateKey=nil
		mainUIUpdate("Player Changed Colour")
		safeWaitFrames("PlayingGame",function() Player[newColor].lookAt({position={getObjectFromGUID(barGUID).getPosition()[1], getObjectFromGUID(barGUID).getPosition()[2], getObjectFromGUID(barGUID).getPosition()[3]-10}, pitch=75, yaw=0, distance=30}) end, 2)
	end
end

function changeMatImage(player, mouseButton, id)
	local barConversion={[colorBand[1]]=1, [colorBand[2]]=2, [colorBand[3]]=3, [colorBand[4]]=4}
	if mouseButton=="-1" and legalPlayerCheck(player.color, gStates.handColors[Hands.getHands()[barConversion[id:sub(1,6)]].getValue()], "NoDummyException")==true then
		local convert={[colorBand[1]]=playerBoard[1], [colorBand[2]]=playerBoard[2], [colorBand[3]]=playerBoard[3], [colorBand[4]]=playerBoard[4]}
		local board=getObjectFromGUID(convert[id:sub(1, 6)])
		local direction=1
		local boardImages={	"https://steamusercontent-a.akamaihd.net/ugc/1684895445424376912/3EE3230EE7EDE9465FBACB66989433E76889EE1B/",
							"https://steamusercontent-a.akamaihd.net/ugc/1684895445424553574/3C342119E5460E99D2CBA90E02703DEFE192A8D2/",
							"https://steamusercontent-a.akamaihd.net/ugc/1684895445424553344/A14FCE5B44805580B609C6331AE493DBF57DFF16/",
							"https://steamusercontent-a.akamaihd.net/ugc/1684895445424553120/FDF4B2E37BB40F81AD7A1DFC45FD3080EDBDD479/",
							"https://steamusercontent-a.akamaihd.net/ugc/1684895445424552867/531D8782F39294923F405B4A8BD33749FFCDC397/",
							"https://steamusercontent-a.akamaihd.net/ugc/1684895445424552298/DCE7288AD482269EF78E138258AEF64E02FB75F0/",
							"https://steamusercontent-a.akamaihd.net/ugc/1684895445424551898/6ED5EFA1552854F7F03E318B5DF1181E4A6388F1/",
							"https://steamusercontent-a.akamaihd.net/ugc/1684895445424551449/B2E1AD69C97515E4AA0B3B99B899DF3F00303E3A/",
							"https://steamusercontent-a.akamaihd.net/ugc/1684895445424553771/4BC2365C114D1D2EFA40127F12FE662927D7A658/",
							"https://steamusercontent-a.akamaihd.net/ugc/1684895445424553972/80BE3DDEAA19CADEAACE68ED263F52DB65465CF6/",
							"https://steamusercontent-a.akamaihd.net/ugc/1684895445424554181/1E919EDF42F1F900A53EE84DC6B24E0CCAE551B0/",
							"https://steamusercontent-a.akamaihd.net/ugc/1684895445424555147/6F7C91142DBDC2CC969E4C55760359791F0D89F8/",
							"https://steamusercontent-a.akamaihd.net/ugc/1684895445424601741/960077146FB0A7EFA4F5F54B6BD5B477BDFF5A6F/",
							"https://steamusercontent-a.akamaihd.net/ugc/1684895445424554674/5FC29A5A6972EED68545A897F9280FA3C954179F/",
							"https://steamusercontent-a.akamaihd.net/ugc/1684895445424554433/5E1CAFCDD9764C7370E9CA387E1E250FFBE95EEA/",
							"https://steamusercontent-a.akamaihd.net/ugc/1684895445424467915/9C5DD81B7345C49DB8ED3F9A5BA9E1E867855EF7/",
							"https://steamusercontent-a.akamaihd.net/ugc/1684895445424555440/E6D119CAA5633518305C512D82D87D033BCD27F2/",
							"https://steamusercontent-a.akamaihd.net/ugc/1684895445440810937/BD5AB7FC76EBA62C6041C19BEDFF187A191B9A3C/",
							"https://steamusercontent-a.akamaihd.net/ugc/1684895445440811336/57CCCDB1CA59C7EC8D78F36A8F41D867232E751A/",
							"https://steamusercontent-a.akamaihd.net/ugc/1684895445440811734/D2494176727E75376EC01F16BBB70E8AE1799238/",
							"https://steamusercontent-a.akamaihd.net/ugc/2546304515596768692/19801470032E2AD7FBC69C3817AD64A01998963F/",
							"https://steamusercontent-a.akamaihd.net/ugc/2546304515596768226/A7A269B1B5492AF4E3692015A1588B3EBD7A0414/"}
		if id:sub(7, 17)=="changeMatUp" then direction=-1 end
		for a=1, #boardImages, 1 do
			if boardImages[a]==board.getCustomObject().image and ((a>1 and direction==-1) or (a<#boardImages and direction==1)) then
				board.setCustomObject({image=boardImages[a+direction]})
				break
			end
			if boardImages[a]==board.getCustomObject().image and a==#boardImages then
				board.setCustomObject({image=boardImages[1]})
				break
			end
			if boardImages[a]==board.getCustomObject().image and a==1 then
				board.setCustomObject({image=boardImages[#boardImages]})
				break
			end
		end
		board.reload()
		safeWaitTime("PlayingGame",function() getObjectFromGUID(convert[id:sub(1, 6)]).interactable=false end, 0.2)
	end
end

function bannerOfCommandDecal()
	if getObjectFromGUID("8dbce4").is_face_down==true then
		getObjectFromGUID("8dbce4").UI.setXmlTable({{tag="Image", attributes={id="Command", image="Banner Command",
			height=240, width=125, position="0 -520 40", rotation="0 180 180"}}})
	else
		getObjectFromGUID("8dbce4").UI.setXmlTable({{tag="Image", attributes={id="Command", image="Banner Command",
			height=240, width=125, position="0 -1066 -40", rotation="0 0 180"}}})
	end
end

function findNearbyMages(origin, distance)--origin={x, y, z}, distance=x
	local mageList={}
	--for _, posibleMage in pairs(getObjectFromGUID(mapArea).getObjects()) do
	--see if the object is a mageKnight
	for _, avatar in pairs(mageKnights) do
		local posibleMage=nil
		if getObjectFromGUID(avatar.model)~=nil and avatar.mage~="Volkare" then posibleMage=getObjectFromGUID(avatar.model) end
		if getObjectFromGUID(avatar.standee)~=nil and avatar.mage~="Volkare" then posibleMage=getObjectFromGUID(avatar.standee) end
		if getObjectFromGUID(avatar.token)~=nil and avatar.mage~="Volkare" then posibleMage=getObjectFromGUID(avatar.token) end
		if posibleMage~=nil then
			local pos={posibleMage.getPosition()[1], 1.17, posibleMage.getPosition()[3]}--done this way so math can be done to the values
			local mageDist=math.sqrt(((origin[1]-pos[1])^2)+((origin[3]-pos[3])^2))
			if mageDist<distance then
				for turn, mageSearch in pairs(turnOrder) do
					if mageSearch.mage==avatar.mage and playerDropoutInactive(turn)==false then
						mageList[#mageList+1]={mage=mageSearch.mage, distance=mageDist, fame=mageSearch.fame, turn=turn}
					end
				end
			end
		end
	end
	for _, posibleMage in pairs(getObjectFromGUID(mapArea).getObjects()) do
		for zone, cityData in pairs(cityScriptZones) do
			if posibleMage.guid==cityData.cityGUID then
				local pos={posibleMage.getPosition()[1], 1.17, posibleMage.getPosition()[3]}--done this way so math can be done to the values
				local mageDist=math.floor(math.sqrt(((origin[1]-pos[1])^2)+((origin[3]-pos[3])^2))+0.5)
				if mageDist<distance then
					for _, cityObj in pairs(getObjectFromGUID(zone).getObjects()) do
						for _, avatar in pairs(mageKnights) do
							if (cityObj.guid==avatar.model or cityObj.guid==avatar.standee or cityObj.guid==avatar.token) and avatar.mage~="Volkare" then
								for turn, mageSearch in pairs(turnOrder) do
									if mageSearch.mage==avatar.mage and playerDropoutInactive(turn)==false then
										mageList[#mageList+1]={mage=mageSearch.mage, distance=mageDist, fame=mageSearch.fame, turn=turn}
										break
									end
								end
								break
							end
						end
					end
				end
				break
			end
		end
	end
	--Closest first; ties use highest Fame, then earlier turn order. One comparator avoids relying on sort stability.
	table.sort(mageList, function(k1,k2)
		if math.abs(k1.distance-k2.distance)>0.01 then return k1.distance<k2.distance end
		if k1.fame~=k2.fame then return k1.fame>k2.fame end
		return k1.turn<k2.turn
	end)
	return mageList
end

bagSearch=nil
local possessedBagBottomY={}
local delayFaceChange=nil
local discardFace={}
function scaleBags(bag, obj, state)
	if bag==nil then return end
	local currentBag=getObjectFromGUID(bag.guid)
	if currentBag==nil then return end
	if currentBag.type~="Bag" and currentBag.type~="Deck" then return end
	local bagContents=currentBag.getObjects()
	if bagContents==nil then return end
	local bagNotes=bag.getGMNotes()
	if bagNotes=="monsterBag" or bagNotes=="Skills" or bagNotes=="terrainBag" or bagNotes=="Command Tokens" then
		--color tint the bag
		local contents=#bagContents
		if state=="enter" and bag.guid==bagSearch then contents=contents+1 end
		if contents==0 then bag.setColorTint({r=0.4, g=0.4, b=0.4}) contents=1 else bag.setColorTint({r=1, g=1, b=1}) end
		if bagNotes=="terrainBag" then
			if gStates.nightTint==true and gStates.firstStarted==true then
				bag.setColorTint({r=0.6, g=0.6, b=0.6})
				if state=="exit" then obj.setColorTint({r=0.6, g=0.6, b=0.6}) end
			else
				if state=="exit" then obj.setColorTint({r=1.0, g=1.0, b=1.0}) end
			end
		end
		--scale the bag
		local bagScaleDetails={	["monsterBag"]=		{scaleMult=1, 		bagPos=1, 		bagScaleMult=0.15},
								["Command Tokens"]=	{scaleMult=1, 		bagPos=1, 		bagScaleMult=0.15},
								["Skills"]=			{scaleMult=0.55, 	bagPos=1, 		bagScaleMult=0.05},
								["terrainBag"]=		{scaleMult=2.5, 	bagPos=0.97, 	bagScaleMult=0.125}}
		local bagScaleY=contents*bagScaleDetails[bagNotes].scaleMult
		--The normal Ruin pile stays planted because its mesh scales from the table-facing base. The Possessed
		--main/discard piles use a centered mesh pivot, so keep each pile's bottom edge fixed explicitly.
		local possessedStack=bag.guid==monsterPiles.possessed or bag.guid==GUID.bag.discard.possessed
		if possessedStack and possessedBagBottomY[bag.guid]==nil then
			local bounds=bag.getBoundsNormalized()
			possessedBagBottomY[bag.guid]=bounds.center[2]-(bounds.size[2]/2)
		end
		bag.setScale({x=bag.getScale()[1], y=bagScaleY, z=bag.getScale()[3]})
		if possessedStack then
			safeWaitFrames("PlayingGame",function()
				if bag==nil or bag.isDestroyed() then return end
				local bounds=bag.getBoundsNormalized()
				local newBottom=bounds.center[2]-(bounds.size[2]/2)
				local targetBottom=possessedBagBottomY[bag.guid]
				if targetBottom~=nil and math.abs(targetBottom-newBottom)>0.001 then
					local pos=bag.getPosition()
					bag.setPosition({pos[1],pos[2]+targetBottom-newBottom,pos[3]})
				end
			end,1)
		end
		--TTS changes the effective ALT orientation of these tall bag meshes when the stack drops from 12 to 11 tokens.
		--Re-select the explicit high/low-count angle after every monster-bag scale change.
		if bagNotes=="monsterBag" then applyAltViewAngle(bag) end
		if bagNotes=="Skills" or bagNotes=="terrainBag" then bag.setPosition({bag.getPosition()[1], bagScaleDetails[bagNotes].bagPos+(contents*bagScaleDetails[bagNotes].bagScaleMult), bag.getPosition()[3]}) end
		if state=="exit" and bagSearch~=bag.guid then obj.setPosition({bag.getPosition()[1], 2.00+(contents*bagScaleDetails[bagNotes].bagScaleMult), bag.getPosition()[3]}) end
	end

	--Change the face of discard bags to simulate stacks
	local faceUpdateBags={[GUID.bag.discard.orcs]={empty="https://steamusercontent-a.akamaihd.net/ugc/17394071079569158125/E741F2F3BC2D802154845C79BF5FE8E0D2897C14/", last=""},--Orcs
							[GUID.bag.discard.dungeon]={empty="https://steamusercontent-a.akamaihd.net/ugc/11745447351685623762/7A4F92FE411C15551904DF42DE956D68FF7108C0/", last=""},--Dungeon
							[GUID.bag.discard.draconum]={empty="https://steamusercontent-a.akamaihd.net/ugc/18216193721391379495/100F7CA9D63623D161040786361C08E5E7D59292/", last=""},--Dragon
							[GUID.bag.discard.keepGarrison]={empty="https://steamusercontent-a.akamaihd.net/ugc/18166193477599219316/C7CC99FBECF2E509EC45A7DFA73D38ABBB82B5F6/", last=""},--Keep
							[GUID.bag.discard.towerGarrison]={empty="https://steamusercontent-a.akamaihd.net/ugc/13983820052964173806/843E10E03FE9D005D226D828003CCFE69CF98413/", last=""},--Mages
							[GUID.bag.discard.cityGarrison]={empty="https://steamusercontent-a.akamaihd.net/ugc/13829892540840002628/51D5CBA828224CFC04C74EC99B83B15F9E582218/", last=""},--City
							[GUID.bag.discard.ruin]={empty="https://steamusercontent-a.akamaihd.net/ugc/16408024805248842569/8ED6E462581719446CA9B2D9ED3A4789FBC855CE/", last=""},--Ruins
							[GUID.bag.discard.darkReward]={empty="https://steamusercontent-a.akamaihd.net/ugc/938341811900383197/E0745EA1293600D6004CC8C56D11462620900FB9/", last=""},--Dark Crusader Rewards
							[GUID.bag.discard.elementalistReward]={empty="https://steamusercontent-a.akamaihd.net/ugc/938341811900383323/F1D0AFC443E37F19C882E713D8D9F468CFD8D574/", last=""},--Elementalist Rewards
							[GUID.bag.discard.apocReward]={empty="https://steamusercontent-a.akamaihd.net/ugc/12094604589800574619/D8E7BF873319442DF81F35DE7E6BC14A53F31561/", last=""},--Apocalypse Cult Rewards
							[GUID.bag.discard.councilReward]={empty="https://steamusercontent-a.akamaihd.net/ugc/17402070254408062099/CEA25FAE0DFAC406E16D1D4AFACF8914AA536C11/", last=""},--Council of the Void Rewards
							[GUID.bag.discard.possessed]={empty="https://steamusercontent-a.akamaihd.net/ugc/15274516273430316784/0BF7DE5777EFF417E514C3510A3E82EFABF02A7B/", last=""},--Possessed
							[GUID.bag.discard.darkMarauders]={empty="https://steamusercontent-a.akamaihd.net/ugc/14928619505389787044/457C605B7972A34C1FC3C1A6E794454CDB315A29/", last=""},--Dark Crusader Green
							[GUID.bag.discard.darkDungeon]={empty="https://steamusercontent-a.akamaihd.net/ugc/15658631720343793034/87B0A8991BB4F5E5B68521B5123985788B78730D/", last=""},--Dark Crusader Tan
							[GUID.bag.discard.darkDraconum]={empty="https://steamusercontent-a.akamaihd.net/ugc/15743640597225539307/4589E50E316BC31A511475B618E0D2ED81806867/", last=""},--Dark Crusader Red
							[GUID.bag.discard.elementalistOrcs]={empty="https://steamusercontent-a.akamaihd.net/ugc/9376260431025960719/2209BFC139062A9ED0293AF9B6A0497DC8F28BB3/", last=""},--Elementalist Green
							[GUID.bag.discard.elementalistDungeon]={empty="https://steamusercontent-a.akamaihd.net/ugc/15828100274106315938/16138FF5D8C1A5100DABE503A55E11855C547378/", last=""},--Elementalist Tan
							[GUID.bag.discard.elementalistDraconum]={empty="https://steamusercontent-a.akamaihd.net/ugc/12276219328362097098/5086999374988FB9F208F17BB79E1427823288CB/", last=""},--Elementalist Red
							["927f52"]={empty="https://steamusercontent-a.akamaihd.net/ugc/2308724878077127112/0A9DFF145270A1373728EFCF95263C7C65F80D35/", last=""},--Norowas Command
							["51a8a0"]={empty="https://steamusercontent-a.akamaihd.net/ugc/2308724878077012222/4ECDBBF2A67C8914B662C828EDE77D0A8594FF90/", last=""},--Goldyx Command
							["1de952"]={empty="https://steamusercontent-a.akamaihd.net/ugc/2308724878077366749/EEF40846649F811D28B6247364E6B7E61223189E/", last=""},--Tovak Command
							["855a00"]={empty="https://steamusercontent-a.akamaihd.net/ugc/2308724878077445983/643A10EA4408CE9E224757AD9B24C4C9B89CED51/", last=""},--Wolfhawk Command
							["4b6d60"]={empty="https://steamusercontent-a.akamaihd.net/ugc/2308724878077103782/FD56191F069E4739F4899914CE4BB472E9794DC3/", last=""},--Coral Command
							["ab4b31"]={empty="https://steamusercontent-a.akamaihd.net/ugc/2308724878076980481/1FC7F984894FAA1242795CEAAEB63D797F599FE1/", last=""},--Braevalar Command
							["b76529"]={empty="https://steamusercontent-a.akamaihd.net/ugc/2308724878077103782/FD56191F069E4739F4899914CE4BB472E9794DC3/", last=""},--Krang Command
							["73e384"]={empty="https://steamusercontent-a.akamaihd.net/ugc/2308724878077521120/AD30FAA0799E1D6358B3FF9F3123F4C1C97AC7E3/", last=""},--Ymirgh Command
							["73442d"]={empty="https://steamusercontent-a.akamaihd.net/ugc/2546304515602308695/928F544BABD137632F1F35A7F13133FEFCA64867/", last=""},--Mevok Command
							["30feec"]={empty="https://steamusercontent-a.akamaihd.net/ugc/16723819408713751858/3F43F49B76B46CEBBA7A6118D65EF6B20351DE0F/", last=""},--Zirtae Command
							["c02f61"]={empty="https://steamusercontent-a.akamaihd.net/ugc/2546304515602322632/97711A8C0A9500D7F195AA55B3AD032A3FF2789D/", last=""},--Duscenia Command
							["453e1f"]={empty="https://steamusercontent-a.akamaihd.net/ugc/2308724878076712667/8DBB295DD4C83BF9DE02CE9B29B3DCC2CF279C49/", last=""},--Arythea Command
							["e4f01a"]={empty="https://steamusercontent-a.akamaihd.net/ugc/2308724878077032409/4C39163B0CCE024E04D2F54BDA80419D2C5D4B04/", last=""},--Jormund Command
							["d6e01e"]={empty="https://steamusercontent-a.akamaihd.net/ugc/14479946909127380756/3B50E70C9A791C876BE2A3BF5DA8D0E01F7743D8/", last=""},--Malek Command
							[GUID.bag.terrain.stack]={empty="https://steamusercontent-a.akamaihd.net/ugc/1688270643043527253/68E270678D47C66202EAF01B86981ADF5509CE89/", last=""}}--Terrain Stack
	if faceUpdateBags[bag.guid]~=nil then
		if state~="shuffle" and obj.getGMNotes()~="Command Token" and obj.getName()~="MapTile" then bag.setColorTint({r=0.5, g=0.5, b=0.5}) end
		if state=="enter" then
			discardFace[bag.guid]=obj.getCustomObject().image
			if obj.type=="Generic" then discardFace[bag.guid]=obj.getCustomObject().diffuse end
		end
		if (state=="exit" or state=="shuffle") and #bagContents>0 then
			local clone=bag.clone({})
			clone.setGMNotes("")
			local cloneObject=clone.takeObject({smooth=false})
			clone.destruct()
			discardFace[bag.guid]=cloneObject.getCustomObject().image
			if cloneObject.type=="Generic" then discardFace[bag.guid]=cloneObject.getCustomObject().diffuse end
			cloneObject.destruct()
		end
		if #bagContents==0 then discardFace[bag.guid]=faceUpdateBags[bag.guid].empty end

		if delayFaceChange~=nil then Wait.stop(delayFaceChange) end
		delayFaceChange=safeWaitFrames("PlayingGame",function()
			for guid, image in pairs(discardFace) do
				getObjectFromGUID(guid).setCustomObject({diffuse=image})
				getObjectFromGUID(guid).reload()
				local bagGUID=guid
				safeWaitFrames("PlayingGame",function() applyAltViewAngle(getObjectFromGUID(bagGUID)) end, 1)
			end
			discardFace={}
			delayFaceChange=nil
		end, 2)
	end
end

local volkareDiceRolled=false
function volkareTokenRandomize(token)--9a686a
	local VolkareReminder={	["Black Mana"]="https://steamusercontent-a.akamaihd.net/ugc/1617311203414015137/203E9CF64831CC5BBB43AAEC5CCBC9B450B2304E/",
							["Blue Mana"]="https://steamusercontent-a.akamaihd.net/ugc/1617311203413988434/BF2446CF89EF2F4398C38B32F5CAB104FCCE94AC/",
							["White Mana"]="https://steamusercontent-a.akamaihd.net/ugc/1617311203414024554/8541C7CC8BC88442619F8921DAA50CAE0BCD88E9/",
							["Green Mana"]="https://steamusercontent-a.akamaihd.net/ugc/1617311203414009198/C52B548C26AC08BCE1237A114A47DC973D0CE7D9/",
							["Red Mana"]="https://steamusercontent-a.akamaihd.net/ugc/1617311203414000318/7F26EE486FD34E0FD08E0653EF4DACCB69F38A87/",
							["Gold Mana"]="https://steamusercontent-a.akamaihd.net/ugc/1617311203413995197/64E0C4E59A98DAFB09633F31CA9D1279F0593CFD/",}
	--roll volkares dice and read result
	local volkareDice=getObjectFromGUID("9a686a")
	if volkareDiceRolled==false then volkareDice.randomize() volkareDiceRolled=true end
	safeWaitFrames("PlayingGame",function() safeWaitCondition("PlayingGame",function()
		if token~=nil then
			token.setCustomObject({image=VolkareReminder[volkareDice.getRotationValue()]})
			token.reload()
			if gStates.monsterPerks[token.guid]==nil then gStates.monsterPerks[token.guid]={} end
			gStates.monsterPerks[token.guid].arcaneImmunity=true
			gStates.monsterPerks[token.guid].brutal=true
			gStates.monsterPerks[token.guid].assassination=true
			if volkareDice.getRotationValue()=="Red Mana" then gStates.monsterPerks[token.guid].attack={F={3}} end
			if volkareDice.getRotationValue()=="Blue Mana" then gStates.monsterPerks[token.guid].attack={I={3}} end
			if volkareDice.getRotationValue()=="Green Mana" then gStates.monsterPerks[token.guid].poison=true gStates.monsterPerks[token.guid].attack={P={4}} end
			if volkareDice.getRotationValue()=="White Mana" then gStates.monsterPerks[token.guid].swiftness=true gStates.monsterPerks[token.guid].attack={P={3}} end
			if volkareDice.getRotationValue()=="Black Mana" then gStates.monsterPerks[token.guid].paralyse=true	gStates.monsterPerks[token.guid].attack={P={3}} end
			if volkareDice.getRotationValue()=="Gold Mana" then gStates.monsterPerks[token.guid].attack={IF={3}} end
			if volkareDiceRolled==true then
				broadcastToAll("{en}Volkare's Attack randomly picked{ru}Атака Волкара была определена{zh-tw}沃里卡随机挑选攻击对象{zh-cn}沃里卡随机挑选攻击对象{ko}볼케어의 공격이 결정되었습니다{es}Ataque de Volkare elegido al azar{fr}Attaque de Volkare choisie au hasard{pt-br}Ataque de Volkare aleatóriamente escolhido{de}Volkare's Angriff zufällig ausgewählt", {1,1,0.5})
				volkareDiceRolled=false
			end
		end
	end, function() return token==nil or (token.resting and volkareDice.resting) end) end, 2)
end

exitWaitID={}
mirrorSpawnEnterIgnore={}
mirrorDestroyIgnore={}
mirrorSourceClaim={}
mirrorFaceWaitID={}
mirrorSourceRefreshWait=nil
mirrorManualRandomize={}
mirrorRepositionIgnore={}
spentMirrorDice={}
function manaSourceDieGUID(guid)
	if guid==nil or gStates.manaSource==nil then return false end
	for _, die in pairs(gStates.manaSource) do if die.manaDie==guid then return true end end
	return false
end
function mirrorSourceBusy()
	for _, waitfunction in pairs(exitWaitID) do if waitfunction~=nil then return true end end
	for _, claim in pairs(mirrorSourceClaim) do if claim~=nil then return true end end
	for _, sourceGUID in pairs(mirrorManualRandomize) do if sourceGUID~=nil then return true end end
	return false
end
function manaSourceZoneHasDie(guid)
	local zone=getObjectFromGUID(GUID.zone.mana)
	if zone==nil or guid==nil then return false end
	for _, obj in pairs(zone.getObjects()) do if obj.guid==guid then return true end end
	return false
end
function scheduleReturnedSourceMirror(sourceDie)
	if sourceDie==nil or sourceDie.guid==nil then return end
	local sourceGUID=sourceDie.guid
	--Do not make mirror restoration depend solely on the generic zone-enter callback. As soon as this exact
	--returned die is physically inside the real Source, rebuild the missing copies; correct its face again after settling.
	safeWaitCondition("PlayingGame",function()
		local die=getObjectFromGUID(sourceGUID)
		if die==nil then return end
		mirrorSourceUpdate("returned die entered real Source")
		safeWaitCondition("PlayingGame",function()
			if getObjectFromGUID(sourceGUID)~=nil then mirrorSourceUpdate("returned die settled in real Source") end
		end, function()
			local current=getObjectFromGUID(sourceGUID)
			return current==nil or current.resting
		end)
	end, function()
		return getObjectFromGUID(sourceGUID)==nil or manaSourceZoneHasDie(sourceGUID)==true
	end)
end
function scheduleMirrorSourceUpdate(from, delay)
	if mirrorSourceRefreshWait~=nil then Wait.stop(mirrorSourceRefreshWait) end
	mirrorSourceRefreshWait=safeWaitTime("PlayingGame",function()
		mirrorSourceRefreshWait=nil
		if mirrorSourceBusy()==true then
			mirrorSourceRefreshWait=safeWaitCondition("PlayingGame",function()
				mirrorSourceRefreshWait=nil
				mirrorSourceUpdate(from)
			end, function() return mirrorSourceBusy()==false end)
		else
			mirrorSourceUpdate(from)
		end
	end, delay or 0.1)
end
function mirrorSourceState()
	local colorConvert={["Blue Mana"]=1, ["White Mana"]=2, ["Green Mana"]=3, ["Red Mana"]=4, ["Gold Mana"]=5, ["Black Mana"]=6}
	if gStates.dayRound==false then colorConvert["Gold Mana"]=6 colorConvert["Black Mana"]=5 end
	local colorRotate={{0, 0, 0}, {0, 0, 270}, {0, 0, 90}, {0, 0, 180}, {90, 0, 0}, {270, 0, 0}}
	if gStates.dayRound==false then colorRotate[5]={270, 0, 0} colorRotate[6]={90, 0, 0} end
	local sourceDice={}
	local seperate=0
	for _, manaDie in pairs(getObjectFromGUID(GUID.zone.mana).getObjects()) do
		local color=manaDie.type=="Dice" and colorConvert[manaDie.getRotationValue()] or nil
		if color~=nil then
			sourceDice[#sourceDice+1]={manaDie=manaDie.guid, color=color}
			if color==6 then seperate=0.25 end
		end
	end
	table.sort(sourceDice, function(k1, k2) return k1.color<k2.color end)
	return sourceDice, colorRotate, seperate
end

function mirrorSourcePlayers()
	local players={}
	for playerIndex, playerDetails in ipairs(turnOrder) do
		if playerDetails.mage~=gStates.positionMageKnight[5] and playerDropoutInactive(playerIndex)==false then players[#players+1]=playerDetails end
	end
	table.sort(players, function(a, b) return (a.seatPos or 99)<(b.seatPos or 99) end)
	return players
end

--Face changes do not need new physical dice. Reuse the existing copies, update their faces and
--slide them into the same sorted positions a rebuild would have produced. If the Source set changed,
--return false so mirrorSourceUpdate can fall back to the structural rebuild.
function mirrorSourceSyncExisting(sourceDice, colorRotate, seperate)
	if gStates.manaMirror==nil then return false end
	local players=mirrorSourcePlayers()
	local expected=#sourceDice*#players
	local sourceSet={}
	local mirrorsBySource={}
	for _, die in ipairs(sourceDice) do sourceSet[die.manaDie]=true mirrorsBySource[die.manaDie]={} end
	local mirrorCount=0
	for mirrorGUID, sourceGUID in pairs(gStates.manaMirror) do
		local mirror=getObjectFromGUID(mirrorGUID)
		if mirror==nil or sourceSet[sourceGUID]~=true then return false end
		mirrorCount=mirrorCount+1
		mirrorsBySource[sourceGUID][#mirrorsBySource[sourceGUID]+1]=mirror
	end
	if mirrorCount~=expected then return false end
	for _, die in ipairs(sourceDice) do if #mirrorsBySource[die.manaDie]~=#players then return false end end
	if expected==0 then gStates.manaSource=sourceDice return true end

	local used={}
	for _, playerDetails in ipairs(players) do
		local spacing=0
		local first=false
		local localSeperate=seperate
		for pos, die in ipairs(sourceDice) do
			if die.color==6 and first==false then
				spacing=0.5 first=true
				if pos==1 then localSeperate=0 spacing=0 end
			end
			local target={-105+(40*playerDetails.seatPos)+((1.5*pos)+spacing)+(((8-gStates.diceNeeded)/2)*1.5)-localSeperate, 1.57, -28.1}
			local best=nil
			local bestDist=99999
			for _, mirror in ipairs(mirrorsBySource[die.manaDie]) do
				if used[mirror.guid]~=true then
					local p=mirror.getPosition()
					local dist=math.abs(p[1]-target[1])
					if dist<bestDist then best=mirror bestDist=dist end
				end
			end
			if best==nil then return false end
			used[best.guid]=true
			mirrorRepositionIgnore[best.guid]=true
			best.setRotation(colorRotate[die.color])
			local p=best.getPosition()
			if math.abs(p[1]-target[1])>0.02 or math.abs(p[2]-target[2])>0.08 or math.abs(p[3]-target[3])>0.02 then best.setPosition(target) end
			local mirrorGUID=best.guid
			safeWaitFrames("PlayingGame",function() mirrorRepositionIgnore[mirrorGUID]=nil end, 3)
		end
	end
	gStates.manaSource=sourceDice
	return true
end

function mirrorSourceUpdate(from)
	--Never alter mirror dice while a player is physically resolving one.
	if mirrorSourceBusy()==true then scheduleMirrorSourceUpdate(from, 0.05) return end
	if getObjectFromGUID(GUID.zone.mana)==nil or getObjectFromGUID(GUID.bag.spareDice)==nil then return end
	local sourceDice, colorRotate, seperate=mirrorSourceState()
	--The normal fast path: same Source GUIDs, so only update/re-sort the existing physical copies.
	if mirrorSourceSyncExisting(sourceDice, colorRotate, seperate)==true then return end

	--Structural change (die spent/returned/added, player set changed, stale save): rebuild the mirror set.
	if gStates.manaMirror~=nil then
		for dieDel, _ in pairs(gStates.manaMirror) do
			mirrorSpawnEnterIgnore[dieDel]=nil
			mirrorRepositionIgnore[dieDel]=nil
			mirrorDestroyIgnore[dieDel]=true
			mirrorManualRandomize[dieDel]=nil
			if mirrorFaceWaitID[dieDel]~=nil then Wait.stop(mirrorFaceWaitID[dieDel]) mirrorFaceWaitID[dieDel]=nil end
			if exitWaitID~=nil and exitWaitID[dieDel]~=nil then Wait.stop(exitWaitID[dieDel]) exitWaitID[dieDel]=nil end
			local oldDie=getObjectFromGUID(dieDel)
			if oldDie~=nil then oldDie.destruct() end
			local oldGUID=dieDel
			safeWaitFrames("PlayingGame",function() mirrorDestroyIgnore[oldGUID]=nil end, 3)
		end
	end
	gStates.manaMirror={}
	gStates.manaSource=sourceDice
	mirrorSourceClaim={}
	local players=mirrorSourcePlayers()
	for _, playerDetails in ipairs(players) do
		local spacing=0
		local first=false
		local localSeperate=seperate
		for pos, die in ipairs(sourceDice) do
			if die.color==6 and first==false then
				spacing=0.5 first=true
				if pos==1 then localSeperate=0 spacing=0 end
			end
			local mirrorDie=getObjectFromGUID(GUID.bag.spareDice).takeObject({position={-105+(40*playerDetails.seatPos)+((1.5*pos)+spacing)+(((8-gStates.diceNeeded)/2)*1.5)-localSeperate, 1.57, -28.1}, rotation=colorRotate[die.color], smooth=false})
			gStates.manaMirror[mirrorDie.guid]=die.manaDie
			mirrorSpawnEnterIgnore[mirrorDie.guid]=true
			local mirrorGUID=mirrorDie.guid
			safeWaitFrames("PlayingGame",function() mirrorSpawnEnterIgnore[mirrorGUID]=nil end, 3)
		end
	end
end

function mirrorSourceFaceSync(diceGUID, sourceGUID, from)
	mirrorFaceWaitID[diceGUID]=nil
	local dice=getObjectFromGUID(diceGUID)
	local source=getObjectFromGUID(sourceGUID)
	if dice==nil or source==nil or gStates.manaMirror==nil or gStates.manaMirror[diceGUID]~=sourceGUID then return end
	source.setRotation(dice.getRotation())
	mirrorSourceUpdate(from)
end
function scheduleMirrorFaceSync(dice, from)
	if dice==nil or dice.guid==nil or gStates.manaMirror==nil then return false end
	if mirrorRepositionIgnore[dice.guid]==true then return true end
	local sourceGUID=gStates.manaMirror[dice.guid]
	if sourceGUID==nil then return false end
	--Once a physical copy has started taking this shared die, face-change shortcuts on any copy must not alter the Source.
	if mirrorSourceClaim[sourceGUID]~=nil then return true end
	if mirrorFaceWaitID[dice.guid]~=nil then Wait.stop(mirrorFaceWaitID[dice.guid]) end
	local diceGUID=dice.guid
	mirrorFaceWaitID[diceGUID]=safeWaitFrames("PlayingGame",function() mirrorSourceFaceSync(diceGUID, sourceGUID, from) end, 2)
	return true
end
function scheduleMirrorRandomizeSync(dice, from)
	if dice==nil or dice.guid==nil or gStates.manaMirror==nil then return false end
	local sourceGUID=gStates.manaMirror[dice.guid]
	if sourceGUID==nil then return false end
	--If this Source die is already being physically taken, R applies only to that held copy; do not cancel the spend.
	if mirrorSourceClaim[sourceGUID]~=nil then return true end
	local diceGUID=dice.guid
	mirrorManualRandomize[diceGUID]=sourceGUID
	if exitWaitID[diceGUID]~=nil then Wait.stop(exitWaitID[diceGUID]) exitWaitID[diceGUID]=nil end
	if mirrorFaceWaitID[diceGUID]~=nil then Wait.stop(mirrorFaceWaitID[diceGUID]) end
	local function finishRandomize()
		mirrorFaceWaitID[diceGUID]=nil
		mirrorManualRandomize[diceGUID]=nil
		mirrorSourceFaceSync(diceGUID, sourceGUID, from)
	end
	mirrorFaceWaitID[diceGUID]=safeWaitFrames("PlayingGame",function()
		mirrorFaceWaitID[diceGUID]=safeWaitCondition("PlayingGame",finishRandomize, function()
			local die=getObjectFromGUID(diceGUID)
			return die==nil or die.resting
		end, 10, finishRandomize)
	end, 2)
	return true
end
function scheduleRealSourceRefresh(dice, from, waitForRest)
	if dice==nil or dice.guid==nil or manaSourceDieGUID(dice.guid)~=true then return false end
	local diceGUID=dice.guid
	if mirrorFaceWaitID[diceGUID]~=nil then Wait.stop(mirrorFaceWaitID[diceGUID]) end
	local function refresh()
		mirrorFaceWaitID[diceGUID]=nil
		if getObjectFromGUID(diceGUID)~=nil then mirrorSourceUpdate(from) end
	end
	if waitForRest==true then
		mirrorFaceWaitID[diceGUID]=safeWaitFrames("PlayingGame",function()
			mirrorFaceWaitID[diceGUID]=safeWaitCondition("PlayingGame",refresh, function()
				local die=getObjectFromGUID(diceGUID)
				return die==nil or die.resting
			end, 10, refresh)
		end, 2)
	else
		mirrorFaceWaitID[diceGUID]=safeWaitFrames("PlayingGame",refresh, 2)
	end
	return true
end
function diceResting(dice, state)
	if dice==nil or dice.type~="Dice" or dice.guid==nil then return end
	if gStates~=nil and gStates.apocalypseQuestRollDice~=nil and gStates.apocalypseQuestRollDice[dice.guid]==true then return end
	--Script-driven mirror destruction can emit collision exits; never interpret those as spending Source mana.
	if mirrorDestroyIgnore[dice.guid]==true then return end
	--In-place mirror face/order synchronization may briefly cross the collision surface.
	if mirrorRepositionIgnore[dice.guid]==true then return end
	--A mirror being randomized can leave/re-enter the collision surface while it rolls. That is a face change, not spending the die.
	if mirrorManualRandomize[dice.guid]~=nil then return end
	--New mirror dice naturally fire one collision-enter as they land. Ignore only that event.
	if state=="enter" and mirrorSpawnEnterIgnore[dice.guid]==true then return end
	if exitWaitID[dice.guid]~=nil then Wait.stop(exitWaitID[dice.guid]) exitWaitID[dice.guid]=nil end
	local sourceGUID=gStates.manaMirror~=nil and gStates.manaMirror[dice.guid] or nil
	--Only a die that actually spent a mirrored Source entry may be returned here. Other dice can
	--touch the collision surface without being destroyed or creating a new real Source die.
	if sourceGUID==nil then
		if state~="enter" or spentMirrorDice[dice.guid]~=true then return end
		local diceGUID=dice.guid
		local function returnDieToSource()
			exitWaitID[diceGUID]=nil
			local currentDice=getObjectFromGUID(diceGUID)
			local spareDice=getObjectFromGUID(GUID.bag.spareDice)
			if currentDice==nil or spareDice==nil then return end
			local returnedSource=spareDice.takeObject({position={-12.5+(math.random()*7), 1.5 , -24.0+(math.random()*3.5)}, rotation=currentDice.getRotation(), smooth=false})--Mana Dice Container
			spentMirrorDice[diceGUID]=nil
			scheduleReturnedSourceMirror(returnedSource)
			onObjectRandomize({type="Dice"})
			currentDice.destruct()
		end
		exitWaitID[diceGUID]=safeWaitCondition("PlayingGame",returnDieToSource, function()
			local currentDice=getObjectFromGUID(diceGUID)
			return currentDice==nil or currentDice.resting
		end, 10, returnDieToSource)
		return
	end
	--Only one physical mirror may be taking a shared Source die at a time. A second simultaneous copy stays stale until the first action resolves/rebuilds.
	if state=="exit" then
		if mirrorSourceClaim[sourceGUID]~=nil and mirrorSourceClaim[sourceGUID]~=dice.guid then return end
		mirrorSourceClaim[sourceGUID]=dice.guid
	elseif state=="enter" then
		if mirrorSourceClaim[sourceGUID]~=nil and mirrorSourceClaim[sourceGUID]~=dice.guid then return end
		if mirrorSourceClaim[sourceGUID]==dice.guid then mirrorSourceClaim[sourceGUID]=nil end
	end
	local diceGUID=dice.guid
	local function updateDice()
		exitWaitID[diceGUID]=nil
		local currentDice=getObjectFromGUID(diceGUID)
		local mappedSource=gStates.manaMirror~=nil and gStates.manaMirror[diceGUID] or nil
		if mappedSource~=sourceGUID then return end
		--Removed a die from a mirrored Source: spend the one shared real Source die.
		if state=="exit" then
			local source=getObjectFromGUID(sourceGUID)
			if source~=nil then source.destruct() end
			spentMirrorDice[diceGUID]=true
			gStates.manaMirror[diceGUID]=nil
			mirrorSourceClaim[sourceGUID]=nil
		else--Returned/changed a die while still on a mirrored Source.
			local source=getObjectFromGUID(sourceGUID)
			if source~=nil and currentDice~=nil then source.setRotation(currentDice.getRotation()) end
		end
		local moreDice=false
		for _, waitfunction in pairs(exitWaitID) do if waitfunction~=nil then moreDice=true break end end
		if moreDice==false then exitWaitID={} scheduleMirrorSourceUpdate("last dice resting in mirror", 0.05) end
	end
	exitWaitID[diceGUID]=safeWaitCondition("PlayingGame",updateDice, function()
		local currentDice=getObjectFromGUID(diceGUID)
		return currentDice==nil or currentDice.resting
	end, 10, updateDice)
end

function DealWound(paramaters)
	local woundbag=getObjectFromGUID(paramaters.guid)
	local playerPosition=math.ceil((woundbag.getPosition()[1]+80)/40)
	if legalPlayerCheck(paramaters.player.color, playerPosition)==true then
		woundbag.takeObject({position={(playerPosition*40)-91, 2.98, -48.40}})
		if paramaters.id=="DealPoison" then
			woundbag.takeObject({position={(playerPosition*40)-110.54, 2, -43.20}})
		end
	end
end

explorePause=false
function exploreMap(player, mouseButton, id)
	if mouseButton=="-1" and legalPlayerCheck(player.color, turnOrder[gStates.turnNumber].seatPos)==true and explorePause==false and gStates.fracturedLandsOrientation==nil then
		explorePause=true
		--convert index to location
		local pos={}
		local index=1
		for value in string.gmatch(id, "([^,]+)") do
			if index==1 then pos[index]=tonumber(value:sub(7, value:len())) else pos[index]=tonumber(value) end
			index=index+1
		end
		--Ignore a stale button event, then recheck the physical target so rapid clicks cannot stack terrain tiles.
		local exploreStillLegal=false
		for _, button in pairs(gStates.exploreButtons or {}) do
			if button.attributes~=nil and button.attributes.id==id then exploreStillLegal=true break end
		end
		if exploreStillLegal==false then explorePause=false return end
		for _, mapObject in pairs(getObjectFromGUID(mapArea).getObjects()) do
			if terrainTiles[mapObject.guid]~=nil then
				local mapPos=mapObject.getPosition()
				if ((pos[1]-mapPos[1])^2)+((pos[2]-mapPos[3])^2)<1 then explorePause=false return end
			end
		end
		--From here on exploration mutates the table. Take the safe rewind point before moving the city card
		--or revealing the random terrain tile, and release it once the new tile is in a stable state.
		rewindTransactionStart(function()
			--Move city cards (normally already handled when this position was highlighted as explore-able).
			relocateCityCardForExplore(pos)
			--Life and Death not pulling the wrong city.
			local drawFrom=GUID.bag.terrain.stack
			if getObjectFromGUID(drawFrom).getQuantity()==0 then drawFrom=GUID.bag.terrain.leftCountry end
			if getObjectFromGUID(drawFrom).getQuantity()==0 then drawFrom=GUID.bag.terrain.leftCore end
			local index=getObjectFromGUID(drawFrom).getQuantity()-1
			if gStates.gameScenario=="Life and Death" and getObjectFromGUID(GUID.bag.terrain.stack).getQuantity()>1 then
				local northBearing=40
				local startTileGUID=startTerrain.open
				if getObjectFromGUID(startTileGUID)==nil then startTileGUID=startTerrain.wedge northBearing=70 end
				local startBearing=math.deg(math.atan2(pos[2]-getObjectFromGUID(startTileGUID).getPosition()[3], pos[1]-getObjectFromGUID(startTileGUID).getPosition()[1]))
				--Check if a City tile is played to wrong side in Life and Death
				local terainBagTest=getObjectFromGUID(GUID.bag.terrain.stack).clone()
				terainBagTest.setGMNotes("")
				local nextTile=terainBagTest.takeObject()
				if (nextTile.guid==GUID.tile.city08 and startBearing<=northBearing-1) or (nextTile.guid==GUID.tile.city05 and startBearing>=northBearing+1) then index=index-1 end
				terainBagTest.destruct()
				nextTile.destruct()
			end
			--Deploy Terrain tile
			local tileRotation={0, 180, 0}
			if gStates.randomTileOrientation==true then tileRotation[2]=math.random(1,6)*60 end
			if getObjectFromGUID(drawFrom).getQuantity()>0 then
				local drawnTile=getObjectFromGUID(drawFrom).takeObject({position={pos[1], 2, pos[2]}, rotation=tileRotation, smooth=false, index=index})
				if gStates.gameScenario=="The Fractured Lands Blitz" then
					startFracturedLandsOrientation(drawnTile, {pos[1],0.97,pos[2]})
					rewindTransactionFinish("Explore map")
				else
					drawnTile.setPositionSmooth({pos[1], 0.97, pos[2]})
					safeWaitFrames("PlayingGame",function() safeWaitCondition("PlayingGame",function()
						mainUIUpdate("Moved city card")
						explorePause=false
						rewindTransactionFinish("Explore map")
					end, function() return drawnTile==nil or drawnTile.resting end,8,function()
						if drawnTile~=nil then drawnTile.setPosition({pos[1],0.97,pos[2]}) end
						explorePause=false
						rewindTransactionFinish("Explore map")
					end) end, 2)
				end
			else
				explorePause=false
				rewindTransactionFinish("Explore map")
			end
		end,"Explore map",function() explorePause=false end)
	end
end

function straightenCrooked()
	--send city cards to bottom so tokens don't spawn under.
	local sendToBottom={dummyBoard, gStates.cityCard[cityModel.blue], gStates.cityCard[cityModel.red], gStates.cityCard[cityModel.green], gStates.cityCard[cityModel.white], "e47fc3", "62d3c3", "12a3b1", "6f815c", "94c021", "d9c252", "7a56fa", "19c6ce", "aa6c1d", "d80815", "fdbc08", "0b57b9"}
	for _, objGUID in pairs(sendToBottom) do
		if getObjectFromGUID(objGUID)~=nil then
			--getObjectFromGUID(objGUID).unlock()
			getObjectFromGUID(objGUID).setPosition({getObjectFromGUID(objGUID).getPosition()[1], 0.98, getObjectFromGUID(objGUID).getPosition()[3]})
			local rot={0.00, 180.00, 0.00}
			if getObjectFromGUID(objGUID).getRotation()[3]>=170 and getObjectFromGUID(objGUID).getRotation()[3]<=190 then rot=({0.00, 180.00, 180.00}) end
			getObjectFromGUID(objGUID).setRotation(rot)
			--Wait.time(function() getObjectFromGUID(objGUID).lock() end, 0.5)
		end
	end
end

function monsterImageSwap(player, mouseButton, id)
	if mouseButton=="-1" then
		for monsterGuid, monsterDetails in pairs(monsterPugs) do
			if getObjectFromGUID(monsterGuid)~=nil then
				if gStates.useAlternatePugs==false and (monsterDetails.original~="" or monsterDetails.alternate~="") then
					getObjectFromGUID(monsterGuid).setCustomObject({image=monsterDetails.alternate})
				else
					getObjectFromGUID(monsterGuid).setCustomObject({image=monsterDetails.original})
				end
				getObjectFromGUID(monsterGuid).reload()
			end
		end
		if gStates.useAlternatePugs==false then
			gStates.useAlternatePugs=true
			getObjectFromGUID("d7a165").UI.setAttribute("d7a165swapMonsterImageText", "text", "{en}Stefano Colombo's Monster Tokens - ON{ru}Жетоны монстров Stefano Colombo — ВКЛ.{zh-tw}Stefano Colombo 的怪物標記－開{zh-cn}Stefano Colombo 的怪物标记－开{ko}Stefano Colombo 몬스터 토큰 - 켬{es}Fichas de Monstruo de Stefano Colombo - ACTIVADAS{fr}Jetons de Monstre de Stefano Colombo - ACTIVÉS{pt-br}Fichas de Monstro de Stefano Colombo - ATIVADAS{de}Stefano Colombos Monstermarker - AN")
		else
			gStates.useAlternatePugs=false
			getObjectFromGUID("d7a165").UI.setAttribute("d7a165swapMonsterImageText", "text", "{en}Stefano Colombo's Monster Tokens - OFF{ru}Жетоны монстров Stefano Colombo — ВЫКЛ.{zh-tw}Stefano Colombo 的怪物標記－關{zh-cn}Stefano Colombo 的怪物标记－关{ko}Stefano Colombo 몬스터 토큰 - 끔{es}Fichas de Monstruo de Stefano Colombo - DESACTIVADAS{fr}Jetons de Monstre de Stefano Colombo - DÉSACTIVÉS{pt-br}Fichas de Monstro de Stefano Colombo - DESATIVADAS{de}Stefano Colombos Monstermarker - AUS")
		end
		--discard containers
		local discardContainers={GUID.bag.discard.towerGarrison, GUID.bag.discard.keepGarrison, GUID.bag.discard.cityGarrison, GUID.bag.discard.ruin, GUID.bag.discard.draconum, GUID.bag.discard.dungeon, GUID.bag.discard.orcs, GUID.bag.discard.darkDraconum, GUID.bag.discard.darkDungeon, GUID.bag.discard.darkMarauders, GUID.bag.discard.darkReward, GUID.bag.discard.elementalistDraconum, GUID.bag.discard.elementalistDungeon, GUID.bag.discard.elementalistOrcs, GUID.bag.discard.elementalistReward, GUID.bag.discard.apocReward, GUID.bag.discard.councilReward}
		for _, containerGuid in pairs(discardContainers) do
			if getObjectFromGUID(containerGuid)~=nil and getObjectFromGUID(containerGuid).getQuantity()>0 then
				temp=getObjectFromGUID(containerGuid).takeObject({position={getObjectFromGUID(containerGuid).getPosition()[1], 5, getObjectFromGUID(containerGuid).getPosition()[3]}, smooth=false})
			end
		end
	end
end

---------------
function autoflip()
	if gStates.autoFlip==true then
		gStates.autoFlip=false
		UI.setAttribute("AutoFlipButtonRealImage", "image", "Sliced Button/Button New Active")
		broadcastToAll("{en}Monster tokens need to be flipped manually.{ru}Жетоны врагов необходимо переворачивать вручную.{zh-tw}怪物标记需要手动翻转{zh-cn}怪物标记需要手动翻转{ko}규칙에 따라 직접 토큰을 뒤집어야 합니다{es}Las fichas de monstruo deben voltearse manualmente.{fr}Les jetons Monstre doivent être retournés manuellement.{pt-br}Fichas de Monstros precisam ser viradas manualmente{de}Monsterplättchen müssen manuell umgedreht werden.", {1,1,0.5})
	else
		gStates.autoFlip=true
		UI.setAttribute("AutoFlipButtonRealImage", "image", "Sliced Button/Button New Deactive")
		broadcastToAll("{en}Script will flip monster tokens for you.{ru}Скрипт будет переворачивать жетоны врагов за вас.{zh-tw}脚本将为你翻转怪物标记. {zh-cn}脚本将为你翻转怪物标记. {ko}스크립트가 자동으로 토큰을 뒤집습니다.{es}Script le dará la vuelta a las fichas de monstruos.{fr}Le script retournera les jetons monstre pour vous.{pt-br}O Script virará as fichas de monstros por você.{de}Das Skript dreht die Monsterplättchen für dich um.", {1,1,0.5})
	end
end

function tableCopy(obj, seen)
	local seen=seen or {}
	if type(obj)~='table' then return obj end
	if seen[obj] then return seen[obj] end
	local res=setmetatable({}, getmetatable(obj))
	seen[obj]=res
	for key, value in pairs(obj) do res[tableCopy(key, seen)]=tableCopy(value, seen) end
	return res
end
initializeCityStaticData()

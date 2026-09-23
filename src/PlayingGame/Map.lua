-- Map state, avatar location, exploration, shields and terrain-site runtime.

local terrainExploreButtons={{}}
local terrainPlacementEdgeCoordinates={
	{-30.03, 15.09}, {-25.23, 19.25}, {-31.23, 21.34},
	{-38.43, 0.54}, {-33.63, 4.70}, {-28.83, 8.86}, {-24.03, 13.02}, {-19.23, 17.17},
	{-24.03, -16.08}, {-19.23, -11.93}, {-14.43, -7.77}, {-9.63, -3.61}, {-4.82, 0.55}, {-0.02, 4.71}, {4.78, 8.87}
}
local terrainExploreSpots={
	{-24.0301, 0.99, -16.0837}, {-30.0303, 0.99, -14.0052}, {-36.0305, 0.99, -11.9267}, {-19.2300, 0.99, -11.9267},
	{-25.2302, 0.99,  -9.8482}, {-31.2303, 0.99,  -7.7696}, {-14.4298, 0.99,  -7.7696}, {-20.4300, 0.99,  -5.6911},
	{-37.2305, 0.99,  -5.6911}, { -9.6297, 0.99,  -3.6126}, {-26.4302, 0.99,  -3.6126}, {-32.4304, 0.99,  -1.5341},
	{-15.6299, 0.99,  -1.5341}, { -4.8295, 0.99,   0.5445}, {-38.4306, 0.99,   0.5445}, {-21.6300, 0.99,   0.5445},
	{-10.8297, 0.99,   2.6230}, {-27.6302, 0.99,   2.6230}, {-33.6304, 0.99,   4.7015}, {-16.8299, 0.99,   4.7015},
	{-0.02940, 0.99,   4.7015}, { -6.0278, 0.99,   6.7794}, {-22.8301, 0.99,   6.7794}, {-28.8303, 0.99,   8.8586},
	{-12.0297, 0.99,   8.8586}, {  4.7708, 0.99,   8.8586}, {-18.0299, 0.99,  10.9371}, { -1.2294, 0.99,  10.9371},
	{ -7.2296, 0.99,  13.0156}, {-24.0301, 0.99,  13.0156}, {-30.0303, 0.99,  15.0941}, {-13.2298, 0.99,  15.0941},
	{-19.2300, 0.99,  17.0727}, {-25.2302, 0.99,  19.2512}, {-31.2303, 0.99,  21.3297}
}
local terrainInfoCardGUIDs={
	["rampaging"]="cb9285", ["mage tower"]="29ef37", ["village"]="3a89e4", ["draconum"]="c2ada0",
	["keep"]="9c74a9", ["monastery"]="8dd3c2", ["maze"]="ad6e2b", ["monster den"]="3aef9a",
	["dungeon"]="57dcab", ["glade"]="938554", ["labyrinth"]="36762b", ["spawning grounds"]="321d15",
	["tomb"]="1cab50", ["mine"]="6b9c02", ["camp"]="6b9c02", ["pyramid"]="467846", ["ziggurat"]="4efb28",
	["Volkare's Camp"]="0bb2dc", ["city green"]="8de450", ["city red"]="bd6ab1", ["city blue"]="79a723",
	["city white"]="a37b57", ["oasis"]="4e4bda", ["ruin"]="0b5e05"
}
local warOfFourGladeEdgeCoordinates={
	{-38.43,  0.54}, {-33.63,  4.70}, {-28.83,  8.86}, {-24.03, 13.02}, {0, 0},
	{-37.23, -5.69}, {-32.43, -1.52}, {-27.63,  2.62}, {-22.83,  6.79}, {-18.02, 10.94},
	{-30.03,-14.01}, {-25.23, -9.84}, {-20.43, -5.69}, {-15.63, -1.54}, {-10.81,  2.63},
	{-24.03,-16.08}, {-19.23,-11.93}, {-14.43, -7.77}, { -9.63, -3.61}
}

function terrainExploreOptions()
	return terrainExploreButtons
end

function clearTerrainExploreOptions()
	terrainExploreButtons={{}}
	local exploreUI=getObjectFromGUID("f2291a")
	if exploreUI~=nil then exploreUI.UI.setXmlTable(terrainExploreButtons) end
end

--Ruin tokens always travel face-down. Daytime reveal happens only after their full map-token arrival,
--including any shared-hex separator correction, so flip() can never interrupt the journey.
function revealRuinAfterArrival(guid)
	mapTokenAfterArrivalComplete(guid,function(ruin)
		if ruin~=nil and ruin.is_face_down==true then ruin.flip() end
	end)
end


-- Portal and City avatar parking
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
				safeWaitTime("Map",function() safeWaitCondition("Map",function()
					shield.lock()
				end, function() return shield.resting end) end, 1.5)
			end
			UI.setAttribute("PreEndTurn", "interactable", "false")
			UI.setAttribute("PreEndTurnImage", "image", "Sliced Button/Button New Deactive")
			safeWaitTime("Map",function()
				UI.setAttribute("PreEndTurn", "interactable", "true")
				UI.setAttribute("PreEndTurnImage", "image", "Sliced Button/Button New Active")
			end, 2.1)
			break
		end
	end
end

--Coral's Tales skills collect a shield when Coral marks the matching type of site.

-- Shield location bookkeeping
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
			if gStates.gameScenario=="The Fractured Lands Blitz" and obj.getGMNotes()=="Burned Monastery" then safeWaitFrames("Map",function() refreshFracturedLandsTeleportHighlights() end, 1) end
		end
	end
	if zone.guid~=mapArea then
		if pause==false then pause=true safeWaitFrames("Map",function()
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

-- Avatar refresh scheduling
local adjustHandSizePause=nil

function fakeDropAvatar(playerIndex)
	local dropPlayer=playerIndex or gStates.turnNumber
	if turnOrder[dropPlayer]==nil then return end
	if coopAssaultVirtualPlayer(dropPlayer)==true then
		if gStates.preEndTurn~=true then mainUIUpdate("Co-op virtual city location") end
		return
	end
	if adjustHandSizePause~=nil then Wait.stop(adjustHandSizePause) end
	adjustHandSizePause=safeWaitTime("Map",function()
		if turnOrder[dropPlayer]==nil then return end
		local found=false
		for _, avatar in pairs(mageKnights) do
			if turnOrder[dropPlayer].mage==avatar.mage and avatar.mage~="Volkare" then
				local modelGUID, tokenGUID, standeeGUID=avatar.model, avatar.token, avatar.standee
				local avatarObj=getObjectFromGUID(modelGUID) or getObjectFromGUID(tokenGUID) or getObjectFromGUID(standeeGUID)
				if avatarObj~=nil then
					found=true
					safeWaitFrames("Map",function()
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

-- Map geometry, avatar location and rampaging tokens
terrainPlacementNeighbourOffsets={
	{math.cos(math.rad(41))*6.35, math.sin(math.rad(41))*6.35},
	{math.cos(math.rad(101))*6.35, math.sin(math.rad(101))*6.35},
	{math.cos(math.rad(161))*6.35, math.sin(math.rad(161))*6.35},
	{math.cos(math.rad(221))*6.35, math.sin(math.rad(221))*6.35},
	{math.cos(math.rad(281))*6.35, math.sin(math.rad(281))*6.35},
	{math.cos(math.rad(341))*6.35, math.sin(math.rad(341))*6.35}
}

--Avatar-location scans use the shared live spatial view, so Map, Combat, Movement and AI all
--derive their local object/hex queries from the same physical-table snapshot.
avatarLocationSpatialCell=3
function avatarLocationMapSnapshot()
	local spatial=runtimeMapSpatialSnapshot(avatarLocationSpatialCell)
	return spatial.objects,spatial.positions,spatial.terrainObjects,spatial.terrainRotations,spatial.buckets,spatial
end

function avatarLocationRelevantObjects(locatedTerrain,pos,spatial)
	return runtimeMapSpatialNearbyObjects(spatial,pos,avatarLocationSpatialCell,locatedTerrain)
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

--Plays rampaging tokens. Both onObjectEnterScriptingZone and endRound call this routine.
--Setup terrain still receives its normal Rampaging enemy, but not player-exploration Ambush/Pursuit effects.
function playRampagingTokens(obj, startBearing, northBearing, hexLocation, hexFeature, dropped, explorationEffectsEligible)
	if explorationEffectsEligible==nil then explorationEffectsEligible=true end
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
	if dice~=nil then safeWaitTime("Map",function() dice.destruct() end, 10) end
	safeWaitFrames("Map",function()--wait for clone to spawn
		if dice~=nil then dice.unlock() dice.shuffle() end
		safeWaitFrames("Map",function()
			safeWaitCondition("Map",function()
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
						if gStates.rampageAmbush==true and gStates.tacticShown==false and dropped==true and explorationEffectsEligible==true then
							gStates.ambushingMonsters[token.guid]=params.position
						end
						if gStates.rampagePursuit==true and gStates.tacticShown==false and dropped==true and explorationEffectsEligible==true and turnOrder[gStates.turnNumber].mage~=gStates.positionMageKnight[5] then
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

-- Manual shield/marker placement and avatar hex tracking
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
				safeWaitFrames("Map",function() safeWaitCondition("Map",function()
					shield.lock()
					addAvatarButtons()
				end, function() return shield.resting end) end, 10)
				break
			end
			if details.markerContainer==id:sub(1, 6) then
				local marker=getObjectFromGUID(details.markerContainer).takeObject({position={tempPos[1], 3, tempPos[3]}})
				safeWaitFrames("Map",function() safeWaitCondition("Map",function()
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

-- Nearby Mage lookup
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

-- Map exploration and table straightening
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
		for _, button in pairs(terrainExploreButtons) do
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
					safeWaitFrames("Map",function() safeWaitCondition("Map",function()
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

-- Avatar drop resolution and terrain-entry runtime moved from Events.lua.
function mapAvatarLocationDetails(player_color, avatar, dropped_object)
	local keepShieldMatch={
		{keep=false, keepShield=false, city=false, cityShield=false},
		{keep=false, keepShield=false, city=false, cityShield=false},
		{keep=false, keepShield=false, city=false, cityShield=false},
		{keep=false, keepShield=false, city=false, cityShield=false},
		{keep=false, keepShield=false, city=false, cityShield=false},
		{keep=false, keepShield=false, city=false, cityShield=false},
		{keep=false, keepShield=false, city=false, cityShield=false}}
	local keepFound=false
	local cityFound="False"
				local attackedLocation=nil
				local horsemenGladeAssault=false
				local avatarChangedHex=false
				if player_color~=nil and turnOrder[gStates.turnNumber].mage==avatar.mage then
					avatarChangedHex=avatarMovedFromPickedUpHex(dropped_object.getPosition())
					if avatarChangedHex==true then
						apocalypseQuestUnderSiegeMarkMoved(gStates.turnNumber)
						clearWallAssaultChoice()
						assaultApproachOrigin=nil
						assaultTargetPosition=nil
						leaveAvatarSite(turnOrder[gStates.turnNumber])
						clearPendingCoopAssault()
					end
				end
				playerPickedUpHex=nil
				if getObjectFromGUID(dropped_object.guid)~=nil then
					for _, playerDetails in pairs(turnOrder) do
						if playerDetails.mage==avatar.mage then
							playerDetails.avatarLocation=""
							playerDetails.avatarSharedHex=nil
							local droppedPos=dropped_object.getPosition()
							local avatarPos={droppedPos[1], droppedPos[2], droppedPos[3]}--copy so neighbour math can safely mutate it
							--check if avatar dropped on city card, then use the city model as the avatar location
							local cityZoneFound=false
							for zone, citySearch in pairs(cityScriptZones) do
								local zoneObj=getObjectFromGUID(zone)
								if zoneObj~=nil then
									for _, detail in pairs(zoneObj.getObjects()) do
										if detail.guid==dropped_object.guid then
											local cityObj=nil
											if zone==volkare.discZone and (gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz" or gStates.gameScenario=="Volkare's Quest" or gStates.gameScenario=="The War of Four") then cityObj=getObjectFromGUID(gStates.volkareModel)
											else cityObj=getObjectFromGUID(citySearch.cityGUID) end
											if cityObj~=nil then local cityPos=cityObj.getPosition() avatarPos={cityPos[1],1.5,cityPos[3]} end
											cityZoneFound=true
											break
										end
									end
								end
								if cityZoneFound==true then break end
							end
							--Use one cached map snapshot for the current hex and its six neighbours.
							local volkareCampKeepAllowed=volkareCampAsCityConquered()==true and volkareCampContributionShieldCount(playerDetails)>0
							local mapObjects, mapObjectPositions, mapTerrainObjects, mapTerrainRotations, mapObjectBuckets, mapSpatial=avatarLocationMapSnapshot()
								for keepSearch=1, 7, 1 do
									--Volkare can remove a City model during this loop, so retain the old live-refresh behaviour for him.
									if keepSearch>1 and playerDetails.mage=="Volkare" then
										mapObjects, mapObjectPositions, mapTerrainObjects, mapTerrainRotations, mapObjectBuckets, mapSpatial=avatarLocationMapSnapshot()
									end
									local locatedTerrain, bearing, _, hexFeature=terrainHexAtPosition(avatarPos, mapTerrainObjects, mapObjectPositions, mapTerrainRotations)
								hexFeature=hexFeature or ""
									for _, terrain in ipairs(avatarLocationRelevantObjects(locatedTerrain,avatarPos,mapSpatial)) do--terrain tile + nearby physical objects only
										--work with terrain tiles
										local tilePos=mapObjectPositions[terrain.guid] or terrain.getPosition()
										local avatarToTileDistSquared=((avatarPos[1]-tilePos[1])^2)+((avatarPos[3]-tilePos[3])^2)
									if terrain==locatedTerrain then
										if keepSearch==1 then
											playerDetails.avatarLocation=hexFeature
											if gStates.gameScenario=="Fury of the Apocalypse Dragon" and avatarChangedHex==true and playerDetails.mage~="Volkare" and
												turnOrder[gStates.turnNumber].mage==avatar.mage and player_color~=nil and playerDetails.avatarLocation:sub(1,4)=="city" then
												gStates.furyHeroEnteredCity=true
											end
											if againstHorsemenCentralGladeHex(locatedTerrain,bearing)==true then
												if gStates.againstHorsemenRitualStarted~=true then playerDetails.avatarSharedHex=againstHorsemenSharedHexKey
												elseif playerDetails.mage~="Volkare" and turnOrder[gStates.turnNumber].mage==avatar.mage and player_color~=nil and gStates.preEndTurn==false and avatarChangedHex==true then horsemenGladeAssault=true end
											end
											if playerDetails.mage~="Volkare" and turnOrder[gStates.turnNumber].mage==avatar.mage and player_color~=nil and gStates.preEndTurn==false and attackedLocation==nil and horsemenGladeAssault==false
												and (avatarChangedHex==true or next(gStates.attackedMonsters)==nil)
												and (playerDetails.avatarLocation=="keep" or playerDetails.avatarLocation=="mage tower" or playerDetails.avatarLocation:sub(1, 4)=="city" or playerDetails.avatarLocation=="Volkare's Camp" or playerDetails.avatarLocation=="hidden valley" or playerDetails.avatarLocation=="necropolis") then
												attackedLocation="Attack"..playerDetails.mage--was "Locati" instead of "Attack"
											end
											if playerDetails.mage=="Volkare" and gStates.preEndTurn==false and attackedLocation==nil and playerDetails.avatarLocation:sub(1, 4)=="city" then
												if gStates.gameScenario~="Volkare's Quest" then
													for index, modelTerrain in pairs(gStates.cityRevealed) do
														if modelTerrain.terrain==terrain.guid then
															getObjectFromGUID(trashCan).putObject(getObjectFromGUID(modelTerrain.model))
															gStates.cityRevealed[index].state="defeated"
															break
														end
													end
												end
											end
										end
										if hexFeature=="keep" or (volkareCampKeepAllowed==true and (hexFeature=="Volkare's Camp" or (gStates.cityVolkareTile==terrain.guid and bearing=="center"))) then
											keepShieldMatch[keepSearch]["keep"]=true
											if keepShieldMatch[keepSearch]["keepShield"]==true then keepFound=true end
										end
										if (hexFeature or ""):sub(1,4)=="city" then
											keepShieldMatch[keepSearch]["city"]=true
											if keepShieldMatch[keepSearch]["cityShield"]==true then cityFound=terrain.getName() end
										end
									end
										if avatarToTileDistSquared<1 then
										--work with Shields
										if terrain.getName()=="Shield" and volkarePursuitShieldRegistered(terrain)~=true and ((terrain.getDescription()==playerDetails.mage and (gStates.coop==0 or gStates.WarOfFourComp==true)) or (gStates.coop==1 and gStates.WarOfFourComp~=true)) then
											keepShieldMatch[keepSearch]["keepShield"]=true
											if keepShieldMatch[keepSearch]["keep"]==true then keepFound=true end
										end

										--work with Cities
										local temp=terrain.guid
										if terrain.guid=="938cd3" or terrain.guid=="a0d7b3" then temp=volkare.model end
										if temp==cityModel.white or	temp==cityModel.blue or	temp==cityModel.red or temp==cityModel.green or temp==volkare.terrainHex or	temp==volkare.model then
											--flip garrisons during the day
											if turnOrder[gStates.turnNumber].mage==avatar.mage and gStates.preEndTurn==false and gStates.cityMonsterQty[temp]~=nil and gStates.autoFlip==true and temp~=volkare.model then
												local broadcast=false
												for monsterGUID, monster in pairs(gStates.cityMonsterQty[temp]) do
													if monsterGUID~="extra" then
														local monsterObj=getObjectFromGUID(monsterGUID)
														if monsterObj~=nil and monsterObj.is_face_down==true then monsterObj.flip() broadcast=true end
													end
												end
												if broadcast==true then
													if temp==volkare.model then
														broadcastToAll("{en}Volkare's Army Revealed{ru}Армия Волкара раскрыта{zh-tw}沃里卡军队揭示了{zh-cn}沃里卡军队揭示了{ko}볼케어의 군대가 공개되었습니다{es}Se revela el ejército de Volkare{fr}L'armée de Volkare révélée{pt-br}Exército de Volkare Revelado{de}Volkare's Armee aufgedeckt", {1,1,0.5})
													else
														broadcastToAll("{en}Site Garrison Revealed{ru}Гарнизон Укрепленного места раскрыт{zh-tw}守军揭示了{zh-cn}守军揭示了{ko}수비자가 공개되었습니다.{es}Guarnición del Sitio Revelada{fr}La Garnison du Site Révélée{pt-br}Lugar de Guarnição Revelada{de}Standort Garnison aufgedeckt", {1,1,0.5})
													end
												end
											end
											--Assult Volkare
											if playerDetails.mage~="Volkare" and keepSearch==1 and temp==volkare.model then
												playerDetails.avatarLocation="Volkare's Camp"
												if player_color~=nil and gStates.preEndTurn==false and attackedLocation~="Volkar"..playerDetails.mage and (avatarChangedHex==true or next(gStates.attackedMonsters)==nil) then
													attackedLocation="Volkar"..playerDetails.mage
												end
											end
											--
											if terrain.getName()~="Volkare's Camp" then
												if playerDetails.defeatedCities[terrain.guid]~=nil then
													keepShieldMatch[keepSearch]["cityShield"]=true
													if keepShieldMatch[keepSearch]["city"]==true then cityFound=terrain.getGMNotes() end
												end
											else
												if volkareCampKeepAllowed==true and playerDetails.defeatedCities[terrain.guid]~=nil then
													keepShieldMatch[keepSearch]["keepShield"]=true
													if keepShieldMatch[keepSearch]["keep"]==true then keepFound=true end
												end
											end
											if gStates.gameScenario=="The Gauntlet" or gStates.gameScenario=="The Hidden Valley Blitz"
												or gStates.gameScenario=="The Hidden Valley Blitz" or gStates.gameScenario=="The Realm of the Dead Blitz"
												or gStates.gameScenario=="Life and Death" or gStates.gameScenario=="Dungeon Lords"
												or gStates.gameScenario=="Druid Nights" or gStates.gameScenario=="Mines Liberation" then
												keepShieldMatch[keepSearch]["cityShield"]=true
												if keepShieldMatch[keepSearch]["city"]==true then cityFound=terrain.getGMNotes() end
												playerDetails.defeatedCities[terrain.guid]="Assist"
											end
										end
										--flip garrisons during the day
										if gStates.autoFlip==true and gStates.dayRound==true and turnOrder[gStates.turnNumber].mage==avatar.mage and terrain.getRotationValues()[2]~=nil and (terrain.getRotationValues()[2].value=="Mage Tower Garrison" or terrain.getRotationValues()[2].value=="Keep Garrison" or terrain.getRotationValues()[2].value=="Marauding Elementalist") then--and gStates.preEndTurn==false
											if terrain.is_face_down==true then terrain.flip() broadcastToAll("{en}Site Garrison Revealed{ru}Гарнизон Укрепленного места раскрыт{zh-tw}守军揭示了{zh-cn}守军揭示了{ko}수비자가 공개되었습니다.{es}Guarnición del Sitio Revelada{fr}La Garnison du Site Révélée{pt-br}Lugar de Guarnição Revelada{de}Standort Garnison aufgedeckt", {1,1,0.5}) end
										end
										--flip ruins at night and Lost Relic dragons day or night
										if gStates.autoFlip==true and turnOrder[gStates.turnNumber].mage==avatar.mage and ((playerDetails.avatarLocation=="ruin" and keepSearch==1) or (terrain.getRotationValues()[2]~=nil and terrain.getRotationValues()[2].value:sub(-8)=="Draconum")) then--and gStates.preEndTurn==false
											--A newly deployed face-down Ruin can pass near the avatar while its container smooth move is
											--still in flight. Flipping that transient object can interrupt its move, so only reveal settled pieces.
											if terrain.is_face_down==true and terrain.isSmoothMoving()==false and terrain.resting==true then
												terrain.flip()
												if playerDetails.avatarLocation=="ruin" then broadcastToAll("{en}Ruin Site Revealed{ru}Руины были раскрыты{zh-tw}废墟板块被揭示了{zh-cn}废墟板块被揭示了{ko}유적 장소 공개됨{es}Sitio de Ruinas Revelado{fr}Site de Ruines Révélé{pt-br}Lugar de Ruinas Revelado{de}Ruinenstätte aufgedeckt", {1,1,0.5}) end
												if playerDetails.avatarLocation~="ruin" then broadcastToAll("{en}Draconum Revealed{ru}Драконид раскрыт{zh-tw}龍人已揭示{zh-cn}龙人已揭示{ko}드라코넘 공개됨{es}Draconum Revelado{fr}Draconum Révélé{pt-br}Draconum Revelado{de}Draconum aufgedeckt", {1,1,0.5}) end
											end
										end
									end
								end
								local avatarAdjust={{-2.39, 0}, {1.2, -2.05}, {2.39, 0}, {1.2, 2.05}, {-1.2, 2.05}, {-2.39, 0}, {0, 0}}
								avatarPos[1]=avatarPos[1]+avatarAdjust[keepSearch][1]
								avatarPos[3]=avatarPos[3]+avatarAdjust[keepSearch][2]
								if cityFound=="False" then playerDetails.nearCity=false
								else playerDetails.nearCity=true end
								if keepFound==true then	playerDetails.nearKeep=true
								else playerDetails.nearKeep=false end
							end
							if avatarPos[3]<-20 then playerDetails.avatarLocation="portal" end
							break
						end
					end
					if turnOrder[gStates.turnNumber].mage==avatar.mage and player_color~=nil and gStates.preEndTurn==false and avatarChangedHex==true and
						apocalypseDragonLairContainsPosition~=nil and apocalypseDragonLairContainsPosition(dropped_object.getPosition())==true and
						gStates.apocalypseDragonDefeated~=true then
						attackedLocation=nil
						local dragonApproach=nil
						if avatarChangedHex==true and playerPickedUpPos[1]~=nil then dragonApproach={playerPickedUpPos[1],playerPickedUpPos[2],playerPickedUpPos[3]} end
						if apocalypseDragonBeginLairAssault(gStates.turnNumber,dragonApproach)==true then
							turnOrder[gStates.turnNumber].avatarLocation="apocalypse dragon"
						end
					end
					if horsemenGladeAssault==true then
						if avatarChangedHex==true and playerPickedUpPos[1]~=nil then assaultApproachOrigin={playerPickedUpPos[1],playerPickedUpPos[2],playerPickedUpPos[3]} end
						local target=dropped_object.getPosition()
						assaultTargetPosition={target[1],target[2],target[3]}
						againstHorsemenBeginGladeAssault(gStates.turnNumber,assaultApproachOrigin)
					elseif attackedLocation~=nil then
						--Keep the actual hex this assault location was entered from. Long moves are deliberately
						--left ambiguous so the wall interface can ask which side was used.
						if avatarChangedHex==true and playerPickedUpPos[1]~=nil then assaultApproachOrigin={playerPickedUpPos[1], playerPickedUpPos[2], playerPickedUpPos[3]} end
						local target=dropped_object.getPosition()
						assaultTargetPosition={target[1], target[2], target[3]}
						local targetFeature=turnOrder[gStates.turnNumber].avatarLocation
						if (targetFeature=="keep" or targetFeature=="mage tower") and wallAssaultChoiceResult==nil and wallAssaultChoiceNeeded(assaultTargetPosition, assaultApproachOrigin)==true then showWallAssaultChoice("attackLocation", attackedLocation, player_color)
						else attackLocation(nil, "-1", attackedLocation) end
					end
					--adjust the hand size
					local cityConversion={["White City"]=GUID.zone.whiteCity, ["Blue City"]=GUID.zone.blueCity, ["Red City"]=GUID.zone.redCity, ["Green City"]=GUID.zone.greenCity}
					local previousHand=turnOrder[gStates.turnNumber].hand
					local handBonusSource=nil
					local raisedReturnCity=(gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz") and gStates.volkareRaisedCity==true
					local nearCityForHand=turnOrder[gStates.turnNumber].nearCity==true and raisedReturnCity~=true
					if (turnOrder[gStates.turnNumber].mage==avatar.mage and turnOrder[gStates.turnNumber].nearKeep==true) or nearCityForHand then
						if nearCityForHand and cityFound~="False" then
							if turnOrder[gStates.turnNumber].defeatedCities[cityScriptZones[cityConversion[cityFound]].cityGUID]=="Lead" then turnOrder[gStates.turnNumber].hand=turnOrder[gStates.turnNumber].baseHand+2 handBonusSource="City" end
							if turnOrder[gStates.turnNumber].defeatedCities[cityScriptZones[cityConversion[cityFound]].cityGUID]=="Assist" then turnOrder[gStates.turnNumber].hand=turnOrder[gStates.turnNumber].baseHand+1 handBonusSource="City" end
						end
						if (turnOrder[gStates.turnNumber].nearKeep==true and nearCityForHand==false) or
							(turnOrder[gStates.turnNumber].nearKeep==true and nearCityForHand==true and turnOrder[gStates.turnNumber].keepsBeat>1) then
							turnOrder[gStates.turnNumber].hand=turnOrder[gStates.turnNumber].baseHand+turnOrder[gStates.turnNumber].keepsBeat
							if turnOrder[gStates.turnNumber].keepsBeat>0 then handBonusSource="Keep" end
						end
					else
						turnOrder[gStates.turnNumber].hand=turnOrder[gStates.turnNumber].baseHand
					end
					if turnOrder[gStates.turnNumber].hand~=previousHand then
						if handBonusSource=="City" then broadcastToAll("{en}Hand size increased from proximity to City{ru}Предел карт в руке увеличен из-за близости города{zh-tw}手牌数量因靠近城市而增加{zh-cn}手牌数量因靠近城市而增加{ko}인접한 도시에 의해 카드 보유 제한이 증가했습니다{es}El tamaño de la mano aumentó de la proximidad a la Ciudad.{fr}La taille de la main a augmenté de la proximité à la Ville{pt-br}O tamanho da mão aumentou devido à proximidade da Cidade{de}Handgröße durch Nähe zur Stadt erhöht", positionToColor(gStates.turnNumber)) end
						if handBonusSource=="Keep" then broadcastToAll("{en}Hand size increased from proximity to Keep{ru}Предел карт в руке увеличен из-за близости крепости{zh-tw}手牌数量增加到最大值{zh-cn}手牌数量增加到最大值{ko}인접한 성에 의해 카드 보유 제한이 증가했습니다{es}El tamaño de la mano aumentó de la proximidad a la Fortaleza{fr}La taille de la main a augmenté de la proximité à la Keep{pt-br}O tamanho da mão aumentou com a proximidade de Keep{de}Handgröße erhöht sich durch die Nähe zu Keep", positionToColor(gStates.turnNumber)) end
					end
					--Reset attack icon and interaction after leaving a hex, but preserve an interaction if the avatar was only repositioned on the same hex.
					if turnOrder[gStates.turnNumber].mage==avatar.mage and attackedLocation==nil and horsemenGladeAssault==false and (avatarChangedHex==true or (next(gStates.attackedMonsters)==nil and UI.getAttribute("zigguratPyramidInteract", "active")~="true")) then
						turnOrder[gStates.turnNumber].combatIconHide="None" gStates.monsterOffsetX=0 gStates.monsterOffsetZ=0
					end
					--Avatar location directly changes Plunder/Pursuit availability.
					--Invalidate the cached menu; the normal location UI refresh will rebuild it when relevant.
					outOfTurnUIStateKey=nil
					mainUIUpdate("Updated player location Details")
					--Quest step availability can depend on the active Mage Knight's current map hex.
					--Use the serialized offer refresh instead of touching Object UI directly here. fakeDropAvatar()
					--can reach this delayed location callback while a Quest offer refill is still physically moving cards;
					--apocalypseQuestRefreshOfferButtons() defers safely until that refill has settled.
					if apocalypseQuestsUsed()==true then apocalypseQuestRefreshOfferButtons() end
					if turnOrder[gStates.turnNumber].mage==avatar.mage then refreshFracturedLandsTeleportHighlights() end
					addAvatarButtons()
					if gStates.rampagePursuit==true and gStates.preEndTurn==false then pursuingRampagers(nil, "-1", nil) end
				end
			end

local function terrainPositionLegal(obj, faceUpTerrain, northBearing, result)--.guid .faceDown .position .objName [.tileType]
	result=result or {}
	local candidateTileType=obj.tileType or (terrainTiles[obj.guid]~=nil and terrainTiles[obj.guid].tileType) or "country"
	--Against the Horsemen uses a completely predefined map. Its face-down tiles are already in
	--their legal positions, so ordinary wedge/open/neighbour placement rules must never reject
	--a tile when it is revealed. Keep face-down tiles dormant; once revealed, always populate them.
	if gStates.gameScenario=="Against the Horsemen Blitz" or gStates.gameScenario=="Fury of the Apocalypse Dragon" then
		if obj.faceDown==true then result.faceDownTerrain=true return false end
		return true
	end

	--Custom Predefined is deliberately unrestricted: players may arrange any face-up terrain anywhere.
	if gStates.gameScenario=="Custom" and gStates.mapShapeKey=="predefined" then
		if obj.faceDown==true then result.faceDownTerrain=true return false end
		return true
	end

	--Check if a core tile is on the coast of a wedge map
	if candidateTileType=="core" and northBearing==70 and (obj.bearing<=41 or obj.bearing>=99) and gStates.gameScenario~="Fast Forwarded Conquest" then result.errorBroadcast="{en}Core Terrain Tiles aren't allowed on the coast{ru}Плитки Развитых земель не могут располагаться на берегу{zh-tw}海岸边不可以部署核心城市板块{zh-cn}海岸边不可以部署核心城市板块{ko}중심부 타일은 해안선에 놓일 수 없습니다{es}Las baldosas de terreno del núcleo no están permitidas en la costa{fr}Les tuiles de terrain de base ne sont pas autorisées sur la côte{pt-br}Peças Mapa Centrais não são permitidas na Costa{de}Kernterrainplättchen sind an der Küste nicht erlaubt" return false end

	--Check if a tile is outside of a wedge map
	if northBearing==70 and (obj.bearing<=35 or obj.bearing>=105) then result.errorBroadcast="{en}Terrain Tile isn't in the Wedge{ru}Плитка земель не находится в форме{zh-tw}地图块不在锥形里 (出界了){zh-cn}地图块不在锥形里 (出界了){ko}지도 타일이 쐐기 안에 있지 않습니다{es}Terrain Tile no está en la cuña{fr}La tuile de terrain n'est pas dans le coin{pt-br}Peça de Terreno não está no Cone{de}Das Geländeplättchen liegt nicht im Keil" return false end

	--Check if tile is on the 4th or 5th column of a limited open map
	if gStates.mapShapeKey=="open3" or gStates.mapShapeKey=="open4" or gStates.mapShapeKey=="open" then
		local checkUpTo=3
		if gStates.mapShapeKey=="open4" then checkUpTo=8 end
		if gStates.mapShapeKey=="open3" then checkUpTo=15 end
		local pos=obj.position
		for b=1, checkUpTo, 1 do
			local edge=terrainPlacementEdgeCoordinates[b]
			if ((pos[1]-edge[1])^2)+((pos[3]-edge[2])^2)<1 then
				result.errorBroadcast=joinLang({"{en}You are playing a {ru}Форма игрового поля - {zh-tw}正在玩的剧本名: {zh-cn}正在玩的剧本名: {ko}플레이 중인 맵: {es}Estás jugando un {fr}Vous jouez à un {pt-br}Você está jogando um(a) {de}Du spielst gerade ein ", gStates.mapShape, "{en} Game{ru} {zh-tw}. {zh-cn}. {ko}{es} juegos{fr} Game{pt-br} Jogo{de} Spiel"})
				return false
			end
		end
	end

	--Check if Core tile has at least two neighbor Tiles
	--Check if Country tile has at least one neighbor that has two neighbor Tiles
	--check if an excess terrain tile has at least three neighbors.
	if gStates.gameScenario~="The Gauntlet" and obj.guid~=firstTile and not (obj.guid=="835c91" and (gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz" or gStates.gameScenario=="Volkare's Quest" or gStates.gameScenario=="The War of Four")) then
		local neighboursFound=0
		local neighbourTile=nil
		local adjacentPositions={}
		for c=1, 6, 1 do
			local offset=terrainPlacementNeighbourOffsets[c]
			adjacentPositions[c]={obj.position[1]+offset[1], obj.position[3]+offset[2]}
		end
		for _, b in pairs(faceUpTerrain) do
			if b.guid~=obj.guid then
				local tested=b.position
				for c=1, 6, 1 do
					local toCheck=adjacentPositions[c]
					if ((tested[1]-toCheck[1])^2)+((tested[3]-toCheck[2])^2)<1 then neighboursFound=neighboursFound+1 neighbourTile=b break end
				end
			end
		end
		if neighboursFound==0 then return false end
		if candidateTileType=="core" and neighboursFound<2 then result.errorBroadcast="{en}Core Terrain Tiles need two or more neighbours{ru}Плитки Развитых земель должны находиться по соседству с двумя другими землями{zh-tw}核心城市板块需要紧邻两个以上的其他板块{zh-cn}核心城市板块需要紧邻两个以上的其他板块{ko}중심부 타일은 최소 2개의 타일과 인접해야 합니다{es}Las baldosas de terreno central necesitan dos o más vecinos{fr}Les tuiles de terrain de base ont besoin de deux voisins ou plus{pt-br}Peças Mapa Centrais precisam de 2 ou mais Vizinhos{de}Kernterrainplättchen benötigen zwei oder mehr Nachbarn" return false end
		if obj.objName=="excess" and neighboursFound<3 then result.errorBroadcast="{en}Excess Terrain Tiles need three or more neighbours, They're meant to fill holes in the map.{ru}Запасные земели должны примыкать хотя бы к трём другим землям (чтобы заполнить дыры).{zh-tw}多余的地形块需要临近3个或更多板块, 这是为了填补地图上的空位{zh-cn}多余的地形块需要临近3个或更多板块, 这是为了填补地图上的空位{ko}추가 지도 타일은 최소 3개의 다른 타일과 인접해야 합니다. 구멍을 메운다는 느낌과 유사합니다.{es}Los mosaicos de terreno en exceso necesitan tres o más vecinos. Están destinados a rellenar huecos en el mapa.{fr}Les tuiles de terrain excédentaire ont besoin de trois voisins ou plus, elles sont destinées à combler les trous sur la carte.{pt-br}Peças de Terreno Excessivas precisam de 3 ou mais vizinhos. Elas são para preencher buracos no mapa{de}Überschüssige Geländeplättchen brauchen drei oder mehr Nachbarn, sie sollen Löcher auf der Karte füllen." return false end
		if candidateTileType~="core" and neighboursFound<=1 then
			neighboursFound=0
			if neighbourTile~=nil then
				local neighbourPositions={}
				for c=1, 6, 1 do
					local offset=terrainPlacementNeighbourOffsets[c]
					neighbourPositions[c]={neighbourTile.position[1]+offset[1], neighbourTile.position[3]+offset[2]}
				end
				for _, b in pairs(faceUpTerrain) do
					if b.guid~=obj.guid then
						local tested=b.position
						for c=1, 6, 1 do
							local toCheck=neighbourPositions[c]
							if ((tested[1]-toCheck[1])^2)+((tested[3]-toCheck[2])^2)<1 then neighboursFound=neighboursFound+1 break end
						end
					end
				end
				if neighboursFound<2 then result.errorBroadcast="{en}Country Terrain Tiles can't be strung out that far{ru}Плитки Диких земель не могут вытягиваться так далеко{zh-tw}乡村板块不能铺那么远{zh-cn}乡村板块不能铺那么远{ko}교외 타일은 그렇게 놓일 수 없습니다{es}Las baldosas de terreno rural no se pueden colocar tan lejos{fr}Les tuiles de terrain de campagne ne peuvent pas être enfilées aussi loin{pt-br}Peças Mapa de Campo não podem ser colocados tão longe{de}Land-Terrainplättchen können nicht so weit aufgereiht werden" return false end
			end
		end
	end

	--Check if a City tile is played to wrong side in Life and Death
	if gStates.gameScenario=="Life and Death" and getObjectFromGUID(GUID.bag.terrain.stack).getQuantity()==1 then
		if obj.guid==GUID.tile.city08 and obj.bearing<=northBearing-1 then --red city
			result.errorBroadcast="{en}Red City needs to be placed in the Northern section{ru}Земля с красным городом не может быть размещена на юге{zh-tw}红色城市需要放在靠北边{zh-cn}红色城市需要放在靠北边{ko}빨간색 도시는 북쪽에 놓여야합니다.{es}Red City debe colocarse en la sección Norte{fr}Red City doit être placé dans la section Nord{pt-br}Cidade Vermelha precisa ser colocada na sessão Norte{de}Die rote Stadt muss in den nördlichen Abschnitt gelegt werden"
			return false
		end
		if obj.guid==GUID.tile.city05 and obj.bearing>=northBearing+1 then --green city
			result.errorBroadcast="{en}Green City needs to be placed in the Southern section{ru}Земля с зелёным городом не может быть размещена на севере{zh-tw}绿色城市需要放置在南边部分{zh-cn}绿色城市需要放置在南边部分{ko}녹색 도시는 남쪽에 놓여야합니다{es}Green City debe colocarse en la sección Sur{fr}Green City doit être placé dans la section Sud{pt-br}Cidade Verde precisa ser colocada na parte Sul do mapa{de}Grüne Stadt muss in die südliche Sektion gelegt werden"
			return false
		end
	end

	--Check if a terrain tile is face up
	if obj.faceDown==true then result.faceDownTerrain=true return false end
	return true
end


--Rebuild EXPLORE buttons directly from the physical map. This path has no terrain-entry side effects.
function refreshTerrainExploreOptions(compactCities)
	if gStates==nil then return end
	local zone=getObjectFromGUID(mapArea)
	if zone==nil then return end
	local playAreaObjects=zone.getObjects()
	local faceUpTerrain={}
	local mapObjectPositions={}
	for _,mapObject in pairs(playAreaObjects) do
		local mapObjectPosition=mapObject.getPosition()
		mapObjectPositions[#mapObjectPositions+1]={guid=mapObject.guid,position=mapObjectPosition}
		if terrainTiles[mapObject.guid]~=nil and mapObject.is_face_down==false then
			faceUpTerrain[#faceUpTerrain+1]={guid=mapObject.guid,position=mapObjectPosition}
		end
	end
	local northBearing=40
	local startTileGUID=startTerrain.open
	if getObjectFromGUID(startTileGUID)==nil then
		if gStates.gameScenario=="Against the Horsemen Blitz" then startTileGUID=GUID.tile.country01
		else startTileGUID=startTerrain.wedge northBearing=70 end
	end
	local startTileObject=getObjectFromGUID(startTileGUID)
	if startTileObject==nil then return end
	local startTilePosition=startTileObject.getPosition()
	--Highlight legal tile plays
	if gStates.gameScenario~="Volkare's Quest" and gStates.gameScenario~="The Gauntlet" and gStates.gameScenario~="The War of Four" and gStates.gameScenario~="Against the Horsemen Blitz" and gStates.gameScenario~="Fury of the Apocalypse Dragon" and not (gStates.gameScenario=="Custom" and gStates.mapShapeKey=="predefined") then
		local gridType=mapShapeGridURL[gStates.mapShapeKey] or ""
		local terrainDecals={}
		terrainExploreButtons={{}}
		if gridType~="" then terrainDecals[#terrainDecals+1]={name="Terrain Grid", url=gridType, position={-16.825, 0.99, 0.55}, rotation={90.0, 0.0, 0.0}, scale={60, 60, 1}} end
		local testTerrain="core"
		local nameTerrain="dud"
		local terrainStack=getObjectFromGUID(GUID.bag.terrain.stack)
		local leftCountry=getObjectFromGUID(GUID.bag.terrain.leftCountry)
		local leftCore=getObjectFromGUID(GUID.bag.terrain.leftCore)
		local terrainStackObjects=terrainStack.getObjects()
		if #terrainStackObjects>0 then
			local nextTerrainIndex=terrainStack.getQuantity()-1
			testTerrain=terrainStackObjects[#terrainStackObjects].guid
			for _, containedTerrain in pairs(terrainStackObjects) do
				if containedTerrain.index==nextTerrainIndex then testTerrain=containedTerrain.guid break end
			end
		else
			nameTerrain="excess"
			testTerrain="country"
		end
		if terrainStack.getQuantity()>0 or leftCountry.getQuantity()>0 or leftCore.getQuantity()>0 then
			for _, terTile in pairs(terrainExploreSpots) do
				local found=false
				for _, mightBeMap in pairs(faceUpTerrain) do
					local existingTile=mightBeMap.position
					if ((terTile[1]-existingTile[1])^2)+((terTile[3]-existingTile[3])^2)<1 then found=true break end
				end
				if found==false and terrainPositionLegal({guid=testTerrain, faceDown=false, objName=nameTerrain, position=terTile, bearing=math.deg(math.atan2(terTile[3]-startTilePosition[3], terTile[1]-startTilePosition[1]))},faceUpTerrain,northBearing,{})==true then--country tile guid stand-in
					terrainDecals[#terrainDecals+1]={name="Legal Play", url="https://steamusercontent-a.akamaihd.net/ugc/1833526258732421084/29942DB5776ABA4145E9E115D1C893574C9A737A/", position=terTile, rotation={90.0, 0.0, 0.0}, scale={6, 6, 1}}
					terrainExploreButtons[#terrainExploreButtons+1]={tag="Button", attributes={id="f2291a"..terTile[1]..","..terTile[3], onClick="global/exploreMap", onMouseDown="global/buttonClicked", onMouseUp="global/buttonClicked", height=150, width=500, tilePosX=terTile[1], tilePosZ=terTile[3], position=(-terTile[1]*100).." "..(-terTile[3]*100).." -1100", rotation="0 0 180", scale="0.38 0.38"},
							children={	{tag="Image", attributes={id="f2291a"..terTile[1]..","..terTile[3].."Image", image="Sliced Button/Button Object Active", type="Sliced"}},
										{tag="HorizontalLayout", attributes={padding="25 25 25 25"},
										children={{tag="Text", attributes={id="f2291a"..terTile[1]..","..terTile[3].."Text", font="Fonts/MKCardText", offsetXY="0 1", fontSize="90", fontStyle="Normal", alignment="MiddleCenter", resizeTextForBestFit="true", resizeTextMaxSize="90", text="{en}EXPLORE{ru}ИССЛЕДОВАТЬ{zh-tw}探索{zh-cn}探索{ko}타일 공개{es}EXPLORAR{fr}EXPLORER{pt-br}EXPLORAR{de}ERKUNDEN SIE"}}}}}}
					--record all the potential future hexes as "explore" so the move can calculate for it.
				end
				end
			end
			for _, teleportDecal in pairs(fracturedLandsTeleportDecals()) do terrainDecals[#terrainDecals+1]=teleportDecal end
			Global.setDecals(terrainDecals)
			getObjectFromGUID("f2291a").UI.setXmlTable(terrainExploreButtons)
			--Now that the complete legal EXPLORE set is known, place each City card once at its closest legal position.
			if compactCities~=false then compactCityCardsAfterExplore(mapObjectPositions) end
	end
end

local function applyPredefinedTerrainTint(playAreaObjects,faceUpTerrain,startBearing,northBearing)
	if gStates.mapShapeKey~="predefined" or gStates.gameScenario=="The Gauntlet" or gStates.gameScenario=="Against the Horsemen Blitz" or gStates.gameScenario=="Fury of the Apocalypse Dragon" then return end
	for _, mightBeMap in pairs(playAreaObjects) do
		if terrainTiles[mightBeMap.guid]~=nil then
			if terrainPositionLegal({guid=mightBeMap.guid, faceDown=false, bearing=startBearing, objName=mightBeMap.getName(), position={mightBeMap.getPosition()[1], 0, mightBeMap.getPosition()[3]}},faceUpTerrain,northBearing,{})==false then
				mightBeMap.setColorTint({r=1.0, g=0.7, b=0.7})--colour tint red
			else
				local useNightTint=(startingMapSetup==true and gStates.startAtNight==true) or (startingMapSetup~=true and gStates.nightTint==true)
				if useNightTint then mightBeMap.setColorTint({r=0.6, g=0.6, b=0.6}) else mightBeMap.setColorTint({r=1.0, g=1.0, b=1.0}) end--colour off
			end
		end
	end
end

--Day/night tint changes need to restore the red illegal-placement tint on predefined maps.
--Do this directly from the real map zone instead of faking a TTS onObjectEnterZone callback.
function refreshPredefinedTerrainTint()
	local mapZone=getObjectFromGUID(mapArea)
	if mapZone==nil or mapZone.getObjects==nil then return end
	local playAreaObjects=mapZone.getObjects()
	local faceUpTerrain={}
	for _,mapObject in pairs(playAreaObjects) do
		if terrainTiles[mapObject.guid]~=nil and mapObject.is_face_down==false then
			faceUpTerrain[#faceUpTerrain+1]={guid=mapObject.guid,position=mapObject.getPosition()}
		end
	end
	local northBearing=getObjectFromGUID(startTerrain.open)==nil and 70 or 40
	applyPredefinedTerrainTint(playAreaObjects,faceUpTerrain,0,northBearing)
end

function mapHandleTerrainZoneEnter(ctx)
	local obj=ctx.obj
	local zoneGUID=ctx.zoneGUID
	local objGUID=ctx.objGUID
	local zoneInfo=ctx.zoneInfo
	local objType=ctx.objType
	--Check if a terrain tile has entered the play area
	if zoneGUID==mapArea and terrainTiles[objGUID]~=nil and workingOnTerrain[objGUID]~=true then
		if startingMapSetup==true then startingMapTiles[objGUID]=true end
		local initialSetupTerrain=startingMapTiles~=nil and startingMapTiles[objGUID]==true
		workingOnTerrain[objGUID]=true
		--Setup terrain still needs normal site/enemy population, but player-exploration UI/effects wait for actual play.
		if initialSetupTerrain~=true then safeWaitTime("Map",function() addAvatarButtons() end, 1.5) end
		local mapZone=getObjectFromGUID(mapArea)
		if mapZone==nil or mapZone.getObjects==nil then
			workingOnTerrain[objGUID]=nil
			return true
		end
		local playAreaObjects=mapZone.getObjects()
		local faceUpTerrain={}
		for _,mapObject in pairs(playAreaObjects) do
			if terrainTiles[mapObject.guid]~=nil and mapObject.is_face_down==false then
				faceUpTerrain[#faceUpTerrain+1]={guid=mapObject.guid,position=mapObject.getPosition()}
			end
		end
		local core=0
		local exploreRefreshedBeforeCity=false
		local faceUp=	{0.0, 180.0,   0.0}
		local faceDown=	{0.0, 180.0, 180.0}
		local y=2
		--figure out which angle is the north south line
		local northBearing=40
		local startTileGUID=startTerrain.open
		local startBearing=0
		if getObjectFromGUID(startTileGUID)==nil then
			if gStates.gameScenario=="Against the Horsemen Blitz" then startTileGUID=GUID.tile.country01
			else startTileGUID=startTerrain.wedge northBearing=70 end
		end
		local startTileObject=getObjectFromGUID(startTileGUID)
		if startTileObject==nil then
			workingOnTerrain[objGUID]=nil
			return true
		end
		local startTilePosition=startTileObject.getPosition()
		local enteredTilePosition=obj.getPosition()
		local enteredTileName=obj.getName()
		startBearing=math.deg(math.atan2(enteredTilePosition[3]-startTilePosition[3], enteredTilePosition[1]-startTilePosition[1]))


		--make predefined maps highlight red
		applyPredefinedTerrainTint(playAreaObjects,faceUpTerrain,startBearing,northBearing)



		--deploy monster token if terrain tile is deployed correctly
		local placementResult={}
		if terrainPositionLegal({guid=objGUID, faceDown=obj.is_face_down, bearing=startBearing, objName=enteredTileName, position={enteredTilePosition[1], 0, enteredTilePosition[3]}},faceUpTerrain,northBearing,placementResult)==true then
			--Before the first round, dayRound is intentionally still false so dayNight() can perform
			--the first transition. Do not let that sentinel make setup terrain look like night.
			if startingMapSetup==true then
				if gStates.startAtNight==true then obj.setColorTint({r=0.6,g=0.6,b=0.6}) else obj.setColorTint({r=1.0,g=1.0,b=1.0}) end
			end
			if initialSetupTerrain~=true then
				againstDragonRevealLair(obj)
				if apocalypseIsHereTerrainRevealed~=nil then apocalypseIsHereTerrainRevealed(obj) end
			end
			--Check if the object is a core tile and unlock elite units
			if terrainTiles[objGUID].tileType=="core" and (objGUID~="835c91" or (objGUID=="835c91" and gStates.volkareCampAsCity==true)) and gStates.gameScenario~="First Reconnaissance" and gStates.gameScenario~="Conquer and Hold" and gStates.gameScenario~="Fury of the Apocalypse Dragon" then
				gStates.playedCoreTiles=gStates.playedCoreTiles+1
				gStates.eliteUnitsUsed=true
				if gStates.playedCoreTiles==1 then broadcastToAll("{en}Elite Units are included in the next Offer{ru}Элитные отряды будут доступны в следующем Раунде{zh-tw}精英部队包含在下个供应区{zh-cn}精英部队包含在下个供应区{ko}다음 라운드부터 엘리트 유닛이 추가됩니다{es}Las Unidades Elite están incluidas en la próxima Oferta{fr}Les unités Elite sont incluses dans la prochaine Offre{pt-br}Unidades Elite estão incluídas na próxima oferta{de}Eliteeinheiten sind im nächsten Angebot enthalten", {1,1,0.5}) end
				core=1
			end

			if startingMapSetup~=true and obj.resting==true and obj.held_by_color==nil and obj.isSmoothMoving()==false then
				refreshTerrainExploreOptions()
			end

			--Against the Apocalypse destroyed terrain
			if initialSetupTerrain~=true and gStates.gameScenario=="Against the Apocalypse Blitz" and gStates.tacticShown==false and enteredTileName~="excess" then
				destroyRestoreLocation(nil, "-1", "id", "destroy", obj)
			end

				--Play the correct pugs for the terrain tile
				local tokenWait=0
				local tokenRefillFrame=nil
				local setupPopulationPending=0
				--Normal exploration keeps the familiar staggered token reveal. During initial setup, the
				--map coordinator already serializes terrain tiles, so do not serialize every hex behind
				--another fixed eight-frame pause. Run each deployment on the next frame and let the tile's
				--real pending count tell map setup when all deployment code has actually executed.
				local function scheduleTerrainPopulation(callback,frames)
					if startingMapSetup==true then
						setupPopulationPending=setupPopulationPending+1
						safeWaitFrames("Map",function()
							callback()
							setupPopulationPending=setupPopulationPending-1
						end,1)
					else
						safeWaitFrames("Map",callback,frames)
					end
				end
				local tileRotation=math.floor(((180-(180-obj.getRotation()[2]))/60)+0.5)*60
				if tileRotation<0 then tileRotation=tileRotation+360 end
				if tileRotation>=360 then tileRotation=tileRotation-360 end
				for hexLocation, hexFeature in pairs(terrainTiles[objGUID].hexFeature) do
					--Only run the all-pile refill once at each deployment step. Initial setup deliberately
					--keeps refills disabled, so there is no reason to schedule its old no-op delay there.
					if startingMapSetup~=true and tokenRefillFrame~=tokenWait+2 then tokenRefillFrame=tokenWait+2 safeWaitFrames("Map",function() tokenRefill() end, tokenRefillFrame) end
				scheduleTerrainPopulation(function()
					local params={}
					--don't deploy token if megapolis is being played
					local free=true
					if gStates.megapolis>gStates.cityTiles-#gStates.citiesPlayed
						and (objGUID==GUID.tile.city05 or objGUID==GUID.tile.city06 or objGUID==GUID.tile.city07 or objGUID==GUID.tile.city08)
						and tonumber(hexLocation)==tileRotation then
						megapolisSuppressTerrainHex(obj,hexFeature,false)
						free=false
					end
					--deploy monster token if hex is free.
					if free==true then
						if gStates.playedAllready[objGUID]~=true then
							if initialSetupTerrain~=true and gStates.gameScenario=="Dungeon Lords" and gStates.tacticShown==false and (hexFeature=="village" or hexFeature=="monastery") then
								dungeonLordsQueueSecretSite(obj,hexLocation,hexFeature)
							end
							--if a monastery tile is placed start dealing advanced actions
							if hexFeature=="monastery" then playMonastery() end

							local tokenPileGreen=monsterPiles.green--Standard green Tokens
							local tokenPileBrown=monsterPiles.tan--Standard Brown Tokens
							local tokenPileRed=	 monsterPiles.red--Standard Red Tokens
							--Rampaging Orcs & Draconum
							if hexFeature=="rampaging" or hexFeature=="draconum" or
								(gStates.gameScenario=="The Chaos Rift" and (hexFeature=="village" or ((hexFeature=="mine" or hexFeature=="") and objGUID==GUID.tile.city08))) then
								playRampagingTokens(obj, startBearing, northBearing, hexLocation, hexFeature, true, initialSetupTerrain~=true)
							end

							--Mine
							if hexFeature=="mine" and gStates.gameScenario=="Mines Liberation" then
								if core==1 then tokenPileGreen=tokenPileRed end
								if getObjectFromGUID(tokenPileBrown).getQuantity()>0 and getObjectFromGUID(tokenPileGreen).getQuantity()>0 then
									local pos={angleToXY(obj, hexLocation)[1]-0.1, y, angleToXY(obj, hexLocation)[2]-0.1}
									local token=getObjectFromGUID(tokenPileBrown).takeObject({rotation=faceDown, position=pos})
									gStates.monsterPlayLocation[token.guid]=pos
									gStates.mineMonsterQty[objGUID]={[token.guid]="alive"}
									token.addDecal({name="NightRules", position={0.85, 0.15, -0.85}, rotation={90, 180, 0}, scale={0.6, 0.6, 1}, url=nightRulesDecal})
									if gStates.monsterPerks[token.guid]==nil then gStates.monsterPerks[token.guid]={nightRules=true} else gStates.monsterPerks[token.guid].nightRules=true end
									local token=getObjectFromGUID(tokenPileGreen).takeObject({rotation=faceUp, position={pos[1]+0.2, pos[2]+0.5, pos[3]+0.2}})
									gStates.monsterPlayLocation[token.guid]={pos[1]+0.2, pos[2]+0.5, pos[3]+0.2}
									gStates.mineMonsterQty[objGUID][token.guid]="alive"
									token.addDecal({name="NightRules", position={0.85, 0.15, -0.85}, rotation={90, 180, 0}, scale={0.6, 0.6, 1}, url=nightRulesDecal})
									if gStates.monsterPerks[token.guid]==nil then gStates.monsterPerks[token.guid]={nightRules=true} else gStates.monsterPerks[token.guid].nightRules=true end
								else
									broadcastToAll("{en}Sorry, there are no tokens left to deploy{ru}Извините, жетонов для размещения не осталось{zh-tw}抱歉，沒有可供部署的標記{zh-cn}抱歉，没有可供部署的标记{ko}여분의 토큰이 없습니다{es}Lo sentimos, no quedan fichas para desplegar{fr}Désolé, il n’y a plus de jetons à déployer{pt-br}Desculpe, não há mais fichas para distribuir{de}Entschuldigung, es sind keine Marker mehr zum Platzieren übrig", warningColor)
								end
								tokenPileGreen=monsterPiles.green
							end

							--glade
							if hexFeature=="glade" then --and objGUID~=GUID.tile.city05 then--stopped it happening on the green city tile but can't figure out why...
								local pos=enteredTilePosition
								local warOfFourDeploy=false
								for _, coords in pairs(warOfFourGladeEdgeCoordinates) do
									if math.sqrt(((pos[1]-coords[1])^2)+((pos[3]-coords[2])^2))<1 then warOfFourDeploy=true break end
								end
								if (gStates.gameScenario=="Life and Death" or (gStates.gameScenario=="The War of Four" and warOfFourDeploy==true)) then -- and core==0
									local tokenFaction=nil
									if startBearing<=northBearing or
										(((startBearing<=northBearing+1 and gStates.coop==1) or (gStates.coop==0 and enteredTilePosition[3]<-7 and enteredTilePosition[3]>-8 and enteredTilePosition[1]<-31 and enteredTilePosition[1]>-32)) and math.random(1,2)==1) then
											tokenFaction="Elem"
										if getObjectFromGUID(monsterPiles.greenElem).getQuantity()>0 then tokenPileGreen=monsterPiles.greenElem end
										if getObjectFromGUID(monsterPiles.tanElem).getQuantity()>0 then tokenPileBrown=monsterPiles.tanElem end--elementalist Tokens
									else
										tokenFaction="Dark"
										if getObjectFromGUID(monsterPiles.greenDark).getQuantity()>0 then tokenPileGreen=monsterPiles.greenDark end
										if getObjectFromGUID(monsterPiles.tanDark).getQuantity()>0 then tokenPileBrown=monsterPiles.tanDark end---Dark Crusader Tokens
										local pos={angleToXY(obj,hexLocation)[1], 1.08, angleToXY(obj,hexLocation)[2]}
										local graveyard=getObjectFromGUID(GUID.bag.cemetery).takeObject({rotation=faceUp, position=pos})
										graveyard.lock()
										terrainTiles[objGUID].hexFeature[hexLocation]="graveyard"
										if gStates.hexOverideSave[objGUID]==nil then gStates.hexOverideSave[objGUID]={} end
										gStates.hexOverideSave[objGUID][hexLocation]="graveyard"
									end
									if getObjectFromGUID(tokenPileBrown).getQuantity()>0 and getObjectFromGUID(tokenPileGreen).getQuantity()>0 then
										local pos={angleToXY(obj,hexLocation)[1]-0.1, y, angleToXY(obj,hexLocation)[2]-0.1}
										for i=1, 2, 1 do
											local monsterPile={tokenPileBrown, tokenPileGreen}
											local token=getObjectFromGUID(monsterPile[i]).takeObject({rotation=faceUp, position={pos[1]+(0.2*(i-1)), pos[2]+(0.5*(i-1)), pos[3]+(0.2*(i-1))}})
											markMonsterFactionSubstitute(token, tokenFaction)
											if terrainTiles[objGUID].hexFeature[hexLocation]=="graveyard" then
												token.addDecal({name="NightRules", position={0.85, 0.15, -0.85}, rotation={90, 180, 0}, scale={0.6, 0.6, 1}, url=nightRulesDecal})
												if gStates.monsterPerks[token.guid]==nil then gStates.monsterPerks[token.guid]={nightRules=true} else gStates.monsterPerks[token.guid].nightRules=true end
											end
											gStates.monsterPlayLocation[token.guid]={pos[1]+(0.2*(i-1)), pos[2]+(0.5*(i-1)), pos[3]+(0.2*(i-1))}
											if gStates.mineMonsterQty[objGUID]==nil then gStates.mineMonsterQty[objGUID]={[token.guid]="alive"} else gStates.mineMonsterQty[objGUID][token.guid]="alive" end
										end
									else
										broadcastToAll("{en}Sorry, there are no tokens left to deploy{ru}Извините, жетонов для размещения не осталось{zh-tw}抱歉，沒有可供部署的標記{zh-cn}抱歉，没有可供部署的标记{ko}여분의 토큰이 없습니다{es}Lo sentimos, no quedan fichas para desplegar{fr}Désolé, il n’y a plus de jetons à déployer{pt-br}Desculpe, não há mais fichas para distribuir{de}Entschuldigung, es sind keine Marker mehr zum Platzieren übrig", warningColor)
									end
								end

								if gStates.gameScenario=="The Realm of the Dead Blitz" and terrainTiles[objGUID].tileType=="country" then
									local deploy={	{monster={{monsterPiles.greenDark, -0.1}, {monsterPiles.greenDark, 0.1}}, reward={advancedActionRewardDecal}},
													{monster={{monsterPiles.tanDark, -0.1}, {monsterPiles.greenDark, 0.1}}, reward={spellRewardDecal}},
													{monster={{monsterPiles.redDark,  0.0}}, reward={unitRewardDecal}},
													{monster={{monsterPiles.redDark, -0.1}, {monsterPiles.greenDark, 0.1}}, reward={artifactRewardDecal}},
													{monster={{monsterPiles.redDark, -0.1}, {monsterPiles.tanDark, 0.1}}, reward={artifactRewardDecal, advancedActionRewardDecal}},
													{monster={{monsterPiles.redDark, -0.1}, {monsterPiles.tanDark, 0.0}, {monsterPiles.greenDark, 0.1}}, reward={artifactRewardDecal, spellRewardDecal}}}--this is for five player games, which is currently imposible
									--play Graveyard Token
									params.position={angleToXY(obj,hexLocation)[1], 1.08, angleToXY(obj,hexLocation)[2]}
									params.rotation=faceDown
									local graveyard=getObjectFromGUID(GUID.bag.cemetery).takeObject(params)
									graveyard.lock()
									terrainTiles[objGUID].hexFeature[hexLocation]="graveyard"
									if gStates.hexOverideSave[objGUID]==nil then gStates.hexOverideSave[objGUID]={} end
									gStates.hexOverideSave[objGUID][hexLocation]="graveyard"
									for index, reward in pairs(deploy[gStates.playedGladeTiles+1].reward) do
										local posOnToken={{0.35, -0.21, 0.35}, {0.0, -0.2, 0.25}}
										graveyard.addDecal({name="Reward", url=reward, position=posOnToken[index], rotation={-90, 0, 0}, scale={0.5, 0.7, 1}})
									end
									--play Monster tokens
									local params2={}
									for index, monsterPile in pairs(deploy[gStates.playedGladeTiles+1].monster) do
										local token=nil
										local monsterPileConvert={[monsterPiles.greenDark]=monsterPiles.green, [monsterPiles.tanDark]=monsterPiles.tan, [monsterPiles.redDark]=monsterPiles.red}
										params2.position={params.position[1]+monsterPile[2], y+(index/2), params.position[3]+monsterPile[2]}
										if getObjectFromGUID(monsterPile[1]).getQuantity()>0 then token=getObjectFromGUID(monsterPile[1]).takeObject(params2) else token=getObjectFromGUID(monsterPileConvert[monsterPile[1]]).takeObject(params2) end
										markMonsterFactionSubstitute(token, "Dark")
										token.addDecal({name="NightRules", position={0.85, 0.15, -0.85}, rotation={90, 180, 0}, scale={0.6, 0.6, 1}, url=nightRulesDecal})
										if gStates.monsterPerks[token.guid]==nil then gStates.monsterPerks[token.guid]={nightRules=true} else gStates.monsterPerks[token.guid].nightRules=true end
										gStates.monsterPlayLocation[token.guid]=params2.position
										if gStates.mineMonsterQty[objGUID]==nil then gStates.mineMonsterQty[objGUID]={[token.guid]="alive"} else gStates.mineMonsterQty[objGUID][token.guid]="alive" end
									end
									gStates.playedGladeTiles=gStates.playedGladeTiles+1
								end
							end

							--Mage Tower
							if hexFeature=="mage tower" then
								params.position={angleToXY(obj, hexLocation)[1], y, angleToXY(obj,hexLocation)[2]}
								params.rotation=faceDown
								if getObjectFromGUID(monsterPiles.purple).getQuantity()>0 then
									local token=getObjectFromGUID(monsterPiles.purple).takeObject(params)
									gStates.monsterPlayLocation[token.guid]=params.position
								else
									broadcastToAll("{en}Sorry, there are no Purple tokens left to deploy{ru}Извините, фиолетовые жетоны закончились.{zh-tw}抱歉，沒有紫色標記可供部署{zh-cn}抱歉，没有紫色标记可供部署{ko}여분의 보라색 토큰이 없습니다{es}Lo sentimos, no quedan tokens púrpuras para implementar{fr}Désolé, il n'y a plus de jetons violets à déployer{pt-br}Desculpe, Não tem Fichas Roxas sobrando para distribuir{de}Leider gibt es keine violetten Plättchen mehr zum Einsetzen", warningColor)
								end
							end

							--Keep
							if hexFeature=="keep" then
								local token={}
								params.position={angleToXY(obj,hexLocation)[1], y, angleToXY(obj, hexLocation)[2]}
								params.rotation=faceDown
								if gStates.gameScenario=="The Hidden Valley Blitz" and objGUID==GUID.tile.city07 then
									gStates.mineMonsterQty[objGUID]=gStates.mineMonsterQty[objGUID] or {}
									local center=angleToXY(obj,hexLocation)
									for i, offset in ipairs({-0.1, 0.1}) do
										params.position={center[1]+offset, y, center[2]+offset}
										local token=takeFactionMonster("green", "Elem", params)
										if token~=nil then
											gStates.monsterPlayLocation[token.guid]=params.position
											gStates.hiddenValleyKeep[i]=token.guid
											gStates.mineMonsterQty[objGUID][token.guid]="alive"
										else
											broadcastToAll("{en}Sorry, there are no Green tokens left to deploy{ru}Извините, зеленые жетоны закончились.{zh-tw}抱歉，没有绿色标记可供部署{zh-cn}抱歉，没有绿色标记可供部署{ko}여분의 녹색 토큰이 없습니다{es}Lo sentimos, no quedan tokens verdes para implementar{fr}Désolé, il n'y a plus de jetons verts à déployer{pt-br}Desculpe, Não tem Fichas Verde sobrando para distribuir{de}Tut mir leid, es gibt keine grünen Plättchen mehr zum Einsetzen", warningColor)
										end
									end
								else
									if getObjectFromGUID(monsterPiles.gray).getQuantity()>0 then
										local token=getObjectFromGUID(monsterPiles.gray).takeObject(params)
										gStates.monsterPlayLocation[token.guid]=params.position
									else
										broadcastToAll("{en}Sorry, there are no Gray tokens left to deploy{ru}Извините, серые жетоны закончились.{zh-tw}抱歉，没有灰色标记可供部署{zh-cn}抱歉，没有灰色标记可供部署{ko}여분의 회색 토큰이 없습니다.{es}Lo sentimos, no quedan tokens grises para desplegar{fr}Désolé, il n'y a plus de jetons gris à déployer{pt-br}Desculpe, Não tem Fichas Cinza sobrando para distribuir{de}Entschuldigung, es gibt keine grauen Plättchen mehr zum Auslegen", warningColor)
									end
								end
							end

							--Ruins
							if hexFeature=="ruin" then
								local target={angleToXY(obj, hexLocation)[1], y, angleToXY(obj, hexLocation)[2]}
								local ruinBag=getObjectFromGUID(monsterPiles.yellow)
								local bagPos=ruinBag.getPosition()
								--Extract beside the bag first. Giving takeObject() the destination rotation/position lets TTS
								--rotate a token while its container smooth-move is still in flight.
								local token=ruinBag.takeObject({position={bagPos[1],bagPos[2]+2,bagPos[3]},rotation=faceDown,smooth=false})
								gStates.monsterPlayLocation[token.guid]=target
								mapTokenSettleArrival(token.guid,target,{force=true,rotation=faceDown})
								if gStates.dayRound==true then revealRuinAfterArrival(token.guid) end
							end

							--City
							if ((hexFeature or ""):sub(1, 4)=="city" or hexFeature=="Volkare's Camp")
								and (objGUID~="835c91" or (objGUID=="835c91" and gStates.volkareCampAsCity==true))
								or (hexLocation=="center" and gStates.removeShadesOfTezlaMonsters~=true and gStates.gameScenario=="Ultimate Conquest" and (objGUID==GUID.tile.core03 or objGUID==GUID.tile.core10)) then
								--Choose the City card's first destination against the frontier created by this tile.
								--Without this, cityInitialCardPosition() reads the previous EXPLORE set and the later
								--terrain-finish refresh redirects the same smooth move mid-flight.
								if startingMapSetup~=true and exploreRefreshedBeforeCity~=true then
									refreshTerrainExploreOptions()
									exploreRefreshedBeforeCity=true
								end
								playCity(obj, hexFeature, true)
							end
						end
					end
				end, tokenWait+8)
				if gStates.playedAllready[objGUID]~=true and
					(hexFeature=="rampaging" or hexFeature=="draconum" or hexFeature=="mage tower" or hexFeature=="keep" or	hexFeature=="ruin" or hexFeature=="Volkare's Camp" or (hexFeature or ""):sub(1, 4)=="city" or
					(hexFeature=="mine" and gStates.gameScenario=="Mines Liberation") or
					(hexFeature=="glade" and (gStates.gameScenario=="Life and Death" or gStates.gameScenario=="The War of Four" or gStates.gameScenario=="The Realm of the Dead Blitz"))) then--and objGUID~=GUID.tile.city05
					tokenWait=tokenWait+8
				end
			end
			--lock terrain tile if succesfuly deployed all tokens
			safeWaitCondition("Map",function() obj.lock() end, function() return obj.resting end)
			local function finishTerrainPopulation()
				gStates.playedAllready[objGUID]=true
				workingOnTerrain[objGUID]=false
				--A City reveal already refreshed immediately before its initial card placement.
				--Do not compact it a second time while that smooth move is still in progress.
				if startingMapSetup~=true and exploreRefreshedBeforeCity~=true then refreshTerrainExploreOptions() end
				--Terrain deployment changes the movement graph directly. Refresh it here instead of relying on
				--the later fake avatar drop to eventually trigger a full UI update.
				if initialSetupTerrain~=true and gStates.firstStarted==true then
					moveDisplayTerrainCache={signature=nil,hexMap=nil}
					updateMoveDisplay()
				end
				if gStates.gameScenario=="Against the Horsemen Blitz" then againstHorsemenRefreshReveals() end
				--Only the newly populated tile can have gained a new shared-token stack. Leave established
				--tokens elsewhere on the map completely untouched.
				mapTokenArrangeAllOccupiedHexes(objGUID)
				if initialSetupTerrain~=true then fakeDropAvatar() end
				apocalypseQuestRefreshOfferButtons()
			end
			if startingMapSetup==true then
				safeWaitCondition("Map",finishTerrainPopulation,function()
					return setupPopulationPending==0 and obj.resting==true
				end,10,function()
					error("SetupGame timed out waiting for initial terrain deployment callbacks for "..tostring(objGUID)..".",2)
				end)
			else
				safeWaitFrames("Map",finishTerrainPopulation,tokenWait+10)
			end

			--Fame is awarded only for terrain actually explored during play. Initial setup terrain is
			--tagged when it enters the map and never counts as exploration in these scenarios.
			if initialSetupTerrain~=true and
				(gStates.gameScenario=="First Reconnaissance" or gStates.gameScenario=="The Lost Relic Blitz" or gStates.gameScenario=="The Fractured Lands Blitz") and gStates.tacticShown==false then
				turnOrder[gStates.turnNumber].fameGain=turnOrder[gStates.turnNumber].fameGain+1
				local centerFeature=terrainTiles[objGUID].hexFeature["center"] or ""
				if gStates.gameScenario=="The Lost Relic Blitz" and (centerFeature:sub(1,4)=="city" or centerFeature=="Volkare's Camp") then
					turnOrder[gStates.turnNumber].fameGain=turnOrder[gStates.turnNumber].fameGain+1
				end
				broadcastToAll("{en}Exploring gives fame gain in this Scenario{ru}Исследование дает Славу в этом сценарии{zh-tw}在这个剧本探索板块会增加名望{zh-cn}在这个剧本探索板块会增加名望{ko}이 시나리오에선 탐험시 명성을 얻습니다{es}Explorar da fama en este Escenario{fr}L'exploration donne un gain de renommée dans ce Scénario{pt-br}Explorar dá Fama neste Cenário{de}Erkunden bringt in diesem Szenario Ruhmgewinn", {1,1,0.5})
				mainUIUpdate("Fame Gain from exploring")
			end
		else
			workingOnTerrain[objGUID]=false
			if (placementResult.errorBroadcast or "")~="" then broadcastToAll(placementResult.errorBroadcast, warningColor) end
			if placementResult.faceDownTerrain~=true then obj.setColorTint({r=1.0, g=0.7, b=0.7}) end
		end
	end

        -- Flip Info cards that match the terrain
        if zoneGUID==mapArea and terrainTiles[objGUID]~=nil and (obj.getRotation()[3] <= 5 or obj.getRotation()[3] >= 355) then
		for hexLocation, hexFeature in pairs(terrainTiles[objGUID].hexFeature) do
			local infoGUID=terrainInfoCardGUIDs[hexFeature]
			if hexFeature=="mine" then
				local mineColors=terrainTiles[objGUID].mineColors~=nil and terrainTiles[objGUID].mineColors[hexLocation] or nil
				if mineColors~=nil and #mineColors==1 then infoGUID="938554" end
			end
			if infoGUID~=nil then
				local citySpecificInfo=hexFeature=="city green" or hexFeature=="city red" or hexFeature=="city blue" or hexFeature=="city white"
				--City colour can change later in playCity() (duplicate/random City replacement).
				--Reveal coloured City cards there, after the final deployed City GUID is known.
				if citySpecificInfo==false then
					local infoCard=getObjectFromGUID(infoGUID)
					if infoCard~=nil then infoCard.setRotationSmooth({0.00, 180.00, 0.00}) end
				end
			end
		end
		local wallList=terrainTiles[objGUID].wallList
			if wallList~=nil and next(wallList)~=nil then
				local wallInfoCard=getObjectFromGUID("767084")
				if wallInfoCard~=nil then wallInfoCard.setRotationSmooth({0.00, 180.00, 0.00}) end
			end
        end
	if zoneGUID==mapArea and terrainTiles[objGUID]~=nil then return true end
	return false
end

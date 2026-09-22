-- Map state, avatar location, exploration, shields and terrain-site runtime.

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

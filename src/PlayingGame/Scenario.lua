-- Scenario-private helpers. Predeclared so forward references keep resolving locally.
local volkareCampMapPositionForPlayer, volkareCampHexInfoAtPosition, volkarePursuitHexUsed, volkarePursuitDropShield, oneToReturnPortalTile
local oneToReturnSetPortalClosedDecal, oneToReturnPortalOccupant, currentMageAvatarPosition, mineLiberatedForClaim, mineClaimData
local clearScenarioEndAchieved, dungeonLordsSecretSourceFeature, dungeonLordsSecretSourcePosition, dungeonLordsSecretSpaceBasicLegal, dungeonLordsFindAdjacentSecretSource
local dungeonLordsSecretDestinationLegal, dungeonLordsSecretLegalDestinationCount, dungeonLordsSecretRequestMatches, dungeonLordsQueueSecretRequest, dungeonLordsPruneImpossibleSecretRequests
local againstHorsemenRitualDefenders, againstHorsemenPortalCardLayout, againstHorsemenEliminateCentralPlayers, againstHorsemenPrepareRitual, againstHorsemenRefreshHorseman
local againstHorsemenGladePosition, againstHorsemenInlineGridDistance, againstHorsemenDefaultNextPosition, againstHorsemenFinalizeMoveWave, againstHorsemenAnimateMoveWave
local againstHorsemenContinueEndRoundMovement, againstHorsemenStartingLevel, apocalypseIsHereHorsemanStartingLevel, apocalypseIsHereRevealThreshold, apocalypseIsHereRecomputeNextHorseman
local apocalypseIsHereCancelReservedReveal, apocalypseIsHereDeployReservedHorseman, apocalypseIsHereRevealNextHorseman, apocalypseIsHerePossessEnemy, apocalypseIsHerePossessRampagersOnTile
local apocalypseIsHereRevealDragonCity, apocalypseIsHereCurrentHorsemanHex, apocalypseIsHereHorsemanTargetOptions, apocalypseIsHereHorsemanDestination, apocalypseIsHereClearChoiceButtons
local apocalypseIsHereShowTargetChoice, apocalypseIsHereRefreshPendingTargetChoice, apocalypseIsHereHorsemanClearTarget, apocalypseIsHereHorsemanDestroyTarget, apocalypseIsHereHexByKey
local apocalypseIsHereHorsemanMoveFinished, apocalypseIsHereResolveHorsemanTarget, apocalypseIsHereProcessNextHorseman, apocalypseIsHereContinueHorsemenTurn, apocalypseIsHereActiveHorsemen
local apocalypseIsHereMainUIRefresh, apocalypseIsHereFinishHorsemenTurn, takeDestroyedSiteToken, arrangeDestroyedSiteHex, againstApocalypseObjectivesComplete
local againstApocalypseCheckCompletion, againstApocalypseMarkPossessedRampager, restoreDestroyedSite, furyDragonEliteConditionMet, againstDragonActive
local againstDragonPlayerIndexForMage, againstDragonClearBlackManaMarkers, againstDragonPlayerMarked, againstDragonMarkPlayer, againstDragonTargetChoiceButton
local againstDragonShowMapChoice, againstDragonShowOffMapChoice, againstDragonMapHexByKey, againstDragonDistanceStarts, againstDragonDistanceChoices
local againstDragonPlayerHex, againstDragonSiteEligible, againstDragonDestroyCandidates, againstDragonActionLabel, againstDragonFinalReport
local againstDragonResolveDestroyOption, againstDragonGainFame, againstDragonAttendanceAuthorized, againstDragonFullAttendAllowed, againstDragonAirborneTokenPosition
local againstDragonAirborneMonsterData, againstDragonDeployAirborneHeads, againstDragonAirborneProtectionLocation, againstDragonAirborneProtectionReminder, againstDragonCaptureAirborneSuppression
local againstDragonAttendPartial, againstDragonBeginManualAttack, againstDragonResolveOffMapPlayer, againstDragonTurnAction, furyDragonCompleteTurn
local furyDragonFeatureMatches, furyDragonHexHasLiveRampager, furyDragonTargetCategory, furyDragonMapTilesAdjacent, furyDragonCurrentHex
local furyDragonLairTarget, furyDragonLowestHead, furyDragonTargetHead, furyDragonTargetWouldOverflow, furyDragonChooseTarget
local furyDragonCityModelGUID, furyDragonCityCard, furyDragonTargetPosition, furyDragonManaColor, furyDragonTargetLabel
local furyDragonMoveMarkerOffMap, furyDragonBeginLandedTurn, furyDragonPlayersOnTarget, furyDragonDiscardHexEnemies, furyDragonDestroyHex
local furyDragonRemoveCityDefender, furyDragonIncreaseHead, furyDragonResolveArrivalEffect, furyDragonBeginInFlightTurn

-- Scenario and variant runtime systems. Setup/menu construction remains in SetupGame.

-- Fractured Lands terrain-orientation controls used by the generic exploration flow.
local function fracturedLandsOrientationButtons(tile)
	if tile==nil then return end
	--Use the same counter-rotation plane as Avatar controls so this strip stays at the visual bottom of the tile.
	--The three controls deliberately copy the Artifact deck's arrow / centre button / arrow layout.
	tile.clearButtons()--clear any createButton controls before installing the XML strip
	local tileRotation=tile.getRotation()[2] or 180
	local rotationPlane=tostring(tileRotation-180)
	local prefix=tile.guid
	local buttonY=175--position offsets are not scaled; keep the strip close beneath the terrain tile
	local buttonZ=-25
	local buttonScale="0.18144 0.18144"--locked-in visual scale
	local xml={{tag="Panel", attributes={id=prefix.."FracturedRotationPlane", height=800, width=900, position="0 0 -25", rotation="0 0 "..rotationPlane, color="rgba(0,0,0,0.0)"}, children={
		{tag="Button", attributes={id=prefix.."ArtifactUp", onMouseDown="global/buttonClicked", onMouseUp="global/buttonClicked", onClick="global/fracturedLandsRotateLeft", height=150, width=150, color="rgba(0,0,0,0.0)", position="-54 "..buttonY.." "..buttonZ, rotation="0 0 180", scale=buttonScale}, children={{tag="Image", attributes={id=prefix.."ArtifactUpImage", image="Overkill Up"}}}},
		{tag="Button", attributes={id=prefix.."FracturedDone", onMouseDown="global/buttonClicked", onMouseUp="global/buttonClicked", onClick="global/fracturedLandsOrientationDone", height=150, width=400, color="rgba(0,0,0,0.0)", position="0 "..buttonY.." "..buttonZ, rotation="0 0 180", scale=buttonScale}, children={{tag="Image", attributes={id=prefix.."FracturedDoneImage", image="Sliced Button/Button Object Active", type="Sliced"}}, {tag="Text", attributes={font="Fonts/MKCardText", fontSize=90, color="black", fontStyle="Normal", alignment="MiddleCenter", text="{en}Done{ru}Готово{zh-tw}完成{zh-cn}完成{ko}완료{es}Listo{fr}Terminé{pt-br}Concluído{de}Fertig"}}}},
		{tag="Button", attributes={id=prefix.."ArtifactDown", onMouseDown="global/buttonClicked", onMouseUp="global/buttonClicked", onClick="global/fracturedLandsRotateRight", height=150, width=150, color="rgba(0,0,0,0.0)", position="54 "..buttonY.." "..buttonZ, rotation="0 0 180", scale=buttonScale}, children={{tag="Image", attributes={id=prefix.."ArtifactDownImage", image="Overkill Down"}}}}
	}}}
	tile.UI.setXmlTable(xml)
end
local function fracturedLandsOrientationPlayerLegal(playerColor)
	return gStates.fracturedLandsOrientation~=nil and playerColor~=nil and legalPlayerCheck(playerColor, gStates.fracturedLandsOrientation.seatPos)==true
end
local function fracturedLandsRotate(player, direction)
	local pending=gStates.fracturedLandsOrientation
	local tile=pending~=nil and getObjectFromGUID(pending.guid) or nil
	if pending==nil or tile==nil or pending.busy==true or player==nil or fracturedLandsOrientationPlayerLegal(player.color)~=true then return end
	pending.busy=true
	local rotation=tile.getRotation()
	rotation[2]=(math.floor((rotation[2]/60)+0.5)*60+(60*direction))%360
	local targetRotation=rotation[2]
	local tileGUID=tile.guid
	tile.setRotationSmooth(rotation, false, true)
	--Follow the smooth turn by changing only the transparent rotation plane, not rebuilding the three buttons.
	--This keeps the controls visually beneath the tile throughout the animation, the same principle used by Avatar buttons.
	local followFrames=0
	local function followRotation()
		local current=gStates.fracturedLandsOrientation
		local currentTile=current~=nil and getObjectFromGUID(current.guid) or nil
		if current==nil or current.guid~=tileGUID or currentTile==nil then return end
		followFrames=followFrames+1
		local currentRotation=currentTile.getRotation()[2] or targetRotation
		currentTile.UI.setAttribute(tileGUID.."FracturedRotationPlane", "rotation", "0 0 "..tostring(currentRotation-180))
		local difference=math.abs(((currentRotation-targetRotation+180)%360)-180)
		if difference<0.5 or followFrames>=60 then current.busy=false return end
		safeWaitFrames("Scenario",followRotation, 1)
	end
	safeWaitFrames("Scenario",followRotation, 1)
end
function fracturedLandsRotateLeft(player, value, id) fracturedLandsRotate(player, -1) end
function fracturedLandsRotateRight(player, value, id) fracturedLandsRotate(player, 1) end
function fracturedLandsOrientationDone(player, value, id)
	local pending=gStates.fracturedLandsOrientation
	local tile=pending~=nil and getObjectFromGUID(pending.guid) or nil
	if pending==nil or tile==nil or pending.busy==true or player==nil or fracturedLandsOrientationPlayerLegal(player.color)~=true then return end
	--The orientation height is above the map scripting zone. Done only releases the tile;
	--its real entry into the map zone performs every normal terrain setup step.
	tile.unlock()
end
function startFracturedLandsOrientation(tile, position)
	tile.setPosition({position[1], 2.20, position[3]})
	tile.lock()
	gStates.fracturedLandsOrientation={guid=tile.guid, seatPos=turnOrder[gStates.turnNumber].seatPos, position={position[1],0.97,position[3]}, busy=false}
	fracturedLandsOrientationButtons(tile)
end

--Volkare's Camp-as-City rules are proximity based. Keep the real avatarLocation intact so any
--printed site on one of the six surrounding hexes can still use its normal rules.
function volkareCampAsCityConquered()
	--During setup defeatedCities is still the legacy numeric sentinel until the first city-state refresh.
	if gStates.volkareCampAsCity~=true or type(gStates.defeatedCities)~="table" then return false end
	return gStates.defeatedCities[volkare.terrainHex]==true and gStates.cityVolkareTile~=nil
end

function volkarePursuitShieldRegistered(obj)
	if obj==nil then return false end
	if obj.getGMNotes~=nil and obj.getGMNotes()=="Volkare Pursuit" then return true end
	return gStates.volkarePursuitShields~=nil and gStates.volkarePursuitShields[obj.guid]~=nil
end

volkareCampMapPositionForPlayer=function(playerIndex)
	local player=turnOrder[playerIndex]
	if player==nil then return nil end
	local cityGUID=player.avatarSwapCity
	local location=player.avatarLocation or ""
	if cityGUID==nil then
		local cityByLocation={["city blue"]=cityModel.blue,["raised blue"]=cityModel.blue,["city red"]=cityModel.red,["raised red"]=cityModel.red,
			["city green"]=cityModel.green,["raised green"]=cityModel.green,["city white"]=cityModel.white,["raised white"]=cityModel.white}
		cityGUID=cityByLocation[location]
	end
	if location=="Volkare's Camp" then cityGUID=volkare.terrainHex end
	if cityGUID~=nil and gStates.cityMonsterQty~=nil and gStates.cityMonsterQty[cityGUID]~=nil then
		local extra=gStates.cityMonsterQty[cityGUID].extra
		local terrainGUID=extra~=nil and extra.terainGUID or nil
		local terrain=terrainGUID~=nil and getObjectFromGUID(terrainGUID) or nil
		if terrain~=nil then return terrain.getPosition() end
	end
	return mageKnightAvatarPosition(playerIndex)
end

volkareCampHexInfoAtPosition=function(position)
	if volkareCampAsCityConquered()~=true or position==nil then return nil end
	local campTerrain=getObjectFromGUID(gStates.cityVolkareTile)
	if campTerrain==nil then return nil end
	local terrain,bearing,hexCenter=terrainHexAtPosition(position)
	if terrain==nil or bearing==nil or hexCenter==nil then return nil end
	local campPos=campTerrain.getPosition()
	local dx=hexCenter[1]-campPos[1]
	local dz=hexCenter[3]-campPos[3]
	if (dx*dx)+(dz*dz)>7 then return nil end
	return {terrainGUID=terrain.guid,bearing=bearing,key=terrain.guid.."|"..tostring(bearing),position={hexCenter[1],2,hexCenter[3]}}
end

function volkareCampPlayerHexInfo(playerIndex)
	return volkareCampHexInfoAtPosition(volkareCampMapPositionForPlayer(playerIndex))
end

function volkareCampContributionShieldCount(playerRef)
	local playerIndex=type(playerRef)=="number" and playerRef or nil
	local player=playerIndex~=nil and turnOrder[playerIndex] or playerRef
	if player==nil or player.mage==nil or volkareCampAsCityConquered()~=true then return 0 end
	local zone=getObjectFromGUID(volkare.discZone)
	if zone==nil then return 0 end
	local count=0
	for _,obj in pairs(zone.getObjects()) do if obj.getName()=="Shield" and obj.getDescription()==player.mage then count=count+1 end end
	return count
end

volkarePursuitHexUsed=function(hexKey)
	if hexKey==nil then return false end
	if gStates.volkarePursuitShields==nil then gStates.volkarePursuitShields={} end
	for guid,storedKey in pairs(gStates.volkarePursuitShields) do
		local shield=getObjectFromGUID(guid)
		if shield==nil then
			gStates.volkarePursuitShields[guid]=nil
		else
			local info=volkareCampHexInfoAtPosition(shield.getPosition())
			if info~=nil then storedKey=info.key gStates.volkarePursuitShields[guid]=storedKey end
			if storedKey==hexKey then return true end
		end
	end
	return false
end

function volkarePursuitActionInfo(playerIndex)
	local player=turnOrder[playerIndex]
	if player==nil or gStates.preEndTurn==true or playerIndex~=gStates.turnNumber or player.combatIconHide~="None" then return nil end
	local token=getObjectFromGUID(player.turnOrderTokenGUID)
	if token==nil or token.is_face_down==true then return nil end
	local info=volkareCampPlayerHexInfo(playerIndex)
	if info==nil or volkarePursuitHexUsed(info.key)==true then return nil end
	return info
end

volkarePursuitDropShield=function(playerIndex,combat)
	local player=turnOrder[playerIndex]
	if player==nil or combat==nil or combat.position==nil then return nil end
	local details=mageKnightsByName[player.mage]
	local container=details~=nil and getObjectFromGUID(details.shieldContainer) or nil
	if container==nil then return nil end
	local shield=container.takeObject({position={combat.position[1]+0.55,3,combat.position[3]},smooth=false})
	if shield==nil then return nil end
	shield.setGMNotes("Volkare Pursuit")
	if gStates.volkarePursuitShields==nil then gStates.volkarePursuitShields={} end
	gStates.volkarePursuitShields[shield.guid]=combat.hexKey
	safeWaitTime("Scenario",function() if getObjectFromGUID(shield.guid)~=nil then safeWaitCondition("Scenario",function() shield.lock() end,function() return shield.resting end) end end,1.0)
	broadcastToAll(joinLang({translateWord[player.mage],"{en} marked a Volkare Pursuit hex.{ru} отметил гекс преследования Волкара.{zh-tw}标记了一个沃卡里追击格。{zh-cn}标记了一个沃卡里追击格。{ko}: 볼케어 추격 칸을 표시했습니다.{es} marcó un hexágono de Persecución de Volkare.{fr} a marqué un hexagone de Poursuite de Volkare.{pt-br} marcou um hexágono de Perseguição de Volkare.{de} hat ein Feld für die Verfolgung Volkares markiert."}),positionToColor(playerIndex))
	return shield
end

function volkarePursuitResolveCombat(playerIndex)
	local combat=gStates.volkarePursuitCombat
	if combat==nil or combat.player~=playerIndex then return end
	local success=false
	for _,obj in pairs(playerCombatObjects(turnOrder[playerIndex].seatPos)) do
		if combat.monsters~=nil and combat.monsters[obj.guid]==true and obj.is_face_down==false then success=true break end
	end
	if success==true and volkarePursuitHexUsed(combat.hexKey)~=true then volkarePursuitDropShield(playerIndex,combat) end
	gStates.volkarePursuitCombat=nil
	gStates.volkarePursuitChoicePlayer=nil
end

function volkareArmyStillAlive()
	local army=gStates~=nil and gStates.cityMonsterQty~=nil and gStates.cityMonsterQty[volkare.model] or nil
	if type(army)~="table" then return false end
	for guid,state in pairs(army) do if guid~="extra" and state=="alive" then return true end end
	return false
end

--City raising is needed by both Volkare's movement processor and later combat-prompt callbacks.
function volkareRazesCity(cityKey)
	if cityKey==nil or cityKey==0 or gStates.cityRevealed[cityKey]==nil then return end
	local city=gStates.cityRevealed[cityKey]
	local cityColor={[cityModel.blue]="blue", [cityModel.red]="red", [cityModel.green]="green", [cityModel.white]="white"}
	runtimeMapSetHexFeature(city.terrain,"center","raised "..cityColor[city.model])
	if gStates.hexOverideSave[city.terrain]==nil then gStates.hexOverideSave[city.terrain]={} end
	gStates.hexOverideSave[city.terrain].center="raised "..cityColor[city.model]
	local cityZone={[cityModel.blue]=GUID.zone.blueCity, [cityModel.red]=GUID.zone.redCity, [cityModel.green]=GUID.zone.greenCity, [cityModel.white]=GUID.zone.whiteCity}
	getObjectFromGUID(cityScriptZones[cityZone[city.model]].cityCard).setDescription("{en}Raised City - Provides no Interaction{ru}Поднятый город — взаимодействие недоступно{zh-tw}升起的城市－無法互動{zh-cn}升起的城市－无法互动{ko}상승한 도시 - 상호작용 불가{es}Ciudad Elevada - No permite Interacción{fr}Cité Élevée - Aucune Interaction{pt-br}Cidade Elevada - Sem Interação{de}Erhöhte Stadt - Keine Interaktion")
	getObjectFromGUID(cityScriptZones[cityZone[city.model]].cityCard).addDecal({name="City Raised", url="https://steamusercontent-a.akamaihd.net/ugc/938341811903683200/0910E72610C36BACDEF44CB3BA2A909BA4AFC12E/",
		position={0.0,0.5,0.0}, rotation={90.0,180.0,0.0}, scale={1,2,2}})
	gStates.volkareRaisedCity=true
end

--Volkare's Quest only: once he reaches three spaces from the portal the Council closes it permanently.
--Mark the closed portal with the dedicated portal-closure artwork.
volkarePortalClosedDecalURL="https://steamusercontent-a.akamaihd.net/ugc/9820771160644960489/29318B61F2A30E0E941F355C3664303B0C95BC60/"
function volkareQuestPortalTile()
	local portalTile=getObjectFromGUID(startTerrain.open)
	if portalTile==nil then portalTile=getObjectFromGUID(startTerrain.wedge) end
	return portalTile
end
function volkareQuestPortalStatus()
	if gStates.gameScenario~="Volkare's Quest" or gStates.volkarePortalClosed==true then return false end
	local volkareObj=gStates.volkareModel~=nil and getObjectFromGUID(gStates.volkareModel) or nil
	local portalTile=volkareQuestPortalTile()
	if volkareObj==nil or portalTile==nil then return false end
	local vPos=volkareObj.getPosition()
	local pPos=portalTile.getPosition()
	local distance=math.sqrt(((vPos[1]-pPos[1])^2)+((vPos[3]-pPos[3])^2))
	--Euclidean distance is sufficient here, but do not divide-and-round it: different hexes on the same ring have different radii.
	--These thresholds sit in the clear gaps between the 3/4-space and 4/5-space rings.
	local closeDistance=2.39*3.25
	local warningDistance=2.39*4.20
	if distance>closeDistance and distance<=warningDistance and gStates.volkarePortalWarningShown~=true then
		gStates.volkarePortalWarningShown=true
		broadcastToAll("{en}WARNING: Volkare is four spaces from the Portal. If he moves within three spaces, the Council of the Void will close it.{ru}ВНИМАНИЕ: Волкар находится в четырёх клетках от Портала. Если он приблизится на три клетки, Совет Пустоты закроет Портал.{zh-tw}警告：沃卡里距離傳送門四格。若他進入三格範圍內，虛空議會將關閉傳送門。{zh-cn}警告：沃卡里距离传送门四格。若他进入三格范围内，虚空议会将关闭传送门。{ko}경고: 볼케어가 포털에서 4칸 떨어져 있습니다. 3칸 이내로 이동하면 공허의 의회가 포털을 닫습니다.{es}ADVERTENCIA: Volkare está a cuatro espacios del Portal. Si se acerca a tres espacios, el Consejo del Vacío lo cerrará.{fr}ATTENTION : Volkare se trouve à quatre cases du Portail. S’il s’approche à trois cases, le Conseil du Vide le fermera.{pt-br}AVISO: Volkare está a quatro espaços do Portal. Se ele chegar a três espaços, o Conselho do Vácuo fechará o Portal.{de}WARNUNG: Volkare ist vier Felder vom Portal entfernt. Kommt er auf drei Felder heran, wird der Rat der Leere das Portal schließen.", {1,0.65,0.15})
	end
	if distance>closeDistance then return false end
	gStates.volkarePortalClosed=true
	gStates.volkarePortalWarningShown=true
	local decals=portalTile.getDecals() or {}
	local marked=false
	for _, decal in pairs(decals) do if decal.name=="Portal Closed" then marked=true break end end
	if marked==false then portalTile.addDecal({name="Portal Closed",url=volkarePortalClosedDecalURL,position={0,0.15,0},rotation={90,180,0},scale={0.88,0.88,1}}) end
	broadcastToAll("{en}The Council of the Void has closed the Portal. From now on it is an ordinary space, and Volkare may be attacked there.{ru}Совет Пустоты закрыл Портал. Теперь это обычная клетка, и Волкара можно атаковать там.{zh-tw}虛空議會已關閉傳送門。從現在起它視為一般空間，沃卡里可在此被攻擊。{zh-cn}虚空议会已关闭传送门。从现在起它视为一般空间，沃卡里可在此被攻击。{ko}공허의 의회가 포털을 닫았습니다. 이제 일반 칸으로 취급하며 그곳에서 볼케어를 공격할 수 있습니다.{es}El Consejo del Vacío ha cerrado el Portal. A partir de ahora es un espacio normal y Volkare puede ser atacado allí.{fr}Le Conseil du Vide a fermé le Portail. Désormais, il s’agit d’une case ordinaire et Volkare peut y être attaqué.{pt-br}O Conselho do Vácuo fechou o Portal. A partir de agora ele é um espaço comum, e Volkare pode ser atacado ali.{de}Der Rat der Leere hat das Portal geschlossen. Von nun an ist es ein normales Feld, und Volkare kann dort angegriffen werden.", {1,0.45,0.15})
	for playerIndex, details in pairs(turnOrder) do
		if details.mage~=gStates.positionMageKnight[5] and playerDropoutInactive(playerIndex)==false and details.avatarLocation=="portal" then
			details.dropoutState="dropped"
			gStates.skipTurn[playerIndex]=nil
			local token=getObjectFromGUID(details.turnOrderTokenGUID)
			if token~=nil and token.is_face_down==true then token.flip() end
			broadcastToAll(joinLang({translateWord[details.mage], "{en} was caught on the Portal when it closed and is out of the game.{ru} оказался на Портале в момент его закрытия и выбывает из игры.{zh-tw} 在傳送門關閉時仍站在其上，因此退出遊戲。{zh-cn} 在传送门关闭时仍站在其上，因此退出游戏。{ko} 포탈이 닫힐 때 그 위에 있어 게임에서 탈락합니다.{es} estaba en el Portal cuando se cerró y queda fuera de la partida.{fr} se trouvait sur le Portail lors de sa fermeture et est éliminé de la partie.{pt-br} estava no Portal quando ele se fechou e está fora do jogo.{de} befand sich beim Schließen auf dem Portal und scheidet aus dem Spiel aus."}), positionToColor(playerIndex))
		end
	end
	applyColorBarButtons()
	addAvatarButtons()
	volkareQuestCheckSkipTurn()
	if activeMageKnightCount()==0 then
		gStates.volkareWon=true
		gStates.blurb="{en}The Portal closed with every Mage Knight trapped upon it.<size=6>\n\n</size>No-one remains to oppose Volkare. You have Lost.{ru}Портал закрылся, когда все Рыцари-Маги находились на нем.<size=6>\n\n</size>Некому противостоять Волкару. Вы проиграли.{zh-tw}傳送門關閉時所有魔法騎士都被困在其上。<size=6>\n\n</size>已無人能阻止沃卡里。你輸了。{zh-cn}传送门关闭时所有魔法骑士都被困在其上。<size=6>\n\n</size>已无人能阻止沃卡里。你输了。{ko}포탈이 닫히며 모든 마법기사가 그 위에 갇혔습니다.<size=6>\n\n</size>볼케어를 막을 자가 없습니다. 패배했습니다.{es}El Portal se cerró con todos los Caballeros Mago atrapados sobre él.<size=6>\n\n</size>Nadie queda para oponerse a Volkare. Has perdido.{fr}Le Portail s'est fermé alors que tous les Chevaliers-Mages s'y trouvaient.<size=6>\n\n</size>Plus personne ne peut s'opposer à Volkare. Vous avez perdu.{pt-br}O Portal se fechou com todos os Cavaleiros Magos presos sobre ele.<size=6>\n\n</size>Ninguém resta para enfrentar Volkare. Você perdeu.{de}Das Portal schloss sich, während alle Mage Knights darauf standen.<size=6>\n\n</size>Niemand kann Volkare noch aufhalten. Ihr habt verloren."
		UI.setAttribute("DummyNotes", "Text", gStates.blurb)
		mainUIUpdate("Volkare portal closure eliminated all players")
	end
	return true
end

--One to Return: the starting Portal closes after the first Day, eliminating anyone still on it.
--After that it is an ordinary single-occupancy plains hex until it reopens at the end of the second Night.
oneToReturnPortalTile=function()
	return volkareQuestPortalTile()
end

oneToReturnSetPortalClosedDecal=function(closed)
	local portalTile=oneToReturnPortalTile()
	if portalTile==nil then return end
	local decals=portalTile.getDecals() or {}
	local kept={}
	local marked=false
	for _, decal in pairs(decals) do
		if decal.name=="Portal Closed" then marked=true else kept[#kept+1]=decal end
	end
	if closed==true then
		if marked==false then portalTile.addDecal({name="Portal Closed",url=volkarePortalClosedDecalURL,position={0,0.15,0},rotation={90,180,0},scale={0.88,0.88,1}}) end
	elseif marked==true then portalTile.setDecals(kept) end
end

function oneToReturnClosePortal()
	if gStates.gameScenario~="One to Return" or gStates.oneToReturnPortalClosed==true then return false end
	gStates.oneToReturnPortalClosed=true
	oneToReturnSetPortalClosedDecal(true)
	broadcastToAll("{en}The Portal has closed. From now on it is an ordinary plains space until the end of the second Night.{ru}Портал закрылся. До конца второй Ночи это обычная клетка Равнины.{zh-tw}傳送門已關閉。從現在起直到第二個夜晚結束，它視為一般平原空間。{zh-cn}传送门已关闭。从现在起直到第二个夜晚结束，它视为一般平原空间。{ko}포털이 닫혔습니다. 두 번째 밤이 끝날 때까지 일반 평원 칸으로 취급합니다.{es}El Portal se ha cerrado. Hasta el final de la segunda Noche es un espacio normal de Llanura.{fr}Le Portail s’est fermé. Jusqu’à la fin de la deuxième Nuit, il s’agit d’une case de Plaine ordinaire.{pt-br}O Portal se fechou. Até o fim da segunda Noite ele é um espaço comum de Planície.{de}Das Portal hat sich geschlossen. Bis zum Ende der zweiten Nacht ist es ein normales Ebenenfeld.", warningColor)
	for playerIndex, details in pairs(turnOrder) do
		if details.mage~=gStates.positionMageKnight[5] and playerDropoutInactive(playerIndex)==false and details.avatarLocation=="portal" then
			details.dropoutState="dropped"
			gStates.skipTurn[playerIndex]=nil
			local token=getObjectFromGUID(details.turnOrderTokenGUID)
			if token~=nil and token.is_face_down==true then token.flip() end
			broadcastToAll(joinLang({translateWord[details.mage], "{en} was still on the Portal when it closed and is out of the game.{ru} оставался на Портале, когда он закрылся, и выбывает из игры.{zh-tw} 在傳送門關閉時仍站在其上，因此退出遊戲。{zh-cn} 在传送门关闭时仍站在其上，因此退出游戏。{ko} 포탈이 닫힐 때 그 위에 있어 게임에서 탈락합니다.{es} seguía en el Portal cuando se cerró y queda fuera de la partida.{fr} se trouvait encore sur le Portail lorsqu'il s'est fermé et est éliminé de la partie.{pt-br} ainda estava no Portal quando ele se fechou e está fora do jogo.{de} befand sich noch auf dem Portal, als es sich schloss, und scheidet aus dem Spiel aus."}), positionToColor(playerIndex))
		end
	end
	applyColorBarButtons()
	addAvatarButtons()
	if activeMageKnightCount()==0 then
		gStates.oneToReturnWinner=nil
		gStates.oneToReturnWinnerLocked=true
		gStates.blurb="{en}The Portal closed with every Mage Knight still upon it.<size=6>\n\n</size>No Hero remains to return. There is no winner.{ru}Портал закрылся, когда все Рыцари-Маги оставались на нем.<size=6>\n\n</size>Никто не сможет вернуться. Победителя нет.{zh-tw}傳送門關閉時所有魔法騎士都還在其上。<size=6>\n\n</size>沒有英雄能夠返回。無人獲勝。{zh-cn}传送门关闭时所有魔法骑士都还在其上。<size=6>\n\n</size>没有英雄能够返回。无人获胜。{ko}포탈이 닫힐 때 모든 마법기사가 그 위에 남아 있었습니다.<size=6>\n\n</size>돌아갈 영웅이 없습니다. 승자는 없습니다.{es}El Portal se cerró con todos los Caballeros Mago todavía sobre él.<size=6>\n\n</size>No queda ningún Héroe que pueda regresar. No hay ganador.{fr}Le Portail s'est fermé alors que tous les Chevaliers-Mages s'y trouvaient encore.<size=6>\n\n</size>Aucun Héros ne peut rentrer. Il n'y a pas de vainqueur.{pt-br}O Portal se fechou com todos os Cavaleiros Magos ainda sobre ele.<size=6>\n\n</size>Nenhum Herói resta para retornar. Não há vencedor.{de}Das Portal schloss sich, während noch alle Mage Knights darauf standen.<size=6>\n\n</size>Kein Held kann zurückkehren. Es gibt keinen Gewinner."
		UI.setAttribute("DummyNotes", "Text", gStates.blurb)
		gStates.endGameAchieved="true"
		gStates.gameOver=true
		mainUIUpdate("One to Return portal closure eliminated all players")
	end
	return true
end

oneToReturnPortalOccupant=function()
	if gStates.gameScenario~="One to Return" then return nil,nil end
	local portalTile=oneToReturnPortalTile()
	if portalTile==nil then return nil,nil end
	local portalPos=portalTile.getPosition()
	for playerIndex, details in pairs(turnOrder) do
		if details.mage~=gStates.positionMageKnight[5] and playerDropoutInactive(playerIndex)==false then
			local avatarObj=nil
			for _, avatar in pairs(mageKnights) do
				if avatar.mage==details.mage then
					avatarObj=getObjectFromGUID(avatar.model) or getObjectFromGUID(avatar.standee) or getObjectFromGUID(avatar.token)
					break
				end
			end
			if avatarObj~=nil then
				local pos=avatarObj.getPosition()
				if ((pos[1]-portalPos[1])^2)+((pos[3]-portalPos[3])^2)<1 then return playerIndex,details end
			end
		end
	end
	return nil,nil
end

function oneToReturnLockFinalWinner()
	if gStates.gameScenario~="One to Return" then return false end
	oneToReturnSetPortalClosedDecal(false)
	local _,winner=oneToReturnPortalOccupant()
	if winner==nil then
		gStates.oneToReturnWinner=nil
		gStates.oneToReturnWinnerLocked=false
		return false
	end
	gStates.oneToReturnWinner=winner.mage
	gStates.oneToReturnWinnerLocked=true
	broadcastToAll(joinLang({translateWord[winner.mage], "{en} occupies the Portal as End of Night is announced and is the One to Return. Player vs. Player combat may not be initiated after End of Night is called.{ru} занимает Портал в момент объявления конца Ночи и становится Единственным, кто вернется. После объявления конца Ночи нельзя начинать бой между игроками.{zh-tw} 在宣告黑夜輪結束時佔據傳送門，成為唯一能返回的英雄。宣告黑夜輪結束後不能再發起玩家對玩家戰鬥。{zh-cn} 在宣布黑夜轮结束时占据传送门，成为唯一能返回的英雄。宣布黑夜轮结束后不能再发起玩家对玩家战斗。{ko} 밤 종료가 선언될 때 포탈을 차지하고 있어 돌아갈 단 한 명의 영웅이 됩니다. 밤 종료 선언 후에는 PvP 전투를 시작할 수 없습니다.{es} ocupa el Portal cuando se anuncia el Fin de la Noche y es el Único que Regresa. No se puede iniciar combate entre jugadores después de anunciar el Fin de la Noche.{fr} occupe le Portail lorsque la Fin de la Nuit est annoncée et devient l'Unique à Revenir. Aucun combat entre joueurs ne peut être initié après l'annonce de la Fin de la Nuit.{pt-br} ocupa o Portal quando o Fim da Noite é anunciado e é o Único a Retornar. Combate entre jogadores não pode ser iniciado depois que o Fim da Noite é anunciado.{de} besetzt das Portal, als das Ende der Nacht ausgerufen wird, und ist der Eine, der zurückkehrt. Nach dem Ausrufen des Nachtendes darf kein PvP-Kampf mehr begonnen werden."}), {1,1,0.5})
	return true
end

function oneToReturnResolveWinner()
	if gStates.gameScenario~="One to Return" then return false end
	oneToReturnSetPortalClosedDecal(false)
	local winnerMage=gStates.oneToReturnWinnerLocked==true and gStates.oneToReturnWinner or nil
	if winnerMage==nil then
		local _,winner=oneToReturnPortalOccupant()
		if winner~=nil then winnerMage=winner.mage end
	end
	gStates.oneToReturnWinner=winnerMage
	if winnerMage~=nil then
		gStates.blurb=joinLang({translateWord[winnerMage], "{en} is the One to Return.<size=6>\n\n</size>They occupy the Portal as the second Night ends and win the game.{ru} — Единственный, кто вернется.<size=6>\n\n</size>Он занимает Портал в конце второй Ночи и выигрывает игру.{zh-tw} 是唯一能返回的英雄。<size=6>\n\n</size>第二個黑夜輪結束時佔據傳送門並贏得遊戲。{zh-cn} 是唯一能返回的英雄。<size=6>\n\n</size>第二个黑夜轮结束时占据传送门并赢得游戏。{ko} 돌아갈 단 한 명의 영웅입니다.<size=6>\n\n</size>두 번째 밤이 끝날 때 포탈을 차지해 승리합니다.{es} es el Único que Regresa.<size=6>\n\n</size>Ocupa el Portal cuando termina la segunda Noche y gana la partida.{fr} est l'Unique à Revenir.<size=6>\n\n</size>Ce Héros occupe le Portail à la fin de la deuxième Nuit et remporte la partie.{pt-br} é o Único a Retornar.<size=6>\n\n</size>Ocupa o Portal quando a segunda Noite termina e vence o jogo.{de} ist der Eine, der zurückkehrt.<size=6>\n\n</size>Dieser Held besetzt das Portal am Ende der zweiten Nacht und gewinnt das Spiel."})
	else
		gStates.blurb="{en}The second Night has ended and no Hero occupies the Portal.<size=6>\n\n</size>There is no winner.{ru}Вторая Ночь закончилась, но Портал никто не занимает.<size=6>\n\n</size>Победителя нет.{zh-tw}第二個黑夜輪已結束，但沒有英雄佔據傳送門。<size=6>\n\n</size>無人獲勝。{zh-cn}第二个黑夜轮已结束，但没有英雄占据传送门。<size=6>\n\n</size>无人获胜。{ko}두 번째 밤이 끝났지만 포탈을 차지한 영웅이 없습니다.<size=6>\n\n</size>승자는 없습니다.{es}La segunda Noche ha terminado y ningún Héroe ocupa el Portal.<size=6>\n\n</size>No hay ganador.{fr}La deuxième Nuit est terminée et aucun Héros n'occupe le Portail.<size=6>\n\n</size>Il n'y a pas de vainqueur.{pt-br}A segunda Noite terminou e nenhum Herói ocupa o Portal.<size=6>\n\n</size>Não há vencedor.{de}Die zweite Nacht ist beendet und kein Held besetzt das Portal.<size=6>\n\n</size>Es gibt keinen Gewinner."
	end
	UI.setAttribute("DummyNotes", "Text", gStates.blurb)
	broadcastToAll(gStates.blurb, {1,1,0.5})
	return winnerMage~=nil
end

function realmDeadEnemiesAtPosition(position)
	if position==nil or position[1]==nil then return false end
	local map=getObjectFromGUID(mapArea)
	if map==nil then return false end
	for _, obj in pairs(map.getObjects()) do
		local data=monsterPugs[obj.guid]
		if data~=nil and data.pugType~="possessed" then
			local pos=obj.getPosition()
			if ((pos[1]-position[1])^2)+((pos[3]-position[3])^2)<1 then return true end
		end
	end
	return false
end

currentMageAvatarPosition=function(playerIndex)
	local player=turnOrder[playerIndex]
	if player==nil then return nil end
	for _, avatar in pairs(mageKnights) do
		if avatar.mage==player.mage then
			if getObjectFromGUID(avatar.model)~=nil then return getObjectFromGUID(avatar.model).getPosition() end
			if getObjectFromGUID(avatar.token)~=nil then return getObjectFromGUID(avatar.token).getPosition() end
			if getObjectFromGUID(avatar.standee)~=nil then return getObjectFromGUID(avatar.standee).getPosition() end
		end
	end
	return nil
end

function hiddenValleyLiberated()
	if gStates.gameScenario~="The Hidden Valley Blitz" then return true end
	if (gStates.elementalistLevel or 1)<=0 then return true end
	local monsters=gStates.cityMonsterQty~=nil and gStates.cityMonsterQty[elementalist.terrainHex] or nil
	if monsters~=nil and monsters[elementalist.token]=="dead" then return true end
	if gStates.defeatedFactionTest~=nil and gStates.defeatedFactionTest[elementalist.terrainHex]=="Beat" then return true end
	return false
end

function scenarioRestLocationIsAvailable()
	local player=turnOrder[gStates.turnNumber]
	if player==nil then return true end
	local location=player.avatarLocation
	if gStates.gameScenario=="The Realm of the Dead Blitz" then
		if location=="graveyard" then return realmDeadEnemiesAtPosition(currentMageAvatarPosition(gStates.turnNumber))~=true end
		if location=="necropolis" then return (gStates.defeatedFaction or 0)>0 end
		return true
	end
	if gStates.gameScenario=="The Hidden Valley Blitz" then
		if location=="hidden valley" then return hiddenValleyLiberated() end
		return true
	end
	local gladeOpen=true
	if gStates.gameScenario=="Life and Death" and (location=="glade" or location=="graveyard") then
		gladeOpen=false
		local avatarLocation=currentMageAvatarPosition(gStates.turnNumber)
		if avatarLocation==nil then return false end
		local objectsInPlay=getObjectFromGUID(mapArea).getObjects()
		table.sort(objectsInPlay, function (k1, k2) return k1.getPosition()[2]>k2.getPosition()[2] end)
		for _, obj in pairs(objectsInPlay) do
			if obj.getName()=="Shield" and volkarePursuitShieldRegistered(obj)~=true then
				if math.sqrt(((obj.getPosition()[1]-avatarLocation[1])^2)+((obj.getPosition()[3]-avatarLocation[3])^2))<1 then
					gladeOpen=true
					break
				end
			end
		end
	end
	return gladeOpen
end



againstHorsemenSharedHexKey="horsemenCentralGlade"

function againstHorsemenCentralGladeHex(terrain, bearing)
	return gStates~=nil and gStates.gameScenario=="Against the Horsemen Blitz" and terrain~=nil
		and terrain.guid==GUID.tile.country01 and tostring(bearing)=="center"
end

function againstHorsemenCentralGladePosition(y)
	if gStates==nil or gStates.gameScenario~="Against the Horsemen Blitz" then return nil end
	local terrain=getObjectFromGUID(GUID.tile.country01)
	if terrain==nil then return nil end
	local p=terrain.getPosition()
	p[2]=y or 1.5
	return p
end

function againstHorsemenPlayerAtCentralGlade(player)
	return gStates~=nil and gStates.gameScenario=="Against the Horsemen Blitz" and player~=nil
		and player.avatarLocation=="glade" and player.avatarSharedHex==againstHorsemenSharedHexKey
end

function againstHorsemenSetStartingAvatarLocations()
	if gStates==nil or gStates.gameScenario~="Against the Horsemen Blitz" then return end
	for playerIndex,player in pairs(turnOrder or {}) do
		--The standard Dummy has no map figure. Human Mage Knights and the optional Proxy do, including
		--the five-avatar case where the Proxy's physical storage starts on the Dummy board.
		local proxyAvatar=proxyPlayerIsActive()==true and player.mage==gStates.positionMageKnight[5]
		if (player.avatarLocation~=nil or proxyAvatar==true) and player.mage~=nil and player.mage~="nobody" and player.mage~="Volkare" then
			player.avatarLocation="glade"
			player.avatarSharedHex=againstHorsemenSharedHexKey
			player.avatarSwapCity=nil
			player.horsemenGladeParked=true
			--Physically park every shared-Glade avatar on the Portal card during tactic selection.
			--startOfTurn() will put the active Mage Knight on Country 01's centre and keep the others parked.
			portalSwap("endOfTurn",playerIndex)
		end
	end
end

function volkareQuestSkipThreshold()
	return activeMageKnightCount()*2
end

function volkareQuestCheckSkipTurn()
	if gStates.gameScenario~="Volkare's Quest" then return false end
	local threshold=volkareQuestSkipThreshold()
	local reminder=getObjectFromGUID("09a991")
	if threshold<=0 or gStates.volkareArmyDefeated<threshold or reminder==nil or reminder.is_face_down==true then return false end
	gStates.volkareQuestSkipThreshold=threshold
	reminder.flip()
	broadcastToAll(joinLang({"{en}At Least {ru}Как минимум {zh-tw}至少{zh-cn}至少{ko}최소 {es}Al menos {fr}Au moins {pt-br}Pelo menos {de}Zumindest ", tostring(threshold), "{en} of Volkare's Army defeated, he skips his next turn.{ru} отряда из армии Волкара побеждено, он пропускает следующий ход{zh-tw}个敌人被击败了, 沃里卡跳过了他的回合. {zh-cn}个敌人被击败了, 沃里卡跳过了他的回合. {ko}개의 볼케어 군대 적 토큰을 제거했기에, 볼케어의 차례를 건너뜁니다{es} de los ejércitos de Volkare derrotados, se salta su siguiente turno.{fr} de l'armée de Volkare vaincus, il saute son prochain tour.{pt-br} do exército de Volkare derrotado, ele pulará seu próximo turno.{de} von Volkare's Armee besiegt, überspringt er seinen nächsten Zug."}), {1,1,0.5})
	return true
end

function volkareQuestFullAttendAllowed(mageName)
	if gStates.gameScenario~="Volkare's Quest" then return true end
	for _, details in pairs(turnOrder) do
		if details.mage==mageName then
			local token=getObjectFromGUID(details.turnOrderTokenGUID)
			if token~=nil and token.is_face_down==true then return false end
			local handZone=getObjectFromGUID(handZones[details.seatPos])
			if handZone~=nil then
				for _, card in pairs(handZone.getObjects()) do
					if card.type=="Card" and card.getGMNotes()~="Wound" then return true end
				end
			end
			return false
		end
	end
	return false
end

function volkareQuestRefreshFullAttend(mageName)
	if gStates.gameScenario~="Volkare's Quest" then return end
	local allowed=volkareQuestFullAttendAllowed(mageName)
	UI.setAttribute("VolkareAttackedFull", "interactable", allowed and "true" or "false")
	UI.setAttribute("VolkareAttackedFullImage", "image", allowed and "Sliced Button/Button New Active" or "Sliced Button/Button New Deactive")
end

function volkareQuestCombatWithdrawalReminder(mageName)
	if gStates.gameScenario~="Volkare's Quest" or gStates.volkareMovementStepPending==true or mageName==nil then return false end
	local attacked=gStates.volkareAttacked~=nil and gStates.volkareAttacked[1] or nil
	if attacked==nil or attacked.mage~=mageName then return false end
	local volkareObj=gStates.volkareModel~=nil and getObjectFromGUID(gStates.volkareModel) or nil
	if volkareObj==nil then return false end
	local mageObj=nil
	for _, avatar in pairs(mageKnights) do
		if avatar.mage==mageName then
			mageObj=getObjectFromGUID(avatar.model) or getObjectFromGUID(avatar.standee) or getObjectFromGUID(avatar.token)
			break
		end
	end
	if mageObj==nil then return false end
	local vPos,mPos=volkareObj.getPosition(),mageObj.getPosition()
	if math.sqrt(((vPos[1]-mPos[1])^2)+((vPos[3]-mPos[3])^2))>=1.5 then return false end
	broadcastToAll(joinLang({translateWord[mageName], "{en} needs to withdraw to a neighboring Safe space after fighting Volkare.{ru} должен отступить на соседнюю безопасную клетку после боя с Волкаром.{zh-tw} 與沃卡里戰鬥後必須撤退到相鄰的安全格。{zh-cn} 与沃卡里战斗后必须撤退到相邻的安全格。{ko} 볼케어와 전투한 뒤 인접한 안전한 칸으로 후퇴해야 합니다.{es} debe retirarse a un espacio seguro vecino después de luchar contra Volkare.{fr} doit se retirer vers un espace sûr adjacent après avoir combattu Volkare.{pt-br} precisa recuar para um espaço Seguro adjacente depois de lutar com Volkare.{de} muss sich nach dem Kampf gegen Volkare auf ein benachbartes sicheres Feld zurückziehen."}), warningColor)
	return true
end

function registerVolkareCampAsCityKeep()
	if gStates.volkareCampAsCity~=true or gStates.volkareCityDefeat==true or gStates.defeatedCities[volkare.terrainHex]~=true then return end
	gStates.volkareCityDefeat=true
	for _, player in pairs(turnOrder) do
		if player.defeatedCities[volkare.terrainHex]=="Lead" then player.keepsBeat=player.keepsBeat+1 break end
	end
end

function coopLeaderScenarioEndAchieved()
	if gStates.endGameAchieved~="false" then return false end
	refreshCityDefeatState()
	if gStates.gameScenario=="Life and Death" then return gStates.defeatedFaction==2 end
	if gStates.gameScenario=="The Hidden Valley Blitz" then return gStates.defeatedFaction==1 end
	if gStates.gameScenario=="Ultimate Conquest" then
		return gStates.defeatedCities.amount==gStates.cityTiles and (gStates.removeShadesOfTezlaMonsters==true or gStates.defeatedFaction==2)
	end
	if gStates.gameScenario=="The Realm of the Dead Blitz" then
		local graveYardCount=0
		local graveYardTileCount=0
		local objectsInPlay=getObjectFromGUID(mapArea).getObjects()
		for _, obj in pairs(objectsInPlay) do
			if obj.getName()=="GraveYard" then graveYardTileCount=graveYardTileCount+1 end
			if obj.getName()=="Shield" and volkarePursuitShieldRegistered(obj)~=true then
				local shieldPos=obj.getPosition()
				for _, graveYard in pairs(objectsInPlay) do
					if graveYard.getName()=="GraveYard" then
						local gravePos=graveYard.getPosition()
						if math.sqrt(((shieldPos[1]-gravePos[1])^2)+((shieldPos[3]-gravePos[3])^2))<1 then graveYardCount=graveYardCount+1 break end
					end
				end
			end
		end
		return gStates.defeatedFaction==1 and graveYardCount==graveYardTileCount
	end
	return false
end

local combatCleanupMineTiles={
	[GUID.tile.core02]=true,[GUID.tile.core04]=true,[GUID.tile.core03]=true,[GUID.tile.country03]=true,
	[GUID.tile.country06]=true,[GUID.tile.country02]=true,[GUID.tile.country05]=true,[GUID.tile.city08]=true,
	[GUID.tile.country13]=true,[GUID.tile.country14]=true,[GUID.tile.country15]=true,[GUID.tile.country17]=true,[GUID.tile.core10]=true
}
local combatCleanupDungeonTombTiles={
	[GUID.tile.core01]=true,[GUID.tile.core03]=true,[GUID.tile.country07]=true,[GUID.tile.country09]=true
}

--Combat calls this only after returned enemies and shields have settled. Scenario owns victory
--conditions and Volkare's Return defense resolution; Combat only owns when this boundary is reached.
function scenarioCombatCleanupCheck(cleanupPlayer)
	if gStates.endGameAchieved~="false" or gStates.tacticShown~=false then return end
	local cleanupLocation=turnOrder[cleanupPlayer]~=nil and turnOrder[cleanupPlayer].avatarLocation or ""
	local dungeonCount,dungeonHexCount=0,0
	local mineCount,mineTileCount=0,0
	local graveYardCount,graveYardTileCount=0,0
	local relicCount=0

	if gStates.gameScenario=="Mines Liberation" or gStates.gameScenario=="The Realm of the Dead Blitz" or
		gStates.gameScenario=="Dungeon Lords" or gStates.gameScenario=="The Lost Relic Blitz" or
		gStates.gameScenario=="Against the Apocalypse Blitz" then
		local map=getObjectFromGUID(mapArea)
		local objectsInPlay=map~=nil and map.getObjects() or {}
		table.sort(objectsInPlay,function(k1,k2) return k1.getPosition()[2]>k2.getPosition()[2] end)
		for _, playAreaObject in pairs(objectsInPlay) do
			if playAreaObject.getName()=="Shield" and volkarePursuitShieldRegistered(playAreaObject)~=true then
				local found=false
				local shieldPos=playAreaObject.getPosition()
				local locatedTerrain,_,_,locatedFeature=terrainHexAtPosition(shieldPos,objectsInPlay)
				for _, terTile in pairs(objectsInPlay) do
					local tilePos=terTile.getPosition()
					local shieldToTileDist=math.sqrt(((shieldPos[1]-tilePos[1])^2)+((shieldPos[3]-tilePos[3])^2))
					if terTile==locatedTerrain then
						found=true
						if locatedFeature=="dungeon" or locatedFeature=="tomb" then dungeonCount=dungeonCount+1 end
						if locatedFeature=="mine" then mineCount=mineCount+1 end
						if locatedFeature~=nil and (locatedFeature:sub(1,4)=="city" or locatedFeature=="Volkare's Camp") and gStates.gameScenario=="The Lost Relic Blitz" then relicCount=relicCount+1 end
					end
					if shieldToTileDist<1 and terTile.getName()=="GraveYard" then graveYardCount=graveYardCount+1 found=true end
					if found==true then break end
				end
			end
			if terrainTiles[playAreaObject.guid]~=nil and combatCleanupMineTiles[playAreaObject.guid]==true then mineTileCount=mineTileCount+1 end
			if playAreaObject.getName()=="GraveYard" then graveYardTileCount=graveYardTileCount+1 end
			if terrainTiles[playAreaObject.guid]~=nil and combatCleanupDungeonTombTiles[playAreaObject.guid]==true then dungeonHexCount=dungeonHexCount+1 end
			if playAreaObject.getName()=="Secret Tomb" or playAreaObject.getName()=="Secret Dungeon" then dungeonHexCount=dungeonHexCount+1 end
		end
	end

	local allRituals=true
	if gStates.gameScenario=="Druid Nights" then
		for _, playerDetails in pairs(turnOrder) do
			if playerDetails.mage~=gStates.positionMageKnight[5] and playerDetails.druidNightsFinalRitual~=true then allRituals=false break end
		end
	end

	local cardInHand=false
	if gStates.gameScenario=="Quest for the Golden Grail" and turnOrder[cleanupPlayer]~=nil then
		local handZone=getObjectFromGUID(handZones[turnOrder[cleanupPlayer].seatPos])
		for _, handobject in pairs(handZone~=nil and handZone.getObjects() or {}) do
			if handobject.guid=="085e59" then cardInHand=true break end
		end
	end

	local volkareBeaten=true
	local volkareObj=gStates.volkareModel~=nil and getObjectFromGUID(gStates.volkareModel) or nil
	if volkareObj~=nil then
		for _, state in pairs(gStates.cityMonsterQty[volkare.model]) do if state=="alive" then volkareBeaten=false break end end
		if volkareBeaten==true then
			local trash=getObjectFromGUID(trashCan)
			if trash~=nil then trash.putObject(volkareObj) end
		end
	end

	local terrainStack=getObjectFromGUID(GUID.bag.terrain.stack)
	local terrainEmpty=terrainStack~=nil and terrainStack.getQuantity()==0
	local complete=
		((gStates.gameScenario=="Conquest" or gStates.gameScenario=="Conquest Blitz" or gStates.gameScenario=="First Conquest" or gStates.gameScenario=="Fast Forwarded Conquest") and gStates.defeatedCities.amount==gStates.cityTiles) or
		((gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz" or gStates.gameScenario=="Volkare's Quest" or gStates.gameScenario=="The War of Four") and volkareBeaten==true) or
		(gStates.gameScenario=="First Reconnaissance" and #gStates.citiesPlayed>=1) or
		(gStates.gameScenario=="Ultimate Conquest" and gStates.defeatedCities.amount==gStates.cityTiles and (gStates.removeShadesOfTezlaMonsters==true or gStates.defeatedFaction==2)) or
		(gStates.gameScenario=="The Hidden Valley Blitz" and gStates.defeatedFaction==1) or
		(gStates.gameScenario=="Mines Liberation" and terrainEmpty and mineCount==mineTileCount) or
		(gStates.gameScenario=="Dungeon Lords" and terrainEmpty and dungeonCount==dungeonHexCount-2) or
		(gStates.gameScenario=="The Realm of the Dead Blitz" and gStates.defeatedFaction==1 and graveYardCount==graveYardTileCount) or
		(gStates.gameScenario=="The Lost Relic Blitz" and relicCount==gStates.cityTiles) or
		(gStates.gameScenario=="Quest for the Golden Grail" and cleanupLocation=="portal" and cardInHand==true) or
		(gStates.gameScenario=="The Gauntlet" and gStates.theGauntletArtifactClaimed==true) or
		(gStates.gameScenario=="Druid Nights" and gStates.currentRound==gStates.rounds and allRituals==true) or
		(gStates.gameScenario=="Life and Death" and gStates.defeatedFaction==2) or
		(gStates.gameScenario=="Against the Horsemen Blitz" and againstHorsemenAllDefeated()==true) or
		(gStates.gameScenario=="Against the Dragon Blitz" and apocalypseDragonColoredHeadsDefeated()==true) or
		(gStates.gameScenario=="Against the Apocalypse Blitz" and againstApocalypseObjectivesComplete~=nil and againstApocalypseObjectivesComplete()==true)
	if complete==true then
		if gStates.coopAssaultPhase=="combat" then gStates.coopAssaultScenarioEndPending=true else markScenarioEndAchieved() end
	end

	--Judge Volkare's Return city defense only when the entire defense is complete; co-op kills are combined across all defenders.
	local volkareReturnDefense=gStates.positionMageKnight[5]=="Volkare" and gStates.volkareState=="Attacking City" and
		(gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz")
	local volkareReturnDefenseFinished=volkareReturnDefense and (gStates.coopAssaultPhase~="combat" or coopAssaultPendingCombat()==false)
	if volkareReturnDefenseFinished then
		if gStates.volkareArmyDefeated<gStates.playerCount then
			gStates.volkareCityDefenseMove=nil
			local trash=getObjectFromGUID(trashCan)
			local liveVolkare=gStates.volkareModel~=nil and getObjectFromGUID(gStates.volkareModel) or nil
			if trash~=nil and liveVolkare~=nil then trash.putObject(liveVolkare) end
			gStates.volkareWon=true
			mainUIUpdate("Volkare Won")
		else volkareReturnCityDefenseMove() end
	end
end

--Mine crystal claim: resolve before cleanup/rewards so Deep Mine choice follows the End of Turn sequence.
mineCrystalBagKey={Red="red", Blue="blue", Green="green", White="white"}

function mineCrystalCount(playerIndex, color)
	local details=turnOrder[playerIndex]
	if details==nil then return 0 end
	local zone=getObjectFromGUID(playerCrystalAreas[details.seatPos])
	if zone==nil then return 0 end
	local count=0
	for _, obj in pairs(zone.getObjects()) do
		if obj.getDescription()==color or obj.getName()==color.." Mana" then count=count+1 end
	end
	return count
end

mineLiberatedForClaim=function(playerIndex, terrainGUID, hexPos)
	if gStates.gameScenario~="Mines Liberation" then return true end
	local map=getObjectFromGUID(mapArea)
	if map~=nil then
		for _, obj in pairs(map.getObjects()) do
			if obj.getName()=="Shield" and volkarePursuitShieldRegistered(obj)~=true then
				local p=obj.getPosition()
				if ((p[1]-hexPos[1])^2)+((p[3]-hexPos[3])^2)<1 then return true end
			end
		end
	end
	--A mine conquered this turn does not receive its Shield until cleanup. Treat its face-up
	--mine enemies in this player's play area as defeated-pending so the crystal can be chosen first.
	local monsters=gStates.mineMonsterQty~=nil and gStates.mineMonsterQty[terrainGUID] or nil
	if monsters==nil then return false end
	local playArea=getObjectFromGUID(playerPlayAreas[turnOrder[playerIndex].seatPos])
	local pendingDefeat={}
	if playArea~=nil then
		for _, obj in pairs(playArea.getObjects()) do if obj.is_face_down==false then pendingDefeat[obj.guid]=true end end
	end
	local found=false
	for monsterGUID, state in pairs(monsters) do
		found=true
		if state~="dead" and pendingDefeat[monsterGUID]~=true then return false end
	end
	return found
end

mineClaimData=function(playerIndex)
	local avatar=coopAssaultAvatarObject(playerIndex)
	if avatar==nil then return nil end
	local terrain, bearing, hexPos, feature=terrainHexAtPosition(avatar.getPosition())
	if terrain==nil or bearing==nil or feature~="mine" then return nil end
	local details=terrainTiles[terrain.guid]
	local colors=details~=nil and details.mineColors~=nil and details.mineColors[bearing] or nil
	if colors==nil or #colors==0 or mineLiberatedForClaim(playerIndex, terrain.guid, hexPos)==false then return nil end
	return {terrainGUID=terrain.guid, bearing=bearing, colors=colors}
end

function mineInventoryPosition(playerIndex, color)
	local seatPos=turnOrder[playerIndex].seatPos
	local board=getObjectFromGUID(playerBoard[seatPos])
	local zone=getObjectFromGUID(playerCrystalAreas[seatPos])
	if board==nil or zone==nil then return {(seatPos*40)-114, 2.0, -36.8} end
	local zonePos, zoneScale=zone.getPosition(), zone.getScale()
	local objects=zone.getObjects()
	local matching={}
	for _, obj in pairs(objects) do
		if obj.getDescription()==color or obj.getName()==color.." Mana" then matching[#matching+1]=obj.getPosition() end
	end
	local choices={}
	for _, snap in pairs(board.getSnapPoints() or {}) do
		local p=board.positionToWorld(snap.position)
		if math.abs(p[1]-zonePos[1])<=zoneScale[1]/2 and math.abs(p[3]-zonePos[3])<=zoneScale[3]/2 then
			local occupied=false
			for _, obj in pairs(objects) do
				local op=obj.getPosition()
				if ((op[1]-p[1])^2)+((op[3]-p[3])^2)<0.56 then occupied=true break end
			end
			if occupied==false then
				local nearest=999999
				for _, mp in pairs(matching) do nearest=math.min(nearest, ((mp[1]-p[1])^2)+((mp[3]-p[3])^2)) end
				choices[#choices+1]={position={p[1], 2.0, p[3]}, score=nearest}
			end
		end
	end
	if #choices>0 then
		table.sort(choices, function(a,b) if a.score==b.score then return a.position[1]<b.position[1] end return a.score<b.score end)
		return choices[1].position
	end
	--No board snap is free (usually because reward tokens were placed over them). Find the clearest
	--physical point in the inventory instead of stacking the new crystal on an existing object.
	local best={position={zonePos[1],2.0,zonePos[3]}, clearance=-1}
	for i=1, 24 do
		local p={zonePos[1]-((zoneScale[1]/2)-0.6)+(math.random()*math.max(0.1,zoneScale[1]-1.2)), 2.0,
			zonePos[3]-((zoneScale[3]/2)-0.6)+(math.random()*math.max(0.1,zoneScale[3]-1.2))}
		local clearance=999999
		for _, obj in pairs(objects) do local op=obj.getPosition() clearance=math.min(clearance, ((op[1]-p[1])^2)+((op[3]-p[3])^2)) end
		if clearance>best.clearance then best={position=p, clearance=clearance} end
	end
	return best.position
end

function refreshMineClaimPanel()
	local pending=gStates.mineClaimPending
	if pending==nil or turnOrder[pending.playerIndex]==nil then UI.hide("MineClaimChoice") return end
	UI.setAttribute("MineClaimChoiceTitle", "text", pending.source=="Quest" and "{en}Quest Crystal{ru}Кристалл задания{zh-tw}任務水晶{zh-cn}任务水晶{ko}퀘스트 크리스털{es}Cristal de Misión{fr}Cristal de Quête{pt-br}Cristal de Missão{de}Quest-Kristall" or "{en}Mined Crystal{ru}Добытый кристалл{zh-tw}開採水晶{zh-cn}开采水晶{ko}채굴한 크리스털{es}Cristal Extraído{fr}Cristal Extrait{pt-br}Cristal Minerado{de}Abgebauter Kristall")
	for i=1, 4 do
		local color=pending.colors[i]
		UI.setAttribute("MineClaimButton"..i, "active", color~=nil and "true" or "false")
		if color~=nil then UI.setAttribute("MineClaimButtonText"..i, "text", translateWord[color] or color) end
	end
	UI.setAttribute("MineClaimRow2", "active", #pending.colors>2 and "true" or "false")
	UI.setAttribute("MineClaimChoice", "visibility", positionToColor(pending.playerIndex).."|Black")
	UI.show("MineClaimChoice")
end

function beginMineCrystalClaim(playerIndex, messageColor)
	local data=mineClaimData(playerIndex)
	if data==nil then return false end
	local available={}
	for _, color in ipairs(data.colors) do if mineCrystalCount(playerIndex, color)<3 then available[#available+1]=color end end
	if #available==0 then
		if messageColor~=nil then broadcastToColor("{en}No crystal gained from the Mine: your Inventory already has 3 of every available color.{ru}Кристалл из Шахты не получен: в вашем Инвентаре уже по 3 кристалла каждого доступного цвета.{zh-tw}未從礦場獲得水晶：你的庫存中每種可用顏色都已有 3 顆水晶。{zh-cn}未从矿场获得水晶：你的库存中每种可用颜色都已有 3 颗水晶。{ko}광산에서 크리스털을 얻지 못했습니다. 인벤토리에 사용 가능한 모든 색의 크리스털이 이미 3개씩 있습니다.{es}No se obtuvo cristal de la Mina: tu Inventario ya tiene 3 de cada color disponible.{fr}Aucun cristal gagné de la Mine : votre Inventaire contient déjà 3 cristaux de chaque couleur disponible.{pt-br}Nenhum cristal foi ganho da Mina: seu Inventário já tem 3 de cada cor disponível.{de}Kein Kristall aus der Mine erhalten: Dein Inventar enthält bereits 3 Kristalle jeder verfügbaren Farbe.", messageColor, warningColor)
		else broadcastToAll("{en}No crystal gained from the Mine: your Inventory already has 3 of every available color.{ru}Кристалл из Шахты не получен: в вашем Инвентаре уже по 3 кристалла каждого доступного цвета.{zh-tw}未從礦場獲得水晶：你的庫存中每種可用顏色都已有 3 顆水晶。{zh-cn}未从矿场获得水晶：你的库存中每种可用颜色都已有 3 颗水晶。{ko}광산에서 크리스털을 얻지 못했습니다. 인벤토리에 사용 가능한 모든 색의 크리스털이 이미 3개씩 있습니다.{es}No se obtuvo cristal de la Mina: tu Inventario ya tiene 3 de cada color disponible.{fr}Aucun cristal gagné de la Mine : votre Inventaire contient déjà 3 cristaux de chaque couleur disponible.{pt-br}Nenhum cristal foi ganho da Mina: seu Inventário já tem 3 de cada cor disponível.{de}Kein Kristall aus der Mine erhalten: Dein Inventar enthält bereits 3 Kristalle jeder verfügbaren Farbe.", warningColor) end
		return false
	end
	gStates.mineClaimPending={source="Mine", playerIndex=playerIndex, terrainGUID=data.terrainGUID, bearing=data.bearing, colors=available}
	refreshMineClaimPanel()
	if mainUIUpdate~=nil then mainUIUpdate("Mine crystal pending") end
	return true
end

function mineClaimChoice(player, mouseButton, id)
	if mouseButton~="-1" or player==nil then return end
	local pending=gStates.mineClaimPending
	if pending==nil or turnOrder[pending.playerIndex]==nil then UI.hide("MineClaimChoice") return end
	local claimantColor=positionToColor(pending.playerIndex)
	local sourceName=pending.source=="Quest" and "Quest" or "Mine"
	if player.color~=claimantColor and player.color~="Black" then
		broadcastToColor(joinLang({"{en}Only the claiming player can choose this {ru}Только получающий игрок может выбрать этот кристалл из {zh-tw}只有領取的玩家可以選擇這顆來自 {zh-cn}只有领取的玩家可以选择这颗来自 {ko}이 크리스털은 획득하는 플레이어만 선택할 수 있습니다: {es}Solo el jugador que reclama puede elegir este cristal de {fr}Seul le joueur qui réclame peut choisir ce cristal de {pt-br}Apenas o jogador que está recebendo pode escolher este cristal de {de}Nur der beanspruchende Spieler kann diesen Kristall aus ",sourceName,"."}), player.color, {1,0.3,0.3})
		return
	end
	local index=tonumber(id:match("(%d+)$"))
	local color=index~=nil and pending.colors[index] or nil
	if color==nil then return end
	if mineCrystalCount(pending.playerIndex, color)>=3 then
		broadcastToColor(joinLang({"{en}You already have 3 {ru}В вашем Инвентаре уже есть 3 {zh-tw}你的庫存中已有 3 顆 {zh-cn}你的库存中已有 3 颗 {ko}인벤토리에 이미 {es}Ya tienes 3 cristales {fr}Vous avez déjà 3 cristaux {pt-br}Você já tem 3 cristais {de}Du hast bereits 3 ",translateWord[color] or color,"{en} crystals in your Inventory.{ru} кристалла.{zh-tw} 水晶。{zh-cn} 水晶。{ko} 크리스털이 3개 있습니다.{es} en tu Inventario.{fr} dans votre Inventaire.{pt-br} no seu Inventário.{de}-Kristalle in deinem Inventar."}), player.color, warningColor)
		return
	end
	local bagKey=mineCrystalBagKey[color]
	local bag=bagKey~=nil and getObjectFromGUID(GUID.bag.mana[bagKey]) or nil
	if bag==nil or bag.getQuantity()==0 then
		broadcastToColor(joinLang({"{en}No {ru}В запасе нет {zh-tw}供應區沒有可用的 {zh-cn}供应区没有可用的 {ko}공급처에 사용할 수 있는 {es}No hay ningún cristal {fr}Aucun cristal {pt-br}Não há cristal {de}Im Vorrat ist kein ",translateWord[color] or color,"{en} crystal is available in the supply.{ru} кристалла.{zh-tw} 水晶。{zh-cn} 水晶。{ko} 크리스털이 없습니다.{es} disponible en la reserva.{fr} disponible dans la réserve.{pt-br} disponível na reserva.{de}-Kristall verfügbar."}), player.color, {1,0.3,0.3})
		return
	end
	local questCardGUID=pending.questCardGUID
	takeManaCrystal(bag,{position=mineInventoryPosition(pending.playerIndex, color),smooth=false})
	broadcastToColor(joinLang({"{en}Claimed a {ru}Получен {zh-tw}已領取 {zh-cn}已领取 {ko}획득: {es}Se reclamó un Cristal {fr}Cristal {pt-br}Recebeu um Cristal {de}Beansprucht: ",translateWord[color] or color,"{en} Crystal from the {ru} кристалл из {zh-tw} 水晶，來源：{zh-cn} 水晶，来源：{ko} 크리스털, 출처: {es} de {fr} réclamé depuis {pt-br} de {de}-Kristall aus ",sourceName,"."}), player.color, {1,1,0.5})
	gStates.mineClaimPending=nil
	UI.hide("MineClaimChoice")
	if questCardGUID~=nil and getObjectFromGUID(questCardGUID)~=nil then apocalypseQuestUpdateProgressButtons(getObjectFromGUID(questCardGUID)) end
	if mainUIUpdate~=nil then mainUIUpdate("Mine crystal claimed") end
end

function markScenarioEndAchieved(endImmediately)
	if gStates.endGameAchieved~="false" then return false end
	UI.setAttribute("EndGameButtonText", "text", "{en}Scenario End Achieved - Yes{ru}Конец сценария достигнут - Да{zh-tw}達成劇本結束 - 是{zh-cn}達成剧本结束 - 是{ko}시나리오 종료 조건 충족 됨{es}Escenario Fin Realizados - Sí{fr}Scénario Fin Atteint - Oui{pt-br}Fim do Cenário Alcançado - Sim{de}Szenarioziel Erreicht – Ja")
	UI.setAttribute("EndGameButtonImage", "image", "Sliced Button/Button New Deactive")
	UI.setAttribute("EndGameButtonImage", "color", "rgb(1.0,0.7,0.2)")
	gStates.endGameAchieved="started"
	turnOrder[gStates.realTurn].gameEnder=true
	establishFinalTurnBoundary("victory", gStates.realTurn)
	if gStates.gameScenario=="The Gauntlet" or gStates.gameScenario=="Quest for the Golden Grail" then
		broadcastToAll("{en}Congratulations{ru}Поздравляем{zh-tw}恭喜{zh-cn}恭喜{ko}축하합니다{es}Felicidades{fr}Toutes nos félicitations{pt-br}Parabéns{de}Glückwunsch", {1,1,0.5})
		gStates.endGameAchieved="true"
		gStates.gameOver=true
		mainUIUpdate("Scenario End")
	elseif endImmediately==true then
		gStates.endGameAchieved="true"
		gStates.gameOver=true
		mainUIUpdate("Game Over")
	else
		broadcastToAll("{en}Final Round of Turns Started{ru}Начался последний круг ходов{zh-tw}最终轮的回合开始了{zh-cn}最终轮的回合开始了{ko}마지막 턴 시작{es}Inicio de la Ultima Ronda de Turnos{fr}Dernier Rounde de Tours Commencé{pt-br}Rodada Final de Turnos começou{de}Die letzte Runde hat begonnen", {1,1,0.5})
	end
	refreshCoopCompSkillWarnings()
	return true
end

clearScenarioEndAchieved=function()
	if gStates.endGameAchieved=="false" then return false end
	UI.setAttribute("EndGameButtonText", "text", "{en}Scenario End Achieved - No{ru}Конец сценария достигнут - Нет{zh-tw}達成劇本結束 - 否{zh-cn}達成剧本结束 - 否{ko}시나리오 종료 조건 충족 전{es}Escenario Fin Realizados - No{fr}Scénario Fin Atteint - Non{pt-br}Fim do Cenário Alcançado - Não{de}Szenarioziel Erreicht – Nein")
	UI.setAttribute("EndGameButtonImage", "image", "Sliced Button/Button New Active")
	UI.setAttribute("EndGameButtonImage", "color", "white")
	UI.setAttribute("PreEndTurnImage", "image", "Sliced Button/Button New Active")
	UI.setAttribute("PreEndTurn", "interactable", "True")
	gStates.gameOver=false
	for _, turnDetails in pairs(turnOrder) do turnDetails.gameEnder=false end
	if gStates.finalTurnReason=="victory" then clearFinalTurnBoundary() else ensureFinalTurnBoundary() end
	gStates.endGameAchieved=(gStates.finalTurnReason=="endRound" and gStates.currentRound==gStates.rounds) and "true" or "false"
	broadcastToAll("{en}Turn order resumed{ru}Порядок хода восстановлен{zh-tw}回合顺序恢复了{zh-cn}回合顺序恢复了{ko}턴 순서가 재개되었습니다{es}Se reanudó el orden de turno{fr}L'ordre des tours a repris{pt-br}Ordem de Turno retomada{de}Reihenfolge der Drehung wieder aufgenommen", {1,1,0.5})
	mainUIUpdate("Scenario End")
	refreshCoopCompSkillWarnings()
	return true
end

function toggleScenarioEndAchieved(player, mouseButton, id)
	if gStates.endGameAchieved=="false" then return markScenarioEndAchieved(false) end
	return clearScenarioEndAchieved()
end

--Dungeon Lords secret entrances remember the exact Village/Monastery that created each placement request.
--That lets the drop validator enforce the scenario's adjacency rule instead of accepting any empty map hex.
function dungeonLordsPendingSecretName(entry)
	if type(entry)=="table" then return entry.siteType or entry.name end
	return entry
end

dungeonLordsSecretSourceFeature=function(secretName)
	if secretName=="Secret Dungeon" then return "village" end
	if secretName=="Secret Tomb" then return "monastery" end
	return nil
end

dungeonLordsSecretSourcePosition=function(entry)
	if type(entry)~="table" then return nil end
	local terrain=entry.sourceTerrainGUID~=nil and getObjectFromGUID(entry.sourceTerrainGUID) or nil
	if terrain~=nil and entry.sourceBearing~=nil then
		local xy=angleToXY(terrain,tostring(entry.sourceBearing))
		return {xy[1],terrain.getPosition()[2],xy[2]}
	end
	return entry.sourcePosition
end

dungeonLordsSecretSpaceBasicLegal=function(terrain,bearing)
	if terrain==nil or bearing==nil or terrainTiles[terrain.guid]==nil then return false end
	local details=terrainTiles[terrain.guid]
	local key=tostring(bearing)
	local feature=details.hexFeature~=nil and details.hexFeature[key] or nil
	local terrainType=details.hexType~=nil and details.hexType[key] or nil
	local noSite=feature=="" or feature=="rampaging" or feature=="draconum"
	return noSite==true and terrainType~=nil and terrainType~="swamp" and terrainType~="lake" and terrainType~="mountain" and terrainType~="ocean"
end

dungeonLordsFindAdjacentSecretSource=function(secretName,destinationPosition)
	local sourceFeature=dungeonLordsSecretSourceFeature(secretName)
	local map=getObjectFromGUID(mapArea)
	if sourceFeature==nil or destinationPosition==nil or map==nil then return nil end
	for _,terrain in pairs(map.getObjects()) do
		local details=terrainTiles[terrain.guid]
		if details~=nil and terrain.is_face_down==false then
			for sourceBearing,feature in pairs(details.hexFeature or {}) do
				if feature==sourceFeature then
					local xy=angleToXY(terrain,sourceBearing)
					local sourcePos={xy[1],terrain.getPosition()[2],xy[2]}
					if runtimeMapWorldHexDistance(sourcePos,destinationPosition)==1 then
						return {siteType=secretName,sourceTerrainGUID=terrain.guid,sourceBearing=tostring(sourceBearing),sourcePosition=sourcePos}
					end
				end
			end
		end
	end
	return nil
end

dungeonLordsSecretDestinationLegal=function(terrain,bearing,request)
	if dungeonLordsSecretSpaceBasicLegal(terrain,bearing)~=true then return false,nil end
	local xy=angleToXY(terrain,tostring(bearing))
	local destinationPosition={xy[1],terrain.getPosition()[2],xy[2]}
	local normalized=request
	if type(normalized)~="table" then normalized=dungeonLordsFindAdjacentSecretSource(dungeonLordsPendingSecretName(request),destinationPosition) end
	local sourcePosition=dungeonLordsSecretSourcePosition(normalized)
	if sourcePosition==nil or runtimeMapWorldHexDistance(sourcePosition,destinationPosition)~=1 then return false,normalized end
	return true,normalized
end

dungeonLordsSecretLegalDestinationCount=function(request)
	local map=getObjectFromGUID(mapArea)
	if map==nil then return 0 end
	local count=0
	for _,terrain in pairs(map.getObjects()) do
		local details=terrainTiles[terrain.guid]
		if details~=nil and terrain.is_face_down==false then
			for destinationBearing,_ in pairs(details.hexType or {}) do
				if dungeonLordsSecretDestinationLegal(terrain,destinationBearing,request)==true then count=count+1 end
			end
		end
	end
	return count
end

dungeonLordsSecretRequestMatches=function(a,b)
	if dungeonLordsPendingSecretName(a)~=dungeonLordsPendingSecretName(b) then return false end
	if type(a)~="table" or type(b)~="table" then return false end
	return a.sourceTerrainGUID==b.sourceTerrainGUID and tostring(a.sourceBearing)==tostring(b.sourceBearing)
end

dungeonLordsQueueSecretRequest=function(request,quiet)
	if request==nil then return false end
	gStates.locationPlace=gStates.locationPlace or {}
	for _,existing in ipairs(gStates.locationPlace) do if dungeonLordsSecretRequestMatches(existing,request)==true then return false end end
	if dungeonLordsSecretLegalDestinationCount(request)==0 then
		if quiet~=true then
			local source=dungeonLordsSecretSourceFeature(dungeonLordsPendingSecretName(request)) or "site"
			broadcastToAll(joinLang({"{en}Dungeon Lords: no legal space exists next to the revealed {ru}Владыки Подземелий: рядом с открытым объектом нет подходящей клетки: {zh-tw}地下城領主：新揭示的 {zh-cn}地下城领主：新揭示的 {ko}던전 로드: 공개된 {es}Señores de las Mazmorras: no existe ningún espacio legal junto a {fr}Seigneurs des Donjons : aucune case légale n’existe à côté de {pt-br}Senhores das Masmorras: não existe espaço válido ao lado de {de}Kerkerfürsten: Neben dem aufgedeckten ",source,"{en}; no secret entrance is placed.{ru}; тайный вход не размещается.{zh-tw} 旁沒有合法空間；不放置秘密入口。{zh-cn} 旁没有合法空间；不放置秘密入口。{ko} 옆에 합법적인 칸이 없어 비밀 입구를 배치하지 않습니다.{es}; no se coloca ninguna entrada secreta.{fr} ; aucune entrée secrète n’est placée.{pt-br}; nenhuma entrada secreta é colocada.{de} gibt es kein gültiges Feld; es wird kein Geheimeingang platziert."}),{1,0.75,0.2})
		end
		return false
	end
	gStates.locationPlace[#gStates.locationPlace+1]=request
	return true
end

dungeonLordsPruneImpossibleSecretRequests=function()
	gStates.locationPlace=gStates.locationPlace or {}
	local removed=false
	for i=#gStates.locationPlace,1,-1 do
		local request=gStates.locationPlace[i]
		if dungeonLordsSecretLegalDestinationCount(request)==0 then
			local source=dungeonLordsSecretSourceFeature(dungeonLordsPendingSecretName(request)) or "site"
			broadcastToAll(joinLang({"{en}Dungeon Lords: no legal space remains next to the revealed {ru}Владыки Подземелий: рядом с открытым объектом больше нет подходящей клетки: {zh-tw}地下城領主：新揭示的 {zh-cn}地下城领主：新揭示的 {ko}던전 로드: 공개된 {es}Señores de las Mazmorras: ya no queda ningún espacio legal junto a {fr}Seigneurs des Donjons : aucune case légale ne reste à côté de {pt-br}Senhores das Masmorras: não resta espaço válido ao lado de {de}Kerkerfürsten: Neben dem aufgedeckten ",source,"{en}; that secret entrance is skipped.{ru}; этот тайный вход пропускается.{zh-tw} 旁已無合法空間；跳過該秘密入口。{zh-cn} 旁已无合法空间；跳过该秘密入口。{ko} 옆에 합법적인 칸이 남아 있지 않아 그 비밀 입구를 건너뜁니다.{es}; se omite esa entrada secreta.{fr} ; cette entrée secrète est ignorée.{pt-br}; essa entrada secreta é ignorada.{de} ist kein gültiges Feld mehr frei; dieser Geheimeingang wird übersprungen."}),{1,0.75,0.2})
			table.remove(gStates.locationPlace,i)
			removed=true
		end
	end
	return removed
end

function dungeonLordsQueueSecretSite(terrain,bearing,sourceFeature)
	if gStates.gameScenario~="Dungeon Lords" or terrain==nil then return false end
	local secretName=sourceFeature=="village" and "Secret Dungeon" or sourceFeature=="monastery" and "Secret Tomb" or nil
	if secretName==nil then return false end
	local xy=angleToXY(terrain,tostring(bearing))
	local request={siteType=secretName,sourceTerrainGUID=terrain.guid,sourceBearing=tostring(bearing),sourcePosition={xy[1],terrain.getPosition()[2],xy[2]}}
	local queued=dungeonLordsQueueSecretRequest(request,false)
	if queued==true then mainUIUpdate("Need Token") end
	return queued
end

function dungeonLordsHandleSecretSiteToken(obj,status,terrain,bearing,hexFeature)
	if gStates.gameScenario~="Dungeon Lords" or obj==nil or terrain==nil or bearing==nil then return false end
	local secretName=obj.getName()
	if secretName~="Secret Dungeon" and secretName~="Secret Tomb" then return false end
	local site=secretName=="Secret Dungeon" and "dungeon" or "tomb"
	gStates.locationPlace=gStates.locationPlace or {}
	gStates.dungeonLordsSecretSiteOrigins=gStates.dungeonLordsSecretSiteOrigins or {}
	if status=="enter" then
		local pending=gStates.locationPlace[#gStates.locationPlace]
		local pendingName=dungeonLordsPendingSecretName(pending)
		if pendingName~=secretName then
			if pendingName~=nil then broadcastToAll(joinLang({"{en}Dungeon Lords: place the requested {ru}Владыки Подземелий: сначала разместите требуемый {zh-tw}地下城領主：請先放置要求的 {zh-cn}地下城领主：请先放置要求的 {ko}던전 로드: 먼저 요청된 {es}Señores de las Mazmorras: coloca primero la entrada solicitada {fr}Seigneurs des Donjons : placez d’abord l’entrée demandée {pt-br}Senhores das Masmorras: coloque primeiro a entrada solicitada {de}Kerkerfürsten: Platziere zuerst den angeforderten ",tostring(pendingName),"{en} first.{ru}.{zh-tw}。{zh-cn}。{ko}을(를) 배치하십시오.{es}.{fr}.{pt-br}.{de}."}),{1,0.55,0.2})
			else broadcastToAll("{en}Dungeon Lords: that secret entrance has not been requested by a newly revealed Village or Monastery.{ru}Владыки Подземелий: этот тайный вход не был запрошен недавно открытой Деревней или Монастырём.{zh-tw}地下城領主：新揭示的村莊或修道院並未要求放置此秘密入口。{zh-cn}地下城领主：新揭示的村庄或修道院并未要求放置此秘密入口。{ko}던전 로드: 새로 공개된 마을이나 수도원이 이 비밀 입구를 요청하지 않았습니다.{es}Señores de las Mazmorras: esta entrada secreta no fue solicitada por una Aldea o Monasterio recién revelados.{fr}Seigneurs des Donjons : cette entrée secrète n’a pas été demandée par un Village ou un Monastère récemment révélé.{pt-br}Senhores das Masmorras: esta entrada secreta não foi solicitada por uma Vila ou Mosteiro recém-revelado.{de}Kerkerfürsten: Dieser Geheimeingang wurde nicht von einem neu aufgedeckten Dorf oder Kloster angefordert.",{1,0.55,0.2}) end
			return true
		end
		local legal,normalized=dungeonLordsSecretDestinationLegal(terrain,bearing,pending)
		if legal~=true then
			broadcastToAll("{en}Dungeon Lords: the secret entrance must be on an accessible, non-Swamp empty space adjacent to the Village or Monastery that created it.{ru}Владыки Подземелий: тайный вход должен находиться на доступной пустой клетке, не являющейся Болотом, рядом с создавшей его Деревней или Монастырём.{zh-tw}地下城領主：秘密入口必須放在建立它的村莊或修道院旁，一個可進入、非沼澤且空置的空間。{zh-cn}地下城领主：秘密入口必须放在建立它的村庄或修道院旁，一个可进入、非沼泽且空置的空间。{ko}던전 로드: 비밀 입구는 이를 생성한 마을 또는 수도원에 인접한, 접근 가능하고 늪이 아닌 빈 칸에 있어야 합니다.{es}Señores de las Mazmorras: la entrada secreta debe estar en un espacio vacío accesible, que no sea Pantano, adyacente a la Aldea o Monasterio que la creó.{fr}Seigneurs des Donjons : l’entrée secrète doit se trouver sur une case vide accessible, non-Marais, adjacente au Village ou au Monastère qui l’a créée.{pt-br}Senhores das Masmorras: a entrada secreta deve ficar em um espaço vazio acessível, que não seja Pântano, adjacente à Vila ou ao Mosteiro que a criou.{de}Kerkerfürsten: Der Geheimeingang muss auf einem zugänglichen, leeren Nicht-Sumpf-Feld neben dem Dorf oder Kloster liegen, das ihn erzeugt hat.",{1,0.55,0.2})
			return true
		end
		runtimeMapSetHexFeature(terrain.guid,bearing,site)
		if gStates.hexOverideSave[terrain.guid]==nil then gStates.hexOverideSave[terrain.guid]={} end
		gStates.hexOverideSave[terrain.guid][tostring(bearing)]=site
		normalized.destinationTerrainGUID=terrain.guid
		normalized.destinationBearing=tostring(bearing)
		gStates.dungeonLordsSecretSiteOrigins[obj.guid]=normalized
		obj.lock()
		broadcastToAll(joinLang({translateWord[secretName], "{en} located.{ru} размещена(о).{zh-tw} 坐落于{zh-cn} 坐落于{ko} 설치됨{es} situado.{fr} situé.{pt-br} localizado.{de} liegt."}), {1,1,0.5})
		table.remove(gStates.locationPlace)
		dungeonLordsPruneImpossibleSecretRequests()
		mainUIUpdate("Need Token")
		local infoGUID=site=="tomb" and "1cab50" or "57dcab"
		local info=getObjectFromGUID(infoGUID)
		if info~=nil then info.setRotationSmooth({0.0,180.0,0.0}) end
		moveDisplayTerrainCache={signature=nil,hexMap=nil}
		updateMoveDisplay()
		return true
	end
	if status=="remove" and hexFeature==site then
		local origin=gStates.dungeonLordsSecretSiteOrigins[obj.guid]
		if origin==nil then
			local xy=angleToXY(terrain,tostring(bearing))
			origin=dungeonLordsFindAdjacentSecretSource(secretName,{xy[1],terrain.getPosition()[2],xy[2]}) or secretName
		end
		runtimeMapSetHexFeature(terrain.guid,bearing,"")
		if gStates.hexOverideSave[terrain.guid]==nil then gStates.hexOverideSave[terrain.guid]={} end
		gStates.hexOverideSave[terrain.guid][tostring(bearing)]=""
		gStates.dungeonLordsSecretSiteOrigins[obj.guid]=nil
		broadcastToAll(joinLang({translateWord[secretName], "{en} removed.{ru} удалена(о).{zh-tw} 移除的{zh-cn} 移除的{ko} 제거됨{es} remoto.{fr} supprimé.{pt-br} removido.{de} entfernt."}), {1,1,0.5})
		dungeonLordsQueueSecretRequest(origin,true)
		dungeonLordsPruneImpossibleSecretRequests()
		mainUIUpdate("Need Token")
		moveDisplayTerrainCache={signature=nil,hexMap=nil}
		updateMoveDisplay()
		return true
	end
	return true
end


--Apocalypse is Here is the only scenario that uses the Horsemen's roaming target priorities.
local function apocalypseIsHereHorsemanPriorityLocalizedList(text)
	local parts={}
	for term in tostring(text or ""):gmatch("[^,]+") do
		term=term:match("^%s*(.-)%s*$")
		if #parts>0 then parts[#parts+1]=", " end
		parts[#parts+1]=translateWord[term] or term
	end
	return joinLang(parts)
end

function apocalypseIsHereHorsemanPriorityDescription(ref)
	local data,name=horsemanDataFor(ref)
	if data==nil then return "" end
	local state=gStates~=nil and gStates.horsemen~=nil and gStates.horsemen[name] or nil
	local level=state~=nil and state.level or nil
	local heading=joinLang({"{en}[00ff00]HORSEMAN - {ru}[00ff00]ВСАДНИК - {zh-tw}[00ff00]騎士 - {zh-cn}[00ff00]骑士 - {ko}[00ff00]기사 - {es}[00ff00]JINETE - {fr}[00ff00]CAVALIER - {pt-br}[00ff00]CAVALEIRO - {de}[00ff00]REITER - ",string.upper(name),level~=nil and joinLang({"{en} (LEVEL {ru} (УРОВЕНЬ {zh-tw}（等級 {zh-cn}（等级 {ko} (레벨 {es} (NIVEL {fr} (NIVEAU {pt-br} (NÍVEL {de} (STUFE ",tostring(level),"{en}){ru}){zh-tw}）{zh-cn}）{ko}){es}){fr}){pt-br}){de})"}) or "","[-]\n"})
	return joinLang({heading,
		"{en}Priority A: {ru}Приоритет A: {zh-tw}優先級 A：{zh-cn}优先级 A：{ko}우선순위 A: {es}Prioridad A: {fr}Priorité A : {pt-br}Prioridade A: {de}Priorität A: ",apocalypseIsHereHorsemanPriorityLocalizedList(data.priorityText.A),"\n",
		"{en}Priority B: {ru}Приоритет B: {zh-tw}優先級 B：{zh-cn}优先级 B：{ko}우선순위 B: {es}Prioridad B: {fr}Priorité B : {pt-br}Prioridade B: {de}Priorität B: ",apocalypseIsHereHorsemanPriorityLocalizedList(data.priorityText.B),"\n",
		"{en}Priority C: {ru}Приоритет C: {zh-tw}優先級 C：{zh-cn}优先级 C：{ko}우선순위 C: {es}Prioridad C: {fr}Priorité C : {pt-br}Prioridade C: {de}Priorität C: ",apocalypseIsHereHorsemanPriorityLocalizedList(data.priorityText.C),"\n\n"})
end

function againstHorsemenAllDefeated()
	if gStates==nil or gStates.gameScenario~="Against the Horsemen Blitz" then return false end
	--Victory always requires the complete Four Horsemen roster. A partial setup must never
	--turn three (or fewer) successfully deployed tokens into an accidental scenario victory.
	for _,name in ipairs({"Famine","Pestilence","Death","War"}) do
		local state=gStates.horsemen~=nil and gStates.horsemen[name] or nil
		if state==nil or state.defeated~=true then return false end
	end
	return true
end

function againstHorsemenRegisterTimeoutLoss()
	if gStates==nil or gStates.gameScenario~="Against the Horsemen Blitz" or againstHorsemenAllDefeated()==true then return false end
	gStates.againstHorsemenTimeoutLoss=true
	gStates.blurb="{en}The final Round ended while at least one Horseman still defended the Magical Glade.<size=6>\n\n</size>The ritual is complete. You have Lost.{ru}Последний раунд закончился, пока хотя бы один Всадник всё ещё защищал Магическую поляну.<size=6>\n\n</size>Ритуал завершён. Вы проиграли.{zh-tw}最後一輪結束時，仍有至少一名騎士守在魔法林地。<size=6>\n\n</size>儀式已完成。你輸了。{zh-cn}最后一轮结束时，仍有至少一名骑士守在魔法林地。<size=6>\n\n</size>仪式已完成。你输了。{ko}마지막 라운드가 끝났지만 한 명 이상의 기사가 여전히 마법의 숲을 지키고 있습니다.<size=6>\n\n</size>의식이 완성되었습니다. 패배했습니다.{es}La Ronda final terminó mientras al menos un Jinete seguía defendiendo el Claro Mágico.<size=6>\n\n</size>El ritual se ha completado. Has perdido.{fr}La dernière Manche s'est terminée alors qu'au moins un Cavalier défendait encore la Clairière Magique.<size=6>\n\n</size>Le rituel est accompli. Vous avez perdu.{pt-br}A Rodada final terminou enquanto pelo menos um Cavaleiro ainda defendia a Clareira Mágica.<size=6>\n\n</size>O ritual foi concluído. Você perdeu.{de}Die letzte Runde endete, während noch mindestens ein Reiter die Magische Lichtung verteidigte.<size=6>\n\n</size>Das Ritual ist vollendet. Ihr habt verloren."
	UI.setAttribute("DummyNotes","Text",gStates.blurb)
	return true
end

againstHorsemenRitualDefenders=function()
	local defenders={}
	for name,state in pairs(gStates~=nil and gStates.horsemen or {}) do
		local data=horsemanData~=nil and horsemanData[name] or nil
		if state~=nil and state.defeated~=true and state.atCentralGlade==true and data~=nil and getObjectFromGUID(data.tokenGUID)~=nil then
			defenders[#defenders+1]={name=name,guid=data.tokenGUID,slot=tonumber(state.mapSlot) or 99}
		end
	end
	table.sort(defenders,function(a,b) if a.slot==b.slot then return a.name<b.name end return a.slot<b.slot end)
	return defenders
end

--The Portal card becomes the Round-4 garrison display. The tokens are physical there, but each
--surviving Horseman's logical map location remains the central Glade. Layouts stay centered for 1-4.
againstHorsemenPortalCardLayout=function(count)
	local cx,cz=-44.0,-12.30
	if count<=1 then return {{cx,1.22,cz}} end
	if count==2 then return {{cx-1.25,1.22,cz},{cx+1.25,1.22,cz}} end
	if count==3 then return {{cx-1.25,1.22,cz-0.78},{cx+1.25,1.22,cz-0.78},{cx,1.22,cz+0.78}} end
	return {{cx-1.25,1.22,cz-0.78},{cx+1.25,1.22,cz-0.78},{cx-1.25,1.22,cz+0.78},{cx+1.25,1.22,cz+0.78}}
end

--A one-player ritual assault uses the ordinary turn/reward interface, but still needs the same
--failed-assault retreat that the combined-assault location resolver provided.
function againstHorsemenFinishSoloAssault(playerIndex)
	local pending=gStates~=nil and gStates.againstHorsemenSoloAssault or nil
	if pending==nil or pending.player~=playerIndex then return nil end
	gStates.againstHorsemenSoloAssault=nil
	local player=turnOrder[playerIndex]
	if player==nil then return nil end
	if againstHorsemenAllDefeated()==true then
		player.avatarLocation="glade"
		player.avatarSharedHex=nil
		player.avatarSwapCity=nil
		return nil
	end
	local origin=pending.origin
	if origin==nil then return nil end
	player.avatarLocation=origin.avatarLocation or ""
	player.avatarSharedHex=origin.avatarSharedHex
	player.avatarSwapCity=origin.avatarSwapCity
	return origin.position
end

--Restore only Against the Horsemen's scenario-specific ritual/garrison state.
function againstHorsemenRestoreScenarioState()
	if gStates==nil or gStates.gameScenario~="Against the Horsemen Blitz" then return end
	if gStates.againstHorsemenRitualStarted==true then
		for name,state in pairs(gStates.horsemen or {}) do
			local data=horsemanData~=nil and horsemanData[name] or nil
			if data~=nil and state~=nil and state.defeated~=true and state.retired~=true then
				state.atCentralGlade=true
				state.terrainGUID=GUID.tile.country01
				state.bearing="center"
				state.revealed=true
				if monsterPugs[data.tokenGUID]~=nil and monsterPugs[data.tokenGUID].unfortified==nil then monsterPugs[data.tokenGUID].fortified=true end
			end
		end
		againstHorsemenEliminateCentralPlayers()
	end
	--Do not pull tokens away from a saved combat/reward sequence. An idle Round-4 save is safe to
	--normalize immediately to the tidy garrison display.
	if gStates.againstHorsemenRitualStarted==true and gStates.coopAssaultPhase==nil and next(gStates.attackedMonsters or {})==nil and gStates.againstHorsemenMovePending==nil then
		local defenders=againstHorsemenRitualDefenders()
		local layout=againstHorsemenPortalCardLayout(#defenders)
		for i,entry in ipairs(defenders) do
			local token=getObjectFromGUID(entry.guid)
			if token~=nil and layout[i]~=nil then
				token.setRotation({0,180,0})
				token.setPositionSmooth(layout[i],false,false)
			end
		end
	end
	--An end-of-round Horseman wave is durable state. Reissue it after load rather than leaving
	--the round reset suspended if the save happened while visible movement was still settling.
	if gStates.againstHorsemenMovePending~=nil then
		safeWaitFrames("Scenario",function() againstHorsemenContinueEndRoundMovement() end,4)
	end
end

againstHorsemenEliminateCentralPlayers=function()
	for playerIndex,details in pairs(turnOrder or {}) do
		--The standard Dummy has no Glade figure and therefore never matches this test; an active Proxy
		--does have a Mage Knight figure and is eliminated by the ritual like any other player.
		if playerDropoutInactive(playerIndex)==false and againstHorsemenPlayerAtCentralGlade(details)==true then
			details.dropoutState="dropped"
			details.avatarLocation="eliminated"
			details.avatarSharedHex=nil
			details.horsemenGladeParked=false
			gStates.skipTurn[playerIndex]=nil
			local turnToken=getObjectFromGUID(details.turnOrderTokenGUID)
			if turnToken~=nil and turnToken.is_face_down==true then turnToken.flip() end
			--Clear the old shared Portal-card parking before the Horsemen garrison arrives. Keep the
			--eliminated figure beside its own board rather than deleting a Mage Knight object.
			local avatar=coopAssaultAvatarObject(playerIndex)
			if avatar~=nil then avatar.setPosition({(details.seatPos*40)-100,1.5,-51.2}) end
			broadcastToAll(joinLang({translateWord[details.mage] or details.mage,"{en} was in the Magical Glade when the ritual began and is out of the game.{ru} находился на Магической поляне, когда начался ритуал, и выбывает из игры.{zh-tw} 在儀式開始時位於魔法林地，因此退出遊戲。{zh-cn} 在仪式开始时位于魔法林地，因此退出游戏。{ko}은(는) 의식이 시작될 때 마법의 숲에 있었으므로 게임에서 제외됩니다.{es} estaba en el Claro Mágico cuando comenzó el ritual y queda fuera de la partida.{fr} se trouvait dans la Clairière Magique lorsque le rituel a commencé et est éliminé de la partie.{pt-br} estava na Clareira Mágica quando o ritual começou e está fora da partida.{de} befand sich auf der Magischen Lichtung, als das Ritual begann, und scheidet aus dem Spiel aus."}),positionToColor(playerIndex))
		end
	end
	applyColorBarButtons()
end

againstHorsemenPrepareRitual=function()
	if gStates==nil or gStates.gameScenario~="Against the Horsemen Blitz" or gStates.againstHorsemenRitualStarted==true then return end
	gStates.againstHorsemenRitualStarted=true
	againstHorsemenEliminateCentralPlayers()
	for name,state in pairs(gStates.horsemen or {}) do
		local data=horsemanData~=nil and horsemanData[name] or nil
		local token=data~=nil and getObjectFromGUID(data.tokenGUID) or nil
		if state~=nil and data~=nil and state.defeated~=true and token~=nil then
			state.atCentralGlade=true
			state.terrainGUID=GUID.tile.country01
			state.bearing="center"
			state.revealed=true
			token.setName(name.." Level "..tostring(state.level or 1))
			if token.is_face_down==true then token.flip() end
			monsterPugs[data.tokenGUID]=monsterPugs[data.tokenGUID] or horsemanMonsterData(name,state.level)
			--The Glade now counts as a fortified site; this is site fortification only, with no city bonus.
			if monsterPugs[data.tokenGUID]~=nil and monsterPugs[data.tokenGUID].unfortified==nil then monsterPugs[data.tokenGUID].fortified=true end
		end
	end
	broadcastToAll("{en}The ritual has begun. The central Magical Glade is now a fortified assault site defended by every surviving Horseman.{ru}Ритуал начался. Центральная Магическая поляна теперь является укреплённым местом штурма, которое защищают все оставшиеся Всадники.{zh-tw}儀式已開始。中央魔法林地現在是由所有倖存騎士防守的要塞攻城地點。{zh-cn}仪式已开始。中央魔法林地现在是由所有幸存骑士防守的要塞攻城地点。{ko}의식이 시작되었습니다. 중앙의 마법의 숲은 이제 살아남은 모든 기수가 방어하는 요새화된 공격 장소입니다.{es}El ritual ha comenzado. El Claro Mágico central es ahora un lugar fortificado de asalto defendido por todos los Jinetes supervivientes.{fr}Le rituel a commencé. La Clairière Magique centrale est désormais un site d’assaut fortifié défendu par tous les Cavaliers survivants.{pt-br}O ritual começou. A Clareira Mágica central agora é um local fortificado de assalto defendido por todos os Cavaleiros sobreviventes.{de}Das Ritual hat begonnen. Die zentrale Magische Lichtung ist nun ein befestigter Angriffsort, der von allen überlebenden Reitern verteidigt wird.",{1,0.35,0.15})
	addAvatarButtons()
end

function againstHorsemenAssaultOrigin(approachPosition)
	local origin={avatarLocation="",avatarSharedHex=nil,avatarSwapCity=nil,position=nil}
	if approachPosition~=nil then
		origin.position={approachPosition[1],approachPosition[2],approachPosition[3]}
		local terrain,bearing,_,feature=terrainHexAtPosition(approachPosition)
		if terrain~=nil and bearing~=nil then origin.avatarLocation=feature or "" end
	end
	return origin
end

--Dropping the active Mage Knight onto the post-ritual Glade declares the assault. From here the
--existing city/co-op assault machinery owns defender allocation, skipped turns, combat order and rewards.
function againstHorsemenBeginGladeAssault(playerIndex,approachPosition)
	if gStates==nil or gStates.gameScenario~="Against the Horsemen Blitz" or gStates.againstHorsemenRitualStarted~=true then return false end
	local player=turnOrder[playerIndex]
	if player==nil or playerIndex~=gStates.turnNumber or playerDropoutInactive(playerIndex)==true then return false end
	local defenders=againstHorsemenRitualDefenders()
	if #defenders<1 then return false end
	local gladePos=againstHorsemenCentralGladePosition(1.45)
	if gladePos==nil then return false end
	gStates.againstHorsemenAssaultOrigin=againstHorsemenAssaultOrigin(approachPosition)
	gStates.assaultData={[player.mage]={primary={},secondary={},UIPos={1},joined=true}}
	for _,entry in ipairs(defenders) do
		gStates.assaultData[player.mage].primary[#gStates.assaultData[player.mage].primary+1]=entry.guid
		local token=getObjectFromGUID(entry.guid)
		if token~=nil then
			local p=token.getPosition()
			gStates.monsterPlayLocation[entry.guid]={p[1],p[2],p[3]}
		end
	end
	gStates.coopAssaultUnassigned={primary={},secondary={}}
	local nearby=findNearbyMages(gladePos,2.5)
	local count=1
	for _,candidate in pairs(nearby) do
		if candidate.mage~=player.mage and turnOrder[candidate.turn]~=nil then
			count=count+1
			gStates.assaultData[candidate.mage]={primary={},secondary={},UIPos={count},joined=false}
		end
	end
	gStates.coopAssaultCityGUID=GUID.tile.country01
	gStates.coopAssaultLocation="glade"
	gStates.coopAssaultType="horsemen"
	gStates.coopAssaultInitiator=playerIndex
	player.combatIconHide="Avatar"
	locationAttacked=true
	applyColorBarButtons()
	--The special cooperative attack is available only with 2+ surviving Horsemen. With one Horseman
	--or no adjacent helper, begin immediately just as a city assault with no co-op option does.
	if #defenders>1 and count>1 then coopAssaultUIUpdate() else attackCity(nil,"-1","startAssault") end
	return true
end

--Against the Horsemen reveals a token as soon as the map space under it is revealed. The token's
--rotation hides the real level image before that point; once revealed it stays face up for the scenario.
againstHorsemenRefreshHorseman=function(name)
	if gStates==nil or gStates.gameScenario~="Against the Horsemen Blitz" or name==nil then return false end
	local state=gStates.horsemen~=nil and gStates.horsemen[name] or nil
	local data=horsemanData~=nil and horsemanData[name] or nil
	local token=data~=nil and getObjectFromGUID(data.tokenGUID) or nil
	if state==nil or data==nil or token==nil or state.defeated==true then return false end
	if state.atCentralGlade==true then
		state.terrainGUID=GUID.tile.country01
		state.bearing="center"
		if state.revealed~=true then
			state.revealed=true
			token.setName(name.." Level "..tostring(state.level or 1))
			if token.is_face_down==true then token.flip() end
			return true
		end
		return false
	end
	local terrain,bearing=terrainHexAtPosition(token.getPosition())
	if terrain==nil or bearing==nil then return false end
	state.terrainGUID=terrain.guid
	state.bearing=bearing
	if state.revealed==true or terrain.is_face_down==true then return false end
	state.revealed=true
	token.setName(name.." Level "..tostring(state.level or 1))
	if token.is_face_down==true then token.flip() end
	broadcastToAll(joinLang({name,"{en} has been revealed at Level {ru} раскрыт на уровне {zh-tw} 已揭示，等級 {zh-cn} 已揭示，等级 {ko} 공개됨. 레벨 {es} ha sido revelado en Nivel {fr} a été révélé au Niveau {pt-br} foi revelado no Nível {de} wurde auf Stufe ",tostring(state.level or 1),"."}),{1,0.75,0.2})
	return true
end

function againstHorsemenRefreshReveals()
	if gStates==nil or gStates.gameScenario~="Against the Horsemen Blitz" then return end
	for name,_ in pairs(gStates.horsemen or {}) do againstHorsemenRefreshHorseman(name) end
end

--Against the Horsemen uses a fixed hex grid around Countryside 1. There is no reason to build a
--map graph or run path-finding here: convert the token position directly to axial coordinates, take
--one deterministic step toward the nearest centre-line, then keep following that line into the Glade.
againstHorsemenGladePosition=function()
	local terrain=getObjectFromGUID(GUID.tile.country01)
	if terrain==nil then return nil end
	local xy=angleToXY(terrain,"center")
	if xy==nil then return nil end
	return {xy[1],1.45,xy[2]}
end

againstHorsemenInlineGridDistance=function(q,r)
	return math.min(math.abs(q),math.abs(r),math.abs(q-r))
end

againstHorsemenDefaultNextPosition=function(position,center)
	local q,r=runtimeMapWorldToAxial(position,center)
	if q==nil or r==nil or (q==0 and r==0) then return nil end
	local currentCenter=runtimeMapAxialDistance(q,r)
	local currentInline=againstHorsemenInlineGridDistance(q,r)
	local neighbours={{1,0},{-1,0},{0,1},{0,-1},{1,1},{-1,-1}}
	local bestQ,bestR=nil,nil
	local bestInline,bestCenter=999,999
	for _,offset in ipairs(neighbours) do
		local nq=q+offset[1]
		local nr=r+offset[2]
		local inline=againstHorsemenInlineGridDistance(nq,nr)
		local centerDistance=runtimeMapAxialDistance(nq,nr)
		if centerDistance~=nil then
			local legal=false
			if currentInline==0 then
				--Already on one of the three lines through the Glade: stay on it and go straight inward.
				legal=inline==0 and centerDistance==currentCenter-1
			else
				--Before reaching a centre-line, simply take the adjacent hex closest to one of those lines.
				legal=inline<currentInline
			end
			if legal==true and (bestQ==nil or inline<bestInline or
				(inline==bestInline and centerDistance<bestCenter) or
				(inline==bestInline and centerDistance==bestCenter and (nq<bestQ or (nq==bestQ and nr<bestR)))) then
				bestQ=nq bestR=nr bestInline=inline bestCenter=centerDistance
			end
		end
	end
	if bestQ==nil then return nil end
	return runtimeMapAxialToWorld(bestQ,bestR,center,1.45)
end

againstHorsemenFinalizeMoveWave=function()
	local pending=gStates~=nil and gStates.againstHorsemenMovePending or nil
	if pending==nil or pending.movingTargets==nil then return end
	--Round 3's ritual state is committed only after every surviving Horseman has physically
	--settled into the garrison display. Until this point players on the Glade remain alive.
	if pending.finalGlade==true and pending.ritualPrepared~=true then
		againstHorsemenPrepareRitual()
		pending.ritualPrepared=true
	end
	for name,_ in pairs(pending.movingTargets) do againstHorsemenRefreshHorseman(name) end
	pending.movingTargets=nil
	pending.stepsRemaining=math.max(0,(pending.stepsRemaining or 1)-1)
	safeWaitFrames("Scenario",function() againstHorsemenContinueEndRoundMovement() end,4)
end

againstHorsemenAnimateMoveWave=function(targets)
	local pending=gStates~=nil and gStates.againstHorsemenMovePending or nil
	if pending==nil or targets==nil then return end
	pending.movingTargets=targets

	local remaining=0
	local allStarted=false
	local function oneSettled()
		remaining=math.max(0,remaining-1)
		if allStarted==true and remaining==0 then againstHorsemenFinalizeMoveWave() end
	end

	for name,target in pairs(targets) do
		local data=horsemanData~=nil and horsemanData[name] or nil
		local token=data~=nil and getObjectFromGUID(data.tokenGUID) or nil
		if token~=nil and target.position~=nil then
			remaining=remaining+1
			local started=mapTokenSettleArrival(token.guid,target.position,{releaseOrigin=true},function() oneSettled() end)
			if started~=true then
				token.setPositionSmooth(target.position,false)
				mapTokenAfterSettled(token.guid,function() oneSettled() end)
			end
		end
	end
	allStarted=true
	if remaining==0 then againstHorsemenFinalizeMoveWave() end
end

againstHorsemenContinueEndRoundMovement=function()
	local pending=gStates~=nil and gStates.againstHorsemenMovePending or nil
	if pending==nil then return end
	--If a save/load happens while a wave is moving, reissue the same destinations together.
	if pending.movingTargets~=nil then againstHorsemenAnimateMoveWave(pending.movingTargets) return end
	if (pending.stepsRemaining or 0)<=0 then
		gStates.againstHorsemenEndRoundMovedRound=pending.round
		gStates.againstHorsemenMovePending=nil
		safeWaitFrames("Scenario",function() endRound(true) end,4)
		return
	end

	local center=againstHorsemenGladePosition()
	if center==nil then
		broadcastToAll("{en}Horsemen movement could not locate the central Magical Glade on the map.{ru}Движение Всадников не смогло найти центральную Магическую поляну на карте.{zh-tw}騎士移動無法在地圖上找到中央魔法林地。{zh-cn}骑士移动无法在地图上找到中央魔法林地。{ko}기사 이동에서 맵 중앙의 마법의 숲을 찾지 못했습니다.{es}El movimiento de los Jinetes no pudo localizar el Claro Mágico central en el mapa.{fr}Le déplacement des Cavaliers n’a pas pu localiser la Clairière Magique centrale sur la carte.{pt-br}O movimento dos Cavaleiros não conseguiu localizar a Clareira Mágica central no mapa.{de}Die Bewegung der Reiter konnte die zentrale Magische Lichtung auf der Karte nicht finden.",{1,0.3,0.2})
		pending.stepsRemaining=0
		againstHorsemenContinueEndRoundMovement()
		return
	end
	local targets={}
	local ritualDefenders={}
	if pending.finalGlade==true then
		--Build the display directly from the surviving movement queue. Do not mark the ritual as
		--started yet: that commit eliminates Glade occupants and belongs after the movement settles.
		for _,name in ipairs(pending.queue or {}) do
			local state=gStates.horsemen~=nil and gStates.horsemen[name] or nil
			local data=horsemanData~=nil and horsemanData[name] or nil
			if state~=nil and state.defeated~=true and data~=nil and getObjectFromGUID(data.tokenGUID)~=nil then
				ritualDefenders[#ritualDefenders+1]={name=name,guid=data.tokenGUID,slot=tonumber(state.mapSlot) or 99}
			end
		end
		table.sort(ritualDefenders,function(a,b) if a.slot==b.slot then return a.name<b.name end return a.slot<b.slot end)
	end
	local ritualLayout=pending.finalGlade==true and againstHorsemenPortalCardLayout(#ritualDefenders) or nil
	local ritualSlot={}
	for i,entry in ipairs(ritualDefenders) do ritualSlot[entry.name]=i end
	for _,name in ipairs(pending.queue or {}) do
		local state=gStates.horsemen~=nil and gStates.horsemen[name] or nil
		local data=horsemanData~=nil and horsemanData[name] or nil
		local token=data~=nil and getObjectFromGUID(data.tokenGUID) or nil
		if state~=nil and state.defeated~=true and token~=nil then
			local nextPosition=nil
			if pending.finalGlade==true then
				--They will logically enter the Glade only after this physical garrison move settles.
				nextPosition=ritualLayout~=nil and ritualLayout[ritualSlot[name]] or nil
			else
				--Use the physical position every wave. Manual player corrections therefore become the new path.
				nextPosition=againstHorsemenDefaultNextPosition(token.getPosition(),center)
			end
			if nextPosition~=nil then targets[name]={position=nextPosition} end
		end
	end
	if next(targets)==nil then
		pending.stepsRemaining=0
		againstHorsemenContinueEndRoundMovement()
		return
	end
	againstHorsemenAnimateMoveWave(targets)
end

--Rounds 1 and 2 move every surviving Horseman two hexes inward. At the end of Round 3 all survivors
--move together directly onto the central Magical Glade, beginning the final ritual round.
function againstHorsemenBeginEndRoundMovement()
	if gStates==nil or gStates.gameScenario~="Against the Horsemen Blitz" or gStates.currentRound>3 then return false end
	if gStates.againstHorsemenEndRoundMovedRound==gStates.currentRound then return false end
	if gStates.againstHorsemenMovePending~=nil then
		againstHorsemenContinueEndRoundMovement()
		return true
	end
	againstHorsemenRefreshReveals()
	local ordered={}
	for name,state in pairs(gStates.horsemen or {}) do ordered[#ordered+1]={name=name,slot=tonumber(state.mapSlot) or 99} end
	table.sort(ordered,function(a,b) if a.slot==b.slot then return a.name<b.name end return a.slot<b.slot end)
	local queue={}
	for _,entry in ipairs(ordered) do
		local state=gStates.horsemen[entry.name]
		local data=horsemanData[entry.name]
		if state~=nil and state.defeated~=true and data~=nil and getObjectFromGUID(data.tokenGUID)~=nil then queue[#queue+1]=entry.name end
	end
	if #queue<1 then return false end
	if gStates.currentRound==3 then
		gStates.againstHorsemenMovePending={round=gStates.currentRound,queue=queue,stepsRemaining=1,finalGlade=true}
		broadcastToAll("{en}End of Round 3: the surviving Horsemen move into the central Magical Glade and begin the ritual.{ru}Конец раунда 3: оставшиеся Всадники перемещаются на центральную Магическую поляну и начинают ритуал.{zh-tw}第 3 回合輪結束：倖存騎士移入中央魔法林地並開始儀式。{zh-cn}第 3 回合轮结束：幸存骑士移入中央魔法林地并开始仪式。{ko}3라운드 종료: 살아남은 기사들이 중앙 마법의 숲으로 이동해 의식을 시작합니다.{es}Fin de la Ronda 3: los Jinetes supervivientes se mueven al Claro Mágico central y comienzan el ritual.{fr}Fin de la Manche 3 : les Cavaliers survivants se déplacent dans la Clairière Magique centrale et commencent le rituel.{pt-br}Fim da Rodada 3: os Cavaleiros sobreviventes se movem para a Clareira Mágica central e iniciam o ritual.{de}Ende von Runde 3: Die überlebenden Reiter ziehen auf die zentrale Magische Lichtung und beginnen das Ritual.",{1,0.3,0.2})
	else
		gStates.againstHorsemenMovePending={round=gStates.currentRound,queue=queue,stepsRemaining=2}
		broadcastToAll(joinLang({"{en}End of Round {ru}Конец раунда {zh-tw}第 {zh-cn}第 {ko}라운드 {es}Fin de la Ronda {fr}Fin de la Manche {pt-br}Fim da Rodada {de}Ende von Runde ",tostring(gStates.currentRound),"{en}: each surviving Horseman moves two spaces closer to the central Magical Glade.{ru}: каждый оставшийся Всадник перемещается на две клетки ближе к центральной Магической поляне.{zh-tw} 回合輪結束：每名倖存騎士向中央魔法林地移動兩格。{zh-cn} 回合轮结束：每名幸存骑士向中央魔法林地移动两格。{ko} 종료: 살아남은 각 기수는 중앙 마법의 숲 쪽으로 2칸 이동합니다.{es}: cada Jinete superviviente se mueve dos espacios hacia el Claro Mágico central.{fr} : chaque Cavalier survivant se déplace de deux cases vers la Clairière Magique centrale.{pt-br}: cada Cavaleiro sobrevivente se move dois espaços em direção à Clareira Mágica central.{de}: Jeder überlebende Reiter bewegt sich zwei Felder näher zur zentralen Magischen Lichtung."}),{1,0.75,0.2})
	end
	againstHorsemenContinueEndRoundMovement()
	return true
end

againstHorsemenStartingLevel=function()
	if gStates.playerCount==1 then return 2 end
	if gStates.coop==1 then return math.min(6,gStates.playerCount+2) end
	return math.max(1,math.min(6,gStates.playerCount))
end

function againstHorsemenSetupTokens(coreTileGUIDs, coreTilePositions)
	if gStates==nil or gStates.gameScenario~="Against the Horsemen Blitz" then return false,"HORSEMEN SETUP ERROR: wrong scenario state" end
	local bag=getObjectFromGUID(GUID.bag.apocalypseDragon)
	if bag==nil then return false,"HORSEMEN SETUP ERROR: Apocalypse setup bag is missing" end
	local names={"Famine","Pestilence","Death","War"}
	for i=#names,2,-1 do
		local j=math.random(i)
		names[i],names[j]=names[j],names[i]
	end
	local level=againstHorsemenStartingLevel()
	gStates.horsemen={}
	gStates.horsemenDefeatedBy={}
	gStates.againstHorsemenCoreTiles={}
	gStates.againstHorsemenRitualStarted=false
	gStates.againstHorsemenAssaultOrigin=nil
	gStates.againstHorsemenSoloAssault=nil
	gStates.againstHorsemenTimeoutLoss=false
	for i,name in ipairs(names) do
		local data=horsemanData[name]
		local pos=coreTilePositions[i]
		local coreGUID=coreTileGUIDs[i]
		if data==nil or pos==nil or coreGUID==nil then
			return false,"HORSEMEN SETUP ERROR: missing setup data for slot "..tostring(i)
		end
		--The left/right Horsemen begin one additional hex outward from their Core-tile centres.
		--Slots 2 and 4 are the right and left Core tiles respectively; one horizontal hex is 2.4 world units.
		local horsemanX=pos[1]
		if i==2 then horsemanX=horsemanX+2.4 elseif i==4 then horsemanX=horsemanX-2.4 end
		local token=bag.takeObject({guid=data.tokenGUID,position={horsemanX,2.3,pos[3]},rotation={0,180,180},smooth=false})
		if token==nil then return false,"HORSEMEN SETUP ERROR: could not deploy "..tostring(name) end
		if setHorsemanLevel(name,level,true)~=true then return false,"HORSEMEN SETUP ERROR: could not initialize "..tostring(name) end
		local state=gStates.horsemen[name]
		if state==nil then return false,"HORSEMEN SETUP ERROR: missing runtime state for "..tostring(name) end
		state.revealed=false
		--Record the actual hex, not merely the Core-tile centre. This matters for the two
		--side Horsemen now that their physical starting hex is one step farther outward.
		local horsemanTerrain,horsemanBearing=terrainHexAtPosition({horsemanX,1.1,pos[3]})
		state.terrainGUID=horsemanTerrain~=nil and horsemanTerrain.guid or coreGUID
		state.bearing=horsemanBearing or "center"
		state.mapSlot=i
		gStates.againstHorsemenCoreTiles[i]=coreGUID
	end
	--Do not allow map setup to complete unless every named Horseman has durable runtime state.
	for _,name in ipairs({"Famine","Pestilence","Death","War"}) do
		if gStates.horsemen[name]==nil then return false,"HORSEMEN SETUP ERROR: incomplete Four Horsemen roster" end
	end
	return true
end


--Apocalypse is Here -------------------------------------------------------------
--This scenario reuses the existing Horseman combat objects and Apocalypse Dragon combat engine.
--The functions below supply the scenario-specific reveal order, roaming Horsemen turns, City/Dragon
--transition, Horseman-powered Dragon levels, and the first-Dragon-attack cleanup.
function apocalypseIsHereActive()
	return gStates~=nil and gStates.gameScenario=="Apocalypse is Here"
end

apocalypseIsHereHorsemanStartingLevel=function()
	if apocalypseIsHereActive()~=true then return nil end
	if gStates.playerCount==1 then return 4 end
	if gStates.coop==1 then return 6 end
	return 5
end

function apocalypseIsHerePositionRoundOrderToken()
	if apocalypseIsHereActive()~=true then return false end
	local token=getObjectFromGUID(apocalypseDragon.roundOrder)
	local bag=getObjectFromGUID(GUID.bag.apocalypseDragon)
	local target={-1.90,0.97,-22.20}
	if token==nil and bag~=nil then token=bag.takeObject({guid=apocalypseDragon.roundOrder,position=target,rotation={0,180,0},smooth=false}) end
	if token==nil then return false end
	token.unlock()
	token.setRotation({0,180,0})
	token.setPositionSmooth(target,false,true)
	safeWaitCondition("Scenario",function() local current=getObjectFromGUID(apocalypseDragon.roundOrder) if current~=nil then current.lock() end end,
		function() local current=getObjectFromGUID(apocalypseDragon.roundOrder) return current==nil or current.isSmoothMoving()==false end)
	return true
end

function apocalypseIsHereSetup()
	if apocalypseIsHereActive()~=true then return false end
	local names={"Famine","Pestilence","Death","War"}
	for i=#names,2,-1 do local j=math.random(i) names[i],names[j]=names[j],names[i] end
	gStates.apocalypseHereHorsemanOrder=names
	gStates.apocalypseHereNextHorseman=1
	gStates.apocalypseHereTilesRevealed=0
	gStates.apocalypseHereRevealedTiles={}
	gStates.apocalypseHereCityTilesSeen=0
	gStates.apocalypseHereHorsemenEnded=false
	gStates.apocalypseHereForcedRevealPending=false
	gStates.apocalypseHereForcedRevealCount=0
	gStates.apocalypseHereForcedRevealCheckedRound=nil
	gStates.apocalypseHereHorsemenTurnActive=false
	gStates.apocalypseHereHorsemenResumeTurn=nil
	gStates.apocalypseHereHorsemenUIState=nil
	gStates.apocalypseHereHorsemenTurnReport=nil
	gStates.apocalypseHereHorsemenQueue={}
	gStates.apocalypseHereHorsemenQueueIndex=1
	gStates.apocalypseHereHorsemanPendingChoice=nil
	gStates.apocalypseHereHorsemanAction=nil
	gStates.apocalypseHerePossessedPending={}
	gStates.apocalypseHereDragonCityRevealed=false
	gStates.apocalypseDragonAssaultFortifiedInitiator=false
	gStates.horsemen={}
	gStates.horsemenDefeatedBy={}
	local level=apocalypseIsHereHorsemanStartingLevel()
	local componentBag=getObjectFromGUID(GUID.bag.apocalypseDragon)
	--The four Horsemen are randomized into four face-down matched stacks. Each stack has its
	--Horseman card underneath its matching face-down token.
	for i,name in ipairs(names) do
		local data=horsemanData[name]
		local x=-56.50-((i-1)*3)
		gStates.horsemen[name]={level=level,tokenGUID=data.tokenGUID,revealed=false,defeated=false,retired=false,sitesDestroyed=0,mapSlot=i,revealIndex=i}
		if componentBag~=nil then
			componentBag.takeObject({guid=data.cardGUID,position={x,0.98,0.40},rotation={0,180,180},smooth=false})
			local token=componentBag.takeObject({guid=data.tokenGUID,position={x,1.12,0.40},rotation={0,180,180},smooth=false})
			if token~=nil then token.setName("") token.unlock() end
		end
	end
	apocalypseIsHerePositionRoundOrderToken()
	return true
end

apocalypseIsHereRevealThreshold=function(index)
	local thresholds=nil
	if (gStates.playerCount or 1)<=2 then thresholds={1,2,4,6}
	elseif gStates.playerCount==3 then thresholds={1,3,5,7}
	else thresholds={2,4,6,8} end
	return thresholds[index]
end

apocalypseIsHereRecomputeNextHorseman=function()
	local order=gStates.apocalypseHereHorsemanOrder or {}
	for index,name in ipairs(order) do
		local state=gStates.horsemen~=nil and gStates.horsemen[name] or nil
		if state~=nil and state.revealed~=true and state.retired~=true and state.defeated~=true and state.revealPending~=true then
			gStates.apocalypseHereNextHorseman=index
			return index
		end
	end
	gStates.apocalypseHereNextHorseman=#order+1
	return gStates.apocalypseHereNextHorseman
end

apocalypseIsHereCancelReservedReveal=function(state)
	if state==nil then return false end
	local forced=state.revealForced==true
	state.revealPending=nil
	state.revealForced=nil
	state.revealIndex=nil
	if forced==true then
		gStates.apocalypseHereForcedRevealCount=(tonumber(gStates.apocalypseHereForcedRevealCount) or 0)+1
		gStates.apocalypseHereForcedRevealPending=true
		if gStates.preEndTurn==true and mainUIUpdate~=nil then mainUIUpdate("Horseman reveal restored") end
	end
	apocalypseIsHereRecomputeNextHorseman()
	return true
end

apocalypseIsHereDeployReservedHorseman=function(name)
	if apocalypseIsHereActive()~=true then return false end
	local state=gStates.horsemen~=nil and gStates.horsemen[name] or nil
	local data=horsemanData~=nil and horsemanData[name] or nil
	if state==nil or data==nil or state.revealPending~=true then return false end
	local tileGUID=state.revealTileGUID
	local index=tonumber(state.revealIndex) or tonumber(state.mapSlot) or 1
	local forced=state.revealForced==true
	local currentTile=tileGUID~=nil and getObjectFromGUID(tileGUID) or nil
	if currentTile==nil then
		apocalypseIsHereCancelReservedReveal(state)
		print("HORSEMAN REVEAL ERROR: terrain tile "..tostring(tileGUID).." disappeared before "..tostring(name).." could deploy")
		return false
	end
	local xy=angleToXY(currentTile,"center")
	local tilePos=currentTile.getPosition()
	local target={xy[1],tilePos[2]+1.0,xy[2]}
	local token=getObjectFromGUID(data.tokenGUID)
	local bag=getObjectFromGUID(GUID.bag.apocalypseDragon)
	if token==nil and bag~=nil then token=bag.takeObject({guid=data.tokenGUID,position={target[1],target[2]+1.0,target[3]},rotation={0,180,0},smooth=false}) end
	if token==nil then
		apocalypseIsHereCancelReservedReveal(state)
		print("HORSEMAN REVEAL ERROR: "..tostring(name).." token is missing")
		return false
	end

	setHorsemanLevel(name,state.level,false)
	token=getObjectFromGUID(data.tokenGUID) or token
	local started=mapTokenSettleArrival(token.guid,target,{force=true,rotation={0,180,0}})
	if started~=true then
		apocalypseIsHereCancelReservedReveal(state)
		print("HORSEMAN REVEAL ERROR: "..tostring(name).." could not start its deployment")
		return false
	end

	state.revealPending=nil
	state.revealForced=nil
	state.revealIndex=nil
	state.revealed=true
	apocalypseIsHereRecomputeNextHorseman()

	local card=getObjectFromGUID(data.cardGUID)
	if card~=nil then
		card.unlock()
		card.setPositionSmooth({-69.80+((index-1)*5.90),0.98,0.40},false,false)
		if card.is_face_down==true then card.flip() end
	end
	broadcastToAll(joinLang({name,"{en} has been revealed at Level {ru} раскрыт на уровне {zh-tw} 已揭示，等級 {zh-cn} 已揭示，等级 {ko} 공개됨. 레벨 {es} ha sido revelado en Nivel {fr} a été révélé au Niveau {pt-br} foi revelado no Nível {de} wurde auf Stufe ",tostring(state.level),forced==true and "{en} by the Round deadline.{ru} из-за срока раунда.{zh-tw}，因回合輪期限而揭示。{zh-cn}，因回合轮期限而揭示。{ko}, 라운드 기한으로 공개되었습니다.{es} por el límite de la Ronda.{fr} en raison de la limite de la Manche.{pt-br} pelo limite da Rodada.{de} aufgrund der Rundenfrist aufgedeckt." or "."}),{1,0.75,0.2})
	return true
end

apocalypseIsHereRevealNextHorseman=function(tile,forced)
	if apocalypseIsHereActive()~=true or gStates.apocalypseHereHorsemenEnded==true or tile==nil then return false end
	local index=tonumber(gStates.apocalypseHereNextHorseman) or 1
	local name=(gStates.apocalypseHereHorsemanOrder or {})[index]
	local data=name~=nil and horsemanData[name] or nil
	local state=name~=nil and gStates.horsemen[name] or nil
	if data==nil or state==nil or state.revealPending==true or state.revealed==true then return false end

	--Reserve the reveal so rapid exploration may reserve the next Horseman too. If physical deployment
	--fails, the reservation and any forced-reveal count are rolled back rather than silently consuming it.
	local tileGUID=tile.guid
	state.revealPending=true
	state.revealForced=forced==true
	state.revealIndex=index
	state.retired=false
	state.terrainGUID=tileGUID
	state.bearing="center"
	state.revealTileGUID=tileGUID
	state.revealCount=gStates.apocalypseHereTilesRevealed
	if forced==true then
		gStates.apocalypseHereForcedRevealCount=math.max(0,(tonumber(gStates.apocalypseHereForcedRevealCount) or 1)-1)
		gStates.apocalypseHereForcedRevealPending=gStates.apocalypseHereForcedRevealCount>0
		if gStates.preEndTurn==true and mainUIUpdate~=nil then mainUIUpdate("Horseman exploration reserved") end
	end
	apocalypseIsHereRecomputeNextHorseman()

	local deployed=false
	local function deploy()
		if deployed==true then return end
		deployed=true
		apocalypseIsHereDeployReservedHorseman(name)
	end
	if workingOnTerrain~=nil and workingOnTerrain[tileGUID]==true then
		--Do not time this out: the Horseman must remain the final arrival even on a slow machine.
		safeWaitCondition("Scenario",deploy,function() return workingOnTerrain[tileGUID]~=true end)
	else
		deploy()
	end
	return true
end

function apocalypseIsHereRoundStart()
	if apocalypseIsHereActive()~=true then return false end
	apocalypseIsHerePositionRoundOrderToken()
	local round=tonumber(gStates.currentRound) or 1
	if gStates.apocalypseHereForcedRevealCheckedRound==round then return false end
	gStates.apocalypseHereForcedRevealCheckedRound=round
	if round<2 or round>5 or gStates.apocalypseHereHorsemenEnded==true then return false end
	local deadlineIndex=round-1
	local nextIndex=tonumber(gStates.apocalypseHereNextHorseman) or 1
	if nextIndex>deadlineIndex then return false end
	gStates.apocalypseHereForcedRevealCount=deadlineIndex-nextIndex+1
	gStates.apocalypseHereForcedRevealPending=true
	local chooser=apocalypseDragonChoicePlayerIndex~=nil and apocalypseDragonChoicePlayerIndex() or nil
	broadcastToAll(joinLang({"{en}A Horseman reveal deadline has been reached. Reveal the top Map tile and place it in a legal position as far as possible from every Mage Knight. {ru}Наступил срок раскрытия Всадника. Откройте верхнюю плитку карты и разместите её в допустимом месте как можно дальше от всех Рыцарей-магов. {zh-tw}已到騎士揭示期限。揭示最上方地圖板塊，並合法放置在距所有魔法騎士盡可能遠的位置。{zh-cn}已到骑士揭示期限。揭示最上方地图板块，并合法放置在距所有魔法骑士尽可能远的位置。{ko}기사 공개 기한에 도달했습니다. 맨 위 지도 타일을 공개하고 모든 마법 기사에게서 가능한 한 멀리 떨어진 합법적인 위치에 배치하십시오. {es}Se alcanzó el límite para revelar un Jinete. Revela la loseta superior del Mapa y colócala legalmente lo más lejos posible de todos los Caballeros Mago. {fr}La limite de révélation d’un Cavalier est atteinte. Révélez la tuile de Carte supérieure et placez-la légalement aussi loin que possible de tous les Chevaliers-Mages. {pt-br}O limite para revelar um Cavaleiro foi atingido. Revele a peça de Mapa do topo e coloque-a legalmente o mais longe possível de todos os Cavaleiros-Magos. {de}Die Frist zum Aufdecken eines Reiters ist erreicht. Decke das oberste Kartenteil auf und platziere es regelkonform so weit wie möglich von allen Magierittern entfernt. ",apocalypseDragonChoicePlayerLabel(chooser),"{en} breaks a tied placement. The next placed Map tile will automatically reveal the overdue Horseman.{ru} разрешает ничью при размещении. Следующая размещённая плитка карты автоматически раскроет просроченного Всадника.{zh-tw} 負責打破放置平手。下一個放置的地圖板塊會自動揭示逾期的騎士。{zh-cn} 负责打破放置平手。下一个放置的地图板块会自动揭示逾期的骑士。{ko}이(가) 배치 동률을 결정합니다. 다음에 배치되는 지도 타일이 기한이 지난 기사를 자동으로 공개합니다.{es} decide cualquier empate de colocación. La siguiente loseta de Mapa colocada revelará automáticamente al Jinete atrasado.{fr} tranche toute égalité de placement. La prochaine tuile de Carte placée révélera automatiquement le Cavalier en retard.{pt-br} desempata qualquer colocação. A próxima peça de Mapa colocada revelará automaticamente o Cavaleiro atrasado.{de} entscheidet bei einem Gleichstand der Platzierung. Das nächste platzierte Kartenteil deckt den überfälligen Reiter automatisch auf."}),warningColor)
	return true
end

apocalypseIsHerePossessEnemy=function(enemy)
	if enemy==nil or apocalypseIsHereActive()~=true then return false end
	gStates.apocalypseHerePossessedPending=gStates.apocalypseHerePossessedPending or {}
	if gStates.apocalypseHerePossessedPending[enemy.guid]==true then return false end
	for _,enemyGUID in pairs(gStates.apocalypsePossessedEnemyByToken or {}) do if enemyGUID==enemy.guid then return false end end
	local bag=getObjectFromGUID(GUID.bag.possessed)
	if bag==nil or bag.getQuantity()==0 then return false end
	gStates.apocalypseHerePossessedPending[enemy.guid]=true
	local p=enemy.getPosition()
	local token=bag.takeObject({position={p[1],p[2]+0.35,p[3]},rotation={0,180,0},smooth=false})
	if token==nil then gStates.apocalypseHerePossessedPending[enemy.guid]=nil return false end
	gStates.apocalypsePossessedFactionByToken=gStates.apocalypsePossessedFactionByToken or {}
	gStates.apocalypsePossessedFactionByToken[token.guid]="Apoc"
	token.setDescription(enemy.guid)
	local enemyGUID=enemy.guid
	local tokenGUID=token.guid
	safeWaitFrames("Scenario",function()
		local currentToken=getObjectFromGUID(tokenGUID)
		local currentEnemy=getObjectFromGUID(enemyGUID)
		if currentToken~=nil and currentEnemy~=nil then
			currentToken.setPosition({currentEnemy.getPosition()[1],currentEnemy.getPosition()[2]+0.25,currentEnemy.getPosition()[3]})
			attachEnemy(nil,nil,"attach",currentToken,nil)
		end
		gStates.apocalypseHerePossessedPending[enemyGUID]=nil
	end,5)
	return true
end

apocalypseIsHerePossessRampagersOnTile=function(tileGUID)
	if apocalypseIsHereActive()~=true or tileGUID==nil then return end
	local hexes,mapObjects=runtimeMapHexesAndObjects()
	for _,hex in ipairs(hexes) do
		if hex.terrainGUID==tileGUID and (hex.feature=="rampaging" or hex.feature=="draconum") then
			for _,enemy in ipairs(proxyMonstersOnHex(hex,mapObjects)) do
				if gStates.rampagingMonsters~=nil and gStates.rampagingMonsters[enemy.guid]==true then apocalypseIsHerePossessEnemy(enemy) end
			end
		end
	end
end

--The destroyed City becomes Plains for the rest of Apocalypse is Here. The terrain-type mutation is
--derived from durable scenario state, so live reveal and save/load reconstruction share one path.
function apocalypseIsHereApplyDragonCityTerrainOverride()
	if apocalypseIsHereActive()~=true or gStates.apocalypseHereDragonCityRevealed~=true or gStates.apocalypseDragonLair==nil then return false end
	local key=gStates.apocalypseDragonLair.cityHexKey
	local terrainGUID,bearing=nil,nil
	if key~=nil then terrainGUID,bearing=tostring(key):match("^([^|]+)|(.+)$") end
	if terrainGUID==nil or bearing==nil then return false end
	return runtimeMapSetHexType(terrainGUID,bearing,"plains")
end

apocalypseIsHereRevealDragonCity=function(tile)
	if apocalypseIsHereActive()~=true or tile==nil or gStates.apocalypseHereDragonCityRevealed==true then return false end
	gStates.apocalypseHereDragonCityRevealed=true
	gStates.apocalypseDragonLairRevealed=true
	local tilePos=tile.getPosition()
	local tileRotation=tile.getRotation()
	local tileYaw=tileRotation.y or tileRotation[2] or 180
	local dragonRotation={0,tileYaw,180}
	local positions={
		{tilePos[1],0.97,tilePos[3]},
		(function() local xy=angleToXY(tile,"240",tilePos,tileRotation) return {xy[1],0.97,xy[2]} end)(),
		(function() local xy=angleToXY(tile,"300",tilePos,tileRotation) return {xy[1],0.97,xy[2]} end)()
	}
	local hexes={}
	for i,pos in ipairs(positions) do
		local bearing=terrainHexBearing(tile,pos)
		hexes[#hexes+1]={bearing=bearing,position=pos,formerCity=i==1}
		if bearing~=nil then
			local feature=terrainTiles[tile.guid].hexFeature[bearing] or ""
			--The three Dragon spaces ignore printed sites; printed rampaging enemies remain and become Possessed.
			if feature~="rampaging" and feature~="draconum" then
				gStates.hexOverideSave=gStates.hexOverideSave or {}
				gStates.hexOverideSave[tile.guid]=gStates.hexOverideSave[tile.guid] or {}
				gStates.hexOverideSave[tile.guid][bearing]=""
				runtimeMapSetHexFeature(tile.guid,bearing,"")
			end
		end
	end
	local target={positions[1][1],1.18,positions[1][3]}
	gStates.apocalypseDragonLair={tileGUID=tile.guid,hexes=hexes,position=target,rotation=dragonRotation,cityHexKey=tile.guid.."|"..tostring(hexes[1].bearing)}
	apocalypseIsHereApplyDragonCityTerrainOverride()
	local dragon=getObjectFromGUID(apocalypseDragon.model)
	local bag=getObjectFromGUID(GUID.bag.apocalypseDragon)
	if dragon==nil and bag~=nil then dragon=bag.takeObject({guid=apocalypseDragon.model,position=target,rotation=dragonRotation,smooth=false})
	elseif dragon~=nil then dragon.unlock() dragon.setRotationSmooth(dragonRotation,false,true) dragon.setPositionSmooth(target,false,true) end
	if dragon~=nil then apocalypseDragonLockModelWhenSettled() end
	safeWaitFrames("Scenario",function() apocalypseIsHerePossessRampagersOnTile(tile.guid) end,35)
	safeWaitFrames("Scenario",function() apocalypseIsHerePossessRampagersOnTile(tile.guid) end,75)
	broadcastToAll("{en}The second City has been destroyed by the Apocalypse Dragon. The City space is now Plains, and the Dragon has landed across the three spaces.{ru}Второй Город уничтожен Драконом Апокалипсиса. Клетка Города теперь считается Равниной, а Дракон приземлился на трёх клетках.{zh-tw}第二座城市已被末日巨龍摧毀。城市空間現在視為平原，巨龍已橫跨三個空間降落。{zh-cn}第二座城市已被末日巨龙摧毁。城市空间现在视为平原，巨龙已横跨三个空间降落。{ko}두 번째 도시가 아포칼립스 드래곤에게 파괴되었습니다. 도시 칸은 이제 평원이며 드래곤은 세 칸에 걸쳐 착륙했습니다.{es}La segunda Ciudad ha sido destruida por el Dragón del Apocalipsis. El espacio de Ciudad ahora es Llanura y el Dragón ha aterrizado ocupando tres espacios.{fr}La deuxième Cité a été détruite par le Dragon de l’Apocalypse. La case de Cité est désormais une Plaine et le Dragon a atterri sur les trois cases.{pt-br}A segunda Cidade foi destruída pelo Dragão do Apocalipse. O espaço da Cidade agora é Planície, e o Dragão pousou ocupando os três espaços.{de}Die zweite Stadt wurde vom Apokalypse-Drachen zerstört. Das Stadtfeld ist nun Ebene, und der Drache ist über drei Felder hinweg gelandet.",{1,0.75,0.2})
	return true
end

function apocalypseIsHereTerrainRevealed(tile)
	if apocalypseIsHereActive()~=true or tile==nil or tile.is_face_down==true then return false end
	local details=terrainTiles[tile.guid]
	if details==nil or details.tileType=="starting" or details.tileType=="tilePile" then return false end

	--Terrain placed as part of the initial map setup does not count as revealed terrain for
	--Horsemen. Use the persistent setup tile marker rather than timing so a slow callback cannot
	--accidentally count an opening tile after startingMapSetup has ended.
	if startingMapTiles~=nil and startingMapTiles[tile.guid]==true then return true end

	gStates.apocalypseHereRevealedTiles=gStates.apocalypseHereRevealedTiles or {}
	if gStates.apocalypseHereRevealedTiles[tile.guid]==true then return false end
	gStates.apocalypseHereRevealedTiles[tile.guid]=true
	gStates.apocalypseHereTilesRevealed=(tonumber(gStates.apocalypseHereTilesRevealed) or 0)+1
	local centerFeature=details.hexFeature~=nil and tostring(details.hexFeature.center or "") or ""
	if centerFeature:sub(1,4)=="city" then
		gStates.apocalypseHereCityTilesSeen=(tonumber(gStates.apocalypseHereCityTilesSeen) or 0)+1
		if gStates.apocalypseHereCityTilesSeen==2 then apocalypseIsHereRevealDragonCity(tile) end
	end
	if gStates.apocalypseHereHorsemenEnded==true then return true end
	local nextIndex=tonumber(gStates.apocalypseHereNextHorseman) or 1
	if nextIndex>4 then return true end
	local forced=gStates.apocalypseHereForcedRevealPending==true
	local threshold=apocalypseIsHereRevealThreshold(nextIndex)
	if forced==true or (threshold~=nil and gStates.apocalypseHereTilesRevealed>=threshold) then apocalypseIsHereRevealNextHorseman(tile,forced) end
	return true
end

apocalypseIsHereCurrentHorsemanHex=function(name,hexes)
	local state=gStates.horsemen~=nil and gStates.horsemen[name] or nil
	local data=horsemanData~=nil and horsemanData[name] or nil
	local token=data~=nil and getObjectFromGUID(data.tokenGUID) or nil
	if state==nil or token==nil then return nil end
	local terrain,bearing=terrainHexAtPosition(token.getPosition())
	if terrain~=nil and bearing~=nil then state.terrainGUID=terrain.guid state.bearing=bearing end
	local key=tostring(state.terrainGUID).."|"..tostring(state.bearing)
	for _,hex in ipairs(hexes or {}) do if runtimeMapHexKey(hex)==key then return hex end end
	return nil
end

apocalypseIsHereHorsemanTargetOptions=function(name)
	local state=gStates.horsemen~=nil and gStates.horsemen[name] or nil
	local data=horsemanData~=nil and horsemanData[name] or nil
	if state==nil or data==nil or state.defeated==true or state.retired==true then return {} end
	local hexes,mapObjects=runtimeMapHexesAndObjects()
	local startHex=apocalypseIsHereCurrentHorsemanHex(name,hexes)
	if startHex==nil then return {} end
	local distances=runtimeMapHexDistanceMap(hexes,{startHex})
	for _,priority in ipairs({"A","B","C"}) do
		local wanted={}
		for _,feature in ipairs(data.priorities[priority] or {}) do wanted[feature]=true end
		local best=nil
		local options={}
		for _,hex in ipairs(hexes) do
			local feature=hex.feature or ""
			local eligible=wanted[feature]==true and feature~="destroyed"
			if eligible and feature=="monastery" and gStates.monasteryBurned~=nil and gStates.monasteryBurned[hex.terrainGUID]==true then eligible=false end
			if eligible and (feature=="rampaging" or feature=="draconum") then
				eligible=false
				for _,enemy in ipairs(proxyMonstersOnHex(hex,mapObjects)) do
					if gStates.rampagingMonsters~=nil and gStates.rampagingMonsters[enemy.guid]==true and horsemanTokenToName[enemy.guid]==nil then eligible=true break end
				end
			end
			if eligible then
				local distance=distances[runtimeMapHexKey(hex)]
				if distance~=nil and (best==nil or distance<best) then best=distance options={{key=runtimeMapHexKey(hex),hex=hex,distance=distance,priority=priority}}
				elseif distance~=nil and distance==best then options[#options+1]={key=runtimeMapHexKey(hex),hex=hex,distance=distance,priority=priority} end
			end
		end
		if #options>0 then table.sort(options,function(a,b) return a.key<b.key end) return options,startHex,hexes,mapObjects end
	end
	return {},startHex,hexes,mapObjects
end

apocalypseIsHereHorsemanDestination=function(startHex,targetHex,hexes,horsemanName,mapObjects)
	if startHex==nil or targetHex==nil then return startHex end
	local fromTarget=runtimeMapHexDistanceMap(hexes,{targetHex})
	local current=startHex
	for _=1,2 do
		local currentDistance=fromTarget[runtimeMapHexKey(current)]
		if currentDistance==nil or currentDistance<=0 then break end
		local choices={}
		local occupied={}
		for _,obj in pairs(mapObjects or {}) do
			local other=horsemanTokenToName~=nil and horsemanTokenToName[obj.guid] or nil
			if other~=nil and other~=horsemanName then
				local pos=obj.getPosition()
				for _,candidate in ipairs(hexes) do
					local key=runtimeMapHexKey(candidate)
					if key~=nil and occupied[key]~=true then
						local dx=pos[1]-candidate.position[1]
						local dz=pos[3]-candidate.position[3]
						if (dx*dx)+(dz*dz)<1.5 then occupied[key]=true break end
					end
				end
			end
		end
		for _,candidate in ipairs(hexes) do
			if runtimeMapHexesAdjacent(current,candidate)==true and fromTarget[runtimeMapHexKey(candidate)]==currentDistance-1 and occupied[runtimeMapHexKey(candidate)]~=true then
				choices[#choices+1]=candidate
			end
		end
		--If every shortest path is occupied, preserve the normal shortest-path rule rather than stopping.
		if #choices<1 then
			for _,candidate in ipairs(hexes) do
				if runtimeMapHexesAdjacent(current,candidate)==true and fromTarget[runtimeMapHexKey(candidate)]==currentDistance-1 then choices[#choices+1]=candidate end
			end
		end
		if #choices<1 then break end
		table.sort(choices,function(a,b) return runtimeMapHexKey(a)<runtimeMapHexKey(b) end)
		current=choices[1]
	end
	return current
end

apocalypseIsHereClearChoiceButtons=function(terrainGUIDs)
	local pending=gStates~=nil and gStates.apocalypseHereHorsemanPendingChoice or nil
	local guids=terrainGUIDs or (pending~=nil and pending.terrainGUIDs) or {}
	local seen={}
	for _,terrainGUID in ipairs(guids) do
		if seen[terrainGUID]~=true then
			seen[terrainGUID]=true
			local terrain=getObjectFromGUID(terrainGUID)
			if terrain~=nil then
				local xml=terrain.UI.getXmlTable() or {}
				local changed=false
				for i=#xml,1,-1 do
					local id=xml[i].attributes~=nil and tostring(xml[i].attributes.id or "") or ""
					if id:find("ApocalypseHorsemanTarget",1,true)~=nil then table.remove(xml,i) changed=true end
				end
				if changed then if #xml>0 then terrain.UI.setXmlTable(xml) else terrain.UI.setXml("") end end
			end
		end
	end
end

local function apocalypseIsHereJoinHorsemenTurnReport(previous,line)
	previous=tostring(previous or "")
	line=tostring(line or "")
	if previous=="" then return line end
	if line=="" then return previous end
	return joinLang({previous,"<size=6>\n\n</size>",line})
end

apocalypseIsHereShowTargetChoice=function(name,options,previousReport,choicePlayerIndex)
	local oldPending=gStates.apocalypseHereHorsemanPendingChoice
	apocalypseIsHereClearChoiceButtons(oldPending~=nil and oldPending.terrainGUIDs or nil)
	local targetKeys={}
	local terrainGUIDs={}
	local terrainSeen={}
	for _,option in ipairs(options or {}) do
		local key=option~=nil and option.hex~=nil and runtimeMapHexKey(option.hex) or nil
		if key~=nil then targetKeys[#targetKeys+1]=key end
		local terrain=option~=nil and option.hex~=nil and option.hex.terrain or nil
		if terrain~=nil and terrainSeen[terrain.guid]~=true then
			terrainSeen[terrain.guid]=true
			terrainGUIDs[#terrainGUIDs+1]=terrain.guid
		end
	end
	local pending={
		name=name,
		targetKeys=targetKeys,
		terrainGUIDs=terrainGUIDs,
		playerIndex=choicePlayerIndex or apocalypseDragonChoicePlayerIndex(),
		previousReport=previousReport~=nil and previousReport or (gStates.apocalypseHereHorsemenTurnReport or "")
	}
	gStates.apocalypseHereHorsemanPendingChoice=pending
	local grouped={}
	for index,option in ipairs(options or {}) do
		local hex=option.hex
		local terrain=hex~=nil and hex.terrain or nil
		if terrain~=nil then
			local group=grouped[terrain.guid] or {terrain=terrain,xml=terrain.UI.getXmlTable() or {}}
			grouped[terrain.guid]=group
			local localPos=terrain.positionToLocal({hex.position[1],terrain.getPosition()[2],hex.position[3]})
			local tileScale=terrain.getScale()
			local scaleX=tileScale.x or tileScale[1] or 2.25
			local scaleZ=tileScale.z or tileScale[3] or 2.25
			local uiFactor=0.16/0.38
			local uiX=(localPos.x or localPos[1])*scaleX*110*uiFactor
			local uiY=(localPos.z or localPos[3])*scaleZ*110*uiFactor
			local uiDepth=-40*uiFactor
			local buttonScale=0.16
			local id=terrain.guid.."ApocalypseHorsemanTarget"..tostring(index)
			group.xml[#group.xml+1]={tag="Button",attributes={id=id,onClick="global/apocalypseIsHereHorsemanTargetSelect",onMouseDown="global/buttonClicked",onMouseUp="global/buttonClicked",height=300,width=320,color="rgba(0,0,0,0.0)",position=uiX.." "..uiY.." "..uiDepth,rotation="0 0 "..tostring(terrain.getRotation()[2] or 180),scale=buttonScale.." "..buttonScale},children={{tag="Image",attributes={image="Sliced Button/Button Object Active",type="Sliced"}},{tag="Text",attributes={font="Fonts/MKCardText",fontSize="65",alignment="MiddleCenter",resizeTextForBestFit="true",resizeTextMaxSize="65",text=joinLang({name,"\n","{en}Target{ru}Цель{zh-tw}目標{zh-cn}目标{ko}목표{es}Objetivo{fr}Cible{pt-br}Alvo{de}Ziel"})}}}}
		end
	end
	for _,group in pairs(grouped) do group.terrain.UI.setXmlTable(group.xml) end
	gStates.apocalypseHereHorsemenUIState="WaitingChoice"
	local choiceText=joinLang({name,"{en} has tied preferred targets. {ru} имеет несколько равноценных предпочтительных целей. {zh-tw} 有多個同等優先的目標。{zh-cn} 有多个同等优先的目标。{ko}에게 동률인 우선 목표가 있습니다. {es} tiene varios objetivos preferidos empatados. {fr} a plusieurs cibles prioritaires à égalité. {pt-br} tem vários alvos preferidos empatados. {de} hat mehrere gleichrangige bevorzugte Ziele. ",apocalypseDragonChoicePlayerLabel(pending.playerIndex),"{en} must choose which site it moves toward.{ru} должен выбрать, к какому месту он двинется.{zh-tw} 必須選擇它要朝哪個地點移動。{zh-cn} 必须选择它要朝哪个地点移动。{ko}이(가) 어느 장소로 이동할지 선택해야 합니다.{es} debe elegir hacia qué lugar se moverá.{fr} doit choisir vers quel site il se déplacera.{pt-br} deve escolher em direção a qual local ele se moverá.{de} muss wählen, auf welchen Ort er sich zubewegt."})
	gStates.apocalypseHereHorsemenTurnReport=apocalypseIsHereJoinHorsemenTurnReport(pending.previousReport,choiceText)
	mainUIUpdate("Horseman target choice")
	return true
end

apocalypseIsHereRefreshPendingTargetChoice=function()
	local pending=gStates.apocalypseHereHorsemanPendingChoice
	if pending==nil then return false end
	local liveOptions=apocalypseIsHereHorsemanTargetOptions(pending.name)
	local previousReport=pending.previousReport or ""
	local playerIndex=pending.playerIndex
	apocalypseIsHereClearChoiceButtons(pending.terrainGUIDs)
	if #liveOptions<1 then
		gStates.apocalypseHereHorsemanPendingChoice=nil
		gStates.apocalypseHereHorsemenUIState="Processing"
		local line=joinLang({pending.name,"{en} found no remaining preferred undestroyed target and did not move.{ru} не нашёл оставшейся предпочтительной неразрушенной цели и не двигался.{zh-tw} 找不到剩餘的優先未摧毀目標，因此沒有移動。{zh-cn} 找不到剩余的优先未摧毁目标，因此没有移动。{ko}은(는) 남아 있는 선호 미파괴 목표를 찾지 못해 이동하지 않았습니다.{es} no encontró ningún objetivo preferido sin destruir y no se movió.{fr} n’a trouvé aucune cible prioritaire non détruite et ne s’est pas déplacé.{pt-br} não encontrou nenhum alvo preferido não destruído e não se moveu.{de} fand kein verbleibendes bevorzugtes unzerstörtes Ziel und bewegte sich nicht."})
		gStates.apocalypseHereHorsemenTurnReport=apocalypseIsHereJoinHorsemenTurnReport(previousReport,line)
		safeWaitFrames("Scenario",apocalypseIsHereProcessNextHorseman,1)
		return true
	end
	if #liveOptions==1 then
		gStates.apocalypseHereHorsemenTurnReport=previousReport
		gStates.apocalypseHereHorsemanPendingChoice=nil
		gStates.apocalypseHereHorsemenUIState="Processing"
		return apocalypseIsHereResolveHorsemanTarget(pending.name,liveOptions[1])
	end
	return apocalypseIsHereShowTargetChoice(pending.name,liveOptions,previousReport,playerIndex)
end

function apocalypseIsHereHorsemanTargetSelect(player,mouseButton,id)
	if mouseButton~="-1" or apocalypseIsHereActive()~=true then return end
	local pending=gStates.apocalypseHereHorsemanPendingChoice
	if pending==nil or apocalypseDragonChoiceAuthorized(player,pending)~=true then return end
	local index=tonumber(tostring(id or ""):match("ApocalypseHorsemanTarget(%d+)$"))
	local targetKey=index~=nil and pending.targetKeys~=nil and pending.targetKeys[index] or nil
	if targetKey==nil then return end
	local liveOptions=apocalypseIsHereHorsemanTargetOptions(pending.name)
	local option=nil
	for _,candidate in ipairs(liveOptions or {}) do
		if candidate.key==targetKey then option=candidate break end
	end
	if option==nil then apocalypseIsHereRefreshPendingTargetChoice() return end
	apocalypseIsHereClearChoiceButtons(pending.terrainGUIDs)
	gStates.apocalypseHereHorsemenTurnReport=pending.previousReport or ""
	gStates.apocalypseHereHorsemanPendingChoice=nil
	gStates.apocalypseHereHorsemenUIState="Processing"
	apocalypseIsHereResolveHorsemanTarget(pending.name,option)
end

apocalypseIsHereHorsemanClearTarget=function(targetHex)
	if targetHex==nil then return false end
	local _,mapObjects=runtimeMapHexesAndObjects()
	for _,enemy in ipairs(proxyMonstersOnHex(targetHex,mapObjects)) do
		if horsemanTokenToName[enemy.guid]==nil then proxyDiscardMonster(enemy) end
	end
	return true
end

apocalypseIsHereHorsemanDestroyTarget=function(name,targetHex,afterArrange)
	local state=gStates.horsemen[name]
	local data=horsemanData[name]
	if state==nil or data==nil or targetHex==nil then return false end
	local destroyedName=proxyFeatureDisplayName(targetHex.feature)
	local action=gStates.apocalypseHereHorsemanAction
	local function failDestruction()
		local line=joinLang({name,"{en} could not destroy {ru} не смог уничтожить {zh-tw} 無法摧毀 {zh-cn} 无法摧毁 {ko}은(는) {es} no pudo destruir {fr} n’a pas pu détruire {pt-br} não conseguiu destruir {de} konnte ",destroyedName,"{en}; no Horseman or Dragon effects were applied.{ru}; эффекты Всадника и Дракона не применены.{zh-tw}；未套用騎士或巨龍效果。{zh-cn}；未应用骑士或巨龙效果。{ko}을(를) 파괴하지 못했습니다. 기사 및 드래곤 효과는 적용되지 않았습니다.{es}; no se aplicaron efectos del Jinete ni del Dragón.{fr} ; aucun effet du Cavalier ni du Dragon n’a été appliqué.{pt-br}; nenhum efeito do Cavaleiro ou do Dragão foi aplicado.{de} nicht zerstören; es wurden keine Reiter- oder Dracheneffekte angewendet."})
		gStates.apocalypseHereHorsemenTurnReport=apocalypseIsHereJoinHorsemenTurnReport(gStates.apocalypseHereHorsemenTurnReport,line)
		mainUIUpdate("Horseman action report")
		gStates.apocalypseHereHorsemanAction=nil
		if afterArrange~=nil then safeWaitFrames("Scenario",afterArrange,1) end
	end

	local destroyedToken=takeDestroyedSiteToken(targetHex.terrain,targetHex.bearing)
	if destroyedToken==nil then failDestruction() return false end
	if action~=nil then
		action.stage="destroying"
		action.destroyedTokenGUID=destroyedToken.guid
	end
	local function finished()
		if gStates.apocalypseHereHorsemanAction==action then gStates.apocalypseHereHorsemanAction=nil end
		if afterArrange~=nil then afterArrange() end
	end
	local destructionStarted=destroySite(destroyedToken,targetHex.terrain,targetHex.bearing,finished)==true
	if destructionStarted~=true then
		local bag=getObjectFromGUID(GUID.bag.destroyedSite)
		if bag~=nil and getObjectFromGUID(destroyedToken.guid)~=nil then bag.putObject(destroyedToken) end
		failDestruction()
		return false
	end

	local oldHead=tonumber(gStates.apocalypseDragonHeadLevels~=nil and gStates.apocalypseDragonHeadLevels[name] or 0) or 0
	local newHead=math.min(12,oldHead+1)
	if oldHead>0 and oldHead<12 then apocalypseDragonSetHeadLevel(name,newHead) end
	state.sitesDestroyed=(tonumber(state.sitesDestroyed) or 0)+1
	local report=nil
	if state.sitesDestroyed>=4 then
		state.retired=true state.revealed=false state.removedAfterFour=true
		local horsemanToken=getObjectFromGUID(data.tokenGUID)
		local apocBag=getObjectFromGUID(GUID.bag.apocalypseDragon)
		if horsemanToken~=nil then
			mapTokenReleaseObject(horsemanToken)
			horsemanToken.unlock()
			if apocBag~=nil then apocBag.putObject(horsemanToken) else horsemanToken.setPosition({0,-20,0}) end
		end
		monsterPugs[data.tokenGUID]=nil
		if gStates.monsterPerks~=nil then gStates.monsterPerks[data.tokenGUID]=nil end
		report=joinLang({name,"{en} destroyed {ru} уничтожил {zh-tw} 摧毀了 {zh-cn} 摧毁了 {ko}이(가) {es} destruyó {fr} a détruit {pt-br} destruiu {de} zerstörte ",destroyedName,"{en}, raising the Dragon head to level {ru}, повысив уровень головы Дракона до {zh-tw}，使巨龍頭部等級提升至 {zh-cn}，使巨龙头部等级提升至 {ko}을(를) 파괴하여 드래곤 머리 레벨을 {es}, elevando la cabeza del Dragón al nivel {fr}, faisant passer la tête du Dragon au niveau {pt-br}, elevando a cabeça do Dragão ao nível {de} und erhöhte den Drachenkopf auf Stufe ",newHead,"{en}, then left the map after destroying four sites.{ru}, а затем покинул карту после уничтожения четырёх мест.{zh-tw}，並在摧毀四個地點後離開地圖。{zh-cn}，并在摧毁四个地点后离开地图。{ko}로 올린 뒤, 네 곳을 파괴하고 지도에서 떠났습니다.{es}, y luego abandonó el mapa tras destruir cuatro lugares.{fr}, puis a quitté la carte après avoir détruit quatre sites.{pt-br}, e então deixou o mapa após destruir quatro locais.{de} und verließ danach die Karte, nachdem vier Orte zerstört worden waren."})
	elseif (tonumber(state.level) or 1)>1 then
		state.level=state.level-1
		setHorsemanLevel(name,state.level,false)
		report=joinLang({name,"{en} destroyed {ru} уничтожил {zh-tw} 摧毀了 {zh-cn} 摧毁了 {ko}이(가) {es} destruyó {fr} a détruit {pt-br} destruiu {de} zerstörte ",destroyedName,"{en}, losing a level while raising the Dragon head to level {ru}, потеряв уровень и одновременно повысив голову Дракона до уровня {zh-tw}，降低一級，同時使巨龍頭部提升至等級 {zh-cn}，降低一级，同时使巨龙头部提升至等级 {ko}을(를) 파괴해 레벨이 감소하고 드래곤 머리를 레벨 {es}, perdiendo un nivel mientras elevaba la cabeza del Dragón al nivel {fr}, perdant un niveau tout en faisant passer la tête du Dragon au niveau {pt-br}, perdendo um nível enquanto elevava a cabeça do Dragão ao nível {de} und verlor eine Stufe, während der Drachenkopf auf Stufe ",newHead,"."})
	else
		report=joinLang({name,"{en} destroyed {ru} уничтожил {zh-tw} 摧毀了 {zh-cn} 摧毁了 {ko}이(가) {es} destruyó {fr} a détruit {pt-br} destruiu {de} zerstörte ",destroyedName,"{en}, raising the Dragon head to level {ru}, повысив голову Дракона до уровня {zh-tw}，使巨龍頭部提升至等級 {zh-cn}，使巨龙头部提升至等级 {ko}을(를) 파괴해 드래곤 머리를 레벨 {es}, elevando la cabeza del Dragón al nivel {fr}, faisant passer la tête du Dragon au niveau {pt-br}, elevando a cabeça do Dragão ao nível {de} und erhöhte den Drachenkopf auf Stufe ",newHead,"."})
	end
	gStates.apocalypseHereHorsemenTurnReport=apocalypseIsHereJoinHorsemenTurnReport(gStates.apocalypseHereHorsemenTurnReport,report)
	mainUIUpdate("Horseman action report")
	if action~=nil then action.stage="settling" end
	return true
end

apocalypseIsHereHexByKey=function(key,hexes)
	if key==nil then return nil end
	for _,hex in ipairs(hexes or {}) do if runtimeMapHexKey(hex)==key then return hex end end
	return nil
end

apocalypseIsHereHorsemanMoveFinished=function(name,target,reached)
	if reached==true then
		local action=gStates.apocalypseHereHorsemanAction
		if action~=nil then action.stage="destroying" end
		apocalypseIsHereHorsemanDestroyTarget(name,target,apocalypseIsHereContinueHorsemenTurn)
	else
		local line=joinLang({name,"{en} moved two spaces toward {ru} переместился на две клетки к {zh-tw} 朝 {zh-cn} 朝 {ko}이(가) {es} se movió dos espacios hacia {fr} s’est déplacé de deux cases vers {pt-br} moveu-se dois espaços em direção a {de} bewegte sich zwei Felder in Richtung ",proxyFeatureDisplayName(target.feature),"{en}.{ru}.{zh-tw} 移動了兩格。{zh-cn} 移动了两格。{ko} 쪽으로 두 칸 이동했습니다.{es}.{fr}.{pt-br}.{de}."})
		gStates.apocalypseHereHorsemenTurnReport=apocalypseIsHereJoinHorsemenTurnReport(gStates.apocalypseHereHorsemenTurnReport,line)
		mainUIUpdate("Horseman action report")
		gStates.apocalypseHereHorsemanAction=nil
		apocalypseIsHereContinueHorsemenTurn()
	end
end

apocalypseIsHereResolveHorsemanTarget=function(name,option)
	local options,startHex,hexes,mapObjects=apocalypseIsHereHorsemanTargetOptions(name)
	local target=option~=nil and option.hex or nil
	if startHex==nil or target==nil then apocalypseIsHereContinueHorsemenTurn() return false end
	local destination=apocalypseIsHereHorsemanDestination(startHex,target,hexes,name,mapObjects)
	local data=horsemanData[name]
	local state=gStates.horsemen[name]
	local token=data~=nil and getObjectFromGUID(data.tokenGUID) or nil
	if token==nil or destination==nil then apocalypseIsHereContinueHorsemenTurn() return false end
	state.terrainGUID=destination.terrainGUID state.bearing=destination.bearing
	local reached=runtimeMapHexKey(destination)==runtimeMapHexKey(target)
	gStates.apocalypseHereHorsemanAction={
		name=name,
		targetKey=runtimeMapHexKey(target),
		destinationKey=runtimeMapHexKey(destination),
		reached=reached,
		stage="moving"
	}
	local started=mapTokenSettleArrival(token.guid,{destination.position[1],1.42,destination.position[3]},
		{releaseOrigin=true,rotation={0,180,0},deferArrange=reached},function()
			apocalypseIsHereHorsemanMoveFinished(name,target,reached)
		end)
	if started~=true then
		gStates.apocalypseHereHorsemanAction=nil
		apocalypseIsHereContinueHorsemenTurn()
		return false
	end
	if reached then apocalypseIsHereHorsemanClearTarget(target) end
	return true
end

apocalypseIsHereProcessNextHorseman=function()
	if gStates.apocalypseHereHorsemenTurnActive~=true then return end
	local queue=gStates.apocalypseHereHorsemenQueue or {}
	local index=tonumber(gStates.apocalypseHereHorsemenQueueIndex) or 1
	local name=queue[index]
	if name==nil then
		gStates.apocalypseHereHorsemenUIState="ReadyToEnd"
		if (gStates.apocalypseHereHorsemenTurnReport or "")=="" then
			gStates.apocalypseHereHorsemenTurnReport="{en}The Horsemen had no action to resolve.{ru}У Всадников не было действий для разрешения.{zh-tw}騎士沒有需要處理的行動。{zh-cn}骑士没有需要处理的行动。{ko}기사들이 처리할 행동이 없습니다.{es}Los Jinetes no tenían ninguna acción que resolver.{fr}Les Cavaliers n’avaient aucune action à résoudre.{pt-br}Os Cavaleiros não tinham nenhuma ação para resolver.{de}Die Reiter hatten keine Aktion auszuführen."
		end
		mainUIUpdate("Horsemen Processed")
		return
	end
	gStates.apocalypseHereHorsemenQueueIndex=index+1
	local options=apocalypseIsHereHorsemanTargetOptions(name)
	if #options<1 then
		local line=joinLang({name,"{en} found no preferred undestroyed target and did not move.{ru} не нашёл предпочтительной неразрушенной цели и не двигался.{zh-tw} 找不到優先的未摧毀目標，因此沒有移動。{zh-cn} 找不到优先的未摧毁目标，因此没有移动。{ko}은(는) 선호하는 미파괴 목표를 찾지 못해 이동하지 않았습니다.{es} no encontró ningún objetivo preferido sin destruir y no se movió.{fr} n’a trouvé aucune cible prioritaire non détruite et ne s’est pas déplacé.{pt-br} não encontrou nenhum alvo preferido não destruído e não se moveu.{de} fand kein bevorzugtes unzerstörtes Ziel und bewegte sich nicht."})
		gStates.apocalypseHereHorsemenTurnReport=apocalypseIsHereJoinHorsemenTurnReport(gStates.apocalypseHereHorsemenTurnReport,line)
		mainUIUpdate("Horseman action report")
		safeWaitFrames("Scenario",apocalypseIsHereProcessNextHorseman,1)
	elseif #options>1 then apocalypseIsHereShowTargetChoice(name,options)
	else apocalypseIsHereResolveHorsemanTarget(name,options[1]) end
end

apocalypseIsHereContinueHorsemenTurn=function()
	if gStates.apocalypseHereHorsemenTurnActive~=true then return end
	gStates.apocalypseHereHorsemenUIState="Processing"
	safeWaitFrames("Scenario",apocalypseIsHereProcessNextHorseman,2)
end

apocalypseIsHereActiveHorsemen=function()
	local list={}
	for _,name in ipairs(gStates.apocalypseHereHorsemanOrder or {}) do
		local state=gStates.horsemen~=nil and gStates.horsemen[name] or nil
		local data=horsemanData~=nil and horsemanData[name] or nil
		if state~=nil and data~=nil and state.revealed==true and state.defeated~=true and state.retired~=true and getObjectFromGUID(data.tokenGUID)~=nil then list[#list+1]=name end
	end
	return list
end

local function apocalypseIsHereHorsemenTurnDescription()
	local queue=gStates.apocalypseHereHorsemenQueue or {}
	local parts={}
	for index,name in ipairs(queue) do
		if index>1 then parts[#parts+1]=", " end
		parts[#parts+1]=translateWord[name] or name
	end
	local roster=#parts>0 and joinLang(parts) or joinLang({"{en}None{ru}Нет{zh-tw}無{zh-cn}无{ko}없음{es}Ninguno{fr}Aucun{pt-br}Nenhum{de}Keine"})
	local heading=joinLang({"{en}Horsemen acting this turn: {ru}Всадники, действующие в этот ход: {zh-tw}本回合行動的騎士：{zh-cn}本回合行动的骑士：{ko}이번 턴에 행동하는 기사: {es}Jinetes que actúan este turno: {fr}Cavaliers agissant ce tour : {pt-br}Cavaleiros agindo neste turno: {de}In diesem Zug handelnde Reiter: ",roster})
	local report=gStates.apocalypseHereHorsemenTurnReport or ""
	if report=="" then return heading end
	return apocalypseIsHereJoinHorsemenTurnReport(heading,report)
end

function apocalypseIsHereBeginHorsemenTurn(nextTurnNumber,newOutOfTurn,sameTurn)
	if apocalypseIsHereActive()~=true or gStates.apocalypseHereHorsemenEnded==true or gStates.apocalypseDragonLairAttacked==true then return false end
	if gStates.endRoundCalled==true or gStates.endGameAchieved~="false" or gStates.tacticShown==true then return false end
	local queue=apocalypseIsHereActiveHorsemen()
	if #queue<1 then return false end
	gStates.apocalypseHereHorsemenTurnActive=true
	gStates.apocalypseHereHorsemenResumeTurn={turnNumber=nextTurnNumber,newOutOfTurn=newOutOfTurn,sameTurn=sameTurn}
	gStates.apocalypseHereHorsemenQueue=queue
	gStates.apocalypseHereHorsemenQueueIndex=1
	gStates.apocalypseHereHorsemanAction=nil
	gStates.apocalypseHereHorsemenTurnReport="{en}The Horsemen act in the order they were revealed.{ru}Всадники действуют в порядке их раскрытия.{zh-tw}騎士依照揭示順序行動。{zh-cn}骑士依照揭示顺序行动。{ko}기사들은 공개된 순서대로 행동합니다.{es}Los Jinetes actúan en el orden en que fueron revelados.{fr}Les Cavaliers agissent dans l’ordre où ils ont été révélés.{pt-br}Os Cavaleiros agem na ordem em que foram revelados.{de}Die Reiter handeln in der Reihenfolge, in der sie aufgedeckt wurden."
	gStates.apocalypseHereHorsemenUIState="ReadyToProcess"
	mainUIUpdate("Horsemen Turn")
	return true
end

function apocalypseIsHereMainUIPanelSpec()
	if apocalypseIsHereActive()~=true or gStates.apocalypseHereHorsemenTurnActive~=true then return nil end
	local state=gStates.apocalypseHereHorsemenUIState
	local label="{en}Processing Horsemen...{ru}Обработка Всадников...{zh-tw}正在處理騎士…{zh-cn}正在处理骑士…{ko}기사 처리 중...{es}Procesando Jinetes...{fr}Traitement des Cavaliers...{pt-br}Processando Cavaleiros...{de}Reiter werden verarbeitet..."
	local active=false
	if state=="ReadyToProcess" then
		label="{en}Process Horsemen{ru}Обработать Всадников{zh-tw}處理騎士{zh-cn}处理骑士{ko}기사 처리{es}Procesar Jinetes{fr}Traiter les Cavaliers{pt-br}Processar Cavaleiros{de}Reiter verarbeiten"
		active=true
	elseif state=="ReadyToEnd" then
		label="{en}Horsemen Processed{ru}Всадники обработаны{zh-tw}騎士處理完成{zh-cn}骑士处理完成{ko}기사 처리 완료{es}Jinetes Procesados{fr}Cavaliers traités{pt-br}Cavaleiros processados{de}Reiter verarbeitet"
		active=true
	elseif state=="WaitingChoice" then
		label="{en}Pick Target{ru}Выбрать цель{zh-tw}選擇目標{zh-cn}选择目标{ko}목표 선택{es}Elegir objetivo{fr}Choisir la cible{pt-br}Escolher alvo{de}Ziel wählen"
	end
	return {actor="horsemen",mainText="{en}<size=25>Horsemen's Turn</size>{ru}<size=25>Ход Всадников</size>{zh-tw}<size=25>騎士回合</size>{zh-cn}<size=25>骑士回合</size>{ko}<size=25>기사들의 턴</size>{es}<size=25>Turno de los Jinetes</size>{fr}<size=25>Tour des Cavaliers</size>{pt-br}<size=25>Turno dos Cavaleiros</size>{de}<size=25>Zug der Reiter</size>",notes=apocalypseIsHereHorsemenTurnDescription(),onClick="apocalypseIsHereProcessHorsemenUI",label=label,interactable=active}
end

apocalypseIsHereMainUIRefresh=function()
	local spec=apocalypseIsHereMainUIPanelSpec()
	if spec==nil then return false end
	return automatedMainPanelApply(spec)
end

function apocalypseIsHereProcessHorsemenUI(player,mouseButton,id)
	if mouseButton~="-1" or apocalypseIsHereActive()~=true or gStates.apocalypseHereHorsemenTurnActive~=true then return end
	if gStates.apocalypseHereHorsemenUIState=="ReadyToEnd" then apocalypseIsHereFinishHorsemenTurn() return end
	if gStates.apocalypseHereHorsemenUIState~="ReadyToProcess" then return end
	gStates.apocalypseHereHorsemenUIState="Processing"
	gStates.apocalypseHereHorsemenTurnReport=""
	apocalypseIsHereProcessNextHorseman()
end

apocalypseIsHereFinishHorsemenTurn=function()
	if gStates.apocalypseHereHorsemenTurnActive~=true then return false end
	local pending=gStates.apocalypseHereHorsemanPendingChoice
	apocalypseIsHereClearChoiceButtons(pending~=nil and pending.terrainGUIDs or nil)
	UI.setAttribute("DummyTurn","active","false")
	local resume=gStates.apocalypseHereHorsemenResumeTurn
	gStates.apocalypseHereHorsemenTurnActive=false
	gStates.apocalypseHereHorsemenResumeTurn=nil
	gStates.apocalypseHereHorsemanPendingChoice=nil
	gStates.apocalypseHereHorsemanAction=nil
	gStates.apocalypseHereHorsemenUIState=nil
	if resume~=nil then mergedTurnCommit(resume.turnNumber,resume.newOutOfTurn,resume.sameTurn) end
	return true
end


function apocalypseIsHereRestoreScenarioState()
	if apocalypseIsHereActive()~=true then return false end

	--Reveal callbacks are not serialized. Resume any successfully reserved reveal from its persisted tile;
	--failed physical deployment rolls the reservation back through the normal reveal path.
	for _,name in ipairs(gStates.apocalypseHereHorsemanOrder or {}) do
		local reservedName=name
		local state=gStates.horsemen~=nil and gStates.horsemen[reservedName] or nil
		if state~=nil and state.revealPending==true then
			local tile=state.revealTileGUID~=nil and getObjectFromGUID(state.revealTileGUID) or nil
			if tile~=nil and workingOnTerrain~=nil and workingOnTerrain[tile.guid]==true then
				local tileGUID=tile.guid
				safeWaitCondition("Scenario",function() apocalypseIsHereDeployReservedHorseman(reservedName) end,function() return workingOnTerrain[tileGUID]~=true end)
			else
				apocalypseIsHereDeployReservedHorseman(reservedName)
			end
		end
	end
	apocalypseIsHereRecomputeNextHorseman()

	if gStates.apocalypseHereHorsemenTurnActive~=true then return true end
	local pending=gStates.apocalypseHereHorsemanPendingChoice
	if pending~=nil or gStates.apocalypseHereHorsemenUIState=="WaitingChoice" then
		if pending~=nil then apocalypseIsHereRefreshPendingTargetChoice()
		else
			gStates.apocalypseHereHorsemenUIState="Processing"
			safeWaitFrames("Scenario",apocalypseIsHereProcessNextHorseman,1)
		end
		return true
	end

	local action=gStates.apocalypseHereHorsemanAction
	if action~=nil then
		local snapshot=runtimeMapSnapshot()
		local hexes=snapshot.hexes or {}
		local destination=apocalypseIsHereHexByKey(action.destinationKey,hexes)
		local target=apocalypseIsHereHexByKey(action.targetKey,hexes)
		local state=gStates.horsemen~=nil and gStates.horsemen[action.name] or nil
		local data=horsemanData~=nil and horsemanData[action.name] or nil
		local token=data~=nil and getObjectFromGUID(data.tokenGUID) or nil
		if action.stage=="settling" then
			local destroyed=action.destroyedTokenGUID~=nil and getObjectFromGUID(action.destroyedTokenGUID) or nil
			if destroyed~=nil and target~=nil then
				arrangeDestroyedSiteHex(destroyed,target.terrain,target.bearing,function()
					if gStates.apocalypseHereHorsemanAction==action then gStates.apocalypseHereHorsemanAction=nil end
					apocalypseIsHereContinueHorsemenTurn()
				end)
			else
				gStates.apocalypseHereHorsemanAction=nil
				apocalypseIsHereContinueHorsemenTurn()
			end
			return true
		end
		if token~=nil and state~=nil and destination~=nil and target~=nil then
			state.terrainGUID=destination.terrainGUID
			state.bearing=destination.bearing
			action.stage="moving"
			local started=mapTokenSettleArrival(token.guid,{destination.position[1],1.42,destination.position[3]},
				{force=true,rotation={0,180,0},deferArrange=action.reached==true},function()
					apocalypseIsHereHorsemanMoveFinished(action.name,target,action.reached==true)
				end)
			if started==true then return true end
		end
		gStates.apocalypseHereHorsemanAction=nil
	end

	if gStates.apocalypseHereHorsemenUIState=="Processing" then
		safeWaitFrames("Scenario",apocalypseIsHereProcessNextHorseman,1)
	else
		mainUIUpdate("Horsemen Turn Restored")
	end
	return true
end

function apocalypseIsHereEndHorsemen()
	if apocalypseIsHereActive()~=true or gStates.apocalypseHereHorsemenEnded==true then return false end
	gStates.apocalypseHereHorsemenEnded=true
	gStates.apocalypseHereForcedRevealPending=false
	gStates.apocalypseHereForcedRevealCount=0
	apocalypseIsHereClearChoiceButtons()
	local bag=getObjectFromGUID(GUID.bag.apocalypseDragon)
	for name,state in pairs(gStates.horsemen or {}) do
		if state.defeated~=true then
			state.retired=true state.removedByDragon=true state.revealed=false
			local data=horsemanData[name]
			local token=data~=nil and getObjectFromGUID(data.tokenGUID) or nil
			if token~=nil then token.unlock() if bag~=nil then bag.putObject(token) else token.setPosition({0,-20,0}) end end
			if data~=nil then monsterPugs[data.tokenGUID]=nil if gStates.monsterPerks~=nil then gStates.monsterPerks[data.tokenGUID]=nil end end
		end
	end
	broadcastToAll("{en}The Apocalypse Dragon has been attacked. Every Horseman still on the map is removed; this does not count as defeating them.{ru}Дракон Апокалипсиса атакован. Все Всадники, оставшиеся на карте, удаляются; это не считается их победой.{zh-tw}末日巨龍已被攻擊。地圖上所有剩餘騎士都被移除；這不算擊敗他們。{zh-cn}末日巨龙已被攻击。地图上所有剩余骑士都被移除；这不算击败他们。{ko}아포칼립스 드래곤이 공격받았습니다. 맵에 남은 모든 기수를 제거합니다. 이들은 처치한 것으로 계산하지 않습니다.{es}El Dragón del Apocalipsis ha sido atacado. Retira a todos los Jinetes que sigan en el mapa; esto no cuenta como derrotarlos.{fr}Le Dragon de l’Apocalypse a été attaqué. Retirez tous les Cavaliers encore présents sur la carte ; cela ne compte pas comme les avoir vaincus.{pt-br}O Dragão do Apocalipse foi atacado. Remova todos os Cavaleiros que ainda estiverem no mapa; isso não conta como derrotá-los.{de}Der Apokalypse-Drache wurde angegriffen. Alle noch auf der Karte befindlichen Reiter werden entfernt; dies zählt nicht als Besiegen.",{1,0.75,0.2})
	return true
end

function apocalypseIsHereDragonCitySpacePlayer(playerIndex)
	if apocalypseIsHereActive()~=true or gStates.apocalypseDragonLair==nil then return false end
	local player=turnOrder[playerIndex]
	if player==nil then return false end
	local pos=fracturedLandsTeleportSourcePosition~=nil and fracturedLandsTeleportSourcePosition(playerIndex) or nil
	if pos==nil then local avatar=coopAssaultAvatarObject(playerIndex) if avatar~=nil then pos=avatar.getPosition() end end
	if pos==nil then return false end
	for _,hex in ipairs(gStates.apocalypseDragonLair.hexes or {}) do
		if hex.formerCity==true and hex.position~=nil and ((pos[1]-hex.position[1])^2)+((pos[3]-hex.position[3])^2)<2.25 then return true end
	end
	return false
end

function volkarePursuitAction(playerDud,mouseButton,id)
	if mouseButton~="-1" then return end
	local mage=id:match("|(.+)$")
	local playerIndex=nil
	for index,details in pairs(turnOrder) do if details.mage==mage then playerIndex=index break end end
	if playerIndex==nil or playerIndex~=gStates.turnNumber then return end
	if playerDud~=nil and playerDud.color~=nil and legalPlayerCheck(playerDud.color,turnOrder[playerIndex].seatPos)~=true then return end
	local info=volkarePursuitActionInfo(playerIndex)
	if info==nil then gStates.volkarePursuitChoicePlayer=nil addAvatarButtons() return end
	if id:sub(1,12)=="VPursuitOpen" then gStates.volkarePursuitChoicePlayer=playerIndex addAvatarButtons() return end
	local choice=id:match("^VPursuit([^|]+)")
	if choice~="Green" and choice~="Red" and choice~="Both" then return end
	gStates.volkarePursuitChoicePlayer=nil
	gStates.volkarePursuitCombat={player=playerIndex,hexKey=info.key,position=info.position,monsters={}}
	if gStates.volkarePursuitEnemies==nil then gStates.volkarePursuitEnemies={} end
	combatCameraChoiceSuppressedPlayer=nil
	turnOrder[playerIndex].combatIconHide="Avatar"
	gStates.monsterOffsetX=0 gStates.monsterOffsetZ=0
	if choice=="Green" or choice=="Both" then drawMonster(monsterPiles.green,turnOrder[playerIndex],"VPDraw|Green") end
	if choice=="Red" or choice=="Both" then local delay=choice=="Both" and 7 or 0 safeWaitFrames("Scenario",function() drawMonster(monsterPiles.red,turnOrder[playerIndex],"VPDraw|Red") end,delay) end
	broadcastToAll(joinLang({translateWord[turnOrder[playerIndex].mage],"{en} pursues Volkare's fleeing army.{ru} преследует отступающую армию Волкара.{zh-tw}追击沃卡里的溃军。{zh-cn}追击沃卡里的溃军。{ko}: 볼케어의 패주하는 군대를 추격합니다.{es} persigue al ejército en fuga de Volkare.{fr} poursuit l'armée de Volkare en fuite.{pt-br} persegue o exército em fuga de Volkare.{de} verfolgt Volkares fliehende Armee."}),positionToColor(playerIndex))
	addAvatarButtons()
end

--Druid Nights Incantation is legal anywhere the Mage Knight cannot Interact with Locals.
--Use the map's interaction helper first so burned Monasteries and conquered/unconquered sites resolve correctly;
--the logical-location fallback also covers Portal/City parking where the physical avatar may be off the map.

function druidNightsCanIncantHere(playerIndex)
	local player=turnOrder[playerIndex]
	if player==nil or gStates.gameScenario~="Druid Nights" then return false end
	local hexes,mapObjects=runtimeMapHexesAndObjects()
	local hex=apocalypseQuestPlayerHex(hexes,mapObjects,playerIndex)
	if hex~=nil then return apocalypseQuestHexInteractionSite(hex,mapObjects,playerIndex)~=true end
	local location=string.lower(tostring(player.avatarLocation or ""))
	if location=="village" or location=="monastery" or location=="keep" or location=="mage tower" or location=="camp" or location=="oasis" or location=="volkare's camp" or location:sub(1,4)=="city" then return false end
	return true
end

--Druid Nights Ritual is a separate combat action from a site attack. Keep it out of attackLocation
--so a legal site defender cannot intercept or add its assault side effects to the Incantation.
function druidNightsRitualAction(playerDud, mouseButton, id)
	if mouseButton~="-1" then return end
	local mage=tostring(id or ""):match("^Incant(.+)$")
	if mage==nil then return end
	local playerIndex=nil
	for index, details in pairs(turnOrder) do if details.mage==mage then playerIndex=index break end end
	if playerIndex==nil or playerIndex~=gStates.turnNumber then return end
	local player=turnOrder[playerIndex]
	if player==nil or gStates.gameScenario~="Druid Nights" or gStates.dayRound~=false or player.combatIconHide~="None" or player.gladesMarked==nil or #player.gladesMarked<1 or player.druidNightsLastRitualRound==gStates.currentRound or druidNightsCanIncantHere(playerIndex)~=true then return end
	local turnToken=getObjectFromGUID(player.turnOrderTokenGUID)
	if turnToken==nil or turnToken.is_face_down==true then return end
	if playerDud~=nil and playerDud.color~=nil and legalPlayerCheck(playerDud.color,player.seatPos)~=true then return end

	combatCameraChoiceSuppressedPlayer=nil
	gStates.monsterOffsetX=0
	gStates.monsterOffsetZ=0
	player.combatIconHide="Both"
	player.druidNightsLastRitualRound=gStates.currentRound
	player.druidNightsRitualCount=(player.druidNightsRitualCount or 0)+1
	broadcastToAll("{en}Performed Incantation to summon Monster(s) to your Player Board{ru}Прочтено заклинание, чтобы призвать Монстра(ов) на вашу игровую доску.{zh-tw}执行了咒语召唤怪物到你的玩家板{zh-cn}执行了咒语召唤怪物到你的玩家板{ko}주문을 시전하여 몬스터를 소환합니다{es}Encantamiento realizado para convocar Monstruos a tu Tablero de Jugador{fr}Incantation exécutée pour invoquer des monstres sur votre plateau de joueur{pt-br}Realizou um Encantamento para invocar Monstro(S) para seu Tabuleiro de Jogador{de}Beschwörung durchgeführt, um Monster auf dein Spielerbrett zu beschwören", positionToColor(playerIndex))
	if gStates.currentRound==gStates.rounds then player.druidNightsFinalRitual=true end
	local ritualCount=#player.gladesMarked
	local crystalMultiple=gStates.currentRound>=5 and 3 or (gStates.currentRound>=3 and 2 or 1)
	gStates.druidNightsSummon=ritualCount
	gStates.druidNightsCrystalReward=ritualCount*crystalMultiple
	local monsterSummoned=gStates.currentRound>=3 and monsterPiles.red or monsterPiles.tan
	for _=1, ritualCount do safeWaitFrames("Scenario",function() drawMonster(monsterSummoned,player,id) end,10) end
	if gStates.currentRound>=5 then
		for _=1, ritualCount do safeWaitFrames("Scenario",function() drawMonster(monsterPiles.tan,player,id) end,10) end
	end
	--Activated Glade shields remain on the map until the end of the Night; round reset removes them.
	addAvatarButtons()
end

--Draw a Destroyed Site beside its Infinite Bag. destroySite()/arrangeDestroyedSiteHex() owns the
--visible smooth move to the target hex, so every scripted destruction follows the same placement path.
takeDestroyedSiteToken=function(terrain,bearing)
	if terrain==nil or bearing==nil then return nil end
	local bag=getObjectFromGUID(GUID.bag.destroyedSite)
	local center=angleToXY(terrain,bearing)
	if bag==nil or center==nil then return nil end
	local bagPos=bag.getPosition()
	return bag.takeObject({position={bagPos[1],bagPos[2]+2,bagPos[3]},rotation={0,180,0},smooth=false})
end

--A Destroyed Site is always slot 1. Smooth it to its measured resting origin at Y 1.13; after it
--settles, the shared arranger can apply the tiny X/Z separation and place any enemies above it.
arrangeDestroyedSiteHex=function(token,terrain,bearing,afterArrange)
	if token==nil or terrain==nil or bearing==nil then return false end
	local center=angleToXY(terrain,bearing)
	if center==nil then return false end

	--Move the token visibly above the destination and leave it unlocked. TTS gravity performs the
	--actual drop onto the hex; once it rests, MapTokens' normal separator owns the bottom slot.
	token.unlock()
	local started=mapTokenSettleArrival(token.guid,{center[1],2.0,center[2]},{
		force=true,
		rotation={0,180,0}
	},function()
		if afterArrange~=nil then afterArrange() end
	end)
	return started==true
end

function destroySite(token,terrain,bearing,afterArrange)
	if token==nil or terrain==nil or bearing==nil or terrainTiles[terrain.guid]==nil then return false end
	local feature=terrainTiles[terrain.guid].hexFeature[bearing]
	if feature==nil or feature=="" or feature=="portal" or feature=="destroyed" or feature:sub(1,7)=="raised " then return false end
	if arrangeDestroyedSiteHex(token,terrain,bearing,afterArrange)~=true then return false end
	if gStates.destroyedSites==nil then gStates.destroyedSites={} end
	gStates.destroyedSites[token.guid]={hexFeature=feature, terrainTile=terrain.guid, hexAngle=bearing}
	runtimeMapSetHexFeature(terrain.guid,bearing,"destroyed")
	if gStates.hexOverideSave[terrain.guid]==nil then gStates.hexOverideSave[terrain.guid]={} end
	gStates.hexOverideSave[terrain.guid][bearing]="destroyed"
	broadcastToAll(joinLang({feature,"{en} Destroyed{ru} уничтожено{zh-tw} 已摧毀{zh-cn} 已摧毁{ko} 파괴됨{es} Destruido{fr} Détruit{pt-br} Destruído{de} zerstört"}))
	safeWaitFrames("Scenario",function() apocalypseQuestRefreshOfferButtons() end,2)
	return true
end

function undoDestroyedSitePlacement(destroyed)
	if destroyed==nil or gStates.destroyedSites==nil then return false end
	local data=gStates.destroyedSites[destroyed.guid]
	if data==nil or terrainTiles[data.terrainTile]==nil then return false end
	runtimeMapSetHexFeature(data.terrainTile,data.hexAngle,data.hexFeature)
	if gStates.hexOverideSave[data.terrainTile]~=nil then gStates.hexOverideSave[data.terrainTile][data.hexAngle]=nil end
	gStates.destroyedSites[destroyed.guid]=nil
	safeWaitFrames("Scenario",function() apocalypseQuestRefreshOfferButtons() end, 2)
	return true
end

--Against the Apocalypse keeps its completion rule in one place so both combat cleanup and
--non-combat site restoration can finish the scenario through the same objective test.
againstApocalypseObjectivesComplete=function()
	if gStates==nil or gStates.gameScenario~="Against the Apocalypse Blitz" then return false end
	local map=getObjectFromGUID(mapArea)
	if map==nil then return false end

	local objectsInPlay=map.getObjects()
	table.sort(objectsInPlay,function(a,b) return a.getPosition()[2]>b.getPosition()[2] end)
	local floorCount=0
	local clearedSites={}
	for _,obj in pairs(objectsInPlay) do
		if obj.getName()=="Shield" and volkarePursuitShieldRegistered(obj)~=true then
			local terrain,_,_,feature=terrainHexAtPosition(obj.getPosition(),objectsInPlay)
			if terrain~=nil and (feature=="ziggurat" or feature=="pyramid") then
				floorCount=floorCount+1
				clearedSites[terrain.guid]=true
			end
		end
	end

	local clearedSiteCount=0
	for _ in pairs(clearedSites) do clearedSiteCount=clearedSiteCount+1 end

	local restoredCount=0
	for _,zoneGUID in ipairs({"13f39d","5bb87a","621d88","2936ad"}) do
		local zone=getObjectFromGUID(zoneGUID)
		if zone~=nil then
			for _,token in pairs(zone.getObjects()) do
				if token.getGMNotes()=="Destroyed" then restoredCount=restoredCount+1 end
			end
		end
	end

	local playerCount=tonumber(gStates.playerCount) or 1
	local sitesRequired=playerCount==1 and 2 or 3
	local progressRequired=playerCount+1
	if gStates.coop==1 and playerCount>1 then progressRequired=playerCount+2 end
	return clearedSiteCount==sitesRequired and floorCount>=progressRequired and restoredCount>=progressRequired
end

againstApocalypseCheckCompletion=function()
	if gStates==nil or gStates.gameScenario~="Against the Apocalypse Blitz" or gStates.endGameAchieved~="false" or gStates.tacticShown==true then return false end
	if againstApocalypseObjectivesComplete()~=true then return false end
	if gStates.coopAssaultPhase=="combat" then gStates.coopAssaultScenarioEndPending=true else markScenarioEndAchieved() end
	return true
end

--Only the Possessed token placed by this scenario's terrain-destruction roll grants Destroyed Site
--tokens. Quest and other Possessed enemies deliberately remain unmarked.
againstApocalypseMarkPossessedRampager=function(possessed)
	if possessed==nil then return false end
	gStates.againstApocalypseRampagerPossessedTokens=gStates.againstApocalypseRampagerPossessedTokens or {}
	gStates.againstApocalypseRampagerPossessedTokens[possessed.guid]=true
	return true
end

function againstApocalypseRampagerDestroyedSiteRewards(enemy)
	if gStates==nil or gStates.gameScenario~="Against the Apocalypse Blitz" or enemy==nil then return 0 end
	local marked=gStates.againstApocalypseRampagerPossessedTokens
	if marked==nil then return 0 end
	for _,attachment in ipairs(enemy.getAttachments() or {}) do
		if marked[attachment.guid]==true then
			marked[attachment.guid]=nil
			if next(marked)==nil then gStates.againstApocalypseRampagerPossessedTokens=nil end
			local details=monsterPugs~=nil and monsterPugs[enemy.guid] or nil
			if details~=nil and details.pugType=="red" then return 2 end
			if details~=nil and details.pugType=="green" then return 1 end
			return 0
		end
	end
	return 0
end

restoreDestroyedSite=function(destroyed, player)
	if destroyed==nil or player==nil or gStates.destroyedSites==nil then return false end
	local data=gStates.destroyedSites[destroyed.guid]
	if data==nil or terrainTiles[data.terrainTile]==nil then return false end
	broadcastToAll("{en}Site Restored{ru}Место восстановлено{zh-tw}地點已恢復{zh-cn}地点已恢复{ko}장소 복구됨{es}Lugar Restaurado{fr}Site Restauré{pt-br}Local Restaurado{de}Ort wiederhergestellt")
	if data.hexFeature=="keep" or data.hexFeature=="mage tower" then
		dropShield({destroyed.getPosition()[1], 2, destroyed.getPosition()[3]}, true)
		player.fameGain=player.fameGain+1
		broadcastToAll("{en}and Fame Gained{ru}и получена Слава{zh-tw}並獲得聲望值{zh-cn}并获得声望值{ko}및 명성 획득{es}y Fama Ganada{fr}et Renommée Gagnée{pt-br}e Fama Ganha{de}und Ruhm erhalten")
	end
	if data.hexFeature=="monastery" then handleMonasteryRevealed() end
	if data.hexFeature=="village" or data.hexFeature=="oasis" or data.hexFeature=="camp" then
		player.repGain=player.repGain+1
		broadcastToAll("{en}and Reputation Gained{ru}и получена Репутация{zh-tw}並獲得聲望{zh-cn}并获得声望{ko}및 평판 획득{es}y Reputación Ganada{fr}et Réputation Gagnée{pt-br}e Reputação Ganha{de}und Ansehen erhalten")
	end
	mapTokenReleaseObject(destroyed)
	undoDestroyedSitePlacement(destroyed)
	destroyed.unlock()
	destroyed.setPositionSmooth({(player.seatPos*40)-117.2+(math.random()*6.5), 3, -35+(math.random()*3.2)})
	scheduleAvatarDropRefresh()
	--The restored token must actually enter its inventory zone before the objective helper counts it.
	--Check one frame after it settles; still run the check on timeout so an odd physics state cannot strand victory.
	if gStates.gameScenario=="Against the Apocalypse Blitz" then
		local restoredGUID=destroyed.guid
		safeWaitCondition("Scenario",function()
			safeWaitFrames("Scenario",function() againstApocalypseCheckCompletion() end,1)
		end,function()
			local restored=getObjectFromGUID(restoredGUID)
			return restored==nil or restored.resting
		end,5,function()
			againstApocalypseCheckCompletion()
		end)
	end
	return true
end

local function destroyRestoreLocationInternal(playerDud, mouseButton, id, type, obj)
	if mouseButton=="-1" then
		if type=="destroy" then
			--destroy
			local featureSearch={"vill", "oasi", "camp", "keep", "mage", "glad", {"ramp", "drac"}, "mine", "mona"}
			local searchOrder={"0", "300", "60", "center", "240", "120", "180"}
			--add tile rotation
			local found=false
			for feature=1, 10, 1 do
				for i=1, 7, 1 do
					local hexFeature=terrainTiles[obj.guid].hexFeature[searchOrder[i]]:sub(1,4)
					if gStates.againstTheApocSitePosition~=7 and hexFeature==featureSearch[gStates.againstTheApocSitePosition] then
						local hexPos=angleToXY(obj, searchOrder[i])
						local terrainGUID=obj.guid
						local hexAngle=searchOrder[i]
						local drawnToken=takeDestroyedSiteToken(getObjectFromGUID(terrainGUID),hexAngle)
						found=destroySite(drawnToken,getObjectFromGUID(terrainGUID),hexAngle)
						if found==true then break end
					end
					if gStates.againstTheApocSitePosition==7 and (hexFeature==featureSearch[7][1] or hexFeature==featureSearch[7][2]) then
						--Deploy and tag the scenario's Possessed Rampaging Enemy. Generic/Quest Possessed
						--tokens are intentionally left untagged so they cannot grant Destroyed Site rewards.
						local possessedBag=getObjectFromGUID(GUID.bag.possessed)
						local possessed=possessedBag~=nil and possessedBag.takeObject({position={angleToXY(obj, searchOrder[i])[1], 2, angleToXY(obj, searchOrder[i])[2]}}) or nil
						if possessed~=nil then
							againstApocalypseMarkPossessedRampager(possessed)
							found=true
							break
						end
					end
				end
				gStates.againstTheApocSitePosition=gStates.againstTheApocSitePosition+1
				if gStates.againstTheApocSitePosition==10 then gStates.againstTheApocSitePosition=1 end
				--Move the shield token
				getObjectFromGUID("e735d3").setPosition({getObjectFromGUID("f64a50").getPosition()[1]-2.37, 1.05, getObjectFromGUID("f64a50").getPosition()[3]+2.895-(0.685*gStates.againstTheApocSitePosition)})
				if found==true then break end
			end
		else
			--Only Against the Apocalypse permits Destroyed Sites to be restored.
			if gStates.gameScenario~="Against the Apocalypse Blitz" then return end
			--restore
			for _, player in pairs(turnOrder) do
				if player.mage==id:sub(7, string.len(id)) then
					--Work out clicking avatar location
					local avPos=mageKnightAvatarPositionByName(id:sub(7,string.len(id))) or {}
					for _, destroyed in pairs(getObjectFromGUID(mapArea).getObjects()) do
						if destroyed.getGMNotes()=="Destroyed" and gStates.destroyedSites~=nil and gStates.destroyedSites[destroyed.guid]~=nil then
							if math.sqrt(((destroyed.getPosition()[1]-avPos[1])^2)+((destroyed.getPosition()[3]-avPos[3])^2))<1 then
								restoreDestroyedSite(destroyed, player)
								break
							end
						end
					end
				end
			end
		end
	end
end

function destroyNextAgainstApocalypseSite(obj)
	return destroyRestoreLocationInternal(nil,"-1","id","destroy",obj)
end

function restoreDestroyedSiteAtCurrentPlayer(player, mouseButton, id)
	return destroyRestoreLocationInternal(player,mouseButton,id,"restore",nil)
end

--City-card positions are arranged in rings around the City. EXPLORE refreshes use the complete current
--EXPLORE set, then choose the closest legal position once instead of first pushing a card away and immediately
--trying to compact it while setPositionSmooth is still moving it.

--Fury begins with Regular Units even though all Core tiles are already face up. Elite Units only
--join subsequent Round offers after a Countryside tile adjacent to a City has been revealed, or after
--a Hero has entered either City at least once.
furyDragonEliteConditionMet=function()
	if gStates==nil or gStates.gameScenario~="Fury of the Apocalypse Dragon" then return false end
	if gStates.furyHeroEnteredCity==true then return true end
	local map=getObjectFromGUID(mapArea)
	if map==nil then return false end
	local countries,cities={},{}
	for _,obj in ipairs(map.getObjects() or {}) do
		local data=terrainTiles[obj.guid]
		if data~=nil and obj.is_face_down==false then
			if data.tileType=="country" then countries[#countries+1]=obj
			elseif data.tileType=="core" and data.hexFeature~=nil and tostring(data.hexFeature.center or ""):sub(1,4)=="city" then cities[#cities+1]=obj end
		end
	end
	for _,city in ipairs(cities) do
		local cp=city.getPosition()
		for _,country in ipairs(countries) do
			local pp=country.getPosition()
			local distance=((cp[1]-pp[1])^2)+((cp[3]-pp[3])^2)
			--Adjacent map-tile centres are 6.35 units apart (40.32 squared).
			if distance>36 and distance<45 then return true end
		end
	end
	return false
end

function furyDragonPrepareEliteUnits()
	if gStates==nil or gStates.gameScenario~="Fury of the Apocalypse Dragon" or gStates.eliteUnitsUsed==true then return false end
	if furyDragonEliteConditionMet()~=true then return false end
	gStates.eliteUnitsUsed=true
	broadcastToAll("{en}Fury of the Apocalypse Dragon: Elite Units are included in this Round's Unit Offer.{ru}Ярость Дракона Апокалипсиса: элитные отряды включены в предложение отрядов этого раунда.{zh-tw}末日巨龍之怒：本回合輪的部隊供應包含精英部隊。{zh-cn}末日巨龙之怒：本回合轮的部队供应包含精英部队。{ko}아포칼립스 드래곤의 분노: 이번 라운드의 유닛 제안에 정예 유닛이 포함됩니다.{es}Furia del Dragón del Apocalipsis: las Unidades de Élite están incluidas en la Oferta de Unidades de esta Ronda.{fr}Fureur du Dragon de l’Apocalypse : les Unités d’Élite sont incluses dans l’Offre d’Unités de cette Manche.{pt-br}Fúria do Dragão do Apocalipse: Unidades de Elite estão incluídas na Oferta de Unidades desta Rodada.{de}Zorn des Apokalypse-Drachen: Eliteeinheiten sind in diesem Einheitenangebot der Runde enthalten.",{1,1,0.5})
	return true
end

function againstDragonRevealLair(tile)
	if gStates.gameScenario~="Against the Dragon Blitz" or tile==nil or tile.guid~=GUID.tile.core03 or tile.is_face_down==true then return false end
	if gStates.apocalypseDragonLairRevealed==true then return false end

	gStates.apocalypseDragonLairRevealed=true
	local tileGUID=tile.guid
	local targetRotation={0,180,180}

	local function lairGeometry(currentTile)
		if currentTile==nil then return nil,nil end
		local tilePos=currentTile.getPosition()
		--Use the standard 180-degree tile orientation only to define the fixed world-space footprint.
		--The actual tile rotation is deliberately ignored for these three physical positions.
		local fixedRotation={0,180,180}
		local worldPositions={
			{tilePos[1],0.97,tilePos[3]},
			(function() local xy=angleToXY(currentTile,"240",tilePos,fixedRotation) return {xy[1],0.97,xy[2]} end)(),
			(function() local xy=angleToXY(currentTile,"300",tilePos,fixedRotation) return {xy[1],0.97,xy[2]} end)()
		}
		local hexes={}
		for _,pos in ipairs(worldPositions) do
			local bearing=terrainHexBearing(currentTile,pos)
			hexes[#hexes+1]={bearing=bearing,position=pos}
		end
		--105141 is modelled with its origin at the centre of the front hex.
		--Placing that origin on the main/centre hex naturally covers the two rear hexes.
		return hexes,{worldPositions[1][1],1.18,worldPositions[1][3]}
	end

	local function suppressLairRuins(currentTile,currentHexes)
		if currentTile==nil or currentHexes==nil then return end
		--Do this before the normal terrain-token loop starts. That loop captures hexFeature in
		--delayed callbacks, so clearing the Ruins later is too late to stop the yellow token.
		for _,hex in ipairs(currentHexes) do
			if hex.bearing~=nil and terrainTiles[currentTile.guid].hexFeature[hex.bearing]=="ruin" then
				gStates.hexOverideSave=gStates.hexOverideSave or {}
				gStates.hexOverideSave[currentTile.guid]=gStates.hexOverideSave[currentTile.guid] or {}
				gStates.hexOverideSave[currentTile.guid][hex.bearing]=""
				runtimeMapSetHexFeature(currentTile.guid,hex.bearing,"")
			end
		end
	end

	local hexes,target=lairGeometry(tile)
	suppressLairRuins(tile,hexes)
	gStates.apocalypseDragonLair={tileGUID=tile.guid,hexes=hexes,position=target,rotation=targetRotation}

	local function placeDragon()
		local currentTile=getObjectFromGUID(tileGUID)
		if currentTile~=nil then
			hexes,target=lairGeometry(currentTile)
			suppressLairRuins(currentTile,hexes)
			gStates.apocalypseDragonLair.hexes=hexes
			gStates.apocalypseDragonLair.position=target
		end

		local dragon=getObjectFromGUID(apocalypseDragon.model)
		local bag=getObjectFromGUID(GUID.bag.apocalypseDragon)
		if dragon==nil and bag~=nil then
			dragon=bag.takeObject({guid=apocalypseDragon.model,position=target,rotation=targetRotation,smooth=false})
		elseif dragon~=nil then
			dragon.setLock(false)
			dragon.setRotationSmooth(targetRotation,false,true)
			dragon.setPositionSmooth(target)
		end
		if dragon~=nil then
			dragon.setLock(false)
			apocalypseDragonLockModelWhenSettled()
		end
	end

	safeWaitCondition("Scenario",placeDragon,function()
		local currentTile=getObjectFromGUID(tileGUID)
		return currentTile==nil or currentTile.resting
	end,8,placeDragon)

	broadcastToAll("{en}The Apocalypse Dragon's Lair has been revealed.{ru}Логово Дракона Апокалипсиса раскрыто.{zh-tw}末日巨龍的巢穴已揭露。{zh-cn}末日巨龙的巢穴已揭示。{ko}아포칼립스 드래곤의 둥지가 공개되었습니다.{es}La guarida del Dragón del Apocalipsis ha sido revelada.{fr}L'antre du Dragon de l'Apocalypse a été révélé.{pt-br}O covil do Dragão do Apocalipse foi revelado.{de}Der Hort des Apokalypse-Drachen wurde enthüllt.",{1,0.75,0.2})
	return true
end

--Ground combat against the landed Apocalypse Dragon. A normal attack starts when the current
--Mage Knight is dropped onto any of the three lair hexes. Solo attacks deploy every live head to
--that board; cooperative attacks reuse the normal co-op assault interface to divide coloured heads.
--The Control head is never divided: each cooperative participant receives a temporary Control clone.
--Against the Dragon turn system ------------------------------------------------
--The Apocalypse Dragon is deliberately NOT inserted into turnOrder. It acts between normal turn
--circuits so the rest of the mod can continue to assume that every turnOrder entry is a Mage Knight,
--Dummy/Proxy, or Volkare.
againstDragonActive=function()
	return gStates~=nil and gStates.gameScenario=="Against the Dragon Blitz"
end

function againstDragonPositionRoundOrderToken()
	if againstDragonActive()~=true then return false end
	local token=getObjectFromGUID(apocalypseDragon.roundOrder)
	if token==nil then return false end
	local target={-1.90,0.97,-22.20}
	token.unlock()
	token.setRotation({0,180,0})
	token.setPositionSmooth(target)
	safeWaitCondition("Scenario",function()
		local current=getObjectFromGUID(apocalypseDragon.roundOrder)
		if current~=nil then current.lock() end
	end,function()
		local current=getObjectFromGUID(apocalypseDragon.roundOrder)
		return current==nil or current.isSmoothMoving()==false
	end)
	return true
end

againstDragonPlayerIndexForMage=function(mage)
	for index,details in ipairs(turnOrder or {}) do if details~=nil and details.mage==mage then return index end end
	return nil
end

againstDragonClearBlackManaMarkers=function()
	for _,guid in pairs(gStates.apocalypseDragonBlackMana or {}) do
		local token=guid~=nil and getObjectFromGUID(guid) or nil
		if token~=nil then token.destruct() end
	end
	gStates.apocalypseDragonBlackMana={}
	gStates.apocalypseDragonAttackedThisRound={}
end

againstDragonPlayerMarked=function(playerIndex)
	local details=turnOrder[playerIndex]
	if details==nil then return true end
	return gStates.apocalypseDragonAttackedThisRound~=nil and gStates.apocalypseDragonAttackedThisRound[details.mage]==true
end

againstDragonMarkPlayer=function(playerIndex)
	local details=turnOrder[playerIndex]
	if details==nil or againstDragonPlayerMarked(playerIndex)==true then return false end
	gStates.apocalypseDragonAttackedThisRound=gStates.apocalypseDragonAttackedThisRound or {}
	gStates.apocalypseDragonBlackMana=gStates.apocalypseDragonBlackMana or {}
	gStates.apocalypseDragonAttackedThisRound[details.mage]=true

	local orderToken=getObjectFromGUID(details.turnOrderTokenGUID)
	local blackBag=getObjectFromGUID("74d666")
	if orderToken~=nil and blackBag~=nil then
		local p=orderToken.getPosition()
		local token=blackBag.takeObject({position={p[1],1.35,p[3]},rotation={0,180,0},smooth=true})
		if token~=nil then
			gStates.apocalypseDragonBlackMana[details.mage]=token.guid
			token.setDescription(joinLang({"{en}Apocalypse Dragon attacked {ru}Дракон Апокалипсиса атаковал {zh-tw}末日巨龍本回合攻擊了 {zh-cn}末日巨龙本回合攻击了 {ko}아포칼립스 드래곤이 이번 라운드에 {es}El Dragón del Apocalipsis atacó a {fr}Le Dragon de l’Apocalypse a attaqué {pt-br}O Dragão do Apocalipse atacou {de}Der Apokalypse-Drache griff ",tostring(details.mage),"{en} this Round{ru} в этом раунде{zh-tw}{zh-cn}{ko}을(를) 공격했습니다{es} esta ronda{fr} ce round{pt-br} nesta rodada{de} in dieser Runde an"}))
			local guid=token.guid
			safeWaitCondition("Scenario",function()
				local current=getObjectFromGUID(guid)
				if current~=nil then current.lock() end
			end,function()
				local current=getObjectFromGUID(guid)
				return current==nil or current.resting==true
			end)
		end
	end
	return true
end

function againstDragonAttackControlUI(show)
	local token=getObjectFromGUID(apocalypseDragon.roundOrder)
	if token==nil then return end
	local xml=token.UI.getXmlTable() or {}
	for i=#xml,1,-1 do
		local id=xml[i].attributes~=nil and tostring(xml[i].attributes.id or "") or ""
		if id=="AgainstDragonAttackComplete" then table.remove(xml,i) end
	end
	if show==true then
		xml[#xml+1]={tag="Button",attributes={id="AgainstDragonAttackComplete",onClick="global/againstDragonAttackComplete",onMouseDown="global/buttonClicked",onMouseUp="global/buttonClicked",
			height=210,width=620,position="0 235 -12",rotation="0 0 180",scale="0.30 0.30",color="rgba(0,0,0,0.0)"},
			children={{tag="Image",attributes={id="AgainstDragonAttackCompleteImage",image="Sliced Button/Button Object Active",type="Sliced"}},
				{tag="HorizontalLayout",attributes={padding="28 28 20 20"},children={{tag="Text",attributes={id="AgainstDragonAttackCompleteText",font="Fonts/MKCardText",fontSize="78",fontStyle="Normal",alignment="MiddleCenter",resizeTextForBestFit="true",resizeTextMaxSize="78",text="{en}COMPLETE\nDRAGON ATTACK{ru}ЗАВЕРШИТЬ\nАТАКУ ДРАКОНА{zh-tw}完成\n巨龍攻擊{zh-cn}完成\n巨龙攻击{ko}드래곤 공격\n완료{es}COMPLETAR\nATAQUE DEL DRAGÓN{fr}TERMINER\nL’ATTAQUE DU DRAGON{pt-br}CONCLUIR\nATAQUE DO DRAGÃO{de}DRACHENANGRIFF\nABSCHLIESSEN"}}}}}}
	end
	if #xml>0 then token.UI.setXmlTable(xml) else token.UI.setXml("") end
end

function againstDragonTargetChoiceClearButtons()
	local map=getObjectFromGUID(mapArea)
	if map==nil then return end
	for _,terrain in pairs(map.getObjects()) do
		if terrainTiles[terrain.guid]~=nil then
			local xml=terrain.UI.getXmlTable() or {}
			local changed=false
			for i=#xml,1,-1 do
				local id=xml[i].attributes~=nil and tostring(xml[i].attributes.id or "") or ""
				if id:find("DragonTargetChoice",1,true)~=nil then table.remove(xml,i) changed=true end
			end
			if changed==true then
				if #xml>0 then terrain.UI.setXmlTable(xml) else terrain.UI.setXml("") end
			end
		end
	end
end

function againstDragonOffMapChoiceClearButtons()
	for _,details in ipairs(turnOrder or {}) do
		local token=details~=nil and getObjectFromGUID(details.turnOrderTokenGUID) or nil
		if token~=nil then
			local xml=token.UI.getXmlTable() or {}
			local changed=false
			for i=#xml,1,-1 do
				local id=xml[i].attributes~=nil and tostring(xml[i].attributes.id or "") or ""
				if id:find("DragonOffMapChoice",1,true)~=nil then table.remove(xml,i) changed=true end
			end
			if changed==true then
				if #xml>0 then token.UI.setXmlTable(xml) else token.UI.setXml("") end
			end
		end
	end
end

againstDragonTargetChoiceButton=function(option,index,xml,splitIndex,splitCount)
	if option==nil or option.key==nil then return nil,xml end
	local terrain,placement=terrainHexChoiceUIPlacement(option.key,0.38,splitIndex,splitCount,0.38)
	if terrain==nil or placement==nil then return nil,xml end
	local label="{en}Dragon\nDestroy{ru}Дракон\nУничтожает{zh-tw}巨龍\n摧毀{zh-cn}巨龙\n摧毁{ko}드래곤\n파괴{es}Dragón\nDestruir{fr}Dragon\nDétruire{pt-br}Dragão\nDestruir{de}Drache\nZerstört"
	if option.kind=="attack" then label=joinLang({"{en}Attack\n{ru}Атака\n{zh-tw}攻擊\n{zh-cn}攻击\n{ko}공격\n{es}Atacar\n{fr}Attaquer\n{pt-br}Atacar\n{de}Angriff\n",tostring(option.mage or joinLang({"{en}Player{ru}Игрок{zh-tw}玩家{zh-cn}玩家{ko}플레이어{es}Jugador{fr}Joueur{pt-br}Jogador{de}Spieler"}))}) end
	local id=terrain.guid.."DragonTargetChoice"..tostring(index)
	xml=xml or terrain.UI.getXmlTable() or {}
	xml[#xml+1]={tag="Button",attributes={id=id,onClick="global/againstDragonTargetChoiceSelect",onMouseDown="global/buttonClicked",onMouseUp="global/buttonClicked",
		height=placement.height,width=320,color="rgba(0,0,0,0.0)",position=placement.x.." "..placement.y.." "..placement.depth,rotation="0 0 "..tostring(placement.rotation),scale=placement.scale.." "..placement.scale},
		children={{tag="Image",attributes={id=id.."Image",image="Sliced Button/Button Object Active",type="Sliced"}},
			{tag="HorizontalLayout",attributes={padding="20 20 12 12"},children={{tag="Text",attributes={id=id.."Text",font="Fonts/MKCardText",offsetXY="0 1",fontSize=placement.count>1 and "60" or "72",fontStyle="Normal",alignment="MiddleCenter",resizeTextForBestFit="true",resizeTextMaxSize=placement.count>1 and "60" or "72",text=label}}}}}}
	return terrain,xml
end

againstDragonShowMapChoice=function(pending)
	apocalypseDragonTurnChoiceClearButtons()
	if pending==nil or pending.options==nil then return false end
	local byTerrain={}
	local sameHexCounts={}
	local sameHexSeen={}
	for _,option in ipairs(pending.options) do if option.key~=nil then sameHexCounts[option.key]=(sameHexCounts[option.key] or 0)+1 end end
	for index,option in ipairs(pending.options) do
		local terrainGUID=option.key~=nil and tostring(option.key):match("^([^|]+)|") or nil
		local terrain=terrainGUID~=nil and getObjectFromGUID(terrainGUID) or nil
		if terrain~=nil then
			local group=byTerrain[terrainGUID]
			if group==nil then group={terrain=terrain,xml=terrain.UI.getXmlTable() or {}} byTerrain[terrainGUID]=group end
			sameHexSeen[option.key]=(sameHexSeen[option.key] or 0)+1
			local _,xml=againstDragonTargetChoiceButton(option,index,group.xml,sameHexSeen[option.key],sameHexCounts[option.key])
			group.xml=xml or group.xml
		end
	end
	for _,group in pairs(byTerrain) do group.terrain.UI.setXmlTable(group.xml) end
	return true
end

againstDragonShowOffMapChoice=function(pending)
	apocalypseDragonTurnChoiceClearButtons()
	if pending==nil or pending.options==nil then return false end
	for index,option in ipairs(pending.options) do
		local playerIndex=againstDragonPlayerIndexForMage(option.mage)
		local details=playerIndex~=nil and turnOrder[playerIndex] or nil
		local token=details~=nil and getObjectFromGUID(details.turnOrderTokenGUID) or nil
		if token~=nil then
			local xml=token.UI.getXmlTable() or {}
			local id=token.guid.."DragonOffMapChoice"..tostring(index)
			xml[#xml+1]={tag="Button",attributes={id=id,onClick="global/againstDragonOffMapChoiceSelect",onMouseDown="global/buttonClicked",onMouseUp="global/buttonClicked",
				height=150,width=470,position="0 185 -10",rotation="0 0 180",scale="0.30 0.30",color="rgba(0,0,0,0.0)"},
				children={{tag="Image",attributes={id=id.."Image",image="Sliced Button/Button Object Active",type="Sliced"}},
					{tag="HorizontalLayout",attributes={padding="20 20 15 15"},children={{tag="Text",attributes={id=id.."Text",font="Fonts/MKCardText",fontSize="76",fontStyle="Normal",alignment="MiddleCenter",resizeTextForBestFit="true",resizeTextMaxSize="76",text=joinLang({"{en}MARK\n{ru}ОТМЕТИТЬ\n{zh-tw}標記\n{zh-cn}标记\n{ko}표시\n{es}MARCAR\n{fr}MARQUER\n{pt-br}MARCAR\n{de}MARKIEREN\n",tostring(option.mage)})}}}}}}
			token.UI.setXmlTable(xml)
		end
	end
	return true
end

againstDragonMapHexByKey=function(hexes,key)
	for _,hex in ipairs(hexes or {}) do if runtimeMapHexKey(hex)==key then return hex end end
	return nil
end

againstDragonDistanceStarts=function(hexes,mapObjects)
	local starts={}
	if gStates.apocalypseDragonLairRevealed==true and gStates.apocalypseDragonLair~=nil then
		for _,saved in ipairs(gStates.apocalypseDragonLair.hexes or {}) do
			local hex=runtimeMapHexForPosition(hexes,saved.position,mapObjects)
			if hex~=nil then starts[#starts+1]=hex end
		end
	else
		for _,hex in ipairs(hexes or {}) do
			if string.lower(tostring(hex.feature or ""))=="portal" then starts[#starts+1]=hex end
		end
	end
	return starts
end

againstDragonDistanceChoices=function(options,hexes,mapObjects)
	local starts=againstDragonDistanceStarts(hexes,mapObjects)
	if #starts<1 then return {} end
	local distances=runtimeMapHexDistanceMap(hexes,starts)
	local best=nil
	local tied={}
	local closest=gStates.apocalypseDragonLairRevealed==true
	for _,option in ipairs(options or {}) do
		local distance=distances[option.key]
		if distance~=nil then
			option.distance=distance
			if best==nil or (closest==true and distance<best) or (closest~=true and distance>best) then
				best=distance
				tied={option}
			elseif distance==best then
				tied[#tied+1]=option
			end
		end
	end
	return tied,best
end

againstDragonPlayerHex=function(hexes,mapObjects,playerIndex)
	local details=turnOrder[playerIndex]
	if details==nil then return nil end
	if details.avatarLocation=="portal" then
		for _,hex in ipairs(hexes or {}) do if string.lower(tostring(hex.feature or ""))=="portal" then return hex end end
	end
	if details.avatarLocation~=nil and details.avatarLocation:sub(1,4)=="city" then
		for zone,city in pairs(cityScriptZones or {}) do
			local z=getObjectFromGUID(zone)
			if z~=nil then
				for _,obj in pairs(z.getObjects()) do
					if obj.getName()==details.mage then
						local cityObj=getObjectFromGUID(city.cityGUID)
						if cityObj~=nil then return runtimeMapHexForPosition(hexes,cityObj.getPosition(),mapObjects) end
					end
				end
			end
		end
	end
	local avatar=currentMageAvatarPosition(playerIndex)
	return avatar~=nil and runtimeMapHexForPosition(hexes,avatar,mapObjects) or nil
end

againstDragonSiteEligible=function(hex)
	if hex==nil then return false end
	local feature=string.lower(tostring(hex.feature or ""))
	if feature=="monastery" and gStates.monasteryBurned~=nil and gStates.monasteryBurned[hex.terrainGUID]==true then return false end
	return feature=="village" or feature=="monastery" or feature=="keep" or feature=="mage tower" or feature=="oasis" or feature=="camp" or feature=="mine"
end

againstDragonDestroyCandidates=function(hexes,mapObjects)
	local candidates={}
	local destroyedBag=getObjectFromGUID(GUID.bag.destroyedSite)
	local siteTokensAvailable=destroyedBag~=nil
	for _,hex in ipairs(hexes or {}) do
		local rampager=nil
		for _,enemy in ipairs(proxyMonstersOnHex(hex,mapObjects)) do
			if gStates.rampagingMonsters~=nil and gStates.rampagingMonsters[enemy.guid]==true then rampager=enemy break end
		end
		if rampager~=nil then
			candidates[#candidates+1]={kind="rampager",key=runtimeMapHexKey(hex),enemyGUID=rampager.guid}
		elseif siteTokensAvailable==true and againstDragonSiteEligible(hex)==true then
			candidates[#candidates+1]={kind="site",key=runtimeMapHexKey(hex),feature=hex.feature}
		end
	end
	return candidates,siteTokensAvailable
end

againstDragonActionLabel=function(action)
	if action=="attack" then return "attack a player" end
	if action=="destroy" then return "destroy a site or Rampaging Enemy" end
	return "take no action"
end

againstDragonFinalReport=function(text)
	local prefix=gStates~=nil and gStates.apocalypseDragonTurnReportPrefix or nil
	if prefix~=nil and prefix~="" then return prefix.."\n"..tostring(text or "") end
	return tostring(text or "")
end

function againstDragonSetTurnReport(text,state)
	if gStates==nil then return end
	gStates.apocalypseDragonTurnReport=tostring(text or "")
	if state~=nil then gStates.apocalypseDragonUIState=state end
	if apocalypseDragonMainUIRefresh~=nil then apocalypseDragonMainUIRefresh() end
end

--The Dragon stays outside turnOrder, but borrows the Dummy/Proxy panel while its interstitial turn is active.
--A fully attending Mage Knight temporarily gets the normal player UI back; once that advanced turn ends,
--the Dragon panel returns with Dragon Processed so the table can acknowledge the result and continue.
function againstDragonAttendanceResponseSpec()
	local pending=gStates~=nil and gStates.apocalypseDragonPendingAttack or nil
	if pending==nil or pending.playerIndex==nil or pending.phase~="choose" then return nil end
	local fullAllowed=againstDragonFullAttendAllowed(pending.playerIndex)
	return {visible=true,
		full={active=true,interactable=fullAllowed,onClick="againstDragonAttendFull",text="{en}Fully Defend{ru}Fully Defend{zh-tw}Fully Defend{zh-cn}Fully Defend{ko}Fully Defend{es}Fully Defend{fr}Fully Defend{pt-br}Fully Defend{de}Fully Defend",tooltip="Take your full turn in advance while resolving the Dragon attack."},
		partial={active=true,interactable=true,onClick="againstDragonFinishPartial",text="{en}Partial Complete{ru}Partial Complete{zh-tw}Partial Complete{zh-cn}Partial Complete{ko}Partial Complete{es}Partial Complete{fr}Partial Complete{pt-br}Partial Complete{de}Partial Complete",tooltip="Finish the Dragon attack without taking your full turn."},
		retreat={active=false}
	}
end

againstDragonResolveDestroyOption=function(option)
	local hexes,mapObjects=runtimeMapHexesAndObjects()
	local hex=option~=nil and againstDragonMapHexByKey(hexes,option.key) or nil
	if hex==nil then
		broadcastToAll("{en}The Apocalypse Dragon's selected destruction target could no longer be found.{ru}Выбранная цель уничтожения Дракона Апокалипсиса больше не найдена.{zh-tw}找不到末日巨龍先前選定的摧毀目標。{zh-cn}找不到末日巨龙先前选定的摧毁目标。{ko}아포칼립스 드래곤이 선택한 파괴 대상을 더 이상 찾을 수 없습니다.{es}Ya no se pudo encontrar el objetivo de destrucción elegido por el Dragón del Apocalipsis.{fr}La cible de destruction choisie par le Dragon de l’Apocalypse est introuvable.{pt-br}O alvo de destruição escolhido pelo Dragão do Apocalipse não pôde mais ser encontrado.{de}Das ausgewählte Zerstörungsziel des Apokalypse-Drachen konnte nicht mehr gefunden werden.",warningColor)
		againstDragonSetTurnReport(againstDragonFinalReport("The selected destruction target could no longer be found."),"Processing")
		safeWaitFrames("Scenario",function() againstDragonCompleteTurn() end,1)
		return false
	end

	if option.kind=="rampager" then
		local target=nil
		for _,enemy in ipairs(proxyMonstersOnHex(hex,mapObjects)) do
			if gStates.rampagingMonsters~=nil and gStates.rampagingMonsters[enemy.guid]==true then target=enemy break end
		end
		if target~=nil then
			local name=(monsterPugs[target.guid] or {}).name or "Rampaging Enemy"
			proxyDiscardMonster(target)
			againstDragonSetTurnReport(againstDragonFinalReport("The Dragon destroyed "..tostring(name).."."),"Processing")
		else
			broadcastToAll("{en}The Apocalypse Dragon's Rampaging Enemy target was no longer present.{ru}Цель Дракона Апокалипсиса — Бродячий враг — больше отсутствует.{zh-tw}末日巨龍的遊蕩敵人目標已不存在。{zh-cn}末日巨龙的游荡敌人目标已不存在。{ko}아포칼립스 드래곤의 방랑 적 대상이 더 이상 존재하지 않습니다.{es}El objetivo de Enemigo Arrasador del Dragón del Apocalipsis ya no estaba presente.{fr}La cible Ennemi Ravageur du Dragon de l’Apocalypse n’était plus présente.{pt-br}O alvo de Inimigo Errante do Dragão do Apocalipse não estava mais presente.{de}Das Ziel „Streunender Gegner“ des Apokalypse-Drachen war nicht mehr vorhanden.",warningColor)
			againstDragonSetTurnReport(againstDragonFinalReport("The selected Rampaging Enemy was no longer present."),"Processing")
		end
		safeWaitFrames("Scenario",function() againstDragonCompleteTurn() end,3)
		return true
	end

	local bag=getObjectFromGUID(GUID.bag.destroyedSite)
	if bag==nil then
		broadcastToAll("{en}The Destroyed Site token bag could not be found. The Apocalypse Dragon cannot destroy this site.{ru}Мешок жетонов разрушенных мест не найден. Дракон Апокалипсиса не может уничтожить это место.{zh-tw}找不到「被摧毀地點」標記袋。末日巨龍無法摧毀此地點。{zh-cn}找不到“被摧毁地点”标记袋。末日巨龙无法摧毁此地点。{ko}파괴된 장소 토큰 주머니를 찾을 수 없습니다. 아포칼립스 드래곤이 이 장소를 파괴할 수 없습니다.{es}No se encontró la bolsa de fichas de Sitio Destruido. El Dragón del Apocalipsis no puede destruir este lugar.{fr}Le sac de jetons Site Détruit est introuvable. Le Dragon de l’Apocalypse ne peut pas détruire ce lieu.{pt-br}A bolsa de fichas de Local Destruído não foi encontrada. O Dragão do Apocalipse não pode destruir este local.{de}Der Beutel mit Markern für zerstörte Orte wurde nicht gefunden. Der Apokalypse-Drache kann diesen Ort nicht zerstören.",warningColor)
		againstDragonSetTurnReport(againstDragonFinalReport("The Dragon could not destroy the selected site because the Destroyed Site token bag was unavailable."),"Processing")
		safeWaitFrames("Scenario",function() againstDragonCompleteTurn() end,1)
		return false
	end

	--Every enemy on an inhabited site/mine is removed before the Destroyed Site marker is placed.
	for _,enemy in ipairs(proxyMonstersOnHex(hex,mapObjects)) do
		if getObjectFromGUID(enemy.guid)~=nil then proxyDiscardMonster(enemy) end
	end
	local token=takeDestroyedSiteToken(hex.terrain,hex.bearing)
	local label=proxyFeatureDisplayName~=nil and proxyFeatureDisplayName(hex.feature) or tostring(hex.feature)
	if token~=nil then
		destroySite(token,hex.terrain,hex.bearing)
		againstDragonSetTurnReport(againstDragonFinalReport("The Dragon destroyed the "..tostring(label).."."),"Processing")
	else
		againstDragonSetTurnReport(againstDragonFinalReport("The Dragon could not draw a Destroyed Site token for the "..tostring(label).."."),"Processing")
	end
	safeWaitFrames("Scenario",function() againstDragonCompleteTurn() end,4)
	return true
end

function againstDragonBeginDestroy()
	gStates.apocalypseDragonUIState="Processing"
	local hexes,mapObjects=runtimeMapHexesAndObjects()
	local candidates,siteTokensAvailable=againstDragonDestroyCandidates(hexes,mapObjects)
	if #candidates<1 then
		local result
		if siteTokensAvailable~=true then
			result="The Destroyed Site token bag was unavailable and there were no Rampaging Enemies to destroy."
			broadcastToAll("{en}The Destroyed Site token bag could not be found and there are no Rampaging Enemies on the map. The Apocalypse Dragon destroys nothing.{ru}Мешок жетонов разрушенных мест не найден, и на карте нет Бродячих врагов. Дракон Апокалипсиса ничего не уничтожает.{zh-tw}找不到「被摧毀地點」標記袋，且地圖上沒有遊蕩敵人。末日巨龍不會摧毀任何東西。{zh-cn}找不到“被摧毁地点”标记袋，且地图上没有游荡敌人。末日巨龙不会摧毁任何东西。{ko}파괴된 장소 토큰 주머니를 찾지 못했고 맵에 방랑 적도 없습니다. 아포칼립스 드래곤은 아무것도 파괴하지 않습니다.{es}No se encontró la bolsa de fichas de Sitio Destruido y no hay Enemigos Arrasadores en el mapa. El Dragón del Apocalipsis no destruye nada.{fr}Le sac de jetons Site Détruit est introuvable et aucun Ennemi Ravageur n’est présent sur la carte. Le Dragon de l’Apocalypse ne détruit rien.{pt-br}A bolsa de fichas de Local Destruído não foi encontrada e não há Inimigos Errantes no mapa. O Dragão do Apocalipse não destrói nada.{de}Der Beutel mit Markern für zerstörte Orte wurde nicht gefunden und es gibt keine streunenden Gegner auf der Karte. Der Apokalypse-Drache zerstört nichts.",warningColor)
		else
			result="The Dragon had no legal site or Rampaging Enemy to destroy."
		end
		againstDragonSetTurnReport(againstDragonFinalReport(result),"Processing")
		safeWaitFrames("Scenario",function() againstDragonCompleteTurn() end,1)
		return true
	end
	local tied,distance=againstDragonDistanceChoices(candidates,hexes,mapObjects)
	if #tied<1 then
		broadcastToAll("{en}The Apocalypse Dragon could not measure a revealed-space route to a destruction target.{ru}Дракон Апокалипсиса не смог определить путь по открытым клеткам до цели уничтожения.{zh-tw}末日巨龍無法計算沿已揭示空間前往摧毀目標的路線。{zh-cn}末日巨龙无法计算沿已揭示空间前往摧毁目标的路线。{ko}아포칼립스 드래곤이 공개된 칸을 따라 파괴 대상까지의 경로를 계산하지 못했습니다.{es}El Dragón del Apocalipsis no pudo calcular una ruta por espacios revelados hasta un objetivo de destrucción.{fr}Le Dragon de l’Apocalypse n’a pas pu calculer un trajet par les cases révélées jusqu’à une cible de destruction.{pt-br}O Dragão do Apocalipse não conseguiu calcular uma rota por espaços revelados até um alvo de destruição.{de}Der Apokalypse-Drache konnte keinen Weg über aufgedeckte Felder zu einem Zerstörungsziel bestimmen.",warningColor)
		againstDragonSetTurnReport(againstDragonFinalReport("The Dragon could not measure a route to a legal destruction target."),"Processing")
		safeWaitFrames("Scenario",function() againstDragonCompleteTurn() end,1)
		return true
	end
	if #tied==1 then return againstDragonResolveDestroyOption(tied[1]) end

	local chooser=apocalypseDragonChoicePlayerIndex()
	local pending={type="destroy",playerIndex=chooser,options=tied,distance=distance}
	gStates.apocalypseDragonPendingChoice=pending
	againstDragonShowMapChoice(pending)
	local direction=gStates.apocalypseDragonLairRevealed==true and "closest to the Lair" or "furthest from the Portal"
	local chooserText=apocalypseDragonChoicePlayerLabel(chooser)
	againstDragonSetTurnReport(againstDragonFinalReport("The Dragon has "..tostring(#tied).." tied destruction targets "..direction..".\n"..chooserText.." must pick one of the highlighted targets."),"WaitingChoice")
	return true
end

againstDragonGainFame=function(playerIndex,amount)
	local details=turnOrder[playerIndex]
	if details==nil or details.mage==gStates.positionMageKnight[5] then return false end
	--Airborne Dragon Fame is a normal pending Fame gain. Keeping it in fameGain makes the
	--reward visible during a Fully Attack turn and lets the normal end-turn reward path apply it.
	details.fameGain=(details.fameGain or 0)+(tonumber(amount) or 0)
	return true
end

--The four coloured head tokens double as the physical airborne attackers. Their actual Dragon levels
--never change here: only their temporary image/monster data changes to the current Round, then they return home.

function againstDragonAirborneHeadGUID(guid)
	if guid==nil then return false end
	for _,headName in ipairs(apocalypseDragonAirborneHeads) do
		local headData=apocalypseDragonHeadData(headName)
		if headData~=nil and headData.tokenGUID==guid then return true end
	end
	return false
end

function againstDragonFullAttendInProgress(playerIndex)
	local pending=gStates~=nil and gStates.apocalypseDragonPendingAttack or nil
	return pending~=nil and pending.phase=="full" and pending.playerIndex==playerIndex
end

againstDragonAttendanceAuthorized=function(player,pending)
	if pending==nil or pending.playerIndex==nil then return false end
	local details=turnOrder[pending.playerIndex]
	if details==nil then return false end
	local color=type(player)=="string" and player or (player~=nil and player.color or nil)
	local allowed=positionToColor(pending.playerIndex)
	if color=="Black" or color==allowed then return true end
	if color~=nil then broadcastToColor(joinLang({translateWord[details.mage] or tostring(details.mage),"{en} (or a player seated Black) must choose how to attend this Dragon attack.{ru} (или игрок на чёрном месте) должен выбрать, как участвовать в атаке Дракона.{zh-tw}（或坐在黑色席位的玩家）必須選擇如何參與此巨龍攻擊。{zh-cn}（或坐在黑色席位的玩家）必须选择如何参与此巨龙攻击。{ko} (또는 검은색 자리에 앉은 플레이어)이 이 드래곤 공격에 어떻게 참가할지 선택해야 합니다.{es} (o un jugador sentado en Negro) debe elegir cómo participar en este ataque del Dragón.{fr} (ou un joueur assis en Noir) doit choisir comment participer à cette attaque du Dragon.{pt-br} (ou um jogador sentado no Preto) deve escolher como participar deste ataque do Dragão.{de} (oder ein Spieler auf Schwarz) muss wählen, wie er an diesem Drachenangriff teilnimmt."}),color,warningColor) end
	return false
end

againstDragonFullAttendAllowed=function(playerIndex)
	local details=turnOrder[playerIndex]
	if details==nil then return false end
	local token=getObjectFromGUID(details.turnOrderTokenGUID)
	return token~=nil and token.is_face_down==false
end

function againstDragonAttendanceUIRefresh()
	local spec=againstDragonAttendanceResponseSpec()
	if spec==nil then return false end
	automatedAttackResponseUI(spec)
	return true
end

againstDragonAirborneTokenPosition=function(playerIndex,slot)
	local details=turnOrder[playerIndex]
	if details==nil then return nil end
	--Match the landed Dragon spacing offset and keep the aerial fight clear of the left-side combat controls.
	return {(details.seatPos*40)-98.75+((slot-1)*2.5),1.5,-39.25}
end

againstDragonAirborneMonsterData=function(headName,round)
	local data=apocalypseDragonMonsterData(headName,round)
	if data==nil then return nil end
	--These heads cannot be attacked during the airborne combat. Keep only attack-side information.
	data.armour=nil
	data.pResist=nil data.fResist=nil data.iResist=nil data.elusive=nil
	--The Round Fame is awarded once by the Dragon attack resolver, never by individual heads.
	data.fame=0
	data.dragonAirborne=true
	return data
end

againstDragonDeployAirborneHeads=function(playerIndex)
	local pending=gStates.apocalypseDragonPendingAttack
	local details=turnOrder[playerIndex]
	if pending==nil or pending.playerIndex~=playerIndex or details==nil then return false end
	local round=math.max(1,math.min(12,math.floor(tonumber(pending.round) or tonumber(gStates.currentRound) or 1)))
	gStates.monsterPerks=gStates.monsterPerks or {}
	for slot,headName in ipairs(apocalypseDragonAirborneHeads) do
		local headData=apocalypseDragonHeadData(headName)
		local levelData=apocalypseDragonCurrentLevelData(headName,round)
		local token=headData~=nil and getObjectFromGUID(headData.tokenGUID) or nil
		if headData~=nil and levelData~=nil and token~=nil then
			monsterPugs[headData.tokenGUID]=againstDragonAirborneMonsterData(headName,round)
			gStates.monsterPerks[headData.tokenGUID]={dragonAirborne=true,dragonAirborneRound=round,dragonAirborneMage=details.mage}
			local target=againstDragonAirborneTokenPosition(playerIndex,slot)
			token.setLock(false)
			token.setCustomObject({image=levelData.image})
			token.setName(headName.." Dragon Head — Airborne Round "..tostring(round))
			token.reload()
			local guid=headData.tokenGUID
			safeWaitFrames("Scenario",function()
				local current=getObjectFromGUID(guid)
				if current~=nil then
					--Airborne attacks use only the printed Round-level attack. Any Control bonus decal
					--belongs to the persistent landed Dragon state and must not travel with this temporary form.
					syncDragonHeadAttackBonusDecal(guid,0)
					if target~=nil then
						current.setLock(false)
						current.setRotation({0,180,0})
						current.setPositionSmooth(target,false,true)
					end
				end
			end,1)
		end
	end
	pending.tokensDeployed=true
	pending.tokensReturned=false
	return true
end

againstDragonAirborneProtectionLocation=function(playerIndex)
	local avatar=coopAssaultAvatarObject~=nil and coopAssaultAvatarObject(playerIndex) or nil
	if avatar==nil then return nil end
	local terrain,bearing,_,feature=terrainHexAtPosition(avatar.getPosition())
	if terrain==nil or bearing==nil or feature==nil then return nil end
	return {terrainGUID=terrain.guid,bearing=bearing,feature=feature}
end

againstDragonAirborneProtectionReminder=function(location)
	if location==nil then return "No Dragon-head protection from this space." end
	local feature=string.lower(tostring(location.feature or ""))
	local label=proxyFeatureDisplayName~=nil and proxyFeatureDisplayName(location.feature) or tostring(location.feature or "space")
	if feature:sub(1,4)=="city" then
		return "Fortified City: protect against 2 heads. Flip those heads face down. The City is not destroyed."
	end
	if feature=="keep" or feature=="mage tower" then
		return "Fortified "..tostring(label)..": protect against 2 heads. Flip those heads face down; the site is destroyed after combat."
	end
	if feature=="mine" then
		return "Crystal Mine: protect against 2 heads. Flip those heads face down; the Mine is destroyed after combat."
	end
	if feature=="village" or feature=="monastery" or feature=="oasis" or feature=="camp" or feature=="refugee camp" then
		return tostring(label)..": protect against 1 head. Flip that head face down; the site is destroyed after combat."
	end
	if feature=="glade" or feature=="magical glade" then
		return "Glade: spend matching-colour mana to protect against a head, then flip it face down. The Glade is destroyed after combat."
	end
	return "No Dragon-head protection from this "..tostring(label).."."
end

function againstDragonAirborneProtectionDestroysSite(feature)
	local value=string.lower(tostring(feature or ""))
	--Cities may protect the player but are explicitly never destroyed by an airborne Dragon attack.
	if value:sub(1,4)=="city" then return false end
	return value=="keep" or value=="mage tower" or value=="mine" or value=="village" or
		value=="monastery" or value=="oasis" or value=="camp" or value=="glade"
end

againstDragonCaptureAirborneSuppression=function()
	local pending=gStates~=nil and gStates.apocalypseDragonPendingAttack or nil
	if pending==nil or pending.suppressionCaptured==true then return false end
	pending.suppressionCaptured=true
	pending.suppressedHeads={}
	for _,headName in ipairs(apocalypseDragonAirborneHeads) do
		local headData=apocalypseDragonHeadData(headName)
		local token=headData~=nil and getObjectFromGUID(headData.tokenGUID) or nil
		if token~=nil and token.is_face_down==true then pending.suppressedHeads[#pending.suppressedHeads+1]=headName end
	end
	pending.usedSiteProtection=#pending.suppressedHeads>0
	return pending.usedSiteProtection
end

function againstDragonResolveAirborneProtection(pending)
	if pending==nil or pending.siteProtectionResolved==true then return false end
	pending.siteProtectionResolved=true
	if pending.usedSiteProtection~=true then return false end
	local location=pending.protectionLocation
	if location==nil then return false end
	local feature=string.lower(tostring(location.feature or ""))
	if feature:sub(1,4)=="city" then return false end
	if againstDragonAirborneProtectionDestroysSite(feature)~=true then return false end
	local terrain=getObjectFromGUID(location.terrainGUID)
	if terrain==nil or terrainTiles[location.terrainGUID]==nil then return false end
	local currentFeature=terrainTiles[location.terrainGUID].hexFeature[location.bearing]
	if currentFeature==nil or string.lower(tostring(currentFeature))~=feature then return false end
	local bag=getObjectFromGUID(GUID.bag.destroyedSite)
	if bag==nil then
		broadcastToAll("{en}A Dragon head was suppressed by the site, but no Destroyed Site token was available.{ru}Голова Дракона была подавлена местом, но жетон разрушенного места недоступен.{zh-tw}此地點壓制了一個龍首，但沒有可用的「被摧毀地點」標記。{zh-cn}此地点压制了一个龙首，但没有可用的“被摧毁地点”标记。{ko}장소가 드래곤 머리 하나를 억제했지만 사용할 파괴된 장소 토큰이 없습니다.{es}El lugar suprimió una cabeza del Dragón, pero no había ninguna ficha de Sitio Destruido disponible.{fr}Le site a neutralisé une tête du Dragon, mais aucun jeton Site Détruit n’était disponible.{pt-br}O local suprimiu uma cabeça do Dragão, mas não havia ficha de Local Destruído disponível.{de}Ein Drachenkopf wurde durch den Ort unterdrückt, aber es war kein Marker für einen zerstörten Ort verfügbar.",warningColor)
		return false
	end
	local token=takeDestroyedSiteToken(terrain,location.bearing)
	if token==nil then return false end
	pending.destroyedSiteTokenGUID=token.guid
	destroySite(token,terrain,location.bearing)
	local label=proxyFeatureDisplayName~=nil and proxyFeatureDisplayName(location.feature) or tostring(location.feature)
	broadcastToAll(joinLang({"{en}The Apocalypse Dragon destroys the {ru}Дракон Апокалипсиса уничтожает {zh-tw}末日巨龍在防護被使用後摧毀 {zh-cn}末日巨龙在防护被使用后摧毁 {ko}아포칼립스 드래곤이 보호 효과가 사용된 후 {es}El Dragón del Apocalipsis destruye {fr}Le Dragon de l’Apocalypse détruit {pt-br}O Dragão do Apocalipse destrói {de}Der Apokalypse-Drache zerstört ",tostring(label),"{en} after its protection was used.{ru} после использования его защиты.{zh-tw}。{zh-cn}。{ko}을(를) 파괴합니다.{es} después de usar su protección.{fr} après l’utilisation de sa protection.{pt-br} depois que sua proteção foi usada.{de}, nachdem dessen Schutz verwendet wurde."}),{1,0.75,0.2})
	return true
end

function againstDragonReturnAirborneHeads()
	local pending=gStates~=nil and gStates.apocalypseDragonPendingAttack or nil
	if pending==nil or pending.tokensDeployed~=true or pending.tokensReturned==true then return false end
	againstDragonCaptureAirborneSuppression()
	pending.tokensReturned=true
	for _,headName in ipairs(apocalypseDragonAirborneHeads) do
		local headData=apocalypseDragonHeadData(headName)
		if headData~=nil then
			if gStates.monsterPerks~=nil then gStates.monsterPerks[headData.tokenGUID]=nil end
			local actual=tonumber(gStates.apocalypseDragonHeadLevels~=nil and gStates.apocalypseDragonHeadLevels[headName] or 0) or 0
			apocalypseDragonApplyHeadLevel(headName,actual)
		end
	end
	return true
end

function againstDragonFinishAttackForPlayer(playerIndex,finishDragonImmediately)
	local pending=gStates~=nil and gStates.apocalypseDragonPendingAttack or nil
	local details=turnOrder[playerIndex]
	if pending==nil or details==nil or pending.playerIndex~=playerIndex then return false end
	local attendance=pending.phase=="full" and "fully attended" or pending.phase=="partial" and "partially attended" or "resolved"
	againstDragonReturnAirborneHeads()
	againstDragonResolveAirborneProtection(pending)
	UI.setAttribute("VolkareAttacked","active","false")
	againstDragonAttackControlUI(false)
	local fame=tonumber(pending.fameQueued) or tonumber(pending.round) or tonumber(gStates.currentRound) or 1
	if pending.fameAwarded~=true then
		if pending.phase=="full" then
			--The normal end-turn cleanup has already applied and cleared fameGain before reaching here.
			pending.fameAwarded=true
		else
			--Partial Complete does not take a normal turn, so apply only the queued Dragon Fame now
			--while preserving any unrelated pending Fame/Reputation on this player.
			local pendingFame=details.fameGain or 0
			local otherFame=math.max(0,pendingFame-fame)
			local oldRepGain=details.repGain or 0
			details.fameGain=fame
			details.repGain=0
			applyPlayerFameReputation(playerIndex)
			details.fameGain=otherFame
			details.repGain=oldRepGain
			pending.fameAwarded=true
		end
	end
	againstDragonMarkPlayer(playerIndex)
	local report="The Dragon attacked "..tostring(details.mage).." at level "..tostring(fame)..".\n"..tostring(details.mage).." "..attendance.." the attack, gained "..tostring(fame).." Fame, and received a Black mana marker."
	gStates.apocalypseDragonTurnReport=report
	if finishDragonImmediately==true then
		--Partial Complete is equivalent to acknowledging Dragon Processed. A fully-attending player
		--does the same only after their advanced normal turn has actually finished. Delay one frame
		--so any current end-turn cleanup can finish before the next normal turn is committed.
		safeWaitFrames("Scenario",function() apocalypseDragonFinishTurn(true) end,1)
	else
		againstDragonCompleteTurn()
	end
	return true
end

againstDragonAttendPartial=function(player,mouseButton,id)
	if mouseButton~="-1" then return end
	againstDragonFinishPartial(player,mouseButton,id)
end

function againstDragonFinishPartial(player,mouseButton,id)
	if mouseButton~="-1" then return end
	local pending=gStates.apocalypseDragonPendingAttack
	if pending==nil or pending.phase~="choose" or againstDragonAttendanceAuthorized(player,pending)~=true then return end
	pending.phase="partial"
	againstDragonFinishAttackForPlayer(pending.playerIndex,true)
end

function againstDragonAttendFull(player,mouseButton,id)
	if mouseButton~="-1" then return end
	local pending=gStates.apocalypseDragonPendingAttack
	if pending==nil or pending.phase~="choose" or againstDragonAttendanceAuthorized(player,pending)~=true then return end
	if againstDragonFullAttendAllowed(pending.playerIndex)~=true then
		againstDragonAttendanceUIRefresh()
		local color=player~=nil and player.color or positionToColor(pending.playerIndex)
		if color~=nil then broadcastToColor("{en}Fully Defend is unavailable because this Mage Knight's Round Order token is already face down.{ru}Полная защита недоступна, потому что жетон порядка хода этого Рыцаря-мага уже лежит лицом вниз.{zh-tw}無法完全防禦，因為此魔法騎士的回合順位標記已經翻面。{zh-cn}无法完全防御，因为此魔法骑士的回合顺序标记已经翻面。{ko}이 마법 기사의 라운드 순서 토큰이 이미 뒷면이어서 완전 방어를 사용할 수 없습니다.{es}Defender por Completo no está disponible porque la ficha de Orden de Ronda de este Caballero Mago ya está boca abajo.{fr}La Défense Complète est indisponible car le jeton d’Ordre de Manche de ce Chevalier-Mage est déjà face cachée.{pt-br}Defender por Completo não está disponível porque a ficha de Ordem da Rodada deste Cavaleiro-Mago já está virada para baixo.{de}Vollständige Verteidigung ist nicht möglich, da der Rundenreihenfolgemarker dieses Magieritters bereits verdeckt liegt.",color,warningColor) end
		return
	end
	local playerIndex=pending.playerIndex
	local details=turnOrder[playerIndex]
	if details==nil then return end
	pending.phase="full"
	gStates.apocalypseDragonFullAttendPlayer=playerIndex
	gStates.apocalypseDragonUIState="FullAttend"
	gStates.apocalypseDragonTurnReport="The Dragon attacked "..tostring(details.mage).." at level "..tostring(pending.round or gStates.currentRound)..".\n"..tostring(details.mage).." is fully attacking and taking their turn in advance."
	--The Dragon interface is finished now. The heads remain on this player's board while they take
	--a normal out-of-turn turn; their end-turn cleanup resolves the Dragon reward and resumes play
	--directly, without returning to Dragon Processed.
	UI.setAttribute("DummyTurn","active","false")
	automatedAttackResponseUI(nil)
	local token=getObjectFromGUID(details.turnOrderTokenGUID)
	if token~=nil and token.is_face_down==false then token.flip() end
	local function beginAdvancedTurn()
		nextTurnMerged("incrementTurn")
		combatCameraFocus(playerIndex)
		mainUIUpdate("Dragon Full Attack")
	end
	if token~=nil then safeWaitCondition("Scenario",beginAdvancedTurn,function() return token==nil or token.resting end,4,beginAdvancedTurn) else beginAdvancedTurn() end
end

againstDragonBeginManualAttack=function(playerIndex)
	local details=turnOrder[playerIndex]
	if details==nil then
		againstDragonSetTurnReport("The Dragon's selected player could no longer be found.","Processing")
		safeWaitFrames("Scenario",function() againstDragonCompleteTurn() end,1)
		return false
	end
	local attackFame=math.max(1,tonumber(gStates.currentRound) or 1)
	gStates.apocalypseDragonPendingAttack={playerIndex=playerIndex,mage=details.mage,round=gStates.currentRound,phase="choose",tokensDeployed=false,tokensReturned=false,fameQueued=attackFame,fameAwarded=false}
	againstDragonGainFame(playerIndex,attackFame)
	gStates.apocalypseDragonPendingAttack.protectionLocation=againstDragonAirborneProtectionLocation(playerIndex)
	againstDragonAttackControlUI(false)
	againstDragonDeployAirborneHeads(playerIndex)
	local fullText=againstDragonFullAttendAllowed(playerIndex) and "Choose Fully Defend or resolve the restricted combat and click Partial Complete." or "Their Round Order token is already face down, so resolve the restricted combat and click Partial Complete."
	local protectionText=againstDragonAirborneProtectionReminder(gStates.apocalypseDragonPendingAttack.protectionLocation)
	againstDragonSetTurnReport("The Dragon is attacking "..tostring(details.mage).." at level "..tostring(gStates.currentRound)..".\n"..fullText.."\n"..protectionText,"WaitingAttendance")
	againstDragonAttendanceUIRefresh()
	combatCameraFocus(playerIndex)
	return true
end

againstDragonResolveOffMapPlayer=function(playerIndex)
	local details=turnOrder[playerIndex]
	if details==nil then
		againstDragonSetTurnReport("The Dragon's selected Portal player could no longer be found.","Processing")
		safeWaitFrames("Scenario",function() againstDragonCompleteTurn() end,1)
		return false
	end
	againstDragonMarkPlayer(playerIndex)
	gStates.apocalypseDragonTurnReportPrefix=tostring(details.mage).." was on the Portal, so the Dragon could not attack them. A Black mana marker was placed; the Dragon destroys a target instead."
	againstDragonSetTurnReport(gStates.apocalypseDragonTurnReportPrefix,"Processing")
	return againstDragonBeginDestroy()
end

function againstDragonBeginAttack()
	gStates.apocalypseDragonUIState="Processing"
	local hexes,mapObjects=runtimeMapHexesAndObjects()
	local attackable={}
	local offMap={}
	for index,details in ipairs(turnOrder or {}) do
		local human=details~=nil and (details.seatPos or 99)<=4 and details.mage~=gStates.positionMageKnight[5] and playerDropoutInactive(index)==false
		if human==true and againstDragonPlayerMarked(index)~=true then
			if details.avatarLocation=="portal" then
				offMap[#offMap+1]={kind="offMap",mage=details.mage,playerIndex=index}
			else
				local hex=againstDragonPlayerHex(hexes,mapObjects,index)
				if hex~=nil then
					attackable[#attackable+1]={kind="attack",mage=details.mage,playerIndex=index,key=runtimeMapHexKey(hex)}
				else
					broadcastToAll(joinLang({"{en}Could not locate the map space for {ru}Не удалось найти клетку карты для {zh-tw}找不到 {zh-cn}找不到 {ko}아포칼립스 드래곤 공격을 위한 {es}No se pudo localizar el espacio de mapa de {fr}Impossible de localiser la case de carte de {pt-br}Não foi possível localizar o espaço do mapa de {de}Das Kartenfeld von ",translateWord[details.mage] or tostring(details.mage),"{en} for the Apocalypse Dragon attack.{ru} для атаки Дракона Апокалипсиса.{zh-tw} 的地圖空間以進行末日巨龍攻擊。{zh-cn} 的地图空间以进行末日巨龙攻击。{ko}의 지도 칸을 찾지 못했습니다.{es} para el ataque del Dragón del Apocalipsis.{fr} pour l’attaque du Dragon de l’Apocalypse.{pt-br} para o ataque do Dragão do Apocalipse.{de} für den Angriff des Apokalypse-Drachen konnte nicht gefunden werden."}),warningColor)
				end
			end
		end
	end

	if #attackable<1 then
		if #offMap==1 then return againstDragonResolveOffMapPlayer(offMap[1].playerIndex) end
		if #offMap>1 then
			local chooser=apocalypseDragonChoicePlayerIndex()
			local pending={type="offMap",playerIndex=chooser,options=offMap}
			gStates.apocalypseDragonPendingChoice=pending
			againstDragonShowOffMapChoice(pending)
			local chooserText=apocalypseDragonChoicePlayerLabel(chooser)
			againstDragonSetTurnReport("More than one eligible player is on the Portal.\n"..chooserText.." must choose who receives the Black mana marker; the Dragon will then destroy a target instead.","WaitingChoice")
			return true
		end
		againstDragonSetTurnReport("The Dragon had no eligible player left to attack this Round.","Processing")
		safeWaitFrames("Scenario",function() againstDragonCompleteTurn() end,1)
		return true
	end

	local tied,distance=againstDragonDistanceChoices(attackable,hexes,mapObjects)
	if #tied<1 then
		broadcastToAll("{en}The Apocalypse Dragon could not measure a revealed-space route to an eligible player.{ru}Дракон Апокалипсиса не смог определить путь по открытым клеткам до подходящего игрока.{zh-tw}末日巨龍無法計算沿已揭示空間前往合資格玩家的路線。{zh-cn}末日巨龙无法计算沿已揭示空间前往合资格玩家的路线。{ko}아포칼립스 드래곤이 공개된 칸을 따라 공격 가능한 플레이어까지의 경로를 계산하지 못했습니다.{es}El Dragón del Apocalipsis no pudo calcular una ruta por espacios revelados hasta un jugador válido.{fr}Le Dragon de l’Apocalypse n’a pas pu calculer un trajet par les cases révélées jusqu’à un joueur éligible.{pt-br}O Dragão do Apocalipse não conseguiu calcular uma rota por espaços revelados até um jogador elegível.{de}Der Apokalypse-Drache konnte keinen Weg über aufgedeckte Felder zu einem berechtigten Spieler bestimmen.",warningColor)
		againstDragonSetTurnReport("The Dragon could not measure a route to an eligible player.","Processing")
		safeWaitFrames("Scenario",function() againstDragonCompleteTurn() end,1)
		return true
	end
	if #tied==1 then return againstDragonBeginManualAttack(tied[1].playerIndex) end

	local chooser=apocalypseDragonChoicePlayerIndex()
	local pending={type="attack",playerIndex=chooser,options=tied,distance=distance}
	gStates.apocalypseDragonPendingChoice=pending
	againstDragonShowMapChoice(pending)
	local direction=gStates.apocalypseDragonLairRevealed==true and "closest to the Lair" or "furthest from the Portal"
	local chooserText=apocalypseDragonChoicePlayerLabel(chooser)
	againstDragonSetTurnReport("The Dragon has "..tostring(#tied).." tied players "..direction..".\n"..chooserText.." must pick the attacked player using the highlighted buttons.","WaitingChoice")
	return true
end

function againstDragonTargetChoiceSelect(player,mouseButton,id)
	if mouseButton~="-1" then return end
	local pending=gStates.apocalypseDragonPendingChoice
	if pending==nil or (pending.type~="destroy" and pending.type~="attack") then return end
	if apocalypseDragonChoiceAuthorized(player,pending)~=true then return end
	local index=tonumber(tostring(id or ""):match("DragonTargetChoice(%d+)$"))
	local option=index~=nil and pending.options[index] or nil
	if option==nil then return end
	gStates.apocalypseDragonPendingChoice=nil
	apocalypseDragonTurnChoiceClearButtons()
	gStates.apocalypseDragonUIState="Processing"
	if pending.type=="destroy" then againstDragonResolveDestroyOption(option)
	else
		local playerIndex=againstDragonPlayerIndexForMage(option.mage) or option.playerIndex
		againstDragonBeginManualAttack(playerIndex)
	end
end

function againstDragonOffMapChoiceSelect(player,mouseButton,id)
	if mouseButton~="-1" then return end
	local pending=gStates.apocalypseDragonPendingChoice
	if pending==nil or pending.type~="offMap" then return end
	if apocalypseDragonChoiceAuthorized(player,pending)~=true then return end
	local index=tonumber(tostring(id or ""):match("DragonOffMapChoice(%d+)$"))
	local option=index~=nil and pending.options[index] or nil
	if option==nil then return end
	gStates.apocalypseDragonPendingChoice=nil
	apocalypseDragonTurnChoiceClearButtons()
	gStates.apocalypseDragonUIState="Processing"
	local playerIndex=againstDragonPlayerIndexForMage(option.mage) or option.playerIndex
	againstDragonResolveOffMapPlayer(playerIndex)
end

function againstDragonAttackComplete(player,mouseButton,id)
	if mouseButton~="-1" then return end
	local pending=gStates.apocalypseDragonPendingAttack
	if pending==nil or againstDragonAttendanceAuthorized(player,pending)~=true then return end
	againstDragonFinishAttackForPlayer(pending.playerIndex)
end

againstDragonTurnAction=function(turnNumber)
	local players=tonumber(gStates.playerCount) or 1
	local n=tonumber(turnNumber) or 1
	if n>=5 then return "destroy" end
	if players<=1 then
		if n==1 then return "destroy" end
		if n==3 then return "attack" end
		return nil
	end
	if players==2 then
		if n==2 or n==4 then return "attack" end
		if n==3 then return "destroy" end
		return nil
	end
	if players==3 then
		if n==1 then return "destroy" end
		if n>=2 and n<=4 then return "attack" end
		return nil
	end
	if n>=1 and n<=4 then return "attack" end
	return nil
end

function againstDragonRoundStart()
	if againstDragonActive()~=true then return false end
	if gStates.apocalypseDragonRoundPrepared==gStates.currentRound then
		againstDragonPositionRoundOrderToken()
		return false
	end
	gStates.apocalypseDragonRoundPrepared=gStates.currentRound
	gStates.apocalypseDragonTurn=0
	gStates.apocalypseDragonTurnActive=false
	gStates.apocalypseDragonResumeTurn=nil
	gStates.apocalypseDragonPendingChoice=nil
	gStates.apocalypseDragonPendingAttack=nil
	gStates.apocalypseDragonFullAttendPlayer=nil
	gStates.apocalypseDragonUIState=nil
	gStates.apocalypseDragonTurnAction=nil
	gStates.apocalypseDragonTurnReport=nil
	gStates.apocalypseDragonTurnReportPrefix=nil
	UI.setAttribute("DummyTurn","active","false")
	automatedAttackResponseUI(nil)
	apocalypseDragonTurnChoiceClearButtons()
	againstDragonAttackControlUI(false)
	againstDragonClearBlackManaMarkers()
	againstDragonPositionRoundOrderToken()
	return true
end

function againstDragonBeginTurn(nextTurnNumber,newOutOfTurn,sameTurn)
	if againstDragonActive()~=true or gStates.tacticShown==true or gStates.tacticRemove==true then return false end
	if gStates.endRoundCalled==true or gStates.gameOver==true or gStates.apocalypseDragonLairAttacked==true then return false end
	if gStates.apocalypseDragonTurnActive==true then return true end
	gStates.apocalypseDragonTurnActive=true
	gStates.apocalypseDragonResumeTurn={turnNumber=nextTurnNumber,newOutOfTurn=newOutOfTurn==true,sameTurn=sameTurn==true}
	gStates.apocalypseDragonTurn=(gStates.apocalypseDragonTurn or 0)+1
	local dragonTurn=gStates.apocalypseDragonTurn
	local action=againstDragonTurnAction(dragonTurn) or "none"
	local ordinal=apocalypseDragonTurnOrdinal(dragonTurn)
	gStates.apocalypseDragonTurnAction=action
	gStates.apocalypseDragonUIState="ReadyToProcess"
	gStates.apocalypseDragonTurnReportPrefix=nil
	gStates.apocalypseDragonTurnReport="The Apocalypse Dragon's "..ordinal.." turn will "..againstDragonActionLabel(action)..".\nClick Process Dragon to continue."
	apocalypseDragonMainUIRefresh()
	mainUIUpdate("Dragon Turn Ready")
	return true
end

function againstDragonCompleteTurn()
	if againstDragonActive()~=true then return false end
	apocalypseDragonTurnChoiceClearButtons()
	againstDragonAttackControlUI(false)
	automatedAttackResponseUI(nil)
	gStates.apocalypseDragonPendingChoice=nil
	gStates.apocalypseDragonPendingAttack=nil
	gStates.apocalypseDragonTurnAction=nil
	gStates.apocalypseDragonUIState="ReadyToEnd"
	if gStates.apocalypseDragonTurnReport==nil or gStates.apocalypseDragonTurnReport=="" then
		gStates.apocalypseDragonTurnReport="The Apocalypse Dragon finished its turn."
	end
	apocalypseDragonMainUIRefresh()
	mainUIUpdate("Dragon Processed")
	return true
end

--Fury of the Apocalypse Dragon turn system --------------------------------------
--Fury uses the same interstitial turn shell as Against the Dragon, but its physical state alternates
--between Landed and In Flight. A stored flight target means the Dragon is in flight; nil means landed.
--This is intentionally new-game state only: Fury setup initializes the current Lair hex and no
--old-save recovery is attempted.
function furyDragonIsActive()
	return gStates~=nil and gStates.gameScenario=="Fury of the Apocalypse Dragon"
end

function furyDragonPositionRoundOrderToken()
	if furyDragonIsActive()~=true then return false end
	local token=getObjectFromGUID(apocalypseDragon.roundOrder)
	local bag=getObjectFromGUID(GUID.bag.apocalypseDragon)
	local target={-1.90,0.97,-18.00-(1.4*((#turnOrder or 0)+1))}
	if token==nil and bag~=nil then token=bag.takeObject({guid=apocalypseDragon.roundOrder,position=target,rotation={0,180,0},smooth=false}) end
	if token==nil then return false end
	token.unlock()
	token.setRotation({0,180,0})
	token.setPositionSmooth(target,false)
	safeWaitCondition("Scenario",function()
		local current=getObjectFromGUID(apocalypseDragon.roundOrder)
		if current~=nil then current.lock() end
	end,function()
		local current=getObjectFromGUID(apocalypseDragon.roundOrder)
		return current==nil or current.resting==true
	end)
	return true
end

function furyDragonRoundStart()
	if furyDragonIsActive()~=true then return false end
	if gStates.furyDragonRoundPrepared==gStates.currentRound then
		furyDragonPositionRoundOrderToken()
		return false
	end
	gStates.furyDragonRoundPrepared=gStates.currentRound
	gStates.apocalypseDragonTurn=0
	gStates.apocalypseDragonTurnActive=false
	gStates.apocalypseDragonResumeTurn=nil
	gStates.apocalypseDragonPendingChoice=nil
	gStates.apocalypseDragonPendingAttack=nil
	gStates.apocalypseDragonFullAttendPlayer=nil
	gStates.apocalypseDragonUIState=nil
	gStates.apocalypseDragonTurnAction=nil
	gStates.apocalypseDragonTurnReport=nil
	gStates.apocalypseDragonTurnReportPrefix=nil
	UI.setAttribute("DummyTurn","active","false")
	automatedAttackResponseUI(nil)
	apocalypseDragonTurnChoiceClearButtons()
	againstDragonAttackControlUI(false)
	furyDragonPositionRoundOrderToken()
	return true
end

function furyDragonBeginTurn(nextTurnNumber,newOutOfTurn,sameTurn)
	if furyDragonIsActive()~=true or gStates.tacticShown==true or gStates.tacticRemove==true then return false end
	if gStates.endRoundCalled==true or gStates.gameOver==true or gStates.apocalypseDragonDefeated==true then return false end
	if gStates.apocalypseDragonTurnActive==true then return true end
	gStates.apocalypseDragonTurnActive=true
	gStates.apocalypseDragonResumeTurn={turnNumber=nextTurnNumber,newOutOfTurn=newOutOfTurn==true,sameTurn=sameTurn==true}
	gStates.apocalypseDragonTurn=(gStates.apocalypseDragonTurn or 0)+1
	local dragonTurn=gStates.apocalypseDragonTurn
	local ordinal=apocalypseDragonTurnOrdinal(dragonTurn)
	local state=gStates.furyDragonFlightTarget~=nil and "in flight" or "landed"
	gStates.apocalypseDragonTurnAction="fury"
	gStates.apocalypseDragonUIState="ReadyToProcess"
	gStates.apocalypseDragonTurnReportPrefix=nil
	gStates.apocalypseDragonTurnReport="The Apocalypse Dragon is "..state.." for its "..ordinal.." turn.\nClick Process Dragon to continue."
	apocalypseDragonMainUIRefresh()
	mainUIUpdate("Fury Dragon Turn Ready")
	return true
end

furyDragonCompleteTurn=function(text)
	if furyDragonIsActive()~=true then return false end
	gStates.apocalypseDragonUIState="ReadyToEnd"
	gStates.apocalypseDragonTurnReport=text or "The Apocalypse Dragon finished its turn."
	apocalypseDragonMainUIRefresh()
	mainUIUpdate("Dragon Processed")
	return true
end

furyDragonFeatureMatches=function(feature,wanted)
	local name=string.lower(tostring(feature or ""))
	if wanted=="city" then return name:sub(1,4)=="city" end
	return name==wanted
end

furyDragonHexHasLiveRampager=function(hex,mapObjects)
	if hex==nil then return false end
	for _,enemy in ipairs(proxyMonstersOnHex(hex,mapObjects)) do
		if gStates.rampagingMonsters~=nil and gStates.rampagingMonsters[enemy.guid]==true then return true end
	end
	return false
end

furyDragonTargetCategory=function(hex,color,mapObjects)
	local categoryOrder=apocalypseDragon.furyColorCategories[color] or {}
	for categoryIndex,category in ipairs(categoryOrder) do
		for featureIndex,wanted in ipairs(apocalypseDragon.furyTargetCategories[category] or {}) do
			if furyDragonFeatureMatches(hex.feature,wanted)==true then
				if category~="rampager" or furyDragonHexHasLiveRampager(hex,mapObjects)==true then
					return category,(categoryIndex*100)+featureIndex,wanted
				end
			end
		end
	end
	return nil,nil,nil
end

furyDragonMapTilesAdjacent=function(a,b)
	if a==nil or b==nil then return false end
	if a.guid==b.guid then return true end
	local ap=a.getPosition()
	local bp=b.getPosition()
	local d=((ap[1]-bp[1])^2)+((ap[3]-bp[3])^2)
	return d>36 and d<45
end

furyDragonCurrentHex=function(hexes)
	if gStates.furyDragonCurrentHexKey==nil then return nil end
	return againstDragonMapHexByKey(hexes,gStates.furyDragonCurrentHexKey)
end

furyDragonLairTarget=function(hexes)
	local lair=gStates.apocalypseDragonLair
	if lair==nil then return nil end
	local key=lair.cityHexKey
	if key==nil and lair.tileGUID~=nil and lair.hexes~=nil and lair.hexes[1]~=nil then key=lair.tileGUID.."|"..tostring(lair.hexes[1].bearing) end
	local hex=key~=nil and againstDragonMapHexByKey(hexes,key) or nil
	if hex==nil then return nil end
	return {key=key,terrainGUID=hex.terrainGUID,bearing=hex.bearing,feature="",category="lair",isLair=true}
end

furyDragonLowestHead=function()
	local chosen=nil
	local chosenLevel=nil
	for _,headName in ipairs(apocalypseDragon.furyLowestHeadOrder or {}) do
		local level=tonumber(gStates.apocalypseDragonHeadLevels~=nil and gStates.apocalypseDragonHeadLevels[headName] or 0) or 0
		if chosenLevel==nil or level<chosenLevel then chosen=headName chosenLevel=level end
	end
	return chosen,chosenLevel
end

furyDragonTargetHead=function(target)
	if target==nil then return nil end
	local fixed=apocalypseDragon.furyCategoryHead[target.category]
	if fixed~=nil then return fixed end
	if target.category=="mana" or target.category=="lair" then return furyDragonLowestHead() end
	return nil
end

furyDragonTargetWouldOverflow=function(target)
	local head=furyDragonTargetHead(target)
	if head==nil then return false end
	local level=tonumber(gStates.apocalypseDragonHeadLevels~=nil and gStates.apocalypseDragonHeadLevels[head] or 0) or 0
	return level>=12
end

furyDragonChooseTarget=function(color,hexes,mapObjects)
	--The mod's Destroyed Site supply is an Infinite Bag, so Fury intentionally omits the printed
	--"all 16 Destroyed Site tokens used" redirect and only applies the no-target / level-12 redirects.
	local current=furyDragonCurrentHex(hexes)
	local lair=furyDragonLairTarget(hexes)
	if current==nil then return lair end
	local allowed={}
	for _,hex in ipairs(hexes or {}) do
		if hex.terrain~=nil and current.terrain~=nil and furyDragonMapTilesAdjacent(current.terrain,hex.terrain)==true then allowed[#allowed+1]=hex end
	end
	local distances=runtimeMapHexDistanceMap(allowed,{current})
	local currentKey=runtimeMapHexKey(current)
	local bestDistance=nil
	local bestPriority=nil
	local candidates={}
	for _,hex in ipairs(allowed) do
		local key=runtimeMapHexKey(hex)
		if key~=currentKey then
			local category,priority,wanted=furyDragonTargetCategory(hex,color,mapObjects)
			local distance=distances[key]
			if category~=nil and distance~=nil then
				local option={key=key,terrainGUID=hex.terrainGUID,bearing=hex.bearing,feature=hex.feature,category=category,wanted=wanted,isLair=false}
				if bestDistance==nil or distance<bestDistance or (distance==bestDistance and priority<bestPriority) then
					bestDistance=distance
					bestPriority=priority
					candidates={option}
				elseif distance==bestDistance and priority==bestPriority then
					candidates[#candidates+1]=option
				end
			end
		end
	end
	if #candidates<1 then return lair end
	local target=candidates[math.random(1,#candidates)]
	if furyDragonTargetWouldOverflow(target)==true then return lair end
	return target
end

furyDragonCityModelGUID=function(feature)
	local color=string.lower(tostring(feature or "")):match("^city%s+(%a+)")
	return color~=nil and cityModel[color] or nil
end

furyDragonCityCard=function(feature)
	local cityGUID=furyDragonCityModelGUID(feature)
	local cardGUID=cityGUID~=nil and gStates.cityCard~=nil and gStates.cityCard[cityGUID] or nil
	return cardGUID~=nil and getObjectFromGUID(cardGUID) or nil
end

furyDragonTargetPosition=function(target,hexes,forDragon)
	if target==nil then return nil end
	if furyDragonCityModelGUID(target.feature)~=nil then
		local card=furyDragonCityCard(target.feature)
		if card~=nil then
			local p=card.getPosition()
			return {p[1],p[2]+(forDragon==true and 1.30 or 0.85),p[3]}
		end
	end
	local hex=againstDragonMapHexByKey(hexes,target.key)
	if hex==nil then return nil end
	return {hex.position[1],forDragon==true and 1.45 or 1.65,hex.position[3]}
end

furyDragonManaColor=function(die)
	if die==nil then return nil end
	local value=string.lower(tostring(die.getRotationValue() or ""))
	return value:match("^(%a+)")
end

furyDragonTargetLabel=function(target)
	if target==nil then return "the Lair" end
	if target.isLair==true then return "the Lair" end
	local label=proxyFeatureDisplayName~=nil and proxyFeatureDisplayName(target.feature) or tostring(target.feature or "space")
	return tostring(label)
end

furyDragonMoveMarkerOffMap=function()
	local marker=getObjectFromGUID(apocalypseDragon.furyMarker)
	if marker==nil then return false end
	--Leaving a shared map hex may let the pieces left behind collapse back toward the centre.
	if mapTokenReleaseObject~=nil then mapTokenReleaseObject(marker) end
	marker.unlock()
	marker.setRotation({0,180,0})
	marker.setPositionSmooth(apocalypseDragon.furyHoldingPosition,false)
	local guid=marker.guid
	mapTokenAfterSettled(guid,function(current)
		if current~=nil then current.lock() end
	end)
	return true
end

furyDragonBeginLandedTurn=function()
	if furyDragonIsActive()~=true then return false end
	gStates.apocalypseDragonUIState="Processing"
	gStates.apocalypseDragonTurnReport="The landed Apocalypse Dragon is rolling its mana die."
	apocalypseDragonMainUIRefresh()
	local bag=getObjectFromGUID(GUID.bag.spareDice)
	if bag==nil then return furyDragonCompleteTurn("The spare mana-die bag is missing; the Apocalypse Dragon could not choose a flight target.") end
	local die=bag.takeObject({position=apocalypseDragon.furyDieRollPosition,rotation={0,180,0},smooth=false})
	if die==nil then return furyDragonCompleteTurn("The Apocalypse Dragon could not draw its mana die.") end
	gStates.furyDragonManaDieGUID=die.guid
	die.unlock()
	die.randomize()
	local dieGUID=die.guid
	safeWaitFrames("Scenario",function()
		safeWaitCondition("Scenario",function()
			local currentDie=getObjectFromGUID(dieGUID)
			if currentDie==nil then
				gStates.furyDragonManaDieGUID=nil
				furyDragonCompleteTurn("The Apocalypse Dragon's mana die disappeared before a target could be chosen.")
				return
			end
			local color=furyDragonManaColor(currentDie)
			local hexes,mapObjects=runtimeMapHexesAndObjects()
			local target=furyDragonChooseTarget(color,hexes,mapObjects)
			if target==nil then
				local spare=getObjectFromGUID(GUID.bag.spareDice)
				if spare~=nil then currentDie.unlock() spare.putObject(currentDie) end
				gStates.furyDragonManaDieGUID=nil
				furyDragonCompleteTurn("The Apocalypse Dragon could not resolve its Lair or a legal flight target.")
				return
			end
			local destination=furyDragonTargetPosition(target,hexes,false)
			if destination==nil then
				local spare=getObjectFromGUID(GUID.bag.spareDice)
				if spare~=nil then currentDie.unlock() spare.putObject(currentDie) end
				gStates.furyDragonManaDieGUID=nil
				furyDragonCompleteTurn("The Apocalypse Dragon's chosen flight target could not be located.")
				return
			end
			gStates.furyDragonFlightTarget=target
			currentDie.unlock()
			currentDie.setPositionSmooth(destination,false)
			if furyDragonMoveMarkerOffMap()~=true then
				local spare=getObjectFromGUID(GUID.bag.spareDice)
				if spare~=nil then currentDie.unlock() spare.putObject(currentDie) end
				gStates.furyDragonManaDieGUID=nil
				gStates.furyDragonFlightTarget=nil
				furyDragonCompleteTurn("The Fury Apocalypse Dragon marker is missing; the flight target was cancelled.")
				return
			end
			local targetText=furyDragonTargetLabel(target)
			local colorText=color~=nil and color:gsub("^%l",string.upper) or "Unknown"
			safeWaitCondition("Scenario",function()
				local settled=getObjectFromGUID(dieGUID)
				if settled~=nil then settled.lock() end
				local dragon=getObjectFromGUID(apocalypseDragon.furyMarker)
				if dragon~=nil then dragon.lock() end
				furyDragonCompleteTurn("The Apocalypse Dragon rolled "..colorText.." and is now in flight toward "..targetText..".")
			end,function()
				local settling=getObjectFromGUID(dieGUID)
				local dragon=getObjectFromGUID(apocalypseDragon.furyMarker)
				local dieReady=settling==nil or settling.resting==true
				local dragonReady=dragon==nil or dragon.resting==true
				return dieReady and dragonReady
			end)
		end,function()
			local current=getObjectFromGUID(dieGUID)
			return current==nil or current.resting==true
		end)
	end,2)
	return true
end

furyDragonPlayersOnTarget=function(target,hexes,mapObjects)
	local players={}
	for playerIndex,details in ipairs(turnOrder or {}) do
		if details~=nil and details.mage~=gStates.positionMageKnight[5] and playerDropoutInactive(playerIndex)==false then
			local onTarget=false
			if furyDragonCityModelGUID(target.feature)~=nil and details.avatarLocation==target.feature then
				onTarget=true
			else
				local playerHex=againstDragonPlayerHex(hexes,mapObjects,playerIndex)
				onTarget=playerHex~=nil and runtimeMapHexKey(playerHex)==target.key
			end
			if onTarget==true then players[#players+1]=playerIndex end
		end
	end
	return players
end

furyDragonDiscardHexEnemies=function(hex,mapObjects)
	for _,enemy in ipairs(proxyMonstersOnHex(hex,mapObjects)) do
		if getObjectFromGUID(enemy.guid)~=nil then proxyDiscardMonster(enemy) end
	end
end

furyDragonDestroyHex=function(hex,mapObjects,removeEnemies)
	if hex==nil then return false end
	if removeEnemies==true then furyDragonDiscardHexEnemies(hex,mapObjects) end
	local bag=getObjectFromGUID(GUID.bag.destroyedSite)
	if bag==nil then
		broadcastToAll(joinLang({"{en}The Destroyed Site bag is missing; Fury could not mark {ru}Мешок жетонов разрушенных мест отсутствует; Ярость не смогла отметить {zh-tw}缺少「被摧毀地點」標記袋；巨龍之怒無法將 {zh-cn}缺少“被摧毁地点”标记袋；巨龙之怒无法将 {ko}파괴된 장소 주머니가 없습니다. 분노가 {es}Falta la bolsa de Sitio Destruido; Furia no pudo marcar {fr}Le sac Site Détruit est manquant ; la Fureur n’a pas pu marquer {pt-br}A bolsa de Local Destruído está ausente; Fúria não pôde marcar {de}Der Beutel für zerstörte Orte fehlt; Zorn konnte ",furyDragonTargetLabel({feature=hex.feature}),"{en} as destroyed.{ru} как разрушенное.{zh-tw} 標記為被摧毀。{zh-cn} 标记为被摧毁。{ko}을(를) 파괴됨으로 표시하지 못했습니다.{es} como destruido.{fr} comme détruit.{pt-br} como destruído.{de} nicht als zerstört markieren."}),warningColor)
		return false
	end
	local token=takeDestroyedSiteToken(hex.terrain,hex.bearing)
	if token==nil then return false end
	return destroySite(token,hex.terrain,hex.bearing)
end

furyDragonRemoveCityDefender=function(feature)
	local cityGUID=furyDragonCityModelGUID(feature)
	local defenders=cityGUID~=nil and gStates.cityMonsterQty~=nil and gStates.cityMonsterQty[cityGUID] or nil
	if defenders==nil then return false,nil end
	local lowest=nil
	local tied={}
	for guid,state in pairs(defenders) do
		if guid~="extra" and state=="alive" then
			local obj=getObjectFromGUID(guid)
			if obj~=nil then
				local fame=tonumber((monsterPugs[guid] or {}).fame) or 0
				if lowest==nil or fame<lowest then lowest=fame tied={{guid=guid,obj=obj}}
				elseif fame==lowest then tied[#tied+1]={guid=guid,obj=obj} end
			end
		end
	end
	if #tied<1 then return false,nil end
	local chosen=tied[math.random(1,#tied)]
	defenders[chosen.guid]="dead"
	local name=(monsterPugs[chosen.guid] or {}).name or "City defender"
	proxyDiscardMonster(chosen.obj)
	return true,name
end

furyDragonIncreaseHead=function(headName)
	if headName==nil then return false end
	local current=tonumber(gStates.apocalypseDragonHeadLevels~=nil and gStates.apocalypseDragonHeadLevels[headName] or 0) or 0
	if current>=12 then return false end
	return apocalypseDragonSetHeadLevel(headName,current+1)
end

furyDragonResolveArrivalEffect=function(target,hex,mapObjects)
	if target==nil or hex==nil then return "The Dragon landed, but its target could not be resolved." end
	if target.isLair==true or target.category=="lair" then
		local head=furyDragonLowestHead()
		local raised=furyDragonIncreaseHead(head)
		return "The Apocalypse Dragon returned to its Lair."..(raised==true and " "..tostring(head).." increased by 1 level." or "")
	end
	local head=furyDragonTargetHead(target)
	local action=""
	if target.category=="fortified" then
		if furyDragonCityModelGUID(target.feature)~=nil then
			local removed,name=furyDragonRemoveCityDefender(target.feature)
			if removed==true then action="The Dragon destroyed "..tostring(name).." in the City."
			else
				furyDragonDestroyHex(hex,mapObjects,false)
				action="The undefended City space was destroyed."
			end
		else
			furyDragonDestroyHex(hex,mapObjects,true)
			action="The "..furyDragonTargetLabel(target).." was destroyed."
		end
	elseif target.category=="adventure" then
		furyDragonDestroyHex(hex,mapObjects,true)
		action="The "..furyDragonTargetLabel(target).." was destroyed."
	elseif target.category=="rampager" then
		local victim=nil
		for _,enemy in ipairs(proxyMonstersOnHex(hex,mapObjects)) do
			if gStates.rampagingMonsters~=nil and gStates.rampagingMonsters[enemy.guid]==true then victim=enemy break end
		end
		if victim~=nil then
			local name=(monsterPugs[victim.guid] or {}).name or "Rampaging Enemy"
			proxyDiscardMonster(victim)
			action="The Dragon destroyed "..tostring(name).."."
		else
			head=nil
			action="The Dragon landed where its Rampaging Enemy target had been, but that enemy was no longer present."
		end
	elseif target.category=="inhabited" or target.category=="mana" then
		furyDragonDestroyHex(hex,mapObjects,false)
		action="The "..furyDragonTargetLabel(target).." was destroyed."
	end
	local raised=head~=nil and furyDragonIncreaseHead(head) or false
	if raised==true then action=action.." "..tostring(head).." increased by 1 level." end
	return action
end

furyDragonBeginInFlightTurn=function()
	if furyDragonIsActive()~=true then return false end
	local target=gStates.furyDragonFlightTarget
	if target==nil then return furyDragonBeginLandedTurn() end
	gStates.apocalypseDragonUIState="Processing"
	gStates.apocalypseDragonTurnReport="The Apocalypse Dragon is flying to "..furyDragonTargetLabel(target).."."
	apocalypseDragonMainUIRefresh()
	local hexes,mapObjects=runtimeMapHexesAndObjects()
	local hex=againstDragonMapHexByKey(hexes,target.key)
	local destination=furyDragonTargetPosition(target,hexes,true)
	local marker=getObjectFromGUID(apocalypseDragon.furyMarker)
	if hex==nil or destination==nil or marker==nil then
		return furyDragonCompleteTurn("The Apocalypse Dragon could not locate its marked flight destination.")
	end

	local die=gStates.furyDragonManaDieGUID~=nil and getObjectFromGUID(gStates.furyDragonManaDieGUID) or nil
	local spare=getObjectFromGUID(GUID.bag.spareDice)
	if die~=nil and spare~=nil then die.unlock() spare.putObject(die) end
	gStates.furyDragonManaDieGUID=nil

	local markerGUID=marker.guid
	marker.lock()
	local started=mapTokenSettleArrival(markerGUID,destination,{force=true,rotation={0,180,0}},function(landed)
		if landed==nil then
			furyDragonCompleteTurn("The Apocalypse Dragon marker disappeared while landing.")
			return
		end
		gStates.furyDragonCurrentHexKey=target.key
		gStates.furyDragonFlightTarget=nil
		local currentHexes,currentMapObjects=runtimeMapHexesAndObjects()
		local currentHex=againstDragonMapHexByKey(currentHexes,target.key)
		if currentHex==nil then
			furyDragonCompleteTurn("The Apocalypse Dragon landed, but the destination space could no longer be resolved.")
			return
		end
		local players=furyDragonPlayersOnTarget(target,currentHexes,currentMapObjects)
		if #players>0 then
			local names={}
			for _,playerIndex in ipairs(players) do names[#names+1]=tostring(turnOrder[playerIndex].mage) end
			gStates.furyDragonAwaitingCombat={players=players,target=target}
			gStates.apocalypseDragonUIState="WaitingCombat"
			gStates.apocalypseDragonTurnReport="The Apocalypse Dragon attacks "..table.concat(names,", ")..". Resolve combat against the landed Dragon. When combat is finished, click Combat Resolved; the Dragon will immediately take its required landed turn."
			apocalypseDragonMainUIRefresh()
			mainUIUpdate("Fury Dragon Combat")
			return
		end
		local result=furyDragonResolveArrivalEffect(target,currentHex,currentMapObjects)
		furyDragonCompleteTurn(result)
	end)
	if started~=true then return furyDragonCompleteTurn("The Apocalypse Dragon could not begin its landing move.") end
	return true
end

function furyDragonProcessTurn()
	if furyDragonIsActive()~=true or gStates.apocalypseDragonTurnActive~=true then return false end
	if gStates.apocalypseDragonUIState=="WaitingCombat" then
		gStates.furyDragonAwaitingCombat=nil
		return furyDragonBeginLandedTurn()
	end
	if gStates.apocalypseDragonUIState~="ReadyToProcess" then return false end
	if gStates.furyDragonFlightTarget~=nil then return furyDragonBeginInFlightTurn() end
	return furyDragonBeginLandedTurn()
end

cityCardExploreOffsets={{-1.2, 1.09, 6.23},{4.8, 1.09, 4.15},{-6, 1.09, 2.08},{6, 1.09, -2.08},{-4.8, 1.09, -4.15},{1.2, 1.09, -6.23},
	{-2.4, 1.09, 12.46},{3.6, 1.09, 10.24},{9.6, 1.09, 8.23},{10.82, 1.09, 2.12},{12, 1.09, -4.16},{7.2, 1.09, -8.33},
	{2.4, 1.09, -12.46},{-3.6, 1.09, -10.24},{-9.6, 1.09, -8.3},{-10.82, 1.09, -2.12},{-12, 1.09, 4.16},{-7.2, 1.09, 8.33},
	{-3.6, 1.09, 18.69},{-8.4, 1.09, 14.54},{-13.2, 1.09, 10.39},{-18, 1.09, 6.24},
	{18, 1.09, -6.24},{13.2, 1.09, -10.39},{8.4, 1.09, -14.54},{3.6, 1.09, -18.69}}

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
		{tag="Button", attributes={id=prefix.."FracturedDone", onMouseDown="global/buttonClicked", onMouseUp="global/buttonClicked", onClick="global/fracturedLandsOrientationDone", height=150, width=400, color="rgba(0,0,0,0.0)", position="0 "..buttonY.." "..buttonZ, rotation="0 0 180", scale=buttonScale}, children={{tag="Image", attributes={id=prefix.."FracturedDoneImage", image="Sliced Button/Button Object Active", type="Sliced"}}, {tag="Text", attributes={font="Fonts/MKCardText", fontSize=90, color="black", fontStyle="Normal", alignment="MiddleCenter", text="Done"}}}},
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

function volkareCampMapPositionForPlayer(playerIndex)
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

function volkareCampHexInfoAtPosition(position)
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

function volkarePursuitHexUsed(hexKey)
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

function volkarePursuitAvailable(playerIndex)
	local player=turnOrder[playerIndex]
	if player==nil or gStates.preEndTurn==true or playerIndex~=gStates.turnNumber or player.combatIconHide~="None" then return nil end
	local token=getObjectFromGUID(player.turnOrderTokenGUID)
	if token==nil or token.is_face_down==true then return nil end
	local info=volkareCampPlayerHexInfo(playerIndex)
	if info==nil or volkarePursuitHexUsed(info.key)==true then return nil end
	return info
end

function volkarePursuitDropShield(playerIndex,combat)
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
	broadcastToAll(joinLang({translateWord[player.mage],"{en} marked a Volkare Pursuit hex.{ru} отметил гекс преследования Волкара.{zh-cn}标记了一个沃卡里追击格。{ko}: 볼케어 추격 칸을 표시했습니다.{es} marcó un hexágono de Persecución de Volkare.{fr} a marqué un hexagone de Poursuite de Volkare.{pt-br} marcou um hexágono de Perseguição de Volkare.{de} hat ein Feld für die Verfolgung Volkares markiert."}),positionToColor(playerIndex))
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
	terrainTiles[city.terrain].hexFeature.center="raised "..cityColor[city.model]
	if gStates.hexOverideSave[city.terrain]==nil then gStates.hexOverideSave[city.terrain]={} end
	gStates.hexOverideSave[city.terrain].center="raised "..cityColor[city.model]
	local cityZone={[cityModel.blue]=GUID.zone.blueCity, [cityModel.red]=GUID.zone.redCity, [cityModel.green]=GUID.zone.greenCity, [cityModel.white]=GUID.zone.whiteCity}
	getObjectFromGUID(cityScriptZones[cityZone[city.model]].cityCard).setDescription("Raised City - Provides no Interaction")
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
		broadcastToAll("WARNING: Volkare is four spaces from the Portal. If he moves within three spaces, the Council of the Void will close it.", {1,0.65,0.15})
	end
	if distance>closeDistance then return false end
	gStates.volkarePortalClosed=true
	gStates.volkarePortalWarningShown=true
	local decals=portalTile.getDecals() or {}
	local marked=false
	for _, decal in pairs(decals) do if decal.name=="Portal Closed" then marked=true break end end
	if marked==false then portalTile.addDecal({name="Portal Closed",url=volkarePortalClosedDecalURL,position={0,0.15,0},rotation={90,180,0},scale={0.88,0.88,1}}) end
	broadcastToAll("The Council of the Void has closed the Portal. From now on it is an ordinary space, and Volkare may be attacked there.", {1,0.45,0.15})
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
function oneToReturnPortalTile()
	return volkareQuestPortalTile()
end

function oneToReturnSetPortalClosedDecal(closed)
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
	broadcastToAll("The Portal has closed. From now on it is an ordinary plains space until the end of the second Night.", warningColor)
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

function oneToReturnPortalOccupant()
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

function currentMageAvatarPosition(playerIndex)
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

function gladeFreeCheck()
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
		local proxyAvatar=proxyPlayerActive()==true and player.mage==gStates.positionMageKnight[5]
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
	broadcastToAll(joinLang({"{en}At Least {ru}Как минимум {zh-cn}至少{ko}최소 {es}Al menos {fr}Au moins {pt-br}Pelo menos {de}Zumindest ", tostring(threshold), "{en} of Volkare's Army defeated, he skips his next turn.{ru} отряда из армии Волкара побеждено, он пропускает следующий ход{zh-cn}个敌人被击败了, 沃里卡跳过了他的回合. {ko}개의 볼케어 군대 적 토큰을 제거했기에, 볼케어의 차례를 건너뜁니다{es} de los ejércitos de Volkare derrotados, se salta su siguiente turno.{fr} de l'armée de Volkare vaincus, il saute son prochain tour.{pt-br} do exército de Volkare derrotado, ele pulará seu próximo turno.{de} von Volkare's Armee besiegt, überspringt er seinen nächsten Zug."}), {1,1,0.5})
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

function mineLiberatedForClaim(playerIndex, terrainGUID, hexPos)
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

function mineClaimData(playerIndex)
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
	UI.setAttribute("MineClaimChoiceTitle", "text", pending.source=="Quest" and "Quest Crystal" or "Mined Crystal")
	for i=1, 4 do
		local color=pending.colors[i]
		UI.setAttribute("MineClaimButton"..i, "active", color~=nil and "true" or "false")
		if color~=nil then UI.setAttribute("MineClaimButtonText"..i, "text", color) end
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
		if messageColor~=nil then broadcastToColor("No crystal gained from the Mine: your Inventory already has 3 of every available color.", messageColor, warningColor)
		else broadcastToAll("No crystal gained from the Mine: your Inventory already has 3 of every available color.", warningColor) end
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
		broadcastToColor("Only the claiming player can choose this "..sourceName.." crystal.", player.color, {1,0.3,0.3})
		return
	end
	local index=tonumber(id:match("(%d+)$"))
	local color=index~=nil and pending.colors[index] or nil
	if color==nil then return end
	if mineCrystalCount(pending.playerIndex, color)>=3 then
		broadcastToColor("You already have 3 "..color.." crystals in your Inventory.", player.color, warningColor)
		return
	end
	local bagKey=mineCrystalBagKey[color]
	local bag=bagKey~=nil and getObjectFromGUID(GUID.bag.mana[bagKey]) or nil
	if bag==nil or bag.getQuantity()==0 then
		broadcastToColor("No "..color.." crystal is available in the supply.", player.color, {1,0.3,0.3})
		return
	end
	local questCardGUID=pending.questCardGUID
	takeManaCrystal(bag,{position=mineInventoryPosition(pending.playerIndex, color),smooth=false})
	broadcastToColor("Claimed a "..color.." Crystal from the "..sourceName..".", player.color, {1,1,0.5})
	gStates.mineClaimPending=nil
	UI.hide("MineClaimChoice")
	if questCardGUID~=nil and getObjectFromGUID(questCardGUID)~=nil then apocalypseQuestUpdateProgressButtons(getObjectFromGUID(questCardGUID)) end
	if mainUIUpdate~=nil then mainUIUpdate("Mine crystal claimed") end
end

function scenarioEnd(endImmediately)
	if gStates.endGameAchieved=="false" then
		UI.setAttribute("EndGameButtonText", "text", "{en}Scenario End Achieved - Yes{ru}Конец сценария достигнут - Да{zh-tw}達成劇本結束 - 是{zh-cn}達成剧本结束 - 是{ko}시나리오 종료 조건 충족 됨{es}Escenario Fin Realizados - Sí{fr}Scénario Fin Atteint - Oui{pt-br}Fim do Cenário Alcançado - Sim{de}Szenarioziel Erreicht – Ja")
		UI.setAttribute("EndGameButtonImage", "image", "Sliced Button/Button New Deactive")
		UI.setAttribute("EndGameButtonImage", "color", "rgb(1.0,0.7,0.2)")
		gStates.endGameAchieved="started"
		turnOrder[gStates.realTurn].gameEnder=true
		establishFinalTurnBoundary("victory", gStates.realTurn)
		if gStates.gameScenario=="The Gauntlet" or gStates.gameScenario=="Quest for the Golden Grail" then
			broadcastToAll("{en}Congratulations{ru}Поздравляем{zh-cn}恭喜{ko}축하합니다{es}Felicidades{fr}Toutes nos félicitations{pt-br}Parabéns{de}Glückwunsch", {1,1,0.5})
			gStates.endGameAchieved="true"
			gStates.gameOver=true
			mainUIUpdate("Scenario End")
		elseif endImmediately==true then
			gStates.endGameAchieved="true"
			gStates.gameOver=true
			mainUIUpdate("Game Over")
		else
			broadcastToAll("{en}Final Round of Turns Started{ru}Начался последний круг ходов{zh-cn}最终轮的回合开始了{ko}마지막 턴 시작{es}Inicio de la Ultima Ronda de Turnos{fr}Dernier Rounde de Tours Commencé{pt-br}Rodada Final de Turnos começou{de}Die letzte Runde hat begonnen", {1,1,0.5})
		end
	else
		UI.setAttribute("EndGameButtonText", "text", "{en}Scenario End Achieved - No{ru}Конец сценария достигнут - Нет{zh-tw}達成劇本結束 - 否{zh-cn}達成剧本结束 - 否{ko}시나리오 종료 조건 충족 전{es}Escenario Fin Realizados - No{fr}Scénario Fin Atteint - Non{pt-br}Fim do Cenário Alcançado - Não{de}Szenarioziel Erreicht – Nein")
		UI.setAttribute("EndGameButtonImage", "image", "Sliced Button/Button New Active")
		UI.setAttribute("EndGameButtonImage", "color", "white")
		UI.setAttribute("PreEndTurnImage", "image", "Sliced Button/Button New Active")
		UI.setAttribute("PreEndTurn", "interactable", "True")
		gStates.gameOver=false
		for _, turnDetails in pairs(turnOrder) do turnDetails.gameEnder=false end
		if gStates.finalTurnReason=="victory" then clearFinalTurnBoundary() else ensureFinalTurnBoundary() end
		gStates.endGameAchieved=(gStates.finalTurnReason=="endRound" and gStates.currentRound==gStates.rounds) and "true" or "false"
		broadcastToAll("{en}Turn order resumed{ru}Порядок хода восстановлен{zh-cn}回合顺序恢复了{ko}턴 순서가 재개되었습니다{es}Se reanudó el orden de turno{fr}L'ordre des tours a repris{pt-br}Ordem de Turno retomada{de}Reihenfolge der Drehung wieder aufgenommen", {1,1,0.5})
		mainUIUpdate("Scenario End")
	end
	refreshCoopCompSkillXs()
end

--Dungeon Lords secret entrances remember the exact Village/Monastery that created each placement request.
--That lets the drop validator enforce the scenario's adjacency rule instead of accepting any empty map hex.
function dungeonLordsPendingSecretName(entry)
	if type(entry)=="table" then return entry.siteType or entry.name end
	return entry
end

function dungeonLordsSecretSourceFeature(secretName)
	if secretName=="Secret Dungeon" then return "village" end
	if secretName=="Secret Tomb" then return "monastery" end
	return nil
end

function dungeonLordsWorldHexDistance(fromPos,toPos)
	if fromPos==nil or toPos==nil then return nil end
	local function nearest(value) if value>=0 then return math.floor(value+0.5) end return math.ceil(value-0.5) end
	local dHor=nearest((toPos[3]-fromPos[3])/2.0785)
	local dVec=nearest(((toPos[1]-fromPos[1])/2.4)+(dHor/2))
	return math.max(math.abs(dHor),math.abs(dVec),math.abs(dVec-dHor))
end

function dungeonLordsSecretSourcePosition(entry)
	if type(entry)~="table" then return nil end
	local terrain=entry.sourceTerrainGUID~=nil and getObjectFromGUID(entry.sourceTerrainGUID) or nil
	if terrain~=nil and entry.sourceBearing~=nil then
		local xy=angleToXY(terrain,tostring(entry.sourceBearing))
		return {xy[1],terrain.getPosition()[2],xy[2]}
	end
	return entry.sourcePosition
end

function dungeonLordsSecretSpaceBasicLegal(terrain,bearing)
	if terrain==nil or bearing==nil or terrainTiles[terrain.guid]==nil then return false end
	local details=terrainTiles[terrain.guid]
	local key=tostring(bearing)
	local feature=details.hexFeature~=nil and details.hexFeature[key] or nil
	local terrainType=details.hexType~=nil and details.hexType[key] or nil
	local noSite=feature=="" or feature=="rampaging" or feature=="draconum"
	return noSite==true and terrainType~=nil and terrainType~="swamp" and terrainType~="lake" and terrainType~="mountain" and terrainType~="ocean"
end

function dungeonLordsFindAdjacentSecretSource(secretName,destinationPosition)
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
					if dungeonLordsWorldHexDistance(sourcePos,destinationPosition)==1 then
						return {siteType=secretName,sourceTerrainGUID=terrain.guid,sourceBearing=tostring(sourceBearing),sourcePosition=sourcePos}
					end
				end
			end
		end
	end
	return nil
end

function dungeonLordsSecretDestinationLegal(terrain,bearing,request)
	if dungeonLordsSecretSpaceBasicLegal(terrain,bearing)~=true then return false,nil end
	local xy=angleToXY(terrain,tostring(bearing))
	local destinationPosition={xy[1],terrain.getPosition()[2],xy[2]}
	local normalized=request
	if type(normalized)~="table" then normalized=dungeonLordsFindAdjacentSecretSource(dungeonLordsPendingSecretName(request),destinationPosition) end
	local sourcePosition=dungeonLordsSecretSourcePosition(normalized)
	if sourcePosition==nil or dungeonLordsWorldHexDistance(sourcePosition,destinationPosition)~=1 then return false,normalized end
	return true,normalized
end

function dungeonLordsSecretLegalDestinationCount(request)
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

function dungeonLordsSecretRequestMatches(a,b)
	if dungeonLordsPendingSecretName(a)~=dungeonLordsPendingSecretName(b) then return false end
	if type(a)~="table" or type(b)~="table" then return false end
	return a.sourceTerrainGUID==b.sourceTerrainGUID and tostring(a.sourceBearing)==tostring(b.sourceBearing)
end

function dungeonLordsQueueSecretRequest(request,quiet)
	if request==nil then return false end
	gStates.locationPlace=gStates.locationPlace or {}
	for _,existing in ipairs(gStates.locationPlace) do if dungeonLordsSecretRequestMatches(existing,request)==true then return false end end
	if dungeonLordsSecretLegalDestinationCount(request)==0 then
		if quiet~=true then
			local source=dungeonLordsSecretSourceFeature(dungeonLordsPendingSecretName(request)) or "site"
			broadcastToAll("Dungeon Lords: no legal space exists next to the revealed "..source.."; no secret entrance is placed.",{1,0.75,0.2})
		end
		return false
	end
	gStates.locationPlace[#gStates.locationPlace+1]=request
	return true
end

function dungeonLordsPruneImpossibleSecretRequests()
	gStates.locationPlace=gStates.locationPlace or {}
	local removed=false
	for i=#gStates.locationPlace,1,-1 do
		local request=gStates.locationPlace[i]
		if dungeonLordsSecretLegalDestinationCount(request)==0 then
			local source=dungeonLordsSecretSourceFeature(dungeonLordsPendingSecretName(request)) or "site"
			broadcastToAll("Dungeon Lords: no legal space remains next to the revealed "..source.."; that secret entrance is skipped.",{1,0.75,0.2})
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
			if pendingName~=nil then broadcastToAll("Dungeon Lords: place the requested "..tostring(pendingName).." first.",{1,0.55,0.2})
			else broadcastToAll("Dungeon Lords: that secret entrance has not been requested by a newly revealed Village or Monastery.",{1,0.55,0.2}) end
			return true
		end
		local legal,normalized=dungeonLordsSecretDestinationLegal(terrain,bearing,pending)
		if legal~=true then
			broadcastToAll("Dungeon Lords: the secret entrance must be on an accessible, non-Swamp empty space adjacent to the Village or Monastery that created it.",{1,0.55,0.2})
			return true
		end
		terrainTiles[terrain.guid].hexFeature[tostring(bearing)]=site
		if gStates.hexOverideSave[terrain.guid]==nil then gStates.hexOverideSave[terrain.guid]={} end
		gStates.hexOverideSave[terrain.guid][tostring(bearing)]=site
		normalized.destinationTerrainGUID=terrain.guid
		normalized.destinationBearing=tostring(bearing)
		gStates.dungeonLordsSecretSiteOrigins[obj.guid]=normalized
		obj.lock()
		broadcastToAll(joinLang({translateWord[secretName], "{en} located.{ru} размещена(о).{zh-cn} 坐落于{ko} 설치됨{es} situado.{fr} situé.{pt-br} localizado.{de} liegt."}), {1,1,0.5})
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
		terrainTiles[terrain.guid].hexFeature[tostring(bearing)]=""
		if gStates.hexOverideSave[terrain.guid]==nil then gStates.hexOverideSave[terrain.guid]={} end
		gStates.hexOverideSave[terrain.guid][tostring(bearing)]=""
		gStates.dungeonLordsSecretSiteOrigins[obj.guid]=nil
		broadcastToAll(joinLang({translateWord[secretName], "{en} removed.{ru} удалена(о).{zh-cn} 移除的{ko} 제거됨{es} remoto.{fr} supprimé.{pt-br} removido.{de} entfernt."}), {1,1,0.5})
		dungeonLordsQueueSecretRequest(origin,true)
		dungeonLordsPruneImpossibleSecretRequests()
		mainUIUpdate("Need Token")
		moveDisplayTerrainCache={signature=nil,hexMap=nil}
		updateMoveDisplay()
		return true
	end
	return true
end

local pause=false

--Four Horsemen helpers. The Horsemen use one persistent Custom_Tile GUID each; setHorsemanLevel()
--swaps only the front image (once level art is supplied) and replaces that GUID's normal monster data.
--Cards/neutral level Shields are therefore not required by the scripted implementation.
function horsemanDataFor(ref)
	if ref==nil or horsemanData==nil then return nil, nil end
	local key=tostring(ref)
	if horsemanData[key]~=nil then return horsemanData[key], key end
	local name=horsemanTokenToName~=nil and horsemanTokenToName[key] or nil
	if name~=nil then return horsemanData[name], name end
	return nil, nil
end

function horsemanMonsterData(ref, level)
	local data,name=horsemanDataFor(ref)
	level=math.max(1,math.min(6,tonumber(level) or 1))
	local levelData=data~=nil and data.levels~=nil and data.levels[level] or nil
	if data==nil or levelData==nil then return nil end
	---@type table<string, any>
	local abilities={
		name="Horseman - "..name,
		pugType="horseman",
		horseman=name,
		fame=levelData.fame,
		armour=levelData.armour,
		attack={[data.attackType]={[1]=levelData.attack}},
		reward=1,
		faction="Apoc",
	}
	for ability,value in pairs(data.abilities or {}) do abilities[ability]=value end
	return abilities
end

function horsemanPriorityDescription(ref)
	local data,name=horsemanDataFor(ref)
	if data==nil then return "" end
	local state=gStates~=nil and gStates.horsemen~=nil and gStates.horsemen[name] or nil
	local level=state~=nil and state.level or nil
	local heading="[00ff00]HORSEMAN - "..string.upper(name)..(level~=nil and " (LEVEL "..tostring(level)..")" or "").."[-]\n"
	return heading..
		"Priority A: "..data.priorityText.A.."\n"..
		"Priority B: "..data.priorityText.B.."\n"..
		"Priority C: "..data.priorityText.C.."\n\n"
end

--Small map tokens can legitimately share one hex. Keep enemy-like tokens slightly separated so
--each remains visible/clickable, while a physical site marker stays at the centre underneath them.
--Destroyed Site tokens are special: their known settled table height is 1.13, so scripted/manual
--placement pins them directly there instead of asking physics to discover the bottom of an existing stack.
local mapTokenArrangeGeneration={}
local mapTokenSpreadSlots={
	[1]={x=-0.10,z=-0.10},
	[2]={x= 0.10,z= 0.10},
	[3]={x= 0.10,z=-0.10},
	[4]={x=-0.10,z= 0.10},
	[5]={x=-0.17,z= 0.00},
	[6]={x= 0.17,z= 0.00},
	[7]={x= 0.00,z=-0.17},
	[8]={x= 0.00,z= 0.17}
}
local destroyedSiteRestingY=1.13

function mapTokenIsDestroyedSite(obj)
	return obj~=nil and obj.getGMNotes~=nil and obj.getGMNotes()=="Destroyed"
end

function mapTokenIsBaseSite(obj)
	if obj==nil then return false end
	if mapTokenIsDestroyedSite(obj)==true then return true end
	local details=monsterPugs~=nil and monsterPugs[obj.guid] or nil
	return details~=nil and details.name=="Ruin"
end

function mapTokenIsSpreadEnemy(obj)
	if obj==nil then return false end
	if apocalypseDragon~=nil and obj.guid==apocalypseDragon.furyMarker then return true end
	local details=monsterPugs~=nil and monsterPugs[obj.guid] or nil
	if details==nil then return false end
	--Possessed markers are physically linked overlays, not independent enemies. Ruins are site markers.
	if details.pugType=="possessed" or details.name=="Ruin" then return false end
	return true
end

function mapTokenNeedsArrangement(obj)
	return mapTokenIsSpreadEnemy(obj)==true or mapTokenIsBaseSite(obj)==true
end

local function mapTokenOnHex(obj,hex)
	if obj==nil or hex==nil or hex.position==nil then return false end
	local pos=obj.getPosition()
	local dx=pos[1]-hex.position[1]
	local dz=pos[3]-hex.position[3]
	return (dx*dx)+(dz*dz)<1.5
end

--Any token that was locked before the arranger touched it is locked again only after one physics
--frame has elapsed and the moved piece reports resting. This avoids locking a token in mid-air just
--because a smooth move has ended with resting still carrying its previous value for that frame.
function mapTokenRelockWhenSettled(guid,shouldLock)
	if shouldLock~=true or guid==nil then return end
	safeWaitFrames("Scenario",function()
		safeWaitCondition("Scenario",function()
			local obj=getObjectFromGUID(guid)
			if obj~=nil then obj.lock() end
		end,function()
			local obj=getObjectFromGUID(guid)
			return obj==nil or obj.resting==true
		end,4,function()
			local obj=getObjectFromGUID(guid)
			if obj~=nil then obj.lock() end
		end)
	end,1)
end

function mapTokenAfterSettled(guid,callback)
	if guid==nil or callback==nil then return end
	safeWaitCondition("Scenario",function()
		safeWaitFrames("Scenario",function()
			safeWaitCondition("Scenario",function()
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

local function mapTokenMoveAndDrop(obj,targetX,targetZ,minY)
	if obj==nil then return false end
	local pos=obj.getPosition()
	if obj.isSmoothMoving()==true then return false end
	local already=math.abs(pos[1]-targetX)<0.035 and math.abs(pos[3]-targetZ)<0.035
	if already==true then return false end
	local wasLocked=obj.getLock()==true
	local targetY=math.max(tonumber(minY) or 1.45,pos[2]+0.10)
	obj.unlock()
	obj.setPosition({targetX,targetY,targetZ})
	mapTokenUpdatePlayLocation(obj,{targetX,targetY,targetZ})
	mapTokenRelockWhenSettled(obj.guid,wasLocked)
	return true
end

--When a token is picked up, pieces left behind still need to close/rebalance their horizontal
--spacing, but lifting them again makes the stack visibly hop. Preserve the exact current Y and
--move only across the table surface; previously locked pieces can be relocked immediately.
local function mapTokenMoveLaterally(obj,targetX,targetZ)
	if obj==nil then return false end
	local pos=obj.getPosition()
	if obj.isSmoothMoving()==true then return false end
	local already=math.abs(pos[1]-targetX)<0.035 and math.abs(pos[3]-targetZ)<0.035
	if already==true then return false end
	local wasLocked=obj.getLock()==true
	obj.unlock()
	obj.setPosition({targetX,pos[2],targetZ})
	mapTokenUpdatePlayLocation(obj,{targetX,pos[2],targetZ})
	if wasLocked==true then obj.lock() end
	return true
end

--Arrange one resolved map hex. A Destroyed Site remains the floor marker, but when another token
--shares its hex it participates in the spread: the lower marker sits down-left and the first token
--above it sits up-right. A Ruin remains an ordinary centred base marker. A lone enemy recentres.
--lateralOnly is used when a piece leaves the hex so the survivors never visibly hop in Y.
function mapTokenArrangeHex(hex,mapObjects,ignoreGUID,extraObject,lateralOnly)
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

	local destroyed=nil
	local ordinaryBase=nil
	local enemies={}
	for _,obj in ipairs(objects) do
		if mapTokenIsDestroyedSite(obj)==true then
			if destroyed==nil then destroyed=obj end
		elseif mapTokenIsBaseSite(obj)==true then
			if ordinaryBase==nil then ordinaryBase=obj end
		elseif mapTokenIsSpreadEnemy(obj)==true then
			enemies[#enemies+1]=obj
		end
	end
	table.sort(enemies,function(a,b)
		local ay=a.getPosition()[2]
		local by=b.getPosition()[2]
		if math.abs(ay-by)>0.025 then return ay<by end
		return tostring(a.guid)<tostring(b.guid)
	end)

	local centerX,centerZ=hex.position[1],hex.position[3]
	local base=destroyed or ordinaryBase
	local baseY=nil
	local changed=false

	if destroyed~=nil then
		local pos=destroyed.getPosition()
		local destroyedOffset=#enemies>0 and mapTokenSpreadSlots[1] or {x=0,z=0}
		local targetX,targetZ=centerX+destroyedOffset.x,centerZ+destroyedOffset.z
		local targetY=lateralOnly==true and pos[2] or destroyedSiteRestingY
		local needsMove=math.abs(pos[1]-targetX)>0.025 or math.abs(pos[2]-targetY)>0.025 or math.abs(pos[3]-targetZ)>0.025
		if needsMove==true or destroyed.getLock()~=true then
			destroyed.unlock()
			destroyed.setRotation({0,180,0})
			--Destroyed stays physically underneath, but shares the same horizontal spread as the pieces above.
			destroyed.setPosition({targetX,targetY,targetZ})
			destroyed.lock()
			changed=true
		end
		baseY=targetY
	elseif ordinaryBase~=nil then
		local pos=ordinaryBase.getPosition()
		baseY=pos[2]
		if #enemies>0 and ordinaryBase.isSmoothMoving()~=true and (math.abs(pos[1]-centerX)>0.035 or math.abs(pos[3]-centerZ)>0.035) then
			if lateralOnly==true then changed=mapTokenMoveLaterally(ordinaryBase,centerX,centerZ) or changed
			else changed=mapTokenMoveAndDrop(ordinaryBase,centerX,centerZ,math.max(1.35,pos[2]+0.10)) or changed end
		end
	end

	if #enemies<1 then return changed end
	for _,obj in ipairs(enemies) do if obj.isSmoothMoving()==true then return changed end end

	local shouldSpread=base~=nil or #enemies>1
	if shouldSpread~=true then
		local obj=enemies[1]
		local pos=obj.getPosition()
		if math.abs(pos[1]-centerX)>0.035 or math.abs(pos[3]-centerZ)>0.035 then
			if lateralOnly==true then changed=mapTokenMoveLaterally(obj,centerX,centerZ) or changed
			else changed=mapTokenMoveAndDrop(obj,centerX,centerZ,math.max(1.45,pos[2]+0.10)) or changed end
		end
		return changed
	end

	--Destroyed occupies slot 1 itself when the hex is shared, putting the physical bottom down-left.
	--Enemy assignment therefore begins at slot 2, whose offset is up-right.
	local firstEnemySlot=destroyed~=nil and 2 or 1
	local assigned={}
	--Read the actual physical stack and assign slots from bottom to top. This makes a drop deterministic:
	--the lowest piece is down-left, the next is up-right, regardless of tiny differences in drop position.
	for index,obj in ipairs(enemies) do
		assigned[obj.guid]=math.min(firstEnemySlot+index-1,#mapTokenSpreadSlots)
	end

	for _,obj in ipairs(enemies) do
		local slot=assigned[obj.guid] or firstEnemySlot
		local offset=mapTokenSpreadSlots[slot]
		local minY=(baseY~=nil and baseY+0.55 or 1.45)
		if lateralOnly==true then
			changed=mapTokenMoveLaterally(obj,centerX+offset.x,centerZ+offset.z) or changed
		else
			changed=mapTokenMoveAndDrop(obj,centerX+offset.x,centerZ+offset.z,minY) or changed
		end
	end
	return changed
end

function mapTokenArrangeObject(guid,lateralOnly)
	local obj=guid~=nil and getObjectFromGUID(guid) or nil
	if obj==nil or mapTokenNeedsArrangement(obj)~=true then return false end
	local hexes,mapObjects=apocalypseQuestMapHexes()
	local hex=apocalypseQuestHexForPosition(hexes,obj.getPosition(),mapObjects)
	if hex==nil then return false end
	return mapTokenArrangeHex(hex,mapObjects,nil,obj,lateralOnly==true)
end

--A human drop is already responsible for the token's vertical physics. Cancel any scripted-arrival
--retries and, once the drop event has registered, read the whole hex once and change X/Z only.
function mapTokenArrangeDroppedObject(guid)
	if guid==nil then return end
	mapTokenArrangeGeneration[guid]=(mapTokenArrangeGeneration[guid] or 0)+1
	safeWaitFrames("Scenario",function()
		mapTokenArrangeObject(guid,true)
	end,1)
end

function mapTokenScheduleObject(guid)
	if guid==nil then return end
	local generation=(mapTokenArrangeGeneration[guid] or 0)+1
	mapTokenArrangeGeneration[guid]=generation
	for _,delay in ipairs({2,8,20,45}) do
		safeWaitFrames("Scenario",function()
			if mapTokenArrangeGeneration[guid]~=generation then return end
			mapTokenArrangeObject(guid)
		end,delay)
	end
end

--Re-arrange the hex an object is leaving while deliberately ignoring that object. This recentres a
--remaining lone enemy and keeps a Destroyed Site marker fixed underneath anything still on the hex.
function mapTokenReleaseObject(obj)
	if obj==nil or mapTokenNeedsArrangement(obj)~=true then return false end
	local position=obj.getPosition()
	local ignoreGUID=obj.guid
	--Invalidate any delayed arrival retries for the object now being carried away.
	mapTokenArrangeGeneration[ignoreGUID]=(mapTokenArrangeGeneration[ignoreGUID] or 0)+1
	safeWaitFrames("Scenario",function()
		local hexes,mapObjects=apocalypseQuestMapHexes()
		local hex=apocalypseQuestHexForPosition(hexes,position,mapObjects)
		if hex~=nil then mapTokenArrangeHex(hex,mapObjects,ignoreGUID,nil,true) end
	end,1)
	return true
end

function mapTokenArrangeAllOccupiedHexes()
	local hexes,mapObjects=apocalypseQuestMapHexes()
	local touched={}
	for _,obj in pairs(mapObjects or {}) do
		if mapTokenNeedsArrangement(obj)==true then
			local hex=apocalypseQuestHexForPosition(hexes,obj.getPosition(),mapObjects)
			local key=hex~=nil and apocalypseQuestMapHexKey(hex) or nil
			if key~=nil and touched[key]~=true then
				touched[key]=true
				mapTokenArrangeHex(hex,mapObjects)
			end
		end
	end
end

--Horseman callers now use the generic map-token arranger. These small wrappers keep the scenario
--movement code readable while ensuring Horsemen, ordinary enemies and the Fury Dragon all share
--exactly the same physical-hex behaviour.
function horsemanReleaseOccupiedToken(name)
	local data=horsemanData~=nil and horsemanData[name] or nil
	local token=data~=nil and getObjectFromGUID(data.tokenGUID) or nil
	return mapTokenReleaseObject(token)
end

function horsemanArrangeOccupiedTokenStack(name)
	local data=horsemanData~=nil and horsemanData[name] or nil
	return data~=nil and mapTokenArrangeObject(data.tokenGUID) or false
end

function horsemanScheduleOccupiedTokenStack(name)
	local data=horsemanData~=nil and horsemanData[name] or nil
	if data~=nil then mapTokenScheduleObject(data.tokenGUID) end
end

function horsemanArrangeOccupiedTokenStacks()
	mapTokenArrangeAllOccupiedHexes()
end

function setHorsemanLevel(ref, level, hideIdentity)
	local data,name=horsemanDataFor(ref)
	level=math.max(1,math.min(6,tonumber(level) or 1))
	local levelData=data~=nil and data.levels~=nil and data.levels[level] or nil
	if data==nil or name==nil or levelData==nil then return false end
	local token=getObjectFromGUID(data.tokenGUID)
	if token~=nil then
		--The physical rotation now hides an unrevealed Horseman's face, so load the real level art
		--from setup onward instead of swapping to a separate blank image.
		local displayName=hideIdentity==true and "" or (name.." Level "..tostring(level))
		local imageURL=levelData.tokenImg
		if type(imageURL)=="string" and imageURL~="" then
			token.setCustomObject({image=imageURL})
			token.setName(displayName)
			token.reload()
		else
			token.setName(displayName)
		end
	end
	monsterPugs[data.tokenGUID]=horsemanMonsterData(name,level)
	if gStates.horsemen==nil then gStates.horsemen={} end
	local state=gStates.horsemen[name] or {}
	state.level=level
	state.tokenGUID=data.tokenGUID
	if state.defeated==nil then state.defeated=false end
	gStates.horsemen[name]=state
	return true
end

function againstHorsemenAllDefeated()
	if gStates==nil or gStates.gameScenario~="Against the Horsemen Blitz" then return false end
	local found=false
	for _,state in pairs(gStates.horsemen or {}) do
		found=true
		if state.defeated~=true then return false end
	end
	return found
end

--Scenario scoring uses the actual Horseman defeats rather than inventory reward tokens. This remains
--stable if a reward token is temporarily unavailable, and also preserves exactly who earned each kill.
function againstHorsemenDefeatSummary()
	local summary={total=0,byMage={},fameByMage={}}
	if gStates==nil or (gStates.gameScenario~="Against the Horsemen Blitz" and gStates.gameScenario~="Apocalypse is Here") then return summary end
	for name,state in pairs(gStates.horsemen or {}) do
		if state~=nil and state.defeated==true then
			summary.total=summary.total+1
			local mage=state.defeatedBy or (gStates.horsemenDefeatedBy~=nil and gStates.horsemenDefeatedBy[name] or nil)
			if mage~=nil then
				summary.byMage[mage]=(summary.byMage[mage] or 0)+1
				local data=horsemanData~=nil and horsemanData[name] or nil
				local level=math.max(1,math.min(6,tonumber(state.level) or 1))
				local fame=data~=nil and data.levels~=nil and data.levels[level]~=nil and tonumber(data.levels[level].fame) or 0
				summary.fameByMage[mage]=(summary.fameByMage[mage] or 0)+fame
			end
		end
	end
	return summary
end

--The all-players-Horseman cooperative bonus is scenario-specific: +6 in Against the Horsemen and
--+5 in Apocalypse is Here. This helper only checks whether the scoring Mage Knights qualify;
--the standard Dummy/optional Proxy never counts toward that requirement.
function againstHorsemenEveryScoringPlayerDefeatedOne(summary)
	if gStates==nil or (gStates.gameScenario~="Against the Horsemen Blitz" and gStates.gameScenario~="Apocalypse is Here") or gStates.playerCount<=1 then return false end
	summary=summary or againstHorsemenDefeatSummary()
	local found=false
	for _,details in pairs(turnOrder or {}) do
		if details.mage~=nil and details.mage~="nobody" and details.mage~=gStates.positionMageKnight[5] then
			found=true
			if (summary.byMage[details.mage] or 0)<1 then return false end
		end
	end
	return found
end

function againstHorsemenRitualDefenders()
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
function againstHorsemenPortalCardLayout(count)
	local cx,cz=-44.0,-12.30
	if count<=1 then return {{cx,1.22,cz}} end
	if count==2 then return {{cx-1.25,1.22,cz},{cx+1.25,1.22,cz}} end
	if count==3 then return {{cx-1.25,1.22,cz-0.78},{cx+1.25,1.22,cz-0.78},{cx,1.22,cz+0.78}} end
	return {{cx-1.25,1.22,cz-0.78},{cx+1.25,1.22,cz-0.78},{cx-1.25,1.22,cz+0.78},{cx+1.25,1.22,cz+0.78}}
end

--Defeated Horsemen are trophies as well as saved scoring state. Keep a tidy 2x2 group in the
--slayer's Inventory and make their defeated status obvious without changing the level artwork.
function againstHorsemenDefeatedInventoryPosition(playerIndex,name)
	local player=turnOrder[playerIndex]
	local state=name~=nil and gStates.horsemen~=nil and gStates.horsemen[name] or nil
	if player==nil then return {55,2,20} end
	local slot=math.max(1,math.min(4,tonumber(state~=nil and state.mapSlot) or 1))
	local col=(slot-1)%2
	local row=math.floor((slot-1)/2)
	return {(player.seatPos*40)-115.8+(col*3.2),1.35,-32.7-(row*2.7)}
end

function againstHorsemenMarkDefeatedToken(token,name,playerIndex,smooth)
	local state=name~=nil and gStates.horsemen~=nil and gStates.horsemen[name] or nil
	local player=turnOrder[playerIndex]
	if token==nil or state==nil or player==nil then return false end
	local level=math.max(1,math.min(6,tonumber(state.level) or 1))
	horsemanReleaseOccupiedToken(name)
	token.setName("DEFEATED - "..name.." Level "..tostring(level))
	token.setDescription("Defeated by "..tostring(player.mage))
	token.setGMNotes("Defeated Horseman")
	token.setRotation({0,180,0})
	local destination=againstHorsemenDefeatedInventoryPosition(playerIndex,name)
	if smooth==false then token.setPosition(destination) else token.setPositionSmooth(destination,false) end
	return true
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

--Rebuild dynamic Horseman combat data after loading a current save.
function againstHorsemenRestoreRuntimeState()
	if gStates==nil or (gStates.gameScenario~="Against the Horsemen Blitz" and gStates.gameScenario~="Apocalypse is Here") then return end
	if type(gStates.horsemenDefeatedBy)~="table" then gStates.horsemenDefeatedBy={} end
	for name,state in pairs(gStates.horsemen or {}) do
		local data=horsemanData~=nil and horsemanData[name] or nil
		if data~=nil and state~=nil then
			if state.defeated==true or state.retired==true then
				--The trophy is already physically saved in the player's Inventory; only keep it out of active combat data.
				monsterPugs[data.tokenGUID]=nil
				if gStates.monsterPerks~=nil then gStates.monsterPerks[data.tokenGUID]=nil end
			else
				monsterPugs[data.tokenGUID]=horsemanMonsterData(name,state.level)
				if gStates.gameScenario=="Against the Horsemen Blitz" and gStates.againstHorsemenRitualStarted==true then
					state.atCentralGlade=true
					state.terrainGUID=GUID.tile.country01
					state.bearing="center"
					state.revealed=true
					if monsterPugs[data.tokenGUID]~=nil and monsterPugs[data.tokenGUID].unfortified==nil then monsterPugs[data.tokenGUID].fortified=true end
				end
			end
		end
	end
	if gStates.gameScenario=="Against the Horsemen Blitz" and gStates.againstHorsemenRitualStarted==true then againstHorsemenEliminateCentralPlayers() end
	--Do not pull tokens away from a saved combat/reward sequence. An idle Round-4 save is safe to
	--normalize immediately to the tidy garrison display.
	if gStates.gameScenario=="Against the Horsemen Blitz" and gStates.againstHorsemenRitualStarted==true and gStates.coopAssaultPhase==nil and next(gStates.attackedMonsters or {})==nil and gStates.againstHorsemenMovePending==nil then
		local defenders=againstHorsemenRitualDefenders()
		local layout=againstHorsemenPortalCardLayout(#defenders)
		for i,entry in ipairs(defenders) do
			local token=getObjectFromGUID(entry.guid)
			if token~=nil and layout[i]~=nil then
				token.setRotation({0,180,0})
				token.setPositionSmooth(layout[i],false)
			end
		end
	end
end

function againstHorsemenEliminateCentralPlayers()
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
			broadcastToAll(details.mage.." was in the Magical Glade when the ritual began and is out of the game.",positionToColor(playerIndex))
		end
	end
	applyColorBarButtons()
end

function againstHorsemenPrepareRitual()
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
	broadcastToAll("The ritual has begun. The central Magical Glade is now a fortified assault site defended by every surviving Horseman.",{1,0.35,0.15})
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
function againstHorsemenRefreshHorseman(name)
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
	broadcastToAll(name.." has been revealed at Level "..tostring(state.level or 1)..".",{1,0.75,0.2})
	return true
end

function againstHorsemenRefreshReveals()
	if gStates==nil or gStates.gameScenario~="Against the Horsemen Blitz" then return end
	for name,_ in pairs(gStates.horsemen or {}) do
		againstHorsemenRefreshHorseman(name)
		horsemanScheduleOccupiedTokenStack(name)
	end
end

--Before the ritual, a Horseman is a same-space action rather than a Rampaging-style adjacent attack.
--Once the Round-4 ritual begins these individual actions disappear: dropping onto the central Glade
--starts its fortified city-style assault against every surviving Horseman instead.
function againstHorsemenAttackOptions(playerIndex,mapPosition)
	if gStates==nil or (gStates.gameScenario~="Against the Horsemen Blitz" and gStates.gameScenario~="Apocalypse is Here") or (gStates.gameScenario=="Against the Horsemen Blitz" and gStates.againstHorsemenRitualStarted==true) then return {} end
	local player=turnOrder[playerIndex]
	if player==nil or player.mage==nil then return {} end
	againstHorsemenRefreshReveals()
	local avPos=mapPosition or mageKnightAvatarPositionByName(player.mage)
	--City/Volkare-Camp avatars can be physically parked on their shared city card. Convert that
	--parking position back to the actual map location just as addAvatarButtons does for site attacks.
	if mapPosition==nil and player.avatarLocation~=nil and (player.avatarLocation:sub(1,4)=="city" or player.avatarLocation=="Volkare's Camp") then
		for zoneGUID,citySearch in pairs(cityScriptZones) do
			local zoneObj=getObjectFromGUID(zoneGUID)
			if zoneObj~=nil then
				local found=false
				for _,obj in pairs(zoneObj.getObjects()) do if obj.getName()==player.mage then found=true break end end
				if found==true then
					local cityObj=nil
					if zoneGUID==volkare.discZone and (gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz" or gStates.gameScenario=="Volkare's Quest" or gStates.gameScenario=="The War of Four") then cityObj=getObjectFromGUID(gStates.volkareModel)
					else cityObj=getObjectFromGUID(citySearch.cityGUID) end
					if cityObj~=nil then avPos=cityObj.getPosition() end
					break
				end
			end
		end
	end
	if avPos==nil then return {} end
	local avTerrain,avBearing,avHexCenter=terrainHexAtPosition(avPos)
	if avTerrain==nil or avBearing==nil then return {} end
	local here={}
	for name,state in pairs(gStates.horsemen or {}) do
		local data=horsemanData~=nil and horsemanData[name] or nil
		local token=data~=nil and getObjectFromGUID(data.tokenGUID) or nil
		if state~=nil and data~=nil and state.defeated~=true and state.retired~=true and state.revealed==true and token~=nil then
			local tokenPos=token.getPosition()
			local terrain,bearing=terrainHexAtPosition(tokenPos)
			local sameHex=terrain~=nil and terrain.guid==avTerrain.guid and tostring(bearing)==tostring(avBearing)
			--Occupied sites can physically nudge the Horseman when the Mage Knight is dropped on top.
			--Allow a small centre tolerance without reaching the neighbouring hex 2.39 units away.
			if sameHex~=true and avHexCenter~=nil then
				sameHex=((tokenPos[1]-avHexCenter[1])^2)+((tokenPos[3]-avHexCenter[3])^2)<2.25
			end
			if sameHex==true then here[#here+1]={name=name,guid=data.tokenGUID,slot=tonumber(state.mapSlot) or 99} end
		end
	end
	table.sort(here,function(a,b) if a.slot==b.slot then return a.name<b.name end return a.slot<b.slot end)
	local options={}
	for _,entry in ipairs(here) do options[#options+1]={key=entry.guid,name=entry.name,label=entry.name:sub(1,1),targets={[entry.guid]=true}} end
	return options
end

function againstHorsemenAttackAction(playerDud,mouseButton,id)
	if mouseButton~="-1" then return end
	local key,mage=tostring(id or ""):match("^Horse|([^|]+)|(.+)$")
	if key==nil or mage==nil then return end
	local playerIndex=nil
	for index,details in pairs(turnOrder) do if details.mage==mage then playerIndex=index break end end
	if playerIndex==nil or playerIndex~=gStates.turnNumber then return end
	local player=turnOrder[playerIndex]
	--"Avatar" means a first defender has already been staged, but further optional enemies may still
	--be added to that combat. Only "Both" closes the Horseman choice completely.
	if player==nil or player.combatIconHide=="Both" then return end
	local turnToken=getObjectFromGUID(player.turnOrderTokenGUID)
	if turnToken==nil or turnToken.is_face_down==true then return end
	if playerDud~=nil and playerDud.color~=nil and legalPlayerCheck(playerDud.color,player.seatPos)~=true then return end
	local chosen=nil
	for _,option in ipairs(againstHorsemenAttackOptions(playerIndex)) do if option.key==key then chosen=option break end end
	if chosen==nil then addAvatarButtons() return end
	gStates.againstHorsemenAttackSelection={player=playerIndex,targets=chosen.targets}
	attackLocation(playerDud,mouseButton,"Attack"..mage)
end

--Horseman tokens are persistent Custom Tiles, so normal monster-discard logic must not treat them as
--Faction Leaders. A face-up Horseman at cleanup was defeated: record the slayer, award the Apocalypse
--Faction token, and keep the marked Horseman as a trophy in that player's Inventory. Failed face-down
--combats use monsterPlayLocation and the existing undefeated-monster return path instead.
function againstHorsemenResolveDefeat(token,playerIndex,coopCombatReward)
	local name=horsemanTokenToName~=nil and horsemanTokenToName[token~=nil and token.guid or ""] or nil
	local state=name~=nil and gStates.horsemen~=nil and gStates.horsemen[name] or nil
	local player=turnOrder[playerIndex]
	if token==nil or name==nil or state==nil or player==nil then return false end
	if state.defeated==true then
		againstHorsemenMarkDefeatedToken(token,name,playerIndex,true)
		return true
	end
	state.defeated=true
	state.defeatedLevel=tonumber(state.level) or 1
	state.defeatedBy=player.mage
	state.defeatedRound=gStates.currentRound
	state.atCentralGlade=false
	if gStates.horsemenDefeatedBy==nil then gStates.horsemenDefeatedBy={} end
	gStates.horsemenDefeatedBy[name]=player.mage
	local rewardBag=getObjectFromGUID(monsterPiles.rewardApoc)
	if rewardBag~=nil and rewardBag.getQuantity()>0 then
		if coopCombatReward~=nil then
			coopCombatReward.factionRewards.apocalypse=(coopCombatReward.factionRewards.apocalypse or 0)+1
			if coopCombatReward.factionRewardsGiven==true then rewardBag.takeObject({position={(player.seatPos*40)-117.2+(math.random()*6.5),2,-35+(math.random()*3.2)}}) end
		else
			rewardBag.takeObject({position={(player.seatPos*40)-117.2+(math.random()*6.5),2,-35+(math.random()*3.2)}})
		end
	else
		broadcastToAll("Sorry, there are no more Apocalypse Faction Reward Tokens. Use a reminder and collect one when a token becomes available.",positionToColor(playerIndex))
	end
	if gStates.monsterPlayLocation~=nil then gStates.monsterPlayLocation[token.guid]=nil end
	if gStates.monsterPerks~=nil then gStates.monsterPerks[token.guid]=nil end
	if gStates.attackedMonsters~=nil then gStates.attackedMonsters[token.guid]=nil end
	monsterPugs[token.guid]=nil
	againstHorsemenMarkDefeatedToken(token,name,playerIndex,true)
	broadcastToAll(player.mage.." defeated "..name..". The Horseman has been placed in their Inventory.",positionToColor(playerIndex))
	return true
end

--Against the Horsemen uses a fixed hex grid around Countryside 1. There is no reason to build a
--map graph or run path-finding here: convert the token position directly to axial coordinates, take
--one deterministic step toward the nearest centre-line, then keep following that line into the Glade.
function againstHorsemenGladePosition()
	local terrain=getObjectFromGUID(GUID.tile.country01)
	if terrain==nil then return nil end
	local xy=angleToXY(terrain,"center")
	if xy==nil then return nil end
	return {xy[1],1.45,xy[2]}
end

function againstHorsemenGridFromPosition(position,center)
	if position==nil or center==nil then return nil,nil end
	local r=math.floor(((position[3]-center[3])/2.0785)+0.5)
	local q=math.floor(((position[1]-center[1])/2.4)+(r/2)+0.5)
	return q,r
end

function againstHorsemenGridDistance(q,r)
	return math.max(math.abs(q),math.abs(r),math.abs(q-r))
end

function againstHorsemenInlineGridDistance(q,r)
	return math.min(math.abs(q),math.abs(r),math.abs(q-r))
end

function againstHorsemenGridPosition(q,r,center,y)
	return {center[1]+(2.4*(q-(r/2))),y or 1.45,center[3]+(2.0785*r)}
end

function againstHorsemenDefaultNextPosition(position,center)
	local q,r=againstHorsemenGridFromPosition(position,center)
	if q==nil or r==nil or (q==0 and r==0) then return nil end
	local currentCenter=againstHorsemenGridDistance(q,r)
	local currentInline=againstHorsemenInlineGridDistance(q,r)
	local neighbours={{1,0},{-1,0},{0,1},{0,-1},{1,1},{-1,-1}}
	local bestQ,bestR=nil,nil
	local bestInline,bestCenter=999,999
	for _,offset in ipairs(neighbours) do
		local nq=q+offset[1]
		local nr=r+offset[2]
		local inline=againstHorsemenInlineGridDistance(nq,nr)
		local centerDistance=againstHorsemenGridDistance(nq,nr)
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
	if bestQ==nil then return nil end
	return againstHorsemenGridPosition(bestQ,bestR,center,1.45)
end

function againstHorsemenFinalizeMoveWave()
	local pending=gStates~=nil and gStates.againstHorsemenMovePending or nil
	if pending==nil or pending.movingTargets==nil then return end
	for name,_ in pairs(pending.movingTargets) do
		againstHorsemenRefreshHorseman(name)
		horsemanArrangeOccupiedTokenStack(name)
	end
	pending.movingTargets=nil
	pending.stepsRemaining=math.max(0,(pending.stepsRemaining or 1)-1)
	safeWaitFrames("Scenario",function() againstHorsemenContinueEndRoundMovement() end,4)
end

function againstHorsemenAnimateMoveWave(targets)
	local pending=gStates~=nil and gStates.againstHorsemenMovePending or nil
	if pending==nil or targets==nil then return end
	pending.movingTargets=targets
	for name,target in pairs(targets) do
		local data=horsemanData~=nil and horsemanData[name] or nil
		local token=data~=nil and getObjectFromGUID(data.tokenGUID) or nil
		if token~=nil and target.position~=nil then
			horsemanReleaseOccupiedToken(name)
			token.setPositionSmooth(target.position,false)
		end
	end
	safeWaitFrames("Scenario",function()
		local function allSettled()
			for name,_ in pairs(targets) do
				local data=horsemanData~=nil and horsemanData[name] or nil
				local token=data~=nil and getObjectFromGUID(data.tokenGUID) or nil
				if token~=nil and token.resting~=true then return false end
			end
			return true
		end
		safeWaitCondition("Scenario",function() againstHorsemenFinalizeMoveWave() end, allSettled, 3, function()
			for name,target in pairs(targets) do
				local data=horsemanData~=nil and horsemanData[name] or nil
				local token=data~=nil and getObjectFromGUID(data.tokenGUID) or nil
				if token~=nil and target.position~=nil then token.setPosition(target.position) end
			end
			againstHorsemenFinalizeMoveWave()
		end)
	end,2)
end

function againstHorsemenContinueEndRoundMovement()
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
		broadcastToAll("Horsemen movement could not locate the central Magical Glade on the map.",{1,0.3,0.2})
		pending.stepsRemaining=0
		againstHorsemenContinueEndRoundMovement()
		return
	end
	local targets={}
	local stackIndex=0
	if pending.finalGlade==true and pending.ritualPrepared~=true then
		againstHorsemenPrepareRitual()
		pending.ritualPrepared=true
	end
	local ritualDefenders=pending.finalGlade==true and againstHorsemenRitualDefenders() or nil
	local ritualLayout=ritualDefenders~=nil and againstHorsemenPortalCardLayout(#ritualDefenders) or nil
	local ritualSlot={}
	for i,entry in ipairs(ritualDefenders or {}) do ritualSlot[entry.name]=i end
	for _,name in ipairs(pending.queue or {}) do
		local state=gStates.horsemen~=nil and gStates.horsemen[name] or nil
		local data=horsemanData~=nil and horsemanData[name] or nil
		local token=data~=nil and getObjectFromGUID(data.tokenGUID) or nil
		if state~=nil and state.defeated~=true and token~=nil then
			local nextPosition=nil
			if pending.finalGlade==true then
				--Logically they enter the Glade; physically they take their tidy garrison slots on the Portal card.
				stackIndex=stackIndex+1
				local slot=ritualSlot[name] or stackIndex
				nextPosition=ritualLayout~=nil and ritualLayout[slot] or nil
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
		broadcastToAll("End of Round 3: the surviving Horsemen move into the central Magical Glade and begin the ritual.",{1,0.3,0.2})
	else
		gStates.againstHorsemenMovePending={round=gStates.currentRound,queue=queue,stepsRemaining=2}
		broadcastToAll("End of Round "..tostring(gStates.currentRound)..": each surviving Horseman moves two spaces closer to the central Magical Glade.",{1,0.75,0.2})
	end
	againstHorsemenContinueEndRoundMovement()
	return true
end

function againstHorsemenStartingLevel()
	if gStates.playerCount==1 then return 2 end
	if gStates.coop==1 then return math.min(6,gStates.playerCount+2) end
	return math.max(1,math.min(6,gStates.playerCount))
end

function againstHorsemenSetupTokens(coreTileGUIDs, coreTilePositions)
	if gStates==nil or gStates.gameScenario~="Against the Horsemen Blitz" then return end
	local bag=getObjectFromGUID(GUID.bag.apocalypseDragon)
	if bag==nil then print("HORSEMEN SETUP ERROR: Apocalypse setup bag is missing") return end
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
	for i,name in ipairs(names) do
		local data=horsemanData[name]
		local pos=coreTilePositions[i]
		local coreGUID=coreTileGUIDs[i]
		if data==nil or pos==nil or coreGUID==nil then
			print("HORSEMEN SETUP ERROR: missing setup data for slot "..tostring(i))
		else
			--The left/right Horsemen begin one additional hex outward from their Core-tile centres.
			--Slots 2 and 4 are the right and left Core tiles respectively; one horizontal hex is 2.4 world units.
			local horsemanX=pos[1]
			if i==2 then horsemanX=horsemanX+2.4 elseif i==4 then horsemanX=horsemanX-2.4 end
			local token=bag.takeObject({guid=data.tokenGUID,position={horsemanX,2.3,pos[3]},rotation={0,180,180},smooth=false})
			if token==nil then
				print("HORSEMEN SETUP ERROR: could not deploy "..name)
			else
				setHorsemanLevel(name,level,true)
				local state=gStates.horsemen[name]
				state.revealed=false
				--Record the actual hex, not merely the Core-tile centre. This matters for the two
				--side Horsemen now that their physical starting hex is one step farther outward.
				local horsemanTerrain,horsemanBearing=terrainHexAtPosition({horsemanX,1.1,pos[3]})
				state.terrainGUID=horsemanTerrain~=nil and horsemanTerrain.guid or coreGUID
				state.bearing=horsemanBearing or "center"
				state.mapSlot=i
				gStates.againstHorsemenCoreTiles[i]=coreGUID
			end
		end
	end
end


--Apocalypse is Here -------------------------------------------------------------
--This scenario reuses the existing Horseman combat objects and Apocalypse Dragon combat engine.
--The functions below supply the scenario-specific reveal order, roaming Horsemen turns, City/Dragon
--transition, Horseman-powered Dragon levels, and the first-Dragon-attack cleanup.
function apocalypseIsHereActive()
	return gStates~=nil and gStates.gameScenario=="Apocalypse is Here"
end

function apocalypseIsHereHorsemanStartingLevel()
	if apocalypseIsHereActive()~=true then return nil end
	if gStates.playerCount==1 then return 4 end
	if gStates.coop==1 then return 6 end
	return 5
end

function apocalypseIsHerePositionRoundOrderToken()
	if apocalypseIsHereActive()~=true then return false end
	local token=getObjectFromGUID("9ba54f")
	local bag=getObjectFromGUID(GUID.bag.apocalypseDragon)
	local target={-1.90,0.97,-22.20}
	if token==nil and bag~=nil then token=bag.takeObject({guid="9ba54f",position=target,rotation={0,180,0},smooth=false}) end
	if token==nil then return false end
	token.unlock()
	token.setRotation({0,180,0})
	token.setPositionSmooth(target,false,true)
	safeWaitCondition("Scenario",function() local current=getObjectFromGUID("9ba54f") if current~=nil then current.lock() end end,
		function() local current=getObjectFromGUID("9ba54f") return current==nil or current.isSmoothMoving()==false end)
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

function apocalypseIsHereRevealThreshold(index)
	local thresholds=nil
	if (gStates.playerCount or 1)<=2 then thresholds={1,2,4,6}
	elseif gStates.playerCount==3 then thresholds={1,3,5,7}
	else thresholds={2,4,6,8} end
	return thresholds[index]
end

function apocalypseIsHereRevealNextHorseman(tile,forced)
	if apocalypseIsHereActive()~=true or gStates.apocalypseHereHorsemenEnded==true or tile==nil then return false end
	local index=tonumber(gStates.apocalypseHereNextHorseman) or 1
	local name=(gStates.apocalypseHereHorsemanOrder or {})[index]
	local data=name~=nil and horsemanData[name] or nil
	local state=name~=nil and gStates.horsemen[name] or nil
	if data==nil or state==nil then return false end
	local xy=angleToXY(tile,"center")
	local tilePos=tile.getPosition()
	--Bring the Horseman in above the settled terrain instead of teleporting him onto the tile.
	--One unit of clearance lets the smooth move finish cleanly; physics then drops him onto the map.
	local target={xy[1],tilePos[2]+1.0,xy[2]}
	local token=getObjectFromGUID(data.tokenGUID)
	local bag=getObjectFromGUID(GUID.bag.apocalypseDragon)
	if token==nil and bag~=nil then token=bag.takeObject({guid=data.tokenGUID,position={target[1],target[2]+1.0,target[3]},rotation={0,180,0},smooth=false}) end
	if token==nil then return false end
	state.revealed=true
	state.retired=false
	state.terrainGUID=tile.guid
	state.bearing="center"
	state.revealTileGUID=tile.guid
	state.revealCount=gStates.apocalypseHereTilesRevealed
	setHorsemanLevel(name,state.level,false)
	token=getObjectFromGUID(data.tokenGUID) or token
	token.unlock()
	token.setRotation({0,180,0})
	token.setPositionSmooth(target,false)
	--Terrain population can finish after the Horseman itself arrives, so let the generic settle-aware
	--scheduler catch whichever of the Horseman or existing map token finishes last.
	horsemanScheduleOccupiedTokenStack(name)
	gStates.apocalypseHereNextHorseman=index+1
	local card=getObjectFromGUID(data.cardGUID)
	if card~=nil then
		card.unlock()
		card.setPositionSmooth({-69.80+((index-1)*5.90),0.98,0.40},false,true)
		if card.is_face_down==true then card.flip() end
	end
	if gStates.apocalypseHereForcedRevealPending==true then
		gStates.apocalypseHereForcedRevealCount=math.max(0,(tonumber(gStates.apocalypseHereForcedRevealCount) or 1)-1)
		gStates.apocalypseHereForcedRevealPending=gStates.apocalypseHereForcedRevealCount>0
		if gStates.preEndTurn==true and mainUIUpdate~=nil then mainUIUpdate("Horseman exploration resolved") end
	end
	broadcastToAll(name.." has been revealed at Level "..tostring(state.level)..(forced==true and " by the Round deadline." or "."),{1,0.75,0.2})
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
	local chooser=againstDragonChoicePlayerIndex~=nil and againstDragonChoicePlayerIndex() or nil
	broadcastToAll("A Horseman reveal deadline has been reached. Reveal the top Map tile and place it in a legal position as far as possible from every Mage Knight. "..againstDragonChoicePlayerLabel(chooser).." breaks a tied placement. The next placed Map tile will automatically reveal the overdue Horseman.",warningColor)
	return true
end

function apocalypseIsHerePossessEnemy(enemy)
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

function apocalypseIsHerePossessRampagersOnTile(tileGUID)
	if apocalypseIsHereActive()~=true or tileGUID==nil then return end
	local hexes,mapObjects=apocalypseQuestMapHexes()
	for _,hex in ipairs(hexes) do
		if hex.terrainGUID==tileGUID and (hex.feature=="rampaging" or hex.feature=="draconum") then
			for _,enemy in ipairs(proxyMonstersOnHex(hex,mapObjects)) do
				if gStates.rampagingMonsters~=nil and gStates.rampagingMonsters[enemy.guid]==true then apocalypseIsHerePossessEnemy(enemy) end
			end
		end
	end
end

function apocalypseIsHereRevealDragonCity(tile)
	if apocalypseIsHereActive()~=true or tile==nil or gStates.apocalypseHereDragonCityRevealed==true then return false end
	gStates.apocalypseHereDragonCityRevealed=true
	gStates.apocalypseDragonLairRevealed=true
	local tilePos=tile.getPosition()
	local fixedRotation={0,180,180}
	local positions={
		{tilePos[1],0.97,tilePos[3]},
		(function() local xy=angleToXY(tile,"240",tilePos,fixedRotation) return {xy[1],0.97,xy[2]} end)(),
		(function() local xy=angleToXY(tile,"300",tilePos,fixedRotation) return {xy[1],0.97,xy[2]} end)()
	}
	local hexes={}
	for i,pos in ipairs(positions) do
		local bearing=terrainHexBearing(tile,pos)
		hexes[#hexes+1]={bearing=bearing,position=pos,formerCity=i==1}
		if bearing~=nil then
			local feature=terrainTiles[tile.guid].hexFeature[bearing] or ""
			if i==1 then terrainTiles[tile.guid].hexType[bearing]="plains" end
			--The three Dragon spaces ignore printed sites; printed rampaging enemies remain and become Possessed.
			if feature~="rampaging" and feature~="draconum" then
				gStates.hexOverideSave=gStates.hexOverideSave or {}
				gStates.hexOverideSave[tile.guid]=gStates.hexOverideSave[tile.guid] or {}
				gStates.hexOverideSave[tile.guid][bearing]=""
				terrainTiles[tile.guid].hexFeature[bearing]=""
			end
		end
	end
	local target={positions[1][1],1.18,positions[1][3]}
	gStates.apocalypseDragonLair={tileGUID=tile.guid,hexes=hexes,position=target,rotation={0,180,180},cityHexKey=tile.guid.."|"..tostring(hexes[1].bearing)}
	local dragon=getObjectFromGUID("105141")
	local bag=getObjectFromGUID(GUID.bag.apocalypseDragon)
	if dragon==nil and bag~=nil then dragon=bag.takeObject({guid="105141",position=target,rotation={0,180,180},smooth=false})
	elseif dragon~=nil then dragon.unlock() dragon.setRotationSmooth({0,180,180},false,true) dragon.setPositionSmooth(target,false,true) end
	if dragon~=nil then apocalypseDragonLockModelWhenSettled() end
	safeWaitFrames("Scenario",function() apocalypseIsHerePossessRampagersOnTile(tile.guid) end,35)
	safeWaitFrames("Scenario",function() apocalypseIsHerePossessRampagersOnTile(tile.guid) end,75)
	broadcastToAll("The second City has been destroyed by the Apocalypse Dragon. The City space is now Plains, and the Dragon has landed across the three spaces.",{1,0.75,0.2})
	return true
end

function apocalypseIsHereTerrainRevealed(tile)
	if apocalypseIsHereActive()~=true or tile==nil or tile.is_face_down==true then return false end
	local details=terrainTiles[tile.guid]
	if details==nil or details.tileType=="starting" or details.tileType=="tilePile" then return false end
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

function apocalypseIsHereCurrentHorsemanHex(name,hexes)
	local state=gStates.horsemen~=nil and gStates.horsemen[name] or nil
	local data=horsemanData~=nil and horsemanData[name] or nil
	local token=data~=nil and getObjectFromGUID(data.tokenGUID) or nil
	if state==nil or token==nil then return nil end
	local terrain,bearing=terrainHexAtPosition(token.getPosition())
	if terrain~=nil and bearing~=nil then state.terrainGUID=terrain.guid state.bearing=bearing end
	local key=tostring(state.terrainGUID).."|"..tostring(state.bearing)
	for _,hex in ipairs(hexes or {}) do if apocalypseQuestMapHexKey(hex)==key then return hex end end
	return nil
end

function apocalypseIsHereHorsemanTargetOptions(name)
	local state=gStates.horsemen~=nil and gStates.horsemen[name] or nil
	local data=horsemanData~=nil and horsemanData[name] or nil
	if state==nil or data==nil or state.defeated==true or state.retired==true then return {} end
	local hexes,mapObjects=apocalypseQuestMapHexes()
	local startHex=apocalypseIsHereCurrentHorsemanHex(name,hexes)
	if startHex==nil then return {} end
	local distances=apocalypseQuestHexDistanceMap(hexes,{startHex})
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
				local distance=distances[apocalypseQuestMapHexKey(hex)]
				if distance~=nil and (best==nil or distance<best) then best=distance options={{key=apocalypseQuestMapHexKey(hex),hex=hex,distance=distance,priority=priority}}
				elseif distance~=nil and distance==best then options[#options+1]={key=apocalypseQuestMapHexKey(hex),hex=hex,distance=distance,priority=priority} end
			end
		end
		if #options>0 then table.sort(options,function(a,b) return a.key<b.key end) return options,startHex,hexes,mapObjects end
	end
	return {},startHex,hexes,mapObjects
end

function apocalypseIsHereHorsemanDestination(startHex,targetHex,hexes,horsemanName,mapObjects)
	if startHex==nil or targetHex==nil then return startHex end
	local fromTarget=apocalypseQuestHexDistanceMap(hexes,{targetHex})
	local current=startHex
	for _=1,2 do
		local currentDistance=fromTarget[apocalypseQuestMapHexKey(current)]
		if currentDistance==nil or currentDistance<=0 then break end
		local choices={}
		local occupied={}
		for _,obj in pairs(mapObjects or {}) do
			local other=horsemanTokenToName~=nil and horsemanTokenToName[obj.guid] or nil
			if other~=nil and other~=horsemanName then
				local pos=obj.getPosition()
				for _,candidate in ipairs(hexes) do
					local key=apocalypseQuestMapHexKey(candidate)
					if occupied[key]~=true then
						local dx=pos[1]-candidate.position[1]
						local dz=pos[3]-candidate.position[3]
						if (dx*dx)+(dz*dz)<1.5 then occupied[key]=true break end
					end
				end
			end
		end
		for _,candidate in ipairs(hexes) do
			if apocalypseQuestHexesAdjacent(current,candidate)==true and fromTarget[apocalypseQuestMapHexKey(candidate)]==currentDistance-1 and occupied[apocalypseQuestMapHexKey(candidate)]~=true then
				choices[#choices+1]=candidate
			end
		end
		--If every shortest path is occupied, preserve the normal shortest-path rule rather than stopping.
		if #choices<1 then
			for _,candidate in ipairs(hexes) do
				if apocalypseQuestHexesAdjacent(current,candidate)==true and fromTarget[apocalypseQuestMapHexKey(candidate)]==currentDistance-1 then choices[#choices+1]=candidate end
			end
		end
		if #choices<1 then break end
		table.sort(choices,function(a,b) return apocalypseQuestMapHexKey(a)<apocalypseQuestMapHexKey(b) end)
		current=choices[1]
	end
	return current
end

function apocalypseIsHereClearChoiceButtons()
	local map=getObjectFromGUID(mapArea)
	if map==nil then return end
	for _,terrain in pairs(map.getObjects()) do
		if terrainTiles[terrain.guid]~=nil then
			local xml=terrain.UI.getXmlTable() or {}
			local changed=false
			for i=#xml,1,-1 do local id=xml[i].attributes~=nil and tostring(xml[i].attributes.id or "") or "" if id:find("ApocalypseHorsemanTarget",1,true)~=nil then table.remove(xml,i) changed=true end end
			if changed then if #xml>0 then terrain.UI.setXmlTable(xml) else terrain.UI.setXml("") end end
		end
	end
end

function apocalypseIsHereShowTargetChoice(name,options)
	apocalypseIsHereClearChoiceButtons()
	local targetKeys={}
	for _,option in ipairs(options or {}) do
		local key=option~=nil and option.hex~=nil and apocalypseQuestMapHexKey(option.hex) or nil
		if key~=nil then targetKeys[#targetKeys+1]=key end
	end
	local pending={name=name,targetKeys=targetKeys,playerIndex=againstDragonChoicePlayerIndex()}
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
			local uiX=(localPos.x or localPos[1])*(tileScale.x or tileScale[1] or 2.25)*110
			local uiY=(localPos.z or localPos[3])*(tileScale.z or tileScale[3] or 2.25)*110
			local scale=0.38
			local id=terrain.guid.."ApocalypseHorsemanTarget"..tostring(index)
			group.xml[#group.xml+1]={tag="Button",attributes={id=id,onClick="global/apocalypseIsHereHorsemanTargetSelect",onMouseDown="global/buttonClicked",onMouseUp="global/buttonClicked",height=300,width=320,color="rgba(0,0,0,0.0)",position=uiX.." "..uiY.." "..(-40),rotation="0 0 "..tostring(terrain.getRotation()[2] or 180),scale=scale.." "..scale},children={{tag="Image",attributes={image="Sliced Button/Button Object Active",type="Sliced"}},{tag="Text",attributes={font="Fonts/MKCardText",fontSize="65",alignment="MiddleCenter",text=name.."\nTarget"}}}}
		end
	end
	for _,group in pairs(grouped) do group.terrain.UI.setXmlTable(group.xml) end
	gStates.apocalypseHereHorsemenUIState="WaitingChoice"
	gStates.apocalypseHereHorsemenTurnReport=name.." has tied preferred targets. "..againstDragonChoicePlayerLabel(pending.playerIndex).." must choose which site it moves toward."
	mainUIUpdate("Horseman target choice")
	return true
end

function apocalypseIsHereHorsemanTargetSelect(player,mouseButton,id)
	if mouseButton~="-1" or apocalypseIsHereActive()~=true then return end
	local pending=gStates.apocalypseHereHorsemanPendingChoice
	if pending==nil or againstDragonChoiceAuthorized(player,pending)~=true then return end
	local index=tonumber(tostring(id or ""):match("ApocalypseHorsemanTarget(%d+)$"))
	local targetKey=index~=nil and pending.targetKeys~=nil and pending.targetKeys[index] or nil
	if targetKey==nil then return end
	local liveOptions=apocalypseIsHereHorsemanTargetOptions(pending.name)
	local option=nil
	for _,candidate in ipairs(liveOptions or {}) do
		if candidate.key==targetKey then option=candidate break end
	end
	if option==nil then return end
	apocalypseIsHereClearChoiceButtons()
	gStates.apocalypseHereHorsemanPendingChoice=nil
	gStates.apocalypseHereHorsemenUIState="Processing"
	apocalypseIsHereResolveHorsemanTarget(pending.name,option)
end

function apocalypseIsHereHorsemanDestroyTarget(name,targetHex)
	local state=gStates.horsemen[name]
	local data=horsemanData[name]
	if state==nil or data==nil or targetHex==nil then return false end
	local _,mapObjects=apocalypseQuestMapHexes()
	for _,enemy in ipairs(proxyMonstersOnHex(targetHex,mapObjects)) do
		if horsemanTokenToName[enemy.guid]==nil then proxyDiscardMonster(enemy) end
	end
	local token=takeDestroyedSiteToken(targetHex.terrain,targetHex.bearing)
	if token~=nil then destroySite(token,targetHex.terrain,targetHex.bearing) end
	local oldHead=tonumber(gStates.apocalypseDragonHeadLevels~=nil and gStates.apocalypseDragonHeadLevels[name] or 0) or 0
	if oldHead>0 and oldHead<12 then apocalypseDragonSetHeadLevel(name,oldHead+1) end
	state.sitesDestroyed=(tonumber(state.sitesDestroyed) or 0)+1
	local report=name.." destroyed "..proxyFeatureDisplayName(targetHex.feature).." and raised the "..name.." Dragon head from Level "..tostring(oldHead).." to Level "..tostring(math.min(12,oldHead+1)).."."
	if state.sitesDestroyed>=4 then
		state.retired=true state.revealed=false state.removedAfterFour=true
		local token=getObjectFromGUID(data.tokenGUID)
		local apocBag=getObjectFromGUID(GUID.bag.apocalypseDragon)
		horsemanReleaseOccupiedToken(name)
		if token~=nil then token.unlock() if apocBag~=nil then apocBag.putObject(token) else token.setPosition({0,-20,0}) end end
		monsterPugs[data.tokenGUID]=nil
		if gStates.monsterPerks~=nil then gStates.monsterPerks[data.tokenGUID]=nil end
		report=report.." It has destroyed four sites and leaves the map."
	elseif (tonumber(state.level) or 1)>1 then
		state.level=state.level-1
		setHorsemanLevel(name,state.level,false)
		report=report.." "..name.." drops to Level "..tostring(state.level).."."
	end
	gStates.apocalypseHereHorsemenTurnReport=(gStates.apocalypseHereHorsemenTurnReport or "")..((gStates.apocalypseHereHorsemenTurnReport or "")~="" and "\n" or "")..report
	return true
end

function apocalypseIsHereResolveHorsemanTarget(name,option)
	local options,startHex,hexes,mapObjects=apocalypseIsHereHorsemanTargetOptions(name)
	local target=option~=nil and option.hex or nil
	if startHex==nil or target==nil then apocalypseIsHereContinueHorsemenTurn() return false end
	local destination=apocalypseIsHereHorsemanDestination(startHex,target,hexes,name,mapObjects)
	local data=horsemanData[name]
	local state=gStates.horsemen[name]
	local token=data~=nil and getObjectFromGUID(data.tokenGUID) or nil
	if token==nil or destination==nil then apocalypseIsHereContinueHorsemenTurn() return false end
	horsemanReleaseOccupiedToken(name)
	state.terrainGUID=destination.terrainGUID state.bearing=destination.bearing
	token.unlock() token.setRotation({0,180,0}) token.setPositionSmooth({destination.position[1],1.42,destination.position[3]},false)
	safeWaitCondition("Scenario",function()
		local reached=apocalypseQuestMapHexKey(destination)==apocalypseQuestMapHexKey(target)
		if reached then apocalypseIsHereHorsemanDestroyTarget(name,target)
		else
			local line=name.." moved two spaces toward "..proxyFeatureDisplayName(target.feature).."."
			gStates.apocalypseHereHorsemenTurnReport=(gStates.apocalypseHereHorsemenTurnReport or "")..((gStates.apocalypseHereHorsemenTurnReport or "")~="" and "\n" or "")..line
		end
		horsemanScheduleOccupiedTokenStack(name)
		apocalypseIsHereContinueHorsemenTurn()
	end,function() local current=getObjectFromGUID(data.tokenGUID) return current==nil or current.isSmoothMoving()==false end,5,function() apocalypseIsHereContinueHorsemenTurn() end)
	return true
end

function apocalypseIsHereProcessNextHorseman()
	if gStates.apocalypseHereHorsemenTurnActive~=true then return end
	local queue=gStates.apocalypseHereHorsemenQueue or {}
	local index=tonumber(gStates.apocalypseHereHorsemenQueueIndex) or 1
	local name=queue[index]
	if name==nil then
		gStates.apocalypseHereHorsemenUIState="ReadyToEnd"
		if (gStates.apocalypseHereHorsemenTurnReport or "")=="" then gStates.apocalypseHereHorsemenTurnReport="The Horsemen had no action to resolve." end
		mainUIUpdate("Horsemen Processed")
		return
	end
	gStates.apocalypseHereHorsemenQueueIndex=index+1
	local options=apocalypseIsHereHorsemanTargetOptions(name)
	if #options<1 then
		local line=name.." found no preferred undestroyed target and did not move."
		gStates.apocalypseHereHorsemenTurnReport=(gStates.apocalypseHereHorsemenTurnReport or "")..((gStates.apocalypseHereHorsemenTurnReport or "")~="" and "\n" or "")..line
		safeWaitFrames("Scenario",apocalypseIsHereProcessNextHorseman,1)
	elseif #options>1 then apocalypseIsHereShowTargetChoice(name,options)
	else apocalypseIsHereResolveHorsemanTarget(name,options[1]) end
end

function apocalypseIsHereContinueHorsemenTurn()
	if gStates.apocalypseHereHorsemenTurnActive~=true then return end
	gStates.apocalypseHereHorsemenUIState="Processing"
	safeWaitFrames("Scenario",apocalypseIsHereProcessNextHorseman,2)
end

function apocalypseIsHereActiveHorsemen()
	local list={}
	for _,name in ipairs(gStates.apocalypseHereHorsemanOrder or {}) do
		local state=gStates.horsemen~=nil and gStates.horsemen[name] or nil
		local data=horsemanData~=nil and horsemanData[name] or nil
		if state~=nil and data~=nil and state.revealed==true and state.defeated~=true and state.retired~=true and getObjectFromGUID(data.tokenGUID)~=nil then list[#list+1]=name end
	end
	return list
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
	gStates.apocalypseHereHorsemenTurnReport="The Horsemen act in the order they were revealed."
	gStates.apocalypseHereHorsemenUIState="ReadyToProcess"
	mainUIUpdate("Horsemen Turn")
	return true
end

function apocalypseIsHereMainUIPanelSpec()
	if apocalypseIsHereActive()~=true or gStates.apocalypseHereHorsemenTurnActive~=true then return nil end
	local state=gStates.apocalypseHereHorsemenUIState
	local label="{en}Processing Horsemen...{ru}Processing Horsemen...{zh-tw}Processing Horsemen...{zh-cn}Processing Horsemen...{ko}Processing Horsemen...{es}Processing Horsemen...{fr}Processing Horsemen...{pt-br}Processing Horsemen...{de}Processing Horsemen..."
	local active=false
	if state=="ReadyToProcess" then label="{en}Process Horsemen{ru}Process Horsemen{zh-tw}Process Horsemen{zh-cn}Process Horsemen{ko}Process Horsemen{es}Process Horsemen{fr}Process Horsemen{pt-br}Process Horsemen{de}Process Horsemen" active=true
	elseif state=="ReadyToEnd" then label="{en}Horsemen Processed{ru}Horsemen Processed{zh-tw}Horsemen Processed{zh-cn}Horsemen Processed{ko}Horsemen Processed{es}Horsemen Processed{fr}Horsemen Processed{pt-br}Horsemen Processed{de}Horsemen Processed" active=true
	elseif state=="WaitingChoice" then label="{en}Pick Target{ru}Pick Target{zh-tw}Pick Target{zh-cn}Pick Target{ko}Pick Target{es}Pick Target{fr}Pick Target{pt-br}Pick Target{de}Pick Target" end
	return {actor="horsemen",mainText="<size=25>Horsemen's Turn</size>",notes=gStates.apocalypseHereHorsemenTurnReport or "Process the Horsemen.",onClick="apocalypseIsHereProcessHorsemenUI",label=label,interactable=active}
end

function apocalypseIsHereMainUIRefresh()
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

function apocalypseIsHereFinishHorsemenTurn()
	if gStates.apocalypseHereHorsemenTurnActive~=true then return false end
	apocalypseIsHereClearChoiceButtons()
	UI.setAttribute("DummyTurn","active","false")
	local resume=gStates.apocalypseHereHorsemenResumeTurn
	gStates.apocalypseHereHorsemenTurnActive=false
	gStates.apocalypseHereHorsemenResumeTurn=nil
	gStates.apocalypseHereHorsemanPendingChoice=nil
	gStates.apocalypseHereHorsemenUIState=nil
	if resume~=nil then mergedTurnCommit(resume.turnNumber,resume.newOutOfTurn,resume.sameTurn) end
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
	broadcastToAll("The Apocalypse Dragon has been attacked. Every Horseman still on the map is removed; this does not count as defeating them.",{1,0.75,0.2})
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
	local info=volkarePursuitAvailable(playerIndex)
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
	broadcastToAll(joinLang({translateWord[turnOrder[playerIndex].mage],"{en} pursues Volkare's fleeing army.{ru} преследует отступающую армию Волкара.{zh-cn}追击沃卡里的溃军。{ko}: 볼케어의 패주하는 군대를 추격합니다.{es} persigue al ejército en fuga de Volkare.{fr} poursuit l'armée de Volkare en fuite.{pt-br} persegue o exército em fuga de Volkare.{de} verfolgt Volkares fliehende Armee."}),positionToColor(playerIndex))
	addAvatarButtons()
end

--Druid Nights Incantation is legal anywhere the Mage Knight cannot Interact with Locals.
--Use the map's interaction helper first so burned Monasteries and conquered/unconquered sites resolve correctly;
--the logical-location fallback also covers Portal/City parking where the physical avatar may be off the map.

function druidNightsCanIncantHere(playerIndex)
	local player=turnOrder[playerIndex]
	if player==nil or gStates.gameScenario~="Druid Nights" then return false end
	local hexes,mapObjects=apocalypseQuestMapHexes()
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
	broadcastToAll("{en}Performed Incantation to summon Monster(s) to your Player Board{ru}Прочтено заклинание, чтобы призвать Монстра(ов) на вашу игровую доску.{zh-cn}执行了咒语召唤怪物到你的玩家板{ko}주문을 시전하여 몬스터를 소환합니다{es}Encantamiento realizado para convocar Monstruos a tu Tablero de Jugador{fr}Incantation exécutée pour invoquer des monstres sur votre plateau de joueur{pt-br}Realizou um Encantamento para invocar Monstro(S) para seu Tabuleiro de Jogador{de}Beschwörung durchgeführt, um Monster auf dein Spielerbrett zu beschwören", positionToColor(playerIndex))
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

--Draw a Destroyed Site directly at its final table height. The supply is an Infinite Bag, so callers
--only need to handle a genuinely missing bag/object rather than token exhaustion.
function takeDestroyedSiteToken(terrain,bearing)
	if terrain==nil or bearing==nil then return nil end
	local bag=getObjectFromGUID(GUID.bag.destroyedSite)
	local center=angleToXY(terrain,bearing)
	if bag==nil or center==nil then return nil end
	return bag.takeObject({position={center[1],destroyedSiteRestingY,center[2]},rotation={0,180,0},smooth=false})
end

--A Destroyed Site has a known physical resting height. Put it straight onto the map surface rather
--than dropping it onto whatever is already on the hex. The generic token arranger then moves enemy
--tokens into their slight offsets and lets those pieces fall/relock above the marker.
function arrangeDestroyedSiteHex(token,terrain,bearing,afterArrange)
	if token==nil or terrain==nil or bearing==nil then return false end
	local map=getObjectFromGUID(mapArea)
	local center=angleToXY(terrain,bearing)
	if map==nil or center==nil then return false end

	token.unlock()
	token.setRotation({0,180,0})
	token.setPosition({center[1],destroyedSiteRestingY,center[2]})
	token.lock()

	local details=terrainTiles[terrain.guid]
	local hex={
		terrain=terrain,terrainGUID=terrain.guid,bearing=bearing,
		position={center[1],destroyedSiteRestingY,center[2]},
		hexType=details~=nil and details.hexType~=nil and details.hexType[bearing] or "",
		feature=details~=nil and details.hexFeature~=nil and details.hexFeature[bearing] or ""
	}
	local mapObjects=map.getObjects() or {}
	mapTokenArrangeHex(hex,mapObjects,nil,token)
	--A scripted enemy/site token can enter the map zone in a different physics frame. Recheck this
	--same base token several times so either arrival order converges to the same final arrangement.
	mapTokenScheduleObject(token.guid)
	if afterArrange~=nil then afterArrange() end
	return true
end

--Apply Destroyed Site state from one authoritative path. The helper owns the physical placement,
--so callers only need to obtain a Destroyed Site token and identify the target hex.
function destroySite(token,terrain,bearing)
	if token==nil or terrain==nil or bearing==nil or terrainTiles[terrain.guid]==nil then return false end
	local feature=terrainTiles[terrain.guid].hexFeature[bearing]
	if feature==nil or feature=="" or feature=="portal" or feature=="destroyed" or feature:sub(1,7)=="raised " then return false end
	arrangeDestroyedSiteHex(token,terrain,bearing)
	if gStates.destroyedSites==nil then gStates.destroyedSites={} end
	gStates.destroyedSites[token.guid]={hexFeature=feature, terrainTile=terrain.guid, hexAngle=bearing}
	terrainTiles[terrain.guid].hexFeature[bearing]="destroyed"
	if gStates.hexOverideSave[terrain.guid]==nil then gStates.hexOverideSave[terrain.guid]={} end
	gStates.hexOverideSave[terrain.guid][bearing]="destroyed"
	broadcastToAll(feature.." Destroyed")
	safeWaitFrames("Scenario",function() apocalypseQuestRefreshOfferButtons() end,2)
	return true
end

--Undo only the map assignment. Used when a player deliberately unlocks and moves an active Destroyed token.
function undoDestroyedSitePlacement(destroyed)
	if destroyed==nil or gStates.destroyedSites==nil then return false end
	local data=gStates.destroyedSites[destroyed.guid]
	if data==nil or terrainTiles[data.terrainTile]==nil then return false end
	terrainTiles[data.terrainTile].hexFeature[data.hexAngle]=data.hexFeature
	if gStates.hexOverideSave[data.terrainTile]~=nil then gStates.hexOverideSave[data.terrainTile][data.hexAngle]=nil end
	gStates.destroyedSites[destroyed.guid]=nil
	safeWaitFrames("Scenario",function() apocalypseQuestRefreshOfferButtons() end, 2)
	return true
end

function restoreDestroyedSite(destroyed, player)
	if destroyed==nil or player==nil or gStates.destroyedSites==nil then return false end
	local data=gStates.destroyedSites[destroyed.guid]
	if data==nil or terrainTiles[data.terrainTile]==nil then return false end
	broadcastToAll("Site Restored")
	if data.hexFeature=="keep" or data.hexFeature=="mage tower" then
		dropShield({destroyed.getPosition()[1], 2, destroyed.getPosition()[3]}, true)
		player.fameGain=player.fameGain+1
		broadcastToAll("and Fame Gained")
	end
	if data.hexFeature=="monastery" then playMonastery() end
	if data.hexFeature=="village" or data.hexFeature=="oasis" or data.hexFeature=="camp" then
		player.repGain=player.repGain+1
		broadcastToAll("and Reputation Gained")
	end
	mapTokenReleaseObject(destroyed)
	undoDestroyedSitePlacement(destroyed)
	destroyed.unlock()
	destroyed.setPositionSmooth({(player.seatPos*40)-117.2+(math.random()*6.5), 3, -35+(math.random()*3.2)})
	fakeDropAvatar()
	return true
end

function destroyRestoreLocation(playerDud, mouseButton, id, type, obj)
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
						--deploy possessed token
						getObjectFromGUID(GUID.bag.possessed).takeObject({position={angleToXY(obj, searchOrder[i])[1], 2, angleToXY(obj, searchOrder[i])[2]}})
						found=true
						break
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

function apocalypseDragonPossessSummonedEnemy(enemyGUID,target)
	local enemy=getObjectFromGUID(enemyGUID)
	if target==nil then
		if enemy==nil then return false end
		local p=enemy.getPosition()
		target={p[1],p[2],p[3]}
	end
	local bag=getObjectFromGUID(GUID.bag.possessed)
	if bag==nil or bag.getQuantity()==0 then
		tokenRefill()
		bag=getObjectFromGUID(GUID.bag.possessed)
	end
	if bag==nil or bag.getQuantity()==0 then return false end
	--Match the working Quest possessed-enemy path: draw both tokens to the same X/Z, with the
	--Possessed token above the enemy. Falling through the player scripting zone performs the link.
	local possessed=bag.takeObject({position={target[1],target[2]+1.10,target[3]},rotation={0,180,0},smooth=true})
	if possessed==nil then return false end
	gStates.apocalypsePossessedFactionByToken=gStates.apocalypsePossessedFactionByToken or {}
	gStates.apocalypsePossessedFactionByToken[possessed.guid]="Apoc"
	--Control-head summons are temporary enemies: neither the summoned monster nor its Possessed
	--token may award Fame or a Faction Reward. Mark the attachment with the same summoned state
	--used by ordinary monster cleanup so every reward path treats both pieces consistently.
	gStates.summonStates=gStates.summonStates or {}
	gStates.summonStates[possessed.guid]="summoned"
	return true
end

--City-card positions are arranged in rings around the City. EXPLORE refreshes use the complete current
--EXPLORE set, then choose the closest legal position once instead of first pushing a card away and immediately
--trying to compact it while setPositionSmooth is still moving it.

function apocalypseDragonScenario()
	return gStates~=nil and (gStates.gameScenario=="Against the Dragon Blitz" or gStates.gameScenario=="Apocalypse is Here" or gStates.gameScenario=="Fury of the Apocalypse Dragon")
end

function apocalypseDragonStartingLevel()
	if apocalypseDragonScenario()~=true then return nil end
	if gStates.gameScenario=="Fury of the Apocalypse Dragon" then
		if gStates.playerCount==1 then return 1 end
		return gStates.coop==1 and gStates.playerCount or gStates.playerCount-1
	end
	if gStates.playerCount==1 then
		if gStates.gameScenario=="Against the Dragon Blitz" then return 4 end
		return 5
	end
	if gStates.gameScenario=="Against the Dragon Blitz" then
		return gStates.playerCount+(gStates.coop==1 and 3 or 1)
	end
	return gStates.playerCount+(gStates.coop==1 and 4 or 2)
end

function apocalypseDragonHeadData(headName)
	for _,headData in ipairs(apocalypseDragon.heads) do if headData.name==headName then return headData end end
	return nil
end

function apocalypseDragonCurrentLevelData(headName,level)
	local data=apocalypseDragonLevelData~=nil and apocalypseDragonLevelData[headName] or nil
	level=math.floor(tonumber(level) or 0)
	if data==nil or level<1 or level>12 then return nil end
	return data.levels~=nil and data.levels[level] or nil
end

function apocalypseDragonHeadTokenPosition(headData)
	if headData==nil or headData.position==nil then return nil end
	return {headData.position[1],headData.position[2]+0.12,headData.position[3]}
end

function apocalypseDragonPositionHeadToken(headData)
	if headData==nil or headData.tokenGUID==nil then return false end
	local token=getObjectFromGUID(headData.tokenGUID)
	local target=apocalypseDragonHeadTokenPosition(headData)
	if token==nil or target==nil then return false end
	local pos=token.getPosition()
	local moved=math.abs(pos[1]-target[1])>0.03 or math.abs(pos[2]-target[2])>0.03 or math.abs(pos[3]-target[3])>0.03
	token.setLock(false)
	if moved==true then token.setPosition(target) end
	token.setRotation({0,180,0})
	token.setLock(true)
	return moved
end

function apocalypseDragonCopyAttack(attack,bonus)
	if type(attack)~="table" then return nil end
	local copied={}
	for attackType,values in pairs(attack) do
		if type(values)=="table" then
			copied[attackType]={}
			for _,value in ipairs(values) do copied[attackType][#copied[attackType]+1]=(tonumber(value) or 0)+(bonus or 0) end
		end
	end
	return copied
end

function apocalypseDragonMonsterData(headName,level)
	local levelData=apocalypseDragonCurrentLevelData(headName,level)
	if levelData==nil then return nil end
	local data={name="Apocalypse Dragon - "..headName,pugType="dragonHead",dragonHead=headName,dragonHeadLevel=level}
	for key,value in pairs(levelData) do
		if key~="image" and key~="attackBonus" and key~="possessedSummon" then
			if key=="attack" then data.attack=apocalypseDragonCopyAttack(value,0)
			elseif key=="monsters" then
				data.monsters={}
				for _,monsterColor in ipairs(value) do data.monsters[#data.monsters+1]=monsterColor end
			else data[key]=value end
		end
	end
	return data
end

--Refresh the persistent small head token stats. Printed level data lives in monsterPugs; Control's
--whole-head Attack bonus is a runtime monsterPerks attack override so every displayed attack gets it.
function apocalypseDragonRefreshRuntimeData()
	if gStates==nil then return end
	local monsterPerks=gStates.monsterPerks
	if monsterPerks==nil then
		monsterPerks={}
		gStates.monsterPerks=monsterPerks
	end
	for _,headData in ipairs(apocalypseDragon.heads) do
		local tokenGUID=headData.tokenGUID
		if tokenGUID~=nil then
			local level=tonumber(gStates.apocalypseDragonHeadLevels~=nil and gStates.apocalypseDragonHeadLevels[headData.name] or 0) or 0
			if level>0 then monsterPugs[tokenGUID]=apocalypseDragonMonsterData(headData.name,level) else monsterPugs[tokenGUID]=nil end
			local perks=monsterPerks[tokenGUID]
			if perks~=nil and perks.dragonControlBonus~=nil then
				perks.attack=nil
				perks.dragonControlBonus=nil
				if next(perks)==nil then monsterPerks[tokenGUID]=nil end
			end
			if headData.name~="Control" then syncDragonHeadAttackBonusDecal(tokenGUID,0) end
		end
	end
	local headLevels=gStates.apocalypseDragonHeadLevels or {}
	local controlLevel=tonumber(headLevels.Control) or 0
	local controlData=apocalypseDragonCurrentLevelData("Control",controlLevel)
	local bonus=controlData~=nil and tonumber(controlData.attackBonus) or 0
	if bonus>0 then
		for _,headName in ipairs(apocalypseDragonColoredHeads or {}) do
			local headData=apocalypseDragonHeadData(headName)
			if headData~=nil and headData.tokenGUID~=nil then
				local tokenGUID=headData.tokenGUID
				local printed=monsterPugs[tokenGUID]
				if printed~=nil and printed.attack~=nil then
					local perks=monsterPerks[tokenGUID] or {}
					perks.attack=apocalypseDragonCopyAttack(printed.attack,bonus)
					perks.dragonControlBonus=bonus
					monsterPerks[tokenGUID]=perks
					syncDragonHeadAttackBonusDecal(tokenGUID,bonus)
				end
			end
		end
	end
end

function apocalypseDragonApplyHeadLevel(headName,level)
	local headData=apocalypseDragonHeadData(headName)
	local tokenData=apocalypseDragonLevelData~=nil and apocalypseDragonLevelData[headName] or nil
	if headData==nil or tokenData==nil then return false end
	level=math.max(0,math.min(12,math.floor(tonumber(level) or 0)))
	local token=getObjectFromGUID(headData.tokenGUID)
	local levelData=level>0 and apocalypseDragonCurrentLevelData(headName,level) or nil
	local image=levelData~=nil and levelData.image or tokenData.blank
	if token~=nil then
		token.setLock(false)
		if type(image)=="string" and image~="" then token.setCustomObject({image=image}) end
		token.setName(level>0 and (headName.." Dragon Head Level "..tostring(level)) or (headName.." Dragon Head Defeated"))
		token.reload()
		safeWaitFrames("Scenario",function()
			local current=getObjectFromGUID(headData.tokenGUID)
			if current~=nil then apocalypseDragonPositionHeadToken(headData) end
		end,1)
	end
	apocalypseDragonRefreshRuntimeData()
	return true
end

function apocalypseDragonDeployHeadToken(headData,bag)
	if headData==nil or headData.tokenGUID==nil then return nil end
	local target=apocalypseDragonHeadTokenPosition(headData)
	if target==nil then return nil end
	local token=getObjectFromGUID(headData.tokenGUID)
	if token==nil and bag~=nil then
		token=bag.takeObject({guid=headData.tokenGUID,position=target,rotation={0,180,0},smooth=false})
	elseif token~=nil then
		token.setLock(false)
		token.setPosition(target)
		token.setRotation({0,180,0})
	end
	if token~=nil then token.setLock(true) end
	return token
end

--The Dragon heads use the same 12-position circular level layout as the Shades of Tezla leader discs.
--Level 1 is at the top, then levels advance clockwise in 30-degree steps.
function apocalypseDragonLevelMarkerPosition(head,level)
	if head==nil or level==nil or level<1 then return nil end
	local angle=math.rad(120-(30*level))
	local pos=head.getPosition()
	return {pos[1]+(math.cos(angle)*apocalypseDragon.levelMarkerRadius),1.12,pos[3]+(math.sin(angle)*apocalypseDragon.levelMarkerRadius)}
end

function apocalypseDragonLockLevelMarker(marker,target)
	if marker==nil or target==nil then return end
	marker.setLock(false)
	marker.setPosition(target)
	marker.setRotation({0,180,0})
	marker.setLock(true)
end


function apocalypseDragonColoredHeadsDefeated()
	if gStates==nil or type(gStates.apocalypseDragonHeadLevels)~="table" then return false end
	for _,headName in ipairs(apocalypseDragonColoredHeads) do
		if tonumber(gStates.apocalypseDragonHeadLevels[headName])~=0 then return false end
	end
	return true
end

function apocalypseDragonDefeatedHeadCount()
	if gStates==nil or type(gStates.apocalypseDragonHeadLevels)~="table" then return 0 end
	local count=0
	for _,headName in ipairs(apocalypseDragonColoredHeads) do
		if tonumber(gStates.apocalypseDragonHeadLevels[headName])==0 then count=count+1 end
	end
	return count
end

function apocalypseDragonSyncControlLevel()
	if gStates==nil or type(gStates.apocalypseDragonHeadLevels)~="table" then return false end
	local highest=0
	local found=false
	for _,headName in ipairs(apocalypseDragonColoredHeads) do
		local level=tonumber(gStates.apocalypseDragonHeadLevels[headName])
		if level~=nil then
			found=true
			if level>highest then highest=level end
		end
	end
	if found~=true then return false end
	if tonumber(gStates.apocalypseDragonHeadLevels.Control)==highest then return false end
	return apocalypseDragonSetHeadLevel("Control",highest)
end

function againstDragonDefeatCheck()
	if gStates==nil or (gStates.gameScenario~="Against the Dragon Blitz" and gStates.gameScenario~="Apocalypse is Here") or gStates.apocalypseDragonDefeated==true then return false end
	if apocalypseDragonColoredHeadsDefeated()~=true then return false end

	gStates.apocalypseDragonDefeated=true
	gStates.apocalypseDragonDefeatedRound=gStates.currentRound
	gStates.apocalypseDragonLairAttacked=true
	if tonumber(gStates.apocalypseDragonHeadLevels.Control)~=0 then apocalypseDragonSetHeadLevel("Control",0) end

	local dragon=getObjectFromGUID(apocalypseDragon.model)
	if dragon~=nil then
		local trash=getObjectFromGUID(trashCan)
		if trash~=nil then trash.putObject(dragon) else dragon.destruct() end
	end

	broadcastToAll("{en}The Apocalypse Dragon has been defeated! All players have one final turn.{ru}The Apocalypse Dragon has been defeated! All players have one final turn.{zh-tw}The Apocalypse Dragon has been defeated! All players have one final turn.{zh-cn}The Apocalypse Dragon has been defeated! All players have one final turn.{ko}The Apocalypse Dragon has been defeated! All players have one final turn.{es}The Apocalypse Dragon has been defeated! All players have one final turn.{fr}The Apocalypse Dragon has been defeated! All players have one final turn.{pt-br}The Apocalypse Dragon has been defeated! All players have one final turn.{de}The Apocalypse Dragon has been defeated! All players have one final turn.",{1,1,0.5})
	local coopDragon=gStates.coopAssaultPhase=="combat" and coopAssaultTargetType~=nil and coopAssaultTargetType()=="dragon"
	if coopDragon==true then gStates.coopAssaultScenarioEndPending=true
	elseif gStates.endGameAchieved=="false" then scenarioEnd() end
	return true
end

function apocalypseDragonHeadStateChanged(headName)
	if headName~="Control" then apocalypseDragonSyncControlLevel() end
	if gStates~=nil and (gStates.gameScenario=="Against the Dragon Blitz" or gStates.gameScenario=="Apocalypse is Here") then againstDragonDefeatCheck() end
end

--Read the physical player Shields on the four large coloured head boards.
--This is only used by end-game scoring, so a one-off getAllObjects() scan is acceptable.
function againstDragonCompetitiveScoreSummary()
	local summary={defeatedHeads=apocalypseDragonDefeatedHeadCount(),byMage={},heads={}}
	local mageToPlayer={}
	for playerIndex,details in ipairs(turnOrder or {}) do
		if details~=nil and details.mage~=gStates.positionMageKnight[5] then
			mageToPlayer[details.mage]=playerIndex
			summary.byMage[details.mage]={levels=0,slayerBonus=0,slayerHeads={}}
		end
	end

	local slots={}
	for _,headName in ipairs(apocalypseDragonColoredHeads) do
		local headData=apocalypseDragonHeadData(headName)
		local head=headData~=nil and getObjectFromGUID(headData.guid) or nil
		local headSummary={countByMage={},highestByMage={},winner=nil}
		summary.heads[headName]=headSummary
		if head~=nil then
			for level=1,12 do
				local pos=apocalypseDragonLevelMarkerPosition(head,level)
				if pos~=nil then slots[#slots+1]={head=headName,level=level,pos=pos} end
			end
		end
	end

	for _,obj in ipairs(getAllObjects()) do
		if obj.getName()=="Shield" then
			local mage=obj.getDescription()
			if mageToPlayer[mage]~=nil then
				local pos=obj.getPosition()
				local nearest=nil
				local best=0.72
				for _,slot in ipairs(slots) do
					local dist=math.sqrt(((pos[1]-slot.pos[1])^2)+((pos[3]-slot.pos[3])^2))
					if dist<best then best=dist nearest=slot end
				end
				if nearest~=nil then
					local headSummary=summary.heads[nearest.head]
					headSummary.countByMage[mage]=(headSummary.countByMage[mage] or 0)+1
					headSummary.highestByMage[mage]=math.max(headSummary.highestByMage[mage] or 0,nearest.level)
				end
			end
		end
	end

	if gStates.gameScenario=="Apocalypse is Here" then
		for _,headName in ipairs(apocalypseDragonColoredHeads) do
			local state=gStates.horsemen~=nil and gStates.horsemen[headName] or nil
			local mage=state~=nil and (state.defeatedBy or (gStates.horsemenDefeatedBy~=nil and gStates.horsemenDefeatedBy[headName] or nil)) or nil
			local headSummary=summary.heads[headName]
			if state~=nil and state.defeated==true and mage~=nil and summary.byMage[mage]~=nil and headSummary~=nil then
				local bonus=math.max(1,math.min(6,tonumber(state.defeatedLevel or state.level) or 1))
				headSummary.countByMage[mage]=(headSummary.countByMage[mage] or 0)+bonus
			end
		end
	end

	for headName,headSummary in pairs(summary.heads) do
		local bestCount=0
		local bestHighest=0
		local winner=nil
		for mage,_ in pairs(mageToPlayer) do
			local count=headSummary.countByMage[mage] or 0
			local highest=headSummary.highestByMage[mage] or 0
			if count>bestCount or (count==bestCount and count>0 and highest>bestHighest) then
				bestCount=count
				bestHighest=highest
				winner=mage
			elseif count==bestCount and count>0 and highest==bestHighest then
				--A genuine game cannot place two different player Shields on the same highest level.
				--If a malformed board does, leave the +5 unresolved rather than inventing a tiebreaker.
				winner=nil
			end
		end
		headSummary.winner=winner
		for mage,data in pairs(summary.byMage) do
			data.levels=data.levels+(headSummary.countByMage[mage] or 0)
			if winner==mage then
				data.slayerBonus=data.slayerBonus+5
				data.slayerHeads[#data.slayerHeads+1]=headName
			end
		end
	end
	return summary
end

function apocalypseDragonSetHeadLevel(headName,level)
	local headData=apocalypseDragonHeadData(headName)
	local head=headData~=nil and getObjectFromGUID(headData.guid) or nil
	if head==nil then return false end
	level=math.max(0,math.min(12,math.floor(tonumber(level) or 0)))
	gStates.apocalypseDragonHeadLevels=gStates.apocalypseDragonHeadLevels or {}
	gStates.apocalypseDragonLevelMarkers=gStates.apocalypseDragonLevelMarkers or {}
	gStates.apocalypseDragonHeadLevels[headName]=level
	local markerGUID=gStates.apocalypseDragonLevelMarkers[headName]
	local marker=markerGUID~=nil and getObjectFromGUID(markerGUID) or nil
	if level==0 then
		if marker~=nil then marker.destruct() end
		gStates.apocalypseDragonLevelMarkers[headName]=nil
		apocalypseDragonApplyHeadLevel(headName,level)
		apocalypseDragonHeadStateChanged(headName)
		return true
	end
	local target=apocalypseDragonLevelMarkerPosition(head,level)
	if target==nil then return false end
	if marker==nil then
		local shieldBag=getObjectFromGUID(GUID.bag.neutralShield)
		if shieldBag==nil then return false end
		marker=shieldBag.takeObject({position=target,rotation={0,180,0},smooth=false})
		if marker==nil then return false end
		gStates.apocalypseDragonLevelMarkers[headName]=marker.guid
	end
	--The Dragon head boards are fixed, so use the tested table height directly.
	target=apocalypseDragonLevelMarkerPosition(head,level)
	marker.setName(headName.." Dragon Head Level "..level)
	apocalypseDragonLockLevelMarker(marker,target)
	apocalypseDragonApplyHeadLevel(headName,level)
	apocalypseDragonHeadStateChanged(headName)
	return true
end

function setupApocalypseDragonHeads()
	if apocalypseDragonScenario()~=true then return end
	local startingLevel=apocalypseDragonStartingLevel()
	gStates.apocalypseDragonHeadLevels={}
	gStates.apocalypseDragonLevelMarkers={}
	local bag=getObjectFromGUID(GUID.bag.apocalypseDragon)
	if gStates.gameScenario=="Against the Dragon Blitz" then
		local roundToken=getObjectFromGUID(apocalypseDragon.roundOrder)
		local roundPos={-1.90,0.97,-22.20}
		if roundToken==nil and bag~=nil then
			roundToken=bag.takeObject({guid=apocalypseDragon.roundOrder,position=roundPos,rotation={0,180,0},smooth=false})
		elseif roundToken~=nil then
			roundToken.setPosition(roundPos)
			roundToken.setRotation({0,180,0})
		end
		if roundToken~=nil then roundToken.lock() end
	end
	for _,headData in ipairs(apocalypseDragon.heads) do
		local head=getObjectFromGUID(headData.guid)
		if head==nil and bag~=nil then
			head=bag.takeObject({guid=headData.guid,position=headData.position,rotation={0,180,0},smooth=false})
		elseif head~=nil then
			head.setPosition(headData.position)
			head.setRotation({0,180,0})
		end
		if head~=nil then head.lock() end
		apocalypseDragonDeployHeadToken(headData,bag)
	end
	safeWaitFrames("Scenario",function()
		for _,headData in ipairs(apocalypseDragon.heads) do apocalypseDragonSetHeadLevel(headData.name,startingLevel) end
	end,2)
	if gStates.gameScenario~="Fury of the Apocalypse Dragon" then
		local dragon=getObjectFromGUID(apocalypseDragon.model)
		if dragon==nil and bag~=nil then
			dragon=bag.takeObject({guid=apocalypseDragon.model,position=apocalypseDragon.modelPosition,rotation={0,180,180},smooth=false})
		elseif dragon~=nil then
			dragon.setPosition(apocalypseDragon.modelPosition)
			dragon.setRotation({0,180,180})
		end
		if dragon~=nil then dragon.setLock(false) end
	end
end

function apocalypseDragonLockModelWhenSettled()
	local guid=apocalypseDragon.model
	local function lockDragon()
		local dragon=getObjectFromGUID(guid)
		if dragon~=nil then dragon.lock() end
	end
	safeWaitCondition("Scenario",lockDragon,function()
		local dragon=getObjectFromGUID(guid)
		return dragon==nil or dragon.resting==true
	end,5,lockDragon)
end

--Against the Dragon: Core non-City tile 3 reveals the Dragon's three-space lair.
--The Dragon keeps its normal map orientation. Its model origin is the centre of the front hex,
--so it is placed directly on the main/centre hex and the two rear hexes fall behind it.
--Random Tile Orientation rotates the printed hexes underneath this fixed footprint.
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
				terrainTiles[currentTile.guid].hexFeature[hex.bearing]=""
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
function apocalypseDragonLairContainsPosition(pos)
	if pos==nil or gStates==nil or gStates.apocalypseDragonLairRevealed~=true or gStates.apocalypseDragonLair==nil then return false end
	for _,hex in ipairs(gStates.apocalypseDragonLair.hexes or {}) do
		local p=hex.position
		if p~=nil and ((pos[1]-p[1])^2)+((pos[3]-p[3])^2)<2.25 then return true end
	end
	return false
end

function apocalypseDragonGroundCombatForPlayer(playerIndex)
	local combat=gStates~=nil and gStates.apocalypseDragonGroundCombat or nil
	if combat==nil or combat.finished==true then return false end
	if combat.coop==true then return combat.players~=nil and combat.players[playerIndex]==true and (combat.finishedPlayers==nil or combat.finishedPlayers[playerIndex]~=true) end
	return combat.playerIndex==playerIndex
end

function apocalypseDragonGroundHeadNameForGUID(guid)
	if guid==nil then return nil end
	for _,headData in ipairs(apocalypseDragon.heads) do if headData.tokenGUID==guid then return headData.name end end
	local combat=gStates~=nil and gStates.apocalypseDragonGroundCombat or nil
	if combat~=nil and combat.controlClones~=nil and combat.controlClones[guid]~=nil then return "Control" end
	return nil
end

function apocalypseDragonGroundHeadOwner(headName)
	local combat=gStates~=nil and gStates.apocalypseDragonGroundCombat or nil
	if combat==nil or headName==nil then return nil end
	if combat.headOwners~=nil and combat.headOwners[headName]~=nil then return combat.headOwners[headName] end
	return combat.playerIndex
end

function apocalypseDragonGroundHeadToken(guid)
	local combat=gStates~=nil and gStates.apocalypseDragonGroundCombat or nil
	local headName=apocalypseDragonGroundHeadNameForGUID(guid)
	if combat==nil or headName==nil then return false,headName end
	if headName=="Control" and combat.controlClones~=nil and combat.controlClones[guid]~=nil then return false,headName end
	return combat.deployed~=nil and combat.deployed[headName]==true,headName
end

function apocalypseDragonGroundControlToken(guid)
	local combat=gStates~=nil and gStates.apocalypseDragonGroundCombat or nil
	if combat==nil or guid==nil then return false,nil end
	local controlData=apocalypseDragonHeadData("Control")
	if controlData~=nil and guid==controlData.tokenGUID and combat.deployed~=nil and combat.deployed.Control==true then return true,combat.playerIndex end
	if combat.controlClones~=nil and combat.controlClones[guid]~=nil then return true,combat.controlClones[guid] end
	return false,nil
end

function apocalypseDragonGroundCombatToken(guid)
	local active,headName=apocalypseDragonGroundHeadToken(guid)
	if active==true then return true,headName,apocalypseDragonGroundHeadOwner(headName) end
	local control,owner=apocalypseDragonGroundControlToken(guid)
	if control==true then return true,"Control",owner end
	return false,nil,nil
end

function apocalypseDragonGroundTokenPosition(playerIndex,slot)
	local details=turnOrder[playerIndex]
	if details==nil then return nil end
	--Keep the Dragon fight clear of the normal left-side combat controls: two enemy slots right.
	return {(details.seatPos*40)-100+((slot-1)*2.5),1.5,-39.25}
end

function apocalypseDragonGroundReduction(headName)
	local combat=gStates~=nil and gStates.apocalypseDragonGroundCombat or nil
	if combat==nil or combat.reductions==nil then return 1 end
	return math.max(1,math.floor(tonumber(combat.reductions[headName]) or 1))
end

function apocalypseDragonGroundMarkedThroughOne(headName)
	local combat=gStates~=nil and gStates.apocalypseDragonGroundCombat or nil
	if combat==nil then return false end
	if combat.headMarkedToOne~=nil and combat.headMarkedToOne[headName]==true then return true end
	local level=tonumber(gStates.apocalypseDragonHeadLevels~=nil and gStates.apocalypseDragonHeadLevels[headName] or 0) or 0
	if level<=0 then return true end
	local headData=apocalypseDragonHeadData(headName)
	local token=headData~=nil and getObjectFromGUID(headData.tokenGUID) or nil
	if token==nil or combat.processedTokens~=nil and combat.processedTokens[token.guid]==true then return false end
	--Future co-op participants cannot suppress the current player's Control attack by pre-adjusting
	--their head before their own combat. Only resolved earlier heads plus the current participant count.
	local owner=apocalypseDragonGroundHeadOwner(headName)
	if combat.coop==true and owner~=gStates.turnNumber then return false end
	return token.is_face_down==false and apocalypseDragonGroundReduction(headName)>=level
end

function apocalypseDragonGroundControlGUIDs()
	local combat=gStates~=nil and gStates.apocalypseDragonGroundCombat or nil
	local guids={}
	if combat==nil then return guids end
	local controlData=apocalypseDragonHeadData("Control")
	if controlData~=nil and combat.deployed~=nil and combat.deployed.Control==true then guids[#guids+1]=controlData.tokenGUID end
	for guid,_ in pairs(combat.controlClones or {}) do guids[#guids+1]=guid end
	return guids
end

function apocalypseDragonRefreshGroundAttackSuppression()
	local combat=gStates~=nil and gStates.apocalypseDragonGroundCombat or nil
	if combat==nil then return false end
	gStates.monsterPerks=gStates.monsterPerks or {}
	local controlLevel=tonumber(gStates.apocalypseDragonHeadLevels~=nil and gStates.apocalypseDragonHeadLevels.Control or 0) or 0
	local controlLevelData=apocalypseDragonCurrentLevelData("Control",controlLevel)
	local controlBonus=controlLevelData~=nil and tonumber(controlLevelData.attackBonus) or 0
	for _,headName in ipairs(apocalypseDragonColoredHeads) do
		local headData=apocalypseDragonHeadData(headName)
		local level=tonumber(gStates.apocalypseDragonHeadLevels~=nil and gStates.apocalypseDragonHeadLevels[headName] or 0) or 0
		if level>0 then
			if headData~=nil and combat.deployed~=nil and combat.deployed[headName]==true then
				local printed=apocalypseDragonMonsterData(headName,level)
				if printed~=nil then
					--The head remains at its entered-combat level until cleanup. The player decides combat
					--phase timing manually, so the reduction dial never changes/suppresses its printed stats.
					printed.fame=1
					monsterPugs[headData.tokenGUID]=printed
				end
				local perks=gStates.monsterPerks[headData.tokenGUID] or {}
				perks.attack=nil
				perks.dragonControlBonus=nil
				if controlBonus>0 and printed~=nil and printed.attack~=nil then
					perks.attack=apocalypseDragonCopyAttack(printed.attack,controlBonus)
					perks.dragonControlBonus=controlBonus
				end
				gStates.monsterPerks[headData.tokenGUID]=perks
				syncDragonHeadAttackBonusDecal(headData.tokenGUID,(controlBonus>0 and printed~=nil and printed.attack~=nil) and controlBonus or 0)
			end
		end
	end
	for _,guid in ipairs(apocalypseDragonGroundControlGUIDs()) do
		local control=getObjectFromGUID(guid)
		if control~=nil and controlLevel>0 then
			local printed=apocalypseDragonMonsterData("Control",controlLevel)
			if printed~=nil then
				printed.fame=0
				monsterPugs[guid]=printed
			end
			local perks=gStates.monsterPerks[guid] or {}
			perks.dragonGround=true
			perks.dragonGroundLevel=controlLevel
			perks.dragonLevelFame=nil
			gStates.monsterPerks[guid]=perks
			setMonsterObjectButtons(control)
		end
	end
	return true
end

function apocalypseDragonGroundReductionAdjust(player,mouseButton,id)
	if mouseButton~="-1" then return end
	local guid=tostring(id or ""):sub(1,6)
	local active,headName=apocalypseDragonGroundHeadToken(guid)
	local combat=gStates~=nil and gStates.apocalypseDragonGroundCombat or nil
	if active~=true or combat==nil or headName==nil or headName=="Control" then return end
	local owner=apocalypseDragonGroundHeadOwner(headName)
	if owner==nil then return end
	if combat.finishedPlayers~=nil and combat.finishedPlayers[owner]==true then return end
	local color=player~=nil and player.color or nil
	local allowed=positionToColor(owner)
	if color~="Black" and color~=allowed then return end
	local current=tonumber(gStates.apocalypseDragonHeadLevels~=nil and gStates.apocalypseDragonHeadLevels[headName] or 0) or 0
	if current<1 then return end
	local value=apocalypseDragonGroundReduction(headName)
	if id:find("GroundOverkillUp",1,true)~=nil and value<current then value=value+1 end
	if id:find("GroundOverkillDown",1,true)~=nil and value>1 then value=value-1 end
	local reductions=combat.reductions or {}
	combat.reductions=reductions
	reductions[headName]=value
	local token=getObjectFromGUID(guid)
	if token~=nil then token.UI.setAttribute(guid.."GroundOverkill","text",tostring(value)) end
	apocalypseDragonRefreshGroundAttackSuppression()
	apocalypseDragonRefreshGroundFameGain(owner)
	mainUIUpdate("Dragon Head Reduction")
end

function apocalypseDragonGroundHeadButtons(obj)
	local active,headName=apocalypseDragonGroundHeadToken(obj~=nil and obj.guid or nil)
	if active~=true or headName==nil or headName=="Control" then return {} end
	local combat=gStates~=nil and gStates.apocalypseDragonGroundCombat or nil
	if combat~=nil and combat.processedTokens~=nil and combat.processedTokens[obj.guid]==true then return {} end
	local value=apocalypseDragonGroundReduction(headName)
	return {
		{tag="Button",attributes={id=obj.guid.."GroundOverkillUp",onMouseDown="global/buttonClicked",onMouseUp="global/buttonClicked",onClick="global/apocalypseDragonGroundReductionAdjust",height=50/0.9,width=50/0.9,color="rgba(0,0,0,0.0)",position="-62 "..tostring(-120/0.9).." "..tostring(-15/0.9),rotation="0 0 180"},children={{tag="Image",attributes={id=obj.guid.."GroundOverkillUpImage",image="Overkill Up"}}}},
		{tag="Image",attributes={image="Overkill Text",height=50/0.9,width=55/0.9,position="0 "..tostring(-120/0.9).." "..tostring(-15/0.9),rotation="0 0 180"},children={{tag="Text",attributes={id=obj.guid.."GroundOverkill",color="rgb(0,0,0)",fontSize="45",fontStyle="Bold",alignment="MiddleCenter",text=tostring(value)}}}},
		{tag="Button",attributes={id=obj.guid.."GroundOverkillDown",onMouseDown="global/buttonClicked",onMouseUp="global/buttonClicked",onClick="global/apocalypseDragonGroundReductionAdjust",height=50/0.9,width=50/0.9,color="rgba(0,0,0,0.0)",position="62 "..tostring(-120/0.9).." "..tostring(-15/0.9),rotation="0 0 180"},children={{tag="Image",attributes={id=obj.guid.."GroundOverkillDownImage",image="Overkill Down"}}}}
	}
end

function apocalypseDragonGroundPrepareColoredHead(combat,headName,playerIndex)
	local headData=apocalypseDragonHeadData(headName)
	local level=tonumber(gStates.apocalypseDragonHeadLevels~=nil and gStates.apocalypseDragonHeadLevels[headName] or 0) or 0
	if headData==nil or level<=0 then return false end
	local token=getObjectFromGUID(headData.tokenGUID)
	if token==nil then return false end
	combat.deployed[headName]=true
	combat.headOwners[headName]=playerIndex
	combat.reductions[headName]=1
	local printed=apocalypseDragonMonsterData(headName,level)
	if printed~=nil then
		printed.fame=1
		if combat.fortifiedPlayers~=nil and combat.fortifiedPlayers[playerIndex]==true then printed.fortified=true end
		monsterPugs[headData.tokenGUID]=printed
	end
	local perks=gStates.monsterPerks[headData.tokenGUID] or {}
	perks.dragonGround=true
	perks.dragonGroundLevel=level
	perks.dragonLevelFame=1
	gStates.monsterPerks[headData.tokenGUID]=perks
	gStates.monsterPlayLocation[headData.tokenGUID]=apocalypseDragonHeadTokenPosition(headData)
	token.setLock(false)
	token.setRotation({0,180,0})
	setMonsterObjectButtons(token)
	return true
end

function apocalypseDragonGroundPrepareControl(combat,playerIndex,slot,useOriginal)
	local controlData=apocalypseDragonHeadData("Control")
	local level=tonumber(gStates.apocalypseDragonHeadLevels~=nil and gStates.apocalypseDragonHeadLevels.Control or 0) or 0
	if controlData==nil or level<=0 then return nil end
	local original=getObjectFromGUID(controlData.tokenGUID)
	if original==nil then return nil end
	local target=apocalypseDragonGroundTokenPosition(playerIndex,slot)
	local token=original
	if useOriginal~=true then
		token=original.clone({position=target,rotation={0,180,0},smooth=false})
		if token==nil then return nil end
		combat.controlClones[token.guid]=playerIndex
	else
		combat.deployed.Control=true
		gStates.monsterPlayLocation[controlData.tokenGUID]=apocalypseDragonHeadTokenPosition(controlData)
		original.setLock(false)
		original.setRotation({0,180,0})
		if target~=nil then original.setPositionSmooth(target,false,true) end
	end
	local printed=apocalypseDragonMonsterData("Control",level)
	if printed~=nil then printed.fame=0 monsterPugs[token.guid]=printed end
	local perks=gStates.monsterPerks[token.guid] or {}
	perks.dragonGround=true
	perks.dragonGroundLevel=level
	perks.dragonLevelFame=nil
	gStates.monsterPerks[token.guid]=perks
	token.setLock(false)
	token.setRotation({0,180,0})
	if useOriginal~=true and target~=nil then token.setPosition(target) end
	safeWaitFrames("Scenario",function() local current=getObjectFromGUID(token.guid) if current~=nil then setMonsterObjectButtons(current) end end,2)
	return token
end

function apocalypseDragonNewGroundCombat(coop)
	return {coop=coop==true,players={},headOwners={},deployed={},reductions={},processedTokens={},headMarkedToOne={},fameByPlayer={},previewFameByPlayer={},finishedPlayers={},controlClones={},fortifiedPlayers={},finished=false,levelsApplied=false}
end

function apocalypseDragonGroundTokenInPlayerArea(tokenGUID,playerIndex)
	local details=turnOrder[playerIndex]
	if tokenGUID==nil or details==nil then return false end
	for _,obj in pairs(playerCombatObjects(details.seatPos)) do if obj.guid==tokenGUID then return true end end
	return false
end

function apocalypseDragonRefreshGroundFameGain(playerIndex)
	local combat=gStates~=nil and gStates.apocalypseDragonGroundCombat or nil
	local details=turnOrder[playerIndex]
	if combat==nil or details==nil or combat.finished==true then return false end
	--Resolved heads stay earned while unprocessed heads behave like faction leaders: they only
	--contribute while face up and physically inside their owner's Play/Unit combat area.
	local total=tonumber(combat.fameByPlayer~=nil and combat.fameByPlayer[playerIndex] or 0) or 0
	for _,headName in ipairs(apocalypseDragonColoredHeads) do
		if apocalypseDragonGroundHeadOwner(headName)==playerIndex and combat.deployed~=nil and combat.deployed[headName]==true then
			local headData=apocalypseDragonHeadData(headName)
			local token=headData~=nil and getObjectFromGUID(headData.tokenGUID) or nil
			if token~=nil and (combat.processedTokens==nil or combat.processedTokens[token.guid]~=true) and token.is_face_down==false
				and apocalypseDragonGroundTokenInPlayerArea(token.guid,playerIndex)==true then
				total=total+apocalypseDragonGroundReduction(headName)
			end
		end
	end
	combat.previewFameByPlayer=combat.previewFameByPlayer or {}
	local previous=tonumber(combat.previewFameByPlayer[playerIndex]) or 0
	if total~=previous then
		details.fameGain=(details.fameGain or 0)+(total-previous)
		if details.fameGain<0 then details.fameGain=0 end
		combat.previewFameByPlayer[playerIndex]=total
	end
	return true
end

function apocalypseDragonBeginGroundCombat(playerIndex)
	if apocalypseDragonScenario()~=true or gStates.apocalypseDragonLairRevealed~=true or gStates.apocalypseDragonDefeated==true then return false end
	if gStates.apocalypseDragonGroundCombat~=nil then return apocalypseDragonGroundCombatForPlayer(playerIndex) end
	local details=turnOrder[playerIndex]
	if details==nil or details.mage==gStates.positionMageKnight[5] then return false end
	gStates.apocalypseDragonLairAttacked=true --from the first lair attack onward the Dragon takes no more automated turns
	local combat=apocalypseDragonNewGroundCombat(false)
	combat.playerIndex=playerIndex
	combat.mage=details.mage
	combat.players[playerIndex]=true
	if gStates.apocalypseDragonAssaultFortifiedInitiator==true then combat.fortifiedPlayers[playerIndex]=true end
	gStates.apocalypseDragonGroundCombat=combat
	gStates.monsterPerks=gStates.monsterPerks or {}
	--Control is always the first/left-most Dragon head; coloured heads follow it.
	apocalypseDragonGroundPrepareControl(combat,playerIndex,1,true)
	local slot=2
	for _,headName in ipairs(apocalypseDragonColoredHeads) do
		if apocalypseDragonGroundPrepareColoredHead(combat,headName,playerIndex)==true then
			local headData=apocalypseDragonHeadData(headName)
			local token=headData~=nil and getObjectFromGUID(headData.tokenGUID) or nil
			local target=apocalypseDragonGroundTokenPosition(playerIndex,slot)
			if token~=nil and target~=nil then token.setPositionSmooth(target,false,true) end
			slot=slot+1
		end
	end
	apocalypseDragonRefreshGroundAttackSuppression()
	apocalypseDragonRefreshGroundFameGain(playerIndex)
	combatCameraFocus(playerIndex)
	mainUIUpdate("Apocalypse Dragon Ground Combat")
	broadcastToAll(tostring(details.mage).." attacks the landed Apocalypse Dragon. Each coloured head is a separate enemy; use the +/- control on a face-up head to record how many levels your attack reduced. Flip a coloured head face down if you did not reduce it. The Control head cannot be attacked.",positionToColor(playerIndex))
	return true
end

function apocalypseDragonCoopAdjacentPlayers(playerIndex)
	local result={}
	if gStates==nil or gStates.apocalypseDragonLair==nil then return result end
	for candidate,details in ipairs(turnOrder or {}) do
		if candidate~=playerIndex and details~=nil and details.mage~=gStates.positionMageKnight[5] and playerDropoutInactive(candidate)==false then
			local pos=fracturedLandsTeleportSourcePosition~=nil and fracturedLandsTeleportSourcePosition(candidate) or nil
			if pos==nil then local avatar=coopAssaultAvatarObject(candidate) if avatar~=nil then pos=avatar.getPosition() end end
			local adjacent=false
			if pos~=nil then
				for _,hex in ipairs(gStates.apocalypseDragonLair.hexes or {}) do
					local p=hex.position
					if p~=nil then
						local d=((pos[1]-p[1])^2)+((pos[3]-p[3])^2)
						if d>4.2 and d<7.4 then adjacent=true break end
					end
				end
			end
			if adjacent==true then result[#result+1]={mage=details.mage,turn=candidate} end
		end
	end
	return result
end

function apocalypseDragonAssaultOriginData(approachPosition)
	local origin={avatarLocation="",avatarSharedHex=nil,avatarSwapCity=nil,position=nil}
	if approachPosition~=nil then
		origin.position={approachPosition[1],approachPosition[2],approachPosition[3]}
		local terrain,bearing,_,feature=terrainHexAtPosition(approachPosition)
		if terrain~=nil and bearing~=nil then origin.avatarLocation=feature or "" end
	end
	return origin
end

function apocalypseDragonBeginLairAssault(playerIndex,approachPosition)
	if apocalypseDragonScenario()~=true or gStates.apocalypseDragonLairRevealed~=true or gStates.apocalypseDragonDefeated==true then return false end
	if gStates.coopAssaultPhase~=nil or gStates.apocalypseDragonGroundCombat~=nil then return false end
	local player=turnOrder[playerIndex]
	if player==nil or playerIndex~=gStates.turnNumber or playerDropoutInactive(playerIndex)==true then return false end
	local endHorsemenOnStart=gStates.gameScenario=="Apocalypse is Here" and gStates.apocalypseDragonLairAttacked~=true and apocalypseIsHereEndHorsemen~=nil
	gStates.apocalypseDragonAssaultFortifiedInitiator=gStates.gameScenario=="Apocalypse is Here" and apocalypseIsHereDragonCitySpacePlayer~=nil and apocalypseIsHereDragonCitySpacePlayer(playerIndex)==true
	local liveHeads={}
	for _,headName in ipairs(apocalypseDragonColoredHeads) do
		local level=tonumber(gStates.apocalypseDragonHeadLevels~=nil and gStates.apocalypseDragonHeadLevels[headName] or 0) or 0
		local headData=apocalypseDragonHeadData(headName)
		if level>0 and headData~=nil and getObjectFromGUID(headData.tokenGUID)~=nil then liveHeads[#liveHeads+1]=headData.tokenGUID end
	end
	if #liveHeads<1 then return false end
	local nearby=apocalypseDragonCoopAdjacentPlayers(playerIndex)
	if #liveHeads<2 or #nearby<1 then
		local started=apocalypseDragonBeginGroundCombat(playerIndex)
		if started==true and endHorsemenOnStart==true then apocalypseIsHereEndHorsemen() end
		return started
	end

	gStates.apocalypseDragonAssaultOrigin=apocalypseDragonAssaultOriginData(approachPosition)
	gStates.assaultData={[player.mage]={primary={},secondary={},UIPos={1},joined=true}}
	for _,guid in ipairs(liveHeads) do
		gStates.assaultData[player.mage].primary[#gStates.assaultData[player.mage].primary+1]=guid
		local headName=apocalypseDragonGroundHeadNameForGUID(guid)
		local headData=headName~=nil and apocalypseDragonHeadData(headName) or nil
		if headData~=nil then gStates.monsterPlayLocation[guid]=apocalypseDragonHeadTokenPosition(headData) end
	end
	local count=1
	for _,candidate in ipairs(nearby) do
		count=count+1
		gStates.assaultData[candidate.mage]={primary={},secondary={},UIPos={count},joined=false}
	end
	gStates.coopAssaultUnassigned={primary={},secondary={}}
	gStates.coopAssaultCityGUID=apocalypseDragon.model
	gStates.coopAssaultLocation="apocalypse dragon"
	gStates.coopAssaultType="dragon"
	gStates.coopAssaultInitiator=playerIndex
	player.combatIconHide="Avatar"
	locationAttacked=true
	applyColorBarButtons()
	coopAssaultUIUpdate()
	if endHorsemenOnStart==true then apocalypseIsHereEndHorsemen() end
	return true
end

function apocalypseDragonBeginCoopGroundCombat()
	if gStates==nil or gStates.coopAssaultPhase~="combat" or coopAssaultTargetType()~="dragon" then return false end
	if gStates.apocalypseDragonGroundCombat~=nil then return true end
	local combat=apocalypseDragonNewGroundCombat(true)
	combat.initiator=gStates.coopAssaultInitiator or gStates.turnNumber
	if gStates.apocalypseDragonAssaultFortifiedInitiator==true then combat.fortifiedPlayers[combat.initiator]=true end
	gStates.apocalypseDragonGroundCombat=combat
	gStates.apocalypseDragonLairAttacked=true
	gStates.monsterPerks=gStates.monsterPerks or {}
	for playerIndex,_ in pairs(gStates.coopAssaultParticipants or {}) do combat.players[playerIndex]=true combat.fameByPlayer[playerIndex]=0 end
	for playerIndex,details in ipairs(turnOrder or {}) do
		local assigned=details~=nil and gStates.assaultData~=nil and gStates.assaultData[details.mage] or nil
		if assigned~=nil and assigned.joined==true then
			local assignedCount=0
			for _,army in ipairs({"primary","secondary"}) do
				for _,guid in ipairs(assigned[army] or {}) do
					local headName=apocalypseDragonGroundHeadNameForGUID(guid)
					if headName~=nil and headName~="Control" and apocalypseDragonGroundPrepareColoredHead(combat,headName,playerIndex)==true then assignedCount=assignedCount+1 end
				end
			end
			apocalypseDragonGroundPrepareControl(combat,playerIndex,1,false)
		end
	end
	apocalypseDragonRefreshGroundAttackSuppression()
	for playerIndex,_ in pairs(combat.players or {}) do apocalypseDragonRefreshGroundFameGain(playerIndex) end
	broadcastToAll("The cooperative assault on the Apocalypse Dragon begins. The coloured heads have been divided between the participating Mage Knights; every participant also faces the Control head.",{1,0.75,0.2})
	return true
end

function apocalypseDragonGroundResolveToken(obj)
	local combat=gStates~=nil and gStates.apocalypseDragonGroundCombat or nil
	if combat==nil or obj==nil or combat.processedTokens[obj.guid]==true then return false end
	local active,headName,owner=apocalypseDragonGroundCombatToken(obj.guid)
	if active~=true or headName==nil or owner==nil then return false end
	combat.processedTokens=combat.processedTokens or {}
	combat.processedTokens[obj.guid]=true
	obj.UI.setXmlTable({{}})
	if headName=="Control" then
		local controlData=apocalypseDragonHeadData("Control")
		if controlData~=nil and obj.guid==controlData.tokenGUID then
			local home=apocalypseDragonHeadTokenPosition(controlData)
			obj.setLock(false)
			obj.setRotation({0,180,0})
			if home~=nil then obj.setPositionSmooth(home,false,true) end
		else
			--Do not destroy the clone while the normal end-turn loop still owns this userdata.
			--Move it out of the play area now, then clear the temporary monster registration next frame.
			local cloneGUID=obj.guid
			if combat.controlClones~=nil then combat.controlClones[cloneGUID]=nil end
			obj.setPosition({0,-20,0})
			safeWaitFrames("Scenario",function()
				local clone=getObjectFromGUID(cloneGUID)
				if clone~=nil then clone.destruct() end
				if gStates.monsterPerks~=nil then gStates.monsterPerks[cloneGUID]=nil end
				if gStates.summonStates~=nil then gStates.summonStates[cloneGUID]=nil end
				monsterPugs[cloneGUID]=nil
			end,1)
		end
		return true
	end

	if obj.is_face_down==false and apocalypseDragonGroundTokenInPlayerArea(obj.guid,owner)==true then
		local headLevels=gStates.apocalypseDragonHeadLevels or {}
		local current=tonumber(headLevels[headName]) or 0
		local reduction=math.min(current,apocalypseDragonGroundReduction(headName))
		combat.reductions=combat.reductions or {}
		combat.fameByPlayer=combat.fameByPlayer or {}
		combat.headMarkedToOne=combat.headMarkedToOne or {}
		combat.reductions[headName]=reduction
		combat.fameByPlayer[owner]=(combat.fameByPlayer[owner] or 0)+reduction
		combat.headMarkedToOne[headName]=reduction>=current and current>0
		local headData=apocalypseDragonHeadData(headName)
		local disc=headData~=nil and getObjectFromGUID(headData.guid) or nil
		if disc~=nil then
			for step=0,reduction-1 do
				local target=apocalypseDragonLevelMarkerPosition(disc,current-step)
				if target~=nil then dropShield({target[1],2+(step*0.15),target[3]},false) end
			end
		end
	else
		combat.reductions=combat.reductions or {}
		combat.headMarkedToOne=combat.headMarkedToOne or {}
		combat.reductions[headName]=0
		combat.headMarkedToOne[headName]=false
	end
	local headData=apocalypseDragonHeadData(headName)
	local home=headData~=nil and apocalypseDragonHeadTokenPosition(headData) or nil
	obj.setLock(false)
	obj.setRotation({0,180,0})
	if home~=nil then obj.setPositionSmooth(home,false,true) end
	apocalypseDragonRefreshGroundAttackSuppression()
	return true
end

function apocalypseDragonGroundPlayerFinished(playerIndex)
	local combat=gStates~=nil and gStates.apocalypseDragonGroundCombat or nil
	if combat==nil or combat.coop~=true or combat.players[playerIndex]~=true then return false end
	combat.finishedPlayers[playerIndex]=true
	return true
end

function apocalypseDragonGroundApplyFinalLevels(combat)
	for _,headName in ipairs(apocalypseDragonColoredHeads) do
		local reduction=tonumber(combat.reductions[headName]) or 0
		if reduction>0 then
			local current=tonumber(gStates.apocalypseDragonHeadLevels[headName]) or 0
			apocalypseDragonSetHeadLevel(headName,math.max(0,current-reduction))
		end
	end
	apocalypseDragonSyncControlLevel()
end

function apocalypseDragonGroundTryApplyLevelsBeforeRewards(playerIndex)
	local combat=gStates~=nil and gStates.apocalypseDragonGroundCombat or nil
	if combat==nil or combat.coop==true or combat.playerIndex~=playerIndex or combat.levelsApplied==true then return false end
	for headName,_ in pairs(combat.deployed or {}) do
		local headData=apocalypseDragonHeadData(headName)
		local guid=headData~=nil and headData.tokenGUID or nil
		if guid~=nil and (combat.processedTokens==nil or combat.processedTokens[guid]~=true) then return false end
	end
	combat.levelsApplied=true
	apocalypseDragonGroundApplyFinalLevels(combat)
	againstDragonDefeatCheck()
	mainUIUpdate("Apocalypse Dragon Levels Resolved")
	return true
end

function apocalypseDragonGroundCleanupRuntime(combat)
	for guid,_ in pairs(combat.controlClones or {}) do
		local clone=getObjectFromGUID(guid)
		if clone~=nil then clone.destruct() end
		monsterPugs[guid]=nil
		if gStates.monsterPerks~=nil then gStates.monsterPerks[guid]=nil end
		if gStates.summonStates~=nil then gStates.summonStates[guid]=nil end
	end
	for _,headData in ipairs(apocalypseDragon.heads) do
		if gStates.summonStates~=nil then gStates.summonStates[headData.tokenGUID]=nil end
		if gStates.monsterPerks~=nil and gStates.monsterPerks[headData.tokenGUID]~=nil then
			gStates.monsterPerks[headData.tokenGUID].dragonGround=nil
			gStates.monsterPerks[headData.tokenGUID].dragonGroundLevel=nil
			gStates.monsterPerks[headData.tokenGUID].dragonLevelFame=nil
			gStates.monsterPerks[headData.tokenGUID].dragonControlBonus=nil
		end
		local token=getObjectFromGUID(headData.tokenGUID)
		local home=apocalypseDragonHeadTokenPosition(headData)
		if token~=nil then
			token.UI.setXmlTable({{}})
			token.setLock(false)
			token.setRotation({0,180,0})
			if home~=nil then token.setPositionSmooth(home,false,true) end
		end
		local level=tonumber(gStates.apocalypseDragonHeadLevels~=nil and gStates.apocalypseDragonHeadLevels[headData.name] or 0) or 0
		apocalypseDragonApplyHeadLevel(headData.name,level)
		gStates.monsterPlayLocation[headData.tokenGUID]=nil
		if gStates.attackedMonsters~=nil then gStates.attackedMonsters[headData.tokenGUID]=nil end
	end
end

function apocalypseDragonFinalizeGroundCombat(playerIndex)
	local combat=gStates~=nil and gStates.apocalypseDragonGroundCombat or nil
	if combat==nil or combat.coop==true or combat.playerIndex~=playerIndex or combat.finished==true then return false end
	combat.finished=true
	for headName,_ in pairs(combat.deployed or {}) do
		local headData=apocalypseDragonHeadData(headName)
		local token=headData~=nil and getObjectFromGUID(headData.tokenGUID) or nil
		if token~=nil and combat.processedTokens[token.guid]~=true then apocalypseDragonGroundResolveToken(token) end
	end
	if combat.levelsApplied~=true then
		apocalypseDragonGroundApplyFinalLevels(combat)
		combat.levelsApplied=true
	end
	local fame=tonumber(combat.fameByPlayer[playerIndex]) or 0
	apocalypseDragonGroundCleanupRuntime(combat)
	gStates.apocalypseDragonGroundCombat=nil
	if fame>0 then broadcastToAll(tostring(turnOrder[playerIndex].mage).." reduced the Apocalypse Dragon by "..tostring(fame).." total level(s) and gains "..tostring(fame).." Fame.",positionToColor(playerIndex)) end
	againstDragonDefeatCheck()
	mainUIUpdate("Apocalypse Dragon Ground Combat Complete")
	return true
end

function finalizeCoopDragonCombat()
	local combat=gStates~=nil and gStates.apocalypseDragonGroundCombat or nil
	if combat==nil or combat.coop~=true or combat.finished==true then return false end
	combat.finished=true
	--All reductions should already have been recorded by each participant's normal combat cleanup.
	--If a persistent head token somehow escaped that cleanup, treat it as unreduced and return it home.
	for headName,_ in pairs(combat.deployed or {}) do
		if headName~="Control" then
			local headData=apocalypseDragonHeadData(headName)
			local token=headData~=nil and getObjectFromGUID(headData.tokenGUID) or nil
			if token~=nil and combat.processedTokens[token.guid]~=true then
				combat.reductions[headName]=0
				combat.headMarkedToOne[headName]=false
				local home=apocalypseDragonHeadTokenPosition(headData)
				token.UI.setXmlTable({{}})
				token.setRotation({0,180,0})
				if home~=nil then token.setPositionSmooth(home,false,true) end
			end
		end
	end
	apocalypseDragonGroundApplyFinalLevels(combat)
	combat.levelsApplied=true
	--Dragon Fame was already in each player's fameGain when the co-op reward snapshot was made.
	for playerIndex,fame in pairs(combat.fameByPlayer or {}) do
		if fame>0 and turnOrder[playerIndex]~=nil then broadcastToAll(tostring(turnOrder[playerIndex].mage).." reduced the Apocalypse Dragon by "..tostring(fame).." total level(s) and will gain "..tostring(fame).." Fame in the cooperative reward phase.",positionToColor(playerIndex)) end
	end
	apocalypseDragonGroundCleanupRuntime(combat)
	gStates.apocalypseDragonGroundCombat=nil
	againstDragonDefeatCheck()
	return true
end


--Against the Dragon turn system ------------------------------------------------
--The Apocalypse Dragon is deliberately NOT inserted into turnOrder. It acts between normal turn
--circuits so the rest of the mod can continue to assume that every turnOrder entry is a Mage Knight,
--Dummy/Proxy, or Volkare.
function againstDragonActive()
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

function againstDragonChoicePlayerIndex()
	local chosen=nil
	for index,details in ipairs(turnOrder or {}) do
		local human=details~=nil and (details.seatPos or 99)<=4 and details.mage~=gStates.positionMageKnight[5]
		if human==true and playerDropoutInactive(index)==false then
			if chosen==nil or (details.tactic or 99)<(turnOrder[chosen].tactic or 99) then chosen=index end
		end
	end
	return chosen
end

function againstDragonChoicePlayerLabel(index)
	if index==nil or turnOrder[index]==nil then return "the player with the lowest-numbered Tactic" end
	local color=positionToColor(index)
	local mage=tostring(turnOrder[index].mage or "player")
	if color~=nil and color~="Black" then return color.." ("..mage..")" end
	return mage
end

function againstDragonChoiceAuthorized(player,pending)
	if pending==nil then return false end
	local color=type(player)=="string" and player or (player~=nil and player.color or nil)
	local allowed=pending.playerIndex~=nil and positionToColor(pending.playerIndex) or nil
	if color=="Black" or color==allowed then return true end
	if color~=nil then
		broadcastToAll(againstDragonChoicePlayerLabel(pending.playerIndex).." has the lowest-numbered Tactic and must make this Dragon choice. A player seated Black may also choose.",warningColor)
	end
	return false
end

function againstDragonPlayerIndexForMage(mage)
	for index,details in ipairs(turnOrder or {}) do if details~=nil and details.mage==mage then return index end end
	return nil
end

function againstDragonClearBlackManaMarkers()
	for _,guid in pairs(gStates.apocalypseDragonBlackMana or {}) do
		local token=guid~=nil and getObjectFromGUID(guid) or nil
		if token~=nil then token.destruct() end
	end
	gStates.apocalypseDragonBlackMana={}
	gStates.apocalypseDragonAttackedThisRound={}
end

function againstDragonPlayerMarked(playerIndex)
	local details=turnOrder[playerIndex]
	if details==nil then return true end
	return gStates.apocalypseDragonAttackedThisRound~=nil and gStates.apocalypseDragonAttackedThisRound[details.mage]==true
end

function againstDragonMarkPlayer(playerIndex)
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
			token.setDescription("Apocalypse Dragon attacked "..tostring(details.mage).." this Round")
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
				{tag="HorizontalLayout",attributes={padding="28 28 20 20"},children={{tag="Text",attributes={id="AgainstDragonAttackCompleteText",font="Fonts/MKCardText",fontSize="78",fontStyle="Normal",alignment="MiddleCenter",resizeTextForBestFit="true",resizeTextMaxSize="78",text="COMPLETE\nDRAGON ATTACK"}}}}}}
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

function againstDragonChoiceClearButtons()
	againstDragonTargetChoiceClearButtons()
	againstDragonOffMapChoiceClearButtons()
end

function againstDragonTargetChoiceButton(option,index,xml,splitIndex,splitCount)
	if option==nil or option.key==nil then return nil,xml end
	local terrainGUID,bearing=tostring(option.key):match("^([^|]+)|(.+)$")
	local terrain=terrainGUID~=nil and getObjectFromGUID(terrainGUID) or nil
	if terrain==nil or bearing==nil then return nil,xml end
	local hexXY=angleToXY(terrain,bearing)
	local tilePos=terrain.getPosition()
	local localHex=terrain.positionToLocal({hexXY[1],tilePos[2],hexXY[2]})
	local tileScale=terrain.getScale()
	local scaleX=tileScale.x or tileScale[1] or 2.25
	local scaleZ=tileScale.z or tileScale[3] or 2.25
	local uiX=(localHex.x or localHex[1])*scaleX*110
	local uiY=(localHex.z or localHex[3])*scaleZ*110
	local buttonScale=0.38
	local uiRotation=terrain.getRotation()[2] or 180
	local count=math.max(1,tonumber(splitCount) or 1)
	local slot=math.max(1,tonumber(splitIndex) or 1)
	local height=320/count
	if count>1 then uiY=uiY+(((count+1)/2)-slot)*height*buttonScale end
	local label="Dragon\nDestroy"
	if option.kind=="attack" then label="Attack\n"..tostring(option.mage or "Player") end
	local id=terrain.guid.."DragonTargetChoice"..tostring(index)
	xml=xml or terrain.UI.getXmlTable() or {}
	xml[#xml+1]={tag="Button",attributes={id=id,onClick="global/againstDragonTargetChoiceSelect",onMouseDown="global/buttonClicked",onMouseUp="global/buttonClicked",
		height=height,width=320,color="rgba(0,0,0,0.0)",position=uiX.." "..uiY.." "..(-40),rotation="0 0 "..tostring(uiRotation),scale=buttonScale.." "..buttonScale},
		children={{tag="Image",attributes={id=id.."Image",image="Sliced Button/Button Object Active",type="Sliced"}},
			{tag="HorizontalLayout",attributes={padding="20 20 12 12"},children={{tag="Text",attributes={id=id.."Text",font="Fonts/MKCardText",offsetXY="0 1",fontSize=count>1 and "60" or "72",fontStyle="Normal",alignment="MiddleCenter",resizeTextForBestFit="true",resizeTextMaxSize=count>1 and "60" or "72",text=label}}}}}}
	return terrain,xml
end

function againstDragonShowMapChoice(pending)
	againstDragonChoiceClearButtons()
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

function againstDragonShowOffMapChoice(pending)
	againstDragonChoiceClearButtons()
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
					{tag="HorizontalLayout",attributes={padding="20 20 15 15"},children={{tag="Text",attributes={id=id.."Text",font="Fonts/MKCardText",fontSize="76",fontStyle="Normal",alignment="MiddleCenter",resizeTextForBestFit="true",resizeTextMaxSize="76",text="MARK\n"..tostring(option.mage)}}}}}}
			token.UI.setXmlTable(xml)
		end
	end
	return true
end

function againstDragonMapHexByKey(hexes,key)
	for _,hex in ipairs(hexes or {}) do if apocalypseQuestMapHexKey(hex)==key then return hex end end
	return nil
end

function againstDragonDistanceStarts(hexes,mapObjects)
	local starts={}
	if gStates.apocalypseDragonLairRevealed==true and gStates.apocalypseDragonLair~=nil then
		for _,saved in ipairs(gStates.apocalypseDragonLair.hexes or {}) do
			local hex=apocalypseQuestHexForPosition(hexes,saved.position,mapObjects)
			if hex~=nil then starts[#starts+1]=hex end
		end
	else
		for _,hex in ipairs(hexes or {}) do
			if string.lower(tostring(hex.feature or ""))=="portal" then starts[#starts+1]=hex end
		end
	end
	return starts
end

function againstDragonDistanceChoices(options,hexes,mapObjects)
	local starts=againstDragonDistanceStarts(hexes,mapObjects)
	if #starts<1 then return {} end
	local distances=apocalypseQuestHexDistanceMap(hexes,starts)
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

function againstDragonPlayerHex(hexes,mapObjects,playerIndex)
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
						if cityObj~=nil then return apocalypseQuestHexForPosition(hexes,cityObj.getPosition(),mapObjects) end
					end
				end
			end
		end
	end
	local avatar=currentMageAvatarPosition(playerIndex)
	return avatar~=nil and apocalypseQuestHexForPosition(hexes,avatar,mapObjects) or nil
end

function againstDragonSiteEligible(hex)
	if hex==nil then return false end
	local feature=string.lower(tostring(hex.feature or ""))
	if feature=="monastery" and gStates.monasteryBurned~=nil and gStates.monasteryBurned[hex.terrainGUID]==true then return false end
	return feature=="village" or feature=="monastery" or feature=="keep" or feature=="mage tower" or feature=="oasis" or feature=="camp" or feature=="mine"
end

function againstDragonDestroyCandidates(hexes,mapObjects)
	local candidates={}
	local destroyedBag=getObjectFromGUID(GUID.bag.destroyedSite)
	local siteTokensAvailable=destroyedBag~=nil
	for _,hex in ipairs(hexes or {}) do
		local rampager=nil
		for _,enemy in ipairs(proxyMonstersOnHex(hex,mapObjects)) do
			if gStates.rampagingMonsters~=nil and gStates.rampagingMonsters[enemy.guid]==true then rampager=enemy break end
		end
		if rampager~=nil then
			candidates[#candidates+1]={kind="rampager",key=apocalypseQuestMapHexKey(hex),enemyGUID=rampager.guid}
		elseif siteTokensAvailable==true and againstDragonSiteEligible(hex)==true then
			candidates[#candidates+1]={kind="site",key=apocalypseQuestMapHexKey(hex),feature=hex.feature}
		end
	end
	return candidates,siteTokensAvailable
end

function againstDragonTurnOrdinal(turnNumber)
	local n=tonumber(turnNumber) or 1
	if n==1 then return "1st" end
	if n==2 then return "2nd" end
	if n==3 then return "3rd" end
	if n==4 then return "4th" end
	return tostring(n).."th"
end

function againstDragonActionLabel(action)
	if action=="attack" then return "attack a player" end
	if action=="destroy" then return "destroy a site or Rampaging Enemy" end
	return "take no action"
end

function againstDragonFinalReport(text)
	local prefix=gStates~=nil and gStates.apocalypseDragonTurnReportPrefix or nil
	if prefix~=nil and prefix~="" then return prefix.."\n"..tostring(text or "") end
	return tostring(text or "")
end

function againstDragonSetTurnReport(text,state)
	if gStates==nil then return end
	gStates.apocalypseDragonTurnReport=tostring(text or "")
	if state~=nil then gStates.apocalypseDragonUIState=state end
	if againstDragonMainUIRefresh~=nil then againstDragonMainUIRefresh() end
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

function againstDragonMainUIPanelSpec()
	if gStates==nil or gStates.apocalypseDragonTurnActive~=true then return nil end
	local pending=gStates.apocalypseDragonPendingAttack
	local turnNumber=tonumber(gStates.apocalypseDragonTurn) or 1
	local ordinal=againstDragonTurnOrdinal(turnNumber)
	local mainText="<size=25>Apocalypse Dragon's Turn</size><size=6>\n\n</size><size=18>Round "..tostring(gStates.currentRound or 1).." - Dragon turn "..tostring(dragonTurn).."</size><size=4>\n</size>"
	if pending~=nil then
		if pending.phase=="choose" then
			return {actor="dragon",mainText=mainText,notes=gStates.apocalypseDragonTurnReport or "Resolve the Apocalypse Dragon attack.",onClick="againstDragonProcessUI",label="{en}Resolve Dragon Attack{ru}Разрешите атаку Дракона{zh-tw}處理巨龍攻擊{zh-cn}处理巨龙攻击{ko}드래곤 공격 해결{es}Resolver Ataque del Dragón{fr}Résoudre l'Attaque du Dragon{pt-br}Resolver Ataque do Dragão{de}Drachenangriff abhandeln",interactable=false,responseSpec=againstDragonAttendanceResponseSpec()}
		end
		return {actor="dragon",panelActive=false}
	end
	local state=gStates.apocalypseDragonUIState
	local label="{en}Processing Dragon...{ru}Дракон действует...{zh-tw}巨龍行動處理中...{zh-cn}巨龙行动处理中...{ko}드래곤 처리 중...{es}Procesando Dragón...{fr}Traitement du Dragon...{pt-br}Processando Dragão...{de}Drache wird verarbeitet..."
	local active=false
	if state=="ReadyToProcess" then label="{en}Process Dragon{ru}Ход Дракона{zh-tw}執行巨龍行動{zh-cn}执行巨龙行动{ko}드래곤 진행{es}Procesar Dragón{fr}Traiter le Dragon{pt-br}Processar Dragão{de}Drache aktivieren" active=true
	elseif state=="ReadyToEnd" then label="{en}Dragon Processed{ru}Дракон обработан{zh-tw}巨龍行動結束{zh-cn}巨龙行动结束{ko}드래곤 처리 완료{es}Dragón Procesado{fr}Dragon traité{pt-br}Dragão Processado{de}Drache verarbeitet" active=true
	elseif state=="WaitingChoice" then label="{en}Pick Target{ru}Выберите цель{zh-tw}選擇目標{zh-cn}选择目标{ko}대상 선택{es}Elige Objetivo{fr}Choisir la Cible{pt-br}Escolha o Alvo{de}Ziel wählen"
	elseif state=="WaitingCombat" then label="{en}Combat Resolved{ru}Бой завершён{zh-tw}戰鬥已解決{zh-cn}战斗已解决{ko}전투 해결 완료{es}Combate resuelto{fr}Combat résolu{pt-br}Combate resolvido{de}Kampf beendet" active=true end
	return {actor="dragon",mainText=mainText,notes=gStates.apocalypseDragonTurnReport or ("The Apocalypse Dragon is preparing its "..ordinal.." turn."),onClick="againstDragonProcessUI",label=label,interactable=active}
end

function againstDragonMainUIRefresh()
	local spec=againstDragonMainUIPanelSpec()
	if spec==nil then return false end
	return automatedMainPanelApply(spec)
end

function againstDragonProcessUI(player,mouseButton,id)
	if mouseButton~="-1" or gStates==nil or gStates.apocalypseDragonTurnActive~=true then return end
	local state=gStates.apocalypseDragonUIState
	if state=="ReadyToEnd" then
		againstDragonFinishTurn()
		return
	end
	if furyDragonActive~=nil and furyDragonActive()==true then
		furyDragonProcessTurn()
		return
	end
	if state~="ReadyToProcess" then return end
	local action=gStates.apocalypseDragonTurnAction
	gStates.apocalypseDragonTurnReportPrefix=nil
	if action=="attack" then
		againstDragonSetTurnReport("The Apocalypse Dragon is determining which player to attack.","Processing")
		againstDragonBeginAttack()
	elseif action=="destroy" then
		againstDragonSetTurnReport("The Apocalypse Dragon is determining what it will destroy.","Processing")
		againstDragonBeginDestroy()
	else
		local ordinal=againstDragonTurnOrdinal(gStates.apocalypseDragonTurn)
		againstDragonSetTurnReport("The Apocalypse Dragon took no action on its "..ordinal.." turn.","Processing")
		safeWaitFrames("Scenario",function() againstDragonCompleteTurn() end,1)
	end
end

function againstDragonResolveDestroyOption(option)
	local hexes,mapObjects=apocalypseQuestMapHexes()
	local hex=option~=nil and againstDragonMapHexByKey(hexes,option.key) or nil
	if hex==nil then
		broadcastToAll("The Apocalypse Dragon's selected destruction target could no longer be found.",warningColor)
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
			broadcastToAll("The Apocalypse Dragon's Rampaging Enemy target was no longer present.",warningColor)
			againstDragonSetTurnReport(againstDragonFinalReport("The selected Rampaging Enemy was no longer present."),"Processing")
		end
		safeWaitFrames("Scenario",function() againstDragonCompleteTurn() end,3)
		return true
	end

	local bag=getObjectFromGUID(GUID.bag.destroyedSite)
	if bag==nil then
		broadcastToAll("The Destroyed Site token bag could not be found. The Apocalypse Dragon cannot destroy this site.",warningColor)
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
	local hexes,mapObjects=apocalypseQuestMapHexes()
	local candidates,siteTokensAvailable=againstDragonDestroyCandidates(hexes,mapObjects)
	if #candidates<1 then
		local result
		if siteTokensAvailable~=true then
			result="The Destroyed Site token bag was unavailable and there were no Rampaging Enemies to destroy."
			broadcastToAll("The Destroyed Site token bag could not be found and there are no Rampaging Enemies on the map. The Apocalypse Dragon destroys nothing.",warningColor)
		else
			result="The Dragon had no legal site or Rampaging Enemy to destroy."
		end
		againstDragonSetTurnReport(againstDragonFinalReport(result),"Processing")
		safeWaitFrames("Scenario",function() againstDragonCompleteTurn() end,1)
		return true
	end
	local tied,distance=againstDragonDistanceChoices(candidates,hexes,mapObjects)
	if #tied<1 then
		broadcastToAll("The Apocalypse Dragon could not measure a revealed-space route to a destruction target.",warningColor)
		againstDragonSetTurnReport(againstDragonFinalReport("The Dragon could not measure a route to a legal destruction target."),"Processing")
		safeWaitFrames("Scenario",function() againstDragonCompleteTurn() end,1)
		return true
	end
	if #tied==1 then return againstDragonResolveDestroyOption(tied[1]) end

	local chooser=againstDragonChoicePlayerIndex()
	local pending={type="destroy",playerIndex=chooser,options=tied,distance=distance}
	gStates.apocalypseDragonPendingChoice=pending
	againstDragonShowMapChoice(pending)
	local direction=gStates.apocalypseDragonLairRevealed==true and "closest to the Lair" or "furthest from the Portal"
	local chooserText=againstDragonChoicePlayerLabel(chooser)
	againstDragonSetTurnReport(againstDragonFinalReport("The Dragon has "..tostring(#tied).." tied destruction targets "..direction..".\n"..chooserText.." must pick one of the highlighted targets."),"WaitingChoice")
	return true
end

function againstDragonGainFame(playerIndex,amount)
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

function againstDragonAttendanceAuthorized(player,pending)
	if pending==nil or pending.playerIndex==nil then return false end
	local details=turnOrder[pending.playerIndex]
	if details==nil then return false end
	local color=type(player)=="string" and player or (player~=nil and player.color or nil)
	local allowed=positionToColor(pending.playerIndex)
	if color=="Black" or color==allowed then return true end
	if color~=nil then broadcastToColor(tostring(details.mage).." (or a player seated Black) must choose how to attend this Dragon attack.",color,warningColor) end
	return false
end

function againstDragonFullAttendAllowed(playerIndex)
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

function againstDragonAirborneTokenPosition(playerIndex,slot)
	local details=turnOrder[playerIndex]
	if details==nil then return nil end
	--Match the landed Dragon spacing offset and keep the aerial fight clear of the left-side combat controls.
	return {(details.seatPos*40)-98.75+((slot-1)*2.5),1.5,-39.25}
end

function againstDragonAirborneMonsterData(headName,round)
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

function againstDragonDeployAirborneHeads(playerIndex)
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

function againstDragonAirborneProtectionLocation(playerIndex)
	local avatar=coopAssaultAvatarObject~=nil and coopAssaultAvatarObject(playerIndex) or nil
	if avatar==nil then return nil end
	local terrain,bearing,_,feature=terrainHexAtPosition(avatar.getPosition())
	if terrain==nil or bearing==nil or feature==nil then return nil end
	return {terrainGUID=terrain.guid,bearing=bearing,feature=feature}
end

function againstDragonAirborneProtectionReminder(location)
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

function againstDragonCaptureAirborneSuppression()
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
		broadcastToAll("A Dragon head was suppressed by the site, but no Destroyed Site token was available.",warningColor)
		return false
	end
	local token=takeDestroyedSiteToken(terrain,location.bearing)
	if token==nil then return false end
	pending.destroyedSiteTokenGUID=token.guid
	destroySite(token,terrain,location.bearing)
	local label=proxyFeatureDisplayName~=nil and proxyFeatureDisplayName(location.feature) or tostring(location.feature)
	broadcastToAll("The Apocalypse Dragon destroys the "..tostring(label).." after its protection was used.",{1,0.75,0.2})
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
		safeWaitFrames("Scenario",function() againstDragonFinishTurn(true) end,1)
	else
		againstDragonCompleteTurn()
	end
	return true
end

function againstDragonAttendPartial(player,mouseButton,id)
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
		if color~=nil then broadcastToColor("Fully Defend is unavailable because this Mage Knight's Round Order token is already face down.",color,warningColor) end
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

function againstDragonBeginManualAttack(playerIndex)
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

function againstDragonResolveOffMapPlayer(playerIndex)
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
	local hexes,mapObjects=apocalypseQuestMapHexes()
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
					attackable[#attackable+1]={kind="attack",mage=details.mage,playerIndex=index,key=apocalypseQuestMapHexKey(hex)}
				else
					broadcastToAll("Could not locate "..tostring(details.mage).."'s map space for the Apocalypse Dragon attack.",warningColor)
				end
			end
		end
	end

	if #attackable<1 then
		if #offMap==1 then return againstDragonResolveOffMapPlayer(offMap[1].playerIndex) end
		if #offMap>1 then
			local chooser=againstDragonChoicePlayerIndex()
			local pending={type="offMap",playerIndex=chooser,options=offMap}
			gStates.apocalypseDragonPendingChoice=pending
			againstDragonShowOffMapChoice(pending)
			local chooserText=againstDragonChoicePlayerLabel(chooser)
			againstDragonSetTurnReport("More than one eligible player is on the Portal.\n"..chooserText.." must choose who receives the Black mana marker; the Dragon will then destroy a target instead.","WaitingChoice")
			return true
		end
		againstDragonSetTurnReport("The Dragon had no eligible player left to attack this Round.","Processing")
		safeWaitFrames("Scenario",function() againstDragonCompleteTurn() end,1)
		return true
	end

	local tied,distance=againstDragonDistanceChoices(attackable,hexes,mapObjects)
	if #tied<1 then
		broadcastToAll("The Apocalypse Dragon could not measure a revealed-space route to an eligible player.",warningColor)
		againstDragonSetTurnReport("The Dragon could not measure a route to an eligible player.","Processing")
		safeWaitFrames("Scenario",function() againstDragonCompleteTurn() end,1)
		return true
	end
	if #tied==1 then return againstDragonBeginManualAttack(tied[1].playerIndex) end

	local chooser=againstDragonChoicePlayerIndex()
	local pending={type="attack",playerIndex=chooser,options=tied,distance=distance}
	gStates.apocalypseDragonPendingChoice=pending
	againstDragonShowMapChoice(pending)
	local direction=gStates.apocalypseDragonLairRevealed==true and "closest to the Lair" or "furthest from the Portal"
	local chooserText=againstDragonChoicePlayerLabel(chooser)
	againstDragonSetTurnReport("The Dragon has "..tostring(#tied).." tied players "..direction..".\n"..chooserText.." must pick the attacked player using the highlighted buttons.","WaitingChoice")
	return true
end

function againstDragonTargetChoiceSelect(player,mouseButton,id)
	if mouseButton~="-1" then return end
	local pending=gStates.apocalypseDragonPendingChoice
	if pending==nil or (pending.type~="destroy" and pending.type~="attack") then return end
	if againstDragonChoiceAuthorized(player,pending)~=true then return end
	local index=tonumber(tostring(id or ""):match("DragonTargetChoice(%d+)$"))
	local option=index~=nil and pending.options[index] or nil
	if option==nil then return end
	gStates.apocalypseDragonPendingChoice=nil
	againstDragonChoiceClearButtons()
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
	if againstDragonChoiceAuthorized(player,pending)~=true then return end
	local index=tonumber(tostring(id or ""):match("DragonOffMapChoice(%d+)$"))
	local option=index~=nil and pending.options[index] or nil
	if option==nil then return end
	gStates.apocalypseDragonPendingChoice=nil
	againstDragonChoiceClearButtons()
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

function againstDragonTurnAction(turnNumber)
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
	againstDragonChoiceClearButtons()
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
	local ordinal=againstDragonTurnOrdinal(dragonTurn)
	gStates.apocalypseDragonTurnAction=action
	gStates.apocalypseDragonUIState="ReadyToProcess"
	gStates.apocalypseDragonTurnReportPrefix=nil
	gStates.apocalypseDragonTurnReport="The Apocalypse Dragon's "..ordinal.." turn will "..againstDragonActionLabel(action)..".\nClick Process Dragon to continue."
	againstDragonMainUIRefresh()
	mainUIUpdate("Dragon Turn Ready")
	return true
end

function againstDragonCompleteTurn()
	if againstDragonActive()~=true then return false end
	againstDragonChoiceClearButtons()
	againstDragonAttackControlUI(false)
	automatedAttackResponseUI(nil)
	gStates.apocalypseDragonPendingChoice=nil
	gStates.apocalypseDragonPendingAttack=nil
	gStates.apocalypseDragonTurnAction=nil
	gStates.apocalypseDragonUIState="ReadyToEnd"
	if gStates.apocalypseDragonTurnReport==nil or gStates.apocalypseDragonTurnReport=="" then
		gStates.apocalypseDragonTurnReport="The Apocalypse Dragon finished its turn."
	end
	againstDragonMainUIRefresh()
	mainUIUpdate("Dragon Processed")
	return true
end

function againstDragonFinishTurn(force)
	if gStates==nil or gStates.apocalypseDragonTurnActive~=true then return false end
	if force~=true and gStates.apocalypseDragonUIState~="ReadyToEnd" then return false end
	againstDragonChoiceClearButtons()
	againstDragonAttackControlUI(false)
	UI.setAttribute("DummyTurn","active","false")
	automatedAttackResponseUI(nil)
	gStates.apocalypseDragonTurnActive=false
	local resume=gStates.apocalypseDragonResumeTurn
	local fullAttendPlayer=gStates.apocalypseDragonFullAttendPlayer
	gStates.apocalypseDragonResumeTurn=nil
	gStates.apocalypseDragonPendingChoice=nil
	gStates.apocalypseDragonPendingAttack=nil
	gStates.apocalypseDragonFullAttendPlayer=nil
	gStates.apocalypseDragonUIState=nil
	gStates.apocalypseDragonTurnAction=nil
	gStates.apocalypseDragonTurnReport=nil
	gStates.apocalypseDragonTurnReportPrefix=nil
	if resume~=nil and mergedTurnCommit~=nil then
		local resumeTurn=resume.turnNumber
		if fullAttendPlayer~=nil and resumeTurn==fullAttendPlayer and gStates.skipTurn[fullAttendPlayer]==true then
			gStates.skipTurn[fullAttendPlayer]=nil
			local skipped=turnOrder[fullAttendPlayer]
			local token=skipped~=nil and getObjectFromGUID(skipped.turnOrderTokenGUID) or nil
			if token~=nil and token.is_face_down==true then token.flip() end
			if skipped~=nil then broadcastToAll(tostring(skipped.mage).." skips their normal turn because they fully attended the Dragon attack.",positionToColor(fullAttendPlayer)) end
			for _=1,#turnOrder do
				resumeTurn=resumeTurn+1
				if resumeTurn>#turnOrder then resumeTurn=1 end
				if playerDropoutInactive(resumeTurn)==false then
					if gStates.skipTurn[resumeTurn]==true then
						gStates.skipTurn[resumeTurn]=nil
						local skippedDetails=turnOrder[resumeTurn]
						local skippedToken=skippedDetails~=nil and getObjectFromGUID(skippedDetails.turnOrderTokenGUID) or nil
						if skippedToken~=nil and skippedToken.is_face_down==true then skippedToken.flip() end
						if skippedDetails~=nil then broadcastToAll(tostring(skippedDetails.mage).." skips their turn. They already played out of order.",positionToColor(resumeTurn)) end
					else
						break
					end
				end
			end
		end
		mergedTurnCommit(resumeTurn,resume.newOutOfTurn,resume.sameTurn)
	else
		mainUIUpdate("Dragon Turn Complete")
	end
	return true
end


--Fury of the Apocalypse Dragon turn system --------------------------------------
--Fury uses the same interstitial turn shell as Against the Dragon, but its physical state alternates
--between Landed and In Flight. A stored flight target means the Dragon is in flight; nil means landed.
--This is intentionally new-game state only: Fury setup initializes the current Lair hex and no
--old-save recovery is attempted.
function furyDragonActive()
	return gStates~=nil and gStates.gameScenario=="Fury of the Apocalypse Dragon"
end

function furyDragonPositionRoundOrderToken()
	if furyDragonActive()~=true then return false end
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
	if furyDragonActive()~=true then return false end
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
	againstDragonChoiceClearButtons()
	againstDragonAttackControlUI(false)
	furyDragonPositionRoundOrderToken()
	return true
end

function furyDragonBeginTurn(nextTurnNumber,newOutOfTurn,sameTurn)
	if furyDragonActive()~=true or gStates.tacticShown==true or gStates.tacticRemove==true then return false end
	if gStates.endRoundCalled==true or gStates.gameOver==true or gStates.apocalypseDragonDefeated==true then return false end
	if gStates.apocalypseDragonTurnActive==true then return true end
	gStates.apocalypseDragonTurnActive=true
	gStates.apocalypseDragonResumeTurn={turnNumber=nextTurnNumber,newOutOfTurn=newOutOfTurn==true,sameTurn=sameTurn==true}
	gStates.apocalypseDragonTurn=(gStates.apocalypseDragonTurn or 0)+1
	local dragonTurn=gStates.apocalypseDragonTurn
	local ordinal=againstDragonTurnOrdinal(dragonTurn)
	local state=gStates.furyDragonFlightTarget~=nil and "in flight" or "landed"
	gStates.apocalypseDragonTurnAction="fury"
	gStates.apocalypseDragonUIState="ReadyToProcess"
	gStates.apocalypseDragonTurnReportPrefix=nil
	gStates.apocalypseDragonTurnReport="The Apocalypse Dragon is "..state.." for its "..ordinal.." turn.\nClick Process Dragon to continue."
	againstDragonMainUIRefresh()
	mainUIUpdate("Fury Dragon Turn Ready")
	return true
end

function furyDragonCompleteTurn(text)
	if furyDragonActive()~=true then return false end
	gStates.apocalypseDragonUIState="ReadyToEnd"
	gStates.apocalypseDragonTurnReport=text or "The Apocalypse Dragon finished its turn."
	againstDragonMainUIRefresh()
	mainUIUpdate("Dragon Processed")
	return true
end

function furyDragonFeatureMatches(feature,wanted)
	local name=string.lower(tostring(feature or ""))
	if wanted=="city" then return name:sub(1,4)=="city" end
	return name==wanted
end

function furyDragonHexHasLiveRampager(hex,mapObjects)
	if hex==nil then return false end
	for _,enemy in ipairs(proxyMonstersOnHex(hex,mapObjects)) do
		if gStates.rampagingMonsters~=nil and gStates.rampagingMonsters[enemy.guid]==true then return true end
	end
	return false
end

function furyDragonTargetCategory(hex,color,mapObjects)
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

function furyDragonMapTilesAdjacent(a,b)
	if a==nil or b==nil then return false end
	if a.guid==b.guid then return true end
	local ap=a.getPosition()
	local bp=b.getPosition()
	local d=((ap[1]-bp[1])^2)+((ap[3]-bp[3])^2)
	return d>36 and d<45
end

function furyDragonCurrentHex(hexes)
	if gStates.furyDragonCurrentHexKey==nil then return nil end
	return againstDragonMapHexByKey(hexes,gStates.furyDragonCurrentHexKey)
end

function furyDragonLairTarget(hexes)
	local lair=gStates.apocalypseDragonLair
	if lair==nil then return nil end
	local key=lair.cityHexKey
	if key==nil and lair.tileGUID~=nil and lair.hexes~=nil and lair.hexes[1]~=nil then key=lair.tileGUID.."|"..tostring(lair.hexes[1].bearing) end
	local hex=key~=nil and againstDragonMapHexByKey(hexes,key) or nil
	if hex==nil then return nil end
	return {key=key,terrainGUID=hex.terrainGUID,bearing=hex.bearing,feature="",category="lair",isLair=true}
end

function furyDragonLowestHead()
	local chosen=nil
	local chosenLevel=nil
	for _,headName in ipairs(apocalypseDragon.furyLowestHeadOrder or {}) do
		local level=tonumber(gStates.apocalypseDragonHeadLevels~=nil and gStates.apocalypseDragonHeadLevels[headName] or 0) or 0
		if chosenLevel==nil or level<chosenLevel then chosen=headName chosenLevel=level end
	end
	return chosen,chosenLevel
end

function furyDragonTargetHead(target)
	if target==nil then return nil end
	local fixed=apocalypseDragon.furyCategoryHead[target.category]
	if fixed~=nil then return fixed end
	if target.category=="mana" or target.category=="lair" then return furyDragonLowestHead() end
	return nil
end

function furyDragonTargetWouldOverflow(target)
	local head=furyDragonTargetHead(target)
	if head==nil then return false end
	local level=tonumber(gStates.apocalypseDragonHeadLevels~=nil and gStates.apocalypseDragonHeadLevels[head] or 0) or 0
	return level>=12
end

function furyDragonChooseTarget(color,hexes,mapObjects)
	--The mod's Destroyed Site supply is an Infinite Bag, so Fury intentionally omits the printed
	--"all 16 Destroyed Site tokens used" redirect and only applies the no-target / level-12 redirects.
	local current=furyDragonCurrentHex(hexes)
	local lair=furyDragonLairTarget(hexes)
	if current==nil then return lair end
	local allowed={}
	for _,hex in ipairs(hexes or {}) do
		if hex.terrain~=nil and current.terrain~=nil and furyDragonMapTilesAdjacent(current.terrain,hex.terrain)==true then allowed[#allowed+1]=hex end
	end
	local distances=apocalypseQuestHexDistanceMap(allowed,{current})
	local currentKey=apocalypseQuestMapHexKey(current)
	local bestDistance=nil
	local bestPriority=nil
	local candidates={}
	for _,hex in ipairs(allowed) do
		local key=apocalypseQuestMapHexKey(hex)
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

function furyDragonCityModelGUID(feature)
	local color=string.lower(tostring(feature or "")):match("^city%s+(%a+)")
	return color~=nil and cityModel[color] or nil
end

function furyDragonCityCard(feature)
	local cityGUID=furyDragonCityModelGUID(feature)
	local cardGUID=cityGUID~=nil and gStates.cityCard~=nil and gStates.cityCard[cityGUID] or nil
	return cardGUID~=nil and getObjectFromGUID(cardGUID) or nil
end

function furyDragonTargetPosition(target,hexes,forDragon)
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

function furyDragonManaColor(die)
	if die==nil then return nil end
	local value=string.lower(tostring(die.getRotationValue() or ""))
	return value:match("^(%a+)")
end

function furyDragonTargetLabel(target)
	if target==nil then return "the Lair" end
	if target.isLair==true then return "the Lair" end
	local label=proxyFeatureDisplayName~=nil and proxyFeatureDisplayName(target.feature) or tostring(target.feature or "space")
	return tostring(label)
end

function furyDragonMoveMarkerOffMap()
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

function furyDragonBeginLandedTurn()
	if furyDragonActive()~=true then return false end
	gStates.apocalypseDragonUIState="Processing"
	gStates.apocalypseDragonTurnReport="The landed Apocalypse Dragon is rolling its mana die."
	againstDragonMainUIRefresh()
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
			local hexes,mapObjects=apocalypseQuestMapHexes()
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

function furyDragonPlayersOnTarget(target,hexes,mapObjects)
	local players={}
	for playerIndex,details in ipairs(turnOrder or {}) do
		if details~=nil and details.mage~=gStates.positionMageKnight[5] and playerDropoutInactive(playerIndex)==false then
			local onTarget=false
			if furyDragonCityModelGUID(target.feature)~=nil and details.avatarLocation==target.feature then
				onTarget=true
			else
				local playerHex=againstDragonPlayerHex(hexes,mapObjects,playerIndex)
				onTarget=playerHex~=nil and apocalypseQuestMapHexKey(playerHex)==target.key
			end
			if onTarget==true then players[#players+1]=playerIndex end
		end
	end
	return players
end

function furyDragonDiscardHexEnemies(hex,mapObjects)
	for _,enemy in ipairs(proxyMonstersOnHex(hex,mapObjects)) do
		if getObjectFromGUID(enemy.guid)~=nil then proxyDiscardMonster(enemy) end
	end
end

function furyDragonDestroyHex(hex,mapObjects,removeEnemies)
	if hex==nil then return false end
	if removeEnemies==true then furyDragonDiscardHexEnemies(hex,mapObjects) end
	local bag=getObjectFromGUID(GUID.bag.destroyedSite)
	if bag==nil then
		broadcastToAll("The Destroyed Site bag is missing; Fury could not mark "..furyDragonTargetLabel({feature=hex.feature}).." as destroyed.",warningColor)
		return false
	end
	local token=takeDestroyedSiteToken(hex.terrain,hex.bearing)
	if token==nil then return false end
	return destroySite(token,hex.terrain,hex.bearing)
end

function furyDragonRemoveCityDefender(feature)
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

function furyDragonIncreaseHead(headName)
	if headName==nil then return false end
	local current=tonumber(gStates.apocalypseDragonHeadLevels~=nil and gStates.apocalypseDragonHeadLevels[headName] or 0) or 0
	if current>=12 then return false end
	return apocalypseDragonSetHeadLevel(headName,current+1)
end

function furyDragonResolveArrivalEffect(target,hex,mapObjects)
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

function furyDragonBeginInFlightTurn()
	if furyDragonActive()~=true then return false end
	local target=gStates.furyDragonFlightTarget
	if target==nil then return furyDragonBeginLandedTurn() end
	gStates.apocalypseDragonUIState="Processing"
	gStates.apocalypseDragonTurnReport="The Apocalypse Dragon is flying to "..furyDragonTargetLabel(target).."."
	againstDragonMainUIRefresh()
	local hexes,mapObjects=apocalypseQuestMapHexes()
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

	marker.unlock()
	marker.setRotation({0,180,0})
	marker.setPositionSmooth(destination,false)
	local markerGUID=marker.guid
	mapTokenAfterSettled(markerGUID,function(landed)
		if landed==nil then
			furyDragonCompleteTurn("The Apocalypse Dragon marker disappeared while landing.")
			return
		end
		gStates.furyDragonCurrentHexKey=target.key
		gStates.furyDragonFlightTarget=nil
		local currentHexes,currentMapObjects=apocalypseQuestMapHexes()
		local currentHex=againstDragonMapHexByKey(currentHexes,target.key)
		if currentHex==nil then
			furyDragonCompleteTurn("The Apocalypse Dragon landed, but the destination space could no longer be resolved.")
			return
		end
		local players=furyDragonPlayersOnTarget(target,currentHexes,currentMapObjects)
		if #players>0 then
			local names={}
			for _,playerIndex in ipairs(players) do names[#names+1]=tostring(turnOrder[playerIndex].mage) end
			if mapTokenScheduleObject~=nil then mapTokenScheduleObject(markerGUID) end
			mapTokenRelockWhenSettled(markerGUID,true)
			gStates.furyDragonAwaitingCombat={players=players,target=target}
			gStates.apocalypseDragonUIState="WaitingCombat"
			gStates.apocalypseDragonTurnReport="The Apocalypse Dragon attacks "..table.concat(names,", ")..". Resolve combat against the landed Dragon. When combat is finished, click Combat Resolved; the Dragon will immediately take its required landed turn."
			againstDragonMainUIRefresh()
			mainUIUpdate("Fury Dragon Combat")
			return
		end
		local result=furyDragonResolveArrivalEffect(target,currentHex,currentMapObjects)
		if mapTokenScheduleObject~=nil then mapTokenScheduleObject(markerGUID) end
		mapTokenRelockWhenSettled(markerGUID,true)
		furyDragonCompleteTurn(result)
	end)
	return true
end

function furyDragonProcessTurn()
	if furyDragonActive()~=true or gStates.apocalypseDragonTurnActive~=true then return false end
	if gStates.apocalypseDragonUIState=="WaitingCombat" then
		gStates.furyDragonAwaitingCombat=nil
		return furyDragonBeginLandedTurn()
	end
	if gStates.apocalypseDragonUIState~="ReadyToProcess" then return false end
	if gStates.furyDragonFlightTarget~=nil then return furyDragonBeginInFlightTurn() end
	return furyDragonBeginLandedTurn()
end

function positionApocalypseDragonHeads()
	if apocalypseDragonScenario()~=true then return false end
	local moved=false
	for _,headData in ipairs(apocalypseDragon.heads) do
		local head=getObjectFromGUID(headData.guid)
		if head~=nil then
			local pos=head.getPosition()
			if math.abs(pos[1]-headData.position[1])>0.05 or math.abs(pos[3]-headData.position[3])>0.05 then
				head.setPositionSmooth(headData.position)
				moved=true
			end
			head.lock()
			if apocalypseDragonPositionHeadToken(headData)==true then moved=true end
		end
	end
	return moved
end

cityCardExploreOffsets={{-1.2, 1.09, 6.23},{4.8, 1.09, 4.15},{-6, 1.09, 2.08},{6, 1.09, -2.08},{-4.8, 1.09, -4.15},{1.2, 1.09, -6.23},
	{-2.4, 1.09, 12.46},{3.6, 1.09, 10.24},{9.6, 1.09, 8.23},{10.82, 1.09, 2.12},{12, 1.09, -4.16},{7.2, 1.09, -8.33},
	{2.4, 1.09, -12.46},{-3.6, 1.09, -10.24},{-9.6, 1.09, -8.3},{-10.82, 1.09, -2.12},{-12, 1.09, 4.16},{-7.2, 1.09, 8.33},
	{-3.6, 1.09, 18.69},{-8.4, 1.09, 14.54},{-13.2, 1.09, 10.39},{-18, 1.09, 6.24},
	{18, 1.09, -6.24},{13.2, 1.09, -10.39},{8.4, 1.09, -14.54},{3.6, 1.09, -18.69}}

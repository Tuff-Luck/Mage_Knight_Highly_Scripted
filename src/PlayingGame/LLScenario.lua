-- The Lost Legion: Volkare's Camp, pursuits, and Quest scenario rules.
local volkareCampMapPositionForPlayer, volkareCampHexInfoAtPosition, volkarePursuitHexUsed, volkarePursuitDropShield

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
	for _,obj in pairs(zone.getObjects()) do if isShieldObject(obj) and shieldOwner(obj)==player.mage then count=count+1 end end
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
	broadcastToAll(joinLang({translateWord[player.mage],"{en} marked a Volkare Pursuit hex.{it} ha contrassegnato un esagono di Inseguimento di Volkare.{ru} отметил гекс преследования Волкара.{zh-tw}标记了一个沃卡里追击格。{zh-cn}标记了一个沃卡里追击格。{ko}: 볼케어 추격 칸을 표시했습니다.{es} marcó un hexágono de Persecución de Volkare.{fr} a marqué un hexagone de Poursuite de Volkare.{pt-br} marcou um hexágono de Perseguição de Volkare.{de} hat ein Feld für die Verfolgung Volkares markiert."}),positionToColor(playerIndex))
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
	getObjectFromGUID(cityScriptZones[cityZone[city.model]].cityCard).setDescription("{en}Raised City - Provides no Interaction{it}Città Rasa al Suolo - Nessuna Interazione{ru}Поднятый город — взаимодействие недоступно{zh-tw}升起的城市－無法互動{zh-cn}升起的城市－无法互动{ko}상승한 도시 - 상호작용 불가{es}Ciudad Elevada - No permite Interacción{fr}Cité Élevée - Aucune Interaction{pt-br}Cidade Elevada - Sem Interação{de}Erhöhte Stadt - Keine Interaktion")
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
		broadcastToAll("{en}WARNING: Volkare is four spaces from the Portal. If he moves within three spaces, the Council of the Void will close it.{it}ATTENZIONE: Volkare è a quattro spazi dal Portale. Se arriva entro tre spazi, il Consiglio del Vuoto lo chiuderà.{ru}ВНИМАНИЕ: Волкар находится в четырёх клетках от Портала. Если он приблизится на три клетки, Совет Пустоты закроет Портал.{zh-tw}警告：沃卡里距離傳送門四格。若他進入三格範圍內，虛空議會將關閉傳送門。{zh-cn}警告：沃卡里距离传送门四格。若他进入三格范围内，虚空议会将关闭传送门。{ko}경고: 볼케어가 포털에서 4칸 떨어져 있습니다. 3칸 이내로 이동하면 공허의 의회가 포털을 닫습니다.{es}ADVERTENCIA: Volkare está a cuatro espacios del Portal. Si se acerca a tres espacios, el Consejo del Vacío lo cerrará.{fr}ATTENTION : Volkare se trouve à quatre cases du Portail. S’il s’approche à trois cases, le Conseil du Vide le fermera.{pt-br}AVISO: Volkare está a quatro espaços do Portal. Se ele chegar a três espaços, o Conselho do Vácuo fechará o Portal.{de}WARNUNG: Volkare ist vier Felder vom Portal entfernt. Kommt er auf drei Felder heran, wird der Rat der Leere das Portal schließen.", {1,0.65,0.15})
	end
	if distance>closeDistance then return false end
	gStates.volkarePortalClosed=true
	gStates.volkarePortalWarningShown=true
	local decals=portalTile.getDecals() or {}
	local marked=false
	for _, decal in pairs(decals) do if decal.name=="Portal Closed" then marked=true break end end
	if marked==false then portalTile.addDecal({name="Portal Closed",url=volkarePortalClosedDecalURL,position={0,0.15,0},rotation={90,180,0},scale={0.88,0.88,1}}) end
	broadcastToAll("{en}The Council of the Void has closed the Portal. From now on it is an ordinary space, and Volkare may be attacked there.{it}Il Consiglio del Vuoto ha chiuso il Portale. Ora è uno spazio normale e vi si può attaccare Volkare.{ru}Совет Пустоты закрыл Портал. Теперь это обычная клетка, и Волкара можно атаковать там.{zh-tw}虛空議會已關閉傳送門。從現在起它視為一般空間，沃卡里可在此被攻擊。{zh-cn}虚空议会已关闭传送门。从现在起它视为一般空间，沃卡里可在此被攻击。{ko}공허의 의회가 포털을 닫았습니다. 이제 일반 칸으로 취급하며 그곳에서 볼케어를 공격할 수 있습니다.{es}El Consejo del Vacío ha cerrado el Portal. A partir de ahora es un espacio normal y Volkare puede ser atacado allí.{fr}Le Conseil du Vide a fermé le Portail. Désormais, il s’agit d’une case ordinaire et Volkare peut y être attaqué.{pt-br}O Conselho do Vácuo fechou o Portal. A partir de agora ele é um espaço comum, e Volkare pode ser atacado ali.{de}Der Rat der Leere hat das Portal geschlossen. Von nun an ist es ein normales Feld, und Volkare kann dort angegriffen werden.", {1,0.45,0.15})
	scenarioEliminatePlayersAtPortal("{en} was caught on the Portal when it closed and is out of the game.{it} si trovava sul Portale alla chiusura ed è fuori dalla partita.{ru} оказался на Портале в момент его закрытия и выбывает из игры.{zh-tw} 在傳送門關閉時仍站在其上，因此退出遊戲。{zh-cn} 在传送门关闭时仍站在其上，因此退出游戏。{ko} 포탈이 닫힐 때 그 위에 있어 게임에서 탈락합니다.{es} estaba en el Portal cuando se cerró y queda fuera de la partida.{fr} se trouvait sur le Portail lors de sa fermeture et est éliminé de la partie.{pt-br} estava no Portal quando ele se fechou e está fora do jogo.{de} befand sich beim Schließen auf dem Portal und scheidet aus dem Spiel aus.")
	applyColorBarButtons()
	addAvatarButtons()
	volkareQuestCheckSkipTurn()
	if activeMageKnightCount()==0 then
		gStates.volkareWon=true
		gStates.blurb="{en}The Portal closed with every Mage Knight trapped upon it.<size=6>\n\n</size>No-one remains to oppose Volkare. You have Lost.{it}Il Portale si è chiuso con tutti i Mage Knight intrappolati sopra.<size=6>\n\n</size>Nessuno può più opporsi a Volkare. Avete perso.{ru}Портал закрылся, когда все Рыцари-Маги находились на нем.<size=6>\n\n</size>Некому противостоять Волкару. Вы проиграли.{zh-tw}傳送門關閉時所有魔法騎士都被困在其上。<size=6>\n\n</size>已無人能阻止沃卡里。你輸了。{zh-cn}传送门关闭时所有魔法骑士都被困在其上。<size=6>\n\n</size>已无人能阻止沃卡里。你输了。{ko}포탈이 닫히며 모든 마법기사가 그 위에 갇혔습니다.<size=6>\n\n</size>볼케어를 막을 자가 없습니다. 패배했습니다.{es}El Portal se cerró con todos los Caballeros Mago atrapados sobre él.<size=6>\n\n</size>Nadie queda para oponerse a Volkare. Has perdido.{fr}Le Portail s'est fermé alors que tous les Chevaliers-Mages s'y trouvaient.<size=6>\n\n</size>Plus personne ne peut s'opposer à Volkare. Vous avez perdu.{pt-br}O Portal se fechou com todos os Cavaleiros Magos presos sobre ele.<size=6>\n\n</size>Ninguém resta para enfrentar Volkare. Você perdeu.{de}Das Portal schloss sich, während alle Mage Knights darauf standen.<size=6>\n\n</size>Niemand kann Volkare noch aufhalten. Ihr habt verloren."
		UI.setAttribute("DummyNotes", "Text", gStates.blurb)
		mainUIUpdate("Volkare portal closure eliminated all players")
	end
	return true
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
	broadcastToAll(joinLang({"{en}At Least {it}Almeno {ru}Как минимум {zh-tw}至少{zh-cn}至少{ko}최소 {es}Al menos {fr}Au moins {pt-br}Pelo menos {de}Zumindest ", tostring(threshold), "{en} of Volkare's Army defeated, he skips his next turn.{it} dell'esercito di Volkare è sconfitto; salta il prossimo turno.{ru} отряда из армии Волкара побеждено, он пропускает следующий ход{zh-tw}个敌人被击败了, 沃里卡跳过了他的回合. {zh-cn}个敌人被击败了, 沃里卡跳过了他的回合. {ko}개의 볼케어 군대 적 토큰을 제거했기에, 볼케어의 차례를 건너뜁니다{es} de los ejércitos de Volkare derrotados, se salta su siguiente turno.{fr} de l'armée de Volkare vaincus, il saute son prochain tour.{pt-br} do exército de Volkare derrotado, ele pulará seu próximo turno.{de} von Volkare's Armee besiegt, überspringt er seinen nächsten Zug."}), {1,1,0.5})
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
	broadcastToAll(joinLang({translateWord[mageName], "{en} needs to withdraw to a neighboring Safe space after fighting Volkare.{it} deve ritirarsi in uno spazio Sicuro adiacente dopo il combattimento con Volkare.{ru} должен отступить на соседнюю безопасную клетку после боя с Волкаром.{zh-tw} 與沃卡里戰鬥後必須撤退到相鄰的安全格。{zh-cn} 与沃卡里战斗后必须撤退到相邻的安全格。{ko} 볼케어와 전투한 뒤 인접한 안전한 칸으로 후퇴해야 합니다.{es} debe retirarse a un espacio seguro vecino después de luchar contra Volkare.{fr} doit se retirer vers un espace sûr adjacent après avoir combattu Volkare.{pt-br} precisa recuar para um espaço Seguro adjacente depois de lutar com Volkare.{de} muss sich nach dem Kampf gegen Volkare auf ein benachbartes sicheres Feld zurückziehen."}), warningColor)
	return true
end

function registerVolkareCampAsCityKeep()
	if gStates.volkareCampAsCity~=true or gStates.volkareCityDefeat==true or gStates.defeatedCities[volkare.terrainHex]~=true then return end
	gStates.volkareCityDefeat=true
	for _, player in pairs(turnOrder) do
		if player.defeatedCities[volkare.terrainHex]=="Lead" then player.keepsBeat=player.keepsBeat+1 break end
	end
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
	broadcastToAll(joinLang({translateWord[turnOrder[playerIndex].mage],"{en} pursues Volkare's fleeing army.{it} insegue l'esercito in fuga di Volkare.{ru} преследует отступающую армию Волкара.{zh-tw}追击沃卡里的溃军。{zh-cn}追击沃卡里的溃军。{ko}: 볼케어의 패주하는 군대를 추격합니다.{es} persigue al ejército en fuga de Volkare.{fr} poursuit l'armée de Volkare en fuite.{pt-br} persegue o exército em fuga de Volkare.{de} verfolgt Volkares fliehende Armee."}),positionToColor(playerIndex))
	addAvatarButtons()
end

-- Volkare automated turn and combat-response runtime.

--Return the legal top-tile exploration position that contains a world hex.
--This deliberately reuses the normal EXPLORE set, so Volkare obeys the same tile-placement rules as players.
local function volkareLegalExploreSpot(pos)
	if pos==nil or gStates.exploreButtons==nil then return end
	local best=nil
	local bestDist=999
	for _, button in pairs(gStates.exploreButtons) do
		local attributes=button.attributes
		if attributes~=nil then
			local x=tonumber(attributes.tilePosX)
			local z=tonumber(attributes.tilePosZ)
			if x~=nil and z~=nil then
				local dist=math.sqrt(((pos[1]-x)^2)+((pos[3]-z)^2))
				if dist<3.1 and dist<bestDist then best={x, 2.0, z} bestDist=dist end
			end
		end
	end
	return best
end

local function normalizeVolkareBearing(bearing)
	bearing=bearing%360
	if bearing<0 then bearing=bearing+360 end
	return bearing
end

--Plan each first-phase Volkare step from the card's original direction.
--If that step needs an illegal tile, try the closest neighbouring direction and test the movement again.
local function planVolkareExploreMove(volkarePos, originalBearing, moveCount, objectsInPlay)
	local bearings={}
	local plannedTile=nil
	local simPos={volkarePos[1], volkarePos[2], volkarePos[3]}
	local offsets={0, -60, 60, -120, 120, 180}
	for step=1, moveCount do
		local chosenBearing=nil
		local chosenPos=nil
		for _, offset in ipairs(offsets) do
			local bearing=normalizeVolkareBearing(originalBearing+offset)
			local testPos={simPos[1]-(2.39*math.cos(math.rad(bearing))), 3.5, simPos[3]-(2.39*math.sin(math.rad(bearing)))}
			local explored=terrainHexAtPosition(testPos, objectsInPlay)~=nil
			if explored==false and plannedTile~=nil then explored=math.sqrt(((testPos[1]-plannedTile[1])^2)+((testPos[3]-plannedTile[3])^2))<3.1 end
			if explored==true then
				chosenBearing=bearing
				chosenPos=testPos
				break
			end
			if plannedTile==nil then
				local legalSpot=volkareLegalExploreSpot(testPos)
				if legalSpot~=nil then
					plannedTile=legalSpot
					chosenBearing=bearing
					chosenPos=testPos
					break
				end
			end
		end
		if chosenBearing==nil then return bearings, plannedTile end
		bearings[step]=chosenBearing
		simPos=chosenPos
	end
	return bearings, plannedTile
end


--Volkare only. Keep his existing slower state/prompt sequence independent from the fast standard Dummy.
function volkareTurn(player, mouseButton, id)
	if mouseButton~="-1" or gStates.positionMageKnight[5]~="Volkare" then return end
	if gStates.tacticShown==true then
		automatedTurnRewindStart(function()
			automatedPlayerRandomTactic()
			gStates.volkareState="Start"
			gStates.volkareAttacked={}
			nextTurnMerged("incrementTurn")
			automatedTacticRewindRelease()
		end)
		return
	end
	--Only the initial Process Volkare click creates the rewind checkpoint. Combat-response clicks
	--continue the already protected sequence without trying to save an intermediate state.
	if gStates.endRoundCalled==false and gStates.volkareState=="Start" and id~="VolkareRewindReady" then
		automatedTurnRewindStart(function() volkareTurn(player,mouseButton,"VolkareRewindReady") end)
		return
	end
	local volkareDrew={color="Blue", spell=2}--this will give Volkare a Frenzy result.
	gStates.volkareFrenzied=true
	local function volkareDrawCard()
		local stats=turnOrder[gStates.turnNumber]
		if stats==nil then return nil end
		local lastCard=automatedDeedDraw(stats.seatPos,1,1)
		if lastCard~=nil then
			gStates.volkareFrenzied=false
			local colors=dummyCardColors(lastCard)
			if colors[1]~=nil then volkareDrew.color=colors[1] elseif lastCard.getGMNotes()=="Wound" then volkareDrew.color="Wound" end
			if gameCardType(lastCard)~="Spell" then volkareDrew.spell=1 end
		end
		return lastCard
	end
	if gStates.positionMageKnight[5]=="Volkare" and gStates.endRoundCalled==false and gStates.volkareState=="Start" then
		gStates.volkareRazeCityKey=nil
		gStates.volkareMovementPaused=false
		gStates.volkareMovementStepPending=false
		gStates.volkarePendingCombatMage=nil
		gStates.volkareAdvanceAfterMovement=false
		automatedAttackResponseUI({visible=false,
			full={active=true,interactable=true,onClick="volkareTurn",text="{en}Fully Attend the Battle{ru}Долгая подготовка к битве{zh-tw}完全參戰{zh-cn}完全参战{ko}전투 완전 참여{es}Participar en la Batalla por Completo{fr}Assistez pleinement à la bataille{pt-br}Participar Totalmente do Combate{de}Vollständig an der Schlacht teilnehmen"},
			partial={active=true,interactable=true,onClick="volkarePartial",text="{en}Partially Attend the Battle{ru}Быстрая подготовка к битве{zh-tw}部分參戰{zh-cn}部分参战{ko}전투 부분 참여{es}Asiste Parcialmente a la Batalla{fr}Participez Partiellement à la Bataille{pt-br}Participe Parcialmente da Batalha{de}Teilweise an der Schlacht teilnehmen"},
			retreat={active=true,interactable=true,onClick="volkareRetreat",text="{en}Retreat from the Battle{ru}Отступить с поля битвы{zh-tw}退出戰鬥{zh-cn}退出战斗{ko}전투 후퇴{es}Retirarse de la Batalla{fr}Retraite de la bataille{pt-br}Recuar da Batalha{de}Rückzug von der Schlacht"}
		})

		local volkareTurnSuffix="{en}."
		gStates.blurb="{en}Processing...{ru}Обработка...{zh-tw}處理中...{zh-cn}处理中...{ko}처리 중...{es}Procesando...{fr}Traitement...{pt-br}Processando...{de}Verarbeitung..."
		UI.setAttribute("DummyNotes", "Text", gStates.blurb)
		if getObjectFromGUID("09a991").is_face_down==false then
			--draw a card if one exists
			volkareDrawCard()
			--wound card will roll and remove unit
			if volkareDrew.color=="Wound" then
				gStates.blurb="{en}Volkare rests this turn{ru}Волкар отдыхает в этот ход{zh-tw}沃卡里這回合休息。{zh-cn}沃卡里这回合休息。{ko}볼케어는 이번 차례에 휴식{es}Volkare descansa este turno{fr}Volkare se repose ce tour{pt-br}Volkare descansa esse turno{de}Volkare ruht diese Runde"
				--roll volkares dice and read result
				gStates.volkareState="Resting"
				local volkareDice=getObjectFromGUID("9a686a")
				volkareDice.randomize()
				safeWaitCondition("AI.Volkare",function()
					local crystalData=gStates.volkareUnitCrystals~=nil and gStates.volkareUnitCrystals[volkareDice.getRotationValue()] or nil
					local unitCard=crystalData~=nil and unitOfferCardAtSlot(crystalData.slot) or nil
					if unitCard~=nil then
						local unitData=gameCards[unitCard.guid]
						local unitName=unitData~=nil and unitData.name~=nil and unitData.name[1] or unitCard.getName()
						unitCard.destruct()
						--add a gray unit to Volkare's Army
						if gStates.gameScenario~="Volkare's Quest" then
							gStates.blurb=joinLang({gStates.blurb, "{en}, and removes the {ru}, и удаляет {zh-tw}\n移除了 {zh-cn}\n移除了 {ko}, 다음 유닛 제거: {es}, y quita el {fr}, et supprime le {pt-br}, e remove a {de}, und beseitigt die ", unitName, "{en} to recruit another unit to his army.{ru}, чтобы нанять еще один отряд в свою армию.{zh-tw}\n來加入他的軍隊。{zh-cn}\n来加入他的军队。{ko} 볼케어 군대에 적 하나 추가.{es} para reclutar otra unidad para su ejército.{fr} recruter une autre unité dans son armée.{pt-br} para recrutar outra unidade para este exército.{de} um eine weitere Einheit für seine Armee zu rekrutieren."})
							local params={position={0, 0, 0}, rotation={0, 180, 180}}
						 	params.position[1]=getObjectFromGUID(dummyBoard).getPosition()[1]+5.1+(0.2*gStates.volkareRecruit)
						 	params.position[2]=getObjectFromGUID(dummyBoard).getPosition()[2]+1.0+(0.2*gStates.volkareRecruit)
						 	params.position[3]=getObjectFromGUID(dummyBoard).getPosition()[3]+1.9+(0.2*gStates.volkareRecruit)
							gStates.volkareRecruit=gStates.volkareRecruit+1
						 	local monster=getObjectFromGUID(monsterPiles.gray).takeObject(params)
						 	gStates.monsterPlayLocation[monster.guid]={params.position[1], params.position[2], params.position[3]}
							gStates.cityMonsterQty[volkare.model][monster.guid]="alive"
						else
							gStates.blurb=joinLang({gStates.blurb, "{en}, and intimidates the {ru}, и запугивает {zh-tw}\n嚇跑了 {zh-cn}\n吓跑了 {ko}, 다음 유닛: {es}, e intimida el {fr}, et intimide le {pt-br}, e intimida a {de}, und schüchtert die ", unitName, "{en} to flee the area.{ru}, и те сбегают.{zh-tw}\n讓他逃離此地區。{zh-cn}\n让他逃离此地区。{ko} 제거됩니다.{es} para huir de la zona.{fr} de fuir la région.{pt-br}para fugir da área.{de} aus dem Gebiet zu fliehen."})
						end
					else
						if gStates.gameScenario~="The War of Four" then
							gStates.blurb=joinLang({gStates.blurb, "{en}, and has no effect on the Unit Offer.{ru} и не оказывает никакого влияния на Доступные отряды.{zh-tw}\n對部隊供應區沒有任何影響。{zh-cn}\n对部队供应区没有任何影响。{ko}, 유닛 영향 없음.{es}, y no tiene ningún efecto sobre la Oferta Unitaria.{fr}, et n'a aucun effet sur l'Offre des unités.{pt-br}, e não tem efeito sobre a Oferta de Unidades.{de}, und hat keine Auswirkungen auf das Anteilsangebot."})
						else
							gStates.blurb=joinLang({gStates.blurb, "{en}."})
						end
					end
					UI.setAttribute("DummyNotes", "Text", gStates.blurb)
					if gStates.volkareWon~=true then gStates.volkareState="ReadyToEnd"; volkareReleaseRewindWhenStable(); mainUIUpdate("Volkare rest complete") end
				end, function() return volkareDice==nil or volkareDice.resting end,8,function()
					gStates.blurb=joinLang({gStates.blurb,"{en}. Volkare's die did not settle; finish any unit-offer effect manually.{ru}. Кубик Волкара не остановился; при необходимости завершите эффект отрядов вручную.{zh-tw}。沃卡里的骰子未停止，請手動處理需要的部隊效果。{zh-cn}。沃卡里的骰子未停止，请手动处理需要的部队效果。{ko}. 볼케어 주사위가 멈추지 않았습니다. 필요한 유닛 효과는 수동으로 처리하세요.{es}. El dado de Volkare no se detuvo; resuelve manualmente cualquier efecto de Unidad.{fr}. Le dé de Volkare ne s'est pas arrêté ; résolvez manuellement tout effet d'Unité.{pt-br}. O dado de Volkare não parou; resolva manualmente qualquer efeito de Unidade.{de}. Volkares Würfel kam nicht zur Ruhe; führt nötige Einheiten-Effekte manuell aus."})
					UI.setAttribute("DummyNotes","Text",gStates.blurb)
					if gStates.volkareWon~=true then gStates.volkareState="ReadyToEnd"; volkareReleaseRewindWhenStable() end
					mainUIUpdate("Volkare rest timeout")
				end)
			end
			--Any other card
			if volkareDrew.color~="Wound" then
				gStates.volkareState="Moving"
				gStates.volkareMovementSequence=(gStates.volkareMovementSequence or 0)+1
				local movementSequence=gStates.volkareMovementSequence
				local volkareVector={	["Volkare's Return"]=				{["White"]=240, ["Blue"]=180, 	["Green"]=120},
										["Volkare's Return Blitz"]=			{["White"]=240, ["Blue"]=180, 	["Green"]=120},
										["Volkare's Quest"]=				{["White"]=60, 	["Blue"]=60, 	["Green"]=0},
										["The War of Four"]=	{["White"]=60, 	["Blue"]=60, 	["Green"]=0}}
				--re roll mana of same colour, gold can be chosen if day and the colour does not exist
				if gStates.volkareFrenzied~=true then
					local found=false
					local remember=nil
					for a, diceObj in pairs(getObjectFromGUID(GUID.zone.mana).getObjects()) do
						if diceObj.type=="Dice" and diceObj.getRotationValue()==volkareDrew.color.." Mana" then
							diceObj.randomize()
							onObjectRandomize({type="Dice"})
							found=true
							break
						end
						if diceObj.type=="Dice" and diceObj.getRotationValue()=="Gold Mana" then remember=diceObj.guid end
					end
					if found==false and remember~=nil and gStates.dayRound==true then
						getObjectFromGUID(remember).randomize()
						onObjectRandomize({type="Dice"})
						found=true
					end
					if found==true then volkareTurnSuffix="{en}, and re-rolled a Mana Die.{ru} и перебросил кубик маны.{zh-tw}\n重擲了一顆魔力骰。{zh-cn}\n重掷了一颗魔力骰。{ko}, 마나 주사위 재굴림.{es} y volvió a lanzar un dado de maná.{fr}, et a relancé un dé de mana.{pt-br}, e rerole um dado de mana.{de}, und würfelte erneut einen Manawürfel." else volkareTurnSuffix="{en}." end
				end

				--move Volkare's figure
				if (((gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz") and gStates.cityRevealed[1]~=nil) or
				 	(gStates.gameScenario=="The War of Four" and ((gStates.cityRevealed[1]~=nil and gStates.cityRevealed[1].state~="defeated") or (gStates.cityRevealed[2]~=nil and gStates.cityRevealed[2].state~="defeated")))) and
					volkareDrew.color=="Red" then volkareDrew.color="Blue" end
				if volkareDrew.color=="Green" or volkareDrew.color=="Blue" or volkareDrew.color=="White" then

					--Find closest city
					local volkarePOS=getObjectFromGUID(gStates.volkareModel).getPosition()
					local cityDistance={dist=500, key=0}
					for key, city in pairs(gStates.cityRevealed) do
						if city.state~="defeated" then
							local cityObj=getObjectFromGUID(city.model)
							local cityPos=cityObj~=nil and cityObj.getPosition() or {500,0,500}
							local temp=math.sqrt(((volkarePOS[1]-cityPos[1])^2)+((volkarePOS[3]-cityPos[3])^2))
							local pair=cityMegapolisPair(city.model)
							local pairObj=pair~=nil and pair~=city.model and getObjectFromGUID(pair) or nil
							if pairObj~=nil then local pairPos=pairObj.getPosition() local pairDist=math.sqrt(((volkarePOS[1]-pairPos[1])^2)+((volkarePOS[3]-pairPos[3])^2)) if pairDist<temp then temp=pairDist end end
							if temp<cityDistance.dist then cityDistance.dist=temp cityDistance.key=key end
						end
					end
					if cityDistance.key~=0 then gStates.volkareRazeCityKey=cityDistance.key end

					--Blurb Update
					gStates.blurb=volkareTurnSuffix
					if volkareDrew.spell==1 then
						if cityDistance.key==0 then gStates.blurb=joinLang({"{en}Volkare moved in the {ru}Волкар переместился в {zh-tw}\n沃卡里移動一格，往{zh-cn}\n沃卡里移动一格，往{ko}볼케어 이동: {es}Volkare se movió en el {fr}Volkare se déplace dans le {pt-br}Volkare se moveu na {de}Volkare bewegt sich im ", translateWord[volkareDrew.color], "{en} direction{ru} направление{zh-tw}方向{zh-cn}方向{ko} 방향{es} dirección{fr} direction{pt-br} direção{de} Richtung", gStates.blurb}) end
						if cityDistance.dist>2.5 and cityDistance.dist<490 then gStates.blurb=joinLang({"{en}Volkare moved towards the city{ru}Волкар двинулся в сторону города{zh-tw}\n沃卡里往城市移動一格。{zh-cn}\n沃卡里往城市移动一格。{ko}볼케어 도시로 이동{es}Volkare se movió hacia la ciudad{fr}Volkare s'est déplacé vers la ville{pt-br}Volkare se moveu em direção a Cidade{de}Volkare bewegte sich in Richtung der Stadt", gStates.blurb}) end
					else
						if cityDistance.key==0 then gStates.blurb=joinLang({"{en}Volkare moved twice in the {ru}Волкаре дважды переместился в {zh-tw}\n沃卡里移動兩格，往{zh-cn}\n沃卡里移动两格，往{ko}볼케어 두 번 이동: {es}Volkare se movió dos veces en el {fr}Volkare se déplace deux fois dans le {pt-br}Volkare se moveu 2x na direção da Cidade {de}Volkare bewegt sich zweimal in die ", translateWord[volkareDrew.color], "{en} direction{ru} направление{zh-tw}方向{zh-cn}方向{ko} 방향{es} dirección{fr} direction{pt-br} direção{de} Richtung", gStates.blurb}) end
						if cityDistance.dist>5 and cityDistance.dist<490 then gStates.blurb=joinLang({"{en}Volkare moved twice towards the city{ru}Волкар дважды двигался в сторону города{zh-tw}\n沃卡里往城市移動兩格。{zh-cn}\n沃卡里往城市移动两格。{ko}볼케어 도시로 두 번 이동{es}Volkare se movió dos veces hacia la ciudad{fr}Volkare s'est déplacé deux fois vers la ville{pt-br}Volkare se moveu 2x na direção da Cidade{de}Volkare bewegte sich zweimal in Richtung der Stadt", gStates.blurb}) end
					end

					local terrainPlayed=false
					local volkareExploreBearings={}
					--Before the city is found, each step tries the card's indicated direction first.
					--If that step requires an illegal new tile, retry in the closest legal direction.
					if cityDistance.key==0 and (gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz") then
						local objectsInPlay=getObjectFromGUID(mapArea).getObjects()
						local originalBearing=volkareVector[gStates.gameScenario][volkareDrew.color]
						local terrainSpot=nil
						volkareExploreBearings, terrainSpot=planVolkareExploreMove(volkarePOS, originalBearing, volkareDrew.spell, objectsInPlay)
						if terrainSpot~=nil then
							local terrainStack=getObjectFromGUID(GUID.bag.terrain.stack)
							if terrainStack~=nil and terrainStack.getQuantity()>0 then
								local newtile=terrainStack.takeObject({position=terrainSpot, smooth=true})
								terrainPlayed=true
								gStates.blurb=joinLang({gStates.blurb, "{en} New Terrain explored.{ru} Исследована новая территория.{zh-tw}\n新地形被探索了。{zh-cn}\n新地形被探索了。{ko} 새 지도 타일 공개{es} Nuevo Terreno explorado.{fr} Nouveau Terrain exploré.{pt-br} Novo Terreno explorado.{de} Neues Terrain erkundet."})
								safeWaitFrames("AI.Volkare",function() safeWaitCondition("AI.Volkare",function() if newtile~=nil then newtile.flip() end end, function() return newtile==nil or newtile.resting end,8,function() if newtile~=nil then newtile.flip() end end) end, 5)
							end
						end
					end

					local wait=0
					if terrainPlayed==true then wait=5 end
					local pass=0
					local doubleAttack=false
					for z=1, volkareDrew.spell, 1 do
						local stepNumber=z
						safeWaitTime("AI.Volkare",function() safeWaitCondition("AI.Volkare",function()
							if movementSequence~=gStates.volkareMovementSequence or gStates.volkareWon==true then return end
							pass=stepNumber
							if stepNumber>1 then gStates.volkareMovementStepPending=false end
							--check he won't move out of bounds and alter his course
							if getObjectFromGUID(gStates.volkareModel)~=nil then
								volkareQuestPortalStatus()
								if gStates.volkareWon==true then return end
								--correct course if going out of bounds
								volkarePOS=getObjectFromGUID(gStates.volkareModel).getPosition()
								if cityDistance.key==0 and volkareExploreBearings[pass]~=nil then volkareVector[gStates.gameScenario][volkareDrew.color]=volkareExploreBearings[pass] end
								local objectsInPlay=getObjectFromGUID(mapArea).getObjects()
								local arrowColor=volkareDrew.color
								local volkareProjPos={volkarePOS[1]-(2.39*math.cos(math.rad(volkareVector[gStates.gameScenario][volkareDrew.color]))), 3.5, volkarePOS[3]-(2.39*math.sin(math.rad(volkareVector[gStates.gameScenario][volkareDrew.color])))}
								local found=terrainHexAtPosition(volkareProjPos, objectsInPlay)~=nil
								if found==false and gStates.gameScenario~="Volkare's Quest" and gStates.gameScenario~="The War of Four" and cityDistance.key>0 and (volkareDrew.color=="White" or volkareDrew.color=="Green") then volkareDrew.color="Blue" end
								if found==false and (gStates.gameScenario=="Volkare's Quest" or gStates.gameScenario=="The War of Four") and (volkareDrew.color=="White" or volkareDrew.color=="Blue") then volkareDrew.color="Green" found=true end
								if found==false and (gStates.gameScenario=="Volkare's Quest" or gStates.gameScenario=="The War of Four") and volkareDrew.color=="Green" then volkareDrew.color="Blue" end

								--change vector to move closer to the city
								if cityDistance.key>0 and gStates.gameScenario~="Volkare's Quest" then
									local cityPos=getObjectFromGUID(gStates.cityRevealed[cityDistance.key].model).getPosition()
									getObjectFromGUID(gStates.volkareModel).setDecals({})
									--stops automation next to city
									local primaryDistance=math.sqrt(((volkarePOS[1]-cityPos[1])^2)+((volkarePOS[3]-cityPos[3])^2))
									local pair=cityMegapolisPair(gStates.cityRevealed[cityDistance.key].model)
									local pairObj=pair~=nil and pair~=gStates.cityRevealed[cityDistance.key].model and getObjectFromGUID(pair) or nil
									local pairPos=pairObj~=nil and pairObj.getPosition() or nil
									local pairDistance=pairPos~=nil and math.sqrt(((volkarePOS[1]-pairPos[1])^2)+((volkarePOS[3]-pairPos[3])^2)) or 500
									local attackingPrimary=primaryDistance<=pairDistance
									if primaryDistance<2.5 or pairDistance<2.5 then
										--check if city is beat by player or end game
										gStates.volkareAttacked={}
										gStates.volkareState="Attacking City"
										if gStates.defeatedCities.amount==0 then
											gStates.blurb="{en}Volkare has been welcomed in by the City, making him unbeatable.<size=6>\n\n</size>You have Lost.{ru}Волкара радушно приняли в Городе, и теперь его невозможно победить.<size=6>\n\n</size>Вы проиграли.{zh-tw}\n沃卡里受到城市的熱烈歡迎，\n他已經無人能敵。你輸了。{zh-cn}\n沃卡里受到城市的热烈欢迎，\n他已经无人能敌。你输了。{ko}볼케어는 무수한 환영을 받으며 도시에 도착했다. 이제 그를 막을 자는 없다.<size=6>\n\n</size>게임 패배.{es}Volkare ha sido recibido por la ciudad, haciéndolo invencible.<size=6>\n\n</size>Has perdido.{fr}Volkare a été accueilli par la Cité, ce qui le rend imbattable.<size=6>\n\n</size>Vous avez perdu.{pt-br}Volkare foi recebido com louvores na Cidade, fazendo-o imbatível.<size=6>\n\n</size>Você perdeu.{de}Volkare wurde von der Stadt aufgenommen, was ihn unschlagbar macht.<size=6>\n\n</size>Du hast verloren."
											gStates.volkareWon=true; volkareReleaseRewindWhenStable()
											getObjectFromGUID(trashCan).putObject(getObjectFromGUID(gStates.volkareModel))
										else
											--check if player is there defending or end game
											local primaryCity=gStates.cityRevealed[cityDistance.key].model
											local pairedCity=cityMegapolisPair(primaryCity)
											local function avatarDefendsTargetCity(location)
												local function matches(cityGUID)
													local cityName=CITY_NAME_BY_GUID[cityGUID]
													if cityName==nil then return false end
													local color=cityName:sub(6)
													return location==cityName or location=="raised "..color
												end
												return matches(primaryCity) or (pairedCity~=nil and pairedCity~=primaryCity and matches(pairedCity))
											end
											for playerIndex, playerDetails in pairs(turnOrder) do
												if playerDetails.mage~="Volkare" and playerDropoutInactive(playerIndex)==false and avatarDefendsTargetCity(playerDetails.avatarLocation or "") then
													gStates.volkareAttacked[#gStates.volkareAttacked+1]={mage=playerDetails.mage, distance=2.5}
												end
											end
											if #gStates.volkareAttacked>=1 then
												--Remember the attack approach so a successful Volkare's Return defense can move him physically.
												--If this attack is the first half of a Spell/Frenzy double move, the remaining step brings him forward again after the retreat.
												if (gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz") and gStates.volkareCityDefenseMove==nil then
													local targetPos=attackingPrimary==false and pairPos or cityPos
													gStates.volkareCityDefenseMove={attackPos={volkarePOS[1], volkarePOS[2], volkarePOS[3]}, cityPos={targetPos[1], targetPos[2], targetPos[3]}, secondMove=(volkareDrew.spell==2 and pass==1), resolving=false}
												end
												if (volkareDrew.spell==2 and pass==2) or volkareDrew.spell==1 then
													local EndText="{en}otherwise Volkare enters the city and you have Lost.{ru}в противном случае Волкар войдет в город, и вы Проиграете.{zh-tw}\n否則沃卡里進入城市，你輸了。{zh-cn}\n否则沃卡里进入城市，你输了。{ko}이외에 볼케어가 도시에 입장했다면, 게임 패배.{es}de lo contrario, Volkare entra en la ciudad y has perdido.{fr}sinon Volkare entre dans la ville et vous avez perdu.{pt-br}do contrário Volkare entra na cidade e você perdeu.{de}andernfalls dringt Volkare in die Stadt ein und du hast verloren."
													local MidText="{en}<size=6>\n\n</size>If you Defend and kill at least {ru}<size=6>\n\n</size>Если вы защититесь и убьете хотя бы {zh-tw}<size=6>\n\n</size>若你防守並擊敗至少 {zh-cn}<size=6>\n\n</size>若你防守并击败至少 {ko}<size=6>\n\n</size>볼케어 군대의 적을 최소 {es}<size=6>\n\n</size>Si defiendes y matas al menos {fr}<size=6>\n\n</size>Si vous défendez et tuez au moins {pt-br}<size=6>\n\n</size>Se você defender e matar pelo menos {de}<size=6>\n\n</size>Wenn Sie verteidigen und mindestens einen "
													if gStates.volkareRaisedCity==true then MidText="{en}<size=6>\n\n</size>If you kill at least {ru}<size=6>\n\n</size>Если вы убьете хотя бы {zh-tw}<size=6>\n\n</size>若你擊敗至少 {zh-cn}<size=6>\n\n</size>若你击败至少 {ko}<size=6>\n\n</size>볼케어 군대의 적을 최소 {es}<size=6>\n\n</size>Si matas al menos {fr}<size=6>\n\n</size>Si tu tues au moins {pt-br}<size=6>\n\n</size>Se você matar pelo menos {de}<size=6>\n\n</size>Wenn du mindestens " end
													if gStates.gameScenario=="The War of Four" then EndText="{en}otherwise you retreat and Volkare moves onto the city, destroying it.{ru}в противном случае вы отступаете, и Волкар движется в город, разрушая его.{zh-tw}\n否則你會撤退並且讓沃卡里進入\n城市，將其摧毀。{zh-cn}\n否则你会撤退并且让沃卡里进入\n城市，将其摧毁。{ko}이외에 플레이어는 후퇴하고, 볼케어가 이동하여 도시를 파괴합니다.{es}de lo contrario, te retiras y Volkare se mueve hacia la ciudad, destruyéndola.{fr}Sinon, vous battez en retraite et Volkare se déplace sur la ville, la détruisant.{pt-br}do contrário você recua e Volkare move para a cidade, destruindo-a.{de}andernfalls ziehst du dich zurück und Volkare rückt auf die Stadt vor und zerstört sie." end
													if volkareDrew.spell==1 or (volkareDrew.spell==2 and doubleAttack==false) then
														gStates.blurb=joinLang({"{en}Volkare Attacks the City{ru}Волкар атакует город{zh-tw}\n沃卡里攻擊這個城市{zh-cn}\n沃卡里攻击这个城市{ko}볼케어 도시 공격{es}Volkare ataca la ciudad{fr}Volkare attaque la ville{pt-br}Volkare ataca a Cidade{de}Volkare greift die Stadt an", gStates.blurb, MidText, gStates.playerCount, "{en} of Volkare's army, move Volkare back one space, {ru} отряда из армии Волкара, переместите Волкара на одну клетку назад, {zh-tw} 名\n沃卡里的手下，\n沃卡里會向後退一格，{zh-cn} 名\n沃卡里的手下，\n沃卡里会向后退一格，{ko} 개 처치했다면, 볼케어는 한 칸 후퇴합니다, {es} del ejército de Volkare, mueve Volkare hacia atrás un espacio, {fr} de l'armée de Volkare, reculez Volkare d'une case, {pt-br} do Exército de Volkare, mova Volkare de volta 1 espaço, {de} von Volkares Armee tötest, ziehst du Volkare ein Feld zurück, ", EndText})
													end
													if volkareDrew.spell==2 and doubleAttack==true then
														gStates.blurb=joinLang({"{en}Volkare Attacks the City{ru}Волкар атакует город{zh-tw}沃里卡攻击这个城市{zh-cn}沃里卡攻击这个城市{ko}볼케어 도시 공격{es}Volkare ataca la ciudad{fr}Volkare attaque la ville{pt-br}Volkare ataca a Cidade{de}Volkare greift die Stadt an", gStates.blurb, MidText, gStates.playerCount, "{en} of Volkare's army, Volkare stays where he is, {ru} отряда из армии Волкара, Волкар останется на своем месте, {zh-tw} 名\n沃卡里的手下，\n沃卡里會留在原位置，{zh-cn} 名\n沃卡里的手下，\n沃卡里会留在原位置，{ko} 개 처치했다면, 볼케어는 지금 자리에 머뭅니다, {es} del ejército de Volkare, Volkare permanece donde está, {fr} de l'armée de Volkare, Volkare reste où il est, {pt-br} do Exército de Volkare, Volkare fica aonde ele está, {de} von Volkare's Armee, bleibt Volkare wo er ist, ", EndText})
													end
													if gStates.volkareRaisedCity==false then gStates.blurb=joinLang({gStates.blurb, "{en}<size=6>\n\n</size>Not defending means Volkare will destroy the city walls.{ru}<size=6>\n\n</size>Отказ от защиты означает, что Волкар разрушит городские стены.{zh-tw}<size=6>\n\n</size>不防守代表沃卡里會摧毀城牆。{zh-cn}<size=6>\n\n</size>不防守代表沃卡里会摧毁城墙。{ko}<size=6>\n\n</size>방어하지 않으면 볼케어가 성벽을 파괴합니다.{es}<size=6>\n\n</size>No defender significa que Volkare destruirá las murallas de la ciudad.{fr}<size=6>\n\n</size>Ne pas se défendre signifie que Volkare détruira les murs de la ville.{pt-br}<size=6>\n\n</size>Não defender significa que o Volkare destruirá as muralhas da cidade.{de}<size=6>\n\n</size>Wenn Sie sich nicht verteidigen, wird Volkare die Stadtmauern zerstören."}) end
													gStates.volkareLock=false
												end
												--initiate fight if location has mage knights, Mage knights allways retreat
												UI.setAttribute("CoopAssaultMainTableText1", "text", "{en}Combined Defense Possible{ru}Доступна Совместная защита города{zh-tw}可以進行合作防守{zh-cn}可以进行合作防守{ko}협력 수비 가능{es}Defensa Combinada Posible{fr}Défense Combinée Possible{pt-br}Defesa Combinada Possível{de}Gemeinsame Verteidigung möglich")
												UI.setAttribute("CoopAssaultMainTableText2", "text", "{en}The City is under attack. Players must skip their next turn and Defend. This tool randomly assigns the chosen number of attackers to each player. All must face Volkare.{ru}Город атакован. Игроки должны пропустить свой следующий ход и защищаться. Этот инструмент случайным образом распределяет выбранное количество атакующих между игроками. Все должны сразиться с Волкаром.{zh-tw}城市正遭受攻擊。玩家必須跳過下一個回合並進行防禦。此工具會將所選數量的攻擊者隨機分配給每位玩家。所有玩家都必須面對沃卡里。{zh-cn}城市正遭受攻击。玩家必须跳过下一个回合并进行防御。此工具会将所选数量的攻击者随机分配给每位玩家。所有玩家都必须面对沃卡里。{ko}도시가 공격받고 있습니다. 플레이어는 다음 턴을 건너뛰고 방어해야 합니다. 이 도구는 선택한 수의 공격자를 각 플레이어에게 무작위로 배정합니다. 모두 볼케어와 맞서야 합니다.{es}La Ciudad está bajo ataque. Los jugadores deben saltarse su próximo turno y Defender. Esta herramienta asigna al azar la cantidad elegida de atacantes a cada jugador. Todos deben enfrentarse a Volkare.{fr}La Cité est attaquée. Les joueurs doivent passer leur prochain tour et Défendre. Cet outil répartit aléatoirement le nombre choisi d’attaquants entre les joueurs. Tous doivent affronter Volkare.{pt-br}A Cidade está sob ataque. Os jogadores devem pular o próximo turno e Defender. Esta ferramenta distribui aleatoriamente a quantidade escolhida de atacantes entre os jogadores. Todos devem enfrentar Volkare.{de}Die Stadt wird angegriffen. Die Spieler müssen ihren nächsten Zug aussetzen und Verteidigen. Dieses Werkzeug verteilt die gewählte Anzahl Angreifer zufällig auf die Spieler. Alle müssen sich Volkare stellen.")
												UI.setAttribute("CoopAssaultMainTableText3", "text", "")
												UI.setAttribute("CoopAssaultMainTableText3", "active", "false")
												UI.setAttribute("startAssaultText", "text", "{en}Begin Defense{ru}Начать защиту{zh-tw}開始防守{zh-cn}开始防守{ko}수비 시작{es}Comenzar Defensa{fr}Commencer la Défense{pt-br}Comece a Defesa{de}Verteidigung Starten")
												local coopVolkareDefense=#gStates.volkareAttacked>=2
												automatedAttackResponseUI({visible=true,
													full={active=true,interactable=true,onClick=coopVolkareDefense and "volkareCoopDefense" or "volkareTurn",text=coopVolkareDefense and "{en}Coop Defend the City{ru}Совместно Защитить город{zh-tw}合作保衛城市{zh-cn}合作保卫城市{ko}협력 도시 방어{es}Cooperativa Defiende la Ciudad{fr}Coopérative Défendre la Ville{pt-br}Cooperativa Defenda a Cidade{de}Coop Verteidigen Sie die Stadt" or "{en}Fully Defend the City{ru}Полностью Защитить город{zh-tw}全力保衛城市{zh-cn}全力保卫城市{ko}도시 완전 방어{es}Defiende Completamente la Ciudad{fr}Défendre Pleinement la Ville{pt-br}Defenda Totalmente a Cidade{de}Die Stadt vollständig verteidigen"},
													partial={active=coopVolkareDefense~=true,interactable=true,onClick="volkarePartial",text="{en}Partially Defend the City{ru}Частично Защитить город{zh-tw}部分保衛城市{zh-cn}部分保卫城市{ko}도시 부분 방어{es}Defiende Parcialmente la Ciudad{fr}Défendre Partiellement la Ville{pt-br}Defenda Parcialmente a Cidade{de}Teilweise die Stadt verteidigen"},
													retreat={active=true,interactable=true,onClick="volkareRetreat",text="{en}Don't Defend the City{ru}Не Защищать город{zh-tw}不要保衛城市{zh-cn}不要保卫城市{ko}도시 방어 안함{es}No Defiendas la Ciudad{fr}Ne Défendez pas la Ville{pt-br}Não Defenda a Cidade{de}Die Stadt nicht verteidigen",tooltip=gStates.volkareRaisedCity==true and "Volkare will conquer the City. You lose." or "Volkare will raise the city (it provides no Interaction or Hand Size bonus from then on)"}
												})
												if coopVolkareDefense then dropoutCoopDefensePrompt=true applyColorBarButtons() end
												doubleAttack=true
											else
												if gStates.gameScenario~="The War of Four" then
													--check if this is Volkare's second attack or end game
													if gStates.volkareRaisedCity==true then
														gStates.blurb="{en}Volkare has conquered the city.<size=6>\n\n</size>You have Lost.{ru}Волкар захватил город.<size=6>\n\n</size>Вы проиграли.{zh-tw}\n沃卡里已經征服了這座城市。<size=6>\n\n</size>你輸了。{zh-cn}\n沃卡里已经征服了这座城市。<size=6>\n\n</size>你输了。{ko}볼케어가 도시를 정복했습니다.<size=6>\n\n</size>게임 패배{es}Volkare ha conquistado la ciudad.<size=6>\n\n</size>Has perdido.{fr}Volkare a conquis la ville.<size=6>\n\n</size>Vous avez perdu.{pt-br}Volkare conquistou a Cidade<size=6>\n\n</size>Você Perdeu.{de}Volkare hat die Stadt erobert.<size=6>\n\n</size>Du hast verloren."
														getObjectFromGUID(trashCan).putObject(getObjectFromGUID(gStates.volkareModel))
														gStates.volkareWon=true; volkareReleaseRewindWhenStable()
													else
														if (volkareDrew.spell==2 and pass==2) or volkareDrew.spell==1 then gStates.blurb=joinLang({"{en}Volkare has raised the city\n(it provides no Interaction or Hand Size bonus from now on){ru}Волкар поднял город\n(с этого момента он не дает бонусов за взаимодействие или для предела руки){zh-tw}\n沃卡里劫掠了城市四周\n（從現在起此城市不能交涉，\n並且不會增加手牌上限）{zh-cn}\n沃卡里劫掠了城市四周\n（从现在起此城市不能交涉，\n并且不会增加手牌上限）{ko}볼케어가 도시를 파괴했습니다.\n(이제 도시에서 교류를 할 수 없고 카드 보유 제한 혜택이 사라집니다.){es}Volkare ha elevado la ciudad\n(a partir de ahora no proporciona ninguna bonificación por interacción o tamaño de la mano){fr}Volkare a élevé la ville\n(il ne fournit plus de bonus d'interaction ou de taille de main à partir de maintenant){pt-br}Volkare ergueu a Cidade\n(Ela não fornece Interação ou Bonus de Tamanho de mão por hora){de}Volkare hat die Stadt erhöht\n(sie bietet von nun an keinen Interaktions- oder Handgrößenbonus mehr)", gStates.blurb}) end
														volkareRazesCity(cityDistance.key)
													end
												else
													--start him heading to the next city or portal
													getObjectFromGUID(trashCan).putObject(getObjectFromGUID(gStates.cityRevealed[cityDistance.key].model))
													gStates.cityRevealed[cityDistance.key].state="defeated"
													gStates.blurb=joinLang({"{en}Volkare has raised the city\n(Consider it an empty space with movement cost of the terain under it){ru}Волкар поднял город\n(Считайте это пустым пространством со стоимостью движения местности под ним){zh-tw}\n沃卡里劫掠了城市四周\n（地點視為一格空地，移動費用\n比照其原有地形。）{zh-cn}\n沃卡里劫掠了城市四周\n（地点视为一格空地，移动费用\n比照其原有地形。）{ko}볼카레가 도시를 키웠습니다.\n(그 아래 지형의 이동 비용이 있는 빈 공간으로 간주합니다).{es}Volkare ha elevado la ciudad\n(considérelo un espacio vacío con el coste de movimiento de la tierra debajo de él){fr}Volkare a élevé la ville\n(Considérez-le comme un espace vide avec le coût de déplacement du terrain en dessous){pt-br}Volkare ergueu a Cidade\n(Considere-a um espaço vazio com custo de movimento do terreno sob ela){de}Volkare hat die Stadt erhöht\n(Betrachten Sie es als ein leeres Feld mit den Bewegungskosten des Feldes unter ihm)", gStates.blurb})
												end
											end
										end
										if (volkareDrew.spell==2 and (pass==2 or gStates.volkareWon==true)) or volkareDrew.spell==1 then
											if #gStates.volkareAttacked==0 and gStates.volkareWon~=true then gStates.volkareState="ReadyToEnd"; volkareReleaseRewindWhenStable() end
											UI.setAttribute("DummyNotes", "Text", gStates.blurb)
											mainUIUpdate("Volkare Beat City")
										end
										if gStates.gameScenario~="The War of Four" or #gStates.volkareAttacked>=1 then return end
									end
									--chooses a proper bearing
									local targetCityPos=cityPos
									local pair=cityMegapolisPair(gStates.cityRevealed[cityDistance.key].model)
									local pairObj=pair~=nil and pair~=gStates.cityRevealed[cityDistance.key].model and getObjectFromGUID(pair) or nil
									if pairObj~=nil then local pairPos=pairObj.getPosition() if math.sqrt(((volkarePOS[1]-pairPos[1])^2)+((volkarePOS[3]-pairPos[3])^2))<math.sqrt(((volkarePOS[1]-cityPos[1])^2)+((volkarePOS[3]-cityPos[3])^2)) then targetCityPos=pairPos end end
									local cityBearing=math.floor((math.deg(math.atan2(volkarePOS[3]-targetCityPos[3], volkarePOS[1]-targetCityPos[1]))/60)+0.5)*60
									if cityBearing>=360 then cityBearing=cityBearing-360 end
									if cityBearing<0 then cityBearing=cityBearing+360 end
									volkareVector[gStates.gameScenario][volkareDrew.color]=cityBearing
									arrowColor="Orange"
								end

								--one hex away from portal always goes to portal
								local portalTile=volkareQuestPortalTile()
								local portalPos=portalTile~=nil and portalTile.getPosition() or volkarePOS
								local volkareToPortalDist=math.sqrt(((volkarePOS[1]-portalPos[1])^2)+((volkarePOS[3]-portalPos[3])^2))
								local portalSpecial=(gStates.gameScenario=="The War of Four") or gStates.gameScenario=="Volkare's Quest"
								if portalSpecial and volkareToPortalDist<2.5 then
									--stops automation when on portal need to inititiate a game over.
									if volkareToPortalDist<0.5 then
										gStates.volkareWon=true; volkareReleaseRewindWhenStable()
										gStates.blurb="{en}Volkare passed through the Portal. His unknowable intentions achieved.<size=6>\n\n</size>You have Lost.{ru}Волкар прошел через Портал. Его непостижимые намерения достигнуты.<size=6>\n\n</size>Вы проиграли.{zh-tw}沃卡里穿越了傳送門。\n他無人知曉的密謀達成了。<size=6>\n\n</size>你輸了。{zh-cn}沃卡里穿越了传送门。\n他无人知晓的密谋达成了。<size=6>\n\n</size>你输了。{ko}볼케어가 포탈에 도착했고 그의 알수 없는 목적을 달성했습니다.<size=6>\n\n</size>게임 패배.{es}Volkare pasó por el Portal. Sus incognoscibles intenciones logradas.<size=6>\n\n</size>Has perdido.{fr}Volkare passa par le Portail. Ses intentions inconnaissables se sont réalisées.<size=6>\n\n</size>Vous avez perdu.{pt-br}Volkare passou pelo portal. Suas intenções misteriosas conquistadas.<size=6>\n\n</size>Você perdeu.{de}Volkare ging durch das Portal. Seine unbekannten Absichten wurden erfüllt.<size=6>\n\n</size>Du hast verloren."
										UI.setAttribute("DummyNotes", "Text", gStates.blurb)
										mainUIUpdate("Volkare entered portal")
										return
									end
									--find the portal bearing
									local portalBearing=math.floor((math.deg(math.atan2(volkarePOS[3]-portalPos[3], volkarePOS[1]-portalPos[1]))/60)+0.5)*60
									if portalBearing>=360 then portalBearing=portalBearing-360 end
									if portalBearing<0 then portalBearing=portalBearing+360 end
									volkareVector[gStates.gameScenario][volkareDrew.color]=portalBearing
									arrowColor="Orange"
								end

								--white green and blue card will move volkare (Red also when city revealed)
								local volkareNewPos={volkarePOS[1]-(2.39*math.cos(math.rad(volkareVector[gStates.gameScenario][volkareDrew.color]))), 3.5, volkarePOS[3]-(2.39*math.sin(math.rad(volkareVector[gStates.gameScenario][volkareDrew.color])))}
								getObjectFromGUID(gStates.volkareModel).unlock()
								getObjectFromGUID(gStates.volkareModel).setPositionSmooth(volkareNewPos)
								safeWaitFrames("AI.Volkare",function() safeWaitCondition("AI.Volkare",function() local v=getObjectFromGUID(gStates.volkareModel) if v~=nil and gStates.volkareLock~=false then v.lock() end end, function() local v=getObjectFromGUID(gStates.volkareModel) return v==nil or (v.resting and v.isSmoothMoving()==false and v.getPosition()[2]<1.5) end,8,function() local v=getObjectFromGUID(gStates.volkareModel) if v~=nil then v.setVelocity({0,0,0}) v.setAngularVelocity({0,0,0}) if gStates.volkareLock~=false then v.lock() end end end) end, 5)
								local arrow=getObjectFromGUID("6647eb").clone({position={volkarePOS[1]-(1.1*math.cos(math.rad(volkareVector[gStates.gameScenario][volkareDrew.color]))), 1.11, volkarePOS[3]-(1.1*math.sin(math.rad(volkareVector[gStates.gameScenario][volkareDrew.color])))}})
								local convert={[0]=270, [60]=210, [120]=150, [180]=90, [240]=30, [300]=330}
								arrow.setRotation({90.00, convert[volkareVector[gStates.gameScenario][volkareDrew.color]], 0.00})
								arrow.setColorTint(arrowColor)
								arrow.unlock()
								safeWaitFrames("AI.Volkare",function() arrow.lock() end, 50)

								--initiate fight if location has mage knights,
								local magesInRange=findNearbyMages(volkareNewPos, 1.5)
								if #magesInRange>0 then
									gStates.volkareState="Attacking Player"
									if stepNumber<volkareDrew.spell then
										gStates.volkareMovementPaused=true
										gStates.volkareMovementStepPending=true
										gStates.volkarePendingCombatMage=magesInRange[1].mage
									else
										gStates.volkareAdvanceAfterMovement=false
									end
									if gStates.volkareAttacked~=nil then
										gStates.volkareAttacked[#gStates.volkareAttacked+1]={mage=magesInRange[1].mage, distance=magesInRange[1].distance}
									else
										gStates.volkareAttacked={{mage=magesInRange[1].mage, distance=magesInRange[1].distance}}
									end
									if #gStates.volkareAttacked<2 then
										gStates.blurb=joinLang({gStates.blurb, "{en}Volkare attacked {ru}Волкар атаковал {zh-tw}\n沃卡里攻擊了{zh-cn}\n沃卡里攻击了{ko}볼케어의 공격: {es}Volkare atacó {fr}Volkare a attaqué {pt-br}Volkare atacou {de}Volkare angegriffen ", translateWord[magesInRange[1].mage], "{en}. ", translateWord[magesInRange[1].mage], "{en} can take {ru} может взять {zh-tw}可拿取 {zh-cn}可拿取 {ko} 플레이어는 {es} puede tomar {fr} peut prendre {pt-br} pode receber {de} können sich ", (math.ceil(gStates.currentRound/2)+1), "{en} wounds to retreat.{ru} раны и отступить.{zh-tw} 張創傷卡來躲避。\n{zh-cn} 张创伤卡来躲避。\n{ko} 장의 부상을 받고 후퇴할 수 있습니다.{es} heridas para retirarse.{fr} blessures à reculer.{pt-br} Ferimentos para recuar.{de} Wunden zum Rückzug."})
										local questSkipTarget=gStates.gameScenario=="Volkare's Quest" and volkareQuestSkipThreshold() or (gStates.playerCount*2)
										if (gStates.gameScenario=="Volkare's Quest" or gStates.gameScenario=="The War of Four") then gStates.blurb=joinLang({gStates.blurb, "{en} Defeating at least {ru} Победив по крайней мере {zh-tw}\n在沃卡里的下個回合之前，\n擊敗至少 {zh-cn}\n在沃卡里的下个回合之前，\n击败至少 {ko} 볼케어 군대의 최소 {es} Derrotando al menos {fr} Vaincre au moins {pt-br} Derrotar ao menos {de} Das Besiegen von mindestens ", tostring(questSkipTarget), "{en} of Volkare's army before his next turn will force him to skip that turn.{ru} отряда из армии Волкара до его следующего хода, вы заставите его пропустить этот ход.{zh-tw} 名沃卡里的手下，\n會讓沃卡里強制跳過他的回合。\n{zh-cn} 名沃卡里的手下，\n会让沃卡里强制跳过他的回合。\n{ko} 개의 적을 처치했다면 볼케어는 다음 차례를 쉽니다.{es} del ejército de Volkare antes de su próximo turno lo obligará a saltarse ese turno.{fr} de l'armée de Volkare avant son prochain tour le forcera à sauter ce tour.{pt-br} do Exército de Volkare antes do seu próximo turno o forçará a pular aquele turno.{de} der Armee von Volkare vor seinem nächsten Zug zu besiegen, zwingt ihn, diesen Zug auszulassen."}) end
										UI.setAttribute("VolkareAttacked", "active", "true")
										volkareQuestRefreshFullAttend(magesInRange[1].mage)
									else
										gStates.blurb=joinLang({gStates.blurb, " ", translateWord[magesInRange[1].mage], "{en} is also attacked, but will need to be done manually. Resolve that attack, then click Volkare Processed.{ru} также атакован, но это нужно будет проделать вручную.{zh-tw}也遭受攻擊，\n這部分需要手動執行。{zh-cn}也遭受攻击，\n这部分需要手动执行。{ko}의 전투는 수동으로 처리해 주세요.{es} también es atacado, pero deberá hacerse manualmente{fr} est également attaqué, mais devra être fait manuellement{pt-br} é também atacado, mas precisará fazê-lo manualmente{de} wird ebenfalls angegriffen, muss aber manuell erledigt werden"})
										gStates.volkareState="ReadyToEnd"; volkareReleaseRewindWhenStable()
										UI.setAttribute("VolkareAttacked", "active", "false")
										mainUIUpdate("Volkare second attack manual")
									end
								end

								--remove Guide Arrows
								if (gStates.gameScenario=="Volkare's Quest" or gStates.gameScenario=="The War of Four") and math.sqrt(((volkareNewPos[1]-portalPos[1])^2)+((volkareNewPos[3]-portalPos[3])^2))<2.5 then
									getObjectFromGUID(gStates.volkareModel).setDecals({})
								end
								if (volkareDrew.spell==2 and pass==2) or volkareDrew.spell==1 then UI.setAttribute("DummyNotes", "Text", gStates.blurb) end
								safeWaitCondition("AI.Volkare",function()
									if movementSequence~=gStates.volkareMovementSequence then return end
									volkareQuestPortalStatus()
									if #magesInRange==0 and stepNumber==volkareDrew.spell and gStates.volkareWon~=true then
										gStates.volkareState="ReadyToEnd"; volkareReleaseRewindWhenStable()
										if gStates.volkareAdvanceAfterMovement==true then
											gStates.volkareAdvanceAfterMovement=false
											nextTurnMerged("incrementTurn")
										else mainUIUpdate("Volkare movement complete") end
									end
								end, function() local v=getObjectFromGUID(gStates.volkareModel) return v==nil or (v.resting and v.isSmoothMoving()==false and v.getPosition()[2]<1.5) end,8,function()
								if movementSequence~=gStates.volkareMovementSequence then return end
								local v=getObjectFromGUID(gStates.volkareModel)
								if v~=nil then v.setVelocity({0,0,0}) v.setAngularVelocity({0,0,0}) if gStates.volkareLock~=false then v.lock() end end
								volkareQuestPortalStatus()
								if #magesInRange==0 and stepNumber==volkareDrew.spell and gStates.volkareWon~=true then
									gStates.volkareState="ReadyToEnd"; volkareReleaseRewindWhenStable()
									if gStates.volkareAdvanceAfterMovement==true then gStates.volkareAdvanceAfterMovement=false nextTurnMerged("incrementTurn") else mainUIUpdate("Volkare movement timeout") end
								end
							end)
							end
						end, function()
							if movementSequence~=gStates.volkareMovementSequence then return true end
							local v=getObjectFromGUID(gStates.volkareModel)
							return v==nil or (v.resting and (stepNumber==1 or gStates.volkareMovementPaused~=true))
						end)	end, wait+(2*(z-1)))
					end
				end

				--red card will initiate fight with avatars
				if volkareDrew.color=="Red" then
					gStates.blurb=volkareTurnSuffix
					gStates.volkareState="Attacking Player"
					local volkarePOS={getObjectFromGUID(gStates.volkareModel).getPosition()[1], 1, getObjectFromGUID(gStates.volkareModel).getPosition()[3]}
					local magesInRange={}
					if volkareDrew.spell==1 then magesInRange=findNearbyMages(volkarePOS, 2.5) else magesInRange=findNearbyMages(volkarePOS, 5) end
					if #magesInRange>0 then
						gStates.blurb=joinLang({"{en}Volkare attacked {ru}Волкар атаковал {zh-tw}\n沃卡里攻擊了{zh-cn}\n沃卡里攻击了{ko}볼케어의 공격: {es}Volkare atacó {fr}Volkare a attaqué {pt-br}Volkare atacou {de}Volkare angegriffen ", translateWord[magesInRange[1].mage], gStates.blurb, "<size=6>\n\n</size>", translateWord[magesInRange[1].mage], "{en} may retreat taking {ru} может отступить, взяв {zh-tw}可以躲避，拿取 {zh-cn}可以躲避，拿取 {ko} 플레이어는 {es} puede retirarse tomando {fr} peut battre en retraite en prenant {pt-br} pode fugir tomando {de} kann sich zurückziehen und ", tostring(math.ceil(gStates.currentRound/2)+1), "{en} wounds,\nor stand and fight{ru} раны,\n или остаться и сражаться{zh-tw} 張創傷卡\n或是不躲避直接戰鬥。{zh-cn} 张创伤卡\n或是不躲避直接战斗。{ko} 장의 부상을 받고 후퇴하거나,\n볼케어와 전투합니다.{es} heridas,\no estar de pie y pelear{fr} blessures,\ni se lever et se battre{pt-br} ferimentos,\nou ficar e lutar.{de} Wunden,\noder stehen und kämpfen"})
						UI.setAttribute("VolkareAttacked", "active", "true")
						volkareQuestRefreshFullAttend(magesInRange[1].mage)
						if gStates.volkareAttacked~=nil then
							gStates.volkareAttacked[#gStates.volkareAttacked+1]={mage=magesInRange[1].mage, distance=magesInRange[1].distance}
						else
							gStates.volkareAttacked={{mage=magesInRange[1].mage, distance=magesInRange[1].distance}}
						end
					else
						gStates.blurb=joinLang({"{en}Volkare looked for a fight to no avail{ru}Волкар пытался вступить в бой, но безуспешно.{zh-tw}\n沃卡里試圖找人戰鬥，\n但沒有任何結果。{zh-cn}\n沃卡里试图找人战斗，\n但没有任何结果。{ko}볼케어는 전투할 상대를 찾지 못했습니다.{es}Volkare buscó una pelea en vano{fr}Volkare a cherché un combat en vain{pt-br}Volkare procurou uma luta em vão{de}Volkare suchte vergeblich einen Kampf", gStates.blurb})
						gStates.volkareState="ReadyToEnd"; volkareReleaseRewindWhenStable()
					end
					UI.setAttribute("DummyNotes", "Text", gStates.blurb)
					mainUIUpdate("Volkare red action complete")
				end
			end
		else
			getObjectFromGUID("09a991").flip()
			gStates.volkareState="ReadyToEnd"; volkareReleaseRewindWhenStable()
			local questSkipThreshold=gStates.volkareQuestSkipThreshold or volkareQuestSkipThreshold()
			gStates.blurb=joinLang({"{en}Volkare lost at least {ru}Волкар потерял по крайней мере {zh-tw}\n沃卡里失去了至少 {zh-cn}\n沃卡里失去了至少 {ko}볼케어는 최소 {es}Volkare perdió al menos {fr}Volkare a perdu au moins {pt-br}Volkare perdeu ao menos {de}Volkare verlor mindestens ", questSkipThreshold, "{en} tokens from his Army, so misses a turn{ru} жетонов из его Армии, поэтому пропускает ход{zh-tw} 名手下，\n因此將跳過他的回合{zh-cn} 名手下，\n因此将跳过他的回合{ko} 명의 병사를 잃었기에, 이번 차례를 쉽니다.{es} fichas de su ejército, por lo que pierde un turno{fr} jetons de son armée, donc rate un tour{pt-br} fichas de seu exército, então perde um turno{de} Spielsteine aus seiner Armee und verpasst somit eine Runde"})
			gStates.volkareQuestSkipThreshold=nil
			UI.setAttribute("DummyNotes", "Text", gStates.blurb)
		end
		gStates.volkareArmyDefeated=0
		mainUIUpdate("Volkare Beat City")
		return
	end
	if id=="VolkareAttackedFull" and gStates.gameScenario=="Volkare's Quest" and gStates.volkareAttacked~=nil and gStates.volkareAttacked[1]~=nil and volkareQuestFullAttendAllowed(gStates.volkareAttacked[1].mage)~=true then
		volkareQuestRefreshFullAttend(gStates.volkareAttacked[1].mage)
		broadcastToAll("{en}Fully Attend is unavailable: the attacked Mage Knight's Round Order token is already face down, or they have no non-Wound cards in hand.{ru}Полное участие недоступно: жетон порядка хода атакованного Рыцаря-мага уже лежит лицом вниз или у него в руке нет карт, кроме Ран.{zh-tw}無法完全參戰：遭攻擊魔法騎士的回合順位標記已翻面，或手牌中沒有非創傷牌。{zh-cn}无法完全参战：遭攻击魔法骑士的回合顺序标记已翻面，或手牌中没有非创伤牌。{ko}완전 참전할 수 없습니다. 공격받은 마법 기사의 라운드 순서 토큰이 이미 뒷면이거나 손에 부상 이외의 카드가 없습니다.{es}No se puede Asistir por Completo: la ficha de Orden de Ronda del Caballero Mago atacado ya está boca abajo o no tiene cartas que no sean Heridas en la mano.{fr}Participation complète indisponible : le jeton d’Ordre de Manche du Chevalier-Mage attaqué est déjà face cachée, ou sa main ne contient aucune carte autre que des Blessures.{pt-br}Não é possível Participar por Completo: a ficha de Ordem da Rodada do Cavaleiro-Mago atacado já está virada para baixo, ou ele não tem cartas que não sejam Ferimentos na mão.{de}Vollständige Teilnahme ist nicht möglich: Der Rundenreihenfolgemarker des angegriffenen Magieritters liegt bereits verdeckt oder er hat nur Wunden auf der Hand.", warningColor)
		return
	end
	UI.setAttribute("VolkareAttackedFull", "interactable", "false")
	UI.setAttribute("VolkareAttackedFullImage", "image", "Sliced Button/Button New Deactive")
	UI.setAttribute("VolkareAttackedPartial", "interactable", "false")
	UI.setAttribute("VolkareAttackedPartialImage", "image", "Sliced Button/Button New Deactive")
	UI.setAttribute("VolkareAttackedPartialText", "text", "{en}Partially Attend the Battle{ru}Быстрая подготовка к битве{zh-tw}部分參戰{zh-cn}部分参战{ko}전투 부분 참여{es}Asiste Parcialmente a la Batalla{fr}Participez Partiellement à la Bataille{pt-br}Participe Parcialmente da Batalha{de}Teilweise an der Schlacht teilnehmen")
	UI.setAttribute("VolkareRetreat", "active", "true")
	UI.setAttribute("VolkareRetreat", "interactable", "false")
	UI.setAttribute("VolkareRetreatImage", "image", "Sliced Button/Button New Deactive")
	if id=="VolkareAttackedFull" or id=="VolkareRetreat" or id=="VolkareAttackedPartial" then
		--find mage knight affected
		for x, mageDetails in pairs(turnOrder) do
			if gStates.volkareAttacked[1]~=nil and mageDetails.mage==gStates.volkareAttacked[1].mage then
				if id=="VolkareAttackedFull" then
					--Flip turn order token
					if getObjectFromGUID(mageDetails.turnOrderTokenGUID).is_face_down==false then getObjectFromGUID(mageDetails.turnOrderTokenGUID).flip() end
					--place Volkare's Army
					safeWaitFrames("AI.Volkare",function() safeWaitCondition("AI.Volkare",function()
						nextTurnMerged("incrementTurn")
						attackLocation("", "-1", "Volkar"..mageDetails.mage)
					end, function() local token=getObjectFromGUID(mageDetails.turnOrderTokenGUID) return token==nil or token.resting end,6,function()
						nextTurnMerged("incrementTurn")
						attackLocation("", "-1", "Volkar"..mageDetails.mage)
					end) end, 5)
					return
				end
				if id=="VolkareRetreat" then

				end
				if id=="VolkareAttackedPartial" then
					for _, playAreaObj in pairs(getObjectFromGUID(playerPlayAreas[mageDetails.seatPos]).getObjects()) do
						if monsterPugs[playAreaObj.guid]~=nil then
							if playAreaObj.is_face_down==true then
								--returns undefeated monsters.
								playAreaObj.setRotationSmooth({0, 180, 0})
								playAreaObj.setPositionSmooth(gStates.monsterPlayLocation[playAreaObj.guid])
							else
								--mark city monsters defeated
								if gStates.cityMonsterQty[volkare.model][playAreaObj.guid]~=nil then
									--mark monster dead
									gStates.cityMonsterQty[volkare.model][playAreaObj.guid]="dead"
								end
							end
						end
						if playAreaObj.getGMNotes()=="Volkare Reminder Token" then getObjectFromGUID(trashCan).putObject(playAreaObj) end
					end
					volkareQuestCombatWithdrawalReminder(mageDetails.mage)
				end
			end
		end
	end
	if (id=="VolkareRetreat" or id=="VolkareAttackedPartial") and gStates.volkareMovementStepPending==true then
		gStates.volkareMovementPaused=false
		gStates.volkarePendingCombatMage=nil
		gStates.volkareState="Moving"
		mainUIUpdate("Volkare resumes second movement")
		return
	end
	gStates.volkareMovementPaused=false
	gStates.volkareMovementStepPending=false
	gStates.volkarePendingCombatMage=nil
	gStates.volkareAdvanceAfterMovement=false
	gStates.volkareState="Start"
	gStates.volkareAttacked={}
	automatedTurnRewindRelease()
	nextTurnMerged("incrementTurn")
end

function volkarePartial(player, mouseButton, id)
	if mouseButton=="-1" then
		if dropoutCoopDefensePrompt==true then dropoutCoopDefensePrompt=false applyColorBarButtons() end
		UI.setAttribute("VolkareAttackedPartial", "onClick", "volkareTurn")
		UI.setAttribute("VolkareAttackedPartialText", "text", "{en}Finished Partially Attending{ru}Завершено Частичное участие{zh-tw}部分參戰結束{zh-cn}部分参战结束{ko}전투 부분 참여 완료{es}Finalizada la Participación Parcial{fr}Fini Partiellement Participant{pt-br}Participar Parcialmente do Combate{de}Teilweise Teilnahme an der Schlacht beendet")
		UI.setAttribute("VolkareAttackedFull", "interactable", "false")
		UI.setAttribute("VolkareAttackedFullImage", "image", "Sliced Button/Button New Deactive")
		UI.setAttribute("VolkareRetreat", "interactable", "false")
		UI.setAttribute("VolkareRetreatImage", "image", "Sliced Button/Button New Deactive")
		--find mage knight affected
		for _, mageDetails in pairs(turnOrder) do
			if gStates.volkareAttacked[1]~=nil and mageDetails.mage==gStates.volkareAttacked[1].mage then
				--place Volkare's Army
				--Wait.time(function()
				attackLocation("", "-1", "Volkar"..mageDetails.mage)
				--end, 1)
				break
			end
		end
	end
end

--Resolve the physical push-back after a successful Volkare's Return city defense.
--Volkare attacks from an adjacent space, so one hex backward leaves one empty space between him and the City (distance 2).
--If a Spell/Frenzy attack happened on its first movement step, the remaining step then returns him to the adjacent attack space.
function volkareReturnCityDefenseMove()
	if gStates==nil or (gStates.gameScenario~="Volkare's Return" and gStates.gameScenario~="Volkare's Return Blitz") or gStates.volkareArmyDefeated<gStates.playerCount then return false end
	local move=gStates.volkareCityDefenseMove
	local volkareObj=gStates.volkareModel~=nil and getObjectFromGUID(gStates.volkareModel) or nil
	if move==nil or move.resolving==true or move.attackPos==nil or move.cityPos==nil then return false end
	if volkareObj==nil then gStates.volkareCityDefenseMove=nil return false end
	move.resolving=true
	local dx=move.attackPos[1]-move.cityPos[1]
	local dz=move.attackPos[3]-move.cityPos[3]
	local dist=math.sqrt((dx*dx)+(dz*dz))
	if dist<0.1 then move.resolving=false return false end
	local retreatPos={move.attackPos[1]+((dx/dist)*2.39), 3.5, move.attackPos[3]+((dz/dist)*2.39)}
	local function lockAndFinish()
		local obj=getObjectFromGUID(gStates.volkareModel)
		if obj~=nil then obj.lock() end
		gStates.volkareLock=true
		gStates.volkareCityDefenseMove=nil
	end
	local function finishRetreat()
		local obj=getObjectFromGUID(gStates.volkareModel)
		if obj==nil then gStates.volkareCityDefenseMove=nil return end
		if move.secondMove==true then
			obj.setPositionSmooth({move.attackPos[1], 3.5, move.attackPos[3]})
			safeWaitFrames("AI.Volkare",function() safeWaitCondition("AI.Volkare",lockAndFinish, function() local v=getObjectFromGUID(gStates.volkareModel) return v==nil or (v.resting and v.getPosition()[2]<1.5) end, 3, lockAndFinish) end, 3)
		else lockAndFinish() end
	end
	volkareObj.unlock()
	volkareObj.setPositionSmooth(retreatPos)
	safeWaitFrames("AI.Volkare",function() safeWaitCondition("AI.Volkare",finishRetreat, function() local v=getObjectFromGUID(gStates.volkareModel) return v==nil or (v.resting and v.getPosition()[2]<1.5) end, 3, finishRetreat) end, 3)
	return true
end

function volkareRetreat(player, mouseButton, id)
	if mouseButton=="-1" then
		if dropoutCoopDefensePrompt==true then dropoutCoopDefensePrompt=false applyColorBarButtons() end
		local retreatText=UI.getAttribute("VolkareRetreatText", "text") or ""
		local playerRetreat=retreatText:sub(1, 11)=="{en}Retreat"
		UI.setAttribute("VolkareRetreat", "onClick", "volkareTurn")
		UI.setAttribute("VolkareRetreatText", "text", "{en}Finished Retreating{ru}Завершено отступление{zh-tw}完成撤退{zh-cn}完成撤退{ko}후퇴 완료{es}Terminar de Retirarse{fr}Retraite Terminée{pt-br}Retiro Acabado{de}Beendeter Rückzug")
		UI.setAttribute("VolkareAttackedFull", "interactable", "false")
		UI.setAttribute("VolkareAttackedFullImage", "image", "Sliced Button/Button New Deactive")
		UI.setAttribute("VolkareAttackedPartial", "interactable", "false")
		UI.setAttribute("VolkareAttackedPartialImage", "image", "Sliced Button/Button New Deactive")
		--find mage knight affected
		for x, mageDetails in pairs(turnOrder) do
			if gStates.volkareAttacked[1]~=nil and mageDetails.mage==gStates.volkareAttacked[1].mage then
				if playerRetreat==true then
					--give woundCards
					for a=1, (math.ceil(gStates.currentRound/2)+1), 1 do
						getObjectFromGUID("e917e2").takeObject({position={(mageDetails.seatPos*40)-90, 3.5, -48.4}, rotation={0, 180, 0}, smooth=false})
					end
					broadcastToAll(joinLang({translateWord[mageDetails.mage], "{en} gained {ru} получает {zh-tw}增加了{zh-cn}增加了{ko}의 획득:  {es} ganó {fr} a subi {pt-br} ganhou {de} gewonnen ", (math.ceil(gStates.currentRound/2)+1), "{en} wounds.{ru} раны.{zh-tw}张创伤卡{zh-cn}张创伤卡{ko}장의 부상{es} heridas.{fr} blessures.{pt-br} ferimentos.{de} Wunden."}), positionToColor(x))
					if gStates.volkareAttacked[1].distance<1.5 and gStates.volkareMovementStepPending~=true then broadcastToAll(joinLang({translateWord[mageDetails.mage], "{en} needs to withdraw to a neighboring Safe space.{ru} должен перейти на соседнее безопасное место.{zh-tw}需要强制撤退到附近的安全地带{zh-cn}需要强制撤退到附近的安全地带{ko}: 인접한 안전한 칸으로 강제후퇴해야 합니다.{es} necesita retirarse a un espacio seguro vecino.{fr} doit se retirer dans un espace sûr voisin.{pt-br} precisa se retirar para um espaço seguro vizinho.{de} sich auf ein benachbartes sicheres Feld zurückziehen muss."}), positionToColor(x)) end
				else
					local returnScenario=gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz"
					if returnScenario and gStates.volkareRaisedCity==true then
						gStates.volkareCityDefenseMove=nil
						gStates.blurb="{en}Volkare has conquered the city.<size=6>\n\n</size>You have Lost.{ru}Волкар захватил город.<size=6>\n\n</size>Вы проиграли.{zh-tw}\n沃卡里已經征服了這座城市。<size=6>\n\n</size>你輸了。{zh-cn}\n沃卡里已经征服了这座城市。<size=6>\n\n</size>你输了。{ko}볼케어가 도시를 정복했습니다.<size=6>\n\n</size>게임 패배{es}Volkare ha conquistado la ciudad.<size=6>\n\n</size>Has perdido.{fr}Volkare a conquis la ville.<size=6>\n\n</size>Vous avez perdu.{pt-br}Volkare conquistou a Cidade<size=6>\n\n</size>Você Perdeu.{de}Volkare hat die Stadt erobert.<size=6>\n\n</size>Du hast verloren."
						local volkareObj=gStates.volkareModel~=nil and getObjectFromGUID(gStates.volkareModel) or nil
						if volkareObj~=nil then getObjectFromGUID(trashCan).putObject(volkareObj) end
						gStates.volkareWon=true
						volkareReleaseRewindWhenStable()
						UI.setAttribute("VolkareRetreatText", "text", "{en}Volkare Processed{ru}Волкар сходил{zh-tw}沃卡里行動結束{zh-cn}沃卡里行动结束{ko}진행 완료{es}Volkare Procesado{fr}Volkare Traité{pt-br}Volkare Processado{de}Volkare Verarbeitet")
						UI.setAttribute("DummyNotes", "Text", gStates.blurb)
						mainUIUpdate("Volkare conquered raised city undefended")
					else
						broadcastToAll("{en}Volkare Raised the City{ru}Волкар добрался до города{zh-tw}沃里卡占领了城市{zh-cn}沃里卡占领了城市{ko}볼케어가 도시를 정복했습니다.{es}Volkare Levantó la Ciudad{fr}Volkare a Elevé la Ville{pt-br}Volkare Elevou a Cidade{de}Volkare hat die Stadt gehoben", positionToColor(x))
						volkareRazesCity(gStates.volkareRazeCityKey)
						UI.setAttribute("VolkareRetreatText", "text", "{en}Volkare Processed{ru}Волкар сходил{zh-tw}沃卡里行動結束{zh-cn}沃卡里行动结束{ko}진행 완료{es}Volkare Procesado{fr}Volkare Traité{pt-br}Volkare Processado{de}Volkare Verarbeitet")
					end
				end
				break
			end
		end
	end
end

function volkareCoopDefense(player, mouseButton, id)
	if mouseButton=="-1" then
		UI.setAttribute("VolkareAttackedFull", "interactable", "false")
		UI.setAttribute("VolkareAttackedFullImage", "image", "Sliced Button/Button New Deactive")
		UI.setAttribute("VolkareRetreat", "interactable", "false")
		UI.setAttribute("VolkareRetreatImage", "image", "Sliced Button/Button New Deactive")
		--load the coop Interface
		for _, mageDetails in pairs(turnOrder) do
			if gStates.volkareAttacked[1]~=nil and mageDetails.mage==gStates.volkareAttacked[1].mage then
				attackLocation("", "-1", "Volkar"..mageDetails.mage)
				break
			end
		end
		dropoutCoopDefensePrompt=false
		applyColorBarButtons()
	end
end

-- Volkare reminder token randomization
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
	safeWaitFrames("Volkare",function() safeWaitCondition("Volkare",function()
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

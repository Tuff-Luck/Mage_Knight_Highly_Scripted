-- Start-at-higher-level setup flow and its temporary player pools.

function higherLevelRelocateUnits(playerIndex)
	local playerData=turnOrder[playerIndex]
	if playerData==nil or playerData.poolCreated~=true or playerData.seatPos==nil then return end
	local playArea=getObjectFromGUID(playerPlayAreas[playerData.seatPos])
	if playArea==nil then return end
	local layout=unitLayoutSnapshot(playerData.seatPos)
	local alreadyInUnitArea=layout.unitByGuid
	for _, obj in pairs(playArea.getObjects()) do
		if obj.type=="Card" and gameCardType(obj)=="Regular Unit" and alreadyInUnitArea[obj.guid]~=nil then
			--The overlapping Play/Unit zones report cards already placed below; leave them alone.
		elseif obj.type=="Card" and gameCardType(obj)=="Regular Unit" then
			for slot, command in ipairs(layout.commands) do
				if layout.unitBySlot[slot]==nil then
					obj.setRotationSmooth({0,180,0})
					local scale=unitLayoutCardScale(#layout.commands)
					obj.setScale({scale,1,scale})
					obj.setPositionSmooth({layout.slotX[slot],2.0,-34.74})
					layout.unitBySlot[slot]=obj
					break
				end
			end
		end
	end
	scheduleUnitLayoutRefresh(playerData.seatPos)
end

--Create and Update Level Interface for Player count
local higherLevelUIPause=true
function mageLevelBoard()
	if higherLevelUIPause==true then safeWaitFrames("SetupGame",function()
		if gStates.magesSetup==true then
			--Create an interface for all players in the game
			for a=1, #turnOrder, 1 do
				if turnOrder[a].mage~=gStates.positionMageKnight[5] then
					if turnOrder[a].seatPos>0 then
						UI.setAttribute("Mage"..turnOrder[a].seatPos.."levelText", "Text", joinLang({"{en}Start at Level {ru}Начать с уровнем {zh-tw}起始等级：{zh-cn}起始等级：{ko}시작 레벨: {es}Empezar en el Nivel {fr}Début Niveau {pt-br}Iníciar no Nível {de}Starte auf Level ", turnOrder[a].level}))
						UI.setAttribute("Mage"..turnOrder[a].seatPos.."influenceText", "Text", joinLang({turnOrder[a].influence, "{en} Influence Per Level{ru} Влияние(я) за ур.{zh-tw}每级构筑点数{zh-cn}每级构筑点数{ko} 영향력*레벨{es} Influencia por Nivel{fr} Influence par Niveau{pt-br} Influência por Nível{de} Einfluss pro Stufe"}))
						UI.setAttribute("Mage"..turnOrder[a].seatPos.."influenceTotalText", "Text", joinLang({"{en}Influence to Spend : {ru}Доступно влияния: {zh-tw}影响力额度：{zh-cn}影响力额度：{ko}주어진 영향력: {es}Influencia para Gastar : {fr}Influence à Dépenser : {pt-br}Influência para Gastar : {de}Einfluss zum Ausgeben : ", (turnOrder[a].influence*turnOrder[a].level)+gStates.bondsOfLoyalty[a]}))
						UI.setAttribute("Mage"..turnOrder[a].seatPos.."AdvancedActionFreeText", "Text", joinLang({math.floor((turnOrder[a].level-1)/2), "{en} Free Advanced Action(s){ru} Бесплатное(ых) особое(ых) действие(ия/ий){zh-tw} 張免費的高級行動卡{zh-cn} 張免費的高級行動卡{ko}장의 무료 상급 액션{es} Acción Avanzada Gratuita{fr} Action Avancée Gratuite{pt-br} Cartas de Ação Avançadas Gratuitas{de} Freie Fortgeschrittene Aktion(en)"}))
						UI.setAttribute("Mage"..turnOrder[a].seatPos.."NameText", "Text", translateWord[turnOrder[a].mage])
						UI.setAttribute("Mage"..turnOrder[a].seatPos.."NamePanel", "Color", positionToColor(a))
						if gStates.showboards[a]==true then
							turnOrder[a].level=2
							if gStates.gameScenario=="Fast Forwarded Conquest" then turnOrder[a].level=6 end
							if gStates.gameScenario=="The Lost Relic Blitz" then turnOrder[a].level=3 end
							gStates.showboards[a]=false
							playArea=getObjectFromGUID(turnOrder[a].playerBoardGUID).getPosition()
							Player[positionToColor(a)].lookAt({position={playArea[1], playArea[2], playArea[3]+2}, pitch=65, yaw=0, distance=28})
							UI.setAttribute("Mage"..turnOrder[a].seatPos.."levelText", "Text", joinLang({"{en}Start at Level {ru}Начать с уровнем {zh-tw}起始等级：{zh-cn}起始等级：{ko}시작 레벨: {es}Empezar en el Nivel {fr}Début Niveau {pt-br}Iníciar no Nível {de}Starte auf Level ", turnOrder[a].level}))
							UI.setAttribute("Mage"..turnOrder[a].seatPos.."influenceTotalText", "Text", joinLang({"{en}Influence to Spend : {ru}Доступно влияния: {zh-tw}影响力额度：{zh-cn}影响力额度：{ko}주어진 영향력: {es}Influencia para Gastar : {fr}Influence à Dépenser : {pt-br}Influência para Gastar : {de}Einfluss zum Ausgeben : ", (turnOrder[a].influence*turnOrder[a].level)+gStates.bondsOfLoyalty[a]}))
							UI.show("Mage"..turnOrder[a].seatPos.."LevelBoard")
						end
						--Move any Regular Unit selection accidentally dropped in the main play area to its command-token slot.
						higherLevelRelocateUnits(a)
						--Zero the stats
						local badPlay=false
						local stats={"AdvancedActions", "Spells", "SpellCrystals", "Artifacts", "RegularUnits", "RegularUnitsWorth", "Crystals"}
						for b, c in pairs(stats) do
							turnOrder[a].levelingStats[c]=0
						end
						safeWaitFrames("SetupGame",function()
							--Count Everything in the player's play area
							local spellColors={}
							local crystalColors={}
							local countedUnits={}--Play and Unit zones can overlap; only value each selected Unit once.
							for b, c in pairs(getObjectFromGUID(playerPlayAreas[turnOrder[a].seatPos]).getObjects()) do
								if c.type=="Card" then
									if c.getGMNotes()=="Advanced Action" then turnOrder[a].levelingStats.AdvancedActions=turnOrder[a].levelingStats.AdvancedActions+1 end
									if gameCardType(c)=="Regular Unit" and countedUnits[c.guid]==nil then
										countedUnits[c.guid]=true
										turnOrder[a].levelingStats.RegularUnits=turnOrder[a].levelingStats.RegularUnits+1
										turnOrder[a].levelingStats.RegularUnitsWorth=turnOrder[a].levelingStats.RegularUnitsWorth-gameCards[c.guid].influence
									end
									if c.getGMNotes()=="Spell" then
										turnOrder[a].levelingStats.Spells=turnOrder[a].levelingStats.Spells+1
										spellColors[#spellColors+1]=c.getDescription()
									end
									if c.getGMNotes()=="Artifact" then turnOrder[a].levelingStats.Artifacts=turnOrder[a].levelingStats.Artifacts+1 end
								end
								if c.type=="Figurine" then
									if gStates.startingHigherLevelCrystal[c.guid]~=nil then
										turnOrder[a].levelingStats.SpellCrystals=turnOrder[a].levelingStats.SpellCrystals+1
										crystalColors[#crystalColors+1]=c.getDescription()
									end
								end
							end
							--Count Everything in the player's Unit area
							for b, c in pairs(getObjectFromGUID(playerUnitAreas[turnOrder[a].seatPos]).getObjects()) do
								if c.type=="Card" then
									if gameCardType(c)=="Regular Unit" and countedUnits[c.guid]==nil then
										countedUnits[c.guid]=true
										turnOrder[a].levelingStats.RegularUnits=turnOrder[a].levelingStats.RegularUnits+1
										turnOrder[a].levelingStats.RegularUnitsWorth=turnOrder[a].levelingStats.RegularUnitsWorth-gameCards[c.guid].influence
									end
								end
							end
							local commandCount=#unitLayoutSnapshot(turnOrder[a].seatPos).commands
							if turnOrder[a].levelingStats.RegularUnits>commandCount then badPlay=true end
							gStates.higherLevelUnitWarning=gStates.higherLevelUnitWarning or {}
							if turnOrder[a].poolCreated==true and turnOrder[a].levelingStats.RegularUnits>commandCount then
								if gStates.higherLevelUnitWarning[a]~=true then
									broadcastToAll(joinLang({"{en}Warning: {ru}Внимание: {zh-tw}警告：{zh-cn}警告：{ko}경고: {es}Advertencia: {fr}Attention : {pt-br}Aviso: {de}Warnung: ", translateWord[turnOrder[a].mage], "{en} has selected more Units than available Command tokens. One or more Units cannot be placed.{ru} выбрал(а) больше отрядов, чем доступно жетонов командования. Один или несколько отрядов нельзя разместить.{zh-tw}选择的部队数量超过了可用的指挥标记数量。一个或多个部队无法放置。{zh-cn}选择的部队数量超过了可用的指挥标记数量。一个或多个部队无法放置。{ko}이 사용 가능한 지휘 토큰보다 많은 유닛을 선택했습니다. 하나 이상의 유닛을 배치할 수 없습니다.{es} ha seleccionado más Unidades que fichas de Mando disponibles. Una o más Unidades no pueden colocarse.{fr} a sélectionné plus d'Unités que de jetons de Commandement disponibles. Une ou plusieurs Unités ne peuvent pas être placées.{pt-br} selecionou mais Unidades do que Fichas de Comando disponíveis. Uma ou mais Unidades não podem ser colocadas.{de} hat mehr Einheiten als verfügbare Befehlsplättchen gewählt. Eine oder mehrere Einheiten können nicht platziert werden."}), positionToColor(a))
								end
								gStates.higherLevelUnitWarning[a]=true
							else
								gStates.higherLevelUnitWarning[a]=nil
							end
							--Count Everything in the player's Inventory area
							for b, c in pairs(getObjectFromGUID(playerCrystalAreas[turnOrder[a].seatPos]).getObjects()) do
								if c.type=="Figurine" then
									if gStates.startingHigherLevelCrystal[c.guid]==nil then
										turnOrder[a].levelingStats.Crystals=turnOrder[a].levelingStats.Crystals+1
									end
								end
							end
							--score Advanced Actions in the play area
							turnOrder[a].levelingStats.AdvancedActionsWorth=(turnOrder[a].levelingStats.AdvancedActions-math.floor((turnOrder[a].level-1)/2))*-6
							if turnOrder[a].levelingStats.AdvancedActionsWorth>0 then turnOrder[a].levelingStats.AdvancedActionsWorth=0 end
							--score Artifacts in the play area
							turnOrder[a].levelingStats.ArtifactsWorth=turnOrder[a].levelingStats.Artifacts*-12
							--score Crystals in the play area
							turnOrder[a].levelingStats.CrystalsWorth=turnOrder[a].levelingStats.Crystals*-3
							--score Spells in the play area .getDescription()
							turnOrder[a].levelingStats.SpellsWorth=(turnOrder[a].levelingStats.Spells*-9)
							local count=0
							for b, c in pairs(crystalColors) do
								for d, e in pairs(spellColors) do
									if c==e then turnOrder[a].levelingStats.SpellsWorth=turnOrder[a].levelingStats.SpellsWorth+2 count=count+1 break end
								end
							end
							if #crystalColors~=count then badPlay=true end
							--update UI
							local influence=turnOrder[a].level*turnOrder[a].influence+gStates.bondsOfLoyalty[a]
							if turnOrder[a].level==1 then influence=0 end
							local remain=influence+turnOrder[a].levelingStats.AdvancedActionsWorth+turnOrder[a].levelingStats.RegularUnitsWorth+turnOrder[a].levelingStats.SpellsWorth+turnOrder[a].levelingStats.ArtifactsWorth+turnOrder[a].levelingStats.CrystalsWorth
							if remain~=turnOrder[a].remain then
								UI.setAttribute("Mage"..turnOrder[a].seatPos.."AdvancedActionCostText", "Text", joinLang({turnOrder[a].levelingStats.AdvancedActions, "{en} Advanced Action(s) : {ru} Особое(ых) действие(ия/ий): {zh-tw} 張高級行動卡：{zh-cn} 張高級行動卡：{ko}장의 상급 액션 : {es} Acción Avanzada : {fr} Action Avancée : {pt-br} Ações Avançadas : {de} Fortgeschrittene Aktion(en) : ", turnOrder[a].levelingStats.AdvancedActionsWorth}))
								UI.setAttribute("Mage"..turnOrder[a].seatPos.."RegularUnitCostText", "Text", joinLang({turnOrder[a].levelingStats.RegularUnits, "{en} Regular Unit(s) : {ru} Обычный(ых) отряд(а/ов): {zh-tw} 支常规部队：{zh-cn} 支常规部队：{ko}개의 일반 유닛 : {es} Unidad(es) Regulares : {fr} Unité(s) Régulières : {pt-br} Unidade(s) Regulares : {de} Normale Einheit(en) : ", turnOrder[a].levelingStats.RegularUnitsWorth}))
								UI.setAttribute("Mage"..turnOrder[a].seatPos.."SpellCostText", "Text", joinLang({turnOrder[a].levelingStats.Spells, "{en} Spell(s) : {ru} Заклинание(я/ий): {zh-tw} 張法術卡：{zh-cn} 張法術卡：{ko}장의 마법 : {es} Hechizo(s) : {fr} Sort(s) : {pt-br} Feitiços : {de} Zauber : ", turnOrder[a].levelingStats.SpellsWorth}))
								UI.setAttribute("Mage"..turnOrder[a].seatPos.."ArtifactCostText", "Text", joinLang({turnOrder[a].levelingStats.Artifacts, "{en} Artifact(s) : {ru} Артефакт(а/ов): {zh-tw} 張神器卡：{zh-cn} 張神器卡：{ko}장의 유물 : {es} Artefacto(s) : {fr} Artefact(s) : {pt-br} Artefatos : {de} Artefakt(e) : ", turnOrder[a].levelingStats.ArtifactsWorth}))
								UI.setAttribute("Mage"..turnOrder[a].seatPos.."CrystalCostText", "Text", joinLang({turnOrder[a].levelingStats.Crystals, "{en} Mana Crystal(s) : {ru} Кристалл(а/ов) маны: {zh-tw} 顆魔晶：{zh-cn} 顆魔晶：{ko}개의 수정 : {es} Cristales de Maná : {fr} Cristaux de Mana : {pt-br} Cristais de Mana : {de} Manakristall(e) : ", turnOrder[a].levelingStats.CrystalsWorth}))
								UI.setAttribute("Mage"..turnOrder[a].seatPos.."RemainingText", "Text", joinLang({"{en}Remaining : {ru}Остаток: {zh-tw}剩餘：{zh-cn}剩餘：{ko}남은 영향력 : {es}Restante : {fr}Restant : {pt-br}Restando : {de}Verbleibend : ", remain}))
								turnOrder[a].remain=remain
								turnOrder[a].levelUpComplete=false
								if remain>=0 and badPlay==false then
									UI.setAttribute("Mage"..turnOrder[a].seatPos.."RemainingText", "Color", "Black")
									UI.setAttribute("Mage"..turnOrder[a].seatPos.."CompleteButton", "interactable", "true")
									UI.setAttribute("Mage"..turnOrder[a].seatPos.."CompleteButtonImage", "image", "Sliced Button/Button New Active")
								else
									if remain<0 then UI.setAttribute("Mage"..turnOrder[a].seatPos.."RemainingText", "Color", "Red") end
									UI.setAttribute("Mage"..turnOrder[a].seatPos.."CompleteButton", "interactable", "false")
									UI.setAttribute("Mage"..turnOrder[a].seatPos.."CompleteButtonImage", "image", "Sliced Button/Button New Deactive")
								end
							end
						end, 5)
					end
				else
					if a==1 then gStates.turnNumber=2 end
				end
			end
		end
		higherLevelUIPause=true
	end, 5)	end
	higherLevelUIPause=false
end

--Change level and Infuence for Player(s)
function mageKnightLevel(player, mouseButton, id)
	if mouseButton=="-1" then
		--check if player was alowed to click those buttons
		local playerPosition=id:sub(5,5)
		if legalPlayerCheck(player.color, tonumber(playerPosition))==true then
			for a, b in pairs(turnOrder) do
				if tostring(b.seatPos)==playerPosition then
					local c=11
					if id:sub(6, 12)~="levelUp" and id:sub(6, 14)~="levelDown" then c=15 end
					if id:sub(c, c+1)=="Up" then
						local levelSum=0
						for c, d in pairs(turnOrder) do
							if d.mage~=gStates.positionMageKnight[5] then levelSum=levelSum+d.level end
						end
						if 	(id:sub(6, 12)~="levelUp" and b[id:sub(6, c-1)]<10) or
							(((levelSum<20 and gStates.coop==1 and gStates.WarOfFourComp~=true) or (levelSum<24 and (gStates.coop==0 or gStates.WarOfFourComp==true))) and b[id:sub(6, c-1)]<10) then
							b[id:sub(6, c-1)]=b[id:sub(6, c-1)]+1
						end
					else
						if b[id:sub(6, c-1)]>1 then b[id:sub(6, c-1)]=b[id:sub(6, c-1)]-1 end
					end
					mageLevelBoard()
					break
				end
			end
		end
	end
end

--Create Start at Higher level Card Pool for Player
function cardPool(player, mouseButton, id)
	if mouseButton=="-1" then
		local playerPosition=id:sub(5,5)
		if legalPlayerCheck(player.color, tonumber(playerPosition))==true then
			--lock clicking players "Create Card Pool" button
			UI.setAttribute("Mage"..playerPosition.."CompleteButton", "onClick", "startHigherLevel")
			UI.setAttribute("Mage"..playerPosition.."CompleteText", "text", "{en}Complete{ru}Завершить{zh-tw}完成{zh-cn}完成{ko}완료{es}Completo{fr}Compléter{pt-br}Completo{de}Fertig")
			UI.setAttribute("Mage"..playerPosition.."CompleteButton", "interactable", "true")
			UI.setAttribute("Mage"..playerPosition.."CompleteButtonImage", "image", "Sliced Button/Button New Active")
			--lock clicking players "+" & "-" Level buttons
			UI.setAttribute("Mage"..playerPosition.."levelDown", "interactable", "false")
			UI.setAttribute("Mage"..playerPosition.."levelUp", "interactable", "false")
			--find the turnOrder List that matches the position
			for _, mageDetails in pairs(turnOrder) do
				if tostring(mageDetails.seatPos)==playerPosition then
					--Create Card Pool
					mageDetails.poolCreated=true
					local poolDraw={[GUID.deck.action]={ 2, 100},--Advanced Actions
					 				[GUID.deck.regularUnit]={ 1, 96 },--Regular Units
									[GUID.deck.spell]={ 0, 92 },--Spells
									[GUID.deck.artifact]={-1, 88 }}--Artifacts
					for deck, numbers in pairs(poolDraw) do
						for _=1, mageDetails.level+numbers[1], 1 do
							getObjectFromGUID(deck).takeObject({position={(mageDetails.seatPos*40)-numbers[2], 3.0, -48.4}, smooth=false, rotation={0, 180, 0}})
						end
					end
					--Give Starting Crystals to player(s)
					if mageDetails.level>1 then
						for c, d in pairs(mageKnights) do
							if d.mage==mageDetails.mage then
								for e=1, 2, 1 do
									local container={["Red"]=GUID.bag.mana.red, ["Blue"]=GUID.bag.mana.blue, ["Green"]=GUID.bag.mana.green, ["White"]=GUID.bag.mana.white}
									local obj=takeManaCrystal(getObjectFromGUID(container[d.crystals[e]]),{position={(mageDetails.seatPos*40)-116.53+(1.76*e), 2.00, -36.80},smooth=false})
									--obj.setVar("state", "Starting")
									if obj~=nil then gStates.startingHigherLevelCrystal[obj.guid]=true end
								end
								break
							end
						end
					end
					--Hero Challenges replace the level-2 pair with the reserved Skill. Higher even levels still flip two of this Hero's own Skills.
					--Keep the consumed level-2 row physically reserved too: the optional level-4+ pairs belong one row below it.
					local skillRows=math.floor(mageDetails.level/2)
					local skillRowOffset=0
					if gStates.heroChallenges==true and mageDetails.level>=2 and heroChallengesData[mageDetails.mage]~=nil then
						for playerIndex,details in pairs(turnOrder) do if details==mageDetails then heroChallengeClaimReservedSkill(playerIndex,true) break end end
						skillRows=math.max(0,skillRows-1)
						skillRowOffset=1
					end
					--draw two skills for each remaining even level
					local obj=nil
					for c=1, skillRows, 1 do
						for d=1, 2, 1 do
							local pos={(mageDetails.seatPos*40)-108.5+(d*3.65), 2.0, -37.19-((c+skillRowOffset)*1.48)}
							obj=getObjectFromGUID(mageDetails.skillBagGUID).takeObject({position=pos, smooth=true, rotation={0, 180, 0}})
							gStates.mageSkills[obj.guid]=pos
						end
					end
					--Add claim buttons
					safeWaitFrames("SetupGame",function() safeWaitCondition("SetupGame",function()
						higherLevelSkillClaimButons()
					end, function() return obj==nil or obj.resting end) end, 5)
					--Deploy Command Token(s). Slot 1 is the printed starting token already on the board.
					local setupCommandCount=1+math.floor((mageDetails.level-1)/2)
					for c=1, setupCommandCount-1 do
						getObjectFromGUID(mageDetails.commandGUID).takeObject({position={unitLayoutX(mageDetails.seatPos,c+1,setupCommandCount),2.00,-31.2}, rotation={0,180,180}})
					end
					scheduleUnitLayoutRefresh(mageDetails.seatPos)
					break
				end
			end
		end
	end
end

--activate skill buttons for non claimed skills.
function higherLevelSkillClaimButons()
	for skillGUID, skillDetails in pairs(skillTokens) do
		if getObjectFromGUID(skillGUID)~=nil and getObjectFromGUID(skillGUID).UI.getXml()=="" then
			local objPos=getObjectFromGUID(skillGUID).getPosition()
			if 	not (objPos[3]>-25 or
				(objPos[3]<-35 and objPos[1]>-68 and objPos[1]<-66) or
				(objPos[3]<-35 and objPos[1]>-28 and objPos[1]<-26) or
				(objPos[3]<-35 and objPos[1]>12 and objPos[1]<14) or
				(objPos[3]<-35 and objPos[1]>52 and objPos[1]<54)) then
				getObjectFromGUID(skillGUID).UI.setXmlTable({createClaimButton(skillGUID, "higherLevelSkill")})
			end
		end
	end
end

function higherLevelSkillAreaPlayer(position)
	if position==nil or position[3]>=-35 then return nil end
	for playerPosition=1, 4, 1 do
		local skillAreaX=(playerPosition*40)-107
		if position[1]>skillAreaX-1 and position[1]<skillAreaX+1 then return playerPosition end
	end
	return nil
end

--Claim and store skills. pairPosition is supplied when the player drags a choice into their skill area,
--so the original row can still identify the other offered skill even if the chosen token was moved vertically.
function higherLevelSkill(player, mouseButton, id, pairPosition)
	if mouseButton=="-1" then
		local selectedSkill=getObjectFromGUID(id:sub(1,6))
		if selectedSkill==nil then return end
		local playerPosition=(math.ceil((selectedSkill.getPosition()[1]+95)/40))
		local pairZ=pairPosition~=nil and pairPosition[3] or selectedSkill.getPosition()[3]
		if legalPlayerCheck(player.color, tonumber(playerPosition))==true then
			--Bonds of Loyalty goes to unit area
			if id:sub(1,6)=="f30dd4" then
				local bondsX=unitLayoutNextCommandX(playerPosition)
				gStates.mageSkills[id:sub(1,6)]={bondsX,1.1,-31.19}
				selectedSkill.setPositionSmooth({bondsX,1.1,-31.19})
				scheduleUnitLayoutRefresh(playerPosition)
				--Place Unit Cards
				local unitDeck=getObjectFromGUID(GUID.zone.regularUnit).getObjects()[1]
				for a=1, 2, 1 do
					standardDeckCycleShuffleIfReached("Regular Unit", unitDeck)
					unitDeck=getObjectFromGUID(GUID.zone.regularUnit).getObjects()[1]
					unitDeck.takeObject({position={(playerPosition*40)-101, 3.0, -48.4}, smooth=true, rotation={0, 180, 0}})
				end
				for a=1, #turnOrder, 1 do
					if turnOrder[a].seatPos==playerPosition then
						gStates.bondsOfLoyalty[a]=5
						UI.setAttribute("Mage"..playerPosition.."influenceTotalText", "Text", joinLang({"{en}Influence to Spend : {ru}Доступно влияния: {zh-tw}影响力额度：{zh-cn}影响力额度：{ko}주어진 영향력: {es}Influencia para Gastar : {fr}Influence à Dépenser : {pt-br}Influência para Gastar : {de}Einfluss zum Ausgeben : ", (turnOrder[a].influence*turnOrder[a].level)+gStates.bondsOfLoyalty[a]}))
						break
					end
				end
				broadcastToAll("{en}Two more Regular units and 5 influence given to Norowas.{ru}Два дополнительных обычных отряда и 5 влияния даны Норовас{zh-tw}给诺罗瓦斯增加两个常规部队供应和5影响力{zh-cn}给诺罗瓦斯增加两个常规部队供应和5影响力{ko}노로워즈에게 일반 유닛 두 개와 영향력 5가 추가 지급되었습니다. {es}Dos unidades regulares más y 5 influencia dadas a Norowas.{fr}Deux autres unités régulières et 5 d'influence donnés à Norowas.{pt-br}2 unidades Regulares a mais e 5 influência dadas a Norowas{de}Zwei weitere reguläre Einheiten und 5 Einfluss an Norowas gegeben.", {1,1,0.5})
			end
			--Master of Chaos
			if id:sub(1,6)=="1ff34f" then
				masterOfChaosSetup(playerPosition)
			end
			--move claimed skill to skill column. Bonds of Loyalty already moved to/recorded in the Unit Area above.
			selectedSkill.unlock()
			if id:sub(1,6)~="f30dd4" then
				local skillHome={(playerPosition*40)-107.45, 1.5, selectedSkill.getPosition()[3]}
				selectedSkill.setPositionSmooth(skillHome)
				gStates.mageSkills[id:sub(1,6)]=skillHome
			end
			selectedSkill.UI.setXmlTable({{}})
			if gStates.motivationSkill[id:sub(1,6)]~=nil then
				gStates.motivationSkill[id:sub(1,6)].state="active"
				gStates.motivationSkill[id:sub(1,6)].pos=playerPosition
			end
			--find other Skill
			for skillGUID, skillDetails in pairs(skillTokens) do
				if getObjectFromGUID(skillGUID)~=nil then
					local otherSkill=getObjectFromGUID(skillGUID)
					local otherPosition=(math.ceil((otherSkill.getPosition()[1]+95)/40))
					if otherPosition==playerPosition and skillGUID~=id:sub(1,6) and otherSkill.getPosition()[3]>pairZ-1 and otherSkill.getPosition()[3]<pairZ+1 then
						--move other skill to communal area
						local exist=0
						for skillGUID, skillPos in pairs(gStates.mageSkills) do
							if math.floor(skillPos[1])==math.floor((playerPosition*3.7)+7.3) and skillPos[3]>-25 then exist=exist+1 end
						end
						local pos={(playerPosition*3.7)+7.3, 2.00, -23.95+(exist*1.35)}
						otherSkill.unlock()
						otherSkill.setPositionSmooth(pos)
						otherSkill.UI.setXmlTable({{}})
						gStates.mageSkills[skillGUID]=pos
						break
					end
				end
			end
		end
	end
end

--run after all complete's on the start at higher level panel(s) are clicked
function startHigherLevel(player, mouseButton, id)
	if mouseButton=="-1" then
		local playerPosition=id:sub(5,5)
		if legalPlayerCheck(player.color, tonumber(playerPosition))==true then
			--lock clicking players "Complete" button
			UI.setAttribute("Mage"..playerPosition.."CompleteButton", "interactable", "false")
			UI.setAttribute("Mage"..playerPosition.."CompleteButtonImage", "image", "Sliced Button/Button New Deactive")
			--lock clicking players "+" & "-" Influence buttons
			UI.setAttribute("Mage"..playerPosition.."influenceDown", "interactable", "false")
			UI.setAttribute("Mage"..playerPosition.."influenceUp", "interactable", "false")
			local shieldNumber={}
			local startFame={}
			for a=0, 145, 1 do shieldNumber[a]=1 end
			for a=0, 145, 1 do startFame[a]={} end
			--Check if every player is complete
			local finalComplete=true
			for _, b in pairs(turnOrder) do
				if b.seatPos==tonumber(playerPosition) then
					b.levelUpComplete=true
				else
					if b.levelUpComplete~=true and b.mage~=gStates.positionMageKnight[5] then finalComplete=false end
				end
			end
			if finalComplete==true then
				--build a list of fame tokens and where they start
				for a, b in pairs(turnOrder) do
					if turnOrder[a].mage~=gStates.positionMageKnight[5] then
						local fame=gStates.blitz  +  math.ceil(b.remain/150)  +  ((b.level-1)*3)  +  (((b.level-1)*2)/2)
						startFame[fame][#startFame[fame]+1]=true
					end
				end
				--Loop through all playing player positions
				for a=1, #turnOrder, 1 do
					--Make sure it's not the dummy
					if turnOrder[a].mage~=gStates.positionMageKnight[5] then
						--Hide Interface
						UI.hide("Mage"..turnOrder[a].seatPos.."LevelBoard")
						--Return unbought cards
						local deckReturn={["Advanced Action"]=GUID.deck.action, ["Regular Unit"]=GUID.deck.regularUnit, ["Spell"]=GUID.deck.spell, ["Artifact"]=GUID.deck.artifact}
						for b, c in pairs(getObjectFromGUID(handZones[turnOrder[a].seatPos]).getObjects()) do
							if c.type=="Card" then
								getObjectFromGUID(deckReturn[gameCardType(c)]).putObject(c)
							end
						end
						for _, deckGUID in pairs(deckReturn) do getObjectFromGUID(deckGUID).shuffle() end
						--loop through all card in play area
						local deedDeck=nil
						for _, possibleDeck in pairs(getObjectFromGUID(deedDeckZones[turnOrder[a].seatPos]).getObjects()) do
							if possibleDeck.type=="Deck" then deedDeck=possibleDeck break end
						end
						for _, playAreaObj in pairs(getObjectFromGUID(playerPlayAreas[turnOrder[a].seatPos]).getObjects()) do
							if playAreaObj.type=="Card" and (playAreaObj.getGMNotes()=="Advanced Action" or playAreaObj.getGMNotes()=="Spell" or playAreaObj.getGMNotes()=="Artifact") and deedDeck~=nil then
								deedDeck.putObject(playAreaObj)
							end
							--delete any spent Crystals
							if playAreaObj.type=="Figurine" then playAreaObj.destruct() end
						end
						if deedDeck~=nil then deedDeck.shuffle() end
						--Hand Size Increase
						if turnOrder[a].level>4 then
							turnOrder[a].baseHand=turnOrder[a].baseHand+1
							turnOrder[a].hand=turnOrder[a].hand+1
						end
						if turnOrder[a].level>8 then
							turnOrder[a].baseHand=turnOrder[a].baseHand+1
							turnOrder[a].hand=turnOrder[a].hand+1
						end
						--place Fame Token (add 1 fame for any remaining influence)
						local startPosition=1+gStates.blitz+math.ceil(turnOrder[a].remain/150)
						local levelRowFameQuantity=(((turnOrder[a].level-1)*cellGainPerLevel)+normalCellAmount)
						local levelRowLength=((turnOrder[a].level-1)*gStates.rowLengthGainPerLevel)+gStates.normalRowLength
						local fame=startPosition  +  ((turnOrder[a].level-1)*3)  +  (((turnOrder[a].level-1)*2)/2) -  1
						local xOffset=(((1/levelRowFameQuantity*levelRowLength)   /   (#startFame[fame]+1)))   *   (shieldNumber[fame])
						local yOffset=(((heightOfFameBoard/gStates.rowsOnBoard)/(#startFame[fame]+1)))*(shieldNumber[fame])
						local horizontalValue=leftOfFameBoard+(startPosition/levelRowFameQuantity*levelRowLength)-xOffset
						local verticalValue=(topOfFameBoard-((turnOrder[a].level/gStates.rowsOnBoard)*heightOfFameBoard))+yOffset-0.25
						getObjectFromGUID(turnOrder[a].fameGUID).setPosition({horizontalValue, 1.5, verticalValue})
						shieldNumber[fame]=shieldNumber[fame]+1
						turnOrder[a].fame=fame
					end
				end
				--remove wond card deck holders
				local woundCards={[GUID.deck.spell]={"5c38e4", "ab778d"}, [GUID.deck.regularUnit]={"b5048c", "718f39"}}
				for deck, wounds in pairs(woundCards) do
					for a=1, 2, 1 do
						local objToDel=getObjectFromGUID(deck).takeObject({guid=wounds[a], position={40.8, 8.0, -10.2}})
						objToDel.destruct()
					end
				end
				--Return to regular setup
				UI.hide("LevelUpRules")
				safeWaitTime("SetupGame",afterLoad, 0.1)
			end
		end
	end
end

-- Player-board Deeds runtime.

--Deed/discard descriptions are informational and only need rebuilding when that physical pile changes.
--Key the debounce by scripting zone rather than Deck GUID because TTS can replace/collapse Deck objects as cards merge or are drawn.
local deckDescriptionWait={}
--Deed draws are always single-digit in normal play. TTS otherwise waits to see if another digit is coming before firing onObjectNumberTyped.
function setDeedDeckImmediateNumberTyping(seatPos)
	local zoneGUID=deedDeckZones[seatPos]
	local zone=zoneGUID~=nil and getObjectFromGUID(zoneGUID) or nil
	if zone==nil then return end
	for _, obj in pairs(zone.getObjects()) do if obj.type=="Deck" then obj.max_typed_number=1 end end
end
local function refreshDeedPileDescription(seatPos, zoneType)
	local playerStats=nil
	for _, details in pairs(turnOrder) do if details.seatPos==seatPos then playerStats=details break end end
	if playerStats==nil then return end
	local zoneGUID=zoneType=="deed" and deedDeckZones[seatPos] or deedDeckDiscardZones[seatPos]
	local zone=zoneGUID~=nil and getObjectFromGUID(zoneGUID) or nil
	if zone==nil then return end
	for _, deck in pairs(zone.getObjects()) do
		if deck.type=="Deck" or deck.type=="Card" then
			if playerStats.mage~=gStates.positionMageKnight[5] then
				for color, playerZone in pairs(gStates.handColors) do if playerZone==seatPos then deck.setGMNotes(color) break end end
			end
		local deckStats={	["Red"]={0, "{en}Red Card(s){ru}Красная(ых) карточка(и){zh-tw}紅色卡{zh-cn}红色卡{ko}빨간색 카드{es}Tarjeta(s) Roja{fr}Carte(s) Rouge{pt-br}Cartas Vermelhas{de}Rote Karten"},
														["Green"]={0, "{en}Green Card(s){ru}Зеленая(ых) карточка(и){zh-tw}綠色卡{zh-cn}绿色卡{ko}녹색 카드{es}Tarjeta(s) Verde{fr}Carte(s) Verte{pt-br}Cartas Verdes{de}Grüne Karten"},
														["Blue"]={0, "{en}Blue Card(s){ru}Синяя(ых) карточка(и){zh-tw}藍色卡{zh-cn}蓝色卡{ko}파란색 카드{es}Tarjeta(s) Azul{fr}Carte(s) Bleue{pt-br}Cartas Azuis{de}Blaue Karten"},
														["White"]={0, "{en}White Card(s){ru}Белая(ых) карточка(и){zh-tw}白色卡{zh-cn}白色卡{ko}흰색 카드{es}Tarjeta(s) Blanca{fr}Carte(s) Blanche{pt-br}Cartas Brancas{de}Weiße Karten"},
														["Starting"]={0, "{en}Basic Action(s){ru}Базовое(ых) действие(я){zh-tw}基本行動卡{zh-cn}基本行动卡{ko}기본 액션 카드{es}Acciones Básicas{fr}Action(s) de Base{pt-br}Ações Básicas{de}Basis Aktionen"},
														["Advanced Action"]={0, "{en}Advanced Action(s){ru}Особое(ые) действие(я){zh-tw}高級行動卡{zh-cn}高级行动卡{ko}상급 액션 카드{es}Acciones Avanzadas{fr}Action(s) Avancée{pt-br}Ações Avançadas{de}Erweiterte Aktionen"},
														["Spell"]={0, "{en}Spell(s){ru}Заклинание(я){zh-tw}法術卡{zh-cn}法术卡{ko}마법 카드{es}Hechizo(s){fr}Sort(s){pt-br}Feitiços{de}Zauber"},
														["Wound"]={0, "{en}Wound(s){ru}Рана(ы){zh-tw}創傷卡{zh-cn}创伤卡{ko}부상{es}Herida(s){fr}Blessure(s){pt-br}Ferimentos{de}Wunde(n)"},
														["Artifact"]={0, "{en}Artifact(s){ru}Артефакт(а){zh-tw}神器卡{zh-cn}神器卡{ko}유물{es}Artefacto(s){fr}Artefact(s){pt-br}Artefatos{de}Artefakt(e)"},
														["Move"]={0, "{en}Card(s) are Move{ru}Карта(ы) - это Движение{zh-tw}移動類卡牌{zh-cn}移动类卡牌{ko}장의 이동 카드{es}Las Cartas se Mueven{fr}Les cartes sont Mouvements{pt-br}Cartas são Movimento{de}Karte(n) sind Bewegung"},
														["Combat"]={0, "{en}Card(s) are Combat{ru}Карта(ы) - это Боевые{zh-tw}戰鬥類卡牌{zh-cn}战斗类卡牌{ko}장의 전투 카드{es}Las Cartas son de Combate{fr}Les cartes sont Combat{pt-br}Cartas são Combate{de}Karte(n) sind Angriff"},
														["Influence"]={0, "{en}Card(s) are Influence{ru}Карта(ы) - это Влияние{zh-tw}影響力卡牌{zh-cn}影响力卡牌{ko}장의 영향력 카드{es}Las Cartas tienen Influencia{fr}Les cartes sont Influence{pt-br}Cartas são Influência{de}Karte(n) sind Einfluss"},
														["Special"]={0, "{en}Card(s) are Special{ru}Карта(ы) - это Особая{zh-tw}特殊類卡牌{zh-cn}特殊类卡牌{ko}장의 특수효과 카드{es}Las Cartas son Especiales{fr}Les cartes sont Spéciales{pt-br}Cartas são Especiais{de}Karte(n) sind Spezial"},
														["Heal"]={0, "{en}Card(s) are Heal{ru}Карта(ы) - это Лечение{zh-tw}治療類卡牌{zh-cn}治疗类卡牌{ko}장의 치유 카드{es}Las Cartas se Curan{fr}Les cartes sont Guéries{pt-br}Cartas são Cura{de}Karte(n) sind Heilung"},
														["Action"]={0, "{en}Card(s) are Action{ru}Карта(ы) - это Действие{zh-tw}行動類卡牌{zh-cn}行动类卡牌{ko}장의 행동 카드{es}Las Cartas son Acción{fr}Les cartes sont des Actions{pt-br}Cartas são Ações{de}Karte(n) sind Aktionen"}}
									--count card types colours, and abilities
									local deedCards=deck.type=="Deck" and deck.getObjects() or {{guid=deck.guid}}
									local cardSearch={["deed"]=deedCards}
									deck.setName("{en}Deed Cards{ru}Колода Деяний{zh-tw}功能卡牌{zh-cn}功能卡牌{ko}행동 카드{es}Tarjetas de Escritura{fr}Cartes D'acte{pt-br}Cartas de Façanha{de}Handlungskarten")
									if zoneType=="deed" and playerStats.tactic==6 and gStates.dayRound==false and #gStates.powerStored>0 then
										cardSearch={["deed"]=deedCards, ["stored"]=gStates.powerStored}
										deck.setName(joinLang({"{en}Deed Cards +{ru}Карты Деяний +{zh-tw}功能卡牌 +{zh-cn}功能卡牌 +{ko}행동 카드 +{es}Tarjetas de Escritura +{fr}Cartes D'acte +{pt-br}Cartas de Façanha +{de}Handlungskarten +", #gStates.powerStored, "{en} Stored{ru} Сбережено{zh-tw} 已儲存{zh-cn} 已储存{ko} 장 저장됨{es} Almacenado{fr} Stockée{pt-br} Armazenada{de} Gelagert"}))
									end
									for _, cardpile in pairs(cardSearch) do
										for _, deedCard in pairs(cardpile) do
											if gameCards[deedCard.guid]~=nil and gameCards[deedCard.guid].cardType~="Regular Unit" and gameCards[deedCard.guid].cardType~="Elite Unit" then
												deckStats[gameCards[deedCard.guid].cardType][1]=deckStats[gameCards[deedCard.guid].cardType][1]+1
												for _, cardColor in pairs(gameCards[deedCard.guid].color) do deckStats[cardColor][1]=deckStats[cardColor][1]+1 end
												for _, cardAction in pairs(gameCards[deedCard.guid].action) do if cardAction~="Banner" then deckStats[cardAction][1]=deckStats[cardAction][1]+1 end end
											else
												deckStats["Wound"][1]=deckStats["Wound"][1]+1
											end
										end
									end
									--write a description
									local deckDescription=""
									for statName, statValue in pairs(deckStats) do
										if statValue[1]>0 then
											deckDescription=joinLang({deckDescription, statValue[1], " ", statValue[2], "\n"})
										end
										if statName=="White" or statName=="Artifact" then deckDescription=joinLang({deckDescription, "----------\n"}) end
									end
									deckDescription=joinLang({deckDescription, "----------"})
									deck.setDescription(deckDescription)
			break
		end
	end
end
function scheduleDeedPileDescriptionRefresh(seatPos, zoneType)
	local zoneGUID=zoneType=="deed" and deedDeckZones[seatPos] or deedDeckDiscardZones[seatPos]
	if zoneGUID==nil then return end
	if deckDescriptionWait[zoneGUID]~=nil then Wait.stop(deckDescriptionWait[zoneGUID]) end
	deckDescriptionWait[zoneGUID]=safeWaitTime("PlayerBoard.Deeds",function()
		deckDescriptionWait[zoneGUID]=nil
		refreshDeedPileDescription(seatPos, zoneType)
	end, 0.75)
end
function containerInsideDeckZone(container, zone)
	if container==nil or zone==nil then return false end
	for _, zoneObj in pairs(zone.getObjects()) do if zoneObj.guid==container.guid then return true end end
	--Zone membership can lag a deck merge by a frame, so use the zone bounds as a fallback.
	local pos=container.getPosition()
	local zonePos=zone.getPosition()
	local zoneScale=zone.getScale()
	return math.abs(pos[1]-zonePos[1])<=zoneScale[1]/2 and math.abs(pos[3]-zonePos[3])<=zoneScale[3]/2
end
function scheduleContainerDeckDescriptionRefresh(container)
	if container==nil or container.type~="Deck" then return end
	for _, details in pairs(turnOrder) do
		local seatPos=details.seatPos
		local deedZone=getObjectFromGUID(deedDeckZones[seatPos])
		if containerInsideDeckZone(container, deedZone)==true then scheduleDeedPileDescriptionRefresh(seatPos, "deed") return end
		local discardZone=getObjectFromGUID(deedDeckDiscardZones[seatPos])
		if containerInsideDeckZone(container, discardZone)==true then scheduleDeedPileDescriptionRefresh(seatPos, "discard") return end
	end
end

--Move cards visibly to a player's Deed deck without allowing two cards to converge on the same pile.
--Each seat owns its own queue, so different players can receive cards simultaneously.
deedTransferState={queues={},active={},transit={}}

function deedTransferBusy(seatPos)
	local queue=deedTransferState.queues[seatPos]
	return deedTransferState.active[seatPos]~=nil or (queue~=nil and #queue>0)
end

function deedTransferAnyBusy()
	for seatPos=1,4 do if deedTransferBusy(seatPos)==true then return true end end
	return false
end

function deedTransferPile(zone,ignoreGUID)
	if zone==nil then return nil end
	local single=nil
	for _, obj in pairs(zone.getObjects()) do
		if obj.guid~=ignoreGUID then
			if obj.type=="Deck" then return obj end
			if obj.type=="Card" then single=obj end
		end
	end
	return single
end

function deedTransferHomePosition(seatPos)
	return {-74.19+(40*(seatPos-1)),1.50,-43.16}
end

function deedTransferComplete(seatPos,entry,placed)
	deedTransferState.transit[entry.guid]=nil
	deedTransferState.active[seatPos]=nil
	local queue=deedTransferState.queues[seatPos]
	local transferFinished=false
	if queue~=nil then
		for index, queued in ipairs(queue) do
			if queued.guid==entry.guid then table.remove(queue,index) break end
		end
		if #queue==0 then deedTransferState.queues[seatPos]=nil transferFinished=true end
	else
		transferFinished=true
	end
	if transferFinished==true then rewindTransactionFinish("Deed transfer "..tostring(seatPos)) end
	if placed==true and turnOrder[entry.playerIndex]~=nil then
		turnOrder[entry.playerIndex].deedCount=(turnOrder[entry.playerIndex].deedCount or 0)+1
	end
	safeWaitFrames("PlayerBoard.Deeds",function() deedTransferProcess(seatPos) end,2)
end

function deedTransferFinishHover(seatPos,entry)
	local card=getObjectFromGUID(entry.guid)
	local zone=getObjectFromGUID(deedDeckZones[seatPos])
	if card==nil or zone==nil then deedTransferComplete(seatPos,entry,false) return end
	local pile=deedTransferPile(zone,entry.guid)
	if pile~=nil then
		local pilePos=pile.getPosition()
		local cardPos=card.getPosition()
		card.setPosition({pilePos[1],math.max(cardPos[2],pilePos[2]+1.0),pilePos[3]})
		pile.putObject(card)
		deedTransferComplete(seatPos,entry,true)
		return
	end
	--An empty Deed zone has no container to receive putObject. Smooth the first card down to the normal
	--deck home, then let the next queued card use that card as its pile.
	local home=deedTransferHomePosition(seatPos)
	card.setRotationSmooth({0,180,180})
	card.setPositionSmooth(home)
	safeWaitCondition("PlayerBoard.Deeds",function()
		deedTransferComplete(seatPos,entry,true)
	end,function()
		local moving=getObjectFromGUID(entry.guid)
		if moving==nil then return true end
		local pos=moving.getPosition()
		return moving.resting==true and math.abs(pos[1]-home[1])<0.25 and math.abs(pos[2]-home[2])<0.35 and math.abs(pos[3]-home[3])<0.25
	end,2.5,function()
		local moving=getObjectFromGUID(entry.guid)
		if moving~=nil then moving.setPosition(home) moving.setRotation({0,180,180}) end
		deedTransferComplete(seatPos,entry,moving~=nil)
	end)
end

function deedTransferProcess(seatPos)
	if deedTransferState.active[seatPos]~=nil then return end
	local queue=deedTransferState.queues[seatPos]
	if queue==nil or #queue==0 then return end
	local entry=queue[1]
	local card=getObjectFromGUID(entry.guid)
	local zone=getObjectFromGUID(deedDeckZones[seatPos])
	if card==nil or zone==nil then deedTransferComplete(seatPos,entry,false) return end
	deedTransferState.active[seatPos]=entry.guid
	deedTransferState.transit[entry.guid]=zone.guid
	local pile=deedTransferPile(zone,entry.guid)
	local target=pile~=nil and pile.getPosition() or deedTransferHomePosition(seatPos)
	local rotation=pile~=nil and pile.getRotation() or {0,180,180}
	local hover={target[1],target[2]+2.0,target[3]}
	card.setRotationSmooth(rotation)
	card.setPositionSmooth(hover)
	safeWaitCondition("PlayerBoard.Deeds",function()
		deedTransferFinishHover(seatPos,entry)
	end,function()
		local moving=getObjectFromGUID(entry.guid)
		if moving==nil then return true end
		local pos=moving.getPosition()
		return math.abs(pos[1]-hover[1])<0.35 and math.abs(pos[2]-hover[2])<0.5 and math.abs(pos[3]-hover[3])<0.35
	end,3.0,function()
		deedTransferFinishHover(seatPos,entry)
	end)
end

function queueCardToDeedDeck(playerIndex,card,rewindReady)
	if card==nil or turnOrder[playerIndex]==nil then return false end
	local seatPos=turnOrder[playerIndex].seatPos
	if seatPos==nil or deedDeckZones[seatPos]==nil or getObjectFromGUID(deedDeckZones[seatPos])==nil then return false end
	local guid=card.guid
	local queue=deedTransferState.queues[seatPos]
	if deedTransferState.active[seatPos]==guid then return true end
	if queue~=nil then for _, entry in ipairs(queue) do if entry.guid==guid then return true end end end
	--The transfer queue is runtime-only, so take the rewind point before lifting the first card. Closely
	--spaced claims for the same seat share this owner and are all allowed to queue behind the same snapshot.
	if rewindReady~=true then
		rewindTransactionStart(function() queueCardToDeedDeck(playerIndex,card,true) end,"Deed transfer "..tostring(seatPos))
		return true
	end
	card.unlock()
	card.UI.setXmlTable({{}})
	card.setScale({1.5,1,1.5})
	--Lift vertically before any horizontal movement. This clears Quest cards and offer cards, and gives the
	--ordinary source-zone leave callback a chance to resolve before transit suppression begins.
	local pos=card.getPosition()
	card.setPosition({pos[1],pos[2]+3.0,pos[3]})
	--Register immediately so closely spaced claims keep click order and other systems see this seat as busy
	--during the short lift delay. Horizontal transit does not begin until the source zone has had two frames.
	deedTransferState.queues[seatPos]=deedTransferState.queues[seatPos] or {}
	deedTransferState.queues[seatPos][#deedTransferState.queues[seatPos]+1]={guid=guid,playerIndex=playerIndex}
	safeWaitFrames("PlayerBoard.Deeds",function() deedTransferProcess(seatPos) end,2)
	return true
end

--Move's an offer or tactic card to a player's location
local fillWait=false
function claimMove(player, mouseButton, id, rewindReady)
	if mouseButton~="-3" then
		if legalPlayerCheck(player.color, turnOrder[gStates.turnNumber].seatPos)==true and turnOrder[gStates.turnNumber].mage~=gStates.positionMageKnight[5] then
			local claimedCard=getObjectFromGUID(id:sub(1, 6))
			if claimedCard~=nil then
				local source=id:sub(7, string.len(id))
				local cardClaimRewindOwner="Card claim "..tostring(claimedCard.guid)
				--Left-click card claims can update offers/rewards immediately while the physical card then travels
				--through the Deed-transfer queue. Protect the whole claim so a failed rewind-store never applies
				--the bookkeeping without also starting the physical transfer.
				if source~="unit" and mouseButton=="-1" and rewindReady~=true then
					if rewindTransactionOwnerActive(cardClaimRewindOwner)==true then return end
					rewindTransactionStart(function() claimMove(player,mouseButton,id,true) end,cardClaimRewindOwner)
					return
				end
				claimedCard.unlock()
				if source~="unit" then
					local tacticSource=source:sub(1, string.len(source)-1)=="tactic"
					if tacticSource==true then
						claimedCard.setPositionSmooth({(turnOrder[gStates.turnNumber].seatPos*40)-117.83 , 3.0, -43.16})
					elseif mouseButton=="-1" then
						queueCardToDeedDeck(gStates.turnNumber,claimedCard)
					else
						claimedCard.setPosition({claimedCard.getPosition()[1], claimedCard.getPosition()[2]+3, claimedCard.getPosition()[3]})
					end
					cardClaim=true
					safeWaitTime("PlayerBoard.Deeds",function() cardClaim=false end, 2)
					--add decal to tactic if playing Ultimate Conquest
					if gStates.gameScenario=="Ultimate Conquest" then
						for _, mage2 in pairs(mageKnights) do
							if mage2.mage==turnOrder[gStates.turnNumber].mage then
								local posX=-1*((turnOrder[gStates.turnNumber].seatPos*0.34)-0.85)
								safeWaitTime("PlayerBoard.Deeds",function()
									claimedCard.addDecal({name="Used Already Shield", url=mage2.shieldImage,
									position={posX, 0.11, -0.9}, rotation={90.0, 180.0, 0.0}, scale={0.4, 0.4, 1}})
								end, 1)
							end
						end
					end
					--Left-click Deed claims are handled by the serialized smooth-transfer queue above. Preserve the
					--existing alternate claim action and tactic destination exactly as before.
					if mouseButton=="-2" and tacticSource~=true then
						claimedCard.setPositionSmooth({(turnOrder[gStates.turnNumber].seatPos*40)-105.0 , 4.59, -47.55})
					elseif mouseButton~="-1" and tacticSource~=true then
						claimedCard.flip()
						claimedCard.setPositionSmooth({(turnOrder[gStates.turnNumber].seatPos*40)-114.19 , 3.0, -43.16})
					end
					if source=="offer" and fillWait==false then fillWait=true safeWaitTime("PlayerBoard.Deeds",function() fillSlide() fillWait=false end, 1.2) end
					if source=="artifactReward" then
						if turnOrder[gStates.turnNumber].avatarLocation:sub(1, 4)=="city" then gStates.theGauntletArtifactClaimed=true end
						gStates.dealtArtifacts[id:sub(1, 6)]=false
						claimedCard.UI.setXmlTable({{}})
						local remainingGUID={}
						for GUID, state in pairs(gStates.dealtArtifacts) do if state==true then remainingGUID[#remainingGUID+1]=GUID end end
						if #remainingGUID==1 then
							--return last card
							local PosOrigin=getObjectFromGUID(GUID.deck.artifact).getPosition()
							getObjectFromGUID(GUID.deck.artifact).setPositionSmooth({getObjectFromGUID(GUID.deck.artifact).getPosition()[1], getObjectFromGUID(GUID.deck.artifact).getPosition()[2]+2, getObjectFromGUID(GUID.deck.artifact).getPosition()[3]})
							standardDeckCycleMarkReturned("Artifact", getObjectFromGUID(remainingGUID[1]))
							getObjectFromGUID(remainingGUID[1]).unlock()
							getObjectFromGUID(remainingGUID[1]).setRotation({0, 180, 180})
							getObjectFromGUID(remainingGUID[1]).setPositionSmooth(PosOrigin)
							getObjectFromGUID(remainingGUID[1]).UI.setXmlTable({{}})
							--reset buttons
							getObjectFromGUID(GUID.deck.artifact).UI.setAttribute("ac75c4ArtifactDown", "active", "true")
							getObjectFromGUID(GUID.deck.artifact).UI.setAttribute("ac75c4ArtifactOffer", "active", "true")
							getObjectFromGUID(GUID.deck.artifact).UI.setAttribute("ac75c4ArtifactUp", "active", "true")
							gStates.artifactRewards=1
							gStates.dealtArtifacts=nil
							getObjectFromGUID(GUID.deck.artifact).UI.setAttribute("ac75c4ArtifactOfferText", "text", joinLang({"{en}Reward {ru}Награда {zh-tw}獎勵{zh-cn}奖励{ko}보상 {es}Premiar {fr}Reward {pt-br}Premiar {de}Belohnung ", gStates.artifactRewards}))
						end
					end
					if gameCards[claimedCard.guid]~=nil and source~="artifactReward" then
						broadcastToAll(joinLang({translateWord[turnOrder[gStates.turnNumber].mage], "{en} gained {ru} получает {zh-cn}增加了{ko}의 획득:  {es} ganó {fr} a subi {pt-br} ganhou {de} gewonnen ", gameCards[claimedCard.guid].name[1], "."}), positionToColor(gStates.turnNumber))
					else
						broadcastToAll(joinLang({translateWord[turnOrder[gStates.turnNumber].mage], "{en} gained {ru} получает {zh-cn}增加了{ko}의 획득:  {es} ganó {fr} a subi {pt-br} ganhou {de} gewonnen ", getObjectFromGUID(claimedCard.guid).getName(), "."}), positionToColor(gStates.turnNumber))
					end
				else
					if fillWait==false then--Move the Unit card to an empty command-source column
						local seatPos=turnOrder[gStates.turnNumber].seatPos
						local slot, unitX, commandSource, layout=unitLayoutFirstFreeCommand(seatPos)
						local found=slot~=nil
						if found==true then
							local scale=unitLayoutCardScale(#layout.commands)
							claimedCard.setScale({scale,1,scale})
							claimedCard.setPositionSmooth({unitX,2.0,-34.74})
							fillWait=true
							safeWaitFrames("PlayerBoard.Deeds",function() safeWaitCondition("PlayerBoard.Deeds",function() fillWait=false scheduleUnitLayoutRefresh(seatPos) end, function() return claimedCard.resting end) end,5)
							if gameCards[claimedCard.guid]~=nil then
								broadcastToAll(joinLang({translateWord[turnOrder[gStates.turnNumber].mage], "{en} gained {ru} получает {zh-cn}增加了{ko}의 획득:  {es} ganó {fr} a subi {pt-br} ganhou {de} gewonnen ", gameCards[claimedCard.guid].name[1], "."}), positionToColor(gStates.turnNumber))
							end
						end
						if found==false then broadcastToAll("{en}You have no free command tokens to enlist another unit{ru}У вас нет свободного жетона командования, чтобы нанять еще один отряд{zh-cn}你没有闲置的位置招募新部队{ko}유닛을 고용할 지휘 토큰이 부족합니다{es}No tienes fichas de mando gratuitas para alistar otra unidad{fr}Vous n'avez pas de jetons de commande gratuits pour enrôler une autre unité{pt-br}Você não tem Fichas de Comando livres para recrutar outra unidade{de}Du hast keine freien Befehlsmarken, um eine andere Einheit anzuwerben.", warningColor) end
						--Warn only after the normal location rules plus conquered Camp-as-City proximity are checked.
						if gameCards[claimedCard.guid]~=nil and unitRecruitableAtCurrentLocation(gStates.turnNumber,claimedCard)~=true then
							broadcastToAll("{en}Claimed Unit normally isn't recruited from the location you're currently at.{ru}Забранный Отряд обычно не нанимается из того места, где вы в данный момент находитесь.{zh-cn}你所在的位置通常不能招募这个部队{ko}보통은, 그 유닛을 현재 장소에서 고용할 수 없습니다{es}La Unidad reclamada normalmente no se recluta en la ubicación en la que se encuentra actualmente.{fr}L'Unité réclamée n'est normalement pas recrutée à l'endroit où vous vous trouvez actuellement.{pt-br}Unidade Clamada normalmente não é recrutada da localização que você está agora.{de}Die beanspruchte Einheit wird normalerweise nicht von dem Ort rekrutiert, an dem Sie sich gerade befinden.", positionToColor(gStates.turnNumber))
						end
					else
						broadcastToAll("{en}Let the last card settle before claiming the next unit.{ru}Не спешите. Позвольте предыдущей карте переместиться, прежде чем брать следующую.{zh-cn}征召下一个部队前, 把上一个结算清{ko}이전 유닛이 완전히 놓일 때 까지 기다려주세요{es}Deje que la última carta se asiente antes de reclamar la siguiente unidad.{fr}Laissez la dernière carte s'installer avant de réclamer l'unité suivante.{pt-br}Deixe a última carta se encaixar antes de clamar a próxima unidade.{de}Lassen Sie die letzte Karte ruhen, bevor Sie die nächste Einheit beanspruchen.", warningColor)
					end
				end
				--activate some of the tactics effects.
				if source:sub(1, string.len(source)-1)=="tactic" then
					turnOrder[gStates.turnNumber].tactic=tonumber(source:sub(7, string.len(source)))
					if gStates.dayRound==true and turnOrder[gStates.turnNumber].tactic==5 then
						drawExactDeedCards(gStates.turnNumber, 2, "DrawOne")
					end
					if gStates.dayRound==true and turnOrder[gStates.turnNumber].tactic==2 then
						safeWaitTime("PlayerBoard.Deeds",function() dayTactic2ButtonActivate() end, 2)--activate after the tactic card finishes moving to the player area
					end
					nextTurnMerged("incrementTurn")
				end
				if rewindReady==true then safeWaitTime("PlayerBoard.Deeds",function() rewindTransactionFinish(cardClaimRewindOwner) end,1.5) end
			end
		else
			if turnOrder[gStates.turnNumber].mage==gStates.positionMageKnight[5] then
				if turnOrder[gStates.turnNumber].mage=="Volkare" then
					broadcastToAll("{en}Volkare doesn't claim cards{ru}Волкар не берет карты{zh-cn}傻孩子, 沃里卡不选卡{ko}볼케어는 카드를 획득하지 않습니다{es}Volkare no reclama cartas{fr}Volkare ne réclame pas de cartes{pt-br}Volkare não clama cartas{de}Volkare beansprucht keine Karten", warningColor)
				else
					broadcastToAll("{en}Dummy doesn't claim cards this way{ru}Виртуальный игрок не получает карты таким образом{zh-cn}虚拟玩家不会这样选卡{ko}가상 플레이어는 카드를 이런 방식으로 얻지 않습니다{es}El muñeco no reclama cartas de esta manera{fr}Le mannequin ne réclame pas les cartes de cette façon{pt-br}Jog. Fictício não clama cartas desta forma{de}Dummy beansprucht auf diese Weise keine Karten", warningColor)
				end
			end
		end
	end
end

function coralQuickWittedSetAside(playerIndex)
	local playerDetails=turnOrder[playerIndex]
	if playerDetails==nil or playerDetails.mage~="Coral" or playerDetails.mage==gStates.positionMageKnight[5] or playerDetails.dropoutState~=nil then return nil end
	local deedZone=getObjectFromGUID(deedDeckZones[playerDetails.seatPos])
	if deedZone==nil then return nil end
	for _, obj in pairs(deedZone.getObjects()) do
		if obj.type=="Deck" and obj.getQuantity()>1 then
			for _, cardData in pairs(obj.getObjects()) do if cardData.guid=="6ecbc6" then return obj end end
		end
	end
	return nil
end

--Returns Quick Witted only when it has become Coral's lone physical Deed card.
function coralQuickWittedLastDeedCard(playerIndex)
	local playerDetails=turnOrder[playerIndex]
	if playerDetails==nil or playerDetails.mage~="Coral" or playerDetails.mage==gStates.positionMageKnight[5] or playerDetails.dropoutState~=nil then return nil end
	local deedZone=getObjectFromGUID(deedDeckZones[playerDetails.seatPos])
	if deedZone==nil then return nil end
	for _, obj in pairs(deedZone.getObjects()) do if obj.type=="Card" and obj.guid=="6ecbc6" then return obj end end
	return nil
end

coralDrawPending=nil
local coralDrawBypass=false
local coralDrawExactCount=nil

--Quick Witted prompts can remain open while turnOrder is re-sorted. Resolve Coral by her fixed board seat instead of a stale turnOrder index.
local function coralDrawPlayerIndex(seatPos)
	for playerIndex, playerDetails in pairs(turnOrder) do
		if playerDetails.mage=="Coral" and playerDetails.seatPos==seatPos and playerDetails.mage~=gStates.positionMageKnight[5] and playerDetails.dropoutState==nil then return playerIndex end
	end
	return nil
end

function showCoralDrawChoice(playerIndex, drawCount, sourceId)
	if drawCount<1 or turnOrder[playerIndex]==nil then return end
	local seatPos=turnOrder[playerIndex].seatPos
	if coralDrawPending~=nil and coralDrawPending.seatPos==seatPos then
		coralDrawPending.remaining=coralDrawPending.remaining+drawCount
		drawCount=coralDrawPending.remaining
	else
		coralDrawPending={seatPos=seatPos, remaining=drawCount, sourceId=sourceId}
	end
	UI.setAttribute("CoralDrawChoiceQuestion", "text", tostring(drawCount).." card draw"..(drawCount==1 and "" or "s").." remaining. Replace one draw with Quick Witted?")
	UI.setAttribute("CoralDrawFullPanel", "active", drawCount>1 and "true" or "false")
	UI.setAttribute("CoralDrawChoice", "visibility", positionToColor(playerIndex).."|Black")
	UI.show("CoralDrawChoice")
end

function clearCoralDrawChoice()
	coralDrawPending=nil
	UI.hide("CoralDrawChoice")
end

--A Coral draw can turn a Deck into a lone Card or rebuild it after a manual draw is intercepted.
--Refresh from the scripting zone after TTS has settled so hover text/counts describe the final physical pile.
local function coralScheduleDeedRefresh(seatPos, delayFrames)
	safeWaitFrames("PlayerBoard.Deeds",function()
		scheduleDeedPileDescriptionRefresh(seatPos, "deed")
		scheduleEndRoundDeedStateRefresh(seatPos)
	end, delayFrames or 4)
end

--Returns Coral's player index only when this object is her physical Deed Deck and Quick Witted is still available inside it.
function coralManualQuickWittedDeck(object)
	if object==nil or object.type~="Deck" then return nil end
	for playerIndex, playerDetails in pairs(turnOrder) do
		if playerDetails.mage=="Coral" and playerDetails.mage~=gStates.positionMageKnight[5] and playerDetails.dropoutState==nil then
			local deedDeck=coralQuickWittedSetAside(playerIndex)
			if deedDeck~=nil and deedDeck.guid==object.guid then return playerIndex end
			return nil
		end
	end
	return nil
end

--A manual top-card draw creates a Card from the Deck; onPlayerAction therefore does not reliably see the Deck.
--Use the exact container-leave event instead, then check held_by_color a few frames later to distinguish a player drag from scripted draws.
function coralManualQuickWittedLeaveSource(container)
	if container==nil or container.type~="Deck" then return nil end
	for playerIndex, playerDetails in pairs(turnOrder) do
		if playerDetails.mage=="Coral" and playerDetails.mage~=gStates.positionMageKnight[5] and playerDetails.dropoutState==nil then
			local deedZone=getObjectFromGUID(deedDeckZones[playerDetails.seatPos])
			if deedZone==nil then return nil end
			local inDeedZone=false
			for _, zoneObj in pairs(deedZone.getObjects()) do
				if zoneObj.guid==container.guid then inDeedZone=true break end
			end
			if inDeedZone==false then return nil end
			for _, cardData in pairs(container.getObjects()) do
				if cardData.guid=="6ecbc6" then return playerIndex end
			end
			if container.remainder~=nil and container.remainder.guid=="6ecbc6" then return playerIndex end
			return nil
		end
	end
	return nil
end

function coralRestoreManualDraw(playerIndex, deckGuid, card, showChoice)
	if playerIndex==nil or card==nil or card.isDestroyed() then return end
	local seatPos=turnOrder[playerIndex].seatPos
	card.drop()
	safeWaitFrames("PlayerBoard.Deeds",function()
		if card==nil or card.isDestroyed() then return end
		local destination=getObjectFromGUID(deckGuid)
		if destination==nil or destination.type~="Deck" then
			local deedZone=getObjectFromGUID(deedDeckZones[seatPos])
			if deedZone~=nil then
				for _, obj in pairs(deedZone.getObjects()) do
					if obj.guid~=card.guid and (obj.type=="Deck" or obj.type=="Card") then
						destination=obj
						if obj.guid=="6ecbc6" then break end
					end
				end
			end
		end
		if destination==nil or destination.isDestroyed() then return end
		destination.putObject(card)
		coralScheduleDeedRefresh(seatPos, 3)
		if showChoice~=false then safeWaitFrames("PlayerBoard.Deeds",function()
			local currentPlayerIndex=coralDrawPlayerIndex(seatPos)
			if currentPlayerIndex~=nil and coralDrawPending==nil then showCoralDrawChoice(currentPlayerIndex, 1, "DrawOne") end
		end, 5) end
	end, 1)
end

local function coralRunNormalDraw(playerIndex, id, exactCount)
	local previousTurn=gStates.turnNumber
	gStates.turnNumber=playerIndex
	coralDrawBypass=true
	coralDrawExactCount=exactCount
	drawUpTo({color="Black"}, "-1", id)
	coralDrawExactCount=nil
	coralDrawBypass=false
	gStates.turnNumber=previousTurn
end

--Object scripts such as Day Tactic 2 can route Coral draws through the same Quick Witted-aware draw path.
--Track the whole external draw flow, including the few frames where Draw One temporarily closes and then reopens the choice.
local coralExternalDrawSeat=nil
local coralExternalDrawFinishPause=nil
local function coralFinishExternalDraw(seatPos, delayFrames)
	if coralExternalDrawSeat~=seatPos then return end
	if coralExternalDrawFinishPause~=nil then Wait.stop(coralExternalDrawFinishPause) end
	coralExternalDrawFinishPause=safeWaitFrames("PlayerBoard.Deeds",function()
		coralExternalDrawFinishPause=nil
		if coralExternalDrawSeat==seatPos then coralExternalDrawSeat=nil end
	end, delayFrames or 10)
end

function coralExternalQuickWittedDraw(params)
	if params==nil then return end
	local playerIndex=coralDrawPlayerIndex(params.seatPos)
	if playerIndex==nil then return end
	coralExternalDrawSeat=params.seatPos
	local previousTurn=gStates.turnNumber
	gStates.turnNumber=playerIndex
	coralDrawExactCount=tonumber(params.count) or 1
	drawUpTo({color="Black"}, "-1", params.sourceId or "DrawOne")
	coralDrawExactCount=nil
	gStates.turnNumber=previousTurn
	if coralDrawPending==nil or coralDrawPending.seatPos~=params.seatPos then coralFinishExternalDraw(params.seatPos, 10) end
end

function coralExternalDrawPending(params)
	return params~=nil and coralExternalDrawSeat==params.seatPos
end

--Run a scripted exact-count Deed draw as one operation. Coral uses the tracked external
--Quick Witted flow; every other Mage Knight uses the same exact-count draw engine without a prompt.
function drawExactDeedCards(playerIndex, count, sourceId)
	local details=turnOrder[playerIndex]
	count=tonumber(count) or 0
	if details==nil or count<1 then return end
	if details.mage=="Coral" and details.mage~=gStates.positionMageKnight[5] and details.dropoutState==nil then
		coralExternalQuickWittedDraw({seatPos=details.seatPos, count=count, sourceId=sourceId or "DrawOne"})
	else
		coralRunNormalDraw(playerIndex, sourceId or "DrawOne", count)
	end
end

--Night Tactic 4 needs a single multi-card draw request so Coral sees the normal Quick Witted choice,
--including Draw Full, instead of several one-card requests competing with the pending prompt.
function coralTactic4Draw(playerIndex, exactCount)
	local previousTurn=gStates.turnNumber
	gStates.turnNumber=playerIndex
	coralDrawExactCount=exactCount
	drawUpTo({color="Black"}, "-1", "DrawOne")
	coralDrawExactCount=nil
	gStates.turnNumber=previousTurn
end

local function coralTakeQuickWitted(playerIndex)
	local deedDeck=coralQuickWittedSetAside(playerIndex)
	if deedDeck==nil then return false end
	local playerPosition=turnOrder[playerIndex].seatPos
	safeTakeObject("PlayerBoard.Deeds",deedDeck,{guid="6ecbc6", position={(playerPosition*40)-105, 4.59, -47.55}, rotation={0, 180, 0}, smooth=false, callback_function=function(card) card.setScale({1.5, 1, 1.5}) end})
	turnOrder[playerIndex].deedCount=math.max(0,(turnOrder[playerIndex].deedCount or 0)-1)
	coralScheduleDeedRefresh(playerPosition, 4)
	return true
end

function coralDrawChoice(player, mouseButton, id)
	if mouseButton~="-1" or coralDrawPending==nil or player==nil then return end
	local pending=coralDrawPending
	local playerIndex=coralDrawPlayerIndex(pending.seatPos)
	local playerDetails=playerIndex~=nil and turnOrder[playerIndex] or nil
	if playerDetails==nil or legalPlayerCheck(player.color, pending.seatPos, "NoDummyException")~=true then return end
	if id=="CoralDrawQuickWitted" then
		UI.hide("CoralDrawChoice")
		coralDrawPending=nil
		if coralTakeQuickWitted(playerIndex)==true then
			pending.remaining=pending.remaining-1
			if pending.remaining>0 then safeWaitFrames("PlayerBoard.Deeds",function()
				local currentIndex=coralDrawPlayerIndex(pending.seatPos)
				if currentIndex~=nil then coralRunNormalDraw(currentIndex, pending.sourceId, pending.remaining) end
			end, 2) end
		else
			coralRunNormalDraw(playerIndex, pending.sourceId, pending.remaining)
		end
		coralScheduleDeedRefresh(pending.seatPos, 4)
		if coralExternalDrawSeat==pending.seatPos then coralFinishExternalDraw(pending.seatPos, 10) end
	elseif id=="CoralDrawOne" then
		--Keep the choice visible while the single card is dealt; temporarily clear pending input so repeated clicks cannot queue extra draws.
		coralDrawPending=nil
		coralRunNormalDraw(playerIndex, "DrawOne", 1)
		pending.remaining=pending.remaining-1
		if pending.remaining>0 then
			--A few frames is enough for TTS to remove the drawn card from the Deck and update zone contents.
			safeWaitFrames("PlayerBoard.Deeds",function()
				local currentIndex=coralDrawPlayerIndex(pending.seatPos)
				if currentIndex==nil then UI.hide("CoralDrawChoice") return end
				--If the last normal card was just drawn, Quick Witted has become the physical Deed Deck and the remaining draw is mandatory.
				if coralQuickWittedSetAside(currentIndex)==nil then
					UI.hide("CoralDrawChoice")
					coralRunNormalDraw(currentIndex, pending.sourceId, pending.remaining)
					if coralExternalDrawSeat==pending.seatPos then coralFinishExternalDraw(pending.seatPos, 10) end
				else
					showCoralDrawChoice(currentIndex, pending.remaining, pending.sourceId)
				end
			end, 4)
		else
			UI.hide("CoralDrawChoice")
			if coralExternalDrawSeat==pending.seatPos then coralFinishExternalDraw(pending.seatPos, 10) end
		end
		coralScheduleDeedRefresh(pending.seatPos, 5)
	elseif id=="CoralDrawFull" then
		UI.hide("CoralDrawChoice")
		coralDrawPending=nil
		coralRunNormalDraw(playerIndex, pending.sourceId, pending.remaining)
		coralScheduleDeedRefresh(pending.seatPos, 5)
		if coralExternalDrawSeat==pending.seatPos then coralFinishExternalDraw(pending.seatPos, 10) end
	end
end

--Draw cards from a deed deck into that positions hand
cardClaim=false
function drawUpTo(player, mouseButton, id)
	if mouseButton=="-1" then
		local playerPosition=turnOrder[gStates.turnNumber].seatPos
		if legalPlayerCheck(player.color, playerPosition)==true then
			if deedTransferBusy(playerPosition)==true then
				safeWaitCondition("PlayerBoard.Deeds",function() drawUpTo(player,mouseButton,id) end,function() return deedTransferBusy(playerPosition)~=true end,10,function() drawUpTo(player,mouseButton,id) end)
				return
			end
			local meditationBonus=0
			if id=="DrawHand" and gStates.meditationDrawBonus~=nil then
				meditationBonus=gStates.meditationDrawBonus[gStates.turnNumber] or 0
				if meditationBonus>0 then
					gStates.meditationDrawBonus[gStates.turnNumber]=nil
					safeWaitFrames("PlayerBoard.Deeds",function() mainUIUpdate("Meditation Draw Bonus Used") end, 1)
				end
			end
			local deedDeck=nil
			for _, possibleDeck in pairs(getObjectFromGUID(deedDeckZones[playerPosition]).getObjects()) do
				if possibleDeck.type=="Deck" or possibleDeck.type=="Card" then deedDeck=possibleDeck break end
			end
			--Quick Witted is already physically in Coral's Deed Deck; when it is the final card it resolves as a normal single-card Deed Deck.
			if deedDeck~=nil or (id=="DrawHand" and turnOrder[gStates.turnNumber].tactic==2 and gStates.dayRound==false and gStates.tacticTwoState~="Used" and turnOrder[gStates.turnNumber].mage~=gStates.positionMageKnight[5]) then
				local cardsInHand=0
				local handSize=turnOrder[gStates.turnNumber].hand+turnOrder[gStates.turnNumber].handBonus+gStates.tactic4HandBonus+meditationBonus
				if id=="DrawHand" then
					for _, possibleCards in pairs(getObjectFromGUID(handZones[playerPosition]).getObjects()) do if possibleCards.type=="Card" then cardsInHand=cardsInHand+1 end end
				else--Draw one
					cardsInHand=handSize-1
				end
				local drawNeeded=coralDrawExactCount or (handSize-cardsInHand)
				if drawNeeded>0 then
					local turnAffected=gStates.turnNumber
					--While normal Deed cards remain, Coral may replace any individual card draw with Quick Witted.
					if coralDrawBypass==false and deedDeck~=nil and coralQuickWittedSetAside(turnAffected)~=nil then
						showCoralDrawChoice(turnAffected, drawNeeded, id)
						return
					end
					function drawCardstoHand()
						local excess=drawNeeded
						local deckPos={-74.19+(40*(turnOrder[turnAffected].seatPos-1)), 1.50, -43.16}
						if deedDeck~=nil then
							if deedDeck.type=="Deck" then
								local deckQuantity=deedDeck.getQuantity()
								local drawNow=math.min(drawNeeded, deckQuantity)
								excess=drawNeeded-drawNow
								local deckTakes=drawNow
								local takeRemainder=drawNow==deckQuantity
								if takeRemainder==true then deckTakes=math.max(0,deckQuantity-1) end
								for x=1, deckTakes do
									local drawn=deedDeck.takeObject({position={(playerPosition*40)-105-(x*0.2), 4.59, -47.55}, rotation={0, 180, 0}})
									if drawn~=nil then turnOrder[turnAffected].deedCount=math.max(0,(turnOrder[turnAffected].deedCount or 0)-1) end
								end
								if takeRemainder==true then
									safeWaitFrames("PlayerBoard.Deeds",function()
										local deedZone=getObjectFromGUID(deedDeckZones[turnOrder[turnAffected].seatPos])
										if deedZone==nil then return end
										for _, remainder in pairs(deedZone.getObjects()) do
											if remainder.type=="Card" then
												remainder.setScale({1.5, 1, 1.5})
												remainder.setPositionSmooth({(playerPosition*40)-105-(drawNow*0.2), 4.59, -47.55})
												remainder.setRotationSmooth({0, 180, 0})
												turnOrder[turnAffected].deedCount=math.max(0,(turnOrder[turnAffected].deedCount or 0)-1)
												break
											end
										end
										coralScheduleDeedRefresh(turnOrder[turnAffected].seatPos, 3)
									end, 2)
								end
							else
								excess=drawNeeded-1
								deedDeck.setScale({1.5, 1, 1.5})
								deedDeck.setPositionSmooth({(playerPosition*40)-105, 4.59, -47.55})
								deedDeck.setRotationSmooth({0, 180, 0})
								turnOrder[turnAffected].deedCount=math.max(0,(turnOrder[turnAffected].deedCount or 0)-1)
							end
							coralScheduleDeedRefresh(turnOrder[turnAffected].seatPos, 4)
						end
						cardClaim=false
						safeWaitFrames("PlayerBoard.Deeds",function()
							safeWaitTime("PlayerBoard.Deeds",function()
								--Night tactic 2 grab three random discards back to deck if draw will reduce to 0.
								if id=="DrawHand" and excess>0 and gStates.endRoundCalled==false and turnOrder[turnAffected].tactic==2 and gStates.dayRound==false and gStates.tacticTwoState~="Used" and turnOrder[turnAffected].mage~=gStates.positionMageKnight[5] then
									for _, discards in pairs(getObjectFromGUID(deedDeckDiscardZones[playerPosition]).getObjects()) do
										if discards.type=="Deck" then
											discards.shuffle()
											safeWaitTime("PlayerBoard.Deeds",function()
												discards.takeObject({position=deckPos, smooth=true, rotation={0, 180, 180}})
												discards.takeObject({position=deckPos, smooth=true, rotation={0, 180, 180}})
												discards.takeObject({position=deckPos, smooth=true, rotation={0, 180, 180}})
												safeWaitTime("PlayerBoard.Deeds",function()
													for _, possibleDeck in pairs(getObjectFromGUID(deedDeckZones[playerPosition]).getObjects()) do
														if possibleDeck.type=="Deck" then
															for x=1, excess, 1 do possibleDeck.takeObject({position={(playerPosition*40)-105-(x*0.2), 4.59, -47.55}, rotation={0, 180, 0}}) end
															break
														end
													end
												end, 1)
											end, 1)
											break
										end
									end
									gStates.tacticTwoState="Used"
									if getObjectFromGUID("f6ad01")~=nil and getObjectFromGUID("f6ad01").is_face_down==false then getObjectFromGUID("f6ad01").flip() end
									broadcastToAll("{en}Night Tactic Two was used to refill Deed Deck with 3 Random discards{ru}Ночная Тактика 2 была использована для замешивания 3 карт из сброса в Колоду деяний{zh-cn}使用夜间战术卡2随机弃了3张牌{ko}밤 전략 카드 2가 사용되었습니다{es}La Segunda Táctica Nocturna se utilizó para rellenar el Deed Deck con 3 descartes aleatorios.{fr}Nuit Tactic Deux a été utilisé pour remplir Deed Deck avec 3 défausse aléatoires{pt-br}Tática da Noite 2 foi usada para recarregar o Baralho de Feitos com 3 Cartas Aleatórias{de}Nachttaktik Zwei wurde benutzt, um das Tatendeck mit 3 zufälligen Abwürfen aufzufüllen", positionToColor(turnAffected))
								end
							end, 0.5)
						end, 2)
					end
					if cardClaim==true then safeWaitTime("PlayerBoard.Deeds",function() drawCardstoHand() end, 1.5) else drawCardstoHand() end--make sure the card has entered the deck
				end
		    end
		end
	end
end

--True once there is no real Coral player, or Quick Witted is physically back in Coral's Deed Deck.
function coralQuickWittedReadyForDraw()
	for _, playerDetails in pairs(turnOrder) do
		if playerDetails.mage=="Coral" and playerDetails.mage~=gStates.positionMageKnight[5] and playerDetails.dropoutState==nil then
			local deedZone=getObjectFromGUID(deedDeckZones[playerDetails.seatPos])
			if deedZone==nil then return false end
			for _, obj in pairs(deedZone.getObjects()) do
				if obj.type=="Card" and obj.guid=="6ecbc6" then return true end
				if obj.type=="Deck" then for _, cardData in pairs(obj.getObjects()) do if cardData.guid=="6ecbc6" then return true end end end
			end
			return false
		end
	end
	return true
end

--Starting Deed Decks are taken from bags and shuffled asynchronously. Deal only after every active
--Mage Knight's complete Deed pile is registered in its scripting zone and has finished moving.
function startingDeedDecksReadyForDraw()
	for playerIndex, playerDetails in ipairs(turnOrder) do
		if playerDetails.mage~=gStates.positionMageKnight[5] and playerDropoutInactive(playerIndex)==false then
			local deedZone=getObjectFromGUID(deedDeckZones[playerDetails.seatPos])
			if deedZone==nil then return false end
			local deedPileFound=false
			for _, obj in pairs(deedZone.getObjects()) do
				if obj.type=="Deck" or obj.type=="Card" then
					deedPileFound=true
					if obj.resting~=true then return false end
				end
			end
			if deedPileFound==false then return false end
		end
	end
	return true
end

--Replace the old four-second setup cushion with actual Deck readiness. Coral preparation runs once
--after all Deed Decks exist; the timeout retains a final fallback if TTS never reports a settled state.
function dealStartingHandsWhenReady()
	local coralPrepared=false
	local function finishStartingHandsDeal()
		dealAllHands()
		--Give the dealt cards a few frames to leave their Deck objects before automatic rewind snapshots resume.
		safeWaitFrames("PlayerBoard.Deeds",function() rewindTransactionFinish("Game setup") end,15)
	end
	safeWaitCondition("PlayerBoard.Deeds",finishStartingHandsDeal, function()
		if startingDeedDecksReadyForDraw()==false then return false end
		if coralPrepared==false then
			coralPrepared=true
			coralSetAsideQuickWitted()
			return false
		end
		return coralQuickWittedReadyForDraw()
	end, 10, function()
		coralSetAsideQuickWitted()
		safeWaitFrames("PlayerBoard.Deeds",finishStartingHandsDeal, 5)
	end)
end

--Meditation / Trance card smarts. Top/Bot starts as Meditation; adding discard cards to the Deed Deck tells the script Trance was powered.
meditationTranceCardGUID="2eb8d0"
local function meditationPlayerIndex(card)
	if card==nil then return nil end
	for playerIndex, details in pairs(turnOrder) do
		local area=details.seatPos~=nil and getObjectFromGUID(playerPlayAreas[details.seatPos]) or nil
		if area~=nil then for _, obj in pairs(area.getObjects()) do if obj.guid==card.guid then return playerIndex end end end
	end
	return nil
end
local function meditationDiscardSnapshot(playerIndex)
	local cards={}
	local zone=turnOrder[playerIndex]~=nil and getObjectFromGUID(deedDeckDiscardZones[turnOrder[playerIndex].seatPos]) or nil
	if zone==nil then return cards end
	for _, obj in pairs(zone.getObjects()) do
		if obj.type=="Card" then cards[obj.guid]=true
		elseif obj.type=="Deck" then for _, data in pairs(obj.getObjects()) do cards[data.guid]=true end end
	end
	return cards
end
local function meditationCardCount(cards)
	local count=0
	for _, _ in pairs(cards or {}) do count=count+1 end
	return count
end
--Card-effect controls are only shown while the card is essentially vertical.
--Read the card's settled world rotation rather than inferring orientation from Q/E presses.
--The 10 degree tolerance is intentionally below TTS's normal 15 degree rotation step.
function cardEffectIsVertical(card)
	if card==nil then return false end
	local rotation=card.getRotation()
	local y=((rotation~=nil and rotation[2]) or 0)%180
	return math.min(y,180-y)<=10
end
local function meditationStripXmlButtons(card)
	local xml=card.UI.getXmlTable() or {}
	for a=#xml, 1, -1 do
		local id=xml[a].attributes~=nil and xml[a].attributes.id or nil
		if id=="MeditationTranceTop" or id=="MeditationTranceBot" or id==card.guid.."meditationTop" or id==card.guid.."meditationBot" or id==card.guid.."tranceTop" or id==card.guid.."tranceBot" then table.remove(xml,a) end
	end
	return xml
end
local function meditationRemoveButtons(card)
	if card==nil then return end
	--Clean up old 3D buttons left by saves from before the XML conversion.
	local remove={}
	for _, button in pairs(card.getButtons() or {}) do
		if button.click_function=="meditationTranceTop" or button.click_function=="meditationTranceBot" then remove[#remove+1]=button.index end
	end
	table.sort(remove, function(a,b) return a>b end)
	for _, index in ipairs(remove) do card.removeButton(index) end

	local before=card.UI.getXmlTable() or {}
	local xml=meditationStripXmlButtons(card)
	if #xml~=#before then
		if #xml>0 then card.UI.setXmlTable(xml) else card.UI.setXml("") end
	end
end
local function meditationAddButtons(card, tranceReady)
	if card==nil then return end
	if cardEffectIsVertical(card)==false then meditationRemoveButtons(card) return end
	--Replace only our two controls, preserving any unrelated object UI on the card.
	local xml=meditationStripXmlButtons(card)
	if tranceReady==true then
		xml[#xml+1]=createClaimButton(card.guid, "tranceTop") xml[#xml+1]=createClaimButton(card.guid, "tranceBot")
	else
		xml[#xml+1]=createClaimButton(card.guid, "meditationTop") xml[#xml+1]=createClaimButton(card.guid, "meditationBot")
	end
	card.UI.setXmlTable(xml)
end
local function meditationNewState(playerIndex)
	local discard=meditationDiscardSnapshot(playerIndex)
	local required=math.min(2, meditationCardCount(discard))
	return {player=playerIndex, mode="waiting", discard=discard, required=required, accepted={}, acceptedSet={}, resolved=false}
end
function resetMeditationTranceState()
	local card=getObjectFromGUID(meditationTranceCardGUID)
	if card~=nil then meditationRemoveButtons(card) end
	gStates.meditationTranceState=nil
end
function refreshMeditationTrance()
	local card=getObjectFromGUID(meditationTranceCardGUID)
	if card==nil then return end
	local playerIndex=meditationPlayerIndex(card)
	--Picking the card up can briefly move it outside the player zone. Hide its controls,
	--but keep the resolved/unresolved state until the next turn explicitly resets it.
	if playerIndex==nil or cardEffectIsVertical(card)==false then meditationRemoveButtons(card) return end
	local state=gStates.meditationTranceState
	--Discard old powered/unpowered state from the first implementation and rebuild using physical card movement instead.
	if state==nil or state.player~=playerIndex or state.powered~=nil then gStates.meditationTranceState=meditationNewState(playerIndex) state=gStates.meditationTranceState end
	if state.resolved==true then meditationRemoveButtons(card) return end
	if state.mode=="trance" then
		if #state.accepted>=(state.required or 2) then meditationAddButtons(card, true) else meditationRemoveButtons(card) end
	else meditationAddButtons(card, false) end
end
local function meditationContainerIsDeedDeck(container, playerIndex)
	if container==nil or turnOrder[playerIndex]==nil then return false end
	local zone=getObjectFromGUID(deedDeckZones[turnOrder[playerIndex].seatPos])
	if zone==nil then return false end
	for _, obj in pairs(zone.getObjects()) do if obj.guid==container.guid then return true end end
	local a,b=container.getPosition(),zone.getPosition()
	return ((a[1]-b[1])^2)+((a[3]-b[3])^2)<6.25
end
local function meditationAcceptTranceCard(cardGUID)
	local state=gStates.meditationTranceState
	if state==nil or state.resolved==true or #state.accepted>=(state.required or 2) or state.discard==nil or state.discard[cardGUID]~=true or (state.acceptedSet~=nil and state.acceptedSet[cardGUID]==true) then return false end
	if (state.required or 0)<1 then return false end
	if state.acceptedSet==nil then state.acceptedSet={} end
	state.mode="trance" state.accepted[#state.accepted+1]=cardGUID state.acceptedSet[cardGUID]=true
	broadcastToAll("Trance Card Accepted ("..tostring(#state.accepted).."/"..tostring(state.required)..")", positionToColor(state.player))
	safeWaitFrames("PlayerBoard.Deeds",function() refreshMeditationTrance() end, 2)
	return true
end
function meditationTranceContainerEnter(container, obj)
	if obj==nil then return end
	if obj.guid==meditationTranceCardGUID then meditationRemoveButtons(obj) gStates.meditationTranceState=nil return end
	local state=gStates.meditationTranceState
	if state~=nil and state.resolved~=true and meditationContainerIsDeedDeck(container, state.player)==true then meditationAcceptTranceCard(obj.guid) end
end
function meditationTranceCheckLooseCard(cardGUID)
	local state=gStates.meditationTranceState
	if state==nil or state.resolved==true or state.discard==nil or state.discard[cardGUID]~=true then return end
	local card=getObjectFromGUID(cardGUID)
	if card==nil or turnOrder[state.player]==nil then return end
	local zone=getObjectFromGUID(deedDeckZones[turnOrder[state.player].seatPos])
	if zone==nil then return end
	for _, obj in pairs(zone.getObjects()) do if obj.guid==cardGUID then meditationAcceptTranceCard(cardGUID) return end end
end
local function meditationTakeCard(zone, cardGUID, position, callback)
	if zone==nil then return false end
	for _, pile in pairs(zone.getObjects()) do
		if pile.type=="Card" and pile.guid==cardGUID then pile.setPosition(position) pile.setRotation({0,180,0}) callback(pile) return true end
		if pile.type=="Deck" then
			for _, data in pairs(pile.getObjects()) do
				if data.guid==cardGUID then safeTakeObject("PlayerBoard.Deeds",pile,{guid=cardGUID, position=position, rotation={0,180,0}, smooth=false, callback_function=callback}) return true end
			end
		end
	end
	return false
end
local function meditationInsertDeedCard(playerIndex, card, destination, callback)
	local zone=turnOrder[playerIndex]~=nil and getObjectFromGUID(deedDeckZones[turnOrder[playerIndex].seatPos]) or nil
	if zone==nil or card==nil then if callback~=nil then callback(false) end return end
	local pile=nil
	for _, obj in pairs(zone.getObjects()) do if obj.guid~=card.guid then if obj.type=="Deck" then pile=obj break elseif obj.type=="Card" then pile=obj end end end
	if pile==nil then
		local pos=zone.getPosition() card.setRotation({0,180,180}) card.setPosition({pos[1],1.50,pos[3]})
		safeWaitFrames("PlayerBoard.Deeds",function() if callback~=nil then callback(true) end end, 2) return
	end
	local pos=pile.getPosition()
	if pile.type=="Deck" then
		card.setScale({1.5,1,1.5}) card.setRotation(pile.getRotation()) card.setPosition({pos[1]+3,pos[2]+(destination=="top" and 0.5 or -0.5),pos[3]})
		safeWaitFrames("PlayerBoard.Deeds",function() if pile~=nil and not pile.isDestroyed() and card~=nil and not card.isDestroyed() then pile.putObject(card) end safeWaitFrames("PlayerBoard.Deeds",function() if callback~=nil then callback(true) end end, 1) end, 1)
	else
		local rotation=pile.getRotation() card.setScale({1.5,1,1.5}) card.setRotation(rotation)
		if destination=="top" then card.setPosition({pos[1],pos[2]+0.28,pos[3]}) else pile.setPosition({pos[1],pos[2]+0.28,pos[3]}) card.setPosition({pos[1],pos[2],pos[3]}) end
		safeWaitFrames("PlayerBoard.Deeds",function() if callback~=nil then callback(true) end end, 4)
	end
end
local function meditationMoveCards(playerIndex, sourceType, cardGUIDs, destination, done)
	local moved=0
	local function moveNext(index)
		if index>#cardGUIDs then if done~=nil then done(moved) end return end
		local sourceZone=getObjectFromGUID((sourceType=="discard" and deedDeckDiscardZones or deedDeckZones)[turnOrder[playerIndex].seatPos])
		local deckZone=getObjectFromGUID(deedDeckZones[turnOrder[playerIndex].seatPos])
		local deckPos=deckZone~=nil and deckZone.getPosition() or {turnOrder[playerIndex].seatPos*40-114,1.5,-43}
		local staging={deckPos[1]+4,3.0,deckPos[3]}
		local found=meditationTakeCard(sourceZone, cardGUIDs[index], staging, function(card)
			meditationInsertDeedCard(playerIndex, card, destination, function(success) if success==true then moved=moved+1 end safeWaitFrames("PlayerBoard.Deeds",function() moveNext(index+1) end, 2) end)
		end)
		if found==false then safeWaitFrames("PlayerBoard.Deeds",function() moveNext(index+1) end, 1) end
	end
	moveNext(1)
end
local function meditationGrantDrawBonus(playerIndex)
	if gStates.meditationDrawBonus==nil then gStates.meditationDrawBonus={} end
	gStates.meditationDrawBonus[playerIndex]=2
	if playerIndex==gStates.turnNumber then safeWaitFrames("PlayerBoard.Deeds",function() if gStates.turnNumber==playerIndex then mainUIUpdate("Meditation Draw Bonus") end end, 1) end
end
local function meditationFinish(playerIndex, destination, moved, expected, name)
	if moved~=expected then broadcastToAll(name.." could not find all selected discard cards.", positionToColor(playerIndex)) return end
	turnOrder[playerIndex].deedCount=(turnOrder[playerIndex].deedCount or 0)+moved
	if destination=="bottom" and turnOrder[playerIndex].mage=="Coral" then safeWaitFrames("PlayerBoard.Deeds",function() coralSetAsideQuickWitted() end, 8) end
end
local function meditationResolve(destination, buttonPlayerColor)
	local card=getObjectFromGUID(meditationTranceCardGUID)
	local playerIndex=meditationPlayerIndex(card)
	if card==nil or playerIndex==nil or legalPlayerCheck(buttonPlayerColor, turnOrder[playerIndex].seatPos)~=true then return end
	local state=gStates.meditationTranceState
	if state==nil or state.player~=playerIndex or state.powered~=nil then refreshMeditationTrance() state=gStates.meditationTranceState end
	if state==nil or state.resolved==true then return end
	if state.mode=="trance" then
		local required=state.required or math.min(2,#state.accepted)
		if #state.accepted<required then broadcastToAll("Trance: add "..tostring(required-#state.accepted).." more chosen card"..((required-#state.accepted)==1 and "" or "s").." from your discard pile to your Deed deck first.", positionToColor(playerIndex)) return end
		state.resolved=true meditationRemoveButtons(card) meditationGrantDrawBonus(playerIndex)
		local selected={}
		for a=1, required do selected[#selected+1]=state.accepted[a] end
		meditationMoveCards(playerIndex, "deed", selected, destination, function(moved) meditationFinish(playerIndex, destination, moved, required, "Trance") end)
		return
	end
	local discard=meditationDiscardSnapshot(playerIndex)
	local choices={}
	for guid, _ in pairs(discard) do choices[#choices+1]=guid end
	local amount=math.min(2,#choices)
	local selected={}
	for a=1, amount do selected[#selected+1]=table.remove(choices,math.random(#choices)) end
	state.resolved=true meditationRemoveButtons(card) meditationGrantDrawBonus(playerIndex)
	if amount==0 then
		broadcastToAll("Meditation: no discard cards to return. Draw +2 over hand limit still applies.", positionToColor(playerIndex))
		return
	end
	meditationMoveCards(playerIndex, "discard", selected, destination, function(moved)
		meditationFinish(playerIndex, destination, moved, amount, "Meditation")
		if moved==amount then broadcastToAll("Meditation returned "..tostring(amount).." random discard card"..(amount==1 and "" or "s").." to the "..destination.." of the Deed deck.", positionToColor(playerIndex)) end
	end)
end
function meditationTranceTop(player, mouseButton, id) if mouseButton~="-3" then meditationResolve("top", player.color) end end
function meditationTranceBot(player, mouseButton, id) if mouseButton~="-3" then meditationResolve("bottom", player.color) end end

--Steady Tempo end-of-turn choice. The card deliberately remains in the play area
--during cleanup, then these small card-attached buttons decide where it goes.
local steadyTempoGUIDs={ ["1f362f"]=true, ["6e506a"]=true }
function isSteadyTempoGUID(guid) return guid~=nil and steadyTempoGUIDs[guid]==true end
local function steadyTempoPlayerIndex(seatPos)
	for playerIndex, details in pairs(turnOrder) do if details.seatPos==seatPos then return playerIndex end end
	return nil
end
function steadyTempoPendingForSeat(seatPos)
	if seatPos==nil or gStates.steadyTempoPending==nil then return false end
	for _, pendingSeat in pairs(gStates.steadyTempoPending) do if pendingSeat==seatPos then return true end end
	return false
end
function steadyTempoUpdateRewardGate(seatPos)
	if seatPos==nil or gStates.preEndTurn~=true or turnOrder[gStates.turnNumber]==nil or turnOrder[gStates.turnNumber].seatPos~=seatPos then return end
	--Quest resolution uses a soft gate: Rewards Claimed remains clickable, and __endTurn_raw refreshes
	--the Quest controls plus explains what must be resolved. Only genuinely asynchronous cleanup/Steady
	--Tempo physically disables this button. Free Wine now follows the same Quest behavior.
	local blocked=rewardClaimDelayActive==true or steadyTempoPendingForSeat(seatPos)
	UI.setAttribute("PreEndTurn", "interactable", blocked and "false" or "true")
	UI.setAttribute("PreEndTurnImage", "image", blocked and "Sliced Button/Button New Deactive" or "Sliced Button/Button New Active")
end
local function steadyTempoStripButtons(card)
	local xml=card~=nil and (card.UI.getXmlTable() or {}) or {}
	for a=#xml, 1, -1 do
		local id=xml[a].attributes~=nil and xml[a].attributes.id or nil
		if id==card.guid.."steadyTempoDiscard" or id==card.guid.."steadyTempoBot" or id==card.guid.."steadyTempoTop" then table.remove(xml,a) end
	end
	return xml
end
function steadyTempoRemoveButtons(card)
	if card==nil then return end
	local before=card.UI.getXmlTable() or {}
	local xml=steadyTempoStripButtons(card)
	if #xml~=#before then if #xml>0 then card.UI.setXmlTable(xml) else card.UI.setXml("") end end
end
local function steadyTempoHasDeedPile(playerIndex)
	local details=turnOrder[playerIndex]
	local zone=details~=nil and getObjectFromGUID(deedDeckZones[details.seatPos]) or nil
	if zone==nil then return false end
	for _, obj in pairs(zone.getObjects()) do if obj.type=="Deck" or obj.type=="Card" then return true end end
	return false
end
local function steadyTempoCardInPlayArea(card, seatPos)
	local zone=card~=nil and getObjectFromGUID(playerPlayAreas[seatPos]) or nil
	if zone==nil then return false end
	for _, obj in pairs(zone.getObjects()) do if obj.guid==card.guid then return true end end
	return false
end
local function steadyTempoAddButtons(card, playerIndex)
	if card==nil or turnOrder[playerIndex]==nil then return end
	if cardEffectIsVertical(card)==false then steadyTempoRemoveButtons(card) return end
	local xml=steadyTempoStripButtons(card)
	xml[#xml+1]=createClaimButton(card.guid, "steadyTempoDiscard")
	--The printed basic effect only permits the bottom option while the Deed deck is not empty.
	if steadyTempoHasDeedPile(playerIndex)==true then xml[#xml+1]=createClaimButton(card.guid, "steadyTempoBot") end
	xml[#xml+1]=createClaimButton(card.guid, "steadyTempoTop")
	card.UI.setXmlTable(xml)
end
function steadyTempoPrepare(card, playerIndex)
	if card==nil or isSteadyTempoGUID(card.guid)==false or turnOrder[playerIndex]==nil then return end
	if cardEffectIsVertical(card)==false then steadyTempoRemoveButtons(card) return end
	if gStates.steadyTempoPending==nil then gStates.steadyTempoPending={} end
	local seatPos=turnOrder[playerIndex].seatPos
	gStates.steadyTempoPending[card.guid]=seatPos
	steadyTempoAddButtons(card, playerIndex)
	steadyTempoUpdateRewardGate(seatPos)
end
function steadyTempoClearPending(cardGUID)
	local seatPos=gStates.steadyTempoPending~=nil and gStates.steadyTempoPending[cardGUID] or nil
	if gStates.steadyTempoPending~=nil then gStates.steadyTempoPending[cardGUID]=nil end
	local card=getObjectFromGUID(cardGUID)
	if card~=nil then steadyTempoRemoveButtons(card) end
	if seatPos~=nil then steadyTempoUpdateRewardGate(seatPos) end
end
function steadyTempoRefreshCard(cardGUID)
	if gStates.steadyTempoPending==nil then return end
	local seatPos=gStates.steadyTempoPending[cardGUID]
	local card=seatPos~=nil and getObjectFromGUID(cardGUID) or nil
	local playerIndex=seatPos~=nil and steadyTempoPlayerIndex(seatPos) or nil
	if card==nil or playerIndex==nil then return end
	if steadyTempoCardInPlayArea(card, seatPos)==true and card.is_face_down==false and cardEffectIsVertical(card)==true then steadyTempoAddButtons(card, playerIndex) else steadyTempoRemoveButtons(card) end
end
function steadyTempoRefreshAll()
	if gStates.steadyTempoPending==nil then return end
	for cardGUID, _ in pairs(gStates.steadyTempoPending) do steadyTempoRefreshCard(cardGUID) end
end
local function steadyTempoMoveToDiscard(playerIndex, card)
	local details=turnOrder[playerIndex]
	local zone=details~=nil and getObjectFromGUID(deedDeckDiscardZones[details.seatPos]) or nil
	if zone==nil or card==nil then return false end
	local pile=nil
	for _, obj in pairs(zone.getObjects()) do if obj.type=="Deck" then pile=obj break elseif obj.type=="Card" then pile=obj end end
	card.setScale({1.5,1,1.5}) card.setRotation({0,180,0})
	if pile==nil then
		local pos=zone.getPosition() card.setPosition({pos[1],1.50,pos[3]})
	else
		local pos=pile.getPosition() card.setPosition({pos[1]+3,pos[2]+0.5,pos[3]})
		safeWaitFrames("PlayerBoard.Deeds",function() if pile~=nil and not pile.isDestroyed() and card~=nil and not card.isDestroyed() then pile.putObject(card) end end, 1)
	end
	safeWaitFrames("PlayerBoard.Deeds",function() scheduleDeedPileDescriptionRefresh(details.seatPos, "discard") end, 6)
	return true
end
function steadyTempoChoice(player, mouseButton, id)
	if mouseButton=="-3" or player==nil or id==nil then return end
	local cardGUID=id:sub(1,6)
	if isSteadyTempoGUID(cardGUID)==false or gStates.steadyTempoPending==nil then return end
	local seatPos=gStates.steadyTempoPending[cardGUID]
	local playerIndex=seatPos~=nil and steadyTempoPlayerIndex(seatPos) or nil
	local card=getObjectFromGUID(cardGUID)
	if playerIndex==nil or card==nil or legalPlayerCheck(player.color, seatPos)~=true then return end
	local choice=id:sub(7)
	if choice=="steadyTempoBot" and steadyTempoHasDeedPile(playerIndex)==false then steadyTempoAddButtons(card, playerIndex) return end
	--Remove the controls immediately, but keep the pending flag until the card physically reaches its destination.
	--Rewards Claimed therefore cannot race a Top insertion and draw the old top card first.
	steadyTempoRemoveButtons(card)
	if choice=="steadyTempoDiscard" then
		if steadyTempoMoveToDiscard(playerIndex, card)==true then safeWaitFrames("PlayerBoard.Deeds",function() steadyTempoClearPending(cardGUID) end, 2)
		else steadyTempoAddButtons(card, playerIndex) end
		return
	end
	local destination=choice=="steadyTempoBot" and "bottom" or "top"
	meditationInsertDeedCard(playerIndex, card, destination, function(success)
		if success~=true then steadyTempoAddButtons(card, playerIndex) return end
		turnOrder[playerIndex].deedCount=(turnOrder[playerIndex].deedCount or 0)+1
		scheduleDeedPileDescriptionRefresh(seatPos, "deed")
		scheduleEndRoundDeedStateRefresh(seatPos)
		--Quick Witted remains Coral's actual set-aside bottom card; Steady Tempo sits immediately above it.
		if destination=="bottom" and turnOrder[playerIndex].mage=="Coral" then
			scheduleCoralQuickWittedBottom(6)
			safeWaitFrames("PlayerBoard.Deeds",function() steadyTempoClearPending(cardGUID) end, 8)
		else steadyTempoClearPending(cardGUID) end
	end)
end

--Keep Quick Witted Set Aside at the bottom of Coral's physical Deed Deck.
--Taking it out and putting it back at the Deck's resting elevation inserts it at the bottom.
function coralSetAsideQuickWitted()
	local cardGUID="6ecbc6"
	for _, playerDetails in pairs(turnOrder) do
		if playerDetails.mage=="Coral" and playerDetails.mage~=gStates.positionMageKnight[5] and playerDetails.dropoutState==nil then
			local deedZone=getObjectFromGUID(deedDeckZones[playerDetails.seatPos])
			if deedZone==nil then return end
			local deedDeck=nil
			for _, obj in pairs(deedZone.getObjects()) do
				if obj.type=="Deck" then
					deedDeck=obj
					for _, cardData in pairs(obj.getObjects()) do
						if cardData.guid==cardGUID then
							local deckPos=obj.getPosition()
							safeTakeObject("PlayerBoard.Deeds",obj,{guid=cardGUID, position={deckPos[1]+3, deckPos[2], deckPos[3]}, rotation={0, 180, 180}, smooth=false, callback_function=function(card)
								safeWaitFrames("PlayerBoard.Deeds",function()
									local currentDeck=nil
									for _, currentObj in pairs(deedZone.getObjects()) do if currentObj.type=="Deck" then currentDeck=currentObj break end end
									if currentDeck~=nil then
										local currentPos=currentDeck.getPosition()
										card.setScale({1.5, 1, 1.5})
										card.setPosition({currentPos[1]+3, currentPos[2]-0.5, currentPos[3]})
										currentDeck.putObject(card)
									else
										card.setPosition({deckPos[1], deckPos[2], deckPos[3]})
									end
								end, 1)
							end})
							return
						end
					end
				end
			end
			--Compatibility with saves from the earlier inventory-based version. Only recover a loose
			--Quick Witted that is physically in Coral's Deed zone; once claimed to hand it is a normal card.
			local looseCard=getObjectFromGUID(cardGUID)
			local looseInDeedZone=false
			if looseCard~=nil then
				for _, deedObj in pairs(deedZone.getObjects()) do if deedObj.guid==cardGUID then looseInDeedZone=true break end end
			end
			if looseCard~=nil and looseInDeedZone==true and deedDeck~=nil then
				local deckPos=deedDeck.getPosition()
				looseCard.setScale({1.5, 1, 1.5})
				looseCard.setRotation({0, 180, 180})
				looseCard.setPosition({deckPos[1]+3, deckPos[2]-0.5, deckPos[3]})
				safeWaitFrames("PlayerBoard.Deeds",function() if deedDeck~=nil then deedDeck.putObject(looseCard) end end, 1)
			elseif looseCard~=nil and looseInDeedZone==true and deedDeck==nil then
				local deckPos=deedZone.getPosition()
				looseCard.setScale({1.5, 1, 1.5})
				looseCard.setRotation({0, 180, 180})
				looseCard.setPosition({deckPos[1], 1.50, deckPos[3]})
			end
			return
		end
	end
end

--Deals all the hands by fast forwarding through the turns
function dealAllHands()
	local temp=gStates.turnNumber
	for a=1, #turnOrder, 1 do
		gStates.turnNumber=a
		if turnOrder[gStates.turnNumber].mage~=gStates.positionMageKnight[5] and playerDropoutInactive(gStates.turnNumber)==false then drawUpTo({color="Black"}, "-1", "DrawHand") end--color is only there to stop error
	end
	gStates.turnNumber=temp
	safeWaitTime("PlayerBoard.Deeds",function()
		for x=1, #turnOrder, 1 do
			--Records current amount of cards in deed deck
			turnOrder[x].deedCount=0
			for _, b in pairs(getObjectFromGUID(deedDeckZones[turnOrder[x].seatPos]).getObjects()) do
				if b.type=="Card" then turnOrder[x].deedCount=1 end
				if b.type=="Deck" then turnOrder[x].deedCount=b.getQuantity() end
			end
		end
	end, 0.5)
end

--Fill any gaps in the offer by sliding more cards down the line
local function fillSlideRaw()
	local offerList={{}, {}}
	local sourceDeck={GUID.zone.actionDeck, GUID.zone.spellDeck}
	for _, obj in pairs(getObjectFromGUID(GUID.zone.offer).getObjects()) do
		if obj.type=="Card" then --and obj.resting==true then
			local cardSpot=obj.getPosition()
			offerList[math.floor(((-cardSpot[3]-10.2)/6)+0.5)][math.floor(((cardSpot[1]-21.6)/4.8)+0.5)]=obj.guid
		end
	end
	--fill gaps in the offer
	for column=1, gStates.offerSize, 1 do
		for row=1, 2, 1 do
			if offerList[row][column]==nil then
				for replaceColumn=column+1, gStates.offerSize+1, 1 do
					if replaceColumn<gStates.offerSize+1 then
						--fill empty spaces with cards further up the offer
						if offerList[row][replaceColumn]~=nil then
							local cardMove=getObjectFromGUID(offerList[row][replaceColumn])
							cardMove.unlock()
							cardMove.setPositionSmooth({(column*4.8)+21.6, 1.5, -((row*6)+10.2)})
							cardMove.setRotationSmooth({0, 180, 0})
							safeWaitCondition("PlayerBoard.Deeds",function() safeWaitTime("PlayerBoard.Deeds",function() cardMove.lock() end, 1) end, function() return cardMove.resting end)
							offerList[row][column]=offerList[row][replaceColumn]
							offerList[row][replaceColumn]=nil
							break
						end
					else
						--fill empty spaces from deck when no cards are found
						local deckName=row==1 and "Advanced Action" or "Spell"
						standardDeckCycleShuffleIfReached(deckName)
						local MainDeck=getObjectFromGUID(sourceDeck[row]).getObjects()
						if MainDeck[1]~=nil then
							if MainDeck[1].type=="Deck" then
								local newcard=MainDeck[1].takeObject({position={((column*4.8)+21.6), 1.5, -((row*6)+10.2)}, rotation={0, 180, 0}})
								offerList[row][column]=newcard.guid
								safeWaitCondition("PlayerBoard.Deeds",function() safeWaitTime("PlayerBoard.Deeds",function() newcard.lock() end, 1) end, function() return newcard.resting end)
							else
								MainDeck[1].setPositionSmooth({(column*4.8)+21.6, 1.5, -((row*6)+10.2)})
								MainDeck[1].setRotationSmooth({0, 180, 0})
								MainDeck[1]=nil
							end
						end
					end
				end
			end
		end
	end
end

function fillSlide()
	return safeCallback("fillSlide",function() return fillSlideRaw() end)
end

-- Artifact, Unit, Monastery and deed-offer runtime.

-- Artifact reward offer
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
					safeWaitCondition("Offers",function() dealtArtifact.lock() end, function() return dealtArtifact.resting end)
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

-- Unit offer layout and refill
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
	safeWaitCondition("Offers",function()
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
	safeWaitTime("Offers",function() if claimButtonRefresh~=nil then claimButtonRefresh() end end,0.5)
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
			safeTakeObject("Offers",deck,{
				position=unitOfferPosition(slot,finalCount,1.25),
				rotation={0,180,0},
				smooth=true,
				callback_function=function(drawnCard)
					drawnCard.setScale({scale,1,scale})
					safeWaitCondition("Offers",function() if drawnCard~=nil then drawnCard.lock() end end,function() return drawnCard==nil or drawnCard.resting end)
				end
			})
			added=added+1
		end
	end
	safeWaitTime("Offers",function() if claimButtonRefresh~=nil then claimButtonRefresh() end end,0.5)
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
			safeTakeObject("Offers",draw.deck,{
				guid=draw.guid,
				position=unitOfferPosition(a,gStates.totalUnitCount),
				rotation={0,180,0},
				smooth=true,
				callback_function=function(drawnCard)
					local scale=unitOfferCardScale(gStates.totalUnitCount)
					drawnCard.setScale({scale,1,scale})
					safeWaitCondition("Offers",function()
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
			safeWaitCondition("Offers",function() drawnCard.lock() end, function() return drawnCard.resting end)
		end
	end
end

-- Monastery offer
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
	--Initial terrain reveals happen before the starting offers are built. Record the monastery now,
	--then let the first unitOffer() deal its Advanced Action once so setup does not deal-and-return it.
	if startingMapSetup==true then return end
	if gStates.monasteryCount>=0 then
		--Find the first free printed Monastery slot directly from the broad offer zone.
		local slot=monasteryOfferFirstEmptySlot()
		if slot==nil then return end
		local params={rotation={0,180,0},position={40.8-slot*4.8,0.98,-10.2}}
		--Play an advanced action card. Deck-cycle cleanup can briefly leave the draw zone without
		--a Card/Deck, so wait on the real source instead of spinning a Lua while loop around a callback.
		standardDeckCycleShuffleIfReached("Advanced Action")
		local function drawMonasteryAdvancedAction()
			local source=standardDeckCycleObject("Advanced Action")
			if source==nil then return false end
			local drawnCard=nil
			if source.type=="Deck" then
				drawnCard=safeTakeObject("Offers",source,params)
			elseif source.type=="Card" then
				drawnCard=source
				drawnCard.unlock()
				drawnCard.setPositionSmooth(params.position,false,false)
				drawnCard.setRotationSmooth(params.rotation,false,false)
			end
			if drawnCard==nil then return false end
			safeWaitCondition("Offers",function() if drawnCard~=nil then drawnCard.lock() end end,function()
				return drawnCard==nil or drawnCard.resting==true
			end,5,function() if drawnCard~=nil then drawnCard.lock() end end)
			broadcastToAll("{en}Monastery is teaching a new Advanced Action{ru}Монастырь обучает новому Особому действию{zh-tw}修道院现在传授新的高级行动{zh-cn}修道院现在传授新的高级行动{ko}수도원에 새로운 상급 액션이 추가되었습니다{es}El Monasterio está enseñando una nueva Acción Avanzada{fr}Le Monastère enseigne une nouvelle Action Avancée{pt-br}Monastério está encinsando uma nova Ação Avançada{de}Das Kloster lehrt eine neue fortgeschrittene Aktion", {1,1,0.5})
			return true
		end
		if drawMonasteryAdvancedAction()~=true then
			safeWaitCondition("Offers",function()
				if drawMonasteryAdvancedAction()~=true then error("Monastery Advanced Action source disappeared before it could be drawn.",2) end
			end,function()
				return standardDeckCycleObject("Advanced Action")~=nil
			end,5,function()
				error("Timed out waiting for the Monastery Advanced Action draw source.",2)
			end)
		end
	end
end

-- Main deed offer resizing
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
		safeWaitFrames("Offers",function()
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

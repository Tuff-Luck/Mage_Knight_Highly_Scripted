-- Shared automated-player helpers for Dummy, Proxy and Volkare.

--The combined-defense choice is a transient lock; it does not need to be saved with the game.
dropoutCoopDefensePrompt=false

--Get's the dummy to pick a tactic card
function dummyRefreshDeedState(seatPos)
	if seatPos==nil then return end
	local newCount=readDeedPileCardCount(seatPos)
	deedPileCardCount[seatPos]=newCount
	endRoundDeedHasCards[seatPos]=newCount>0
	if gStates.turnNumber~=nil and turnOrder[gStates.turnNumber]~=nil and turnOrder[gStates.turnNumber].seatPos==seatPos then endRoundUIStateKey=nil refreshEndRoundState() end
end

--Compatibility names for the three automated-player systems.
function automatedTurnRewindStart(andThen) return rewindTransactionStart(andThen,"Automated turn") end
function automatedTurnRewindRelease() rewindTransactionFinish("Automated turn") end

function automatedTacticRewindRelease()
	--The tactic itself moves smoothly after the turn advances, so keep rewind storage blocked briefly.
	Wait.time(automatedTurnRewindRelease,1.5)
end

function volkareReleaseRewindWhenStable()
	if rewindTransactionOwnerActive("Automated turn")~=true then return end
	local v=getObjectFromGUID(gStates.volkareModel)
	if v==nil or (v.resting and v.isSmoothMoving()==false) then automatedTurnRewindRelease() return end
	Wait.condition(automatedTurnRewindRelease,function()
		local current=getObjectFromGUID(gStates.volkareModel)
		return current==nil or (current.resting and current.isSmoothMoving()==false)
	end,8,function()
		local current=getObjectFromGUID(gStates.volkareModel)
		if current~=nil then
			current.setPosition(current.getPosition())
			current.setVelocity({0,0,0})
			current.setAngularVelocity({0,0,0})
			if gStates.volkareLock~=false then current.lock() end
		end
		automatedTurnRewindRelease()
	end)
end

--Dummy and Volkare both use the center random-Tactic button, but their actual turns are processed separately.
function automatedPlayerRandomTactic()
	local dummyTactic=nil
	local claimedCard=nil
	while dummyTactic==nil do
		dummyTactic=math.random(1,6)
		for _, obj in pairs(getObjectFromGUID(tacticZones[dummyTactic]).getObjects()) do
			if isTacticCard(obj) then claimedCard=obj break end
		end
		if claimedCard==nil then dummyTactic=nil end
	end
	broadcastToAll(joinLang({gStates.positionMageKnight[5]=="Volkare" and "{en}Volkare RANDOMLY gained Tactic for {ru}Волкар получает СЛУЧАЙНУЮ Тактику для {zh-tw}沃卡里隨機選取戰術給{zh-cn}沃卡里随机选取战术给{ko}볼케어가 무작위 전략을 가져갑니다: {es}Volkare ganó ALEATORIAMENTE Táctica para {fr}Volkare a gagné au hasard une Tactique pour {pt-br}Volkare ALEATORIAMENTE ganhou a Tática por {de}Volkare hat ZUFÄLLIG eine Taktik für " or (proxyPlayerActive()==true and "{en}Proxy RANDOMLY gained Tactic for {ru}Прокси получает СЛУЧАЙНУЮ Тактику для {zh-tw}代理玩家隨機選取戰術給{zh-cn}代理玩家随机选取战术给{ko}프록시가 무작위 전략을 가져갑니다: {es}Proxy ganó ALEATORIAMENTE Táctica para {fr}Le Proxy a gagné au hasard une Tactique pour {pt-br}Proxy ALEATORIAMENTE ganhou a Tática por {de}Proxy hat ZUFÄLLIG eine Taktik für " or "{en}Dummy RANDOMLY gained Tactic for {ru}Виртуальный игрок получает СЛУЧАЙНУЮ Тактику для {zh-cn}虚拟玩家随机选取战术给{ko}가상 플레이어가 무작위의 전략 카드를 가져갑니다: {es}Dummy ganada ALEATORIAMENTE Táctica para {fr}Le mannequin a gagné au hasard une Tactique pour {pt-br}Jog. Fictício ALEATORIAMENTE ganhou a Tática por {de}Dummy hat ZUFÄLLIG eine Taktik für "), translateWord[turnOrder[gStates.turnNumber].mage]}), positionToColor(gStates.turnNumber))
	if claimedCard~=nil then
		claimedCard.unlock()
		claimedCard.setPositionSmooth({getObjectFromGUID(dummyBoard).getPosition()[1], 3.0, getObjectFromGUID(dummyBoard).getPosition()[3]-5.17})
	end
	turnOrder[gStates.turnNumber].tactic=dummyTactic
end

--Draw from an automated player's Deed pile without ever calling takeObject on a Deck after it collapses to its final Card.
--The returned card is the last card actually flipped, even when fewer cards were available than requested.
function automatedDeedDraw(seatPos, cardCount, passIndex)
	if seatPos==nil or cardCount==nil or cardCount<=0 then return nil,0 end
	local deedZone=getObjectFromGUID(deedDeckZones[seatPos])
	local discardZone=getObjectFromGUID(deedDeckDiscardZones[seatPos])
	if deedZone==nil or discardZone==nil then return nil,0 end
	local pile=nil
	for _, obj in pairs(deedZone.getObjects()) do
		if obj.type=="Deck" or obj.type=="Card" then pile=obj break end
	end
	if pile==nil then return nil,0 end
	local destination=discardZone.getPosition()
	local passOffset=((passIndex or 1)-1)*4.5
	local drawn=0
	local lastCard=nil
	local function destinationFor(drawIndex) return {destination[1], destination[2]+(drawIndex*1.5)+passOffset, destination[3]} end
	if pile.type=="Card" then
		pile.setPositionSmooth(destinationFor(1))
		pile.setRotationSmooth({0,180,0})
		return pile,1
	end
	local quantity=pile.getQuantity()
	local takeCount=math.min(cardCount, math.max(quantity-1,0))
	for i=1,takeCount do
		local taken=pile.takeObject({position=destinationFor(i), rotation={0,180,0}})
		if taken==nil then break end
		drawn=drawn+1
		lastCard=taken
	end
	--Taking the second-last card destroys a TTS Deck. If this draw is meant to empty it,
	--move the spawned remainder instead of calling takeObject on the destroyed Deck reference.
	if cardCount>=quantity and drawn==quantity-1 then
		local remainder=pile.remainder
		if remainder~=nil then
			drawn=drawn+1
			remainder.setPositionSmooth(destinationFor(drawn))
			remainder.setRotationSmooth({0,180,0})
			lastCard=remainder
		end
	end
	return lastCard,drawn
end

function dummyCardColors(card)
	local colors={}
	if card~=nil and gameCards[card.guid]~=nil and type(gameCards[card.guid].color)=="table" then
		for _, color in ipairs(gameCards[card.guid].color) do if color=="Red" or color=="Green" or color=="Blue" or color=="White" then colors[#colors+1]=color end end
	end
	if #colors==0 and card~=nil then
		for color in tostring(card.getDescription()):gmatch("%a+") do if color=="Red" or color=="Green" or color=="Blue" or color=="White" then colors[#colors+1]=color end end
	end
	return colors
end

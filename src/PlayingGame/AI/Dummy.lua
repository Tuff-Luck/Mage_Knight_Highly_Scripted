-- Standard Dummy runtime.

--Standard Dummy only. It deliberately advances immediately; bonus flips may finish during the next player's turn.
function dummyProcessTurn(dummyIndex,dummySeat)
	if gStates.turnNumber~=dummyIndex then automatedTurnRewindRelease() return end
	local dummyStats=turnOrder[dummyIndex]
	if dummyStats==nil or dummyStats.mage~=gStates.positionMageKnight[5] then automatedTurnRewindRelease() return end
	dummyStats.dummyProcessedThisTurn=true
	automatedMainPanelRefresh()

	--Snapshot the physical crystals now so delayed bonus flips never depend on whichever player is current later.
	local crystalSnapshot={Red=0,White=0,Green=0,Blue=0}
	for _, obj in pairs(getObjectFromGUID(playerCrystalAreas[dummySeat]).getObjects()) do
		if obj.getName()=="Red Mana" or obj.getName()=="Blue Mana" or obj.getName()=="Green Mana" or obj.getName()=="White Mana" then
			local color=obj.getDescription()
			if crystalSnapshot[color]~=nil then crystalSnapshot[color]=crystalSnapshot[color]+1 end
		end
	end
	dummyStats.dummyCrystals["Red"]=crystalSnapshot.Red
	dummyStats.dummyCrystals["White"]=crystalSnapshot.White
	dummyStats.dummyCrystals["Green"]=crystalSnapshot.Green
	dummyStats.dummyCrystals["Blue"]=crystalSnapshot.Blue

	local thirdCard=automatedDeedDraw(dummySeat,3,1)
	local bonusDraw=0
	if thirdCard~=nil then for _, color in ipairs(dummyCardColors(thirdCard)) do bonusDraw=bonusDraw+(crystalSnapshot[color] or 0) end end
	safeWaitTime("AI.Dummy",function()
		automatedDeedDraw(dummySeat,bonusDraw,2)
		safeWaitTime("AI.Dummy",function()
			dummyRefreshDeedState(dummySeat)
			automatedTurnRewindRelease()
		end,0.25)
	end,1.5)
	--Experienced players can continue immediately while any crystal-bonus cards finish flipping.
	nextTurnMerged("incrementTurn")
end

function dummyTurn(player, mouseButton, id)
	if mouseButton~="-1" or gStates.positionMageKnight[5]=="Volkare" or proxyPlayerActive()==true then return end
	if gStates.tacticShown==true then
		automatedTurnRewindStart(function()
			automatedPlayerRandomTactic()
			nextTurnMerged("incrementTurn")
			automatedTacticRewindRelease()
		end)
		return
	end
	if gStates.endRoundCalled==true then return end
	local dummyIndex=gStates.turnNumber
	local dummyStats=turnOrder[dummyIndex]
	if dummyStats==nil or dummyStats.mage~=gStates.positionMageKnight[5] then return end
	local dummySeat=dummyStats.seatPos
	--Only an empty deck at the START of the Dummy's turn calls End of Round.
	if readDeedPileCardCount(dummySeat)==0 then dummyRefreshDeedState(dummySeat) PreEndRound({color="Black"}, "-1", "DummyButton") return end
	if dummyStats.dummyProcessedThisTurn==true then return end
	automatedTurnRewindStart(function() dummyProcessTurn(dummyIndex,dummySeat) end)
end

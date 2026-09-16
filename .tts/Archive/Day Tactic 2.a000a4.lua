local discardedButton={label="{en}Day Tactic 2\nClick after Card(s)\nhave been discarded{ru}Тактика дня 2\nЩелкните после\nсброса карт{zh-cn}白天战术卡2\n弃牌后单击此处{ko}낮 전략 2\n버릴 카드를 놓고\n클릭하세요.{es}Táctica del día 2\nHaga clic después de Tarjeta (s)\nhan sido descartados{fr}Jour Tactique 2\nCliquez après Carte(s)\n ont été jetés{pt-br}Dia Tática 2\nClique depois do (s) cartão (ões)\nforam descartados{de}Tag Taktik 2\nKlicken Sie, nachdem die Karte(n)\nabgeworfen worden sind", font_size=65, color={0.7, 0.7, 0.7},
			position={3.1, 0, -1.4}, width=650, height=300, rotation={0, 0, 0},
			function_owner=self, click_function="discardedCards"}

function onLoad()
	if Global.getTable("gStates").firstStarted==1 then
		buttonActivate()
	end
end

function buttonActivate()
	--remove any existing buttons
	if self.getButtons()~=nil then
		for i=1, #self.getButtons(), 1 do self.removeButton(i-1) end
	end
	--see if dummy has this tactic
	local dummyHasTactic=false
	for a=1, #Global.getTable("turnOrder"), 1 do
		if Global.getTable("turnOrder")[a].tactic==2 then
			if Global.getTable("turnOrder")[a].mage==Global.getTable("gStates").positionMageKnight[5] then dummyHasTactic=true end
			break
		end
	end
	--Add button
	Wait.frames(function()
		if self.getPosition()[3]<-15 and Global.getTable("gStates").tacticTwoState~="Used" and Global.getTable("gStates").tacticRemove==false and dummyHasTactic==false and Global.getTable("gStates").dayRound==true then
			self.createButton(discardedButton)
		end
	end, 50)
end

--Give new cards and shuffle discard back in to deck.
function discardedCards(notUsed, playerColor)
	--converts the color of the player who clicked the button into a position they are sitting at
	local playerPosition=0
	for a, findPlayerPosition in pairs(Global.getTable("turnOrder")) do
		if findPlayerPosition.tactic==2 then playerPosition=findPlayerPosition.seatPos break end
	end
	if Player[playerColor].seated==true and playerColor~="Black" and Player[playerColor].getHandTransform()~=nil then playerPosition=math.ceil((Player[playerColor].getHandTransform().position[1] + 97.59)/40) end
	--make sure it's the player who has Day Tactic 2
	if playerPosition==math.ceil((self.getPosition()[1]+78)/40) then
		--clean play area of cards in case player discarded there.
		local cardDestination=nil
		local waitTime=0
		for _, playAreaObj in pairs(getObjectFromGUID(Global.getTable("playerPlayAreas")[Global.getTable("turnOrder")[Global.getTable("gStates").turnNumber].seatPos]).getObjects()) do
			if playAreaObj.tag=="Card" then
				--Check for and leave banner Cards
				local found=false
				for _, bannerGUID in pairs({"596cfa", "986216", "0b5b32", "e48e44", "8dbce4", "8e4b92", "75a627"}) do
					if playAreaObj.guid==bannerGUID then found=true break end
				end
				if playAreaObj.getDescription()=="Quest" then found=true end
				--Check if the card is registered to the player and place on deed pile
				if found==false then
					waitTime=1
					if cardDestination==nil then
						playAreaObj.setRotation({0.0, 180.0, 0.0})
						playAreaObj.setPosition({(Global.getTable("turnOrder")[Global.getTable("gStates").turnNumber].seatPos*40)-110.32, 1.12, -43.20})
						cardDestination=playAreaObj
					else
						playAreaObj.setPosition({playAreaObj.getPosition()[1], 1.9, playAreaObj.getPosition()[3]})
						cardDestination=cardDestination.putObject(playAreaObj)
					end
				end
			end
		end

		Wait.time(function()
			--Check there are not more than three discarded cards
			local deedDeckDiscardZones={"3ec23f", "07c9e2", "b3fe99", "2e1a7a", "88fb5d"}
			local fail=false
			for a, discards in pairs(getObjectFromGUID(deedDeckDiscardZones[playerPosition]).getObjects()) do
				if discards.tag=="Deck" or discards.tag=="Card" then
					if discards.getQuantity()<=3 then
						--Draw new cards
						local deedDeck=nil
						local deedDeckZones={"af0360", "22b532", "c10770", "aa1121", "b29524"}
						for _, possibleDeck in pairs(getObjectFromGUID(deedDeckZones[playerPosition]).getObjects()) do
							if possibleDeck.tag=="Deck" or possibleDeck.tag=="Card" then deedDeck=possibleDeck break end
						end
						for a=1, math.abs(discards.getQuantity()), 1 do
							deedDeck.takeObject({position={(playerPosition*40)-100, 4.59, -47.55}, rotation={0, 180, 0}})
						end
						--Move discard(s) back to Deed Deck
						Wait.time(function() deedDeck.putObject(discards) end, 1)
						--Shuffle Deed Deck
						Wait.time(function() deedDeck.shuffle() end, 2)
					else
						fail=true
						broadcastToAll("You have discarded too many cards",{1,0,0})
					end
					break
				end
			end
			if fail==false then
				--flip Tactic face down
				if self.getRotation()[3]~=180 then self.flip() end
				--Update states and buttons
				local temp=Global.getTable("gStates")
				temp.tacticTwoState="Used"
				Global.setTable("gStates", temp)
				buttonActivate()
			end
		end, waitTime)
	else
		broadcastToAll("That's not for you to decide",{1,0,0})
	end
end
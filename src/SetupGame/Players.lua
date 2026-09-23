-- Physical player, Dummy and Volkare piece deployment during setup.

function setupPlayersReady()
	if gStates==nil or gStates.playerSetupReady~=true or gStates.mirrorSetupReady~=true then return false end
	if proxyPlayerActive()==true and gStates.proxySetupReady~=true then return false end
	if gStates.positionMageKnight[5]=="Volkare" and gStates.volkareSetupReady~=true then return false end
	return true
end

--Go through the five player positions and put out pieces based on the game settings
function playerSetup()
	gStates.playerSetupReady=false
	gStates.proxySetupReady=proxyPlayerActive()~=true
	gStates.volkareSetupReady=gStates.positionMageKnight[5]~="Volkare"
	gStates.mirrorSource=gStates.mirrorSource or {}
	gStates.mirrorSetupReady=false
	local mirrorExpected=0
	for seat=1,4 do if gStates.positionMageKnight[seat]~="nobody" then mirrorExpected=mirrorExpected+1 end end
	local mirrorReady=0
	if mirrorExpected==0 then gStates.mirrorSetupReady=true end
	if gStates.heroChallenges==true then gStates.heroChallengeReservedSkills={} end
	--generate random Mage Knights if needed
	gStates.originalChoiceMageKnights={gStates.positionMageKnight[1], gStates.positionMageKnight[2], gStates.positionMageKnight[3], gStates.positionMageKnight[4], gStates.positionMageKnight[5]}
	for a=1, 5, 1 do
		if gStates.positionMageKnight[a]=="Random" or gStates.positionMageKnight[a]=="All Skills" then
			local randomMK=""
			local duplicate=true
			while duplicate==true do
				duplicate=false
				randomMK=mageKnights[math.random(1, #mageKnights-3)].mage
				for a=1, 5, 1 do
					if randomMK==gStates.positionMageKnight[a] then duplicate=true break end
				end
				if gStates.useCustomMageKnights==false and customMages[randomMK]~=nil then duplicate=true end
				if gStates.riseOfTheForgemasters~=3 and randomMK=="Jormund" then duplicate=true end
				if duplicate==false and gStates.heroChallenges==true then
					if heroChallengesData[randomMK]==nil then
						duplicate=true
					else
						--Quick Random Game bypasses the setup Start-button legality check. Temporarily test the
						--candidate here so a random Hero never creates an impossible Challenge terrain setup.
						local oldChoice=gStates.positionMageKnight[a]
						gStates.positionMageKnight[a]=randomMK
						local assignment=heroChallengeCountryAssignment(false)
						gStates.positionMageKnight[a]=oldChoice
						if assignment==nil then duplicate=true end
					end
				end
			end
			gStates.positionMageKnight[a]=randomMK
		end
	end

	--The selected Mage Knight's normal Shield source may belong to a player position that is cleaned
	--before the Dummy/Proxy position is built. Preserve a dedicated Proxy copy first.
	if proxyPlayerActive()==true then proxyStageShieldBag() end

	--Setup Players Mats.
	local DummyPlayed=0
	local positionOrder={2, 3, 4, 1, 5}--positions are built in this order so dummy is put in the middle
	local startPos=		{0, 0, 0, 0, 0}--records if a position has been used for a turn order token.
	local time=0
	local delay=1.6
	local DummyPlayedTiming=0
	for a=1, 5, 1 do
		--Wait.time(function()
			local offsetPosition=positionOrder[a]*40-40
			local CommonParts={	{-72.50, 0.98, -38.00}, {-68.60, 1.37, -30.80}, {-68.60, 1.37, -32.40},							--Dummy Board, Black Mana, Gold Mana
								{-67.30, 1.37, -30.80}, {-67.30, 1.37, -32.40}, {-65.90, 1.37, -30.80}, {-65.9, 1.37, -32.40},	--Blue Mana, Green Mana, Red Mana, White Mana
								{-41.95, 1.08, -36.10}, {-41.76, 1.14, -31.10}, {-41.76, 1.16, -34.41},							--Wound Cards, Wound Tokens, Keep Token
								{-69.30, 1.35, -29.30}, {-68.00, 1.35, -29.30}, {-66.70, 1.35, -29.30}, {-65.40, 1.35, -29.30}, --Blue Shard, Green Shard, Red Shard, White Shard
								{-76.30, 1.35, -29.30}, {-75.00, 1.35, -29.30}, {-73.70, 1.35, -29.30}, {-72.40, 1.35, -29.30}} --Blue Potion, Green Potion, Red Potion, White Potion
			--Checks if the position has a player, dummy or Volkare required
			if (gStates.positionMageKnight[positionOrder[a]]~="nobody" and positionOrder[a]<=4) or (gStates.positionMageKnight[5]~="nobody" and DummyPlayed==0) then
				--Layout everything from the Common Bag if needed
				local CommonBag=getObjectFromGUID(GUID.bag.common).clone()
				CommonBag.setPosition({-60.0+offsetPosition, 1.5, -38.0})
				for i=1, #CommonParts, 1 do
					local skip=0
					local params={position=CommonParts[i], rotation={0, 180, 0}, smooth=false}
					params.position[1]=params.position[1]+offsetPosition
					if (i>=2 and i<=7) or (i>=11 and i<=14) then params.rotation={0, 30, 0} end
					if positionOrder[a]==5 then params.position[1]=params.position[1]-25.2 params.position[3]=params.position[3]+21.1 end
					if i==1 and positionOrder[a]<=4 and gStates.positionMageKnight[positionOrder[a]]~="nobody" then local obj=CommonBag.takeObject() obj.destruct() skip=1 end--destroy the Dummy Board if this is a player
					if i==1 and positionOrder[a]<=4 and gStates.positionMageKnight[positionOrder[a]]=="nobody" then--change a player position into a dummy position
						getObjectFromGUID(playerBoard[positionOrder[a]]).destruct()
						getObjectFromGUID(colorBand[positionOrder[a]]).setScale({7.48, 0.01, 2.5})
						getObjectFromGUID(colorBand[positionOrder[a]]).setColorTint("Black")
						getObjectFromGUID(colorBand[positionOrder[a]]).setPosition({getObjectFromGUID(colorBand[positionOrder[a]]).getPosition()[1]-12.5, 0.98, -30.0})
						if getObjectFromGUID(playAreaGuideText[positionOrder[a]])~=nil then getObjectFromGUID(playAreaGuideText[positionOrder[a]]).destruct() end
						if getObjectFromGUID(playAreaGuideBackground[positionOrder[a]])~=nil then getObjectFromGUID(playAreaGuideBackground[positionOrder[a]]).destruct() end
					end
					if i==8 and positionOrder[a]<=4 and gStates.positionMageKnight[positionOrder[a]]~="nobody" then--snuck the new poison card in with the regular wound cards
						CommonBag.takeObject({guid="d1e6c3", position={-40.86+offsetPosition, 1.08, -36.10}, smooth=false}).lock()
					end
					if (gStates.positionMageKnight[positionOrder[a]]=="nobody" or positionOrder[a]==5) and ((i>=2 and gStates.positionMageKnight[5]=="Volkare") or (i>=8 and gStates.positionMageKnight[5]~="nobody")) then DummyPlayed=1 break end--just dummy board for Volkare
					if i>=11 and gStates.riseOfTheForgemasters<=1 then break end
					if i>=15 and gStates.riseOfTheForgemasters<=2 then break end
					if skip==0 then local obj=safeTakeObject("SetupGame",CommonBag,params).lock() end
				end
				CommonBag.destruct()

				--mirror source
				if (gStates.positionMageKnight[positionOrder[a]]~="nobody" and positionOrder[a]~=5) then
					local obj=getObjectFromGUID("b5a6ce").clone()
					obj.setPosition({-58.25+offsetPosition, 0.98, -28.53})
					safeWaitCondition("SetupGame",function()
						obj.lock()
						obj.setRotation({0,180,0})
						obj.registerCollisions()
						gStates.mirrorSource[#gStates.mirrorSource+1]=obj.guid
						mirrorReady=mirrorReady+1
						if mirrorReady>=mirrorExpected then gStates.mirrorSetupReady=true end
					end,function() return obj~=nil and obj.resting==true end,10,function()
						error("SetupGame timed out waiting for a player mirror source to settle.",2)
					end)
				end

				--Figure out which Mage Knight is assigned to a position
				local PlayerBag={}
				for i=1, #mageKnights, 1 do
					if gStates.positionMageKnight[positionOrder[a]]==mageKnights[i].mage or (gStates.positionMageKnight[positionOrder[a]]=="nobody" and gStates.positionMageKnight[5]==mageKnights[i].mage) then
						PlayerBag=getObjectFromGUID(mageKnights[i].bag).clone()
						PlayerBag.setPosition({-60.0+offsetPosition, 1.5, -38.0})
						break
					end
				end

				--Layout everything from the mage bag assigned to the position
				local UniqueParts={	{  0.40, 1.55, -19.17}, {-74.19, 1.50, -43.16}, {-72.89, 1.10, -35.13}, {-67.46, 1.60, -36.88}, {-77.30, 1.05, -49.00}, {-73.90, 1.05, -49.00}, --{-67.33, 1.99, -36.88}, {-67.33, 1.99, -36.88},
									{-10.00, 1.25, -27.50}, { 12.10, 1.25,  24.5}, { 40.15, 1.25,  18.6}, {-66.40, 1.16, -34.25}, {-41.76, 1.16, -32.78},
									{-63.57, 1.50, -31.19},	{-68.24, 1.10, -34.4}}
									--1-Turn Order, 2-Unique Cards, 3-Dummy Inventory, 4-Skills, 5-Skill Reference Card 1, 6-Skill Reference Card 2,
									--7-Avatar, 8-Shield Fame, 9-Shield Rep, 10-Shield Control, 11-Quest Marker,
									--12-Comand token Blank, 13-5 Command Tokens
				local turnRef=1
				for i=1, #UniqueParts, 1 do
					local skip=0
					local params={position=UniqueParts[i], smooth=false, setColorTint=""}
					params.position[1]=params.position[1]+offsetPosition
					--turn markers all go in Shuffled Order
					if i==1 then
						if (gStates.positionMageKnight[positionOrder[a]]=="nobody" or positionOrder[a]==5) then--Dummy and Volkare
							local dummyStats={	seatPos=positionOrder[a], mage=gStates.positionMageKnight[5], fame=0, fameGain=0, reputation=0, repGain=0, scoreLoop=0, hand=5, baseHand=5, handBonus=0, tactic=1, keepsBeat=0, gladesMarked={}, deedCount=11, discardCount=0, defeatedCities={}, deadDeckInventory={}, score={Glade=0, GraveYard=0},
												dummyCrystals={["Red"]=0, Blue=0, Green=0, ["White"]=0}}
							if scenarioList[gStates.scenarioRef][gStates.playersRef].dummyTacticSelection=="F" then
								params.position={-1.9, 0.96, -19.4}--if dummy draws first
								startPos[1]=1
								turnOrder[1]=dummyStats
							else
								params.position={-1.9, 0.96, -19.4-(gStates.playerCount*1.4)}--if dummy draw last
								startPos[gStates.playerCount+1]=1
								turnOrder[gStates.playerCount+1]=dummyStats
								turnOrder[gStates.playerCount+1].tactic=gStates.playerCount+1
								turnRef=gStates.playerCount+1
							end
						else--Mage Knights
							local duplicate=true
							while duplicate==true do
								duplicate=false
								turnRef=math.random(1, gStates.playerCount)
								if scenarioList[gStates.scenarioRef][gStates.playersRef].dummyTacticSelection=="F" then turnRef=turnRef+1 end
								if startPos[turnRef]==1 then duplicate=true else startPos[turnRef]=1 end
							end
							params.position={-1.9, 0.96, -19.4-((turnRef-1)*1.4)}
							turnOrder[turnRef]={seatPos=positionOrder[a],mage=gStates.positionMageKnight[positionOrder[a]], fame=0, fameGain=0, reputation=0, repGain=0, scoreLoop=0, level=1, levelUp=0, influence=6, hand=5, baseHand=5, handBonus=0, tactic=turnRef, keepsBeat=0, gladesMarked={}, deedCount=11, discardCount=0, combatIconHide="None", defeatedCities={}, levelUpComplete=false, avatarLocation="portal", deadDeckInventory={}, levelingStats={}, score={Glade=0, GraveYard=0}}
						end
					end

					--Player Deed Deck
					if i==2 then
						params.rotation={180, 0, 0}--Orient cards face down
						if (gStates.positionMageKnight[positionOrder[a]]=="nobody" or positionOrder[a]==5) then--Dummy and Volkare deck go in different spot
							params.position={-67.96+offsetPosition, 1.17, -43.17}
						end
						params.callback_function=function(obj) obj.shuffle() end
					end

					--Dummy Invetory Card
					if i==3 and (gStates.positionMageKnight[positionOrder[a]]~="nobody" and positionOrder[a]<5) then local destr=safeTakeObject("SetupGame",PlayerBag,params) destr.destruct() skip=1 end--Delete Dummy Inventory when this is a player

					--Skills Container or Volkare's Level Chart
					if i==4 then
						if (gStates.positionMageKnight[positionOrder[a]]=="nobody" or positionOrder[a]==5) then--Checks if this position is a dummy
							if gStates.positionMageKnight[5]=="Volkare" then
								params.position={39.16, 0.97, 35.00}
								params.guid="b2ec85"--Volkare Level Chart: explicit GUID pull rather than relying on bag order.
							else
								if gStates.playerCount==1 and gStates.dummyAllSkills==false then
									params.position={-78.12+offsetPosition, 1.6, -31.03}--Skills container Position
								else
									local destr=safeTakeObject("SetupGame",PlayerBag,params) destr.destruct() skip=1
								end
							end
						end
					end

					--Skill Refernce Card 1
					if i==5 and (gStates.positionMageKnight[positionOrder[a]]=="nobody" or positionOrder[a]==5) and ((gStates.positionMageKnight[5]=="Volkare" or gStates.playerCount~=1) or gStates.dummyAllSkills==true) then
						local destr=safeTakeObject("SetupGame",PlayerBag,params) destr.destruct() skip=1
					end

					--Skill Refernce Card 2
					if i==6 then
						if (gStates.positionMageKnight[positionOrder[a]]=="nobody" or positionOrder[a]==5) and ((gStates.positionMageKnight[5]=="Volkare" or gStates.playerCount~=1) or gStates.dummyAllSkills==true) then
							local destr=safeTakeObject("SetupGame",PlayerBag,params) destr.destruct() skip=1
						else
							params.callback_function=function(obj) obj.lock() end
							if (gStates.coop==0 or gStates.WarOfFourComp==true) and gStates.positionMageKnight[positionOrder[a]]~="Ymirgh" and gStates.positionMageKnight[positionOrder[a]]~="Malek" and gStates.positionMageKnight[positionOrder[a]]~="Duscenia" and gStates.positionMageKnight[positionOrder[a]]~="Mevok" and gStates.positionMageKnight[positionOrder[a]]~="Zirtae" then
								params.callback_function=function(ob) local obj=ob.setState(1) obj.lock() end
							end
						end
					end

					--Player Avater or Volkare's Wound Card
					if i==7 then
						if (gStates.positionMageKnight[positionOrder[a]]=="nobody" or positionOrder[a]==5) then--Checks if this position is a dummy
							if gStates.positionMageKnight[5]=="Volkare" then
								params.rotation={180, 0, 0}
								params.position={-67.96+offsetPosition, 1.17, -50.17}--Flip wound card over if Volkare
								params.callback_function=volkareSetup
							elseif proxyPlayerActive()==true then
								--Use one of the same four Portal-card positions as a normal player whenever one is free.
								--With four human players there is no fifth Portal position, so the Proxy starts on the Dummy board instead.
								local proxyPos,onPortal=proxySetupAvatarPosition()
								params.position=proxyPos
								params.callback_function=function(obj)
									obj.unlock()
									gStates.proxyAvatarOffMap=(onPortal~=true)
									local proxyIndex=proxyPlayerIndex()
									if proxyIndex~=nil and turnOrder[proxyIndex]~=nil then turnOrder[proxyIndex].avatarLocation=onPortal==true and "portal" or nil end
								end
							else
								local destr=safeTakeObject("SetupGame",PlayerBag,params) destr.destruct() skip=1
							end
						else
							--params.position[1]=params.position[1]-(offsetPosition/1.07)--Avatar
							local portalPosition={{-42.5, 1.3, -11.4}, {-45.5, 1.3, -13.2}, {-42.5, 1.3, -13.2}, {-45.5, 1.3, -11.4}, {-43.94, 1.3, -12.36}}
							params.position=portalPosition[a]
						end
					end

					--Fame Marker, Volkare's Terrain Tile or Dummy's Crystals. Dummy is Setup
					if i==8 then
						if (gStates.positionMageKnight[positionOrder[a]]=="nobody" or positionOrder[a]==5) then--Checks if this position is a dummy
							if positionOrder[a]<5 then
								getObjectFromGUID(deedDeckZones[positionOrder[a]]).setPosition({offsetPosition-68, 1.15, -43.20})
								getObjectFromGUID(deedDeckDiscardZones[positionOrder[a]]).setPosition({offsetPosition-77.21, 1.15, -43.20})
							end
							if gStates.positionMageKnight[5]=="Volkare" then
								local cityBag=getObjectFromGUID(GUID.bag.terrain.leftCity)
								if cityBag==nil then error("Volkare setup missing City terrain bag",2) end
								if gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz" or gStates.gameScenario=="Volkare's Quest" then
									--Keep the Camp out of the map zone until mapSetup is ready to reveal it.
									--Quest now uses the same staging rule so its Camp cannot begin a separate reveal timer.
									local bagPos=cityBag.getPosition()
									params.position={bagPos.x,bagPos.y+2,bagPos.z}
								else
									params.position={-12.0297, 2.0,  8.8586}--The War of Four camp tile position
								end
								terrainTiles["835c91"].hexFeature.center=""
								gStates.hexOverideSave["835c91"]={center=""}
								if gStates.randomTileOrientation==false then params.rotation={0, 180, 180} else params.rotation={0, math.random(1, 6)*60, 180} end
								params.guid="835c91"
								local obj=safeTakeObject("SetupGame",cityBag,params)
								if obj==nil then error("Volkare setup missing Camp terrain tile 835c91 from City terrain bag",2) end
								--The Camp originated as a special Volkare component and historically had no Terrain tag.
								--Now that it lives in the City terrain pool, normalize it before it ever reaches the map.
								if obj.hasTag("Terrain")~=true then obj.addTag("Terrain") end
								skip=1
							else
								local params={position={-69.4, 1.41, -36.5}, rotation={0, 30, 0}, smooth=false, index=0}
								if positionOrder[a]==5 then params.position[1]=params.position[1]-25.2 params.position[3]=params.position[3]+21.1 end
								params.position[1]=params.position[1]+offsetPosition
								for a=1, 3, 1 do
									params.position[1]=params.position[1]-(1.7)
									local obj=safeTakeObject("SetupGame",PlayerBag,params)
									obj.lock()
									local b=obj.getDescription()
									if scenarioList[gStates.scenarioRef][gStates.playersRef].dummyTacticSelection=="F" then
										turnOrder[1].dummyCrystals[b]=turnOrder[1].dummyCrystals[b]+1
									else
										turnOrder[gStates.playerCount+1].dummyCrystals[b]=turnOrder[gStates.playerCount+1].dummyCrystals[b]+1
									end
								end
								break
							end
						else
							params.position[1]=(params.position[1]-(offsetPosition/1.032))+(5.3*gStates.blitz)--Fame Marker
						end
					end

					--Reputation Marker or Volkare's Avatar
					local colorReputation={	{{34.02, 1.14, 21.26}, {34.50, 1.14, 22.57}, {34.99, 1.14, 23.91}, {33.53, 1.21, 19.98}},--(-2)
											{{36.70, 1.20, 20.25}, {37.33, 1.14, 21.45}, {38.02, 1.14, 22.63}, {36.11, 1.14, 19.04}},--(-1)
											{{39.87, 1.13, 19.41}, {38.79, 1.13, 18.75}, {41.16, 1.13, 19.20}, {40.33, 1.13, 20.87}},--(0)
											{{39.03, 1.13, 16.00}, {40.18, 1.13, 16.30}, {41.37, 1.13, 16.56}, {37.87, 1.13, 15.74}}}--(+1)
					if i==9 then
						if (gStates.positionMageKnight[positionOrder[a]]=="nobody" or positionOrder[a]==5) then--Checks if this position is a dummy
							if gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz" then
								params.position={-37.2305, 1.6, -5.6911}--Volkare's Return Avatar position
							else
								params.position={-12.0297, 1.6, 8.8586}--Volkare's Quest Avatar position
							end
							local obj=safeTakeObject("SetupGame",PlayerBag,params)
							--Volkare is stored in the Mage bag before the map exists. Keep him physical so the
							--starting terrain can lift/settle him normally; setup locks him only after map completion.
							if gStates.positionMageKnight[5]=="Volkare" and obj~=nil then obj.unlock() end
							skip=1
						else
							local blitzSub=gStates.blitz
							params.position=colorReputation[0+blitzSub-gStates.rampage+3][positionOrder[a]]--Reputation Marker
							turnOrder[turnRef].reputation=(0+blitzSub-gStates.rampage)*2
						end
					end

					-- or Volkare's Arrow Guide or Volkares Dice
					if i==10 then
						if ((positionOrder[a]<5 and gStates.positionMageKnight[positionOrder[a]]=="nobody" and gStates.positionMageKnight[5]=="Volkare") or gStates.positionMageKnight[positionOrder[a]]=="Volkare") then
							params.position={-72.89+offsetPosition,1.5,-33.0}--Volkare Dice
						end
					end

					--or Volkares Scenario Reference Card
					if i==11 then
						if (positionOrder[a]<5 and gStates.positionMageKnight[positionOrder[a]]=="nobody" and gStates.positionMageKnight[5]=="Volkare") or gStates.positionMageKnight[positionOrder[a]]=="Volkare" then
							params.position={-72.5+offsetPosition, 1.06, -48.23}
							params.callback_function=function(obj) obj.lock() end
							if gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz" then
								params.callback_function=function(ob) local obj=ob.setState(2) obj.lock() end
							end
						end
					end

					--Volkare's Marker
					if i==12 then
						if (positionOrder[a]<5 and gStates.positionMageKnight[positionOrder[a]]=="nobody" and gStates.positionMageKnight[5]=="Volkare") or gStates.positionMageKnight[positionOrder[a]]=="Volkare" then
							params.position={-76+offsetPosition, 1.16, -31}
							params.callback_function=function(obj) obj.lock() end
						else
							params.rotation={0.00, 180.00, 180.00}
						end
					end

					if i==13 then
						if (positionOrder[a]<5 and gStates.positionMageKnight[positionOrder[a]]=="nobody" and gStates.positionMageKnight[5]=="Volkare") or gStates.positionMageKnight[positionOrder[a]]=="Volkare" then
							if gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz" then
								params.position={-37.23, 2.5, -5.69}
								params.rotation={0.0, 210.0, 0.0}--Volkare's Return Guide position
								params.callback_function=function(guide)
									safeWaitCondition("SetupGame",function()
										guide.jointTo(getObjectFromGUID(volkare.model),{["type"]="Fixed"})
									end,function() return guide~=nil and guide.resting==true and getObjectFromGUID(volkare.model)~=nil end,10,function()
										error("SetupGame timed out waiting to attach Volkare's Return guide.",2)
									end)
								end
							else
								params.position={-12.03, 2.5, 8.86}--Volkare's Quest Guide position
								params.rotation={0.0, 210.0, 0.0}
								params.callback_function=function(guide)
									safeWaitCondition("SetupGame",function()
										guide.setState(2)
										safeWaitCondition("SetupGame",function()
											getObjectFromGUID("be2dc2").jointTo(getObjectFromGUID(volkare.model),{["type"]="Fixed"})
										end,function() return getObjectFromGUID("be2dc2")~=nil and getObjectFromGUID(volkare.model)~=nil end,10,function()
											error("SetupGame timed out waiting for Volkare's Quest guide state.",2)
										end)
									end,function() return guide~=nil and guide.resting==true and getObjectFromGUID(volkare.model)~=nil end,10,function()
										error("SetupGame timed out waiting to prepare Volkare's Quest guide.",2)
									end)
								end
							end
							skip=1
						end
					end

					--Volkare is Setup
					if i==13 and (gStates.positionMageKnight[positionOrder[a]]=="nobody" or positionOrder[a]==5) then break end

					if positionOrder[a]==5 and i~=1 then params.position[1]=params.position[1]-25.2 params.position[3]=params.position[3]+21.1 end
					if skip==0 then
						local obj=safeTakeObject("SetupGame",PlayerBag,params)
						if (i==4 or i==5 or i==10 or i==11 or i==13) and gStates.positionMageKnight[positionOrder[a]]~="nobody" and positionOrder[a]<5 then obj.lock() end--lock player board components
						if (i==1 or i==3 or i==4 or i==5 or i==11) and (gStates.positionMageKnight[positionOrder[a]]=="nobody" or positionOrder[a]==5) then obj.lock() end--lock dummy board components
						if i==1 then turnOrder[turnRef].turnOrderTokenGUID=obj.guid end
						if (i==4 and gStates.positionMageKnight[positionOrder[a]]~="nobody" and positionOrder[a]<=4) or (i==4 and gStates.playerCount==1) then
							turnOrder[turnRef].skillBagGUID=obj.guid
							--Hero Challenges reserve the prescribed first Skill before the Hero's remaining Skill bag is shuffled.
							if gStates.heroChallenges==true and positionOrder[a]<=4 and gStates.positionMageKnight[positionOrder[a]]~="nobody" then
								local challenge=heroChallengesData[turnOrder[turnRef].mage]
								if challenge~=nil then
									local reserved=obj.takeObject({guid=challenge.skillGUID,position={(positionOrder[a]*40)-113.0,1.5,-48.9},rotation={0,180,0},smooth=false})
									--turnOrder is re-sorted during play, so reserve by stable Mage Knight identity rather than array index.
									if reserved~=nil then reserved.lock() gStates.heroChallengeReservedSkills[turnOrder[turnRef].mage]=reserved.guid end
								end
							end
							obj.shuffle()
						end
						if i==8 and gStates.positionMageKnight[positionOrder[a]]~="nobody" and positionOrder[a]<=4 then turnOrder[turnRef].fameGUID=obj.guid end
						if i==9 and gStates.positionMageKnight[positionOrder[a]]~="nobody" and positionOrder[a]<=4 then turnOrder[turnRef].reputationGUID=obj.guid end
						if i==13 and gStates.positionMageKnight[positionOrder[a]]~="nobody" and positionOrder[a]<=4 then turnOrder[turnRef].commandGUID=obj.guid end
						local inventories={	["Arythea"]="https://steamusercontent-a.akamaihd.net/ugc/1688270498378077447/DA7FA05E7349C9E1C99C318032043429816C861D/",
											["Braevalar"]="https://steamusercontent-a.akamaihd.net/ugc/1688270498378077718/DCE81E61A3E1B96D8BA93A4F8793A10FB665FB6B/",
											["Goldyx"]="https://steamusercontent-a.akamaihd.net/ugc/1688270498378077961/390B23321D1B2E3F34B1A029FFB2FB9C84262763/",
											["Jormund"]="https://steamusercontent-a.akamaihd.net/ugc/1795241588983562972/1557BE3291E3A706D57FBFDBE5A72E7FAAB2CDF1/",
											["Mevok"]="https://steamusercontent-a.akamaihd.net/ugc/2546304515601825153/FC93E96C09CB79AC93C52094C1B5287D811FA482/",
											["Duscenia"]="https://steamusercontent-a.akamaihd.net/ugc/2546304515601824613/3B452F1B422F9671596713E2AFAAD60D41D3D16F/",
											["Malek"]="https://steamusercontent-a.akamaihd.net/ugc/14943218316842257893/D58F0F6FCC4FE321C759297C11AE9F56BE11B0FD/",
											["Krang"]="https://steamusercontent-a.akamaihd.net/ugc/1688270498378078687/F80D82EF2E26084CEB57089D002A0302D97DEC6B/",
											["Norowas"]="https://steamusercontent-a.akamaihd.net/ugc/1688270498378079060/8711BC1DD995631FD7EEEC2747ADB204C806CE5C/",
											["Tovak"]="https://steamusercontent-a.akamaihd.net/ugc/1688270498378079257/2B4D0055D769A2F0A24EEBC1940C0A50F834A9C0/",
											["Wolfhawk"]="https://steamusercontent-a.akamaihd.net/ugc/1688270498378079469/999F91445334DECE8125779EB46C1A5C46687A9D/",
											["Coral"]="https://steamusercontent-a.akamaihd.net/ugc/14667008316248124108/D5989267D0EA9DC649819CA8E597860FA8B9F92C/",
											["Zirtae"]="https://steamusercontent-a.akamaihd.net/ugc/17952541848407306110/B100358117F2DBF3F181B3FD347B14C77AA26308/",
											["Ymirgh"]="https://steamusercontent-a.akamaihd.net/ugc/1688270498378079688/47CE3F5B6A9F817FB562B5E9864E7F761CC62F97/"}
						if i==1 and gStates.positionMageKnight[positionOrder[a]]~="nobody" and positionOrder[a]<=4 then
							local inventoryImage=inventories[gStates.positionMageKnight[positionOrder[a]]]
							if inventoryImage~=nil then getObjectFromGUID(playerBoard[positionOrder[a]]).addDecal({name="Mage Inventory", url=inventoryImage, position={1.735, 0.11, -0.32}, rotation={90.0, 180.0, 0.0}, scale={1.164, 1.219, 10}}) end
							turnOrder[turnRef].playerBoardGUID=playerBoard[positionOrder[a]]
						end
					end
				end
				if gStates.positionMageKnight[positionOrder[a]]=="Mevok" then
					local obj=safeTakeObject("SetupGame",PlayerBag,{guid="32bc89", position={-77.30+offsetPosition, 1.05, -53.65}, smooth=false, setColorTint="", callback_function=function(obj) obj.lock() end})
					local obj=safeTakeObject("SetupGame",PlayerBag,{guid="2dbfde", position={-73.90+offsetPosition, 1.05, -53.65}, smooth=false, setColorTint="", callback_function=function(obj) obj.lock() end})
				end
				PlayerBag.destruct()
			else
				--clean up that positions area
				getObjectFromGUID(deedDeckZones[positionOrder[a]]).destruct()
				getObjectFromGUID(deedDeckDiscardZones[positionOrder[a]]).destruct()
				getObjectFromGUID(colorBand[positionOrder[a]]).destruct()
				if a~=5 then getObjectFromGUID(playerBoard[positionOrder[a]]).destruct() end
				if getObjectFromGUID(playAreaGuideText[positionOrder[a]])~=nil then getObjectFromGUID(playAreaGuideText[positionOrder[a]]).destruct() end
				if getObjectFromGUID(playAreaGuideBackground[positionOrder[a]])~=nil then getObjectFromGUID(playAreaGuideBackground[positionOrder[a]]).destruct() end
			end
		--end, time)
		--if a<5 then
		--	if (gStates.positionMageKnight[positionOrder[a+1]]~="nobody" and positionOrder[a+1]<=4) or (gStates.positionMageKnight[5]~="nobody" and DummyPlayedTiming==0) then
		--		time=time+delay
		--	end
		--	if (gStates.positionMageKnight[positionOrder[a+1]]=="nobody" or positionOrder[a+1]==5) and gStates.positionMageKnight[5]~="nobody" then DummyPlayedTiming=1 end
		--end
	end
	--The Proxy uses a visible copy of their Mage Knight's infinite Shield bag beside the Dummy setup,
	--plus the two Apocalypse Proxy reference cards immediately to the right of the Skill reference cards.
	if proxyPlayerActive()==true then
		safeWaitCondition("SetupGame",function()
			proxySetupReferenceCards()
			proxySetupShieldBag()
			safeWaitCondition("SetupGame",function()
				gStates.proxySetupReady=true
			end,function()
				local shield=gStates.proxyShieldBagGUID~=nil and getObjectFromGUID(gStates.proxyShieldBagGUID) or nil
				return getObjectFromGUID("0e855c")~=nil and getObjectFromGUID("dbf566")~=nil and shield~=nil
			end,10,function() error("SetupGame timed out waiting for Proxy reference components.",2) end)
		end,function()
			return getObjectFromGUID(dummyBoard)~=nil and getObjectFromGUID(GUID.bag.apocalypseDragon)~=nil
		end,10,function() error("SetupGame timed out waiting for the Proxy setup sources.",2) end)
	end
	gStates.playerSetupReady=true
end

--Setup additional volkare components (Skill for Solo, Unit Crytals, And Monster Pugs)
function volkareSetup()
	--Add wounds to Volkare's Deck
	local VolkareWounds=20
	local PlayerBag={}
	if gStates.gameScenario=="The War of Four" then gStates.volkareRaceLevel=3 end
	if gStates.gameScenario=="Volkare's Quest" or gStates.gameScenario=="The War of Four" then VolkareWounds=24-(4*gStates.volkareRaceLevel) else VolkareWounds=21-(3*gStates.volkareRaceLevel)-(2*gStates.blitz) end
	if gStates.gameScenario=="Custom" then VolkareWounds=0 end
	for i=1, VolkareWounds, 1 do
		getObjectFromGUID(GUID.deck.volkare).putObject(getObjectFromGUID("a8e73d").clone({position={getObjectFromGUID(GUID.deck.volkare).getPosition()[1], -2, getObjectFromGUID(GUID.deck.volkare).getPosition()[3]}}))--The wound card to Volkare's Deck
	end
	getObjectFromGUID(GUID.deck.volkare).shuffle()
	if gStates.gameScenario~="Custom" then getObjectFromGUID("a8e73d").destruct() end--The wound card

	--Add a random skill set if solo playing
	if gStates.playerCount==1 and gStates.volkareSkills~="All Skills" then
		local duplicate=true
		local randomMKIndex=1
		if gStates.volkareSkills=="Random" then
			while duplicate==true do
				duplicate=false
				randomMKIndex=math.random(1, #mageKnights-3)
				local randomMK=mageKnights[randomMKIndex].mage
				for i=1, 4, 1 do
					if randomMK==gStates.positionMageKnight[i] then duplicate=true end
				end
				if gStates.useCustomMageKnights==false and customMages[randomMK]~=nil then duplicate=true end
				if gStates.riseOfTheForgemasters~=3 and randomMK=="Jormund" then duplicate=true end
			end
		else
			for index, mageDetails in ipairs(mageKnights) do
				if mageDetails.mage==gStates.volkareSkills then randomMKIndex=index break end
			end
		end
		local PlayerBag=getObjectFromGUID(mageKnights[randomMKIndex].bag).clone({position={getObjectFromGUID(dummyBoard).getPosition()[1]-10.16, 5.15, getObjectFromGUID(dummyBoard).getPosition()[3]+12.14}})
		local skillBag=PlayerBag.takeObject({index=12})--Skill Container
		skillBag.lock()
		turnOrder[2].skillBagGUID=skillBag.guid--he doesn't get skills in more than solo
		skillBag.setPosition({getObjectFromGUID(dummyBoard).getPosition()[1]-5.62, 1.6, getObjectFromGUID(dummyBoard).getPosition()[3]+6.97})
		skillBag.shuffle()
		local skillRef=PlayerBag.takeObject({index=10})
		skillRef.lock()
		skillRef.setPosition({getObjectFromGUID(dummyBoard).getPosition()[1]-4.4, 1.05, -49})
		local skillRef=PlayerBag.takeObject({index=10})
		skillRef.lock()
		skillRef.setPosition({getObjectFromGUID(dummyBoard).getPosition()[1]-7.8, 1.05, -49})
		PlayerBag.destruct()
	end

	--Add Volkare unit crystals based on Player count and Race Level.
	--Each die face owns a physical Unit-offer slot; the broad offer zone replaces the old slot zones.
	gStates.volkareUnitCrystals={}
	if gStates.gameScenario~="The War of Four" then
		local VolkareUnits=gStates.playerCount+(gStates.volkareRaceLevel-1)
		local PlayerBag=getObjectFromGUID(GUID.bag.volkare).clone()
		local obj=PlayerBag.takeObject({position={37, 1.29, -1.14}, guid="1212f3"})--Crystal Container
		obj.shuffle()
		for i=1, VolkareUnits, 1 do
			local obj2=obj.takeObject()
			obj2.lock()
			obj2.setPosition({36.0-(4.8*(i-1)), 1.29, -1.15})
			obj2.setRotation({0, 30, 0})
			gStates.volkareUnitCrystals[obj2.getName()]={slot=i,crystalGUID=obj2.guid}
		end
		PlayerBag.destruct()
		obj.destruct()
	end

	--add unit tokens based on Volkare's Level
	gStates.volkareLevel=gStates.cityLevels[#gStates.cityLevels]
	table.remove(gStates.cityLevels, #gStates.cityLevels)
	if gStates.monsterSetupReady==true then
		volkareArmy()
	else
		safeWaitCondition("SetupGame",volkareArmy,function() return gStates.monsterSetupReady==true end,10,function()
			error("SetupGame timed out waiting for monster piles before building Volkare's Army.",2)
		end)
	end

	--Move reminder Tokens
	getObjectFromGUID(GUID.bag.volkare).takeObject({rotation={0.0, 180.0, 0.0}, position={getObjectFromGUID(cityScriptZones[volkare.discZone].cityCard).getPosition()[1]+2.2, 1.5, getObjectFromGUID(cityScriptZones[volkare.discZone].cityCard).getPosition()[3]+2.2}, guid=GUID.bag.volkareReminder})
end

--add unit tokens based on Volkare's Level
function volkareArmy()
	gStates.cityMonsterQty[volkare.model]={}
	if gStates.gameScenario~="Custom" then
		local VolkareArmy={	{},		  {},		{},		  {0,1,1,2},{1,0,1,2}, {1,0,1,3}, {1,0,2,2}, {1,1,2,2}, {1,1,2,3}, {1,1,2,5}, {2,0,2,5}, {2,0,2,6}, {2,0,2,7}, {2,0,3,6}, {2,1,3,6},
							{2,2,4,4},{2,2,4,5},{2,2,4,6},{2,2,4,8},{2,2,4,10},{3,1,4,10},{4,0,4,10},{4,0,4,11},{4,0,4,12},{4,0,4,13},{4,0,4,14},{4,0,5,13},{4,0,6,12},{4,1,6,12},{4,2,6,12}}
		--{no. White Units, No. Gray Units, No. Red Units, No. Green Units}(Level 4 to 15 shown, other levels made by adding levels togeather)
		local PugDraw={monsterPiles.white,monsterPiles.gray,monsterPiles.red,monsterPiles.green}
		--{White Unit Bag, Gray Unit Bag, Red Unit Bag, Green Unit Bag}
		if (gStates.volkareLevel<=20 and gStates.removeShadesOfTezlaMonsters==true and gStates.removeLostLegionExpansion==true) or (gStates.volkareLevel<=30 and (gStates.removeShadesOfTezlaMonsters~=true or gStates.removeLostLegionExpansion==false)) or (gStates.removeShadesOfTezlaMonsters~=true and gStates.removeLostLegionExpansion==false) then
			for i=1, 4, 1 do
				local LoopsNeeded=math.ceil(gStates.volkareLevel/30)
				local levelConverted=math.floor(gStates.volkareLevel/LoopsNeeded)
				local leftover=gStates.volkareLevel-(LoopsNeeded*levelConverted)+levelConverted
				getObjectFromGUID(PugDraw[i]).shuffle()
				for x=1, LoopsNeeded, 1 do
					if x==LoopsNeeded then levelConverted=leftover end
					for a=1, VolkareArmy[levelConverted][i], 1 do
						local params={position={0, 0, 0}, rotation={0, 180, 180}}
						params.position[1]=getObjectFromGUID(dummyBoard).getPosition()[1]+(0.2*a)+(2.2*x)+2.5
						params.position[2]=getObjectFromGUID(dummyBoard).getPosition()[2]+(0.2*a)+1
						params.position[3]=getObjectFromGUID(dummyBoard).getPosition()[3]+(0.2*a)+(2.2*i)-2.9
						local obj2=getObjectFromGUID(PugDraw[i]).takeObject(params)
						gStates.cityMonsterQty[volkare.model][obj2.guid]="alive"
						gStates.monsterPlayLocation[obj2.guid]={params.position[1], params.position[2], params.position[3]}
					end
				end
			end
		else
			broadcastToAll("{en}Volkare's Army is too large with your setup. You will need to create it when you fight him for the first time{ru}Армия Волкара слишком велика с вашей настройкой. Вам нужно будет создать ее, когда вы сразитесь с ним в первый раз{zh-tw}现在不用设置沃里卡的军队, 你将在首次和他交锋时设置这些{zh-cn}现在不用设置沃里卡的军队, 你将在首次和他交锋时设置这些{ko}볼케어의 군대 규모가 너무 큽니다. 플레이어가 직접 첫 전투 세팅을 준비해주세요.{es}El ejército de Volkare es demasiado grande con tu configuración. Necesitarás crearlo cuando luches contra él por primera vez.{fr}L'armée de Volkare est trop grande avec votre configuration. Vous devrez le créer lorsque vous le combattrez pour la première fois{pt-br}O exército de Volkare é muito grande com a sua configuração. Você precisará criá-lo quando você for lutar com ele pela primeira vez{de}Volkare's Armee ist mit deiner Aufstellung zu groß. Du musst sie erstellen, wenn du zum ersten Mal gegen ihn kämpfst.", warningColor)
		end
		--Change his models level
		getObjectFromGUID(volkare.model).setCustomObject({diffuse=cityLevelImage[volkare.model][math.floor(gStates.volkareLevel/math.ceil(gStates.volkareLevel/15))]})
		getObjectFromGUID(volkare.model).reload()
		safeWaitCondition("SetupGame",function()
			local model=getObjectFromGUID(volkare.model)
			--This flag means the model reload is complete, not that Volkare is ready to be frozen.
			--The initial map cannot start until this flag is true, so locking here would guarantee
			--that he is frozen on the bare table before his starting terrain is constructed.
			if model~=nil then model.unlock() end
			gStates.volkareSetupReady=true
		end,function()
			local model=getObjectFromGUID(volkare.model)
			return model~=nil and model.resting==true
		end,10,function() error("SetupGame timed out waiting for Volkare's model to reload.",2) end)
		cityLevelButtons(volkare.model, "Volkar")
	else
		gStates.volkareSetupReady=true
	end
end

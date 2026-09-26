-- End-game scoring and Hero Challenge scoring runtime.

--Hero Challenges are an optional Apocalypse-rulebook overlay. Keep all scoring/objective
--math here so the underlying scenario can retain its normal victory and end conditions.
local function heroChallengeActive(playerIndex)
	return gStates~=nil and gStates.heroChallenges==true and turnOrder[playerIndex]~=nil and heroChallengesData[turnOrder[playerIndex].mage]~=nil
end

local function heroChallengeRecordCard(stats, guid)
	if stats==nil or guid==nil or stats.cardSeen[guid]==true then return end
	stats.cardSeen[guid]=true
	local card=gameCards[guid]
	if card==nil then return end
	if card.cardType=="Starting" then stats.basicActions=stats.basicActions+1 end
	if card.cardType=="Advanced Action" then
		local colors={}
		for _,color in ipairs(card.color or {}) do colors[color]=true end
		stats.aaCards[guid]=colors
	end
end

local function heroChallengeCrystalColor(obj)
	if obj==nil then return nil end
	local note=obj.getGMNotes()
	if note=="Red" or note=="Blue" or note=="Green" or note=="White" then return note end
	local name=tostring(obj.getName() or "")
	for _,color in ipairs({"Red","Blue","Green","White"}) do if name:find(color,1,true)~=nil then return color end end
	return nil
end

--Hero Challenge scoring counts only Puppets explicitly accepted by the Puppet Master system.
local function heroChallengePuppetFame(obj)
	if obj==nil or gStates.puppetMasterPuppets==nil then return nil end
	local record=gStates.puppetMasterPuppets[obj.guid]
	if record==nil or record.played==true then return nil end
	local source=record.sourceGUID~=nil and monsterPugs[record.sourceGUID] or nil
	local fame=source~=nil and tonumber(source.fame) or 0
	if fame>0 then return fame end
	return nil
end

--A dual-colour Advanced Action may satisfy only one colour. Matching four colours to four distinct
--cards implements that directly instead of simply checking whether every colour appears somewhere.
local function heroChallengeAACoversAllColors(stats)
	if stats==nil then return false end
	local colors={"Red","Blue","Green","White"}
	local used={}
	local function assign(index)
		if index>#colors then return true end
		for guid,cardColors in pairs(stats.aaCards or {}) do
			if used[guid]~=true and cardColors[colors[index]]==true then
				used[guid]=true
				if assign(index+1)==true then return true end
				used[guid]=nil
			end
		end
		return false
	end
	return assign(1)
end

local function heroChallengeFinalMapPosition(playerIndex)
	local player=turnOrder[playerIndex]
	if player==nil then return nil end
	--Shared map spaces park inactive avatars off-map. Score the logical hex, not the storage position.
	if againstHorsemenPlayerAtCentralGlade(player)==true then return againstHorsemenCentralGladePosition(1.5) end
	if player.avatarLocation=="portal" then
		local startTile=getObjectFromGUID(startTerrain.wedge) or getObjectFromGUID(startTerrain.open)
		if startTile~=nil then
			local pos=startTile.getPosition()
			pos[2]=1.5
			return pos
		end
	end
	return fracturedLandsTeleportSourcePosition(playerIndex)
end

local function heroChallengeFinalTerrainBonus(playerIndex, objectsInPlay)
	if heroChallengeActive(playerIndex)~=true or turnOrder[playerIndex].mage~="Braevalar" then return 0 end
	local pos=heroChallengeFinalMapPosition(playerIndex)
	if pos==nil then return 0 end
	local _,_,_,_,hexType=terrainHexAtPosition(pos,objectsInPlay)
	local nightCost={plains=2,hills=3,forest=5,wasteland=4,desert=3,swamp=5,lake=2,mountain=5,city=2}
	return nightCost[string.lower(tostring(hexType or ""))] or 0
end

local function heroChallengeBeatingScore(playerIndex)
	if heroChallengeActive(playerIndex)==true and turnOrder[playerIndex].mage=="Arythea" then return 0 end
	return turnOrder[playerIndex].score.Wound*2
end

local function heroChallengeKnowledgeScore(playerIndex)
	local score=turnOrder[playerIndex].score
	local mage=heroChallengeActive(playerIndex) and turnOrder[playerIndex].mage or nil
	local aaRate=mage=="Braevalar" and 2 or 1
	local spellRate=mage=="Goldyx" and 3 or 2
	return (score.AdvanceAction*aaRate)+(score.Spell*spellRate)
end

local function heroChallengeLootScore(playerIndex)
	local score=turnOrder[playerIndex].score
	local mage=heroChallengeActive(playerIndex) and turnOrder[playerIndex].mage or nil
	local artifactRate=mage=="Coral" and 4 or 2
	local crystalScore=(mage=="Goldyx" or mage=="Coral") and score.Crystal or math.floor(score.Crystal/2)
	return (score.Artifact*artifactRate)+crystalScore+score.Potion
end

local function heroChallengeLeaderScore(playerIndex)
	local score=turnOrder[playerIndex].score
	local mage=heroChallengeActive(playerIndex) and turnOrder[playerIndex].mage or nil
	local healthy=mage=="Norowas" and score.UnitsLevel*2 or score.UnitsLevel
	local wounded=mage=="Arythea" and score.WoundedUnitsRawLevel or score.WoundedUnitsLevel
	return healthy+wounded
end

local function heroChallengeAdventurerScore(playerIndex, ref)
	local score=turnOrder[playerIndex].score
	local wolfhawk=heroChallengeActive(playerIndex) and turnOrder[playerIndex].mage=="Wolfhawk"
	if ref==2 then
		return (score.DungeonTomb*4)+(score.SpawningDen+score.Ruin+score.Maze+score.ZigguratPyramid)*(wolfhawk and 4 or 2)
	end
	if ref==4 then
		return (score.ZigguratPyramid*5)+(score.SpawningDen+score.Ruin+score.Maze+score.DungeonTomb)*(wolfhawk and 4 or 2)
	end
	return (score.DungeonTomb+score.SpawningDen+score.Ruin+score.Maze+score.ZigguratPyramid)*(wolfhawk and 4 or 2)
end

local function heroChallengeConquerorScore(playerIndex)
	local score=turnOrder[playerIndex].score
	local rate=heroChallengeActive(playerIndex) and turnOrder[playerIndex].mage=="Tovak" and 4 or 2
	return ((score.Keep+score.MageTower+score.Monastery)*rate)+score.VolkareCamp
end

local function heroChallengeEvaluate(playerIndex, objectsInPlay)
	if heroChallengeActive(playerIndex)~=true then return nil end
	local playerData=turnOrder[playerIndex]
	local score=playerData.score
	local stats=playerData.heroChallengeStats or {crystalColors={},puppetFame={},basicActions=0,aaCards={}}
	local complete=false
	local details=""
	local extraBonus=0
	if playerData.mage=="Arythea" then
		local wounds=score.Wound+score.WoundedUnits
		complete=wounds>=10 details="Wounds "..tostring(wounds).." / 10"
	elseif playerData.mage=="Goldyx" then
		local colors=0 for _,color in ipairs({"Red","Blue","Green","White"}) do if stats.crystalColors[color]==true then colors=colors+1 end end
		complete=score.Spell>=4 and colors==4 details="Spells "..tostring(score.Spell).." / 4; crystal colours "..tostring(colors).." / 4"
	elseif playerData.mage=="Norowas" then
		local levels=score.UnitsLevel+score.WoundedUnitsRawLevel
		complete=levels>=10 details="Unit levels "..tostring(levels).." / 10"
	elseif playerData.mage=="Tovak" then
		local shields=score.Keep+score.MageTower+score.Monastery+score.VolkareCamp
		complete=shields>=4 details="Conqueror Shields "..tostring(shields).." / 4"
	elseif playerData.mage=="Wolfhawk" then
		local shields=score.DungeonTomb+score.SpawningDen+score.Ruin+score.Maze+score.ZigguratPyramid
		complete=shields>=4 details="Adventurer Shields "..tostring(shields).." / 4"
	elseif playerData.mage=="Krang" then
		local count=0 local highest=0
		for fame,_ in pairs(stats.puppetFame) do count=count+1 if fame>highest then highest=fame end end
		complete=count>=4 details="Puppet Master Fame values "..tostring(count).." / 4"
		extraBonus=highest+(count*2)
	elseif playerData.mage=="Braevalar" then
		local colors=heroChallengeAACoversAllColors(stats)
		complete=stats.basicActions>=16 and colors==true
		details="Basic Actions "..tostring(stats.basicActions).." / 16; four AA colours "..(colors and "yes" or "no")
		extraBonus=heroChallengeFinalTerrainBonus(playerIndex,objectsInPlay)
	elseif playerData.mage=="Coral" then
		complete=score.Artifact>=3 and score.Crystal>=4 details="Artifacts "..tostring(score.Artifact).." / 3; crystals "..tostring(score.Crystal).." / 4"
	end
	return {complete=complete,details=details,extraBonus=extraBonus}
end

scoreViewing={}
function closePanel(player, mouseButton, id)
	if mouseButton=="-1" then
		UI.setAttribute("helpButtonReal", "interactable", "true")
		UI.setAttribute("Setup", "active", "false")
		UI.setAttribute("helpButtonRealImage", "image", "Sliced Button/Button New Active")
		UI.setAttribute("helpButtonReal", "interactable", "true")
		local temp={}
		for a=1, #scoreViewing, 1 do
			if scoreViewing[a]~=player.color then temp[#temp+1]=scoreViewing[a] end
		end
		scoreViewing=temp
		if #scoreViewing<1 then
			UI.hide("ScoreBoard")
			scoreViewing={}
		else
			setUIVisibility("ScoreBoard",scoreViewing)
		end
	end
end

function displayScore(player, mouseButton, id)
	if mouseButton=="-1" then
		--Count all objects required for scoring
		local seatRecord=5
		for a=1, #turnOrder, 1 do
			if turnOrder[a].mage==gStates.positionMageKnight[5] then
				seatRecord=turnOrder[a].seatPos
				turnOrder[a].seatPos=5
				break
			end
		end
		table.sort(turnOrder, function (k1, k2) return k1.seatPos<k2.seatPos end)
		for a=1, #turnOrder, 1 do
			if turnOrder[a].mage==gStates.positionMageKnight[5] then
				turnOrder[a].seatPos=seatRecord
				break
			end
		end
		local foundRelic=0--Not individually scored
		local coopGraveYard=0
		local objectsInPlay=getObjectFromGUID(mapArea).getObjects()
		table.sort(objectsInPlay, function (k1, k2) return k1.getPosition()[2]>k2.getPosition()[2] end)
		for a=1, #turnOrder, 1 do
			if turnOrder[a].mage~=gStates.positionMageKnight[5] then
				local obj={}
				local cardDupeCheck={}--Scoring zones can overlap; de-duplicate every physical/deck card by GUID.
				turnOrder[a].heroChallengeStats={cardSeen={},basicActions=0,aaCards={},crystalColors={},puppetFame={}}
				local heroStats=turnOrder[a].heroChallengeStats
				for b, c in pairs(objectsInPlay) do obj[#obj+1]=c end
				--Look for Cards
				for b, c in pairs(getObjectFromGUID(deedDeckZones[turnOrder[a].seatPos]).getObjects()) do obj[#obj+1]=c end
				for b, c in pairs(getObjectFromGUID(deedDeckDiscardZones[turnOrder[a].seatPos]).getObjects()) do obj[#obj+1]=c end
				for b, c in pairs(getObjectFromGUID(handZones[turnOrder[a].seatPos]).getObjects()) do obj[#obj+1]=c end
				for b, c in pairs(getObjectFromGUID(playerPlayAreas[turnOrder[a].seatPos]).getObjects()) do obj[#obj+1]=c end
				--look for Crystals, rewards and Hero Challenge inventory trophies
				local inventoryObjects=getObjectFromGUID(playerCrystalAreas[turnOrder[a].seatPos]).getObjects()
				for b, c in pairs(inventoryObjects) do
					obj[#obj+1]=c
					if heroChallengeActive(a)==true then
						local crystalColor=heroChallengeCrystalColor(c)
						if crystalColor~=nil then heroStats.crystalColors[crystalColor]=true end
						if turnOrder[a].mage=="Krang" then
							local puppetFame=heroChallengePuppetFame(c)
							if puppetFame~=nil then heroStats.puppetFame[puppetFame]=true end
						end
					end
				end
				--look for Units
				local playerUnits=getObjectFromGUID(playerUnitAreas[turnOrder[a].seatPos]).getObjects()
				for b, c in pairs(playerUnits) do obj[#obj+1]=c end
				--Zero out any existing scores
				local scoreVariable={"AdvanceAction", "Spell", "Artifact", "Wound", "Crystal", "Potion", "Units", "UnitsLevel", "WoundedUnits", "WoundedUnitsLevel", "WoundedUnitsRawLevel", "Keep", "Reward", "GraveYard", "Glade",
									"MageTower", "Monastery", "VolkareCamp", "DungeonTomb", "SpawningDen", "Ruin", "Maze", "Relic", "CountryMine", "CoreMine", "ZigguratPyramid", "Destroyed",
									"Zig1", "Zig2", "Zig3", "Pyr1", "Pyr2", "Pyr3"}
				for b, c in pairs(scoreVariable) do
					turnOrder[a].score[c]=0
				end
				--count found objects
				for b, c in pairs(obj) do
					--Count Card Types
					if c.type=="Card" then
						heroChallengeRecordCard(heroStats,c.guid)
						if c.getGMNotes()=="Advanced Action" and cardDupeCheck[c.guid]==nil then turnOrder[a].score.AdvanceAction=turnOrder[a].score.AdvanceAction+1 cardDupeCheck[c.guid]=1 end
						if c.getGMNotes()=="Spell" and cardDupeCheck[c.guid]==nil then turnOrder[a].score.Spell=turnOrder[a].score.Spell+1 cardDupeCheck[c.guid]=1 end
						if c.getGMNotes()=="Artifact" and cardDupeCheck[c.guid]==nil then turnOrder[a].score.Artifact=turnOrder[a].score.Artifact+1 cardDupeCheck[c.guid]=1 end
						if c.getGMNotes()=="Wound" and cardDupeCheck[c.guid]==nil then turnOrder[a].score.Wound=turnOrder[a].score.Wound+1 cardDupeCheck[c.guid]=1 end
						if gameCardType(c)=="Regular Unit" or gameCardType(c)=="Elite Unit" then
							--Look for a wound whose nearest Unit is this card. This remains unambiguous after elastic compression.
							local found=false
							for e, woundToken in pairs(playerUnits) do
								if woundToken.getGMNotes()=="Unit Wound" then
									local nearestUnit, distance=unitLayoutNearestUnit(playerUnits,woundToken.getPosition()[1])
									if nearestUnit~=nil and nearestUnit.guid==c.guid and distance<=1.7 then
										turnOrder[a].score.WoundedUnits=turnOrder[a].score.WoundedUnits+1
										turnOrder[a].score.WoundedUnitsLevel=turnOrder[a].score.WoundedUnitsLevel+math.floor(gameCards[c.guid].level/2)
										turnOrder[a].score.WoundedUnitsRawLevel=turnOrder[a].score.WoundedUnitsRawLevel+gameCards[c.guid].level
										found=true
										break
									end
								end
							end
							if found==false then
								turnOrder[a].score.Units=turnOrder[a].score.Units+1
								turnOrder[a].score.UnitsLevel=turnOrder[a].score.UnitsLevel+gameCards[c.guid].level
							end
						end
				 	end
					if c.type=="Deck" then
						for _, card in pairs(c.getObjects()) do
							heroChallengeRecordCard(heroStats,card.guid)
							if cardDupeCheck[card.guid]==nil then
								if card.gm_notes=="Advanced Action" then turnOrder[a].score.AdvanceAction=turnOrder[a].score.AdvanceAction+1 cardDupeCheck[card.guid]=1
								elseif card.gm_notes=="Spell" then turnOrder[a].score.Spell=turnOrder[a].score.Spell+1 cardDupeCheck[card.guid]=1
								elseif card.gm_notes=="Artifact" then turnOrder[a].score.Artifact=turnOrder[a].score.Artifact+1 cardDupeCheck[card.guid]=1
								elseif card.gm_notes=="Wound" then turnOrder[a].score.Wound=turnOrder[a].score.Wound+1 cardDupeCheck[card.guid]=1 end
							end
						end
					end
					--count Crystals
					if c.type=="Figurine" then
						if c.getPosition()[1]<turnOrder[a].seatPos*40-109.76 and c.getPosition()[3]<-31 then turnOrder[a].score.Crystal=turnOrder[a].score.Crystal+1 end
					end
					--count Destroyed Tokens
					if c.getGMNotes()=="Destroyed" then
						if c.getPosition()[1]<turnOrder[a].seatPos*40-109.76 and c.getPosition()[3]<-31 then turnOrder[a].score.Destroyed=turnOrder[a].score.Destroyed+1 end
					end
					--count Faction Rewards
					if c.type=="Tile" then
						if c.getPosition()[1]<turnOrder[a].seatPos*40-109.76 and c.getPosition()[3]<-31 then
							if c.getName()~="Red Potion" and c.getName()~="Blue Potion" and c.getName()~="Green Potion" and c.getName()~="White Potion" then
								if c.getGMNotes()=="Dark Crusader Reward" or c.getGMNotes()=="Elementalist Reward" or c.getGMNotes()=="Apocalypse Cult Reward" or c.getGMNotes()=="Council of the Void Reward" then turnOrder[a].score.Reward=turnOrder[a].score.Reward+1 end
							else
								turnOrder[a].score.Potion=turnOrder[a].score.Potion+1
							end
						end
					end
					--Count Shield tokens. Pursuit shields score only as Pursuits, never also as the printed site below.
					if c.getName()=="Shield" and c.getDescription()==turnOrder[a].mage then
						if volkarePursuitShieldRegistered(c)==true then
							turnOrder[a].score.VolkareCamp=turnOrder[a].score.VolkareCamp+1
						else
							local found=false
						local shieldPos=c.getPosition()
						local locatedTerrain, locatedBearing, hexCenter, hexFeature=terrainHexAtPosition(shieldPos, objectsInPlay)
						--Destroyed Sites no longer exist for gameplay, but their existing Shields still score
						--as the original printed site. Recover that saved feature for scoring only.
						if hexFeature=="destroyed" and locatedTerrain~=nil and locatedBearing~=nil then
							for _,destroyedData in pairs(gStates.destroyedSites or {}) do
								if destroyedData.terrainTile==locatedTerrain.guid and destroyedData.hexAngle==locatedBearing then
									hexFeature=destroyedData.hexFeature
									break
								end
							end
						end
						for e, terTile in pairs(objectsInPlay) do
							local tilePos=terTile.getPosition()
							local shieldToTileDist=math.sqrt(((shieldPos[1]-tilePos[1])^2)+((shieldPos[3]-tilePos[3])^2))
							if terTile==locatedTerrain then
								found=true
								if hexFeature=="keep" then turnOrder[a].score.Keep=turnOrder[a].score.Keep+1 end
								if hexFeature=="mage tower" then turnOrder[a].score.MageTower=turnOrder[a].score.MageTower+1 end
								if hexFeature=="monastery" then turnOrder[a].score.Monastery=turnOrder[a].score.Monastery+1 end
								if hexFeature=="ruin" then turnOrder[a].score.Ruin=turnOrder[a].score.Ruin+1 end
								if hexFeature=="glade" then turnOrder[a].score.Glade=turnOrder[a].score.Glade+1 end
								if hexFeature=="dungeon" or hexFeature=="tomb" then turnOrder[a].score.DungeonTomb=turnOrder[a].score.DungeonTomb+1 end
								if hexFeature=="monster den" or hexFeature=="spawning grounds" then turnOrder[a].score.SpawningDen=turnOrder[a].score.SpawningDen+1 end
								if hexFeature=="maze" or hexFeature=="labyrinth" then turnOrder[a].score.Maze=turnOrder[a].score.Maze+1 end
								if hexFeature=="ziggurat" or hexFeature=="pyramid" then
									if gStates.coop==1 then
										turnOrder[a].score.ZigguratPyramid=turnOrder[a].score.ZigguratPyramid+1
									else
										local floor=zigguratPyramidFloorFromPosition(terTile, hexCenter, shieldPos)
										if floor==1 then
											if hexFeature=="ziggurat" then turnOrder[a].score.Zig1=turnOrder[a].score.Zig1+1 else turnOrder[a].score.Pyr1=turnOrder[a].score.Pyr1+1 end
										elseif floor==3 then
											if hexFeature=="ziggurat" then turnOrder[a].score.Zig3=turnOrder[a].score.Zig3+1 else turnOrder[a].score.Pyr3=turnOrder[a].score.Pyr3+1 end
										else
											if hexFeature=="ziggurat" then turnOrder[a].score.Zig2=turnOrder[a].score.Zig2+1 else turnOrder[a].score.Pyr2=turnOrder[a].score.Pyr2+1 end
										end
										turnOrder[a].score.ZigguratPyramid=turnOrder[a].score.ZigguratPyramid+1
									end
								end
								if ((hexFeature or ""):sub(1,4)=="city" or hexFeature=="Volkare's Camp") and gStates.gameScenario=="The Lost Relic Blitz" then turnOrder[a].score.Relic=turnOrder[a].score.Relic+1 foundRelic=foundRelic+1 end
								if hexFeature=="mine" and gStates.gameScenario=="Mines Liberation" then
									if terrainTiles[terTile.guid].tileType=="core" then
										turnOrder[a].score.CoreMine=turnOrder[a].score.CoreMine+1
									else
										turnOrder[a].score.CountryMine=turnOrder[a].score.CountryMine+1
									end
								end
							end
							if shieldToTileDist<1 then
								--dungeons for Dungeon Lords
								if terTile.getRotationValues()[2]~=nil and gStates.gameScenario=="Dungeon Lords" then
									if terTile.getRotationValues()[2].value=="Dungeon Monster" or terTile.getRotationValues()[2].value=="Draconum" then
										turnOrder[a].score.DungeonTomb=turnOrder[a].score.DungeonTomb+1
										found=true
									end
								end
								--GraveYards
								if terTile.getName()=="GraveYard" then
									turnOrder[a].score.GraveYard=turnOrder[a].score.GraveYard+1
									coopGraveYard=coopGraveYard+1
									found=true
								end
							end
							if found==true then break end
						end
						end
					end
				end
				turnOrder[a].heroChallenge=heroChallengeEvaluate(a,objectsInPlay)
			else
				--count the amount of cards left in the dummy or Volkare's deck
				turnOrder[a].score.CardsLeft=0
				for b, c in pairs(getObjectFromGUID(deedDeckZones[turnOrder[a].seatPos]).getObjects()) do
					if c.type=="Card" then turnOrder[a].score.CardsLeft=1 break end
					if c.type=="Deck" then turnOrder[a].score.CardsLeft=c.getQuantity() break end
				end
			end
		end
		--Figure out who leads and assisted in cities
		refreshCityControlAndScoring()
		local forTheCouncil=gStates.gameScenario=="For the Council"
		local againstHorsemen=gStates.gameScenario=="Against the Horsemen Blitz"
		local apocalypseHere=gStates.gameScenario=="Apocalypse is Here"
		local furyDragon=gStates.gameScenario=="Fury of the Apocalypse Dragon"
		local horsemenSummary=(againstHorsemen or apocalypseHere) and horsemanDefeatSummary() or {total=0,byMage={},fameByMage={}}
		local againstDragon=gStates.gameScenario=="Against the Dragon Blitz" or apocalypseHere or furyDragon
		local dragonScoreSummary=againstDragon and apocalypseDragonCompetitiveScoreSummary() or {defeatedHeads=0,byMage={},heads={}}
		local fracturedLandsNoCityScore=gStates.gameScenario=="The Fractured Lands Blitz"
		if againstHorsemen then
			local bestFame=0
			local bestPlayers={}
			for playerIndex,details in pairs(turnOrder) do
				details.score.HorsemenDefeated=horsemenSummary.byMage[details.mage] or 0
				details.score.HorsemenFame=horsemenSummary.fameByMage[details.mage] or 0
				details.score.gHorsemanSlayer=0
				if details.mage~=gStates.positionMageKnight[5] then
					local fame=details.score.HorsemenFame
					if fame>bestFame then bestFame=fame bestPlayers={playerIndex}
					elseif fame==bestFame and fame>0 then bestPlayers[#bestPlayers+1]=playerIndex end
				end
			end
			if gStates.coop==0 and bestFame>0 then
				local bonus=#bestPlayers==1 and 6 or 3
				for _,playerIndex in ipairs(bestPlayers) do turnOrder[playerIndex].score.gHorsemanSlayer=bonus end
			end
		end
		local function councilReputationPoints(playerIndex)
			if turnOrder[playerIndex].reputation==-7 then return -10 end
			return tonumber(reputationTable[turnOrder[playerIndex].reputation].repDisplay)
		end
		--For the Council always runs to its time limit; Reputation decides success/failure only once the game is actually over.
		local councilMissionResult=""
		if forTheCouncil and gStates.gameOver==true then
			local requiredReputation=gStates.playerCount==1 and 2 or 1
			local missionSuccessful=true
			for playerIndex, details in pairs(turnOrder) do
				if details.mage~=gStates.positionMageKnight[5] and councilReputationPoints(playerIndex)<requiredReputation then
					missionSuccessful=false
					break
				end
			end
			if missionSuccessful then
				councilMissionResult="{en}Mission Successful{ru}Mission Successful{zh-tw}Mission Successful{zh-cn}Mission Successful{ko}Mission Successful{es}Mission Successful{fr}Mission Successful{pt-br}Mission Successful{de}Mission Successful"
			else
				councilMissionResult="{en}Mission Failed{ru}Mission Failed{zh-tw}Mission Failed{zh-cn}Mission Failed{ko}Mission Failed{es}Mission Failed{fr}Mission Failed{pt-br}Mission Failed{de}Mission Failed"
			end
		end
		--find the greatest in a category for competative games
		local coopScore=0
		local coopKey={}
		local scoreMax=0
		local scoreMin=999
		local key={}
		--Lowest base score for cooperative/solo scoring.
		if gStates.coop==1 then
			for a=1, #turnOrder, 1 do
				local currentLowScore=999
				if turnOrder[a].mage~=gStates.positionMageKnight[5] then
					if forTheCouncil then currentLowScore=turnOrder[a].questScore+councilReputationPoints(a)
					else currentLowScore=turnOrder[a].fame+turnOrder[a].score.Reward end
				end
				if currentLowScore==scoreMin then key[#key+1]=a end
				if currentLowScore<scoreMin then scoreMin=currentLowScore key={a} end
			end
			if forTheCouncil then
				coopScore=scoreMin
			else
				coopScore=coopScore+turnOrder[key[1]].fame+turnOrder[key[1]].score.Reward
				coopKey.lFame=key[1]
			end
		end
		--Find Greatest in all the categories. Used to add final score for Solo and Coop games.
		local greatestTable={gKnowledge=	{function(z) return heroChallengeKnowledgeScore(z) end},
							 gLoot=			{function(z) return heroChallengeLootScore(z) end},
							 gLeader=		{function(z) return heroChallengeLeaderScore(z) end},
							 gAdventurer=	{function(z) return heroChallengeAdventurerScore(z,1) end,
											 function(z) return heroChallengeAdventurerScore(z,2) end, nil,--Dungeon Lords
											 function(z) return heroChallengeAdventurerScore(z,4) end},--Against the Apocalypse
							 gRestorer=		{function(z) return turnOrder[z].score.Destroyed*3 end, nil, nil,
											 function(z) return turnOrder[z].score.Destroyed*3 end},--Against the Apocalypse
							 gAscender=		{function(z) return turnOrder[z].score.ZigguratPyramid*0 end, nil, nil,
											 function(z) return turnOrder[z].score.Zig1+(turnOrder[z].score.Zig2*2)+(turnOrder[z].score.Zig3*3)+(turnOrder[z].score.Pyr1*2)+(turnOrder[z].score.Pyr2*4)+(turnOrder[z].score.Pyr3*6) end},--Against the Apocalypse
							 gConqueror=	{function(z) return heroChallengeConquerorScore(z) end},
							 gLiberator=	{function(z) return (turnOrder[z].score.CoreMine*7)+(turnOrder[z].score.CountryMine*4) end,
							 				 function(z) return (turnOrder[z].score.CoreMine*7)+(turnOrder[z].score.CountryMine*4) end},--Mines Liberation
							 gBeating=		{function(z) return heroChallengeBeatingScore(z) end},
							 gCityLead=		{function(z) return (turnOrder[z].score.CityLead*7)+(turnOrder[z].score.CityAssist*4) end,
							 				 function(z) return (turnOrder[z].score.CityLead*7)+(turnOrder[z].score.CityAssist*4) end},
							 gRelic=		{function(z) return turnOrder[z].score.Relic*5 end, nil ,
						 					 function(z) return turnOrder[z].score.Relic*4 end}}--The Lost Relic Blitz
		if apocalypseQuestScoringActive()==true and (forTheCouncil~=true or gStates.coop==0) then
			greatestTable.gQuest={function(z) return turnOrder[z].questScore end}
		end
		if forTheCouncil and gStates.coop==0 then
			--Offsets preserve ordering while ensuring the title is still awarded if all
			--Reputation values are negative or all Fame values are zero.
			greatestTable.gEsteem={function(z) return turnOrder[z].reputation+8 end}
			greatestTable.gRenown={function(z) return turnOrder[z].fame+1 end}
		end
		local greatestBonus={{3, 1},
							 {5, 2},--Dungeon Lords, Mines Liberation
							 {4, 2},--The Lost Relic Blitz
							 {5, 2}}--Against the Apocalypse
		for greatName, scoreMath in pairs(greatestTable) do
			local ref=1
			if gStates.gameScenario=="Mines Liberation" and greatName=="gLiberator" then ref=2 end
			if gStates.gameScenario=="Dungeon Lords" and greatName=="gAdventurer" then ref=2 end
			if gStates.gameScenario=="Against the Apocalypse Blitz" and (greatName=="gRestorer" or (greatName=="gAdventurer" and gStates.coop==1) or (greatName=="gAscender" and gStates.coop==0)) then ref=4 end
			if (gStates.gameScenario=="Conquest" or gStates.gameScenario=="Conquest Blitz" or gStates.gameScenario=="First Conquest" or gStates.gameScenario=="Ultimate Conquest" or gStates.gameScenario=="Fast Forwarded Conquest") and greatName=="gCityLead" then ref=2 end
			if gStates.gameScenario=="The Lost Relic Blitz" and gStates.coop==0 and greatName=="gRelic" then ref=3 end
			scoreMax=0
			key={}
			for playerX=1, #turnOrder, 1 do
				turnOrder[playerX].score[greatName]=0
				local currentHighScore=-1
				if turnOrder[playerX].mage~=gStates.positionMageKnight[5] then currentHighScore=scoreMath[ref](playerX) end
				if currentHighScore==scoreMax then key[#key+1]=playerX end
				if currentHighScore>scoreMax then scoreMax=currentHighScore key={playerX} end
			end
			if gStates.gameScenario=="Against the Apocalypse Blitz" and greatName=="gAdventurer" then ref=1 end
			if #key==1 and scoreMax~=0 and (gStates.coop==0 or gStates.WarOfFourComp==true) then turnOrder[key[1]].score[greatName]=greatestBonus[ref][1] end
			if #key>1 and scoreMax~=0 and (gStates.coop==0 or gStates.WarOfFourComp==true) then for a=1, #key, 1 do turnOrder[key[a]].score[greatName]=greatestBonus[ref][2] end end
			if gStates.gameScenario=="Against the Apocalypse Blitz" and greatName=="gAdventurer" then ref=4 end
			if gStates.coop==1 and forTheCouncil~=true and greatName~="gBeating" and greatName~="gCityLead" then coopScore=coopScore+scoreMath[ref](key[1]) coopKey[greatName]=key[1] end
			if gStates.coop==1 and forTheCouncil~=true and greatName=="gBeating" and greatName~="gCityLead" then coopScore=coopScore-scoreMath[ref](key[1]) coopKey[greatName]=key[1] end
		end
		--Krang and Braevalar have Hero Challenge bonuses outside the standard Achievement categories.
		--In cooperative scoring these are added once for each participating Hero; altered category rates above
		--still follow the normal cooperative rule of scoring only the best Hero in each Achievement category.
		if gStates.coop==1 and forTheCouncil~=true and gStates.heroChallenges==true then
			for playerIndex,details in pairs(turnOrder) do
				if details.mage~=gStates.positionMageKnight[5] and details.heroChallenge~=nil then coopScore=coopScore+(details.heroChallenge.extraBonus or 0) end
			end
		end

		--Update Score Card
		local scoreCardSections={	"QuestScoreHeading",		"QuestScoreData",
									"ReputationScoreHeading",	"ReputationScoreData",
									"KnowledgeScoreHeading",	"KnowledgeScoreData",
									"LootScoreHeading",			"LootScoreData",
									"LeaderScoreHeading",		"LeaderScoreData",
									"ConquerorScoreHeading",	"ConquerorScoreData",
									"AdventurerScoreHeading",	"AdventurerScoreData",
									"RestorerScoreHeading",		"RestorerScoreData",
									"LiberatorScoreHeading",	"LiberatorScoreData",
									"BeatingScoreHeading",		"BeatingScoreData",
									"RelicScoreHeading",		"RelicScoreData",
									"RewardScoreHeading",		"RewardScoreData",
									"CityScoreHeading",			"CityScoreData",
									"VolkareScoreHeading",		"VolkareScoreData",
									"TezlaScoreHeading",		"TezlaScoreData",
									"EfficiencyScoreHeading",	"EfficiencyScoreData"}
		for a, b in pairs(scoreCardSections) do
			UI.setAttribute(b, "active", "false")
		end
		local pannel=1
		local totalHeight=54+30+30
		local assembledText=""
		local lineFeed=0
		local heights={Quest=0, Reputation=0, Knowledge=0, Loot=0, Leader=0, Conqueror=0, Adventurer=0, Restorer=0, Liberator=0, Beating=0, Volkare=0, Efficiency=0, City=0, Relic=0, Tezla=0, Reward=0}

		local function appendScoreLine(text, lineCount, parts)
			local line={}
			if lineCount>0 then
				line[1]=text
				line[2]="\n"
			end
			for i=1, #parts do line[#line+1]=parts[i] end
			return joinLang(line), lineCount+1
		end

		--Display and add up score pannel heights
		function updateScorePannel(scoreName, lineFeed, assembledText)
			local pannelText=tostring(pannel)
			local textCol="rgb(0, 0, 0)"
			if coopKey["g"..scoreName]~=pannel and coopKey["g"..scoreName]~=nil and gStates.coop==1 and scoreName~="Relic" then textCol="rgb(0.2, 0.2, 0.4)" end
			if scoreName=="Volkare" or scoreName=="Efficiency" then pannelText="" end
			UI.setAttribute(scoreName..pannelText.."ScoreText", "text", "")
			UI.setAttribute(scoreName..pannelText.."ScoreCell", "active", "true")
			local scoreHieght=0
			if lineFeed>0 then scoreHieght=(lineFeed*25)-((lineFeed-1)*8) end
			if scoreHieght>heights[scoreName] then
				if lineFeed>0 then totalHeight=totalHeight+scoreHieght-heights[scoreName] end
				heights[scoreName]=scoreHieght
				UI.setAttribute(scoreName.."ScoreData", "preferredHeight", heights[scoreName])
			end
			if lineFeed>0 then
				UI.setAttribute(scoreName.."ScoreHeading", "active", "true")
				UI.setAttribute(scoreName.."ScoreData", "active", "true")
				if scoreName~="Reward" then UI.setAttribute(scoreName..pannelText.."ScoreText", "Color", textCol) end
				UI.setAttribute(scoreName..pannelText.."ScoreText", "text", assembledText)
			end
		end

		--Work out which scores to display
		for a=1, #turnOrder, 1 do
			local totalScore=0
			local challenge=turnOrder[a].heroChallenge
			local function appendHeroChallenge(scoreCategory)
				local challengeData=heroChallengesData[turnOrder[a].mage]
				if challenge==nil or challengeData==nil or challengeData.scoreCategory~=scoreCategory then return end
				local challengeStatus=challenge.complete and "Complete" or (gStates.gameOver==true and "Failed" or "Incomplete")
				assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{"Hero Challenge: ",challengeStatus})
				assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{"(",challenge.details,")"})
				if (challenge.extraBonus or 0)>0 then
					local bonusLabel=turnOrder[a].mage=="Krang" and "Puppet Master trophies: +" or "Final terrain: +"
					assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{bonusLabel,challenge.extraBonus})
					totalScore=totalScore+challenge.extraBonus
				end
			end
			if turnOrder[a].mage~=gStates.positionMageKnight[5] then
				if gStates.gameScenario~="Conquer and Hold" and gStates.gameScenario~="One to Return" then
					--Base Score
					if forTheCouncil~=true then
						assembledText="" lineFeed=0
						local textCol="rgb(0, 0, 0)"
						if coopKey.lFame~=a and gStates.coop==1 then textCol="rgb(0.2, 0.2, 0.4)" end
						UI.setAttribute("Reward"..pannel.."ScoreText", "Color", textCol)
						assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{translateWord[turnOrder[a].mage], "{en}'s Base Fame: {ru}имеет Славы: {zh-tw}的基础名望: {zh-cn}的基础名望: {ko} 의 기본 명성: {es} Fama Base: {fr} Gloire Base: {pt-br} Fama Base: {de}Basis-Ruhm: ", turnOrder[a].fame})
						totalScore=turnOrder[a].fame
						if turnOrder[a].score.Reward>0 then
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{turnOrder[a].score.Reward, "{en} Faction Reward(s): +{ru} Жетон фракций: +{zh-tw}派系奖励: +{zh-cn}派系奖励: +{ko} 세력 보상: +{es} Recompensas Facción: +{fr} Récompenses Faction: +{pt-br} Recompensas de Facção: +{de} Fraktions-Belohnung(en): +", turnOrder[a].score.Reward})
							totalScore=totalScore+turnOrder[a].score.Reward
						end
						updateScorePannel("Reward", lineFeed, assembledText)
					end

					--Quest scoring is optional when the selected scenario does not require it.
					if apocalypseQuestScoringActive()==true then
						assembledText="" lineFeed=0
						if turnOrder[a].questScore>0 then
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{turnOrder[a].questScore, "{en} Quest Point(s): +{ru} Quest Point(s): +{zh-tw} Quest Point(s): +{zh-cn} Quest Point(s): +{ko} Quest Point(s): +{es} Quest Point(s): +{fr} Quest Point(s): +{pt-br} Quest Point(s): +{de} Quest Point(s): +", turnOrder[a].questScore})
							totalScore=totalScore+turnOrder[a].questScore
						end
						if (forTheCouncil~=true or gStates.coop==0) and turnOrder[a].score.gQuest>0 then
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{"{en}Greatest Quester: +{ru}Greatest Quester: +{zh-tw}Greatest Quester: +{zh-cn}Greatest Quester: +{ko}Greatest Quester: +{es}Greatest Quester: +{fr}Greatest Quester: +{pt-br}Greatest Quester: +{de}Greatest Quester: +", turnOrder[a].score.gQuest})
							totalScore=totalScore+turnOrder[a].score.gQuest
						end
						updateScorePannel("Quest", lineFeed, assembledText)
					end

					--For the Council uses Reputation as scoring points. Greatest Renown is kept
					--here with Greatest Esteem so no separate Fame category is needed.
					if forTheCouncil then
						assembledText="" lineFeed=0
						local reputationScore=councilReputationPoints(a)
						local reputationText=tostring(reputationScore)
						if reputationScore>0 then reputationText="+"..reputationText end
						assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{"{en}Reputation: {ru}Reputation: {zh-tw}Reputation: {zh-cn}Reputation: {ko}Reputation: {es}Reputation: {fr}Reputation: {pt-br}Reputation: {de}Reputation: ", reputationText})
						totalScore=totalScore+reputationScore
						if gStates.coop==0 and turnOrder[a].score.gEsteem>0 then
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{"{en}Greatest Esteem: +{ru}Greatest Esteem: +{zh-tw}Greatest Esteem: +{zh-cn}Greatest Esteem: +{ko}Greatest Esteem: +{es}Greatest Esteem: +{fr}Greatest Esteem: +{pt-br}Greatest Esteem: +{de}Greatest Esteem: +", turnOrder[a].score.gEsteem})
							totalScore=totalScore+turnOrder[a].score.gEsteem
						end
						if gStates.coop==0 and turnOrder[a].score.gRenown>0 then
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{"{en}Greatest Renown: +{ru}Greatest Renown: +{zh-tw}Greatest Renown: +{zh-cn}Greatest Renown: +{ko}Greatest Renown: +{es}Greatest Renown: +{fr}Greatest Renown: +{pt-br}Greatest Renown: +{de}Greatest Renown: +", turnOrder[a].score.gRenown})
							totalScore=totalScore+turnOrder[a].score.gRenown
						end
						updateScorePannel("Reputation", lineFeed, assembledText)
					end
					--Knowledge Score
					assembledText="" lineFeed=0
					appendHeroChallenge("Knowledge")
					if forTheCouncil~=true then
						local aaRate=heroChallengeActive(a)==true and turnOrder[a].mage=="Braevalar" and 2 or 1
						local spellRate=heroChallengeActive(a)==true and turnOrder[a].mage=="Goldyx" and 3 or 2
						if turnOrder[a].score.AdvanceAction>0 then
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{turnOrder[a].score.AdvanceAction, "{en} Advanced Action(s): +{ru} Особое действие: +{zh-tw}张高级行动卡: +{zh-cn}张高级行动卡: +{ko} 상급 액션: +{es} Acciones Avanzadas: +{fr} Actions Avancées: +{pt-br} Ações Avançadas: +{de} Fortgeschrittene Aktion(en): +", turnOrder[a].score.AdvanceAction*aaRate})
							totalScore=totalScore+(turnOrder[a].score.AdvanceAction*aaRate)
						end
						if turnOrder[a].score.Spell>0 then
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{turnOrder[a].score.Spell, "{en} Spell(s): +{ru} Заклинание: +{zh-tw}张法术卡: +{zh-cn}张法术卡: +{ko} 마법: +{es} Hechizos: +{fr} Sorts: +{pt-br} Feitiços: +{de} Zauberspruch(e): +", (turnOrder[a].score.Spell*spellRate)})
							totalScore=totalScore+(turnOrder[a].score.Spell*spellRate)
						end

					end
					if turnOrder[a].score.gKnowledge>0 then
						assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{"{en}Greatest Knowledge: +{ru}Великий мудрец: +{zh-tw}博古通今： +{zh-cn}博古通今： +{ko}위대한 지식: +{es}Mayor Conocimiento: +{fr}Plus Grand Connaissance: +{pt-br}Mais Conhecimento: +{de}Größtes Wissen: +", turnOrder[a].score.gKnowledge})
						totalScore=totalScore+turnOrder[a].score.gKnowledge
					end
					updateScorePannel("Knowledge", lineFeed, assembledText)

					--Loot Score
					assembledText="" lineFeed=0
					appendHeroChallenge("Loot")
					if forTheCouncil~=true then
						local artifactRate=heroChallengeActive(a)==true and turnOrder[a].mage=="Coral" and 4 or 2
						local crystalScore=(heroChallengeActive(a)==true and (turnOrder[a].mage=="Goldyx" or turnOrder[a].mage=="Coral")) and turnOrder[a].score.Crystal or math.floor(turnOrder[a].score.Crystal/2)
						if turnOrder[a].score.Artifact>0 then
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{turnOrder[a].score.Artifact, "{en} Artifact(s): +{ru} Артефакт: +{zh-tw}张圣器卡: +{zh-cn}张圣器卡: +{ko} 유물: +{es} Artefactos: +{fr} Artefacts: +{pt-br} Artefatos: +{de} Artefakt(e): +", (turnOrder[a].score.Artifact*artifactRate)})
							totalScore=totalScore+(turnOrder[a].score.Artifact*artifactRate)
						end
						if turnOrder[a].score.Crystal>0 then
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{turnOrder[a].score.Crystal, "{en} Mana Crystal(s): +{ru} Кристалл маны: +{zh-tw}个未使用的魔晶: +{zh-cn}个未使用的魔晶: +{ko} 마나 수정: +{es} Cristales de Maná: +{fr} Cristaux de Mana: +{pt-br} Cristais de Mana: +{de} Manakristall(e): +", crystalScore})
							totalScore=totalScore+crystalScore
						end
						if turnOrder[a].score.Potion>0 then
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{turnOrder[a].score.Potion, "{en} Potion(s): +{ru} Зелье: +{zh-tw}瓶药剂： +{zh-cn}瓶药剂： +{ko} 포션: +{es} Pociones: +{fr} Potion: +{pt-br} Poções: +{de} Trank(e): +", turnOrder[a].score.Potion})
							totalScore=totalScore+turnOrder[a].score.Potion
						end

					end
					if turnOrder[a].score.gLoot>0 then
						assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{"{en}Greatest Loot: +{ru}Великая добыча: +{zh-tw}至多战利品： +{zh-cn}至多战利品： +{ko}위대한 전리품: +{es}Mayor Botín: +{fr}Plus Grand Butin: +{pt-br}Maior Saque: +{de}Größte Beute: +", turnOrder[a].score.gLoot})
						totalScore=totalScore+turnOrder[a].score.gLoot
					end
					updateScorePannel("Loot", lineFeed, assembledText)

					--Leader Score
					assembledText="" lineFeed=0
					appendHeroChallenge("Leader")
					if forTheCouncil~=true then
						local healthyScore=heroChallengeActive(a)==true and turnOrder[a].mage=="Norowas" and turnOrder[a].score.UnitsLevel*2 or turnOrder[a].score.UnitsLevel
						local woundedScore=heroChallengeActive(a)==true and turnOrder[a].mage=="Arythea" and turnOrder[a].score.WoundedUnitsRawLevel or turnOrder[a].score.WoundedUnitsLevel
						if turnOrder[a].score.Units>0 then
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{turnOrder[a].score.Units, "{en} Healthy Unit(s): +{ru} Здоровый отряд: +{zh-tw}个健康的部队: +{zh-cn}个健康的部队: +{ko} 보유 유닛: +{es} Unidades Saludables: +{fr} Unités Saines: +{pt-br} Unidades Saudáveis: +{de} Gesunde Einheit(en): +", healthyScore})
							totalScore=totalScore+healthyScore
						end
						if turnOrder[a].score.WoundedUnits>0 then
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{turnOrder[a].score.WoundedUnits, "{en} Wounded Unit(s): +{ru} Раненный отряд: +{zh-tw}个受伤的部队: +{zh-cn}个受伤的部队: +{ko} 부상받은 유닛: +{es} Unidades Heridas: +{fr} Unités Blessées: +{pt-br} Unidades Feridas: +{de} Verwundete Einheit(en): +", woundedScore})
							totalScore=totalScore+woundedScore
						end

					end
					if turnOrder[a].score.gLeader>0 then
						assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{"{en}Greatest Leader: +{ru}Великий лидер: +{zh-tw}至高领袖： +{zh-cn}至高领袖： +{ko}위대한 지도자: +{es}Mayor Líder: +{fr}Plus Grand Chef: +{pt-br}Maior Líder: +{de}Größter Anführer: +", turnOrder[a].score.gLeader})
						totalScore=totalScore+turnOrder[a].score.gLeader
					end
					updateScorePannel("Leader", lineFeed, assembledText)

					--Adventurer Score
					assembledText="" lineFeed=0
					appendHeroChallenge("Adventurer")
					if forTheCouncil~=true then
						local adventurerRate=heroChallengeActive(a)==true and turnOrder[a].mage=="Wolfhawk" and 4 or 2
						if turnOrder[a].score.Ruin>0 then
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{turnOrder[a].score.Ruin, "{en} Ruin(s): +{ru} Руины: +{zh-tw}个远古遗迹已探索: +{zh-cn}个远古遗迹已探索: +{ko} 유적: +{es} Ruinas: +{fr} Ruines: +{pt-br} Ruínas: +{de} Ruine(n): +", turnOrder[a].score.Ruin*adventurerRate})
							totalScore=totalScore+(turnOrder[a].score.Ruin*adventurerRate)
						end
						if turnOrder[a].score.DungeonTomb>0 then
							local b=turnOrder[a].score.DungeonTomb*adventurerRate
							if gStates.gameScenario=="Dungeon Lords" then b=turnOrder[a].score.DungeonTomb*4 end
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{turnOrder[a].score.DungeonTomb, "{en} Dungeon / Tomb(s): +{ru} Подземелье / Гробница: +{zh-tw}个地下城或墓穴已征服: +{zh-cn}个地下城或墓穴已征服: +{ko} 던전과 무덤: +{es} Mazmorras / Tumbas: +{fr} Donjons / Tombeaux: +{pt-br} Masmorras / Tumbas: +{de} Verlies / Grabmal(e): +", b})
							totalScore=totalScore+b
						end
						if turnOrder[a].score.SpawningDen>0 then
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{turnOrder[a].score.SpawningDen, "{en} Den / Spawn Grnd(s): +{ru} Логово / Проклятые земли: +{zh-tw}个怪物巢穴或孵化领地已征服： +{zh-cn}个怪物巢穴或孵化领地已征服： +{ko} 은신처와 산란지: +{es} Den / Zonas Desove: +{fr} Tanière / Frayère: +{pt-br} Covil / Nascedouro: +{de} Höhle(n) / Laichplatz(e): +", turnOrder[a].score.SpawningDen*adventurerRate})
							totalScore=totalScore+(turnOrder[a].score.SpawningDen*adventurerRate)
						end
						if turnOrder[a].score.Maze>0 then
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{turnOrder[a].score.Maze, "{en} Maze / Labyrinth(s): +{ru} Катакомбы / Лабиринт: +{zh-tw}个迷宫或迷城已征服: +{zh-cn}个迷宫或迷城已征服: +{ko} 미로와 미궁: +{es} Maze / Laberintos: +{fr} Maze / Labyrinthes: +{pt-br} Labirintos / Dédalos: +{de} Irrgarten / Labyrinth(e): +", turnOrder[a].score.Maze*adventurerRate})
							totalScore=totalScore+(turnOrder[a].score.Maze*adventurerRate)
						end
						if turnOrder[a].score.ZigguratPyramid>0 and (gStates.gameScenario~="Against the Apocalypse Blitz" or (gStates.gameScenario=="Against the Apocalypse Blitz" and gStates.coop==1)) then
							local b=turnOrder[a].score.ZigguratPyramid*adventurerRate
							if gStates.gameScenario=="Against the Apocalypse Blitz" then b=turnOrder[a].score.ZigguratPyramid*5 end
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{turnOrder[a].score.ZigguratPyramid, "{en} Ziggurat / Pyramid(s): +{ru} Зиккурат / Пирамида (и): +{zh-tw} 座階梯神廟/金字塔：+{zh-cn} 座阶梯神庙/金字塔：+{ko} 지구라트 / 피라미드: +{es} Zigurat / Pirámide(s): +{fr} Ziggourat / Pyramide(s) : +{pt-br} Zigurate / Pirâmide(s): +{de} Zikkurat / Pyramide(n): +", b})
							totalScore=totalScore+b
						end
						if turnOrder[a].score.Zig1>0 then
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{turnOrder[a].score.Zig1, "{en} Ziggurat Floor One(s): +{ru} Зиккурат, первый этаж: +{zh-tw} 座階梯神殿在第一層：+{zh-cn} 座阶梯神庙在第一层：+{ko} 지구라트 1층: +{es} Planta(s) 1 de la zigurat: +{fr} Ziggourat, 1er étage : +{pt-br} Zigurate, 1º andar(es): +{de} Zikkurat, 1. Etage: +", turnOrder[a].score.Zig1})
							totalScore=totalScore+(turnOrder[a].score.Zig1)
						end
						if turnOrder[a].score.Zig2>0 then
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{turnOrder[a].score.Zig2, "{en} Ziggurat Floor Two(s): +{ru} Зиккурат, второй этаж: +{zh-tw} 座階梯神殿在第二層：+{zh-cn} 座阶梯神庙在第二层：+{ko} 지구라트 2층: +{es} Planta(s) 2 de la zigurat: +{fr} Ziggourat, 2e étage : +{pt-br} Zigurate, 2º andar(es): +{de} Zikkurat, 2. Etage: +", turnOrder[a].score.Zig2*2})
							totalScore=totalScore+(turnOrder[a].score.Zig2*2)
						end
						if turnOrder[a].score.Zig3>0 then
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{turnOrder[a].score.Zig3, "{en} Ziggurat Floor Three(s): +{ru} Зиккурат, третий этаж: +{zh-tw} 座階梯神殿在第三層：+{zh-cn} 座阶梯神庙在第三层：+{ko} 지구라트 3층: +{es} Planta(s) 3 de la zigurat: +{fr} Ziggourat, 3e étage : +{pt-br} Zigurate, 3º andar(es): +{de} Zikkurat, 3. Etage: +", turnOrder[a].score.Zig3*3})
							totalScore=totalScore+(turnOrder[a].score.Zig3*3)
						end
						if turnOrder[a].score.Pyr1>0 then
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{turnOrder[a].score.Pyr1, "{en} Pyramid Floor One(s): +{ru} Пирамида, первый этаж: +{zh-tw} 座金字塔在第一層：+{zh-cn} 座金字塔在第一层：+{ko} 피라미드 1층: +{es} Planta(s) 1 de la pirámide: +{fr} Pyramide, 1er étage : +{pt-br} Pirâmide, 1º andar(es): +{de} Pyramide, 1. Etage: +", turnOrder[a].score.Pyr1*2})
							totalScore=totalScore+(turnOrder[a].score.Pyr1*2)
						end
						if turnOrder[a].score.Pyr2>0 then
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{turnOrder[a].score.Pyr2, "{en} Pyramid Floor Two(s): +{ru} Пирамида, второй этаж: +{zh-tw} 座金字塔在第二層：+{zh-cn} 座金字塔在第二层：+{ko} 피라미드 2층: +{es} Planta(s) 2 de la pirámide: +{fr} Pyramide, 2e étage : +{pt-br} Pirâmide, 2º andar(es): +{de} Pyramide, 2. Etage: +", turnOrder[a].score.Pyr2*4})
							totalScore=totalScore+(turnOrder[a].score.Pyr2*4)
						end
						if turnOrder[a].score.Pyr3>0 then
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{turnOrder[a].score.Pyr3, "{en} Pyramid Floor Three(s): +{ru} Пирамида, третий этаж: +{zh-tw} 座金字塔在第三層：+{zh-cn} 座金字塔在第三层：+{ko} 피라미드 3층: +{es} Planta(s) 3 de la pirámide: +{fr} Pyramide, 3e étage : +{pt-br} Pirâmide, 3º andar(es): +{de} Pyramide, 3. Etage: +", turnOrder[a].score.Pyr3*6})
							totalScore=totalScore+(turnOrder[a].score.Pyr3*6)
						end

					end
					if turnOrder[a].score.gAdventurer>0 then
						local b="{en}Greatest Adventurer: +{ru}Великий искатель приключений: +{zh-tw}披荊斬棘：+{zh-cn}披荆斩棘：+{ko}위대한 모험가: +{es}Mayor Aventurero: +{fr}Plus Grand Aventurier: +{pt-br}Maior Aventureiro: +{de}Größter Abenteurer: +"
						if gStates.gameScenario=="Dungeon Lords" then
							b="{en}Great Dungeon Crawler: +{ru}Великий исследователь подземелий: +{zh-tw}地下城勇士：+{zh-cn}地下城勇士：+{ko}던전 탐험가: +{es}Mayor Mazmorra Orugas: +{fr}Plus Grand Donjon Crawler: +{pt-br}Maior Explorador de Masmorras: +{de}Großer Dungeon-Krabbler: +"
						end
						assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{b, turnOrder[a].score.gAdventurer})
						totalScore=totalScore+turnOrder[a].score.gAdventurer
					end
					if turnOrder[a].score.gAscender>0 then
						assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{"{en}Greatest Ascender: +{ru}Величайший восходец: +{zh-tw}登峰造極：+{zh-cn}登峰造极：+{ko}위대한 등반가: +{es}El mejor escalador: +{fr}Meilleur grimpeur : +{pt-br}Maior Ascendente: +{de}Größter Aufsteiger: +", turnOrder[a].score.gAscender})
						totalScore=totalScore+turnOrder[a].score.gAscender
					end
					updateScorePannel("Adventurer", lineFeed, assembledText)--gAscender

					--Restorer Score
					assembledText="" lineFeed=0
					if forTheCouncil~=true then
						if turnOrder[a].score.Destroyed>0 then
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{turnOrder[a].score.Destroyed, "{en} Restored Site(s): +{ru} Восстановленные объекты: +{zh-tw} 個修復地點：+{zh-cn} 个修复地点：+{ko} 복구한 장소: +{es} Lugares restaurados: +{fr} Site(s) restauré(s) : +{pt-br} Local(is) restaurado(s): +{de} Wiederhergestellte Stätte(n): +", (turnOrder[a].score.Destroyed*3)})
							totalScore=totalScore+(turnOrder[a].score.Destroyed*3)
						end

					end
					if turnOrder[a].score.gRestorer>0 then
						assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{"{en}Greatest Restorer: +{ru}Лучший реставратор: +{zh-tw}重振山河：+{zh-cn}重振山河：+{ko}위대한 복원가: +{es}Mejor restaurador: +{fr}Meilleur restaurateur : +{pt-br}Maior restaurador: +{de}Bester Wiederhersteller: +", turnOrder[a].score.gRestorer})
						totalScore=totalScore+turnOrder[a].score.gRestorer
					end
					updateScorePannel("Restorer", lineFeed, assembledText)

					--Liberator Score
					assembledText="" lineFeed=0
					if forTheCouncil~=true then
						if turnOrder[a].score.CountryMine>0 then
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{turnOrder[a].score.CountryMine, "{en} Country Mine(s): +{ru} Шахта на дикой земле: +{zh-tw}个深层矿山已解放: +{zh-cn}个深层矿山已解放: +{ko} 교외 광산: +{es} Minas del País: +{fr} Mines de Pays: +{pt-br} Minas de Campo: +{de} Landmine(n): +", (turnOrder[a].score.CountryMine*4)})
							totalScore=totalScore+(turnOrder[a].score.CountryMine*4)
						end
						if turnOrder[a].score.CoreMine>0 then
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{turnOrder[a].score.CoreMine, "{en} Core Mine(s): +{ru} Шахта на развитой земле: +{zh-tw}个魔晶矿山已解放: +{zh-cn}个魔晶矿山已解放: +{ko} 중심부 광산: +{es} Minas Centrales: +{fr} Mines de Base: +{pt-br} Minas Centrais: +{de} Kernmine(n): +", (turnOrder[a].score.CoreMine*7)})
							totalScore=totalScore+(turnOrder[a].score.CoreMine*7)
						end

					end
					if turnOrder[a].score.gLiberator>0 then
						assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{"{en}Greatest Liberator: +{ru}Великий исследователь подземелий: +{zh-tw}至善解放者： +{zh-cn}至善解放者： +{ko}위대한 해방자: +{es}Mayor Libertador: +{fr}Plus Grand Libérateur: +{pt-br}Maior Libertador: +{de}Größter Befreier: +", turnOrder[a].score.gLiberator})
						totalScore=totalScore+turnOrder[a].score.gLiberator
					end
					updateScorePannel("Liberator", lineFeed, assembledText)

					--Relic Score
					if (gStates.coop==0 or gStates.WarOfFourComp==true) then
						assembledText="" lineFeed=0
						if forTheCouncil~=true then
							if turnOrder[a].score.Relic>0 then
								assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{turnOrder[a].score.Relic, "{en} Relic(s) Found: +{ru} Реликвия найдена: +{zh-tw}个圣器已收集: +{zh-cn}个圣器已收集: +{ko} 발견한 유물: +{es} Reliquias Encontradas: +{fr} Reliques Trouvées: +{pt-br} Relíquias Encontradas: +{de} Relikt(e) gefunden: +", (turnOrder[a].score.Relic*4)})
								totalScore=totalScore+(turnOrder[a].score.Relic*4)
							end

						end
					if turnOrder[a].score.gRelic>0 then
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{"{en}Greatest Relic Hunter: +{ru}Великий охотник за древностями: +{zh-tw}至高圣器猎手： +{zh-cn}至高圣器猎手： +{ko}위대한 유물 사냥꾼: +{es}Mayor Relic Hunter: +{fr}Plus Grand Chasseur de Reliques: +{pt-br}Maior Caçador de Relíquias: +{de}Größter Reliquienjäger: +", turnOrder[a].score.gRelic})
							totalScore=totalScore+turnOrder[a].score.gRelic
						end
						updateScorePannel("Relic", lineFeed, assembledText)
					end

					--Beating Score
					assembledText="" lineFeed=0
					appendHeroChallenge("Beating")
					if forTheCouncil~=true then
						if turnOrder[a].score.Wound>0 and not (heroChallengeActive(a)==true and turnOrder[a].mage=="Arythea") then
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{turnOrder[a].score.Wound, "{en} Wound(s): -{ru} Рана: -{zh-tw}张创伤卡: -{zh-cn}张创伤卡: -{ko} 부상: -{es} Heridas: -{fr} Blessures: -{pt-br} Ferimentos: -{de} Wunde(n): -", (turnOrder[a].score.Wound*2)})
							totalScore=totalScore-(turnOrder[a].score.Wound*2)
						end

					end
					if turnOrder[a].score.gBeating>0 then
						assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{"{en}Greatest Beating: -{ru}Великое поражение: -{zh-tw}受伤最多的: -{zh-cn}受伤最多的: -{ko}위대한 패배자: -{es}Mayor Paliza: -{fr}Plus Grandr Battement: -{pt-br}Mais Espancado: -{de}Größter Prügler: -", turnOrder[a].score.gBeating})
						totalScore=totalScore-turnOrder[a].score.gBeating
					end
					updateScorePannel("Beating", lineFeed, assembledText)

					if (gStates.coop==0 or gStates.WarOfFourComp==true) and forTheCouncil~=true then
						--Cities Competative. Fractured Lands explicitly does not use City scoring.
						if fracturedLandsNoCityScore~=true then
							assembledText="" lineFeed=0
							if turnOrder[a].score.CityLead>0 and gStates.defeatedCities.amount>0 then
								assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{turnOrder[a].score.CityLead, "{en} Conquered City(s): +{ru} Захваченный Город: +{zh-tw}个城市已征服: +{zh-cn}个城市已征服: +{ko} 정복한 도시: +{es} Ciudades Conquistadas: +{fr} Villes Conquises: +{pt-br} Cidades Conquistadas: +{de} Eroberte Stadt(en): +", (turnOrder[a].score.CityLead*7)})
								totalScore=totalScore+(turnOrder[a].score.CityLead*7)
							end
							if turnOrder[a].score.CityAssist>0 and gStates.defeatedCities.amount>0 then
								assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{turnOrder[a].score.CityAssist, "{en} Assisted City(s): +{ru} Помощь с Городом: +{zh-tw}个城市已援助: +{zh-cn}个城市已援助: +{ko} 도와준 도시: +{es} Ciudades Asistidas: +{fr} Villes Aidées: +{pt-br} Cidades Assistidas: +{de} Unterstützte Stadt(en): +", (turnOrder[a].score.CityAssist*4)})
								totalScore=totalScore+(turnOrder[a].score.CityAssist*4)
							end
							if turnOrder[a].score.gCityLead>0 and gStates.defeatedCities.amount>0 then
								assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{"{en}Greatest City Leader: +{ru}Великий завоеватель городов: +{zh-tw}至强城市领袖： +{zh-cn}至强城市领袖： +{ko}위대한 도시 정복자: +{es}Mayor Líder de la Ciudad: +{fr}Plus Grand Chef de la Ville: +{pt-br}Maior Líder de Cidade: +{de}Größter Stadtführer: +", turnOrder[a].score.gCityLead})
								totalScore=totalScore+turnOrder[a].score.gCityLead
							end
							updateScorePannel("City", lineFeed, assembledText)
						end

						--Tezla Faction Leaders
						assembledText="" lineFeed=0
						if (gStates.gameScenario=="Life and Death" or gStates.gameScenario=="The Realm of the Dead Blitz" or gStates.gameScenario=="The Hidden Valley Blitz" or gStates.gameScenario=="Ultimate Conquest") and turnOrder[a].score.DarkFactionLead>0 then
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{"{en}Dark Crusader Enemy: +5{ru}Враг Темного легиона: +5{zh-tw}黑暗十字军敌人: +5{zh-cn}黑暗十字军敌人: +5{ko}암흑 십자군 적: +5{es}Enemigo del Cruzado Oscuro: +5{fr}Ennemi Noir Croisé: +5{pt-br}Inimigo dos Cruzados Sombrios: +5{de}Feind des dunklen Kreuzfahrers: +5"})
							totalScore=totalScore+5
						end
						if (gStates.gameScenario=="Life and Death" or gStates.gameScenario=="The Realm of the Dead Blitz" or gStates.gameScenario=="The Hidden Valley Blitz" or gStates.gameScenario=="Ultimate Conquest") and turnOrder[a].score.ElemFactionLead>0 then
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{"{en}Elementalist Enemy: +5{ru}Враг Элементалистов: +5{zh-tw}元素敌人: +5{zh-cn}元素敌人: +5{ko}원소술사 적: +5{es}Enemigo Elementalista: +5{fr}Ennemi Elémentaliste: +5{pt-br}Inimigo dos Elementaristas: +5{de}Elementarmagier-Feind: +5"})
							totalScore=totalScore+5
						end
						updateScorePannel("Tezla", lineFeed, assembledText)
					end
				end

				--Conqueror Score
				if gStates.gameScenario~="One to Return" then
					assembledText="" lineFeed=0
					appendHeroChallenge("Conqueror")
					if turnOrder[a].score.Keep>0 and forTheCouncil~=true then
						local b=2
						if gStates.gameScenario=="Conquer and Hold" then b=3 end
						if heroChallengeActive(a)==true and turnOrder[a].mage=="Tovak" then b=4 end
						assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{turnOrder[a].score.Keep, "{en} Keep(s): +{ru} Крепость: +{zh-tw}个要塞已占领: +{zh-cn}个要塞已占领: +{ko} 성: +{es} Mantiene: +{fr} Garde: +{pt-br} Fortes: +{de} Bergfried(e): +", turnOrder[a].score.Keep*b})
						if gStates.gameScenario=="Conquer and Hold" then totalScore=turnOrder[a].score.Keep*b else totalScore=totalScore+(turnOrder[a].score.Keep*b) end
					end
					if turnOrder[a].score.MageTower>0 and forTheCouncil~=true then
						local towerRate=heroChallengeActive(a)==true and turnOrder[a].mage=="Tovak" and 4 or 2
						assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{turnOrder[a].score.MageTower, "{en} Mage Tower(s): +{ru} Башня мага: +{zh-tw}个法师塔已征服: +{zh-cn}个法师塔已征服: +{ko} 마법사의 탑: +{es} Torres de Magos: +{fr} Tours des Mages: +{pt-br} Torres de Mago: +{de} Magierturm(e): +", turnOrder[a].score.MageTower*towerRate})
						totalScore=totalScore+(turnOrder[a].score.MageTower*towerRate)
					end
					if gStates.gameScenario~="Conquer and Hold" then
						if turnOrder[a].score.Monastery>0 and forTheCouncil~=true then
							local monasteryRate=heroChallengeActive(a)==true and turnOrder[a].mage=="Tovak" and 4 or 2
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{turnOrder[a].score.Monastery, "{en} Monastery(s): +{ru} Монастырь: +{zh-tw}个修道院已焚毁: +{zh-cn}个修道院已焚毁: +{ko} 수도원: +{es} Monasterios: +{fr} Monastères: +{pt-br} Monastérios: +{de} Kloster(s): +", turnOrder[a].score.Monastery*monasteryRate})
							totalScore=totalScore+(turnOrder[a].score.Monastery*monasteryRate)
						end
						if turnOrder[a].score.VolkareCamp>0 and forTheCouncil~=true then
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{turnOrder[a].score.VolkareCamp, "{en} Volkare Pursuits: +{ru} Охоты на Волкара: +{zh-tw}沃卡里追击： +{zh-cn}沃卡里追击： +{ko} 볼케어 진영 추적: +{es} Persecuciones de Volkare: +{fr} Volkare Poursuites: +{pt-br} Volkare Persegue: +{de} Volkare Verfolgungen: +", turnOrder[a].score.VolkareCamp})
							totalScore=totalScore+turnOrder[a].score.VolkareCamp
						end
						if turnOrder[a].score.gConqueror>0 then
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{"{en}Greatest Conqueror: +{ru}Великий завоеватель: +{zh-tw}至高征服者： +{zh-cn}至高征服者： +{ko}위대한 정복자: +{es}Mayor Conquistador: +{fr}Plus Grand Conquérant: +{pt-br}Maior Conquistador: +{de}Größter Eroberer: +", turnOrder[a].score.gConqueror})
							totalScore=totalScore+turnOrder[a].score.gConqueror
						end
					end
					updateScorePannel("Conqueror", lineFeed, assembledText)
				end

				--Against the Horsemen competitive scoring: +6 per personal kill and the special Slayer title.
				if againstHorsemen and gStates.coop==0 then
					assembledText="" lineFeed=0
					local defeated=turnOrder[a].score.HorsemenDefeated or 0
					if defeated>0 then
						local horsemenLabel=defeated==1 and "{en} Horseman: +{ru} Всадник: +{zh-tw} 名騎士：+{zh-cn} 名骑士：+{ko}명의 기사: +{es} Jinete: +{fr} Cavalier : +{pt-br} Cavaleiro: +{de} Reiter: +" or "{en} Horsemen defeated: +{ru} Всадников побеждено: +{zh-tw} 名騎士被擊敗：+{zh-cn} 名骑士被击败：+{ko}명의 기사 처치: +{es} Jinetes derrotados: +{fr} Cavaliers vaincus : +{pt-br} Cavaleiros derrotados: +{de} Reiter besiegt: +"
						assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{defeated,horsemenLabel,defeated*6})
						totalScore=totalScore+(defeated*6)
					end
					if (turnOrder[a].score.gHorsemanSlayer or 0)>0 then
						assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{"{en}Greatest Horseman Slayer: +{ru}Лучший истребитель Всадников: +{zh-tw}最佳騎士剋星：+{zh-cn}最佳骑士克星：+{ko}최고의 기사 처치자: +{es}Mayor cazador de Jinetes: +{fr}Meilleur tueur de Cavaliers : +{pt-br}Maior Matador de Cavaleiros: +{de}Größter Reiterbezwinger: +",turnOrder[a].score.gHorsemanSlayer})
						totalScore=totalScore+turnOrder[a].score.gHorsemanSlayer
					end
					UI.setAttribute("TezlaScoreHeadingText","text","{en}Horsemen{ru}Всадники{zh-tw}騎士{zh-cn}骑士{ko}기사{es}Jinetes{fr}Cavaliers{pt-br}Cavaleiros{de}Reiter")
					updateScorePannel("Tezla",lineFeed,assembledText)
				end

				--Dragon competitive scoring. Every player Shield on a coloured head is +1 Fame.
				--Fury follows its printed per-head Greatest Slayer tiebreaker, including +3 each if still tied.
				if againstDragon and gStates.coop==0 then
					assembledText="" lineFeed=0
					local dragonPlayer=dragonScoreSummary.byMage[turnOrder[a].mage] or {levels=0,slayerBonus=0,slayerHeads={}}
					if dragonPlayer.levels>0 then
						local dragonScoreLabel=apocalypseHere and "{en} Head Slayer score: +{ru} Счёт истребителя голов: +{zh-tw} 龍首剋星分數：+{zh-cn} 龙首克星分数：+{ko} 용 머리 처치 점수: +{es} Puntuación de cazador de cabezas: +{fr} Score de tueur de têtes : +{pt-br} Pontuação de matador de cabeças: +{de} Kopfbezwinger-Wertung: +" or "{en} Dragon Head Level(s) Reduced: +{ru} Снижено уровней голов Дракона: +{zh-tw} 降低的巨龍頭部等級：+{zh-cn} 降低的巨龙头部等级：+{ko} 감소시킨 드래곤 머리 레벨: +{es} Niveles de cabezas del Dragón reducidos: +{fr} Niveaux de têtes du Dragon réduits : +{pt-br} Níveis de cabeças do Dragão reduzidos: +{de} Reduzierte Drachenkopf-Stufen: +"
						assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{dragonPlayer.levels,dragonScoreLabel,dragonPlayer.levels})
						totalScore=totalScore+dragonPlayer.levels
					end
					if dragonPlayer.slayerBonus>0 then
						local slayerLabel=furyDragon and "{en} Head Slayer bonus(es): +{ru} Бонус истребителя голов: +{zh-tw} 龍首剋星獎勵：+{zh-cn} 龙首克星奖励：+{ko} 용 머리 처치자 보너스: +{es} Bonificación de cazador de cabezas: +{fr} Bonus de tueur de têtes : +{pt-br} Bônus de matador de cabeças: +{de} Kopfbezwinger-Bonus: +" or "{en} Greatest Head Slayer bonus(es): +{ru} Бонус лучшего истребителя голов: +{zh-tw} 最佳龍首剋星獎勵：+{zh-cn} 最佳龙首克星奖励：+{ko} 최고의 용 머리 처치자 보너스: +{es} Bonificación del mejor cazador de cabezas: +{fr} Bonus du meilleur tueur de têtes : +{pt-br} Bônus do maior matador de cabeças: +{de} Bonus des größten Kopfbezwingers: +"
						assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{#dragonPlayer.slayerHeads,slayerLabel,dragonPlayer.slayerBonus})
						totalScore=totalScore+dragonPlayer.slayerBonus
					end
					local dragonHeading=apocalypseHere and "{en}Head Slayer score{ru}Счёт истребителя голов{zh-tw}龍首剋星分數{zh-cn}龙首克星分数{ko}용 머리 처치 점수{es}Puntuación de cazador de cabezas{fr}Score de tueur de têtes{pt-br}Pontuação de matador de cabeças{de}Kopfbezwinger-Wertung" or (furyDragon and "{en}Apocalypse Dragon{ru}Дракон Апокалипсиса{zh-tw}末日巨龍{zh-cn}末日巨龙{ko}아포칼립스 드래곤{es}Dragón del Apocalipsis{fr}Dragon de l'Apocalypse{pt-br}Dragão do Apocalipse{de}Apokalypse-Drache" or "{en}Dragon{ru}Дракон{zh-tw}巨龍{zh-cn}巨龙{ko}드래곤{es}Dragón{fr}Dragon{pt-br}Dragão{de}Drache")
					UI.setAttribute("TezlaScoreHeadingText","text",dragonHeading)
					updateScorePannel("Tezla",lineFeed,assembledText)
				end

				--Total Score
				if (gStates.coop==0 or gStates.WarOfFourComp==true) then
					UI.setAttribute("CompScoreData", "active", "true")
					UI.setAttribute("Total"..pannel.."ScoreCell", "active", "true")
					if forTheCouncil then
						local resultSuffix=councilMissionResult~="" and joinLang({"\n", councilMissionResult}) or ""
						UI.setAttribute("Total"..pannel.."ScoreText", "text", joinLang({translateWord[turnOrder[a].mage], "{en}'s Final Score: {ru}'s Final Score: {zh-tw}'s Final Score: {zh-cn}'s Final Score: {ko}'s Final Score: {es}'s Final Score: {fr}'s Final Score: {pt-br}'s Final Score: {de}'s Final Score: ", totalScore, resultSuffix}))
					else
						UI.setAttribute("Total"..pannel.."ScoreText", "text", joinLang({translateWord[turnOrder[a].mage], "{en}'s Final Fame: {ru} имеет итого Славы: {zh-tw}的最终名望： {zh-cn}的最终名望： {ko} 의 최종 명성: {es} Fama Final: {fr} Gloire Finale: {pt-br} Fama Final: {de}End-Ruhm: ", totalScore}))
					end
					if gStates.gameScenario=="Conquer and Hold" then UI.setAttribute("Total"..pannel.."ScoreText", "text", joinLang({translateWord[turnOrder[a].mage], "{en}'s Final VP: {ru} имеет итого ПО: {zh-tw}的最终分数： {zh-cn}的最终分数： {ko} 의 최종 승점: {es} Vicepresidente Final: {fr} Vice-Président Final de: {pt-br} Pontos de Vitória Final: {de}s End-VP: ", totalScore})) end
					turnOrder[a].score.finalScore=totalScore
				end
				pannel=pannel+1
			else
				if forTheCouncil~=true then
					assembledText="" lineFeed=0
					if gStates.positionMageKnight[5]~="Volkare" then
						--First Reconnaissance uses normal Achievement scoring only; it does not use Solo Conquest efficiency bonuses.
						if gStates.gameScenario~="First Reconnaissance" then
						--Efficiency
						if gStates.currentRound<gStates.rounds and gStates.gameScenario~="The Lost Relic Blitz" then
							local c=30
							if gStates.gameScenario=="The Gauntlet" then c=40 end
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{gStates.rounds-gStates.currentRound, "{en} Round(s) still to go: +{ru} Оставшиеся Раунды: +{zh-tw}个未开始的轮次： +{zh-cn}个未开始的轮次： +{ko} 남은 라운드: +{es} Rondas Aún por Hacer: +{fr} Rounds Encore à Faire: +{pt-br} Rodadas ainda a completar: +{de} Noch ausstehende Runde(n): +", ((gStates.rounds-gStates.currentRound)*c)})
							coopScore=coopScore+((gStates.rounds-gStates.currentRound)*c)
						end
						if turnOrder[a].score.CardsLeft>0 then
							local c=1
							if gStates.gameScenario=="The Gauntlet" then c=2 end
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{turnOrder[a].score.CardsLeft, "{en} Dummy Card(s) Left: +{ru} Карт у виртуального игрока: +{zh-tw}虚拟玩家剩余牌池量： +{zh-cn}虚拟玩家剩余牌池量： +{ko} 남은 가상 플레이어의 카드: + {es} Cartas Falsas Restantes: +{fr} Cartes Factices Restantes: +{pt-br} Cartas Restantes do Jog. Fic.: +{de} Dummy-Karte(n) links: +", turnOrder[a].score.CardsLeft*c})
							coopScore=coopScore+turnOrder[a].score.CardsLeft*c
						end
						if gStates.endRoundCalled==false then
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{"{en}Round End Not Called: +5{ru}Конец последнего Раунда не был объявлен: +5{zh-tw}最后一轮中没有声明本轮结束： +5{zh-cn}最后一轮中没有声明本轮结束： +5{ko}라운드 종료 선언되지 않음: +5{es}Final de Ronda no Llamado: +5{fr}Fin de Manche non Appelée: +5{pt-br}Rodada final Não chamada: +5{de}Rundenende nicht ausgerufen: +5"})
							coopScore=coopScore+5
						end
						if gStates.gameScenario=="Druid Nights" and gStates.playerCount==1 then
							local rituals=0
							for _,details in pairs(turnOrder) do if details.mage~=gStates.positionMageKnight[5] then rituals=details.druidNightsRitualCount or 0 break end end
							if rituals>0 then
								assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{rituals,"{en} Incantation(s): +{ru} Incantation(s): +{zh-tw} Incantation(s): +{zh-cn} Incantation(s): +{ko} Incantation(s): +{es} Incantation(s): +{fr} Incantation(s): +{pt-br} Incantation(s): +{de} Incantation(s): +",rituals*15})
								coopScore=coopScore+(rituals*15)
							end
						end
						if gStates.gameScenario=="Against the Apocalypse Blitz" and gStates.coop==1 and gStates.endGameAchieved=="true" then
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{"{en}Beat the Scenario: +15{ru}Прохождение сценария: +15{zh-tw}通關劇本：+15{zh-cn}通关剧本：+15{ko}시나리오 클리어: +15{es}Superar el escenario: +15{fr}Victoire dans le scénario : +15{pt-br}Superou o cenário: +15{de}Szenario gemeistert: +15"})
							coopScore=coopScore+15
						end
						updateScorePannel("Efficiency", lineFeed, assembledText)
						end
					else
						--Volkare
						if gStates.volkareWon~=true then
							local volkareCombatLevel={"Daring", "Heroic", "Legendary"}
							local volkareRaceLevel={"Fair", "Tight", "Thrilling"}
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{translateWord[volkareCombatLevel[gStates.volkareCombatLevel]], "{en} Volkare Combat Level: +(({ru} Уровень битвы Волкара: +(({zh-tw}沃卡里战斗等级： +（（{zh-cn}沃卡里战斗等级： +（（{ko} 볼케어 전투 레벨: +(({es} Nivel de Combate Volkare: +(({fr} Niveau de Combat Volkare: +(({pt-br} Nível de Combate de Volkare: +(({de} Volkare Kampfstufe: +((", (gStates.volkareCombatLevel*10)+20})
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{turnOrder[a].score.CardsLeft, "{en} Volkare Card(s) Left: +{ru} Карт у Волкара: +{zh-tw}沃卡里卡池剩余： +{zh-cn}沃卡里卡池剩余： +{ko} 남은 볼케어 카드: +{es} Cartas Volkare Restantes: +{fr} Cartes Volkare Restantes: +{pt-br} Cartas de Volkare Restantes: +{de} Volkare Karte(n) übrig: +", (turnOrder[a].score.CardsLeft*2), ")"})
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{translateWord[volkareRaceLevel[gStates.volkareRaceLevel]], "{en} Volkare Race Level: x{ru} Уровень гонки Волкара: x{zh-tw}沃卡里移动等级： x{zh-cn}沃卡里移动等级： x{ko} 볼케어 레이스 레벨: x{es} Nivel de Carrera Volkare: x{fr} Niveau de Course Volkare: x{pt-br} Nível de Corrida de Volkare: +{de} Volkare Ethnie Stufe: x", (((gStates.volkareRaceLevel-1)/2)+1), ")"})
							coopScore=coopScore+((((gStates.volkareCombatLevel*10)+20)+(turnOrder[a].score.CardsLeft*2))*(((gStates.volkareRaceLevel-1)/2)+1))
							updateScorePannel("Volkare", lineFeed, assembledText)
						end
					end

					--Against the Horsemen cooperative/solo scenario bonuses. Standard cooperative Achievement
					--scoring above already supplies the lowest Fame base and the best score in each category.
					if againstHorsemen then
						assembledText="" lineFeed=0
						if horsemenSummary.total>0 then
							local horsemenLabel=horsemenSummary.total==1 and "{en} Horseman: +{ru} Всадник: +{zh-tw} 名騎士：+{zh-cn} 名骑士：+{ko}명의 기사: +{es} Jinete: +{fr} Cavalier : +{pt-br} Cavaleiro: +{de} Reiter: +" or "{en} Horsemen defeated: +{ru} Всадников побеждено: +{zh-tw} 名騎士被擊敗：+{zh-cn} 名骑士被击败：+{ko}명의 기사 처치: +{es} Jinetes derrotados: +{fr} Cavaliers vaincus : +{pt-br} Cavaleiros derrotados: +{de} Reiter besiegt: +"
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{horsemenSummary.total,horsemenLabel,horsemenSummary.total*4})
							coopScore=coopScore+(horsemenSummary.total*4)
						end
						if gStates.playerCount>1 and horsemanEveryScoringPlayerDefeatedOne(horsemenSummary)==true then
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{"{en}Each player defeated a Horseman: +6{ru}Каждый игрок победил Всадника: +6{zh-tw}每位玩家都擊敗了一名騎士：+6{zh-cn}每位玩家都击败了一名骑士：+6{ko}각 플레이어가 기사를 한 명씩 처치: +6{es}Cada jugador derrotó a un Jinete: +6{fr}Chaque joueur a vaincu un Cavalier : +6{pt-br}Cada jogador derrotou um Cavaleiro: +6{de}Jeder Spieler besiegte einen Reiter: +6"})
							coopScore=coopScore+6
						end
						if horsemenSummary.total>=4 then
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{"{en}All Horsemen defeated: +15{ru}Все Всадники побеждены: +15{zh-tw}所有騎士皆被擊敗：+15{zh-cn}所有骑士皆被击败：+15{ko}모든 기사 처치: +15{es}Todos los Jinetes derrotados: +15{fr}Tous les Cavaliers vaincus : +15{pt-br}Todos os Cavaleiros derrotados: +15{de}Alle Reiter besiegt: +15"})
							coopScore=coopScore+15
						end
						UI.setAttribute("TezlaScoreHeadingText","text","{en}Horsemen{ru}Всадники{zh-tw}騎士{zh-cn}骑士{ko}기사{es}Jinetes{fr}Cavaliers{pt-br}Cavaleiros{de}Reiter")
						local temp=pannel
						pannel=1
						UI.setAttribute("Tezla1ScoreCell","columnSpan","4")
						UI.setAttribute("Tezla1ScoreText","alignment","MiddleCenter")
						updateScorePannel("Tezla",lineFeed,assembledText)
						pannel=temp
					end

					--Dragon cooperative/solo goal scoring. Fury's generic efficiency scoring above already
					--handles +30 per unused Round, +1 per Dummy card left, and uncalled End-of-Round +5.
					if againstDragon then
						assembledText="" lineFeed=0
						if apocalypseHere and horsemenSummary.total>0 then
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{horsemenSummary.total,"{en} Horsemen defeated: +{ru} Всадников побеждено: +{zh-tw} 名騎士被擊敗：+{zh-cn} 名骑士被击败：+{ko}명의 기사 처치: +{es} Jinetes derrotados: +{fr} Cavaliers vaincus : +{pt-br} Cavaleiros derrotados: +{de} Reiter besiegt: +",horsemenSummary.total*3})
							coopScore=coopScore+(horsemenSummary.total*3)
						end
						if apocalypseHere and gStates.playerCount>1 and horsemanEveryScoringPlayerDefeatedOne(horsemenSummary)==true then
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{"{en}Each player defeated a Horseman: +5{ru}Каждый игрок победил Всадника: +5{zh-tw}每位玩家都擊敗一名騎士：+5{zh-cn}每位玩家都击败一名骑士：+5{ko}각 플레이어가 기사를 한 명씩 처치: +5{es}Cada jugador derrotó a un Jinete: +5{fr}Chaque joueur a vaincu un Cavalier : +5{pt-br}Cada jogador derrotou um Cavaleiro: +5{de}Jeder Spieler besiegte einen Reiter: +5"})
							coopScore=coopScore+5
						end
						if dragonScoreSummary.defeatedHeads>0 then
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{dragonScoreSummary.defeatedHeads,"{en} Dragon Head(s) Defeated: +{ru} Побеждено голов Дракона: +{zh-tw} 擊敗的巨龍頭部：+{zh-cn} 击败的巨龙头部：+{ko} 처치한 드래곤 머리: +{es} Cabezas del Dragón derrotadas: +{fr} Têtes du Dragon vaincues : +{pt-br} Cabeças do Dragão derrotadas: +{de} Besiegte Drachenköpfe: +",dragonScoreSummary.defeatedHeads*5})
							coopScore=coopScore+(dragonScoreSummary.defeatedHeads*5)
						end
						if dragonScoreSummary.defeatedHeads>=4 then
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{"{en}All Dragon Heads defeated: +15{ru}Все головы Дракона побеждены: +15{zh-tw}所有巨龍頭部都已擊敗：+15{zh-cn}所有巨龙头部都已击败：+15{ko}모든 드래곤 머리 처치: +15{es}Todas las cabezas del Dragón derrotadas: +15{fr}Toutes les têtes du Dragon vaincues : +15{pt-br}Todas as cabeças do Dragão derrotadas: +15{de}Alle Drachenköpfe besiegt: +15"})
							coopScore=coopScore+15
						end
						local dragonGoalHeading=apocalypseHere and "{en}Apocalypse{ru}Апокалипсис{zh-tw}末日{zh-cn}末日{ko}아포칼립스{es}Apocalipsis{fr}Apocalypse{pt-br}Apocalipse{de}Apokalypse" or (furyDragon and "{en}Apocalypse Dragon{ru}Дракон Апокалипсиса{zh-tw}末日巨龍{zh-cn}末日巨龙{ko}아포칼립스 드래곤{es}Dragón del Apocalipsis{fr}Dragon de l'Apocalypse{pt-br}Dragão do Apocalipse{de}Apokalypse-Drache" or "{en}Dragon{ru}Дракон{zh-tw}巨龍{zh-cn}巨龙{ko}드래곤{es}Dragón{fr}Dragon{pt-br}Dragão{de}Drache")
						UI.setAttribute("TezlaScoreHeadingText","text",dragonGoalHeading)
						local temp=pannel
						pannel=1
						UI.setAttribute("Tezla1ScoreCell","columnSpan","4")
						UI.setAttribute("Tezla1ScoreText","alignment","MiddleCenter")
						updateScorePannel("Tezla",lineFeed,assembledText)
						pannel=temp
					end

					--Relic Score
					if gStates.gameScenario=="The Lost Relic Blitz" then
						assembledText="" lineFeed=0
						if foundRelic>0 then
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{foundRelic, "{en} Relic(s) Found: +{ru} Реликвия найдена: +{zh-tw}个圣器已收集: +{zh-cn}个圣器已收集: +{ko} 발견한 유물: +{es} Reliquias Encontradas: +{fr} Reliques Trouvées: +{pt-br} Relíquias Encontradas: +{de} Relikt(e) gefunden: +", (foundRelic*5)})
							coopScore=coopScore+(foundRelic*5)
						end
						if gStates.playersRef~=5 then
							local EveryRelic=true
							for b=1, #turnOrder, 1 do
								if turnOrder[b].mage~=gStates.positionMageKnight[5] then
									if turnOrder[b].score.Relic==0 then EveryRelic=false break end
								end
							end
							if EveryRelic==true then
								assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{"{en}Every player collected a Relic: +5{ru}Каждый игрок собрал реликвию: +5{zh-tw}每位玩家收集一件圣器: +5{zh-cn}每位玩家收集一件圣器: +5{ko}모든 플레이어 유물 수집: +5{es}Cada Jugador Recogió una Reliquia: +5{fr}Chaque Joueur a Récupéré une Relique: +5{pt-br}Cada Jogador coletou uma Relíquia: +5{de}Jeder Spieler hat eine Reliquie gesammelt: +5"})
								coopScore=coopScore+5
							end
						end
						if foundRelic==gStates.cityTiles then
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{"{en}All relics collected: +10{ru}Все реликвии собраны: +10{zh-tw}收集所有圣器: +10{zh-cn}收集所有圣器: +10{ko}모든 유물 수집됨: +10{es}Todas las Reliquias Recolectadas: +10{fr}Toutes les Reliques Collectées: +10{pt-br}Todas Relíquias Coletadas: +10{de}Alle gesammelten Reliquien: +10"})
							coopScore=coopScore+10
						end
						local temp=pannel
						pannel=1
						UI.setAttribute("Relic1ScoreCell", "columnSpan", "4")
						UI.setAttribute("Relic1ScoreText", "alignment", "MiddleCenter")
						updateScorePannel("Relic", lineFeed, assembledText)
						pannel=temp
					end

					--City Coop Score. Fractured Lands explicitly does not use City scoring.
					if fracturedLandsNoCityScore~=true and (gStates.defeatedCities.amount>0 or gStates.gameScenario=="The Gauntlet") then
						assembledText="" lineFeed=0
						local cityValue=10
						if gStates.gameScenario=="Volkare's Return" or gStates.gameScenario=="Volkare's Return Blitz" then cityValue=20 end
						if gStates.gameScenario=="Volkare's Quest" then cityValue=5 end
						if gStates.gameScenario~="The Gauntlet" then
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{gStates.defeatedCities.amount, "{en} Conquered City(s): +{ru} Захваченный Город: +{zh-tw}个城市已征服: +{zh-cn}个城市已征服: +{ko} 정복한 도시: +{es} Ciudades Conquistadas: +{fr} Villes Conquises: +{pt-br} Cidades Conquistadas: +{de} Eroberte Stadt(en): +", (gStates.defeatedCities.amount*cityValue)})
							coopScore=coopScore+(gStates.defeatedCities.amount*cityValue)
						end
						if gStates.gameScenario~="Volkare's Return" and gStates.gameScenario~="Volkare's Return Blitz" and gStates.gameScenario~="Volkare's Quest" then
							if gStates.playersRef~=5 and gStates.allLeaderCheck==true then
								assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{"{en}Each Player is a Leader of a City: +10{ru}Каждый игрок владеет Городом: +10{zh-tw}每个玩家都是一个城市的领袖: +10{zh-cn}每个玩家都是一个城市的领袖: +10{ko}각 플레이어가 도시 지도자: +10{es}Cada Jugador es un Líder de una Ciudad: +10{fr}Chaque Joueur est un Chef de Ville: +10{pt-br}Cada jogador é um líder de uma cidade: +10{de}Jeder Spieler ist ein Anführer einer Stadt: +10"})
								coopScore=coopScore+10
							end
							if gStates.defeatedCities.amount==gStates.cityTiles then--+gStates.megapolis
								assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{"{en}All Cities are Conquered: +15{ru}Все города захвачены: +15{zh-tw}征服了所有城市: +15{zh-cn}征服了所有城市: +15{ko}모든 도시 정복됨: +15{es}Todas las Ciudades son Conquistadas: +15{fr}Toutes les Villes Sont Conquises: +15{pt-br}Todas Cidades Conquistadas: +15{de}Alle Städte sind erobert: +15"})
								coopScore=coopScore+15
							end
						end
						if gStates.gameScenario=="The Gauntlet" and gStates.endGameAchieved=="true" then
							assembledText="{en}Entered the Red City: +10\nBought the Artifact: +10{ru}Красный город посещен: +10\nАртефакт куплен: +10{zh-tw}进入红色城市： +10\n购买圣器： +10{zh-cn}进入红色城市： +10\n购买圣器： +10{ko}적색 도시 입장: +10\n유물 구입: +10{es}Entró en la Ciudad Roja: +10\nCompró la Reliquia: +10{fr}Entrée dans la Ville Rouge: +10\nAcheté la Relique: +10{pt-br}Entrou na Cidade Vermelha:+10\nComprou a Relíquia: +10{de}Die Rote Stadt betreten: +10\nKaufte das Artefakt: +10"
							lineFeed=2
							coopScore=coopScore+20
						end

						local temp=pannel
						pannel=1
						UI.setAttribute("City1ScoreCell", "columnSpan", "4")
						UI.setAttribute("City1ScoreText", "alignment", "MiddleCenter")
						updateScorePannel("City", lineFeed, assembledText)
						pannel=temp
					end

					--Faction Leader Coop Score. Horsemen and Dragon scenarios reuse this UI row for
					--their scenario scoring above, so do not clear or relabel it afterward.
					if againstHorsemen~=true and againstDragon~=true then
					assembledText="" lineFeed=0
					if (gStates.gameScenario=="Life and Death" or gStates.gameScenario=="Ultimate Conquest") and gStates.coop==1 and gStates.defeatedFaction>0 then
						assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{gStates.defeatedFaction, "{en} Leader(s) Defeated: +{ru} Лидер побежден: +{zh-tw}个领袖已击败: +{zh-cn}个领袖已击败: +{ko} 처치한 지도자: +{es} Líderes Derrotados: +{fr} Chefs Vaincus: +{pt-br} Líderes Derrotados: +{de} Anführer besiegt: +", (gStates.defeatedFaction*10)})
						coopScore=coopScore+(gStates.defeatedFaction*10)
						if gStates.defeatedFaction==2 then
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{"{en}Both Leaders are defeated: +15{ru}Оба Лидера побеждены: +15{zh-tw}两位领袖都被击败: +15{zh-cn}两位领袖都被击败: +15{ko}모든 지도자 처치됨: +15{es}Ambos Líderes son Derrotados: +15{fr}Les deux Chefs sont Vaincus: +15{pt-br}Ambos líderes derrotados: +15{de}Beide Anführer sind besiegt: +15"})
							coopScore=coopScore+15
							if gStates.playersRef~=5 then
								if gStates.allPlayersFoughtAFactionLeaderCheck==true then
									assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{"{en}Every player helped defeat a Leader: +10{ru}Каждый игрок помог победить Лидера: +10{zh-tw}每个玩家都帮助击败了一个领袖: +10{zh-cn}每个玩家都帮助击败了一个领袖: +10{ko}모든 플레이어가 지도자 처치에 참여: +10{es}Cada Jugador Ayudó a Derrotar a un Líder: +10{fr}Chaque Joueur a Aidé à Vaincre un Leader: +10{pt-br}Cada Jogador ajudou a derrotar um Líder: +10{de}Jeder Spieler hat geholfen, einen Anführer zu besiegen: +10"})
									coopScore=coopScore+10
								end
								if gStates.allPlayersFoughtBothFactionLeaderCheck==true then
									assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{"{en}Every player helped defeat Both Leaders: +10{ru}Каждый игрок помог победить обоих Лидеров: +10{zh-tw}每个玩家都帮助击败了两个领袖: +10{zh-cn}每个玩家都帮助击败了两个领袖: +10{ko}모든 플레이어가 두 지도차 처치에 참여: +10{es}Cada Jugador Ayudó a Derrotar a Ambos Líderes: +10{fr}Chaque Joueur a Aidé à Vaincre les Deux Leaders: +10{pt-br}Cada Jogador ajudou a derrotar ambos Líderes: +10{de}Jeder Spieler hat geholfen, beide Anführer zu besiegen: +10"})
									coopScore=coopScore+10
								end
							end
						end
					end
					if gStates.gameScenario=="The Realm of the Dead Blitz" and gStates.coop==1 then
						if gStates.defeatedFaction>0 then
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{"{en}Necromancer is Defeated: +10{ru}Некромант побежден: +10{zh-tw}亡灵法师被击败: +10{zh-cn}亡灵法师被击败: +10{ko}네크로맨서 처치됨: +10{es}Nigromante es Derrotado: +10{fr}Nécromancien est Vaincu: +10{pt-br}Necromante derrotado: +10{de}Nekromant ist besiegt: +10"})
							coopScore=coopScore+10
						end
						if coopGraveYard>0 then
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{coopGraveYard, "{en} Graveyard(s) sealed: +{ru} Кладбище запечатано: +{zh-tw}个墓穴已封印: +{zh-cn}个墓穴已封印: +{ko} 봉인된 묘지: +{es} Cementerios Sellados: +{fr} Cimetières Scellés: +{pt-br} Cemitérios Selados: +{de} Friedhof(e) versiegelt: +", (coopGraveYard*5)})
							coopScore=coopScore+(coopGraveYard*5)
						end
						if gStates.defeatedFaction>0 and coopGraveYard>=gStates.playerCount+1 then
							assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{"{en}Necromancer defeated & Graveyards sealed: +10{ru}Некромант побежден & Кладбища запечатаны: +10{zh-tw}亡灵法师被击败并封印墓穴: +10{zh-cn}亡灵法师被击败并封印墓穴: +10{ko}네크로맨서 처치 & 묘지 봉인됨: +10{es}Nigromante derrotado y Cementerios sellados: +10{fr}Nécromancien vaincu & Cimetières scellés: +10{pt-br}Necromante derrotado e Cemitérios Selados: +10{de}Nekromant besiegt & Friedhöfe versiegelt: +10"})
							coopScore=coopScore+10
						end
					end
					if (gStates.gameScenario=="The Realm of the Dead Blitz" or gStates.gameScenario=="The Hidden Valley Blitz") and gStates.coop==1 and gStates.playersRef~=5 and gStates.allPlayersFoughtAFactionLeaderCheck==true and gStates.defeatedFaction>0 then
						assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{"{en}Every player helped defeat the Leader: +20{ru}Каждый игрок помог победить Лидера: +20{zh-tw}所有玩家都帮助击败了首领: +20{zh-cn}所有玩家都帮助击败了首领: +20{ko}모든 플레이어가 지도자 처치에 참여: +20{es}Todos los Jugadores Ayudaron a Derrotar al Líder: +20{fr}Chaque Joueur a Aidé à Vaincre le Leader: +20{pt-br}Cada Jogador ajudou a derrotar o Líder: +20{de}Jeder Spieler hat geholfen, den Anführer zu besiegen: +20"})
						coopScore=coopScore+20
					end
					if gStates.gameScenario=="The Hidden Valley Blitz" and gStates.coop==1 and gStates.defeatedFaction>0 then
						assembledText,lineFeed=appendScoreLine(assembledText,lineFeed,{"{en}Defeated the High Priestess: +20{ru}Верховная Жрица побеждена: +20{zh-tw}击败高阶祭司: +20{zh-cn}击败高阶祭司: +20{ko}하이 프리스트 처치됨: +20{es}Derrota a la Suma Sacerdotisa: +20{fr}Vaincre la Grande Prêtresse: +20{pt-br}Derrotou a Alta Sacerdotiza: +20{de}Die Hohepriesterin besiegt: +20"})
						coopScore=coopScore+20
					end
					local temp=pannel
					pannel=1
					UI.setAttribute("TezlaScoreHeadingText", "text", "{en}Faction Scoring{ru}Подсчет очков фракций{zh-tw}派系得分{zh-cn}派系得分{ko}세력 점수{es}Puntuación de Facción{fr}Décompte des Factions{pt-br}Pontuação de Facção{de}Faction-Wertung")
					UI.setAttribute("Tezla1ScoreCell", "columnSpan", "4")
					UI.setAttribute("Tezla1ScoreText", "alignment", "MiddleCenter")
					updateScorePannel("Tezla", lineFeed, assembledText)
					pannel=temp
					end
				end
				--Total Score
				UI.setAttribute("CoopScoreData", "active", "true")
				if forTheCouncil then
					local resultSuffix=councilMissionResult~="" and joinLang({"\n", councilMissionResult}) or ""
					UI.setAttribute("CoopScoreText", "text", joinLang({"{en}Final Score: {ru}Final Score: {zh-tw}Final Score: {zh-cn}Final Score: {ko}Final Score: {es}Final Score: {fr}Final Score: {pt-br}Final Score: {de}Final Score: ", coopScore, resultSuffix}))
				else
					UI.setAttribute("CoopScoreText", "text", joinLang({"{en}Final Fame: {ru}Итого Славы: {zh-tw}最终名望: {zh-cn}最终名望: {ko}최종 명성: {es}Fama Final: {fr}Gloire Finale: {pt-br}Fama Final: {de}Endgültiger Ruhm: ", coopScore}))
				end
				--The Dummy can be first or last in turnOrder depending on scenario Tactic rules.
				--Assign the team score by identity instead of assuming the final array entry is always the Dummy.
				for _,details in ipairs(turnOrder) do
					if details.mage~=gStates.positionMageKnight[5] then details.score.finalScore=coopScore end
				end
			end
		end

		--final scoreboard tweaks
		if player=="all" then
			setUIVisibility("ScoreBoard")
		else
			scoreViewing[#scoreViewing+1]=player.color
			setUIVisibility("ScoreBoard",scoreViewing)
		end
		UI.show("ScoreBoard")
		for a, b in pairs(heights) do
			if b>24 and a~="Reward" then totalHeight=totalHeight+30 end
		end
		UI.setAttribute("ScoreBoard", "height", totalHeight)
		UI.setAttribute("ScoreBoard", "width", (pannel-1)*280)
		if gStates.playersRef==5 then
			UI.setAttribute("ScoreBoard", "width", 400)
			UI.setAttribute("ScoreBoardTable", "columnWidths", "400")
		end
		if gameOver==true and gStates.scoreRecorded==false then UI.show("SendScoreRequest") gStates.scoreRecorded=true end
		table.sort(turnOrder, function (k1, k2) return k1.tactic<k2.tactic end)
	end
end

-- Final claimed-card layout
function layoutClaimedCards()
	--A Time Bending set aside on the victorious final round still belongs to its owner and must be present for scoring.
	if gStates~=nil and gStates.timeBendingRemovedSeat~=nil then if reclaimTimeBending(layoutClaimedCards)==true then return end end
	--Never dismantle live deed decks/hands while the active turn is still waiting
	--for Rewards Claimed. The final boundary must be crossed first.
	if gStates~=nil and gStates.preEndTurn==true then
		log("layoutClaimedCards ignored: Rewards Claimed is still pending.")
		return
	end
	--Score the untouched deck/discard/hand/play-area state before dismantling Deck objects.
	--TTS zone membership can lag behind takeObject/setPosition by a frame, and Deck remainders below
	--are deliberately moved later, so scoring after the layout could temporarily miss claimed cards.
	displayScore("all", "-1", nil)
	for _, turnDetails in pairs(turnOrder) do
		if turnDetails.mage~=gStates.positionMageKnight[5] then
			local obj={}
			local OffsetX={["Advanced Action"]=0, ["Spell"]=0, ["Artifact"]=0, ["Wound"]=0}
			local OffsetY={["Advanced Action"]=0, ["Spell"]=0, ["Artifact"]=0, ["Wound"]=0}
			local OffsetZ={["Advanced Action"]=0, ["Spell"]=0, ["Artifact"]=0, ["Wound"]=0}
			local OffsetStart={["Advanced Action"]=-97, ["Spell"]=-91, ["Artifact"]=-85, ["Wound"]=-103}
			local xOffset=0.4
			local yOffset=0.04
			local zOffset=0.8
			--Look for Cards
			for _, c in pairs(getObjectFromGUID(deedDeckZones[turnDetails.seatPos]).getObjects()) do obj[#obj+1]=c end
			for _, c in pairs(getObjectFromGUID(deedDeckDiscardZones[turnDetails.seatPos]).getObjects()) do obj[#obj+1]=c end
			for _, c in pairs(getObjectFromGUID(handZones[turnDetails.seatPos]).getObjects()) do obj[#obj+1]=c end
			for _, c in pairs(obj) do
				if c.type=="Deck" then
					for _, card in pairs(c.getObjects()) do
						if c.remainder~=nil and (card.gm_notes=="Advanced Action" or card.gm_notes=="Spell" or card.gm_notes=="Artifact" or card.gm_notes=="Wound") then
							local lastCard=c.remainder
							safeWaitFrames("Scoring",function()
								lastCard.setPosition({(turnDetails.seatPos*40)+OffsetStart[card.gm_notes]+OffsetX[card.gm_notes], 1.1+OffsetY[card.gm_notes], -39.4-OffsetZ[card.gm_notes]})
								OffsetX[card.gm_notes]=OffsetX[card.gm_notes]+xOffset
								OffsetY[card.gm_notes]=OffsetY[card.gm_notes]+yOffset
								OffsetZ[card.gm_notes]=OffsetZ[card.gm_notes]+zOffset
								if OffsetZ[card.gm_notes]>4.8 then OffsetZ[card.gm_notes]=0 end
							end, 10)
							break
						end
						if card.gm_notes=="Advanced Action" or card.gm_notes=="Spell" or card.gm_notes=="Artifact" or card.gm_notes=="Wound" then
							c.takeObject({position={(turnDetails.seatPos*40)+OffsetStart[card.gm_notes]+OffsetX[card.gm_notes], 1.1+OffsetY[card.gm_notes], -39.4-OffsetZ[card.gm_notes]}, rotation={0, 180, 0}, guid=card.guid, smooth=false})
							OffsetX[card.gm_notes]=OffsetX[card.gm_notes]+xOffset
							OffsetY[card.gm_notes]=OffsetY[card.gm_notes]+yOffset
							OffsetZ[card.gm_notes]=OffsetZ[card.gm_notes]+zOffset
							if OffsetZ[card.gm_notes]>4.8 then OffsetZ[card.gm_notes]=0 end
						end
					end
				end
				if c.type=="Card" and (c.getGMNotes()=="Advanced Action" or c.getGMNotes()=="Spell" or c.getGMNotes()=="Artifact" or c.getGMNotes()=="Wound") then
					c.setPosition({(turnDetails.seatPos*40)+OffsetStart[c.getGMNotes()]+OffsetX[c.getGMNotes()], 1.1+OffsetY[c.getGMNotes()], -39.4-OffsetZ[c.getGMNotes()]})
					OffsetX[c.getGMNotes()]=OffsetX[c.getGMNotes()]+xOffset
					OffsetY[c.getGMNotes()]=OffsetY[c.getGMNotes()]+yOffset
					OffsetZ[c.getGMNotes()]=OffsetZ[c.getGMNotes()]+zOffset
					if OffsetZ[c.getGMNotes()]>4.8 then OffsetZ[c.getGMNotes()]=0 end
				end
			end
		end
	end
end

--Swap Day and Night items

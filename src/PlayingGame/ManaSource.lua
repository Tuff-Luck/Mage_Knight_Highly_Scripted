-- Mirrored Mana Source runtime.

-- Shared Mana Source mirrors
exitWaitID={}
mirrorSpawnEnterIgnore={}
mirrorDestroyIgnore={}
mirrorSourceClaim={}
mirrorFaceWaitID={}
mirrorSourceRefreshWait=nil
mirrorManualRandomize={}
mirrorRepositionIgnore={}
spentMirrorDice={}
function manaSourceDieGUID(guid)
	if guid==nil or gStates.manaSource==nil then return false end
	for _, die in pairs(gStates.manaSource) do if die.manaDie==guid then return true end end
	return false
end
function mirrorSourceBusy()
	for _, waitfunction in pairs(exitWaitID) do if waitfunction~=nil then return true end end
	for _, claim in pairs(mirrorSourceClaim) do if claim~=nil then return true end end
	for _, sourceGUID in pairs(mirrorManualRandomize) do if sourceGUID~=nil then return true end end
	return false
end
function manaSourceZoneHasDie(guid)
	local zone=getObjectFromGUID(GUID.zone.mana)
	if zone==nil or guid==nil then return false end
	for _, obj in pairs(zone.getObjects()) do if obj.guid==guid then return true end end
	return false
end
function scheduleReturnedSourceMirror(sourceDie)
	if sourceDie==nil or sourceDie.guid==nil then return end
	local sourceGUID=sourceDie.guid
	--Do not make mirror restoration depend solely on the generic zone-enter callback. As soon as this exact
	--returned die is physically inside the real Source, rebuild the missing copies; correct its face again after settling.
	safeWaitCondition("ManaSource",function()
		local die=getObjectFromGUID(sourceGUID)
		if die==nil then return end
		mirrorSourceUpdate("returned die entered real Source")
		safeWaitCondition("ManaSource",function()
			if getObjectFromGUID(sourceGUID)~=nil then mirrorSourceUpdate("returned die settled in real Source") end
		end, function()
			local current=getObjectFromGUID(sourceGUID)
			return current==nil or current.resting
		end)
	end, function()
		return getObjectFromGUID(sourceGUID)==nil or manaSourceZoneHasDie(sourceGUID)==true
	end)
end
function scheduleMirrorSourceUpdate(from, delay)
	if mirrorSourceRefreshWait~=nil then Wait.stop(mirrorSourceRefreshWait) end
	mirrorSourceRefreshWait=safeWaitTime("ManaSource",function()
		mirrorSourceRefreshWait=nil
		if mirrorSourceBusy()==true then
			mirrorSourceRefreshWait=safeWaitCondition("ManaSource",function()
				mirrorSourceRefreshWait=nil
				mirrorSourceUpdate(from)
			end, function() return mirrorSourceBusy()==false end)
		else
			mirrorSourceUpdate(from)
		end
	end, delay or 0.1)
end
function mirrorSourceState()
	local colorConvert={["Blue Mana"]=1, ["White Mana"]=2, ["Green Mana"]=3, ["Red Mana"]=4, ["Gold Mana"]=5, ["Black Mana"]=6}
	if gStates.dayRound==false then colorConvert["Gold Mana"]=6 colorConvert["Black Mana"]=5 end
	local colorRotate={{0, 0, 0}, {0, 0, 270}, {0, 0, 90}, {0, 0, 180}, {90, 0, 0}, {270, 0, 0}}
	if gStates.dayRound==false then colorRotate[5]={270, 0, 0} colorRotate[6]={90, 0, 0} end
	local sourceDice={}
	local seperate=0
	for _, manaDie in pairs(getObjectFromGUID(GUID.zone.mana).getObjects()) do
		local color=manaDie.type=="Dice" and colorConvert[manaDie.getRotationValue()] or nil
		if color~=nil then
			sourceDice[#sourceDice+1]={manaDie=manaDie.guid, color=color}
			if color==6 then seperate=0.25 end
		end
	end
	table.sort(sourceDice, function(k1, k2) return k1.color<k2.color end)
	return sourceDice, colorRotate, seperate
end

function mirrorSourcePlayers()
	local players={}
	for playerIndex, playerDetails in ipairs(turnOrder) do
		if playerDetails.mage~=gStates.positionMageKnight[5] and playerDropoutInactive(playerIndex)==false then players[#players+1]=playerDetails end
	end
	table.sort(players, function(a, b) return (a.seatPos or 99)<(b.seatPos or 99) end)
	return players
end

--Face changes do not need new physical dice. Reuse the existing copies, update their faces and
--slide them into the same sorted positions a rebuild would have produced. If the Source set changed,
--return false so mirrorSourceUpdate can fall back to the structural rebuild.
function mirrorSourceSyncExisting(sourceDice, colorRotate, seperate)
	if gStates.manaMirror==nil then return false end
	local players=mirrorSourcePlayers()
	local expected=#sourceDice*#players
	local sourceSet={}
	local mirrorsBySource={}
	for _, die in ipairs(sourceDice) do sourceSet[die.manaDie]=true mirrorsBySource[die.manaDie]={} end
	local mirrorCount=0
	for mirrorGUID, sourceGUID in pairs(gStates.manaMirror) do
		local mirror=getObjectFromGUID(mirrorGUID)
		if mirror==nil or sourceSet[sourceGUID]~=true then return false end
		mirrorCount=mirrorCount+1
		mirrorsBySource[sourceGUID][#mirrorsBySource[sourceGUID]+1]=mirror
	end
	if mirrorCount~=expected then return false end
	for _, die in ipairs(sourceDice) do if #mirrorsBySource[die.manaDie]~=#players then return false end end
	if expected==0 then gStates.manaSource=sourceDice return true end

	local used={}
	for _, playerDetails in ipairs(players) do
		local spacing=0
		local first=false
		local localSeperate=seperate
		for pos, die in ipairs(sourceDice) do
			if die.color==6 and first==false then
				spacing=0.5 first=true
				if pos==1 then localSeperate=0 spacing=0 end
			end
			local target={-105+(40*playerDetails.seatPos)+((1.5*pos)+spacing)+(((8-gStates.diceNeeded)/2)*1.5)-localSeperate, 1.57, -28.1}
			local best=nil
			local bestDist=99999
			for _, mirror in ipairs(mirrorsBySource[die.manaDie]) do
				if used[mirror.guid]~=true then
					local p=mirror.getPosition()
					local dist=math.abs(p[1]-target[1])
					if dist<bestDist then best=mirror bestDist=dist end
				end
			end
			if best==nil then return false end
			used[best.guid]=true
			mirrorRepositionIgnore[best.guid]=true
			best.setRotation(colorRotate[die.color])
			local p=best.getPosition()
			if math.abs(p[1]-target[1])>0.02 or math.abs(p[2]-target[2])>0.08 or math.abs(p[3]-target[3])>0.02 then best.setPosition(target) end
			local mirrorGUID=best.guid
			safeWaitFrames("ManaSource",function() mirrorRepositionIgnore[mirrorGUID]=nil end, 3)
		end
	end
	gStates.manaSource=sourceDice
	return true
end

function mirrorSourceUpdate(from)
	--Never alter mirror dice while a player is physically resolving one.
	if mirrorSourceBusy()==true then scheduleMirrorSourceUpdate(from, 0.05) return end
	if getObjectFromGUID(GUID.zone.mana)==nil or getObjectFromGUID(GUID.bag.spareDice)==nil then return end
	local sourceDice, colorRotate, seperate=mirrorSourceState()
	--The normal fast path: same Source GUIDs, so only update/re-sort the existing physical copies.
	if mirrorSourceSyncExisting(sourceDice, colorRotate, seperate)==true then return end

	--Structural change (die spent/returned/added, player set changed, stale save): rebuild the mirror set.
	if gStates.manaMirror~=nil then
		for dieDel, _ in pairs(gStates.manaMirror) do
			mirrorSpawnEnterIgnore[dieDel]=nil
			mirrorRepositionIgnore[dieDel]=nil
			mirrorDestroyIgnore[dieDel]=true
			mirrorManualRandomize[dieDel]=nil
			if mirrorFaceWaitID[dieDel]~=nil then Wait.stop(mirrorFaceWaitID[dieDel]) mirrorFaceWaitID[dieDel]=nil end
			if exitWaitID~=nil and exitWaitID[dieDel]~=nil then Wait.stop(exitWaitID[dieDel]) exitWaitID[dieDel]=nil end
			local oldDie=getObjectFromGUID(dieDel)
			if oldDie~=nil then oldDie.destruct() end
			local oldGUID=dieDel
			safeWaitFrames("ManaSource",function() mirrorDestroyIgnore[oldGUID]=nil end, 3)
		end
	end
	gStates.manaMirror={}
	gStates.manaSource=sourceDice
	mirrorSourceClaim={}
	local players=mirrorSourcePlayers()
	for _, playerDetails in ipairs(players) do
		local spacing=0
		local first=false
		local localSeperate=seperate
		for pos, die in ipairs(sourceDice) do
			if die.color==6 and first==false then
				spacing=0.5 first=true
				if pos==1 then localSeperate=0 spacing=0 end
			end
			local mirrorDie=getObjectFromGUID(GUID.bag.spareDice).takeObject({position={-105+(40*playerDetails.seatPos)+((1.5*pos)+spacing)+(((8-gStates.diceNeeded)/2)*1.5)-localSeperate, 1.57, -28.1}, rotation=colorRotate[die.color], smooth=false})
			gStates.manaMirror[mirrorDie.guid]=die.manaDie
			mirrorSpawnEnterIgnore[mirrorDie.guid]=true
			local mirrorGUID=mirrorDie.guid
			safeWaitFrames("ManaSource",function() mirrorSpawnEnterIgnore[mirrorGUID]=nil end, 3)
		end
	end
end

function mirrorSourceFaceSync(diceGUID, sourceGUID, from)
	mirrorFaceWaitID[diceGUID]=nil
	local dice=getObjectFromGUID(diceGUID)
	local source=getObjectFromGUID(sourceGUID)
	if dice==nil or source==nil or gStates.manaMirror==nil or gStates.manaMirror[diceGUID]~=sourceGUID then return end
	source.setRotation(dice.getRotation())
	mirrorSourceUpdate(from)
end
function scheduleMirrorFaceSync(dice, from)
	if dice==nil or dice.guid==nil or gStates.manaMirror==nil then return false end
	if mirrorRepositionIgnore[dice.guid]==true then return true end
	local sourceGUID=gStates.manaMirror[dice.guid]
	if sourceGUID==nil then return false end
	--Once a physical copy has started taking this shared die, face-change shortcuts on any copy must not alter the Source.
	if mirrorSourceClaim[sourceGUID]~=nil then return true end
	if mirrorFaceWaitID[dice.guid]~=nil then Wait.stop(mirrorFaceWaitID[dice.guid]) end
	local diceGUID=dice.guid
	mirrorFaceWaitID[diceGUID]=safeWaitFrames("ManaSource",function() mirrorSourceFaceSync(diceGUID, sourceGUID, from) end, 2)
	return true
end
function scheduleMirrorRandomizeSync(dice, from)
	if dice==nil or dice.guid==nil or gStates.manaMirror==nil then return false end
	local sourceGUID=gStates.manaMirror[dice.guid]
	if sourceGUID==nil then return false end
	--If this Source die is already being physically taken, R applies only to that held copy; do not cancel the spend.
	if mirrorSourceClaim[sourceGUID]~=nil then return true end
	local diceGUID=dice.guid
	mirrorManualRandomize[diceGUID]=sourceGUID
	if exitWaitID[diceGUID]~=nil then Wait.stop(exitWaitID[diceGUID]) exitWaitID[diceGUID]=nil end
	if mirrorFaceWaitID[diceGUID]~=nil then Wait.stop(mirrorFaceWaitID[diceGUID]) end
	local function finishRandomize()
		mirrorFaceWaitID[diceGUID]=nil
		mirrorManualRandomize[diceGUID]=nil
		mirrorSourceFaceSync(diceGUID, sourceGUID, from)
	end
	mirrorFaceWaitID[diceGUID]=safeWaitFrames("ManaSource",function()
		mirrorFaceWaitID[diceGUID]=safeWaitCondition("ManaSource",finishRandomize, function()
			local die=getObjectFromGUID(diceGUID)
			return die==nil or die.resting
		end, 10, finishRandomize)
	end, 2)
	return true
end
function scheduleRealSourceRefresh(dice, from, waitForRest)
	if dice==nil or dice.guid==nil or manaSourceDieGUID(dice.guid)~=true then return false end
	local diceGUID=dice.guid
	if mirrorFaceWaitID[diceGUID]~=nil then Wait.stop(mirrorFaceWaitID[diceGUID]) end
	local function refresh()
		mirrorFaceWaitID[diceGUID]=nil
		if getObjectFromGUID(diceGUID)~=nil then mirrorSourceUpdate(from) end
	end
	if waitForRest==true then
		mirrorFaceWaitID[diceGUID]=safeWaitFrames("ManaSource",function()
			mirrorFaceWaitID[diceGUID]=safeWaitCondition("ManaSource",refresh, function()
				local die=getObjectFromGUID(diceGUID)
				return die==nil or die.resting
			end, 10, refresh)
		end, 2)
	else
		mirrorFaceWaitID[diceGUID]=safeWaitFrames("ManaSource",refresh, 2)
	end
	return true
end
function diceResting(dice, state)
	if dice==nil or dice.type~="Dice" or dice.guid==nil then return end
	if gStates~=nil and gStates.apocalypseQuestRollDice~=nil and gStates.apocalypseQuestRollDice[dice.guid]==true then return end
	--Script-driven mirror destruction can emit collision exits; never interpret those as spending Source mana.
	if mirrorDestroyIgnore[dice.guid]==true then return end
	--In-place mirror face/order synchronization may briefly cross the collision surface.
	if mirrorRepositionIgnore[dice.guid]==true then return end
	--A mirror being randomized can leave/re-enter the collision surface while it rolls. That is a face change, not spending the die.
	if mirrorManualRandomize[dice.guid]~=nil then return end
	--New mirror dice naturally fire one collision-enter as they land. Ignore only that event.
	if state=="enter" and mirrorSpawnEnterIgnore[dice.guid]==true then return end
	if exitWaitID[dice.guid]~=nil then Wait.stop(exitWaitID[dice.guid]) exitWaitID[dice.guid]=nil end
	local sourceGUID=gStates.manaMirror~=nil and gStates.manaMirror[dice.guid] or nil
	--Only a die that actually spent a mirrored Source entry may be returned here. Other dice can
	--touch the collision surface without being destroyed or creating a new real Source die.
	if sourceGUID==nil then
		if state~="enter" or spentMirrorDice[dice.guid]~=true then return end
		local diceGUID=dice.guid
		local function returnDieToSource()
			exitWaitID[diceGUID]=nil
			local currentDice=getObjectFromGUID(diceGUID)
			local spareDice=getObjectFromGUID(GUID.bag.spareDice)
			if currentDice==nil or spareDice==nil then return end
			local returnedSource=spareDice.takeObject({position={-12.5+(math.random()*7), 1.5 , -24.0+(math.random()*3.5)}, rotation=currentDice.getRotation(), smooth=false})--Mana Dice Container
			spentMirrorDice[diceGUID]=nil
			scheduleReturnedSourceMirror(returnedSource)
			onObjectRandomize({type="Dice"})
			currentDice.destruct()
		end
		exitWaitID[diceGUID]=safeWaitCondition("ManaSource",returnDieToSource, function()
			local currentDice=getObjectFromGUID(diceGUID)
			return currentDice==nil or currentDice.resting
		end, 10, returnDieToSource)
		return
	end
	--Only one physical mirror may be taking a shared Source die at a time. A second simultaneous copy stays stale until the first action resolves/rebuilds.
	if state=="exit" then
		if mirrorSourceClaim[sourceGUID]~=nil and mirrorSourceClaim[sourceGUID]~=dice.guid then return end
		mirrorSourceClaim[sourceGUID]=dice.guid
	elseif state=="enter" then
		if mirrorSourceClaim[sourceGUID]~=nil and mirrorSourceClaim[sourceGUID]~=dice.guid then return end
		if mirrorSourceClaim[sourceGUID]==dice.guid then mirrorSourceClaim[sourceGUID]=nil end
	end
	local diceGUID=dice.guid
	local function updateDice()
		exitWaitID[diceGUID]=nil
		local currentDice=getObjectFromGUID(diceGUID)
		local mappedSource=gStates.manaMirror~=nil and gStates.manaMirror[diceGUID] or nil
		if mappedSource~=sourceGUID then return end
		--Removed a die from a mirrored Source: spend the one shared real Source die.
		if state=="exit" then
			local source=getObjectFromGUID(sourceGUID)
			if source~=nil then source.destruct() end
			spentMirrorDice[diceGUID]=true
			gStates.manaMirror[diceGUID]=nil
			mirrorSourceClaim[sourceGUID]=nil
		else--Returned/changed a die while still on a mirrored Source.
			local source=getObjectFromGUID(sourceGUID)
			if source~=nil and currentDice~=nil then source.setRotation(currentDice.getRotation()) end
		end
		local moreDice=false
		for _, waitfunction in pairs(exitWaitID) do if waitfunction~=nil then moreDice=true break end end
		if moreDice==false then exitWaitID={} scheduleMirrorSourceUpdate("last dice resting in mirror", 0.05) end
	end
	exitWaitID[diceGUID]=safeWaitCondition("ManaSource",updateDice, function()
		local currentDice=getObjectFromGUID(diceGUID)
		return currentDice==nil or currentDice.resting
	end, 10, updateDice)
end

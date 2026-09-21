-- Physical setup for monster pools and expansion bag merging.

local monsterSetupPendingMoves=0
local monsterSetupExpectedQuantity={}
local monsterSetupLeadersReady=false

-- Expansion enemies live in the normal monster pools in the saved table. Setup only removes
-- excluded tokens or moves Tezla faction tokens into the empty faction bags already on the table.
local lostLegionMonsterTokens={
	[monsterPiles.green]={"643901","30df98","f0d27a","994ee9","e17886","8ffd9e","28bc08","0cc1e5"},
	[monsterPiles.tan]={"013cb1","16d47c","ce794a","863ba1","558de1","277cd2"},
	[monsterPiles.red]={"be5c5e","9156c4","80d998","17bcd9","09ec72","b7dca2"},
	[monsterPiles.gray]={"3f4b5e","88ecaa","bc5065","808631","8ea708","f11b70","7e72a2","90755e"},
	[monsterPiles.purple]={"490a69","b8f920","23fe94","8a3f72"},
	[monsterPiles.white]={"c0c315","eae753","e9a281","e6859f","864fe1","729056"},
	[monsterPiles.yellow]={"58c5ab","2f9a1f","28cc9c"}
}
local tezlaMonsterTokens={
	dark={
		{source=monsterPiles.green,destination=monsterPiles.greenDark,guids={"0c5f4d","698829","f87e33","565ecd","f85b1e","d549a5","39d58e","8efc22"}},
		{source=monsterPiles.tan,destination=monsterPiles.tanDark,guids={"863ba2","558de0","013cb2","61eb06"}},
		{source=monsterPiles.red,destination=monsterPiles.redDark,guids={"c77902","f87e32","342ed4","0d0645"}}
	},
	elementalist={
		{source=monsterPiles.green,destination=monsterPiles.greenElem,guids={"8efc20","64b218","698828","adec2a","e9911f","60e427","a04726","f87e31"}},
		{source=monsterPiles.tan,destination=monsterPiles.tanElem,guids={"00c4da","863bab","013cb3","61eb07"}},
		{source=monsterPiles.red,destination=monsterPiles.redElem,guids={"c77901","6cad42","5d4e06","f87e39"}}
	}
}

local function queueMonsterTokenMove(sourceGUID,tokenGUID,destinationGUID)
	local source=getObjectFromGUID(sourceGUID)
	if source==nil then error("SetupGame missing monster source bag "..tostring(sourceGUID),2) end
	local destination=nil
	if destinationGUID~=nil then
		destination=getObjectFromGUID(destinationGUID)
		if destination==nil then error("SetupGame missing monster destination bag "..tostring(destinationGUID),2) end
		if monsterSetupExpectedQuantity[destinationGUID]==nil then monsterSetupExpectedQuantity[destinationGUID]=destination.getQuantity() end
		monsterSetupExpectedQuantity[destinationGUID]=monsterSetupExpectedQuantity[destinationGUID]+1
	end
	monsterSetupPendingMoves=monsterSetupPendingMoves+1
	local extracted=safeTakeObject("SetupGame",source,{
		guid=tokenGUID,
		smooth=false,
		callback_function=function(token)
			if destination~=nil then
				destination.putObject(token)
			else
				local trash=getObjectFromGUID(trashCan)
				if trash~=nil then trash.putObject(token) else token.destruct() end
			end
			monsterSetupPendingMoves=monsterSetupPendingMoves-1
		end})
	if extracted==nil then
		monsterSetupPendingMoves=monsterSetupPendingMoves-1
		error("SetupGame could not extract monster token "..tostring(tokenGUID).." from "..tostring(sourceGUID),2)
	end
end

local function monsterTokenMovesReady()
	if monsterSetupPendingMoves~=0 then return false end
	for guid,expected in pairs(monsterSetupExpectedQuantity) do
		local pile=getObjectFromGUID(guid)
		if pile==nil or pile.getQuantity()<expected then return false end
	end
	return true
end

local function moveTezlaFactionTokens(entries)
	for _,entry in ipairs(entries) do
		for _,guid in ipairs(entry.guids) do queueMonsterTokenMove(entry.source,guid,entry.destination) end
	end
end

local function removeTezlaTokens(entries)
	for _,entry in ipairs(entries) do
		for _,guid in ipairs(entry.guids) do queueMonsterTokenMove(entry.source,guid,nil) end
	end
end

local function removeLostLegionTokens()
	for source,guids in pairs(lostLegionMonsterTokens) do
		for _,guid in ipairs(guids) do queueMonsterTokenMove(source,guid,nil) end
	end
end

local function destroyTezlaFactionBags(keepDark,keepElementalist)
	local groups={
		{keep=keepDark,guids={monsterPiles.greenDark,monsterPiles.tanDark,monsterPiles.redDark}},
		{keep=keepElementalist,guids={monsterPiles.greenElem,monsterPiles.tanElem,monsterPiles.redElem}}
	}
	for _,group in ipairs(groups) do
		if group.keep~=true then
			for _,guid in ipairs(group.guids) do
				local bag=getObjectFromGUID(guid)
				if bag~=nil then bag.destruct() end
			end
		end
	end
end

local function shuffleMonsterPiles()
	local toBeShuffled={monsterPiles.redElem,monsterPiles.tanElem,monsterPiles.greenElem,monsterPiles.rewardElem,
		monsterPiles.redDark,monsterPiles.tanDark,monsterPiles.greenDark,monsterPiles.rewardDark,
		monsterPiles.rewardApoc,monsterPiles.rewardCouncil,monsterPiles.possessed,
		monsterPiles.tan,monsterPiles.green,monsterPiles.red,monsterPiles.purple,monsterPiles.white,monsterPiles.gray,monsterPiles.yellow}
	for _,guid in ipairs(toBeShuffled) do
		local pile=getObjectFromGUID(guid)
		if pile~=nil then pile.shuffle() end
	end
	gStates.monsterSetupReady=true
end

--Monster Pug Setup
function monsterSetup()
	monsterSetupPendingMoves=0
	monsterSetupExpectedQuantity={}
	monsterSetupLeadersReady=false
	gStates.monsterSetupReady=false

	if gStates.removeLostLegionExpansion==true then removeLostLegionTokens() end

	local scenario=gStates.gameScenario
	local keepDark=gStates.removeShadesOfTezlaMonsters~=true and
		(scenario=="Life and Death" or scenario=="The War of Four" or scenario=="Ultimate Conquest" or scenario=="The Realm of the Dead Blitz")
	local keepElem=gStates.removeShadesOfTezlaMonsters~=true and
		(scenario=="Life and Death" or scenario=="The War of Four" or scenario=="Ultimate Conquest" or scenario=="The Hidden Valley Blitz")

	if gStates.removeShadesOfTezlaMonsters==true then
		removeTezlaTokens(tezlaMonsterTokens.dark)
		removeTezlaTokens(tezlaMonsterTokens.elementalist)
	else
		if keepDark then moveTezlaFactionTokens(tezlaMonsterTokens.dark) end
		if keepElem then moveTezlaFactionTokens(tezlaMonsterTokens.elementalist) end

		local darkCrusaderLocations={
			[darkCrusader.disc]={-52.00,0.97,6.50}, [darkCrusader.token]={-55.30,0.97,10.20}, [darkCrusader.terrainHex]={-34.70,0.98,-27.00},
			["f8c83e"]={-65.16,0.98,-5.50}, [GUID.bag.cemetery]={-36.09,0.97,-24.87}, [monsterPiles.rewardDark]={-46.13,0.98,13.99}, ["2ca34f"]={-53.50,0.98,15.50}}
		local elementalistLocations={
			[elementalist.disc]={-63.50,0.97,6.50}, [elementalist.token]={-67.00,0.97,10.20}, [elementalist.terrainHex]={-37.49,0.98,-27.00},
			["7121c7"]={-70.16,0.98,-5.50}, [monsterPiles.rewardElem]={-46.13,0.98,16.99}, ["8fe07e"]={-49.50,0.98,15.50}}
		local alwaysDeploy={[monsterPiles.rewardDark]=true,["2ca34f"]=true,[monsterPiles.rewardElem]=true,["8fe07e"]=true}
		local function deployTezlaComponents(locations,factionActive)
			for objGuid,location in pairs(locations) do
				if alwaysDeploy[objGuid]==true or scenario=="Life and Death" or scenario=="The War of Four" or scenario=="Ultimate Conquest" or factionActive==true then
					local flip=objGuid==GUID.bag.cemetery and 180 or 0
					local obj=getObjectFromGUID(GUID.bag.tezla).takeObject({guid=objGuid,position=location,rotation={0,180,flip},smooth=false})
					if obj~=nil then obj.lock() end
				end
			end
		end
		deployTezlaComponents(darkCrusaderLocations,scenario=="The Realm of the Dead Blitz")
		deployTezlaComponents(elementalistLocations,scenario=="The Hidden Valley Blitz")
		if scenario=="Life and Death" then getObjectFromGUID(GUID.bag.tezla).takeObject({guid="27911e",smooth=false,position={-50.63,1.47,1.16}}) end
	end

	destroyTezlaFactionBags(keepDark,keepElem)

	if gStates.removeShadesOfTezlaMonsters==true and gStates.useCustomMageKnights==true then
		getObjectFromGUID(GUID.bag.tezla).takeObject({guid=monsterPiles.rewardElem,position={-46.13,0.98,16.99},rotation={0,180,0},smooth=false}).lock()
		getObjectFromGUID(GUID.bag.tezla).takeObject({guid="8fe07e",position={-49.50,0.98,15.50},rotation={0,180,0},smooth=false}).lock()
		getObjectFromGUID(GUID.bag.tezla).takeObject({guid=monsterPiles.rewardDark,position={-46.13,0.98,13.99},rotation={0,180,0},smooth=false}).lock()
		getObjectFromGUID(GUID.bag.tezla).takeObject({guid="2ca34f",position={-53.50,0.98,15.50},rotation={0,180,0},smooth=false}).lock()
	end
	--Set faction leader levels when the physical leader pieces have actually registered.
	local leaderLevel=gStates.cityLevels[1]
	local expectDark=gStates.removeShadesOfTezlaMonsters~=true and
		(scenario=="Life and Death" or scenario=="The War of Four" or scenario=="Ultimate Conquest" or scenario=="The Realm of the Dead Blitz")
	local expectElem=gStates.removeShadesOfTezlaMonsters~=true and
		(scenario=="Life and Death" or scenario=="The War of Four" or scenario=="Ultimate Conquest" or scenario=="The Hidden Valley Blitz")

	local function leaderObjectsReady()
		if expectDark and (getObjectFromGUID(darkCrusader.disc)==nil or getObjectFromGUID(darkCrusader.token)==nil) then return false end
		if expectElem and (getObjectFromGUID(elementalist.disc)==nil or getObjectFromGUID(elementalist.token)==nil) then return false end
		return true
	end

	--reload() destroys and recreates the physical object. Existence alone is not a completion signal:
	--wait for the replacement leader pieces to be registered and settled before advertising setup readiness.
	local function leaderObjectSettled(guid)
		local obj=getObjectFromGUID(guid)
		return obj~=nil and obj.spawning~=true and obj.resting==true
	end
	local function leaderObjectsSettled()
		if expectDark and (leaderObjectSettled(darkCrusader.disc)~=true or leaderObjectSettled(darkCrusader.token)~=true) then return false end
		if expectElem and (leaderObjectSettled(elementalist.disc)~=true or leaderObjectSettled(elementalist.token)~=true) then return false end
		return true
	end

	local function finishLeaderSetup()
		local darkToken=getObjectFromGUID(darkCrusader.token)
		if darkToken~=nil then
			darkToken.addDecal({name="NightRules",position={0.85,0.15,-0.85},rotation={90,180,0},scale={0.6,0.6,1},url=nightRulesDecal})
			if gStates.monsterPerks[darkCrusader.token]==nil then gStates.monsterPerks[darkCrusader.token]={nightRules=true} else gStates.monsterPerks[darkCrusader.token].nightRules=true end
		end
		monsterSetupLeadersReady=true
	end

	local function applyLeaderSetup()
		if scenario~="Ultimate Conquest" then
			local elemDisc=getObjectFromGUID(elementalist.disc)
			local elemToken=getObjectFromGUID(elementalist.token)
			if elemDisc~=nil and elemToken~=nil then
				elemDisc.setCustomObject({image=leaderData[elementalist.terrainHex][leaderLevel].discImg})
				elemDisc.reload()
				elemToken.setCustomObject({image=leaderData[elementalist.terrainHex][leaderLevel].tokenImg})
				elemToken.setName("Elementalist Leader Level "..leaderLevel)
				elemToken.reload()
				monsterPugs[elementalist.token]=leaderData[elementalist.terrainHex][leaderLevel].abilities
				gStates.elementalistLevel=leaderLevel
				gStates.cityMonsterQty[elementalist.terrainHex]={[elementalist.token]="alive",extra={}}
				gStates.monsterPlayLocation[elementalist.token]={-55.3,3.0,15.3}
			end
			local darkDisc=getObjectFromGUID(darkCrusader.disc)
			local darkToken=getObjectFromGUID(darkCrusader.token)
			if darkDisc~=nil and darkToken~=nil then
				darkDisc.setCustomObject({image=leaderData[darkCrusader.terrainHex][leaderLevel].discImg})
				darkDisc.reload()
				darkToken.setCustomObject({image=leaderData[darkCrusader.terrainHex][leaderLevel].tokenImg})
				darkToken.setName("Dark Crusader Leader Level "..leaderLevel)
				darkToken.reload()
				monsterPugs[darkCrusader.token]=leaderData[darkCrusader.terrainHex][leaderLevel].abilities
				gStates.darkCrusaderLevel=leaderLevel
				gStates.cityMonsterQty[darkCrusader.terrainHex]={[darkCrusader.token]="alive",extra={}}
				gStates.monsterPlayLocation[darkCrusader.token]={-55.3,3.0,6.7}
			end
		end
		if expectDark or expectElem then
			safeWaitCondition("SetupGame",finishLeaderSetup,leaderObjectsSettled,10,function()
				error("SetupGame timed out waiting for faction leaders to reload and settle.",2)
			end)
		else
			finishLeaderSetup()
		end
	end

	if leaderObjectsReady()==true then
		applyLeaderSetup()
	else
		safeWaitCondition("SetupGame",applyLeaderSetup,leaderObjectsReady,10,function()
			error("SetupGame timed out waiting for faction leader setup objects.",2)
		end)
	end

	--Monster piles are ready only when every requested token move is physically reflected in its destination and
	--the optional faction-leader setup has completed.
	safeWaitCondition("SetupGame",shuffleMonsterPiles,function()
		return monsterSetupLeadersReady==true and monsterTokenMovesReady()==true
	end,15,function() error("SetupGame timed out waiting for monster setup to complete.",2) end)
end

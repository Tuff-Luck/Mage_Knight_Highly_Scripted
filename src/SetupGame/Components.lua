-- Physical setup for monster pools and Tezla scenario components.
-- The save starts with the ordinary monster pools already containing all Lost Legion and Tezla
-- enemy tokens. Membership is defined once in setupContentRoster; setup only removes excluded
-- tokens or moves Tezla tokens into the dedicated faction pools required by a scenario.

local monsterSetupMoves={}
local monsterSetupLeadersReady=false

local lostLegionEnemyPools=setupContentRoster.lostLegion.enemies
local darkCrusaderEnemyPools=setupContentRoster.shadesOfTezla.enemies.dark
local elementalistEnemyPools=setupContentRoster.shadesOfTezla.enemies.elementalist

local function monsterBagContainsGUID(bag,guid)
	if bag==nil then return false end
	for _,entry in ipairs(bag.getObjects()) do
		if entry.guid==guid then return true end
	end
	return false
end

local function moveMonsterToken(sourceGUID,tokenGUID,destinationGUID)
	local source=getObjectFromGUID(sourceGUID)
	if source==nil then error("SetupGame missing monster source bag "..tostring(sourceGUID),2) end
	local token=safeTakeObject("SetupGame",source,{guid=tokenGUID,smooth=false})
	if token==nil then error("SetupGame could not extract monster token "..tostring(tokenGUID).." from "..tostring(sourceGUID),2) end
	if destinationGUID~=nil then
		local destination=getObjectFromGUID(destinationGUID)
		if destination==nil then error("SetupGame missing monster destination bag "..tostring(destinationGUID),2) end
		destination.putObject(token)
	else
		local trash=getObjectFromGUID(trashCan)
		if trash==nil then error("SetupGame missing trash chest while removing monster token "..tostring(tokenGUID),2) end
		trash.putObject(token)
	end
	monsterSetupMoves[#monsterSetupMoves+1]={source=sourceGUID,destination=destinationGUID,guid=tokenGUID}
end

local function moveMonsterPoolSet(poolSet,toFaction)
	for _,pool in ipairs(poolSet) do
		for _,tokenGUID in ipairs(pool.tokens) do
			moveMonsterToken(pool.source,tokenGUID,toFaction==true and pool.destination or nil)
		end
	end
end

local function destroyMonsterBags(guids)
	for _,guid in ipairs(guids) do
		local bag=getObjectFromGUID(guid)
		if bag~=nil then bag.destruct() end
	end
end

local function configurePreloadedTokenBags(guids,keep,label)
	for _,guid in ipairs(guids) do
		local bag=getObjectFromGUID(guid)
		if keep==true then
			if bag==nil then error("SetupGame missing preloaded "..tostring(label).." bag "..tostring(guid),2) end
			bag.lock()
		elseif bag~=nil then
			bag.destruct()
		end
	end
end

local function monsterPoolConfigurationReady()
	for _,move in ipairs(monsterSetupMoves) do
		local source=getObjectFromGUID(move.source)
		if source==nil or monsterBagContainsGUID(source,move.guid)==true then return false end
		if move.destination~=nil then
			local destination=getObjectFromGUID(move.destination)
			if destination==nil or monsterBagContainsGUID(destination,move.guid)~=true then return false end
		end
	end
	return true
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

local function deployTezlaComponents(entries,includeScenarioComponents)
	local tezlaBag=getObjectFromGUID(GUID.bag.tezla)
	if tezlaBag==nil then error("SetupGame missing Shades of Tezla component bag.",2) end
	for _,entry in ipairs(entries) do
		if entry.always==true or includeScenarioComponents==true then
			local obj=safeTakeObject("SetupGame",tezlaBag,{
				guid=entry.guid,
				position=entry.position,
				rotation={0,180,entry.flip or 0},
				smooth=false})
			if obj==nil then error("SetupGame could not deploy Shades of Tezla component "..tostring(entry.guid),2) end
			obj.lock()
		end
	end
end

--Monster Pool Setup
function monsterSetup()
	monsterSetupMoves={}
	monsterSetupLeadersReady=false
	gStates.monsterSetupReady=false

	--Lost Legion enemies are already in the seven normal pools. Removing the expansion is subtractive.
	if gStates.removeLostLegionExpansion==true then moveMonsterPoolSet(lostLegionEnemyPools,false) end

	local scenario=gStates.gameScenario
	local darkSupport=scenario=="Life and Death" or scenario=="The War of Four" or scenario=="Ultimate Conquest" or scenario=="The Realm of the Dead Blitz"
	local elemSupport=scenario=="Life and Death" or scenario=="The War of Four" or scenario=="Ultimate Conquest" or scenario=="The Hidden Valley Blitz"
	local darkFactionEnemies=scenario=="Life and Death" or scenario=="The War of Four" or scenario=="The Realm of the Dead Blitz"
	local elemFactionEnemies=scenario=="Life and Death" or scenario=="The War of Four" or scenario=="The Hidden Valley Blitz"
	local darkBags={monsterPiles.greenDark,monsterPiles.tanDark,monsterPiles.redDark}
	local elemBags={monsterPiles.greenElem,monsterPiles.tanElem,monsterPiles.redElem}
	local tezlaRewardsNeeded=gStates.removeShadesOfTezlaMonsters~=true or gStates.useCustomMageKnights==true
	configurePreloadedTokenBags({
		monsterPiles.rewardDark,GUID.bag.discard.darkReward,
		monsterPiles.rewardElem,GUID.bag.discard.elementalistReward
	},tezlaRewardsNeeded,"Shades of Tezla reward")
	local darkComponents={
		{guid=darkCrusader.disc,position={-52.00,0.97,6.50}},
		{guid=darkCrusader.token,position={-55.30,0.97,10.20}},
		{guid=darkCrusader.terrainHex,position={-34.70,0.98,-27.00}},
		{guid="f8c83e",position={-65.16,0.98,-5.50}},
		{guid=GUID.bag.cemetery,position={-36.09,0.97,-24.87},flip=180},
		{guid="2ca34f",position={-53.50,0.98,15.50},always=true}
	}
	local elemComponents={
		{guid=elementalist.disc,position={-63.50,0.97,6.50}},
		{guid=elementalist.token,position={-67.00,0.97,10.20}},
		{guid=elementalist.terrainHex,position={-37.49,0.98,-27.00}},
		{guid="7121c7",position={-70.16,0.98,-5.50}},
		{guid="8fe07e",position={-49.50,0.98,15.50},always=true}
	}

	if gStates.removeShadesOfTezlaMonsters~=true then
		deployTezlaComponents(darkComponents,darkSupport)
		deployTezlaComponents(elemComponents,elemSupport)

		--The six faction bags load empty in their table positions. Fill only the faction pools used by
		--this scenario; otherwise delete those bags and leave their enemies in the normal pools.
		if darkFactionEnemies==true then moveMonsterPoolSet(darkCrusaderEnemyPools,true) else destroyMonsterBags(darkBags) end
		if elemFactionEnemies==true then moveMonsterPoolSet(elementalistEnemyPools,true) else destroyMonsterBags(elemBags) end
	else
		moveMonsterPoolSet(darkCrusaderEnemyPools,false)
		moveMonsterPoolSet(elementalistEnemyPools,false)
		destroyMonsterBags(darkBags)
		destroyMonsterBags(elemBags)
		--Custom Mage Knights can still use Tezla rewards even when the Tezla enemies are removed.
		if gStates.useCustomMageKnights==true then
			deployTezlaComponents(darkComponents,false)
			deployTezlaComponents(elemComponents,false)
		end
	end

	if scenario=="Life and Death" then
		local factionDie=safeTakeObject("SetupGame",getObjectFromGUID(GUID.bag.tezla),{guid="27911e",smooth=false,position={-50.63,1.47,1.16}})
		if factionDie==nil then error("SetupGame could not deploy the Life and Death faction die.",2) end
	end
	--Set faction leader levels when the physical leader pieces have actually registered.
	local leaderLevel=gStates.cityLevels[1]
	local scenario=gStates.gameScenario
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

	--Monster piles are ready only when every merge is physically reflected in its destination and
	--the optional faction-leader setup has completed.
	safeWaitCondition("SetupGame",shuffleMonsterPiles,function()
		return monsterSetupLeadersReady==true and monsterPoolConfigurationReady()==true
	end,15,function() error("SetupGame timed out waiting for monster setup to complete.",2) end)
end

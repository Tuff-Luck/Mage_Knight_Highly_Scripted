-- Physical setup for monster pools and expansion bag merging.

local monsterSetupPendingMerges=0
local monsterSetupFinalizeQueued=false

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

local function finishMonsterSetupWhenReady()
	if monsterSetupPendingMerges~=0 or monsterSetupFinalizeQueued==true then return end
	monsterSetupFinalizeQueued=true
	--One frame lets destination containers absorb the final putObject calls; no fixed one-second sleep.
	safeWaitFrames("SetupGame",function()
		monsterSetupFinalizeQueued=false
		if monsterSetupPendingMerges==0 then shuffleMonsterPiles() else finishMonsterSetupWhenReady() end
	end,1)
end

local function mergeMonsterBag(source,destination,container)
	local destinationBag=getObjectFromGUID(destination)
	if destinationBag==nil then error("SetupGame missing monster destination bag "..tostring(destination),2) end
	monsterSetupPendingMerges=monsterSetupPendingMerges+1
	local p=destinationBag.getPosition()
	local temp=safeTakeObject("SetupGame",getObjectFromGUID(container),{
		position={p[1],-2,p[3]},
		smooth=false,
		guid=source,
		callback_function=function(sourceBag)
			local count=#sourceBag.getObjects()
			for _=1,count do destinationBag.putObject(sourceBag.takeObject({smooth=false})) end
			sourceBag.destruct()
			monsterSetupPendingMerges=monsterSetupPendingMerges-1
			finishMonsterSetupWhenReady()
		end})
	if temp==nil then
		monsterSetupPendingMerges=monsterSetupPendingMerges-1
		error("SetupGame could not extract monster bag "..tostring(source),2)
	end
end

--Monster Pug Setup
function monsterSetup()
	monsterSetupPendingMerges=0
	monsterSetupFinalizeQueued=false
	gStates.monsterSetupReady=false
	if gStates.removeLostLegionExpansion==false then
		local LostLegion={["89a23e"]=monsterPiles.green, ["77e1c6"]=monsterPiles.tan, ["143108"]=monsterPiles.red, ["88ff48"]=monsterPiles.gray, ["bf4140"]=monsterPiles.purple, ["fe25be"]=monsterPiles.white, ["b65694"]=monsterPiles.yellow}
		for mergeBag, destinationBag in pairs(LostLegion) do
			mergeMonsterBag(mergeBag, destinationBag, GUID.bag.lostLegion)
		end
	end
	if gStates.removeShadesOfTezlaMonsters~=true then
		local darkCrusaderLocations={[monsterPiles.greenDark]={-48.63, 0.98, -6.00}, [monsterPiles.tanDark]={-48.63, 0.98, -3.50}, [monsterPiles.redDark]={-48.63, 0.98, -1.00},
							[darkCrusader.disc]={-52.00, 0.97, 6.50}, [darkCrusader.token]={-55.30, 0.97, 10.20}, [darkCrusader.terrainHex]={-34.70, 0.98, -27.00},
							["f8c83e"]={-65.16, 0.98, -5.50}, [GUID.bag.cemetery]={-36.09, 0.97, -24.87}, [monsterPiles.rewardDark]={-46.13, 0.98, 13.99}, ["2ca34f"]={-53.50, 0.98, 15.50}}
							--Necropolis Info Card, Graveyards, Rewards, Reward info card
		local elementalistLocations={[monsterPiles.greenElem]={-51.13, 0.98, -6.00}, [monsterPiles.tanElem]={-51.13, 0.98, -3.50}, [monsterPiles.redElem]={-51.13, 0.98, -1.00},
							[elementalist.disc]={-63.50, 0.97, 6.50}, [elementalist.token]={-67.00, 0.97, 10.20}, [elementalist.terrainHex]={-37.49, 0.98, -27.00},
							["7121c7"]={-70.16, 0.98, -5.50}, [monsterPiles.rewardElem]={-46.13, 0.98, 16.99}, ["8fe07e"]={-49.50, 0.98, 15.50}}
							--Hidden Valley Info Card, Rewards, Reward info card
		local mergeDestination={[monsterPiles.greenDark]=monsterPiles.green, [monsterPiles.tanDark]=monsterPiles.tan, [monsterPiles.redDark]=monsterPiles.red, [monsterPiles.greenElem]=monsterPiles.green, [monsterPiles.tanElem]=monsterPiles.tan, [monsterPiles.redElem]=monsterPiles.red}
		local allowed={[monsterPiles.rewardDark]=true, ["2ca34f"]=true, [monsterPiles.rewardElem]=true, ["8fe07e"]=true}
		local workingOn=darkCrusaderLocations
		for a=1, 2, 1 do
			for objGuid, location in pairs(workingOn) do
				if mergeDestination[objGuid]~=nil and gStates.gameScenario~="Life and Death" and gStates.gameScenario~="The War of Four" and
					((a==1 and gStates.gameScenario~="The Realm of the Dead Blitz") or (a==2 and gStates.gameScenario~="The Hidden Valley Blitz")) then
					mergeMonsterBag(objGuid, mergeDestination[objGuid], GUID.bag.tezla)
				else
					if allowed[objGuid]~=nil or gStates.gameScenario=="Life and Death" or gStates.gameScenario=="The War of Four" or gStates.gameScenario=="Ultimate Conquest" or
						(a==1 and gStates.gameScenario=="The Realm of the Dead Blitz") or (a==2 and gStates.gameScenario=="The Hidden Valley Blitz") then
						local flip=0
						if mergeDestination[objGuid]~=nil or objGuid==GUID.bag.cemetery then flip=180 end
						local obj=getObjectFromGUID(GUID.bag.tezla).takeObject({guid=objGuid, position=location, rotation={0, 180, flip}, smooth=false}).lock()
					end
				end
			end
			workingOn=elementalistLocations
		end
		if gStates.gameScenario=="Life and Death" then getObjectFromGUID(GUID.bag.tezla).takeObject({guid="27911e", smooth=false, position={-50.63, 1.47, 1.16}}) end --Faction Die
	end
	if gStates.removeShadesOfTezlaMonsters==true and gStates.useCustomMageKnights==true then
		getObjectFromGUID(GUID.bag.tezla).takeObject({guid=monsterPiles.rewardElem, position={-46.13, 0.98, 16.99}, rotation={0, 180, 0}, smooth=false}).lock()
		getObjectFromGUID(GUID.bag.tezla).takeObject({guid="8fe07e", position={-49.50, 0.98, 15.50}, rotation={0, 180, 0}, smooth=false}).lock()
		getObjectFromGUID(GUID.bag.tezla).takeObject({guid=monsterPiles.rewardDark, position={-46.13, 0.98, 13.99}, rotation={0, 180, 0}, smooth=false}).lock()
		getObjectFromGUID(GUID.bag.tezla).takeObject({guid="2ca34f", position={-53.50, 0.98, 15.50}, rotation={0, 180, 0}, smooth=false}).lock()
	end
	--set faction leader levels
	local leaderLevel=gStates.cityLevels[1]
	safeWaitFrames("SetupGame",function()
		if gStates.gameScenario~="Ultimate Conquest" then
			if getObjectFromGUID(elementalist.disc)~=nil then
				getObjectFromGUID(elementalist.disc).setCustomObject({image=leaderData[elementalist.terrainHex][leaderLevel].discImg})
				getObjectFromGUID(elementalist.disc).reload()
				getObjectFromGUID(elementalist.token).setCustomObject({image=leaderData[elementalist.terrainHex][leaderLevel].tokenImg})
				getObjectFromGUID(elementalist.token).setName("Elementalist Leader Level "..leaderLevel)
				getObjectFromGUID(elementalist.token).reload()
				monsterPugs[elementalist.token]=leaderData[elementalist.terrainHex][leaderLevel].abilities
				gStates.elementalistLevel=leaderLevel
				gStates.cityMonsterQty[elementalist.terrainHex]={[elementalist.token]="alive", extra={}}
				gStates.monsterPlayLocation[elementalist.token]={-55.3, 3.0, 15.3}
			end
			if getObjectFromGUID(darkCrusader.disc)~=nil then
				getObjectFromGUID(darkCrusader.disc).setCustomObject({image=leaderData[darkCrusader.terrainHex][leaderLevel].discImg})
				getObjectFromGUID(darkCrusader.disc).reload()
				getObjectFromGUID(darkCrusader.token).setCustomObject({image=leaderData[darkCrusader.terrainHex][leaderLevel].tokenImg})
				getObjectFromGUID(darkCrusader.token).setName("Dark Crusader Leader Level "..leaderLevel)
				getObjectFromGUID(darkCrusader.token).reload()
				monsterPugs[darkCrusader.token]=leaderData[darkCrusader.terrainHex][leaderLevel].abilities
				gStates.darkCrusaderLevel=leaderLevel
				gStates.cityMonsterQty[darkCrusader.terrainHex]={[darkCrusader.token]="alive", extra={}}
				gStates.monsterPlayLocation[darkCrusader.token]={-55.3, 3.0, 6.7}
			end
		end
		if getObjectFromGUID(darkCrusader.token)~=nil then
			getObjectFromGUID(darkCrusader.token).addDecal({name="NightRules", position={0.85, 0.15, -0.85}, rotation={90, 180, 0}, scale={0.6, 0.6, 1}, url=nightRulesDecal})
			if gStates.monsterPerks[darkCrusader.token]==nil then gStates.monsterPerks[darkCrusader.token]={nightRules=true} else gStates.monsterPerks[darkCrusader.token].nightRules=true end
		end
	end, 5)

	finishMonsterSetupWhenReady()
end

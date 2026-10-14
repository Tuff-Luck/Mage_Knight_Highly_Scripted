-- Fan-made scenarios: specific victory conditions and custom rule helpers.


-- Extra conquest variants and Ultimate Conquest retain their independent win rules.
function fanScenarioConquestEndAchieved(count)
	if gStates==nil then return false end
	local scenario=gStates.gameScenario
	if scenario=="First Conquest" or scenario=="Fast Forwarded Conquest" then return count==gStates.cityTiles end
	if scenario=="Ultimate Conquest" then
		return count==gStates.cityTiles and (gStates.removeShadesOfTezlaMonsters==true or gStates.defeatedFaction==2)
	end
	return false
end

-- Called by BaseScenario after Combat has returned enemies and settled shields.
function fanScenarioCombatEndAchieved(cleanupLocation,cardInHand,volkareBeaten)
	if gStates==nil then return false end
	local scenario=gStates.gameScenario
	if scenario=="First Conquest" or scenario=="Fast Forwarded Conquest" or scenario=="Ultimate Conquest" then
		return fanScenarioConquestEndAchieved(conqueredCityObjectiveCount())
	end
	if scenario=="The War of Four" then return volkareBeaten==true end
	if scenario=="Quest for the Golden Grail" then return cleanupLocation=="portal" and cardInHand==true end
	if scenario=="The Gauntlet" then return gStates.theGauntletArtifactClaimed==true end
	return false
end

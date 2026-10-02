-- Public error-wrapped gameplay and TTS callback boundaries.

local validatePublicUICallbacks

--Object-UI Skill claims are not TTS event callbacks, so give them the same automatic error-report boundary.
function skillMove(player, mouseButton, id, rewindReady)
	return safeCallback("skillMove", function() return __skillMove_raw(player, mouseButton, id, rewindReady) end, function() return automaticLuaSkillClaimContext(player,id) end)
end

function preEndTurn(player, mouseButton, id, rewindReady)
	return safeCallback("preEndTurn", function() return __preEndTurn_raw(player, mouseButton, id, rewindReady) end, function() return automaticLuaTurnPhaseContext(player, id) end)
end

function endTurn(player, mouseButton, id, rewindReady)
	return safeCallback("endTurn", function() return __endTurn_raw(player, mouseButton, id, rewindReady) end, function() return automaticLuaTurnPhaseContext(player, id) end)
end

function PreEndRound(player, mouseButton, id)
	return safeCallback("PreEndRound", function() return __PreEndRound_raw(player, mouseButton, id) end, function() return automaticLuaTurnPhaseContext(player, id) end)
end

function endRound(rewindReady)
	return safeCallback("endRound", function() return __endRound_raw(rewindReady) end, function() return automaticLuaTurnPhaseContext(nil, "EndRound") end)
end

-- Wrap TTS event callbacks so unexpected Lua errors are reported automatically.
function onLoad(saved_data)
	return safeCallback("onLoad",function()
		validatePublicUICallbacks()
		local loadedData=nil
		if type(saved_data)=="string" and saved_data~="" then loadedData=JSON.decode(saved_data) end
		--These objects already exist when Global loads. Install their XML immediately, then use the
		--proven load-time setAttribute pass once TTS has had two frames to build/localise the object UI.
		monsterReplenishObjectOnLoad()
		artifactOnLoad()
		siteDescriptionObjectOnLoad()
		rollerOnLoad(rollerSavedState(loadedData))
		local result=__onLoad_raw(saved_data,loadedData)
		safeWaitFrames("Callbacks",function()
			monsterReplenishTranslationRefresh()
			artifactOfferRewardTextRefresh()
			siteDescriptionTranslationRefresh()
			deedOfferArrowTextRefresh()
		end,2)
		return result
	end)
end

function onObjectPickUp(player_color, picked_up_object)
	return safeCallback("onObjectPickUp", function() __onObjectPickUp_raw(player_color, picked_up_object) end)
end

function onObjectHover(player_color, hover_object)
	return safeDirectCallback("onObjectHover", __onObjectHover_raw, player_color, hover_object)
end

function onObjectDrop(player_color, dropped_object)
	return safeCallback("onObjectDrop", function() __onObjectDrop_raw(player_color, dropped_object) end)
end

function onObjectSpawn(spawn_object)
	return safeCallback("onObjectSpawn", function() __onObjectSpawn_raw(spawn_object) end)
end

function onObjectDestroy(destroyedObj)
	return safeCallback("onObjectDestroy", function() __onObjectDestroy_raw(destroyedObj) end)
end

function onObjectEnterZone(zone, obj)
	return safeZoneCallback("onObjectEnterZone", __onObjectEnterZone_raw, zone, obj)
end

function onObjectLeaveZone(zone, obj)
	return safeZoneCallback("onObjectLeaveZone", __onObjectLeaveZone_raw, zone, obj)
end

function onObjectCollisionEnter(registered_object, info)
	return safeDirectCallback("onObjectCollisionEnter", __onObjectCollisionEnter_raw, registered_object, info)
end

function onObjectCollisionExit(registered_object, info)
	return safeDirectCallback("onObjectCollisionExit", __onObjectCollisionExit_raw, registered_object, info)
end

function onObjectEnterContainer(bag, obj)
	return safeCallback("onObjectEnterContainer", function() __onObjectEnterContainer_raw(bag, obj) end)
end

function onObjectLeaveContainer(bag, obj)
	return safeCallback("onObjectLeaveContainer", function() __onObjectLeaveContainer_raw(bag, obj) end)
end

function onObjectSearchStart(object, player_color)
	return safeCallback("onObjectSearchStart", function() __onObjectSearchStart_raw(object, player_color) end)
end

function onObjectSearchEnd(object, player_color)
	return safeCallback("onObjectSearchEnd", function() __onObjectSearchEnd_raw(object, player_color) end)
end

function onObjectRandomize(randomize_object, player_color)
	return safeCallback("onObjectRandomize", function() __onObjectRandomize_raw(randomize_object, player_color) end)
end

function onObjectRotate(object, spin, flip, player_color, old_spin, old_flip)
	return safeCallback("onObjectRotate", function() __onObjectRotate_raw(object, spin, flip, player_color, old_spin, old_flip) end)
end

function onPlayerConnect(player)
	return safeCallback("onPlayerConnect", function() __onPlayerConnect_raw(player) end,
		function() return automaticLuaPlayerContext(player,"Player connected") end)
end

function onPlayerChangeColor(color)
	return safeCallback("onPlayerChangeColor", function() __onPlayerChangeColor_raw(color) end,
		function() return automaticLuaPlayerContext(color,"Player changed color") end)
end

function onObjectNumberTyped(object, player_color, number, alt)
	return safeCallback("onObjectNumberTyped", function() return __onObjectNumberTyped_raw(object, player_color, number, alt) end)
end

function tryObjectEnterContainer(container, object)
	return safeDirectCallback("tryObjectEnterContainer", __tryObjectEnterContainer_raw, container, object)
end

function filterObjectEnterContainer(container, enter_object)
	return safeDirectCallback("filterObjectEnterContainer", __filterObjectEnterContainer_raw, container, enter_object)
end

--Global XML and Object UI callbacks bypass the normal TTS lifecycle wrappers above. Install their
--error boundaries here, after every gameplay module has loaded, so the owning implementations stay
--unchanged and UI names continue resolving exactly as before.
local expectedProtectedUICallbacks={
	--Global XML setup/general controls
	"BlitzSelection","displayScore","MoreRampageSelection","PlayerChosen","RampageSelection","SendDataRequest",
	"SetupMenu","VolkareLevelSelection","VolkareRaceSelection","adjustHigherLevelSetupValue",
	"apocalypseDragonLevelSelection","assaultAdjust","attackCity","autoflip","baseValueTweak","buttonClicked",
	"cameraControl","cameraControlFollowEnemy","cameraControlTopDown","closePanel","closeSplash","coopAssaultJoin",
	"coralDrawChoice","createHigherLevelCardPool","drawUpTo","dummyTurn","extraTurnButton","extraTurnChoice",
	"horsemanLevelSelection","lowerTable","masterOfChaos","mineClaimChoice","monsterImageSwap","motivation",
	"nightTactic2","nightTactic4","nightTactic6","openBugReportPanel","optionsUpdate","plunderVillage",
	"proxyManaChoiceSelect","pursuingRampagers","randomSetup","resourceTracker","riseOfTheForgemasterOption",
	"scenarioSelection","setBugReportComment","switchSetup","toggleDropDown","toggleScenarioEndAchieved","valueAdjust",
	"volkarePartial","volkareRetreat","wallAssaultChoice","zigguratPyramidInteract","MKRollDieButton",
	--Dynamic Object UI / scenario controls
	"adjustCityLevel","adjustOverkill","againstDragonAttackComplete","againstDragonAttendFull",
	"againstDragonFinishPartial","againstDragonOffMapChoiceSelect","againstDragonTargetChoiceSelect",
	"apocalypseDragonGroundReductionAdjust","apocalypseDragonProcessUI","apocalypseIsHereHorsemanTargetSelect",
	"apocalypseIsHereProcessHorsemenUI","apocalypseQuestCardAction","apocalypseQuestEnemyAttack","artifactAdjust",
	"attachEnemy","attackLocation","ButtonClickDown","ButtonClickDownOverkill","ButtonClickUp","ButtonClickUpOverkill",
	"changeMatImage","changePositionColor","dayTactic2Discarded","druidNightsRitualAction","exploreMap",
	"fracturedLandsOrientationDone","fracturedLandsRotateLeft","fracturedLandsRotateRight","gladeDiscardHealUI",
	"higherLevelSkill","horsemanAttackAction","layoutClaimedCards","nightTint","offerAdjust","offerArtifacts",
	"processCardClaim","proxyDestinationChoiceSelect","proxyEnemyChoiceSelect","proxyInteractionChoiceSelect",
	"proxyTurn","refillMonsterTokenPiles","removeTactic","restoreDestroyedSiteAtCurrentPlayer","shieldDrop",
	"steadyTempoChoice","summonMonster","togglePlayerDropoutRequest","volkarePursuitAction","volkareTurn",
	"coopCompSkillWarningClick","nightTactic6StoredCountNoop"
}

validatePublicUICallbacks=function()
	local missing={}
	local unprotected={}
	for _,name in ipairs(expectedProtectedUICallbacks) do
		if type(_G[name])~="function" then
			missing[#missing+1]=name
		elseif automaticLuaPublicUICallbackProtected(name)~=true then
			unprotected[#unprotected+1]=name
		end
	end
	if #missing==0 and #unprotected==0 then return true end
	local details={}
	if #missing>0 then details[#details+1]="Missing public UI callback(s): "..table.concat(missing,", ") end
	if #unprotected>0 then details[#details+1]="Unprotected public UI callback(s): "..table.concat(unprotected,", ") end
	safeCallback("Callbacks UI registration",function()
		error(table.concat(details,"\n"),2)
	end)
	return false
end

function onChat(message, player)
	if player~=nil and player.admin==true then
		if message=="!testerror" then testAutomaticLuaError() return false end
		if message=="!testasyncerror" then testAutomaticLuaAsyncError() return false end
	end
end

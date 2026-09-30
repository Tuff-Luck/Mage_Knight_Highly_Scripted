-- Public error-wrapped gameplay and TTS callback boundaries.

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
		monsterReplenishObjectOnLoad()
		artifactOnLoad()
		rollerOnLoad(rollerSavedState(saved_data))
		local result=__onLoad_raw(saved_data)
		safeWaitFrames("Callbacks",function()
			local monsterReplenish=getObjectFromGUID(GUID.ui.monsterReplenish)
			if monsterReplenish~=nil then
				monsterReplenish.UI.setAttribute("d7a165replenishMonsterPilesText", "text", "{en}Restock Empty Piles{ru}Восполнить пустые стопки{zh-tw}補齊抽空的標記{zh-cn}补齐抽空的标记{ko}빈 토큰더미채우기{es}Reabastecer Vacío Pilas{fr}Réapprovisionner Vider Les piles{pt-br}Reestocar Pilhas Vazias{de}Leere Stapel auffüllen")
			end
			artifactOnLoad()
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

function onPlayerAction(player, action, targets)
	return safeCallback("onPlayerAction", function() return __onPlayerAction_raw(player, action, targets) end)
end

--Global XML and Object UI callbacks bypass the normal TTS lifecycle wrappers above. Install their
--error boundaries here, after every gameplay module has loaded, so the owning implementations stay
--unchanged and UI names continue resolving exactly as before.
local function protectPublicUICallback(name)
	local callback=_G[name]
	if type(callback)=="function" then _G[name]=safePublicCallback(name,callback,automaticLuaUICallbackContext) end
end

local protectedUICallbacks={
	--Global XML setup/general controls
	"BlitzSelection","DisplayScore","MoreRampageSelection","PlayerChosen","RampageSelection","SendDataRequest",
	"SetupMenu","VolkareLevelSelection","VolkareRaceSelection","adjustHigherLevelSetupValue",
	"apocalypseDragonLevelSelection","assaultAdjust","attackCity","autoflip","baseValueTweak","buttonClicked",
	"cameraControl","cameraControlFollowEnemy","cameraControlTopDown","closePanel","closeSplash","coopAssaultJoin",
	"coralDrawChoice","createHigherLevelCardPool","drawUpTo","dummyTurn","extraTurnButton","extraTurnChoice",
	"horsemanLevelSelection","lowerTable","masterOfChaos","mineClaimChoice","monsterImageSwap","motivation",
	"nightTactic2","nightTactic4","nightTactic6","openBugReportPanel","optionsUpdate","plunderVillage",
	"proxyManaChoiceSelect","pursuingRampagers","randomSetup","resourceTracker","riseOfTheForgemasterOption",
	"scenarioSelection","setBugReportComment","switchSetup","toggleDropDown","toggleScenarioEndAchieved","valueAdjust",
	"volkarePartial","volkareRetreat","wallAssaultChoice","zigguratPyramidInteract",
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
	"steadyTempoChoice","summonMonster","togglePlayerDropoutRequest","volkarePursuitAction","volkareTurn"
}
for _,name in ipairs(protectedUICallbacks) do protectPublicUICallback(name) end

function onChat(message, player)
	if player~=nil and player.admin==true then
		if message=="!testerror" then testAutomaticLuaError() return false end
		if message=="!testasyncerror" then testAutomaticLuaAsyncError() return false end
	end
end

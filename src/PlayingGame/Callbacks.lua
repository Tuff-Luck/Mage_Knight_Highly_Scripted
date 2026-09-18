-- Public error-wrapped gameplay and TTS callback boundaries.

function automaticLuaTurnPhaseContext(player, id)
	local context="Turn: "..tostring(automaticLuaErrorStateValue("turnNumber", "")).." / Round: "..tostring(automaticLuaErrorStateValue("currentRound", ""))
	if player~=nil then context=context.."\nPlayer: "..tostring(player.color or player) end
	if id~=nil then context=context.."\nAction: "..tostring(id) end
	return context
end

function automaticLuaSkillClaimContext(player, id)
	local guid=id~=nil and tostring(id):sub(1,6) or ""
	local context=automaticLuaTurnPhaseContext(player,id).."\nSkill buttons: "..tostring(automaticLuaErrorStateValue("skillButtons","")).."\nSkill GUID: "..tostring(guid)
	local skill=getObjectFromGUID(guid)
	if skill~=nil then
		local p=skill.getPosition()
		context=context.."\nLive position: "..tostring(p[1])..", "..tostring(p[2])..", "..tostring(p[3])
	end
	local home=automaticLuaErrorValue(function() return gStates.mageSkills[guid] end,nil)
	if home~=nil then context=context.."\nRecorded position: "..tostring(home[1])..", "..tostring(home[2])..", "..tostring(home[3]) end
	return context
end

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
			monsterReplenishObjectOnLoad()
			artifactOnLoad()
		end,2)
		return result
	end)
end

function onObjectPickUp(player_color, picked_up_object)
	return safeCallback("onObjectPickUp", function() __onObjectPickUp_raw(player_color, picked_up_object) end)
end

function onObjectHover(player_color, hover_object)
	return __onObjectHover_raw(player_color, hover_object)
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
	return __onObjectCollisionEnter_raw(registered_object, info)
end

function onObjectCollisionExit(registered_object, info)
	return __onObjectCollisionExit_raw(registered_object, info)
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

function onPlayerChangeColor(color)
	return safeCallback("onPlayerChangeColor", function() __onPlayerChangeColor_raw(color) end)
end

function onObjectNumberTyped(object, player_color, number, alt)
	return safeCallback("onObjectNumberTyped", function() return __onObjectNumberTyped_raw(object, player_color, number, alt) end)
end


function onChat(message, player)
	if player~=nil and player.admin==true then
		if message=="!testerror" then testAutomaticLuaError() return false end
		if message=="!testasyncerror" then testAutomaticLuaAsyncError() return false end
	end
end

-- Shades of Tezla: Realm of the Dead and Hidden Valley runtime rules.

function realmDeadEnemiesAtPosition(position)
	if position==nil or position[1]==nil then return false end
	local map=getObjectFromGUID(mapArea)
	if map==nil then return false end
	for _, obj in pairs(map.getObjects()) do
		local data=monsterPugs[obj.guid]
		if data~=nil and data.pugType~="possessed" then
			local pos=obj.getPosition()
			if ((pos[1]-position[1])^2)+((pos[3]-position[3])^2)<1 then return true end
		end
	end
	return false
end

function hiddenValleyLiberated()
	if gStates.gameScenario~="The Hidden Valley Blitz" then return true end
	if (gStates.elementalistLevel or 1)<=0 then return true end
	local monsters=gStates.cityMonsterQty~=nil and gStates.cityMonsterQty[elementalist.terrainHex] or nil
	if monsters~=nil and monsters[elementalist.token]=="dead" then return true end
	if gStates.defeatedFactionTest~=nil and gStates.defeatedFactionTest[elementalist.terrainHex]=="Beat" then return true end
	return false
end

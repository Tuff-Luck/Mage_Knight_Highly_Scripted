terainTiles = {"20607e","05b612"}
playArea = "ded4d3" -- where all the terain tiles will be played

function onObjectEnterScriptingZone(zone, obj)
	-- Check if the scripting zone is the play area
	if zone.guid == playArea then
		-- Check if the object is a core tile and unlock elite units
		for i=1, #terainTiles, 1 do
			if obj.guid == terainTiles[i] then
				if obj.getRotation()[3] <= 5 or obj.getRotation()[3] >= 355 then
					self.setRotationSmooth({0.00, 180.00, 0.00})
				end
			end
		end
	end
end
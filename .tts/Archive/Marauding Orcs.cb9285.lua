terainTiles = {"208d84", "184fb7", "29a93c", "d21095", "e2ecf8", "ca8ad3", "a26c4f", "0bf020", "20607e", "78fc79","de7fad","314081","835c91"}
playArea = "ded4d3" -- where all the terain tiles will be played

function onObjectEnterScriptingZone(zone, obj)
	-- Check if the scripting zone is the play area
	if zone.guid == playArea then
		for i=1, #terainTiles, 1 do
			if obj.guid == terainTiles[i] then
				if obj.getRotation()[3] <= 5 or obj.getRotation()[3] >= 355 then
					self.setRotationSmooth({0.00, 180.00, 0.00})
				end
			end
		end
	end
end
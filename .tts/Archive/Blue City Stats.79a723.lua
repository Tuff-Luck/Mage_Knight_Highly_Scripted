terainTiles = {"095870","61df02","fe333d","7b9fc2","5065a6","e72220","f5b289","0ab34b","5b4d7d","340142","8fdfc8","6079bc"}--all the level states of the city
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
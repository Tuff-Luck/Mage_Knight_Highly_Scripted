terainTiles = {"a8b06c","202fbc","22e380","c9daa9","ca1951","aa477e","836c22","b2be68","fa2a87","c1ecbd","3ae0a1","34e3e4"}--all the level states of the city
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
-- Hero Challenge setup validation, terrain assignment and objective text.

-- Apocalypse Dragon Hero Challenges play variant.
-- The variant overlays the selected scenario; the scenario's own end condition remains authoritative.
function heroChallengeCountryGUID(number)
	return GUID.tile["country"..tostring(number)]
end

local function heroChallengeGUIDInList(guid,list)
	for _,candidate in ipairs(list or {}) do if guid==candidate then return true end end
	return false
end

function heroChallengeCountryAvailable(guid)
	if guid==nil then return false end
	if gStates.removeTerrain==true and (guid==GUID.tile.country01 or guid==GUID.tile.country02) then return false end
	if gStates.removeLostLegionExpansion==true and heroChallengeGUIDInList(guid,setupContentRoster.lostLegion.terrain.country) then return false end
	if gStates.removeApocalypseTerrain==true and heroChallengeGUIDInList(guid,setupContentRoster.apocalypse.terrain.country) then return false end
	return terrainTiles[guid]~=nil and terrainTiles[guid].tileType=="country"
end

function heroChallengeCountryIn(guid, numbers)
	for _, number in ipairs(numbers or {}) do if guid==heroChallengeCountryGUID(number) then return true end end
	return false
end

function heroChallengeCountryHasVillage(guid)
	local data=terrainTiles[guid]
	if data==nil or data.hexFeature==nil then return false end
	for _, feature in pairs(data.hexFeature) do if feature=="village" then return true end end
	return false
end

--Mirror the scenario-specific Countryside pools used by mapSetup(). This lets setup legality be tested
--before Start is pressed and lets Hero Challenges safely combine the requirements of several Heroes.
function heroChallengeCountrySlotAllows(guid, slot)
	if heroChallengeCountryAvailable(guid)~=true then return false end
	local scenario=gStates.gameScenario
	local countryCount=scenarioList[gStates.scenarioRef][gStates.playersRef].countryTiles
	if scenario=="First Reconnaissance" then
		local order={"03","04","05","06","07","08","09","10","11","02","01"}
		local index=slot
		if slot>=countryCount-1 then index=slot+(11-countryCount) end
		return guid==heroChallengeCountryGUID(order[index])
	end
	if scenario=="Mines Liberation" then
		if slot<=4 then return heroChallengeCountryIn(guid,{"02","03","05","06","13","14","15","17"}) end
		return heroChallengeCountryIn(guid,{"01","04","07","08","09","10","11","12","16"})
	end
	if scenario=="Conquer and Hold" then return heroChallengeCountryIn(guid,{"03","04","09","10","11","13","14","15","17"}) end
	if scenario=="The Gauntlet" then return heroChallengeCountryIn(guid,{"01","02","03","04","05","06","07","08","09","10","12","13","14","15","16","17"}) end
	if scenario=="Druid Nights" then
		local gladeSlots=0
		for _,number in ipairs({"01","02","05","07","08","13","16"}) do
			if heroChallengeCountryAvailable(heroChallengeCountryGUID(number))==true then gladeSlots=gladeSlots+1 end
		end
		gladeSlots=math.min(gladeSlots,countryCount)
		if slot<=gladeSlots then return heroChallengeCountryIn(guid,{"01","02","05","07","08","13","16"}) end
		return heroChallengeCountryIn(guid,{"03","04","06","09","10","11","12","14","15","17"})
	end
	if scenario=="Dungeon Lords" and slot<=2 then return heroChallengeCountryIn(guid,{"07","09"}) end
	if scenario=="Quest for the Golden Grail" or scenario=="The Chaos Rift" then
		if slot<=4 then return heroChallengeCountryIn(guid,{"04","05","07","09","11","12","13","15"}) end
		return heroChallengeCountryIn(guid,{"01","02","03","06","08","10","14","16","17"})
	end
	if scenario=="Life and Death" then
		local gladeSlots=gStates.playerCount>=2 and gStates.playerCount+1 or 3
		if slot<=gladeSlots then return heroChallengeCountryIn(guid,{"01","02","05","07","08","13","16"}) end
		return heroChallengeCountryIn(guid,{"03","04","06","09","10","11","12","14","15","17"})
	end
	if scenario=="The Realm of the Dead Blitz" then
		local gladeSlots=gStates.coop==1 and gStates.playerCount+1 or gStates.playerCount
		if slot<=gladeSlots then return heroChallengeCountryIn(guid,{"01","02","05","07","08","13","16"}) end
		return heroChallengeCountryIn(guid,{"03","04","06","09","10","11","12","14","15","17"})
	end
	if scenario=="Raiders of the Crusader Temple" and slot<=3 then return heroChallengeCountryIn(guid,{"08","10","11"}) end
	if scenario=="Against the Apocalypse Blitz" then
		local zigguratSlots=gStates.playerCount>1 and 2 or 1
		if slot<=zigguratSlots then return heroChallengeCountryIn(guid,{"16","17"}) end
		return heroChallengeCountryIn(guid,{"01","02","03","04","05","06","07","08","09","10","11","12","13","14","15"})
	end
	--Against the Horsemen has one compulsory terrain tile: Countryside 1 is the face-up centre.
	--All other Countryside slots are unrestricted after the normal expansion/variant availability checks.
	if scenario=="Against the Horsemen Blitz" and slot==1 then return guid==GUID.tile.country01 end
	return true
end

function heroChallengeShuffleCopy(array)
	local result={}
	for i,value in ipairs(array or {}) do result[i]=value end
	for i=#result,2,-1 do local j=math.random(i) result[i],result[j]=result[j],result[i] end
	return result
end

function heroChallengeRequirementSets()
	local sets={{}}
	for seat=1,4 do
		local mage=gStates.positionMageKnight[seat]
		if mage~=nil and mage~="nobody" then
			local data=heroChallengesData[mage]
			if data==nil then return nil,"Hero Challenges: Unsupported Mage Knight" end
			for _, alternatives in ipairs(data.country or {}) do
				local expanded={}
				for _, existing in ipairs(sets) do
					for _, number in ipairs(alternatives) do
						local copy={}
						for guid,_ in pairs(existing) do copy[guid]=true end
						copy[heroChallengeCountryGUID(number)]=true
						expanded[#expanded+1]=copy
					end
				end
				sets=expanded
			end
		end
	end
	return sets,nil
end

--Return a complete legal Countryside assignment, not just the forced tiles. When Hero Challenges are on,
--using the complete assignment avoids duplicate GUID selection after several Heroes reserve overlapping pools.
function heroChallengeCountryAssignment(randomize)
	if gStates.heroChallenges~=true then return nil,nil end
	local countryCount=scenarioList[gStates.scenarioRef][gStates.playersRef].countryTiles
	local requirementSets,reason=heroChallengeRequirementSets()
	if requirementSets==nil then return nil,reason end
	local available={}
	for number=1,17 do
		local guid=heroChallengeCountryGUID(string.format("%02d",number))
		if heroChallengeCountryAvailable(guid)==true then available[#available+1]=guid end
	end
	if randomize==true then available=heroChallengeShuffleCopy(available) end
	local expandedSets={}
	for _,required in ipairs(requirementSets) do
		local hasVillage=false
		for guid,_ in pairs(required) do if heroChallengeCountryHasVillage(guid)==true then hasVillage=true break end end
		if apocalypseQuestsUsed()==true and hasVillage==false then
			for _,guid in ipairs(available) do
				if heroChallengeCountryHasVillage(guid)==true then
					local copy={} for existing,_ in pairs(required) do copy[existing]=true end copy[guid]=true
					expandedSets[#expandedSets+1]=copy
				end
			end
		else expandedSets[#expandedSets+1]=required end
	end
	if randomize==true then expandedSets=heroChallengeShuffleCopy(expandedSets) end

	for _,requiredSet in ipairs(expandedSets) do
		local required={}
		local possible=true
		for guid,_ in pairs(requiredSet) do
			if heroChallengeCountryAvailable(guid)~=true then possible=false break end
			required[#required+1]=guid
		end
		if possible==true and #required<=countryCount then
			table.sort(required,function(a,b)
				local ca,cb=0,0
				for slot=1,countryCount do if heroChallengeCountrySlotAllows(a,slot) then ca=ca+1 end if heroChallengeCountrySlotAllows(b,slot) then cb=cb+1 end end
				return ca<cb
			end)
			if randomize==true then
				--Shuffle equal-flexibility groups without undoing the useful constrained-first ordering.
				local i=1
				while i<=#required do
					local count=0 for slot=1,countryCount do if heroChallengeCountrySlotAllows(required[i],slot) then count=count+1 end end
					local j=i+1
					while j<=#required do local c=0 for slot=1,countryCount do if heroChallengeCountrySlotAllows(required[j],slot) then c=c+1 end end if c~=count then break end j=j+1 end
					local group={} for k=i,j-1 do group[#group+1]=required[k] end group=heroChallengeShuffleCopy(group) for k=i,j-1 do required[k]=group[k-i+1] end i=j
				end
			end
			local forcedSlots,usedTiles={},{}
			local result=nil
			local function fillRemaining()
				local tileMatch={}
				local remainingSlots={}
				for slot=1,countryCount do if forcedSlots[slot]==nil then remainingSlots[#remainingSlots+1]=slot end end
				table.sort(remainingSlots,function(a,b)
					local ca,cb=0,0
					for _,guid in ipairs(available) do if usedTiles[guid]~=true and heroChallengeCountrySlotAllows(guid,a) then ca=ca+1 end if usedTiles[guid]~=true and heroChallengeCountrySlotAllows(guid,b) then cb=cb+1 end end
					return ca<cb
				end)
				local function augment(slot,seen)
					local candidates=randomize==true and heroChallengeShuffleCopy(available) or available
					for _,guid in ipairs(candidates) do
						if usedTiles[guid]~=true and seen[guid]~=true and heroChallengeCountrySlotAllows(guid,slot)==true then
							seen[guid]=true
							if tileMatch[guid]==nil or augment(tileMatch[guid],seen)==true then tileMatch[guid]=slot return true end
						end
					end
					return false
				end
				for _,slot in ipairs(remainingSlots) do if augment(slot,{})~=true then return nil end end
				local assignment={}
				for slot,guid in pairs(forcedSlots) do assignment[slot]=guid end
				for guid,slot in pairs(tileMatch) do assignment[slot]=guid end
				return assignment
			end
			local function placeRequired(index)
				if index>#required then result=fillRemaining() return result~=nil end
				local guid=required[index]
				local slots={} for slot=1,countryCount do if forcedSlots[slot]==nil and heroChallengeCountrySlotAllows(guid,slot) then slots[#slots+1]=slot end end
				if randomize==true then slots=heroChallengeShuffleCopy(slots) end
				for _,slot in ipairs(slots) do
					forcedSlots[slot]=guid usedTiles[guid]=true
					if placeRequired(index+1)==true then return true end
					forcedSlots[slot]=nil usedTiles[guid]=nil
				end
				return false
			end
			if placeRequired(1)==true then return result,nil end
		end
	end
	return nil,"Hero Challenges: Required terrain cannot fit this setup"
end

function heroChallengeSetupLegal()
	if gStates.heroChallenges~=true then return true,nil end
	if gStates.useCustomMageKnights==true then return false,"Hero Challenges cannot use fan-made Mage Knights" end
	if (gStates.riseOfTheForgemasters or 0)>0 then return false,"Hero Challenges cannot use Rise of the Forgemasters" end
	local humans=0
	for seat=1,4 do
		local mage=gStates.positionMageKnight[seat]
		if mage~=nil and mage~="nobody" then
			humans=humans+1
			if mage=="Random" or mage=="All Skills" then return false,"Hero Challenges: Choose specific Mage Knights" end
			if heroChallengesData[mage]==nil then return false,"Hero Challenges: Unsupported Mage Knight" end
		end
	end
	if humans==0 then return false,"Hero Challenges: Choose a Mage Knight" end
	local assignment,reason=heroChallengeCountryAssignment(false)
	if assignment==nil then return false,reason end
	return true,nil
end

--Append the active Heroes' personal Challenge objectives to the Scenario End help box.
--The printed objectives are currently English; repeat them inside every language branch so the information
--is never hidden merely because the user is viewing another translated Scenario End entry.
function heroChallengeScenarioEndText(baseText)
	local text=tostring(baseText or "")
	if gStates==nil or gStates.heroChallenges~=true then return text end
	local lines={}
	for seat=1,4 do
		local mage=gStates.positionMageKnight~=nil and gStates.positionMageKnight[seat] or nil
		local challenge=mage~=nil and heroChallengesData[mage] or nil
		if challenge~=nil then lines[#lines+1]=tostring(mage)..": "..tostring(challenge.objective or "") end
	end
	if #lines==0 then return text end
	local suffix="\n\nHero Challenges:\n"..table.concat(lines,"\n")
	local firstTagStart=text:find("{[%a%-]+}")
	if firstTagStart==nil then return text..suffix end
	local out={}
	if firstTagStart>1 then out[#out+1]=text:sub(1,firstTagStart-1) end
	local pos=firstTagStart
	while pos<=#text do
		local tagStart,tagEnd=text:find("{[%a%-]+}",pos)
		if tagStart==nil then break end
		local nextTagStart=text:find("{[%a%-]+}",tagEnd+1)
		local body=nextTagStart~=nil and text:sub(tagEnd+1,nextTagStart-1) or text:sub(tagEnd+1)
		out[#out+1]=text:sub(tagStart,tagEnd)..body..suffix
		if nextTagStart==nil then break end
		pos=nextTagStart
	end
	return table.concat(out)
end

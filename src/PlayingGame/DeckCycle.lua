-- Shared draw-deck cycle tracking for cards returned to the bottom of standard decks.
-- TTS may collapse/rebuild Deck objects as cards are drawn or returned, so non-Artifact piles
-- are resolved from their scripting zones instead of assuming a persistent Deck GUID.

local function standardDeckCycleZone(deckName)
	if deckName=="Advanced Action" then return GUID.zone.actionDeck end
	if deckName=="Spell" then return GUID.zone.spellDeck end
	if deckName=="Regular Unit" then return GUID.zone.regularUnit end
	if deckName=="Elite Unit" then return GUID.zone.eliteUnit end
	return nil
end

function standardDeckCycleObject(deckName)
	if deckName=="Artifact" then return getObjectFromGUID(GUID.deck.artifact) end
	local zoneGUID=standardDeckCycleZone(deckName)
	local zone=zoneGUID~=nil and getObjectFromGUID(zoneGUID) or nil
	if zone~=nil then
		for _,obj in pairs(zone.getObjects()) do
			if obj.type=="Deck" or obj.type=="Card" then return obj end
		end
	end
	return nil
end

local function standardDeckCycleMarker(deckName)
	if deckName==nil or gStates==nil or gStates.standardDeckFirstReturnedGUID==nil then return nil end
	return gStates.standardDeckFirstReturnedGUID[deckName]
end

function standardDeckCycleMarkReturned(deckName,card)
	if deckName==nil or gStates==nil or gStates.firstStarted~=true or card==nil then return false end
	if gStates.standardDeckFirstReturnedGUID==nil then gStates.standardDeckFirstReturnedGUID={} end
	if gStates.standardDeckFirstReturnedGUID[deckName]==nil then
		gStates.standardDeckFirstReturnedGUID[deckName]=card.guid
		return true
	end
	return false
end

function standardDeckCycleShuffleIfReached(deckName,deck,candidateGUID)
	local firstReturned=standardDeckCycleMarker(deckName)
	if firstReturned==nil then return false end
	deck=deck or standardDeckCycleObject(deckName)
	if deck==nil or (deck.type~="Deck" and deck.type~="Card") then return false end
	local reachedGUID=candidateGUID
	if reachedGUID==nil then
		if deck.type=="Deck" then
			local objects=deck.getObjects()
			if objects[1]~=nil then reachedGUID=objects[1].guid end
		else
			reachedGUID=deck.guid
		end
	end
	if reachedGUID~=firstReturned then return false end
	gStates.standardDeckFirstReturnedGUID[deckName]=nil
	if deck.type=="Deck" and deck.getQuantity()>1 then deck.shuffle() end
	return true
end

function standardDeckCycleClearIfDeckShuffled(deck)
	if deck==nil or deck.type~="Deck" or gStates==nil or gStates.standardDeckFirstReturnedGUID==nil then return false end
	for _,deckName in ipairs({"Artifact","Regular Unit","Elite Unit","Advanced Action","Spell"}) do
		local current=standardDeckCycleObject(deckName)
		if current~=nil and current.guid==deck.guid then
			gStates.standardDeckFirstReturnedGUID[deckName]=nil
			return true
		end
	end
	return false
end

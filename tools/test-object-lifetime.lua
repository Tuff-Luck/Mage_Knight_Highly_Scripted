-- Reproduce TTS's non-nil but invalid LuaGameObjectScript references.
-- Run: lua5.2 tools/test-object-lifetime.lua
local function check(label,condition)
	assert(condition,label)
	print("PASS "..label)
end

local stale=setmetatable({
	guid="dead01",
	isDestroyed=function() return true end,
	getPosition=function() error("destroyed position") end
},{
	__index=function(_,key)
		if key=="type" or key=="alt_view_angle" then error("cannot access "..key.." of destroyed LuaGameObjectScript") end
	end
})
local liveDeck={guid="live01",type="Deck",isDestroyed=function() return false end,
	getQuantity=function() return 3 end}
local liveCard={guid="card01",type="Card",isDestroyed=function() return false end}
local actionZone={guid="actz01",getObjects=function() return {stale,liveDeck,liveCard} end}
local deedZone={guid="deed01",getObjects=function() return {stale,liveDeck,liveCard} end}
local objects={actz01=actionZone,deed01=deedZone,live01=liveDeck,card01=liveCard}
getObjectFromGUID=function(guid) return objects[guid] end
GUID={zone={actionDeck="actz01",spellDeck="actz01",regularUnit="actz01",eliteUnit="actz01"},deck={artifact="live01"}}
gStates={firstStarted=true,standardDeckFirstReturnedGUID={},monsterPlayLocation={}}
deedDeckZones={[1]="deed01"}
deedDeckDiscardZones={[1]="deed01"}
turnOrder={{seatPos=1}}
monsterPugs={}
terrainTiles={}
skillTokens={}
function scriptObjectId(obj) return obj.getName and obj.getName() end
function isShieldObject(_) return false end
publishPublicUICallbacks=function(_) end
dofile("src/PlayingGame/DeckCycle.lua")
dofile("src/PlayingGame/PlayerBoard/CardFlow.lua")
dofile("src/PlayingGame/MapTokens.lua")

check("zone lookup ignores expired Deck references",standardDeckCycleObject("Advanced Action")==liveDeck)
objects.live01=nil
check("zone lookup falls back to live Card when Deck expired",standardDeckCycleObject("Advanced Action")==nil)
-- A freshly-invalidated object should not be used for deck numeric shortcuts.
objects.live01=liveDeck
deedZone.getObjects=function() return {stale,liveDeck} end
setDeedDeckImmediateNumberTyping(1)
check("deed typing skips dead userdata",liveDeck.max_typed_number==1)
deedZone.getObjects=function() return {stale} end
setDeedDeckImmediateNumberTyping(1)
check("all-dead zone does not crash",true)

local noteObject=setmetatable({guid="marker1",isDestroyed=function() return true end,
	getName=function() return "GraveYard" end,
	getGMNotes=function() return "" end,
	getPosition=function() return {1,1,1} end},{
	__index=function(_,key)
		if key=="type" then error("invalid type") end
	end
})
check("destroy callback can identify Graveyard without .type",mapTokenNeedsArrangement(noteObject,{destroying=true})==true)
check("normal expired marker is ignored",mapTokenNeedsArrangement(noteObject)==false)
local expired=setmetatable({guid="marker2",isDestroyed=function() return true end,
	getName=function() error("expired name") end,
	getGMNotes=function() error("expired notes") end},{
	__index=function(_,key)
		if key=="type" then error("expired type") end
	end
})
check("invalid destroyed marker fails closed without throwing",mapTokenNeedsArrangement(expired,{destroying=true})==false)
print("Object lifetime regression tests passed.")

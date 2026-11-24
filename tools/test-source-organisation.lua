-- Source layout guard: paths are part of the TTS bundler contract.
local expected={
    ["src/PlayingGame/Combat/Combat.lua"]=true,
    ["src/PlayingGame/GameFlow/Callbacks.lua"]=true,
    ["src/PlayingGame/Interface/UI.lua"]=true,
    ["src/PlayingGame/Offers/DeckCycle.lua"]=true,
    ["src/PlayingGame/Scenarios/Quests.lua"]=true,
    ["src/PlayingGame/World/Map.lua"]=true,
    ["src/PlayingGame/Components/ManaSource.lua"]=true,
    ["src/PlayingGame/PlayerBoard/Units/UnitHistory.lua"]=true
}
for path in pairs(expected) do
    local f=assert(io.open(path,"r"),"Missing organised source "..path)
    f:close()
end
local f=assert(io.open(".tts/objects/Global.lua","r"))
local entry=f:read("*a")
f:close()
local function position(module)
    return assert(entry:find('require("'..module..'")',1,true),"Missing entry "..module)
end
assert(position("ErrorReporting")<position("Shared"))
assert(position("PlayingGame.World.City")<position("PlayingGame.Scenarios.FactionLeaders"))
assert(position("PlayingGame.Scenarios.FactionLeaders")<position("PlayingGame.Combat.Combat"))
assert(position("PlayingGame.Interface.UI")<position("PlayingGame.GameFlow.Callbacks"))
assert(position("PlayingGame.GameFlow.Events")<position("PlayingGame.GameFlow.Callbacks"))
print("Organised source paths and Global load-order invariants passed")

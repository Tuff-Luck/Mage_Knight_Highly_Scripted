-- Wings of Wind: paid activation, one-use movement paths and legal landings.
-- Run from repo root: lua5.2 tools/test-wings-of-wind.lua
local function read(path)
    local f=assert(io.open(path,"r"))
    local result=f:read("*a")
    f:close()
    return result
end
local function between(text,first,last)
    local a=assert(text:find(first,1,true),"Missing "..first)
    local b=assert(text:find(last,a+#first,true),"Missing "..last)
    return text:sub(a,b-1)
end
local data=read("src/Data.lua")
local rules=assert(load("return {\n"..between(data,
    "    -- Spell resources are independent","    -- Artifact sides are physical").."\n}"))()
local spell=assert(rules.spellWingsNight)
assert(spell.movementEffects.normal.windFlightMax==5)
assert(spell.movementEffects.powered==nil,"Wings of Night is combat only")
local reader=read("src/PlayingGame/PlayerBoard/CardRecognition.lua")
assert(reader:find("or spellCastingPaid[card.guid]==true",1,true),
    "The existing movement effect collection must require a paid Spell")
assert(reader:find("movementEffects.windFlightMax=math.max(",1,true))
assert(reader:find("(priorMovement.windFlightMax or 0)~=movementEffects.windFlightMax",1,true))
local movement=read("src/PlayingGame/Movement.lua")
assert(movement:find("windFlightMax>0 and not spentWind",1,true),
    "A flight must be available only once along a route")
assert(movement:find('state:sub(1,4)=="safe"',1,true),
    "Both normal and post-Wind safe states must be traversable")
assert(movement:find('previous.windPath',1,true),"Wings flight needs a distinct drawn route")

-- Execute the real pathfinder in isolation from Tabletop Simulator.
MOVE_DISPLAY_VECTORS={{0,-1},{-1,-1},{-1,0},{0,1},{1,1},{1,0}}
MOVE_DISPLAY_TWO_HEX_VECTORS={{0,-2},{-1,-2},{-2,-2},{-2,-1},{-2,0},{-1,1},
    {0,2},{1,2},{2,2},{2,1},{2,0},{1,-1}}
resourceCardsEffectiveTerrainCost=function(kind)
    return (kind=="lake" or kind=="mountain" or kind=="wall" or kind=="explore") and 999 or 2
end
local begin=assert(movement:find("function moveDisplayWindDestinations(",1,true))
local finish=assert(movement:find("\nMOVE_DISPLAY_RAMPAGE_ADJACENT=",begin,true))
assert(load(movement:sub(begin,finish-1)))()

local map={}
local function hex(hor,vec,kind,opts)
    local row=map[tostring(hor)] or {}
    map[tostring(hor)]=row
    local result={hexType=kind,tileGUID="revealed"}
    for key,value in pairs(opts or {}) do result[key]=value end
    row[tostring(vec)]=result
end
hex(0,0,"plains")
hex(1,0,"mountain")
hex(2,0,"lake")
hex(3,0,"plains")
hex(4,0,"city",{fortified="city"})
hex(5,0,"plains")
hex(6,0,"plains")
hex(-1,0,"plains",{rampager=true})
hex(0,-1,"explore")
hex(0,1,"wall",{tileGUID=false})
-- A wall without a tileGUID is not a valid revealed traversable space.
map["0"]["1"].tileGUID=nil

local function keyed(destinations)
    local result={}
    for _,entry in ipairs(destinations) do result[entry.hor..":"..entry.vec]=entry end
    return result
end
local results=keyed(moveDisplayWindDestinations(map,0,0,5,false))
assert(results["3:0"]~=nil and results["3:0"].cost==3,
    "Fly through mountain and lake for 3 Move")
assert(#results["3:0"].path==4,"Flight path includes start and landing")
assert(results["5:0"]~=nil and results["5:0"].cost==5,
    "Fly through an unconquered City to a safe landing")
assert(results["1:0"]==nil and results["2:0"]==nil,
    "Mountains and Lakes are not safe landings")
assert(results["4:0"]==nil and results["-1:0"]==nil,
    "Fortified sites and Rampagers are not safe landings")
assert(results["6:0"]==nil,"Wings cannot spend 6 Move")
assert(results["0:-1"]==nil and results["0:1"]==nil,
    "Do not fly into unrevealed placeholders or walls")
local shorter=keyed(moveDisplayWindDestinations(map,0,0,2,false))
assert(shorter["3:0"]==nil,"Flight budget limits movement")
local bent=keyed(moveDisplayWindDestinations(map,0,0,5,true))
assert(bent["3:0"]~=nil and bent["3:0"].cost==2,
    "Space Bending treats two-away revealed spaces as adjacent during Wings")
print("Wings of Wind movement tests passed")

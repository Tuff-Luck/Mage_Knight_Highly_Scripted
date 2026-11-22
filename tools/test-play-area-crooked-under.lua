-- A crooked played card can tuck under one overlapping card without
-- merging the two objects into a Deck or waiting for 'resting'.
-- Run from repository root: lua5.2 tools/test-play-area-crooked-under.lua
local function read(path)
    local f=assert(io.open(path,"r"))
    local content=f:read("*a")
    f:close()
    return content
end
local function section(source,first,last)
    local a=assert(source:find(first,1,true),"Missing "..first)
    local b=assert(source:find(last,a+#first,true),"Missing "..last)
    return source:sub(a,b-1)
end
local events=read("src/PlayingGame/PlayerBoard/Events.lua")
local callback=read("src/PlayingGame/Events.lua")
assert(callback:find("playerBoardObjectDropped(dropped_object)",1,true),
    "All manual drops must reach the crooked-card restack handler")
assert(events:find("playerBoardScheduleCrookedUnder(obj)",1,true),
    "The player-board drop callback must schedule crooked cards")
local matCode=section(events,"local function playerBoardPlayMatSeat(obj)",
    "\n-- A lifted card must never have its buttons destroyed")
local underCode=section(events,"-- A deliberately crooked played card",
    "\nfunction playerBoardObjectDropped(obj)")
local function position(x,y,z)
    return {x=x,y=y,z=z,[1]=x,[2]=y,[3]=z}
end
local function makeCard(guid,x,y,z,angle)
    local obj={guid=guid,type="Card",held_by_color=nil,moves=0,
        rotation={x=0,y=angle,z=0},pos=position(x,y,z)}
    obj.getPosition=function() return obj.pos end
    obj.getRotation=function() return obj.rotation end
    obj.getBounds=function() return {size={x=2,y=0.05,z=3}} end
    obj.isSmoothMoving=function() return false end
    obj.isDestroyed=function() return false end
    obj.setPositionSmooth=function(p,collide,fast)
        assert(collide==false and fast==false,
            "Auto-Under must use normal-speed no-collision smooth movement")
        obj.pos=position(p[1],p[2],p[3])
        obj.moves=obj.moves+1
    end
    obj.putObject=function() error("Auto-Under must not merge played cards into a Deck") end
    return obj
end
local zone={
    getPosition=function() return position(0,1,0) end,
    getRotation=function() return {y=0} end,
    getScale=function() return position(20,0.10,20) end,
    getBounds=function() return {size=position(0,0,0)} end
}
local objects,all,frames,choices,updates={},{},{},0,0
local env={
    math=math,ipairs=ipairs,pairs=pairs,
    gStates={firstStarted=true},
    playerPlayAreas={[1]="area"},
    gameCards={},
    getAllObjects=function() return all end,
    getObjectFromGUID=function(guid)
        return guid=="area" and zone or objects[guid]
    end,
    resourceCardsObjectPickedUp=function()
        choices=choices+1
    end,
    resourceCardsObjectMoved=function() updates=updates+1 end,
    safeWaitFrames=function(_owner,callback,_count)
        frames[#frames+1]=callback
    end,
    safeWaitCondition=function(_owner,callback,condition,_timeout,onTimeout)
        if condition() then callback() else onTimeout() end
    end
}
setmetatable(env,{__index=_G})
local run=assert(load(matCode.."\n"..underCode
    .."\nreturn playerBoardScheduleCrookedUnder",
    "Crooked card Auto-Under","t",env))()
local function setup(...)
    objects,all,frames={}, {}, {}
    choices,updates=0,0
    env.gameCards={}
    for _,obj in ipairs({...}) do
        objects[obj.guid]=obj
        env.gameCards[obj.guid]={}
        all[#all+1]=obj
    end
end
local function drain(onTick)
    local iterations=0
    while #frames>0 do
        iterations=iterations+1
        assert(iterations<110,"Auto-Under watcher must be bounded")
        if onTick~=nil then onTick(iterations) end
        table.remove(frames,1)()
    end
end
local base=makeCard("base",0,1.20,0,0)
local crooked=makeCard("crooked",0.1,1.27,0.1,17)
setup(base,crooked)
run(crooked)
drain()
assert(crooked.pos.y==1.20 and base.pos.y>crooked.pos.y
    and crooked.rotation.y==17 and crooked.pos.x==0.1
    and crooked.moves==1 and base.moves==2,
    "Crooked card must move beneath the other card without rotating or merging")
assert(choices==2 and updates==2,
    "Repositioning must preserve tracker choices and refresh both cards")

for _,angle in ipairs({0,3,90,180,270}) do
    base=makeCard("base",0,1.20,0,0)
    crooked=makeCard("crooked",0,1.27,0,angle)
    setup(base,crooked)
    run(crooked)
    drain()
    assert(base.moves==0 and crooked.moves==0,
        "Straight or near-straight cards must stay untouched")
end

base=makeCard("base",0,1.20,0,0)
crooked=makeCard("crooked",0,1.17,0,20)
setup(base,crooked)
run(crooked)
drain()
assert(base.moves==0 and crooked.moves==0,
    "A crooked card already below the target must not be moved")

base=makeCard("base",5,1.20,0,0)
crooked=makeCard("crooked",0,1.27,0,25)
setup(base,crooked)
run(crooked)
drain()
assert(base.moves==0 and crooked.moves==0,
    "Cards without substantial overlap must not be restacked")

local second=makeCard("second",0.1,1.18,0,0)
base=makeCard("base",0,1.20,0,0)
crooked=makeCard("crooked",0,1.27,0,25)
setup(base,second,crooked)
run(crooked)
drain()
assert(base.moves==0 and second.moves==0 and crooked.moves==0,
    "Ambiguous multi-card overlaps must be left alone")

base=makeCard("base",0,1.20,0,0)
crooked=makeCard("crooked",0,2.00,0,25)
setup(base,crooked)
run(crooked)
drain(function(tick)
    if tick>=4 and crooked.pos.y>1.30 then
        crooked.pos=position(0,math.max(1.30,crooked.pos.y-0.20),0)
    end
end)
assert(crooked.moves==1 and base.moves==2,
    "A falling card should be restacked by height even when it never rests")

base=makeCard("base",0,1.20,0,0)
crooked=makeCard("crooked",0,1.27,0,20)
setup(base,crooked)
run(crooked)
crooked.held_by_color="Blue"
drain()
assert(base.moves==0 and crooked.moves==0,
    "Never restack a card the player has picked up again")
print("Play Area crooked Auto-Under regressions passed")

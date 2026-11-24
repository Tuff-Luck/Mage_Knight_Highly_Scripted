-- Skills and Faction Rewards must preserve manual options and enemy targets
-- on the same shallow play mat, even though they are not TTS Card objects.
-- Run: lua5.2 tools/test-play-token-relocation-locks.lua
local function read(path)
    local f=assert(io.open(path,"r"))
    local s=f:read("*a")
    f:close()
    return s
end
local function section(src,first,last)
    local a=assert(src:find(first,1,true),"Missing "..first)
    local b=assert(src:find(last,a+#first,true),"Missing "..last)
    return src:sub(a,b-1)
end
local src=read("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local geometry=section(src,"trackerPrivate.zoneFootprintContainsXZ=function(obj,zone)",
    "local function footprint(obj)")
local kinds=section(src,"local function resourceObjectKind(obj)",
    "-- A NightRules token")
local pickup=section(src,"function resourceCardsObjectPickedUp(obj)",
    "function resourceCardsZoneEntered(ctx)")
local drop=section(src,"function resourceCardsObjectMoved(obj,stabilized)",
    "-- Register the remaining readying")

local posByGUID={}
local tokens={}
local function token(guid,notes)
    local p={x=1,y=2,z=0}
    local obj={guid=guid,type="Custom_Token",is_face_down=false,
        held_by_color=nil,resting=true,
        getGMNotes=function() return notes end,
        getPosition=function() return p end,
        getRotation=function() return {0,0,0} end,
        isSmoothMoving=function() return false end,
        isDestroyed=function() return false end}
    tokens[guid]=obj
    posByGUID[guid]=p
    return obj
end
local skill=token("skill01","Skill")
local reward=token("reward01","Dark Crusader Reward")
local zone={
    -- A shallow trigger may not list these objects until well after Drop.
    getObjects=function() return {} end,
    getBounds=function() return {size={x=0,z=0}} end,
    getPosition=function() return {x=0,z=0} end,
    getScale=function() return {x=12,z=12} end,
    getRotation=function() return {y=0} end
}
local tracker={
    playCandidatesBySeat={[1]={skill01=true,reward01=true}},
    bySeat={[1]={skill01=true,reward01=true}},
    playCardMovements={},choiceResetGenerationByGUID={},
    factionRewardNotes={["Dark Crusader Reward"]="Dark"},
    checkCardChoicesAfterDrop=function(guid,seat) assert(seat==1) end, -- UI repair is covered separately
    playCandidateKind=function(kind)
        return kind=="card" or kind=="skill" or kind=="factionReward"
    end
}
local selected={skill01={effect="attack"},reward01={effect="block"}}
local combat={
    targets={skill01="enemyLeft",reward01="enemyLeft"},
    explicit={skill01=true,reward01=true}
}
local frames,queues={},0
local env={
    trackerPrivate=tracker,selectedResourceByGUID=selected,
    combatAssignmentState=combat,
    playerPlayAreas={[1]="play"},turnOrder={{seatPos=1}},
    gStates={turnNumber=1,resourceCardPlayOrder={skill01=1,reward01=2}},
    gameCards={},skillTokens={skill01={skillType="Hero"}},
    getObjectFromGUID=function(guid)
        if guid=="play" then return zone end
        return tokens[guid]
    end,
    manaColor=function() return nil end,
    combatEnemyData=function() return nil end,
    unitLayoutIsCommand=function() return false end,
    unitLayoutIsWound=function() return false end,
    resourceCardsPanelOpen=function() return true end,
    cardPosture=function() return "upright" end,
    safeWaitFrames=function(_,fn) frames[#frames+1]=fn end,
    queueSeat=function() queues=queues+1 end
}
setmetatable(env,{__index=_G})
local source=table.concat({geometry,kinds,pickup,drop,
    "return resourceObjectKind,resourceCardsObjectPickedUp,trackerPrivate.finishPlayCardMove"},"\n")
local kindOf,onPickup,finish=assert(load(source,"Skill and reward relocation","t",env))()
assert(kindOf(skill)=="skill","Skill token must be a tracked source")
assert(kindOf(reward)=="factionReward","Faction Reward must be a tracked source")

local function tick()
    local callbacks=frames
    frames={}
    for _,fn in ipairs(callbacks) do fn() end
end
for _,obj in ipairs({skill,reward}) do
    local guid=obj.guid
    local original=selected[guid].effect
    -- The real onPickUp event is the start of a relocation transaction.
    obj.held_by_color="White"
    onPickup(obj)
    assert(tracker.playCardMovements[guid]~=nil,
        "Pickup must protect "..guid.." despite being a non-Card object")
    -- Simulate an intermediate erroneous scan trying to replace the choice
    -- and nearest target. The settled callback restores the saved decision.
    selected[guid]={effect=original=="attack" and "block" or "attack"}
    combat.targets[guid]="enemyNear"
    combat.explicit[guid]=nil
    posByGUID[guid].x=4
    posByGUID[guid].y=8
    obj.held_by_color=nil
    obj.resting=false
    finish(obj)
    for i=1,5 do tick() end
    assert(tracker.playCardMovements[guid]==nil,
        "Settled "..guid.." must complete its relocation")
    assert(selected[guid].effect==original
        and combat.targets[guid]=="enemyLeft"
        and combat.explicit[guid]==true,
        "Repositioning "..guid.." must retain option and manual enemy target")
    assert(tracker.cardOverPlayMat(obj,1),
        "Released "..guid.." must count as on the mat despite missing zone entry")
end
assert(queues>=2,"Both tokens must request a settled recalculation")
print("Skill and Faction Reward relocation option/target regressions passed")

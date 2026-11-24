-- End-turn combat must use the calculator's defeat verdict without flipping enemy tokens.
-- Run from repository root: lua5.2 tools/test-combat-defeat-cleanup.lua
local function equal(actual,expected,label)
    assert(actual==expected,(label or "Mismatch")..": expected "..tostring(expected)
        ..", got "..tostring(actual))
end

local function read(path)
    local file=assert(io.open(path,"r"))
    local source=file:read("*a")
    file:close()
    return source
end

local source=read("src/PlayingGame/Combat.lua")
local function slice(first,last)
    local a=assert(source:find(first,1,true),first.." missing")
    local b=assert(source:find(last,a+#first,true),last.." missing")
    return source:sub(a,b-1)
end

local env={
    combatDefeatMarksActive=true,
    combatDefeatTracked={dead=true,survivor=true,partial=true},
    combatDefeatDefeated={dead=true},
    combatDefeatPartial={partial=true},
    gStates={preEndTurn=false}
}
setmetatable(env,{__index=_G})
assert(load(slice("function combatEnemyTokenDefeated(obj)","-- Puppet Master must"),
    "defeat decisions","t",env))()
assert(load(slice("function combatDefeatSnapshotForCleanup()","-- A Ruin with"),
    "defeat snapshot","t",env))()

local faceUp={guid="dead",is_face_down=false}
local survivor={guid="survivor",is_face_down=false}
local partial={guid="partial",is_face_down=false}
local untracked={guid="untracked",is_face_down=false}
equal(env.combatEnemyTokenDefeated(faceUp),true,"Calculator defeated")
equal(env.combatEnemyTokenDefeated(survivor),false,"Face-up calculator survivor")
equal(env.combatEnemyTokenDefeated(partial),false,"Partial boss not fully defeated")
equal(env.combatEnemyTokenDefeated(untracked),true,"Untracked physical fallback")
equal(env.combatBossPartialRewardEligible("partial"),true,"Partial damage recorded")

local results,partials=env.combatDefeatSnapshotForCleanup()
equal(results.dead,true,"Snapshot stores defeated")
equal(results.survivor,false,"Snapshot explicitly stores surviving")
equal(results.partial,false,"Snapshot does not kill partial boss")
equal(partials.partial,true,"Snapshot stores partial boss progress")

-- Simulate the calculator closing and a TTS reload: only the persisted
-- pre-end-turn recovery data survives, not runtime markers.
env.combatDefeatMarksActive=false
env.combatDefeatTracked={}
env.combatDefeatDefeated={}
env.combatDefeatPartial={}
env.gStates={preEndTurn=true,combatPreEndTurnRecovery={
    defeatResults=results,partialResults=partials
}}
equal(env.combatEnemyTokenDefeated(faceUp),true,"Defeated after reload")
equal(env.combatEnemyTokenDefeated(survivor),false,"Survivor after reload")
equal(env.combatEnemyTokenDefeated(partial),false,"Partial boss after reload")
equal(env.combatBossPartialRewardEligible("partial"),true,"Partial result after reload")

-- Without calculator tracking, a physically flipped token remains the
-- normal source of truth: face down survives, face up was defeated.
env.gStates={preEndTurn=true,combatPreEndTurnRecovery={}}
equal(env.combatEnemyTokenDefeated({guid="manualAlive",is_face_down=true}),
    false,"Manual face-down survivor")
equal(env.combatEnemyTokenDefeated({guid="manualDead",is_face_down=false}),
    true,"Manual face-up defeated")

-- Exercise the actual preparation helper with two stable face-up tokens.
-- Neither an enemy's orientation nor a deck should be altered.
local rotations,detachments=0,0
local possessed={guid="possessed",type="Custom_Tile",is_face_down=false,
    getAttachments=function() return {{guid="attached"}} end,
    setRotation=function() rotations=rotations+1 end}
local untouched={guid="survivor",type="Custom_Tile",is_face_down=false,
    getAttachments=function() return {} end,
    setRotation=function() rotations=rotations+1 end}
local importedDeck={guid="externalDeck",type="Deck",is_face_down=false,
    getAttachments=function() error("Unexpected deck was inspected") end,
    takeObject=function(_params) error("Unexpected deck was split") end}
local objects={possessed,untouched,importedDeck}
env.gStates={preEndTurn=true,combatPreEndTurnRecovery={
    defeatResults={possessed=true,survivor=false}
}}
env.turnOrder={{seatPos=1}}
env.deedDeckDiscardZones={[1]="discard"}
env.playerCombatObjects=function() return objects end
env.manaClaimRegisterForTurn=function() end
env.resourceCardsMaximalEffectBeforeEndTurn=function(seat) equal(seat,1,"Throw verdict reconciliation seat") end
env.combatReleaseAllSummonedEnemies=function() return {} end
env.getObjectFromGUID=function(guid)
    if guid=="discard" then return {getObjects=function() return {} end} end
    return nil
end
env.attachEnemy=function(_,_,mode,obj)
    equal(mode,"detachCleanup","Cleanup detach mode")
    equal(obj.guid,"possessed","Only defeated attached monster detaches")
    detachments=detachments+1
end
-- Production's release routine is local to Combat.lua; this isolated test
-- supplies it as an upvalue-compatible local alias.
local prepareCode=slice("local function combatPreEndTurnPreparePlayArea(cleanupPlayer,recovery)",
    "local function combatTrackReturningObject(state,obj)")
prepareCode="local combatReleaseAllSummonedEnemies = _ENV.combatReleaseAllSummonedEnemies\n"..
    prepareCode.."\nreturn combatPreEndTurnPreparePlayArea"
local prep=assert(load(prepareCode,"cleanup preparation","t",env))()
local destination,settle=prep(1,env.gStates.combatPreEndTurnRecovery)
equal(destination,nil,"No discard destination")
equal(next(settle)~=nil,true,"Defeated possessed separation must settle")
equal(settle.possessed,true,"Attached enemy needs settling")
equal(settle.attached,true,"Detached attachment needs settling")
equal(settle.survivor,nil,"Stable survivor needs no settling")
equal(rotations,0,"Preparation never flips enemy tokens")
equal(detachments,1,"Exactly one defeated enemy detached")

assert(not source:find("combatDefeatFlipUndefeated(",1,true),
    "Cleanup must not reinstate the orientation-flipping workaround")
assert(source:find("if enemyRegistered and not enemyDefeated and not enemyPartial",1,true),
    "Survivors must use the verdict rather than physical orientation")
assert(source:find("elseif playAreaObj.is_face_down==true then",1,true),
    "Only manually flipped survivors should be turned upright on return")
assert(source:find("recovery.defeatResults=defeatResults",1,true),
    "Verdict must be saved for reload during cleanup")
assert(read("src/PlayingGame/Horsemen.lua"):find(
    "combatEnemyTokenDefeated(survivingHorse)",1,true),
    "Surviving Horseman horse must respect calculator")
assert(read("src/PlayingGame/ApocalypseDragon.lua"):find(
    "combatBossPartialRewardEligible(obj.guid)",1,true),
    "Dragon head partial level reduction must remain eligible")

print("Combat verdict-based cleanup regression checks passed")

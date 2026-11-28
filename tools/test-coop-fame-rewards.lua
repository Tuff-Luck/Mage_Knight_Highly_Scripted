-- Co-op Fame/Reputation accounting: the combat handoff is not a reward claim.
-- Run from repository root: lua5.2 tools/test-coop-fame-rewards.lua
local function eq(actual,expected,message)
    assert(actual==expected,message..": expected "..tostring(expected)..", got "..tostring(actual))
end

local function read(path)
    local file=assert(io.open(path,"r"))
    local source=file:read("*a")
    file:close()
    return source
end

-- Use the production accounting functions and reward-display callback. Mock
-- physical TTS markers and the completed-turn reset/transition boundary.
local env=setmetatable({},{__index=_G})
local markers={}
local function marker()
    local pos={0,1,0}
    return {
        isDestroyed=function() return false end,
        getPosition=function() return pos end,
        setPosition=function(value) pos=value end
    }
end
local function hero(name,fame,rep,gain,repGain)
    local f,r=name.."F",name.."R"
    markers[f],markers[r]=marker(),marker()
    return {mage=name,seatPos=name=="Goldyx" and 1 or 2,
        fame=fame,reputation=rep,fameGain=gain,repGain=repGain,
        scoreLoop=0,fameGUID=f,reputationGUID=r}
end
env.turnOrder={hero("Goldyx",29,6,17,3),hero("Tovak",10,-6,7,-3)}
env.gStates={turnNumber=1,preEndTurn=true,coopAssaultPhase="combat",
    coopAssaultType="city",coopRewardIndex=1,coopRewardQueue={},
    positionMageKnight={[5]="Dummy"}}
env.getObjectFromGUID=function(guid) return markers[guid] end
env.log=function() end
env.broadcastToAll=function() end
env.refreshPlayerFameFromShield=function() return true end
local commits={0,0}
env.combatApplyPlayerFameReputationBase=function(index,fameShield,repShield)
    local p=env.turnOrder[index]
    p.fame=p.fame+p.fameGain
    p.reputation=p.reputation+p.repGain
    fameShield.setPosition({p.fame,1,0})
    repShield.setPosition({p.reputation,1,0})
    commits[index]=commits[index]+1
    return true
end
env.eventsOnLoadRawBase=function() return true end
local pendingFrames={}
env.safeWaitFrames=function(_module,callback,_frames)
    pendingFrames[#pendingFrames+1]=callback
end
local function flushFrames()
    local callbacks=pendingFrames
    pendingFrames={}
    for _,callback in ipairs(callbacks) do callback() end
end
env.refreshTactic4HandBonus=function() end
env.rewardClaimSoftLockStart=function() end
env.claimButtonRefresh=function() end
env.mainUIUpdate=function() end
assert(load(read("src/PlayingGame/GameFlow/FameReputation.lua"),"fame accounting","t",env))()
env.applyPlayerFameReputation=env.fameReputationApplyPlayerFameReputation

local combat=read("src/PlayingGame/Combat/Combat.lua")
local first=assert(combat:find("showCoopReward=function()",1,true))
local last=assert(combat:find("coopAssaultAvatarsSettled=function()",first,true))
assert(load(combat:sub(first,last-1),"co-op reward display","t",env))()

local handoffs=0
env.turnEndTurnRawBase=function(_player,_mouseButton,_id,_rewindReady)
    local states=env.gStates
    local index=states.turnNumber
    local p=env.turnOrder[index]
    -- The real Turn reset clears these totals and the commit baseline.
    p.fameGain,p.repGain=0,0
    if states.fameRepCommitted then states.fameRepCommitted[index]=nil end
    states.preEndTurn=false
    handoffs=handoffs+1
    states.turnNumber=2
    return true
end
env.combatAdvanceCoopRewardPhaseBase=function()
    local states=env.gStates
    local entry=states.coopRewardQueue[states.coopRewardIndex]
    local p=env.turnOrder[entry.player]
    p.fameGain,p.repGain=0,0
    states.coopRewardIndex=states.coopRewardIndex+1
    if states.coopRewardQueue[states.coopRewardIndex] then
        env.showCoopReward()
    else
        states.coopAssaultPhase=nil
        states.preEndTurn=false
    end
    return true
end

local function queue(index)
    local p=env.turnOrder[index]
    local q=env.gStates.coopRewardQueue
    q[#q+1]={player=index,fame=p.fameGain,reputation=p.repGain,
        factionRewards={dark=0,elementalist=0,apocalypse=0,council=0}}
end
local function loadGame()
    env.fameReputationOnLoadRaw("",nil)
    flushFrames()
end
local function handoff()
    return env.fameReputationEndTurnRaw({color="White"},"-1","CoopCombatComplete",true)
end

queue(1)
env.gStates.combatPreEndTurnRecovery={}
handoff()
eq(handoffs,0,"cleanup gate still blocks early handoff")
env.gStates.combatPreEndTurnRecovery=nil
loadGame()
eq(commits[1],0,"reload while co-op combat is pending")
eq(handoff(),true,"Goldyx combat handoff")
eq(env.turnOrder[1].fame,29,"Goldyx Fame deferred")
eq(env.turnOrder[1].reputation,6,"Goldyx Reputation deferred")
eq(commits[1],0,"Goldyx no physical commit at handoff")

env.gStates.preEndTurn=true
queue(2)
local missing=markers.TovakF
markers.TovakF=nil
loadGame()
eq(handoff(),true,"missing marker must not block co-op combat handoff")
eq(commits[2],0,"Tovak no physical commit at handoff")
eq(env.turnOrder[2].fame,10,"Tovak Fame deferred")
eq(handoffs,2,"both combat handoffs finished")

env.gStates.coopAssaultPhase="rewards"
env.showCoopReward()
eq(env.turnOrder[1].fame,46,"reported 29 + 17 Fame")
eq(env.turnOrder[1].reputation,7,"upper Reputation cap")
eq(commits[1],1,"Goldyx reward committed exactly once")
loadGame()
eq(commits[1],1,"reloading committed co-op reward does not duplicate it")
eq(env.fameReputationAdvanceCoopRewardPhase(),true,"advance Goldyx rewards")
eq(commits[1],1,"claim does not duplicate Goldyx reward")
eq(commits[2],0,"missing marker prevents Tovak reward commit")
eq(env.fameReputationAdvanceCoopRewardPhase(),false,"missing marker blocks reward advancement")
markers.TovakF=missing
eq(env.fameReputationAdvanceCoopRewardPhase(),true,"restored marker permits reward claim")
eq(env.turnOrder[2].fame,17,"Tovak Fame awarded once")
eq(env.turnOrder[2].reputation,-7,"lower Reputation cap")
eq(commits[2],1,"Tovak reward committed exactly once")

-- Ordinary turn recovery still commits once and reconciles only later deltas.
env.gStates.turnNumber=1
env.gStates.preEndTurn=true
env.turnOrder[1].fameGain=4
env.turnOrder[1].repGain=0
loadGame()
eq(env.turnOrder[1].fame,50,"normal load recovers Fame")
loadGame()
eq(commits[1],2,"normal reload does not duplicate Fame")
env.turnOrder[1].fameGain=6
loadGame()
eq(env.turnOrder[1].fame,52,"post-commit Fame delta applied once")
eq(commits[1],3,"one post-commit adjustment")
eq(handoff(),true,"ordinary completed turn advances")
eq(env.turnOrder[1].fame,52,"ordinary handoff does not duplicate Fame")
print("Co-op Fame/Reputation reward regressions passed")

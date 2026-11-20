-- Selecting ordinary Movement must clear any previous Attack/Block target.
-- Combat Move has a distinct, deliberately chosen role and may auto-target
-- a nearest eligible Cumbersome enemy on the next scan.
-- Run from the repository root: lua5.2 tools/test-card-option-move-targeting.lua
local function read(path)
    local f=assert(io.open(path,"r"))
    local source=f:read("*a")
    f:close()
    return source
end
local function slice(source,first,last)
    local a=assert(source:find(first,1,true),"Missing "..first)
    local b=assert(source:find(last,a+#first,true),"Missing "..last)
    return source:sub(a,b-1)
end

local reader=read("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local arrows=read("src/PlayingGame/AttackAssignments.lua")
local data=read("src/Data.lua")
assert(data:find('resourceKey="pureMagic"',1,true),"Pure Magic mapping missing")
assert(data:find('resourceKey="oneWithTheLand"',1,true),"One with the Land mapping missing")
assert(reader:find("local autoCombatMove=moveOnly and source.move>0 and combatCumbersomeActive",1,true),
    "Combat Move alone must qualify for the new nearest-Cumbersome default")
assert(reader:find("if targetIndex==nil and (autoCombatMove or (not moveOnly and not influenceOnly)) then",1,true),
    "Movement-role Move must not be auto-targeted by the Combat Calculator")
assert(reader:find('if moveAmount>0 and resourceCardsMoveRole(guid,true)=="combat" then',1,true),
    "Movement-role Move must never enter the calculator's auto-target source list")

local forgetCode=slice(reader,
    "local function combatForgetPhysicalSourceTargets(unitGUID)",
    "function resourceCardsCombatAssignmentClick(")
local choiceCode=slice(reader,
    "function resourceCardsChoiceClicked(player,value,id)",
    "-- Regeneration gives Heal and an independent Ready")
local clearCode=slice(arrows,
    "function attackAssignmentsClearForObject(objectOrGUID)",
    "function attackAssignmentsObjectMoved(")

local chosen={}
local expanded={}
local shown={}
local registered={}
local pending={}
local targetState={targets={},explicit={},selected=nil}
local state={turnNumber=1,attackAssignments={}}
local scans={[1]={cards={}}}
local cards={}
local redraws=0
local rescanCount=0
local recordsCleared=0
local rules={
    pureMagic={
        poweredChoices={{key="move",move=7},{key="influence",influence=7},
            {key="block",block=7},{key="attack",attack=7}}},
    oneWithTheLand={
        normalChoices={{move=2},{healing=1},{block=2}}}
}
local zone={getObjects=function()
    local result={}
    for _,card in pairs(cards) do result[#result+1]=card end
    return result
end}
local function categoryOf(choice)
    if type(choice.key)=="string" then return choice.key end
    for key in pairs(choice) do return key end
end
local function choiceFor(guid,options)
    for _,choice in ipairs(options or {}) do
        if categoryOf(choice)==chosen[guid].effect then
            return choice,chosen[guid].effect
        end
    end
    local first=options[1]
    return first,categoryOf(first)
end
local env={
    selectedResourceByGUID=chosen,choiceExpandedByGUID=expanded,
    choiceButtonShown=shown,combatAssignmentState=targetState,
    assignmentRegistry=registered,targetingByPlayer=pending,
    gameCards={},cardResourceDefinitions=rules,
    skillResourceDefinitions={},skillTokens={},
    resourceCardScanBySeat=scans,gStates=state,
    turnOrder={{seatPos=1}},playerPlayAreas={[1]="zone"},
    combatConfig={sourceFields={{key="attack"},{key="block"},
        {key="ranged"},{key="siege"}}},
    resourceCardsPanelOpen=function() return true end,
    resourceCardsMoveRole=function(guid)
        return state.resourceCardMoveRoles and state.resourceCardMoveRoles[guid]
            or "combat"
    end,
    resourceCardsDetailsOpen=function() return true end,
    resourceCardsPlayerCanEdit=function() return true end,
    getObjectFromGUID=function(guid)
        if guid=="zone" then return zone end
        return cards[guid]
    end,
    cardPosture=function() return "upright" end,
    factionRewardForObject=function() return nil end,
    cardCanPlaySideways=function() return false end,
    choiceAvailable=function(options,key)
        for _,option in ipairs(options or {}) do
            if categoryOf(option)==key then return true end
        end
        return false
    end,
    currentChoice=function(guid,_,options) return choiceFor(guid,options) end,
    choiceCategory=categoryOf,
    showChoiceButtons=function() redraws=redraws+1 end,
    queueSeat=function() rescanCount=rescanCount+1 end,
    syncTargetButtons=function() end,
    refreshRenderedLines=function() end,
    resourceCardsSourceChanged=function() rescanCount=rescanCount+1 end,
    persistAssignments=function()
        recordsCleared=recordsCleared+1
        state.attackAssignments={}
        for _,entry in pairs(registered) do
            state.attackAssignments[#state.attackAssignments+1]=entry
        end
    end,
    assignmentKeyMatches=function(entry,wanted)
        return entry==wanted or type(entry)=="string"
            and entry:sub(1,#wanted+1)==wanted.."#"
    end
}
setmetatable(env,{__index=_G})
assert(load(clearCode,"Target clearing","t",env))()
local click=assert(load(forgetCode.."\n"..choiceCode.."\nreturn resourceCardsChoiceClicked",
    "Card choice change","t",env))()

local enemyGUID="994ee9"
local function prepare(guid,resourceKey,options,powered,previous)
    cards[guid]={guid=guid,getGMNotes=function() return "" end}
    env.gameCards[guid]={resourceKey=resourceKey,cardType="Advanced Action"}
    scans[1].cards[guid]={powered=powered,choices=options,
        resources=previous=="attack" and {attack=7} or {block=2}}
    chosen[guid]={effect=previous}
    expanded[guid]="base"
    targetState.targets[guid]=enemyGUID
    targetState.explicit[guid]=false
    registered[guid]={sourceGUID=guid,targetGUID=enemyGUID,resource=previous}
    env.persistAssignments()
end
local function clickMove(guid)
    click({color="Blue"},"-1","ResourceCardChoice_"..guid.."_move")
end

-- Gold-powered Pure Magic: Attack -> Move clears the auto Attack arrow/lock.
local pure="878d89"
prepare(pure,"pureMagic",rules.pureMagic.poweredChoices,true,"attack")
expanded[pure]=nil
clickMove(pure)
assert(registered[pure]~=nil and targetState.targets[pure]==enemyGUID,
    "Opening an option row must never remove an assignment")
assert(chosen[pure].effect=="attack","Opening the option row is not selection")
clickMove(pure)
assert(chosen[pure].effect=="move","Pure Magic Move selection not stored")
assert(registered[pure]==nil and targetState.targets[pure]==nil
    and targetState.explicit[pure]==nil,
    "Pure Magic Attack arrow and calculator lock must disappear on selecting Move")
assert(#state.attackAssignments==0,
    "Removed Pure Magic target must also disappear from saved assignments")

-- The same gold-powered Pure Magic must drop its old Block target too.
prepare(pure,"pureMagic",rules.pureMagic.poweredChoices,true,"block")
clickMove(pure)
assert(registered[pure]==nil and targetState.targets[pure]==nil
    and targetState.explicit[pure]==nil,
    "Pure Magic Block arrow and calculator lock must disappear on selecting Move")

-- Another card with a Move alternative must obey the same rule; dependent
-- split keys must be cleared without deleting other cards' assignments.
local other="c137e0"
prepare(other,"oneWithTheLand",rules.oneWithTheLand.normalChoices,false,"block")
registered["split"]={sourceGUID=other.."#block",targetGUID=enemyGUID,resource="block"}
registered["unrelated"]={sourceGUID="abc123",targetGUID=enemyGUID,resource="attack"}
targetState.targets[other.."#block"]=enemyGUID
targetState.explicit[other.."#block"]=true
clickMove(other)
assert(chosen[other].effect=="move","One with the Land Move selection not stored")
assert(registered[other]==nil and registered.split==nil
    and targetState.targets[other]==nil and targetState.targets[other.."#block"]==nil,
    "Other Move cards must clear both ordinary and split target locks")
assert(registered.unrelated~=nil,"Other cards' targets must be preserved")

-- Re-selecting Move after the player has deliberately targeted Cumbersome
-- must NOT silently remove that manual target.
registered.manual={sourceGUID=other,targetGUID=enemyGUID,resource="move"}
targetState.targets[other]=enemyGUID
targetState.explicit[other]=true
expanded[other]="base"
clickMove(other)
assert(registered.manual~=nil and targetState.targets[other]==enemyGUID
    and targetState.explicit[other]==true,
    "Selecting an already-active Move choice must preserve manual targeting")
assert(rescanCount>0 and redraws>0 and recordsCleared>0,
    "Changing Move choices should update the card and calculator")
-- A queued/stale target button cannot clear a Block source that has
-- already been committed by the Damage phase.
local lockedArrow={id="lock",sourceGUID="cafe01",targetGUID=enemyGUID}
local lockedRegistry={lock=lockedArrow}
local mutations=0
local lockedEnv={
    assignmentRegistry=lockedRegistry,
    Player={Red={}},
    safeCallback=function(_,fn) return fn() end,
    resourceCardsPlayerCanEdit=function() return true end,
    resourceCardsPanelOpen=function() return true end,
    getObjectFromGUID=function() return {guid="cafe01"} end,
    combatCommittedSource=function(key) return key=="cafe01" end,
    persistAssignments=function() mutations=mutations+1 end,
    resourceCardsCombatForgetSource=function() mutations=mutations+1 end,
    attackAssignmentsBegin=function() mutations=mutations+1 end,
    resourceCardsSourceChanged=function() mutations=mutations+1 end
}
setmetatable(lockedEnv,{__index=_G})
local lockedClick=assert(load(slice(arrows,
    "function attackAssignmentSourceClicked(player,value,id)",
    "-- The Ambush button is reusable")..
    "\nreturn attackAssignmentSourceClicked","Committed targeting guard","t",lockedEnv))()
lockedClick({color="Red"},"-1","AttackAssignmentSource_cafe01_0_block")
assert(lockedRegistry.lock==lockedArrow and mutations==0,
    "A locked combat source must not lose its arrow or calculator assignment")

print("Generic Move-option targeting regression passed")

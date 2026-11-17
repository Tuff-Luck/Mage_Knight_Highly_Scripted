-- Regression coverage for Volkare's partial attendance and Pursuit combat.
-- Exercise the real scenario callbacks with a calculator-aware defeat-state stub.
-- Run from repository root: lua5.2 tools/test-volkare-combat-defeats.lua

local function eq(actual,expected,label)
    assert(actual==expected,(label or "Mismatch")..": expected "..tostring(expected)
        ..", got "..tostring(actual))
end

publishPublicUICallbacks=function() end
dofile("src/PlayingGame/AI/Volkare.lua")
dofile("src/PlayingGame/LLScenario.lua")

volkare={model="testVolkare"}
trashCan="trash"
playerPlayAreas={[1]="playzone"}
turnOrder={{mage="Tester",seatPos=1}}
mageKnightsByName={Tester={shieldContainer="shieldBag"}}
UI={setAttribute=function() end}
setUIButtonEnabled=function() end
mainUIUpdate=function() end
joinLang=function() return "" end
positionToColor=function() return "White" end
broadcastToAll=function() end
safeWaitTime=function() end -- Pursuit only schedules cosmetic shield locking.
translateWord={Tester="Tester"}
local playObjects,shieldCount={},0
local shieldBag={takeObject=function()
    shieldCount=shieldCount+1
    return {guid="shield"..shieldCount,setGMNotes=function() end}
end}
getObjectFromGUID=function(guid)
    if guid=="playzone" then return {getObjects=function() return playObjects end} end
    if guid=="shieldBag" then return shieldBag end
    return nil
end
playerCombatObjects=function(seat)
    eq(seat,1,"Pursuit uses the attacked player's combat area")
    return playObjects
end

local calculatorActive,defeatMarks=true,{}
-- The Combat service owns the actual implementation; test that both callers
-- honor its verdict rather than reinterpreting the visible token orientation.
combatEnemyTokenDefeated=function(obj)
    if calculatorActive then return defeatMarks[obj.guid]==true end
    return obj.is_face_down~=true
end

local function enemy(guid,faceDown)
    local token={guid=guid,is_face_down=faceDown,returns=0,rotations=0}
    token.getGMNotes=function() return "" end
    token.setPositionSmooth=function()
        token.returns=token.returns+1
    end
    token.setRotationSmooth=function()
        token.rotations=token.rotations+1
    end
    return token
end

local function partialCase(label,calcOn,survivorFaceDown,killedFaceDown,marks,
    survivorDead,killedDead)
    local survivor=enemy("survivor",survivorFaceDown)
    local killed=enemy("killed",killedFaceDown)
    calculatorActive,defeatMarks=calcOn,marks
    playObjects={survivor,killed}
    monsterPugs={survivor={},killed={}}
    gStates={
        positionMageKnight={[5]="Volkare"},tacticShown=false,endRoundCalled=false,
        volkareState="Attacking Player",gameScenario="Volkare's Return",
        volkareAttacked={{mage="Tester"}},
        volkareMovementStepPending=true,volkareMovementPaused=true,
        cityMonsterQty={[volkare.model]={survivor="alive",killed="alive"}},
        monsterPlayLocation={survivor={10,2,0},killed={11,2,0}}
    }
    volkareTurn(nil,"-1","VolkareAttackedPartial")
    eq(gStates.cityMonsterQty[volkare.model].survivor,survivorDead and "dead" or "alive",
        label.." survivor army state")
    eq(gStates.cityMonsterQty[volkare.model].killed,killedDead and "dead" or "alive",
        label.." second enemy army state")
    eq(survivor.returns,survivorDead and 0 or 1,label.." survivor returned")
    eq(killed.returns,killedDead and 0 or 1,label.." second enemy returned")
    eq(survivor.rotations,survivor.returns,label.." survivor rotation")
    eq(killed.rotations,killed.returns,label.." second enemy rotation")
    eq(gStates.volkareState,"Moving",label.." resumes suspended second step")
end

-- While the calculator is open, both tokens can be face up even though only one is killed.
partialCase("Calculator mixed defeat",true,false,false,{killed=true},false,true)
partialCase("Calculator no defeats",true,false,false,{},false,false)
partialCase("Calculator both defeated",true,false,false,{survivor=true,killed=true},true,true)
-- Outside the calculator, preserve the legacy face-down survivor/face-up kill convention.
partialCase("Manual combat",false,true,false,{},false,true)

local function pursuitCase(label,calcOn,objects,marks,registered,expectedShields)
    calculatorActive,defeatMarks=calcOn,marks
    playObjects=objects
    shieldCount=0
    gStates={
        volkarePursuitCombat={
            player=1,hexKey="tile|0",position={10,2,0},monsters=registered
        },
        volkarePursuitChoicePlayer=1,
        volkarePursuitShields={}
    }
    volkarePursuitResolveCombat(1)
    eq(shieldCount,expectedShields,label.." award count")
    eq(gStates.volkarePursuitCombat,nil,label.." combat cleared")
    eq(gStates.volkarePursuitChoicePlayer,nil,label.." choice cleared")
end

local faceUp=enemy("target",false)
local faceDown=enemy("target",true)
pursuitCase("Calculator face-up survivor",true,{faceUp},{},{target=true},0)
pursuitCase("Calculator marked defeat",true,{faceUp},{target=true},{target=true},1)
pursuitCase("Manual face-down survivor",false,{faceDown},{},{target=true},0)
pursuitCase("Manual face-up defeat",false,{faceUp},{},{target=true},1)
pursuitCase("Unrelated defeated token",true,{faceUp},{target=true},{elsewhere=true},0)
pursuitCase("Mixed calculator enemies",true,{enemy("survivor",false),faceUp},
    {target=true},{survivor=true,target=true},1)

print("Volkare combat defeat integration regression checks passed")

-- Actual observation and payment passes: shallow-zone membership is authoritative.
local root="src/PlayingGame/PlayerBoard/ResourceTracker/"
local function eq(a,b,label) assert(a==b,label..": expected "..tostring(b)..", got "..tostring(a)) end
local card={guid="card",kind="card"}
local outsideCard={guid="remembered",kind="card"}
local mana={guid="mana",kind="mana",color="Red"}
local outsideMana={guid="outside",kind="mana",color="Red"}
local inventory={guid="inventory",kind="mana",color="Blue"}
local held={guid="held",kind="mana",color="Red",held_by_color="Blue"}
local unit={guid="unit",kind="unit"}
local zones={
    play={getObjects=function() return {card,mana,held} end},
    unitArea={getObjects=function() return {card} end},
    inventoryArea={getObjects=function() return {inventory} end}
}
local objects={card=card,remembered=outsideCard,mana=mana,outside=outsideMana,inventory=inventory,
    held=held,unit=unit,play=zones.play,unitArea=zones.unitArea,inventoryArea=zones.inventoryArea}
local env=setmetatable({
    gStates={unitResourceActivations={unit={seatPos=1}}},
    playerPlayAreas={"play"},playerUnitAreas={"unitArea"},playerCrystalAreas={"inventoryArea"},
    monsterPugs={},gameCards={card={cardType="Starting",resourceKey="rage"},remembered={cardType="Starting",resourceKey="rage"}},
    cardResourceDefinitions={rage={}},
    getObjectFromGUID=function(guid) return objects[guid] end,
    unitLayoutSnapshot=function(seat) return {units={unit}} end,
    isManaTokenFigurine=function(obj) return obj.kind=="mana" end,
    manaTokenColor=function(obj) return obj.color end,
    resourceCardsGoldAllowed=function() return true end,
    resourceCardsBlackAllowed=function() return false end,
    resourceCardsMaximalEffectSyncMarks=function(seat,cards,repeats,discarded,hasDiscard) end
},{__index=_G})
local tracker={playCandidatesBySeat={[1]={remembered=true,outside=true}},
    playCandidateKind=function(kind) return kind=="card" end,
    readyForXZ=function(obj) return obj.held_by_color==nil end,
    cardOverPlayMat=function(obj,seat) return true end,
    bannerCardForm=function(guid) return nil end,
    bestManaCard=function(mana,cards,footprints,eligible)
        for _,c in ipairs(cards) do if eligible(c) then return c end end
    end}
local obs=assert(loadfile(root.."Scanning/ScanObservation.lua","t",env))()
local seen,placements,monsters,playMonsters,combatMonsters,enemyEntries,counts,cards,wounds,skills,
    manaObjects,footprints,unitPaymentMana=obs.observe({
    seatPos=1,trackerPrivate=tracker,combatConfig={cardInTransit=function(obj) return false end},
    combatEnemyData=function(guid,obj) return nil end,resourceObjectKind=function(obj) return obj.kind end,
    combatKeepHeldEnemies=function(seat,monsters,play) end,
    resourceCardsCombatNightFromEnemies=function(monsters) return false end,
    combatCalcUpdate=function(monsters) end,footprint=function(obj) return {} end
})
eq(placements.card,"play","Play placement wins overlapping zones")
eq(placements.remembered,"play","Known released card recovered")
eq(seen.outside,nil,"Outside-zone mana never recovered")
eq(seen.held,nil,"Held mana never counted")
eq(placements.unit,"unit","Previously activated Unit recovered")
eq(counts.Blue,1,"Inventory crystal counted")
eq(#unitPaymentMana,1,"Only settled play/Unit mana can pay Unit")
eq(unitPaymentMana[1],mana,"Live play mana is the candidate")
local pay=assert(loadfile(root.."Scanning/ScanPayments.lua","t",env))()
local byObject,bySkill,byCard,skillTargets,skillLinks,sideways,powered,used=pay.resolve({
    seatPos=1,cards=cards,wounds=wounds,skills=skills,manaObjects=manaObjects,footprints=footprints,
    placements=placements,trackerPrivate=tracker,resolveManaSkillLinks=function() return {},{},{} end,
    resolveSkillCardLinks=function() return {},{},{} end,cardPosture=function(obj) return "upright" end,
    matchesCardMana=function(obj,color) return obj.guid=="card" and color=="Red" end,
    manaColor=function(obj) return obj.color end,resolveActionLinks=function() return {},{},{},{},{},{},{},{} end
})
eq(powered.card,true,"Physical matching mana powers played card")
eq(used.mana,"card","Single mana payment assigned")
eq(used.inventory,nil,"Inventory crystal not spent")
eq(used.outside,nil,"Outside-zone mana not spent")
eq(used.held,nil,"Held mana not spent")
eq(env.gStates.resourceCardPlayOrder.card,env.gStates.resourceCardPlayOrder.remembered,
    "Already-present cards share an ordinal")
print("Scan observation and mana coordination regressions passed")

-- Direct Maximal Effect + Pure Magic: face-down target accepts only
-- additional effect mana not already assigned to another source.
package.path="src/?.lua;"..package.path
local realMana=require("PlayingGame.PlayerBoard.ResourceTracker.Scanning.ManaPayments")
local realLinks=assert(loadfile(root.."Cards/ActionLinks.lua","t",env))()({
    overlapArea=function(a,b)
        if a==b then return 1 end
        return a.pair~=nil and a.pair==b.pair and 1 or 0
    end,
    cardPosture=function(obj) return obj.posture or "upright" end,
    linkedColorChoices=function(_rule,_guid,_powered) return nil end,
    canPayDiscard=function(_obj) return false end,
    resourceCardsArtifactBroken=function(_guid,_obj) return false end
})
local source={guid="maximal",getPosition=function() return {0,1.2,0} end}
local pure={guid="pure",is_face_down=true,getPosition=function() return {2,1,0} end}
local function token(guid,color,x)
    return {guid=guid,color=color,getPosition=function() return {x,1.5,0} end}
end
local power=token("power","Blue",0)
local red1=token("red1","Red",2)
local red2=token("red2","Red",2)
local red3=token("red3","Red",2)
local blue1=token("blue1","Blue",2)
local blue2=token("blue2","Blue",2)
local blue3=token("blue3","Blue",2)
env.gameCards.maximal={cardType="Advanced Action",resourceKey="maximalEffect",color={"Blue"}}
env.gameCards.pure={cardType="Advanced Action",resourceKey="pureMagic",color={"Blue"}}
env.cardResourceDefinitions.maximalEffect={requiredLink={mode="repeat",normalCount=3,poweredCount=2}}
env.cardResourceDefinitions.pureMagic={effectManaChoice={powerColor="Blue",colors={Red="attack",Blue="block"}}}
tracker.bestManaCard=realMana.bestManaCard
local function repeatedScan(items)
    local placed={}
    for _,obj in ipairs(items) do placed[obj.guid]="play" end
    local _,_,_,_,_,_,poweredMap,usedMap,_,_,effectPayments,_,_,_,discardMap,_,_,repeats=pay.resolve({
        seatPos=1,cards={source,pure},wounds={},skills={},manaObjects=items,
        footprints={maximal={x=0,z=0,halfX=1.4,halfZ=1,pair="pair"},
            pure={x=2,z=0,halfX=1.4,halfZ=1,pair="pair"}},
        placements=placed,trackerPrivate=tracker,
        resolveManaSkillLinks=function() return {},{},{} end,
        resolveSkillCardLinks=function() return {},{},{} end,
        cardPosture=function(obj) return obj.posture or "upright" end,
        matchesCardMana=function(_obj,color) return color=="Blue" end,
        manaColor=function(obj) return obj.color end,
        effectManaPossibilities=realMana.effectManaPossibilities,
        resolveActionLinks=realLinks
    })
    return poweredMap,usedMap,effectPayments,discardMap,repeats
end
local powers,usedTokens,effectPayments,discardMap,repeats=repeatedScan({power,red1,red2})
eq(repeats.pure.count,2,"Power on Maximal Effect supplies two stronger uses")
eq(repeats.pure.powered,true,"Strong repeat")
eq(usedTokens.power,"maximal","Source power stays reserved")
eq(usedTokens.red1,"pure","Face-down target accepts effect mana")
eq(usedTokens.red2,"pure","Second effect mana assigned separately")
eq(#effectPayments.pure,2,"Only target payments included")
eq(discardMap.pure,"maximal","Ordinary repeat target remains throw-away")
eq(powers.pure,nil,"Effect payment never becomes ordinary target power")
powers,usedTokens,effectPayments,discardMap,repeats=repeatedScan({red1,red2,red3})
eq(repeats.pure.count,3,"Unpowered Maximal Effect supplies three basic uses")
eq(#effectPayments.pure,3,"Three independent basic costs")
pure.is_face_down=false
powers,usedTokens,effectPayments,discardMap,repeats=repeatedScan({blue1,blue2,blue3})
eq(repeats.pure.count,3,"Face-up paid target still eligible for basic repetition")
eq(#effectPayments.pure,3,"All Blue mana are effect selections, not power")
eq(powers.pure,nil,"Target power is superseded by repeat")
print("Direct repeated effect mana scan regressions passed")

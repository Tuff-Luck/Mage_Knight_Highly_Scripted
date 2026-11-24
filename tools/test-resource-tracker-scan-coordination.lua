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
local obs=assert(loadfile(root.."ScanObservation.lua","t",env))()
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
local pay=assert(loadfile(root.."ScanPayments.lua","t",env))()
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

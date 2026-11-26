-- Regression: Ambush has one reusable target button but two independent links:
-- Move to a Cumbersome enemy and an Attack/Block bonus to a played card.
-- Run from repository root: lua5.2 tools/test-ambush-dual-target.lua
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
local reader=read("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local arrows=read("src/PlayingGame/Combat/AttackAssignments.lua")
local data=read("src/Data.lua")
assert(data:find("ambush={normal={move=2},powered={move=4}",1,true))
assert(data:find("combatLink={normal={attack=1,block=2},powered={attack=2,block=4}}",1,true))
assert(read("src/PlayingGame/PlayerBoard/ResourceTracker/Interface/CardControlOptions.lua"):find('return "ambush" end',1,true),
    "Ambush must use the shared card/enemy target control")
assert(read("src/PlayingGame/PlayerBoard/ResourceTracker/Interface/CardControls.lua"):find('global/attackAssignmentAmbushSourceClicked',1,true),
    "Ambush target button must use the dual-target callback")
local ambushLines=section(arrows,"-- Ambush's card buff is independent", "for key,guids in pairs(damageTargets) do")
assert(ambushLines:find('appendStatic(sourceGUID,targetGUID,assignmentColors.other)',1,true),
    "The separate card bonus must draw a purple arrow")
assert(arrows:find('for sourceGUID,targetGUID in pairs(gStates~=nil and gStates.ambushCombatLinks or {})',1,true),
    "The saved bonus must survive independent enemy-target changes")
assert(arrows:find('if resourceCardsPanelOpen~=nil and resourceCardsPanelOpen() then\n        for sourceGUID,targetGUID in pairs(gStates~=nil and gStates.ambushCombatLinks or {}) do',1,true),
    "Ambush's purple arrow must use the exported tracker visibility API")
local postureDeclaration=assert(reader:find('local cardPosture=require(',1,true))
local ambushDeclaration=assert(reader:find('combatConfig.ambushEligibleTarget=',1,true))
assert(postureDeclaration<ambushDeclaration,
    "Ambush must bind to the local posture helper declared before its callbacks")

local sourceGUID,attackGUID,blockGUID,enemyGUID="20cb85","a1b2c3","d4e5f6","ee1200"
local source={guid=sourceGUID,posture="upright",is_face_down=false,
    isDestroyed=function() return false end,
    getRotation=function() return {0,0,0} end}
local attack={guid=attackGUID,posture="upright",is_face_down=false,
    isDestroyed=function() return false end,
    getRotation=function() return {0,0,0} end}
local block={guid=blockGUID,posture="upright",is_face_down=false,
    isDestroyed=function() return false end,
    getRotation=function() return {0,0,0} end}
local enemy={guid=enemyGUID,posture="upright",is_face_down=false,
    isDestroyed=function() return false end,
    getRotation=function() return {0,0,0} end}
local objects={[sourceGUID]=source,[attackGUID]=attack,[blockGUID]=block,[enemyGUID]=enemy}
local cards={[sourceGUID]={resourceKey="ambush",cardType="Advanced Action"},
    [attackGUID]={cardType="Starting"},[blockGUID]={cardType="Advanced Action"}}
local rule={ambush={combatLink={normal={attack=1,block=2},
    powered={attack=2,block=4}}}}
local sourceRecord={complete=true,resources={move=2},powered=false,links={}}
local attackRecord={complete=true,resources={attack=3},powered=false,links={}}
local blockRecord={complete=true,resources={block=4},powered=false,links={}}
local records={[sourceGUID]=sourceRecord,[attackGUID]=attackRecord,[blockGUID]=blockRecord}
local gStates={turnNumber=1,ambushCombatLinks={}}
local env={
    combatConfig={},gameCards=cards,cardResourceDefinitions=rule,gStates=gStates,
    turnOrder={{seatPos=1}},resourceCardScanBySeat={[1]={cards=records}},
    getObjectFromGUID=function(guid) return objects[guid] end,
    resourceCardsPanelOpen=function() return true end,
    resourceCardsDetailsOpen=function() return true end,
    setHighlight=function() end
}
setmetatable(env,{__index=_G})
env.trackerPrivate={combatTargetPolicy=assert(loadfile("src/PlayingGame/PlayerBoard/ResourceTracker/Combat/CombatTargetPolicy.lua","t",env))()}
package.path="src/?.lua;"..package.path
local helpers=section(reader,'local cardPosture=require("PlayingGame.PlayerBoard.ResourceTracker.Scanning.PhysicalObjects").cardPosture',
    "-- Paging changes visible rows")
assert(load(helpers,"Ambush candidate eligibility","t",env))()
assert(env.cardPosture==nil,
    "Ambush must work through the local posture helper, not a global mock")
local targetCards=env.resourceCardsAmbushLinkTargets(sourceGUID)
assert(targetCards[attackGUID]==attack and targetCards[blockGUID]==block,
    "Remote Attack and Block cards must be selectable regardless of overlap")
assert(targetCards[sourceGUID]==nil and targetCards[enemyGUID]==nil,
    "Ambush cannot buff itself or a monster token")
block.is_face_down=true
assert(env.resourceCardsAmbushLinkTargets(sourceGUID)[blockGUID]==nil,
    "Face-down cards must not be valid bonus targets")
block.is_face_down=false

-- Resolve the actual buff code with a saved remote link and a physically
-- overlapping DIFFERENT card. Explicit assignment must win.
local calculate=section(read("src/PlayingGame/PlayerBoard/ResourceTracker/Cards/CrossCardEffects.lua"),
    "    -- Ambush's explicit card assignment takes priority over physical overlap.",
    "    -- Retire stale manual links when Ambush itself is no longer")
local calcEnv=setmetatable({
    cards={source,attack,block},records=records,gameCards=cards,
    cardResourceDefinitions=rule,combatConfig=env.combatConfig,
    gStates=gStates,discarded={},repeatByTarget={},
    footprints={[sourceGUID]={id=sourceGUID},[attackGUID]={id=attackGUID},
        [blockGUID]={id=blockGUID}},
    overlapArea=function(a,b)
        return a.id==sourceGUID and b.id==blockGUID and 10 or 0
    end,
    cardPosture=function(card) return card.posture end,
    getObjectFromGUID=env.getObjectFromGUID,
    setHighlight=function() end,
    resourceOps=require("PlayingGame.PlayerBoard.ResourceTracker.Core.ResourceOperations"),
    highlightPolicy=require("PlayingGame.PlayerBoard.ResourceTracker.Core.HighlightPolicy"),
    physicalLinks=require("PlayingGame.PlayerBoard.ResourceTracker.Core.PhysicalLinks")
},{__index=env})
local function calculateWith(sourcePowered,targetGUID,targetFamily)
    sourceRecord.powered=sourcePowered
    sourceRecord.resources={move=sourcePowered and 4 or 2}
    sourceRecord.links={}
    attackRecord.resources={attack=targetFamily=="attack" and 3 or 0}
    attackRecord.links={}
    blockRecord.resources={block=targetFamily=="block" and 4 or 0}
    blockRecord.links={}
    gStates.ambushCombatLinks[sourceGUID]=targetGUID
    calcEnv.totals={}
    assert(load(calculate,"Ambush resolved bonus","t",calcEnv))()
end
calculateWith(false,attackGUID,"attack")
assert(attackRecord.resources.attack==4 and blockRecord.resources.block==0,
    "Normal Ambush must grant +1 Attack to the remote target only")
assert(sourceRecord.resources.move==2,"Attack buff must leave Move available")
calculateWith(true,attackGUID,"attack")
assert(attackRecord.resources.attack==5 and sourceRecord.resources.move==4,
    "Powered Ambush must grant +2 Attack independently of Move 4")
calculateWith(false,blockGUID,"block")
assert(blockRecord.resources.block==6,
    "Normal Ambush must grant +2 Block")
calculateWith(true,blockGUID,"block")
assert(blockRecord.resources.block==8,
    "Powered Ambush must grant +4 Block")

-- A physical tie must not choose an arbitrary card; an explicit target wins.
calcEnv.overlapArea=function() return 10 end
sourceRecord.powered=false
sourceRecord.resources={move=2}
sourceRecord.links={}
attackRecord.resources={attack=3}
blockRecord.resources={block=4}
attackRecord.links={}
blockRecord.links={}
gStates.ambushCombatLinks={}
calcEnv.totals={attack=3,block=4}
assert(load(calculate,"Ambush ambiguous physical link","t",calcEnv))()
assert(attackRecord.resources.attack==3 and blockRecord.resources.block==4,
    "Equal physical overlap must not assign a bonus")
gStates.ambushCombatLinks[sourceGUID]=attackGUID
assert(load(calculate,"Ambush explicit target on tie","t",calcEnv))()
assert(attackRecord.resources.attack==4 and blockRecord.resources.block==4,
    "An explicit target must win even on equal overlap")

-- Exercise the real targeting callbacks (with only TTS boundary calls stubbed).
sourceRecord.powered=false
sourceRecord.resources={move=2}
attackRecord.resources={attack=3}
blockRecord.resources={block=4}
gStates.ambushCombatLinks={}
local assignments,pending={},{}
local combatLocks={}
local changeCount=0
local actionEnv=setmetatable({
    assignmentRegistry=assignments,targetingByPlayer=pending,
    blockLinkPending={},assignmentBaseGUID=function(key)
        return type(key)=="string" and key:match("^[^#]+") or key
    end,
    assignmentCounter=0,gStates=gStates,gameCards=cards,
    cardResourceDefinitions=rule,Player={Blue={}},
    resourceCardsPlayerCanEdit=function(color) return color=="Blue" end,
    resourceCardsPanelOpen=function() return true end,
    resourceCardsAmbushSourceActive=env.resourceCardsAmbushSourceActive,
    resourceCardsAmbushCombatMoveActive=function(guid) return guid==sourceGUID end,
    resourceCardsAmbushLinkTargets=env.resourceCardsAmbushLinkTargets,
    resourceCardsCombatTargetObjects=function() return {[enemyGUID]=enemy} end,
    resourceCardsCombatTargetAcceptsMove=function(guid) return guid==enemyGUID end,
    resourceCardsCombatTargetAcceptsSource=function() return true end,
    resourceCardsCombatAssignSource=function(guid,target)
        combatLocks[guid]=target
        changeCount=changeCount+1 -- The real calculator also reschedules its scan.
    end,
    attackAssignmentsKindFor=function() return "other" end,
    getObjectFromGUID=env.getObjectFromGUID,
    safeCallback=function(_,fn) return fn() end,
    syncTargetButtons=function() end,refreshRenderedLines=function() end,
    scheduleRefresh=function() end,persistAssignments=function() end,
    resourceCardsSourceChanged=function() changeCount=changeCount+1 end
},{__index=env})
local callbacks=section(arrows,"function attackAssignmentsBegin(",
    "-- Explicitly link Spirit Guides")
assert(load(callbacks,"Ambush targeting callbacks","t",actionEnv))()
local player={color="Blue"}
local id="AttackAssignmentSource_"..sourceGUID.."_0_ambush"
actionEnv.attackAssignmentAmbushSourceClicked(player,"-1",id)
assert(pending.Blue~=nil and pending.Blue.resource=="ambush")
actionEnv.attackAssignmentTargetClicked(attack,"Blue")
assert(gStates.ambushCombatLinks[sourceGUID]==attackGUID
    and next(assignments)==nil,
    "Choosing a card must not create an enemy assignment")
actionEnv.attackAssignmentAmbushSourceClicked(player,"-1",id)
actionEnv.attackAssignmentTargetClicked(enemy,"Blue")
assert(gStates.ambushCombatLinks[sourceGUID]==attackGUID,
    "Choosing a Cumbersome enemy must preserve the card bonus")
assert(combatLocks[sourceGUID]==enemyGUID,
    "The Move target must enter the ordinary combat calculator")
local enemyLink
for _,entry in pairs(assignments) do enemyLink=entry end
assert(enemyLink~=nil and enemyLink.targetGUID==enemyGUID
    and enemyLink.kind=="other" and enemyLink.resource=="move",
    "Move must receive its own purple arrow and normal resource key")
actionEnv.attackAssignmentAmbushSourceClicked(player,"-1",id)
actionEnv.attackAssignmentTargetClicked(block,"Blue")
assert(gStates.ambushCombatLinks[sourceGUID]==blockGUID
    and combatLocks[sourceGUID]==enemyGUID,
    "Retargeting the card buff must leave Move targeting intact")
assert(next(assignments)~=nil and changeCount>=3,
    "Both links must remain active and refresh the calculator")
print("Ambush independent card buff and Cumbersome Move targeting passed")

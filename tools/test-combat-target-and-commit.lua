-- Regression coverage for multi-target permissions and Damage confirmation fingerprints.
-- Run from repository root: lua5.2 tools/test-combat-target-and-commit.lua
local function read(path)
    local file=assert(io.open(path,"r"))
    local result=file:read("*a")
    file:close()
    return result
end
local function isolate(source,first,last,env)
    local a=assert(source:find(first,1,true),"Missing start: "..first)
    local b=assert(source:find(last,a+#first,true),"Missing end: "..last)
    setmetatable(env,{__index=_G})
    assert(load(source:sub(a,b-1),"combat regression","t",env))()
end
local function eq(a,b,label)
    assert(a==b,(label or "Mismatch")..": expected "..tostring(b)..", got "..tostring(a))
end
local function differs(a,b,label)
    assert(a~=b,label or "Expected a different fingerprint")
end

local recognition=read("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local assignments=read("src/PlayingGame/AttackAssignments.lua")

-- The authoritative source capability check must distinguish one-target cards,
-- point pools, and explicitly multi-enemy effects.
local sources={}
local scan={cards={}}
local r={
    resourceCardScanBySeat={[1]=scan},gameCards={},cardResourceDefinitions={},
    combatAssignmentState={targets={}},
    combatAssignmentActiveSeat=function() return 1 end,
    combatAssignmentSources=function() return sources end,
    sideChoices=function() return {{key="other"}} end,
    currentChoice=function() return nil,"other" end,
    combatEffectSpec=function(rule,powered)
        return powered and rule.enemyEffect.powered or rule.enemyEffect.normal
    end,
}
isolate(recognition,"function resourceCardsCombatAdditionalTargetLimit(sourceKey)",
    "-- Every Maximal Effect application",r)

eq(r.resourceCardsCombatAdditionalTargetLimit("ordinary"),1,"Ordinary source")
sources={{key="ordinary",attack=4,convertedAmount=nil,psychicInfluence=0}}
eq(r.resourceCardsCombatAdditionalTargetLimit("ordinary"),1,"Attack stays single target")
sources={{key="converted#attack",convertedAmount=3,psychicInfluence=0}}
local points,mode=r.resourceCardsCombatAdditionalTargetLimit("converted#attack")
eq(points,3,"Converted point pool")
eq(mode,"points","Converted allocation mode")
sources={{key="psychic",psychicInfluence=4}}
points,mode=r.resourceCardsCombatAdditionalTargetLimit("psychic")
eq(points,4,"Psychic Influence points")
eq(mode,"influence","Influence allocation mode")

sources={}
r.gameCards.fear={resourceKey="fear"}
r.cardResourceDefinitions.fear={enemyEffect={powered={choice="other",maxTargets=3}}}
scan.cards.fear={complete=true,powered=true,enemyEffectTargetKeys={"fear"}}
points,mode=r.resourceCardsCombatAdditionalTargetLimit("fear")
eq(points,3,"Banner of Fear targets")
eq(mode,"targets","Banner target allocation")
r.gameCards.wings={resourceKey="wings"}
r.cardResourceDefinitions.wings={enemyEffect={powered={multiTargetMove=true}}}
scan.cards.wings={complete=true,powered=true,enemyEffectTargetKeys={"wings"}}
points,mode=r.resourceCardsCombatAdditionalTargetLimit("wings")
eq(points,math.huge,"Wings of Night permits multiple targets")
eq(mode,"move","Wings allocation mode")
scan.cards.fear.powered=false
eq(r.resourceCardsCombatAdditionalTargetLimit("fear"),1,"Unpowered Banner cannot split")
r.combatAssignmentState.targets.ordinary="monsterA"
eq(r.resourceCardsCombatPrimaryTarget("ordinary"),"monsterA","Primary target accessor")

-- A second arrow from an ordinary source must be rejected before the
-- targeting UI is entered. A genuine multi-target source can enter it.
local maxTargets=1
local announcements={}
local a={
    targetingByPlayer={},Player={Blue={}},
    resourceCardsPlayerCanEdit=function() return true end,
    resourceCardsPanelOpen=function() return true end,
    combatCommittedSource=function() return false end,
    resourceCardsCombatAdditionalTargetLimit=function() return maxTargets end,
    attackAssignmentsKindFor=function() return "armour" end,
    broadcastToColor=function(message) announcements[#announcements+1]=message end,
    syncTargetButtons=function() end,
    refreshRenderedLines=function() end,
    scheduleRefresh=function() end,
}
isolate(assignments,"function attackAssignmentsBegin(",
    "function attackAssignmentSourceClicked(",a)
local source={guid="ordinary",isDestroyed=function() return false end}
eq(a.attackAssignmentsBegin(source,"attack","Blue",true,"ordinary"),false,
    "No extra arrows for ordinary Attack")
eq(a.targetingByPlayer.Blue,nil,"No misleading targeting state")
eq(#announcements,1,"Rejected action explains why")
maxTargets=3
eq(a.attackAssignmentsBegin(source,"attack","Blue",true,"ordinary"),true,
    "Explicit multi-target permission")
eq(a.targetingByPlayer.Blue.additional,true,"Multi-target mode is retained")

-- Two damage allocations can produce identical Wound counts but affect
-- different Units. Confirmation must detect that exact decision change.
local c={
    combatConfig={},combatAssignmentState={targets={},explicit={}},
    combatReductionAttackChoice={},
    gStates={turnNumber=1,attackAssignments={}}
}
isolate(recognition,"combatConfig.decisionFingerprint=function",
    "-- A Damage commit is a deliberate phase boundary",c)
isolate(recognition,"combatConfig.woundCommitSignature=function",
    "combatConfig.woundConfirmClose=function",c)
local f1=c.combatConfig.decisionFingerprint({b=2,a={x=1,y=2}})
local f2=c.combatConfig.decisionFingerprint({a={y=2,x=1},b=2})
eq(f1,f2,"Fingerprint independent of table insertion order")
differs(f1,c.combatConfig.decisionFingerprint({a={x=2,y=1},b=2}),
    "Value and key changes must alter fingerprint")

local ledger={seat=1,hasPreview=true,preview={["monster:1"]={hand=1,discard=0}},
    applied={},previewOtherWounds=0,handDiscardApplied=false}
c.combatConfig.phasePreview={seat=1,turn=1,
    sources={{key="attack",resources={attack=4}}},
    joined={},targets={attack="monster"},explicit={},
    damage={targets={["monster:1"]={"unitA"}}},
    damageResults={["monster:1"]={heroWounds=1}}}
local before=c.combatConfig.woundCommitSignature(ledger)
c.combatConfig.phasePreview.damage.targets["monster:1"]={"unitB"}
local changed=c.combatConfig.woundCommitSignature(ledger)
differs(before,changed,"Identical Wounds assigned to a different Unit")
c.combatConfig.phasePreview.damage.targets["monster:1"]={"unitA"}
eq(c.combatConfig.woundCommitSignature(ledger),before,
    "Reverting a decision restores the confirmation signature")
c.combatConfig.phasePreview.sources[1].resources.attack=3
differs(before,c.combatConfig.woundCommitSignature(ledger),
    "Changed attack option invalidates confirmation")
assert(assignments:find("local primary=resourceCardsCombatPrimaryTarget",1,true),
    "Repeated Influence must not create a redundant primary arrow")
assert(assignments:find("Clear legacy phantom arrows",1,true),
    "Unsupported legacy additional arrows should be pruned")
print("Combat target-capability and commitment regressions passed")

-- Regression: a calculated Wound must be dealt once, keep its origin through
-- a save, and never be retroactively counted as an earlier Ranged/Siege kill.
-- Run: lua5.2 tools/test-combat-wound-application.lua
local function eq(actual,expected,label)
    if actual~=expected then error((label or "Mismatch")..": expected "
        ..tostring(expected)..", got "..tostring(actual),2) end
end
local function fileText(path)
    local file=assert(io.open(path,"r"))
    local content=file:read("*a")
    file:close()
    return content
end
local recognition=fileText("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local cardflow=fileText("src/PlayingGame/PlayerBoard/CardFlow.lua")
local function isolated(text,first,last,returns)
    local start=assert(text:find(first,1,true),first)
    local finish=assert(text:find(last,start+#first,true),last)
    return assert(load(text:sub(start,finish-1).."\n"..(returns or "")))()
end

-- Exercise the real transfer function against a minimal TTS bag.
local dealt={}
local bag={
    getGMNotes=function() return "Wound Cards" end,
    getPosition=function() return {-50,2,-45} end
}
getObjects=function() return {bag} end
safeTakeObject=function(_,container,args)
    eq(container,bag,"player's own Wound bag")
    local guid=string.format("w%05d",#dealt+1)
    dealt[#dealt+1]={guid=guid,position=args.position}
    return {guid=guid}
end
safeWaitFrames=function(_,callback) callback() end
isolated(cardflow,"function combatDealCalculatedWounds(seat,allocations,onCard,onDone)",
    "-- Wound dealing helper")

gStates={turnNumber=1}
turnOrder={[1]={seatPos=1}}
combatConfig={}
resourceCardsPanelOpen=function() return true end
resourceCardsPlayerCanEdit=function() return true end
resourceCardsSourceChanged=function() end
mainUIUpdate=function() end
warningColor={1,0,0}
local warnings={}
broadcastToColor=function(message, _playerColor, _messageTint)
    warnings[#warnings+1]=message
end
safeBroadcastToColor=broadcastToColor
-- Isolation tests do not load the earlier module-local snapshot helpers.
-- Provide equivalent minimal globals for the extracted wound coordinator.
combatPhaseLock=function() return nil end
combatAssignmentActiveSeat=function() return 1 end
combatFrozenCopy=function(value)
    if type(value)~="table" then return value end
    local copy={}
    for key,item in pairs(value) do copy[key]=combatFrozenCopy(item) end
    return copy
end
isolated(recognition,"combatConfig.woundLedger=function(seat)",
    "trackerPrivate.combatDisplay=require")

local items={{key="monsterA:1"},{key="monsterB:1"}}
combatConfig.woundRecordPreview(1,items,{
    ["monsterA:1"]={heroWounds=2,discard=2},
    ["monsterB:1"]={heroWounds=1,discard=0}})
local ledger=gStates.combatWoundApplication
local allocations,h,d,changed=combatConfig.woundPending(ledger)
eq(#allocations,2,"two distinct attacks")
eq(h,3,"three Wounds to hand")
eq(d,2,"two Poison Wounds to discard")
eq(changed,false,"no discrepancy yet")
resourceCardsApplyCombatWounds({color="Red"})
eq(#dealt,5,"five physical cards delivered")
eq(#(function() local t={} for guid in pairs(ledger.cards) do t[#t+1]=guid end return t end)(),
    3,"only hand cards are eligible post-Damage sources")
eq(dealt[1].position[3],-48.4,"hand positioning")
eq(dealt[3].position[3],-43.2,"poison-discard positioning")
resourceCardsApplyCombatWounds({color="Red"})
eq(#dealt,5,"second click cannot deal again")

-- A new calculation can add a Wound from the same printed attack.
combatConfig.woundRecordPreview(1,items,{
    ["monsterA:1"]={heroWounds=3,discard=2},
    ["monsterB:1"]={heroWounds=1,discard=0}})
resourceCardsApplyCombatWounds({color="Red"})
eq(#dealt,6,"only the newly owed Wound was delivered")
combatConfig.woundRecordPreview(1,items,{
    ["monsterA:1"]={heroWounds=1,discard=1},
    ["monsterB:1"]={heroWounds=1,discard=0}})
allocations,h,d,changed=combatConfig.woundPending(ledger)
eq(h,0,"no negative hand Wounds")
eq(d,0,"no negative discard Wounds")
eq(changed,true,"a changed plan needs manual reconciliation")
eq(combatWoundsEndTurnReminder("Red"),true,"first End Turn warns")
eq(combatWoundsEndTurnReminder("Red"),false,"second End Turn acknowledges")

-- A new Damage-phase Wound with a converted ranged/siege resource cannot
-- retroactively defeat its source. An old Wound remains eligible normally.
combatEnemyFortificationCount=function() return 0 end
combatEnemyHasTrait=function() return false end
combatAttackTotal=function(groups)
    local total=0
    for _,group in ipairs(groups) do
        for _,source in ipairs(group.sources) do
            total=total+(source.resources[group.category] or 0)
        end
    end
    return total
end
local range=isolated(recognition,"local function combatRangeResult(entry,sources)",
    "-- Block cells hold","return combatRangeResult")
local phase=isolated(recognition,"local function combatDetailPhase(detail,rangeDefeated,fortification,source)",
    "-- Chooses which Block","return combatDetailPhase")
local enemy={data={},perks={},baseArmour=2,elusiveArmour=2}
local old={guid="old",resources={ranged=2},damagePhaseWound=false}
local new={guid="new",resources={siege=2},damagePhaseWound=true}
local total,_,killed=range(enemy,{old,new})
eq(total,2,"new Wound not counted in Ranged/Siege")
eq(killed,true,"old Ranged Attack remains eligible")
eq(select(1,range(enemy,{new})),0,"late-only Siege cannot kill early")
eq(phase({family="siege"},true,0,new),"attack","late Siege always shown in Attack")
eq(phase({family="ranged"},true,0,old),"range","existing Ranged stays earlier")
assert(recognition:find('damagePhaseWound=guid=="878d92" and lateMoveSpent>0',1,true),
    "Agility must retain late-Move provenance")
assert(recognition:find('if field=="move" and source.damagePhaseWound',1,true),
    "Agility must track consumed Wound Move")
assert(fileText("src/PlayingGame/Combat/Combat.lua"):find(
    "attackAssignmentsUnitPreviewCommit",1,true),"Unit preview still commits at End Turn")

-- The explicit Draw Wounds UI refresh must not re-count all enemy rewards:
-- temporary movement through the thin combat zone could otherwise revoke Fame.
local ui=fileText("src/PlayingGame/Interface/UI.lua")
local nonCombatUpdates=isolated(ui,"local mainUINonCombatAccountingSources={",
    "local function setEndTurnText","return mainUINonCombatAccountingSources")
eq(nonCombatUpdates["Combat Wounds applied"],true,
    "drawing physical Wounds must preserve pending enemy Fame")
local enemyPanel=fileText("src/UI/CombatEnemyPanel.xml")
-- TTS expands a HorizontalLayout with only one child to the whole calculator.
-- Preserve the plain row and fixed-width, right-anchored wound summary while
-- allowing cosmetic changes to its width and offset (currently 205, 0 -4).
local summaryRow=assert(enemyPanel:match('<Panel id="CombatTotalRow"[^>]*>'),
    "Draw Wounds row must remain a plain Panel, not a HorizontalLayout")
assert(summaryRow:find('active="false"',1,true)
    and summaryRow:find('preferredHeight="22"',1,true),
    "Draw Wounds row needs the original collapsed height")
-- The Phase prompt must not join a HorizontalLayout or alter the existing
-- fixed-width Draw Wounds button. It is a non-interactive sibling immediately
-- to the left, with a Unicode arrow rather than a literal angle bracket.
local phasePrompt=assert(enemyPanel:match('<Text id="CombatDamagePhasePrompt"[^>]*>Perform Damage Phase →</Text>'),
    "Damage phase prompt or proper arrow is missing")
assert(phasePrompt:find('rectAlignment="UpperRight"',1,true)
    and phasePrompt:find('offsetXY="-213 -4"',1,true)
    and phasePrompt:find('width="200"',1,true)
    and phasePrompt:find('raycastTarget="false"',1,true),
    "Damage phase prompt must be absolutely positioned and non-interactive")
assert(enemyPanel:find('id="CombatDamagePhasePrompt"',1,true)
    < enemyPanel:find('id="CombatWoundSummary"',1,true),
    "Damage phase prompt must precede the right-hand wound button")
local summary=assert(enemyPanel:match('<Panel id="CombatWoundSummary"[^>]*>'),
    "Draw Wounds needs a dedicated anchored container")
local apply=assert(enemyPanel:match('<Button id="CombatApplyWounds"[^>]*>'),
    "Draw Wounds button was removed")
local label=assert(enemyPanel:match('<Text id="CombatTotalDamage"[^>]*>'),
    "Draw Wounds label was removed")
local warning=assert(enemyPanel:match('<Text id="CombatKnockoutWarning"[^>]*>'),
    "Knockout warning was removed")
local function fixedWidth(tag,name)
    local width=tonumber(tag:match('width="(%d+)"'))
    assert(width~=nil and width>0,name.." must use an explicit fixed width")
    assert(not tag:find('preferredWidth=',1,true),
        name.." must not use layout-preferred sizing")
    return width
end
assert(summary:find('rectAlignment="UpperRight"',1,true),
    "Wound summary must stay anchored to the result column at the right")
assert(summary:match('offsetXY="[%-%d%.]+ [%-%d%.]+"'),
    "Wound summary needs an explicit anchored offset")
assert(apply:find('onClick="resourceTracker"',1,true)
    and apply:find('rectAlignment="UpperCenter"',1,true),
    "Wound button must stay clickable and centred inside its summary")
local width=fixedWidth(summary,"Wound summary")
eq(fixedWidth(apply,"Draw Wounds button"),width,
    "Button and summary container widths must match")
eq(fixedWidth(label,"Draw Wounds text"),width,
    "Text must remain aligned with the Draw Wounds button")
eq(fixedWidth(warning,"Knockout warning"),width,
    "Knockout warning must align with the Draw Wounds button")
assert(not enemyPanel:find('CombatTotalSpacer',1,true),
    "No spacer may stretch the Draw Wounds row")
local renderer=fileText("src/PlayingGame/PlayerBoard/ResourceTracker/Interface/CombatPanel.lua")
assert(not recognition:find('summaryWidth',1,true) and not renderer:find('summaryWidth',1,true),
    "No dynamic preferredWidth writes should fight TTS's anchored position")
assert(renderer:find('"Draw: "..combatRich',1,true),
    "Wound button should be labelled Draw")
assert(renderer:find('local showTotal=totalHeroWounds>0 or knockout',1,true),
    "Knockout warning must remain visible after a cost-only discard")
assert(renderer:find('effects.handDiscard and "Apply: Discard hand"',1,true),
    "cost-only Knockout must show an actionable hand-discard button")
-- Paralysis must discard only the cards STILL IN HAND, including mixed
-- Deck stacks, and must never discard already played cards.
local discardHand=isolated(cardflow,"function combatDiscardParalyzedHand(seat,ownerColor)",
    "-- Discard only the Attack-only GUIDs","return combatDiscardParalyzedHand")
local discardStaged=isolated(cardflow,
    "function combatDiscardStagedAttackCards(seat,guids)",
    "-- Wound dealing helper","return combatDiscardStagedAttackCards")
local moved={}
local function card(guid,wound)
    local position={x=0,y=1,z=0}
    local obj={guid=guid,type="Card",use_hands=true,
        getGMNotes=function()
            return wound and "Wound" or "Advanced Action"
        end,
        getPosition=function() return position end,
        -- Smooth moves fail silently in a TTS HandTrigger. Direct movement
        -- works only when the script temporarily disables hand capture.
        setPositionSmooth=function(pos,collide,fast) end}
    obj.setPosition=function(target)
        eq(obj.use_hands,false,"temporarily disable TTS hand capture before moving")
        position={x=target.x or target[1],y=target.y or target[2],
            z=target.z or target[3]}
        moved[#moved+1]=guid
    end
    return obj
end
local good=card("good",false)
local existingWound=card("wound",true)
local deck={guid="deck",type="Deck",getObjects=function()
    return {{guid="stacked",gm_notes="Spell"},{guid="stackWound",gm_notes="Wound"}}
end,takeObject=function(args)
    eq(args.guid,"stacked","mixed Deck must extract only non-Wound cards")
    moved[#moved+1]=args.guid
    return {guid=args.guid}
end}
local held=card("held",false)
local handObjects={good,existingWound,deck}
local handZone={getObjects=function() return handObjects end}
local discardZone={getPosition=function() return {x=2,y=1,z=3} end}
handZones={[1]="hand"}
deedDeckDiscardZones={[1]="discard"}
getObjectFromGUID=function(guid)
    if guid=="hand" then return handZone end
    if guid=="discard" then return discardZone end
    return nil
end
local discarded,count=discardHand(1)
eq(discarded,true,"Paralysis discard should succeed")
eq(count,2,"only non-Wounds should be discarded")
eq(#moved,2,"exactly two cards physically discarded")
eq(moved[1],"good","ordinary hand card discarded")
eq(moved[2],"stacked","mixed deck non-Wound discarded")
eq(good.getPosition().x,2,"non-Wound hand card must escape HandTrigger")
eq(good.getPosition().z,3,"non-Wound hand card reaches discard zone")
eq(good.use_hands,true,"restore hand eligibility after discarding")
-- Scripting Zone tag filters may exclude playable cards. Request the
-- unfiltered contents when available.
local tagFiltered=card("tagFiltered",false)
handZone.getObjects=function(includeAll)
    return includeAll and {tagFiltered} or {}
end
discarded,count=discardHand(1)
eq(discarded,true,"tag-filtered scripting hand must be included")
eq(count,1,"tag-filtered card moved to discard")
eq(tagFiltered.getPosition().x,2,"tag-filtered hand card left hand")
handZone.getObjects=function() return handObjects end
held.held_by_color="Blue"
handObjects={held}
discarded=discardHand(1)
eq(discarded,false,"held hand cards must abort a destructive discard")
eq(#moved,3,"held card must remain untouched")
handObjects={}

-- In live TTS, the actual player HandTrigger may contain cards not reported
-- by the scripted hand zone. Paralysis must still discard those cards and
-- must not discard native hand Wounds or the same card twice.
local native=card("native",false)
local nativeWound=card("nativeWound",true)
local nativeHand={native,nativeWound}
Player={Red={getHandObjects=function() return nativeHand end}}
positionToColor=function() return "Red" end
discarded,count=discardHand(1)
eq(discarded,true,"native TTS hand should be inspected")
eq(count,1,"native hand discards its non-Wound card")
eq(moved[4],"native","native hand card actually moved")
handObjects={native}
discarded,count=discardHand(1)
eq(discarded,true,"duplicate physical and native hand views can merge")
eq(count,1,"duplicate hand views must not discard a card twice")
eq(#moved,5,"same GUID is moved only once per application")
-- The caller's actual colour overrides an unreliable seat-to-hand lookup.
-- This is important when the TTS hand was moved after initial setup.
local explicitCard=card("explicitCard",false)
handObjects={}
Player.Blue={getHandObjects=function() return {explicitCard} end}
positionToColor=function() return "Black" end
discarded,count=discardHand(1,"Blue")
eq(discarded,true,"explicit owner hand must be inspected")
eq(count,1,"explicit owner hand must discard its ordinary card")
eq(moved[6],"explicitCard","the real committing player controls the hand lookup")
-- The player's native TTS hand remains usable if the mod's scripting zone
-- is missing. Do not mistake an unavailable script zone for an empty hand.
local nativeOnly=card("nativeOnly",false)
Player.Blue={getHandObjects=function() return {nativeOnly} end}
getObjectFromGUID=function(guid)
    return guid=="discard" and discardZone or nil
end
discarded,count=discardHand(1,"Blue")
eq(discarded,true,"native hand works without a scripted hand zone")
eq(count,1,"native hand must still discard its non-Wound card")
eq(moved[7],"nativeOnly","native-only card reaches discard")
Player=nil
discarded=discardHand(1)
eq(discarded,false,"missing both hand sources must not silently succeed")
getObjectFromGUID=function(guid)
    return guid=="hand" and handZone or guid=="discard" and discardZone or nil
end
nativeHand={}
handObjects={}
Player=nil
positionToColor=nil

-- Count physical "take a Wound" costs during this combat, not previously
-- held Wounds or Wounds already dealt through the enemy damage transaction.
local playObjects={}
local playZone={getObjects=function() return playObjects end}
playerPlayAreas={[1]="play"}
getObjectFromGUID=function(guid)
    return guid=="hand" and handZone or guid=="play" and playZone
        or guid=="discard" and discardZone or nil
end
gStates.combatWoundApplication=nil
local oldDiscardWound=card("oldDiscardWound",true)
discardZone.getObjects=function() return {oldDiscardWound} end
handObjects={existingWound}
eq(combatConfig.combatOtherWounds(1),0,"start-of-combat existing Wound ignored")
handObjects={existingWound,oldDiscardWound}
eq(combatConfig.combatOtherWounds(1),0,
    "retrieving an old discard Wound is not new combat damage")
local costWound=card("costWound",true)
handObjects={existingWound,costWound}
eq(combatConfig.combatOtherWounds(1),1,"card-cost Wound is counted")
local costLedger=gStates.combatWoundApplication
costLedger.cards.enemyWound=true
handObjects[#handObjects+1]=card("enemyWound",true)
eq(combatConfig.combatOtherWounds(1),1,"dealt enemy Wound not counted twice")
handObjects={existingWound}
playObjects={costWound}
eq(combatConfig.combatOtherWounds(1),1,
    "playing an extra combat Wound does not erase its count")
playObjects={}
eq(combatConfig.combatOtherWounds(1),1,
    "discarding a spent cost Wound does not erase prior combat damage")

-- Physical Attack-only discards use the same direct TTS movement as hand
-- cards, but target ONLY the exact play-zone GUIDs from the frozen plan.
local stageRage=card("stageRage",false)
local stageShield=card("stageShield",false)
playObjects={stageRage,stageShield,existingWound}
local beforeStage=#moved
local okStage,movedStage,guidsStage=discardStaged(1,{"stageRage"})
eq(okStage,true,"Attack-only staged card discarded")
eq(movedStage,1,"only one confirmed Attack-only card moved")
eq(guidsStage[1],"stageRage","moved GUID recorded for transaction")
eq(#moved,beforeStage+1,"staged Attack moves once")
eq(stageRage.getPosition().x,2,"staged Attack reaches discard zone")
eq(stageShield.getPosition().x,0,"played Shield is never swept up")
eq(stageRage.use_hands,true,"hand eligibility restored after staged discard")
local beforeInvalid=#moved
okStage=discardStaged(1,{"stageShield","absent"})
eq(okStage,false,"missing frozen card aborts the staged transfer")
eq(#moved,beforeInvalid,"failed validation cannot partly discard")
stageShield.held_by_color="Red"
okStage=discardStaged(1,{"stageShield"})
eq(okStage,false,"held staged card is not discarded")
stageShield.held_by_color=nil
playObjects={}
gStates.combatWoundApplication=nil
handObjects={}

-- If a destroyed Unit had already helped defeat a different enemy with
-- Ranged/Siege, its early attack must remain valid after physical removal.
local resolveDamage=dofile("src/PlayingGame/PlayerBoard/ResourceTracker/Combat/DamageCalculation.lua").resolution(
    function(guid) return gameCards~=nil and gameCards[guid] or nil end,
    function(owner,summoner)
        local records=gStates~=nil and gStates.attackedMonsters or nil
        local record=records~=nil and records[owner] or nil
        return record~=nil and record[3]=="summoned" and record[4]==summoner
    end,
    function() return trackerPrivate.bannerEffectUses().fortitude end).resolve
gameCards={unitR={name={"Crossbowmen"}}}

-- Hero Armor rises at levels 3, 7, 11, ...; extra native Command tokens
-- must not increase Armor at levels 5, 9, 13, ...
local heroArmour=isolated(recognition,"local function combatHeroArmour(nativeCommandCount)",
    "local function combatDamageUnits","return combatHeroArmour")
local savedHeroLevel=turnOrder[1].level
for _,case in ipairs({
    {1,1,2},{2,1,2},{3,2,3},{4,2,3},{5,3,3},{6,3,3},
    {7,4,4},{8,4,4},{9,5,4},{10,5,4},
    {11,6,5},{12,6,5},{13,7,5},{14,7,5},{15,8,6}
}) do
    turnOrder[1].level=case[1]
    eq(heroArmour(case[2]),case[3],"Hero Armor at level "..case[1])
end
-- Regression: switching an attack-reduction modifier from -2 to none
-- must return the High Dragon's Brutal 12 damage to four Hero Wounds.
turnOrder[1].level=5
local dragonHits={{key="highDragon:1",owner="highDragon",type="IF",damage=12}}
local noAssignedUnits=function() return {} end
local function dragonWounds()
    local result=resolveDamage(dragonHits,{},heroArmour(3),noAssignedUnits)
    return result["highDragon:1"].heroWounds
end
eq(dragonWounds(),4,"Brutal Cold Fire 12 vs Armor 3")
dragonHits[1].damage=8
eq(dragonWounds(),3,"reduced Brutal Cold Fire 8 vs Armor 3")
dragonHits[1].damage=12
eq(dragonWounds(),4,"reverted reduction restores four Wounds")
turnOrder[1].level=savedHeroLevel
local attack={{key="enemyB:1",owner="enemyB",type="P",damage=4,paralyse=true}}
local initial=resolveDamage(attack,{unitR={guid="unitR",armour=2,resist={},wounded=false}},
    2,function() return {"unitR"} end)
eq(initial["enemyB:1"].heroWounds,1,"Hero receives one residual Wound")
eq(initial["enemyB:1"].units[1].destroyed,true,"Paralysis destroys hit Unit")
eq(initial["enemyB:1"].units[1].absorbed,2,"destroyed Unit absorbed its Armour")
local immune=resolveDamage(attack,{unitR={guid="unitR",armour=2,resist={},
    wounded=false,arcaneImmunity=true}},2,function() return {"unitR"} end)
eq(immune["enemyB:1"].units[1].destroyed,false,
    "Arcane Immunity prevents Paralysis destruction")
local after=resolveDamage(attack,{},2,function() return {} end,
    nil,nil,nil,{["enemyB:1"]={destroyed={unitR=2}}})
eq(after["enemyB:1"].heroWounds,1,
    "recalculation cannot reassign a destroyed Unit's damage to Hero")
eq(#after["enemyB:1"].units,1,"resolved Unit hit remains in history")
eq(after["enemyB:1"].units[1].alreadyApplied,true,
    "resolved Unit hit is not a fresh physical wound")
assert(recognition:find('retiredUnitSources',1,true)
    and recognition:find('source.retiredUnitPosition',1,true),
    "destroyed Ranged/Siege Unit must survive calculation as a frozen source")
local snapshot=isolated(recognition,"local function combatFrozenCopy(value)",
    "local function combatNearestEnemyGUID",
    "return combatConfig.captureParalyzedUnitSources")
combatAssignmentState={targets={unitR="enemyA"},explicit={unitR=true}}
combatAssignmentSources=function()
    return {{kind="unit",guid="unitR",key="unitR",name="Crossbowmen",
        ranged=4,siege=0,block=2,attack=5,move=0,
        resources={ranged=4,block=2,attack=5},
        details={{family="ranged",key="ranged",amount=4},
            {family="block",key="block",amount=2},
            {family="attack",key="attack",amount=5}}}}
end
getObjectFromGUID=function(guid)
    if guid=="unitR" then
        return {getPosition=function() return {0,1,-39} end}
    end
    return nil
end
gStates.combatWoundApplication=nil
eq(snapshot(1,"unitR"),true,"retired Unit snapshot succeeds")
local saved=gStates.combatWoundApplication.retiredUnitSources.unitR[1]
eq(saved.ranged,4,"previous Ranged contribution survives")
eq(saved.block,2,"previous Block contribution survives")
eq(saved.attack,0,"destroyed Unit cannot attack in later phase")
eq(saved.resources.attack,nil,"Attack resource must not survive")
eq(saved.retiredTarget,"enemyA","chosen Ranged target must survive")
eq(saved.retiredUnitPosition[3],-39,"automatic targeting preserves position")
local targetPolicy=dofile("src/PlayingGame/PlayerBoard/ResourceTracker/Combat/CombatTargetPolicy.lua")
eq(targetPolicy.acceptsSource("unitR","enemyA"),true,
    "destroyed Unit retains its earlier Ranged/Siege target")
eq(targetPolicy.acceptsSource("unitR","enemyB"),false,
    "destroyed Unit must not redirect its earlier Ranged/Siege attack")

-- Draw Wounds must commit each Paralysis consequence once, including when
-- the Hero took zero Wounds and the only effect is destroying one Unit.
gStates.combatWoundApplication=nil
combatConfig.woundRecordPreview(1,{{key="enemyC:1"}},{
    ["enemyC:1"]={heroWounds=0,discard=0,paralyse=false,
        units={{wounded=true,destroyed=true,absorbed=2,
            unit={guid="unitR",name="Crossbowmen"}}}}})
ledger=gStates.combatWoundApplication
local _,ph,pd,pc,fx=combatConfig.woundPending(ledger)
eq(ph,0,"Unit-only Paralysis owes no Hero Wounds")
eq(fx.destroyCount,1,"Unit-only Paralysis requires Apply")
local captured,destroyedUnits=0,0
combatConfig.captureParalyzedUnitSources=function()
    captured=captured+1
    return true
end
attackAssignmentsUnitPreviewApplyDestroyed=function(_,guid)
    eq(guid,"unitR","only the assigned Paralyzed Unit is destroyed")
    destroyedUnits=destroyedUnits+1
    return true
end
resourceCardsApplyCombatWounds({color="Red"})
eq(captured,1,"early Unit attack captured before destruction")
eq(destroyedUnits,1,"Apply destroys Unit immediately")
resourceCardsApplyCombatWounds({color="Red"})
eq(destroyedUnits,1,"second click must not destroy twice")

gStates.combatWoundApplication=nil
combatConfig.woundRecordPreview(1,{{key="enemyD:1"}},{
    ["enemyD:1"]={heroWounds=1,discard=0,paralyse=true,units={}}})
getObjectFromGUID=function(guid)
    return guid=="hand" and handZone or guid=="discard" and discardZone or nil
end
local discardCount=0
combatDiscardParalyzedHand=function()
    discardCount=discardCount+1
    return true,2
end
resourceCardsApplyCombatWounds({color="Red"})
eq(discardCount,1,"first hit discards non-Wounds from hand")
resourceCardsApplyCombatWounds({color="Red"})
eq(discardCount,1,"second click cannot discard newly drawn cards")

-- Knockout alone, with no calculated enemy Wounds left to deal, must still
-- expose a Commit action that discards hand cards exactly once.
gStates.combatWoundApplication=nil
combatConfig.woundRecordPreview(1,{{key="costKO:1"}},{
    ["costKO:1"]={heroWounds=0,discard=0,paralyse=false,units={}}},true,5)
local koLedger=gStates.combatWoundApplication
local _,koh,kod,_,koEffects=combatConfig.woundPending(koLedger)
eq(koh,0,"Knockout can be caused entirely by card-effect Wounds")
eq(kod,0,"Knockout does not fabricate extra Poison Wounds")
eq(koEffects.handDiscard,true,"Knockout alone requires hand discard")
eq(koEffects.knockout,true,"Knockout is included in the pending ledger")
local beforeKO=discardCount
resourceCardsApplyCombatWounds({color="Red"})
eq(discardCount,beforeKO+1,"Knockout discards the Hero hand")
eq(koLedger.handDiscardApplied,true,"Knockout discard is saved")
resourceCardsApplyCombatWounds({color="Red"})
eq(discardCount,beforeKO+1,"retry cannot discard newly drawn cards")

-- A simultaneous Paralyzing Wound and Knockout must share one physical
-- discard instead of triggering the same destructive effect twice.
gStates.combatWoundApplication=nil
combatConfig.woundRecordPreview(1,{{key="combined:1"}},{
    ["combined:1"]={heroWounds=1,discard=0,paralyse=true,units={}}},true,4)
local combined=gStates.combatWoundApplication
local _,_,_,_,combinedEffects=combatConfig.woundPending(combined)
eq(combinedEffects.paralyseCount,1,"Paralysis is still reported")
eq(combinedEffects.handDiscard,true,"simultaneous effects need one discard")
resourceCardsApplyCombatWounds({color="Red"})
eq(discardCount,beforeKO+2,"simultaneous effects discarded exactly once")
eq(combined.handDiscardApplied,true,"combined discard stays committed")
resourceCardsApplyCombatWounds({color="Red"})
eq(discardCount,beforeKO+2,"combined effect never double discards")

-- A failure before any physical hand movement must NOT acknowledge the
-- discard. The previous implementation marked a throwing helper as done,
-- leaving every playable card in hand on all subsequent retries.
gStates.combatWoundApplication=nil
combatConfig.woundRecordPreview(1,{{key="exception:1"}},{
    ["exception:1"]={heroWounds=0,discard=0,paralyse=false,units={}}},true,5)
local failedLedger=gStates.combatWoundApplication
combatDiscardParalyzedHand=function()
    error("test hand error")
end
resourceCardsApplyCombatWounds({color="Red"})
eq(failedLedger.handDiscardApplied,false,
    "an exception must not silently acknowledge Knockout")
eq(select(5,combatConfig.woundPending(failedLedger)).handDiscard,true,
    "failed Knockout discard remains pending for retry")
combatDiscardParalyzedHand=function(seat,color)
    eq(seat,1,"commit must pass the correct seat")
    eq(color,"Red","commit must pass the committing TTS hand colour")
    discardCount=discardCount+1
    return true,1,{"retryCard"}
end
resourceCardsApplyCombatWounds({color="Red"})
eq(failedLedger.handDiscardApplied,true,"retry finally commits Knockout")
eq(discardCount,beforeKO+3,"retry moves the remaining hand")

gStates.combatWoundApplication=nil
combatConfig.woundRecordPreview(1,{{key="partial:1"}},{
    ["partial:1"]={heroWounds=0,discard=0,paralyse=false,units={}}},true,5)
local partialLedger=gStates.combatWoundApplication
combatDiscardParalyzedHand=function()
    return false,"partial move",1,{"oneCard"}
end
resourceCardsApplyCombatWounds({color="Red"})
eq(partialLedger.handDiscardApplied,false,
    "a partial hand transfer must not abandon remaining cards")
eq(select(5,combatConfig.woundPending(partialLedger)).handDiscard,true,
    "partial Knockout discard remains pending")
combatDiscardParalyzedHand=function()
    discardCount=discardCount+1
    return true,1,{"remainingCard"}
end
resourceCardsApplyCombatWounds({color="Red"})
eq(partialLedger.handDiscardApplied,true,"a partial discard can safely finish")

-- A confirmed Attack-only plan persists through the commit, save/reload,
-- retry, and temporary disappearance of the physical card from the scan.
local stageCalls={}
combatDiscardStagedAttackCards=function(seat,guids)
    eq(seat,1,"Attack-only discard has the right seat")
    stageCalls[#stageCalls+1]=table.concat(guids,",")
    return true,#guids,guids
end
combatDiscardParalyzedHand=function()
    return true,0,{}
end
gStates.combatWoundApplication=nil
combatConfig.woundRecordPreview(1,{{key="stage:1"}},{
    ["stage:1"]={heroWounds=0,discard=0,paralyse=false,units={}}},
    true,0,{"rage","swiftness"})
local stageLedger=gStates.combatWoundApplication
local _,_,_,_,stageFx=combatConfig.woundPending(stageLedger)
eq(stageFx.stagedDiscardCount,2,"two invalidated pure Attack cards are pending")
resourceCardsApplyCombatWounds({color="Red"})
eq(stageCalls[1],"rage,swiftness","only captured Attack GUIDs moved")
eq(stageLedger.playDiscardApplied.rage,true,"Rage transfer saved by GUID")
eq(stageLedger.playDiscardApplied.swiftness,true,"Swiftness saved by GUID")
resourceCardsApplyCombatWounds({color="Red"})
eq(#stageCalls,1,"a second commit must not discard new played cards")

gStates.combatWoundApplication=nil
combatConfig.woundRecordPreview(1,{{key="stageFail:1"}},{
    ["stageFail:1"]={heroWounds=0,discard=0,paralyse=false,units={}}},
    true,0,{"rage","swiftness"})
local stageFailed=gStates.combatWoundApplication
combatDiscardStagedAttackCards=function()
    return false,"second card failed",1,{"rage"}
end
resourceCardsApplyCombatWounds({color="Red"})
eq(stageFailed.playDiscardApplied.rage,true,"partial staged transfer recorded")
eq(stageFailed.playDiscardApplied.swiftness,nil,"unmoved card remains pending")
local _,_,_,_,remainingStage=combatConfig.woundPending(stageFailed)
eq(remainingStage.stagedDiscardCount,1,"only one Attack remains for retry")
combatDiscardStagedAttackCards=function(_,guids)
    stageCalls[#stageCalls+1]=table.concat(guids,",")
    return true,#guids,guids
end
resourceCardsApplyCombatWounds({color="Red"})
eq(stageCalls[2],"swiftness","retry moves only the remaining Attack")
eq(stageFailed.playDiscardApplied.swiftness,true,"retry persists staged transfer")

-- Save/reload may rescan an empty play area after cards were physically
-- discarded. The stored phaseLock must keep the original candidate GUIDs;
-- only the uncommitted ones remain eligible on recovery.
gStates.combatWoundApplication=nil
combatConfig.woundRecordPreview(1,{{key="savedStage:1"}},{
    ["savedStage:1"]={heroWounds=0,discard=0,paralyse=false,units={}}},
    true,0,{"rage","swiftness"})
local savedStage=gStates.combatWoundApplication
savedStage.phaseLock={attackDiscards={"rage","swiftness"}}
savedStage.playDiscardApplied.rage=true
combatConfig.woundRecordPreview(1,{{key="savedStage:1"}},{
    ["savedStage:1"]={heroWounds=0,discard=0,paralyse=false,units={}}},
    true,0,{})
local _,_,_,_,savedStageEffects=combatConfig.woundPending(savedStage)
eq(savedStageEffects.stagedDiscardCount,1,
    "save/reload preserves the one remaining staged discard")
eq(savedStageEffects.stagedDiscards[1],"swiftness",
    "save/reload never re-discards the committed Rage card")

assert(renderer:find("effects.destroyCount>0",1,true),
    "Paralysis-only effects must show the Apply row")
assert(recognition:find("combatConfig.captureParalyzedUnitSources(seat,effect.guid)",1,true),
    "snapshot ranged actions before deleting Unit")

-- The existing Draw Wounds button does not mutate anything. It opens a
-- seat-scoped confirmation, and a fresh rewind snapshot is required before
-- ANY physical Wounds or Paralysis consequences can be committed.
local xml=fileText("src/UI/CombatDamageConfirm.xml")
assert(fileText(".tts/objects/Global.xml"):find('UI/CombatDamageConfirm.xml',1,true),
    "confirmation dialog must be included in the global UI")
assert(xml:find('id="CombatDamageConfirm" active="false"',1,true)
    and xml:find('id="CombatDamageConfirmSummary"',1,true)
    and xml:find('id="CombatDamageConfirmCancel" onClick="resourceTracker"',1,true)
    and xml:find('id="CombatDamageConfirmApply" onClick="resourceTracker"',1,true)
    and xml:find('id="CombatDamageConfirmDontShowAgain"',1,true)
    and xml:find('onValueChanged="resourceCardsCombatWoundsSkipChanged"',1,true),
    "Combat damage confirmation controls must be present and initially hidden")
assert(xml:find('<Text id="CombatDamageConfirmCancelText" class="Text18">',1,true)
    and xml:find('<Text id="CombatDamageConfirmApplyText" class="Text18">',1,true),
    "the Cancel and Commit Damage labels need stable translation IDs")
assert(xml:find('width="410" height="280"',1,true)
    and xml:find('returnToOriginalPositionWhenReleased="false"',1,true)
    and xml:find('preferredHeight="154"',1,true),
    "confirmation should be compact and stay where dragged")
assert(fileText("src/PlayingGame/Interface/UI.lua"):find(
    'resourceCardsRequestCombatWounds(player)',1,true),
    "the original wound button must open confirmation, not deal Wounds")

-- Exercise the actual UI routing with no access to the module-private
-- combatConfig table. Previously both buttons failed here with a nil index.
local uiSource=fileText("src/PlayingGame/Interface/UI.lua")
local routeStart=assert(uiSource:find("function resourceTracker(player, mouseButton, id)",1,true))
local routeEnd=assert(uiSource:find(
    "-- Stale hidden XML controls cannot revive calculations while OFF.",routeStart,true))
local clickChoices={}
local clickEnv={
    resourceCardsPlayerCanEdit=function(color) return color=="Red" end,
    resourceCardsConfirmCombatWounds=function(_,choice)
        clickChoices[#clickChoices+1]=choice
    end,
}
setmetatable(clickEnv,{__index=function(_,name)
    if name=="combatConfig" then error("UI accessed private combatConfig") end
    return _G[name]
end})
assert(load(uiSource:sub(routeStart,routeEnd-1).."\n    end\nend\n",
    "combat UI click routing","t",clickEnv))()
clickEnv.resourceTracker({color="Red"},"-1","CombatDamageConfirmCancel")
clickEnv.resourceTracker({color="Red"},"-1","CombatDamageConfirmApply")
eq(clickChoices[1],"CombatDamageConfirmCancel","Cancel reaches public handler")
eq(clickChoices[2],"CombatDamageConfirmApply","Commit reaches public handler")
eq(#clickChoices,2,"both confirm buttons invoke exactly one handler")
assert(recognition:find('type(storeRewindState)~="function"',1,true)
    and recognition:find('rewindTransactionCanStartFresh()',1,true)
    and recognition:find('rewindTransactionStart(function()',1,true)
    and recognition:find('rewindTransactionFinish(owner)',1,true),
    "combat commits require a new protected TTS rewind point")
assert(fileText("src/Shared.lua"):find(
    'function rewindTransactionCanStartFresh()',1,true),
    "rewind helper must refuse nesting under an older snapshot")

local attrs={}
UI={setAttribute=function(id,field,value) attrs[id..":"..field]=value end}
setUIVisibility=function(id,viewers)
    eq(id,"CombatDamageConfirm","confirmation must be private")
    eq(viewers[1],"Red","only the committing player sees dialog")
end
joinLang=function(parts)
    local result={}
    for _,part in ipairs(parts) do
        local value=tostring(part)
        result[#result+1]=value:match("^{en}(.-){it}") or value
    end
    return table.concat(result)
end
combatAssignmentState={targets={unitR="enemyA"},explicit={unitR=true}}
local capturedSnapshot,finishedSnapshots={},{}
local activeRewind=true
rewindTransactionCanStartFresh=function() return activeRewind end
rewindTransactionOwnerActive=function() return true end
rewindTransactionStart=function(callback,owner,onFail)
    capturedSnapshot={callback=callback,owner=owner,fail=onFail}
    return true
end
rewindTransactionFinish=function(owner)
    finishedSnapshots[#finishedSnapshots+1]=owner
end
storeRewindState=function(_callback,_block) end
local player={color="Red"}
-- The production calculator builds this candidate during the preview pass.
combatConfig.phasePreview={seat=1,turn=1,sources={},sourceKeys={},
    objectKeys={},targets={},explicit={},positions={},joined={},
    entries={},damageResults={},damage={attacks={},units={},targets={}}}
local startCount=#dealt
gStates.combatWoundApplication=nil
combatConfig.woundRecordPreview(1,{{key="confirm:1"}},{
    ["confirm:1"]={heroWounds=2,discard=0}})
combatConfig.scanAwaitingRescan=true
eq(combatConfig.woundCommitSignature(gStates.combatWoundApplication),nil,
    "Intermediate Unit scan cannot supply a confirmation signature")
eq(resourceCardsApplyCombatWounds(player),false,"Intermediate scan cannot apply Wounds")
eq(combatWoundsEndTurnReminder("Red"),true,"Intermediate scan cannot end turn")
combatConfig.scanAwaitingRescan=false
resourceCardsRequestCombatWounds(player)
eq(attrs["CombatDamageConfirm:active"],"true","button must open confirmation")
eq(attrs["CombatDamageConfirm:height"],"280","normal damage dialog fits the checkbox")
eq(attrs["CombatDamageConfirmDontShowAgain:isOn"],"false","checkbox starts unchecked")
eq(attrs["CombatDamageConfirmSummary:preferredHeight"],"154","compact summary height")
local damageText=attrs["CombatDamageConfirmSummary:text"]
assert(damageText:find("Calculator will be locked in to attack adjustments only. Use TTS Rewind to undo.",1,true)
    and damageText:find("Confirm your Ranged/Siege and Block decisions",1,true)
    and damageText:find("Hero Wounds to hand: 2",1,true)
    and damageText:find("Poison Wounds to discard: 0",1,true),
    "all confirmation paragraphs must survive as one localized message")
eq(#dealt,startCount,"opening dialog does not draw Wounds")
eq(combatWoundsEndTurnReminder("Red"),true,
    "End Turn blocked while confirmation is open")
resourceCardsConfirmCombatWounds(player,"CombatDamageConfirmCancel")
eq(attrs["CombatDamageConfirm:active"],"false","Cancel closes dialog")
eq(#dealt,startCount,"Cancel must not draw any Wounds")

-- Stale plans are rejected BEFORE snapshot and again AFTER it is recorded.
resourceCardsRequestCombatWounds(player)
combatConfig.woundRecordPreview(1,{{key="confirm:1"}},{
    ["confirm:1"]={heroWounds=3,discard=0}})
resourceCardsConfirmCombatWounds(player,"CombatDamageConfirmApply")
eq(#dealt,startCount,"changed plan cannot be confirmed")
eq(combatConfig.woundTransactionPending,nil,
    "stale dialog must not start rewind transaction")
resourceCardsRequestCombatWounds(player)
combatConfig.woundConfirmChoice(player,"CombatDamageConfirmApply")
eq(combatConfig.woundTransactionPending,true,
    "while recording checkpoint, damage remains blocked")
eq(#dealt,startCount,"snapshot must precede card transfer")
eq(combatWoundsEndTurnReminder("Red"),true,
    "End Turn blocked while checkpoint is pending")
combatConfig.woundRecordPreview(1,{{key="confirm:1"}},{
    ["confirm:1"]={heroWounds=4,discard=0}})
capturedSnapshot.callback()
eq(#dealt,startCount,"plan changed during rewind snapshot must abort")
eq(combatConfig.woundTransactionPending,false,"aborted snapshot clears pending")
eq(#finishedSnapshots,1,"aborted snapshot releases rewind owner")

-- A failed checkpoint leaves the table untouched and allows another try.
resourceCardsRequestCombatWounds(player)
combatConfig.woundConfirmChoice(player,"CombatDamageConfirmApply")
capturedSnapshot.fail()
eq(#dealt,startCount,"snapshot failure cannot deliver physical Wounds")
eq(combatConfig.woundTransactionPending,false,"snapshot failure clears lock")

-- Rewind API unavailable and an older active transaction both block commit.
resourceCardsRequestCombatWounds(player)
storeRewindState=nil
combatConfig.woundConfirmChoice(player,"CombatDamageConfirmApply")
eq(#dealt,startCount,"without TTS rewind API, commit is refused")
storeRewindState=function(_callback,_block) end
activeRewind=false
combatConfig.woundConfirmChoice(player,"CombatDamageConfirmApply")
eq(#dealt,startCount,"nested transaction cannot reuse older checkpoint")
activeRewind=true
combatConfig.woundConfirmChoice(player,"CombatDamageConfirmCancel")

-- Successfully snapped commits wait for the FINAL moving card before
-- releasing rewind storage. The underlying Wound ledger remains idempotent.
local settle={}
safeWaitCondition=function(_,done,ready)
    settle={done=done,ready=ready}
end
resourceCardsRequestCombatWounds(player)
combatConfig.woundConfirmChoice(player,"CombatDamageConfirmApply")
local previousFinished=#finishedSnapshots
capturedSnapshot.callback()
eq(#dealt,startCount+4,"checkpoint allows exactly planned four Wounds")
eq(combatConfig.woundApplying,true,"physical settlement holds commit lock")
eq(#finishedSnapshots,previousFinished,"rewind remains protected while cards move")
eq(type(settle.ready),"function","settling condition registered")
eq(settle.ready(),true,"all card movements eventually settle")
settle.done()
eq(combatConfig.woundApplying,false,"settlement clears applying flag")
eq(#finishedSnapshots,previousFinished+1,"rewind released once after settling")
eq(attrs["CombatDamageConfirm:active"],"false","dialog stays closed after commit")
local committed=gStates.combatWoundApplication.phaseLock
assert(committed~=nil and committed.seat==1 and committed.turn==1,
    "successful checkpoint must persist the phase lock in the wound ledger")
resourceCardsRequestCombatWounds(player)
eq(attrs["CombatDamageConfirm:active"],"false","second click has nothing left to apply")

-- Clean validation failure should release the newly created phase lock.
-- If a physical transfer has begun, leave it locked but allow a fresh
-- confirmation to resume the same idempotent ledger.
local realApply=resourceCardsApplyCombatWounds
gStates.combatWoundApplication=nil
combatConfig.woundRecordPreview(1,{{key="retry:1"}},{
    ["retry:1"]={heroWounds=2,discard=0}})
local retryLedger=gStates.combatWoundApplication
resourceCardsRequestCombatWounds(player)
resourceCardsApplyCombatWounds=function(_,done)
    done(false,"missing hand zone",false)
    return true
end
combatConfig.woundConfirmChoice(player,"CombatDamageConfirmApply")
capturedSnapshot.callback()
eq(retryLedger.phaseLock,nil,"clean failure must release phase lock")
resourceCardsRequestCombatWounds(player)
eq(attrs["CombatDamageConfirm:active"],"true",
    "clean failed commit may be attempted again")
resourceCardsApplyCombatWounds=function(_,done)
    done(false,"one card was moved",true)
    return true
end
combatConfig.woundConfirmChoice(player,"CombatDamageConfirmApply")
capturedSnapshot.callback()
local partialLock=retryLedger.phaseLock
assert(partialLock~=nil,"partial physical failure keeps the committed phase")
resourceCardsRequestCombatWounds(player)
eq(attrs["CombatDamageConfirm:active"],"true",
    "partial failure may reopen the confirmation under its phase lock")
-- A retry uses the original lock even if the live preview is unavailable.
local savedPreview=combatConfig.phasePreview
combatConfig.phasePreview=nil
resourceCardsApplyCombatWounds=function(_,done)
    done(true,nil,false)
    return true
end
combatConfig.woundConfirmChoice(player,"CombatDamageConfirmApply")
capturedSnapshot.callback()
eq(retryLedger.phaseLock,partialLock,
    "retry must preserve rather than replace the original combat snapshot")
combatConfig.phasePreview=savedPreview
-- Unexpected exceptions after the busy flag is set must allow recovery.
resourceCardsRequestCombatWounds(player)
resourceCardsApplyCombatWounds=function()
    combatConfig.woundApplying=true
    error("injected physical transfer exception")
end
local beforeException=#finishedSnapshots
combatConfig.woundConfirmChoice(player,"CombatDamageConfirmApply")
capturedSnapshot.callback()
eq(combatConfig.woundApplying,false,"exception clears applying flag")
eq(combatConfig.woundTransactionPending,false,"exception clears pending flag")
eq(#finishedSnapshots,beforeException+1,"exception releases rewind owner")
eq(retryLedger.phaseLock,partialLock,"exception preserves existing phase lock")
resourceCardsApplyCombatWounds=realApply

-- A Unit-only damage assignment can be reviewed, cancelled, and committed
-- without drawing a Hero Wound. Fortitude is spent only at that boundary.
gStates.combatWoundApplication=nil
local bannerUses={}
trackerPrivate=trackerPrivate or {}
local originalBannerUses=trackerPrivate.bannerEffectUses
trackerPrivate.bannerEffectUses=function() return {fortitude=bannerUses} end
local unitItems={{key="bannerAttack:1"}}
local unitResults={["bannerAttack:1"]={heroWounds=0,units={{
    unit={guid="protectedUnit",fortitudeGUID="fortitude"},
    wounded=false,fortitudePrevented=true}}}}
local function unitPreview()
    combatConfig.phasePreview.damageResults=combatFrozenCopy(unitResults)
    combatConfig.woundRecordPreview(1,unitItems,unitResults)
end
unitPreview()
local unitLedger=gStates.combatWoundApplication
local _,_,_,_,unitEffects=combatConfig.woundPending(unitLedger)
eq(unitEffects.unitCommitPending,true,"Zero Hero Wounds still require a Unit commitment")
eq(combatWoundsEndTurnReminder("Red"),true,"Uncommitted Unit damage blocks End Turn")
resourceCardsRequestCombatWounds(player)
eq(attrs["CombatDamageConfirm:active"],"true","Unit-only commit opens normal dialog")
eq(bannerUses.fortitude,nil,"Opening dialog does not spend Banner")
resourceCardsConfirmCombatWounds(player,"CombatDamageConfirmCancel")
eq(bannerUses.fortitude,nil,"Cancellation does not spend Banner")
combatConfig.woundRecordPreview(1,unitItems,{["bannerAttack:1"]={heroWounds=0}})
local _,_,_,_,removedEffects=combatConfig.woundPending(unitLedger)
eq(removedEffects.unitCommitPending,false,"Removing assignment removes pending commitment")
unitPreview()
resourceCardsRequestCombatWounds(player)
resourceCardsConfirmCombatWounds(player,"CombatDamageConfirmApply")
eq(bannerUses.fortitude,nil,"Waiting for rewind point does not spend Banner")
local beforeUnitCommit=#dealt
capturedSnapshot.callback()
eq(#dealt,beforeUnitCommit,"Zero-Wound commit draws no cards")
eq(unitLedger.damageAssignmentsCommitted,true,"Unit-only damage committed")
assert(unitLedger.phaseLock~=nil,"Unit-only damage freezes earlier phases")
eq(bannerUses.fortitude.attackKey,"bannerAttack:1","Confirmed Banner use persisted")
eq(combatConfig.woundApplying,false,"No physical movement to settle")
local _,_,_,_,committedUnitEffects=combatConfig.woundPending(unitLedger)
eq(committedUnitEffects.unitCommitPending,false,"Committed Unit assignment not pending")
eq(combatWoundsEndTurnReminder("Red"),false,"Committed Unit damage permits End Turn")
resourceCardsRequestCombatWounds(player)
eq(attrs["CombatDamageConfirm:active"],"false","Cannot commit same Unit assignment twice")
trackerPrivate.bannerEffectUses=originalBannerUses
combatConfig.phasePreview.damageResults={}

-- Opt-out belongs to the confirming colour, persists only after a successful
-- protected commit, and never removes snapshot/validation on later clicks.
gStates.combatWoundApplication=nil
combatConfig.woundRecordPreview(1,{{key="optout:1"}},{
    ["optout:1"]={heroWounds=1,discard=0}})
resourceCardsRequestCombatWounds(player)
resourceCardsCombatWoundsSkipChanged({color="Blue"},"True","CombatDamageConfirmDontShowAgain")
eq(combatConfig.woundConfirmation.skipNext,false,
    "another player cannot select the confirmation checkbox")
resourceCardsCombatWoundsSkipChanged(player,"True","CombatDamageConfirmDontShowAgain")
eq(combatConfig.woundConfirmation.skipNext,true,"checkbox records pending opt-out")
resourceCardsConfirmCombatWounds(player,"CombatDamageConfirmCancel")
eq(gStates.combatDamageSkipConfirmationByColor,nil,
    "Cancel does not suppress the next confirmation")
resourceCardsRequestCombatWounds(player)
eq(attrs["CombatDamageConfirm:active"],"true","Cancel retains normal confirmation")
resourceCardsCombatWoundsSkipChanged(player,"True","CombatDamageConfirmDontShowAgain")
resourceCardsConfirmCombatWounds(player,"CombatDamageConfirmApply")
eq(gStates.combatDamageSkipConfirmationByColor,nil,
    "pre-checkpoint confirmation has not persisted opt-out")
capturedSnapshot.callback()
eq(settle.ready(),true,"opt-out commit Wound settles")
settle.done()
eq(gStates.combatDamageSkipConfirmationByColor.Red,true,
    "successful commit saves opt-out for the player colour")
eq(gStates.combatDamageSkipConfirmationByColor.Blue,nil,
    "opt-out is not applied to other players")
gStates.combatWoundApplication=nil
combatConfig.woundRecordPreview(1,{{key="auto:1"}},{
    ["auto:1"]={heroWounds=1,discard=0}})
local beforeAuto=capturedSnapshot
resourceCardsRequestCombatWounds(player)
eq(attrs["CombatDamageConfirm:active"],"false",
    "opted-out player commits without reopening confirmation")
eq(combatConfig.woundTransactionPending,true,
    "automatic confirmation still waits for a new rewind snapshot")
assert(capturedSnapshot~=beforeAuto,"automatic confirmation starts a new rewind snapshot")
capturedSnapshot.callback()
eq(settle.ready(),true,"automatic confirm Wound settles")
settle.done()
eq(combatConfig.woundTransactionPending,false,"automatic commit completes normally")

-- Regression: an earlier Block remains fixed when its card leaves play;
-- playing the same GUID again cannot produce a second Block or more Attack.
local phaseSources=isolated(recognition,
    "local function combatFrozenCopy(value)",
    "combatConfig.captureParalyzedUnitSources=function",
    "return combatPhaseLockSources")
local original={guid="played",key="played",name="Played",kind="card",
    ranged=0,siege=0,block=2,attack=2,move=0,psychicInfluence=0,
    resources={block=2,attack=2},
    details={{family="block",key="block",amount=2},
        {family="attack",key="attack",amount=2}}}
local wound={guid="wound",key="wound",name="Fresh Wound",kind="wound",
    ranged=0,siege=0,block=3,attack=4,move=0,psychicInfluence=0,
    resources={block=3,attack=4},
    details={{family="block",key="block",amount=3},
        {family="attack",key="attack",amount=4}}}
local lock={sources={original},sourceKeys={played=true},spentRange={}}
local onlyWound=phaseSources(lock,{wound})
local byKey={}
for _,source in ipairs(onlyWound) do byKey[source.key]=source end
eq(byKey.played.block,2,"earlier Block remains after card returns to hand")
eq(byKey.played.noAttackPhase,true,"committed source not reused in Attack")
eq(byKey.wound.block,0,"Damage-phase Wound cannot retroactively Block")
eq(byKey.wound.attack,4,"new Wound may Attack with a legal linked Skill")
eq(byKey.wound.damagePhaseWound,true,"late Wound cannot join Ranged/Siege")
local replay=combatFrozenCopy(original)
replay.block=99 replay.attack=99 replay.resources.block=99
replay.resources.attack=99
replay.details[2].amount=99
local repeated=phaseSources(lock,{replay})
eq(repeated[1].block,2,"replayed GUID retains original Block")
eq(repeated[1].attack,0,"frozen early source has no second Attack")
eq(repeated[2].key,"played#postDamage","later Attack separated")
eq(repeated[2].attack,2,"replayed GUID cannot inflate original Attack")
eq(repeated[2].resources.attack,2,"late Attack resource itself is capped")
local unusedBlock=phaseSources({sources={original},sourceKeys={},spentRange={}},
    {{guid="played",key="played",name="Played",kind="card",
        ranged=0,siege=0,block=2,attack=4,move=0,psychicInfluence=0,
        resources={block=2,attack=4},details={{family="attack",key="attack",amount=4}}}})
eq(#unusedBlock,1,"unspent Block does not create a frozen early source")
eq(unusedBlock[1].block,0,"unspent Block cannot retroactively Block")
eq(unusedBlock[1].attack,4,"unspent Block may be changed to a later Attack")
eq(unusedBlock[1].phaseAfterDamage,true,"changed source is Attack-phase only")
assert(fileText("src/PlayingGame/PlayerBoard/ResourceTracker/Interface/CombatRowRenderer.lua"):find('item.source.phaseLocked and "false" or "true"',1,true),
    "frozen calculator icons must not be clickable")
assert(fileText("src/PlayingGame/PlayerBoard/ResourceTracker/Interface/CardControls.lua"):find('combatConfig.phaseObjectLocked(card.guid)',1,true)
    and fileText("src/PlayingGame/PlayerBoard/ResourceTracker/Interface/UnitControls.lua"):find('combatConfig.phaseObjectLocked(unit.guid)',1,true),
    "locked cards and Units must lose choice and target controls")
local assignments=fileText("src/PlayingGame/Combat/AttackAssignments.lua")
assert(assignments:find('lock.positions or {}',1,true)
    and assignments:find('(lock.sourceKeys or {})[entry.sourceGUID]==true',1,true)
    and assignments:find('combatCommittedSource(entry.sourceGUID)',1,true),
    "only committed arrows stay frozen; unused Block arrows may still move")
assert(assignments:find('function attackAssignmentsDamageSnapshot()',1,true)
    and assignments:find('if lock~=nil then',1,true),
    "Damage targets must persist and be non-interactive after commit")

-- Exercise the real Block optimiser: spare and failed Blocks must not
-- lock their sources, while Block points used for success and Cumbersome
-- Move reductions must remain committed.
local blockConfig={sourceFields={{key="block",family="block"}},
    COMBAT_EFFICIENT_BLOCKS={P={block=true}},COMBAT_RED="red"}
local blockSolver=dofile("src/PlayingGame/PlayerBoard/ResourceTracker/Combat/BlockCalculation.lua").solver(blockConfig)
local blockEngine=dofile("src/PlayingGame/PlayerBoard/ResourceTracker/Combat/BlockCalculation.lua").results(blockConfig,blockSolver,
    function(enemy) return enemy.attacks end,function() return 0 end,
    function(value) return value end)
local blockCache={}
local function blockResult(enemy,sources)
    return blockEngine(enemy,sources,blockCache)
end
local function testEnemy(guid,cumbersome)
    return {guid=guid,attacks={{owner=guid,slot=1,key="P",value=5,
        cumbersome=cumbersome==true}}}
end
local function blockSource(guid,amount)
    return {key=guid,guid=guid,block=amount,move=0,
        resources={block=amount}}
end
local function moveSource(guid,amount)
    return {key=guid,guid=guid,block=0,move=amount,moveCounts=true,resources={}}
end
local function effective(enemy,sources)
    local _,_,_,_,_,_,_,_,_,_,usedBlockKeys,usedMoveKeys=blockResult(enemy,sources)
    return usedBlockKeys,usedMoveKeys
end
local failed=effective(testEnemy("failed"),{blockSource("b2",2)})
eq(failed.b2,nil,"an ineffective partial Block must remain editable")
local spare=effective(testEnemy("spare"),{blockSource("b5",5),blockSource("b1",1)})
eq(spare.b5,true,"successful Block source is committed")
eq(spare.b1,nil,"spare Block must remain editable")
local together=effective(testEnemy("together"),{blockSource("b4",4),blockSource("b1",1)})
eq(together.b4,true,"first contributing Block is committed")
eq(together.b1,true,"second contributing Block is committed")
local _,moved=effective(testEnemy("cumbersome",true),{moveSource("m2",2)})
eq(moved.m2,true,"effective Cumbersome Move reduction is committed")
local swapEnemy=testEnemy("swap",true)
local _,firstMove=effective(swapEnemy,{moveSource("moveA",2)})
local _,replacementMove=effective(swapEnemy,{moveSource("moveB",2)})
eq(firstMove.moveA,true,"initial Move source committed")
eq(replacementMove.moveB,true,"same-valued replacement Move source committed")
eq(replacementMove.moveA,nil,"cache cannot retain a departed Move source")
assert(fileText("src/PlayingGame/PlayerBoard/ResourceTracker/Combat/EarlyCombatPhase.lua"):find("preview.sourceKeys={}",1,true)
    and fileText("src/PlayingGame/PlayerBoard/ResourceTracker/Combat/EarlyCombatPhase.lua"):find("block.successfulSourceKeys",1,true)
    and fileText("src/PlayingGame/PlayerBoard/ResourceTracker/Combat/EarlyCombatPhase.lua"):find("block.spentMoveKeys",1,true),
    "phase lock must be derived from actual successful Block and Move use")

-- Exercise the production rewind guard itself (not just the commit
-- coordinator stub): storage is requested once, owners stay blocked through
-- the scripted work, and failed storage never starts the destructive action.
local shared=fileText("src/Shared.lua")
local checkpoints,allowed,waiting=0,0,nil
storeRewindState=function(callback,block)
    checkpoints=checkpoints+1
    eq(block,true,"damage transaction must block further rewind stores")
    waiting=callback
end
allowRewindStore=function() allowed=allowed+1 end
safeWaitTime=function() return 1 end
broadcastToAll=function() end
isolated(shared,"local rewindTransactionStorePending=false",
    "--Return one loose card to the bottom of a live deck")
eq(rewindTransactionCanStartFresh(),true,"new transaction can begin fresh")
local mutation=0
rewindTransactionStart(function() mutation=mutation+1 end,"Damage transaction")
eq(checkpoints,1,"rewind snapshot requested before mutation")
eq(mutation,0,"no mutation while snapshot is pending")
eq(rewindTransactionCanStartFresh(),false,"no overlapping checkpoint")
waiting(true,false) -- TTS also succeeds when no new state was necessary.
eq(mutation,1,"snapshot success permits damage")
eq(rewindTransactionCanStartFresh(),false,"rewind stays blocked through commit")
rewindTransactionFinish("Damage transaction")
eq(allowed,1,"rewind automatically restored after physical completion")
eq(rewindTransactionCanStartFresh(),true,"next transaction can start fresh")
local rejected=0
rewindTransactionStart(function() mutation=mutation+1 end,"Failed transaction",
    function() rejected=rejected+1 end)
waiting(false,false)
eq(mutation,1,"failed snapshot must not permit physical mutations")
eq(rejected,1,"snapshot failure callback invoked")
eq(rewindTransactionCanStartFresh(),true,"snapshot failure releases pending state")

print("Combat Wound application regressions passed")

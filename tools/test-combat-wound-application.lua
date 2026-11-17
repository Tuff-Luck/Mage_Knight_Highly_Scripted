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
isolated(recognition,"combatConfig.woundLedger=function(seat)",
    "local function combatDamageNotes")

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
assert(fileText("src/PlayingGame/Combat.lua"):find(
    "attackAssignmentsUnitPreviewCommit",1,true),"Unit preview still commits at End Turn")

-- The explicit Draw Wounds UI refresh must not re-count all enemy rewards:
-- temporary movement through the thin combat zone could otherwise revoke Fame.
local ui=fileText("src/PlayingGame/UI.lua")
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
assert(not recognition:find('summaryWidth',1,true),
    "No dynamic preferredWidth writes should fight TTS's anchored position")
assert(recognition:find('"Draw: "..combatRich',1,true),
    "Wound button should be labelled Draw")
print("Combat Wound application regressions passed")

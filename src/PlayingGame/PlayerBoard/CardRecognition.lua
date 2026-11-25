-- The physical play area supplies estimated resources to the Resource Tracker.
-- Runtime-only observations never overwrite the saved manual +/- adjustments.
resourceCardScanBySeat={}
local trackerPrivate=require("PlayingGame.PlayerBoard.ResourceTracker.Core.State")()
trackerPrivate.combatTargetPolicy=require("PlayingGame.PlayerBoard.ResourceTracker.Combat.CombatTargetPolicy")
trackerPrivate.combatInteraction=require("PlayingGame.PlayerBoard.ResourceTracker.Combat.CombatInteraction")
trackerPrivate.playedCardScan=require("PlayingGame.PlayerBoard.ResourceTracker.Cards.PlayedCardScan")
trackerPrivate.cardInteractions=require("PlayingGame.PlayerBoard.ResourceTracker.Cards.CrossCardEffects")
trackerPrivate.skillInteractions=require("PlayingGame.PlayerBoard.ResourceTracker.Cards.SkillInteractions")
trackerPrivate.unitScan=require("PlayingGame.PlayerBoard.ResourceTracker.Units.UnitScan")
trackerPrivate.unitManagement=require("PlayingGame.PlayerBoard.ResourceTracker.Units.UnitManagement")
trackerPrivate.readyPolicy=require("PlayingGame.PlayerBoard.ResourceTracker.Units.ReadyPolicy")
trackerPrivate.scanObservation=require("PlayingGame.PlayerBoard.ResourceTracker.Scanning.ScanObservation")
trackerPrivate.scanPayments=require("PlayingGame.PlayerBoard.ResourceTracker.Scanning.ScanPayments")
trackerPrivate.scanFinalization=require("PlayingGame.PlayerBoard.ResourceTracker.Scanning.ScanFinalization")
trackerPrivate.factionRewardScan=require("PlayingGame.PlayerBoard.ResourceTracker.Scanning.FactionRewardScan")
trackerPrivate.scanPublication=require("PlayingGame.PlayerBoard.ResourceTracker.Scanning.ScanPublication")
trackerPrivate.scanScheduler=require("PlayingGame.PlayerBoard.ResourceTracker.Core.TrackerLifecycle").scheduler
trackerPrivate.trackerLifecycle=require("PlayingGame.PlayerBoard.ResourceTracker.Core.TrackerLifecycle").lifecycle
trackerPrivate.objectEvents=require("PlayingGame.PlayerBoard.ResourceTracker.Core.ObjectEvents")
trackerPrivate.cardInteraction=require("PlayingGame.PlayerBoard.ResourceTracker.Cards.CardCallbacks")
-- Keep the public chat callback here; diagnostics share this live private state.
require("PlayingGame.PlayerBoard.ResourceTracker.Core.Diagnostics")(trackerPrivate)
function resourceCardsTraceCommand(command,playerColor)
    return trackerPrivate.traceCommand(command,playerColor)
end
local shown={}
-- Runtime choices are kept here; explicit played choices are serialized by TrackerLifecycle.
local selectedResourceByGUID={}
-- Retain the chosen crystal-pair Attack after Sacrifice converts the pairs to mana.
-- Uses combatConfig.sacrificeCastPairs to avoid Lua 5.2's 200-local module limit.
-- Display state is separate from player selections. Picks/drops may clear the
-- buttons, but the chosen resource stays until the script reloads.
local choiceExpandedByGUID={}
local choiceButtonShown={}
local unitManaDecision
local factionRewardForObject
-- Catalog is defined once in UnitResources.lua and keyed by card GUID.
local unitResourceDefinitions=unitResourceDefinitions
-- Full-size Artifacts use the saved THROW/RECOVER choice when face up.
-- Physical face-down also means Throw, but must remain reversible without
-- modifying an earlier button choice. Half Banners use their back to mean
-- 'spent', not 'thrown away'.
function resourceCardsArtifactBroken(guid,card)
    local data=gameCards~=nil and gameCards[guid] or nil
    if data==nil or data.cardType~="Artifact" or data.full~=nil then return false end
    local state=gStates~=nil and gStates.artifactBreaks or nil
    local chosen=type(state)=="table" and state[guid] or nil
    local obj=card or getObjectFromGUID(guid)
    return (obj~=nil and obj.is_face_down==true) or chosen==true
end

function resourceCardsArtifactBreakClear(guid)
    if gStates~=nil and gStates.artifactBreaks~=nil then
        gStates.artifactBreaks[guid]=nil
    end
end

-- Persist one-shot Banner uses through save/rewind, resetting only at new Round.
trackerPrivate.bannerEffectUses=function()
    if gStates==nil then return {fortitude={},courage={},healing={}} end
    local round=tonumber(gStates.currentRound) or 0
    local uses=gStates.bannerArtifactUses
    if type(uses)~="table" or uses.round~=round then
        uses={round=round,fortitude={},courage={},healing={}}
        gStates.bannerArtifactUses=uses
    end
    uses.fortitude=uses.fortitude or {}
    uses.courage=uses.courage or {}
    uses.healing=uses.healing or {}
    return uses
end

-- The same printed Banner has two TTS card states with different rules:
-- full-size = playable Artifact (saved toggle means Break), half-size =
-- attached to a Unit (face down means its basic effect was spent).
-- Never infer which effect was used from is_face_down alone.
trackerPrivate.bannerCardForm=function(guid)
    local data=gameCards~=nil and gameCards[guid] or nil
    if data==nil or data.cardType~="Artifact"
        or type(data.resourceKey)~="string"
        or data.resourceKey:sub(1,14)~="artifactBanner" then return nil end
    if data.full~=nil then return "half" end
    if data.half~=nil then return "full" end
    return nil
end
trackerPrivate.bannerStrongActive=function(card)
    return card~=nil and trackerPrivate.bannerCardForm(card.guid)=="full"
        and resourceCardsArtifactBroken(card.guid,card)
end
-- Attached halves are not separate played actions. This also protects
-- direct calculateCard() callers, even when a thin play-zone overlaps a Unit.
trackerPrivate.bannerAttachedCardResult=function(guid)
    if trackerPrivate.bannerCardForm(guid)~="half" then return nil end
    return {guid=guid,known=true,complete=true,powered=false,
        links={},status="blue",resources=nil}
end

-- An attached Banner of Fear adds a selectable, non-printed Unit
-- activation. Do not alter the shared per-type Unit catalog.
trackerPrivate.unitAbilitiesFor=function(guid,state,seatPos)
    local printed=unitResourceDefinitions~=nil and unitResourceDefinitions[guid] or nil
    if printed==nil then return nil end
    state=state or (seatPos~=nil and unitLayoutResourceState(seatPos) or nil)
    local banners=state~=nil and state.bannersByUnit~=nil
        and state.bannersByUnit[guid] or nil
    local fear=banners~=nil and banners["Banner of Fear"] or nil
    -- Spending the Unit may turn the half-card face down. That is the
    -- basic effect in progress, not a Break; re-readying the Unit permits
    -- another Fear use even during the same Round.
    if fear==nil then return printed end
    local abilities={}
    for key,value in pairs(printed) do abilities[key]=value end
    local index=#printed+1
    abilities[index]={row=99,key="bannerFear",buttonLabel="FEAR",
        enemyEffect={cancelOneAttack=true},bannerFear=true}
    abilities.bannerFearIndex=index
    return abilities
end
trackerPrivate.commandPickupForUnits={}
-- Mana payments use current scripting-zone membership, not outside-zone recovery.
-- Rebuilt with the live Unit layout for each Resource Tracker scan.
-- Unit outlines require a Command token physically on the card and a valid
-- activation this turn. Wounds and site restrictions also suppress outlines.
trackerPrivate.unitHighlightBlocked={}

-- Minimizing is OFF: no play-area scanning, Unit automation or tracker overlays.
-- Reopening starts a new tracking session using the physical table.
trackerPrivate.trackerWasDisabled=false
trackerPrivate.trackerSession=0
trackerPrivate.trackerStartupRequest=0
trackerPrivate.restoreAssignmentsPending=false
-- Preferences are saved per seat; older saves default to automation enabled.
function resourceCardsSeatEnabled(seat)
    local settings=gStates~=nil and gStates.resourceTrackerEnabledBySeat or nil
    return seat~=nil and (settings==nil or settings[seat]~=false)
end

function resourceCardsSetSeatEnabled(enabled)
    local current=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    if current==nil or current.seatPos==nil then return end
    if type(gStates.resourceTrackerEnabledBySeat)~="table" then
        gStates.resourceTrackerEnabledBySeat={true,true,true,true}
    end
    gStates.resourceTrackerEnabledBySeat[current.seatPos]=enabled==true
end

-- Observers cannot change resources, target arrows, damage allocations or layout.
-- Black may act as GM only when actually seated.
function resourceCardsPlayerCanEdit(color)
    if type(color)~="string" or color=="Grey" then return false end
    local current=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    if current==nil or current.seatPos==nil then return false end
    local player=Player[color]
    if player==nil or player.seated~=true then return false end
    if color=="Black" then return true end
    return legalPlayerCheck(color,current.seatPos,"NoDummyException")==true
end
-- The UI may update a frame after the click. Keep its visible state separate
-- from the immediate OFF latch so delayed events cannot restart scanning.
function resourceCardsPanelReady()
    return gStates~=nil and gStates.firstStarted==true
        and UI.getAttribute("ResourceTracker","active")=="true"
        and UI.getAttribute("ResourceTrackerDetail","active")=="true"
        -- The compact panel can legitimately be shorter than 200px with few/no resources.
        -- Only the collapsed 35px header indicates that the content is not yet ready.
        and (tonumber(UI.getAttribute("ResourceTracker","height")) or 0)>35
end

function resourceCardsPanelOpen()
    local current=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    return not trackerPrivate.trackerWasDisabled and resourceCardsPanelReady()
        and current~=nil and resourceCardsSeatEnabled(current.seatPos)
end

-- An outgoing hand Wound is not necessarily a Heal. Cure's additional
-- draws are player-confirmed, including Wounds healed before the cast.
function resourceCardsCureCanDraw(color)
    if not resourceCardsPanelOpen() or not resourceCardsPlayerCanEdit(color) then return false end
    local active=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    local scan=active~=nil and resourceCardScanBySeat[active.seatPos] or nil
    local record=scan~=nil and scan.cards["47e71c"] or nil
    return record~=nil and record.complete==true and record.powered~=true
        and record.resources~=nil and (record.resources.healing or 0)>0
end

local function resourceCardsDetailsOpen()
    return resourceCardsPanelOpen()
end

-- Keep combat constants in one private table: luabundle adds four parameters
-- to each module, which also count toward Lua 5.2's 200 active-local limit.
local combatConfig={}
combatConfig.amuletMana={gold=false,black=false}
combatConfig.artifactCombat={sword=false,bow=false,bowMode="double",
    swordFame=false,bowFame=false}
combatConfig.sacrificeCastPairs={}
combatConfig.enemyDefenceTraits={
    {"fortified","Fortified"},{"unfortified","Unfortified"},{"elusive","Elusive"},
    {"arcaneImmunity","Arcane Immunity"},{"pResist","Physical Resist"},
    {"fResist","Fire Resist"},{"iResist","Ice Resist"},{"mResist","Psychic Resist"}
}
combatConfig.enemyOffenceTraits={
    {"swiftness","Swiftness"},{"brutal","Brutal"},{"poison","Poison"},
    {"paralyse","Paralyse"},{"assassination","Assassination"},
    {"cumbersome","Cumbersome"},{"vampiric","Vampiric"}
}
combatConfig.sourceFields={
    {key="ranged",family="ranged",type="Physical Range",icon="MKChoiceRanged"},
    {key="rangedFire",family="ranged",type="Fire Range",icon="MKChoiceRanged"},
    {key="rangedIce",family="ranged",type="Ice Range",icon="MKChoiceRanged"},
    {key="rangedColdFire",family="ranged",type="Cold Fire Range",icon="MKChoiceRanged"},
    {key="rangedPsychic",family="ranged",type="Psychic Range",icon="MKChoiceRanged"},
    {key="siege",family="siege",type="Physical Siege",icon="MKChoiceSiege"},
    {key="siegeFire",family="siege",type="Fire Siege",icon="MKChoiceSiege"},
    {key="siegeIce",family="siege",type="Ice Siege",icon="MKChoiceSiege"},
    {key="siegeColdFire",family="siege",type="Cold Fire Siege",icon="MKChoiceSiege"},
    {key="siegePsychic",family="siege",type="Psychic Siege",icon="MKChoiceSiege"},
    {key="block",family="block",type="Physical Block",icon="MKChoiceBlock"},
    {key="blockFire",family="block",type="Fire Block",icon="MKChoiceBlock"},
    {key="blockIce",family="block",type="Ice Block",icon="MKChoiceBlock"},
    {key="blockColdFire",family="block",type="Cold Fire Block",icon="MKChoiceBlock"},
    {key="blockPsychic",family="block",type="Psychic Block",icon="MKChoiceBlock"},
    {key="attack",family="attack",type="Physical Attack",icon="MKChoiceAttack"},
    {key="attackFire",family="attack",type="Fire Attack",icon="MKChoiceAttack"},
    {key="attackIce",family="attack",type="Ice Attack",icon="MKChoiceAttack"},
    {key="attackColdFire",family="attack",type="Cold Fire Attack",icon="MKChoiceAttack"},
    {key="attackPsychic",family="attack",type="Psychic Attack",icon="MKChoiceAttack"}
}
-- A source locks to the nearest enemy when first targeted and stays there until retargeted.
-- "explicit" holds sources the player aimed by hand; Move resources are only ever counted that way.
local combatAssignmentState={seat=nil,selected=nil,targets={},explicit={}}
-- Fame/Reputation currently earned by defeating enemies in the calculator; the scan adds its own fixed part.
local combatDefeatFameRep={fame=0,rep=0}

-- Interaction is an explicit choice, but its powered bonus follows the live
-- card scan. A temporarily absent card keeps its last earned reward; removing
-- mana from a card still in play must retract only the powered part.
local function resourceCardsSyncInteractionPower(records)
    for guid,selected in pairs(gStates.startingCardSelections or {}) do
        local data=gameCards[guid]
        local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
        local record=records[guid]
        if selected.interaction==true and rule~=nil
            and rule.interactionReward~=nil and record~=nil
            and record.complete and record.resources~=nil then
            selected.interactionPowered=record.powered==true or nil
        end
    end
end

-- Conditional effects are earned by the player's explicit choice, not merely
-- by a card lying in the play area. Once earned, they survive repositioning
-- that card or minimizing the tracker until the end-of-turn commit.
combatConfig.startingCardConditionalFameRep=function()
    local fame,rep=0,0
    for guid,selected in pairs(gStates~=nil and gStates.startingCardSelections or {}) do
        local data=gameCards~=nil and gameCards[guid] or nil
        local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
        if rule~=nil then
            if selected.interaction==true and rule.interactionReward~=nil then
                local reward=selected.interactionPowered==true
                    and rule.interactionReward.powered or rule.interactionReward.normal
                fame=fame+(reward.fame or 0)
                rep=rep+(reward.rep or 0)
            end
            if selected.recruited==true and rule.recruitDiscount~=nil then
                rep=rep+(rule.recruitRepPenalty or 0)
            end
        end
    end
    return fame,rep
end

-- The basic Ruthless Coercion recruitment discount is player-declared.
-- Give the player two more Influence to spend manually rather than
-- attempting to identify or discount the recruited Unit's offer cost.
local function resourceCardsRecruitInfluenceBonus(guid,rule,record)
    if rule==nil or rule.recruitDiscount==nil or record==nil
        or record.powered==true or record.complete~=true
        or record.resources==nil then return 0 end
    local selected=gStates~=nil and gStates.startingCardSelections~=nil
        and gStates.startingCardSelections[guid] or nil
    return selected~=nil and selected.recruited==true
        and (tonumber(rule.recruitDiscount) or 0) or 0
end

-- One owner for the pending Fame/Reputation this seat's played sources provide (scan part + defeat part).
local function resourceCardsApplyFameRep(seat)
    local scan=seat~=nil and resourceCardScanBySeat[seat] or nil
    local player=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    if player==nil or player.seatPos~=seat then return end
    local base=scan~=nil and scan.fameRepBase or nil
    resourceFameRepApply(gStates.turnNumber,
        (base~=nil and base.fame or 0)+combatDefeatFameRep.fame,
        (base~=nil and base.rep or 0)+combatDefeatFameRep.rep)
end
-- The calculator runs only while the Resource Tracker details are open and an enemy is in play.
local combatCalcOn=false
local combatEnemyInPlay=false
-- Explicit boss overkill corrections are kept in save state until the
-- calculator closes. Nil selects Auto, while zero is a valid manual value.
function combatBossAutomationActive()
    return combatCalcOn==true and resourceCardsPanelOpen()
end
function combatBossSetManual(guid,value)
    if gStates==nil or guid==nil then return end
    gStates.combatBossManual=gStates.combatBossManual or {}
    if value==nil then gStates.combatBossManual[guid]=nil
    else gStates.combatBossManual[guid]=math.max(0,math.floor(tonumber(value) or 0)) end
    if combatBossAutomationActive() and resourceCardsSourceChanged~=nil then
        resourceCardsSourceChanged()
    end
end
local combatCumbersomeActive=false
local combatPsychicActive=false

-- Save each Move source's phase, never infer it again after the first scan.
-- Source role is independent of the printed resource-choice category.
local function resourceCardsMoveRole(guid,assign)
    if gStates==nil or guid==nil then return "movement" end
    gStates.resourceCardMoveRoles=gStates.resourceCardMoveRoles or {}
    local role=gStates.resourceCardMoveRoles[guid]
    if role~="movement" and role~="combat" then
        role=combatEnemyInPlay and "combat" or "movement"
        if assign then gStates.resourceCardMoveRoles[guid]=role end
    end
    return role
end
-- A Move role can be selected in any combat, not only against Cumbersome.
-- Keep an already committed source editable after combat ends; do not
-- automatically transfer its points to the movement pool.
combatConfig.moveRoleForUI=function(guid) return resourceCardsMoveRole(guid,false) end
combatConfig.moveRoleAvailable=function(guid)
    return combatCalcOn or combatEnemyInPlay
        or (gStates~=nil and gStates.resourceCardMoveRoles~=nil
            and gStates.resourceCardMoveRoles[guid]=="combat")
end
function resourceCardsEnemyPresent()
    return combatEnemyInPlay==true
end
local combatAssignmentJoined={}
local combatAssignmentSlotSources={}
combatConfig.bowSourceModes={}
combatConfig.slotBowFamilies={}
-- Effect-only buttons share the resource slots, without adding any Block/Attack.
combatConfig.effectSources={}
combatConfig.blockedEnemyCounts={}
local combatAssignmentRowTargets={}
local combatEnemyPage=1
local combatAssignmentRowIndices={}
local combatExpandedResults={}
local combatReductionAttackChoice={}
local combatReductionActiveSource={}
local combatAttackChoiceByRow={}
combatConfig.resultRowCache={}
combatConfig.slotSelection={}
combatConfig.panelHeight=0
combatConfig.shutdownClean=false
combatConfig.rowCount=8 -- XML has eight reusable row controls.
combatConfig.crowdedPageSize=6
combatConfig.slotCount=12
combatConfig.lineSlotCount=6 -- Wrap each resource cell after six visible icons.
combatConfig.rowHeight=32
combatConfig.panelBaseHeight=30
combatConfig.columns={Name=120,Armour=55,Traits=150,Attacks=105,Offence=130}
-- Damage/resistance colours: normal, then the darker shade used once a value has been reduced.
combatConfig.typeColors={P={"#FFFFFF","#9A9A9A"},F={"#FF5555","#992E2E"},I={"#5AA0FF","#2F5F9A"},
    IF={"#C070FF","#74429A"},M={"#FFE055","#9A8A33"}}
combatConfig.resistTypes={pResist="P",fResist="F",iResist="I",mResist="M"}

-- These tokens carry attacks, but cannot themselves be attacked or defeated.
-- Volkare and trap rolls already put the current attack in gStates.monsterPerks.
combatConfig.attackOnlyReminders={
    ["Volkare Reminder Token"]={name="Volkare's Attack",armour=0,attackOnly=true},
    ["Trap Reminder Token"]={name="Trap",armour=0,attackOnly=true}
}
-- Co-op Leader planning copies have no monsterPugs entry. Read the current
-- real Leader's data without registering a clone as an actual enemy.
local function combatEnemyData(guid,obj)
    local data=monsterPugs[guid]
    if data~=nil then return data end
    if gStates~=nil and gStates.coopAssaultType=="leader" then
        for _,cloneGUID in pairs(gStates.coopLeaderPreviewClones or {}) do
            if cloneGUID==guid then
                local leader=factionLeaderForCity~=nil and factionLeaderForCity(gStates.coopAssaultCityGUID) or nil
                return leader~=nil and monsterPugs[leader.token] or nil,"preview"
            end
        end
    end
    local perks=gStates~=nil and gStates.monsterPerks~=nil and gStates.monsterPerks[guid] or nil
    if perks==nil or type(perks.attack)~="table" then return nil end
    obj=obj or getObjectFromGUID(guid)
    if obj==nil then return nil end
    local reminder=combatConfig.attackOnlyReminders[obj.getGMNotes()]
    return reminder,reminder~=nil and "attackOnly" or nil
end

-- Level-based bosses keep their entered-combat characteristics even after
-- an earlier phase or cooperative participant has removed levels.
local function combatBossIdentity(guid,data,perks,mode)
    if data.pugType=="leader" then
        local realGUID=guid
        if mode=="preview" and factionLeaderForCity~=nil then
            local leader=factionLeaderForCity(gStates.coopAssaultCityGUID)
            if leader~=nil then realGUID=leader.token end
        end
        local level=realGUID==darkCrusader.token and gStates.darkCrusaderLevel
            or realGUID==elementalist.token and gStates.elementalistLevel or nil
        if level~=nil then return "leader",math.max(0,(tonumber(level) or 0)
            -(tonumber(gStates.leaderReduction) or 0)),nil end
    end
    if perks~=nil and perks.dragonGround==true
        and apocalypseDragonGroundHeadNameForGUID~=nil then
        local head=apocalypseDragonGroundHeadNameForGUID(guid)
        if head=="Control" then return "control",0,head end
        if head~=nil then return "dragon",math.max(0,tonumber(perks.dragonGroundLevel)
            or tonumber(gStates.apocalypseDragonHeadLevels[head]) or 0),head end
    end
    return nil,nil,nil
end

local function combatTypeRich(text,typeKey,reduced)
    local colors=combatConfig.typeColors[typeKey]
    if colors==nil then return text end
    return "<color="..colors[reduced and 2 or 1]..">"..text.."</color>"
end

local function combatEnemyTraitsText(data,perks,traitDefinitions)
    local traits={}
    local unfortified=data.unfortified==true or (perks~=nil and perks.unfortified==true)
    local fortified=not unfortified and
        (data.fortified==true or (perks~=nil and perks.fortified==true))
    for _,trait in ipairs(traitDefinitions) do
        if trait[1]=="fortified" and fortified then
            traits[#traits+1]=trait[2]
        elseif trait[1]=="unfortified" and unfortified then
            traits[#traits+1]=trait[2]
        elseif trait[1]~="fortified" and trait[1]~="unfortified"
            and (data[trait[1]]==true or (perks~=nil and perks[trait[1]]==true)) then
            traits[#traits+1]=combatConfig.resistTypes[trait[1]]~=nil
                and combatTypeRich(trait[2],combatConfig.resistTypes[trait[1]]) or trait[2]
        end
    end
    local defender=(tonumber(data.defend) or 0)+(perks~=nil and (tonumber(perks.defend) or 0) or 0)
    if traitDefinitions==combatConfig.enemyDefenceTraits then
        if defender>0 then traits[#traits+1]="Defender +"..tostring(defender) end
        local fortificationCount=(data.fortified==true and 1 or 0)
            +(perks~=nil and perks.fortified==true and 1 or 0)
            +(perks~=nil and perks.wallFortified==true and 1 or 0)
        if unfortified then
            fortificationCount=0
        elseif fortificationCount>1 then
            traits[#traits+1]="Double Fortified"
        elseif fortificationCount==1 and not (data.fortified==true or (perks~=nil and perks.fortified==true)) then
            traits[#traits+1]="Wall Fortified"
        end
    end
    return #traits>0 and table.concat(traits,"\n") or "None"
end

local function combatAssignmentActiveSeat()
    local active=turnOrder~=nil and gStates~=nil and gStates.turnNumber~=nil
        and turnOrder[gStates.turnNumber] or nil
    return active~=nil and active.seatPos or nil
end

-- Card effects recorded against any enemy GUID (including summoned tokens) by the active seat's scan.
local function combatEffectOf(guid)
    local seat=combatAssignmentActiveSeat()
    local scan=seat~=nil and resourceCardScanBySeat[seat] or nil
    return scan~=nil and scan.enemyEffects~=nil and scan.enemyEffects[guid] or nil
end

combatConfig.resourceOperations=require("PlayingGame.PlayerBoard.ResourceTracker.Core.ResourceOperations")

-- The single place that maps a resource key through active attack transformations (Altem Mages).
-- Cold Fire replaces the element; Siege replaces the family and keeps the element. Block is never changed.
function resourceCardsTransformedKey(key,transform)
    return combatConfig.resourceOperations.globalAttackKey(key,transform)
end

-- A primary Move/Psychic arrow owns all the points left on that physical
-- source; additional arrows transfer individual points from that same pool.
-- While such an explicit allocation exists, conversions must use OTHER
-- unassigned sources. The player can remove/retarget an arrow to free its pool.
-- Both scan-time Spell costs and calculator-time conversions use this
-- reservation policy. A saved arrow is authoritative even before the
-- calculator has reconstructed its target cache after a load.
combatConfig.sharedSpendable=function(key,amount,field,moveEligible)
    amount=math.max(0,tonumber(amount) or 0)
    if amount==0 then return 0 end
    if combatConfig.phaseKeyLocked~=nil and combatConfig.phaseKeyLocked(key) then return 0 end
    local function reserves(target)
        if field=="move" then
            local eligible=moveEligible or resourceCardsCombatTargetAcceptsMove
            return eligible~=nil and eligible(target)
        end
        return field=="influence" and combatConfig.hasPsychicAttack~=nil
            and combatConfig.hasPsychicAttack(target)
    end
    local target=combatAssignmentState.targets[key]
    if target~=nil and combatAssignmentState.explicit[key]==true and reserves(target) then return 0 end
    if attackAssignmentsTargetGUIDs~=nil then
        for guid in pairs(attackAssignmentsTargetGUIDs(key)) do
            if reserves(guid) then return 0 end
        end
    end
    return amount
end

combatConfig.sharedSourceKey=function(guid,record)
    return record.splitTargets~=nil and (guid.."#block") or guid
end

-- Player-set conversions spend only unassigned Move/Influence. A card already
-- assigned to Cumbersome or Psychic Block must not be silently cannibalised.
combatConfig.conversionFor=function(seat,kind,preview)
    if seat==nil then return nil,0,false,nil end
    local scan=seat~=nil and resourceCardScanBySeat[seat] or nil
    local cards=scan~=nil and scan.cards or nil
    local guid=kind=="agility" and "878d92" or "8c3de6"
    local active=cards~=nil and cards[guid] or nil
    local valid=active~=nil and active.combatConversion==kind
        and active.resources~=nil
    -- gStates is the save/rewind authority. Seat keys are strings to
    -- avoid sparse-array ambiguity in TTS JSON.
    if gStates==nil then return nil,0,false,nil end
    local saved=type(gStates.resourceCardConversions)=="table"
        and gStates.resourceCardConversions or {}
    local seatKey=tostring(seat)
    local state=type(saved[seatKey])=="table" and saved[seatKey] or {}
    if not preview then
        gStates.resourceCardConversions=saved
        saved[seatKey]=state
    end
    -- Normalise a missing choice before any counter is read.
    local choice=type(state[kind])=="table" and state[kind]
        or {attack=0,ranged=0,block=0,element="F"}
    if preview then
        -- Object UI is built before the current scan is published. Never
        -- clamp the saved counters from that potentially stale preview.
        local copy={}
        for key,value in pairs(choice) do
            if type(value)=="table" then
                local nested={}
                for index,item in pairs(value) do nested[index]=item end
                copy[key]=nested
            else copy[key]=value end
        end
        choice=copy
    elseif valid then
        state[kind]=choice
    else
        state[kind]=nil
        return {attack=0,ranged=0,block=0,element="F"},0,false,active
    end
    local available=0
    if valid and cards~=nil then
        for sourceGUID,record in pairs(cards) do
            local field=kind=="agility" and "move" or "influence"
            local amount=math.max(0,tonumber(record.resources~=nil and record.resources[field]) or 0)
            if kind=="agility" and amount>0 and resourceCardsMoveRole(sourceGUID,true)~="combat" then
                amount=0
            end
            -- A manually targeted source retains its entire remaining pool.
            -- Split-target cards put Move/Influence on their Block source.
            local sourceKey=combatConfig.sharedSourceKey(sourceGUID,record)
            available=available+combatConfig.sharedSpendable(sourceKey,amount,field)
        end
    end
    choice.attack=math.max(0,math.floor(tonumber(choice.attack) or 0))
    choice.ranged=math.max(0,math.floor(tonumber(choice.ranged) or 0))
    choice.block=math.max(0,math.floor(tonumber(choice.block) or 0))
    if kind=="agility" then
        choice.attack=math.min(choice.attack,available)
        choice.ranged=math.min(choice.ranged,math.floor((available-choice.attack)/2))
    else
        local repeatLink=active~=nil and active.repeatLink or nil
        if valid and repeatLink~=nil and repeatLink.count>1 then
            -- Each copied Diplomacy may select its own elemental Block.
            -- Its counters spend distinct points from ONE Influence pool.
            local uses=repeatLink.count
            if type(choice.blockUses)~="table" then
                choice.blockUses={[1]=choice.block}
            end
            if type(choice.elementUses)~="table" then
                choice.elementUses={[1]=choice.element}
            end
            choice.block=0
            for index=1,uses do
                local count=math.max(0,math.floor(tonumber(choice.blockUses[index]) or 0))
                count=math.min(count,math.max(0,available-choice.block))
                choice.blockUses[index]=count
                choice.elementUses[index]=choice.elementUses[index]=="I" and "I" or "F"
                choice.block=choice.block+count
            end
            choice.useCount=uses
        else
            choice.useCount=1
            choice.block=math.min(choice.block,available)
        end
    end
    return choice,available,valid,active
end

local function combatAssignmentSources(seat)
    local scan=seat~=nil and resourceCardScanBySeat[seat] or nil
    local transform=scan~=nil and scan.attackTransforms or nil
    local sources={}
    for guid,record in pairs(scan~=nil and scan.cards or {}) do
        if record.resources~=nil then
            local source=nil
            local effective={}
            for key,amount in pairs(record.resources) do
                if type(amount)=="number" then
                    local newKey=resourceCardsTransformedKey(key,transform)
                    effective[newKey]=(effective[newKey] or 0)+amount
                end
            end
            -- A split card (record.splitTargets) offers one source per resource family so each
            -- can be aimed independently; the key is "guid#family" and guid stays the card.
            local parts={}
            local function ensureSource(family)
                local part=record.splitTargets~=nil and family or nil
                local slot=part or ""
                local source=parts[slot]
                if source==nil then
                    local physicalGUID=record.sourceObjectGUID or guid
                    local cardData=gameCards[physicalGUID]
                    local sourceName=record.kind=="factionReward" and record.nameKey
                        or (cardData~=nil and cardData.name or nil)
                    if type(sourceName)=="table" then sourceName=sourceName[1] end
                    source={guid=physicalGUID,key=part~=nil and (guid.."#"..part) or guid,part=part,
                        name=tostring(sourceName or record.kind or "Resource")
                            ..(record.activationIndex~=nil and (" ("..record.activationIndex..")") or ""),
                        ranged=0,siege=0,block=0,attack=0,move=0,
                        psychicInfluence=0,psychicInfluenceCounts=false,details={},
                        resources=record.splitTargets~=nil and {} or effective,
                        swiftDouble=record.swiftDouble==true,
                        excessBlockArmour=record.excessBlockArmour==true,
                        defeatFameRep=record.defeatFameRep,
                        gloryFame=record.gloryFame,
                        heroPsychicBlock=scan~=nil and scan.heroPsychicBlock==true and record.kind~="unit",
                        repeatBlocks=record.repeatBlocks,
                        ambushFirstBlockBonus=record.ambushFirstBlockBonus,kind=record.kind,
                        conditionalFireAttack=record.conditionalFireAttack,
                        flameWave=record.flameWave,
                        explosiveBolt=record.explosiveBolt,
                        dodgeConditional=record.dodgeConditional==true,
                        possessExclude=record.possessEnemyGUID,
                        dueling=guid=="7d1c32",
                        damagePhaseWound=gStates~=nil and gStates.combatWoundApplication~=nil
                            and gStates.combatWoundApplication.cards~=nil
                            and gStates.combatWoundApplication.cards[physicalGUID]==true}
                    parts[slot]=source
                    sources[#sources+1]=source
                end
                return source
            end
            for _,field in ipairs(combatConfig.sourceFields) do
                local amount=tonumber(effective[field.key]) or 0
                if amount>0 then
                    local source=ensureSource(field.family=="block" and "block" or "attack")
                    local resourceFamily=field.family
                    source[resourceFamily]=source[resourceFamily]+amount
                    if record.splitTargets~=nil then source.resources[field.key]=amount end
                    local typeKey="P"
                    if field.key:find("ColdFire$") then typeKey="IF"
                    elseif field.key:find("Fire$") then typeKey="F"
                    elseif field.key:find("Ice$") then typeKey="I"
                    elseif field.key:find("Psychic$") then typeKey="M" end
                    source.details[#source.details+1]={text=field.type.." "..tostring(amount),
                        amount=amount,icon=field.icon,key=field.key,family=field.family,typeKey=typeKey}
                end
            end
            -- Burning Shield's normal effect triggers a later Fire Attack only
            -- if its Block helped block an attack. Keep that Attack as its own
            -- independently targetable source, rather than attaching it to the
            -- enemy whose attack was blocked.
            if record.conditionalFireAttack~=nil and record.splitTargets~=nil then
                local amount=math.max(0,tonumber(record.conditionalFireAttack) or 0)
                if amount>0 then
                    local counter=ensureSource("attack")
                    counter.conditionalFireAttack=nil
                    counter.conditionalCounterattack=amount
                    -- The potential Attack must exist during target assignment;
                    -- its value is checked against successful Blocks below.
                    counter.attack=amount
                    counter.resources.attackFire=amount
                    counter.details[#counter.details+1]={
                        text="Fire Attack "..tostring(amount).." (requires successful Block)",
                        amount=amount,icon="MKChoiceAttack",key="attackFire",
                        family="attack",typeKey="F"}
                end
            end
            local moveAmount=tonumber(record.resources.move) or 0
            if moveAmount>0 and resourceCardsMoveRole(guid,true)=="combat" then
                local source=ensureSource("block")
                source.move=moveAmount
                if record.splitTargets~=nil then source.resources.move=moveAmount end
                source.details[#source.details+1]={text="Move "..tostring(moveAmount),
                    amount=moveAmount,icon="MKChoiceMove",key="move",family="move"}
            end
            local psychicInfluence=tonumber(effective.influence) or 0
            if combatPsychicActive and psychicInfluence>0 then
                local source=ensureSource("block")
                source.psychicInfluence=psychicInfluence
                source.details[#source.details+1]={text="Influence "..tostring(psychicInfluence).." → Psychic Block",
                    amount=psychicInfluence,icon="MKChoiceBlock",key="influence",family="influence"}
            end
            -- Forked Lightning is three independent Cold Fire Ranged Attack 1
            -- effects, never a single Ranged Attack 3 against one enemy.
            if record.forkedLightning then
                local forkKey=resourceCardsTransformedKey("rangedColdFire",transform)
                local forkFamily=forkKey:sub(1,5)=="siege" and "siege" or "ranged"
                local count=math.min(3,math.max(0,math.floor(tonumber(effective[forkKey]) or 0)))
                for i=#sources,1,-1 do
                    if sources[i].guid==guid then table.remove(sources,i) end
                end
                local forkField=nil
                for _,field in ipairs(combatConfig.sourceFields) do
                    if field.key==forkKey then forkField=field break end
                end
                for point=1,count do
                    sources[#sources+1]={guid=guid,key=guid.."#fork"..point,
                        part="fork"..point,name="Forked Lightning "..point,
                        ranged=forkFamily=="ranged" and 1 or 0,
                        siege=forkFamily=="siege" and 1 or 0,
                        block=0,attack=0,move=0,
                        resources={[forkKey]=1},psychicInfluence=0,
                        psychicInfluenceCounts=false,kind="skill",forkedLightning=true,
                        details={{text="Cold Fire "..forkFamily.." Attack 1",amount=1,
                            icon=forkField~=nil and forkField.icon or "MKChoiceRanged",
                            key=forkKey,family=forkFamily,typeKey="IF"}}}
                end
            end
        end
    end
    local agility,_,agilityOn=combatConfig.conversionFor(seat,"agility")
    local diplomacy,_,diplomacyOn=combatConfig.conversionFor(seat,"diplomacy")
    -- Reserve points already committed to Cumbersome/Psychic; consume only
    -- the otherwise available pool. Existing sources cannot count twice.
    local lateMoveSpent=0
    local function consumeShared(field,amount)
        -- Source records originate in a pairs() scan. Consume unassigned
        -- points in a stable order so rescans cannot move the conversion
        -- between physical cards (or change its Damage-phase timing).
        local ordered={}
        for _,source in ipairs(sources) do
            local value=field=="move" and source.move or source.psychicInfluence
            if value~=nil and value>0 then ordered[#ordered+1]=source end
        end
        table.sort(ordered,function(a,b) return a.key<b.key end)
        for _,source in ipairs(ordered) do
            if amount<=0 then break end
            local value=field=="move" and source.move or source.psychicInfluence
            if value~=nil and value>0 then
                local spendable=combatConfig.sharedSpendable(source.key,value,field)
                local consumed=math.min(spendable,amount)
                if field=="move" and source.damagePhaseWound then lateMoveSpent=lateMoveSpent+consumed end
                local remaining=value-consumed
                if field=="move" then source.move=remaining
                else source.psychicInfluence=remaining end
                if source.resources~=nil then source.resources[field== "move" and "move" or "influence"]=remaining end
                for index=#source.details,1,-1 do
                    local detail=source.details[index]
                    if detail.key==field then
                        if remaining==0 then table.remove(source.details,index)
                        else
                            detail.amount=remaining
                            detail.text=(field=="move" and "Move " or "Influence ")..tostring(remaining)
                                ..(field=="influence" and " → Psychic Block" or "")
                        end
                    end
                end
                amount=amount-consumed
            end
        end
        if amount>0 and trackerPrivate.traceEnabled then
            trackerPrivate.traceEvent("resource.conversionUnderpaid",seat,nil,
                field.." shortfall="..tostring(amount))
        end
    end
    local function converted(guid,part,original,points,resourceCost)
        if points<=0 then return end
        local key=resourceCardsTransformedKey(original,transform)
        local family=key:match("^([a-z]+)") or "attack"
        if key:sub(1,6)=="ranged" then family="ranged"
        elseif key:sub(1,5)=="siege" then family="siege"
        elseif key:sub(1,5)=="block" then family="block"
        else family="attack" end
        local label=(guid=="878d92" and "Agility" or "Diplomacy")
            .." ("..tostring(resourceCost).." points spent)"
        local icon=family=="ranged" and "MKChoiceRanged"
            or family=="siege" and "MKChoiceSiege"
            or family=="block" and "MKChoiceBlock" or "MKChoiceAttack"
        local source={guid=guid,key=guid.."#"..part,part=part,kind="card",name=label,
            ranged=family=="ranged" and points or 0,
            siege=family=="siege" and points or 0,
            block=family=="block" and points or 0,
            attack=family=="attack" and points or 0,
            move=0,psychicInfluence=0,psychicInfluenceCounts=false,
            convertedResource=key,convertedFamily=family,convertedAmount=points,
            -- All converted points stay late if any Damage-phase Wound paid for them.
            damagePhaseWound=guid=="878d92" and lateMoveSpent>0,
            resources={[key]=points},
            details={{text=key.." "..points,amount=points,
                icon=icon,key=key,family=family,
                typeKey=key:find("Fire$") and "F"
                    or key:find("Ice$") and "I" or "P"}}}
        sources[#sources+1]=source
    end
    if agilityOn and agility~=nil then
        local used=agility.attack+2*agility.ranged
        consumeShared("move",used)
        converted("878d92","convertAttack","attack",agility.attack,agility.attack)
        converted("878d92","convertRanged","ranged",agility.ranged,agility.ranged*2)
    end
    if diplomacyOn and diplomacy~=nil then
        consumeShared("influence",diplomacy.block)
        local record=resourceCardScanBySeat[seat].cards["8c3de6"]
        local copied=record~=nil and record.repeatLink~=nil
            and record.repeatLink.count>1
        local key=not record.powered and "block"
            or diplomacy.element=="I" and "blockIce" or "blockFire"
        if copied and record.powered then
            local amounts={blockFire=0,blockIce=0}
            for index=1,record.repeatLink.count do
                local element=diplomacy.elementUses~=nil
                    and diplomacy.elementUses[index]=="I"
                    and "blockIce" or "blockFire"
                amounts[element]=amounts[element]+(diplomacy.blockUses[index] or 0)
            end
            key=amounts.blockFire>0 and "blockFire" or "blockIce"
            if diplomacy.block>0 then
                converted("8c3de6","convertBlock",key,diplomacy.block,diplomacy.block)
                local source=sources[#sources]
                -- A copied card is one composite Block, even when its two
                -- uses have different elements. The two typed details must
                -- share one target and must never be divided by right-click.
                source.convertedResource=nil
                source.convertedAmount=nil
                source.resources={}
                source.details={}
                for _,field in ipairs({"blockFire","blockIce"}) do
                    local amount=amounts[field]
                    if amount>0 then
                        source.resources[field]=amount
                        source.details[#source.details+1]={
                            text=field.." "..amount,amount=amount,
                            icon="MKChoiceBlock",key=field,family="block",
                            typeKey=field=="blockFire" and "F" or "I"}
                    end
                end
            end
        else
            converted("8c3de6","convertBlock",key,diplomacy.block,diplomacy.block)
            if copied and diplomacy.block>0 then
                -- Three basic uses also form one composite Physical Block.
                local source=sources[#sources]
                source.convertedResource=nil
                source.convertedAmount=nil
            end
        end
    end
    -- Shield of the Fallen Kings gives separate Block effects, not one
    -- divisible pool. Each part has its own target key, arrow and assignment.
    -- An Ambush bonus belongs to the FIRST printed Block effect only.
    -- A newly received Wound cannot Block or spend Move against Cumbersome:
    -- both happen before the Damage phase. Agility has already consumed Move.
    for _,source in ipairs(sources) do
        if source.damagePhaseWound then
            source.block=0 source.move=0
            for key in pairs(source.resources or {}) do
                if key=="move" or key:sub(1,5)=="block" then source.resources[key]=0 end
            end
            for index=#source.details,1,-1 do
                local family=source.details[index].family
                if family=="block" or family=="move" then table.remove(source.details,index) end
            end
        end
    end
    local splitBlocks={}
    for _,source in ipairs(sources) do
        local count=tonumber(source.repeatBlocks) or 1
        if count>1 and source.block>0 then
            local firstBonus=tonumber(source.ambushFirstBlockBonus) or 0
            for index=1,count do
                local part={}
                for key,value in pairs(source) do part[key]=value end
                part.key=source.key.."#block"..index
                part.part="block"..index
                part.name=source.name.." (Block "..index..")"
                part.repeatBlocks=nil
                part.ambushFirstBlockBonus=nil
                part.resources={}
                part.details={}
                part.block=0
                for _,detail in ipairs(source.details) do
                    if detail.family=="block" then
                        local amount=detail.amount-firstBonus
                        if amount>=0 and amount%count==0 then
                            amount=amount/count+(index==1 and firstBonus or 0)
                            local copy={}
                            for key,value in pairs(detail) do copy[key]=value end
                            copy.amount=amount
                            copy.text=tostring(detail.text):gsub("%s+%d+$"," "..tostring(amount))
                            part.details[#part.details+1]=copy
                            part.resources[detail.key]=amount
                            part.block=part.block+amount
                        end
                    end
                end
                if part.block>0 then splitBlocks[#splitBlocks+1]=part end
            end
        else
            splitBlocks[#splitBlocks+1]=source
        end
    end
    sources=splitBlocks
    -- Paralyzed Units disappear physically in the Damage phase. Keep only
    -- their ALREADY resolved Ranged/Siege and Block/Move contributions until
    -- turn end. Their Attack-phase ability cannot be used after destruction.
    local ledger=gStates~=nil and gStates.combatWoundApplication or nil
    if ledger~=nil and ledger.seat==seat then
        local active={}
        for _,source in ipairs(sources) do active[source.key]=true end
        for _,retired in pairs(ledger.retiredUnitSources or {}) do
            for _,source in ipairs(retired) do
                if not active[source.key] then
                    sources[#sources+1]=source
                    active[source.key]=true
                    if combatAssignmentState.targets[source.key]==nil
                        and source.retiredTarget~=nil then
                        combatAssignmentState.targets[source.key]=source.retiredTarget
                        combatAssignmentState.explicit[source.key]=source.retiredExplicit==true
                    end
                end
            end
        end
    end
    table.sort(sources,function(a,b)
        if a.name==b.name then return a.key<b.key end
        return a.name<b.name
    end)
    return sources
end

-- Preserve resolved pre-Damage Unit contributions before removing the card
-- from its zone. Snapshot plain scalar data only so TTS JSON save/reload
-- does not capture objects or userdata.
local function combatFrozenCopy(value)
    if type(value)~="table" then
        if type(value)=="string" or type(value)=="number" or type(value)=="boolean" then
            return value
        end
        return nil
    end
    local copy={}
    for key,entry in pairs(value) do
        if type(key)=="string" or type(key)=="number" then
            copy[key]=combatFrozenCopy(entry)
        end
    end
    return copy
end


-- A committed Damage phase is immutable, even if cards are lifted, returned
-- to hand, or re-enter the play area. Keep the snapshot in gStates so it
-- survives ordinary TTS save/reload and is reverted by the pre-commit rewind.
local function combatPhaseLock(seat)
    local ledger=gStates~=nil and gStates.combatWoundApplication or nil
    local lock=ledger~=nil and ledger.phaseLock or nil
    if ledger~=nil and lock~=nil and gStates~=nil
        and ledger.seat==seat and lock.turn==gStates.turnNumber then
        return lock
    end
    return nil
end

local function combatPhaseLockSources(lock,live)
    if lock==nil then return live end
    local results,byKey={},{}
    for _,source in ipairs(live) do byKey[source.key]=source end
    local frozenKeys=lock.sourceKeys or {}
    for _,original in ipairs(lock.sources or {}) do
        if frozenKeys[original.key] then
            local frozen=combatFrozenCopy(original) or {}
            frozen.phaseLocked=true
            frozen.noAttackPhase=true
            frozen.attack=0
            for key in pairs(frozen.resources or {}) do
                if type(key)=="string" and key:sub(1,6)=="attack" then
                    frozen.resources[key]=nil
                end
            end
            for i=#(frozen.details or {}),1,-1 do
                if frozen.details[i].family=="attack" then
                    table.remove(frozen.details,i)
                end
            end
            results[#results+1]=frozen
            -- The card's later Attack is separate from the already committed
            -- resource. Never grant a second copy when the same GUID re-enters.
            local current=byKey[original.key]
            if current~=nil then
                local fallback=(lock.spentRange or {})[original.key]~=true
                local late=combatFrozenCopy(original) or {}
                late.key=original.key.."#postDamage"
                late.phaseAfterDamage=true
                late.damagePhaseWound=true
                late.block=0 late.move=0 late.psychicInfluence=0
                -- Replaying the same GUID cannot inflate the Attack it had
                -- when Damage was committed. A separate authorised reuse
                -- requires an explicit activation record, not a new scan.
                late.attack=(original.attack or 0)>0
                    and math.min(original.attack or 0,current.attack or 0) or 0
                late.ranged=fallback and (original.ranged or 0) or 0
                late.siege=fallback and (original.siege or 0) or 0
                late.resources={}
                late.details={}
                for _,detail in ipairs(original.details or {}) do
                    if (detail.family=="ranged" or detail.family=="siege") and fallback then
                        late.details[#late.details+1]=combatFrozenCopy(detail)
                        late.resources[detail.key]=detail.amount
                    end
                end
                if (original.attack or 0)>0 then
                    for _,detail in ipairs(current.details or {}) do
                        if detail.family=="attack" then
                            local allowed=math.min(detail.amount or 0,
                                (original.resources or {})[detail.key] or 0)
                            if allowed>0 then
                                local copy=combatFrozenCopy(detail)
                                copy.amount=allowed
                                late.details[#late.details+1]=copy
                                late.resources[detail.key]=allowed
                            end
                        end
                    end
                end
                if late.attack+late.ranged+late.siege>0 then
                    results[#results+1]=late
                end
            end
        end
    end
    for _,source in ipairs(live) do
        if not frozenKeys[source.key] then
            local late=combatFrozenCopy(source) or {}
            -- Only new Attack-phase actions may be introduced after Damage.
            -- Ranged/Siege can fall back as Attack; Block and Move cannot.
            late.damagePhaseWound=true
            late.phaseAfterDamage=true
            late.block=0 late.move=0 late.psychicInfluence=0
            late.psychicInfluenceCounts=false
            for key in pairs(late.resources or {}) do
                if key=="move" or key=="influence" or key:sub(1,5)=="block" then
                    late.resources[key]=nil
                end
            end
            for i=#(late.details or {}),1,-1 do
                local family=late.details[i].family
                if family=="block" or family=="move" or family=="influence" then
                    table.remove(late.details,i)
                end
            end
            if late.attack+late.ranged+late.siege>0 then
                results[#results+1]=late
            end
        end
    end
    table.sort(results,function(a,b)
        if a.name==b.name then return a.key<b.key end
        return a.name<b.name
    end)
    return results
end

combatConfig.phaseKeyLocked=function(key)
    local seat=combatAssignmentActiveSeat()
    local lock=combatPhaseLock(seat)
    return lock~=nil and (lock.sourceKeys or {})[key]==true
end

combatConfig.phaseObjectLocked=function(guid)
    local lock=combatPhaseLock(combatAssignmentActiveSeat())
    return lock~=nil and (lock.objectKeys or {})[guid]==true
end

combatConfig.captureParalyzedUnitSources=function(seat,unitGUID)
    local ledger=combatConfig.woundLedger(seat)
    if ledger==nil or unitGUID==nil then return false end
    ledger.retiredUnitSources=ledger.retiredUnitSources or {}
    if ledger.retiredUnitSources[unitGUID]~=nil then return true end
    local unit=getObjectFromGUID(unitGUID)
    local pos=unit~=nil and unit.getPosition() or nil
    local saved={}
    for _,source in ipairs(combatAssignmentSources(seat)) do
        if source.kind=="unit" and source.guid==unitGUID
            and combatAssignmentState.targets[source.key]~=nil
            and source.ranged+source.siege+source.block+source.move>0 then
            local copy=combatFrozenCopy(source) or {}
            copy.retiredUnit=true
            copy.retiredUnitPosition=pos~=nil
                and {pos.x or pos[1],pos.y or pos[2],pos.z or pos[3]} or nil
            copy.retiredTarget=combatAssignmentState.targets[source.key]
            copy.retiredExplicit=combatAssignmentState.explicit[source.key]==true
            copy.attack=0
            copy.conditionalCounterattack=nil
            local resources=copy.resources
            if type(resources)=="table" then
                for field in pairs(resources) do
                    if type(field)=="string" and field:sub(1,6)=="attack" then
                        resources[field]=nil
                    end
                end
            end
            local details=copy.details
            if type(details)=="table" then
                for i=#details,1,-1 do
                    local detail=details[i]
                    if type(detail)=="table" and detail.family=="attack" then
                        table.remove(details,i)
                    end
                end
            end
            saved[#saved+1]=copy
        end
    end
    ledger.retiredUnitSources[unitGUID]=saved
    return true
end

local function combatNearestEnemyGUID(source,entries,eligible,positions)
    -- Allocation passes may share a short-lived physical position snapshot.
    -- Other callers still obtain fresh positions without a cache.
    local function positionOf(guid)
        if positions~=nil and positions[guid]~=nil then
            return positions[guid] or nil
        end
        local obj=getObjectFromGUID(guid)
        local position=obj~=nil and obj.getPosition() or nil
        if positions~=nil then positions[guid]=position or false end
        return position
    end
    local sourcePosition=positionOf(source.guid) or source.retiredUnitPosition
    if sourcePosition==nil then return nil end
    local nearestGUID,nearestDistance=nil,nil
    for _,entry in ipairs(entries) do
        local forkDuplicate=false
        if source.forkedLightning then
            for key,target in pairs(combatAssignmentState.targets or {}) do
                if key~=source.key and key:match("^d01b70#fork%d+$")
                    and target==entry.guid then forkDuplicate=true break end
            end
        end
        if not forkDuplicate and entry.guid~=source.possessExclude
            and (eligible==nil or eligible(entry.guid))
            and (not entry.attackOnly
            or source.ranged+source.siege+source.attack==0) then
            local position=positionOf(entry.guid)
            if position~=nil then
                local dx,dz=position[1]-sourcePosition[1],position[3]-sourcePosition[3]
                local distance=dx*dx+dz*dz
                if nearestDistance==nil or distance<nearestDistance
                    or (distance==nearestDistance and entry.guid<nearestGUID) then
                    nearestGUID,nearestDistance=entry.guid,distance
                end
            end
        end
    end
    return nearestGUID
end

combatConfig.attackTypes={
    {key="P",label="Physical",attack="attack",ranged="ranged",siege="siege",block="block"},
    {key="F",label="Fire",attack="attackFire",ranged="rangedFire",siege="siegeFire",block="blockFire"},
    {key="I",label="Ice",attack="attackIce",ranged="rangedIce",siege="siegeIce",block="blockIce"},
    {key="IF",label="Cold Fire",attack="attackColdFire",ranged="rangedColdFire",siege="siegeColdFire",block="blockColdFire"},
    {key="M",label="Psychic",attack="attackPsychic",ranged="rangedPsychic",siege="siegePsychic",block="blockPsychic"}
}

trackerPrivate.enemyDefences=require("PlayingGame.PlayerBoard.ResourceTracker.Combat.EnemyProperties").defences(combatConfig)
local combatEnemyHasTrait=trackerPrivate.enemyDefences.hasTrait
local combatEnemyFortificationCount=trackerPrivate.enemyDefences.fortificationCount

-- owner/slot identify the physical token carrying each attack; calculation is delegated.
trackerPrivate.enemyAttacks=require("PlayingGame.PlayerBoard.ResourceTracker.Combat.EnemyProperties").attacks(
    combatConfig.attackTypes,combatEnemyHasTrait,combatEnemyFortificationCount)
local combatEnemyPrintedAttacks=trackerPrivate.enemyAttacks.printed
combatConfig.convertPreyAttacks=trackerPrivate.enemyAttacks.convertPreyAttacks

-- Summoned tokens are not enemies in their own right: their attacks and abilities belong to the summoner.
local function combatSummonedFor(summonerGUID)
    local summoned={}
    for guid,details in pairs(gStates~=nil and gStates.attackedMonsters or {}) do
        local data=monsterPugs[guid]
        if type(details)=="table" and details[3]=="summoned" and details[4]==summonerGUID
            and data~=nil and getObjectFromGUID(guid)~=nil then
            local perks=gStates.monsterPerks~=nil and gStates.monsterPerks[guid] or nil
            local effect=combatEffectOf(guid)
            if effect~=nil and next(effect.removedPrinted or {})~=nil then
                local reduced={}
                for trait,value in pairs(data) do reduced[trait]=value end
                for trait in pairs(effect.removedPrinted) do
                    reduced[trait]=trait=="defend" and 0 or false
                end
                data=reduced
            end
            summoned[#summoned+1]={guid=guid,data=data,perks=perks,effect=effect}
        end
    end
    table.sort(summoned,function(a,b) return a.guid<b.guid end)
    return summoned
end

local function combatIsSummonedToken(guid)
    return gStates~=nil and gStates.summonStates~=nil and gStates.summonStates[guid]=="summoned"
end

local combatOrderedReductions=trackerPrivate.enemyAttacks.orderedReductions
local function combatEnemyAttacks(entry,includeCancelled)
    return trackerPrivate.enemyAttacks.enemyAttacks(entry,includeCancelled,
        combatReductionAttackChoice[entry.guid])
end

-- Conversion availability must reserve Influence only if its explicit target
-- can actually receive Psychic Block, including a summoner's live attacks.
combatConfig.hasPsychicAttack=function(guid)
    local data=guid~=nil and combatEnemyData(guid) or nil
    if data==nil then return false end
    local perks=gStates~=nil and gStates.monsterPerks~=nil
        and gStates.monsterPerks[guid] or nil
    local entry={guid=guid,data=data,perks=perks,
        summoned=data.monsters~=nil and combatSummonedFor(guid) or nil}
    for _,attack in ipairs(combatEnemyAttacks(entry)) do
        if attack.key=="M" and not attack.pending then return true end
    end
    return false
end

-- Used by Battle Hardened's per-Attack selector. A summoner's separately
-- drawn enemy attacks retain their own owner/slot keys.
local function combatHardenedAttackOptions(targetGUID)
    local data=targetGUID~=nil and combatEnemyData(targetGUID) or nil
    if data==nil then return {} end
    local perks=gStates~=nil and gStates.monsterPerks~=nil
        and gStates.monsterPerks[targetGUID] or nil
    local entry={guid=targetGUID,data=data,perks=perks,
        summoned=data.monsters~=nil and combatSummonedFor(targetGUID) or nil}
    local options={}
    for _,attack in ipairs(combatEnemyAttacks(entry)) do
        if attack.owner~=nil and not attack.pending then
            options[#options+1]={key=attack.owner..":"..tostring(attack.slot),
                label=attack.label.." "..tostring(attack.value)}
        end
    end
    return options
end

-- Offence abilities shown for a summoner are the ones carried by its summoned tokens.
local function combatEnemyOffenceTraits(entry)
    if entry.removeAbilities and entry.data.monsters==nil then return "None" end
    if entry.data.monsters==nil then
        local text=combatEnemyTraitsText(entry.data,entry.perks,combatConfig.enemyOffenceTraits)
        if entry.effect~=nil and entry.effect.grantCumbersome==true
            and not text:find("Cumbersome",1,true) then
            text=text=="None" and "Cumbersome" or (text.."\nCumbersome")
        end
        return text
    end
    local merged={}
    for _,summoned in ipairs(entry.summoned or {}) do
        if not (summoned.effect~=nil and summoned.effect.removeAbilities==true) then
            for _,trait in ipairs(combatConfig.enemyOffenceTraits) do
                if combatEnemyHasTrait(summoned.data,summoned.perks,trait[1])
                    or (trait[1]=="cumbersome" and summoned.effect~=nil
                        and summoned.effect.grantCumbersome==true) then merged[trait[1]]=true end
            end
        end
    end
    return combatEnemyTraitsText(merged,nil,combatConfig.enemyOffenceTraits)
end

local function combatEntryHasCumbersome(guid,data,perks)
    local effect=combatEffectOf(guid)
    local printedIgnored=effect~=nil and effect.removedPrinted~=nil
        and effect.removedPrinted.cumbersome==true
    local hasCumbersome=(data.cumbersome==true and not printedIgnored)
        or (perks~=nil and perks.cumbersome==true)
        or (effect~=nil and effect.grantCumbersome==true)
    if effect~=nil and effect.grantCumbersome==true then return true end
    if hasCumbersome and not (effect~=nil and effect.removeAbilities) then return true end
    if data.monsters~=nil then
        for _,summoned in ipairs(combatSummonedFor(guid)) do
            if summoned.effect~=nil and summoned.effect.grantCumbersome==true then return true end
            if combatEnemyHasTrait(summoned.data,summoned.perks,"cumbersome")
                and not (summoned.effect~=nil and summoned.effect.removeAbilities) then return true end
        end
    end
    return false
end

local function combatGUIDHasCumbersome(guid)
    local data=combatEnemyData(guid)
    if data==nil then return false end
    local perks=gStates~=nil and gStates.monsterPerks~=nil and gStates.monsterPerks[guid] or nil
    return combatEntryHasCumbersome(guid,data,perks)
end

function resourceCardsCombatTargetAcceptsMove(guid)
    return combatGUIDHasCumbersome(guid)
end

-- Reject a stale split Move button after the reward changes role or flips.
function resourceCardsSplitMoveActive(guid)
    local seat=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    local scan=seat~=nil and resourceCardScanBySeat[seat.seatPos] or nil
    local record=scan~=nil and scan.cards[guid] or nil
    return record~=nil and record.splitTargets~=nil
        and (tonumber(record.resources~=nil and record.resources.move) or 0)>0
        and resourceCardsMoveRole(guid,false)=="combat"
        and combatCalcOn and combatCumbersomeActive
end

function resourceCardsAmbushCombatMoveActive(guid)
    return resourceCardsAmbushSourceActive(guid)
        and resourceCardsMoveRole(guid,false)=="combat"
end

-- "Unfortified" Unit abilities (Illusionists) only target enemies whose
-- effective Fortification is zero. A separate active Remove Fortification
-- effect qualifies; the printed Fortified and Wall Fortified traits do not.
-- Keep the rule source-key based so the target button and auto scan agree.
function resourceCardsUnitTargetRequiresUnfortified(sourceKey)
    return trackerPrivate.combatTargetPolicy.requiresUnfortified(sourceKey,unitResourceDefinitions)
end

function resourceCardsEnemyEffectivelyUnfortified(guid,effects,ignoreSiteFortifications)
    return trackerPrivate.combatTargetPolicy.effectivelyUnfortified(guid,effects,ignoreSiteFortifications,combatEnemyData,combatEffectOf,combatEnemyFortificationCount,combatEnemyHasTrait)
end

function resourceCardsCombatTargetRejectMessage(sourceKey,targetGUID)
    return trackerPrivate.combatTargetPolicy.rejectMessage(sourceKey,targetGUID,combatAssignmentActiveSeat)
end

-- Reminders accept only Block/Move and enemy-attack effects, not attacks
-- against Armour. Unknown source keys represent effect-only targeting links.
function resourceCardsCombatTargetAcceptsSource(sourceKey,targetGUID)
    return trackerPrivate.combatTargetPolicy.acceptsSource(sourceKey,targetGUID,combatAssignmentActiveSeat,combatEnemyData,combatConfig,combatAssignmentSources,combatAssignmentState,selectedResourceByGUID)
end

-- A lifted card keeps its target while its arrow still exists.
-- Preserve existing target arrows only while a source is actually in transit.
-- Once a card settles, the live active-source list must decide whether its
-- arrow survives. In particular, switching to a non-combat option must clear
-- the old attack/block arrow even if the card remains on the play mat.
local function combatSourceKeepsLock(key)
    local obj=getObjectFromGUID(key:match("^[^#]+"))
    if obj==nil or next(attackAssignmentsTargetGUIDs(key))==nil then return false end
    local held=obj.held_by_color
    return (held~=nil and held~="") or obj.isSmoothMoving()
        or (trackerPrivate.playCardMovements~=nil
            and trackerPrivate.playCardMovements[obj.guid]~=nil)
end

-- Physical target controls and the calculator share the current scan's
-- effect classification; ordinary numeric resources keep their own colours.
function resourceCardsCombatEffectArrowKind(sourceKey)
    return trackerPrivate.combatTargetPolicy.effectArrowKind(sourceKey,combatAssignmentActiveSeat)
end

-- Orange = Attack; blue = Block (including Psychic Influence); purple = other.
-- A composite source with both Attack/Block and other resources retains the
-- numeric Attack/Block colour because its arrow represents the shared target.
local function combatSourceArrowKind(source)
    local kind=resourceCardsCombatEffectArrowKind(source.key)
    if kind~=nil then return kind end
    if source.ranged+source.siege+source.attack>0 then return "armour" end
    if source.block>0 or (source.psychicInfluence or 0)>0 then return "attack" end
    return "other"
end

-- True while the Resource Tracker details are open and an enemy stands in the play area.
local function combatCalcUpdate(monsters)
    local on=false
    combatEnemyInPlay=false
    local cumbersome,psychic=false,false
    local enemyCount,singleEnemyGUID=0,nil
    if resourceCardsDetailsOpen() then
        for guid,obj in pairs(monsters or {}) do
            local data=combatEnemyData(guid,obj)
            if data~=nil and data.name~="Ruin"
                and (obj.isDestroyed==nil or not obj.isDestroyed()) then
                combatEnemyInPlay=true
            end
            if data~=nil and obj.is_face_down~=true then
                -- A lone ordinary enemy needs no manual choice for automatic
                -- Attack/Block and enemy effects. Reminders and summoned enemies
                -- still count: their separate targets/limitations matter.
                if data.name~="Ruin" and (obj.isDestroyed==nil or not obj.isDestroyed()) then
                    enemyCount=enemyCount+1
                    if enemyCount==1 and data.attackOnly~=true
                        and not combatIsSummonedToken(guid) then singleEnemyGUID=guid end
                end
                local perks=gStates~=nil and gStates.monsterPerks~=nil and gStates.monsterPerks[guid] or nil
                -- Summoned enemies count for their Psychic Attack, even though
                -- only the summoner gets a separate calculator row.
                local printed=type(data.attack)=="table" and data.attack or {}
                local override=perks~=nil and type(perks.attack)=="table" and perks.attack or {}
                if override.M~=nil or printed.M~=nil then psychic=true end
                if not combatIsSummonedToken(guid) then
                    on=true
                    if combatEntryHasCumbersome(guid,data,perks) then cumbersome=true end
                end
            end
        end
    end
    combatCalcOn=on
    combatCumbersomeActive=cumbersome
    combatPsychicActive=psychic
    -- The current scan owns this transient UI hint. No targeting or combat
    -- assignment is changed when the number of enemies changes.
    trackerPrivate.singleAutoEnemyGUID=enemyCount==1 and singleEnemyGUID or nil
    return on
end

-- A shallow zone can miss an enemy that was just dropped above it.
-- Recover ONLY enemies previously observed in this seat's combat areas.
-- Held/smooth enemies remain visible; released ones must still be over
-- either combat zone in X/Z. Otherwise real departures leave combat normally.
local combatTrackedSeat=nil
local combatTrackedEnemies={}
local function combatKeepHeldEnemies(seatPos,monsters,playMonsters)
    if combatTrackedSeat~=seatPos then
        combatTrackedSeat=seatPos
        combatTrackedEnemies={}
    end
    for guid,obj in pairs(monsters) do
        if obj~=nil and not obj.isDestroyed() then
            combatTrackedEnemies[guid]=playMonsters[guid]~=nil
        end
    end
    local playZone=nil
    local unitZone=nil
    for guid,wasInPlay in pairs(combatTrackedEnemies) do
        if monsters[guid]==nil then
            local obj=getObjectFromGUID(guid)
            if obj==nil or obj.isDestroyed() then
                combatTrackedEnemies[guid]=nil
            else
                -- The source may be released before zone.getObjects() sees
                -- its new Y position. Check the zone's actual transform
                -- footprint, never its zero-sized scripting-zone bounds.
                if playZone==nil and playerPlayAreas[seatPos]~=nil then
                    playZone=getObjectFromGUID(playerPlayAreas[seatPos])
                end
                if unitZone==nil and playerUnitAreas[seatPos]~=nil then
                    unitZone=getObjectFromGUID(playerUnitAreas[seatPos])
                end
                local overPlay=trackerPrivate.zoneFootprintContainsXZ(obj,playZone)
                local overUnit=trackerPrivate.zoneFootprintContainsXZ(obj,unitZone)
                local held=obj.held_by_color~=nil and obj.held_by_color~=""
                if held or obj.isSmoothMoving() or overPlay or overUnit then
                    monsters[guid]=obj
                    local inPlay=overPlay or (wasInPlay and not overUnit)
                    if inPlay then playMonsters[guid]=obj end
                    combatTrackedEnemies[guid]=inPlay
                else
                    -- A genuinely removed token must not leave a ghost
                    -- enemy or permanently lock an invalid assignment.
                    combatTrackedEnemies[guid]=nil
                end
            end
        end
    end
    return monsters
end

local function combatPlayMonsters()
    local active=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    local monsters,playMonsters={},{}
    if active~=nil and active.seatPos~=nil then
        for _,zoneInfo in ipairs({{playerUnitAreas[active.seatPos],false},
            {playerPlayAreas[active.seatPos],true}}) do
            local zone=zoneInfo[1]~=nil and getObjectFromGUID(zoneInfo[1]) or nil
            if zone~=nil then
                for _,obj in ipairs(zone.getObjects()) do
                    local data=combatEnemyData(obj.guid,obj)
                    if data~=nil and data.name~="Ruin" then
                        monsters[obj.guid]=obj
                        if zoneInfo[2] then playMonsters[obj.guid]=obj end
                    end
                end
            end
        end
        return combatKeepHeldEnemies(active.seatPos,monsters,playMonsters)
    end
    return monsters
end

-- Temporary target buttons cover only face-up enemies in the active combat.
-- A summoned token may act as a proxy only if its summoner is also present.
function resourceCardsCombatTargetObjects(monsters)
    monsters=monsters or combatPlayMonsters()
    local targets={}
    for guid,obj in pairs(monsters) do
        if obj.is_face_down~=true and not obj.isDestroyed() then
            local summoned=gStates~=nil and gStates.attackedMonsters~=nil
                and gStates.attackedMonsters[guid] or nil
            if summoned~=nil and summoned[3]=="summoned" then
                local owner=monsters[summoned[4]]
                if owner~=nil and owner.is_face_down~=true and not owner.isDestroyed() then
                    targets[guid]=obj
                end
            elseif not combatIsSummonedToken(guid) then
                targets[guid]=obj
            end
        end
    end
    return targets
end

function resourceCardsCombatCalculatorOn()
    return combatCalcUpdate(combatPlayMonsters())
end

local combatEnemyResists=trackerPrivate.enemyDefences.resists
local combatAttackTotal=trackerPrivate.enemyDefences.attackTotal

-- Blocks of the wrong element are halved against Fire, Ice and Cold Fire attacks. Every Block type is
-- fully efficient against Physical attacks (P), so that entry lists all of them.
combatConfig.COMBAT_EFFICIENT_BLOCKS={
    P={block=true,blockFire=true,blockIce=true,blockColdFire=true},
    F={blockIce=true,blockColdFire=true},
    I={blockFire=true,blockColdFire=true},
    IF={blockColdFire=true},
    M={blockPsychic=true}
}

-- The assignment panel is rescanned with every card scan; only send attributes that changed.
trackerPrivate.combatPanelAttributes={}
local function combatPanelSetAttribute(id,attribute,value)
    local key=id.."\0"..attribute
    if trackerPrivate.combatPanelAttributes[key]==value then
        if trackerPrivate.traceEnabled then trackerPrivate.profileCount("ui.attribute.skipped") end
        return
    end
    local writeProfile
    if trackerPrivate.traceEnabled then writeProfile=trackerPrivate.profileStart() end
    UI.setAttribute(id,attribute,value)
    if writeProfile~=nil then trackerPrivate.profileUIWrite(id,writeProfile) end
    trackerPrivate.combatPanelAttributes[key]=value
    if trackerPrivate.traceEnabled then trackerPrivate.profileCount("ui.attribute.written") end
end

-- Selection changes affect icon tint only; they cannot change combat outcomes.
combatConfig.refreshSelectedSlots=function()
    for id,spec in pairs(combatConfig.slotSelection) do
        combatPanelSetAttribute(id,"color",(spec.wounded or spec.ineffective) and "rgb(0.90,0.37,0.35)"
            or (combatAssignmentState.selected==spec.key and "rgb(1,0.75,0.2)"
                or "rgb(0.85,0.82,0.72)"))
    end
end

-- Empty slots are hidden; a filled slot is the resource icon with its value over the top.
local function combatAssignmentIconButton(id,active,amount,icon,tooltip,selected,textColor,wounded,ineffective)
    combatPanelSetAttribute(id,"active",active and "true" or "false")
    if active then
        local imageID,amountID=id.."Image",id.."Amount"
        -- Fixed geometry is applied once per slot, for the lifetime of the
        -- same attribute cache. Dynamic text, tint and interaction stay live.
        local styleKey="style\0"..id
        if not trackerPrivate.combatPanelAttributes[styleKey] then
            combatPanelSetAttribute(imageID,"rectAlignment","MiddleCenter")
            combatPanelSetAttribute(imageID,"offsetXY","0 0")
            combatPanelSetAttribute(imageID,"width","24")
            combatPanelSetAttribute(imageID,"height","24")
            combatPanelSetAttribute(imageID,"preserveAspect","true")
            combatPanelSetAttribute(amountID,"rectAlignment","MiddleCenter")
            combatPanelSetAttribute(amountID,"offsetXY","0 0")
            combatPanelSetAttribute(amountID,"width","24")
            combatPanelSetAttribute(amountID,"height","24")
            combatPanelSetAttribute(amountID,"preferredHeight","24")
            combatPanelSetAttribute(amountID,"alignment","MiddleCenter")
            combatPanelSetAttribute(amountID,"fontSize","18")
            combatPanelSetAttribute(amountID,"fontStyle","Bold")
            combatPanelSetAttribute(amountID,"outline","rgb(0,0,0)")
            combatPanelSetAttribute(amountID,"outlineSize","1 -1")
            combatPanelSetAttribute(id,"preferredWidth","24")
            combatPanelSetAttribute(id,"preferredHeight","26")
            trackerPrivate.combatPanelAttributes[styleKey]=true
        end
        combatPanelSetAttribute(imageID,"image",icon)
        combatPanelSetAttribute(amountID,"text",tostring(amount))
        combatPanelSetAttribute(amountID,"color",textColor or "White")
        combatPanelSetAttribute(id,"color",
            (wounded or ineffective) and "rgb(0.90,0.37,0.35)"
            or (selected and "rgb(1,0.75,0.2)" or "rgb(0.85,0.82,0.72)"))
        combatPanelSetAttribute(id,"tooltip",tooltip)
    end
end

combatConfig.COMBAT_RED="#FF5555"
combatConfig.COMBAT_GREEN="#8CFF8C"

-- TTS Text uses Unity rich text tags.
local function combatRich(text,color)
    return "<color="..color..">"..text.."</color>"
end

-- Ranged and Siege only count in the Ranged/Siege phase against enemies that are not
-- (doubly) fortified; one phase total is resisted as a whole.
local function combatRangeResult(entry,sources)
    -- Forked Lightning must use every bolt in the SAME phase. When the
    -- player selects melee, none of its bolts can score a Ranged-phase kill.
    local eligible={}
    for _,source in ipairs(sources) do
        if not source.damagePhaseWound and (not source.forkedLightning
            or (gStates==nil or gStates.forkedLightningPhase~="attack")) then
            eligible[#eligible+1]=source
        end
    end
    sources=eligible
    local data,perks=entry.data,entry.perks
    local fortification=combatEnemyFortificationCount(data,perks)
    local groups={}
    if fortification==0 then groups[#groups+1]={sources=sources,category="ranged"} end
    if fortification<2 then groups[#groups+1]={sources=sources,category="siege"} end
    local total=combatAttackTotal(groups,data,perks,"range")
    local armour=combatEnemyHasTrait(data,perks,"elusive") and entry.elusiveArmour or entry.baseArmour
    return total,armour,total>0 and total>=(entry.fullLevelArmour or armour),fortification
end

-- Block cells hold block, the Ranged/Siege cell holds range/siege only once it can legally
-- defeat the enemy, and everything else is generic Attack.
local function combatDetailPhase(detail,rangeDefeated,fortification,source)
    if source~=nil and source.noAttackPhase then
        if rangeDefeated and ((detail.family=="ranged" and fortification==0)
            or (detail.family=="siege" and fortification<2)) then return "range" end
        if detail.family=="block" or detail.family=="move" then return "block" end
        return nil -- unspent Ranged falls back through its separate Attack source
    end
    if source~=nil and source.damagePhaseWound then return "attack" end
    if source~=nil and source.forkedLightning then
        return (gStates==nil or gStates.forkedLightningPhase~="attack") and "range" or "attack"
    end
    if detail.family=="block" or detail.family=="move" then return "block" end
    if rangeDefeated and ((detail.family=="ranged" and fortification==0)
        or (detail.family=="siege" and fortification<2)) then return "range" end
    return "attack"
end

-- Chooses which Block resources and Move reductions stop which attacks; the solver owns the allocation math.
trackerPrivate.blockSolver=require("PlayingGame.PlayerBoard.ResourceTracker.Combat.BlockCalculation").solver(combatConfig)

-- Block resources only ever face the enemy they were targeted at.
-- Move resources the player aimed at a Cumbersome attack reduce that attack by 1 each.
-- Returns result lines, total damage, damaging attack count, whether every attack was blocked,
-- and the Move reduction applied to each attack.
-- Cache one complete result per enemy. Physical sources and attack effects
-- are fingerprinted every scan; an unchanged layout never reruns the Block DP.
-- Competitive Nature's Vengeance penalises opponents only while their own
-- reminder exists. The extra point changes Block thresholds, never the
-- damage assigned after Block, and never applies to the Skill owner.
local function combatNatureVengeanceBlockBonus()
    local state=gStates or {}
    local records=state.competitiveSkillReminders or {}
    local reminder=records["19daf9"]
    if reminder==nil or reminder.owner==state.turnNumber then return 0 end
    local seat=combatAssignmentActiveSeat()
    if seat==nil then return 0 end
    for guid,recipientSeat in pairs(reminder.reminders or {}) do
        if recipientSeat==seat and getObjectFromGUID(guid)~=nil then return 1 end
    end
    return 0
end

trackerPrivate.combatBlockResultCache={}
trackerPrivate.blockResults=require("PlayingGame.PlayerBoard.ResourceTracker.Combat.BlockCalculation").results(
    combatConfig,trackerPrivate.blockSolver,combatEnemyAttacks,
    combatNatureVengeanceBlockBonus,combatRich)
local function combatBlockResult(entry,sources)
    if not trackerPrivate.traceEnabled then
        return trackerPrivate.blockResults(entry,sources,trackerPrivate.combatBlockResultCache)
    end
    local profile=trackerPrivate.traceEnabled and (trackerPrivate.profileStart() or true) or nil
    local result={trackerPrivate.blockResults(entry,sources,trackerPrivate.combatBlockResultCache,
        trackerPrivate.profileCount)}
    trackerPrivate.profileFinish("block.result",profile)
    return table.unpack(result,1,12)
end

-- Damage phase. Every unblocked attack starts wholly on the Hero; the player may route it through free Units first
-- with the damage buttons. A Unit takes damage from one attack per combat and is Wounded whenever it is assigned damage,
-- unless a resistance absorbs all of it.
combatConfig.COMBAT_UNIT_RESIST_KEYS={Physical="P",Fire="F",Ice="I"}

-- Site rules are keyed by the *active fight*, not merely the player's map
-- location. A Dungeon/Tomb or burning Monastery normally forbids all Units,
-- except the Unit occupying Bonds of Loyalty's own Command slot. Maze and
-- Labyrinth allow one Unit TOTAL; Bonds adds no second companion.
trackerPrivate.combatUnitSiteModeByLocation={
    dungeon="bonds",tomb="bonds",monastery="bonds",
    maze="one",labyrinth="one",ziggurat="none",pyramid="none"
}
trackerPrivate.combatOneUnitBySeat={}
local function combatUnitSiteRestriction(seatPos,combatEnemies)
    local player=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    if player==nil or player.seatPos~=seatPos then return nil end
    local site=player.avatarLocation
    local mode=trackerPrivate.combatUnitSiteModeByLocation[site]
    if mode==nil then return nil end
    local perkKey=mode=="one" and "oneUnit" or "noUnits"
    for guid,enemy in pairs(combatEnemies or combatPlayMonsters()) do
        local perks=gStates.monsterPerks~=nil and gStates.monsterPerks[guid] or nil
        if enemy~=nil and enemy.is_face_down~=true
            and perks~=nil and perks[perkKey]==true then
            return mode,site
        end
    end
    return nil
end

local function combatOneUnitChosen(seatPos,site)
    local state=trackerPrivate.combatOneUnitBySeat[seatPos]
    if state~=nil and state.site==site and state.round==gStates.currentRound
        and state.turn==gStates.turnNumber then return state.guid end
    return nil
end

local function combatOneUnitSelect(seatPos,site,guid)
    trackerPrivate.combatOneUnitBySeat[seatPos]={site=site,round=gStates.currentRound,
        turn=gStates.turnNumber,guid=guid}
end

function resourceCardsCombatSelectOneUnit(guid)
    return trackerPrivate.combatInteraction.selectOneUnit(guid,combatUnitSiteRestriction,combatOneUnitSelect)
end

function resourceCardsCombatClearOneUnit(seatPos)
    if seatPos~=nil then trackerPrivate.combatOneUnitBySeat[seatPos]=nil
    else trackerPrivate.combatOneUnitBySeat={} end
end

local function combatUnitSitePermits(mode,bondsGUID,chosenGUID,unitGUID,damageChoice)
    if mode=="none" then return false end
    if mode=="bonds" then return unitGUID~=nil and unitGUID==bondsGUID end
    if mode=="one" then return unitGUID==chosenGUID
        or (chosenGUID==nil and damageChoice==true) end
    return true
end

-- Hero Armor: 2 at levels 1-2, 3 at 3-6, 4 at 7-10, then +1 per four levels.
-- Native Command tokens are gained every two levels, but Armor does NOT increase
-- with each token. Physical native tokens may lead the recorded level in testing;
-- Banner of Command and Bonds of Loyalty add slots, not Hero Armor.
local function combatHeroArmour(nativeCommandCount)
    local player=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    local level=math.max(1,math.floor(tonumber(player~=nil and player.level or 1) or 1))
    local levelArmour=2+math.floor((level+1)/4)
    local physicalArmour=2+math.floor(math.max(0,tonumber(nativeCommandCount) or 0)/2)
    return math.max(levelArmour,physicalArmour)
end

local function combatDamageUnits(seat)
    local scan=seat~=nil and resourceCardScanBySeat[seat] or nil
    local state=scan~=nil and scan.unitState
        or (seat~=nil and unitLayoutResourceState(seat) or nil)
    local units={}
    -- Into the Heat forbids assigning damage to Units, even if they are ready.
    if scan~=nil and scan.preventUnitDamage==true then
        return units,state~=nil and state.nativeCommandCount or 0
    end
    local siteMode,site=combatUnitSiteRestriction(seat)
    local selected=siteMode=="one" and combatOneUnitChosen(seat,site) or nil
    local bondsUnitGUID=state~=nil and state.bondsUnitGUID or nil
    for _,unitState in ipairs(state~=nil and state.units or {}) do
        local data=gameCards[unitState.guid]
        if data~=nil and tonumber(data.armour)~=nil
            and combatUnitSitePermits(siteMode,bondsUnitGUID,selected,unitState.guid,true) then
            local resist={}
            for _,name in ipairs(data.resistance or {}) do resist[combatConfig.COMBAT_UNIT_RESIST_KEYS[name] or name]=true end
            if scan~=nil and scan.allUnitResistances==true then
                resist.P,resist.F,resist.I=true,true,true
            end
            local banner=state~=nil and state.bannersByUnit~=nil
                and state.bannersByUnit[unitState.guid] or nil
            local glory=(banner~=nil and banner["Banner of Glory"]~=nil)
                or (scan~=nil and scan.gloryBroken==true)
            local protection=banner~=nil and banner["Banner of Protection"]~=nil
            if protection then resist.F,resist.I=true,true end
            units[unitState.guid]={guid=unitState.guid,name=type(data.name)=="table" and tostring(data.name[1]) or tostring(data.name),
                armour=tonumber(data.armour)+(glory and 1 or 0)
                    +(protection and 1 or 0),
                level=math.max(1,tonumber(data.level) or 1),
                resist=resist,wounded=not unitState.unwounded,
                fortitudeGUID=banner~=nil and banner["Banner of Fortitude"]~=nil
                    and banner["Banner of Fortitude"].guid or nil,
                fortitudeUsed=banner~=nil and banner["Banner of Fortitude"]~=nil
                    and banner["Banner of Fortitude"].faceDown==true,
                arcaneImmunity=data.arcaneImmunity==true,
                arcaneVulnerability=data.arcaneVulnerability==true}
        end
    end
    return units,state~=nil and state.nativeCommandCount or 0
end

trackerPrivate.damageResolution=require("PlayingGame.PlayerBoard.ResourceTracker.Combat.DamageCalculation").resolution(
    function(guid) return gameCards~=nil and gameCards[guid] or nil end,
    function(owner,summoner)
        local records=gStates~=nil and gStates.attackedMonsters or nil
        local record=records~=nil and records[owner] or nil
        return record~=nil and record[3]=="summoned" and record[4]==summoner
    end,
    function() return trackerPrivate.bannerEffectUses().fortitude end)
local combatDamageResolve=trackerPrivate.damageResolution.resolve

local function combatWoundsText(count)
    return tostring(count)..(count==1 and " Wound" or " Wounds")
end

-- Physical Wounds can leave the Hero's hand after being used. Persist their
-- source and every confirmed consequence per printed attack, not hand contents.
combatConfig.woundLedger=function(seat)
    if gStates==nil or seat==nil then return nil end
    local ledger=gStates.combatWoundApplication
    if type(ledger)~="table" or ledger.seat~=seat then
        ledger={seat=seat,applied={},cards={},preview={},hasPreview=false}
        gStates.combatWoundApplication=ledger
    end
    ledger.applied=ledger.applied or {}
    ledger.cards=ledger.cards or {}
    ledger.preview=ledger.preview or {}
    ledger.playDiscardApplied=ledger.playDiscardApplied or {}
    -- Legacy saves only tracked the individual Paralysis application.
    if ledger.handDiscardApplied==nil then
        ledger.handDiscardApplied=false
        for _,applied in pairs(ledger.applied) do
            if applied.paralyse==true then ledger.handDiscardApplied=true break end
        end
    end
    return ledger
end

-- Extra Wounds from "take a Wound" card effects count toward Knockout.
-- Snapshot the existing hand/play Wound GUIDs when combat begins; newly
-- observed GUIDs remain counted even if those Wounds are played or discarded.
-- Do not count enemy Wounds already recorded by the Apply Wounds ledger.
combatConfig.combatOtherWounds=function(seat)
    local ledger=combatConfig.woundLedger(seat)
    if ledger==nil then return 0 end
    local observed=ledger.otherCombatWounds or {}
    local hand=handZones~=nil and handZones[seat]~=nil
        and getObjectFromGUID(handZones[seat]) or nil
    local play=playerPlayAreas~=nil and playerPlayAreas[seat]~=nil
        and getObjectFromGUID(playerPlayAreas[seat]) or nil
    if hand~=nil and play~=nil then
        local seen={}
        local function inspect(obj)
            if obj==nil then return end
            if obj.type=="Card" and obj.getGMNotes~=nil
                and obj.getGMNotes()=="Wound" then
                seen[obj.guid]=true
            elseif obj.type=="Deck" and obj.getObjects~=nil then
                for _,card in ipairs(obj.getObjects() or {}) do
                    if card.gm_notes=="Wound" then seen[card.guid]=true end
                end
            end
        end
        for _,obj in ipairs(hand.getObjects() or {}) do inspect(obj) end
        for _,obj in ipairs(play.getObjects() or {}) do inspect(obj) end
        local current=turnOrder~=nil and gStates~=nil
            and turnOrder[gStates.turnNumber] or nil
        if current~=nil and current.seatPos==seat
            and positionToColor~=nil and Player~=nil then
            local color=positionToColor(gStates.turnNumber)
            local player=color~=nil and Player[color] or nil
            if player~=nil and player.getHandObjects~=nil then
                local ok,objects=pcall(player.getHandObjects)
                if ok then for _,obj in ipairs(objects or {}) do inspect(obj) end end
            end
        end
        if ledger.initialCombatWounds==nil then
            -- Wounds already owned in the Deed deck or discard pile are old
            -- cards, not new combat damage if a card effect retrieves them.
            -- These zones are baseline-only: newly dealt Poison discards
            -- must never enter the Hero's combat knockout count.
            for _,zoneGUID in pairs({
                deed=deedDeckZones~=nil and deedDeckZones[seat] or nil,
                discard=deedDeckDiscardZones~=nil
                    and deedDeckDiscardZones[seat] or nil}) do
                local zone=zoneGUID~=nil and getObjectFromGUID(zoneGUID) or nil
                if zone~=nil and zone.getObjects~=nil then
                    for _,obj in ipairs(zone.getObjects() or {}) do inspect(obj) end
                end
            end
            ledger.initialCombatWounds=seen
        else
            for guid in pairs(seen) do
                if ledger.initialCombatWounds[guid]~=true
                    and ledger.cards[guid]~=true then
                    observed[guid]=true
                end
            end
        end
    end
    ledger.otherCombatWounds=observed
    local count=0
    for _ in pairs(observed) do count=count+1 end
    return count
end

combatConfig.woundRecordPreview=function(seat,items,results,knockout,otherWounds,stagedCards)
    local ledger=combatConfig.woundLedger(seat)
    if ledger==nil then return end
    local expected={}
    local unitAssignments,fortitude=0,{}
    for _,item in ipairs(items or {}) do
        local result=results[item.key] or {}
        -- Previously destroyed Units are no longer physically in the Unit zone.
        -- Keep them in this attack's expected record and retain the damage
        -- they absorbed before removal, so they cannot hurt the Hero twice.
        local destroyed={}
        for guid,absorbed in pairs(result.committedDestroyed or {}) do
            destroyed[guid]=absorbed
        end
        for _,entry in ipairs(result.units or {}) do
            if entry.unit~=nil and entry.unit.guid~=nil then
                unitAssignments=unitAssignments+1
                if entry.fortitudePrevented and entry.unit.fortitudeGUID~=nil then
                    fortitude[entry.unit.fortitudeGUID]={attackKey=item.key}
                end
            end
            if entry.destroyed==true and entry.wounded==true
                and entry.unit~=nil and entry.unit.guid~=nil then
                destroyed[entry.unit.guid]=entry.absorbed or 0
            end
        end
        expected[item.key]={hand=result.heroWounds or 0,
            discard=result.discard or 0,paralyse=result.paralyse==true,
            destroyed=destroyed}
    end
    ledger.preview=expected
    ledger.previewUnitAssignments=unitAssignments
    ledger.previewFortitude=fortitude
    ledger.previewKnockout=knockout==true
    ledger.previewOtherWounds=math.max(0,tonumber(otherWounds) or 0)
    -- The confirmed plan survives moving cards away and save/reload.
    ledger.previewStagedDiscards=ledger.phaseLock~=nil
        and (ledger.phaseLock.attackDiscards or {}) or (stagedCards or {})
    ledger.hasPreview=true
end

-- Retain the original first four return values for existing consumers.
-- The fifth describes uncommitted physical Paralysis consequences.
combatConfig.woundPending=function(ledger)
    local allocations,hand,discard,changed={},0,0,false
    local effects={paralyse={},destroyed={},paralyseCount=0,destroyCount=0,
        stagedDiscards={},stagedDiscardCount=0,
        knockout=false,handDiscard=false,unitAssignments=0,unitCommitPending=false}
    if ledger==nil or not ledger.hasPreview then
        return allocations,hand,discard,changed,effects
    end
    effects.unitAssignments=ledger.previewUnitAssignments or 0
    effects.unitCommitPending=effects.unitAssignments>0 and ledger.damageAssignmentsCommitted~=true
    for key,expected in pairs(ledger.preview) do
        local applied=(ledger.applied or {})[key] or {}
        local h=math.max(0,(expected.hand or 0)-(applied.hand or 0))
        local d=math.max(0,(expected.discard or 0)-(applied.discard or 0))
        if h>0 or d>0 then
            allocations[#allocations+1]={key=key,hand=h,discard=d}
            hand=hand+h discard=discard+d
        end
        if expected.paralyse==true and applied.paralyse~=true
            and ledger.handDiscardApplied~=true then
            effects.paralyse[#effects.paralyse+1]=key
            effects.paralyseCount=effects.paralyseCount+1
        elseif applied.paralyse==true and expected.paralyse~=true then
            changed=true
        end
        for guid,absorbed in pairs(expected.destroyed or {}) do
            if (applied.destroyed or {})[guid]==nil then
                effects.destroyed[#effects.destroyed+1]={
                    key=key,guid=guid,absorbed=absorbed}
                effects.destroyCount=effects.destroyCount+1
            end
        end
        for guid in pairs(applied.destroyed or {}) do
            if (expected.destroyed or {})[guid]==nil then changed=true end
        end
        if (applied.hand or 0)>(expected.hand or 0)
            or (applied.discard or 0)>(expected.discard or 0) then changed=true end
    end
    for key,applied in pairs(ledger.applied or {}) do
        if ledger.preview[key]==nil and ((applied.hand or 0)>0
            or (applied.discard or 0)>0 or applied.paralyse==true
            or next(applied.destroyed or {})~=nil) then changed=true end
    end
    effects.knockout=ledger.previewKnockout==true
        and ledger.handDiscardApplied~=true
    effects.handDiscard=effects.knockout or effects.paralyseCount>0
    for _,guid in ipairs(ledger.previewStagedDiscards or {}) do
        if (ledger.playDiscardApplied or {})[guid]~=true then
            effects.stagedDiscards[#effects.stagedDiscards+1]=guid
            effects.stagedDiscardCount=effects.stagedDiscardCount+1
        end
    end
    table.sort(effects.stagedDiscards)
    table.sort(allocations,function(a,b) return a.key<b.key end)
    table.sort(effects.paralyse)
    table.sort(effects.destroyed,function(a,b)
        if a.key~=b.key then return a.key<b.key end
        return a.guid<b.guid
    end)
    return allocations,hand,discard,changed,effects
end

-- Deterministic, unambiguous plain-data fingerprint. The saved phase preview
-- already contains scalar snapshots; sorting keys avoids pairs() traversal order
-- making unchanged decisions look different.
combatConfig.decisionFingerprint=function(value)
    local function encode(item)
        if type(item)~="table" then
            local kind=type(item)
            local valueText=tostring(item)
            return kind..":"..#valueText..":"..valueText
        end
        local keys={}
        for key in pairs(item) do
            if type(key)=="string" or type(key)=="number" then
                keys[#keys+1]=key
            end
        end
        table.sort(keys,function(a,b)
            if type(a)==type(b) then return a<b end
            return type(a)<type(b)
        end)
        local parts={"{"}
        for _,key in ipairs(keys) do
            parts[#parts+1]=encode(key)
            parts[#parts+1]=encode(item[key])
        end
        parts[#parts+1]="}"
        return table.concat(parts,"|")
    end
    return encode(value)
end

-- A Damage commit is a deliberate phase boundary: record a stable
-- fingerprint of the planned Wounds, Paralysis, and assigned enemy targets.
-- The latest preview is checked after the dialog and again after TTS
-- records its rewind point; a changed plan must not use stale counts.
combatConfig.woundCommitSignature=function(ledger)
    if combatConfig.scanAwaitingRescan or ledger==nil or ledger.hasPreview~=true then return nil end
    local parts={tostring(ledger.seat),tostring(ledger.previewKnockout==true),
        tostring(ledger.previewOtherWounds or 0),
        tostring(ledger.handDiscardApplied==true),
        tostring(ledger.previewUnitAssignments or 0),
        tostring(ledger.damageAssignmentsCommitted==true),
        combatConfig.decisionFingerprint(ledger.previewFortitude or {})}
    local keys,seen={},{}
    for key in pairs(ledger.preview or {}) do
        keys[#keys+1]=key
        seen[key]=true
    end
    for key in pairs(ledger.applied or {}) do
        if not seen[key] then keys[#keys+1]=key end
    end
    table.sort(keys)
    for _,key in ipairs(keys) do
        local expected=ledger.preview[key] or {}
        local applied=ledger.applied[key] or {}
        parts[#parts+1]=table.concat({key,tostring(expected.hand or 0),
            tostring(expected.discard or 0),tostring(expected.paralyse==true),
            tostring(applied.hand or 0),tostring(applied.discard or 0),
            tostring(applied.paralyse==true)},":")
        local guids,seenGUIDs={},{}
        for guid in pairs(expected.destroyed or {}) do
            guids[#guids+1]=guid seenGUIDs[guid]=true
        end
        for guid in pairs(applied.destroyed or {}) do
            if not seenGUIDs[guid] then guids[#guids+1]=guid end
        end
        table.sort(guids)
        for _,guid in ipairs(guids) do
            parts[#parts+1]=key..":"..guid..":"
                ..tostring((expected.destroyed or {})[guid])..":"
                ..tostring((applied.destroyed or {})[guid])
        end
    end
    -- Fingerprint staged physical discards so a changed selection cannot
    -- use a stale confirmation or its rewind snapshot.
    for _,guid in ipairs(ledger.previewStagedDiscards or {}) do
        parts[#parts+1]="staged:"..guid..":"
            ..tostring((ledger.playDiscardApplied or {})[guid]==true)
    end
    local targets={}
    for source,target in pairs(combatAssignmentState.targets or {}) do
        targets[#targets+1]=tostring(source)..":"..tostring(target)
            ..":"..tostring(combatAssignmentState.explicit[source]==true)
    end
    table.sort(targets)
    for _,target in ipairs(targets) do parts[#parts+1]=target end
    -- Equal Wound totals do not mean equal decisions: a different Unit can
    -- receive the same damage, or a Block/Attack option can be changed while
    -- leaving the pending consequence counts unchanged. Reject that dialog.
    local phase=ledger.phaseLock or combatConfig.phasePreview
    if phase~=nil and phase.seat==ledger.seat
        and gStates~=nil and phase.turn==gStates.turnNumber then
        parts[#parts+1]="phase:"..combatConfig.decisionFingerprint({
            entries=phase.entries,sources=phase.sources,
            enemyEffects=phase.enemyEffects,joined=phase.joined,
            targets=phase.targets,explicit=phase.explicit,
            earlyGroups=phase.earlyGroups,rowBlock=phase.rowBlock,
            spentRange=phase.spentRange,damage=phase.damage,
            damageResults=phase.damageResults,attackDiscards=phase.attackDiscards
        })
    end
    if ledger.phaseLock==nil then
        parts[#parts+1]="choices:"..combatConfig.decisionFingerprint({
            reductions=combatReductionAttackChoice,
            hardened=gStates~=nil and gStates.battleHardenedAttackKey or nil,
            elemental=gStates~=nil and gStates.elementalResistanceAttackKey or nil,
            forked=gStates~=nil and gStates.forkedLightningPhase or nil,
            arrows=gStates~=nil and gStates.attackAssignments or nil
        })
    end
    return table.concat(parts,"|")
end

combatConfig.woundConfirmClose=function()
    combatConfig.woundConfirmation=nil
    UI.setAttribute("CombatDamageConfirm","active","false")
end

-- Only the player viewing this dialog can opt out. Do not persist the choice
-- until damage has actually been committed; Cancel must not change the setting.
function resourceCardsCombatWoundsSkipChanged(player,value,id)
    local confirmation=combatConfig.woundConfirmation
    local color=player~=nil and player.color or nil
    if id~="CombatDamageConfirmDontShowAgain" or confirmation==nil
        or color~=confirmation.color or not resourceCardsPlayerCanEdit(color) then return end
    confirmation.skipNext=value=="True" or value==true
end

-- The original wound button stays unchanged; it only opens the dialog.
function resourceCardsRequestCombatWounds(player)
    local color=player~=nil and player.color or nil
    if not resourceCardsPanelOpen() or not resourceCardsPlayerCanEdit(color)
        or combatConfig.scanAwaitingRescan
        or combatConfig.woundApplying or combatConfig.woundTransactionPending then return end
    -- A previous partial application may have committed the phase but not
    -- finished its physical consequences. Let the player confirm a safe retry.
    local active=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    if active==nil or active.seatPos==nil then return end
    local ledger=combatConfig.woundLedger(active.seatPos)
    if ledger==nil then return end
    local _,hand,discard,changed,effects=combatConfig.woundPending(ledger)
    if hand+discard+effects.destroyCount+effects.stagedDiscardCount==0
        and not effects.handDiscard and not effects.unitCommitPending then
        if changed then
            broadcastToColor("Combat damage changed after consequences were applied. Check physical cards; they cannot be undone automatically.",
                color,warningColor)
        end
        return
    end
    local signature=combatConfig.woundCommitSignature(ledger)
    if signature==nil then return end
    combatConfig.woundConfirmation={
        seat=active.seatPos,turn=gStates.turnNumber,color=color,
        ledger=ledger,signature=signature,skipNext=false}
    -- This option is saved per player colour with the game. Skipping the
    -- prompt still uses the exact validation and protected rewind transaction.
    if gStates.combatDamageSkipConfirmationByColor~=nil
        and gStates.combatDamageSkipConfirmationByColor[color]==true then
        combatConfig.woundConfirmChoice(player,"CombatDamageConfirmApply")
        return
    end
    UI.setAttribute("CombatDamageConfirmDontShowAgain","isOn","false")
    -- Build one complete multilingual string. Concatenating already translated
    -- strings repeats {en}/{it}/... tags, so TTS may display only the first
    -- paragraph and hide the actual wound totals.
    local summaryParts={
        "{en}Calculator will be locked in to attack adjustments only. Use TTS Rewind to undo."
        .."{it}Il calcolatore sarà bloccato: potrai solo modificare gli attacchi. Usa il riavvolgimento TTS per annullare."
        .."{ru}Калькулятор будет заблокирован, кроме корректировок атаки. Для отмены используйте перемотку TTS."
        .."{zh-tw}計算器將鎖定，只允許調整攻擊。若要復原，請使用 TTS 時間回溯。"
        .."{zh-cn}计算器将锁定，只允许调整攻击。若要撤销，请使用 TTS 时间回溯。"
        .."{ko}계산기는 공격 조정만 허용하도록 잠깁니다. 취소하려면 TTS 되감기를 사용하세요."
        .."{es}La calculadora quedará bloqueada, salvo los ajustes de ataque. Usa Rebobinar tiempo de TTS para deshacerlo."
        .."{fr}Le calculateur sera verrouillé, sauf pour ajuster les attaques. Utilisez le retour arrière de TTS pour annuler."
        .."{pt-br}A calculadora ficará bloqueada, exceto para ajustes de ataque. Use o Retroceder tempo do TTS para desfazer."
        .."{de}Der Rechner wird gesperrt; nur Angriffsanpassungen bleiben möglich. Zum Rückgängigmachen TTS-Zeit zurückspulen.",
        " ",
        "{en}Confirm your Ranged/Siege and Block decisions before applying combat damage."
        .."{it}Conferma le decisioni di Attacco a distanza/Assedio e Blocco prima di applicare i danni."
        .."{ru}Подтвердите дальние/осадные атаки и блоки перед применением урона."
        .."{zh-tw}套用戰鬥傷害前，請確認遠程／攻城攻擊與格擋決定。"
        .."{zh-cn}应用战斗伤害前，请确认远程／攻城攻击与格挡决定。"
        .."{ko}전투 피해를 적용하기 전에 원거리/공성 공격과 방어 결정을 확인하세요."
        .."{es}Confirma el ataque a distancia/asedio y el bloqueo antes de aplicar el daño."
        .."{fr}Confirmez les attaques à distance/de siège et les blocages avant d'appliquer les dégâts."
        .."{pt-br}Confirme os ataques à distância/cerco e os bloqueios antes de aplicar o dano."
        .."{de}Fern-/Belagerungsangriffe und Blocks vor dem Schaden bestätigen.",
        "\n\n",
        "{en}Hero Wounds to hand: {it}Ferite in mano: {ru}Раны в руку: {zh-tw}加入手牌的傷害：{zh-cn}加入手牌的伤害：{ko}손에 받는 상처: {es}Heridas a la mano: {fr}Blessures en main : {pt-br}Ferimentos na mão: {de}Wunden auf die Hand: ",
        hand,
        "\n",
        "{en}Poison Wounds to discard: {it}Ferite da Veleno negli scarti: {ru}Ядовитые раны в сброс: {zh-tw}棄牌區的毒傷：{zh-cn}弃牌区的毒伤：{ko}버림더미 독 상처: {es}Heridas de Veneno al descarte: {fr}Blessures de poison en défausse : {pt-br}Ferimentos de Veneno no descarte: {de}Giftwunden in den Ablagestapel: ",
        discard
    }
    local summaryHeight=154
    if effects.unitCommitPending then
        summaryParts[#summaryParts+1]="\n"
        summaryParts[#summaryParts+1]="{en}Unit damage assignments: {it}Assegnazioni dei danni alle Unità: {ru}Назначения урона отрядам: {zh-tw}單位傷害分配：{zh-cn}单位伤害分配：{ko}유닛 피해 배정: {es}Asignaciones de daño a unidades: {fr}Affectations de dégâts aux unités : {pt-br}Atribuições de dano às unidades: {de}Schadenszuweisungen an Einheiten: "
        summaryParts[#summaryParts+1]=effects.unitAssignments
        summaryHeight=summaryHeight+24
    end
    if (ledger.previewOtherWounds or 0)>0 then
        summaryParts[#summaryParts+1]="\n"
        summaryParts[#summaryParts+1]="{en}Other combat Wounds already taken: "
            .."{it}Altre Ferite già ricevute nel combattimento: "
            .."{ru}Другие Раны, уже полученные в бою: "
            .."{zh-tw}本次戰鬥已受到的其他傷害："
            .."{zh-cn}本次战斗已受到的其他伤害："
            .."{ko}이번 전투에서 이미 받은 추가 부상: "
            .."{es}Otras Heridas ya recibidas en combate: "
            .."{fr}Autres Blessures déjà reçues au combat : "
            .."{pt-br}Outros Ferimentos já recebidos em combate: "
            .."{de}Andere im Kampf bereits erhaltene Wunden: "
        summaryParts[#summaryParts+1]=ledger.previewOtherWounds
        summaryHeight=summaryHeight+24
    end
    if effects.handDiscard then
        summaryParts[#summaryParts+1]="\n"
        summaryParts[#summaryParts+1]="{en}Knockout / Paralysis: discard all non-Wound hand cards."
            .."{it}KO / Paralisi: scarta tutte le carte in mano tranne le Ferite."
            .."{ru}Нокаут / Паралич: сбросьте все карты с руки, кроме Ран."
            .."{zh-tw}昏迷／麻痺：棄掉手牌中所有非傷害牌。"
            .."{zh-cn}昏迷／麻痹：弃掉手牌中所有非伤害牌。"
            .."{ko}기절 / 마비: 손에 있는 상처가 아닌 카드를 모두 버립니다."
            .."{es}K.O. / Parálisis: descarta las cartas en mano que no sean Heridas."
            .."{fr}K.O. / Paralysie : défaussez les cartes en main sauf les Blessures."
            .."{pt-br}Nocaute / Paralisia: descarte as cartas na mão que não sejam Ferimentos."
            .."{de}K. o. / Lähmung: Alle Nicht-Wunden auf der Hand abwerfen."
        summaryHeight=summaryHeight+40
    end
    if effects.stagedDiscardCount>0 then
        summaryParts[#summaryParts+1]="\n"
        summaryParts[#summaryParts+1]="{en}Attack-only cards moved from play area: "
            .."{it}Carte solo Attacco scartate dall'area di gioco: "
            .."{ru}Карты только атаки, сбрасываемые из игровой области: "
            .."{zh-tw}將從遊戲區棄掉的純攻擊牌："
            .."{zh-cn}将从游戏区弃掉的纯攻击牌："
            .."{ko}플레이 구역에서 버릴 공격 전용 카드: "
            .."{es}Cartas solo de Ataque descartadas del área de juego: "
            .."{fr}Cartes Attaque uniquement défaussées de la zone de jeu : "
            .."{pt-br}Cartas só de Ataque descartadas da área de jogo: "
            .."{de}Reine Angriffskarten aus dem Spielbereich abwerfen: "
        summaryParts[#summaryParts+1]=effects.stagedDiscardCount
        summaryHeight=summaryHeight+26
    end
    if effects.destroyCount>0 then
        summaryParts[#summaryParts+1]="\n"
        summaryParts[#summaryParts+1]="{en}Paralyzed Units destroyed: {it}Unità paralizzate distrutte: {ru}Уничтожено парализованных отрядов: {zh-tw}將摧毀的麻痺單位：{zh-cn}将摧毁的麻痹单位：{ko}파괴되는 마비 유닛: {es}Unidades paralizadas destruidas: {fr}Unités paralysées détruites : {pt-br}Unidades paralisadas destruídas: {de}Zerstörte gelähmte Einheiten: "
        summaryParts[#summaryParts+1]=effects.destroyCount
        summaryHeight=summaryHeight+28
    end
    local summary=joinLang(summaryParts)
    -- Keep the normal dialog compact but grow for optional Paralysis details.
    UI.setAttribute("CombatDamageConfirmSummary","preferredHeight",tostring(summaryHeight))
    UI.setAttribute("CombatDamageConfirm","height",tostring(summaryHeight+126))
    setUIVisibility("CombatDamageConfirm",{color})
    UI.setAttribute("CombatDamageConfirmSummary","text",summary)
    UI.setAttribute("CombatDamageConfirm","active","true")
end

-- Only a confirmed and successfully snapshotted action reaches the physical
-- wound routine. No custom Undo: Rewind Time restores the entire pre-commit
-- table, including the attack ledger and Units.
combatConfig.woundConfirmChoice=function(player,id)
    local confirmation=combatConfig.woundConfirmation
    local color=player~=nil and player.color or nil
    if type(color)~="string" or confirmation==nil or color~=confirmation.color
        or not resourceCardsPlayerCanEdit(color) then return end
    if id=="CombatDamageConfirmCancel" then
        combatConfig.woundConfirmClose()
        return
    end
    if id~="CombatDamageConfirmApply"
        or combatConfig.woundApplying or combatConfig.woundTransactionPending then return end
    local function stillCurrent()
        local current=turnOrder~=nil and gStates~=nil
            and turnOrder[gStates.turnNumber] or nil
        return resourceCardsPanelOpen() and current~=nil
            and current.seatPos==confirmation.seat
            and gStates.turnNumber==confirmation.turn
            and gStates.combatWoundApplication==confirmation.ledger
            and combatConfig.woundCommitSignature(confirmation.ledger)==confirmation.signature
    end
    if not stillCurrent() then
        combatConfig.woundConfirmClose()
        broadcastToColor("Combat changed since confirmation opened. Review the calculator and try again.",
            color,warningColor)
        return
    end
    if type(storeRewindState)~="function"
        or type(rewindTransactionStart)~="function" then
        broadcastToColor("TTS rewind snapshots are unavailable. Combat damage was not applied.",
            color,warningColor)
        return
    end
    if rewindTransactionCanStartFresh==nil or not rewindTransactionCanStartFresh() then
        broadcastToColor("Another scripted action is still using Rewind Time. Finish that action before committing damage.",
            color,warningColor)
        return
    end
    local owner="Combat damage "..tostring(confirmation.seat)
    combatConfig.woundConfirmClose()
    combatConfig.woundTransactionPending=true
    local function abort(message)
        combatConfig.woundTransactionPending=false
        if rewindTransactionOwnerActive~=nil and rewindTransactionOwnerActive(owner) then
            rewindTransactionFinish(owner)
        end
        if message~=nil then broadcastToColor(message,color,warningColor) end
    end
    local started=rewindTransactionStart(function()
        if not stillCurrent() then
            abort("Combat changed while the rewind point was being saved. No damage was applied; review the calculator.")
            return
        end
        combatConfig.woundTransactionPending=false
        local existingLock=confirmation.ledger.phaseLock
        if existingLock==nil then
            local preview=combatConfig.phasePreview
            if preview==nil or preview.seat~=confirmation.seat
                or preview.turn~=confirmation.turn or preview.damageResults==nil then
                abort("Combat phase snapshot is unavailable. No damage was applied.")
                return
            end
            confirmation.ledger.phaseLock=combatFrozenCopy(preview)
        end
        local ok,startedOrError=pcall(resourceCardsApplyCombatWounds,player,
            function(success,_,physicallyTouched)
                if success and confirmation.skipNext then
                    gStates.combatDamageSkipConfirmationByColor=
                        gStates.combatDamageSkipConfirmationByColor or {}
                    gStates.combatDamageSkipConfirmationByColor[color]=true
                end
                -- A failed validation before any physical mutation must not
                -- strand the player behind an irreversible phase lock.
                -- Partial transfers keep their lock and can be retried safely.
                if not success and not physicallyTouched and existingLock==nil then
                    confirmation.ledger.phaseLock=nil
                    resourceCardsSourceChanged()
                end
                rewindTransactionFinish(owner)
            end)
        if not ok or startedOrError~=true then
            -- A synchronous exception can bypass the normal finish callback.
            -- Release the busy flag while retaining the idempotent ledger.
            combatConfig.woundApplying=false
            -- An exception may occur after a physical move. Preserve the
            -- snapshot conservatively; the next Apply click can retry it.
            if ok and existingLock==nil then
                confirmation.ledger.phaseLock=nil
                resourceCardsSourceChanged()
            end
            abort("Could not apply combat damage safely: "..tostring(startedOrError))
        end
    end,owner,function()
        -- Shared.lua also reports the snapshot failure. Never deal a Wound
        -- without a successful rewind checkpoint.
        combatConfig.woundTransactionPending=false
    end)
    if started~=true then
        combatConfig.woundTransactionPending=false
        broadcastToColor("Could not start a combat rewind transaction. No damage was applied.",
            color,warningColor)
    end
end

-- TTS global UI callbacks live in UI.lua, outside this module's private
-- combatConfig scope. Expose only the confirmation action they need.
function resourceCardsConfirmCombatWounds(player,id)
    combatConfig.woundConfirmChoice(player,id)
end

function resourceCardsApplyCombatWounds(player,onComplete)
    if not resourceCardsPanelOpen() or not resourceCardsPlayerCanEdit(player and player.color or nil)
        or combatConfig.scanAwaitingRescan or combatConfig.woundApplying then return false end
    local current=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    local ledger=current~=nil and combatConfig.woundLedger(current.seatPos) or nil
    local allocations,hand,discard,changed,effects=combatConfig.woundPending(ledger)
    if current==nil or ledger==nil then return false end
    if hand+discard==0 and not effects.handDiscard
        and effects.destroyCount+effects.stagedDiscardCount==0
        and not effects.unitCommitPending then
        if changed then
            broadcastToColor("Combat damage changed after Wounds were dealt. Check the physical cards; none are removed automatically.",
                player.color,warningColor)
        end
        return false
    end
    ledger.warned=nil
    combatConfig.woundApplying=true
    local seat=current.seatPos
    local function record(key)
        local applied=ledger.applied[key]
        if applied==nil then
            applied={hand=0,discard=0}
            ledger.applied[key]=applied
        end
        return applied
    end
    local settlingGUIDs={}
    local unitAreaTouched=false
    local physicallyTouched=false
    local completing=false
    local finalized=false
    local function finish(success,reason)
        if completing then return end
        completing=true
        local function finalise()
            if finalized then return end
            finalized=true
            combatConfig.woundApplying=false
            if not success then
                broadcastToColor("Apply Wounds stopped: "..tostring(reason)
                    ..". Check the physical cards and click again to finish.",
                    player.color,warningColor)
            end
            -- UI refresh errors must not strand a protected rewind transaction.
            local refreshed,refreshError=pcall(function()
                resourceCardsSourceChanged()
                mainUIUpdate("Combat Wounds applied")
            end)
            if onComplete~=nil then onComplete(success,reason,physicallyTouched) end
            if not refreshed then error(refreshError) end
        end
        if onComplete==nil or (not unitAreaTouched and next(settlingGUIDs)==nil)
            or safeWaitFrames==nil or safeWaitCondition==nil then
            finalise()
        else
            -- TTS smooth movement continues after setPositionSmooth returns.
            -- Keep the rewind transaction open until the last affected card
            -- settles, never expose a partial physical snapshot mid-commit.
            safeWaitFrames("PlayerBoard.CardRecognition",function()
                safeWaitCondition("PlayerBoard.CardRecognition",finalise,function()
                    for guid in pairs(settlingGUIDs) do
                        local obj=getObjectFromGUID(guid)
                        if obj~=nil and ((obj.isSmoothMoving~=nil and obj.isSmoothMoving())
                            or obj.resting==false) then return false end
                    end
                    return true
                end,45,function()
                    -- TTS automatically releases rewind suppression at 60s.
                    -- Report a rare stuck physics transfer rather than
                    -- silently exposing an intermediate rewind state.
                    broadcastToColor("Combat cards have not settled after 45 seconds. Check the table; use TTS Rewind Time if necessary.",
                        player.color,warningColor)
                    finalise()
                end)
            end,unitAreaTouched and 18 or 3)
        end
    end
    local function commitConsequences()
        -- Knockout and Paralysis share exactly one hand discard. Its saved
        -- flag prevents retries from discarding newly drawn cards again.
        if effects.handDiscard then
            local discardZone=getObjectFromGUID(deedDeckDiscardZones~=nil
                and deedDeckDiscardZones[seat] or nil)
            if discardZone==nil then
                finish(false,"Discard zone missing for Knockout/Paralysis")
                return
            end
            -- The hand helper accepts either the scripting hand zone or the
            -- native TTS HandTrigger, and rejects an uninspectable hand.
            -- Failed validation (for example, a card being held) is safe to
            -- retry. After a partial transfer, mark the hand effect committed
            -- and ask for manual correction, never discard new draws on retry.
            local ok,success,countOrReason,moved,partialGUIDs=
                pcall(combatDiscardParalyzedHand,seat,player.color)
            local movedCount=ok and success==true
                and (tonumber(countOrReason) or 0) or (tonumber(moved) or 0)
            if movedCount>0 then physicallyTouched=true end
            if not ok or success~=true then
                -- Do not acknowledge an exception or partial failure as an
                -- applied hand discard: previously this permanently skipped
                -- Knockout/Paralysis even when zero cards had actually moved.
                -- A retry inspects the remaining hand, without repeating the
                -- Wounds already committed in the damage ledger.
                for _,guid in ipairs(type(partialGUIDs)=="table" and partialGUIDs or {}) do
                    settlingGUIDs[guid]=true
                end
                finish(false,"Knockout/Paralysis hand discard: "
                    ..tostring(ok and countOrReason or success))
                return
            end
            ledger.handDiscardApplied=true
            for _,key in ipairs(effects.paralyse) do record(key).paralyse=true end
            -- On success the fourth pcall value is the transferred GUID list.
            for _,guid in ipairs(type(moved)=="table" and moved or {}) do
                settlingGUIDs[guid]=true
            end
        end
        -- Transfer the exact Attack-only physical GUIDs frozen before the
        -- Damage commit. Hand cards have already been handled separately.
        -- Each successful GUID is saved immediately so a partial failure,
        -- saved game, or retry never discards a card twice.
        if effects.stagedDiscardCount>0 then
            if type(combatDiscardStagedAttackCards)~="function" then
                finish(false,"Staged Attack discard helper is unavailable")
                return
            end
            local ok,success,countOrReason,moved,partial=
                pcall(combatDiscardStagedAttackCards,seat,effects.stagedDiscards)
            local confirmed=success==true and moved or partial
            for _,guid in ipairs(type(confirmed)=="table" and confirmed or {}) do
                ledger.playDiscardApplied[guid]=true
                settlingGUIDs[guid]=true
                physicallyTouched=true
            end
            if not ok or success~=true then
                finish(false,"Staged Attack discard: "
                    ..tostring(ok and countOrReason or success))
                return
            end
        end
        for _,effect in ipairs(effects.destroyed) do
            local applied=record(effect.key)
            applied.destroyed=applied.destroyed or {}
            if applied.destroyed[effect.guid]==nil then
                if attackAssignmentsUnitPreviewApplyDestroyed==nil then
                    finish(false,"Paralysis Unit cleanup is unavailable")
                    return
                end
                -- Capture this Unit's already-resolved Ranged/Siege and Block
                -- before physically removing its resource source from the mat.
                if combatConfig.captureParalyzedUnitSources~=nil then
                    combatConfig.captureParalyzedUnitSources(seat,effect.guid)
                end
                -- Accessory detachment may partially move objects before
                -- reporting an error, so retain the phase lock conservatively.
                physicallyTouched=true
                local ok,movedOrReason=attackAssignmentsUnitPreviewApplyDestroyed(seat,effect.guid)
                if not ok then
                    finish(false,movedOrReason)
                    return
                end
                for _,guid in ipairs(type(movedOrReason)=="table" and movedOrReason or {}) do
                    settlingGUIDs[guid]=true
                end
                -- Unit-area compaction is scheduled 0.2 seconds after
                -- removal. Wait through that timer and the resulting smooth
                -- moves before allowing TTS to store further rewind states.
                unitAreaTouched=true
                local zoneGUID=playerUnitAreas~=nil and playerUnitAreas[seat] or nil
                local zone=zoneGUID~=nil and getObjectFromGUID(zoneGUID) or nil
                for _,obj in ipairs(zone~=nil and zone.getObjects() or {}) do
                    if obj.guid~=nil then settlingGUIDs[obj.guid]=true end
                end
                applied.destroyed[effect.guid]=effect.absorbed
            end
        end
        -- Commit previewed Banner uses only after all physical consequences
        -- succeed. A failed transfer can retry against its frozen phase.
        if effects.unitCommitPending then
            if next(ledger.previewFortitude or {})~=nil then
                local uses=trackerPrivate.bannerEffectUses().fortitude
                for guid,use in pairs(ledger.previewFortitude) do
                    if uses[guid]==nil then uses[guid]={attackKey=use.attackKey} end
                end
            end
            ledger.damageAssignmentsCommitted=true
        end
        finish(true)
    end
    if hand+discard==0 then
        local ok,reason=pcall(commitConsequences)
        if not ok then finish(false,reason) end
        return true
    end
    combatDealCalculatedWounds(seat,allocations,
        function(key,destination,guid)
            physicallyTouched=true
            local applied=record(key)
            applied[destination]=(applied[destination] or 0)+1
            if destination=="hand" then ledger.cards[guid]=true end
            settlingGUIDs[guid]=true
        end,
        function(success,reason)
            if not success then
                finish(false,reason)
            else
                local ok,problem=pcall(commitConsequences)
                if not ok then finish(false,problem) end
            end
        end)
    return true
end

-- A soft two-click acknowledgement also works if the tracker was minimized.
-- An in-progress physical transfer is always held until its queue finishes.
function combatWoundsEndTurnReminder(color)
    if combatConfig.scanAwaitingRescan then
        safeBroadcastToColor("Combat resources are being recalculated. Review the calculator before ending the turn.",
            color,warningColor)
        return true
    end
    if combatConfig.woundConfirmation~=nil then
        safeBroadcastToColor("Confirm or cancel Combat Damage before ending the turn.",
            color,warningColor)
        return true
    end
    if combatConfig.woundTransactionPending then
        safeBroadcastToColor("A safe Combat Damage rewind point is being saved. Finish before ending the turn.",
            color,warningColor)
        return true
    end
    local current=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    local ledger=current~=nil and gStates.combatWoundApplication or nil
    if current==nil or ledger==nil or ledger.seat~=current.seatPos then return false end
    if combatConfig.woundApplying then
        safeBroadcastToColor("Combat consequences are still being applied. Finish before ending combat.",
            color,warningColor)
        return true
    end
    local _,hand,discard,changed,effects=combatConfig.woundPending(ledger)
    if effects.unitCommitPending then
        safeBroadcastToColor("Confirm Unit damage with Give Wounds, or remove the damage assignments before ending the turn.",
            color,warningColor)
        return true
    end
    if hand+discard==0 and not effects.handDiscard
        and effects.destroyCount+effects.stagedDiscardCount==0
        and not changed then return false end
    local signature=tostring(hand)..":"..tostring(discard)..":"..tostring(changed)
        ..":"..tostring(effects.paralyseCount)..":"..tostring(effects.destroyCount)
        ..":"..tostring(effects.knockout)
        ..":"..tostring(effects.stagedDiscardCount)
    if ledger.warned==signature then return false end
    ledger.warned=signature
    local message
    if hand+discard>0 or effects.handDiscard or effects.destroyCount>0
        or effects.stagedDiscardCount>0 then
        message="Unapplied combat: "..tostring(hand).." Wounds to hand, "
            ..tostring(discard).." to discard"
        if effects.handDiscard then
            message=message..", Knockout/Paralysis hand discard pending"
        end
        if effects.destroyCount>0 then
            message=message..", "..tostring(effects.destroyCount)
                .." Paralyzed Units to destroy"
        end
        if effects.stagedDiscardCount>0 then
            message=message..", "..tostring(effects.stagedDiscardCount)
                .." Attack-only played cards to discard"
        end
        message=message..". Use Apply Wounds, or click End Turn again if handled manually."
    else
        message="Combat damage changed after effects were applied. Check physical cards; click End Turn again to continue."
    end
    safeBroadcastToColor(message,color,warningColor)
    return true
end

trackerPrivate.combatDisplay=require("PlayingGame.PlayerBoard.ResourceTracker.Interface.CombatDisplay")(
    combatConfig,combatRich,combatEnemyTraitsText)
local combatDamageNotes=trackerPrivate.combatDisplay.damageNotes
local combatCompactResultLines=trackerPrivate.combatDisplay.compactResultLines

local combatGroupEntry=trackerPrivate.enemyDefences.groupEntry
local combatRangeGroupEntry=trackerPrivate.enemyDefences.rangeGroupEntry

local combatGroupTraitsText=trackerPrivate.combatDisplay.groupTraitsText
local combatGroupAttackLine=trackerPrivate.combatDisplay.groupAttackLine

trackerPrivate.combatDefenderMarks={}
combatConfig.COMBAT_DEFENDER_DECAL_URLS={
    [1]="https://steamusercontent-a.akamaihd.net/ugc/10632112705667530745/ABBA1BEC1D6355C0F4E08DA79140A8CB24A03A7A/",
    [2]="https://steamusercontent-a.akamaihd.net/ugc/10268219428207943773/49479D6AF430568A0B487F79709FD20C77E3BA6C/"}

local function combatSetDefenderDecal(guid,amount)
    local obj=guid~=nil and getObjectFromGUID(guid) or nil
    if obj==nil then return end
    local decals={}
    for _,decal in pairs(obj.getDecals() or {}) do
        if decal.name~="DefenderArmour" then decals[#decals+1]=decal end
    end
    if amount~=nil then
        decals[#decals+1]={name="DefenderArmour",url=combatConfig.COMBAT_DEFENDER_DECAL_URLS[amount>=2 and 2 or 1],
            position={0.0,0.15,-1.2},rotation={90,180,0},scale={0.72,0.72,1}}
    end
    obj.setDecals(decals)
end

-- Marks the enemies currently receiving a Defender armour bonus ({guid=bonus}); pass nil to clear.
local function combatSyncDefenderMark(marks)
    local wanted={}
    for guid,amount in pairs(marks or {}) do wanted[guid]=amount>=2 and 2 or 1 end
    for guid,key in pairs(trackerPrivate.combatDefenderMarks) do
        if wanted[guid]==nil then combatSetDefenderDecal(guid,nil) end
    end
    for guid,key in pairs(wanted) do
        if trackerPrivate.combatDefenderMarks[guid]~=key then combatSetDefenderDecal(guid,key) end
    end
    trackerPrivate.combatDefenderMarks=wanted
end

trackerPrivate.bossAllocation=require("PlayingGame.PlayerBoard.ResourceTracker.Combat.BossAllocation")(combatEnemyHasTrait)
-- Preserve the public level-count helper for other modules.
function combatBossLevelCount(total,armour,remaining)
    return trackerPrivate.bossAllocation.levelCount(total,armour,remaining)
end

local function combatBossPhasePlan(group,entries,total,phase,blockedAll)
    return trackerPrivate.bossAllocation.phasePlan(group,entries,total,phase,blockedAll,
        gStates~=nil and gStates.combatBossManual or nil)
end

trackerPrivate.defendAllocation=require("PlayingGame.PlayerBoard.ResourceTracker.Combat.DefendAllocation")(
    trackerPrivate.enemyDefences,combatRangeResult)
local function combatApplyDefend(entries,groups,allocated)
    return trackerPrivate.defendAllocation(entries,groups,allocated,
        gStates~=nil and gStates.forkedLightningPhase or nil)
end

local combatGroupResourceRows=trackerPrivate.combatDisplay.groupResourceRows

trackerPrivate.combatEffectDisplay=require("PlayingGame.PlayerBoard.ResourceTracker.Interface.CombatEffectDisplay")(
    trackerPrivate.enemyDefences,combatEnemyAttacks,combatEnemyPrintedAttacks,
    function(spec) return combatEffectArrowKind(spec) end,
    function(spec) return combatEffectRequiresDefence(spec) end,
    function(guid) return skillResourceDefinitions[guid] end,
    function(guid)
        local source=getObjectFromGUID(guid)
        local name=source~=nil and source.getName~=nil and source.getName() or tostring(guid)
        return joinLangEnglish~=nil and joinLangEnglish(tostring(name)) or tostring(name)
    end)
combatConfig.effectButtonInfo=trackerPrivate.combatEffectDisplay.effectButtonInfo
combatConfig.mitigationButtonInfo=trackerPrivate.combatEffectDisplay.mitigationButtonInfo

trackerPrivate.attackEligibility=require("PlayingGame.PlayerBoard.ResourceTracker.Combat.AttackEligibility")(
    combatConfig,
    function(seat) return seat~=nil and resourceCardScanBySeat[seat] or nil end,
    function(guid) return gameCards~=nil and gameCards[guid] or nil end,
    function(key) return cardResourceDefinitions~=nil and cardResourceDefinitions[key] or nil end,
    function(guid) return getObjectFromGUID(guid) end)
combatConfig.unitsWoundedByDamage=trackerPrivate.attackEligibility.unitsWoundedByDamage
combatConfig.paralysisAttackCards=trackerPrivate.attackEligibility.paralysisAttackCards
combatConfig.knockoutStagedAttackCards=trackerPrivate.attackEligibility.knockoutStagedAttackCards
combatConfig.attackPhaseSources=trackerPrivate.attackEligibility.attackPhaseSources

trackerPrivate.unitSelfWounds=require("PlayingGame.PlayerBoard.ResourceTracker.Units.UnitSelfWounds")(
    function(guid) return unitResourceDefinitions~=nil and unitResourceDefinitions[guid] or nil end,
    function(...) return unitHistoryUses(...) end,
    function(...) return unitHistoryKey(...) end,
    function(guid) return getObjectFromGUID(guid) end,
    function(...) return unitManaDecision(...) end)
combatConfig.selfWoundingUnitChoices=function(seat,groups)
    local scan=seat~=nil and resourceCardScanBySeat[seat] or nil
    return trackerPrivate.unitSelfWounds(seat,groups,scan~=nil and scan.cards or {},
        gStates~=nil and gStates.unitResourceActivations or {})
end

combatConfig.applyExplosiveBoltRange=require("PlayingGame.PlayerBoard.ResourceTracker.Combat.ExplosiveBolt")(
    combatApplyDefend,combatRangeGroupEntry,combatRangeResult,combatEnemyHasTrait,
    function(key) return combatAssignmentState.targets[key] end,
    function(key) return attackAssignmentsTargetGUIDs(key) end,
    function(key,guid,arrow) return attackAssignmentsReconcileEffectTarget(key,guid,arrow) end)

trackerPrivate.combatPanelLayout=require("PlayingGame.PlayerBoard.ResourceTracker.Interface.CombatPanel").layout
combatConfig.enemyNameColumnWidth=trackerPrivate.combatPanelLayout.enemyNameColumnWidth
combatConfig.textColumnWidth=trackerPrivate.combatPanelLayout.textColumnWidth
combatConfig.traitColumnWidth=trackerPrivate.combatPanelLayout.traitColumnWidth

trackerPrivate.enemyGroups=require("PlayingGame.PlayerBoard.ResourceTracker.Combat.EnemyGroups")

trackerPrivate.divisibleResources=require("PlayingGame.PlayerBoard.ResourceTracker.Combat.DivisibleResources")(
    function(key) return attackAssignmentsTargetCounts(key) end,
    combatGUIDHasCumbersome,combatEnemyAttacks)

trackerPrivate.sourceTargetAllocation=require("PlayingGame.PlayerBoard.ResourceTracker.Combat.SourceTargetAllocation")(
    function(key) return attackAssignmentsTargetGUIDs(key) end,
    function(key) return attackAssignmentsClearForObject(key) end,
    function(key,guid) return resourceCardsCombatTargetAcceptsSource(key,guid) end,
    combatGUIDHasCumbersome,combatNearestEnemyGUID,
    function(key) return attackAssignmentsIsTargeting(key) end,
    function(...) return attackAssignmentsEnsureTarget(...) end,
    combatSourceArrowKind,combatEnemyAttacks,trackerPrivate.divisibleResources,
    function()
        local seat=combatAssignmentActiveSeat()
        return seat~=nil and resourceCardScanBySeat[seat] or nil
    end,combatSourceKeepsLock)

trackerPrivate.flameWave=require("PlayingGame.PlayerBoard.ResourceTracker.Combat.FlameWave")(
    combatApplyDefend,trackerPrivate.enemyGroups.collect,combatRangeGroupEntry,combatRangeResult)

trackerPrivate.conditionalBlockEffects=require("PlayingGame.PlayerBoard.ResourceTracker.Combat.ConditionalBlockEffects")(
    combatApplyDefend,trackerPrivate.enemyGroups.collect,combatRangeGroupEntry,combatRangeResult,
    combatEnemyAttacks,combatBlockResult,
    function(...) return combatEffectDestroysFullyBlocked(...) end,combatEnemyHasTrait,
    function(guid) return monsterPugs[guid] end,
    function(guid) return gStates~=nil and gStates.monsterPerks~=nil and gStates.monsterPerks[guid] or nil end)

trackerPrivate.earlyCombatPhase=require("PlayingGame.PlayerBoard.ResourceTracker.Combat.EarlyCombatPhase")(
    combatBlockResult,combatGroupEntry,combatRangeResult,combatRangeGroupEntry,
    combatBossPhasePlan,combatEnemyAttacks,combatEnemyHasTrait,combatFrozenCopy)
trackerPrivate.damagePreparation=require("PlayingGame.PlayerBoard.ResourceTracker.Combat.DamageCalculation").preparation(
    function(guid) return skillResourceDefinitions[guid] end)
trackerPrivate.lateCombatPhase=require("PlayingGame.PlayerBoard.ResourceTracker.Combat.LateCombatPhase")(
    combatGroupEntry,combatEnemyHasTrait,combatEnemyFortificationCount,
    function(result) return combatVampiricArmourGain(result) end,
    function(...) return combatEffectPostDamageSpecs(...) end,combatFrozenCopy,
    combatConfig.attackPhaseSources,combatAttackTotal,combatBossPhasePlan)

trackerPrivate.combatResourceDisplay=require("PlayingGame.PlayerBoard.ResourceTracker.Interface.CombatResourceDisplay")(
    combatConfig,function(guid) return skillResourceDefinitions[guid] end,
    combatDetailPhase,combatEnemyResists,combatGroupResourceRows)
trackerPrivate.combatRowRenderer=require("PlayingGame.PlayerBoard.ResourceTracker.Interface.CombatRowRenderer")(
    combatConfig,combatPanelSetAttribute,combatAssignmentIconButton,combatEnemyHasTrait,
    combatGroupTraitsText,combatEnemyAttacks,combatTypeRich,combatNatureVengeanceBlockBonus,
    combatRich,combatDamageNotes,combatGroupAttackLine,combatCompactResultLines,
    function(guid) return monsterPugs[guid] end,trackerPrivate)
trackerPrivate.combatPanelRenderer=require("PlayingGame.PlayerBoard.ResourceTracker.Interface.CombatPanel").renderer(
    combatConfig,combatPanelSetAttribute,combatRich,combatWoundsText,
    function(...) return joinLang(...) end,trackerPrivate)

local function combatAssignmentRefreshRows(entries,sources)
    -- Exclusive stage timings within combat.rows. Existing block.result,
    -- damage.phase and UI counters are nested measurements, not extra time.
    local stageProfile
    if trackerPrivate.traceEnabled then stageProfile=trackerPrivate.profileStart() end
    combatConfig.resultRowCache={}
    combatConfig.slotSelection={}
    combatConfig.effectSources={}
    local rowByGUID={}
    local totalRowHeight=0
    combatAssignmentRowTargets={}
    combatAssignmentRowIndices={}
    local pages,pageOffset,pageEnd,visibleRows
    combatEnemyPage,pages,pageOffset,pageEnd,visibleRows=trackerPrivate.combatPanelLayout.paginate(
        entries,combatAssignmentJoined,combatConfig.crowdedPageSize,combatConfig.rowCount,combatEnemyPage)
    for index,entry in ipairs(entries) do rowByGUID[entry.guid]=index end
    for row=1,combatConfig.rowCount do
        local entry=row<=visibleRows and entries[pageOffset+row] or nil
        if entry~=nil then
            combatAssignmentRowTargets[row]=entry.guid
            combatAssignmentRowIndices[row]=pageOffset+row
        end
    end
    combatPanelSetAttribute("CombatEnemyPageControls","active",pages>1 and "true" or "false")
    combatPanelSetAttribute("CombatEnemyPageLabel","text",
        tostring(visibleRows>0 and pageOffset+1 or 0).."-"..tostring(pageEnd)
            .." / "..tostring(#entries))
    local maxResourceCounts={range=0,block=0,attack=0}
    -- Text shown in the ability columns and the columns that hold anything, so empty columns can be hidden.
    local shownTraits,shownOffence,shownAttacks,colUsed={},{},{},{range=false,block=false,attack=false}
    local groups,groupOf=trackerPrivate.enemyGroups.build(entries,combatAssignmentJoined)
    if stageProfile~=nil then stageProfile=trackerPrivate.profileCheckpoint("rows.grouping",stageProfile) end
    local enemyNameWidth=trackerPrivate.combatPanelLayout.nameColumnWidth(entries,groupOf,pageOffset,pageEnd)
    combatConfig.columns.Name=enemyNameWidth
    for row=1,combatConfig.rowCount do
        combatPanelSetAttribute("CombatEnemyNameCell"..row,"preferredWidth",tostring(enemyNameWidth))
    end
    for row=1,combatConfig.rowCount do
        local index=pageOffset+row
        local entry=row<=visibleRows and entries[index] or nil
        local group=entry~=nil and groupOf[index] or nil
        combatPanelSetAttribute("CombatEnemyRow"..row,"active",entry~=nil and "true" or "false")
        combatPanelSetAttribute("CombatEnemyRow"..row,"color",
            (group~=nil and #group.members>1) and "rgb(0.27,0.31,0.38)"
            or (index%2==0 and "rgb(0.34,0.29,0.22)" or "rgb(0.29,0.25,0.19)"))
        if entry~=nil and group~=nil then
            combatPanelSetAttribute("CombatEnemyRow"..row.."Name","text",
                (group.leader~=index and "+ " or "")..entry.name)
            local ownTraits=combatEnemyTraitsText(entry.data,entry.perks,combatConfig.enemyDefenceTraits)
            shownTraits[row]=ownTraits
            combatPanelSetAttribute("CombatEnemyRow"..row.."Traits","text",ownTraits)
            combatPanelSetAttribute("CombatEnemyRow"..row.."Armour","font","Fonts/MKCardText")
            combatPanelSetAttribute("CombatEnemyRow"..row.."Traits","font","Fonts/MKCardText")
            combatPanelSetAttribute("CombatEnemyRow"..row.."Name","color","rgb(0.96,0.92,0.82)")
            combatPanelSetAttribute("CombatEnemyRow"..row.."Armour","color","rgb(0.96,0.92,0.82)")
            combatPanelSetAttribute("CombatEnemyRow"..row.."Traits","color","rgb(0.88,0.84,0.73)")
            local attacks=combatEnemyAttacks(entry,true)
            local options={}
            if #entry.attackReductions>0 then
                for attackIndex,attack in ipairs(attacks) do
                    if not attack.pending then options[#options+1]=attackIndex end
                end
            end
            local selectable=#options>1
            combatAttackChoiceByRow[row]=selectable
                and {options=options,reductions=entry.attackReductions} or nil
            combatPanelSetAttribute("CombatEnemyAttackCycle"..row,"active",selectable and "true" or "false")
            if selectable then
                local active=combatReductionActiveSource[entry.guid]
                local rank=1
                for i,reduction in ipairs(entry.attackReductions) do
                    if (reduction.id or tostring(reduction.source))==active then rank=i break end
                end
                local selected=entry.attackReductions[rank]
                combatReductionActiveSource[entry.guid]=selected.id or tostring(selected.source)
                local sourceData=gameCards[selected.source]
                local sourceName=sourceData~=nil and sourceData.name or selected.source
                if type(sourceName)=="table" then sourceName=sourceName[1] end
                combatPanelSetAttribute("CombatEnemyAttackCycle"..row,"tooltip",
                    "Reduction "..tostring(rank).."/"..tostring(#entry.attackReductions)
                    ..": "..tostring(sourceName)
                    ..(selected.cancelAttack and " (cancel one Attack)"
                        or selected.stripAbilities and " (remove abilities)"
                        or (" (-"..tostring(selected.amount)..")"))
                    ..". Left-click: cycle target (including Auto). Right-click: next reduction source.")
            end
            for _,column in ipairs({"Attacks","Offence","Traits"}) do
                local id="CombatEnemyRow"..row..column
                combatPanelSetAttribute(id,"font","Fonts/MKCardText")
                combatPanelSetAttribute(id,"color","rgb(0.88,0.84,0.73)")
                combatPanelSetAttribute(id,"alignment","MiddleCenter")
            end
            local offenceText=combatEnemyOffenceTraits(entry)
            shownOffence[row]=offenceText
            combatPanelSetAttribute("CombatEnemyRow"..row.."Offence","text",offenceText)
            local traitLines=math.max(select(2,offenceText:gsub("\n",""))+1,
                select(2,ownTraits:gsub("\n",""))+1)
            -- Dynamic text widths are owned by the final column layout.
            -- Do not overwrite them with legacy defaults before measuring them again.
            combatPanelSetAttribute("CombatEnemyRow"..row.."Name","preferredWidth",tostring(enemyNameWidth))
            combatPanelSetAttribute("CombatEnemyRow"..row.."Armour","preferredWidth",tostring(combatConfig.columns.Armour))
            entry.attackCount=math.max(#attacks,traitLines)
        end
    end

    if stageProfile~=nil then stageProfile=trackerPrivate.profileCheckpoint("rows.enemyHeaders",stageProfile) end
    combatAssignmentSlotSources={}
    combatConfig.slotBowFamilies={}
    local allocated=trackerPrivate.sourceTargetAllocation.allocate(
        entries,sources,rowByGUID,combatAssignmentState,combatCumbersomeActive,
        trackerPrivate.traceEnabled and function(key,field,allowed,actual)
            trackerPrivate.traceEvent("resource.overallocated",combatAssignmentActiveSeat(),key,
                field.." budget="..tostring(allowed).." allocated="..tostring(actual))
        end or nil,trackerPrivate)

    if stageProfile~=nil then stageProfile=trackerPrivate.profileCheckpoint("rows.allocation",stageProfile) end
    combatConfig.applyExplosiveBoltRange(entries,groups,allocated,sources)

    trackerPrivate.flameWave(entries,groups,allocated,sources)

    local rangedBeforeBlock,conditionalDestroyed=trackerPrivate.conditionalBlockEffects.destroyAfterBlock(entries,groups,allocated)
    if conditionalDestroyed then
        -- A newly destroyed member splits joined groups just like a pre-destroyed member.
        -- Keep group visuals and group memberships consistent with the resulting combat.
        groups,groupOf=trackerPrivate.enemyGroups.build(entries,combatAssignmentJoined)
        for index=1,#entries do
            local group=groupOf[index]
            local row=index-pageOffset
            if row>=1 and row<=visibleRows then
                combatPanelSetAttribute("CombatEnemyRow"..row,"color",
                    #group.members>1 and "rgb(0.27,0.31,0.38)"
                    or (row%2==0 and "rgb(0.34,0.29,0.22)" or "rgb(0.29,0.25,0.19)"))
            end
            if entries[index].destroyed then entries[index].attackCount=1 end
        end
    end

    local emptyTarget={sources={},details={}}
    local defended=combatApplyDefend(entries,groups,allocated)
    local defendMarks={}
    for index,amount in pairs(defended) do defendMarks[entries[index].guid]=amount end
    combatSyncDefenderMark(defendMarks)
    trackerPrivate.conditionalBlockEffects.burningShield(entries,allocated,emptyTarget)
    local function defeatedCount(group,rangedOnly)
        return trackerPrivate.lateCombatPhase.defeatedCount(entries,group,rangedOnly)
    end
    local rowBlock=trackerPrivate.earlyCombatPhase.resolve(entries,groups,allocated,emptyTarget,rangedBeforeBlock)
    local earlyLock=combatPhaseLock(combatAssignmentActiveSeat())
    rowBlock=trackerPrivate.earlyCombatPhase.snapshot(
        entries,groups,groupOf,rowBlock,earlyLock,combatConfig.phasePreview)
    local blockedEnemies=trackerPrivate.earlyCombatPhase.countBlockedEnemies(entries,groups,rowBlock)
    local blockSeat=combatAssignmentActiveSeat()
    if blockSeat~=nil then
        local previousBlocked=combatConfig.blockedEnemyCounts[blockSeat] or 0
        combatConfig.blockedEnemyCounts[blockSeat]=blockedEnemies
        if previousBlocked~=blockedEnemies and resourceCardsSourceChanged~=nil then
            resourceCardsSourceChanged()
        end
    end
    if stageProfile~=nil then stageProfile=trackerPrivate.profileCheckpoint("rows.earlyCombat",stageProfile) end
    -- Damage phase: each unblocked attack of an enemy that is not already defeated starts on the Hero.
    local damageSeat=combatAssignmentActiveSeat()
    local selfWoundsEarly,selfWoundsLate=combatConfig.selfWoundingUnitChoices(damageSeat,groups)
    local damageProfile
    if trackerPrivate.traceEnabled then damageProfile=trackerPrivate.profileStart() end
    local damageUnits,nativeCommandCount=combatDamageUnits(damageSeat)
    if damageProfile~=nil then damageProfile=trackerPrivate.profileCheckpoint("damage.unitDiscovery",damageProfile) end
    local damageSpec,damageItems=trackerPrivate.damagePreparation.build(entries,groups,rowBlock,damageUnits,selfWoundsEarly)
    if damageProfile~=nil then damageProfile=trackerPrivate.profileCheckpoint("damage.prepare",damageProfile) end
    attackAssignmentsDamageSync(damageSpec)
    if damageProfile~=nil then trackerPrivate.profileFinish("damage.targetSync",damageProfile) end
    local seatScan=damageSeat~=nil and resourceCardScanBySeat[damageSeat] or nil
    local mitigation,elementMitigation=trackerPrivate.damagePreparation.mitigationFor(seatScan,damageItems,gStates)
    damageProfile=trackerPrivate.traceEnabled and (trackerPrivate.profileStart() or true) or nil
    local damageResults
    if earlyLock~=nil and earlyLock.damageResults~=nil then
        -- Do not recalculate the committed Damage phase just to discard it.
        -- Restore the mitigation controls from the same authoritative results.
        damageResults=combatFrozenCopy(earlyLock.damageResults)
        trackerPrivate.damagePreparation.restoreMitigations(damageResults,mitigation,elementMitigation)
        if trackerPrivate.traceEnabled then trackerPrivate.profileCount("damage.frozen") end
    else
        damageResults=combatDamageResolve(damageItems,damageUnits,
            combatHeroArmour(nativeCommandCount),attackAssignmentsDamageTargetsOf,
            mitigation,elementMitigation,seatScan~=nil and seatScan.heroFirstWoundIgnored==true,
            gStates~=nil and gStates.combatWoundApplication~=nil
                and gStates.combatWoundApplication.seat==damageSeat
                and gStates.combatWoundApplication.applied or nil)
        if trackerPrivate.traceEnabled then trackerPrivate.profileCount("damage.resolved") end
        if combatConfig.phasePreview~=nil then
            combatConfig.phasePreview.damageResults=combatFrozenCopy(damageResults)
            if attackAssignmentsDamageSnapshot~=nil then
                combatConfig.phasePreview.damage=attackAssignmentsDamageSnapshot()
            end
        end
    end
    if damageProfile~=nil then trackerPrivate.profileFinish("damage.phase",damageProfile) end

    if stageProfile~=nil then stageProfile=trackerPrivate.profileCheckpoint("rows.damage",stageProfile) end
    trackerPrivate.lateCombatPhase.vampiric(entries,groups,rowBlock,damageItems,damageResults)

    trackerPrivate.lateCombatPhase.lateEffects(entries,groups,rowBlock,earlyLock,seatScan,combatEffectPostDamageSpecs~=nil)

    trackerPrivate.lateCombatPhase.dodgeAfterDamage(sources,damageResults)
    -- An unblocked Paralyzing Wound or Knockout removes planned hand-card
    -- Attacks in the later phase. A successful Block or a Unit assignment
    -- can restore these resources while damage has not been committed.
    -- Wounds received from played-card costs DURING this combat count
    -- toward Knockout alongside enemy hits, but never double-count the
    -- calculated Wounds already delivered by the damage transaction.
    local totalHeroWounds,totalDiscardWounds=0,0
    for _,result in pairs(damageResults) do
        totalHeroWounds=totalHeroWounds+(tonumber(result.heroWounds) or 0)
        totalDiscardWounds=totalDiscardWounds+(tonumber(result.discard) or 0)
    end
    local otherCombatWounds=combatConfig.combatOtherWounds(damageSeat)
    local currentPlayer=turnOrder~=nil and gStates~=nil
        and turnOrder[gStates.turnNumber] or nil
    local handLimit=math.max(1,tonumber(currentPlayer~=nil and currentPlayer.baseHand) or 5)
    local knockout=totalHeroWounds+otherCombatWounds>=handLimit
    local paralysisAttackCards=combatConfig.paralysisAttackCards(sources,damageResults,earlyLock,knockout)
    local stagedAttackCards={}
    if earlyLock~=nil and earlyLock.attackDiscards~=nil then
        stagedAttackCards=earlyLock.attackDiscards
    elseif next(paralysisAttackCards)~=nil then
        stagedAttackCards=combatConfig.knockoutStagedAttackCards(
            sources,paralysisAttackCards,damageSeat,combatConfig.phasePreview)
    end
    -- Blocks: only suppress remaining Unit attacks after *actual* wounds.
    -- Resisted assignments that cause no Wound leave the Unit eligible.
    local woundedBeforeAttack=combatConfig.unitsWoundedByDamage(damageResults)
    -- Self-wounding Attack 6 happens only if the Unit survived damage and
    -- still has an enemy to attack. It does not cancel its own Attack 6.
    local selfWounds={}
    for guid in pairs(selfWoundsEarly) do selfWounds[guid]=true end
    for guid in pairs(selfWoundsLate) do
        if woundedBeforeAttack[guid]~=true then selfWounds[guid]=true end
    end
    damageProfile=trackerPrivate.traceEnabled and (trackerPrivate.profileStart() or true) or nil
    attackAssignmentsUnitPreviewSync(damageSeat,damageResults,selfWounds)
    if damageProfile~=nil then trackerPrivate.profileFinish("damage.unitPreviewSync",damageProfile) end
    local defeatFame,defeatRep=trackerPrivate.lateCombatPhase.resolve(
        entries,groups,rowBlock,woundedBeforeAttack,paralysisAttackCards,
        gStates~=nil and gStates.forkedLightningPhase or nil)
    if stageProfile~=nil then stageProfile=trackerPrivate.profileCheckpoint("rows.lateAttack",stageProfile) end
    -- Scenario modules still own Shields, physical level markers, and
    -- reward finalisation; the calculator only publishes calculated amounts.
    local dragonOwners={}
    local leaderChanged=false
    for _,member in ipairs(entries) do
        if member.bossLevel~=nil and not member.preview and not member.attackOnly then
            local value=math.min(member.bossLevel,
                (member.bossRangeLevels or 0)+(member.bossAttackLevels or 0))
            if member.bossType=="leader" then
                if gStates.leaderOverkill~=value then
                    gStates.leaderOverkill=value
                    leaderChanged=true
                    local token=getObjectFromGUID(member.guid)
                    if token~=nil then
                        token.UI.setAttribute(member.guid.."Overkill","Text",tostring(value))
                    end
                end
            elseif member.bossType=="dragon" then
                local combat=gStates.apocalypseDragonGroundCombat
                if combat~=nil and combat.reductions~=nil
                    and (combat.processedTokens==nil
                        or combat.processedTokens[member.guid]~=true)
                    and combat.reductions[member.bossHead]~=value then
                    combat.reductions[member.bossHead]=value
                    local token=getObjectFromGUID(member.guid)
                    if token~=nil then
                        token.UI.setAttribute(member.guid.."GroundOverkill","text",tostring(value))
                    end
                    local owner=apocalypseDragonGroundHeadOwner(member.bossHead)
                    if owner~=nil then dragonOwners[owner]=true end
                end
            end
        end
    end
    for owner in pairs(dragonOwners) do apocalypseDragonRefreshGroundFameGain(owner) end
    if leaderChanged then mainUIUpdate("Combat leader levels") end

    if stageProfile~=nil then stageProfile=trackerPrivate.profileCheckpoint("rows.bossUpdates",stageProfile) end
    -- Knockout was resolved before Attack, so a staged card cannot
    -- incorrectly defeat an enemy once the Hero has lost their hand.
    -- An active Sword gives +1 Fame for EACH real enemy defeated, even when
    -- no cards were discarded for its basic Attack. Bow's basic side gives
    -- +1 for each enemy defeated in the Ranged/Siege phase. This is not tied
    -- to the artifact itself being allocated as an Attack source.
    if combatConfig.artifactCombat.swordFame or combatConfig.artifactCombat.bowFame then
        for _,group in ipairs(groups) do
            local count=defeatedCount(group,false)
            local rangedCount=defeatedCount(group,true)
            if combatConfig.artifactCombat.swordFame then
                defeatFame=defeatFame+count
            end
            if combatConfig.artifactCombat.bowFame then
                defeatFame=defeatFame+rangedCount
            end
        end
    end

    -- Banner of Glory awards Fame for participating Unit combat abilities, not
    -- merely for sitting in a play area. The attached banner counts each
    -- activation; a broken banner counts each Unit only once this turn.
    local gloryFameSeen={}
    for _,group in ipairs(groups) do
        if not group.destroyed then
            for _,source in ipairs(group.sources or {}) do
                if source.gloryFame~=nil and source.kind=="unit" then
                    local key=source.gloryFame=="global" and source.guid or source.key
                    local usedRange=source.ranged+source.siege>0
                    local usedBlock=not group.rangeDefeated and source.block>0
                    local usedAttack=not group.rangeDefeated and source.attack>0
                        and woundedBeforeAttack[source.guid]~=true
                    if (usedRange or usedBlock or usedAttack) and not gloryFameSeen[key] then
                        gloryFameSeen[key]=true
                        defeatFame=defeatFame+1
                    end
                end
            end
        end
    end

    -- Sources that reward every defeated enemy, whichever attack defeated it.
    local seenScope={}
    for _,source in ipairs(combatAssignmentSources(damageSeat)) do
        local spec=source.defeatFameRep
        if spec~=nil and spec.scope~=nil and not seenScope[source.guid] then
            seenScope[source.guid]=true
            for _,group in ipairs(groups) do
                local count=defeatedCount(group,spec.scope~="all")
                if count>0 then
                    defeatFame=defeatFame+(spec.fame or 0)*count
                    defeatRep=defeatRep+(spec.rep or 0)*count
                end
            end
        end
    end
    -- Dueling Fame requires a legal Block-phase enemy that was subsequently
    -- defeated, no Unit ability used against it, and NO damage assigned to any Unit
    -- (even if its Resistance prevented the Wound).
    local duelingUnitDamaged=false
    for _,result in pairs(damageResults) do
        if #(result.units or {})>0 then duelingUnitDamaged=true break end
    end
    if not duelingUnitDamaged then
        for _,group in ipairs(groups) do
            if (group.defeated or (group.bossSpecial
                and defeatedCount(group,false)>defeatedCount(group,true)))
                and not group.rangeDefeated and not group.destroyed then
                local targetGUID=nil
                for _,source in ipairs(group.sources) do
                    if source.dueling and source.duelingEligible==true then
                        targetGUID=combatAssignmentState.targets[source.key]
                        break
                    end
                end
                if targetGUID~=nil then
                    local targetInGroup=false
                    local usedUnit=false
                    for _,index in ipairs(group.members) do
                        if entries[index].guid==targetGUID
                            and (not group.bossSpecial or entries[index].attackDead==true) then
                            targetInGroup=true
                        end
                    end
                    for _,source in ipairs(group.sources) do
                        if source.kind=="unit" then usedUnit=true break end
                    end
                    if not usedUnit then
                        for _,record in pairs(seatScan~=nil and seatScan.cards or {}) do
                            if record.kind=="unit" then
                                for _,enemyGUID in pairs(record.enemyEffectTargetGUIDs or {}) do
                                    if enemyGUID==targetGUID then usedUnit=true break end
                                end
                            end
                            if usedUnit then break end
                        end
                    end
                    if targetInGroup and not usedUnit then defeatFame=defeatFame+1 end
                end
            end
        end
    end
    combatDefeatFameRep.fame,combatDefeatFameRep.rep=defeatFame,defeatRep
    resourceCardsApplyFameRep(damageSeat)
    if stageProfile~=nil then stageProfile=trackerPrivate.profileCheckpoint("rows.rewards",stageProfile) end
    local trackedGuids,defeatedGuids,partialGuids={},{},{}
    for _,group in ipairs(groups) do
        for _,index in ipairs(group.members) do
            local entry=entries[index]
            local guid=entry.guid
            if not entry.attackOnly and not entry.preview then
                trackedGuids[guid]=true
                if trackerPrivate.lateCombatPhase.enemyDefeated(entry,group,false) then
                    defeatedGuids[guid]=true
                elseif entry.bossLevel~=nil
                    and (entry.bossRangeLevels or 0)+(entry.bossAttackLevels or 0)>0 then
                    partialGuids[guid]=true
                end
                for summonedGUID in pairs(entry.summonedDestroyed or {}) do
                    trackedGuids[summonedGUID]=true
                    defeatedGuids[summonedGUID]=true
                end
            end
        end
    end
    combatSetDefeatMarks(trackedGuids,defeatedGuids,partialGuids)
    if stageProfile~=nil then stageProfile=trackerPrivate.profileCheckpoint("rows.defeatMarks",stageProfile) end
    local displayByIndex,overflow=trackerPrivate.combatResourceDisplay(
        entries,groups,allocated,emptyTarget,rowBlock,seatScan,woundedBeforeAttack,
        paralysisAttackCards,damageResults,mitigation,elementMitigation)
    if stageProfile~=nil then stageProfile=trackerPrivate.profileCheckpoint("rows.resourceDisplay",stageProfile) end
    totalRowHeight=trackerPrivate.combatRowRenderer(entries,groupOf,rowBlock,displayByIndex,
        seatScan,damageResults,knockout,pageOffset,visibleRows,shownTraits,shownOffence,shownAttacks,
        colUsed,maxResourceCounts,combatAssignmentSlotSources,combatAssignmentState,
        combatReductionAttackChoice,combatExpandedResults,combatAttackChoiceByRow,
        gStates.combatBossManual,totalRowHeight)

    if stageProfile~=nil then stageProfile=trackerPrivate.profileCheckpoint("rows.resultRenderer",stageProfile) end
    local columnWidths,baseWidth=trackerPrivate.combatPanelRenderer.columns(
        shownTraits,shownOffence,shownAttacks,colUsed,maxResourceCounts,enemyNameWidth)

    if stageProfile~=nil then stageProfile=trackerPrivate.profileCheckpoint("rows.columnLayout",stageProfile) end
    if earlyLock==nil and combatConfig.phasePreview~=nil then
        combatConfig.phasePreview.attackDiscards=combatFrozenCopy(stagedAttackCards)
    end
    combatConfig.woundRecordPreview(damageSeat,damageItems,damageResults,
        knockout,otherCombatWounds,stagedAttackCards)
    local ledger=combatConfig.woundLedger(damageSeat)
    local _,pendingHand,pendingDiscard,changed,effects=combatConfig.woundPending(ledger)
    totalRowHeight=totalRowHeight+trackerPrivate.combatPanelRenderer.woundSummary(
        totalHeroWounds,totalDiscardWounds,knockout,pendingHand,pendingDiscard,changed,effects)

    if stageProfile~=nil then stageProfile=trackerPrivate.profileCheckpoint("rows.woundSummary",stageProfile) end
    trackerPrivate.combatPanelRenderer.finish(overflow,baseWidth,columnWidths,enemyNameWidth,combatExpandedResults,pages)
    if stageProfile~=nil then trackerPrivate.profileFinish("rows.finalLayout",stageProfile) end
    return totalRowHeight+(pages>1 and 22 or 0)+(overflow>0 and 18 or 0)
end

local function combatCalcShutdown()
    combatConfig.scanAwaitingRescan=false
    combatConfig.shutdownClean=true
    combatConfig.resultRowCache={}
    combatConfig.slotSelection={}
    combatConfig.effectSources={}
    combatConfig.blockedEnemyCounts={}
        combatConfig.panelHeight=0
    if gStates~=nil then gStates.combatBossManual={} end
    combatTrackedSeat=nil
    combatTrackedEnemies={}
    combatCalcOn=false
    combatEnemyInPlay=false
    combatCumbersomeActive=false
    combatSyncDefenderMark(nil)
    combatClearDefeatMarks()
    combatPanelSetAttribute("CombatEnemyPanel","active","false")
    local seat=combatAssignmentState.seat
    combatDefeatFameRep.fame,combatDefeatFameRep.rep=0,0
    if seat~=nil then resourceCardsApplyFameRep(seat) end
    combatAssignmentState={seat=nil,selected=nil,targets={},explicit={}}
    combatAssignmentJoined={}
    combatEnemyPage=1
    combatAssignmentRowIndices={}
    combatExpandedResults={}
    trackerPrivate.combatBlockResultCache={}
    combatReductionAttackChoice={}
    combatReductionActiveSource={}
    combatAttackChoiceByRow={}
    -- Includes pending target buttons, previews, damage allocations and arrows.
    attackAssignmentsClearAll()
end

local function refreshCombatEnemyPanel(monsters,calculated)
    if combatConfig.scanAwaitingRescan then return end
    local profile=trackerPrivate.traceEnabled and (trackerPrivate.profileStart() or true) or nil
    local active
    if calculated==true then active=combatCalcOn
    else active=combatCalcUpdate(monsters) end
    if not active then
        -- A closed calculator is already clean; don't repeatedly delete/rebuild overlays.
        if not combatConfig.shutdownClean then combatCalcShutdown() end
        if trackerPrivate.traceEnabled then trackerPrivate.profileCount("combat.inactive") end
        return
    end
    combatConfig.shutdownClean=false
    combatPanelSetAttribute("CombatEnemyPanel","active","true")
    local entries={}
    for guid in pairs(monsters or {}) do
        local data,mode=combatEnemyData(guid,monsters[guid])
        if data~=nil and monsters[guid]~=nil and monsters[guid].is_face_down~=true
            and not combatIsSummonedToken(guid) then
            local perks=gStates~=nil and gStates.monsterPerks~=nil and gStates.monsterPerks[guid] or nil
            local baseArmour=tonumber(data.armour) or 0
            local armourBonus=perks~=nil and (tonumber(perks.armour) or 0) or 0
            local armour=baseArmour+armourBonus
            local bossType,bossLevel,bossHead=combatBossIdentity(guid,data,perks,mode)
            entries[#entries+1]={guid=guid,name=tostring(data.name or "Enemy"),
                attackOnly=mode=="attackOnly" or bossType=="control",preview=mode=="preview",
                bossType=bossType,bossLevel=bossLevel,bossHead=bossHead,
                armour=tostring(armour),unmodifiedArmour=armour,baseArmour=baseArmour+armourBonus,
                elusiveArmour=baseArmour*2+armourBonus,data=data,perks=perks,
                summoned=data.monsters~=nil and combatSummonedFor(guid) or nil}
        end
    end
    local currentSeat=combatAssignmentActiveSeat()
    -- Establish the pre-combat Wound baseline as soon as enemies appear.
    -- Doing this before resources resolve prevents an old Wound moved into
    -- the play area from being mistaken for a newly taken card-cost Wound.
    if #entries>0 and currentSeat~=nil then
        combatConfig.combatOtherWounds(currentSeat)
    end
    local seatScan=currentSeat~=nil and resourceCardScanBySeat[currentSeat] or nil
    local enemyEffects=seatScan~=nil and seatScan.enemyEffects or nil
    trackerPrivate.enemyDefences.prepareFortifications(entries,
        seatScan~=nil and seatScan.ignoreSiteFortifications==true)
    for _,entry in ipairs(entries) do
        local obj=monsters[entry.guid]
        entry.x=obj~=nil and obj.getPosition()[1] or 0
        -- Card effects on one enemy (Armour reduction never goes below 1).
        local effect=enemyEffects~=nil and enemyEffects[entry.guid] or nil
        entry.effect=effect
        entry.attackReductions=combatOrderedReductions(effect)
        trackerPrivate.enemyDefences.applyEffects(entry,effect,combatEnemyAttacks)
        entry.noAttack=not entry.attackOnly and effect~=nil and (effect.noAttack==true or (effect.noAttackUnfortified==true
            and (combatEnemyFortificationCount(entry.data,entry.perks)==0
                or effect.removeFortify==true)))
        entry.destroyed=not entry.attackOnly and effect~=nil and effect.destroy==true
        entry.attackPhaseDestroyed=not entry.attackOnly and effect~=nil
            and effect.destroyDuringAttack==true
        entry.destroyIfBlocked=not entry.attackOnly and effect~=nil and effect.destroyIfBlocked==true
        entry.destroyIfFullyBlocked=not entry.attackOnly and effect~=nil and effect.destroyIfFullyBlocked==true
        entry.removeAbilities=effect~=nil and effect.removeAbilities==true
    end
    -- Board order, left to right, so enemies placed side by side group the way the player laid them out.
    table.sort(entries,function(a,b)
        if a.x~=b.x then return a.x<b.x end
        return a.guid<b.guid
    end)
    if currentSeat~=combatAssignmentState.seat then
        combatAssignmentState={seat=currentSeat,selected=nil,targets={},explicit={}}
        combatExpandedResults={}
    end
    local lock=combatPhaseLock(currentSeat)
    local sources=combatAssignmentSources(currentSeat)
    if lock~=nil then
        -- Use the exact enemy state and grouping that existed when Damage
        -- was confirmed, rather than newly changed earlier-phase effects.
        entries=combatFrozenCopy(lock.entries) or entries
        combatAssignmentJoined=combatFrozenCopy(lock.joined or {}) or {}
        for key,target in pairs(lock.targets or {}) do
            if (lock.sourceKeys or {})[key] then
                combatAssignmentState.targets[key]=target
                combatAssignmentState.explicit[key]=(lock.explicit or {})[key]==true
            end
        end
        sources=combatPhaseLockSources(lock,sources)
    else
        local keys,objects,positions={}, {}, {}
        for _,source in ipairs(sources) do
            if (source.ranged or 0)+(source.siege or 0)+(source.block or 0)
                +(source.move or 0)+(source.psychicInfluence or 0)>0 then
                keys[source.key]=true
                objects[source.guid]=true
                local obj=getObjectFromGUID(source.guid)
                if obj~=nil then
                    local pos=obj.getPosition()
                    positions[source.key]={pos.x or pos[1],pos.y or pos[2],pos.z or pos[3]}
                end
            end
        end
        combatConfig.phasePreview={
            seat=currentSeat,turn=gStates.turnNumber,
            entries=combatFrozenCopy(entries),
            sources=combatFrozenCopy(sources),
            enemyEffects=combatFrozenCopy(enemyEffects or {}),
            sourceKeys=keys,objectKeys=objects,positions=positions,
            joined=combatFrozenCopy(combatAssignmentJoined),
            targets=combatFrozenCopy(combatAssignmentState.targets),
            explicit=combatFrozenCopy(combatAssignmentState.explicit)
        }
    end
    local activeSources,activeObjects={},{}
    -- Unit effects such as Illusionists and Delphana Masters can target an enemy
    -- without creating Attack/Block points. Keep their arrows while that ability is active.
    for guid,record in pairs(seatScan~=nil and seatScan.cards or {}) do
        for _,key in ipairs(record.enemyEffectTargetKeys or {}) do
            activeSources[key]=true
            activeObjects[guid]=true
        end
    end
    for _,source in ipairs(sources) do
        activeSources[source.key]=true
        activeObjects[source.guid]=true
        -- Move only has a target while a Cumbersome attacker is in play.
        if not combatCumbersomeActive and source.move>0 then
            combatAssignmentState.explicit[source.key]=nil
            if source.ranged+source.siege+source.block+source.attack==0 then
                combatAssignmentState.targets[source.key]=nil
                attackAssignmentsClearForObject(source.key)
            end
        end
    end
    local arrowProfile=trackerPrivate.traceEnabled and (trackerPrivate.profileStart() or true) or nil
    attackAssignmentsPruneInactive(activeSources,activeObjects,combatSourceKeepsLock)
    local validTargets={}
    for guid,obj in pairs(monsters or {}) do
        if obj.is_face_down~=true then validTargets[guid]=true end
    end
    attackAssignmentsPruneTargets(validTargets)
    -- Reconcile effect colours even when a saved/manual arrow already exists.
    -- Recolour all of a source's arrows in place; never replace extra targets.
    local effectKinds=seatScan~=nil and seatScan.enemyEffectArrowKinds or {}
    for _,record in pairs(seatScan~=nil and seatScan.cards or {}) do
        for sourceKey,targetGUID in pairs(record.enemyEffectTargetGUIDs or {}) do
            if activeSources[sourceKey]==true and validTargets[targetGUID]==true then
                attackAssignmentsReconcileEffectTarget(sourceKey,targetGUID,
                    effectKinds[sourceKey] or "other")
            end
        end
    end
    for guid in pairs(combatAssignmentState.targets) do
        if activeSources[guid]~=true and not combatSourceKeepsLock(guid)
            and not (lock~=nil and (lock.sourceKeys or {})[guid]) then
            combatAssignmentState.targets[guid]=nil
        end
    end
    if combatAssignmentState.selected~=nil and activeSources[combatAssignmentState.selected]~=true then
        combatAssignmentState.selected=nil
    end
    if arrowProfile~=nil then trackerPrivate.profileFinish("combat.arrows",arrowProfile) end
    local rowProfile=trackerPrivate.traceEnabled and (trackerPrivate.profileStart() or true) or nil
    local rowHeight=combatAssignmentRefreshRows(entries,sources)
    if rowProfile~=nil then trackerPrivate.profileFinish("combat.rows",rowProfile) end
    if lock==nil and combatConfig.phasePreview~=nil then
        -- Automatic nearest-enemy targeting is resolved inside the calculator,
        -- so capture it AFTER that pass rather than before the first render.
        combatConfig.phasePreview.targets=combatFrozenCopy(combatAssignmentState.targets)
        combatConfig.phasePreview.explicit=combatFrozenCopy(combatAssignmentState.explicit)
    end
    if attackAssignmentsRefreshTargetButtons~=nil then
        local buttonProfile=trackerPrivate.traceEnabled and (trackerPrivate.profileStart() or true) or nil
        attackAssignmentsRefreshTargetButtons(monsters)
        if buttonProfile~=nil then trackerPrivate.profileFinish("combat.targetButtons",buttonProfile) end
    end
    combatConfig.panelHeight=combatConfig.panelBaseHeight+rowHeight
    combatPanelSetAttribute("CombatEnemyPanel","height",tostring(combatConfig.panelHeight))
    if profile~=nil then trackerPrivate.profileFinish("combat.refresh",profile) end
end

-- Result expansion is presentation only. Reuse the existing combat solution,
-- retaining all targeting, Defender, Damage and Wound preview state.
combatConfig.refreshResultRowOnly=function(row)
    local cache=combatConfig.resultRowCache[row]
    if cache==nil or not cache.hasDetails then return false end
    local expanded=combatExpandedResults[cache.guid]==true
    local display=expanded and cache.detailText or cache.compactText
    local rows=expanded and cache.detailLines or cache.compactLines
    local height=math.max(cache.minHeight,math.max(rows,cache.attackCount)*15+4)
    combatConfig.panelHeight=combatConfig.panelHeight+height-cache.rowHeight
    cache.rowHeight=height
    combatPanelSetAttribute("CombatEnemyRow"..row.."Result","text",
        display..(expanded and " [-]" or " [+]"))
    combatPanelSetAttribute("CombatEnemyResultToggle"..row,"tooltip","")
    combatPanelSetAttribute("CombatEnemyRow"..row,"preferredHeight",tostring(height))
    trackerPrivate.combatPanelRenderer.refreshResultWidth(combatExpandedResults)
    combatPanelSetAttribute("CombatEnemyPanel","height",tostring(combatConfig.panelHeight))
    return true
end

function resourceCardsRefreshCombatEnemies()
    if not resourceCardsPanelOpen() then return end
    refreshCombatEnemyPanel(combatPlayMonsters())
end

function resourceCardsCombatAssignSource(sourceGUID,enemyGUID)
    return trackerPrivate.combatInteraction.assignSource(sourceGUID,enemyGUID,combatConfig,combatAssignmentState)
end


-- A remote Spirit Guides link can target any active, Block-producing card,
-- Skill or Unit in this player's areas; it is not an enemy assignment.
-- This is also the candidate set for temporary clickable target buttons.
combatConfig.spiritGuideBlockFields={"block","blockFire","blockIce","blockColdFire","blockPsychic"}
function resourceCardsBlockLinkSkillActive(guid)
    return trackerPrivate.combatTargetPolicy.blockLinkSkillActive(guid)
end

function resourceCardsBlockLinkTargets()
    return trackerPrivate.combatTargetPolicy.blockLinkTargets(combatConfig)
end

local cardPosture=require("PlayingGame.PlayerBoard.ResourceTracker.Scanning.PhysicalObjects").cardPosture

-- Site-fortification bypass is a combat rule, not an enemy debuff; even
-- Arcane Immunity / Fire Resistance cannot prevent it. Demolish uses its
-- basic side, while Underground Attack uses its stronger side.
local function resourceCardsIgnoreSiteFortification(rule,result,card)
    if rule==nil or rule.ignoreSiteFortification~=true
        or result==nil or result.complete~=true or result.resources==nil
        or card==nil or (card.is_face_down==true and result.repeatLink==nil)
        or cardPosture(card)~="upright" then return false end
    return (result.powered==true)==(rule.ignoreSiteFortificationPowered==true)
end

-- Ambush can augment exactly one played card's first Attack or Block. This
-- pool is shared by the target buttons and the calculation, rather than
-- requiring the cards to physically touch.
combatConfig.ambushCombatCategories={"attack","attackFire","attackIce","attackColdFire","attackPsychic",
    "ranged","rangedFire","rangedIce","rangedColdFire","rangedPsychic",
    "siege","siegeFire","siegeIce","siegeColdFire","siegePsychic",
    "block","blockFire","blockIce","blockColdFire","blockPsychic"}
combatConfig.ambushEligibleTarget=function(guid,record,sourceGUID)
    return trackerPrivate.combatTargetPolicy.ambushEligibleTarget(guid,record,sourceGUID,combatConfig,cardPosture)
end

function resourceCardsAmbushSourceActive(guid)
    return trackerPrivate.combatTargetPolicy.ambushSourceActive(guid,resourceCardsDetailsOpen,cardPosture)
end

function resourceCardsAmbushLinkTargets(sourceGUID)
    return trackerPrivate.combatTargetPolicy.ambushLinkTargets(sourceGUID,combatConfig)
end

-- Paging changes visible rows, not the underlying combat calculations.
function resourceCardsCombatPage(delta)
    combatEnemyPage=math.max(1,combatEnemyPage+delta)
    resourceCardsRefreshCombatEnemies()
end

function resourceCardsCombatCycleAttack(row,nextSource)
    return trackerPrivate.combatInteraction.cycleAttack(row,nextSource,combatPhaseLock,combatAssignmentActiveSeat,combatAssignmentRowTargets,combatAttackChoiceByRow,combatReductionActiveSource,combatReductionAttackChoice)
end

-- The first visible row can still join the preceding enemy on another page.
function resourceCardsCombatToggleGroup(row)
    return trackerPrivate.combatInteraction.toggleGroup(row,combatPhaseLock,combatAssignmentActiveSeat,combatAssignmentRowTargets,combatAssignmentRowIndices,combatEnemyData,combatAssignmentJoined)
end

function resourceCardsCombatToggleResult(row)
    return trackerPrivate.combatInteraction.toggleResult(row,combatAssignmentRowTargets,combatConfig,combatExpandedResults)
end

-- Called when a targeting arrow is removed; the source re-locks to the nearest enemy on refresh.
function resourceCardsCombatForgetSource(sourceGUID,replacementTargetGUID)
    return trackerPrivate.combatInteraction.forgetSource(sourceGUID,replacementTargetGUID,combatConfig,combatAssignmentState)
end

-- Clear every target key owned by a physical card or Unit (including split
-- keys). Choice changes and borrowed Unit cleanup must not leave hidden locks
-- that regenerate arrows during the next Combat Calculator scan.
local function combatForgetPhysicalSourceTargets(unitGUID)
    return trackerPrivate.combatInteraction.forgetPhysicalSourceTargets(unitGUID,combatAssignmentState)
end

function resourceCardsCombatAssignmentClick(id,mouseButton)
    return trackerPrivate.combatInteraction.assignmentClick(id,mouseButton,combatAssignmentSlotSources,combatConfig,combatAssignmentRowTargets,combatAssignmentState,combatAssignmentSources,combatGUIDHasCumbersome,combatSourceArrowKind)
end

-- The tracker belongs to the active Mage Knight, not everyone whose cards are on the table.
function resourceCardsCurrentTotals()
    if not resourceCardsPanelOpen() or turnOrder==nil or gStates.turnNumber==nil then return nil end
    local player=turnOrder[gStates.turnNumber]
    local scan=player~=nil and resourceCardScanBySeat[player.seatPos] or nil
    return scan~=nil and scan.totals or nil
end

trackerPrivate.resourceTotalsKeyByField={
    move={move="move"},
    ranged={physical="ranged",fire="rangedFire",ice="rangedIce",iceFire="rangedColdFire",psychic="rangedPsychic"},
    siege={physical="siege",fire="siegeFire",ice="siegeIce",iceFire="siegeColdFire",psychic="siegePsychic"},
    attack={physical="attack",fire="attackFire",ice="attackIce",iceFire="attackColdFire",psychic="attackPsychic"},
    block={physical="block",fire="blockFire",ice="blockIce",iceFire="blockColdFire",psychic="blockPsychic"},
    influence={generated="influence"},
    healing={healing="healing"}
}

trackerPrivate.attackTransformFamilies={"attack","ranged","siege"}
trackerPrivate.attackTransformFields={"physical","fire","ice","iceFire","psychic"}

-- Manual adjustments only remain for Move, Influence and Healing; combat resources come from the scan.
local function resourceCardsRawValue(tracker,totals,category,field)
    local manual=0
    if category~="attack" and category~="ranged" and category~="siege" and category~="block" then
        manual=tracker~=nil and tracker[category]~=nil and tracker[category][field] or 0
    end
    local fields=trackerPrivate.resourceTotalsKeyByField[category]
    local totalKey=fields~=nil and fields[field] or nil
    local estimated=totals~=nil and totalKey~=nil and (totals[totalKey] or 0) or 0
    return manual+estimated
end

function resourceCardsEffectiveValue(category,field)
    if not resourceCardsPanelOpen() then return 0 end
    local tracker=gStates~=nil and gStates.resourceTracker or nil
    local totals=resourceCardsCurrentTotals()
    local current=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    local scan=current~=nil and resourceCardScanBySeat[current.seatPos] or nil
    local transform=totals~=nil and scan~=nil and scan.attackTransforms or nil
    if transform==nil or (not transform.coldFire and not transform.siege)
        or (category~="attack" and category~="ranged" and category~="siege") then
        return resourceCardsRawValue(tracker,totals,category,field)
    end

    -- Same key mapping as the Combat Calculator's per-source resources.
    local wanted=trackerPrivate.resourceTotalsKeyByField[category][field]
    local amount=0
    for _,sourceFamily in ipairs(trackerPrivate.attackTransformFamilies) do
        for _,sourceField in ipairs(trackerPrivate.attackTransformFields) do
            local sourceKey=trackerPrivate.resourceTotalsKeyByField[sourceFamily][sourceField]
            if resourceCardsTransformedKey(sourceKey,transform)==wanted then
                amount=amount+resourceCardsRawValue(tracker,totals,sourceFamily,sourceField)
            end
        end
    end
    return amount
end

local function resourceCardsMoveByRole(role,includeManual)
    if not resourceCardsPanelOpen() then return 0 end
    local active=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    local scan=active~=nil and resourceCardScanBySeat[active.seatPos] or nil
    local amount=0
    for guid,record in pairs(scan~=nil and scan.cards or {}) do
        local generated=math.max(0,tonumber(record.resources~=nil and record.resources.move) or 0)
        if generated>0 and resourceCardsMoveRole(guid,true)==role then
            amount=amount+generated
        end
    end
    if role=="movement" and includeManual~=false then
        amount=amount+(gStates~=nil and gStates.resourceTracker~=nil
            and gStates.resourceTracker.move~=nil
            and (tonumber(gStates.resourceTracker.move.move) or 0) or 0)
    end
    return math.max(0,amount)
end
function resourceCardsEffectiveMove()
    return resourceCardsMoveByRole("movement")
end
-- Printed Move from played movement-role sources, without tracker adjustments.
-- Combat Move is intentionally excluded from this Generated breakdown.
function resourceCardsGeneratedMove()
    return resourceCardsMoveByRole("movement",false)
end
function resourceCardsEffectiveCombatMove()
    return resourceCardsMoveByRole("combat")
end

-- Active, reconstructable play-area effects, shared with the movement calculator.
function resourceCardsCurrentMovementEffects()
    if not resourceCardsPanelOpen() or turnOrder==nil then return nil end
    local player=turnOrder[gStates.turnNumber]
    local scan=player~=nil and resourceCardScanBySeat[player.seatPos] or nil
    return scan~=nil and scan.movementEffects or nil
end

-- Terrain abilities are an overlay, not changes to gStates.moveCost. This
-- preserves day/night terrain settings, manual adjustments and other cards.
-- Explore is not terrain; Weather also changes the special movement cost of Cities.
-- Claimed Skills keep their passive effects while their token remains at home.
trackerPrivate.movementEffects=require("PlayingGame.PlayerBoard.ResourceTracker.Cards.MovementEffects")
local ownedSkillAtSeat=trackerPrivate.movementEffects.ownedSkillAtSeat
local resourceCardsWeatherTerrainEffects=trackerPrivate.movementEffects.resourceCardsWeatherTerrainEffects
local cardTerrainEffects=trackerPrivate.movementEffects.cardTerrainEffects
local terrainEffectActive=trackerPrivate.movementEffects.terrainEffectActive

function resourceCardsEffectiveTerrainCost(terrain)
    return trackerPrivate.movementEffects.resourceCardsEffectiveTerrainCost(terrain)
end

function resourceCardsEffectiveExploreCost()
    return trackerPrivate.movementEffects.resourceCardsEffectiveExploreCost()
end

local function clearHighlight(guid)
    if shown[guid]==nil then return end
    local obj=getObjectFromGUID(guid)
    if obj~=nil then obj.highlightOff() end
    shown[guid]=nil
end

local function setHighlight(obj,kind,powered)
    if trackerPrivate.unitHighlightBlocked[obj.guid]==true then
        clearHighlight(obj.guid)
        return
    end
    -- Crystal figurines represent mana but are visually distinctive already.
    -- Keep their power detection/contribution records, without outlining the
    -- figurine. Remove any highlight left from the previous tracker version.
    if isManaTokenFigurine(obj) then
        if shown[obj.guid]~=nil then
            clearHighlight(obj.guid)
        elseif trackerPrivate.crystalHighlightCleared[obj.guid]~=true then
            obj.highlightOff()
        end
        trackerPrivate.crystalHighlightCleared[obj.guid]=true
        return
    end
    local choice=kind..(powered and "Bright" or "Normal")
    if shown[obj.guid]==choice then return end
    -- Omit duration: TTS keeps this highlight until highlightOff() is called.
    obj.highlightOn(trackerPrivate.palette[kind][powered and 2 or 1])
    shown[obj.guid]=choice
end


-- Only a deliberately tilted card can pay a discard cost, not an upright
-- action or a fully sideways +1 play (notably Improvisation).
local function canPayDiscard(card)
    return card.is_face_down~=true and cardPosture(card)=="discard"
end

-- Only cards that may be played from hand can generate a sideways +1.
-- In particular, recruited Units and unidentified cards are not candidates.
local function cardCanPlaySideways(card)
    local data=gameCards[card.guid]
    return card.type=="Card" and card.is_face_down~=true and data~=nil
        and (data.cardType=="Starting" or data.cardType=="Advanced Action"
            or data.cardType=="Spell" or data.cardType=="Artifact")
end

trackerPrivate.sidewaysChoices={{move=1},{block=1},{attack=1},{influence=1}}

local choiceLetters={attackP1="A",attackP2="A2",attackP3="A3",
    attackF1="AF",attackF2="AF2",attackI1="AI",attackI2="AI2",
    attackIF1="AC",attackIF2="AC2",
    block2Attack1="B2/A1",block1Attack2="B1/A2",
    tauntReduce="-1",tauntProvoke="+2",preyNone="?",duel="D",
    blockP1="B",blockF1="BF",blockI1="BI",blockIF1="BC",
    twiceAttack="A2",twiceBlock="B2",move="M",influence="I",attack="A",block="B",
    ranged="R",siege="S",healing="H",draw="D",other="O",armour="Arm",
    guide="M",hardened="H",
    siegeFire="SF",siegeIce="SI",rangedFire="RF",rangedIce="RI",blockIce="BI",
    fire="F",ice="I",coldFire="C",boost="H+",reduce="AR",split="I/F",negative="N",
    single="1",all="All",singleBefore="1st",allBefore="All 1st",
    heal="H",combat="C",wound="W",fame="F",reputation="R",gain="G",ready="R",
    base="2",sourceUnused="3",red="R",blue="B",white="W",green="G",
    fireAttack="F",fireBlock="F",fireSiege="F",iceSiege="I",fireBlockOnly="B",fireBlockCounter="B+",
    woundPending="W?",woundTaken="W✓",
    splitBlock="B2",zero="0",one="1",two="2",three="3",four="4",five="5"}
-- The choice UI and initial-guess tie-breaks follow the Resource Tracker order.
trackerPrivate.choicePolicy=require("PlayingGame.PlayerBoard.ResourceTracker.Cards.ResourceChoices")(
    trackerPrivate,function() return selectedResourceByGUID end,choiceLetters,cardPosture)
local resourceChoiceFamilies=trackerPrivate.choicePolicy.resourceChoiceFamilies
local resourceChoiceRank=trackerPrivate.choicePolicy.resourceChoiceRank
local resourceChoiceColumn=trackerPrivate.choicePolicy.resourceChoiceColumn
local sideChoices=trackerPrivate.choicePolicy.sideChoices
local choiceCategory=trackerPrivate.choicePolicy.choiceCategory

local function choiceHasTargetableCombatResource(category)
	if not combatCalcOn or type(category)~="string" then return false end
	if category=="move" then return combatCumbersomeActive end
    if category=="influence" then return combatPsychicActive end
	return (category:find("attack",1,true)~=nil or category:find("Attack",1,true)~=nil
			or category:find("block",1,true)~=nil or category:find("Block",1,true)~=nil
			or category:find("siege",1,true)~=nil or category:find("Siege",1,true)~=nil
			or category:find("ranged",1,true)~=nil or category:find("Range",1,true)~=nil
			or category=="twiceAttack" or category=="twiceBlock")
end

-- Units have a separate ability UI from cards, but share the same combat target-arrow handler.
local function unitAbilityTargetCategory(ability)
    if not combatCalcOn or ability==nil then return nil end
    for _,field in ipairs(combatConfig.sourceFields) do
        if (tonumber(ability[field.key]) or 0)>0 then return field.key end
    end
    if combatPsychicActive and (tonumber(ability.influence) or 0)>0 then return "influence" end
    if combatCumbersomeActive and (tonumber(ability.move) or 0)>0 then return "move" end
    return nil
end

-- Target buttons select an enemy, not whether to play the source. Only hide
-- a redundant selection for a single normal enemy; keep manual allocations,
-- friendly links, special effect-only buttons, and any pending retargeting.
-- This is presentation only: the Combat Calculator still owns assignments.
local function resourceCardsHideAutomaticEnemyTarget(sourceKey,resource,automaticEffect)
    local sole=trackerPrivate~=nil and trackerPrivate.singleAutoEnemyGUID or nil
    if not combatCalcOn or sole==nil or type(sourceKey)~="string"
        or type(resource)~="string" then return false end
    -- Spirit Guides' blockSource is a friendly link, not Block points.
    if resource=="blockSource" or resource=="unitReady"
        or resource=="move" or resource=="influence" then return false end
    local numeric=resource:match("^attack")~=nil
        or resource:match("^ranged")~=nil or resource:match("^siege")~=nil
        or resource:match("^block")~=nil
        or resource=="twiceAttack" or resource=="twiceBlock"
    if not numeric and not (resource=="effect" and automaticEffect==true) then
        return false
    end
    if attackAssignmentsIsTargeting~=nil
        and attackAssignmentsIsTargeting(sourceKey) then return false end
    if resourceCardsCombatTargetAcceptsSource~=nil
        and not resourceCardsCombatTargetAcceptsSource(sourceKey,sole) then return false end
    -- Preserve arrows that might already point elsewhere (e.g. an unusual
    -- physical/explicit assignment), rather than concealing the retarget.
    if combatAssignmentState~=nil and combatAssignmentState.targets~=nil then
        local selected=combatAssignmentState.targets[sourceKey]
        if selected~=nil and selected~=sole then return false end
    end
    if attackAssignmentsTargetGUIDs~=nil then
        for guid in pairs(attackAssignmentsTargetGUIDs(sourceKey)) do
            if guid~=sole then return false end
        end
    end
    return true
end

-- Numeric resources keep their own target; accompanying non-Attack enemy
-- effects use a separate key, so Sorcerers may affect a different enemy.
local function unitAbilityTargetKey(unitGUID,index,ability,useIndex)
    local key=unitHistoryKey(unitGUID,useIndex or 1)
    if ability~=nil and ability.enemyEffect~=nil then return key.."#effect"..index end
    return unitAbilityTargetCategory(ability)~=nil and key
        or (key.."#effect"..index)
end

-- The printed normal and powered effects share one choice for each physical
-- card. The sideways +1 action also shares it when the resource type matches,
-- but retains a separate choice when the printed effect is incompatible
-- (e.g. Tranquility's Heal/Draw versus a sideways Move/Attack).
local choiceAvailable=trackerPrivate.choicePolicy.choiceAvailable
local currentChoice=trackerPrivate.choicePolicy.currentChoice
local chosenEffect=trackerPrivate.choicePolicy.chosenEffect

-- Only resources that explicitly split a pool or apply a multi-enemy effect
-- may keep additional right-click arrows. Independent printed effects already
-- have their own source keys and do not need a second arrow on one source.
function resourceCardsCombatAdditionalTargetLimit(sourceKey)
    return trackerPrivate.combatTargetPolicy.additionalTargetLimit(sourceKey,combatAssignmentActiveSeat,combatAssignmentSources,combatConfig,currentChoice,sideChoices)
end

-- The primary allocation already receives the source's remaining points.
-- An extra Influence arrow to that same enemy would be purely decorative.
function resourceCardsCombatPrimaryTarget(sourceKey)
    return combatAssignmentState.targets[sourceKey]
end

-- Every Maximal Effect application may choose independently. The stored choice
-- is per *use*, not per linked card, and never invents an optional Wound payment.
combatConfig.repeatChoiceFor=function(guid,powered,choices,index)
    if choices==nil or #choices==0 then return nil,nil end
    local stored=selectedResourceByGUID[guid]
    local key=stored~=nil and stored.repeatChoices~=nil
        and stored.repeatChoices[index] or nil
    if choiceAvailable(choices,key) then
        for _,choice in ipairs(choices) do
            if choiceCategory(choice)==key then return choice,key end
        end
    end
    -- A single Wound confirmation on the original Action must not silently
    -- confirm TWO/THREE new Wounds when that Action is repeated.
    local data=gameCards[guid]
    local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
    if rule~=nil and rule.woundConfirmation==true then
        return choices[1],choiceCategory(choices[1])
    end
    return currentChoice(guid,powered,choices)
end

-- A Maximal Effect copy is one composite effect: repeated options cannot
-- straddle separate combat phases. Move may join Block only when explicitly
-- allocated against Cumbersome. Draw/Heal and other instantaneous options
-- do not independently define a combat phase.
combatConfig.compositeChoicePhase=function(guid,choice)
    if type(choice)~="table" then return nil end
    local found={}
    for key,value in pairs(choice) do
        if type(value)=="number" and value>0 then
            if key:sub(1,6)=="ranged" or key:sub(1,5)=="siege" then
                found.range=true
            elseif key:sub(1,6)=="attack" then
                found.attack=true
            elseif key:sub(1,5)=="block" then
                found.block=true
            elseif key=="move" then
                found.move=true
            elseif key=="influence" then
                found.influence=true
            end
        end
    end
    if found.range then return "range" end
    if found.attack and not found.block then return "attack" end
    if found.block then return "block" end
    if found.move then
        if resourceCardsMoveRole(guid,false)=="combat" then
            -- Combat Move without Cumbersome can still pay for conversions
            -- or Spell costs, but is not ordinary map movement or Block.
            return combatCumbersomeActive and "block" or "combatMove"
        end
        return "move"
    end
    local data=gameCards[guid]
    local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
    if found.influence then
        if combatCalcOn and (combatPsychicActive
            or (rule~=nil and rule.combatConversion=="diplomacy")) then
            return "block"
        end
        return "influence"
    end
    if rule~=nil and rule.enemyEffect~=nil then
        local category=choiceCategory(choice)
        local spec=combatEffectSpec(rule,false,category)
            or combatEffectSpec(rule,true,category)
        if spec~=nil and (spec.attackReduce~=nil or spec.noAttack==true
            or spec.cancelOneAttack==true) then return "block" end
    end
    return nil
end

combatConfig.compositePhasesMatch=function(guid,powered,choices,repeatLink)
    if repeatLink==nil or (repeatLink.count or 1)<2 then return true end
    local phase=nil
    for index=1,repeatLink.count do
        local options=repeatLink.options~=nil
            and repeatLink.options[index] or choices
        local selected=combatConfig.repeatChoiceFor(guid,powered,options,index)
        local current=combatConfig.compositeChoicePhase(guid,selected)
        if current~=nil then
            if phase~=nil and current~=phase then return false end
            phase=current
        end
    end
    return true
end

-- Bonus choices are independent of the card's primary selection. Until the
-- player chooses a bonus explicitly, it follows the main choice (or the
-- printed first alternative if the main category is unavailable).
local function inventorySetChoice(guid,index,choices,mainChoices)
    if type(choices)~="table" or #choices==0 then return nil,nil end
    local stored=selectedResourceByGUID[guid]
    local selected=stored~=nil and stored.inventorySets~=nil and stored.inventorySets[index] or nil
    if not choiceAvailable(choices,selected) then
        local _,primary=currentChoice(guid,true,mainChoices)
        selected=choiceAvailable(choices,primary) and primary or nil
    end
    if not choiceAvailable(choices,selected) then selected=choiceCategory(choices[1]) end
    for _,choice in ipairs(choices) do
        if choiceCategory(choice)==selected then return choice,selected end
    end
    return nil,nil
end

local trackerChoiceScores=trackerPrivate.choicePolicy.trackerChoiceScores
local guessInitialCardChoice=trackerPrivate.choicePolicy.guessInitialCardChoice

local function effectHasTrackedResource(effects)
    if effects==nil then return false end
    for category,value in pairs(effects) do
        if trackerPrivate.totalsKeys[category] and type(value)=="number" and value~=0 then
            return true
        end
    end
    return false
end

-- These are tiny object XML buttons over the artwork, not the much larger
-- Meditation buttons beside the card. Preserve other object UI elements.
local function removeChoiceButtons(card)
    if card==nil or card.UI==nil then return end
    local xml=resourceObjectUiXmlTable(card.UI)
    local changed=false
    for i=#xml,1,-1 do
        local attr=xml[i].attributes
        if attr~=nil and type(attr.id)=="string"
            and (attr.id:sub(1,19)=="ResourceCardChoice_"
                or attr.id:find("^AttackAssignmentSource_")~=nil) then
            table.remove(xml,i)
            changed=true
        end
    end
    if changed then resourceObjectUiSetTable(card.UI,xml) end
    choiceButtonShown[card.guid]=nil
    if combatConfig.cardButtonIds~=nil then combatConfig.cardButtonIds[card.guid]=nil end
end

-- Cure is simultaneous: Heal 2 remains in the totals while a separate
-- Draw 1 button lets the player confirm each actually healed hand Wound.
-- The button is removed with other tracker choices on minimisation.
combatConfig.refreshCureDrawButton=function(card,allowed)
    if card==nil or card.UI==nil then return end
    local id="ResourceCardChoice_CureDraw"
    local xml=resourceObjectUiXmlTable(card.UI)
    local index=nil
    for i,node in ipairs(xml) do
        if node.attributes~=nil and node.attributes.id==id then index=i break end
    end
    if allowed and index==nil then
        local button=createClaimButton(card.guid,"cureDraw")
        button.attributes.id=id
        xml[#xml+1]=button
        resourceObjectUiSetTable(card.UI,xml)
        safeBroadcastToColor("Cure: use Draw 1 for each Wound healed from your hand this turn, even before casting Cure. Ready every Unit healed this turn by returning its Command token to the ready slot.",
            positionToColor(gStates.turnNumber),{0.7,1,0.7})
    elseif not allowed and index~=nil then
        table.remove(xml,index)
        resourceObjectUiSetTable(card.UI,xml)
    end
end

-- Skills use their own centred layout; Action/Spell/Artifact buttons keep their
-- existing horizontal layout. Elemental options for the same resource family
-- share a column, centred vertically around the Skill's midpoint.
local function skillChoiceFamily(category,choice)
    for _,family in ipairs(resourceChoiceFamilies) do
        for resource,value in pairs(choice) do
            if type(value)=="number"
                and (resource==family or resource:sub(1,#family)==family) then
                return family
            end
        end
    end
    return resourceChoiceColumn(category)
end

local function skillChoicePositions(entries)
    local families,familyOrder={},{}
    for _,entry in ipairs(entries) do
        local family=entry.skillFamily
        if families[family]==nil then
            families[family]={}
            familyOrder[#familyOrder+1]=family
        end
        families[family][#families[family]+1]=entry
    end

    local columns={}
    local grouped=#familyOrder<=3
    for _,family in ipairs(familyOrder) do
        if #families[family]>2
            and not (#familyOrder==1 and #families[family]==3) then
            grouped=false break
        end
    end
    if grouped then
        for _,family in ipairs(familyOrder) do
            columns[#columns+1]=families[family]
        end
    else
        -- Four alternatives of one element family or four unrelated resource
        -- families fit in a centred 2x2 grid, rather than a wide four-button row.
        local ordered={}
        for _,family in ipairs(familyOrder) do
            for _,entry in ipairs(families[family]) do ordered[#ordered+1]=entry end
        end
        local rowCount=math.max(2,math.ceil(#ordered/3))
        for i,entry in ipairs(ordered) do
            local columnIndex=math.ceil(i/rowCount)
            columns[columnIndex]=columns[columnIndex] or {}
            columns[columnIndex][#columns[columnIndex]+1]=entry
        end
    end

    local positions={}
    for columnIndex,column in ipairs(columns) do
        local x=((#columns+1)/2-columnIndex)*104
        local verticalSpacing=#column==3 and 58 or 70
        for rowIndex,entry in ipairs(column) do
            positions[entry.category]={x=x,
                y=((#column+1)/2-rowIndex)*verticalSpacing}
        end
    end
    return positions
end

-- Replace the generic "other" artwork only when that option specifically
-- reduces an enemy stat. Explicit resource icons still take priority.
local function combatReductionChoiceIcon(rule,powered,choice,category)
    local icon=choice.icon or category
    if icon~="other" then return icon end
    local spec=combatEffectSpec(rule,powered,category)
    if spec==nil then return icon end
    if (tonumber(spec.armourReduce) or 0)>0
        or (tonumber(spec.armourReduceFortified) or 0)>0
        or (tonumber(spec.armourReduceByResist) or 0)>0 then
        return "armourReduction"
    end
    if (tonumber(spec.attackReduce) or 0)>0 then return "attackReduction" end
    return icon
end

-- Keep card-attached controls intact while a card is being rearranged.
-- During a pickup TTS can momentarily report the card as tilted/discarded
-- or outside the thin play scripting zone; only the settled scan may remove
-- its controls for a genuinely changed posture or area.
combatConfig.cardInTransit=function(card)
    return card~=nil and ((card.held_by_color~=nil and card.held_by_color~="")
        or card.isSmoothMoving() or (trackerPrivate.playCardMovements~=nil
            and trackerPrivate.playCardMovements[card.guid]~=nil))
end

-- TTS and other object-UI owners can replace the XML while a card is lifted.
-- A cached resource signature does not prove its choice/target buttons survived.
-- Store only this card's own button IDs so an unchanged settled scan can repair
-- missing controls without resetting the player's selections or links.
combatConfig.cardButtonIds=combatConfig.cardButtonIds or {}
combatConfig.cardChoiceIds=function(guid,xml)
    local choices="ResourceCardChoice_"..guid.."_"
    local targets="AttackAssignmentSource_"..guid.."_"
    local ids={}
    for _,node in ipairs(xml or {}) do
        local id=node.attributes~=nil and node.attributes.id or nil
        if node.tag=="Button" and type(id)=="string"
            and (id:sub(1,#choices)==choices or id:sub(1,#targets)==targets) then
            ids[#ids+1]=id
        end
    end
    return ids
end
combatConfig.cardChoicesPresent=function(card)
    local expected=combatConfig.cardButtonIds[card.guid]
    if expected==nil then return false end
    if #expected==0 then return true end
    local missing={}
    for _,id in ipairs(expected) do missing[id]=true end
    for _,node in ipairs(resourceObjectUiXmlTable(card.UI)) do
        local id=node.attributes~=nil and node.attributes.id or nil
        if id~=nil then missing[id]=nil end
    end
    return next(missing)==nil
end

-- The Throw/Recover control selects the printed throw-away (strong) effect.
-- This is independent of resource choices, including Artifacts without numeric choices.
trackerPrivate.artifactBreakButton=function(card,uiRotation,buttonDepth)
    local broken=resourceCardsArtifactBroken(card.guid,card)
    local data=gameCards~=nil and gameCards[card.guid] or nil
    local key=data~=nil and data.resourceKey or nil
    local waitForCombat=not broken and combatEnemyInPlay
        and (key=="artifactDruidicStaff" or key=="artifactBannerCourage"
            or key=="artifactBannerFortitude")
    local label=broken and "RECOVER" or (waitForCombat and "WAIT" or "THROW")
    return {tag="Button",attributes={
        id="ResourceCardChoice_"..card.guid.."_artifactBreak",
        onClick="global/resourceCardsArtifactBreakClicked",
        -- Card UI rotates 180 degrees: negative Y is toward the top artwork.
        -- Keep THROW below the printed text and RECOVER above the artwork.
        position="0 "..tostring(broken and -140 or 140).." "..buttonDepth,
        rotation=uiRotation,width=220,height=74,scale="0.25 0.25",
        font="Fonts/MKCardText",fontSize=58,
        resizeTextForBestFit="true",resizeTextMinSize=26,
        resizeTextMaxSize=58,padding="18 18 9 9",
        colors=broken and "#81372F|#AD5045|#81372F|#81372F"
            or (waitForCombat and "#383838|#505050|#383838|#383838"
                or "#454D5D|#69798E|#444C63|#454D5D"),
        textColor="#FFFFFF",textAlignment="MiddleCenter"},
        value=label}
end

-- Shift only the Artifact's newly generated option/target controls toward the
-- artwork by half their actual rendered height (UI height times Y scale).
-- Move multi-choice row labels with their buttons; leave unrelated object UI
-- and the independent THROW/RECOVER control exactly where they are.
trackerPrivate.raiseArtifactChoiceControls=function(xml,startIndex,guid)
    local choicePrefix="ResourceCardChoice_"..guid.."_"
    local targetPrefix="AttackAssignmentSource_"..guid.."_"
    for i=startIndex,#xml do
        local node=xml[i]
        local attrs=type(node)=="table" and node.attributes or nil
        local id=type(attrs)=="table" and attrs.id or nil
        if type(attrs)=="table" and type(id)=="string" and attrs.position~=nil
            and id~=choicePrefix.."artifactBreak"
            and (id:sub(1,#choicePrefix)==choicePrefix
                or id:sub(1,#targetPrefix)==targetPrefix)
            and (node.tag=="Button" or
                (node.tag=="Text" and id:find("_label",1,true)~=nil)) then
            local x,y,z=tostring(attrs.position):match("^(%S+)%s+(%S+)%s+(%S+)$")
            local height=tonumber(attrs.height) or 0
            -- Special edge controls (e.g. Banner HEAL and Staff RDY)
            -- are already clear of the card title and must not be pushed off-card.
            if x~=nil and tonumber(y)~=nil and math.abs(tonumber(y))<=110
                and height>0 then
                local sx,sy
                if type(attrs.scale)=="string" then
                    sx,sy=attrs.scale:match("^(%S+)%s+(%S+)")
                end
                local shift=height*(tonumber(sy) or tonumber(sx) or 1)/2
                attrs.position=x.." "..tostring(tonumber(y)-shift).." "..z
            end
        end
    end
end

-- A manual counter: only spent Heal points from the Grail's basic effect
-- generate Fame. The user can left-click to add and right-click to subtract.
trackerPrivate.grailFameButton=function(card,uiRotation,buttonDepth)
    local used=gStates~=nil and gStates.artifactGrailHealingUsed~=nil
        and gStates.artifactGrailHealingUsed[card.guid] or 0
    used=math.max(0,math.min(2,tonumber(used) or 0))
    return {tag="Button",attributes={
        id="ResourceCardChoice_"..card.guid.."_grailFame",
        onClick="global/resourceCardsArtifactGrailFameClicked",
        position="145 -145 "..buttonDepth,rotation=uiRotation,
        width=185,height=90,scale="0.28 0.28",fontSize=42,
        colors="#454D5D|#69798E|#454D5D|#454D5D",
        textColor="#FFFFFF",textAlignment="MiddleCenter"},
        value="F "..tostring(used).."/2"}
end

trackerPrivate.cardControlOptions=require("PlayingGame.PlayerBoard.ResourceTracker.Interface.CardControlOptions")({
    choiceLetters=choiceLetters,
    combatConfig=combatConfig,
    combatContext=function() return combatCalcOn,combatPsychicActive,combatCumbersomeActive end,
    cardPosture=function(...) return cardPosture(...) end,
    choiceHasTargetableCombatResource=function(...) return choiceHasTargetableCombatResource(...) end,
    combatEffectSpec=function(...) return combatEffectSpec(...) end,
    resourceChoiceRank=function(...) return resourceChoiceRank(...) end,
    currentChoice=function(...) return currentChoice(...) end,
    inventorySetChoice=function(...) return inventorySetChoice(...) end,
    choiceCategory=function(...) return choiceCategory(...) end,
    skillChoiceFamily=function(...) return skillChoiceFamily(...) end,
    combatReductionChoiceIcon=function(...) return combatReductionChoiceIcon(...) end,
    resourceCardsMoveRole=function(...) return resourceCardsMoveRole(...) end,
    resourceCardsHideAutomaticEnemyTarget=function(...) return resourceCardsHideAutomaticEnemyTarget(...) end
})

-- A single selected icon is centred on the object. Click to expand all
-- choices; selecting one immediately collapses back to its icon.
local showChoiceButtons=require("PlayingGame.PlayerBoard.ResourceTracker.Interface.CardControls")({
    trackerPrivate=trackerPrivate,
    combatConfig=combatConfig,
    choiceLetters=choiceLetters,
    getContext=function()
        return choiceButtonShown,choiceExpandedByGUID,combatAssignmentState,
            combatCalcOn,combatCumbersomeActive,combatPsychicActive,combatEnemyInPlay,
            gameCards,cardResourceDefinitions,skillResourceDefinitions,skillTokens,
            gStates,turnOrder,factionRewardForObject,attackAssignmentsHasReadyTarget
    end,
    removeChoiceButtons=function(...) return removeChoiceButtons(...) end,
    cardPosture=function(...) return cardPosture(...) end,
    resourceCardsDetailsOpen=resourceCardsDetailsOpen,
    resourceObjectUiXmlTable=function(...) return resourceObjectUiXmlTable(...) end,
    resourceObjectUiSameXML=function(...) return resourceObjectUiSameXML(...) end,
    resourceObjectUiSetTable=function(...) return resourceObjectUiSetTable(...) end,
    resourceCardsArtifactBroken=function(...) return resourceCardsArtifactBroken(...) end,
    cardCanPlaySideways=function(...) return cardCanPlaySideways(...) end,
    combatHardenedAttackOptions=function(...) return combatHardenedAttackOptions(...) end,
    combatAssignmentActiveSeat=combatAssignmentActiveSeat,
    resourceCardsChoiceAssetsFor=function(...) return resourceCardsChoiceAssetsFor(...) end,
    resourceChoiceColumn=function(...) return resourceChoiceColumn(...) end,
    skillChoicePositions=function(...) return skillChoicePositions(...) end,
    resourceCardsChoiceIcon=function(...) return resourceCardsChoiceIcon(...) end,
    combatEffectSpec=function(...) return combatEffectSpec(...) end,
    currentChoice=function(...) return currentChoice(...) end,
    choiceCategory=function(...) return choiceCategory(...) end,
    inventorySetChoice=function(...) return inventorySetChoice(...) end
})

-- One selected icon in the Unit's lower-left artwork margin, away from
-- its Command token. Expand vertically in printed ability order.
-- Alternatives sharing a printed row occupy adjacent columns to the right.
-- This is intentionally independent of translated text position.
local showUnitAbilityButtons=require("PlayingGame.PlayerBoard.ResourceTracker.Interface.UnitControls")({
    combatConfig=combatConfig,
    choiceLetters=choiceLetters,
    getContext=function()
        return choiceButtonShown,choiceExpandedByGUID,combatCalcOn,combatPsychicActive,combatCumbersomeActive
    end,
    removeChoiceButtons=function(...) return removeChoiceButtons(...) end,
    unitHistorySelectedNumber=function(...) return unitHistorySelectedNumber(...) end,
    unitManaDecision=function(...) return unitManaDecision(...) end,
    unitHistoryIsCombatAbility=function(...) return unitHistoryIsCombatAbility(...) end,
    unitHistoryDecisionHasCombat=function(...) return unitHistoryDecisionHasCombat(...) end,
    unitAbilityTargetCategory=function(...) return unitAbilityTargetCategory(...) end,
    unitHistoryKey=function(...) return unitHistoryKey(...) end,
    resourceCardsMoveRole=function(...) return resourceCardsMoveRole(...) end,
    resourceCardsHideAutomaticEnemyTarget=function(...) return resourceCardsHideAutomaticEnemyTarget(...) end,
    unitAbilityTargetKey=function(...) return unitAbilityTargetKey(...) end,
    resourceObjectUiXmlTable=function(...) return resourceObjectUiXmlTable(...) end,
    resourceCardsChoiceAssetsFor=function(...) return resourceCardsChoiceAssetsFor(...) end,
    resourceCardsChoiceIcon=function(...) return resourceCardsChoiceIcon(...) end,
    resourceObjectUiSetTable=function(...) return resourceObjectUiSetTable(...) end
})

local function clearChoiceButtons()
    for guid,signature in pairs(choiceButtonShown) do
        if signature~="hidden" then removeChoiceButtons(getObjectFromGUID(guid)) end
    end
    choiceButtonShown={}
    combatConfig.cardButtonIds={}
end

trackerPrivate.zoneFootprintContainsXZ=require("PlayingGame.PlayerBoard.ResourceTracker.Scanning.PhysicalObjects").zoneFootprintContainsXZ

-- A dropped play source can be above the shallow zone while still in play.
-- Held/smooth sources are not counted until released.
trackerPrivate.cardOverPlayMat=function(obj,seatPos)
    if obj==nil or seatPos==nil
        or (obj.isDestroyed~=nil and obj.isDestroyed())
        or (obj.held_by_color~=nil and obj.held_by_color~="")
        or obj.isSmoothMoving() then return false end
    local zoneGUID=playerPlayAreas~=nil and playerPlayAreas[seatPos] or nil
    local zone=zoneGUID~=nil and getObjectFromGUID(zoneGUID) or nil
    return trackerPrivate.zoneFootprintContainsXZ(obj,zone)
end

-- Reset a player's explicit choice only after the card has actually left
-- the play mat in X/Z. A temporary zone exit while lifted is not a new play.
local function cardInSeatPlayArea(guid,seatPos)
    local zoneGUID=playerPlayAreas~=nil and playerPlayAreas[seatPos] or nil
    local zone=zoneGUID~=nil and getObjectFromGUID(zoneGUID) or nil
    if zone==nil then return false end
    -- Actual zone membership is affirmative evidence: it must not be
    -- overruled by an X/Z bounds approximation as the card drops into the
    -- shallow trigger. The previous check returned the X/Z result first,
    -- allowing a delayed exit callback to erase the chosen effect even
    -- when zone.getObjects() already contained the card.
    for _,candidate in ipairs(zone.getObjects()) do
        if candidate.guid==guid then return true end
    end
    -- Above a shallow zone, keep the X/Z fallback for released cards that
    -- have not yet entered the zone's Y range.
    local obj=getObjectFromGUID(guid)
    return obj~=nil and trackerPrivate.cardOverPlayMat(obj,seatPos) or false
end

local function scheduleChoiceResetAfterPlay(guid,seatPos)
    return trackerPrivate.objectEvents.scheduleChoiceReset(guid,seatPos,function() return selectedResourceByGUID end,function() return choiceExpandedByGUID end,trackerPrivate,cardInSeatPlayArea)
end

local footprint=require("PlayingGame.PlayerBoard.ResourceTracker.Scanning.PhysicalObjects").footprint
local overlapArea=require("PlayingGame.PlayerBoard.ResourceTracker.Scanning.PhysicalObjects").overlapArea
local overlaps=require("PlayingGame.PlayerBoard.ResourceTracker.Scanning.PhysicalObjects").overlaps

local manaColor=require("PlayingGame.PlayerBoard.ResourceTracker.Scanning.PhysicalObjects").manaColor
trackerPrivate.readyForXZ=require("PlayingGame.PlayerBoard.ResourceTracker.Scanning.PhysicalObjects").readyForXZ

-- Magic Talent's strong side consumes TWO distinct mana objects, not the
-- single mana that normally powers an Advanced Action. Read the same released
-- die faces/crystals as the ordinary tracker, even when its panel is minimized.
trackerPrivate.manaPayments=require("PlayingGame.PlayerBoard.ResourceTracker.Scanning.ManaPayments")
function magicTalentManaPayments(seatPos)
    return trackerPrivate.manaPayments.magicTalentManaPayments(seatPos,
        footprint,manaColor,trackerPrivate.readyForXZ)
end

factionRewardForObject=require("PlayingGame.PlayerBoard.ResourceTracker.Scanning.PhysicalObjects").factionRewardForObject
local resourceObjectKind=require("PlayingGame.PlayerBoard.ResourceTracker.Scanning.PhysicalObjects").resourceObjectKind

-- A NightRules token represents a combat fought under Night rules, even
-- during a Day round or when the Mage Knight is standing outside the site.
-- The saved perk is authoritative; the physical decal also supports older
-- saves/manual tokens that have the marker but no matching perk entry.
local function resourceCardsCombatNightFromEnemies(enemies)
    for guid,enemy in pairs(enemies or {}) do
        if enemy~=nil and enemy.is_face_down~=true
            and (enemy.isDestroyed==nil or enemy.isDestroyed()~=true) then
            local perks=gStates~=nil and gStates.monsterPerks~=nil
                and gStates.monsterPerks[guid] or nil
            -- Earlier saves could have nightRules mistakenly stamped on every
            -- summoned monster. For a summon, require the actual Night decal.
            local summoned=gStates~=nil and gStates.summonStates~=nil
                and gStates.summonStates[guid]=="summoned"
            if not summoned and perks~=nil and perks.nightRules==true then return true end
            if enemy.getDecals~=nil then
                local ok,decals=pcall(enemy.getDecals)
                if ok and type(decals)=="table" then
                    for _,decal in ipairs(decals) do
                        if decal.name=="NightRules" then return true end
                    end
                end
            end
        end
    end
    return false
end

-- This is the effective Day/Night setting for combat Skills and mana, not the
-- world's round setting. Terrain movement and other non-combat Day effects
-- still use gStates.dayRound. One visible NightRules enemy makes the active
-- combat Night, including for a hero fighting from an adjacent hex.
local function resourceCardsUsesDayMana()
    if gStates==nil or gStates.dayRound~=true then return false end
    local player=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    local site=player~=nil and player.avatarLocation or nil
    if site=="dungeon" or site=="tomb" then return false end
    -- The render already collected the active combat tokens once. Avoid
    -- rescanning scripting zones for every mana/Skill lookup in that pass.
    if trackerPrivate.renderCombatNight~=nil then
        return not trackerPrivate.renderCombatNight
    end
    if player~=nil and player.seatPos~=nil
        and type(playerPlayAreas)=="table" and type(playerUnitAreas)=="table"
        and getObjectFromGUID~=nil then
        return not resourceCardsCombatNightFromEnemies(combatPlayMonsters())
    end
    return true
end

-- These are separate permissions. Amulet of the Sun permits Gold at Night
-- without disabling Black; Amulet of Darkness permits Black during Day
-- without making the rest of the game's Day/Night rules change.
-- Map auto-reveal may execute with the tracker minimized; inspect the real
-- current play area rather than relying on a stale tracker snapshot.
function resourceCardsAmuletSunRevealActive()
    if gStates==nil or gStates.dayRound==true then return false end
    local player=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    if player==nil or player.seatPos==nil then return false end
    local zone=getObjectFromGUID(playerPlayAreas[player.seatPos])
    if zone==nil then return false end
    for _,obj in ipairs(zone.getObjects()) do
        if obj.guid=="085e61" and cardPosture(obj)=="upright" then return true end
    end
    return false
end

function resourceCardsGoldAllowed()
    return resourceCardsUsesDayMana() or (combatConfig~=nil
        and combatConfig.amuletMana~=nil and combatConfig.amuletMana.gold==true)
end
function resourceCardsBlackAllowed()
    return not resourceCardsUsesDayMana() or (combatConfig~=nil
        and combatConfig.amuletMana~=nil and combatConfig.amuletMana.black==true)
end

local function matchesCardMana(card,color)
    if color==nil then return false end
    local data=gameCards[card.guid]
    if data==nil then return color=="Red" or color=="Blue" or color=="Green" or color=="White" end
    if data.cardType=="Artifact" then return false end
    if color=="Gold" then return resourceCardsGoldAllowed() end
    if color=="Black" then return resourceCardsBlackAllowed() and data.cardType=="Spell" end
    local colors=data.color
    if type(colors)=="string" then return colors==color end
    if type(colors)=="table" then
        for _,cardColor in ipairs(colors) do if cardColor==color then return true end end
    end
    return false
end

-- A borrowed Spell's casting payment must remain on its physical card.
-- This check also works with the Resource Tracker minimized, when its cached
-- records are deliberately cleared. A lone Black die never casts a Spell.
function magicTalentSpellCastingPaid(seatPos,guid)
    return trackerPrivate.manaPayments.magicTalentSpellCastingPaid(seatPos,guid,
        footprint,cardPosture,manaColor,trackerPrivate.readyForXZ,matchesCardMana)
end

-- Count distinct physical casting payments for repeated uses of the same
-- Spell through Maximal Effect + Magic Talent. Only play-zone mana qualifies;
-- duplicates are counted only once.
function magicTalentSpellCastingPaymentCount(seatPos,guid)
    return trackerPrivate.manaPayments.magicTalentSpellCastingPaymentCount(seatPos,guid,
        footprint,cardPosture,manaColor,trackerPrivate.readyForXZ,matchesCardMana)
end

-- A powered link grants a target Action card its strong side for free and can
-- amend only the resource types specified in that link's data definition.
local function applyLinkedResourceBonus(effects,link)
    if effects==nil or link==nil then return effects end
    local values={}
    for category,value in pairs(effects) do
        if type(value)=="number" then
            -- A stronger Action bonus also applies to elemental attacks/blocks
            -- (e.g. Concentration + Ice Bolt = Ranged Ice Attack 5).
            local bonusCategory=category
            for _,prefix in ipairs({"ranged","siege","attack","block"}) do
                if category:sub(1,#prefix)==prefix then
                    bonusCategory=prefix
                    break
                end
            end
            local bonus=link.bonusFor~=nil and link.bonusFor[bonusCategory]
                and (link.bonus or 0) or 0
            values[category]=value+bonus
        end
    end
    return values
end

local effectManaPossibilities=require("PlayingGame.PlayerBoard.ResourceTracker.Scanning.ManaPayments").effectManaPossibilities
local effectManaPowerColors=require("PlayingGame.PlayerBoard.ResourceTracker.Scanning.ManaPayments").effectManaPowerColors

-- Colour-triggered Actions use stable target-card data, not translated text.
-- Dual-colour Actions offer an explicit choice, using the existing card buttons.
trackerPrivate.basicActionColors={"Red","Blue","White","Green"}
local function linkedColorChoices(rule,targetGUID,powered)
    if rule==nil or rule.linkedColorEffects==nil or targetGUID==nil then return nil end
    local data=gameCards[targetGUID]
    local colors=data~=nil and data.color or nil
    if colors==nil then return nil end
    if type(colors)=="string" then colors={colors} end
    local definitions=powered and rule.linkedColorEffects.powered
        or rule.linkedColorEffects.normal
    local choices={}
    for _,color in ipairs(trackerPrivate.basicActionColors) do
        if definitions[color]~=nil then
            for _,cardColor in ipairs(colors) do
                if cardColor==color then
                    local effect={key=string.lower(color)}
                    for resource,value in pairs(definitions[color]) do effect[resource]=value end
                    choices[#choices+1]=effect
                    break
                end
            end
        end
    end
    return #choices>0 and choices or nil
end

-- Powered One with the Land references the *printed*, unmodified Move
-- cost of the Mage Knight's actual hex, not player-adjusted gStates.moveCost.
-- Lakes and Mountains explicitly have special printed values on the card.
trackerPrivate.landPrintedMoveDay={
    plains=2,hills=3,forest=3,wasteland=4,desert=5,swamp=5,
    lake=2,mountain=5,city=2
}
trackerPrivate.landPrintedMoveNight={
    plains=2,hills=3,forest=5,wasteland=4,desert=3,swamp=5,
    lake=2,mountain=5,city=2
}

local function currentLandBlockValue()
    if gStates==nil or gStates.turnNumber==nil
        or fracturedLandsTeleportSourcePosition==nil then return nil end
    -- Reuse the existing avatar-origin helper: it handles avatars moved
    -- onto City boards as well as ordinary map-space positions.
    local position=fracturedLandsTeleportSourcePosition(gStates.turnNumber)
    if position==nil then return nil end
    local hex,_,_,_,_,_,terrain=runtimeMapHexAtPosition(position)
    terrain=terrain or (hex~=nil and hex.hexType or nil)
    local costs=gStates.dayRound==true and trackerPrivate.landPrintedMoveDay or trackerPrivate.landPrintedMoveNight
    return costs[terrain]
end


-- Used only for effects that vary with the Mage Knight's current terrain.
local function currentSpellTerrain()
    if gStates==nil or gStates.turnNumber==nil
        or fracturedLandsTeleportSourcePosition==nil then return nil end
    local position=fracturedLandsTeleportSourcePosition(gStates.turnNumber)
    if position==nil then return nil end
    local hex,_,_,_,_,_,terrain=runtimeMapHexAtPosition(position)
    return terrain or (hex~=nil and hex.hexType or nil)
end

-- Mountain Lore changes the *next* hand draw, not current Move resources.
-- Read the live play area before end-of-turn cleanup; keep the resulting
-- one-shot bonus in Turn/CardFlow so it survives a round boundary.
function resourceCardsMountainLoreEndTurnBonus(seatPos)
    local terrain=currentSpellTerrain()
    if terrain~="hills" and terrain~="mountain" then return 0 end
    local zone=seatPos~=nil and getObjectFromGUID(playerPlayAreas[seatPos]) or nil
    if zone==nil then return 0 end
    local objects=zone.getObjects()
    local card=nil
    for _,obj in ipairs(objects) do
        if obj.guid=="d3995b" then card=obj break end
    end
    if card==nil or cardPosture(card)~="upright" then return 0 end

    local function drawBonus(powered,copies)
        copies=copies or 1
        if terrain=="hills" then return copies end
        return powered and 2*copies or 0
    end
    -- A copied Action can already be face down (thrown away). The live scan
    -- has the authoritative number of Maximal Effect uses and strong-side
    -- status, including Concentration/Will Focus.
    if resourceCardsPanelOpen() then
        local scan=resourceCardScanBySeat[seatPos]
        local record=scan~=nil and scan.cards[card.guid] or nil
        if record==nil or record.complete~=true or record.resources==nil then return 0 end
        return drawBonus(record.powered==true,record.repeatCount)
    end

    -- When tracking is closed, recover unambiguous physical payments and
    -- links rather than assuming the card was not played on its strong side.
    local function paidManaOn(target)
        local area=footprint(target)
        for _,obj in ipairs(objects) do
            local color=manaColor(obj)
            if color~=nil and matchesCardMana(target,color) then
                local pos=obj.getPosition()
                if math.abs(pos[1]-area.x)<area.halfX
                    and math.abs(pos[3]-area.z)<area.halfZ then return true end
            end
        end
        return false
    end
    local function strongEffect(target)
        if paidManaOn(target) then return true end
        for _,source in ipairs(objects) do
            local data=gameCards[source.guid]
            local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
            if source.guid~=target.guid and rule~=nil and rule.poweredLink~=nil
                and rule.poweredLink.mode=="stronger"
                and source.is_face_down~=true and cardPosture(source)=="upright"
                and overlapArea(footprint(source),footprint(target))>0
                and paidManaOn(source) then return true end
        end
        return false
    end
    -- Maximal Effect throws Lore away, but its delayed effect survives.
    -- A card directly paid with its own mana cannot be the repeated target.
    if not paidManaOn(card) then
        for _,source in ipairs(objects) do
            local data=gameCards[source.guid]
            local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
            if rule~=nil and rule.requiredLink~=nil
                and rule.requiredLink.mode=="repeat"
                and source.is_face_down~=true and cardPosture(source)=="upright"
                and overlapArea(footprint(source),footprint(card))>0 then
                local powered=strongEffect(source)
                return drawBonus(powered,powered and rule.requiredLink.poweredCount
                    or rule.requiredLink.normalCount)
            end
        end
    end
    if card.is_face_down==true then return 0 end
    return drawBonus(strongEffect(card),1)
end

-- Training is resource-neutral, but its mode and Maximal Effect repetition
-- still come from the same physical mana/Action-link resolver as other cards.
function resourceCardsTrainingMode(seatPos)
    local scan=seatPos~=nil and resourceCardScanBySeat[seatPos] or nil
    local record=scan~=nil and scan.cards["6fdeb0"] or nil
    if record~=nil and resourceCardsPanelOpen() then
        return record.powered==true,record.repeatCount or 1
    end
    local copied=resourceCardsMaximalEffectLink(seatPos,"6fdeb0")
    if copied~=nil then return copied.powered==true,copied.count end
    local card=getObjectFromGUID("6fdeb0")
    local zone=seatPos~=nil and getObjectFromGUID(playerPlayAreas[seatPos]) or nil
    if card==nil or zone==nil or card.is_face_down==true then return false,1 end
    local area=footprint(card)
    for _,obj in ipairs(zone.getObjects()) do
        local color=manaColor(obj)
        if color~=nil and matchesCardMana(card,color) then
            local pos=obj.getPosition()
            if math.abs(pos[1]-area.x)<area.halfX
                and math.abs(pos[3]-area.z)<area.halfZ then return true,1 end
        end
    end
    return false,1
end

-- Used by Steady Tempo's end-turn placement controls, even when the tracker is
-- closed. The live scan also recognises Concentration/Will Focus/Maximal Effect
-- payment links that do not leave mana physically on Steady Tempo.
function resourceCardsSteadyTempoPowered(seatPos,cardGUID)
    local card=cardGUID~=nil and getObjectFromGUID(cardGUID) or nil
    if card==nil or card.is_face_down==true or cardPosture(card)~="upright" then return false end
    local scan=seatPos~=nil and resourceCardScanBySeat[seatPos] or nil
    local record=scan~=nil and scan.cards[cardGUID] or nil
    if record~=nil and resourceCardsPanelOpen() then return record.powered==true end
    local zone=seatPos~=nil and getObjectFromGUID(playerPlayAreas[seatPos]) or nil
    if zone==nil then return false end
    local area=footprint(card)
    for _,mana in ipairs(zone.getObjects()) do
        local color=manaColor(mana)
        if color~=nil and matchesCardMana(card,color) then
            local pos=mana.getPosition()
            if math.abs(pos[1]-area.x)<area.halfX
                and math.abs(pos[3]-area.z)<area.halfZ then return true end
        end
    end
    return false
end

trackerPrivate.cardEffects=require("PlayingGame.PlayerBoard.ResourceTracker.Cards.CardEffects")({
    trackerPrivate=trackerPrivate,
    combatConfig=combatConfig,
    chosenEffect=chosenEffect,
    cardPosture=cardPosture,
    cardCanPlaySideways=cardCanPlaySideways,
    sideChoices=sideChoices,
    currentLandBlockValue=currentLandBlockValue,
    resourceCardsUsesDayMana=resourceCardsUsesDayMana,
    applyLinkedResourceBonus=applyLinkedResourceBonus,
    effectHasTrackedResource=effectHasTrackedResource,
    cardTerrainEffects=cardTerrainEffects,
    terrainEffectActive=terrainEffectActive,
    choiceCategory=choiceCategory,
    resourceCardsMoveRole=resourceCardsMoveRole
})
local calculateSideways=trackerPrivate.cardEffects.calculateSideways
local calculateCard=trackerPrivate.cardEffects.calculateCard

local resolveActionLinks=require("PlayingGame.PlayerBoard.ResourceTracker.Cards.ActionLinks")({
    overlapArea=overlapArea,
    cardPosture=cardPosture,
    linkedColorChoices=linkedColorChoices,
    canPayDiscard=canPayDiscard,
    resourceCardsArtifactBroken=resourceCardsArtifactBroken
})

-- The same floating red X visualises Throw for full Artifacts and cards
-- consumed by a linked effect (Maximal Effect or Ritual Attack). It is
-- presentation, not the authoritative end-turn disposal decision.
function resourceCardsMaximalEffectMarkerNoop() end

function resourceCardsMaximalEffectMarked(card)
    if card==nil or card.getButtons==nil then return false end
    for _,button in ipairs(card.getButtons() or {}) do
        if button.click_function=="resourceCardsMaximalEffectMarkerNoop" then return true end
    end
    return false
end

function resourceCardsMaximalEffectMark(card,active)
    if card==nil or card.type~="Card" or card.getButtons==nil then return end
    local found,existing={},nil
    for _,button in ipairs(card.getButtons() or {}) do
        if button.click_function=="resourceCardsMaximalEffectMarkerNoop" then
            found[#found+1]=button.index
            existing=existing or button
        end
    end
    for i=#found,(active and 2 or 1),-1 do card.removeButton(found[i]) end
    if active then
        local bounds=card.getBoundsNormalized()
        local scale=card.getScale()
        local height=bounds~=nil and bounds.size~=nil and (bounds.size.y or bounds.size[2]) or 0
        local scaleY=scale~=nil and (scale.y or scale[2]) or 1
        -- Lift well clear of the card surface to avoid zoom-dependent z-fighting.
        local markerY=math.max(0.38,height/(2*math.max(0.01,scaleY))+0.25)
        if #found==0 and card.createButton~=nil then
            card.createButton({click_function="resourceCardsMaximalEffectMarkerNoop",
                function_owner=Global,label="X",position={0,markerY,0},
                rotation={0,0,0},width=0,height=0,font_size=640,
                font_color={1,0.04,0.04}})
        elseif #found>0 and card.editButton~=nil then
            -- Saved games may still contain the old near-surface button.
            local position=existing~=nil and existing.position or nil
            local oldY=position~=nil and (position.y or position[2]) or nil
            if type(oldY)~="number" or math.abs(oldY-markerY)>0.02 then
                card.editButton({index=found[1],position={0,markerY,0}})
            end
        end
    end
    trackerPrivate.maximalMarkedByGUID=trackerPrivate.maximalMarkedByGUID or {}
    trackerPrivate.maximalMarkedByGUID[card.guid]=active and true or nil
end

-- Special-card workflows also need this link while tracking is OFF. Recover
-- only the overlap and power for Maximal Effect, not full resource totals.
-- When tracking is ON, its authoritative resolver record takes precedence.
function resourceCardsMaximalEffectLink(seatPos,targetGUID)
    if seatPos==nil or targetGUID==nil then return nil end
    if resourceCardsPanelOpen() then
        local scan=resourceCardScanBySeat[seatPos]
        local record=scan~=nil and scan.cards~=nil and scan.cards[targetGUID] or nil
        if record~=nil then return record.repeatLink end
    end
    local zone=getObjectFromGUID(playerPlayAreas[seatPos])
    if zone==nil then return nil end
    local objects=zone.getObjects()
    local target=nil
    for _,obj in ipairs(objects) do
        if obj.guid==targetGUID then target=obj break end
    end
    local data=target~=nil and gameCards[target.guid] or nil
    if data==nil or (data.cardType~="Starting" and data.cardType~="Advanced Action")
        or cardPosture(target)~="upright" then return nil end
    for _,source in ipairs(objects) do
        local sourceData=gameCards[source.guid]
        local rule=sourceData~=nil and cardResourceDefinitions[sourceData.resourceKey] or nil
        local spec=rule~=nil and rule.requiredLink or nil
        if spec~=nil and spec.mode=="repeat" and source.is_face_down~=true
            and cardPosture(source)=="upright" then
            local area=footprint(source)
            local best,bestPriority,bestArea=nil,-1,0
            for _,candidate in ipairs(objects) do
                local details=gameCards[candidate.guid]
                if candidate.guid~=source.guid and details~=nil
                    and (details.cardType=="Starting" or details.cardType=="Advanced Action")
                    and cardPosture(candidate)=="upright" then
                    local overlap=overlapArea(area,footprint(candidate))
                    local priority=candidate.is_face_down==true and 1 or 0
                    if overlap>0 and (priority>bestPriority
                        or (priority==bestPriority and (overlap>bestArea
                            or (overlap==bestArea and best~=nil
                                and candidate.guid<best.guid)))) then
                        best,bestPriority,bestArea=candidate,priority,overlap
                    end
                end
            end
            if best~=nil and best.guid==targetGUID then
                local strong=false
                for _,mana in ipairs(objects) do
                    local color=manaColor(mana)
                    -- A held or smooth-moving mana object is not a settled payment,
                    -- even if TTS still reports it inside the shallow play zone.
                    if color~=nil and trackerPrivate.readyForXZ(mana)
                        and matchesCardMana(source,color) then
                        local p=mana.getPosition()
                        local x,z=p.x or p[1],p.z or p[3]
                        if math.abs(x-area.x)<area.halfX
                            and math.abs(z-area.z)<area.halfZ then
                            strong=true break
                        end
                    end
                end
                return {powered=strong,sourceGUID=source.guid,
                    count=strong and spec.poweredCount or spec.normalCount}
            end
        end
    end
    return nil
end

-- A Maximal Effect power mana object cannot also be one of Magic Talent's
-- additional casting/claim payments, even if overlapping cards share X/Z.
function resourceCardsMaximalEffectSourceManaGUIDs(seatPos,sourceGUID)
    return trackerPrivate.manaPayments.resourceCardsMaximalEffectSourceManaGUIDs(seatPos,sourceGUID,
        footprint,manaColor,trackerPrivate.readyForXZ,matchesCardMana)
end

-- One shared linked-throw decision, kept separate from ordinary discard
-- payments. The resolver only accepts Starting/Advanced Action cards for
-- the two throw-away links; Spells/Artifacts may pay some discard costs but
-- must never be promoted to throw-away because of that.
function resourceCardsMaximalEffectSyncMarks(seatPos,cards,repeats,discarded,hasDiscard)
    trackerPrivate.throwAwayLinksByGUID=trackerPrivate.throwAwayLinksByGUID or {}
    local prior=trackerPrivate.throwAwayLinksByGUID
    local present={}
    for _,card in ipairs(cards or {}) do
        present[card.guid]=true
        local repeated=repeats~=nil and repeats[card.guid]~=nil
            or (repeats==nil and resourceCardsMaximalEffectLink(seatPos,card.guid)~=nil)
        local costSource=discarded~=nil and discarded[card.guid] or nil
        local costData=costSource~=nil and gameCards[costSource] or nil
        local costRule=costData~=nil and cardResourceDefinitions[costData.resourceKey] or nil
        local ritual=costRule~=nil and costRule.requiredLink~=nil
            and costRule.requiredLink.mode=="throwAway"
            and hasDiscard~=nil and hasDiscard[costSource]==true
        -- Before End Turn, preserve the most recent authoritative ON scan.
        -- An OFF reconciliation instead uses manual face-down or Maximal
        -- Effect's physical fallback rather than guessing at payment links.
        if discarded==nil and repeats~=nil and resourceCardsPanelOpen()
            and prior[card.guid]=="ritualAttack" then ritual=true end
        prior[card.guid]=repeated and "maximalEffect"
            or ritual and "ritualAttack" or nil
        local artifactThrown=resourceCardsArtifactBroken~=nil
            and resourceCardsArtifactBroken(card.guid,card)==true
        local data=gameCards~=nil and gameCards[card.guid] or nil
        -- The red X is a physical TTS button too: keep the back completely
        -- clear, then restore the X from the saved state after turning face up.
        local artifactBack=data~=nil and data.cardType=="Artifact"
            and card.is_face_down==true
        resourceCardsMaximalEffectMark(card,
            not artifactBack and (repeated or ritual or artifactThrown))
    end
    for guid in pairs(prior) do
        if not present[guid] then prior[guid]=nil end
    end
    for guid in pairs(trackerPrivate.maximalMarkedByGUID or {}) do
        if not present[guid] then
            local previous=getObjectFromGUID(guid)
            if previous==nil then trackerPrivate.maximalMarkedByGUID[guid]=nil
            elseif not combatConfig.cardInTransit(previous) then
                resourceCardsMaximalEffectMark(previous,false)
            end
        end
    end
end

-- Cleanup and the UI consult the same saved/physical/link verdict, not the
-- red-X button. Half Banners use face-down only to mean 'spent', and stay
-- attached. A Wound that is manually thrown is deleted at cleanup.
function resourceCardsThrowAwayReason(card)
    if card==nil or card.type~="Card" then return nil end
    local data=gameCards~=nil and gameCards[card.guid] or nil
    if data~=nil and data.cardType=="Artifact" and data.full~=nil then return nil end
    if card.is_face_down==true then return "manual" end
    if data~=nil and data.cardType=="Artifact"
        and resourceCardsArtifactBroken(card.guid,card) then return "artifact" end
    -- A resumed End Turn must retain the pre-cleanup verdict after a reload,
    -- even if its source Action has already moved to discard.
    local saved=gStates~=nil and gStates.preEndTurn==true
        and gStates.throwAwayCleanupByGUID or nil
    if saved~=nil and saved[card.guid]~=nil then return saved[card.guid] end
    -- Older saves taken midway through cleanup may have an X but no saved
    -- verdict table. Only in that legacy recovery case is the physical
    -- marker used as a migration fallback.
    if gStates~=nil and gStates.preEndTurn==true
        and gStates.throwAwayCleanupByGUID==nil
        and resourceCardsMaximalEffectMarked(card) then return "maximalEffect" end
    return trackerPrivate.throwAwayLinksByGUID~=nil
        and trackerPrivate.throwAwayLinksByGUID[card.guid] or nil
end

-- The last End Turn click is a final physical reconciliation point. On a
-- fresh load the classic X may not exist yet, and while OFF no resource scan
-- should run just to discover it. Record all consumed Actions before any
-- callback starts moving their source cards to the discard pile.
function resourceCardsMaximalEffectBeforeEndTurn(seatPos)
    if seatPos==nil then return end
    local zone=getObjectFromGUID(playerPlayAreas[seatPos])
    if zone==nil then return end
    local cards={}
    for _,obj in ipairs(zone.getObjects()) do
        if obj.type=="Card" then cards[#cards+1]=obj end
    end
    -- Rebuild only at the start of a new cleanup, never during recovery.
    if gStates~=nil then gStates.throwAwayCleanupByGUID=nil end
    local repeats=nil
    if resourceCardsPanelOpen() then
        local scan=resourceCardScanBySeat[seatPos]
        if scan~=nil and scan.cards~=nil then
            repeats={}
            for guid,record in pairs(scan.cards) do
                if record.repeatLink~=nil then repeats[guid]=record.repeatLink end
            end
        end
    end
    resourceCardsMaximalEffectSyncMarks(seatPos,cards,repeats)
    -- Save the link verdict before the source and target cards start moving.
    -- Physical face-down and Artifact THROW states are already persisted or
    -- reconstructible, so only linked consumptions require this snapshot.
    if gStates~=nil then
        local saved={}
        local present={}
        for _,card in ipairs(cards) do present[card.guid]=true end
        for guid,reason in pairs(trackerPrivate.throwAwayLinksByGUID or {}) do
            if present[guid] and (reason=="maximalEffect" or reason=="ritualAttack") then
                saved[guid]=reason
            end
        end
        gStates.throwAwayCleanupByGUID=saved
    end
end

-- Marker reconciliation while minimized is independent of card recalculation.
function resourceCardsMaximalEffectOffDrop(obj)
    if obj==nil or gStates==nil or gStates.firstStarted~=true
        or gStates.preEndTurn==true or resourceCardsPanelOpen() then return end
    local current=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    local seat=current~=nil and current.seatPos or nil
    local data=gameCards~=nil and gameCards[obj.guid] or nil
    local artifact=data~=nil and data.cardType=="Artifact" and data.full==nil
    if seat==nil or (not artifact
        and not objectGUIDInZone("8fac50",playerPlayAreas[seat])
        and not objectGUIDInZone("d030d8",playerPlayAreas[seat])
        and next(trackerPrivate.maximalMarkedByGUID or {})==nil) then return end
    local guid=obj.guid
    local function update()
        if gStates==nil or gStates.preEndTurn==true or resourceCardsPanelOpen() then return end
        local zone=getObjectFromGUID(playerPlayAreas[seat])
        if zone==nil then return end
        local cards={}
        for _,card in ipairs(zone.getObjects()) do
            if card.type=="Card" then cards[#cards+1]=card end
        end
        resourceCardsMaximalEffectSyncMarks(seat,cards)
    end
    safeWaitCondition("PlayerBoard.MaximalEffect",update,function()
        local live=getObjectFromGUID(guid)
        return live==nil or (live.held_by_color==nil and live.resting
            and not live.isSmoothMoving())
    end,8,update)
end

-- Generic Skill-card links: one Skill per target, one target per Skill.
-- The descriptor, not an individual Skill GUID, determines replacement value,
-- card-type bonuses, mana payment and player-declared conditional values.
local function manaInsideFootprint(mana,area)
    local p=mana.getPosition()
    return math.abs(p[1]-area.x)<area.halfX
        and math.abs(p[3]-area.z)<area.halfZ
end

trackerPrivate.bestManaCard=require("PlayingGame.PlayerBoard.ResourceTracker.Scanning.ManaPayments").bestManaCard

-- Time Bending's extra turn must be usable without opening the Resource Tracker.
-- Read the physical Blue casting payment and a separate Black strong-side payment;
-- the mere presence of the Spell in the play area does not establish either.
function resourceCardsTimeBendingPaid(seatPos,card)
    return trackerPrivate.manaPayments.resourceCardsTimeBendingPaid(seatPos,card,
        footprint,cardPosture,manaColor,manaInsideFootprint)
end

-- Physical mana is authoritative for a paid Unit ability. It is read from
-- either overlapping board zone, even with the Resource Tracker collapsed.
local function unitManaCounts(unit,seatPos,source,crystalsOnly)
    return trackerPrivate.manaPayments.unitManaCounts(unit,seatPos,source,crystalsOnly,
        footprint,manaColor,trackerPrivate.readyForXZ,isManaTokenFigurine,manaInsideFootprint)
end

local function unitAbilityPaid(ability,counts)
    return trackerPrivate.manaPayments.unitAbilityPaid(ability,counts,
        resourceCardsGoldAllowed,resourceCardsBlackAllowed)
end

local function unitManaSignature(counts)
    return trackerPrivate.manaPayments.unitManaSignature(counts,
        resourceCardsGoldAllowed,resourceCardsBlackAllowed)
end

unitManaDecision=require("PlayingGame.PlayerBoard.ResourceTracker.Units.UnitChoices")({
    unitManaCounts=unitManaCounts,
    unitManaSignature=unitManaSignature,
    unitAbilityPaid=unitAbilityPaid,
    resourceCardsGoldAllowed=resourceCardsGoldAllowed
})

-- Earlier Command activations own the Unit's combat use for this turn.
-- Check their actual paid/selected abilities rather than the currently
-- displayed Command number; editing an earlier choice reopens a later use.
combatConfig.unitMoveRole=resourceCardsMoveRole
combatConfig.unitCombatBlocked=function(unit,abilities,useIndex)
    return unitHistoryCombatConflict(unit.guid,useIndex,abilities,function(activation)
        return unitManaDecision(unit,abilities,activation,
            activation.frozenCounts or activation.lastCounts)
    end,function(key) return resourceCardsMoveRole(key,false) end)
end

-- A Source die used earlier this turn disallows Who Needs Magic?'s +3.
-- Keep +2 available, even when the player previously selected +3.
local function skillChoicesForCurrentTurn(rule)
    if rule~=nil and rule.noSourceDieBonus==true then
        local player=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
        if player~=nil and player.whoNeedsMagicSourceDieUsed==true then
            return {rule.choices[1]}
        end
    end
    return rule~=nil and rule.choices or nil
end

trackerPrivate.skillLinks=require("PlayingGame.PlayerBoard.ResourceTracker.Cards.SkillLinks")({
    trackerPrivate=trackerPrivate,
    resourceCardsGoldAllowed=resourceCardsGoldAllowed,
    resourceCardsBlackAllowed=resourceCardsBlackAllowed,
    currentChoice=currentChoice,
    skillChoicesForCurrentTurn=skillChoicesForCurrentTurn,
    manaColor=manaColor,
    resourceObjectKind=resourceObjectKind,
    cardPosture=cardPosture,
    overlapArea=overlapArea,
    manaInsideFootprint=manaInsideFootprint,
    matchesCardMana=matchesCardMana
})
local matchingSidewaysMana=trackerPrivate.skillLinks.matchingSidewaysMana
local resolveSkillCardLinks=trackerPrivate.skillLinks.resolveSkillCardLinks
local resolveManaSkillLinks=trackerPrivate.skillLinks.resolveManaSkillLinks

-- Physical Skill GUIDs, not translated text, determine available resources.
-- Skills outside the active player's Play Area are not counted.
-- A combat inside a Dungeon/Tomb is always Night for day/night Skill bonuses.
local function skillUsesDayStrength()
    return resourceCardsUsesDayMana()
end

-- Puppet Master tokens already have authoritative half-strength Attack/Block
-- perk data. Keep each printed Attack separate: a Puppet cannot combine all
-- of its enemy's different attacks into one automatic total.
combatConfig.puppetTypes={P="",F="Fire",I="Ice",IF="ColdFire"}
combatConfig.puppetTypeOrder={"P","F","I","IF"}
local function puppetResourceOptions(guid)
    local record=gStates.puppetMasterPuppets~=nil and gStates.puppetMasterPuppets[guid] or nil
    if record==nil then return nil end
    local perks=gStates.monsterPerks~=nil and gStates.monsterPerks[guid] or nil
    if perks==nil and puppetMasterDataForSourceGUID~=nil
        and puppetMasterPerksForData~=nil then
        local _,data=puppetMasterDataForSourceGUID(record.sourceGUID)
        perks=puppetMasterPerksForData(data)
    end
    if perks==nil then return nil end
    local choices={}
    for _,family in ipairs({"attack","block"}) do
        for _,attackType in ipairs(combatConfig.puppetTypeOrder) do
            local entries=perks[family]~=nil and perks[family][attackType] or nil
            if type(entries)=="table" then
                for i,value in ipairs(entries) do
                    if type(value)=="number" and value>0 then
                        ---@type table<string, string|number>
                        local choice={key=family..attackType..i,icon=family}
                        if attackType~="P" then choice.iconOverlay=attackType=="IF" and "C" or attackType end
                        choice[family..combatConfig.puppetTypes[attackType]]=value
                        choices[#choices+1]=choice
                    end
                end
            end
        end
    end
    return #choices>0 and choices or nil
end

local calculateSkill=require("PlayingGame.PlayerBoard.ResourceTracker.Cards.SkillEffects")({
    skillChoicesForCurrentTurn=skillChoicesForCurrentTurn,
    chosenEffect=chosenEffect,
    skillUsesDayStrength=skillUsesDayStrength,
    effectHasTrackedResource=effectHasTrackedResource
})

-- Stable modifier instances prevent false movement redraws on every scan.
combatConfig.druidicTerrainEffects=require("PlayingGame.PlayerBoard.ResourceTracker.Cards.TerrainModifiers").selectedTerrainDiscounts
local terrainModifierPrecedes=require("PlayingGame.PlayerBoard.ResourceTracker.Cards.TerrainModifiers").precedes

-- Count only printed enemy-token icons, not site-given traits.
-- A Coldfire attack represents both Fire and Ice attack-colour icons.
combatConfig.enemyPrintedAbilityKeys={
    "swiftness","cumbersome","brutal","poison","paralyse",
    "assassination","vampiric","elusive","fortified","unfortified",
    "defend","pResist","fResist","iResist"
}
local function enemyPrintedIconBonus(enemy)
    if enemy==nil then return nil end
    if enemy.arcaneImmunity==true then return 0 end
    local count=0
    for _,key in ipairs(combatConfig.enemyPrintedAbilityKeys) do
        local value=enemy[key]
        if value==true or (type(value)=="number" and value>0) then
            count=count+1
        end
    end
    local attacks=enemy.attack or {}
    if attacks.F~=nil or attacks.IF~=nil then count=count+1 end
    if attacks.I~=nil or attacks.IF~=nil then count=count+1 end
    return count
end

-- Possess borrows actual enemy attacks, including live bonuses and drawn
-- summons, without their special abilities; they form one Attack source.
combatConfig.possessedAttackKeys={P="attack",F="attackFire",I="attackIce",
    IF="attackColdFire",M="attackPsychic"}
local function enemyPrintedPossessAttack(enemy,guid)
    if enemy==nil or enemy.arcaneImmunity==true then return nil end
    local perks=gStates~=nil and gStates.monsterPerks~=nil and gStates.monsterPerks[guid] or nil
    if perks~=nil and perks.arcaneImmunity==true then return nil end
    local attacks=combatEnemyPrintedAttacks(enemy,perks,false,guid)
    if enemy.monsters~=nil then
        for _,summoned in ipairs(combatSummonedFor(guid)) do
            for _,attack in ipairs(combatEnemyPrintedAttacks(
                summoned.data,summoned.perks,false,summoned.guid)) do
                attacks[#attacks+1]=attack
            end
        end
    end
    local resources={}
    for _,attack in ipairs(attacks) do
        local field=combatConfig.possessedAttackKeys[attack.key]
        if field~=nil and (tonumber(attack.value) or 0)>0 then
            resources[field]=(resources[field] or 0)+attack.value
        end
    end
    return resources
end

local function addResourceAmounts(result,totals)
    result.contributes=false
    if result.resources==nil then return end
    for category,value in pairs(result.resources) do
        if trackerPrivate.totalsKeys[category] and type(value)=="number" then
            totals[category]=(totals[category] or 0)+value
            if value~=0 then result.contributes=true end
        end
    end
end

-- Scan the play area for used abilities, the Unit area for Units, and crystal
-- inventory for unused mana. Only a played, supported effect enters the totals.
-- Explicit arrows always win; proximity is only an initial default.
-- Attack-only reminders have no Armour, Fortification, or defensive traits.
-- Enforce this for every enemy-targeted card, Skill and Unit effect, not only Curse.
local function combatEffectTargetEligible(spec)
    local defenceEffect=combatEffectRequiresDefence(spec)
    return function(enemy,guid)
        local data=combatEnemyData(guid,enemy)
        return data~=nil and (data.attackOnly~=true or not defenceEffect)
    end
end

local function combatEffectChosenEnemy(sourceGUID,area,monsters,eligible)
    local chosen=nil
    local valid,invalid={},false
    local function targetFor(guid)
        local target=monsters[guid]
        if target==nil then
            -- Attack-reducing effects can explicitly link to reminder attacks.
            local special=combatPlayMonsters()[guid]
            local data=special~=nil and combatEnemyData(guid,special) or nil
            if data~=nil and data.attackOnly then target=special end
        end
        if target~=nil and target.is_face_down~=true
            and (eligible==nil or eligible(target,guid)) then return target end
        return nil
    end
    for guid in pairs(attackAssignmentsTargetGUIDs(sourceGUID)) do
        local target=targetFor(guid)
        if target~=nil then
            valid[guid]=true
            if chosen==nil or guid<chosen.guid then chosen=target end
        else invalid=true end
    end
    -- A pending source may remain registered with no assigned enemy. Prune
    -- only actual invalid arrows, not the source or its pending selection.
    if invalid and attackAssignmentsPruneSourceTargets~=nil then
        attackAssignmentsPruneSourceTargets(sourceGUID,valid)
    end
    local locked=combatAssignmentState.targets[sourceGUID]
    if locked~=nil and targetFor(locked)==nil then
        combatAssignmentState.targets[sourceGUID]=nil
        combatAssignmentState.explicit[sourceGUID]=nil
    end
    return chosen or combatEffectNearestEnemy(area,monsters,footprint,overlapArea,eligible)
end

trackerPrivate.unitEffects=require("PlayingGame.PlayerBoard.ResourceTracker.Units.UnitEffects")(
    trackerPrivate,unitAbilityPaid,resourceCardsUsesDayMana)

local function renderSeat(seatPos)
    if not resourceCardsPanelOpen() then return end
    local active=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    if active==nil or active.seatPos~=seatPos then return end
    if trackerPrivate.traceEnabled then trackerPrivate.traceEvent("render.start",seatPos) end
    -- Keep the last complete calculator result while a played card is carried
    -- or its final X/Z/orientation is being confirmed. Never publish a
    -- half-empty scan that discards a choice or replaces an explicit target.
    for guid,movement in pairs(trackerPrivate.playCardMovements or {}) do
        local live=getObjectFromGUID(guid)
        if live==nil or (live.isDestroyed~=nil and live.isDestroyed()) then
            trackerPrivate.playCardMovements[guid]=nil
        elseif movement.seatPos==seatPos then
            if trackerPrivate.traceEnabled then
                trackerPrivate.traceEvent("render.blocked",seatPos,guid,
                    "watch="..tostring(movement.releasing)
                    .." samples="..tostring(movement.samples)
                    .." held="..tostring(live.held_by_color))
            end
            return
        end
    end
    trackerPrivate.renderCombatNight=nil
    local profile=trackerPrivate.traceEnabled and trackerPrivate.profileScanStart() or nil
    local scanStage
    if profile~=nil then scanStage=profile.started end

    local objects,placements,monsters,playMonsters,combatMonsters,
        enemyEntries,inventoryCrystalCounts,cards,wounds,skills,
        manaObjects,footprints,unitPaymentMana,enemyEffects,pendingWingsNight,
        deferredUnfortifiedUnitEffects,unitCombatBoost,preventUnitDamage,allUnitResistances,heroFirstWoundIgnored,
        heroPsychicBlock,hasUnits=
        trackerPrivate.scanObservation.observe({
        seatPos=seatPos, trackerPrivate=trackerPrivate, combatConfig=combatConfig,
        combatEnemyData=combatEnemyData, resourceObjectKind=resourceObjectKind,
        combatKeepHeldEnemies=combatKeepHeldEnemies,
        resourceCardsCombatNightFromEnemies=resourceCardsCombatNightFromEnemies,
        combatCalcUpdate=combatCalcUpdate, footprint=footprint,
    })

    if scanStage~=nil then scanStage=trackerPrivate.profileCheckpoint("scan.observation",scanStage) end
    local unitState, activations, unitSiteMode, unitSite, chosenSiteUnit, woundCount=
        trackerPrivate.scanObservation.prepare({
        seatPos=seatPos, cards=cards, skills=skills, placements=placements, hasUnits=hasUnits,
        combatMonsters=combatMonsters, combatConfig=combatConfig, trackerPrivate=trackerPrivate,
        cardPosture=cardPosture, combatUnitSiteRestriction=combatUnitSiteRestriction,
        combatOneUnitChosen=combatOneUnitChosen, combatOneUnitSelect=combatOneUnitSelect,
        combatUnitSitePermits=combatUnitSitePermits, unitResourceDefinitions=unitResourceDefinitions,
        clearHighlight=clearHighlight,
    })

    if scanStage~=nil then scanStage=trackerPrivate.profileCheckpoint("scan.unitPreparation",scanStage) end
    local manaByObject,manaBySkill,manaByCard,skillLinksByTarget,skillLinksBySkill,
        sidewaysSkillMana,powered,usedMana,spellCastingPaid,powerManaColorsByCard,
        effectManaByCard,links,boostBy,boostSource,discarded,
        hasDiscard,linkedCardBySource,repeatByTarget,discardBoostBySource,extraTerrainManaByCard,
        extraTerrainManaByObject=
        trackerPrivate.scanPayments.resolve({
        seatPos=seatPos, cards=cards, wounds=wounds, skills=skills, manaObjects=manaObjects,
        footprints=footprints, placements=placements, unitState=unitState,
        resolveManaSkillLinks=resolveManaSkillLinks, resolveSkillCardLinks=resolveSkillCardLinks,
        trackerPrivate=trackerPrivate, cardPosture=cardPosture, matchesCardMana=matchesCardMana,
        manaColor=manaColor, effectManaPossibilities=effectManaPossibilities,
        resolveActionLinks=resolveActionLinks,
    })
    if scanStage~=nil then scanStage=trackerPrivate.profileCheckpoint("scan.payments",scanStage) end
    local current,records,totals={}, {}, {}
    local usesCurrentHexBlock=false
    local usesCurrentHexHealing=false
    local ignoreSiteFortifications=false
    local terrainModifiers=resourceCardsWeatherTerrainEffects(seatPos)
    local movementEffects={jumpTwoSpaces=false,ignoreRampagers=false,
        singleSpaceDiscount=0,windFlightMax=0}
    local usesSkillLocation=false
    trackerPrivate.scanFinalization.passiveTerrain({
        seatPos=seatPos, terrainModifiers=terrainModifiers, ownedSkillAtSeat=ownedSkillAtSeat,
        footprint=footprint, manaObjects=manaObjects, placements=placements, manaColor=manaColor,
        manaInsideFootprint=manaInsideFootprint,
    })
    -- Only infer an effect after assigning separate casting/power/effect
    -- payments. If Gold or multiple valid assignments leave alternatives,
    -- show the supported choices rather than choosing a mana token by GUID.
    local function paidManaChoices(guid,rule,strong,boost)
        local needPower=powered[guid]==true and boost==nil
        local possible,anyColor=effectManaPossibilities(rule.effectManaChoice,
            effectManaByCard[guid] or {},needPower,
            resourceCardsGoldAllowed(),resourceCardsBlackAllowed())
        local choices={}
        for _,choice in ipairs(sideChoices(rule,strong) or {}) do
            if anyColor or possible[choiceCategory(choice)] then
                choices[#choices+1]=choice
            end
        end
        return choices
    end
    if scanStage~=nil then scanStage=trackerPrivate.profileCheckpoint("scan.passiveTerrain",scanStage) end
    usesCurrentHexBlock,usesCurrentHexHealing,ignoreSiteFortifications,
        unitCombatBoost,preventUnitDamage,allUnitResistances,heroFirstWoundIgnored=
        trackerPrivate.playedCardScan.process({
        seatPos=seatPos, cards=cards, powered=powered, boostBy=boostBy, repeatByTarget=repeatByTarget,
        linkedCardBySource=linkedCardBySource, discarded=discarded, hasDiscard=hasDiscard,
        spellCastingPaid=spellCastingPaid, links=links, skillLinksByTarget=skillLinksByTarget,
        discardBoostBySource=discardBoostBySource, woundCount=woundCount, enemyEntries=enemyEntries,
        monsters=monsters, footprints=footprints, combatCalcOn=combatCalcOn,
        combatEnemyInPlay=combatEnemyInPlay, combatAssignmentState=combatAssignmentState,
        combatConfig=combatConfig, trackerPrivate=trackerPrivate, paidManaChoices=paidManaChoices,
        inventoryCrystalCounts=inventoryCrystalCounts, playMonsters=playMonsters, unitState=unitState,
        manaByCard=manaByCard, current=current, records=records, totals=totals, enemyEffects=enemyEffects,
        pendingWingsNight=pendingWingsNight, extraTerrainManaByCard=extraTerrainManaByCard,
        movementEffects=movementEffects, cardPosture=cardPosture,
        cardCanPlaySideways=cardCanPlaySideways, linkedColorChoices=linkedColorChoices, overlapArea=overlapArea,
        footprint=footprint, combatNearestEnemyGUID=combatNearestEnemyGUID,
        enemyPrintedIconBonus=enemyPrintedIconBonus, sideChoices=sideChoices,
        guessInitialCardChoice=guessInitialCardChoice, calculateCard=calculateCard, currentChoice=currentChoice,
        choiceCategory=choiceCategory, combatEnemyHasTrait=combatEnemyHasTrait,
        enemyPrintedPossessAttack=enemyPrintedPossessAttack, combatEnemyData=combatEnemyData,
        combatIsSummonedToken=combatIsSummonedToken, currentSpellTerrain=currentSpellTerrain,
        inventorySetChoice=inventorySetChoice, effectHasTrackedResource=effectHasTrackedResource,
        combatEffectChosenEnemy=combatEffectChosenEnemy, combatEffectTargetEligible=combatEffectTargetEligible,
        resourceCardsRecruitInfluenceBonus=resourceCardsRecruitInfluenceBonus,
        showChoiceButtons=showChoiceButtons, resourceCardsDetailsOpen=resourceCardsDetailsOpen,
        cardTerrainEffects=cardTerrainEffects,
        resourceCardsIgnoreSiteFortification=resourceCardsIgnoreSiteFortification,
        addResourceAmounts=addResourceAmounts, setHighlight=setHighlight,
        usesCurrentHexBlock=usesCurrentHexBlock, usesCurrentHexHealing=usesCurrentHexHealing,
        ignoreSiteFortifications=ignoreSiteFortifications, unitCombatBoost=unitCombatBoost,
        preventUnitDamage=preventUnitDamage, allUnitResistances=allUnitResistances,
        heroFirstWoundIgnored=heroFirstWoundIgnored,
    })
    if scanStage~=nil then scanStage=trackerPrivate.profileCheckpoint("scan.playedCards",scanStage) end
    trackerPrivate.cardInteractions.process({
        cards=cards, records=records, totals=totals, cardPosture=cardPosture, monsters=monsters,
        current=current, setHighlight=setHighlight, discarded=discarded, choiceCategory=choiceCategory,
        chosenEffect=chosenEffect, overlapArea=overlapArea, footprints=footprints, combatConfig=combatConfig,
        repeatByTarget=repeatByTarget, wounds=wounds, skillLinksByTarget=skillLinksByTarget,
        calculateSideways=calculateSideways, showChoiceButtons=showChoiceButtons, trackerPrivate=trackerPrivate,
        addResourceAmounts=addResourceAmounts, links=links,
    })
    if scanStage~=nil then scanStage=trackerPrivate.profileCheckpoint("scan.cardInteractions",scanStage) end
    local attackTransforms,transformingUnits
    unitState,chosenSiteUnit,allUnitResistances,attackTransforms,transformingUnits=
        trackerPrivate.unitScan.process({
        seatPos=seatPos, cards=cards, records=records, objects=objects, activations=activations,
        unitState=unitState, unitSiteMode=unitSiteMode, unitSite=unitSite, chosenSiteUnit=chosenSiteUnit,
        unitPaymentMana=unitPaymentMana, unitCombatBoost=unitCombatBoost,
        allUnitResistances=allUnitResistances, combatCalcOn=combatCalcOn, combatConfig=combatConfig,
        trackerPrivate=trackerPrivate, unitResourceDefinitions=unitResourceDefinitions,
        cardPosture=cardPosture, clearHighlight=clearHighlight, trackerChoiceScores=trackerChoiceScores,
        removeChoiceButtons=removeChoiceButtons, unitManaCounts=unitManaCounts,
        unitManaDecision=unitManaDecision, combatOneUnitSelect=combatOneUnitSelect,
        combatUnitSitePermits=combatUnitSitePermits, showUnitAbilityButtons=showUnitAbilityButtons,
        unitAbilityPaid=unitAbilityPaid, addResourceAmounts=addResourceAmounts, totals=totals, current=current,
        setHighlight=setHighlight,
        deferredUnfortifiedUnitEffects=deferredUnfortifiedUnitEffects,
        unitAbilityTargetKey=unitAbilityTargetKey, combatEffectChosenEnemy=combatEffectChosenEnemy,
        footprint=footprint, monsters=monsters, combatEffectTargetEligible=combatEffectTargetEligible,
        enemyEffects=enemyEffects,
    })
    if scanStage~=nil then scanStage=trackerPrivate.profileCheckpoint("scan.units",scanStage) end
    trackerPrivate.skillInteractions.process({
        seatPos=seatPos, skills=skills, cards=cards, wounds=wounds, objects=objects, activations=activations,
        records=records, current=current, totals=totals, manaBySkill=manaBySkill,
        skillLinksBySkill=skillLinksBySkill, unitState=unitState, inventoryCrystalCounts=inventoryCrystalCounts,
        calculateSkill=calculateSkill, addResourceAmounts=addResourceAmounts, setHighlight=setHighlight,
        chosenEffect=chosenEffect, choiceCategory=choiceCategory, overlapArea=overlapArea, footprint=footprint,
        footprints=footprints, cardPosture=cardPosture, showChoiceButtons=showChoiceButtons,
        skillLinksByTarget=skillLinksByTarget, matchingSidewaysMana=matchingSidewaysMana,
        trackerPrivate=trackerPrivate, combatConfig=combatConfig, monsters=monsters,
        combatMonsters=combatMonsters, choiceLetters=choiceLetters, combatEnemyData=combatEnemyData,
        combatEnemyPrintedAttacks=combatEnemyPrintedAttacks, combatEffectChosenEnemy=combatEffectChosenEnemy,
        combatEffectTargetEligible=combatEffectTargetEligible, enemyEffects=enemyEffects,
        combatAssignmentState=combatAssignmentState, manaObjects=manaObjects, placements=placements,
        usedMana=usedMana, manaInsideFootprint=manaInsideFootprint, manaColor=manaColor, powered=powered,
        powerManaColorsByCard=powerManaColorsByCard, paidManaChoices=paidManaChoices,
        currentChoice=currentChoice, effectManaPowerColors=effectManaPowerColors,
        effectManaByCard=effectManaByCard, matchesCardMana=matchesCardMana,
    })
    if scanStage~=nil then scanStage=trackerPrivate.profileCheckpoint("scan.skills",scanStage) end
    -- This scan has just granted Cumbersome to a target: show Move-target
    -- buttons immediately, without requiring the player to close/reopen the tracker.
    for _,effect in pairs(enemyEffects) do
        if effect.grantCumbersome==true then combatCumbersomeActive=true break end
    end

    usesSkillLocation=
        trackerPrivate.scanFinalization.remainingObjects({
        boostSource=boostSource, records=records, objects=objects, placements=placements, usedMana=usedMana,
        resourceObjectKind=resourceObjectKind, puppetResourceOptions=puppetResourceOptions,
        chosenEffect=chosenEffect, showChoiceButtons=showChoiceButtons, addResourceAmounts=addResourceAmounts,
        totals=totals, manaBySkill=manaBySkill, calculateSkill=calculateSkill,
        skillLinksBySkill=skillLinksBySkill, unitState=unitState,
        inventoryCrystalCounts=inventoryCrystalCounts, usesSkillLocation=usesSkillLocation,
        movementEffects=movementEffects, skillLinksByTarget=skillLinksByTarget, manaByObject=manaByObject,
        sidewaysSkillMana=sidewaysSkillMana, extraTerrainManaByObject=extraTerrainManaByObject,
        current=current, setHighlight=setHighlight,
    })


    heroPsychicBlock=
        trackerPrivate.factionRewardScan.read({
        objects=objects, placements=placements, resourceObjectKind=resourceObjectKind,
        factionRewardForObject=factionRewardForObject, chosenEffect=chosenEffect,
        effectHasTrackedResource=effectHasTrackedResource, movementEffects=movementEffects,
        heroPsychicBlock=heroPsychicBlock, combatEffectChosenEnemy=combatEffectChosenEnemy,
        footprint=footprint, monsters=monsters, combatEffectTargetEligible=combatEffectTargetEligible,
        enemyEffects=enemyEffects, showChoiceButtons=showChoiceButtons, addResourceAmounts=addResourceAmounts,
        totals=totals, records=records, current=current, setHighlight=setHighlight,
    })

    trackerPrivate.unitScan.resolveUnfortifiedTargets({
        deferredUnfortifiedUnitEffects=deferredUnfortifiedUnitEffects, monsters=monsters,
        enemyEffects=enemyEffects, ignoreSiteFortifications=ignoreSiteFortifications,
        combatAssignmentState=combatAssignmentState, combatEffectChosenEnemy=combatEffectChosenEnemy,
        footprint=footprint,
    })

    trackerPrivate.scanFinalization.linkedUnits({
        records=records, objects=objects, activations=activations, seatPos=seatPos,
        unitResourceDefinitions=unitResourceDefinitions, effectHasTrackedResource=effectHasTrackedResource,
        setHighlight=setHighlight,
    })

    trackerPrivate.factionRewardScan.modifiers({
        records=records, objects=objects, footprint=footprint, cardPosture=cardPosture,
        overlapArea=overlapArea, attackTransforms=attackTransforms, addResourceAmounts=addResourceAmounts,
        totals=totals, setHighlight=setHighlight,
    })

    trackerPrivate.unitScan.markTransforms({
        transformingUnits=transformingUnits, trackerPrivate=trackerPrivate,
        resourceCardsRawValue=resourceCardsRawValue, totals=totals, records=records, objects=objects,
        setHighlight=setHighlight,
    })


    trackerPrivate.scanFinalization.spiritGuides({
        records=records, combatConfig=combatConfig, totals=totals, setHighlight=setHighlight, objects=objects,
    })

    trackerPrivate.cardInteractions.tirelessness(cards,records,totals,cardPosture)
    trackerPrivate.scanFinalization.playedMovement({
        records=records,terrainModifiers=terrainModifiers,movementEffects=movementEffects,
        resourceCardsMoveRole=resourceCardsMoveRole,objects=objects,setHighlight=setHighlight,
    })

    trackerPrivate.scanFinalization.wingsNight({
        pendingWingsNight=pendingWingsNight, records=records, resourceCardsMoveRole=resourceCardsMoveRole,
        monsters=monsters, enemyEffects=enemyEffects, totals=totals,
        sharedSpendable=combatConfig.sharedSpendable,sharedSourceKey=combatConfig.sharedSourceKey,
        moveEligible=function(guid)
            local obj=monsters[guid]
            if obj==nil or obj.is_face_down==true then return false end
            local effect=enemyEffects[guid]
            if effect~=nil and effect.grantCumbersome==true then return true end
            return resourceCardsCombatTargetAcceptsMove(guid)
        end,
    })

    local ruthlessReadySpent,readyNeedsRescan
    ruthlessReadySpent,readyNeedsRescan=
        trackerPrivate.unitScan.payReadyInfluence({
        records=records, totals=totals,
    })

    if scanStage~=nil then scanStage=trackerPrivate.profileCheckpoint("scan.finalization",scanStage) end
    trackerPrivate.scanPublication.publish({
        seatPos=seatPos, records=records, resourceCardsMoveRole=resourceCardsMoveRole,
        combatForgetPhysicalSourceTargets=combatForgetPhysicalSourceTargets,
        showChoiceButtons=showChoiceButtons,objects=objects,
        trackerPrivate=trackerPrivate, combatEnemyInPlay=combatEnemyInPlay, terrainModifiers=terrainModifiers,
        terrainModifierPrecedes=terrainModifierPrecedes, totals=totals, movementEffects=movementEffects,
        attackTransforms=attackTransforms, resourceCardsSyncInteractionPower=resourceCardsSyncInteractionPower,
        combatConfig=combatConfig, current=current, enemyEffects=enemyEffects,
        ruthlessReadySpent=ruthlessReadySpent, ignoreSiteFortifications=ignoreSiteFortifications,
        unitState=unitState, cards=cards, cardPosture=cardPosture, preventUnitDamage=preventUnitDamage,
        allUnitResistances=allUnitResistances, heroFirstWoundIgnored=heroFirstWoundIgnored,
        heroPsychicBlock=heroPsychicBlock, usesCurrentHexBlock=usesCurrentHexBlock,
        usesCurrentHexHealing=usesCurrentHexHealing, usesSkillLocation=usesSkillLocation,
        readyNeedsRescan=readyNeedsRescan, refreshCombatEnemyPanel=refreshCombatEnemyPanel,
        combatMonsters=combatMonsters, resourceCardsApplyFameRep=resourceCardsApplyFameRep,
        clearHighlight=clearHighlight, choiceButtonShown=choiceButtonShown,
        removeChoiceButtons=removeChoiceButtons, choiceExpandedByGUID=choiceExpandedByGUID,
    })
    if scanStage~=nil then trackerPrivate.profileFinish("scan.publication",scanStage) end
    if profile~=nil then trackerPrivate.profileScanFinish(profile) end
end

local function scheduleSeatRender(seatPos)
    return trackerPrivate.scanScheduler.schedule(seatPos,trackerPrivate,renderSeat)
end

local function queueSeat(seatPos,triggerGUID)
    return trackerPrivate.scanScheduler.queue(seatPos,triggerGUID,trackerPrivate,scheduleSeatRender)
end

function resourceCardsSourceChanged()
    return trackerPrivate.scanScheduler.sourceChanged(trackerPrivate,queueSeat)
end

local function clearAll()
    return trackerPrivate.trackerLifecycle.clearAll(trackerPrivate,clearChoiceButtons,function() choiceExpandedByGUID={} end,shown,clearHighlight,combatConfig)
end

-- Explicitly resolve Banner of Fortitude's all-Unit Healing against physical
-- Wound tokens. The button is shown only for the broken side, and player
-- action is required; scanning must NEVER delete a Wound just because an
-- artifact briefly changed posture.
function resourceCardsArtifactHealUnitsClicked(player,value,id)
    return trackerPrivate.cardInteraction.healUnits(player,value,id,combatCalcOn,combatEnemyInPlay,trackerPrivate,cardPosture,cardInSeatPlayArea)
end

-- Forked Lightning commits every bolt to one combat phase, rather than
-- allowing a Ranged kill with one and a later melee hit with another.
function resourceCardsForkedLightningPhaseClicked(player,value,id)
    return trackerPrivate.combatInteraction.forkedLightningPhaseClicked(player,value,id)
end

-- The small Battle Hardened counter cycles individual printed Attacks on the
-- already targeted enemy (including multiple Attacks from summoners).
function resourceCardsBattleHardenedAttackClicked(player,value,id)
    return trackerPrivate.combatInteraction.battleHardenedAttackClicked(player,value,id,combatAssignmentState,combatHardenedAttackOptions)
end

function resourceCardsConversionClicked(player,value,id)
    return trackerPrivate.combatInteraction.conversionClicked(player,value,id,combatAssignmentActiveSeat,combatConfig)
end

-- Explicit decisions for official starting cards that have a secondary effect.
-- These controls never silently add conditional Fame, Reputation or Move.
function resourceCardsStartingCardControlClicked(player,value,id)
    return trackerPrivate.cardInteraction.startingControl(player,value,id,resourceCardsDetailsOpen,cardPosture,cardInSeatPlayArea)
end

-- Confirm how many of the basic Golden Grail's two Heal points were spent.
-- Generated but unspent Heal is worth no Fame. Right-click removes a point.
function resourceCardsArtifactGrailFameClicked(player,value,id)
    return trackerPrivate.cardInteraction.grailFame(player,value,id,resourceCardsDetailsOpen,cardPosture,cardInSeatPlayArea,combatConfig)
end

-- Toggle the strong effect on any full-size Artifact while keeping its text
-- face up. The saved choice, not rotation, controls later end-turn destruction.
function resourceCardsArtifactBreakClicked(player,value,id)
    return trackerPrivate.cardInteraction.artifactBreak(player,value,id,resourceCardsDetailsOpen,cardPosture,cardInSeatPlayArea,combatConfig,combatEnemyInPlay,trackerPrivate,choiceExpandedByGUID)
end

-- Player clicks always replace the one-time guess; opening the choice menu
-- alone leaves that selection and the Resource Tracker totals unchanged.
function resourceCardsChoiceClicked(player,value,id)
    return trackerPrivate.cardInteraction.choiceClicked(player,value,id,combatConfig,resourceCardsDetailsOpen,factionRewardForObject,cardPosture,cardCanPlaySideways,trackerPrivate,currentChoice,choiceCategory,combatCalcOn,combatCumbersomeActive,combatEnemyInPlay,choiceAvailable,inventorySetChoice,choiceExpandedByGUID,showChoiceButtons,selectedResourceByGUID,sideChoices,resourceCardsMoveRole,combatForgetPhysicalSourceTargets,queueSeat)
end

-- Regeneration gives Heal and an independent Ready for each application.
-- Right click cancels the link and its dependent Unit activation history.
function resourceCardsRegenerationReadyClicked(player,value,id)
    return trackerPrivate.cardInteraction.regenerationReady(player,value,id,resourceCardsDetailsOpen)
end

-- Ready sources need an active effect; a Command move alone cannot authorize reuse.
-- while the exact played choice remains Ready; physical Command movement
-- alone cannot grant a second use.
function resourceCardsReadySourceValid(sourceKey,seatPos)
    return trackerPrivate.readyPolicy.sourceValid(sourceKey,seatPos,unitResourceDefinitions,unitManaDecision,cardInSeatPlayArea,cardPosture,combatEnemyInPlay,currentChoice,choiceCategory,inventorySetChoice,trackerPrivate,sideChoices,combatConfig,selectedResourceByGUID)
end

-- Used both when a new Ready link is made and when changing card sides
-- invalidates a previously valid target.
function resourceCardsReadySourceLevelLimit(sourceKey,seatPos)
    return trackerPrivate.readyPolicy.sourceLevelLimit(sourceKey,seatPos)
end

function resourceCardsReadyTargetEligible(sourceKey,unitGUID,seatPos)
    return trackerPrivate.readyPolicy.targetEligible(sourceKey,unitGUID,seatPos)
end

function attackAssignmentReadySourceClicked(player,value,id)
    return trackerPrivate.readyPolicy.sourceClicked(player,value,id,combatEnemyInPlay,unitResourceDefinitions)
end

-- Command tokens remain spent for the entire round, even after the turn's
-- resource history is cleared. A physical Command still on a Unit must not be
-- treated as a new activation when its owner starts a later turn.
function resourceUnitsSpentCommands()
    return trackerPrivate.unitManagement.spentCommands()
end

function resourceUnitsCommandSpent(tokenGUID)
    return trackerPrivate.unitManagement.commandSpent(tokenGUID)
end

-- A legitimate Ready lifts the Command's round-long exhaustion; undoing the
-- Ready reinstates it. These are history facts, not guesses from token height.
function resourceUnitsSetCommandSpent(tokenGUID,spent)
    return trackerPrivate.unitManagement.setCommandSpent(tokenGUID,spent)
end

-- The token's GUID is its Command capacity; the owner GUID identifies the
-- Unit whose turn/round exhaustion it represents. A replacement must not
-- inherit its predecessor's spent flag, but moving the SAME Unit may not
-- erase it. Keep ownership alongside the existing round-long spent map.
function resourceUnitsCommandOwner(tokenGUID)
    return trackerPrivate.unitManagement.commandOwner(tokenGUID)
end

function resourceUnitsRecordSpentCommands(seatPos)
    return trackerPrivate.unitManagement.recordSpentCommands(seatPos)
end

-- Called once a NEW Unit owns a vacated Command position, not on token pickup.
-- Ordinary board movement is not an excuse to ready an old Unit: without an
-- approved recruit, the prior owner must truly have left every Unit Area.
function resourceUnitsAdoptCommand(tokenGUID,unitGUID,seatPos,approvedRecruit)
    return trackerPrivate.unitManagement.adoptCommand(tokenGUID,unitGUID,seatPos,approvedRecruit)
end

-- The only generic disband cleanup: retire the Unit's choices/Ready links,
-- attack arrows and token number. Do not touch the spent Command flag here;
-- only an actual newly claimed Unit may ready that Command.
function resourceUnitsRetireUnit(unitGUID)
    return trackerPrivate.unitManagement.retireUnit(unitGUID,removeChoiceButtons,choiceButtonShown,choiceExpandedByGUID)
end

-- On a manually dragged replacement card, reconcile its settled physical
-- Command column. No reset happens for the same Unit or while the previous
-- owner is still on the Unit mat.
function resourceUnitsReconcileNewUnit(unitGUID,seatPos)
    return trackerPrivate.unitManagement.reconcileNewUnit(unitGUID,seatPos)
end

-- An activation belongs to the physical Command token that started it.
-- Dropping that token away from its Unit is an undo, not a spent ability:
-- discard its saved choice and remove its buttons and tracked contribution.
-- Returning the token to the same Unit preserves its selection.
local function resourceUnitsCancelMovedCommand(tokenGUID,seatPos,targetGUID)
    return trackerPrivate.unitManagement.cancelMovedCommand(tokenGUID,seatPos,targetGUID,removeChoiceButtons,choiceExpandedByGUID)
end

-- The picked-up origin is transient; only completed activations belong in
-- saved state. A token placed back on its original Unit isn't a new play.
function resourceUnitsCommandPickedUp(playerColor,obj)
    return trackerPrivate.unitManagement.commandPickedUp(playerColor,obj,trackerPrivate)
end

function resourceUnitsCommandDropped(playerColor,obj)
    return trackerPrivate.unitManagement.commandDropped(playerColor,obj,trackerPrivate,resourceUnitsCancelMovedCommand,queueSeat,unitResourceDefinitions,trackerChoiceScores,choiceExpandedByGUID)
end

-- A Unit's choice can switch its targeting key (e.g. Shocktroops
-- Ranged 1 -> Armour -1). Retire obsolete arrow keys and calculator locks
-- immediately, keeping explicitly targeted effects whose keys stay active.
-- The next scan then auto-targets newly selected effects just like attacks.
function resourceUnitsReconcileChoiceTargets(unit,abilities,activation)
    return trackerPrivate.unitManagement.reconcileChoiceTargets(unit,abilities,activation,unitManaDecision,combatConfig,unitAbilityTargetCategory,unitAbilityTargetKey,combatAssignmentState)
end

function resourceUnitsPruneHistoricalTargets(unitGUID)
    return trackerPrivate.unitManagement.pruneHistoricalTargets(unitGUID,trackerPrivate)
end

function resourceUnitsChoiceClicked(player,value,id)
    return trackerPrivate.unitManagement.choiceClicked(player,value,id,combatConfig.moveRoleAvailable,trackerPrivate,unitManaDecision,choiceExpandedByGUID,showUnitAbilityButtons,unitManaCounts,resourceCardsMoveRole,renderSeat)
end

-- Release a temporary offered Unit without touching Command activations.
function resourceUnitsBorrowedUnitEnded(guid)
    return trackerPrivate.unitManagement.borrowedUnitEnded(guid,combatForgetPhysicalSourceTargets,removeChoiceButtons,choiceButtonShown,choiceExpandedByGUID)
end

-- Clear any remaining activations at turn end without moving Command tokens.
-- A token moved off its Unit during the turn cancels immediately on its drop.
function resourceUnitsResetTurn()
    return trackerPrivate.unitManagement.resetTurn(removeChoiceButtons,choiceExpandedByGUID,trackerPrivate)
end

-- There is one owner for Unit control rendering: the settled Resource Tracker
-- scan, after combat presence, payment, wound and site restrictions are known.
-- Token-history arrows and other callers request that scan, not an early paint.
function resourceUnitsRefreshButtons()
    return trackerPrivate.unitManagement.refreshButtons()
end

-- Reconstruct used Units from Command tokens physically sitting on their cards.
-- Command tokens in ready slots do not count as activations.
local function resourceUnitsRebuildFromTable()
    return trackerPrivate.unitManagement.rebuildFromTable(unitResourceDefinitions,trackerChoiceScores)
end

-- Explicit card choices represent player decisions rather than reconstructable table state.
-- Save only choices for cards still in the current player's play/unit areas.
trackerPrivate.copyCardSelection=function(selection,fromSave)
    return trackerPrivate.trackerLifecycle.copyCardSelection(selection,fromSave)
end

function resourceCardsChoicesSave()
    -- Preserve the primary target of each divisible resource.
    if gStates~=nil then
        local primary={}
        for key,guid in pairs(combatAssignmentState~=nil and combatAssignmentState.targets or {}) do
            if type(key)=="string" and type(guid)=="string" then primary[key]=guid end
        end
        gStates.resourceCardPrimaryTargets=primary
    end
    return trackerPrivate.trackerLifecycle.choicesSave(selectedResourceByGUID,trackerPrivate,resourceObjectKind)
end

function resourceCardsChoicesRestore()
    return trackerPrivate.trackerLifecycle.choicesRestore(function() selectedResourceByGUID={} end,function() return selectedResourceByGUID end,trackerPrivate)
end

function resourceCardsPanelChanged(open)
    return trackerPrivate.trackerLifecycle.panelChanged(open,trackerPrivate,combatConfig,combatCalcShutdown,clearAll,function() return selectedResourceByGUID end,resourceUnitsRebuildFromTable,renderSeat)
end

-- Clear the outgoing seat before changing turnNumber so rewards, overlays,
-- damage previews and locks cannot leak into the next player's combat.
function resourceCardsBeforeTurnHandoff(nextSeat)
    return trackerPrivate.trackerLifecycle.beforeTurnHandoff(nextSeat,function() selectedResourceByGUID={} end)
end

-- The Global UI is shared, but its expanded/collapsed preference belongs to a seat.
function resourceCardsAfterTurnHandoff(previousSeat)
    return trackerPrivate.trackerLifecycle.afterTurnHandoff(previousSeat)
end

-- Shared by saved-game load, first-game setup and re-expanding the panel.
-- Wait for the actual UI state rather than treating startup's collapsed XML
-- defaults as a player pressing OFF. Explicit minimization cancels this wait.
function resourceCardsOnLoad(restoringSave)
    return trackerPrivate.trackerLifecycle.onLoad(restoringSave,trackerPrivate)
end

local function resourceCardsRelevantZone(ctx)
    return trackerPrivate.objectEvents.relevantZone(ctx,resourceObjectKind,combatEnemyData)
end

-- Mark played cards while dragged, so zone callbacks cannot publish an
-- intermediate 'card absent' calculation and overwrite a chosen target.
function resourceCardsObjectPickedUp(obj)
    return trackerPrivate.objectEvents.pickedUp(obj,trackerPrivate,resourceObjectKind,cardInSeatPlayArea,combatAssignmentState,selectedResourceByGUID,cardPosture)
end

-- Restore the player's source decisions before a completed drop recalculates.
-- This is runtime-only and applies only while the original card remains on
-- the same Play Area. Deliberate sideways/flipped play can change targeting.
trackerPrivate.restorePlayCardMove=function(obj,state)
    return trackerPrivate.objectEvents.restoreMove(obj,state,cardInSeatPlayArea,selectedResourceByGUID,cardPosture,combatAssignmentState)
end

-- A card may still be falling in Y when its X/Z and rotation are final.
-- Observe those values for three frames instead of waiting for 'resting'.
trackerPrivate.finishPlayCardMove=function(obj)
    return trackerPrivate.objectEvents.finishMove(obj,trackerPrivate,queueSeat,cardInSeatPlayArea)
end

-- Native TTS Place Under (U) does not promise a pickup/drop or zone change.
-- Mark existing play sources before the action, then reconcile the target(s)
-- after TTS has applied it, including non-Card Skills and Faction Rewards.
function resourceCardsUnderAction(targets)
    return trackerPrivate.objectEvents.underAction(targets,trackerPrivate,resourceObjectKind,queueSeat)
end

function resourceCardsZoneEntered(ctx)
    return trackerPrivate.objectEvents.zoneEntered(ctx,trackerPrivate,resourceCardsRelevantZone,resourceObjectKind,queueSeat)
end

function resourceCardsZoneLeft(ctx)
    return trackerPrivate.objectEvents.zoneLeft(ctx,trackerPrivate,resourceCardsRelevantZone,resourceObjectKind,combatConfig,cardInSeatPlayArea,scheduleChoiceResetAfterPlay,queueSeat)
end


-- A late TTS object-UI refresh can clear option buttons AFTER the settled
-- tracker scan has finished. A targeted recheck repairs only genuinely lost
-- controls; unchanged buttons and combat values are never rebuilt.
trackerPrivate.cardUIRecheckSerial={}
trackerPrivate.checkCardChoicesAfterDrop=function(guid,seatPos)
    return trackerPrivate.objectEvents.checkChoicesAfterDrop(guid,seatPos,trackerPrivate,cardInSeatPlayArea,combatConfig,function() return choiceButtonShown end,queueSeat)
end

function resourceCardsObjectMoved(obj,stabilized)
    return trackerPrivate.objectEvents.objectMoved(obj,stabilized,trackerPrivate,resourceObjectKind,manaColor,queueSeat,combatEnemyData,cardInSeatPlayArea,scheduleChoiceResetAfterPlay,combatTrackedSeat,combatTrackedEnemies)
end

-- Register the remaining readying and Artifact gameplay buttons through the
-- protected public boundary for the onLoad audit and error reporter.
publishPublicUICallbacks({
    resourceCardsRegenerationReadyClicked=resourceCardsRegenerationReadyClicked,
    resourceCardsArtifactHealUnitsClicked=resourceCardsArtifactHealUnitsClicked,
    resourceCardsArtifactBreakClicked=resourceCardsArtifactBreakClicked,
    resourceCardsArtifactGrailFameClicked=resourceCardsArtifactGrailFameClicked,
    resourceCardsCombatWoundsSkipChanged=resourceCardsCombatWoundsSkipChanged
})

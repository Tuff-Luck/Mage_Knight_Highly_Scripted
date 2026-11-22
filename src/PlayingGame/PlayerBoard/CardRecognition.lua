-- The physical play area supplies estimated resources to the Resource Tracker.
-- Runtime-only observations never overwrite the saved manual +/- adjustments.
resourceCardScanBySeat={}
local trackerPrivate={}
-- Small module-private state tables live here to keep sufficient headroom
-- beneath Lua 5.2's 200-active-local limit when this module is bundled.
trackerPrivate.generation={}
-- One settling watcher per object and one render request per seat. A moving
-- crystal must not block a second, already-settled card from updating.
trackerPrivate.pendingSeatSettles={}
trackerPrivate.pendingSeatRender={}
-- Opt-in ring trace for reproducing a stalled tracker without permanent log spam.
-- Use the admin chat commands !trackertrace on/status/dump/off.
trackerPrivate.traceEnabled=false
trackerPrivate.traceLines={}
trackerPrivate.traceSequence=0
trackerPrivate.traceEvent=function(event,seat,guid,detail)
    if not trackerPrivate.traceEnabled then return end
    trackerPrivate.traceSequence=trackerPrivate.traceSequence+1
    local line=string.format("%04d %s seat=%s guid=%s %s",
        trackerPrivate.traceSequence,tostring(event),tostring(seat or "-"),
        tostring(guid or "-"),tostring(detail or ""))
    local lines=trackerPrivate.traceLines
    lines[#lines+1]=line
    if #lines>180 then table.remove(lines,1) end
end

function resourceCardsTraceCommand(command,playerColor)
    command=command or "status"
    if command=="on" then
        trackerPrivate.traceEnabled=true
        trackerPrivate.traceLines={}
        trackerPrivate.traceSequence=0
        trackerPrivate.traceEvent("trace.enabled")
    elseif command=="off" then
        trackerPrivate.traceEvent("trace.disabled")
        trackerPrivate.traceEnabled=false
    elseif command=="dump" then
        log("[TrackerTrace] BEGIN "..tostring(#trackerPrivate.traceLines).." events")
        for _,line in ipairs(trackerPrivate.traceLines) do
            log("[TrackerTrace] "..line)
        end
        log("[TrackerTrace] END")
    elseif command~="status" then
        return false
    end
    local movements={}
    for guid,movement in pairs(trackerPrivate.playCardMovements or {}) do
        local obj=getObjectFromGUID(guid)
        local held=obj~=nil and obj.held_by_color or nil
        local smooth=obj~=nil and obj.isSmoothMoving~=nil and obj.isSmoothMoving() or false
        movements[#movements+1]=guid.."(seat="..tostring(movement.seatPos)
            ..",held="..tostring(held)..",smooth="..tostring(smooth)
            ..",watch="..tostring(movement.releasing)
            ..",samples="..tostring(movement.samples)..")"
    end
    table.sort(movements)
    local seat=turnOrder~=nil and gStates~=nil
        and turnOrder[gStates.turnNumber]~=nil
        and turnOrder[gStates.turnNumber].seatPos or nil
    local pending=seat~=nil and trackerPrivate.pendingSeatSettles[seat] or nil
    local pendingCount=0
    for _ in pairs(pending or {}) do pendingCount=pendingCount+1 end
    local status="Tracker trace "..(trackerPrivate.traceEnabled and "ON" or "OFF")
        .."; panel="..tostring(resourceCardsPanelOpen())
        .."; seat="..tostring(seat)
        .."; renderQueued="..tostring(seat~=nil and trackerPrivate.pendingSeatRender[seat] or nil)
        .."; settleWaits="..pendingCount
        .."; movements="..(#movements>0 and table.concat(movements,", ") or "none")
        .."; events="..#trackerPrivate.traceLines
    log("[TrackerTrace] "..status)
    if playerColor~=nil then
        broadcastToColor(status,playerColor,{0.7,0.9,1})
    end
    return true
end
local shown={}
-- Mana crystal figurines are still read for powering cards, but should never
-- receive Resource Tracker highlights. Avoid repeated highlightOff calls.
trackerPrivate.crystalHighlightCleared={}
trackerPrivate.bySeat={}
-- Known play sources survive transient shallow-zone exits while a card is
-- lifted or still falling above the mat. Rebuilt from entries/scans, not saved.
trackerPrivate.playCandidatesBySeat={}
-- Protect explicit options and targets from half-complete relocation scans.
trackerPrivate.playCardMovements={}
trackerPrivate.playCandidateKind=function(kind)
    return kind=="card" or kind=="skill" or kind=="factionReward"
end
-- Initial guesses and explicit player choices are transient, never saved in gStates or JSON.
local selectedResourceByGUID={}
-- Retain the chosen crystal-pair Attack after Sacrifice converts the pairs to mana.
-- Uses combatConfig.sacrificeCastPairs to avoid Lua 5.2's 200-local module limit.
-- A choice lasts for one play; delayed departure checks must not race a return.
trackerPrivate.choiceResetGenerationByGUID={}
-- Display state is separate from player selections. Picks/drops may clear the
-- buttons, but the chosen resource stays until the script reloads.
local choiceExpandedByGUID={}
local choiceButtonShown={}
local unitManaDecision
local factionRewardForObject
-- Highlights show how confidently the tracker understands the selected effect.
-- Blue is a deliberate neutral/not-calculated state, not an illegal-play warning.
-- Purple takes precedence when objects are linked; brightness indicates power.
trackerPrivate.palette={
    green={{0.10,0.55,0.14},{0.35,1.00,0.38}},
    yellow={{0.62,0.48,0.08},{1.00,0.94,0.19}},
    blue={{0.08,0.34,0.64},{0.26,0.66,1.00}},
    purple={{0.47,0.19,0.62},{0.92,0.43,1.00}}
}
-- Distinguish elemental and physical damage. Otherwise a Ranged Fire Attack
-- would be incorrectly added to the Physical Ranged field.
trackerPrivate.totalsKeys={move=true,ranged=true,siege=true,attack=true,block=true,influence=true,healing=true,
    rangedFire=true,rangedIce=true,rangedColdFire=true,rangedPsychic=true,
    siegeFire=true,siegeIce=true,siegeColdFire=true,siegePsychic=true,
    attackFire=true,attackIce=true,attackColdFire=true,attackPsychic=true,
    blockFire=true,blockIce=true,blockColdFire=true,blockPsychic=true}

-- Catalog is defined once in UnitResources.lua and keyed by card GUID.
local unitResourceDefinitions=unitResourceDefinitions
-- Full-size Artifacts use an explicit, saved Break toggle instead of their physical back.
-- An old face-down play is imported as Break on its first scan; an explicit
-- false always overrides that legacy interpretation. Half Banners are spent
-- Unit attachments, never independently broken Artifacts.
function resourceCardsArtifactBroken(guid,card)
    local data=gameCards~=nil and gameCards[guid] or nil
    if data==nil or data.cardType~="Artifact" or data.full~=nil then return false end
    local state=gStates~=nil and gStates.artifactBreaks or nil
    if type(state)=="table" and type(state[guid])=="boolean" then return state[guid] end
    local obj=card or getObjectFromGUID(guid)
    if obj~=nil and obj.is_face_down==true then
        if gStates~=nil then
            gStates.artifactBreaks=gStates.artifactBreaks or {}
            gStates.artifactBreaks[guid]=true
        end
        return true
    end
    return false
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
-- Only mana objects actually moved by players are candidates for extra Unit
-- payment checks. A stacked crystal can sit above the Unit scripting zone,
-- but its settled physical position still pays that Unit's ability.
trackerPrivate.unitManaCandidatesBySeat={}
-- Rebuilt with the live Unit layout for each Resource Tracker scan.
-- Existing Command tokens and Wounds suppress Unit highlights regardless of
-- whether an activated ability contributes resources this turn.
trackerPrivate.unitHighlightBlocked={}
-- Reuse a single immutable terrain modifier. Constructing a new table on
-- every scan would make the terrain-effect comparison think the cost changed
-- even when Foresters' chosen ability is unchanged.
trackerPrivate.forestersTerrainModifier={mode="reduce",
    terrains={forest=true,hills=true,swamp=true},amount=1,minimum=0}

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
combatConfig.conversionState={}
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
combatConfig.columns={Name=120,Armour=55,Traits=150,Attacks=105,Offence=130,Result=170}
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

combatConfig.transformFamilies={attack=true,ranged=true,siege=true}
combatConfig.elementSuffixes={"ColdFire","Fire","Ice","Psychic"}

-- The single place that maps a resource key through active attack transformations (Altem Mages).
-- Cold Fire replaces the element; Siege replaces the family and keeps the element. Block is never changed.
function resourceCardsTransformedKey(key,transform)
    if transform==nil or (not transform.coldFire and not transform.siege) then return key end
    local family,suffix=key,""
    for _,candidate in ipairs(combatConfig.elementSuffixes) do
        if key:sub(-#candidate)==candidate and #key>#candidate then
            family,suffix=key:sub(1,#key-#candidate),candidate
            break
        end
    end
    if combatConfig.transformFamilies[family]~=true then return key end
    if transform.siege then family="siege" end
    if transform.coldFire then suffix="ColdFire" end
    return family..suffix
end

-- A primary Move/Psychic arrow owns all the points left on that physical
-- source; additional arrows transfer individual points from that same pool.
-- While such an explicit allocation exists, conversions must use OTHER
-- unassigned sources. The player can remove/retarget an arrow to free its pool.
local function combatConversionReserved(key,amount,field)
    if amount<=0 or combatAssignmentState.explicit[key]~=true then return 0 end
    local target=combatAssignmentState.targets[key]
    if target==nil then return 0 end
    -- An ordinary Attack target does not reserve unrelated Influence. Only
    -- an actual Cumbersome/Psychic target owns the respective shared pool.
    if field=="move" and resourceCardsCombatTargetAcceptsMove~=nil
        and resourceCardsCombatTargetAcceptsMove(target) then return amount end
    if field=="influence" and combatConfig.hasPsychicAttack~=nil
        and combatConfig.hasPsychicAttack(target) then return amount end
    return 0
end

-- Player-set conversions spend only unassigned Move/Influence. A card already
-- assigned to Cumbersome or Psychic Block must not be silently cannibalised.
combatConfig.conversionFor=function(seat,kind)
    if seat==nil then return nil,0,false,nil end
    local scan=seat~=nil and resourceCardScanBySeat[seat] or nil
    local cards=scan~=nil and scan.cards or nil
    local guid=kind=="agility" and "878d92" or "8c3de6"
    local active=cards~=nil and cards[guid] or nil
    local valid=active~=nil and active.combatConversion==kind
        and active.resources~=nil
    local state=combatConfig.conversionState[seat]
    if state==nil then
        state={}
        combatConfig.conversionState[seat]=state
    end
    -- Normalise a missing choice before any counter is read.
    local choice=state[kind] or {attack=0,ranged=0,block=0,element="F"}
    state[kind]=choice
    local available=0
    if valid and cards~=nil then
        for sourceGUID,record in pairs(cards) do
            local field=kind=="agility" and "move" or "influence"
            local amount=math.max(0,tonumber(record.resources~=nil and record.resources[field]) or 0)
            if kind=="agility" and resourceCardsMoveRole(sourceGUID,true)~="combat" then
                amount=0
            end
            -- A manually targeted source retains its entire remaining pool.
            -- Split-target cards put Move/Influence on their Block source.
            local sourceKey=record.splitTargets~=nil and (sourceGUID.."#block")
                or sourceGUID
            available=available+math.max(0,
                amount-combatConversionReserved(sourceKey,amount,field))
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
                    local sourceName=cardData~=nil and cardData.name or nil
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
                local spendable=math.max(0,value-combatConversionReserved(source.key,value,field))
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

local function combatNearestEnemyGUID(source,entries,eligible)
    local sourceObject=getObjectFromGUID(source.guid)
    local sourcePosition=sourceObject~=nil and sourceObject.getPosition()
        or source.retiredUnitPosition
    if sourcePosition==nil then return nil end
    local nearestGUID,nearestDistance=nil,nil
    for _,entry in ipairs(entries) do
        local enemy=getObjectFromGUID(entry.guid)
        local forkDuplicate=false
        if source.forkedLightning then
            for key,target in pairs(combatAssignmentState.targets or {}) do
                if key~=source.key and key:match("^d01b70#fork%d+$")
                    and target==entry.guid then forkDuplicate=true break end
            end
        end
        if enemy~=nil and not forkDuplicate and entry.guid~=source.possessExclude
            and (eligible==nil or eligible(entry.guid))
            and (not entry.attackOnly
            or source.ranged+source.siege+source.attack==0) then
            local position=enemy.getPosition()
            local dx,dz=position[1]-sourcePosition[1],position[3]-sourcePosition[3]
            local distance=dx*dx+dz*dz
            if nearestDistance==nil or distance<nearestDistance
                or (distance==nearestDistance and entry.guid<nearestGUID) then
                nearestGUID,nearestDistance=entry.guid,distance
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

local function combatEnemyHasTrait(data,perks,key)
    return data[key]==true or (perks~=nil and perks[key]==true)
end

local function combatEnemyFortificationCount(data,perks)
    if combatEnemyHasTrait(data,perks,"unfortified") then return 0 end
    return (data.fortified==true and 1 or 0)
        +(perks~=nil and perks.fortified==true and 1 or 0)
        +(perks~=nil and perks.wallFortified==true and 1 or 0)
end

-- owner/slot identify the physical token carrying each attack, so its damage button can find it again.
local function combatEnemyPrintedAttacks(data,perks,stripAbilities,ownerGUID)
    local attacks={}
    local base=type(data.attack)=="table" and data.attack or {}
    local override=perks~=nil and type(perks.attack)=="table" and perks.attack or {}
    local elemental=perks~=nil and perks.elemental==true
    local boost=perks~=nil and tonumber(perks.boost) or 0
    local boostUsed=false
    local swift=not stripAbilities and combatEnemyHasTrait(data,perks,"swiftness")
    local brutal=not stripAbilities and combatEnemyHasTrait(data,perks,"brutal")
    local cumbersome=not stripAbilities and combatEnemyHasTrait(data,perks,"cumbersome")
    local poison=not stripAbilities and combatEnemyHasTrait(data,perks,"poison")
    local paralyse=not stripAbilities and combatEnemyHasTrait(data,perks,"paralyse")
    local assassination=not stripAbilities and combatEnemyHasTrait(data,perks,"assassination")
    for _,attackType in ipairs(combatConfig.attackTypes) do
        local values=override[attackType.key] or base[attackType.key]
        for _,printedValue in ipairs(type(values)=="table" and values or {}) do
            local bonus=elemental and (attackType.key=="IF" and 1 or 2) or 0
            if not boostUsed and boost~=0 then bonus=bonus+boost boostUsed=true end
            -- Psychic Attacks never inherit offensive abilities (Apocalypse Dragon).
            local psychic=attackType.key=="M"
            attacks[#attacks+1]={key=attackType.key,label=attackType.label,
                value=math.max(0,printedValue+bonus),block=attackType.block,
                swift=not psychic and swift,brutal=not psychic and brutal,
                cumbersome=not psychic and cumbersome,poison=not psychic and poison,
                paralyse=not psychic and paralyse,assassination=not psychic and assassination,
                owner=ownerGUID,slot=#attacks+1}
        end
    end
    return attacks
end

-- Know Your Prey changes exactly one printed attack's element. This does not
-- affect other attacks (including ones belonging to a separate summoned token).
combatConfig.convertPreyAttacks=function(attacks,effect)
    for _,conversion in ipairs(effect~=nil and effect.attackConversions or {}) do
        local attack=attacks[conversion.slot]
        if attack~=nil and attack.key==conversion.from then
            for _,kind in ipairs(combatConfig.attackTypes) do
                if kind.key==conversion.to then
                    attack.key=kind.key
                    attack.label=kind.label
                    attack.block=kind.block
                    break
                end
            end
        end
    end
end

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

-- A summoner with no token out yet counts as one 0 attack with no abilities per token still to come.
-- Effects stored against a summoned token apply to that token's attacks while it replaces its summoner.
local function combatSummonedAttackPrevented(summoned)
    local effect=summoned.effect
    return effect~=nil and (effect.noAttack==true or effect.destroy==true or (effect.noAttackUnfortified==true
        and (combatEnemyFortificationCount(summoned.data,summoned.perks)==0
            or effect.removeFortify==true)))
end

-- An Attack reduction modifies one printed Attack, not every Attack on a multi-attack enemy.
-- When several Attacks exist, use the currently strongest one, with stable order on ties.
-- All reductions are rebuilt from the original printed values on every scan (never cumulative).
local function combatOrderedReductions(effect)
    local ordered={}
    for _,reduction in ipairs(effect~=nil and effect.attackReductions or {}) do
        ordered[#ordered+1]=reduction
    end
    table.sort(ordered,function(a,b)
        if a.amount~=b.amount then return a.amount>b.amount end
        -- A card can reduce two attacks on the same enemy. Keep its
        -- separate -2 effects in a predictable order so each one can be
        -- selected independently with the calculator's attack-cycle control.
        if a.source~=b.source then return tostring(a.source)<tostring(b.source) end
        return tostring(a.id or a.source)<tostring(b.id or b.source)
    end)
    return ordered
end

local function combatApplyAttackReductions(attacks,effect,ownerGUID,chosenAttacks)
    for _,reduction in ipairs(combatOrderedReductions(effect)) do
        local sourceKey=reduction.id or tostring(reduction.source)
        local choice=chosenAttacks~=nil and chosenAttacks[sourceKey] or nil
        local target=choice~=nil and attacks[choice] or nil
        if target~=nil and (target.pending or target.cancelled
            or (ownerGUID~=nil and target.owner~=ownerGUID)) then
            target=nil
        end
        -- Stale selections fall back to the strongest currently legal attack.
        if target==nil then
            for _,attack in ipairs(attacks) do
                if not attack.pending and not attack.cancelled
                    and (ownerGUID==nil or attack.owner==ownerGUID)
                    and (attack.value>0 or reduction.amount<0
                        or reduction.stripAbilities or reduction.cancelAttack)
                    and (target==nil or attack.value>target.value) then
                    target=attack
                end
            end
        end
        if target~=nil then
            if reduction.cancelAttack then target.cancelled=true end
            target.value=math.max(0,target.value-reduction.amount)
            if reduction.stripAbilities then
                for _,trait in ipairs({"swift","brutal","cumbersome","poison",
                    "paralyse","assassination"}) do target[trait]=false end
                target.abilitiesStripped=true
            end
            if reduction.firstDamageUnit~=nil then target.firstDamageUnit=reduction.firstDamageUnit end
        end
    end
end

local function combatEnemyAttacks(entry,includeCancelled)
    if entry.noAttack or entry.destroyed then return {} end
    local attacks=combatEnemyPrintedAttacks(entry.data,entry.perks,entry.removeAbilities,entry.guid)
    if entry.data.monsters~=nil then
        for _,summoned in ipairs(entry.summoned or {}) do
            if not combatSummonedAttackPrevented(summoned)
                and not (entry.summonedDestroyed~=nil
                    and entry.summonedDestroyed[summoned.guid]==true) then
                local strip=summoned.effect~=nil and summoned.effect.removeAbilities==true
                local summonedAttacks=combatEnemyPrintedAttacks(summoned.data,summoned.perks,strip,summoned.guid)
                combatConfig.convertPreyAttacks(summonedAttacks,summoned.effect)
                combatApplyAttackReductions(summonedAttacks,summoned.effect,summoned.guid)
                if summoned.effect~=nil and summoned.effect.grantCumbersome==true then
                    for _,attack in ipairs(summonedAttacks) do
                        if attack.key~="M" and not attack.abilitiesStripped then attack.cumbersome=true end
                    end
                end
                for _,attack in ipairs(summonedAttacks) do attacks[#attacks+1]=attack end
            end
        end
        for _=1,math.max(0,#entry.data.monsters-#(entry.summoned or {})) do
            attacks[#attacks+1]={key="P",label="Summon",value=0,block="block",pending=true}
        end
    end
    -- Apply the summoner's changes only to its own printed attacks. Changes
    -- aimed at a summoned monster were already applied to that token above.
    if entry.effect~=nil and #attacks>0 then
        local ownAttacks={}
        for _,attack in ipairs(attacks) do
            if attack.owner==entry.guid then ownAttacks[#ownAttacks+1]=attack end
        end
        combatConfig.convertPreyAttacks(ownAttacks,entry.effect)
    end
    combatApplyAttackReductions(attacks,entry.effect,nil,combatReductionAttackChoice[entry.guid])
    if entry.effect~=nil and entry.effect.grantCumbersome==true then
        for _,attack in ipairs(attacks) do
            if attack.owner==entry.guid and attack.key~="M"
                and not attack.abilitiesStripped then attack.cumbersome=true end
        end
    end
    -- Keep original attack positions for the attack-cycle selector; actual
    -- combat omits precisely the cancelled attack and all its abilities.
    if not includeCancelled then
        for i=#attacks,1,-1 do
            if attacks[i].cancelled then table.remove(attacks,i) end
        end
    end
    return attacks
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

-- "Unfortified" Unit abilities (Illusionists) only target enemies whose
-- effective Fortification is zero. A separate active Remove Fortification
-- effect qualifies; the printed Fortified and Wall Fortified traits do not.
-- Keep the rule source-key based so the target button and auto scan agree.
function resourceCardsUnitTargetRequiresUnfortified(sourceKey)
    if type(sourceKey)~="string" then return false end
    local guid,index=sourceKey:match("^([^#]+)#effect(%d+)$")
    if guid==nil then guid,index=sourceKey:match("^([^#]+)#use%d+#effect(%d+)$") end
    local abilities=guid~=nil and unitResourceDefinitions~=nil
        and unitResourceDefinitions[guid] or nil
    local ability=abilities~=nil and abilities[tonumber(index)] or nil
    return ability~=nil and ability.enemyEffect~=nil
        and ability.enemyEffect.noAttackUnfortified==true
end

function resourceCardsEnemyEffectivelyUnfortified(guid,effects,ignoreSiteFortifications)
    local data,mode=combatEnemyData(guid)
    if data==nil or mode=="attackOnly" or data.attackOnly==true then return false end
    local perks=gStates~=nil and gStates.monsterPerks~=nil
        and gStates.monsterPerks[guid] or nil
    local effect=effects~=nil and effects[guid] or combatEffectOf(guid)
    local fortified=combatEnemyFortificationCount(data,perks)
    -- Demolish removes site/wall Fortification, but not printed Fortified.
    if ignoreSiteFortifications==true and fortified>0 and perks~=nil then
        fortified=math.max(0,fortified
            -(perks.fortified==true and 1 or 0)
            -(perks.wallFortified==true and 1 or 0))
    end
    if effect~=nil and effect.removedPrinted~=nil
        and effect.removedPrinted.fortified==true and data.fortified==true
        and not combatEnemyHasTrait(data,perks,"unfortified") then
        fortified=math.max(0,fortified-1)
    end
    return fortified==0 or (effect~=nil and effect.removeFortify==true)
end

function resourceCardsCombatTargetRejectMessage(sourceKey,targetGUID)
    local seat=combatAssignmentActiveSeat()
    local scan=seat~=nil and resourceCardScanBySeat[seat] or nil
    local record=scan~=nil and scan.cards[sourceKey] or nil
    if record~=nil and record.possessEnemyGUID==targetGUID then
        return "Possess cannot use an enemy's own Attack against itself."
    end
    if resourceCardsUnitTargetRequiresUnfortified(sourceKey) then
        return "Illusionists can only target an unfortified enemy."
    end
    if apocalypseDragonGroundHeadNameForGUID~=nil
        and apocalypseDragonGroundHeadNameForGUID(targetGUID)=="Control" then
        return "The Control head cannot be attacked."
    end
    if sourceKey=="6a33c1" then
        return "Curse's Armour reduction cannot target an attack-only reminder."
    end
    return "Only Block/Move or attack reductions can target a reminder."
end

-- Reminders accept only Block/Move and enemy-attack effects, not attacks
-- against Armour. Unknown source keys represent effect-only targeting links.
function resourceCardsCombatTargetAcceptsSource(sourceKey,targetGUID)
    -- Committed pre-Damage Unit resources are historical. Keep the enemy
    -- originally attacked, but never let a destroyed Unit retarget them.
    local ledger=gStates~=nil and gStates.combatWoundApplication or nil
    for _,sources in pairs(ledger~=nil and ledger.retiredUnitSources or {}) do
        for _,source in ipairs(sources) do
            if source.key==sourceKey then
                return source.retiredTarget==targetGUID
            end
        end
    end
    local data=combatEnemyData(targetGUID)
    if data==nil then return false end
    -- Post-Damage companion sources are Attack-only. Their generated keys do
    -- not appear in the ordinary live source list, so reject attack-only
    -- reminder tokens explicitly (including the Dragon's Control head).
    if type(sourceKey)=="string" and sourceKey:match("#postDamage$")
        and (data.attackOnly==true
            or (apocalypseDragonGroundHeadNameForGUID~=nil
                and apocalypseDragonGroundHeadNameForGUID(targetGUID)=="Control")) then
        return false
    end
    local seat=combatAssignmentActiveSeat()
    local scan=seat~=nil and resourceCardScanBySeat[seat] or nil
    local record=scan~=nil and scan.cards[sourceKey] or nil
    if record~=nil and record.possessEnemyGUID==targetGUID then return false end
    if apocalypseDragonGroundHeadNameForGUID~=nil
        and apocalypseDragonGroundHeadNameForGUID(targetGUID)=="Control" then
        local effectSource=combatConfig.effectSources[sourceKey]
        if effectSource~=nil then return effectSource.arrow~="armour" end
        for _,source in ipairs(combatAssignmentSources(seat)) do
            if source.key==sourceKey then
                return source.ranged+source.siege+source.attack==0
            end
        end
        return sourceKey~="6a33c1"
    end
    if resourceCardsUnitTargetRequiresUnfortified(sourceKey) then
        local seat=combatAssignmentActiveSeat()
        local scan=seat~=nil and resourceCardScanBySeat~=nil
            and resourceCardScanBySeat[seat] or nil
        return resourceCardsEnemyEffectivelyUnfortified(targetGUID,
            scan~=nil and scan.enemyEffects or nil,
            scan~=nil and scan.ignoreSiteFortifications==true)
    end
    if type(sourceKey)=="string" and sourceKey:match("^d01b70#fork%d+$") then
        if data.attackOnly==true then return false end
        for key,target in pairs(combatAssignmentState.targets or {}) do
            if key~=sourceKey and key:match("^d01b70#fork%d+$")
                and target==targetGUID then return false end
        end
    end
    -- Explosive Bolt's follow-up reduces Armour, never reminder Attack.
    if type(sourceKey)=="string" and sourceKey:match("#explosiveAttack$") then
        return data.attackOnly~=true
    end
    if (sourceKey=="4ac9f6" or sourceKey=="19daf9") and data.monsters~=nil then
        return false -- Nature's Vengeance targets a summoned monster, never its Summoner.
    end
    if data.attackOnly~=true then return true end
    local effectSource=combatConfig.effectSources[sourceKey]
    if effectSource~=nil then return effectSource.arrow~="armour" end
    -- An Attack-only reminder has no Armour to reduce. Curse's Attack option
    -- can still target its attack, but its Armour option cannot.
    if sourceKey=="6a33c1" then
        local saved=selectedResourceByGUID[sourceKey]
        if saved~=nil and saved.effect=="armour" then return false end
    end
    for _,source in ipairs(combatAssignmentSources(combatAssignmentActiveSeat())) do
        if source.key==sourceKey then
            return source.ranged+source.siege+source.attack==0
        end
    end
    return true
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

-- Orange arrows aim at armour; blue arrows (Block, Move) affect an enemy attack.
local function combatSourceArrowKind(source)
    if source.ranged+source.siege+source.attack>0 then return "armour" end
    return "attack"
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

local function combatEnemyResists(data,perks,attackType)
    if attackType=="P" then return combatEnemyHasTrait(data,perks,"pResist") end
    if attackType=="F" then return combatEnemyHasTrait(data,perks,"fResist") end
    if attackType=="I" then return combatEnemyHasTrait(data,perks,"iResist") end
    -- Cold Fire is only resisted by an enemy with both Fire and Ice Resistance.
    if attackType=="IF" then
        -- A group resists Cold Fire only if one individual member has both traits.
        -- The ordinary group resistance flags are merged independently.
        if data~=nil and data.coldFireResist~=nil then return data.coldFireResist==true end
        return combatEnemyHasTrait(data,perks,"fResist")
            and combatEnemyHasTrait(data,perks,"iResist")
    end
    return combatEnemyHasTrait(data,perks,"mResist")
end

-- Groups are {sources=,category=}. The resisted part of one phase's attack is
-- totalled first and halved once, rounding down.
local function combatAttackTotal(groups,data,perks,phase)
    local normal,resisted=0,0
    for _,group in ipairs(groups) do
        for _,source in ipairs(group.sources) do
            if not (source.dueling and source.duelingEligible==false
                and group.category~="block") then
                for _,attackType in ipairs(combatConfig.attackTypes) do
                    local value=tonumber(source.resources[attackType[group.category]]) or 0
                    if phase=="range" and combatConfig.artifactCombat.bow then
                        local modeR=combatConfig.bowSourceModes[source.key.."#ranged"] or "double"
                        local modeS=combatConfig.bowSourceModes[source.key.."#siege"] or "none"
                        if group.category=="ranged" then
                            if modeR=="siege" then value=0
                            else value=value*2 end
                            if modeS=="ranged" then
                                value=value+2*(tonumber(source.resources[attackType.siege]) or 0)
                            end
                        elseif group.category=="siege" then
                            if modeS=="ranged" then value=0 end
                            if modeR=="siege" then
                                value=value+(tonumber(source.resources[attackType.ranged]) or 0)
                            end
                        end
                    end
                    if value>0 then
                        -- Sword doubles every physical contribution in the
                        -- Attack phase, including physical Unit and Skill effects.
                        -- An Arcane Immune enemy keeps its printed Resistance.
                        if phase=="attack" and combatConfig.artifactCombat.sword
                            and attackType.key=="P" then
                            value=value*2
                        end
                        -- Bow's Ranged double only applies in the Ranged/Siege
                        -- phase. The later Attack phase is ordinary Attack.
                        local resistant=combatEnemyResists(data,perks,attackType.key)
                        if resistant and attackType.key=="P"
                            and combatConfig.artifactCombat.sword
                            and not combatEnemyHasTrait(data,perks,"arcaneImmunity") then
                            resistant=false
                        end
                        if resistant then resisted=resisted+value
                        else normal=normal+value end
                    end
                end
            end
        end
    end
    return normal+math.floor(resisted/2)
end

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
    if trackerPrivate.combatPanelAttributes[key]==value then return end
    trackerPrivate.combatPanelAttributes[key]=value
    UI.setAttribute(id,attribute,value)
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
        combatPanelSetAttribute(id.."Image","image",icon)
        combatPanelSetAttribute(id.."Image","rectAlignment","MiddleCenter")
        combatPanelSetAttribute(id.."Image","offsetXY","0 0")
        combatPanelSetAttribute(id.."Image","width","24")
        combatPanelSetAttribute(id.."Image","height","24")
        combatPanelSetAttribute(id.."Image","preserveAspect","true")
        combatPanelSetAttribute(id.."Amount","text",tostring(amount))
        combatPanelSetAttribute(id.."Amount","rectAlignment","MiddleCenter")
        combatPanelSetAttribute(id.."Amount","offsetXY","0 0")
        combatPanelSetAttribute(id.."Amount","width","24")
        combatPanelSetAttribute(id.."Amount","height","24")
        combatPanelSetAttribute(id.."Amount","preferredHeight","24")
        combatPanelSetAttribute(id.."Amount","alignment","MiddleCenter")
        combatPanelSetAttribute(id.."Amount","fontSize","18")
        combatPanelSetAttribute(id.."Amount","fontStyle","Bold")
        combatPanelSetAttribute(id.."Amount","color",textColor or "White")
        combatPanelSetAttribute(id.."Amount","outline","rgb(0,0,0)")
        combatPanelSetAttribute(id.."Amount","outlineSize","1 -1")
        combatPanelSetAttribute(id,"preferredWidth","24")
        combatPanelSetAttribute(id,"preferredHeight","26")
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

-- Chooses which Block resources and Move reductions stop which attacks of one enemy so the least damage
-- is taken. Every Block resource is used by at most one attack. Move only reduces Cumbersome attacks,
-- one point each, and the reduction stands even when the rest of the attack cannot be blocked.
-- Ties prefer fewer Block resources, then less Move. Returns one {mask,reduction,blocked} per attack.
-- Exact Block allocation without the old 12-item/bitmask limit.
-- States track each attack's useful contribution in half-points, so inefficient
-- Blocks round down only once per attack. Matching states keep the fewest spent
-- resources; a point above an attack's threshold has no additional value.
local function combatBlockLegal(attack,item)
    return item.key~="blockPsychic" or attack.key=="M"
end

-- Share one efficiency rule between the optimiser, displayed Block totals,
-- and the colour assigned to an inefficient Block icon.
local function combatBlockEfficient(attack,item)
    return (combatConfig.COMBAT_EFFICIENT_BLOCKS[attack.key] or {})[item.key]==true
        or (attack.key=="M" and item.source.heroPsychicBlock==true
            and item.key~="blockPsychic")
end

local function combatSolveBlocks(attacks,items,movePool)
    table.sort(items,function(a,b)
        if a.value~=b.value then return a.value>b.value end
        if a.source.key~=b.source.key then return a.source.key<b.source.key end
        if a.key~=b.key then return a.key<b.key end
        return (a.part or 0)<(b.part or 0)
    end)
    local targets={}
    local initial={}
    for index,attack in ipairs(attacks) do
        targets[index]=2*attack.value*(attack.swift and 2 or 1)
        initial[index]=0
    end
    local states={["0"]={points=initial,spent=0,route=""}}
    for _,item in ipairs(items) do
        -- Type efficiency and Swiftness are constant for this item, not per DP state.
        local options={}
        for index,attack in ipairs(attacks) do
            if targets[index]>0 and combatBlockLegal(attack,item) then
                local amount=item.value*(attack.swift and item.swiftDouble and 2 or 1)
                local efficient=combatBlockEfficient(attack,item)
                local contribution=amount*(efficient and 2 or 1)
                if contribution>0 then options[#options+1]={index=index,points=contribution} end
            end
        end
        local nextStates={}
        local function retain(points,spent,route)
            local key=table.concat(points,",")
            local prior=nextStates[key]
            if prior==nil or spent<prior.spent then
                nextStates[key]={points=points,spent=spent,route=route}
            end
        end
        for _,state in pairs(states) do
            retain(state.points,state.spent,state.route..string.char(64))
            for _,option in ipairs(options) do
                local index=option.index
                if state.points[index]<targets[index] then
                    local points={}
                    for j=1,#attacks do points[j]=state.points[j] end
                    points[index]=math.min(targets[index],points[index]+option.points)
                    retain(points,state.spent+1,state.route..string.char(64+index))
                end
            end
        end
        states=nextStates
    end
    local bestScore,bestState,bestReductions=nil,nil,nil
    -- Move allocation is independent of which individual Block cards supplied
    -- the totals. Evaluate it with a small memoized knapsack for each state.
    local usefulMove=0
    for _,attack in ipairs(attacks) do
        if attack.cumbersome then usefulMove=usefulMove+attack.value end
    end
    local cap=math.min(math.max(0,movePool),usefulMove)
    local noReductions={}
    for _,state in pairs(states) do
        local score,reductions
        if cap==0 then
            -- No Move allocated: score Block totals directly without a per-state knapsack.
            local damage=0
            for index,attack in ipairs(attacks) do
                if state.points[index]<targets[index] then
                    damage=damage+(attack.damageValue or attack.value)*(attack.brutal and 2 or 1)
                end
            end
            score=damage*1000000
            reductions=noReductions
        else
            local memo,chosen={},{}
            local function scoreMoves(index,remaining)
                if index>#attacks then return 0 end
                local key=index..":"..remaining
                if memo[key]~=nil then return memo[key] end
                local attack=attacks[index]
                local maxReduction=attack.cumbersome and math.min(remaining,attack.value) or 0
                local best,bestReduction=math.huge,0
                for reduction=0,maxReduction do
                    local leftover=attack.value-reduction
                    local threshold=2*leftover*(attack.swift and 2 or 1)
                    local blocked=leftover<=0 or state.points[index]>=threshold
                    local damage=blocked and 0 or math.max(0,(attack.damageValue or attack.value)-reduction)*(attack.brutal and 2 or 1)
                    local optionScore=damage*1000000+reduction+scoreMoves(index+1,remaining-reduction)
                    if optionScore<best then best,bestReduction=optionScore,reduction end
                end
                memo[key]=best
                chosen[key]=bestReduction
                return best
            end
            score=scoreMoves(1,cap)
            reductions={}
            local remaining=cap
            for index=1,#attacks do
                local reduction=chosen[index..":"..remaining] or 0
                reductions[index]=reduction
                remaining=remaining-reduction
            end
        end
        score=score+state.spent*100
        if bestScore==nil or score<bestScore then
            bestScore,bestState,bestReductions=score,state,reductions
        end
    end
    -- Every DP state keeps an unused-item transition, so a winner should always
    -- exist. If none survives, conservatively report no Block/Move allocation.
    local planState=bestState or {points=initial,route=string.rep("@",#items)}
    local planReductions=bestReductions or {}
    local plan,used={},{}
    for index,attack in ipairs(attacks) do
        local reduction=planReductions[index] or 0
        local required=2*(attack.value-reduction)*(attack.swift and 2 or 1)
        plan[index]={used={},reduction=reduction,
            blocked=attack.value-reduction<=0 or planState.points[index]>=required}
    end
    for index=1,#items do
        local attackIndex=string.byte(planState.route,index)-64
        if attackIndex>0 then
            plan[attackIndex].used[index]=true
            used[index]=true
        end
    end
    local leftover={}
    for index=1,#items do if not used[index] then leftover[#leftover+1]=index end end
    return plan,items,leftover
end

local function combatBlockSpent(attack,items,used)
    local full,wrong=0,0
    for index,item in ipairs(items) do
        if used[index] and combatBlockLegal(attack,item) then
            local amount=item.value*(attack.swift and item.swiftDouble and 2 or 1)
            if combatBlockEfficient(attack,item) then full=full+amount else wrong=wrong+amount end
        end
    end
    return full+math.floor(wrong/2)
end

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
local function combatBlockResult(entry,sources)
    local items={}
    local movePool=0
    for _,source in ipairs(sources) do
        if source.moveCounts==true then movePool=movePool+source.move end
        if source.psychicInfluenceCounts==true and source.psychicInfluence>0 then
            -- Influence may be divided between attacks; individual points are
            -- independent legal Psychic Block resources, never generic Block.
            for point=1,source.psychicInfluence do
                items[#items+1]={source=source,key="blockPsychic",value=1,part=point}
            end
        end
        if source.block>0 then
            for _,field in ipairs(combatConfig.sourceFields) do
                local value=tonumber(source.resources[field.key]) or 0
                if field.family=="block" and value>0 then
                    -- Repeated Block icons (Shield of the Fallen Kings) are separate, equal effects.
                    local repeats=tonumber(source.repeatBlocks) or 1
                    local firstBonus=tonumber(source.ambushFirstBlockBonus) or 0
                    local unboosted=value-firstBonus
                    if repeats<2 or unboosted%repeats~=0 then
                        repeats,firstBonus,unboosted=1,0,value
                    end
                    for part=1,repeats do
                        items[#items+1]={source=source,key=field.key,
                            value=unboosted/repeats+(part==1 and firstBonus or 0),
                            swiftDouble=source.swiftDouble,part=part}
                    end
                end
            end
        end
    end
    local attacks=combatEnemyAttacks(entry)
    local blockBonus=combatNatureVengeanceBlockBonus()
    if blockBonus>0 then
        for _,attack in ipairs(attacks) do
            if not attack.pending then
                attack.damageValue=attack.value
                attack.value=attack.value+blockBonus
            end
        end
    end
    local parts={tostring(movePool),tostring(#attacks),tostring(#items)}
    for _,attack in ipairs(attacks) do
        parts[#parts+1]=table.concat({
            tostring(attack.key),tostring(attack.value),tostring(attack.damageValue),tostring(attack.owner),
            tostring(attack.slot),tostring(attack.pending),tostring(attack.swift),
            tostring(attack.brutal),tostring(attack.cumbersome),tostring(attack.poison),
            tostring(attack.paralyse),tostring(attack.assassination),
            tostring(attack.firstDamageUnit)},":")
    end
    for _,item in ipairs(items) do
        parts[#parts+1]=table.concat({
            tostring(item.source.key),tostring(item.key),tostring(item.value),
            tostring(item.swiftDouble),tostring(item.part),
            tostring(item.source.heroPsychicBlock),
            tostring(item.source.excessBlockArmour)},":")
    end
    -- Move-source identity matters to the committed phase even when its
    -- total reduction is unchanged (e.g. swapping Move 2 cards).
    local moveSignature={}
    for _,source in ipairs(sources) do
        if source.moveCounts==true and (source.move or 0)>0 then
            moveSignature[#moveSignature+1]=source.key..":"..tostring(source.move)
        end
    end
    table.sort(moveSignature)
    for _,piece in ipairs(moveSignature) do parts[#parts+1]="move:"..piece end
    local key=table.concat(parts,";")
    local cached=entry.guid~=nil and trackerPrivate.combatBlockResultCache[entry.guid] or nil
    if cached~=nil and cached.key==key then return table.unpack(cached.result,1,12) end
    local plan,solved,leftover=combatSolveBlocks(attacks,items,movePool)
    -- Capture only the resources assigned to a successful Block. The later
    -- display of spare/failed Block icons must never commit their sources.
    local successfulSources,successfulOwners,successfulSourceKeys={},{},{}
    for index,attack in ipairs(attacks) do
        if plan[index]~=nil and plan[index].blocked and not attack.pending then
            for j,item in ipairs(solved) do
                if plan[index].used[j] and item.key:sub(1,5)=="block" then
                    successfulSources[item.source.guid]=true
                    successfulSourceKeys[item.source.key]=true
                    local owners=successfulOwners[item.source.guid] or {}
                    owners[attack.owner or entry.guid]=true
                    successfulOwners[item.source.guid]=owners
                end
            end
        end
    end
    -- Resources that could not complete any block are shown against the heaviest unblocked attack, once each.
    -- When every attack is blocked, spare Block is shown as over-blocking the heaviest attack.
    local attempted=nil
    for index,attack in ipairs(attacks) do
        if not plan[index].blocked then
            local damage=math.max(0,(attack.damageValue or attack.value)-plan[index].reduction)*(attack.brutal and 2 or 1)
            if attempted==nil or damage>attempted.damage then attempted={index=index,damage=damage} end
        end
    end
    if attempted==nil then
        for index,attack in ipairs(attacks) do
            if not attack.pending and attack.value>0 and (attempted==nil or attack.value>attempted.damage) then
                attempted={index=index,damage=attack.value}
            end
        end
    end
    if attempted~=nil then
        for _,itemIndex in ipairs(leftover) do
            if combatBlockLegal(attacks[attempted.index],solved[itemIndex]) then
                plan[attempted.index].used[itemIndex]=true
            end
        end
    end
    -- Shield Bash is one Block effect against one attack. Its powered Armour
    -- reduction uses excess Block on THAT attack (including other cards),
    -- not surplus Block from the enemy's other attacks. Calculate this after
    -- spare resources have been assigned, without affecting Ranged/Siege.
    local shieldBashExcess={}
    for index,attack in ipairs(attacks) do
        local step=plan[index]
        if step~=nil and step.blocked and not attack.pending and attack.value>0 then
            local bashCount=0
            for itemIndex,item in ipairs(solved) do
                if step.used[itemIndex] and item.source.excessBlockArmour then
                    bashCount=bashCount+1
                end
            end
            if bashCount>0 then
                local needed=math.max(0,attack.value-step.reduction)
                    *(attack.swift and 2 or 1)
                local excess=math.max(0,combatBlockSpent(attack,solved,step.used)-needed)
                local owner=attack.owner or entry.guid
                if excess>0 then
                    shieldBashExcess[owner]=(shieldBashExcess[owner] or 0)+excess*bashCount
                end
            end
        end
    end
    -- Cumbersome Move is effective even when damage is not fully blocked.
    -- Commit only enough physical Move sources to cover the actual reductions;
    -- unused sources remain free to supply Attack-phase alternatives.
    local spentMoveKeys={}
    local remainingMove=0
    for _,step in ipairs(plan) do remainingMove=remainingMove+(step.reduction or 0) end
    if remainingMove>0 then
        local moveSources={}
        for _,source in ipairs(sources) do
            if source.moveCounts==true and (source.move or 0)>0 then
                moveSources[#moveSources+1]=source
            end
        end
        table.sort(moveSources,function(a,b) return a.key<b.key end)
        for _,source in ipairs(moveSources) do
            if remainingMove<=0 then break end
            spentMoveKeys[source.key]=true
            remainingMove=remainingMove-source.move
        end
    end
    local lines,reductions,totalDamage,damageCount,allBlocked={},{},0,0,#attacks>0
    local unblocked={}
    -- Block items applied at the wrong element (halved) against their attack, keyed source.key..field.key.
    local wrongBlock={}
    for index,attack in ipairs(attacks) do
        for j,item in ipairs(solved) do
            if plan[index].used[j] and not combatBlockEfficient(attack,item) then
                wrongBlock[item.source.key..item.key]=true
            end
        end
    end
    for index,attack in ipairs(attacks) do
        local step=plan[index]
        local remaining=attack.value-step.reduction
        local required=remaining*(attack.swift and 2 or 1)
        local spent=combatBlockSpent(attack,solved,step.used)
        reductions[index]=step.reduction
        if step.blocked then
            lines[index]=attack.pending and "Summon pending" or (attack.value<=0 and "No attack"
                or (tostring(math.max(spent,required)).."/"..tostring(required).." Blocked"))
        else
            allBlocked=false
            local damage=math.max(0,(attack.damageValue or attack.value)-step.reduction)*(attack.brutal and 2 or 1)
            totalDamage=totalDamage+damage
            if damage>0 then damageCount=damageCount+1 end
            local prefix=spent>0 and (tostring(spent).."/"..tostring(required).." Block, ") or "Not blocked, "
            unblocked[index]={prefix=prefix,damage=damage,attack=attack}
            lines[index]=prefix..combatRich(tostring(damage).." Damage",combatConfig.COMBAT_RED)
        end
    end
    if entry.guid~=nil then
        trackerPrivate.combatBlockResultCache[entry.guid]={key=key,result={
            lines,totalDamage,damageCount,allBlocked,reductions,wrongBlock,unblocked,
            successfulSources,successfulOwners,shieldBashExcess,successfulSourceKeys,spentMoveKeys}}
    end
    return lines,totalDamage,damageCount,allBlocked,reductions,wrongBlock,unblocked,
        successfulSources,successfulOwners,shieldBashExcess,successfulSourceKeys,spentMoveKeys
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
    local player=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    if player==nil or guid==nil then return false end
    local mode,site=combatUnitSiteRestriction(player.seatPos)
    if mode~="one" then return false end
    combatOneUnitSelect(player.seatPos,site,guid)
    return true
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

-- The physical native Command tokens can lead the recorded level during testing.
-- Command slots imply Armor 2, 3, 3, 4, 4, 5, 5, 6, 6... for 1, 2, 3, 4...
-- Banner of Command and Bonds of Loyalty add slots, but not Hero Armor.
local function combatHeroArmour(nativeCommandCount)
    local player=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    local level=math.max(1,math.min(10,tonumber(player~=nil and player.level or 1) or 1))
    local levelArmour=2+math.floor((level-1)/2)
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

-- Cold Fire only counts as resisted by a Unit with both Fire and Ice resistance. Psychic has no Unit resistance rule.
local function combatUnitResists(unit,attackKey)
    if attackKey=="IF" then return unit.resist.F==true and unit.resist.I==true end
    return unit.resist[attackKey]==true
end

-- items: {key,type,damage,poison,paralyse,assassination} in resolution order; targetsOf(key) lists the Unit GUIDs the player chose.
local function combatDamageResolve(items,units,heroArmour,targetsOf,mitigation,elementMitigation,ignoreFirstHeroWound,appliedDamage)
    local used,results={},{}
    local firstHeroWoundIgnored=false
    -- Reserve a Unit required to receive its own protected enemy's damage first.
    -- An earlier, unrelated enemy must not consume that Unit before its forced assignment.
    local reserved={}
    for _,item in ipairs(items) do
        local guid=item.firstDamageUnit
        if guid~=nil and units[guid]~=nil and not units[guid].wounded then
            reserved[guid]=item.key
        end
    end
    for _,item in ipairs(items) do
        local remaining=item.damage
        local result={units={},heroWounds=0,discard=0,heroDamage=0,committedDestroyed={}}
        -- After Apply Wounds removes a Paralyzed Unit from the board, that
        -- Unit must still absorb its already-resolved share of this attack.
        -- Otherwise a new scan would incorrectly wound the Hero again.
        local prior=appliedDamage~=nil and appliedDamage[item.key] or nil
        for guid,absorbed in pairs(prior~=nil and prior.destroyed or {}) do
            local value=math.max(0,tonumber(absorbed) or 0)
            remaining=math.max(0,remaining-value)
            result.committedDestroyed[guid]=value
            -- Keep a resolved damage-phase entry for Vampiric Armor, Glory
            -- and other effects that look at which Units were wounded. This
            -- is not a live Unit and must never generate a new wound preview.
            local data=gameCards~=nil and gameCards[guid] or nil
            local name=data~=nil and data.name or nil
            result.units[#result.units+1]={
                unit={guid=guid,name=type(name)=="table" and name[1]
                    or tostring(name or guid)},
                wounded=true,destroyed=true,alreadyApplied=true,
                absorbed=value,wounds=1}
        end
        local function assign(guid,forced)
            local unit=units[guid]
            if unit==nil or unit.wounded or used[guid] or remaining<=0
                or (not forced and reserved[guid]~=nil and reserved[guid]~=item.key) then return end
            used[guid]=true
            local before=remaining
            local entry={unit=unit,wounded=true,resisted=combatUnitResists(unit,item.type),forced=forced}
            local armour=item.type=="M" and unit.level or unit.armour
            if entry.resisted then
                remaining=remaining-armour
                if remaining<=0 then entry.wounded,remaining=false,0 end
            end
            if entry.wounded then
                remaining=math.max(0,remaining-armour)
                entry.wounds=item.poison and 2 or 1
                entry.destroyed=item.paralyse==true and unit.arcaneImmunity~=true
                if unit.fortitudeUsed and unit.fortitudeGUID~=nil then
                    -- Once per Round, on one printed attack; calculator rescans
                    -- of this same attack may preview it without recharging.
                    local uses=trackerPrivate.bannerEffectUses().fortitude
                    local prior=uses[unit.fortitudeGUID]
                    if prior==nil or prior.attackKey==item.key then
                        if prior==nil then uses[unit.fortitudeGUID]={attackKey=item.key} end
                        entry.wounded=false
                        entry.wounds=nil
                        entry.destroyed=nil
                        entry.fortitudePrevented=true
                    end
                end
            end
            if entry.destroyed then entry.absorbed=math.max(0,before-remaining) end
            result.units[#result.units+1]=entry
        end
        -- Shocktroops must take damage first, even against Assassination.
        -- Ordinary voluntary Unit assignments still cannot bypass it.
        if item.firstDamageUnit~=nil then assign(item.firstDamageUnit,true) end
        for _,guid in ipairs(item.assassination and {} or targetsOf(item.key)) do
            if guid~=item.firstDamageUnit then assign(guid,false) end
        end
        if remaining>0 then
            -- Battle Hardened prevents damage to the Hero, not attack points
            -- or Unit damage. Brutal has already doubled item.damage.
            -- One use applies to one printed Attack, even on a multi-attack enemy.
            local sameEnemy=mitigation~=nil and (item.owner==mitigation.owner
                or (gStates~=nil and gStates.attackedMonsters~=nil
                    and gStates.attackedMonsters[item.owner]~=nil
                    and gStates.attackedMonsters[item.owner][3]=="summoned"
                    and gStates.attackedMonsters[item.owner][4]==mitigation.owner))
            if sameEnemy and not mitigation.used
                and (mitigation.attackKey==nil or mitigation.attackKey==item.key) then
                local ignored=item.type=="P" and mitigation.physical or mitigation.nonphysical
                result.prevented=math.min(remaining,ignored)
                remaining=remaining-result.prevented
                mitigation.used=true
                mitigation.appliedKey=item.key
            end
        end
        -- Elemental Resistance is a separate once-per-turn Hero safeguard.
        -- Fire/Ice prevent 2; Cold Fire, Physical and Psychic prevent 1.
        -- Apply after Brutal doubles damage and after Units absorb their share.
        if remaining>0 and elementMitigation~=nil and not elementMitigation.used then
            local sameEnemy=item.owner==elementMitigation.owner
                or (gStates~=nil and gStates.attackedMonsters~=nil
                    and gStates.attackedMonsters[item.owner]~=nil
                    and gStates.attackedMonsters[item.owner][3]=="summoned"
                    and gStates.attackedMonsters[item.owner][4]==elementMitigation.owner)
            if sameEnemy and (elementMitigation.attackKey==nil
                or elementMitigation.attackKey==item.key) then
                local ignored=(item.type=="F" or item.type=="I") and 2 or 1
                result.elementPrevented=math.min(remaining,ignored)
                remaining=remaining-result.elementPrevented
                elementMitigation.used=true
                elementMitigation.appliedKey=item.key
            end
        end
        if remaining>0 then
            result.heroDamage=remaining
            result.heroWounds=math.ceil(remaining/math.max(1,heroArmour))
            if ignoreFirstHeroWound==true and not firstHeroWoundIgnored and result.heroWounds>0 then
                -- Veil of Mist ignores one hero Wound for the whole turn, not one per attack.
                -- The ignored Wound also has no Poison/Paralyse side effects.
                firstHeroWoundIgnored=true
                result.heroWounds=result.heroWounds-1
                result.veilWoundIgnored=true
            end
            if item.poison then result.discard=result.heroWounds end
        end
        result.paralyse=item.paralyse==true and result.heroWounds>0
        result.unitWounds=0
        for _,entry in ipairs(result.units) do result.unitWounds=result.unitWounds+(entry.wounded and entry.wounds or 0) end
        results[item.key]=result
    end
    return results
end

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
        knockout=false,handDiscard=false}
    if ledger==nil or not ledger.hasPreview then
        return allocations,hand,discard,changed,effects
    end
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
    if ledger==nil or ledger.hasPreview~=true then return nil end
    local parts={tostring(ledger.seat),tostring(ledger.previewKnockout==true),
        tostring(ledger.previewOtherWounds or 0),
        tostring(ledger.handDiscardApplied==true)}
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

-- The original wound button stays unchanged; it only opens the dialog.
function resourceCardsRequestCombatWounds(player)
    local color=player~=nil and player.color or nil
    if not resourceCardsPanelOpen() or not resourceCardsPlayerCanEdit(color)
        or combatConfig.woundApplying or combatConfig.woundTransactionPending then return end
    -- A previous partial application may have committed the phase but not
    -- finished its physical consequences. Let the player confirm a safe retry.
    local active=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    if active==nil or active.seatPos==nil then return end
    local ledger=combatConfig.woundLedger(active.seatPos)
    if ledger==nil then return end
    local _,hand,discard,changed,effects=combatConfig.woundPending(ledger)
    if hand+discard+effects.destroyCount+effects.stagedDiscardCount==0
        and not effects.handDiscard then
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
        ledger=ledger,signature=signature}
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
    UI.setAttribute("CombatDamageConfirm","height",tostring(summaryHeight+96))
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
    if confirmation==nil or color~=confirmation.color
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
        or combatConfig.woundApplying then return false end
    local current=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    local ledger=current~=nil and combatConfig.woundLedger(current.seatPos) or nil
    local allocations,hand,discard,changed,effects=combatConfig.woundPending(ledger)
    if current==nil or ledger==nil then return false end
    if hand+discard==0 and not effects.handDiscard
        and effects.destroyCount+effects.stagedDiscardCount==0 then
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
            resourceCardsSourceChanged()
            mainUIUpdate("Combat Wounds applied")
            if onComplete~=nil then onComplete(success,reason,physicallyTouched) end
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

-- Short notes under an attack's line: what each chosen Unit took and what is left for the Hero.
local function combatDamageNotes(item,result)
    local wounds,resisted,destroyed,forced={},{},{},{}
    for _,entry in ipairs(result.units) do
        local name=entry.unit.name
        if entry.wounded then
            wounds[#wounds+1]=name..((entry.wounds or 1)>1 and
                (" ("..tostring(entry.wounds)..")") or "")
        else
            resisted[#resisted+1]=name
        end
        if entry.destroyed then destroyed[#destroyed+1]=name end
        if entry.forced then forced[#forced+1]=name end
    end
    if result.heroWounds>0 then
        wounds[#wounds+1]="Hero ("..tostring(result.heroWounds)..")"
    end
    local distribution="Wounds: "..(#wounds>0 and table.concat(wounds,", ") or "None")
    if result.discard>0 then
        distribution=distribution.." Poison ("..tostring(result.discard)..")"
    end
    if result.veilWoundIgnored then distribution=distribution.." (Veil of Mist: 1 Wound ignored)" end
    local notes={distribution}
    if (result.prevented or 0)>0 then
        notes[#notes+1]="Battle Hardened: -"..tostring(result.prevented).." Hero damage"
    end
    if (result.elementPrevented or 0)>0 then
        notes[#notes+1]="Elemental Resistance: -"..tostring(result.elementPrevented).." Hero damage"
    end
    if #resisted>0 then notes[#notes+1]="Resisted (no Wound): "..table.concat(resisted,", ") end
    if #destroyed>0 then notes[#notes+1]="Destroyed (Paralyse): "..table.concat(destroyed,", ") end
    if #forced>0 then notes[#notes+1]="Must take damage first: "..table.concat(forced,", ") end
    if item.assassination then notes[#notes+1]="Assassination" end
    if result.paralyse then notes[#notes+1]="Paralyse: discard hand" end
    return notes
end

-- Preserve the original Result button and expansion wiring for stable layout.
-- Full per-source results are now the default display, without abbreviated text.
local function combatCompactResultLines(fullLines,damageItems,damageResults)
    -- Keep the original Result button, layout, and expansion plumbing intact.
    -- The concise per-source breakdown is already the full display; do not
    -- abbreviate it or append expandable [+]/[-] indicators.
    return fullLines
end

-- A group is attacked as one: fortification and resistance of any member apply to all of
-- them and the armours add together. Elusive members only use their higher armour in the
-- Attack phase while one of their attacks is unblocked.
local function combatGroupEntry(members,blockedAll,rangePhase)
    local data={fortified=false,elusive=true,coldFireResist=false}
    local perks={}
    local fortification=0
    local armour,elusiveArmour,attackArmour=0,0,0
    for _,member in ipairs(members) do
        if not member.stripFortify then
            fortification=math.max(fortification,combatEnemyFortificationCount(member.data,member.perks))
        end
        for _,key in ipairs({"pResist","fResist","iResist","mResist"}) do
            if not member.stripResist and not (key=="fResist" and member.stripFireResist)
                and combatEnemyHasTrait(member.data,member.perks,key) then data[key]=true end
        end
        if not member.stripResist
            and not member.stripFireResist
            and combatEnemyHasTrait(member.data,member.perks,"fResist")
            and combatEnemyHasTrait(member.data,member.perks,"iResist") then
            data.coldFireResist=true
        end
        local elusive=combatEnemyHasTrait(member.data,member.perks,"elusive")
        local baseArmour=(rangePhase and member.rangeBaseArmour) or member.baseArmour
        local elusiveValue=(rangePhase and member.rangeElusiveArmour) or member.elusiveArmour
        local rangeArmour=elusive and elusiveValue or baseArmour
        armour=armour+baseArmour
        elusiveArmour=elusiveArmour+rangeArmour
        attackArmour=attackArmour+((elusive and not blockedAll[member.guid]) and elusiveValue or baseArmour)
    end
    data.fortified=fortification>=1
    perks.wallFortified=fortification>=2
    return {data=data,perks=perks,baseArmour=armour,elusiveArmour=elusiveArmour},attackArmour
end

-- Bonuses first assigned in the regular Attack phase must not retrospectively
-- make an earlier Ranged/Siege attack fail.
local function combatRangeGroupEntry(members)
    local result=combatGroupEntry(members,{},true)
    local lateBonus=0
    for _,member in ipairs(members) do lateBonus=lateBonus+(member.defendMeleeBonus or 0) end
    if lateBonus>0 then
        result.baseArmour=result.baseArmour-lateBonus
        result.elusiveArmour=result.elusiveArmour-lateBonus
    end
    local extra=0
    for _,member in ipairs(members) do
        if (member.bossLevel or 0)>1 then
            local armour=combatEnemyHasTrait(member.data,member.perks,"elusive")
                and (member.rangeElusiveArmour or member.elusiveArmour)
                or (member.rangeBaseArmour or member.baseArmour)
            extra=extra+((member.bossLevel-1)*math.max(1,
                armour-(member.defendMeleeBonus or 0)))
        end
    end
    result.fullLevelArmour=(combatEnemyHasTrait(result.data,result.perks,"elusive")
        and result.elusiveArmour or result.baseArmour)+extra
    return result
end

-- Defence text of one member of a multi-enemy group: fortification and resistances are shared by the whole group.
local function combatGroupTraitsText(entry,groupEntry)
    local data={elusive=entry.data.elusive,arcaneImmunity=entry.data.arcaneImmunity,defend=entry.data.defend,
        fortified=groupEntry.data.fortified,unfortified=entry.data.unfortified}
    local perks={defend=entry.perks~=nil and entry.perks.defend or nil,
        elusive=entry.perks~=nil and entry.perks.elusive or nil,
        arcaneImmunity=entry.perks~=nil and entry.perks.arcaneImmunity or nil,
        unfortified=entry.perks~=nil and entry.perks.unfortified or nil,
        wallFortified=groupEntry.perks.wallFortified}
    for _,key in ipairs({"pResist","fResist","iResist","mResist"}) do data[key]=groupEntry.data[key] end
    return combatEnemyTraitsText(data,perks,combatConfig.enemyDefenceTraits)
end

local function combatGroupAttackLine(meleeTotal,attackArmour)
    -- Render the same post-Damage total used by the defeat decision. Recounting
    -- the original sources would re-include Wounded Units in the Result text.
    if meleeTotal<=0 then return nil end
    local line="Attack "..tostring(meleeTotal).."/"..tostring(attackArmour)
    return meleeTotal>=attackArmour and (line.." "..combatRich("Defeated",combatConfig.COMBAT_GREEN)) or line
end

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

-- Whole multiples of effective Armour remove levels of either boss type.
function combatBossLevelCount(total,armour,remaining)
    local a=math.max(1,tonumber(armour) or 1)
    return math.max(0,math.min(math.max(0,tonumber(remaining) or 0),
        math.floor(math.max(0,tonumber(total) or 0)/a)))
end

-- Joined attacks reserve one Armour for every living ordinary enemy and
-- one Armour/level for each boss, then allocate spare points to further
-- reductions. Never spend the same Attack points independently on two heads.
local function combatBossPhasePlan(group,entries,total,phase,blockedAll)
    local bosses,ordinary={},{}
    local anyBoss=false
    for _,index in ipairs(group.members) do
        local entry=entries[index]
        if entry.bossLevel~=nil and entry.bossType~="control" then anyBoss=true end
        if not entry.attackOnly and not entry.destroyed
            and (phase=="range" or not entry.rangeDead) then
            local remaining=entry.bossLevel~=nil
                and math.max(0,entry.bossLevel-(phase=="attack"
                    and (entry.bossRangeLevels or 0) or 0)) or 1
            if remaining>0 then
                local elusive=combatEnemyHasTrait(entry.data,entry.perks,"elusive")
                local armour
                if phase=="range" then
                    armour=elusive and (entry.rangeElusiveArmour or entry.elusiveArmour)
                        or (entry.rangeBaseArmour or entry.baseArmour)
                    armour=armour-(entry.defendMeleeBonus or 0)
                else
                    armour=elusive and not (blockedAll or {})[entry.guid]
                        and entry.elusiveArmour or entry.baseArmour
                end
                local item={entry=entry,armour=math.max(1,armour),remaining=remaining}
                if entry.bossLevel~=nil then bosses[#bosses+1]=item
                else ordinary[#ordinary+1]=item end
            end
        end
    end
    if not anyBoss then return nil end
    local result={reductions={},killed={},spent=false}
    local required=0
    for _,item in ipairs(bosses) do required=required+item.armour end
    for _,item in ipairs(ordinary) do required=required+item.armour end
    local points=math.max(0,tonumber(total) or 0)
    if required>0 and points>=required then
        points=points-required
        for _,item in ipairs(ordinary) do result.killed[item.entry.guid]=true end
        for _,item in ipairs(bosses) do result.reductions[item.entry.guid]=1 end
        local manual=gStates~=nil and gStates.combatBossManual or {}
        table.sort(bosses,function(a,b)
            local am=manual[a.entry.guid]~=nil
            local bm=manual[b.entry.guid]~=nil
            if am~=bm then return am end
            if a.entry.x~=b.entry.x then return a.entry.x<b.entry.x end
            return a.entry.guid<b.entry.guid
        end)
        for pass=1,2 do
            for _,item in ipairs(bosses) do
                local guid=item.entry.guid
                local current=result.reductions[guid] or 0
                local extra=math.min(item.remaining-current,math.floor(points/item.armour))
                if pass==1 then
                    local target=manual[guid]
                    if target==nil then extra=0
                    else
                        extra=math.min(extra,math.max(0,target
                            -(phase=="attack" and (item.entry.bossRangeLevels or 0) or 0)
                            -current))
                    end
                end
                if extra>0 then
                    result.reductions[guid]=current+extra
                    points=points-extra*item.armour
                end
            end
        end
    end
    -- In a single-target attack the player may explicitly correct an
    -- unrecognised effect. Extra corrections belong to the later Attack
    -- phase so that Block/Damage timing is not rewritten retroactively.
    if #group.members==1 and #bosses==1 then
        local item=bosses[1]
        local target=gStates~=nil and gStates.combatBossManual~=nil
            and gStates.combatBossManual[item.entry.guid] or nil
        if target~=nil then
            if phase=="range" then
                result.reductions[item.entry.guid]=math.min(target,
                    result.reductions[item.entry.guid] or 0)
            else
                result.reductions[item.entry.guid]=math.min(item.remaining,
                    math.max(0,target-(item.entry.bossRangeLevels or 0)))
            end
        end
    end
    for _,item in ipairs(bosses) do
        local value=result.reductions[item.entry.guid] or 0
        if value>0 then result.spent=true end
        if value>=item.remaining then result.killed[item.entry.guid]=true end
    end
    if #ordinary>0 and next(result.killed)~=nil then result.spent=true end
    result.full=true
    for _,index in ipairs(group.members) do
        local entry=entries[index]
        if not entry.attackOnly and not entry.destroyed and not entry.rangeDead
            and not result.killed[entry.guid] then result.full=false break end
    end
    return result
end

-- Each Defend symbol may protect one attacked enemy, including a member of an
-- attacked group. Ranged/Siege attacks are resolved first; a defender defeated
-- in that phase cannot protect a newly attacked enemy in the Attack phase.
-- Default ordering is left-to-right within each phase (the physical table order).
local function combatApplyDefend(entries,groups,allocated)
    local defenders={}
    for index,entry in ipairs(entries) do
        entry.defendMeleeBonus=nil
        local bonus=(tonumber(entry.data.defend) or 0)+(entry.perks~=nil and (tonumber(entry.perks.defend) or 0) or 0)
        if bonus>0 and not entry.destroyed then
            defenders[#defenders+1]={index=index,bonus=bonus}
        end
    end
    if #defenders==0 then return {} end
    table.sort(defenders,function(a,b)
        if a.bonus~=b.bonus then return a.bonus>b.bonus end
        return a.index<b.index
    end)

    local groupOf,groupSources={},{}
    local rangedTargets,meleeTargets={},{}
    for _,group in ipairs(groups) do
        local members,sources={},{}
        for _,index in ipairs(group.members) do
            local entry=entries[index]
            groupOf[index]=group
            members[#members+1]=entry
            for _,source in ipairs((allocated[index] or {sources={}}).sources) do
                sources[#sources+1]=source
            end
        end
        groupSources[group]=sources
        local grouped=combatGroupEntry(members,{})
        local fortification=combatEnemyFortificationCount(grouped.data,grouped.perks)
        local hasRanged,hasAnyAttack=false,false
        for _,index in ipairs(group.members) do
            for _,item in ipairs((allocated[index] or {details={}}).details) do
                local family=item.detail.family
                if family=="attack" or family=="ranged" or family=="siege" then
                    hasAnyAttack=true
                    local forkMelee=item.source.forkedLightning
                        and gStates~=nil and gStates.forkedLightningPhase=="attack"
                    if not forkMelee and ((family=="ranged" and fortification==0)
                        or (family=="siege" and fortification<2)) then
                        hasRanged=true
                    end
                end
            end
        end
        for _,index in ipairs(group.members) do
            local entry=entries[index]
            if not entry.destroyed and not entry.attackOnly then
                if hasRanged then rangedTargets[#rangedTargets+1]=index end
                if hasAnyAttack then meleeTargets[#meleeTargets+1]=index end
            end
        end
    end
    -- The Ranged phase can spend any available Defender, even one whose own
    -- token will later be defeated by that Ranged attack.
    local applied,rangedBonuses,spentDefenders={},{},{}
    local slot=1
    for _,target in ipairs(rangedTargets) do
        local defender=defenders[slot]
        if defender==nil then break end
        applied[target]=defender.bonus
        rangedBonuses[target]=defender.bonus
        spentDefenders[defender.index]=true
        slot=slot+1
    end

    -- Evaluate survival with Ranged-only Defender bonuses. Do not use late
    -- Attack-phase bonuses when deciding whether a Defender survives.
    local rangedDefeated={}
    for _,group in ipairs(groups) do
        local members={}
        for _,index in ipairs(group.members) do
            local entry=entries[index]
            local bonus=rangedBonuses[index] or 0
            members[#members+1]={guid=entry.guid,data=entry.data,perks=entry.perks,
                baseArmour=entry.baseArmour+bonus,elusiveArmour=entry.elusiveArmour+bonus,
                rangeBaseArmour=entry.rangeBaseArmour~=nil and entry.rangeBaseArmour+bonus or nil,
                rangeElusiveArmour=entry.rangeElusiveArmour~=nil and entry.rangeElusiveArmour+bonus or nil,
                stripFortify=entry.stripFortify,stripResist=entry.stripResist,
                stripFireResist=entry.stripFireResist,bossLevel=entry.bossLevel}
        end
        local grouped=combatRangeGroupEntry(members)
        local _,_,defeated=combatRangeResult(grouped,groupSources[group])
        rangedDefeated[group]=defeated and not members[1].data.attackOnly
    end

    -- Remaining Defenders may help in the regular Attack phase only if they
    -- survived Ranged/Siege, and no enemy receives more than one Defend bonus.
    for _,target in ipairs(meleeTargets) do
        if applied[target]==nil and not rangedDefeated[groupOf[target]] then
            for _,defender in ipairs(defenders) do
                if not spentDefenders[defender.index] and not rangedDefeated[groupOf[defender.index]] then
                    applied[target]=defender.bonus
                    entries[target].defendMeleeBonus=defender.bonus
                    spentDefenders[defender.index]=true
                    break
                end
            end
        end
    end
    for index,bonus in pairs(applied) do
        entries[index].baseArmour=entries[index].baseArmour+bonus
        entries[index].elusiveArmour=entries[index].elusiveArmour+bonus
        if entries[index].rangeBaseArmour~=nil then
            entries[index].rangeBaseArmour=entries[index].rangeBaseArmour+bonus
            entries[index].rangeElusiveArmour=entries[index].rangeElusiveArmour+bonus
        end
    end
    return applied
end

-- Distribute a joined group's display icons without changing resource assignments.
-- Attack/Ranged resources are shared by the group; Block stays on its owning
-- enemy row first, with excess icons continuing into free slots below it.
-- An ungrouped enemy has just one member and cannot spill into another enemy.
local function combatGroupResourceRows(members,perMember,limit)
    local rows,overflow={},0
    for _,index in ipairs(members) do rows[index]={range={},block={},attack={}} end
    for _,family in ipairs({"range","attack"}) do
        local count=0
        for _,index in ipairs(members) do
            for _,item in ipairs(perMember[index][family]) do
                count=count+1
                local targetIndex=members[math.floor((count-1)/limit)+1]
                if targetIndex~=nil then
                    local display=rows[targetIndex][family]
                    display[#display+1]=item
                else
                    overflow=overflow+1
                end
            end
        end
    end
    local pending,head={},1
    for _,index in ipairs(members) do
        local display=rows[index].block
        for i,item in ipairs(perMember[index].block) do
            if i<=limit then display[#display+1]=item
            else pending[#pending+1]=item end
        end
        while #display<limit and pending[head]~=nil do
            display[#display+1]=pending[head]
            head=head+1
        end
    end
    return rows,overflow+(#pending-head+1)
end

-- The same two colours as existing resource slots: normal grey, or the
-- existing red used for a Wounded/unavailable assignment. Effect metadata
-- comes from CombatEffects rather than skill-specific table-button branches.
combatConfig.effectButtonInfo=function(entry,applied)
    local spec,actual=applied.spec or {},applied.effective or {}
    if spec.all==true then return nil end
    local printedFortified=combatEnemyFortificationCount(entry.data,entry.perks)>0
    local fortified=printedFortified
        and (entry.effect==nil or entry.effect.removeFortify~=true)
    local fortifiedWhenCast=fortified
        or (spec.armourBeforeFortificationRemoval==true and (entry.originalFortification or 0)>0)
    local armour=tonumber(spec.armourReduce) or 0
    local armourFortified=tonumber(spec.armourReduceFortified) or armour
    local resistArmour=tonumber(spec.armourReduceByResist) or 0
    local attack=tonumber(spec.attackReduce) or 0
    local isArmour=armour>0 or armourFortified>0 or resistArmour>0
        or spec.removeFortify==true or spec.removeResist==true
        or spec.removeFireResist==true or spec.destroy==true or spec.destroyDuringAttack==true
    local isBlock=attack>0 or spec.noAttack==true or spec.noAttackUnfortified==true
        or spec.cancelOneAttack==true
        or spec.removeAbilities==true or spec.removeOneAttackAbilities==true
        or spec.destroyIfBlocked==true or spec.destroyIfFullyBlocked==true
    local attackIncrease=tonumber(spec.attackIncrease) or 0
    local special=spec.removeTrait~=nil or spec.convertAttack~=nil or attackIncrease>0
    if not isArmour and not isBlock and not special then return nil end
    local family=isArmour and (fortified and "attack" or "range") or "block"
    if (tonumber(spec.armourReduceAttackOnly) or 0)>0 or spec.destroyDuringAttack then family="attack" end
    if spec.removeTrait~=nil then
        family=(spec.removeTrait=="fortified" or spec.removeTrait=="elusive"
            or spec.removeTrait=="pResist" or spec.removeTrait=="fResist"
            or spec.removeTrait=="iResist" or spec.removeTrait=="mResist"
            or spec.removeTrait=="defend") and "attack" or "block"
    end
    local arrow=isArmour and "armour" or "attack"
    local icon=isArmour and "MKChoiceAttack" or "MKChoiceBlock"
    -- Use specific artwork for numeric reductions, preserving the usual icons
    -- for removal, prevention, conversion and other non-reduction effects.
    if armour>0 or armourFortified>0 or resistArmour>0 then
        icon="MKChoiceArmourReduction"
    elseif attack>0 then
        icon="MKChoiceAttackReduction"
    end
    local amount,description,reason="!", "Combat effect",nil
    local raw=entry.unmodifiedArmour or entry.baseArmour or 1
    if spec.cancelOneAttack==true then
        amount="X"
        description="Cancel one printed enemy Attack"
        if actual.cancelOneAttack~=true then
            reason=applied.immune and "Arcane Immunity ignores this effect."
                or "This attack cannot be cancelled."
        end
    elseif spec.removeTrait~=nil then
        amount="X"
        description="Ignore printed "..tostring(spec.removeTrait)
        if actual.removedPrinted==nil or actual.removedPrinted[spec.removeTrait]~=true then
            reason="The printed ability was not removed."
        end
    elseif spec.convertAttack~=nil then
        amount="→"
        description="Convert attack "..tostring(spec.convertAttack.slot)
            .." from "..tostring(spec.convertAttack.from).." to "..tostring(spec.convertAttack.to)
        if #(actual.attackConversions or {})==0 then
            reason="No attack element was changed."
        end
    elseif attackIncrease>0 then
        amount="+"..tostring(attackIncrease)
        description="Enemy Attack +"..tostring(attackIncrease)
            ..", Armour -"..tostring(armour).." in Attack phase if it attacks"
        if #combatEnemyAttacks(entry)==0 then reason="The enemy has no attack." end
    elseif isArmour and (armour>0 or armourFortified>0 or resistArmour>0) then
        local appliedReduction=fortifiedWhenCast and
            (tonumber(actual.armourReduceFortified) or tonumber(actual.armourReduce) or 0)
            or (tonumber(actual.armourReduce) or 0)
        if (tonumber(actual.armourReduceByResist) or 0)>0 then
            local count=0
            for _,trait in ipairs({"pResist","fResist","iResist"}) do
                if combatEnemyHasTrait(entry.data,entry.perks,trait) then count=count+1 end
            end
            appliedReduction=appliedReduction+count*actual.armourReduceByResist
        end
        local total=entry.effectArmourReduction or 0
        local before=math.max(1,raw-math.max(0,total-appliedReduction))
        local after=math.max(1,raw-total)
        local printed=fortifiedWhenCast and armourFortified or armour
        amount="-"..tostring(math.max(printed,appliedReduction))
        description="Armour reduction "..amount
        if spec.noAttack==true then description=description.."; prevent enemy Attack" end
        if spec.armourBeforeFortificationRemoval==true then
            description=description.." (Earthquake before fortification removal)"
        end
        if appliedReduction==0 then
            reason=applied.fireResistant and "Fire Resistance ignores this red effect."
                or (applied.iceResistant and "Ice Resistance ignores this blue effect.")
                or (applied.immune and "Arcane Immunity ignores this Armour effect.")
                or "This Armour reduction is not applicable to the target."
        elseif before<=after then reason="Armour is already at its minimum of 1 (or other effects have reached it)."
        elseif fortified and (tonumber(spec.armourReduceRangedUnfortifiedOnly) or 0)>0 then
            description=description.." (Attack phase only while Fortified)"
        end
    elseif attack>0 then
        amount="-"..tostring(attack)
        description="Enemy Attack reduction "..amount
            ..(spec.grantCumbersome==true and "; gains Cumbersome" or "")
        -- Compare attacks with and without this source's reduction. Zero printed
        -- attacks, already-cancelled attacks, and duplicate reductions turn red.
        local with=combatEnemyAttacks(entry)
        local original=entry.effect
        local without={}
        for key,value in pairs(original or {}) do without[key]=value end
        without.attackReductions={}
        for _,reduction in ipairs(original~=nil and original.attackReductions or {}) do
            if reduction.source~=applied.source then
                without.attackReductions[#without.attackReductions+1]=reduction
            end
        end
        entry.effect=without
        local before=combatEnemyAttacks(entry)
        entry.effect=original
        local reduced=false
        for i,attackEntry in ipairs(with) do
            if before[i]~=nil and (tonumber(before[i].value) or 0)>
                (tonumber(attackEntry.value) or 0) then reduced=true break end
        end
        if not reduced then reason="No attack value is reduced: the target has no applicable attack or is already at 0."
        end
    elseif spec.removeFortify==true then
        description="Remove Fortification"
        if actual.removeFortify~=true then reason="Arcane Immunity ignores Remove Fortification."
        elseif combatEnemyFortificationCount(entry.data,entry.perks)==0 then
            reason="This enemy has no Fortification to remove." end
    elseif spec.removeResist==true or spec.removeFireResist==true then
        description=spec.removeResist and "Remove Resistances" or "Remove Fire Resistance"
        local relevant=false
        for _,trait in ipairs(spec.removeResist and {"pResist","fResist","iResist","mResist"}
            or {"fResist"}) do
            if combatEnemyHasTrait(entry.data,entry.perks,trait) then relevant=true end
        end
        if applied.iceResistant then
            reason="Ice Resistance ignores this blue effect."
        elseif applied.fireResistant then
            reason="Fire Resistance ignores this red effect."
        elseif (spec.removeResist and actual.removeResist~=true)
            or (spec.removeFireResist and actual.removeFireResist~=true) then
            reason="Arcane Immunity ignores this resistance effect."
        elseif not relevant then reason="The enemy has no applicable Resistance." end
    elseif spec.noAttack==true or spec.noAttackUnfortified==true then
        description="Prevent enemy Attack"
        if spec.moveCost~=nil then
            description=description.." (Wings of Night: "..tostring(spec.moveCost).." Move)"
        end
        if spec.insufficientMove then
            reason="Not enough unspent Move points for this Wings of Night target."
        elseif not actual.noAttack and not actual.noAttackUnfortified then
            reason=applied.iceResistant and "Ice Resistance ignores this blue effect."
                or (applied.fireResistant and "Fire Resistance ignores this red effect.")
                or "Arcane Immunity ignores this prevention effect."
        elseif spec.noAttackUnfortified and fortified then
            reason="The target is still Fortified."
        elseif #combatEnemyPrintedAttacks(entry.data,entry.perks,entry.removeAbilities,entry.guid)==0 then
            reason="The enemy has no attack to prevent." end
    elseif spec.destroyIfFullyBlocked==true then
        description="Destroy target if all its attacks are successfully Blocked"
        if applied.immune or actual.destroyIfFullyBlocked~=true then
            reason="Arcane Immunity prevents this destruction."
        elseif entry.destroyed~=true then
            reason="Not all attacks from this enemy were successfully Blocked."
        end
    elseif spec.destroyIfBlocked==true then
        description="Destroy if this Spell successfully Blocks an attack"
        if applied.fireResistant then reason="Fire Resistance prevents this destruction."
        elseif applied.immune then reason="Arcane Immunity prevents this destruction."
        elseif entry.destroyed~=true then
            reason="This Fire Block has not been used in a successful Block."
        end
    elseif spec.removeOneAttackAbilities==true then
        amount="X"
        description="Chosen attack loses abilities, but keeps its element. Select the attack in the enemy row."
        if actual.removeOneAttackAbilities~=true then
            reason=applied.iceResistant and "Ice Resistance prevents this effect."
                or "This attack ability effect is unavailable."
        end
    elseif spec.removeAbilities==true then
        description="Remove Attack Abilities"
        if actual.removeAbilities~=true then reason="Arcane Immunity ignores this effect." end
    elseif spec.destroy==true then
        description="Destroy enemy"
        if entry.destroyed~=true then reason="This effect is not destroying the enemy." end
    elseif spec.destroyDuringAttack==true then
        description="Destroy enemy during Attack phase"
        if actual.destroyDuringAttack~=true then
            reason=applied.fireResistant and "Fire Resistance prevents this destruction."
                or "Arcane Immunity prevents this destruction."
        end
    end
    local source=getObjectFromGUID(applied.source)
    local sourceName=source~=nil and source.getName~=nil and source.getName() or tostring(applied.source)
    local name=joinLangEnglish~=nil and joinLangEnglish(tostring(sourceName)) or tostring(sourceName)
    local tooltip=name..": "..description..(reason~=nil and ("\nNo benefit: "..reason) or "")
        .."\nClick to select, then click a cell in the enemy row to retarget."
    return {source={guid=applied.source,key=applied.key,name=name},
        family=family,arrow=arrow,amount=amount,icon=icon,
        text=description,tooltip=tooltip,ineffective=reason~=nil}
end

combatConfig.mitigationButtonInfo=function(guid,record,entry,group,damageResults,mitigation)
    if record.enemyGUID~=entry.guid then return nil end
    local rule=skillResourceDefinitions[guid]
    local spec=rule~=nil and rule.damageMitigation or nil
    if spec==nil then return nil end
    local resolved=mitigation~=nil and mitigation.appliedKey~=nil
        and damageResults~=nil and damageResults[mitigation.appliedKey] or nil
    local elemental=spec.fire~=nil or spec.ice~=nil
    local prevented=resolved~=nil and (tonumber(elemental and resolved.elementPrevented or resolved.prevented) or 0) or 0
    local reason=nil
    if prevented==0 then
        if group.rangeDefeated or group.destroyed then
            reason="The enemy was already defeated before the Damage phase."
        else reason="No Hero damage was prevented. The chosen attack may be blocked or its damage assigned to Units." end
    end
    local source=getObjectFromGUID(guid)
    local name=source~=nil and source.getName~=nil and source.getName() or tostring(guid)
    name=joinLangEnglish~=nil and joinLangEnglish(tostring(name)) or tostring(name)
    local tooltip=elemental
        and (name..": Prevent 2 Fire/Ice or 1 Cold Fire/Physical/Psychic Hero damage from one attack.")
        or (name..": Prevent "..tostring(spec.physical or 2)
            .." Physical or "..tostring(spec.nonphysical or 1)
            .." non-Physical damage reaching the Hero from one attack.")
        .."\nCurrently prevents "..tostring(prevented).." Hero damage."
        ..(reason~=nil and ("\nNo benefit: "..reason) or "")
        .."\nSelect the button then click an enemy row to retarget."
    return {source={guid=guid,key=guid,name=name},family="block",arrow="attack",
        amount=tostring(prevented>0 and prevented or (elemental and 2 or (spec.physical or 2))),
        icon="MKChoiceBlock",text="Hero damage prevention",tooltip=tooltip,
        ineffective=reason~=nil}
end

-- Attack-phase eligibility comes from the preceding damage phase, never the
-- eventual melee result. This breaks the apparent ranged/damage/melee feedback
-- loop: ranged kills and Block are frozen before Unit wounds are evaluated.
combatConfig.unitsWoundedByDamage=function(results)
    local wounded={}
    for _,result in pairs(results or {}) do
        for _,entry in ipairs(result.units or {}) do
            if entry.wounded==true and entry.unit~=nil then wounded[entry.unit.guid]=true end
        end
    end
    return wounded
end

-- Unit resources already spent in the Ranged/Block phases stand. Unused
-- Ranged/Siege effects fall back to normal Attack only if their Unit survived
-- damage unwounded; a wound cannot retroactively undo an earlier phase.
-- Knockout and an unblocked Paralyzing Wound both discard non-Wound hand
-- cards before Attack. Backwards-planned card Attacks therefore cannot count
-- while earlier Range/Siege/Block and surviving Unit/Skill actions still do.
-- Cards genuinely played *after* committed Damage remain legal.
combatConfig.paralysisAttackCards=function(sources,results,lock,knockout)
    local heroParalyzed=knockout==true
    for _,result in pairs(results or {}) do
        if result.paralyse==true and (tonumber(result.heroWounds) or 0)>0 then
            heroParalyzed=true
            break
        end
    end
    if not heroParalyzed then return {} end
    local preDamageCards={}
    for _,source in ipairs(lock~=nil and lock.sources or {}) do
        if source.kind=="card" then preDamageCards[source.guid]=true end
    end
    -- Cards actually played in earlier phases survive Knockout/Paralysis.
    -- This includes Burning Shield's Attack earned from a successful Block.
    local previous=lock or combatConfig.phasePreview
    local alreadyPlayed={}
    for guid in pairs(previous~=nil and previous.objectKeys or {}) do
        alreadyPlayed[guid]=true
    end
    -- Some early effects have no numeric source (e.g. Exploding Shield).
    for _,effect in pairs(previous~=nil and previous.enemyEffects or {}) do
        for _,applied in ipairs(effect.applied or {}) do
            if applied.phaseAfterDamage~=true and applied.source~=nil then
                alreadyPlayed[applied.source]=true
            end
        end
    end
    local unavailable={}
    for _,source in ipairs(sources or {}) do
        if source.kind=="card" and not alreadyPlayed[source.guid]
            and (lock==nil or source.phaseAfterDamage~=true
                or preDamageCards[source.guid]==true) then
            unavailable[source.guid]=true
        end
    end
    return unavailable
end

-- Only auto-discard unambiguously Attack-only staged physical cards.
-- Inspect ALL sources with the same physical GUID; no single split-target
-- resource is allowed to pull an earlier Block/Ranged/conditional card away.
combatConfig.knockoutStagedAttackCards=function(sources,unavailable,seat,phase)
    local protected,hasAttack={},{}
    for _,source in ipairs(sources or {}) do
        if source.kind=="card" and source.guid~=nil then
            local guid=source.guid
            if (source.attack or 0)>0 then hasAttack[guid]=true end
            if (source.block or 0)>0 or (source.move or 0)>0
                or (source.psychicInfluence or 0)>0
                or (source.ranged or 0)>0 or (source.siege or 0)>0
                or source.conditionalFireAttack~=nil
                or source.conditionalCounterattack~=nil then
                protected[guid]=true
            end
        end
    end
    local snapshot=phase or combatConfig.phasePreview
    for guid in pairs(snapshot~=nil and snapshot.objectKeys or {}) do
        protected[guid]=true
    end
    for _,effect in pairs(snapshot~=nil and snapshot.enemyEffects or {}) do
        for _,applied in ipairs(effect.applied or {}) do
            if applied.source~=nil then protected[applied.source]=true end
        end
    end
    local scan=seat~=nil and resourceCardScanBySeat[seat] or nil
    for guid,record in pairs(scan~=nil and scan.cards or {}) do
        if record.kind=="card" then
            local data=gameCards~=nil and gameCards[guid] or nil
            local rule=data~=nil and cardResourceDefinitions~=nil
                and cardResourceDefinitions[data.resourceKey] or nil
            if record.complete~=true or record.status=="yellow"
                or #(record.links or {})>0 or record.enemyGUID~=nil
                or #(record.enemyEffectTargetKeys or {})>0
                or record.conditionalFireAttack~=nil
                or record.combatConversion~=nil
                or record.fameRep~=nil or record.defeatFameRep~=nil
                or (rule~=nil and (rule.enemyEffect~=nil
                    or rule.movementEffects~=nil
                    or rule.unitCombatBoost~=nil
                    or rule.preventUnitDamage==true)) then
                protected[guid]=true
            end
            -- "Pure Attack" means the currently selected, fully understood
            -- resource has no other usable family, even if the calculator
            -- only drew its Attack icon.
            for field,amount in pairs(record.resources or {}) do
                if type(field)=="string" and type(amount)=="number"
                    and amount>0 and field:sub(1,6)~="attack" then
                    protected[guid]=true
                    break
                end
            end
        end
    end
    local eligible={}
    for guid in pairs(hasAttack) do
        local record=scan~=nil and scan.cards or nil
        if unavailable[guid]==true and protected[guid]~=true
            and record~=nil and record[guid]~=nil
            and record[guid].complete==true then
            local obj=getObjectFromGUID(guid)
            local data=gameCards~=nil and gameCards[guid] or nil
            if obj~=nil and obj.type=="Card" and obj.is_face_down~=true
                and obj.getGMNotes~=nil and obj.getGMNotes()~="Wound"
                and data~=nil and data.cardType~="Artifact" then
                eligible[#eligible+1]=guid
            end
        end
    end
    table.sort(eligible)
    return eligible
end

combatConfig.attackPhaseSources=function(sources,wounded,paralysisCards)
    local active={}
    for _,source in ipairs(sources or {}) do
        if wounded[source.guid]~=true and not source.noAttackPhase
            and not (paralysisCards~=nil and paralysisCards[source.guid]==true) then
            active[#active+1]=source
        end
    end
    return active
end

-- Timing of self-wounding Unit abilities: a Block wounds its Unit before
-- enemies may assign damage; an Attack wounds its Unit in the final Attack
-- phase, after enemy damage. Only Units with an activated, targeted ability
-- receive a preview. Other modifiers used earlier retain their effects.
combatConfig.selfWoundingUnitChoices=function(seat,groups)
    local early,late={},{}
    local active={}
    for _,group in ipairs(groups or {}) do
        if not group.rangeDefeated and not group.destroyed then
            for _,source in ipairs(group.sources or {}) do
                if source.key~=nil then active[source.key]=true end
            end
        end
    end
    local scan=seat~=nil and resourceCardScanBySeat[seat] or nil
    local records=scan~=nil and scan.cards or {}
    local activations=gStates~=nil and gStates.unitResourceActivations or {}
    for guid,currentActivation in pairs(activations) do
        local abilities=unitResourceDefinitions~=nil and unitResourceDefinitions[guid] or nil
        if currentActivation.seatPos==seat and abilities~=nil then
            for useIndex,activation in ipairs(unitHistoryUses(guid,currentActivation)) do
                local key=unitHistoryKey(guid,useIndex)
                local record=records[key]
                local unit=getObjectFromGUID(guid)
                local decision=unit~=nil and unitManaDecision(unit,abilities,activation,
                    activation.frozenCounts or activation.lastCounts) or nil
                local ability=decision~=nil and abilities[decision.index] or nil
                if active[key] and record~=nil and record.complete==true
                    and ability~=nil and ability.woundsSelf==true then
                    local blocks=false
                    for field,value in pairs(ability) do
                        if type(value)=="number" and type(field)=="string"
                            and field:sub(1,5)=="block" then blocks=true break end
                    end
                    if blocks then early[guid]=true else late[guid]=true end
                end
            end
        end
    end
    return early,late
end

-- Explosive Bolt effects are gained as Ranged groups fall. Apply their
-- Armour reduction *within* that phase so a second Ranged/Siege attack may
-- defeat another enemy, and carry the reduction into the later Attack phase.
-- A fixed-point pass only unlocks a new bonus after an independently legal
-- Ranged/Siege defeat; two attacks that both need the other's bonus cannot
-- manufacture a kill. Each defeated enemy grants -1 even under Maximal Effect.
combatConfig.applyExplosiveBoltRange=function(entries,groups,allocated,sources)
    local active={}
    for _,source in ipairs(sources) do
        if (tonumber(source.explosiveBolt) or 0)>0 then
            active[#active+1]=source
        end
    end
    if #active==0 then return end
    local preview={}
    for i,entry in ipairs(entries) do
        local copy={}
        for key,value in pairs(entry) do copy[key]=value end
        preview[i]=copy
    end
    combatApplyDefend(preview,groups,allocated)
    local rangedVictims,finished,earned={}, {}, {}
    local appliedBySource={}
    local function groupRange(group)
        local members,assigned={},{}
        for _,index in ipairs(group.members) do
            members[#members+1]=preview[index]
            for _,source in ipairs((allocated[index] or {sources={}}).sources) do
                assigned[#assigned+1]=source
            end
        end
        local total,armour,dead,fort=combatRangeResult(
            combatRangeGroupEntry(members),assigned)
        if members[1].attackOnly then dead=false end
        return dead,fort,assigned
    end
    local function linkedTarget(source)
        local key=source.guid.."#explosiveAttack"
        local targetGUID=combatAssignmentState.targets[key]
        if targetGUID==nil then
            for guid in pairs(attackAssignmentsTargetGUIDs(key)) do
                if targetGUID==nil or guid<targetGUID then targetGUID=guid end
            end
        end
        for _,entry in ipairs(entries) do
            if entry.guid==targetGUID then return entry,key,true end
        end
        -- Deterministic left-to-right default, not an enemy already defeated.
        for _,entry in ipairs(entries) do
            if not entry.attackOnly and not entry.destroyed and not entry.preview
                and not rangedVictims[entry.guid] then
                return entry,key,false
            end
        end
        return nil,key,false
    end
    for _=1,#groups+1 do
        for _,group in ipairs(groups) do
            if not finished[group] then
                local dead,fort,assigned=groupRange(group)
                if dead then
                    finished[group]=true
                    local count=0
                    for _,index in ipairs(group.members) do
                        local enemy=entries[index]
                        if not enemy.preview and not enemy.attackOnly then
                            rangedVictims[enemy.guid]=true
                            count=count+1
                        end
                    end
                    if count>0 then
                        local seen={}
                        for _,source in ipairs(assigned) do
                            if (tonumber(source.explosiveBolt) or 0)>0
                                and not seen[source.guid]
                                and ((source.ranged>0 and fort==0)
                                    or (source.siege>0 and fort<2)) then
                                seen[source.guid]=true
                                earned[source.guid]=(earned[source.guid] or 0)+count
                            end
                        end
                    end
                end
            end
        end
        local changed=false
        for _,source in ipairs(active) do
            local target,key,locked=linkedTarget(source)
            if target~=nil then
                if not locked and not attackAssignmentsIsTargeting(key) then
                    attackAssignmentsEnsureTarget(key,target.guid,"armour")
                end
                local already=appliedBySource[source.guid] or 0
                local desired=(earned[source.guid] or 0)*(source.explosiveBolt or 0)
                local immune=combatEnemyHasTrait(target.data,target.perks,"fResist")
                    or combatEnemyHasTrait(target.data,target.perks,"arcaneImmunity")
                local valid=not target.attackOnly and not target.destroyed
                    and not rangedVictims[target.guid] and not immune
                local delta=valid and math.min(math.max(0,desired-already),
                    math.max(0,target.baseArmour-1)) or 0
                if delta>0 then
                    appliedBySource[source.guid]=already+delta
                    local other=nil
                    for i,enemy in ipairs(entries) do
                        if enemy.guid==target.guid then
                            other=preview[i]
                            break
                        end
                    end
                    -- Update both the real later-Attack Armour and the Ranged
                    -- preview. Defender's Ranged bonus lives on the preview.
                    for _,member in ipairs({target,other}) do
                        if member~=nil then
                            member.rangeBaseArmour=math.max(1,
                                (member.rangeBaseArmour or member.baseArmour)-delta)
                            member.rangeElusiveArmour=math.max(1,
                                (member.rangeElusiveArmour or member.elusiveArmour)-delta)
                            member.baseArmour=math.max(1,member.baseArmour-delta)
                            member.elusiveArmour=math.max(1,member.elusiveArmour-delta)
                        end
                    end
                    target.effectArmourReduction=(target.effectArmourReduction or 0)+delta
                    changed=true
                end
            end
        end
        if not changed then break end
    end
    -- Report the earned amount, even if immunity or the Armour floor makes
    -- some of it ineffective. Effects retain a separate target/control.
    for _,source in ipairs(active) do
        local target,key,locked=linkedTarget(source)
        if target~=nil then
            local amount=(earned[source.guid] or 0)*(source.explosiveBolt or 0)
            local applied=appliedBySource[source.guid] or 0
            local immune=combatEnemyHasTrait(target.data,target.perks,"fResist")
                or combatEnemyHasTrait(target.data,target.perks,"arcaneImmunity")
            local reason=nil
            if applied==0 then
                reason=amount==0 and "No enemy defeated by this Ranged Attack."
                    or rangedVictims[target.guid] and "Target was defeated by a Ranged Attack."
                    or immune and "Fire Resistance or Arcane Immunity prevents this Armour reduction."
                    or target.attackOnly and "This enemy has no Armour."
                    or "Armour is already at its minimum of 1."
            end
            target.explosiveBoltEffects=target.explosiveBoltEffects or {}
            target.explosiveBoltEffects[#target.explosiveBoltEffects+1]={
                key=key,guid=source.guid,earned=amount,applied=applied,reason=reason}
        end
    end
end

-- TTS does not expose Unity's measured text width to Lua. Estimate 13px
-- display text by glyph type (and UTF-8 codepoint, not byte count), with
-- room for margins, so even long or translated enemy names stay readable.
combatConfig.enemyNameColumnWidth=function(label)
    label=tostring(label or "")
    local width=18
    for i=1,#label do
        local byte=label:byte(i)
        if byte<128 then
            local char=label:sub(i,i)
            if char==" " then width=width+5
            elseif char=="i" or char=="l" or char=="I" or char=="t"
                or char=="f" or char=="r" or char=="j" or char=="1"
                or char=="'" or char=="." or char=="," then width=width+5
            elseif char=="M" or char=="W" or char=="m" or char=="w"
                or char=="@" then width=width+12
            elseif char:match("%u") then width=width+10
            else width=width+8 end
        elseif byte>=240 and byte<248 then width=width+17
        elseif byte>=224 and byte<240 then width=width+15
        elseif byte>=192 and byte<224 then width=width+10
        end
    end
    return math.max(74,math.ceil(width))
end

-- Defensive abilities are displayed on separate lines. Measure only the
-- longest visible line (ignoring TTS rich-text colours), not their total length.
-- This keeps short entries compact while allowing long abilities to fit.
combatConfig.traitColumnWidth=function(traits)
    local width=78
    for _,text in pairs(traits or {}) do
        local plain=tostring(text or ""):gsub("<[^>]+>","")
        for line in plain:gmatch("[^\n]+") do
            width=math.max(width,combatConfig.enemyNameColumnWidth(line))
        end
    end
    return width
end

local function combatAssignmentRefreshRows(entries,sources)
    combatConfig.resultRowCache={}
    combatConfig.slotSelection={}
    combatConfig.effectSources={}
    local rowByGUID={}
    local totalRowHeight=0
    local grandDamage,damageSources=0,0
    combatAssignmentRowTargets={}
    combatAssignmentRowIndices={}
    local pageSize=#entries>combatConfig.crowdedPageSize
        and combatConfig.crowdedPageSize or combatConfig.rowCount
    -- Keep joined groups together on a page whenever they fit. Combat math always
    -- covers every enemy; paging only controls which rows are displayed.
    local pageStarts,pageEnds={},{}
    local nextStart=1
    while nextStart<=#entries do
        local finish=math.min(#entries,nextStart+pageSize-1)
        if finish<#entries then
            local boundary=finish
            while boundary>nextStart do
                local nextEnemy=entries[boundary+1]
                if combatAssignmentJoined[nextEnemy.guid]~=true
                    or entries[boundary].destroyed or nextEnemy.destroyed
                    or entries[boundary].attackOnly or nextEnemy.attackOnly then break end
                boundary=boundary-1
            end
            -- Oversized groups can span pages; never leave a page empty.
            if boundary>nextStart then finish=boundary end
        end
        pageStarts[#pageStarts+1]=nextStart
        pageEnds[#pageEnds+1]=finish
        nextStart=finish+1
    end
    local pages=math.max(1,#pageStarts)
    combatEnemyPage=math.max(1,math.min(combatEnemyPage,pages))
    local pageOffset=(pageStarts[combatEnemyPage] or 1)-1
    local pageEnd=pageEnds[combatEnemyPage] or 0
    local visibleRows=pageEnd-pageOffset
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
    local overflow=0
    local maxResourceCounts={range=0,block=0,attack=0}
    -- Text shown in the ability columns and the columns that hold anything, so empty columns can be hidden.
    local shownTraits,shownOffence,shownAttacks,colUsed={},{},{},{range=false,block=false,attack=false}
    -- Joined enemies form a group (the leader is its first row) that is attacked as one.
    local groups,groupOf={},{}
    for index=1,#entries do
        local group=groups[#groups]
        if index==1 or combatAssignmentJoined[entries[index].guid]~=true
            or entries[index].destroyed or entries[index-1].destroyed
            or entries[index].attackOnly or entries[index-1].attackOnly then
            group={members={},sources={}}
            groups[#groups+1]=group
        end
        group.members[#group.members+1]=index
        group.leader=group.members[1]
        groupOf[index]=group
    end
    -- The name and header occupy one shared column. Size it from the longest
    -- name on this page, including the '+ ' prefix for a joined enemy.
    local enemyNameWidth=74
    for index=pageOffset+1,pageEnd do
        local entry=entries[index]
        local joined=groupOf[index]~=nil and groupOf[index].leader~=index
        local label=(joined and "+ " or "")..tostring(entry.name or "")
        enemyNameWidth=math.max(enemyNameWidth,combatConfig.enemyNameColumnWidth(label))
    end
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
                select(2,combatEnemyTraitsText(entry.data,entry.perks,combatConfig.enemyDefenceTraits):gsub("\n",""))+1)
            for column,width in pairs(combatConfig.columns) do
                combatPanelSetAttribute("CombatEnemyRow"..row..column,"preferredWidth",tostring(width))
            end
            entry.attackCount=math.max(#attacks,traitLines)
        end
    end

    combatAssignmentSlotSources={}
    combatConfig.slotBowFamilies={}
    local allocated={}
    for _,source in ipairs(sources) do
        local moveOnly=source.ranged+source.siege+source.block+source.attack==0
            and source.psychicInfluence==0
        local influenceOnly=source.ranged+source.siege+source.block+source.attack==0
            and source.psychicInfluence>0 and source.move==0
        -- Explicit calculator targets remain authoritative. If none exists,
        -- the saved arrow is recovered below (including after reload).
        local targetGUID=combatAssignmentState.targets[source.key]
        if targetGUID==nil then
            -- Restore the saved visual assignment for every source after a reload.
            -- Persisted/manual assignments win over nearest-enemy defaults.
            for guid in pairs(attackAssignmentsTargetGUIDs(source.key)) do
                if rowByGUID[guid]~=nil then
                    targetGUID=guid
                    combatAssignmentState.targets[source.key]=guid
                    combatAssignmentState.explicit[source.key]=true
                    break
                end
            end
        end
        local targetIndex=targetGUID~=nil and rowByGUID[targetGUID] or nil
        if targetIndex~=nil and source.possessExclude==targetGUID then
            combatAssignmentState.targets[source.key]=nil
            combatAssignmentState.explicit[source.key]=nil
            attackAssignmentsClearForObject(source.key)
            targetGUID,targetIndex=nil,nil
        end
        if source.forkedLightning and targetIndex~=nil
            and not resourceCardsCombatTargetAcceptsSource(source.key,targetGUID) then
            combatAssignmentState.targets[source.key]=nil
            combatAssignmentState.explicit[source.key]=nil
            attackAssignmentsClearForObject(source.key)
            targetGUID,targetIndex=nil,nil
        end
        if targetIndex~=nil and entries[targetIndex].attackOnly
            and source.ranged+source.siege+source.attack>0 then
            combatAssignmentState.targets[source.key]=nil
            combatAssignmentState.explicit[source.key]=nil
            attackAssignmentsClearForObject(source.key)
            targetGUID,targetIndex=nil,nil
        end
        if moveOnly and targetGUID~=nil and not combatGUIDHasCumbersome(targetGUID) then
            -- Move can only be aimed at a Cumbersome enemy.
            combatAssignmentState.targets[source.key]=nil
            combatAssignmentState.explicit[source.key]=nil
            attackAssignmentsClearForObject(source.key)
            targetGUID,targetIndex=nil,nil
        end
        -- Combat Move is a deliberate phase choice, unlike ordinary movement.
        -- Its nearest eligible Cumbersome enemy gets the same initial arrow
        -- and lock as other combat sources. A manually assigned target wins.
        -- Mark this automatic Move lock allocated so its points actually
        -- reduce Cumbersome and are reserved from Agility conversion.
        local autoCombatMove=moveOnly and source.move>0 and combatCumbersomeActive
        if targetIndex==nil and (autoCombatMove or (not moveOnly and not influenceOnly)) then
            targetGUID=combatNearestEnemyGUID(source,entries,
                autoCombatMove and combatGUIDHasCumbersome or nil)
            combatAssignmentState.targets[source.key]=targetGUID
            combatAssignmentState.explicit[source.key]=autoCombatMove and targetGUID~=nil or nil
            targetIndex=targetGUID~=nil and rowByGUID[targetGUID] or nil
        end
        if targetIndex==nil and targetGUID~=nil then
            combatAssignmentState.targets[source.key]=nil
            combatAssignmentState.explicit[source.key]=nil
        end
        if targetIndex~=nil then
            -- The arrow follows the lock, and returns if a cancelled retarget removed it.
            if not attackAssignmentsIsTargeting(source.key) then
                attackAssignmentsEnsureTarget(source.key,targetGUID,combatSourceArrowKind(source))
            end
            local manuallyTargeted=combatAssignmentState.explicit[source.key]==true
            local explicit=manuallyTargeted and combatGUIDHasCumbersome(targetGUID)
            source.moveCounts=explicit
            source.psychicInfluenceCounts=manuallyTargeted
                and source.psychicInfluence>0 and (function()
                    for _,attack in ipairs(combatEnemyAttacks(entries[targetIndex])) do
                        if attack.key=="M" then return true end
                    end
                    return false
                end)()
            local target=allocated[targetIndex]
            if target==nil then
                target={range={},block={},attack={},sources={},details={}}
                allocated[targetIndex]=target
            end
            if source.dueling then
                -- A target with no Block phase cannot receive Dueling's later Attack.
                source.duelingEligible=false
                for _,attack in ipairs(combatEnemyAttacks(entries[targetIndex])) do
                    if not attack.pending then source.duelingEligible=true break end
                end
            end
            if source.convertedResource~=nil then
                -- A right-click adds an arrow to another enemy. Each extra
                -- arrow spends ONE converted point, never a second full pool.
                local counts=attackAssignmentsTargetCounts(source.key)
                local other={}
                for guid in pairs(counts) do
                    if guid~=targetGUID and rowByGUID[guid]~=nil then other[#other+1]=guid end
                end
                table.sort(other)
                local remaining=source.convertedAmount
                for _,guid in ipairs(other) do
                    local amount=math.min(remaining,counts[guid])
                    if amount>0 then
                        local family=source.convertedFamily
                        local key=source.convertedResource
                        local detail=source.details[1]
                        local portion={guid=source.guid,key=source.key,name=source.name,
                            ranged=family=="ranged" and amount or 0,
                            siege=family=="siege" and amount or 0,
                            attack=family=="attack" and amount or 0,
                            block=family=="block" and amount or 0,move=0,
                            psychicInfluence=0,resources={[key]=amount},
                            details={{text=key.." "..amount,amount=amount,
                                key=key,icon=detail~=nil and detail.icon or "MKChoiceAttack",
                                family=family,typeKey=detail~=nil and detail.typeKey or "P"}}}
                        local index=rowByGUID[guid]
                        local extra=allocated[index]
                        if extra==nil then
                            extra={range={},block={},attack={},sources={},details={}}
                            allocated[index]=extra
                        end
                        extra.sources[#extra.sources+1]=portion
                        extra.details[#extra.details+1]={source=portion,detail=portion.details[1]}
                        remaining=remaining-amount
                    end
                end
                source[source.convertedFamily]=remaining
                source.resources[source.convertedResource]=remaining
                if remaining>0 and source.details[1]~=nil then
                    source.details[1].amount=remaining
                    source.details[1].text=source.convertedResource.." "..remaining
                else
                    source.details={}
                end
            end
            target.sources[#target.sources+1]=source
            for _,detail in ipairs(source.details) do
                if (detail.family~="move" or explicit)
                    and (detail.family~="influence" or source.psychicInfluenceCounts) then
                    target.details[#target.details+1]={source=source,detail=detail}
                end
            end
            if source.moveCounts and (source.move or 0)>0 then
                -- Primary target receives the remaining Cumbersome Move.
                -- Each extra arrow transfers one point to another Cumbersome
                -- enemy, exactly as divisible Psychic Influence does.
                local counts=attackAssignmentsTargetCounts(source.key)
                local other={}
                for guid in pairs(counts) do
                    if guid~=targetGUID and rowByGUID[guid]~=nil then
                        other[#other+1]=guid
                    end
                end
                table.sort(other)
                local remaining=source.move
                for _,guid in ipairs(other) do
                    if remaining<=0 then break end
                    if combatGUIDHasCumbersome(guid) then
                        local amount=math.min(counts[guid],remaining)
                        local portion={guid=source.guid,key=source.key,name=source.name,
                            ranged=0,siege=0,block=0,attack=0,
                            move=amount,moveCounts=true,
                            psychicInfluence=0,resources={move=amount},
                            details={{text="Move "..tostring(amount),amount=amount,
                                icon="MKChoiceMove",key="move",family="move"}}}
                        local index=rowByGUID[guid]
                        local extra=allocated[index]
                        if extra==nil then
                            extra={range={},block={},attack={},sources={},details={}}
                            allocated[index]=extra
                        end
                        extra.sources[#extra.sources+1]=portion
                        extra.details[#extra.details+1]={
                            source=portion,detail=portion.details[1]}
                        remaining=remaining-amount
                    end
                end
                source.move=remaining
                if source.resources~=nil then source.resources.move=remaining end
                for i=#target.details,1,-1 do
                    local item=target.details[i]
                    if item.source==source and item.detail.family=="move" then
                        if remaining<=0 then table.remove(target.details,i)
                        else
                            item.detail.amount=remaining
                            item.detail.text="Move "..tostring(remaining)
                        end
                    end
                end
            end
            if source.psychicInfluenceCounts then
                -- The primary left-click target initially receives all Influence.
                -- Each additional right-click arrow transfers one point; repeated
                -- arrows to the same enemy transfer more. No point is double-spent.
                local targetCounts=attackAssignmentsTargetCounts(source.key)
                local extraTargets={}
                for guid in pairs(targetCounts) do
                    if guid~=targetGUID and rowByGUID[guid]~=nil then
                        extraTargets[#extraTargets+1]=guid
                    end
                end
                table.sort(extraTargets)
                local remaining=source.psychicInfluence
                for _,guid in ipairs(extraTargets) do
                    if remaining<=0 then break end
                    local index=rowByGUID[guid]
                    local psychic=false
                    for _,attack in ipairs(combatEnemyAttacks(entries[index])) do
                        if attack.key=="M" then psychic=true break end
                    end
                    if psychic then
                        local amount=math.min(targetCounts[guid],remaining)
                        local portion={guid=source.guid,key=source.key,name=source.name.." (Influence)",
                            ranged=0,siege=0,block=0,attack=0,move=0,resources={},
                            psychicInfluence=amount,psychicInfluenceCounts=true,details={}}
                        local detail={text="Influence "..tostring(amount).." → Psychic Block",
                            amount=amount,icon="MKChoiceBlock",key="influence",family="influence"}
                        portion.details[1]=detail
                        local extra=allocated[index]
                        if extra==nil then
                            extra={range={},block={},attack={},sources={},details={}}
                            allocated[index]=extra
                        end
                        extra.sources[#extra.sources+1]=portion
                        extra.details[#extra.details+1]={source=portion,detail=detail}
                        remaining=remaining-amount
                    end
                end
                source.psychicInfluence=remaining
                for i=#target.details,1,-1 do
                    local item=target.details[i]
                    if item.source==source and item.detail.family=="influence" then
                        if remaining<=0 then table.remove(target.details,i)
                        else
                            item.detail.amount=remaining
                            item.detail.text="Influence "..tostring(remaining).." → Psychic Block"
                        end
                    end
                end
            end
        end
    end
    local effectOnly={}
    local seat=combatAssignmentActiveSeat()
    local currentScan=seat~=nil and resourceCardScanBySeat[seat] or nil
    for _,record in pairs(currentScan~=nil and currentScan.cards or {}) do
        for _,key in ipairs(record.enemyEffectTargetKeys or {}) do effectOnly[key]=true end
    end
    for key in pairs(combatAssignmentState.targets) do
        local active=effectOnly[key]==true
        for _,source in ipairs(sources) do
            if source.key==key then active=true break end
        end
        -- Enemy-effect Skills and Units are also real target sources even
        -- when they generate no numeric Attack or Block.
        if not active and not combatSourceKeepsLock(key) then
            combatAssignmentState.targets[key]=nil
            combatAssignmentState.explicit[key]=nil
        end
    end

    combatConfig.applyExplosiveBoltRange(entries,groups,allocated,sources)

    -- Flame Wave counts only enemies still faced in the Block/Attack phase.
    -- Resolve the Ranged/Siege preview (including Defender) first: summoned
    -- tokens and attack-only reminders are already excluded from entries.
    local flameWaveActive=false
    for _,source in ipairs(sources) do
        if source.flameWave then flameWaveActive=true break end
    end
    if flameWaveActive then
        local preview={}
        for i,entry in ipairs(entries) do
            local copy={}
            for key,value in pairs(entry) do copy[key]=value end
            preview[i]=copy
        end
        combatApplyDefend(preview,groups,allocated)
        local remaining=0
        for _,group in ipairs(groups) do
            local members,rangeSources={},{}
            for _,index in ipairs(group.members) do
                members[#members+1]=preview[index]
                for _,source in ipairs((allocated[index] or {sources={}}).sources) do
                    rangeSources[#rangeSources+1]=source
                end
            end
            local _,_,rangeDefeated=combatRangeResult(combatRangeGroupEntry(members),rangeSources)
            if not rangeDefeated then
                for _,member in ipairs(members) do
                    if not member.attackOnly and not member.destroyed then
                        remaining=remaining+1
                    end
                end
            end
        end
        for _,source in ipairs(sources) do
            if source.flameWave then
                local key=source.resources.attackFire~=nil and "attackFire"
                    or (source.resources.blockFire~=nil and "blockFire" or nil)
                if key~=nil then
                    local base=key=="attackFire" and 5 or 7
                    local amount=base+2*remaining
                    local previous=source.resources[key] or 0
                    local family=key=="attackFire" and "attack" or "block"
                    source.resources[key]=amount
                    source[family]=source[family]-previous+amount
                    for _,detail in ipairs(source.details) do
                        if detail.key==key then
                            detail.amount=amount
                            detail.text=(family=="attack" and "Fire Attack " or "Fire Block ")
                                ..tostring(amount)
                        end
                    end
                end
            end
        end
    end

    -- Complete the Ranged/Siege phase BEFORE resolving any "destroyed if
    -- blocked" effect. A preview uses shallow copies so Defender bonuses
    -- cannot be applied twice to the actual combat entries.
    local rangedBeforeBlock=nil
    local hasConditional=false
    for _,entry in ipairs(entries) do
        if not entry.destroyed then
            for _,applied in ipairs(entry.effect~=nil and entry.effect.applied or {}) do
                if applied.effective~=nil and (applied.effective.destroyIfBlocked==true
                    or applied.effective.destroyIfFullyBlocked==true) then
                    entry.explodePending=true
                    hasConditional=true
                    break
                end
            end
        end
    end
    if hasConditional then
        local preview={}
        for i,entry in ipairs(entries) do
            local copy={}
            for key,value in pairs(entry) do copy[key]=value end
            preview[i]=copy
        end
        combatApplyDefend(preview,groups,allocated)
        rangedBeforeBlock={}
        for _,group in ipairs(groups) do
            local members,sources={},{}
            for _,index in ipairs(group.members) do
                members[#members+1]=preview[index]
                for _,source in ipairs((allocated[index] or {sources={}}).sources) do
                    sources[#sources+1]=source
                end
            end
            local _,_,ranged=combatRangeResult(combatRangeGroupEntry(members),sources)
            if ranged and not members[1].attackOnly then
                for _,index in ipairs(group.members) do rangedBeforeBlock[index]=true end
            end
        end
    end

    -- Only enemies surviving Ranged/Siege can be destroyed in the Block phase.
    local conditionalDestroyed=false
    for index=1,#entries do
        local entry=entries[index]
        if entry.explodePending and not entry.destroyed
            and (rangedBeforeBlock==nil or rangedBeforeBlock[index]~=true) then
            local hasAttack=false
            for _,attack in ipairs(combatEnemyAttacks(entry)) do
                if not attack.pending and attack.value>0 then hasAttack=true break end
            end
            if hasAttack then
                local target=allocated[index]
                local _,_,_,allBlocked,_,_,_,successfulSources,successfulOwners=
                    combatBlockResult(entry,target~=nil and target.sources or {})
                local explodedEnemy=false
                for _,applied in ipairs(entry.effect~=nil and entry.effect.applied or {}) do
                    if combatEffectDestroysFullyBlocked(applied,allBlocked,hasAttack) then
                        explodedEnemy=true
                    elseif applied.effective~=nil and applied.effective.destroyIfBlocked==true
                        and successfulSources[applied.source]==true then
                        for owner in pairs(successfulOwners[applied.source] or {}) do
                            local token=owner==entry.guid and entry.data or monsterPugs[owner]
                            local perks=owner==entry.guid and entry.perks
                                or (gStates~=nil and gStates.monsterPerks~=nil
                                    and gStates.monsterPerks[owner] or nil)
                            -- Immunity belongs to the actual blocked token,
                            -- not to its summoner (which may have different traits).
                            local immune=token==nil
                                or combatEnemyHasTrait(token,perks,"arcaneImmunity")
                                or combatEnemyHasTrait(token,perks,"fResist")
                            if not immune and owner==entry.guid then
                                -- One successful Attack Block suffices even if
                                -- the token has other, unblocked attacks.
                                explodedEnemy=true
                            else
                                -- A blocked summoned monster is destroyed, NOT
                                -- its summoner, and never earns Fame by itself.
                                for _,summoned in ipairs(entry.summoned or {}) do
                                    if not immune and summoned.guid==owner then
                                        entry.summonedDestroyed=entry.summonedDestroyed or {}
                                        entry.summonedDestroyed[owner]=true
                                        break
                                    end
                                end
                            end
                        end
                    end
                end
                if explodedEnemy then entry.destroyed=true conditionalDestroyed=true end
            end
        end
    end
    if conditionalDestroyed then
        -- A newly destroyed member splits joined groups just like a pre-destroyed member.
        -- Keep group visuals and group memberships consistent with the resulting combat.
        groups,groupOf={},{}
        for index=1,#entries do
            local group=groups[#groups]
            if index==1 or combatAssignmentJoined[entries[index].guid]~=true
                or entries[index].destroyed or entries[index-1].destroyed
            or entries[index].attackOnly or entries[index-1].attackOnly then
                group={members={},sources={}}
                groups[#groups+1]=group
            end
            group.members[#group.members+1]=index
            group.leader=group.members[1]
            groupOf[index]=group
        end
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
    local rowBlock={}
    local defended=combatApplyDefend(entries,groups,allocated)
    local defendMarks={}
    for index,amount in pairs(defended) do defendMarks[entries[index].guid]=amount end
    combatSyncDefenderMark(defendMarks)
    -- Resolve Burning Shield's trigger across EVERY Block target before
    -- resolving any Attack target. The earned Fire Attack may then be aimed
    -- at a different enemy, even one that made no attack of its own.
    local burningShieldTriggered={}
    for index,entry in ipairs(entries) do
        local target=allocated[index] or emptyTarget
        local _,_,_,_,_,_,_,successfulSources=combatBlockResult(entry,target.sources)
        for _,source in ipairs(target.sources) do
            if source.conditionalFireAttack~=nil and source.block>0
                and successfulSources[source.guid]==true then
                burningShieldTriggered[source.guid]=true
            end
        end
    end
    for index in ipairs(entries) do
        local target=allocated[index]
        if target~=nil then
            for _,source in ipairs(target.sources) do
                if source.conditionalCounterattack~=nil then
                    local amount=burningShieldTriggered[source.guid]
                        and source.conditionalCounterattack or 0
                    source.attack=amount
                    source.resources.attackFire=amount
                    if amount<=0 then
                        -- Do not count or display a counterattack until the
                        -- generating Fire Block has actually succeeded.
                        for detailIndex=#target.details,1,-1 do
                            if target.details[detailIndex].source==source then
                                table.remove(target.details,detailIndex)
                            end
                        end
                        source.details={}
                    else
                        for _,detail in ipairs(source.details) do
                            if detail.key=="attackFire" then
                                detail.text="Fire Attack "..tostring(amount).." (successful Block)"
                            end
                        end
                    end
                end
            end
        end
    end
    local defeatFame,defeatRep=0,0
    -- Joined boss attacks may defeat an ordinary enemy or one head without
    -- defeating the whole group. Per-defeat bonuses count each actual kill,
    -- never every level removed from a still-living boss.
    local function defeatedCount(group,rangedOnly)
        local count=0
        for _,index in ipairs(group.members) do
            local entry=entries[index]
            if not entry.preview and not entry.attackOnly then
                local dead
                if group.bossSpecial then
                    dead=entry.rangeDead==true or (not rangedOnly and
                        (entry.attackDead==true or entry.attackPhaseDestroyed==true))
                else
                    dead=group.defeated and (not rangedOnly or group.rangeDefeated)
                end
                if dead then count=count+1 end
            end
        end
        return count
    end
    for _,group in ipairs(groups) do
        local members,blockedAll={},{}
        for _,index in ipairs(group.members) do
            local entry=entries[index]
            local target=allocated[index] or emptyTarget
            local lines,damage,count,allBlocked,reductions,wrongBlock,unblocked,_,_,shieldBashExcess,
                successfulSourceKeys,spentMoveKeys=combatBlockResult(entry,target.sources)
            rowBlock[index]={lines=lines,damage=damage,count=count,allBlocked=allBlocked,reductions=reductions,
                wrongBlock=wrongBlock,unblocked=unblocked,shieldBashExcess=shieldBashExcess,
                successfulSourceKeys=successfulSourceKeys,spentMoveKeys=spentMoveKeys,damageItems={}}
            blockedAll[entry.guid]=allBlocked
            members[#members+1]=entry
            for _,source in ipairs(target.sources) do
                group.sources[#group.sources+1]=source
            end
        end
        group.entry,group.attackArmour=combatGroupEntry(members,blockedAll)
        group.rangeTotal,group.rangeArmour,group.rangeDefeated,group.fortification=
            combatRangeResult(combatRangeGroupEntry(members),group.sources)
        if members[1].attackOnly then group.rangeDefeated=false end
        local plan=combatBossPhasePlan(group,entries,group.rangeTotal,"range",blockedAll)
        if plan~=nil then
            group.bossSpecial=true
            group.rangeSpent=plan.spent
            group.rangeDefeated=plan.full
            for _,index in ipairs(group.members) do
                local member=entries[index]
                member.bossRangeLevels=plan.reductions[member.guid] or 0
                member.rangeDead=plan.killed[member.guid]==true
            end
        end
        -- Disease resolves after Block, not during Ranged/Siege. Every attack
        -- of the actual enemy must be blocked; an immune enemy gets no effect.
        if not group.rangeDefeated then
            local diseaseChanged=false
            for _,index in ipairs(group.members) do
                local enemy=entries[index]
                local limit=enemy.effect~=nil and enemy.effect.armourSetIfBlocked or nil
                local blocked=rowBlock[index]
                if limit~=nil and blocked~=nil and blocked.allBlocked
                    and #combatEnemyAttacks(enemy)>0 and not enemy.attackOnly
                    and not enemy.destroyed then
                    enemy.rangeBaseArmour=enemy.rangeBaseArmour or enemy.baseArmour
                    enemy.rangeElusiveArmour=enemy.rangeElusiveArmour or enemy.elusiveArmour
                    enemy.baseArmour=math.min(enemy.baseArmour,limit)
                    enemy.elusiveArmour=math.min(enemy.elusiveArmour,limit)
                    diseaseChanged=true
                end
            end
            if diseaseChanged then
                group.entry,group.attackArmour=combatGroupEntry(members,blockedAll)
            end
        end
        -- Shield Bash lowers Armour only in the later Attack phase, and only
        -- after a successful Block against that enemy's own attack. A summoned
        -- monster's Block never lowers its summoner's Armour. Ice Resistance
        -- and Arcane Immunity ignore this non-Block effect, not the Block.
        if not group.rangeDefeated then
            local bashChanged=false
            for _,index in ipairs(group.members) do
                local enemy=entries[index]
                local excess=(rowBlock[index].shieldBashExcess or {})[enemy.guid] or 0
                if excess>0 and not enemy.attackOnly and not enemy.destroyed
                    and not combatEnemyHasTrait(enemy.data,enemy.perks,"iResist")
                    and not combatEnemyHasTrait(enemy.data,enemy.perks,"arcaneImmunity") then
                    local originalArmour=enemy.baseArmour
                    local originalElusive=enemy.elusiveArmour
                    local reducedArmour=math.max(1,originalArmour-excess)
                    local reducedElusive=math.max(1,originalElusive-excess)
                    if reducedArmour~=originalArmour or reducedElusive~=originalElusive then
                        enemy.rangeBaseArmour=enemy.rangeBaseArmour or originalArmour
                        enemy.rangeElusiveArmour=enemy.rangeElusiveArmour or originalElusive
                        enemy.baseArmour=reducedArmour
                        enemy.elusiveArmour=reducedElusive
                        bashChanged=true
                    end
                end
            end
            if bashChanged then
                group.entry,group.attackArmour=combatGroupEntry(members,blockedAll)
            end
        end
        if group.rangeDefeated then
            for _,source in ipairs(group.sources) do
                if source.dueling then source.duelingEligible=false end
            end
        end
        if rangedBeforeBlock~=nil and not group.bossSpecial then
            -- A later Block-phase destruction cannot retrospectively win the
            -- Ranged phase or create extra Ranged-only rewards.
            group.rangeDefeated=true
            for _,index in ipairs(group.members) do
                if rangedBeforeBlock[index]~=true then group.rangeDefeated=false break end
            end
        end
        -- A destroyed enemy has already been removed by a pre-Damage effect.
        -- Its final defeat state and any melee rewards are resolved only after
        -- the damage assignments establish which Units survive into Attack.
        group.destroyed=not members[1].attackOnly and #group.members==1
            and entries[group.members[1]].destroyed==true
    end
    -- Snapshot resolved Ranged/Siege and Block before the Damage phase.
    -- Results, not just UI labels, are retained for later recalculations.
    local earlyLock=combatPhaseLock(combatAssignmentActiveSeat())
    if earlyLock~=nil and earlyLock.earlyGroups~=nil then
        for index,group in ipairs(groups) do
            local saved=earlyLock.earlyGroups[index]
            if saved~=nil then
                for _,field in ipairs({"rangeTotal","rangeArmour","rangeDefeated",
                    "rangeSpent","fortification","bossSpecial","attackArmour","destroyed"}) do
                    group[field]=saved[field]
                end
            end
        end
        for index,saved in ipairs(earlyLock.earlyEntries or {}) do
            if entries[index]~=nil then
                for field,value in pairs(saved) do
                    if field~="x" then entries[index][field]=combatFrozenCopy(value) end
                end
            end
        end
        rowBlock=combatFrozenCopy(earlyLock.rowBlock) or rowBlock
    elseif combatConfig.phasePreview~=nil then
        local preview=combatConfig.phasePreview
        preview.earlyGroups=combatFrozenCopy(groups)
        preview.earlyEntries=combatFrozenCopy(entries)
        preview.rowBlock=combatFrozenCopy(rowBlock)
        preview.spentRange={}
        -- A Damage commitment freezes the actual resources spent in earlier
        -- phases, not every Block icon laid out while planning combat.
        preview.sourceKeys={}
        preview.objectKeys={}
        local sourcesByKey={}
        for _,source in ipairs(preview.sources or {}) do
            sourcesByKey[source.key]=source
        end
        local function commitEarlySource(key)
            local source=sourcesByKey[key]
            if source==nil then return end
            preview.sourceKeys[key]=true
            preview.objectKeys[source.guid]=true
        end
        for _,group in ipairs(groups) do
            if group.rangeDefeated or group.rangeSpent then
                for _,source in ipairs(group.sources or {}) do
                    local legalRange=(source.ranged or 0)>0 and group.fortification==0
                    local legalSiege=(source.siege or 0)>0 and group.fortification<2
                    if legalRange or legalSiege then
                        preview.spentRange[source.key]=true
                        commitEarlySource(source.key)
                    end
                end
            end
        end
        for index,block in ipairs(rowBlock) do
            local group=groupOf[index]
            local enemy=entries[index]
            if group~=nil and not group.rangeDefeated and not group.destroyed
                and enemy~=nil and not enemy.rangeDead then
                for key in pairs(block.successfulSourceKeys or {}) do commitEarlySource(key) end
                for key in pairs(block.spentMoveKeys or {}) do commitEarlySource(key) end
            end
        end
    end
    -- Counterattack counts *enemies*, not individual attacks. Multi-attack
    -- enemies (including summoners) count only when every attack was blocked.
    -- Ranged-defeated and attack-only preview tokens never count.
    local blockedEnemies=0
    for _,group in ipairs(groups) do
        if not group.rangeDefeated then
            for _,index in ipairs(group.members) do
                local enemy=entries[index]
                if not enemy.attackOnly and not enemy.destroyed and not enemy.rangeDead
                    and rowBlock[index]~=nil and rowBlock[index].allBlocked
                    and #combatEnemyAttacks(enemy)>0 then
                    blockedEnemies=blockedEnemies+1
                end
            end
        end
    end
    local blockSeat=combatAssignmentActiveSeat()
    if blockSeat~=nil then
        local previousBlocked=combatConfig.blockedEnemyCounts[blockSeat] or 0
        combatConfig.blockedEnemyCounts[blockSeat]=blockedEnemies
        if previousBlocked~=blockedEnemies and resourceCardsSourceChanged~=nil then
            resourceCardsSourceChanged()
        end
    end
    -- Damage phase: each unblocked attack of an enemy that is not already defeated starts on the Hero.
    local damageSeat=combatAssignmentActiveSeat()
    local selfWoundsEarly,selfWoundsLate=combatConfig.selfWoundingUnitChoices(damageSeat,groups)
    local damageUnits,nativeCommandCount=combatDamageUnits(damageSeat)
    -- Block 6 (Utem Swordsmen) causes a Wound during Block, before any enemy
    -- damage assignment; do not allow that Unit to absorb an enemy attack.
    for guid in pairs(selfWoundsEarly) do
        if damageUnits[guid]~=nil then damageUnits[guid].wounded=true end
    end
    local damageSpec={attacks={},units={}}
    local damageItems={}
    for guid,unit in pairs(damageUnits) do
        if not unit.wounded then damageSpec.units[guid]=true end
    end
    for _,group in ipairs(groups) do
        if not group.rangeDefeated and not group.destroyed then
            for _,index in ipairs(group.members) do
                local unblocked=rowBlock[index].unblocked
                local last=0
                for attackIndex in pairs(unblocked) do last=math.max(last,attackIndex) end
                for attackIndex=1,last do
                    local info=unblocked[attackIndex]
                    if info~=nil and info.attack.owner~=nil
                        and not entries[index].rangeDead then
                        local attack=info.attack
                        local item={key=attack.owner..":"..tostring(attack.slot),owner=attack.owner,type=attack.key,
                            damage=info.damage,poison=attack.poison,paralyse=attack.paralyse,
                            assassination=attack.assassination,firstDamageUnit=attack.firstDamageUnit}
                        damageItems[#damageItems+1]=item
                        rowBlock[index].damageItems[attackIndex]=item
                        damageSpec.attacks[#damageSpec.attacks+1]={key=item.key,owner=item.owner,damage=item.damage,
                            assassination=item.assassination,firstDamageUnit=item.firstDamageUnit}
                    end
                end
            end
        end
    end
    attackAssignmentsDamageSync(damageSpec)
    local seatScan=damageSeat~=nil and resourceCardScanBySeat[damageSeat] or nil
    local hardeningRecord=seatScan~=nil and seatScan.cards["0688d8"] or nil
    local hardenedTarget=hardeningRecord~=nil and hardeningRecord.enemyGUID or nil
    local mitigation=nil
    if hardenedTarget~=nil then
        local selected=gStates~=nil and gStates.battleHardenedAttackKey or nil
        local available={}
        for _,item in ipairs(damageItems) do
            if item.owner==hardenedTarget
                or (gStates~=nil and gStates.attackedMonsters~=nil
                    and gStates.attackedMonsters[item.owner]~=nil
                    and gStates.attackedMonsters[item.owner][3]=="summoned"
                    and gStates.attackedMonsters[item.owner][4]==hardenedTarget) then
                available[item.key]=true
            end
        end
        -- An attack that was fully Blocked cannot consume Battle Hardened.
        if selected~=nil and not available[selected] then selected=nil end
        local rule=skillResourceDefinitions["0688d8"]
        local spec=rule~=nil and rule.damageMitigation or nil
        if spec~=nil then
            mitigation={owner=hardenedTarget,attackKey=selected,
                physical=spec.physical or 2,nonphysical=spec.nonphysical or 1}
        end
    end
    local elementRecord=seatScan~=nil and seatScan.cards["ae8673"] or nil
    local elementTarget=elementRecord~=nil and elementRecord.enemyGUID or nil
    local elementMitigation=nil
    if elementTarget~=nil then
        local selected=gStates~=nil and gStates.elementalResistanceAttackKey or nil
        local available={}
        for _,item in ipairs(damageItems) do
            if item.owner==elementTarget
                or (gStates~=nil and gStates.attackedMonsters~=nil
                    and gStates.attackedMonsters[item.owner]~=nil
                    and gStates.attackedMonsters[item.owner][3]=="summoned"
                    and gStates.attackedMonsters[item.owner][4]==elementTarget) then
                available[item.key]=true
            end
        end
        if selected~=nil and not available[selected] then selected=nil end
        elementMitigation={owner=elementTarget,attackKey=selected}
    end
    local damageResults=combatDamageResolve(damageItems,damageUnits,
        combatHeroArmour(nativeCommandCount),attackAssignmentsDamageTargetsOf,
        mitigation,elementMitigation,seatScan~=nil and seatScan.heroFirstWoundIgnored==true,
        gStates~=nil and gStates.combatWoundApplication~=nil
            and gStates.combatWoundApplication.seat==damageSeat
            and gStates.combatWoundApplication.applied or nil)
    if earlyLock~=nil and earlyLock.damageResults~=nil then
        damageResults=combatFrozenCopy(earlyLock.damageResults) or damageResults
    elseif combatConfig.phasePreview~=nil then
        combatConfig.phasePreview.damageResults=combatFrozenCopy(damageResults)
        if attackAssignmentsDamageSnapshot~=nil then
            combatConfig.phasePreview.damage=attackAssignmentsDamageSnapshot()
        end
    end

    -- Vampiric gains Armor for Wounds added to the Hero's hand and for each
    -- Unit its own non-Psychic attacks wound. Poison's extra discard/Unit
    -- Wounds do not double this bonus. Rebuild Attack-phase Armor only:
    -- Ranged/Siege kills and Block were settled before damage.
    local vampiricByOwner={}
    for _,item in ipairs(damageItems) do
        if item.type~="M" then
            local bonus=combatVampiricArmourGain(damageResults[item.key])
            if bonus>0 then
                vampiricByOwner[item.owner]=(vampiricByOwner[item.owner] or 0)+bonus
            end
        end
    end
    for _,group in ipairs(groups) do
        local changed=false
        local members,blockedAll={},{}
        for _,index in ipairs(group.members) do
            local entry=entries[index]
            local bonus=vampiricByOwner[entry.guid] or 0
            if bonus>0 and not entry.removeAbilities
                and combatEnemyHasTrait(entry.data,entry.perks,"vampiric") then
                entry.baseArmour=entry.baseArmour+bonus
                entry.elusiveArmour=entry.elusiveArmour+bonus
                changed=true
            end
            members[#members+1]=entry
            blockedAll[entry.guid]=rowBlock[index].allBlocked
        end
        if changed then
            group.entry,group.attackArmour=combatGroupEntry(members,blockedAll)
        end
    end

    -- Resolve newly played enemy-targeted effects in Attack only. Their
    -- source may not undo a committed Ranged kill, Block or Wound allocation.
    -- Pre-commit sources are excluded even if their physical cards move.
    if earlyLock~=nil and seatScan~=nil and combatEffectPostDamageSpecs~=nil then
        local committedSources={}
        for _,source in ipairs(earlyLock.sources or {}) do
            committedSources[source.guid]=true
        end
        for _,effect in pairs(earlyLock.enemyEffects or {}) do
            for _,item in ipairs(effect.applied or {}) do
                committedSources[item.source]=true
            end
        end
        local lateChanged=false
        for _,entry in ipairs(entries) do
            local latest=(seatScan.enemyEffects or {})[entry.guid]
            local committed=(earlyLock.enemyEffects or {})[entry.guid]
            local newEffects=combatEffectPostDamageSpecs(latest,committed,committedSources)
            for _,applied in ipairs(newEffects) do
                local spec=applied.effective or {}
                local contributes=false
                local fortified=combatEnemyFortificationCount(entry.data,entry.perks)>0
                    and not entry.stripFortify
                local reduction=fortified
                    and (tonumber(spec.armourReduceFortified)
                        or tonumber(spec.armourReduce) or 0)
                    or (tonumber(spec.armourReduce) or 0)
                local perResist=tonumber(spec.armourReduceByResist) or 0
                if perResist>0 then
                    for _,trait in ipairs({"pResist","fResist","iResist"}) do
                        if combatEnemyHasTrait(entry.data,entry.perks,trait) then
                            reduction=reduction+perResist
                        end
                    end
                end
                if reduction>0 then
                    entry.baseArmour=math.max(1,entry.baseArmour-reduction)
                    entry.elusiveArmour=math.max(1,entry.elusiveArmour-reduction)
                    entry.effectArmourReduction=(entry.effectArmourReduction or 0)+reduction
                    contributes=true
                end
                if spec.destroyDuringAttack==true or spec.destroy==true then
                    entry.attackPhaseDestroyed=true
                    contributes=true
                end
                if spec.removeResist==true then
                    entry.stripResist=true
                    contributes=true
                end
                if spec.removeFireResist==true then
                    entry.stripFireResist=true
                    contributes=true
                end
                if spec.removeTrait~=nil then
                    local updated=combatFrozenCopy(entry.data)
                    updated[spec.removeTrait]=spec.removeTrait=="defend" and 0 or false
                    entry.data=updated
                    contributes=true
                end
                if contributes then
                    entry.effect=entry.effect or {}
                    entry.effect.applied=entry.effect.applied or {}
                    local tagged=combatFrozenCopy(applied)
                    tagged.phaseAfterDamage=true
                    entry.effect.applied[#entry.effect.applied+1]=tagged
                    lateChanged=true
                end
            end
        end
        if lateChanged then
            for _,group in ipairs(groups) do
                local members,blockedAll={},{}
                for _,index in ipairs(group.members) do
                    members[#members+1]=entries[index]
                    blockedAll[entries[index].guid]=rowBlock[index].allBlocked
                end
                group.entry,group.attackArmour=combatGroupEntry(members,blockedAll)
            end
        end
    end

    -- Damage is earlier than Attack. Do not invalidate Ranged/Siege kills or
    -- The player still confirms Wounds received outside calculated Damage.
    local dodgeWounded=false
    for _,result in pairs(damageResults) do
        if (tonumber(result.heroWounds) or 0)>0 then dodgeWounded=true break end
    end
    if dodgeWounded then
        for _,source in ipairs(sources) do
            if source.dodgeConditional then
                source.attack=0
                source.dodgeIneligible=true
                if source.resources~=nil then source.resources.attack=0 end
            end
        end
    end
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
    attackAssignmentsUnitPreviewSync(damageSeat,damageResults,selfWounds)
    -- Tornado resolves after enemy Damage. A grouped target is removed from
    -- only the later Attack calculation; surviving group members keep Armour.
    for _,group in ipairs(groups) do
        if not group.rangeDefeated and not group.destroyed then
            local surviving,blockedAll={},{}
            for _,index in ipairs(group.members) do
                local entry=entries[index]
                if not entry.attackPhaseDestroyed and not entry.rangeDead then
                    surviving[#surviving+1]=entry
                    blockedAll[entry.guid]=rowBlock[index].allBlocked
                end
            end
            if #surviving==0 then
                group.destroyed=true
            elseif #surviving<#group.members then
                group.entry,group.attackArmour=combatGroupEntry(surviving,blockedAll)
            end
        end
    end
    for _,group in ipairs(groups) do
        local available=combatConfig.attackPhaseSources(group.sources,woundedBeforeAttack,paralysisAttackCards)
        local meleeSources={}
        for _,source in ipairs(available) do
            if not source.forkedLightning
                or (gStates~=nil and gStates.forkedLightningPhase=="attack") then
                meleeSources[#meleeSources+1]=source
            end
        end
        -- Ranged/Siege points that already reduced a boss cannot be played
        -- as melee Attack a second time. Unspent ranged resources still have
        -- their ordinary fallback to the later Attack phase.
        local laterSources=meleeSources
        if group.bossSpecial and group.rangeSpent then
            laterSources={}
            for _,source in ipairs(meleeSources) do
                local resources={}
                for key,value in pairs(source.resources or {}) do
                    local spent=(key:sub(1,6)=="ranged" and group.fortification==0)
                        or (key:sub(1,5)=="siege" and group.fortification<2)
                    if not spent then resources[key]=value end
                end
                laterSources[#laterSources+1]=setmetatable({resources=resources},{__index=source})
            end
        end
        local meleeTotal=combatAttackTotal({
            {sources=laterSources,category="attack"},
            {sources=laterSources,category="ranged"},
            {sources=laterSources,category="siege"}},group.entry.data,group.entry.perks,"attack")
        group.attackTotal=meleeTotal
        group.defeated=not entries[group.members[1]].attackOnly
            and (group.rangeDefeated or (meleeTotal>0 and meleeTotal>=group.attackArmour))
        if group.bossSpecial then
            local blockedAll={}
            for _,index in ipairs(group.members) do
                blockedAll[entries[index].guid]=rowBlock[index].allBlocked
            end
            local plan=not group.rangeDefeated
                and combatBossPhasePlan(group,entries,meleeTotal,"attack",blockedAll) or nil
            for _,index in ipairs(group.members) do
                local member=entries[index]
                member.bossAttackLevels=plan~=nil and (plan.reductions[member.guid] or 0) or 0
                member.attackDead=plan~=nil and plan.killed[member.guid]==true
            end
            group.defeated=group.rangeDefeated or (plan~=nil and plan.full==true)
        end
        if group.destroyed then group.defeated,group.rangeDefeated=true,false end
        if (group.defeated or group.bossSpecial) and not group.destroyed then
            local count=defeatedCount(group,false)
            local rangedCount=defeatedCount(group,true)
            local counted={}
            for _,source in ipairs(group.sources) do
                local spec=source.defeatFameRep
                local availableInFinalPhase=woundedBeforeAttack[source.guid]~=true
                if count>0 and spec~=nil and spec.scope==nil
                    and not counted[source.guid] and (
                        (rangedCount>0 and (source.ranged>0 or source.siege>0))
                        or (count>rangedCount and availableInFinalPhase)) then
                    counted[source.guid]=true
                    local times=spec.once and 1 or count
                    defeatFame=defeatFame+(spec.fame or 0)*times
                    defeatRep=defeatRep+(spec.rep or 0)*times
                end
            end
        end
    end
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
    local trackedGuids,defeatedGuids,partialGuids={},{},{}
    for _,group in ipairs(groups) do
        for _,index in ipairs(group.members) do
            local entry=entries[index]
            local guid=entry.guid
            if not entry.attackOnly and not entry.preview then
                trackedGuids[guid]=true
                if group.defeated or entry.rangeDead or entry.attackDead
                    or (not group.rangeDefeated and entry.attackPhaseDestroyed) then
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
    -- Build all grouped rows before paging or rendering them. A group can
    -- span pages, and each following member offers two six-icon display lines.
    -- Only the button placement changes; allocated sources stay on their targets.
    local mitigationRecords={}
    for guid,record in pairs(seatScan~=nil and seatScan.cards or {}) do
        local rule=skillResourceDefinitions[guid]
        if rule~=nil and rule.damageMitigation~=nil and record.enemyGUID~=nil then
            mitigationRecords[#mitigationRecords+1]={guid=guid,record=record}
        end
    end
    local displayByIndex={}
    for _,group in ipairs(groups) do
        local perMember={}
        for _,index in ipairs(group.members) do
            local lists={range={},block={},attack={}}
            for _,item in ipairs((allocated[index] or emptyTarget).details) do
                if item.detail.family=="block" or item.detail.family=="move"
                    or item.detail.family=="influence" then
                    lists.block[#lists.block+1]={source=item.source,amount=item.detail.amount,
                        icon=item.detail.icon,text=item.detail.text,typeKey=item.detail.typeKey,
                        reduced=rowBlock[index].wrongBlock[item.source.key..tostring(item.detail.key)]==true}
                end
                if item.detail.family~="block" and item.detail.family~="move" then
                    local phase=combatDetailPhase(item.detail,
                        group.rangeDefeated or group.rangeSpent,group.fortification,item.source)
                    -- Keep invalidated Attack-phase Unit icons visible so players
                    -- can see what was assigned, but make the unavailable value grey
                    -- and explain why it does not count. Earlier Ranged/Block stands.
                    local wounded=phase=="attack" and (woundedBeforeAttack[item.source.guid]==true
                        or item.source.dodgeIneligible==true)
                    local paralysisCard=phase=="attack"
                        and paralysisAttackCards[item.source.guid]==true
                    if phase~=nil then
                        lists[phase][#lists[phase]+1]={source=item.source,amount=item.detail.amount,
                            icon=item.detail.icon,text=item.detail.text,typeKey=item.detail.typeKey,
                            reduced=combatEnemyResists(group.entry.data,group.entry.perks,item.detail.typeKey),
                            wounded=wounded,paralysisCard=paralysisCard,ineffective=paralysisCard}
                    end
                end
            end
            perMember[index]=lists
        end
        local distributed,hidden=combatGroupResourceRows(group.members,perMember,combatConfig.slotCount)
        for index,lists in pairs(distributed) do displayByIndex[index]=lists end
        overflow=overflow+hidden
        -- Numeric Ranged/Attack sources may flow through joined enemies, but
        -- enemy effects always stay on the row of the enemy they actually target.
        -- Put them first so the control stays visible even when a row is crowded.
        for _,index in ipairs(group.members) do
            local targetEntry=entries[index]
            local lists=displayByIndex[index]
            local function insertEffect(item)
                if item==nil then return end
                local buttons=lists[item.family]
                table.insert(buttons,1,item)
                if #buttons>combatConfig.slotCount then
                    table.remove(buttons)
                    overflow=overflow+1
                end
                combatConfig.effectSources[item.source.key]={arrow=item.arrow}
            end
            for _,applied in ipairs(targetEntry.effect~=nil and targetEntry.effect.applied or {}) do
                local effectButton=combatConfig.effectButtonInfo(targetEntry,applied)
                if effectButton~=nil and applied.phaseAfterDamage then
                    effectButton.family="attack"
                    effectButton.tooltip=(effectButton.tooltip or "")
                        .."\nPlayed after Damage; Ranged/Siege and Block are locked."
                end
                insertEffect(effectButton)
            end
            -- The extra target from Explosive Bolt is an Armour effect, not
            -- more Ranged Attack. Red/grey states explain unmet conditions.
            for _,bolt in ipairs(targetEntry.explosiveBoltEffects or {}) do
                insertEffect({source={guid=bolt.guid,key=bolt.key,name="Explosive Bolt"},
                    family="attack",arrow="armour",amount="-"..tostring(bolt.earned),
                    icon="MKChoiceArmourReduction",
                    text="Armour -"..tostring(bolt.earned).." after Ranged defeat (min 1)",
                    tooltip="Explosive Bolt: "..(bolt.reason or
                        ("Applied Armour reduction: "..tostring(bolt.applied)))
                        .."\nClick to retarget this effect separately from its Ranged Attack.",
                    ineffective=bolt.reason~=nil})
            end
            -- Damage mitigation is a Block-column control, but not Block points.
            for _,mitigationSource in ipairs(mitigationRecords) do
                if mitigationSource.record.enemyGUID==targetEntry.guid then
                    insertEffect(combatConfig.mitigationButtonInfo(mitigationSource.guid,
                        mitigationSource.record,targetEntry,group,damageResults,
                        mitigationSource.guid=="ae8673" and elementMitigation or mitigation))
                end
            end
        end
    end
    for row=1,combatConfig.rowCount do
        local index=pageOffset+row
        local entry=row<=visibleRows and entries[index] or nil
        local group=entry~=nil and groupOf[index] or nil
        local lists=displayByIndex[index] or {range={},block={},attack={}}
        local resourceLines=1
        for _,family in ipairs({"range","block","attack"}) do
            local items=lists[family]
            if entry~=nil and #items>0 then
                colUsed[family]=true
                maxResourceCounts[family]=math.max(maxResourceCounts[family],#items)
                resourceLines=math.max(resourceLines,math.ceil(#items/combatConfig.lineSlotCount))
            end
            -- Collapse the second icon line completely when unused. The Grid is
            -- anchored to the cell's centre, so tall text rows don't strand
            -- their one-line icons against the top of the enemy row.
            local gridID="CombatSourceGrid"..row..family
            local gridHeight=math.ceil(#items/combatConfig.lineSlotCount)*26
            combatPanelSetAttribute(gridID,"height",tostring(gridHeight))
            combatPanelSetAttribute(gridID,"preferredHeight",tostring(gridHeight))
            for slot=1,combatConfig.slotCount do
                local id="CombatSourceSlot"..row..family..slot
                local item=items[slot]
                if item~=nil then
                    combatAssignmentSlotSources[id]=item.source.key
                    combatConfig.slotBowFamilies[id]=item.detail~=nil
                        and (item.detail.family=="ranged" or item.detail.family=="siege")
                        and item.detail.family or nil
                    combatConfig.slotSelection[id]={key=item.source.key,
                        wounded=item.wounded,ineffective=item.ineffective}
                    local tooltip=item.tooltip or (item.source.name..": "..item.text
                        ..(item.source.dodgeIneligible and
                            " unavailable: the Hero took Wounds before the Attack phase"
                            or (item.wounded and " can't apply 'Wounded'" or "")))
                    -- Cold Toughness's powered icon bonus is automatic. Explain
                    -- its printed Arcane Immunity exception on the Block source icon.
                    local coldToughness=seatScan~=nil and seatScan.cards["79bfbd"] or nil
                    if item.source.guid=="79bfbd" and item.typeKey=="I"
                        and coldToughness~=nil and coldToughness.powered==true then
                        local printedEnemy=entry~=nil and monsterPugs[entry.guid] or nil
                        if printedEnemy~=nil and printedEnemy.arcaneImmunity==true then
                            tooltip=tooltip.."\nCold Toughness: Ice Block 5 + 0 icon bonus (Arcane Immunity)."
                        else
                            tooltip=tooltip.."\nCold Toughness: Ice Block 5 + 1 per printed enemy ability, attack type or resistance icon (automatic)."
                        end
                    end
                    if item.paralysisCard then
                        tooltip=tooltip.."\n"
                            ..(knockout and "Knockout" or "Paralysis")
                            ..": the Hero discards non-Wound cards before Attack."
                            .." This planned card Attack does not count."
                    end
                    local bowFamily=combatConfig.slotBowFamilies[id]
                    if bowFamily~=nil and combatConfig.artifactCombat.bow then
                        local bowMode=combatConfig.bowSourceModes[
                            item.source.key.."#"..bowFamily]
                            or (bowFamily=="ranged" and "double" or "none")
                        local description=bowFamily=="ranged"
                            and (bowMode=="siege" and "Convert to Siege (same value)"
                                or "Double Ranged")
                            or (bowMode=="ranged" and "Double and convert to Ranged"
                                or "Keep original Siege")
                        tooltip=tooltip.."\nBow of Starsdawn: "..description
                            ..". Right-click this source icon to switch."
                    end
                    if item.source.phaseLocked then
                        tooltip=tooltip.."\nLocked by Commit Damage. Use TTS Rewind to change."
                    end
                    combatAssignmentIconButton(id,true,item.amount,item.icon,
                        tooltip,combatAssignmentState.selected==item.source.key,
                        (item.wounded or item.ineffective) and "#292323" or (item.typeKey~=nil
                            and combatConfig.typeColors[item.typeKey][item.reduced and 2 or 1] or nil),
                        item.wounded,item.ineffective)
                    combatPanelSetAttribute(id,"interactable",
                        item.source.phaseLocked and "false" or "true")
                else
                    combatAssignmentIconButton(id,false,0,"","",false)
                end
            end
        end
        local merged=group~=nil and #group.members>1
        for _,family in ipairs({"range","attack"}) do
            combatPanelSetAttribute("CombatSourceCell"..row..family,"color",
                merged and "rgba(1,1,1,0.10)" or "rgba(0,0,0,0)")
        end
        local rowHeight=math.max(combatConfig.rowHeight,resourceLines*26+4)
        if entry~=nil and group~=nil then
            -- Final armour for the current layout: Elusive doubles unless every attack is blocked.
            local armourValue=entry.baseArmour
            if combatEnemyHasTrait(entry.data,entry.perks,"elusive") and not rowBlock[index].allBlocked then
                armourValue=entry.elusiveArmour
            end
            combatPanelSetAttribute("CombatEnemyRow"..row.."Armour","text",
                (entry.destroyed or entry.attackOnly) and "-" or tostring(armourValue))
            -- Use actual modified defenses even on a single enemy (Sorcerers,
            -- stripped fortification, and other effects may change them).
            local sharedText=combatGroupTraitsText(entry,group.entry)
            shownTraits[row]=sharedText
            combatPanelSetAttribute("CombatEnemyRow"..row.."Traits","text",sharedText)
            entry.attackCount=math.max(entry.attackCount or 1,select(2,sharedText:gsub("\n",""))+1)
            -- An enemy defeated before the Block phase has no attack or
            -- offensive abilities to resolve, even if its printed token has them.
            local noEnemyAttack=group.rangeDefeated or entry.rangeDead
                or group.destroyed or entry.destroyed
            local attacks=combatEnemyAttacks(entry)
            local attackLines={}
            if not noEnemyAttack then
                for attackIndex,attack in ipairs(attacks) do
                    local reduction=rowBlock[index].reductions[attackIndex] or 0
                    local markers={}
                    local selections=combatReductionAttackChoice[entry.guid] or {}
                    for rank,effect in ipairs(entry.attackReductions) do
                        if selections[effect.id or tostring(effect.source)]==attackIndex then
                            markers[#markers+1]=tostring(rank)
                        end
                    end
                    attackLines[#attackLines+1]=(#markers>0 and ("▶"..table.concat(markers,",").." ") or "")
                        ..combatTypeRich(attack.label.." "..tostring(attack.value-reduction)
                            ..(combatNatureVengeanceBlockBonus()>0 and " (Block +1)" or ""),
                            attack.key,reduction>0)
                end
            end
            local attackText=noEnemyAttack and ""
                or (#attackLines>0 and table.concat(attackLines,"\n") or "-")
            shownAttacks[row]=attackText
            combatPanelSetAttribute("CombatEnemyRow"..row.."Attacks","text",attackText)
            if noEnemyAttack then
                shownOffence[row]=""
                combatPanelSetAttribute("CombatEnemyRow"..row.."Offence","text","")
                combatPanelSetAttribute("CombatEnemyAttackCycle"..row,"active","false")
                -- Removed attack lines must not leave extra empty height.
                entry.attackCount=math.max(1,select(2,sharedText:gsub("\n",""))+1)
            end
            local lines={}
            local isLast=group.members[#group.members]==index
            if group.destroyed then
                lines[1]=combatRich("Destroyed",combatConfig.COMBAT_GREEN)
            elseif entry.rangeDead then
                lines[1]=combatRich("Ranged defeated",combatConfig.COMBAT_GREEN)
            elseif group.rangeDefeated then
                -- Group results sit under the last enemy of the group.
                if isLast then
                    lines[1]=combatRich("Ranged "..tostring(group.rangeTotal).."/"..tostring(group.rangeArmour)
                        .." Defeated",combatConfig.COMBAT_GREEN)
                end
            else
                -- Keep each source's Block status and wound distribution together.
                for lineIndex,line in ipairs(rowBlock[index].lines) do
                    local item=rowBlock[index].damageItems[lineIndex]
                    local attack=attacks[lineIndex]
                    if attack~=nil and not attack.pending then
                        local value=math.max(0,attack.value-(rowBlock[index].reductions[lineIndex] or 0))
                        line=attack.label.." "..tostring(value)..": "..line
                    end
                    lines[#lines+1]=line
                    if item~=nil then
                        for _,note in ipairs(combatDamageNotes(item,damageResults[item.key])) do
                            lines[#lines+1]=note
                        end
                    elseif rowBlock[index].lines[lineIndex]:find("Blocked",1,true) then
                        lines[#lines+1]="Wounds: None"
                    end
                end
                grandDamage=grandDamage+rowBlock[index].damage
                damageSources=damageSources+rowBlock[index].count
                if isLast and not entry.attackOnly then
                    if group.bossSpecial then
                        if group.attackTotal>0 then
                            lines[#lines+1]="Attack "..tostring(group.attackTotal).." (level attack)"
                        end
                    else
                        local line=combatGroupAttackLine(group.attackTotal,group.attackArmour)
                        if line~=nil then lines[#lines+1]=line end
                    end
                end
            end
            if entry.bossType=="control" then
                lines[#lines+1]="Control: cannot be attacked"
            elseif entry.bossLevel~=nil then
                local ranged,melee=entry.bossRangeLevels or 0,entry.bossAttackLevels or 0
                local manual=gStates.combatBossManual~=nil
                    and gStates.combatBossManual[entry.guid]~=nil
                lines[#lines+1]="Levels: -"..tostring(ranged+melee).."/"..tostring(entry.bossLevel)
                    .." (R "..tostring(ranged)..", A "..tostring(melee)..")"
                    ..(manual and (group.bossSpecial and #group.members>1
                        and " [Manual priority]" or " [Manual]") or "")
            end
            local compactLines=combatCompactResultLines(lines,rowBlock[index].damageItems,damageResults)
            local detailText=table.concat(lines,"\n")
            local compactText=table.concat(compactLines,"\n")
            local hasDetails=detailText~=compactText
            local expanded=hasDetails and combatExpandedResults[entry.guid]==true
            local displayText=expanded and detailText or compactText
            if hasDetails then displayText=displayText..(expanded and " [-]" or " [+]") end
            -- Only explicit newlines take vertical space; Result text may overflow horizontally.
            local displayLines=expanded and #lines or #compactLines
            local minHeight=rowHeight
            rowHeight=math.max(rowHeight,math.max(displayLines,entry.attackCount or 1)*15+4)
            -- Only the Result text and its row/panel heights change when expanded.
            combatConfig.resultRowCache[row]={guid=entry.guid,detailText=detailText,
                compactText=compactText,hasDetails=hasDetails,detailLines=#lines,
                compactLines=#compactLines,minHeight=minHeight,rowHeight=rowHeight,
                attackCount=entry.attackCount or 1}
            local resultID="CombatEnemyRow"..row.."Result"
            combatPanelSetAttribute(resultID,"text",displayText)
            combatPanelSetAttribute("CombatEnemyResultToggle"..row,"tooltip","")
            combatPanelSetAttribute(resultID,"fontSize","12")
            combatPanelSetAttribute(resultID,"font","Fonts/MKCardText")
            combatPanelSetAttribute(resultID,"color","White")
            totalRowHeight=totalRowHeight+rowHeight
        end
        combatPanelSetAttribute("CombatEnemyRow"..row,"preferredHeight",tostring(rowHeight))
        if entry==nil then
            combatAttackChoiceByRow[row]=nil
            combatPanelSetAttribute("CombatEnemyAttackCycle"..row,"active","false")
        end
    end

    -- Hide a column when every visible enemy leaves it blank or "None".
    local function textBlank(text) return text==nil or text=="" or text=="None" or text=="-" end
    local colShown={range=colUsed.range,block=colUsed.block,attack=colUsed.attack,traits=false,offence=false,enemyAttack=false}
    for row=1,combatConfig.rowCount do
        if not textBlank(shownTraits[row]) then colShown.traits=true end
        if not textBlank(shownOffence[row]) then colShown.offence=true end
        if not textBlank(shownAttacks[row]) then colShown.enemyAttack=true end
    end
    -- Keep columns aligned across visible enemy rows, but size each
    -- resource phase to its fullest row (three to six icons wide).
    -- GridLayout wraps additional icons below the first line.
    local columnWidths={traits=combatConfig.traitColumnWidth(shownTraits),offence=130,enemyAttack=105}
    -- Keep trait row cells and their header in lockstep, including when the
    -- visible page changes or a combat ability is removed mid-fight.
    for row=1,combatConfig.rowCount do
        combatPanelSetAttribute("CombatEnemyRow"..row.."Traits","preferredWidth",tostring(columnWidths.traits))
    end
    for _,family in ipairs({"range","block","attack"}) do
        local columns=math.max(3,math.min(combatConfig.lineSlotCount,maxResourceCounts[family]))
        columnWidths[family]=columns*24
        for row=1,combatConfig.rowCount do
            combatPanelSetAttribute("CombatSourceCell"..row..family,"preferredWidth",
                tostring(columnWidths[family]))
            combatPanelSetAttribute("CombatSourceGrid"..row..family,"constraintCount",tostring(columns))
            combatPanelSetAttribute("CombatSourceGrid"..row..family,"width",
                tostring(columnWidths[family]))
        end
    end
    local headerIDs={traits="CombatDefenceTraitsHeader",range="CombatRangeSiegeHeader",offence="CombatOffenceHeader",
        enemyAttack="CombatEnemyAttackHeader",
        block="CombatBlockHeader",attack="CombatAssignedAttackHeader"}
    local hiddenWidth=0
    for column,shown in pairs(colShown) do
        local active=shown and "true" or "false"
        if not shown then hiddenWidth=hiddenWidth+columnWidths[column] end
        combatPanelSetAttribute(headerIDs[column],"active",active)
        for index=1,combatConfig.rowCount do
            local cell=(column=="traits" and "CombatEnemyRow"..index.."Traits")
                or (column=="offence" and "CombatEnemyRow"..index.."Offence")
                or (column=="enemyAttack" and "CombatEnemyAttackCell"..index)
                or "CombatSourceCell"..index..column
            combatPanelSetAttribute(cell,"active",active)
        end
    end

    local widthReduction=(170-columnWidths.range)+(170-columnWidths.block)+(170-columnWidths.attack)
    local panelWidth=1380-(255-combatConfig.columns.Result)-hiddenWidth-widthReduction
        +(enemyNameWidth-120)+(columnWidths.traits-150)

    if earlyLock==nil and combatConfig.phasePreview~=nil then
        combatConfig.phasePreview.attackDiscards=combatFrozenCopy(stagedAttackCards)
    end
    combatConfig.woundRecordPreview(damageSeat,damageItems,damageResults,
        knockout,otherCombatWounds,stagedAttackCards)
    local ledger=combatConfig.woundLedger(damageSeat)
    local _,pendingHand,pendingDiscard,changed,effects=combatConfig.woundPending(ledger)
    -- A Paralyzed Unit needs an Apply button even when all its attack damage
    -- was absorbed and the Hero has zero Wounds.
    local showTotal=totalHeroWounds>0 or knockout or effects.destroyCount>0
        or effects.handDiscard or effects.stagedDiscardCount>0
    combatPanelSetAttribute("CombatTotalRow","active",showTotal and "true" or "false")
    if showTotal then
        -- The XML's fixed-width, right-anchored Panel is outside any
        -- HorizontalLayout, so Unity's layout group cannot expand its child.
        local poisonText=totalDiscardWounds>0 and " ("..tostring(totalDiscardWounds).." Poison)" or ""
        local text=totalHeroWounds>0
            and ("Draw: "..combatRich(combatWoundsText(totalHeroWounds)..poisonText,combatConfig.COMBAT_RED))
            or (effects.handDiscard and "Apply: Discard hand"
                or (effects.stagedDiscardCount>0 and "Apply: Discard Attack"
                    or (knockout and "Knocked out (applied)"
                    or ("Apply: Destroy "..tostring(effects.destroyCount)..
                        (effects.destroyCount==1 and " Unit" or " Units")))))
        combatPanelSetAttribute("CombatTotalDamage","text",text)
        combatPanelSetAttribute("CombatTotalDamage","font","Fonts/MKCardText")
        local pending=pendingHand+pendingDiscard>0
            or effects.handDiscard or effects.destroyCount>0
            or effects.stagedDiscardCount>0
        combatPanelSetAttribute("CombatApplyWounds","interactable",
            (pending or changed) and not combatConfig.woundApplying and "true" or "false")
        combatPanelSetAttribute("CombatApplyWounds","color",
            pending and "rgb(0.48,0.36,0.20)" or changed and "rgb(0.49,0.30,0.22)"
            or "rgb(0.23,0.37,0.24)")
        -- The commit confirmation already explains the consequences.
        -- Clear any tooltip cached from an earlier calculator refresh.
        combatPanelSetAttribute("CombatApplyWounds","tooltip","")
        combatPanelSetAttribute("CombatKnockoutWarning","active",knockout and "true" or "false")
        if knockout then
            combatPanelSetAttribute("CombatKnockoutWarning","text",
                "KNOCKED OUT")
            combatPanelSetAttribute("CombatKnockoutWarning","font","Fonts/MKCardText")
        end
        local summaryHeight=knockout and 40 or 22
        combatPanelSetAttribute("CombatTotalRow","preferredHeight",tostring(summaryHeight))
        totalRowHeight=totalRowHeight+summaryHeight
    end

    -- A solo enemy can show twelve icons per phase; larger grouped stacks
    -- continue onto the next member row. Do not silently hide any remainder.
    combatPanelSetAttribute("CombatResourceOverflow","active",overflow>0 and "true" or "false")
    if overflow>0 then
        combatPanelSetAttribute("CombatResourceOverflow","text",joinLang({
            "{en}"..overflow.." resource icons exceed the available rows.",
            "{it}"..overflow.." icone delle risorse oltre le righe disponibili.",
            "{ru}"..overflow.." значков ресурсов не помещается в строках.",
            "{zh-tw}有 "..overflow.." 個資源圖示超出可用列數。",
            "{zh-cn}有 "..overflow.." 个资源图标超出可用行数。",
            "{ko}"..overflow.."개 자원 아이콘이 표시 행을 초과했습니다.",
            "{es}"..overflow.." iconos de recursos superan las filas disponibles.",
            "{fr}"..overflow.." icônes de ressources dépassent les lignes disponibles.",
            "{pt-br}"..overflow.." ícones de recursos excedem as linhas disponíveis.",
            "{de}"..overflow.." Ressourcensymbole passen nicht in die verfügbaren Zeilen."
        }))
    end
    combatPanelSetAttribute("CombatEnemyPanel","width",tostring(panelWidth))
    combatPanelSetAttribute("CombatEnemyPanel","color","rgb(0.24,0.2,0.15)")
    local headerWidths={Monster=enemyNameWidth,Armour=55,DefenceTraits=columnWidths.traits,RangeSiege=columnWidths.range,EnemyAttack=105,
        Offence=130,Block=columnWidths.block,AssignedAttack=columnWidths.attack,Result=combatConfig.columns.Result}
    for name,width in pairs(headerWidths) do
        local id="Combat"..name.."Header"
        combatPanelSetAttribute(id,"font","Fonts/MKCardTittle")
        combatPanelSetAttribute(id,"color","rgb(0.95,0.9,0.78)")
        combatPanelSetAttribute(id,"preferredWidth",tostring(width))
        if name=="DefenceTraits" or name=="Offence" then
            combatPanelSetAttribute(id,"alignment","MiddleCenter")
        end
    end
    return totalRowHeight+(pages>1 and 22 or 0)+(overflow>0 and 18 or 0)
end

local function combatCalcShutdown()
    combatConfig.shutdownClean=true
    combatConfig.resultRowCache={}
    combatConfig.slotSelection={}
    combatConfig.effectSources={}
    combatConfig.blockedEnemyCounts={}
    combatConfig.conversionState={}
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
    local active
    if calculated==true then active=combatCalcOn
    else active=combatCalcUpdate(monsters) end
    if not active then
        -- A closed calculator is already clean; don't repeatedly delete/rebuild overlays.
        if not combatConfig.shutdownClean then combatCalcShutdown() end
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
    -- Preserve the printed/site Fortification before Demolish/Expose strips it.
    for _,entry in ipairs(entries) do
        entry.originalFortification=combatEnemyFortificationCount(entry.data,entry.perks)
    end
    -- Ignore site/wall Fortified, but preserve the monster's printed Fortified.
    if seatScan~=nil and seatScan.ignoreSiteFortifications==true then
        for _,entry in ipairs(entries) do
            local perks=entry.perks
            if perks~=nil and (perks.fortified==true or perks.wallFortified==true) then
                local adjusted={}
                for key,value in pairs(perks) do adjusted[key]=value end
                adjusted.fortified=false
                adjusted.wallFortified=false
                entry.perks=adjusted
            end
        end
    end
    for _,entry in ipairs(entries) do
        local obj=getObjectFromGUID(entry.guid)
        entry.x=obj~=nil and obj.getPosition()[1] or 0
        -- Card effects on one enemy (Armour reduction never goes below 1).
        local effect=enemyEffects~=nil and enemyEffects[entry.guid] or nil
        entry.effect=effect
        entry.attackReductions=combatOrderedReductions(effect)
        if effect~=nil then
            -- Remove only the trait PRINTED on the selected enemy token. A
            -- separate fortification/resistance granted by its site remains.
            if next(effect.removedPrinted or {})~=nil then
                local copy={}
                for key,value in pairs(entry.data) do copy[key]=value end
                for trait in pairs(effect.removedPrinted) do
                    if trait=="defend" then copy[trait]=0
                    else copy[trait]=false end
                end
                entry.data=copy
            end
            local currentlyFortified=combatEnemyFortificationCount(entry.data,entry.perks)>0
                and effect.removeFortify~=true
            local reduction=currentlyFortified and effect.armourReduceFortified
                or effect.armourReduce
            if not currentlyFortified and entry.originalFortification>0 then
                reduction=reduction+(effect.armourBeforeFortificationRemoval or 0)
            end
            if effect.armourReduceByResist>0 then
                local resistances=0
                for _,key in ipairs({"pResist","fResist","iResist"}) do
                    if combatEnemyHasTrait(entry.data,entry.perks,key) then resistances=resistances+1 end
                end
                reduction=reduction+effect.armourReduceByResist*resistances
            end
            -- Taunt's provoke option grants its Armour discount only if the
            -- enemy actually attacks; it can NEVER help in Ranged/Siege.
            local lateReduction=effect.armourReduceAttackOnly or 0
            if lateReduction>0 then
                local attacks=combatEnemyAttacks(entry)
                local attacksNow=false
                for _,attack in ipairs(attacks) do
                    if not attack.pending then attacksNow=true break end
                end
                local noAttack=effect.noAttack==true or effect.destroy==true
                    or (effect.noAttackUnfortified==true
                        and (combatEnemyFortificationCount(entry.data,entry.perks)==0
                            or effect.removeFortify==true))
                if noAttack or not attacksNow then
                    reduction=math.max(0,reduction-lateReduction)
                    lateReduction=0
                end
            end
            entry.effectArmourReduction=reduction
            if reduction>0 then
                -- Curse applies to fortified enemies only in the later Attack
                -- phase. Preserve independent Ranged/Siege Armour, including
                -- reductions from other sources and the minimum of 1.
                local fortified=combatEnemyFortificationCount(entry.data,entry.perks)>0
                    and effect.removeFortify~=true
                local rangedReduction=math.max(0,reduction-lateReduction)
                if fortified then
                    rangedReduction=math.max(0,reduction
                        -(effect.armourReduceRangedUnfortifiedOnly or 0))
                end
                if rangedReduction~=reduction then
                    entry.rangeBaseArmour=math.max(1,entry.baseArmour-rangedReduction)
                    entry.rangeElusiveArmour=math.max(1,entry.elusiveArmour-rangedReduction)
                end
                entry.baseArmour=math.max(1,entry.baseArmour-reduction)
                entry.elusiveArmour=math.max(1,entry.elusiveArmour-reduction)
            end
            entry.stripFortify=effect.removeFortify
            entry.stripResist=effect.removeResist
            entry.stripFireResist=effect.removeFireResist
        end
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
    attackAssignmentsPruneInactive(activeSources,activeObjects,combatSourceKeepsLock)
    local validTargets={}
    for guid,obj in pairs(monsters or {}) do
        if obj.is_face_down~=true then validTargets[guid]=true end
    end
    attackAssignmentsPruneTargets(validTargets)
    -- Reconcile effect-only Unit arrows on *every* calculator refresh, not only
    -- when an assignment is clicked. The damage overlay may come and go as
    -- attacks are blocked; its removal must not remove the originating arrow.
    for guid,record in pairs(seatScan~=nil and seatScan.cards or {}) do
        for sourceKey,targetGUID in pairs(record.enemyEffectTargetGUIDs or {}) do
            if activeSources[sourceKey]==true and monsters[targetGUID]~=nil
                and not attackAssignmentsIsTargeting(sourceKey)
                and next(attackAssignmentsTargetGUIDs(sourceKey))==nil then
                attackAssignmentsEnsureTarget(sourceKey,targetGUID,"attack")
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
    local rowHeight=combatAssignmentRefreshRows(entries,sources)
    if lock==nil and combatConfig.phasePreview~=nil then
        -- Automatic nearest-enemy targeting is resolved inside the calculator,
        -- so capture it AFTER that pass rather than before the first render.
        combatConfig.phasePreview.targets=combatFrozenCopy(combatAssignmentState.targets)
        combatConfig.phasePreview.explicit=combatFrozenCopy(combatAssignmentState.explicit)
    end
    if attackAssignmentsRefreshTargetButtons~=nil then
        attackAssignmentsRefreshTargetButtons(monsters)
    end
    combatConfig.panelHeight=combatConfig.panelBaseHeight+rowHeight
    combatPanelSetAttribute("CombatEnemyPanel","height",tostring(combatConfig.panelHeight))
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
    combatPanelSetAttribute("CombatEnemyPanel","height",tostring(combatConfig.panelHeight))
    return true
end

function resourceCardsRefreshCombatEnemies()
    if not resourceCardsPanelOpen() then return end
    refreshCombatEnemyPanel(combatPlayMonsters())
end

function resourceCardsCombatAssignSource(sourceGUID,enemyGUID)
    if combatConfig~=nil and combatConfig.phaseKeyLocked~=nil
        and combatConfig.phaseKeyLocked(sourceGUID) then return end
    if not resourceCardsCombatTargetAcceptsSource(sourceGUID,enemyGUID) then return end
    if gStates~=nil and combatAssignmentState.targets[sourceGUID]~=enemyGUID then
        if sourceGUID=="0688d8" then gStates.battleHardenedAttackKey=nil end
        if sourceGUID=="ae8673" then gStates.elementalResistanceAttackKey=nil end
    end
    combatAssignmentState.targets[sourceGUID]=enemyGUID
    combatAssignmentState.explicit[sourceGUID]=true
    resourceCardsRefreshCombatEnemies()
    resourceCardsSourceChanged()
end


-- A remote Spirit Guides link can target any active, Block-producing card,
-- Skill or Unit in this player's areas; it is not an enemy assignment.
-- This is also the candidate set for temporary clickable target buttons.
combatConfig.spiritGuideBlockFields={"block","blockFire","blockIce","blockColdFire","blockPsychic"}
function resourceCardsBlockLinkSkillActive(guid)
    local active=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    local scan=active~=nil and resourceCardScanBySeat[active.seatPos] or nil
    local record=scan~=nil and scan.cards[guid] or nil
    local rule=skillResourceDefinitions[guid]
    return record~=nil and record.kind=="skill" and rule~=nil
        and rule.blockSourceBoost~=nil and resourceCardsPanelOpen()
end

function resourceCardsBlockLinkTargets()
    local active=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    local scan=active~=nil and resourceCardScanBySeat[active.seatPos] or nil
    local targets={}
    for guid,record in pairs(scan~=nil and scan.cards or {}) do
        if record.resources~=nil and record.contributes==true
            and record.kind~="mana" and record.kind~="wound" then
            for _,field in ipairs(combatConfig.spiritGuideBlockFields) do
                if (tonumber(record.resources[field]) or 0)>0 then
                    local obj=getObjectFromGUID(guid)
                    if obj~=nil and not obj.isDestroyed() then targets[guid]=obj end
                    break
                end
            end
        end
    end
    return targets
end

-- Separate the three physical orientations. A tilted card is paid as a
-- discard (typically 45 degrees); a fully sideways card gives any basic 1.
-- Reducing modulo 180 handles the face-up cards' normal Y=180 orientation.
local function cardRotationOffset(card)
    local y=card.getRotation()[2]%180
    return math.min(y,180-y)
end

local function cardPosture(card)
    local tilt=cardRotationOffset(card)
    if tilt<25 then return "upright" end
    if tilt<=70 then return "discard" end
    return "sideways"
end

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
    if guid==sourceGUID or record==nil or record.resources==nil then return false end
    local data=gameCards[guid]
    if data==nil or (data.cardType~="Starting" and data.cardType~="Advanced Action"
        and data.cardType~="Spell" and data.cardType~="Artifact") then return false end
    local card=getObjectFromGUID(guid)
    if card==nil or card.isDestroyed() or card.is_face_down==true
        or cardPosture(card)=="discard" then return false end
    for _,key in ipairs(combatConfig.ambushCombatCategories) do
        if (tonumber(record.resources[key]) or 0)>0 then return true end
    end
    return false
end

function resourceCardsAmbushSourceActive(guid)
    local active=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    local scan=active~=nil and resourceCardScanBySeat[active.seatPos] or nil
    local record=scan~=nil and scan.cards[guid] or nil
    local data=gameCards[guid]
    local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
    local card=getObjectFromGUID(guid)
    return resourceCardsPanelOpen() and resourceCardsDetailsOpen()
        and rule~=nil and rule.combatLink~=nil
        and record~=nil and record.complete==true and record.resources~=nil
        and card~=nil and not card.isDestroyed() and card.is_face_down~=true
        and cardPosture(card)=="upright"
end

function resourceCardsAmbushLinkTargets(sourceGUID)
    local targets={}
    if not resourceCardsAmbushSourceActive(sourceGUID) then return targets end
    local active=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    local scan=active~=nil and resourceCardScanBySeat[active.seatPos] or nil
    for guid,record in pairs(scan~=nil and scan.cards or {}) do
        if combatConfig.ambushEligibleTarget(guid,record,sourceGUID) then
            targets[guid]=getObjectFromGUID(guid)
        end
    end
    return targets
end

-- Paging changes visible rows, not the underlying combat calculations.
function resourceCardsCombatPage(delta)
    combatEnemyPage=math.max(1,combatEnemyPage+delta)
    resourceCardsRefreshCombatEnemies()
end

function resourceCardsCombatCycleAttack(row,nextSource)
    if combatPhaseLock~=nil and combatPhaseLock(combatAssignmentActiveSeat())~=nil then return end
    local guid=combatAssignmentRowTargets[row]
    local selector=combatAttackChoiceByRow[row]
    if guid==nil or selector==nil or #selector.options<2 then return end
    local reductions=selector.reductions
    local active=combatReductionActiveSource[guid] or (reductions[1].id or tostring(reductions[1].source))
    if nextSource then
        for i,reduction in ipairs(reductions) do
            if (reduction.id or tostring(reduction.source))==active then
                local following=reductions[i%#reductions+1]
                combatReductionActiveSource[guid]=following.id or tostring(following.source)
                break
            end
        end
    else
        local selected=combatReductionAttackChoice[guid] or {}
        local previous=selected[active]
        local nextIndex=selector.options[1]
        for i,index in ipairs(selector.options) do
            if previous==index then nextIndex=selector.options[i+1] break end
        end
        selected[active]=nextIndex
        combatReductionAttackChoice[guid]=next(selected)~=nil and selected or nil
    end
    resourceCardsRefreshCombatEnemies()
end

-- The first visible row can still join the preceding enemy on another page.
function resourceCardsCombatToggleGroup(row)
    if combatPhaseLock~=nil and combatPhaseLock(combatAssignmentActiveSeat())~=nil then return end
    local guid=combatAssignmentRowTargets[row]
    local index=combatAssignmentRowIndices[row]
    if guid==nil or index==nil or index<2 then return end
    local data=combatEnemyData(guid)
    if data~=nil and data.attackOnly then return end
    combatAssignmentJoined[guid]=combatAssignmentJoined[guid]~=true or nil
    resourceCardsRefreshCombatEnemies()
end

function resourceCardsCombatToggleResult(row)
    local guid=combatAssignmentRowTargets[row]
    if guid==nil then return end
    local cache=combatConfig.resultRowCache[row]
    if cache==nil or cache.guid~=guid then
        combatExpandedResults[guid]=not combatExpandedResults[guid]
        resourceCardsRefreshCombatEnemies()
        return
    end
    if not cache.hasDetails then return end
    combatExpandedResults[guid]=not combatExpandedResults[guid]
    combatConfig.refreshResultRowOnly(row)
end

-- Called when a targeting arrow is removed; the source re-locks to the nearest enemy on refresh.
function resourceCardsCombatForgetSource(sourceGUID,replacementTargetGUID)
    if combatConfig~=nil and combatConfig.phaseKeyLocked~=nil
        and combatConfig.phaseKeyLocked(sourceGUID) then return end
    -- Deleting one of several arrows must not wipe the remaining allocations.
    -- The caller passes a deterministic replacement only when the primary
    -- arrow itself has disappeared; nil still clears the source entirely.
    combatAssignmentState.targets[sourceGUID]=replacementTargetGUID
    combatAssignmentState.explicit[sourceGUID]=replacementTargetGUID~=nil or nil
end

-- Clear every target key owned by a physical card or Unit (including split
-- keys). Choice changes and borrowed Unit cleanup must not leave hidden locks
-- that regenerate arrows during the next Combat Calculator scan.
local function combatForgetPhysicalSourceTargets(unitGUID)
    local prefix=unitGUID.."#"
    for key in pairs(combatAssignmentState.targets) do
        if key==unitGUID or key:sub(1,#prefix)==prefix then
            combatAssignmentState.targets[key]=nil
            combatAssignmentState.explicit[key]=nil
        end
    end
    local selected=combatAssignmentState.selected
    if type(selected)=="string"
        and (selected==unitGUID or selected:sub(1,#prefix)==prefix) then
        combatAssignmentState.selected=nil
    end
end

function resourceCardsCombatAssignmentClick(id,mouseButton)
    local lockedSource=combatAssignmentSlotSources[id]
    if lockedSource~=nil and combatConfig~=nil and combatConfig.phaseKeyLocked~=nil
        and combatConfig.phaseKeyLocked(lockedSource) then return end
    if tostring(mouseButton)=="-2" and combatConfig.artifactCombat.bow then
        local key=combatAssignmentSlotSources[id]
        local family=combatConfig.slotBowFamilies[id]
        if key~=nil and family~=nil then
            local modeKey=key.."#"..family
            local old=combatConfig.bowSourceModes[modeKey]
                or (family=="ranged" and "double" or "none")
            combatConfig.bowSourceModes[modeKey]=family=="ranged"
                and (old=="double" and "siege" or "double")
                or (old=="none" and "ranged" or "none")
            resourceCardsSourceChanged()
            return
        end
    end
    local row=id:match("^CombatSourceSlot(%d+)")
    local index=row~=nil and tonumber(row) or nil
    local targetGUID=index~=nil and combatAssignmentRowTargets[index] or nil
    if targetGUID==nil then return end
    local sourceGUID=combatAssignmentSlotSources[id]
    local moved=combatAssignmentState.selected
    if moved~=nil and combatConfig~=nil and combatConfig.phaseKeyLocked~=nil
        and combatConfig.phaseKeyLocked(moved) then
        combatAssignmentState.selected=nil
        combatConfig.refreshSelectedSlots()
        return
    end
    if moved~=nil then
        if sourceGUID==moved then
            combatAssignmentState.selected=nil
            combatConfig.refreshSelectedSlots()
            return
        else
            local movedSource=nil
            for _,candidate in ipairs(combatAssignmentSources(combatAssignmentState.seat)) do
                if candidate.key==moved then movedSource=candidate break end
            end
            local effectSource=combatConfig.effectSources[moved]
            if effectSource==nil and movedSource~=nil
                and movedSource.ranged+movedSource.siege+movedSource.block+movedSource.attack==0
                and not combatGUIDHasCumbersome(targetGUID) then
                combatAssignmentState.selected=nil
                combatConfig.refreshSelectedSlots()
                return
            end
            if not resourceCardsCombatTargetAcceptsSource(moved,targetGUID) then
                combatAssignmentState.selected=nil
                combatConfig.refreshSelectedSlots()
                return
            end
            combatAssignmentState.targets[moved]=targetGUID
            combatAssignmentState.explicit[moved]=true
            combatAssignmentState.selected=nil
            attackAssignmentsSetSourceTarget(moved,targetGUID,
                effectSource~=nil and effectSource.arrow
                or movedSource~=nil and combatSourceArrowKind(movedSource) or nil)
            resourceCardsSourceChanged()
        end
        resourceCardsRefreshCombatEnemies()
        return
    end
    if sourceGUID~=nil then combatAssignmentState.selected=sourceGUID end
    combatConfig.refreshSelectedSlots()
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
local function ownedSkillAtSeat(guid,seatPos)
    local home=gStates~=nil and gStates.mageSkills~=nil and gStates.mageSkills[guid] or nil
    return home~=nil and home[1]~=nil and home[3]~=nil
        and home[3]<-30.5 and math.abs(home[1]-(seatPos*40-109.5))<15
end

trackerPrivate.passableTerrain={
    plains=true,hills=true,forest=true,wasteland=true,desert=true,swamp=true,
    lake=true,mountain=true
}

-- Static rule objects are reused by every scan. The movement panel compares
-- terrain modifier identity to avoid expensive redraws on unchanged positions.
local weatherTerrain={}
for _,guid in ipairs({"55e5e5","676856"}) do
    local rule=skillResourceDefinitions[guid] or {}
    local roles={}
    for role,amount in pairs(rule.weatherTerrain or {}) do
        roles[role]={mode="weather",terrains="weather",amount=amount}
    end
    weatherTerrain[guid]=roles
end

-- Interactive Weather skills use the same persistent activation/circulation
-- state as the physical token. The owner gets -2 on activation; the other
-- player's Calming benefit lasts only on their eligible turn; Prayer affects
-- opponents while its competitive circulation is still active.
local function resourceCardsWeatherTerrainEffects(seatPos)
    local effects={}
    local states=gStates or {}
    local current=states.turnNumber
    local player=turnOrder~=nil and turnOrder[current] or nil
    if player==nil or player.seatPos~=seatPos then return effects end
    local active=states.coopCompSkillActivation or {}
    for _,guid in ipairs({"55e5e5","676856"}) do
        local record=active[guid]
        local details=weatherTerrain[guid]
        if record~=nil and record.round==states.currentRound then
            if record.player==current and (states.doingTheRounds or {})[guid]==nil then
                if details.owner~=nil then effects[#effects+1]=details.owner end
            elseif record.player~=current and guid=="676856" then
                if details.others~=nil then effects[#effects+1]=details.others end
            elseif record.player~=current and guid=="55e5e5"
                and coopCompSkillPlayAreaPlayer~=nil
                and coopCompSkillPlayAreaPlayer(guid)==current then
                if details.recipient~=nil then effects[#effects+1]=details.recipient end
            end
        end
    end
    local claimed=states.weatherBenefitThisTurn
    if claimed~=nil and claimed.player==current and claimed.round==states.currentRound
        and weatherTerrain["55e5e5"].recipient~=nil then
        local already=false
        for _,effect in ipairs(effects) do
            if effect==weatherTerrain["55e5e5"].recipient then already=true break end
        end
        if not already then effects[#effects+1]=weatherTerrain["55e5e5"].recipient end
    end
    return effects
end

local function cardTerrainEffects(rule,powered)
    if rule==nil or rule.terrainEffects==nil then return nil end
    if powered then return rule.terrainEffects.powered end
    return rule.terrainEffects.normal
end

local function terrainEffectActive(effect)
    return effect.dayRound==nil or effect.dayRound==(gStates.dayRound==true)
end

local function terrainEffectApplies(effect,terrain)
    return effect.terrains=="passable" and trackerPrivate.passableTerrain[terrain]==true
        or effect.terrains=="weather" and (trackerPrivate.passableTerrain[terrain]==true or terrain=="city")
        or type(effect.terrains)=="table" and effect.terrains[terrain]==true
end

function resourceCardsEffectiveTerrainCost(terrain)
    local base=gStates~=nil and gStates.moveCost~=nil and gStates.moveCost[terrain] or nil
    if base==nil then base=999 end
    if not resourceCardsPanelOpen() then return base end
    local player=turnOrder~=nil and gStates~=nil
        and turnOrder[gStates.turnNumber] or nil
    local scan=player~=nil and resourceCardScanBySeat[player.seatPos] or nil
    local effects=scan~=nil and scan.terrainModifiers or nil
    if effects==nil then return base end
    -- Explicit traversal permissions (e.g. Song of Wind + extra Blue mana)
    -- may open a lake; ordinary discounts cannot open impassable terrain.
    -- Several simultaneous "set" effects use the lowest applicable cost,
    -- independently of the order in which card/Skill effects were discovered.
    local setCost=nil
    for _,effect in ipairs(effects) do
        if effect.mode=="set" and terrainEffectApplies(effect,terrain) then
            setCost=setCost==nil and effect.cost or math.min(setCost,effect.cost)
        end
    end
    if setCost==nil and base>=900 then return base end
    local cost=setCost or base
    -- Set effects grant traversal first; Path Finding can then discount that
    -- newly passable terrain. A minimum is a floor, not a price increase.
    for _,effect in ipairs(effects) do
        if terrainEffectApplies(effect,terrain) then
            if effect.mode=="cap" then
                cost=math.min(cost,effect.cost)
            elseif effect.mode=="reduce" then
                cost=math.min(cost,math.max(effect.minimum or 0,cost-effect.amount))
            end
        end
    end
    for _,effect in ipairs(effects) do
        if effect.mode=="weather" and terrainEffectApplies(effect,terrain) then
            if effect.amount<0 then cost=math.max(1,cost+effect.amount)
            else cost=math.min(5,cost+effect.amount) end
        end
    end
    return cost
end

-- Exploring is not ordinary terrain. Apply the existing explicit explore modifiers
-- (Hawk Eyes at night, Feral Allies, and any later explore-specific effects).
-- In Hidden Valley the modified price is tripled, not the other way around.
function resourceCardsEffectiveExploreCost()
    local cost=resourceCardsEffectiveTerrainCost("explore")
    -- Owned passive Skills still apply when the tracker has been minimized.
    -- Played-card effects require an active scanner and remain player-managed while OFF.
    if not resourceCardsPanelOpen() and gStates~=nil and turnOrder~=nil
        and turnOrder[gStates.turnNumber]~=nil then
        local seatPos=turnOrder[gStates.turnNumber].seatPos
        for guid,rule in pairs(skillResourceDefinitions) do
            if ownedSkillAtSeat(guid,seatPos) then
                for _,effect in ipairs(rule.passiveTerrain or {}) do
                    if effect.mode=="reduce" and terrainEffectApplies(effect,"explore") then
                        cost=math.max(effect.minimum or 0,cost-effect.amount)
                    end
                end
                if gStates.dayRound~=true then
                    for _,effect in ipairs(rule.passiveNightTerrain or {}) do
                        if effect.mode=="reduce" and terrainEffectApplies(effect,"explore") then
                            cost=math.max(effect.minimum or 0,cost-effect.amount)
                        end
                    end
                end
            end
        end
    end
    if gStates~=nil and gStates.gameScenario=="The Hidden Valley Blitz" then
        cost=cost*3
    end
    return math.max(0,cost)
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
trackerPrivate.resourceChoiceOrder={
    move=1,siege=2,ranged=3,block=4,attack=5,influence=6,healing=7,heal=7,fame=8,
    fireBlock=4,fireAttack=5,fireSiege=2,iceSiege=2
}
local resourceChoiceFamilies={"move","siege","ranged","block","attack","influence","healing"}
local function resourceChoiceRank(category,choice)
    local rank=trackerPrivate.resourceChoiceOrder[category]
    if rank~=nil then return rank end
    -- Choices with non-resource keys (e.g. heal, combat, wound) retain
    -- their unique callback IDs while sorting by what they contribute.
    for i,family in ipairs(resourceChoiceFamilies) do
        for resource,value in pairs(choice) do
            if type(value)=="number" and (resource==family
                or (family=="healing" and resource=="healing")
                or (family=="siege" or family=="ranged"
                    or family=="block" or family=="attack")
                    and resource:sub(1,#family)==family) then
                return i
            end
        end
    end
    return #resourceChoiceFamilies+1
end
local function resourceChoiceColumn(category)
    if category=="fireBlock" then return "block" end
    if category=="fireAttack" then return "attack" end
    if category=="fireSiege" or category=="iceSiege" then return "siege" end
    return category
end
local function sideChoices(rule,powered)
    if rule==nil then return nil end
    -- Do not use 'powered and poweredChoices or normalChoices': Lua falls back
    -- to normal choices when poweredChoices is nil, overriding a fixed powered
    -- effect (e.g. Rage's Attack 4) with its unpowered Attack/Block 2 options.
    if powered then return rule.poweredChoices end
    return rule.normalChoices
end

local function choiceCategory(choice)
    if type(choice)~="table" then return nil end
    -- Two choices may provide the same resource at different values (e.g.
    -- Blood Rage's Attack with/without a Wound). Their explicit key must
    -- identify the button, rather than the first resource field in pairs().
    if type(choice.key)=="string" then return choice.key end
    for category in pairs(choice) do return category end
    return nil
end

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
local function choiceAvailable(choices,category)
    if choices==nil or category==nil then return false end
    for _,effect in ipairs(choices) do
        if choiceCategory(effect)==category then return true end
    end
    return false
end

-- Use the first option on each card from the outset. A previously selected
-- resource is reused on both card sides whenever that side supports it;
-- otherwise display its first option without overwriting the preference.
local function currentChoice(guid,powered,choices,sideways)
    if choices==nil or #choices==0 then return nil,nil end
    local stored=selectedResourceByGUID[guid]
    if stored~=nil then
        -- A separately selected sideways action takes priority while sideways;
        -- upright/strong effects continue to use the printed-action preference.
        local preferred=sideways and stored.sideways or nil
        if not choiceAvailable(choices,preferred) then preferred=stored.effect end
        if choiceAvailable(choices,preferred) then
            for _,effect in ipairs(choices) do
                if choiceCategory(effect)==preferred then return effect,preferred end
            end
        end
    end
    local first=choices[1]
    return first,choiceCategory(first)
end

local function chosenEffect(guid,powered,choices,sideways)
    return currentChoice(guid,powered,choices,sideways)
end

-- Only resources that explicitly split a pool or apply a multi-enemy effect
-- may keep additional right-click arrows. Independent printed effects already
-- have their own source keys and do not need a second arrow on one source.
function resourceCardsCombatAdditionalTargetLimit(sourceKey)
    if type(sourceKey)~="string" then return 1 end
    local seat=combatAssignmentActiveSeat()
    local scan=seat~=nil and resourceCardScanBySeat[seat] or nil
    local guid=sourceKey:match("^[^#]+")
    local record=scan~=nil and scan.cards[guid] or nil
    if record~=nil and record.complete==true then
        for _,key in ipairs(record.enemyEffectTargetKeys or {}) do
            if key==sourceKey then
                local data=gameCards[guid]
                local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
                local index=tonumber(sourceKey:match("#rep(%d+)$"))
                local _,category
                if index~=nil and record.repeatLink~=nil then
                    _,category=combatConfig.repeatChoiceFor(guid,record.powered,
                        record.repeatLink.options~=nil
                            and record.repeatLink.options[index]
                            or sideChoices(rule,record.powered),index)
                else
                    _,category=currentChoice(guid,record.powered,
                        sideChoices(rule,record.powered))
                end
                local spec=combatEffectSpec(rule,record.powered,category)
                if spec~=nil then
                    if spec.multiTargetMove==true then return math.huge,"move" end
                    local maximum=tonumber(spec.maxTargets) or 0
                    if maximum>1 then return maximum,"targets" end
                end
                break
            end
        end
    end
    for _,source in ipairs(combatAssignmentSources(seat)) do
        if source.key==sourceKey then
            local converted=tonumber(source.convertedAmount) or 0
            if converted>1 then return converted,"points" end
            local influence=tonumber(source.psychicInfluence) or 0
            if influence>1 then return influence,"influence" end
            local move=tonumber(source.move) or 0
            if move>1 then return move,"movePoints" end
            break
        end
    end
    return 1
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
        return combatCalcOn and combatCumbersomeActive
            and resourceCardsMoveRole(guid,false)=="combat"
            and "block" or "move"
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

-- Guess once for a newly played choice card. Compare the displayed Resource
-- Tracker family totals (including manual +/-), excluding this card's previous
-- contribution so it cannot vote for its own old selection.
local function trackerChoiceScores(guid,seatPos)
    local tracker=gStates~=nil and gStates.resourceTracker or nil
    local previous=resourceCardScanBySeat[seatPos]
    local estimated=previous~=nil and previous.totals or {}
    local record=previous~=nil and previous.cards[guid] or nil
    local own=record~=nil and record.resources or {}
    local scores={}
    for _,family in ipairs(resourceChoiceFamilies) do
        local value=0
        for field,offset in pairs(tracker~=nil and tracker[family] or {}) do
            -- Reputation and conquered-city shields are valid Interaction
            -- Influence on their own, but are not a generated resource type
            -- for guessing which action the player meant to play.
            if family~="influence" or field=="generated" then
                value=value+offset
            end
        end
        for _,totalKey in pairs(trackerPrivate.resourceTotalsKeyByField[family]) do
            value=value+(estimated[totalKey] or 0)-(own[totalKey] or 0)
        end
        scores[family]=math.max(0,value)
    end
    return scores
end

-- First try to match a resource already contributed by an overlapping (or
-- closely adjacent) played card. Only the first guess uses this spatial hint:
-- selecting an option manually, lifting cards and using U/Place Under must
-- never reassign a previously chosen option.
trackerPrivate.nearbyCardChoice=function(card,choices,seatPos,cards,footprints,records)
    local own=footprints[card.guid]
    if own==nil then return nil end
    local available={}
    for _,choice in ipairs(choices) do
        local category=choiceCategory(choice)
        if category~=nil and choiceLetters[category]~=nil then
            local rank=resourceChoiceRank(category,choice)
            if rank<=#resourceChoiceFamilies and available[rank]==nil then
                available[rank]=category
            end
        end
    end
    if next(available)==nil then return nil end
    local previous=resourceCardScanBySeat[seatPos]
    local best=nil
    for _,other in ipairs(cards) do
        if other.guid~=card.guid and other.is_face_down~=true
            and cardPosture(other)~="discard" then
            local area=footprints[other.guid]
            if area~=nil then
                local gapX=math.max(0,math.abs(own.x-area.x)-own.halfX-area.halfX)
                local gapZ=math.max(0,math.abs(own.z-area.z)-own.halfZ-area.halfZ)
                -- Allow a narrow gap beside a card, not unrelated cards elsewhere
                -- on the mat. Actual overlap always takes precedence over a gap.
                local reach=math.min(own.halfX,area.halfX)*0.5
                local gap=gapX*gapX+gapZ*gapZ
                if gap<=reach*reach then
                    local record=records[other.guid]
                        or (previous~=nil and previous.cards[other.guid] or nil)
                    if record~=nil and record.complete==true
                        and type(record.resources)=="table" then
                        local overlapX=math.max(0,
                            math.min(own.x+own.halfX,area.x+area.halfX)
                            -math.max(own.x-own.halfX,area.x-area.halfX))
                        local overlapZ=math.max(0,
                            math.min(own.z+own.halfZ,area.z+area.halfZ)
                            -math.max(own.z-own.halfZ,area.z-area.halfZ))
                        local overlap=overlapX*overlapZ
                        local distance=(own.x-area.x)^2+(own.z-area.z)^2
                        for rank,category in pairs(available) do
                            local amount=0
                            for _,key in pairs(trackerPrivate.resourceTotalsKeyByField[resourceChoiceFamilies[rank]]) do
                                amount=amount+math.max(0,tonumber(record.resources[key]) or 0)
                            end
                            if amount>0 and (best==nil
                                or overlap>best.overlap
                                or (overlap==best.overlap and gap<best.gap)
                                or (overlap==best.overlap and gap==best.gap
                                    and distance<best.distance)
                                or (overlap==best.overlap and gap==best.gap
                                    and distance==best.distance and amount>best.amount)
                                or (overlap==best.overlap and gap==best.gap
                                    and distance==best.distance and amount==best.amount
                                    and (rank<best.rank or (rank==best.rank
                                        and other.guid<best.guid)))) then
                                best={category=category,overlap=overlap,gap=gap,
                                    distance=distance,amount=amount,rank=rank,guid=other.guid}
                            end
                        end
                    end
                end
            end
        end
    end
    return best~=nil and best.category or nil
end

local function guessInitialCardChoice(card,choices,seatPos,rule,sideways,cards,footprints,records)
    -- A Wound-paid spell must be confirmed by the player, never guessed.
    if rule~=nil and rule.woundConfirmation==true and not sideways then return end
    if selectedResourceByGUID[card.guid]~=nil or choices==nil or #choices<2
        or card.is_face_down==true then return end
    local nearby=trackerPrivate.nearbyCardChoice(card,choices,seatPos,cards,footprints,records)
    local best,bestValue,bestRank=nearby,nil,nil
    if best==nil then
        local scores=trackerChoiceScores(card.guid,seatPos)
        for _,choice in ipairs(choices) do
            local category=choiceCategory(choice)
            local rank=resourceChoiceRank(category,choice)
            if category~=nil and choiceLetters[category]~=nil
                and rank<=#resourceChoiceFamilies then
                local value=scores[resourceChoiceFamilies[rank]]
                if best==nil or value>bestValue or (value==bestValue and rank<bestRank) then
                    best,bestValue,bestRank=category,value,rank
                end
            end
        end
    end
    -- Purely untracked choices (draw/other/etc.) retain their printed default.
    if best==nil then return end
    local selected={}
    if sideways and not choiceAvailable(sideChoices(rule,false),best)
        and not choiceAvailable(sideChoices(rule,true),best) then
        selected.sideways=best
    else
        selected.effect=best
    end
    selectedResourceByGUID[card.guid]=selected
end

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
        colors=broken and "#81372F|#AD5045|#81372F|#81372F"
            or (waitForCombat and "#383838|#505050|#383838|#383838"
                or "#454D5D|#69798E|#444C63|#454D5D"),
        textColor="#FFFFFF",textAlignment="MiddleCenter"},
        value="",
        children={{tag="HorizontalLayout",attributes={
            padding="18 18 9 9",childAlignment="MiddleCenter"},
            children={{tag="Text",attributes={
                text=label,font="Fonts/MKCardText",fontSize=58,
                resizeTextForBestFit="true",resizeTextMinSize=26,
                resizeTextMaxSize=58,color="#FFFFFF",alignment="MiddleCenter",
                raycastTarget="false"}}}}}
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
        local attrs=node~=nil and node.attributes or nil
        local id=attrs~=nil and attrs.id or nil
        if type(id)=="string" and attrs.position~=nil
            and id~=choicePrefix.."artifactBreak"
            and (id:sub(1,#choicePrefix)==choicePrefix
                or id:sub(1,#targetPrefix)==targetPrefix)
            and (node.tag=="Button" or
                (node.tag=="Text" and id:find("_label",1,true)~=nil)) then
            local x,y,z=tostring(attrs.position):match("^(%S+)%s+(%S+)%s+(%S+)$")
            local height=tonumber(attrs.height) or 0
            if x~=nil and tonumber(y)~=nil and height>0 then
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

-- A single selected icon is centred on the object. Click to expand all
-- choices; selecting one immediately collapses back to its icon.
local function showChoiceButtons(card,choices,powered,inventorySpec,inventorySets,resources,repeatLink)
    if card==nil or combatConfig.cardInTransit(card) then return end
    if combatConfig~=nil and combatConfig.phaseObjectLocked~=nil
        and combatConfig.phaseObjectLocked(card.guid) then
        removeChoiceButtons(card)
        choiceButtonShown[card.guid]="hidden"
        choiceExpandedByGUID[card.guid]=nil
        return
    end
    local cardData=gameCards[card.guid]
    local rule=cardData~=nil and cardResourceDefinitions[cardData.resourceKey]
        or skillResourceDefinitions[card.guid]
    local function targetResourceFor(choice,category)
        if category=="ready" and cardData~=nil
            and cardData.resourceKey=="rejuvenate" then return "unitReady" end
        if rule~=nil and rule.blockSourceBoost~=nil then return "blockSource" end
        -- Ambush has ONE reusable target button. An Action card receives the
        -- combat bonus; a Cumbersome enemy receives the independent Move.
        if rule~=nil and rule.combatLink~=nil and cardPosture(card)=="upright"
            and card.is_face_down~=true then return "ambush" end
        -- Mana Overload's choices select which linked CARD resource is boosted;
        -- the Skill itself is not an independently targetable Attack/Block.
        if rule~=nil and rule.manaOverload==true then return nil end
        if not combatCalcOn then return nil end
        if rule~=nil and rule.damageMitigation~=nil then return "effect" end
        for _,field in ipairs(combatConfig.sourceFields) do
            if (tonumber(choice[field.key]) or 0)>0 then return field.key end
        end
        if combatPsychicActive and (tonumber(choice.influence) or 0)>0 then return "influence" end
        if combatCumbersomeActive and (tonumber(choice.move) or 0)>0 then return "move" end
        if rule~=nil and rule.dodgeAttackSplit==true then return nil end
        local spec=combatEffectSpec(rule,powered,category)
        if spec~=nil and not spec.all then return "effect" end
        return choiceHasTargetableCombatResource(category) and category or nil
    end
    -- Give non-resource Skill effects the same dedicated targeting icon used
    -- by the combat calculator, without pretending the bonus is a free Block.
    if rule~=nil and rule.blockSourceBoost~=nil then
        choices={{key="guide",icon="move"}}
    elseif rule~=nil and rule.damageMitigation~=nil then
        choices={{key="hardened",icon="other"}}
    end
    -- Starting cards with selectable conditional effects keep their controls
    -- even when their Move/Influence value is fixed; manual notes need no button.
    if rule~=nil and (rule.interactionReward~=nil or rule.recruitDiscount~=nil
        or rule.selectedTerrainDiscount~=nil)
        and (choices==nil or #choices==0) and type(resources)=="table" then
        if (tonumber(resources.move) or 0)>0 then choices={{move=resources.move}}
        elseif (tonumber(resources.influence) or 0)>0 then
            choices={{influence=resources.influence}} end
    end
    -- Regeneration's Heal and Ready are simultaneous, not a choice.
    if (choices==nil or #choices==0) and rule~=nil
        and rule.simultaneousReady==true and type(resources)=="table"
        and (tonumber(resources.healing) or 0)>0 then
        choices={{healing=resources.healing}}
    end
    -- Ambush has only printed Move, but its independent combat buff must be
    -- targetable even before an enemy is in the play area.
    if (choices==nil or #choices==0) and rule~=nil and rule.combatLink~=nil
        and type(resources)=="table" and (tonumber(resources.move) or 0)>0
        and cardPosture(card)=="upright" and card.is_face_down~=true then
        choices={{move=resources.move}}
    end
    -- Fixed Move effects also require an ordinary grid choice for their phase.
    if (choices==nil or #choices==0) and type(resources)=="table"
        and (tonumber(resources.move) or 0)>0 then
        choices={{move=resources.move}}
    end
    -- A fixed effect (no alternatives) still needs a Target button for its combat resource.
    if (choices==nil or #choices==0) and type(resources)=="table" then
        local bestKey,bestRank
        for key,value in pairs(resources) do
            if type(value)=="number" and value>0 and choiceLetters[key]~=nil
                and choiceHasTargetableCombatResource(key) then
                local rank=key=="move" and 99 or resourceChoiceRank(key,{[key]=value})
                if bestKey==nil or rank<bestRank or (rank==bestRank and key<bestKey) then
                    bestKey,bestRank=key,rank
                end
            end
        end
        if bestKey~=nil then choices={{[bestKey]=resources[bestKey]}} end
    end
    -- Training, Force of Nature (basic) and other manual copied effects
    -- still get one visible reminder row per use. Never manufacture a
    -- numeric effect or an unsupported target for an untracked action.
    if repeatLink~=nil and repeatLink.count>1
        and (choices==nil or #choices==0) then
        choices={{key="other",icon="other"}}
    end
    local posture=cardPosture(card)
    local reward=factionRewardForObject~=nil and factionRewardForObject(card) or nil
    local isSkill=skillTokens[card.guid]~=nil or card.getGMNotes()=="Puppet Master"
        or reward~=nil
    if not resourceCardsDetailsOpen() then
        if choiceButtonShown[card.guid]~="hidden" then
            removeChoiceButtons(card)
            choiceButtonShown[card.guid]="hidden"
        end
        choiceExpandedByGUID[card.guid]=nil
        return
    end
    -- Skill tokens are physically smaller than Action cards, so their choice
    -- buttons (collapsed and expanded) need a larger dedicated scale.
    local buttonScale=isSkill and "0.58 0.58" or "0.25 0.25"
    local buttonSpacing=44
    local buttonRowOffset=-30
    local data=gameCards[card.guid]
    local isArtifact=data~=nil and data.cardType=="Artifact" and data.full==nil
    if isArtifact and posture=="upright" and (choices==nil or #choices==0) then
        local xml=resourceObjectUiXmlTable(card.UI)
        local old={}
        for i,node in ipairs(xml) do old[i]=node end
        for i=#xml,1,-1 do
            local attr=xml[i].attributes
            if attr~=nil and type(attr.id)=="string"
                and (attr.id:sub(1,19)=="ResourceCardChoice_"
                    or attr.id:find("^AttackAssignmentSource_")~=nil) then
                table.remove(xml,i)
            end
        end
        local uiRotation=card.is_face_down==true and "0 180 180" or "0 0 180"
        local depth=card.is_face_down==true and "35" or "-35"
        xml[#xml+1]=trackerPrivate.artifactBreakButton(card,uiRotation,depth)
        if rule~=nil and rule.grailFamePerHealing~=nil and not powered then
            xml[#xml+1]=trackerPrivate.grailFameButton(card,uiRotation,depth)
        end
        if not resourceObjectUiSameXML(old,xml) then resourceObjectUiSetTable(card.UI,xml) end
        combatConfig.cardButtonIds[card.guid]=combatConfig.cardChoiceIds(card.guid,xml)
        choiceButtonShown[card.guid]="artifact-break-only:"..tostring(resourceCardsArtifactBroken(card.guid,card))
        return
    end
    if choices==nil or #choices==0
        or (card.is_face_down==true and not isSkill and not isArtifact and repeatLink==nil)
        or (not isSkill and posture=="discard")
        or (not isSkill and posture=="sideways" and not (cardCanPlaySideways(card)
            or card.getGMNotes()=="Wound")) then
        if choiceButtonShown[card.guid]~="hidden" then
            removeChoiceButtons(card)
            choiceButtonShown[card.guid]="hidden"
        end
        choiceExpandedByGUID[card.guid]=nil
        return
    end

    -- Multiple-choice cards normally have one row. A declarative inventory
    -- set rule adds one more compact row for each complete set of crystals.
    local rows={{index=0,choices=choices}}
    -- Each copied use gets its own visible row, even when the printed
    -- effect has no alternatives. Numeric effects still share one composite
    -- combat source; enemy-only effects may have independent targets.
    if repeatLink~=nil and repeatLink.count>1 and posture=="upright" then
        rows={}
        for i=1,repeatLink.count do
            rows[#rows+1]={index=-i,
                choices=repeatLink.options~=nil and (repeatLink.options[i] or {})
                    or choices}
        end
    end
    if powered and posture=="upright" and inventorySpec~=nil then
        for i=1,(inventorySets or 0) do
            rows[#rows+1]={index=i,choices=inventorySpec.choices}
        end
    end
    local expandedRow=choiceExpandedByGUID[card.guid]
    local signatureParts,visibleAssets,assetSeen={}, {}, {}
    for _,row in ipairs(rows) do
        local _,selected
        if row.index<0 then
            _,selected=combatConfig.repeatChoiceFor(card.guid,powered,row.choices,-row.index)
        elseif row.index==0 then
            _,selected=currentChoice(card.guid,powered,row.choices,
                not isSkill and posture=="sideways")
        else
            _,selected=inventorySetChoice(card.guid,row.index,row.choices,choices)
        end
        row.selected=selected
        if selected~=nil and combatCalcOn and combatCumbersomeActive
            and resourceCardsMoveRole(card.guid,false)=="combat" then
            for _,option in ipairs(row.choices) do
                if choiceCategory(option)==selected and (tonumber(option.move) or 0)>0 then
                    row.selected="combatMove"..selected
                    break
                end
            end
        end
        row.entries={}
        local seen={}
        for j,choice in ipairs(row.choices) do
            local category=choiceCategory(choice)
            if category~=nil and choiceLetters[category]~=nil and not seen[category] then
                seen[category]=true
                local producesMove=(tonumber(choice.move) or 0)>0
                local entry={category=category,
                    rank=resourceChoiceRank(category,choice),originalIndex=j,
                    skillFamily=isSkill and skillChoiceFamily(category,choice) or nil,
                    icon=combatReductionChoiceIcon(rule,powered,choice,category),
                    iconOverlay=choice.iconOverlay,
                    stackedIcons=choice.stackedIcons,splitTargets=choice.splitTargets,
                    forkedCount=rule~=nil and rule.forkedLightning and choice.rangedColdFire or nil,
                    targetResource=targetResourceFor(choice,category),
                    iconOverlayColor=choice.iconOverlayColor,
                    iconOverlayAlignment=choice.iconOverlayAlignment,
                    iconOverlaySize=choice.iconOverlaySize,
                    roleBadge=producesMove and "M" or nil}
                -- In combat, Influence can be committed to Psychic Block.
                -- Show its function with shield beneath the Influence symbol.
                if category=="influence" and combatPsychicActive
                    and (tonumber(choice.influence) or 0)>0 then
                    entry.icon="block"
                    entry.stackedIcons={"block","influence"}
                end
                if producesMove then
                    -- Two cells, one printed Move effect. Never duplicate points.
                    entry.targetResource=nil
                    row.entries[#row.entries+1]=entry
                    -- Only offer defensive Move when at least one enemy has
                    -- Cumbersome. Normal Move stays available otherwise.
                    if combatCalcOn and combatCumbersomeActive then
                        local combatEntry={}
                        for key,value in pairs(entry) do combatEntry[key]=value end
                        combatEntry.category="combatMove"..category
                        combatEntry.originalIndex=j+0.5
                        -- Match Tempered Steel: both icons are full-size,
                        -- drawn in order with the Move symbol on top.
                        combatEntry.icon="block"
                        combatEntry.stackedIcons={"block","move"}
                        combatEntry.roleBadge=nil
                        combatEntry.targetResource="move"
                        row.entries[#row.entries+1]=combatEntry
                    end
                else
                    row.entries[#row.entries+1]=entry
                end
            end
        end
        table.sort(row.entries,function(a,b)
            if a.rank~=b.rank then return a.rank<b.rank end
            return a.originalIndex<b.originalIndex
        end)
        for _,entry in ipairs(row.entries) do
            -- The Combat Calculator assigns ordinary Attack/Block to the lone
            -- enemy automatically. Keep all special split, manual and friendly
            -- target controls, even if they currently have only one candidate.
            if entry.targetResource~=nil and entry.splitTargets==nil
                and (rule==nil or rule.forkedLightning~=true)
                and resourceCardsHideAutomaticEnemyTarget(card.guid,
                    entry.targetResource,false) then
                entry.targetResource=nil
            end
        end
        if #row.entries<1 or selected==nil then
            if choiceButtonShown[card.guid]~="hidden" then
                removeChoiceButtons(card)
                choiceButtonShown[card.guid]="hidden"
            end
            choiceExpandedByGUID[card.guid]=nil
            return
        end
        row.expanded=#row.entries>1 and ((row.index==0 and (expandedRow==true or expandedRow=="base"))
            or (row.index>0 and expandedRow=="set"..tostring(row.index))
            or (row.index<0 and expandedRow=="rep"..tostring(-row.index)))
        local selectedEntry
        for _,entry in ipairs(row.entries) do
            if entry.category==row.selected then selectedEntry=entry break end
        end
        row.visible=row.expanded and row.entries or {selectedEntry}
        local categories={}
        for _,entry in ipairs(row.visible) do
            categories[#categories+1]=entry.category
            if not assetSeen[entry.icon] then
                visibleAssets[#visibleAssets+1]=entry.icon
                assetSeen[entry.icon]=true
            end
            for _,stackedIcon in ipairs(entry.stackedIcons or {}) do
                if not assetSeen[stackedIcon] then
                    visibleAssets[#visibleAssets+1]=stackedIcon
                    assetSeen[stackedIcon]=true
                end
            end
            if not row.expanded and entry.targetResource~=nil
                and not assetSeen.target then
                visibleAssets[#visibleAssets+1]="target"
                assetSeen.target=true
            end
            for _,part in ipairs(not row.expanded and entry.splitTargets or {}) do
                if not assetSeen[part] then
                    visibleAssets[#visibleAssets+1]=part
                    assetSeen[part]=true
                end
            end
        end
        signatureParts[#signatureParts+1]=row.index..":"..row.selected..":"
            ..(row.expanded and "open" or "closed")..":"..table.concat(categories,",")
    end
    local buttonRotation=180
    if posture=="sideways" then
        buttonRotation=card.getRotation()[2]%360<180 and 90 or 270
    end
    local uiRotation=card.is_face_down==true and "0 180 180" or ("0 0 "..buttonRotation)
    local hardenedTarget=rule~=nil and rule.damageMitigation~=nil
        and combatAssignmentState.targets[card.guid] or nil
    local hardenedOptions=hardenedTarget~=nil and combatHardenedAttackOptions(hardenedTarget) or {}
    local mitigationStateKey=card.guid=="ae8673" and "elementalResistanceAttackKey"
        or "battleHardenedAttackKey"
    local hardenedKey=gStates~=nil and gStates[mitigationStateKey] or nil
    local hardenedIndex=1
    for i,option in ipairs(hardenedOptions) do
        if option.key==hardenedKey then hardenedIndex=i break end
    end
    -- Keep Skill icons just clear of the token surface to prevent
    -- z-fighting/flicker when the camera moves. Other object UI depths stay put.
    local buttonDepth=isSkill and (card.is_face_down==true and "12" or "-12")
        or (card.is_face_down==true and "35" or "-35")
    local conversion,conversionBudget,conversionValid=nil,0,false
    if rule~=nil and rule.combatConversion~=nil and combatCalcOn
        and posture=="upright" and resources~=nil then
        conversion,conversionBudget,conversionValid=combatConfig.conversionFor(
            combatAssignmentActiveSeat(),rule.combatConversion)
        -- The first scan has not stored its new records yet; the card itself
        -- is already a valid source and must receive its controls immediately.
        conversionValid=conversion~=nil
    end
    local special=gStates~=nil and gStates.startingCardSelections~=nil
        and gStates.startingCardSelections[card.guid] or nil
    local readyLinks={}
    if rule~=nil and (rule.readyWithInfluence~=nil or rule.simultaneousReady==true) then
        for sourceKey in pairs(gStates~=nil and gStates.unitReadyLinks or {}) do
            if sourceKey:match("^"..card.guid.."#ready%d+$") then
                readyLinks[#readyLinks+1]=sourceKey
            end
        end
        table.sort(readyLinks)
    end
    local readyCount=#readyLinks
    -- Keep the Ready control for undo while links exist; otherwise show it
    -- only if the active Unit layout has a spent, eligible target.
    local canReadyUnit=rule~=nil and rule.readyWithInfluence~=nil and powered
        and attackAssignmentsHasReadyTarget~=nil
        and attackAssignmentsHasReadyTarget(
            turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber]~=nil
                and turnOrder[gStates.turnNumber].seatPos or nil,
            rule.readyWithInfluence.maxLevel) or false
    local signature=(posture=="sideways" and "S" or (powered and "P" or "N"))
        ..":"..table.concat(signatureParts,";")..":"..uiRotation..":"..buttonDepth
        ..(combatCalcOn and (combatCumbersomeActive and ":CC" or ":C") or "")
        ..":PSY:"..tostring(combatPsychicActive)
        ..(rule~=nil and rule.damageMitigation~=nil
            and (":H:"..tostring(hardenedTarget)..":"..tostring(#hardenedOptions)
                ..":"..tostring(hardenedIndex)) or "")
        ..(rule~=nil and rule.forkedLightning
            and (":FL:"..tostring(gStates~=nil and gStates.forkedLightningPhase or "range")) or "")
        ..(conversionValid and conversion~=nil and (":CV:"..tostring(conversionBudget)..":"
            ..tostring(conversion.attack)..":"..tostring(conversion.ranged)..":"
            ..tostring(conversion.block)..":"..tostring(conversion.element)
            ..":"..table.concat(conversion.blockUses or {},",")
            ..":"..table.concat(conversion.elementUses or {},",")) or "")
        ..(special~=nil and (":START:"..tostring(special.interaction)..":"
            ..tostring(special.recruited)..":"..tostring(special.terrain)) or "")
        ..":READY:"..tostring(readyCount)..":"..table.concat(readyLinks,",")
        ..":READY_ELIGIBLE:"..tostring(canReadyUnit)
        ..":ARTIFACT_BREAK:"..tostring(isArtifact and resourceCardsArtifactBroken(card.guid,card))
        ..":ENEMY_PRESENT:"..tostring(combatEnemyInPlay)
        ..":GRAIL:"..tostring(gStates~=nil and gStates.artifactGrailHealingUsed~=nil
            and gStates.artifactGrailHealingUsed[card.guid] or 0)
        ..":TARGETS:"..tostring(trackerPrivate.singleAutoEnemyGUID)
    if choiceButtonShown[card.guid]==signature
        and combatConfig.cardChoicesPresent(card) then return end
    local xml=resourceObjectUiXmlTable(card.UI)
    -- Preserve the actual pre-render object UI for a structural comparison.
    -- Unrelated object buttons remain in both lists, and moving a card with
    -- unchanged choices does not require a destructive TTS UI rebuild.
    local previousXml={}
    for index,node in ipairs(xml) do previousXml[index]=node end
    for i=#xml,1,-1 do
        local attr=xml[i].attributes
        if attr~=nil and type(attr.id)=="string"
            and (attr.id:sub(1,19)=="ResourceCardChoice_"
                or attr.id:find("^AttackAssignmentSource_")~=nil) then table.remove(xml,i) end
    end
    local otherControlCount=#xml
    if conversionValid then visibleAssets[#visibleAssets+1]="target" end
    if rule~=nil and rule.dodgeAttackSplit and combatCalcOn
        and posture=="upright" and resources~=nil then
        visibleAssets[#visibleAssets+1]="attackReduction"
        visibleAssets[#visibleAssets+1]="target"
    end
    if rule~=nil and rule.defeatArmourReduce~=nil and powered and combatCalcOn
        and posture=="upright" then
        visibleAssets[#visibleAssets+1]="armourReduction"
        visibleAssets[#visibleAssets+1]="target"
    end
    local assets,blocked=resourceCardsChoiceAssetsFor(card.UI,visibleAssets)
    local multi=#rows>1
    for rowPosition,row in ipairs(rows) do
        local columns,columnByCategory={},{}
        for _,entry in ipairs(row.visible) do
            local column=resourceChoiceColumn(entry.category)
            if columnByCategory[column]==nil then
                columns[#columns+1]=column
                columnByCategory[column]=#columns
            end
        end
        local y=isSkill and 0 or (-12-(#rows-1)*15+(rowPosition-1)*30)
        -- 0 = printed stronger effect; 1, 2, ... = crystal set bonuses.
        if multi then
            xml[#xml+1]={tag="Text",attributes={
                id="ResourceCardChoice_"..card.guid.."_label"..row.index,
                position="-80 "..tostring(y).." "..buttonDepth,rotation=uiRotation,
                width=60,height=90,scale="0.25 0.25",fontSize=62,
                color="#DAE1EA",alignment="MiddleCenter",
                raycastTarget="false",text=tostring(math.abs(row.index))}}
        end
        local displayed={}
        for _,entry in ipairs(row.visible) do displayed[entry.category]=true end
        local skillPositions=isSkill and skillChoicePositions(row.visible) or nil
        for entryIndex,entry in ipairs(row.visible) do
            local category=entry.category
            local column=resourceChoiceColumn(category)
            local x=((#columns+1)/2-columnByCategory[column])*buttonSpacing
            local above=row.expanded and category~=column and displayed[column]==true
            local buttonY=y+(above and buttonRowOffset or 0)
            if skillPositions~=nil then
                x=skillPositions[category].x
                buttonY=skillPositions[category].y
            end
            -- Blood Fury has three wound-scaled Attacks in one horizontal row.
            if reward~=nil and reward.name=="Blood Fury Dagger" then
                x=((#row.visible+1)/2-entryIndex)*104
                buttonY=0
            end
            local active=category==row.selected
            local icon=resourceCardsChoiceIcon(entry.icon)
            if icon~=nil and blocked[icon.name] then icon=nil end
            local buttonId="ResourceCardChoice_"..card.guid.."_"
                ..(row.index>0 and ("set"..row.index.."_")
                    or row.index<0 and ("rep"..(-row.index).."_") or "")..category
            -- Fixed copied effects still need a visible icon in each row.
            -- It is deliberately not clickable: there is no alternative.
            if #row.entries>1 or (repeatLink~=nil and repeatLink.count>1) then
                local button={tag="Button",attributes={
                    id=buttonId,onClick=#row.entries>1
                        and "global/resourceCardsChoiceClicked" or nil,
                    position=tostring(x).." "..tostring(buttonY).." "..buttonDepth,
                    rotation=uiRotation,width=90,height=90,
                    scale=buttonScale,
                    colors=active and "#387D30|#4CA940|#387D30|#387D30"
                        or "#454D5D|#69798E|#444C63|#454D5D",
                    fontSize=77,textColor="#FFFFFF",textAlignment="MiddleCenter"
                },value=icon==nil and (choiceLetters[category]
                    or (category:sub(1,10)=="combatMove" and "C") or "") or ""}
                if icon~=nil then
                    if entry.stackedIcons~=nil then
                        button.children={}
                        -- Listed back to front: later icons draw over earlier ones.
                        for _,stackedIcon in ipairs(entry.stackedIcons) do
                            local stackedAsset=resourceCardsChoiceIcon(stackedIcon)
                            if stackedAsset~=nil and not blocked[stackedAsset.name] then
                                button.children[#button.children+1]={tag="Image",attributes={
                                    image=stackedAsset.name,width=82,height=82,
                                    preserveAspect="true",raycastTarget="false",color="#FFFFFF"}}
                            end
                        end
                    else
                        button.children={{tag="Image",attributes={
                            image=icon.name,width=82,height=82,preserveAspect="true",
                            raycastTarget="false",color="#FFFFFF"}}
                        }
                    end
                    local mark=entry.iconOverlay
                    if mark==nil and (category=="fireAttack" or category=="fireBlock") then
                        mark="F" -- Existing Battle Versatility fire icons.
                    end
                    if mark~=nil then
                        button.children[#button.children+1]={tag="Text",attributes={
                            text=mark,width=82,height=82,
                            alignment=entry.iconOverlayAlignment or "MiddleCenter",
                            fontSize=tonumber(entry.iconOverlaySize) or 62,
                            fontStyle="Bold",color=entry.iconOverlayColor or "#FF564A",
                            outline="#1C1514",outlineSize="2 -2",
                            raycastTarget="false"}}
                    end
                end
                if entry.roleBadge~=nil then
                    button.children=button.children or {}
                    button.children[#button.children+1]={tag="Text",attributes={
                        text=entry.roleBadge,width=34,height=34,
                        alignment="LowerRight",fontSize=37,fontStyle="Bold",
                        color=entry.roleBadge=="C" and "#69AEFF" or "#9AFFA4",
                        outline="#101820",outlineSize="2 -2",
                        raycastTarget="false"}}
                end
                -- Text-only alternatives (e.g. Chivalry's Reputation choice) are
                -- real buttons even when no custom icon asset exists.
                xml[#xml+1]=button
            end
            if not row.expanded and entry.targetResource~=nil then
                local resource=row.index>0 and ("set"..row.index..":"..entry.targetResource) or entry.targetResource
                local targetX=x
                if #row.entries>1 or (repeatLink~=nil and repeatLink.count>1) then
                    -- Skill tokens push the target button out a further half button width.
                    local gap=buttonSpacing/2+(isSkill and 90*0.70/2 or 0)
                    targetX=x+(x>=0 and gap or -gap)
                end
                local targetAsset=resourceCardsChoiceIcon("target")
                -- A split choice gets one target button per resource, each marked with its icon.
                ---@type (string|boolean)[]
                local parts=entry.splitTargets or {false}
                if rule~=nil and rule.forkedLightning then
                    parts={}
                    for point=1,math.min(3,math.max(1,entry.forkedCount or 1)) do
                        parts[#parts+1]="fork"..point
                    end
                end
                for partIndex,part in ipairs(parts) do
                    local partX=rule~=nil and rule.forkedLightning
                        and targetX+(partIndex-(#parts+1)/2)*buttonSpacing*1.85
                        or targetX+(partIndex-1)*buttonSpacing*(targetX>=0 and 1 or -1)
                    local children={}
                    if part and not (rule~=nil and rule.forkedLightning) then
                        local partAsset=resourceCardsChoiceIcon(part)
                        if partAsset~=nil and not blocked[partAsset.name] then
                            children[#children+1]={tag="Image",attributes={
                                image=partAsset.name,width=62,height=62,
                                preserveAspect="true",raycastTarget="false",color="#FFFFFF"}}
                        end
                    end
                    children[#children+1]={tag="Image",attributes={
                        image=targetAsset.name,width=82,height=82,
                        preserveAspect="true",raycastTarget="false",color="#FFFFFF"}}
                    if rule~=nil and rule.forkedLightning then
                        children[#children+1]={tag="Text",attributes={
                            text=tostring(partIndex),width=58,height=58,fontSize=48,
                            alignment="LowerRight",color="#FFFFFF",
                            outline="#141820",outlineSize="2 -2",raycastTarget="false"}}
                    end
                    local independentEffect=row.index<0 and entry.targetResource=="effect"
                        and rule~=nil and rule.enemyEffect~=nil
                        and combatEffectSpec(rule,powered,entry.category)~=nil
                    local targetPart=independentEffect and ("rep"..(-row.index))
                        or part
                    local targetCategory=entry.targetResource
                    if row.index<0 and targetCategory=="unitReady" then
                        targetPart="use"..(-row.index)
                    end
                    xml[#xml+1]={tag="Button",attributes={
                        id="AttackAssignmentSource_"..card.guid.."_0_"
                            ..(row.index<0 and targetCategory~="unitReady"
                                and ("rep"..(-row.index)..":") or "")..targetCategory
                            ..(targetPart and ("@"..targetPart) or ""),
                        onClick=entry.targetResource=="unitReady"
                            and "global/attackAssignmentReadySourceClicked"
                            or (entry.targetResource=="blockSource"
                                and "global/resourceCardsBlockSourceLinkClicked"
                                or (entry.targetResource=="ambush"
                                    and "global/attackAssignmentAmbushSourceClicked"
                                    or "global/attackAssignmentSourceClicked")),
                        position=tostring(partX).." "..tostring(buttonY).." "..buttonDepth,
                        rotation=uiRotation,width=90,height=90,scale=buttonScale,
                        colors="#454D5D|#69798E|#444C63|#454D5D",textColor="#FFFFFF",textAlignment="MiddleCenter"
                    },value="",children=children}
                end
            end
        end
    end
    -- Dodge and Weave has no option selector: its normal Attack target follows
    -- other Attack cards, while these buttons independently reduce enemy Attacks.
    if rule~=nil and rule.dodgeAttackSplit and combatCalcOn
        and posture=="upright" and resources~=nil then
        local perUse=powered and 2 or 1
        local repeatCount=repeatLink~=nil and repeatLink.count or 1
        local count=perUse*repeatCount
        local targetAsset=resourceCardsChoiceIcon("target")
        local reduceAsset=resourceCardsChoiceIcon("attackReduction")
        -- Each copied use has its own effect targets. The printed Attack
        -- points still form one composite combat source.
        local targetX=-44
        for index=1,count do
            local useIndex=math.floor((index-1)/perUse)+1
            local withinUse=(index-1)%perUse
            local targetY=-12-(repeatCount-1)*15+(useIndex-1)*30
            local children={}
            if reduceAsset~=nil and not blocked[reduceAsset.name] then
                children[#children+1]={tag="Image",attributes={image=reduceAsset.name,
                    width=76,height=76,preserveAspect="true",raycastTarget="false"}}
            end
            if targetAsset~=nil and not blocked[targetAsset.name] then
                children[#children+1]={tag="Image",attributes={image=targetAsset.name,
                    width=42,height=42,preserveAspect="true",raycastTarget="false",
                    rectAlignment="LowerRight"}}
            end
            xml[#xml+1]={tag="Button",attributes={
                id="AttackAssignmentSource_"..card.guid.."_0_effect@effect"..index,
                onClick="global/attackAssignmentSourceClicked",
                position=tostring(targetX-withinUse*44).." "..tostring(targetY).." "..buttonDepth,
                rotation=uiRotation,width=90,height=90,scale=buttonScale,
                colors="#454D5D|#69798E|#444C63|#454D5D",
                textColor="#FFFFFF",textAlignment="MiddleCenter"},
                value=#children==0 and "-2" or "",
                children=children}
        end
    end
    -- Two small pool-allocation counters on Agility (Attack/Ranged), or one
    -- on Diplomacy (Block). Left click spends; right click returns points.
    -- Converted points remain independently targetable from the printed Move
    -- or Influence resource. No other printed card is duplicated.
    if conversionValid and conversion~=nil then
        local agility=rule.combatConversion=="agility"
        local multiDiplomacy=not agility and repeatLink~=nil
            and repeatLink.count>1
        local controls=agility and
            {{part="Attack",value=conversion.attack,label="A",x=-145,y=135},
             {part="Ranged",value=conversion.ranged,label="R",x=15,y=135}}
            or {{part="Block",value=conversion.block,label="B",x=-80,y=135}}
        if multiDiplomacy then
            controls={}
            for index=1,repeatLink.count do
                controls[#controls+1]={part="Block"..index,
                    value=conversion.blockUses~=nil
                        and conversion.blockUses[index] or 0,label="B"..index,
                    x=-152,y=-12-(repeatLink.count-1)*15+(index-1)*30,
                    index=index}
            end
        end
        for _,control in ipairs(controls) do
            xml[#xml+1]={tag="Button",attributes={
                id="ResourceCardChoice_"..card.guid.."_convert"..control.part,
                onClick="global/resourceCardsConversionClicked",
                position=tostring(control.x).." "..tostring(control.y).." "..buttonDepth,
                rotation=uiRotation,width=125,height=90,scale="0.30 0.30",
                fontSize=55,colors="#454D5D|#69798E|#444C63|#454D5D",
                textColor="#FFFFFF",textAlignment="MiddleCenter"},
                value=control.label..tostring(control.value)}
            if control.value>0 then
                local targetAsset=resourceCardsChoiceIcon("target")
                local children={}
                if targetAsset~=nil and not blocked[targetAsset.name] then
                    children[#children+1]={tag="Image",attributes={
                        image=targetAsset.name,width=78,height=78,
                        preserveAspect="true",raycastTarget="false"}}
                end
                xml[#xml+1]={tag="Button",attributes={
                    id="AttackAssignmentSource_"..card.guid.."_0_"
                        ..string.lower(control.part).."@convert"..control.part,
                    onClick="global/attackAssignmentSourceClicked",
                    position=tostring(multiDiplomacy and 174 or control.x+73)
                        .." "..tostring(control.y).." "..buttonDepth,
                    rotation=uiRotation,width=90,height=90,
                    scale="0.25 0.25",fontSize=60,
                    colors="#454D5D|#69798E|#444C63|#454D5D",
                    textColor="#FFFFFF",textAlignment="MiddleCenter"},
                    value=#children==0 and "T" or "",children=children}
            end
            if multiDiplomacy and powered then
                xml[#xml+1]={tag="Button",attributes={
                    id="ResourceCardChoice_"..card.guid.."_convertElement"..control.index,
                    onClick="global/resourceCardsConversionClicked",
                    position="103 "..tostring(control.y).." "..buttonDepth,
                    rotation=uiRotation,width=105,height=90,
                    scale="0.30 0.30",fontSize=55,
                    colors="#454D5D|#69798E|#444C63|#454D5D",
                    textColor="#FFFFFF",textAlignment="MiddleCenter"},
                    value=conversion.elementUses~=nil
                        and conversion.elementUses[control.index] or "F"}
            end
        end
        if not agility and powered and not multiDiplomacy then
            xml[#xml+1]={tag="Button",attributes={
                id="ResourceCardChoice_"..card.guid.."_convertElement",
                onClick="global/resourceCardsConversionClicked",
                position="100 135 "..buttonDepth,rotation=uiRotation,
                width=105,height=90,scale="0.30 0.30",fontSize=55,
                colors="#454D5D|#69798E|#444C63|#454D5D",
                textColor="#FFFFFF",textAlignment="MiddleCenter"},
                value=conversion.element}
        end
        xml[#xml+1]={tag="Text",attributes={
            id="ResourceCardChoice_"..card.guid.."_convertHint",
            position="0 190 "..buttonDepth,rotation=uiRotation,
            width=300,height=50,scale="0.25 0.25",fontSize=45,
            alignment="MiddleCenter",color="#E6E1D7",
            raycastTarget="false",text="Left + / Right -"}}
    end
    -- A multi-attack target needs an explicit choice of which single Attack
    -- Battle Hardened will mitigate. The cycling button is on the Skill, not
    -- the enemy, and never changes the existing calculator columns.
    if rule~=nil and rule.damageMitigation~=nil and #hardenedOptions>1 then
        xml[#xml+1]={tag="Button",attributes={
            id="ResourceCardChoice_"..card.guid.."_hardenedCycle",
            onClick="global/resourceCardsBattleHardenedAttackClicked",
            position="-105 0 "..buttonDepth,rotation=uiRotation,
            width=110,height=90,scale="0.42 0.42",fontSize=55,
            colors="#454D5D|#69798E|#444C63|#454D5D",
            textColor="#FFFFFF",textAlignment="MiddleCenter"},
            value=tostring(hardenedIndex).."/"..tostring(#hardenedOptions)}
    end
    if rule~=nil and rule.defeatArmourReduce~=nil and powered and combatCalcOn
        and posture=="upright" and resources~=nil then
        local reductionAsset=resourceCardsChoiceIcon("armourReduction")
        local targetAsset=resourceCardsChoiceIcon("target")
        local children={}
        if reductionAsset~=nil and not blocked[reductionAsset.name] then
            children[#children+1]={tag="Image",attributes={
                image=reductionAsset.name,width=75,height=75,
                preserveAspect="true",raycastTarget="false",color="#FFFFFF"}}
        end
        if targetAsset~=nil and not blocked[targetAsset.name] then
            children[#children+1]={tag="Image",attributes={
                image=targetAsset.name,width=45,height=45,
                preserveAspect="true",raycastTarget="false",color="#FFFFFF",
                rectAlignment="LowerRight"}}
        end
        xml[#xml+1]={tag="Button",attributes={
            id="AttackAssignmentSource_"..card.guid.."_0_attack@explosiveAttack",
            onClick="global/attackAssignmentSourceClicked",
            position="140 0 "..buttonDepth,rotation=uiRotation,
            width=90,height=90,scale=buttonScale,fontSize=46,
            colors="#454D5D|#69798E|#444C63|#454D5D",
            textColor="#FFFFFF",textAlignment="MiddleCenter"},
            value=#children==0 and "Arm" or "",children=children}
    end
    if rule~=nil and rule.forkedLightning then
        local phase=gStates~=nil and gStates.forkedLightningPhase or "range"
        xml[#xml+1]={tag="Button",attributes={
            id="ResourceCardChoice_"..card.guid.."_forkPhase",
            onClick="global/resourceCardsForkedLightningPhaseClicked",
            position="160 0 "..buttonDepth,rotation=uiRotation,
            width=140,height=90,scale="0.38 0.38",fontSize=47,
            colors="#454D5D|#69798E|#444C63|#454D5D",
            textColor="#FFFFFF",textAlignment="MiddleCenter"},
            value=phase=="range" and "RNG" or "ATK"}
    end
    if rule~=nil and posture=="upright" and card.is_face_down~=true then
        local function startingControl(suffix,label,active,x,y)
            xml[#xml+1]={tag="Button",attributes={
                id="ResourceCardChoice_"..card.guid.."_"..suffix,
                onClick="global/resourceCardsStartingCardControlClicked",
                position=tostring(x).." "..tostring(y).." "..buttonDepth,
                rotation=uiRotation,width=160,height=90,scale="0.28 0.28",
                fontSize=41,textColor="#FFFFFF",textAlignment="MiddleCenter",
                colors=active and "#387D30|#4CA940|#387D30|#387D30"
                    or "#454D5D|#69798E|#444C63|#454D5D"},
                value=label}
        end
        if rule.interactionReward~=nil then
            startingControl("interaction","INT",
                special~=nil and special.interaction==true,135,-125)
        elseif rule.recruitDiscount~=nil and not powered then
            startingControl("recruit","-2 REC",
                special~=nil and special.recruited==true,135,-125)
        elseif rule.readyWithInfluence~=nil and powered
            and (canReadyUnit or readyCount>0) then
            startingControl("ruthlessReady","RDY "..tostring(readyCount),
                readyCount>0,145,-125)
        elseif rule.selectedTerrainDiscount~=nil and powered then
            startingControl("terrain",special~=nil and special.terrain~=nil
                and special.terrain:sub(1,3):upper() or "TER",
                special~=nil and special.terrain~=nil,150,-125)
        end
    end
    if rule~=nil and isArtifact
        and cardData.resourceKey=="artifactBannerFortitude"
        and trackerPrivate.bannerStrongActive(card) and posture=="upright"
        and not combatEnemyInPlay and not combatCalcOn
        and not trackerPrivate.bannerEffectUses().healing[card.guid] then
        xml[#xml+1]={tag="Button",attributes={
            id="ResourceCardChoice_"..card.guid.."_healAllUnits",
            onClick="global/resourceCardsArtifactHealUnitsClicked",
            position="145 -145 "..buttonDepth,rotation=uiRotation,
            width=160,height=85,scale="0.28 0.28",fontSize=40,
            colors="#454D5D|#69798E|#444C63|#454D5D",
            textColor="#FFFFFF",textAlignment="MiddleCenter"},value="HEAL"}
    end
    if rule~=nil and rule.staffDualChoices==true and posture=="upright" then
        -- Colour identity, not the shared numeric 'other=1', grants Ready.
        -- Ready may have been played earlier, but cannot be activated in combat.
        local _,first=currentChoice(card.guid,powered,choices)
        local second=nil
        if powered then
            local remaining={}
            for _,option in ipairs(choices or {}) do
                if choiceCategory(option)~=first then remaining[#remaining+1]=option end
            end
            _,second=inventorySetChoice(card.guid,1,remaining,choices)
        end
        local redReady=type(resources)=="table" and not combatEnemyInPlay
            and (first=="red" or second=="red")
        if redReady then
            xml[#xml+1]={tag="Button",attributes={
                id="AttackAssignmentSource_"..card.guid.."_0_unitReady",
                onClick="global/attackAssignmentReadySourceClicked",
                position="150 -145 "..buttonDepth,rotation=uiRotation,
                width=150,height=85,scale="0.28 0.28",fontSize=46,
                colors="#454D5D|#69798E|#444C63|#454D5D",textColor="#FFFFFF",
                textAlignment="MiddleCenter"},value="RDY"}
        end
    end
    if rule~=nil and rule.simultaneousReady==true and posture=="upright"
        and resources~=nil and (tonumber(resources.healing) or 0)>0
        and (card.is_face_down~=true or repeatLink~=nil) then
        for index=1,(repeatLink~=nil and repeatLink.count or 1) do
            local sourceKey=card.guid.."#ready"..index
            local linked=gStates~=nil and gStates.unitReadyLinks~=nil
                and gStates.unitReadyLinks[sourceKey]~=nil
            xml[#xml+1]={tag="Button",attributes={
                id="ResourceCardChoice_"..card.guid.."_regenReady"..index,
                onClick="global/resourceCardsRegenerationReadyClicked",
                position="145 "..tostring(-125+(index-1)*62).." "..buttonDepth,
                rotation=uiRotation,width=150,height=90,scale="0.28 0.28",
                fontSize=44,textColor="#FFFFFF",textAlignment="MiddleCenter",
                colors=linked and "#387D30|#4CA940|#387D30|#387D30"
                    or "#454D5D|#69798E|#444C63|#454D5D"},
                value="RDY"..(repeatLink~=nil and tostring(index) or "")}
        end
    end
    if isArtifact and posture=="upright" then
        trackerPrivate.raiseArtifactChoiceControls(xml,otherControlCount+1,card.guid)
        xml[#xml+1]=trackerPrivate.artifactBreakButton(card,uiRotation,buttonDepth)
        if rule~=nil and rule.grailFamePerHealing~=nil and not powered then
            xml[#xml+1]=trackerPrivate.grailFameButton(card,uiRotation,buttonDepth)
        end
    end
    -- A fixed Attack/Block against a sole enemy needs no manual target icon.
    -- That can leave an otherwise empty object UI; TTS rejects setXmlTable({})
    -- with an Object reference error. The shared writer uses setXml("") here.
    -- A harmless signature change (for example, another enemy's target
    -- context during a card drop) must not flash an unchanged card UI.
    -- New image registrations still need the asset-list writer.
    if assets~=nil or not resourceObjectUiSameXML(previousXml,xml) then
        resourceObjectUiSetTable(card.UI,xml,assets)
        if trackerPrivate.traceEnabled then
            trackerPrivate.traceEvent("choice.write",nil,card.guid,
                "buttons="..tostring(#combatConfig.cardChoiceIds(card.guid,xml)))
        end
    elseif trackerPrivate.traceEnabled then
        trackerPrivate.traceEvent("choice.same",nil,card.guid)
    end
    combatConfig.cardButtonIds[card.guid]=combatConfig.cardChoiceIds(card.guid,xml)
    choiceButtonShown[card.guid]=signature
end


-- One selected icon in the Unit's lower-left artwork margin, away from
-- its Command token. Expand vertically in printed ability order.
-- Alternatives sharing a printed row occupy adjacent columns to the right.
-- This is intentionally independent of translated text position.
local function showUnitAbilityButtons(unit,abilities,activation,unwounded,decision,useIndex)
    if unit==nil then return end
    if combatConfig~=nil and combatConfig.phaseObjectLocked~=nil
        and combatConfig.phaseObjectLocked(unit.guid) then
        removeChoiceButtons(unit)
        choiceButtonShown[unit.guid]="hidden"
        return
    end
    useIndex=useIndex or unitHistorySelectedNumber(unit.guid)
    if not unwounded or activation==nil or abilities==nil or #abilities==0 then
        removeChoiceButtons(unit)
        choiceExpandedByGUID[unit.guid]=nil
        return
    end
    local decision=decision or unitManaDecision(unit,abilities,activation,
        activation.frozenCounts)
    local available=decision.display
    local combatBlocked=combatConfig.unitCombatBlocked~=nil
        and combatConfig.unitCombatBlocked(unit,abilities,useIndex) or false
    local targetSpecs={}
    do
        local function addTarget(index)
            local ability=abilities[index]
            if ability==nil or (combatBlocked and unitHistoryIsCombatAbility(ability)) then return end
            if ability.key=="ready" then
                targetSpecs[#targetSpecs+1]={index=index,category="unitReady",
                    idCategory="unitReady"..(useIndex>1 and ("@use"..useIndex) or ""),
                    ready=true}
                return
            end
            local category=unitAbilityTargetCategory(ability)
            local numericKey=unitHistoryKey(unit.guid,useIndex)
            if category=="move" and resourceCardsMoveRole(numericKey,false)~="combat" then
                category=nil
            end
            if category~=nil and not resourceCardsHideAutomaticEnemyTarget(
                numericKey,category,false) then
                targetSpecs[#targetSpecs+1]={index=index,category=category,
                    idCategory=category..(useIndex>1 and ("@use"..useIndex) or "")}
            end
            if combatCalcOn and (ability.enemyEffect~=nil
                or (category==nil and ability.targetableEnemy==true))
                and not resourceCardsHideAutomaticEnemyTarget(
                    unitAbilityTargetKey(unit.guid,index,ability,useIndex),
                    "effect",ability.enemyEffect~=nil and ability.targetableEnemy~=true) then
                targetSpecs[#targetSpecs+1]={index=index,category="effect",
                    idCategory="effect@"..(useIndex>1 and ("use"..useIndex.."#") or "")
                        .."effect"..index}
            end
        end
        if abilities.multi==true then
            for index in ipairs(abilities) do
                if decision.selected~=nil and decision.selected[index]==true then addTarget(index) end
            end
        elseif decision.index~=nil then
            addTarget(decision.index)
        end
    end
    local hasMoveAbility=false
    for _,index in ipairs(available) do
        if (tonumber(abilities[index]~=nil and abilities[index].move) or 0)>0 then
            hasMoveAbility=true
            break
        end
    end
    local hasChoices=#available>=2 or decision.ambiguous or hasMoveAbility
    if not hasChoices and #targetSpecs==0 then
        if choiceButtonShown[unit.guid]~="hidden" then
            removeChoiceButtons(unit)
            choiceButtonShown[unit.guid]="hidden"
        end
        choiceExpandedByGUID[unit.guid]=nil
        return
    end
    local selected=decision.index
    -- Paid choices explicitly marked expandable start as a single button.
    -- Opening that button must not activate an undecided mana-powered effect.
    local expanded=hasMoveAbility
        or (decision.ambiguous and decision.index==nil and not abilities.paidChoiceExpandable)
        or (choiceExpandedByGUID[unit.guid]==true and #available>1)
    local selectedKeys={}
    for i in pairs(decision.selected or {}) do selectedKeys[#selectedKeys+1]=tostring(i) end
    table.sort(selectedKeys)
    local targetLabels={}
    if not expanded then
        for _,spec in ipairs(targetSpecs) do targetLabels[#targetLabels+1]=spec.idCategory end
    end
    local combatMoveAvailable=combatCumbersomeActive==true and combatCalcOn==true
    local signature="Unit:"..tostring(selected)..":"..tostring(expanded)
        ..":"..table.concat(available,",")..":"..table.concat(selectedKeys,",")
        ..":use="..tostring(useIndex)
        ..":move="..resourceCardsMoveRole(unitHistoryKey(unit.guid,useIndex),false)
        ..":cumbersome="..tostring(combatMoveAvailable)
        ..":psychic="..tostring(combatPsychicActive)
        ..":targets="..table.concat(targetLabels,",")
    local xml=resourceObjectUiXmlTable(unit.UI)
    if choiceButtonShown[unit.guid]==signature then
        -- TTS object UI is applied asynchronously. After a Call Offer switch,
        -- the scan may have cached this signature before the buttons really
        -- appeared on the moving Unit. Recreate only missing controls.
        local needed={}
        if hasChoices then
            for _,index in ipairs(expanded and available or {selected or available[1]}) do
                needed["ResourceCardChoice_"..unit.guid.."_unit"..index]=true
                if combatMoveAvailable
                    and (tonumber(abilities[index]~=nil and abilities[index].move) or 0)>0 then
                    needed["ResourceCardChoice_"..unit.guid.."_unit"..index.."Combat"]=true
                end
            end
        end
        if #targetLabels>0 then
            for _,spec in ipairs(targetSpecs) do
                needed["AttackAssignmentSource_"..unit.guid.."_0_"..spec.idCategory]=true
            end
        end
        for _,node in ipairs(xml) do
            local id=node.attributes~=nil and node.attributes.id or nil
            if id~=nil then needed[id]=nil end
        end
        if next(needed)==nil then return end
    end

    for i=#xml,1,-1 do
        local attr=xml[i].attributes
        if attr~=nil and type(attr.id)=="string"
            and (attr.id:sub(1,19)=="ResourceCardChoice_"
                or attr.id:find("^AttackAssignmentSource_")~=nil) then table.remove(xml,i) end
    end
    local visibleAssets,seen={},{}
    local displayed=hasChoices and (expanded and available or {selected or available[1]}) or {}
    for _,index in ipairs(displayed) do
        local ability=abilities[index]
        local name=ability.icon or ability.key
        if not seen[name] then visibleAssets[#visibleAssets+1]=name seen[name]=true end
    end
    -- Unit Move has the same shield/Move choice as Action cards; Psychic
    -- Influence shares the shield/Influence treatment when relevant.
    for _,index in ipairs(displayed) do
        local ability=abilities[index]
        if (combatMoveAvailable and (tonumber(ability.move) or 0)>0)
            or (combatPsychicActive and ability.key=="influence"
                and (tonumber(ability.influence) or 0)>0) then
            if not seen.block then visibleAssets[#visibleAssets+1]="block" seen.block=true end
            if not seen.move and (tonumber(ability.move) or 0)>0 then
                visibleAssets[#visibleAssets+1]="move" seen.move=true
            end
            if not seen.influence and combatPsychicActive
                and ability.key=="influence" then
                visibleAssets[#visibleAssets+1]="influence" seen.influence=true
            end
        end
    end
    if #targetLabels>0 then visibleAssets[#visibleAssets+1]="target" end
    local assets,blocked=resourceCardsChoiceAssetsFor(unit.UI,visibleAssets)

    -- Shared printed rows keep a stable vertical slot; all sub-options start
    -- at the centre column and grow only to the right.
    local rows,rowByKey={},{}
    if expanded then
        for _,i in ipairs(displayed) do
            local ability=abilities[i]
            local key=ability.row or i
            if rowByKey[key]==nil then
                rowByKey[key]={}
                rows[#rows+1]=rowByKey[key]
            end
            rowByKey[key][#rowByKey[key]+1]=i
        end
    elseif hasChoices then
        rows={{displayed[1]}}
    end

    -- Fixed lower-left anchor works independently of translated text.
    -- The 180-degree UI rotation reverses the screen-space axes, so the
    -- first printed ability takes negative Y (above) and extra alternatives
    -- take negative X (to the screen-right of their primary option).
    -- Shift by one rendered Unit-button width (90 * 0.22) farther left.
    local baseX,baseY=91.8,80
    -- Button footprint is 90 * 0.22 = 19.8 UI units. Halve the
    -- *empty gap* (not the centre spacing) so neighbouring buttons
    -- remain separate and clickable: 34 -> 26.9, 35 -> 27.4.
    local rowSpacing=26.9
    local columnSpacing=27.4
    for rowIndex,indices in ipairs(rows) do
        local y=baseY+(rowIndex-(#rows+1)/2)*rowSpacing
        for columnIndex,index in ipairs(indices) do
            local ability=abilities[index]
            local active=decision.selected~=nil and decision.selected[index]==true
                or decision.selected==nil and index==selected
            local invalidCombat=active and combatBlocked
                and unitHistoryIsCombatAbility(ability)
            local icon=resourceCardsChoiceIcon(ability.icon or ability.key)
            if icon~=nil and blocked[icon.name] then icon=nil end
            local button={tag="Button",attributes={
                id="ResourceCardChoice_"..unit.guid.."_unit"..index,
                onClick="global/resourceUnitsChoiceClicked",
                position=tostring(baseX-(columnIndex-1)*columnSpacing).." "..tostring(y).." -35",
                rotation="0 0 180",width=90,height=90,scale="0.22 0.22",
                colors=invalidCombat and "#9C3737|#B34A4A|#9C3737|#9C3737"
                    or active and "#387D30|#4CA940|#387D30|#387D30"
                    or "#454D5D|#69798E|#444C63|#454D5D",
                fontSize=77,textColor="#FFFFFF",textAlignment="MiddleCenter"
            },value=icon==nil and (ability.buttonLabel
                or (ability.key=="other" and tostring(ability.row))
                or choiceLetters[ability.key] or "?") or ""}
            if icon~=nil then
                button.children={{tag="Image",attributes={
                    image=icon.name,width=82,height=82,preserveAspect="true",
                    raycastTarget="false",color="#FFFFFF"}}}
                if combatPsychicActive and ability.key=="influence"
                    and (tonumber(ability.influence) or 0)>0 then
                    local shield=resourceCardsChoiceIcon("block")
                    local influence=resourceCardsChoiceIcon("influence")
                    if shield~=nil and influence~=nil
                        and not blocked[shield.name] and not blocked[influence.name] then
                        button.children={{tag="Image",attributes={
                            image=shield.name,width=82,height=82,preserveAspect="true",
                            raycastTarget="false",color="#FFFFFF"}},
                            {tag="Image",attributes={image=influence.name,width=82,height=82,
                                preserveAspect="true",raycastTarget="false",color="#FFFFFF"}}}
                    end
                end
                if ability.iconOverlay~=nil then
                    button.children[#button.children+1]={tag="Text",attributes={
                        text=ability.iconOverlay,width=82,height=82,
                        alignment="MiddleCenter",fontSize=62,fontStyle="Bold",
                        color=ability.iconOverlayColor or "#FF564A",
                        outline="#1C1514",outlineSize="2 -2",
                        raycastTarget="false"}}
                end
            end
            if (tonumber(ability.move) or 0)>0 then
                local phase=resourceCardsMoveRole(unitHistoryKey(unit.guid,useIndex),true)
                -- The regular button becomes the Movement variant; the
                -- adjacent C variant is a normal, equally-sized option cell.
                local isMovement=phase~="combat"
                button.attributes.colors=isMovement
                    and "#387D30|#4CA940|#387D30|#387D30"
                    or "#454D5D|#69798E|#444C63|#454D5D"
                button.children=button.children or {}
                button.children[#button.children+1]={tag="Text",attributes={
                    text="M",width=34,height=34,alignment="LowerRight",
                    fontSize=37,fontStyle="Bold",color="#9AFFA4",
                    outline="#101820",outlineSize="2 -2",raycastTarget="false"}}
                if combatMoveAvailable then
                    local combatButton={tag="Button",attributes={
                    id="ResourceCardChoice_"..unit.guid.."_unit"..index.."Combat",
                    onClick="global/resourceUnitsChoiceClicked",
                    position=tostring(baseX-(#indices+columnIndex-1)*columnSpacing)
                        .." "..tostring(y).." -35",
                    rotation="0 0 180",width=90,height=90,scale="0.22 0.22",
                    colors=not isMovement
                        and "#387D30|#4CA940|#387D30|#387D30"
                        or "#454D5D|#69798E|#444C63|#454D5D",
                    fontSize=77,textColor="#FFFFFF",textAlignment="MiddleCenter"},
                    value=icon==nil and "C" or ""}
                local shield=resourceCardsChoiceIcon("block")
                local movement=resourceCardsChoiceIcon("move")
                if shield~=nil and not blocked[shield.name] then
                    combatButton.value=""
                    combatButton.children={{tag="Image",attributes={
                        image=shield.name,width=82,height=82,preserveAspect="true",
                        raycastTarget="false",color="#FFFFFF"}}}
                    if movement~=nil and not blocked[movement.name] then
                        combatButton.children[#combatButton.children+1]={tag="Image",attributes={
                            image=movement.name,width=82,height=82,
                            preserveAspect="true",raycastTarget="false",color="#FFFFFF"}}
                    else
                        combatButton.children[#combatButton.children+1]={tag="Text",attributes={
                            text="M",width=34,height=34,alignment="LowerRight",
                            fontSize=37,fontStyle="Bold",color="#69AEFF",
                            raycastTarget="false"}}
                    end
                elseif icon~=nil then
                    -- Missing shield artwork: retain the old legible fallback.
                    combatButton.children={{tag="Image",attributes={
                        image=icon.name,width=82,height=82,preserveAspect="true",
                        raycastTarget="false",color="#FFFFFF"}},
                        {tag="Text",attributes={text="C",width=34,height=34,
                            alignment="LowerRight",fontSize=37,fontStyle="Bold",
                            color="#69AEFF",outline="#101820",
                            outlineSize="2 -2",raycastTarget="false"}}}
                end
                    xml[#xml+1]=button
                    xml[#xml+1]=combatButton
                else
                    xml[#xml+1]=button
                end
            else
                xml[#xml+1]=button
            end
        end
    end
    if #targetLabels>0 then
        local count=#targetSpecs
        for i,spec in ipairs(targetSpecs) do
            local targetAsset=resourceCardsChoiceIcon("target")
            local x=hasChoices and baseX-columnSpacing or baseX
            local y=baseY+(i-(count+1)/2)*rowSpacing
            local children={}
            if targetAsset~=nil and not blocked[targetAsset.name] then
                children={{tag="Image",attributes={image=targetAsset.name,
                    width=82,height=82,preserveAspect="true",raycastTarget="false",color="#FFFFFF"}}}
            end
            -- R (Ranged) and E (enemy effect) label independent targets
            -- without relying on unsupported object-attached tooltips.
            if count==2 and targetSpecs[1].index==targetSpecs[2].index then
                children[#children+1]={tag="Text",attributes={
                    text=spec.category=="effect" and "E" or "R",
                    width=38,height=38,fontSize=35,alignment="LowerRight",
                    color="#FFFFFF",outline="#141820",outlineSize="2 -2",
                    raycastTarget="false"}}
            end
            xml[#xml+1]={tag="Button",attributes={
                id="AttackAssignmentSource_"..unit.guid.."_0_"..spec.idCategory,
                onClick=spec.ready and "global/attackAssignmentReadySourceClicked"
                    or "global/attackAssignmentSourceClicked",
                position=tostring(x).." "..tostring(y).." -35",
                rotation="0 0 180",width=90,height=90,scale="0.22 0.22",
                colors="#454D5D|#69798E|#444C63|#454D5D",textColor="#FFFFFF",
                textAlignment="MiddleCenter"
            },value="",children=children}
        end
    end
    resourceObjectUiSetTable(unit.UI,xml,assets)
    choiceButtonShown[unit.guid]=signature
end


local function clearChoiceButtons()
    for guid,signature in pairs(choiceButtonShown) do
        if signature~="hidden" then removeChoiceButtons(getObjectFromGUID(guid)) end
    end
    choiceButtonShown={}
    combatConfig.cardButtonIds={}
end

-- Read a scripting zone's transform, not its (potentially zero-sized)
-- collider bounds. Sharing this X/Z test keeps Card, Skill, Reward and enemy
-- recovery consistent, including rotated play and unit zones.
trackerPrivate.zoneFootprintContainsXZ=function(obj,zone)
    if obj==nil or zone==nil then return false end
    local center,size=zone.getPosition(),zone.getScale()
    if center==nil or size==nil then return false end
    local pos=obj.getPosition()
    local x,z=pos.x or pos[1],pos.z or pos[3]
    local cx,cz=center.x or center[1],center.z or center[3]
    local width,depth=size.x or size[1],size.z or size[3]
    if x==nil or z==nil or cx==nil or cz==nil
        or width==nil or depth==nil or width<=0 or depth<=0 then return false end
    local rotation=zone.getRotation~=nil and zone.getRotation() or nil
    local yaw=math.rad(rotation~=nil and (rotation.y or rotation[2]) or 0)
    local cosYaw,sinYaw=math.cos(yaw),math.sin(yaw)
    local dx,dz=x-cx,z-cz
    local localX=dx*cosYaw-dz*sinYaw
    local localZ=dx*sinYaw+dz*cosYaw
    return math.abs(localX)<width*0.5 and math.abs(localZ)<depth*0.5
end

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
    if guid==nil or seatPos==nil then return end
    -- Avoid physics waits for mana, enemies and unrelated play-area objects.
    if selectedResourceByGUID[guid]==nil and (gStates==nil
        or ((gStates.artifactBreaks==nil or gStates.artifactBreaks[guid]==nil)
            and (gStates.artifactGrailHealingUsed==nil
                or gStates.artifactGrailHealingUsed[guid]==nil)
            and (gStates.resourceCardPlayOrder==nil
                or gStates.resourceCardPlayOrder[guid]==nil)
            and (gStates.resourceCardMoveRoles==nil
                or gStates.resourceCardMoveRoles[guid]==nil))) then return end
    trackerPrivate.choiceResetGenerationByGUID[guid]=(trackerPrivate.choiceResetGenerationByGUID[guid] or 0)+1
    local serial=trackerPrivate.choiceResetGenerationByGUID[guid]
    -- On release, check X/Z instead of waiting for the shallow zone's Y
    -- membership to catch up with a card that is still falling.
    safeWaitFrames("PlayerBoard.CardRecognition",function()
        if trackerPrivate.choiceResetGenerationByGUID[guid]~=serial then return end
        safeWaitCondition("PlayerBoard.CardRecognition",function()
            if trackerPrivate.choiceResetGenerationByGUID[guid]~=serial then return end
            if not cardInSeatPlayArea(guid,seatPos) then
                -- A genuine departure retires this play's time-order slot;
                -- moving a card in/out again starts a fresh play sequence.
                if gStates~=nil and gStates.resourceCardPlayOrder~=nil then
                    gStates.resourceCardPlayOrder[guid]=nil
                end
                selectedResourceByGUID[guid]=nil
                if gStates~=nil and gStates.resourceCardMoveRoles~=nil then
                    gStates.resourceCardMoveRoles[guid]=nil
                end
                choiceExpandedByGUID[guid]=nil
                resourceCardsArtifactBreakClear(guid)
                if gStates~=nil and gStates.artifactGrailHealingUsed~=nil then
                    gStates.artifactGrailHealingUsed[guid]=nil
                end
                if gStates~=nil and gStates.unitReadyCardChoices~=nil then
                    gStates.unitReadyCardChoices[guid]=nil
                end
                unitHistoryValidSources(seatPos)
            end
        end,function()
            if trackerPrivate.choiceResetGenerationByGUID[guid]~=serial then return true end
            local obj=getObjectFromGUID(guid)
            return obj==nil or (trackerPrivate.playCardMovements[guid]==nil
                and trackerPrivate.readyForXZ(obj))
        end,8)
    end,1)
end

local function footprint(obj)
    local position=obj.getPosition()
    local bounds=obj.getBounds()
    local size=bounds~=nil and bounds.size or nil
    local x=size~=nil and size[1] or 2
    local z=size~=nil and size[3] or 3
    return {x=position[1],z=position[3],halfX=math.max(0.4,x*0.5),halfZ=math.max(0.5,z*0.5)}
end

local function overlaps(a,b)
    -- Strict overlap, not merely touching edges. Each card can link several others.
    return math.abs(a.x-b.x)<(a.halfX+b.halfX)*0.92
       and math.abs(a.z-b.z)<(a.halfZ+b.halfZ)*0.92
end

local function manaColor(obj)
    if isManaTokenFigurine(obj) then return manaTokenColor(obj) end
    if obj.type=="Dice" then
        -- Treat released dice like crystals: a slight physical wobble can
        -- leave resting=false indefinitely, even when the visible face is stable.
        -- Still exclude scripted smooth movement while reading the face.
        if obj.isSmoothMoving() then return nil end
        local face=obj.getRotationValue()
        if type(face)=="string" then return face:match("^([%a]+) Mana$") end
    end
    return nil
end

-- Placement and resource links use X/Z, so vertical falling or a slightly
-- rocking die does not delay an otherwise released object.
trackerPrivate.readyForXZ=function(obj)
    return obj~=nil and (obj.held_by_color==nil or obj.held_by_color=="")
        and not obj.isSmoothMoving()
end

-- Magic Talent's strong side consumes TWO distinct mana objects, not the
-- single mana that normally powers an Advanced Action. Read the same released
-- die faces/crystals as the ordinary tracker, even when its panel is minimized.
function magicTalentManaPayments(seatPos)
    local card=getObjectFromGUID("3d832c")
    local zone=seatPos~=nil and getObjectFromGUID(playerPlayAreas[seatPos]) or nil
    if card==nil or zone==nil then return {} end
    local area=footprint(card)
    local payments,seen={},{}
    local function consider(obj)
        if obj==nil or seen[obj.guid] or obj.guid==card.guid
            or not trackerPrivate.readyForXZ(obj) then return end
        seen[obj.guid]=true
        local p=obj.getPosition()
        if math.abs(p[1]-area.x)<area.halfX
            and math.abs(p[3]-area.z)<area.halfZ then
            local color=manaColor(obj)
            if color~=nil then
                payments[#payments+1]={guid=obj.guid,color=color}
            end
        end
    end
    for _,obj in ipairs(zone.getObjects()) do consider(obj) end
    if #payments<2 then
        -- The play zone is deliberately thin; a crystal stacked on a card can
        -- be above its Y boundary. Only inspect objects physically covering
        -- Magic Talent, and never read die faces while still moving.
        for _,obj in ipairs(getAllObjects()) do consider(obj) end
    end
    table.sort(payments,function(a,b) return a.guid<b.guid end)
    return payments
end

-- Reuse the same stable identifiers as Skills and Combat's faction reward cleanup.
-- No name/description guessing for Skills, Units or Faction Rewards.
trackerPrivate.factionRewardNotes={
    ["Dark Crusader Reward"]="Dark",
    ["Elementalist Reward"]="Elem",
    ["Apocalypse Cult Reward"]="Apoc",
    ["Council of the Void Reward"]="Coun"
}

-- Original container GUIDs collide across factions in the pushed JSON.
-- Front-art image hashes are independent of translated names and survive
-- regenerated GUIDs when a token is extracted from a bag.
factionRewardForObject=function(obj)
    if obj==nil or trackerPrivate.factionRewardNotes[obj.getGMNotes()]==nil then return nil end
    local custom=obj.getCustomObject()
    local image=custom~=nil and custom.image or nil
    local hash=type(image)=="string" and image:match("([0-9A-Fa-f]+)/?$") or nil
    local definition=hash~=nil and factionRewardResourceByImage[hash:upper()] or nil
    if definition~=nil and definition.notes==obj.getGMNotes() then return definition end
    return factionRewardResourceByGUID[obj.getGMNotes()..":"..obj.guid]
end

local function resourceObjectKind(obj)
    if obj==nil then return nil end
    if skillTokens[obj.guid]~=nil then return "skill" end
    if obj.getGMNotes()=="Puppet Master" then return "puppet" end
    if obj.type=="Card" then
        local data=gameCards[obj.guid]
        if data~=nil then
            if data.cardType=="Regular Unit" or data.cardType=="Elite Unit" then return "unit" end
            return "card"
        end
        -- Wounds/Quests are not unknown resource cards.
        local notes=obj.getGMNotes()
        if notes=="Wound" then return "wound" end
        if notes=="Quest" then return nil end
        return "card"
    end
    if manaColor(obj)~=nil then return "mana" end
    if trackerPrivate.factionRewardNotes[obj.getGMNotes()]~=nil then return "factionReward" end
    return nil
end

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
    local card=guid~=nil and getObjectFromGUID(guid) or nil
    local data=card~=nil and gameCards[guid] or nil
    local zone=seatPos~=nil and getObjectFromGUID(playerPlayAreas[seatPos]) or nil
    if card==nil or data==nil or data.cardType~="Spell"
        or zone==nil or card.is_face_down==true
        or cardPosture(card)~="upright" then return false end
    local area=footprint(card)
    local seen={}
    local function paidBy(mana)
        if mana==nil or seen[mana.guid] or mana.guid==guid
            or not trackerPrivate.readyForXZ(mana) then return false end
        seen[mana.guid]=true
        local p=mana.getPosition()
        if math.abs(p[1]-area.x)>=area.halfX
            or math.abs(p[3]-area.z)>=area.halfZ then return false end
        local color=manaColor(mana)
        return color~=nil and color~="Black" and matchesCardMana(card,color)
    end
    for _,mana in ipairs(zone.getObjects()) do
        if paidBy(mana) then return true end
    end
    -- Stacked crystals can rest above the thin play scripting zone.
    for _,mana in ipairs(getAllObjects()) do
        if paidBy(mana) then return true end
    end
    return false
end

-- Count distinct physical casting payments for repeated uses of the same
-- Spell through Maximal Effect + Magic Talent. Both shallow-zone and raised
-- mana objects are inspected; duplicates are counted only once.
function magicTalentSpellCastingPaymentCount(seatPos,guid)
    local card=guid~=nil and getObjectFromGUID(guid) or nil
    local data=card~=nil and gameCards[guid] or nil
    local zone=seatPos~=nil and getObjectFromGUID(playerPlayAreas[seatPos]) or nil
    if card==nil or data==nil or data.cardType~="Spell" or zone==nil
        or card.is_face_down==true or cardPosture(card)~="upright" then return 0 end
    local area=footprint(card)
    local seen,count={},0
    local function consider(mana)
        if mana==nil or seen[mana.guid] or mana.guid==guid
            or not trackerPrivate.readyForXZ(mana) then return end
        seen[mana.guid]=true
        local p=mana.getPosition()
        local x,z=p.x or p[1],p.z or p[3]
        if math.abs(x-area.x)>=area.halfX
            or math.abs(z-area.z)>=area.halfZ then return end
        local color=manaColor(mana)
        if color~=nil and color~="Black" and matchesCardMana(card,color) then
            count=count+1
        end
    end
    for _,mana in ipairs(zone.getObjects()) do consider(mana) end
    for _,mana in ipairs(getAllObjects()) do consider(mana) end
    return count
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

-- Resolve independent mana roles without relying on placement order or GUID
-- order. A casting payment (if declared), stronger-effect payment, and
-- effect-selection payment must be different physical mana objects. Daytime
-- Gold can fill either a casting or effect role; its effect stays ambiguous.
-- Other cards can reuse this by declaring effectManaChoice.castColor.
local function effectManaPossibilities(spec,payments,needPower,goldAllowed,blackAllowed)
    -- Single-boolean call sites/tests retain the ordinary Day/Night pairing.
    -- The Amulets may independently enable both colors at runtime.
    if blackAllowed==nil then blackAllowed=not goldAllowed end
    local possible,anyColor={},false
    -- Black mana cannot pay for any role during a Day round, including
    -- the otherwise separate strong-side payment on Mana Bolt/Thunderbolt.
    if not blackAllowed and needPower and spec.powerColor=="Black" then return possible,anyColor end
    local function hasDistinctPower(effectGUID,castGUID)
        if not needPower then return true end
        for _,payment in ipairs(payments) do
            if payment.guid~=effectGUID and payment.guid~=castGUID
                and (payment.color==spec.powerColor
                    or (goldAllowed and spec.powerColor~="Black"
                        and payment.color=="Gold")) then return true end
        end
        return false
    end
    for _,effect in ipairs(payments) do
        local category=spec.colors[effect.color]
        local wildcard=effect.color=="Gold" and goldAllowed
        if category~=nil or wildcard then
            local valid=false
            if spec.castColor==nil then
                valid=hasDistinctPower(effect.guid,nil)
            else
                for _,casting in ipairs(payments) do
                    if casting.guid~=effect.guid
                        and (casting.color==spec.castColor
                            or (casting.color=="Gold" and goldAllowed))
                        and hasDistinctPower(effect.guid,casting.guid) then
                        valid=true
                        break
                    end
                end
            end
            if valid then
                if wildcard then anyColor=true
                elseif category~=nil then possible[category]=true end
            end
        end
    end
    return possible,anyColor
end

-- Only the separate stronger-effect payment qualifies for Mana Overload.
-- A card's casting mana or a Pure Magic / Mana Bolt option payment does not.
local function effectManaPowerColors(spec,payments,goldAllowed,blackAllowed,selectedCategory)
    if selectedCategory==nil and type(blackAllowed)=="string" then
        selectedCategory=blackAllowed
        blackAllowed=not goldAllowed
    end
    local eligible={}
    if spec==nil or selectedCategory==nil
        or (not blackAllowed and spec.powerColor=="Black") then return eligible end
    for _,effect in ipairs(payments or {}) do
        if spec.colors[effect.color]==selectedCategory
            or (goldAllowed and effect.color=="Gold") then
            for _,power in ipairs(payments or {}) do
                if power.guid~=effect.guid
                    and (power.color==spec.powerColor
                        or (goldAllowed and spec.powerColor~="Black"
                            and power.color=="Gold")) then
                    if spec.castColor==nil then
                        eligible[spec.powerColor]=true
                    else
                        for _,casting in ipairs(payments or {}) do
                            if casting.guid~=effect.guid and casting.guid~=power.guid
                                and (casting.color==spec.castColor
                                    or (goldAllowed and casting.color=="Gold")) then
                                eligible[spec.powerColor]=true
                                break
                            end
                        end
                    end
                end
            end
        end
    end
    return eligible
end

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

-- One sideways calculator for ordinary Actions and Skill-linked exceptions.
-- A linked Skill changes the value, not the player's chosen resource.
local function calculateSideways(card,known,skillLink)
    local choice=chosenEffect(card.guid,false,trackerPrivate.sidewaysChoices,true)
    local resources=nil
    if choice~=nil then
        resources={}
        for category,value in pairs(choice) do
            resources[category]=value*(skillLink~=nil and skillLink.sidewaysValue or 1)
        end
    end
    local linked=skillLink~=nil
    local linkedObjects={}
    if linked then
        linkedObjects[1]=skillLink.skillGUID
        if skillLink.manaGUID~=nil then linkedObjects[2]=skillLink.manaGUID end
    end
    return {guid=card.guid,known=known,complete=choice~=nil,powered=linked,
        links=linkedObjects,
        linkedSkill=linked and skillLink.skillGUID or nil,
        status=linked and "purple" or (choice~=nil and "green" or "yellow"),
        resources=resources}
end

local function calculateCard(card,manaPowered,linkedBoost,linked,discardTarget,hasDiscard,skillLink,linkedChoices,repeatLink,discardBonus,woundCount,enemyIconBonus,spellCastPaid)
    local data=gameCards[card.guid]
    local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
    local known=data~=nil
    -- A half Banner is an attached Unit accessory, NOT a played Artifact.
    -- In particular Banner of Command must not award its Break Fame +2 or
    -- its full-card Influence 4 when the Command source is flipped/spent.
    local attachedResult=trackerPrivate.bannerAttachedCardResult(card.guid)
    if attachedResult~=nil then return attachedResult end
    local tracked=data==nil or data.resourceTracked~=false
    local powered=manaPowered or linkedBoost~=nil
    if repeatLink~=nil then powered=repeatLink.powered end
    local posture=cardPosture(card)
    -- A non-resource Action is neutral upright, but still gives the standard
    -- selectable +1 when played sideways like any other non-Wound Action.
    if data~=nil and data.resourceAlwaysNeutral==true and posture~="sideways" then
        return {guid=card.guid,known=true,complete=true,powered=powered,
            links=linked,status=#linked>0 and "purple" or "blue",resources=nil,
            repeatCount=repeatLink~=nil and repeatLink.count or nil,
            repeatLink=repeatLink}
    end
    -- Artifacts use the saved Break decision; face-down Actions stay
    -- inert unless they are the Action selected by Maximal Effect.
    local artifactPlayed=known and data.cardType=="Artifact" and rule~=nil
        and rule.artifactMode==true
    local faceUp=(card.is_face_down~=true or repeatLink~=nil or artifactPlayed)
        and posture=="upright"
    -- Any non-Wound card played at 90 degrees has one generic resource,
    -- irrespective of its printed card effect. It requires an explicit choice.
    if posture=="sideways" and cardCanPlaySideways(card) then
        return calculateSideways(card,known,skillLink)
    end
    local sideTracked=tracked and not (not powered and rule~=nil and rule.normalTrackerNeutral==true)
    local choices=linkedChoices or sideChoices(rule,powered)
    local chosen=chosenEffect(card.guid,powered,choices)
    local usesTerrainBlock=chosen~=nil and chosen.terrainBlock==true
    if usesTerrainBlock then
        local value=currentLandBlockValue()
        if value~=nil then
            chosen=resourceCardsUsesDayMana() and {blockFire=value} or {blockIce=value}
        else
            -- Terrain not yet determinable. Preserve the B selection, but
            -- do not invent a Block amount; show yellow until the next scan.
            chosen=nil
        end
    end
    local choicePending=choices~=nil and #choices>1 and chosen==nil
    local statePartial=rule~=nil and ((powered and rule.poweredPartial==true)
        or (not powered and rule.normalPartial==true)) and chosen==nil
    local base=chosen or (rule~=nil and (powered and rule.powered or rule.normal) or nil)
    if base~=nil and rule~=nil and rule.blockedEnemyAttackBonus~=nil then
        local active=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
        local count=active~=nil and (combatConfig.blockedEnemyCounts[active.seatPos] or 0) or 0
        local perEnemy=powered and rule.blockedEnemyAttackBonus.powered
            or rule.blockedEnemyAttackBonus.normal
        local adjusted={}
        for key,value in pairs(base) do adjusted[key]=value end
        adjusted.attack=(adjusted.attack or 0)+count*(perEnemy or 0)
        base=adjusted
    end
    if base~=nil and rule~=nil and rule.woundBonus~=nil and woundCount~=nil then
        local perWound=powered and rule.woundBonus.powered or rule.woundBonus.normal
        base={influence=(base.influence or 0)+woundCount*perWound}
    end
    if powered and base~=nil and rule~=nil and rule.enemyIconBlock
        and enemyIconBonus~=nil then
        base={blockIce=(base.blockIce or 0)+enemyIconBonus}
    end
    -- A discard is an actual cost of Improvisation, even when its strong side
    -- came free from Concentration/Will Focus.
    -- Spells on the table may be discarded or merely displayed. Their printed
    -- effect is played only after a linked mana matches the Spell's own colour
    -- (or Daytime Gold). Black alone can indicate a strong side, not a cast.
    local costPaid=(data==nil or data.cardType~="Spell" or spellCastPaid==true)
        and (rule==nil or rule.requiredLink==nil or hasDiscard==true
            or (powered and rule.strongNoDiscard==true))
        and (rule==nil or not rule.artifactMode or rule.discardBoost==nil
            or powered or discardBonus~=nil)
    local canApply=not discardTarget or repeatLink~=nil
    local effects=sideTracked and faceUp and costPaid and canApply
        and applyLinkedResourceBonus(base,linkedBoost) or nil
    local invalidComposite=repeatLink~=nil and not combatConfig.compositePhasesMatch(
        card.guid,powered,choices,repeatLink)
    if invalidComposite then
        canApply=false
        effects=nil
    end
    if effects~=nil and repeatLink~=nil then
        -- Repeated choices are independent. A copied Ritual Attack can use
        -- differently coloured discarded cards on its separate applications.
        -- Numeric resources join the SAME composite effect / enemy target.
        local repeated={}
        if repeatLink.options~=nil or (choices~=nil and #choices>1) then
            for index=1,repeatLink.count do
                local options=repeatLink.options~=nil and repeatLink.options[index] or choices
                local single=combatConfig.repeatChoiceFor(card.guid,powered,options,index)
                if single~=nil then
                    for category,value in pairs(single) do
                        if trackerPrivate.totalsKeys[category] and type(value)=="number" then
                            repeated[category]=(repeated[category] or 0)+value
                        end
                    end
                end
            end
        else
            for category,value in pairs(effects) do
                repeated[category]=(trackerPrivate.totalsKeys[category] and type(value)=="number")
                    and value*repeatLink.count or value
            end
        end
        effects=repeated
    end
    -- Each Maximal Effect application chooses its own Stout Resolve resource
    -- and pays its own discarded cards. A single pooled bonus applied to every
    -- resource family would create points when uses select different resources.
    if effects~=nil and discardBonus~=nil then
        local adjusted={}
        for category,value in pairs(effects) do adjusted[category]=value end
        if type(discardBonus)=="table" and repeatLink~=nil then
            for index=1,repeatLink.count do
                local amount=discardBonus[index] or 0
                if amount>0 then
                    local options=repeatLink.options~=nil and repeatLink.options[index] or choices
                    local selected=combatConfig.repeatChoiceFor(card.guid,powered,options,index)
                    if selected~=nil then
                        for category,value in pairs(selected) do
                            if trackerPrivate.totalsKeys[category] and type(value)=="number" then
                                adjusted[category]=(adjusted[category] or 0)+amount
                                break
                            end
                        end
                    end
                end
            end
        elseif type(discardBonus)=="number" and discardBonus>0 then
            for category,value in pairs(effects) do
                if trackerPrivate.totalsKeys[category] and type(value)=="number" then
                    adjusted[category]=value+discardBonus
                end
            end
        end
        effects=adjusted
    end
    -- A card's other unimplemented options do not make its currently selected
    -- *known* resource effect uncertain. Keep the first option as the fast,
    -- green default; only a genuinely unresolved selected effect stays yellow.
    local knownSelectedOption=chosen~=nil and effectHasTrackedResource(chosen)
    local complete=sideTracked and base~=nil and not choicePending and not statePartial
        and not invalidComposite
        and (rule==nil or rule.partial~=true or knownSelectedOption)
        and (rule==nil or rule.woundBonus==nil or woundCount~=nil)
        and (rule==nil or rule.enemyIconBlock~=true or not powered
            or enemyIconBonus~=nil)
        and faceUp and costPaid and canApply
    local choiceIsUntracked=chosen~=nil and not effectHasTrackedResource(chosen)
    -- Recognised movement rules change the calculator even without supplying
    -- numeric Move. Show green when the paid, selected side has such an effect.
    -- For example, Space Bending is green, but Time Bending stays neutral
    -- until its distinct stronger-side effect is supported.
    local scriptedMovement=rule~=nil and rule.movementEffects~=nil
        and (powered and rule.movementEffects.powered
            or (not powered and rule.movementEffects.normal))
    local scriptedTerrain=false
    for _,effect in ipairs(cardTerrainEffects(rule,powered) or {}) do
        if terrainEffectActive(effect) then scriptedTerrain=true break end
    end
    local status=(not known or not sideTracked or posture=="discard"
        or (choiceIsUntracked and costPaid and not scriptedMovement and not scriptedTerrain)) and "blue"
        or not complete and "yellow" or "green"
    -- The printed crystal gain on Savage Harvesting is deliberately manual.
    -- Move is still counted, but a green "fully understood" highlight would lie.
    -- Golden Grail's basic Fame is complete once both Heal points are confirmed;
    -- its stronger-side card draws still require manual resolution.
    if rule~=nil and rule.manualSecondary~=nil and status=="green"
        and not (rule.grailFamePerHealing~=nil and not powered
            and gStates~=nil and gStates.artifactGrailHealingUsed~=nil
            and (tonumber(gStates.artifactGrailHealingUsed[card.guid]) or 0)>=2) then
        status="yellow"
    end
    -- Linking information is more valuable than the underlying certainty colour.
    if #linked>0 then status="purple" end
    local fameRepSide=rule~=nil and rule.fameRep~=nil and faceUp and costPaid and canApply
        and (powered and rule.fameRep.powered or not powered and rule.fameRep.normal) or nil
    if fameRepSide~=nil and repeatLink~=nil then
        local multiplied={}
        for key,value in pairs(fameRepSide) do
            multiplied[key]=type(value)=="number" and value*repeatLink.count or value
        end
        fameRepSide=multiplied
    end
    -- Fame/Reputation earned only when the calculator shows this source's group defeated.
    local defeatSide=rule~=nil and rule.defeatFameRep~=nil and faceUp and costPaid and canApply
        and (powered and rule.defeatFameRep.powered or not powered and rule.defeatFameRep.normal) or nil
    if defeatSide~=nil then
        local repeats=repeatLink~=nil and repeatLink.count or 1
        if defeatSide.choice~=nil then
            if repeatLink~=nil then
                repeats=0
                for index=1,repeatLink.count do
                    local options=repeatLink.options~=nil and repeatLink.options[index] or choices
                    local selected=combatConfig.repeatChoiceFor(card.guid,powered,options,index)
                    if selected~=nil and choiceCategory(selected)==defeatSide.choice then
                        repeats=repeats+1
                    end
                end
            elseif chosen==nil or choiceCategory(chosen)~=defeatSide.choice then
                repeats=0
            end
        end
        if repeats==0 then defeatSide=nil
        elseif repeats>1 then
            local scaled={}
            for key,value in pairs(defeatSide) do
                scaled[key]=type(value)=="number" and value*repeats or value
            end
            defeatSide=scaled
        end
    end
    -- Preserve the physical source type for phase rules (Knockout and
    -- Paralysis invalidate only non-Wound hand-card Attacks, not Units/Skills).
    return {guid=card.guid,kind="card",known=known,complete=complete,powered=powered,fameRep=fameRepSide,
        conditionalFireAttack=complete and not powered and chosen~=nil
            and chosen.conditionalFireAttack or nil,
        flameWave=complete and powered and rule~=nil and rule.poweredEnemyBonus~=nil,
        explosiveBolt=complete and powered and rule~=nil and rule.defeatArmourReduce or nil,
        dodgeConditional=complete and rule~=nil and rule.conditionalAttackNoWounds==true,
        combatConversion=complete and rule~=nil and rule.combatConversion or nil,
        defeatFameRep=defeatSide,splitTargets=chosen~=nil and chosen.splitTargets or nil,
        repeatBlocks=chosen~=nil and chosen.repeatBlocks or nil,
        swiftDouble=complete and rule~=nil and rule.swiftDouble==true,
        excessBlockArmour=complete and powered and rule~=nil
            and rule.excessBlockArmour==true,
        links=linked,status=status,resources=effects,
        usesTerrainBlock=usesTerrainBlock and faceUp and costPaid and canApply,
        repeatCount=repeatLink~=nil and repeatLink.count or nil,
        repeatLink=repeatLink,incompatibleComposite=invalidComposite}
end

local function overlapArea(a,b)
    if not overlaps(a,b) then return 0 end
    local width=math.max(0,math.min(a.x+a.halfX,b.x+b.halfX)-math.max(a.x-a.halfX,b.x-b.halfX))
    local depth=math.max(0,math.min(a.z+a.halfZ,b.z+b.halfZ)-math.max(a.z-a.halfZ,b.z-b.halfZ))
    return width*depth
end

-- The common pairing engine is used for different reasons:
-- "stronger" plays one Action card's stronger effect; "discard" consumes one
-- OTHER unused, non-Wound card as a cost. Neither is inferred from overlap alone.
local function resolveActionLinks(cards,wounds,footprints,manaPowered,skillLinksByTarget)
    local links,boostBy,boostSource,discarded,hasDiscard={}, {}, {}, {}, {}
    local linkedCardBySource,repeatByTarget,discardBoostBySource={}, {}, {}
    local boostClaimed={}
    for _,card in ipairs(cards) do links[card.guid]={} end
    for _,wound in ipairs(wounds) do links[wound.guid]={} end
    local function connect(source,target)
        links[source.guid][#links[source.guid]+1]=target.guid
        links[target.guid][#links[target.guid]+1]=source.guid
    end
    local function nearestOverlap(source,valid,preference)
        local best,bestArea,bestPriority=nil,0,-1
        local a=footprints[source.guid]
        for _,target in ipairs(cards) do
            if target.guid~=source.guid and valid(target) then
                local area=overlapArea(a,footprints[target.guid])
                local priority=((preference=="discard" and cardPosture(target)=="discard")
                    or (preference=="faceDown" and target.is_face_down==true)) and 1 or 0
                if area>0 and (priority>bestPriority
                    or (priority==bestPriority and (area>bestArea
                        or (area==bestArea and best~=nil and target.guid<best.guid)))) then
                    best,bestArea,bestPriority=target,area,priority
                end
            end
        end
        return best
    end
    for _,source in ipairs(cards) do
        local data=gameCards[source.guid]
        local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
        local link=rule~=nil and manaPowered[source.guid] and rule.poweredLink or nil
        if link~=nil and link.mode=="stronger" and source.is_face_down~=true
            and cardPosture(source)=="upright" then
            local target=nearestOverlap(source,function(candidate)
                local other=gameCards[candidate.guid]
                local otherRule=other~=nil and cardResourceDefinitions[other.resourceKey] or nil
                return not boostClaimed[candidate.guid] and other~=nil
                    and (other.cardType=="Starting" or other.cardType=="Advanced Action")
                    and (otherRule==nil or otherRule.poweredLink==nil)
                    and candidate.is_face_down~=true and cardPosture(candidate)=="upright"
            end)
            if target~=nil then
                boostClaimed[target.guid]=true
                boostBy[target.guid]=link
                boostSource[target.guid]=source.guid
                connect(source,target)
            end
        end
    end
    -- Maximal Effect owns its follow-on Action before any of that Action's
    -- additional costs are resolved. Those costs must be paid separately for
    -- *each* repeated use, not reused from the card Maximal Effect throws away.
    for _,source in ipairs(cards) do
        local data=gameCards[source.guid]
        local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
        local requirement=rule~=nil and rule.requiredLink or nil
        if requirement~=nil and requirement.mode=="repeat"
            and discarded[source.guid]==nil and source.is_face_down~=true
            and cardPosture(source)=="upright" then
            local target=nearestOverlap(source,function(candidate)
                local other=gameCards[candidate.guid]
                return other~=nil
                    and (other.cardType=="Starting" or other.cardType=="Advanced Action")
                    and discarded[candidate.guid]==nil and not boostClaimed[candidate.guid]
                    and not manaPowered[candidate.guid] and #links[candidate.guid]==0
                    and cardPosture(candidate)=="upright"
            end,"faceDown")
            if target~=nil then
                discarded[target.guid]=source.guid
                hasDiscard[source.guid]=true
                linkedCardBySource[source.guid]=target.guid
                local strong=manaPowered[source.guid]==true or boostBy[source.guid]~=nil
                repeatByTarget[target.guid]={powered=strong,sourceGUID=source.guid,
                    count=strong and requirement.poweredCount or requirement.normalCount}
                connect(source,target)
            end
        end
    end
    -- Ritual Attack is another throwaway effect. Under Maximal Effect it needs
    -- one NEW throwaway Action for each application, with independently chosen
    -- colors (a two-color target can offer two choices for that application).
    for _,source in ipairs(cards) do
        local data=gameCards[source.guid]
        local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
        local requirement=rule~=nil and rule.requiredLink or nil
        local repeated=repeatByTarget[source.guid]
        if requirement~=nil and requirement.mode=="throwAway"
            and (discarded[source.guid]==nil or repeated~=nil)
            and (source.is_face_down~=true or repeated~=nil)
            and cardPosture(source)=="upright" then
            local need=repeated~=nil and repeated.count or 1
            local paid=0
            if repeated~=nil then repeated.options={} end
            for index=1,need do
                local target=nearestOverlap(source,function(candidate)
                    local other=gameCards[candidate.guid]
                    return other~=nil
                        and (other.cardType=="Starting" or other.cardType=="Advanced Action")
                        and discarded[candidate.guid]==nil and not boostClaimed[candidate.guid]
                        and not manaPowered[candidate.guid] and #links[candidate.guid]==0
                        and cardPosture(candidate)=="upright"
                end,"faceDown")
                if target==nil then break end
                discarded[target.guid]=source.guid
                if paid==0 then linkedCardBySource[source.guid]=target.guid end
                paid=paid+1
                if repeated~=nil then
                    repeated.options[index]=linkedColorChoices(rule,target.guid,repeated.powered)
                end
                connect(source,target)
            end
            hasDiscard[source.guid]=paid==need
        end
    end
    -- Improvisation (and other discard-cost cards) must pay once per repeated
    -- use, even when Maximal Effect supplies their advanced side for free.
    for _,source in ipairs(cards) do
        local data=gameCards[source.guid]
        local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
        local repeated=repeatByTarget[source.guid]
        if (discarded[source.guid]==nil or repeated~=nil)
            and rule~=nil and rule.requiredLink~=nil
            and rule.requiredLink.mode=="discard"
            and (source.is_face_down~=true or repeated~=nil)
            and cardPosture(source)=="upright"
            and not (data~=nil and data.cardType=="Artifact"
                and resourceCardsArtifactBroken(source.guid,source)) then
            local need=repeated~=nil and repeated.count or 1
            local paid=0
            for _=1,need do
                local target=nearestOverlap(source,function(candidate)
                    local targetData=gameCards[candidate.guid]
                    return not discarded[candidate.guid] and not boostClaimed[candidate.guid]
                        and candidate.guid~=boostSource[source.guid]
                        and not manaPowered[candidate.guid]
                        and #links[candidate.guid]==0
                        and targetData~=nil
                        and (targetData.cardType=="Starting" or targetData.cardType=="Advanced Action"
                            or targetData.cardType=="Spell" or targetData.cardType=="Artifact")
                        and candidate.getGMNotes()~="Wound"
                        and candidate.getGMNotes()~="Quest"
                        and canPayDiscard(candidate)
                end,"discard")
                if target==nil then break end
                discarded[target.guid]=source.guid
                if paid==0 then linkedCardBySource[source.guid]=target.guid end
                paid=paid+1
                connect(source,target)
            end
            hasDiscard[source.guid]=paid==need
        end
    end
    -- Stout Resolve can take multiple discard payments. Only deliberately
    -- tilted, otherwise unused cards qualify; upright cards remain played.
    -- The basic side permits one Wound, the strong side permits any number
    -- of cards but at most one Wound.
    for _,source in ipairs(cards) do
        local data=gameCards[source.guid]
        local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
        local paid=rule~=nil and rule.discardBoost or nil
        local repeated=repeatByTarget[source.guid]
        if paid~=nil and (discarded[source.guid]==nil or repeated~=nil)
            and (source.is_face_down~=true or repeated~=nil)
            and (cardPosture(source)=="upright" or repeated~=nil)
            -- A face-up broken Sword/Bow has no basic discard-payment ability.
            and not (data~=nil and data.cardType=="Artifact"
                and resourceCardsArtifactBroken(source.guid,source)) then
            local chosen=selectedResourceByGUID[source.guid]
            local strong=manaPowered[source.guid]==true or boostBy[source.guid]~=nil
                or (data~=nil and data.cardType=="Artifact"
                    and resourceCardsArtifactBroken(source.guid,source))
            if repeated~=nil then strong=repeated.powered end
            local spec=paid.normal
            if strong then spec=paid.powered end
            if spec~=nil then
            local choices={}
            for _,target in ipairs(cards) do choices[#choices+1]=target end
            for _,target in ipairs(wounds) do choices[#choices+1]=target end
            table.sort(choices,function(a,b)
                local aa=overlapArea(footprints[source.guid],footprints[a.guid])
                local bb=overlapArea(footprints[source.guid],footprints[b.guid])
                if aa==bb then return a.guid<b.guid end
                return aa>bb
            end)
            local woundPayments,bonus=0,0
            local perUse=repeated~=nil and {} or nil
            local woundUse,cardUse={},1
            for _,target in ipairs(choices) do
                local isWound=target.getGMNotes()=="Wound"
                local targetData=gameCards[target.guid]
                local eligible=isWound or (targetData~=nil
                    and (targetData.cardType=="Starting" or targetData.cardType=="Advanced Action"
                        or targetData.cardType=="Spell" or targetData.cardType=="Artifact"))
                if target.guid~=source.guid and eligible
                    and (not spec.woundOnly or isWound)
                    -- Maximal Effect repeats independent Stout Resolve payments.
                    and (not isWound or woundPayments<(spec.maxWounds or 0)
                        *(repeated~=nil and repeated.count or 1))
                    and discarded[target.guid]==nil and not boostClaimed[target.guid]
                    and #links[target.guid]==0 and skillLinksByTarget[target.guid]==nil
                    and not manaPowered[target.guid]
                    and target.is_face_down~=true and cardPosture(target)=="discard"
                    and overlapArea(footprints[source.guid],footprints[target.guid])>0 then
                    -- Physical costs are sorted by overlap. Assign Wounds to
                    -- separate applications (at most one per application) and
                    -- cycle other costs between applications. This deterministic
                    -- assignment changes with card placement, never duplicates
                    -- a payment, and follows each application's chosen effect.
                    ---@type integer|nil
                    local useIndex=1
                    if repeated~=nil then
                        if isWound then
                            useIndex=nil
                            for index=1,repeated.count do
                                if woundUse[index]~=true then useIndex=index break end
                            end
                        else
                            useIndex=cardUse
                            cardUse=cardUse%repeated.count+1
                        end
                    end
                    if useIndex~=nil then
                        discarded[target.guid]=source.guid
                        connect(source,target)
                        if isWound then
                            woundPayments=woundPayments+1
                            woundUse[useIndex]=true
                        end
                        bonus=bonus+spec.perCard
                        if perUse~=nil then
                            perUse[useIndex]=(perUse[useIndex] or 0)+spec.perCard
                        end
                    end
                end
            end
            if bonus>0 then
                discardBoostBySource[source.guid]=perUse or bonus
            end
            end
        end
    end
    return links,boostBy,boostSource,discarded,hasDiscard,linkedCardBySource,
        repeatByTarget,discardBoostBySource
end

-- A consumed Action carries the same floating red X as a defeated token.
-- Its printed face remains readable, and cleanup uses this distinct button
-- identity to throw the card away even if the player turns it face up.
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
    local found={}
    for _,button in ipairs(card.getButtons() or {}) do
        if button.click_function=="resourceCardsMaximalEffectMarkerNoop" then
            found[#found+1]=button.index
        end
    end
    for i=#found,(active and 2 or 1),-1 do card.removeButton(found[i]) end
    if active and #found==0 and card.createButton~=nil then
        local bounds=card.getBoundsNormalized()
        local scale=card.getScale()
        local height=bounds~=nil and bounds.size~=nil and (bounds.size.y or bounds.size[2]) or 0
        local scaleY=scale~=nil and (scale.y or scale[2]) or 1
        card.createButton({click_function="resourceCardsMaximalEffectMarkerNoop",
            function_owner=Global,label="X",
            position={0,math.max(0.12,height/(2*math.max(0.01,scaleY))+0.08),0},
            rotation={0,0,0},width=0,height=0,font_size=640,
            font_color={1,0.04,0.04}})
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
                    if color~=nil and matchesCardMana(source,color) then
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
    local source=sourceGUID~=nil and getObjectFromGUID(sourceGUID) or nil
    local zone=seatPos~=nil and getObjectFromGUID(playerPlayAreas[seatPos]) or nil
    if source==nil or zone==nil then return {} end
    local area=footprint(source)
    local spent,seen={},{}
    local function inspect(mana)
        if mana==nil or seen[mana.guid] or mana.guid==sourceGUID
            or not trackerPrivate.readyForXZ(mana) then return end
        seen[mana.guid]=true
        local color=manaColor(mana)
        if color==nil or not matchesCardMana(source,color) then return end
        local pos=mana.getPosition()
        local x,z=pos.x or pos[1],pos.z or pos[3]
        if math.abs(x-area.x)<area.halfX and math.abs(z-area.z)<area.halfZ then
            spent[mana.guid]=true
        end
    end
    for _,mana in ipairs(zone.getObjects()) do inspect(mana) end
    for _,mana in ipairs(getAllObjects()) do inspect(mana) end
    return spent
end

function resourceCardsMaximalEffectSyncMarks(seatPos,cards,repeats)
    local present={}
    for _,card in ipairs(cards or {}) do
        present[card.guid]=true
        local linked=repeats~=nil and repeats[card.guid]~=nil
            or (repeats==nil and resourceCardsMaximalEffectLink(seatPos,card.guid)~=nil)
        resourceCardsMaximalEffectMark(card,linked)
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
end

-- Marker reconciliation while minimized is independent of card recalculation.
function resourceCardsMaximalEffectOffDrop(obj)
    if obj==nil or gStates==nil or gStates.firstStarted~=true
        or gStates.preEndTurn==true or resourceCardsPanelOpen() then return end
    local current=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    local seat=current~=nil and current.seatPos or nil
    if seat==nil or (not objectGUIDInZone("8fac50",playerPlayAreas[seat])
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

-- U/Place Under changes the vertical order of overlapping cards without
-- changing their X/Z centres. Mana belongs to the physically highest eligible
-- card, not the closest centre (nor the first GUID in a table).
-- Coloured mana considers only legally matching cards; Gold considers any
-- eligible card. For equal height, preserve the old X/Z nearest-card rule.
trackerPrivate.bestManaCard=function(mana,cards,footprints,eligible)
    local p=mana.getPosition()
    local px,pz=p.x or p[1],p.z or p[3]
    local py=p.y or p[2]
    local best,bestY,bestDistance=nil,nil,nil
    for _,card in ipairs(cards) do
        local f=footprints[card.guid]
        if f~=nil then
            local dx,dz=px-f.x,pz-f.z
            if math.abs(dx)<f.halfX and math.abs(dz)<f.halfZ
                and eligible(card) then
                local cp=card.getPosition()
                local y=cp.y or cp[2] or 0
                local distance=dx*dx+dz*dz
                -- A payment tucked between cards cannot power a card above it.
                if (py==nil or y<=py+0.15)
                    and (best==nil or y>bestY+0.001
                    or (math.abs(y-bestY)<=0.001
                        and (distance<bestDistance
                            or (distance==bestDistance and card.guid<best.guid)))) then
                    best,bestY,bestDistance=card,y,distance
                end
            end
        end
    end
    return best
end

-- Time Bending's extra turn must be usable without opening the Resource Tracker.
-- Read the physical Blue casting payment and a separate Black strong-side payment;
-- the mere presence of the Spell in the play area does not establish either.
function resourceCardsTimeBendingPaid(seatPos,card)
    if card==nil or card.guid~=GUID.card.timeBending
        or card.is_face_down==true or cardPosture(card)~="upright"
        or not resourceCardsBlackAllowed() then return false end
    local zone=seatPos~=nil and getObjectFromGUID(playerPlayAreas[seatPos]) or nil
    if zone==nil then return false end
    local area=footprint(card)
    local blue,black=false,false
    for _,mana in ipairs(zone.getObjects()) do
        if mana.guid~=card.guid and manaInsideFootprint(mana,area)
            and (manaClaimDieHeld==nil or not manaClaimDieHeld(mana.guid)) then
            local color=manaColor(mana)
            if color=="Blue" then blue=true elseif color=="Black" then black=true end
        end
    end
    return blue and black
end

-- Physical mana is authoritative for a paid Unit ability. It is read from
-- either overlapping board zone, even with the Resource Tracker collapsed.
local function unitManaCounts(unit,seatPos,source,crystalsOnly)
    local tokens=source
    if tokens==nil then
        tokens={}
        local seen={}
        for _,zoneGUID in ipairs({playerUnitAreas[seatPos],playerPlayAreas[seatPos]}) do
            local zone=zoneGUID~=nil and getObjectFromGUID(zoneGUID) or nil
            if zone~=nil then
                for _,obj in ipairs(zone.getObjects()) do
                    if not seen[obj.guid] and trackerPrivate.readyForXZ(obj)
                        and manaColor(obj)~=nil then
                        seen[obj.guid]=true
                        tokens[#tokens+1]=obj
                    end
                end
            end
        end
    end
    local counts,area={},footprint(unit)
    local seen={}
    for _,mana in ipairs(tokens) do
        if trackerPrivate.readyForXZ(mana) then
            seen[mana.guid]=true
            local color=manaColor(mana)
            if color~=nil and (not crystalsOnly or isManaTokenFigurine(mana))
            and manaInsideFootprint(mana,area) then
                counts[color]=(counts[color] or 0)+1
            end
        end
    end
    -- Stacking can raise a crystal beyond the zone's Y extent. Recover
    -- only previously moved mana physically covering this Unit, once per GUID.
    -- Inventory crystals elsewhere never pay a Unit, and a lifted/moving
    -- crystal cannot retain its previous payment during settling.
    local candidates=trackerPrivate.unitManaCandidatesBySeat[seatPos] or {}
    for guid in pairs(candidates) do
        if not seen[guid] then
            local mana=getObjectFromGUID(guid)
            if mana==nil then
                candidates[guid]=nil
            elseif trackerPrivate.readyForXZ(mana) then
                local color=manaColor(mana)
                if color~=nil and (not crystalsOnly or isManaTokenFigurine(mana))
                    and manaInsideFootprint(mana,area) then
                    counts[color]=(counts[color] or 0)+1
                end
            end
        end
    end
    return counts
end

local function unitAbilityPaid(ability,counts)
    local color=ability.manaCost
    if color==nil then return true end
    if color=="Black" and not resourceCardsBlackAllowed() then return false end
    if (counts[color] or 0)>0 then return true end
    -- Daytime Gold can pay any basic colour, but not Black.
    return color~="Black" and resourceCardsGoldAllowed() and (counts.Gold or 0)>0
end

local function unitManaSignature(counts)
    local parts={tostring(resourceCardsGoldAllowed()),tostring(resourceCardsBlackAllowed())}
    for _,color in ipairs({"Red","Blue","Green","White","Black","Gold"}) do
        parts[#parts+1]=tostring(counts[color] or 0)
    end
    return table.concat(parts,":")
end

unitManaDecision=function(unit,abilities,activation,counts)
    -- A Command exhausted on a previous turn can be readied now, but that
    -- earlier use is not an ability in this turn's resource calculation.
    if activation.priorTurnSpent==true
        or (activation.bannerFearSelected==true
            and abilities.bannerFearIndex==nil) then
        -- Losing the Banner cannot retroactively turn its spent FEAR
        -- activation into a printed Attack or Block.
        return {index=nil,display={},ambiguous=false,selected={}}
    end
    counts=counts or unitManaCounts(unit,activation.seatPos)
    local signature=unitManaSignature(counts)
    local free,paid,direct,goldOnly={},{},{},{}
    for index,ability in ipairs(abilities) do
        if ability.manaCost==nil then
            free[#free+1]=index
        elseif unitAbilityPaid(ability,counts) then
            paid[#paid+1]=index
            if (counts[ability.manaCost] or 0)>0 then
                direct[#direct+1]=index
            else
                goldOnly[#goldOnly+1]=index
            end
        end
    end
    local result={index=nil,display={},ambiguous=false,
        signature=signature}
    local fearIndex=abilities.bannerFearIndex
    if fearIndex~=nil and activation.choice==fearIndex
        and activation.bannerFearSelected==true then
        result.index=fearIndex
        result.selected={[fearIndex]=true}
        result.display={fearIndex}
        for _,index in ipairs(paid) do result.display[#result.display+1]=index end
        for _,index in ipairs(free) do
            if index~=fearIndex then result.display[#result.display+1]=index end
        end
        return result
    end
    if abilities.multi==true then
        local chosen={}
        for _,index in ipairs(direct) do chosen[index]=true end
        local goldCount=resourceCardsGoldAllowed() and (counts.Gold or 0) or 0
        if #goldOnly<=goldCount then
            for _,index in ipairs(goldOnly) do chosen[index]=true end
        elseif goldCount>0 then
            result.ambiguous=true
            result.display=goldOnly
            local remaining=goldCount
            if activation.manaSignature==signature then
                for _,index in ipairs(goldOnly) do
                    if activation.selected~=nil and activation.selected[index]==true
                        and remaining>0 then
                        chosen[index]=true
                        remaining=remaining-1
                    end
                end
            end
        end
        result.selected=chosen
        if fearIndex~=nil then
            for _,index in ipairs(direct) do result.display[#result.display+1]=index end
            result.display[#result.display+1]=fearIndex
        end
        return result
    end
    if #paid==1 then
        -- An unambiguous paid ability stays active if another mana token later
        -- makes additional paid choices available.
        result.index=paid[1]
        activation.lastPaidIndex=result.index
        -- A previously selected paid effect no longer takes priority after
        -- another payment has made a different effect the only legal one.
        if activation.manaChoice~=nil and activation.manaChoice~=result.index then
            activation.manaChoice=nil
        end
    elseif #paid>1 then
        -- Adding mana must not discard an already valid paid choice or the
        -- corresponding Unit's existing enemy target. Prefer a manually chosen
        -- paid ability, then a previously active automatic one.
        result.ambiguous=true
        result.display=paid
        for _,index in ipairs(paid) do
            if activation.manaChoice==index then result.index=index break end
        end
        if result.index==nil then
            for _,index in ipairs(paid) do
                if activation.lastPaidIndex==index then result.index=index break end
            end
        end
        if result.index==nil then
            -- Red Cape/Northern Monks: Attack 3 -> elemental Attack 4,
            -- Block 3 -> elemental Block 4. Only carry the choice forward
            -- when exactly ONE payable ability matches that family.
            local base=abilities[activation.choice]
            local family=base~=nil and base.key or nil
            if family~=nil and family~="other" and family~="gain"
                and family~="ready" then
                local matched,duplicates=nil,false
                for _,index in ipairs(paid) do
                    if abilities[index].key==family then
                        if matched~=nil then duplicates=true break end
                        matched=index
                    end
                end
                if not duplicates then result.index=matched end
            end
        end
        if result.index~=nil then activation.lastPaidIndex=result.index end
    else
        -- Unpaid abilities stay hidden until matching mana is actually there.
        result.display=free
        for _,index in ipairs(free) do
            if activation.choice==index then result.index=index break end
        end
        if result.index==nil then result.index=free[1] end
    end
    if fearIndex~=nil and #paid>0 then
        if #paid==1 then result.display={paid[1]} end
        result.display[#result.display+1]=fearIndex
    end
    return result
end

-- Earlier Command activations own the Unit's combat use for this turn.
-- Check their actual paid/selected abilities rather than the currently
-- displayed Command number; editing an earlier choice reopens a later use.
combatConfig.unitCombatBlocked=function(unit,abilities,useIndex)
    return unitHistoryCombatConflict(unit.guid,useIndex,abilities,function(activation)
        return unitManaDecision(unit,abilities,activation,
            activation.frozenCounts or activation.lastCounts)
    end)
end

local function sidewaysManaAvailable(color)
    return color~=nil and (color~="Gold" or resourceCardsGoldAllowed())
        and (color~="Black" or resourceCardsBlackAllowed())
end

local function matchingSidewaysMana(card,color)
    if color=="Gold" or color=="Black" then return false end
    local data=gameCards[card.guid]
    if data==nil or (data.cardType~="Starting" and data.cardType~="Advanced Action"
        and data.cardType~="Spell") then return false end
    if type(data.color)=="string" then return data.color==color end
    if type(data.color)=="table" then
        for _,entry in ipairs(data.color) do if entry==color then return true end end
    end
    return false
end

-- Gold acts as a matching basic colour when paying for Universal Power in
-- Day conditions. Keep this separate from matchingSidewaysMana: that helper
-- also compares actual printed card colours for If It's Not Broken.
local function matchingSidewaysPaymentMana(card,color)
    if color=="Gold" then
        if not resourceCardsGoldAllowed() then return false end
        for _,basicColor in ipairs({"Red","Blue","Green","White"}) do
            if matchingSidewaysMana(card,basicColor) then return true end
        end
        return false
    end
    return matchingSidewaysMana(card,color)
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

local function sidewaysModifierValue(skill,target,descriptor,mana,unitState)
    local value=skill.is_face_down==true and descriptor.faceDownValue
        or descriptor.value or 1
    local cardData=gameCards[target.guid]
    if descriptor.cardTypeValues~=nil and cardData~=nil then
        value=descriptor.cardTypeValues[cardData.cardType] or value
    end
    if descriptor.choiceValues~=nil then
        local rule=skillResourceDefinitions[skill.guid]
        local _,choice=currentChoice(skill.guid,false,skillChoicesForCurrentTurn(rule))
        value=descriptor.choiceValues[choice] or value
    end
    if mana~=nil and descriptor.matchingManaValue~=nil
        and matchingSidewaysPaymentMana(target,manaColor(mana)) then
        value=descriptor.matchingManaValue
    end
    if descriptor.perEmptyCommandSlot~=nil and unitState~=nil then
        value=value+descriptor.perEmptyCommandSlot*unitState.emptyCommandSlots
    end
    return value
end

local function resolveSkillCardLinks(skills,targets,footprints,manaObjects,placements,reservedMana,unitState)
    local byTarget,bySkill,byMana={}, {}, {}
    local candidates={}
    for _,skill in ipairs(skills) do
        local rule=skillResourceDefinitions[skill.guid]
        local spec=rule~=nil and rule.linkedCard or nil
        if spec~=nil and spec.sideways~=nil
            and (spec.requiresCirculation~=true
                or (gStates.doingTheRounds or {})[skill.guid]~=nil) then
            for _,target in ipairs(targets) do
                if target.is_face_down~=true
                    and resourceObjectKind(target)==spec.targetKind
                    and (spec.posture==nil or cardPosture(target)==spec.posture) then
                    local size=overlapArea(footprints[skill.guid],footprints[target.guid])
                    if size>0 then
                        candidates[#candidates+1]={skill=skill,target=target,size=size,rule=spec.sideways}
                    end
                end
            end
        end
    end
    -- The strongest physical overlap wins when two different Skills touch the
    -- same sideways card; never combine multiple replacement values.
    table.sort(candidates,function(a,b)
        if a.size~=b.size then return a.size>b.size end
        if a.skill.guid~=b.skill.guid then return a.skill.guid<b.skill.guid end
        return a.target.guid<b.target.guid
    end)
    for _,candidate in ipairs(candidates) do
        local skill,target,descriptor=candidate.skill,candidate.target,candidate.rule
        if bySkill[skill.guid]==nil and byTarget[target.guid]==nil then
            local mana=nil
            if descriptor.manaRequired then
                local closest=nil
                local skillArea,targetArea=footprints[skill.guid],footprints[target.guid]
                for _,available in ipairs(manaObjects) do
                    if placements[available.guid]=="play" and reservedMana[available.guid]==nil
                        and byMana[available.guid]==nil
                        and sidewaysManaAvailable(manaColor(available))
                        and (manaInsideFootprint(available,skillArea)
                            or manaInsideFootprint(available,targetArea)) then
                        local p=available.getPosition()
                        local dx,dz=p[1]-targetArea.x,p[3]-targetArea.z
                        local distance=dx*dx+dz*dz
                        if closest==nil or distance<closest then
                            mana,closest=available,distance
                        end
                    end
                end
            end
            if not descriptor.manaRequired or mana~=nil then
                byTarget[target.guid]={skillGUID=skill.guid,
                    sidewaysValue=sidewaysModifierValue(skill,target,descriptor,mana,unitState),
                    manaGUID=mana~=nil and mana.guid or nil}
                bySkill[skill.guid]=target.guid
                if mana~=nil then
                    byMana[mana.guid]={skillGUID=skill.guid,targetGUID=target.guid}
                end
            end
        end
    end
    return byTarget,bySkill,byMana
end

-- Physical mana transformations are distinct from Action-card boost links.
-- The Skill selects one mana resting on it, then an overlapping powerable card.
-- Neither the die nor the crystal is physically changed or double-counted.
trackerPrivate.oppositeMana={Red="Blue",Blue="Red",Green="White",White="Green",Gold="Black",Black="Gold"}

local function convertedManaMatchesCard(card,color)
    local data=gameCards[card.guid]
    if data==nil or card.is_face_down==true or cardPosture(card)~="upright" then return false end
    if data.cardType~="Starting" and data.cardType~="Advanced Action"
        and data.cardType~="Spell" and data.cardType~="Artifact" then return false end
    -- Shared card-mana validation also checks Black-at-night and Gold-by-day.
    if color=="Gold" and not resourceCardsGoldAllowed() then return false end
    if color=="Black" and (data.cardType~="Spell" or not resourceCardsBlackAllowed()) then return false end
    return matchesCardMana(card,color)
end

local function resolveManaSkillLinks(skills,manaObjects,cards,footprints,placements)
    local byMana,bySkill,byCard={}, {}, {}
    table.sort(manaObjects,function(a,b) return a.guid<b.guid end)
    for _,skill in ipairs(skills) do
        local rule=skillResourceDefinitions[skill.guid]
        local spec=rule~=nil and rule.manaConversion or nil
        if spec~=nil then
            local area=footprints[skill.guid]
            local nearest,distance=nil,nil
            for _,mana in ipairs(manaObjects) do
                if placements[mana.guid]=="play" and byMana[mana.guid]==nil
                    and manaColor(mana)~=nil and manaInsideFootprint(mana,area) then
                    local p=mana.getPosition()
                    local dx,dz=p[1]-area.x,p[3]-area.z
                    local d=dx*dx+dz*dz
                    if distance==nil or d<distance then nearest,distance=mana,d end
                end
            end
            if nearest~=nil then
                local original=manaColor(nearest)
                local converted=spec.mode=="opposite" and trackerPrivate.oppositeMana[original] or nil
                local link={skillGUID=skill.guid,manaGUID=nearest.guid,
                    original=original,converted=converted}
                bySkill[skill.guid]=link
                byMana[nearest.guid]=link
                if converted~=nil then
                    local best,areaSize=nil,0
                    for _,card in ipairs(cards) do
                        if byCard[card.guid]==nil and convertedManaMatchesCard(card,converted) then
                            local size=overlapArea(area,footprints[card.guid])
                            if size>areaSize or (size>0 and size==areaSize and best~=nil
                                and card.guid<best.guid) then best,areaSize=card,size end
                        end
                    end
                    if best~=nil then
                        link.targetGUID=best.guid
                        byCard[best.guid]=link
                    end
                end
            end
        end
    end
    return byMana,bySkill,byCard
end

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

local function calculateSkill(skill,linkedTarget,unitState,inventoryCrystalCounts)
    local rule=skillResourceDefinitions[skill.guid]
    if rule==nil then
        return {guid=skill.guid,kind="skill",known=true,complete=false,
            status="yellow",powered=false,resources=nil}
    end
    local choices=skillChoicesForCurrentTurn(rule)
    local chosen=choices~=nil and chosenEffect(skill.guid,false,choices) or nil
    local effects=chosen
        or (skill.is_face_down==true and rule.flipped or nil)
        or (skillUsesDayStrength() and rule.day or rule.night)
        or rule.normal
    if rule.dynamic=="masterOfChaos" then
        -- The Master of Chaos marker advances when the played token is
        -- cleaned up: it earns the NEXT position's resource while in play.
        local nextSegment=((tonumber(gStates.masterOfChaos) or 0)%6)+1
        local segments={{move=1},{rangedColdFire=1},{influence=2},{attack=2},false,{block=3}}
        if nextSegment==5 then
            choices={{block=3},{move=1},
                {key="coldFire",rangedColdFire=1,icon="ranged",iconOverlay="C"},
                {attack=2},{influence=2}}
            effects=chosenEffect(skill.guid,false,choices)
        else effects=segments[nextSegment] end
    end
    if rule.locationInfluence~=nil then
        local player=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
        local place=player~=nil and player.avatarLocation or nil
        local fortified=place=="keep" or place=="mage tower"
            or (type(place)=="string" and place:sub(1,4)=="city")
        local value=place=="glade" and rule.locationInfluence.glade
            or (fortified and rule.locationInfluence.fortified
            or rule.locationInfluence.default)
        effects={influence=value}
    end
    -- Card/Unit linked bonuses must not be added until the linked target
    -- actually supplies a compatible printed resource.
    if rule.unitBoost~=nil or rule.shapeshift or rule.attackCardBoost
        or rule.manaOverload then
        effects=nil
    end

    -- Reusable board-state rule: effects can count qualifying Units instead
    -- of encoding Skill-specific calculations or depending on translated text.
    local unitSources={}
    local condition=rule.unitCondition
    local unitResolved=condition~=nil and unitState~=nil
    if unitResolved then
        local qualified=0
        local cap=condition.max or math.huge
        for _,entry in ipairs(unitState.units) do
            if (not condition.ready or entry.ready)
                and (not condition.unwounded or entry.unwounded) then
                qualified=qualified+1
                if qualified<=cap then unitSources[#unitSources+1]=entry.guid end
            end
        end
        effects={[condition.resource]=math.min(qualified,cap)}
    end

    -- Derive resource values directly from the physical crystal inventory;
    -- multiple crystals of one colour count only once.
    local inventoryResolved=false
    if rule.inventoryDistinctColors~=nil then
        local spec=rule.inventoryDistinctColors
        local count=0
        for _,color in ipairs(spec.colors) do
            if (inventoryCrystalCounts[color] or 0)>0 then count=count+1 end
        end
        effects={[spec.resource]=count*(spec.valuePerColor or 1)}
        inventoryResolved=true
    end

    local tracked=effectHasTrackedResource(effects)
    -- A targeted Skill is recognized even when it supplies no numeric resource.
    local targeted=rule.enemyEffect~=nil and chosen~=nil
    local function hasCrystals(colors)
        for _,color in ipairs(colors) do
            if (inventoryCrystalCounts[color] or 0)<=0 then return false end
        end
        return true
    end
    -- Runic Shield: crystal-dependent element and Swiftness bonus.
    local swiftDouble=rule.swiftDoubleCrystals~=nil and hasCrystals(rule.swiftDoubleCrystals) or nil
    if rule.coldFireCrystals~=nil and effects~=nil and effects.block~=nil
        and hasCrystals(rule.coldFireCrystals) then
        effects={blockColdFire=effects.block}
    end
    local unitLinked=#unitSources>0
    local status=rule.untracked and "blue"
        or (rule.unitBoost~=nil or rule.shapeshift or rule.attackCardBoost) and "yellow"
        or (linkedTarget~=nil or unitLinked) and "purple"
        or (unitResolved or inventoryResolved) and "green"
        or rule.linkedCard~=nil and linkedTarget==nil and "yellow"
        or tracked and (rule.partial and "yellow" or "green")
        or targeted and "green"
        or effects~=nil and "blue" or "yellow"
    local links={}
    if linkedTarget~=nil then links[#links+1]=linkedTarget end
    for _,guid in ipairs(unitSources) do links[#links+1]=guid end
    return {guid=skill.guid,kind="skill",known=true,
        complete=unitResolved or inventoryResolved or (tracked and not rule.partial) or targeted or linkedTarget~=nil,
        powered=skill.is_face_down==true or linkedTarget~=nil or unitLinked,
        forkedLightning=rule.forkedLightning==true,
        status=status,links=links,unitSources=unitSources,swiftDouble=swiftDouble,
        resources=effects,choices=choices}
end

-- Stable modifier instances prevent false movement redraws on every scan.
combatConfig.druidicTerrainEffects={}
for _,terrain in ipairs({"plains","hills","forest","wasteland","desert",
    "swamp","lake","mountain","city"}) do
    combatConfig.druidicTerrainEffects[terrain]={
        mode="reduce",terrains={[terrain]=true},amount=1,minimum=2}
end
combatConfig.terrainEffectOrder={set=0,cap=1,reduce=2}
local function terrainModifierPrecedes(a,b)
    local first,second=combatConfig.terrainEffectOrder[a.mode] or 9,combatConfig.terrainEffectOrder[b.mode] or 9
    if first~=second then return first<second end
    if a.mode=="reduce" then return (a.minimum or 0)>(b.minimum or 0) end
    return false
end

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
    local defenceEffect=type(spec)=="table" and (
        (tonumber(spec.armourReduce) or 0)>0
        or (tonumber(spec.armourReduceFortified) or 0)>0
        or (tonumber(spec.armourReduceByResist) or 0)>0
        or spec.removeFortify==true or spec.removeResist==true
        or spec.removeFireResist==true or spec.destroy==true
        or spec.destroyDuringAttack==true or spec.destroyIfFullyBlocked==true)
    return function(enemy,guid)
        local data=combatEnemyData(guid,enemy)
        return data~=nil and (data.attackOnly~=true or not defenceEffect)
    end
end

local function combatEffectChosenEnemy(sourceGUID,area,monsters,eligible)
    local chosen=nil
    for guid in pairs(attackAssignmentsTargetGUIDs(sourceGUID)) do
        local target=monsters[guid]
        if target==nil then
            -- Attack-reducing effects can explicitly link to reminder attacks.
            local special=combatPlayMonsters()[guid]
            local data=special~=nil and combatEnemyData(guid,special) or nil
            if data~=nil and data.attackOnly then target=special end
        end
        if target~=nil and target.is_face_down~=true
            and (eligible==nil or eligible(target,guid))
            and (chosen==nil or guid<chosen.guid) then chosen=target end
    end
    return chosen or combatEffectNearestEnemy(area,monsters,footprint,overlapArea,eligible)
end

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

    local objects,placements,monsters,playMonsters={},{},{},{}
    local combatMonsters,combatPlayMonsters={},{}
    local objectKinds={}
    local function inspectZone(guid,zoneKind)
        local zone=guid~=nil and getObjectFromGUID(guid) or nil
        if zone==nil then return end
        for _,obj in ipairs(zone.getObjects()) do
            if zoneKind=="play" or zoneKind=="unit" then
                local data=combatEnemyData(obj.guid,obj)
                if data~=nil and data.name~="Ruin" then
                    combatMonsters[obj.guid]=obj
                    if zoneKind=="play" then combatPlayMonsters[obj.guid]=obj end
                end
            end
            local kind=objectKinds[obj.guid]
            if kind==nil then
                kind=resourceObjectKind(obj)
                if kind~=nil then objectKinds[obj.guid]=kind end
            end
            if zoneKind=="play" and trackerPrivate.playCandidateKind(kind) then
                local candidates=trackerPrivate.playCandidatesBySeat[seatPos]
                if candidates==nil then
                    candidates={}
                    trackerPrivate.playCandidatesBySeat[seatPos]=candidates
                end
                candidates[obj.guid]=true
            end
            if kind~=nil and (kind~="mana" or trackerPrivate.readyForXZ(obj))
                and (zoneKind~="play" or not trackerPrivate.playCandidateKind(kind)
                    or not combatConfig.cardInTransit(obj))
                and (zoneKind=="play"
                or (zoneKind=="unit" and (kind=="unit" or kind=="mana" or kind=="puppet"))
                or (zoneKind=="crystal" and kind=="mana")) then
                -- Play-area placement takes precedence when scripting zones overlap.
                local existing=placements[obj.guid]
                if existing==nil or (zoneKind=="play" and existing~="play") then
                    objects[obj.guid]=obj
                    placements[obj.guid]=zoneKind
                end
            end
        end
    end
    inspectZone(playerCrystalAreas[seatPos],"crystal")
    inspectZone(playerUnitAreas[seatPos],"unit")
    inspectZone(playerPlayAreas[seatPos],"play")
    -- A released source may be above the shallow zone despite its X/Z being
    -- on the play mat. Recover only previously seen/dropped play sources,
    -- never arbitrary cards elsewhere on the table.
    do
        local playCandidates=trackerPrivate.playCandidatesBySeat[seatPos] or {}
        for guid in pairs(playCandidates) do
            if placements[guid]~="play" then
                local obj=getObjectFromGUID(guid)
                if obj==nil or (obj.isDestroyed~=nil and obj.isDestroyed()) then
                    playCandidates[guid]=nil
                elseif trackerPrivate.cardOverPlayMat(obj,seatPos) then
                    local kind=resourceObjectKind(obj)
                    if trackerPrivate.playCandidateKind(kind) then
                        objects[guid]=obj
                        placements[guid]="play"
                        objectKinds[guid]=kind
                    end
                elseif not combatConfig.cardInTransit(obj) then
                    playCandidates[guid]=nil
                end
            end
        end
    end
    -- Mana dropped ON a played Action may sit above the thin play
    -- scripting zone, even though its dropped GUID was seen. Recover only
    -- released, physically overlapping mana candidates; a die elsewhere on
    -- the table must never pay for an Action merely because it was moved.
    local manaCandidates=trackerPrivate.unitManaCandidatesBySeat[seatPos] or {}
    local candidateUnitFootprints=nil
    local function candidateTouchesUnit(pos)
        if candidateUnitFootprints==nil then
            candidateUnitFootprints={}
            local snapshot=unitLayoutSnapshot~=nil and unitLayoutSnapshot(seatPos) or nil
            for _,unit in ipairs(snapshot~=nil and snapshot.units or {}) do
                candidateUnitFootprints[#candidateUnitFootprints+1]=footprint(unit)
            end
        end
        for _,area in ipairs(candidateUnitFootprints) do
            if math.abs(pos[1]-area.x)<area.halfX
                and math.abs(pos[3]-area.z)<area.halfZ then return true end
        end
        return false
    end
    for guid in pairs(manaCandidates) do
        if placements[guid]~="play" then
            local mana=objects[guid] or getObjectFromGUID(guid)
            if mana==nil or (mana.isDestroyed~=nil and mana.isDestroyed()) then
                manaCandidates[guid]=nil
            elseif trackerPrivate.readyForXZ(mana) then
                local pos=mana.getPosition()
                local recovered=false
                if manaColor(mana)~=nil then
                    -- Use the top of the stack to establish that the mana is
                    -- physically on the cards. Comparing its Y against *each*
                    -- buried card can reject a valid die after U/Place Under.
                    local manaY=pos.y or pos[2]
                    local highestCardY=nil
                    for cardGUID,card in pairs(objects) do
                        if placements[cardGUID]=="play"
                            and (objectKinds[cardGUID]=="card" or objectKinds[cardGUID]=="skill") then
                            local area=footprint(card)
                            local cardPos=card.getPosition()
                            local cy=cardPos.y or cardPos[2]
                            if math.abs(pos[1]-area.x)<area.halfX
                                and math.abs(pos[3]-area.z)<area.halfZ
                                and cy~=nil and manaY~=nil and cy<=manaY+0.15
                                and (highestCardY==nil or cy>highestCardY) then
                                highestCardY=cy
                            end
                        end
                    end
                    if highestCardY~=nil and manaY-highestCardY<3 then
                        objects[guid]=mana
                        objectKinds[guid]="mana"
                        placements[guid]="play"
                        recovered=true
                    end
                end
                -- Remember above-zone payments on Units as well as Actions.
                -- Remove settled tokens dropped elsewhere; they can register
                -- again on a future drop without slowing every subsequent scan.
                if not recovered and not candidateTouchesUnit(pos) then
                    manaCandidates[guid]=nil
                end
            end
        end
    end
    -- A resting active Unit can be lifted above the thin Zone by its stacked
    -- Command/crystal without actually leaving the Unit mat. Reuse the same
    -- X/Z and held-object checks as the physical Unit layout rather than
    -- interpreting a missing zone entry as an undone activation.
    local missingActiveUnit=false
    for guid,activation in pairs(gStates.unitResourceActivations or {}) do
        if activation.seatPos==seatPos and objects[guid]==nil then
            missingActiveUnit=true
            break
        end
    end
    if missingActiveUnit then
        for _,unit in ipairs(unitLayoutSnapshot(seatPos).units) do
            if objects[unit.guid]==nil and gStates.unitResourceActivations[unit.guid]~=nil then
                objects[unit.guid]=unit
                objectKinds[unit.guid]="unit"
                placements[unit.guid]="unit"
            end
        end
    end
    -- One observation and one held-enemy reconciliation serve both systems.
    -- Reminders/Leader previews belong to combat, but never to card enemy-count bonuses.
    combatKeepHeldEnemies(seatPos,combatMonsters,combatPlayMonsters)
    -- Apply NightRules to the entire active combat, not just Dungeon/Tomb
    -- location checks. The same value powers mana legality and day/night Skills.
    trackerPrivate.renderCombatNight=resourceCardsCombatNightFromEnemies(combatMonsters)
    for guid,enemy in pairs(combatMonsters) do
        local pug=monsterPugs[guid]
        if pug~=nil and pug.name~="Ruin" then
            monsters[guid]=enemy
            if combatPlayMonsters[guid]~=nil then playMonsters[guid]=enemy end
        end
    end
    combatCalcUpdate(combatMonsters)
    local enemyEntries={}
    for guid,enemy in pairs(monsters) do
        if enemy.is_face_down~=true then enemyEntries[#enemyEntries+1]={guid=guid} end
    end

    -- Read *inventory* crystals only. A crystal moved to the Play Area is
    -- mana being spent, not part of a complete set in inventory.
    local inventoryCrystalCounts={}
    for guid,obj in pairs(objects) do
        if placements[guid]=="crystal" and isManaTokenFigurine(obj) then
            local color=manaTokenColor(obj)
            if color~=nil then
                inventoryCrystalCounts[color]=(inventoryCrystalCounts[color] or 0)+1
            end
        end
    end

    local cards,wounds,skills,manaObjects,footprints={}, {}, {}, {}, {}
    local enemyEffects={}
    local pendingWingsNight={}
    -- Resolve conditional Unit targets after other cards, Units, Skills and
    -- rewards have had a chance to remove Fortification in this same scan.
    local deferredUnfortifiedUnitEffects={}
    local unitCombatBoost,preventUnitDamage,allUnitResistances=0,false,false
    local heroFirstWoundIgnored=false
    local heroPsychicBlock=false
    local hasUnits=false
    for guid,obj in pairs(objects) do
        local kind=objectKinds[guid]
        if kind=="card" and placements[guid]=="play"
            and trackerPrivate.bannerCardForm(guid)~="half"
            and (trainingOfferReservedCard==nil
                or not trainingOfferReservedCard(guid,seatPos)) then
            cards[#cards+1]=obj
            footprints[guid]=footprint(obj)
        elseif kind=="wound" and placements[guid]=="play" then
            wounds[#wounds+1]=obj
            footprints[guid]=footprint(obj)
        elseif kind=="skill" and placements[guid]=="play" then
            skills[#skills+1]=obj
            footprints[guid]=footprint(obj)
        elseif kind=="mana" then
            if manaClaimDieHeld==nil or not manaClaimDieHeld(obj.guid) then
                manaObjects[#manaObjects+1]=obj
            end
        elseif kind=="unit" then
            -- Unit and Play Areas overlap; placement may be "play" here.
            -- The physical Unit-area snapshot still owns its wound/spent state.
            hasUnits=true
        end
    end

    -- Scan active Amulet permissions before resolving ANY physical mana.
    -- The card itself is a free artifact effect; no mana should be attached.
    combatConfig.amuletMana.gold=false
    combatConfig.amuletMana.black=false
    for _,card in ipairs(cards) do
        local data=gameCards[card.guid]
        local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
        if rule~=nil and rule.artifactMana~=nil
            and cardPosture(card)=="upright" then
            combatConfig.amuletMana[rule.artifactMana]=true
        end
    end

    combatConfig.artifactCombat.sword=false
    combatConfig.artifactCombat.bow=false
    combatConfig.artifactCombat.swordFame=false
    combatConfig.artifactCombat.bowFame=false
    for _,card in ipairs(cards) do
        local data=gameCards[card.guid]
        local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
        if rule~=nil and cardPosture(card)=="upright" then
            if rule.artifactGlobalCombat~=nil and resourceCardsArtifactBroken(card.guid,card) then
                combatConfig.artifactCombat[rule.artifactGlobalCombat]=true
            end
            if rule.artifactGlobalFame=="all" then
                combatConfig.artifactCombat.swordFame=true
            elseif rule.artifactGlobalFame=="range" and not resourceCardsArtifactBroken(card.guid,card) then
                combatConfig.artifactCombat.bowFame=true
            end
        end
    end

    -- Read the physical Unit state once per scan for highlights and Skills.
    -- A Command token already resting on a Unit from a previous turn means
    -- spent; a Unit activated by a Command move THIS turn is still active.
    local unitState=hasUnits and unitLayoutResourceState(seatPos) or nil
    gStates.unitResourceActivations=gStates.unitResourceActivations or {}
    local activations=gStates.unitResourceActivations
    local unitSiteMode,unitSite=combatUnitSiteRestriction(seatPos,combatMonsters)
    if unitSiteMode==nil then resourceCardsCombatClearOneUnit(seatPos) end
    local chosenSiteUnit=unitSiteMode=="one" and combatOneUnitChosen(seatPos,unitSite) or nil
    if unitSiteMode=="one" and chosenSiteUnit==nil and unitState~=nil then
        -- With just one used Unit, its Command token is an unambiguous choice.
        -- If several are active, do not infer that all may participate.
        local only,count=nil,0
        for _,entry in ipairs(unitState.units) do
            local activation=activations[entry.guid]
            if entry.unwounded and activation~=nil
                and activation.seatPos==seatPos then
                only,count=entry.guid,count+1
            end
        end
        if count==1 then
            chosenSiteUnit=only
            combatOneUnitSelect(seatPos,unitSite,only)
        end
    end
    trackerPrivate.unitHighlightBlocked={}
    if unitState~=nil then
        for _,entry in ipairs(unitState.units) do
            local activation=activations[entry.guid]
            local activeThisTurn=activation~=nil and activation.seatPos==seatPos
                and unitResourceDefinitions[entry.guid]~=nil
            if not entry.unwounded or (not entry.ready and not activeThisTurn)
                or not combatUnitSitePermits(unitSiteMode,
                    unitState.bondsUnitGUID,chosenSiteUnit,entry.guid,false) then
                trackerPrivate.unitHighlightBlocked[entry.guid]=true
                clearHighlight(entry.guid)
            end
        end
    end
    local countWounds=false
    for _,card in ipairs(cards) do
        local data=gameCards[card.guid]
        local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
        if rule~=nil and rule.woundBonus~=nil then countWounds=true break end
    end
    if countWounds and unitState==nil then unitState=unitLayoutResourceState(seatPos) end
    for _,skill in ipairs(skills) do
        local rule=skillResourceDefinitions[skill.guid]
        local sideways=rule~=nil and rule.linkedCard~=nil and rule.linkedCard.sideways or nil
        if unitState==nil and rule~=nil and (rule.unitCondition~=nil
            or (sideways~=nil and sideways.perEmptyCommandSlot~=nil)) then
            unitState=unitLayoutResourceState(seatPos)
            break
        end
    end
    -- Hand-zone Wounds are not play-area Wounds. Count the latter only when
    -- physically placed on a Unit, via the shared Unit layout observer.
    local woundCount=nil
    if countWounds and unitState~=nil then
        local hand=getObjectFromGUID(handZones[seatPos])
        if hand~=nil then
            woundCount=unitState.woundCount or 0
            for _,obj in ipairs(hand.getObjects()) do
                if obj.type=="Card" and obj.getGMNotes()=="Wound"
                    and placements[obj.guid]~="play" then
                    woundCount=woundCount+1
                end
            end
        end
    end

    -- Wounds may be Skill targets, but are not ordinary Action-link candidates.
    local skillTargets={}
    for _,card in ipairs(cards) do skillTargets[#skillTargets+1]=card end
    for _,wound in ipairs(wounds) do skillTargets[#skillTargets+1]=wound end

    -- First reserve conversion mana (Polarization), then sideways-skill mana,
    -- so one physical mana never powers two separate interactions.
    table.sort(cards,function(a,b) return a.guid<b.guid end)
    -- Cards already present when opening a saved/minimized tracker have no
    -- reliable order; give them one shared ordinal instead of inventing one.
    -- Subsequent real zone entries are recorded immediately at entry time.
    gStates.resourceCardPlayOrder=gStates.resourceCardPlayOrder or {}
    gStates.resourceCardPlaySerial=gStates.resourceCardPlaySerial or 0
    local missingOrder=false
    for _,card in ipairs(cards) do
        if gStates.resourceCardPlayOrder[card.guid]==nil then
            missingOrder=true break
        end
    end
    if missingOrder then
        gStates.resourceCardPlaySerial=gStates.resourceCardPlaySerial+1
        for _,card in ipairs(cards) do
            if gStates.resourceCardPlayOrder[card.guid]==nil then
                gStates.resourceCardPlayOrder[card.guid]=gStates.resourceCardPlaySerial
            end
        end
    end
    local manaByObject,manaBySkill,manaByCard=
        resolveManaSkillLinks(skills,manaObjects,cards,footprints,placements)
    local skillLinksByTarget,skillLinksBySkill,sidewaysSkillMana=
        resolveSkillCardLinks(skills,skillTargets,footprints,manaObjects,placements,manaByObject,unitState)
    local powered,usedMana,spellCastingPaid,powerManaColorsByCard={}, {}, {}, {}
    -- Some cards require a separate coloured mana payment to choose their
    -- effect. Record those candidates before deciding which mana powers the
    -- strong side; one token can never fill both roles.
    local effectManaByCard,specialPaymentByCard={},{}
    for _,card in ipairs(cards) do
        local data=gameCards[card.guid]
        local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
        if rule~=nil and rule.effectManaChoice~=nil then
            specialPaymentByCard[card.guid]=rule.effectManaChoice
        end
    end
    local function spendMana(card,color,manaGUID)
        -- Never record an illegal Daytime Black payment through the separate
        -- spell-effect or mana-conversion paths.
        if color=="Black" and not resourceCardsBlackAllowed() then return end
        local data=gameCards[card.guid]
        if data~=nil and data.cardType=="Spell" and color~="Black"
            and matchesCardMana(card,color) then
            spellCastingPaid[card.guid]=true
        end
        if specialPaymentByCard[card.guid]~=nil then
            local candidates=effectManaByCard[card.guid] or {}
            candidates[#candidates+1]={guid=manaGUID,color=color}
            effectManaByCard[card.guid]=candidates
        elseif data~=nil and data.cardType=="Spell" then
            -- Casting mana selects the normal Spell; only Black powers
            -- the stronger effect and may activate Mana Overload.
            if color=="Black" then
                powered[card.guid]=true
                powerManaColorsByCard[card.guid]=powerManaColorsByCard[card.guid] or {}
                powerManaColorsByCard[card.guid][color]=true
            end
        else
            powered[card.guid]=true
            powerManaColorsByCard[card.guid]=powerManaColorsByCard[card.guid] or {}
            powerManaColorsByCard[card.guid][color]=true
        end
        usedMana[manaGUID]=card.guid
        if trackerPrivate.traceEnabled then
            trackerPrivate.traceEvent("mana.assigned",seatPos,manaGUID,
                "color="..tostring(color).." card="..card.guid)
        end
    end
    -- Mana physically on the Skill cannot also power the card directly.
    for _,mana in ipairs(manaObjects) do
        if placements[mana.guid]=="play" and manaByObject[mana.guid]==nil
            and sidewaysSkillMana[mana.guid]==nil then
            local color=manaColor(mana)
            if color~=nil then
                local best=trackerPrivate.bestManaCard(mana,cards,footprints,function(card)
                    return cardPosture(card)=="upright" and card.is_face_down~=true
                        and (matchesCardMana(card,color)
                            or (specialPaymentByCard[card.guid]~=nil
                                and (specialPaymentByCard[card.guid].colors[color]~=nil
                                    or (color=="Gold" and resourceCardsGoldAllowed()))))
                end)
                if best~=nil then spendMana(best,color,mana.guid) end
            end
        end
    end
    for _,link in pairs(manaBySkill) do
        if link.targetGUID~=nil then
            local card=getObjectFromGUID(link.targetGUID)
            if card~=nil then spendMana(card,link.converted,link.manaGUID) end
        end
    end
    -- Power the stronger side only when a complete distinct payment set is
    -- possible. Pure Magic needs effect + Blue; Mana Thunderbolt needs
    -- casting Blue/Gold + Black + a separate effect mana.
    for guid,candidates in pairs(effectManaByCard) do
        local spec=specialPaymentByCard[guid]
        local options,wildcard=effectManaPossibilities(spec,candidates,true,
            resourceCardsGoldAllowed(),resourceCardsBlackAllowed())
        if wildcard or next(options)~=nil then powered[guid]=true end
    end
    local links,boostBy,boostSource,discarded,hasDiscard,linkedCardBySource,
        repeatByTarget,discardBoostBySource=
        resolveActionLinks(cards,wounds,footprints,powered,skillLinksByTarget)
    resourceCardsMaximalEffectSyncMarks(seatPos,cards,repeatByTarget)
    -- Extra terrain mana is an optional physical payment, separate from the
    -- mana that powers the strong action. Never reuse a claimed mana object.
    local extraTerrainManaByCard,extraTerrainManaByObject={},{}
    for _,mana in ipairs(manaObjects) do
        if placements[mana.guid]=="play" and usedMana[mana.guid]==nil
            and manaByObject[mana.guid]==nil and sidewaysSkillMana[mana.guid]==nil then
            local color=manaColor(mana)
            local best=trackerPrivate.bestManaCard(mana,cards,footprints,function(card)
                local data=gameCards[card.guid]
                local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
                local spec=rule~=nil and rule.extraTerrainMana or nil
                return spec~=nil and spec.color==color
                    and extraTerrainManaByCard[card.guid]==nil
                    and (not spec.poweredOnly or powered[card.guid]==true or boostBy[card.guid]~=nil)
                    and card.is_face_down~=true and cardPosture(card)=="upright"
            end)
            if best~=nil then
                extraTerrainManaByCard[best.guid]=mana.guid
                extraTerrainManaByObject[mana.guid]=best.guid
                usedMana[mana.guid]=best.guid
            end
        end
    end
    local current,records,totals={}, {}, {}
    local usesCurrentHexBlock=false
    local usesCurrentHexHealing=false
    local ignoreSiteFortifications=false
    local terrainModifiers=resourceCardsWeatherTerrainEffects(seatPos)
    local movementEffects={jumpTwoSpaces=false,ignoreRampagers=false,
        singleSpaceDiscount=0,windFlightMax=0}
    local usesSkillLocation=false
    -- This is a reusable declarative overlay. All passives are owned-Skill
    -- effects, whether the physical token is resting at home or being played.
    -- Read immutable rule tables so identical scans don't invalidate movement.
    for skillGUID,rule in pairs(skillResourceDefinitions) do
        if ownedSkillAtSeat(skillGUID,seatPos) then
            for _,effect in ipairs(rule.passiveTerrain or {}) do
                terrainModifiers[#terrainModifiers+1]=effect
            end
            if gStates.dayRound~=true then
                for _,effect in ipairs(rule.passiveNightTerrain or {}) do
                    terrainModifiers[#terrainModifiers+1]=effect
                end
            else
                for _,effect in ipairs(rule.passiveDayTerrain or {}) do
                    terrainModifiers[#terrainModifiers+1]=effect
                end
            end
            local extra=rule.skillManaTerrain
            if extra~=nil then
                local token=getObjectFromGUID(skillGUID)
                if token~=nil then
                    local area=footprint(token)
                    for _,mana in ipairs(manaObjects) do
                        if placements[mana.guid]=="play" and manaColor(mana)==extra.color
                            and manaInsideFootprint(mana,area) then
                            terrainModifiers[#terrainModifiers+1]=extra.effect
                            break
                        end
                    end
                end
            end
        end
    end
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
    local claimedPossessEnemies={}
    for _,card in ipairs(cards) do
        local cardData=gameCards[card.guid]
        local rule=cardData~=nil and cardResourceDefinitions[cardData.resourceKey] or nil
        local artifactBreak=cardData~=nil and cardData.cardType=="Artifact"
            and resourceCardsArtifactBroken(card.guid,card)
        local isStrong=powered[card.guid]==true or boostBy[card.guid]~=nil or artifactBreak
        if repeatByTarget[card.guid]~=nil then
            isStrong=repeatByTarget[card.guid].powered
        end
        local linkedChoices=linkedColorChoices(rule,linkedCardBySource[card.guid],isStrong)
        local repeatedColor=repeatByTarget[card.guid]
        if repeatedColor~=nil and repeatedColor.options~=nil then
            linkedChoices=repeatedColor.options[1]
        end
        if rule~=nil and rule.effectManaChoice~=nil then
            linkedChoices=paidManaChoices(card.guid,rule,isStrong,boostBy[card.guid])
        end
        -- Cold Toughness uses the enemy being blocked in the Combat Calculator,
        -- not an enemy physically placed on the Action card. Read the active lock
        -- first (including a just-clicked retarget), then a restored arrow.
        -- Outside the calculator, the existing physical overlap remains usable.
        local enemyTarget,enemyBonus=nil,nil
        if rule~=nil and rule.enemyIconBlock==true and isStrong
            and cardPosture(card)=="upright" then
            local targetGUID=nil
            if combatCalcOn then
                if combatAssignmentState.seat==seatPos then
                    targetGUID=combatAssignmentState.targets[card.guid]
                end
                if targetGUID==nil or monsters[targetGUID]==nil
                    or monsters[targetGUID].is_face_down==true then
                    targetGUID=nil
                    for guid in pairs(attackAssignmentsTargetGUIDs(card.guid)) do
                        local enemy=monsters[guid]
                        if enemy~=nil and enemy.is_face_down~=true
                            and (targetGUID==nil or guid<targetGUID) then
                            targetGUID=guid
                        end
                    end
                end
            end
            if targetGUID~=nil then enemyTarget=monsters[targetGUID] end
            -- Match the calculator's initial nearest-enemy assignment before
            -- its first panel refresh has populated the source lock.
            if enemyTarget==nil and combatCalcOn then
                local nearest=combatNearestEnemyGUID(
                    {guid=card.guid,ranged=0,siege=0,attack=0},enemyEntries)
                if nearest~=nil then enemyTarget=monsters[nearest] end
            end
            if enemyTarget==nil then
                local bestArea=0
                for guid,monster in pairs(monsters) do
                    if monster.is_face_down~=true then
                        local area=overlapArea(footprints[card.guid],footprint(monster))
                        if area>bestArea or (area==bestArea and area>0 and enemyTarget~=nil
                            and guid<enemyTarget.guid) then
                            enemyTarget,bestArea=monster,area
                        end
                    end
                end
            end
            if enemyTarget~=nil then
                enemyBonus=enemyPrintedIconBonus(monsterPugs[enemyTarget.guid])
            end
        end
        local choices=nil
        if discarded[card.guid]==nil or repeatByTarget[card.guid]~=nil then
            if cardPosture(card)=="sideways" then
                if cardCanPlaySideways(card) then choices=trackerPrivate.sidewaysChoices end
            elseif (cardData==nil or cardData.resourceAlwaysNeutral~=true)
                and (rule==nil or rule.requiredLink==nil or hasDiscard[card.guid]==true
                    or (isStrong and rule.strongNoDiscard==true))
                and (cardData==nil or cardData.cardType~="Spell"
                    or spellCastingPaid[card.guid]==true) then
                -- Don't guess an unavailable effect before its payment/link is present.
                choices=linkedChoices or sideChoices(rule,isStrong)
            end
        end
        if choices~=nil and cardPosture(card)~="discard" then
            guessInitialCardChoice(card,choices,seatPos,rule,cardPosture(card)=="sideways",
                cards,footprints,records)
        end
        local result=calculateCard(card,powered[card.guid]==true or artifactBreak,boostBy[card.guid],
            links[card.guid],discarded[card.guid]~=nil,hasDiscard[card.guid]==true,
            skillLinksByTarget[card.guid],linkedChoices,repeatByTarget[card.guid],
            discardBoostBySource[card.guid],woundCount,enemyBonus,
            spellCastingPaid[card.guid]==true)
        if rule~=nil and rule.grailFamePerHealing~=nil
            and not result.powered and result.complete
            and cardPosture(card)=="upright" then
            local used=gStates.artifactGrailHealingUsed~=nil
                and gStates.artifactGrailHealingUsed[card.guid] or 0
            used=math.max(0,math.min(2,tonumber(used) or 0))
            if used>0 then
                result.fameRep=result.fameRep or {}
                result.fameRep.fame=(result.fameRep.fame or 0)
                    +used*rule.grailFamePerHealing
            end
        end
        if rule~=nil and rule.staffDualChoices==true and combatEnemyInPlay then
            -- Only the blue crystal effect can be used during combat. Existing
            -- pre-combat Unit Ready history is preserved separately below.
            if result.powered~=true then
                local _,option=currentChoice(card.guid,false,linkedChoices)
                if option~="blue" then
                    result.resources=nil
                    result.complete=false
                    result.status="yellow"
                end
            elseif result.resources~=nil then
                -- A Break selected before combat can remain physically on the
                -- table; its Healing points cannot be spent during combat.
                local combatResources={}
                for key,value in pairs(result.resources) do
                    if key~="healing" then combatResources[key]=value end
                end
                result.resources=combatResources
            end
        end
        -- This explicit flag distinguishes browsing Magic Talent's loaned
        -- Spell from an actual paid cast, including non-numeric utility Spells.
        if cardData~=nil and cardData.cardType=="Spell" then
            result.spellCastPaid=spellCastingPaid[card.guid]==true
            local repeats=result.spellCastPaid
                and magicTalentOfferSpellCastCount~=nil
                and magicTalentOfferSpellCastCount(seatPos,card.guid) or 1
            if repeats>1 then
                local multiplied={}
                for key,value in pairs(result.resources or {}) do
                    multiplied[key]=trackerPrivate.totalsKeys[key] and type(value)=="number"
                        and value*repeats or value
                end
                result.resources=multiplied
                result.repeatCount=repeats
                if result.fameRep~=nil then
                    local fameRep={}
                    for key,value in pairs(result.fameRep) do
                        fameRep[key]=type(value)=="number" and value*repeats or value
                    end
                    result.fameRep=fameRep
                end
            end
        end

        if rule~=nil and rule.poweredTargetBonuses~=nil and result.powered==true
            and result.resources~=nil and cardPosture(card)=="upright" then
            local targetGUIDs={}
            local hasAssignmentAPI=type(attackAssignmentsTargetGUIDs)=="function"
            if hasAssignmentAPI then
                for targetGUID in pairs(attackAssignmentsTargetGUIDs(card.guid)) do
                    local enemy=monsters[targetGUID]
                    if enemy~=nil and enemy.is_face_down~=true then targetGUIDs[targetGUID]=true end
                end
            end
            if next(targetGUIDs)==nil then
                local targetGUID=nil
                if not hasAssignmentAPI then
                    targetGUID=combatAssignmentState.targets[card.guid]
                end
                if targetGUID==nil or monsters[targetGUID]==nil
                    or monsters[targetGUID].is_face_down==true then
                    targetGUID=combatNearestEnemyGUID(card.guid,enemyEntries)
                end
                if targetGUID~=nil then targetGUIDs[targetGUID]=true end
            end
            -- result.resources can alias the rule's choice table; never mutate it.
            local boosted={}
            for category,value in pairs(result.resources) do boosted[category]=value end
            result.resources=boosted
            for resource,bonus in pairs(rule.poweredTargetBonuses) do
                if (tonumber(result.resources[resource]) or 0)>0 then
                    local applies=false
                    for targetGUID in pairs(targetGUIDs) do
                        local targetData=monsterPugs[targetGUID]
                        local targetPerks=gStates.monsterPerks~=nil
                            and gStates.monsterPerks[targetGUID] or nil
                        if targetData~=nil then
                            for _,trait in ipairs(bonus.traits) do
                                if combatEnemyHasTrait(targetData,targetPerks,trait) then
                                    applies=true
                                    break
                                end
                            end
                        end
                        if applies then break end
                    end
                    if applies then
                        result.resources[resource]=result.resources[resource]+bonus.amount
                    end
                end
            end
        end

        -- Possess links to one face-up enemy placed over the powered Spell.
        -- The enemy cannot be Arcane Immune and its printed Attack (including
        -- all printed elements/strikes) becomes our melee Attack this combat.
        if rule~=nil and rule.enemyAttackLink==true and result.powered
            and result.resources~=nil and cardPosture(card)=="upright"
            and (discarded[card.guid]==nil or repeatByTarget[card.guid]~=nil) then
            local best,bestResources,bestArea=nil,nil,0
            for guid,enemy in pairs(monsters) do
                if enemy.is_face_down~=true and claimedPossessEnemies[guid]~=true then
                    local resources=enemyPrintedPossessAttack(monsterPugs[guid],guid)
                    if resources~=nil then
                        local area=overlapArea(footprints[card.guid],footprint(enemy))
                        if area>bestArea or (area==bestArea and area>0
                            and best~=nil and guid<best.guid) then
                            best,bestResources,bestArea=enemy,resources,area
                        end
                    end
                end
            end
            if best~=nil then
                claimedPossessEnemies[best.guid]=true
                result.resources=bestResources
                result.enemyGUID=best.guid
                result.possessEnemyGUID=best.guid
                result.links[#result.links+1]=best.guid
                result.status="purple"
                combatEffectAdd(enemyEffects,best.guid,card.guid,{noAttack=true,all=true})
            end
        end

        -- Sacrifice's pairs become mana, so preserve their Attack after conversion.
        if rule~=nil and rule.crystalPairAttack~=nil then
            if result.powered and result.resources~=nil
                and cardPosture(card)=="upright" and card.is_face_down~=true then
                local chosen,category=currentChoice(card.guid,true,rule.poweredChoices)
                local colors=rule.crystalPairAttack[category]
                if colors~=nil and chosen~=nil then
                    local available=math.min(inventoryCrystalCounts[colors[1]] or 0,
                        inventoryCrystalCounts[colors[2]] or 0)
                    local snapshot=combatConfig.sacrificeCastPairs[card.guid]
                    if snapshot~=nil and (snapshot.seat~=seatPos or snapshot.category~=category) then
                        snapshot=nil
                        combatConfig.sacrificeCastPairs[card.guid]=nil
                    end
                    if snapshot==nil and available>0 then
                        snapshot={seat=seatPos,category=category,pairs=available}
                        combatConfig.sacrificeCastPairs[card.guid]=snapshot
                    end
                    local pairCount=snapshot~=nil and snapshot.pairs or 0
                    result.resources={[category]=(chosen[category] or 0)*pairCount}
                    result.complete=pairCount>0
                    result.status=pairCount>0 and "green" or "blue"
                    result.sacrificePairs=pairCount
                end
            else
                combatConfig.sacrificeCastPairs[card.guid]=nil
            end
        end
        if rule~=nil and rule.poweredEnemyBonus~=nil and result.powered
            and result.resources~=nil and cardPosture(card)=="upright" then
            local enemyCount=0
            for guid,enemy in pairs(playMonsters) do
                local data,mode=combatEnemyData(guid,enemy)
                -- Summons and attack-only reminders are not extra enemy tokens.
                if enemy.is_face_down~=true and data~=nil
                    and data.attackOnly~=true and mode~="attackOnly"
                    and not combatIsSummonedToken(guid) then
                    enemyCount=enemyCount+1
                end
            end
            local updated={}
            for category,value in pairs(result.resources) do
                updated[category]=(trackerPrivate.totalsKeys[category] and type(value)=="number")
                    and value+enemyCount*rule.poweredEnemyBonus or value
            end
            result.resources=updated
        end
        if rule~=nil and rule.forestHealing~=nil and result.resources~=nil
            and result.resources.healing~=nil and cardPosture(card)=="upright" then
            usesCurrentHexHealing=true
            if currentSpellTerrain()=="forest" then
                local updated={}
                for category,value in pairs(result.resources) do updated[category]=value end
                updated.healing=rule.forestHealing
                result.resources=updated
            end
        end
        -- Druidic Staff's Break side selects TWO different options without
        -- discards. The second menu uses the same independent choice-row UI
        -- as crystal-set effects, but cannot select the first option again.
        -- Each colour is resolved once; Green contributes Heal 3, while
        -- movement/crystal/Unit-ready options require their physical actions.
        local staffDual=rule~=nil and rule.staffDualChoices==true
            and result.powered==true and cardPosture(card)=="upright"
        local staffExtraChoices=nil
        if staffDual then
            local _,firstKey=currentChoice(card.guid,true,choices)
            staffExtraChoices={}
            for _,option in ipairs(choices or {}) do
                if choiceCategory(option)~=firstKey then
                    staffExtraChoices[#staffExtraChoices+1]=option
                end
            end
            local second=inventorySetChoice(card.guid,1,staffExtraChoices,choices)
            local adjusted={}
            for key,value in pairs(result.resources or {}) do adjusted[key]=value end
            for key,value in pairs(second or {}) do
                if trackerPrivate.totalsKeys[key] and type(value)=="number" then
                    adjusted[key]=(adjusted[key] or 0)+value
                end
            end
            result.resources=adjusted
            result.inventorySetCount=second~=nil and 1 or 0
            result.complete=result.complete==true and firstKey~=nil
                and second~=nil and choiceCategory(second)~=firstKey
            -- The non-numeric options need the player to carry out the move,
            -- crystal gain, or Unit ready. Do not show fully automated green.
            if (firstKey~="green"
                or choiceCategory(second)~="green") and result.status=="green" then
                result.status="yellow"
            end
        end
        local inventorySpec=staffDual and {choices=staffExtraChoices}
            or (rule~=nil and rule.inventorySetChoices or nil)
        local inventorySets=staffDual and 1 or 0
        if not staffDual and inventorySpec~=nil and result.powered and result.resources~=nil
            and cardPosture(card)=="upright" then
            inventorySets=math.huge
            for _,color in ipairs(inventorySpec.colors) do
                inventorySets=math.min(inventorySets,inventoryCrystalCounts[color] or 0)
            end
            if inventorySets==math.huge then inventorySets=0 end
            result.inventorySetCount=inventorySets
            -- Each crystal set may make its own choice. Scale the result only
            -- after summing those choices so repeated Actions remain correct.
            local multiplier=result.repeatCount or 1
            local adjusted={}
            for category,value in pairs(result.resources) do adjusted[category]=value end
            for index=1,inventorySets do
                local bonus=inventorySetChoice(card.guid,index,inventorySpec.choices,choices)
                if bonus~=nil then
                    for category,value in pairs(bonus) do
                        if type(value)=="number" then
                            adjusted[category]=(adjusted[category] or 0)+value*multiplier
                        end
                    end
                end
            end
            result.resources=adjusted
            if result.status=="blue" and effectHasTrackedResource(adjusted) then
                result.status="green"
            end
        end
        if enemyTarget~=nil and result.resources~=nil then
            result.enemyGUID=enemyTarget.guid
            result.links[#result.links+1]=enemyTarget.guid
            result.status="purple"
        end
        -- Enemy debuffs can have a separate lock from printed Attack resources.
        if rule~=nil and rule.enemyEffect~=nil and result.resources~=nil
            and result.powered~=nil and cardPosture(card)=="upright"
            and result.status~="yellow"
            and (result.enemyGUID==nil or rule.dodgeAttackSplit==true) then
            local _,category=currentChoice(card.guid,result.powered,choices)
            local spec=combatEffectSpec(rule,result.powered,category)
            if spec~=nil or (result.repeatLink~=nil and result.repeatLink.count>1) then
                if result.repeatLink~=nil and result.repeatLink.count>1
                    and rule.dodgeAttackSplit~=true then
                    -- Maximal Effect plays each non-numeric enemy effect once.
                    -- A target key per use permits three different enemies,
                    -- while the printed Attack/Block points remain composite.
                    result.enemyEffectTargetKeys={}
                    result.enemyEffectTargetGUIDs={}
                    for index=1,result.repeatCount do
                        local options=result.repeatLink.options~=nil
                            and result.repeatLink.options[index] or choices
                        local _,selected=combatConfig.repeatChoiceFor(
                            card.guid,result.powered,options,index)
                        local effect=combatEffectSpec(rule,result.powered,selected)
                        if effect~=nil then
                            local key=card.guid.."#rep"..index
                            if not effect.all then
                                result.enemyEffectTargetKeys[#result.enemyEffectTargetKeys+1]=key
                            end
                            local target=combatEffectChosenEnemy(key,footprints[card.guid],
                                monsters,combatEffectTargetEligible(effect))
                            if effect.all then
                                for enemyGUID,monster in pairs(monsters) do
                                    if monster.is_face_down~=true then
                                        combatEffectAdd(enemyEffects,enemyGUID,card.guid,effect,key)
                                        result.links[#result.links+1]=enemyGUID
                                        result.status="purple"
                                    end
                                end
                            elseif target~=nil then
                                combatEffectAdd(enemyEffects,target.guid,card.guid,effect,key)
                                result.enemyGUID=result.enemyGUID or target.guid
                                result.enemyEffectTargetGUIDs[key]=target.guid
                                result.links[#result.links+1]=target.guid
                                result.status="purple"
                            end
                        end
                    end
                elseif rule.dodgeAttackSplit==true then
                    -- The optional Attack is automatic, with its own ordinary
                    -- target assignment. Always expose two -2 targets when
                    -- powered, even if both currently point to one enemy.
                    local count=(result.powered and 2 or 1)*(result.repeatCount or 1)
                    result.enemyEffectTargetKeys={}
                    result.enemyEffectTargetGUIDs={}
                    for index=1,count do
                        local key=card.guid.."#effect"..index
                        local target=combatEffectChosenEnemy(key,footprints[card.guid],
                            monsters,combatEffectTargetEligible({attackReduce=2}))
                        result.enemyEffectTargetKeys[#result.enemyEffectTargetKeys+1]=key
                        if target~=nil then
                            -- Do not merge the two reductions. When both aim
                            -- at one multi-attack enemy, the calculator can
                            -- select a different printed Attack for each.
                            -- Two selections of the SAME Attack still total -4.
                            combatEffectAdd(enemyEffects,target.guid,card.guid,
                                {attackReduce=2},key)
                            result.enemyGUID=result.enemyGUID or target.guid
                            result.enemyEffectTargetGUIDs[key]=target.guid
                            result.links[#result.links+1]=target.guid
                            result.status="purple"
                        end
                    end
                elseif spec~=nil then
                -- The repeated-effect branch may run without a spec;
                -- only this ordinary-effect branch reads spec fields.
                local key=rule.separateEffectTarget and not result.powered
                    and (card.guid.."#effect") or card.guid
                if (tonumber(spec.maxTargets) or 0)>1 then
                    -- Banner of Fear (Lost Legion): at most three different
                    -- enemies are unable to attack. Each target is its own
                    -- persistent physical arrow; right-click adds another.
                    local targets=attackAssignmentsTargetGUIDs(key)
                    local primary=combatEffectChosenEnemy(key,footprints[card.guid],
                        monsters,combatEffectTargetEligible(spec))
                    if next(targets)==nil and primary~=nil then targets[primary.guid]=true end
                    local ordered={}
                    for guid in pairs(targets) do
                        local monster=monsters[guid]
                        if monster~=nil and monster.is_face_down~=true then
                            ordered[#ordered+1]=guid
                        end
                    end
                    table.sort(ordered)
                    result.enemyEffectTargetKeys={key}
                    for index=1,math.min(#ordered,spec.maxTargets) do
                        local targetGUID=ordered[index]
                        combatEffectAdd(enemyEffects,targetGUID,card.guid,spec,key)
                        result.links[#result.links+1]=targetGUID
                        if result.enemyGUID==nil then
                            result.enemyGUID=targetGUID
                            result.enemyEffectTargetGUIDs={[key]=targetGUID}
                        end
                        result.status="purple"
                    end
                elseif spec.multiTargetMove then
                    -- Right-click target to add further enemies; cost is settled
                    -- after all Move-producing cards/Units/Skills have been read.
                    result.enemyEffectTargetKeys={key}
                    local targets=attackAssignmentsTargetGUIDs(key)
                    local primary=combatEffectChosenEnemy(key,footprints[card.guid],
                        monsters,combatEffectTargetEligible(spec))
                    if next(targets)==nil and primary~=nil then targets[primary.guid]=true end
                    local ordered={}
                    for guid in pairs(targets) do
                        local monster=monsters[guid]
                        if monster~=nil and monster.is_face_down~=true then
                            ordered[#ordered+1]=guid
                        end
                    end
                    local first=combatAssignmentState.targets[key]
                        or (primary~=nil and primary.guid or nil)
                    table.sort(ordered,function(a,b)
                        if a==first then return true end
                        if b==first then return false end
                        return a<b
                    end)
                    if #ordered>0 then
                        pendingWingsNight[#pendingWingsNight+1]={source=card.guid,targets=ordered}
                        result.enemyEffectTargetGUIDs={[key]=ordered[1]}
                        result.enemyGUID=ordered[1]
                        for _,guid in ipairs(ordered) do result.links[#result.links+1]=guid end
                        result.status="purple"
                    end
                else
                    local target=combatEffectChosenEnemy(key,footprints[card.guid],
                        monsters,combatEffectTargetEligible(spec))
                    if target~=nil then
                        local targetGUID=target.guid
                        for _=1,(result.repeatCount or 1) do
                            if spec.all then
                                for guid,monster in pairs(monsters) do
                                    if monster.is_face_down~=true then
                                        combatEffectAdd(enemyEffects,guid,card.guid,spec,key)
                                    end
                                end
                            else
                                combatEffectAdd(enemyEffects,targetGUID,card.guid,spec,key)
                                if spec.othersArmourReduce~=nil then
                                    for guid,monster in pairs(monsters) do
                                        if guid~=targetGUID and monster~=nil and monster.is_face_down~=true then
                                            combatEffectAdd(enemyEffects,guid,card.guid,
                                                {armourReduce=spec.othersArmourReduce,all=true,fireSpell=spec.fireSpell})
                                        end
                                    end
                                end
                            end
                        end
                        result.enemyGUID=targetGUID
                        result.links[#result.links+1]=targetGUID
                        result.status="purple"
                        if not spec.all then
                            result.enemyEffectTargetKeys={key}
                            result.enemyEffectTargetGUIDs={[key]=targetGUID}
                        end
                    end
                end
                end -- Dodge and Weave separate effect targets
            end
        end
        if rule~=nil and rule.woundBonus~=nil and result.resources~=nil and unitState~=nil then
            result.unitSources={}
            for _,unit in ipairs(unitState.units) do
                if unit.woundCount>0 then
                    result.unitSources[#result.unitSources+1]=unit.guid
                end
            end
        end
        local manaLink=manaByCard[card.guid]
        if manaLink~=nil then
            result.status="purple"
            result.links[#result.links+1]=manaLink.skillGUID
            result.convertedMana=manaLink.converted
        end
        -- The recruitment-cost change is not performed by the offer script:
        -- the player chooses when to use these two extra Influence points.
        local recruitBonus=resourceCardsRecruitInfluenceBonus(card.guid,rule,result)
        if recruitBonus>0 then
            local adjusted={}
            for key,value in pairs(result.resources) do adjusted[key]=value end
            adjusted.influence=(tonumber(adjusted.influence) or 0)+recruitBonus
            result.resources=adjusted
        end
        result.choices=choices -- Also authoritative for payment-restricted click validation.
        showChoiceButtons(card,choices,result.powered,inventorySpec,inventorySets,result.resources,
            repeatByTarget[card.guid])
        if cardData~=nil and cardData.resourceKey=="spellCure" then
            combatConfig.refreshCureDrawButton(card,
                result.complete==true and result.powered~=true
                and resourceCardsDetailsOpen())
        end
        -- Expose a separate Armour-reduction source. It is independent of the
        -- card's Ranged Attack target and becomes effective only after a kill.
        if result.explosiveBolt~=nil and combatCalcOn then
            result.enemyEffectTargetKeys={card.guid.."#explosiveAttack"}
        end
        -- Ordinary Move cards and played Artifacts can both change terrain
        -- costs; amulets grant no numeric Move and work on their Break side.
        if rule~=nil and cardPosture(card)=="upright" and result.resources~=nil
            and (type(result.resources.move)=="number"
                or (cardData~=nil and cardData.cardType=="Artifact")) then
            for _=1,(result.repeatCount or 1) do
                for _,effect in ipairs(cardTerrainEffects(rule,result.powered) or {}) do
                    if terrainEffectActive(effect) then
                        terrainModifiers[#terrainModifiers+1]=effect
                    end
                end
            end
            local extraManaGUID=extraTerrainManaByCard[card.guid]
            if extraManaGUID~=nil and rule.extraTerrainMana~=nil then
                terrainModifiers[#terrainModifiers+1]=rule.extraTerrainMana.effect
                result.links[#result.links+1]=extraManaGUID
                result.status="purple"
            end
        end
        -- Persistent movement rules are non-numeric abilities: collect them
        -- from the actual played card, independently of Resource Tracker
        -- resource values/completeness. A powered side must never inherit the
        -- unpowered side's movement rules.
        if rule~=nil and rule.movementEffects~=nil and cardPosture(card)=="upright"
            and (card.is_face_down~=true or result.repeatLink~=nil)
            and (cardData==nil or cardData.cardType~="Spell"
                or spellCastingPaid[card.guid]==true)
            and (discarded[card.guid]==nil or repeatByTarget[card.guid]~=nil) then
            local effect=result.powered and rule.movementEffects.powered
                or (not result.powered and rule.movementEffects.normal or nil)
            if effect~=nil then
                if effect.jumpTwoSpaces==true then movementEffects.jumpTwoSpaces=true end
                if effect.ignoreRampagers==true then movementEffects.ignoreRampagers=true end
                if effect.windFlightMax~=nil then
                    movementEffects.windFlightMax=math.max(movementEffects.windFlightMax,effect.windFlightMax)
                end
            end
        end
        if rule~=nil and result.complete and result.resources~=nil
            and cardPosture(card)=="upright"
            and (card.is_face_down~=true or result.repeatLink~=nil) then
            if rule.oneSpaceDiscount~=nil and not result.powered then
                -- Basic Druidic Paths discounts a single entered space per
                -- route, never every space of one terrain type.
                movementEffects.singleSpaceDiscount=math.max(
                    movementEffects.singleSpaceDiscount,rule.oneSpaceDiscount.amount or 1)
            elseif rule.selectedTerrainDiscount~=nil and result.powered then
                local selection=gStates.startingCardSelections
                    and gStates.startingCardSelections[card.guid] or nil
                local modifier=selection~=nil
                    and combatConfig.druidicTerrainEffects[selection.terrain] or nil
                if modifier~=nil then
                    for _=1,(result.repeatCount or 1) do
                        terrainModifiers[#terrainModifiers+1]=modifier
                    end
                elseif result.status~="purple" then
                    -- Move 4 is counted but the terrain choice is not guessed.
                    result.status="yellow"
                end
            end
        end
        -- Both Demolish (basic) and Underground Attack (strong) bypass the
        -- current assault's site/wall Fortification, never printed Fortified.
        -- Recomputed each scan so lost mana, a changed side or a removed card
        -- cannot leave a stale combat modifier.
        if resourceCardsIgnoreSiteFortification(rule,result,card) then
            ignoreSiteFortifications=true
        end
        -- Conditional combat effects apply only on a paid, upright, actually
        -- played side, never when the card is merely in the zone for display.
        if rule~=nil and result.complete and result.resources~=nil
            and cardPosture(card)=="upright"
            and (card.is_face_down~=true or result.repeatLink~=nil) then
            if rule.unitCombatBoost~=nil then
                local bonus=result.powered and rule.unitCombatBoost.powered
                    or rule.unitCombatBoost.normal
                unitCombatBoost=unitCombatBoost+(bonus or 0)*(result.repeatCount or 1)
                if rule.preventUnitDamage==true then preventUnitDamage=true end
            end
            if rule.poweredUnitResistances==true and result.powered then
                allUnitResistances=true
            end
            if rule.poweredHeroFirstWound==true and result.powered then
                heroFirstWoundIgnored=true
            end
        end
        -- Fixed components of partially understood cards may be counted; an
        -- unresolved choice never contributes an invented amount.
        addResourceAmounts(result,totals)
        records[card.guid]=result
        current[card.guid]=true
        if result.usesTerrainBlock then usesCurrentHexBlock=true end
        setHighlight(card,result.status,result.powered)
    end
    -- Wolfhawk's Tirelessness affects only subsequently PLAYED cards, not
    -- already-played cards or Units. Maximal Effect repeats the bonus but
    -- each repeated target Action is still only one played card.
    for _,source in ipairs(cards) do
        local data=gameCards[source.guid]
        local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
        local modifier=rule~=nil and rule.followingMoveBonus or nil
        local origin=records[source.guid]
        if modifier~=nil and origin~=nil and origin.complete==true
            and origin.resources~=nil and (tonumber(origin.resources.move) or 0)>0
            and cardPosture(source)=="upright"
            and (source.is_face_down~=true or origin.repeatLink~=nil) then
            local order=gStates.resourceCardPlayOrder[source.guid]
            local candidates={}
            for _,target in ipairs(cards) do
                local targetRecord=records[target.guid]
                local targetOrder=gStates.resourceCardPlayOrder[target.guid]
                if target.guid~=source.guid and targetOrder~=nil and order~=nil
                    and targetOrder>order and targetRecord~=nil
                    and targetRecord.complete==true and targetRecord.resources~=nil
                    and (tonumber(targetRecord.resources.move) or 0)>0 then
                    candidates[#candidates+1]=target
                end
            end
            table.sort(candidates,function(a,b)
                local aa=gStates.resourceCardPlayOrder[a.guid]
                local bb=gStates.resourceCardPlayOrder[b.guid]
                return aa==bb and a.guid<b.guid or aa<bb
            end)
            local spec=origin.powered and modifier.powered or modifier.normal
            local count=spec.all and #candidates or math.min(#candidates,spec.count or 1)
            local extra=(spec.amount or 1)*(origin.repeatCount or 1)
            for i=1,count do
                local target=candidates[i]
                local record=records[target.guid]
                record.resources.move=record.resources.move+extra
                record.tirelessnessBonus=(record.tirelessnessBonus or 0)+extra
                totals.move=(totals.move or 0)+extra
            end
        end
    end
    -- Outline an enemy that supplied a printed ability bonus or a Possess
    -- Attack; the enemy record itself does not add those values twice.
    -- Iterate the card list, not records: the loop also adds enemy records.
    for _,card in ipairs(cards) do
        local record=records[card.guid]
        if record~=nil and record.enemyGUID~=nil then
            local enemy=monsters[record.enemyGUID]
            if enemy~=nil then
                local enemyRecord=records[enemy.guid]
                if enemyRecord==nil then
                    enemyRecord={guid=enemy.guid,kind="monster",known=true,complete=true,
                        powered=true,links={},status="purple",resources=nil}
                    records[enemy.guid]=enemyRecord
                end
                enemyRecord.links[#enemyRecord.links+1]=record.guid
                current[enemy.guid]=true
                setHighlight(enemy,"purple",true)
            end
        end
    end
    -- Deadly Precision's stronger conversion works only on one physically
    -- overlapping, played Action with a single active melee Attack value.
    -- Do not invent a target or a mana payment when links are ambiguous.
    for _,source in ipairs(cards) do
        local data=gameCards[source.guid]
        local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
        local sourceRecord=records[source.guid]
        if rule~=nil and rule.poweredLinkConversion==true
            and sourceRecord~=nil and sourceRecord.powered==true
            and sourceRecord.resources~=nil and cardPosture(source)=="upright"
            and discarded[source.guid]==nil
            and choiceCategory(chosenEffect(source.guid,true,rule.poweredChoices))=="convert" then
            local candidates={}
            for _,target in ipairs(cards) do
                local targetData=gameCards[target.guid]
                local targetRecord=records[target.guid]
                if target.guid~=source.guid and targetData~=nil
                    and (targetData.cardType=="Starting" or targetData.cardType=="Advanced Action")
                    and targetRecord~=nil and targetRecord.resources~=nil
                    and cardPosture(target)=="upright" and target.is_face_down~=true
                    and discarded[target.guid]==nil then
                    local attackKey=nil
                    local ambiguous=false
                    for _,key in ipairs({"attack","attackFire","attackIce",
                        "attackColdFire","attackPsychic"}) do
                        if (tonumber(targetRecord.resources[key]) or 0)>0 then
                            if attackKey~=nil then ambiguous=true break end
                            attackKey=key
                        end
                    end
                    local area=overlapArea(footprints[source.guid],footprints[target.guid])
                    if attackKey~=nil and not ambiguous and area>0 then
                        candidates[#candidates+1]={card=target,record=targetRecord,
                            key=attackKey,area=area}
                    end
                end
            end
            table.sort(candidates,function(a,b)
                if a.area~=b.area then return a.area>b.area end
                return a.card.guid<b.card.guid
            end)
            local best=candidates[1]
            if best~=nil and (candidates[2]==nil or best.area>candidates[2].area) then
                local to="ranged"..best.key:sub(7)
                local amount=best.record.resources[best.key]
                local updated={}
                for key,value in pairs(best.record.resources) do updated[key]=value end
                updated[best.key]=nil
                updated[to]=(updated[to] or 0)+amount
                best.record.resources=updated
                totals[best.key]=(totals[best.key] or 0)-amount
                totals[to]=(totals[to] or 0)+amount
                sourceRecord.links[#sourceRecord.links+1]=best.card.guid
                best.record.links[#best.record.links+1]=source.guid
                sourceRecord.complete=true
                sourceRecord.contributes=true
                sourceRecord.status="purple"
                best.record.status="purple"
                setHighlight(source,"purple",true)
                setHighlight(best.card,"purple",best.record.powered)
            end
        end
    end
    -- Ambush's explicit card assignment takes priority over physical overlap.
    -- The Move enemy target stays in the ordinary combat assignment registry.
    local combatCategories=combatConfig.ambushCombatCategories
    for _,source in ipairs(cards) do
        local data=gameCards[source.guid]
        local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
        local sourceRecord=records[source.guid]
        if rule~=nil and rule.combatLink~=nil and sourceRecord~=nil
            and sourceRecord.resources~=nil and cardPosture(source)=="upright"
            and (discarded[source.guid]==nil or repeatByTarget[source.guid]~=nil) then
            local best,bestCategory,bestType,bestOverlap=nil,nil,nil,0
            local function chooseCategory(target)
                local record=records[target.guid]
                if discarded[target.guid]~=nil
                    or not combatConfig.ambushEligibleTarget(target.guid,record,source.guid) then
                    return nil,nil
                end
                for _,key in ipairs(combatCategories) do
                    if (tonumber(record.resources[key]) or 0)>0 then
                        return key,key:sub(1,5)=="block" and "block" or "attack"
                    end
                end
                return nil,nil
            end
            local saved=gStates~=nil and gStates.ambushCombatLinks or nil
            local savedGUID=saved~=nil and saved[source.guid] or nil
            if savedGUID~=nil then
                local target=getObjectFromGUID(savedGUID)
                if target~=nil then
                    local category,kind=chooseCategory(target)
                    if category~=nil then
                        best,bestCategory,bestType=target,category,kind
                    end
                end
                -- A lifted target keeps its assignment until the settled scan.
                if best==nil and (target==nil or not combatConfig.cardInTransit(target)) then
                    saved[source.guid]=nil
                    savedGUID=nil
                end
            end
            if best==nil and savedGUID==nil then
                for _,target in ipairs(cards) do
                    local area=target.guid~=source.guid
                        and overlapArea(footprints[source.guid],footprints[target.guid]) or 0
                    if area>0 then
                        local category,kind=chooseCategory(target)
                        if category~=nil and (area>bestOverlap
                            or (area==bestOverlap and best~=nil and target.guid<best.guid)) then
                            best,bestCategory,bestType,bestOverlap=target,category,kind,area
                        end
                    end
                end
            end
            if best~=nil and bestCategory~=nil and bestType~=nil then
                local bonusRule=sourceRecord.powered and rule.combatLink.powered
                    or rule.combatLink.normal
                local bonus=bonusRule[bestType]*(sourceRecord.repeatCount or 1)
                local targetRecord=records[best.guid]
                if targetRecord==nil or targetRecord.resources==nil then
                    error("The linked combat target has no resource record.",2)
                end
                local adjusted={}
                for key,value in pairs(targetRecord.resources) do adjusted[key]=value end
                local targetAmount=adjusted[bestCategory]
                if type(targetAmount)~="number" then
                    error("The linked combat target is missing its selected resource.",2)
                end
                adjusted[bestCategory]=targetAmount+bonus
                targetRecord.resources=adjusted
                -- Shield of the Fallen Kings keeps separate Block effects.
                -- Ambush augments only the first one, not each equal split.
                if bestType=="block" and (tonumber(targetRecord.repeatBlocks) or 1)>1 then
                    targetRecord.ambushFirstBlockBonus=
                        (targetRecord.ambushFirstBlockBonus or 0)+bonus
                end
                totals[bestCategory]=(totals[bestCategory] or 0)+bonus
                if sourceRecord.links==nil or targetRecord.links==nil then
                    error("A linked combat record has no link list.",2)
                end
                sourceRecord.links[#sourceRecord.links+1]=best.guid
                targetRecord.links[#targetRecord.links+1]=source.guid
                sourceRecord.status="purple"
                targetRecord.status="purple"
                sourceRecord.contributes=true
                setHighlight(source,sourceRecord.status,sourceRecord.powered)
                setHighlight(best,targetRecord.status,targetRecord.powered)
            end
        end
    end
    -- Retire stale manual links when Ambush itself is no longer a played
    -- upright card. Transiently lifted cards keep their pending assignments.
    for guid in pairs(gStates~=nil and gStates.ambushCombatLinks or {}) do
        local record=records[guid]
        local data=gameCards[guid]
        local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
        local obj=getObjectFromGUID(guid)
        if (record==nil or record.complete~=true or record.resources==nil
            or rule==nil or rule.combatLink==nil or obj==nil
            or obj.is_face_down==true or cardPosture(obj)~="upright")
            and not combatConfig.cardInTransit(obj) then
            gStates.ambushCombatLinks[guid]=nil
        end
    end
    -- An unlinked Wound is inert. Only an attached Skill or a deliberate
    -- discard payment gives it a tracker outline.
    for _,wound in ipairs(wounds) do
        local skillLink=skillLinksByTarget[wound.guid]
        if skillLink~=nil then
            local result=calculateSideways(wound,true,skillLink)
            result.kind="wound"
            showChoiceButtons(wound,trackerPrivate.sidewaysChoices,result.powered)
            addResourceAmounts(result,totals)
            records[wound.guid]=result
            current[wound.guid]=true
            setHighlight(wound,result.status,result.powered)
        elseif links[wound.guid]~=nil and #links[wound.guid]>0 then
            local result={guid=wound.guid,kind="wound",known=true,complete=true,
                powered=false,links=links[wound.guid],status="purple",resources=nil}
            records[wound.guid]=result
            current[wound.guid]=true
            setHighlight(wound,result.status,false)
        end
    end
    -- Unit activation is historical: a Command token may stay on the card for
    -- the entire round, or be moved away by an ability. Only a Command move
    -- during THIS turn creates an entry, never a static token found on load.
    -- Read only released mana physically over each Unit; inventory mana does
    -- not pay costs. Familiar crystals are a persistent modifier, not a cost.
    local howlOwner=gStates~=nil and gStates.doingTheRounds
        and gStates.doingTheRounds["a92d73"] or nil
    local howlPenalty=howlOwner~=nil and howlOwner~=gStates.turnNumber
        and (gStates.soloCoop==nil or gStates.soloCoop["a92d73"]~=true)
    -- Printed Altem Mages' red/blue bonuses can each be bought once.
    -- Daytime Gold substitutes for the missing basic colour, but never
    -- buys more than the printed +4 total or counts twice as one token.
    local function unitManaScaleBonus(counts)
        local natural=(counts.Red or 0)>0 and 1 or 0
        if (counts.Blue or 0)>0 then natural=natural+1 end
        local gold=resourceCardsUsesDayMana() and (counts.Gold or 0) or 0
        return math.min(2,natural+gold)*2
    end
    local function unitAbilityResources(ability,counts,crystalCounts)
        if ability==nil or (not unitAbilityPaid(ability,counts)
            and not ability.baseWithoutPayment) then return nil end
        local resources={}
        for category,value in pairs(ability) do
            if trackerPrivate.totalsKeys[category] and type(value)=="number" then
                local bonus=0
                if ability.bonusColor~=nil and (crystalCounts[ability.bonusColor] or 0)>0 then
                    bonus=ability.bonus or 0
                end
                if ability.manaScale then bonus=bonus+unitManaScaleBonus(counts) end
                if unitCombatBoost>0 and (category:sub(1,6)=="attack"
                    or category:sub(1,6)=="ranged"
                    or category:sub(1,5)=="siege"
                    or category:sub(1,5)=="block") then
                    bonus=bonus+unitCombatBoost
                end
                local amount=value+bonus
                if howlPenalty and (category:sub(1,6)=="attack"
                    or category:sub(1,6)=="ranged"
                    or category:sub(1,5)=="siege"
                    or category:sub(1,5)=="block") then
                    amount=math.max(0,amount-1)
                end
                resources[category]=amount
            end
        end
        return resources
    end
    -- Call to Arms uses the original Unit card temporarily positioned by
    -- the offer browser. It gains a normal Unit activation without a Command
    -- slot only when the basic white Spell was actually paid and played.
    local offeredUnit=callOfferBorrowedUnitForSeat~=nil
        and callOfferBorrowedUnitForSeat(seatPos) or nil
    if offeredUnit~=nil then
        local spellRecord=records["2eb8e8"]
        local unitGUID=offeredUnit.guid
        local paid=spellRecord~=nil and spellRecord.complete==true
            and spellRecord.powered~=true and spellRecord.resources~=nil
        if paid and unitResourceDefinitions[unitGUID]~=nil then
            objects[unitGUID]=offeredUnit
            local activation=activations[unitGUID]
            if activation==nil or activation.callOffer~=true then
                local abilities=unitResourceDefinitions[unitGUID]
                local scores=trackerChoiceScores(unitGUID,seatPos)
                local chosen,best=1,-math.huge
                for i,ability in ipairs(abilities) do
                    if ability.manaCost==nil then
                        local score=scores[ability.key] or 0
                        if score>best then chosen,best=i,score end
                    end
                end
                activations[unitGUID]={seatPos=seatPos,callOffer=true,
                    choice=chosen,selected=abilities.multi==true and {} or nil}
            end
        elseif activations[unitGUID]~=nil and activations[unitGUID].callOffer then
            removeChoiceButtons(offeredUnit)
            activations[unitGUID]=nil
        end
    end
    -- A flipped attached Courage banner explicitly authorises the Unit to
    -- ready once this round. The broken banner authorises every used Unit.
    -- unitHistory owns the actual Command move, extra activation and undo;
    -- simply flipping a card never creates free Attack or Block resources.
    if not combatCalcOn and unitState~=nil then
        gStates.unitReadyLinks=gStates.unitReadyLinks or {}
        local byUnit=unitState.bannersByUnit or {}
        for unitGUID,banners in pairs(byUnit) do
            local courage=banners["Banner of Courage"]
            if courage~=nil and courage.faceDown and
                gStates.unitReadyLinks[courage.guid]==nil then
                unitHistoryReadyLink(courage.guid,unitGUID,seatPos,nil)
            end
        end
        local courageUses=trackerPrivate.bannerEffectUses().courage
        for _,card in ipairs(cards) do
            local data=gameCards[card.guid]
            if data~=nil and data.resourceKey=="artifactBannerCourage"
                and trackerPrivate.bannerStrongActive(card)
                and cardPosture(card)=="upright" then
                -- Capture eligible spent Units at the moment the Banner breaks.
                -- Spent Units appearing later in this Round are never added.
                if courageUses[card.guid]==nil then
                    local eligible={}
                    for index,entry in ipairs(unitState.units) do
                        if not entry.ready then
                            eligible[#eligible+1]={key=card.guid.."#ready"..index,
                                guid=entry.guid}
                        end
                    end
                    courageUses[card.guid]={eligible=eligible}
                end
                for _,entry in ipairs(courageUses[card.guid].eligible) do
                    -- The link, not a stale cached boolean, is authoritative.
                    -- A Break toggle off/on restores only the original eligible
                    -- Units, never Units spent after the first Break.
                    if gStates.unitReadyLinks[entry.key]==nil then
                        unitHistoryReadyLink(entry.key,entry.guid,seatPos,nil)
                    end
                end
            end
        end
    end
    local selectedUnitAttacks={}
    local activationByRecordKey={}
    local shocktroopsBoosts=0
    local attackTransforms={}
    local transformingUnits={}
    unitHistoryValidSources(seatPos)
    for unitGUID,currentActivation in pairs(activations) do
      if currentActivation.seatPos==seatPos then
       for useIndex,activation in ipairs(unitHistoryUses(unitGUID,currentActivation)) do
        if activation.priorTurnSpent~=true then
        local recordKey=unitHistoryKey(unitGUID,useIndex)
        activationByRecordKey[recordKey]=activation
            local unit=objects[unitGUID]
            local abilities=trackerPrivate.unitAbilitiesFor(unitGUID,unitState,seatPos)
            if unit~=nil and abilities~=nil then
                if unitState==nil then unitState=unitLayoutResourceState(seatPos) end
                if unitState==nil then error("Unable to read Unit resource state.",2) end
                local unwounded=true
                for _,entry in ipairs(unitState.units) do
                    if entry.guid==unitGUID then unwounded=entry.unwounded break end
                end
                local counts=activation.frozenCounts
                    or unitManaCounts(unit,seatPos,manaObjects)
                if activation.frozenCounts==nil then
                    activation.lastCounts=unitHistoryCopyCounts(counts)
                end
                local decision=unitManaDecision(unit,abilities,activation,counts)
                local deniedCombat=combatConfig.unitCombatBlocked(unit,abilities,useIndex)
                    and unitHistoryDecisionHasCombat(abilities,decision)
                if activation.callOffer and unitSiteMode=="one"
                    and chosenSiteUnit==nil then
                    chosenSiteUnit=unitGUID
                    combatOneUnitSelect(seatPos,unitSite,unitGUID)
                end
                local sitePermits=combatUnitSitePermits(unitSiteMode,
                    unitState.bondsUnitGUID,chosenSiteUnit,unitGUID,false)
                if unitHistorySelectedNumber(unitGUID)==useIndex then
                    if sitePermits then
                        showUnitAbilityButtons(unit,abilities,activation,true,decision,useIndex)
                    else
                        removeChoiceButtons(unit)
                    end
                end
                local selected=decision.index~=nil and abilities[decision.index] or nil
                if (unwounded or activation.frozenCounts~=nil) and sitePermits then
                    local crystalCounts=selected~=nil and selected.bonusColor~=nil
                        and unitManaCounts(unit,seatPos,manaObjects,true) or nil
                    local resources=not deniedCombat and selected~=nil
                        and unitAbilityResources(selected,counts,crystalCounts) or nil
                    local banners=unitState~=nil and unitState.bannersByUnit~=nil
                        and unitState.bannersByUnit[unitGUID] or nil
                    local gloryAttached=banners~=nil and banners["Banner of Glory"]~=nil
                    local gloryGlobal=(function()
                            for _,artifact in ipairs(cards) do
                                local data=gameCards[artifact.guid]
                                if data~=nil and data.resourceKey=="artifactBannerGlory"
                                    and trackerPrivate.bannerStrongActive(artifact)
                                    and cardPosture(artifact)=="upright" then return true end
                            end
                            return false
                        end)()
                    local hasGlory=gloryAttached or gloryGlobal
                    local gloryCombat=false
                    if resources~=nil and hasGlory then
                        local boosted={}
                        for key,value in pairs(resources) do
                            local combatResource=type(key)=="string" and type(value)=="number"
                                and (key:sub(1,6)=="attack" or key:sub(1,6)=="ranged"
                                    or key:sub(1,5)=="siege" or key:sub(1,5)=="block")
                            boosted[key]=combatResource and value+1 or value
                            if combatResource and value>0 then gloryCombat=true end
                        end
                        resources=boosted
                    end
                    local result={guid=recordKey,sourceObjectGUID=unitGUID,
                        activationIndex=useIndex,kind="unit",known=true,
                        complete=not deniedCombat and (selected~=nil and unitAbilityPaid(selected,counts)
                            or abilities.multi==true and next(decision.selected or {})~=nil),
                        resources=resources,powered=false,links={},
                        swiftDouble=selected~=nil and selected.countsTwiceVsSwift==true or nil,
                        gloryFame=gloryCombat and (gloryGlobal and "global" or "attached") or nil,
                        fameRep=selected~=nil and selected.fameRep or nil}
                    result.fameRep=result.complete and result.fameRep or nil
                    addResourceAmounts(result,totals)
                    result.status=result.contributes and "green" or "blue"
                    records[recordKey]=result
                    current[unitGUID]=true
                    if unitHistorySelectedNumber(unitGUID)==useIndex then
                        setHighlight(unit,result.status,false)
                    end
                    if selected~=nil and selected.terrainReduce and result.complete then
                        terrainModifiers[#terrainModifiers+1]=trackerPrivate.forestersTerrainModifier
                    end
                    if selected~=nil and selected.boostOtherUnits and result.complete then
                        shocktroopsBoosts=shocktroopsBoosts+1
                    end
                    if selected~=nil and selected.grantUnitResistances and result.complete then
                        allUnitResistances=true
                    end
                    if selected~=nil and selected.attackTransform~=nil and result.complete then
                        attackTransforms[selected.attackTransform]=true
                        transformingUnits[recordKey]=selected.attackTransform
                    end
                    if result.complete then
                        local picked={}
                        if abilities.multi==true then
                            for index,ability in ipairs(abilities) do
                                if decision.selected~=nil and decision.selected[index]==true then
                                    picked[#picked+1]={index=index,ability=ability}
                                end
                            end
                        elseif selected~=nil then
                            picked[1]={index=decision.index,ability=selected}
                        end
                        for _,pickedAbility in ipairs(picked) do
                            local index,ability=pickedAbility.index,pickedAbility.ability
                            if ability.enemyEffect~=nil or ability.targetableEnemy==true then
                                local sourceKey=unitAbilityTargetKey(unitGUID,index,ability,useIndex)
                                if sourceKey~=unitGUID then
                                    result.enemyEffectTargetKeys=result.enemyEffectTargetKeys or {}
                                    result.enemyEffectTargetKeys[#result.enemyEffectTargetKeys+1]=sourceKey
                                end
                                -- Every enemy-targeting Unit ability starts on a nearby
                                -- enemy, even if it is a non-resource/manual effect.
                                -- An explicit retarget wins over the nearest default.
                                -- Keep effect-only arrows separate from the Unit's
                                -- numeric Attack/Block source to prevent stale locks.
                                if ability.enemyEffect~=nil
                                    and ability.enemyEffect.noAttackUnfortified==true then
                                    deferredUnfortifiedUnitEffects[#deferredUnfortifiedUnitEffects+1]={
                                        sourceKey=sourceKey,unit=unit,unitGUID=unitGUID,
                                        result=result,spec=ability.enemyEffect}
                                else
                                    local target=combatEffectChosenEnemy(sourceKey,footprint(unit),
                                        monsters,combatEffectTargetEligible(ability.enemyEffect))
                                    if target~=nil then
                                        if ability.enemyEffect~=nil then
                                            combatEffectAdd(enemyEffects,target.guid,unitGUID,ability.enemyEffect,sourceKey)
                                            result.links[#result.links+1]=target.guid
                                            -- The Unit is spent for Fear rather than
                                            -- its printed ability. Fame requires a legal
                                            -- enemy target; Arcane Immunity negates it.
                                            if ability.bannerFear and not combatEffectImmune(target.guid) then
                                                result.fameRep={fame=1}
                                                result.contributes=true
                                                result.status="purple"
                                                setHighlight(unit,"purple",false)
                                            end
                                        end
                                        if sourceKey~=unitGUID then
                                            result.enemyEffectTargetGUIDs=result.enemyEffectTargetGUIDs or {}
                                            result.enemyEffectTargetGUIDs[sourceKey]=target.guid
                                        end
                                    end
                                end
                            end
                        end
                    end
                    if result.contributes then
                        selectedUnitAttacks[#selectedUnitAttacks+1]=recordKey
                    end
                end
            end
        end -- Earlier-round spent Command: no active source this turn.
       end
      end
    end
    -- Shocktroops' Ranged Attack 1 also boosts ALL other activated Units'
    -- Attacks, even if their ability was activated earlier this turn.
    if shocktroopsBoosts>0 then
        for _,unitGUID in ipairs(selectedUnitAttacks) do
            local record=records[unitGUID]
            local baseGUID=unitHistorySourceBase(unitGUID)
            local use=activationByRecordKey[unitGUID]
            local selected=use~=nil and unitResourceDefinitions[baseGUID]
                and unitResourceDefinitions[baseGUID][use.choice or 1] or nil
            local ownBoost=selected~=nil and selected.boostOtherUnits and 1 or 0
            local bonus=shocktroopsBoosts-ownBoost
            if bonus>0 and record~=nil and record.resources~=nil then
                for category,value in pairs(record.resources) do
                    if type(value)=="number" and (category:sub(1,6)=="attack"
                        or category:sub(1,6)=="ranged"
                        or category:sub(1,5)=="siege") then
                        record.resources[category]=value+bonus
                        totals[category]=(totals[category] or 0)+bonus
                    end
                end
            end
        end
    end
    -- Physical Skill bonuses use the SAME record/totals as the target. Never
    -- add a Skill's printed bonus independently of its activated Unit or card.
    -- Links must create their Skill record before modifying the target; the
    -- final object pass reuses it instead of overwriting or double-counting it.
    local function ensureSkillRecord(skill)
        local record=records[skill.guid]
        if record~=nil then return record end
        local conversion=manaBySkill[skill.guid]
        record=calculateSkill(skill,skillLinksBySkill[skill.guid]
            or (conversion~=nil and conversion.targetGUID or nil),
            unitState,inventoryCrystalCounts)
        addResourceAmounts(record,totals)
        records[skill.guid]=record
        current[skill.guid]=true
        return record
    end
    local function resourceFieldForFamily(resources,family)
        if resources==nil then return nil end
        local found=nil
        for field,amount in pairs(resources) do
            if type(amount)=="number" and amount>0
                and (field==family or field:sub(1,#family)==family) then
                -- Multiple independent elemental abilities need player
                -- disambiguation rather than picking the first pairs() entry.
                if found~=nil then return nil end
                found=field
            end
        end
        return found
    end
    local function skillTargetLinked(skill,target,field,amount,replaceField)
        local skillRecord,targetRecord=ensureSkillRecord(skill),records[target.guid]
        if skillRecord==nil or targetRecord==nil or targetRecord.resources==nil then return end
        -- Cards often return the catalog's immutable basic-effect table.
        -- Never mutate a rule entry by adjusting the live played result.
        local copy={}
        for k,v in pairs(targetRecord.resources) do copy[k]=v end
        targetRecord.resources=copy
        local old=copy[field] or 0
        if replaceField~=nil then
            targetRecord.resources[field]=nil
            totals[field]=(totals[field] or 0)-old
            targetRecord.resources[replaceField]=(targetRecord.resources[replaceField] or 0)+amount
            totals[replaceField]=(totals[replaceField] or 0)+amount
        else
            targetRecord.resources[field]=old+amount
            totals[field]=(totals[field] or 0)+amount
        end
        skillRecord.complete=true
        skillRecord.contributes=true
        skillRecord.powered=true
        skillRecord.status="purple"
        skillRecord.links[#skillRecord.links+1]=target.guid
        targetRecord.links[#targetRecord.links+1]=skill.guid
        if targetRecord.kind~="unit" then targetRecord.status="purple" end
        setHighlight(skill,"purple",true)
        -- Activated Units retain their green/blue highlight; they are not
        -- reclassified purple merely because Leadership enhanced the effect.
        if targetRecord.kind~="unit" then
            setHighlight(target,"purple",targetRecord.powered)
        end
    end
    for _,skill in ipairs(skills) do
        local rule=skillResourceDefinitions[skill.guid]
        if rule~=nil and rule.unitBoost~=nil then
            local choice=chosenEffect(skill.guid,false,rule.choices)
            local family=choice~=nil and choiceCategory(choice) or nil
            if family=="twiceAttack" then family="attack"
            elseif family=="twiceBlock" then family="block" end
            local unitBoost=rule.unitBoost
            if choice~=nil and family~=nil and unitBoost~=nil and unitBoost[family]~=nil then
                local eligible={}
                for unitGUID,activation in pairs(activations) do
                    local unit=objects[unitGUID]
                    local record=records[unitGUID]
                    if activation.seatPos==seatPos and unit~=nil and record~=nil
                        and record.complete==true then
                        local field=resourceFieldForFamily(record.resources,family)
                        local replacement=nil
                        -- Leadership's +1 Ranged/Siege option boosts the
                        -- chosen printed Siege attack if it has no Ranged attack.
                        if field==nil and family=="ranged" and rule.attackPhaseFallback then
                            field=resourceFieldForFamily(record.resources,"siege")
                        end
                        -- Leadership can convert an activated Unit's printed
                        -- Ranged/Siege Attack to ordinary Attack in the regular
                        -- Attack phase. The alternative is +2 Attack, not +1
                        -- Ranged, and the original phase cannot also keep it.
                        if field==nil and family=="attack" and rule.attackPhaseFallback then
                            local ranged=resourceFieldForFamily(record.resources,"ranged")
                            local siege=resourceFieldForFamily(record.resources,"siege")
                            if ranged~=nil and siege==nil then
                                field=ranged
                                replacement="attack"..ranged:sub(7)
                            elseif siege~=nil and ranged==nil then
                                field=siege
                                replacement="attack"..siege:sub(6)
                            end
                        end
                        if field~=nil then
                            eligible[#eligible+1]={unit=unit,field=field,
                                replaceField=replacement,
                                overlap=overlapArea(footprint(skill),footprint(unit))}
                        end
                    end
                end
                table.sort(eligible,function(a,b)
                    if a.overlap~=b.overlap then return a.overlap>b.overlap end
                    return a.unit.guid<b.unit.guid
                end)
                -- One matching activated Unit is unambiguous. With several,
                -- require a physical overlap to indicate the target.
                if #eligible==1 or (#eligible>1 and eligible[1].overlap>0
                    and eligible[1].overlap>eligible[2].overlap) then
                    local chosenUnit=eligible[1]
                    local bonus=choice[family] or unitBoost[family]
                    if chosenUnit.replaceField~=nil then
                        local resources=records[chosenUnit.unit.guid].resources
                        bonus=(resources[chosenUnit.field] or 0)+bonus
                    end
                    skillTargetLinked(skill,chosenUnit.unit,chosenUnit.field,
                        bonus,chosenUnit.replaceField)
                end
            end
        end
    end
    -- Braevalar's Shapeshift: one upright Basic Action with exactly one
    -- fixed Move/Attack/Block resource may switch to either other family.
    -- The target is declared by overlapping the Skill with that card.
    for _,skill in ipairs(skills) do
        local rule=skillResourceDefinitions[skill.guid]
        if rule~=nil and rule.shapeshift then
            local best,bestOverlap=nil,0
            for _,card in ipairs(cards) do
                local data=gameCards[card.guid]
                local record=records[card.guid]
                if data~=nil and data.cardType=="Starting"
                    and card.is_face_down~=true and cardPosture(card)=="upright"
                    and record~=nil and record.resources~=nil then
                    local field=nil
                    local matches=0
                    for category,value in pairs(record.resources) do
                        if type(value)=="number" and value>0 and
                            (category=="move" or category:sub(1,6)=="attack"
                                or category:sub(1,5)=="block") then
                            field=category
                            matches=matches+1
                        end
                    end
                    if matches==1 then
                        local area=overlapArea(footprints[skill.guid],footprints[card.guid])
                        if area>bestOverlap then
                            best,bestOverlap={card=card,field=field},area
                        end
                    end
                end
            end
            local sourceField=best~=nil and best.field or nil
            if best~=nil and sourceField~=nil then
                local sourceFamily=sourceField=="move" and "move"
                    or (sourceField:sub(1,6)=="attack" and "attack" or "block")
                local suffix=sourceField:sub(#sourceFamily+1)
                local choices={}
                for _,family in ipairs({"move","block","attack"}) do
                    if family~=sourceFamily then
                        local field=family=="move" and "move" or family..suffix
                        choices[#choices+1]={key=family,icon=family,[field]=0}
                    end
                end
                local result=records[skill.guid]
                if result~=nil then
                    result.choices=choices
                    showChoiceButtons(skill,choices,false)
                end
                local selected=chosenEffect(skill.guid,false,choices)
                if selected~=nil then
                    local family=choiceCategory(selected)
                    local newField=family=="move" and "move" or family..suffix
                    local original=records[best.card.guid].resources[sourceField]
                    skillTargetLinked(skill,best.card,sourceField,original,newField)
                end
            end
        end
    end
    -- Coral's If It's Not Broken: a sideways card on the Skill copies a
    -- previously played Action's BASIC effect of the same colour. We only
    -- infer a result with one fixed numeric resource and one clear source.
    -- No inferred play order, extra payments, or invented source card.
    for _,skill in ipairs(skills) do
        local skillRule=skillResourceDefinitions[skill.guid]
        if skillRule~=nil and skillRule.copyBasicAction then
            local sideways,bestOverlap=nil,0
            for _,card in ipairs(cards) do
                local record=records[card.guid]
                if cardPosture(card)=="sideways" and record~=nil
                    and record.resources~=nil
                    and skillLinksByTarget[card.guid]==nil then
                    local area=overlapArea(footprints[skill.guid],footprints[card.guid])
                    if area>bestOverlap then sideways,bestOverlap=card,area end
                end
            end
            if sideways~=nil then
                local sidewaysData=gameCards[sideways.guid]
                local sideIsArtifact=sidewaysData~=nil
                    and sidewaysData.cardType=="Artifact"
                local candidates={}
                for _,source in ipairs(cards) do
                    local data=gameCards[source.guid]
                    -- Card colours are stored as separate tables; compare their
                    -- entries rather than table identity, including dual colours.
                    local sameColour=false
                    if sidewaysData~=nil then
                        local colours=sidewaysData.color
                        if type(colours)=="string" then
                            sameColour=matchingSidewaysMana(source,colours)
                        elseif type(colours)=="table" then
                            for _,colour in ipairs(colours) do
                                if matchingSidewaysMana(source,colour) then
                                    sameColour=true
                                    break
                                end
                            end
                        end
                    end
                    if source.guid~=sideways.guid and data~=nil
                        and (data.cardType=="Starting" or data.cardType=="Advanced Action")
                        and cardPosture(source)=="upright" and source.is_face_down~=true
                        and (sideIsArtifact or sameColour) then
                        local definition=cardResourceDefinitions[data.resourceKey]
                        if definition~=nil and definition.requiredLink==nil
                            and definition.woundBonus==nil and definition.partial~=true then
                            local base=definition.normalChoices~=nil
                                and chosenEffect(source.guid,false,definition.normalChoices)
                                or definition.normal
                            local srcField,srcValue,count=nil,nil,0
                            for key,value in pairs(base or {}) do
                                if trackerPrivate.totalsKeys[key] and type(value)=="number" and value>0 then
                                    srcField,srcValue,count=key,value,count+1
                                end
                            end
                            if count==1 then
                                candidates[#candidates+1]={source=source,field=srcField,
                                    value=srcValue,overlap=overlapArea(footprints[sideways.guid],
                                        footprints[source.guid])}
                            end
                        end
                    end
                end
                table.sort(candidates,function(a,b)
                    if a.overlap~=b.overlap then return a.overlap>b.overlap end
                    return a.source.guid<b.source.guid
                end)
                if #candidates==1 or (#candidates>1 and candidates[1].overlap>0
                    and candidates[1].overlap>candidates[2].overlap) then
                    local original=records[sideways.guid]
                    local oldField,oldCount=nil,0
                    for key,value in pairs(original.resources) do
                        if trackerPrivate.totalsKeys[key] and type(value)=="number" and value>0 then
                            oldField,oldCount=key,oldCount+1
                        end
                    end
                    if oldCount==1 then
                        local chosen=candidates[1]
                        skillTargetLinked(skill,sideways,oldField,chosen.value,chosen.field)
                        local origin=records[chosen.source.guid]
                        local skillRecord=records[skill.guid]
                        if origin~=nil and skillRecord~=nil then
                            origin.links[#origin.links+1]=skill.guid
                            skillRecord.links[#skillRecord.links+1]=chosen.source.guid
                            origin.status="purple"
                            setHighlight(chosen.source,"purple",origin.powered)
                        end
                        -- The sideways generic Move/Attack/Block button no
                        -- longer describes its copied basic effect.
                        showChoiceButtons(sideways,nil,false)
                    end
                end
            end
        end
    end
    -- Build Know Your Prey's choices from the printed traits and attack slots
    -- of its currently selected target. Never offer site-granted abilities.
    combatConfig.preyChoices=function(enemyGUID)
        local choices={}
        local enemy=enemyGUID~=nil and monsters[enemyGUID] or nil
        local data=enemy~=nil and combatEnemyData(enemyGUID,enemy) or nil
        if data==nil then return {{key="preyNone",icon="other",iconOverlay="?"}} end
        for _,trait in ipairs({"swiftness","brutal","poison","paralyse","assassination",
            "cumbersome","vampiric","fortified","elusive",
            "pResist","fResist","iResist","mResist","defend"}) do
            if data[trait]==true or (trait=="defend" and (tonumber(data.defend) or 0)>0) then
                local key="prey"..trait:sub(1,1):upper()..trait:sub(2)
                choiceLetters[key]="X"
                choices[#choices+1]={key=key,icon="other",iconOverlay="X",
                    tooltip="Know Your Prey: ignore the enemy token's printed "..trait,
                    preySpec={removeTrait=trait}}
            end
        end
        for _,attack in ipairs(combatEnemyPrintedAttacks(data,
            gStates~=nil and gStates.monsterPerks and gStates.monsterPerks[enemyGUID] or nil,
            false,enemyGUID)) do
            local destinations=attack.key=="IF" and {"F","I"}
                or (attack.key=="F" or attack.key=="I") and {"P"} or {}
            for _,to in ipairs(destinations) do
                local key="preyA"..tostring(attack.slot)..to
                choiceLetters[key]="→"
                choices[#choices+1]={key=key,icon="other",iconOverlay=to,
                    tooltip="Know Your Prey: attack "..tostring(attack.slot).." "..attack.key.." → "..to,
                    preySpec={convertAttack={slot=attack.slot,from=attack.key,to=to}}}
            end
        end
        if #choices==0 then
            choices={{key="preyNone",icon="other",iconOverlay="?"}}
        end
        return choices
    end
    -- Skills that act on one enemy use the same nearest-enemy targeting as cards.
    -- This pass precedes the final object pass. Register enemy-effect Skills
    -- now so their chosen effects, targets and arrows survive the next scan.
    for _,skill in ipairs(skills) do
        local rule=skillResourceDefinitions[skill.guid]
        if rule~=nil and rule.enemyEffect~=nil then
            local record=ensureSkillRecord(skill)
            local choice=rule.choices~=nil and chosenEffect(skill.guid,false,rule.choices) or nil
            local spec=combatEffectSpec(rule,false,choice~=nil and choiceCategory(choice) or nil)
            if rule.prey then
                local eligible=function(enemy,guid)
                    local data=combatEnemyData(guid,enemy)
                    local perks=gStates~=nil and gStates.monsterPerks and gStates.monsterPerks[guid] or nil
                    return data~=nil and data.attackOnly~=true and data.arcaneImmunity~=true
                        and (perks==nil or perks.arcaneImmunity~=true)
                end
                local target=combatEffectChosenEnemy(skill.guid,footprints[skill.guid],monsters,eligible)
                local options=combatConfig.preyChoices(target~=nil and target.guid or nil)
                record.choices=options
                record.enemyEffectTargetKeys={skill.guid}
                local selected=chosenEffect(skill.guid,false,options)
                spec=selected~=nil and selected.preySpec or nil
                if target~=nil and spec~=nil then
                    combatEffectAdd(enemyEffects,target.guid,skill.guid,spec)
                    record.enemyGUID=target.guid
                    record.links[#record.links+1]=target.guid
                    record.status="purple"
                    record.complete=true
                    record.enemyEffectTargetGUIDs={[skill.guid]=target.guid}
                else
                    record.status="yellow"
                    record.complete=false
                end
            end
            -- Curse must remain an active effect-only target source while the
            -- player is choosing a new enemy; otherwise a rescan can erase
            -- the purple preview arrow before the target click is applied.
            if spec~=nil and not spec.all then
                record.enemyEffectTargetKeys={skill.guid}
            end
            if skill.guid=="6a33c1" and spec~=nil and spec.armourReduce~=nil then
                -- Switching from Attack -1 to Armour -1 invalidates a saved
                -- reminder target. Keep legitimate enemy locks untouched.
                local eligible={}
                for guid,enemy in pairs(monsters) do
                    local data=combatEnemyData(guid,enemy)
                    if enemy.is_face_down~=true and data~=nil and data.attackOnly~=true then
                        eligible[guid]=true
                    end
                end
                attackAssignmentsPruneSourceTargets(skill.guid,eligible)
                local locked=combatAssignmentState.targets[skill.guid]
                if locked~=nil and eligible[locked]~=true then
                    combatAssignmentState.targets[skill.guid]=nil
                    combatAssignmentState.explicit[skill.guid]=nil
                end
            end
            local eligible=nil
            if skill.guid=="4ac9f6" or skill.guid=="19daf9" then
                eligible=function(enemy,guid)
                    local data=combatEnemyData(guid,enemy)
                    return data~=nil and data.monsters==nil
                end
            end
            if skill.guid=="6a33c1" and spec~=nil and spec.armourReduce~=nil then
                eligible=function(enemy,guid)
                    local data=combatEnemyData(guid,enemy)
                    return data~=nil and data.attackOnly~=true
                end
            end
            local target=not rule.prey and spec~=nil and combatEffectChosenEnemy(
                skill.guid,footprints[skill.guid],monsters,
                eligible or combatEffectTargetEligible(spec)) or nil
            if spec~=nil and target~=nil then
                combatEffectAdd(enemyEffects,target.guid,skill.guid,spec)
                record.enemyGUID=target.guid
                record.links[#record.links+1]=target.guid
                record.status="purple"
                if not spec.all then
                    record.enemyEffectTargetKeys={skill.guid}
                    record.enemyEffectTargetGUIDs={[skill.guid]=target.guid}
                end
            end
        end
    end
    -- The cooperating player's Howl of the Pack use is claimed through the
    -- existing shared-skill lifecycle and persists after its token is returned.
    local pack=gStates~=nil and gStates.wolfhawkPackUse or nil
    if pack~=nil and pack.recipient==gStates.turnNumber
        and pack.round==gStates.currentRound then
        local key="564392"
        local spec={attackReduce=1,armourReduce=1}
        local anchor=getObjectFromGUID(key)
        local fallback=nil
        for _,enemy in pairs(monsters) do fallback=enemy break end
        local area=anchor~=nil and footprint(anchor)
            or fallback~=nil and footprint(fallback) or nil
        local record=records[key] or {guid=key,kind="skill",known=true,
            resources=nil,status="yellow",powered=false,complete=false,links={}}
        record.enemyEffectTargetKeys={key}
        records[key]=record
        current[key]=true
        if area~=nil then
            local target=combatEffectChosenEnemy(key,area,monsters,
                combatEffectTargetEligible(spec))
            if target~=nil then
                combatEffectAdd(enemyEffects,target.guid,key,spec)
                record.enemyGUID=target.guid
                record.links[#record.links+1]=target.guid
                record.status="purple"
                record.complete=true
                record.enemyEffectTargetGUIDs={[key]=target.guid}
            end
        end
    end
    -- A claimed cooperative Nature's Vengeance remains playable after the
    -- recipient hands the physical Skill back to its owner. Keep its target
    -- source and one enemy reduction through the recipient's turn only.
    local vengeance=gStates~=nil and gStates.braevalarVengeanceUse or nil
    if vengeance~=nil and vengeance.recipient==gStates.turnNumber
        and vengeance.round==gStates.currentRound then
        local key="4ac9f6"
        local spec={attackReduce=1,grantCumbersome=true}
        local anchor=getObjectFromGUID(key)
        local fallback=nil
        for _,enemy in pairs(monsters) do fallback=enemy break end
        local area=anchor~=nil and footprint(anchor)
            or fallback~=nil and footprint(fallback) or nil
        local record=records[key] or {guid=key,kind="skill",known=true,
            resources=nil,status="yellow",powered=false,complete=false,links={}}
        record.enemyEffectTargetKeys={key}
        records[key]=record
        current[key]=true
        if area~=nil then
            local target=combatEffectChosenEnemy(key,area,monsters,
                function(enemy,guid)
                    local data=combatEnemyData(guid,enemy)
                    return data~=nil and data.monsters==nil
                end)
            if target~=nil then
                combatEffectAdd(enemyEffects,target.guid,key,spec)
                record.enemyGUID=target.guid
                record.links[#record.links+1]=target.guid
                record.status="purple"
                record.complete=true
                record.enemyEffectTargetGUIDs={[key]=target.guid}
            end
        end
    end
    -- Battle Hardened protects the Hero from one selected enemy attack,
    -- rather than reducing the enemy's printed Attack or Block requirement.
    -- Unlike Curse it only activates after the player targets an enemy.
    for _,skill in ipairs(skills) do
        local rule=skillResourceDefinitions[skill.guid]
        if rule~=nil and rule.damageMitigation~=nil then
            local record=ensureSkillRecord(skill)
            -- Advertise the effect-only source even before the first target
            -- click. Otherwise an immediate calculator refresh prunes its new
            -- arrow before the pending Skill scan can apply the mitigation.
            record.enemyEffectTargetKeys={skill.guid}
            local targetGUID=combatAssignmentState.targets[skill.guid]
            if targetGUID==nil then
                for guid in pairs(attackAssignmentsTargetGUIDs(skill.guid)) do
                    if combatMonsters[guid]~=nil then targetGUID=guid break end
                end
            end
            local target=targetGUID~=nil and combatMonsters[targetGUID] or nil
            if target~=nil and target.is_face_down~=true then
                record.enemyGUID=targetGUID
                record.links[#record.links+1]=targetGUID
                record.status="purple"
                record.complete=true
                record.enemyEffectTargetKeys={skill.guid}
                record.enemyEffectTargetGUIDs={[skill.guid]=targetGUID}
            end
        end
    end
    -- Deadly Aim adds to one physically linked card's actual Attack element,
    -- never to Units or a guessed attack phase.
    for _,skill in ipairs(skills) do
        local rule=skillResourceDefinitions[skill.guid]
        if rule~=nil and rule.attackCardBoost then
            local best,bestOverlap=nil,0
            local targets={}
            for _,card in ipairs(cards) do targets[#targets+1]=card end
            -- Power of Pain / Ritual of Pain can make a sideways Wound a real
            -- Attack source. Deadly Aim may boost it, but never a plain Wound.
            for _,wound in ipairs(wounds) do
                if records[wound.guid]~=nil
                    and records[wound.guid].resources~=nil then
                    targets[#targets+1]=wound
                end
            end
            for _,card in ipairs(targets) do
                if card.is_face_down~=true then
                    local record=records[card.guid]
                    if record~=nil then
                        local chosenField=nil
                        local amount=nil
                        for _,family in ipairs({"ranged","siege","attack"}) do
                            local field=resourceFieldForFamily(record.resources,family)
                            if field~=nil then
                                if chosenField~=nil then chosenField=nil break end
                                chosenField=field
                                amount=family=="attack" and 2 or 1
                            end
                        end
                        local area=overlapArea(footprints[skill.guid],footprints[card.guid])
                        if chosenField~=nil and area>bestOverlap then
                            best,bestOverlap={card=card,field=chosenField,amount=amount},area
                        end
                    end
                end
            end
            if best~=nil then
                skillTargetLinked(skill,best.card,best.field,best.amount)
            end
        end
    end
    -- Tovak's Mana Overload: marker mana on the Skill identifies the color,
    -- but only a DIFFERENT mana which actually powers a Deed card's strong
    -- side may trigger +4. Casting/option-selection payments do not qualify.
    -- Cards granting multiple resources provide separate Skill options.
    for _,skill in ipairs(skills) do
        local rule=skillResourceDefinitions[skill.guid]
        if rule~=nil and rule.manaOverload then
            local colors={}
            local skillArea=footprints[skill.guid]
            for _,mana in ipairs(manaObjects) do
                if placements[mana.guid]=="play" and usedMana[mana.guid]==nil
                    and manaInsideFootprint(mana,skillArea) then
                    local color=manaColor(mana)
                    if color~=nil and color~="Gold" then colors[color]=true end
                end
            end
            local candidates={}
            if next(colors)~=nil then
                for _,card in ipairs(cards) do
                    local data=gameCards[card.guid]
                    local target=records[card.guid]
                    if data~=nil and (data.cardType=="Starting"
                            or data.cardType=="Advanced Action"
                            or data.cardType=="Spell" or data.cardType=="Artifact")
                        and powered[card.guid]==true
                        and card.is_face_down~=true and cardPosture(card)=="upright"
                        and target~=nil and target.resources~=nil then
                        local powerColors=powerManaColorsByCard[card.guid] or {}
                        local definition=cardResourceDefinitions[data.resourceKey]
                        if definition~=nil and definition.effectManaChoice~=nil then
                            -- The chosen strong-side effect needs its own
                            -- physical selection payment, and (for Spells)
                            -- an independent casting payment as well.
                            -- calculateCard returns resources but deliberately does
                            -- not persist the UI choices in its record. Rebuild
                            -- the same paid strong-side choices used above.
                            local available=paidManaChoices(card.guid,definition,true,nil)
                            local _,selected=currentChoice(card.guid,true,available)
                            powerColors=effectManaPowerColors(definition.effectManaChoice,
                                effectManaByCard[card.guid],resourceCardsGoldAllowed(),
                                resourceCardsBlackAllowed(),selected)
                        end
                        local matching=false
                        for color in pairs(colors) do
                            if powerColors[color]==true
                                or (powerColors.Gold==true and resourceCardsGoldAllowed()
                                    and matchesCardMana(card,color)) then
                                matching=true
                                break
                            end
                        end
                        if matching then
                            local fields={}
                            for _,family in ipairs({"move","siege","ranged","block","attack","influence"}) do
                                local byFamily={}
                                for field,amount in pairs(target.resources) do
                                    if type(amount)=="number" and amount>0
                                        and (field==family or field:sub(1,#family)==family) then
                                        byFamily[#byFamily+1]=field
                                    end
                                end
                                table.sort(byFamily)
                                for _,field in ipairs(byFamily) do
                                    fields[#fields+1]={field=field,family=family}
                                end
                            end
                            if #fields>0 then
                                candidates[#candidates+1]={card=card,fields=fields,
                                    overlap=overlapArea(skillArea,footprints[card.guid])}
                            end
                        end
                    end
                end
            end
            table.sort(candidates,function(a,b)
                if a.overlap~=b.overlap then return a.overlap>b.overlap end
                return a.card.guid<b.card.guid
            end)
            if #candidates==1 or (#candidates>1 and candidates[1].overlap>0
                and candidates[1].overlap>candidates[2].overlap) then
                local chosen=candidates[1]
                local options,fieldByKey={},{}
                for _,fieldInfo in ipairs(chosen.fields) do
                    local field,family=fieldInfo.field,fieldInfo.family
                    local key="overload_"..field
                    local element=field:sub(#family+1)
                    local choice={key=key,icon=family,[field]=0}
                    if element=="Fire" then choice.iconOverlay="F"
                    elseif element=="Ice" then choice.iconOverlay="I"
                    elseif element=="ColdFire" then choice.iconOverlay="C"
                    elseif element=="Psychic" then choice.iconOverlay="P" end
                    choiceLetters[key]=choiceLetters[family] or "O"
                    options[#options+1]=choice
                    fieldByKey[key]=field
                end
                local skillRecord=ensureSkillRecord(skill)
                skillRecord.choices=options
                local _,selected=currentChoice(skill.guid,false,options)
                local field=fieldByKey[selected]
                if field~=nil then skillTargetLinked(skill,chosen.card,field,4) end
            end
        end
    end
    -- This scan has just granted Cumbersome to a target: show Move-target
    -- buttons immediately, without requiring the player to close/reopen the tracker.
    for _,effect in pairs(enemyEffects) do
        if effect.grantCumbersome==true then combatCumbersomeActive=true break end
    end

    -- The linking card itself contributes the target's upgraded effect. Mark it
    -- as a contributor so its powering mana token receives a green outline.
    for targetGUID,sourceGUID in pairs(boostSource) do
        if records[targetGUID]~=nil and records[targetGUID].contributes
            and records[sourceGUID]~=nil then
            records[sourceGUID].contributes=true
        end
    end

    for guid,obj in pairs(objects) do
        -- No contribution or outline for a Wound without a matching Skill.
        -- Previously linked Skills need their button/highlight finalization
        -- even though their resource record was created before target bonuses.
        local kind=resourceObjectKind(obj)
        if (records[guid]==nil or (kind=="skill" and placements[guid]=="play"))
            and kind~="wound" then
            local poweredTarget=usedMana[guid]
            local contributing=poweredTarget~=nil and records[poweredTarget]~=nil
                and records[poweredTarget].contributes==true
            local result
            if kind=="puppet" and (placements[guid]=="play" or placements[guid]=="unit") then
                local choices=obj.is_face_down~=true and puppetResourceOptions(guid) or nil
                local selected=choices~=nil and chosenEffect(guid,false,choices) or nil
                result={guid=guid,kind="puppet",known=true,complete=selected~=nil,
                    status=selected~=nil and "green" or "blue",
                    resources=selected,choices=choices,powered=false,links={}}
                showChoiceButtons(obj,choices,false)
                addResourceAmounts(result,totals)
            elseif kind=="skill" and placements[guid]=="play" then
                local conversion=manaBySkill[guid]
                local alreadyRecorded=records[guid]~=nil
                result=alreadyRecorded and records[guid]
                    or calculateSkill(obj,skillLinksBySkill[guid]
                        or (conversion~=nil and conversion.targetGUID or nil),
                        unitState,inventoryCrystalCounts)
                local skillRule=skillResourceDefinitions[guid]
                if skillRule~=nil then
                    if skillRule.locationInfluence~=nil
                        or skillRule.day~=nil or skillRule.night~=nil then
                        usesSkillLocation=true
                    end
                    -- Played Skill movement flags are declarative, just like
                    -- equivalent printed Action/Spell effects.
                    local spec=skillRule.movementEffects
                    local effects=spec~=nil
                        and (obj.is_face_down==true and spec.flipped or spec.normal) or nil
                    if effects~=nil then
                        if effects.jumpTwoSpaces then movementEffects.jumpTwoSpaces=true end
                        if effects.ignoreRampagers then movementEffects.ignoreRampagers=true end
                    end
                end
                showChoiceButtons(obj,result.choices,result.powered)
                if not alreadyRecorded then addResourceAmounts(result,totals) end
                if skillLinksBySkill[guid]~=nil then
                    result.contributes=true
                    local link=skillLinksByTarget[skillLinksBySkill[guid]]
                    if link~=nil and link.manaGUID~=nil then
                        result.links[#result.links+1]=link.manaGUID
                    end
                end
                if conversion~=nil then
                    result.status="purple"
                    result.powered=conversion.targetGUID~=nil
                    result.links={conversion.manaGUID}
                    if conversion.targetGUID~=nil then
                        result.links[#result.links+1]=conversion.targetGUID
                        local target=records[conversion.targetGUID]
                        result.contributes=target~=nil and target.contributes==true
                    end
                end
            else
                local conversion=kind=="mana" and manaByObject[guid] or nil
                local sidewaysLink=kind=="mana" and sidewaysSkillMana[guid] or nil
                local extraTerrainTarget=kind=="mana" and extraTerrainManaByObject[guid] or nil
                local skillContributes=sidewaysLink~=nil
                    and records[sidewaysLink.targetGUID]~=nil
                    and records[sidewaysLink.targetGUID].contributes==true
                local status=(conversion~=nil or sidewaysLink~=nil or extraTerrainTarget~=nil) and "purple"
                    or kind=="mana" and (contributing and "green" or "yellow") or "yellow"
                local bright=kind=="mana" and (poweredTarget~=nil or sidewaysLink~=nil)
                result={guid=guid,kind=kind,known=true,complete=false,
                    contributes=contributing or skillContributes,powered=bright,status=status,
                    powers=poweredTarget or (sidewaysLink~=nil and sidewaysLink.targetGUID or nil),
                    links=conversion~=nil and {conversion.skillGUID}
                        or sidewaysLink~=nil and {sidewaysLink.skillGUID,sidewaysLink.targetGUID}
                        or extraTerrainTarget~=nil and {extraTerrainTarget} or {},
                    convertedMana=conversion~=nil and conversion.converted or nil,
                    resources=nil}
            end
            records[guid]=result
            current[guid]=true
            setHighlight(obj,result.status,result.powered)
        end
    end


    -- Aura Gauntlet can only choose colours currently showing on physical
    -- Mana Source dice (not spent dice or mirror copies).
    local sourceRewardColors={}
    for _,die in ipairs(gStates.manaSource or {}) do
        local color=({[1]="blue",[2]="white",[3]="green",[4]="red"})[die.color]
        if color~=nil then sourceRewardColors[color]=true end
    end

    -- A Faction Reward is available only after the player actually places it
    -- in the Play Area. Face-down is the alternative interaction exchange:
    -- choose +3 Influence or 1 Fame (Fame itself is not a Tracker column).
    -- Do not infer its effect from being stored face-up in inventory.
    local exchangeChoices={{key="fame"},{influence=3}}
    for guid,token in pairs(objects) do
        if resourceObjectKind(token)=="factionReward" and placements[guid]=="play" then
            local rule=factionRewardForObject(token)
            local flipped=token.is_face_down==true
            local choices=flipped and exchangeChoices or (rule~=nil and rule.choices or nil)
            if not flipped and rule~=nil and rule.name=="Aura Gauntlet" then
                local available={}
                for _,choice in ipairs(choices or {}) do
                    if sourceRewardColors[choice.key] then available[#available+1]=choice end
                end
                choices=available
            end
            local effect=choices~=nil and chosenEffect(guid,flipped,choices) or nil
            if effect==nil and not flipped and rule~=nil then effect=rule.resources end
            local contributes=effectHasTrackedResource(effect)
            local result={guid=guid,kind="factionReward",known=rule~=nil,
                complete=rule~=nil,resources=effect,choices=choices,
                modifier=not flipped and rule~=nil and rule.modifier or nil,
                powered=flipped,links={},contributes=contributes,
                status=contributes and "green" or "blue",
                nameKey=rule~=nil and rule.name or nil}
            if rule~=nil and not flipped and (rule.partial or rule.modifier~=nil) then
                result.status="yellow"
            end
            if not flipped and rule~=nil and rule.movement~=nil
                and rule.movement.ignoreRampagers then
                movementEffects.ignoreRampagers=true
            end
            if not flipped and rule~=nil and rule.heroPsychicBlock==true then
                heroPsychicBlock=true
            end
            if not flipped and rule~=nil and rule.enemyEffect~=nil then
                local target=combatEffectChosenEnemy(guid,footprint(token),monsters,
                    combatEffectTargetEligible(rule.enemyEffect))
                if target~=nil then
                    combatEffectAdd(enemyEffects,target.guid,guid,rule.enemyEffect)
                    result.enemyEffectTargetKeys={guid}
                    result.enemyEffectTargetGUIDs={[guid]=target.guid}
                    result.links[#result.links+1]=target.guid
                    result.status="purple"
                end
            end
            showChoiceButtons(token,choices,flipped)
            addResourceAmounts(result,totals)
            records[guid]=result
            current[guid]=true
            setHighlight(token,result.status,result.powered)
        end
    end

    -- Illusionists: now that every independent enemy effect has been read,
    -- evaluate *effective* Fortification rather than the printed token alone.
    -- Reevaluate legal locks each scan so an expired Remove Fortification
    -- effect cannot leave an invalid target or a misleading attack arrow.
    for _,pending in ipairs(deferredUnfortifiedUnitEffects) do
        local eligible={}
        for guid,enemy in pairs(monsters) do
            if enemy.is_face_down~=true
                and resourceCardsEnemyEffectivelyUnfortified(guid,enemyEffects,
                    ignoreSiteFortifications) then
                eligible[guid]=true
            end
        end
        attackAssignmentsPruneSourceTargets(pending.sourceKey,eligible)
        local locked=combatAssignmentState.targets[pending.sourceKey]
        if locked~=nil and eligible[locked]~=true then
            combatAssignmentState.targets[pending.sourceKey]=nil
            combatAssignmentState.explicit[pending.sourceKey]=nil
        end
        local target=combatEffectChosenEnemy(pending.sourceKey,footprint(pending.unit),
            monsters,function(_,guid) return eligible[guid]==true end)
        if target~=nil then
            combatEffectAdd(enemyEffects,target.guid,pending.unitGUID,pending.spec,pending.sourceKey)
            pending.result.links[#pending.result.links+1]=target.guid
            pending.result.enemyEffectTargetGUIDs=pending.result.enemyEffectTargetGUIDs or {}
            pending.result.enemyEffectTargetGUIDs[pending.sourceKey]=target.guid
        end
    end

    -- Qualifying Units actually supplied the dynamic Skill resource. Show
    -- their link just like physical Skill/card interactions, without treating
    -- Command or Wound markers as resource sources themselves.
    for guid,record in pairs(records) do
        if record.unitSources~=nil then
            for _,unitGUID in ipairs(record.unitSources) do
                local unit,unitRecord=objects[unitGUID],records[unitGUID]
                if unit~=nil and unitRecord~=nil then
                    local activated=activations[unitGUID]~=nil
                        and activations[unitGUID].seatPos==seatPos
                        and unitResourceDefinitions[unitGUID]~=nil
                    -- Linked Skill sources normally show purple, but a Unit
                    -- currently activated by its Command token keeps its
                    -- own green/blue Resource Tracker status.
                    unitRecord.status=activated
                        and (effectHasTrackedResource(unitRecord.resources) and "green" or "blue")
                        or "purple"
                    unitRecord.powered=not activated
                    unitRecord.contributes=true
                    unitRecord.links[#unitRecord.links+1]=guid
                    setHighlight(unit,unitRecord.status,unitRecord.powered)
                end
            end
        end
    end

    -- Physical faction reward overlays. Place the token on its target:
    -- gems convert one Action card's Attack/Block element; Ghostly Elixir
    -- changes one melee Attack to Ranged; Vial of Toxin boosts one physical
    -- Attack source. Nothing is awarded for a missing or ambiguous target.
    local function rewardConversion(mode,category)
        if mode=="makeRanged" then
            return ({attack="ranged",attackFire="rangedFire",
                attackIce="rangedIce",attackColdFire="rangedColdFire"})[category]
        end
        local family,suffix=category:match("^(attack)(.*)$")
        if family==nil then family,suffix=category:match("^(ranged)(.*)$") end
        if family==nil then family,suffix=category:match("^(siege)(.*)$") end
        if family==nil then family,suffix=category:match("^(block)(.*)$") end
        if family==nil then return nil end
        if mode=="addFire" then
            if suffix=="" then return family.."Fire" end
            if suffix=="Ice" then return family.."ColdFire" end
        elseif mode=="addIce" then
            if suffix=="" then return family.."Ice" end
            if suffix=="Fire" then return family.."ColdFire" end
        end
        return nil
    end
    -- Resolve element conversions before the toxin. Toxin's extra physical
    -- Attack must vanish if a Gem subsequently makes that attack elemental.
    for _,mode in ipairs({"makeRanged","addFire","addIce","physicalBoost"}) do
        for rewardGUID,reward in pairs(records) do
            local token=reward.kind=="factionReward" and reward.modifier==mode
                and objects[rewardGUID] or nil
            if token~=nil then
                local winner,selected,bestArea=nil,nil,0
                -- Inline record type avoids a duplicate global class declaration in the generated TTS bundle.
                ---@type {resources: table<string, number>?, links: string[], status: string, powered: boolean}|nil
                local sourceRecord=nil
                local tokenArea=footprint(token)
                for sourceGUID,candidate in pairs(objects) do
                    local data=gameCards[sourceGUID]
                    local action=data~=nil and (data.cardType=="Starting"
                        or data.cardType=="Advanced Action")
                    local unit=mode=="physicalBoost" and data~=nil
                        and (data.cardType=="Regular Unit" or data.cardType=="Elite Unit")
                    local record=records[sourceGUID]
                    if sourceGUID~=rewardGUID and (action or unit) and record~=nil
                        and record.contributes==true and record.resources~=nil
                        and (unit or (candidate.is_face_down~=true
                            and cardPosture(candidate)=="upright")) then
                        local overlap=overlapArea(tokenArea,footprint(candidate))
                        if overlap>bestArea then
                            local possible={}
                            for field,amount in pairs(record.resources) do
                                if type(amount)=="number" and amount>0 then
                                    local to=rewardConversion(mode,field)
                                    if mode=="physicalBoost" then
                                        -- Only the source's current physical
                                        -- category qualifies for Vial of Toxin.
                                        if not attackTransforms.coldFire
                                            and (field=="attack" or field=="ranged"
                                                or field=="siege") then to=field
                                        else to=nil end
                                    end
                                    if to~=nil then
                                        possible[#possible+1]={from=field,to=to}
                                    end
                                end
                            end
                            if #possible==1 then
                                winner,sourceRecord,selected,bestArea=
                                    candidate,record,possible[1],overlap
                            end
                        end
                    end
                end
                if winner~=nil and sourceRecord~=nil and selected~=nil then
                    local from,to=selected.from,selected.to
                    if mode=="physicalBoost" then
                        local effectiveFamily=attackTransforms.siege and "siege" or from
                        local bonus=effectiveFamily=="siege" and 1
                            or (effectiveFamily=="ranged" and 2 or 3)
                        reward.resources={[from]=bonus}
                        addResourceAmounts(reward,totals)
                    else
                        -- Never mutate the declarative global resource data,
                        -- which can be reused by another identical card.
                        if sourceRecord.resources==nil then
                            error("The linked resource source has no resource values.",2)
                        end
                        local newResources={}
                        for k,v in pairs(sourceRecord.resources) do newResources[k]=v end
                        local amount=newResources[from]
                        if type(amount)~="number" then
                            error("The linked resource source is missing its selected value.",2)
                        end
                        newResources[from]=nil
                        newResources[to]=(newResources[to] or 0)+amount
                        sourceRecord.resources=newResources
                        totals[from]=(totals[from] or 0)-amount
                        totals[to]=(totals[to] or 0)+amount
                        reward.contributes=true
                    end
                    if reward.links==nil or sourceRecord.links==nil then
                        error("A linked resource record has no link list.",2)
                    end
                    reward.links[#reward.links+1]=winner.guid
                    sourceRecord.links[#sourceRecord.links+1]=rewardGUID
                    reward.status="purple"
                    sourceRecord.status="purple"
                    setHighlight(token,reward.status,true)
                    setHighlight(winner,sourceRecord.status,sourceRecord.powered)
                end
            end
        end
    end

    -- Global Altem effects contribute when they upgrade an Attack, including
    -- a value entered manually into the Resource Tracker.
    local tracker=gStates.resourceTracker or {}
    for sourceKey,mode in pairs(transformingUnits) do
        local affected=false
        for _,family in ipairs(trackerPrivate.attackTransformFamilies) do
            for _,field in ipairs(trackerPrivate.attackTransformFields) do
                if (mode=="coldFire" and field~="iceFire")
                    or (mode=="siege" and family~="siege") then
                    if resourceCardsRawValue(tracker,totals,family,field)~=0 then
                        affected=true
                        break
                    end
                end
            end
            if affected then break end
        end
        local record=records[sourceKey]
        if record~=nil then
            record.contributes=affected
            record.status=affected and "green" or "blue"
            local unitGUID=unitHistorySourceBase(sourceKey)
            -- Only the Command's displayed use owns the physical highlight;
            -- earlier uses retain their own record for History and Undo.
            if unitHistorySelectedNumber(unitGUID)==record.activationIndex then
                setHighlight(objects[unitGUID],record.status,false)
            end
        end
    end


    -- Spirit Guides adds its Block point to ONE existing Block source,
    -- regardless of physical distance. Preserve the source's element, and
    -- never add the bonus before the target actually generates Block.
    local guideGUID="f36762"
    local guide=records[guideGUID]
    local linkedGUID=guide~=nil and gStates.blockSourceLinks~=nil
        and gStates.blockSourceLinks[guideGUID] or nil
    local boosted=linkedGUID~=nil and records[linkedGUID] or nil
    if boosted~=nil and boosted.contributes==true and boosted.resources~=nil then
        local bestKey,bestValue=nil,0
        for _,field in ipairs(combatConfig.spiritGuideBlockFields) do
            local value=tonumber(boosted.resources[field]) or 0
            if value>bestValue then bestKey,bestValue=field,value end
        end
        if bestKey~=nil then
            local replacement={}
            for key,value in pairs(boosted.resources) do replacement[key]=value end
            replacement[bestKey]=replacement[bestKey]+1
            boosted.resources=replacement
            totals[bestKey]=(totals[bestKey] or 0)+1
            guide.links[#guide.links+1]=linkedGUID
            boosted.links=boosted.links or {}
            boosted.links[#boosted.links+1]=guideGUID
            guide.status="purple"
            guide.complete=true
            -- Activated Units keep their normal resource-state highlight;
            -- the Spirit Guides arrow itself still shows the purple link.
            if boosted.kind~="unit" then boosted.status="purple" end
            setHighlight(objects[guideGUID],guide.status,guide.powered)
            setHighlight(objects[linkedGUID],boosted.status,boosted.powered)
        end
    end

    -- Wings of Night costs 0 for the first affected enemy, then 1, 2,
    -- etc. Red buttons remain for immune/unaffordable selected targets.
    -- Remove paid Move from original sources too, to avoid counting it
    -- again against Cumbersome or in the Movement display.
    for _,pending in ipairs(pendingWingsNight) do
        local spent,count=0,0
        local combatMoveAvailable=0
        for sourceGUID,record in pairs(records) do
            if resourceCardsMoveRole(sourceGUID,true)=="combat" then
                combatMoveAvailable=combatMoveAvailable
                    +math.max(0,tonumber(record.resources~=nil and record.resources.move) or 0)
            end
        end
        for _,guid in ipairs(pending.targets) do
            local enemy=monsters[guid]
            if enemy~=nil and enemy.is_face_down~=true then
                local data=monsterPugs[guid]
                local perks=gStates~=nil and gStates.monsterPerks~=nil
                    and gStates.monsterPerks[guid] or nil
                local immune=(data~=nil and data.arcaneImmunity==true)
                    or (perks~=nil and perks.arcaneImmunity==true)
                local cost=count
                local affordable=cost<=combatMoveAvailable-spent
                combatEffectAdd(enemyEffects,guid,pending.source,
                    {noAttack=true,moveCost=cost,insufficientMove=not affordable},
                    pending.source)
                if not immune and affordable then count=count+1 spent=spent+cost end
            end
        end
        if spent>0 then
            local remaining=spent
            local moveSources={}
            for guid,record in pairs(records) do
                if record.resources~=nil and (tonumber(record.resources.move) or 0)>0
                    and resourceCardsMoveRole(guid,true)=="combat" then
                    moveSources[#moveSources+1]=guid
                end
            end
            table.sort(moveSources)
            for _,guid in ipairs(moveSources) do
                if remaining<=0 then break end
                local record=records[guid]
                local original=tonumber(record.resources.move) or 0
                local used=math.min(original,remaining)
                if used>0 then
                    local adjusted={}
                    for key,value in pairs(record.resources) do adjusted[key]=value end
                    adjusted.move=original-used
                    record.resources=adjusted
                    remaining=remaining-used
                end
            end
            totals.move=math.max(0,(tonumber(totals.move) or 0)-spent)
        end
    end

    -- Pay for Ready links from the available Influence pool in creation
    -- order. If a resource source is later undone, retire unaffordable
    -- links newest-first, along with their dependent Unit activations.
    local ruthlessReadySpent=0
    local ruthlessReadyBySource={}
    local readyNeedsRescan=false
    local readyPayments={}
    for key,link in pairs(gStates.unitReadyLinks or {}) do
        local owner=key:match("^([0-9a-f]+)#ready%d+$")
        local record=owner~=nil and records[owner] or nil
        local data=owner~=nil and gameCards[owner] or nil
        local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
        local unit=link~=nil and gameCards[link.unitGUID] or nil
        if record~=nil and record.complete and record.powered and rule~=nil
            and rule.readyWithInfluence~=nil and unit~=nil
            and (tonumber(unit.level) or 99)<=rule.readyWithInfluence.maxLevel then
            readyPayments[#readyPayments+1]={key=key,owner=owner,
                cost=(tonumber(unit.level) or 0)*rule.readyWithInfluence.costPerLevel,
                number=tonumber(key:match("#ready(%d+)$")) or 0}
        end
    end
    table.sort(readyPayments,function(a,b)
        if a.owner~=b.owner then return a.owner<b.owner end
        return a.number<b.number
    end)
    local availableInfluence=totals.influence or 0
    for _,payment in ipairs(readyPayments) do
        if gStates.unitReadyLinks[payment.key]~=nil then
            if ruthlessReadySpent+payment.cost<=availableInfluence then
                ruthlessReadySpent=ruthlessReadySpent+payment.cost
                ruthlessReadyBySource[payment.owner]=
                    (ruthlessReadyBySource[payment.owner] or 0)+payment.cost
            else
                unitHistoryCancelReadySource(payment.key)
                readyNeedsRescan=true
            end
        end
    end
    for owner,spent in pairs(ruthlessReadyBySource) do
        if records[owner]~=nil then records[owner].readyInfluenceSpent=spent end
    end
    totals.influence=availableInfluence-ruthlessReadySpent

    -- First recognition determines phase; later enemy arrivals do not change it.
    local moveSplit={movement=0,combat=0}
    for guid,record in pairs(records) do
        local amount=math.max(0,tonumber(record.resources~=nil and record.resources.move) or 0)
        if amount>0 then
            local role=resourceCardsMoveRole(guid,true)
            moveSplit[role]=moveSplit[role]+amount
        end
    end
    local previous=trackerPrivate.bySeat[seatPos] or {}
    local previousScan=resourceCardScanBySeat[seatPos]
    local previousMove=previousScan~=nil and (previousScan.totals.move or 0) or 0
    local previousSplit=previousScan~=nil and previousScan.moveSplit or nil
    local enemyStateChanged=previousScan==nil
        or previousScan.enemyPresent~=combatEnemyInPlay
    local moveSplitChanged=previousSplit==nil
        or previousSplit.movement~=moveSplit.movement
        or previousSplit.combat~=moveSplit.combat
    table.sort(terrainModifiers,terrainModifierPrecedes)
    local prior=previousScan~=nil and previousScan.terrainModifiers or nil
    local terrainChanged=prior==nil and #terrainModifiers>0
        or prior~=nil and #prior~=#terrainModifiers
    if prior~=nil and not terrainChanged then
        for i,effect in ipairs(terrainModifiers) do
            if prior[i]~=effect then terrainChanged=true break end
        end
    end
    local totalsChanged=previousScan==nil
    if not totalsChanged then
        for category in pairs(trackerPrivate.totalsKeys) do
            if (previousScan.totals[category] or 0)~=(totals[category] or 0) then
                totalsChanged=true
                break
            end
        end
    end
    local priorMovement=previousScan~=nil and previousScan.movementEffects or nil
    local movementChanged=priorMovement==nil
        or priorMovement.jumpTwoSpaces~=movementEffects.jumpTwoSpaces
        or priorMovement.ignoreRampagers~=movementEffects.ignoreRampagers
        or (priorMovement.windFlightMax or 0)~=movementEffects.windFlightMax
        or (priorMovement.singleSpaceDiscount or 0)~=movementEffects.singleSpaceDiscount
    local previousTransform=previousScan~=nil and previousScan.attackTransforms or nil
    local transformChanged=previousTransform==nil
        or (previousTransform.coldFire==true)~=(attackTransforms.coldFire==true)
        or (previousTransform.siege==true)~=(attackTransforms.siege==true)
    -- The normal recruitment discount cannot coexist with the stronger
    -- side of the same card. Remove its pending event if the side changes.
    for guid,selected in pairs(gStates.startingCardSelections or {}) do
        local data=gameCards[guid]
        local record=records[guid]
        if data~=nil and data.resourceKey=="ruthlessCoercion"
            and record~=nil and record.powered==true then
            selected.recruited=nil
        end
    end
    local fameTotal,repTotal=0,0
    for _,record in pairs(records) do
        if record.fameRep~=nil then
            fameTotal=fameTotal+(record.fameRep.fame or 0)
            repTotal=repTotal+(record.fameRep.rep or 0)
        end
    end
    resourceCardsSyncInteractionPower(records)
    local earnedFame,earnedRep=combatConfig.startingCardConditionalFameRep()
    fameTotal=fameTotal+earnedFame
    repTotal=repTotal+earnedRep
    local scanPlayer=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    local fameRepBase={fame=fameTotal,rep=repTotal}
    trackerPrivate.bySeat[seatPos]=current
    resourceCardScanBySeat[seatPos]={cards=records,totals=totals,
        moveSplit=moveSplit,enemyPresent=combatEnemyInPlay,
        attackTransforms=attackTransforms,
        terrainModifiers=terrainModifiers,movementEffects=movementEffects,
        enemyEffects=enemyEffects,fameRepBase=fameRepBase,
        ruthlessReadySpent=ruthlessReadySpent,
        ignoreSiteFortifications=ignoreSiteFortifications,
        unitState=unitState,gloryBroken=(function()
            for _,card in ipairs(cards) do
                local data=gameCards[card.guid]
                if data~=nil and data.resourceKey=="artifactBannerGlory"
                    and trackerPrivate.bannerStrongActive(card)
                    and cardPosture(card)=="upright" then
                    return true
                end
            end
            return false
        end)(),preventUnitDamage=preventUnitDamage,
        allUnitResistances=allUnitResistances,heroFirstWoundIgnored=heroFirstWoundIgnored,
        heroPsychicBlock=heroPsychicBlock,
        usesCurrentHexBlock=usesCurrentHexBlock,
        usesCurrentHexHealing=usesCurrentHexHealing,
        usesSkillLocation=usesSkillLocation}
    if attackAssignmentsRefreshAmbushLinks~=nil then attackAssignmentsRefreshAmbushLinks() end
    -- This also retracts a saved Ready if its card loses power or the new
    -- Rejuvenate side can no longer ready that Unit level.
    if unitHistoryValidSources(seatPos) or readyNeedsRescan then
        -- Links can undo earlier Unit resources; rebuild from the updated
        -- history rather than showing those stale contributions for one scan.
        resourceCardsSourceChanged()
    end
    refreshCombatEnemyPanel(combatMonsters,true)
    resourceCardsApplyFameRep(seatPos)
    -- Refresh Reputation on every settled Skill scan so flipping Arcane
    -- Disguise updates Influence without requiring a panel toggle.
    local reputationBefore=gStates.resourceTracker~=nil
        and gStates.resourceTracker.influence~=nil
        and gStates.resourceTracker.influence.reputation or nil
    refreshResourceTrackerReputation()
    local reputationAfter=gStates.resourceTracker~=nil
        and gStates.resourceTracker.influence~=nil
        and gStates.resourceTracker.influence.reputation or nil
    -- Redraw movement when ability flags change, even if total Move stays equal.
    if totalsChanged or terrainChanged or transformChanged or moveSplitChanged
        or enemyStateChanged or reputationBefore~=reputationAfter then
        refreshResourceTrackerText()
    end
    if previousMove~=(totals.move or 0) or moveSplitChanged
        or terrainChanged or movementChanged then
        updateMoveDisplay()
    end
    for guid in pairs(previous) do
        if current[guid]~=true then
            combatConfig.sacrificeCastPairs[guid]=nil
            clearHighlight(guid)
            local previousObject=getObjectFromGUID(guid)
            if not combatConfig.cardInTransit(previousObject) then
                if choiceButtonShown[guid]~=nil and choiceButtonShown[guid]~="hidden" then
                    removeChoiceButtons(previousObject)
                end
                -- A genuinely removed card must rebuild its controls on re-entry.
                -- Preserve the existing object UI and its signature during
                -- transient lifts; the settled drop scan owns their cleanup.
                choiceButtonShown[guid]=nil
                choiceExpandedByGUID[guid]=nil
            end
            -- A used Skill leaves play at end of turn; do not allow the
            -- previous turn's Block link to be silently reused next turn.
            local rule=skillResourceDefinitions[guid]
            if rule~=nil and rule.damageMitigation~=nil and gStates~=nil then
                local obj=getObjectFromGUID(guid)
                if obj==nil or (obj.held_by_color==nil and not obj.isSmoothMoving()) then
                    if guid=="ae8673" then gStates.elementalResistanceAttackKey=nil
                    else gStates.battleHardenedAttackKey=nil end
                end
            end
            if rule~=nil and rule.blockSourceBoost~=nil
                and attackAssignmentsForgetBlockLink~=nil then
                local obj=getObjectFromGUID(guid)
                if obj==nil or (obj.held_by_color==nil
                    and not obj.isSmoothMoving()) then
                    attackAssignmentsForgetBlockLink(guid)
                end
            end
        end
    end
    -- A borrowed offer Unit is not a normal Unit-zone object. Zone-exit
    -- tracker refreshes can drop its independent cycling UI during dragging.
    -- Restore it after all tracker-owned UI writes, without touching resources.
    if callOfferEnsureControls~=nil then callOfferEnsureControls(seatPos) end
    if magicTalentEnsureControls~=nil then magicTalentEnsureControls(seatPos) end
    if unitReplacementEnsureControls~=nil then unitReplacementEnsureControls(seatPos) end
    if steadyTempoRefreshAll~=nil and next(gStates.steadyTempoPending or {})~=nil then
        steadyTempoRefreshAll()
    end
    trackerPrivate.renderCombatNight=nil
    if trackerPrivate.traceEnabled then trackerPrivate.traceEvent("render.done",seatPos) end
end

local function scheduleSeatRender(seatPos)
    local generation=trackerPrivate.generation[seatPos] or 0
    if trackerPrivate.pendingSeatRender[seatPos]==generation then
        if trackerPrivate.traceEnabled then trackerPrivate.traceEvent("render.coalesced",seatPos) end
        return
    end
    trackerPrivate.pendingSeatRender[seatPos]=generation
    if trackerPrivate.traceEnabled then trackerPrivate.traceEvent("render.queued",seatPos,nil,"gen="..generation) end
    safeWaitFrames("PlayerBoard.CardRecognition",function()
        if trackerPrivate.pendingSeatRender[seatPos]~=generation then return end
        trackerPrivate.pendingSeatRender[seatPos]=nil
        if (trackerPrivate.generation[seatPos] or 0)==generation and resourceCardsPanelOpen() then
            renderSeat(seatPos)
        end
    end,1)
end

local function queueSeat(seatPos,triggerGUID)
    if not resourceCardsPanelOpen() or seatPos==nil or seatPos<1 or seatPos>4 then return end
    if triggerGUID==nil then scheduleSeatRender(seatPos) return end
    local generation=trackerPrivate.generation[seatPos] or 0
    local waits=trackerPrivate.pendingSeatSettles[seatPos]
    if waits==nil then waits={} trackerPrivate.pendingSeatSettles[seatPos]=waits end
    -- Zone entry and drop frequently report the same moving object.
    if waits[triggerGUID]==generation then
        if trackerPrivate.traceEnabled then trackerPrivate.traceEvent("settle.coalesced",seatPos,triggerGUID) end
        return
    end
    local obj=getObjectFromGUID(triggerGUID)
    if obj==nil or trackerPrivate.readyForXZ(obj) then
        if trackerPrivate.traceEnabled then trackerPrivate.traceEvent("settle.ready",seatPos,triggerGUID) end
        scheduleSeatRender(seatPos)
        return
    end
    waits[triggerGUID]=generation
    if trackerPrivate.traceEnabled then trackerPrivate.traceEvent("settle.wait",seatPos,triggerGUID) end
    local function stillCurrent()
        return (trackerPrivate.generation[seatPos] or 0)==generation
            and trackerPrivate.pendingSeatSettles[seatPos]==waits
            and waits[triggerGUID]==generation and resourceCardsPanelOpen()
    end
    local function settled()
        if not stillCurrent() then return end
        waits[triggerGUID]=nil
        if trackerPrivate.traceEnabled then trackerPrivate.traceEvent("settle.done",seatPos,triggerGUID) end
        scheduleSeatRender(seatPos)
    end
    safeWaitCondition("PlayerBoard.CardRecognition",settled,function()
        if not stillCurrent() then return true end
        local live=getObjectFromGUID(triggerGUID)
        return live==nil or trackerPrivate.readyForXZ(live)
    end,8,function()
        -- A perpetually held/rolling token must not keep the watcher alive
        -- or delay other objects' refreshes. Its eventual drop queues anew.
        if trackerPrivate.pendingSeatSettles[seatPos]==waits
            and waits[triggerGUID]==generation then
            waits[triggerGUID]=nil
            if trackerPrivate.traceEnabled then trackerPrivate.traceEvent("settle.timeout",seatPos,triggerGUID) end
        end
    end)
end

function resourceCardsSourceChanged()
    local current=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    if current~=nil and resourceCardsPanelOpen() then
        if trackerPrivate.traceEnabled then trackerPrivate.traceEvent("source.changed",current.seatPos) end
        queueSeat(current.seatPos,nil)
    end
end

local function clearAll()
    if trackerPrivate.traceEnabled then trackerPrivate.traceEvent("tracker.reset") end
    for seat=1,4 do trackerPrivate.generation[seat]=(trackerPrivate.generation[seat] or 0)+1 end
    trackerPrivate.pendingSeatSettles={}
    trackerPrivate.pendingSeatRender={}
    clearChoiceButtons()
    choiceExpandedByGUID={}
    -- Do not discard choices when closing/reopening the Resource Tracker.
    for guid in pairs(shown) do clearHighlight(guid) end
    trackerPrivate.bySeat={}
    trackerPrivate.playCandidatesBySeat={}
    trackerPrivate.playCardMovements={}
    trackerPrivate.cardUIRecheckSerial={}
    resourceCardScanBySeat={}
    combatConfig.bowSourceModes={}
    combatConfig.amuletMana={gold=false,black=false}
    -- Ordinary resource sources disappear when tracking is OFF. Earned
    -- conditional interaction rewards/penalties remain pending until turn end.
    if turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber]~=nil then
        local fame,rep=combatConfig.startingCardConditionalFameRep()
        resourceFameRepApply(gStates.turnNumber,fame,rep)
    end
    -- Closing must not invoke tracker calculations or redraw its overlays.
    if resourceCardsPanelOpen() and gStates~=nil and gStates.resourceTracker~=nil then
        refreshResourceTrackerText()
        updateMoveDisplay()
    end
end

-- Explicitly resolve Banner of Fortitude's all-Unit Healing against physical
-- Wound tokens. The button is shown only for the broken side, and player
-- action is required; scanning must NEVER delete a Wound just because an
-- artifact briefly changed posture.
function resourceCardsArtifactHealUnitsClicked(player,value,id)
    if not resourceCardsPanelOpen()
        or not resourceCardsPlayerCanEdit(player~=nil and player.color or nil)
        or type(id)~="string" or combatCalcOn or combatEnemyInPlay then return end
    local guid=id:match("^ResourceCardChoice_([0-9a-f]+)_healAllUnits$")
    local data=guid~=nil and gameCards[guid] or nil
    if data==nil or data.resourceKey~="artifactBannerFortitude"
        or trackerPrivate.bannerCardForm(guid)~="full" then return end
    local current=turnOrder~=nil and gStates~=nil
        and turnOrder[gStates.turnNumber] or nil
    local card=getObjectFromGUID(guid)
    if current==nil or card==nil or not resourceCardsArtifactBroken(guid,card)
        or cardPosture(card)~="upright"
        or not cardInSeatPlayArea(guid,current.seatPos) then return end
    local layout=unitLayoutSnapshot(current.seatPos)
    local trash=getObjectFromGUID(trashCan)
    if trash==nil then return end
    local uses=trackerPrivate.bannerEffectUses().healing
    if uses[guid] then return end
    -- Activating the break effect consumes it, even if no Units are wounded.
    uses[guid]=true
    local healed=0
    for _,obj in ipairs(layout.objects or {}) do
        if unitLayoutIsWound(obj) then
            trash.putObject(obj)
            healed=healed+1
        end
    end
    if healed>0 then scheduleUnitLayoutRefresh(current.seatPos) end
    -- Refresh the spent HEAL control even when zero Wounds were present.
    resourceCardsSourceChanged()
    broadcastToColor("Banner of Fortitude: healed "..tostring(healed)
        .." Unit Wound(s).",player.color,{0.7,0.95,0.7})
end

-- Forked Lightning commits every bolt to one combat phase, rather than
-- allowing a Ranged kill with one and a later melee hit with another.
function resourceCardsForkedLightningPhaseClicked(player,value,id)
    if id~="ResourceCardChoice_d01b70_forkPhase"
        or not resourceCardsPanelOpen()
        or not resourceCardsPlayerCanEdit(player~=nil and player.color or nil) then return end
    gStates.forkedLightningPhase=gStates.forkedLightningPhase=="attack" and "range" or "attack"
    resourceCardsSourceChanged()
end

-- The small Battle Hardened counter cycles individual printed Attacks on the
-- already targeted enemy (including multiple Attacks from summoners).
function resourceCardsBattleHardenedAttackClicked(player,value,id)
    if not resourceCardsPanelOpen() or not resourceCardsPlayerCanEdit(player~=nil and player.color or nil) then return end
    local guid=type(id)=="string" and id:match("^ResourceCardChoice_([0-9a-f]+)_hardenedCycle$") or nil
    if guid~="0688d8" and guid~="ae8673" then return end
    local stateKey=guid=="ae8673" and "elementalResistanceAttackKey" or "battleHardenedAttackKey"
    local target=combatAssignmentState.targets[guid]
    local options=combatHardenedAttackOptions(target)
    if #options<2 then return end
    local current=gStates~=nil and gStates[stateKey] or nil
    local index=1
    for i,option in ipairs(options) do if option.key==current then index=i break end end
    gStates[stateKey]=options[index%#options+1].key
    resourceCardsSourceChanged()
end

function resourceCardsConversionClicked(player,value,id)
    if not resourceCardsPanelOpen()
        or not resourceCardsPlayerCanEdit(player~=nil and player.color or nil) then return end
    local guid,part,useIndex=nil,nil,nil
    if type(id)=="string" then
        guid,part,useIndex=id:match(
            "^ResourceCardChoice_([0-9a-f]+)_convert([%a]+)(%d*)$")
    end
    -- The match above uses two captures; do not mistake a missing part for an action.
    if guid~="878d92" and guid~="8c3de6" then return end
    local seat=combatAssignmentActiveSeat()
    local kind=guid=="878d92" and "agility" or "diplomacy"
    local conversion,available,valid,record=combatConfig.conversionFor(seat,kind)
    if not valid or record==nil or conversion==nil then return end
    local index=useIndex~="" and tonumber(useIndex) or nil
    if index~=nil and (kind~="diplomacy" or record.repeatLink==nil
        or index<1 or index>record.repeatLink.count) then return end
    if part=="Element" then
        if kind~="diplomacy" or record.powered~=true then return end
        if index~=nil then
            conversion.elementUses[index]=conversion.elementUses[index]=="F" and "I" or "F"
        else
            conversion.element=conversion.element=="F" and "I" or "F"
        end
    else
        local delta=tostring(value)=="-2" and -1 or 1
        if kind=="agility" and part=="Attack" and index==nil then
            conversion.attack=math.max(0,math.min(available-2*conversion.ranged,
                conversion.attack+delta))
        elseif kind=="agility" and part=="Ranged" and index==nil then
            conversion.ranged=math.max(0,math.min(
                math.floor((available-conversion.attack)/2),conversion.ranged+delta))
        elseif kind=="diplomacy" and part=="Block" and index~=nil then
            local current=conversion.blockUses[index] or 0
            local unspent=available-conversion.block+current
            conversion.blockUses[index]=math.max(0,math.min(unspent,current+delta))
        elseif kind=="diplomacy" and part=="Block" and index==nil then
            conversion.block=math.max(0,math.min(available,conversion.block+delta))
        else return end
    end
    resourceCardsSourceChanged()
end

-- Explicit decisions for official starting cards that have a secondary effect.
-- These controls never silently add conditional Fame, Reputation or Move.
function resourceCardsStartingCardControlClicked(player,value,id)
    if not resourceCardsPanelOpen() or not resourceCardsDetailsOpen()
        or not resourceCardsPlayerCanEdit(player~=nil and player.color or nil)
        or type(id)~="string" then return end
    local guid,control=id:match("^ResourceCardChoice_([0-9a-f]+)_([%a]+)$")
    if guid==nil then return end
    local card=getObjectFromGUID(guid)
    local data=gameCards[guid]
    local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
    local current=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    if current==nil or card==nil or rule==nil or card.is_face_down
        or cardPosture(card)~="upright"
        or not cardInSeatPlayArea(guid,current.seatPos) then return end
    local scan=resourceCardScanBySeat[current.seatPos]
    local record=scan~=nil and scan.cards[guid] or nil
    if record==nil or not record.complete or record.resources==nil then return end
    gStates.startingCardSelections=gStates.startingCardSelections or {}
    local selected=gStates.startingCardSelections[guid] or {}
    local right=tostring(value)=="-2"
    if control=="interaction" and rule.interactionReward~=nil then
        selected.interaction=not selected.interaction
        selected.interactionPowered=selected.interaction and record.powered or nil
    elseif control=="recruit" and rule.recruitDiscount~=nil and not record.powered then
        selected.recruited=not selected.recruited
    elseif control=="terrain" and rule.selectedTerrainDiscount~=nil and record.powered then
        if right then selected.terrain=nil
        else
            local terrains={"plains","hills","forest","wasteland","desert",
                "swamp","lake","mountain","city"}
            local index=0
            for i,terrain in ipairs(terrains) do
                if terrain==selected.terrain then index=i break end
            end
            selected.terrain=terrains[index%#terrains+1]
        end
    elseif control=="ruthlessReady" and rule.readyWithInfluence~=nil
        and record.powered then
        local links=gStates.unitReadyLinks or {}
        if right then
            local highest=0
            for key in pairs(links) do
                local index=tonumber(key:match("^"..guid.."#ready(%d+)$"))
                if index~=nil and index>highest then highest=index end
            end
            if highest>0 then unitHistoryCancelReadySource(guid.."#ready"..highest) end
        else
            -- A new click chooses a fresh independent Ready source; old links
            -- and their dependent activation history remain intact.
            if (tonumber(scan.totals.influence) or 0)<2 then return end
            local index=1
            while links[guid.."#ready"..index]~=nil do index=index+1 end
            attackAssignmentsBeginUnitReady(guid,guid.."#ready"..index,player.color,
                rule.readyWithInfluence.maxLevel)
        end
    else return end
    gStates.startingCardSelections[guid]=selected
    resourceCardsSourceChanged()
end

-- Confirm how many of the basic Golden Grail's two Heal points were spent.
-- Generated but unspent Heal is worth no Fame. Right-click removes a point.
function resourceCardsArtifactGrailFameClicked(player,value,id)
    if not resourceCardsPanelOpen() or not resourceCardsDetailsOpen()
        or not resourceCardsPlayerCanEdit(player~=nil and player.color or nil)
        or type(id)~="string" or gStates==nil then return end
    local guid=id:match("^ResourceCardChoice_([0-9a-f]+)_grailFame$")
    local data=guid~=nil and gameCards[guid] or nil
    local card=guid~=nil and getObjectFromGUID(guid) or nil
    local current=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    if data==nil or data.resourceKey~="artifactGoldenGrail" or card==nil
        or current==nil or cardPosture(card)~="upright"
        or resourceCardsArtifactBroken(guid,card)
        or not cardInSeatPlayArea(guid,current.seatPos)
        or combatConfig.phaseObjectLocked(guid) then return end
    local scan=resourceCardScanBySeat[current.seatPos]
    local record=scan~=nil and scan.cards[guid] or nil
    if record==nil or not record.complete or record.powered then return end
    gStates.artifactGrailHealingUsed=gStates.artifactGrailHealingUsed or {}
    local used=math.max(0,math.min(2,
        tonumber(gStates.artifactGrailHealingUsed[guid]) or 0))
    local delta=tostring(value)=="-2" and -1 or 1
    gStates.artifactGrailHealingUsed[guid]=math.max(0,math.min(2,used+delta))
    resourceCardsSourceChanged()
end

-- Toggle the strong effect on any full-size Artifact while keeping its text
-- face up. The saved choice, not rotation, controls later end-turn destruction.
function resourceCardsArtifactBreakClicked(player,value,id)
    if not resourceCardsPanelOpen() or not resourceCardsDetailsOpen()
        or not resourceCardsPlayerCanEdit(player~=nil and player.color or nil)
        or type(id)~="string" or gStates==nil then return end
    local guid=id:match("^ResourceCardChoice_([0-9a-f]+)_artifactBreak$")
    local data=guid~=nil and gameCards[guid] or nil
    local card=guid~=nil and getObjectFromGUID(guid) or nil
    local current=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    if data==nil or data.cardType~="Artifact" or data.full~=nil
        or card==nil or current==nil or cardPosture(card)~="upright"
        or not cardInSeatPlayArea(guid,current.seatPos)
        or combatConfig.phaseObjectLocked(guid) then return end
    local broken=resourceCardsArtifactBroken(guid,card)
    if not broken and combatEnemyInPlay then
        if data.resourceKey=="artifactDruidicStaff" then
            safeBroadcastToColor("Druidic Staff: Throw requires two different "
                .."options; only Blue is usable in combat.",player.color,warningColor)
            return
        elseif data.resourceKey=="artifactBannerCourage"
            or data.resourceKey=="artifactBannerFortitude" then
            safeBroadcastToColor("This Banner's stronger effect can only be used "
                .."outside combat.",player.color,warningColor)
            return
        end
    end
    -- Undo only this Banner's Ready permissions on unbreaking. A later
    -- re-Break can restore the original eligible snapshot without granting
    -- duplicate activations or newly-spent Units an extra Ready.
    if broken and data.resourceKey=="artifactBannerCourage" then
        local uses=trackerPrivate.bannerEffectUses().courage[guid]
        for _,entry in ipairs(uses~=nil and uses.eligible or {}) do
            if gStates.unitReadyLinks~=nil and gStates.unitReadyLinks[entry.key]~=nil then
                unitHistoryCancelReadySource(entry.key)
            end
        end
    end
    gStates.artifactBreaks=gStates.artifactBreaks or {}
    gStates.artifactBreaks[guid]=not broken
    choiceExpandedByGUID[guid]=nil
    resourceCardsSourceChanged()
end

-- Player clicks always replace the one-time guess; opening the choice menu
-- alone leaves that selection and the Resource Tracker totals unchanged.
function resourceCardsChoiceClicked(player,value,id)
    if not resourceCardsPanelOpen() or type(id)~="string"
        or not resourceCardsPlayerCanEdit(player~=nil and player.color or nil) then return end
    local guid,repeatIndex,category=id:match(
        "^ResourceCardChoice_([0-9a-f]+)_rep(%d+)_([%w]+)$")
    local setIndex=nil
    if guid==nil then
        guid,setIndex,category=id:match(
            "^ResourceCardChoice_([0-9a-f]+)_set(%d+)_([%w]+)$")
    end
    if guid==nil then
        guid,category=id:match("^ResourceCardChoice_([0-9a-f]+)_([%w]+)$")
    end
    if guid==nil or (combatConfig~=nil and combatConfig.phaseObjectLocked~=nil
        and combatConfig.phaseObjectLocked(guid)) then return end
    setIndex=setIndex~=nil and tonumber(setIndex) or nil
    repeatIndex=repeatIndex~=nil and tonumber(repeatIndex) or nil
    if not resourceCardsDetailsOpen() then return end
    local card=getObjectFromGUID(guid)
    local data=card~=nil and gameCards[guid] or nil
    local isSkill=skillTokens[guid]~=nil
    local isReward=card~=nil and factionRewardForObject(card)~=nil
    local isPuppet=card~=nil and card.getGMNotes()=="Puppet Master"
    local rule=isSkill and skillResourceDefinitions[guid]
        or (data~=nil and cardResourceDefinitions[data.resourceKey] or nil)
    local currentSeat=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    if card==nil or currentSeat==nil then return end
    local scan=resourceCardScanBySeat[currentSeat.seatPos]
    local record=scan~=nil and scan.cards[guid] or nil
    local linkedWound=card.getGMNotes()=="Wound" and record~=nil
        and record.linkedSkill~=nil
    if rule==nil and not isSkill and not isPuppet and not isReward and not (cardPosture(card)=="sideways"
        and (cardCanPlaySideways(card) or linkedWound)) then return end
    local zone=getObjectFromGUID(playerPlayAreas[currentSeat.seatPos])
    local inZone=false
    if zone~=nil then
        for _,obj in ipairs(zone.getObjects()) do
            if obj.guid==guid then inZone=true break end
        end
    end
    if not inZone then return end
    -- Linked cards take the powered choice even without mana placed on them.
    local powered=record~=nil and record.powered==true
    local sideways=not isSkill and not isReward and cardPosture(card)=="sideways"
    local mainChoices
    if isSkill or isPuppet or isReward then
        mainChoices=record~=nil and record.choices or (rule~=nil and rule.choices or nil)
    elseif sideways and (cardCanPlaySideways(card) or linkedWound) then
        mainChoices=trackerPrivate.sidewaysChoices
    elseif not sideways then
        -- Paid mana choices were filtered during the most recent physical scan.
        -- Do not rediscover the full printed menu and offer unpaid alternatives.
        mainChoices=record~=nil and record.choices or nil
    end
    if (mainChoices==nil or #mainChoices==0) and record~=nil
        and (tonumber(record.resources~=nil and record.resources.move) or 0)>0 then
        mainChoices={{move=record.resources.move}}
    end
    local choices=mainChoices
    if repeatIndex~=nil then
        local repeated=record~=nil and record.repeatLink or nil
        if repeated==nil or repeatIndex<1 or repeatIndex>repeated.count then return end
        choices=repeated.options~=nil and repeated.options[repeatIndex] or mainChoices
    end
    local inventorySpec=not sideways and powered and rule~=nil
        and rule.inventorySetChoices or nil
    if rule~=nil and rule.staffDualChoices==true and powered and not sideways then
        local _,firstKey=currentChoice(guid,true,mainChoices)
        local remaining={}
        for _,option in ipairs(mainChoices or {}) do
            if choiceCategory(option)~=firstKey then
                remaining[#remaining+1]=option
            end
        end
        inventorySpec={choices=remaining}
    end
    local inventorySets=inventorySpec~=nil and record~=nil
        and record.inventorySetCount or 0
    if setIndex~=nil then
        if inventorySpec==nil or setIndex<1 or setIndex>inventorySets then return end
        choices=inventorySpec.choices
    end
    local selectedMoveCategory=category:match("^combatMove(.+)$")
    -- Reject a stale UI click after the last Cumbersome enemy is removed.
    if selectedMoveCategory~=nil and not (combatCalcOn and combatCumbersomeActive) then return end
    local requestedMoveRole=selectedMoveCategory~=nil and "combat" or nil
    if selectedMoveCategory~=nil then category=selectedMoveCategory end
    if data~=nil and data.resourceKey=="artifactDruidicStaff"
        and combatEnemyInPlay and category~="blue" then
        safeBroadcastToColor("Druidic Staff: only the two-crystal option is usable in combat.",
            player.color,warningColor)
        return
    end
    local valid=choiceAvailable(choices,category)
    if not valid then return end
    if requestedMoveRole==nil then
        for _,option in ipairs(choices) do
            if choiceCategory(option)==category and (tonumber(option.move) or 0)>0 then
                requestedMoveRole="movement"
                break
            end
        end
    end
    -- Any card whose newly selected effect is Move-only must start without
    -- an enemy assignment. Move can Block Cumbersome, but only when the
    -- player explicitly targets it; never carry an old Attack/Block arrow.
    local _,previousCategory
    if repeatIndex~=nil then
        _,previousCategory=combatConfig.repeatChoiceFor(guid,powered,choices,repeatIndex)
    elseif setIndex~=nil then
        _,previousCategory=inventorySetChoice(guid,setIndex,choices,mainChoices)
    else
        _,previousCategory=currentChoice(guid,powered,choices,sideways)
    end
    local selectedMoveOnly=false
    if previousCategory~=category then
        for _,option in ipairs(choices or {}) do
            if choiceCategory(option)==category and (tonumber(option.move) or 0)>0 then
                selectedMoveOnly=true
                for _,field in ipairs(combatConfig.sourceFields) do
                    if (tonumber(option[field.key]) or 0)>0 then
                        selectedMoveOnly=false
                        break
                    end
                end
                break
            end
        end
    end
    local rowId=repeatIndex~=nil and ("rep"..repeatIndex)
        or setIndex~=nil and ("set"..setIndex) or "base"
    local currentlyExpanded=choiceExpandedByGUID[guid]
    if currentlyExpanded~=rowId and not (rowId=="base" and currentlyExpanded==true) then
        -- Opening a row never changes the chosen resource.
        choiceExpandedByGUID[guid]=rowId
        showChoiceButtons(card,mainChoices,powered,inventorySpec,inventorySets,
            record~=nil and record.resources,record~=nil and record.repeatLink)
        return
    end
    local selected=selectedResourceByGUID[guid] or {}
    if repeatIndex~=nil then
        selected.repeatChoices=selected.repeatChoices or {}
        selected.repeatChoices[repeatIndex]=category
    elseif setIndex~=nil then
        selected.inventorySets=selected.inventorySets or {}
        selected.inventorySets[setIndex]=category
    elseif not sideways then
        selected.effect=category
    elseif choiceAvailable(sideChoices(rule,false),category)
        or choiceAvailable(sideChoices(rule,true),category) then
        selected.effect=category
        selected.sideways=nil
    else
        selected.sideways=category
    end
    selectedResourceByGUID[guid]=selected
    if repeatIndex~=nil and record~=nil and record.repeatLink~=nil
        and not combatConfig.compositePhasesMatch(
            guid,powered,mainChoices,record.repeatLink) then
        safeBroadcastToColor(
            "Maximal Effect: repeated options must resolve in one phase. "
            .."Adjust the other rows; mixed phases contribute nothing until compatible.",
            player.color,warningColor)
    end
    local previousMoveRole=requestedMoveRole~=nil
        and resourceCardsMoveRole(guid,true) or nil
    if requestedMoveRole~=nil then
        gStates.resourceCardMoveRoles[guid]=requestedMoveRole
    end
    if selectedMoveOnly or (previousMoveRole=="combat"
        and requestedMoveRole=="movement") then
        -- Clear both the saved arrow and the independent calculator lock
        -- before the rescan. The newly selected Move stays available for
        -- a deliberate new target, but does not auto-Block any enemy.
        combatForgetPhysicalSourceTargets(guid)
        if attackAssignmentsClearForObject~=nil then attackAssignmentsClearForObject(guid) end
    end
    if data~=nil and data.resourceKey=="rejuvenate" then
        gStates.unitReadyCardChoices=gStates.unitReadyCardChoices or {}
        gStates.unitReadyCardChoices[guid]=selected.effect=="ready" or nil
    end
    choiceExpandedByGUID[guid]=nil
    showChoiceButtons(card,mainChoices,powered,inventorySpec,inventorySets,
        record~=nil and record.resources,record~=nil and record.repeatLink)
    if data~=nil and data.resourceKey=="rejuvenate" then
        unitHistoryValidSources(currentSeat.seatPos)
        if attackAssignmentsRefreshReadyUI~=nil then attackAssignmentsRefreshReadyUI() end
    end
    queueSeat(currentSeat.seatPos,nil)
end

-- Regeneration gives Heal and an independent Ready for each application.
-- Right click cancels the link and its dependent Unit activation history.
function resourceCardsRegenerationReadyClicked(player,value,id)
    if not resourceCardsPanelOpen() or not resourceCardsDetailsOpen()
        or not resourceCardsPlayerCanEdit(player~=nil and player.color or nil)
        or type(id)~="string" then return end
    local guid,index=id:match("^ResourceCardChoice_([0-9a-f]+)_regenReady(%d+)$")
    if guid~="878d91" then return end
    local sourceKey=guid.."#ready"..index
    if tostring(value)=="-2" then
        if gStates.unitReadyLinks~=nil and gStates.unitReadyLinks[sourceKey]~=nil then
            unitHistoryCancelReadySource(sourceKey)
            resourceCardsSourceChanged()
        end
        return
    end
    if not resourceCardsReadySourceValid(sourceKey) then return end
    local active=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    if active==nil then return end
    attackAssignmentsBeginUnitReady(guid,sourceKey,player.color,
        resourceCardsReadySourceLevelLimit(sourceKey,active.seatPos))
end

-- Ready sources need an active effect; a Command move alone cannot authorize reuse.
-- while the exact played choice remains Ready; physical Command movement
-- alone cannot grant a second use.
function resourceCardsReadySourceValid(sourceKey,seatPos)
    if type(sourceKey)~="string" or gStates==nil then return false end
    local guid=unitHistorySourceBase(sourceKey)
    local abilities=unitResourceDefinitions[guid]
    if abilities~=nil then
        local useIndex=tonumber(sourceKey:match("#use(%d+)$")) or 1
        local group=gStates.unitActivationHistory and gStates.unitActivationHistory[guid]
        local activation=group~=nil and group.uses[useIndex] or nil
        if activation==nil or (seatPos~=nil and activation.seatPos~=seatPos) then return false end
        local unit=getObjectFromGUID(guid)
        if unit==nil then return false end
        local decision=unitManaDecision(unit,abilities,activation,
            activation.frozenCounts or activation.lastCounts)
        local choice=decision.index~=nil and abilities[decision.index] or nil
        return choice~=nil and choice.key=="ready"
    end
    local data=gameCards[guid]
    if data~=nil and data.resourceKey=="artifactDruidicStaff" then
        local card=getObjectFromGUID(guid)
        local current=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
        seatPos=seatPos or (current~=nil and current.seatPos)
        if card==nil or seatPos==nil or not cardInSeatPlayArea(guid,seatPos)
            or cardPosture(card)~="upright" or sourceKey~=guid then return false end
        local scan=resourceCardScanBySeat[seatPos]
        local record=scan~=nil and scan.cards[guid] or nil
        local linkedReady=gStates.unitReadyLinks~=nil
            and gStates.unitReadyLinks[sourceKey]~=nil
        if record==nil or (not record.complete and not (combatEnemyInPlay and linkedReady)) then
            return false
        end
        -- An already-committed pre-combat Ready remains valid during combat,
        -- but a new in-combat Ready is never authorised by the Staff.
        if combatEnemyInPlay and (gStates.unitReadyLinks==nil
            or gStates.unitReadyLinks[sourceKey]==nil) then return false end
        local choices=record.choices
        local _,first=currentChoice(guid,record.powered,choices)
        if record.powered~=true then return first=="red" end
        local remaining={}
        for _,option in ipairs(choices or {}) do
            if choiceCategory(option)~=first then remaining[#remaining+1]=option end
        end
        local _,second=inventorySetChoice(guid,1,remaining,choices)
        return second~=nil and first~=second and (first=="red" or second=="red")
    end
    if data~=nil and data.resourceKey=="artifactBannerCourage" then
        local card=getObjectFromGUID(guid)
        local current=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
        seatPos=seatPos or (current~=nil and current.seatPos)
        if card==nil or seatPos==nil then return false end
        if trackerPrivate.bannerCardForm(guid)=="full"
            and not resourceCardsArtifactBroken(guid,card) then return false end
        if trackerPrivate.bannerCardForm(guid)=="half"
            and card.is_face_down~=true then return false end
        if trackerPrivate.bannerCardForm(guid)=="full" then
            if not cardInSeatPlayArea(guid,seatPos)
                or cardPosture(card)~="upright" then return false end
            local uses=trackerPrivate.bannerEffectUses().courage[guid]
            for _,entry in ipairs(uses~=nil and uses.eligible or {}) do
                if entry.key==sourceKey then return true end
            end
            return false
        end
        if trackerPrivate.bannerCardForm(guid)~="half"
            or sourceKey~=guid then return false end
        -- Unit and play scripting zones overlap near the Banner snap.
        -- A face-down half still authorises exactly its own attached Unit.
        local state=unitLayoutResourceState(seatPos)
        for _,banners in pairs(state~=nil and state.bannersByUnit or {}) do
            if banners["Banner of Courage"]~=nil
                and banners["Banner of Courage"].guid==guid then return true end
        end
        return false
    end
    if data==nil or (data.resourceKey~="rejuvenate"
        and data.resourceKey~="regeneration"
        and data.resourceKey~="ruthlessCoercion") then return false end
    local card=getObjectFromGUID(guid)
    if card==nil or cardPosture(card)~="upright" then return false end
    local current=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    seatPos=seatPos or (current~=nil and current.seatPos)
    if seatPos==nil or not cardInSeatPlayArea(guid,seatPos) then return false end
    local scan=resourceCardScanBySeat[seatPos]
    local record=scan~=nil and scan.cards[guid] or nil
    if record==nil or record.complete~=true
        or (card.is_face_down==true and record.repeatLink==nil) then return false end
    if data.resourceKey=="ruthlessCoercion" then
        return record.powered==true
            and sourceKey:match("^"..guid.."#ready%d+$")~=nil
    end
    if data.resourceKey=="regeneration" then
        local index=tonumber(sourceKey:match("^"..guid.."#ready(%d+)$"))
        return index~=nil and index>=1 and index<=(record.repeatCount or 1)
            and record.resources~=nil and (tonumber(record.resources.healing) or 0)>0
    end
    local repeatIndex=tonumber(sourceKey:match("^"..guid.."#ready(%d+)$"))
    if record.repeatLink~=nil and repeatIndex~=nil then
        if repeatIndex<1 or repeatIndex>record.repeatLink.count then return false end
        local options=record.repeatLink.options~=nil
            and record.repeatLink.options[repeatIndex]
            or sideChoices(rule,record.powered)
        local _,selected=combatConfig.repeatChoiceFor(guid,record.powered,
            options,repeatIndex)
        return selected=="ready"
    end
    local choice=selectedResourceByGUID[guid]
    return (choice~=nil and choice.effect=="ready")
        or (choice==nil and gStates.unitReadyCardChoices~=nil
            and gStates.unitReadyCardChoices[guid]==true)
end

-- Used both when a new Ready link is made and when changing card sides
-- invalidates a previously valid target.
function resourceCardsReadySourceLevelLimit(sourceKey,seatPos)
    local guid=type(sourceKey)=="string" and unitHistorySourceBase(sourceKey) or nil
    local data=guid~=nil and gameCards[guid] or nil
    local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
    if rule==nil then return nil end
    local current=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    seatPos=seatPos or (current~=nil and current.seatPos)
    local scan=seatPos~=nil and resourceCardScanBySeat[seatPos] or nil
    local record=scan~=nil and scan.cards[guid] or nil
    if rule.unitReadyLevels~=nil then
        return record~=nil and record.powered and rule.unitReadyLevels.powered
            or rule.unitReadyLevels.normal
    end
    return rule.readyWithInfluence~=nil and rule.readyWithInfluence.maxLevel or nil
end

function resourceCardsReadyTargetEligible(sourceKey,unitGUID,seatPos)
    local guid=type(sourceKey)=="string" and unitHistorySourceBase(sourceKey) or nil
    local data=guid~=nil and gameCards[guid] or nil
    local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
    if rule==nil or rule.readyWithInfluence==nil then return true end
    if not resourceCardsReadySourceValid(sourceKey,seatPos) then return false end
    local unitData=gameCards[unitGUID]
    local level=unitData~=nil and tonumber(unitData.level) or nil
    if level==nil or level<1 or level>rule.readyWithInfluence.maxLevel then return false end
    local current=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    seatPos=seatPos or (current~=nil and current.seatPos)
    local scan=seatPos~=nil and resourceCardScanBySeat[seatPos] or nil
    if scan==nil then return false end
    local cost=level*rule.readyWithInfluence.costPerLevel
    -- The scan already subtracts every existing Ready payment. A retargeted
    -- existing link can reuse its previous payment instead of paying twice.
    local link=gStates.unitReadyLinks~=nil and gStates.unitReadyLinks[sourceKey] or nil
    local old=link~=nil and gameCards[link.unitGUID] or nil
    local credit=old~=nil and (tonumber(old.level) or 0)
        *rule.readyWithInfluence.costPerLevel or 0
    return (tonumber(scan.totals.influence) or 0)+credit>=cost
end

function attackAssignmentReadySourceClicked(player,value,id)
    if not resourceCardsPanelOpen() or not resourceCardsPlayerCanEdit(player~=nil and player.color or nil)
        or type(id)~="string" then return end
    local guid,suffix=id:match("^AttackAssignmentSource_([0-9a-f]+)_0_unitReady(.*)$")
    if guid==nil then return end
    local useIndex=tonumber(suffix:match("^@use(%d+)$"))
    if suffix~="" and useIndex==nil then return end
    local sourceKey=unitHistoryKey(guid,useIndex or 1)
    local data=gameCards~=nil and gameCards[guid] or nil
    if data~=nil and data.resourceKey=="artifactDruidicStaff"
        and combatEnemyInPlay then return end
    if not resourceCardsReadySourceValid(sourceKey) then return end
    local limit=unitResourceDefinitions[guid]~=nil and 2
        or resourceCardsReadySourceLevelLimit(sourceKey) 
    attackAssignmentsBeginUnitReady(guid,sourceKey,player.color,limit)
end

-- Command tokens remain spent for the entire round, even after the turn's
-- resource history is cleared. A physical Command still on a Unit must not be
-- treated as a new activation when its owner starts a later turn.
function resourceUnitsSpentCommands()
    local round=tonumber(gStates.currentRound) or 0
    local state=gStates.unitSpentCommandTokens
    if type(state)~="table" or state.round~=round then
        state={round=round,tokens={},owners={}}
        gStates.unitSpentCommandTokens=state
    end
    state.owners=state.owners or {}
    return state.tokens
end

function resourceUnitsCommandSpent(tokenGUID)
    return gStates~=nil and resourceUnitsSpentCommands()[tokenGUID]==true
end

-- A legitimate Ready lifts the Command's round-long exhaustion; undoing the
-- Ready reinstates it. These are history facts, not guesses from token height.
function resourceUnitsSetCommandSpent(tokenGUID,spent)
    if gStates==nil or tokenGUID==nil then return end
    resourceUnitsSpentCommands()[tokenGUID]=spent==true and true or nil
end

-- The token's GUID is its Command capacity; the owner GUID identifies the
-- Unit whose turn/round exhaustion it represents. A replacement must not
-- inherit its predecessor's spent flag, but moving the SAME Unit may not
-- erase it. Keep ownership alongside the existing round-long spent map.
function resourceUnitsCommandOwner(tokenGUID)
    if gStates==nil then return nil end
    resourceUnitsSpentCommands()
    return gStates.unitSpentCommandTokens.owners[tokenGUID]
end

function resourceUnitsRecordSpentCommands(seatPos)
    if gStates==nil or seatPos==nil then return end
    local spent=resourceUnitsSpentCommands()
    local owners=gStates.unitSpentCommandTokens.owners
    local layout=unitLayoutSnapshot(seatPos)
    for _,token in ipairs(layout.commands) do
        local unit=unitLayoutCommandTarget(token,seatPos)
        if unit~=nil then
            spent[token.guid]=true
            owners[token.guid]=unit.guid
        end
    end
end

-- Called once a NEW Unit owns a vacated Command position, not on token pickup.
-- Ordinary board movement is not an excuse to ready an old Unit: without an
-- approved recruit, the prior owner must truly have left every Unit Area.
function resourceUnitsAdoptCommand(tokenGUID,unitGUID,seatPos,approvedRecruit)
    if gStates==nil or tokenGUID==nil or unitGUID==nil then return false end
    resourceUnitsSpentCommands()
    local owners=gStates.unitSpentCommandTokens.owners
    local previous=owners[tokenGUID]
    if previous==unitGUID then return true end
    if approvedRecruit~=true then
        if previous==nil or unitLayoutObjectInAnyUnitArea(previous) then return false end
    end
    if previous~=nil and previous~=unitGUID
        and unitLayoutObjectInAnyUnitArea(previous)==false then
        if resourceUnitsRetireUnit~=nil then resourceUnitsRetireUnit(previous) end
    end
    resourceUnitsSetCommandSpent(tokenGUID,false)
    owners[tokenGUID]=unitGUID
    return true
end

-- The only generic disband cleanup: retire the Unit's choices/Ready links,
-- attack arrows and token number. Do not touch the spent Command flag here;
-- only an actual newly claimed Unit may ready that Command.
function resourceUnitsRetireUnit(unitGUID)
    if unitGUID==nil then return end
    if unitHistoryReleaseUnit~=nil then unitHistoryReleaseUnit(unitGUID) end
    removeChoiceButtons(getObjectFromGUID(unitGUID))
    choiceButtonShown[unitGUID]=nil
    choiceExpandedByGUID[unitGUID]=nil
    if gStates~=nil and gStates.unitReadyCardChoices~=nil then
        gStates.unitReadyCardChoices[unitGUID]=nil
    end
    if resourceCardsSourceChanged~=nil then resourceCardsSourceChanged() end
end

-- On a manually dragged replacement card, reconcile its settled physical
-- Command column. No reset happens for the same Unit or while the previous
-- owner is still on the Unit mat.
function resourceUnitsReconcileNewUnit(unitGUID,seatPos)
    if unitGUID==nil or seatPos==nil then return false end
    local layout=unitLayoutSnapshot(seatPos)
    local slot=layout.unitSlotByGuid[unitGUID]
    local token=slot~=nil and layout.commands[slot] or nil
    if token==nil then return false end
    local changed=resourceUnitsCommandOwner(token.guid)~=unitGUID
        and resourceUnitsAdoptCommand(token.guid,unitGUID,seatPos,false)
    if changed==true and resourceCardsSourceChanged~=nil then
        resourceCardsSourceChanged()
    end
    return changed==true
end

-- An activation belongs to the physical Command token that started it.
-- Dropping that token away from its Unit is an undo, not a spent ability:
-- discard its saved choice and remove its buttons and tracked contribution.
-- Returning the token to the same Unit preserves its selection.
local function resourceUnitsCancelMovedCommand(tokenGUID,seatPos,targetGUID)
    local activations=gStates~=nil and gStates.unitResourceActivations or nil
    if activations==nil then return false end
    local changed=false
    for unitGUID,activation in pairs(activations) do
        if activation.tokenGUID==tokenGUID and activation.seatPos==seatPos
            and unitGUID~=targetGUID then
            local sourceKey=targetGUID==nil and unitHistoryReadyPermission(unitGUID) or nil
            if sourceKey~=nil then
                -- This is a real Ready effect, not an undo. Preserve the
                -- contribution and wait for the Command token to return.
                unitHistoryMarkReady(unitGUID,sourceKey)
            else
                -- No linked Ready permission: lifting a Command token away
                -- from its Unit undoes only its latest activation.
                unitHistoryUndoLatest(unitGUID)
                removeChoiceButtons(getObjectFromGUID(unitGUID))
                choiceExpandedByGUID[unitGUID]=nil
            end
            changed=true
        end
    end
    return changed
end

-- The picked-up origin is transient; only completed activations belong in
-- saved state. A token placed back on its original Unit isn't a new play.
function resourceUnitsCommandPickedUp(playerColor,obj)
    if not resourceCardsPanelOpen() or obj==nil or not unitLayoutIsCommand(obj) then return end
    local current=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    if current==nil or legalPlayerCheck(playerColor,current.seatPos)~=true then return end
    local origin=unitLayoutCommandTarget(obj,current.seatPos)
    trackerPrivate.commandPickupForUnits[obj.guid]={seatPos=current.seatPos,
        turnNumber=gStates.turnNumber,origin=origin~=nil and origin.guid or nil}
end

function resourceUnitsCommandDropped(playerColor,obj)
    if not resourceCardsPanelOpen() or obj==nil or not unitLayoutIsCommand(obj) then return end
    local pickup=trackerPrivate.commandPickupForUnits[obj.guid]
    trackerPrivate.commandPickupForUnits[obj.guid]=nil
    if pickup==nil or not resourceCardsPanelOpen() then return end
    local guid=obj.guid
    local serial=trackerPrivate.trackerSession
    safeWaitCondition("PlayerBoard.CardRecognition",function()
        if not resourceCardsPanelOpen() or trackerPrivate.trackerSession~=serial then return end
        local current=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
        if current==nil or current.seatPos~=pickup.seatPos
            or gStates.turnNumber~=pickup.turnNumber then return end
        local token=getObjectFromGUID(guid)
        local unit=token~=nil and unitLayoutCommandTarget(token,pickup.seatPos) or nil
        local targetGUID=unit~=nil and unit.guid or nil
        if resourceUnitsCancelMovedCommand(guid,pickup.seatPos,targetGUID) then
            queueSeat(pickup.seatPos,nil)
        end
        if unit==nil then unitHistoryPriorTurnCommandMoved(guid,pickup.seatPos) end
        if unit==nil or unit.guid==pickup.origin
            or unitResourceDefinitions[unit.guid]==nil then return end
        local state=unitLayoutResourceState(pickup.seatPos)
        if state==nil then return end
        for _,entry in ipairs(state.units) do
            if entry.guid==unit.guid and not entry.unwounded then return end
        end
        -- Choose an unpowered default only. Physical mana overrides it
        -- automatically when a particular paid ability is unambiguous.
        local abilities=unitResourceDefinitions[unit.guid]
        local scores=trackerChoiceScores(unit.guid,pickup.seatPos)
        local choice,bestScore=1,-math.huge
        for i,ability in ipairs(abilities) do
            if ability.manaCost==nil then
                local score=scores[ability.key] or 0
                if score>bestScore then choice,bestScore=i,score end
            end
        end
        gStates.unitResourceActivations=gStates.unitResourceActivations or {}
        -- A new Unit claimed into this Command's slot is Ready even if the
        -- former Unit used this token earlier in the same Round.
        resourceUnitsAdoptCommand(guid,unit.guid,pickup.seatPos,false)
        local previous=gStates.unitResourceActivations[unit.guid]
        local newActivation={seatPos=pickup.seatPos,tokenGUID=guid,
            choice=choice,selected=abilities.multi==true and {} or nil}
        local useIndex=1
        local permission=unitHistoryAwaiting(unit.guid)
            or unitHistoryReadyPermission(unit.guid)
        if previous~=nil or resourceUnitsCommandSpent(guid) or permission~=nil then
            if permission==nil or (previous~=nil and previous.tokenGUID~=guid) then return end
            local appendedIndex=unitHistoryAppend(unit.guid,newActivation,permission)
            if appendedIndex==nil then return end
            useIndex=appendedIndex
        else
            gStates.unitResourceActivations[unit.guid]=newActivation
            unitHistoryEnsure(unit.guid,newActivation)
            unitHistoryRefreshToken(unit.guid)
        end
        -- A newly used Command must remember which physical Unit owns it,
        -- independent of the current turn's activation-history snapshots.
        resourceUnitsSpentCommands()
        gStates.unitSpentCommandTokens.owners[guid]=unit.guid
        resourceCardsCombatSelectOneUnit(unit.guid)
        choiceExpandedByGUID[unit.guid]=nil
        -- The final settled scan owns the choice and target buttons. Painting
        -- them here used an older combatCalcOn state, which could show a
        -- choice but omit its enemy target (or immediately erase both).
        queueSeat(pickup.seatPos,nil)
    end,function()
        if not resourceCardsPanelOpen() or trackerPrivate.trackerSession~=serial then return true end
        local token=getObjectFromGUID(guid)
        return token==nil or trackerPrivate.readyForXZ(token)
    end,8)
end

-- A Unit's choice can switch its targeting key (e.g. Shocktroops
-- Ranged 1 -> Armour -1). Retire obsolete arrow keys and calculator locks
-- immediately, keeping explicitly targeted effects whose keys stay active.
-- The next scan then auto-targets newly selected effects just like attacks.
function resourceUnitsReconcileChoiceTargets(unit,abilities,activation)
    -- A changed historical choice may retire only THAT use's target. The
    -- other activations of this same physical Unit keep their own arrows.
    local allowed={}
    local current=gStates~=nil and gStates.unitResourceActivations
        and gStates.unitResourceActivations[unit.guid] or activation
    for useIndex,entry in ipairs(unitHistoryUses(unit.guid,current)) do
        local decision=unitManaDecision(unit,abilities,entry,
            entry.frozenCounts or entry.lastCounts)
        local combatBlocked=combatConfig.unitCombatBlocked(unit,abilities,useIndex)
        local function allow(index)
            local ability=abilities[index]
            if ability~=nil and not (combatBlocked and unitHistoryIsCombatAbility(ability))
                and (unitAbilityTargetCategory(ability)~=nil
                or ability.enemyEffect~=nil or ability.targetableEnemy==true) then
                allowed[unitAbilityTargetKey(unit.guid,index,ability,useIndex)]=true
                -- Preserve the numeric attack target beside its separate
                -- enemy-effect target, including earlier Command uses.
                if ability.enemyEffect~=nil and unitAbilityTargetCategory(ability)~=nil then
                    allowed[unitHistoryKey(unit.guid,useIndex)]=true
                end
            end
        end
        if abilities.multi==true then
            for index in pairs(decision.selected or {}) do allow(index) end
        elseif decision.index~=nil then
            allow(decision.index)
        end
    end
    local prefix=unit.guid.."#"
    for key in pairs(combatAssignmentState.targets) do
        if (key==unit.guid or key:sub(1,#prefix)==prefix)
            and allowed[key]~=true then
            combatAssignmentState.targets[key]=nil
            combatAssignmentState.explicit[key]=nil
            if combatAssignmentState.selected==key then
                combatAssignmentState.selected=nil
            end
        end
    end
    attackAssignmentsPruneUnitChoiceSources(unit.guid,allowed)
end

function resourceUnitsPruneHistoricalTargets(unitGUID)
    local activation=gStates~=nil and gStates.unitResourceActivations
        and gStates.unitResourceActivations[unitGUID] or nil
    local unit=getObjectFromGUID(unitGUID)
    local abilities=trackerPrivate.unitAbilitiesFor(unitGUID,nil,
        activation~=nil and activation.seatPos or nil)
    if activation~=nil and unit~=nil and abilities~=nil then
        resourceUnitsReconcileChoiceTargets(unit,abilities,activation)
    elseif attackAssignmentsPruneUnitChoiceSources~=nil then
        attackAssignmentsPruneUnitChoiceSources(unitGUID,{})
    end
end

function resourceUnitsChoiceClicked(player,value,id)
    if not resourceCardsPanelOpen() or type(id)~="string"
        or not resourceCardsPlayerCanEdit(player~=nil and player.color or nil) then return end
    local unitGUID,index=id:match("^ResourceCardChoice_([0-9a-f]+)_unit(%d+)Combat$")
    local combatMoveChoice=unitGUID~=nil
    -- The visible Unit button is removed on refresh, but an in-flight click
    -- must also be rejected when there is no Cumbersome target.
    if combatMoveChoice and not (combatCalcOn and combatCumbersomeActive) then return end
    if unitGUID==nil then
        unitGUID,index=id:match("^ResourceCardChoice_([0-9a-f]+)_unit(%d+)$")
    end
    index=tonumber(index)
    local latest=unitGUID~=nil and gStates.unitResourceActivations
        and gStates.unitResourceActivations[unitGUID] or nil
    local activation,useIndex=unitHistorySelected(unitGUID,latest)
    local current=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    local abilities=unitGUID~=nil and trackerPrivate.unitAbilitiesFor(
        unitGUID,nil,current~=nil and current.seatPos) or nil
    if activation==nil or abilities==nil or current==nil or index==nil
        or abilities[index]==nil or activation.seatPos~=current.seatPos then return end
    local unit=getObjectFromGUID(unitGUID)
    if unit==nil then return end
    resourceCardsCombatSelectOneUnit(unitGUID)
    local state=unitLayoutResourceState(current.seatPos)
    if state==nil then return end
    for _,entry in ipairs(state.units) do
        if entry.guid==unitGUID and not entry.unwounded then return end
    end
    local decision=unitManaDecision(unit,abilities,activation,
        activation.frozenCounts)
    local available=false
    for _,candidate in ipairs(decision.display) do
        if candidate==index then available=true break end
    end
    if not available then return end
    if (not decision.ambiguous or abilities.paidChoiceExpandable or decision.index~=nil)
        and choiceExpandedByGUID[unitGUID]~=true and #decision.display>1
        and (tonumber(abilities[index].move) or 0)==0 then
        -- Expanding ordinary choices does not change what was played.
        choiceExpandedByGUID[unitGUID]=true
        showUnitAbilityButtons(unit,abilities,activation,true,decision)
        return
    end
    if abilities.bannerFearIndex~=nil and index==abilities.bannerFearIndex then
        activation.choice=index
        activation.bannerFearSelected=true
        activation.manaChoice=nil
        activation.lastPaidIndex=nil
        choiceExpandedByGUID[unitGUID]=nil
    elseif abilities.multi==true then
        activation.bannerFearSelected=nil
        -- Gold payments may be assigned to several different abilities, but
        -- never more abilities than the actual number of Gold tokens.
        -- Choosing another button reassigns Gold instead of silently
        -- preserving an older choice the player can no longer see as active.
        activation.selected=activation.selected or {}
        if activation.manaSignature~=decision.signature then activation.selected={} end
        activation.manaSignature=decision.signature
        if decision.selected[index]==true then
            activation.selected[index]=nil
        else
            local goldCount=((activation.frozenCounts
                or unitManaCounts(unit,current.seatPos)).Gold or 0)
            local prior={}
            for _,candidate in ipairs(decision.display) do
                if candidate~=index and activation.selected[candidate]==true then
                    prior[#prior+1]=candidate
                end
            end
            while #prior>=goldCount and #prior>0 do
                activation.selected[table.remove(prior,1)]=nil
            end
            activation.selected[index]=true
        end
        choiceExpandedByGUID[unitGUID]=true
    elseif decision.ambiguous then
        activation.bannerFearSelected=nil
        activation.manaChoice=index
        activation.manaSignature=decision.signature
        -- Once a payable alternative is selected, collapse to its icon and
        -- restore the target button, regardless of the Unit's display style.
        choiceExpandedByGUID[unitGUID]=nil
    else
        activation.bannerFearSelected=nil
        activation.choice=index
        activation.manaChoice=nil
        activation.manaSignature=nil
        activation.lastPaidIndex=nil
        choiceExpandedByGUID[unitGUID]=nil
    end
    if (tonumber(abilities[index].move) or 0)>0 then
        gStates.resourceCardMoveRoles=gStates.resourceCardMoveRoles or {}
        local sourceKey=unitHistoryKey(unitGUID,useIndex)
        local before=resourceCardsMoveRole(sourceKey,true)
        gStates.resourceCardMoveRoles[sourceKey]=combatMoveChoice and "combat" or "movement"
        if before=="combat" and not combatMoveChoice then
            attackAssignmentsClearForObject(sourceKey)
        end
    end
    resourceUnitsReconcileChoiceTargets(unit,abilities,activation)
    unitHistoryValidSources(current.seatPos)
    showUnitAbilityButtons(unit,abilities,activation,true,nil,useIndex)
    if attackAssignmentsRefreshReadyUI~=nil then attackAssignmentsRefreshReadyUI() end
    -- Recalculate Unit choices immediately; enemy modifiers are shown directly
    -- in the Combat Calculator rather than broadcast into chat.
    renderSeat(current.seatPos)
end

-- Release a temporary offered Unit without touching Command activations.
function resourceUnitsBorrowedUnitEnded(guid)
    local activation=gStates~=nil and gStates.unitResourceActivations
        and gStates.unitResourceActivations[guid] or nil
    if activation~=nil and activation.callOffer==true then
        gStates.unitResourceActivations[guid]=nil
    end
    -- Retire the old Unit's combat source first. A failed Object UI update
    -- must never leave its target arrow behind when Call to Arms cycles.
    combatForgetPhysicalSourceTargets(guid)
    if attackAssignmentsClearForObject~=nil then attackAssignmentsClearForObject(guid) end
    if attackAssignmentsPruneUnitChoiceSources~=nil then
        attackAssignmentsPruneUnitChoiceSources(guid,{})
    end
    removeChoiceButtons(getObjectFromGUID(guid))
    choiceButtonShown[guid]=nil
    choiceExpandedByGUID[guid]=nil
    if resourceCardsPanelOpen() then resourceCardsSourceChanged() end
end

-- Clear any remaining activations at turn end without moving Command tokens.
-- A token moved off its Unit during the turn cancels immediately on its drop.
function resourceUnitsResetTurn()
    if gStates~=nil then
        for unitGUID in pairs(gStates.unitResourceActivations or {}) do
            removeChoiceButtons(getObjectFromGUID(unitGUID))
            choiceExpandedByGUID[unitGUID]=nil
        end
        unitHistoryReset()
        gStates.unitReadyCardChoices={}
        gStates.unitResourceActivations={}
    end
    trackerPrivate.commandPickupForUnits={}
    if attackAssignmentsRefreshReadyUI~=nil then attackAssignmentsRefreshReadyUI() end
end

-- There is one owner for Unit control rendering: the settled Resource Tracker
-- scan, after combat presence, payment, wound and site restrictions are known.
-- Token-history arrows and other callers request that scan, not an early paint.
function resourceUnitsRefreshButtons()
    if not resourceCardsPanelOpen() or gStates==nil
        or next(gStates.unitResourceActivations or {})==nil then return end
    resourceCardsSourceChanged()
end

-- Reconstruct used Units from Command tokens physically sitting on their cards.
-- Command tokens in ready slots do not count as activations.
local function resourceUnitsRebuildFromTable()
    if not resourceCardsPanelOpen() or gStates==nil then return end
    local current=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    if current==nil then return end
    local seat=current.seatPos
    local layout=unitLayoutSnapshot(seat)
    local state=unitLayoutResourceState(seat)
    local unwounded={}
    for _,entry in ipairs(state~=nil and state.units or {}) do
        unwounded[entry.guid]=entry.unwounded
    end
    local activations={}
    for _,token in ipairs(layout.commands) do
        local unit=unitLayoutCommandTarget(token,seat)
        local abilities=unit~=nil and unitResourceDefinitions[unit.guid] or nil
        if unit~=nil and abilities~=nil and unwounded[unit.guid]
            and activations[unit.guid]==nil and not resourceUnitsCommandSpent(token.guid) then
            local scores=trackerChoiceScores(unit.guid,seat)
            local choice,bestScore=1,-math.huge
            for i,ability in ipairs(abilities) do
                if ability.manaCost==nil then
                    local score=scores[ability.key] or 0
                    if score>bestScore then choice,bestScore=i,score end
                end
            end
            local activation={seatPos=seat,tokenGUID=token.guid,choice=choice,
                selected=abilities.multi==true and {} or nil}
            activations[unit.guid]=activation
            -- A Ready completed while the panel was closed still belongs to
            -- the current turn, never to the previous spent anchor.
            local awaiting=unitHistoryAwaiting(unit.guid)
            if awaiting~=nil then
                unitHistoryAppend(unit.guid,activation,awaiting)
            else
                unitHistoryEnsure(unit.guid,activation)
            end
        end
    end
    gStates.unitResourceActivations=activations
    for guid in pairs(activations) do unitHistoryRefreshToken(guid) end
end

-- Explicit card choices represent player decisions rather than reconstructable table state.
-- Save only choices for cards still in the current player's play/unit areas.
trackerPrivate.copyCardSelection=function(selection,fromSave)
    if type(selection)~="table" then return nil end
    local result={}
    for _,field in ipairs({"effect","sideways"}) do
        if type(selection[field])=="string" then result[field]=selection[field] end
    end
    for _,field in ipairs({"repeatChoices","inventorySets"}) do
        local entries={}
        if fromSave then
            for _,entry in ipairs(type(selection[field])=="table" and selection[field] or {}) do
                local index=type(entry)=="table" and tonumber(entry.index) or nil
                if index~=nil and index>=1 and index%1==0 and type(entry.choice)=="string" then
                    entries[index]=entry.choice
                end
            end
        else
            for index,choice in pairs(type(selection[field])=="table" and selection[field] or {}) do
                if type(index)=="number" and index>=1 and index%1==0 and type(choice)=="string" then
                    entries[#entries+1]={index=index,choice=choice}
                end
            end
            table.sort(entries,function(a,b) return a.index<b.index end)
        end
        if next(entries)~=nil then result[field]=entries end
    end
    return next(result)~=nil and result or nil
end

function resourceCardsChoicesSave()
    if gStates==nil then return end
    local selected={}
    local active=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    if active~=nil and active.seatPos~=nil then
        local present={}
        for _,zoneGUID in ipairs({playerPlayAreas[active.seatPos],playerUnitAreas[active.seatPos]}) do
            local zone=zoneGUID~=nil and getObjectFromGUID(zoneGUID) or nil
            if zone~=nil then
                for _,obj in ipairs(zone.getObjects()) do present[obj.guid]=true end
            end
        end
        for guid,selection in pairs(selectedResourceByGUID) do
            if present[guid]==true and gameCards[guid]~=nil then
                selected[guid]=trackerPrivate.copyCardSelection(selection,false)
            end
        end
    end
    gStates.resourceCardSelectedChoices=selected
end

function resourceCardsChoicesRestore()
    selectedResourceByGUID={}
    local stored=gStates~=nil and gStates.resourceCardSelectedChoices or nil
    if type(stored)~="table" then return end
    for guid,selection in pairs(stored) do
        if type(guid)=="string" and gameCards[guid]~=nil then
            selectedResourceByGUID[guid]=trackerPrivate.copyCardSelection(selection,true)
        end
    end
end

function resourceCardsPanelChanged(open)
    local current=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    if open==true and (current==nil or not resourceCardsSeatEnabled(current.seatPos)) then return end
    -- A newly shown panel may need a frame before TTS reports its attributes.
    -- That temporary state is not a player-requested OFF transition.
    if open==true and not resourceCardsPanelReady() then return end
    trackerPrivate.trackerStartupRequest=trackerPrivate.trackerStartupRequest+1
    if open~=true then
        -- Closing the tracker cancels a pending decision, not a physical
        -- transaction whose rewind point is already being stored.
        if combatConfig.woundConfirmation~=nil then
            combatConfig.woundConfirmClose()
        end
        trackerPrivate.trackerWasDisabled=true
        trackerPrivate.trackerSession=trackerPrivate.trackerSession+1
        -- Turn the tracker completely off: stop callbacks and remove its visuals.
        combatCalcShutdown()
        clearAll()
        unitHistoryHideControls()
        for guid in pairs(trackerPrivate.choiceResetGenerationByGUID) do
            trackerPrivate.choiceResetGenerationByGUID[guid]=trackerPrivate.choiceResetGenerationByGUID[guid]+1
        end
        trackerPrivate.crystalHighlightCleared={}
        trackerPrivate.unitHighlightBlocked={}
        -- Fresh starts never inherit manual resource offsets or an old avatar position.
        -- Keep moveCost: those are real day/night and manually adjusted terrain rules.
        local tracker=gStates~=nil and gStates.resourceTracker or nil
        if tracker~=nil then
            for _,category in ipairs({"move","influence","healing"}) do
                for field,value in pairs(tracker[category] or {}) do
                    if type(value)=="number" and not (category=="influence" and field=="reputation") then
                        tracker[category][field]=0
                    end
                end
            end
            tracker.playerPos=nil
        end
        clearMoveDisplayVisuals()
        if refreshUnitOfferHighlights~=nil then refreshUnitOfferHighlights() end
        return
    end
    -- Expanding after an OFF period rebuilds from scratch, not cached choices.
    local restart=trackerPrivate.trackerWasDisabled
    trackerPrivate.trackerWasDisabled=false
    if restart then refreshResourceTrackerReputation() end
    clearAll()
    if invalidateResourceTrackerDisplayCache~=nil then invalidateResourceTrackerDisplayCache() end
    unitHistoryRestoreCurrent()
    for guid,ready in pairs(gStates.unitReadyCardChoices or {}) do
        if ready and selectedResourceByGUID[guid]==nil then
            selectedResourceByGUID[guid]={effect="ready"}
        end
    end
    if restart and next(gStates.unitResourceActivations or {})==nil then
        resourceUnitsRebuildFromTable()
    end
    for guid in pairs(gStates.unitResourceActivations or {}) do
        unitHistoryRefreshToken(guid)
    end
    if attackAssignmentsRefreshReadyUI~=nil then attackAssignmentsRefreshReadyUI() end
    resourceUnitsRefreshButtons()
    if refreshUnitOfferHighlights~=nil then refreshUnitOfferHighlights() end
    local player=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    if player==nil then return end
    local seat=player.seatPos
    -- TTS may not expose the just-set ResourceTrackerDetail.active attribute
    -- until the next UI update. queueSeat rejects closed panels immediately,
    -- so invoking it in the same button callback could silently lose the scan.
    -- Wait only while opening, then read every physical object exactly once.
    local serial=trackerPrivate.generation[seat]
    safeWaitCondition("PlayerBoard.CardRecognition",function()
        if trackerPrivate.generation[seat]==serial and resourceCardsPanelOpen() then
            renderSeat(seat)
        end
    end,function()
        -- Closing or reopening the panel invalidates this pending request.
        return trackerPrivate.generation[seat]~=serial or resourceCardsPanelOpen()
    end,1)
end

-- Clear the outgoing seat before changing turnNumber so rewards, overlays,
-- damage previews and locks cannot leak into the next player's combat.
function resourceCardsBeforeTurnHandoff(nextSeat)
    if gStates==nil or gStates.firstStarted~=true then return end
    local current=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    if current==nil or current.seatPos==nextSeat then return end
    resourceCardsPanelChanged(false)
    resourceUnitsResetTurn()
    selectedResourceByGUID={}
    if gStates~=nil then gStates.resourceCardMoveRoles={} end
end

-- The Global UI is shared, but its expanded/collapsed preference belongs to a seat.
function resourceCardsAfterTurnHandoff(previousSeat)
    if gStates==nil or gStates.firstStarted~=true then return end
    local current=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    if current==nil or current.seatPos==previousSeat then return end
    local enabled=resourceCardsSeatEnabled(current.seatPos)
    UI.setAttribute("CombatCalculatorHelp","active","false")
    UI.setAttribute("ResourceTrackerDetail","active",enabled and "true" or "false")
    -- The previous seat may have left terrain/combat submenus expanded.
    -- Preserve their visibility without squeezing them into the default height.
    resourceTrackerSyncLayout(enabled)
    if enabled then resourceCardsOnLoad() end
end

-- Shared by saved-game load, first-game setup and re-expanding the panel.
-- Wait for the actual UI state rather than treating startup's collapsed XML
-- defaults as a player pressing OFF. Explicit minimization cancels this wait.
function resourceCardsOnLoad(restoringSave)
    if restoringSave==true then trackerPrivate.restoreAssignmentsPending=true end
    if gStates==nil or gStates.firstStarted~=true then return end
    local current=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    if current~=nil and not resourceCardsSeatEnabled(current.seatPos) then
        UI.setAttribute("ResourceTrackerDetail","active","false")
        resourceTrackerSyncLayout(false)
        resourceCardsPanelChanged(false)
        return
    end
    -- TTS rewinds rebuild Global XML with a 35px collapsed root. Size the
    -- tracker first, then reveal its details, so the lower-anchored contents
    -- cannot cover the header/minimize button during the load transition.
    if restoringSave==true and current~=nil then
        resourceTrackerRestoreExpandedLayout()
    elseif UI.getAttribute("ResourceTrackerDetail","active")=="true" then
        -- Normal reopen/turn handoff keeps any chosen nested sections.
        resourceTrackerSyncLayout(true)
    end
    trackerPrivate.trackerStartupRequest=trackerPrivate.trackerStartupRequest+1
    local request=trackerPrivate.trackerStartupRequest
    safeWaitCondition("PlayerBoard.CardRecognition",function()
        if trackerPrivate.trackerStartupRequest==request and resourceCardsPanelReady() then
            if trackerPrivate.restoreAssignmentsPending==true then
                trackerPrivate.restoreAssignmentsPending=false
                attackAssignmentsRestore()
            end
            resourceCardsPanelChanged(true)
        end
    end,function()
        return trackerPrivate.trackerStartupRequest~=request or resourceCardsPanelReady()
    end,5,function()
        -- A panel that is still collapsed after the readiness wait stays
        -- OFF; it must never scan until the player explicitly expands it.
        if trackerPrivate.trackerStartupRequest==request and not resourceCardsPanelReady() then
            resourceCardsPanelChanged(false)
        end
    end)
end

local function resourceCardsRelevantZone(ctx)
    if ctx==nil or ctx.zoneInfo==nil or ctx.obj==nil then return nil end
    -- The tracker only renders the active Mage Knight's board; ignore other seats early.
    local active=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    if active==nil or active.seatPos~=ctx.zoneInfo.seatPos then return nil end
    local kind=ctx.zoneInfo.kind
    -- A moving die is mana even though its face cannot yet be read safely.
    local objectKind=(ctx.objType=="Dice" and scriptObjectId(ctx.obj)=="Mana Dice")
        and "mana" or resourceObjectKind(ctx.obj)
    if kind=="play" and (objectKind~=nil or combatEnemyData(ctx.objGUID,ctx.obj)~=nil) then
        return ctx.zoneInfo.seatPos
    end
    if kind=="unit" and (objectKind=="unit" or objectKind=="mana" or objectKind=="puppet"
        or combatEnemyData(ctx.objGUID,ctx.obj)~=nil
        or unitLayoutIsCommand(ctx.obj) or unitLayoutIsWound(ctx.obj)) then
        return ctx.zoneInfo.seatPos
    end
    if kind=="crystal" and objectKind=="mana" then return ctx.zoneInfo.seatPos end
    if kind=="hand" and objectKind=="wound" then return ctx.zoneInfo.seatPos end
    return nil
end

-- Mark played cards while dragged, so zone callbacks cannot publish an
-- intermediate 'card absent' calculation and overwrite a chosen target.
function resourceCardsObjectPickedUp(obj)
    if obj==nil or obj.guid==nil or not resourceCardsPanelOpen()
        or not trackerPrivate.playCandidateKind(resourceObjectKind(obj)) then return end
    local active=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    if active==nil then return end
    local seat=active.seatPos
    local candidates=trackerPrivate.playCandidatesBySeat[seat]
    local previous=trackerPrivate.bySeat[seat]
    if (candidates~=nil and candidates[obj.guid]==true)
        or (previous~=nil and previous[obj.guid]==true)
        or cardInSeatPlayArea(obj.guid,seat) then
        -- A second pickup invalidates the first drop's pending callbacks.
        -- Capture what the player actually chose; a scan must not replace
        -- these choices or enemy targets with the nearest/default ones.
        local savedTargets={}
        local prefix=obj.guid.."#"
        for sourceKey,targetGUID in pairs(combatAssignmentState.targets or {}) do
            if sourceKey==obj.guid or sourceKey:sub(1,#prefix)==prefix then
                savedTargets[sourceKey]={targetGUID=targetGUID,
                    explicit=combatAssignmentState.explicit[sourceKey]==true}
            end
        end
        trackerPrivate.playCardMovements[obj.guid]={
            seatPos=seat,choice=selectedResourceByGUID[obj.guid],
            targets=savedTargets,posture=cardPosture(obj),
            faceDown=obj.is_face_down
        }
        if trackerPrivate.traceEnabled then
            trackerPrivate.traceEvent("move.pickup",seat,obj.guid,
                "held="..tostring(obj.held_by_color))
        end
        -- A normal Drop is not guaranteed (e.g. the native U/Place Under
        -- action). Watch every known pickup until the object is released.
        trackerPrivate.finishPlayCardMove(obj)
    end
end

-- Restore the player's source decisions before a completed drop recalculates.
-- This is runtime-only and applies only while the original card remains on
-- the same Play Area. Deliberate sideways/flipped play can change targeting.
trackerPrivate.restorePlayCardMove=function(obj,state)
    if state==nil or obj==nil
        or not cardInSeatPlayArea(obj.guid,state.seatPos) then return end
    if state.choice~=nil then
        selectedResourceByGUID[obj.guid]=state.choice
    end
    if state.posture~=cardPosture(obj)
        or state.faceDown~=obj.is_face_down then return end
    for sourceKey,saved in pairs(state.targets or {}) do
        if saved.targetGUID~=nil then
            combatAssignmentState.targets[sourceKey]=saved.targetGUID
            combatAssignmentState.explicit[sourceKey]=saved.explicit
        end
    end
end

-- A card may still be falling in Y when its X/Z and rotation are final.
-- Observe those values for three frames instead of waiting for 'resting'.
trackerPrivate.finishPlayCardMove=function(obj)
    local state=obj~=nil and trackerPrivate.playCardMovements[obj.guid] or nil
    if state==nil or state.releasing then return end
    state.releasing=true
    state.samples=0
    state.consecutive=0
    state.last=nil
    local guid=obj.guid
    if trackerPrivate.traceEnabled then trackerPrivate.traceEvent("move.watch",state.seatPos,guid) end
    local function sample()
        if trackerPrivate.playCardMovements[guid]~=state then return end
        local live=getObjectFromGUID(guid)
        if live==nil or (live.isDestroyed~=nil and live.isDestroyed()) then
            trackerPrivate.playCardMovements[guid]=nil
            if trackerPrivate.traceEnabled then trackerPrivate.traceEvent("move.gone",state.seatPos,guid) end
            queueSeat(state.seatPos,nil)
            return
        end
        state.samples=state.samples+1
        local held=live.held_by_color~=nil and live.held_by_color~=""
        local smooth=live.isSmoothMoving()
        if held or smooth then
            -- Never abandon the watcher with the movement lock still set.
            -- A missed onObjectDrop (notably U/Place Under) must not freeze
            -- every future option button and combat calculator refresh.
            if trackerPrivate.traceEnabled and (state.samples==1 or state.samples%90==0) then
                trackerPrivate.traceEvent("move.wait",state.seatPos,guid,
                    "held="..tostring(held).." smooth="..tostring(smooth)
                    .." samples="..state.samples)
            end
            safeWaitFrames("PlayerBoard.CardRecognition",sample,held and 6 or 3)
            return
        end
        local pos=live.getPosition()
        local rot=live.getRotation()
        local now={x=pos.x or pos[1],z=pos.z or pos[3],
            rx=rot.x or rot[1],ry=rot.y or rot[2],rz=rot.z or rot[3],
            face=live.is_face_down}
        local previous=state.last
        local function angleDifference(a,b)
            return math.abs(((a or 0)-(b or 0)+180)%360-180)
        end
        if previous~=nil
            and math.abs(now.x-previous.x)<0.04
            and math.abs(now.z-previous.z)<0.04
            and angleDifference(now.rx,previous.rx)<1
            and angleDifference(now.ry,previous.ry)<1
            and angleDifference(now.rz,previous.rz)<1
            and now.face==previous.face then
            state.consecutive=state.consecutive+1
        else
            state.consecutive=0
        end
        state.last=now
        if state.consecutive<2 and state.samples<24 then
            safeWaitFrames("PlayerBoard.CardRecognition",sample,1)
            return
        end
        trackerPrivate.restorePlayCardMove(live,state)
        trackerPrivate.playCardMovements[guid]=nil
        if trackerPrivate.traceEnabled then
            trackerPrivate.traceEvent("move.complete",state.seatPos,guid,
                "samples="..state.samples.." onMat="..tostring(cardInSeatPlayArea(guid,state.seatPos)))
        end
        -- Resume a single complete scan; normal drop handling determines
        -- whether this was a reposition or a genuine departure from play.
        resourceCardsObjectMoved(live,true)
        queueSeat(state.seatPos,nil)
    end
    safeWaitFrames("PlayerBoard.CardRecognition",sample,1)
end

-- Native TTS Place Under (U) does not promise a pickup/drop or zone change.
-- Mark existing play sources before the action, then reconcile the target(s)
-- after TTS has applied it, including non-Card Skills and Faction Rewards.
function resourceCardsUnderAction(targets)
    if not resourceCardsPanelOpen() then return end
    local active=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    local seat=active~=nil and active.seatPos or nil
    local zoneGUID=seat~=nil and playerPlayAreas~=nil and playerPlayAreas[seat] or nil
    local playZone=zoneGUID~=nil and getObjectFromGUID(zoneGUID) or nil
    local guids,playedCardUnder={},false
    for _,obj in ipairs(targets or {}) do
        if obj~=nil and obj.guid~=nil then
            guids[#guids+1]=obj.guid
            if playZone~=nil and trackerPrivate.playCandidateKind(resourceObjectKind(obj))
                and trackerPrivate.zoneFootprintContainsXZ(obj,playZone) then
                playedCardUnder=true
            end
            if trackerPrivate.traceEnabled then
                trackerPrivate.traceEvent("action.under",seat,obj.guid)
            end
            resourceCardsObjectPickedUp(obj)
        end
    end
    if #guids==0 then return end
    local session=trackerPrivate.trackerSession
    safeWaitFrames("PlayerBoard.CardRecognition",function()
        if trackerPrivate.trackerSession~=session or not resourceCardsPanelOpen() then return end
        for _,guid in ipairs(guids) do
            local obj=getObjectFromGUID(guid)
            if obj~=nil and (obj.isDestroyed==nil or not obj.isDestroyed()) then
                resourceCardsObjectMoved(obj)
            end
        end
        -- Native Under changes card height, sometimes nudging a die that was
        -- above the deliberately shallow play zone. It may not emit a Die
        -- pickup/drop/zone event. Discover only mana dice above this play mat,
        -- on this rare action, and refresh their visible faces.
        if playedCardUnder and seat~=nil then
            local candidates=trackerPrivate.unitManaCandidatesBySeat[seat]
            if candidates==nil then
                candidates={}
                trackerPrivate.unitManaCandidatesBySeat[seat]=candidates
            end
            for _,obj in ipairs(getAllObjects()) do
                if obj.type=="Dice" and scriptObjectId(obj)=="Mana Dice"
                    and trackerPrivate.zoneFootprintContainsXZ(obj,playZone) then
                    candidates[obj.guid]=true
                    if trackerPrivate.traceEnabled then
                        trackerPrivate.traceEvent("under.mana",seat,obj.guid,
                            "resting="..tostring(obj.resting))
                    end
                    queueSeat(seat,obj.guid)
                end
            end
            -- If TTS starts jostling the die after its first frame, sample
            -- again; a slight wobble no longer blocks mana recognition.
            safeWaitFrames("PlayerBoard.CardRecognition",function()
                if trackerPrivate.trackerSession~=session
                    or not resourceCardsPanelOpen() then return end
                for guid in pairs(candidates) do
                    local die=getObjectFromGUID(guid)
                    if die~=nil and die.type=="Dice"
                        and trackerPrivate.zoneFootprintContainsXZ(die,playZone) then
                        queueSeat(seat,guid)
                    end
                end
                resourceCardsSourceChanged()
            end,22)
        end
        resourceCardsSourceChanged()
    end,2)
end

function resourceCardsZoneEntered(ctx)
    if not resourceCardsPanelOpen() or ctx==nil or ctx.zoneInfo==nil then return end
    -- Filter irrelevant zones and other players before touching the Unit layout.
    local seat=resourceCardsRelevantZone(ctx)
    if seat==nil then return end
    if trackerPrivate.traceEnabled then
        trackerPrivate.traceEvent("zone.enter",seat,ctx.objGUID,ctx.zoneInfo.kind)
    end
    if ctx.zoneInfo.kind=="play" and ctx.objType~="Dice"
        and trackerPrivate.playCandidateKind(resourceObjectKind(ctx.obj)) then
        -- A returned card invalidates any delayed choice-clear queued by its
        -- earlier onExitZone. The exit callback must never win after reentry.
        trackerPrivate.choiceResetGenerationByGUID[ctx.objGUID]=
            (trackerPrivate.choiceResetGenerationByGUID[ctx.objGUID] or 0)+1
        trackerPrivate.playCandidatesBySeat[seat]=trackerPrivate.playCandidatesBySeat[seat] or {}
        local candidates=trackerPrivate.playCandidatesBySeat[seat]
        local previous=trackerPrivate.bySeat[seat]
        local alreadyPlayed=candidates[ctx.objGUID]==true
            or (previous~=nil and previous[ctx.objGUID]==true)
            or trackerPrivate.playCardMovements[ctx.objGUID]~=nil
        candidates[ctx.objGUID]=true
        if alreadyPlayed then
            if trackerPrivate.traceEnabled then trackerPrivate.traceEvent("zone.reentry",seat,ctx.objGUID) end
            -- TTS emits EnterZone again when a relocated card falls through
            -- the thin zone. That is not a new play or another pickup.
            -- onObjectDrop owns its one reconciliation, even if the zone
            -- entry happens before the drop's final callback.
            return
        end
        -- For a genuinely new play, queue its first scan normally. Do not
        -- infer an ObjectPickUp from resting=false on zone entry.
    end
    if ctx.zoneInfo.kind=="play" and gameCards[ctx.objGUID]~=nil
        and gStates~=nil then
        gStates.resourceCardPlayOrder=gStates.resourceCardPlayOrder or {}
        if gStates.resourceCardPlayOrder[ctx.objGUID]==nil then
            gStates.resourceCardPlaySerial=(gStates.resourceCardPlaySerial or 0)+1
            gStates.resourceCardPlayOrder[ctx.objGUID]=gStates.resourceCardPlaySerial
        end
    end
    if ctx.obj~=nil and ((ctx.objType=="Dice" and scriptObjectId(ctx.obj)=="Mana Dice")
        or manaColor(ctx.obj)~=nil) then
        -- Track a die even if it is still slightly rocking; the released scan reads its face.
        trackerPrivate.unitManaCandidatesBySeat[seat]=trackerPrivate.unitManaCandidatesBySeat[seat] or {}
        trackerPrivate.unitManaCandidatesBySeat[seat][ctx.objGUID]=true
    end
    queueSeat(seat,ctx.objGUID)
end

function resourceCardsZoneLeft(ctx)
    if not resourceCardsPanelOpen() or ctx==nil or ctx.zoneInfo==nil then return end
    local seat=resourceCardsRelevantZone(ctx)
    if trackerPrivate.traceEnabled then
        trackerPrivate.traceEvent("zone.leave",seat,ctx.objGUID,ctx.zoneInfo.kind)
    end
    if ctx.zoneInfo.kind=="play" then
        if ctx.obj~=nil and trackerPrivate.playCandidateKind(resourceObjectKind(ctx.obj))
            and (combatConfig.cardInTransit(ctx.obj)
                or cardInSeatPlayArea(ctx.objGUID,ctx.zoneInfo.seatPos)) then
            -- This is a transient exit of a card still being moved or
            -- physically over the play mat, not an ended play. Crucially,
            -- do not schedule a delayed choice reset here: onDrop owns the
            -- final departure check, and reentry may occur after the timer.
            if trackerPrivate.traceEnabled then trackerPrivate.traceEvent("zone.leave-transit",seat,ctx.objGUID) end
            return
        end
        scheduleChoiceResetAfterPlay(ctx.objGUID,ctx.zoneInfo.seatPos)
    end
    if seat==nil then return end
    queueSeat(seat,ctx.objGUID)
end


-- A late TTS object-UI refresh can clear option buttons AFTER the settled
-- tracker scan has finished. A targeted recheck repairs only genuinely lost
-- controls; unchanged buttons and combat values are never rebuilt.
trackerPrivate.cardUIRecheckSerial={}
trackerPrivate.checkCardChoicesAfterDrop=function(guid,seatPos)
    if guid==nil or seatPos==nil then return end
    local serial=(trackerPrivate.cardUIRecheckSerial[guid] or 0)+1
    trackerPrivate.cardUIRecheckSerial[guid]=serial
    local session=trackerPrivate.trackerSession
    local function verify(attempt)
        if trackerPrivate.cardUIRecheckSerial[guid]~=serial
            or trackerPrivate.trackerSession~=session
            or not resourceCardsPanelOpen() then return end
        local card=getObjectFromGUID(guid)
        if card==nil or (card.isDestroyed~=nil and card.isDestroyed())
            or not cardInSeatPlayArea(guid,seatPos) then return end
        if not combatConfig.cardInTransit(card) then
            local expected=combatConfig.cardButtonIds[guid]
            if choiceButtonShown[guid]~=nil and choiceButtonShown[guid]~="hidden"
                and expected~=nil and #expected>0
                and not combatConfig.cardChoicesPresent(card) then
                if trackerPrivate.traceEnabled then
                    trackerPrivate.traceEvent("choice.repair",seatPos,guid,
                        "attempt="..tostring(attempt).." expected="..tostring(#expected))
                end
                queueSeat(seatPos,guid)
            end
        end
        if attempt==1 then
            -- Catch a late overwrite from TTS/another card-UI owner, without
            -- permanently polling every card in the play area.
            safeWaitFrames("PlayerBoard.CardRecognition",function() verify(2) end,12)
        end
    end
    safeWaitFrames("PlayerBoard.CardRecognition",function() verify(1) end,5)
end

function resourceCardsObjectMoved(obj,stabilized)
    if obj==nil or not resourceCardsPanelOpen() then return end
    if trackerPrivate.traceEnabled then
        trackerPrivate.traceEvent("object.moved",nil,obj.guid,
            "stable="..tostring(stabilized).." held="..tostring(obj.held_by_color))
    end
    -- Some entries are reported only after the card is dropped. Protect that
    -- first scan too, even if no pickup/enter event registered the movement.
    if not stabilized and obj.type~="Dice" and obj.resting==false
        and trackerPrivate.playCardMovements[obj.guid]==nil
        and trackerPrivate.playCandidateKind(resourceObjectKind(obj)) then
        resourceCardsObjectPickedUp(obj)
    end
    -- Drop callbacks can arrive before the card's final rotation or before
    -- the shallow zone knows it is back. Keep the calculator unchanged.
    if trackerPrivate.playCardMovements[obj.guid]~=nil then
        trackerPrivate.finishPlayCardMove(obj)
        return
    end
    local player=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    if player==nil then return end
    local seat=player.seatPos
    if (obj.type=="Dice" and scriptObjectId(obj)=="Mana Dice") or manaColor(obj)~=nil then
        -- Drop callbacks fire even if the final die/crystal sits above both thin
        -- scripting zones. Remember its GUID and scan once released.
        trackerPrivate.unitManaCandidatesBySeat[seat]=trackerPrivate.unitManaCandidatesBySeat[seat] or {}
        trackerPrivate.unitManaCandidatesBySeat[seat][obj.guid]=true
        queueSeat(seat,obj.guid)
        return
    end
    local isUnitStateToken=unitLayoutIsCommand(obj) or unitLayoutIsWound(obj)
    local isMonster=combatEnemyData(obj.guid,obj)~=nil
    local objectKind=resourceObjectKind(obj)
    if objectKind==nil and not isUnitStateToken and not isMonster then
        -- A played powered One with the Land may change Block value when the
        -- Mage Knight moves to different terrain. Only watch avatar drops
        -- while that exact effect is selected; no continual background scan.
        local scan=resourceCardScanBySeat[seat]
        if scan~=nil and (scan.usesCurrentHexBlock==true
            or scan.usesCurrentHexHealing==true or scan.usesSkillLocation==true) then
            for _,hero in ipairs(mageKnights or {}) do
                if hero.mage==player.mage and
                    (obj.guid==hero.model or obj.guid==hero.token or obj.guid==hero.standee) then
                    queueSeat(seat,obj.guid)
                    return
                end
            end
        end
        return
    end
    -- Already-observed sources always need a settled reconciliation, even
    -- when dropped just above a shallow zone. Avoid searching four zones to
    -- discover information the last scan already provided.
    local observed=trackerPrivate.bySeat[seat]
    -- The drop event can precede the shallow zone's physical re-entry.
    -- Keep the previously played source (and its explicit choices/target)
    -- when its released X/Z is still over this mat.
    if trackerPrivate.playCandidateKind(objectKind) then
        local candidates=trackerPrivate.playCandidatesBySeat[seat] or {}
        local known=candidates[obj.guid]==true
        local inPlay=cardInSeatPlayArea(obj.guid,seat)
        if inPlay then
            candidates[obj.guid]=true
            trackerPrivate.playCandidatesBySeat[seat]=candidates
        elseif known then
            candidates[obj.guid]=nil
            scheduleChoiceResetAfterPlay(obj.guid,seat)
        end
        if inPlay or known then
            queueSeat(seat,obj.guid)
            if inPlay then trackerPrivate.checkCardChoicesAfterDrop(obj.guid,seat) end
            return
        end
    end
    if observed~=nil and observed[obj.guid]==true then
        if (objectKind=="card" or objectKind=="skill" or objectKind=="factionReward")
            and not cardInSeatPlayArea(obj.guid,seat) then
            scheduleChoiceResetAfterPlay(obj.guid,seat)
        end
        queueSeat(seat,obj.guid)
        if trackerPrivate.playCandidateKind(objectKind)
            and cardInSeatPlayArea(obj.guid,seat) then
            trackerPrivate.checkCardChoicesAfterDrop(obj.guid,seat)
        end
        return
    end
    -- New arrivals only need zones that can actually hold their resource type.
    -- Mana/dice have already taken the dedicated early path above.
    local relevantZones
    if isMonster or isUnitStateToken or objectKind=="unit" or objectKind=="puppet" then
        relevantZones={playerPlayAreas[seat],playerUnitAreas[seat]}
    elseif objectKind=="wound" then
        relevantZones={playerPlayAreas[seat],playerUnitAreas[seat],handZones[seat]}
    else
        relevantZones={playerPlayAreas[seat]}
    end
    for _,zoneGUID in ipairs(relevantZones) do
        local zone=zoneGUID~=nil and getObjectFromGUID(zoneGUID) or nil
        if zone~=nil then
            for _,candidate in ipairs(zone.getObjects()) do
                if candidate.guid==obj.guid then queueSeat(seat,obj.guid) return end
            end
        end
    end
    if (isMonster and combatTrackedSeat==seat and combatTrackedEnemies[obj.guid]~=nil)
        or isUnitStateToken or (isMonster and trackerPrivate.bySeat[seat]~=nil
        and trackerPrivate.bySeat[seat][obj.guid]==true) then
        -- On a drop outside the zones, wait for the token to settle before
        -- checking membership. Otherwise smooth movement can retain a ghost
        -- indefinitely if no further zone event fires.
        queueSeat(seat,isMonster and obj.guid or nil)
    elseif trackerPrivate.bySeat[seat]~=nil and trackerPrivate.bySeat[seat][obj.guid]==true then
        scheduleChoiceResetAfterPlay(obj.guid,seat)
        -- Wait for this specific card to settle before reconciling its XML.
        -- An immediate scan could run while TTS is still clearing its UI.
        queueSeat(seat,obj.guid)
    end
end

-- Register the remaining readying and Artifact gameplay buttons through the
-- protected public boundary for the onLoad audit and error reporter.
publishPublicUICallbacks({
    resourceCardsRegenerationReadyClicked=resourceCardsRegenerationReadyClicked,
    resourceCardsArtifactHealUnitsClicked=resourceCardsArtifactHealUnitsClicked,
    resourceCardsArtifactBreakClicked=resourceCardsArtifactBreakClicked,
    resourceCardsArtifactGrailFameClicked=resourceCardsArtifactGrailFameClicked
})

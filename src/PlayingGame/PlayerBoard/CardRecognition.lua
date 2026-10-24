-- The physical play area supplies estimated resources to the Resource Tracker.
-- Runtime-only observations never overwrite the saved manual +/- adjustments.
resourceCardScanBySeat={}
local generation={}
local shown={}
-- Mana crystal figurines are still read for powering cards, but should never
-- receive Resource Tracker highlights. Avoid repeated highlightOff calls.
local crystalHighlightCleared={}
local bySeat={}
-- Initial guesses and explicit player choices are transient, never saved in gStates or JSON.
local selectedResourceByGUID={}
-- A choice lasts for one play; delayed departure checks must not race a return.
local choiceResetGenerationByGUID={}
-- Display state is separate from player selections. Picks/drops may clear the
-- buttons, but the chosen resource stays until the script reloads.
local choiceExpandedByGUID={}
local choiceButtonShown={}
local unitManaDecision
local factionRewardForObject
-- Highlights show how confidently the tracker understands the selected effect.
-- Blue is a deliberate neutral/not-calculated state, not an illegal-play warning.
-- Purple takes precedence when objects are linked; brightness indicates power.
local palette={
    green={{0.10,0.55,0.14},{0.35,1.00,0.38}},
    yellow={{0.62,0.48,0.08},{1.00,0.94,0.19}},
    blue={{0.08,0.34,0.64},{0.26,0.66,1.00}},
    purple={{0.47,0.19,0.62},{0.92,0.43,1.00}}
}
-- Distinguish elemental and physical damage. Otherwise a Ranged Fire Attack
-- would be incorrectly added to the Physical Ranged field.
local totalsKeys={move=true,ranged=true,siege=true,attack=true,block=true,influence=true,healing=true,
    rangedFire=true,rangedIce=true,rangedColdFire=true,rangedPsychic=true,
    siegeFire=true,siegeIce=true,siegeColdFire=true,siegePsychic=true,
    attackFire=true,attackIce=true,attackColdFire=true,attackPsychic=true,
    blockFire=true,blockIce=true,blockColdFire=true,blockPsychic=true}

-- Catalog is defined once in UnitResources.lua and keyed by card GUID.
local unitResourceDefinitions=unitResourceDefinitions
local commandPickupForUnits={}
-- Rebuilt with the live Unit layout for each Resource Tracker scan.
-- Existing Command tokens and Wounds suppress Unit highlights regardless of
-- whether an activated ability contributes resources this turn.
local unitHighlightBlocked={}
-- Reuse a single immutable terrain modifier. Constructing a new table on
-- every scan would make the terrain-effect comparison think the cost changed
-- even when Foresters' chosen ability is unchanged.
local forestersTerrainModifier={mode="reduce",
    terrains={forest=true,hills=true,swamp=true},amount=1,minimum=0}

-- Game effects must continue working while the Resource Tracker is collapsed
-- or hidden. Detail visibility controls only the over-card choice buttons.
function resourceCardsPanelOpen()
    return gStates~=nil and gStates.firstStarted==true
end

local function resourceCardsDetailsOpen()
    return resourceCardsPanelOpen()
        and UI.getAttribute("ResourceTracker","active")~="false"
        and UI.getAttribute("ResourceTrackerDetail","active")=="true"
end

local COMBAT_ENEMY_DEFENCE_TRAITS={
    {"fortified","Fortified"},{"unfortified","Unfortified"},{"elusive","Elusive"},
    {"arcaneImmunity","Arcane Immunity"},{"pResist","Physical Resist"},
    {"fResist","Fire Resist"},{"iResist","Ice Resist"},{"mResist","Psychic Resist"}
}
local COMBAT_ENEMY_OFFENCE_TRAITS={
    {"swiftness","Swiftness"},{"brutal","Brutal"},{"poison","Poison"},
    {"paralyse","Paralyse"},{"assassination","Assassination"},
    {"cumbersome","Cumbersome"},{"vampiric","Vampiric"}
}
local COMBAT_SOURCE_FIELDS={
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
-- The calculator runs only while the Resource Tracker details are open and an enemy is in play.
local combatCalcOn=false
local combatCumbersomeActive=false
local combatAssignmentJoined={}
local combatAssignmentSlotSources={}
local combatAssignmentRowTargets={}
local COMBAT_ASSIGNMENT_ROW_COUNT=8
local COMBAT_ASSIGNMENT_SLOT_COUNT=6
local COMBAT_ASSIGNMENT_ROW_HEIGHT=40
local COMBAT_ASSIGNMENT_PANEL_BASE_HEIGHT=52
local COMBAT_ASSIGNMENT_COLUMNS={Name=130,Armour=55,Traits=150,Attacks=110,Offence=130,Result=180}
-- Damage/resistance colours: normal, then the darker shade used once a value has been reduced.
local COMBAT_TYPE_COLORS={P={"#FFFFFF","#9A9A9A"},F={"#FF5555","#992E2E"},I={"#5AA0FF","#2F5F9A"},
    IF={"#C070FF","#74429A"},M={"#FFE055","#9A8A33"}}
local COMBAT_RESIST_TYPES={pResist="P",fResist="F",iResist="I",mResist="M"}

local function combatTypeRich(text,typeKey,reduced)
    local colors=COMBAT_TYPE_COLORS[typeKey]
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
            traits[#traits+1]=COMBAT_RESIST_TYPES[trait[1]]~=nil
                and combatTypeRich(trait[2],COMBAT_RESIST_TYPES[trait[1]]) or trait[2]
        end
    end
    local defender=(tonumber(data.defend) or 0)+(perks~=nil and (tonumber(perks.defend) or 0) or 0)
    if traitDefinitions==COMBAT_ENEMY_DEFENCE_TRAITS then
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

local function combatAssignmentSources(seat)
    local scan=seat~=nil and resourceCardScanBySeat[seat] or nil
    local sources={}
    for guid,record in pairs(scan~=nil and scan.cards or {}) do
        if record.resources~=nil then
            local source=nil
            local function ensureSource()
                if source~=nil then return end
                local cardData=gameCards[guid]
                local sourceName=cardData~=nil and cardData.name or nil
                if type(sourceName)=="table" then sourceName=sourceName[1] end
                source={guid=guid,name=tostring(sourceName or record.kind or "Resource"),
                    ranged=0,siege=0,block=0,attack=0,move=0,details={},resources=record.resources}
                sources[#sources+1]=source
            end
            for _,field in ipairs(COMBAT_SOURCE_FIELDS) do
                local amount=tonumber(record.resources[field.key]) or 0
                if amount>0 then
                    ensureSource()
                    local resourceFamily=field.family
                    source[resourceFamily]=source[resourceFamily]+amount
                    local typeKey="P"
                    if field.key:find("ColdFire$") then typeKey="IF"
                    elseif field.key:find("Fire$") then typeKey="F"
                    elseif field.key:find("Ice$") then typeKey="I"
                    elseif field.key:find("Psychic$") then typeKey="M" end
                    source.details[#source.details+1]={text=field.type.." "..tostring(amount),
                        amount=amount,icon=field.icon,key=field.key,family=field.family,typeKey=typeKey}
                end
            end
            local moveAmount=tonumber(record.resources.move) or 0
            if moveAmount>0 then
                ensureSource()
                source.move=moveAmount
                source.details[#source.details+1]={text="Move "..tostring(moveAmount),
                    amount=moveAmount,icon="MKChoiceMove",key="move",family="move"}
            end
        end
    end
    table.sort(sources,function(a,b)
        if a.name==b.name then return a.guid<b.guid end
        return a.name<b.name
    end)
    return sources
end

local function combatNearestEnemyGUID(sourceGUID,entries)
    local source=getObjectFromGUID(sourceGUID)
    if source==nil then return nil end
    local sourcePosition=source.getPosition()
    local nearestGUID,nearestDistance=nil,nil
    for _,entry in ipairs(entries) do
        local enemy=getObjectFromGUID(entry.guid)
        if enemy~=nil then
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

local COMBAT_ATTACK_TYPES={
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

local function combatEnemyPrintedAttacks(data,perks)
    local attacks={}
    local base=type(data.attack)=="table" and data.attack or {}
    local override=perks~=nil and type(perks.attack)=="table" and perks.attack or {}
    local elemental=perks~=nil and perks.elemental==true
    local boost=perks~=nil and tonumber(perks.boost) or 0
    local boostUsed=false
    local swift=combatEnemyHasTrait(data,perks,"swiftness")
    local brutal=combatEnemyHasTrait(data,perks,"brutal")
    local cumbersome=combatEnemyHasTrait(data,perks,"cumbersome")
    for _,attackType in ipairs(COMBAT_ATTACK_TYPES) do
        local values=override[attackType.key] or base[attackType.key]
        for _,printedValue in ipairs(type(values)=="table" and values or {}) do
            local bonus=elemental and (attackType.key=="IF" and 1 or 2) or 0
            if not boostUsed and boost~=0 then bonus=bonus+boost boostUsed=true end
            attacks[#attacks+1]={key=attackType.key,label=attackType.label,
                value=math.max(0,printedValue+bonus),block=attackType.block,
                swift=swift,brutal=brutal,cumbersome=cumbersome}
        end
    end
    return attacks
end

-- Summoned tokens are not enemies in their own right: their attacks and abilities belong to the summoner.
local function combatSummonedFor(summonerGUID)
    local summoned={}
    for guid,details in pairs(gStates~=nil and gStates.attackedMonsters or {}) do
        local data=monsterPugs[guid]
        if type(details)=="table" and details[3]=="summoned" and details[4]==summonerGUID
            and data~=nil and getObjectFromGUID(guid)~=nil then
            local perks=gStates.monsterPerks~=nil and gStates.monsterPerks[guid] or nil
            summoned[#summoned+1]={guid=guid,data=data,perks=perks}
        end
    end
    table.sort(summoned,function(a,b) return a.guid<b.guid end)
    return summoned
end

local function combatIsSummonedToken(guid)
    return gStates~=nil and gStates.summonStates~=nil and gStates.summonStates[guid]=="summoned"
end

-- A summoner with no token out yet counts as one 0 attack with no abilities.
local function combatEnemyAttacks(entry)
    local attacks=combatEnemyPrintedAttacks(entry.data,entry.perks)
    if entry.data.monsters~=nil then
        for _,summoned in ipairs(entry.summoned or {}) do
            for _,attack in ipairs(combatEnemyPrintedAttacks(summoned.data,summoned.perks)) do
                attacks[#attacks+1]=attack
            end
        end
        if #(entry.summoned or {})==0 then
            attacks[#attacks+1]={key="P",label="Summon",value=0,block="block",pending=true}
        end
    end
    return attacks
end

-- Offence abilities shown for a summoner are the ones carried by its summoned tokens.
local function combatEnemyOffenceTraits(entry)
    if entry.data.monsters==nil then
        return combatEnemyTraitsText(entry.data,entry.perks,COMBAT_ENEMY_OFFENCE_TRAITS)
    end
    local merged={}
    for _,summoned in ipairs(entry.summoned or {}) do
        for _,trait in ipairs(COMBAT_ENEMY_OFFENCE_TRAITS) do
            if combatEnemyHasTrait(summoned.data,summoned.perks,trait[1]) then merged[trait[1]]=true end
        end
    end
    return combatEnemyTraitsText(merged,nil,COMBAT_ENEMY_OFFENCE_TRAITS)
end

local function combatEntryHasCumbersome(guid,data,perks)
    if combatEnemyHasTrait(data,perks,"cumbersome") then return true end
    if data.monsters~=nil then
        for _,summoned in ipairs(combatSummonedFor(guid)) do
            if combatEnemyHasTrait(summoned.data,summoned.perks,"cumbersome") then return true end
        end
    end
    return false
end

local function combatGUIDHasCumbersome(guid)
    local data=monsterPugs[guid]
    if data==nil then return false end
    local perks=gStates~=nil and gStates.monsterPerks~=nil and gStates.monsterPerks[guid] or nil
    return combatEntryHasCumbersome(guid,data,perks)
end

function resourceCardsCombatTargetAcceptsMove(guid)
    return combatGUIDHasCumbersome(guid)
end

-- A lifted card keeps its target while its arrow still exists.
local function combatSourceKeepsLock(guid)
    return getObjectFromGUID(guid)~=nil and next(attackAssignmentsTargetGUIDs(guid))~=nil
end

-- True while the Resource Tracker details are open and an enemy stands in the play area.
local function combatCalcUpdate(monsters)
    local on=false
    local cumbersome=false
    if resourceCardsDetailsOpen() then
        for guid in pairs(monsters or {}) do
            local data=monsterPugs[guid]
            if data~=nil and not combatIsSummonedToken(guid) then
                on=true
                local perks=gStates~=nil and gStates.monsterPerks~=nil and gStates.monsterPerks[guid] or nil
                if combatEntryHasCumbersome(guid,data,perks) then cumbersome=true break end
            end
        end
    end
    combatCalcOn=on
    combatCumbersomeActive=cumbersome
    return on
end

local function combatPlayMonsters()
    local active=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    local monsters={}
    if active~=nil and active.seatPos~=nil then
        for _,zoneGUID in ipairs({playerPlayAreas[active.seatPos],playerUnitAreas[active.seatPos]}) do
            local zone=zoneGUID~=nil and getObjectFromGUID(zoneGUID) or nil
            if zone~=nil then
                for _,obj in ipairs(zone.getObjects()) do
                    if monsterPugs[obj.guid]~=nil then monsters[obj.guid]=obj end
                end
            end
        end
    end
    return monsters
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
        return combatEnemyHasTrait(data,perks,"fResist")
            and combatEnemyHasTrait(data,perks,"iResist")
    end
    return combatEnemyHasTrait(data,perks,"mResist")
end

-- Groups are {sources=,category=}. The resisted part of one phase's attack is
-- totalled first and halved once, rounding down.
local function combatAttackTotal(groups,data,perks)
    local normal,resisted=0,0
    for _,group in ipairs(groups) do
        for _,source in ipairs(group.sources) do
            for _,attackType in ipairs(COMBAT_ATTACK_TYPES) do
                local value=tonumber(source.resources[attackType[group.category]]) or 0
                if value>0 then
                    if combatEnemyResists(data,perks,attackType.key) then
                        resisted=resisted+value
                    else
                        normal=normal+value
                    end
                end
            end
        end
    end
    return normal+math.floor(resisted/2)
end

-- Blocks of the wrong element are halved against Fire, Ice and Cold Fire attacks.
local COMBAT_EFFICIENT_BLOCKS={
    P={block=true,blockFire=true,blockIce=true,blockColdFire=true,blockPsychic=true},
    F={blockIce=true,blockColdFire=true},
    I={blockFire=true,blockColdFire=true},
    IF={blockColdFire=true},
    M={block=true,blockPsychic=true}
}

-- The assignment panel is rescanned with every card scan; only send attributes that changed.
local combatPanelAttributes={}
local function combatPanelSetAttribute(id,attribute,value)
    local key=id.."\0"..attribute
    if combatPanelAttributes[key]==value then return end
    combatPanelAttributes[key]=value
    UI.setAttribute(id,attribute,value)
end

-- Empty slots are hidden; a filled slot is the resource icon with its value over the top.
local function combatAssignmentIconButton(id,active,amount,icon,tooltip,selected,textColor)
    combatPanelSetAttribute(id,"active",active and "true" or "false")
    if active then
        combatPanelSetAttribute(id.."Image","image",icon)
        combatPanelSetAttribute(id.."Image","rectAlignment","MiddleCenter")
        combatPanelSetAttribute(id.."Image","offsetXY","0 0")
        combatPanelSetAttribute(id.."Image","width","28")
        combatPanelSetAttribute(id.."Image","height","28")
        combatPanelSetAttribute(id.."Image","preserveAspect","true")
        combatPanelSetAttribute(id.."Amount","text",tostring(amount))
        combatPanelSetAttribute(id.."Amount","rectAlignment","MiddleCenter")
        combatPanelSetAttribute(id.."Amount","offsetXY","0 0")
        combatPanelSetAttribute(id.."Amount","width","28")
        combatPanelSetAttribute(id.."Amount","height","28")
        combatPanelSetAttribute(id.."Amount","preferredHeight","28")
        combatPanelSetAttribute(id.."Amount","alignment","MiddleCenter")
        combatPanelSetAttribute(id.."Amount","fontSize","20")
        combatPanelSetAttribute(id.."Amount","fontStyle","Bold")
        combatPanelSetAttribute(id.."Amount","color",textColor or "White")
        combatPanelSetAttribute(id.."Amount","outline","rgb(0,0,0)")
        combatPanelSetAttribute(id.."Amount","outlineSize","1 -1")
        combatPanelSetAttribute(id,"preferredWidth","28")
        combatPanelSetAttribute(id,"preferredHeight","34")
        combatPanelSetAttribute(id,"color",
            selected and "rgb(1,0.75,0.2)" or "rgb(0.85,0.82,0.72)")
        combatPanelSetAttribute(id,"tooltip",tooltip)
    end
end

local COMBAT_RED="#FF5555"
local COMBAT_GREEN="#8CFF8C"

-- TTS Text uses Unity rich text tags.
local function combatRich(text,color)
    return "<color="..color..">"..text.."</color>"
end

-- Ranged and Siege only count in the Ranged/Siege phase against enemies that are not
-- (doubly) fortified; one phase total is resisted as a whole.
local function combatRangeResult(entry,sources)
    local data,perks=entry.data,entry.perks
    local fortification=combatEnemyFortificationCount(data,perks)
    local groups={}
    if fortification==0 then groups[#groups+1]={sources=sources,category="ranged"} end
    if fortification<2 then groups[#groups+1]={sources=sources,category="siege"} end
    local total=combatAttackTotal(groups,data,perks)
    local armour=combatEnemyHasTrait(data,perks,"elusive") and entry.elusiveArmour or entry.baseArmour
    return total,armour,total>0 and total>=armour,fortification
end

-- Block cells hold block, the Ranged/Siege cell holds range/siege only once it can legally
-- defeat the enemy, and everything else is generic Attack.
local function combatDetailPhase(detail,rangeDefeated,fortification)
    if detail.family=="block" or detail.family=="move" then return "block" end
    if rangeDefeated and ((detail.family=="ranged" and fortification==0)
        or (detail.family=="siege" and fortification<2)) then return "range" end
    return "attack"
end

local function combatBlockAllocation(blockSources,attack,required,usedBlocks)
    if required<=0 then return 0,{} end
    local efficient=COMBAT_EFFICIENT_BLOCKS[attack.key] or {}
    local candidates={}
    for _,source in ipairs(blockSources) do
        for _,field in ipairs(COMBAT_SOURCE_FIELDS) do
            local value=tonumber(source.resources[field.key]) or 0
            if field.family=="block" and value>0 and not usedBlocks[source.guid..field.key] then
                candidates[#candidates+1]={source=source,key=field.key,value=value,
                    efficient=efficient[field.key]==true}
            end
        end
    end
    table.sort(candidates,function(a,b)
        if a.efficient~=b.efficient then return a.efficient end
        if a.source.guid==b.source.guid then return a.key<b.key end
        return a.source.guid<b.source.guid
    end)
    local full,wrong,spent,used=0,0,0,{}
    for _,candidate in ipairs(candidates) do
        used[#used+1]=candidate.source.guid..candidate.key
        if candidate.efficient then full=full+candidate.value else wrong=wrong+candidate.value end
        spent=full+math.floor(wrong/2)
        if spent>=required then break end
    end
    return spent,used
end

-- Block resources only ever face the enemy they were targeted at.
-- Move resources the player aimed at a Cumbersome attack reduce that attack by 1 each
-- before blocking; they are only spent once the attack is fully stopped.
-- Returns result lines, total damage, damaging attack count, and whether every attack was blocked.
local function combatBlockResult(entry,sources)
    local blockSources={}
    local movePool=0
    for _,source in ipairs(sources) do
        if source.block>0 then blockSources[#blockSources+1]=source end
        if source.moveCounts==true then movePool=movePool+source.move end
    end
    local attacks=combatEnemyAttacks(entry)
    -- Weakest attacks are blocked first, and a failed block keeps its resources for the rest.
    local order={}
    for index,attack in ipairs(attacks) do order[index]=index end
    table.sort(order,function(a,b)
        if attacks[a].value~=attacks[b].value then return attacks[a].value<attacks[b].value end
        return a<b
    end)
    local lineByAttack,usedBlocks,allBlocked,totalDamage={},{},#attacks>0,0
    local reductions={}
    local damageCount=0
    for _,index in ipairs(order) do
        local attack=attacks[index]
        local swift=attack.swift and 2 or 1
        local brutal=attack.brutal and 2 or 1
        local reduction,spent,used,required=0,0,{},attack.value*swift
        local maxReduction=attack.cumbersome and math.min(movePool,attack.value) or 0
        for tried=0,maxReduction do
            required=(attack.value-tried)*swift
            spent,used=combatBlockAllocation(blockSources,attack,required,usedBlocks)
            if required<=0 or spent>=required then reduction=tried break end
            if tried==maxReduction then reduction=0 required=attack.value*swift
                spent,used=combatBlockAllocation(blockSources,attack,required,usedBlocks)
            end
        end
        local counts=tostring(spent).."/"..tostring(required)
        if attack.value<=0 or spent>=required then
            for _,usage in ipairs(used) do usedBlocks[usage]=true end
            movePool=movePool-reduction
            reductions[index]=reduction
            if reduction>0 then
                -- Move-reduced attacks read like any other fully blocked attack.
                local full=attack.value*swift
                counts=tostring(full).."/"..tostring(full)
            end
            lineByAttack[index]=attack.pending and "Summon pending" or (attack.value<=0 and "No attack" or (counts.." Blocked"))
        else
            allBlocked=false
            totalDamage=totalDamage+attack.value*brutal
            damageCount=damageCount+1
            local damage=combatRich(tostring(attack.value*brutal).." Damage",COMBAT_RED)
            lineByAttack[index]=(spent>0 and (counts.." Block, ") or "Not blocked, ")..damage
        end
    end
    local lines={}
    for index=1,#attacks do lines[#lines+1]=lineByAttack[index] end
    return lines,totalDamage,damageCount,allBlocked,reductions
end

-- A group is attacked as one: fortification and resistance of any member apply to all of
-- them and the armours add together. Elusive members only use their higher armour in the
-- Attack phase while one of their attacks is unblocked.
local function combatGroupEntry(members,blockedAll)
    local data={fortified=false,elusive=true}
    local perks={}
    local fortification=0
    local armour,elusiveArmour,attackArmour=0,0,0
    for _,member in ipairs(members) do
        fortification=math.max(fortification,combatEnemyFortificationCount(member.data,member.perks))
        for _,key in ipairs({"pResist","fResist","iResist","mResist"}) do
            if combatEnemyHasTrait(member.data,member.perks,key) then data[key]=true end
        end
        local elusive=combatEnemyHasTrait(member.data,member.perks,"elusive")
        local rangeArmour=elusive and member.elusiveArmour or member.baseArmour
        armour=armour+member.baseArmour
        elusiveArmour=elusiveArmour+rangeArmour
        attackArmour=attackArmour+((elusive and not blockedAll[member.guid]) and member.elusiveArmour or member.baseArmour)
    end
    data.fortified=fortification>=1
    perks.wallFortified=fortification>=2
    return {data=data,perks=perks,baseArmour=armour,elusiveArmour=elusiveArmour},attackArmour
end

local function combatGroupAttackLine(group,sources,attackArmour)
    local meleeTotal=combatAttackTotal({
        {sources=sources,category="attack"},
        {sources=sources,category="ranged"},
        {sources=sources,category="siege"}},group.data,group.perks)
    if meleeTotal<=0 then return nil end
    local line="Attack "..tostring(meleeTotal).."/"..tostring(attackArmour)
    return meleeTotal>=attackArmour and (line.." "..combatRich("Defeated",COMBAT_GREEN)) or line
end

local combatDefenderMarkedGUID=nil
local COMBAT_DEFENDER_DECAL_URL="https://steamusercontent-a.akamaihd.net/ugc/14077412532545838280/E5508FB0ADB512C72FA29D49665D051B12B8C015/"

local function combatSetDefenderDecal(guid,on)
    local obj=guid~=nil and getObjectFromGUID(guid) or nil
    if obj==nil then return end
    local decals,found={},false
    for _,decal in pairs(obj.getDecals() or {}) do
        if decal.name=="DefenderArmour" then found=true else decals[#decals+1]=decal end
    end
    if on and not found then
        obj.addDecal({name="DefenderArmour",url=COMBAT_DEFENDER_DECAL_URL,position={0.0,0.15,1.2},
            rotation={90,180,0},scale={0.72,0.72,1}})
    elseif not on and found then
        obj.setDecals(decals)
    end
end

-- Marks the enemy currently receiving the Defender armour bonus; pass nil to clear.
local function combatSyncDefenderMark(guid)
    if combatDefenderMarkedGUID~=nil and combatDefenderMarkedGUID~=guid then
        combatSetDefenderDecal(combatDefenderMarkedGUID,false)
    end
    combatDefenderMarkedGUID=guid
    if guid~=nil then combatSetDefenderDecal(guid,true) end
end

local function combatAssignmentRefreshRows(entries,sources)
    local rowByGUID={}
    local totalRowHeight=0
    local grandDamage,damageSources=0,0
    combatAssignmentRowTargets={}
    for index,entry in ipairs(entries) do
        if index<=COMBAT_ASSIGNMENT_ROW_COUNT then
            rowByGUID[entry.guid]=index
            combatAssignmentRowTargets[index]=entry.guid
        end
    end
    local overflow=math.max(0,#entries-COMBAT_ASSIGNMENT_ROW_COUNT)
    -- Joined enemies form a group (the leader is its first row) that is attacked as one.
    local groups,groupOf={},{}
    for index=1,math.min(#entries,COMBAT_ASSIGNMENT_ROW_COUNT) do
        local group=groups[#groups]
        if index==1 or combatAssignmentJoined[entries[index].guid]~=true then
            group={members={},sources={}}
            groups[#groups+1]=group
        end
        group.members[#group.members+1]=index
        group.leader=group.members[1]
        groupOf[index]=group
    end
    for index=1,COMBAT_ASSIGNMENT_ROW_COUNT do
        local entry=entries[index]
        local group=groupOf[index]
        combatPanelSetAttribute("CombatEnemyRow"..index,"active",entry~=nil and "true" or "false")
        combatPanelSetAttribute("CombatEnemyRow"..index,"color",
            (group~=nil and #group.members>1) and "rgb(0.27,0.31,0.38)"
            or (index%2==0 and "rgb(0.34,0.29,0.22)" or "rgb(0.29,0.25,0.19)"))
        if entry~=nil then
            combatPanelSetAttribute("CombatEnemyRow"..index.."Name","text",
                (group.leader~=index and "+ " or "")..entry.name)
            combatPanelSetAttribute("CombatEnemyRow"..index.."Traits","text",
                combatEnemyTraitsText(entry.data,entry.perks,COMBAT_ENEMY_DEFENCE_TRAITS))
            combatPanelSetAttribute("CombatEnemyRow"..index.."Name","font","Fonts/MKCardText")
            combatPanelSetAttribute("CombatEnemyRow"..index.."Armour","font","Fonts/MKCardText")
            combatPanelSetAttribute("CombatEnemyRow"..index.."Traits","font","Fonts/MKCardText")
            combatPanelSetAttribute("CombatEnemyRow"..index.."Name","color","rgb(0.96,0.92,0.82)")
            combatPanelSetAttribute("CombatEnemyRow"..index.."Armour","color","rgb(0.96,0.92,0.82)")
            combatPanelSetAttribute("CombatEnemyRow"..index.."Traits","color","rgb(0.88,0.84,0.73)")
            local attacks=combatEnemyAttacks(entry)
            for _,column in ipairs({"Attacks","Offence","Traits"}) do
                local id="CombatEnemyRow"..index..column
                combatPanelSetAttribute(id,"font","Fonts/MKCardText")
                combatPanelSetAttribute(id,"color","rgb(0.88,0.84,0.73)")
                combatPanelSetAttribute(id,"alignment","MiddleCenter")
            end
            local offenceText=combatEnemyOffenceTraits(entry)
            combatPanelSetAttribute("CombatEnemyRow"..index.."Offence","text",offenceText)
            local traitLines=math.max(select(2,offenceText:gsub("\n",""))+1,
                select(2,combatEnemyTraitsText(entry.data,entry.perks,COMBAT_ENEMY_DEFENCE_TRAITS):gsub("\n",""))+1)
            for column,width in pairs(COMBAT_ASSIGNMENT_COLUMNS) do
                combatPanelSetAttribute("CombatEnemyRow"..index..column,"preferredWidth",tostring(width))
            end
            entry.attackCount=math.max(#attacks,traitLines)
        end
    end

    combatAssignmentSlotSources={}
    local allocated={}
    for _,source in ipairs(sources) do
        local moveOnly=source.ranged+source.siege+source.block+source.attack==0
        -- Once locked, a source stays on its enemy until it is retargeted or its arrow is removed.
        local targetGUID=combatAssignmentState.targets[source.guid]
        if targetGUID==nil and moveOnly then
            -- Move is never aimed automatically; keep an arrow the player drew earlier.
            for guid in pairs(attackAssignmentsTargetGUIDs(source.guid)) do
                if rowByGUID[guid]~=nil then
                    targetGUID=guid
                    combatAssignmentState.targets[source.guid]=guid
                    combatAssignmentState.explicit[source.guid]=true
                    break
                end
            end
        end
        local targetIndex=targetGUID~=nil and rowByGUID[targetGUID] or nil
        if moveOnly and targetGUID~=nil and not combatGUIDHasCumbersome(targetGUID) then
            -- Move can only be aimed at a Cumbersome enemy.
            combatAssignmentState.targets[source.guid]=nil
            combatAssignmentState.explicit[source.guid]=nil
            attackAssignmentsClearForObject(source.guid)
            targetGUID,targetIndex=nil,nil
        end
        if targetIndex==nil and not moveOnly then
            targetGUID=combatNearestEnemyGUID(source.guid,entries)
            combatAssignmentState.targets[source.guid]=targetGUID
            combatAssignmentState.explicit[source.guid]=nil
            targetIndex=targetGUID~=nil and rowByGUID[targetGUID] or nil
        end
        if targetIndex==nil and targetGUID~=nil then
            combatAssignmentState.targets[source.guid]=nil
            combatAssignmentState.explicit[source.guid]=nil
        end
        if targetIndex~=nil then
            -- The arrow follows the lock, and returns if a cancelled retarget removed it.
            if not attackAssignmentsIsTargeting(source.guid) then
                attackAssignmentsEnsureTarget(source.guid,targetGUID)
            end
            local explicit=combatAssignmentState.explicit[source.guid]==true
                and combatGUIDHasCumbersome(targetGUID)
            source.moveCounts=explicit
            local target=allocated[targetIndex]
            if target==nil then
                target={range={},block={},attack={},sources={},details={}}
                allocated[targetIndex]=target
            end
            target.sources[#target.sources+1]=source
            for _,detail in ipairs(source.details) do
                if detail.family~="move" or explicit then
                    target.details[#target.details+1]={source=source,detail=detail}
                end
            end
        end
    end
    for guid in pairs(combatAssignmentState.targets) do
        local active=false
        for _,source in ipairs(sources) do
            if source.guid==guid then active=true break end
        end
        -- A card lifted to rearrange the play area keeps its lock while its arrow remains.
        if not active and not combatSourceKeepsLock(guid) then
            combatAssignmentState.targets[guid]=nil
            combatAssignmentState.explicit[guid]=nil
        end
    end

    local emptyTarget={sources={},details={}}
    local rowBlock={}
    -- Defender: the leftmost enemy being attacked takes every Defend bonus. A lone enemy defends itself.
    local totalDefend=0
    for _,entry in ipairs(entries) do
        totalDefend=totalDefend+(tonumber(entry.data.defend) or 0)
            +(entry.perks~=nil and tonumber(entry.perks.defend) or 0)
    end
    local defendedGUID=nil
    if totalDefend>0 then
        if #entries==1 then
            defendedGUID=entries[1].guid
        else
            local leftX
            for _,group in ipairs(groups) do
                local attacked=false
                for _,index in ipairs(group.members) do
                    for _,item in ipairs((allocated[index] or emptyTarget).details) do
                        local family=item.detail.family
                        if family~="block" and family~="move" then attacked=true end
                    end
                end
                if attacked then
                    for _,index in ipairs(group.members) do
                        local obj=getObjectFromGUID(entries[index].guid)
                        local x=obj~=nil and obj.getPosition().x or nil
                        if x~=nil and (leftX==nil or x<leftX) then leftX,defendedGUID=x,entries[index].guid end
                    end
                end
            end
        end
        for _,entry in ipairs(entries) do
            if entry.guid==defendedGUID then
                entry.baseArmour=entry.baseArmour+totalDefend
                entry.elusiveArmour=entry.elusiveArmour+totalDefend
            end
        end
    end
    combatSyncDefenderMark(defendedGUID)
    for _,group in ipairs(groups) do
        local members,blockedAll={},{}
        for _,index in ipairs(group.members) do
            local entry=entries[index]
            local target=allocated[index] or emptyTarget
            local lines,damage,count,allBlocked,reductions=combatBlockResult(entry,target.sources)
            rowBlock[index]={lines=lines,damage=damage,count=count,allBlocked=allBlocked,reductions=reductions}
            blockedAll[entry.guid]=allBlocked
            members[#members+1]=entry
            for _,source in ipairs(target.sources) do group.sources[#group.sources+1]=source end
        end
        group.entry,group.attackArmour=combatGroupEntry(members,blockedAll)
        group.rangeTotal,group.rangeArmour,group.rangeDefeated,group.fortification=
            combatRangeResult(group.entry,group.sources)
    end

    for index=1,COMBAT_ASSIGNMENT_ROW_COUNT do
        local entry=entries[index]
        local group=groupOf[index]
        local isLeader=group~=nil and group.leader==index
        local lists={range={},block={},attack={}}
        if entry~=nil then
            for _,item in ipairs((allocated[index] or emptyTarget).details) do
                if item.detail.family=="block" or item.detail.family=="move" then
                    lists.block[#lists.block+1]={source=item.source,amount=item.detail.amount,
                        icon=item.detail.icon,text=item.detail.text,typeKey=item.detail.typeKey}
                end
            end
            -- Range, Siege and Attack resources of a group share the leader's merged cells.
            if isLeader then
                for _,member in ipairs(group.members) do
                    for _,item in ipairs((allocated[member] or emptyTarget).details) do
                        if item.detail.family~="block" and item.detail.family~="move" then
                            local phase=combatDetailPhase(item.detail,group.rangeDefeated,group.fortification)
                            local list=lists[phase]
                            list[#list+1]={source=item.source,amount=item.detail.amount,
                                icon=item.detail.icon,text=item.detail.text,typeKey=item.detail.typeKey,
                                reduced=combatEnemyResists(group.entry.data,group.entry.perks,item.detail.typeKey)}
                        end
                    end
                end
            end
        end
        for _,family in ipairs({"range","block","attack"}) do
            local items=lists[family]
            overflow=overflow+math.max(0,#items-COMBAT_ASSIGNMENT_SLOT_COUNT)
            for slot=1,COMBAT_ASSIGNMENT_SLOT_COUNT do
                local id="CombatSourceSlot"..index..family..slot
                local item=items[slot]
                if item~=nil then
                    combatAssignmentSlotSources[id]=item.source.guid
                    combatAssignmentIconButton(id,true,item.amount,item.icon,
                        item.source.name..": "..item.text,
                        combatAssignmentState.selected==item.source.guid,
                        item.typeKey~=nil and COMBAT_TYPE_COLORS[item.typeKey][item.reduced and 2 or 1] or nil)
                else
                    combatAssignmentIconButton(id,false,0,"","",false)
                end
            end
        end
        local merged=group~=nil and #group.members>1
        for _,family in ipairs({"range","attack"}) do
            combatPanelSetAttribute("CombatSourceCell"..index..family,"color",
                merged and "rgba(1,1,1,0.10)" or "rgba(0,0,0,0)")
        end
        local rowHeight=COMBAT_ASSIGNMENT_ROW_HEIGHT
        if entry~=nil then
            -- Final armour for the current layout: Elusive doubles unless every attack is blocked.
            local armourValue=entry.baseArmour
            if combatEnemyHasTrait(entry.data,entry.perks,"elusive") and not rowBlock[index].allBlocked then
                armourValue=entry.elusiveArmour
            end
            combatPanelSetAttribute("CombatEnemyRow"..index.."Armour","text",tostring(armourValue))
            local attackLines={}
            for attackIndex,attack in ipairs(combatEnemyAttacks(entry)) do
                local reduction=rowBlock[index].reductions[attackIndex] or 0
                attackLines[#attackLines+1]=combatTypeRich(attack.label.." "..tostring(attack.value-reduction),
                    attack.key,reduction>0)
            end
            combatPanelSetAttribute("CombatEnemyRow"..index.."Attacks","text",
                #attackLines>0 and table.concat(attackLines,"\n") or "-")
            local lines={}
            local isLast=group.members[#group.members]==index
            if group.rangeDefeated then
                -- Group results sit under the last enemy of the group.
                if isLast then
                    lines[1]=combatRich("Ranged "..tostring(group.rangeTotal).."/"..tostring(group.rangeArmour)
                        .." Defeated",COMBAT_GREEN)
                end
            else
                for _,line in ipairs(rowBlock[index].lines) do lines[#lines+1]=line end
                grandDamage=grandDamage+rowBlock[index].damage
                damageSources=damageSources+rowBlock[index].count
                if isLast then
                    local line=combatGroupAttackLine(group.entry,group.sources,group.attackArmour)
                    if line~=nil then lines[#lines+1]=line end
                end
            end
            rowHeight=math.max(rowHeight,math.max(#lines,entry.attackCount or 1)*17+8)
            local resultID="CombatEnemyRow"..index.."Result"
            combatPanelSetAttribute(resultID,"text",table.concat(lines,"\n"))
            combatPanelSetAttribute(resultID,"fontSize","13")
            combatPanelSetAttribute(resultID,"font","Fonts/MKCardText")
            combatPanelSetAttribute(resultID,"color","White")
            totalRowHeight=totalRowHeight+rowHeight
        end
        combatPanelSetAttribute("CombatEnemyRow"..index,"preferredHeight",tostring(rowHeight))
    end

    local showTotal=grandDamage>0
    combatPanelSetAttribute("CombatTotalRow","active",showTotal and "true" or "false")
    if showTotal then
        -- The spacer pushes the total under the Result column.
        local spacer=0
        for _,width in ipairs({130,55,150,170,110,130,170,170}) do spacer=spacer+width end
        combatPanelSetAttribute("CombatTotalSpacer","preferredWidth",tostring(spacer))
        combatPanelSetAttribute("CombatTotalDamage","text",
            "Total damage - "..combatRich(tostring(grandDamage),COMBAT_RED))
        combatPanelSetAttribute("CombatTotalDamage","font","Fonts/MKCardText")
        totalRowHeight=totalRowHeight+20
    end

    local selectionText
    if combatAssignmentState.selected~=nil then
        selectionText=joinLang({
            "{en}Source selected: click another enemy's row to move it there.",
            "{it}Fonte selezionata: clicca la cella Distanza/Assedio o Attacco per spostare tutte le risorse su quel nemico.",
            "{ru}Источник выбран: нажмите на ячейку Дальняя/Осадная или Атака, чтобы переместить все ресурсы к этому врагу.",
            "{zh-tw}已選擇來源：點擊該敵人的遠程／攻城或攻擊欄位，即可移動所有資源。",
            "{zh-cn}已选择来源：点击该敌人的远程／攻城或攻击栏位，即可移动所有资源。",
            "{ko}자원이 선택됨: 적의 원거리/공성 또는 공격 칸을 클릭해 모든 자원을 이동하세요.",
            "{es}Fuente seleccionada: haz clic en la celda de Rango/Asedio o Ataque para mover todos los recursos a ese enemigo.",
            "{fr}Source sélectionnée : cliquez sur la cellule Distance/Siège ou Attaque de l'ennemi pour y déplacer toutes les ressources.",
            "{pt-br}Fonte selecionada: clique na célula Distância/Cerco ou Ataque para mover todos os recursos para esse inimigo.",
            "{de}Quelle ausgewählt: Klicke auf das Fernkampf-/Belagerungs- oder Angriffsfeld des Feindes, um alle Ressourcen dorthin zu verschieben."
        })
    else
        selectionText=joinLang({
            "{en}Sources lock to the nearest enemy and the phase is chosen for you. Click an icon, then another enemy's row to retarget it. Click an enemy name to group it with the row above.",
            "{it}Le fonti iniziano sul nemico più vicino. Clicca un'icona, poi la cella della fase del nemico per riassegnarla.",
            "{ru}Источники изначально назначены ближайшему врагу. Нажмите на значок, затем на ячейку фазы нужного врага.",
            "{zh-tw}資源預設分配給最近的敵人。點擊圖示，再點擊另一敵人的階段欄位即可重新指定。",
            "{zh-cn}资源默认分配给最近的敌人。点击图标，再点击另一敌人的阶段栏位即可重新指定。",
            "{ko}자원은 가장 가까운 적에게 배정됩니다. 아이콘을 클릭한 다음 다른 적의 단계 칸을 클릭해 다시 지정하세요.",
            "{es}Las fuentes empiezan en el enemigo más cercano. Haz clic en un icono y luego en la fase de otro enemigo para reasignarla.",
            "{fr}Les sources commencent sur l'ennemi le plus proche. Cliquez sur une icône, puis sur la phase d'un autre ennemi pour la réattribuer.",
            "{pt-br}As fontes começam no inimigo mais próximo. Clique em um ícone e depois na fase de outro inimigo para reatribuí-la.",
            "{de}Quellen beginnen beim nächsten Feind. Klicke auf ein Symbol und dann auf die Phasenzelle eines anderen Feindes, um es neu zuzuweisen."
        })
    end
    if overflow>0 then
        selectionText=selectionText..joinLang({
            "{en}\nWarning: "..tostring(overflow).." enemies/resources exceed the visible assignment slots.",
            "{it}\nAvviso: "..tostring(overflow).." nemici/risorse superano gli spazi visibili.",
            "{ru}\nПредупреждение: врагов/ресурсов вне видимых ячеек: "..tostring(overflow)..".",
            "{zh-tw}\n警告：有 "..tostring(overflow).." 個敵人／資源超出可見欄位。",
            "{zh-cn}\n警告：有 "..tostring(overflow).." 个敌人／资源超出可见栏位。",
            "{ko}\n경고: 표시 슬롯을 초과한 적/자원 "..tostring(overflow).."개.",
            "{es}\nAviso: "..tostring(overflow).." enemigos/recursos exceden los espacios visibles.",
            "{fr}\nAttention : "..tostring(overflow).." ennemis/ressources dépassent les emplacements visibles.",
            "{pt-br}\nAviso: "..tostring(overflow).." inimigos/recursos excedem os espaços visíveis.",
            "{de}\nWarnung: "..tostring(overflow).." Feinde/Ressourcen überschreiten die sichtbaren Plätze."
        })
    end
    combatPanelSetAttribute("CombatEnemyPanel","width","1320")
    combatPanelSetAttribute("CombatEnemyPanel","color","rgb(0.24,0.2,0.15)")
    local headerWidths={Monster=130,Armour=55,DefenceTraits=150,RangeSiege=170,EnemyAttack=110,
        Offence=130,Block=170,AssignedAttack=170,Result=180}
    for name,width in pairs(headerWidths) do
        local id="Combat"..name.."Header"
        combatPanelSetAttribute(id,"font","Fonts/MKCardTittle")
        combatPanelSetAttribute(id,"color","rgb(0.95,0.9,0.78)")
        combatPanelSetAttribute(id,"preferredWidth",tostring(width))
        if name=="DefenceTraits" or name=="Offence" then
            combatPanelSetAttribute(id,"alignment","MiddleCenter")
        end
    end
    return totalRowHeight
end

local function combatCalcShutdown()
    combatCalcOn=false
    combatCumbersomeActive=false
    combatSyncDefenderMark(nil)
    combatPanelSetAttribute("CombatEnemyPanel","active","false")
    combatAssignmentState={seat=nil,selected=nil,targets={},explicit={}}
    combatAssignmentJoined={}
    if attackAssignmentsHasAny() then attackAssignmentsClearAll() end
end

local function refreshCombatEnemyPanel(monsters)
    if not combatCalcUpdate(monsters) then
        -- Calculator off: no panel, no arrows, no calculations. The player plays manually.
        combatCalcShutdown()
        return
    end
    combatPanelSetAttribute("CombatEnemyPanel","active","true")
    local entries={}
    for guid in pairs(monsters or {}) do
        local data=monsterPugs[guid]
        if data~=nil and not combatIsSummonedToken(guid) then
            local perks=gStates~=nil and gStates.monsterPerks~=nil and gStates.monsterPerks[guid] or nil
            local baseArmour=tonumber(data.armour) or 0
            local armourBonus=perks~=nil and (tonumber(perks.armour) or 0) or 0
            local armour=baseArmour+armourBonus
            entries[#entries+1]={guid=guid,name=tostring(data.name or "Enemy"),
                armour=tostring(armour),baseArmour=baseArmour+armourBonus,
                elusiveArmour=baseArmour*2+armourBonus,data=data,perks=perks,
                summoned=data.monsters~=nil and combatSummonedFor(guid) or nil}
        end
    end
    table.sort(entries,function(a,b)
        if a.name==b.name then return a.guid<b.guid end
        return a.name<b.name
    end)
    local currentSeat=combatAssignmentActiveSeat()
    if currentSeat~=combatAssignmentState.seat then
        combatAssignmentState={seat=currentSeat,selected=nil,targets={},explicit={}}
    end
    local sources=combatAssignmentSources(currentSeat)
    local activeSources={}
    for _,source in ipairs(sources) do
        activeSources[source.guid]=true
        -- Move only has a target while a Cumbersome attacker is in play.
        if not combatCumbersomeActive and source.move>0 then
            combatAssignmentState.explicit[source.guid]=nil
            if source.ranged+source.siege+source.block+source.attack==0 then
                combatAssignmentState.targets[source.guid]=nil
                attackAssignmentsClearForObject(source.guid)
            end
        end
    end
    for guid in pairs(combatAssignmentState.targets) do
        if activeSources[guid]~=true and not combatSourceKeepsLock(guid) then combatAssignmentState.targets[guid]=nil end
    end
    if combatAssignmentState.selected~=nil and activeSources[combatAssignmentState.selected]~=true then
        combatAssignmentState.selected=nil
    end
    local rowHeight=combatAssignmentRefreshRows(entries,sources)
    combatPanelSetAttribute("CombatEnemyPanel","height",
        tostring(COMBAT_ASSIGNMENT_PANEL_BASE_HEIGHT+rowHeight))
end

function resourceCardsRefreshCombatEnemies()
    refreshCombatEnemyPanel(combatPlayMonsters())
end

function resourceCardsCombatAssignSource(sourceGUID,enemyGUID)
    combatAssignmentState.targets[sourceGUID]=enemyGUID
    combatAssignmentState.explicit[sourceGUID]=true
    resourceCardsRefreshCombatEnemies()
    resourceCardsSourceChanged()
end

-- Click an enemy name to join it with the row above, or click again to split it off.
function resourceCardsCombatToggleGroup(row)
    local guid=combatAssignmentRowTargets[row]
    if guid==nil or row<2 then return end
    combatAssignmentJoined[guid]=combatAssignmentJoined[guid]~=true or nil
    resourceCardsRefreshCombatEnemies()
end

-- Called when a targeting arrow is removed; the source re-locks to the nearest enemy on refresh.
function resourceCardsCombatForgetSource(sourceGUID)
    combatAssignmentState.targets[sourceGUID]=nil
    combatAssignmentState.explicit[sourceGUID]=nil
end

function resourceCardsCombatAssignmentClick(id)
    local row=id:match("^CombatSourceSlot(%d+)")
    local index=row~=nil and tonumber(row) or nil
    local targetGUID=index~=nil and combatAssignmentRowTargets[index] or nil
    if targetGUID==nil then return end
    local sourceGUID=combatAssignmentSlotSources[id]
    if combatAssignmentState.selected~=nil then
        if sourceGUID==combatAssignmentState.selected then
            combatAssignmentState.selected=nil
        else
            local moved=combatAssignmentState.selected
            local movedSource=nil
            for _,candidate in ipairs(combatAssignmentSources(combatAssignmentState.seat)) do
                if candidate.guid==moved then movedSource=candidate break end
            end
            if movedSource~=nil and movedSource.ranged+movedSource.siege+movedSource.block+movedSource.attack==0
                and not combatGUIDHasCumbersome(targetGUID) then
                combatAssignmentState.selected=nil
                resourceCardsRefreshCombatEnemies()
                return
            end
            combatAssignmentState.targets[moved]=targetGUID
            combatAssignmentState.explicit[moved]=true
            combatAssignmentState.selected=nil
            attackAssignmentsSetSourceTarget(moved,targetGUID)
            resourceCardsSourceChanged()
        end
        resourceCardsRefreshCombatEnemies()
        return
    end
    if sourceGUID~=nil then combatAssignmentState.selected=sourceGUID end
    resourceCardsRefreshCombatEnemies()
end

-- The tracker belongs to the active Mage Knight, not everyone whose cards are on the table.
function resourceCardsCurrentTotals()
    if not resourceCardsPanelOpen() or turnOrder==nil or gStates.turnNumber==nil then return nil end
    local player=turnOrder[gStates.turnNumber]
    local scan=player~=nil and resourceCardScanBySeat[player.seatPos] or nil
    return scan~=nil and scan.totals or nil
end

local resourceTotalsKeyByField={
    move={move="move"},
    ranged={physical="ranged",fire="rangedFire",ice="rangedIce",iceFire="rangedColdFire",psychic="rangedPsychic"},
    siege={physical="siege",fire="siegeFire",ice="siegeIce",iceFire="siegeColdFire",psychic="siegePsychic"},
    attack={physical="attack",fire="attackFire",ice="attackIce",iceFire="attackColdFire",psychic="attackPsychic"},
    block={physical="block",fire="blockFire",ice="blockIce",iceFire="blockColdFire",psychic="blockPsychic"},
    influence={generated="influence"},
    healing={healing="healing"}
}

local attackTransformFamilies={"attack","ranged","siege"}
local attackTransformFields={"physical","fire","ice","iceFire","psychic"}

local function resourceCardsRawValue(tracker,totals,category,field)
    local manual=tracker~=nil and tracker[category]~=nil and tracker[category][field] or 0
    local fields=resourceTotalsKeyByField[category]
    local totalKey=fields~=nil and fields[field] or nil
    local estimated=totals~=nil and totalKey~=nil and (totals[totalKey] or 0) or 0
    return manual+estimated
end

function resourceCardsEffectiveValue(category,field)
    local tracker=gStates~=nil and gStates.resourceTracker or nil
    local totals=resourceCardsCurrentTotals()
    local current=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    local scan=current~=nil and resourceCardScanBySeat[current.seatPos] or nil
    local transform=totals~=nil and scan~=nil and scan.attackTransforms or nil
    if transform==nil or (not transform.coldFire and not transform.siege)
        or (category~="attack" and category~="ranged" and category~="siege") then
        return resourceCardsRawValue(tracker,totals,category,field)
    end

    -- Change the displayed Attack category, not original card/Unit records.
    -- Manual +/- values follow the same transformation as scanned attacks.
    local amount=0
    for _,sourceFamily in ipairs(attackTransformFamilies) do
        local destinationFamily=transform.siege and "siege" or sourceFamily
        if destinationFamily==category then
            for _,sourceField in ipairs(attackTransformFields) do
                local destinationField=transform.coldFire and "iceFire" or sourceField
                if destinationField==field then
                    amount=amount+resourceCardsRawValue(tracker,totals,sourceFamily,sourceField)
                end
            end
        end
    end
    return amount
end

function resourceCardsEffectiveMove()
    return math.max(0,resourceCardsEffectiveValue("move","move"))
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
-- City/Explore are not terrain: their special movement costs remain intact.
-- Claimed Skills keep their passive effects while their token remains at home.
local function ownedSkillAtSeat(guid,seatPos)
    local home=gStates~=nil and gStates.mageSkills~=nil and gStates.mageSkills[guid] or nil
    return home~=nil and home[1]~=nil and home[3]~=nil
        and home[3]<-30.5 and math.abs(home[1]-(seatPos*40-109.5))<15
end

local passableTerrain={
    plains=true,hills=true,forest=true,wasteland=true,desert=true,swamp=true,
    lake=true,mountain=true
}

local function cardTerrainEffects(rule,powered)
    if rule==nil or rule.terrainEffects==nil then return nil end
    if powered then return rule.terrainEffects.powered end
    return rule.terrainEffects.normal
end

local function terrainEffectActive(effect)
    return effect.dayRound==nil or effect.dayRound==(gStates.dayRound==true)
end

local function terrainEffectApplies(effect,terrain)
    return effect.terrains=="passable" and passableTerrain[terrain]==true
        or type(effect.terrains)=="table" and effect.terrains[terrain]==true
end

function resourceCardsEffectiveTerrainCost(terrain)
    local base=gStates~=nil and gStates.moveCost~=nil and gStates.moveCost[terrain] or nil
    if base==nil then base=999 end
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
    if setCost~=nil then return setCost end
    if base>=900 then return base end
    local cost=base
    -- Cap effects are evaluated before reductions so Song of Wind and
    -- Path Finding can stack, with higher-minimum reductions applied first.
    for _,effect in ipairs(effects) do
        if effect.mode=="cap" and terrainEffectApplies(effect,terrain) then
            cost=math.min(cost,effect.cost)
        elseif effect.mode=="reduce" and terrainEffectApplies(effect,terrain) then
            cost=math.max(effect.minimum or 0,cost-effect.amount)
        end
    end
    return cost
end

local function clearHighlight(guid)
    if shown[guid]==nil then return end
    local obj=getObjectFromGUID(guid)
    if obj~=nil then obj.highlightOff() end
    shown[guid]=nil
end

local function setHighlight(obj,kind,powered)
    if unitHighlightBlocked[obj.guid]==true then
        clearHighlight(obj.guid)
        return
    end
    -- Crystal figurines represent mana but are visually distinctive already.
    -- Keep their power detection/contribution records, without outlining the
    -- figurine. Remove any highlight left from the previous tracker version.
    if isManaTokenFigurine(obj) then
        if shown[obj.guid]~=nil then
            clearHighlight(obj.guid)
        elseif crystalHighlightCleared[obj.guid]~=true then
            obj.highlightOff()
        end
        crystalHighlightCleared[obj.guid]=true
        return
    end
    local choice=kind..(powered and "Bright" or "Normal")
    if shown[obj.guid]==choice then return end
    -- Omit duration: TTS keeps this highlight until highlightOff() is called.
    obj.highlightOn(palette[kind][powered and 2 or 1])
    shown[obj.guid]=choice
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

local sidewaysChoices={{move=1},{block=1},{attack=1},{influence=1}}

local choiceLetters={attackP1="A",attackP2="A2",attackP3="A3",
    attackF1="AF",attackF2="AF2",attackI1="AI",attackI2="AI2",
    attackIF1="AC",attackIF2="AC2",
    block2Attack1="B2/A1",block1Attack2="B1/A2",
    blockP1="B",blockF1="BF",blockI1="BI",blockIF1="BC",
    twiceAttack="A2",twiceBlock="B2",move="M",influence="I",attack="A",block="B",
    ranged="R",siege="S",healing="H",draw="D",other="O",
    siegeFire="SF",siegeIce="SI",rangedFire="RF",rangedIce="RI",
    fire="F",ice="I",coldFire="C",boost="H+",split="I/F",negative="N",
    heal="H",combat="C",wound="W",fame="F",reputation="R",gain="G",ready="R",
    base="2",sourceUnused="3",red="R",blue="B",white="W",green="G",
    fireAttack="F",fireBlock="F",fireSiege="F",iceSiege="I",fireBlockOnly="B",fireBlockCounter="B+",
    splitBlock="B2",zero="0",one="1",two="2",three="3",four="4",five="5"}
-- The choice UI and initial-guess tie-breaks follow the Resource Tracker order.
local resourceChoiceOrder={
    move=1,siege=2,ranged=3,block=4,attack=5,influence=6,healing=7,heal=7,fame=8,
    fireBlock=4,fireAttack=5,fireSiege=2,iceSiege=2
}
local resourceChoiceFamilies={"move","siege","ranged","block","attack","influence","healing"}
local function resourceChoiceRank(category,choice)
    local rank=resourceChoiceOrder[category]
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
	return (category:find("attack",1,true)~=nil or category:find("Attack",1,true)~=nil
			or category:find("block",1,true)~=nil or category:find("Block",1,true)~=nil
			or category:find("siege",1,true)~=nil or category:find("Siege",1,true)~=nil
			or category:find("ranged",1,true)~=nil or category:find("Range",1,true)~=nil
			or category=="twiceAttack" or category=="twiceBlock")
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

-- Bonus choices are independent of the card's primary selection. Until the
-- player chooses a bonus explicitly, it follows the main choice (or the
-- printed first alternative if the main category is unavailable).
local function inventorySetChoice(guid,index,choices,mainChoices)
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
        for _,offset in pairs(tracker~=nil and tracker[family] or {}) do
            value=value+offset
        end
        for _,totalKey in pairs(resourceTotalsKeyByField[family]) do
            value=value+(estimated[totalKey] or 0)-(own[totalKey] or 0)
        end
        scores[family]=math.max(0,value)
    end
    return scores
end

local function guessInitialCardChoice(card,choices,seatPos,rule,sideways)
    if selectedResourceByGUID[card.guid]~=nil or choices==nil or #choices<2
        or card.is_face_down==true then return end
    local scores=trackerChoiceScores(card.guid,seatPos)
    local best,bestValue,bestRank=nil,nil,nil
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
        if totalsKeys[category] and type(value)=="number" and value~=0 then
            return true
        end
    end
    return false
end

-- These are tiny object XML buttons over the artwork, not the much larger
-- Meditation buttons beside the card. Preserve other object UI elements.
local function removeChoiceButtons(card)
    if card==nil or card.UI==nil then return end
    local xml=card.UI.getXmlTable() or {}
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
    if changed then card.UI.setXmlTable(#xml>0 and xml or {{}}) end
    choiceButtonShown[card.guid]=nil
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

-- A single selected icon is centred on the object. Click to expand all
-- choices; selecting one immediately collapses back to its icon.
local function showChoiceButtons(card,choices,powered,inventorySpec,inventorySets,resources)
    if card==nil then return end
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
    local isArtifact=data~=nil and data.cardType=="Artifact"
    if choices==nil or #choices==0
        or (card.is_face_down==true and not isSkill and not isArtifact)
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
    if powered and posture=="upright" and inventorySpec~=nil then
        for i=1,(inventorySets or 0) do
            rows[#rows+1]={index=i,choices=inventorySpec.choices}
        end
    end
    local expandedRow=choiceExpandedByGUID[card.guid]
    local signatureParts,visibleAssets,assetSeen={}, {}, {}
    for _,row in ipairs(rows) do
        local _,selected
        if row.index==0 then
            _,selected=currentChoice(card.guid,powered,row.choices,
                not isSkill and posture=="sideways")
        else
            _,selected=inventorySetChoice(card.guid,row.index,row.choices,choices)
        end
        row.selected=selected
        row.entries={}
        local seen={}
        for j,choice in ipairs(row.choices) do
            local category=choiceCategory(choice)
            if category~=nil and choiceLetters[category]~=nil and not seen[category] then
                seen[category]=true
                row.entries[#row.entries+1]={category=category,
                    rank=resourceChoiceRank(category,choice),originalIndex=j,
                    skillFamily=isSkill and skillChoiceFamily(category,choice) or nil,
                    icon=choice.icon or category,iconOverlay=choice.iconOverlay,
                    stackedIcons=choice.stackedIcons,
                    iconOverlayColor=choice.iconOverlayColor,
                    iconOverlayAlignment=choice.iconOverlayAlignment,
                    iconOverlaySize=choice.iconOverlaySize}
            end
        end
        table.sort(row.entries,function(a,b)
            if a.rank~=b.rank then return a.rank<b.rank end
            return a.originalIndex<b.originalIndex
        end)
        if #row.entries<1 or selected==nil then
            if choiceButtonShown[card.guid]~="hidden" then
                removeChoiceButtons(card)
                choiceButtonShown[card.guid]="hidden"
            end
            choiceExpandedByGUID[card.guid]=nil
            return
        end
        row.expanded=#row.entries>1 and ((row.index==0 and (expandedRow==true or expandedRow=="base"))
            or expandedRow=="set"..tostring(row.index))
        local selectedEntry
        for _,entry in ipairs(row.entries) do
            if entry.category==selected then selectedEntry=entry break end
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
            if not row.expanded and choiceHasTargetableCombatResource(entry.category)
                and not assetSeen.target then
                visibleAssets[#visibleAssets+1]="target"
                assetSeen.target=true
            end
        end
        signatureParts[#signatureParts+1]=row.index..":"..selected..":"
            ..(row.expanded and "open" or "closed")..":"..table.concat(categories,",")
    end
    local buttonRotation=180
    if posture=="sideways" then
        buttonRotation=card.getRotation()[2]%360<180 and 90 or 270
    end
    local uiRotation=card.is_face_down==true and "0 180 180" or ("0 0 "..buttonRotation)
    -- Keep Skill icons just clear of the token surface to prevent
    -- z-fighting/flicker when the camera moves. Other object UI depths stay put.
    local buttonDepth=isSkill and (card.is_face_down==true and "12" or "-12")
        or (card.is_face_down==true and "35" or "-35")
    local signature=(posture=="sideways" and "S" or (powered and "P" or "N"))
        ..":"..table.concat(signatureParts,";")..":"..uiRotation..":"..buttonDepth
        ..(combatCalcOn and (combatCumbersomeActive and ":CC" or ":C") or "")
    if choiceButtonShown[card.guid]==signature then return end
    local xml=card.UI.getXmlTable() or {}
    for i=#xml,1,-1 do
        local attr=xml[i].attributes
        if attr~=nil and type(attr.id)=="string"
            and (attr.id:sub(1,19)=="ResourceCardChoice_"
                or attr.id:find("^AttackAssignmentSource_")~=nil) then table.remove(xml,i) end
    end
    local assets,blocked=resourceCardsChoiceAssetsFor(card.UI,visibleAssets)
    local multi=#rows>1
    for _,row in ipairs(rows) do
        local columns,columnByCategory={},{}
        for _,entry in ipairs(row.visible) do
            local column=resourceChoiceColumn(entry.category)
            if columnByCategory[column]==nil then
                columns[#columns+1]=column
                columnByCategory[column]=#columns
            end
        end
        local y=isSkill and 0 or (-12-(#rows-1)*15+row.index*30)
        -- 0 = printed stronger effect; 1, 2, ... = crystal set bonuses.
        if multi then
            xml[#xml+1]={tag="Text",attributes={
                id="ResourceCardChoice_"..card.guid.."_label"..row.index,
                position="-80 "..tostring(y).." "..buttonDepth,rotation=uiRotation,
                width=60,height=90,scale="0.25 0.25",fontSize=62,
                color="#DAE1EA",alignment="MiddleCenter",
                raycastTarget="false",text=tostring(row.index)}}
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
                ..(row.index>0 and ("set"..row.index.."_") or "")..category
            if #row.entries>1 then
                local button={tag="Button",attributes={
                    id=buttonId,onClick="global/resourceCardsChoiceClicked",
                    position=tostring(x).." "..tostring(buttonY).." "..buttonDepth,
                    rotation=uiRotation,width=90,height=90,
                    scale=buttonScale,
                    colors=active and "#387D30|#4CA940|#387D30|#387D30"
                        or "#454D5D|#69798E|#444C63|#454D5D",
                    fontSize=77,textColor="#FFFFFF",textAlignment="MiddleCenter"
                },value=icon==nil and choiceLetters[category] or ""}
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
                    xml[#xml+1]=button
                end
            end
            if not row.expanded and choiceHasTargetableCombatResource(category) then
                local resource=row.index>0 and ("set"..row.index..":"..category) or category
                local targetX=x
                if #row.entries>1 then targetX=x+(x>=0 and buttonSpacing/2 or -buttonSpacing/2) end
                xml[#xml+1]={tag="Button",attributes={
                    id="AttackAssignmentSource_"..card.guid.."_"..tostring(row.index).."_"..category,
                    onClick="global/attackAssignmentSourceClicked",
                    position=tostring(targetX).." "..tostring(buttonY).." "..buttonDepth,
                    rotation=uiRotation,width=90,height=90,scale=buttonScale,
                    colors="#454D5D|#69798E|#444C63|#454D5D",textColor="#FFFFFF",textAlignment="MiddleCenter"
                },value="",children={{tag="Image",attributes={
                    image=resourceCardsChoiceIcon("target").name,width=82,height=82,
                    preserveAspect="true",raycastTarget="false",color="#FFFFFF"}}}}
            end
        end
    end
    if assets~=nil then card.UI.setXmlTable(xml,assets)
    else card.UI.setXmlTable(xml) end
    choiceButtonShown[card.guid]=signature
end


-- One selected icon in the Unit's lower-left artwork margin, away from
-- its Command token. Expand vertically in printed ability order.
-- Alternatives sharing a printed row occupy adjacent columns to the right.
-- This is intentionally independent of translated text position.
local function showUnitAbilityButtons(unit,abilities,activation,unwounded,decision)
    if unit==nil then return end
    if not unwounded or activation==nil or abilities==nil or #abilities==0 then
        removeChoiceButtons(unit)
        choiceExpandedByGUID[unit.guid]=nil
        return
    end
    local decision=decision or unitManaDecision(unit,abilities,activation)
    local available=decision.display
    if #available<2 and not decision.ambiguous then
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
    local expanded=(decision.ambiguous and not abilities.paidChoiceExpandable)
        or (choiceExpandedByGUID[unit.guid]==true and #available>1)
    local selectedKeys={}
    for i in pairs(decision.selected or {}) do selectedKeys[#selectedKeys+1]=tostring(i) end
    table.sort(selectedKeys)
    local signature="Unit:"..tostring(selected)..":"..tostring(expanded)
        ..":"..table.concat(available,",")..":"..table.concat(selectedKeys,",")
    if choiceButtonShown[unit.guid]==signature then return end

    local xml=unit.UI.getXmlTable() or {}
    for i=#xml,1,-1 do
        local attr=xml[i].attributes
        if attr~=nil and type(attr.id)=="string"
            and attr.id:sub(1,19)=="ResourceCardChoice_" then table.remove(xml,i) end
    end
    local visibleAssets,seen={},{}
    local displayed=expanded and available or {selected or available[1]}
    for _,index in ipairs(displayed) do
        local ability=abilities[index]
        local name=ability.icon or ability.key
        if not seen[name] then visibleAssets[#visibleAssets+1]=name seen[name]=true end
    end
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
    else
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
            local icon=resourceCardsChoiceIcon(ability.icon or ability.key)
            if icon~=nil and blocked[icon.name] then icon=nil end
            local button={tag="Button",attributes={
                id="ResourceCardChoice_"..unit.guid.."_unit"..index,
                onClick="global/resourceUnitsChoiceClicked",
                position=tostring(baseX-(columnIndex-1)*columnSpacing).." "..tostring(y).." -35",
                rotation="0 0 180",width=90,height=90,scale="0.22 0.22",
                colors=active and "#387D30|#4CA940|#387D30|#387D30"
                    or "#454D5D|#69798E|#444C63|#454D5D",
                fontSize=77,textColor="#FFFFFF",textAlignment="MiddleCenter"
            },value=icon==nil and (ability.buttonLabel
                or (ability.key=="other" and tostring(ability.row))
                or choiceLetters[ability.key] or "?") or ""}
            if icon~=nil then
                button.children={{tag="Image",attributes={
                    image=icon.name,width=82,height=82,preserveAspect="true",
                    raycastTarget="false",color="#FFFFFF"}}}
                if ability.iconOverlay~=nil then
                    button.children[#button.children+1]={tag="Text",attributes={
                        text=ability.iconOverlay,width=82,height=82,
                        alignment="MiddleCenter",fontSize=62,fontStyle="Bold",
                        color=ability.iconOverlayColor or "#FF564A",
                        outline="#1C1514",outlineSize="2 -2",
                        raycastTarget="false"}}
                end
            end
            xml[#xml+1]=button
        end
    end
    if assets~=nil then unit.UI.setXmlTable(xml,assets)
    else unit.UI.setXmlTable(xml) end
    choiceButtonShown[unit.guid]=signature
end


local function clearChoiceButtons()
    for guid,signature in pairs(choiceButtonShown) do
        if signature~="hidden" then removeChoiceButtons(getObjectFromGUID(guid)) end
    end
    choiceButtonShown={}
end

-- Reset a player's explicit choice only after the card has actually finished
-- leaving that player's Play Area. Zone exits while held are not new plays.
local function cardInSeatPlayArea(guid,seatPos)
    local zoneGUID=playerPlayAreas~=nil and playerPlayAreas[seatPos] or nil
    local zone=zoneGUID~=nil and getObjectFromGUID(zoneGUID) or nil
    if zone==nil then return false end
    for _,obj in ipairs(zone.getObjects()) do
        if obj.guid==guid then return true end
    end
    return false
end

local function scheduleChoiceResetAfterPlay(guid,seatPos)
    if guid==nil or seatPos==nil or selectedResourceByGUID[guid]==nil then return end
    choiceResetGenerationByGUID[guid]=(choiceResetGenerationByGUID[guid] or 0)+1
    local serial=choiceResetGenerationByGUID[guid]
    -- Allow the zone's membership to settle before checking whether this
    -- is a real departure or just a temporary lift/rearrangement.
    safeWaitFrames("PlayerBoard.CardRecognition",function()
        if choiceResetGenerationByGUID[guid]~=serial then return end
        safeWaitCondition("PlayerBoard.CardRecognition",function()
            if choiceResetGenerationByGUID[guid]~=serial then return end
            if not cardInSeatPlayArea(guid,seatPos) then
                selectedResourceByGUID[guid]=nil
                choiceExpandedByGUID[guid]=nil
            end
        end,function()
            if choiceResetGenerationByGUID[guid]~=serial then return true end
            local obj=getObjectFromGUID(guid)
            return obj==nil or (obj.held_by_color==nil and obj.resting==true
                and obj.isSmoothMoving()==false)
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
        local face=obj.getRotationValue()
        if type(face)=="string" then return face:match("^([%a]+) Mana$") end
    end
    return nil
end

-- Reuse the same stable identifiers as Skills and Combat's faction reward cleanup.
-- No name/description guessing for Skills, Units or Faction Rewards.
local factionRewardNotes={
    ["Dark Crusader Reward"]="Dark",
    ["Elementalist Reward"]="Elem",
    ["Apocalypse Cult Reward"]="Apoc",
    ["Council of the Void Reward"]="Coun"
}

-- Original container GUIDs collide across factions in the pushed JSON.
-- Front-art image hashes are independent of translated names and survive
-- regenerated GUIDs when a token is extracted from a bag.
factionRewardForObject=function(obj)
    if obj==nil or factionRewardNotes[obj.getGMNotes()]==nil then return nil end
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
    if factionRewardNotes[obj.getGMNotes()]~=nil then return "factionReward" end
    return nil
end

local function matchesCardMana(card,color)
    if color==nil then return false end
    local data=gameCards[card.guid]
    if data==nil then return color=="Red" or color=="Blue" or color=="Green" or color=="White" end
    if data.cardType=="Artifact" then return false end
    if color=="Gold" then return gStates.dayRound==true end
    if color=="Black" then return data.cardType=="Spell" end
    local colors=data.color
    if type(colors)=="string" then return colors==color end
    if type(colors)=="table" then
        for _,cardColor in ipairs(colors) do if cardColor==color then return true end end
    end
    return false
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
local function effectManaPossibilities(spec,payments,needPower,daytime)
    local possible,anyColor={},false
    local function hasDistinctPower(effectGUID,castGUID)
        if not needPower then return true end
        for _,payment in ipairs(payments) do
            if payment.guid~=effectGUID and payment.guid~=castGUID
                and payment.color==spec.powerColor then return true end
        end
        return false
    end
    for _,effect in ipairs(payments) do
        local category=spec.colors[effect.color]
        local wildcard=effect.color=="Gold" and daytime
        if category~=nil or wildcard then
            local valid=false
            if spec.castColor==nil then
                valid=hasDistinctPower(effect.guid,nil)
            else
                for _,casting in ipairs(payments) do
                    if casting.guid~=effect.guid
                        and (casting.color==spec.castColor
                            or (casting.color=="Gold" and daytime))
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

-- Colour-triggered Actions use stable target-card data, not translated text.
-- Dual-colour Actions offer an explicit choice, using the existing card buttons.
local basicActionColors={"Red","Blue","White","Green"}
local function linkedColorChoices(rule,targetGUID,powered)
    if rule==nil or rule.linkedColorEffects==nil or targetGUID==nil then return nil end
    local data=gameCards[targetGUID]
    local colors=data~=nil and data.color or nil
    if colors==nil then return nil end
    if type(colors)=="string" then colors={colors} end
    local definitions=powered and rule.linkedColorEffects.powered
        or rule.linkedColorEffects.normal
    local choices={}
    for _,color in ipairs(basicActionColors) do
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
local landPrintedMoveDay={
    plains=2,hills=3,forest=3,wasteland=4,desert=5,swamp=5,
    lake=2,mountain=5,city=2
}
local landPrintedMoveNight={
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
    local costs=gStates.dayRound==true and landPrintedMoveDay or landPrintedMoveNight
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

-- One sideways calculator for ordinary Actions and Skill-linked exceptions.
-- A linked Skill changes the value, not the player's chosen resource.
local function calculateSideways(card,known,skillLink)
    local choice=chosenEffect(card.guid,false,sidewaysChoices,true)
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
    local tracked=data==nil or data.resourceTracked~=false
    local powered=manaPowered or linkedBoost~=nil
    if repeatLink~=nil then powered=repeatLink.powered end
    local posture=cardPosture(card)
    -- A non-resource Action is neutral upright, but still gives the standard
    -- selectable +1 when played sideways like any other non-Wound Action.
    if data~=nil and data.resourceAlwaysNeutral==true and posture~="sideways" then
        return {guid=card.guid,known=true,complete=true,powered=false,
            links=linked,status=#linked>0 and "purple" or "blue",resources=nil}
    end
    -- Face-down Artifacts play their Break effect. Face-down Actions stay
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
            chosen=gStates.dayRound==true and {blockFire=value} or {blockIce=value}
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
    if effects~=nil and discardBonus~=nil and discardBonus>0 then
        local adjusted={}
        for category,value in pairs(effects) do
            adjusted[category]=(totalsKeys[category] and type(value)=="number")
                and value+discardBonus or value
        end
        effects=adjusted
    end
    if effects~=nil and repeatLink~=nil then
        -- The base may be a cardResourceDefinitions entry. Never modify it:
        -- each new placement/drop recalculates from the same printed values.
        local repeated={}
        for category,value in pairs(effects) do
            repeated[category]=(totalsKeys[category] and type(value)=="number")
                and value*repeatLink.count or value
        end
        effects=repeated
    end
    -- A card's other unimplemented options do not make its currently selected
    -- *known* resource effect uncertain. Keep the first option as the fast,
    -- green default; only a genuinely unresolved selected effect stays yellow.
    local knownSelectedOption=chosen~=nil and effectHasTrackedResource(chosen)
    local complete=sideTracked and base~=nil and not choicePending and not statePartial
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
    -- Linking information is more valuable than the underlying certainty colour.
    if #linked>0 then status="purple" end
    return {guid=card.guid,known=known,complete=complete,powered=powered,
        links=linked,status=status,resources=effects,
        usesTerrainBlock=usesTerrainBlock and faceUp and costPaid and canApply,
        repeatCount=repeatLink~=nil and repeatLink.count or nil}
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
    -- The same Action-target pairing serves copying and throwing away.
    -- Reserve targets before ordinary discard payments to avoid double use.
    for _,source in ipairs(cards) do
        local data=gameCards[source.guid]
        local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
        local requirement=rule~=nil and rule.requiredLink or nil
        if requirement~=nil and (requirement.mode=="repeat" or requirement.mode=="throwAway")
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
                if requirement.mode=="repeat" then
                    local strong=manaPowered[source.guid]==true or boostBy[source.guid]~=nil
                    repeatByTarget[target.guid]={powered=strong,
                        count=strong and requirement.poweredCount or requirement.normalCount}
                end
                connect(source,target)
            end
        end
    end
    -- Resolve discard costs after stronger links: a link-boosted Improvisation
    -- can still discard ANOTHER card, but never its own booster as payment.
    for _,source in ipairs(cards) do
        local data=gameCards[source.guid]
        local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
        if discarded[source.guid]==nil and rule~=nil and rule.requiredLink~=nil
            and rule.requiredLink.mode=="discard"
            and source.is_face_down~=true and cardPosture(source)=="upright"
            and not (data~=nil and data.cardType=="Artifact"
                and source.is_face_down==true) then
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
            if target~=nil then
                discarded[target.guid]=source.guid
                hasDiscard[source.guid]=true
                linkedCardBySource[source.guid]=target.guid
                connect(source,target)
            end
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
            and source.is_face_down~=true and cardPosture(source)=="upright" then
            local chosen=selectedResourceByGUID[source.guid]
            local strong=manaPowered[source.guid]==true or boostBy[source.guid]~=nil
                or (data~=nil and data.cardType=="Artifact"
                    and source.is_face_down==true)
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
            for _,target in ipairs(choices) do
                local isWound=target.getGMNotes()=="Wound"
                local targetData=gameCards[target.guid]
                local eligible=isWound or (targetData~=nil
                    and (targetData.cardType=="Starting" or targetData.cardType=="Advanced Action"
                        or targetData.cardType=="Spell" or targetData.cardType=="Artifact"))
                if target.guid~=source.guid and eligible
                    and (not spec.woundOnly or isWound)
                    and (not isWound or woundPayments<(spec.maxWounds or 0))
                    and discarded[target.guid]==nil and not boostClaimed[target.guid]
                    and #links[target.guid]==0 and skillLinksByTarget[target.guid]==nil
                    and not manaPowered[target.guid]
                    and target.is_face_down~=true and cardPosture(target)=="discard"
                    and overlapArea(footprints[source.guid],footprints[target.guid])>0 then
                    discarded[target.guid]=source.guid
                    connect(source,target)
                    if isWound then woundPayments=woundPayments+1 end
                    bonus=bonus+spec.perCard
                end
            end
            if bonus>0 then discardBoostBySource[source.guid]=bonus end
            end
        end
    end
    return links,boostBy,boostSource,discarded,hasDiscard,linkedCardBySource,
        repeatByTarget,discardBoostBySource
end

-- Generic Skill-card links: one Skill per target, one target per Skill.
-- The descriptor, not an individual Skill GUID, determines replacement value,
-- card-type bonuses, mana payment and player-declared conditional values.
local function manaInsideFootprint(mana,area)
    local p=mana.getPosition()
    return math.abs(p[1]-area.x)<area.halfX
        and math.abs(p[3]-area.z)<area.halfZ
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
                    if not seen[obj.guid] and manaColor(obj)~=nil then
                        seen[obj.guid]=true
                        tokens[#tokens+1]=obj
                    end
                end
            end
        end
    end
    local counts,area={},footprint(unit)
    for _,mana in ipairs(tokens) do
        local color=manaColor(mana)
        if color~=nil and (not crystalsOnly or isManaTokenFigurine(mana))
            and manaInsideFootprint(mana,area) then
            counts[color]=(counts[color] or 0)+1
        end
    end
    return counts
end

local function unitAbilityPaid(ability,counts)
    local color=ability.manaCost
    if color==nil then return true end
    if (counts[color] or 0)>0 then return true end
    -- Daytime Gold can pay any basic colour, but not Black.
    return color~="Black" and gStates.dayRound==true and (counts.Gold or 0)>0
end

local function unitManaSignature(counts)
    local parts={tostring(gStates.dayRound==true)}
    for _,color in ipairs({"Red","Blue","Green","White","Black","Gold"}) do
        parts[#parts+1]=tostring(counts[color] or 0)
    end
    return table.concat(parts,":")
end

unitManaDecision=function(unit,abilities,activation,counts)
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
    if abilities.multi==true then
        local chosen={}
        for _,index in ipairs(direct) do chosen[index]=true end
        local goldCount=gStates.dayRound==true and (counts.Gold or 0) or 0
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
        return result
    end
    if #paid==1 then
        -- One payable ability means no option button is needed.
        result.index=paid[1]
    elseif #paid>1 then
        -- E.g. Altem Mages' two Black options or Catapults paid by Gold.
        result.ambiguous=true
        result.display=paid
        if activation.manaSignature==signature then
            for _,index in ipairs(paid) do
                if activation.manaChoice==index then result.index=index break end
            end
        end
    else
        -- Unpaid abilities stay hidden until matching mana is actually there.
        result.display=free
        for _,index in ipairs(free) do
            if activation.choice==index then result.index=index break end
        end
        if result.index==nil then result.index=free[1] end
    end
    return result
end

local function sidewaysManaAvailable(color)
    return color~=nil and (color~="Gold" or gStates.dayRound==true)
        and (color~="Black" or gStates.dayRound~=true)
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

local function sidewaysModifierValue(skill,target,descriptor,mana,unitState)
    local value=skill.is_face_down==true and descriptor.faceDownValue
        or descriptor.value or 1
    local cardData=gameCards[target.guid]
    if descriptor.cardTypeValues~=nil and cardData~=nil then
        value=descriptor.cardTypeValues[cardData.cardType] or value
    end
    if descriptor.choiceValues~=nil then
        local rule=skillResourceDefinitions[skill.guid]
        local _,choice=currentChoice(skill.guid,false,rule.choices)
        value=descriptor.choiceValues[choice] or value
    end
    if mana~=nil and descriptor.matchingManaValue~=nil
        and matchingSidewaysMana(target,manaColor(mana)) then
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
        if spec~=nil and spec.sideways~=nil then
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
local oppositeMana={Red="Blue",Blue="Red",Green="White",White="Green",Gold="Black",Black="Gold"}

local function convertedManaMatchesCard(card,color)
    local data=gameCards[card.guid]
    if data==nil or card.is_face_down==true or cardPosture(card)~="upright" then return false end
    if data.cardType~="Starting" and data.cardType~="Advanced Action"
        and data.cardType~="Spell" and data.cardType~="Artifact" then return false end
    -- Gold follows the day rule; Black Spell strength is not legality-checked.
    if color=="Gold" and gStates.dayRound~=true then return false end
    if color=="Black" and data.cardType~="Spell" then return false end
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
                local converted=spec.mode=="opposite" and oppositeMana[original] or nil
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
    if gStates.dayRound~=true then return false end
    local player=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    local site=player~=nil and player.avatarLocation or nil
    return site~="dungeon" and site~="tomb"
end

-- Puppet Master tokens already have authoritative half-strength Attack/Block
-- perk data. Keep each printed Attack separate: a Puppet cannot combine all
-- of its enemy's different attacks into one automatic total.
local puppetTypes={P="",F="Fire",I="Ice",IF="ColdFire"}
local puppetTypeOrder={"P","F","I","IF"}
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
        for _,attackType in ipairs(puppetTypeOrder) do
            local entries=perks[family]~=nil and perks[family][attackType] or nil
            if type(entries)=="table" then
                for i,value in ipairs(entries) do
                    if type(value)=="number" and value>0 then
                        ---@type table<string, string|number>
                        local choice={key=family..attackType..i,icon=family}
                        if attackType~="P" then choice.iconOverlay=attackType=="IF" and "C" or attackType end
                        choice[family..puppetTypes[attackType]]=value
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
    local choices=rule.choices
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
    local unitLinked=#unitSources>0
    local status=rule.untracked and "blue"
        or (rule.unitBoost~=nil or rule.shapeshift or rule.attackCardBoost) and "yellow"
        or (linkedTarget~=nil or unitLinked) and "purple"
        or (unitResolved or inventoryResolved) and "green"
        or rule.linkedCard~=nil and linkedTarget==nil and "yellow"
        or tracked and (rule.partial and "yellow" or "green")
        or effects~=nil and "blue" or "yellow"
    local links={}
    if linkedTarget~=nil then links[#links+1]=linkedTarget end
    for _,guid in ipairs(unitSources) do links[#links+1]=guid end
    return {guid=skill.guid,kind="skill",known=true,
        complete=unitResolved or inventoryResolved or (tracked and not rule.partial) or linkedTarget~=nil,
        powered=skill.is_face_down==true or linkedTarget~=nil or unitLinked,
        status=status,links=links,unitSources=unitSources,
        resources=effects,choices=choices}
end

local terrainEffectOrder={set=0,cap=1,reduce=2}
local function terrainModifierPrecedes(a,b)
    local first,second=terrainEffectOrder[a.mode] or 9,terrainEffectOrder[b.mode] or 9
    if first~=second then return first<second end
    if a.mode=="reduce" then return (a.minimum or 0)>(b.minimum or 0) end
    return false
end

-- Count only printed enemy-token icons, not site-given traits.
-- A Coldfire attack represents both Fire and Ice attack-colour icons.
local enemyPrintedAbilityKeys={
    "swiftness","cumbersome","brutal","poison","paralyse",
    "assassination","vampiric","elusive","fortified","unfortified",
    "defend","pResist","fResist","iResist"
}
local function enemyPrintedIconBonus(enemy)
    if enemy==nil then return nil end
    if enemy.arcaneImmunity==true then return 0 end
    local count=0
    for _,key in ipairs(enemyPrintedAbilityKeys) do
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

-- The stronger Possess Spell borrows the target enemy's printed melee Attacks.
-- Every printed attack counts, with its element, but none of its abilities
-- (Swift, Brutal, etc.) change the borrowed value.
local possessedAttackKeys={P="attack",F="attackFire",I="attackIce",IF="attackColdFire"}
local function enemyPrintedPossessAttack(enemy)
    if enemy==nil or enemy.arcaneImmunity==true
        or type(enemy.attack)~="table" then return nil end
    local resources={}
    for element,category in pairs(possessedAttackKeys) do
        local attacks=enemy.attack[element]
        if type(attacks)=="table" then
            for _,value in ipairs(attacks) do
                if type(value)=="number" and value>0 then
                    resources[category]=(resources[category] or 0)+value
                end
            end
        end
    end
    return next(resources)~=nil and resources or nil
end

local function addResourceAmounts(result,totals)
    result.contributes=false
    if result.resources==nil then return end
    for category,value in pairs(result.resources) do
        if totalsKeys[category] and type(value)=="number" then
            totals[category]=(totals[category] or 0)+value
            if value~=0 then result.contributes=true end
        end
    end
end

-- Scan the play area for used abilities, the Unit area for Units, and crystal
-- inventory for unused mana. Only a played, supported effect enters the totals.
local function renderSeat(seatPos)
    if not resourceCardsPanelOpen() then return end
    local active=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    if active==nil or active.seatPos~=seatPos then return end

    local objects,placements,monsters,playMonsters={},{},{},{}
    local function inspectZone(guid,zoneKind)
        local zone=guid~=nil and getObjectFromGUID(guid) or nil
        if zone==nil then return end
        for _,obj in ipairs(zone.getObjects()) do
            if (zoneKind=="play" or zoneKind=="unit")
                and monsterPugs[obj.guid]~=nil then
                monsters[obj.guid]=obj
                if zoneKind=="play" then playMonsters[obj.guid]=obj end
            end
            local kind=resourceObjectKind(obj)
            if kind~=nil and (zoneKind=="play"
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
    combatCalcUpdate(monsters)
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
    local hasUnits=false
    for guid,obj in pairs(objects) do
        local kind=resourceObjectKind(obj)
        if kind=="card" and placements[guid]=="play" then
            cards[#cards+1]=obj
            footprints[guid]=footprint(obj)
        elseif kind=="wound" and placements[guid]=="play" then
            wounds[#wounds+1]=obj
            footprints[guid]=footprint(obj)
        elseif kind=="skill" and placements[guid]=="play" then
            skills[#skills+1]=obj
            footprints[guid]=footprint(obj)
        elseif kind=="mana" then
            manaObjects[#manaObjects+1]=obj
        elseif kind=="unit" then
            -- Unit and Play Areas overlap; placement may be "play" here.
            -- The physical Unit-area snapshot still owns its wound/spent state.
            hasUnits=true
        end
    end

    -- Read the physical Unit state once per scan for highlights and Skills.
    -- A Command token already resting on a Unit from a previous turn means
    -- spent; a Unit activated by a Command move THIS turn is still active.
    local unitState=hasUnits and unitLayoutResourceState(seatPos) or nil
    local activations=gStates.unitResourceActivations or {}
    unitHighlightBlocked={}
    if unitState~=nil then
        for _,entry in ipairs(unitState.units) do
            local activation=activations[entry.guid]
            local activeThisTurn=activation~=nil and activation.seatPos==seatPos
                and unitResourceDefinitions[entry.guid]~=nil
            if not entry.unwounded or (not entry.ready and not activeThisTurn) then
                unitHighlightBlocked[entry.guid]=true
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
    if countWounds then unitState=unitLayoutResourceState(seatPos) end
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
    local manaByObject,manaBySkill,manaByCard=
        resolveManaSkillLinks(skills,manaObjects,cards,footprints,placements)
    local skillLinksByTarget,skillLinksBySkill,sidewaysSkillMana=
        resolveSkillCardLinks(skills,skillTargets,footprints,manaObjects,placements,manaByObject,unitState)
    local powered,usedMana,spellCastingPaid={}, {}, {}
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
            -- Black alone selects the stronger Spell for this estimate.
            -- Other mana payments and legal casting are left to the player.
            if color=="Black" then powered[card.guid]=true end
        else
            powered[card.guid]=true
        end
        usedMana[manaGUID]=card.guid
    end
    -- Mana physically on the Skill cannot also power the card directly.
    for _,mana in ipairs(manaObjects) do
        if placements[mana.guid]=="play" and manaByObject[mana.guid]==nil
            and sidewaysSkillMana[mana.guid]==nil then
            local color=manaColor(mana)
            if color~=nil then
                local p=mana.getPosition()
                local best,bestDistance=nil,nil
                for _,card in ipairs(cards) do
                    local f=footprints[card.guid]
                    local dx,dz=p[1]-f.x,p[3]-f.z
                    if math.abs(dx)<f.halfX and math.abs(dz)<f.halfZ
                        and cardPosture(card)=="upright" and card.is_face_down~=true
                        and (matchesCardMana(card,color)
                            or (specialPaymentByCard[card.guid]~=nil
                                and (specialPaymentByCard[card.guid].colors[color]~=nil
                                    or (color=="Gold" and gStates.dayRound==true)))) then
                        local distance=dx*dx+dz*dz
                        if bestDistance==nil or distance<bestDistance then best,bestDistance=card,distance end
                    end
                end
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
            gStates.dayRound==true)
        if wildcard or next(options)~=nil then powered[guid]=true end
    end
    local links,boostBy,boostSource,discarded,hasDiscard,linkedCardBySource,
        repeatByTarget,discardBoostBySource=
        resolveActionLinks(cards,wounds,footprints,powered,skillLinksByTarget)
    -- Extra terrain mana is an optional physical payment, separate from the
    -- mana that powers the strong action. Never reuse a claimed mana object.
    local extraTerrainManaByCard,extraTerrainManaByObject={},{}
    for _,mana in ipairs(manaObjects) do
        if placements[mana.guid]=="play" and usedMana[mana.guid]==nil
            and manaByObject[mana.guid]==nil and sidewaysSkillMana[mana.guid]==nil then
            local color=manaColor(mana)
            local best,bestDistance=nil,nil
            for _,card in ipairs(cards) do
                local data=gameCards[card.guid]
                local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
                local spec=rule~=nil and rule.extraTerrainMana or nil
                if spec~=nil and spec.color==color and extraTerrainManaByCard[card.guid]==nil
                    and (not spec.poweredOnly or powered[card.guid]==true or boostBy[card.guid]~=nil)
                    and card.is_face_down~=true and cardPosture(card)=="upright"
                    and manaInsideFootprint(mana,footprints[card.guid]) then
                    local p=mana.getPosition()
                    local f=footprints[card.guid]
                    local distance=(p[1]-f.x)^2+(p[3]-f.z)^2
                    if bestDistance==nil or distance<bestDistance then
                        best,bestDistance=card,distance
                    end
                end
            end
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
    local terrainModifiers={}
    local movementEffects={jumpTwoSpaces=false,ignoreRampagers=false}
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
            effectManaByCard[guid] or {},needPower,gStates.dayRound==true)
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
            and card.is_face_down==true
        local isStrong=powered[card.guid]==true or boostBy[card.guid]~=nil or artifactBreak
        if repeatByTarget[card.guid]~=nil then
            isStrong=repeatByTarget[card.guid].powered
        end
        local linkedChoices=linkedColorChoices(rule,linkedCardBySource[card.guid],isStrong)
        if rule~=nil and rule.effectManaChoice~=nil then
            linkedChoices=paidManaChoices(card.guid,rule,isStrong,boostBy[card.guid])
        end
        -- Enemy-targeted effects count the printed icons of the token actually
        -- placed over the card. A missing target still gives the fixed base Block.
        local enemyTarget,enemyBonus=nil,nil
        if rule~=nil and rule.enemyIconBlock==true and isStrong
            and cardPosture(card)=="upright" then
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
            if enemyTarget~=nil then
                enemyBonus=enemyPrintedIconBonus(monsterPugs[enemyTarget.guid])
            end
        end
        local choices=nil
        if discarded[card.guid]==nil or repeatByTarget[card.guid]~=nil then
            if cardPosture(card)=="sideways" then
                if cardCanPlaySideways(card) then choices=sidewaysChoices end
            elseif (cardData==nil or cardData.resourceAlwaysNeutral~=true)
                and (rule==nil or rule.requiredLink==nil or hasDiscard[card.guid]==true)
                and (cardData==nil or cardData.cardType~="Spell"
                    or spellCastingPaid[card.guid]==true) then
                -- Don't guess an unavailable effect before its payment/link is present.
                choices=linkedChoices or sideChoices(rule,isStrong)
            end
        end
        if choices~=nil and cardPosture(card)~="discard" then
            guessInitialCardChoice(card,choices,seatPos,rule,cardPosture(card)=="sideways")
        end
        local result=calculateCard(card,powered[card.guid]==true or artifactBreak,boostBy[card.guid],
            links[card.guid],discarded[card.guid]~=nil,hasDiscard[card.guid]==true,
            skillLinksByTarget[card.guid],linkedChoices,repeatByTarget[card.guid],
            discardBoostBySource[card.guid],woundCount,enemyBonus,
            spellCastingPaid[card.guid]==true)

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
                    local resources=enemyPrintedPossessAttack(monsterPugs[guid])
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
                result.links[#result.links+1]=best.guid
                result.status="purple"
            end
        end

        -- Sacrifice's four variants count physically stored crystal pairs.
        if rule~=nil and rule.crystalPairAttack~=nil and result.powered
            and result.resources~=nil and cardPosture(card)=="upright" then
            local chosen,category=currentChoice(card.guid,true,rule.poweredChoices)
            local colors=rule.crystalPairAttack[category]
            if colors~=nil and chosen~=nil then
                local pairCount=math.min(inventoryCrystalCounts[colors[1]] or 0,
                    inventoryCrystalCounts[colors[2]] or 0)
                result.resources={[category]=(chosen[category] or 0)*pairCount}
                result.complete=pairCount>0
                result.status=pairCount>0 and "green" or "blue"
            end
        end
        if rule~=nil and rule.poweredEnemyBonus~=nil and result.powered
            and result.resources~=nil and cardPosture(card)=="upright" then
            local enemyCount=0
            for _,enemy in pairs(playMonsters) do
                if enemy.is_face_down~=true then enemyCount=enemyCount+1 end
            end
            local updated={}
            for category,value in pairs(result.resources) do
                updated[category]=(totalsKeys[category] and type(value)=="number")
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
        local inventorySpec=rule~=nil and rule.inventorySetChoices or nil
        local inventorySets=0
        if inventorySpec~=nil and result.powered and result.resources~=nil
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
        -- Enemy effects follow the card's *selected* option, so changing the
        -- option re-links (or unlinks) the nearest enemy on the next scan.
        if rule~=nil and rule.enemyEffect~=nil and result.resources~=nil
            and result.powered~=nil and cardPosture(card)=="upright"
            and result.status~="yellow" and result.enemyGUID==nil then
            local _,chosenCategory=currentChoice(card.guid,result.powered,choices)
            local spec=combatEffectSpec(rule,result.powered,chosenCategory)
            if spec~=nil then
                local target=combatEffectNearestEnemy(footprints[card.guid],monsters,footprint,overlapArea)
                if target~=nil then
                    for _=1,(result.repeatCount or 1) do
                        combatEffectAdd(enemyEffects,target.guid,card.guid,spec)
                    end
                    result.enemyGUID=target.guid
                    result.links[#result.links+1]=target.guid
                    result.status="purple"
                end
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
        result.choices=choices -- Also authoritative for payment-restricted click validation.
        showChoiceButtons(card,choices,result.powered,inventorySpec,inventorySets,result.resources)
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
            and card.is_face_down~=true
            and (cardData==nil or cardData.cardType~="Spell"
                or spellCastingPaid[card.guid]==true)
            and (discarded[card.guid]==nil or repeatByTarget[card.guid]~=nil) then
            local effect=result.powered and rule.movementEffects.powered
                or (not result.powered and rule.movementEffects.normal or nil)
            if effect~=nil then
                if effect.jumpTwoSpaces==true then movementEffects.jumpTwoSpaces=true end
                if effect.ignoreRampagers==true then movementEffects.ignoreRampagers=true end
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
    -- Ambush boosts the physically linked Action's first Attack or Block,
    -- rather than generating a separate untyped Attack resource.
    local combatCategories={"attack","attackFire","attackIce","attackColdFire",
        "ranged","rangedFire","rangedIce","rangedColdFire",
        "siege","siegeFire","siegeIce","siegeColdFire",
        "block","blockFire","blockIce","blockColdFire"}
    for _,source in ipairs(cards) do
        local data=gameCards[source.guid]
        local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
        local sourceRecord=records[source.guid]
        if rule~=nil and rule.combatLink~=nil and sourceRecord~=nil
            and sourceRecord.resources~=nil and cardPosture(source)=="upright"
            and (discarded[source.guid]==nil or repeatByTarget[source.guid]~=nil) then
            local best,bestCategory,bestType,bestOverlap=nil,nil,nil,0
            for _,target in ipairs(cards) do
                local record=records[target.guid]
                local area=target.guid~=source.guid
                    and overlapArea(footprints[source.guid],footprints[target.guid]) or 0
                if area>0 and record~=nil and record.resources~=nil
                    and discarded[target.guid]==nil then
                    local category,kind=nil,nil
                    for _,key in ipairs(combatCategories) do
                        if type(record.resources[key])=="number" and record.resources[key]>0 then
                            category=key
                            kind=key:sub(1,5)=="block" and "block" or "attack"
                            break
                        end
                    end
                    if category~=nil and (area>bestOverlap
                        or (area==bestOverlap and best~=nil and target.guid<best.guid)) then
                        best,bestCategory,bestType,bestOverlap=target,category,kind,area
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
    -- An unlinked Wound is inert. Only an attached Skill or a deliberate
    -- discard payment gives it a tracker outline.
    for _,wound in ipairs(wounds) do
        local skillLink=skillLinksByTarget[wound.guid]
        if skillLink~=nil then
            local result=calculateSideways(wound,true,skillLink)
            result.kind="wound"
            showChoiceButtons(wound,sidewaysChoices,result.powered)
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
    -- Read only mana physically resting over each Unit; inventory mana does
    -- not pay costs. Familiar crystals are a persistent modifier, not a cost.
    local function unitAbilityResources(ability,counts,crystalCounts)
        if ability==nil or (not unitAbilityPaid(ability,counts)
            and not ability.baseWithoutPayment) then return nil end
        local resources={}
        for category,value in pairs(ability) do
            if totalsKeys[category] and type(value)=="number" then
                local bonus=0
                if ability.bonusColor~=nil and (crystalCounts[ability.bonusColor] or 0)>0 then
                    bonus=ability.bonus or 0
                end
                if ability.manaScale then
                    if (counts.Red or 0)>0 then bonus=bonus+2 end
                    if (counts.Blue or 0)>0 then bonus=bonus+2 end
                end
                resources[category]=value+bonus
            end
        end
        return resources
    end
    local selectedUnitAttacks={}
    local shocktroopsBoosts=0
    local attackTransforms={}
    local transformingUnits={}
    for unitGUID,activation in pairs(activations) do
        if activation.seatPos==seatPos then
            local unit=objects[unitGUID]
            local abilities=unitResourceDefinitions[unitGUID]
            if unit~=nil and abilities~=nil then
                if unitState==nil then unitState=unitLayoutResourceState(seatPos) end
                if unitState==nil then error("Unable to read Unit resource state.",2) end
                local unwounded=true
                for _,entry in ipairs(unitState.units) do
                    if entry.guid==unitGUID then unwounded=entry.unwounded break end
                end
                local counts=unitManaCounts(unit,seatPos,manaObjects)
                local decision=unitManaDecision(unit,abilities,activation,counts)
                showUnitAbilityButtons(unit,abilities,activation,unwounded,decision)
                local selected=decision.index~=nil and abilities[decision.index] or nil
                if unwounded then
                    local crystalCounts=selected~=nil and selected.bonusColor~=nil
                        and unitManaCounts(unit,seatPos,manaObjects,true) or nil
                    local resources=selected~=nil
                        and unitAbilityResources(selected,counts,crystalCounts) or nil
                    local result={guid=unitGUID,kind="unit",known=true,
                        complete=selected~=nil and unitAbilityPaid(selected,counts)
                            or abilities.multi==true and next(decision.selected or {})~=nil,
                        resources=resources,powered=false,links={}}
                    addResourceAmounts(result,totals)
                    result.status=result.contributes and "green" or "blue"
                    records[unitGUID]=result
                    current[unitGUID]=true
                    setHighlight(unit,result.status,false)
                    if selected~=nil and selected.terrainReduce and result.complete then
                        terrainModifiers[#terrainModifiers+1]=forestersTerrainModifier
                    end
                    if selected~=nil and selected.boostOtherUnits and result.complete then
                        shocktroopsBoosts=shocktroopsBoosts+1
                    end
                    if selected~=nil and selected.attackTransform~=nil and result.complete then
                        attackTransforms[selected.attackTransform]=true
                        transformingUnits[unitGUID]=selected.attackTransform
                    end
                    if result.contributes then
                        selectedUnitAttacks[#selectedUnitAttacks+1]=unitGUID
                    end
                end
            end
        end
    end
    -- Shocktroops' Ranged Attack 1 also boosts ALL other activated Units'
    -- Attacks, even if their ability was activated earlier this turn.
    if shocktroopsBoosts>0 then
        for _,unitGUID in ipairs(selectedUnitAttacks) do
            local record=records[unitGUID]
            local selected=activations[unitGUID]~=nil
                and unitResourceDefinitions[unitGUID][activations[unitGUID].choice or 1] or nil
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
            if family~=nil and unitBoost~=nil and unitBoost[family]~=nil then
                local eligible={}
                for unitGUID,activation in pairs(activations) do
                    local unit=objects[unitGUID]
                    local record=records[unitGUID]
                    if activation.seatPos==seatPos and unit~=nil and record~=nil
                        and record.complete==true then
                        local field=resourceFieldForFamily(record.resources,family)
                        if field~=nil then
                            eligible[#eligible+1]={unit=unit,field=field,
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
                    skillTargetLinked(skill,chosenUnit.unit,chosenUnit.field,
                        (choice[family] or unitBoost[family]))
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
            if best~=nil and best.field~=nil then
                local sourceField=best.field
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
                    if source.guid~=sideways.guid and data~=nil
                        and (data.cardType=="Starting" or data.cardType=="Advanced Action")
                        and cardPosture(source)=="upright" and source.is_face_down~=true
                        and (sideIsArtifact or (sidewaysData~=nil
                            and sidewaysData.color~=nil and data.color==sidewaysData.color)) then
                        local definition=cardResourceDefinitions[data.resourceKey]
                        if definition~=nil and definition.requiredLink==nil
                            and definition.woundBonus==nil and definition.partial~=true then
                            local base=definition.normalChoices~=nil
                                and chosenEffect(source.guid,false,definition.normalChoices)
                                or definition.normal
                            local srcField,srcValue,count=nil,nil,0
                            for key,value in pairs(base or {}) do
                                if totalsKeys[key] and type(value)=="number" and value>0 then
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
                        if totalsKeys[key] and type(value)=="number" and value>0 then
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
    -- Deadly Aim adds to one physically linked card's actual Attack element,
    -- never to Units or a guessed attack phase.
    for _,skill in ipairs(skills) do
        local rule=skillResourceDefinitions[skill.guid]
        if rule~=nil and rule.attackCardBoost then
            local best,bestOverlap=nil,0
            for _,card in ipairs(cards) do
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
    -- Tovak's Mana Overload: the unused marker mana on the Skill declares
    -- its colour. A *different* mana of that colour must actually power the
    -- target Deed card. An explicit overlapping target wins; if exactly one
    -- suitable powered card exists, the choice is unambiguous.
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
                        and target~=nil and target.resources~=nil then
                        local familyField=nil
                        for _,family in ipairs({"move","influence","ranged","siege","attack","block"}) do
                            local field=resourceFieldForFamily(target.resources,family)
                            if field~=nil then
                                if familyField~=nil then familyField=nil break end
                                familyField=field
                            end
                        end
                        if familyField~=nil then
                            for _,mana in ipairs(manaObjects) do
                                if usedMana[mana.guid]==card.guid and colors[manaColor(mana)]==true then
                                    candidates[#candidates+1]={card=card,field=familyField,
                                        overlap=overlapArea(skillArea,footprints[card.guid])}
                                    break
                                end
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
                skillTargetLinked(skill,chosen.card,chosen.field,4)
            end
        end
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
            showChoiceButtons(token,choices,flipped)
            addResourceAmounts(result,totals)
            records[guid]=result
            current[guid]=true
            setHighlight(token,result.status,result.powered)
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
                ---@class CardRecognitionRecord
                ---@field resources table<string, number>|nil
                ---@field links string[]
                ---@field status string
                ---@field powered boolean
                local winner,selected,bestArea=nil,nil,0
                ---@type CardRecognitionRecord|nil
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
    for unitGUID,mode in pairs(transformingUnits) do
        local affected=false
        for _,family in ipairs(attackTransformFamilies) do
            for _,field in ipairs(attackTransformFields) do
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
        local record=records[unitGUID]
        if record~=nil then
            record.contributes=affected
            record.status=affected and "green" or "blue"
            setHighlight(objects[unitGUID],record.status,false)
        end
    end

    local previous=bySeat[seatPos] or {}
    local previousScan=resourceCardScanBySeat[seatPos]
    local previousMove=previousScan~=nil and (previousScan.totals.move or 0) or 0
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
        for category in pairs(totalsKeys) do
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
    local previousTransform=previousScan~=nil and previousScan.attackTransforms or nil
    local transformChanged=previousTransform==nil
        or (previousTransform.coldFire==true)~=(attackTransforms.coldFire==true)
        or (previousTransform.siege==true)~=(attackTransforms.siege==true)
    combatEffectReport(seatPos,enemyEffects)
    bySeat[seatPos]=current
    resourceCardScanBySeat[seatPos]={cards=records,totals=totals,
        attackTransforms=attackTransforms,
        terrainModifiers=terrainModifiers,movementEffects=movementEffects,
        enemyEffects=enemyEffects,
        usesCurrentHexBlock=usesCurrentHexBlock,
        usesCurrentHexHealing=usesCurrentHexHealing,
        usesSkillLocation=usesSkillLocation}
    refreshCombatEnemyPanel(monsters)
    -- Redraw movement when ability flags change, even if total Move stays equal.
    if totalsChanged or terrainChanged or transformChanged then refreshResourceTrackerText() end
    if previousMove~=(totals.move or 0) or terrainChanged or movementChanged then
        updateMoveDisplay()
    end
    for guid in pairs(previous) do
        if current[guid]~=true then
            clearHighlight(guid)
            if choiceButtonShown[guid]~=nil and choiceButtonShown[guid]~="hidden" then
                removeChoiceButtons(getObjectFromGUID(guid))
            end
            -- Drop cached hidden state so cards are inspected on re-entry.
            choiceButtonShown[guid]=nil
            -- Keep the chosen resource, even if the object briefly leaves the
            -- zone while being dragged. The collapsed UI is rebuilt on return.
            choiceExpandedByGUID[guid]=nil
        end
    end
end

local function queueSeat(seatPos,triggerGUID)
    if not resourceCardsPanelOpen() or seatPos==nil or seatPos<1 or seatPos>4 then return end
    generation[seatPos]=(generation[seatPos] or 0)+1
    local serial=generation[seatPos]
    -- Zone entry is the trigger, but never inspect a moving card/token's position.
    safeWaitFrames("PlayerBoard.CardRecognition",function()
        if generation[seatPos]~=serial or not resourceCardsPanelOpen() then return end
        safeWaitCondition("PlayerBoard.CardRecognition",function()
            if generation[seatPos]==serial and resourceCardsPanelOpen() then renderSeat(seatPos) end
        end,function()
            if generation[seatPos]~=serial or not resourceCardsPanelOpen() then return true end
            if triggerGUID==nil then return true end
            local obj=getObjectFromGUID(triggerGUID)
            return obj==nil or (obj.held_by_color==nil and obj.resting==true and obj.isSmoothMoving()==false)
        end,8)
    end,1)
end

function resourceCardsSourceChanged()
    local current=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    if current~=nil and resourceCardsPanelOpen() then queueSeat(current.seatPos,nil) end
end

local function clearAll()
    for seat=1,4 do generation[seat]=(generation[seat] or 0)+1 end
    clearChoiceButtons()
    choiceExpandedByGUID={}
    -- Do not discard choices when closing/reopening the Resource Tracker.
    for guid in pairs(shown) do clearHighlight(guid) end
    bySeat={}
    resourceCardScanBySeat={}
    -- Manual Resource Tracker adjustments are never changed by clearing estimates.
    if gStates~=nil and gStates.resourceTracker~=nil then
        refreshResourceTrackerText()
        updateMoveDisplay()
    end
end

-- Player clicks always replace the one-time guess; opening the choice menu
-- alone leaves that selection and the Resource Tracker totals unchanged.
function resourceCardsChoiceClicked(player,value,id)
    if type(id)~="string" then return end
    local guid,setIndex,category=id:match(
        "^ResourceCardChoice_([0-9a-f]+)_set(%d+)_([%w]+)$")
    if guid==nil then
        guid,category=id:match("^ResourceCardChoice_([0-9a-f]+)_([%w]+)$")
    end
    if guid==nil then return end
    setIndex=setIndex~=nil and tonumber(setIndex) or nil
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
        mainChoices=sidewaysChoices
    elseif not sideways then
        -- Paid mana choices were filtered during the most recent physical scan.
        -- Do not rediscover the full printed menu and offer unpaid alternatives.
        mainChoices=record~=nil and record.choices or nil
    end
    local choices=mainChoices
    local inventorySpec=not sideways and powered and rule~=nil
        and rule.inventorySetChoices or nil
    local inventorySets=inventorySpec~=nil and record~=nil
        and record.inventorySetCount or 0
    if setIndex~=nil then
        if inventorySpec==nil or setIndex<1 or setIndex>inventorySets then return end
        choices=inventorySpec.choices
    end
    local valid=choiceAvailable(choices,category)
    if not valid then return end
    local rowId=setIndex~=nil and ("set"..setIndex) or "base"
    local currentlyExpanded=choiceExpandedByGUID[guid]
    if currentlyExpanded~=rowId and not (rowId=="base" and currentlyExpanded==true) then
        -- Opening a row never changes the chosen resource.
        choiceExpandedByGUID[guid]=rowId
        showChoiceButtons(card,mainChoices,powered,inventorySpec,inventorySets)
        return
    end
    local selected=selectedResourceByGUID[guid] or {}
    if setIndex~=nil then
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
    choiceExpandedByGUID[guid]=nil
    showChoiceButtons(card,mainChoices,powered,inventorySpec,inventorySets)
    queueSeat(currentSeat.seatPos,nil)
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
            removeChoiceButtons(getObjectFromGUID(unitGUID))
            choiceExpandedByGUID[unitGUID]=nil
            activations[unitGUID]=nil
            changed=true
        end
    end
    return changed
end

-- The picked-up origin is transient; only completed activations belong in
-- saved state. A token placed back on its original Unit isn't a new play.
function resourceUnitsCommandPickedUp(playerColor,obj)
    if obj==nil or not unitLayoutIsCommand(obj)
        or gStates==nil or gStates.firstStarted~=true then return end
    local current=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    if current==nil or legalPlayerCheck(playerColor,current.seatPos)~=true then return end
    local origin=unitLayoutCommandTarget(obj,current.seatPos)
    commandPickupForUnits[obj.guid]={seatPos=current.seatPos,
        turnNumber=gStates.turnNumber,origin=origin~=nil and origin.guid or nil}
end

function resourceUnitsCommandDropped(playerColor,obj)
    if obj==nil or not unitLayoutIsCommand(obj) then return end
    local pickup=commandPickupForUnits[obj.guid]
    commandPickupForUnits[obj.guid]=nil
    if pickup==nil then return end
    local guid=obj.guid
    safeWaitCondition("PlayerBoard.CardRecognition",function()
        local current=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
        if current==nil or current.seatPos~=pickup.seatPos
            or gStates.turnNumber~=pickup.turnNumber then return end
        local token=getObjectFromGUID(guid)
        local unit=token~=nil and unitLayoutCommandTarget(token,pickup.seatPos) or nil
        local targetGUID=unit~=nil and unit.guid or nil
        if resourceUnitsCancelMovedCommand(guid,pickup.seatPos,targetGUID) then
            queueSeat(pickup.seatPos,nil)
        end
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
        gStates.unitResourceActivations[unit.guid]={
            seatPos=pickup.seatPos,tokenGUID=guid,choice=choice,
            selected=abilities.multi==true and {} or nil}
        choiceExpandedByGUID[unit.guid]=nil
        showUnitAbilityButtons(unit,abilities,gStates.unitResourceActivations[unit.guid],true)
        queueSeat(pickup.seatPos,nil)
    end,function()
        local token=getObjectFromGUID(guid)
        return token==nil or (token.held_by_color==nil and token.resting==true
            and token.isSmoothMoving()==false)
    end,8)
end

function resourceUnitsChoiceClicked(player,value,id)
    if type(id)~="string" then return end
    local unitGUID,index=id:match("^ResourceCardChoice_([0-9a-f]+)_unit(%d+)$")
    index=tonumber(index)
    local activation=unitGUID~=nil and gStates.unitResourceActivations
        and gStates.unitResourceActivations[unitGUID] or nil
    local abilities=unitGUID~=nil and unitResourceDefinitions[unitGUID] or nil
    local current=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    if activation==nil or abilities==nil or current==nil or index==nil
        or abilities[index]==nil or activation.seatPos~=current.seatPos
        or legalPlayerCheck(player.color,current.seatPos)~=true then return end
    local unit=getObjectFromGUID(unitGUID)
    if unit==nil then return end
    local state=unitLayoutResourceState(current.seatPos)
    if state==nil then return end
    for _,entry in ipairs(state.units) do
        if entry.guid==unitGUID and not entry.unwounded then return end
    end
    local decision=unitManaDecision(unit,abilities,activation)
    local available=false
    for _,candidate in ipairs(decision.display) do
        if candidate==index then available=true break end
    end
    if not available then return end
    if (not decision.ambiguous or abilities.paidChoiceExpandable)
        and choiceExpandedByGUID[unitGUID]~=true and #decision.display>1 then
        -- Expanding ordinary choices does not change what was played.
        choiceExpandedByGUID[unitGUID]=true
        showUnitAbilityButtons(unit,abilities,activation,true,decision)
        return
    end
    if abilities.multi==true then
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
            local goldCount=(unitManaCounts(unit,current.seatPos).Gold or 0)
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
        activation.manaChoice=index
        activation.manaSignature=decision.signature
        if abilities.paidChoiceExpandable then choiceExpandedByGUID[unitGUID]=nil end
    else
        activation.choice=index
        activation.manaChoice=nil
        activation.manaSignature=nil
        choiceExpandedByGUID[unitGUID]=nil
    end
    showUnitAbilityButtons(unit,abilities,activation,true)
    queueSeat(current.seatPos,nil)
end

-- Clear any remaining activations at turn end without moving Command tokens.
-- A token moved off its Unit during the turn cancels immediately on its drop.
function resourceUnitsResetTurn()
    if gStates~=nil then
        for unitGUID in pairs(gStates.unitResourceActivations or {}) do
            removeChoiceButtons(getObjectFromGUID(unitGUID))
            choiceExpandedByGUID[unitGUID]=nil
        end
        gStates.unitResourceActivations={}
    end
    commandPickupForUnits={}
end

-- Unit buttons depend on this turn's activation record, not on whether
-- the Resource Tracker details panel is currently expanded.
function resourceUnitsRefreshButtons()
    if gStates==nil or next(gStates.unitResourceActivations or {})==nil then return end
    local current=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    if current==nil then return end
    local state=unitLayoutResourceState(current.seatPos)
    if state==nil then return end
    local conditionByGUID={}
    for _,entry in ipairs(state.units) do
        conditionByGUID[entry.guid]=entry.unwounded
    end
    for unitGUID,activation in pairs(gStates.unitResourceActivations) do
        if activation.seatPos==current.seatPos then
            local unit=getObjectFromGUID(unitGUID)
            if unit~=nil then
                showUnitAbilityButtons(unit,unitResourceDefinitions[unitGUID],
                    activation,conditionByGUID[unitGUID]==true)
            end
        end
    end
end

function resourceCardsPanelChanged(open)
    if open~=true then
        -- Collapsing hides choice controls, not live resources or movement
        -- effects. Unit activation controls remain independently available.
        clearChoiceButtons()
        combatCalcShutdown()
        choiceExpandedByGUID={}
        resourceUnitsRefreshButtons()
        local active=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
        if active~=nil then queueSeat(active.seatPos,nil) end
        return
    end
    -- A newly opened detail panel (also invoked on turn change) drops the
    -- previous player's outlines before scanning the current Mage Knight.
    clearAll()
    resourceUnitsRefreshButtons()
    local player=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    if player==nil then return end
    local seat=player.seatPos
    -- TTS may not expose the just-set ResourceTrackerDetail.active attribute
    -- until the next UI update. queueSeat rejects closed panels immediately,
    -- so invoking it in the same button callback could silently lose the scan.
    -- Wait only while opening, then read every physical object exactly once.
    local serial=generation[seat]
    safeWaitCondition("PlayerBoard.CardRecognition",function()
        if generation[seat]==serial and resourceCardsPanelOpen() then
            renderSeat(seat)
        end
    end,function()
        -- Closing or reopening the panel invalidates this pending request.
        return generation[seat]~=serial or resourceCardsPanelOpen()
    end,1)
end

function resourceCardsOnLoad()
    if resourceCardsPanelOpen() then
        resourceCardsPanelChanged(resourceCardsDetailsOpen())
    else
        clearAll()
        -- The Unit's activation buttons exist independently of the expanded
        -- Resource Tracker panel and must survive a mid-turn save/reload.
        resourceUnitsRefreshButtons()
    end
end

local function resourceCardsRelevantZone(ctx)
    if ctx==nil or ctx.zoneInfo==nil or ctx.obj==nil then return nil end
    local kind=ctx.zoneInfo.kind
    local objectKind=resourceObjectKind(ctx.obj)
    if kind=="play" and (objectKind~=nil or monsterPugs[ctx.objGUID]~=nil) then
        return ctx.zoneInfo.seatPos
    end
    if kind=="unit" and (objectKind=="unit" or objectKind=="mana" or objectKind=="puppet"
        or monsterPugs[ctx.objGUID]~=nil
        or unitLayoutIsCommand(ctx.obj) or unitLayoutIsWound(ctx.obj)) then
        return ctx.zoneInfo.seatPos
    end
    if kind=="crystal" and objectKind=="mana" then return ctx.zoneInfo.seatPos end
    if kind=="hand" and objectKind=="wound" then return ctx.zoneInfo.seatPos end
    return nil
end

function resourceCardsZoneEntered(ctx)
    if ctx~=nil and ctx.obj~=nil and (unitLayoutIsWound(ctx.obj)
        or manaColor(ctx.obj)~=nil) then
        resourceUnitsRefreshButtons()
    end
    local seat=resourceCardsRelevantZone(ctx)
    if seat~=nil then queueSeat(seat,ctx.objGUID) end
end

function resourceCardsZoneLeft(ctx)
    if ctx~=nil and ctx.obj~=nil and (unitLayoutIsWound(ctx.obj)
        or manaColor(ctx.obj)~=nil) then
        resourceUnitsRefreshButtons()
    end
    local seat=resourceCardsRelevantZone(ctx)
    if ctx~=nil and ctx.zoneInfo~=nil and ctx.zoneInfo.kind=="play" then
        scheduleChoiceResetAfterPlay(ctx.objGUID,ctx.zoneInfo.seatPos)
    end
    if seat~=nil then queueSeat(seat,nil) end
end

function resourceCardsObjectMoved(obj)
    if obj~=nil and (unitLayoutIsWound(obj) or manaColor(obj)~=nil)
        and gStates~=nil and next(gStates.unitResourceActivations or {})~=nil then
        local woundGUID=obj.guid
        safeWaitCondition("PlayerBoard.CardRecognition",function()
            resourceUnitsRefreshButtons()
        end,function()
            local wound=getObjectFromGUID(woundGUID)
            return wound==nil or (wound.held_by_color==nil and wound.resting==true
                and wound.isSmoothMoving()==false)
        end,8)
    end
    if not resourceCardsPanelOpen() or obj==nil then return end
    local player=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    if player==nil then return end
    local seat=player.seatPos
    local isUnitStateToken=unitLayoutIsCommand(obj) or unitLayoutIsWound(obj)
    local isMonster=monsterPugs[obj.guid]~=nil
    if resourceObjectKind(obj)==nil and not isUnitStateToken and not isMonster then
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
    for _,zoneGUID in ipairs({playerPlayAreas[seat],playerUnitAreas[seat],
        playerCrystalAreas[seat],handZones[seat]}) do
        local zone=getObjectFromGUID(zoneGUID)
        if zone~=nil then
            for _,candidate in ipairs(zone.getObjects()) do
                if candidate.guid==obj.guid then queueSeat(seat,obj.guid) return end
            end
        end
    end
    if isUnitStateToken or (isMonster and bySeat[seat]~=nil
        and bySeat[seat][obj.guid]==true) then
        -- Zone exit usually handles this already, but a token can be dragged
        -- straight out and dropped before its membership event settles.
        queueSeat(seat,nil)
    elseif bySeat[seat]~=nil and bySeat[seat][obj.guid]==true then
        scheduleChoiceResetAfterPlay(obj.guid,seat)
        queueSeat(seat,nil)
    end
end

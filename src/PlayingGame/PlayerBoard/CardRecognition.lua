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
-- Retain the chosen crystal-pair Attack after Sacrifice converts the pairs to mana.
-- Uses combatConfig.sacrificeCastPairs to avoid Lua 5.2's 200-local module limit.
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

-- Minimizing is OFF: no play-area scanning, Unit automation or tracker overlays.
-- Reopening starts a new tracking session using the physical table.
local trackerWasDisabled=false
local trackerSession=0
local trackerStartupRequest=0
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
        and (tonumber(UI.getAttribute("ResourceTracker","height")) or 0)>200
end

function resourceCardsPanelOpen()
    local current=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    return not trackerWasDisabled and resourceCardsPanelReady()
        and current~=nil and resourceCardsSeatEnabled(current.seatPos)
end

local function resourceCardsDetailsOpen()
    return resourceCardsPanelOpen()
end

-- Keep combat constants in one private table: luabundle adds four parameters
-- to each module, which also count toward Lua 5.2's 200 active-local limit.
local combatConfig={}
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
local combatCumbersomeActive=false
local combatPsychicActive=false
local combatAssignmentJoined={}
local combatAssignmentSlotSources={}
-- Effect-only buttons share the resource slots, without adding any Block/Attack.
combatConfig.effectSources={}
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
                    local cardData=gameCards[guid]
                    local sourceName=cardData~=nil and cardData.name or nil
                    if type(sourceName)=="table" then sourceName=sourceName[1] end
                    source={guid=guid,key=part~=nil and (guid.."#"..part) or guid,part=part,
                        name=tostring(sourceName or record.kind or "Resource"),
                        ranged=0,siege=0,block=0,attack=0,move=0,
                        psychicInfluence=0,psychicInfluenceCounts=false,details={},
                        resources=record.splitTargets~=nil and {} or effective,
                        swiftDouble=record.swiftDouble==true,defeatFameRep=record.defeatFameRep,
                        heroPsychicBlock=scan~=nil and scan.heroPsychicBlock==true and record.kind~="unit",
                        repeatBlocks=record.repeatBlocks,kind=record.kind,
                        conditionalFireAttack=record.conditionalFireAttack,
                        flameWave=record.flameWave,
                        possessExclude=record.possessEnemyGUID,
                        dueling=guid=="7d1c32"}
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
            local moveAmount=tonumber(record.resources.move) or 0
            if moveAmount>0 then
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
    table.sort(sources,function(a,b)
        if a.name==b.name then return a.key<b.key end
        return a.name<b.name
    end)
    return sources
end

local function combatNearestEnemyGUID(source,entries)
    local sourceObject=getObjectFromGUID(source.guid)
    if sourceObject==nil then return nil end
    local sourcePosition=sourceObject.getPosition()
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
        return tostring(a.source)<tostring(b.source)
    end)
    return ordered
end

local function combatApplyAttackReductions(attacks,effect,ownerGUID,chosenAttacks)
    for _,reduction in ipairs(combatOrderedReductions(effect)) do
        local sourceKey=reduction.id or tostring(reduction.source)
        local choice=chosenAttacks~=nil and chosenAttacks[sourceKey] or nil
        local target=choice~=nil and attacks[choice] or nil
        if target~=nil and (target.pending or (ownerGUID~=nil and target.owner~=ownerGUID)) then
            target=nil
        end
        -- Stale selections fall back to the strongest currently legal attack.
        if target==nil then
            for _,attack in ipairs(attacks) do
                if not attack.pending and (ownerGUID==nil or attack.owner==ownerGUID)
                    and (attack.value>0 or reduction.amount<0)
                    and (target==nil or attack.value>target.value) then
                    target=attack
                end
            end
        end
        if target~=nil then
            target.value=math.max(0,target.value-reduction.amount)
            if reduction.firstDamageUnit~=nil then target.firstDamageUnit=reduction.firstDamageUnit end
        end
    end
end

local function combatEnemyAttacks(entry)
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
                        if attack.key~="M" then attack.cumbersome=true end
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
            if attack.owner==entry.guid and attack.key~="M" then attack.cumbersome=true end
        end
    end
    return attacks
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
    local abilities=guid~=nil and unitResourceDefinitions~=nil
        and unitResourceDefinitions[guid] or nil
    local ability=abilities~=nil and abilities[tonumber(index)] or nil
    return ability~=nil and ability.enemyEffect~=nil
        and ability.enemyEffect.noAttackUnfortified==true
end

function resourceCardsEnemyEffectivelyUnfortified(guid,effects)
    local data,mode=combatEnemyData(guid)
    if data==nil or mode=="attackOnly" or data.attackOnly==true then return false end
    local perks=gStates~=nil and gStates.monsterPerks~=nil
        and gStates.monsterPerks[guid] or nil
    local effect=effects~=nil and effects[guid] or combatEffectOf(guid)
    local fortified=combatEnemyFortificationCount(data,perks)
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
    if sourceKey=="6a33c1" then
        return "Curse's Armour reduction cannot target an attack-only reminder."
    end
    return "Only Block/Move or attack reductions can target a reminder."
end

-- Reminders accept only Block/Move and enemy-attack effects, not attacks
-- against Armour. Unknown source keys represent effect-only targeting links.
function resourceCardsCombatTargetAcceptsSource(sourceKey,targetGUID)
    local data=combatEnemyData(targetGUID)
    if data==nil then return false end
    local seat=combatAssignmentActiveSeat()
    local scan=seat~=nil and resourceCardScanBySeat[seat] or nil
    local record=scan~=nil and scan.cards[sourceKey] or nil
    if record~=nil and record.possessEnemyGUID==targetGUID then return false end
    if resourceCardsUnitTargetRequiresUnfortified(sourceKey) then
        local seat=combatAssignmentActiveSeat()
        local scan=seat~=nil and resourceCardScanBySeat~=nil
            and resourceCardScanBySeat[seat] or nil
        return resourceCardsEnemyEffectivelyUnfortified(targetGUID,
            scan~=nil and scan.enemyEffects or nil)
    end
    if type(sourceKey)=="string" and sourceKey:match("^d01b70#fork%d+$") then
        if data.attackOnly==true then return false end
        for key,target in pairs(combatAssignmentState.targets or {}) do
            if key~=sourceKey and key:match("^d01b70#fork%d+$")
                and target==targetGUID then return false end
        end
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
-- A card being carried (for example lifted to rearrange the play area) keeps its targeting. Once it is put down
-- anywhere without being an active source (hand, discard, elsewhere) its targeting is dropped.
local function combatSourceKeepsLock(key)
    local obj=getObjectFromGUID(key:match("^[^#]+"))
    if obj==nil or next(attackAssignmentsTargetGUIDs(key))==nil then return false end
    local held=obj.held_by_color
    return (held~=nil and held~="") or obj.isSmoothMoving()
end

-- Orange arrows aim at armour; blue arrows (Block, Move) affect an enemy attack.
local function combatSourceArrowKind(source)
    if source.ranged+source.siege+source.attack>0 then return "armour" end
    return "attack"
end

-- True while the Resource Tracker details are open and an enemy stands in the play area.
local function combatCalcUpdate(monsters)
    local on=false
    local cumbersome,psychic=false,false
    if resourceCardsDetailsOpen() then
        for guid,obj in pairs(monsters or {}) do
            local data=combatEnemyData(guid,obj)
            if data~=nil and obj.is_face_down~=true then
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
    return on
end

-- A token lifted above a short scripting zone is still part of the current combat.
-- Remember only enemies already seen on the active board; never pull in arbitrary
-- held enemies from elsewhere on the table. This is runtime-only and seat-scoped.
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
    for guid,wasInPlay in pairs(combatTrackedEnemies) do
        if monsters[guid]==nil then
            local obj=getObjectFromGUID(guid)
            if obj~=nil and not obj.isDestroyed()
                and ((obj.held_by_color~=nil and obj.held_by_color~="")
                    or obj.isSmoothMoving() or obj.resting==false) then
                monsters[guid]=obj
                if wasInPlay then playMonsters[guid]=obj end
            else
                -- On a settled drop outside the combat zones, stop retaining it.
                combatTrackedEnemies[guid]=nil
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
local function combatAttackTotal(groups,data,perks)
    local normal,resisted=0,0
    for _,group in ipairs(groups) do
        for _,source in ipairs(group.sources) do
            if not (source.dueling and source.duelingEligible==false
                and group.category~="block") then
                for _,attackType in ipairs(combatConfig.attackTypes) do
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
local combatPanelAttributes={}
local function combatPanelSetAttribute(id,attribute,value)
    local key=id.."\0"..attribute
    if combatPanelAttributes[key]==value then return end
    combatPanelAttributes[key]=value
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
        if not source.forkedLightning
            or (gStates==nil or gStates.forkedLightningPhase~="attack") then
            eligible[#eligible+1]=source
        end
    end
    sources=eligible
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
local function combatDetailPhase(detail,rangeDefeated,fortification,source)
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

local combatBlockResultCache={}
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
                    if repeats<2 or value%repeats~=0 then repeats=1 end
                    for part=1,repeats do
                        items[#items+1]={source=source,key=field.key,value=value/repeats,
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
            tostring(attack.key),tostring(attack.value),tostring(attack.owner),
            tostring(attack.slot),tostring(attack.pending),tostring(attack.swift),
            tostring(attack.brutal),tostring(attack.cumbersome),tostring(attack.poison),
            tostring(attack.paralyse),tostring(attack.assassination),
            tostring(attack.firstDamageUnit)},":")
    end
    for _,item in ipairs(items) do
        parts[#parts+1]=table.concat({
            tostring(item.source.key),tostring(item.key),tostring(item.value),
            tostring(item.swiftDouble),tostring(item.part),
            tostring(item.source.heroPsychicBlock)},":")
    end
    local key=table.concat(parts,";")
    local cached=entry.guid~=nil and combatBlockResultCache[entry.guid] or nil
    if cached~=nil and cached.key==key then return table.unpack(cached.result,1,9) end
    local plan,solved,leftover=combatSolveBlocks(attacks,items,movePool)
    -- Capture the genuinely spent Block sources before spare Block display
    -- items are appended to the plan, or a free counterattack can result.
    local successfulSources,successfulOwners={},{}
    for index,attack in ipairs(attacks) do
        if plan[index]~=nil and plan[index].blocked and not attack.pending then
            for j,item in ipairs(solved) do
                if plan[index].used[j] and item.key:sub(1,5)=="block" then
                    successfulSources[item.source.guid]=true
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
        combatBlockResultCache[entry.guid]={key=key,result={
            lines,totalDamage,damageCount,allBlocked,reductions,wrongBlock,unblocked,
            successfulSources,successfulOwners}}
    end
    return lines,totalDamage,damageCount,allBlocked,reductions,wrongBlock,unblocked,
        successfulSources,successfulOwners
end

-- Damage phase. Every unblocked attack starts wholly on the Hero; the player may route it through free Units first
-- with the damage buttons. A Unit takes damage from one attack per combat and is Wounded whenever it is assigned damage,
-- unless a resistance absorbs all of it.
combatConfig.COMBAT_UNIT_RESIST_KEYS={Physical="P",Fire="F",Ice="I"}

-- Site rules are keyed by the *active fight*, not merely the player's map
-- location. A Dungeon/Tomb or burning Monastery normally forbids all Units,
-- except the Unit occupying Bonds of Loyalty's own Command slot. Maze and
-- Labyrinth allow one Unit TOTAL; Bonds adds no second companion.
local combatUnitSiteModeByLocation={
    dungeon="bonds",tomb="bonds",monastery="bonds",
    maze="one",labyrinth="one",ziggurat="none",pyramid="none"
}
local combatOneUnitBySeat={}
local function combatUnitSiteRestriction(seatPos,combatEnemies)
    local player=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    if player==nil or player.seatPos~=seatPos then return nil end
    local site=player.avatarLocation
    local mode=combatUnitSiteModeByLocation[site]
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
    local state=combatOneUnitBySeat[seatPos]
    if state~=nil and state.site==site and state.round==gStates.currentRound
        and state.turn==gStates.turnNumber then return state.guid end
    return nil
end

local function combatOneUnitSelect(seatPos,site,guid)
    combatOneUnitBySeat[seatPos]={site=site,round=gStates.currentRound,
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
    if seatPos~=nil then combatOneUnitBySeat[seatPos]=nil
    else combatOneUnitBySeat={} end
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
            units[unitState.guid]={guid=unitState.guid,name=type(data.name)=="table" and tostring(data.name[1]) or tostring(data.name),
                armour=tonumber(data.armour),level=math.max(1,tonumber(data.level) or 1),
                resist=resist,wounded=not unitState.unwounded,
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
local function combatDamageResolve(items,units,heroArmour,targetsOf,mitigation,elementMitigation,ignoreFirstHeroWound)
    local used,results={},{}
    local firstHeroWoundIgnored=false
    -- Reserve a Unit required to receive its own protected enemy's damage first.
    -- An earlier, unrelated enemy must not consume that Unit before its forced assignment.
    local reserved={}
    for _,item in ipairs(items) do
        local guid=item.firstDamageUnit
        if guid~=nil and not item.assassination and units[guid]~=nil and not units[guid].wounded then
            reserved[guid]=item.key
        end
    end
    for _,item in ipairs(items) do
        local remaining=item.damage
        local result={units={},heroWounds=0,discard=0,heroDamage=0}
        local function assign(guid,forced)
            local unit=units[guid]
            if unit==nil or unit.wounded or used[guid] or remaining<=0
                or (not forced and reserved[guid]~=nil and reserved[guid]~=item.key) then return end
            used[guid]=true
            local entry={unit=unit,wounded=true,resisted=combatUnitResists(unit,item.type),forced=forced}
            local armour=item.type=="M" and unit.level or unit.armour
            if entry.resisted then
                remaining=remaining-armour
                if remaining<=0 then entry.wounded,remaining=false,0 end
            end
            if entry.wounded then
                remaining=math.max(0,remaining-armour)
                entry.wounds=item.poison and 2 or 1
                entry.destroyed=item.paralyse==true
            end
            result.units[#result.units+1]=entry
        end
        if not item.assassination and item.firstDamageUnit~=nil then assign(item.firstDamageUnit,true) end
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

local function combatGroupAttackLine(group,sources,attackArmour)
    local meleeTotal=combatAttackTotal({
        {sources=sources,category="attack"},
        {sources=sources,category="ranged"},
        {sources=sources,category="siege"}},group.data,group.perks)
    if meleeTotal<=0 then return nil end
    local line="Attack "..tostring(meleeTotal).."/"..tostring(attackArmour)
    return meleeTotal>=attackArmour and (line.." "..combatRich("Defeated",combatConfig.COMBAT_GREEN)) or line
end

local combatDefenderMarks={}
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
    for guid,key in pairs(combatDefenderMarks) do
        if wanted[guid]==nil then combatSetDefenderDecal(guid,nil) end
    end
    for guid,key in pairs(wanted) do
        if combatDefenderMarks[guid]~=key then combatSetDefenderDecal(guid,key) end
    end
    combatDefenderMarks=wanted
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
                stripFireResist=entry.stripFireResist}
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
    local armour=tonumber(spec.armourReduce) or 0
    local armourFortified=tonumber(spec.armourReduceFortified) or armour
    local resistArmour=tonumber(spec.armourReduceByResist) or 0
    local attack=tonumber(spec.attackReduce) or 0
    local isArmour=armour>0 or armourFortified>0 or resistArmour>0
        or spec.removeFortify==true or spec.removeResist==true
        or spec.removeFireResist==true or spec.destroy==true or spec.destroyDuringAttack==true
    local isBlock=attack>0 or spec.noAttack==true or spec.noAttackUnfortified==true
        or spec.removeAbilities==true or spec.destroyIfBlocked==true
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
    if spec.removeTrait~=nil then
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
        local appliedReduction=printedFortified and
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
        local printed=printedFortified and armourFortified or armour
        amount="-"..tostring(math.max(printed,appliedReduction))
        description="Armour reduction "..amount
        if appliedReduction==0 then
            reason=applied.fireResistant and "Fire Resistance ignores this red Spell effect."
                or (applied.iceResistant and "Ice Resistance ignores this blue Spell effect.")
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
            reason="Ice Resistance ignores this blue Spell effect."
        elseif applied.fireResistant then
            reason="Fire Resistance ignores this red Spell effect."
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
            reason=applied.iceResistant and "Ice Resistance ignores this blue Spell effect."
                or (applied.fireResistant and "Fire Resistance ignores this red Spell effect.")
                or "Arcane Immunity ignores this prevention effect."
        elseif spec.noAttackUnfortified and fortified then
            reason="The target is still Fortified."
        elseif #combatEnemyPrintedAttacks(entry.data,entry.perks,entry.removeAbilities,entry.guid)==0 then
            reason="The enemy has no attack to prevent." end
    elseif spec.destroyIfBlocked==true then
        description="Destroy if this Spell successfully Blocks an attack"
        if applied.fireResistant then reason="Fire Resistance prevents this destruction."
        elseif applied.immune then reason="Arcane Immunity prevents this destruction."
        elseif entry.destroyed~=true then
            reason="This Fire Block has not been used in a successful Block."
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
combatConfig.attackPhaseSources=function(sources,wounded)
    local active={}
    for _,source in ipairs(sources or {}) do
        if wounded[source.guid]~=true then active[#active+1]=source end
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
            for _,source in ipairs(group.sources or {}) do active[source.guid]=true end
        end
    end
    local scan=seat~=nil and resourceCardScanBySeat[seat] or nil
    local records=scan~=nil and scan.cards or {}
    local activations=gStates~=nil and gStates.unitResourceActivations or {}
    for guid,activation in pairs(activations) do
        local abilities=unitResourceDefinitions~=nil and unitResourceDefinitions[guid] or nil
        local ability=abilities~=nil and abilities[activation.choice or 1] or nil
        local record=records[guid]
        if activation.seatPos==seat and active[guid] and record~=nil
            and record.complete==true and ability~=nil and ability.woundsSelf==true then
            local blocks=false
            for field,value in pairs(ability) do
                if type(value)=="number" and type(field)=="string"
                    and field:sub(1,5)=="block" then blocks=true break end
            end
            if blocks then early[guid]=true else late[guid]=true end
        end
    end
    return early,late
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
    local shownTraits,shownOffence,colUsed={},{},{range=false,block=false,attack=false}
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
            local attacks=combatEnemyAttacks(entry)
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
                    ..": "..tostring(sourceName).." (-"..tostring(selected.amount)
                    .."). Left-click: cycle target (including Auto). Right-click: next reduction source.")
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
    local allocated={}
    for _,source in ipairs(sources) do
        local moveOnly=source.ranged+source.siege+source.block+source.attack==0
            and source.psychicInfluence==0
        local influenceOnly=source.ranged+source.siege+source.block+source.attack==0
            and source.psychicInfluence>0 and source.move==0
        -- Once locked, a source stays on its enemy until it is retargeted or its arrow is removed.
        local targetGUID=combatAssignmentState.targets[source.key]
        if targetGUID==nil then
            -- Restore the saved visual assignment for every source after a reload.
            -- Move has no automatic target, while other resources use nearest-enemy only
            -- when no valid persisted assignment exists.
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
        if targetIndex==nil and not moveOnly and not influenceOnly then
            targetGUID=combatNearestEnemyGUID(source,entries)
            combatAssignmentState.targets[source.key]=targetGUID
            combatAssignmentState.explicit[source.key]=nil
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
            target.sources[#target.sources+1]=source
            for _,detail in ipairs(source.details) do
                if (detail.family~="move" or explicit)
                    and (detail.family~="influence" or source.psychicInfluenceCounts) then
                    target.details[#target.details+1]={source=source,detail=detail}
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
                if applied.spec~=nil and applied.spec.destroyIfBlocked==true then
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
                local _,_,_,_,_,_,_,successfulSources,successfulOwners=
                    combatBlockResult(entry,target~=nil and target.sources or {})
                local explodedEnemy=false
                for _,applied in ipairs(entry.effect~=nil and entry.effect.applied or {}) do
                    if applied.spec~=nil and applied.spec.destroyIfBlocked==true
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
    local defeatFame,defeatRep=0,0
    for _,group in ipairs(groups) do
        local members,blockedAll={},{}
        for _,index in ipairs(group.members) do
            local entry=entries[index]
            local target=allocated[index] or emptyTarget
            local lines,damage,count,allBlocked,reductions,wrongBlock,unblocked,successfulSources=
                combatBlockResult(entry,target.sources)
            rowBlock[index]={lines=lines,damage=damage,count=count,allBlocked=allBlocked,reductions=reductions,
                wrongBlock=wrongBlock,unblocked=unblocked,damageItems={}}
            blockedAll[entry.guid]=allBlocked
            members[#members+1]=entry
            for _,source in ipairs(target.sources) do
                if source.conditionalFireAttack~=nil
                    and successfulSources[source.guid]==true then
                    local amount=source.conditionalFireAttack
                    source.resources.attackFire=(source.resources.attackFire or 0)+amount
                    source.attack=source.attack+amount
                    local detail={text="Fire Attack "..tostring(amount).." (successful Block)",
                        amount=amount,icon="MKChoiceAttack",key="attackFire",
                        family="attack",typeKey="F"}
                    source.details[#source.details+1]=detail
                    target.details[#target.details+1]={source=source,detail=detail}
                end
                group.sources[#group.sources+1]=source
            end
        end
        group.entry,group.attackArmour=combatGroupEntry(members,blockedAll)
        group.rangeTotal,group.rangeArmour,group.rangeDefeated,group.fortification=
            combatRangeResult(combatRangeGroupEntry(members),group.sources)
        if members[1].attackOnly then group.rangeDefeated=false end
        if group.rangeDefeated then
            for _,source in ipairs(group.sources) do
                if source.dueling then source.duelingEligible=false end
            end
        end
        if rangedBeforeBlock~=nil then
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
                    if info~=nil and info.attack.owner~=nil then
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
        mitigation,elementMitigation,seatScan~=nil and seatScan.heroFirstWoundIgnored==true)

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

    -- Damage is earlier than Attack. Do not invalidate Ranged/Siege kills or
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
                if not entry.attackPhaseDestroyed then
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
        local available=combatConfig.attackPhaseSources(group.sources,woundedBeforeAttack)
        local meleeSources={}
        for _,source in ipairs(available) do
            if not source.forkedLightning
                or (gStates~=nil and gStates.forkedLightningPhase=="attack") then
                meleeSources[#meleeSources+1]=source
            end
        end
        local meleeTotal=combatAttackTotal({
            {sources=meleeSources,category="attack"},
            {sources=meleeSources,category="ranged"},
            {sources=meleeSources,category="siege"}},group.entry.data,group.entry.perks)
        group.defeated=not entries[group.members[1]].attackOnly
            and (group.rangeDefeated or (meleeTotal>0 and meleeTotal>=group.attackArmour))
        if group.destroyed then group.defeated,group.rangeDefeated=true,false end
        if group.defeated and not group.destroyed then
            local count=0
            for _,index in ipairs(group.members) do
                if not entries[index].preview then count=count+1 end
            end
            local counted={}
            for _,source in ipairs(group.sources) do
                local spec=source.defeatFameRep
                local availableInFinalPhase=woundedBeforeAttack[source.guid]~=true
                if count>0 and spec~=nil and spec.scope==nil
                    and not counted[source.guid] and (
                        (group.rangeDefeated and (source.ranged>0 or source.siege>0))
                        or (not group.rangeDefeated and availableInFinalPhase)) then
                    counted[source.guid]=true
                    local times=spec.once and 1 or count
                    defeatFame=defeatFame+(spec.fame or 0)*times
                    defeatRep=defeatRep+(spec.rep or 0)*times
                end
            end
        end
    end
    local totalHeroWounds,totalDiscardWounds=0,0
    for _,result in pairs(damageResults) do
        totalHeroWounds=totalHeroWounds+result.heroWounds
        totalDiscardWounds=totalDiscardWounds+result.discard
    end

    -- Knockout uses the unmodified Hand limit, never temporary draw bonuses.
    -- Wounds from card costs are not inferred here; players may need to add
    -- them when deciding whether to apply Knockout.
    local currentPlayer=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    local handLimit=math.max(1,tonumber(currentPlayer~=nil and currentPlayer.baseHand) or 5)
    local knockout=totalHeroWounds>=handLimit

    -- Sources that reward every defeated enemy, whichever attack defeated it.
    local seenScope={}
    for _,source in ipairs(combatAssignmentSources(damageSeat)) do
        local spec=source.defeatFameRep
        if spec~=nil and spec.scope~=nil and not seenScope[source.guid] then
            seenScope[source.guid]=true
            for _,group in ipairs(groups) do
                if group.defeated and (spec.scope=="all" or group.rangeDefeated) then
                    local count=0
                    for _,index in ipairs(group.members) do
                        if not entries[index].preview then count=count+1 end
                    end
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
            if group.defeated and not group.rangeDefeated and not group.destroyed then
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
                        if entries[index].guid==targetGUID then targetInGroup=true end
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
    local trackedGuids,defeatedGuids={},{}
    for _,group in ipairs(groups) do
        for _,index in ipairs(group.members) do
            local entry=entries[index]
            local guid=entry.guid
            if not entry.attackOnly and not entry.preview then
                trackedGuids[guid]=true
                if group.defeated or (not group.rangeDefeated
                    and entry.attackPhaseDestroyed) then defeatedGuids[guid]=true end
                for summonedGUID in pairs(entry.summonedDestroyed or {}) do
                    trackedGuids[summonedGUID]=true
                    defeatedGuids[summonedGUID]=true
                end
            end
        end
    end
    combatSetDefeatMarks(trackedGuids,defeatedGuids)
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
                    local phase=combatDetailPhase(item.detail,group.rangeDefeated,group.fortification,item.source)
                    -- Keep invalidated Attack-phase Unit icons visible so players
                    -- can see what was assigned, but make the unavailable value grey
                    -- and explain why it does not count. Earlier Ranged/Block stands.
                    local wounded=phase=="attack" and woundedBeforeAttack[item.source.guid]==true
                    lists[phase][#lists[phase]+1]={source=item.source,amount=item.detail.amount,
                        icon=item.detail.icon,text=item.detail.text,typeKey=item.detail.typeKey,
                        reduced=combatEnemyResists(group.entry.data,group.entry.perks,item.detail.typeKey),
                        wounded=wounded}
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
                insertEffect(combatConfig.effectButtonInfo(targetEntry,applied))
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
                    combatConfig.slotSelection[id]={key=item.source.key,
                        wounded=item.wounded,ineffective=item.ineffective}
                    local tooltip=item.tooltip or (item.source.name..": "..item.text
                        ..(item.wounded and " can't apply 'Wounded'" or ""))
                    combatAssignmentIconButton(id,true,item.amount,item.icon,
                        tooltip,combatAssignmentState.selected==item.source.key,
                        (item.wounded or item.ineffective) and "#292323" or (item.typeKey~=nil
                            and combatConfig.typeColors[item.typeKey][item.reduced and 2 or 1] or nil),
                        item.wounded,item.ineffective)
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
            local attacks=combatEnemyAttacks(entry)
            local attackLines={}
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
            combatPanelSetAttribute("CombatEnemyRow"..row.."Attacks","text",
                #attackLines>0 and table.concat(attackLines,"\n") or "-")
            local lines={}
            local isLast=group.members[#group.members]==index
            if group.destroyed then
                lines[1]=combatRich("Destroyed",combatConfig.COMBAT_GREEN)
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
                    local line=combatGroupAttackLine(group.entry,group.sources,group.attackArmour)
                    if line~=nil then lines[#lines+1]=line end
                end
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
    local colShown={range=colUsed.range,block=colUsed.block,attack=colUsed.attack,traits=false,offence=false}
    for row=1,combatConfig.rowCount do
        if not textBlank(shownTraits[row]) then colShown.traits=true end
        if not textBlank(shownOffence[row]) then colShown.offence=true end
    end
    -- Keep columns aligned across visible enemy rows, but size each
    -- resource phase to its fullest row (three to six icons wide).
    -- GridLayout wraps additional icons below the first line.
    local columnWidths={traits=150,offence=130}
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
        block="CombatBlockHeader",attack="CombatAssignedAttackHeader"}
    local hiddenWidth=0
    for column,shown in pairs(colShown) do
        local active=shown and "true" or "false"
        if not shown then hiddenWidth=hiddenWidth+columnWidths[column] end
        combatPanelSetAttribute(headerIDs[column],"active",active)
        for index=1,combatConfig.rowCount do
            local cell=(column=="traits" and "CombatEnemyRow"..index.."Traits")
                or (column=="offence" and "CombatEnemyRow"..index.."Offence")
                or "CombatSourceCell"..index..column
            combatPanelSetAttribute(cell,"active",active)
        end
    end

    local showTotal=totalHeroWounds>0
    combatPanelSetAttribute("CombatTotalRow","active",showTotal and "true" or "false")
    if showTotal then
        -- Align with Result; allow the separate knockout warning to extend slightly
        -- into the preceding column rather than clipping in a 180-unit text field.
        local spacer=-hiddenWidth-50
        for _,width in ipairs({120,55,150,columnWidths.range,105,130,columnWidths.block,columnWidths.attack}) do
            spacer=spacer+width
        end
        combatPanelSetAttribute("CombatTotalSpacer","preferredWidth",tostring(spacer))
        local poisonText=totalDiscardWounds>0 and " ("..tostring(totalDiscardWounds).." Poison)" or ""
        combatPanelSetAttribute("CombatTotalDamage","text",
            "Total: "..combatRich(combatWoundsText(totalHeroWounds)..poisonText,combatConfig.COMBAT_RED))
        combatPanelSetAttribute("CombatTotalDamage","font","Fonts/MKCardText")
        combatPanelSetAttribute("CombatKnockoutWarning","active",knockout and "true" or "false")
        if knockout then
            combatPanelSetAttribute("CombatKnockoutWarning","text",
                "KNOCKED OUT")
            combatPanelSetAttribute("CombatKnockoutWarning","font","Fonts/MKCardText")
        end
        local summaryHeight=knockout and 36 or 18
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
    local widthReduction=(170-columnWidths.range)+(170-columnWidths.block)+(170-columnWidths.attack)
    combatPanelSetAttribute("CombatEnemyPanel","width",
        tostring(1380-(255-combatConfig.columns.Result)-hiddenWidth-widthReduction))
    combatPanelSetAttribute("CombatEnemyPanel","color","rgb(0.24,0.2,0.15)")
    local headerWidths={Monster=120,Armour=55,DefenceTraits=150,RangeSiege=columnWidths.range,EnemyAttack=105,
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
    combatConfig.panelHeight=0
    combatTrackedSeat=nil
    combatTrackedEnemies={}
    combatCalcOn=false
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
    combatBlockResultCache={}
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
            entries[#entries+1]={guid=guid,name=tostring(data.name or "Enemy"),
                attackOnly=mode=="attackOnly",preview=mode=="preview",
                armour=tostring(armour),unmodifiedArmour=armour,baseArmour=baseArmour+armourBonus,
                elusiveArmour=baseArmour*2+armourBonus,data=data,perks=perks,
                summoned=data.monsters~=nil and combatSummonedFor(guid) or nil}
        end
    end
    local currentSeat=combatAssignmentActiveSeat()
    local seatScan=currentSeat~=nil and resourceCardScanBySeat[currentSeat] or nil
    local enemyEffects=seatScan~=nil and seatScan.enemyEffects or nil
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
            local reduction=combatEnemyFortificationCount(entry.data,entry.perks)>0
                and effect.armourReduceFortified or effect.armourReduce
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
    local sources=combatAssignmentSources(currentSeat)
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
        if activeSources[guid]~=true and not combatSourceKeepsLock(guid) then combatAssignmentState.targets[guid]=nil end
    end
    if combatAssignmentState.selected~=nil and activeSources[combatAssignmentState.selected]~=true then
        combatAssignmentState.selected=nil
    end
    local rowHeight=combatAssignmentRefreshRows(entries,sources)
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

-- Paging changes visible rows, not the underlying combat calculations.
function resourceCardsCombatPage(delta)
    combatEnemyPage=math.max(1,combatEnemyPage+delta)
    resourceCardsRefreshCombatEnemies()
end

function resourceCardsCombatCycleAttack(row,nextSource)
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
function resourceCardsCombatForgetSource(sourceGUID)
    combatAssignmentState.targets[sourceGUID]=nil
    combatAssignmentState.explicit[sourceGUID]=nil
end

-- Both numeric and effect-only Unit sources must lose their Combat Calculator
-- locks when a temporary offer Unit is returned; otherwise the next scan can
-- regenerate its arrow from a stale target.
local function combatForgetBorrowedUnitTargets(unitGUID)
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

function resourceCardsCombatAssignmentClick(id)
    local row=id:match("^CombatSourceSlot(%d+)")
    local index=row~=nil and tonumber(row) or nil
    local targetGUID=index~=nil and combatAssignmentRowTargets[index] or nil
    if targetGUID==nil then return end
    local sourceGUID=combatAssignmentSlotSources[id]
    local moved=combatAssignmentState.selected
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

-- Manual adjustments only remain for Move, Influence and Healing; combat resources come from the scan.
local function resourceCardsRawValue(tracker,totals,category,field)
    local manual=0
    if category~="attack" and category~="ranged" and category~="siege" and category~="block" then
        manual=tracker~=nil and tracker[category]~=nil and tracker[category][field] or 0
    end
    local fields=resourceTotalsKeyByField[category]
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
    local wanted=resourceTotalsKeyByField[category][field]
    local amount=0
    for _,sourceFamily in ipairs(attackTransformFamilies) do
        for _,sourceField in ipairs(attackTransformFields) do
            local sourceKey=resourceTotalsKeyByField[sourceFamily][sourceField]
            if resourceCardsTransformedKey(sourceKey,transform)==wanted then
                amount=amount+resourceCardsRawValue(tracker,totals,sourceFamily,sourceField)
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
-- Explore is not terrain; Weather also changes the special movement cost of Cities.
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
    return effect.terrains=="passable" and passableTerrain[terrain]==true
        or effect.terrains=="weather" and (passableTerrain[terrain]==true or terrain=="city")
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
    -- A traversal-setting effect retains its precedence over ordinary card
    -- discounts. Weather always applies last to the resulting legal cost.
    if setCost==nil then
        for _,effect in ipairs(effects) do
            if effect.mode=="cap" and terrainEffectApplies(effect,terrain) then
                cost=math.min(cost,effect.cost)
            elseif effect.mode=="reduce" and terrainEffectApplies(effect,terrain) then
                cost=math.max(effect.minimum or 0,cost-effect.amount)
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
    tauntReduce="-1",tauntProvoke="+2",preyNone="?",duel="D",
    blockP1="B",blockF1="BF",blockI1="BI",blockIF1="BC",
    twiceAttack="A2",twiceBlock="B2",move="M",influence="I",attack="A",block="B",
    ranged="R",siege="S",healing="H",draw="D",other="O",armour="Arm",
    guide="M",hardened="H",
    siegeFire="SF",siegeIce="SI",rangedFire="RF",rangedIce="RI",blockIce="BI",
    fire="F",ice="I",coldFire="C",boost="H+",split="I/F",negative="N",
    heal="H",combat="C",wound="W",fame="F",reputation="R",gain="G",ready="R",
    base="2",sourceUnused="3",red="R",blue="B",white="W",green="G",
    fireAttack="F",fireBlock="F",fireSiege="F",iceSiege="I",fireBlockOnly="B",fireBlockCounter="B+",
    woundPending="W?",woundTaken="W✓",
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

-- Effects without numeric combat resources need their own source keys (one per paid ability).
-- Resource-producing abilities use the Unit GUID itself, matching the Combat Calculator.
local function unitAbilityTargetKey(unitGUID,index,ability)
    return unitAbilityTargetCategory(ability)~=nil and unitGUID or (unitGUID.."#effect"..index)
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
    -- A Wound-paid spell must be confirmed by the player, never guessed.
    if rule~=nil and rule.woundConfirmation==true and not sideways then return end
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

-- A single selected icon is centred on the object. Click to expand all
-- choices; selecting one immediately collapses back to its icon.
local function showChoiceButtons(card,choices,powered,inventorySpec,inventorySets,resources)
    if card==nil then return end
    local cardData=gameCards[card.guid]
    local rule=cardData~=nil and cardResourceDefinitions[cardData.resourceKey]
        or skillResourceDefinitions[card.guid]
    local function targetResourceFor(choice,category)
        if rule~=nil and rule.blockSourceBoost~=nil then return "blockSource" end
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
                    icon=combatReductionChoiceIcon(rule,powered,choice,category),
                    iconOverlay=choice.iconOverlay,
                    stackedIcons=choice.stackedIcons,splitTargets=choice.splitTargets,
                    forkedCount=rule~=nil and rule.forkedLightning and choice.rangedColdFire or nil,
                    targetResource=targetResourceFor(choice,category),
                    iconOverlayColor=choice.iconOverlayColor,
                    iconOverlayAlignment=choice.iconOverlayAlignment,
                    iconOverlaySize=choice.iconOverlaySize,
                    tooltip=choice.tooltip}
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
        signatureParts[#signatureParts+1]=row.index..":"..selected..":"
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
    local signature=(posture=="sideways" and "S" or (powered and "P" or "N"))
        ..":"..table.concat(signatureParts,";")..":"..uiRotation..":"..buttonDepth
        ..(combatCalcOn and (combatCumbersomeActive and ":CC" or ":C") or "")
        ..(rule~=nil and rule.damageMitigation~=nil
            and (":H:"..tostring(hardenedTarget)..":"..tostring(#hardenedOptions)
                ..":"..tostring(hardenedIndex)) or "")
        ..(rule~=nil and rule.forkedLightning
            and (":FL:"..tostring(gStates~=nil and gStates.forkedLightningPhase or "range")) or "")
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
                    fontSize=77,textColor="#FFFFFF",textAlignment="MiddleCenter",
                    tooltip=entry.tooltip
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
                end
                -- Text-only alternatives (e.g. Chivalry's Reputation choice) are
                -- real buttons even when no custom icon asset exists.
                xml[#xml+1]=button
            end
            if not row.expanded and entry.targetResource~=nil then
                local resource=row.index>0 and ("set"..row.index..":"..entry.targetResource) or entry.targetResource
                local targetX=x
                if #row.entries>1 then
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
                    xml[#xml+1]={tag="Button",attributes={
                        id="AttackAssignmentSource_"..card.guid.."_"..tostring(row.index).."_"..entry.targetResource
                            ..(part and ("@"..part) or ""),
                        onClick=entry.targetResource=="blockSource"
                            and "global/resourceCardsBlockSourceLinkClicked"
                            or "global/attackAssignmentSourceClicked",
                        position=tostring(partX).." "..tostring(buttonY).." "..buttonDepth,
                        rotation=uiRotation,width=90,height=90,scale=buttonScale,
                        colors="#454D5D|#69798E|#444C63|#454D5D",textColor="#FFFFFF",textAlignment="MiddleCenter"
                    },value="",children=children}
                end
            end
        end
    end
    -- A multi-attack target needs an explicit choice of which single Attack
    -- Battle Hardened will mitigate. The cycling button is on the Skill, not
    -- the enemy, and never changes the existing calculator columns.
    if rule~=nil and rule.damageMitigation~=nil and #hardenedOptions>1 then
        local tooltip="Choose the specific enemy Attack for "
            ..(card.guid=="ae8673" and "Elemental Resistance" or "Battle Hardened")
        for i,option in ipairs(hardenedOptions) do
            tooltip=tooltip.."\n"..tostring(i)..": "..option.label
        end
        xml[#xml+1]={tag="Button",attributes={
            id="ResourceCardChoice_"..card.guid.."_hardenedCycle",
            onClick="global/resourceCardsBattleHardenedAttackClicked",
            position="-105 0 "..buttonDepth,rotation=uiRotation,
            width=110,height=90,scale="0.42 0.42",fontSize=55,
            tooltip=tooltip,colors="#454D5D|#69798E|#444C63|#454D5D",
            textColor="#FFFFFF",textAlignment="MiddleCenter"},
            value=tostring(hardenedIndex).."/"..tostring(#hardenedOptions)}
    end
    if rule~=nil and rule.forkedLightning then
        local phase=gStates~=nil and gStates.forkedLightningPhase or "range"
        xml[#xml+1]={tag="Button",attributes={
            id="ResourceCardChoice_"..card.guid.."_forkPhase",
            onClick="global/resourceCardsForkedLightningPhaseClicked",
            position="160 0 "..buttonDepth,rotation=uiRotation,
            width=140,height=90,scale="0.38 0.38",fontSize=47,
            tooltip="Forked Lightning: all bolts must resolve in the same phase. Click to toggle Ranged or Attack.",
            colors="#454D5D|#69798E|#444C63|#454D5D",
            textColor="#FFFFFF",textAlignment="MiddleCenter"},
            value=phase=="range" and "RNG" or "ATK"}
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
    local targetSpecs={}
    if combatCalcOn then
        local function addTarget(index)
            local ability=abilities[index]
            if ability==nil then return end
            local category=unitAbilityTargetCategory(ability)
            if category~=nil then
                targetSpecs[#targetSpecs+1]={index=index,category=category,
                    idCategory=category}
            elseif ability.enemyEffect~=nil or ability.targetableEnemy==true then
                targetSpecs[#targetSpecs+1]={index=index,category="effect",
                    idCategory="effect@effect"..index}
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
    local hasChoices=#available>=2 or decision.ambiguous
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
    local expanded=(decision.ambiguous and decision.index==nil and not abilities.paidChoiceExpandable)
        or (choiceExpandedByGUID[unit.guid]==true and #available>1)
    local selectedKeys={}
    for i in pairs(decision.selected or {}) do selectedKeys[#selectedKeys+1]=tostring(i) end
    table.sort(selectedKeys)
    local targetLabels={}
    if not expanded then
        for _,spec in ipairs(targetSpecs) do targetLabels[#targetLabels+1]=spec.idCategory end
    end
    local signature="Unit:"..tostring(selected)..":"..tostring(expanded)
        ..":"..table.concat(available,",")..":"..table.concat(selectedKeys,",")
        ..":targets="..table.concat(targetLabels,",")
    if choiceButtonShown[unit.guid]==signature then return end

    local xml=unit.UI.getXmlTable() or {}
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
    if #targetLabels>0 then
        local targetAsset=resourceCardsChoiceIcon("target")
        local count=#targetSpecs
        for i,spec in ipairs(targetSpecs) do
            local x=hasChoices and baseX-columnSpacing or baseX
            local y=baseY+(i-(count+1)/2)*rowSpacing
            local children={}
            if targetAsset~=nil and not blocked[targetAsset.name] then
                children={{tag="Image",attributes={image=targetAsset.name,
                    width=82,height=82,preserveAspect="true",raycastTarget="false",color="#FFFFFF"}}}
            end
            xml[#xml+1]={tag="Button",attributes={
                id="AttackAssignmentSource_"..unit.guid.."_0_"..spec.idCategory,
                onClick="global/attackAssignmentSourceClicked",
                position=tostring(x).." "..tostring(y).." -35",
                rotation="0 0 180",width=90,height=90,scale="0.22 0.22",
                colors="#454D5D|#69798E|#444C63|#454D5D",textColor="#FFFFFF",
                textAlignment="MiddleCenter"
            },value="",children=children}
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

-- Dungeon and Tomb mana is Night even in an otherwise Day round.
local function resourceCardsUsesDayMana()
    if gStates.dayRound~=true then return false end
    local player=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    local site=player~=nil and player.avatarLocation or nil
    return site~="dungeon" and site~="tomb"
end

local function matchesCardMana(card,color)
    if color==nil then return false end
    local data=gameCards[card.guid]
    if data==nil then return color=="Red" or color=="Blue" or color=="Green" or color=="White" end
    if data.cardType=="Artifact" then return false end
    if color=="Gold" then return resourceCardsUsesDayMana() end
    if color=="Black" then return not resourceCardsUsesDayMana() and data.cardType=="Spell" end
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
    -- Black mana cannot pay for any role during a Day round, including
    -- the otherwise separate strong-side payment on Mana Bolt/Thunderbolt.
    if daytime and needPower and spec.powerColor=="Black" then return possible,anyColor end
    local function hasDistinctPower(effectGUID,castGUID)
        if not needPower then return true end
        for _,payment in ipairs(payments) do
            if payment.guid~=effectGUID and payment.guid~=castGUID
                and (payment.color==spec.powerColor
                    or (daytime and spec.powerColor~="Black"
                        and payment.color=="Gold")) then return true end
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

-- Only the separate stronger-effect payment qualifies for Mana Overload.
-- A card's casting mana or a Pure Magic / Mana Bolt option payment does not.
local function effectManaPowerColors(spec,payments,daytime,selectedCategory)
    local eligible={}
    if spec==nil or selectedCategory==nil
        or (daytime and spec.powerColor=="Black") then return eligible end
    for _,effect in ipairs(payments or {}) do
        if spec.colors[effect.color]==selectedCategory
            or (daytime and effect.color=="Gold") then
            for _,power in ipairs(payments or {}) do
                if power.guid~=effect.guid
                    and (power.color==spec.powerColor
                        or (daytime and spec.powerColor~="Black"
                            and power.color=="Gold")) then
                    if spec.castColor==nil then
                        eligible[spec.powerColor]=true
                    else
                        for _,casting in ipairs(payments or {}) do
                            if casting.guid~=effect.guid and casting.guid~=power.guid
                                and (casting.color==spec.castColor
                                    or (daytime and casting.color=="Gold")) then
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
    local fameRepSide=rule~=nil and rule.fameRep~=nil and faceUp and costPaid and canApply
        and (powered and rule.fameRep.powered or not powered and rule.fameRep.normal) or nil
    -- Fame/Reputation earned only when the calculator shows this source's group defeated.
    local defeatSide=rule~=nil and rule.defeatFameRep~=nil and faceUp and costPaid and canApply
        and (powered and rule.defeatFameRep.powered or not powered and rule.defeatFameRep.normal) or nil
    if defeatSide~=nil and defeatSide.choice~=nil
        and (chosen==nil or choiceCategory(chosen)~=defeatSide.choice) then defeatSide=nil end
    return {guid=card.guid,known=known,complete=complete,powered=powered,fameRep=fameRepSide,
        conditionalFireAttack=complete and not powered and chosen~=nil
            and chosen.conditionalFireAttack or nil,
        flameWave=complete and powered and rule~=nil and rule.poweredEnemyBonus~=nil,
        defeatFameRep=defeatSide,splitTargets=chosen~=nil and chosen.splitTargets or nil,
        repeatBlocks=chosen~=nil and chosen.repeatBlocks or nil,
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

-- Time Bending's extra turn must be usable without opening the Resource Tracker.
-- Read the physical Blue casting payment and a separate Black strong-side payment;
-- the mere presence of the Spell in the play area does not establish either.
function resourceCardsTimeBendingPaid(seatPos,card)
    if card==nil or card.guid~=GUID.card.timeBending
        or card.is_face_down==true or cardPosture(card)~="upright"
        or resourceCardsUsesDayMana() then return false end
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
    if color=="Black" and resourceCardsUsesDayMana() then return false end
    if (counts[color] or 0)>0 then return true end
    -- Daytime Gold can pay any basic colour, but not Black.
    return color~="Black" and resourceCardsUsesDayMana() and (counts.Gold or 0)>0
end

local function unitManaSignature(counts)
    local parts={tostring(resourceCardsUsesDayMana())}
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
        local goldCount=resourceCardsUsesDayMana() and (counts.Gold or 0) or 0
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
    return result
end

local function sidewaysManaAvailable(color)
    return color~=nil and (color~="Gold" or resourceCardsUsesDayMana())
        and (color~="Black" or not resourceCardsUsesDayMana())
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
        if not resourceCardsUsesDayMana() then return false end
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
local oppositeMana={Red="Blue",Blue="Red",Green="White",White="Green",Gold="Black",Black="Gold"}

local function convertedManaMatchesCard(card,color)
    local data=gameCards[card.guid]
    if data==nil or card.is_face_down==true or cardPosture(card)~="upright" then return false end
    if data.cardType~="Starting" and data.cardType~="Advanced Action"
        and data.cardType~="Spell" and data.cardType~="Artifact" then return false end
    -- Shared card-mana validation also checks Black-at-night and Gold-by-day.
    if color=="Gold" and not resourceCardsUsesDayMana() then return false end
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
        if totalsKeys[category] and type(value)=="number" then
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
        or spec.destroyDuringAttack==true)
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

local function renderSeat(seatPos,quietUnitChoice)
    if not resourceCardsPanelOpen() then return end
    local active=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    if active==nil or active.seatPos~=seatPos then return end

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
    -- One observation and one held-enemy reconciliation serve both systems.
    -- Reminders/Leader previews belong to combat, but never to card enemy-count bonuses.
    combatKeepHeldEnemies(seatPos,combatMonsters,combatPlayMonsters)
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
            if manaClaimDieHeld==nil or not manaClaimDieHeld(obj.guid) then
                manaObjects[#manaObjects+1]=obj
            end
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
    unitHighlightBlocked={}
    if unitState~=nil then
        for _,entry in ipairs(unitState.units) do
            local activation=activations[entry.guid]
            local activeThisTurn=activation~=nil and activation.seatPos==seatPos
                and unitResourceDefinitions[entry.guid]~=nil
            if not entry.unwounded or (not entry.ready and not activeThisTurn)
                or not combatUnitSitePermits(unitSiteMode,
                    unitState.bondsUnitGUID,chosenSiteUnit,entry.guid,false) then
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
        if color=="Black" and resourceCardsUsesDayMana() then return end
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
                                    or (color=="Gold" and resourceCardsUsesDayMana())))) then
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
            resourceCardsUsesDayMana())
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
    local ignoreSiteFortifications=false
    local terrainModifiers=resourceCardsWeatherTerrainEffects(seatPos)
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
            effectManaByCard[guid] or {},needPower,resourceCardsUsesDayMana())
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
        -- Enemy debuffs can have a separate lock from printed Attack resources.
        if rule~=nil and rule.enemyEffect~=nil and result.resources~=nil
            and result.powered~=nil and cardPosture(card)=="upright"
            and result.status~="yellow" and result.enemyGUID==nil then
            local _,category=currentChoice(card.guid,result.powered,choices)
            local spec=combatEffectSpec(rule,result.powered,category)
            if spec~=nil then
                local key=rule.separateEffectTarget and not result.powered
                    and (card.guid.."#effect") or card.guid
                if spec.multiTargetMove then
                    -- Right-click target to add further enemies; cost is settled
                    -- after all Move-producing cards/Units/Skills have been read.
                    result.enemyEffectTargetKeys={key}
                    local targets=attackAssignmentsTargetGUIDs(key)
                    local primary=combatEffectChosenEnemy(key,footprints[card.guid],
                        monsters,combatEffectTargetEligible(spec))
                    if next(targets)==nil and primary~=nil then targets[primary.guid]=true end
                    local ordered={}
                    for guid in pairs(targets) do
                        if monsters[guid]~=nil and monsters[guid].is_face_down~=true then
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
                        for _=1,(result.repeatCount or 1) do
                            if spec.all then
                                for guid,monster in pairs(monsters) do
                                    if monster.is_face_down~=true then
                                        combatEffectAdd(enemyEffects,guid,card.guid,spec,key)
                                    end
                                end
                            else
                                combatEffectAdd(enemyEffects,target.guid,card.guid,spec,key)
                                if spec.othersArmourReduce~=nil then
                                    for guid,monster in pairs(monsters) do
                                        if guid~=target.guid and monster.is_face_down~=true then
                                            combatEffectAdd(enemyEffects,guid,card.guid,
                                                {armourReduce=spec.othersArmourReduce,all=true,fireSpell=spec.fireSpell})
                                        end
                                    end
                                end
                            end
                        end
                        result.enemyGUID=target.guid
                        result.links[#result.links+1]=target.guid
                        result.status="purple"
                        if not spec.all then
                            result.enemyEffectTargetKeys={key}
                            result.enemyEffectTargetGUIDs={[key]=target.guid}
                        end
                    end
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
        -- Demolish removes site fortification independent of enemy Fire Resistance.
        if rule~=nil and rule.ignoreSiteFortification==true
            and result.complete and not result.powered and result.resources~=nil
            and cardPosture(card)=="upright" and card.is_face_down~=true then
            ignoreSiteFortifications=true
        end
        -- Conditional combat effects apply only on a paid, upright, actually
        -- played side, never when the card is merely in the zone for display.
        if rule~=nil and result.complete and result.resources~=nil
            and cardPosture(card)=="upright" and card.is_face_down~=true then
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
    local howlOwner=gStates~=nil and gStates.doingTheRounds
        and gStates.doingTheRounds["a92d73"] or nil
    local howlPenalty=howlOwner~=nil and howlOwner~=gStates.turnNumber
        and (gStates.soloCoop==nil or gStates.soloCoop["a92d73"]~=true)
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
                if activation.callOffer and unitSiteMode=="one"
                    and chosenSiteUnit==nil then
                    chosenSiteUnit=unitGUID
                    combatOneUnitSelect(seatPos,unitSite,unitGUID)
                end
                local sitePermits=combatUnitSitePermits(unitSiteMode,
                    unitState.bondsUnitGUID,chosenSiteUnit,unitGUID,false)
                if sitePermits then
                    showUnitAbilityButtons(unit,abilities,activation,unwounded,decision)
                else
                    removeChoiceButtons(unit)
                end
                local selected=decision.index~=nil and abilities[decision.index] or nil
                if unwounded and sitePermits then
                    local crystalCounts=selected~=nil and selected.bonusColor~=nil
                        and unitManaCounts(unit,seatPos,manaObjects,true) or nil
                    local resources=selected~=nil
                        and unitAbilityResources(selected,counts,crystalCounts) or nil
                    local result={guid=unitGUID,kind="unit",known=true,
                        complete=selected~=nil and unitAbilityPaid(selected,counts)
                            or abilities.multi==true and next(decision.selected or {})~=nil,
                        resources=resources,powered=false,links={},
                        swiftDouble=selected~=nil and selected.countsTwiceVsSwift==true or nil,
                        fameRep=selected~=nil and selected.fameRep or nil}
                    result.fameRep=result.complete and result.fameRep or nil
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
                    if selected~=nil and selected.grantUnitResistances and result.complete then
                        allUnitResistances=true
                    end
                    if selected~=nil and selected.attackTransform~=nil and result.complete then
                        attackTransforms[selected.attackTransform]=true
                        transformingUnits[unitGUID]=selected.attackTransform
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
                                local sourceKey=unitAbilityTargetKey(unitGUID,index,ability)
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
                                effectManaByCard[card.guid],resourceCardsUsesDayMana(),selected)
                        end
                        local matching=false
                        for color in pairs(colors) do
                            if powerColors[color]==true
                                or (powerColors.Gold==true and resourceCardsUsesDayMana()
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
                and resourceCardsEnemyEffectivelyUnfortified(guid,enemyEffects) then
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
        for _,guid in ipairs(pending.targets) do
            local enemy=monsters[guid]
            if enemy~=nil and enemy.is_face_down~=true then
                local data=monsterPugs[guid]
                local perks=gStates~=nil and gStates.monsterPerks~=nil
                    and gStates.monsterPerks[guid] or nil
                local immune=(data~=nil and data.arcaneImmunity==true)
                    or (perks~=nil and perks.arcaneImmunity==true)
                local cost=count
                local affordable=cost<=(tonumber(totals.move) or 0)-spent
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
                if record.resources~=nil and (tonumber(record.resources.move) or 0)>0 then
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
    combatEffectReport(seatPos,enemyEffects,quietUnitChoice)
    local fameTotal,repTotal=0,0
    for _,record in pairs(records) do
        if record.fameRep~=nil then
            fameTotal=fameTotal+(record.fameRep.fame or 0)
            repTotal=repTotal+(record.fameRep.rep or 0)
        end
    end
    local scanPlayer=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    local fameRepBase={fame=fameTotal,rep=repTotal}
    bySeat[seatPos]=current
    resourceCardScanBySeat[seatPos]={cards=records,totals=totals,
        attackTransforms=attackTransforms,
        terrainModifiers=terrainModifiers,movementEffects=movementEffects,
        enemyEffects=enemyEffects,fameRepBase=fameRepBase,
        ignoreSiteFortifications=ignoreSiteFortifications,
        unitState=unitState,preventUnitDamage=preventUnitDamage,
        allUnitResistances=allUnitResistances,heroFirstWoundIgnored=heroFirstWoundIgnored,
        heroPsychicBlock=heroPsychicBlock,
        usesCurrentHexBlock=usesCurrentHexBlock,
        usesCurrentHexHealing=usesCurrentHexHealing,
        usesSkillLocation=usesSkillLocation}
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
    if totalsChanged or terrainChanged or transformChanged
        or reputationBefore~=reputationAfter then refreshResourceTrackerText() end
    if previousMove~=(totals.move or 0) or terrainChanged or movementChanged then
        updateMoveDisplay()
    end
    for guid in pairs(previous) do
        if current[guid]~=true then
            combatConfig.sacrificeCastPairs[guid]=nil
            clearHighlight(guid)
            if choiceButtonShown[guid]~=nil and choiceButtonShown[guid]~="hidden" then
                removeChoiceButtons(getObjectFromGUID(guid))
            end
            -- Drop cached hidden state so cards are inspected on re-entry.
            choiceButtonShown[guid]=nil
            -- Keep the chosen resource, even if the object briefly leaves the
            -- zone while being dragged. The collapsed UI is rebuilt on return.
            choiceExpandedByGUID[guid]=nil
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
    -- Closing the tracker removes its pending Fame/Reputation until the next scan restores it.
    if turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber]~=nil then
        resourceFameRepApply(gStates.turnNumber,0,0)
    end
    -- Closing must not invoke tracker calculations or redraw its overlays.
    if resourceCardsPanelOpen() and gStates~=nil and gStates.resourceTracker~=nil then
        refreshResourceTrackerText()
        updateMoveDisplay()
    end
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

-- Player clicks always replace the one-time guess; opening the choice menu
-- alone leaves that selection and the Resource Tracker totals unchanged.
function resourceCardsChoiceClicked(player,value,id)
    if not resourceCardsPanelOpen() or type(id)~="string"
        or not resourceCardsPlayerCanEdit(player~=nil and player.color or nil) then return end
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
    if not resourceCardsPanelOpen() or obj==nil or not unitLayoutIsCommand(obj) then return end
    local current=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    if current==nil or legalPlayerCheck(playerColor,current.seatPos)~=true then return end
    local origin=unitLayoutCommandTarget(obj,current.seatPos)
    commandPickupForUnits[obj.guid]={seatPos=current.seatPos,
        turnNumber=gStates.turnNumber,origin=origin~=nil and origin.guid or nil}
end

function resourceUnitsCommandDropped(playerColor,obj)
    if not resourceCardsPanelOpen() or obj==nil or not unitLayoutIsCommand(obj) then return end
    local pickup=commandPickupForUnits[obj.guid]
    commandPickupForUnits[obj.guid]=nil
    if pickup==nil or not resourceCardsPanelOpen() then return end
    local guid=obj.guid
    local serial=trackerSession
    safeWaitCondition("PlayerBoard.CardRecognition",function()
        if not resourceCardsPanelOpen() or trackerSession~=serial then return end
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
        resourceCardsCombatSelectOneUnit(unit.guid)
        choiceExpandedByGUID[unit.guid]=nil
        showUnitAbilityButtons(unit,abilities,gStates.unitResourceActivations[unit.guid],true)
        queueSeat(pickup.seatPos,nil)
    end,function()
        if not resourceCardsPanelOpen() or trackerSession~=serial then return true end
        local token=getObjectFromGUID(guid)
        return token==nil or (token.held_by_color==nil and token.resting==true
            and token.isSmoothMoving()==false)
    end,8)
end

-- A Unit's choice can switch its targeting key (e.g. Shocktroops
-- Ranged 1 -> Armour -1). Retire obsolete arrow keys and calculator locks
-- immediately, keeping explicitly targeted effects whose keys stay active.
-- The next scan then auto-targets newly selected effects just like attacks.
function resourceUnitsReconcileChoiceTargets(unit,abilities,activation)
    local allowed={}
    local decision=unitManaDecision(unit,abilities,activation)
    local function allow(index)
        local ability=abilities[index]
        if ability~=nil and (unitAbilityTargetCategory(ability)~=nil
            or ability.enemyEffect~=nil or ability.targetableEnemy==true) then
            allowed[unitAbilityTargetKey(unit.guid,index,ability)]=true
        end
    end
    if abilities.multi==true then
        for index in pairs(decision.selected or {}) do allow(index) end
    elseif decision.index~=nil then
        allow(decision.index)
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

function resourceUnitsChoiceClicked(player,value,id)
    if not resourceCardsPanelOpen() or type(id)~="string"
        or not resourceCardsPlayerCanEdit(player~=nil and player.color or nil) then return end
    local unitGUID,index=id:match("^ResourceCardChoice_([0-9a-f]+)_unit(%d+)$")
    index=tonumber(index)
    local activation=unitGUID~=nil and gStates.unitResourceActivations
        and gStates.unitResourceActivations[unitGUID] or nil
    local abilities=unitGUID~=nil and unitResourceDefinitions[unitGUID] or nil
    local current=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
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
    local decision=unitManaDecision(unit,abilities,activation)
    local available=false
    for _,candidate in ipairs(decision.display) do
        if candidate==index then available=true break end
    end
    if not available then return end
    if (not decision.ambiguous or abilities.paidChoiceExpandable or decision.index~=nil)
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
        -- Once a payable alternative is selected, collapse to its icon and
        -- restore the target button, regardless of the Unit's display style.
        choiceExpandedByGUID[unitGUID]=nil
    else
        activation.choice=index
        activation.manaChoice=nil
        activation.manaSignature=nil
        activation.lastPaidIndex=nil
        choiceExpandedByGUID[unitGUID]=nil
    end
    resourceUnitsReconcileChoiceTargets(unit,abilities,activation)
    showUnitAbilityButtons(unit,abilities,activation,true)
    -- A Unit choice still recalculates immediately, but its enemy-effect
    -- notification is silent. Other card/skill updates retain their notices.
    renderSeat(current.seatPos,true)
end

-- Release a temporary offered Unit without touching Command activations.
function resourceUnitsBorrowedUnitEnded(guid)
    local activation=gStates~=nil and gStates.unitResourceActivations
        and gStates.unitResourceActivations[guid] or nil
    if activation~=nil and activation.callOffer==true then
        gStates.unitResourceActivations[guid]=nil
    end
    removeChoiceButtons(getObjectFromGUID(guid))
    choiceButtonShown[guid]=nil
    choiceExpandedByGUID[guid]=nil
    combatForgetBorrowedUnitTargets(guid)
    if attackAssignmentsClearForObject~=nil then attackAssignmentsClearForObject(guid) end
    if attackAssignmentsPruneUnitChoiceSources~=nil then
        attackAssignmentsPruneUnitChoiceSources(guid,{})
    end
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
        gStates.unitResourceActivations={}
    end
    commandPickupForUnits={}
end

-- Unit buttons are part of the tracker and must remain absent while it is off.
function resourceUnitsRefreshButtons()
    if not resourceCardsPanelOpen() or next(gStates.unitResourceActivations or {})==nil then return end
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
        if unit~=nil and abilities~=nil and unwounded[unit.guid] and activations[unit.guid]==nil then
            local scores=trackerChoiceScores(unit.guid,seat)
            local choice,bestScore=1,-math.huge
            for i,ability in ipairs(abilities) do
                if ability.manaCost==nil then
                    local score=scores[ability.key] or 0
                    if score>bestScore then choice,bestScore=i,score end
                end
            end
            activations[unit.guid]={seatPos=seat,tokenGUID=token.guid,choice=choice,
                selected=abilities.multi==true and {} or nil}
        end
    end
    gStates.unitResourceActivations=activations
end

function resourceCardsPanelChanged(open)
    local current=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
    if open==true and (current==nil or not resourceCardsSeatEnabled(current.seatPos)) then return end
    -- A newly shown panel may need a frame before TTS reports its attributes.
    -- That temporary state is not a player-requested OFF transition.
    if open==true and not resourceCardsPanelReady() then return end
    trackerStartupRequest=trackerStartupRequest+1
    if open~=true then
        trackerWasDisabled=true
        trackerSession=trackerSession+1
        -- Turn the tracker completely off: stop callbacks and remove its visuals.
        combatCalcShutdown()
        clearAll()
        resourceUnitsResetTurn()
        selectedResourceByGUID={}
        for guid in pairs(choiceResetGenerationByGUID) do
            choiceResetGenerationByGUID[guid]=choiceResetGenerationByGUID[guid]+1
        end
        crystalHighlightCleared={}
        unitHighlightBlocked={}
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
        return
    end
    -- Expanding after an OFF period rebuilds from scratch, not cached choices.
    local restart=trackerWasDisabled
    trackerWasDisabled=false
    if restart then refreshResourceTrackerReputation() end
    clearAll()
    if invalidateResourceTrackerDisplayCache~=nil then invalidateResourceTrackerDisplayCache() end
    if restart then resourceUnitsRebuildFromTable() end
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

-- Clear the outgoing seat before changing turnNumber so rewards, overlays,
-- damage previews and locks cannot leak into the next player's combat.
function resourceCardsBeforeTurnHandoff(nextSeat)
    if gStates==nil or gStates.firstStarted~=true then return end
    local current=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    if current==nil or current.seatPos==nextSeat then return end
    resourceCardsPanelChanged(false)
end

-- The Global UI is shared, but its expanded/collapsed preference belongs to a seat.
function resourceCardsAfterTurnHandoff(previousSeat)
    if gStates==nil or gStates.firstStarted~=true then return end
    local current=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    if current==nil or current.seatPos==previousSeat then return end
    local enabled=resourceCardsSeatEnabled(current.seatPos)
    UI.setAttribute("CombatCalculatorHelp","active","false")
    UI.setAttribute("ResourceTracker","height",enabled and "245" or "35")
    UI.setAttribute("ResourceTrackerDetail","height","210")
    UI.setAttribute("ResourceTrackerDetail","active",enabled and "true" or "false")
    if enabled then resourceCardsOnLoad() end
end

-- Shared by saved-game load, first-game setup and re-expanding the panel.
-- Wait for the actual UI state rather than treating startup's collapsed XML
-- defaults as a player pressing OFF. Explicit minimization cancels this wait.
function resourceCardsOnLoad()
    if gStates==nil or gStates.firstStarted~=true then return end
    local current=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    if current~=nil and not resourceCardsSeatEnabled(current.seatPos) then
        UI.setAttribute("ResourceTracker","height","35")
        UI.setAttribute("ResourceTrackerDetail","active","false")
        resourceCardsPanelChanged(false)
        return
    end
    trackerStartupRequest=trackerStartupRequest+1
    local request=trackerStartupRequest
    safeWaitCondition("PlayerBoard.CardRecognition",function()
        if trackerStartupRequest==request and resourceCardsPanelReady() then
            resourceCardsPanelChanged(true)
        end
    end,function()
        return trackerStartupRequest~=request or resourceCardsPanelReady()
    end,5,function()
        -- A genuinely collapsed saved panel stays OFF; it must never
        -- trigger a new scan until the player explicitly expands it.
        if trackerStartupRequest==request and not resourceCardsPanelReady() then
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
    local objectKind=resourceObjectKind(ctx.obj)
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

function resourceCardsZoneEntered(ctx)
    if not resourceCardsPanelOpen() or ctx==nil or ctx.zoneInfo==nil then return end
    -- Filter irrelevant zones and other players before touching the Unit layout.
    local seat=resourceCardsRelevantZone(ctx)
    if seat==nil then return end
    if ctx.obj~=nil and (ctx.zoneInfo.kind=="unit" or ctx.zoneInfo.kind=="play"
        or ctx.zoneInfo.kind=="crystal")
        and (unitLayoutIsWound(ctx.obj) or manaColor(ctx.obj)~=nil) then
        resourceUnitsRefreshButtons()
    end
    queueSeat(seat,ctx.objGUID)
end

function resourceCardsZoneLeft(ctx)
    if not resourceCardsPanelOpen() or ctx==nil or ctx.zoneInfo==nil then return end
    local seat=resourceCardsRelevantZone(ctx)
    if ctx.zoneInfo.kind=="play" then
        scheduleChoiceResetAfterPlay(ctx.objGUID,ctx.zoneInfo.seatPos)
    end
    if seat==nil then return end
    if ctx.obj~=nil and (ctx.zoneInfo.kind=="unit" or ctx.zoneInfo.kind=="play"
        or ctx.zoneInfo.kind=="crystal")
        and (unitLayoutIsWound(ctx.obj) or manaColor(ctx.obj)~=nil) then
        resourceUnitsRefreshButtons()
    end
    queueSeat(seat,nil)
end

function resourceCardsObjectMoved(obj)
    if not resourceCardsPanelOpen() then return end
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
    local isMonster=combatEnemyData(obj.guid,obj)~=nil
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
    if (isMonster and combatTrackedSeat==seat and combatTrackedEnemies[obj.guid]~=nil)
        or isUnitStateToken or (isMonster and bySeat[seat]~=nil
        and bySeat[seat][obj.guid]==true) then
        -- On a drop outside the zones, wait for the token to settle before
        -- checking membership. Otherwise smooth movement can retain a ghost
        -- indefinitely if no further zone event fires.
        queueSeat(seat,isMonster and obj.guid or nil)
    elseif bySeat[seat]~=nil and bySeat[seat][obj.guid]==true then
        scheduleChoiceResetAfterPlay(obj.guid,seat)
        queueSeat(seat,nil)
    end
end

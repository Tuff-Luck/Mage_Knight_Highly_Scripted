-- The physical play area supplies estimated resources to the Resource Tracker.
-- Runtime-only observations never overwrite the saved manual +/- adjustments.
resourceCardScanBySeat={}
local generation={}
local shown={}
local bySeat={}
-- Player choices are transient, never written into gStates or save JSON.
local selectedResourceByGUID={}
-- Display state is separate from player selections. Picks/drops may clear the
-- buttons, but the chosen resource stays until the script reloads.
local choiceExpandedByGUID={}
local choiceButtonShown={}
local palette={
    green={{0.10,0.55,0.14},{0.35,1.00,0.38}},
    yellow={{0.62,0.48,0.08},{1.00,0.94,0.19}},
    red={{0.59,0.10,0.12},{1.00,0.27,0.25}},
    purple={{0.47,0.19,0.62},{0.92,0.43,1.00}}
}
-- Distinguish elemental and physical damage. Otherwise a Ranged Fire Attack
-- would be incorrectly added to the Physical Ranged field.
local totalsKeys={move=true,ranged=true,siege=true,attack=true,block=true,influence=true,healing=true,
    rangedFire=true,rangedIce=true,rangedColdFire=true,
    siegeFire=true,siegeIce=true,siegeColdFire=true,
    attackFire=true,attackIce=true,attackColdFire=true,
    blockFire=true,blockIce=true,blockColdFire=true}

function resourceCardsPanelOpen()
    return gStates~=nil and gStates.firstStarted==true
        and UI.getAttribute("ResourceTracker","active")~="false"
        and UI.getAttribute("ResourceTrackerDetail","active")=="true"
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
    ranged={physical="ranged",fire="rangedFire",ice="rangedIce",iceFire="rangedColdFire"},
    siege={physical="siege",fire="siegeFire",ice="siegeIce",iceFire="siegeColdFire"},
    attack={physical="attack",fire="attackFire",ice="attackIce",iceFire="attackColdFire"},
    block={physical="block",fire="blockFire",ice="blockIce",iceFire="blockColdFire"},
    influence={generated="influence"},
    healing={healing="healing"}
}

function resourceCardsEffectiveValue(category,field)
    local tracker=gStates~=nil and gStates.resourceTracker or nil
    local manual=tracker~=nil and tracker[category]~=nil and tracker[category][field] or 0
    local totals=resourceCardsCurrentTotals()
    local fields=resourceTotalsKeyByField[category]
    local totalKey=fields~=nil and fields[field] or nil
    local estimated=totals~=nil and totalKey~=nil and (totals[totalKey] or 0) or 0
    return manual+estimated
end

function resourceCardsEffectiveMove()
    return math.max(0,resourceCardsEffectiveValue("move","move"))
end

local function clearHighlight(guid)
    if shown[guid]==nil then return end
    local obj=getObjectFromGUID(guid)
    if obj~=nil then obj.highlightOff() end
    shown[guid]=nil
end

local function setHighlight(obj,kind,powered)
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

-- A card lying at any angle through 70 degrees can be physically overlapped
-- as Improvisation's discard payment; 90 degrees means something else.
local function canPayDiscard(card)
    return card.is_face_down~=true and cardRotationOffset(card)<=70
end

-- Only cards that may be played from hand can generate a sideways +1.
-- In particular, recruited Units and unidentified cards are not candidates.
local function cardCanPlaySideways(card)
    local data=gameCards[card.guid]
    return card.type=="Card" and card.is_face_down~=true and data~=nil
        and (data.cardType=="Starting" or data.cardType=="Advanced Action"
            or data.cardType=="Spell" or data.cardType=="Artifact")
end

local sidewaysChoices={{move=1},{influence=1},{attack=1},{block=1}}

local choiceLetters={move="M",influence="I",attack="A",block="B",
    ranged="R",siege="S",healing="H",draw="D",other="O"}

local function sideChoices(rule,powered)
    if rule==nil then return nil end
    -- Do not use 'powered and poweredChoices or normalChoices': Lua falls back
    -- to normal choices when poweredChoices is nil, overriding a fixed powered
    -- effect (e.g. Rage's Attack 4) with its unpowered Attack/Block 2 options.
    if powered then return rule.poweredChoices end
    return rule.normalChoices
end

local function choiceCategory(choice)
    for category in pairs(choice) do return category end
    return nil
end

-- The printed normal and powered effects share one choice for each physical
-- card. The sideways +1 action also shares it when the resource type matches,
-- but retains a separate choice when the printed effect is incompatible
-- (e.g. Tranquility's Heal/Draw versus a sideways Move/Attack).
local function choiceAvailable(choices,category)
    if choices==nil or category==nil then return false end
    for _,effect in ipairs(choices) do
        if effect[category]~=nil then return true end
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
        local preferred=stored.effect
        if sideways and not choiceAvailable(choices,preferred) then
            preferred=stored.sideways
        end
        if choiceAvailable(choices,preferred) then
            for _,effect in ipairs(choices) do
                if effect[preferred]~=nil then return effect,preferred end
            end
        end
    end
    local first=choices[1]
    return first,choiceCategory(first)
end

local function chosenEffect(guid,powered,choices,sideways)
    return currentChoice(guid,powered,choices,sideways)
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
            and attr.id:sub(1,19)=="ResourceCardChoice_" then
            table.remove(xml,i)
            changed=true
        end
    end
    if changed then card.UI.setXmlTable(#xml>0 and xml or {{}}) end
    choiceButtonShown[card.guid]=nil
end

-- A single selected letter sits above the title. Click to show the whole
-- choice row; choosing any option immediately collapses back to one letter.
local function showChoiceButtons(card,choices,powered)
    if card==nil then return end
    local posture=cardPosture(card)
    if choices==nil or #choices<2 or card.is_face_down==true or posture=="discard"
        or (posture=="sideways" and not cardCanPlaySideways(card)) then
        -- Once per card, inspect object XML even when our runtime cache is
        -- empty: controls created before a script reload can still be present.
        -- A 'hidden' marker avoids re-reading XML during every later scan.
        if choiceButtonShown[card.guid]~="hidden" then
            removeChoiceButtons(card)
            choiceButtonShown[card.guid]="hidden"
        end
        choiceExpandedByGUID[card.guid]=nil
        return
    end
    local _,selected=currentChoice(card.guid,powered,choices,posture=="sideways")
    local categories,seen={},{}
    for _,choice in ipairs(choices) do
        local category=choiceCategory(choice)
        if category~=nil and choiceLetters[category]~=nil and not seen[category] then
            seen[category]=true
            categories[#categories+1]=category
        end
    end
    if #categories<2 or selected==nil then
        if choiceButtonShown[card.guid]~="hidden" then
            removeChoiceButtons(card)
            choiceButtonShown[card.guid]="hidden"
        end
        choiceExpandedByGUID[card.guid]=nil
        return
    end
    local expanded=choiceExpandedByGUID[card.guid]==true
    local visible=expanded and categories or {selected}
    -- Keep each letter upright when a card is played sideways at 90/270 Y.
    -- Positions remain card-local, so expanded choices still form a vertical
    -- column on the table. Snap to quarter-turns to avoid UI churn from wobble.
    local buttonRotation=180
    if posture=="sideways" then
        buttonRotation=card.getRotation()[2]%360<180 and 270 or 90
    end
    local signature=(posture=="sideways" and "S" or (powered and "P" or "N"))
        ..":"..selected..":"..(expanded and "open" or "closed")
        ..":"..table.concat(categories,",")..":"..buttonRotation
    if choiceButtonShown[card.guid]==signature then return end
    local xml=card.UI.getXmlTable() or {}
    for i=#xml,1,-1 do
        local attr=xml[i].attributes
        if attr~=nil and type(attr.id)=="string"
            and attr.id:sub(1,19)=="ResourceCardChoice_" then table.remove(xml,i) end
    end
    for i,category in ipairs(visible) do
        local x=((#visible+1)/2-i)*44
        local active=category==selected
        xml[#xml+1]={tag="Button",attributes={
            id="ResourceCardChoice_"..card.guid.."_"..category,
            onClick="global/resourceCardsChoiceClicked",
            position=tostring(x).." -12 -35",rotation="0 0 "..buttonRotation,
            width=90,height=90,scale="0.25 0.25",
            colors=active and "#387D30|#4CA940|#387D30|#387D30"
                or "#454D5D|#69798E|#444C63|#454D5D",
            fontSize=77,textColor="#FFFFFF",textAlignment="MiddleCenter"
        },value=choiceLetters[category]}
    end
    card.UI.setXmlTable(xml)
    choiceButtonShown[card.guid]=signature
end

local function clearChoiceButtons()
    for guid,signature in pairs(choiceButtonShown) do
        if signature~="hidden" then removeChoiceButtons(getObjectFromGUID(guid)) end
    end
    choiceButtonShown={}
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

local function resourceObjectKind(obj)
    if obj==nil then return nil end
    if obj.type=="Card" then
        local data=gameCards[obj.guid]
        if data~=nil then
            if data.cardType=="Regular Unit" or data.cardType=="Elite Unit" then return "unit" end
            return "card"
        end
        -- Wounds/Quests are not unknown resource cards.
        local notes=obj.getGMNotes()
        if notes=="Wound" or notes=="Quest" then return nil end
        return "card"
    end
    if skillTokens[obj.guid]~=nil then return "skill" end
    if manaColor(obj)~=nil then return "mana" end
    if factionRewardNotes[obj.getGMNotes()]~=nil then return "factionReward" end
    return nil
end

local function matchesCardMana(card,color)
    if color==nil then return false end
    local data=gameCards[card.guid]
    if data==nil then return color=="Red" or color=="Blue" or color=="Green" or color=="White" end
    if color=="Gold" then return gStates.dayRound==true end
    if color=="Black" then return data.cardType=="Spell" and gStates.dayRound==false end
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

local function calculateCard(card,manaPowered,linkedBoost,linked,discardTarget,hasDiscard)
    local data=gameCards[card.guid]
    local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
    local known=data~=nil
    local tracked=data==nil or data.resourceTracked~=false
    local powered=manaPowered or linkedBoost~=nil
    local posture=cardPosture(card)
    local faceUp=card.is_face_down~=true and posture=="upright"
    -- Any non-Wound card played at 90 degrees has one generic resource,
    -- irrespective of its printed card effect. It requires an explicit choice.
    if posture=="sideways" and cardCanPlaySideways(card) then
        local effect=chosenEffect(card.guid,false,sidewaysChoices,true)
        return {guid=card.guid,known=known,complete=effect~=nil,powered=false,
            links={},status=effect~=nil and "green" or "yellow",resources=effect}
    end
    local sideTracked=tracked and not (not powered and rule~=nil and rule.normalTrackerNeutral==true)
    local choices=sideChoices(rule,powered)
    local chosen=chosenEffect(card.guid,powered,choices)
    local choicePending=choices~=nil and #choices>1 and chosen==nil
    local statePartial=rule~=nil and ((powered and rule.poweredPartial==true)
        or (not powered and rule.normalPartial==true)) and chosen==nil
    local base=chosen or (rule~=nil and (powered and rule.powered or rule.normal) or nil)
    -- A discard is an actual cost of Improvisation, even when its strong side
    -- came free from Concentration/Will Focus.
    local costPaid=rule==nil or rule.requiredLink==nil or hasDiscard==true
    local effects=sideTracked and faceUp and costPaid and not discardTarget
        and applyLinkedResourceBonus(base,linkedBoost) or nil
    local complete=sideTracked and base~=nil and not choicePending and not statePartial
        and rule.partial~=true and faceUp and costPaid and not discardTarget
    local choiceIsUntracked=chosen~=nil and not effectHasTrackedResource(chosen)
    local status=(not known or not sideTracked or posture=="discard" or choiceIsUntracked) and "red"
        or not complete and "yellow" or "green"
    if #linked>0 then status="purple" end
    return {guid=card.guid,known=known,complete=complete,powered=powered,
        links=linked,status=status,resources=effects}
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
local function resolveActionLinks(cards,footprints,manaPowered)
    local links,boostBy,boostSource,discarded,hasDiscard={}, {}, {}, {}, {}
    local boostClaimed={}
    for _,card in ipairs(cards) do links[card.guid]={} end
    local function connect(source,target)
        links[source.guid][#links[source.guid]+1]=target.guid
        links[target.guid][#links[target.guid]+1]=source.guid
    end
    local function nearestOverlap(source,valid,preferTilt)
        local best,bestArea,bestPriority=nil,0,-1
        local a=footprints[source.guid]
        for _,target in ipairs(cards) do
            if target.guid~=source.guid and valid(target) then
                local area=overlapArea(a,footprints[target.guid])
                local priority=preferTilt and cardPosture(target)=="discard" and 1 or 0
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
    -- Resolve discard costs after stronger links: a link-boosted Improvisation
    -- can still discard ANOTHER card, but never its own booster as payment.
    for _,source in ipairs(cards) do
        local data=gameCards[source.guid]
        local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
        if rule~=nil and rule.requiredLink~=nil and rule.requiredLink.mode=="discard"
            and source.is_face_down~=true and cardPosture(source)=="upright" then
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
            end,true)
            if target~=nil then
                discarded[target.guid]=source.guid
                hasDiscard[source.guid]=true
                connect(source,target)
            end
        end
    end
    return links,boostBy,boostSource,discarded,hasDiscard
end

-- Scan the play area for used abilities, the Unit area for Units, and crystal
-- inventory for unused mana. Only a played, supported effect enters the totals.
local function renderSeat(seatPos)
    if not resourceCardsPanelOpen() then return end
    local active=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    if active==nil or active.seatPos~=seatPos then return end

    local objects,placements={},{}
    local function inspectZone(guid,zoneKind)
        local zone=guid~=nil and getObjectFromGUID(guid) or nil
        if zone==nil then return end
        for _,obj in ipairs(zone.getObjects()) do
            local kind=resourceObjectKind(obj)
            if kind~=nil and (zoneKind=="play"
                or (zoneKind=="unit" and (kind=="unit" or kind=="mana"))
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

    local cards,manaObjects,footprints={}, {}, {}
    for guid,obj in pairs(objects) do
        local kind=resourceObjectKind(obj)
        if obj.type=="Card" and placements[guid]=="play" then
            cards[#cards+1]=obj
            footprints[guid]=footprint(obj)
        elseif kind=="mana" then
            manaObjects[#manaObjects+1]=obj
        end
    end

    -- Stable ordering also makes tied link targets deterministic across scans.
    table.sort(cards,function(a,b) return a.guid<b.guid end)
    local powered,usedMana={}, {}

    -- Track which physical mana token is powering which card. A crystal merely
    -- sitting in inventory must not be mistaken for a spent resource.
    for _,mana in ipairs(manaObjects) do
        if placements[mana.guid]=="play" then
            local color=manaColor(mana)
            if color~=nil then
                local p=mana.getPosition()
                local best,bestDistance=nil,nil
                for _,card in ipairs(cards) do
                    local f=footprints[card.guid]
                    local dx,dz=p[1]-f.x,p[3]-f.z
                    if math.abs(dx)<f.halfX and math.abs(dz)<f.halfZ
                        and matchesCardMana(card,color) then
                        local distance=dx*dx+dz*dz
                        if bestDistance==nil or distance<bestDistance then best,bestDistance=card,distance end
                    end
                end
                if best~=nil then
                    powered[best.guid]=true
                    usedMana[mana.guid]=best.guid
                end
            end
        end
    end

    local links,boostBy,boostSource,discarded,hasDiscard=resolveActionLinks(cards,footprints,powered)
    local current,records,totals={}, {}, {}
    for _,card in ipairs(cards) do
        local result=calculateCard(card,powered[card.guid]==true,boostBy[card.guid],
            links[card.guid],discarded[card.guid]~=nil,hasDiscard[card.guid]==true)
        local cardData=gameCards[card.guid]
        local rule=cardData~=nil and cardResourceDefinitions[cardData.resourceKey] or nil
        local choices=nil
        if discarded[card.guid]==nil then
            if cardPosture(card)=="sideways" then
                if cardCanPlaySideways(card) then choices=sidewaysChoices end
            elseif rule==nil or rule.requiredLink==nil or hasDiscard[card.guid]==true then
                -- Hide the choice entirely until its cost is present. Powered
                -- Rage has a fixed effect, so sideChoices is nil and hides it.
                choices=sideChoices(rule,result.powered)
            end
        end
        showChoiceButtons(card,choices,result.powered)
        result.kind=resourceObjectKind(card)
        result.contributes=false
        -- Fixed components of partially understood cards may be counted; an
        -- unresolved choice never contributes an invented amount.
        if result.resources~=nil then
            for category,value in pairs(result.resources) do
                if totalsKeys[category] and type(value)=="number" then
                    totals[category]=(totals[category] or 0)+value
                    if value~=0 then result.contributes=true end
                end
            end
        end
        records[card.guid]=result
        current[card.guid]=true
        setHighlight(card,result.status,result.powered)
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
        if records[guid]==nil then
            local kind=resourceObjectKind(obj)
            local poweredTarget=usedMana[guid]
            local contributing=poweredTarget~=nil and records[poweredTarget]~=nil
                and records[poweredTarget].contributes==true
            local status="yellow" -- Registered Unit/Skill/Faction Reward effects still need numeric definitions.
            local bright=false
            if kind=="mana" then
                status=contributing and "green" or "yellow"
                bright=poweredTarget~=nil
            end
            records[guid]={guid=guid,kind=kind,known=true,complete=false,
                contributes=contributing,powered=bright,status=status,
                powers=poweredTarget,resources=nil}
            current[guid]=true
            setHighlight(obj,status,bright)
        end
    end

    local previous=bySeat[seatPos] or {}
    local previousScan=resourceCardScanBySeat[seatPos]
    local previousMove=previousScan~=nil and (previousScan.totals.move or 0) or 0
    bySeat[seatPos]=current
    resourceCardScanBySeat[seatPos]={cards=records,totals=totals}
    refreshResourceTrackerText()
    if previousMove~=(totals.move or 0) then updateMoveDisplay() end
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

-- A card records only an explicit player selection; no assumptions about
-- movement versus combat are inferred from the board.
function resourceCardsChoiceClicked(player,value,id)
    if type(id)~="string" then return end
    local guid,category=id:match("^ResourceCardChoice_([0-9a-f]+)_([%a]+)$")
    if guid==nil then return end
    if not resourceCardsPanelOpen() then return end
    local card=getObjectFromGUID(guid)
    local data=card~=nil and gameCards[guid] or nil
    local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
    if card==nil or (rule==nil and not (cardPosture(card)=="sideways"
        and cardCanPlaySideways(card))) then return end
    local currentSeat=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    if currentSeat==nil then return end
    local zone=getObjectFromGUID(playerPlayAreas[currentSeat.seatPos])
    local inZone=false
    if zone~=nil then
        for _,obj in ipairs(zone.getObjects()) do
            if obj.guid==guid then inZone=true break end
        end
    end
    if not inZone then return end
    -- Linked cards take the powered choice even without mana placed on them.
    local scan=resourceCardScanBySeat[currentSeat.seatPos]
    local record=scan~=nil and scan.cards[guid] or nil
    local powered=record~=nil and record.powered==true
    local sideways=cardPosture(card)=="sideways"
    local choices=(sideways and cardCanPlaySideways(card)) and sidewaysChoices
        or (not sideways and sideChoices(rule,powered) or nil)
    local valid=false
    for _,choice in ipairs(choices or {}) do
        if choice[category]~=nil then valid=true break end
    end
    if not valid then return end
    if choiceExpandedByGUID[guid]~=true then
        -- A click on the sole, selected button opens the alternatives. Merely
        -- opening this menu must not change the calculated resource totals.
        choiceExpandedByGUID[guid]=true
        showChoiceButtons(card,choices,powered)
        return
    end
    -- Any choice, including the already selected one, closes the menu.
    local selected=selectedResourceByGUID[guid] or {}
    if not sideways then
        -- Normal and powered abilities use the same card-wide preference.
        selected.effect=category
    elseif choiceAvailable(sideChoices(rule,false),category)
        or choiceAvailable(sideChoices(rule,true),category) then
        -- Keep a 90-degree generic resource in sync with the printed action
        -- when the selected category is also an available printed choice.
        selected.effect=category
        selected.sideways=nil
    else
        -- A generic +1 with no matching printed category is independent.
        selected.sideways=category
    end
    selectedResourceByGUID[guid]=selected
    choiceExpandedByGUID[guid]=nil
    showChoiceButtons(card,choices,powered)
    queueSeat(currentSeat.seatPos,nil)
end

function resourceCardsPanelChanged(open)
    -- The tracker shows the current turn's Mage Knight; stale outlines on other
    -- players' boards would falsely imply those pieces contribute to these totals.
    clearAll()
    if open~=true then return end
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
    if resourceCardsPanelOpen() then resourceCardsPanelChanged(true) else clearAll() end
end

local function resourceCardsRelevantZone(ctx)
    if ctx==nil or ctx.zoneInfo==nil or resourceObjectKind(ctx.obj)==nil then return nil end
    local kind=ctx.zoneInfo.kind
    if kind=="play" then return ctx.zoneInfo.seatPos end
    local objectKind=resourceObjectKind(ctx.obj)
    if kind=="unit" and (objectKind=="unit" or objectKind=="mana") then return ctx.zoneInfo.seatPos end
    if kind=="crystal" and objectKind=="mana" then return ctx.zoneInfo.seatPos end
    return nil
end

function resourceCardsZoneEntered(ctx)
    local seat=resourceCardsRelevantZone(ctx)
    if seat~=nil then queueSeat(seat,ctx.objGUID) end
end

function resourceCardsZoneLeft(ctx)
    local seat=resourceCardsRelevantZone(ctx)
    if seat~=nil then queueSeat(seat,nil) end
end

function resourceCardsObjectMoved(obj)
    if not resourceCardsPanelOpen() or resourceObjectKind(obj)==nil then return end
    local player=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    if player==nil then return end
    local seat=player.seatPos
    for _,zoneGUID in ipairs({playerPlayAreas[seat],playerUnitAreas[seat],playerCrystalAreas[seat]}) do
        local zone=getObjectFromGUID(zoneGUID)
        if zone~=nil then
            for _,candidate in ipairs(zone.getObjects()) do
                if candidate.guid==obj.guid then queueSeat(seat,obj.guid) return end
            end
        end
    end
    if bySeat[seat]~=nil and bySeat[seat][obj.guid]==true then queueSeat(seat,nil) end
end

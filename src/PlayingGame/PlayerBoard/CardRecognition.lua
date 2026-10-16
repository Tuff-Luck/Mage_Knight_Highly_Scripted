-- The physical play area supplies estimated resources to the Resource Tracker.
-- Runtime-only observations never overwrite the saved manual +/- adjustments.
resourceCardScanBySeat={}
local generation={}
local shown={}
-- Mana crystal figurines are still read for powering cards, but should never
-- receive Resource Tracker highlights. Avoid repeated highlightOff calls.
local crystalHighlightCleared={}
local bySeat={}
-- Player choices are transient, never written into gStates or save JSON.
local selectedResourceByGUID={}
-- A choice lasts for one play; delayed departure checks must not race a return.
local choiceResetGenerationByGUID={}
-- Display state is separate from player selections. Picks/drops may clear the
-- buttons, but the chosen resource stays until the script reloads.
local choiceExpandedByGUID={}
local choiceButtonShown={}
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

-- Terrain abilities are an overlay, not changes to gStates.moveCost. This
-- preserves day/night terrain settings, manual adjustments and other cards.
-- City/Explore are not terrain: their special movement costs remain intact.
local pathFindingTerrain={
    plains=true,hills=true,forest=true,wasteland=true,desert=true,swamp=true,
    lake=true,mountain=true
}

function resourceCardsEffectiveTerrainCost(terrain)
    local base=gStates~=nil and gStates.moveCost~=nil and gStates.moveCost[terrain] or nil
    if base==nil then return 999 end
    -- Path Finding does not grant access to impassable lakes or mountains.
    if base>=900 or not pathFindingTerrain[terrain] then return base end
    local player=turnOrder~=nil and gStates~=nil
        and turnOrder[gStates.turnNumber] or nil
    local scan=player~=nil and resourceCardScanBySeat[player.seatPos] or nil
    local modifiers=scan~=nil and scan.terrainModifiers or nil
    if modifiers==nil then return base end
    if modifiers.setToTwo then return math.min(base,2) end
    if modifiers.reduce>0 then return math.min(base,math.max(2,base-modifiers.reduce)) end
    return base
end

local function clearHighlight(guid)
    if shown[guid]==nil then return end
    local obj=getObjectFromGUID(guid)
    if obj~=nil then obj.highlightOff() end
    shown[guid]=nil
end

local function setHighlight(obj,kind,powered)
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
    ranged="R",siege="S",healing="H",draw="D",other="O",
    fire="F",ice="I",coldFire="C",boost="H+",split="I/F",negative="N",
    heal="H",combat="C",wound="W",reputation="R",gain="G",ready="R",
    base="2",sourceUnused="3"}

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
    local isSkill=skillTokens[card.guid]~=nil
    if choices==nil or #choices<2 or (card.is_face_down==true and not isSkill)
        or (not isSkill and posture=="discard")
        or (not isSkill and posture=="sideways" and not (cardCanPlaySideways(card)
            or card.getGMNotes()=="Wound")) then
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
    local _,selected=currentChoice(card.guid,powered,choices,not isSkill and posture=="sideways")
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
    -- The card's object UI has the opposite apparent Z rotation to the
    -- card's world Y rotation. Counter-rotate each label in the correct
    -- direction, while positions stay card-local (vertical when sideways).
    -- Snap to quarter-turns to avoid UI churn from small rotation changes.
    local buttonRotation=180
    if posture=="sideways" then
        buttonRotation=card.getRotation()[2]%360<180 and 90 or 270
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

local function resourceObjectKind(obj)
    if obj==nil then return nil end
    if skillTokens[obj.guid]~=nil then return "skill" end
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

local function calculateCard(card,manaPowered,linkedBoost,linked,discardTarget,hasDiscard,skillLink)
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
        return calculateSideways(card,known,skillLink)
    end
    local sideTracked=tracked and not (not powered and rule~=nil and rule.normalTrackerNeutral==true)
    local choices=sideChoices(rule,powered)
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
    -- A discard is an actual cost of Improvisation, even when its strong side
    -- came free from Concentration/Will Focus.
    local costPaid=rule==nil or rule.requiredLink==nil or hasDiscard==true
    local effects=sideTracked and faceUp and costPaid and not discardTarget
        and applyLinkedResourceBonus(base,linkedBoost) or nil
    -- A card's other unimplemented options do not make its currently selected
    -- *known* resource effect uncertain. Keep the first option as the fast,
    -- green default; only a genuinely unresolved selected effect stays yellow.
    local knownSelectedOption=chosen~=nil and effectHasTrackedResource(chosen)
    local complete=sideTracked and base~=nil and not choicePending and not statePartial
        and (rule.partial~=true or knownSelectedOption)
        and faceUp and costPaid and not discardTarget
    local choiceIsUntracked=chosen~=nil and not effectHasTrackedResource(chosen)
    local status=(not known or not sideTracked or posture=="discard" or choiceIsUntracked) and "blue"
        or not complete and "yellow" or "green"
    -- Linking information is more valuable than the underlying certainty colour.
    if #linked>0 then status="purple" end
    return {guid=card.guid,known=known,complete=complete,powered=powered,
        links=linked,status=status,resources=effects,
        usesTerrainBlock=usesTerrainBlock and faceUp and not discardTarget}
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
        if discarded[source.guid]==nil and rule~=nil and rule.requiredLink~=nil
            and rule.requiredLink.mode=="discard"
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

-- Generic Skill-card links: one Skill per target, one target per Skill.
-- The descriptor, not an individual Skill GUID, determines replacement value,
-- card-type bonuses, mana payment and player-declared conditional values.
local function manaInsideFootprint(mana,area)
    local p=mana.getPosition()
    return math.abs(p[1]-area.x)<area.halfX
        and math.abs(p[3]-area.z)<area.halfZ
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

local function sidewaysModifierValue(skill,target,descriptor,mana)
    local value=descriptor.value or 1
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
    return value
end

local function resolveSkillCardLinks(skills,targets,footprints,manaObjects,placements,reservedMana)
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
                    sidewaysValue=sidewaysModifierValue(skill,target,descriptor,mana),
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
    -- Gold may supply a basic colour by day; Black may supply a Spell at night.
    if color=="Gold" and gStates.dayRound~=true then return false end
    if color=="Black" and (gStates.dayRound==true or data.cardType~="Spell") then return false end
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
local function calculateSkill(skill,linkedTarget,unitState)
    local rule=skillResourceDefinitions[skill.guid]
    if rule==nil then
        return {guid=skill.guid,kind="skill",known=true,complete=false,
            status="yellow",powered=false,resources=nil}
    end
    local chosen=rule.choices~=nil and chosenEffect(skill.guid,false,rule.choices) or nil
    local effects=chosen
        or (skill.is_face_down==true and rule.flipped or nil)
        or (gStates.dayRound==true and rule.day or rule.night)
        or rule.normal

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

    local tracked=effectHasTrackedResource(effects)
    local unitLinked=#unitSources>0
    local status=rule.untracked and "blue"
        or (linkedTarget~=nil or unitLinked) and "purple"
        or unitResolved and "green"
        or rule.linkedCard~=nil and linkedTarget==nil and "yellow"
        or tracked and (rule.partial and "yellow" or "green")
        or effects~=nil and "blue" or "yellow"
    local links={}
    if linkedTarget~=nil then links[#links+1]=linkedTarget end
    for _,guid in ipairs(unitSources) do links[#links+1]=guid end
    return {guid=skill.guid,kind="skill",known=true,
        complete=unitResolved or (tracked and not rule.partial) or linkedTarget~=nil,
        powered=skill.is_face_down==true or linkedTarget~=nil or unitLinked,
        status=status,links=links,unitSources=unitSources,
        resources=effects,choices=rule.choices}
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

    local cards,wounds,skills,manaObjects,footprints={}, {}, {}, {}, {}
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
        end
    end

    -- Read the physical Unit state once per scan, only for played Skills
    -- declaring that dependency. This also supplies which Unit cards to link.
    local unitState=nil
    for _,skill in ipairs(skills) do
        local rule=skillResourceDefinitions[skill.guid]
        if rule~=nil and rule.unitCondition~=nil then
            unitState=unitLayoutResourceState(seatPos)
            break
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
        resolveSkillCardLinks(skills,skillTargets,footprints,manaObjects,placements,manaByObject)
    local powered,usedMana,spellSupply={}, {}, {}
    local function spendMana(card,color,manaGUID)
        local data=gameCards[card.guid]
        if data~=nil and data.cardType=="Spell" then
            -- A Spell's stronger effect needs basic-colour AND Black mana at Night.
            local supply=spellSupply[card.guid] or {basic=false,black=false}
            if color=="Black" then supply.black=true else supply.basic=true end
            spellSupply[card.guid]=supply
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
                        and matchesCardMana(card,color) then
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
    for guid,supply in pairs(spellSupply) do
        powered[guid]=gStates.dayRound~=true and supply.basic and supply.black
    end

    local links,boostBy,boostSource,discarded,hasDiscard=resolveActionLinks(cards,footprints,powered)
    local current,records,totals={}, {}, {}
    local usesCurrentHexBlock=false
    local terrainModifiers={reduce=0,setToTwo=false}
    for _,card in ipairs(cards) do
        local result=calculateCard(card,powered[card.guid]==true,boostBy[card.guid],
            links[card.guid],discarded[card.guid]~=nil,hasDiscard[card.guid]==true,
            skillLinksByTarget[card.guid])
        local manaLink=manaByCard[card.guid]
        if manaLink~=nil then
            result.status="purple"
            result.links[#result.links+1]=manaLink.skillGUID
            result.convertedMana=manaLink.converted
        end
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
        -- Path Finding's movement modifier applies only when its printed
        -- effect is actually played, not while discarded, linked as payment,
        -- face down or used sideways for a basic +1.
        if rule~=nil and rule.terrainReduction==true
            and cardPosture(card)=="upright" and result.resources~=nil
            and type(result.resources.move)=="number" then
            if result.powered then
                terrainModifiers.setToTwo=true
            else
                terrainModifiers.reduce=terrainModifiers.reduce+1
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
    -- An unlinked Wound is inert. Only an attached Skill permits sideways use.
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
        if records[guid]==nil and resourceObjectKind(obj)~="wound" then
            local kind=resourceObjectKind(obj)
            local poweredTarget=usedMana[guid]
            local contributing=poweredTarget~=nil and records[poweredTarget]~=nil
                and records[poweredTarget].contributes==true
            local result
            if kind=="skill" and placements[guid]=="play" then
                local conversion=manaBySkill[guid]
                result=calculateSkill(obj,skillLinksBySkill[guid]
                    or (conversion~=nil and conversion.targetGUID or nil),unitState)
                showChoiceButtons(obj,result.choices,result.powered)
                addResourceAmounts(result,totals)
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
                local skillContributes=sidewaysLink~=nil
                    and records[sidewaysLink.targetGUID]~=nil
                    and records[sidewaysLink.targetGUID].contributes==true
                local status=(conversion~=nil or sidewaysLink~=nil) and "purple"
                    or kind=="mana" and (contributing and "green" or "yellow") or "yellow"
                local bright=kind=="mana" and (poweredTarget~=nil or sidewaysLink~=nil)
                result={guid=guid,kind=kind,known=true,complete=false,
                    contributes=contributing or skillContributes,powered=bright,status=status,
                    powers=poweredTarget or (sidewaysLink~=nil and sidewaysLink.targetGUID or nil),
                    links=conversion~=nil and {conversion.skillGUID}
                        or sidewaysLink~=nil and {sidewaysLink.skillGUID,sidewaysLink.targetGUID} or {},
                    convertedMana=conversion~=nil and conversion.converted or nil,
                    resources=nil}
            end
            records[guid]=result
            current[guid]=true
            setHighlight(obj,result.status,result.powered)
        end
    end

    -- Qualifying Units actually supplied the dynamic Skill resource. Show
    -- their link just like physical Skill/card interactions, without treating
    -- Command or Wound markers as resource sources themselves.
    for guid,record in pairs(records) do
        if record.kind=="skill" and record.unitSources~=nil then
            for _,unitGUID in ipairs(record.unitSources) do
                local unit,unitRecord=objects[unitGUID],records[unitGUID]
                if unit~=nil and unitRecord~=nil then
                    unitRecord.status="purple"
                    unitRecord.powered=true
                    unitRecord.contributes=true
                    unitRecord.links[#unitRecord.links+1]=guid
                    setHighlight(unit,unitRecord.status,unitRecord.powered)
                end
            end
        end
    end

    local previous=bySeat[seatPos] or {}
    local previousScan=resourceCardScanBySeat[seatPos]
    local previousMove=previousScan~=nil and (previousScan.totals.move or 0) or 0
    local prior=previousScan~=nil and previousScan.terrainModifiers or nil
    local terrainChanged=prior==nil and (terrainModifiers.reduce>0 or terrainModifiers.setToTwo)
        or prior~=nil and (prior.reduce~=terrainModifiers.reduce
            or prior.setToTwo~=terrainModifiers.setToTwo)
    local totalsChanged=previousScan==nil
    if not totalsChanged then
        for category in pairs(totalsKeys) do
            if (previousScan.totals[category] or 0)~=(totals[category] or 0) then
                totalsChanged=true
                break
            end
        end
    end
    bySeat[seatPos]=current
    resourceCardScanBySeat[seatPos]={cards=records,totals=totals,
        terrainModifiers=terrainModifiers,usesCurrentHexBlock=usesCurrentHexBlock}
    -- Repeated scans for card position/highlight changes need no panel repaint
    -- unless a calculated resource or movement modifier actually changed.
    if totalsChanged or terrainChanged then refreshResourceTrackerText() end
    if previousMove~=(totals.move or 0) or terrainChanged then updateMoveDisplay() end
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
    local isSkill=skillTokens[guid]~=nil
    local rule=isSkill and skillResourceDefinitions[guid]
        or (data~=nil and cardResourceDefinitions[data.resourceKey] or nil)
    local currentSeat=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    if card==nil or currentSeat==nil then return end
    local scan=resourceCardScanBySeat[currentSeat.seatPos]
    local record=scan~=nil and scan.cards[guid] or nil
    local linkedWound=card.getGMNotes()=="Wound" and record~=nil
        and record.linkedSkill~=nil
    if rule==nil and not isSkill and not (cardPosture(card)=="sideways"
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
    local sideways=not isSkill and cardPosture(card)=="sideways"
    local choices=isSkill and (rule~=nil and rule.choices or nil)
        or ((sideways and (cardCanPlaySideways(card) or linkedWound)) and sidewaysChoices
            or (not sideways and sideChoices(rule,powered) or nil))
    local valid=false
    for _,choice in ipairs(choices or {}) do
        if choiceCategory(choice)==category then valid=true break end
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
    if ctx==nil or ctx.zoneInfo==nil or ctx.obj==nil then return nil end
    local kind=ctx.zoneInfo.kind
    local objectKind=resourceObjectKind(ctx.obj)
    if kind=="play" and objectKind~=nil then return ctx.zoneInfo.seatPos end
    if kind=="unit" and (objectKind=="unit" or objectKind=="mana"
        or unitLayoutIsCommand(ctx.obj) or unitLayoutIsWound(ctx.obj)) then
        return ctx.zoneInfo.seatPos
    end
    if kind=="crystal" and objectKind=="mana" then return ctx.zoneInfo.seatPos end
    return nil
end

function resourceCardsZoneEntered(ctx)
    local seat=resourceCardsRelevantZone(ctx)
    if seat~=nil then queueSeat(seat,ctx.objGUID) end
end

function resourceCardsZoneLeft(ctx)
    local seat=resourceCardsRelevantZone(ctx)
    if ctx~=nil and ctx.zoneInfo~=nil and ctx.zoneInfo.kind=="play" then
        scheduleChoiceResetAfterPlay(ctx.objGUID,ctx.zoneInfo.seatPos)
    end
    if seat~=nil then queueSeat(seat,nil) end
end

function resourceCardsObjectMoved(obj)
    if not resourceCardsPanelOpen() or obj==nil then return end
    local player=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    if player==nil then return end
    local seat=player.seatPos
    local isUnitStateToken=unitLayoutIsCommand(obj) or unitLayoutIsWound(obj)
    if resourceObjectKind(obj)==nil and not isUnitStateToken then
        -- A played powered One with the Land may change Block value when the
        -- Mage Knight moves to different terrain. Only watch avatar drops
        -- while that exact effect is selected; no continual background scan.
        local scan=resourceCardScanBySeat[seat]
        if scan~=nil and scan.usesCurrentHexBlock==true then
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
    for _,zoneGUID in ipairs({playerPlayAreas[seat],playerUnitAreas[seat],playerCrystalAreas[seat]}) do
        local zone=getObjectFromGUID(zoneGUID)
        if zone~=nil then
            for _,candidate in ipairs(zone.getObjects()) do
                if candidate.guid==obj.guid then queueSeat(seat,obj.guid) return end
            end
        end
    end
    if isUnitStateToken then
        -- Zone exit usually handles this already, but a token can be dragged
        -- straight out and dropped before its membership event settles.
        queueSeat(seat,nil)
    elseif bySeat[seat]~=nil and bySeat[seat][obj.guid]==true then
        scheduleChoiceResetAfterPlay(obj.guid,seat)
        queueSeat(seat,nil)
    end
end

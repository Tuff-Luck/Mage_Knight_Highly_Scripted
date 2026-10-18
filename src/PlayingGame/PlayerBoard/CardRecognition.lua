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
    for _,effect in ipairs(effects) do
        if effect.mode=="set" and terrainEffectApplies(effect,terrain) then
            return effect.cost
        end
    end
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
    blockP1="B",blockF1="BF",blockI1="BI",blockIF1="BC",
    twiceAttack="A2",twiceBlock="B2",move="M",influence="I",attack="A",block="B",
    ranged="R",siege="S",healing="H",draw="D",other="O",
    siegeFire="SF",siegeIce="SI",rangedFire="RF",rangedIce="RI",
    fire="F",ice="I",coldFire="C",boost="H+",split="I/F",negative="N",
    heal="H",combat="C",wound="W",reputation="R",gain="G",ready="R",
    base="2",sourceUnused="3",red="R",blue="B",white="W",green="G",
    fireAttack="F",fireBlock="F",fireSiege="F",iceSiege="I",fireBlockOnly="B",fireBlockCounter="B+",
    splitBlock="B2",zero="0",one="1",two="2",three="3",four="4",five="5"}
-- The choice UI and initial-guess tie-breaks follow the Resource Tracker order.
local resourceChoiceOrder={
    move=1,siege=2,ranged=3,block=4,attack=5,influence=6,healing=7,heal=7,
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
            and attr.id:sub(1,19)=="ResourceCardChoice_" then
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
local function showChoiceButtons(card,choices,powered,inventorySpec,inventorySets)
    if card==nil then return end
    local posture=cardPosture(card)
    local isSkill=skillTokens[card.guid]~=nil or card.getGMNotes()=="Puppet Master"
    -- Skill tokens are physically smaller than Action cards, so their choice
    -- buttons (collapsed and expanded) need a larger dedicated scale.
    local buttonScale=isSkill and "0.58 0.58" or "0.25 0.25"
    local buttonSpacing=44
    local buttonRowOffset=-30
    local data=gameCards[card.guid]
    local isArtifact=data~=nil and data.cardType=="Artifact"
    if choices==nil or #choices<2
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
                    iconOverlayColor=choice.iconOverlayColor,
                    iconOverlayAlignment=choice.iconOverlayAlignment,
                    iconOverlaySize=choice.iconOverlaySize}
            end
        end
        table.sort(row.entries,function(a,b)
            if a.rank~=b.rank then return a.rank<b.rank end
            return a.originalIndex<b.originalIndex
        end)
        if #row.entries<2 or selected==nil then
            if choiceButtonShown[card.guid]~="hidden" then
                removeChoiceButtons(card)
                choiceButtonShown[card.guid]="hidden"
            end
            choiceExpandedByGUID[card.guid]=nil
            return
        end
        row.expanded=(row.index==0 and (expandedRow==true or expandedRow=="base"))
            or expandedRow=="set"..tostring(row.index)
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
    if choiceButtonShown[card.guid]==signature then return end
    local xml=card.UI.getXmlTable() or {}
    for i=#xml,1,-1 do
        local attr=xml[i].attributes
        if attr~=nil and type(attr.id)=="string"
            and attr.id:sub(1,19)=="ResourceCardChoice_" then table.remove(xml,i) end
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
        for _,entry in ipairs(row.visible) do
            local category=entry.category
            local column=resourceChoiceColumn(category)
            local x=((#columns+1)/2-columnByCategory[column])*buttonSpacing
            local above=row.expanded and category~=column and displayed[column]==true
            local buttonY=y+(above and buttonRowOffset or 0)
            if skillPositions~=nil then
                x=skillPositions[category].x
                buttonY=skillPositions[category].y
            end
            local active=category==row.selected
            local icon=resourceCardsChoiceIcon(entry.icon)
            if icon~=nil and blocked[icon.name] then icon=nil end
            local buttonId="ResourceCardChoice_"..card.guid.."_"
                ..(row.index>0 and ("set"..row.index.."_") or "")..category
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
                button.children={{tag="Image",attributes={
                    image=icon.name,width=82,height=82,preserveAspect="true",
                    raycastTarget="false",color="#FFFFFF"}}}
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
            xml[#xml+1]=button
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
local function showUnitAbilityButtons(unit,abilities,activation,unwounded)
    if unit==nil then return end
    if not unwounded or activation==nil or abilities==nil or #abilities==0 then
        removeChoiceButtons(unit)
        choiceExpandedByGUID[unit.guid]=nil
        return
    end
    local selected=math.max(1,math.min(#abilities,activation.choice or 1))
    local expanded=choiceExpandedByGUID[unit.guid]==true and #abilities>1
    local selectedKeys={}
    if abilities.multi==true then
        for i=1,#abilities do
            if activation.selected~=nil and activation.selected[i]==true then
                selectedKeys[#selectedKeys+1]=tostring(i)
            end
        end
    end
    local signature="Unit:"..selected..":"..tostring(expanded)..":"..tostring(#abilities)
        ..":"..table.concat(selectedKeys,",")
    if choiceButtonShown[unit.guid]==signature then return end

    local xml=unit.UI.getXmlTable() or {}
    for i=#xml,1,-1 do
        local attr=xml[i].attributes
        if attr~=nil and type(attr.id)=="string"
            and attr.id:sub(1,19)=="ResourceCardChoice_" then table.remove(xml,i) end
    end
    local visibleAssets,seen={},{}
    local displayed=expanded and abilities or {abilities[selected]}
    for _,ability in ipairs(displayed) do
        local name=ability.icon or ability.key
        if not seen[name] then visibleAssets[#visibleAssets+1]=name seen[name]=true end
    end
    local assets,blocked=resourceCardsChoiceAssetsFor(unit.UI,visibleAssets)

    -- Shared printed rows keep a stable vertical slot; all sub-options start
    -- at the centre column and grow only to the right.
    local rows,rowByKey={},{}
    if expanded then
        for i,ability in ipairs(abilities) do
            local key=ability.row or i
            if rowByKey[key]==nil then
                rowByKey[key]={}
                rows[#rows+1]=rowByKey[key]
            end
            rowByKey[key][#rowByKey[key]+1]=i
        end
    else
        rows={{selected}}
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
            local active=abilities.multi==true and activation.selected~=nil
                and activation.selected[index]==true or index==selected and abilities.multi~=true
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
                else possible[category]=true end
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
        and (rule.partial~=true or knownSelectedOption)
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
        showChoiceButtons(card,choices,result.powered,inventorySpec,inventorySets)
        result.kind=resourceObjectKind(card)
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
            if best~=nil then
                local bonusRule=sourceRecord.powered and rule.combatLink.powered
                    or rule.combatLink.normal
                local bonus=bonusRule[bestType]*(sourceRecord.repeatCount or 1)
                local targetRecord=records[best.guid]
                local adjusted={}
                for key,value in pairs(targetRecord.resources) do adjusted[key]=value end
                adjusted[bestCategory]=adjusted[bestCategory]+bonus
                targetRecord.resources=adjusted
                totals[bestCategory]=(totals[bestCategory] or 0)+bonus
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
    local function unitManaCounts(unit)
        local counts={}
        local area=footprint(unit)
        for _,mana in ipairs(manaObjects) do
            local color=manaColor(mana)
            if color~=nil and manaInsideFootprint(mana,area) then
                counts[color]=(counts[color] or 0)+1
            end
        end
        return counts
    end
    local function unitAbilityPaid(ability,counts)
        local cost=ability.manaCost
        if cost==nil then return true end
        if (counts[cost] or 0)>0 then return true end
        -- Daytime Gold may be used as any basic mana. The selected button
        -- records which basic colour the player meant to spend.
        return cost~="Black" and gStates.dayRound==true and (counts.Gold or 0)>0
    end
    local function unitAbilityResources(ability,counts)
        if ability==nil or not unitAbilityPaid(ability,counts) then return nil end
        local resources={}
        for category,value in pairs(ability) do
            if totalsKeys[category] and type(value)=="number" then
                local bonus=0
                if ability.bonusColor~=nil and (counts[ability.bonusColor] or 0)>0 then
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
    for unitGUID,activation in pairs(activations) do
        if activation.seatPos==seatPos then
            local unit=objects[unitGUID]
            local abilities=unitResourceDefinitions[unitGUID]
            if unit~=nil and abilities~=nil then
                if unitState==nil then unitState=unitLayoutResourceState(seatPos) end
                local unwounded=true
                for _,entry in ipairs(unitState.units) do
                    if entry.guid==unitGUID then unwounded=entry.unwounded break end
                end
                showUnitAbilityButtons(unit,abilities,activation,unwounded)
                local selected=abilities[activation.choice or 1]
                if unwounded and selected~=nil then
                    local counts=unitManaCounts(unit)
                    local resources=unitAbilityResources(selected,counts)
                    local result={guid=unitGUID,kind="unit",known=true,
                        complete=unitAbilityPaid(selected,counts),
                        resources=resources,powered=false,links={}}
                    if abilities.multi==true then
                        -- Delphana Masters may apply several different
                        -- mana-paid effects to one or more enemies.
                        result.complete=true
                        for i,ability in ipairs(abilities) do
                            if activation.selected~=nil and activation.selected[i]==true
                                and not unitAbilityPaid(ability,counts) then
                                result.complete=false
                            end
                        end
                    end
                    addResourceAmounts(result,totals)
                    result.status=result.contributes and "green" or "blue"
                    records[unitGUID]=result
                    current[unitGUID]=true
                    setHighlight(unit,result.status,false)
                    if selected.terrainReduce and result.complete then
                        terrainModifiers[#terrainModifiers+1]=forestersTerrainModifier
                    end
                    if selected.boostOtherUnits and result.complete then
                        shocktroopsBoosts=shocktroopsBoosts+1
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
        local skillRecord,targetRecord=records[skill.guid],records[target.guid]
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
            if family~=nil and rule.unitBoost[family]~=nil then
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
                        (choice[family] or rule.unitBoost[family]))
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
            if best~=nil then
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
        if records[guid]==nil and resourceObjectKind(obj)~="wound" then
            local kind=resourceObjectKind(obj)
            local poweredTarget=usedMana[guid]
            local contributing=poweredTarget~=nil and records[poweredTarget]~=nil
                and records[poweredTarget].contributes==true
            local result
            if kind=="puppet" and placements[guid]=="play" then
                local choices=obj.is_face_down~=true and puppetResourceOptions(guid) or nil
                local selected=choices~=nil and chosenEffect(guid,false,choices) or nil
                result={guid=guid,kind="puppet",known=true,complete=selected~=nil,
                    status=selected~=nil and "green" or "blue",
                    resources=selected,choices=choices,powered=false,links={}}
                showChoiceButtons(obj,choices,false)
                addResourceAmounts(result,totals)
            elseif kind=="skill" and placements[guid]=="play" then
                local conversion=manaBySkill[guid]
                result=calculateSkill(obj,skillLinksBySkill[guid]
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
    bySeat[seatPos]=current
    resourceCardScanBySeat[seatPos]={cards=records,totals=totals,
        terrainModifiers=terrainModifiers,movementEffects=movementEffects,
        usesCurrentHexBlock=usesCurrentHexBlock,
        usesCurrentHexHealing=usesCurrentHexHealing,
        usesSkillLocation=usesSkillLocation}
    -- Redraw movement when ability flags change, even if total Move stays equal.
    if totalsChanged or terrainChanged then refreshResourceTrackerText() end
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
        "^ResourceCardChoice_([0-9a-f]+)_set(%d+)_([%a]+)$")
    if guid==nil then
        guid,category=id:match("^ResourceCardChoice_([0-9a-f]+)_([%a]+)$")
    end
    if guid==nil then return end
    setIndex=setIndex~=nil and tonumber(setIndex) or nil
    if not resourceCardsPanelOpen() then return end
    local card=getObjectFromGUID(guid)
    local data=card~=nil and gameCards[guid] or nil
    local isSkill=skillTokens[guid]~=nil
    local isPuppet=card~=nil and card.getGMNotes()=="Puppet Master"
    local rule=isSkill and skillResourceDefinitions[guid]
        or (data~=nil and cardResourceDefinitions[data.resourceKey] or nil)
    local currentSeat=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    if card==nil or currentSeat==nil then return end
    local scan=resourceCardScanBySeat[currentSeat.seatPos]
    local record=scan~=nil and scan.cards[guid] or nil
    local linkedWound=card.getGMNotes()=="Wound" and record~=nil
        and record.linkedSkill~=nil
    if rule==nil and not isSkill and not isPuppet and not (cardPosture(card)=="sideways"
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
    local mainChoices
    if isSkill or isPuppet then
        mainChoices=record~=nil and record.choices or (rule~=nil and rule.choices or nil)
    elseif sideways and (cardCanPlaySideways(card) or linkedWound) then
        mainChoices=sidewaysChoices
    elseif not sideways then
        mainChoices=sideChoices(rule,powered)
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
        for _,entry in ipairs(state.units) do
            if entry.guid==unit.guid and not entry.unwounded then return end
        end
        -- For ordinary Units the strongest tracker family determines the
        -- default choice; ties keep printed row order. Non-resource abilities
        -- never outrank a tracked option solely for being first.
        local abilities=unitResourceDefinitions[unit.guid]
        local scores=trackerChoiceScores(unit.guid,pickup.seatPos)
        local choice,bestScore=1,-math.huge
        for i,ability in ipairs(abilities) do
            local score=scores[ability.key] or 0
            if score>bestScore then choice,bestScore=i,score end
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
    for _,entry in ipairs(state.units) do
        if entry.guid==unitGUID and not entry.unwounded then return end
    end
    if choiceExpandedByGUID[unitGUID]~=true and #abilities>1 then
        -- First click reveals the compact vertical grid; no resource change.
        choiceExpandedByGUID[unitGUID]=true
        showUnitAbilityButtons(unit,abilities,activation,true)
        return
    end
    -- Delphana Masters can use several different abilities with a single
    -- activation. Toggle them individually without erasing earlier choices.
    if abilities.multi==true then
        activation.selected=activation.selected or {}
        activation.selected[index]=not (activation.selected[index]==true)
    end
    -- Selecting an option closes the grid to the chosen centred icon.
    activation.choice=index
    choiceExpandedByGUID[unitGUID]=nil
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
    -- The tracker shows the current turn's Mage Knight; stale outlines on other
    -- players' boards would falsely imply those pieces contribute to these totals.
    clearAll()
    resourceUnitsRefreshButtons()
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
    if resourceCardsPanelOpen() then
        resourceCardsPanelChanged(true)
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
    if kind=="unit" and (objectKind=="unit" or objectKind=="mana"
        or monsterPugs[ctx.objGUID]~=nil
        or unitLayoutIsCommand(ctx.obj) or unitLayoutIsWound(ctx.obj)) then
        return ctx.zoneInfo.seatPos
    end
    if kind=="crystal" and objectKind=="mana" then return ctx.zoneInfo.seatPos end
    if kind=="hand" and objectKind=="wound" then return ctx.zoneInfo.seatPos end
    return nil
end

function resourceCardsZoneEntered(ctx)
    if ctx~=nil and ctx.obj~=nil and unitLayoutIsWound(ctx.obj) then
        resourceUnitsRefreshButtons()
    end
    local seat=resourceCardsRelevantZone(ctx)
    if seat~=nil then queueSeat(seat,ctx.objGUID) end
end

function resourceCardsZoneLeft(ctx)
    if ctx~=nil and ctx.obj~=nil and unitLayoutIsWound(ctx.obj) then
        resourceUnitsRefreshButtons()
    end
    local seat=resourceCardsRelevantZone(ctx)
    if ctx~=nil and ctx.zoneInfo~=nil and ctx.zoneInfo.kind=="play" then
        scheduleChoiceResetAfterPlay(ctx.objGUID,ctx.zoneInfo.seatPos)
    end
    if seat~=nil then queueSeat(seat,nil) end
end

function resourceCardsObjectMoved(obj)
    if obj~=nil and unitLayoutIsWound(obj)
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

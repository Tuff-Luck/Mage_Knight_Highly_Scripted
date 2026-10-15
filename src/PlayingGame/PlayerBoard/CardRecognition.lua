-- The physical play area supplies estimated resources to the Resource Tracker.
-- Runtime-only observations never overwrite the saved manual +/- adjustments.
resourceCardScanBySeat={}
local generation={}
local shown={}
local bySeat={}
-- Player choices are transient, never written into gStates or save JSON.
local selectedResourceByGUID={}
local choiceButtonShown={}
local palette={
    green={{0.10,0.55,0.14},{0.35,1.00,0.38}},
    yellow={{0.62,0.48,0.08},{1.00,0.94,0.19}},
    red={{0.59,0.10,0.12},{1.00,0.27,0.25}},
    purple={{0.47,0.19,0.62},{0.92,0.43,1.00}}
}
local totalsKeys={move=true,ranged=true,siege=true,attack=true,block=true,influence=true,healing=true}

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

local resourceFieldForCategory={
    move="move",ranged="physical",siege="physical",attack="physical",
    block="physical",influence="generated",healing="healing"
}

function resourceCardsEffectiveValue(category,field)
    local tracker=gStates~=nil and gStates.resourceTracker or nil
    local manual=tracker~=nil and tracker[category]~=nil and tracker[category][field] or 0
    local totals=resourceCardsCurrentTotals()
    local estimated=totals~=nil and resourceFieldForCategory[category]==field and (totals[category] or 0) or 0
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


local choiceLetters={move="M",influence="I",attack="A",block="B",
    ranged="R",siege="S",healing="H",draw="D"}

local function sideChoices(rule,powered)
    return rule~=nil and (powered and rule.poweredChoices or rule.normalChoices) or nil
end

local function choiceCategory(choice)
    for category in pairs(choice) do return category end
    return nil
end

local function chosenEffect(guid,powered,choices)
    if choices==nil then return nil end
    local choice=selectedResourceByGUID[guid]
    local category=choice~=nil and choice[powered and "powered" or "normal"] or nil
    if category==nil then return nil end
    for _,value in ipairs(choices) do
        if value[category]~=nil then return value end
    end
    return nil
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

local function showChoiceButtons(card,choices,powered)
    if card==nil then return end
    if choices==nil or #choices<2 or card.is_face_down==true or cardIsSideways(card) then
        if choiceButtonShown[card.guid]~=nil then removeChoiceButtons(card) end
        return
    end
    local selection=selectedResourceByGUID[card.guid]
    local chosen=selection~=nil and selection[powered and "powered" or "normal"] or nil
    local layout={}
    local seen={}
    for _,choice in ipairs(choices) do
        local category=choiceCategory(choice)
        if category~=nil and choiceLetters[category]~=nil and not seen[category] then
            seen[category]=true
            layout[#layout+1]=category
        end
    end
    if #layout<2 then
        if choiceButtonShown[card.guid]~=nil then removeChoiceButtons(card) end
        return
    end
    local signature=(powered and "P" or "N")..":"..(chosen or "")..":"..table.concat(layout,",")
    if choiceButtonShown[card.guid]==signature then return end
    local xml=card.UI.getXmlTable() or {}
    for i=#xml,1,-1 do
        local attr=xml[i].attributes
        if attr~=nil and type(attr.id)=="string"
            and attr.id:sub(1,19)=="ResourceCardChoice_" then table.remove(xml,i) end
    end
    -- Card-UI coordinates, matched to createClaimButton/Meditation (same -10 height).
    -- Approx. 36 visual units per square, centred across the illustration.
    for i,category in ipairs(layout) do
        local x=(i-(#layout+1)/2)*66
        local active=(category==chosen)
        xml[#xml+1]={tag="Button",attributes={
            id="ResourceCardChoice_"..card.guid.."_"..category,
            onClick="global/resourceCardsChoiceClicked",
            position=tostring(x).." -88 -10",rotation="0 0 180",
            width=115,height=115,scale="0.30 0.30",
            colors=active and "#387D30|#4CA940|#387D30|#387D30"
                or "#454D5D|#69798E|#444C63|#454D5D",
            text=choiceLetters[category],fontSize=77,textColor="#FFFFFF"
        }}
    end
    card.UI.setXmlTable(xml)
    choiceButtonShown[card.guid]=signature
end

local function clearChoiceButtons()
    for guid in pairs(choiceButtonShown) do
        removeChoiceButtons(getObjectFromGUID(guid))
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

local function cardIsSideways(card)
    local y=card.getRotation()[2]%180
    return y>25 and y<155
end

-- A powered link grants a target Action card its strong side for free and can
-- amend only the resource types specified in that link's data definition.
local function applyLinkedResourceBonus(effects,link)
    if effects==nil or link==nil then return effects end
    local values={}
    for category,value in pairs(effects) do
        if type(value)=="number" then
            local bonus=link.bonusFor~=nil and link.bonusFor[category] and (link.bonus or 0) or 0
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
    local faceUp=card.is_face_down~=true and cardIsSideways(card)==false
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
    local status=(not known or not sideTracked) and "red"
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
    local function nearestOverlap(source,valid)
        local best,bestArea=nil,0
        local a=footprints[source.guid]
        for _,target in ipairs(cards) do
            if target.guid~=source.guid and valid(target) then
                local area=overlapArea(a,footprints[target.guid])
                if area>bestArea or (area==bestArea and best~=nil and target.guid<best.guid) then
                    best,bestArea=target,area
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
            and not cardIsSideways(source) then
            local target=nearestOverlap(source,function(candidate)
                local other=gameCards[candidate.guid]
                local otherRule=other~=nil and cardResourceDefinitions[other.resourceKey] or nil
                return not boostClaimed[candidate.guid] and other~=nil
                    and (other.cardType=="Starting" or other.cardType=="Advanced Action")
                    and (otherRule==nil or otherRule.poweredLink==nil)
                    and candidate.is_face_down~=true and not cardIsSideways(candidate)
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
            and source.is_face_down~=true and not cardIsSideways(source) then
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
                    and not cardIsSideways(candidate)
            end)
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
        showChoiceButtons(card,discarded[card.guid]==nil and sideChoices(rule,result.powered) or nil,result.powered)
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
            if choiceButtonShown[guid]~=nil then removeChoiceButtons(getObjectFromGUID(guid)) end
            selectedResourceByGUID[guid]=nil
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
    selectedResourceByGUID={}
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
    if card==nil or rule==nil then return end
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
    local choices=sideChoices(rule,powered)
    local valid=false
    for _,choice in ipairs(choices or {}) do
        if choice[category]~=nil then valid=true break end
    end
    if not valid then return end
    local selected=selectedResourceByGUID[guid] or {}
    selected[powered and "powered" or "normal"]=category
    selectedResourceByGUID[guid]=selected
    queueSeat(currentSeat.seatPos,nil)
end

function resourceCardsPanelChanged(open)
    -- The tracker shows the current turn's Mage Knight; stale outlines on other
    -- players' boards would falsely imply those pieces contribute to these totals.
    clearAll()
    if open~=true then return end
    local player=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    if player~=nil then queueSeat(player.seatPos,nil) end
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

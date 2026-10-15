-- The physical play area supplies estimated resources to the Resource Tracker.
-- Runtime-only observations never overwrite the saved manual +/- adjustments.
resourceCardScanBySeat={}
local generation={}
local shown={}
local bySeat={}
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

-- Hovering over each main Resource Tracker total lists the actual physical
-- cards behind the estimate. GUIDs distinguish otherwise identical copies.
function resourceCardsSourceTooltip(category)
    local lines={}
    local scan=resourceCardsPanelOpen() and resourceCardsCurrentTotals() or nil
    local active=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    local records=active~=nil and resourceCardScanBySeat[active.seatPos] or nil
    if scan~=nil and records~=nil then
        for guid,record in pairs(records.cards) do
            local value=record.resources~=nil and record.resources[category] or nil
            if type(value)=="number" and value~=0 then
                local card=gameCards[guid]
                local label=card~=nil and card.name~=nil and card.name[1] or record.kind or "Card"
                local state=record.powered and " (powered)" or ""
                local partial=record.complete==false and " (partial)" or ""
                lines[#lines+1]=tostring(label).." ["..guid.."]"..state..partial
                    ..": "..(value>0 and "+" or "")..tostring(value)
            end
        end
    end
    table.sort(lines)
    if #lines==0 then lines[1]="No recognised effects calculated" end
    local manual=0
    local values=gStates~=nil and gStates.resourceTracker~=nil and gStates.resourceTracker[category] or nil
    if values~=nil then
        for _,value in pairs(values) do manual=manual+value end
    end
    return "Calculated sources:\n"..table.concat(lines,"\n")
        .."\nManual / base: "..tostring(manual)
        .."\nYellow = additional effects not yet understood."
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
    obj.highlightOn(palette[kind][powered and 2 or 1],0)
    shown[obj.guid]=choice
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

local function calculateCard(card,powered,linked)
    local data=gameCards[card.guid]
    local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
    local known=data~=nil
    local faceUp=card.is_face_down~=true and cardIsSideways(card)==false
    local complete=rule~=nil and rule.partial~=true and faceUp
    -- A known fixed component can contribute to the estimate even when the card's
    -- additional rules are still unimplemented. Unresolved choices contribute nothing.
    local effects=faceUp and rule~=nil and (powered and rule.powered or rule.normal) or nil
    local kind=not known and "red" or not complete and "yellow" or "green"
    if #linked>0 then kind="purple" end
    return {guid=card.guid,known=known,complete=complete,powered=powered,
        links=linked,status=kind,resources=effects}
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

    local links,powered,usedMana={}, {}, {}
    for _,card in ipairs(cards) do links[card.guid]={} end
    for i=1,#cards do
        for j=i+1,#cards do
            local a,b=cards[i],cards[j]
            if overlaps(footprints[a.guid],footprints[b.guid]) then
                links[a.guid][#links[a.guid]+1]=b.guid
                links[b.guid][#links[b.guid]+1]=a.guid
            end
        end
    end

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

    local current,records,totals={}, {}, {}
    for _,card in ipairs(cards) do
        local result=calculateCard(card,powered[card.guid]==true,links[card.guid])
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
        if current[guid]~=true then clearHighlight(guid) end
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
    for guid in pairs(shown) do clearHighlight(guid) end
    bySeat={}
    resourceCardScanBySeat={}
    -- Manual Resource Tracker adjustments are never changed by clearing estimates.
    if gStates~=nil and gStates.resourceTracker~=nil then
        refreshResourceTrackerText()
        updateMoveDisplay()
    end
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

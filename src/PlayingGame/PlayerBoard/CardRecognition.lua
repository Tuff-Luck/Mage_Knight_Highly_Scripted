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

local function inspectable(obj)
    return obj~=nil and (obj.type=="Card" or obj.type=="Dice" or isManaTokenFigurine(obj))
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

local function renderSeat(seatPos)
    if not resourceCardsPanelOpen() then return end
    local zone=getObjectFromGUID(playerPlayAreas[seatPos])
    if zone==nil then return end
    local cards,resources,footprints={}, {}, {}
    for _,obj in ipairs(zone.getObjects()) do
        if obj.type=="Card" then
            cards[#cards+1]=obj
            footprints[obj.guid]=footprint(obj)
        elseif inspectable(obj) then
            resources[#resources+1]=obj
        end
    end
    local links,powered={},{}
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
    -- Assign a placed mana object to the closest card it actually lies on.
    for _,mana in ipairs(resources) do
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
            if best~=nil then powered[best.guid]=true end
        end
    end
    local current={}
    local records={}
    local totals={}
    for _,card in ipairs(cards) do
        local guid=card.guid
        current[guid]=true
        local result=calculateCard(card,powered[guid]==true,links[guid])
        records[guid]=result
        setHighlight(card,result.status,result.powered)
        -- Even linked cards have their own base effect. Unknown interactions add no bonus yet.
        -- The Resource Tracker combines these estimates with manual adjustments at display time.
        if result.complete and result.resources~=nil then
            for category,value in pairs(result.resources) do
                if totalsKeys[category] then totals[category]=(totals[category] or 0)+value end
            end
        end
    end
    local previous=bySeat[seatPos] or {}
    local previousScan=resourceCardScanBySeat[seatPos]
    local previousMove=previousScan~=nil and (previousScan.totals.move or 0) or 0
    bySeat[seatPos]=current
    resourceCardScanBySeat[seatPos]={cards=records,totals=totals}
    local active=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
    if active~=nil and active.seatPos==seatPos then
        refreshResourceTrackerText()
        if previousMove~=(totals.move or 0) then updateMoveDisplay() end
    end
    for guid in pairs(previous) do
        if current[guid]~=true then
            local usedElsewhere=false
            for otherSeat,otherCards in pairs(bySeat) do
                if otherSeat~=seatPos and otherCards[guid]==true then usedElsewhere=true break end
            end
            if not usedElsewhere then clearHighlight(guid) end
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
    for guid in pairs(shown) do clearHighlight(guid) end
    bySeat={}
    resourceCardScanBySeat={}
    -- When the details close the automatic contribution disappears, but manual edits persist.
    if gStates~=nil and gStates.resourceTracker~=nil then
        refreshResourceTrackerText()
        updateMoveDisplay()
    end
end

function resourceCardsPanelChanged(open)
    if open~=true then clearAll() return end
    for seatPos=1,4 do queueSeat(seatPos,nil) end
end

function resourceCardsOnLoad()
    if resourceCardsPanelOpen() then resourceCardsPanelChanged(true) else clearAll() end
end

function resourceCardsZoneEntered(ctx)
    if ctx==nil or ctx.playerZoneKind~="play" or not inspectable(ctx.obj) then return end
    queueSeat(ctx.zoneInfo.seatPos,ctx.objGUID)
end

function resourceCardsZoneLeft(ctx)
    if ctx==nil or ctx.playerZoneKind~="play" or not inspectable(ctx.obj) then return end
    -- An exiting object is intentionally not waited on: it may still be held.
    queueSeat(ctx.zoneInfo.seatPos,nil)
end

function resourceCardsObjectMoved(obj)
    if not resourceCardsPanelOpen() or not inspectable(obj) then return end
    for seatPos=1,4 do
        local zone=getObjectFromGUID(playerPlayAreas[seatPos])
        if zone~=nil then
            local present=false
            for _,candidate in ipairs(zone.getObjects()) do
                if candidate.guid==obj.guid then present=true break end
            end
            if present or (bySeat[seatPos]~=nil and bySeat[seatPos][obj.guid]==true) then
                queueSeat(seatPos,present and obj.guid or nil)
            end
        end
    end
end

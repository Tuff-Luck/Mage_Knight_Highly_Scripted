-- A Command token remains one physical object, but can represent multiple
-- activations after a card/Unit readies its Unit. Each use owns its choices,
-- paid mana snapshot and combat source. The number on the token selects which
-- use the existing Unit-card buttons edit; it never changes the use count.
unitHistory=unitHistory or {}

local function groupOf(guid,create)
    if gStates==nil or guid==nil then return nil end
    gStates.unitActivationHistory=gStates.unitActivationHistory or {}
    local group=gStates.unitActivationHistory[guid]
    if group==nil and create then
        group={uses={},selected=1,awaiting=nil}
        gStates.unitActivationHistory[guid]=group
    end
    return group
end

function unitHistoryKey(guid,index)
    return index==1 and guid or (guid.."#use"..tostring(index))
end

function unitHistorySourceBase(key)
    return type(key)=="string" and key:match("^[^#]+") or key
end

function unitHistoryEnsure(guid,activation)
    local group=groupOf(guid,activation~=nil)
    if group~=nil and activation~=nil and #group.uses==0 then
        group.uses[1]=activation
        group.tokenGUID=activation.tokenGUID
        group.selected=1
    end
    return group
end

function unitHistoryUses(guid,activation)
    local group=unitHistoryEnsure(guid,activation)
    return group~=nil and group.uses or (activation~=nil and {activation} or {})
end

function unitHistorySelected(guid,activation)
    local group=unitHistoryEnsure(guid,activation)
    if group==nil or #group.uses==0 then return activation,1 end
    group.selected=math.max(1,math.min(#group.uses,tonumber(group.selected) or #group.uses))
    return group.uses[group.selected],group.selected
end

function unitHistorySelectedNumber(guid)
    local group=groupOf(guid)
    return group~=nil and group.selected or 1
end

function unitHistoryCopyCounts(counts)
    local copy={}
    for key,value in pairs(counts or {}) do copy[key]=value end
    return copy
end

-- A saved history is authoritative. In particular, a token sitting on a Unit
-- cannot tell us how many times that Unit was used earlier this turn.
function unitHistoryRestoreCurrent()
    if gStates==nil then return end
    gStates.unitResourceActivations=gStates.unitResourceActivations or {}
    for guid,group in pairs(gStates.unitActivationHistory or {}) do
        if type(group)=="table" and type(group.uses)=="table" and #group.uses>0 then
            group.selected=math.max(1,math.min(#group.uses,tonumber(group.selected) or #group.uses))
            gStates.unitResourceActivations[guid]=group.uses[#group.uses]
        end
    end
end

local function clearTokenControls(token)
    if token==nil or token.isDestroyed() then return end
    local buttons=token.getButtons() or {}
    for i=#buttons,1,-1 do
        local click=tostring(buttons[i].click_function or "")
        if click=="unitHistoryPrevious" or click=="unitHistoryNext"
            or click=="unitHistoryDisplay" then token.removeButton(buttons[i].index) end
    end
end

function unitHistoryRefreshToken(guid)
    local group=groupOf(guid)
    if group==nil or #group.uses==0 then return end
    local token=getObjectFromGUID(group.tokenGUID or group.uses[#group.uses].tokenGUID)
    if token==nil then return end
    clearTokenControls(token)
    local function add(click,label,x,width,font)
        token.createButton({click_function=click,function_owner=Global,
            label=label,position={x,0.27,0},rotation={0,0,0},
            width=width,height=190,font_size=font or 155,
            color={0.13,0.15,0.19,0.90},font_color={1,1,1,1},
            tooltip="Select a Unit activation to inspect or edit"})
    end
    add("unitHistoryDisplay",tostring(group.selected),0,190,180)
    if #group.uses>1 then
        add("unitHistoryPrevious","<",-0.31,115,140)
        add("unitHistoryNext",">",0.31,115,140)
    end
end

function unitHistoryDisplay(token,color)
    -- The displayed activation number is deliberately not an activation action.
end

local function cycle(token,color,delta)
    if token==nil or not resourceCardsPlayerCanEdit(color) then return end
    for guid,group in pairs(gStates~=nil and gStates.unitActivationHistory or {}) do
        if group.tokenGUID==token.guid and #group.uses>0 then
            local index=math.max(1,math.min(#group.uses,(group.selected or 1)+delta))
            if index==group.selected then return end
            group.selected=index
            unitHistoryRefreshToken(guid)
            if resourceUnitsRefreshButtons~=nil then resourceUnitsRefreshButtons() end
            if resourceCardsSourceChanged~=nil then resourceCardsSourceChanged() end
            return
        end
    end
end

function unitHistoryPrevious(token,color)
    cycle(token,color,-1)
end

function unitHistoryNext(token,color)
    cycle(token,color,1)
end

-- The first use is always keyed by the original GUID for compatibility with
-- existing skills and Unit links. Later combat resources use stable #useN keys.
function unitHistoryAppend(guid,activation,sourceKey)
    local group=groupOf(guid,true)
    local nextIndex=#group.uses+1
    activation.readiedBy=sourceKey
    activation.useIndex=nextIndex
    group.uses[nextIndex]=activation
    group.selected=nextIndex
    group.tokenGUID=activation.tokenGUID
    group.awaiting=nil
    gStates.unitResourceActivations[guid]=activation
    local link=gStates.unitReadyLinks and gStates.unitReadyLinks[sourceKey]
    if link~=nil then link.usedBy=nextIndex end
    unitHistoryRefreshToken(guid)
    return nextIndex
end

-- Store mana at the moment the Command token leaves its Unit. Earlier paid
-- effects must not change when their crystals are later moved elsewhere.
function unitHistoryFreeze(guid,counts)
    local group=groupOf(guid)
    local use=group~=nil and group.uses[#group.uses] or nil
    if use~=nil and use.frozenCounts==nil then
        use.frozenCounts=unitHistoryCopyCounts(counts or use.lastCounts)
    end
end

local function unlinkSource(sourceKey)
    if gStates==nil or gStates.unitReadyLinks==nil then return end
    local link=gStates.unitReadyLinks[sourceKey]
    if link==nil then return end
    gStates.unitReadyLinks[sourceKey]=nil
    local group=groupOf(link.unitGUID)
    if group~=nil and link.usedBy~=nil then
        unitHistoryTrim(link.unitGUID,link.usedBy-1)
    elseif group~=nil and group.awaiting==sourceKey then
        group.awaiting=nil
    end
end

-- Undo from the most recent use backwards, retiring dependent ready links.
-- Never remove a different use's combat targeting merely because it has
-- the same physical Unit GUID.
function unitHistoryTrim(guid,keep)
    local group=groupOf(guid)
    if group==nil then return end
    keep=math.max(0,math.min(#group.uses,keep or 0))
    for i=#group.uses,keep+1,-1 do
        local entry=group.uses[i]
        local key=unitHistoryKey(guid,i)
        group.uses[i]=nil
        if entry~=nil and entry.readiedBy~=nil then
            local link=gStates.unitReadyLinks and gStates.unitReadyLinks[entry.readiedBy]
            if link~=nil and link.unitGUID==guid then
                link.usedBy=nil
            end
        end
        for readyKey in pairs(gStates.unitReadyLinks or {}) do
            if readyKey==key then unlinkSource(readyKey) end
        end
        if resourceCardsCombatForgetSource~=nil then resourceCardsCombatForgetSource(key) end
        if attackAssignmentsPruneSourceTargets~=nil then
            attackAssignmentsPruneSourceTargets(key,{})
        end
    end
    group.selected=math.max(1,math.min(keep,group.selected or keep))
    group.awaiting=nil
    if keep==0 then
        gStates.unitResourceActivations[guid]=nil
        gStates.unitActivationHistory[guid]=nil
        local token=getObjectFromGUID(group.tokenGUID)
        clearTokenControls(token)
    else
        gStates.unitResourceActivations[guid]=group.uses[keep]
        unitHistoryRefreshToken(guid)
    end
end

function unitHistoryReadyLink(sourceKey,unitGUID,seat,levelLimit)
    if gStates==nil or sourceKey==nil or unitGUID==nil then return false end
    local group=groupOf(unitGUID)
    if group==nil or #group.uses==0 or group.awaiting~=nil then return false end
    local unit=getObjectFromGUID(unitGUID)
    local data=gameCards~=nil and gameCards[unitGUID] or nil
    if unit==nil or (levelLimit~=nil and (data==nil or data.level>levelLimit))
        or (resourceCardsReadySourceValid~=nil
            and not resourceCardsReadySourceValid(sourceKey,seat)) then return false end
    -- A ready effect can be retargeted before it is consumed. Undo its old
    -- dependent activations before linking it to a different Unit.
    unlinkSource(sourceKey)
    gStates.unitReadyLinks=gStates.unitReadyLinks or {}
    gStates.unitReadyLinks[sourceKey]={unitGUID=unitGUID,seatPos=seat,
        afterUse=#group.uses,limit=levelLimit}
    return true
end

function unitHistoryReadyPermission(guid)
    local group=groupOf(guid)
    if group==nil or gStates==nil then return nil end
    for key,link in pairs(gStates.unitReadyLinks or {}) do
        if link.unitGUID==guid and link.usedBy==nil
            and link.afterUse==#group.uses
            and (resourceCardsReadySourceValid==nil
                or resourceCardsReadySourceValid(key,link.seatPos)) then
            return key
        end
    end
    return nil
end

function unitHistoryMarkReady(guid,sourceKey,counts)
    local group=groupOf(guid)
    if group==nil or sourceKey==nil then return false end
    unitHistoryFreeze(guid,counts)
    group.awaiting=sourceKey
    unitHistoryRefreshToken(guid)
    return true
end

function unitHistoryAwaiting(guid)
    local group=groupOf(guid)
    return group~=nil and group.awaiting or nil
end

function unitHistoryUndoLatest(guid)
    local group=groupOf(guid)
    if group==nil then return end
    unitHistoryTrim(guid,#group.uses-1)
end

function unitHistoryCancelReadySource(sourceKey)
    unlinkSource(sourceKey)
    if attackAssignmentsRefreshReadyUI~=nil then attackAssignmentsRefreshReadyUI() end
end

function unitHistoryValidSources(seat)
    for key,link in pairs(gStates~=nil and gStates.unitReadyLinks or {}) do
        if link.seatPos==seat and resourceCardsReadySourceValid~=nil
            and not resourceCardsReadySourceValid(key,seat) then
            local obj=getObjectFromGUID(unitHistorySourceBase(key))
            if obj==nil or (obj.held_by_color==nil
                and not obj.isSmoothMoving()) then unlinkSource(key) end
        end
    end
end

function unitHistoryHideControls()
    for _,group in pairs(gStates~=nil and gStates.unitActivationHistory or {}) do
        clearTokenControls(getObjectFromGUID(group.tokenGUID))
    end
end

function unitHistoryReset()
    if gStates==nil then return end
    for _,group in pairs(gStates.unitActivationHistory or {}) do
        clearTokenControls(getObjectFromGUID(group.tokenGUID))
    end
    gStates.unitActivationHistory={}
    gStates.unitReadyLinks={}
end

-- Immutable terrain definitions and collection policy. Do not copy individual
-- modifiers: the published scan compares their identity to avoid redraws.
local M={}
function M.side(rule,powered)
    if rule==nil or rule.terrainEffects==nil then return nil end
    if powered then return rule.terrainEffects.powered end
    return rule.terrainEffects.normal
end

function M.active(effect,dayRound)
    return effect.dayRound==nil or effect.dayRound==(dayRound==true)
end

function M.append(target,effects,dayRound,repeatCount)
    for _=1,(repeatCount or 1) do
        for _,effect in ipairs(effects or {}) do
            if M.active(effect,dayRound) then
                target[#target+1]=effect
            end
        end
    end
end

function M.stage(record,effects,dayRound,repeatCount)
    local pending=record.pendingTerrainModifiers or {}
    M.append(pending,effects,dayRound,repeatCount)
    if #pending>0 then record.pendingTerrainModifiers=pending end
end

function M.passive(target,rule,dayRound)
    M.append(target,rule.passiveTerrain,dayRound)
    M.append(target,dayRound==true and rule.passiveDayTerrain or
        (dayRound~=true and rule.passiveNightTerrain or nil),dayRound)
end

function M.movementEligible(record,guid,moveRole)
    return record.independentTerrain==true
        or ((tonumber(record.resources~=nil and record.resources.move) or 0)>0
            and moveRole(guid,false)=="movement")
end

-- Selected terrain discounts use stable rule instances across scans.
local selected={}
for _,terrain in ipairs({"plains","hills","forest","wasteland","desert",
    "swamp","lake","mountain","city"}) do
    selected[terrain]={mode="reduce",terrains={[terrain]=true},amount=1,minimum=2}
end
M.selectedTerrainDiscounts=selected

-- Keep the same ordering for active and minimized terrain overlays.
local order={set=0,cap=1,reduce=2}
function M.precedes(a,b)
    local first,second=order[a.mode] or 9,order[b.mode] or 9
    if first~=second then return first<second end
    if a.mode=="reduce" then return (a.minimum or 0)>(b.minimum or 0) end
    return false
end

local passable={plains=true,hills=true,forest=true,wasteland=true,desert=true,
    swamp=true,lake=true,mountain=true}
local function applies(effect,terrain)
    return effect.terrains=="passable" and passable[terrain]==true
        or effect.terrains=="weather" and (passable[terrain]==true or terrain=="city")
        or type(effect.terrains)=="table" and effect.terrains[terrain]==true
end

function M.cost(base,terrain,effects)
    if effects==nil then return base end
    local setCost=nil
    -- Published scans are already sorted. Only copy/sort if a standalone
    -- caller supplies unsorted modifiers (e.g. passive-only exploration).
    local previous,needsSort=nil,false
    for _,effect in ipairs(effects) do
        if effect.mode=="set" and applies(effect,terrain) then
            setCost=setCost==nil and effect.cost or math.min(setCost,effect.cost)
        elseif effect.mode=="cap" or effect.mode=="reduce" then
            if previous~=nil and M.precedes(effect,previous) then needsSort=true end
            previous=effect
        end
    end
    if setCost==nil and base>=900 then return base end
    local cost=setCost or base
    local ordered=effects
    if needsSort then
        ordered={}
        for _,effect in ipairs(effects) do ordered[#ordered+1]=effect end
        table.sort(ordered,M.precedes)
    end
    for _,effect in ipairs(ordered) do
        if applies(effect,terrain) then
            if effect.mode=="cap" then cost=math.min(cost,effect.cost)
            elseif effect.mode=="reduce" then
                cost=math.min(cost,math.max(effect.minimum or 0,cost-effect.amount))
            end
        end
    end
    -- Preserve the existing Weather order and apply it last.
    for _,effect in ipairs(effects) do
        if effect.mode=="weather" and applies(effect,terrain) then
            if effect.amount<0 then cost=math.max(1,cost+effect.amount)
            else cost=math.min(5,cost+effect.amount) end
        end
    end
    return cost
end

return M

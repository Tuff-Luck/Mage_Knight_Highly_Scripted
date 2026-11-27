-- Pure resource-key and live-record operations. Printed catalog tables are immutable.
local M={}
local suffixes={"ColdFire","Fire","Ice","Psychic"}
local combatFamilies={attack=true,ranged=true,siege=true}
local elementalFamilies={attack=true,ranged=true,siege=true,block=true}

function M.splitKey(key)
    for _,suffix in ipairs(suffixes) do
        if #key>#suffix and key:sub(-#suffix)==suffix then
            return key:sub(1,#key-#suffix),suffix
        end
    end
    return key,""
end

function M.changeFamily(key,family)
    local _,suffix=M.splitKey(key)
    -- Movement has no element; converting from Move starts physical.
    return family=="move" and "move" or family..suffix
end

function M.addElement(key,element)
    local family,suffix=M.splitKey(key)
    if not elementalFamilies[family] then return nil end
    if element~="Fire" and element~="Ice" then return nil end
    if suffix=="" then return family..element end
    if (suffix=="Fire" and element=="Ice") or (suffix=="Ice" and element=="Fire") then
        return family.."ColdFire"
    end
    return nil
end

function M.globalAttackKey(key,transform)
    if transform==nil or (not transform.coldFire and not transform.siege) then return key end
    local family,suffix=M.splitKey(key)
    if not combatFamilies[family] then return key end
    if transform.siege then family="siege" end
    if transform.coldFire then suffix="ColdFire" end
    return family..suffix
end

-- A link to one printed effect cannot silently choose between several
-- positive resource fields. Family matching is exact, including elements.
function M.uniqueField(resources,families)
    local found
    for field,amount in pairs(resources or {}) do
        if type(field)=="string" and type(amount)=="number" and amount>0
            and families[M.splitKey(field)] then
            if found~=nil then return nil end
            found=field
        end
    end
    return found
end

-- One-source Attack bonuses follow the source through element and family
-- conversions. Resolve their actual value in the consuming combat phase,
-- rather than creating a second independently targetable attack.
function M.linkAttackBonus(record,field,spec)
    record.phaseAttackBoosts=record.phaseAttackBoosts or {}
    local bonuses=record.phaseAttackBoosts[field] or {}
    bonuses[#bonuses+1]=spec
    record.phaseAttackBoosts[field]=bonuses
end

function M.effectivePhaseAttackBoosts(record,transform)
    if record.phaseAttackBoosts==nil then return nil end
    local effective={}
    for field,bonuses in pairs(record.phaseAttackBoosts) do
        local key=M.globalAttackKey(field,transform)
        local list=effective[key] or {}
        for _,bonus in ipairs(bonuses) do list[#list+1]=bonus end
        effective[key]=list
    end
    return effective
end

function M.phaseAttackBonus(source,field,phase,asFamily)
    if source.phaseAttackBoosts==nil or field==nil then return 0 end
    local amount=tonumber((source.resources or {})[field]) or 0
    if amount<=0 then return 0 end
    local family,element=M.splitKey(field)
    local bonus=0
    for _,spec in ipairs(source.phaseAttackBoosts[field] or {}) do
        if not spec.physicalOnly or element=="" then
            bonus=bonus+(phase=="attack" and spec.late
                or (spec.early or {})[asFamily or family] or 0)
        end
    end
    return bonus
end

-- Preview each source in its printed/effective phase for the Resource
-- Tracker; the Combat Calculator uses its actually allocated phase instead.
-- Do not inject preview values into the underlying spendable resource pool.
function M.previewAttackBonuses(records,transform)
    local totals={}
    for _,record in pairs(records) do
        if record.phaseAttackBoosts~=nil then
            local effective={resources={},phaseAttackBoosts=M.effectivePhaseAttackBoosts(record,transform)}
            for field,amount in pairs(record.resources or {}) do
                if type(field)=="string" and type(amount)=="number" then
                    local key=M.globalAttackKey(field,transform)
                    effective.resources[key]=(effective.resources[key] or 0)+amount
                end
            end
            for field in pairs(effective.phaseAttackBoosts) do
                local family=M.splitKey(field)
                local phase=family=="attack" and "attack" or "range"
                totals[field]=(totals[field] or 0)+M.phaseAttackBonus(effective,field,phase)
            end
        end
    end
    return totals
end

function M.fixedShapeshiftAmount(record,field)
    local value=tonumber((record.resources or {})[field]) or 0
    -- Cold Toughness may convert its printed Block 5, never the extra
    -- Block generated from the enemy's attack icons.
    if M.splitKey(field)=="block" then
        value=value-(record.variableEnemyBlockBonus or 0)
    end
    return math.max(0,value)
end

local function copyResources(record)
    local copy={}
    for key,value in pairs(record.resources) do copy[key]=value end
    return copy
end

-- The caller supplies an already published, eligible resource record. These
-- operations adjust only that record and its scan totals, not links, payment,
-- contribution flags, highlights, target locks or effect ordering.
function M.addAmounts(record,totals,amounts)
    local copy=copyResources(record)
    for field,amount in pairs(amounts) do
        copy[field]=(copy[field] or 0)+amount
        totals[field]=(totals[field] or 0)+amount
    end
    record.resources=copy
end
function M.add(record,totals,field,amount)
    M.addAmounts(record,totals,{[field]=amount})
end

-- A modifier of one Block increases the first repeated Block, not every
-- printed copy (Shield of the Fallen Kings). Preserve the existing split
-- metadata consumed by the calculator and exact Block solver.
function M.addSingleBlockBonus(record,totals,field,amount)
    M.add(record,totals,field,amount)
    if (tonumber(record.repeatBlocks) or 1)>1 then
        record.ambushFirstBlockBonus=(record.ambushFirstBlockBonus or 0)+amount
    end
end

-- Replace the complete original field. An omitted amount preserves its value;
-- an explicit amount supports a conversion with a bonus (e.g. Leadership).
function M.replace(record,totals,from,to,amount)
    local copy=copyResources(record)
    local old=copy[from] or 0
    if amount==nil then amount=old end
    copy[from]=nil
    copy[to]=(copy[to] or 0)+amount
    record.resources=copy
    totals[from]=(totals[from] or 0)-old
    totals[to]=(totals[to] or 0)+amount
    if from~=to and record.phaseAttackBoosts~=nil then
        local bonuses=record.phaseAttackBoosts[from]
        if bonuses~=nil then
            record.phaseAttackBoosts[from]=nil
            if combatFamilies[M.splitKey(to)] then
                for _,bonus in ipairs(bonuses) do M.linkAttackBonus(record,to,bonus) end
            end
        end
    end
end

-- Record the scan-local share of generated Influence already paid for
-- non-combat effects. Keep printed/resource values intact for card controls.
-- Stable source order keeps the same remaining combat pool across rescans.
function M.allocateInfluenceSpend(records,amount)
    local ordered={}
    for key,record in pairs(records) do
        record.influenceSpent=nil
        if (tonumber((record.resources or {}).influence) or 0)>0 then
            ordered[#ordered+1]=key
        end
    end
    table.sort(ordered)
    local remaining=math.max(0,tonumber(amount) or 0)
    for _,key in ipairs(ordered) do
        if remaining<=0 then break end
        local record=records[key]
        local spent=math.min(remaining,record.resources.influence)
        record.influenceSpent=spent
        remaining=remaining-spent
    end
    return remaining
end

return M

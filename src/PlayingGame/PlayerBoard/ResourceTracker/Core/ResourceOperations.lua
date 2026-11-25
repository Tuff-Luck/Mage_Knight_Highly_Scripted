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
end

return M

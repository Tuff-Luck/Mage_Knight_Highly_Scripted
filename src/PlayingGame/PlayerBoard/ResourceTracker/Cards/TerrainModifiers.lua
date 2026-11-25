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

return M

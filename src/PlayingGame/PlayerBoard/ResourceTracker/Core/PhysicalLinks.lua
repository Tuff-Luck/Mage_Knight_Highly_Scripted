-- Select a unique physical link from already eligible candidates.
-- Eligibility, payment and explicit targeting belong to the calling effect.
local M={}

-- Each candidate has an overlap area (zero means no physical overlap).
-- Some effects explicitly permit a sole eligible remote target.
-- A tie at the highest positive area is ambiguous, regardless of order.
function M.unique(candidates,allowSingleRemote)
    if allowSingleRemote and #candidates==1 then return candidates[1] end
    local best,bestArea,tied=nil,0,false
    for _,candidate in ipairs(candidates) do
        local area=candidate.overlap
        if area>bestArea then
            best,bestArea,tied=candidate,area,false
        elseif area==bestArea and area>0 then
            tied=true
        end
    end
    if tied then return nil end
    return best
end

return M

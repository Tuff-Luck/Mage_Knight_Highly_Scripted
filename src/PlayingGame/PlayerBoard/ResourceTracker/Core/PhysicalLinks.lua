-- Shared physical overlap ranking. Eligibility and payment ownership
-- stay with callers. Single-effect links reject equal best overlaps;
-- ordered cost allocation deliberately uses a stable GUID tie break.
local M={}
local function compare(a,b)
    local ap,bp=a.priority or 0,b.priority or 0
    if ap~=bp then return ap>bp and 1 or -1 end
    if a.overlap~=b.overlap then return a.overlap>b.overlap and 1 or -1 end
    return 0
end
function M.unique(candidates,allowSingleRemote)
    if allowSingleRemote and #candidates==1 then return candidates[1] end
    local best,tied=nil,false
    for _,candidate in ipairs(candidates) do
        if candidate.overlap>0 then
            local rank=best==nil and 1 or compare(candidate,best)
            if rank>0 then best,tied=candidate,false
            elseif rank==0 then tied=true end
        end
    end
    if tied then return nil end
    return best
end
-- Deterministic ordering is only for deliberately allocated claims.
function M.precedes(a,b)
    local rank=compare(a,b)
    if rank~=0 then return rank>0 end
    if a.tieKey~=b.tieKey then return a.tieKey<b.tieKey end
    return (a.secondaryKey or "")<(b.secondaryKey or "")
end
function M.ordered(candidates)
    local best=nil
    for _,candidate in ipairs(candidates) do
        if candidate.overlap>0 and (best==nil or M.precedes(candidate,best)) then best=candidate end
    end
    return best
end
return M

-- Semantic resource highlights. Brightness, lifecycle and actual TTS
-- highlight calls remain with the coordinator and the current object owner.
local M={}
function M.contribution(contributes)
    return contributes and "green" or "blue"
end
function M.certainty(recognized,complete)
    if not recognized then return "blue" end
    return complete and "green" or "yellow"
end
function M.linkedSource(record)
    record.status="purple"
end
-- A bonus to an activated Unit does not change its activation color
-- or acquire ownership of the currently displayed historical use.
function M.linkedTarget(record)
    if record.kind=="unit" then return false end
    M.linkedSource(record)
    return true
end
-- Dynamic Skill contributors may also be Units that are NOT activated.
function M.dynamicUnit(activated,contributes)
    if activated then return M.contribution(contributes),false end
    return "purple",true
end
return M

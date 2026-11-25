-- Shared enemy-effect source bookkeeping; actual rules and immunity remain
-- in CombatEffects. The caller owns eligibility, timing and completion.
local M={}
local highlightPolicy=require("PlayingGame.PlayerBoard.ResourceTracker.Core.HighlightPolicy")
function M.register(record,key)
    record.enemyEffectTargetKeys=record.enemyEffectTargetKeys or {}
    for _,existing in ipairs(record.enemyEffectTargetKeys) do
        if existing==key then return end
    end
    record.enemyEffectTargetKeys[#record.enemyEffectTargetKeys+1]=key
end
function M.target(record,key,guid)
    record.enemyEffectTargetGUIDs=record.enemyEffectTargetGUIDs or {}
    record.enemyEffectTargetGUIDs[key]=guid
end
-- Do not merge repeated effects on the same enemy or assume immunity means
-- that a target is absent. Units retain their own activation highlight.
function M.link(record,key,guid,policy)
    if policy.primary=="replace" then
        record.enemyGUID=guid
    elseif policy.primary=="first" then
        record.enemyGUID=record.enemyGUID or guid
    end
    if key~=nil then M.target(record,key,guid) end
    record.links[#record.links+1]=guid
    if policy.purple then highlightPolicy.linkedSource(record) end
    if policy.complete then record.complete=true end
end
return M

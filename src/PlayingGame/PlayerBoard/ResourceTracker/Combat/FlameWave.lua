-- Flame Wave resources depend on enemies surviving the Ranged/Siege phase.
-- Operates on fresh source records; preview Armour must not leak into real combat entries.
return function(combatApplyDefend,collectGroup,combatRangeGroupEntry,combatRangeResult)
    local function apply(entries,groups,allocated,sources)
        -- Flame Wave counts only enemies still faced in the Block/Attack phase.
        -- Resolve the Ranged/Siege preview (including Defender) first: summoned
        -- tokens and attack-only reminders are already excluded from entries.
        local flameWaveActive=false
        for _,source in ipairs(sources) do
            if source.flameWave then flameWaveActive=true break end
        end
        if flameWaveActive then
            local preview={}
            for i,entry in ipairs(entries) do
                local copy={}
                for key,value in pairs(entry) do copy[key]=value end
                preview[i]=copy
            end
            combatApplyDefend(preview,groups,allocated)
            local remaining=0
            for _,group in ipairs(groups) do
                local members,rangeSources=collectGroup(group,preview,allocated)
                local _,_,rangeDefeated=combatRangeResult(combatRangeGroupEntry(members),rangeSources)
                if not rangeDefeated then
                    for _,member in ipairs(members) do
                        if not member.attackOnly and not member.destroyed then
                            remaining=remaining+1
                        end
                    end
                end
            end
            for _,source in ipairs(sources) do
                if source.flameWave then
                    local key=source.resources.attackFire~=nil and "attackFire"
                        or (source.resources.blockFire~=nil and "blockFire" or nil)
                    if key~=nil then
                        local base=key=="attackFire" and 5 or 7
                        local amount=base+2*remaining
                        local previous=source.resources[key] or 0
                        local family=key=="attackFire" and "attack" or "block"
                        source.resources[key]=amount
                        source[family]=source[family]-previous+amount
                        for _,detail in ipairs(source.details) do
                            if detail.key==key then
                                detail.amount=amount
                                detail.text=(family=="attack" and "Fire Attack " or "Fire Block ")
                                    ..tostring(amount)
                            end
                        end
                    end
                end
            end
        end
    end

    return apply
end

-- Select payable Unit abilities and preserve an activation's existing choice.
-- The caller owns activation history and supplies the live mana policy/counts.
-- Only the existing lastPaidIndex and manaChoice bookkeeping is mutated here.
return function(deps)
    local unitManaCounts=deps.unitManaCounts
    local unitManaSignature=deps.unitManaSignature
    local unitAbilityPaid=deps.unitAbilityPaid
    local resourceCardsGoldAllowed=deps.resourceCardsGoldAllowed

    local function unitManaDecision(unit,abilities,activation,counts)
        -- A Command exhausted on a previous turn can be readied now, but that
        -- earlier use is not an ability in this turn's resource calculation.
        if activation.priorTurnSpent==true
            or (activation.bannerFearSelected==true
                and abilities.bannerFearIndex==nil) then
            -- Losing the Banner cannot retroactively turn its spent FEAR
            -- activation into a printed Attack or Block.
            return {index=nil,display={},ambiguous=false,selected={}}
        end
        counts=counts or unitManaCounts(unit,activation.seatPos)
        local signature=unitManaSignature(counts)
        local free,paid,direct,goldOnly={},{},{},{}
        for index,ability in ipairs(abilities) do
            if ability.manaCost==nil then
                free[#free+1]=index
            elseif unitAbilityPaid(ability,counts) then
                paid[#paid+1]=index
                if (counts[ability.manaCost] or 0)>0 then
                    direct[#direct+1]=index
                else
                    goldOnly[#goldOnly+1]=index
                end
            end
        end
        local result={index=nil,display={},ambiguous=false,
            signature=signature}
        local fearIndex=abilities.bannerFearIndex
        if fearIndex~=nil and activation.choice==fearIndex
            and activation.bannerFearSelected==true then
            result.index=fearIndex
            result.selected={[fearIndex]=true}
            result.display={fearIndex}
            for _,index in ipairs(paid) do result.display[#result.display+1]=index end
            for _,index in ipairs(free) do
                if index~=fearIndex then result.display[#result.display+1]=index end
            end
            return result
        end
        if abilities.multi==true then
            local chosen={}
            for _,index in ipairs(direct) do chosen[index]=true end
            local goldCount=resourceCardsGoldAllowed() and (counts.Gold or 0) or 0
            if #goldOnly<=goldCount then
                for _,index in ipairs(goldOnly) do chosen[index]=true end
            elseif goldCount>0 then
                result.ambiguous=true
                result.display=goldOnly
                local remaining=goldCount
                if activation.manaSignature==signature then
                    for _,index in ipairs(goldOnly) do
                        if activation.selected~=nil and activation.selected[index]==true
                            and remaining>0 then
                            chosen[index]=true
                            remaining=remaining-1
                        end
                    end
                end
            end
            result.selected=chosen
            if fearIndex~=nil then
                for _,index in ipairs(direct) do result.display[#result.display+1]=index end
                result.display[#result.display+1]=fearIndex
            end
            return result
        end
        if #paid==1 then
            -- An unambiguous paid ability stays active if another mana token later
            -- makes additional paid choices available.
            result.index=paid[1]
            activation.lastPaidIndex=result.index
            -- A previously selected paid effect no longer takes priority after
            -- another payment has made a different effect the only legal one.
            if activation.manaChoice~=nil and activation.manaChoice~=result.index then
                activation.manaChoice=nil
            end
        elseif #paid>1 then
            -- Adding mana must not discard an already valid paid choice or the
            -- corresponding Unit's existing enemy target. Prefer a manually chosen
            -- paid ability, then a previously active automatic one.
            result.ambiguous=true
            result.display=paid
            for _,index in ipairs(paid) do
                if activation.manaChoice==index then result.index=index break end
            end
            if result.index==nil then
                for _,index in ipairs(paid) do
                    if activation.lastPaidIndex==index then result.index=index break end
                end
            end
            if result.index==nil then
                -- Red Cape/Northern Monks: Attack 3 -> elemental Attack 4,
                -- Block 3 -> elemental Block 4. Only carry the choice forward
                -- when exactly ONE payable ability matches that family.
                local base=abilities[activation.choice]
                local family=base~=nil and base.key or nil
                if family~=nil and family~="other" and family~="gain"
                    and family~="ready" then
                    local matched,duplicates=nil,false
                    for _,index in ipairs(paid) do
                        if abilities[index].key==family then
                            if matched~=nil then duplicates=true break end
                            matched=index
                        end
                    end
                    if not duplicates then result.index=matched end
                end
            end
            if result.index~=nil then activation.lastPaidIndex=result.index end
        else
            -- Unpaid abilities stay hidden until matching mana is actually there.
            result.display=free
            for _,index in ipairs(free) do
                if activation.choice==index then result.index=index break end
            end
            if result.index==nil then result.index=free[1] end
        end
        if fearIndex~=nil and #paid>0 then
            if #paid==1 then result.display={paid[1]} end
            result.display[#result.display+1]=fearIndex
        end
        return result
    end

    return unitManaDecision
end

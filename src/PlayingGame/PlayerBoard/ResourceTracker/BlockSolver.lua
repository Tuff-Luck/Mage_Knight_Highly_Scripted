-- Exact Block/Move allocation over caller-supplied attacks and resources.
-- The caller owns source collection, caching, result rendering and phase commitments.
return function(combatConfig)
    -- Chooses which Block resources and Move reductions stop which attacks of one enemy so the least damage
    -- is taken. Every Block resource is used by at most one attack. Move only reduces Cumbersome attacks,
    -- one point each, and the reduction stands even when the rest of the attack cannot be blocked.
    -- Ties prefer fewer Block resources, then less Move. Returns one {mask,reduction,blocked} per attack.
    -- Exact Block allocation without the old 12-item/bitmask limit.
    -- States track each attack's useful contribution in half-points, so inefficient
    -- Blocks round down only once per attack. Matching states keep the fewest spent
    -- resources; a point above an attack's threshold has no additional value.
    local function combatBlockLegal(attack,item)
        return item.key~="blockPsychic" or attack.key=="M"
    end

    -- Share one efficiency rule between the optimiser, displayed Block totals,
    -- and the colour assigned to an inefficient Block icon.
    local function combatBlockEfficient(attack,item)
        return (combatConfig.COMBAT_EFFICIENT_BLOCKS[attack.key] or {})[item.key]==true
            or (attack.key=="M" and item.source.heroPsychicBlock==true
                and item.key~="blockPsychic")
    end

    local function combatSolveBlocks(attacks,items,movePool)
        table.sort(items,function(a,b)
            if a.value~=b.value then return a.value>b.value end
            if a.source.key~=b.source.key then return a.source.key<b.source.key end
            if a.key~=b.key then return a.key<b.key end
            return (a.part or 0)<(b.part or 0)
        end)
        local targets={}
        local initial={}
        for index,attack in ipairs(attacks) do
            targets[index]=2*attack.value*(attack.swift and 2 or 1)
            initial[index]=0
        end
        local states={["0"]={points=initial,spent=0,route=""}}
        for _,item in ipairs(items) do
            -- Type efficiency and Swiftness are constant for this item, not per DP state.
            local options={}
            for index,attack in ipairs(attacks) do
                if targets[index]>0 and combatBlockLegal(attack,item) then
                    local amount=item.value*(attack.swift and item.swiftDouble and 2 or 1)
                    local efficient=combatBlockEfficient(attack,item)
                    local contribution=amount*(efficient and 2 or 1)
                    if contribution>0 then options[#options+1]={index=index,points=contribution} end
                end
            end
            local nextStates={}
            local function retain(points,spent,route)
                local key=table.concat(points,",")
                local prior=nextStates[key]
                if prior==nil or spent<prior.spent then
                    nextStates[key]={points=points,spent=spent,route=route}
                end
            end
            for _,state in pairs(states) do
                retain(state.points,state.spent,state.route..string.char(64))
                for _,option in ipairs(options) do
                    local index=option.index
                    if state.points[index]<targets[index] then
                        local points={}
                        for j=1,#attacks do points[j]=state.points[j] end
                        points[index]=math.min(targets[index],points[index]+option.points)
                        retain(points,state.spent+1,state.route..string.char(64+index))
                    end
                end
            end
            states=nextStates
        end
        local bestScore,bestState,bestReductions=nil,nil,nil
        -- Move allocation is independent of which individual Block cards supplied
        -- the totals. Evaluate it with a small memoized knapsack for each state.
        local usefulMove=0
        for _,attack in ipairs(attacks) do
            if attack.cumbersome then usefulMove=usefulMove+attack.value end
        end
        local cap=math.min(math.max(0,movePool),usefulMove)
        local noReductions={}
        for _,state in pairs(states) do
            local score,reductions
            if cap==0 then
                -- No Move allocated: score Block totals directly without a per-state knapsack.
                local damage=0
                for index,attack in ipairs(attacks) do
                    if state.points[index]<targets[index] then
                        damage=damage+(attack.damageValue or attack.value)*(attack.brutal and 2 or 1)
                    end
                end
                score=damage*1000000
                reductions=noReductions
            else
                local memo,chosen={},{}
                local function scoreMoves(index,remaining)
                    if index>#attacks then return 0 end
                    local key=index..":"..remaining
                    if memo[key]~=nil then return memo[key] end
                    local attack=attacks[index]
                    local maxReduction=attack.cumbersome and math.min(remaining,attack.value) or 0
                    local best,bestReduction=math.huge,0
                    for reduction=0,maxReduction do
                        local leftover=attack.value-reduction
                        local threshold=2*leftover*(attack.swift and 2 or 1)
                        local blocked=leftover<=0 or state.points[index]>=threshold
                        local damage=blocked and 0 or math.max(0,(attack.damageValue or attack.value)-reduction)*(attack.brutal and 2 or 1)
                        local optionScore=damage*1000000+reduction+scoreMoves(index+1,remaining-reduction)
                        if optionScore<best then best,bestReduction=optionScore,reduction end
                    end
                    memo[key]=best
                    chosen[key]=bestReduction
                    return best
                end
                score=scoreMoves(1,cap)
                reductions={}
                local remaining=cap
                for index=1,#attacks do
                    local reduction=chosen[index..":"..remaining] or 0
                    reductions[index]=reduction
                    remaining=remaining-reduction
                end
            end
            score=score+state.spent*100
            if bestScore==nil or score<bestScore then
                bestScore,bestState,bestReductions=score,state,reductions
            end
        end
        -- Every DP state keeps an unused-item transition, so a winner should always
        -- exist. If none survives, conservatively report no Block/Move allocation.
        local planState=bestState or {points=initial,route=string.rep("@",#items)}
        local planReductions=bestReductions or {}
        local plan,used={},{}
        for index,attack in ipairs(attacks) do
            local reduction=planReductions[index] or 0
            local required=2*(attack.value-reduction)*(attack.swift and 2 or 1)
            plan[index]={used={},reduction=reduction,
                blocked=attack.value-reduction<=0 or planState.points[index]>=required}
        end
        for index=1,#items do
            local attackIndex=string.byte(planState.route,index)-64
            if attackIndex>0 then
                plan[attackIndex].used[index]=true
                used[index]=true
            end
        end
        local leftover={}
        for index=1,#items do if not used[index] then leftover[#leftover+1]=index end end
        return plan,items,leftover
    end

    local function combatBlockSpent(attack,items,used)
        local full,wrong=0,0
        for index,item in ipairs(items) do
            if used[index] and combatBlockLegal(attack,item) then
                local amount=item.value*(attack.swift and item.swiftDouble and 2 or 1)
                if combatBlockEfficient(attack,item) then full=full+amount else wrong=wrong+amount end
            end
        end
        return full+math.floor(wrong/2)
    end

    return {legal=combatBlockLegal,efficient=combatBlockEfficient,
        solve=combatSolveBlocks,spent=combatBlockSpent}
end

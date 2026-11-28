-- Cohesive BlockCalculation services; preserve original lexical and factory boundaries.

-- BlockSolver
local solver=(function()
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

    local function itemAmount(attack,item)
        local bonus=item.wallType==attack.key and item.wallOwner==attack.owner
            and (item.wallBonus or 0) or 0
        return (item.value+bonus)*(attack.swift and item.swiftDouble and 2 or 1)
    end

    local function sortItems(items)
        table.sort(items,function(a,b)
            if a.value~=b.value then return a.value>b.value end
            if a.source.key~=b.source.key then return a.source.key<b.source.key end
            if a.key~=b.key then return a.key<b.key end
            return (a.part or 0)<(b.part or 0)
        end)
    end

    local function solveVariant(attacks,items,movePool,anchorIndex)
        sortItems(items)
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
                if targets[index]>0 and combatBlockLegal(attack,item)
                    and (item.fixedAttack==nil or item.fixedAttack==index) then
                    local amount=itemAmount(attack,item)
                    local efficient=combatBlockEfficient(attack,item)
                    local contribution=amount*(efficient and 2 or 1)
                    if contribution>0 then options[#options+1]={index=index,points=contribution} end
                end
            end
            local nextStates={}
            local function retain(points,spent,route)
                local key=table.concat(points,",")
                local prior=nextStates[key]
                if prior==nil or spent<prior.spent
                    or (spent==prior.spent and route<prior.route) then
                    nextStates[key]={points=points,spent=spent,route=route}
                end
            end
            for _,state in pairs(states) do
                if item.fixedAttack==nil then retain(state.points,state.spent,state.route..string.char(64)) end
                for _,option in ipairs(options) do
                    local index=option.index
                    if state.points[index]<targets[index] or item.fixedAttack==index then
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
                score=anchorIndex~=nil and state.points[anchorIndex]<targets[anchorIndex]
                    and math.huge or damage*1000000
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
                        local optionScore=(index==anchorIndex and not blocked) and math.huge
                            or damage*1000000+reduction+scoreMoves(index+1,remaining-reduction)
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
            -- Equal-cost routes must not depend on Lua hash iteration order.
            if score<math.huge and (bestScore==nil or score<bestScore
                or (score==bestScore and bestState~=nil and state.route<bestState.route)) then
                bestScore,bestState,bestReductions=score,state,reductions
            end
        end
        -- Every DP state keeps an unused-item transition, so a winner should always
        -- exist. If none survives, conservatively report no Block/Move allocation.
        if anchorIndex~=nil and bestState==nil then return nil end
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
        return plan,items,leftover,bestScore or math.huge
    end

    local function combatSolveBlocks(attacks,items,movePool)
        local plan,solved,leftover,best=solveVariant(attacks,items,movePool)
        local wall
        for _,item in ipairs(items) do
            if item.source.shieldWallBonus~=nil then wall=item break end
        end
        if wall==nil then return plan,solved,leftover end
        -- Try each legal Shield Wall anchor. A bonus is only valid when
        -- the Wall participates in a successful Block against the same
        -- physical attack owner and element as the qualifying other Block.
        for index,attack in ipairs(attacks) do
            if not attack.pending and attack.value>0 and combatBlockLegal(attack,wall) then
                local candidate={}
                for i,item in ipairs(items) do
                    local copy={}
                    for key,value in pairs(item) do copy[key]=value end
                    if item==wall then copy.fixedAttack=index
                    elseif item.value>=2 and item.source~=wall.source
                        and item.source.key~=wall.source.key then
                        copy.wallType=attack.key
                        copy.wallOwner=attack.owner
                        copy.wallBonus=wall.source.shieldWallBonus
                    end
                    candidate[i]=copy
                end
                local p,s,l,score=solveVariant(attacks,candidate,movePool,index)
                if p~=nil and score<best then plan,solved,leftover,best=p,s,l,score end
            end
        end
        return plan,solved,leftover
    end

    local function combatBlockSpent(attack,items,used)
        local full,wrong=0,0
        for index,item in ipairs(items) do
            if used[index] and combatBlockLegal(attack,item) then
                local amount=itemAmount(attack,item)
                if combatBlockEfficient(attack,item) then full=full+amount else wrong=wrong+amount end
            end
        end
        return full+math.floor(wrong/2)
    end

    return {legal=combatBlockLegal,efficient=combatBlockEfficient,
        sortItems=sortItems,solve=combatSolveBlocks,spent=combatBlockSpent}
end
end)()

-- BlockResults
local results=(function()
-- Assemble the Block phase result and cache from fresh enemy attacks and source records.
-- Caller owns the cache lifetime, attack discovery, targeting and committed phase state.
return function(combatConfig,solver,combatEnemyAttacks,combatNatureVengeanceBlockBonus,combatRich)
    local combatBlockLegal=solver.legal
    local combatBlockEfficient=solver.efficient
    local combatSolveBlocks=solver.solve
    local combatBlockSpent=solver.spent

    local function combatBlockResult(entry,sources,cache,profileCount)
        local items={}
        local movePool=0
        for _,source in ipairs(sources) do
            if source.moveCounts==true then movePool=movePool+source.move end
            if source.psychicInfluenceCounts==true and source.psychicInfluence>0 then
                -- Influence may be divided between attacks; individual points are
                -- independent legal Psychic Block resources, never generic Block.
                for point=1,source.psychicInfluence do
                    items[#items+1]={source=source,key="blockPsychic",value=1,part=point}
                end
            end
            if source.block>0 then
                for _,field in ipairs(combatConfig.sourceFields) do
                    local value=tonumber(source.resources[field.key]) or 0
                    if field.family=="block" and value>0 then
                        -- Repeated Block icons (Shield of the Fallen Kings) are separate, equal effects.
                        local repeats=tonumber(source.repeatBlocks) or 1
                        local firstBonus=tonumber(source.ambushFirstBlockBonus) or 0
                        local unboosted=value-firstBonus
                        if repeats<2 or unboosted%repeats~=0 then
                            repeats,firstBonus,unboosted=1,0,value
                        end
                        for part=1,repeats do
                            items[#items+1]={source=source,key=field.key,
                                value=unboosted/repeats+(part==1 and firstBonus or 0),
                                swiftDouble=source.swiftDouble,part=part}
                        end
                    end
                end
            end
        end
        local attacks=combatEnemyAttacks(entry)
        local blockBonus=combatNatureVengeanceBlockBonus()
        if blockBonus>0 then
            for _,attack in ipairs(attacks) do
                if not attack.pending then
                    attack.damageValue=attack.value
                    attack.value=attack.value+blockBonus
                end
            end
        end
        -- Canonicalize the same resource set before keying the exact solver.
        solver.sortItems(items)
        local parts={tostring(movePool),tostring(#attacks),tostring(#items)}
        for _,attack in ipairs(attacks) do
            parts[#parts+1]=table.concat({
                tostring(attack.key),tostring(attack.value),tostring(attack.damageValue),tostring(attack.owner),
                tostring(attack.slot),tostring(attack.pending),tostring(attack.swift),
                tostring(attack.brutal),tostring(attack.cumbersome),tostring(attack.poison),
                tostring(attack.paralyse),tostring(attack.assassination),
                tostring(attack.firstDamageUnit),tostring(attack.label),
                tostring(attack.block),tostring(attack.abilitiesStripped)},":")
        end
        for _,item in ipairs(items) do
            parts[#parts+1]=table.concat({
                tostring(item.source.key),tostring(item.source.guid),tostring(item.key),tostring(item.value),
                tostring(item.swiftDouble),tostring(item.part),
                tostring(item.source.heroPsychicBlock),
                tostring(item.source.excessBlockArmour),tostring(item.source.shieldWallBonus)},":")
        end
        -- Move-source identity matters to the committed phase even when its
        -- total reduction is unchanged (e.g. swapping Move 2 cards).
        local moveSignature={}
        for _,source in ipairs(sources) do
            if source.moveCounts==true and (source.move or 0)>0 then
                moveSignature[#moveSignature+1]=source.key..":"..tostring(source.move)
            end
        end
        table.sort(moveSignature)
        for _,piece in ipairs(moveSignature) do parts[#parts+1]="move:"..piece end
        local key=table.concat(parts,";")
        -- Conditional effects can alternate between a few valid attack/source
        -- variants in a single refresh. Retain the four most recent exact
        -- solutions per enemy rather than evicting one on every phase pass.
        local variants=entry.guid~=nil and cache[entry.guid] or nil
        if variants~=nil then
            for index,cached in ipairs(variants) do
                if cached.key==key then
                    if index>1 then
                        table.remove(variants,index)
                        table.insert(variants,1,cached)
                    end
                    if profileCount~=nil then profileCount("block.cache.hit") end
                    return table.unpack(cached.result,1,12)
                end
            end
        end
        if profileCount~=nil then profileCount("block.cache.miss") end
        local plan,solved,leftover=combatSolveBlocks(attacks,items,movePool)
        -- Capture only the resources assigned to a successful Block. The later
        -- display of spare/failed Block icons must never commit their sources.
        local successfulSources,successfulOwners,successfulSourceKeys={},{},{}
        for index,attack in ipairs(attacks) do
            if plan[index]~=nil and plan[index].blocked and not attack.pending then
                for j,item in ipairs(solved) do
                    if plan[index].used[j] and item.key:sub(1,5)=="block" then
                        successfulSources[item.source.guid]=true
                        successfulSourceKeys[item.source.key]=true
                        local owners=successfulOwners[item.source.guid] or {}
                        owners[attack.owner or entry.guid]=true
                        successfulOwners[item.source.guid]=owners
                    end
                end
            end
        end
        -- Resources that could not complete any block are shown against the heaviest unblocked attack, once each.
        -- When every attack is blocked, spare Block is shown as over-blocking the heaviest attack.
        local attempted=nil
        for index,attack in ipairs(attacks) do
            if not plan[index].blocked then
                local damage=math.max(0,(attack.damageValue or attack.value)-plan[index].reduction)*(attack.brutal and 2 or 1)
                if attempted==nil or damage>attempted.damage then attempted={index=index,damage=damage} end
            end
        end
        if attempted==nil then
            for index,attack in ipairs(attacks) do
                if not attack.pending and attack.value>0 and (attempted==nil or attack.value>attempted.damage) then
                    attempted={index=index,damage=attack.value}
                end
            end
        end
        if attempted~=nil then
            for _,itemIndex in ipairs(leftover) do
                if combatBlockLegal(attacks[attempted.index],solved[itemIndex]) then
                    plan[attempted.index].used[itemIndex]=true
                end
            end
        end
        -- Shield Bash is one Block effect against one attack. Its powered Armour
        -- reduction uses excess Block on THAT attack (including other cards),
        -- not surplus Block from the enemy's other attacks. Calculate this after
        -- spare resources have been assigned, without affecting Ranged/Siege.
        local shieldBashExcess={}
        for index,attack in ipairs(attacks) do
            local step=plan[index]
            if step~=nil and step.blocked and not attack.pending and attack.value>0 then
                local bashCount=0
                for itemIndex,item in ipairs(solved) do
                    if step.used[itemIndex] and item.source.excessBlockArmour then
                        bashCount=bashCount+1
                    end
                end
                if bashCount>0 then
                    local needed=math.max(0,attack.value-step.reduction)
                        *(attack.swift and 2 or 1)
                    local excess=math.max(0,combatBlockSpent(attack,solved,step.used)-needed)
                    local owner=attack.owner or entry.guid
                    if excess>0 then
                        shieldBashExcess[owner]=(shieldBashExcess[owner] or 0)+excess*bashCount
                            -- Every point used to generate the frozen Armour reduction
                            -- was spent, including surplus Block assigned after solving.
                            for itemIndex,item in ipairs(solved) do
                                if step.used[itemIndex] then
                                    successfulSourceKeys[item.source.key]=true
                                end
                            end
                    end
                end
            end
        end
        -- Cumbersome Move is effective even when damage is not fully blocked.
        -- Commit only enough physical Move sources to cover the actual reductions;
        -- unused sources remain free to supply Attack-phase alternatives.
        local spentMoveKeys={}
        local remainingMove=0
        for _,step in ipairs(plan) do remainingMove=remainingMove+(step.reduction or 0) end
        if remainingMove>0 then
            local moveSources={}
            for _,source in ipairs(sources) do
                if source.moveCounts==true and (source.move or 0)>0 then
                    moveSources[#moveSources+1]=source
                end
            end
            table.sort(moveSources,function(a,b) return a.key<b.key end)
            for _,source in ipairs(moveSources) do
                if remainingMove<=0 then break end
                spentMoveKeys[source.key]=true
                remainingMove=remainingMove-source.move
            end
        end
        local lines,reductions,totalDamage,damageCount,allBlocked={},{},0,0,#attacks>0
        local unblocked={}
        -- Block items applied at the wrong element (halved) against their attack, keyed source.key..field.key.
        local wrongBlock={}
        for index,attack in ipairs(attacks) do
            for j,item in ipairs(solved) do
                if plan[index].used[j] and not combatBlockEfficient(attack,item) then
                    wrongBlock[item.source.key..item.key]=true
                end
            end
        end
        for index,attack in ipairs(attacks) do
            local step=plan[index]
            local remaining=attack.value-step.reduction
            local required=remaining*(attack.swift and 2 or 1)
            local spent=combatBlockSpent(attack,solved,step.used)
            reductions[index]=step.reduction
            if attack.pending then allBlocked=false end
            if step.blocked then
                lines[index]=attack.pending and "Summon pending" or (attack.value<=0 and "No attack"
                    or (tostring(math.max(spent,required)).."/"..tostring(required).." Blocked"))
            else
                allBlocked=false
                local damage=math.max(0,(attack.damageValue or attack.value)-step.reduction)*(attack.brutal and 2 or 1)
                totalDamage=totalDamage+damage
                if damage>0 then damageCount=damageCount+1 end
                local prefix=spent>0 and (tostring(spent).."/"..tostring(required).." Block, ") or "Not blocked, "
                unblocked[index]={prefix=prefix,damage=damage,attack=attack}
                lines[index]=prefix..combatRich(tostring(damage).." Damage",combatConfig.COMBAT_RED)
            end
        end
        if entry.guid~=nil then
            if variants==nil then variants={} cache[entry.guid]=variants end
            table.insert(variants,1,{key=key,result={
                lines,totalDamage,damageCount,allBlocked,reductions,wrongBlock,unblocked,
                successfulSources,successfulOwners,shieldBashExcess,successfulSourceKeys,spentMoveKeys}})
            if #variants>4 then table.remove(variants) end
        end
        return lines,totalDamage,damageCount,allBlocked,reductions,wrongBlock,unblocked,
            successfulSources,successfulOwners,shieldBashExcess,successfulSourceKeys,spentMoveKeys
    end

    return combatBlockResult
end
end)()

return {solver=solver,results=results}

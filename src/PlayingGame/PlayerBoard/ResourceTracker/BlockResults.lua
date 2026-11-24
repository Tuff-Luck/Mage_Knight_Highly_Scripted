-- Assemble the Block phase result and cache from fresh enemy attacks and source records.
-- Caller owns the cache lifetime, attack discovery, targeting and committed phase state.
return function(combatConfig,solver,combatEnemyAttacks,combatNatureVengeanceBlockBonus,combatRich)
    local combatBlockLegal=solver.legal
    local combatBlockEfficient=solver.efficient
    local combatSolveBlocks=solver.solve
    local combatBlockSpent=solver.spent

    local function combatBlockResult(entry,sources,cache)
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
        local parts={tostring(movePool),tostring(#attacks),tostring(#items)}
        for _,attack in ipairs(attacks) do
            parts[#parts+1]=table.concat({
                tostring(attack.key),tostring(attack.value),tostring(attack.damageValue),tostring(attack.owner),
                tostring(attack.slot),tostring(attack.pending),tostring(attack.swift),
                tostring(attack.brutal),tostring(attack.cumbersome),tostring(attack.poison),
                tostring(attack.paralyse),tostring(attack.assassination),
                tostring(attack.firstDamageUnit)},":")
        end
        for _,item in ipairs(items) do
            parts[#parts+1]=table.concat({
                tostring(item.source.key),tostring(item.key),tostring(item.value),
                tostring(item.swiftDouble),tostring(item.part),
                tostring(item.source.heroPsychicBlock),
                tostring(item.source.excessBlockArmour)},":")
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
        local cached=entry.guid~=nil and cache[entry.guid] or nil
        if cached~=nil and cached.key==key then return table.unpack(cached.result,1,12) end
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
            cache[entry.guid]={key=key,result={
                lines,totalDamage,damageCount,allBlocked,reductions,wrongBlock,unblocked,
                successfulSources,successfulOwners,shieldBashExcess,successfulSourceKeys,spentMoveKeys}}
        end
        return lines,totalDamage,damageCount,allBlocked,reductions,wrongBlock,unblocked,
            successfulSources,successfulOwners,shieldBashExcess,successfulSourceKeys,spentMoveKeys
    end

    return combatBlockResult
end

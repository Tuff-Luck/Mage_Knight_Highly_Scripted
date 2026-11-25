-- Distribute one physical resource source across its assigned enemy targets.
-- The coordinator chooses targets and owns arrow state; only fresh allocation records are changed here.
return function(attackAssignmentsTargetCounts,combatGUIDHasCumbersome,combatEnemyAttacks)
    local function allocate(source,target,targetGUID,explicit,rowByGUID,entries,allocated,observation)
        local cumbersome=observation~=nil and observation.cumbersome or combatGUIDHasCumbersome
        local attacks=observation~=nil and observation.attacks or combatEnemyAttacks
        local counts
        if source.convertedResource~=nil or (source.moveCounts and (source.move or 0)>0)
            or source.psychicInfluenceCounts then
            counts=attackAssignmentsTargetCounts(source.key)
        end
        if source.convertedResource~=nil then
            -- A right-click adds an arrow to another enemy. Each extra
            -- arrow spends ONE converted point, never a second full pool.
            local other={}
            for guid in pairs(counts) do
                if guid~=targetGUID and rowByGUID[guid]~=nil then other[#other+1]=guid end
            end
            table.sort(other)
            local remaining=source.convertedAmount
            for _,guid in ipairs(other) do
                local amount=math.min(remaining,counts[guid])
                if amount>0 then
                    local family=source.convertedFamily
                    local key=source.convertedResource
                    local detail=source.details[1]
                    local portion={guid=source.guid,key=source.key,name=source.name,
                        ranged=family=="ranged" and amount or 0,
                        siege=family=="siege" and amount or 0,
                        attack=family=="attack" and amount or 0,
                        block=family=="block" and amount or 0,move=0,
                        psychicInfluence=0,resources={[key]=amount},
                        details={{text=key.." "..amount,amount=amount,
                            key=key,icon=detail~=nil and detail.icon or "MKChoiceAttack",
                            family=family,typeKey=detail~=nil and detail.typeKey or "P"}}}
                    local index=rowByGUID[guid]
                    local extra=allocated[index]
                    if extra==nil then
                        extra={range={},block={},attack={},sources={},details={}}
                        allocated[index]=extra
                    end
                    extra.sources[#extra.sources+1]=portion
                    extra.details[#extra.details+1]={source=portion,detail=portion.details[1]}
                    remaining=remaining-amount
                end
            end
            source[source.convertedFamily]=remaining
            source.resources[source.convertedResource]=remaining
            if remaining>0 and source.details[1]~=nil then
                source.details[1].amount=remaining
                source.details[1].text=source.convertedResource.." "..remaining
            else
                source.details={}
            end
        end
        target.sources[#target.sources+1]=source
        for _,detail in ipairs(source.details) do
            if (detail.family~="move" or explicit)
                and (detail.family~="influence" or source.psychicInfluenceCounts) then
                target.details[#target.details+1]={source=source,detail=detail}
            end
        end
        if source.moveCounts and (source.move or 0)>0 then
            -- Primary target receives the remaining Cumbersome Move.
            -- Each extra arrow transfers one point to another Cumbersome
            -- enemy, exactly as divisible Psychic Influence does.
            local other={}
            for guid in pairs(counts) do
                if guid~=targetGUID and rowByGUID[guid]~=nil then
                    other[#other+1]=guid
                end
            end
            table.sort(other)
            local remaining=source.move
            for _,guid in ipairs(other) do
                if remaining<=0 then break end
                if cumbersome(guid) then
                    local amount=math.min(counts[guid],remaining)
                    local portion={guid=source.guid,key=source.key,name=source.name,
                        ranged=0,siege=0,block=0,attack=0,
                        move=amount,moveCounts=true,
                        psychicInfluence=0,resources={move=amount},
                        details={{text="Move "..tostring(amount),amount=amount,
                            icon="MKChoiceMove",key="move",family="move"}}}
                    local index=rowByGUID[guid]
                    local extra=allocated[index]
                    if extra==nil then
                        extra={range={},block={},attack={},sources={},details={}}
                        allocated[index]=extra
                    end
                    extra.sources[#extra.sources+1]=portion
                    extra.details[#extra.details+1]={
                        source=portion,detail=portion.details[1]}
                    remaining=remaining-amount
                end
            end
            source.move=remaining
            if source.resources~=nil then source.resources.move=remaining end
            for i=#target.details,1,-1 do
                local item=target.details[i]
                if item.source==source and item.detail.family=="move" then
                    if remaining<=0 then table.remove(target.details,i)
                    else
                        item.detail.amount=remaining
                        item.detail.text="Move "..tostring(remaining)
                    end
                end
            end
        end
        if source.psychicInfluenceCounts then
            -- The primary left-click target initially receives all Influence.
            -- Each additional right-click arrow transfers one point; repeated
            -- arrows to the same enemy transfer more. No point is double-spent.
            local targetCounts=counts
            local extraTargets={}
            for guid in pairs(targetCounts) do
                if guid~=targetGUID and rowByGUID[guid]~=nil then
                    extraTargets[#extraTargets+1]=guid
                end
            end
            table.sort(extraTargets)
            local remaining=source.psychicInfluence
            for _,guid in ipairs(extraTargets) do
                if remaining<=0 then break end
                local index=rowByGUID[guid]
                local psychic=false
                for _,attack in ipairs(attacks(entries[index])) do
                    if attack.key=="M" then psychic=true break end
                end
                if psychic then
                    local amount=math.min(targetCounts[guid],remaining)
                    local portion={guid=source.guid,key=source.key,name=source.name.." (Influence)",
                        ranged=0,siege=0,block=0,attack=0,move=0,resources={},
                        psychicInfluence=amount,psychicInfluenceCounts=true,details={}}
                    local detail={text="Influence "..tostring(amount).." → Psychic Block",
                        amount=amount,icon="MKChoiceBlock",key="influence",family="influence"}
                    portion.details[1]=detail
                    local extra=allocated[index]
                    if extra==nil then
                        extra={range={},block={},attack={},sources={},details={}}
                        allocated[index]=extra
                    end
                    extra.sources[#extra.sources+1]=portion
                    extra.details[#extra.details+1]={source=portion,detail=detail}
                    remaining=remaining-amount
                end
            end
            source.psychicInfluence=remaining
            for i=#target.details,1,-1 do
                local item=target.details[i]
                if item.source==source and item.detail.family=="influence" then
                    if remaining<=0 then table.remove(target.details,i)
                    else
                        item.detail.amount=remaining
                        item.detail.text="Influence "..tostring(remaining).." → Psychic Block"
                    end
                end
            end
        end
    end

    return allocate
end

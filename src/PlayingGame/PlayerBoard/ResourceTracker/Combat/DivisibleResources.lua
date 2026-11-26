-- Distribute one physical resource source across its assigned enemy targets.
-- The coordinator owns arrows; only fresh allocation records are changed.
return function(attackAssignmentsTargetCounts,combatGUIDHasCumbersome,combatEnemyAttacks)
    local function append(allocated,index,portion)
        local extra=allocated[index]
        if extra==nil then
            extra={range={},block={},attack={},sources={},details={}}
            allocated[index]=extra
        end
        extra.sources[#extra.sources+1]=portion
        extra.details[#extra.details+1]={source=portion,detail=portion.details[1]}
    end

    local function distribute(other,counts,remaining,rowByGUID,allocated,eligible,makePortion)
        for _,guid in ipairs(other) do
            if remaining<=0 then break end
            local index=rowByGUID[guid]
            if eligible==nil or eligible(guid,index) then
                local amount=math.min(remaining,counts[guid])
                if amount>0 then
                    append(allocated,index,makePortion(amount))
                    remaining=remaining-amount
                end
            end
        end
        return remaining
    end

    local function portion(source,name)
        return {guid=source.guid,key=source.key,name=name or source.name,
            ranged=0,siege=0,block=0,attack=0,move=0,psychicInfluence=0,
            resources={},details={}}
    end

    local function updatePrimary(target,source,family,remaining,label)
        for i=#target.details,1,-1 do
            local item=target.details[i]
            if item.source==source and item.detail.family==family then
                if remaining<=0 then table.remove(target.details,i)
                else
                    item.detail.amount=remaining
                    item.detail.text=label(remaining)
                end
            end
        end
    end

    local function allocate(source,target,targetGUID,explicit,rowByGUID,entries,allocated,observation)
        local cumbersome=observation~=nil and observation.cumbersome or combatGUIDHasCumbersome
        local attacks=observation~=nil and observation.attacks or combatEnemyAttacks
        local counts,other
        if source.convertedResource~=nil or (source.moveCounts and (source.move or 0)>0)
            or source.psychicInfluenceCounts then
            counts=attackAssignmentsTargetCounts(source.key)
            other={}
            for guid in pairs(counts) do
                if guid~=targetGUID and rowByGUID[guid]~=nil then other[#other+1]=guid end
            end
            table.sort(other)
        end
        if source.convertedResource~=nil then
            local family,key=source.convertedFamily,source.convertedResource
            local detail=source.details[1]
            local remaining=distribute(other,counts,source.convertedAmount,rowByGUID,allocated,nil,function(amount)
                local part=portion(source)
                part[family]=amount
                part.resources[key]=amount
                part.details[1]={text=key.." "..amount,amount=amount,key=key,
                    icon=detail~=nil and detail.icon or "MKChoiceAttack",family=family,
                    typeKey=detail~=nil and detail.typeKey or "P"}
                return part
            end)
            source[family]=remaining
            source.resources[key]=remaining
            if remaining>0 and detail~=nil then
                detail.amount=remaining
                detail.text=key.." "..remaining
            else source.details={} end
        end
        target.sources[#target.sources+1]=source
        for _,detail in ipairs(source.details) do
            if (detail.family~="move" or explicit)
                and (detail.family~="influence" or source.psychicInfluenceCounts) then
                target.details[#target.details+1]={source=source,detail=detail}
            end
        end
        if source.moveCounts and (source.move or 0)>0 then
            local function label(amount) return "Move "..tostring(amount) end
            local remaining=distribute(other,counts,source.move,rowByGUID,allocated,cumbersome,function(amount)
                local part=portion(source)
                part.move,part.moveCounts=amount,true
                part.resources.move=amount
                part.details[1]={text=label(amount),amount=amount,icon="MKChoiceMove",key="move",family="move"}
                return part
            end)
            source.move=remaining
            if source.resources~=nil then source.resources.move=remaining end
            updatePrimary(target,source,"move",remaining,label)
        end
        if source.psychicInfluenceCounts then
            local function label(amount) return "Influence "..tostring(amount).." → Psychic Block" end
            local remaining=distribute(other,counts,source.psychicInfluence,rowByGUID,allocated,function(_,index)
                for _,attack in ipairs(attacks(entries[index])) do
                    if attack.key=="M" then return true end
                end
                return false
            end,function(amount)
                local part=portion(source,source.name.." (Influence)")
                part.psychicInfluence,part.psychicInfluenceCounts=amount,true
                part.details[1]={text=label(amount),amount=amount,icon="MKChoiceBlock",key="influence",family="influence"}
                return part
            end)
            source.psychicInfluence=remaining
            updatePrimary(target,source,"influence",remaining,label)
        end
    end

    return allocate
end

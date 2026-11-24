-- Block-triggered destruction and counterattacks, preserving the preceding ranged phase.
-- Operates on fresh entries and allocations; group rebuilding and physical state stay with the caller.
return function(combatApplyDefend,collectGroup,combatRangeGroupEntry,combatRangeResult,
    combatEnemyAttacks,combatBlockResult,combatEffectDestroysFullyBlocked,
    combatEnemyHasTrait,tokenOf,perksOf)
    local function destroyAfterBlock(entries,groups,allocated)
        -- Complete the Ranged/Siege phase BEFORE resolving any "destroyed if
        -- blocked" effect. A preview uses shallow copies so Defender bonuses
        -- cannot be applied twice to the actual combat entries.
        local rangedBeforeBlock=nil
        local hasConditional=false
        for _,entry in ipairs(entries) do
            if not entry.destroyed then
                for _,applied in ipairs(entry.effect~=nil and entry.effect.applied or {}) do
                    if applied.effective~=nil and (applied.effective.destroyIfBlocked==true
                        or applied.effective.destroyIfFullyBlocked==true) then
                        entry.explodePending=true
                        hasConditional=true
                        break
                    end
                end
            end
        end
        if hasConditional then
            local preview={}
            for i,entry in ipairs(entries) do
                local copy={}
                for key,value in pairs(entry) do copy[key]=value end
                preview[i]=copy
            end
            combatApplyDefend(preview,groups,allocated)
            rangedBeforeBlock={}
            for _,group in ipairs(groups) do
                local members,sources=collectGroup(group,preview,allocated)
                local _,_,ranged=combatRangeResult(combatRangeGroupEntry(members),sources)
                if ranged and not members[1].attackOnly then
                    for _,index in ipairs(group.members) do rangedBeforeBlock[index]=true end
                end
            end
        end

        -- Only enemies surviving Ranged/Siege can be destroyed in the Block phase.
        local conditionalDestroyed=false
        for index=1,#entries do
            local entry=entries[index]
            if entry.explodePending and not entry.destroyed
                and (rangedBeforeBlock==nil or rangedBeforeBlock[index]~=true) then
                local hasAttack=false
                for _,attack in ipairs(combatEnemyAttacks(entry)) do
                    if not attack.pending and attack.value>0 then hasAttack=true break end
                end
                if hasAttack then
                    local target=allocated[index]
                    local _,_,_,allBlocked,_,_,_,successfulSources,successfulOwners=
                        combatBlockResult(entry,target~=nil and target.sources or {})
                    local explodedEnemy=false
                    for _,applied in ipairs(entry.effect~=nil and entry.effect.applied or {}) do
                        if combatEffectDestroysFullyBlocked(applied,allBlocked,hasAttack) then
                            explodedEnemy=true
                        elseif applied.effective~=nil and applied.effective.destroyIfBlocked==true
                            and successfulSources[applied.source]==true then
                            for owner in pairs(successfulOwners[applied.source] or {}) do
                                local token=owner==entry.guid and entry.data or tokenOf(owner)
                                local perks=owner==entry.guid and entry.perks or perksOf(owner)
                                -- Immunity belongs to the actual blocked token,
                                -- not to its summoner (which may have different traits).
                                local immune=token==nil
                                    or combatEnemyHasTrait(token,perks,"arcaneImmunity")
                                    or combatEnemyHasTrait(token,perks,"fResist")
                                if not immune and owner==entry.guid then
                                    -- One successful Attack Block suffices even if
                                    -- the token has other, unblocked attacks.
                                    explodedEnemy=true
                                else
                                    -- A blocked summoned monster is destroyed, NOT
                                    -- its summoner, and never earns Fame by itself.
                                    for _,summoned in ipairs(entry.summoned or {}) do
                                        if not immune and summoned.guid==owner then
                                            entry.summonedDestroyed=entry.summonedDestroyed or {}
                                            entry.summonedDestroyed[owner]=true
                                            break
                                        end
                                    end
                                end
                            end
                        end
                    end
                    if explodedEnemy then entry.destroyed=true conditionalDestroyed=true end
                end
            end
        end
        return rangedBeforeBlock,conditionalDestroyed
    end

    local function burningShield(entries,allocated,emptyTarget)
        -- Resolve Burning Shield's trigger across EVERY Block target before
        -- resolving any Attack target. The earned Fire Attack may then be aimed
        -- at a different enemy, even one that made no attack of its own.
        local burningShieldTriggered={}
        for index,entry in ipairs(entries) do
            local target=allocated[index] or emptyTarget
            local _,_,_,_,_,_,_,successfulSources=combatBlockResult(entry,target.sources)
            for _,source in ipairs(target.sources) do
                if source.conditionalFireAttack~=nil and source.block>0
                    and successfulSources[source.guid]==true then
                    burningShieldTriggered[source.guid]=true
                end
            end
        end
        for index in ipairs(entries) do
            local target=allocated[index]
            if target~=nil then
                for _,source in ipairs(target.sources) do
                    if source.conditionalCounterattack~=nil then
                        local amount=burningShieldTriggered[source.guid]
                            and source.conditionalCounterattack or 0
                        source.attack=amount
                        source.resources.attackFire=amount
                        if amount<=0 then
                            -- Do not count or display a counterattack until the
                            -- generating Fire Block has actually succeeded.
                            for detailIndex=#target.details,1,-1 do
                                if target.details[detailIndex].source==source then
                                    table.remove(target.details,detailIndex)
                                end
                            end
                            source.details={}
                        else
                            for _,detail in ipairs(source.details) do
                                if detail.key=="attackFire" then
                                    detail.text="Fire Attack "..tostring(amount).." (successful Block)"
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    return {destroyAfterBlock=destroyAfterBlock,burningShield=burningShield}
end

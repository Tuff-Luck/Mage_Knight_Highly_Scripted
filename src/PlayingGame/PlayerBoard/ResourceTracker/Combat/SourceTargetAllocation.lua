-- Source target recovery, eligibility and fresh row allocation.
-- Caller owns the current assignment state, physical arrows and active player.
return function(attackAssignmentsTargetGUIDs,attackAssignmentsClearForObject,
    resourceCardsCombatTargetAcceptsSource,combatGUIDHasCumbersome,combatNearestEnemyGUID,
    attackAssignmentsIsTargeting,attackAssignmentsEnsureTarget,combatSourceArrowKind,
    combatEnemyAttacks,divisibleResources,scanOfActiveSeat,combatSourceKeepsLock)
    local function recoverTarget(source,rowByGUID,combatAssignmentState)
        -- Explicit calculator targets remain authoritative. If none exists,
        -- the saved arrow is recovered below (including after reload).
        local targetGUID=combatAssignmentState.targets[source.key]
        if targetGUID==nil then
            -- Restore the saved visual assignment for every source after a reload.
            -- Persisted/manual assignments win over nearest-enemy defaults.
            local saved=attackAssignmentsTargetGUIDs(source.key)
            local first
            for guid in pairs(saved) do
                if rowByGUID[guid]~=nil and (first==nil or guid<first) then first=guid end
            end
            -- Prefer the persisted primary target when available; otherwise
            -- use a deterministic fallback for older saves.
            local primary=gStates~=nil and gStates.resourceCardPrimaryTargets
                and gStates.resourceCardPrimaryTargets[source.key] or nil
            if gStates~=nil and gStates.resourceCardPrimaryTargets~=nil then
                gStates.resourceCardPrimaryTargets[source.key]=nil
            end
            targetGUID=primary~=nil and rowByGUID[primary]~=nil
                and saved[primary] and primary or first
            if targetGUID~=nil then
                combatAssignmentState.targets[source.key]=targetGUID
                combatAssignmentState.explicit[source.key]=true
            end
        end
        return targetGUID
    end

    local function resolveTarget(source,entries,rowByGUID,combatAssignmentState,combatCumbersomeActive,observation)
        local cumbersome=observation~=nil and observation.cumbersome or combatGUIDHasCumbersome
        local moveOnly=source.ranged+source.siege+source.block+source.attack==0
            and source.psychicInfluence==0
        local influenceOnly=source.ranged+source.siege+source.block+source.attack==0
            and source.psychicInfluence>0 and source.move==0
        local targetGUID=recoverTarget(source,rowByGUID,combatAssignmentState)
        local targetIndex=targetGUID~=nil and rowByGUID[targetGUID] or nil
        if targetIndex~=nil and source.possessExclude==targetGUID then
            combatAssignmentState.targets[source.key]=nil
            combatAssignmentState.explicit[source.key]=nil
            attackAssignmentsClearForObject(source.key)
            targetGUID,targetIndex=nil,nil
        end
        if source.forkedLightning and targetIndex~=nil
            and not resourceCardsCombatTargetAcceptsSource(source.key,targetGUID) then
            combatAssignmentState.targets[source.key]=nil
            combatAssignmentState.explicit[source.key]=nil
            attackAssignmentsClearForObject(source.key)
            targetGUID,targetIndex=nil,nil
        end
        if targetIndex~=nil and entries[targetIndex].attackOnly
            and source.ranged+source.siege+source.attack>0 then
            combatAssignmentState.targets[source.key]=nil
            combatAssignmentState.explicit[source.key]=nil
            attackAssignmentsClearForObject(source.key)
            targetGUID,targetIndex=nil,nil
        end
        if moveOnly and targetGUID~=nil and not cumbersome(targetGUID) then
            -- Move can only be aimed at a Cumbersome enemy.
            combatAssignmentState.targets[source.key]=nil
            combatAssignmentState.explicit[source.key]=nil
            attackAssignmentsClearForObject(source.key)
            targetGUID,targetIndex=nil,nil
        end
        -- Combat Move is a deliberate phase choice, unlike ordinary movement.
        -- Its nearest eligible Cumbersome enemy gets the same initial arrow
        -- and lock as other combat sources. A manually assigned target wins.
        -- Mark this automatic Move lock allocated so its points actually
        -- reduce Cumbersome and are reserved from Agility conversion.
        local autoCombatMove=moveOnly and source.move>0 and combatCumbersomeActive
            and not attackAssignmentsIsTargeting(source.key)
        if targetIndex==nil and (autoCombatMove or (not moveOnly and not influenceOnly)) then
            targetGUID=combatNearestEnemyGUID(source,entries,
                autoCombatMove and cumbersome or nil,observation~=nil and observation.positions or nil)
            combatAssignmentState.targets[source.key]=targetGUID
            combatAssignmentState.explicit[source.key]=autoCombatMove and targetGUID~=nil or nil
            targetIndex=targetGUID~=nil and rowByGUID[targetGUID] or nil
        end
        if targetIndex==nil and targetGUID~=nil then
            combatAssignmentState.targets[source.key]=nil
            combatAssignmentState.explicit[source.key]=nil
        end
        return targetGUID,targetIndex
    end

    -- Trace-only accounting captures original amounts before the divisible
    -- allocator mutates its fresh source records. Unassigned resources are legal;
    -- only allocation above the original source budget is a violation.
    local fields={"ranged","siege","block","attack","move","psychicInfluence"}
    local function addBudget(budgets,source)
        local budget=budgets[source.key] or {}
        budgets[source.key]=budget
        for _,field in ipairs(fields) do
            budget[field]=(budget[field] or 0)+(tonumber(source[field]) or 0)
        end
    end

    local function checkBudget(original,allocated,report)
        local actual={}
        for _,row in pairs(allocated) do
            for _,source in ipairs(row.sources) do addBudget(actual,source) end
        end
        for key,budget in pairs(actual) do
            for _,field in ipairs(fields) do
                local allowed=(original[key] or {})[field] or 0
                if budget[field]>allowed then report(key,field,allowed,budget[field]) end
            end
        end
    end

    local function allocate(entries,sources,rowByGUID,combatAssignmentState,combatCumbersomeActive,report)
        local allocated,activeSources={},{}
        -- These observations are valid only during this allocation pass.
        -- Later phases can change attacks and the next refresh sees live positions.
        local cumbersomeCache,attackCache={},{}
        local observation={positions={}}
        observation.cumbersome=function(guid)
            if cumbersomeCache[guid]==nil then
                cumbersomeCache[guid]=combatGUIDHasCumbersome(guid)==true
            end
            return cumbersomeCache[guid]
        end
        observation.attacks=function(entry)
            local cached=attackCache[entry]
            if cached==nil then
                cached=combatEnemyAttacks(entry)
                attackCache[entry]=cached
            end
            return cached
        end
        local original=report~=nil and {} or nil
        if original~=nil then
            for _,source in ipairs(sources) do addBudget(original,source) end
        end
        for _,source in ipairs(sources) do
            activeSources[source.key]=true
            local targetGUID,targetIndex=resolveTarget(source,entries,rowByGUID,combatAssignmentState,combatCumbersomeActive,observation)
            if targetIndex~=nil then
                -- The arrow follows the lock, and returns if a cancelled retarget removed it.
                if not attackAssignmentsIsTargeting(source.key) then
                    attackAssignmentsEnsureTarget(source.key,targetGUID,combatSourceArrowKind(source))
                end
                local manuallyTargeted=combatAssignmentState.explicit[source.key]==true
                local explicit=manuallyTargeted and observation.cumbersome(targetGUID)
                source.moveCounts=explicit
                source.psychicInfluenceCounts=manuallyTargeted
                    and source.psychicInfluence>0 and (function()
                        for _,attack in ipairs(observation.attacks(entries[targetIndex])) do
                            if attack.key=="M" then return true end
                        end
                        return false
                    end)()
                local target=allocated[targetIndex]
                if target==nil then
                    target={range={},block={},attack={},sources={},details={}}
                    allocated[targetIndex]=target
                end
                if source.dueling then
                    -- A target with no Block phase cannot receive Dueling's later Attack.
                    source.duelingEligible=false
                    for _,attack in ipairs(observation.attacks(entries[targetIndex])) do
                        if not attack.pending then source.duelingEligible=true break end
                    end
                end
                divisibleResources(source,target,targetGUID,explicit,rowByGUID,entries,allocated,observation)
            end
        end
        local effectOnly={}
        local currentScan=scanOfActiveSeat()
        for _,record in pairs(currentScan~=nil and currentScan.cards or {}) do
            for _,key in ipairs(record.enemyEffectTargetKeys or {}) do effectOnly[key]=true end
        end
        for key in pairs(combatAssignmentState.targets) do
            local active=effectOnly[key]==true or activeSources[key]==true
            -- Enemy-effect Skills and Units are also real target sources even
            -- when they generate no numeric Attack or Block.
            if not active and not combatSourceKeepsLock(key) then
                combatAssignmentState.targets[key]=nil
                combatAssignmentState.explicit[key]=nil
            end
        end
        if original~=nil then checkBudget(original,allocated,report) end
        return allocated
    end

    return {recoverTarget=recoverTarget,resolveTarget=resolveTarget,allocate=allocate}
end

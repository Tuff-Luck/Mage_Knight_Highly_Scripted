-- Iterative Explosive Bolt Armour reduction, earned only from legal Ranged/Siege defeats.
-- The coordinator supplies combat evaluation and owns physical target assignments.
return function(combatApplyDefend,combatRangeGroupEntry,combatRangeResult,combatEnemyHasTrait,
    targetOf,attackAssignmentsTargetGUIDs,attackAssignmentsReconcileEffectTarget)
    -- Explosive Bolt effects are gained as Ranged groups fall. Apply their
    -- Armour reduction *within* that phase so a second Ranged/Siege attack may
    -- defeat another enemy, and carry the reduction into the later Attack phase.
    -- A fixed-point pass only unlocks a new bonus after an independently legal
    -- Ranged/Siege defeat; two attacks that both need the other's bonus cannot
    -- manufacture a kill. Each defeated enemy grants -1 even under Maximal Effect.
    local function applyExplosiveBoltRange(entries,groups,allocated,sources)
        local active={}
        for _,source in ipairs(sources) do
            if (tonumber(source.explosiveBolt) or 0)>0 then
                active[#active+1]=source
            end
        end
        if #active==0 then return end
        local preview={}
        for i,entry in ipairs(entries) do
            local copy={}
            for key,value in pairs(entry) do copy[key]=value end
            preview[i]=copy
        end
        combatApplyDefend(preview,groups,allocated)
        local rangedVictims,finished,earned={}, {}, {}
        local appliedBySource={}
        local function groupRange(group)
            local members,assigned={},{}
            for _,index in ipairs(group.members) do
                members[#members+1]=preview[index]
                for _,source in ipairs((allocated[index] or {sources={}}).sources) do
                    assigned[#assigned+1]=source
                end
            end
            local total,armour,dead,fort=combatRangeResult(
                combatRangeGroupEntry(members),assigned)
            if members[1].attackOnly then dead=false end
            return dead,fort,assigned
        end
        local function linkedTarget(source)
            local key=source.guid.."#explosiveAttack"
            local targetGUID=targetOf(key)
            if targetGUID==nil then
                for guid in pairs(attackAssignmentsTargetGUIDs(key)) do
                    if targetGUID==nil or guid<targetGUID then targetGUID=guid end
                end
            end
            for _,entry in ipairs(entries) do
                if entry.guid==targetGUID then return entry,key,true end
            end
            -- Deterministic left-to-right default, not an enemy already defeated.
            for _,entry in ipairs(entries) do
                if not entry.attackOnly and not entry.destroyed and not entry.preview
                    and not rangedVictims[entry.guid] then
                    return entry,key,false
                end
            end
            return nil,key,false
        end
        for _=1,#groups+1 do
            for _,group in ipairs(groups) do
                if not finished[group] then
                    local dead,fort,assigned=groupRange(group)
                    if dead then
                        finished[group]=true
                        local count=0
                        for _,index in ipairs(group.members) do
                            local enemy=entries[index]
                            if not enemy.preview and not enemy.attackOnly then
                                rangedVictims[enemy.guid]=true
                                count=count+1
                            end
                        end
                        if count>0 then
                            local seen={}
                            for _,source in ipairs(assigned) do
                                if (tonumber(source.explosiveBolt) or 0)>0
                                    and not seen[source.guid]
                                    and ((source.ranged>0 and fort==0)
                                        or (source.siege>0 and fort<2)) then
                                    seen[source.guid]=true
                                    earned[source.guid]=(earned[source.guid] or 0)+count
                                end
                            end
                        end
                    end
                end
            end
            local changed=false
            for _,source in ipairs(active) do
                local target,key=linkedTarget(source)
                if target~=nil then
                    -- Also recolour an existing saved follow-up arrow; reconciliation
                    -- preserves the chosen target and skips committed/pending sources.
                    attackAssignmentsReconcileEffectTarget(key,target.guid,"other")
                    local already=appliedBySource[source.guid] or 0
                    local desired=(earned[source.guid] or 0)*(source.explosiveBolt or 0)
                    local immune=combatEnemyHasTrait(target.data,target.perks,"fResist")
                        or combatEnemyHasTrait(target.data,target.perks,"arcaneImmunity")
                    local valid=not target.attackOnly and not target.destroyed
                        and not rangedVictims[target.guid] and not immune
                    local delta=valid and math.min(math.max(0,desired-already),
                        math.max(0,target.baseArmour-1)) or 0
                    if delta>0 then
                        appliedBySource[source.guid]=already+delta
                        local other=nil
                        for i,enemy in ipairs(entries) do
                            if enemy.guid==target.guid then
                                other=preview[i]
                                break
                            end
                        end
                        -- Update both the real later-Attack Armour and the Ranged
                        -- preview. Defender's Ranged bonus lives on the preview.
                        for _,member in ipairs({target,other}) do
                            if member~=nil then
                                member.rangeBaseArmour=math.max(1,
                                    (member.rangeBaseArmour or member.baseArmour)-delta)
                                member.rangeElusiveArmour=math.max(1,
                                    (member.rangeElusiveArmour or member.elusiveArmour)-delta)
                                member.baseArmour=math.max(1,member.baseArmour-delta)
                                member.elusiveArmour=math.max(1,member.elusiveArmour-delta)
                            end
                        end
                        target.effectArmourReduction=(target.effectArmourReduction or 0)+delta
                        changed=true
                    end
                end
            end
            if not changed then break end
        end
        -- Report the earned amount, even if immunity or the Armour floor makes
        -- some of it ineffective. Effects retain a separate target/control.
        for _,source in ipairs(active) do
            local target,key,locked=linkedTarget(source)
            if target~=nil then
                local amount=(earned[source.guid] or 0)*(source.explosiveBolt or 0)
                local applied=appliedBySource[source.guid] or 0
                local immune=combatEnemyHasTrait(target.data,target.perks,"fResist")
                    or combatEnemyHasTrait(target.data,target.perks,"arcaneImmunity")
                local reason=nil
                if applied==0 then
                    reason=amount==0 and "No enemy defeated by this Ranged Attack."
                        or rangedVictims[target.guid] and "Target was defeated by a Ranged Attack."
                        or immune and "Fire Resistance or Arcane Immunity prevents this Armour reduction."
                        or target.attackOnly and "This enemy has no Armour."
                        or "Armour is already at its minimum of 1."
                end
                target.explosiveBoltEffects=target.explosiveBoltEffects or {}
                target.explosiveBoltEffects[#target.explosiveBoltEffects+1]={
                    key=key,guid=source.guid,earned=amount,applied=applied,reason=reason}
            end
        end
    end

    return applyExplosiveBoltRange
end

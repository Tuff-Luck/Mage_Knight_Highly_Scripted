-- Ranged/Siege and Block phase resolution; immutable earlier-phase snapshots.
return function(combatBlockResult,combatGroupEntry,combatRangeResult,combatRangeGroupEntry,
    combatBossPhasePlan,combatEnemyAttacks,combatEnemyHasTrait,combatFrozenCopy)
    local function resolve(entries,groups,allocated,emptyTarget,rangedBeforeBlock,profiler)
        local tracing=profiler~=nil and profiler.traceEnabled
        local rowBlock={}
        for _,group in ipairs(groups) do
            local members,blockedAll={},{}
            local profile
            if tracing then profile=profiler.profileStart() end
            for _,index in ipairs(group.members) do
                local entry=entries[index]
                local target=allocated[index] or emptyTarget
                local lines,damage,count,allBlocked,reductions,wrongBlock,unblocked,_,_,shieldBashExcess,
                    successfulSourceKeys,spentMoveKeys=combatBlockResult(entry,target.sources)
                rowBlock[index]={lines=lines,damage=damage,count=count,allBlocked=allBlocked,reductions=reductions,
                    wrongBlock=wrongBlock,unblocked=unblocked,shieldBashExcess=shieldBashExcess,
                    successfulSourceKeys=successfulSourceKeys,spentMoveKeys=spentMoveKeys,damageItems={}}
                blockedAll[entry.guid]=allBlocked
                members[#members+1]=entry
                for _,source in ipairs(target.sources) do
                    group.sources[#group.sources+1]=source
                end
            end
            if profile~=nil then profile=profiler.profileCheckpoint("early.resolveBlock",profile) end
            group.entry,group.attackArmour=combatGroupEntry(members,blockedAll)
            group.rangeTotal,group.rangeArmour,group.rangeDefeated,group.fortification=
                combatRangeResult(combatRangeGroupEntry(members),group.sources)
            if members[1].attackOnly then group.rangeDefeated=false end
            local plan=combatBossPhasePlan(group,entries,group.rangeTotal,"range",blockedAll)
            if plan~=nil then
                group.bossSpecial=true
                group.rangeSpent=plan.spent
                group.rangeDefeated=plan.full
                for _,index in ipairs(group.members) do
                    local member=entries[index]
                    member.bossRangeLevels=plan.reductions[member.guid] or 0
                    member.rangeDead=plan.killed[member.guid]==true
                end
            end
            if profile~=nil then profile=profiler.profileCheckpoint("early.resolveRange",profile) end
            -- Disease resolves after Block, not during Ranged/Siege. Every attack
            -- of the actual enemy must be blocked; an immune enemy gets no effect.
            if not group.rangeDefeated then
                local diseaseChanged=false
                for _,index in ipairs(group.members) do
                    local enemy=entries[index]
                    local limit=enemy.effect~=nil and enemy.effect.armourSetIfBlocked or nil
                    local blocked=rowBlock[index]
                    if limit~=nil and blocked~=nil and blocked.allBlocked
                        and #combatEnemyAttacks(enemy)>0 and not enemy.attackOnly
                        and not enemy.destroyed then
                        enemy.rangeBaseArmour=enemy.rangeBaseArmour or enemy.baseArmour
                        enemy.rangeElusiveArmour=enemy.rangeElusiveArmour or enemy.elusiveArmour
                        enemy.baseArmour=math.min(enemy.baseArmour,limit)
                        enemy.elusiveArmour=math.min(enemy.elusiveArmour,limit)
                        diseaseChanged=true
                    end
                end
                if diseaseChanged then
                    group.entry,group.attackArmour=combatGroupEntry(members,blockedAll)
                end
            end
            -- Shield Bash lowers Armour only in the later Attack phase, and only
            -- after a successful Block against that enemy's own attack. A summoned
            -- monster's Block never lowers its summoner's Armour. Ice Resistance
            -- and Arcane Immunity ignore this non-Block effect, not the Block.
            if not group.rangeDefeated then
                local bashChanged=false
                for _,index in ipairs(group.members) do
                    local enemy=entries[index]
                    local excess=(rowBlock[index].shieldBashExcess or {})[enemy.guid] or 0
                    if excess>0 and not enemy.attackOnly and not enemy.destroyed
                        and not combatEnemyHasTrait(enemy.data,enemy.perks,"iResist")
                        and not combatEnemyHasTrait(enemy.data,enemy.perks,"arcaneImmunity") then
                        local originalArmour=enemy.baseArmour
                        local originalElusive=enemy.elusiveArmour
                        local reducedArmour=math.max(1,originalArmour-excess)
                        local reducedElusive=math.max(1,originalElusive-excess)
                        if reducedArmour~=originalArmour or reducedElusive~=originalElusive then
                            enemy.rangeBaseArmour=enemy.rangeBaseArmour or originalArmour
                            enemy.rangeElusiveArmour=enemy.rangeElusiveArmour or originalElusive
                            enemy.baseArmour=reducedArmour
                            enemy.elusiveArmour=reducedElusive
                            bashChanged=true
                        end
                    end
                end
                if bashChanged then
                    group.entry,group.attackArmour=combatGroupEntry(members,blockedAll)
                end
            end
            if group.rangeDefeated then
                for _,source in ipairs(group.sources) do
                    if source.dueling then source.duelingEligible=false end
                end
            end
            if rangedBeforeBlock~=nil and not group.bossSpecial then
                -- A later Block-phase destruction cannot retrospectively win the
                -- Ranged phase or create extra Ranged-only rewards.
                group.rangeDefeated=true
                for _,index in ipairs(group.members) do
                    if rangedBeforeBlock[index]~=true then group.rangeDefeated=false break end
                end
            end
            -- A destroyed enemy has already been removed by a pre-Damage effect.
            -- Its final defeat state and any melee rewards are resolved only after
            -- the damage assignments establish which Units survive into Attack.
            group.destroyed=not members[1].attackOnly and #group.members==1
                and entries[group.members[1]].destroyed==true
            if profile~=nil then profiler.profileFinish("early.postBlockEffects",profile) end
        end
        return rowBlock
    end

    local function snapshot(entries,groups,groupOf,rowBlock,earlyLock,preview)
        -- Snapshot resolved Ranged/Siege and Block before the Damage phase.
        -- Results, not just UI labels, are retained for later recalculations.
        if earlyLock~=nil and earlyLock.earlyGroups~=nil then
            for index,group in ipairs(groups) do
                local saved=earlyLock.earlyGroups[index]
                if saved~=nil then
                    for _,field in ipairs({"rangeTotal","rangeArmour","rangeDefeated",
                        "rangeSpent","fortification","bossSpecial","attackArmour","destroyed"}) do
                        group[field]=saved[field]
                    end
                end
            end
            for index,saved in ipairs(earlyLock.earlyEntries or {}) do
                if entries[index]~=nil then
                    for field,value in pairs(saved) do
                        if field~="x" then entries[index][field]=combatFrozenCopy(value) end
                    end
                end
            end
            rowBlock=combatFrozenCopy(earlyLock.rowBlock) or rowBlock
        elseif preview~=nil then
            preview.earlyGroups=combatFrozenCopy(groups)
            preview.earlyEntries=combatFrozenCopy(entries)
            preview.rowBlock=combatFrozenCopy(rowBlock)
            preview.spentRange={}
            -- A Damage commitment freezes the actual resources spent in earlier
            -- phases, not every Block icon laid out while planning combat.
            preview.sourceKeys={}
            preview.objectKeys={}
            local sourcesByKey={}
            for _,source in ipairs(preview.sources or {}) do
                sourcesByKey[source.key]=source
            end
            local function commitEarlySource(key)
                local source=sourcesByKey[key]
                if source==nil then return end
                preview.sourceKeys[key]=true
                preview.objectKeys[source.guid]=true
            end
            for _,group in ipairs(groups) do
                if group.rangeDefeated or group.rangeSpent then
                    for _,source in ipairs(group.sources or {}) do
                        local legalRange=(source.ranged or 0)>0 and group.fortification==0
                        local legalSiege=(source.siege or 0)>0 and group.fortification<2
                        if legalRange or legalSiege then
                            preview.spentRange[source.key]=true
                            commitEarlySource(source.key)
                        end
                    end
                end
            end
            for index,block in ipairs(rowBlock) do
                local group=groupOf[index]
                local enemy=entries[index]
                if group~=nil and not group.rangeDefeated and not group.destroyed
                    and enemy~=nil and not enemy.rangeDead then
                    for key in pairs(block.successfulSourceKeys or {}) do commitEarlySource(key) end
                    for key in pairs(block.spentMoveKeys or {}) do commitEarlySource(key) end
                end
            end
        end
        return rowBlock
    end

    local function countBlockedEnemies(entries,groups,rowBlock)
        -- Counterattack counts *enemies*, not individual attacks. Multi-attack
        -- enemies (including summoners) count only when every attack was blocked.
        -- Ranged-defeated and attack-only preview tokens never count.
        local blockedEnemies=0
        for _,group in ipairs(groups) do
            if not group.rangeDefeated then
                for _,index in ipairs(group.members) do
                    local enemy=entries[index]
                    if not enemy.attackOnly and not enemy.destroyed and not enemy.rangeDead
                        and rowBlock[index]~=nil and rowBlock[index].allBlocked
                        and #combatEnemyAttacks(enemy)>0 then
                        blockedEnemies=blockedEnemies+1
                    end
                end
            end
        end
        return blockedEnemies
    end

    return {resolve=resolve,snapshot=snapshot,countBlockedEnemies=countBlockedEnemies}
end

-- Allocate enemy Defend bonuses by combat phase over fresh calculator entries.
-- Phase eligibility and effective ranged damage use the supplied production helpers.
return function(defences,combatRangeResult)
    local combatGroupEntry=defences.groupEntry
    local combatRangeGroupEntry=defences.rangeGroupEntry
    local combatEnemyFortificationCount=defences.fortificationCount

    -- Each Defend symbol may protect one attacked enemy, including a member of an
    -- attacked group. Ranged/Siege attacks are resolved first; a defender defeated
    -- in that phase cannot protect a newly attacked enemy in the Attack phase.
    -- Default ordering is left-to-right within each phase (the physical table order).
    local function combatApplyDefend(entries,groups,allocated,forkedLightningPhase)
        local defenders={}
        for index,entry in ipairs(entries) do
            entry.defendMeleeBonus=nil
            local bonus=(tonumber(entry.data.defend) or 0)+(entry.perks~=nil and (tonumber(entry.perks.defend) or 0) or 0)
            if bonus>0 and not entry.destroyed then
                defenders[#defenders+1]={index=index,bonus=bonus}
            end
        end
        if #defenders==0 then return {} end
        table.sort(defenders,function(a,b)
            if a.bonus~=b.bonus then return a.bonus>b.bonus end
            return a.index<b.index
        end)

        local groupOf,groupSources={},{}
        local rangedTargets,meleeTargets={},{}
        for _,group in ipairs(groups) do
            local members,sources={},{}
            for _,index in ipairs(group.members) do
                local entry=entries[index]
                groupOf[index]=group
                members[#members+1]=entry
                for _,source in ipairs((allocated[index] or {sources={}}).sources) do
                    sources[#sources+1]=source
                end
            end
            groupSources[group]=sources
            local grouped=combatGroupEntry(members,{})
            local fortification=combatEnemyFortificationCount(grouped.data,grouped.perks)
            local hasRanged,hasAnyAttack=false,false
            for _,index in ipairs(group.members) do
                for _,item in ipairs((allocated[index] or {details={}}).details) do
                    local family=item.detail.family
                    if family=="attack" or family=="ranged" or family=="siege" then
                        hasAnyAttack=true
                        local forkMelee=item.source.forkedLightning
                            and forkedLightningPhase=="attack"
                        if not forkMelee and ((family=="ranged" and fortification==0)
                            or (family=="siege" and fortification<2)) then
                            hasRanged=true
                        end
                    end
                end
            end
            for _,index in ipairs(group.members) do
                local entry=entries[index]
                if not entry.destroyed and not entry.attackOnly then
                    if hasRanged then rangedTargets[#rangedTargets+1]=index end
                    if hasAnyAttack then meleeTargets[#meleeTargets+1]=index end
                end
            end
        end
        -- The Ranged phase can spend any available Defender, even one whose own
        -- token will later be defeated by that Ranged attack.
        local applied,rangedBonuses,spentDefenders={},{},{}
        local slot=1
        for _,target in ipairs(rangedTargets) do
            local defender=defenders[slot]
            if defender==nil then break end
            applied[target]=defender.bonus
            rangedBonuses[target]=defender.bonus
            spentDefenders[defender.index]=true
            slot=slot+1
        end

        -- Evaluate survival with Ranged-only Defender bonuses. Do not use late
        -- Attack-phase bonuses when deciding whether a Defender survives.
        local rangedDefeated={}
        for _,group in ipairs(groups) do
            local members={}
            for _,index in ipairs(group.members) do
                local entry=entries[index]
                local bonus=rangedBonuses[index] or 0
                members[#members+1]={guid=entry.guid,data=entry.data,perks=entry.perks,
                    baseArmour=entry.baseArmour+bonus,elusiveArmour=entry.elusiveArmour+bonus,
                    rangeBaseArmour=entry.rangeBaseArmour~=nil and entry.rangeBaseArmour+bonus or nil,
                    rangeElusiveArmour=entry.rangeElusiveArmour~=nil and entry.rangeElusiveArmour+bonus or nil,
                    stripFortify=entry.stripFortify,stripResist=entry.stripResist,
                    stripFireResist=entry.stripFireResist,bossLevel=entry.bossLevel}
            end
            local grouped=combatRangeGroupEntry(members)
            local _,_,defeated=combatRangeResult(grouped,groupSources[group])
            rangedDefeated[group]=defeated and not members[1].data.attackOnly
        end

        -- Remaining Defenders may help in the regular Attack phase only if they
        -- survived Ranged/Siege, and no enemy receives more than one Defend bonus.
        for _,target in ipairs(meleeTargets) do
            if applied[target]==nil and not rangedDefeated[groupOf[target]] then
                for _,defender in ipairs(defenders) do
                    if not spentDefenders[defender.index] and not rangedDefeated[groupOf[defender.index]] then
                        applied[target]=defender.bonus
                        entries[target].defendMeleeBonus=defender.bonus
                        spentDefenders[defender.index]=true
                        break
                    end
                end
            end
        end
        for index,bonus in pairs(applied) do
            entries[index].baseArmour=entries[index].baseArmour+bonus
            entries[index].elusiveArmour=entries[index].elusiveArmour+bonus
            if entries[index].rangeBaseArmour~=nil then
                entries[index].rangeBaseArmour=entries[index].rangeBaseArmour+bonus
                entries[index].rangeElusiveArmour=entries[index].rangeElusiveArmour+bonus
            end
        end
        return applied
    end

    return combatApplyDefend
end

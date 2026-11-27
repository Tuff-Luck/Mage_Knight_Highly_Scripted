-- Attack-phase modifiers, surviving group resources and final defeat calculation.
-- The coordinator owns committed Damage, physical objects, scenario updates and rewards.
return function(combatGroupEntry,combatEnemyHasTrait,combatEnemyFortificationCount,
    combatVampiricArmourGain,combatEffectPostDamageSpecs,combatFrozenCopy,
    attackPhaseSources,combatAttackTotal,combatBossPhasePlan,resourceOps)
    -- Joined boss attacks may defeat an ordinary enemy or one head without
    -- defeating the whole group. Per-defeat bonuses count each actual kill,
    -- never every level removed from a still-living boss.
    local function enemyDefeated(entry,group,rangedOnly)
        if entry.preview or entry.attackOnly then return false end
        if entry.rangeDead or group.rangeDefeated then return true end
        if rangedOnly then return false end
        return group.defeated==true or entry.attackDead==true
            or entry.attackPhaseDestroyed==true
    end

    local function defeatedCount(entries,group,rangedOnly)
        local count=0
        for _,index in ipairs(group.members) do
            if enemyDefeated(entries[index],group,rangedOnly) then count=count+1 end
        end
        return count
    end

    local function vampiric(entries,groups,rowBlock,damageItems,damageResults)
        -- Vampiric gains Armor for Wounds added to the Hero's hand and for each
        -- Unit its own non-Psychic attacks wound. Poison's extra discard/Unit
        -- Wounds do not double this bonus. Rebuild Attack-phase Armor only:
        -- Ranged/Siege kills and Block were settled before damage.
        local vampiricByOwner={}
        for _,item in ipairs(damageItems) do
            if item.type~="M" then
                local bonus=combatVampiricArmourGain(damageResults[item.key])
                if bonus>0 then
                    vampiricByOwner[item.owner]=(vampiricByOwner[item.owner] or 0)+bonus
                end
            end
        end
        for _,group in ipairs(groups) do
            local changed=false
            local members,blockedAll={},{}
            for _,index in ipairs(group.members) do
                local entry=entries[index]
                local bonus=vampiricByOwner[entry.guid] or 0
                if bonus>0 and not entry.removeAbilities
                    and combatEnemyHasTrait(entry.data,entry.perks,"vampiric") then
                    entry.baseArmour=entry.baseArmour+bonus
                    entry.elusiveArmour=entry.elusiveArmour+bonus
                    changed=true
                end
                members[#members+1]=entry
                blockedAll[entry.guid]=rowBlock[index].allBlocked
            end
            if changed then
                group.entry,group.attackArmour=combatGroupEntry(members,blockedAll)
            end
        end
    end

    local function lateEffects(entries,groups,rowBlock,earlyLock,seatScan,postDamageSpecsAvailable)
        -- Resolve newly played enemy-targeted effects in Attack only. Their
        -- source may not undo a committed Ranged kill, Block or Wound allocation.
        -- Pre-commit sources are excluded even if their physical cards move.
        if earlyLock~=nil and seatScan~=nil and postDamageSpecsAvailable then
            local committedSources={}
            for _,source in ipairs(earlyLock.sources or {}) do
                committedSources[source.guid]=true
            end
            for _,effect in pairs(earlyLock.enemyEffects or {}) do
                for _,item in ipairs(effect.applied or {}) do
                    committedSources[item.source]=true
                end
            end
            local lateChanged=false
            for _,entry in ipairs(entries) do
                local latest=(seatScan.enemyEffects or {})[entry.guid]
                local committed=(earlyLock.enemyEffects or {})[entry.guid]
                local newEffects=combatEffectPostDamageSpecs(latest,committed,committedSources)
                for _,applied in ipairs(newEffects) do
                    local spec=applied.effective or {}
                    local contributes=false
                    local fortified=combatEnemyFortificationCount(entry.data,entry.perks)>0
                        and not entry.stripFortify
                    local reduction=fortified
                        and (tonumber(spec.armourReduceFortified)
                            or tonumber(spec.armourReduce) or 0)
                        or (tonumber(spec.armourReduce) or 0)
                    local perResist=tonumber(spec.armourReduceByResist) or 0
                    if perResist>0 then
                        for _,trait in ipairs({"pResist","fResist","iResist"}) do
                            if combatEnemyHasTrait(entry.data,entry.perks,trait) then
                                reduction=reduction+perResist
                            end
                        end
                    end
                    if reduction>0 then
                        entry.baseArmour=math.max(1,entry.baseArmour-reduction)
                        entry.elusiveArmour=math.max(1,entry.elusiveArmour-reduction)
                        entry.effectArmourReduction=(entry.effectArmourReduction or 0)+reduction
                        contributes=true
                    end
                    if spec.destroyDuringAttack==true or spec.destroy==true then
                        entry.attackPhaseDestroyed=true
                        contributes=true
                    end
                    if spec.removeResist==true then
                        entry.stripResist=true
                        contributes=true
                    end
                    if spec.removeFireResist==true then
                        entry.stripFireResist=true
                        contributes=true
                    end
                    if spec.removeTrait~=nil then
                        local updated=combatFrozenCopy(entry.data)
                        updated[spec.removeTrait]=spec.removeTrait=="defend" and 0 or false
                        entry.data=updated
                        contributes=true
                    end
                    if contributes then
                        entry.effect=entry.effect or {}
                        entry.effect.applied=entry.effect.applied or {}
                        local tagged=combatFrozenCopy(applied)
                        tagged.phaseAfterDamage=true
                        entry.effect.applied[#entry.effect.applied+1]=tagged
                        lateChanged=true
                    end
                end
            end
            if lateChanged then
                for _,group in ipairs(groups) do
                    local members,blockedAll={},{}
                    for _,index in ipairs(group.members) do
                        members[#members+1]=entries[index]
                        blockedAll[entries[index].guid]=rowBlock[index].allBlocked
                    end
                    group.entry,group.attackArmour=combatGroupEntry(members,blockedAll)
                end
            end
        end
    end

    local function dodgeAfterDamage(sources,damageResults)
        -- Damage is earlier than Attack. Do not invalidate Ranged/Siege kills or
        -- The player still confirms Wounds received outside calculated Damage.
        local dodgeWounded=false
        for _,result in pairs(damageResults) do
            if (tonumber(result.heroWounds) or 0)>0 then dodgeWounded=true break end
        end
        if dodgeWounded then
            for _,source in ipairs(sources) do
                if source.dodgeConditional then
                    source.attack=0
                    source.dodgeIneligible=true
                    if source.resources~=nil then source.resources.attack=0 end
                end
            end
        end
    end

    local function woundAttackBonuses(sources,wounds,damageItems,damageResults)
        local byEnemy,highest={},0
        for _,item in ipairs(damageItems or {}) do
            local result=(damageResults or {})[item.key]
            if item.owner~=nil and result~=nil then
                byEnemy[item.owner]=(byEnemy[item.owner] or 0)+(tonumber(result.heroWounds) or 0)
                highest=math.max(highest,byEnemy[item.owner])
            end
        end
        -- Apply only in Attack, after Damage, to fresh physical source records.
        -- Do not credit the same Wounds to manually selected bonus values or
        -- change an earlier Ranged/Siege result after the fact.
        for _,source in ipairs(sources) do
            local spec=source.combatWoundAttack
            if spec~=nil and not source.noAttackPhase and ((source.attack or 0)>0
                or source.appliedWoundAttackBonus~=nil) then
                local count=spec.singleEnemy and highest or (wounds or 0)
                local earned=math.min(math.max(0,count),spec.maxWounds)*spec.perWound*spec.copies
                local bonus=earned-(spec.baseCredit or 0)
                local field
                for _,detail in ipairs(source.details or {}) do
                    if detail.family=="attack" and ((source.resources[detail.key] or 0)>0
                        or source.appliedWoundAttackBonus~=nil) then
                        if field~=nil then field=nil break end
                        field=detail
                    end
                end
                if field~=nil then
                    local delta=bonus-(source.appliedWoundAttackBonus or 0)
                    source.resources[field.key]=source.resources[field.key]+delta
                    source.attack=source.attack+delta
                    field.amount=field.amount+delta
                    field.woundAttackLabel=field.woundAttackLabel
                        or field.text:match("^(.-)%s+%d+$") or "Attack"
                    field.text=field.woundAttackLabel.." "..tostring(field.amount)
                        ..(bonus>0 and (" (+"..tostring(bonus).." from Wounds)") or "")
                    source.appliedWoundAttackBonus=bonus
                    if spec.singleEnemy then
                        source.dodgeIneligible=earned==0
                        field.text=field.woundAttackLabel.." "..tostring(field.amount)
                            .." (Wounds from one enemy)"
                    end
                end
            end
        end
    end

    local function distinctAttackBonuses(group,sources)
        local skill
        for _,source in ipairs(sources) do
            if source.distinctAttackBonus~=nil then skill=source break end
        end
        if skill==nil then return end
        if #group.members~=1 then
            -- Coordinated Attack cannot participate in a joined attack.
            skill.attack=0
            skill.dodgeIneligible=true
            for key in pairs(skill.resources or {}) do
                if key:sub(1,6)=="attack" then skill.resources[key]=0 end
            end
            return
        end
        if group.rangeDefeated or group.rangeSpent or group.destroyed then return end
        -- Compare the original printed/current values, never the already
        -- increased values. One bonus per distinct value, excluding Attack 1
        -- from the Skill itself. Stable source order resolves equal values.
        local skillValue=skill.attack or 1
        if resourceOps~=nil then
            for _,detail in ipairs(skill.details or {}) do
                skillValue=skillValue+resourceOps.phaseAttackBonus(skill,detail.key,"attack")
            end
        end
        local seen={[skillValue]=true}
        local ordered={}
        for _,source in ipairs(sources) do
            if source~=skill and source.distinctAttackBonus==nil then ordered[#ordered+1]=source end
        end
        table.sort(ordered,function(a,b) return tostring(a.key)<tostring(b.key) end)
        for _,source in ipairs(ordered) do
            for _,detail in ipairs(source.details or {}) do
                local family=detail.family
                local amount=tonumber(source.resources[detail.key]) or 0
                local effective=amount+(resourceOps~=nil and
                    resourceOps.phaseAttackBonus(source,detail.key,"attack") or 0)
                if (family=="attack" or family=="ranged" or family=="siege")
                    and amount>0 and not seen[effective] then
                    seen[effective]=true
                    local bonus=skill.distinctAttackBonus
                    source.resources[detail.key]=amount+bonus
                    source[family]=(source[family] or 0)+bonus
                    detail.amount=amount+bonus
                    detail.text=(detail.text:match("^(.-)%s+%d+$") or detail.text)
                        .." +"..tostring(bonus).." (Coordinated Attack)"
                end
            end
        end
    end

    local function resolve(entries,groups,rowBlock,woundedBeforeAttack,paralysisAttackCards,forkedLightningPhase)
        local defeatFame,defeatRep=0,0
        -- Tornado resolves after enemy Damage. A grouped target is removed from
        -- only the later Attack calculation; surviving group members keep Armour.
        for _,group in ipairs(groups) do
            if not group.rangeDefeated and not group.destroyed then
                local surviving,blockedAll={},{}
                for _,index in ipairs(group.members) do
                    local entry=entries[index]
                    if not entry.attackPhaseDestroyed and not entry.rangeDead then
                        surviving[#surviving+1]=entry
                        blockedAll[entry.guid]=rowBlock[index].allBlocked
                    end
                end
                if #surviving==0 then
                    group.destroyed=true
                elseif #surviving<#group.members then
                    group.entry,group.attackArmour=combatGroupEntry(surviving,blockedAll)
                end
            end
        end
        for _,group in ipairs(groups) do
            local available=attackPhaseSources(group.sources,woundedBeforeAttack,paralysisAttackCards)
            local meleeSources={}
            for _,source in ipairs(available) do
                if not source.forkedLightning
                    or (forkedLightningPhase=="attack") then
                    meleeSources[#meleeSources+1]=source
                end
            end
            -- Ranged/Siege points that already reduced a boss cannot be played
            -- as melee Attack a second time. Unspent ranged resources still have
            -- their ordinary fallback to the later Attack phase.
            local laterSources=meleeSources
            if group.bossSpecial and group.rangeSpent then
                laterSources={}
                for _,source in ipairs(meleeSources) do
                    local resources={}
                    for key,value in pairs(source.resources or {}) do
                        local spent=(key:sub(1,6)=="ranged" and group.fortification==0)
                            or (key:sub(1,5)=="siege" and group.fortification<2)
                        if not spent then resources[key]=value end
                    end
                    laterSources[#laterSources+1]=setmetatable({resources=resources},{__index=source})
                end
            end
            distinctAttackBonuses(group,laterSources)
            local meleeTotal=combatAttackTotal({
                {sources=laterSources,category="attack"},
                {sources=laterSources,category="ranged"},
                {sources=laterSources,category="siege"}},group.entry.data,group.entry.perks,"attack")
            group.attackTotal=meleeTotal
            group.defeated=not entries[group.members[1]].attackOnly
                and (group.rangeDefeated or (meleeTotal>0 and meleeTotal>=group.attackArmour))
            if group.bossSpecial then
                local blockedAll={}
                for _,index in ipairs(group.members) do
                    blockedAll[entries[index].guid]=rowBlock[index].allBlocked
                end
                local plan=not group.rangeDefeated
                    and combatBossPhasePlan(group,entries,meleeTotal,"attack",blockedAll) or nil
                for _,index in ipairs(group.members) do
                    local member=entries[index]
                    member.bossAttackLevels=plan~=nil and (plan.reductions[member.guid] or 0) or 0
                    member.attackDead=plan~=nil and plan.killed[member.guid]==true
                end
                group.defeated=group.rangeDefeated or (plan~=nil and plan.full==true)
            end
            if group.destroyed then group.defeated,group.rangeDefeated=true,false end
            if (group.defeated or group.bossSpecial) and not group.destroyed then
                local count=defeatedCount(entries,group,false)
                local rangedCount=defeatedCount(entries,group,true)
                local counted={}
                for _,source in ipairs(group.sources) do
                    local spec=source.defeatFameRep
                    local availableInFinalPhase=woundedBeforeAttack[source.guid]~=true
                    if count>0 and spec~=nil and spec.scope==nil
                        and not counted[source.guid] and (
                            (rangedCount>0 and (source.ranged>0 or source.siege>0))
                            or (count>rangedCount and availableInFinalPhase)) then
                        counted[source.guid]=true
                        local times=spec.once and 1 or count
                        defeatFame=defeatFame+(spec.fame or 0)*times
                        defeatRep=defeatRep+(spec.rep or 0)*times
                    end
                end
            end
        end
        return defeatFame,defeatRep
    end

    return {enemyDefeated=enemyDefeated,defeatedCount=defeatedCount,vampiric=vampiric,lateEffects=lateEffects,
        dodgeAfterDamage=dodgeAfterDamage,woundAttackBonuses=woundAttackBonuses,
        distinctAttackBonuses=distinctAttackBonuses,resolve=resolve}
end

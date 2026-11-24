-- Allocate one shared Attack budget to ordinary enemies and remaining boss levels.
-- Manual overrides are supplied by the coordinator; this module owns no saved state.
return function(combatEnemyHasTrait)
    -- Whole multiples of effective Armour remove levels of either boss type.
    local function combatBossLevelCount(total,armour,remaining)
        local a=math.max(1,tonumber(armour) or 1)
        return math.max(0,math.min(math.max(0,tonumber(remaining) or 0),
            math.floor(math.max(0,tonumber(total) or 0)/a)))
    end

    -- Joined attacks reserve one Armour for every living ordinary enemy and
    -- one Armour/level for each boss, then allocate spare points to further
    -- reductions. Never spend the same Attack points independently on two heads.
    local function combatBossPhasePlan(group,entries,total,phase,blockedAll,manual)
        manual=manual or {}
        local bosses,ordinary={},{}
        local anyBoss=false
        for _,index in ipairs(group.members) do
            local entry=entries[index]
            if entry.bossLevel~=nil and entry.bossType~="control" then anyBoss=true end
            if not entry.attackOnly and not entry.destroyed
                and (phase=="range" or not entry.rangeDead) then
                local remaining=entry.bossLevel~=nil
                    and math.max(0,entry.bossLevel-(phase=="attack"
                        and (entry.bossRangeLevels or 0) or 0)) or 1
                if remaining>0 then
                    local elusive=combatEnemyHasTrait(entry.data,entry.perks,"elusive")
                    local armour
                    if phase=="range" then
                        armour=elusive and (entry.rangeElusiveArmour or entry.elusiveArmour)
                            or (entry.rangeBaseArmour or entry.baseArmour)
                        armour=armour-(entry.defendMeleeBonus or 0)
                    else
                        armour=elusive and not (blockedAll or {})[entry.guid]
                            and entry.elusiveArmour or entry.baseArmour
                    end
                    local item={entry=entry,armour=math.max(1,armour),remaining=remaining}
                    if entry.bossLevel~=nil then bosses[#bosses+1]=item
                    else ordinary[#ordinary+1]=item end
                end
            end
        end
        if not anyBoss then return nil end
        local result={reductions={},killed={},spent=false}
        local required=0
        for _,item in ipairs(bosses) do required=required+item.armour end
        for _,item in ipairs(ordinary) do required=required+item.armour end
        local points=math.max(0,tonumber(total) or 0)
        if required>0 and points>=required then
            points=points-required
            for _,item in ipairs(ordinary) do result.killed[item.entry.guid]=true end
            for _,item in ipairs(bosses) do result.reductions[item.entry.guid]=1 end
            table.sort(bosses,function(a,b)
                local am=manual[a.entry.guid]~=nil
                local bm=manual[b.entry.guid]~=nil
                if am~=bm then return am end
                if a.entry.x~=b.entry.x then return a.entry.x<b.entry.x end
                return a.entry.guid<b.entry.guid
            end)
            for pass=1,2 do
                for _,item in ipairs(bosses) do
                    local guid=item.entry.guid
                    local current=result.reductions[guid] or 0
                    local extra=math.min(item.remaining-current,math.floor(points/item.armour))
                    if pass==1 then
                        local target=manual[guid]
                        if target==nil then extra=0
                        else
                            extra=math.min(extra,math.max(0,target
                                -(phase=="attack" and (item.entry.bossRangeLevels or 0) or 0)
                                -current))
                        end
                    end
                    if extra>0 then
                        result.reductions[guid]=current+extra
                        points=points-extra*item.armour
                    end
                end
            end
        end
        -- In a single-target attack the player may explicitly correct an
        -- unrecognised effect. Extra corrections belong to the later Attack
        -- phase so that Block/Damage timing is not rewritten retroactively.
        if #group.members==1 and #bosses==1 then
            local item=bosses[1]
            local target=manual[item.entry.guid]
            if target~=nil then
                if phase=="range" then
                    result.reductions[item.entry.guid]=math.min(target,
                        result.reductions[item.entry.guid] or 0)
                else
                    result.reductions[item.entry.guid]=math.min(item.remaining,
                        math.max(0,target-(item.entry.bossRangeLevels or 0)))
                end
            end
        end
        for _,item in ipairs(bosses) do
            local value=result.reductions[item.entry.guid] or 0
            if value>0 then result.spent=true end
            if value>=item.remaining then result.killed[item.entry.guid]=true end
        end
        if #ordinary>0 and next(result.killed)~=nil then result.spent=true end
        result.full=true
        for _,index in ipairs(group.members) do
            local entry=entries[index]
            if not entry.attackOnly and not entry.destroyed and not entry.rangeDead
                and not result.killed[entry.guid] then result.full=false break end
        end
        return result
    end

    return {levelCount=combatBossLevelCount,phasePlan=combatBossPhasePlan}
end

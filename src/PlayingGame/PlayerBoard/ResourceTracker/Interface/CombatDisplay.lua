-- Combat result formatting and grouped icon layout; does not alter combat assignments.
return function(combatConfig,combatRich,combatEnemyTraitsText)
    -- Short notes under an attack's line: what each chosen Unit took and what is left for the Hero.
    local function combatDamageNotes(item,result)
        local wounds,resisted,destroyed,forced={},{},{},{}
        for _,entry in ipairs(result.units) do
            local name=entry.unit.name
            if entry.wounded then
                wounds[#wounds+1]=name..((entry.wounds or 1)>1 and
                    (" ("..tostring(entry.wounds)..")") or "")
            else
                resisted[#resisted+1]=name
            end
            if entry.destroyed then destroyed[#destroyed+1]=name end
            if entry.forced then forced[#forced+1]=name end
        end
        if result.heroWounds>0 then
            wounds[#wounds+1]="Hero ("..tostring(result.heroWounds)..")"
        end
        local distribution="Wounds: "..(#wounds>0 and table.concat(wounds,", ") or "None")
        if result.discard>0 then
            distribution=distribution.." Poison ("..tostring(result.discard)..")"
        end
        if result.veilWoundIgnored then distribution=distribution.." (Veil of Mist: 1 Wound ignored)" end
        if (result.heroWoundsIgnored or 0)>0 then
            distribution=distribution.." (Hero protection: "..tostring(result.heroWoundsIgnored)
                .." Wound"..(result.heroWoundsIgnored==1 and "" or "s").." ignored)"
        end
        local notes={distribution}
        if (result.prevented or 0)>0 then
            notes[#notes+1]="Battle Hardened: -"..tostring(result.prevented).." Hero damage"
        end
        if (result.elementPrevented or 0)>0 then
            notes[#notes+1]="Elemental Resistance: -"..tostring(result.elementPrevented).." Hero damage"
        end
        if #resisted>0 then notes[#notes+1]="Resisted (no Wound): "..table.concat(resisted,", ") end
        if #destroyed>0 then notes[#notes+1]="Destroyed (Paralyse): "..table.concat(destroyed,", ") end
        if #forced>0 then notes[#notes+1]="Must take damage first: "..table.concat(forced,", ") end
        if item.assassination then notes[#notes+1]="Assassination" end
        if result.paralyse then notes[#notes+1]="Paralyse: discard hand" end
        return notes
    end

    -- Preserve the original Result button and expansion wiring for stable layout.
    -- Full per-source results are now the default display, without abbreviated text.
    local function combatCompactResultLines(fullLines,damageItems,damageResults)
        -- Keep the original Result button, layout, and expansion plumbing intact.
        -- The concise per-source breakdown is already the full display; do not
        -- abbreviate it or append expandable [+]/[-] indicators.
        return fullLines
    end

    -- Defence text of one member of a multi-enemy group: fortification and resistances are shared by the whole group.
    local function combatGroupTraitsText(entry,groupEntry)
        local data={elusive=entry.data.elusive,arcaneImmunity=entry.data.arcaneImmunity,defend=entry.data.defend,
            fortified=groupEntry.data.fortified,unfortified=entry.data.unfortified}
        local perks={defend=entry.perks~=nil and entry.perks.defend or nil,
            elusive=entry.perks~=nil and entry.perks.elusive or nil,
            arcaneImmunity=entry.perks~=nil and entry.perks.arcaneImmunity or nil,
            unfortified=entry.perks~=nil and entry.perks.unfortified or nil,
            wallFortified=groupEntry.perks.wallFortified}
        for _,key in ipairs({"pResist","fResist","iResist","mResist"}) do data[key]=groupEntry.data[key] end
        return combatEnemyTraitsText(data,perks,combatConfig.enemyDefenceTraits)
    end

    local function combatGroupAttackLine(meleeTotal,attackArmour)
        -- Render the same post-Damage total used by the defeat decision. Recounting
        -- the original sources would re-include Wounded Units in the Result text.
        if meleeTotal<=0 then return nil end
        local line="Attack "..tostring(meleeTotal).."/"..tostring(attackArmour)
        return meleeTotal>=attackArmour and (line.." "..combatRich("Defeated",combatConfig.COMBAT_GREEN)) or line
    end

    -- Distribute a joined group's display icons without changing resource assignments.
    -- Attack/Ranged resources are shared by the group; Block stays on its owning
    -- enemy row first, with excess icons continuing into free slots below it.
    -- An ungrouped enemy has just one member and cannot spill into another enemy.
    local function combatGroupResourceRows(members,perMember,limit)
        local rows,overflow={},0
        for _,index in ipairs(members) do rows[index]={range={},block={},attack={}} end
        for _,family in ipairs({"range","attack"}) do
            local count=0
            for _,index in ipairs(members) do
                for _,item in ipairs(perMember[index][family]) do
                    count=count+1
                    local targetIndex=members[math.floor((count-1)/limit)+1]
                    if targetIndex~=nil then
                        local display=rows[targetIndex][family]
                        display[#display+1]=item
                    else
                        overflow=overflow+1
                    end
                end
            end
        end
        local pending,head={},1
        for _,index in ipairs(members) do
            local display=rows[index].block
            for i,item in ipairs(perMember[index].block) do
                if i<=limit then display[#display+1]=item
                else pending[#pending+1]=item end
            end
            while #display<limit and pending[head]~=nil do
                display[#display+1]=pending[head]
                head=head+1
            end
        end
        return rows,overflow+(#pending-head+1)
    end

    return {damageNotes=combatDamageNotes,compactResultLines=combatCompactResultLines,
        groupTraitsText=combatGroupTraitsText,groupAttackLine=combatGroupAttackLine,
        groupResourceRows=combatGroupResourceRows}
end

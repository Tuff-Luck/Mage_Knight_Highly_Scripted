-- Presentation of targeted combat effects and Hero damage mitigation.
-- Caller supplies attack/trait evaluations, classification, and live source names.
return function(defences,combatEnemyAttacks,combatEnemyPrintedAttacks,
    combatEffectArrowKind,combatEffectRequiresDefence,skillRuleOf,sourceNameOf)
    local combatEnemyFortificationCount=defences.fortificationCount
    local combatEnemyHasTrait=defences.hasTrait

    -- The same two colours as existing resource slots: normal grey, or the
    -- existing red used for a Wounded/unavailable assignment. Effect metadata
    -- comes from CombatEffects rather than skill-specific table-button branches.
    local function effectButtonInfo(entry,applied)
        local spec,actual=applied.spec or {},applied.effective or {}
        if spec.all==true then return nil end
        local printedFortified=combatEnemyFortificationCount(entry.data,entry.perks)>0
        local fortified=printedFortified
            and (entry.effect==nil or entry.effect.removeFortify~=true)
        local fortifiedWhenCast=fortified
            or (spec.armourBeforeFortificationRemoval==true and (entry.originalFortification or 0)>0)
        local armour=tonumber(spec.armourReduce) or 0
        local armourFortified=tonumber(spec.armourReduceFortified) or armour
        local resistArmour=tonumber(spec.armourReduceByResist) or 0
        local attack=tonumber(spec.attackReduce) or 0
        local isArmour=armour>0 or armourFortified>0 or resistArmour>0
            or spec.removeFortify==true or spec.removeResist==true
            or spec.removeFireResist==true or spec.destroy==true or spec.destroyDuringAttack==true
        local isBlock=attack>0 or spec.noAttack==true or spec.noAttackUnfortified==true
            or spec.cancelOneAttack==true
            or spec.removeAbilities==true or spec.removeOneAttackAbilities==true
            or spec.destroyIfBlocked==true or spec.destroyIfFullyBlocked==true
        local attackIncrease=tonumber(spec.attackIncrease) or 0
        local special=spec.removeTrait~=nil or spec.convertAttack~=nil or attackIncrease>0
        if not isArmour and not isBlock and not special then return nil end
        local family=isArmour and (fortified and "attack" or "range") or "block"
        if (tonumber(spec.armourReduceAttackOnly) or 0)>0 or spec.destroyDuringAttack then family="attack" end
        if spec.removeTrait~=nil then
            family=(spec.removeTrait=="fortified" or spec.removeTrait=="elusive"
                or spec.removeTrait=="pResist" or spec.removeTrait=="fResist"
                or spec.removeTrait=="iResist" or spec.removeTrait=="mResist"
                or spec.removeTrait=="defend") and "attack" or "block"
        end
        local arrow=combatEffectArrowKind(spec)
        local icon=isArmour and "MKChoiceAttack" or "MKChoiceBlock"
        -- Use specific artwork for numeric reductions, preserving the usual icons
        -- for removal, prevention, conversion and other non-reduction effects.
        if armour>0 or armourFortified>0 or resistArmour>0 then
            icon="MKChoiceArmourReduction"
        elseif attack>0 then
            icon="MKChoiceAttackReduction"
        end
        local amount,description,reason="!", "Combat effect",nil
        local raw=entry.unmodifiedArmour or entry.baseArmour or 1
        if spec.cancelOneAttack==true then
            amount="X"
            description="Cancel one printed enemy Attack"
            if actual.cancelOneAttack~=true then
                reason=applied.immune and "Arcane Immunity ignores this effect."
                    or "This attack cannot be cancelled."
            end
        elseif spec.removeTrait~=nil then
            amount="X"
            description="Ignore printed "..tostring(spec.removeTrait)
            if actual.removedPrinted==nil or actual.removedPrinted[spec.removeTrait]~=true then
                reason="The printed ability was not removed."
            end
        elseif spec.convertAttack~=nil then
            amount="→"
            description="Convert attack "..tostring(spec.convertAttack.slot)
                .." from "..tostring(spec.convertAttack.from).." to "..tostring(spec.convertAttack.to)
            if #(actual.attackConversions or {})==0 then
                reason="No attack element was changed."
            end
        elseif attackIncrease>0 then
            amount="+"..tostring(attackIncrease)
            description="Enemy Attack +"..tostring(attackIncrease)
                ..", Armour -"..tostring(armour).." in Attack phase if it attacks"
            if #combatEnemyAttacks(entry)==0 then reason="The enemy has no attack." end
        elseif isArmour and (armour>0 or armourFortified>0 or resistArmour>0) then
            local appliedReduction=fortifiedWhenCast and
                (tonumber(actual.armourReduceFortified) or tonumber(actual.armourReduce) or 0)
                or (tonumber(actual.armourReduce) or 0)
            if (tonumber(actual.armourReduceByResist) or 0)>0 then
                local count=0
                for _,trait in ipairs({"pResist","fResist","iResist"}) do
                    if combatEnemyHasTrait(entry.data,entry.perks,trait) then count=count+1 end
                end
                appliedReduction=appliedReduction+count*actual.armourReduceByResist
            end
            local total=entry.effectArmourReduction or 0
            local before=math.max(1,raw-math.max(0,total-appliedReduction))
            local after=math.max(1,raw-total)
            local printed=fortifiedWhenCast and armourFortified or armour
            amount="-"..tostring(math.max(printed,appliedReduction))
            description="Armour reduction "..amount
            if spec.noAttack==true then description=description.."; prevent enemy Attack" end
            if spec.armourBeforeFortificationRemoval==true then
                description=description.." (Earthquake before fortification removal)"
            end
            if appliedReduction==0 then
                reason=applied.fireResistant and "Fire Resistance ignores this red effect."
                    or (applied.iceResistant and "Ice Resistance ignores this blue effect.")
                    or (applied.immune and "Arcane Immunity ignores this Armour effect.")
                    or "This Armour reduction is not applicable to the target."
            elseif before<=after then reason="Armour is already at its minimum of 1 (or other effects have reached it)."
            elseif fortified and (tonumber(spec.armourReduceRangedUnfortifiedOnly) or 0)>0 then
                description=description.." (Attack phase only while Fortified)"
            end
        elseif attack>0 then
            amount="-"..tostring(attack)
            description="Enemy Attack reduction "..amount
                ..(spec.grantCumbersome==true and "; gains Cumbersome" or "")
            -- Compare attacks with and without this source's reduction. Zero printed
            -- attacks, already-cancelled attacks, and duplicate reductions turn red.
            local with=combatEnemyAttacks(entry)
            local original=entry.effect
            local without={}
            for key,value in pairs(original or {}) do without[key]=value end
            without.attackReductions={}
            for _,reduction in ipairs(original~=nil and original.attackReductions or {}) do
                if reduction.source~=applied.source then
                    without.attackReductions[#without.attackReductions+1]=reduction
                end
            end
            entry.effect=without
            local before=combatEnemyAttacks(entry)
            entry.effect=original
            local reduced=false
            for i,attackEntry in ipairs(with) do
                if before[i]~=nil and (tonumber(before[i].value) or 0)>
                    (tonumber(attackEntry.value) or 0) then reduced=true break end
            end
            if not reduced then reason="No attack value is reduced: the target has no applicable attack or is already at 0."
            end
        elseif spec.removeFortify==true then
            description="Remove Fortification"
            if actual.removeFortify~=true then reason="Arcane Immunity ignores Remove Fortification."
            elseif combatEnemyFortificationCount(entry.data,entry.perks)==0 then
                reason="This enemy has no Fortification to remove." end
        elseif spec.removeResist==true or spec.removeFireResist==true then
            description=spec.removeResist and "Remove Resistances" or "Remove Fire Resistance"
            local relevant=false
            for _,trait in ipairs(spec.removeResist and {"pResist","fResist","iResist","mResist"}
                or {"fResist"}) do
                if combatEnemyHasTrait(entry.data,entry.perks,trait) then relevant=true end
            end
            if applied.iceResistant then
                reason="Ice Resistance ignores this blue effect."
            elseif applied.fireResistant then
                reason="Fire Resistance ignores this red effect."
            elseif (spec.removeResist and actual.removeResist~=true)
                or (spec.removeFireResist and actual.removeFireResist~=true) then
                reason="Arcane Immunity ignores this resistance effect."
            elseif not relevant then reason="The enemy has no applicable Resistance." end
        elseif spec.noAttack==true or spec.noAttackUnfortified==true then
            description="Prevent enemy Attack"
            if spec.moveCost~=nil then
                description=description.." (Wings of Night: "..tostring(spec.moveCost).." Move)"
            end
            if spec.insufficientMove then
                reason="Not enough unspent Move points for this Wings of Night target."
            elseif not actual.noAttack and not actual.noAttackUnfortified then
                reason=applied.iceResistant and "Ice Resistance ignores this blue effect."
                    or (applied.fireResistant and "Fire Resistance ignores this red effect.")
                    or "Arcane Immunity ignores this prevention effect."
            elseif spec.noAttackUnfortified and fortified then
                reason="The target is still Fortified."
            elseif #combatEnemyPrintedAttacks(entry.data,entry.perks,entry.removeAbilities,entry.guid)==0 then
                reason="The enemy has no attack to prevent." end
        elseif spec.destroyIfFullyBlocked==true then
            description="Destroy target if all its attacks are successfully Blocked"
            if applied.immune or actual.destroyIfFullyBlocked~=true then
                reason="Arcane Immunity prevents this destruction."
            elseif entry.destroyed~=true then
                reason="Not all attacks from this enemy were successfully Blocked."
            end
        elseif spec.destroyIfBlocked==true then
            description="Destroy if this Spell successfully Blocks an attack"
            if applied.fireResistant then reason="Fire Resistance prevents this destruction."
            elseif applied.immune then reason="Arcane Immunity prevents this destruction."
            elseif entry.destroyed~=true then
                reason="This Fire Block has not been used in a successful Block."
            end
        elseif spec.removeOneAttackAbilities==true then
            amount="X"
            description="Chosen attack loses abilities, but keeps its element. Select the attack in the enemy row."
            if actual.removeOneAttackAbilities~=true then
                reason=applied.iceResistant and "Ice Resistance prevents this effect."
                    or "This attack ability effect is unavailable."
            end
        elseif spec.removeAbilities==true then
            description="Remove Attack Abilities"
            if actual.removeAbilities~=true then reason="Arcane Immunity ignores this effect." end
        elseif spec.destroy==true then
            description="Destroy enemy"
            if entry.destroyed~=true then reason="This effect is not destroying the enemy." end
        elseif spec.destroyDuringAttack==true then
            description="Destroy enemy during Attack phase"
            if actual.destroyDuringAttack~=true then
                reason=applied.fireResistant and "Fire Resistance prevents this destruction."
                    or "Arcane Immunity prevents this destruction."
            end
        end
        local name=sourceNameOf(applied.source)
        local tooltip=name..": "..description..(reason~=nil and ("\nNo benefit: "..reason) or "")
            .."\nClick to select, then click a cell in the enemy row to retarget."
        return {source={guid=applied.source,key=applied.key,name=name},
            family=family,arrow=arrow,requiresDefence=combatEffectRequiresDefence(spec),
            amount=amount,icon=icon,
            text=description,tooltip=tooltip,ineffective=reason~=nil}
    end

    local function mitigationButtonInfo(guid,record,entry,group,damageResults,mitigation)
        if record.enemyGUID~=entry.guid then return nil end
        local rule=skillRuleOf(guid)
        local spec=rule~=nil and rule.damageMitigation or nil
        if spec==nil then return nil end
        local resolved=mitigation~=nil and mitigation.appliedKey~=nil
            and damageResults~=nil and damageResults[mitigation.appliedKey] or nil
        local elemental=spec.fire~=nil or spec.ice~=nil
        local prevented=resolved~=nil and (tonumber(elemental and resolved.elementPrevented or resolved.prevented) or 0) or 0
        local reason=nil
        if prevented==0 then
            if group.rangeDefeated or group.destroyed then
                reason="The enemy was already defeated before the Damage phase."
            else reason="No Hero damage was prevented. The chosen attack may be blocked or its damage assigned to Units." end
        end
        local name=sourceNameOf(guid)
        local tooltip=elemental
            and (name..": Prevent 2 Fire/Ice or 1 Cold Fire/Physical/Psychic Hero damage from one attack.")
            or (name..": Prevent "..tostring(spec.physical or 2)
                .." Physical or "..tostring(spec.nonphysical or 1)
                .." non-Physical damage reaching the Hero from one attack.")
            .."\nCurrently prevents "..tostring(prevented).." Hero damage."
            ..(reason~=nil and ("\nNo benefit: "..reason) or "")
            .."\nSelect the button then click an enemy row to retarget."
        return {source={guid=guid,key=guid,name=name},family="block",arrow="other",requiresDefence=false,
            amount=tostring(prevented>0 and prevented or (elemental and 2 or (spec.physical or 2))),
            icon="MKChoiceBlock",text="Hero damage prevention",tooltip=tooltip,
            ineffective=reason~=nil}
    end

    return {effectButtonInfo=effectButtonInfo,mitigationButtonInfo=mitigationButtonInfo}
end

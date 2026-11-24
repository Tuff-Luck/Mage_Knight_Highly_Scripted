-- Attack-phase eligibility and conservative selection of staged cards to discard.
-- The coordinator owns the combat snapshot, physical card disposal and saved state.
return function(combatConfig,scanOf,cardDataOf,cardRuleOf,objectOf)
    -- Attack-phase eligibility comes from the preceding damage phase, never the
    -- eventual melee result. This breaks the apparent ranged/damage/melee feedback
    -- loop: ranged kills and Block are frozen before Unit wounds are evaluated.
    local function unitsWoundedByDamage(results)
        local wounded={}
        for _,result in pairs(results or {}) do
            for _,entry in ipairs(result.units or {}) do
                if entry.wounded==true and entry.unit~=nil then wounded[entry.unit.guid]=true end
            end
        end
        return wounded
    end

    -- Unit resources already spent in the Ranged/Block phases stand. Unused
    -- Ranged/Siege effects fall back to normal Attack only if their Unit survived
    -- damage unwounded; a wound cannot retroactively undo an earlier phase.
    -- Knockout and an unblocked Paralyzing Wound both discard non-Wound hand
    -- cards before Attack. Backwards-planned card Attacks therefore cannot count
    -- while earlier Range/Siege/Block and surviving Unit/Skill actions still do.
    -- Cards genuinely played *after* committed Damage remain legal.
    local function paralysisAttackCards(sources,results,lock,knockout)
        local heroParalyzed=knockout==true
        for _,result in pairs(results or {}) do
            if result.paralyse==true and (tonumber(result.heroWounds) or 0)>0 then
                heroParalyzed=true
                break
            end
        end
        if not heroParalyzed then return {} end
        local preDamageCards={}
        for _,source in ipairs(lock~=nil and lock.sources or {}) do
            if source.kind=="card" then preDamageCards[source.guid]=true end
        end
        -- Cards actually played in earlier phases survive Knockout/Paralysis.
        -- This includes Burning Shield's Attack earned from a successful Block.
        local previous=lock or combatConfig.phasePreview
        local alreadyPlayed={}
        for guid in pairs(previous~=nil and previous.objectKeys or {}) do
            alreadyPlayed[guid]=true
        end
        -- Some early effects have no numeric source (e.g. Exploding Shield).
        for _,effect in pairs(previous~=nil and previous.enemyEffects or {}) do
            for _,applied in ipairs(effect.applied or {}) do
                if applied.phaseAfterDamage~=true and applied.source~=nil then
                    alreadyPlayed[applied.source]=true
                end
            end
        end
        local unavailable={}
        for _,source in ipairs(sources or {}) do
            if source.kind=="card" and not alreadyPlayed[source.guid]
                and (lock==nil or source.phaseAfterDamage~=true
                    or preDamageCards[source.guid]==true) then
                unavailable[source.guid]=true
            end
        end
        return unavailable
    end

    -- Only auto-discard unambiguously Attack-only staged physical cards.
    -- Inspect ALL sources with the same physical GUID; no single split-target
    -- resource is allowed to pull an earlier Block/Ranged/conditional card away.
    local function knockoutStagedAttackCards(sources,unavailable,seat,phase)
        local protected,hasAttack={},{}
        for _,source in ipairs(sources or {}) do
            if source.kind=="card" and source.guid~=nil then
                local guid=source.guid
                if (source.attack or 0)>0 then hasAttack[guid]=true end
                if (source.block or 0)>0 or (source.move or 0)>0
                    or (source.psychicInfluence or 0)>0
                    or (source.ranged or 0)>0 or (source.siege or 0)>0
                    or source.conditionalFireAttack~=nil
                    or source.conditionalCounterattack~=nil then
                    protected[guid]=true
                end
            end
        end
        local snapshot=phase or combatConfig.phasePreview
        for guid in pairs(snapshot~=nil and snapshot.objectKeys or {}) do
            protected[guid]=true
        end
        for _,effect in pairs(snapshot~=nil and snapshot.enemyEffects or {}) do
            for _,applied in ipairs(effect.applied or {}) do
                if applied.source~=nil then protected[applied.source]=true end
            end
        end
        local scan=scanOf(seat)
        for guid,record in pairs(scan~=nil and scan.cards or {}) do
            if record.kind=="card" then
                local data=cardDataOf(guid)
                local rule=data~=nil and cardRuleOf(data.resourceKey) or nil
                if record.complete~=true or record.status=="yellow"
                    or #(record.links or {})>0 or record.enemyGUID~=nil
                    or #(record.enemyEffectTargetKeys or {})>0
                    or record.conditionalFireAttack~=nil
                    or record.combatConversion~=nil
                    or record.fameRep~=nil or record.defeatFameRep~=nil
                    or (rule~=nil and (rule.enemyEffect~=nil
                        or rule.movementEffects~=nil
                        or rule.unitCombatBoost~=nil
                        or rule.preventUnitDamage==true)) then
                    protected[guid]=true
                end
                -- "Pure Attack" means the currently selected, fully understood
                -- resource has no other usable family, even if the calculator
                -- only drew its Attack icon.
                for field,amount in pairs(record.resources or {}) do
                    if type(field)=="string" and type(amount)=="number"
                        and amount>0 and field:sub(1,6)~="attack" then
                        protected[guid]=true
                        break
                    end
                end
            end
        end
        local eligible={}
        for guid in pairs(hasAttack) do
            local record=scan~=nil and scan.cards or nil
            if unavailable[guid]==true and protected[guid]~=true
                and record~=nil and record[guid]~=nil
                and record[guid].complete==true then
                local obj=objectOf(guid)
                local data=cardDataOf(guid)
                if obj~=nil and obj.type=="Card" and obj.is_face_down~=true
                    and obj.getGMNotes~=nil and obj.getGMNotes()~="Wound"
                    and data~=nil and data.cardType~="Artifact" then
                    eligible[#eligible+1]=guid
                end
            end
        end
        table.sort(eligible)
        return eligible
    end

    local function attackPhaseSources(sources,wounded,paralysisCards)
        local active={}
        for _,source in ipairs(sources or {}) do
            if wounded[source.guid]~=true and not source.noAttackPhase
                and not (paralysisCards~=nil and paralysisCards[source.guid]==true) then
                active[#active+1]=source
            end
        end
        return active
    end

    return {unitsWoundedByDamage=unitsWoundedByDamage,paralysisAttackCards=paralysisAttackCards,
        knockoutStagedAttackCards=knockoutStagedAttackCards,attackPhaseSources=attackPhaseSources}
end

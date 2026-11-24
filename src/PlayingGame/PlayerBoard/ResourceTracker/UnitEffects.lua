-- Calculate numeric resources for an already selected Unit ability.
-- Physical payment discovery, activation history, targeting, and record ownership
-- remain in the coordinator. Pass scan-specific modifiers explicitly.
return function(trackerPrivate,unitAbilityPaid,resourceCardsUsesDayMana)
    -- Printed Altem Mages' red/blue bonuses can each be bought once.
    -- Daytime Gold substitutes for the missing basic colour, but never
    -- buys more than the printed +4 total or counts twice as one token.
    local function unitManaScaleBonus(counts)
        local natural=(counts.Red or 0)>0 and 1 or 0
        if (counts.Blue or 0)>0 then natural=natural+1 end
        local gold=resourceCardsUsesDayMana() and (counts.Gold or 0) or 0
        return math.min(2,natural+gold)*2
    end
    local function unitAbilityResources(ability,counts,crystalCounts,unitCombatBoost,howlPenalty)
        if ability==nil or (not unitAbilityPaid(ability,counts)
            and not ability.baseWithoutPayment) then return nil end
        local resources={}
        for category,value in pairs(ability) do
            if trackerPrivate.totalsKeys[category] and type(value)=="number" then
                local bonus=0
                if ability.bonusColor~=nil and (crystalCounts[ability.bonusColor] or 0)>0 then
                    bonus=ability.bonus or 0
                end
                if ability.manaScale then bonus=bonus+unitManaScaleBonus(counts) end
                if unitCombatBoost>0 and (category:sub(1,6)=="attack"
                    or category:sub(1,6)=="ranged"
                    or category:sub(1,5)=="siege"
                    or category:sub(1,5)=="block") then
                    bonus=bonus+unitCombatBoost
                end
                local amount=value+bonus
                if howlPenalty and (category:sub(1,6)=="attack"
                    or category:sub(1,6)=="ranged"
                    or category:sub(1,5)=="siege"
                    or category:sub(1,5)=="block") then
                    amount=math.max(0,amount-1)
                end
                resources[category]=amount
            end
        end
        return resources
    end

    local function applyGlory(resources,hasGlory)
        local gloryCombat=false
        if resources~=nil and hasGlory then
            local boosted={}
            for key,value in pairs(resources) do
                local combatResource=type(key)=="string" and type(value)=="number"
                    and (key:sub(1,6)=="attack" or key:sub(1,6)=="ranged"
                        or key:sub(1,5)=="siege" or key:sub(1,5)=="block")
                boosted[key]=combatResource and value+1 or value
                if combatResource and value>0 then gloryCombat=true end
            end
            resources=boosted
        end
        return resources,gloryCombat
    end

    return {unitAbilityResources=unitAbilityResources,applyGlory=applyGlory}
end

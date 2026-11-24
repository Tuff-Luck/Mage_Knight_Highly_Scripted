-- Identify self-wounding Unit activations before Damage or during Attack.
-- Caller supplies the fresh scan, activation history and live Unit lookups.
return function(abilitiesOf,unitHistoryUses,unitHistoryKey,getObjectFromGUID,unitManaDecision)
    -- Timing of self-wounding Unit abilities: a Block wounds its Unit before
    -- enemies may assign damage; an Attack wounds its Unit in the final Attack
    -- phase, after enemy damage. Only Units with an activated, targeted ability
    -- receive a preview. Other modifiers used earlier retain their effects.
    local function selfWoundingUnitChoices(seat,groups,records,activations)
        local early,late={},{}
        local active={}
        for _,group in ipairs(groups or {}) do
            if not group.rangeDefeated and not group.destroyed then
                for _,source in ipairs(group.sources or {}) do
                    if source.key~=nil then active[source.key]=true end
                end
            end
        end
        for guid,currentActivation in pairs(activations) do
            local abilities=abilitiesOf(guid)
            if currentActivation.seatPos==seat and abilities~=nil then
                for useIndex,activation in ipairs(unitHistoryUses(guid,currentActivation)) do
                    local key=unitHistoryKey(guid,useIndex)
                    local record=records[key]
                    local unit=getObjectFromGUID(guid)
                    local decision=unit~=nil and unitManaDecision(unit,abilities,activation,
                        activation.frozenCounts or activation.lastCounts) or nil
                    local ability=decision~=nil and abilities[decision.index] or nil
                    if active[key] and record~=nil and record.complete==true
                        and ability~=nil and ability.woundsSelf==true then
                        local blocks=false
                        for field,value in pairs(ability) do
                            if type(value)=="number" and type(field)=="string"
                                and field:sub(1,5)=="block" then blocks=true break end
                        end
                        if blocks then early[guid]=true else late[guid]=true end
                    end
                end
            end
        end
        return early,late
    end

    return selfWoundingUnitChoices
end

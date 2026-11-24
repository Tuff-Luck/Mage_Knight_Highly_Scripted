-- Mana payment role assignment and physical candidate ranking.
-- These helpers only evaluate supplied candidates: the coordinator decides
-- current zone membership and eligibility before calling them.

-- Resolve independent mana roles without relying on placement order or GUID
-- order. A casting payment (if declared), stronger-effect payment, and
-- effect-selection payment must be different physical mana objects. Daytime
-- Gold can fill either a casting or effect role; its effect stays ambiguous.
-- Other cards can reuse this by declaring effectManaChoice.castColor.
local function effectManaPossibilities(spec,payments,needPower,goldAllowed,blackAllowed)
    -- Single-boolean call sites/tests retain the ordinary Day/Night pairing.
    -- The Amulets may independently enable both colors at runtime.
    if blackAllowed==nil then blackAllowed=not goldAllowed end
    local possible,anyColor={},false
    -- Black mana cannot pay for any role during a Day round, including
    -- the otherwise separate strong-side payment on Mana Bolt/Thunderbolt.
    if not blackAllowed and needPower and spec.powerColor=="Black" then return possible,anyColor end
    local function hasDistinctPower(effectGUID,castGUID)
        if not needPower then return true end
        for _,payment in ipairs(payments) do
            if payment.guid~=effectGUID and payment.guid~=castGUID
                and (payment.color==spec.powerColor
                    or (goldAllowed and spec.powerColor~="Black"
                        and payment.color=="Gold")) then return true end
        end
        return false
    end
    for _,effect in ipairs(payments) do
        local category=spec.colors[effect.color]
        local wildcard=effect.color=="Gold" and goldAllowed
        if category~=nil or wildcard then
            local valid=false
            if spec.castColor==nil then
                valid=hasDistinctPower(effect.guid,nil)
            else
                for _,casting in ipairs(payments) do
                    if casting.guid~=effect.guid
                        and (casting.color==spec.castColor
                            or (casting.color=="Gold" and goldAllowed))
                        and hasDistinctPower(effect.guid,casting.guid) then
                        valid=true
                        break
                    end
                end
            end
            if valid then
                if wildcard then anyColor=true
                elseif category~=nil then possible[category]=true end
            end
        end
    end
    return possible,anyColor
end

-- Only the separate stronger-effect payment qualifies for Mana Overload.
-- A card's casting mana or a Pure Magic / Mana Bolt option payment does not.
local function effectManaPowerColors(spec,payments,goldAllowed,blackAllowed,selectedCategory)
    if selectedCategory==nil and type(blackAllowed)=="string" then
        selectedCategory=blackAllowed
        blackAllowed=not goldAllowed
    end
    local eligible={}
    if spec==nil or selectedCategory==nil
        or (not blackAllowed and spec.powerColor=="Black") then return eligible end
    for _,effect in ipairs(payments or {}) do
        if spec.colors[effect.color]==selectedCategory
            or (goldAllowed and effect.color=="Gold") then
            for _,power in ipairs(payments or {}) do
                if power.guid~=effect.guid
                    and (power.color==spec.powerColor
                        or (goldAllowed and spec.powerColor~="Black"
                            and power.color=="Gold")) then
                    if spec.castColor==nil then
                        eligible[spec.powerColor]=true
                    else
                        for _,casting in ipairs(payments or {}) do
                            if casting.guid~=effect.guid and casting.guid~=power.guid
                                and (casting.color==spec.castColor
                                    or (goldAllowed and casting.color=="Gold")) then
                                eligible[spec.powerColor]=true
                                break
                            end
                        end
                    end
                end
            end
        end
    end
    return eligible
end

-- U/Place Under changes the vertical order of overlapping cards without
-- changing their X/Z centres. Mana belongs to the physically highest eligible
-- card, not the closest centre (nor the first GUID in a table).
-- Coloured mana considers only legally matching cards; Gold considers any
-- eligible card. For equal height, preserve the old X/Z nearest-card rule.
local function bestManaCard(mana,cards,footprints,eligible)
    local p=mana.getPosition()
    local px,pz=p.x or p[1],p.z or p[3]
    local py=p.y or p[2]
    local best,bestY,bestDistance=nil,nil,nil
    for _,card in ipairs(cards) do
        local f=footprints[card.guid]
        if f~=nil then
            local dx,dz=px-f.x,pz-f.z
            if math.abs(dx)<f.halfX and math.abs(dz)<f.halfZ
                and eligible(card) then
                local cp=card.getPosition()
                local y=cp.y or cp[2] or 0
                local distance=dx*dx+dz*dz
                -- A payment tucked between cards cannot power a card above it.
                if (py==nil or y<=py+0.15)
                    and (best==nil or y>bestY+0.001
                    or (math.abs(y-bestY)<=0.001
                        and (distance<bestDistance
                            or (distance==bestDistance and card.guid<best.guid)))) then
                    best,bestY,bestDistance=card,y,distance
                end
            end
        end
    end
    return best
end

return {
    effectManaPossibilities=effectManaPossibilities,
    effectManaPowerColors=effectManaPowerColors,
    bestManaCard=bestManaCard
}

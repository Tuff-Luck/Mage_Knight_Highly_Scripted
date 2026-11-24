-- Mana payment role assignment, physical candidate ranking and live payment scans.
-- Special-card scans read the current play zone; Unit scans read the play and
-- Unit zones or supplied live candidates. The coordinator retains color and posture policies.

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

-- Magic Talent's strong side consumes TWO distinct mana objects, not the
-- single mana that normally powers an Advanced Action. Read the same released
-- die faces/crystals as the ordinary tracker, even when its panel is minimized.
local function magicTalentManaPayments(seatPos,footprint,manaColor,readyForXZ)
    local card=getObjectFromGUID("3d832c")
    local zone=seatPos~=nil and getObjectFromGUID(playerPlayAreas[seatPos]) or nil
    if card==nil or zone==nil then return {} end
    local area=footprint(card)
    local payments,seen={},{}
    local function consider(obj)
        if obj==nil or seen[obj.guid] or obj.guid==card.guid
            or not readyForXZ(obj) then return end
        seen[obj.guid]=true
        local p=obj.getPosition()
        if math.abs(p[1]-area.x)<area.halfX
            and math.abs(p[3]-area.z)<area.halfZ then
            local color=manaColor(obj)
            if color~=nil then
                payments[#payments+1]={guid=obj.guid,color=color}
            end
        end
    end
    for _,obj in ipairs(zone.getObjects()) do consider(obj) end
    table.sort(payments,function(a,b) return a.guid<b.guid end)
    return payments
end

-- A borrowed Spell's casting payment must remain on its physical card.
-- This check also works with the Resource Tracker minimized, when its cached
-- records are deliberately cleared. A lone Black die never casts a Spell.
local function magicTalentSpellCastingPaid(seatPos,guid,footprint,cardPosture,manaColor,readyForXZ,matchesCardMana)
    local card=guid~=nil and getObjectFromGUID(guid) or nil
    local data=card~=nil and gameCards[guid] or nil
    local zone=seatPos~=nil and getObjectFromGUID(playerPlayAreas[seatPos]) or nil
    if card==nil or data==nil or data.cardType~="Spell"
        or zone==nil or card.is_face_down==true
        or cardPosture(card)~="upright" then return false end
    local area=footprint(card)
    local seen={}
    local function paidBy(mana)
        if mana==nil or seen[mana.guid] or mana.guid==guid
            or not readyForXZ(mana) then return false end
        seen[mana.guid]=true
        local p=mana.getPosition()
        if math.abs(p[1]-area.x)>=area.halfX
            or math.abs(p[3]-area.z)>=area.halfZ then return false end
        local color=manaColor(mana)
        return color~=nil and color~="Black" and matchesCardMana(card,color)
    end
    for _,mana in ipairs(zone.getObjects()) do
        if paidBy(mana) then return true end
    end
    return false
end

-- Count distinct physical casting payments for repeated uses of the same
-- Spell through Maximal Effect + Magic Talent. Only play-zone mana qualifies;
-- duplicates are counted only once.
local function magicTalentSpellCastingPaymentCount(seatPos,guid,footprint,cardPosture,manaColor,readyForXZ,matchesCardMana)
    local card=guid~=nil and getObjectFromGUID(guid) or nil
    local data=card~=nil and gameCards[guid] or nil
    local zone=seatPos~=nil and getObjectFromGUID(playerPlayAreas[seatPos]) or nil
    if card==nil or data==nil or data.cardType~="Spell" or zone==nil
        or card.is_face_down==true or cardPosture(card)~="upright" then return 0 end
    local area=footprint(card)
    local seen,count={},0
    local function consider(mana)
        if mana==nil or seen[mana.guid] or mana.guid==guid
            or not readyForXZ(mana) then return end
        seen[mana.guid]=true
        local p=mana.getPosition()
        local x,z=p.x or p[1],p.z or p[3]
        if math.abs(x-area.x)>=area.halfX
            or math.abs(z-area.z)>=area.halfZ then return end
        local color=manaColor(mana)
        if color~=nil and color~="Black" and matchesCardMana(card,color) then
            count=count+1
        end
    end
    for _,mana in ipairs(zone.getObjects()) do consider(mana) end
    return count
end

-- A Maximal Effect power mana object cannot also be one of Magic Talent's
-- additional casting/claim payments, even if overlapping cards share X/Z.
local function resourceCardsMaximalEffectSourceManaGUIDs(seatPos,sourceGUID,footprint,manaColor,readyForXZ,matchesCardMana)
    local source=sourceGUID~=nil and getObjectFromGUID(sourceGUID) or nil
    local zone=seatPos~=nil and getObjectFromGUID(playerPlayAreas[seatPos]) or nil
    if source==nil or zone==nil then return {} end
    local area=footprint(source)
    local spent,seen={},{}
    local function inspect(mana)
        if mana==nil or seen[mana.guid] or mana.guid==sourceGUID
            or not readyForXZ(mana) then return end
        seen[mana.guid]=true
        local color=manaColor(mana)
        if color==nil or not matchesCardMana(source,color) then return end
        local pos=mana.getPosition()
        local x,z=pos.x or pos[1],pos.z or pos[3]
        if math.abs(x-area.x)<area.halfX and math.abs(z-area.z)<area.halfZ then
            spent[mana.guid]=true
        end
    end
    for _,mana in ipairs(zone.getObjects()) do inspect(mana) end
    return spent
end

-- Time Bending's extra turn must be usable without opening the Resource Tracker.
-- Read the physical Blue casting payment and a separate Black strong-side payment;
-- the mere presence of the Spell in the play area does not establish either.
local function resourceCardsTimeBendingPaid(seatPos,card,footprint,cardPosture,manaColor,manaInsideFootprint)
    if card==nil or card.guid~=GUID.card.timeBending
        or card.is_face_down==true or cardPosture(card)~="upright"
        or not resourceCardsBlackAllowed() then return false end
    local zone=seatPos~=nil and getObjectFromGUID(playerPlayAreas[seatPos]) or nil
    if zone==nil then return false end
    local area=footprint(card)
    local blue,black=false,false
    for _,mana in ipairs(zone.getObjects()) do
        if mana.guid~=card.guid and manaInsideFootprint(mana,area)
            and (manaClaimDieHeld==nil or not manaClaimDieHeld(mana.guid)) then
            local color=manaColor(mana)
            if color=="Blue" then blue=true elseif color=="Black" then black=true end
        end
    end
    return blue and black
end

-- Physical mana is authoritative for a paid Unit ability. It is read from
-- either overlapping board zone, even with the Resource Tracker collapsed.
local function unitManaCounts(unit,seatPos,source,crystalsOnly,
    footprint,manaColor,readyForXZ,isManaTokenFigurine,manaInsideFootprint)
    local tokens=source
    if tokens==nil then
        tokens={}
        local seen={}
        for _,zoneGUID in ipairs({playerUnitAreas[seatPos],playerPlayAreas[seatPos]}) do
            local zone=zoneGUID~=nil and getObjectFromGUID(zoneGUID) or nil
            if zone~=nil then
                for _,obj in ipairs(zone.getObjects()) do
                    if not seen[obj.guid] and readyForXZ(obj)
                        and manaColor(obj)~=nil then
                        seen[obj.guid]=true
                        tokens[#tokens+1]=obj
                    end
                end
            end
        end
    end
    local counts,area={},footprint(unit)
    local seen={}
    for _,mana in ipairs(tokens) do
        if not seen[mana.guid] and readyForXZ(mana) then
            seen[mana.guid]=true
            local color=manaColor(mana)
            if color~=nil and (not crystalsOnly or isManaTokenFigurine(mana))
            and manaInsideFootprint(mana,area) then
                counts[color]=(counts[color] or 0)+1
            end
        end
    end
    return counts
end

local function unitAbilityPaid(ability,counts,resourceCardsGoldAllowed,resourceCardsBlackAllowed)
    local color=ability.manaCost
    if color==nil then return true end
    if color=="Black" and not resourceCardsBlackAllowed() then return false end
    if (counts[color] or 0)>0 then return true end
    -- Daytime Gold can pay any basic colour, but not Black.
    return color~="Black" and resourceCardsGoldAllowed() and (counts.Gold or 0)>0
end

local function unitManaSignature(counts,resourceCardsGoldAllowed,resourceCardsBlackAllowed)
    local parts={tostring(resourceCardsGoldAllowed()),tostring(resourceCardsBlackAllowed())}
    for _,color in ipairs({"Red","Blue","Green","White","Black","Gold"}) do
        parts[#parts+1]=tostring(counts[color] or 0)
    end
    return table.concat(parts,":")
end

return {
    effectManaPossibilities=effectManaPossibilities,
    effectManaPowerColors=effectManaPowerColors,
    bestManaCard=bestManaCard,
    magicTalentManaPayments=magicTalentManaPayments,
    magicTalentSpellCastingPaid=magicTalentSpellCastingPaid,
    magicTalentSpellCastingPaymentCount=magicTalentSpellCastingPaymentCount,
    resourceCardsMaximalEffectSourceManaGUIDs=resourceCardsMaximalEffectSourceManaGUIDs,
    resourceCardsTimeBendingPaid=resourceCardsTimeBendingPaid,
    unitManaCounts=unitManaCounts,
    unitAbilityPaid=unitAbilityPaid,
    unitManaSignature=unitManaSignature
}

-- Mana payment role assignment, physical candidate ranking and live payment scans.
-- Special-card scans read the current play zone; Unit scans read the play and
-- Unit zones or supplied live candidates. The coordinator retains color and posture policies.

-- Payment-only colours preserve the physical face while allowing Mana Storm
-- dice to fill basic roles. Never expose these as actual crystal colours.
local function stormColor(color,isDice,active)
    if active and isDice then
        if color=="Gold" then return "StormGold" end
        if color=="Black" then return "StormBlack" end
    end
    return color
end
local function wildcard(color,goldAllowed)
    return color=="StormGold" or color=="StormBlack" or (color=="Gold" and goldAllowed)
end
local function blackPayment(color)
    return color=="Black" or color=="StormBlack"
end
local function basicPayment(color,required,goldAllowed)
    return color==required or (required~=nil and required~="Black" and wildcard(color,goldAllowed))
end
local function wildcardCount(counts,goldAllowed,reserveBlack)
    local count=(goldAllowed and (counts.Gold or 0) or 0)+(counts.StormGold or 0)+(counts.StormBlack or 0)
    if reserveBlack and (counts.Black or 0)==0 and (counts.StormBlack or 0)>0 then count=count-1 end
    return count
end
local function ordinarySpellRoles(payments,blackAllowed)
    local cast,power=false,false
    for _,payment in ipairs(payments) do
        if payment.color~="Black" then
            cast=true
            if blackAllowed then
                for _,other in ipairs(payments) do
                    if other.guid~=payment.guid and blackPayment(other.color) then power=true break end
                end
            end
        end
    end
    -- Preserve the existing uncast Black-only strong-side indicator.
    if not cast and blackAllowed then
        for _,payment in ipairs(payments) do if blackPayment(payment.color) then power=true break end end
    end
    return cast,power
end

-- All roles are assigned to distinct physical objects. Gold can fill a
-- basic casting or power role, but never substitutes for Black power.
local function castingColorMatches(spec,color,goldAllowed)
    return basicPayment(color,spec.castColor,goldAllowed)
end

local function powerColorMatches(spec,color,goldAllowed)
    if spec.powerColor=="Black" then return blackPayment(color) end
    return basicPayment(color,spec.powerColor,goldAllowed)
end

-- Shared enumeration for the possible effect options and Mana Overload's
-- qualifying stronger-side payment. The chosen effect can have a wildcard;
-- callers decide how to present it. No payment is reserved by this query.
local function hasDistinctRoles(spec,payments,effectGUID,needPower,goldAllowed)
    local function hasPower(castGUID)
        if not needPower then return true end
        for _,power in ipairs(payments) do
            if power.guid~=effectGUID and power.guid~=castGUID
                and powerColorMatches(spec,power.color,goldAllowed) then return true end
        end
        return false
    end
    if spec.castColor==nil then return hasPower(nil) end
    for _,casting in ipairs(payments) do
        if casting.guid~=effectGUID and castingColorMatches(spec,casting.color,goldAllowed)
            and hasPower(casting.guid) then return true end
    end
    return false
end

local function effectManaPossibilities(spec,payments,needPower,goldAllowed,blackAllowed)
    -- Single-boolean call sites retain the ordinary Day/Night pairing.
    -- Amulets may independently enable both colours.
    if blackAllowed==nil then blackAllowed=not goldAllowed end
    local possible,anyColor={},false
    if not blackAllowed and needPower and spec.powerColor=="Black" then return possible,anyColor end
    for _,effect in ipairs(payments) do
        local category=spec.colors[effect.color]
        local wild=wildcard(effect.color,goldAllowed)
        if (category~=nil or wild)
            and hasDistinctRoles(spec,payments,effect.guid,needPower,goldAllowed) then
            if wild then anyColor=true
            elseif category~=nil then possible[category]=true end
        end
    end
    return possible,anyColor
end

-- Repeated granted effects have one independent effect-selection payment
-- per use. Match the chosen categories to distinct physical mana objects,
-- preferring exact colours over legal Gold. The source's casting/power
-- entitlement is already resolved by the caller.
local function effectManaSelectionsPaid(spec,payments,selections,goldAllowed,count)
    local exact,wildcards,seen={},0,{}
    for _,payment in ipairs(payments or {}) do
        if payment.guid~=nil and not seen[payment.guid] then
            seen[payment.guid]=true
            local category=spec.colors[payment.color]
            if wildcard(payment.color,goldAllowed) then
                wildcards=wildcards+1
            elseif category~=nil then
                exact[category]=(exact[category] or 0)+1
            end
        end
    end
    for index=1,count do
        local category=selections[index]
        if category==nil then return false end
        if (exact[category] or 0)>0 then
            exact[category]=exact[category]-1
        elseif wildcards>0 then
            wildcards=wildcards-1
        else return false end
    end
    return true
end

-- Casting and effect-selection mana do not qualify for Mana Overload.
local function effectManaPowerColors(spec,payments,goldAllowed,blackAllowed,selectedCategory)
    if selectedCategory==nil and type(blackAllowed)=="string" then
        selectedCategory=blackAllowed
        blackAllowed=not goldAllowed
    end
    local eligible={}
    if spec==nil or selectedCategory==nil
        or (not blackAllowed and spec.powerColor=="Black") then return eligible end
    for _,effect in ipairs(payments or {}) do
        if (spec.colors[effect.color]==selectedCategory or wildcard(effect.color,goldAllowed))
            and hasDistinctRoles(spec,payments,effect.guid,true,goldAllowed) then
            eligible[spec.powerColor]=true
            break
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

-- The special-card paths use live zone membership even while the tracker
-- is minimized. Do not reuse a prior scan or search outside the zone.
local function playZone(seatPos)
    return seatPos~=nil and getObjectFromGUID(playerPlayAreas[seatPos]) or nil
end

-- All of these special-card checks deliberately use X/Z footprints. They
-- inspect payments for a specified physical source, not ordinary multi-card
-- mana allocation (which retains the highest eligible card rule above).
-- The callback can stop immediately after finding a matching payment.
local function visitFootprintMana(zone,card,footprint,manaColor,readyForXZ,visit)
    if zone==nil or card==nil then return end
    local area=footprint(card)
    local seen={}
    for _,mana in ipairs(zone.getObjects()) do
        if mana~=nil and mana.guid~=card.guid and not seen[mana.guid]
            and readyForXZ(mana) then
            seen[mana.guid]=true
            local p=mana.getPosition()
            local x,z=p.x or p[1],p.z or p[3]
            if math.abs(x-area.x)<area.halfX and math.abs(z-area.z)<area.halfZ then
                local color=manaColor(mana)
                if color~=nil and visit(mana.guid,color,mana) then return end
            end
        end
    end
end

-- Magic Talent's strong side consumes two distinct physical mana objects.
local function magicTalentManaPayments(seatPos,footprint,manaColor,readyForXZ,talentGUID,sourceGUIDs)
    local card=getObjectFromGUID(talentGUID or "3d832c")
    local payments={}
    local sources,footprints={},{}
    for _,guid in ipairs(sourceGUIDs or {}) do
        local source=getObjectFromGUID(guid)
        if source~=nil then
            sources[#sources+1]=source
            footprints[guid]=footprint(source)
        end
    end
    visitFootprintMana(playZone(seatPos),card,footprint,manaColor,readyForXZ,function(guid,color,mana)
        -- A single physical mana cannot pay two overlapping browser sources.
        -- Only the specified live sources participate, with the same height
        -- and distance priority as ordinary tracker allocation.
        if #sources>1 and bestManaCard(mana,sources,footprints,function() return true end)~=card then return end
        payments[#payments+1]={guid=guid,color=color}
    end)
    table.sort(payments,function(a,b) return a.guid<b.guid end)
    return payments
end

-- A borrowed Spell's casting payment must remain on its physical card.
-- The boolean query stops at the first valid payment; repeated uses count
-- all distinct physical payments through the same eligibility path.
local function spellCastingCount(seatPos,guid,footprint,cardPosture,manaColor,readyForXZ,matchesCardMana,firstOnly)
    local card=guid~=nil and getObjectFromGUID(guid) or nil
    local data=card~=nil and gameCards[guid] or nil
    if card==nil or data==nil or data.cardType~="Spell"
        or card.is_face_down==true or cardPosture(card)~="upright" then return 0 end
    local count=0
    visitFootprintMana(playZone(seatPos),card,footprint,manaColor,readyForXZ,function(_,color)
        if color~="Black" and matchesCardMana(card,color) then
            count=count+1
            return firstOnly
        end
        return false
    end)
    return count
end

local function magicTalentSpellCastingPaid(seatPos,guid,footprint,cardPosture,manaColor,readyForXZ,matchesCardMana)
    return spellCastingCount(seatPos,guid,footprint,cardPosture,manaColor,readyForXZ,matchesCardMana,true)>0
end

local function magicTalentSpellCastingPaymentCount(seatPos,guid,footprint,cardPosture,manaColor,readyForXZ,matchesCardMana)
    return spellCastingCount(seatPos,guid,footprint,cardPosture,manaColor,readyForXZ,matchesCardMana,false)
end

-- A Maximal Effect power mana object cannot also be one of Magic Talent's
-- additional casting/claim payments, even if overlapping cards share X/Z.
local function resourceCardsMaximalEffectSourceManaGUIDs(seatPos,sourceGUID,footprint,manaColor,readyForXZ,matchesCardMana)
    local source=sourceGUID~=nil and getObjectFromGUID(sourceGUID) or nil
    local spent={}
    visitFootprintMana(playZone(seatPos),source,footprint,manaColor,readyForXZ,function(guid,color)
        if matchesCardMana(source,color) then spent[guid]=true end
    end)
    return spent
end

-- Time Bending's extra turn must be usable without opening the Resource Tracker.
-- Read the physical Blue casting payment and a separate Black strong-side payment;
-- the mere presence of the Spell in the play area does not establish either.
local function resourceCardsTimeBendingPaid(seatPos,card,footprint,cardPosture,manaColor,manaInsideFootprint)
    if card~=nil and magicTalentOfferCastSide~=nil then
        local side=magicTalentOfferCastSide(seatPos,card.guid)
        if side~=nil then return card.guid==GUID.card.timeBending and side end
    end
    if card==nil or card.guid~=GUID.card.timeBending
        or card.is_face_down==true or cardPosture(card)~="upright"
        or not resourceCardsBlackAllowed() then return false end
    local zone=playZone(seatPos)
    if zone==nil then return false end
    local area=footprint(card)
    local payments={}
    for _,mana in ipairs(zone.getObjects()) do
        if mana.guid~=card.guid and manaInsideFootprint(mana,area)
            and (manaClaimDieHeld==nil or not manaClaimDieHeld(mana.guid)) then
            local color=manaColor(mana)
            if basicPayment(color,"Blue",false) or blackPayment(color) then
                payments[#payments+1]={guid=mana.guid,color=color}
            end
        end
    end
    local cast,power=ordinarySpellRoles(payments,true)
    return cast and power
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
    if color=="Black" then
        return resourceCardsBlackAllowed() and ((counts.Black or 0)+(counts.StormBlack or 0)>0)
    end
    if (counts[color] or 0)>0 then return true end
    return wildcardCount(counts,resourceCardsGoldAllowed())>0
end

local function unitManaSignature(counts,resourceCardsGoldAllowed,resourceCardsBlackAllowed)
    local parts={tostring(resourceCardsGoldAllowed()),tostring(resourceCardsBlackAllowed())}
    for _,color in ipairs({"Red","Blue","Green","White","Black","Gold","StormGold","StormBlack"}) do
        parts[#parts+1]=tostring(counts[color] or 0)
    end
    return table.concat(parts,":")
end

return {
    stormColor=stormColor,
    wildcard=wildcard,
    blackPayment=blackPayment,
    basicPayment=basicPayment,
    wildcardCount=wildcardCount,
    ordinarySpellRoles=ordinarySpellRoles,
    effectManaPossibilities=effectManaPossibilities,
    effectManaPowerColors=effectManaPowerColors,
    effectManaSelectionsPaid=effectManaSelectionsPaid,
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

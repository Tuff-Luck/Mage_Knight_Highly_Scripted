-- Enemy-targeted effects of Combat Actions (e.g. Ice Shield's Armor reduction).
-- Runtime only: targets are recomputed from the physical table on every
-- Resource Tracker scan, so re-choosing a card's option re-links it at once.

local lastReport={}

-- Vampiric gains one Armor for each Wound added to the Hero's hand, plus
-- one for each Unit wounded (not each Unit Wound card). Poison's extra discard
-- Wounds do not contribute. Arcane Immunity prevents the additional effect;
-- Arcane Vulnerability permits it even if resistance avoided the Wound.
function combatVampiricArmourGain(result)
    if result==nil then return 0 end
    local bonus=result.heroWounds or 0
    for _,hit in ipairs(result.units or {}) do
        local unit=hit.unit
        if unit~=nil and unit.arcaneImmunity~=true
            and (hit.wounded==true or unit.arcaneVulnerability==true) then
            bonus=bonus+1
        end
    end
    return bonus
end

-- The enemy physically under the card wins; otherwise the nearest face-up one.
function combatEffectNearestEnemy(cardArea,monsters,enemyAreaOf,overlapOf,eligible)
    local best,bestArea,bestDistance=nil,-1,math.huge
    for guid,enemy in pairs(monsters) do
        if enemy.is_face_down~=true and (eligible==nil or eligible(enemy,guid)) then
            local enemyArea=enemyAreaOf(enemy)
            local area=overlapOf(cardArea,enemyArea)
            local distance=(cardArea.x-enemyArea.x)^2+(cardArea.z-enemyArea.z)^2
            if area>bestArea or (area==bestArea and (distance<bestDistance
                or (distance==bestDistance and best~=nil and guid<best.guid))) then
                best,bestArea,bestDistance=enemy,area,distance
            end
        end
    end
    return best
end

-- Returns the effect for the played side, if the selected option applies.
function combatEffectSpec(rule,powered,chosenCategory)
    local sides=rule~=nil and rule.enemyEffect or nil
    local spec=nil
    if sides~=nil then
        if powered then spec=sides.powered else spec=sides.normal end
    end
    if spec==nil then return nil end
    -- A powered play never falls back to the normal effect: the sides are distinct effects.
    -- A side may list one spec per option; the selected option picks the matching one.
    if spec[1]~=nil then
        for _,candidate in ipairs(spec) do
            if candidate.choice==nil or candidate.choice==chosenCategory then return candidate end
        end
        return nil
    end
    if spec.choice~=nil and spec.choice~=chosenCategory then return nil end
    return spec
end

-- Spec fields: noAttackUnfortified, armourReduce, armourReduceFortified (replaces it against a fortified enemy),
-- armourReduceByResist (per resistance), noAttack, removeAbilities, removeFortify,
-- removeResist, removeFireResist, destroy, destroyDuringAttack, destroyIfBlocked, attackReduce, firstDamageUnit,
-- armourReduceRangedUnfortifiedOnly (does not reduce Armour in Ranged/Siege on a fortified enemy),
-- all (every face-up enemy instead of one).
-- Arcane Immunity ignores non-attack effects; directly changing an Attack remains legal.
local function combatEffectImmune(enemyGUID)
    local pug=monsterPugs[enemyGUID]
    local perks=gStates~=nil and gStates.monsterPerks~=nil and gStates.monsterPerks[enemyGUID] or nil
    return (pug~=nil and pug.arcaneImmunity==true) or (perks~=nil and perks.arcaneImmunity==true)
end

function combatEffectAdd(enemyEffects,enemyGUID,sourceGUID,spec,sourceKey)
    local entry=enemyEffects[enemyGUID]
    if entry==nil then
        entry={armourReduce=0,armourReduceFortified=0,armourReduceByResist=0,
            armourReduceRangedUnfortifiedOnly=0,armourReduceAttackOnly=0,noAttack=false,destroy=false,
            destroyDuringAttack=false,destroyIfBlocked=false,grantCumbersome=false,attackReductions={},
            removeAbilities=false,removeFortify=false,removeResist=false,removeFireResist=false,removedPrinted={},attackConversions={},sources={},applied={},
            armourBeforeFortificationRemoval=0}
        enemyEffects[enemyGUID]=entry
    end
    -- Keep each original, targeted effect for the shared Combat Calculator
    -- button renderer. Numerical resource totals are unaffected by these.
    local requested=spec
    local immune=combatEffectImmune(enemyGUID)
    local pug=monsterPugs[enemyGUID]
    local perks=gStates~=nil and gStates.monsterPerks~=nil
        and gStates.monsterPerks[enemyGUID] or nil
    local fireResistant=requested.fireSpell==true
        and ((pug~=nil and pug.fResist==true) or (perks~=nil and perks.fResist==true))
    local iceResistant=requested.iceSpell==true
        and ((pug~=nil and pug.iResist==true) or (perks~=nil and perks.iResist==true))
    if spec.insufficientMove==true then
        spec={} -- Keep a red Wings target button, but apply no suppression.
    elseif fireResistant or iceResistant then
        -- Elemental Resistance blocks the non-Attack/Block effects of a matching Spell.
        if fireResistant then entry.fireResistIgnored=true end
        if iceResistant then entry.iceResistIgnored=true end
        spec={}
    elseif immune then
        -- Attack manipulation (including one attack losing its abilities)
        -- still works against Arcane Immunity; do not report it as ignored.
        if spec.removeOneAttackAbilities~=true and spec.removeAbilities~=true then
            entry.immuneIgnored=true
        end
        spec={removeAbilities=spec.removeAbilities,
            removeOneAttackAbilities=spec.removeOneAttackAbilities,
            attackReduce=spec.attackReduce,
            attackIncrease=spec.attackIncrease,grantCumbersome=spec.grantCumbersome,
            firstDamageUnit=spec.firstDamageUnit}
    end
    if requested.all~=true then
        entry.applied=entry.applied or {}
        entry.applied[#entry.applied+1]={source=sourceGUID,key=sourceKey or sourceGUID,
            spec=requested,effective=spec,immune=immune,fireResistant=fireResistant,
            iceResistant=iceResistant}
    end
    local attackAdjust=(tonumber(spec.attackReduce) or 0)-(tonumber(spec.attackIncrease) or 0)
    if attackAdjust~=0 or spec.removeOneAttackAbilities==true then
        local ordinal=1
        for _,previous in ipairs(entry.attackReductions) do
            if previous.source==sourceGUID then ordinal=ordinal+1 end
        end
        local id=tostring(sourceGUID)..(ordinal>1 and ("#"..tostring(ordinal)) or "")
        entry.attackReductions[#entry.attackReductions+1]={amount=attackAdjust,
            stripAbilities=spec.removeOneAttackAbilities==true,
            source=sourceGUID,id=id,
            firstDamageUnit=spec.firstDamageUnit==true and sourceGUID or nil}
    end
    entry.destroy=entry.destroy or spec.destroy==true
    entry.destroyDuringAttack=entry.destroyDuringAttack or spec.destroyDuringAttack==true
    entry.destroyIfBlocked=entry.destroyIfBlocked or spec.destroyIfBlocked==true
    entry.armourReduce=entry.armourReduce+(spec.armourReduce or 0)
    entry.armourReduceFortified=entry.armourReduceFortified+(spec.armourReduceFortified or spec.armourReduce or 0)
    -- Only the player's explicit '1st' Earthquake mode preserves the extra
    -- fortified reduction after another effect removes fortification.
    if spec.armourBeforeFortificationRemoval==true then
        entry.armourBeforeFortificationRemoval=entry.armourBeforeFortificationRemoval
            +math.max(0,(spec.armourReduceFortified or 0)-(spec.armourReduce or 0))
    end
    if spec.armourSetIfBlocked~=nil then
        entry.armourSetIfBlocked=math.min(entry.armourSetIfBlocked or math.huge,spec.armourSetIfBlocked)
    end
    entry.armourReduceByResist=entry.armourReduceByResist+(spec.armourReduceByResist or 0)
    entry.armourReduceRangedUnfortifiedOnly=entry.armourReduceRangedUnfortifiedOnly
        +(spec.armourReduceRangedUnfortifiedOnly or 0)
    entry.armourReduceAttackOnly=entry.armourReduceAttackOnly
        +(spec.armourReduceAttackOnly or 0)
    if spec.removeTrait~=nil then entry.removedPrinted[spec.removeTrait]=true end
    if spec.convertAttack~=nil then
        entry.attackConversions[#entry.attackConversions+1]=spec.convertAttack
    end
    entry.grantCumbersome=entry.grantCumbersome or spec.grantCumbersome==true
    entry.noAttack=entry.noAttack or spec.noAttack==true
    entry.noAttackUnfortified=entry.noAttackUnfortified or spec.noAttackUnfortified==true
    entry.removeAbilities=entry.removeAbilities or spec.removeAbilities==true
    entry.removeFortify=entry.removeFortify or spec.removeFortify==true
    entry.removeResist=entry.removeResist or spec.removeResist==true
    entry.removeFireResist=entry.removeFireResist or spec.removeFireResist==true
    entry.sources[#entry.sources+1]=sourceGUID
end

-- Remind the active player when the set of applied effects changes.
function combatEffectReport(seatPos,enemyEffects,quiet)
    local parts={}
    for guid,entry in pairs(enemyEffects) do
        local pug=monsterPugs[guid]
        local name=pug~=nil and pug.name~=nil and tostring(pug.name) or guid
        local text=name..":"
        if entry.armourReduce>0 or entry.armourReduceByResist>0 then
            text=text.." Armor -"..entry.armourReduce
            if entry.armourReduceFortified~=entry.armourReduce then
                text=text.." (-"..entry.armourReduceFortified.." if fortified)"
            end
            if entry.armourReduceByResist>0 then text=text.." (-"..entry.armourReduceByResist.." per resistance)" end
        end
        if entry.armourReduceRangedUnfortifiedOnly>0 then
            text=text.." (Armour reduction applies in Ranged/Siege only if unfortified)"
        end
        if entry.removeFortify then text=text.." loses fortification" end
        if entry.removeResist then text=text.." loses resistances" end
        if entry.removeFireResist then text=text.." loses Fire Resistance" end
        if entry.noAttack then text=text.." does not attack" end
        if entry.grantCumbersome then text=text.." gains Cumbersome" end
        if entry.noAttackUnfortified and not entry.noAttack then text=text.." does not attack if unfortified" end
        if entry.removeAbilities then text=text.." attack loses abilities (keeps colour)" end
        for _,reduction in ipairs(entry.attackReductions or {}) do
            if reduction.stripAbilities then text=text.." one chosen attack loses abilities (keeps colour)" end
        end
        local attackReduction,attackIncrease=0,0
        local forcedDamage=false
        for _,reduction in ipairs(entry.attackReductions or {}) do
            if reduction.amount>0 then attackReduction=attackReduction+reduction.amount
            else attackIncrease=attackIncrease-reduction.amount end
            if reduction.firstDamageUnit~=nil then forcedDamage=true end
        end
        if attackReduction>0 then text=text.." Attack reduction "..tostring(attackReduction) end
        if attackIncrease>0 then text=text.." Attack increase "..tostring(attackIncrease) end
        for trait in pairs(entry.removedPrinted or {}) do text=text.." removes "..trait end
        for _,conversion in ipairs(entry.attackConversions or {}) do text=text.." converts attack to "..tostring(conversion.to) end
        if forcedDamage then text=text.." (assign damage to reducing Unit first)" end
        if entry.destroy then text=text.." is destroyed" end
        if entry.destroyDuringAttack then text=text.." destroyed during Attack" end
        if entry.destroyIfBlocked then text=text.." destroyed if all attacks blocked" end
        if entry.immuneIgnored then text=text.." (Arcane Immunity ignores non-attack effects)" end
        if entry.fireResistIgnored then text=text.." (Fire Resistance ignores red Spell effects)" end
        if entry.iceResistIgnored then text=text.." (Ice Resistance ignores blue Spell effects)" end
        parts[#parts+1]=text
    end
    table.sort(parts)
    local signature=table.concat(parts,"\n")
    if lastReport[seatPos]==signature then return end
    lastReport[seatPos]=signature
    if signature~="" and quiet~=true then
        -- The Mage Knight's hand color may not be occupied (hotseat/dummy/GM).
        -- Use the shared safe broadcaster so changing an effect never crashes
        -- the combat scan while the target color has no seated Player.
        safeBroadcastToColor("Card effects on enemies (apply manually if needed):\n"..signature,
            positionToColor(gStates.turnNumber),{1,0.6,0.1})
    end
end

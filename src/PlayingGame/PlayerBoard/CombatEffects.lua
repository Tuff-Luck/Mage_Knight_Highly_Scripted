-- Enemy-targeted effects of Combat Actions (e.g. Ice Shield's Armour reduction).
-- Runtime only: targets are recomputed from the physical table on every
-- Resource Tracker scan, so re-choosing a card's option re-links it at once.

local lastReport={}

-- The enemy physically under the card wins; otherwise the nearest face-up one.
function combatEffectNearestEnemy(cardArea,monsters,enemyAreaOf,overlapOf)
    local best,bestArea,bestDistance=nil,-1,math.huge
    for guid,enemy in pairs(monsters) do
        if enemy.is_face_down~=true then
            local enemyArea=enemyAreaOf(enemy)
            local area=overlapOf(cardArea,enemyArea)
            local distance=(cardArea.x-enemyArea.x)^2+(cardArea.z-enemyArea.z)^2
            if area>bestArea or (area==bestArea and (distance<bestDistance
                or (distance==bestDistance and guid<best.guid))) then
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
-- removeResist, removeFireResist, destroy, destroyIfBlocked, attackReduce, firstDamageUnit,
-- all (every face-up enemy instead of one).
-- Arcane Immunity ignores non-attack effects; directly changing an Attack remains legal.
local function combatEffectImmune(enemyGUID)
    local pug=monsterPugs[enemyGUID]
    local perks=gStates~=nil and gStates.monsterPerks~=nil and gStates.monsterPerks[enemyGUID] or nil
    return (pug~=nil and pug.arcaneImmunity==true) or (perks~=nil and perks.arcaneImmunity==true)
end

function combatEffectAdd(enemyEffects,enemyGUID,sourceGUID,spec)
    local entry=enemyEffects[enemyGUID]
    if entry==nil then
        entry={armourReduce=0,armourReduceFortified=0,armourReduceByResist=0,noAttack=false,destroy=false,
            destroyIfBlocked=false,attackReductions={},
            removeAbilities=false,removeFortify=false,removeResist=false,removeFireResist=false,sources={}}
        enemyEffects[enemyGUID]=entry
    end
    if combatEffectImmune(enemyGUID) then
        entry.immuneIgnored=true
        spec={removeAbilities=spec.removeAbilities,attackReduce=spec.attackReduce,
            firstDamageUnit=spec.firstDamageUnit}
    end
    local attackReduce=math.max(0,tonumber(spec.attackReduce) or 0)
    if attackReduce>0 then
        local ordinal=1
        for _,previous in ipairs(entry.attackReductions) do
            if previous.source==sourceGUID then ordinal=ordinal+1 end
        end
        local id=tostring(sourceGUID)..(ordinal>1 and ("#"..tostring(ordinal)) or "")
        entry.attackReductions[#entry.attackReductions+1]={amount=attackReduce,
            source=sourceGUID,id=id,
            firstDamageUnit=spec.firstDamageUnit==true and sourceGUID or nil}
    end
    entry.destroy=entry.destroy or spec.destroy==true
    entry.destroyIfBlocked=entry.destroyIfBlocked or spec.destroyIfBlocked==true
    entry.armourReduce=entry.armourReduce+(spec.armourReduce or 0)
    entry.armourReduceFortified=entry.armourReduceFortified+(spec.armourReduceFortified or spec.armourReduce or 0)
    entry.armourReduceByResist=entry.armourReduceByResist+(spec.armourReduceByResist or 0)
    entry.noAttack=entry.noAttack or spec.noAttack==true
    entry.noAttackUnfortified=entry.noAttackUnfortified or spec.noAttackUnfortified==true
    entry.removeAbilities=entry.removeAbilities or spec.removeAbilities==true
    entry.removeFortify=entry.removeFortify or spec.removeFortify==true
    entry.removeResist=entry.removeResist or spec.removeResist==true
    entry.removeFireResist=entry.removeFireResist or spec.removeFireResist==true
    entry.sources[#entry.sources+1]=sourceGUID
end

-- Remind the active player when the set of applied effects changes.
function combatEffectReport(seatPos,enemyEffects)
    local parts={}
    for guid,entry in pairs(enemyEffects) do
        local pug=monsterPugs[guid]
        local name=pug~=nil and pug.name~=nil and tostring(pug.name) or guid
        local text=name..":"
        if entry.armourReduce>0 or entry.armourReduceByResist>0 then
            text=text.." Armour -"..entry.armourReduce
            if entry.armourReduceFortified~=entry.armourReduce then
                text=text.." (-"..entry.armourReduceFortified.." if fortified)"
            end
            if entry.armourReduceByResist>0 then text=text.." (-"..entry.armourReduceByResist.." per resistance)" end
        end
        if entry.removeFortify then text=text.." loses fortification" end
        if entry.removeResist then text=text.." loses resistances" end
        if entry.removeFireResist then text=text.." loses Fire Resistance" end
        if entry.noAttack then text=text.." does not attack" end
        if entry.noAttackUnfortified and not entry.noAttack then text=text.." does not attack if unfortified" end
        if entry.removeAbilities then text=text.." attack loses abilities (keeps colour)" end
        local attackReduction=0
        local forcedDamage=false
        for _,reduction in ipairs(entry.attackReductions or {}) do
            attackReduction=attackReduction+reduction.amount
            if reduction.firstDamageUnit~=nil then forcedDamage=true end
        end
        if attackReduction>0 then text=text.." Attack reduction "..tostring(attackReduction) end
        if forcedDamage then text=text.." (assign damage to reducing Unit first)" end
        if entry.destroy then text=text.." is destroyed" end
        if entry.destroyIfBlocked then text=text.." destroyed if all attacks blocked" end
        if entry.immuneIgnored then text=text.." (Arcane Immunity ignores non-attack effects)" end
        parts[#parts+1]=text
    end
    table.sort(parts)
    local signature=table.concat(parts,"\n")
    if lastReport[seatPos]==signature then return end
    lastReport[seatPos]=signature
    if signature~="" then
        broadcastToColor("Card effects on enemies (apply manually if needed):\n"..signature,
            positionToColor(gStates.turnNumber),{1,0.6,0.1})
    end
end

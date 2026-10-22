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
    local spec=sides~=nil and (powered and sides.powered or sides.normal) or nil
    if spec==nil then return nil end
    if spec.choice~=nil and spec.choice~=chosenCategory then return nil end
    return spec
end

function combatEffectAdd(enemyEffects,enemyGUID,sourceGUID,spec)
    local entry=enemyEffects[enemyGUID]
    if entry==nil then
        entry={armourReduce=0,noAttack=false,removeAbilities=false,sources={}}
        enemyEffects[enemyGUID]=entry
    end
    entry.armourReduce=entry.armourReduce+(spec.armourReduce or 0)
    entry.noAttack=entry.noAttack or spec.noAttack==true
    entry.removeAbilities=entry.removeAbilities or spec.removeAbilities==true
    entry.sources[#entry.sources+1]=sourceGUID
end

-- Remind the active player when the set of applied effects changes.
function combatEffectReport(seatPos,enemyEffects)
    local parts={}
    for guid,entry in pairs(enemyEffects) do
        local pug=monsterPugs[guid]
        local name=pug~=nil and pug.name~=nil and tostring(pug.name) or guid
        local text=name..":"
        if entry.armourReduce>0 then text=text.." Armour -"..entry.armourReduce end
        if entry.noAttack then text=text.." does not attack" end
        if entry.removeAbilities then text=text.." attack loses abilities (keeps colour)" end
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

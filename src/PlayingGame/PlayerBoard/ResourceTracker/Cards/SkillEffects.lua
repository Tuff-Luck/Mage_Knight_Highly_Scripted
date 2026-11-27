-- Evaluate played Skill resource records without owning physical discovery,
-- links, player choices, or UI. Read the game catalog and turn state live.
local highlightPolicy=require("PlayingGame.PlayerBoard.ResourceTracker.Core.HighlightPolicy")
return function(deps)
    local skillChoicesForCurrentTurn=deps.skillChoicesForCurrentTurn
    local chosenEffect=deps.chosenEffect
    local skillUsesDayStrength=deps.skillUsesDayStrength
    local effectHasTrackedResource=deps.effectHasTrackedResource

    local function calculateSkill(skill,linkedTarget,unitState,inventoryCrystalCounts)
        local rule=skillResourceDefinitions[skill.guid]
        if rule==nil then
            return {guid=skill.guid,kind="skill",known=true,complete=false,
                status="yellow",powered=false,resources=nil}
        end
        local choices=skillChoicesForCurrentTurn(rule)
        local chosen=choices~=nil and chosenEffect(skill.guid,false,choices) or nil
        local effects=chosen
            or (skill.is_face_down==true and rule.flipped or nil)
            or (skillUsesDayStrength() and rule.day or rule.night)
            or rule.normal
        if rule.dynamic=="masterOfChaos" then
            -- The Master of Chaos marker advances when the played token is
            -- cleaned up: it earns the NEXT position's resource while in play.
            local nextSegment=((tonumber(gStates.masterOfChaos) or 0)%6)+1
            local segments={{move=1},{rangedColdFire=1},{influence=2},{attack=2},false,{block=3}}
            if nextSegment==5 then
                choices={{block=3},{move=1},
                    {key="coldFire",rangedColdFire=1,icon="ranged",iconOverlay="C"},
                    {attack=2},{influence=2}}
                effects=chosenEffect(skill.guid,false,choices)
            else effects=segments[nextSegment] end
        end
        if rule.locationInfluence~=nil then
            local player=turnOrder~=nil and turnOrder[gStates.turnNumber] or nil
            local place=player~=nil and player.avatarLocation or nil
            local fortified=place=="keep" or place=="mage tower"
                or (type(place)=="string" and place:sub(1,4)=="city")
            local value=place=="glade" and rule.locationInfluence.glade
                or (fortified and rule.locationInfluence.fortified
                or rule.locationInfluence.default)
            effects={influence=value}
        end
        -- Card/Unit linked bonuses must not be added until the linked target
        -- actually supplies a compatible printed resource.
        if rule.unitBoost~=nil or rule.shapeshift or rule.attackCardBoost
            or rule.manaOverload then
            effects=nil
        end

        -- Reusable board-state rule: effects can count qualifying Units instead
        -- of encoding Skill-specific calculations or depending on translated text.
        local unitSources={}
        local condition=rule.unitCondition
        local unitResolved=condition~=nil and unitState~=nil
        if unitResolved then
            local qualified=0
            local cap=condition.max or math.huge
            for _,entry in ipairs(unitState.units) do
                if (not condition.ready or entry.ready)
                    and (not condition.unwounded or entry.unwounded) then
                    qualified=qualified+1
                    if qualified<=cap then unitSources[#unitSources+1]=entry.guid end
                end
            end
            effects={[condition.resource]=math.min(qualified,cap)}
        end

        -- Derive resource values directly from the physical crystal inventory;
        -- multiple crystals of one colour count only once.
        local inventoryResolved=false
        if rule.inventoryDistinctColors~=nil then
            local spec=rule.inventoryDistinctColors
            local count=0
            for _,color in ipairs(spec.colors) do
                if (inventoryCrystalCounts[color] or 0)>0 then count=count+1 end
            end
            effects={[spec.resource]=count*(spec.valuePerColor or 1)}
            inventoryResolved=true
        end

        local tracked=effectHasTrackedResource(effects)
        -- A targeted Skill is recognized even when it supplies no numeric resource.
        local targeted=rule.enemyEffect~=nil and chosen~=nil
        local function hasCrystals(colors)
            for _,color in ipairs(colors) do
                if (inventoryCrystalCounts[color] or 0)<=0 then return false end
            end
            return true
        end
        -- Runic Shield: crystal-dependent element and Swiftness bonus.
        local swiftDouble=rule.swiftDoubleCrystals~=nil and hasCrystals(rule.swiftDoubleCrystals) or nil
        if rule.coldFireCrystals~=nil and effects~=nil and effects.block~=nil
            and hasCrystals(rule.coldFireCrystals) then
            effects={blockColdFire=effects.block}
        end
        local unitLinked=#unitSources>0
        local status=rule.untracked and "blue"
            or (rule.unitBoost~=nil or rule.shapeshift or rule.attackCardBoost) and "yellow"
            or (linkedTarget~=nil or unitLinked) and "purple"
            or (unitResolved or inventoryResolved) and "green"
            or rule.linkedCard~=nil and linkedTarget==nil and "yellow"
            or tracked and highlightPolicy.certainty(true,not rule.partial)
            or targeted and "green"
            or effects~=nil and "blue" or "yellow"
        local links={}
        if linkedTarget~=nil then links[#links+1]=linkedTarget end
        for _,guid in ipairs(unitSources) do links[#links+1]=guid end
        return {guid=skill.guid,kind="skill",known=true,
            complete=unitResolved or inventoryResolved or (tracked and not rule.partial) or targeted or linkedTarget~=nil,
            powered=skill.is_face_down==true or linkedTarget~=nil or unitLinked,
            forkedLightning=rule.forkedLightning==true,
            distinctAttackBonus=rule.distinctAttackBonus,shieldWallBonus=rule.shieldWallBonus,
            status=status,links=links,unitSources=unitSources,swiftDouble=swiftDouble,
            resources=effects,choices=choices}
    end

    return calculateSkill
end

-- Passive terrain overlays, remaining Skill/mana/puppet records, linked Unit highlights, Spirit Guides and Wings of Night costs. Runs at original scan boundaries.
local M={}
local resourceOps=require("PlayingGame.PlayerBoard.ResourceTracker.Core.ResourceOperations")
local terrainPolicy=require("PlayingGame.PlayerBoard.ResourceTracker.Cards.TerrainModifiers")
local highlightPolicy=require("PlayingGame.PlayerBoard.ResourceTracker.Core.HighlightPolicy")

-- Publish only effects belonging to the final, effective movement source.
-- Owned passives and independent non-Move effects are handled separately.
function M.playedMovement(context)
    local records,terrainModifiers,movementEffects=context.records,context.terrainModifiers,context.movementEffects
    for guid,record in pairs(records) do
        if record.pendingTerrainModifiers~=nil or record.pendingSingleSpaceDiscount~=nil
            or record.pendingIgnoreRampagers or record.pendingTerrainChoice then
            local movement=terrainPolicy.movementEligible(record,guid,context.resourceCardsMoveRole)
            if movement then
                for _,effect in ipairs(record.pendingTerrainModifiers or {}) do
                    terrainModifiers[#terrainModifiers+1]=effect
                end
                if record.pendingSingleSpaceDiscount~=nil then
                    movementEffects.singleSpaceDiscount=math.max(
                        movementEffects.singleSpaceDiscount,record.pendingSingleSpaceDiscount)
                end
                if record.pendingIgnoreRampagers then movementEffects.ignoreRampagers=true end
                if record.pendingTerrainChoice and record.status~="purple" then
                    record.status="yellow"
                    local obj=context.objects[record.sourceObjectGUID or guid]
                    if obj~=nil then context.setHighlight(obj,record.status,record.powered) end
                end
            end
        end
    end
end

function M.passiveTerrain(context)
    local seatPos, terrainModifiers, ownedSkillAtSeat = context.seatPos, context.terrainModifiers, context.ownedSkillAtSeat
    local footprint, manaObjects, placements = context.footprint, context.manaObjects, context.placements
    local manaColor, manaInsideFootprint = context.manaColor, context.manaInsideFootprint
    -- This is a reusable declarative overlay. All passives are owned-Skill
    -- effects, whether the physical token is resting at home or being played.
    -- Read immutable rule tables so identical scans don't invalidate movement.
    for skillGUID,rule in pairs(skillResourceDefinitions) do
        if ownedSkillAtSeat(skillGUID,seatPos) then
            terrainPolicy.passive(terrainModifiers,rule,gStates.dayRound)
            local extra=rule.skillManaTerrain
            if extra~=nil then
                local token=getObjectFromGUID(skillGUID)
                if token~=nil then
                    local area=footprint(token)
                    for _,mana in ipairs(manaObjects) do
                        if placements[mana.guid]=="play" and manaColor(mana)==extra.color
                            and manaInsideFootprint(mana,area) then
                            terrainPolicy.append(terrainModifiers,{extra.effect},gStates.dayRound)
                            break
                        end
                    end
                end
            end
        end
    end
end

function M.remainingObjects(context)
    local boostSource, records, objects = context.boostSource, context.records, context.objects
    local placements, usedMana, resourceObjectKind = context.placements, context.usedMana, context.resourceObjectKind
    local puppetResourceOptions, chosenEffect, showChoiceButtons = context.puppetResourceOptions, context.chosenEffect, context.showChoiceButtons
    local addResourceAmounts, totals, manaBySkill = context.addResourceAmounts, context.totals, context.manaBySkill
    local calculateSkill, skillLinksBySkill, unitState = context.calculateSkill, context.skillLinksBySkill, context.unitState
    local inventoryCrystalCounts, usesSkillLocation, movementEffects = context.inventoryCrystalCounts, context.usesSkillLocation, context.movementEffects
    local skillLinksByTarget, manaByObject, sidewaysSkillMana = context.skillLinksByTarget, context.manaByObject, context.sidewaysSkillMana
    local extraTerrainManaByObject, current, setHighlight = context.extraTerrainManaByObject, context.current, context.setHighlight
    -- The linking card itself contributes the target's upgraded effect. Mark it
    -- as a contributor so its powering mana token receives a green outline.
    for targetGUID,sourceGUID in pairs(boostSource) do
        if records[targetGUID]~=nil and records[targetGUID].contributes
            and records[sourceGUID]~=nil then
            records[sourceGUID].contributes=true
        end
    end

    for guid,obj in pairs(objects) do
        -- No contribution or outline for a Wound without a matching Skill.
        -- Previously linked Skills need their button/highlight finalization
        -- even though their resource record was created before target bonuses.
        local kind=resourceObjectKind(obj)
        if (records[guid]==nil or (kind=="skill" and placements[guid]=="play"))
            and kind~="wound" then
            local poweredTarget=usedMana[guid]
            local contributing=poweredTarget~=nil and records[poweredTarget]~=nil
                and records[poweredTarget].contributes==true
            local result
            if kind=="puppet" and (placements[guid]=="play" or placements[guid]=="unit") then
                local choices=obj.is_face_down~=true and puppetResourceOptions(guid) or nil
                local selected=choices~=nil and chosenEffect(guid,false,choices) or nil
                result={guid=guid,kind="puppet",known=true,complete=selected~=nil,
                    status=highlightPolicy.contribution(selected~=nil),
                    resources=selected,choices=choices,powered=false,links={}}
                showChoiceButtons(obj,choices,false)
                addResourceAmounts(result,totals)
            elseif kind=="skill" and placements[guid]=="play" then
                local conversion=manaBySkill[guid]
                local alreadyRecorded=records[guid]~=nil
                result=alreadyRecorded and records[guid]
                    or calculateSkill(obj,skillLinksBySkill[guid]
                        or (conversion~=nil and conversion.targetGUID or nil),
                        unitState,inventoryCrystalCounts)
                local skillRule=skillResourceDefinitions[guid]
                if skillRule~=nil then
                    if skillRule.locationInfluence~=nil
                        or skillRule.day~=nil or skillRule.night~=nil then
                        usesSkillLocation=true
                    end
                    -- Played Skill movement flags are declarative, just like
                    -- equivalent printed Action/Spell effects.
                    local spec=skillRule.movementEffects
                    local effects=spec~=nil
                        and (obj.is_face_down==true and spec.flipped or spec.normal) or nil
                    if effects~=nil then
                        if effects.jumpTwoSpaces then movementEffects.jumpTwoSpaces=true end
                        if effects.ignoreRampagers then movementEffects.ignoreRampagers=true end
                    end
                end
                showChoiceButtons(obj,result.choices,result.powered,nil,nil,result.resources)
                if not alreadyRecorded then addResourceAmounts(result,totals) end
                if skillLinksBySkill[guid]~=nil then
                    result.contributes=true
                    local link=skillLinksByTarget[skillLinksBySkill[guid]]
                    if link~=nil and link.manaGUID~=nil then
                        result.links[#result.links+1]=link.manaGUID
                    end
                end
                if conversion~=nil then
                    highlightPolicy.linkedSource(result)
                    result.powered=conversion.targetGUID~=nil
                    result.links={conversion.manaGUID}
                    if conversion.targetGUID~=nil then
                        result.links[#result.links+1]=conversion.targetGUID
                        local target=records[conversion.targetGUID]
                        result.contributes=target~=nil and target.contributes==true
                    end
                end
            else
                local conversion=kind=="mana" and manaByObject[guid] or nil
                local sidewaysLink=kind=="mana" and sidewaysSkillMana[guid] or nil
                local extraTerrainTarget=kind=="mana" and extraTerrainManaByObject[guid] or nil
                local skillContributes=sidewaysLink~=nil
                    and records[sidewaysLink.targetGUID]~=nil
                    and records[sidewaysLink.targetGUID].contributes==true
                local status=(conversion~=nil or sidewaysLink~=nil or extraTerrainTarget~=nil) and "purple"
                    or kind=="mana" and (contributing and "green" or "yellow") or "yellow"
                local bright=kind=="mana" and (poweredTarget~=nil or sidewaysLink~=nil)
                result={guid=guid,kind=kind,known=true,complete=false,
                    contributes=contributing or skillContributes,powered=bright,status=status,
                    powers=poweredTarget or (sidewaysLink~=nil and sidewaysLink.targetGUID or nil),
                    links=conversion~=nil and {conversion.skillGUID}
                        or sidewaysLink~=nil and {sidewaysLink.skillGUID,sidewaysLink.targetGUID}
                        or extraTerrainTarget~=nil and {extraTerrainTarget} or {},
                    convertedMana=conversion~=nil and conversion.converted or nil,
                    resources=nil}
            end
            records[guid]=result
            current[guid]=true
            setHighlight(obj,result.status,result.powered)
        end
    end
    return usesSkillLocation
end

function M.linkedUnits(context)
    local records, objects, activations = context.records, context.objects, context.activations
    local seatPos, unitResourceDefinitions, effectHasTrackedResource = context.seatPos, context.unitResourceDefinitions, context.effectHasTrackedResource
    local setHighlight = context.setHighlight
    -- Qualifying Units actually supplied the dynamic Skill resource. Show
    -- their link just like physical Skill/card interactions, without treating
    -- Command or Wound markers as resource sources themselves.
    for guid,record in pairs(records) do
        if record.unitSources~=nil then
            for _,unitGUID in ipairs(record.unitSources) do
                local unit,unitRecord=objects[unitGUID],records[unitGUID]
                if unit~=nil and unitRecord~=nil then
                    local activated=activations[unitGUID]~=nil
                        and activations[unitGUID].seatPos==seatPos
                        and unitResourceDefinitions[unitGUID]~=nil
                    -- Linked Skill sources normally show purple, but a Unit
                    -- currently activated by its Command token keeps its
                    -- own green/blue Resource Tracker status.
                    unitRecord.status,unitRecord.powered=highlightPolicy.dynamicUnit(
                        activated,activated and effectHasTrackedResource(unitRecord.resources))
                    unitRecord.contributes=true
                    unitRecord.links[#unitRecord.links+1]=guid
                    setHighlight(unit,unitRecord.status,unitRecord.powered)
                end
            end
        end
    end
end

function M.spiritGuides(context)
    local records, combatConfig, totals = context.records, context.combatConfig, context.totals
    local setHighlight, objects = context.setHighlight, context.objects
    -- Spirit Guides adds its Block point to ONE existing Block source,
    -- regardless of physical distance. Preserve the source's element, and
    -- never add the bonus before the target actually generates Block.
    local guideGUID="f36762"
    local guide=records[guideGUID]
    local linkedGUID=guide~=nil and gStates.blockSourceLinks~=nil
        and gStates.blockSourceLinks[guideGUID] or nil
    local boosted=linkedGUID~=nil and records[linkedGUID] or nil
    if boosted~=nil and boosted.contributes==true and boosted.resources~=nil then
        local bestKey,bestValue=nil,0
        for _,field in ipairs(combatConfig.spiritGuideBlockFields) do
            local value=tonumber(boosted.resources[field]) or 0
            if value>bestValue then bestKey,bestValue=field,value end
        end
        if bestKey~=nil then
            resourceOps.add(boosted,totals,bestKey,1)
            guide.links[#guide.links+1]=linkedGUID
            boosted.links=boosted.links or {}
            boosted.links[#boosted.links+1]=guideGUID
            highlightPolicy.linkedSource(guide)
            guide.complete=true
            -- Activated Units keep their normal resource-state highlight;
            -- the Spirit Guides arrow itself still shows the purple link.
            local redrawTarget=highlightPolicy.linkedTarget(boosted)
            setHighlight(objects[guideGUID],guide.status,guide.powered)
            if redrawTarget then
                setHighlight(objects[linkedGUID],boosted.status,boosted.powered)
            end
        end
    end
end

function M.wingsNight(context)
    local pendingWingsNight, records, resourceCardsMoveRole = context.pendingWingsNight, context.records, context.resourceCardsMoveRole
    local monsters, enemyEffects, totals = context.monsters, context.enemyEffects, context.totals
    -- Priority: existing Cumbersome assignments, Wings of Night, then Agility
    -- (which reads the remaining published resources). New automatic targets
    -- may use only the points left after both costs.
    table.sort(pendingWingsNight,function(a,b) return a.source<b.source end)
    for _,pending in ipairs(pendingWingsNight) do
        local spent,count=0,0
        local combatMoveAvailable=0
        local moveSources={}
        for guid,record in pairs(records) do
            local amount=math.max(0,tonumber(record.resources~=nil and record.resources.move) or 0)
            if amount>0 and resourceCardsMoveRole(guid,true)=="combat" then
                local key=context.sharedSourceKey(guid,record)
                local free=context.sharedSpendable(key,amount,"move",context.moveEligible)
                if free>0 then
                    combatMoveAvailable=combatMoveAvailable+free
                    moveSources[#moveSources+1]={guid=guid,amount=free}
                end
            end
        end
        for _,guid in ipairs(pending.targets) do
            local enemy=monsters[guid]
            if enemy~=nil and enemy.is_face_down~=true then
                local data=monsterPugs[guid]
                local perks=gStates~=nil and gStates.monsterPerks~=nil
                    and gStates.monsterPerks[guid] or nil
                local immune=(data~=nil and data.arcaneImmunity==true)
                    or (perks~=nil and perks.arcaneImmunity==true)
                local cost=count
                local affordable=cost<=combatMoveAvailable-spent
                combatEffectAdd(enemyEffects,guid,pending.source,
                    {noAttack=true,moveCost=cost,insufficientMove=not affordable},
                    pending.source)
                if not immune and affordable then count=count+1 spent=spent+cost end
            end
        end
        if spent>0 then
            local remaining=spent
            table.sort(moveSources,function(a,b) return a.guid<b.guid end)
            for _,source in ipairs(moveSources) do
                if remaining<=0 then break end
                local record=records[source.guid]
                local original=tonumber(record.resources.move) or 0
                local used=math.min(source.amount,original,remaining)
                if used>0 then
                    local adjusted={}
                    for key,value in pairs(record.resources) do adjusted[key]=value end
                    adjusted.move=original-used
                    record.resources=adjusted
                    record.wingsNightMoveSpent=(record.wingsNightMoveSpent or 0)+used
                    remaining=remaining-used
                end
            end
            totals.move=math.max(0,(tonumber(totals.move) or 0)-(spent-remaining))
        end
    end
end

return M

-- Cross-card bonuses and conversions, including Tirelessness, borrowed-enemy highlights, Deadly Precision, Ambush, and linked or discarded Wounds. Uses the current scan's records, resources and existing targeting callbacks.
local M={}

function M.process(context)
    local cards, records, totals = context.cards, context.records, context.totals
    local cardPosture, monsters, current = context.cardPosture, context.monsters, context.current
    local setHighlight, discarded, choiceCategory = context.setHighlight, context.discarded, context.choiceCategory
    local chosenEffect, overlapArea, footprints = context.chosenEffect, context.overlapArea, context.footprints
    local combatConfig, repeatByTarget, wounds = context.combatConfig, context.repeatByTarget, context.wounds
    local skillLinksByTarget, calculateSideways, showChoiceButtons = context.skillLinksByTarget, context.calculateSideways, context.showChoiceButtons
    local trackerPrivate, addResourceAmounts, links = context.trackerPrivate, context.addResourceAmounts, context.links
    -- Wolfhawk's Tirelessness affects only subsequently PLAYED cards, not
    -- already-played cards or Units. Maximal Effect repeats the bonus but
    -- each repeated target Action is still only one played card.
    for _,source in ipairs(cards) do
        local data=gameCards[source.guid]
        local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
        local modifier=rule~=nil and rule.followingMoveBonus or nil
        local origin=records[source.guid]
        if modifier~=nil and origin~=nil and origin.complete==true
            and origin.resources~=nil and (tonumber(origin.resources.move) or 0)>0
            and cardPosture(source)=="upright"
            and (source.is_face_down~=true or origin.repeatLink~=nil) then
            local order=gStates.resourceCardPlayOrder[source.guid]
            local candidates={}
            for _,target in ipairs(cards) do
                local targetRecord=records[target.guid]
                local targetOrder=gStates.resourceCardPlayOrder[target.guid]
                if target.guid~=source.guid and targetOrder~=nil and order~=nil
                    and targetOrder>order and targetRecord~=nil
                    and targetRecord.complete==true and targetRecord.resources~=nil
                    and (tonumber(targetRecord.resources.move) or 0)>0 then
                    candidates[#candidates+1]=target
                end
            end
            table.sort(candidates,function(a,b)
                local aa=gStates.resourceCardPlayOrder[a.guid]
                local bb=gStates.resourceCardPlayOrder[b.guid]
                return aa==bb and a.guid<b.guid or aa<bb
            end)
            local spec=origin.powered and modifier.powered or modifier.normal
            local count=spec.all and #candidates or math.min(#candidates,spec.count or 1)
            local extra=(spec.amount or 1)*(origin.repeatCount or 1)
            for i=1,count do
                local target=candidates[i]
                local record=records[target.guid]
                -- The calculator may return a shared printed resource table.
                -- Copy before applying this scan-only modifier.
                local adjusted={}
                for key,value in pairs(record.resources) do adjusted[key]=value end
                adjusted.move=adjusted.move+extra
                record.resources=adjusted
                record.tirelessnessBonus=(record.tirelessnessBonus or 0)+extra
                totals.move=(totals.move or 0)+extra
            end
        end
    end
    -- Only outline enemies that actually supply printed values to a card.
    -- A debuff target (including Banner of Fear) is already identified by
    -- its arrow; outlining the first target is misleading for multi-target effects.
    -- Iterate cards, not records: this pass also creates enemy records.
    for _,card in ipairs(cards) do
        local record=records[card.guid]
        local data=gameCards[card.guid]
        local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
        local borrowedEnemy=record~=nil and (record.possessEnemyGUID~=nil
            or (rule~=nil and rule.enemyIconBlock==true))
        if borrowedEnemy and record.enemyGUID~=nil then
            local enemy=monsters[record.enemyGUID]
            if enemy~=nil then
                local enemyRecord=records[enemy.guid]
                if enemyRecord==nil then
                    enemyRecord={guid=enemy.guid,kind="monster",known=true,complete=true,
                        powered=true,links={},status="purple",resources=nil}
                    records[enemy.guid]=enemyRecord
                end
                enemyRecord.links[#enemyRecord.links+1]=record.guid
                current[enemy.guid]=true
                setHighlight(enemy,"purple",true)
            end
        end
    end
    -- Deadly Precision's stronger conversion works only on one physically
    -- overlapping, played Action with a single active melee Attack value.
    -- Do not invent a target or a mana payment when links are ambiguous.
    for _,source in ipairs(cards) do
        local data=gameCards[source.guid]
        local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
        local sourceRecord=records[source.guid]
        if rule~=nil and rule.poweredLinkConversion==true
            and sourceRecord~=nil and sourceRecord.powered==true
            and sourceRecord.resources~=nil and cardPosture(source)=="upright"
            and discarded[source.guid]==nil
            and choiceCategory(chosenEffect(source.guid,true,rule.poweredChoices))=="convert" then
            local candidates={}
            for _,target in ipairs(cards) do
                local targetData=gameCards[target.guid]
                local targetRecord=records[target.guid]
                if target.guid~=source.guid and targetData~=nil
                    and (targetData.cardType=="Starting" or targetData.cardType=="Advanced Action")
                    and targetRecord~=nil and targetRecord.resources~=nil
                    and cardPosture(target)=="upright" and target.is_face_down~=true
                    and discarded[target.guid]==nil then
                    local attackKey=nil
                    local ambiguous=false
                    for _,key in ipairs({"attack","attackFire","attackIce",
                        "attackColdFire","attackPsychic"}) do
                        if (tonumber(targetRecord.resources[key]) or 0)>0 then
                            if attackKey~=nil then ambiguous=true break end
                            attackKey=key
                        end
                    end
                    local area=overlapArea(footprints[source.guid],footprints[target.guid])
                    if attackKey~=nil and not ambiguous and area>0 then
                        candidates[#candidates+1]={card=target,record=targetRecord,
                            key=attackKey,area=area}
                    end
                end
            end
            table.sort(candidates,function(a,b)
                if a.area~=b.area then return a.area>b.area end
                return a.card.guid<b.card.guid
            end)
            local best=candidates[1]
            if best~=nil and (candidates[2]==nil or best.area>candidates[2].area) then
                local to="ranged"..best.key:sub(7)
                local amount=best.record.resources[best.key]
                local updated={}
                for key,value in pairs(best.record.resources) do updated[key]=value end
                updated[best.key]=nil
                updated[to]=(updated[to] or 0)+amount
                best.record.resources=updated
                totals[best.key]=(totals[best.key] or 0)-amount
                totals[to]=(totals[to] or 0)+amount
                sourceRecord.links[#sourceRecord.links+1]=best.card.guid
                best.record.links[#best.record.links+1]=source.guid
                sourceRecord.complete=true
                sourceRecord.contributes=true
                sourceRecord.status="purple"
                best.record.status="purple"
                setHighlight(source,"purple",true)
                setHighlight(best.card,"purple",best.record.powered)
            end
        end
    end
    -- Ambush's explicit card assignment takes priority over physical overlap.
    -- The Move enemy target stays in the ordinary combat assignment registry.
    local combatCategories=combatConfig.ambushCombatCategories
    for _,source in ipairs(cards) do
        local data=gameCards[source.guid]
        local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
        local sourceRecord=records[source.guid]
        if rule~=nil and rule.combatLink~=nil and sourceRecord~=nil
            and sourceRecord.resources~=nil and cardPosture(source)=="upright"
            and (discarded[source.guid]==nil or repeatByTarget[source.guid]~=nil) then
            local best,bestCategory,bestType,bestOverlap=nil,nil,nil,0
            local function chooseCategory(target)
                local record=records[target.guid]
                if discarded[target.guid]~=nil
                    or not combatConfig.ambushEligibleTarget(target.guid,record,source.guid) then
                    return nil,nil
                end
                for _,key in ipairs(combatCategories) do
                    if (tonumber(record.resources[key]) or 0)>0 then
                        return key,key:sub(1,5)=="block" and "block" or "attack"
                    end
                end
                return nil,nil
            end
            local saved=gStates~=nil and gStates.ambushCombatLinks or nil
            local savedGUID=saved~=nil and saved[source.guid] or nil
            if savedGUID~=nil then
                local target=getObjectFromGUID(savedGUID)
                if target~=nil then
                    local category,kind=chooseCategory(target)
                    if category~=nil then
                        best,bestCategory,bestType=target,category,kind
                    end
                end
                -- A lifted target keeps its assignment until the settled scan.
                if best==nil and (target==nil or not combatConfig.cardInTransit(target)) then
                    saved[source.guid]=nil
                    savedGUID=nil
                end
            end
            if best==nil and savedGUID==nil then
                for _,target in ipairs(cards) do
                    local area=target.guid~=source.guid
                        and overlapArea(footprints[source.guid],footprints[target.guid]) or 0
                    if area>0 then
                        local category,kind=chooseCategory(target)
                        if category~=nil and (area>bestOverlap
                            or (area==bestOverlap and best~=nil and target.guid<best.guid)) then
                            best,bestCategory,bestType,bestOverlap=target,category,kind,area
                        end
                    end
                end
            end
            if best~=nil and bestCategory~=nil and bestType~=nil then
                local bonusRule=sourceRecord.powered and rule.combatLink.powered
                    or rule.combatLink.normal
                local bonus=bonusRule[bestType]*(sourceRecord.repeatCount or 1)
                local targetRecord=records[best.guid]
                if targetRecord==nil or targetRecord.resources==nil then
                    error("The linked combat target has no resource record.",2)
                end
                local adjusted={}
                for key,value in pairs(targetRecord.resources) do adjusted[key]=value end
                local targetAmount=adjusted[bestCategory]
                if type(targetAmount)~="number" then
                    error("The linked combat target is missing its selected resource.",2)
                end
                adjusted[bestCategory]=targetAmount+bonus
                targetRecord.resources=adjusted
                -- Shield of the Fallen Kings keeps separate Block effects.
                -- Ambush augments only the first one, not each equal split.
                if bestType=="block" and (tonumber(targetRecord.repeatBlocks) or 1)>1 then
                    targetRecord.ambushFirstBlockBonus=
                        (targetRecord.ambushFirstBlockBonus or 0)+bonus
                end
                totals[bestCategory]=(totals[bestCategory] or 0)+bonus
                if sourceRecord.links==nil or targetRecord.links==nil then
                    error("A linked combat record has no link list.",2)
                end
                sourceRecord.links[#sourceRecord.links+1]=best.guid
                targetRecord.links[#targetRecord.links+1]=source.guid
                sourceRecord.status="purple"
                targetRecord.status="purple"
                sourceRecord.contributes=true
                setHighlight(source,sourceRecord.status,sourceRecord.powered)
                setHighlight(best,targetRecord.status,targetRecord.powered)
            end
        end
    end
    -- Retire stale manual links when Ambush itself is no longer a played
    -- upright card. Transiently lifted cards keep their pending assignments.
    for guid in pairs(gStates~=nil and gStates.ambushCombatLinks or {}) do
        local record=records[guid]
        local data=gameCards[guid]
        local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
        local obj=getObjectFromGUID(guid)
        if (record==nil or record.complete~=true or record.resources==nil
            or rule==nil or rule.combatLink==nil or obj==nil
            or obj.is_face_down==true or cardPosture(obj)~="upright")
            and not combatConfig.cardInTransit(obj) then
            gStates.ambushCombatLinks[guid]=nil
        end
    end
    -- An unlinked Wound is inert. Only an attached Skill or a deliberate
    -- discard payment gives it a tracker outline.
    for _,wound in ipairs(wounds) do
        local skillLink=skillLinksByTarget[wound.guid]
        if skillLink~=nil then
            local result=calculateSideways(wound,true,skillLink)
            result.kind="wound"
            showChoiceButtons(wound,trackerPrivate.sidewaysChoices,result.powered)
            addResourceAmounts(result,totals)
            records[wound.guid]=result
            current[wound.guid]=true
            setHighlight(wound,result.status,result.powered)
        elseif links[wound.guid]~=nil and #links[wound.guid]>0 then
            local result={guid=wound.guid,kind="wound",known=true,complete=true,
                powered=false,links=links[wound.guid],status="purple",resources=nil}
            records[wound.guid]=result
            current[wound.guid]=true
            setHighlight(wound,result.status,false)
        end
    end
end

return M

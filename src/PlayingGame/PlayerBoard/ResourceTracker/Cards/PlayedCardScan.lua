-- Per-card record processing after mana and Action links have been resolved. Applies existing conditional resources, target effects, inventory choices, card controls and movement/combat flags; returns scalar flags to the scan coordinator. Does not discover mana, publish scans or change phase ordering.
local M={}

function M.process(context)
    local seatPos, cards, powered = context.seatPos, context.cards, context.powered
    local boostBy, repeatByTarget, linkedCardBySource = context.boostBy, context.repeatByTarget, context.linkedCardBySource
    local discarded, hasDiscard, spellCastingPaid = context.discarded, context.hasDiscard, context.spellCastingPaid
    local links, skillLinksByTarget, discardBoostBySource = context.links, context.skillLinksByTarget, context.discardBoostBySource
    local woundCount, enemyEntries, monsters = context.woundCount, context.enemyEntries, context.monsters
    local footprints, combatCalcOn, combatEnemyInPlay = context.footprints, context.combatCalcOn, context.combatEnemyInPlay
    local combatAssignmentState, combatConfig, trackerPrivate = context.combatAssignmentState, context.combatConfig, context.trackerPrivate
    local paidManaChoices, inventoryCrystalCounts, playMonsters = context.paidManaChoices, context.inventoryCrystalCounts, context.playMonsters
    local unitState, manaByCard, current = context.unitState, context.manaByCard, context.current
    local records, totals, enemyEffects = context.records, context.totals, context.enemyEffects
    local pendingWingsNight, extraTerrainManaByCard, terrainModifiers = context.pendingWingsNight, context.extraTerrainManaByCard, context.terrainModifiers
    local movementEffects, cardPosture, cardCanPlaySideways = context.movementEffects, context.cardPosture, context.cardCanPlaySideways
    local linkedColorChoices, overlapArea, footprint = context.linkedColorChoices, context.overlapArea, context.footprint
    local combatNearestEnemyGUID, enemyPrintedIconBonus, sideChoices = context.combatNearestEnemyGUID, context.enemyPrintedIconBonus, context.sideChoices
    local guessInitialCardChoice, calculateCard, currentChoice = context.guessInitialCardChoice, context.calculateCard, context.currentChoice
    local choiceCategory, combatEnemyHasTrait, enemyPrintedPossessAttack = context.choiceCategory, context.combatEnemyHasTrait, context.enemyPrintedPossessAttack
    local combatEnemyData, combatIsSummonedToken, currentSpellTerrain = context.combatEnemyData, context.combatIsSummonedToken, context.currentSpellTerrain
    local inventorySetChoice, effectHasTrackedResource, combatEffectChosenEnemy = context.inventorySetChoice, context.effectHasTrackedResource, context.combatEffectChosenEnemy
    local combatEffectTargetEligible, resourceCardsRecruitInfluenceBonus, showChoiceButtons = context.combatEffectTargetEligible, context.resourceCardsRecruitInfluenceBonus, context.showChoiceButtons
    local resourceCardsDetailsOpen, cardTerrainEffects, terrainEffectActive = context.resourceCardsDetailsOpen, context.cardTerrainEffects, context.terrainEffectActive
    local resourceCardsIgnoreSiteFortification, addResourceAmounts, setHighlight = context.resourceCardsIgnoreSiteFortification, context.addResourceAmounts, context.setHighlight
    local usesCurrentHexBlock, usesCurrentHexHealing, ignoreSiteFortifications = context.usesCurrentHexBlock, context.usesCurrentHexHealing, context.ignoreSiteFortifications
    local unitCombatBoost, preventUnitDamage, allUnitResistances = context.unitCombatBoost, context.preventUnitDamage, context.allUnitResistances
    local heroFirstWoundIgnored = context.heroFirstWoundIgnored
    local claimedPossessEnemies={}
    for _,card in ipairs(cards) do
        local cardData=gameCards[card.guid]
        local rule=cardData~=nil and cardResourceDefinitions[cardData.resourceKey] or nil
        local artifactBreak=cardData~=nil and cardData.cardType=="Artifact"
            and resourceCardsArtifactBroken(card.guid,card)
        local isStrong=powered[card.guid]==true or boostBy[card.guid]~=nil or artifactBreak
        if repeatByTarget[card.guid]~=nil then
            isStrong=repeatByTarget[card.guid].powered
        end
        local linkedChoices=linkedColorChoices(rule,linkedCardBySource[card.guid],isStrong)
        local repeatedColor=repeatByTarget[card.guid]
        if repeatedColor~=nil and repeatedColor.options~=nil then
            linkedChoices=repeatedColor.options[1]
        end
        if rule~=nil and rule.effectManaChoice~=nil then
            linkedChoices=paidManaChoices(card.guid,rule,isStrong,boostBy[card.guid])
        end
        -- Cold Toughness uses the enemy being blocked in the Combat Calculator,
        -- not an enemy physically placed on the Action card. Read the active lock
        -- first (including a just-clicked retarget), then a restored arrow.
        -- Outside the calculator, the existing physical overlap remains usable.
        local enemyTarget,enemyBonus=nil,nil
        if rule~=nil and rule.enemyIconBlock==true and isStrong
            and cardPosture(card)=="upright" then
            local targetGUID=nil
            if combatCalcOn then
                if combatAssignmentState.seat==seatPos then
                    targetGUID=combatAssignmentState.targets[card.guid]
                end
                if targetGUID==nil or monsters[targetGUID]==nil
                    or monsters[targetGUID].is_face_down==true then
                    targetGUID=nil
                    for guid in pairs(attackAssignmentsTargetGUIDs(card.guid)) do
                        local enemy=monsters[guid]
                        if enemy~=nil and enemy.is_face_down~=true
                            and (targetGUID==nil or guid<targetGUID) then
                            targetGUID=guid
                        end
                    end
                end
            end
            if targetGUID~=nil then enemyTarget=monsters[targetGUID] end
            -- Match the calculator's initial nearest-enemy assignment before
            -- its first panel refresh has populated the source lock.
            if enemyTarget==nil and combatCalcOn then
                local nearest=combatNearestEnemyGUID(
                    {guid=card.guid,ranged=0,siege=0,attack=0},enemyEntries)
                if nearest~=nil then enemyTarget=monsters[nearest] end
            end
            if enemyTarget==nil then
                local bestArea=0
                for guid,monster in pairs(monsters) do
                    if monster.is_face_down~=true then
                        local area=overlapArea(footprints[card.guid],footprint(monster))
                        if area>bestArea or (area==bestArea and area>0 and enemyTarget~=nil
                            and guid<enemyTarget.guid) then
                            enemyTarget,bestArea=monster,area
                        end
                    end
                end
            end
            if enemyTarget~=nil then
                enemyBonus=enemyPrintedIconBonus(monsterPugs[enemyTarget.guid])
            end
        end
        local choices=nil
        if discarded[card.guid]==nil or repeatByTarget[card.guid]~=nil then
            if cardPosture(card)=="sideways" then
                if cardCanPlaySideways(card) then choices=trackerPrivate.sidewaysChoices end
            elseif (cardData==nil or cardData.resourceAlwaysNeutral~=true)
                and (rule==nil or rule.requiredLink==nil or hasDiscard[card.guid]==true
                    or (isStrong and rule.strongNoDiscard==true))
                and (cardData==nil or cardData.cardType~="Spell"
                    or spellCastingPaid[card.guid]==true) then
                -- Don't guess an unavailable effect before its payment/link is present.
                choices=linkedChoices or sideChoices(rule,isStrong)
            end
        end
        if choices~=nil and cardPosture(card)~="discard" then
            guessInitialCardChoice(card,choices,seatPos,rule,cardPosture(card)=="sideways",
                cards,footprints,records)
        end
        local result=calculateCard(card,powered[card.guid]==true or artifactBreak,boostBy[card.guid],
            links[card.guid],discarded[card.guid]~=nil,hasDiscard[card.guid]==true,
            skillLinksByTarget[card.guid],linkedChoices,repeatByTarget[card.guid],
            discardBoostBySource[card.guid],woundCount,enemyBonus,
            spellCastingPaid[card.guid]==true)
        if rule~=nil and rule.grailFamePerHealing~=nil
            and not result.powered and result.complete
            and cardPosture(card)=="upright" then
            local used=gStates.artifactGrailHealingUsed~=nil
                and gStates.artifactGrailHealingUsed[card.guid] or 0
            used=math.max(0,math.min(2,tonumber(used) or 0))
            if used>0 then
                result.fameRep=result.fameRep or {}
                result.fameRep.fame=(result.fameRep.fame or 0)
                    +used*rule.grailFamePerHealing
            end
        end
        if rule~=nil and rule.staffDualChoices==true and combatEnemyInPlay then
            -- Only the blue crystal effect can be used during combat. Existing
            -- pre-combat Unit Ready history is preserved separately below.
            if result.powered~=true then
                local _,option=currentChoice(card.guid,false,linkedChoices)
                if option~="blue" then
                    result.resources=nil
                    result.complete=false
                    result.status="yellow"
                end
            elseif result.resources~=nil then
                -- A Break selected before combat can remain physically on the
                -- table; its Healing points cannot be spent during combat.
                local combatResources={}
                for key,value in pairs(result.resources) do
                    if key~="healing" then combatResources[key]=value end
                end
                result.resources=combatResources
            end
        end
        -- This explicit flag distinguishes browsing Magic Talent's loaned
        -- Spell from an actual paid cast, including non-numeric utility Spells.
        if cardData~=nil and cardData.cardType=="Spell" then
            result.spellCastPaid=spellCastingPaid[card.guid]==true
            local repeats=result.spellCastPaid
                and magicTalentOfferSpellCastCount~=nil
                and magicTalentOfferSpellCastCount(seatPos,card.guid) or 1
            if repeats>1 then
                local multiplied={}
                for key,value in pairs(result.resources or {}) do
                    multiplied[key]=trackerPrivate.totalsKeys[key] and type(value)=="number"
                        and value*repeats or value
                end
                result.resources=multiplied
                result.repeatCount=repeats
                if result.fameRep~=nil then
                    local fameRep={}
                    for key,value in pairs(result.fameRep) do
                        fameRep[key]=type(value)=="number" and value*repeats or value
                    end
                    result.fameRep=fameRep
                end
            end
        end

        if rule~=nil and rule.poweredTargetBonuses~=nil and result.powered==true
            and result.resources~=nil and cardPosture(card)=="upright" then
            local targetGUIDs={}
            local hasAssignmentAPI=type(attackAssignmentsTargetGUIDs)=="function"
            if hasAssignmentAPI then
                for targetGUID in pairs(attackAssignmentsTargetGUIDs(card.guid)) do
                    local enemy=monsters[targetGUID]
                    if enemy~=nil and enemy.is_face_down~=true then targetGUIDs[targetGUID]=true end
                end
            end
            if next(targetGUIDs)==nil then
                local targetGUID=nil
                if not hasAssignmentAPI then
                    targetGUID=combatAssignmentState.targets[card.guid]
                end
                if targetGUID==nil or monsters[targetGUID]==nil
                    or monsters[targetGUID].is_face_down==true then
                    targetGUID=combatNearestEnemyGUID(card.guid,enemyEntries)
                end
                if targetGUID~=nil then targetGUIDs[targetGUID]=true end
            end
            -- result.resources can alias the rule's choice table; never mutate it.
            local boosted={}
            for category,value in pairs(result.resources) do boosted[category]=value end
            result.resources=boosted
            for resource,bonus in pairs(rule.poweredTargetBonuses) do
                if (tonumber(result.resources[resource]) or 0)>0 then
                    local applies=false
                    for targetGUID in pairs(targetGUIDs) do
                        local targetData=monsterPugs[targetGUID]
                        local targetPerks=gStates.monsterPerks~=nil
                            and gStates.monsterPerks[targetGUID] or nil
                        if targetData~=nil then
                            for _,trait in ipairs(bonus.traits) do
                                if combatEnemyHasTrait(targetData,targetPerks,trait) then
                                    applies=true
                                    break
                                end
                            end
                        end
                        if applies then break end
                    end
                    if applies then
                        result.resources[resource]=result.resources[resource]+bonus.amount
                    end
                end
            end
        end

        -- Possess links to one face-up enemy placed over the powered Spell.
        -- The enemy cannot be Arcane Immune and its printed Attack (including
        -- all printed elements/strikes) becomes our melee Attack this combat.
        if rule~=nil and rule.enemyAttackLink==true and result.powered
            and result.resources~=nil and cardPosture(card)=="upright"
            and (discarded[card.guid]==nil or repeatByTarget[card.guid]~=nil) then
            local best,bestResources,bestArea=nil,nil,0
            for guid,enemy in pairs(monsters) do
                if enemy.is_face_down~=true and claimedPossessEnemies[guid]~=true then
                    local resources=enemyPrintedPossessAttack(monsterPugs[guid],guid)
                    if resources~=nil then
                        local area=overlapArea(footprints[card.guid],footprint(enemy))
                        if area>bestArea or (area==bestArea and area>0
                            and best~=nil and guid<best.guid) then
                            best,bestResources,bestArea=enemy,resources,area
                        end
                    end
                end
            end
            if best~=nil then
                claimedPossessEnemies[best.guid]=true
                result.resources=bestResources
                result.enemyGUID=best.guid
                result.possessEnemyGUID=best.guid
                result.links[#result.links+1]=best.guid
                result.status="purple"
                combatEffectAdd(enemyEffects,best.guid,card.guid,{noAttack=true,all=true})
            end
        end

        -- Sacrifice's pairs become mana, so preserve their Attack after conversion.
        if rule~=nil and rule.crystalPairAttack~=nil then
            if result.powered and result.resources~=nil
                and cardPosture(card)=="upright" and card.is_face_down~=true then
                local chosen,category=currentChoice(card.guid,true,rule.poweredChoices)
                local colors=rule.crystalPairAttack[category]
                if colors~=nil and chosen~=nil then
                    local available=math.min(inventoryCrystalCounts[colors[1]] or 0,
                        inventoryCrystalCounts[colors[2]] or 0)
                    local snapshot=combatConfig.sacrificeCastPairs[card.guid]
                    if snapshot~=nil and (snapshot.seat~=seatPos or snapshot.category~=category) then
                        snapshot=nil
                        combatConfig.sacrificeCastPairs[card.guid]=nil
                    end
                    if snapshot==nil and available>0 then
                        snapshot={seat=seatPos,category=category,pairs=available}
                        combatConfig.sacrificeCastPairs[card.guid]=snapshot
                    end
                    local pairCount=snapshot~=nil and snapshot.pairs or 0
                    result.resources={[category]=(chosen[category] or 0)*pairCount}
                    result.complete=pairCount>0
                    result.status=pairCount>0 and "green" or "blue"
                    result.sacrificePairs=pairCount
                end
            else
                combatConfig.sacrificeCastPairs[card.guid]=nil
            end
        end
        if rule~=nil and rule.poweredEnemyBonus~=nil and result.powered
            and result.resources~=nil and cardPosture(card)=="upright" then
            local enemyCount=0
            for guid,enemy in pairs(playMonsters) do
                local data,mode=combatEnemyData(guid,enemy)
                -- Summons and attack-only reminders are not extra enemy tokens.
                if enemy.is_face_down~=true and data~=nil
                    and data.attackOnly~=true and mode~="attackOnly"
                    and not combatIsSummonedToken(guid) then
                    enemyCount=enemyCount+1
                end
            end
            local updated={}
            for category,value in pairs(result.resources) do
                updated[category]=(trackerPrivate.totalsKeys[category] and type(value)=="number")
                    and value+enemyCount*rule.poweredEnemyBonus or value
            end
            result.resources=updated
        end
        if rule~=nil and rule.forestHealing~=nil and result.resources~=nil
            and result.resources.healing~=nil and cardPosture(card)=="upright" then
            usesCurrentHexHealing=true
            if currentSpellTerrain()=="forest" then
                local updated={}
                for category,value in pairs(result.resources) do updated[category]=value end
                updated.healing=rule.forestHealing
                result.resources=updated
            end
        end
        -- Druidic Staff's Break side selects TWO different options without
        -- discards. The second menu uses the same independent choice-row UI
        -- as crystal-set effects, but cannot select the first option again.
        -- Each colour is resolved once; Green contributes Heal 3, while
        -- movement/crystal/Unit-ready options require their physical actions.
        local staffDual=rule~=nil and rule.staffDualChoices==true
            and result.powered==true and cardPosture(card)=="upright"
        local staffExtraChoices=nil
        if staffDual then
            local _,firstKey=currentChoice(card.guid,true,choices)
            staffExtraChoices={}
            for _,option in ipairs(choices or {}) do
                if choiceCategory(option)~=firstKey then
                    staffExtraChoices[#staffExtraChoices+1]=option
                end
            end
            local second=inventorySetChoice(card.guid,1,staffExtraChoices,choices)
            local adjusted={}
            for key,value in pairs(result.resources or {}) do adjusted[key]=value end
            for key,value in pairs(second or {}) do
                if trackerPrivate.totalsKeys[key] and type(value)=="number" then
                    adjusted[key]=(adjusted[key] or 0)+value
                end
            end
            result.resources=adjusted
            result.inventorySetCount=second~=nil and 1 or 0
            result.complete=result.complete==true and firstKey~=nil
                and second~=nil and choiceCategory(second)~=firstKey
            -- The non-numeric options need the player to carry out the move,
            -- crystal gain, or Unit ready. Do not show fully automated green.
            if (firstKey~="green"
                or choiceCategory(second)~="green") and result.status=="green" then
                result.status="yellow"
            end
        end
        local inventorySpec=staffDual and {choices=staffExtraChoices}
            or (rule~=nil and rule.inventorySetChoices or nil)
        local inventorySets=staffDual and 1 or 0
        if not staffDual and inventorySpec~=nil and result.powered and result.resources~=nil
            and cardPosture(card)=="upright" then
            inventorySets=math.huge
            for _,color in ipairs(inventorySpec.colors) do
                inventorySets=math.min(inventorySets,inventoryCrystalCounts[color] or 0)
            end
            if inventorySets==math.huge then inventorySets=0 end
            result.inventorySetCount=inventorySets
            -- Each crystal set may make its own choice. Scale the result only
            -- after summing those choices so repeated Actions remain correct.
            local multiplier=result.repeatCount or 1
            local adjusted={}
            for category,value in pairs(result.resources) do adjusted[category]=value end
            for index=1,inventorySets do
                local bonus=inventorySetChoice(card.guid,index,inventorySpec.choices,choices)
                if bonus~=nil then
                    for category,value in pairs(bonus) do
                        if type(value)=="number" then
                            adjusted[category]=(adjusted[category] or 0)+value*multiplier
                        end
                    end
                end
            end
            result.resources=adjusted
            if result.status=="blue" and effectHasTrackedResource(adjusted) then
                result.status="green"
            end
        end
        if enemyTarget~=nil and result.resources~=nil then
            result.enemyGUID=enemyTarget.guid
            result.links[#result.links+1]=enemyTarget.guid
            result.status="purple"
        end
        -- Enemy debuffs can have a separate lock from printed Attack resources.
        if rule~=nil and rule.enemyEffect~=nil and result.resources~=nil
            and result.powered~=nil and cardPosture(card)=="upright"
            and result.status~="yellow"
            and (result.enemyGUID==nil or rule.dodgeAttackSplit==true) then
            local _,category=currentChoice(card.guid,result.powered,choices)
            local spec=combatEffectSpec(rule,result.powered,category)
            if spec~=nil or (result.repeatLink~=nil and result.repeatLink.count>1) then
                if result.repeatLink~=nil and result.repeatLink.count>1
                    and rule.dodgeAttackSplit~=true then
                    -- Maximal Effect plays each non-numeric enemy effect once.
                    -- A target key per use permits three different enemies,
                    -- while the printed Attack/Block points remain composite.
                    result.enemyEffectTargetKeys={}
                    result.enemyEffectTargetGUIDs={}
                    for index=1,result.repeatCount do
                        local options=result.repeatLink.options~=nil
                            and result.repeatLink.options[index] or choices
                        local _,selected=combatConfig.repeatChoiceFor(
                            card.guid,result.powered,options,index)
                        local effect=combatEffectSpec(rule,result.powered,selected)
                        if effect~=nil then
                            local key=card.guid.."#rep"..index
                            if not effect.all then
                                result.enemyEffectTargetKeys[#result.enemyEffectTargetKeys+1]=key
                            end
                            local target=combatEffectChosenEnemy(key,footprints[card.guid],
                                monsters,combatEffectTargetEligible(effect))
                            if effect.all then
                                for enemyGUID,monster in pairs(monsters) do
                                    if monster.is_face_down~=true then
                                        combatEffectAdd(enemyEffects,enemyGUID,card.guid,effect,key)
                                        result.links[#result.links+1]=enemyGUID
                                        result.status="purple"
                                    end
                                end
                            elseif target~=nil then
                                combatEffectAdd(enemyEffects,target.guid,card.guid,effect,key)
                                result.enemyGUID=result.enemyGUID or target.guid
                                result.enemyEffectTargetGUIDs[key]=target.guid
                                result.links[#result.links+1]=target.guid
                                result.status="purple"
                            end
                        end
                    end
                elseif rule.dodgeAttackSplit==true then
                    -- The optional Attack is automatic, with its own ordinary
                    -- target assignment. Always expose two -2 targets when
                    -- powered, even if both currently point to one enemy.
                    local count=(result.powered and 2 or 1)*(result.repeatCount or 1)
                    result.enemyEffectTargetKeys={}
                    result.enemyEffectTargetGUIDs={}
                    for index=1,count do
                        local key=card.guid.."#effect"..index
                        local target=combatEffectChosenEnemy(key,footprints[card.guid],
                            monsters,combatEffectTargetEligible({attackReduce=2}))
                        result.enemyEffectTargetKeys[#result.enemyEffectTargetKeys+1]=key
                        if target~=nil then
                            -- Do not merge the two reductions. When both aim
                            -- at one multi-attack enemy, the calculator can
                            -- select a different printed Attack for each.
                            -- Two selections of the SAME Attack still total -4.
                            combatEffectAdd(enemyEffects,target.guid,card.guid,
                                {attackReduce=2},key)
                            result.enemyGUID=result.enemyGUID or target.guid
                            result.enemyEffectTargetGUIDs[key]=target.guid
                            result.links[#result.links+1]=target.guid
                            result.status="purple"
                        end
                    end
                elseif spec~=nil then
                -- The repeated-effect branch may run without a spec;
                -- only this ordinary-effect branch reads spec fields.
                local key=rule.separateEffectTarget and not result.powered
                    and (card.guid.."#effect") or card.guid
                if (tonumber(spec.maxTargets) or 0)>1 then
                    -- Banner of Fear (Lost Legion): at most three different
                    -- enemies are unable to attack. Each target is its own
                    -- persistent physical arrow; right-click adds another.
                    local targets=attackAssignmentsTargetGUIDs(key)
                    local primary=combatEffectChosenEnemy(key,footprints[card.guid],
                        monsters,combatEffectTargetEligible(spec))
                    if next(targets)==nil and primary~=nil then targets[primary.guid]=true end
                    local ordered={}
                    for guid in pairs(targets) do
                        local monster=monsters[guid]
                        if monster~=nil and monster.is_face_down~=true then
                            ordered[#ordered+1]=guid
                        end
                    end
                    table.sort(ordered)
                    result.enemyEffectTargetKeys={key}
                    for index=1,math.min(#ordered,spec.maxTargets) do
                        local targetGUID=ordered[index]
                        combatEffectAdd(enemyEffects,targetGUID,card.guid,spec,key)
                        result.links[#result.links+1]=targetGUID
                        if result.enemyGUID==nil then
                            result.enemyGUID=targetGUID
                            result.enemyEffectTargetGUIDs={[key]=targetGUID}
                        end
                        result.status="purple"
                    end
                elseif spec.multiTargetMove then
                    -- Right-click target to add further enemies; cost is settled
                    -- after all Move-producing cards/Units/Skills have been read.
                    result.enemyEffectTargetKeys={key}
                    local targets=attackAssignmentsTargetGUIDs(key)
                    local primary=combatEffectChosenEnemy(key,footprints[card.guid],
                        monsters,combatEffectTargetEligible(spec))
                    if next(targets)==nil and primary~=nil then targets[primary.guid]=true end
                    local ordered={}
                    for guid in pairs(targets) do
                        local monster=monsters[guid]
                        if monster~=nil and monster.is_face_down~=true then
                            ordered[#ordered+1]=guid
                        end
                    end
                    local first=combatAssignmentState.targets[key]
                        or (primary~=nil and primary.guid or nil)
                    table.sort(ordered,function(a,b)
                        if a==first then return true end
                        if b==first then return false end
                        return a<b
                    end)
                    if #ordered>0 then
                        pendingWingsNight[#pendingWingsNight+1]={source=card.guid,targets=ordered}
                        result.enemyEffectTargetGUIDs={[key]=ordered[1]}
                        result.enemyGUID=ordered[1]
                        for _,guid in ipairs(ordered) do result.links[#result.links+1]=guid end
                        result.status="purple"
                    end
                else
                    local target=combatEffectChosenEnemy(key,footprints[card.guid],
                        monsters,combatEffectTargetEligible(spec))
                    if target~=nil then
                        local targetGUID=target.guid
                        for _=1,(result.repeatCount or 1) do
                            if spec.all then
                                for guid,monster in pairs(monsters) do
                                    if monster.is_face_down~=true then
                                        combatEffectAdd(enemyEffects,guid,card.guid,spec,key)
                                    end
                                end
                            else
                                combatEffectAdd(enemyEffects,targetGUID,card.guid,spec,key)
                                if spec.othersArmourReduce~=nil then
                                    for guid,monster in pairs(monsters) do
                                        if guid~=targetGUID and monster~=nil and monster.is_face_down~=true then
                                            combatEffectAdd(enemyEffects,guid,card.guid,
                                                {armourReduce=spec.othersArmourReduce,all=true,fireSpell=spec.fireSpell})
                                        end
                                    end
                                end
                            end
                        end
                        result.enemyGUID=targetGUID
                        result.links[#result.links+1]=targetGUID
                        result.status="purple"
                        if not spec.all then
                            result.enemyEffectTargetKeys={key}
                            result.enemyEffectTargetGUIDs={[key]=targetGUID}
                        end
                    end
                end
                end -- Dodge and Weave separate effect targets
            end
        end
        if rule~=nil and rule.woundBonus~=nil and result.resources~=nil and unitState~=nil then
            result.unitSources={}
            for _,unit in ipairs(unitState.units) do
                if unit.woundCount>0 then
                    result.unitSources[#result.unitSources+1]=unit.guid
                end
            end
        end
        local manaLink=manaByCard[card.guid]
        if manaLink~=nil then
            result.status="purple"
            result.links[#result.links+1]=manaLink.skillGUID
            result.convertedMana=manaLink.converted
        end
        -- The recruitment-cost change is not performed by the offer script:
        -- the player chooses when to use these two extra Influence points.
        local recruitBonus=resourceCardsRecruitInfluenceBonus(card.guid,rule,result)
        if recruitBonus>0 then
            local adjusted={}
            for key,value in pairs(result.resources) do adjusted[key]=value end
            adjusted.influence=(tonumber(adjusted.influence) or 0)+recruitBonus
            result.resources=adjusted
        end
        result.choices=choices -- Also authoritative for payment-restricted click validation.
        showChoiceButtons(card,choices,result.powered,inventorySpec,inventorySets,result.resources,
            repeatByTarget[card.guid])
        if cardData~=nil and cardData.resourceKey=="spellCure" then
            combatConfig.refreshCureDrawButton(card,
                result.complete==true and result.powered~=true
                and resourceCardsDetailsOpen())
        end
        -- Expose a separate Armour-reduction source. It is independent of the
        -- card's Ranged Attack target and becomes effective only after a kill.
        if result.explosiveBolt~=nil and combatCalcOn then
            result.enemyEffectTargetKeys={card.guid.."#explosiveAttack"}
        end
        -- Stage terrain effects until linked conversions have resolved.
        -- Amulets grant no numeric Move and retain their independent effects.
        if rule~=nil and cardPosture(card)=="upright" and result.resources~=nil
            and (type(result.resources.move)=="number"
                or (cardData~=nil and cardData.cardType=="Artifact")) then
            result.independentTerrain=cardData~=nil and cardData.cardType=="Artifact"
                and (tonumber(result.resources.move) or 0)<=0
            for _=1,(result.repeatCount or 1) do
                for _,effect in ipairs(cardTerrainEffects(rule,result.powered) or {}) do
                    if terrainEffectActive(effect) then
                        result.pendingTerrainModifiers=result.pendingTerrainModifiers or {}
                        result.pendingTerrainModifiers[#result.pendingTerrainModifiers+1]=effect
                    end
                end
            end
            local extraManaGUID=extraTerrainManaByCard[card.guid]
            if extraManaGUID~=nil and rule.extraTerrainMana~=nil then
                result.pendingTerrainModifiers=result.pendingTerrainModifiers or {}
                result.pendingTerrainModifiers[#result.pendingTerrainModifiers+1]=rule.extraTerrainMana.effect
                result.links[#result.links+1]=extraManaGUID
                result.status="purple"
            end
        end
        -- Persistent movement rules are non-numeric abilities: collect them
        -- from the actual played card, independently of Resource Tracker
        -- resource values/completeness. A powered side must never inherit the
        -- unpowered side's movement rules.
        if rule~=nil and rule.movementEffects~=nil and cardPosture(card)=="upright"
            and (card.is_face_down~=true or result.repeatLink~=nil)
            and (cardData==nil or cardData.cardType~="Spell"
                or spellCastingPaid[card.guid]==true)
            and (discarded[card.guid]==nil or repeatByTarget[card.guid]~=nil) then
            local effect=result.powered and rule.movementEffects.powered
                or (not result.powered and rule.movementEffects.normal or nil)
            if effect~=nil then
                if effect.jumpTwoSpaces==true then movementEffects.jumpTwoSpaces=true end
                if effect.ignoreRampagers==true then movementEffects.ignoreRampagers=true end
                if effect.windFlightMax~=nil then
                    movementEffects.windFlightMax=math.max(movementEffects.windFlightMax,effect.windFlightMax)
                end
            end
        end
        if rule~=nil and result.complete and result.resources~=nil
            and cardPosture(card)=="upright"
            and (card.is_face_down~=true or result.repeatLink~=nil) then
            if rule.oneSpaceDiscount~=nil and not result.powered then
                -- Basic Druidic Paths discounts a single entered space per
                -- route, never every space of one terrain type.
                result.pendingSingleSpaceDiscount=rule.oneSpaceDiscount.amount or 1
            elseif rule.selectedTerrainDiscount~=nil and result.powered then
                local selection=gStates.startingCardSelections
                    and gStates.startingCardSelections[card.guid] or nil
                local modifier=selection~=nil
                    and combatConfig.druidicTerrainEffects[selection.terrain] or nil
                if modifier~=nil then
                    for _=1,(result.repeatCount or 1) do
                        result.pendingTerrainModifiers=result.pendingTerrainModifiers or {}
                        result.pendingTerrainModifiers[#result.pendingTerrainModifiers+1]=modifier
                    end
                else
                    -- Only movement-role Druidic Paths needs a terrain choice.
                    result.pendingTerrainChoice=true
                end
            end
        end
        -- Both Demolish (basic) and Underground Attack (strong) bypass the
        -- current assault's site/wall Fortification, never printed Fortified.
        -- Recomputed each scan so lost mana, a changed side or a removed card
        -- cannot leave a stale combat modifier.
        if resourceCardsIgnoreSiteFortification(rule,result,card) then
            ignoreSiteFortifications=true
        end
        -- Conditional combat effects apply only on a paid, upright, actually
        -- played side, never when the card is merely in the zone for display.
        if rule~=nil and result.complete and result.resources~=nil
            and cardPosture(card)=="upright"
            and (card.is_face_down~=true or result.repeatLink~=nil) then
            if rule.unitCombatBoost~=nil then
                local bonus=result.powered and rule.unitCombatBoost.powered
                    or rule.unitCombatBoost.normal
                unitCombatBoost=unitCombatBoost+(bonus or 0)*(result.repeatCount or 1)
                if rule.preventUnitDamage==true then preventUnitDamage=true end
            end
            if rule.poweredUnitResistances==true and result.powered then
                allUnitResistances=true
            end
            if rule.poweredHeroFirstWound==true and result.powered then
                heroFirstWoundIgnored=true
            end
        end
        -- Fixed components of partially understood cards may be counted; an
        -- unresolved choice never contributes an invented amount.
        addResourceAmounts(result,totals)
        records[card.guid]=result
        current[card.guid]=true
        if result.usesTerrainBlock then usesCurrentHexBlock=true end
        setHighlight(card,result.status,result.powered)
    end
    return usesCurrentHexBlock,usesCurrentHexHealing,ignoreSiteFortifications,
        unitCombatBoost,preventUnitDamage,allUnitResistances,heroFirstWoundIgnored
end

return M

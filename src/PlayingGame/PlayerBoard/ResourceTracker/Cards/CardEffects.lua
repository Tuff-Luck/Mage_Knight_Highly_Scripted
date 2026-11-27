-- Evaluate played card effects and sideways resources using the coordinator's
-- existing choice, terrain, payment and combat helpers. No scanning, UI or
-- lifecycle ownership is transferred here; game data is read live.
local highlightPolicy=require("PlayingGame.PlayerBoard.ResourceTracker.Core.HighlightPolicy")
return function(deps)
    local trackerPrivate=deps.trackerPrivate
    local combatConfig=deps.combatConfig
    local chosenEffect=deps.chosenEffect
    local cardPosture=deps.cardPosture
    local cardCanPlaySideways=deps.cardCanPlaySideways
    local sideChoices=deps.sideChoices
    local currentLandBlockValue=deps.currentLandBlockValue
    local resourceCardsUsesDayMana=deps.resourceCardsUsesDayMana
    local applyLinkedResourceBonus=deps.applyLinkedResourceBonus
    local effectHasTrackedResource=deps.effectHasTrackedResource
    local cardTerrainEffects=deps.cardTerrainEffects
    local terrainEffectActive=deps.terrainEffectActive
    local choiceCategory=deps.choiceCategory
    local resourceCardsMoveRole=deps.resourceCardsMoveRole

    -- One sideways calculator for ordinary Actions and Skill-linked exceptions.
    -- A linked Skill changes the value, not the player's chosen resource.
    local function calculateSideways(card,known,skillLink)
        local choice=chosenEffect(card.guid,false,trackerPrivate.sidewaysChoices,true)
        local resources=nil
        if choice~=nil then
            resources={}
            for category,value in pairs(choice) do
                resources[category]=value*(skillLink~=nil and skillLink.sidewaysValue or 1)
            end
        end
        local linked=skillLink~=nil
        local linkedObjects={}
        if linked then
            linkedObjects[1]=skillLink.skillGUID
            if skillLink.manaGUID~=nil then linkedObjects[2]=skillLink.manaGUID end
        end
        return {guid=card.guid,known=known,complete=choice~=nil,powered=linked,
            links=linkedObjects,
            linkedSkill=linked and skillLink.skillGUID or nil,
            status=linked and "purple" or (choice~=nil and "green" or "yellow"),
            resources=resources}
    end

    local function calculateCard(card,manaPowered,linkedBoost,linked,discardTarget,hasDiscard,skillLink,linkedChoices,repeatLink,discardBonus,woundCount,enemyIconBonus,spellCastPaid)
        local data=gameCards[card.guid]
        local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
        local known=data~=nil
        -- A half Banner is an attached Unit accessory, NOT a played Artifact.
        -- In particular Banner of Command must not award its Break Fame +2 or
        -- its full-card Influence 4 when the Command source is flipped/spent.
        local attachedResult=trackerPrivate.bannerAttachedCardResult(card.guid)
        if attachedResult~=nil then return attachedResult end
        local tracked=data==nil or data.resourceTracked~=false
        local powered=manaPowered or linkedBoost~=nil
        if repeatLink~=nil then powered=repeatLink.powered end
        local posture=cardPosture(card)
        -- A non-resource Action is neutral upright, but still gives the standard
        -- selectable +1 when played sideways like any other non-Wound Action.
        if data~=nil and data.resourceAlwaysNeutral==true and posture~="sideways" then
            return {guid=card.guid,known=true,complete=true,powered=powered,
                links=linked,status=#linked>0 and "purple" or "blue",resources=nil,
                repeatCount=repeatLink~=nil and repeatLink.count or nil,
                repeatLink=repeatLink}
        end
        -- Artifacts use the saved Break decision; face-down Actions stay
        -- inert unless they are the Action selected by Maximal Effect.
        local artifactPlayed=known and data.cardType=="Artifact" and rule~=nil
            and rule.artifactMode==true
        local faceUp=(card.is_face_down~=true or repeatLink~=nil or artifactPlayed)
            and posture=="upright"
        -- Any non-Wound card played at 90 degrees has one generic resource,
        -- irrespective of its printed card effect. It requires an explicit choice.
        if posture=="sideways" and cardCanPlaySideways(card) then
            return calculateSideways(card,known,skillLink)
        end
        local sideTracked=tracked and not (not powered and rule~=nil and rule.normalTrackerNeutral==true)
        local choices=linkedChoices or sideChoices(rule,powered)
        local chosen=chosenEffect(card.guid,powered,choices)
        local usesTerrainBlock=chosen~=nil and chosen.terrainBlock==true
        if usesTerrainBlock then
            local value=currentLandBlockValue()
            if value~=nil then
                chosen=resourceCardsUsesDayMana() and {blockFire=value} or {blockIce=value}
            else
                -- Terrain not yet determinable. Preserve the B selection, but
                -- do not invent a Block amount; show yellow until the next scan.
                chosen=nil
            end
        end
        local choicePending=choices~=nil and #choices>1 and chosen==nil
        local statePartial=rule~=nil and ((powered and rule.poweredPartial==true)
            or (not powered and rule.normalPartial==true)) and chosen==nil
        local base=chosen or (rule~=nil and (powered and rule.powered or rule.normal) or nil)
        if base~=nil and rule~=nil and rule.blockedEnemyAttackBonus~=nil then
            local active=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
            local count=active~=nil and (combatConfig.blockedEnemyCounts[active.seatPos] or 0) or 0
            local perEnemy=powered and rule.blockedEnemyAttackBonus.powered
                or rule.blockedEnemyAttackBonus.normal
            local adjusted={}
            for key,value in pairs(base) do adjusted[key]=value end
            adjusted.attack=(adjusted.attack or 0)+count*(perEnemy or 0)
            base=adjusted
        end
        if base~=nil and rule~=nil and rule.woundBonus~=nil and woundCount~=nil then
            local perWound=powered and rule.woundBonus.powered or rule.woundBonus.normal
            base={influence=(base.influence or 0)+woundCount*perWound}
        end
        if powered and base~=nil and rule~=nil and rule.enemyIconBlock
            and enemyIconBonus~=nil then
            base={blockIce=(base.blockIce or 0)+enemyIconBonus}
        end
        -- A discard is an actual cost of Improvisation, even when its strong side
        -- came free from Concentration/Will Focus.
        -- Spells on the table may be discarded or merely displayed. Their printed
        -- effect is played only after a linked mana matches the Spell's own colour
        -- (or Daytime Gold). Black alone can indicate a strong side, not a cast.
        local costPaid=(data==nil or data.cardType~="Spell" or spellCastPaid==true)
            and (rule==nil or rule.requiredLink==nil or hasDiscard==true
                or (powered and rule.strongNoDiscard==true))
            and (rule==nil or not rule.artifactMode or rule.discardBoost==nil
                or powered or discardBonus~=nil)
        local canApply=not discardTarget or repeatLink~=nil
        local effects=sideTracked and faceUp and costPaid and canApply
            and applyLinkedResourceBonus(base,linkedBoost) or nil
        local invalidComposite=repeatLink~=nil and not combatConfig.compositePhasesMatch(
            card.guid,powered,choices,repeatLink)
        if invalidComposite then
            canApply=false
            effects=nil
        end
        if effects~=nil and repeatLink~=nil then
            -- Repeated choices are independent. A copied Ritual Attack can use
            -- differently coloured discarded cards on its separate applications.
            -- Numeric resources join the SAME composite effect / enemy target.
            local repeated={}
            if repeatLink.options~=nil or (choices~=nil and #choices>1) then
                for index=1,repeatLink.count do
                    local options=repeatLink.options~=nil and repeatLink.options[index] or choices
                    local single=combatConfig.repeatChoiceFor(card.guid,powered,options,index)
                    if single~=nil then
                        for category,value in pairs(single) do
                            if trackerPrivate.totalsKeys[category] and type(value)=="number" then
                                repeated[category]=(repeated[category] or 0)+value
                            end
                        end
                    end
                end
            else
                for category,value in pairs(effects) do
                    repeated[category]=(trackerPrivate.totalsKeys[category] and type(value)=="number")
                        and value*repeatLink.count or value
                end
            end
            effects=repeated
        end
        -- Each Maximal Effect application chooses its own Stout Resolve resource
        -- and pays its own discarded cards. A single pooled bonus applied to every
        -- resource family would create points when uses select different resources.
        if effects~=nil and discardBonus~=nil then
            local adjusted={}
            for category,value in pairs(effects) do adjusted[category]=value end
            if type(discardBonus)=="table" and repeatLink~=nil then
                for index=1,repeatLink.count do
                    local amount=discardBonus[index] or 0
                    if amount>0 then
                        local options=repeatLink.options~=nil and repeatLink.options[index] or choices
                        local selected=combatConfig.repeatChoiceFor(card.guid,powered,options,index)
                        if selected~=nil then
                            for category,value in pairs(selected) do
                                if trackerPrivate.totalsKeys[category] and type(value)=="number" then
                                    adjusted[category]=(adjusted[category] or 0)+amount
                                    break
                                end
                            end
                        end
                    end
                end
            elseif type(discardBonus)=="number" and discardBonus>0 then
                for category,value in pairs(effects) do
                    if trackerPrivate.totalsKeys[category] and type(value)=="number" then
                        adjusted[category]=value+discardBonus
                    end
                end
            end
            effects=adjusted
        end
        -- Refreshing Walk may be played for Move during combat, but its Heal
        -- is unavailable in that role. Apply after linked bonuses/repeats and
        -- never mutate the shared printed definition or suppress sideways play.
        if rule~=nil and rule.combatMoveSuppressHealing==true and effects~=nil
            and (tonumber(effects.move) or 0)>0
            and resourceCardsMoveRole(card.guid,true)=="combat" then
            local adjusted={}
            for category,value in pairs(effects) do
                if category~="healing" then adjusted[category]=value end
            end
            effects=adjusted
        end
        -- A card's other unimplemented options do not make its currently selected
        -- *known* resource effect uncertain. Keep the first option as the fast,
        -- green default; only a genuinely unresolved selected effect stays yellow.
        local knownSelectedOption=chosen~=nil and effectHasTrackedResource(chosen)
        local complete=sideTracked and base~=nil and not choicePending and not statePartial
            and not invalidComposite
            and (rule==nil or rule.partial~=true or knownSelectedOption)
            and (rule==nil or rule.woundBonus==nil or woundCount~=nil)
            and (rule==nil or rule.enemyIconBlock~=true or not powered
                or enemyIconBonus~=nil)
            and faceUp and costPaid and canApply
        local choiceIsUntracked=chosen~=nil and not effectHasTrackedResource(chosen)
        -- Recognised movement rules change the calculator even without supplying
        -- numeric Move. Show green when the paid, selected side has such an effect.
        -- For example, Space Bending is green, but Time Bending stays neutral
        -- until its distinct stronger-side effect is supported.
        local scriptedMovement=rule~=nil and rule.movementEffects~=nil
            and (powered and rule.movementEffects.powered
                or (not powered and rule.movementEffects.normal))
        local scriptedTerrain=false
        for _,effect in ipairs(cardTerrainEffects(rule,powered) or {}) do
            if terrainEffectActive(effect) then scriptedTerrain=true break end
        end
        local recognized=known and sideTracked and posture~="discard"
            and not (choiceIsUntracked and costPaid and not scriptedMovement and not scriptedTerrain)
        local status=highlightPolicy.certainty(recognized,complete)
        -- The printed crystal gain on Savage Harvesting is deliberately manual.
        -- Move is still counted, but a green "fully understood" highlight would lie.
        -- Golden Grail's basic Fame is complete once both Heal points are confirmed;
        -- its stronger-side card draws still require manual resolution.
        if rule~=nil and rule.manualSecondary~=nil and status=="green"
            and not (rule.grailFamePerHealing~=nil and not powered
                and gStates~=nil and gStates.artifactGrailHealingUsed~=nil
                and (tonumber(gStates.artifactGrailHealingUsed[card.guid]) or 0)>=2) then
            status="yellow"
        end
        -- Linking information is more valuable than the underlying certainty colour.
        if #linked>0 then status="purple" end
        local fameRepSide=rule~=nil and rule.fameRep~=nil and faceUp and costPaid and canApply
            and (powered and rule.fameRep.powered or not powered and rule.fameRep.normal) or nil
        if fameRepSide~=nil and repeatLink~=nil then
            local multiplied={}
            for key,value in pairs(fameRepSide) do
                multiplied[key]=type(value)=="number" and value*repeatLink.count or value
            end
            fameRepSide=multiplied
        end
        -- Heroic Tale credits all recruitment events this turn, even if the
        -- recruited Unit was subsequently disbanded. Only the upright paid
        -- card contributes; returning it or changing its side is reversible.
        if complete and rule~=nil and rule.recruitmentReward~=nil
            and unitRecruitmentCount~=nil and unitRecruitmentReward~=nil then
            local active=turnOrder~=nil and gStates~=nil and turnOrder[gStates.turnNumber] or nil
            if active~=nil then
                local earned=unitRecruitmentReward(rule.recruitmentReward,powered,
                    unitRecruitmentCount(active.seatPos),repeatLink~=nil and repeatLink.count or 1)
                if earned~=nil then
                    fameRepSide={fame=(fameRepSide~=nil and fameRepSide.fame or 0)+earned.fame,
                        rep=(fameRepSide~=nil and fameRepSide.rep or 0)+earned.rep}
                end
            end
        end
        -- Fame/Reputation earned only when the calculator shows this source's group defeated.
        local defeatSide=rule~=nil and rule.defeatFameRep~=nil and faceUp and costPaid and canApply
            and (powered and rule.defeatFameRep.powered or not powered and rule.defeatFameRep.normal) or nil
        if defeatSide~=nil then
            local repeats=repeatLink~=nil and repeatLink.count or 1
            if defeatSide.choice~=nil then
                if repeatLink~=nil then
                    repeats=0
                    for index=1,repeatLink.count do
                        local options=repeatLink.options~=nil and repeatLink.options[index] or choices
                        local selected=combatConfig.repeatChoiceFor(card.guid,powered,options,index)
                        if selected~=nil and choiceCategory(selected)==defeatSide.choice then
                            repeats=repeats+1
                        end
                    end
                elseif chosen==nil or choiceCategory(chosen)~=defeatSide.choice then
                    repeats=0
                end
            end
            if repeats==0 then defeatSide=nil
            elseif repeats>1 then
                local scaled={}
                for key,value in pairs(defeatSide) do
                    scaled[key]=type(value)=="number" and value*repeats or value
                end
                defeatSide=scaled
            end
        end
        -- Each copied automatic application can earn its own printed bonus.
        -- Manual choices already include their bonus and must not get it twice.
        local woundAttack
        if complete and rule~=nil and rule.combatWoundAttack~=nil then
            local copies=0
            if repeatLink~=nil then
                for index=1,repeatLink.count do
                    local options=repeatLink.options~=nil and repeatLink.options[index] or choices
                    local option=combatConfig.repeatChoiceFor(card.guid,powered,options,index)
                    if option~=nil and option.key=="autoWounds" then copies=copies+1 end
                end
            elseif chosen~=nil and chosen.key=="autoWounds" then copies=1 end
            if copies>0 then
                local spec=rule.combatWoundAttack
                woundAttack={maxWounds=powered and spec.poweredMax or spec.normalMax,
                    perWound=spec.perWound,copies=copies}
            end
        end
        -- Preserve the physical source type for phase rules (Knockout and
        -- Paralysis invalidate only non-Wound hand-card Attacks, not Units/Skills).
        return {guid=card.guid,kind="card",known=known,complete=complete,powered=powered,fameRep=fameRepSide,
            conditionalFireAttack=complete and not powered and chosen~=nil
                and chosen.conditionalFireAttack or nil,
            flameWave=complete and powered and rule~=nil and rule.poweredEnemyBonus~=nil,
            explosiveBolt=complete and powered and rule~=nil and rule.defeatArmourReduce or nil,
            dodgeConditional=complete and rule~=nil and rule.conditionalAttackNoWounds==true,
            combatWoundAttack=woundAttack,
            combatConversion=complete and rule~=nil and rule.combatConversion or nil,
            defeatFameRep=defeatSide,splitTargets=chosen~=nil and chosen.splitTargets or nil,
            repeatBlocks=chosen~=nil and chosen.repeatBlocks or nil,
            swiftDouble=complete and rule~=nil and rule.swiftDouble==true,
            excessBlockArmour=complete and powered and rule~=nil
                and rule.excessBlockArmour==true,
            links=linked,status=status,resources=effects,
            usesTerrainBlock=usesTerrainBlock and faceUp and costPaid and canApply,
            repeatCount=repeatLink~=nil and repeatLink.count or nil,
            compositeAction=linkedBoost~=nil or repeatLink~=nil,
            repeatLink=repeatLink,incompatibleComposite=invalidComposite}
    end

    return {calculateSideways=calculateSideways,calculateCard=calculateCard}
end

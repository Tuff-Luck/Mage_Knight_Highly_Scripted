-- Linked Skill processing after activated Unit records exist: Leadership, Shapeshift, copying basic Actions, enemy effects, cooperative Skills, damage mitigation, Deadly Aim and Mana Overload. Receives live scan data and helpers; final object rendering, state publication and lifecycle remain with CardRecognition.
local M={}
local highlightPolicy=require("PlayingGame.PlayerBoard.ResourceTracker.Core.HighlightPolicy")
local effectRecords=require("PlayingGame.PlayerBoard.ResourceTracker.Combat.EnemyEffectRecords")
local physicalLinks=require("PlayingGame.PlayerBoard.ResourceTracker.Core.PhysicalLinks")
local resourceOps=require("PlayingGame.PlayerBoard.ResourceTracker.Core.ResourceOperations")

function M.process(context)
    local seatPos, skills, cards = context.seatPos, context.skills, context.cards
    local wounds, objects, activations = context.wounds, context.objects, context.activations
    local records, current, totals = context.records, context.current, context.totals
    local manaBySkill, skillLinksBySkill, unitState = context.manaBySkill, context.skillLinksBySkill, context.unitState
    local inventoryCrystalCounts, calculateSkill, addResourceAmounts = context.inventoryCrystalCounts, context.calculateSkill, context.addResourceAmounts
    local setHighlight, chosenEffect, choiceCategory = context.setHighlight, context.chosenEffect, context.choiceCategory
    local overlapArea, footprint, footprints = context.overlapArea, context.footprint, context.footprints
    local cardPosture, showChoiceButtons, skillLinksByTarget = context.cardPosture, context.showChoiceButtons, context.skillLinksByTarget
    local matchingSidewaysMana, trackerPrivate, combatConfig = context.matchingSidewaysMana, context.trackerPrivate, context.combatConfig
    local monsters, combatMonsters, choiceLetters = context.monsters, context.combatMonsters, context.choiceLetters
    local combatEnemyData, combatEnemyPrintedAttacks, combatEffectChosenEnemy = context.combatEnemyData, context.combatEnemyPrintedAttacks, context.combatEffectChosenEnemy
    local combatEffectTargetEligible, enemyEffects, combatAssignmentState = context.combatEffectTargetEligible, context.enemyEffects, context.combatAssignmentState
    local manaObjects, placements, usedMana = context.manaObjects, context.placements, context.usedMana
    local manaInsideFootprint, manaColor, powered = context.manaInsideFootprint, context.manaColor, context.powered
    local powerManaColorsByCard, paidManaChoices, currentChoice = context.powerManaColorsByCard, context.paidManaChoices, context.currentChoice
    local effectManaPowerColors, effectManaByCard, matchesCardMana = context.effectManaPowerColors, context.effectManaByCard, context.matchesCardMana
    -- Physical Skill bonuses use the SAME record/totals as the target. Never
    -- add a Skill's printed bonus independently of its activated Unit or card.
    -- Links must create their Skill record before modifying the target; the
    -- final object pass reuses it instead of overwriting or double-counting it.
    local function ensureSkillRecord(skill)
        local record=records[skill.guid]
        if record~=nil then return record end
        local conversion=manaBySkill[skill.guid]
        record=calculateSkill(skill,skillLinksBySkill[skill.guid]
            or (conversion~=nil and conversion.targetGUID or nil),
            unitState,inventoryCrystalCounts)
        addResourceAmounts(record,totals)
        records[skill.guid]=record
        current[skill.guid]=true
        return record
    end
    local function resourceFieldForFamily(resources,family)
        return resourceOps.uniqueField(resources,{[family]=true})
    end
    local function skillTargetLinked(skill,target,field,amount,replaceField,phaseBonus)
        local skillRecord,targetRecord=ensureSkillRecord(skill),records[target.guid]
        if skillRecord==nil or targetRecord==nil or targetRecord.resources==nil then return end
        -- Cards often return the catalog's immutable basic-effect table.
        -- Never mutate a rule entry by adjusting the live played result.
        if phaseBonus~=nil then
            resourceOps.linkAttackBonus(targetRecord,field,phaseBonus)
        elseif replaceField~=nil then
            resourceOps.replace(targetRecord,totals,field,replaceField,amount)
        elseif resourceOps.splitKey(field)=="block" then
            resourceOps.addSingleBlockBonus(targetRecord,totals,field,amount)
        else
            resourceOps.add(targetRecord,totals,field,amount)
        end
        skillRecord.complete=true
        skillRecord.contributes=true
        skillRecord.powered=true
        highlightPolicy.linkedSource(skillRecord)
        skillRecord.links[#skillRecord.links+1]=target.guid
        targetRecord.links[#targetRecord.links+1]=skill.guid
        local redrawTarget=highlightPolicy.linkedTarget(targetRecord)
        setHighlight(skill,skillRecord.status,true)
        -- A linked Unit's activation owns its physical highlight.
        if redrawTarget then
            setHighlight(target,targetRecord.status,targetRecord.powered)
        end
    end
    for _,skill in ipairs(skills) do
        local rule=skillResourceDefinitions[skill.guid]
        if rule~=nil and rule.unitBoost~=nil then
            local choice=chosenEffect(skill.guid,false,rule.choices)
            local family=choice~=nil and choiceCategory(choice) or nil
            if family=="twiceAttack" then family="attack"
            elseif family=="twiceBlock" then family="block" end
            local unitBoost=rule.unitBoost
            if choice~=nil and family~=nil and unitBoost~=nil and unitBoost[family]~=nil then
                local eligible={}
                for unitGUID,activation in pairs(activations) do
                    local unit=objects[unitGUID]
                    local record=records[unitGUID]
                    if activation.seatPos==seatPos and unit~=nil and record~=nil
                        and record.complete==true then
                        local field=resourceFieldForFamily(record.resources,family)
                        local replacement=nil
                        -- The ranged-phase option is Ranged, NOT Siege.
                        -- Printed Siege can still be chosen as ordinary Attack.
                        -- Leadership can convert an activated Unit's printed
                        -- Ranged/Siege Attack to ordinary Attack in the regular
                        -- Attack phase. The alternative is +2 Attack, not +1
                        -- Ranged, and the original phase cannot also keep it.
                        if field==nil and family=="attack" and rule.attackPhaseFallback then
                            local ranged=resourceFieldForFamily(record.resources,"ranged")
                            local siege=resourceFieldForFamily(record.resources,"siege")
                            if ranged~=nil and siege==nil then
                                field=ranged
                                replacement=resourceOps.changeFamily(ranged,"attack")
                            elseif siege~=nil and ranged==nil then
                                field=siege
                                replacement=resourceOps.changeFamily(siege,"attack")
                            end
                        end
                        if field~=nil then
                            eligible[#eligible+1]={unit=unit,field=field,
                                replaceField=replacement,
                                overlap=overlapArea(footprint(skill),footprint(unit))}
                        end
                    end
                end
                -- One matching activated Unit is unambiguous. With several,
                -- require a physical overlap to indicate the target.
                local chosenUnit=physicalLinks.unique(eligible,true)
                if chosenUnit~=nil then
                    local bonus=choice[family] or unitBoost[family]
                    if chosenUnit.replaceField~=nil then
                        local resources=records[chosenUnit.unit.guid].resources
                        bonus=(resources[chosenUnit.field] or 0)+bonus
                    end
                    skillTargetLinked(skill,chosenUnit.unit,chosenUnit.field,
                        bonus,chosenUnit.replaceField)
                end
            end
        end
    end
    -- Braevalar's Shapeshift: one upright Basic Action with exactly one
    -- fixed Move/Attack/Block resource may switch to either other family.
    -- The target is declared by overlapping the Skill with that card.
    for _,skill in ipairs(skills) do
        local rule=skillResourceDefinitions[skill.guid]
        if rule~=nil and rule.shapeshift then
            local candidates={}
            for _,card in ipairs(cards) do
                local data=gameCards[card.guid]
                local record=records[card.guid]
                if data~=nil and data.cardType=="Starting"
                    and card.is_face_down~=true and cardPosture(card)=="upright"
                    and record~=nil and record.complete==true and record.resources~=nil then
                    local field=resourceOps.uniqueField(record.resources,
                        {move=true,attack=true,block=true})
                    if field~=nil then
                        local area=overlapArea(footprints[skill.guid],footprints[card.guid])
                        if area>0 then
                            candidates[#candidates+1]={card=card,field=field,overlap=area}
                        end
                    end
                end
            end
            local best=physicalLinks.unique(candidates)
            local sourceField=best~=nil and best.field or nil
            if best~=nil and sourceField~=nil then
                local sourceFamily,suffix=resourceOps.splitKey(sourceField)
                local choices={}
                for _,family in ipairs({"move","block","attack"}) do
                    if family~=sourceFamily then
                        local field=resourceOps.changeFamily(sourceField,family)
                        local option={key=family,icon=family,[field]=0,
                            shapeshiftTargetGUID=best.card.guid}
                        if family~="move" then
                            if suffix=="Fire" then option.iconOverlay="F"
                            elseif suffix=="Ice" then option.iconOverlay="I"
                            elseif suffix=="ColdFire" then option.iconOverlay="C"
                            elseif suffix=="Psychic" then option.iconOverlay="P" end
                        end
                        choices[#choices+1]=option
                    end
                end
                -- The normal Skill finalization pass renders these options.
                -- Create the record before publishing them, not during linking.
                local result=ensureSkillRecord(skill)
                result.choices=choices
                result.shapeshiftTargetGUID=best.card.guid
                local selected=chosenEffect(skill.guid,false,choices)
                if selected~=nil then
                    local family=choiceCategory(selected)
                    local newField=resourceOps.changeFamily(sourceField,family)
                    local original=resourceOps.fixedShapeshiftAmount(records[best.card.guid],sourceField)
                    skillTargetLinked(skill,best.card,sourceField,original,newField)
                    local target=records[best.card.guid]
                    target.shapeshiftField=newField
                    -- Printed choices stay editable on the card; only its target
                    -- control follows the converted resource. Move role is
                    -- selected on the Skill but stored against this card.
                    showChoiceButtons(best.card,target.choices,target.powered,nil,nil,
                        target.resources,target.repeatLink,newField)
                end
            end
        end
    end
    -- Coral's If It's Not Broken: a sideways card on the Skill copies a
    -- previously played Action's BASIC effect of the same colour. We only
    -- infer a result with one fixed numeric resource and one clear source.
    -- No inferred play order, extra payments, or invented source card.
    for _,skill in ipairs(skills) do
        local skillRule=skillResourceDefinitions[skill.guid]
        if skillRule~=nil and skillRule.copyBasicAction then
            local sidewaysCandidates={}
            for _,card in ipairs(cards) do
                local record=records[card.guid]
                if cardPosture(card)=="sideways" and record~=nil
                    and record.resources~=nil
                    and skillLinksByTarget[card.guid]==nil then
                    local area=overlapArea(footprints[skill.guid],footprints[card.guid])
                    if area>0 then
                        sidewaysCandidates[#sidewaysCandidates+1]={card=card,overlap=area}
                    end
                end
            end
            local sidewaysChoice=physicalLinks.unique(sidewaysCandidates)
            local sideways=sidewaysChoice~=nil and sidewaysChoice.card or nil
            if sideways~=nil then
                local sidewaysData=gameCards[sideways.guid]
                local sideIsArtifact=sidewaysData~=nil
                    and sidewaysData.cardType=="Artifact"
                local candidates={}
                for _,source in ipairs(cards) do
                    local data=gameCards[source.guid]
                    -- Card colours are stored as separate tables; compare their
                    -- entries rather than table identity, including dual colours.
                    local sameColour=false
                    if sidewaysData~=nil then
                        local colours=sidewaysData.color
                        if type(colours)=="string" then
                            sameColour=matchingSidewaysMana(source,colours)
                        elseif type(colours)=="table" then
                            for _,colour in ipairs(colours) do
                                if matchingSidewaysMana(source,colour) then
                                    sameColour=true
                                    break
                                end
                            end
                        end
                    end
                    if source.guid~=sideways.guid and data~=nil
                        and (data.cardType=="Starting" or data.cardType=="Advanced Action")
                        and cardPosture(source)=="upright" and source.is_face_down~=true
                        and (sideIsArtifact or sameColour) then
                        local definition=cardResourceDefinitions[data.resourceKey]
                        if definition~=nil and definition.requiredLink==nil
                            and definition.woundBonus==nil and definition.partial~=true then
                            local base=definition.normalChoices~=nil
                                and chosenEffect(source.guid,false,definition.normalChoices)
                                or definition.normal
                            local srcField,srcValue,count=nil,nil,0
                            for key,value in pairs(base or {}) do
                                if trackerPrivate.totalsKeys[key] and type(value)=="number" and value>0 then
                                    srcField,srcValue,count=key,value,count+1
                                end
                            end
                            if count==1 then
                                candidates[#candidates+1]={source=source,field=srcField,
                                    value=srcValue,overlap=overlapArea(footprints[sideways.guid],
                                        footprints[source.guid])}
                            end
                        end
                    end
                end
                local chosen=physicalLinks.unique(candidates,true)
                if chosen~=nil then
                    local original=records[sideways.guid]
                    local oldField,oldCount=nil,0
                    for key,value in pairs(original.resources) do
                        if trackerPrivate.totalsKeys[key] and type(value)=="number" and value>0 then
                            oldField,oldCount=key,oldCount+1
                        end
                    end
                    if oldCount==1 then
                        skillTargetLinked(skill,sideways,oldField,chosen.value,chosen.field)
                        local origin=records[chosen.source.guid]
                        local skillRecord=records[skill.guid]
                        if origin~=nil and skillRecord~=nil then
                            origin.links[#origin.links+1]=skill.guid
                            skillRecord.links[#skillRecord.links+1]=chosen.source.guid
                            highlightPolicy.linkedSource(origin)
                            setHighlight(chosen.source,origin.status,origin.powered)
                        end
                        -- The copied effect replaces the generic sideways
                        -- choice, but copied Move still needs its M/C selector.
                        original.copiedBasicField=chosen.field
                        original.choices=chosen.field=="move" and {{move=chosen.value}} or nil
                        showChoiceButtons(sideways,original.choices,false,nil,nil,
                            chosen.field=="move" and original.resources or nil)
                    end
                end
            end
        end
    end
    -- Build Know Your Prey's choices from the printed traits and attack slots
    -- of its currently selected target. Never offer site-granted abilities.
    combatConfig.preyChoices=function(enemyGUID)
        local choices={}
        local enemy=enemyGUID~=nil and monsters[enemyGUID] or nil
        local data=enemy~=nil and combatEnemyData(enemyGUID,enemy) or nil
        if data==nil then return {{key="preyNone",icon="other",iconOverlay="?"}} end
        for _,trait in ipairs({"swiftness","brutal","poison","paralyse","assassination",
            "cumbersome","vampiric","fortified","elusive",
            "pResist","fResist","iResist","mResist","defend"}) do
            if data[trait]==true or (trait=="defend" and (tonumber(data.defend) or 0)>0) then
                local key="prey"..trait:sub(1,1):upper()..trait:sub(2)
                choiceLetters[key]="X"
                choices[#choices+1]={key=key,icon="other",iconOverlay="X",
                    tooltip="Know Your Prey: ignore the enemy token's printed "..trait,
                    preySpec={removeTrait=trait}}
            end
        end
        for _,attack in ipairs(combatEnemyPrintedAttacks(data,
            gStates~=nil and gStates.monsterPerks and gStates.monsterPerks[enemyGUID] or nil,
            false,enemyGUID)) do
            local destinations=attack.key=="IF" and {"F","I"}
                or (attack.key=="F" or attack.key=="I") and {"P"} or {}
            for _,to in ipairs(destinations) do
                local key="preyA"..tostring(attack.slot)..to
                choiceLetters[key]="→"
                choices[#choices+1]={key=key,icon="other",iconOverlay=to,
                    tooltip="Know Your Prey: attack "..tostring(attack.slot).." "..attack.key.." → "..to,
                    preySpec={convertAttack={slot=attack.slot,from=attack.key,to=to}}}
            end
        end
        if #choices==0 then
            choices={{key="preyNone",icon="other",iconOverlay="?"}}
        end
        return choices
    end
    -- Skills that act on one enemy use the same nearest-enemy targeting as cards.
    -- This pass precedes the final object pass. Register enemy-effect Skills
    -- now so their chosen effects, targets and arrows survive the next scan.
    for _,skill in ipairs(skills) do
        local rule=skillResourceDefinitions[skill.guid]
        if rule~=nil and rule.enemyEffect~=nil then
            local record=ensureSkillRecord(skill)
            local choice=rule.choices~=nil and chosenEffect(skill.guid,false,rule.choices) or nil
            local spec=combatEffectSpec(rule,false,choice~=nil and choiceCategory(choice) or nil)
            if rule.prey then
                local eligible=function(enemy,guid)
                    local data=combatEnemyData(guid,enemy)
                    local perks=gStates~=nil and gStates.monsterPerks and gStates.monsterPerks[guid] or nil
                    return data~=nil and data.attackOnly~=true and data.arcaneImmunity~=true
                        and (perks==nil or perks.arcaneImmunity~=true)
                end
                local target=combatEffectChosenEnemy(skill.guid,footprints[skill.guid],monsters,eligible)
                local options=combatConfig.preyChoices(target~=nil and target.guid or nil)
                record.choices=options
                effectRecords.register(record,skill.guid)
                local selected=chosenEffect(skill.guid,false,options)
                spec=selected~=nil and selected.preySpec or nil
                if target~=nil and spec~=nil then
                    combatEffectAdd(enemyEffects,target.guid,skill.guid,spec)
                    effectRecords.link(record,skill.guid,target.guid,
                        {primary="replace",purple=true,complete=true})
                else
                    record.status="yellow"
                    record.complete=false
                end
            end
            -- Curse must remain an active effect-only target source while the
            -- player is choosing a new enemy; otherwise a rescan can erase
            -- the purple preview arrow before the target click is applied.
            if spec~=nil and not spec.all then
                effectRecords.register(record,skill.guid)
            end
            if skill.guid=="6a33c1" and spec~=nil and spec.armourReduce~=nil then
                -- Switching from Attack -1 to Armour -1 invalidates a saved
                -- reminder target. Keep legitimate enemy locks untouched.
                local eligible={}
                for guid,enemy in pairs(monsters) do
                    local data=combatEnemyData(guid,enemy)
                    if enemy.is_face_down~=true and data~=nil and data.attackOnly~=true then
                        eligible[guid]=true
                    end
                end
                attackAssignmentsPruneSourceTargets(skill.guid,eligible)
                local locked=combatAssignmentState.targets[skill.guid]
                if locked~=nil and eligible[locked]~=true then
                    combatAssignmentState.targets[skill.guid]=nil
                    combatAssignmentState.explicit[skill.guid]=nil
                end
            end
            local eligible=nil
            if skill.guid=="4ac9f6" or skill.guid=="19daf9" then
                eligible=function(enemy,guid)
                    local data=combatEnemyData(guid,enemy)
                    return data~=nil and data.monsters==nil
                end
            end
            if skill.guid=="6a33c1" and spec~=nil and spec.armourReduce~=nil then
                eligible=function(enemy,guid)
                    local data=combatEnemyData(guid,enemy)
                    return data~=nil and data.attackOnly~=true
                end
            end
            local target=not rule.prey and spec~=nil and combatEffectChosenEnemy(
                skill.guid,footprints[skill.guid],monsters,
                eligible or combatEffectTargetEligible(spec)) or nil
            if spec~=nil and target~=nil then
                combatEffectAdd(enemyEffects,target.guid,skill.guid,spec)
                effectRecords.link(record,not spec.all and skill.guid or nil,target.guid,
                    {primary="replace",purple=true})
            end
        end
    end
    -- The cooperating player's Howl of the Pack use is claimed through the
    -- existing shared-skill lifecycle and persists after its token is returned.
    local pack=gStates~=nil and gStates.wolfhawkPackUse or nil
    if pack~=nil and pack.recipient==gStates.turnNumber
        and pack.round==gStates.currentRound then
        local key="564392"
        local spec={attackReduce=1,armourReduce=1}
        local anchor=getObjectFromGUID(key)
        local fallback=nil
        for _,enemy in pairs(monsters) do fallback=enemy break end
        local area=anchor~=nil and footprint(anchor)
            or fallback~=nil and footprint(fallback) or nil
        local record=records[key] or {guid=key,kind="skill",known=true,
            resources=nil,status="yellow",powered=false,complete=false,links={}}
        effectRecords.register(record,key)
        records[key]=record
        current[key]=true
        if area~=nil then
            local target=combatEffectChosenEnemy(key,area,monsters,
                combatEffectTargetEligible(spec))
            if target~=nil then
                combatEffectAdd(enemyEffects,target.guid,key,spec)
                effectRecords.link(record,key,target.guid,
                    {primary="replace",purple=true,complete=true})
            end
        end
    end
    -- A claimed cooperative Nature's Vengeance remains playable after the
    -- recipient hands the physical Skill back to its owner. Keep its target
    -- source and one enemy reduction through the recipient's turn only.
    local vengeance=gStates~=nil and gStates.braevalarVengeanceUse or nil
    if vengeance~=nil and vengeance.recipient==gStates.turnNumber
        and vengeance.round==gStates.currentRound then
        local key="4ac9f6"
        local spec={attackReduce=1,grantCumbersome=true}
        local anchor=getObjectFromGUID(key)
        local fallback=nil
        for _,enemy in pairs(monsters) do fallback=enemy break end
        local area=anchor~=nil and footprint(anchor)
            or fallback~=nil and footprint(fallback) or nil
        local record=records[key] or {guid=key,kind="skill",known=true,
            resources=nil,status="yellow",powered=false,complete=false,links={}}
        effectRecords.register(record,key)
        records[key]=record
        current[key]=true
        if area~=nil then
            local target=combatEffectChosenEnemy(key,area,monsters,
                function(enemy,guid)
                    local data=combatEnemyData(guid,enemy)
                    return data~=nil and data.monsters==nil
                end)
            if target~=nil then
                combatEffectAdd(enemyEffects,target.guid,key,spec)
                effectRecords.link(record,key,target.guid,
                    {primary="replace",purple=true,complete=true})
            end
        end
    end
    -- Battle Hardened protects the Hero from one selected enemy attack,
    -- rather than reducing the enemy's printed Attack or Block requirement.
    -- Unlike Curse it only activates after the player targets an enemy.
    for _,skill in ipairs(skills) do
        local rule=skillResourceDefinitions[skill.guid]
        if rule~=nil and rule.damageMitigation~=nil then
            local record=ensureSkillRecord(skill)
            -- Advertise the effect-only source even before the first target
            -- click. Otherwise an immediate calculator refresh prunes its new
            -- arrow before the pending Skill scan can apply the mitigation.
            effectRecords.register(record,skill.guid)
            local targetGUID=combatAssignmentState.targets[skill.guid]
            if targetGUID==nil then
                for guid in pairs(attackAssignmentsTargetGUIDs(skill.guid)) do
                    if combatMonsters[guid]~=nil then targetGUID=guid break end
                end
            end
            local target=targetGUID~=nil and combatMonsters[targetGUID] or nil
            if target~=nil and target.is_face_down~=true then
                effectRecords.link(record,skill.guid,targetGUID,
                    {primary="replace",purple=true,complete=true})
            end
        end
    end
    -- Deadly Aim adds to one physically linked card's actual Attack element,
    -- never to Units or a guessed attack phase.
    for _,skill in ipairs(skills) do
        local rule=skillResourceDefinitions[skill.guid]
        if rule~=nil and rule.attackCardBoost then
            local candidates={}
            local targets={}
            for _,card in ipairs(cards) do targets[#targets+1]=card end
            -- Power of Pain / Ritual of Pain can make a sideways Wound a real
            -- Attack source. Deadly Aim may boost it, but never a plain Wound.
            for _,wound in ipairs(wounds) do
                if records[wound.guid]~=nil
                    and records[wound.guid].resources~=nil then
                    targets[#targets+1]=wound
                end
            end
            for _,card in ipairs(targets) do
                if card.is_face_down~=true then
                    local record=records[card.guid]
                    if record~=nil then
                        local chosenField=resourceOps.uniqueField(record.resources,
                            {ranged=true,siege=true,attack=true})
                        local area=overlapArea(footprints[skill.guid],footprints[card.guid])
                        if chosenField~=nil and area>0 then
                            candidates[#candidates+1]={card=card,field=chosenField,overlap=area}
                        end
                    end
                end
            end
            local best=physicalLinks.unique(candidates)
            if best~=nil then
                skillTargetLinked(skill,best.card,best.field,nil,nil,
                    {early={ranged=1,siege=1},late=2})
            end
        end
    end
    -- Tovak's Mana Overload: marker mana on the Skill identifies the color,
    -- but only a DIFFERENT mana which actually powers a Deed card's strong
    -- side may trigger +4. Casting/option-selection payments do not qualify.
    -- Cards granting multiple resources provide separate Skill options.
    for _,skill in ipairs(skills) do
        local rule=skillResourceDefinitions[skill.guid]
        if rule~=nil and rule.manaOverload then
            local colors={}
            local skillArea=footprints[skill.guid]
            for _,mana in ipairs(manaObjects) do
                if placements[mana.guid]=="play" and usedMana[mana.guid]==nil
                    and manaInsideFootprint(mana,skillArea) then
                    local color=manaColor(mana)
                    if color~=nil and color~="Gold" then colors[color]=true end
                end
            end
            local candidates={}
            if next(colors)~=nil then
                for _,card in ipairs(cards) do
                    local data=gameCards[card.guid]
                    local target=records[card.guid]
                    if data~=nil and (data.cardType=="Starting"
                            or data.cardType=="Advanced Action"
                            or data.cardType=="Spell" or data.cardType=="Artifact")
                        and powered[card.guid]==true
                        and card.is_face_down~=true and cardPosture(card)=="upright"
                        and target~=nil and target.resources~=nil
                        and target.repeatLink==nil
                        and (magicTalentOfferCastSide==nil or magicTalentOfferCastSide(seatPos,card.guid)==nil) then
                        local powerColors=powerManaColorsByCard[card.guid] or {}
                        local definition=cardResourceDefinitions[data.resourceKey]
                        if definition~=nil and definition.effectManaChoice~=nil then
                            -- The chosen strong-side effect needs its own
                            -- physical selection payment, and (for Spells)
                            -- an independent casting payment as well.
                            -- calculateCard returns resources but deliberately does
                            -- not persist the UI choices in its record. Rebuild
                            -- the same paid strong-side choices used above.
                            local available=paidManaChoices(card.guid,definition,true,nil)
                            local _,selected=currentChoice(card.guid,true,available)
                            powerColors=effectManaPowerColors(definition.effectManaChoice,
                                effectManaByCard[card.guid],resourceCardsGoldAllowed(),
                                resourceCardsBlackAllowed(),selected)
                        end
                        local matching=false
                        for color in pairs(colors) do
                            if powerColors[color]==true
                                or (powerColors.Gold==true and resourceCardsGoldAllowed()
                                    and matchesCardMana(card,color)) then
                                matching=true
                                break
                            end
                        end
                        if matching then
                            local fields={}
                            for _,family in ipairs({"move","siege","ranged","block","attack","influence"}) do
                                local byFamily={}
                                for field,amount in pairs(target.resources) do
                                    if type(amount)=="number" and amount>0
                                        and (field==family or field:sub(1,#family)==family) then
                                        byFamily[#byFamily+1]=field
                                    end
                                end
                                table.sort(byFamily)
                                for _,field in ipairs(byFamily) do
                                    fields[#fields+1]={field=field,family=family}
                                end
                            end
                            if #fields>0 then
                                candidates[#candidates+1]={card=card,fields=fields,
                                    overlap=overlapArea(skillArea,footprints[card.guid])}
                            end
                        end
                    end
                end
            end
            local chosen=physicalLinks.unique(candidates,true)
            if chosen~=nil then
                local options,fieldByKey={},{}
                for _,fieldInfo in ipairs(chosen.fields) do
                    local field,family=fieldInfo.field,fieldInfo.family
                    local key="overload_"..field
                    local element=field:sub(#family+1)
                    local choice={key=key,icon=family,[field]=0}
                    if element=="Fire" then choice.iconOverlay="F"
                    elseif element=="Ice" then choice.iconOverlay="I"
                    elseif element=="ColdFire" then choice.iconOverlay="C"
                    elseif element=="Psychic" then choice.iconOverlay="P" end
                    choiceLetters[key]=choiceLetters[family] or "O"
                    options[#options+1]=choice
                    fieldByKey[key]=field
                end
                local skillRecord=ensureSkillRecord(skill)
                skillRecord.choices=options
                local _,selected=currentChoice(skill.guid,false,options)
                local field=fieldByKey[selected]
                if field~=nil then skillTargetLinked(skill,chosen.card,field,4) end
            end
        end
    end
end

return M

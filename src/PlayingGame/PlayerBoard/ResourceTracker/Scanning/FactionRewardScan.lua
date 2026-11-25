-- Faction reward choices, enemy effects, and ordered physical element/Attack modifiers; updates current records without changing immutable catalogs.
local M={}
local physicalLinks=require("PlayingGame.PlayerBoard.ResourceTracker.Core.PhysicalLinks")
local resourceOps=require("PlayingGame.PlayerBoard.ResourceTracker.Core.ResourceOperations")

function M.read(context)
    local objects, placements, resourceObjectKind = context.objects, context.placements, context.resourceObjectKind
    local factionRewardForObject, chosenEffect, effectHasTrackedResource = context.factionRewardForObject, context.chosenEffect, context.effectHasTrackedResource
    local movementEffects, heroPsychicBlock, combatEffectChosenEnemy = context.movementEffects, context.heroPsychicBlock, context.combatEffectChosenEnemy
    local footprint, monsters, combatEffectTargetEligible = context.footprint, context.monsters, context.combatEffectTargetEligible
    local enemyEffects, showChoiceButtons, addResourceAmounts = context.enemyEffects, context.showChoiceButtons, context.addResourceAmounts
    local totals, records, current = context.totals, context.records, context.current
    local setHighlight = context.setHighlight
    -- Aura Gauntlet can only choose colours currently showing on physical
    -- Mana Source dice (not spent dice or mirror copies).
    local sourceRewardColors={}
    for _,die in ipairs(gStates.manaSource or {}) do
        local color=({[1]="blue",[2]="white",[3]="green",[4]="red"})[die.color]
        if color~=nil then sourceRewardColors[color]=true end
    end

    -- A Faction Reward is available only after the player actually places it
    -- in the Play Area. Face-down is the alternative interaction exchange:
    -- choose +3 Influence or 1 Fame (Fame itself is not a Tracker column).
    -- Do not infer its effect from being stored face-up in inventory.
    local exchangeChoices={{key="fame"},{influence=3}}
    for guid,token in pairs(objects) do
        if resourceObjectKind(token)=="factionReward" and placements[guid]=="play" then
            local rule=factionRewardForObject(token)
            local flipped=token.is_face_down==true
            local choices=flipped and exchangeChoices or (rule~=nil and rule.choices or nil)
            if not flipped and rule~=nil and rule.name=="Aura Gauntlet" then
                local available={}
                for _,choice in ipairs(choices or {}) do
                    if sourceRewardColors[choice.key] then available[#available+1]=choice end
                end
                choices=available
            end
            local effect=choices~=nil and chosenEffect(guid,flipped,choices) or nil
            if effect==nil and not flipped and rule~=nil then effect=rule.resources end
            -- Boot's printed resources are simultaneous, not alternatives.
            -- Its one UI choice selects the Move role only.
            local splitMoveAttack=false
            if not flipped and rule~=nil and rule.splitMoveAttack==true
                and effect~=nil and (tonumber(effect.move) or 0)>0
                and (tonumber(effect.attack) or 0)>0 then
                splitMoveAttack=true
                choices={{key="move",icon="move",move=effect.move,attack=effect.attack,
                    splitMoveAttack=true}}
            end
            local contributes=effectHasTrackedResource(effect)
            local result={guid=guid,kind="factionReward",known=rule~=nil,
                complete=rule~=nil,resources=effect,choices=choices,
                splitTargets=splitMoveAttack and {"block","attack"} or nil,
                modifier=not flipped and rule~=nil and rule.modifier or nil,
                powered=flipped,links={},contributes=contributes,
                status=contributes and "green" or "blue",
                nameKey=rule~=nil and rule.name or nil}
            if rule~=nil and not flipped and (rule.partial or rule.modifier~=nil) then
                result.status="yellow"
            end
            if not flipped and rule~=nil and rule.movement~=nil
                and rule.movement.ignoreRampagers then
                result.pendingIgnoreRampagers=true
            end
            if not flipped and rule~=nil and rule.heroPsychicBlock==true then
                heroPsychicBlock=true
            end
            if not flipped and rule~=nil and rule.enemyEffect~=nil then
                local target=combatEffectChosenEnemy(guid,footprint(token),monsters,
                    combatEffectTargetEligible(rule.enemyEffect))
                if target~=nil then
                    combatEffectAdd(enemyEffects,target.guid,guid,rule.enemyEffect)
                    result.enemyEffectTargetKeys={guid}
                    result.enemyEffectTargetGUIDs={[guid]=target.guid}
                    result.links[#result.links+1]=target.guid
                    result.status="purple"
                end
            end
            showChoiceButtons(token,choices,flipped,nil,nil,effect)
            addResourceAmounts(result,totals)
            records[guid]=result
            current[guid]=true
            setHighlight(token,result.status,result.powered)
        end
    end
    return heroPsychicBlock
end

function M.modifiers(context)
    local records, objects, footprint = context.records, context.objects, context.footprint
    local cardPosture, overlapArea, attackTransforms = context.cardPosture, context.overlapArea, context.attackTransforms
    local addResourceAmounts, totals, setHighlight = context.addResourceAmounts, context.totals, context.setHighlight
    -- Physical faction reward overlays. Place the token on its target:
    -- gems convert one Action card's Attack/Block element; Ghostly Elixir
    -- changes one melee Attack to Ranged; Vial of Toxin boosts one physical
    -- Attack source. Nothing is awarded for a missing or ambiguous target.
    local function rewardConversion(mode,category)
        if mode=="makeRanged" then
            local family,suffix=resourceOps.splitKey(category)
            if family=="attack" and suffix~="Psychic" then
                return resourceOps.changeFamily(category,"ranged")
            end
        elseif mode=="addFire" then
            return resourceOps.addElement(category,"Fire")
        elseif mode=="addIce" then
            return resourceOps.addElement(category,"Ice")
        end
        return nil
    end
    -- Resolve element conversions before the toxin. Toxin's extra physical
    -- Attack must vanish if a Gem subsequently makes that attack elemental.
    for _,mode in ipairs({"makeRanged","addFire","addIce","physicalBoost"}) do
        for rewardGUID,reward in pairs(records) do
            local token=reward.kind=="factionReward" and reward.modifier==mode
                and objects[rewardGUID] or nil
            if token~=nil then
                local candidates={}
                local tokenArea=footprint(token)
                for sourceGUID,candidate in pairs(objects) do
                    local data=gameCards[sourceGUID]
                    local action=data~=nil and (data.cardType=="Starting"
                        or data.cardType=="Advanced Action")
                    local unit=mode=="physicalBoost" and data~=nil
                        and (data.cardType=="Regular Unit" or data.cardType=="Elite Unit")
                    local record=records[sourceGUID]
                    if sourceGUID~=rewardGUID and (action or unit) and record~=nil
                        and record.contributes==true and record.resources~=nil
                        and (unit or (candidate.is_face_down~=true
                            and cardPosture(candidate)=="upright")) then
                        local overlap=overlapArea(tokenArea,footprint(candidate))
                        if overlap>0 then
                            local possible={}
                            for field,amount in pairs(record.resources) do
                                if type(amount)=="number" and amount>0 then
                                    local to=rewardConversion(mode,field)
                                    if mode=="physicalBoost" then
                                        -- Only the source's current physical
                                        -- category qualifies for Vial of Toxin.
                                        if not attackTransforms.coldFire
                                            and (field=="attack" or field=="ranged"
                                                or field=="siege") then to=field
                                        else to=nil end
                                    end
                                    if to~=nil then
                                        possible[#possible+1]={from=field,to=to}
                                    end
                                end
                            end
                            if #possible==1 then
                                candidates[#candidates+1]={card=candidate,record=record,
                                    selected=possible[1],overlap=overlap}
                            end
                        end
                    end
                end
                local chosen=physicalLinks.unique(candidates)
                if chosen~=nil then
                    local winner,sourceRecord,selected=chosen.card,chosen.record,chosen.selected
                    local from,to=selected.from,selected.to
                    if mode=="physicalBoost" then
                        local effectiveFamily=attackTransforms.siege and "siege" or from
                        local bonus=effectiveFamily=="siege" and 1
                            or (effectiveFamily=="ranged" and 2 or 3)
                        reward.resources={[from]=bonus}
                        addResourceAmounts(reward,totals)
                    else
                        -- Never mutate the declarative global resource data,
                        -- which can be reused by another identical card.
                        if sourceRecord.resources==nil then
                            error("The linked resource source has no resource values.",2)
                        end
                        local amount=sourceRecord.resources[from]
                        if type(amount)~="number" then
                            error("The linked resource source is missing its selected value.",2)
                        end
                        resourceOps.replace(sourceRecord,totals,from,to,amount)
                        reward.contributes=true
                    end
                    if reward.links==nil or sourceRecord.links==nil then
                        error("A linked resource record has no link list.",2)
                    end
                    reward.links[#reward.links+1]=winner.guid
                    sourceRecord.links[#sourceRecord.links+1]=rewardGUID
                    reward.status="purple"
                    sourceRecord.status="purple"
                    setHighlight(token,reward.status,true)
                    setHighlight(winner,sourceRecord.status,sourceRecord.powered)
                end
            end
        end
    end
end

return M

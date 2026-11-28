-- Resolve physical Skill links from the coordinator's current scan candidates.
-- No zone discovery, payment consumption, UI or saved-state writes occur here.
local physicalLinks=require("PlayingGame.PlayerBoard.ResourceTracker.Core.PhysicalLinks")
local payment=require("PlayingGame.PlayerBoard.ResourceTracker.Scanning.ManaPayments")
return function(deps)
    local trackerPrivate=deps.trackerPrivate
    local resourceCardsGoldAllowed=deps.resourceCardsGoldAllowed
    local resourceCardsBlackAllowed=deps.resourceCardsBlackAllowed
    local currentChoice=deps.currentChoice
    local skillChoicesForCurrentTurn=deps.skillChoicesForCurrentTurn
    local manaColor=deps.manaColor
    local resourceObjectKind=deps.resourceObjectKind
    local cardPosture=deps.cardPosture
    local overlapArea=deps.overlapArea
    local manaInsideFootprint=deps.manaInsideFootprint
    local matchesCardMana=deps.matchesCardMana

    local function sidewaysManaAvailable(color)
        return color~=nil and (color~="Gold" or resourceCardsGoldAllowed())
            and (color~="Black" or resourceCardsBlackAllowed())
    end

    local function matchingSidewaysMana(card,color)
        if color=="Gold" or color=="Black" then return false end
        local data=gameCards[card.guid]
        if data==nil or (data.cardType~="Starting" and data.cardType~="Advanced Action"
            and data.cardType~="Spell") then return false end
        if type(data.color)=="string" then return data.color==color end
        if type(data.color)=="table" then
            for _,entry in ipairs(data.color) do if entry==color then return true end end
        end
        return false
    end

    -- Gold acts as a matching basic colour when paying for Universal Power in
    -- Day conditions. Keep this separate from matchingSidewaysMana: that helper
    -- also compares actual printed card colours for If It's Not Broken.
    local function matchingSidewaysPaymentMana(card,color)
        if payment.wildcard(color,resourceCardsGoldAllowed()) then
            for _,basicColor in ipairs({"Red","Blue","Green","White"}) do
                if matchingSidewaysMana(card,basicColor) then return true end
            end
            return false
        end
        return matchingSidewaysMana(card,color)
    end

    local function sidewaysModifierValue(skill,target,descriptor,mana,unitState,paymentColor)
        local value=skill.is_face_down==true and descriptor.faceDownValue
            or descriptor.value or 1
        local cardData=gameCards[target.guid]
        if descriptor.cardTypeValues~=nil and cardData~=nil then
            value=descriptor.cardTypeValues[cardData.cardType] or value
        end
        if descriptor.choiceValues~=nil then
            local rule=skillResourceDefinitions[skill.guid]
            local _,choice=currentChoice(skill.guid,false,skillChoicesForCurrentTurn(rule))
            value=descriptor.choiceValues[choice] or value
        end
        if mana~=nil and descriptor.matchingManaValue~=nil
            and matchingSidewaysPaymentMana(target,paymentColor(mana)) then
            value=descriptor.matchingManaValue
        end
        if descriptor.perEmptyCommandSlot~=nil and unitState~=nil then
            value=value+descriptor.perEmptyCommandSlot*unitState.emptyCommandSlots
        end
        return value
    end

    local function resolveSkillCardLinks(skills,targets,footprints,manaObjects,placements,reservedMana,unitState,paymentColor)
        paymentColor=paymentColor or manaColor
        local byTarget,bySkill,byMana={}, {}, {}
        local candidates={}
        for _,skill in ipairs(skills) do
            local rule=skillResourceDefinitions[skill.guid]
            local spec=rule~=nil and rule.linkedCard or nil
            if spec~=nil and spec.sideways~=nil
                and (spec.requiresCirculation~=true
                    or (gStates.doingTheRounds or {})[skill.guid]~=nil) then
                for _,target in ipairs(targets) do
                    if target.is_face_down~=true
                        and resourceObjectKind(target)==spec.targetKind
                        and (spec.posture==nil or cardPosture(target)==spec.posture) then
                        local size=overlapArea(footprints[skill.guid],footprints[target.guid])
                        if size>0 then
                            candidates[#candidates+1]={skill=skill,target=target,overlap=size,
                                tieKey=skill.guid,secondaryKey=target.guid,rule=spec.sideways}
                        end
                    end
                end
            end
        end
        -- The strongest physical overlap wins when two different Skills touch the
        -- same sideways card; never combine multiple replacement values.
        table.sort(candidates,physicalLinks.precedes)
        for _,candidate in ipairs(candidates) do
            local skill,target,descriptor=candidate.skill,candidate.target,candidate.rule
            if bySkill[skill.guid]==nil and byTarget[target.guid]==nil then
                local mana=nil
                if descriptor.manaRequired then
                    local closest=nil
                    local skillArea,targetArea=footprints[skill.guid],footprints[target.guid]
                    for _,available in ipairs(manaObjects) do
                        if placements[available.guid]=="play" and reservedMana[available.guid]==nil
                            and byMana[available.guid]==nil
                            and sidewaysManaAvailable(paymentColor(available))
                            and (manaInsideFootprint(available,skillArea)
                                or manaInsideFootprint(available,targetArea)) then
                            local p=available.getPosition()
                            local dx,dz=p[1]-targetArea.x,p[3]-targetArea.z
                            local distance=dx*dx+dz*dz
                            if closest==nil or distance<closest then
                                mana,closest=available,distance
                            end
                        end
                    end
                end
                if not descriptor.manaRequired or mana~=nil then
                    byTarget[target.guid]={skillGUID=skill.guid,
                        sidewaysValue=sidewaysModifierValue(skill,target,descriptor,mana,unitState,paymentColor),
                        manaGUID=mana~=nil and mana.guid or nil}
                    bySkill[skill.guid]=target.guid
                    if mana~=nil then
                        byMana[mana.guid]={skillGUID=skill.guid,targetGUID=target.guid}
                    end
                end
            end
        end
        return byTarget,bySkill,byMana
    end

    -- Physical mana transformations are distinct from Action-card boost links.
    -- The Skill selects one mana resting on it, then an overlapping powerable card.
    -- Neither the die nor the crystal is physically changed or double-counted.
    trackerPrivate.oppositeMana={Red="Blue",Blue="Red",Green="White",White="Green",Gold="Black",Black="Gold"}

    local function convertedManaMatchesCard(card,color)
        local data=gameCards[card.guid]
        if data==nil or card.is_face_down==true or cardPosture(card)~="upright" then return false end
        if data.cardType~="Starting" and data.cardType~="Advanced Action"
            and data.cardType~="Spell" and data.cardType~="Artifact" then return false end
        -- Shared card-mana validation also checks Black-at-night and Gold-by-day.
        if color=="Gold" and not resourceCardsGoldAllowed() then return false end
        if color=="Black" and (data.cardType~="Spell" or not resourceCardsBlackAllowed()) then return false end
        return matchesCardMana(card,color)
    end

    local function resolveManaSkillLinks(skills,manaObjects,cards,footprints,placements)
        local byMana,bySkill,byCard={}, {}, {}
        table.sort(manaObjects,function(a,b) return a.guid<b.guid end)
        for _,skill in ipairs(skills) do
            local rule=skillResourceDefinitions[skill.guid]
            local spec=rule~=nil and rule.manaConversion or nil
            if spec~=nil then
                local area=footprints[skill.guid]
                local nearest,distance=nil,nil
                for _,mana in ipairs(manaObjects) do
                    if placements[mana.guid]=="play" and byMana[mana.guid]==nil
                        and manaColor(mana)~=nil and manaInsideFootprint(mana,area) then
                        local p=mana.getPosition()
                        local dx,dz=p[1]-area.x,p[3]-area.z
                        local d=dx*dx+dz*dz
                        if distance==nil or d<distance then nearest,distance=mana,d end
                    end
                end
                if nearest~=nil then
                    local original=manaColor(nearest)
                    local converted=spec.mode=="opposite" and trackerPrivate.oppositeMana[original] or nil
                    local link={skillGUID=skill.guid,manaGUID=nearest.guid,
                        original=original,converted=converted}
                    bySkill[skill.guid]=link
                    byMana[nearest.guid]=link
                    if converted~=nil then
                        local candidates={}
                        for _,card in ipairs(cards) do
                            if byCard[card.guid]==nil and convertedManaMatchesCard(card,converted) then
                                candidates[#candidates+1]={card=card,overlap=overlapArea(area,footprints[card.guid])}
                            end
                        end
                        local best=physicalLinks.unique(candidates)
                        if best~=nil then
                            link.targetGUID=best.card.guid
                            byCard[best.card.guid]=link
                        end
                    end
                end
            end
        end
        return byMana,bySkill,byCard
    end

    return {matchingSidewaysMana=matchingSidewaysMana,
        resolveSkillCardLinks=resolveSkillCardLinks,resolveManaSkillLinks=resolveManaSkillLinks}
end

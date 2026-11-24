-- Resolve Action-card links using the coordinator's current scan candidates.
-- Physical discovery, choice state, marks, cleanup and resource totals stay outside.
return function(deps)
    local overlapArea=deps.overlapArea
    local cardPosture=deps.cardPosture
    local linkedColorChoices=deps.linkedColorChoices
    local canPayDiscard=deps.canPayDiscard
    local resourceCardsArtifactBroken=deps.resourceCardsArtifactBroken

    -- The common pairing engine is used for different reasons:
    -- "stronger" plays one Action card's stronger effect; "discard" consumes one
    -- OTHER unused, non-Wound card as a cost. Neither is inferred from overlap alone.
    local function resolveActionLinks(cards,wounds,footprints,manaPowered,skillLinksByTarget)
        local links,boostBy,boostSource,discarded,hasDiscard={}, {}, {}, {}, {}
        local linkedCardBySource,repeatByTarget,discardBoostBySource={}, {}, {}
        local boostClaimed={}
        for _,card in ipairs(cards) do links[card.guid]={} end
        for _,wound in ipairs(wounds) do links[wound.guid]={} end
        local function connect(source,target)
            links[source.guid][#links[source.guid]+1]=target.guid
            links[target.guid][#links[target.guid]+1]=source.guid
        end
        local function nearestOverlap(source,valid,preference)
            local best,bestArea,bestPriority=nil,0,-1
            local a=footprints[source.guid]
            for _,target in ipairs(cards) do
                if target.guid~=source.guid and valid(target) then
                    local area=overlapArea(a,footprints[target.guid])
                    local priority=((preference=="discard" and cardPosture(target)=="discard")
                        or (preference=="faceDown" and target.is_face_down==true)) and 1 or 0
                    if area>0 and (priority>bestPriority
                        or (priority==bestPriority and (area>bestArea
                            or (area==bestArea and best~=nil and target.guid<best.guid)))) then
                        best,bestArea,bestPriority=target,area,priority
                    end
                end
            end
            return best
        end
        for _,source in ipairs(cards) do
            local data=gameCards[source.guid]
            local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
            local link=rule~=nil and manaPowered[source.guid] and rule.poweredLink or nil
            if link~=nil and link.mode=="stronger" and source.is_face_down~=true
                and cardPosture(source)=="upright" then
                local target=nearestOverlap(source,function(candidate)
                    local other=gameCards[candidate.guid]
                    local otherRule=other~=nil and cardResourceDefinitions[other.resourceKey] or nil
                    return not boostClaimed[candidate.guid] and other~=nil
                        and (other.cardType=="Starting" or other.cardType=="Advanced Action")
                        and (otherRule==nil or otherRule.poweredLink==nil)
                        and candidate.is_face_down~=true and cardPosture(candidate)=="upright"
                end)
                if target~=nil then
                    boostClaimed[target.guid]=true
                    boostBy[target.guid]=link
                    boostSource[target.guid]=source.guid
                    connect(source,target)
                end
            end
        end
        -- Maximal Effect owns its follow-on Action before any of that Action's
        -- additional costs are resolved. Those costs must be paid separately for
        -- *each* repeated use, not reused from the card Maximal Effect throws away.
        for _,source in ipairs(cards) do
            local data=gameCards[source.guid]
            local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
            local requirement=rule~=nil and rule.requiredLink or nil
            if requirement~=nil and requirement.mode=="repeat"
                and discarded[source.guid]==nil and source.is_face_down~=true
                and cardPosture(source)=="upright" then
                local target=nearestOverlap(source,function(candidate)
                    local other=gameCards[candidate.guid]
                    return other~=nil
                        and (other.cardType=="Starting" or other.cardType=="Advanced Action")
                        and discarded[candidate.guid]==nil and not boostClaimed[candidate.guid]
                        and not manaPowered[candidate.guid] and #links[candidate.guid]==0
                        and cardPosture(candidate)=="upright"
                end,"faceDown")
                if target~=nil then
                    discarded[target.guid]=source.guid
                    hasDiscard[source.guid]=true
                    linkedCardBySource[source.guid]=target.guid
                    local strong=manaPowered[source.guid]==true or boostBy[source.guid]~=nil
                    repeatByTarget[target.guid]={powered=strong,sourceGUID=source.guid,
                        count=strong and requirement.poweredCount or requirement.normalCount}
                    connect(source,target)
                end
            end
        end
        -- Ritual Attack is another throwaway effect. Under Maximal Effect it needs
        -- one NEW throwaway Action for each application, with independently chosen
        -- colors (a two-color target can offer two choices for that application).
        for _,source in ipairs(cards) do
            local data=gameCards[source.guid]
            local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
            local requirement=rule~=nil and rule.requiredLink or nil
            local repeated=repeatByTarget[source.guid]
            if requirement~=nil and requirement.mode=="throwAway"
                and (discarded[source.guid]==nil or repeated~=nil)
                and (source.is_face_down~=true or repeated~=nil)
                and cardPosture(source)=="upright" then
                local need=repeated~=nil and repeated.count or 1
                local paid=0
                if repeated~=nil then repeated.options={} end
                for index=1,need do
                    local target=nearestOverlap(source,function(candidate)
                        local other=gameCards[candidate.guid]
                        return other~=nil
                            and (other.cardType=="Starting" or other.cardType=="Advanced Action")
                            and discarded[candidate.guid]==nil and not boostClaimed[candidate.guid]
                            and not manaPowered[candidate.guid] and #links[candidate.guid]==0
                            and cardPosture(candidate)=="upright"
                    end,"faceDown")
                    if target==nil then break end
                    discarded[target.guid]=source.guid
                    if paid==0 then linkedCardBySource[source.guid]=target.guid end
                    paid=paid+1
                    if repeated~=nil then
                        repeated.options[index]=linkedColorChoices(rule,target.guid,repeated.powered)
                    end
                    connect(source,target)
                end
                hasDiscard[source.guid]=paid==need
            end
        end
        -- Improvisation (and other discard-cost cards) must pay once per repeated
        -- use, even when Maximal Effect supplies their advanced side for free.
        for _,source in ipairs(cards) do
            local data=gameCards[source.guid]
            local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
            local repeated=repeatByTarget[source.guid]
            if (discarded[source.guid]==nil or repeated~=nil)
                and rule~=nil and rule.requiredLink~=nil
                and rule.requiredLink.mode=="discard"
                and (source.is_face_down~=true or repeated~=nil)
                and cardPosture(source)=="upright"
                and not (data~=nil and data.cardType=="Artifact"
                    and resourceCardsArtifactBroken(source.guid,source)) then
                local need=repeated~=nil and repeated.count or 1
                local paid=0
                for _=1,need do
                    local target=nearestOverlap(source,function(candidate)
                        local targetData=gameCards[candidate.guid]
                        return not discarded[candidate.guid] and not boostClaimed[candidate.guid]
                            and candidate.guid~=boostSource[source.guid]
                            and not manaPowered[candidate.guid]
                            and #links[candidate.guid]==0
                            and targetData~=nil
                            and (targetData.cardType=="Starting" or targetData.cardType=="Advanced Action"
                                or targetData.cardType=="Spell" or targetData.cardType=="Artifact")
                            and candidate.getGMNotes()~="Wound"
                            and candidate.getGMNotes()~="Quest"
                            and canPayDiscard(candidate)
                    end,"discard")
                    if target==nil then break end
                    discarded[target.guid]=source.guid
                    if paid==0 then linkedCardBySource[source.guid]=target.guid end
                    paid=paid+1
                    connect(source,target)
                end
                hasDiscard[source.guid]=paid==need
            end
        end
        -- Stout Resolve can take multiple discard payments. Only deliberately
        -- tilted, otherwise unused cards qualify; upright cards remain played.
        -- The basic side permits one Wound, the strong side permits any number
        -- of cards but at most one Wound.
        for _,source in ipairs(cards) do
            local data=gameCards[source.guid]
            local rule=data~=nil and cardResourceDefinitions[data.resourceKey] or nil
            local paid=rule~=nil and rule.discardBoost or nil
            local repeated=repeatByTarget[source.guid]
            if paid~=nil and (discarded[source.guid]==nil or repeated~=nil)
                and (source.is_face_down~=true or repeated~=nil)
                and (cardPosture(source)=="upright" or repeated~=nil)
                -- A face-up broken Sword/Bow has no basic discard-payment ability.
                and not (data~=nil and data.cardType=="Artifact"
                    and resourceCardsArtifactBroken(source.guid,source)) then
                local strong=manaPowered[source.guid]==true or boostBy[source.guid]~=nil
                    or (data~=nil and data.cardType=="Artifact"
                        and resourceCardsArtifactBroken(source.guid,source))
                if repeated~=nil then strong=repeated.powered end
                local spec=paid.normal
                if strong then spec=paid.powered end
                if spec~=nil then
                local choices={}
                for _,target in ipairs(cards) do choices[#choices+1]=target end
                for _,target in ipairs(wounds) do choices[#choices+1]=target end
                table.sort(choices,function(a,b)
                    local aa=overlapArea(footprints[source.guid],footprints[a.guid])
                    local bb=overlapArea(footprints[source.guid],footprints[b.guid])
                    if aa==bb then return a.guid<b.guid end
                    return aa>bb
                end)
                local woundPayments,bonus=0,0
                local perUse=repeated~=nil and {} or nil
                local woundUse,cardUse={},1
                for _,target in ipairs(choices) do
                    local isWound=target.getGMNotes()=="Wound"
                    local targetData=gameCards[target.guid]
                    local eligible=isWound or (targetData~=nil
                        and (targetData.cardType=="Starting" or targetData.cardType=="Advanced Action"
                            or targetData.cardType=="Spell" or targetData.cardType=="Artifact"))
                    if target.guid~=source.guid and eligible
                        and (not spec.woundOnly or isWound)
                        -- Maximal Effect repeats independent Stout Resolve payments.
                        and (not isWound or woundPayments<(spec.maxWounds or 0)
                            *(repeated~=nil and repeated.count or 1))
                        and discarded[target.guid]==nil and not boostClaimed[target.guid]
                        and #links[target.guid]==0 and skillLinksByTarget[target.guid]==nil
                        and not manaPowered[target.guid]
                        and target.is_face_down~=true and cardPosture(target)=="discard"
                        and overlapArea(footprints[source.guid],footprints[target.guid])>0 then
                        -- Physical costs are sorted by overlap. Assign Wounds to
                        -- separate applications (at most one per application) and
                        -- cycle other costs between applications. This deterministic
                        -- assignment changes with card placement, never duplicates
                        -- a payment, and follows each application's chosen effect.
                        ---@type integer|nil
                        local useIndex=1
                        if repeated~=nil then
                            if isWound then
                                useIndex=nil
                                for index=1,repeated.count do
                                    if woundUse[index]~=true then useIndex=index break end
                                end
                            else
                                useIndex=cardUse
                                cardUse=cardUse%repeated.count+1
                            end
                        end
                        if useIndex~=nil then
                            discarded[target.guid]=source.guid
                            connect(source,target)
                            if isWound then
                                woundPayments=woundPayments+1
                                woundUse[useIndex]=true
                            end
                            bonus=bonus+spec.perCard
                            if perUse~=nil then
                                perUse[useIndex]=(perUse[useIndex] or 0)+spec.perCard
                            end
                        end
                    end
                end
                if bonus>0 then
                    discardBoostBySource[source.guid]=perUse or bonus
                end
                end
            end
        end
        return links,boostBy,boostSource,discarded,hasDiscard,linkedCardBySource,
            repeatByTarget,discardBoostBySource
    end

    return resolveActionLinks
end

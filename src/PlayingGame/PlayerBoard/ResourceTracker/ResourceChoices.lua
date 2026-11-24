-- Resource choice policy: ranking, printed options and initial selection.
-- The coordinator owns the selection table and may replace it on load/turn reset.
-- Read it through getSelections rather than retaining an obsolete table reference.
return function(trackerPrivate,getSelections,choiceLetters,cardPosture)
    local resourceChoiceOrder={
        move=1,siege=2,ranged=3,block=4,attack=5,influence=6,healing=7,heal=7,fame=8,
        fireBlock=4,fireAttack=5,fireSiege=2,iceSiege=2
    }
    local resourceChoiceFamilies={"move","siege","ranged","block","attack","influence","healing"}
    local function resourceChoiceRank(category,choice)
        local rank=resourceChoiceOrder[category]
        if rank~=nil then return rank end
        -- Choices with non-resource keys (e.g. heal, combat, wound) retain
        -- their unique callback IDs while sorting by what they contribute.
        for i,family in ipairs(resourceChoiceFamilies) do
            for resource,value in pairs(choice) do
                if type(value)=="number" and (resource==family
                    or (family=="healing" and resource=="healing")
                    or (family=="siege" or family=="ranged"
                        or family=="block" or family=="attack")
                        and resource:sub(1,#family)==family) then
                    return i
                end
            end
        end
        return #resourceChoiceFamilies+1
    end
    local function resourceChoiceColumn(category)
        if category=="fireBlock" then return "block" end
        if category=="fireAttack" then return "attack" end
        if category=="fireSiege" or category=="iceSiege" then return "siege" end
        return category
    end
    local function sideChoices(rule,powered)
        if rule==nil then return nil end
        -- Do not use 'powered and poweredChoices or normalChoices': Lua falls back
        -- to normal choices when poweredChoices is nil, overriding a fixed powered
        -- effect (e.g. Rage's Attack 4) with its unpowered Attack/Block 2 options.
        if powered then return rule.poweredChoices end
        return rule.normalChoices
    end

    local function choiceCategory(choice)
        if type(choice)~="table" then return nil end
        -- Two choices may provide the same resource at different values (e.g.
        -- Blood Rage's Attack with/without a Wound). Their explicit key must
        -- identify the button, rather than the first resource field in pairs().
        if type(choice.key)=="string" then return choice.key end
        for category in pairs(choice) do return category end
        return nil
    end

    local function choiceAvailable(choices,category)
        if choices==nil or category==nil then return false end
        for _,effect in ipairs(choices) do
            if choiceCategory(effect)==category then return true end
        end
        return false
    end

    -- Use the first option on each card from the outset. A previously selected
    -- resource is reused on both card sides whenever that side supports it;
    -- otherwise display its first option without overwriting the preference.
    local function currentChoice(guid,powered,choices,sideways)
        if choices==nil or #choices==0 then return nil,nil end
        local stored=getSelections()[guid]
        if stored~=nil then
            -- A separately selected sideways action takes priority while sideways;
            -- upright/strong effects continue to use the printed-action preference.
            local preferred=sideways and stored.sideways or nil
            if not choiceAvailable(choices,preferred) then preferred=stored.effect end
            if choiceAvailable(choices,preferred) then
                for _,effect in ipairs(choices) do
                    if choiceCategory(effect)==preferred then return effect,preferred end
                end
            end
        end
        local first=choices[1]
        return first,choiceCategory(first)
    end

    local function chosenEffect(guid,powered,choices,sideways)
        return currentChoice(guid,powered,choices,sideways)
    end

    -- Guess once for a newly played choice card. Compare the displayed Resource
    -- Tracker family totals (including manual +/-), excluding this card's previous
    -- contribution so it cannot vote for its own old selection.
    local function trackerChoiceScores(guid,seatPos)
        local tracker=gStates~=nil and gStates.resourceTracker or nil
        local previous=resourceCardScanBySeat[seatPos]
        local estimated=previous~=nil and previous.totals or {}
        local record=previous~=nil and previous.cards[guid] or nil
        local own=record~=nil and record.resources or {}
        local scores={}
        for _,family in ipairs(resourceChoiceFamilies) do
            local value=0
            for field,offset in pairs(tracker~=nil and tracker[family] or {}) do
                -- Reputation and conquered-city shields are valid Interaction
                -- Influence on their own, but are not a generated resource type
                -- for guessing which action the player meant to play.
                if family~="influence" or field=="generated" then
                    value=value+offset
                end
            end
            for _,totalKey in pairs(trackerPrivate.resourceTotalsKeyByField[family]) do
                value=value+(estimated[totalKey] or 0)-(own[totalKey] or 0)
            end
            scores[family]=math.max(0,value)
        end
        return scores
    end

    -- First try to match a resource already contributed by an overlapping (or
    -- closely adjacent) played card. Only the first guess uses this spatial hint:
    -- selecting an option manually, lifting cards and using U/Place Under must
    -- never reassign a previously chosen option.
    trackerPrivate.nearbyCardChoice=function(card,choices,seatPos,cards,footprints,records)
        local own=footprints[card.guid]
        if own==nil then return nil end
        local available={}
        for _,choice in ipairs(choices) do
            local category=choiceCategory(choice)
            if category~=nil and choiceLetters[category]~=nil then
                local rank=resourceChoiceRank(category,choice)
                if rank<=#resourceChoiceFamilies and available[rank]==nil then
                    available[rank]=category
                end
            end
        end
        if next(available)==nil then return nil end
        local previous=resourceCardScanBySeat[seatPos]
        local best=nil
        for _,other in ipairs(cards) do
            if other.guid~=card.guid and other.is_face_down~=true
                and cardPosture(other)~="discard" then
                local area=footprints[other.guid]
                if area~=nil then
                    local gapX=math.max(0,math.abs(own.x-area.x)-own.halfX-area.halfX)
                    local gapZ=math.max(0,math.abs(own.z-area.z)-own.halfZ-area.halfZ)
                    -- Allow a narrow gap beside a card, not unrelated cards elsewhere
                    -- on the mat. Actual overlap always takes precedence over a gap.
                    local reach=math.min(own.halfX,area.halfX)*0.5
                    local gap=gapX*gapX+gapZ*gapZ
                    if gap<=reach*reach then
                        local record=records[other.guid]
                            or (previous~=nil and previous.cards[other.guid] or nil)
                        if record~=nil and record.complete==true
                            and type(record.resources)=="table" then
                            local overlapX=math.max(0,
                                math.min(own.x+own.halfX,area.x+area.halfX)
                                -math.max(own.x-own.halfX,area.x-area.halfX))
                            local overlapZ=math.max(0,
                                math.min(own.z+own.halfZ,area.z+area.halfZ)
                                -math.max(own.z-own.halfZ,area.z-area.halfZ))
                            local overlap=overlapX*overlapZ
                            local distance=(own.x-area.x)^2+(own.z-area.z)^2
                            for rank,category in pairs(available) do
                                local amount=0
                                for _,key in pairs(trackerPrivate.resourceTotalsKeyByField[resourceChoiceFamilies[rank]]) do
                                    amount=amount+math.max(0,tonumber(record.resources[key]) or 0)
                                end
                                if amount>0 and (best==nil
                                    or overlap>best.overlap
                                    or (overlap==best.overlap and gap<best.gap)
                                    or (overlap==best.overlap and gap==best.gap
                                        and distance<best.distance)
                                    or (overlap==best.overlap and gap==best.gap
                                        and distance==best.distance and amount>best.amount)
                                    or (overlap==best.overlap and gap==best.gap
                                        and distance==best.distance and amount==best.amount
                                        and (rank<best.rank or (rank==best.rank
                                            and other.guid<best.guid)))) then
                                    best={category=category,overlap=overlap,gap=gap,
                                        distance=distance,amount=amount,rank=rank,guid=other.guid}
                                end
                            end
                        end
                    end
                end
            end
        end
        return best~=nil and best.category or nil
    end

    local function guessInitialCardChoice(card,choices,seatPos,rule,sideways,cards,footprints,records)
        -- A Wound-paid spell must be confirmed by the player, never guessed.
        if rule~=nil and rule.woundConfirmation==true and not sideways then return end
        local selectedResourceByGUID=getSelections()
        if selectedResourceByGUID[card.guid]~=nil or choices==nil or #choices<2
            or card.is_face_down==true then return end
        local nearby=trackerPrivate.nearbyCardChoice(card,choices,seatPos,cards,footprints,records)
        local best,bestValue,bestRank=nearby,nil,nil
        if best==nil then
            local scores=trackerChoiceScores(card.guid,seatPos)
            for _,choice in ipairs(choices) do
                local category=choiceCategory(choice)
                local rank=resourceChoiceRank(category,choice)
                if category~=nil and choiceLetters[category]~=nil
                    and rank<=#resourceChoiceFamilies then
                    local value=scores[resourceChoiceFamilies[rank]]
                    if best==nil or value>bestValue or (value==bestValue and rank<bestRank) then
                        best,bestValue,bestRank=category,value,rank
                    end
                end
            end
        end
        -- Purely untracked choices (draw/other/etc.) retain their printed default.
        if best==nil then return end
        local selected={}
        if sideways and not choiceAvailable(sideChoices(rule,false),best)
            and not choiceAvailable(sideChoices(rule,true),best) then
            selected.sideways=best
        else
            selected.effect=best
        end
        selectedResourceByGUID[card.guid]=selected
    end

    return {
        resourceChoiceFamilies=resourceChoiceFamilies,
        resourceChoiceRank=resourceChoiceRank,
        resourceChoiceColumn=resourceChoiceColumn,
        sideChoices=sideChoices,
        choiceCategory=choiceCategory,
        choiceAvailable=choiceAvailable,
        currentChoice=currentChoice,
        chosenEffect=chosenEffect,
        trackerChoiceScores=trackerChoiceScores,
        guessInitialCardChoice=guessInitialCardChoice
    }
end

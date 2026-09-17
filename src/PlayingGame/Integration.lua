-- Final cross-module gameplay integration.
-- Loaded after the gameplay modules so these wrappers can coordinate setup/runtime helpers
-- without putting the same implementation back into multiple source files.

-- DisplayHelp is provided by PlayingGame.Help because setup, gameplay UI and XML call it across modules.

-- Fury of the Apocalypse Dragon: deploy its scenario manual beside the other rulebooks while
-- the rules bag still exists. The first setupGame call only stores the rewind point; deploy on
-- the rewind-ready pass so rewinding setup restores the pre-setup state cleanly.
local baseSetupGame=setupGame
local function setupGameErrorContext(player,id,rewindReady)
    local playerColor=player~=nil and (player.color or player) or ""
    return "Scenario: "..tostring(gStates~=nil and gStates.gameScenario or "")..
        "\nScenario Ref: "..tostring(gStates~=nil and gStates.scenarioRef or "")..
        "\nPlayers Ref: "..tostring(gStates~=nil and gStates.playersRef or "")..
        "\nPlayer: "..tostring(playerColor)..
        "\nStart ID: "..tostring(id or "")..
        "\nRewind Ready: "..tostring(rewindReady==true)
end
function setupGame(player, mouseButton, id, rewindReady)
    return safeCallback("setupGame",function()
        if mouseButton=="-1" and rewindReady==true and gStates~=nil then
            --Book.setPage expects a CLR Int32. Keep all scenario rule-page values numeric before the
            --delayed rulebook setup callback runs; this also tolerates a value restored as a string.
            local scenario=scenarioList~=nil and scenarioList[gStates.scenarioRef] or nil
            local details=scenario~=nil and scenario.scenarioDetails or nil
            local ruleStates=details~=nil and details.ruleStates or nil
            if type(ruleStates)=="table" then
                for key,page in pairs(ruleStates) do
                    local numeric=tonumber(page)
                    if numeric~=nil then ruleStates[key]=math.floor(numeric) end
                end
            end

            if gStates.gameScenario=="Fury of the Apocalypse Dragon" and getObjectFromGUID("8d7fb9")==nil then
                local ruleBag=getObjectFromGUID("d4a866")
                if ruleBag~=nil then
                    local manual=safeTakeObject("Integration",ruleBag,{guid="8d7fb9",position={41.00,0.96,35.00},rotation={0,180,0},smooth=false})
                    if manual~=nil then
                        --The takeObject return is already the live book. Use that handle instead of waiting
                        --for getObjectFromGUID() registration, then lock only after physics reports it resting.
                        safeWaitFrames("Integration",function()
                            safeWaitCondition("Integration",function()
                                if manual~=nil then manual.lock() end
                            end,function()
                                return manual~=nil and manual.resting==true
                            end)
                        end,5)
                    end
                end
            end
        end
        return baseSetupGame(player,mouseButton,id,rewindReady)
    end,function() return setupGameErrorContext(player,id,rewindReady) end)
end

-- Fury's one-hex Dragon footprint (42b581) is its own object in the Apocalypse Dragon bag.
-- Pull that token directly; do not disturb the normal three-hex Dragon model.
function furyDragonExtractMarker(target)
    if gStates==nil or gStates.gameScenario~="Fury of the Apocalypse Dragon" then return nil end
    local marker=getObjectFromGUID("42b581")
    if marker==nil then
        local bag=getObjectFromGUID(GUID.bag.apocalypseDragon)
        if bag==nil then return nil end
        marker=bag.takeObject({guid="42b581",position=target,rotation={0,180,0},smooth=false})
        if marker==nil then return nil end
    end
    marker.unlock()
    marker.setRotation({0,180,0})
    marker.setPosition(target)
    return marker
end

-- Destroyed Site markers must finish their scripted move and then actually fall onto the terrain
-- before being locked. In particular, Apocalypse is Here previously locked a newly drawn marker
-- immediately after destroySite(), leaving it suspended at its spawn Y position.
function lockDestroyedSiteWhenSettled(token)
    if token==nil then return end
    local guid=token.guid
    token.unlock()
    safeWaitFrames("Integration",function()
        safeWaitCondition("Integration",function()
            local current=getObjectFromGUID(guid)
            if current~=nil then current.lock() end
        end,function()
            local current=getObjectFromGUID(guid)
            if current==nil then return true end
            local pos=current.getPosition()
            local velocity=current.getVelocity()
            local vy=velocity~=nil and (velocity.y or velocity[2]) or 0
            return current.resting==true and math.abs(vy)<0.01 and pos[2]<1.50
        end,6)
    end,1)
end

local baseApocalypseIsHereResolveHorsemanTarget=apocalypseIsHereResolveHorsemanTarget
function apocalypseIsHereResolveHorsemanTarget(name,targetHex)
    local before={}
    for guid in pairs((gStates~=nil and gStates.destroyedSites) or {}) do before[guid]=true end
    local result=baseApocalypseIsHereResolveHorsemanTarget(name,targetHex)
    for guid in pairs((gStates~=nil and gStates.destroyedSites) or {}) do
        if before[guid]~=true then
            local token=getObjectFromGUID(guid)
            if token~=nil then lockDestroyedSiteWhenSettled(token) end
        end
    end
    return result
end

-- The stats/bug sheet should receive an explicit FALSE for Apocalypse Quest just like the other
-- setup toggles. Older/default states can leave this field nil until the option is touched.
local baseSendDataRequest=SendDataRequest
function SendDataRequest(...)
    if gStates~=nil then gStates.apocalypseQuestCards=(gStates.apocalypseQuestCards==true) end
    return baseSendDataRequest(...)
end

-- Starting-hand setup already waits for the physical Deed Decks. Keep a final idempotent retry as
-- protection against a TTS zone/resting event being missed during the large setup burst: drawUpTo()
-- counts cards already in hand, so a successful first deal is unchanged by this retry.
local baseDealStartingHandsWhenReady=dealStartingHandsWhenReady
function dealStartingHandsWhenReady()
    baseDealStartingHandsWhenReady()
    safeWaitTime("Integration",function() dealAllHands() end,11)
end

-- Setup creates the Unit offer before the Action/Spell offers and before the starting-hand deal.
-- The split exposed a typo in PlayingGame.unitOffer(): draw.safeTakeObject(...,deck,...) is called on
-- each {deck=...,guid=...} draw record. Adapt only that short synchronous loop so it uses the record's
-- real Deck with the shared safeTakeObject helper. This keeps the existing Unit-offer algorithm intact.
local baseUnitOffer=unitOffer
function unitOffer()
    return safeCallback("unitOffer",function()
        local normalIpairs=ipairs
        local function unitOfferIpairs(value)
            if type(value)=="table" and type(value[1])=="table" and value[1].deck~=nil and value[1].guid~=nil then
                for _,entry in normalIpairs(value) do
                    if type(entry)=="table" and entry.deck~=nil and entry.guid~=nil and entry.safeTakeObject==nil then
                        entry.safeTakeObject=function(scope,unusedDeck,params)
                            return safeTakeObject(scope,entry.deck,params)
                        end
                    end
                end
            end
            return normalIpairs(value)
        end

        ipairs=unitOfferIpairs
        local ok,result=pcall(baseUnitOffer)
        ipairs=normalIpairs
        if ok~=true then error(result,0) end
        return result
    end)
end

local baseFillSlide=fillSlide
function fillSlide()
    return safeCallback("fillSlide",function() return baseFillSlide() end)
end

-- Also repair a completely empty setup offer if TTS missed the first population pass. Only a zero-card
-- offer is retried, so this cannot add a second set on top of a successful initial deal.
local baseAfterLoad=afterLoad
function afterLoad()
    local result=baseAfterLoad()
    safeWaitTime("Integration",function()
        if gStates==nil or gStates.firstStarted~=true then return end

        local unitArea=getObjectFromGUID("a3d99b")
        local unitCards=0
        if unitArea~=nil then
            for _,obj in pairs(unitArea.getObjects()) do if obj.type=="Card" then unitCards=unitCards+1 end end
        end
        if unitCards==0 then unitOffer() end

        local deedOffer=getObjectFromGUID(GUID.zone.offer)
        local offerCards=0
        if deedOffer~=nil then
            for _,obj in pairs(deedOffer.getObjects()) do if obj.type=="Card" then offerCards=offerCards+1 end end
        end
        if offerCards==0 then fillSlide() end
    end,5)
    return result
end
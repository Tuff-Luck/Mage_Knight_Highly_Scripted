-- Final cross-module gameplay integration.
-- Loaded after the gameplay modules so these wrappers can coordinate setup/runtime helpers
-- without putting the same implementation back into multiple source files.

-- UI.lua still declares DisplayHelp as a chunk-local function. Because Integration.lua is bundled
-- after UI.lua in the same Global chunk, that local is visible here. Export the exact function to
-- the Global callback table so earlier modules (SetupGame/mainUIUpdate) and XML can call it.
if type(DisplayHelp)=="function" then _G.DisplayHelp=DisplayHelp end

-- Fury of the Apocalypse Dragon: deploy its scenario manual beside the other rulebooks while
-- the rules bag still exists. The first setupGame call only stores the rewind point; deploy on
-- the rewind-ready pass so rewinding setup restores the pre-setup state cleanly.
local baseSetupGame=setupGame
function setupGame(player, mouseButton, id, rewindReady)
    if mouseButton=="-1" and rewindReady==true and gStates~=nil and gStates.gameScenario=="Fury of the Apocalypse Dragon" and getObjectFromGUID("8d7fb9")==nil then
        local ruleBag=getObjectFromGUID("d4a866")
        if ruleBag~=nil then
            local manual=safeTakeObject("Integration",ruleBag,{guid="8d7fb9",position={41.00,0.96,35.00},rotation={0,180,0},smooth=false})
            if manual~=nil then
                safeWaitCondition("Integration",function()
                    local current=getObjectFromGUID("8d7fb9")
                    if current~=nil then current.lock() end
                end,function()
                    local current=getObjectFromGUID("8d7fb9")
                    return current==nil or current.resting==true
                end,5)
            end
        end
    end
    return baseSetupGame(player,mouseButton,id,rewindReady)
end

-- Fury's one-hex Dragon footprint (42b581) is attached inside the normal Dragon model (105141).
-- Immediately after takeObject, TTS can expose the model before its attachment hierarchy is ready.
-- Retry for a short period instead of deciding synchronously that the marker is missing.
function furyDragonExtractMarker(target)
    if gStates==nil or gStates.gameScenario~="Fury of the Apocalypse Dragon" then return nil end
    local marker=getObjectFromGUID("42b581")
    if marker~=nil then
        marker.unlock()
        marker.setRotation({0,180,0})
        marker.setPosition(target)
        return marker
    end

    local bag=getObjectFromGUID(GUID.bag.apocalypseDragon)
    if bag==nil then return nil end
    local dragon=bag.takeObject({guid="105141",position={-65.5,4,22},rotation={0,180,180},smooth=false})
    if dragon==nil then return nil end

    local dragonGUID=dragon.guid
    local attempts=0
    local function attachmentParent(parent)
        if parent==nil or parent.getAttachments==nil then return nil end
        for _,attachment in ipairs(parent.getAttachments() or {}) do
            if attachment.guid=="42b581" then return parent end
            local found=attachmentParent(attachment)
            if found~=nil then return found end
        end
        return nil
    end

    local function returnDragon(liveDragon)
        if liveDragon==nil then return end
        local liveBag=getObjectFromGUID(GUID.bag.apocalypseDragon)
        if liveBag~=nil then liveBag.putObject(liveDragon) else liveDragon.destruct() end
    end

    local function tryExtract()
        attempts=attempts+1
        local liveDragon=getObjectFromGUID(dragonGUID) or dragon
        if liveDragon==nil then return end
        local parent=attachmentParent(liveDragon)
        if parent==nil then
            if attempts<60 then safeWaitFrames("Integration",tryExtract,1)
            else
                returnDragon(liveDragon)
                broadcastToAll("Fury setup could not detach the single-space Apocalypse Dragon marker (42b581).",warningColor)
            end
            return
        end

        local found=nil
        for _,detached in ipairs(parent.removeAttachments() or {}) do
            if detached.guid=="42b581" then found=detached else parent.addAttachment(detached) end
        end
        if found==nil then
            if attempts<60 then safeWaitFrames("Integration",tryExtract,1)
            else
                returnDragon(liveDragon)
                broadcastToAll("Fury setup found the Dragon attachment group but not marker 42b581.",warningColor)
            end
            return
        end

        found.unlock()
        found.setRotation({0,180,0})
        found.setPosition(target)
        returnDragon(liveDragon)
    end
    safeWaitFrames("Integration",tryExtract,1)

    -- furyDragonSetupLair only uses the return value as a success/failure signal. The physical marker
    -- is placed by tryExtract as soon as TTS exposes the attachment hierarchy.
    return dragon
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

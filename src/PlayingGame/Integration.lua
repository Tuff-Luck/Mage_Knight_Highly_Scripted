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
                    --SetupGame's normal delayed rulebook pass locks this beside the other manuals.
                    safeTakeObject("Integration",ruleBag,{guid="8d7fb9",position={41.00,0.96,35.00},rotation={0,180,0},smooth=false})
                end
            end
        end
        return baseSetupGame(player,mouseButton,id,rewindReady)
    end,function() return setupGameErrorContext(player,id,rewindReady) end)
end

-- The stats/bug sheet should receive an explicit FALSE for Apocalypse Quest just like the other
-- setup toggles. Older/default states can leave this field nil until the option is touched.
local baseSendDataRequest=SendDataRequest
function SendDataRequest(...)
    if gStates~=nil then gStates.apocalypseQuestCards=(gStates.apocalypseQuestCards==true) end
    return baseSendDataRequest(...)
end

local baseFillSlide=fillSlide
function fillSlide()
    return safeCallback("fillSlide",function() return baseFillSlide() end)
end

-- Final Global lifecycle integration for subsystem helpers moved out of object scripts.
-- Required last so TTS sees one active onLoad/onSave pair after all modules are defined.

local baseOnSave = onSave

local function savedRollerState(saved_data)
    if type(saved_data) ~= "string" or saved_data == "" then return nil end
    local ok, data = pcall(JSON.decode, saved_data)
    if ok and type(data) == "table" then return data.rollerDice end
    return nil
end

function onLoad(saved_data)
    return safeCallback("onLoad", function()
        artifactOnLoad()
        rollerOnLoad(savedRollerState(saved_data))
        return __onLoad_raw(saved_data)
    end)
end

function onSave()
    return safeCallback("onSave", function()
        local saved_data = baseOnSave()
        if type(saved_data) ~= "string" or saved_data == "" then return saved_data end

        local ok, data = pcall(JSON.decode, saved_data)
        if not ok or type(data) ~= "table" then return saved_data end

        data.rollerDice = rollerOnSave()
        return JSON.encode(data)
    end)
end

-- Centralised dice-roller logic for the Roll Crystal Die / Roll Dungeon Die bags.
-- The old object scripts were copies of the same MrStump roller with a few settings changed.

local ROLLER_CONFIG = {
    ["4fcc61"] = {maxCount = 1, layout = "single"},
    ["9758bf"] = {maxCount = 4, layout = "row"},
    ["c4a961"] = {maxCount = 4, layout = "row"},
    ["03de4d"] = {maxCount = 4, layout = "row"},
}

local RADIUS = 2
local ARC = 120
local ROTATION = 180
local HEIGHT = 1.5
local ROLL_DELAY = 1.2
local CLEANUP_DELAY = 15

local RESULT_ROTATION = {
    {270.00, 0.00, 0.00},
    {0.00, 90.00, 0.00},
    {0.00, 270.00, 270.00},
    {0.00, 180.00, 90.00},
    {0.00, 270.00, 180.00},
    {90.00, 180.00, 0.00},
}

local ROW_X = {
    [1] = {0},
    [2] = {-1.1, 1.1},
    [3] = {-2.2, 0, 2.2},
    [4] = {-3.3, -1.1, 1.1, 3.3},
}

local rollerState = {}

local function pointOnArc(roller, index, count)
    local i = index - 0.5
    local angle = ARC / count
    local offset = -ARC / 2 + ROTATION
    local x = math.sin(math.rad(angle * i + offset)) * RADIUS
    local z = math.cos(math.rad(angle * i + offset)) * RADIUS
    return roller.positionToWorld({x = x, y = HEIGHT, z = z})
end

local function randomRotation()
    local u1 = math.random()
    local u2 = math.random()
    local u3 = math.random()
    local u1sqrt = math.sqrt(u1)
    local u1m1sqrt = math.sqrt(1 - u1)
    local qx = u1m1sqrt * math.sin(2 * math.pi * u2)
    local qy = u1m1sqrt * math.cos(2 * math.pi * u2)
    local qz = u1sqrt * math.sin(2 * math.pi * u3)
    local qw = u1sqrt * math.cos(2 * math.pi * u3)
    local ysqr = qy * qy
    local t0 = -2.0 * (ysqr + qz * qz) + 1.0
    local t1 = 2.0 * (qx * qy - qw * qz)
    local t2 = -2.0 * (qx * qz + qw * qy)
    local t3 = 2.0 * (qy * qz - qw * qx)
    local t4 = -2.0 * (qx * qx + ysqr) + 1.0
    if t2 > 1.0 then t2 = 1.0 end
    if t2 < -1.0 then t2 = -1.0 end
    return {math.deg(math.asin(t2)), math.deg(math.atan2(t3, t4)), math.deg(math.atan2(t1, t0))}
end

local function alphanumSort(values)
    local function padnum(d) return ("%03d%s"):format(#d, d) end
    table.sort(values, function(a, b)
        return tostring(a):gsub("%d+", padnum) < tostring(b):gsub("%d+", padnum)
    end)
end

local function cleanupRoller(state)
    for _, die in ipairs(state.dice) do
        if die ~= nil then destroyObject(die) end
    end
    state.dice = {}
    state.phase = nil
    state.rollToken = state.rollToken + 1
    state.cleanupToken = state.cleanupToken + 1
end

local function displayResults(state, color)
    local values = {}
    for _, die in ipairs(state.dice) do
        if die ~= nil then table.insert(values, tostring(die.getRotationValue())) end
    end
    alphanumSort(values)
    local text = Player[color].steam_name .. "    " .. string.char(9679) .. "    " .. table.concat(values, ", ")
    broadcastToAll(text, stringColorToRGB(color))
end

local function layoutResults(state)
    local roller = state.roller
    local count = #state.dice
    for index, die in ipairs(state.dice) do
        local result = die.getValue()
        die.setLock(true)
        die.setScale(Vector(3, 3, 3))
        local zOffset = math.floor((roller.getBounds().size.z / 2) + (die.getBounds().size.z / 2) + 0.5)
        local xOffset = state.config.layout == "single" and 0 or ROW_X[count][index]
        die.setPositionSmooth(roller.getPosition() + Vector(xOffset, 2, zOffset))
        die.setRotationSmooth(RESULT_ROTATION[result])
    end
end

local function finalizeRoll(state, color)
    displayResults(state, color)
    layoutResults(state)
    state.phase = "done"
    state.cleanupToken = state.cleanupToken + 1
    local cleanupToken = state.cleanupToken
    local guid = state.guid
    safeWaitTime("Rollers",function()
        local current = rollerState[guid]
        if current ~= nil and current.cleanupToken == cleanupToken and current.phase == "done" then cleanupRoller(current) end
    end, CLEANUP_DELAY)
end

local function waitForDiceToRest(guid, rollToken, color)
    local state = rollerState[guid]
    if state == nil or state.rollToken ~= rollToken or state.phase ~= "rolling" then return end
    for _, die in ipairs(state.dice) do
        if die ~= nil and not die.resting then
            safeWaitFrames("Rollers",function() waitForDiceToRest(guid, rollToken, color) end, 1)
            return
        end
    end
    -- One physical roll only. The old object scripts rolled every die a second time here.
    finalizeRoll(state, color)
end

local function beginRoll(guid, rollToken, color)
    local state = rollerState[guid]
    if state == nil or state.rollToken ~= rollToken or state.phase ~= "waiting" then return end
    state.phase = "rolling"
    for _, die in ipairs(state.dice) do
        die.setLock(false)
        die.randomize()
    end
    safeWaitFrames("Rollers",function() waitForDiceToRest(guid, rollToken, color) end, 1)
end

local function queueRoll(state, color)
    state.rollToken = state.rollToken + 1
    local rollToken = state.rollToken
    local guid = state.guid
    safeWaitTime("Rollers",function() beginRoll(guid, rollToken, color) end, ROLL_DELAY)
end

function MKRollDieButton(roller, color)
    local state = rollerState[roller.getGUID()]
    if state == nil then return end
    if state.phase == "done" then
        cleanupRoller(state)
    elseif state.phase == "rolling" then
        Player[color].broadcast("Roll in progress.", {0.8, 0.2, 0.2})
        return
    end
    if #state.dice >= state.config.maxCount then
        Player[color].broadcast("Roll in progress.", {0.8, 0.2, 0.2})
        return
    end
    local newCount = #state.dice + 1
    for index, die in ipairs(state.dice) do die.setPositionSmooth(pointOnArc(roller, index, newCount)) end
    local die = roller.takeObject({position = pointOnArc(roller, newCount, newCount), rotation = randomRotation()})
    die.setScale({1, 1, 1})
    die.setLock(true)
    die.script_state = " "
    table.insert(state.dice, die)
    state.phase = "waiting"
    queueRoll(state, color)
end

local function installRoller(guid)
    local roller = getObjectFromGUID(guid)
    if roller == nil then return false end
    rollerState[guid] = {guid = guid, roller = roller, config = ROLLER_CONFIG[guid], dice = {}, phase = nil, rollToken = 0, cleanupToken = 0}
    roller.clearButtons()
    roller.createButton({click_function = "MKRollDieButton", function_owner = Global, position = {0, 0.05, 0}, height = 650, width = 650, color = {1, 1, 1, 0}})
    return true
end

local function installRollers(attempt)
    local missing = false
    for guid in pairs(ROLLER_CONFIG) do
        if rollerState[guid] == nil and not installRoller(guid) then missing = true end
    end
    if missing and attempt < 60 then safeWaitFrames("Rollers",function() installRollers(attempt + 1) end, 1) end
end

local function destroySavedRollerDice(savedState)
    if type(savedState) ~= "table" then return end
    for _, dice in pairs(savedState) do
        if type(dice) == "table" then
            for _, dieGUID in ipairs(dice) do
                local die = getObjectFromGUID(dieGUID)
                if die ~= nil then destroyObject(die) end
            end
        end
    end
end

function rollerOnSave()
    local savedState = {}
    for guid, state in pairs(rollerState) do
        local dice = {}
        for _, die in ipairs(state.dice or {}) do
            if die ~= nil then dice[#dice + 1] = die.getGUID() end
        end
        savedState[guid] = dice
    end
    return savedState
end

function rollerOnLoad(savedState)
    destroySavedRollerDice(savedState)
    rollerState = {}
    installRollers(1)
end

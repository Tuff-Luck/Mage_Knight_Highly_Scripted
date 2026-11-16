---@meta

-- Tabletop Simulator API declarations used by the Lua language server.
-- This file is editor-only; it must not be bundled into the TTS Global script.

---Look up a live TTS object by its six-character GUID (nil if absent).
---@param guid string
---@return any
function getObjectFromGUID(guid) end

---Write a value to Tabletop Simulator's system console.
---@param value any
---@param label? string
---@param tags? string[]
function log(value, label, tags) end

---Send a chat message to a specific player, with an optional text colour.
---@param message string
---@param player_color string
---@param message_tint? table
function broadcastToColor(message, player_color, message_tint) end

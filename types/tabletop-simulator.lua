---@meta

-- Tabletop Simulator API declarations used by the Lua language server.
-- This file is editor-only; it must not be bundled into the TTS Global script.

---Look up a live TTS object by its six-character GUID (nil if absent).
---@param guid string
---@return any
function getObjectFromGUID(guid) end

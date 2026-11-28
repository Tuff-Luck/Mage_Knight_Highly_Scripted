---@meta

-- Editor-only Call to Arms / Call to Glory preview types.
-- Keep named declarations outside src so the TTS bundle cannot duplicate them.

---@class CallOfferPlacement
---@field position number[]
---@field rotation number[]
---@field scale? number[]

---@class CallOfferPreviewState
---@field spellGUID string
---@field seatPos integer
---@field order string[]
---@field index integer
---@field unitGUID? string
---@field home? CallOfferPlacement
---@field display? CallOfferPlacement

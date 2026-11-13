-- Isolated regression tests load only the lightweight production helpers from Shared.
-- Loading all of Shared would reset game state and require a live TTS environment.
local handle=assert(io.open("src/Shared.lua","r"))
local shared=handle:read("*a")
handle:close()
local first=assert(shared:find("-- Shared Offer navigation helpers.",1,true))
local after=assert(shared:find("local UI_BUTTON_ACTIVE_IMAGE",first,true))
assert(load(shared:sub(first,after-1),"Shared Offer navigation helpers","t",_G))()

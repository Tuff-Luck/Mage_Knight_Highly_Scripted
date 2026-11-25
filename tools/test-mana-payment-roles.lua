-- Run from repository root: lua5.2 tools/test-mana-payment-roles.lua
package.path="src/?.lua;"..package.path
local payment=require("PlayingGame.PlayerBoard.ResourceTracker.Scanning.ManaPayments")
local spec={castColor="Blue",powerColor="Black",colors={Blue="ice",Red="fire"}}
local function token(guid,color) return {guid=guid,color=color} end
local blue,black,red=token("cast","Blue"),token("power","Black"),token("effect","Red")
local function check(list,gold,night,category,expected)
    local options,wildcard=payment.effectManaPossibilities(spec,list,true,gold,night)
    local power=payment.effectManaPowerColors(spec,list,gold,night,category)
    assert((options[category]==true or wildcard)==expected)
    assert((power.Black==true)==expected)
end
check({blue,black,red},false,true,"fire",true)
check({red,blue,black},false,true,"fire",true)
check({blue,black},false,true,"ice",false)
check({blue,black,token("cast","Blue")},false,true,"ice",false)
check({blue,black,token("other","Blue")},false,true,"ice",true)
check({blue,black,red},true,false,"fire",false)
check({token("gold","Gold"),black,red},true,true,"fire",true)
check({blue,token("gold","Gold"),red},true,true,"fire",false)
check({blue,black,token("gold","Gold")},true,true,"ice",true)
local ordinary=payment.effectManaPossibilities(spec,{blue,red},false,false,true)
assert(ordinary.fire and not ordinary.ice)
print("Shared distinct mana role regression passed")

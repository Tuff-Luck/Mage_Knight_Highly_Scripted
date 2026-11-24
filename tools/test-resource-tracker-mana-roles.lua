-- Independent mana roles must use distinct objects and the live Gold/Black permissions.
-- Run from the repository root with Lua 5.2.
package.path="src/?.lua;"..package.path
local payment=require("PlayingGame.PlayerBoard.ResourceTracker.ManaPayments")
local function mana(guid,color) return {guid=guid,color=color} end
local spec={castColor="Blue",powerColor="Black",colors={Red="red",White="white",Blue="blue",Green="green"}}
local cast,power,effect=mana("cast","Blue"),mana("power","Black"),mana("effect","Red")
local permutations={{cast,power,effect},{cast,effect,power},{power,cast,effect},
    {power,effect,cast},{effect,cast,power},{effect,power,cast}}
for _,items in ipairs(permutations) do
    local options,wild=payment.effectManaPossibilities(spec,items,true,false,true)
    assert(options.red==true and wild==false,"Three roles must be independent of discovery order")
    assert(payment.effectManaPowerColors(spec,items,false,true,"red").Black==true,
        "Only the actual stronger-effect color qualifies")
    assert(next(payment.effectManaPowerColors(spec,items,false,true,"white"))==nil,
        "An unavailable elemental choice cannot supply power")
end
local options,wild=payment.effectManaPossibilities(spec,{cast,power,cast},true,false,true)
assert(next(options)==nil and wild==false,"Duplicating a GUID cannot pay two roles")
assert(next(payment.effectManaPowerColors(spec,{cast,power,cast},false,true,"blue"))==nil)
assert(next(payment.effectManaPowerColors(spec,{cast,power,effect},true,false,"red"))==nil,
    "Day without an explicit Black permission cannot power a Black strong side")
local gold=mana("gold","Gold")
options,wild=payment.effectManaPossibilities(spec,{cast,power,gold},true,true,true)
assert(wild==true,"Independent Gold and Black permissions can both apply")
assert(payment.effectManaPowerColors(spec,{cast,power,gold},true,true,"white").Black==true)
options,wild=payment.effectManaPossibilities(spec,{cast,power,gold},true,false,true)
assert(wild==false and next(options)==nil,"Night without Gold permission cannot select by Gold")
local pureMagic={powerColor="Green",colors={Red="attack",Blue="block",White="influence",Green="move"}}
local green=mana("green","Green")
assert(next(payment.effectManaPowerColors(pureMagic,{green,green},false,true,"move"))==nil,
    "Pure Magic cannot reuse its own Green payment for the choice")
assert(payment.effectManaPowerColors(pureMagic,{green,mana("secondGreen","Green")},false,true,"move").Green==true)
assert(payment.effectManaPowerColors(pureMagic,{effect,gold},true,false,"attack").Green==true,
    "Gold can fill a separate basic stronger-effect role")
assert(next(payment.effectManaPowerColors(nil,{},true,false,"attack"))==nil)
print("Independent mana roles and Gold/Black permissions passed")

-- Run from repository root: lua5.2 tools/test-move-role-options.lua
package.path="src/?.lua;"..package.path
local m=require("PlayingGame.PlayerBoard.ResourceTracker.Interface.MoveRoleOptions")
assert(m.producesMove({move=2}) and not m.producesMove({move=0}))
assert(m.producesMove({move=0,shapeshiftTargetGUID="card"},"move"))
assert(not m.producesMove({move=0,shapeshiftTargetGUID="card"},"attack"))
assert(not m.producesMove(nil))
local role,valid=m.resolve(true,false,nil)
assert(role=="movement" and valid)
role,valid=m.resolve(true,true,"combat")
assert(role=="combat" and valid)
role,valid=m.resolve(true,false,"combat")
assert(role==nil and not valid)
role,valid=m.resolve(false,true,"combat")
assert(role==nil and not valid)
role,valid=m.resolve(false,false,nil)
assert(role==nil and valid)
local category,requested=m.decodeCardCategory(m.cardCategory("move","combat"))
assert(category=="move" and requested=="combat")
category,requested=m.decodeCardCategory("attack")
assert(category=="attack" and requested==nil)
for _,case in ipairs({
    {true,true,"movement",true,true},
    {true,false,"movement",true,false},
    {true,false,"combat",false,true},
    {true,true,"combat",true,true},
    {false,false,"combat",true,false},
}) do
    local a,b=m.visibleRoles(case[1],case[2],case[3])
    assert(a==case[4] and b==case[5])
end
local a,b=m.badgeNode(m.badge("movement")),m.badgeNode(m.badge("combat"))
assert(a.attributes.text=="M" and a.attributes.color=="#9AFFA4")
assert(b.attributes.text=="C" and b.attributes.color=="#69AEFF")
assert(a.attributes.fontSize==b.attributes.fontSize and a.attributes.raycastTarget=="false")
print("Shared Move role controls passed")

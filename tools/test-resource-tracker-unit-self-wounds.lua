-- Direct phase eligibility regressions for self-wounding Unit abilities.
local abilities={
    block={{block=4,woundsSelf=true}},
    attack={{attack=4,woundsSelf=true}},
    elemental={{blockFire=4,woundsSelf=true}},
    ordinary={{attack=3}},
    multiple={{block=3,woundsSelf=true},{attack=4,woundsSelf=true}},
    otherSeat={{attack=3,woundsSelf=true}},
    incomplete={{block=3,woundsSelf=true}},
    missing={{attack=3,woundsSelf=true}},
    defeated={{attack=3,woundsSelf=true}},
    unused={{attack=3,woundsSelf=true}},
    unpaid={{attack=3,woundsSelf=true}}
}
local activations,records={},{}
local observed={}
local function key(guid,index) return guid.."#use"..index end
for guid in pairs(abilities) do
    activations[guid]={seatPos=1,uses={{index=1}}}
    records[key(guid,1)]={complete=true}
end
activations.otherSeat.seatPos=2
activations.multiple.uses={{index=1,frozenCounts={red=1},lastCounts={blue=1}},
    {index=2,lastCounts={red=2}}}
records[key("multiple",2)]={complete=true}
records[key("incomplete",1)].complete=false
local calculate=dofile("src/PlayingGame/PlayerBoard/ResourceTracker/UnitSelfWounds.lua")(
    function(guid) return abilities[guid] end,
    function(guid,activation) return activation.uses end,key,
    function(guid) if guid~="missing" then return {guid=guid} end end,
    function(unit,choices,activation,counts)
        observed[activation]=counts
        if unit.guid=="unpaid" then return nil end
        return {index=activation.index}
    end)
local function eq(actual,expected,label)
    assert(actual==expected,label..": expected "..tostring(expected)..", got "..tostring(actual))
end
local active={}
for guid in pairs(abilities) do
    if guid~="defeated" and guid~="unused" then active[#active+1]={key=key(guid,1)} end
end
active[#active+1]={key=key("multiple",2)}
local groups={{sources=active},{rangeDefeated=true,sources={{key=key("defeated",1)}}}}
local early,late=calculate(1,groups,records,activations)
eq(early.block,true,"Block ability wounds before enemy damage")
eq(late.block,nil,"Block wound is not a late wound")
eq(late.attack,true,"Attack ability wounds in final Attack")
eq(early.attack,nil,"Attack wound does not occur before enemy damage")
eq(early.elemental,true,"Elemental Block is an early wound")
eq(early.multiple,true,"Historical Block use retained")
eq(late.multiple,true,"Later Attack use separately recognized")
eq(observed[activations.multiple.uses[1]],activations.multiple.uses[1].frozenCounts,"Frozen mana preferred")
eq(observed[activations.multiple.uses[2]],activations.multiple.uses[2].lastCounts,"Live count fallback")
for _,guid in ipairs({"ordinary","otherSeat","incomplete","missing","defeated","unused","unpaid"}) do
    eq(early[guid],nil,guid.." has no early wound")
    eq(late[guid],nil,guid.." has no late wound")
end
local e,l=calculate(1,{{destroyed=true,sources=active}},records,activations)
eq(next(e),nil,"Destroyed group grants no early wounds")
eq(next(l),nil,"Destroyed group grants no late wounds")
e,l=calculate(1,nil,records,activations)
eq(next(e),nil,"Missing groups grants no early wounds")
eq(next(l),nil,"Missing groups grants no late wounds")
eq(records[key("block",1)].complete,true,"Scan records left intact")
print("Unit self-wound phase timing and activation eligibility passed")

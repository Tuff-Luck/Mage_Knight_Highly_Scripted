-- Related regressions share a runner and fixtures while each case retains local state.
-- Run from repository root: lua5.2 tools/test-resource-tracker-mana-payments.lua
package.path="src/?.lua;"..package.path
local payment=require("PlayingGame.PlayerBoard.ResourceTracker.Scanning.ManaPayments")

local failures={}
local function run(name,body)
    local ok,message=xpcall(body,debug.traceback)
    if not ok then
        failures[#failures+1]=name..": "..tostring(message)
    end
end

run("mana-payment-roles",function()
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
end)

run("resource-tracker-mana-roles",function()
    -- Independent mana roles must use distinct objects and the live Gold/Black permissions.
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
end)

run("repeated-effect-mana",function()
    local spec={colors={Red="attack",Blue="block",Green="move",White="influence"}}
    local function mana(guid,color) return {guid=guid,color=color} end
    local red1,red2,blue,gold=mana("r1","Red"),mana("r2","Red"),mana("b1","Blue"),mana("g1","Gold")
    local function paid(items,selected,goldAllowed,count)
        return payment.effectManaSelectionsPaid(spec,items,selected,goldAllowed,count or 2)
    end
    assert(not paid({red1},{"attack","attack"},true),"One mana cannot pay twice")
    assert(not paid({red1,red1},{"attack","attack"},true),"Duplicate GUID cannot pay twice")
    assert(paid({red1,red2},{"attack","attack"},false),"Two distinct red payments")
    assert(paid({red1,blue},{"attack","block"},false),"Different choices each use their own mana")
    assert(not paid({red1,blue},{"attack","attack"},false),"Wrong colour cannot pay second use")
    assert(paid({gold,red1},{"attack","block"},true),"Exact colour reserved before wildcard")
    assert(paid({gold,red1},{"block","attack"},true),"Selection order does not change validity")
    assert(not paid({gold,red1},{"block","attack"},false),"Illegal Gold cannot pay")
    assert(not paid({gold,gold},{"block","attack"},true),"Same Gold cannot fill two roles")
    assert(not paid({red1,red2},{"attack"},true),"Missing second selection")
    assert(not paid({red1,red2,gold},{"attack","block","move"},true,3),"One Gold cannot cover two missing colours")
    assert(paid({red1,red2,gold},{"attack","attack","move"},true,3),"Three independent payments")
    print("Repeated effect mana selection regressions passed")
end)

run("resource-tracker-unit-mana",function()
    -- Unit payment permission and signature checks use the real extracted helpers.
    local gold,black=true,false
    local function goldAllowed() return gold end
    local function blackAllowed() return black end
    local function paid(color,counts)
        return payment.unitAbilityPaid({manaCost=color},counts,goldAllowed,blackAllowed)
    end
    local function signature(counts)
        return payment.unitManaSignature(counts,goldAllowed,blackAllowed)
    end
    assert(paid(nil,{}),"No mana cost")
    assert(paid("Blue",{Blue=1}),"Matching mana")
    assert(paid("Blue",{Gold=1}),"Gold wildcard")
    assert(not paid("Black",{Gold=1}),"Gold never substitutes for Black")
    assert(not paid("Black",{Black=1}),"No Black permission")
    local day=signature({Blue=1})
    assert(day==signature({Blue=1,Red=0}),"Missing and zero counts are equivalent")
    assert(day~=signature({Blue=2}),"Changed count changes signature")
    gold,black=false,true
    assert(not paid("Blue",{Gold=1}),"Gold disabled")
    assert(paid("Black",{Black=1}),"Black allowed")
    assert(signature({Blue=1})~=day,"Permission changes invalidate signature")
    gold=true
    assert(paid("Red",{Gold=1}) and paid("Black",{Black=1}),"Independent simultaneous permissions")
    assert(not paid("Black",{Gold=1}),"Both permissions still cannot substitute Gold for Black")
    print("Unit mana payment eligibility and signatures passed")
end)

if #failures>0 then
    error(table.concat(failures,"\n\n"),0)
end

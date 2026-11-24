-- Unit payment permission and signature checks use the real extracted helpers.
package.path="src/?.lua;"..package.path
local payment=require("PlayingGame.PlayerBoard.ResourceTracker.ManaPayments")
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

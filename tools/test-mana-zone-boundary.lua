-- Physical mana payments use current zone membership, even for special cards.
local f=assert(io.open("src/PlayingGame/PlayerBoard/CardRecognition.lua","r"))
local src=f:read("*a") f:close()
local function section(first,last)
    local a=assert(src:find(first,1,true),first)
    local b=assert(src:find(last,a+#first,true),last)
    return src:sub(a,b-1)
end
local talent={guid="3d832c"}
local spell={guid="spell"}
local maximal={guid="maximal"}
local function mana(guid,color)
    local o={guid=guid,type="Dice",color=color,resting=false}
    o.getPosition=function() return {o.x or 0,2,o.z or 0} end
    o.isSmoothMoving=function() return o.moving==true end
    o.getRotationValue=function() return o.color.." Mana" end
    return o
end
local blue,second,black=mana("blue","Blue"),mana("second","Blue"),mana("black","Black")
local members={}
local zone={getObjects=function() return members end}
local objects={["3d832c"]=talent,spell=spell,maximal=maximal,zone=zone}
local env=setmetatable({
    trackerPrivate={},playerPlayAreas={[1]="zone"},
    gameCards={spell={cardType="Spell"}},
    getObjectFromGUID=function(guid) return objects[guid] end,
    getAllObjects=function() error("Payment may not scan the entire table") end,
    footprint=function() return {x=0,z=0,halfX=1,halfZ=1} end,
    isManaTokenFigurine=function(obj) return obj.type=="Figurine" end,
    manaTokenColor=function(obj) return obj.color end,
    cardPosture=function() return "upright" end,
    matchesCardMana=function(_,color) return color=="Blue" end
},{__index=_G})
env.require=function(name)
    local modules={
        ["PlayingGame.PlayerBoard.ResourceTracker.Scanning.PhysicalObjects"]="src/PlayingGame/PlayerBoard/ResourceTracker/Scanning/PhysicalObjects.lua",
        ["PlayingGame.PlayerBoard.ResourceTracker.Scanning.ManaPayments"]="src/PlayingGame/PlayerBoard/ResourceTracker/Scanning/ManaPayments.lua"
    }
    return assert(loadfile(assert(modules[name],"Unexpected payment dependency"),"t",env))()
end
assert(load(table.concat({
    section('local manaColor=require("PlayingGame.PlayerBoard.ResourceTracker.Scanning.PhysicalObjects").manaColor','factionRewardForObject=require("PlayingGame.PlayerBoard.ResourceTracker.Scanning.PhysicalObjects").factionRewardForObject'),
    section("function trackerPrivate.paymentManaColorForSeat(","-- A powered link grants"),
    section("function resourceCardsMaximalEffectSourceManaGUIDs(","-- One shared linked-throw decision")
},"\n"),"Zone-bound mana","t",env))()
local function check(n)
    assert(#env.magicTalentManaPayments(1)==n,"Magic Talent payment membership")
    assert(env.magicTalentSpellCastingPaid(1,"spell")== (n>0),"Spell casting membership")
    assert(env.magicTalentSpellCastingPaymentCount(1,"spell")==n,"Repeated casting membership")
    local spent=env.resourceCardsMaximalEffectSourceManaGUIDs(1,"maximal")
    local count=0 for _ in pairs(spent) do count=count+1 end
    assert(count==n,"Maximal Effect payment membership")
end
check(0)
members={blue} check(1)
members={blue,second,blue} check(2)
second.held_by_color="Red" check(1)
second.held_by_color=nil second.moving=true check(1)
second.moving=false check(2)
members={second} check(1)
second.x=1 check(0) -- Touching the edge is not a payment.
second.x=0.99 check(1)
second.x=0 second.z=-1 check(0)
second.z=-0.99 check(1)
second.z=0
local crystal=mana("crystal","Blue")
crystal.type="Figurine"
members={crystal,blue,crystal} check(2)
crystal.held_by_color="Blue" check(1)
crystal.held_by_color=nil
members={} check(0)
-- Live membership, not physical X/Z overlap, decides whether mana qualifies.
members={crystal} check(1)
members={} check(0)
members={blue}
spell.is_face_down=true
assert(not env.magicTalentSpellCastingPaid(1,"spell"))
assert(env.magicTalentSpellCastingPaymentCount(1,"spell")==0)
spell.is_face_down=false
local oldZone=objects.zone
objects.zone=nil check(0)
objects.zone=oldZone check(1)
members={black}
assert(not env.magicTalentSpellCastingPaid(1,"spell"),"Black alone never casts a Spell")
assert(env.magicTalentSpellCastingPaymentCount(1,"spell")==0)
-- Named vector coordinates and array coordinates use the same boundary.
blue.getPosition=function() return {x=0,y=2,z=0} end
members={blue,blue} check(1)
blue.getPosition=function() return {x=1,y=2,z=0} end
check(0)
blue.getPosition=function() return {x=0,y=2,z=0} end
check(1)
-- Boolean casting still stops at the first payment; counting visits all.
local reads=0
second.getPosition=function() reads=reads+1 return {x=0,y=2,z=0} end
members={blue,second}
assert(env.magicTalentSpellCastingPaid(1,"spell"))
assert(reads==0,"Boolean query stops after the first eligible payment")
assert(env.magicTalentSpellCastingPaymentCount(1,"spell")==2 and reads==1)
members={black,blue,blue}
assert(env.magicTalentSpellCastingPaid(1,"spell"))
assert(env.magicTalentSpellCastingPaymentCount(1,"spell")==1)
print("Mana zone boundary regressions passed")

-- Two browser sources overlapping the same live mana cannot both use it.
local secondTalent={guid="otherTalent"}
objects.otherTalent=secondTalent
talent.getPosition=function() return {0,1,0} end
secondTalent.getPosition=function() return {0,1.2,0} end
members={blue}
local sources={talent.guid,secondTalent.guid}
assert(#env.magicTalentManaPayments(1,talent.guid,sources)==0,"Lower browser does not reuse higher payment")
assert(#env.magicTalentManaPayments(1,secondTalent.guid,sources)==1,"Highest browser owns payment")
blue.getPosition=function() return {0,1.02,0} end
assert(#env.magicTalentManaPayments(1,talent.guid,sources)==1,"Under-card payment belongs to lower browser")
assert(#env.magicTalentManaPayments(1,secondTalent.guid,sources)==0,"Payment below upper card is not reused")
members={}
assert(#env.magicTalentManaPayments(1,talent.guid,sources)==0,"Shared ranking still respects zone boundary")
print("Overlapping browser mana regressions passed")

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
    o.getPosition=function() return {0,2,0} end
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
    isManaTokenFigurine=function() return false end,
    cardPosture=function() return "upright" end,
    matchesCardMana=function(_,color) return color=="Blue" end
},{__index=_G})
env.require=function(name)
    assert(name=="PlayingGame.PlayerBoard.ResourceTracker.PhysicalObjects", "Unexpected recognition dependency")
    return assert(loadfile("src/PlayingGame/PlayerBoard/ResourceTracker/PhysicalObjects.lua","t",env))()
end
assert(load(table.concat({
    section('local manaColor=require("PlayingGame.PlayerBoard.ResourceTracker.PhysicalObjects").manaColor','factionRewardForObject=require("PlayingGame.PlayerBoard.ResourceTracker.PhysicalObjects").factionRewardForObject'),
    section("function magicTalentSpellCastingPaid(","-- A powered link grants"),
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
members={} check(0)
members={black}
assert(not env.magicTalentSpellCastingPaid(1,"spell"),"Black alone never casts a Spell")
assert(env.magicTalentSpellCastingPaymentCount(1,"spell")==0)
print("Mana zone boundary regressions passed")

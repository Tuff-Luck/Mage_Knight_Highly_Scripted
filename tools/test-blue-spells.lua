-- Blue Spell regression checks. Run from repository root:
-- lua5.2 tools/test-blue-spells.lua
local function eq(actual,expected,label)
    if actual~=expected then
        error((label or "Mismatch")..": expected "..tostring(expected)
            ..", got "..tostring(actual),2)
    end
end
local function source(path)
    local f=assert(io.open(path,"r"))
    local data=f:read("*a")
    f:close()
    return data
end
local function isolated(text,first,last,name)
    local a=assert(text:find(first,1,true),"Missing "..first)
    local b=assert(text:find(last,a+#first,true),"Missing "..last)
    return assert(load(text:sub(a,b-1).."\nreturn "..name))()
end

local data=source("src/Data.lua")
local recognition=source("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local combat=source("src/PlayingGame/Combat.lua")
local turn=source("src/PlayingGame/Turn.lua")
assert(data:find('removeFireResist=true,iceSpell=true',1,true),"Chill needs Ice Resistance marker")
assert(data:find('armourReduce=4,iceSpell=true',1,true),"Lethal Chill needs Ice Resistance marker")
assert(data:find('poweredHeroFirstWound=true',1,true),"Veil of Mist needs hero protection flag")

-- Chill/Lethal Chill: suppress non-Attack effects against Ice Resistance,
-- but still allow other non-resistant enemies and report immunity separately.
gStates={monsterPerks={}}
monsterPugs={
    plain={name="Plain"},
    cold={name="Cold",iResist=true},
    immune={name="Immune",arcaneImmunity=true}
}
dofile("src/PlayingGame/PlayerBoard/CombatEffects.lua")
local effects={}
combatEffectAdd(effects,"cold","2eb8e0",{iceSpell=true,noAttack=true,removeFireResist=true})
eq(effects.cold.noAttack,false,"Chill cannot prevent Ice Resistant attack")
eq(effects.cold.removeFireResist,false,"Chill cannot remove resistance")
eq(effects.cold.iceResistIgnored,true,"Ice Resistance reason recorded")
eq(effects.cold.applied[1].effective.noAttack,nil,"Ineffective icon metadata")
combatEffectAdd(effects,"plain","2eb8e0",{iceSpell=true,noAttack=true,armourReduce=4})
eq(effects.plain.noAttack,true,"Lethal Chill prevents unresistant attack")
eq(effects.plain.armourReduce,4,"Lethal Chill reduces unresistant Armor")
combatEffectAdd(effects,"immune","2eb8e0",{iceSpell=true,noAttack=true,armourReduce=4})
eq(effects.immune.noAttack,false,"Arcane Immunity still blocks Chill")
eq(effects.immune.armourReduce,0,"Arcane Immunity blocks Armour reduction")

-- Veil of Mist: one Wound is ignored across all attacks, and the
-- ignored Wound must not trigger Poison or Paralyse on the Hero.
combatUnitResists=function() return false end
local resolve=isolated(recognition,
    "local function combatDamageResolve(items,units,heroArmour,targetsOf,mitigation,elementMitigation,ignoreFirstHeroWound)",
    "local function combatWoundsText", "combatDamageResolve")
local none=function() return {} end
local hits={
    {key="a:1",owner="a",type="P",damage=2,poison=true,paralyse=true},
    {key="b:1",owner="b",type="P",damage=2,poison=true}
}
local shielded=resolve(hits,{},2,none,nil,nil,true)
eq(shielded["a:1"].heroWounds,0,"Veil ignores first Hero Wound")
eq(shielded["a:1"].discard,0,"Ignored Poison Wound gives no extra discard")
eq(shielded["a:1"].paralyse,false,"Ignored Paralyse Wound does not paralyse")
eq(shielded["a:1"].veilWoundIgnored,true,"Veil annotation")
eq(shielded["b:1"].heroWounds,1,"Only first Wound is ignored")
eq(shielded["b:1"].discard,1,"Later Poison Wound behaves normally")
local unshielded=resolve(hits,{},2,none,nil,nil,false)
eq(unshielded["a:1"].heroWounds,1,"Veil does not act when not powered")
local heavy=resolve({{key="a:1",owner="a",type="P",damage=5,poison=true}},
    {},2,none,nil,nil,true)
eq(heavy["a:1"].heroWounds,2,"Veil removes one of three Wounds")
eq(heavy["a:1"].discard,2,"Only remaining Poison Wounds add discards")

-- Time Bending: availability does not depend on the Resource Tracker panel.
GUID={card={timeBending="2eb8e2"}}
playerPlayAreas={[1]="play"}
local isDay=false
resourceCardsUsesDayMana=function() return isDay end
cardPosture=function() return "upright" end
footprint=function() return {x=0,z=0,halfX=1.5,halfZ=1.8} end
manaInsideFootprint=function(obj,area)
    local p=obj.getPosition()
    return math.abs(p[1]-area.x)<area.halfX and math.abs(p[3]-area.z)<area.halfZ
end
manaColor=function(obj) return obj.color end
manaClaimDieHeld=function() return false end
local blue={guid="blue",color="Blue",getPosition=function() return {0,1,0} end}
local black={guid="black",color="Black",getPosition=function() return {0.2,1,0} end}
local spell={guid="2eb8e2",is_face_down=false}
local playObjects={spell,blue,black}
getObjectFromGUID=function(guid)
    if guid=="play" then return {getObjects=function() return playObjects end} end
end
local paid=isolated(recognition,
    "function resourceCardsTimeBendingPaid(seatPos,card)",
    "-- Physical mana is authoritative", "resourceCardsTimeBendingPaid")
eq(paid(1,spell),true,"Nighttime Blue and Black pay Time Bending")
playObjects={spell,black}
eq(paid(1,spell),false,"Black alone is not a cast")
playObjects={spell,blue}
eq(paid(1,spell),false,"Blue alone does not power Time Bending")
playObjects={spell,blue,black}
isDay=true
eq(paid(1,spell),false,"Black is not legal during Day")
isDay=false
spell.is_face_down=true
eq(paid(1,spell),false,"Face-down Time Bending is inert")
assert(turn:find("resourceCardsTimeBendingPaid(details.seatPos,obj)==true",1,true),
    "Extra turn eligibility must consult actual mana")

-- Mana Claim: after the claim turn, its die is held, not a later mana
-- payment, and released when the round changes.
gStates={currentRound=2}
turnOrder={{seatPos=1}}
playerPlayAreas={[1]="play"}
spell={guid="2eb8f4",is_face_down=false,
    getPosition=function() return {0,1,0} end,
    getBounds=function() return {size={2,0.1,3}} end}
local casting={guid="casting",type="Dice",getPosition=function() return {0,1,0} end,
    getRotationValue=function() return "Blue Mana" end}
local claimed={guid="claimed",type="Dice",getPosition=function() return {3,1,0} end,
    getRotationValue=function() return "Red Mana" end}
playObjects={spell,casting,claimed}
getObjectFromGUID=function(guid)
    if guid=="play" then return {getObjects=function() return playObjects end} end
    if guid=="claimed" then return claimed end
end
scriptObjectId=function() return "Mana Dice" end
cardEffectIsVertical=function() return true end
positionToColor=function() return "Red" end
safeBroadcastToColor=function() end
local held=isolated(combat,
    "function manaClaimDieHeld(guid)",
    "local function combatReturnPreEndTurnDie", "manaClaimDieHeld")
-- The isolated chunk defines both global functions.
manaClaimRegisterForTurn(1)
eq(held("claimed"),true,"Claimed die survives end-of-turn cleanup")
eq(held("casting"),false,"Casting die is not retained")
assert(recognition:find("not manaClaimDieHeld(obj.guid)",1,true),
    "Claimed die cannot pay unrelated tracker actions")
combatReturnPreEndTurnDie=function(_,guid) eq(guid,"claimed","Return claimed die") end
isolated(combat,"function manaClaimReturnHeldDice()",
    "local function combatPreEndTurnPreparePlayArea", "manaClaimReturnHeldDice")()
eq(gStates.manaClaimHeldDice,nil,"Round reset clears claimed die register")
assert(turn:find("manaClaimReturnHeldDice()",1,true),"Round reset returns Mana Claim die")

print("Blue Spell regression checks passed")

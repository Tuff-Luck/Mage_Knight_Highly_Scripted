-- All non-Forgemaster Spell pairs must remain registered with both faces.
-- Run at repository root: lua5.2 tools/test-spell-catalog.lua
local function read(path)
    local file=assert(io.open(path,"r"))
    local content=file:read("*a")
    file:close()
    return content
end
local function between(text,first,last)
    local a=assert(text:find(first,1,true),"Missing: "..first)
    local b=assert(text:find(last,a+#first,true),"Missing: "..last)
    return text:sub(a,b-1)
end
local function eq(value,expected,message)
    assert(value==expected,(message or "Mismatch")..": expected "..tostring(expected)
        ..", got "..tostring(value))
end
local data=read("src/Data.lua")
local reader=read("src/PlayingGame/PlayerBoard/CardRecognition.lua")

-- This explicit roster detects new omissions, duplicated aliases, wrong colours,
-- missing powered names and accidentally included Rise of the Forgemaster cards.
local expected={
    {"Red","Mana Meltdown","Mana Radiance","spellUtility"},
    {"Red","Offering","Sacrifice","spellOffering"},
    {"Red","Demolish","Disintegrate","spellDemolish"},
    {"Red","Fireball","Firestorm","spellFireball"},
    {"Red","Burning Shield","Exploding Shield","spellBurningShield"},
    {"Red","Flame Wall","Flame Wave","spellFlameWall"},
    {"Blue","Mana Claim","Mana Curse","spellUtility"},
    {"Blue","Mist Form","Veil of Mist","spellMistForm"},
    {"Blue","Mana Bolt","Mana Thunderbolt","spellManaBolt"},
    {"Blue","Snowstorm","Blizzard","spellSnowstorm"},
    {"Blue","Chill","Lethal Chill","spellChill"},
    {"Blue","Space Bending","Time Bending","spellSpaceBending"},
    {"White","Mind Read","Mind Steal","spellUtility"},
    {"White","Charm","Possess","spellCharm"},
    {"White","Wings of Wind","Wings of Night","spellWingsNight"},
    {"White","Expose","Mass Expose","spellExpose"},
    {"White","Call to Arms","Call to Glory","spellUtility"},
    {"White","Whirlwind","Tornado","spellWhirlwind"},
    {"Green","Energy Flow","Energy Steal","spellUtility"},
    {"Green","Cure","Disease","spellCure"},
    {"Green","Restoration","Rebirth","spellRestoration"},
    {"Green","Underground Travel","Underground Attack","spellUtility"},
    {"Green","Tremor","Earthquake","spellTremor"},
    {"Green","Meditation","Trance","spellUtility"}
}
local excludedForgemaster={
    ["995f43"]=true,["20b391"]=true,["4bf1a4"]=true,
    ["b4ce88"]=true,["7c0a57"]=true,["81b086"]=true,["8eac5c"]=true
}
local roster={}
local counts={Red=0,Blue=0,White=0,Green=0}
local totalCards=0
for line in data:gmatch("[^\n]+") do
    if line:find('cardType="Spell"',1,true) then
        local guid=line:match('%["([0-9a-f]+)"%]')
        if not excludedForgemaster[guid] then
            local normal,powered=line:match('name%s*=%s*{%s*"([^"]+)"%s*,%s*"([^"]+)"')
            local color=line:match('color%s*=%s*{%s*"([^"]+)"')
            local key=line:match('resourceKey="([^"]+)"')
            assert(normal and powered and color and key,"Malformed Spell row: "..line)
            totalCards=totalCards+1
            if roster[normal] then
                eq(roster[normal].powered,powered,normal.." duplicate powered face")
                eq(roster[normal].color,color,normal.." duplicate colour")
                eq(roster[normal].key,key,normal.." duplicate definition")
            else
                roster[normal]={powered=powered,color=color,key=key}
                counts[color]=(counts[color] or 0)+1
            end
        end
    end
end
local seen={}
for _,entry in ipairs(expected) do
    local color,normal,powered,key=entry[1],entry[2],entry[3],entry[4]
    assert(not seen[normal],"Duplicated expected pair: "..normal)
    seen[normal]=true
    local actual=assert(roster[normal],"Missing Spell: "..normal)
    eq(actual.color,color,normal.." colour")
    eq(actual.powered,powered,normal.." stronger face")
    eq(actual.key,key,normal.." tracker definition")
end
local unique=0
for name in pairs(roster) do
    assert(seen[name],"Unexpected non-Forgemaster Spell: "..name)
    unique=unique+1
end
eq(unique,24,"Distinct spell pairs")
eq(totalCards,28,"Physical non-Forgemaster Spell entries, including competitive copies")
for _,color in ipairs({"Red","Blue","White","Green"}) do
    eq(counts[color],6,color.." distinct Spell pairs")
end

-- Evaluate the actual Spell definition table, rather than copying numeric values.
local section=between(data,"    -- Spell resources are independent",
    "    -- Artifact sides are physical")
local defs=assert(load("return {\n"..section.."\n}"))()
for _,entry in ipairs(expected) do
    local key=entry[4]
    local rule=assert(defs[key],"Missing Spell effect definition: "..key)
    assert(rule.normal~=nil or rule.normalChoices~=nil or rule.normalTrackerNeutral==true,
        entry[2].." basic side lacks a deliberate definition")
    assert(rule.powered~=nil or rule.poweredChoices~=nil,
        entry[3].." strong side lacks a deliberate definition")
end

-- Real payment matching: coloured casts, night-only Black and day-only Gold.
local paymentFunctions=between(reader,"local function resourceCardsUsesDayMana()",
    "-- A powered link grants a target Action card")
local payment=assert(load([[
local gameCards={spell={cardType="Spell",color={"Blue"}}}
local gStates={dayRound=true,turnNumber=1}
local turnOrder={{avatarLocation="glade"}}
]]..paymentFunctions..[[
return {
    matches=matchesCardMana,
    day=function(value,location)
        gStates.dayRound=value
        turnOrder[1].avatarLocation=location or "glade"
    end
}
]]))()
local card={guid="spell"}
eq(payment.matches(card,"Blue"),true,"Colour casts its own Spell")
eq(payment.matches(card,"Red"),false,"Wrong colour cannot cast")
eq(payment.matches(card,"Gold"),true,"Daytime Gold casts")
eq(payment.matches(card,"Black"),false,"Daytime Black cannot power")
payment.day(false)
eq(payment.matches(card,"Gold"),false,"Night Gold cannot cast")
eq(payment.matches(card,"Black"),true,"Night Black can power")
payment.day(true,"dungeon")
eq(payment.matches(card,"Gold"),false,"Dungeon blocks Day Gold")
eq(payment.matches(card,"Black"),true,"Dungeon permits Night Black")

-- Mana Bolt/Thunderbolt has three independent physical mana roles: cast,
-- stronger side, and elemental choice. No physical mana can pay twice.
local selectPayment=between(reader,"local function effectManaPossibilities(",
    "-- Only the separate stronger-effect payment qualifies")
local possibilities=assert(load(selectPayment.."\nreturn effectManaPossibilities"))()
local spec=defs.spellManaBolt.effectManaChoice
local function mana(guid,color) return {guid=guid,color=color} end
local options,wildcard=possibilities(spec,
    {mana("cast","Blue"),mana("power","Black"),mana("effect","Red")},true,false)
eq(options.red,true,"Three independent payments unlock Thunderbolt")
eq(wildcard,false,"No wildcard without Day Gold")
options=possibilities(spec,{mana("cast","Blue"),mana("power","Black")},true,false)
eq(next(options),nil,"Two mana cannot satisfy three independent roles")
options=possibilities(spec,{mana("cast","Blue"),mana("effect","White")},false,false)
eq(options.white,true,"Basic Mana Bolt has cast and effect mana")
options=possibilities(spec,
    {mana("cast","Blue"),mana("power","Black"),mana("effect","Red")},true,true)
eq(next(options),nil,"Daytime Black cannot power Thunderbolt")
options,wildcard=possibilities(spec,
    {mana("cast","Blue"),mana("effect","Gold")},false,true)
eq(wildcard,true,"Daytime Gold may select a basic elemental effect")

assert(reader:find('spellCastingPaid[card.guid]==true',1,true),
    "Printed Spell resources need an actual casting payment")
assert(reader:find('local costPaid=(data==nil or data.cardType~="Spell" or spellCastPaid==true)',1,true),
    "Unpaid Spell must not enter the calculator")

print("Spell catalogue and shared mana regressions passed (24 pairs / 28 cards)")

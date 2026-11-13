-- Official Mage Knight artifact regressions (exclude fan-made expansions).
-- Run at repository root: lua5.2 tools/test-artifact-effects.lua
local function read(path)
    local f=assert(io.open(path,"r"))
    local s=f:read("*a")
    f:close()
    return s
end
local function between(s,a,b)
    local start=assert(s:find(a,1,true),"missing "..a)
    local stop=assert(s:find(b,start+#a,true),"missing "..b)
    return s:sub(start,stop-1)
end
local function eq(actual,expected,what)
    assert(actual==expected,(what or "Mismatch")..": expected "..
        tostring(expected)..", got "..tostring(actual))
end
local data=read("src/Data.lua")
local recognition=read("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local layout=read("src/PlayingGame/PlayerBoard/UnitLayout.lua")
local assignments=read("src/PlayingGame/AttackAssignments.lua")
local map=read("src/PlayingGame/Map.lua")
local ui=read("src/PlayingGame/UI.lua")

local expected={
    ["Ruby Ring"]="artifactRing",["Emerald Ring"]="artifactRing",
    ["Diamond Ring"]="artifactRing",["Sapphire Ring"]="artifactRing",
    ["Endless Gem Pouch"]="artifactUtility",["Sword of Justice"]="artifactSwordOfJustice",
    ["Circlet of Proficiency"]="artifactUtility",["Mysterious Box"]="artifactUtility",
    ["Horn of Wrath"]="artifactHornOfWrath",["Endless Bag of Gold"]="artifactEndlessBagOfGold",
    ["Tome of All Spells"]="artifactUtility",["Druidic Staff"]="artifactDruidicStaff",
    ["Soul Harvester"]="artifactSoulHarvester",["Banner of Fear"]="artifactBannerFear",
    ["Banner of Courage"]="artifactBannerCourage",["Banner of Glory"]="artifactBannerGlory",
    ["Banner of Protection"]="artifactBannerProtection",
    ["Banner of Fortitude"]="artifactBannerFortitude",
    ["Banner of Command"]="artifactBannerOfCommand",
    ["Amulet of Darkness"]="artifactAmuletDarkness",
    ["Amulet of The Sun"]="artifactAmuletSun",
    ["Golden Grail"]="artifactGoldenGrail",["Bow of Starsdawn"]="artifactBowOfStarsdawn",
    ["Book of Wisdom"]="artifactUtility",
    ["Shield of the Fallen Kings"]="artifactShieldOfTheFallenKings"
}
local seen,physical={},0
for line in data:gmatch("[^\n]+") do
    if line:find('cardType="Artifact"',1,true) then
        physical=physical+1
        local name=line:match('name%s*=%s*{%s*"([^"]+)"')
        local key=line:match('resourceKey="([^"]+)"')
        assert(name~=nil and key~=nil,"bad artifact row: "..line)
        eq(key,expected[name],"Official artifact key "..name)
        seen[name]=true
    end
end
for name in pairs(expected) do assert(seen[name],"missing official artifact: "..name) end
local unique=0
for name in pairs(seen) do unique=unique+1 end
eq(unique,25,"Distinct official artifacts")
assert(physical>=25,"Official alternate physical states are missing")

local section=between(data,"    -- Artifact sides are physical",
    "    -- Wound-taking bonuses require")
local defs=assert(load("return {\n"..section.."\n}"))()
eq(defs.artifactAmuletSun.artifactMana,"gold","Sun permits Gold")
eq(defs.artifactAmuletDarkness.artifactMana,"black","Darkness permits Black")
eq(defs.artifactShieldOfTheFallenKings.normalChoices[2].repeatBlocks,2,
    "Shield has two independent normal blocks")
eq(defs.artifactShieldOfTheFallenKings.poweredChoices[2].repeatBlocks,3,
    "Shield has three independent broken blocks")
eq(defs.artifactSwordOfJustice.artifactGlobalCombat,"sword","Sword active")
eq(defs.artifactBowOfStarsdawn.artifactGlobalCombat,"bow","Bow active")
eq(defs.artifactDruidicStaff.staffDualChoices,true,"Staff independent Break options")
eq(defs.artifactDruidicStaff.unitReadyLevels.powered,3,"Staff ready level limit")
eq(defs.artifactBannerFear.enemyEffect.powered.maxTargets,3,
    "Banner of Fear three-enemy maximum")
assert(map:find("resourceCardsAmuletSunRevealActive()",1,true),
    "Sun must reach real map reveal logic even at Night")
assert(layout:find("bannersByUnit=unitLayoutBannersForUnits(layout)",1,true),
    "Attached banners must be observed in Unit layout")
assert(recognition:find('source.key.."#block"..index',1,true),
    "Separate Shield block must have individual stable target key")
assert(recognition:find('fortitudePrevented=true',1,true),
    "Fortitude prevention must skip Wound and Poison/Paralysis consequences")
assert(recognition:find('source.gloryFame',1,true),
    "Only activated combat Units can earn Glory Fame")
assert(assignments:find('if total>=maximum and not distinct[target.guid] then',1,true),
    "Fear must reject fourth target")
assert(ui:find("resourceCardsCombatAssignmentClick(id,mouseButton)",1,true),
    "Combat UI must forward right-click for Bow options")
assert(recognition:find('inventorySpec={choices=remaining}',1,true),
    "Druidic Staff's second UI option must be clickable")
assert(recognition:find('resourceCardsArtifactNoteClicked',1,true),
    "Manual Horn and Soul effects must be visible on either artifact face")

-- The startup audit requires the Artifact Object UI callbacks to be published,
-- not merely defined as globals; exercise the exact production registration.
local published={}
local registration=assert(recognition:match("(publishPublicUICallbacks%(%b{}%))%s*$"),
    "Missing CardRecognition public callback registration")
local registrationTest=assert(load([[
local function publishPublicUICallbacks(callbacks)
    for name,callback in pairs(callbacks) do
        assert(type(callback)=="function","Invalid published callback: "..name)
        published[name]=true
    end
end
local resourceCardsRegenerationReadyClicked=function() end
local resourceCardsArtifactNoteClicked=function() end
local resourceCardsArtifactHealUnitsClicked=function() end
]]..registration..[[
return published
]],"Artifact protected callback registration","t",setmetatable({published=published},{__index=_G})))
registrationTest()
for _,name in ipairs({
    "resourceCardsRegenerationReadyClicked",
    "resourceCardsArtifactNoteClicked",
    "resourceCardsArtifactHealUnitsClicked"
}) do
    assert(published[name]==true,"Unprotected Artifact UI callback: "..name)
end

-- Execute the live payment matcher in a minimal deterministic environment.
local paymentSource=between(recognition,"local function resourceCardsUsesDayMana()",
    "-- A powered link grants a target Action card")
local payment=assert(load([[
local combatConfig={amuletMana={gold=false,black=false}}
local gameCards={spell={cardType="Spell",color={"Blue"}}}
local gStates={dayRound=true,turnNumber=1}
local turnOrder={{avatarLocation="glade"}}
]]..paymentSource..[[
return {
    matches=matchesCardMana,
    amulets=combatConfig.amuletMana,
    setDay=function(day) gStates.dayRound=day end
}
]]))()
local spell={guid="spell"}
eq(payment.matches(spell,"Gold"),true,"Day Gold")
eq(payment.matches(spell,"Black"),false,"Day Black")
payment.amulets.black=true
eq(payment.matches(spell,"Black"),true,"Darkness activates Black during Day")
payment.setDay(false)
payment.amulets.black=false
eq(payment.matches(spell,"Black"),true,"Night Black")
eq(payment.matches(spell,"Gold"),false,"Night Gold")
payment.amulets.gold=true
eq(payment.matches(spell,"Gold"),true,"Sun activates Gold during Night")
eq(payment.matches(spell,"Black"),true,"Sun does not disable Night Black")

-- Execute the production Attack totals with the same per-source Bow mode.
local mathSource=between(recognition,"local function combatEnemyResists(",
    "-- Blocks of the wrong element")
local calculator=assert(load([[
local combatConfig={
    artifactCombat={sword=false,bow=false},
    bowSourceModes={},
    attackTypes={{key="P",attack="attack",ranged="ranged",siege="siege"}}
}
local function combatEnemyHasTrait(data,perks,key)
    return data[key]==true or (perks~=nil and perks[key]==true)
end
]]..mathSource..[[
return {
    sum=combatAttackTotal,combat=combatConfig
}
]]))()
local enemy={}
local source={key="unit#use1",resources={ranged=3,siege=2,attack=4}}
eq(calculator.sum({{sources={source},category="ranged"},
    {sources={source},category="siege"}},enemy,nil,"range"),5,"Normal range total")
calculator.combat.artifactCombat.bow=true
eq(calculator.sum({{sources={source},category="ranged"},
    {sources={source},category="siege"}},enemy,nil,"range"),8,
    "Bow defaults to doubling Ranged, keeping Siege")
calculator.combat.bowSourceModes[source.key.."#ranged"]="siege"
eq(calculator.sum({{sources={source},category="siege"}},enemy,nil,"range"),5,
    "Bow converts Ranged 3 to Siege 3, keeping original Siege 2")
calculator.combat.bowSourceModes[source.key.."#ranged"]="double"
calculator.combat.bowSourceModes[source.key.."#siege"]="ranged"
eq(calculator.sum({{sources={source},category="ranged"}},enemy,nil,"range"),10,
    "Bow converts and doubles Siege into Ranged")
eq(calculator.sum({{sources={source},category="ranged"},
    {sources={source},category="siege"}},enemy,nil,"attack"),5,
    "Bow never multiplies in melee Attack phase")
calculator.combat.artifactCombat.sword=true
calculator.combat.artifactCombat.bow=false
eq(calculator.sum({{sources={source},category="attack"}},enemy,nil,"attack"),8,
    "Sword doubles physical Attack in Attack phase")
eq(calculator.sum({{sources={source},category="attack"}},
    {pResist=true},nil,"attack"),8,"Sword removes Physical Resist")
eq(calculator.sum({{sources={source},category="ranged"}},
    {pResist=true},nil,"range"),3,
    "Sword removes Physical Resist also during Ranged phase")
eq(calculator.sum({{sources={source},category="attack"}},
    {pResist=true,arcaneImmunity=true},nil,"attack"),4,
    "Arcane immune enemies keep Physical Resist")
print("Official artifact roster, mana, targeting and combat regressions passed")

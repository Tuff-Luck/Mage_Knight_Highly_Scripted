-- Red Advanced Action regression checks (base game and Lost Legion only).
-- Run from repository root: lua5.2 tools/test-red-advanced-actions.lua
local function eq(actual,expected,label)
    if actual~=expected then error((label or "Mismatch")..": expected "
        ..tostring(expected)..", got "..tostring(actual),2) end
end
local function source(path)
    local f=assert(io.open(path,"r"))
    local text=f:read("*a")
    f:close()
    return text
end
local function contains(s,needle,label)
    assert(s:find(needle,1,true),label or ("Missing: "..needle))
end

local data=source("src/Data.lua")
local reader=source("src/PlayingGame/PlayerBoard/CardRecognition.lua")

-- Counterattack is a bonus per completely Blocked ENEMY, not per attack.
contains(data,"blockedEnemyAttackBonus={normal=2,powered=3}","Counterattack amounts")
contains(reader,"rowBlock[index].allBlocked","Every printed attack must be Blocked")
contains(reader,"#combatEnemyAttacks(enemy)>0","No bonus from attackless enemies")
contains(reader,"if not group.rangeDefeated then","No bonus from Ranged kills")
contains(reader,"combatConfig.blockedEnemyCounts[blockSeat]=blockedEnemies",
    "Dynamic Block count must be refreshed")

-- Explosive Bolt generates conditional Armour reduction without adding
-- unsupported numeric Ranged damage or altering the preceding Ranged phase.
contains(data,"defeatArmourReduce=1","Explosive Bolt rule")
contains(reader,'#explosiveAttack','Separate Armour target')
contains(reader,'combatConfig.applyExplosiveBoltRange(entries,groups,allocated,sources)',
    "Explosive Bolt resolves before the Block phase")
contains(reader,'or combatEnemyHasTrait(target.data,target.perks,"arcaneImmunity")',
    "Arcane Immunity protects against Armour reduction")
contains(reader,"rangedVictims[enemy.guid]=true","Track prior Ranged defeats")
contains(reader,'combatEnemyHasTrait(target.data,target.perks,"fResist")',
    "Fire resistant targets remain protected")
contains(reader,"math.max(1,member.baseArmour-delta)","Armour minimum one")
contains(reader,'member.rangeBaseArmour=math.max(1,',
    "Armour reduction also applies to subsequent Ranged-phase attacks")
contains(reader,'icon="MKChoiceArmourReduction"',"Combat reduction icon")

-- Maximal Effect: 3 basic or 2 stronger repetitions, each with its
-- own option and (for Improvisation/Ritual Attack) its own discard payment.
contains(data,'normalCount=3,poweredCount=2',"Maximal Effect multipliers")
contains(reader,'hasDiscard[source.guid]=paid==need',"All copied costs must be paid")
contains(reader,'repeated.options[index]=linkedColorChoices',"Ritual Attack colors are independent")
contains(reader,'selected.repeatChoices[repeatIndex]=category',"Independent choice buttons")
contains(reader,'value*repeatLink.count or value',"Repeated Reputation scales")
contains(reader,'and (source.is_face_down~=true or repeated~=nil)',
    "Already thrown away copied Actions still resolve costs")

-- Explicit Blood Rage Wound confirmation cannot be guessed from a
-- prior resource total, nor reused for every Maximal Effect repetition.
contains(data,'woundConfirmation=true',"Blood Rage manual payment")
contains(reader,'rule.woundConfirmation==true and not sideways',
    "No initial Wound auto-selection")

-- Exercise the actual repeated-choice selector in isolation, without TTS.
local first=assert(reader:find("combatConfig.repeatChoiceFor=function",1,true))
local last=assert(reader:find("-- Bonus choices are independent",first,true))
local helper=reader:sub(first,last-1)
local setup=[[
local combatConfig={}
local gameCards={["878d84"]={resourceKey="bloodRage"},
    ["05ef61"]={resourceKey="ritualAttack"}}
local cardResourceDefinitions={bloodRage={woundConfirmation=true},
    ritualAttack={}}
local selectedResourceByGUID={
    ["878d84"]={effect="wound",repeatChoices={[1]="wound"}},
    ["05ef61"]={repeatChoices={[2]="blue"}}
}
local function choiceCategory(choice)
    return choice.key or next(choice)
end
local function choiceAvailable(choices,key)
    if choices==nil or key==nil then return false end
    for _,choice in ipairs(choices) do
        if choiceCategory(choice)==key then return true end
    end
    return false
end
local function currentChoice(guid,powered,choices)
    local stored=selectedResourceByGUID[guid]
    local chosen=stored~=nil and stored.effect or nil
    for _,choice in ipairs(choices) do
        if choiceCategory(choice)==chosen then return choice,chosen end
    end
    return choices[1],choiceCategory(choices[1])
end
]]
local repeated=assert(load(setup..helper..
    "\nreturn combatConfig.repeatChoiceFor"))()
local rage={{key="attack",attack=2},{key="wound",attack=5}}
local firstRage,firstKey=repeated("878d84",false,rage,1)
eq(firstKey,"wound","Only first copied Blood Rage was confirmed")
eq(firstRage.attack,5,"Confirmed Blood Rage")
local secondRage,secondKey=repeated("878d84",false,rage,2)
eq(secondKey,"attack","Second copied Blood Rage needs another Wound")
eq(secondRage.attack,2,"Default copied Blood Rage")
local ritual={{key="red",attack=5},{key="blue",attackIce=3}}
local firstRitual,firstRitualKey=repeated("05ef61",false,ritual,1)
eq(firstRitualKey,"red","First Ritual Attack colour")
local secondRitual,secondRitualKey=repeated("05ef61",false,ritual,2)
eq(secondRitualKey,"blue","Second Ritual Attack colour")
eq(secondRitual.attackIce,3,"Selected elemental Attack")
print("Red Advanced Actions: regression checks passed")

-- Level III Unit regressions: Freezers, Sorcerers and Catapults.
-- Run from the repository root: lua5.2 tools/test-level-three-units.lua
local function eq(actual,expected,label)
    if actual~=expected then
        error((label or "Mismatch")..": expected "..tostring(expected)
            ..", got "..tostring(actual),2)
    end
end
local function source(path)
    local file=assert(io.open(path,"r"))
    local content=file:read("*a")
    file:close()
    return content
end
local function slice(content,first,last)
    local a=assert(content:find(first,1,true),"Missing marker: "..first)
    local b=assert(content:find(last,a+#first,true),"Missing marker: "..last)
    return content:sub(a,b-1)
end
local function hasButton(xml,id)
    for _,entry in ipairs(xml or {}) do
        if entry.attributes~=nil and entry.attributes.id==id then return true end
    end
    return false
end

dofile("src/PlayingGame/PlayerBoard/UnitResources.lua")
local freezers=assert(unitResourceDefinitions["9e8205"])
local sorcerers=assert(unitResourceDefinitions["c3e3c5"])
local catapults=assert(unitResourceDefinitions["1aa68c"])
eq(unitResourceDefinitions["f8ebe0"],freezers,"Freezers physical copy")
eq(unitResourceDefinitions["223b47"],sorcerers,"Sorcerers physical copy")
eq(unitResourceDefinitions["1aa681"],catapults,"Catapults second copy")
eq(unitResourceDefinitions["d6d932"],catapults,"Catapults third copy")
eq(freezers[1].attack,5,"Freezers basic Attack")
eq(freezers[2].block,5,"Freezers basic Block")
eq(freezers[3].manaCost,"Blue","Freezers paid colour")
eq(freezers[3].enemyEffect.iceSpell,true,"Freezers blue non-Attack effect")
eq(sorcerers[1].ranged,3,"Sorcerers unpowered Ranged Attack")
eq(sorcerers[2].enemyEffect.removeFortify,true,"White removes fortification")
eq(sorcerers[3].enemyEffect.removeResist,true,"Green removes resistances")
eq(catapults[1].siege,3,"Catapults basic Siege")
eq(catapults[2].siegeFire,5,"Catapults red Fire Siege")
eq(catapults[3].siegeIce,5,"Catapults blue Ice Siege")
eq(catapults[2].manaCost,"Red","Catapults Fire payment")
eq(catapults[3].manaCost,"Blue","Catapults Ice payment")
eq(catapults.paidChoiceExpandable,true,"Catapults paid choices expandable")
eq(sorcerers.paidChoiceExpandable,true,"Sorcerers paid choices expandable")

gStates={monsterPerks={perk={iResist=true}}}
monsterPugs={
    ordinary={name="Ordinary"},ice={name="Ice",iResist=true},
    fire={name="Fire",fResist=true},perk={name="Perk"},
    arcane={name="Arcane",arcaneImmunity=true}
}
dofile("src/PlayingGame/PlayerBoard/CombatEffects.lua")
local effect=freezers[3].enemyEffect
local applied={}
for _,target in ipairs({"ordinary","ice","fire","perk","arcane"}) do
    combatEffectAdd(applied,target,"9e8205",effect,"9e8205#effect3")
end
eq(applied.ordinary.noAttack,true,"Freezers prevent normal enemy Attack")
eq(applied.ordinary.armourReduce,3,"Freezers reduce normal enemy Armour")
eq(applied.fire.noAttack,true,"Fire Resistance does not stop blue Freezers")
eq(applied.fire.armourReduce,3,"Fire Resistance does not stop Armour reduction")
eq(applied.ice.noAttack,false,"Ice Resistance preserves enemy Attack")
eq(applied.ice.armourReduce,0,"Ice Resistance preserves enemy Armour")
eq(applied.perk.noAttack,false,"Ice Resistance via perk prevents suppression")
eq(applied.perk.armourReduce,0,"Ice Resistance via perk prevents reduction")
eq(applied.arcane.noAttack,false,"Arcane Immunity preserves enemy Attack")
eq(applied.arcane.armourReduce,0,"Arcane Immunity preserves enemy Armour")
eq(applied.ice.applied[1].iceResistant,true,"Retain resistance for red UI")
eq(applied.ice.applied[1].spec.armourReduce,3,"Retain printed effect in tooltip")

local reader=source("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local decisionCode=slice(reader,"local function unitAbilityPaid(ability,counts)",
    "-- Earlier Command activations own")
local decide=assert(load([[
local daytime=false
local resourceCardsUsesDayMana=function() return daytime end
local unitManaCounts=function() error("Explicit test counts required") end
local unitManaDecision
]]..decisionCode..[[
return function(unit,abilities,activation,counts,isDay)
    daytime=isDay
    return unitManaDecision(unit,abilities,activation,counts)
end
]]))()
local function choice(abilities,activation,counts,day)
    return decide({guid="unit"},abilities,activation,counts,day==true)
end
local one={seatPos=1,choice=1}
eq(choice(catapults,one,{},true).index,1,"Unpowered Siege 3 selected")
eq(choice(catapults,{seatPos=1,choice=1},{Red=1},true).index,2,
    "Single red mana selects only Fire Siege 5")
eq(choice(catapults,{seatPos=1,choice=1},{Blue=1},true).index,3,
    "Single blue mana selects only Ice Siege 5")
local both=choice(catapults,{seatPos=1,choice=1},{Red=1,Blue=1},true)
eq(both.ambiguous,true,"Two different paid Siege options need a choice")
eq(both.index,nil,"Do not add both Catapults' Siege 5 options")
eq(#both.display,2,"Show both elemental Siege alternatives")
local preserved={seatPos=1,choice=1}
eq(choice(catapults,preserved,{Red=1},true).index,2,"Auto Fire selection")
eq(choice(catapults,preserved,{Red=1,Blue=1},true).index,2,
    "Adding blue mana keeps previously active Fire Siege")
local blueSelected={seatPos=1,choice=1,manaChoice=3}
eq(choice(catapults,blueSelected,{Red=1,Blue=1},true).index,3,
    "Explicit Ice Siege choice overrides the automatic Fire Siege")
eq(choice(catapults,{seatPos=1,choice=1},{Gold=1},true).index,nil,
    "Daytime Gold requires choosing a colour for Catapults")
eq(choice(catapults,{seatPos=1,choice=1},{Gold=1},false).index,1,
    "Gold cannot power Catapults at night")

eq(choice(sorcerers,{seatPos=1,choice=1},{},true).index,1,
    "Unpaid Sorcerers use Ranged Attack 3")
eq(choice(sorcerers,{seatPos=1,choice=1},{White=1},true).index,2,
    "White power selects remove Fortification with Ranged 3")
eq(choice(sorcerers,{seatPos=1,choice=1},{Green=1},true).index,3,
    "Green power selects remove Resistances with Ranged 3")
eq(choice(sorcerers,{seatPos=1,choice=1},{White=1,Green=1},true).index,nil,
    "White and green options require a single explicit choice")
eq(choice(sorcerers,{seatPos=1,choice=1,manaChoice=3},
    {White=1,Green=1},true).index,3,"Green effect can be selected with both mana")

-- Load the actual target-key and Unit button builders in a small UI sandbox.
local targetFunctions=slice(reader,
    "local function unitAbilityTargetCategory(ability)",
    "-- The printed normal and powered effects share one choice")
local buttonFunction=slice(reader,
    "local function showUnitAbilityButtons(unit,abilities,activation,unwounded,decision,useIndex)",
    "local function clearChoiceButtons()")
local ui=assert(load([[
local combatCalcOn=true
local combatPsychicActive=false
local combatCumbersomeActive=false
local combatConfig={sourceFields={{key="ranged"},{key="siege"},
    {key="siegeFire"},{key="siegeIce"}},
    unitCombatBlocked=function() return false end}
local function unitHistoryKey(guid,index)
    return index==1 and guid or guid.."#use"..tostring(index)
end
local function unitHistorySelectedNumber() return 1 end
local function unitHistoryIsCombatAbility() return false end
local unitManaDecision=function() error("Provide tested decision") end
local choiceButtonShown,choiceExpandedByGUID={},{}
local choiceLetters={}
local lastXml={}
local function resourceObjectUiXmlTable() return {} end
local function resourceCardsChoiceIcon() return nil end
local function resourceCardsChoiceAssetsFor() return nil,{} end
local function resourceObjectUiSetTable(_,xml) lastXml=xml end
local function removeChoiceButtons() end
]]..targetFunctions..buttonFunction..[[
return {
    key=unitAbilityTargetKey,
    category=unitAbilityTargetCategory,
    render=function(unit,abilities,decision,use)
        choiceButtonShown[unit.guid]=nil
        showUnitAbilityButtons(unit,abilities,{},true,decision,use or 1)
        return lastXml
    end,
    expand=function(guid) choiceExpandedByGUID[guid]=true end
}
]]))()
local sorcGUID="c3e3c5"
eq(ui.category(sorcerers[2]),"ranged","Sorcerers still have ranged points")
eq(ui.key(sorcGUID,2,sorcerers[2],1),sorcGUID.."#effect2",
    "Fortification effect has a separate enemy target")
eq(ui.key(sorcGUID,3,sorcerers[3],2),sorcGUID.."#use2#effect3",
    "Second Command use has a separate enemy effect target")
eq(ui.key(sorcGUID,1,sorcerers[1],1),sorcGUID,
    "Basic Sorcerers Ranged Attack retains its source key")
eq(ui.key("1aa68c",2,catapults[2],1),"1aa68c",
    "Catapults Siege keeps a single physical attack source")
local sorcUnit={guid=sorcGUID,UI={}}
local white=choice(sorcerers,{seatPos=1,choice=1},{White=1},true)
local sorcUi=ui.render(sorcUnit,sorcerers,white,1)
assert(hasButton(sorcUi,"AttackAssignmentSource_"..sorcGUID.."_0_ranged"),
    "Sorcerers need their own Ranged Attack target button")
assert(hasButton(sorcUi,"AttackAssignmentSource_"..sorcGUID.."_0_effect@effect2"),
    "Sorcerers need a separate Remove Fortification target button")
local oldUse=ui.render(sorcUnit,sorcerers,white,2)
assert(hasButton(oldUse,"AttackAssignmentSource_"..sorcGUID.."_0_ranged@use2"),
    "Historical Ranged Attack target must remain independent")
assert(hasButton(oldUse,"AttackAssignmentSource_"..sorcGUID.."_0_effect@use2#effect2"),
    "Historical effect target must use its activation key")
local catUnit={guid="1aa68c",UI={}}
local catUi=ui.render(catUnit,catapults,both,1)
assert(hasButton(catUi,"ResourceCardChoice_1aa68c_unit2"),
    "Ambiguous Siege selection begins collapsed")
assert(not hasButton(catUi,"AttackAssignmentSource_1aa68c_0_siege"),
    "Unselected Catapults cannot generate Siege points")
ui.expand(catUnit.guid)
catUi=ui.render(catUnit,catapults,both,1)
assert(hasButton(catUi,"ResourceCardChoice_1aa68c_unit2"),
    "Expanded menu offers Fire Siege")
assert(hasButton(catUi,"ResourceCardChoice_1aa68c_unit3"),
    "Expanded menu offers Ice Siege")
local selectedBlue=choice(catapults,blueSelected,{Red=1,Blue=1},true)
catUi=ui.render(catUnit,catapults,selectedBlue,1)
assert(hasButton(catUi,"AttackAssignmentSource_1aa68c_0_siegeIce"),
    "Selected Catapults Siege has a single enemy target")
assert(reader:find("allowed[unitHistoryKey(unit.guid,useIndex)]=true",1,true),
    "Switching Sorcerers' effects must preserve their numeric ranged target")
assert(reader:find('targetSpecs[1].index==targetSpecs[2].index',1,true),
    "Separate Ranged/effect buttons should be distinguishable")

print("Level III Freezers, Sorcerers and Catapults regressions passed.")

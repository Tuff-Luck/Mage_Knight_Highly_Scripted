-- Regression for copied Action rows, composite phases and Diplomacy.
-- Run from repo root: lua5.2 tools/test-maximal-effect-repeat-targets.lua
local function source(path)
    local file=assert(io.open(path,"r"))
    local text=file:read("*a")
    file:close()
    return text
end
local function contains(haystack,needle,label)
    assert(haystack:find(needle,1,true)~=nil,label or needle)
end
local function eq(actual,expected,label)
    assert(actual==expected,(label or "value")..": expected "
        ..tostring(expected)..", got "..tostring(actual))
end
local reader=source("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local targeting=source("src/PlayingGame/AttackAssignments.lua")
-- A fixed-effect copy must produce two/three rows, not one multiplied button.
contains(source("src/PlayingGame/PlayerBoard/ResourceTracker/CardControlOptions.lua"),'if repeatLink~=nil and repeatLink.count>1 and posture=="upright" then',
    "Every copied Action must show per-use rows")
contains(reader,'if #row.entries>1 or (repeatLink~=nil and repeatLink.count>1) then',
    "Fixed copied effects display one non-clickable icon per use")
contains(reader,'onClick=#row.entries>1',
    "A one-choice icon cannot change the effect")
contains(source("src/PlayingGame/PlayerBoard/ResourceTracker/CardControlOptions.lua"),'choices={{key="other",icon="other"}}',
    "Untracked repeated effects still display numbered manual-use rows")
contains(reader,'row.index<0 and targetCategory~="unitReady"',
    "A repeated numeric target button has a unique visible row identifier")
contains(targeting,'local repeatIndex,repeatCategory=category:match("^rep(%d+):(.+)$")',
    "Repeated source IDs are decoded before aiming")
contains(targeting,'local sourcePart=part~=nil and part:match("^convertBlock%d+$")',
    "Copied Diplomacy target buttons share one composite source")
contains(reader,'local key=card.guid.."#rep"..index',
    "Enemy debuffs get independent use target keys")
contains(reader,'source.convertedResource=nil',
    "Composite converted Block cannot be split by right-click")
contains(reader,'local count=(result.powered and 2 or 1)*(result.repeatCount or 1)',
    "Dodge and Weave creates one reduction target per copied use")
contains(reader,'local repeatCount=repeatLink~=nil and repeatLink.count or 1',
    "Repeated Dodge and Weave draws per-use target rows")

-- Exercise the actual composite-phase checker without TTS.
local start=assert(reader:find("combatConfig.compositeChoicePhase=function",1,true))
local finish=assert(reader:find("-- Bonus choices are independent",start,true))
local methods=reader:sub(start,finish-1)
local script=[[
local combatConfig={}
local combatCalcOn=true
local combatCumbersomeActive=false
local combatPsychicActive=false
local role="movement"
local gameCards={swift={resourceKey="swiftReflexes"}}
local cardResourceDefinitions={swiftReflexes={
    enemyEffect={normal={choice="reduce",attackReduce=1}}
}}
local function choiceCategory(choice) return choice.key or next(choice) end
local function combatEffectSpec(rule,powered,category)
    local spec=rule.enemyEffect.normal
    return spec.choice==category and spec or nil
end
local function resourceCardsMoveRole() return role end
combatConfig.repeatChoiceFor=function(guid,powered,choices,index)
    return choices[1],nil
end
]]
local phase=assert(load(script..methods..[[
return {
    check=combatConfig.compositePhasesMatch,
    setCumbersome=function(v) combatCumbersomeActive=v end,
    setRole=function(v) role=v end,
}
]]))()
local function uses(...)
    local result={}
    for i,choice in ipairs({...}) do result[i]={choice} end
    return {count=#result,options=result}
end
eq(phase.check("card",false,nil,uses({attack=2},{attack=2},{attack=2})),true,
    "Three Attacks join one phase")
eq(phase.check("card",false,nil,uses({attack=2},{block=2},{attack=2})),false,
    "Cannot split copied effect across Attack and Block phases")
eq(phase.check("card",false,nil,uses({ranged=3},{siege=2})),true,
    "Ranged and Siege occupy the same phase")
eq(phase.check("card",false,nil,uses({move=3},{block=3})),false,
    "Move and Block are normally separate")
phase.setCumbersome(true)
phase.setRole("combat")
eq(phase.check("card",false,nil,uses({move=3},{block=3})),true,
    "Move and Block can combine against Cumbersome")
eq(phase.check("card",false,nil,uses({attack=2},{healing=1})),true,
    "Unphased healing cannot invent another combat phase")
eq(phase.check("swift",false,nil,uses({key="reduce"},{ranged=2})),false,
    "Enemy Attack reductions cannot accompany a different combat phase")

-- Exercise the real Diplomacy conversion limiter with two copied uses.
local a=assert(reader:find("combatConfig.conversionFor=function",1,true))
local b=assert(reader:find("local function combatAssignmentSources",a,true))
local conversion=assert(load([[
local combatConfig={conversionState={}}
local resourceCardScanBySeat={
    [1]={cards={
        ["8c3de6"]={combatConversion="diplomacy",resources={influence=8},
            powered=true,repeatLink={count=2}}
    }}
}
local combatAssignmentState={explicit={},targets={}}
local function combatConversionReserved() return 0 end
local function resourceCardsMoveRole() return "movement" end
]]..reader:sub(a,b-1).."\nreturn combatConfig.conversionFor"))()
local choice,available,valid=conversion(1,"diplomacy")
eq(valid,true,"Copied Diplomacy is active")
eq(available,8,"Two powered uses generate eight Influence")
eq(choice.block,0,"No Block spent by default")
choice.blockUses[1],choice.blockUses[2]=3,4
choice.elementUses[1],choice.elementUses[2]="F","I"
choice,available=conversion(1,"diplomacy")
eq(choice.block,7,"Two counters must spend distinct points")
eq(choice.elementUses[1],"F","First use chooses Fire")
eq(choice.elementUses[2],"I","Second use chooses Ice")
choice.blockUses[2]=99
choice=conversion(1,"diplomacy")
eq(choice.blockUses[2],5,"Second use cannot re-spend first use points")
eq(choice.block,8,"Combined conversion cannot exceed paid Influence")
print("Maximal Effect repeated rows, phases and conversion: regression passed")

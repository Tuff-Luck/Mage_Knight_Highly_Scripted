-- Compact Combat Calculator columns: names and defensive abilities should
-- follow visible content, stay aligned with headers, and fit long text.
-- Run from repository root: lua5.2 tools/test-combat-column-layout.lua

local function read(path)
    local file=assert(io.open(path,"r"))
    local result=file:read("*a")
    file:close()
    return result
end

local source=read("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local xml=read("src/UI/CombatEnemyPanel.xml")
local start=assert(source:find("combatConfig.enemyNameColumnWidth=function(label)",1,true))
local finish=assert(source:find("local function combatAssignmentRefreshRows(entries,sources)",start, true))
local env=setmetatable({combatConfig={}},{__index=_G})
local sizing=source:sub(start,finish-1)..
    "\nreturn combatConfig.enemyNameColumnWidth,combatConfig.traitColumnWidth"
local nameWidth,traitWidth=assert(load(sizing,"Combat column sizing","t",env))()

assert(nameWidth("Ice Mages")<100,"A short enemy name should shrink below the old 100px minimum")
assert(nameWidth("Apocalypse Dragon Head")>nameWidth("Ice Mages"),
    "Longer names must still receive more space")
local iceResist="<color=#5AA0FF>Ice Resist</color>"
local compact=traitWidth({"Fortified\n"..iceResist})
assert(compact==math.max(78,nameWidth("Fortified"),nameWidth("Ice Resist")),
    "Ability width should use the longest displayed line, ignoring rich text tags")
assert(traitWidth({"Double Fortified"})>compact,
    "A longer ability must expand the shared column")
assert(traitWidth({})==78,"Empty ability content should use a compact floor")

assert(source:find('combatConfig.columns.Name=enemyNameWidth',1,true),
    "Name text width must follow its resized parent cell")
assert(source:find('traits=combatConfig.traitColumnWidth(shownTraits)',1,true),
    "Defensive column must use visible row text")
assert(source:find('DefenceTraits=columnWidths.traits',1,true),
    "Header must match the defensive row width")
assert(source:find('+(enemyNameWidth-120)+(columnWidths.traits-150)',1,true),
    "Panel width must account for both dynamically sized columns")
assert(source:find('combatPanelSetAttribute("CombatEnemyRow"..row.."Traits","preferredWidth",tostring(columnWidths.traits))',1,true),
    "Every defensive row must use the shared content width")

assert(xml:find("{en}Def. Ability",1,true),"Use the short defensive header")
for i=1,8 do
    for _,suffix in ipairs({"Name","Traits"}) do
        local id="CombatEnemyRow"..i..suffix
        local tag=assert(xml:match('<Text id="'..id..'"[^>]*>'),"Missing "..id)
        assert(tag:find('resizeTextForBestFit="true"',1,true),
            id.." needs best-fit text when its content is unusually long")
    end
end
print("Compact combat column layout regressions passed")

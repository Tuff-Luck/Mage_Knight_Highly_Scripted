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
local panelRenderer=read("src/PlayingGame/PlayerBoard/ResourceTracker/Interface/CombatPanelRenderer.lua")
local xml=read("src/UI/CombatEnemyPanel.xml")
local layout=dofile("src/PlayingGame/PlayerBoard/ResourceTracker/Interface/CombatPanelLayout.lua")
local nameWidth,traitWidth,textWidth=layout.enemyNameColumnWidth,layout.traitColumnWidth,layout.textColumnWidth

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

local attackFloor=nameWidth("E. Attack")
local offenceFloor=nameWidth("Off. Ability")
local shortAttack=textWidth({"Physical 3\nPhysical 2"},attackFloor)
local longAttack=textWidth({"Physical 3\n<color=#FF5555>Fire Attack 12</color>"},attackFloor)
assert(shortAttack<105,"Short multi-attack lines should shrink below the old 105px width")
assert(longAttack>shortAttack,"A longer attack line should expand the attack column")
assert(textWidth({"Swiftness"},offenceFloor)<130,
    "Short offensive traits should shrink below the old 130px width")
assert(textWidth({"Swiftness\nArcane Immunity"},offenceFloor)>textWidth({"Swiftness"},offenceFloor),
    "An expanded offensive ability should widen its column")
assert(textWidth({"<color=#FF5555>Swiftness</color>"},offenceFloor)
    ==textWidth({"Swiftness"},offenceFloor),
    "Markup must not inflate offensive ability widths")
assert(textWidth({},attackFloor)==attackFloor and textWidth({},offenceFloor)==offenceFloor,
    "Empty columns should keep only their short-header minimums")

assert(source:find('combatConfig.columns.Name=enemyNameWidth',1,true),
    "Name text width must follow its resized parent cell")
assert(panelRenderer:find('traits=combatConfig.traitColumnWidth(shownTraits)',1,true),
    "Defensive column must use visible row text")
assert(panelRenderer:find('DefenceTraits=columnWidths.traits',1,true),
    "Header must match the defensive row width")
assert(panelRenderer:find('+(enemyNameWidth-120)+(columnWidths.traits-150)',1,true),
    "Panel width must account for dynamically sized names and traits")
assert(panelRenderer:find('+(columnWidths.enemyAttack-105)+(columnWidths.offence-130)',1,true),
    "Panel width must reflect dynamic attack and offence widths")
assert(panelRenderer:find('EnemyAttack=columnWidths.enemyAttack,Offence=columnWidths.offence',1,true),
    "Headers must inherit attack and offence content widths")
assert(panelRenderer:find('combatPanelSetAttribute("CombatEnemyAttackCell"..row,"preferredWidth",tostring(columnWidths.enemyAttack))',1,true),
    "Attack panel cells must inherit their dynamically measured width")
assert(panelRenderer:find('combatPanelSetAttribute("CombatEnemyRow"..row.."Attacks","preferredWidth",tostring(columnWidths.enemyAttack))',1,true),
    "Attack text must inherit its dynamically measured width")
assert(panelRenderer:find('combatPanelSetAttribute("CombatEnemyRow"..row.."Offence","preferredWidth",tostring(columnWidths.offence))',1,true),
    "Offensive ability rows must inherit their dynamically measured width")
assert(panelRenderer:find('combatPanelSetAttribute("CombatEnemyRow"..row.."Traits","preferredWidth",tostring(columnWidths.traits))',1,true),
    "Every defensive row must use the shared content width")

assert(xml:find("{en}Def. Ability",1,true),"Use the short defensive header")
assert(xml:find("{en}E. Attack",1,true),"Use the short enemy attack header")
assert(xml:find("{en}Off. Ability",1,true),"Use the short offensive ability header")
for i=1,8 do
    for _,suffix in ipairs({"Name","Traits","Attacks","Offence"}) do
        local id="CombatEnemyRow"..i..suffix
        local tag=assert(xml:match('<Text id="'..id..'"[^>]*>'),"Missing "..id)
        assert(tag:find('resizeTextForBestFit="true"',1,true),
            id.." needs best-fit text when its content is unusually long")
    end
end
-- UTF-8 continuation bytes must not inflate the estimated width.
assert(nameWidth("漢漢漢漢漢")==93,"Five CJK codepoints, not fifteen UTF-8 bytes")
assert(nameWidth("éééééé")==78,"Six two-byte glyphs counted once each")
assert(nameWidth("😀😀😀😀")==86,"Four supplementary codepoints counted once each")
assert(nameWidth("WWWWWW")>nameWidth("iiiiii"),"Wide and narrow glyphs differ")
local entries={}
for i=1,9 do entries[i]={guid=tostring(i),name="Enemy "..i} end
local function page(expectedPage,expectedPages,expectedOffset,expectedEnd,expectedRows,
    list,joined,crowded,rows,requested)
    local p,n,o,e,v=layout.paginate(list,joined,crowded,rows,requested)
    assert(p==expectedPage and n==expectedPages and o==expectedOffset
        and e==expectedEnd and v==expectedRows,
        "Unexpected pagination: "..table.concat({p,n,o,e,v},","))
end
page(1,1,0,0,0,{}, {},4,8,8)
page(1,1,0,3,3,{entries[1],entries[2],entries[3]}, {},4,8,1)
page(1,3,0,4,4,entries,{},4,8,0)
page(3,3,8,9,1,entries,{},4,8,99)
page(1,3,0,3,3,entries,{["5"]=true},4,8,1)
page(2,3,3,7,4,entries,{["5"]=true},4,8,2)
-- An oversized group must not stall pagination or leave a blank page.
page(1,3,0,4,4,entries,{["2"]=true,["3"]=true,["4"]=true,["5"]=true},4,8,1)
entries[4].destroyed=true
page(1,3,0,4,4,entries,{["5"]=true},4,8,1)
entries[4].destroyed=nil
entries[5].attackOnly=true
page(1,3,0,4,4,entries,{["5"]=true},4,8,1)
entries[5].attackOnly=nil
entries[2].name="Long Apocalypse Dragon Head"
entries[6].name="Much Longer Offscreen Apocalypse Dragon Name"
local visibleWidth=layout.nameColumnWidth(entries,{[2]={leader=1}},0,4)
assert(visibleWidth==nameWidth("+ "..entries[2].name),"Visible joined name includes prefix")
assert(visibleWidth<nameWidth(entries[6].name),"Offscreen enemy does not widen visible page")
assert(layout.nameColumnWidth(entries,{},0,0)==74,"Empty page uses minimum name width")
assert(entries[4].destroyed==nil and entries[5].attackOnly==nil,"Pagination does not mutate entries")
print("Compact combat column layout regressions passed")

-- Proxy Movement report: base card is a value, not a +bonus.
-- Run from repo root: lua5.2 tools/test-proxy-movement-report.lua
local function read(path)
    local f=assert(io.open(path,"r"))
    local content=f:read("*a")
    f:close()
    return content
end
local function slice(source,first,last)
    local a=assert(source:find(first,1,true),"Missing "..first)
    local b=assert(source:find(last,a+#first,true),"Missing "..last)
    return source:sub(a,b-1)
end
local source=read("src/PlayingGame/AI/Proxy.lua")
local beginCode=slice(source,"function proxyTurnReportBegin(objective,colors,baseMove,shieldMove,sourceMove)",
    "function proxyTurnReportSetTarget(target)")
local actionCode=slice(source,"function proxyLocalizedAction(action)",
    "function proxyTurnReportText(section)")
local renderCode=slice(source,"function proxyTurnReportText(section)",
    "--Return the logical Portal hex")
local sourceCode=slice(source,"function proxyRerollSourceManaGUID(guid,color)",
    "function proxyHexHasOtherHero(hex,proxyIndex)")

-- The real project localises each fragment before combining it.
local function english(parts)
    local result={}
    for _,part in ipairs(parts) do
        local value=tostring(part)
        result[#result+1]=value:match("{en}(.-){it}")
            or value:match("^{en}(.*)") or value
    end
    return table.concat(result)
end
local shared=read("src/Shared.lua")
local langCode=slice(shared,"local JOIN_LANG_ORDER=",
    "--Reapply translated static UI text once at load")
local sharedEnv=setmetatable({},{__index=_G})
assert(load(langCode,"Shared language helpers","t",sharedEnv))()

local env={
    gStates={proxyState="ReadyToEnd"},
    translateWord={White="White",Gold="Gold"},
    gameCardType=function(card) return card.cardType end,
    proxyCardDisplayName=function() return "Test Card" end,
    proxyLocalizedTerm=function(term) return term end,
    proxyLocalizedReason=function() return "The nearest legal objective" end,
    proxyLocalizedColorList=function(colors) return colors end,
    joinLang=english,
    joinLangAppendSentenceSuffix=sharedEnv.joinLangAppendSentenceSuffix
}
setmetatable(env,{__index=_G})
local functions=assert(load(beginCode.."\n"..actionCode.."\n"..renderCode.."\nreturn proxyTurnReportBegin,proxyLocalizedAction,proxyTurnReportText",
    "Proxy movement report","t",env))
local begin,localizedAction,render=functions()
env.proxyLocalizedAction=localizedAction
local examples={
    {type="Starting",base=1,expected="Move: 1 (Start Card: 1)."},
    {type="Starting",base=2,expected="Move: 2 (Unique Card: 2)."},
    {type="Advanced Action",base=2,expected="Move: 2 (Offer Card: 2)."},
    {type="Spell",base=1,expected="Move: 1 (Offer Card: 1)."},
    {type="Starting",base=1,shields=2,source=true,
        expected="Move: 4 (Start Card: 1, Shield +2, Source +1)."},
    {type="Starting",base=2,shields=1,source=true,
        expected="Move: 4 (Unique Card: 2, Shield +1, Source +1)."},
    {type="Advanced Action",base=2,shields=3,source=true,
        expected="Move: 6 (Offer Card: 2, Shield +3, Source +1)."}
}
for _,test in ipairs(examples) do
    begin({cardType=test.type},{},test.base,test.shields or 0,test.source==true)
    local text=render()
    assert(text:find(test.expected,1,true),
        "Expected "..test.expected.." in "..text)
end
-- Existing saves must also display the new labels without reconstructing
-- the saved objective card or altering the movement total.
local oldLabels={
    ["Starter Card +1"]="Start Card: 1",
    ["Unique Basic Action +2"]="Unique Card: 2",
    ["Advanced Action +2"]="Offer Card: 2",
    ["Card +1"]="Offer Card: 1",
    ["Card +2"]="Offer Card: 2"}
for old,new in pairs(oldLabels) do
    env.gStates.proxyTurnReport={
        objective="Saved Card",colors="",moved=0,allowance=2,
        baseReason=old,baseMove=2}
    local result=render()
    assert(result:find("Move: 2 ("..new..").",1,true),
        "Old saved movement label not migrated: "..old)
end
-- Offer results should read naturally without the internal card type.
begin({cardType="Starting"},{"White"},1,1,false)
env.gStates.proxyTurnReport.moved=2
env.gStates.proxyTurnReport.action="took Scouts from the offer"
local offerResult=render()
assert(offerResult:find("Proxy moved 2 spaces and\ntook Scouts from the offer.",1,true),
    "Proxy offer text was not rendered correctly: "..offerResult)
assert(not offerResult:find("rolled a Source die.",1,true),
    "Source reroll was reported even though no die was rolled")

-- Destination wording distinguishes a reached site from an unfinished route;
-- a Source reroll remains part of the movement sentence.
begin({cardType="Starting"},{"Green"},1,1,true)
env.gStates.proxyTurnReport.moved=2
env.gStates.proxyTurnReport.target="Dungeon"
env.gStates.proxyTurnReport.reachedTarget=false
env.gStates.proxyTurnReport.sourceRerollColor="White"
local incomplete=render("headline")
assert(incomplete=="Proxy moved 2 spaces toward the Dungeon, and rolled a Source die.",
    "Unfinished destination wording was incorrect: "..incomplete)
assert(not incomplete:find("did not reach",1,true),"Incomplete routes should not include a redundant warning")
env.gStates.proxyTurnReport.reachedTarget=true
local arrived=render("headline")
assert(arrived=="Proxy moved 2 spaces to the Dungeon, and rolled a Source die.",
    "Reached destination should use 'to', not 'toward': "..arrived)

-- Destination and offer-taking are separate clauses; with a reroll the
-- joining "and" should only appear at the final clause.
env.gStates.proxyTurnReport.action="took Scouts from the offer"
local arrivedAndTook=render("headline")
assert(arrivedAndTook=="Proxy moved 2 spaces to the Dungeon,\ntook Scouts from the offer, and rolled a Source die.",
    "Destination/action/reroll wording was incorrect: "..arrivedAndTook)
env.gStates.proxyTurnReport.sourceRerollColor=nil
assert(render("headline")=="Proxy moved 2 spaces to the Dungeon and\ntook Scouts from the offer.",
    "Reached destination and action should join without a reroll")

-- Combat against a rampager en route does not imply the objective was reached.
env.gStates.proxyTurnReport.reachedTarget=false
env.gStates.proxyTurnReport.action="defeated the rampaging Orc"
assert(render("headline")=="Proxy moved 2 spaces toward the Dungeon and\ndefeated the rampaging Orc.",
    "En-route combat incorrectly implied destination arrival")
env.gStates.proxyTurnReport.moved=0
env.gStates.proxyTurnReport.action=nil
assert(render("headline")=="Proxy did not move toward the Dungeon.",
    "No-movement case should not claim the Proxy moved")

-- A saved report from before this change may carry the obsolete sentence
-- as its action. Treat it as route context rather than repeat the movement.
env.gStates.proxyTurnReport.moved=2
env.gStates.proxyTurnReport.action="moved toward the Dungeon\nbut did not reach it"
assert(render("headline")=="Proxy moved 2 spaces toward the Dungeon.",
    "Legacy unfinished route action was repeated")
env.gStates.proxyTurnReport.target=nil
assert(render("headline")=="Proxy moved 2 spaces toward the Dungeon.",
    "Legacy report should recover the destination from its action")

-- Only a successful Source reroll amends the first sentence. The report
-- still tracks the original die colour internally, even though no separate
-- colour line is shown.
local rollCount=0
local die={randomize=function() rollCount=rollCount+1 end}
env.GUID={zone={mana="source-zone"}}
env.getObjectFromGUID=function(guid) if guid=="die" then return die end end
env.apocalypseQuestManaDieColor=function() return "White" end
env.onObjectRandomize=function() end
env.proxySourceManaOptions=function() return {{guid="die",color="White"}},nil end
local loadSource=assert(load(sourceCode.."\nreturn proxyRerollSourceManaGUID,proxyUseSourceMana",
    "Proxy Source reroll","t",env))
local reroll,useSource=loadSource()
assert(reroll("not-a-die","White")==false,"Missing Source die should not be rerolled")
assert(env.gStates.proxyTurnReport.sourceRerollColor==nil,"Failed reroll was reported")
assert(reroll("die","White")==true,"Available Source die should reroll")
assert(rollCount==1,"Source die should be rolled once")
assert(env.gStates.proxyTurnReport.sourceRerollColor=="White","Rerolled die colour was not recorded")
assert(render():find("and rolled a Source die.",1,true),
    "Source reroll should be part of the first sentence")
assert(not render():find("Source die rerolled:",1,true),
    "Source reroll should no longer be a separate line")

-- While a route is being chosen, the first sentence is past tense even
-- before the destination is reached. The reroll is joined to that sentence.
begin({cardType="Starting"},{"Red"},1,0,true)
env.gStates.proxyState="PickRoute"
env.gStates.proxyTurnReport.target="Mage Tower"
env.gStates.proxyTurnReport.sourceRerollColor="Gold"
local headline=render("headline")
local details=render("details")
assert(headline=="Proxy moved toward the Mage Tower, and rolled a Source die.",
    "Proxy route/reroll first sentence was incorrect: "..headline)
assert(headline:find("Objective:",1,true)==nil and headline:find("Move:",1,true)==nil,
    "Headline should not include the smaller detail labels")
assert(details:find("Objective: Red",1,true) and
    details:find("Move: 2 (Start Card: 1, Source +1).",1,true),
    "Objective and movement breakdown must be separate: "..details)
assert(render():find(headline.."\n\n"..details,1,true),
    "Default report must preserve the full combined text")
env.gStates.proxyState="ReadyToEnd"

-- An automatic reroll precedes report creation; the extra return value preserves the event.
env.gStates.proxyTurnReport=nil
local used,choices,rolledColor=useSource({"White"})
assert(used==true and choices==nil and rolledColor=="White",
    "Automatic Source reroll colour was not returned for the new report")
assert(rollCount==2,"Automatic Source reroll should roll exactly once")
-- Production localisation emits all language tags, unlike the English
-- helper above. Verify that appending the Source die sentence preserves those
-- tags and joins punctuation correctly for English and Chinese.
local translatedEnv={
    gStates={proxyState="PickRoute"},
    translateWord={Gold="Gold"},
    gameCardType=env.gameCardType,
    proxyCardDisplayName=env.proxyCardDisplayName,
    proxyLocalizedTerm=env.proxyLocalizedTerm,
    proxyLocalizedReason=env.proxyLocalizedReason,
    proxyLocalizedColorList=env.proxyLocalizedColorList
}
setmetatable(translatedEnv,{__index=_G})
local taggedFunctions=assert(load(langCode.."\n"..beginCode.."\n"
    ..actionCode.."\n"..renderCode
    .."\nreturn proxyTurnReportBegin,proxyLocalizedAction,proxyTurnReportText",
    "Proxy multilingual report","t",translatedEnv))
local taggedBegin,taggedAction,taggedRender=taggedFunctions()
translatedEnv.proxyLocalizedAction=taggedAction
taggedBegin({cardType="Starting"},{"Red"},1,0,true)
translatedEnv.gStates.proxyTurnReport.target="Mage Tower"
translatedEnv.gStates.proxyTurnReport.sourceRerollColor="Gold"
local tagged=taggedRender("headline")
local function languageFragment(text,lang)
    -- Language tags contain hyphens (zh-cn, pt-br); Lua patterns would
    -- interpret '-' as a repetition operator, not a literal separator.
    local marker="{"..lang.."}"
    local start=text:find(marker,1,true)
    if start==nil then return nil end
    local from=start+#marker
    local nextTag=text:find("{",from,true)
    return text:sub(from,nextTag~=nil and nextTag-1 or #text)
end
assert(languageFragment(tagged,"en")=="Proxy moved toward the Mage Tower, and rolled a Source die.",
    "Localised English headline has misplaced punctuation")
assert(languageFragment(tagged,"zh-cn"):find("，并重掷了一颗魔力源骰。",1,true),
    "Chinese Source reroll suffix missing from translated sentence")
assert(languageFragment(tagged,"it"):find("e ha ritirato un dado della Fonte.",1,true),
    "Italian Source reroll suffix missing from translated sentence")
assert(not renderCode:find("joinLangParse(",1,true),
    "Proxy report called module-private joinLangParse instead of its public helper")

-- Smaller report details use their own Text16 element, not runtime XML tags.
-- This avoids modifying the shared Volkare/Dummy font or writing unsafe markup
-- to a saved Global UI.
local panel=read("src/PlayingGame/UI.lua")
local panelXml=read("src/UI/MainGame.xml")
assert(panelXml:find('id="DummyDetails" class="Text16"',1,true),
    "Proxy detail font should use the smaller Text16 class")
assert(panel:find('proxyTurnReportText("headline")',1,true)
    and panel:find('proxyTurnReportText("details")',1,true)
    and panel:find('UI.setAttribute("DummyDetails","active"',1,true),
    "Proxy panel should independently render headline and detail text")

print("Proxy movement, offer, and Source reroll summary regressions passed")

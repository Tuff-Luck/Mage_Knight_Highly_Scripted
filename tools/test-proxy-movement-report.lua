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
local renderCode=slice(source,"function proxyTurnReportText()",
    "--Return the logical Portal hex")

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
local env={
    gStates={proxyState="ReadyToEnd"},
    gameCardType=function(card) return card.cardType end,
    proxyCardDisplayName=function() return "Test Card" end,
    proxyLocalizedTerm=function(term) return term end,
    proxyLocalizedReason=function() return "The nearest legal objective" end,
    proxyLocalizedColorList=function(colors) return colors end,
    joinLang=english
}
setmetatable(env,{__index=_G})
local functions=assert(load(beginCode.."\n"..renderCode.."\nreturn proxyTurnReportBegin,proxyTurnReportText",
    "Proxy movement report","t",env))
local begin,render=functions()
local examples={
    {type="Starting",base=1,expected="Movement: 1 (Start Card: 1)."},
    {type="Starting",base=2,expected="Movement: 2 (Unique Card: 2)."},
    {type="Advanced Action",base=2,expected="Movement: 2 (Offer Card: 2)."},
    {type="Spell",base=1,expected="Movement: 1 (Offer Card: 1)."},
    {type="Starting",base=1,shields=2,source=true,
        expected="Movement: 4 (Start Card: 1, Shield +2, Source +1)."},
    {type="Starting",base=2,shields=1,source=true,
        expected="Movement: 4 (Unique Card: 2, Shield +1, Source +1)."},
    {type="Advanced Action",base=2,shields=3,source=true,
        expected="Movement: 6 (Offer Card: 2, Shield +3, Source +1)."}
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
    assert(result:find("Movement: 2 ("..new..").",1,true),
        "Old saved movement label not migrated: "..old)
end
print("Proxy movement breakdown label regressions passed")

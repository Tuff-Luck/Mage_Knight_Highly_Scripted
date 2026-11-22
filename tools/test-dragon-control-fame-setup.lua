-- Regression coverage for reporter 466: Dragon Control's nil Fame and setup state swaps.
-- Run from the repository root: lua5.2 tools/test-dragon-control-fame-setup.lua
local function read(path)
    local handle=assert(io.open(path,"r"))
    local source=handle:read("*a")
    handle:close()
    return source
end
local function section(source,first,last)
    local a=assert(source:find(first,1,true),"missing "..first)
    local b=assert(source:find(last,a+#first, true),"missing "..last)
    return source:sub(a,b-1)
end
local function equal(actual,expected,label)
    assert(actual==expected, label..": expected "..tostring(expected)..", got "..tostring(actual))
end

local dragon=read("src/PlayingGame/ApocalypseDragon.lua")
local constructorSource=section(dragon,"function apocalypseDragonMonsterData(", "--Refresh the persistent small head token stats.")
local dragonEnv=setmetatable({
    apocalypseDragonCurrentLevelData=function(head)
        if head=="Control" then return {attack={M={4}},arcaneImmunity=true} end
        if head=="Famine" then return {fame=1,armour=2,attack={P={3}}} end
        return nil
    end,
    apocalypseDragonCopyAttack=function(value) return value end,
},{__index=_G})
local construct=assert(load(constructorSource.."\nreturn apocalypseDragonMonsterData","dragon-fame","t",dragonEnv))()
local control=construct("Control",4)
equal(control.fame,0,"Control without printed Fame")
equal(control.dragonHeadLevel,4,"Control level retained")
equal(control.arcaneImmunity,true,"Control special ability retained")
equal(construct("Famine",4).fame,1,"Famine printed Fame retained")
equal(construct("Unknown",4),nil,"Unknown head still absent")

-- Exercise both Fame-calculator expressions with an older runtime record whose fame is nil.
local ui=read("src/PlayingGame/UI.lua")
local cases=0
for expression in ui:gmatch("local questFame=([^\r\n]+)") do
    cases=cases+1
    local env=setmetatable({
        monsterPugs={test={name="Control",fame=nil}},
        obj={guid="test"},a="test",perks=0,
    },{__index=_G})
    local calculate=assert(load("return "..expression,"fame-expression","t",env))
    equal(calculate(),0,"Fame calculator nil guard "..cases)
    env.perks=2
    equal(calculate(),2,"Fame calculator perk "..cases)
end
equal(cases,2,"Both UI Fame paths checked")

local setup=read("src/SetupGame/Players.lua")
local lockSource=section(setup,"local function playerSetupLockReferenceState(", "local function playerSetupMageBag(")
local current,notices={},{}
local setupEnv=setmetatable({
    getObjectFromGUID=function(guid) return current[guid] end,
    print=function(message) notices[#notices+1]=message end,
},{__index=_G})
local lockReference=assert(load(lockSource.."\nreturn playerSetupLockReferenceState","reference-setup","t",setupEnv))()
local function card(guid,result)
    local obj={guid=guid,locked=false}
    obj.lock=function() obj.locked=true end
    obj.setState=function(state) obj.requested=state;return result end
    return obj
end
local alternative=card("new")
local original=card("reference",alternative)
lockReference(original,1,"Skill Reference Card 2")
equal(original.requested,1,"Competitive reference chooses state 1")
equal(alternative.locked,true,"Switched reference locked")

local unavailable=card("missing-state",nil)
current[unavailable.guid]=unavailable
lockReference(unavailable,1,"Skill Reference Card 2")
equal(unavailable.locked,true,"Failed switch locks original reference")
assert(#notices==1 and notices[1]:find("Skill Reference Card 2",1,true),
    "Failed switch must leave a useful warning")

local volkareSide=card("return-state")
local volkare=card("volkare",volkareSide)
lockReference(volkare,2,"Volkare Scenario Reference")
equal(volkare.requested,2,"Volkare references request state 2")
equal(volkareSide.locked,true,"Volkare swapped reference locked")

local plain=card("plain")
lockReference(plain,nil,"Plain Reference")
equal(plain.requested,nil,"Non-switching references stay in place")
equal(plain.locked,true,"Non-switching references are locked")
lockReference(nil,1,"Missing Reference")
equal(#notices,2,"Missing reference is reported without throwing")

assert(setup:find('playerSetupLockReferenceState(ob,1,"Skill Reference Card 2")',1,true))
assert(setup:find('playerSetupLockReferenceState(ob,2,"Volkare Scenario Reference")',1,true))
print("Dragon Control Fame and setup reference-state regressions passed")

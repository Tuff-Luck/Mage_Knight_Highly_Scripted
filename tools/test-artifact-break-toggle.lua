-- Run at repository root: lua5.2 tools/test-artifact-break-toggle.lua
local function read(path)
    local file=assert(io.open(path,"r"))
    local content=file:read("*a")
    file:close()
    return content
end
local function section(content,a,b)
    local start=assert(content:find(a,1,true),"missing "..a)
    local finish=assert(content:find(b,start+#a,true),"missing "..b)
    return content:sub(start,finish-1)
end
local rec=read("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local flow=read("src/PlayingGame/PlayerBoard/CardFlow.lua")
local callbacks=read("src/PlayingGame/Callbacks.lua")
local cards={a={cardType="Artifact"},b={cardType="Artifact"},
    half={cardType="Artifact",full="full"},full={cardType="Artifact",half="half"}}
local objs={a={guid="a",is_face_down=false},b={guid="b",is_face_down=true},
    half={guid="half",is_face_down=true},full={guid="full",is_face_down=false}}
local state={}
local env=setmetatable({gStates=state,gameCards=cards,
    getObjectFromGUID=function(guid) return objs[guid] end},{__index=_G})
local source=section(rec,"function resourceCardsArtifactBroken(guid,card)",
    "-- Persist one-shot Banner uses through save/rewind")
local broken,clear=assert(load(source.."\nreturn resourceCardsArtifactBroken,resourceCardsArtifactBreakClear",
    "artifact state","t",env))()
assert(not broken("a",objs.a),"Basic face-up Artifact is not broken")
state.artifactBreaks={a=true,full=true}
assert(broken("a",objs.a) and broken("full",objs.full),
    "Face-up Staff and full Banner can be broken")
state.artifactBreaks.a=false
assert(not broken("a",objs.a),"Basic selection must override Break")
assert(broken("b",objs.b) and state.artifactBreaks.b==true,
    "Legacy face-down Artifact imports its Break flag")
objs.b.is_face_down=false
assert(broken("b",objs.b),"Break survives turning legacy Artifact face up")
assert(not broken("half",objs.half),"Spent half Banner must never Break")
clear("full")
assert(not broken("full",objs.full),"Cleanup must clear the saved Break choice")

local linked=section(rec,"local function linkedColorChoices(rule,targetGUID,powered)",
    "-- Powered One with the Land")
local colourCards={r={color={"Red"}},b={color={"Blue"}},
    w={color={"White"}},g={color={"Green"}},dual={color={"Red","Blue"}}}
local colorEnv=setmetatable({gameCards=colourCards,
    trackerPrivate={basicActionColors={"Red","Blue","White","Green"}}},{__index=_G})
local choose=assert(load(linked.."\nreturn linkedColorChoices",
    "linked Staff choices","t",colorEnv))()
local staff={linkedColorEffects={normal={Red={other=1},Blue={other=1},
    White={other=1},Green={healing=3}}}}
for _,test in ipairs({{"r","red"},{"b","blue"},{"w","white"},{"g","green"}}) do
    local options=choose(staff,test[1],false)
    assert(#options==1 and options[1].key==test[2],
        "Staff choice must retain linked colour "..test[2])
end
local dual=choose(staff,"dual",false)
assert(#dual==2 and dual[1].key=="red" and dual[2].key=="blue",
    "Dual-coloured cards must retain both Staff options")
local keySource=section(rec,"local function choiceCategory(choice)",
    "local function choiceHasTargetableCombatResource(")
local key=assert(load(keySource.."\nreturn choiceCategory","choice category","t",{}))()
assert(key(nil)==nil and key(false)==nil,"Missing choices cannot cause nil indexing")
assert(key({key="red",other=1})=="red","Explicit colour takes priority")

for _,needle in ipairs({
    "trackerPrivate.artifactBreakButton=function",
    "function resourceCardsArtifactBreakClicked(",
    "xml[#xml+1]=trackerPrivate.artifactBreakButton(card,false",
    "xml[#xml+1]=trackerPrivate.artifactBreakButton(card,#xml>otherControlCount",
    "or (isStrong and rule.strongNoDiscard==true)",
    "and second~=nil and choiceCategory(second)~=firstKey",
    'local redReady=type(resources)=="table" and not combatEnemyInPlay',
    'return second~=nil and first~=second and (first=="red" or second=="red")',
    "if type(choices)~=\"table\" or #choices==0 then return nil,nil end"
}) do
    assert(rec:find(needle,1,true),"Missing Staff/Break path: "..needle)
end
assert(not rec:find('choices={{key="red",icon="other"}}',1,true),
    "Blue and White must never be rewritten as Red")
assert(flow:find("artifactBroken=resourceCardsArtifactBroken(card.guid,card)",1,true),
    "End-turn cleanup must use explicit Break state")
assert(flow:find("resourceCardsArtifactBreakClear(card.guid)",1,true),
    "Cleanup must retire Break state")
assert(callbacks:find('"resourceCardsArtifactBreakClicked"',1,true),
    "Protected Break callback must be registered")
print("Artifact Break and Druidic Staff regression checks passed")

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
local key=assert(load(keySource.."\nreturn choiceCategory","choice category","t",
    setmetatable({},{__index=_G})))()
assert(key(nil)==nil and key(false)==nil,"Missing choices cannot cause nil indexing")
assert(key({key="red",other=1})=="red","Explicit colour takes priority")

-- The printed-rule action moves between opposite card edges, and its
-- shorter caption fits with padding using the bundled MKCardText font.
do
    local selected=false
    local blocked=false
    local card={guid="abc"}
    local testEnv=setmetatable({
        trackerPrivate={},
        gameCards={abc={resourceKey="artifactDruidicStaff"}},
        resourceCardsArtifactBroken=function() return selected end,
        combatEnemyInPlay=false
    },{__index=_G})
    local toggleSource=section(rec,"trackerPrivate.artifactBreakButton=function",
        "-- Shift only the Artifact's")
    local button=assert(load(toggleSource.."\nreturn trackerPrivate.artifactBreakButton",
        "artifact toggle display","t",testEnv))()
    local normal=button(card,"0 0 180","-35")
    assert(normal.attributes.position=="0 140 -35" and normal.value=="THROW",
        "THROW must sit below the card text")
    assert(normal.attributes.height==74 and normal.attributes.width==220,
        "Artifact button must be about four-fifths the previous height")
    assert(normal.attributes.padding=="18 18 9 9",
        "Artifact button text needs interior padding")
    assert(normal.attributes.font=="Fonts/MKCardText"
        and normal.attributes.resizeTextForBestFit=="true"
        and normal.attributes.resizeTextMinSize==26
        and normal.attributes.resizeTextMaxSize==58,
        "Artifact button text must use shrinking MKCardText")
    selected=true
    local strong=button(card,"0 0 180","-35")
    assert(strong.attributes.position=="0 -140 -35" and strong.value=="RECOVER",
        "RECOVER must sit above the artwork")
    testEnv.combatEnemyInPlay=true
    selected=false
    local waiting=button(card,"0 0 180","-35")
    assert(waiting.attributes.position=="0 140 -35" and waiting.value=="WAIT",
        "Blocked THROW must stay at the lower edge")
end

-- Raise each new Artifact option/target by half its rendered height, without
-- moving unrelated controls, the toggle itself, or other cards' UI.
do
    local testEnv={trackerPrivate={}}
    local raiseSource=section(rec,"trackerPrivate.raiseArtifactChoiceControls=function",
        "-- A manual counter")
    local raise=assert(load(raiseSource.."\nreturn trackerPrivate.raiseArtifactChoiceControls",
        "artifact control lift","t",testEnv))()
    local function ui(tag,id,pos,height)
        return {tag=tag,attributes={id=id,position=pos,height=height,scale="0.25 0.25"}}
    end
    local xml={
        ui("Button","ResourceCardChoice_abc_old","0 -12 -35",90),
        ui("Button","ResourceCardChoice_abc_0","0 -12 -35",90),
        ui("Button","AttackAssignmentSource_abc_0_block","40 -12 -35",90),
        ui("Text","ResourceCardChoice_abc_label0","-80 -12 -35",90),
        ui("Button","ResourceCardChoice_abc_artifactBreak","0 140 -35",74),
        ui("Button","ResourceCardChoice_xyz_0","0 -12 -35",90),
        ui("Button","ResourceCardChoice_abc_healAllUnits","145 -145 -35",85)}
    raise(xml,2,"abc")
    local function y(node)
        return tonumber(node.attributes.position:match("^%S+%s+(%S+)"))
    end
    assert(y(xml[1])==-12 and y(xml[2])==-23.25
        and y(xml[3])==-23.25 and y(xml[4])==-23.25,
        "New choices, targets and their labels must rise by 11.25 UI units")
    assert(y(xml[5])==140 and y(xml[6])==-12 and y(xml[7])==-145,
        "Do not move Throw/Recover, unrelated controls, or edge-anchored buttons")
end

for _,needle in ipairs({
    "trackerPrivate.artifactBreakButton=function",
    "function resourceCardsArtifactBreakClicked(",
    "xml[#xml+1]=trackerPrivate.artifactBreakButton(card,uiRotation,depth)",
    "xml[#xml+1]=trackerPrivate.artifactBreakButton(card,uiRotation,buttonDepth)",
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
-- Exercise Mysterious Box's real cleanup branch. An unresolved normal Box
-- stays in play, but the same face-up Box must go to Trash once broken.
do
    local disposed,brokenByGUID={},{}
    local box={guid="085e69",type="Card",is_face_down=false}
    local trash={putObject=function(card) disposed[#disposed+1]=card.guid end}
    local cleanupEnv=setmetatable({
        gStates={bannercard={}},turnOrder={{deadDeckInventory={}}},
        gameCards={["085e69"]={cardType="Artifact",resourceKey="artifactUtility"}},
        trashCan="trash",getObjectFromGUID=function(guid)
            return guid=="trash" and trash or nil end,
        isQuestCardObject=function(card) return false end,
        cardEffectIsVertical=function(card) return true end,
        resourceCardsArtifactBroken=function(guid) return brokenByGUID[guid]==true end,
        resourceCardsArtifactBreakClear=function(guid) brokenByGUID[guid]=nil end
    },{__index=_G})
    local cleanupSource=section(flow,"function cleanupPlayedCardAtEndTurn(",
        "local MEDITATION_BUTTON_SUFFIXES")
    local cleanup=assert(load(cleanupSource.."\nreturn cleanupPlayedCardAtEndTurn",
        "Mysterious Box cleanup","t",cleanupEnv))()
    cleanup(box,1,nil)
    assert(#disposed==0,"Normal unresolved Mysterious Box must stay in play")
    brokenByGUID[box.guid]=true
    cleanup(box,1,nil)
    assert(#disposed==1 and disposed[1]==box.guid,
        "Face-up broken Mysterious Box must be thrown away")
    assert(brokenByGUID[box.guid]==nil,
        "Mysterious Box Break state must be retired on cleanup")
end

-- Exercise the real Grail count callback, including clamping, right-click,
-- and rejection when the card is broken or its basic side is unavailable.
do
    local state={turnNumber=1,artifactGrailHealingUsed={}}
    local grail={guid="085e59",is_face_down=false}
    local record={complete=true,powered=false}
    local refreshes=0
    local env=setmetatable({
        gStates=state,
        gameCards={["085e59"]={cardType="Artifact",resourceKey="artifactGoldenGrail"}},
        turnOrder={{seatPos=1}},
        resourceCardScanBySeat={[1]={cards={["085e59"]=record}}},
        getObjectFromGUID=function(guid) return guid=="085e59" and grail or nil end,
        cardPosture=function(card) return "upright" end,
        cardInSeatPlayArea=function(guid,seat) return seat==1 end,
        resourceCardsPanelOpen=function() return true end,
        resourceCardsDetailsOpen=function() return true end,
        resourceCardsPlayerCanEdit=function(color) return color=="Blue" end,
        resourceCardsArtifactBroken=function() return state.broken==true end,
        combatConfig={phaseObjectLocked=function(guid) return false end},
        resourceCardsSourceChanged=function() refreshes=refreshes+1 end
    },{__index=_G})
    local clickSource=section(rec,"function resourceCardsArtifactGrailFameClicked(",
        "-- Toggle the strong effect")
    local click=assert(load(clickSource.."\nreturn resourceCardsArtifactGrailFameClicked",
        "Grail fame counter","t",env))()
    local id="ResourceCardChoice_085e59_grailFame"
    for i=1,3 do click({color="Blue"},"-1",id) end
    assert(state.artifactGrailHealingUsed[grail.guid]==2,
        "Grail Fame must be capped at its two basic Heal points")
    click({color="Blue"},"-2",id)
    assert(state.artifactGrailHealingUsed[grail.guid]==1,
        "Right-click must decrement confirmed Heal spend")
    state.broken=true
    click({color="Blue"},"-1",id)
    assert(state.artifactGrailHealingUsed[grail.guid]==1,
        "Broken Grail must not earn the basic-side Fame")
    state.broken=false
    record.powered=true
    click({color="Blue"},"-1",id)
    assert(state.artifactGrailHealingUsed[grail.guid]==1,
        "A powered record cannot alter the basic Fame count")
    assert(refreshes==4,"Only four legal Grail counter clicks should redraw")
end

-- Structural checks for paths involving the combat calculator, Unit history,
-- and the 25 official Artifact cards (full Banner forms included).
for _,needle in ipairs({
    "-- A face-up broken Sword/Bow has no basic discard-payment ability.",
    "and resourceCardsArtifactBroken(source.guid,source)) then",
    "local boxBroken=card.guid==\"085e69\"",
    "and not boxBroken",
    "trackerPrivate.grailFameButton=function",
    "function resourceCardsArtifactGrailFameClicked(",
    "used*rule.grailFamePerHealing",
    "unitHistoryCancelReadySource(entry.key)",
    "if gStates.unitReadyLinks[entry.key]==nil then",
    "and not combatEnemyInPlay and not combatCalcOn",
    "or type(id)~=\"string\" or combatCalcOn or combatEnemyInPlay",
    "if not broken and combatEnemyInPlay then",
    'key=="artifactBannerCourage"',
    'key=="artifactBannerFortitude"',
    ":ENEMY_PRESENT:",
    "resourceCardsArtifactGrailFameClicked=resourceCardsArtifactGrailFameClicked"
}) do
    assert(rec:find(needle,1,true) or flow:find(needle,1,true),
        "Missing Artifact fix or regression guard: "..needle)
end
assert(callbacks:find('"resourceCardsArtifactGrailFameClicked"',1,true),
    "Grail Fame callback must be included in protected startup audit")

print("Artifact Break, Mysterious Box, Golden Grail and Druidic Staff regression checks passed")

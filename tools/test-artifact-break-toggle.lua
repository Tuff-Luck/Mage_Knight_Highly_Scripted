package.path="src/?.lua;"..package.path
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
local actionLinks=read("src/PlayingGame/PlayerBoard/ResourceTracker/ActionLinks.lua")
local cardControls=read("src/PlayingGame/PlayerBoard/ResourceTracker/CardControls.lua")
local playedCards=read("src/PlayingGame/PlayerBoard/ResourceTracker/PlayedCardScan.lua")
local cardInteraction=read("src/PlayingGame/PlayerBoard/ResourceTracker/CardInteraction.lua")
local readyPolicy=read("src/PlayingGame/PlayerBoard/ResourceTracker/ReadyPolicy.lua")
local unitScan=read("src/PlayingGame/PlayerBoard/ResourceTracker/UnitScan.lua")
local callbacks=read("src/PlayingGame/Callbacks.lua")
local events=read("src/PlayingGame/PlayerBoard/Events.lua")
local runtimeEvents=read("src/PlayingGame/Events.lua")
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
-- Manual face-down still means THROW when the tracker is closed, even if
-- RECOVER had previously saved false. Flipping back restores that choice.
objs.a.is_face_down=true
assert(broken("a",objs.a),"Manual face-down overrides a saved RECOVER")
assert(state.artifactBreaks.a==false,
    "A temporary physical flip must not erase saved RECOVER")
objs.a.is_face_down=false
assert(not broken("a",objs.a),"Turning face up restores the saved RECOVER")
assert(broken("b",objs.b) and state.artifactBreaks.b==nil,
    "Manual face-down Artifact is thrown without saving a permanent toggle")
objs.b.is_face_down=false
assert(not broken("b",objs.b),
    "Turning a manually thrown Artifact face up must undo the throw")
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
local key=require("PlayingGame.PlayerBoard.ResourceTracker.ResourceChoices")({},function() return {} end,{},nil).choiceCategory
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
    local testEnv={trackerPrivate={},type=type,tostring=tostring,tonumber=tonumber,math=math}
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
    assert(rec:find(needle,1,true) or cardControls:find(needle,1,true)
        or playedCards:find(needle,1,true) or readyPolicy:find(needle,1,true)
        or unitScan:find(needle,1,true),"Missing Staff/Break path: "..needle)
end
assert(not rec:find('choices={{key="red",icon="other"}}',1,true),
    "Blue and White must never be rewritten as Red")
assert(flow:find("and resourceCardsThrowAwayReason(card) or nil",1,true),
    "End-turn cleanup must use the shared throw-away verdict")
assert(flow:find("resourceCardsArtifactBreakClear(card.guid)",1,true),
    "Cleanup must retire Break state")
assert(callbacks:find('"resourceCardsArtifactBreakClicked"',1,true),
    "Protected Break callback must be registered")
-- A full Banner in the Unit attachment area may convert only on its
-- basic/Recovered side. The stronger Throw side now remains face up.
do
    local conversions,scales,moves,refreshes=0,0,0,0
    local z=-38.0
    objs.full.getPosition=function() return {12,1,z} end
    objs.full.setState=function(index)
        assert(index==2,"Full Banner must convert to its half-card state")
        conversions=conversions+1
    end
    local halfCard={
        setScale=function(scale)
            assert(scale[1]==0.65,"Attached Banner must use half scale")
            scales=scales+1
        end,
        setPosition=function(pos)
            assert(pos[1]==12 and pos[3]==-38.12,
                "Attached Banner must enter the Unit attachment area")
            moves=moves+1
        end
    }
    local testEnv=setmetatable({
        obj=objs.full,objGUID="full",zoneInfo={seatPos=1},gameCards=cards,
        resourceCardsArtifactBroken=broken,
        getObjectFromGUID=function(guid)
            return guid=="half" and halfCard or nil
        end,
        safeWaitFrames=function(owner,callback,frames)
            assert(owner=="PlayerBoard.Events" and frames==3)
            callback()
        end,
        scheduleUnitLayoutRefresh=function(seat)
            assert(seat==1)
            refreshes=refreshes+1
        end
    },{__index=_G})
    local convertSource=section(events,"--Toggle Half Cards","--Add command decal")
    local convert=assert(load("return function()\n"..convertSource.."\nend",
        "Banner attachment conversion","t",testEnv))()

    state.artifactBreaks.full=true
    convert()
    assert(conversions==0,"Thrown face-up full Banner must not reattach")

    state.artifactBreaks.full=false
    convert()
    assert(conversions==1 and scales==1 and moves==1 and refreshes==1,
        "Recovered face-up full Banner must still attach normally")

    objs.full.is_face_down=true
    convert()
    assert(conversions==1,
        "A physically face-down full Banner must not attach")
    objs.full.is_face_down=false
    z=-39
    convert()
    assert(conversions==1,
        "A full Banner outside the attachment area must not convert")
    state.artifactBreaks.full=nil
end

-- Exercise Mysterious Box's real cleanup branch. An unresolved normal Box
-- stays in play, but the same face-up Box must go to Trash once broken.
do
    local disposed,brokenByGUID={},{}
    local box={guid="085e69",type="Card",is_face_down=false}
    local trash={putObject=function(card) disposed[#disposed+1]=card.guid end}
    local cleanupEnv=setmetatable({
        gStates={bannercard={}},trackerPrivate={},turnOrder={{deadDeckInventory={}}},
        gameCards={["085e69"]={cardType="Artifact",resourceKey="artifactUtility"}},
        trashCan="trash",getObjectFromGUID=function(guid)
            return guid=="trash" and trash or nil end,
        isQuestCardObject=function(card) return false end,
        cardEffectIsVertical=function(card) return true end,
        resourceCardsArtifactBroken=function(guid) return brokenByGUID[guid]==true end,
        resourceCardsArtifactBreakClear=function(guid) brokenByGUID[guid]=nil end
    },{__index=_G})
    -- Load the real shared verdict so this covers the current cleanup path,
    -- not the independently loaded legacy fallback.
    local verdictSource=section(rec,"function resourceCardsThrowAwayReason(card)",
        "-- The last End Turn click")
    assert(load(verdictSource,"Shared throw-away verdict","t",cleanupEnv))()
    local cleanupSource=section(flow,"function cleanupPlayedCardAtEndTurn(",
        "local MEDITATION_BUTTON_SUFFIXES")
    local cleanup=assert(load(cleanupSource.."\nreturn cleanupPlayedCardAtEndTurn",
        "Mysterious Box cleanup","t",cleanupEnv))()
    assert(cleanupEnv.resourceCardsThrowAwayReason(box)==nil,
        "Recovered face-up Box has no throw-away verdict")
    cleanup(box,1,nil)
    assert(#disposed==0,"Normal unresolved Mysterious Box must stay in play")
    brokenByGUID[box.guid]=true
    assert(cleanupEnv.resourceCardsThrowAwayReason(box)=="artifact",
        "Explicit Throw choice must reach the shared verdict")
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
env.trackerPrivate=env.trackerPrivate or {}
env.trackerPrivate.cardInteraction=assert(loadfile("src/PlayingGame/PlayerBoard/ResourceTracker/CardInteraction.lua","t",env))()
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
    "and resourceCardsArtifactBroken(source.guid,source)) then"
}) do
    assert(actionLinks:find(needle,1,true),
        "Missing ActionLinks Artifact discard guard: "..needle)
end
for _,needle in ipairs({
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
    assert(rec:find(needle,1,true) or flow:find(needle,1,true) or cardControls:find(needle,1,true)
        or playedCards:find(needle,1,true) or readyPolicy:find(needle,1,true)
        or unitScan:find(needle,1,true) or cardInteraction:find(needle,1,true),
        "Missing Artifact fix or regression guard: "..needle)
end
assert(callbacks:find('"resourceCardsArtifactGrailFameClicked"',1,true),
    "Grail Fame callback must be included in protected startup audit")


-- Physical flips never change the saved choice and never allow a stale
-- Throw/Recover click from the back. Both clicks work again once face up.
do
    local toggleState={turnNumber=1,artifactBreaks={a=true}}
    local artifact={guid="a",is_face_down=true}
    local refreshes,marks=0,{}
    local env=setmetatable({
        gStates=toggleState,gameCards={a={cardType="Artifact",resourceKey="artifactUtility"}},
        trackerPrivate={},choiceExpandedByGUID={},
        turnOrder={{seatPos=1}},combatEnemyInPlay=false,
        combatConfig={phaseObjectLocked=function(guid) return false end},
        getObjectFromGUID=function(guid) return guid=="a" and artifact or nil end,
        resourceCardsPanelOpen=function() return true end,
        resourceCardsDetailsOpen=function() return true end,
        resourceCardsPlayerCanEdit=function(color) return color=="Blue" end,
        cardPosture=function(card) return "upright" end,
        cardInSeatPlayArea=function(guid,seat) return guid=="a" and seat==1 end,
        resourceCardsArtifactBroken=function(guid,card)
            return card.is_face_down==true or toggleState.artifactBreaks[guid]==true
        end,
        resourceCardsMaximalEffectMark=function(card,active) marks[#marks+1]=active end,
        resourceCardsSourceChanged=function() refreshes=refreshes+1 end
    },{__index=_G})
env.trackerPrivate=env.trackerPrivate or {}
env.trackerPrivate.cardInteraction=assert(loadfile("src/PlayingGame/PlayerBoard/ResourceTracker/CardInteraction.lua","t",env))()
    local source=section(rec,"function resourceCardsArtifactBreakClicked(",
        "-- Player clicks always")
    local click=assert(load(source.."\nreturn resourceCardsArtifactBreakClicked",
        "face-down Artifact click guard","t",env))()
    local id="ResourceCardChoice_a_artifactBreak"
    click({color="Blue"},"-1",id)
    assert(toggleState.artifactBreaks.a==true and refreshes==0 and #marks==0,
        "A stale face-down RECOVER must do nothing")
    artifact.is_face_down=false
    click({color="Blue"},"-1",id)
    assert(toggleState.artifactBreaks.a==false and marks[#marks]==false,
        "Face-up RECOVER must undo the red X")
    click({color="Blue"},"-1",id)
    assert(toggleState.artifactBreaks.a==true and marks[#marks]==true,
        "Face-up THROW must restore the red X")
    artifact.is_face_down=true
    click({color="Blue"},"-1",id)
    assert(toggleState.artifactBreaks.a==true and refreshes==2,
        "A flipped artifact cannot silently alter its saved Throw state")
end

-- The marker itself is a TTS button. It must disappear from the back while
-- retaining the saved state, and return on the front without another click.
do
    local markState={artifactBreaks={a=true}}
    local artifact={guid="a",is_face_down=false}
    local marks={}
    local env=setmetatable({
        trackerPrivate={},gameCards={a={cardType="Artifact"}},
        resourceCardsArtifactBroken=function(guid,card)
            return card.is_face_down==true or markState.artifactBreaks[guid]==true
        end,
        resourceCardsMaximalEffectMark=function(card,active) marks[#marks+1]=active end,
        resourceCardsPanelOpen=function() return true end
    },{__index=_G})
    local source=section(rec,"function resourceCardsMaximalEffectSyncMarks(",
        "-- Cleanup and the UI consult")
    local sync=assert(load(source.."\nreturn resourceCardsMaximalEffectSyncMarks",
        "Artifact flip marker reconciliation","t",env))()
    sync(1,{artifact},{})
    artifact.is_face_down=true
    sync(1,{artifact},{})
    artifact.is_face_down=false
    sync(1,{artifact},{})
    assert(marks[1]==true and marks[2]==false and marks[3]==true
        and markState.artifactBreaks.a==true,
        "The face-up X must return after an accidental flip")
    markState.artifactBreaks.a=false
    artifact.is_face_down=true
    sync(1,{artifact},{})
    artifact.is_face_down=false
    sync(1,{artifact},{})
    assert(marks[4]==false and marks[5]==false,
        "A recovered card must stay recovered when flipped twice")
end

-- With the tracker closed there may be no Maximal Effect link or existing
-- marker, but Artifact flips still need physical red-X reconciliation.
do
    local reconciles=0
    local artifact={guid="a",type="Card",resting=true,
        isSmoothMoving=function() return false end}
    local zone={getObjects=function() return {artifact} end}
    local env=setmetatable({
        gStates={firstStarted=true,preEndTurn=false,turnNumber=1},
        gameCards={a={cardType="Artifact"}},turnOrder={{seatPos=1}},
        playerPlayAreas={"zone"},trackerPrivate={},
        resourceCardsPanelOpen=function() return false end,
        getObjectFromGUID=function(guid)
            return guid=="zone" and zone or (guid=="a" and artifact or nil)
        end,
        safeWaitCondition=function(owner,callback,condition,timeout,onTimeout)
            assert(condition(),"The artifact must be settled before resync")
            callback()
        end,
        resourceCardsMaximalEffectSyncMarks=function(seat,cards)
            assert(seat==1 and cards[1]==artifact)
            reconciles=reconciles+1
        end
    },{__index=_G})
    local source=section(rec,"function resourceCardsMaximalEffectOffDrop(",
        "-- Generic Skill-card links")
    local refresh=assert(load(source.."\nreturn resourceCardsMaximalEffectOffDrop",
        "Artifact flip while tracker closed","t",env))()
    refresh(artifact)
    assert(reconciles==1,"OFF-mode Artifact flip must restore its marker")
end

assert(cardControls:find('if data~=nil and data.cardType=="Artifact" and card.is_face_down==true then',1,true),
    "All Artifact resource controls must disappear when face down")
assert(runtimeEvents:find("resourceCardsObjectMoved(card,true)",1,true)
    and runtimeEvents:find("resourceCardsMaximalEffectOffDrop(card)",1,true),
    "Rotating an Artifact must rescan the final face even without a drop")

print("Artifact Throw/Recover, flip and Artifact regression checks passed")

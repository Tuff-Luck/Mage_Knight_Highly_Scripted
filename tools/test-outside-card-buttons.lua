-- Shared card-edge controls and actual payment gating for Meditation / Trance.
local function read(path)
    local f=assert(io.open(path,"r"))
    local s=f:read("*a")
    f:close()
    return s
end
local function section(s,a,b)
    local first=assert(s:find(a,1,true),a)
    return s:sub(first,assert(s:find(b,first+#a,true),b)-1)
end
dofile("src/PlayingGame/Interface/UIAssets.lua")
local ui=read("src/PlayingGame/Interface/UI.lua")
local flow=read("src/PlayingGame/PlayerBoard/CardFlow.lua")
local xml={}
local card={guid="2eb8d0",type="Card",is_face_down=false,UI={}}
card.getRotation=function() return {0,180,0} end
local paid,strong=false,false
local env=setmetatable({
    gStates={},turnOrder={{seatPos=1}},playerPlayAreas={"play"},deedDeckDiscardZones={"discard"},
    meditationTranceCardGUID=card.guid,
    getObjectFromGUID=function(id)
        if id==card.guid then return card end
        if id=="play" then return {getObjects=function() return {card} end} end
        if id=="discard" then return {getObjects=function() return {{guid="cost",type="Card"}} end} end
    end,
    cardEffectIsVertical=function(obj) return obj~=nil and not obj.is_face_down end,
    resourceCardsBrowserSpellValid=function(_seat,_guid) return paid,strong end,
    objectUIRemoveSuffixes=function(_card,_suffixes) xml={} end,
    objectUIWithoutSuffixes=function(_card,_suffixes) return {} end,
    resourceObjectUiSameXML=function(_old,_new) return false end,
    resourceObjectUiXmlTable=function(_ui) return xml end,
    resourceObjectUiSetTable=function(_ui,new) xml=new end
},{__index=_G})
assert(load(section(ui,"function createClaimButton(","-- Player colour and board presentation controls"),"claim buttons","t",env))()
-- Use the actual dynamically loaded builder, not the global mock signature.
---@type fun(objGUID: string, source: string, controlID?: string): table
local claimButton=assert(rawget(env,"createClaimButton"))
local top=claimButton(card.guid,"meditationTop")
local draw=claimButton("cure","cureDraw")
assert(draw.attributes.id=="ResourceCardChoice_CureDraw","Cure must retain its tracker control ID")
assert(claimButton("cure","cureDraw","customDraw").attributes.id=="customDraw",
    "Explicit control ID overrides remain supported")
assert(draw.attributes.width==top.attributes.width and draw.attributes.height==top.attributes.height
    and draw.attributes.scale==top.attributes.scale,"Draw 1 must not change shared dimensions")
assert(draw.children[1].attributes.id==draw.attributes.id.."Image","Pressed artwork ID must match callback ID")
-- Real mouse-down/up handlers must resolve both old GUID-first IDs and
-- resource tracker IDs without changing the IDs used by gameplay callbacks.
do
    local active="Sliced Button/Button Object Active"
    local pressed="Sliced Button/Button Object Deactive"
    local objects={}
    local animationEnv=setmetatable({
        getObjectFromGUID=function(guid) return objects[guid] end
    },{__index=_G})
    assert(load(section(ui,"local function legacyObjectButtonImage(","buttonImageResetGeneration={}"),
        "Object button animation","t",animationEnv))()
    for _,entry in ipairs({
        {"2eb8d0",top},
        {"47e71c",draw},
        {"085e59",createOutsideCardButton("ResourceCardChoice_085e59_artifactBreak",
            "global/resourceCardsArtifactBreakClicked","THROW",artifactActionButtonPosition(false,"-35"))},
        {"085e59",createOutsideCardButton("ResourceCardChoice_085e59_grailFame",
            "global/resourceCardsArtifactGrailFameClicked","F 0/2",sideActionButtonPosition(1,"-35"))},
        {"123abc",createOutsideCardButton("AttackAssignmentSource_123abc_0_unitReady",
            "global/attackAssignmentReadySourceClicked","RDY",sideActionButtonPosition(1,"-35"))}
    }) do
        local guid,button=entry[1],entry[2]
        local id=button.attributes.id
        assert(button.attributes.onMouseDown=="global/ButtonClickDown"
            and button.attributes.onMouseUp=="global/ButtonClickUp","Use explicit down/up callbacks")
        local image=active
        local writes=0
        objects[guid]={UI={
            getAttribute=function(key,attr)
                assert(key==id.."Image" and attr=="image")
                return image
            end,
            setAttribute=function(key,attr,value)
                assert(key==id.."Image" and attr=="image")
                image=value
                writes=writes+1
            end
        }}
        animationEnv.ButtonClickDown(nil,"-1",id)
        assert(image==pressed,"Mouse-down presses "..id)
        animationEnv.ButtonClickDown(nil,"-1",id)
        assert(image==pressed,"Repeated down must not toggle to active")
        animationEnv.ButtonClickUp(nil,"-1",id)
        assert(image==active,"Mouse-up releases "..id)
        animationEnv.ButtonClickUp(nil,"-1",id)
        assert(image==active,"Repeated up must not toggle to pressed")
        -- Right-click inputs (e.g. subtracting Grail Fame) use the same artwork.
        animationEnv.ButtonClickDown(nil,"-2",id)
        assert(image==pressed,"Right mouse-down presses "..id)
        animationEnv.ButtonClickDown(nil,"-2",id)
        assert(image==pressed,"Repeated right down stays pressed")
        animationEnv.ButtonClickUp(nil,"-2",id)
        assert(image==active,"Right mouse-up releases "..id)
        animationEnv.ButtonClickUp(nil,"-2",id)
        assert(image==active,"Repeated right up stays released")
        local beforeIgnored=writes
        animationEnv.ButtonClickDown(nil,"-3",id)
        animationEnv.ButtonClickUp(nil,"-3",id)
        assert(writes==beforeIgnored,"Other mouse buttons must not animate")
        image=nil
        local previous=writes
        animationEnv.ButtonClickUp(nil,"-1",id)
        animationEnv.ButtonClickUp(nil,"-2",id)
        assert(writes==previous,"Removed control must not receive a stale image write")
    end
end
assert(draw.children[2].children[1].attributes.resizeTextForBestFit=="true","Fit long labels")
assert(draw.attributes.position==sideActionButtonPosition(1)
    and top.attributes.position==sideActionButtonPosition(1),
    "Single and upper spell actions share the same slot")
for _,entry in ipairs({
    {"meditationBot",2},{"tranceTop",4},{"tranceBot",5},
    {"steadyTempoDiscard",1},{"steadyTempoBot",3},{"steadyTempoTop",5}
}) do
    assert(claimButton(card.guid,entry[1]).attributes.position==sideActionButtonPosition(entry[2]),
        "Spell action must use its shared slot: "..entry[1])
end
local x,y=sideActionButtonPosition(1):match("^(%S+) (%S+)")
local x2,y2=sideActionButtonPosition(2,"-35"):match("^(%S+) (%S+)")
local x3,y3=sideActionButtonPosition(3):match("^(%S+) (%S+)")
assert(x==x2 and x==x3 and tonumber(y2)-tonumber(y)==tonumber(y3)-tonumber(y2),
    "All side slots share horizontal alignment and uniform vertical spacing")
local cardControls=read("src/PlayingGame/PlayerBoard/ResourceTracker/Interface/CardControls.lua")
local lift=assert(cardControls:find("trackerPrivate.raiseArtifactChoiceControls(xml,otherControlCount+1,card.guid)",1,true))
local side=assert(cardControls:find('sideActionButtonPosition(3,buttonDepth)',lift,true))
assert(lift<side,"Artifact artwork lift must precede fixed side action placement")
assert(load(section(flow,"local function meditationPlayerIndex(","--Card-effect controls")
    ..section(flow,"local MEDITATION_BUTTON_SUFFIXES","local function meditationContainerIsDeedDeck"),
    "Meditation payment gating","t",env))()
env.refreshMeditationTrance()
assert(#xml==0 and env.gStates.meditationTranceState==nil,"Unpaid Meditation is inert")
paid=true
env.refreshMeditationTrance()
assert(#xml==2 and xml[1].attributes.id==card.guid.."meditationTop","Paid basic cast shows buttons")
paid=false
env.refreshMeditationTrance()
assert(#xml==0,"Removing casting mana hides buttons")
paid,strong=true,true
env.refreshMeditationTrance()
assert(#xml==0 and env.gStates.meditationTranceState.mode=="trance","Strong cast waits for chosen cards")
env.gStates.meditationTranceState.accepted={"cost"}
env.refreshMeditationTrance()
assert(#xml==2 and xml[1].attributes.id==card.guid.."tranceTop","Completed paid Trance shows buttons")
strong=false
env.refreshMeditationTrance()
assert(#xml==0,"Trance selection cannot resolve after losing strong payment")
print("Outside card buttons and Meditation payment tests passed")

-- Maximal Effect red-X lifecycle: physical links, undo, flip and cleanup.
-- Run from repo root: lua5.2 tools/test-maximal-effect-markers.lua
local function read(path)
    local file=assert(io.open(path,"r"))
    local content=file:read("*a")
    file:close()
    return content
end
local function extract(source,startMarker,endMarker)
    local a=assert(source:find(startMarker,1,true),"Missing "..startMarker)
    local b=assert(source:find(endMarker,a+1,true),"Missing "..endMarker)
    return source:sub(a,b-1)
end
local function eq(actual,expected,message)
    assert(actual==expected,message..": expected "..tostring(expected)
        ..", got "..tostring(actual))
end
local function card(guid,x)
    local c={guid=guid,type="Card",is_face_down=false,x=x,buttons={},scale={1.5,1,1.5}}
    c.getButtons=function()
        local buttons={}
        for i,b in ipairs(c.buttons) do
            buttons[i]={index=i-1,click_function=b.click_function,
                label=b.label,font_size=b.font_size}
        end
        return buttons
    end
    c.createButton=function(button)
        c.buttons[#c.buttons+1]=button
    end
    c.removeButton=function(index)
        table.remove(c.buttons,index+1)
    end
    c.getBoundsNormalized=function() return {size={x=1,y=0.1,z=1}} end
    c.getScale=function() return c.scale end
    c.getPosition=function() return {x,1,0} end
    c.setScale=function(value) c.scale=value end
    c.setRotation=function() end
    c.setPosition=function() end
    c.getGMNotes=function() return "" end
    return c
end
local maximal=card("8fac50",0)
local training=card("6fdeb0",0.3)
local ordinary=card("a11111",6)
local objects={[maximal.guid]=maximal,[training.guid]=training,
    [ordinary.guid]=ordinary}
local zone={getObjects=function()
    return {maximal,training}
end}
local trashed={}
local trash={putObject=function(target)
    eq(#target.getButtons(),0,"Red X removed before trashing")
    trashed[#trashed+1]=target.guid
end}
objects.zone=zone
objects.trash=trash
local env={
    Global={},trackerPrivate={},combatConfig={cardInTransit=function() return false end},
    gStates={firstStarted=true,turnNumber=1},
    turnOrder={{seatPos=1,deadDeckInventory={"8fac50","6fdeb0","a11111"}}},
    playerPlayAreas={[1]="zone"},trashCan="trash",
    resourceCardScanBySeat={},
    gameCards={
        ["8fac50"]={cardType="Advanced Action",resourceKey="maximalEffect"},
        ["6fdeb0"]={cardType="Advanced Action",resourceKey="training"},
        ["a11111"]={cardType="Starting",resourceKey="stamina"}
    },
    cardResourceDefinitions={
        maximalEffect={requiredLink={mode="repeat",normalCount=3,poweredCount=2}}
    },
    getObjectFromGUID=function(id) return objects[id] end,
    resourceCardsPanelOpen=function() return false end,
    cardPosture=function() return "upright" end,
    footprint=function(obj) return {x=obj.x,z=0,halfX=1,halfZ=1} end,
    overlapArea=function(a,b)
        return math.max(0,math.min(a.x+a.halfX,b.x+b.halfX)
            -math.max(a.x-a.halfX,b.x-b.halfX))
    end,
    manaColor=function(obj) return obj.color end,
    matchesCardMana=function(_,color) return color=="Red" end,
    isQuestCardObject=function() return false end
}
setmetatable(env,{__index=_G})
local reader=read("src/PlayingGame/PlayerBoard/CardRecognition.lua")
local code=extract(reader,
    "function resourceCardsMaximalEffectMarkerNoop()",
    "-- Generic Skill-card links")
local methods=assert(load(code..[[
return {
    mark=resourceCardsMaximalEffectMark,
    marked=resourceCardsMaximalEffectMarked,
    link=resourceCardsMaximalEffectLink,
    sync=resourceCardsMaximalEffectSyncMarks,
    beforeEnd=resourceCardsMaximalEffectBeforeEndTurn
}]],"Maximal Effect marks","t",env))()
eq(methods.link(1,training.guid).count,3,"Physical OFF link finds three basic uses")

-- Artifacts use the same existing red X, driven by the saved Throw state.
-- Recover removes it; repeated recalculation must not duplicate the marker.
local artifact=card("af0001",7)
objects[artifact.guid]=artifact
env.gameCards[artifact.guid]={cardType="Artifact",resourceKey="artifactUtility"}
local artifactThrown=false
env.resourceCardsArtifactBroken=function(guid)
    return guid==artifact.guid and artifactThrown
end
methods.sync(1,{artifact},{})
eq(methods.marked(artifact),false,"Unthrown Artifact has no X")
artifactThrown=true
methods.sync(1,{artifact},{})
eq(methods.marked(artifact),true,"THROW puts an X on a face-up Artifact")
eq(#artifact.getButtons(),1,"Thrown Artifact has one red X")
eq(artifact.buttons[1].font_size,640,"Artifact uses the same red X")
methods.sync(1,{artifact},{})
eq(#artifact.getButtons(),1,"Repeated Artifact scan does not duplicate X")
artifactThrown=false
methods.sync(1,{artifact},{})
eq(methods.marked(artifact),false,"RECOVER removes Artifact X")

-- Training's offer browser must recognise the same repeated effect even
-- with the Resource Tracker minimized, and regardless of the linked flip.
env.resourceCardsMaximalEffectLink=methods.link
local trainingMode=assert(load(extract(reader,
    "function resourceCardsTrainingMode(seatPos)",
    "-- Used by Steady Tempo")..
    "\nreturn resourceCardsTrainingMode","Training OFF mode","t",env))()
local basicTraining,basicUses=trainingMode(1)
eq(basicTraining,false,"Unpowered copied Training")
eq(basicUses,3,"Training has three uses while OFF")
methods.sync(1,{maximal,training},{[training.guid]={count=3,powered=false}})
eq(methods.marked(training),true,"Linked card displays red X")
eq(#training.getButtons(),1,"Only one X")
eq(training.buttons[1].label,"X","Matches Unit red-X style")
eq(training.buttons[1].font_size,640,"Matches Unit X size")
methods.sync(1,{maximal,training},{[training.guid]={count=3,powered=false}})
eq(#training.getButtons(),1,"Repeated scan does not duplicate X")
training.is_face_down=true
methods.sync(1,{maximal,training},{[training.guid]={count=3,powered=false}})
training.is_face_down=false
eq(methods.marked(training),true,"Flip face up retains X")
methods.sync(1,{maximal,training},{})
eq(methods.marked(training),false,"Removing link clears X")

local mana={guid="mana1",color="Red",getPosition=function() return {0,1,0} end}
zone.getObjects=function() return {maximal,training,mana} end
local strong=methods.link(1,training.guid)
eq(strong.count,2,"Powered OFF link gives two uses")
eq(strong.powered,true,"Powered copy is strong")
local poweredTraining,strongUses=trainingMode(1)
eq(poweredTraining,true,"Powered copied Training while OFF")
eq(strongUses,2,"Training's two stronger uses while OFF")
training.is_face_down=true
local flippedTraining,flippedUses=trainingMode(1)
eq(flippedTraining,true,"Thrown-away Training still powered")
eq(flippedUses,2,"Face-down Training retains two uses")
training.is_face_down=false
zone.getObjects=function() return {maximal,training} end

-- Cleanup consumes a marked face-up Action instead of returning it to
-- the discard pile. Unmarked Actions still use the normal discard branch.
methods.beforeEnd(1)
eq(methods.marked(training),true,
    "End Turn rehydrates red X from physical OFF link before cleanup")
local flow=read("src/PlayingGame/PlayerBoard/CardFlow.lua")
local cleanup=extract(flow,"function cleanupPlayedCardAtEndTurn(",
    "local MEDITATION_BUTTON_SUFFIXES=")
env.resourceCardsMaximalEffectMarked=methods.marked
env.resourceCardsMaximalEffectMark=methods.mark
-- A copied Steady Tempo must be thrown away rather than retained for
-- its normal End Turn placement decision.
env.isSteadyTempoGUID=function(guid) return guid==training.guid end
env.cardEffectIsVertical=function() return true end
env.steadyTempoPrepare=function() error("Marked card must never be retained") end
local run=assert(load(cleanup.."\nreturn cleanupPlayedCardAtEndTurn",
    "End Turn red-X trash","t",env))()
eq(run(training,1,nil),nil,"Marked card does not seed discard")
eq(trashed[1],training.guid,"Marked face-up card was thrown away")
eq(methods.marked(training),false,"Trashed card cannot retain marker")
run(ordinary,1,nil)
eq(#trashed,1,"Unmarked face-up card not trashed")
ordinary.is_face_down=true
run(ordinary,1,nil)
eq(trashed[2],ordinary.guid,"Manually face-down card still thrown away")
print("Maximal Effect marker and cleanup regression passed")

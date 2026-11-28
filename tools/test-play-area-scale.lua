-- Play Area scale regression: loose Units scale like cards, army Units do not.
-- Run from repository root: lua5.2 tools/test-play-area-scale.lua
local function eq(actual,expected,label)
    if actual~=expected then
        error((label or "Mismatch")..": "..tostring(actual).." ~= "..tostring(expected),2)
    end
end
local function approx(actual,expected,label)
    if type(actual)~="number" or math.abs(actual-expected)>0.000001 then
        error((label or "Scale mismatch")..": "..tostring(actual).." ~= "..tostring(expected),2)
    end
end
local function fakeCard(guid,kind,area)
    local obj={guid=guid,kind=kind,area=area,type="Card",interactable=true,
        resting=true,held_by_color=nil,scale={1.5,1,1.5}}
    obj.getScale=function() return {obj.scale[1],obj.scale[2],obj.scale[3]} end
    obj.setScale=function(v) obj.scale={v[1],v[2],v[3]} end
    obj.getGMNotes=function() return "" end
    obj.hasTag=function(_tag) return false end
    obj.isSmoothMoving=function() return obj.smoothMoving==true end
    obj.getPosition=function() return obj.position or {0,1,0} end
    return obj
end
local loan=fakeCard("111111","unit","play")
local recruit=fakeCard("222222","unit","army")
local deed=fakeCard("333333","deed","play")
local command=fakeCard("444444","command","play")
local objs={["111111"]=loan,["222222"]=recruit,["333333"]=deed,["444444"]=command}
local zones={
    play={getBounds=function() return {center={0,1,0},size={10,1,10}} end,getObjects=function()
        local result={}
        for _,obj in pairs(objs) do if obj.area=="play" then result[#result+1]=obj end end
        return result
    end},
    army={getBounds=function() return {center={20,1,0},size={10,1,10}} end,getObjects=function()
        local result={}
        for _,obj in pairs(objs) do if obj.area=="army" then result[#result+1]=obj end end
        return result
    end}
}
getObjectFromGUID=function(guid) return objs[guid] or zones[guid] end
playerPlayAreas={"play"}
playerUnitAreas={"army"}
playerBoard={}
colorBand={}
unitLayoutIsUnit=function(obj) return obj.kind=="unit" end
unitLayoutIsCommand=function(obj) return obj.kind=="command" end
unitLayoutIsWound=function() return false end
gStates={playAreaScaleSettings={[1]={step=16,scope="Cards"}}}
publishPublicUICallbacks=function(callbacks)
    for name,fn in pairs(callbacks) do _G[name]=fn end
end
local frames,conditions={},{}
safeWaitFrames=function(_scope,callback,_count) frames[#frames+1]=callback end
safeWaitCondition=function(_scope,callback,predicate,_timeout,onTimeout)
    conditions[#conditions+1]={callback=callback,predicate=predicate,timeout=onTimeout}
end
local function runFrames()
    local queued=frames
    frames={}
    for _,callback in ipairs(queued) do callback() end
end
local function pollConditions()
    local queued=conditions
    conditions={}
    for _,check in ipairs(queued) do
        if check.predicate() then check.callback()
        else conditions[#conditions+1]=check end
    end
end
dofile("src/PlayingGame/PlayerBoard/Scale.lua")
refreshPlayAreaScale(1)
approx(loan.scale[1],1.2,"loose Unit scales in Play Area")
approx(deed.scale[1],1.2,"normal deed scales")
approx(recruit.scale[1],1.5,"recruited Unit stays full sized")
approx(command.scale[1],1.5,"Command token stays full sized")
loan.area="army"
refreshPlayAreaScale(1)
approx(loan.scale[1],1.5,"Unit restores natural size in Unit Area")
loan.area="play"
refreshPlayAreaScale(1)
approx(loan.scale[1],1.2,"Unit scales again on return to Play Area")
gStates.playAreaScaleSettings[1].step=20
refreshPlayAreaScale(1)
approx(loan.scale[1],1.5,"100 percent restores Unit")
gStates.playAreaScaleSettings[1].step=12
refreshPlayAreaScale(1)
approx(loan.scale[1],0.9,"60 percent scales Unit")
-- Call Offer returns a card to the Offer via playAreaScaleForgetObject
-- and sets the real offer card's original scale directly.
playAreaScaleForgetObject(loan)
loan.area="offer"
loan.setScale({1.5,1,1.5})
eq(gStates.playAreaScaledObjects[loan.guid],nil,"returned offer Unit has no stale scale factor")
approx(loan.scale[1],1.5,"returned offer Unit original scale")
-- A lifted object leaves the shallow zone; the drop callback can initially
-- report resting before the next physics frame. It must not grow in either path.
deed.area=nil
deed.position={12,5,0}
deed.held_by_color="Red"
refreshPlayAreaScale(1)
approx(deed.scale[1],0.9,"held object keeps its scale")
deed.held_by_color=nil
playAreaScaleObjectDropped(deed)
refreshPlayAreaScale(1)
approx(deed.scale[1],0.9,"drop frame keeps scale even with stale resting flag")
deed.resting=false
runFrames()
eq(#conditions,1,"one pending settle condition")
refreshPlayAreaScale(1)
pollConditions()
approx(deed.scale[1],0.9,"falling outside zone keeps reduced scale")
eq(#conditions,1,"refresh does not duplicate the pending check")
deed.position={0,1,0}
deed.area="play"
refreshPlayAreaScale(1)
deed.resting=true
pollConditions()
approx(deed.scale[1],0.9,"drop back in play area never grows")

-- An actual removal restores only after resting, including after a timeout.
deed.area=nil
deed.position={12,5,0}
deed.resting=false
playAreaScaleObjectDropped(deed)
runFrames()
local check=table.remove(conditions,1)
check.timeout()
approx(deed.scale[1],0.9,"timeout does not restore a moving object")
runFrames()
eq(#conditions,1,"timeout schedules another check")
deed.position={12,1,0}
deed.resting=true
pollConditions()
approx(deed.scale[1],1.5,"settled outside restores natural scale")
eq(gStates.playAreaScaledObjects[deed.guid],nil,"outside scale record cleared")
eq(#conditions,0,"settled removal finishes the check")

-- Scripted smooth moves also keep their size until arrival.
deed.area="play"
deed.position={0,1,0}
refreshPlayAreaScale(1)
deed.area=nil
deed.position={12,1,0}
deed.smoothMoving=true
refreshPlayAreaScale(1)
runFrames()
pollConditions()
approx(deed.scale[1],0.9,"scripted movement keeps reduced scale")
deed.smoothMoving=false
pollConditions()
approx(deed.scale[1],1.5,"scripted move restores on arrival")
-- Inspect the actual generated controls: both arrows animate, scope is a
-- raised text button, and the percentage remains a recessed read-only image.
do
    local xml={}
    local rebuilds=0
    local function findAttributes(id,nodes)
        for _,node in ipairs(nodes) do
            if node.attributes and node.attributes.id==id then return node.attributes end
            local child=findAttributes(id,node.children or {})
            if child then return child end
        end
    end
    local board={guid="abcdef",UI={
        getXmlTable=function() return xml end,
        setXmlTable=function(value) xml=value rebuilds=rebuilds+1 end,
        getAttribute=function(id,key) return assert(findAttributes(id,xml))[key] end,
        setAttribute=function(id,key,value) assert(findAttributes(id,xml))[key]=value end
    }}
    board.isDestroyed=function() return false end
    board.getButtons=function() return {} end
    board.getBounds=function() return {center={y=1},size={x=10,y=1,z=10}} end
    board.getPosition=function() return {x=0,y=1,z=0} end
    board.positionToLocal=function(pos) return {x=pos[1],z=pos[3]} end
    objs.abcdef=board
    playerBoard[1]=board.guid
    turnOrder={{seatPos=1}}
    turnOrderIndexAtSeat=function(seat) return seat==1 and 1 or nil end
    refreshPlayAreaScaleControls()
    eq(#xml,4,"scale control count")
    for _,i in ipairs({1,3}) do
        eq(xml[i].attributes.onMouseDown,"global/ButtonClickDownOverkill","arrow down")
        eq(xml[i].attributes.onMouseUp,"global/ButtonClickUpOverkill","arrow up")
    end
    eq(xml[2].tag,"Image","percentage is not clickable")
    eq(xml[2].attributes.image,"Overkill Text","percentage stays recessed")
    eq(xml[4].children[1].attributes.image,"Sliced Button/Button Object Active","scope is raised")
    eq(xml[4].attributes.onMouseDown,"global/ButtonClickDown","scope down")
    eq(xml[4].attributes.onMouseUp,"global/ButtonClickUp","scope up")
    local scopeScale=tonumber(xml[4].attributes.scale:match("^%S+"))
    approx(xml[4].attributes.width*scopeScale,130*0.08,"scope rendered width unchanged")
    approx(xml[4].attributes.height*scopeScale,90*0.08,"scope rendered height unchanged")
    eq(xml[4].attributes.width,260,"larger logical button")
    eq(xml[4].children[2].attributes.fontSize,72,"preserve rendered font size")
    local function arrow(i,enabled,direction)
        eq(xml[i].attributes.interactable,tostring(enabled),"arrow availability")
        eq(xml[i].children[1].attributes.image,"Overkill "..direction..(enabled and "" or " Deactive"),"arrow artwork")
        eq(xml[i].children[1].attributes.color,enabled and "#FFFFFF" or "#909090","arrow tint")
    end
    arrow(1,false,"Down")
    arrow(3,true,"Up")
    -- Authorised clicks exercise in-place state changes, not a UI rebuild.
    local hand={getValue=function() return 1 end}
    Hands={getHands=function() return {hand} end}
    gStates.handColors={"Red"}
    legalPlayerCheck=function(_color,_seatColor,_exception) return true end
    local player={color="Red"}
    local down,up="PlayAreaScale1OverkillDown","PlayAreaScale1OverkillUp"
    playAreaScaleDown(player,"-1",down)
    eq(gStates.playAreaScaleSettings[1].step,12,"lower bound unchanged")
    for _=1,8 do playAreaScaleUp(player,"-1",up) end
    arrow(1,true,"Down")
    arrow(3,false,"Up")
    eq(gStates.playAreaScaleSettings[1].step,20,"upper limit")
    eq(xml[2].children[1].attributes.text,"100%","percentage label")
    playAreaScaleUp(player,"-1",up)
    eq(gStates.playAreaScaleSettings[1].step,20,"upper bound unchanged")
    playAreaScaleDown(player,"-1",down)
    arrow(1,true,"Down")
    arrow(3,true,"Up")
    -- Changing scope must not change held arrow artwork.
    xml[1].children[1].attributes.image="Overkill Down Deactive"
    playAreaScaleScope(player,"-1","PlayAreaScale1Scope")
    eq(xml[1].children[1].attributes.image,"Overkill Down Deactive","preserve held arrow")
    eq(rebuilds,1,"no control XML rebuild on click")
end
print("Play Area scale regressions passed")

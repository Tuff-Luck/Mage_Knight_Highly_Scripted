-- Play Area scale regression: loose Units scale like cards, army Units do not.
-- Run from repository root: lua5.2 tools/test-play-area-scale.lua
local function eq(actual,expected,label)
    if actual~=expected then
        error((label or "Mismatch")..": "..tostring(actual).." ~= "..tostring(expected),2)
    end
end
local function fakeCard(guid,kind,area)
    local obj={guid=guid,kind=kind,area=area,type="Card",interactable=true,
        resting=true,held_by_color=nil,scale={1.5,1,1.5}}
    obj.getScale=function() return {obj.scale[1],obj.scale[2],obj.scale[3]} end
    obj.setScale=function(v) obj.scale={v[1],v[2],v[3]} end
    obj.getGMNotes=function() return "" end
    obj.hasTag=function() return false end
    obj.isSmoothMoving=function() return false end
    return obj
end
local loan=fakeCard("111111","unit","play")
local recruit=fakeCard("222222","unit","army")
local deed=fakeCard("333333","deed","play")
local command=fakeCard("444444","command","play")
local objs={["111111"]=loan,["222222"]=recruit,["333333"]=deed,["444444"]=command}
local zones={
    play={getObjects=function()
        local result={}
        for _,obj in pairs(objs) do if obj.area=="play" then result[#result+1]=obj end end
        return result
    end},
    army={getObjects=function()
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
dofile("src/PlayingGame/PlayerBoard/Scale.lua")
refreshPlayAreaScale(1)
eq(loan.scale[1],1.2,"loose Unit scales in Play Area")
eq(deed.scale[1],1.2,"normal deed scales")
eq(recruit.scale[1],1.5,"recruited Unit stays full sized")
eq(command.scale[1],1.5,"Command token stays full sized")
loan.area="army"
refreshPlayAreaScale(1)
eq(loan.scale[1],1.5,"Unit restores natural size in Unit Area")
loan.area="play"
refreshPlayAreaScale(1)
eq(loan.scale[1],1.2,"Unit scales again on return to Play Area")
gStates.playAreaScaleSettings[1].step=20
refreshPlayAreaScale(1)
eq(loan.scale[1],1.5,"100 percent restores Unit")
gStates.playAreaScaleSettings[1].step=12
refreshPlayAreaScale(1)
eq(loan.scale[1],0.9,"60 percent scales Unit")
-- Call Offer returns a card to the Offer via playAreaScaleForgetObject
-- and sets the real offer card's original scale directly.
playAreaScaleForgetObject(loan)
loan.area="offer"
loan.setScale({1.5,1,1.5})
eq(gStates.playAreaScaledObjects[loan.guid],nil,"returned offer Unit has no stale scale factor")
eq(loan.scale[1],1.5,"returned offer Unit original scale")
print("Play Area Unit scale regressions passed")

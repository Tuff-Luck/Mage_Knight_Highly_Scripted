-- Exercise the real Fame/Reputation service against missing markers and failures.
-- Run with: lua5.2 tools/test-fame-reputation.lua
local function check(name,cond)
	assert(cond,name)
	print("PASS "..name)
end
publishPublicUICallbacks=function(_) end
local errors,notices={},{}
log=function(message) errors[#errors+1]=message end
broadcastToAll=function(message) notices[#notices+1]=message end
local function keys(prefix)
	return setmetatable({},{__index=function(t,key)
		local value=prefix..tostring(key)
		rawset(t,key,value)
		return value
	end})
end
monsterPiles=keys("pile-")
cityModel=keys("city-")
volkare=keys("volkare-")
GUID={bag={discard=keys("discard-")},zone=keys("zone-")}
local objects={}
getObjectFromGUID=function(id) return objects[id] end
local function shield(guid,fail)
	local obj={guid=guid,position={0,1.5,0}}
	obj.isDestroyed=function() return false end
	obj.getPosition=function() return {obj.position[1],obj.position[2],obj.position[3]} end
	obj.setPosition=function(position)
		if fail and fail() then error("injected movement failure") end
		obj.position=position
	end
	return obj
end
local fameShield,repShield=shield("fame01"),shield("rep01")
objects.fame01=fameShield
objects.rep01=repShield
gStates={firstStarted=true,turnNumber=1,scoreIfLooped=100,blitz=0,rowLengthGainPerLevel=2,
	normalRowLength=4,rowsOnBoard=10,normalRowFameQuantity=2,
	positionMageKnight={[5]="Dummy"},fameRepCommitted={}}
turnOrder={{
	mage="Goldyx",seatPos=1,fameGUID="fame01",reputationGUID="rep01",
	fame=0,fameGain=2,scoreLoop=0,reputation=0,repGain=1
},{
	mage="Dummy",seatPos=5,fame=0,fameGain=0,scoreLoop=0,reputation=0,repGain=0
}}
normalCellAmount=2
cellGainPerLevel=2
leftOfFameBoard=0
heightOfFameBoard=10
topOfFameBoard=10
reputationTable={}
for n=-7,7 do reputationTable[n]={reputationPos={n,1.5,0}} end
recordPlayerFameChange=function(index,amount)
	local player=turnOrder[index]
	player.fame=player.fame+amount
	player.scoreLoop=math.max(0,math.floor(player.fame/gStates.scoreIfLooped))
end
refreshPlayerFameFromShield=function() return true end
uiMainUIUpdateBase=function(_,afterRefresh) if afterRefresh then afterRefresh(true) end end
dofile("src/PlayingGame/Combat.lua")
dofile("src/PlayingGame/FameReputation.lua")
check("physical reward commit succeeds",fameReputationApplyPlayerFameReputation(1)==true)
check("both markers updated and Fame totals committed",
	turnOrder[1].fame==2 and turnOrder[1].reputation==1 and gStates.fameRepCommitted[1].fame==2)
turnOrder[1].fameGain=4
turnOrder[1].repGain=2
fameReputationMainUIUpdate("test")
check("post-commit delta updates exactly once",turnOrder[1].fame==4
	and turnOrder[1].reputation==2 and gStates.fameRepCommitted[1].fame==4)
fameReputationMainUIUpdate("test")
check("unchanged values are not recommitted",turnOrder[1].fame==4)
objects.fame01=nil
turnOrder[1].fameGain=6
local oldFame=turnOrder[1].fame
fameReputationMainUIUpdate("test")
check("missing Fame marker preserves pending reward and commit baseline",
	turnOrder[1].fame==oldFame and turnOrder[1].fameGain==6
	and gStates.fameRepCommitted[1].fame==4)
check("missing marker identifies player and GUID",#errors==1
	and errors[1]:find("Goldyx",1,true)~=nil and errors[1]:find("fame01",1,true)~=nil)
fameReputationMainUIUpdate("test")
check("repeated UI refresh does not spam warnings",#errors==1 and #notices==1)
objects.fame01=fameShield
fameReputationMainUIUpdate("test")
check("restored marker allows pending delta to commit",
	turnOrder[1].fame==6 and gStates.fameRepCommitted[1].fame==6)
objects.rep01=nil
turnOrder[1].fameGain=7
fameReputationMainUIUpdate("test")
check("missing Reputation also blocks entire commit",
	turnOrder[1].fame==6 and gStates.fameRepCommitted[1].fame==6)
objects.rep01=repShield
check("virtual player without physical markers is not committed",
	fameReputationApplyPlayerFameReputation(2)==false and gStates.fameRepCommitted[2]==nil)
local previousFame,previousRep=turnOrder[1].fame,turnOrder[1].reputation
local oldFamePos,oldRepPos=fameShield.getPosition(),repShield.getPosition()
local fail=true
repShield.setPosition=function(position)
	if fail then error("injected movement failure") end
	repShield.position=position
end
local ok,err=pcall(fameReputationMainUIUpdate,"test")
check("failed physical operation propagates a diagnostic",not ok and tostring(err):find("injected movement failure",1,true)~=nil)
check("failure rolls back physical marker and logical totals",
	turnOrder[1].fame==previousFame and turnOrder[1].reputation==previousRep
	and fameShield.position[1]==oldFamePos[1] and fameShield.position[3]==oldFamePos[3]
	and repShield.position[1]==oldRepPos[1])
check("failure does not consume pending reward",turnOrder[1].fameGain==7 and gStates.fameRepCommitted[1].fame==6)
fail=false
fameReputationMainUIUpdate("test")
check("a failed commit does not leave synchronization suppressed",
	turnOrder[1].fame==7 and gStates.fameRepCommitted[1].fame==7)
print("Fame and Reputation commit regression tests passed.")

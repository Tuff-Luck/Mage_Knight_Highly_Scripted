-- Targeted SetupInterface callback tests. Run: lua5.2 tools/test-player-chosen.lua
-- TTS UI is mocked, while the real public callback implementations are loaded.
local attrs,callbacks={},{}
UI={
	setAttribute=function(id,key,value)
		attrs[id]=attrs[id] or {}
		attrs[id][key]=value
	end,
	getAttribute=function(id,key) return attrs[id] and attrs[id][key] end
}
local function check(label,condition)
	assert(condition,label)
	print("PASS "..label)
end
scenarioList={{"Conquest",scenarioDetails={}}}
customMages={}
translateWord=setmetatable({},{__index=function(_,key) return key end})
gStates={positionMageKnight={"nobody","nobody","nobody","nobody","nobody"},playerCount=0,coop=0,gameScenario="Conquest"}
local notices={}
broadcastToColor=function(message,color)
	notices[#notices+1]={message=message,color=color}
end
publishPublicUICallbacks=function(public)
	for name,func in pairs(public) do callbacks[name]=func end
end
refreshProxySetupLabel=function() end
dofile("src/SetupInterface.lua")
-- Replace the large presentation refresh with a no-op. Seat/count mutation remains
-- production code and uses the real recountSetupMageKnights helper.
for _,name in ipairs({"scenarioInfoUpdate","ToolTipUpdate"}) do
	local found=false
	for index=1,100 do
		local upvalue=debug.getupvalue(callbacks.PlayerChosen,index)
		if upvalue==nil then break end
		if upvalue==name then
			debug.setupvalue(callbacks.PlayerChosen,index,function() end)
			found=true
			break
		end
	end
	check("test hook "..name,found)
end
local blue={color="Blue"},red={color="Red"}
local function open(player,slot)
	callbacks.toggleDropDown(player,"-1",slot)
end
local function token(choiceId)
	local callback=attrs[choiceId] and attrs[choiceId].onClick
	assert(type(callback)=="string" and callback:match("^PlayerChosen%("), "missing bound selection callback")
	return assert(callback:match("^PlayerChosen%(([^)]+)%)$"))
end
local function choose(player,choiceId,clickToken)
	callbacks.PlayerChosen(player,clickToken or token(choiceId),choiceId)
end
open(blue,"firstMKSelection")
local firstToken=token("ArytheaSelection")
check("click includes first seat",firstToken:match("^mk1x")~=nil)
-- A second player cannot change the shared popup's target.
open(red,"secondMKSelection")
check("other player cannot hijack open selector",#notices==1 and token("ArytheaSelection")==firstToken)
choose(red,"ArytheaSelection",firstToken)
check("other player's selection ignored",gStates.positionMageKnight[1]=="nobody" and gStates.playerCount==0)
choose(blue,"ArytheaSelection",firstToken)
check("owner can select Mage",gStates.positionMageKnight[1]=="Arythea" and gStates.playerCount==1)
choose(blue,"ArytheaSelection",firstToken)
check("duplicate click ignored",gStates.positionMageKnight[1]=="Arythea" and gStates.playerCount==1)
open(blue,"secondMKSelection")
local secondToken=token("GoldyxSelection")
check("new open targets second seat",secondToken:match("^mk2x")~=nil and secondToken~=firstToken)
choose(blue,"WolfhawkSelection",firstToken)
check("old click cannot retarget new seat",gStates.positionMageKnight[2]=="nobody")
choose(blue,"GoldyxSelection",secondToken)
check("second seat assigned and recounted",gStates.positionMageKnight[2]=="Goldyx" and gStates.playerCount==2)
open(blue,"firstMKSelection")
local nobodyToken=token("nobodySelection")
choose(blue,"nobodySelection",nobodyToken)
check("nobody removes one real assignment",gStates.positionMageKnight[1]=="nobody" and gStates.playerCount==1)
open(blue,"firstMKSelection")
choose(blue,"nobodySelection")
check("repeated nobody does not decrement count",gStates.playerCount==1)
open(blue,"dummyMKSelection")
choose(blue,"WolfhawkSelection")
check("dummy affects coop but not playerCount",gStates.positionMageKnight[5]=="Wolfhawk" and gStates.playerCount==1 and gStates.coop==1)
open(blue,"fourthMKSelection")
local cancelled=token("NorowasSelection")
open(blue,"fourthMKSelection") -- closes the popup
choose(blue,"NorowasSelection",cancelled)
check("late click after closing ignored",gStates.positionMageKnight[4]=="nobody")
open(blue,"thirdMKSelection")
local invalid=token("KrangSelection")
choose(blue,"InvalidSelection",invalid)
check("unknown choice never writes state",gStates.positionMageKnight[3]=="nobody")
choose(blue,"KrangSelection",invalid)
check("valid choice still works after invalid callback",gStates.positionMageKnight[3]=="Krang" and gStates.playerCount==2)
print("PlayerChosen regression tests passed.")

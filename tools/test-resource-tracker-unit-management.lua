-- Exercise Command ownership/exhaustion and the actual extracted Ready payment pass.
local root="src/PlayingGame/PlayerBoard/ResourceTracker/"
local function eq(a,b,label) assert(a==b,label..": expected "..tostring(b)..", got "..tostring(a)) end
local retired={}
local env=setmetatable({gStates={currentRound=2},gameCards={},cardResourceDefinitions={},
    unitLayoutObjectInAnyUnitArea=function(guid) return guid=="present" end,
    resourceUnitsRetireUnit=function(guid) retired[#retired+1]=guid end}, {__index=_G})
local management=assert(loadfile(root.."Units/UnitManagement.lua","t",env))()
env.resourceUnitsSpentCommands=management.spentCommands
env.resourceUnitsSetCommandSpent=management.setCommandSpent
eq(management.commandSpent("token"),false,"Fresh Command")
management.setCommandSpent("token",true)
env.gStates.unitSpentCommandTokens.owners.token="present"
eq(management.adoptCommand("token","present",1,false),true,"Same Unit retains Command")
eq(management.commandSpent("token"),true,"Same Unit remains spent")
eq(management.adoptCommand("token","new",1,false),false,"Cannot steal existing Unit's Command")
env.gStates.unitSpentCommandTokens.owners.token="departed"
eq(management.adoptCommand("token","new",1,false),true,"Vacated Command can be adopted")
eq(retired[1],"departed","Old Unit retired")
eq(management.commandOwner("token"),"new","New owner recorded")
eq(management.commandSpent("token"),false,"New Unit is ready")
management.setCommandSpent("token",true)
env.gStates.currentRound=3
eq(management.commandSpent("token"),false,"New Round clears exhaustion")
eq(management.commandOwner("token"),nil,"New Round clears ownership")
env.gameCards={abc={resourceKey="ready"},one={level=1},two={level=2}}
env.cardResourceDefinitions.ready={readyWithInfluence={maxLevel=2,costPerLevel=2}}
env.gStates.unitReadyLinks={["abc#ready1"]={unitGUID="one"},["abc#ready2"]={unitGUID="two"}}
local cancelled={}
env.unitHistoryCancelReadySource=function(key)
    cancelled[#cancelled+1]=key
    env.gStates.unitReadyLinks[key]=nil
end
local scan=assert(loadfile(root.."Units/UnitScan.lua","t",env))()
local records={abc={complete=true,powered=true}}
local totals={influence=5}
local spent,rescan=scan.payReadyInfluence({records=records,totals=totals})
eq(spent,2,"First eligible Ready paid")
eq(totals.influence,3,"Only affordable Ready deducted")
eq(records.abc.readyInfluenceSpent,2,"Payment attributed to source")
eq(cancelled[1],"abc#ready2","Unaffordable second Ready cancelled")
eq(rescan,true,"Cancelled activation requests a new scan")
print("Unit management and Ready payment regressions passed")

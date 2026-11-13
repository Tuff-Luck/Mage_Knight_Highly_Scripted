-- Regression: missing optional tactic objects must never break end-of-turn claim refresh.
-- Run from repository root: lua5.2 tools/test-tactic-claim-refresh.lua
local file=assert(io.open("src/PlayingGame/PlayerBoard/Skills.lua","r"))
local source=file:read("*a")
file:close()
local start=assert(source:find("function claimButtonRefresh()",1,true))
local finish=assert(source:find("\nlocal function skillPositionCopy(",start,true))
local implementation=source:sub(start,finish-1)

local objects={}
local writes={}
local env={
    gStates={turnNumber=1,positionMageKnight={[5]="Dummy"},tacticShown=false,
        tacticRemove=false,discardTactics=0,preEndTurn=false},
    turnOrder={{mage="Hero"}},
    tacticClaimingZones={missing="tactic1"},
    cardClaimingZones={},
    tacticCard={"card1"},
    gameCards={},
    GUID={deck={artifact="artifactDeck"}},
    getObjectFromGUID=function(guid) return objects[guid] end,
    isTacticCard=function(card) return card.guid=="card1" end,
    createClaimButton=function(guid,sourceName) return {guid=guid,source=sourceName} end,
    safeWaitTime=function(_,callback) callback() end,
}
setmetatable(env,{__index=_G})
assert(load(implementation,"Claim button refresh","t",env))()

local function check(name)
    local ok,err=pcall(env.claimButtonRefresh)
    assert(ok,name..": "..tostring(err))
end
local function mock(guid)
    return {guid=guid,UI={setXmlTable=function(layout)
        writes[#writes+1]={guid=guid,layout=layout}
    end}}
end
local function lastSource()
    local entry=writes[#writes]
    return entry and entry.layout[1] and entry.layout[1].source
end

check("missing dummy tactic and missing zone on offer refresh")
env.gStates.tacticShown=true
env.gStates.tacticRemove=true
env.gStates.discardTactics=2
env.turnOrder[1].mage="Dummy"
check("missing dummy tactic on claim and removal paths")
assert(#writes==0,"Missing objects should produce no UI writes")

objects["483ed5"]=mock("483ed5")
check("present dummy tactic on claim and removal paths")
assert(#writes==3,"Dummy tactic should clear, then offer claim and removal buttons")
assert(lastSource()=="removeTactic5","Existing dummy tactic removal button was lost")
assert(writes[2].layout[1].source=="tactic7","Existing dummy tactic claim button was lost")

objects={}
writes={}
env.turnOrder[1].mage="Hero"
env.gStates.tacticRemove=true
env.gStates.discardTactics=1
env.gStates.tacticShown=false
check("missing tactic zone on removal path")
assert(#writes==0,"Missing tactic zone should produce no UI writes")

local card=mock("card1")
objects["zone1"]={getObjects=function() return {card} end}
env.tacticClaimingZones={zone1="tactic1",missing="tactic2"}
env.gStates.tacticShown=true
env.gStates.tacticRemove=false
check("existing tactic zone claim path")
assert(lastSource()=="tactic1","Existing tactic claim button was lost")
print("Tactic claim refresh regression tests passed")

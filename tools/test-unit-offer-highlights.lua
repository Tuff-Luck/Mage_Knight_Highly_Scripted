-- Run from repo root: lua5.2 tools/test-unit-offer-highlights.lua
local h=assert(io.open("src/PlayingGame/Offers.lua","r"))
local src=h:read("*a") h:close()
local start=assert(src:find("-- Unit-offer recruitment highlights.",1,true))
local finish=assert(src:find("-- The Spell browser uses",start,true))
local items={}
local function unit(guid)
    local o={guid=guid,changes=0,clears=0}
    function o.highlightOn(color) o.color=color o.changes=o.changes+1 end
    function o.highlightOff() o.color=nil o.clears=o.clears+1 end
    items[guid]=o return o
end
local a,b,c=unit("aaaaaa"),unit("bbbbbb"),unit("cccccc")
local offer={a,b,c}
local budget=nil
gStates={turnNumber=1,firstStarted=true,positionMageKnight={[5]="Dummy"}}
turnOrder={{mage="Tovak",seatPos=1,avatarLocation="village"}}
gameCards={
    aaaaaa={recruit={"village"},influence=5},
    bbbbbb={recruit={"village"},influence=8},
    cccccc={recruit={"keep"},influence=2}}
local combatObjects={}
monsterPugs={enemy1={name="Orcs"}}
function playerCombatObjects(seatPos)
    assert(seatPos==1,"Only current player's enemies count")
    return combatObjects
end
function unitOfferCards() return offer end
function getObjectFromGUID(guid) return items[guid] end
function resourceTrackerAvailableInfluence() return budget end
function unitRecruitableAtCurrentLocation(_,obj)
    for _,site in ipairs(gameCards[obj.guid].recruit) do
        if site==turnOrder[1].avatarLocation then return true end
    end
    return false
end
assert(load(src:sub(start,finish-1),"offer highlights","t",_G))()
refreshUnitOfferHighlights()
assert(a.color[1]<0.8 and b.color[1]<0.8 and c.color==nil,"dark legal-site highlights")
budget=6
refreshUnitOfferHighlights()
assert(a.color[1]==1 and b.color[1]<0.8,"only affordable Unit bright")
refreshUnitOfferHighlights()
assert(a.changes==2,"unchanged offer does not re-highlight")
budget=9
refreshUnitOfferHighlights()
assert(b.color[1]==1,"affordability responds to added Influence")
budget=nil
refreshUnitOfferHighlights()
assert(a.color[1]<0.8 and b.color[1]<0.8,"closing tracker darkens offers")
-- Enemy tokens remove BOTH dark legal-site and bright affordable highlights,
-- including when the resource tracker is closed.
combatObjects={{guid="enemy1"}}
refreshUnitOfferHighlights()
assert(a.color==nil and b.color==nil and c.color==nil,
    "An enemy in the play area removes every Unit highlight")
budget=9
refreshUnitOfferHighlights()
assert(a.color==nil and b.color==nil,
    "Affordability cannot restore highlights during combat")
budget=nil
combatObjects={}
refreshUnitOfferHighlights()
assert(a.color~=nil and b.color~=nil,
    "Unit highlights resume when the enemy leaves")
turnOrder[1].avatarLocation="keep"
refreshUnitOfferHighlights()
assert(a.clears>=1 and b.clears>=1 and c.color~=nil,
    "site move removes old highlights")
offer={}
refreshUnitOfferHighlights()
assert(c.clears==1,"claim removes highlight")
offer={a}
gStates.tacticShown=true
refreshUnitOfferHighlights()
assert(a.color==nil,"no glow while choosing tactics")
local ui=assert(io.open("src/PlayingGame/UI.lua","r"))
local sourceUI=ui:read("*a") ui:close()
assert(sourceUI:find("if resourceCardsEnemyPresent~=nil and resourceCardsEnemyPresent() then return nil end",1,true),
    "combat must suppress affordability")
local eventFile=assert(io.open("src/PlayingGame/Events.lua","r"))
local eventSource=eventFile:read("*a") eventFile:close()
assert(eventSource:find("refreshUnitOfferForEnemyZoneChange(ctx)",1,true),
    "Enemy zone changes must refresh glow even when Resource Tracker is closed")
print("Unit offer site and affordability highlights: PASS")

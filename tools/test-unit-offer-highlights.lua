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
turnOrder={{mage="Tovak",avatarLocation="village"}}
gameCards={
    aaaaaa={recruit={"village"},influence=5},
    bbbbbb={recruit={"village"},influence=8},
    cccccc={recruit={"keep"},influence=2}}
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
turnOrder[1].avatarLocation="keep"
refreshUnitOfferHighlights()
assert(a.clears==1 and b.clears==1 and c.color~=nil,"site move removes old highlights")
offer={}
refreshUnitOfferHighlights()
assert(c.clears==1,"claim removes highlight")
offer={a}
gStates.tacticShown=true
refreshUnitOfferHighlights()
assert(a.color==nil,"no glow while choosing tactics")
print("Unit offer site and affordability highlights: PASS")

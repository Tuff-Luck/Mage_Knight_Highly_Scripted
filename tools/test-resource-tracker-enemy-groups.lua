-- Enemy group boundaries and resource collection use the production helpers.
local engine=dofile("src/PlayingGame/PlayerBoard/ResourceTracker/EnemyGroups.lua")
local function eq(actual,expected,label)
    assert(actual==expected,label..": expected "..tostring(expected)..", got "..tostring(actual))
end
local entries={}
for i=1,7 do entries[i]={guid=tostring(i)} end
local joined={["1"]=true,["2"]=true,["3"]=true,["5"]=true,["6"]=true}
local groups,of=engine.build(entries,joined)
eq(#groups,3,"Consecutive joined enemies form groups")
eq(#groups[1].members,3,"First group contains three enemies")
eq(groups[1].leader,1,"First member is leader even if first join flag set")
eq(groups[2].leader,4,"Second group begins at unjoined enemy")
eq(groups[3].leader,7,"Single enemy is its own group")
eq(of[3],groups[1],"Member maps to group")
eq(of[6],groups[2],"Second group's members map correctly")
eq(#groups[1].sources,0,"Fresh groups have empty source lists")
local a,b,c={key="a"},{key="b"},{key="c"}
local assigned={[1]={sources={a,b}},[3]={sources={c}},[4]={sources={{key="other"}}}}
local members,sources=engine.collect(groups[1],entries,assigned)
eq(#members,3,"All members included even without allocation")
eq(members[2],entries[2],"Original member identity retained")
eq(#sources,3,"All assigned sources included")
eq(sources[1],a,"First assigned source first")
eq(sources[2],b,"Within-member source order retained")
eq(sources[3],c,"Later member appended")
eq(#groups[1].sources,0,"Collection does not mutate group")
eq(#assigned[1].sources,2,"Collection does not mutate allocations")
members,sources=engine.collect(groups[3],entries,{})
eq(#members,1,"Singleton has one member")
eq(#sources,0,"Unassigned singleton has no sources")
entries[2].destroyed=true
local rebuilt,map=engine.build(entries,joined)
eq(#rebuilt,5,"Destroyed member splits adjacent groups")
eq(map[1].leader,1,"Surviving left member isolated")
eq(map[2].leader,2,"Destroyed member isolated")
eq(map[3].leader,3,"Surviving right member isolated")
eq(#map[2].members,1,"Destroyed member not joined to live enemy")
eq(#groups[1].members,3,"Original group not mutated by rebuild")
entries[2].destroyed=nil
entries[5].attackOnly=true
rebuilt,map=engine.build(entries,joined)
eq(#rebuilt,5,"Attack-only reminder splits adjacent groups")
eq(map[5].leader,5,"Attack-only reminder is isolated")
eq(map[6].leader,6,"Following joined enemy starts new group")
eq(joined["5"],true,"Saved join flags untouched")
local empty,emptyMap=engine.build({},joined)
eq(#empty,0,"Empty combat has no groups")
eq(next(emptyMap),nil,"Empty combat has no member map")
print("Enemy group construction, rebuilding and ordered resources passed")

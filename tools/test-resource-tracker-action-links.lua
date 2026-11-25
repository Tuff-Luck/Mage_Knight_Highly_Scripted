-- Direct regression of the physical Action pairing engine.
package.path="src/?.lua;"..package.path
local physical=require("PlayingGame.PlayerBoard.ResourceTracker.Scanning.PhysicalObjects")
local env=setmetatable({gameCards={},cardResourceDefinitions={
    concentration={poweredLink={mode="stronger",bonus=2}},
    willFocus={poweredLink={mode="stronger",bonus=3}},
    maximal={requiredLink={mode="repeat",normalCount=3,poweredCount=2}},
    improv={requiredLink={mode="discard"}},
    ritual={requiredLink={mode="throwAway"},linkedColorEffects={
        normal={Red={attack=5},Blue={attackIce=3}},powered={Red={attackFire=6},Blue={attackColdFire=4}}}},
    stout={discardBoost={normal={perCard=1,woundOnly=true,maxWounds=1},powered={perCard=2,maxWounds=1}}},
    artifact={requiredLink={mode="discard"},discardBoost={normal={perCard=2,maxWounds=1}}},
    ordinary={normal={move=2},powered={ranged=3}}
}},{__index=_G})
local function eq(a,b,label)
    assert(a==b,label..": expected "..tostring(b)..", got "..tostring(a))
end
local areas={}
local function card(guid,rule,x,posture,down,kind,color)
    env.gameCards[guid]={resourceKey=rule or "ordinary",cardType=kind or "Starting",color=color}
    areas[guid]={x=x or 0,z=0,halfX=1,halfZ=1}
    return {guid=guid,posture=posture or "upright",is_face_down=down,
        getGMNotes=function() return "" end}
end
local function wound(guid,x)
    areas[guid]={x=x or 0,z=0,halfX=1,halfZ=1}
    return {guid=guid,posture="discard",getGMNotes=function() return "Wound" end}
end
local broken={}
local resolve=assert(loadfile("src/PlayingGame/PlayerBoard/ResourceTracker/Cards/ActionLinks.lua","t",env))()({
    overlapArea=physical.overlapArea,cardPosture=function(c) return c.posture end,
    canPayDiscard=function(c) return not c.is_face_down and c.posture=="discard" end,
    resourceCardsArtifactBroken=function(guid,c) return broken[guid]==true or c.is_face_down==true end,
    linkedColorChoices=function(rule,guid,powered)
        local effects=powered and rule.linkedColorEffects.powered or rule.linkedColorEffects.normal
        local colors=env.gameCards[guid].color
        if type(colors)=="string" then colors={colors} end
        local out={}
        for _,color in ipairs(colors or {}) do
            if effects[color] then out[#out+1]=effects[color] end
        end
        return out
    end
})
local function scan(cards,wounds,powered,skills)
    return resolve(cards,wounds or {},areas,powered or {},skills or {})
end
local c=card("con","concentration",0)
local f=card("will","willFocus",0)
local a=card("a",nil,0.5)
local b=card("b",nil,0.5)
local spell=card("spell",nil,0,nil,false,"Spell")
local faceDown=card("down",nil,0,nil,true)
local links,boost,source,discarded,paid,linked,repeats,bonuses=
    scan({c,f,b,a,spell,faceDown},nil,{con=true,will=true})
eq(boost.a,nil,"Equal strongest overlap leaves Concentration unresolved")
eq(boost.b,nil,"Equal strongest overlap leaves Will Focus unresolved")
areas.a.x=0.25
links,boost,source,discarded,paid,linked,repeats,bonuses=
    scan({c,f,b,a,spell,faceDown},nil,{con=true,will=true})
eq(boost.a.bonus,2,"Unique strongest overlap chooses Concentration target")
eq(boost.b.bonus,3,"Second stronger grant uses another target")
eq(source.a,"con","Reverse boost source")
eq(links.con[1],"a","Source link")
eq(links.a[1],"con","Target link")
eq(boost.spell,nil,"Spell cannot receive stronger Action link")
eq(boost.down,nil,"Face-down Action excluded")
links,boost=scan({c,a})
eq(boost.a,nil,"Unpowered Concentration has no link")
local max=card("max","maximal",0)
local improv=card("improv","improv",1,nil,true)
local upright=card("upright",nil,0)
local d1=card("d1",nil,2.1,"discard")
local d2=card("d2",nil,2.2,"discard",false,"Spell")
local d3=card("d3",nil,2.3,"discard",false,"Artifact")
links,boost,source,discarded,paid,linked,repeats=
    scan({max,improv,upright,d1,d2,d3})
eq(repeats.improv.count,3,"Basic Maximal Effect repeats three times")
eq(discarded.improv,"max","Face-down repeat preferred over greater upright overlap")
eq(linked.max,"improv","Maximal Effect target")
eq(paid.improv,true,"All three independent discard costs paid")
eq(discarded.d1,"improv","First discard")
eq(discarded.d2,"improv","Spell can pay ordinary discard")
eq(discarded.d3,"improv","Artifact can pay ordinary discard")
eq(discarded.upright,nil,"Upright card is not ordinary discard")
links,boost,source,discarded,paid,linked,repeats=scan({max,improv,upright,d1,d2})
eq(paid.improv,false,"Two discards cannot cover three repeats")
links,boost,source,discarded,paid,linked,repeats=scan({max,improv,upright,d1,d2},nil,{max=true})
eq(repeats.improv.count,2,"Powered Maximal Effect repeats twice")
eq(repeats.improv.powered,true,"Repeats stronger effect")
eq(paid.improv,true,"Two independent costs cover two repeats")
links,boost,source,discarded,paid=scan({max,improv,upright,d1,d2},nil,{max=true,d2=true})
eq(paid.improv,false,"Powered payment card cannot be discarded again")
local ritual=card("ritual","ritual",1,nil,true)
local red=card("red",nil,2.1,nil,true,"Starting","Red")
local blue=card("blue",nil,2.2,nil,true,"Advanced Action","Blue")
local dual=card("dual",nil,2.3,nil,true,"Starting",{"Red","Blue"})
links,boost,source,discarded,paid,linked,repeats=scan({max,ritual,red,blue,dual})
eq(paid.ritual,true,"Each Ritual Attack repeat has its own throw-away")
eq(repeats.ritual.options[1][1].attack,5,"First repeat uses red")
eq(repeats.ritual.options[2][1].attackIce,3,"Second repeat uses blue")
eq(#repeats.ritual.options[3],2,"Third repeat keeps both color choices")
eq(discarded.red,"ritual","Throw-away linked only once")
eq(linked.ritual,"red","First throw-away source link")
local stout=card("stout","stout",1)
local w1,w2,w3=wound("w1",1.1),wound("w2",1.2),wound("w3",1.3)
local payment=card("pay",nil,1.4,"discard")
links,boost,source,discarded,paid,linked,repeats,bonuses=scan({stout,payment},{w1,w2})
eq(bonuses.stout,1,"Basic Stout Resolve one Wound only")
eq(discarded.w2,nil,"Extra Wound remains unused")
eq(discarded.pay,nil,"Basic effect rejects ordinary cards")
links,boost,source,discarded,paid,linked,repeats,bonuses=scan({stout,payment},{w1,w2},{stout=true})
eq(bonuses.stout,4,"Stronger Stout Resolve two separate costs")
eq(discarded.w2,nil,"Stronger effect still caps Wounds")
links,boost,source,discarded,paid,linked,repeats,bonuses=scan({stout,payment},{w1},{stout=true},{w1=true})
eq(bonuses.stout,2,"Skill-linked Wound cannot also pay Stout Resolve")
eq(discarded.w1,nil,"Skill payment preserved")
links,boost,source,discarded,paid,linked,repeats,bonuses=
    scan({max,stout,payment},{w1,w2,w3},{max=true})
eq(repeats.stout.count,2,"Repeated Stout Resolve")
eq(bonuses.stout[1],4,"First use gets Wound and other card")
eq(bonuses.stout[2],2,"Second use gets its own Wound")
eq(discarded.w3,nil,"No third Wound payment across two uses")
local artifact=card("art","artifact",0,nil,false,"Artifact")
local cost=card("cost",nil,0,"discard")
broken.art=true
links,boost,source,discarded,paid,linked,repeats,bonuses=scan({artifact,cost})
eq(discarded.cost,nil,"Thrown Artifact does not consume basic discard payment")
eq(bonuses.art,nil,"Thrown Artifact has no basic discard bonus")
print("Action link priority, stronger grants, repeated payments and discard exclusions passed")

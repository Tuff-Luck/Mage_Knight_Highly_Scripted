-- Direct card calculation regression: actual extracted calculation and live dependencies.
package.path="src/?.lua;"..package.path
local tracker={sidewaysChoices={{move=1},{attack=1}},totalsKeys={attack=true,move=true,block=true,blockFire=true,blockIce=true}}
local cfg={blockedEnemyCounts={[1]=2},compositePhasesMatch=function() return true end}
local selected={}
local choice=require("PlayingGame.PlayerBoard.ResourceTracker.Cards.ResourceChoices")(tracker,function() return selected end,{},nil)
local attached=nil
tracker.bannerAttachedCardResult=function() return attached end
local day=true
local terrainValue=3
local env=setmetatable({
    gameCards={rage={resourceKey="rage",cardType="Starting"},
        spell={resourceKey="spell",cardType="Spell"},counter={resourceKey="counter",cardType="Advanced Action"},
        land={resourceKey="land",cardType="Starting"},manual={resourceKey="manual",cardType="Artifact"}},
    cardResourceDefinitions={
        rage={normalChoices={{attack=2},{block=2}},powered={attack=4}},
        spell={normal={attack=5},powered={attack=8}},
        counter={normal={attack=2},blockedEnemyAttackBonus={normal=2,powered=3},fameRep={normal={fame=1}}},
        land={normalChoices={{key="block",terrainBlock=true}}},
        manual={normal={move=2},manualSecondary=true}
    },gStates={turnNumber=1},turnOrder={{seatPos=1}}
},{__index=_G})
local calc=assert(loadfile("src/PlayingGame/PlayerBoard/ResourceTracker/Cards/CardEffects.lua","t",env))()({
    trackerPrivate=tracker,combatConfig=cfg,chosenEffect=choice.chosenEffect,cardPosture=function(c) return c.posture end,
    cardCanPlaySideways=function(c) return not c.is_face_down end,sideChoices=choice.sideChoices,
    currentLandBlockValue=function() return terrainValue end,resourceCardsUsesDayMana=function() return day end,
    applyLinkedResourceBonus=function(effects,link)
        if effects==nil or link==nil then return effects end
        local out={} for k,v in pairs(effects) do out[k]=v+link.bonus end return out
    end,
    effectHasTrackedResource=function(effects)
        for k,v in pairs(effects or {}) do if tracker.totalsKeys[k] and type(v)=="number" and v~=0 then return true end end
        return false
    end,
    cardTerrainEffects=function() return nil end,terrainEffectActive=function() return true end,
    choiceCategory=choice.choiceCategory
})
local function card(guid,powered,options)
    options=options or {}
    return calc.calculateCard({guid=guid,posture=options.posture or "upright",is_face_down=options.down},
        powered,options.boost,options.links or {},options.discardTarget,options.hasDiscard,options.skillLink,
        nil,options.repeatLink,options.discardBonus,nil,nil,options.paid)
end
local result=card("rage",false)
assert(result.kind=="card" and result.resources.attack==2 and result.complete)
selected.rage={effect="block"}
assert(card("rage",false).resources.block==2)
assert(card("rage",true).resources.attack==4,"Fixed stronger effect must not reuse weaker choices")
assert(card("rage",false,{posture="sideways",skillLink={skillGUID="skill",sidewaysValue=3}}).resources.move==3)
assert(card("rage",false,{discardTarget=true}).resources==nil)
assert(card("spell",true).resources==nil,"Unpaid Spell remains inert")
assert(card("spell",true,{paid=true}).resources.attack==8)
assert(card("spell",true,{paid=true,down=true}).resources==nil)
local repeatResult=card("counter",false,{repeatLink={powered=false,count=3}})
assert(repeatResult.resources.attack==18 and repeatResult.fameRep.fame==3)
assert(card("land",false).resources.blockFire==3)
day=false
assert(card("land",false).resources.blockIce==3)
assert(card("manual",false).status=="yellow")
attached={guid="rage",resources=nil,status="blue"}
assert(card("rage",true)==attached,"Attached Banner early result must take priority")
attached=nil
env.gameCards={new={cardType="Starting",resourceKey="rage"}}
assert(card("new",true).resources.attack==4,"Read replaced catalog live")
-- A played-card record may borrow its printed resource table. The actual
-- coordinator's Tirelessness pass must not modify that catalog on rescan.
local sourceFile=assert(io.open("src/PlayingGame/PlayerBoard/ResourceTracker/Cards/CardInteractions.lua","r"))
local source=sourceFile:read("*a")
sourceFile:close()
local first=assert(source:find("-- Wolfhawk's Tirelessness affects only subsequently PLAYED cards",1,true))
local last=assert(source:find("-- Only outline enemies that actually supply printed values",first,true))
local tirelessness=assert(load("return function(cards,records,totals)\n"
    ..source:sub(first,last-1).."\nend","Tirelessness adjustment","t",env))()
env.cardPosture=function(c) return c.posture end
env.gameCards={tire={cardType="Starting",resourceKey="tire"},
    march={cardType="Starting",resourceKey="march"}}
env.cardResourceDefinitions={
    tire={normal={move=2},followingMoveBonus={normal={amount=1,count=1}}},
    march={normal={move=2}}}
env.gStates.resourceCardPlayOrder={tire=1,march=2}
local played={{guid="tire",posture="upright"},{guid="march",posture="upright"}}
for scan=1,2 do
    local records={tire=card("tire",false),march=card("march",false)}
    local totals={move=4}
    tirelessness(played,records,totals)
    assert(records.march.resources.move==3,"Tirelessness grants one extra Move per scan")
    assert(records.march.tirelessnessBonus==1 and totals.move==5,"Modifier and totals agree")
    assert(env.cardResourceDefinitions.march.normal.move==2,"Printed Move must remain unchanged")
end
print("Card resource calculation, payment gates, repeat, terrain and rescan regressions passed")

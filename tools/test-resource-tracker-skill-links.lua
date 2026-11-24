-- Direct regressions for physical Skill link resolution and shared mana reservation.
package.path="src/?.lua;"..package.path
local physical=require("PlayingGame.PlayerBoard.ResourceTracker.PhysicalObjects")
local gold,black=true,false
local selected="base"
local env=setmetatable({
    gameCards={red={cardType="Starting",color="Red"},dual={cardType="Starting",color={"Blue","Red"}},
        blue={cardType="Starting",color="Blue"},a={cardType="Starting",color="Blue"},
        b={cardType="Starting",color="Blue"},spell={cardType="Spell",color="Blue"}},
    skillResourceDefinitions={
        universal={linkedCard={targetKind="card",posture="sideways",sideways={value=3,manaRequired=true,matchingManaValue=4}}},
        first={linkedCard={targetKind="card",posture="sideways",sideways={value=2,faceDownValue=3}}},
        second={linkedCard={targetKind="card",posture="sideways",sideways={value=5}}},
        ritual={linkedCard={targetKind="card",posture="sideways",requiresCirculation=true,sideways={value=3}}},
        choice={linkedCard={targetKind="card",posture="sideways",sideways={value=2,choiceValues={sourceUnused=3}}}},
        pack={linkedCard={targetKind="card",posture="sideways",sideways={value=4,perEmptyCommandSlot=1}}},
        polar={manaConversion={mode="opposite"}}
    },gStates={doingTheRounds={}}
},{__index=_G})
local function eq(a,b,label)
    assert(a==b,label..": expected "..tostring(b)..", got "..tostring(a))
end
local function card(guid,posture,down)
    return {guid=guid,kind="card",posture=posture,is_face_down=down}
end
local function skill(guid,down) return {guid=guid,is_face_down=down} end
local function mana(guid,color,x,z)
    return {guid=guid,color=color,getPosition=function() return {x,1,z} end}
end
local function area(x,z) return {x=x,z=z,halfX=1,halfZ=1} end
local function matches(card,color)
    return env.gameCards[card.guid].color==color or color=="Black" or color=="Gold"
end
local links=assert(loadfile("src/PlayingGame/PlayerBoard/ResourceTracker/SkillLinks.lua","t",env))()({
    trackerPrivate={},resourceCardsGoldAllowed=function() return gold end,
    resourceCardsBlackAllowed=function() return black end,
    currentChoice=function(guid,powered,choices) return nil,selected end,
    skillChoicesForCurrentTurn=function(rule) return rule.choices end,
    manaColor=function(object) return object.color end,
    resourceObjectKind=function(object) return object.kind end,
    cardPosture=function(object) return object.posture end,
    overlapArea=physical.overlapArea,
    manaInsideFootprint=function(object,footprint)
        local pos=object.getPosition()
        return math.abs(pos[1]-footprint.x)<footprint.halfX
            and math.abs(pos[3]-footprint.z)<footprint.halfZ
    end,
    matchesCardMana=matches
})
eq(links.matchingSidewaysMana(card("dual","sideways"),"Red"),true,"Dual-color printed match")
eq(links.matchingSidewaysMana(card("red","sideways"),"Gold"),false,"Gold is not a printed color match")
local red=card("red","sideways")
local areas={red=area(0,0),universal=area(0,0),first=area(0,0),second=area(0.5,0),
    ritual=area(0,0),choice=area(0,0),pack=area(0,0),polar=area(0,0),
    a=area(0,0),b=area(0,0),blue=area(0,0),spell=area(0,0)}
local redMana=mana("r","Red",0,0)
local goldMana=mana("g","Gold",0,0)
local blueMana=mana("u","Blue",0,0)
local function sideways(skills,targets,manas,placement,reserved,unitState)
    return links.resolveSkillCardLinks(skills,targets,areas,manas or {},placement or {},reserved or {},unitState)
end
local target,bySkill,byMana=sideways({skill("universal")},{red},{redMana},{r="play"})
eq(target.red.sidewaysValue,4,"Universal Power matching mana")
eq(bySkill.universal,"red","Skill reverse link")
eq(byMana.r.targetGUID,"red","Mana reservation")
target=sideways({skill("universal")},{red},{blueMana},{u="play"})
eq(target.red.sidewaysValue,3,"Nonmatching mana")
target=sideways({skill("universal")},{red},{goldMana},{g="play"})
eq(target.red.sidewaysValue,4,"Day Gold wildcard")
gold=false
target=sideways({skill("universal")},{red},{goldMana},{g="play"})
eq(target.red,nil,"Night Gold not legal")
gold=true
target=sideways({skill("universal")},{red},{redMana},{r="crystal"})
eq(target.red,nil,"Inventory mana cannot pay")
target=sideways({skill("universal")},{red},{redMana},{r="play"},{r=true})
eq(target.red,nil,"Reserved mana cannot pay twice")
target=sideways({skill("second"),skill("first",true)},{red})
eq(target.red.skillGUID,"first","Strongest overlap wins")
eq(target.red.sidewaysValue,3,"Flipped Skill strength")
areas.second=area(0,0)
target=sideways({skill("second"),skill("first")},{red})
eq(target.red.skillGUID,"first","Equal overlap uses Skill GUID")
target=sideways({skill("ritual")},{red})
eq(target.red,nil,"Circulated Skill not yet available")
env.gStates.doingTheRounds.ritual=1
target=sideways({skill("ritual")},{red})
eq(target.red.sidewaysValue,3,"Circulated Skill available")
selected="sourceUnused"
target=sideways({skill("choice")},{red})
eq(target.red.sidewaysValue,3,"Selected Skill strength")
target=sideways({skill("pack")},{red},nil,nil,nil,{emptyCommandSlots=2})
eq(target.red.sidewaysValue,6,"Empty Command slot bonus")
local polar=skill("polar")
local function convert(manas,cards,placement)
    return links.resolveManaSkillLinks({polar},manas,cards,areas,placement)
end
local byObject,conversion,byCard=convert({redMana},{card("b","upright"),card("a","upright")},{r="play"})
eq(conversion.polar.converted,"Blue","Polarization opposite color")
eq(conversion.polar.targetGUID,"a","Equal overlap uses card GUID")
eq(byObject.r,byCard.a,"Conversion maps share link")
target=sideways({skill("universal")},{red},{redMana},{r="play"},byObject)
eq(target.red,nil,"Polarization reservation precedes sideways payment")
byObject,conversion,byCard=convert({redMana},{card("a","upright",true)},{r="play"})
eq(conversion.polar.targetGUID,nil,"Face-down card excluded")
byObject,conversion=convert({redMana},{card("a","upright")},{r="unit"})
eq(conversion.polar,nil,"Conversion requires play-zone mana")
byObject,conversion=convert({goldMana},{card("spell","upright")},{g="play"})
eq(conversion.polar.converted,"Black","Gold converts to Black")
eq(conversion.polar.targetGUID,nil,"Converted Black obeys permission")
black=true
byObject,conversion=convert({goldMana},{card("a","upright"),card("spell","upright")},{g="play"})
eq(conversion.polar.targetGUID,"spell","Converted Black only powers Spells")
print("Physical Skill links, overlap ranking, mana reservation and Polarization passed")

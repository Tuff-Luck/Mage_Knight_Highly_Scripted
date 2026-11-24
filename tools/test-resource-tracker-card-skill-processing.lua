-- Exercise the production scan passes with current records and controlled helpers.
local root="src/PlayingGame/PlayerBoard/ResourceTracker/"
local function eq(actual,expected,label)
    assert(actual==expected,label..": expected "..tostring(expected)..", got "..tostring(actual))
end
local function card(guid) return {guid=guid} end
local function posture(obj) return "upright" end
local function add(result,totals)
    result.contributes=false
    for key,value in pairs(result.resources or {}) do
        if type(value)=="number" then
            totals[key]=(totals[key] or 0)+value
            result.contributes=result.contributes or value~=0
        end
    end
end
local env=setmetatable({gameCards={},cardResourceDefinitions={},skillResourceDefinitions={},
    gStates={resourceCardPlayOrder={}},resourceCardsArtifactBroken=function() return false end},
    {__index=_G})
local played=assert(loadfile(root.."Cards/PlayedCardScan.lua","t",env))()
local interactions=assert(loadfile(root.."Cards/CrossCardEffects.lua","t",env))()
local skillPass=assert(loadfile(root.."Cards/SkillInteractions.lua","t",env))()
local unit,action,following,skill=card("unit"),card("action"),card("following"),card("skill")
env.gameCards.action={cardType="Advanced Action",resourceKey="action"}
env.gameCards.following={cardType="Starting",resourceKey="following"}
env.cardResourceDefinitions.action={unitCombatBoost={normal=1,powered=2},
    preventUnitDamage=true,poweredUnitResistances=true,poweredHeroFirstWound=true,
    movementEffects={powered={jumpTwoSpaces=true}},followingMoveBonus={normal={count=1,amount=1},powered={all=true,amount=2}}}
env.cardResourceDefinitions.following={}
local printed={move=2}
local ctx={seatPos=1,cards={action,following},powered={action=true},boostBy={},repeatByTarget={},
    linkedCardBySource={},discarded={},hasDiscard={},spellCastingPaid={},links={},skillLinksByTarget={},
    discardBoostBySource={},inventoryCrystalCounts={},monsters={},footprints={},current={},records={},totals={},
    terrainModifiers={},movementEffects={jumpTwoSpaces=false,ignoreRampagers=false,windFlightMax=0,singleSpaceDiscount=0},
    trackerPrivate={totalsKeys={move=true}},combatConfig={ambushCombatCategories={}},manaByCard={},
    extraTerrainManaByCard={},cardPosture=posture,linkedColorChoices=function() return nil end,
    sideChoices=function() return nil end,calculateCard=function(obj,powered)
        return {guid=obj.guid,complete=true,powered=powered,resources=printed,links={},status="green"}
    end,resourceCardsRecruitInfluenceBonus=function() return 0 end,
    showChoiceButtons=function() end,cardTerrainEffects=function() return {} end,
    resourceCardsIgnoreSiteFortification=function(rule,result,obj) return obj.guid=="action" end,
    addResourceAmounts=add,setHighlight=function() end,usesCurrentHexBlock=false,usesCurrentHexHealing=false,
    ignoreSiteFortifications=false,unitCombatBoost=0,preventUnitDamage=false,
    allUnitResistances=false,heroFirstWoundIgnored=false}
local block,heal,ignore,boost,prevent,resist,wound=played.process(ctx)
eq(ctx.records.action.powered,true,"Paid strong side reaches the card record")
eq(ctx.totals.move,4,"Both played cards contribute once")
eq(ctx.current.following,true,"Played source registered")
eq(ctx.movementEffects.jumpTwoSpaces,true,"Movement flags retained")
eq(block,false,"No terrain Block invented")
eq(heal,false,"No terrain Healing invented")
eq(ignore,true,"Site Fortification bypass returned")
eq(boost,2,"Unit boost returned to coordinator")
eq(prevent,true,"Damage prevention returned")
eq(resist,true,"Unit resistances returned")
eq(wound,true,"Hero mitigation returned")
env.gStates.resourceCardPlayOrder={action=1,following=2}
ctx.wounds={}
interactions.process(ctx)
eq(ctx.records.following.resources.move,4,"Tirelessness boosts only later card")
eq(ctx.records.action.resources.move,2,"Origin does not boost itself")
eq(ctx.totals.move,6,"Following-card bonus updates shared totals")
eq(printed.move,2,"Shared printed resource table remains unchanged")
env.skillResourceDefinitions.skill={unitBoost={attack=2},attackPhaseFallback=true,
    choices={{key="attack",attack=2}}}
ctx.skills={skill}
ctx.objects={unit=unit}
ctx.activations={unit={seatPos=1}}
ctx.records.unit={guid="unit",kind="unit",complete=true,resources={siegeFire=3},links={},status="green"}
ctx.totals.siegeFire=3
ctx.manaBySkill={}
ctx.skillLinksBySkill={}
ctx.calculateSkill=function(obj) return {guid=obj.guid,kind="skill",links={},resources=nil} end
ctx.chosenEffect=function(guid,powered,choices) return choices[1] end
ctx.choiceCategory=function(choice) return choice.key end
ctx.footprint=function(obj) return {} end
ctx.overlapArea=function() return 1 end
skillPass.process(ctx)
eq(ctx.records.unit.resources.siegeFire,nil,"Leadership removes original Siege")
eq(ctx.records.unit.resources.attackFire,5,"Leadership converts and boosts actual element")
eq(ctx.totals.siegeFire,0,"Converted resource is removed from totals")
eq(ctx.totals.attackFire,5,"Converted Attack is counted once")
eq(ctx.records.unit.status,"green","Activated Unit remains green")
eq(ctx.records.skill.status,"purple","Linked Skill is purple")
eq(ctx.records.skill.links[1],"unit","Skill links to actual Unit")
print("Played card and linked Skill scan passes passed")

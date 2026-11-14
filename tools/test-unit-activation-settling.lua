-- Unit activation regression: stacked crystals, settled Command state, and target UI.
-- Run from repository root: lua5.2 tools/test-unit-activation-settling.lua
local function read(path)
    local f=assert(io.open(path,"r"))
    local result=f:read("*a")
    f:close()
    return result
end
local function extract(text,first,last)
    local a=assert(text:find(first,1,true),"Missing "..first)
    local b=assert(text:find(last,a+#first,true),"Missing "..last)
    return text:sub(a,b-1)
end
local function eq(actual,expected,label)
    assert(actual==expected,(label or "Mismatch")..": expected "..tostring(expected)
        ..", got "..tostring(actual))
end
local function hasButton(xml,id)
    for _,node in ipairs(xml or {}) do
        if node.attributes~=nil and node.attributes.id==id then return true end
    end
    return false
end

-- A settled Unit and Command are still on the mat when stacking makes their
-- vertical positions disappear from the thin zone's reported object list.
local position={x=0,y=1.6,z=0}
local commandPosition={x=0,y=1.9,z=0}
local unit={guid="f17813",type="Card",cardType="Regular Unit",resting=true,
    getPosition=function() return position end,
    getBounds=function() return {center=position,size={x=2,z=2.8}} end,
    getScale=function() return {x=1.5,z=1.5} end,
    isSmoothMoving=function() return false end,
    getGMNotes=function() return "" end}
local token={guid="cmd",type="Custom_Model",resting=true,
    getPosition=function() return commandPosition end,
    getGMNotes=function() return "Command Token" end,
    hasTag=function() return false end,
    isSmoothMoving=function() return false end}
local zone={getBounds=function() return {center={x=0,z=0},size={x=10,z=10}} end,
    getObjects=function() return {} end}
local objects={unitZone=zone,[unit.guid]=unit,[token.guid]=token}
getObjectFromGUID=function(guid) return objects[guid] end
gameCardType=function(obj) return obj.cardType end
playerUnitAreas={[1]="unitZone"}
playerPlayAreas={[1]="playZone"}
GUID={skill={bondsOfLoyalty="no-bonds"},card={bannerOfCommandToken="no-banner"}}
gameCards={}
gStates={unitResourceActivations={[unit.guid]={seatPos=1,tokenGUID=token.guid}}}
dofile("src/PlayingGame/PlayerBoard/UnitLayout.lua")
local layout=unitLayoutSnapshot(1)
eq(#layout.units,1,"Settled Northern Monks retained above thin zone")
eq(#layout.commands,1,"Settled Command token retained above thin zone")
eq(unitLayoutCommandTarget(token,1),unit,"Command still targets Northern Monks")
local state=unitLayoutResourceState(1)
eq(state.units[1].ready,false,"Command still marks Unit activated")
unit.held_by_color="Blue"
eq(unitLayoutActiveUnitOnMat(unit,1),false,"Lifted Unit is not falsely recovered")
eq(#unitLayoutSnapshot(1).units,0,"Lifted Unit is absent until returned")
unit.held_by_color=nil
position.x=20
eq(#unitLayoutSnapshot(1).units,0,"Unit moved off mat is not recovered")
position.x=0
eq(#unitLayoutSnapshot(1).units,1,"Returned Unit is recovered")

local reader=read("src/PlayingGame/PlayerBoard/CardRecognition.lua")
-- The mana candidate check must only supplement missing zone objects.
local manaCode=extract(reader,"local function unitManaCounts(unit,seatPos,source,crystalsOnly)",
    "local function unitAbilityPaid")
local blue={guid="blue",type="Figurine",color="Blue",resting=true,moving=false,
    position={x=0,z=0},isSmoothMoving=function(self) return self.moving end,
    getPosition=function(self) return self.position end}
local inventory={guid="inventory",type="Figurine",color="Blue",resting=true,moving=false,
    position={x=30,z=0},isSmoothMoving=function(self) return self.moving end,
    getPosition=function(self) return self.position end}
objects.blue=blue
objects.inventory=inventory
objects.playZone={getObjects=function() return {} end}
local payment=assert(load([[
local trackerPrivate={unitManaCandidatesBySeat={[1]={blue=true,inventory=true}}}
local playerUnitAreas={[1]="unitZone"}
local playerPlayAreas={[1]="playZone"}
local function footprint() return {x=0,z=0,halfX=1.2,halfZ=1.4} end
local function manaInsideFootprint(m,area)
    local p=m.getPosition()
    return math.abs(p.x-area.x)<area.halfX and math.abs(p.z-area.z)<area.halfZ
end
local function manaColor(obj) return obj.color end
local function isManaTokenFigurine(obj) return obj.type=="Figurine" end
]]..manaCode..[[
return unitManaCounts
]],"Unit payment fallback","t",_G))()
eq(payment(unit,1,{}).Blue,1,"Stacked settled blue crystal pays Northern Monks")
eq(payment(unit,1,{blue}).Blue,1,"Zone and candidate do not double-count one crystal")
blue.held_by_color="Blue"
eq(payment(unit,1,{}).Blue,nil,"Held crystal does not pay the Unit")
blue.held_by_color=nil
blue.moving=true
eq(payment(unit,1,{}).Blue,nil,"Moving crystal does not pay the Unit")
blue.moving=false
blue.position.x=20
eq(payment(unit,1,{}).Blue,nil,"Crystal removed from Unit no longer pays")
blue.position.x=0
eq(payment(unit,1,{}).Blue,1,"Replacing crystal restores paid ability")

dofile("src/PlayingGame/PlayerBoard/UnitResources.lua")
local abilities=assert(unitResourceDefinitions[unit.guid])
eq(abilities[3].attackIce,4,"Northern Monks Ice Attack 4")
eq(abilities[4].blockIce,4,"Northern Monks Ice Block 4")
local decisionCode=extract(reader,"local function unitAbilityPaid(ability,counts)",
    "-- Earlier Command activations own")
local decide=assert(load([[
local resourceCardsGoldAllowed=function() return false end
local resourceCardsBlackAllowed=function() return false end
local unitManaCounts=function() error("Pass explicit mana counts") end
local unitManaDecision
]]..decisionCode..[[
return unitManaDecision
]],"Unit mana decision","t",_G))()
local attackActivation={seatPos=1,choice=1}
local blueAttack=decide(unit,abilities,attackActivation,{Blue=1})
eq(blueAttack.index,3,"Attack 3 upgrades to Ice Attack 4")
eq(#blueAttack.display,2,"Both blue paid alternatives remain selectable")
eq(decide(unit,abilities,{seatPos=1,choice=2},{Blue=1}).index,4,
    "Block 3 upgrades to Ice Block 4")
eq(decide(unit,abilities,{seatPos=1,choice=1},{}).index,1,
    "Without blue payment basic Attack remains")

-- Unit target buttons are built only when the refreshed combat is known.
local targetCode=extract(reader,"local function unitAbilityTargetCategory(ability)",
    "-- The printed normal and powered effects share one choice")
local buttonCode=extract(reader,
    "local function showUnitAbilityButtons(unit,abilities,activation,unwounded,decision,useIndex)",
    "local function clearChoiceButtons()")
local ui=assert(load([[
local combatCalcOn=true
local combatPsychicActive=false
local combatCumbersomeActive=false
local combatConfig={sourceFields={{key="attack"},{key="block"},
    {key="attackIce"},{key="blockIce"}},unitCombatBlocked=function() return false end}
local function unitHistoryKey(guid,index) return index==1 and guid or guid.."#use"..index end
local function unitHistorySelectedNumber() return 1 end
local function unitHistoryIsCombatAbility() return false end
local unitManaDecision=function() error("Explicit decision required") end
local choiceButtonShown,choiceExpandedByGUID={},{}
local choiceLetters={}
local function resourceObjectUiXmlTable(u) return u.nodes or {} end
local function resourceCardsChoiceIcon() return nil end
local function resourceCardsChoiceAssetsFor() return nil,{} end
local function resourceObjectUiSetTable(u,xml) u.nodes=xml end
local function removeChoiceButtons(u) u.nodes={} end
]]..targetCode..buttonCode..[[
return function(unit,abilities,activation,decision)
    showUnitAbilityButtons(unit,abilities,activation,true,decision,1)
    return unit.UI.nodes
end
]],"Northern Monks target buttons","t",_G))()
unit.UI={nodes={}}
local buttons=ui(unit,abilities,attackActivation,blueAttack)
assert(hasButton(buttons,"ResourceCardChoice_f17813_unit3"),
    "Paid Ice Attack choice must be visible")
assert(hasButton(buttons,"AttackAssignmentSource_f17813_0_attackIce"),
    "Paid Ice Attack needs a combat enemy target")
local count=#buttons
buttons=ui(unit,abilities,attackActivation,blueAttack)
eq(#buttons,count,"Target buttons survive a repeated settled refresh")
assert(hasButton(buttons,"AttackAssignmentSource_f17813_0_attackIce"),
    "Target button remains after retarget refresh")

-- The pending scan, not the drop or crystal zone event, owns Unit controls.
assert(reader:find("local missingActiveUnit=false",1,true),
    "Settled scan must recover active Units missed by zones")
assert(reader:find("trackerPrivate.unitManaCandidatesBySeat[seat][obj.guid]=true",1,true),
    "Mana dropped above thin zones must trigger Unit payment checks")
local refresh=extract(reader,"function resourceUnitsRefreshButtons()",
    "-- Reconstruct used Units from Command tokens")
assert(refresh:find("resourceCardsSourceChanged()",1,true),
    "External UI refreshes queue the settled scan")
assert(not refresh:find("showUnitAbilityButtons(",1,true),
    "External refreshes may not paint Unit controls before combat state is known")
local events=read("src/PlayingGame/PlayerBoard/Events.lua")
assert(events:find("if not activeUnit then playerBoardClearObjectUIIfPresent(obj) end",1,true),
    "Play Area zone exits must not erase active Unit buttons")

print("Unit activation settled-payment and enemy-target regressions passed")

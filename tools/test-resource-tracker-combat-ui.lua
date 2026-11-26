-- Related regressions share a runner and fixtures while each case retains local state.
-- Run from repository root: lua5.2 tools/test-resource-tracker-combat-ui.lua

local function eq(actual,expected,label)
    assert(actual==expected,(label or "Mismatch")..": expected "..tostring(expected)..", got "..tostring(actual))
end

local failures={}
local function run(name,body)
    local ok,message=xpcall(body,debug.traceback)
    if not ok then
        failures[#failures+1]=name..": "..tostring(message)
    end
end

run("resource-tracker-combat-display",function()
    -- Direct production formatting and grouped display tests.
    local traits={}
    local config={COMBAT_GREEN="green",enemyDefenceTraits=traits}
    local display=dofile("src/PlayingGame/PlayerBoard/ResourceTracker/Interface/CombatDisplay.lua")(config,
        function(text,color) return "<"..color..">"..text.."</"..color..">" end,
        function(data,perks,definitions)
            return {data=data,perks=perks,definitions=definitions}
        end)
    local function row(range,block,attack)
        return {range=range or {},block=block or {},attack=attack or {}}
    end
    local allocated={
        [1]=row({"r1","r2","r3"},{"b1","b2","b3"},{"a1"}),
        [2]=row({"r4"},{"b4"},{"a2","a3","a4"}),
        [3]=row({},{"b5"},{})
    }
    local rows,overflow=display.groupResourceRows({1,2},allocated,2)
    eq(rows[1].range[2],"r2","Ranged icons fill first group row")
    eq(rows[2].range[1],"r3","Ranged icons spill to next group row")
    eq(rows[2].range[2],"r4","Original range order retained")
    eq(rows[1].attack[2],"a2","Melee icons shared across group")
    eq(rows[2].attack[2],"a4","Melee order retained")
    eq(rows[1].block[2],"b2","Block stays on owning row first")
    eq(rows[2].block[1],"b4","Second enemy's own Block shown before overflow")
    eq(rows[2].block[2],"b3","Overflow fills remaining group slot")
    eq(rows[3],nil,"No spill outside group")
    eq(overflow,0,"All group icons fit")
    eq(#allocated[1].range,3,"Physical allocation list unchanged")
    eq(#allocated[1].block,3,"Original Block allocation unchanged")
    rows,overflow=display.groupResourceRows({1},allocated,2)
    eq(overflow,2,"Single enemy counts hidden range and Block icons")
    eq(rows[2],nil,"Single enemy never uses unrelated row")
    eq(display.groupAttackLine(0,4),nil,"No Attack produces no line")
    eq(display.groupAttackLine(3,4),"Attack 3/4","Insufficient Attack displayed")
    eq(display.groupAttackLine(4,4),"Attack 4/4 <green>Defeated</green>","Defeat uses calculated Attack")
    local full={"one","two"}
    eq(display.compactResultLines(full,{},{}),full,"Full result retained without expansion markers")
    local entry={data={elusive=true,defend=2},perks={arcaneImmunity=true}}
    local group={data={fortified=true,fResist=true,pResist=true},perks={wallFortified=true}}
    local shared=display.groupTraitsText(entry,group)
    eq(shared.data.elusive,true,"Individual Elusive preserved")
    eq(shared.data.defend,2,"Individual Defend preserved")
    eq(shared.perks.arcaneImmunity,true,"Individual perk immunity retained")
    eq(shared.data.fortified,true,"Group fortification shared")
    eq(shared.data.fResist,true,"Group resistance shared")
    eq(shared.perks.wallFortified,true,"Group wall shared")
    eq(shared.definitions,traits,"Live trait definitions forwarded")
    eq(entry.data.fResist,nil,"Printed token data unchanged")
    local notes=display.damageNotes({assassination=true},{
        units={{unit={name="Shocktroops"},wounded=true,wounds=2,destroyed=true,forced=true},
            {unit={name="Golems"},wounded=false}},
        heroWounds=1,discard=1,veilWoundIgnored=true,prevented=2,elementPrevented=1,paralyse=true})
    eq(notes[1],"Wounds: Shocktroops (2), Hero (1) Poison (1) (Veil of Mist: 1 Wound ignored)","Wound distribution")
    eq(notes[2],"Battle Hardened: -2 Hero damage","Mitigation displayed")
    eq(notes[3],"Elemental Resistance: -1 Hero damage","Elemental mitigation displayed")
    eq(notes[4],"Resisted (no Wound): Golems","Resisting Unit displayed")
    eq(notes[5],"Destroyed (Paralyse): Shocktroops","Destroyed Unit displayed")
    eq(notes[6],"Must take damage first: Shocktroops","Forced target displayed")
    eq(notes[7],"Assassination","Assassination displayed")
    eq(notes[8],"Paralyse: discard hand","Hero paralysis displayed")
    eq(display.damageNotes({},{units={},heroWounds=0,discard=0})[1],"Wounds: None","No damage display")
    print("Combat display text, grouped resource rows and damage notes passed")
end)

run("resource-tracker-combat-presentation",function()
    -- Exercise extracted presentation with captured UI writes and resolved combat data.
    local root="src/PlayingGame/PlayerBoard/ResourceTracker/"
    local ui,icons={},{}
    local iconCalls,uiCalls=0,0
    local function set(id,key,value)
        uiCalls=uiCalls+1
        ui[id]=ui[id] or {}
        ui[id][key]=value
    end
    local function icon(id,active,amount,image,tooltip,selected,color,wounded,ineffective)
        iconCalls=iconCalls+1
        icons[id]={active=active,amount=amount,tooltip=tooltip,selected=selected,color=color,wounded=wounded,ineffective=ineffective}
    end
    local layout=dofile(root.."Interface/CombatPanel.lua").layout
    eq(layout.estimatedTextWidth("Wi"),35,"Glyph widths retained")
    for i=1,520 do layout.estimatedTextWidth("different "..i) end
    eq(layout.estimatedTextWidth("Wi"),35,"Bounded width cache preserves exact sizing")
    eq(layout.textColumnWidth({"<color=red>Wide</color>\nI"},0),
        math.max(74,layout.estimatedTextWidth("Wide")),"Rich text sizing unchanged")
    local cfg={rowCount=2,slotCount=12,lineSlotCount=6,rowHeight=30,
        columns={Result=255},traitColumnWidth=layout.traitColumnWidth,
        textColumnWidth=layout.textColumnWidth,enemyNameColumnWidth=layout.enemyNameColumnWidth,
        effectSources={},slotBowFamilies={},slotSelection={},resultRowCache={},
        artifactCombat={},typeColors={P={"white","grey"}},COMBAT_GREEN="green",COMBAT_RED="red"}
    local function rich(s) return s end
    local panel=dofile(root.."Interface/CombatPanel.lua").renderer(cfg,set,rich,
        function(n) return tostring(n).." Wounds" end,function(lines) return table.concat(lines," ") end)
    local widths,w=panel.columns({"None","Resist"},{"","-"},{"P 3",""},
        {range=false,block=true,attack=false},{range=0,block=8,attack=0},100)
    local beforeLayout=uiCalls
    local sameWidths,sameW=panel.columns({"None","Resist"},{"","-"},{"P 3",""},
        {range=false,block=true,attack=false},{range=0,block=7,attack=0},100)
    eq(uiCalls,beforeLayout,"Same layout and capped icon count skip all column writes")
    eq(sameWidths.block,widths.block,"Cached widths retained")
    eq(sameW,w,"Cached base width retained")
    sameWidths.block=0
    local stable=panel.columns({"None","Resist"},{"","-"},{"P 3",""},
        {range=false,block=true,attack=false},{range=0,block=8,attack=0},100)
    eq(stable.block,widths.block,"Caller cannot mutate cached widths")
    panel.columns({"None","Resist"},{"","-"},{"",""},
        {range=false,block=true,attack=false},{range=0,block=8,attack=0},100)
    eq(ui.CombatEnemyAttackHeader.active,"false","Changed text invalidates layout")
    panel.columns({"None","Resist"},{"","-"},{"P 3",""},
        {range=false,block=true,attack=false},{range=0,block=8,attack=0},100)
    eq(widths.block,144,"Resource grid width capped at six icons")
    eq(ui.CombatSourceGrid1block.constraintCount,"6","Grid matches column width")
    eq(ui.CombatSourceCell2range.active,"false","Empty resource column hidden")
    eq(ui.CombatDefenceTraitsHeader.active,"true","Visible traits retain column")
    eq(ui.CombatOffenceHeader.active,"false","Blank offence column hidden")
    eq(ui.CombatEnemyAttackHeader.active,"true","Visible attack text retains column")
    panel.finish(2,w,widths,100,{},1)
    eq(ui.CombatEnemyPanel.width,tostring(math.max(w+65,350)),"Panel uses calculated width plus visible Result")
    eq(ui.CombatMonsterHeader.preferredWidth,"100","Name header matches column")
    eq(ui.CombatResourceOverflow.active,"true","Overflow warning displayed")
    panel.finish(0,w,widths,100,{},1)
    eq(ui.CombatResourceOverflow.active,"false","Overflow warning clears")
    local effects={destroyCount=0,stagedDiscardCount=0,handDiscard=false}
    eq(panel.woundSummary(0,0,false,0,0,false,effects),0,"Empty summary has no height")
    eq(ui.CombatTotalRow.active,"false","Empty summary hidden")
    eq(panel.woundSummary(2,1,false,2,1,true,effects),22,"Wound summary uses normal height")
    eq(ui.CombatTotalDamage.text,"Draw: 2 Wounds (1 Poison)","Hero and poison wound totals")
    eq(ui.CombatApplyWounds.interactable,"true","Pending wounds enable apply")
    eq(panel.woundSummary(2,0,true,0,0,false,effects),40,"Knockout increases summary height")
    eq(ui.CombatKnockoutWarning.active,"true","Knockout warning visible")
    eq(ui.CombatApplyWounds.interactable,"false","Applied wounds cannot be reapplied")
    effects.destroyCount=1
    eq(panel.woundSummary(0,0,false,0,0,false,effects),22,"Unit destruction displayed without Hero wounds")
    eq(ui.CombatTotalDamage.text,"Apply: Destroy 1 Unit","Singular Unit destruction")
    effects.destroyCount=0
    effects.unitAssignments=1
    effects.unitCommitPending=true
    eq(panel.woundSummary(0,0,false,0,0,false,effects),22,"Unit-only damage keeps button visible")
    eq(ui.CombatTotalDamage.text,"Draw: 0 Wounds","Zero draws explicitly displayed")
    eq(ui.CombatApplyWounds.interactable,"true","Unit-only commitment enabled")
    effects.unitCommitPending=false
    eq(panel.woundSummary(0,0,false,0,0,false,effects),22,"Committed Unit assignment remains visible")
    eq(ui.CombatApplyWounds.interactable,"false","Committed Unit cannot be committed again")
    effects.unitAssignments=0
    cfg.effectButtonInfo=function(entry,applied)
        return {source={key=applied.key,guid=applied.key,name="Effect"},family="attack",
            arrow="other",requiresDefence=true,amount="-1",icon="effect",text="Armour -1"}
    end
    cfg.mitigationButtonInfo=function() return nil end
    local build=dofile(root.."Interface/CombatResourceDisplay.lua")(cfg,function() return nil end,
        function(detail) return detail.family end,function() return false end,
        function(members,perMember) return perMember,0 end)
    local e={guid="enemy",data={},baseArmour=3,attackReductions={},
        effect={applied={{key="effect",phaseAfterDamage=true}}},attackCount=1}
    local g={members={1},entry={data={}},attackArmour=3,attackTotal=2,fortification=0}
    local src={guid="unit",key="unit",name="Unit"}
    local block={wrongBlock={},lines={},damageItems={},reductions={},allBlocked=true}
    local display,overflow=build({e},{g},{{details={{source=src,detail={family="attack",
        key="attack",amount=2,icon="attack",text="Attack 2",typeKey="P"}}}}},
        {details={}}, {block},nil,{unit=true},{},{},nil,nil)
    eq(overflow,0,"No overflow")
    eq(display[1].attack[1].source.key,"effect","Effect button receives priority")
    eq(display[1].attack[2].wounded,true,"Wounded Unit remains visible")
    eq(cfg.effectSources.effect.requiresDefence,true,"Effect targeting metadata retained")
    local psychicDisplay=build({e},{g},{{details={{source=src,detail={family="influence",
        key="influence",amount=2,icon="influence",text="Influence 2",typeKey="M"}}}}},
        {details={}}, {block},nil,{},{},{},nil,nil)
    eq(#psychicDisplay[1].block,1,"Psychic Influence displayed as Block")
    eq(#psychicDisplay[1].attack,1,"Only the existing effect appears in Attack")
    local render=dofile(root.."Interface/CombatRowRenderer.lua")(cfg,set,icon,function() return false end,
        function() return "None" end,function() return {} end,rich,function() return 0 end,rich,
        function() return {} end,function(total,armour) return "Attack "..total.."/"..armour end,
        function(lines) return lines end,function() return nil end)
    local slots,choices,used,counts={},{},{range=false,block=false,attack=false},{range=0,block=0,attack=0}
    local height=render({e},{g},{block},display,nil,{},false,0,1,{},{},{},used,counts,
        slots,{selected="effect"},{},{},choices,nil,0)
    eq(slots.CombatSourceSlot1attack1,"effect","Effect icon clickable by source key")
    eq(icons.CombatSourceSlot1attack1.selected,true,"Selection retained")
    eq(icons.CombatSourceSlot1attack2.wounded,true,"Wounded source marked")
    eq(icons.CombatSourceSlot1attack2.color,"white","Invalid Attack retains its normal text color")
    eq(icons.CombatSourceSlot2attack1.active,false,"Unused row slot cleared")
    eq(ui.CombatEnemyRow1Result.text,"Attack 2/3","Authoritative Attack total rendered")
    eq(used.attack,true,"Attack column marked used")
    eq(counts.attack,2,"Visible maximum resource count updated")
    eq(height,30,"Single visible row height retained")
    eq(cfg.resultRowCache[1].guid,"enemy","Result cache belongs to enemy")
    local function redraw(entries,groups,blocks,lists,offset,visible)
        local currentSlots={}
        cfg.slotSelection={} cfg.slotBowFamilies={} cfg.resultRowCache={}
        render(entries,groups,blocks,lists,nil,{},false,offset,visible,{},{},{},
            {range=false,block=false,attack=false},{range=0,block=0,attack=0},
            currentSlots,{selected="effect"},{},{},choices,nil,0)
        return currentSlots
    end
    iconCalls=0
    local current=redraw({e},{g},{block},display,0,1)
    eq(iconCalls,2,"Only occupied slots visited after initial reconciliation")
    eq(current.CombatSourceSlot1attack1,"effect","Live click mapping rebuilt")
    iconCalls=0
    local smaller={{range={},block={},attack={display[1].attack[1]}}}
    current=redraw({e},{g},{block},smaller,0,1)
    eq(iconCalls,2,"One live and one removed slot reconciled")
    eq(icons.CombatSourceSlot1attack2.active,false,"Removed resource hidden")
    eq(current.CombatSourceSlot1attack2,nil,"Removed slot no longer clickable")
    iconCalls=0
    redraw({e},{g},{block},smaller,0,1)
    eq(iconCalls,1,"Cleared tail not visited again")
    iconCalls=0
    -- The hidden row may have a real enemy from the next page in displayByIndex.
    current=redraw({e,e},{g,g},{block,block},{smaller[1],display[1]},0,1)
    eq(iconCalls,1,"Off-page enemy never fills hidden row")
    eq(current.CombatSourceSlot2attack1,nil,"Off-page icon not clickable")
    iconCalls=0
    redraw({}, {}, {}, {},0,0)
    eq(iconCalls,1,"Disappearing enemy clears last occupied slot")
    eq(icons.CombatSourceSlot1attack1.active,false,"Disappearing row clears icons")
    iconCalls=0 uiCalls=0
    redraw({}, {}, {}, {},0,0)
    eq(iconCalls,0,"Already cleared rows perform no icon work")
    eq(uiCalls,0,"Already cleared rows perform no attribute work")
    current=redraw({e},{g},{block},display,0,1)
    eq(current.CombatSourceSlot1attack2,"unit","Reappearing row restores correct slot mapping")
    eq(icons.CombatSourceSlot1attack2.active,true,"Reappearing row restores icon")
    print("Combat resource lists, visible row rendering and panel summary passed")
end)

run("resource-tracker-icon-styling",function()
    -- Exercise the actual coordinator functions rather than duplicating styling.
    local f=assert(io.open("src/PlayingGame/PlayerBoard/CardRecognition.lua","r"))
    local code=f:read("*a") f:close()
    local first=assert(code:find("local function combatPanelSetAttribute(",1,true))
    local last=assert(code:find("combatConfig.COMBAT_RED=",first,true))
    local written,skipped,attrs=0,0,{}
    local private={combatPanelAttributes={}}
    dofile("src/PlayingGame/PlayerBoard/ResourceTracker/Core/Diagnostics.lua")(private)
    private.traceEnabled=true
    local tick=0
    private.profileClock=function() return tick end
    local count=private.profileCount
    private.profileCount=function(name)
        if name=="ui.attribute.skipped" then skipped=skipped+1 end
        count(name)
    end
    local config={slotSelection={slot={key="card"}}}
    local state={selected="card"}
    local env={trackerPrivate=private,combatConfig=config,combatAssignmentState=state,
        UI={setAttribute=function(id,key,value)
            written=written+1
            tick=tick+0.001
            attrs[id.."."..key]=value
        end}}
    setmetatable(env,{__index=_G})
    local draw=assert(load(code:sub(first,last-1).."\nreturn combatAssignmentIconButton","Icon styling","t",env))()
    draw("slot",true,2,"block","Block 2",true)
    eq(attrs["slotImage.width"],"24","Initial geometry applied")
    eq(attrs["slotAmount.text"],"2","Initial amount applied")
    local before,skipBefore=written,skipped
    draw("slot",true,2,"block","Block 2",true)
    eq(written,before,"Repeated icon causes no UI writes")
    eq(private.profileStats["ui.setAttribute"].count,written,"Only real UI calls timed")
    assert(math.abs(private.profileStats["ui.setAttribute"].ms-written)<0.001)
    eq(skipped-skipBefore,5+1,"Only six dynamic attributes enter cache on subsequent draws")
    state.selected=nil
    config.refreshSelectedSlots()
    eq(attrs["slot.color"],"rgb(0.85,0.82,0.72)","Selection change remains live")
    draw("slot",false,0,"","",false)
    eq(attrs["slot.active"],"false","Slot hides")
    draw("slot",true,3,"attack","Attack 3",false,"Red",true)
    eq(attrs["slotAmount.text"],"3","Reused slot updates amount")
    eq(attrs["slotImage.image"],"attack","Reused slot updates image")
    eq(attrs["slotAmount.color"],"Red","Reused slot updates text tint")
    eq(attrs["slot.color"],"rgb(0.90,0.37,0.35)","Wounded tint remains live")
    private.combatPanelAttributes={}
    local beforeReset=written
    draw("slot",true,3,"attack","Attack 3",false,"Red",true)
    assert(written-beforeReset>6,"Cleared attribute cache reapplies fixed style")
end)

run("resource-tracker-combat-interaction",function()
    -- Exercise extracted combat controls with live assignment tables.
    local root="src/PlayingGame/PlayerBoard/ResourceTracker/"
    local refreshes,changes,selectedRefreshes,arrows=0,0,0,{}
    local env={
        gStates={battleHardenedAttackKey="old",elementalResistanceAttackKey="old"},
        resourceCardsCombatTargetAcceptsSource=function(key,target) return target~="illegal" end,
        resourceCardsRefreshCombatEnemies=function() refreshes=refreshes+1 end,
        resourceCardsSourceChanged=function() changes=changes+1 end,
        attackAssignmentsSetSourceTarget=function(key,target,kind)
            arrows[key]={target=target,kind=kind}
        end,
        resourceCardsPanelOpen=function() return true end,
        resourceCardsPlayerCanEdit=function(color) return color=="Blue" end
    }
    setmetatable(env,{__index=_G})
    local interaction=assert(loadfile(root.."Combat/CombatInteraction.lua","t",env))()
    local state={seat=1,targets={},explicit={}}
    local cfg={artifactCombat={bow=true},slotBowFamilies={},bowSourceModes={},effectSources={},
        resultRowCache={},refreshSelectedSlots=function() selectedRefreshes=selectedRefreshes+1 end}
    local locked=false
    cfg.phaseKeyLocked=function(key) return locked end
    interaction.assignSource("0688d8","a",cfg,state)
    eq(state.targets["0688d8"],"a","Explicit source target")
    eq(state.explicit["0688d8"],true,"Explicit marker")
    eq(env.gStates.battleHardenedAttackKey,nil,"Changing target clears attack selector")
    eq(refreshes,1,"Assignment refreshes rows")
    eq(changes,1,"Assignment schedules source update")
    interaction.assignSource("0688d8","illegal",cfg,state)
    eq(state.targets["0688d8"],"a","Ineligible target rejected")
    locked=true
    interaction.assignSource("0688d8","b",cfg,state)
    eq(state.targets["0688d8"],"a","Committed source cannot move")
    interaction.forgetSource("0688d8",nil,cfg,state)
    eq(state.targets["0688d8"],"a","Committed source cannot be forgotten")
    locked=false
    interaction.forgetSource("0688d8","b",cfg,state)
    eq(state.targets["0688d8"],"b","Replacement arrow preserved")
    interaction.forgetSource("0688d8",nil,cfg,state)
    eq(state.targets["0688d8"],nil,"Removed arrow clears target")
    eq(state.explicit["0688d8"],nil,"Removed arrow clears explicit marker")
    state.targets.unit="a"
    state.targets["unit#use2"]="b"
    state.targets.unrelated="c"
    state.explicit.unit=true
    state.explicit["unit#use2"]=true
    state.selected="unit#use2"
    interaction.forgetPhysicalSourceTargets("unit",state)
    eq(state.targets.unit,nil,"Physical source cleared")
    eq(state.targets["unit#use2"],nil,"Historical source cleared")
    eq(state.targets.unrelated,"c","Unrelated target retained")
    eq(state.selected,nil,"Removed source selection cleared")
    local rows={"a","b"}
    local indices={1,2}
    local joined={}
    local function phaseLock(seat) return locked and {} or nil end
    local function activeSeat() return 1 end
    local function enemyData(guid) return {attackOnly=guid=="reminder"} end
    interaction.toggleGroup(1,phaseLock,activeSeat,rows,indices,enemyData,joined)
    eq(joined.a,nil,"Cannot join the first enemy")
    interaction.toggleGroup(2,phaseLock,activeSeat,rows,indices,enemyData,joined)
    eq(joined.b,true,"Group joins preceding enemy")
    locked=true
    interaction.toggleGroup(2,phaseLock,activeSeat,rows,indices,enemyData,joined)
    eq(joined.b,true,"Committed group cannot be changed")
    locked=false
    interaction.toggleGroup(2,phaseLock,activeSeat,rows,indices,enemyData,joined)
    eq(joined.b,nil,"Group separates")
    local expanded={}
    local rowOnly=0
    cfg.resultRowCache[1]={guid="a",hasDetails=true}
    cfg.refreshResultRowOnly=function(row) rowOnly=rowOnly+row end
    interaction.toggleResult(1,rows,cfg,expanded)
    eq(expanded.a,true,"Result expands")
    eq(rowOnly,1,"Cached result updates only its own row")
    local slots={CombatSourceSlot1attack1="card"}
    local function sources(seat)
        return {{key="card",ranged=0,siege=0,block=0,attack=4}}
    end
    local function cumbersome(guid) return false end
    local function arrowKind(source) return "armour" end
    interaction.assignmentClick("CombatSourceSlot1attack1","-1",slots,cfg,rows,state,sources,cumbersome,arrowKind)
    eq(state.selected,"card","Click selects source")
    interaction.assignmentClick("CombatSourceSlot2attack1","-1",slots,cfg,rows,state,sources,cumbersome,arrowKind)
    eq(state.targets.card,"b","Second click retargets")
    eq(state.explicit.card,true,"Moved source remains explicit")
    eq(arrows.card.kind,"armour","Arrow keeps numeric resource colour")
    eq(state.selected,nil,"Retarget clears selected source")
    cfg.slotBowFamilies.CombatSourceSlot1attack1="ranged"
    interaction.assignmentClick("CombatSourceSlot1attack1","-2",slots,cfg,rows,state,sources,cumbersome,arrowKind)
    eq(cfg.bowSourceModes["card#ranged"],"siege","Right-click changes Bow mode")
    interaction.assignmentClick("CombatSourceSlot1attack1","-2",slots,cfg,rows,state,sources,cumbersome,arrowKind)
    eq(cfg.bowSourceModes["card#ranged"],"double","Right-click restores Bow mode")
    interaction.forkedLightningPhaseClicked({color="Blue"},nil,"ResourceCardChoice_d01b70_forkPhase")
    eq(env.gStates.forkedLightningPhase,"attack","Forked Lightning chooses melee")
    interaction.forkedLightningPhaseClicked({color="Blue"},nil,"ResourceCardChoice_d01b70_forkPhase")
    eq(env.gStates.forkedLightningPhase,"range","Forked Lightning chooses ranged")
    print("Combat interaction controls passed")
end)

if #failures>0 then
    error(table.concat(failures,"\n\n"),0)
end

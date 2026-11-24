-- Exercise extracted presentation with captured UI writes and resolved combat data.
local root="src/PlayingGame/PlayerBoard/ResourceTracker/"
local function eq(actual,expected,label)
    assert(actual==expected,label..": expected "..tostring(expected)..", got "..tostring(actual))
end
local ui,icons={},{}
local function set(id,key,value)
    ui[id]=ui[id] or {}
    ui[id][key]=value
end
local function icon(id,active,amount,image,tooltip,selected,color,wounded,ineffective)
    icons[id]={active=active,amount=amount,tooltip=tooltip,selected=selected,wounded=wounded,ineffective=ineffective}
end
local layout=dofile(root.."Interface/CombatPanel.lua").layout
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
eq(icons.CombatSourceSlot2attack1.active,false,"Unused row slot cleared")
eq(ui.CombatEnemyRow1Result.text,"Attack 2/3","Authoritative Attack total rendered")
eq(used.attack,true,"Attack column marked used")
eq(counts.attack,2,"Visible maximum resource count updated")
eq(height,30,"Single visible row height retained")
eq(cfg.resultRowCache[1].guid,"enemy","Result cache belongs to enemy")
print("Combat resource lists, visible row rendering and panel summary passed")

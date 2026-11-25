-- A settled card's explicit calculator target takes precedence over a
-- leftover arrow. If no target is recorded, recover the persisted arrow.
-- Run: lua5.2 tools/test-combat-target-arrow-authority.lua
local function read(path)
    local f=assert(io.open(path,"r"))
    local text=f:read("*a")
    f:close()
    return text
end
local state={targets={rage="right"},explicit={rage=true}}
local arrows={rage={left=true}}
local env={
    combatAssignmentState=state,
    attackAssignmentsTargetGUIDs=function(key) return arrows[key] or {} end
}
setmetatable(env,{__index=_G})
local recover=dofile("src/PlayingGame/PlayerBoard/ResourceTracker/Combat/SourceTargetAllocation.lua")(env.attackAssignmentsTargetGUIDs).recoverTarget
local function target(source,rows) return recover(source,rows,state) end
local source={key="rage"}
local rows={left=1,right=2}

assert(target(source,rows)=="right" and state.targets.rage=="right",
    "Stale left arrow must not override a deliberate right target")
-- If the calculator has no target, the persistent arrow is a valid
-- recovery source (especially after a save/load).
state.targets.rage=nil
state.explicit.rage=nil
assert(target(source,rows)=="left" and state.targets.rage=="left"
    and state.explicit.rage==true,
    "Missing calculator target should recover the saved left arrow")
-- Deliberate retargeting updates the calculator, even when the old arrow
-- has not yet been synchronized by the UI.
state.targets.rage="right"
arrows.rage={left=true}
assert(target(source,rows)=="right",
    "Manual calculator retarget must remain authoritative")
arrows.rage={left=true,right=true}
state.targets.rage="left"
assert(target(source,rows)=="left",
    "Multiple independent arrows must not replace a valid primary target")
arrows.rage={}
state.targets.rage=nil
assert(target(source,rows)==nil and state.targets.rage==nil,
    "Fresh card with no lock still uses ordinary targeting fallback")
-- Exercise the real DamageSync function with observable UI reconciliation.
local code=read("src/PlayingGame/Combat/AttackAssignments.lua")
local first=assert(code:find("function attackAssignmentsDamageSync(spec)",1,true))
local last=assert(code:find("-- Uncommitted Unit allocations",first,true))
local rebuilds,redraws=0,0
local damageEnv={
    damageTargets={},damageButtonObjects={},damageOwnerSignatures={},damageTargetUnits={},
    damageButtonX={},damageSignature="",DAMAGE_BUTTON_LIMIT=6,
    combatCommittedLock=function() return nil end,
    damageUsedBy=function() return nil end,
    rebuildDamageButtons=function() rebuilds=rebuilds+1 end,
    refreshRenderedLines=function(force,verify)
        assert(force==false and verify==true,"Damage preview verifies rather than forces redraw")
        redraws=redraws+1
    end,
    hasRuntimeWork=function() return false end,
    resourceCardsPanelOpen=function() return true end,
    getObjectFromGUID=function() return nil end
}
setmetatable(damageEnv,{__index=_G})
assert(load(code:sub(first,last-1),"Damage sync","t",damageEnv))()
local function sync(damage,units)
    damageEnv.attackAssignmentsDamageSync({attacks={{key="enemy:1",owner="enemy",damage=damage}},units=units})
end
sync(4,{})
assert(rebuilds==1 and redraws==1 and damageEnv.damageSignature=="#NO_UNITS",
    "First no-Unit scan reconciles overlays")
sync(3,{})
assert(rebuilds==1 and redraws==1,"Subsequent no-Unit scan skips redraw")
assert(damageEnv.attackAssignmentsDamageSnapshot().attacks[1].damage==3,
    "Fast path preserves current attack snapshot")
sync(2,{unit=true})
assert(rebuilds==2 and redraws==2 and damageEnv.damageSpec.byOwner.enemy~=nil,
    "New eligible Unit restores damage controls")
damageEnv.damageTargets["enemy:1"]={"unit"}
sync(1,{})
assert(rebuilds==3 and redraws==3 and next(damageEnv.damageTargets)==nil,
    "Losing eligible Unit cleans existing assignment")
sync(0,{})
assert(rebuilds==3 and redraws==3,"Clean no-Unit state remains cheap")
-- The real geometry renderer must reuse only unchanged static lines.
local geometryStart=assert(code:find("local function positionAtHeight(",1,true))
local geometryEnd=assert(code:find("function attackAssignmentsAppendVectorLines(",geometryStart,true))
local positions={card={0,0,0},other={2,0,0},enemy={8,0,0},unit={9,0,3}}
local reads={}
local colors={other={0.5,0,1},attack={0,0,1},damage={1,0,0}}
local lock
local registry={a={sourceGUID="card",targetGUID="enemy",kind="attack"}}
local geomEnv={assignmentRegistry=registry,assignmentColors=colors,assignmentHeight=1.1,
    assignmentThickness=0.1,damageThickness=0.2,previewThickness=0.3,previewHeight=1.2,
    arrowHeadLength=0.34,arrowHeadAngle=0.4,
    assignmentBaseGUID=function(guid) return guid end,
    assignmentColorFor=function(kind) return colors[kind] or colors.other end,
    combatCommittedLock=function() return lock end,
    resourceCardsPanelOpen=function() return true end,
    unitHistorySourceBase=function(key) return key end,
    gStates={},readyUnitPending={},blockLinkPending={},targetingByPlayer={},
    damageTargets={},damageSpec={byKey={},attacks={},units={}},
    getObjectFromGUID=function(guid)
        if positions[guid]==nil then return nil end
        return {isDestroyed=function() return false end,
            getPosition=function() reads[guid]=(reads[guid] or 0)+1 return positions[guid] end}
    end}
setmetatable(geomEnv,{__index=_G})
local geometry=assert(load(code:sub(geometryStart,geometryEnd-1).."\nreturn activeVisualLines","Geometry cache","t",geomEnv))()
local initial=geometry()
assert(#initial==3)
local same=geometry()
assert(same[1]==initial[1] and same[2]==initial[2],"Unchanged geometry reused")
registry.b={sourceGUID="other",targetGUID="enemy",kind="attack"}
local before=reads.enemy
local added=geometry()
assert(#added==6 and reads.enemy==before+1,"Shared endpoint sampled once per pass")
local function has(lines,line)
    for _,candidate in ipairs(lines) do if candidate==line then return true end end
    return false
end
assert(has(added,initial[1]),"Adding another arrow preserves existing geometry")
positions.card={1,0,0}
local moved=geometry()
assert(not has(moved,initial[1]),"Moved source rebuilds its arrow")
positions.enemy={8,0,1}
local movedTarget=geometry()
for _,line in ipairs(moved) do assert(not has(movedTarget,line),"Moved target invalidates both arrows") end
registry.b=nil
registry.a.kind="other"
local recolored=geometry()
assert(#recolored==3 and recolored[1].color==colors.other)
lock={sourceKeys={card=true},positions={card={3,0,4}}}
local frozen=geometry()
assert(frozen[1].points[1][1]==3 and frozen[1].points[1][3]==4)
positions.card=nil
assert(geometry()[1]==frozen[1],"Frozen source survives missing live card")
lock=nil
assert(#geometry()==0,"Missing live source removes arrow and prunes cache")
positions.card={3,0,4}
assert(geometry()[1]~=frozen[1],"Restored live object is rebuilt")
geomEnv.damageTargets={hit={"unit"}}
geomEnv.damageSpec={byKey={hit={owner="enemy"}},attacks={},units={unit=true}}
local damage=geometry()
assert(#damage==4 and damage[4].color==colors.damage and damage[4].thickness==0.2)
assert(geometry()[4]==damage[4],"Headless damage geometry reused")
geomEnv.damageTargets={}
registry.a=nil
assert(#geometry()==0,"Removed assignments produce no stale lines")
-- Verify recovery after another vector owner removes, duplicates or recolours an arrow.
local helperStart=assert(code:find("local function assignmentLinesIntact(",1,true))
local helperEnd=assert(code:find("function attackAssignmentsRefreshReadyUI()",helperStart,true))
local desired={{points={{1,0,0},{2,0,0}},color={1,0,0},thickness=0.1}}
local current=desired
local writes=0
local vectorEnv={
    vectorLineKey=function(line) return line.key or "geometry" end,
    vectorComponents=function(vec) return vec[1],vec[2],vec[3] end,
    isAssignmentLine=function(line) return not line.foreign end,
    renderedAssignmentLineKeys={geometry=true},
    activeVisualLines=function() return desired end,
    vectorLineSignature=function() return "same" end,
    renderedSignature="same",
    attackAssignmentsAppendVectorLines=function() return desired end,
    Global={getVectorLines=function() return current end,setVectorLines=function() writes=writes+1 end}
}
setmetatable(vectorEnv,{__index=_G})
local refresh=assert(load(code:sub(helperStart,helperEnd-1).."\nreturn refreshRenderedLines","Vector verification","t",vectorEnv))()
refresh(false,true)
assert(writes==0,"Existing correct arrows skip vector write")
current={}
refresh(false,true)
assert(writes==1,"Missing arrow is repaired")
current={desired[1],desired[1]}
refresh(false,true)
assert(writes==2,"Duplicate arrow is repaired")
current={{color={0,0,1},thickness=0.1}}
refresh(false,true)
assert(writes==3,"Recoloured arrow is repaired")
current={desired[1],{key="unrelated",foreign=true,color={0,0,0}}}
refresh(false,true)
assert(writes==3,"Unrelated vectors do not require rewrite")
-- Exercise the real batch helper with observable publish and failure behaviour.
local batchFirst=assert(code:find("local sourceTargetBatch",1,true))
local batchLast=assert(code:find("-- A source can own several arrows",batchFirst,true))
local persisted,rendered,scheduled=0,0,0
local batchEnv={persistAssignments=function() persisted=persisted+1 end,
    refreshRenderedLines=function() rendered=rendered+1 end,
    scheduleRefresh=function() scheduled=scheduled+1 end}
setmetatable(batchEnv,{__index=_G})
local publish=assert(load(code:sub(batchFirst,batchLast-1).."\nreturn publishSourceTargetChange","Batch","t",batchEnv))()
local result=batchEnv.attackAssignmentsWithTargetBatch(function()
    publish(true) publish(false)
    assert(persisted==0 and rendered==0,"No intermediate redraw")
    batchEnv.attackAssignmentsWithTargetBatch(function() publish(true) end)
    return 42
end)
assert(result==42 and persisted==1 and rendered==1 and scheduled==1)
local ok=pcall(batchEnv.attackAssignmentsWithTargetBatch,function() publish(false) error("failure") end)
assert(not ok and persisted==2 and rendered==2,"Failure flushes and releases batch")
publish(false)
assert(persisted==3 and rendered==3 and scheduled==1,"Ordinary calls remain immediate")
print("Combat calculator target authority and damage sync regressions passed")

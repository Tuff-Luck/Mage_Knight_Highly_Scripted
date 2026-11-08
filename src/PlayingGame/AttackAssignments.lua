-- Persistent visual links between generated combat resources and enemy objects.

local assignmentColors={
	armour={1.0,0.55,0.1},   -- Attack, Ranged, Siege and anything else aimed at armour
	attack={0.25,0.6,1.0},   -- Block and anything that reduces or stops an enemy attack
	damage={1.0,0.1,0.1},    -- Damage that an unblocked enemy attack assigns to a Unit
	other={0.95,0.18,0.78}}
local DAMAGE_BUTTON_LIMIT=6
-- Damage phase state is runtime-only: every unblocked attack starts on the Hero until the player targets Units.
local damageTargets={}   -- attack key -> ordered Unit GUIDs
local damagePending=nil  -- {key=,color=} while the player is choosing a Unit for an attack
local damageSpec={attacks={},units={},byOwner={},byKey={},reserved={}}
local damageButtonObjects={}
local damageOwnerSignatures={}
local damageTargetUnits={}
local damageSignature=""
local assignmentThickness=0.08
local previewThickness=0.047
local assignmentHeight=1.1
local previewHeight=1.3
local arrowHeadLength=0.34
local arrowHeadAngle=0.55
local assignmentRegistry={}
local targetingByPlayer={}
local targetButtonObjects={}
local assignmentCounter=0
local refreshScheduled=false
local renderedSignature=nil
local renderedAssignmentLineKeys={}

-- A split source (one card feeding two targets) is keyed "<card guid>#<part>"; the physical object is the card.
local function assignmentBaseGUID(key)
	return type(key)=="string" and key:match("^[^#]+") or key
end

local function assignmentKeyMatches(entryKey,wanted)
	if entryKey==wanted then return true end
	return type(wanted)=="string" and wanted:find("#",1,true)==nil and assignmentBaseGUID(entryKey)==wanted
end

-- Resource names/parts map to an arrow kind: armour (orange), enemy attack (blue) or other (purple).
function attackAssignmentsKindFor(resource)
	local text=tostring(resource or ""):lower()
	if text:find("attack",1,true) or text:find("siege",1,true) or text:find("ranged",1,true)
		or text:find("range",1,true) then return "armour" end
	if text:find("block",1,true) or text:find("move",1,true)
        or text:find("influence",1,true) then return "attack" end
	return "other"
end

local function assignmentColorFor(kind)
	return assignmentColors[kind] or assignmentColors.other
end

local function colorComponentsMatch(color,wanted)
	local red=color[1] or color.r
	local green=color[2] or color.g
	local blue=color[3] or color.b
	if type(red)~="number" or type(green)~="number" or type(blue)~="number" then return false end
	if red>1 or green>1 or blue>1 then red,green,blue=red/255,green/255,blue/255 end
	return math.abs(red-wanted[1])<0.02
		and math.abs(green-wanted[2])<0.02
		and math.abs(blue-wanted[3])<0.02
end

local function assignmentColorMatches(color)
	if type(color)~="table" then return false end
	for _,wanted in pairs(assignmentColors) do
		if colorComponentsMatch(color,wanted) then return true end
	end
	return false
end

local function isAssignmentLine(line)
	return type(line)=="table" and assignmentColorMatches(line.color)
		and type(line.thickness)=="number"
		and (math.abs(line.thickness-assignmentThickness)<0.001 or math.abs(line.thickness-previewThickness)<0.001)
end

local function vectorComponents(vector)
	if type(vector)~="table" then return nil end
	return vector[1] or vector.x,vector[2] or vector.y,vector[3] or vector.z
end

local function vectorLineKey(line)
	if type(line)~="table" or type(line.points)~="table" then return nil end
	local parts={}
	for _,point in ipairs(line.points) do
		local x,y,z=vectorComponents(point)
		if type(x)~="number" or type(y)~="number" or type(z)~="number" then return nil end
		parts[#parts+1]=string.format("%.3f,%.3f,%.3f",x,y,z)
	end
	if #parts<2 or type(line.thickness)~="number" then return nil end
	return table.concat(parts,";")..":"..string.format("%.3f",line.thickness)
end

local function assignmentLineKeys(lines)
	local keys={}
	for _,line in ipairs(lines) do
		local key=vectorLineKey(line)
		if key~=nil then keys[key]=true end
	end
	return keys
end

function attackAssignmentsWithoutVectorLines(lines)
	local result={}
	for _,line in pairs(lines or {}) do
		local key=vectorLineKey(line)
		if not isAssignmentLine(line) and (key==nil or renderedAssignmentLineKeys[key]~=true) then
			result[#result+1]=line
		end
	end
	return result
end

local function positionAtHeight(position,height)
	return {position[1],height or assignmentHeight,position[3]}
end

local function assignmentLines(source,target,color,noHead)
	if source==nil or target==nil or source.isDestroyed() or target.isDestroyed() then return nil end
	color=color or assignmentColors.other
	local from=positionAtHeight(source.getPosition())
	local to=positionAtHeight(target.getPosition())
	local dx,dz=to[1]-from[1],to[3]-from[3]
	local distance=math.sqrt(dx*dx+dz*dz)
	if distance<0.01 then return nil end
	if noHead then return {{points={from,to},color=color,thickness=assignmentThickness,rotation={0,0,0}}} end
	local dirX,dirZ=dx/distance,dz/distance
	local pullBack=math.min(arrowHeadLength*3,distance*0.5)
	to={to[1]-dirX*pullBack,assignmentHeight,to[3]-dirZ*pullBack}
	local sideX,sideZ=-dirZ,dirX
	local lines={{points={from,to},color=color,thickness=assignmentThickness,rotation={0,0,0}}}
	for _,side in ipairs({-1,1}) do
		local backX=dirX*math.cos(arrowHeadAngle)+sideX*side*math.sin(arrowHeadAngle)
		local backZ=dirZ*math.cos(arrowHeadAngle)+sideZ*side*math.sin(arrowHeadAngle)
		local wing={to[1]-backX*arrowHeadLength,assignmentHeight,to[3]-backZ*arrowHeadLength}
		lines[#lines+1]={points={to,wing},color=color,thickness=assignmentThickness,rotation={0,0,0}}
	end
	return lines
end

local function activeVisualLines()
	local lines={}
	for _,entry in pairs(assignmentRegistry) do
		local assignment=assignmentLines(entry.source,entry.target,assignmentColorFor(entry.kind))
		for _,line in ipairs(assignment or {}) do lines[#lines+1]=line end
	end
	for key,guids in pairs(damageTargets) do
		local attack=damageSpec.byKey[key]
		local owner=attack~=nil and getObjectFromGUID(attack.owner) or nil
		for _,guid in ipairs(guids) do
			local assignment=assignmentLines(owner,getObjectFromGUID(guid),assignmentColors.damage,true)
			for _,line in ipairs(assignment or {}) do lines[#lines+1]=line end
		end
	end
	-- A forced first recipient is also a real damage assignment and should be visible
	-- without making the player click an additional control.
	for _,attack in ipairs(damageSpec.attacks) do
		local guid=attack.firstDamageUnit
		if guid~=nil and damageSpec.units[guid]==true and not attack.assassination then
			local manuallyLinked=false
			for _,manual in ipairs(damageTargets[attack.key] or {}) do
				if manual==guid then manuallyLinked=true break end
			end
			if not manuallyLinked then
				local owner=getObjectFromGUID(attack.owner)
				local assignment=assignmentLines(owner,getObjectFromGUID(guid),assignmentColors.damage,true)
				for _,line in ipairs(assignment or {}) do lines[#lines+1]=line end
			end
		end
	end
	if damagePending~=nil then
		local attack=damageSpec.byKey[damagePending.key]
		local owner=attack~=nil and getObjectFromGUID(attack.owner) or nil
		local player=Player[damagePending.color]
		local pointer=player~=nil and player.getPointerPosition() or nil
		if owner~=nil and pointer~=nil then
			lines[#lines+1]={points={positionAtHeight(owner.getPosition(),previewHeight),positionAtHeight(pointer,previewHeight)},
				color=assignmentColors.damage,thickness=previewThickness,rotation={0,0,0}}
		end
	end
	for color,pending in pairs(targetingByPlayer) do
		local player=Player[color]
		local pointer=player~=nil and player.getPointerPosition() or nil
		if pointer~=nil and pending.source~=nil and not pending.source.isDestroyed() then
			local from=positionAtHeight(pending.source.getPosition(),previewHeight)
			local to=positionAtHeight(pointer,previewHeight)
			lines[#lines+1]={points={from,to},color=assignmentColorFor(pending.kind),thickness=previewThickness,rotation={0,0,0}}
		end
	end
	return lines
end

function attackAssignmentsAppendVectorLines(lines)
	local assignmentLinesNow=activeVisualLines()
	local result=attackAssignmentsWithoutVectorLines(lines)
	for _,line in ipairs(assignmentLinesNow) do result[#result+1]=line end
	renderedAssignmentLineKeys=assignmentLineKeys(assignmentLinesNow)
	return result
end

local function vectorLineSignature(lines)
	local parts={}
	for _,line in ipairs(lines) do
		for _,point in ipairs(line.points or {}) do
			parts[#parts+1]=string.format("%.2f,%.2f,%.2f",point[1],point[2],point[3])
		end
		parts[#parts+1]=tostring(line.thickness)
		local color=line.color or {}
		parts[#parts+1]=tostring(color[1])..tostring(color[2])..tostring(color[3])
	end
	return table.concat(parts,";")
end

local function syncTargetButtons(monsters)
	local shouldShow=next(targetingByPlayer)~=nil
	local live={}
	if shouldShow then
        local candidates=resourceCardsCombatTargetObjects~=nil and resourceCardsCombatTargetObjects(monsters) or {}
        for guid,obj in pairs(candidates) do
            if obj~=nil and not obj.isDestroyed() then
                live[guid]=obj
                if targetButtonObjects[guid]==nil then
                    local bounds=obj.getBounds()
                    local diameter=bounds~=nil and bounds.size~=nil and bounds.size[1] or 1.5
                    local scale=obj.getScale()
                    local size=diameter/((scale~=nil and scale.x) or 1)*500
                    obj.createButton({
                        click_function="attackAssignmentTargetClicked",function_owner=Global,
                        label="",position={0,0.25,0},rotation={0,0,0},
                        width=size,height=size,color={0,0,0,0},
                    })
                    targetButtonObjects[guid]=obj
                end
            end
        end
    end
	for guid,obj in pairs(targetButtonObjects) do
		if live[guid]==nil then
			local liveObject=getObjectFromGUID(guid)
			if liveObject~=nil then
				for _,button in pairs(liveObject.getButtons() or {}) do
					if button.click_function=="attackAssignmentTargetClicked" then
						liveObject.removeButton(button.index)
					end
				end
			end
			targetButtonObjects[guid]=nil
		end
	end
end

-- Called by the event-driven combat scan; polling is reserved for pointer lines.
function attackAssignmentsRefreshTargetButtons(monsters)
    if next(targetingByPlayer)~=nil then syncTargetButtons(monsters) end
end

local function refreshRenderedLines(force)
	local signature=vectorLineSignature(activeVisualLines())
	if not force and signature==renderedSignature then return end
	Global.setVectorLines(attackAssignmentsAppendVectorLines(Global.getVectorLines() or {}))
	renderedSignature=signature
end

-- Static arrows are refreshed by object/assignment events. Only live pointer previews
-- need the repeating refresh loop.
local function hasRuntimeWork()
	return next(targetingByPlayer)~=nil or damagePending~=nil
end

local function scheduleRefresh()
	if refreshScheduled or not hasRuntimeWork() then return end
	refreshScheduled=true
	safeWaitTime("PlayingGame.AttackAssignments",function()
		refreshScheduled=false
		refreshRenderedLines()
		if hasRuntimeWork() then scheduleRefresh() end
	end,0.2)
end

local DAMAGE_DECAL_URL="https://steamusercontent-a.akamaihd.net/ugc/10727875827929703324/92E5145A412AFBE2EB1716DF8B6CF965359A0372/"
local damageButtonX={}

local function removeDamageButtons(obj)
	local buttons=obj.getButtons() or {}
	for i=#buttons,1,-1 do
		if tostring(buttons[i].click_function):find("^attackAssignmentDamage")~=nil then obj.removeButton(buttons[i].index) end
	end
	local decals,kept,found=obj.getDecals() or {},{},false
	for _,decal in ipairs(decals) do
		if tostring(decal.name):find("^DamageTarget")~=nil then found=true else kept[#kept+1]=decal end
	end
	if found then obj.setDecals(kept) end
end

local function damageUsedBy(guid,exceptKey)
	for key,guids in pairs(damageTargets) do
		if key~=exceptKey then
			for _,used in ipairs(guids) do
				if used==guid then return key end
			end
		end
	end
	return nil
end

-- Full-size invisible button over a free Unit card, used only while an attack is being targeted.
local function addDamageTargetButton(obj,clickFunction)
	if obj==nil or obj.isDestroyed() then return end
	local bounds=obj.getBounds()
	local scale=obj.getScale() or {x=1,y=1,z=1}
	if bounds==nil or bounds.size==nil then return end
	obj.createButton({click_function=clickFunction,function_owner=Global,label="",
		position={0,bounds.size[2]/(scale.y or 1)/2+0.2,0},rotation={0,0,0},
		width=bounds.size[1]/(scale.x or 1)*500,height=bounds.size[3]/(scale.z or 1)*500,color={0,0,0,0}})
	damageButtonObjects[obj.guid]=obj
end

local function rebuildDamageButtons()
    -- Change only owners whose attack buttons have changed. A Block adjustment
    -- often changes damage values but not the physical buttons/decals.
    local desiredOwners={}
    for owner,list in pairs(next(damageSpec.units)~=nil and damageSpec.byOwner or {}) do
        local obj=getObjectFromGUID(owner)
        if obj~=nil and not obj.isDestroyed() then
            local keys={}
            for _,attack in ipairs(list) do keys[#keys+1]=attack.key end
            local signature=table.concat(keys,"|")
            desiredOwners[owner]=signature
            if damageOwnerSignatures[owner]~=signature then
                if damageOwnerSignatures[owner]~=nil then removeDamageButtons(obj) end
                if damageButtonX[owner]==nil then
                    local bounds=obj.getBounds()
                    local scale=obj.getScale()
                    local radius=(bounds~=nil and bounds.size~=nil and bounds.size[1] or 1.5)
                        /((scale~=nil and scale.x) or 1)/2
                    local x=-(radius+0.35)
                    for _,decal in ipairs(obj.getDecals() or {}) do
                        local p=decal.position
                        local px=type(p)=="table" and (p[1] or p.x) or nil
                        if px~=nil and px<-0.8 then x=math.min(x,px-0.71) end
                    end
                    damageButtonX[owner]=x
                end
                local x=damageButtonX[owner]
                local decals=obj.getDecals() or {}
                for index in ipairs(list) do
                    local z=(index-(#list+1)/2)*0.65
                    obj.createButton({click_function="attackAssignmentDamageClick"..index,
                        function_owner=Global,label="",position={x,0.25,z},rotation={0,0,0},
                        width=300,height=300,color={0,0,0,0}})
                    decals[#decals+1]={name="DamageTarget"..index,url=DAMAGE_DECAL_URL,
                        position={-x,0.15,z},rotation={90,180,0},scale={0.5,0.5,1}}
                end
                obj.setDecals(decals)
                damageOwnerSignatures[owner]=signature
            end
            damageButtonObjects[owner]=obj
        end
    end
    for owner in pairs(damageOwnerSignatures) do
        if desiredOwners[owner]==nil then
            local obj=getObjectFromGUID(owner)
            if obj~=nil then removeDamageButtons(obj) end
            damageOwnerSignatures[owner]=nil
            damageButtonX[owner]=nil
            damageButtonObjects[owner]=nil
        end
    end
    -- Unit click overlays are separately reconciled, so a changed enemy does
    -- not touch every Unit card in the player's command row.
    local wanted={}
    if damagePending~=nil then
        local own={}
        for _,guid in ipairs(damageTargets[damagePending.key] or {}) do own[guid]=true end
        for guid in pairs(damageSpec.units) do
            if damageSpec.reserved[guid]==nil or damageSpec.reserved[guid]==damagePending.key then
                if own[guid] or damageUsedBy(guid,nil)==nil then wanted[guid]=true end
            end
        end
    end
    for guid in pairs(damageTargetUnits) do
        if wanted[guid]~=true then
            local obj=getObjectFromGUID(guid)
            if obj~=nil then removeDamageButtons(obj) end
            damageTargetUnits[guid]=nil
            damageButtonObjects[guid]=nil
        end
    end
    for guid in pairs(wanted) do
        if damageTargetUnits[guid]~=true then
            local obj=getObjectFromGUID(guid)
            if obj~=nil then
                addDamageTargetButton(obj,"attackAssignmentDamageUnitClicked")
                damageTargetUnits[guid]=true
            end
        end
    end
end
-- spec: attacks={{key,owner,damage,assassination,firstDamageUnit}} in token order, units={guid=true} for Units that can still be assigned
-- damage. Drops targets that no longer apply. An attack keeps its button only while it still has legal Units to pick
-- or an assignment to undo.
function attackAssignmentsDamageSync(spec)
    if resourceCardsPanelOpen~=nil and not resourceCardsPanelOpen() then return end
	damageSpec={attacks=spec.attacks,units=spec.units or {},byOwner={},byKey={},reserved={}}
	for _,attack in ipairs(spec.attacks) do
		damageSpec.byKey[attack.key]=attack
		local guid=attack.firstDamageUnit
		if guid~=nil and damageSpec.units[guid]==true and not attack.assassination then
			damageSpec.reserved[guid]=attack.key
		end
	end
	for key,guids in pairs(damageTargets) do
		local kept={}
		for _,guid in ipairs(damageSpec.byKey[key]~=nil and guids or {}) do
			if damageSpec.units[guid] and (damageSpec.reserved[guid]==nil
				or damageSpec.reserved[guid]==key) then kept[#kept+1]=guid end
		end
		damageTargets[key]=#kept>0 and kept or nil
	end
	local freeUnit=false
	for guid in pairs(damageSpec.units) do
		-- A Unit required by Shocktroops' effect is not free for other attacks.
		if damageSpec.reserved[guid]==nil and damageUsedBy(guid,nil)==nil then
			freeUnit=true
			break
		end
	end
	for _,attack in ipairs(spec.attacks) do
		if damageTargets[attack.key]~=nil or (freeUnit and not attack.assassination) then
			local list=damageSpec.byOwner[attack.owner] or {}
			damageSpec.byOwner[attack.owner]=list
			if #list<DAMAGE_BUTTON_LIMIT then list[#list+1]=attack end
		end
	end
	if damagePending~=nil then
		local visible=false
		for _,attack in ipairs(damageSpec.byOwner[damageSpec.byKey[damagePending.key] and damageSpec.byKey[damagePending.key].owner or ""] or {}) do
			if attack.key==damagePending.key then visible=true end
		end
		if not visible then damagePending=nil end
	end
	local parts={damagePending~=nil and damagePending.key or "-",tostring(freeUnit)}
	for _,attack in ipairs(spec.attacks) do
		local assigned=damageTargets[attack.key]
		parts[#parts+1]=attack.key.."="..tostring(attack.damage)..":"..(assigned~=nil and table.concat(assigned,",") or "")
			..":"..tostring(attack.firstDamageUnit or "")
	end
	local unitGUIDs={}
	for guid in pairs(damageSpec.units) do unitGUIDs[#unitGUIDs+1]=guid end
	table.sort(unitGUIDs)
	parts[#parts+1]=table.concat(unitGUIDs,",")
	local signature=table.concat(parts,";")
	if signature~=damageSignature then
		damageSignature=signature
		rebuildDamageButtons()
		-- Red damage lines coexist with Unit source-target lines. On block/unblock
		-- transitions, force reconciliation even if another system redrew vectors.
		refreshRenderedLines(true)
	end
	if hasRuntimeWork() then scheduleRefresh() end
end

function attackAssignmentsDamageTargetsOf(key)
	return damageTargets[key] or {}
end


-- Provisional Unit damage is a physical overlay, never a real Unit Wound until End Turn.
-- The tag/GM Notes deliberately prevent Resource Tracker scans and scoring from treating
-- these tokens as wounds. Keeping the live token GUIDs also makes recalculation idempotent.
local PREVIEW_WOUND_TAG="CombatPreviewWound"
local PREVIEW_WOUND_HEIGHT=1.16
local PREVIEW_WOUND_ALPHA=150/255
local previewWoundsByUnit={}
local previewUnitBags={}
local previewBagWarnings={}
local previewOrphansScanned=false
local previewParalysisClick="attackAssignmentParalysisMarkerNoop"

function attackAssignmentParalysisMarkerNoop() end

local function previewUnitMarker(unit,show)
    if unit==nil then return end
    local found={}
    for _,button in ipairs(unit.getButtons() or {}) do
        if button.click_function==previewParalysisClick then found[#found+1]=button.index end
    end
    if #found>0 then
        for i=#found,1,-1 do unit.removeButton(found[i]) end
    end
    if show~=true then return end
    -- Same free-floating red X convention as defeated enemy tokens.
    local bounds=unit.getBoundsNormalized()
    local scale=unit.getScale()
    local height=bounds~=nil and bounds.size~=nil and (bounds.size.y or bounds.size[2]) or 0
    local scaleY=scale~=nil and (scale.y or scale[2]) or 1
    unit.createButton({click_function=previewParalysisClick,function_owner=Global,label="X",
        position={0,math.max(0.12,height/(2*math.max(0.01,scaleY))+0.08),0},
        rotation={0,0,0},width=0,height=0,font_size=640,
        font_color={1,0.04,0.04},tooltip="Combat Calculator: Unit destroyed by Paralysis"})
end

local function previewWoundPosition(unit,seat,slot)
    local board=playerBoard~=nil and getObjectFromGUID(playerBoard[seat]) or nil
    local candidates={}
    local pos=unit.getPosition()
    local unitX,unitZ=pos.x or pos[1],pos.z or pos[3]
    if board~=nil then
        for _,point in ipairs(board.getSnapPoints() or {}) do
            local wound=false
            for _,tag in ipairs(point.tags or {}) do
                if tag=="Wound" then wound=true break end
            end
            if wound then
                local world=board.positionToWorld(point.position)
                local x,z=world.x or world[1],world.z or world[3]
                local dx=math.abs(x-unitX)
                local dz=math.abs(z-unitZ)
                if dx<1.6 and dz<2.5 then
                    candidates[#candidates+1]={x=x,z=z,distance=dx+dz*0.1}
                end
            end
        end
    end
    -- The three nearest Wound snaps belong to the Unit even after layout compression.
    if #candidates>=3 then
        table.sort(candidates,function(a,b) return a.distance<b.distance end)
        local three={candidates[1],candidates[2],candidates[3]}
        table.sort(three,function(a,b) return a.x<b.x end)
        local selected=three[slot]
        return {selected.x,PREVIEW_WOUND_HEIGHT,selected.z}
    end
    -- If a custom mat has no recognized snaps, keep the token at the standard wound row.
    return {unitX+(slot-2)*0.57,PREVIEW_WOUND_HEIGHT,-33.29}
end

local function previewWoundBag(seat)
    local guid=previewUnitBags[seat]
    local cached=guid~=nil and getObjectFromGUID(guid) or nil
    if cached~=nil then return cached end
    local board=playerBoard~=nil and getObjectFromGUID(playerBoard[seat]) or nil
    if board==nil then return nil end
    local boardPosition=board.getPosition()
    local centerX=boardPosition.x or boardPosition[1]
    local best,bestDistance=nil,math.huge
    for _,obj in ipairs(getObjects()) do
        if obj.getName()=="Unit Wounds" then
            local candidatePos=obj.getPosition()
            local distance=math.abs((candidatePos.x or candidatePos[1])-centerX)
            if distance<bestDistance then best,bestDistance=obj,distance end
        end
    end
    if best~=nil and bestDistance<20 then
        previewUnitBags[seat]=best.guid
        return best
    end
    if previewBagWarnings[seat]~=true then
        previewBagWarnings[seat]=true
        print("COMBAT PREVIEW: Missing Unit Wounds infinite bag for player mat "..tostring(seat))
    end
    return nil
end

local function previewDiscardWounds(entry)
    for _,guid in pairs(entry.guids or {}) do
        local obj=getObjectFromGUID(guid)
        if obj~=nil and obj.hasTag(PREVIEW_WOUND_TAG) then obj.destruct() end
    end
    if entry.kind=="destroyed" then previewUnitMarker(getObjectFromGUID(entry.unitGUID),false) end
end

-- Existing previews from a saved table may have no Lua registry. Sweep only marked
-- temporary objects; ordinary, permanent Unit Wounds must never be touched.
local function previewSweepOrphans()
    -- The production API always supplies getObjects; pure Lua targeting tests may not.
    if previewOrphansScanned or getObjects==nil then return end
    previewOrphansScanned=true
    for _,obj in ipairs(getObjects()) do
        if obj.hasTag(PREVIEW_WOUND_TAG) or obj.getGMNotes()=="Combat Preview Wound" then
            obj.destruct()
        elseif obj.type=="Card" and unitLayoutIsUnit~=nil and unitLayoutIsUnit(obj) then
            -- A saved Paralysis X can outlive the unsaved runtime registry.
            previewUnitMarker(obj,false)
        end
    end
end

function attackAssignmentsUnitPreviewClear()
    for guid,entry in pairs(previewWoundsByUnit) do
        if not entry.committed then previewDiscardWounds(entry) end
        previewWoundsByUnit[guid]=nil
    end
    previewSweepOrphans()
end

local function previewMakePermanent(token)
    if token==nil then return end
    token.setGMNotes("Unit Wound")
    if token.hasTag(PREVIEW_WOUND_TAG) then token.removeTag(PREVIEW_WOUND_TAG) end
    token.setColorTint({r=1,g=1,b=1,a=1})
    token.lock()
end

local function previewSpawnWound(entry,slot,position)
    if entry.guids[slot]~=nil or entry.pending[slot] then return end
    local bag=previewWoundBag(entry.seat)
    if bag==nil then return end
    entry.pending[slot]=true
    local function finish(token)
        if token==nil then return end
        -- TTS may invoke the callback after a previous recalculation has deleted it.
        token=getObjectFromGUID(token.guid)
        if token==nil then return end
        entry.pending[slot]=nil
        if entry.committed then
            previewMakePermanent(token)
            local unit=getObjectFromGUID(entry.unitGUID)
            token.setPosition(unit~=nil and previewWoundPosition(unit,entry.seat,slot) or position)
            return
        end
        if previewWoundsByUnit[entry.unitGUID]~=entry or
            (resourceCardsPanelOpen~=nil and not resourceCardsPanelOpen()) then
            token.destruct()
            return
        end
        -- This is a ghost, not a gameplay Wound until the End Turn boundary.
        token.setGMNotes("Combat Preview Wound")
        if not token.hasTag(PREVIEW_WOUND_TAG) then token.addTag(PREVIEW_WOUND_TAG) end
        token.setColorTint(entry.kind=="poison"
            and {r=0.32,g=1,b=0.38,a=PREVIEW_WOUND_ALPHA}
            or {r=1,g=1,b=1,a=PREVIEW_WOUND_ALPHA})
        local unit=getObjectFromGUID(entry.unitGUID)
        token.setPosition(unit~=nil and previewWoundPosition(unit,entry.seat,slot) or position)
        token.lock()
        entry.guids[slot]=token.guid
    end
    -- Spawn beside the source bag and classify immediately, before moving into the Unit zone.
    local bagPos=bag.getPosition()
    local token=bag.takeObject({position={bagPos.x or bagPos[1],(bagPos.y or bagPos[2])+2,bagPos.z or bagPos[3]},smooth=false,callback_function=finish})
    -- Mark it immediately as well as in the callback, before zone-entry scans.
    if token~=nil then finish(token) end
end

-- Called after damage is calculated, so full resistance creates no wound.
-- Paralysis is a destroyed Unit: show a red X rather than drawing Wounds.
function attackAssignmentsUnitPreviewSync(seat,results)
    if seat==nil or (resourceCardsPanelOpen~=nil and not resourceCardsPanelOpen())
        or (gStates~=nil and gStates.preEndTurn==true) then return end
    previewSweepOrphans()
    local wanted={}
    for _,result in pairs(results or {}) do
        for _,entry in ipairs(result.units or {}) do
            if entry.wounded==true and entry.unit~=nil then
                local guid=entry.unit.guid
                wanted[guid]={kind=entry.destroyed and "destroyed" or
                    ((entry.wounds or 1)>1 and "poison" or "normal"),seat=seat}
            end
        end
    end
    for guid,entry in pairs(previewWoundsByUnit) do
        local desired=wanted[guid]
        if desired==nil or desired.kind~=entry.kind or desired.seat~=entry.seat then
            previewDiscardWounds(entry)
            previewWoundsByUnit[guid]=nil
        end
    end
    for guid,desired in pairs(wanted) do
        local unit=getObjectFromGUID(guid)
        if unit~=nil then
            local entry=previewWoundsByUnit[guid]
            if entry==nil then
                entry={unitGUID=guid,seat=seat,kind=desired.kind,guids={},pending={}}
                previewWoundsByUnit[guid]=entry
                if desired.kind=="destroyed" then previewUnitMarker(unit,true) end
            end
            if desired.kind~="destroyed" then
                local slots=desired.kind=="poison" and {1,3} or {2}
                for _,slot in ipairs(slots) do
                    local position=previewWoundPosition(unit,seat,slot)
                    local tokenGUID=entry.guids[slot]
                    local token=tokenGUID~=nil and getObjectFromGUID(tokenGUID) or nil
                    if token~=nil then
                        local old=token.getPosition()
                        if math.abs(old.x-position[1])>0.025 or math.abs(old.z-position[3])>0.025
                            or math.abs(old.y-PREVIEW_WOUND_HEIGHT)>0.025 then token.setPosition(position) end
                    else
                        entry.guids[slot]=nil
                        previewSpawnWound(entry,slot,position)
                    end
                end
            end
        end
    end
end

-- This is the *end of turn*, not the end of round. Make Wounds official
-- before ordinary player-area cleanup runs. Closing the tracker instead
-- removes all pending ghosts without committing any of them.
function attackAssignmentsUnitPreviewCommit(seat)
    if seat==nil then return end
    for guid,entry in pairs(previewWoundsByUnit) do
        if entry.seat==seat then
            entry.committed=true
            if entry.kind=="destroyed" then
                previewUnitMarker(getObjectFromGUID(guid),false)
                local unit=getObjectFromGUID(guid)
                -- A Paralyzed Unit is destroyed rather than Wounded.
                local trash=getObjectFromGUID(trashCan)
                if unit~=nil and trash~=nil then
                    protectedObjectAllowScriptRemoval(unit.guid,trashCan,"Paralysis destroyed Unit")
                    trash.putObject(unit)
                end
            else
                for _,tokenGUID in pairs(entry.guids) do
                    local token=getObjectFromGUID(tokenGUID)
                    if token~=nil then previewMakePermanent(token) end
                end
            end
            previewWoundsByUnit[guid]=nil
        end
    end
end

function attackAssignmentsDamageClear()
	attackAssignmentsUnitPreviewClear()
	damageTargets={}
	damagePending=nil
	damageSpec={attacks={},units={},byOwner={},byKey={},reserved={}}
	damageSignature=""
	for guid in pairs(damageButtonObjects) do
		local obj=getObjectFromGUID(guid)
		if obj~=nil then removeDamageButtons(obj) end
	end
	damageButtonObjects={}
    damageOwnerSignatures={}
    damageTargetUnits={}
	damageButtonX={}
	refreshRenderedLines()
end

local function damageChanged()
	damageSignature=""
	if resourceCardsRefreshCombatEnemies~=nil then resourceCardsRefreshCombatEnemies() end
end

local function damageAttackClicked(obj,playerColor,index,altClick)
	local list=obj~=nil and damageSpec.byOwner[obj.guid] or nil
	local attack=list~=nil and list[index] or nil
	if attack==nil then return end
	-- Another player must not steal an in-progress Unit assignment.
	if damagePending~=nil and damagePending.color~=playerColor then return end
	if altClick then
		-- Right click returns the whole attack to the Hero.
		damageTargets[attack.key]=nil
		damagePending=nil
	elseif damagePending~=nil and damagePending.key==attack.key then
		-- Clicking the same damage target button twice returns all of this
		-- attack's manually assigned Unit wounds to the Hero.
		damageTargets[attack.key]=nil
		damagePending=nil
	else
		damagePending={key=attack.key,color=playerColor}
	end
	damageChanged()
end

for index=1,DAMAGE_BUTTON_LIMIT do
	_G["attackAssignmentDamageClick"..index]=function(obj,playerColor,altClick)
		return safeCallback("attackAssignmentDamageClick"..index,function() damageAttackClicked(obj,playerColor,index,altClick==true) end)
	end
end

-- Clicking a free Unit adds it to the attack in order; clicking one already on the attack returns its share to the Hero.
function attackAssignmentDamageUnitClicked(unit,playerColor)
	return safeCallback("attackAssignmentDamageUnitClicked",function()
		if damagePending==nil or unit==nil or damagePending.color~=playerColor then return end
		local key=damagePending.key
		local list=damageTargets[key] or {}
		for position,guid in ipairs(list) do
			if guid==unit.guid then
				table.remove(list,position)
				damageTargets[key]=#list>0 and list or nil
				damagePending=nil
				damageChanged()
				return
			end
		end
		if not damageSpec.units[unit.guid] then
			broadcastToColor("That Unit is Wounded and cannot be assigned damage.",playerColor,{1,0.6,0.2})
		elseif damageSpec.reserved[unit.guid]~=nil and damageSpec.reserved[unit.guid]~=key then
			broadcastToColor("This Unit must receive its protected enemy's damage first.",playerColor,{1,0.6,0.2})
		elseif damageUsedBy(unit.guid,key)~=nil then
			broadcastToColor("That Unit already takes damage from another attack this combat.",playerColor,{1,0.6,0.2})
		else
			list[#list+1]=unit.guid
			damageTargets[key]=list
			damagePending=nil
			damageChanged()
		end
	end)
end

local function persistAssignments()
	if gStates==nil then return end
	local saved={}
	for id,entry in pairs(assignmentRegistry) do
		saved[#saved+1]={id=id,sourceGUID=entry.sourceGUID,targetGUID=entry.targetGUID,
			resource=entry.resource,playerColor=entry.playerColor,kind=entry.kind}
	end
	table.sort(saved,function(a,b) return a.id<b.id end)
	gStates.attackAssignments=saved
end

local function removeAssignment(id)
	if assignmentRegistry[id]==nil then return false end
	local sourceGUID=assignmentRegistry[id].sourceGUID
	assignmentRegistry[id]=nil
	if resourceCardsCombatForgetSource~=nil and sourceGUID~=nil then resourceCardsCombatForgetSource(sourceGUID) end
	persistAssignments()
	refreshRenderedLines()
	if resourceCardsSourceChanged~=nil then resourceCardsSourceChanged() end
	return true
end

function attackAssignmentsBegin(source,resource,playerColor,additional,sourceKey,part)
    if resourceCardsPanelOpen~=nil and not resourceCardsPanelOpen() then return false end
	if source==nil or source.guid==nil or source.isDestroyed()
		or type(resource)~="string" or resource=="" or type(playerColor)~="string"
		or Player[playerColor]==nil then return false end
	sourceKey=sourceKey or source.guid
	local pending=targetingByPlayer[playerColor]
	if pending~=nil and pending.sourceGUID==sourceKey and pending.resource==resource then
		targetingByPlayer[playerColor]=nil
	else
		targetingByPlayer[playerColor]={source=source,sourceGUID=sourceKey,resource=resource,
			additional=additional==true,kind=attackAssignmentsKindFor(part or resource)}
	end
	syncTargetButtons()
	refreshRenderedLines()
	scheduleRefresh()
	return true
end

function attackAssignmentSourceClicked(player,value,id)
	return safeCallback("attackAssignmentSourceClicked",function()
        if resourceCardsPanelOpen~=nil and not resourceCardsPanelOpen() then return end
		if type(id)~="string" then return end
		local guid,rowIndex,category=id:match("^AttackAssignmentSource_([0-9a-f]+)_(%d+)_(.+)$")
		if guid==nil then return end
		-- "category@part" targets one resource of a card that splits its targets.
		local baseCategory,part=category:match("^(.-)@(.+)$")
		if baseCategory~=nil then category=baseCategory end
		rowIndex=tonumber(rowIndex)
		local resource=rowIndex>0 and ("set"..rowIndex..":"..category) or category
		local sourceKey=part~=nil and (guid.."#"..part) or guid
		if part~=nil then resource=resource.."@"..part end
		local color=player~=nil and player.color or nil
		local source=guid~=nil and getObjectFromGUID(guid) or nil
		if source==nil then return end
		local pending=type(color)=="string" and targetingByPlayer[color] or nil
		-- Left click moves the whole source to a single new target; right click keeps the
		-- existing arrow so one source can feed a second enemy.
		local additional=tostring(value)=="-2"
		if not additional and pending==nil then
			local removed=false
			for entryId,entry in pairs(assignmentRegistry) do
				if entry.sourceGUID==sourceKey then
					assignmentRegistry[entryId]=nil
					removed=true
				end
			end
			if removed then persistAssignments() end
		end
		attackAssignmentsBegin(source,resource,color,additional,sourceKey,part)
	end)
end

function attackAssignmentTargetClicked(target,playerColor)
	return safeCallback("attackAssignmentTargetClicked",function()
        if resourceCardsPanelOpen~=nil and not resourceCardsPanelOpen() then return end
		local pending=type(playerColor)=="string" and targetingByPlayer[playerColor] or nil
        local eligible=resourceCardsCombatTargetObjects~=nil and resourceCardsCombatTargetObjects() or {}
        if pending==nil or target==nil or target.guid==nil or eligible[target.guid]==nil then return end
        -- Summoned tokens redirect to their face-up owner in the same combat.
        local summoned=gStates~=nil and gStates.attackedMonsters~=nil
            and gStates.attackedMonsters[target.guid] or nil
        if summoned~=nil and summoned[3]=="summoned" and summoned[4]~=nil then
            target=eligible[summoned[4]]
            if target==nil then return end
        end
        if target.isDestroyed() or pending.source==nil or pending.source.isDestroyed() then return end
        if resourceCardsCombatTargetAcceptsSource~=nil
            and not resourceCardsCombatTargetAcceptsSource(pending.sourceGUID,target.guid) then
            broadcastToColor("Only Block/Move or attack reductions can target a reminder.",
                playerColor,{1,0.6,0.2})
            return
        end
		if tostring(pending.resource):find("move$")~=nil and resourceCardsCombatTargetAcceptsMove~=nil
			and not resourceCardsCombatTargetAcceptsMove(target.guid) then
			broadcastToColor("Move can only be assigned to a Cumbersome enemy.",playerColor,{1,0.6,0.2})
			return
		end
		local duplicate=false
		if not pending.additional then
			for entryId,entry in pairs(assignmentRegistry) do
				if entry.sourceGUID==pending.sourceGUID then assignmentRegistry[entryId]=nil end
			end
		end
		for _,entry in pairs(assignmentRegistry) do
			if entry.sourceGUID==pending.sourceGUID and entry.targetGUID==target.guid
				and entry.resource==pending.resource then duplicate=true break end
		end
        -- Each additional right-clicked Influence arrow is ONE extra point
        -- allocated to that enemy. Repeating it assigns more points, but never
        -- more than the physical card or Unit actually generated.
        if pending.additional and pending.resource=="influence" then
            local current=turnOrder~=nil and gStates~=nil
                and turnOrder[gStates.turnNumber] or nil
            local scan=current~=nil and resourceCardScanBySeat[current.seatPos] or nil
            local record=scan~=nil and scan.cards[pending.source.guid] or nil
            local maxPoints=record~=nil and record.resources~=nil
                and tonumber(record.resources.influence) or nil
            local existing=0
            for _,entry in pairs(assignmentRegistry) do
                if entry.sourceGUID==pending.sourceGUID then existing=existing+1 end
            end
            if maxPoints~=nil and existing>=maxPoints then
                broadcastToColor("All Influence points from this source are already targeted.",
                    playerColor,{1,0.6,0.2})
                return
            end
            duplicate=false
        end
		if not duplicate then
			assignmentCounter=assignmentCounter+1
			local id=tostring(assignmentCounter)
			assignmentRegistry[id]={id=id,source=pending.source,target=target,
				sourceGUID=pending.sourceGUID,targetGUID=target.guid,
				resource=pending.resource,playerColor=playerColor,kind=pending.kind}
			persistAssignments()
		end
		targetingByPlayer[playerColor]=nil
		syncTargetButtons()
		refreshRenderedLines()
		if not pending.additional and resourceCardsCombatAssignSource~=nil then
			resourceCardsCombatAssignSource(pending.sourceGUID,target.guid)
		elseif pending.additional and resourceCardsSourceChanged~=nil then
			resourceCardsSourceChanged()
		end
	end)
end

-- Called by the Attack Assignment panel so both interfaces show the same single target.
function attackAssignmentsSetSourceTarget(sourceGUID,targetGUID,kind)
    if resourceCardsPanelOpen~=nil and not resourceCardsPanelOpen() then return end
	local source,target=getObjectFromGUID(assignmentBaseGUID(sourceGUID)),getObjectFromGUID(targetGUID)
	if source==nil or target==nil then return end
    if monsterPugs[targetGUID]==nil
        and (resourceCardsCombatTargetObjects==nil
            or resourceCardsCombatTargetObjects()[targetGUID]==nil) then return end
    if resourceCardsCombatTargetAcceptsSource~=nil
        and not resourceCardsCombatTargetAcceptsSource(sourceGUID,targetGUID) then return end
	for entryId,entry in pairs(assignmentRegistry) do
		if entry.sourceGUID==sourceGUID then assignmentRegistry[entryId]=nil end
	end
	assignmentCounter=assignmentCounter+1
	local id=tostring(assignmentCounter)
	assignmentRegistry[id]={id=id,source=source,target=target,sourceGUID=sourceGUID,
		targetGUID=targetGUID,resource="panel",playerColor=nil,kind=kind}
	persistAssignments()
	refreshRenderedLines()
	scheduleRefresh()
end

-- Auto-targeted sources get the same arrow a manual assignment would draw.
function attackAssignmentsEnsureTarget(sourceGUID,targetGUID,kind)
	for _,entry in pairs(assignmentRegistry) do
		if entry.sourceGUID==sourceGUID and entry.targetGUID==targetGUID then
			if kind~=nil and entry.kind~=kind then
				entry.kind=kind
				persistAssignments()
				refreshRenderedLines()
			end
			return
		end
	end
	attackAssignmentsSetSourceTarget(sourceGUID,targetGUID,kind)
end

-- Removes arrows of sources that still exist on the table but no longer offer that target
-- (for example when a card's choice stops splitting its resources).
function attackAssignmentsPruneInactive(activeKeys,activeObjects,keepsLock)
	local remove={}
	for id,entry in pairs(assignmentRegistry) do
		if activeKeys[entry.sourceGUID]~=true and (activeObjects[assignmentBaseGUID(entry.sourceGUID)]==true
			or (keepsLock~=nil and not keepsLock(entry.sourceGUID))) then
			remove[#remove+1]=id
		end
	end
	for _,id in ipairs(remove) do assignmentRegistry[id]=nil end
	if #remove>0 then
		persistAssignments()
		refreshRenderedLines()
	end
end

-- Preserve held/moving targets but prune arrows left on enemies outside combat.
function attackAssignmentsPruneTargets(eligible)
    local changed=false
    for id,entry in pairs(assignmentRegistry) do
        if eligible[entry.targetGUID]~=true then
            local target=getObjectFromGUID(entry.targetGUID)
            local inTransit=target~=nil
                and ((target.held_by_color~=nil and target.held_by_color~="")
                    or target.isSmoothMoving() or target.resting==false)
            if not inTransit then assignmentRegistry[id]=nil changed=true end
        end
    end
    if changed then
        persistAssignments()
        refreshRenderedLines()
    end
end

function attackAssignmentsIsTargeting(sourceGUID)
	for _,pending in pairs(targetingByPlayer) do
		if pending.sourceGUID==sourceGUID then return true end
	end
	return false
end

function attackAssignmentsHasAny()
	return next(assignmentRegistry)~=nil or next(targetingByPlayer)~=nil or next(damageTargets)~=nil or damagePending~=nil
end

function attackAssignmentsTargetGUIDs(sourceGUID)
	local targets={}
	for _,entry in pairs(assignmentRegistry) do
		if entry.sourceGUID==sourceGUID then targets[entry.targetGUID]=true end
	end
	return targets
end

-- Counts preserve repeated Influence arrows. A normal source uses the set
-- version above; a Psychic Influence source can spend more than one point
-- on a secondary enemy without duplicating any points in the calculator.
function attackAssignmentsTargetCounts(sourceGUID)
    local targets={}
    for _,entry in pairs(assignmentRegistry) do
        if entry.sourceGUID==sourceGUID then
            targets[entry.targetGUID]=(targets[entry.targetGUID] or 0)+1
        end
    end
    return targets
end

function attackAssignmentsRemove(id)
	return removeAssignment(tostring(id))
end

function attackAssignmentsClearForObject(objectOrGUID)
	local guid=type(objectOrGUID)=="string" and objectOrGUID
		or (objectOrGUID~=nil and objectOrGUID.guid or nil)
	if guid==nil then return 0 end
	local remove={}
	for id,entry in pairs(assignmentRegistry) do
		if assignmentKeyMatches(entry.sourceGUID,guid) or entry.targetGUID==guid then remove[#remove+1]=id end
	end
	for _,id in ipairs(remove) do assignmentRegistry[id]=nil end
	local pendingRemoved=false
	for color,pending in pairs(targetingByPlayer) do
		if assignmentKeyMatches(pending.sourceGUID,guid) then
			targetingByPlayer[color]=nil
			pendingRemoved=true
		end
	end
	if #remove>0 then persistAssignments() end
	if #remove>0 or pendingRemoved then
		syncTargetButtons()
		refreshRenderedLines()
		if resourceCardsSourceChanged~=nil then resourceCardsSourceChanged() end
	end
	return #remove
end

function attackAssignmentsObjectMoved(object)
    if resourceCardsPanelOpen~=nil and not resourceCardsPanelOpen() then return end
	if object==nil or object.guid==nil then return end
	local guid=object.guid
	local relevant=false
	for _,entry in pairs(assignmentRegistry) do
		if assignmentBaseGUID(entry.sourceGUID)==guid or entry.targetGUID==guid then relevant=true break end
	end
	if not relevant then
		for _,pending in pairs(targetingByPlayer) do
			if assignmentBaseGUID(pending.sourceGUID)==guid then relevant=true break end
		end
	end
	if not relevant then
		for key,guids in pairs(damageTargets) do
			local attack=damageSpec.byKey[key]
			if attack~=nil and attack.owner==guid then relevant=true break end
			for _,targetGUID in ipairs(guids) do
				if targetGUID==guid then relevant=true break end
			end
			if relevant then break end
		end
	end
	if not relevant then
		-- Forced recipients (e.g. Shocktroops) have red arrows without a
		-- manual damageTargets entry, so they need movement refreshes too.
		for _,attack in ipairs(damageSpec.attacks) do
			local forced=attack.firstDamageUnit
			if forced~=nil and damageSpec.units[forced]==true and not attack.assassination
				and (attack.owner==guid or forced==guid) then
				relevant=true
				break
			end
		end
	end
	if relevant then
		refreshRenderedLines()
		scheduleRefresh()
	end
end

function attackAssignmentsClearAll()
	attackAssignmentsDamageClear()
	assignmentRegistry={}
	targetingByPlayer={}
	assignmentCounter=0
	persistAssignments()
	syncTargetButtons()
	refreshRenderedLines()
end

function attackAssignmentsRestore()
    if resourceCardsPanelOpen~=nil and not resourceCardsPanelOpen() then
        attackAssignmentsClearAll()
        return
    end
	assignmentRegistry={}
	assignmentCounter=0
	-- Attack-only reminders and co-op Leader previews are valid combat targets
	-- even though they are not registered in monsterPugs.
	local eligible={}
	if resourceCardsCombatTargetObjects~=nil and gStates~=nil and turnOrder~=nil
		and playerUnitAreas~=nil and playerPlayAreas~=nil then
		eligible=resourceCardsCombatTargetObjects()
	end
	for _,saved in ipairs(gStates~=nil and gStates.attackAssignments or {}) do
		local source=getObjectFromGUID(assignmentBaseGUID(saved.sourceGUID))
		local target=getObjectFromGUID(saved.targetGUID)
		if source~=nil and target~=nil
			and (monsterPugs[target.guid]~=nil or eligible[target.guid]~=nil)
			and type(saved.resource)=="string" then
			local id=tostring(saved.id or "")
			if id=="" then
				assignmentCounter=assignmentCounter+1
				id=tostring(assignmentCounter)
			else
				assignmentCounter=math.max(assignmentCounter,tonumber(id) or 0)
			end
			assignmentRegistry[id]={id=id,source=source,target=target,
				sourceGUID=saved.sourceGUID,targetGUID=target.guid,
				resource=saved.resource,playerColor=saved.playerColor,kind=saved.kind}
		end
	end
	persistAssignments()
	refreshRenderedLines()
	scheduleRefresh()
end

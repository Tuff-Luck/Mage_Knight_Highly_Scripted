-- Persistent visual links between generated combat resources and enemy objects.

local assignmentColor={0.95,0.18,0.78}
local assignmentThickness=0.12
local previewThickness=0.07
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

local function assignmentColorMatches(color)
	if type(color)~="table" then return false end
	local red=color[1] or color.r
	local green=color[2] or color.g
	local blue=color[3] or color.b
	if type(red)~="number" or type(green)~="number" or type(blue)~="number" then return false end
	if red>1 or green>1 or blue>1 then red,green,blue=red/255,green/255,blue/255 end
	return math.abs(red-assignmentColor[1])<0.02
		and math.abs(green-assignmentColor[2])<0.02
		and math.abs(blue-assignmentColor[3])<0.02
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

local function assignmentLines(source,target)
	if source==nil or target==nil or source.isDestroyed() or target.isDestroyed() then return nil end
	local from=positionAtHeight(source.getPosition())
	local to=positionAtHeight(target.getPosition())
	local dx,dz=to[1]-from[1],to[3]-from[3]
	local distance=math.sqrt(dx*dx+dz*dz)
	if distance<0.01 then return nil end
	local dirX,dirZ=dx/distance,dz/distance
	local pullBack=math.min(arrowHeadLength*3,distance*0.5)
	to={to[1]-dirX*pullBack,assignmentHeight,to[3]-dirZ*pullBack}
	local sideX,sideZ=-dirZ,dirX
	local lines={{points={from,to},color=assignmentColor,thickness=assignmentThickness,rotation={0,0,0}}}
	for _,side in ipairs({-1,1}) do
		local backX=dirX*math.cos(arrowHeadAngle)+sideX*side*math.sin(arrowHeadAngle)
		local backZ=dirZ*math.cos(arrowHeadAngle)+sideZ*side*math.sin(arrowHeadAngle)
		local wing={to[1]-backX*arrowHeadLength,assignmentHeight,to[3]-backZ*arrowHeadLength}
		lines[#lines+1]={points={to,wing},color=assignmentColor,thickness=assignmentThickness,rotation={0,0,0}}
	end
	return lines
end

local function activeVisualLines()
	local lines={}
	for _,entry in pairs(assignmentRegistry) do
		local assignment=assignmentLines(entry.source,entry.target)
		for _,line in ipairs(assignment or {}) do lines[#lines+1]=line end
	end
	for color,pending in pairs(targetingByPlayer) do
		local player=Player[color]
		local pointer=player~=nil and player.getPointerPosition() or nil
		if pointer~=nil and pending.source~=nil and not pending.source.isDestroyed() then
			local from=positionAtHeight(pending.source.getPosition(),previewHeight)
			local to=positionAtHeight(pointer,previewHeight)
			lines[#lines+1]={points={from,to},color=assignmentColor,thickness=previewThickness,rotation={0,0,0}}
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
	end
	return table.concat(parts,";")
end

local function syncTargetButtons()
	local shouldShow=next(targetingByPlayer)~=nil
	local live={}
	if shouldShow then
		for _,obj in ipairs(getObjects()) do
			if obj~=nil and obj.guid~=nil and monsterPugs[obj.guid]~=nil and not obj.isDestroyed() then
				live[obj.guid]=obj
				if targetButtonObjects[obj.guid]==nil then
					local bounds=obj.getBounds()
					local diameter=bounds~=nil and bounds.size~=nil and bounds.size[1] or 1.5
					local scale=obj.getScale()
					local size=diameter/((scale~=nil and scale.x) or 1)*500
					obj.createButton({
						click_function="attackAssignmentTargetClicked",function_owner=Global,
						label="",position={0,0.25,0},rotation={0,0,0},
						width=size,height=size,
						color={0,0,0,0},
					})
					targetButtonObjects[obj.guid]=obj
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

local function refreshRenderedLines()
	local signature=vectorLineSignature(activeVisualLines())
	if signature==renderedSignature then return end
	Global.setVectorLines(attackAssignmentsAppendVectorLines(Global.getVectorLines() or {}))
	renderedSignature=signature
end

local function hasRuntimeWork()
	return next(assignmentRegistry)~=nil or next(targetingByPlayer)~=nil
end

local function scheduleRefresh()
	if refreshScheduled or not hasRuntimeWork() then return end
	refreshScheduled=true
	safeWaitTime("PlayingGame.AttackAssignments",function()
		refreshScheduled=false
		syncTargetButtons()
		refreshRenderedLines()
		if hasRuntimeWork() then scheduleRefresh() end
	end,0.2)
end

local function persistAssignments()
	if gStates==nil then return end
	local saved={}
	for id,entry in pairs(assignmentRegistry) do
		saved[#saved+1]={id=id,sourceGUID=entry.sourceGUID,targetGUID=entry.targetGUID,
			resource=entry.resource,playerColor=entry.playerColor}
	end
	table.sort(saved,function(a,b) return a.id<b.id end)
	gStates.attackAssignments=saved
end

local function removeAssignment(id)
	if assignmentRegistry[id]==nil then return false end
	assignmentRegistry[id]=nil
	persistAssignments()
	refreshRenderedLines()
	return true
end

function attackAssignmentsBegin(source,resource,playerColor,additional)
	if source==nil or source.guid==nil or source.isDestroyed()
		or type(resource)~="string" or resource=="" or type(playerColor)~="string"
		or Player[playerColor]==nil then return false end
	local pending=targetingByPlayer[playerColor]
	if pending~=nil and pending.sourceGUID==source.guid and pending.resource==resource then
		targetingByPlayer[playerColor]=nil
	else
		targetingByPlayer[playerColor]={source=source,sourceGUID=source.guid,resource=resource,additional=additional==true}
	end
	syncTargetButtons()
	refreshRenderedLines()
	scheduleRefresh()
	return true
end

function attackAssignmentSourceClicked(player,value,id)
	return safeCallback("attackAssignmentSourceClicked",function()
		if type(id)~="string" then return end
		local guid,rowIndex,category=id:match("^AttackAssignmentSource_([0-9a-f]+)_(%d+)_(.+)$")
		if guid==nil then return end
		rowIndex=tonumber(rowIndex)
		local resource=rowIndex>0 and ("set"..rowIndex..":"..category) or category
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
				if entry.sourceGUID==guid then
					assignmentRegistry[entryId]=nil
					removed=true
				end
			end
			if removed then persistAssignments() end
		end
		attackAssignmentsBegin(source,resource,color,additional)
	end)
end

function attackAssignmentTargetClicked(target,playerColor)
	return safeCallback("attackAssignmentTargetClicked",function()
		local pending=type(playerColor)=="string" and targetingByPlayer[playerColor] or nil
		if pending==nil or target==nil or target.guid==nil or monsterPugs[target.guid]==nil
			or target.isDestroyed() or pending.source==nil or pending.source.isDestroyed() 			then return end
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
		if not duplicate then
			assignmentCounter=assignmentCounter+1
			local id=tostring(assignmentCounter)
			assignmentRegistry[id]={id=id,source=pending.source,target=target,
				sourceGUID=pending.sourceGUID,targetGUID=target.guid,
				resource=pending.resource,playerColor=playerColor}
			persistAssignments()
		end
		targetingByPlayer[playerColor]=nil
		syncTargetButtons()
		refreshRenderedLines()
		if not pending.additional and resourceCardsCombatAssignSource~=nil then
			resourceCardsCombatAssignSource(pending.sourceGUID,target.guid)
		end
	end)
end

-- Called by the Attack Assignment panel so both interfaces show the same single target.
function attackAssignmentsSetSourceTarget(sourceGUID,targetGUID)
	local source,target=getObjectFromGUID(sourceGUID),getObjectFromGUID(targetGUID)
	if source==nil or target==nil or monsterPugs[targetGUID]==nil then return end
	for entryId,entry in pairs(assignmentRegistry) do
		if entry.sourceGUID==sourceGUID then assignmentRegistry[entryId]=nil end
	end
	assignmentCounter=assignmentCounter+1
	local id=tostring(assignmentCounter)
	assignmentRegistry[id]={id=id,source=source,target=target,sourceGUID=sourceGUID,
		targetGUID=targetGUID,resource="panel",playerColor=nil}
	persistAssignments()
	refreshRenderedLines()
	scheduleRefresh()
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
		if entry.sourceGUID==guid or entry.targetGUID==guid then remove[#remove+1]=id end
	end
	for _,id in ipairs(remove) do assignmentRegistry[id]=nil end
	local pendingRemoved=false
	for color,pending in pairs(targetingByPlayer) do
		if pending.sourceGUID==guid then
			targetingByPlayer[color]=nil
			pendingRemoved=true
		end
	end
	if #remove>0 then persistAssignments() end
	if #remove>0 or pendingRemoved then
		syncTargetButtons()
		refreshRenderedLines()
	end
	return #remove
end

function attackAssignmentsObjectMoved(object)
	if object==nil or object.guid==nil then return end
	local guid=object.guid
	local relevant=false
	for _,entry in pairs(assignmentRegistry) do
		if entry.sourceGUID==guid or entry.targetGUID==guid then relevant=true break end
	end
	if not relevant then
		for _,pending in pairs(targetingByPlayer) do
			if pending.sourceGUID==guid then relevant=true break end
		end
	end
	if relevant then
		refreshRenderedLines()
		scheduleRefresh()
	end
end

function attackAssignmentsClearAll()
	assignmentRegistry={}
	targetingByPlayer={}
	assignmentCounter=0
	persistAssignments()
	syncTargetButtons()
	refreshRenderedLines()
end

function attackAssignmentsRestore()
	assignmentRegistry={}
	assignmentCounter=0
	for _,saved in ipairs(gStates~=nil and gStates.attackAssignments or {}) do
		local source=getObjectFromGUID(saved.sourceGUID)
		local target=getObjectFromGUID(saved.targetGUID)
		if source~=nil and target~=nil and monsterPugs[target.guid]~=nil
			and type(saved.resource)=="string" then
			local id=tostring(saved.id or "")
			if id=="" then
				assignmentCounter=assignmentCounter+1
				id=tostring(assignmentCounter)
			else
				assignmentCounter=math.max(assignmentCounter,tonumber(id) or 0)
			end
			assignmentRegistry[id]={id=id,source=source,target=target,
				sourceGUID=source.guid,targetGUID=target.guid,
				resource=saved.resource,playerColor=saved.playerColor}
		end
	end
	persistAssignments()
	refreshRenderedLines()
	scheduleRefresh()
end

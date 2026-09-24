-- Runtime Unit/Command-slot layout and compression on player boards.

unitLayoutConfig={nativeSlots=6, firstOffset=-103.57, nativeSpacing=3.84, cardScale=1.5, associationRadius=2.05}
unitLayoutWait=unitLayoutWait or {}
unitLayoutExpanded=unitLayoutExpanded or {}

--Each native Unit slot has six attached player-board snap points:
--1 Banner, 2 Command (one also tagged Unit), and 3 Wound. When overflow compresses the
--Unit columns, rebuild only this snap family at the same dynamic X centres.
function unitLayoutSnapType(point)
	if point==nil then return nil end
	local banner=false
	local wound=false
	local command=false
	local unit=false
	for _,tag in ipairs(point.tags or {}) do
		if tag=="Banner" then banner=true
		elseif tag=="Wound" then wound=true
		elseif tag=="Command" then command=true
		elseif tag=="Unit" then unit=true end
	end
	if banner then return "banner" end
	if wound then return "wound" end
	if command and unit then return "unitCommand" end
	if command then return "command" end
	return nil
end

function refreshUnitLayoutSnapPoints(seatPos,commandCount)
	if seatPos==nil then return end
	local board=getObjectFromGUID(playerBoard[seatPos])
	if board==nil then return end
	local slotCount=math.max(unitLayoutConfig.nativeSlots,commandCount or 0)
	local snaps=board.getSnapPoints() or {}
	local kept={}
	local counts={banner=0,wound=0,unitCommand=0,command=0}
	for _,point in ipairs(snaps) do
		local snapType=unitLayoutSnapType(point)
		if snapType~=nil then counts[snapType]=counts[snapType]+1 else kept[#kept+1]=point end
	end

	--The stock board has 6/18/6/6 of these points. Dynamic versions preserve the same 1:3:1:1 ratio.
	--If a future board asset changes that family, leave it untouched rather than deleting unknown snaps.
	local currentSlots=counts.banner
	if currentSlots<1 or counts.wound~=currentSlots*3 or counts.unitCommand~=currentSlots or counts.command~=currentSlots then
		print("UNIT LAYOUT SNAP ERROR: Player "..tostring(seatPos).." board snap family was not recognised.")
		return
	end
	if currentSlots==slotCount then return end

	local boardPos=board.getPosition()
	for slot=1,slotCount do
		--positionToLocal automatically accounts for each board's 180 degree rotation and 8.2 scale.
		local localCenter=board.positionToLocal({unitLayoutX(seatPos,slot,slotCount),boardPos[2],boardPos[3]})
		local centerX=localCenter.x or localCenter[1]
		kept[#kept+1]={position={centerX,0,-0.155},tags={"Banner"}}
		kept[#kept+1]={position={centerX,0,-0.398},tags={"Unit","Command"}}
		kept[#kept+1]={position={centerX+0.070,0,-0.574},tags={"Wound"}}
		kept[#kept+1]={position={centerX,0,-0.574},tags={"Wound"}}
		kept[#kept+1]={position={centerX-0.070,0,-0.574},tags={"Wound"}}
		kept[#kept+1]={position={centerX,0,-0.830},tags={"Command"}}
	end
	board.setSnapPoints(kept)
end

function unitLayoutIsUnit(obj)
	if obj==nil then return false end
	local cardType=gameCardType(obj)
	return cardType=="Regular Unit" or cardType=="Elite Unit"
end

function unitLayoutIsCommand(obj)
	if obj==nil then return false end
	--Bonds of Loyalty is physically a Skill token, but while claimed in Norowas' Unit Area it provides
	--an extra Command slot exactly like Banner of Command. Its asset does not reliably carry the GM Note.
	return obj.getGMNotes()=="Command Token" or obj.getGMNotes()=="Bonds of Loyalty" or obj.guid==GUID.skill.bondsOfLoyalty or obj.guid==GUID.card.bannerOfCommandToken
end

function unitLayoutCommandPriority(obj)
	if obj==nil then return 9 end
	if obj.getGMNotes()=="Command Token" then return 1 end
	if obj.getGMNotes()=="Bonds of Loyalty" or obj.guid==GUID.skill.bondsOfLoyalty then return 2 end
	if obj.guid==GUID.card.bannerOfCommandToken then return 3 end
	return 9
end

function unitLayoutX(seatPos, slot, commandCount)
	local displayCount=math.max(unitLayoutConfig.nativeSlots, commandCount or unitLayoutConfig.nativeSlots)
	local width=unitLayoutConfig.nativeSpacing*(unitLayoutConfig.nativeSlots-1)
	local spacing=width/(displayCount-1)
	return (seatPos*40)+unitLayoutConfig.firstOffset+((slot-1)*spacing)
end

function unitLayoutCardScale(commandCount)
	if commandCount==nil or commandCount<=unitLayoutConfig.nativeSlots then return unitLayoutConfig.cardScale end
	return unitLayoutConfig.cardScale*((unitLayoutConfig.nativeSlots-1)/(commandCount-1))
end

--Only the Unit scripting zone defines Unit capacity; this preserves the Banner/Bonds behaviour the recruitment code already relied on.
function unitLayoutObjects(seatPos)
	local unitZone=getObjectFromGUID(playerUnitAreas[seatPos])
	if unitZone==nil then return {} end
	return unitZone.getObjects()
end

function unitLayoutSnapshot(seatPos)
	local objects=unitLayoutObjects(seatPos)
	local commands={}
	local units={}
	local unitByGuid={}
	for _, obj in pairs(objects) do
		if unitLayoutIsCommand(obj) then commands[#commands+1]=obj end
		if unitLayoutIsUnit(obj) then units[#units+1]=obj unitByGuid[obj.guid]=obj end
	end
	table.sort(commands, function(a,b)
		local ax=a.getPosition()[1]
		local bx=b.getPosition()[1]
		if math.abs(ax-bx)<0.05 then
			local ap=unitLayoutCommandPriority(a)
			local bp=unitLayoutCommandPriority(b)
			if ap==bp then return a.guid<b.guid end
			return ap<bp
		end
		return ax<bx
	end)
	table.sort(units, function(a,b)
		local ax=a.getPosition()[1]
		local bx=b.getPosition()[1]
		if math.abs(ax-bx)<0.05 then return a.guid<b.guid end
		return ax<bx
	end)

	local unitBySlot={}
	local unitSlotByGuid={}
	local usedCommand={}
	for _, unit in ipairs(units) do
		local unitX=unit.getPosition()[1]
		local bestSlot=nil
		local bestDistance=nil
		for slot, command in ipairs(commands) do
			if usedCommand[slot]~=true then
				local distance=math.abs(unitX-command.getPosition()[1])
				if bestDistance==nil or distance<bestDistance then bestDistance=distance bestSlot=slot end
			end
		end
		if bestSlot~=nil then
			usedCommand[bestSlot]=true
			unitBySlot[bestSlot]=unit
			unitSlotByGuid[unit.guid]=bestSlot
		end
	end

	local expanded=unitLayoutExpanded[seatPos]==true or #commands>unitLayoutConfig.nativeSlots
	if expanded==false and #commands<=unitLayoutConfig.nativeSlots then
		for _, unit in ipairs(units) do
			local scale=unit.getScale()
			local sx=scale.x or scale[1]
			if sx~=nil and sx<unitLayoutConfig.cardScale-0.02 then expanded=true break end
		end
	end
	local slotX={}
	for slot, command in ipairs(commands) do
		if #commands>unitLayoutConfig.nativeSlots or expanded==true then slotX[slot]=unitLayoutX(seatPos, slot, #commands)
		else slotX[slot]=command.getPosition()[1] end
	end
	return {objects=objects, commands=commands, units=units, unitByGuid=unitByGuid, unitBySlot=unitBySlot, unitSlotByGuid=unitSlotByGuid, slotX=slotX, expanded=expanded}
end

function unitLayoutFirstFreeCommand(seatPos)
	local layout=unitLayoutSnapshot(seatPos)
	if #layout.commands>unitLayoutConfig.nativeSlots then refreshUnitLayout(seatPos) end
	for slot, command in ipairs(layout.commands) do
		if layout.unitBySlot[slot]==nil then return slot, layout.slotX[slot], command, layout end
	end
	return nil, nil, nil, layout
end

--Before overflow, new Command sources fill an unused printed column. From the seventh onward they enter at the right edge and trigger a reflow.
function unitLayoutNextCommandX(seatPos)
	local layout=unitLayoutSnapshot(seatPos)
	local count=#layout.commands
	if count>=unitLayoutConfig.nativeSlots or layout.expanded==true then
		local newCount=count+1
		return unitLayoutX(seatPos, newCount, newCount), newCount
	end
	local used={}
	for _, command in ipairs(layout.commands) do
		local commandX=command.getPosition()[1]
		local bestSlot=1
		local bestDistance=math.abs(commandX-unitLayoutX(seatPos,1,unitLayoutConfig.nativeSlots))
		for slot=2, unitLayoutConfig.nativeSlots do
			local distance=math.abs(commandX-unitLayoutX(seatPos,slot,unitLayoutConfig.nativeSlots))
			if distance<bestDistance then bestDistance=distance bestSlot=slot end
		end
		used[bestSlot]=true
	end
	for slot=1, unitLayoutConfig.nativeSlots do
		if used[slot]~=true then return unitLayoutX(seatPos,slot,unitLayoutConfig.nativeSlots), count+1 end
	end
	return unitLayoutX(seatPos,count+1,count+1), count+1
end

function unitLayoutNearestUnit(objects, x)
	local nearest=nil
	local nearestDistance=nil
	for _, obj in pairs(objects or {}) do
		if unitLayoutIsUnit(obj) then
			local distance=math.abs(x-obj.getPosition()[1])
			if nearestDistance==nil or distance<nearestDistance then nearest=obj nearestDistance=distance end
		end
	end
	return nearest, nearestDistance
end

function unitLayoutIsCompanion(obj)
	if obj==nil or unitLayoutIsUnit(obj) or unitLayoutIsCommand(obj) then return false end
	if obj.getGMNotes()=="Unit Wound" or obj.type=="Dice" or obj.type=="Figurine" then return true end
	if skillTokens[obj.guid]~=nil or monsterPugs[obj.guid]~=nil then return true end
	if gameCards[obj.guid]~=nil and gameCards[obj.guid].full~=nil then return true end
	return false
end

function unitLayoutObjectInAnyUnitArea(guid)
	for seatPos=1,4 do
		local zone=getObjectFromGUID(playerUnitAreas[seatPos])
		if zone~=nil then for _, obj in pairs(zone.getObjects()) do if obj.guid==guid then return true end end end
	end
	return false
end

function refreshUnitLayout(seatPos)
	if seatPos==nil then return end
	local layout=unitLayoutSnapshot(seatPos)
	local commandCount=#layout.commands
	if commandCount<=unitLayoutConfig.nativeSlots and layout.expanded~=true then return end
	refreshUnitLayoutSnapPoints(seatPos,commandCount)
	local targetScale=unitLayoutCardScale(commandCount)
	local unitMoves={}

	for slot, command in ipairs(layout.commands) do
		local targetX=unitLayoutX(seatPos,slot,commandCount)
		local pos=command.getPosition()
		if math.abs(pos[1]-targetX)>0.02 and (command.held_by_color==nil or command.held_by_color=="") then command.setPositionSmooth({targetX,pos[2],pos[3]}) end
	end

	for _, unit in ipairs(layout.units) do
		local slot=layout.unitSlotByGuid[unit.guid]
		local scale=unit.getScale()
		local sx=scale.x or scale[1]
		local sz=scale.z or scale[3]
		if sx==nil or sz==nil or math.abs(sx-targetScale)>0.01 or math.abs(sz-targetScale)>0.01 then unit.setScale({targetScale,1,targetScale}) end
		if slot~=nil then
			local pos=unit.getPosition()
			local targetX=unitLayoutX(seatPos,slot,commandCount)
			unitMoves[#unitMoves+1]={oldX=pos[1], targetX=targetX}
			if math.abs(pos[1]-targetX)>0.02 and (unit.held_by_color==nil or unit.held_by_color=="") then unit.setPositionSmooth({targetX,pos[2],pos[3]}) end
		end
	end

	--Keep wounds, Mana, Unit reminders, combat tokens and attached Banner cards with the Unit column they were sitting on.
	for _, obj in pairs(layout.objects) do
		if unitLayoutIsCompanion(obj) then
			local pos=obj.getPosition()
			local bestMove=nil
			local bestDistance=nil
			for _, move in ipairs(unitMoves) do
				local distance=math.abs(pos[1]-move.oldX)
				if bestDistance==nil or distance<bestDistance then bestDistance=distance bestMove=move end
			end
			if bestMove~=nil and bestDistance<=unitLayoutConfig.associationRadius and (obj.held_by_color==nil or obj.held_by_color=="") then
				--Preserve the object's offset from its Unit (notably the three left/centre/right Wound snaps)
				--while moving the whole Unit column to its compressed position.
				local targetX=bestMove.targetX+(pos[1]-bestMove.oldX)
				if math.abs(pos[1]-targetX)>0.02 then obj.setPositionSmooth({targetX,pos[2],pos[3]}) end
			end
		end
	end
	unitLayoutExpanded[seatPos]=commandCount>unitLayoutConfig.nativeSlots
end

function scheduleUnitLayoutRefresh(seatPos)
	if seatPos==nil then return end
	if unitLayoutWait[seatPos]~=nil then Wait.stop(unitLayoutWait[seatPos]) end
	unitLayoutWait[seatPos]=safeWaitTime("SetupGame",function()
		unitLayoutWait[seatPos]=nil
		refreshUnitLayout(seatPos)
	end,0.2)
end

function unitLayoutObjectInUnitArea(guid,seatPos)
	local zone=seatPos~=nil and getObjectFromGUID(playerUnitAreas[seatPos]) or nil
	if zone~=nil then for _,obj in pairs(zone.getObjects()) do if obj.guid==guid then return true end end end
	return false
end

--Players routinely lift Command tokens to place them on Units. Do not temporarily re-expand the whole
--Unit layout while a permanent Command source is in their hand; only resize if it is actually dropped away.
function scheduleUnitLayoutRefreshAfterCommandRelease(seatPos,commandGUID)
	if seatPos==nil or commandGUID==nil then return end
	safeWaitCondition("SetupGame",function()
		safeWaitFrames("SetupGame",function()
			if unitLayoutObjectInUnitArea(commandGUID,seatPos)==false then scheduleUnitLayoutRefresh(seatPos) end
		end,2)
	end,function()
		local command=getObjectFromGUID(commandGUID)
		if command==nil then return true end
		local released=command.held_by_color==nil or command.held_by_color==""
		return released and command.resting==true
	end)
end

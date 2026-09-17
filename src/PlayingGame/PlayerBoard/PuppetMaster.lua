-- Player-board PuppetMaster runtime.

--Puppet Master is driven by the physical Enemy/Puppet tokens rather than by playing the Skill token.
--A defeated Enemy is requested as a Puppet by dragging it from its owner's combat area into Inventory.
--The original is returned to the exact pickup position after a legal clone is created, so normal combat
--cleanup still owns Fame, rewards, site conquest and the real Enemy's discard/return path.
puppetMasterSkillGUID="893537"
puppetMasterDecalURL="https://steamusercontent-a.akamaihd.net/ugc/9238819073352977936/805A3875C8D1AD843302CC3E9AE3307EAC961883/" --Permanent Puppet Master marker applied to every registered Puppet.
puppetMasterPickup={}

function puppetMasterPlayerIndexForSeat(seatPos)
	if seatPos==nil then return nil end
	for playerIndex, details in pairs(turnOrder or {}) do
		if details.seatPos==seatPos and details.mage~=gStates.positionMageKnight[5] then return playerIndex end
	end
	return nil
end

function puppetMasterPlayerIndexForMage(mage)
	if mage==nil then return nil end
	for playerIndex, details in pairs(turnOrder or {}) do if details.mage==mage then return playerIndex end end
	return nil
end

function puppetMasterSeatForColor(playerColor)
	if playerColor==nil or playerColor=="Black" or playerColor=="Grey" then return nil end
	local player=Player[playerColor]
	if player==nil or player.seated~=true or player.getHandTransform()==nil then return nil end
	return math.ceil((player.getHandTransform().position[1]+97.59)/40)
end

function puppetMasterColorCanMovePlayer(playerColor, playerIndex)
	if playerColor=="Black" then return true end
	local details=turnOrder[playerIndex]
	return details~=nil and puppetMasterSeatForColor(playerColor)==details.seatPos
end

function puppetMasterObjectInZone(objectGUID, zoneGUID)
	local zone=zoneGUID~=nil and getObjectFromGUID(zoneGUID) or nil
	if zone==nil then return false end
	for _, obj in pairs(zone.getObjects()) do if obj.guid==objectGUID then return true end end
	return false
end

function puppetMasterCombatAreaPlayer(objectGUID)
	for playerIndex, details in pairs(turnOrder or {}) do
		if details.seatPos~=nil and details.mage~=gStates.positionMageKnight[5] then
			if puppetMasterObjectInZone(objectGUID,playerPlayAreas[details.seatPos])==true or puppetMasterObjectInZone(objectGUID,playerUnitAreas[details.seatPos])==true then return playerIndex end
		end
	end
	return nil
end

function puppetMasterInventoryPlayer(objectGUID)
	for playerIndex, details in pairs(turnOrder or {}) do
		if details.seatPos~=nil and details.mage~=gStates.positionMageKnight[5] and puppetMasterObjectInZone(objectGUID,playerCrystalAreas[details.seatPos])==true then return playerIndex end
	end
	return nil
end

function puppetMasterOwnsSkill(playerIndex)
	local details=turnOrder[playerIndex]
	local skillPos=gStates.mageSkills~=nil and gStates.mageSkills[puppetMasterSkillGUID] or nil
	if details==nil or skillPos==nil or skillPos[1]==nil or skillPos[3]==nil then return false end
	--Claimed Skills keep their home position in the owner's Skill column even while a Turn Skill is in play.
	local skillX=(details.seatPos*40)-107.45
	return skillPos[3]<-35 and math.abs(skillPos[1]-skillX)<2
end

function puppetMasterEnemyEligible(enemy)
	if enemy==nil then return false end
	local details=monsterPugs[enemy.guid]
	return details~=nil and details.name~="Ruin" and details.pugType~="possessed"
end

function puppetMasterWarn(playerIndex,message,controllerColor)
	local text="Puppet Master: "..tostring(message)
	local color=controllerColor
	if color==nil or Player[color]==nil or Player[color].seated~=true then
		color=playerIndex~=nil and positionToColor(playerIndex) or nil
	end
	if color~=nil and Player[color]~=nil and Player[color].seated==true then
		broadcastToColor(text,color,{1,0.65,0.2})
	elseif Player["Black"]~=nil and Player["Black"].seated==true then
		broadcastToColor(text,"Black",{1,0.65,0.2})
	else
		broadcastToAll(text,{1,0.65,0.2})
	end
end

function puppetMasterReturnToPickup(obj,pickup,message)
	if pickup==nil then return end
	if message~=nil then puppetMasterWarn(pickup.player,message,pickup.color) end
	puppetMasterPickup[obj~=nil and obj.guid or ""]=nil
	if obj==nil then return end
	if pickup.rotation~=nil then obj.setRotation(pickup.rotation) end
	if pickup.position~=nil then obj.setPosition(pickup.position) end
end

function puppetMasterApplyDecal(puppet)
	if puppet==nil or puppetMasterDecalURL==nil or puppetMasterDecalURL=="" then return end
	--Replace the marker rather than returning when one already exists, so saved Puppets also pick up
	--future size/position changes to the Puppet Master decal. Preserve any unrelated decals.
	local decals={}
	for _, decal in pairs(puppet.getDecals() or {}) do if decal.name~="Puppet Master" then table.insert(decals,decal) end end
	puppet.setDecals(decals)
	puppet.addDecal({name="Puppet Master",url=puppetMasterDecalURL,position={0,0.15,0},rotation={90,180,0},scale={0.96,0.96,1}})
end


function puppetMasterHalfAttacks(attack)
	if type(attack)~="table" then return nil end
	local result={}
	for attackType, values in pairs(attack) do
		local halved={}
		if type(values)=="table" then
			for _, value in ipairs(values) do if type(value)=="number" then halved[#halved+1]=math.ceil(value/2) end end
		elseif type(values)=="number" then
			halved[1]=math.ceil(values/2)
		end
		if #halved>0 then result[attackType]=halved end
	end
	return next(result)~=nil and result or nil
end

--Puppets are one-use Attack/Block effects, not enemies or Units. Keep only the values Puppet Master
--actually uses in monsterPerks so the normal monster hover renderer can display them. Enemy abilities,
--Fame, rewards and Physical Resistance deliberately do not carry over.
function puppetMasterPerksForData(data)
	local perks={}
	if type(data)~="table" then return perks end
	local attack=puppetMasterHalfAttacks(data.attack)
	if attack~=nil then perks.attack=attack end
	if type(data.armour)=="number" then
		local blockType="P"
		--Puppet Master reverses a single elemental resistance for Block; both become Cold Fire Block.
		if data.fResist~=nil and data.iResist~=nil then blockType="IF"
		elseif data.fResist~=nil then blockType="I"
		elseif data.iResist~=nil then blockType="F" end
		perks.block={[blockType]={math.ceil(data.armour/2)}}
	end
	return perks
end

function puppetMasterRefreshPresentation(puppet,record)
	if puppet==nil then return end
	puppetMasterApplyDecal(puppet)
	local data=record~=nil and record.data or nil --0152/0153 save migration.
	if data==nil and record~=nil and record.sourceGUID~=nil then
		local _, sourceData=puppetMasterDataForSourceGUID(record.sourceGUID)
		data=sourceData
	end
	if gStates.monsterPerks==nil then gStates.monsterPerks={} end
	gStates.monsterPerks[puppet.guid]=puppetMasterPerksForData(data)
	--Old Puppet records stored a full enemy copy for a bespoke tooltip. The hover system now owns all
	--combat presentation, so discard those legacy fields after using them once for migration.
	if record~=nil then record.data=nil record.fame=nil end
	puppet.setDescription("")
end

function puppetMasterObjectImage(obj)
	if obj==nil then return nil end
	local custom=obj.getCustomObject()
	if custom==nil then return nil end
	return custom.image or custom.image_url or custom.ImageURL or custom.diffuse or custom.DiffuseURL
end

function puppetMasterDataForSourceGUID(sourceGUID)
	if sourceGUID==nil then return nil,nil end
	local details=monsterPugs[sourceGUID]
	if details==nil then return nil,nil end
	local puppetData=details
	if sourceGUID==darkCrusader.token or sourceGUID==elementalist.token then
		local leader=sourceGUID==darkCrusader.token and darkCrusader or elementalist
		if leaderData[leader.terrainHex]~=nil and leaderData[leader.terrainHex][1]~=nil and leaderData[leader.terrainHex][1].abilities~=nil then puppetData=leaderData[leader.terrainHex][1].abilities end
	end
	return details,puppetData
end

function puppetMasterDataForEnemy(enemy)
	if enemy==nil then return nil,nil end
	return puppetMasterDataForSourceGUID(enemy.guid)
end

function puppetMasterPreparePuppet(puppet)
	if puppet==nil then return end
	--Possession/buff attachments and combat controls belong to the real Enemy, never to the kept Puppet.
	if #puppet.getAttachments()>0 then for _, attachment in pairs(puppet.removeAttachments() or {}) do attachment.destruct() end end
	puppet.clearButtons()
	puppet.UI.setXmlTable({{}})
	puppet.setDecals({})
	puppet.setGMNotes("Puppet Master")
	puppet.setDescription("")
end

function puppetMasterRegisterPuppet(puppet,enemy,playerIndex,controllerColor)
	local playerData=turnOrder[playerIndex]
	local details,puppetData=puppetMasterDataForEnemy(enemy)
	if puppet==nil or playerData==nil or details==nil or puppetData==nil then return false end
	puppetMasterPreparePuppet(puppet)
	if gStates.puppetMasterPuppets==nil then gStates.puppetMasterPuppets={} end
	gStates.puppetMasterPuppets[puppet.guid]={ownerMage=playerData.mage,ownerSeat=playerData.seatPos,sourceGUID=enemy.guid,name=puppetData.name or details.name,location="inventory",played=false}
	puppetMasterRefreshPresentation(puppet,gStates.puppetMasterPuppets[puppet.guid])
	playerData.puppetMasterUsed=true
	puppetMasterWarn(playerIndex,tostring(details.name or "Enemy").." was kept as a Puppet.",controllerColor)
	return true
end

function puppetMasterRegisterClone(enemy,pickup)
	local dropPos=enemy.getPosition()
	local dropRot=enemy.getRotation()
	--Object.clone() gives the new token a brief physics/autoraise kick even when spawned at its final
	--position. Build the Puppet from the Enemy's ObjectState instead and keep it locked for its first
	--couple of frames so there is never a clone-separation "pop".
	local puppetData=enemy.getData()
	if puppetData==nil then return false end
	puppetData.GUID=nil
	puppetData.Locked=true
	if pickup.rotation~=nil then enemy.setRotation(pickup.rotation) end
	if pickup.position~=nil then enemy.setPosition(pickup.position) end
	local puppet=spawnObjectData({data=puppetData,position={dropPos[1],dropPos[2],dropPos[3]},rotation={dropRot[1],dropRot[2],dropRot[3]}})
	if puppet==nil then return false end
	puppet.setVelocity({0,0,0})
	puppet.setAngularVelocity({0,0,0})
	puppet.setPosition(dropPos)
	puppet.setRotation(dropRot)
	if puppetMasterRegisterPuppet(puppet,enemy,pickup.player,pickup.color)~=true then puppet.destruct() return false end
	local puppetGUID=puppet.guid
	Wait.frames(function()
		local live=getObjectFromGUID(puppetGUID)
		if live~=nil then
			live.setPosition(dropPos)
			live.setRotation(dropRot)
			live.setVelocity({0,0,0})
			live.setAngularVelocity({0,0,0})
			live.unlock()
		end
	end,2)
	puppetMasterPickup[enemy.guid]=nil
	return true
end

--Deleting or trashing a Puppet immediately after claiming it is treated as undo while the exact real
--Enemy used to create it is still in that Mage Knight's combat area. Once normal combat cleanup has
--removed the source Enemy, disposing of the Puppet is just an ordinary Puppet deletion.
function puppetMasterUndoFreshClaim(puppetGUID,controllerColor)
	local record=gStates.puppetMasterPuppets~=nil and gStates.puppetMasterPuppets[puppetGUID] or nil
	if record==nil or record.sourceGUID==nil or record.played==true then return false end
	local owner=puppetMasterRecordOwnerIndex(record)
	local source=getObjectFromGUID(record.sourceGUID)
	if owner==nil or source==nil or puppetMasterCombatAreaPlayer(source.guid)~=owner then return false end
	gStates.puppetMasterPuppets[puppetGUID]=nil
	if gStates.monsterPerks~=nil then gStates.monsterPerks[puppetGUID]=nil end
	puppetMasterPickup[puppetGUID]=nil
	if turnOrder[owner]~=nil then turnOrder[owner].puppetMasterUsed=false end
	puppetMasterWarn(owner,tostring(record.name or "Puppet").." Puppet claim was undone.",controllerColor)
	return true
end

function puppetMasterClaimReason(enemy,pickup,destinationPlayer)
	local playerData=pickup~=nil and turnOrder[pickup.player] or nil
	if playerData==nil or destinationPlayer~=pickup.player then return "That Enemy must be dropped into its owner's Inventory." end
	if pickup.fromCombat~=true then return "Only an Enemy taken directly from your combat area can be kept." end
	if puppetMasterEnemyEligible(enemy)~=true then return "That object is not an eligible Enemy token." end
	if pickup.faceUp~=true or enemy.is_face_down==true then return "Only a defeated, face-up Enemy can be kept." end
	if enemy.guid==darkCrusader.token or enemy.guid==elementalist.token then
		local leaderLevel=enemy.guid==darkCrusader.token and gStates.darkCrusaderLevel or gStates.elementalistLevel
		if leaderLevel~=nil and ((gStates.leaderReduction or 0)+(gStates.leaderOverkill or 0))<leaderLevel then return "A Faction Leader can only be kept after it is completely defeated." end
	end
	if gStates.turnNumber~=pickup.player then return "You can only use the Skill during this Mage Knight's turn." end
	if gStates.preEndTurn==true then return "The turn is already being cleaned up." end
	if puppetMasterOwnsSkill(pickup.player)~=true then return tostring(playerData.mage).." does not own Puppet Master." end
	if playerData.puppetMasterUsed==true then return "Puppet Master has already been used this turn." end
	return nil
end

function puppetMasterResolveEnemyDrop(enemy,pickup)
	local inventoryPlayer=puppetMasterInventoryPlayer(enemy.guid)
	if inventoryPlayer==nil then puppetMasterPickup[enemy.guid]=nil return end
	local reason=puppetMasterClaimReason(enemy,pickup,inventoryPlayer)
	if reason~=nil then puppetMasterReturnToPickup(enemy,pickup,reason) return end
	if puppetMasterRegisterClone(enemy,pickup)~=true then puppetMasterReturnToPickup(enemy,pickup,"The Puppet copy could not be created; the Enemy was returned.") end
end

--Manual copy/paste remains a supported Puppet Master interaction. A pasted token has a new GUID,
--so match its face image to the real defeated Enemy still sitting in that player's combat area.
function puppetMasterManualCopySource(copy,playerIndex)
	local playerData=turnOrder[playerIndex]
	local image=puppetMasterObjectImage(copy)
	if playerData==nil or image==nil or image=="" then return nil end
	for _, enemy in pairs(playerCombatObjects(playerData.seatPos)) do
		if enemy.guid~=copy.guid and puppetMasterEnemyEligible(enemy)==true and puppetMasterObjectImage(enemy)==image then return enemy end
	end
	return nil
end

function puppetMasterResolveManualCopy(copy)
	if copy==nil or copy.guid==nil or monsterPugs[copy.guid]~=nil then return false end
	if gStates.puppetMasterPuppets~=nil and gStates.puppetMasterPuppets[copy.guid]~=nil then return false end
	local owner=puppetMasterInventoryPlayer(copy.guid)
	if owner==nil then return false end
	local enemy=puppetMasterManualCopySource(copy,owner)
	if enemy==nil then return false end
	local pickup={kind="manualCopy",player=owner,fromCombat=true,faceUp=enemy.is_face_down==false}
	local reason=puppetMasterClaimReason(enemy,pickup,owner)
	if reason~=nil then
		puppetMasterWarn(owner,reason.." The pasted copy was removed.")
		copy.destruct()
		return true
	end
	if puppetMasterRegisterPuppet(copy,enemy,owner)~=true then
		puppetMasterWarn(owner,"The pasted Enemy could not be registered as a Puppet and was removed.")
		copy.destruct()
	end
	return true
end

function puppetMasterCheckManualCopyWhenResting(obj)
	if obj==nil or obj.guid==nil then return end
	local guid=obj.guid
	Wait.condition(function()
		local live=getObjectFromGUID(guid)
		if live~=nil then puppetMasterResolveManualCopy(live) end
	end,function()
		local live=getObjectFromGUID(guid)
		return live==nil or live.resting==true
	end)
end

function puppetMasterRecordOwnerIndex(record)
	if record==nil then return nil end
	local playerIndex=puppetMasterPlayerIndexForMage(record.ownerMage)
	if playerIndex~=nil then return playerIndex end
	return puppetMasterPlayerIndexForSeat(record.ownerSeat)
end

function puppetMasterResolvePuppetDrop(puppet,pickup)
	local record=gStates.puppetMasterPuppets~=nil and gStates.puppetMasterPuppets[puppet.guid] or nil
	if record==nil then puppetMasterPickup[puppet.guid]=nil return end
	local owner=puppetMasterRecordOwnerIndex(record)
	if owner==nil then puppetMasterReturnToPickup(puppet,pickup,"The Puppet's owner could not be identified.") return end
	local inventoryPlayer=puppetMasterInventoryPlayer(puppet.guid)
	if inventoryPlayer==owner then
		record.location="inventory"
		record.lastInventoryPosition={puppet.getPosition()[1],puppet.getPosition()[2],puppet.getPosition()[3]}
		record.lastInventoryRotation={puppet.getRotation()[1],puppet.getRotation()[2],puppet.getRotation()[3]}
		puppetMasterPickup[puppet.guid]=nil
		return
	end
	local combatPlayer=puppetMasterCombatAreaPlayer(puppet.guid)
	if combatPlayer~=owner then puppetMasterReturnToPickup(puppet,pickup,"A stored Puppet can only be played into its owner's combat area.") return end
	local playerData=turnOrder[owner]
	if gStates.turnNumber~=owner then puppetMasterReturnToPickup(puppet,pickup,"You can only use the Skill during this Mage Knight's turn.") return end
	if gStates.preEndTurn==true then puppetMasterReturnToPickup(puppet,pickup,"The turn is already being cleaned up.") return end
	if puppetMasterOwnsSkill(owner)~=true then puppetMasterReturnToPickup(puppet,pickup,tostring(playerData.mage).." does not own Puppet Master.") return end
	if playerData.puppetMasterUsed==true then puppetMasterReturnToPickup(puppet,pickup,"Puppet Master has already been used this turn.") return end
	playerData.puppetMasterUsed=true
	record.played=true
	record.location="played"
	puppetMasterPickup[puppet.guid]=nil
	puppetMasterWarn(owner,tostring(record.name or "Puppet").." was played; no Enemy can be kept with Puppet Master this turn.",pickup.color)
end

function puppetMasterTrackPickup(playerColor,obj)
	if obj==nil or obj.guid==nil then return end
	puppetMasterPickup[obj.guid]=nil
	local puppetRecord=gStates.puppetMasterPuppets~=nil and gStates.puppetMasterPuppets[obj.guid] or nil
	if puppetRecord~=nil and puppetRecord.played~=true and puppetRecord.location=="inventory" then
		local owner=puppetMasterRecordOwnerIndex(puppetRecord)
		if owner~=nil and puppetMasterColorCanMovePlayer(playerColor,owner)==true then
			puppetMasterPickup[obj.guid]={kind="puppet",player=owner,color=playerColor,position={obj.getPosition()[1],obj.getPosition()[2],obj.getPosition()[3]},rotation={obj.getRotation()[1],obj.getRotation()[2],obj.getRotation()[3]}}
		end
		return
	end
	if puppetMasterEnemyEligible(obj)~=true then return end
	local combatPlayer=puppetMasterCombatAreaPlayer(obj.guid)
	if combatPlayer==nil or puppetMasterColorCanMovePlayer(playerColor,combatPlayer)~=true then return end
	puppetMasterPickup[obj.guid]={kind="enemy",player=combatPlayer,color=playerColor,fromCombat=true,faceUp=obj.is_face_down==false,position={obj.getPosition()[1],obj.getPosition()[2],obj.getPosition()[3]},rotation={obj.getRotation()[1],obj.getRotation()[2],obj.getRotation()[3]}}
end

function puppetMasterDropped(obj)
	if obj==nil or obj.guid==nil then return false end
	local pickup=puppetMasterPickup[obj.guid]
	if pickup==nil then return false end
	local guid=obj.guid
	Wait.condition(function()
		local live=getObjectFromGUID(guid)
		if live==nil or puppetMasterPickup[guid]~=pickup then return end
		if pickup.kind=="enemy" then puppetMasterResolveEnemyDrop(live,pickup)
		elseif pickup.kind=="puppet" then puppetMasterResolvePuppetDrop(live,pickup)
		else puppetMasterPickup[guid]=nil end
	end,function()
		local live=getObjectFromGUID(guid)
		return live==nil or puppetMasterPickup[guid]~=pickup or live.resting==true
	end)
	return true
end

function puppetMasterCleanupPlayedPuppets(playerIndex)
	local details=turnOrder[playerIndex]
	if details==nil or gStates.puppetMasterPuppets==nil then return end
	for guid, record in pairs(gStates.puppetMasterPuppets) do
		if record.ownerMage==details.mage and record.played==true then
			local puppet=getObjectFromGUID(guid)
			gStates.puppetMasterPuppets[guid]=nil
			if gStates.monsterPerks~=nil then gStates.monsterPerks[guid]=nil end
			puppetMasterPickup[guid]=nil
			if puppet~=nil then puppet.destruct() end
		end
	end
end

--give mana token if starting on a Glade

-- Fame/Reputation accounting corrections that sit across Combat, UI, Quests, Map and Turn.
-- Owning modules expose the public entry points and delegate here explicitly. Their uniquely named base
-- implementations keep cross-module sequencing visible without relying on late global redefinition.

local fameRepSyncSuppressed=false
local possessedAttachPending={}

local function fameRepCommitTable()
	if gStates.fameRepCommitted==nil then gStates.fameRepCommitted={} end
	return gStates.fameRepCommitted
end

local function fameRepClamp(value,minimum,maximum)
	if value<minimum then return minimum end
	if value>maximum then return maximum end
	return value
end

--Reputation is a cache of the physical Reputation shield. Normally setup/load keeps both in sync,
--but a missing cache must not make reward cleanup explode. Rebuild it from the table before doing
--any arithmetic; only virtual players, which have no Reputation marker, legitimately fall back to 0.
local function fameRepCurrentReputation(playerIndex)
	local player=turnOrder[playerIndex]
	if player==nil then return nil end
	local cached=tonumber(player.reputation)
	if cached~=nil then
		player.reputation=cached
		return cached
	end

	if player.reputationGUID==nil and player.mage==gStates.positionMageKnight[5] then
		player.reputation=0
		return 0
	end

	if refreshPlayerReputationFromShield~=nil and refreshPlayerReputationFromShield(playerIndex)==true then
		cached=tonumber(player.reputation)
		if cached~=nil then return cached end
	end

	local shield=player.reputationGUID~=nil and getObjectFromGUID(player.reputationGUID) or nil
	if shield~=nil then
		local position=shield.getPosition()
		local nearestValue=nil
		local nearestDistance=nil
		for value,details in pairs(reputationTable or {}) do
			local target=details.reputationPos
			if type(value)=="number" and target~=nil then
				local dx=position[1]-target[1]
				local dz=position[3]-target[3]
				local distance=(dx*dx)+(dz*dz)
				if nearestDistance==nil or distance<nearestDistance then
					nearestDistance=distance
					nearestValue=value
				end
			end
		end
		--Starting shields are offset by player colour so they do not overlap. 3.5 units comfortably
		--covers those legal offsets while refusing to invent Reputation for a marker moved off the track.
		if nearestValue~=nil and nearestDistance<=12.25 then
			player.reputation=nearestValue
			return nearestValue
		end
	end

	error("Fame/Reputation could not resolve the current Reputation for "..tostring(player.mage or playerIndex)..".",2)
end

--Pending Reputation is always an effective-track delta. Clamp after every externally visible
--accounting pass instead of waiting until Rewards Claimed, so reaching +/-7 consumes the excess
--immediately and a later opposite change still moves away from the edge correctly.
local function normalizePendingReputation(playerIndex, previousSiteLoss)
	local player=turnOrder[playerIndex]
	if player==nil then return end
	player.repGain=player.repGain or 0
	local raw=player.repGain
	local reputation=fameRepCurrentReputation(playerIndex)
	local minimum=-7-reputation
	local maximum=7-reputation
	local clipped=fameRepClamp(raw,minimum,maximum)
	local lowerOverflow=clipped-raw
	player.repGain=clipped

	--Combat reset refunds siteRepLoss later. If part of a newly-created assault loss was clipped at
	--the bottom of the Reputation track, reduce the stored refundable amount by the same quantity.
	if lowerOverflow>0 and gStates.gainList~=nil then
		local overflow=lowerOverflow
		for guid,entry in pairs(gStates.gainList) do
			if overflow<=0 then break end
			if type(entry)=="table" and (entry.siteRepLoss or 0)>0 then
				local before=previousSiteLoss~=nil and (previousSiteLoss[guid] or 0) or 0
				local added=math.max(0,(entry.siteRepLoss or 0)-before)
				if added>0 then
					local remove=math.min(added,overflow)
					entry.siteRepLoss=entry.siteRepLoss-remove
					overflow=overflow-remove
				end
			end
		end
	end
end

local function fameRepSnapshotSiteLoss()
	local snapshot={}
	for guid,entry in pairs(gStates.gainList or {}) do
		if type(entry)=="table" and (entry.siteRepLoss or 0)>0 then snapshot[guid]=entry.siteRepLoss end
	end
	return snapshot
end

local function hiddenValleyNormalizeSiteLoss()
	if gStates.hiddenValleyKeep==nil then return end
	local found=false
	local assigned=0
	for _,guid in ipairs({gStates.hiddenValleyKeep[1],gStates.hiddenValleyKeep[2]}) do
		local entry=guid~=nil and gStates.gainList~=nil and gStates.gainList[guid] or nil
		if entry~=nil then
			found=true
			if (entry.siteRepLoss or 0)>0 then
				assigned=assigned+entry.siteRepLoss
				entry.siteRepLoss=0
			end
		end
	end
	if assigned>0 and gStates.hiddenValleyRepLossActive~=true then
		--The existing combat pass has already queued this loss; only move ownership from a random
		--defender to the assaulted Hidden Valley site.
		gStates.hiddenValleyRepLossActive=true
	end
	if gStates.hiddenValleyRepLossActive==true and found==false and gStates.preEndTurn~=true and fameRepSyncSuppressed~=true then
		local player=turnOrder[gStates.turnNumber]
		if player~=nil then
			player.repGain=(player.repGain or 0)+1
			normalizePendingReputation(gStates.turnNumber)
		end
		gStates.hiddenValleyRepLossActive=nil
	end
end

local function syncPlayerFameFromMarker(playerIndex)
	if refreshPlayerFameFromShield~=nil then refreshPlayerFameFromShield(playerIndex) end
end

--Apply only rewards added after the normal pre-end-turn commit. The cumulative fameGain/repGain
--values remain intact for the reward display, while the physical/logical tracks receive just the delta.
local function syncPostCommitAdjustments(playerIndex)
	if fameRepSyncSuppressed==true then return end
	local player=turnOrder[playerIndex]
	local committed=gStates.fameRepCommitted~=nil and gStates.fameRepCommitted[playerIndex] or nil
	if player==nil or committed==nil then return end
	local fameTotal=player.fameGain or 0
	local repTotal=player.repGain or 0
	local fameDelta=fameTotal-(committed.fame or 0)
	local repDelta=repTotal-(committed.rep or 0)
	if fameDelta==0 and repDelta==0 then return end

	local reputation=fameRepCurrentReputation(playerIndex)
	repDelta=fameRepClamp(repDelta,-7-reputation,7-reputation)
	player.repGain=(committed.rep or 0)+repDelta
	repTotal=player.repGain

	local displayFame=fameTotal
	local displayRep=repTotal
	player.fameGain=fameDelta
	player.repGain=repDelta
	fameRepSyncSuppressed=true
	combatApplyPlayerFameReputationBase(playerIndex)
	syncPlayerFameFromMarker(playerIndex)
	fameRepSyncSuppressed=false
	player.fameGain=displayFame
	player.repGain=displayRep
	committed.fame=displayFame
	committed.rep=displayRep
end

function fameReputationApplyPlayerFameReputation(playerIndex)
	local player=turnOrder[playerIndex]
	if player==nil then return end
	normalizePendingReputation(playerIndex)
	fameRepSyncSuppressed=true
	combatApplyPlayerFameReputationBase(playerIndex)
	--The original Fame placement already includes Blitz line-crossing bonuses. Read that authoritative
	--marker back so player.fame records the same value instead of only the pre-Blitz delta.
	syncPlayerFameFromMarker(playerIndex)
	fameRepSyncSuppressed=false
	local committed=fameRepCommitTable()
	committed[playerIndex]={fame=player.fameGain or 0,rep=player.repGain or 0}
	--A Hidden Valley assault loss is now committed and must not be refunded when combat cleanup removes
	--the two defenders from gainList.
	gStates.hiddenValleyRepLossActive=nil
end

local function nearestPossessedEnemy(possessed,zone)
	if possessed==nil then return nil end
	local candidates=zone~=nil and zone.getObjects() or getAllObjects()
	local pos=possessed.getPosition()
	for _,enemy in pairs(candidates) do
		if enemy.guid~=possessed.guid and monsterPugs[enemy.guid]~=nil and monsterPugs[enemy.guid].pugType~="possessed" then
			local enemyPos=enemy.getPosition()
			if math.abs(enemyPos[1]-pos[1])<0.5 and math.abs(enemyPos[3]-pos[3])<0.5 then return enemy end
		end
	end
	return nil
end

local function possessedManualAward(perks)
	if perks==nil then return 0 end
	local amount=tonumber(perks.fame) or 0
	if perks.faction~=nil and factionRewardUsesJustFame(perks.faction)==true then amount=amount+1 end
	return amount
end

local function correctPossessedAttachmentAwards()
	for tokenGUID,pending in pairs(possessedAttachPending) do
		local enemyGUID=gStates.apocalypsePossessedEnemyByToken~=nil and gStates.apocalypsePossessedEnemyByToken[tokenGUID] or nil
		if enemyGUID~=nil then
			local player=turnOrder[pending.playerIndex]
			local entry=gStates.gainList~=nil and gStates.gainList[enemyGUID] or nil
			local perks=gStates.monsterPerks~=nil and gStates.monsterPerks[enemyGUID] or nil
			if player~=nil and perks~=nil then
				local oldAward=pending.oldAward or 0
				local newAward=possessedManualAward(perks)
				local originalAdded=newAward
				local wanted=0
				--Only an already-registered defeated enemy needs a manual delta. Otherwise the ordinary
				--gainList flip/registration path owns the Possessed Fame and faction fallback.
				if pending.registered==true and entry~=nil and entry.tokenDirection==1 then wanted=math.max(0,newAward-oldAward) end
				player.fameGain=(player.fameGain or 0)-(originalAdded-wanted)
			end
			possessedAttachPending[tokenGUID]=nil
		end
	end
end

function fameReputationAttachEnemy(player,mouseButton,id,obj,zone)
	if id=="attach" and obj~=nil then
		local enemy=nearestPossessedEnemy(obj,zone)
		if enemy~=nil then
			local playerIndex=nil
			if zone~=nil then
				for index,details in pairs(turnOrder) do
					if details.seatPos~=nil and playerPlayAreas[details.seatPos]==zone.guid then playerIndex=index break end
				end
			end
			if playerIndex~=nil then
				possessedAttachPending[obj.guid]={playerIndex=playerIndex,registered=gStates.gainList~=nil and gStates.gainList[enemy.guid]~=nil,oldAward=possessedManualAward(gStates.monsterPerks~=nil and gStates.monsterPerks[enemy.guid] or nil)}
			end
		end
	elseif id~=nil and id:sub(1,6)=="detach" then
		local enemy=obj
		if enemy==nil then enemy=getObjectFromGUID(id:sub(7,13)) end
		if enemy~=nil then
			local entry=gStates.gainList~=nil and gStates.gainList[enemy.guid] or nil
			local oldAward=possessedManualAward(gStates.monsterPerks~=nil and gStates.monsterPerks[enemy.guid] or nil)
			if entry~=nil and entry.tokenDirection==1 and oldAward>0 then
				for index,details in pairs(turnOrder) do
					local zoneGUID=playerPlayAreas[details.seatPos]
					local combatZone=zoneGUID~=nil and getObjectFromGUID(zoneGUID) or nil
					if combatZone~=nil then
						for _,candidate in pairs(combatZone.getObjects()) do
							if candidate.guid==enemy.guid then details.fameGain=(details.fameGain or 0)-oldAward break end
						end
					end
				end
			end
		end
	end
	return combatAttachEnemyBase(player,mouseButton,id,obj,zone)
end

function fameReputationMainUIUpdate(...)
	local previousSiteLoss=fameRepSnapshotSiteLoss()
	if turnOrder[gStates.turnNumber]~=nil and turnOrder[gStates.turnNumber].reputation==nil then fameRepCurrentReputation(gStates.turnNumber) end
	local result=uiMainUIUpdateBase(...)
	if turnOrder[gStates.turnNumber]~=nil then normalizePendingReputation(gStates.turnNumber,previousSiteLoss) end
	hiddenValleyNormalizeSiteLoss()
	correctPossessedAttachmentAwards()
	if turnOrder[gStates.turnNumber]~=nil then syncPostCommitAdjustments(gStates.turnNumber) end
	return result
end

function fameReputationValueAdjust(player,mouseButton,id)
	if turnOrder[gStates.turnNumber]~=nil and turnOrder[gStates.turnNumber].reputation==nil then fameRepCurrentReputation(gStates.turnNumber) end
	local result=uiValueAdjustBase(player,mouseButton,id)
	if turnOrder[gStates.turnNumber]~=nil then
		normalizePendingReputation(gStates.turnNumber)
		syncPostCommitAdjustments(gStates.turnNumber)
	end
	return result
end

function fameReputationMotivation(...)
	local result=skillsMotivationBase(...)
	--Motivation has its own physical Fame movement and includes Blitz bonuses there. Keep every logical
	--Fame value synchronized with its marker after that independent award path.
	for playerIndex,_ in pairs(turnOrder) do syncPlayerFameFromMarker(playerIndex) end
	return result
end

--Plundering remains legal at -7 Reputation; the Reputation loss simply cannot move below the track.
function fameReputationPlunderVillage(player,mouseButton,id)
	if mouseButton=="-1" and legalPlayerCheck(player.color,tonumber(id:sub(8,8)))==true then
		for a=1,#turnOrder do
			if turnOrder[a].seatPos==tonumber(id:sub(8,8)) then
				fameRepCurrentReputation(a)
				broadcastToAll(joinLang({translateWord[turnOrder[a].mage],"{en} just Plundered their Village.{ru} разграбляет деревню.{zh-tw}刚刚劫掠了他们的村庄{zh-cn}刚刚劫掠了他们的村庄{ko}: 마을을 약탈했습니다.{es} acaba de saquear su aldea.{fr} vient de Piller leur Village.{pt-br} acabou de Saquear a Vila{de} hat gerade ihr Dorf geplündert. "}),positionToColor(a))
				drawExactDeedCards(a,2,"DrawOne")
				if turnOrder[a].reputation>-7 then
					local newRep=turnOrder[a].reputation-1
					local repPos=reputationTable[newRep].reputationPos
					getObjectFromGUID(turnOrder[a].reputationGUID).setPosition({repPos[1],repPos[2],repPos[3]})
					turnOrder[a].reputation=newRep
				end
				turnOrder[a].pillagedVillage=true
				mainUIUpdate("Village Pillaged")
				break
			end
		end
	end
end

function fameReputationAdvanceCoopRewardPhase()
	local entry=gStates.coopRewardQueue~=nil and gStates.coopRewardQueue[gStates.coopRewardIndex] or nil
	if entry~=nil then syncPostCommitAdjustments(entry.player) end
	fameRepSyncSuppressed=true
	if entry~=nil and gStates.fameRepCommitted~=nil then gStates.fameRepCommitted[entry.player]=nil end
	local result=combatAdvanceCoopRewardPhaseBase()
	fameRepSyncSuppressed=false
	return result
end

function fameReputationEndTurnRaw(player,mouseButton,id,rewindReady)
	local playerIndex=gStates.turnNumber
	if gStates.coopAssaultPhase~="rewards" then syncPostCommitAdjustments(playerIndex) end
	fameRepSyncSuppressed=true
	local result=turnEndTurnRawBase(player,mouseButton,id,rewindReady)
	fameRepSyncSuppressed=false
	--Only clear the persisted commit marker when the turn actually advanced past Rewards Claimed.
	if gStates.preEndTurn~=true and gStates.fameRepCommitted~=nil then gStates.fameRepCommitted[playerIndex]=nil end
	return result
end

function fameReputationOnLoadRaw(saved_data)
	local result=eventsOnLoadRawBase(saved_data)
	--A save can occur after preEndTurn is set but before its delayed Fame/Rep commit callback. The absence
	--of a persisted commit marker means the physical tracks still need the pending reward exactly once.
	safeWaitFrames("FameReputation",function()
		if gStates.preEndTurn==true and turnOrder[gStates.turnNumber]~=nil then
			local committed=gStates.fameRepCommitted~=nil and gStates.fameRepCommitted[gStates.turnNumber] or nil
			if committed==nil and ((turnOrder[gStates.turnNumber].fameGain or 0)~=0 or (turnOrder[gStates.turnNumber].repGain or 0)~=0) then
				applyPlayerFameReputation(gStates.turnNumber)
			else
				syncPostCommitAdjustments(gStates.turnNumber)
			end
		end
	end,6)
	return result
end

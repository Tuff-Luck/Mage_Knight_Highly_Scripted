-- Fame/Reputation accounting corrections that sit across Combat, UI, Quests, Map and Turn.
-- Owning modules expose the public entry points and delegate here explicitly. Their uniquely named base
-- implementations keep cross-module sequencing visible without relying on late global redefinition.

local fameRepSyncSuppressed=false
local possessedAttachPending={}
--mainUIUpdate() is already debounced by UI.lua. Keep Fame/Reputation bookkeeping attached to that
--same refresh batch so rapid zone/card events do not repeatedly snapshot and reconcile identical state.
local fameRepMainUIBatch=nil

local function fameRepCommitTable()
	if gStates.fameRepCommitted==nil then gStates.fameRepCommitted={} end
	return gStates.fameRepCommitted
end

local function fameRepClamp(value,minimum,maximum)
	if value<minimum then return minimum end
	if value>maximum then return maximum end
	return value
end

-- The setup Dummy/Proxy has no Fame/Reputation shields. Only real Mage Knights
-- can commit physical rewards; missing markers on a real player are not a
-- valid reason to apply the reward to the saved numbers alone.
local fameRepMissingMarkerNotices={}
local function fameRepResolveCommitMarkers(playerIndex)
	local player=turnOrder[playerIndex]
	if player==nil then return nil,nil end
	if player.fameGUID==nil and player.reputationGUID==nil and player.mage==gStates.positionMageKnight[5] then
		return nil,nil -- Virtual Dummy/Proxy; never create a physical Fame commit.
	end
	local fameShield=player.fameGUID~=nil and getObjectFromGUID(player.fameGUID) or nil
	local reputationShield=player.reputationGUID~=nil and getObjectFromGUID(player.reputationGUID) or nil
	if fameShield~=nil and fameShield.isDestroyed()==true then fameShield=nil end
	if reputationShield~=nil and reputationShield.isDestroyed()==true then reputationShield=nil end
	if fameShield~=nil and reputationShield~=nil then
		fameRepMissingMarkerNotices[playerIndex]=nil
		return fameShield,reputationShield
	end
	local missing={}
	if fameShield==nil then missing[#missing+1]="Fame ("..tostring(player.fameGUID or "no GUID")..")" end
	if reputationShield==nil then missing[#missing+1]="Reputation ("..tostring(player.reputationGUID or "no GUID")..")" end
	local details="Fame/Reputation reward not committed for "..tostring(player.mage)..
		" [turnOrder "..tostring(playerIndex)..", seat "..tostring(player.seatPos).."]: missing "..table.concat(missing,", ").." shield."
	if fameRepMissingMarkerNotices[playerIndex]~=details then
		fameRepMissingMarkerNotices[playerIndex]=details
		log(details)
		broadcastToAll(details.." Restore the marker before claiming rewards.",{1,0.72,0.35})
	end
	return nil,nil
end

-- Suppression is runtime-only. Never leave it enabled after a failed callback,
-- including an End Turn or a co-op reward transition.
local function fameRepWithSyncSuppressed(callback)
	local previous=fameRepSyncSuppressed
	fameRepSyncSuppressed=true
	local result=table.pack(pcall(callback))
	fameRepSyncSuppressed=previous
	if result[1]~=true then error(result[2],0) end
	return table.unpack(result,2,result.n)
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

--Pending Reputation is always an effective-track delta. Clamp irreversible changes after every
--externally visible accounting pass so reaching +/-7 consumes excess immediately.
local function normalizePendingReputation(playerIndex)
	local player=turnOrder[playerIndex]
	if player==nil then return end
	player.repGain=player.repGain or 0
	local reputation=fameRepCurrentReputation(playerIndex)
	player.repGain=fameRepClamp(player.repGain,-7-reputation,7-reputation)
end

--Combat Reputation is reversible until its source is committed. Remember the exact amount that
--actually reached the track so removing/flipping that source later reverses only its own applied value.
--Keep the nominal value even when capped to zero so later unrelated changes cannot reactivate an
--already-resolved source just because another UI refresh ran.
function fameReputationSetReversiblePending(playerIndex,entry,key,nominal)
	local player=turnOrder[playerIndex]
	if player==nil or type(entry)~="table" or key==nil then return 0 end
	player.repGain=player.repGain or 0
	nominal=tonumber(nominal) or 0
	entry.repEffects=entry.repEffects or {}
	local previous=entry.repEffects[key]
	if previous~=nil and (tonumber(previous.nominal) or 0)==nominal then return tonumber(previous.applied) or 0 end

	if previous~=nil then player.repGain=player.repGain-(tonumber(previous.applied) or 0) end
	if nominal==0 then
		entry.repEffects[key]=nil
		if next(entry.repEffects)==nil then entry.repEffects=nil end
		return 0
	end

	local reputation=fameRepCurrentReputation(playerIndex)
	local effective=reputation+player.repGain
	local applied=fameRepClamp(nominal,-7-effective,7-effective)
	player.repGain=player.repGain+applied
	entry.repEffects[key]={nominal=nominal,applied=applied}
	return applied
end

--Resource Tracker Fame/Reputation is runtime-only and rebuilt on every scan. It lives in the same
--pending fameGain/repGain the main interface shows, and is reversed whenever the played source leaves.
local resourceFameRepState={}

function resourceFameRepApply(playerIndex,fame,rep)
	local player=turnOrder[playerIndex]
	if player==nil or gStates.preEndTurn==true then return end
	local state=resourceFameRepState[playerIndex]
	if state==nil then
		if (fame or 0)==0 and (rep or 0)==0 then return end
		state={fame=0,entry={}}
		resourceFameRepState[playerIndex]=state
	end
	local fameDelta=(fame or 0)-state.fame
	local previousRep=state.entry.repEffects~=nil and state.entry.repEffects.resourceTracker~=nil
		and state.entry.repEffects.resourceTracker.nominal or 0
	if fameDelta==0 and (rep or 0)==previousRep then return end
	state.fame=fame or 0
	player.fameGain=math.max(0,(player.fameGain or 0)+fameDelta)
	fameReputationSetReversiblePending(playerIndex,state.entry,"resourceTracker",rep or 0)
	if state.fame==0 and state.entry.repEffects==nil then resourceFameRepState[playerIndex]=nil end
	mainUIUpdate("Resource Tracker Fame/Reputation")
end

--Called when the turn's pending Fame/Reputation is committed or zeroed, so nothing is reversed twice.
function resourceFameRepForget(playerIndex)
	resourceFameRepState[playerIndex]=nil
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
	if refreshPlayerFameFromShield~=nil and refreshPlayerFameFromShield(playerIndex)~=true then
		error("Fame/Reputation could not read the moved Fame shield for "..tostring(turnOrder[playerIndex] and turnOrder[playerIndex].mage or playerIndex)..".",2)
	end
end

-- A failed physical update must not leave logical Fame/Reputation changed or
-- one marker at a new position while the other remains at the old position.
local function fameRepCommitPhysical(playerIndex,fameShield,reputationShield)
	local player=turnOrder[playerIndex]
	local oldFame,oldReputation,oldLoop=player.fame,player.reputation,player.scoreLoop
	local oldFamePos,oldRepPos=fameShield.getPosition(),reputationShield.getPosition()
	local ok,err=pcall(function()
		fameRepWithSyncSuppressed(function()
			if combatApplyPlayerFameReputationBase(playerIndex,fameShield,reputationShield)~=true then
				error("Fame/Reputation commit refused for "..tostring(player.mage),2)
			end
			syncPlayerFameFromMarker(playerIndex)
		end)
	end)
	if ok then return true end
	player.fame,player.reputation,player.scoreLoop=oldFame,oldReputation,oldLoop
	-- TTS can fail after the first setPosition. Restore whichever shields still
	-- exist, without allowing a rollback failure to hide the original error.
	pcall(function()
		local live=getObjectFromGUID(player.fameGUID)
		if live~=nil and live.isDestroyed()~=true then live.setPosition(oldFamePos) end
	end)
	pcall(function()
		local live=getObjectFromGUID(player.reputationGUID)
		if live~=nil and live.isDestroyed()~=true then live.setPosition(oldRepPos) end
	end)
	error(err,0)
end

--Apply only rewards added after the normal pre-end-turn commit. The cumulative fameGain/repGain
--values remain intact for the reward display, while the physical/logical tracks receive just the delta.
local function syncPostCommitAdjustments(playerIndex)
	if fameRepSyncSuppressed==true then return end
	local player=turnOrder[playerIndex]
	local committed=gStates.fameRepCommitted~=nil and gStates.fameRepCommitted[playerIndex] or nil
	if player==nil or committed==nil then return end
	local fameTotal,repTotal=player.fameGain or 0,player.repGain or 0
	local fameDelta=fameTotal-(committed.fame or 0)
	local repDelta=repTotal-(committed.rep or 0)
	if fameDelta==0 and repDelta==0 then return end
	local fameShield,reputationShield=fameRepResolveCommitMarkers(playerIndex)
	if fameShield==nil then return false end

	local displayRep
	local ok,err=pcall(function()
		local reputation=fameRepCurrentReputation(playerIndex)
		repDelta=fameRepClamp(repDelta,-7-reputation,7-reputation)
		displayRep=(committed.rep or 0)+repDelta
		player.fameGain=fameDelta
		player.repGain=repDelta
		fameRepCommitPhysical(playerIndex,fameShield,reputationShield)
	end)
	-- The reward display is cumulative; only the temporary delta goes to the
	-- physical marker. Restore it even when a TTS operation throws.
	player.fameGain=fameTotal
	player.repGain=ok and displayRep or repTotal
	if not ok then error(err,0) end
	committed.fame=fameTotal
	committed.rep=displayRep
	return true
end

function fameReputationApplyPlayerFameReputation(playerIndex)
	local player=turnOrder[playerIndex]
	if player==nil then return false end
	local fameShield,reputationShield=fameRepResolveCommitMarkers(playerIndex)
	if fameShield==nil then return false end
	local oldRepGain=player.repGain
	local ok,err=pcall(function()
		normalizePendingReputation(playerIndex)
		fameRepCommitPhysical(playerIndex,fameShield,reputationShield)
	end)
	if not ok then player.repGain=oldRepGain error(err,0) end
	local committed=fameRepCommitTable()
	committed[playerIndex]={fame=player.fameGain or 0,rep=player.repGain or 0}
	-- A Hidden Valley assault loss is committed only after both markers moved.
	gStates.hiddenValleyRepLossActive=nil
	return true
end

local function possessedManualAward(perks)
	if perks==nil then return 0 end
	local amount=tonumber(perks.fame) or 0
	if perks.faction~=nil and factionRewardUsesJustFame(perks.faction)==true then amount=amount+1 end
	return amount
end

--Combat owns the physical Possessed attachment search. Record accounting against the exact enemy
--and player it resolved instead of predicting that asynchronous result here.
function fameReputationPossessedAttachmentResolved(possessedGUID,enemyGUID,playerIndex)
	if possessedGUID==nil or enemyGUID==nil or playerIndex==nil or turnOrder[playerIndex]==nil then return end
	possessedAttachPending[possessedGUID]={
		playerIndex=playerIndex,
		registered=gStates.gainList~=nil and gStates.gainList[enemyGUID]~=nil,
		oldAward=possessedManualAward(gStates.monsterPerks~=nil and gStates.monsterPerks[enemyGUID] or nil)
	}
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
	--Only a manual unlink cancels pending Fame. Combat uses detachCleanup after a defeated
	--enemy has already contributed its Possessed bonus to the end-turn reward total.
	if id~=nil and id:sub(1,6)=="detach" and id~="detachCleanup" then
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

local function fameRepFinishMainUIBatch()
	local pending=fameRepMainUIBatch
	fameRepMainUIBatch=nil
	if pending==nil then return end
	local playerIndex=pending.playerIndex
	if turnOrder[playerIndex]~=nil and (gStates.fameRepCommitted==nil or gStates.fameRepCommitted[playerIndex]==nil) then
		--Committed gains are cumulative display totals, not pending deltas. Re-clamping
		--them against the updated track would turn a move to -7 into a false +1 refund.
		normalizePendingReputation(playerIndex)
	end
	hiddenValleyNormalizeSiteLoss()
	correctPossessedAttachmentAwards()
	if turnOrder[playerIndex]~=nil then syncPostCommitAdjustments(playerIndex) end
end

function fameReputationMainUIUpdate(...)
	if gStates.firstStarted~=true then return uiMainUIUpdateBase(...) end
	local playerIndex=gStates.turnNumber
	--A turn transition should not carry the previous player's accounting baseline into the new turn.
	--Flush that rare boundary synchronously, then start a fresh coalesced batch for the current player.
	if fameRepMainUIBatch~=nil and fameRepMainUIBatch.playerIndex~=playerIndex then fameRepFinishMainUIBatch() end
	if fameRepMainUIBatch==nil then
		if turnOrder[playerIndex]~=nil and turnOrder[playerIndex].reputation==nil then fameRepCurrentReputation(playerIndex) end
		fameRepMainUIBatch={playerIndex=playerIndex}
	end
	return uiMainUIUpdateBase(select(1,...),fameRepFinishMainUIBatch)
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
	for playerIndex,entry in ipairs(turnOrder) do
		if entry.mage~=gStates.positionMageKnight[5] then syncPlayerFameFromMarker(playerIndex) end
	end
	return result
end

--Plundering remains legal at -7 Reputation; the Reputation loss simply cannot move below the track.
function fameReputationPlunderVillage(player,mouseButton,id)
	if mouseButton=="-1" and legalPlayerCheck(player.color,tonumber(id:sub(8,8)))==true then
		for a=1,#turnOrder do
			if turnOrder[a].seatPos==tonumber(id:sub(8,8)) then
				fameRepCurrentReputation(a)
				broadcastToAll(joinLang({translateWord[turnOrder[a].mage],"{en} just Plundered their Village.{it} ha appena Saccheggiato il proprio Villaggio.{ru} разграбляет деревню.{zh-tw}刚刚劫掠了他们的村庄{zh-cn}刚刚劫掠了他们的村庄{ko}: 마을을 약탈했습니다.{es} acaba de saquear su aldea.{fr} vient de Piller leur Village.{pt-br} acabou de Saquear a Vila{de} hat gerade ihr Dorf geplündert. "}),positionToColor(a))
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

-- The player can correct a missing shield and retry Rewards Claimed. Do not
-- advance the turn and zero the pending reward while its physical commit failed.
local function fameRepEnsureRewardCommitted(playerIndex)
	local player=turnOrder[playerIndex]
	if player==nil or player.mage==gStates.positionMageKnight[5] then return true end
	local committed=gStates.fameRepCommitted~=nil and gStates.fameRepCommitted[playerIndex] or nil
	if committed==nil and ((player.fameGain or 0)~=0 or (player.repGain or 0)~=0) then
		if fameReputationApplyPlayerFameReputation(playerIndex)~=true then return false end
	end
	return syncPostCommitAdjustments(playerIndex)~=false
end

function fameReputationAdvanceCoopRewardPhase()
	local entry=gStates.coopRewardQueue~=nil and gStates.coopRewardQueue[gStates.coopRewardIndex] or nil
	if entry~=nil and fameRepEnsureRewardCommitted(entry.player)~=true then return false end
	return fameRepWithSyncSuppressed(function()
		local result=combatAdvanceCoopRewardPhaseBase()
		if entry~=nil and gStates.fameRepCommitted~=nil then gStates.fameRepCommitted[entry.player]=nil end
		return result
	end)
end

function fameReputationEndTurnRaw(player,mouseButton,id,rewindReady)
	local playerIndex=gStates.turnNumber
	local coopRewards=gStates.coopAssaultPhase=="rewards"
	-- Combat's own cleanup gate must run before any attempt to retry a missed
	-- initial reward commit; otherwise a premature click could award Fame before
	-- all defeated monsters have returned and their rewards have settled.
	if gStates.preEndTurn==true and gStates.combatPreEndTurnRecovery~=nil then return end
	if coopRewards~=true then
		if gStates.preEndTurn==true then
			if fameRepEnsureRewardCommitted(playerIndex)~=true then return false end
		elseif syncPostCommitAdjustments(playerIndex)==false then
			return false
		end
	end
	local result
	if coopRewards~=true then
		result=fameRepWithSyncSuppressed(function() return turnEndTurnRawBase(player,mouseButton,id,rewindReady) end)
	else
		result=turnEndTurnRawBase(player,mouseButton,id,rewindReady)
	end
	--Only clear the persisted commit marker when the turn actually advanced past Rewards Claimed.
	if gStates.preEndTurn~=true and gStates.fameRepCommitted~=nil then gStates.fameRepCommitted[playerIndex]=nil end
	return result
end

function fameReputationOnLoadRaw(saved_data, loaded_data)
	local result=eventsOnLoadRawBase(saved_data,loaded_data)
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

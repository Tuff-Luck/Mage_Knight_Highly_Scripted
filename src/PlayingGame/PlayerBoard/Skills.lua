-- Player-board Skills runtime.

function refreshMageSkillLocations()
	local double={}
	for skillGUID, _ in pairs(skillTokens) do
		local skill=getObjectFromGUID(skillGUID)
		if skill~=nil then
			local objPos=skill.getPosition()
			if gStates.mageSkills[skillGUID]==nil then gStates.mageSkills[skillGUID]={objPos[1], objPos[2], objPos[3]} end
			local skillPos=gStates.mageSkills[skillGUID]
			local key=(math.floor(skillPos[1]/0.3)*0.3)..(math.floor(skillPos[3]/0.3)*0.3)
			if double[key]~=nil then
				skillPos[1]=skillPos[1]+0.4
				skillPos[3]=skillPos[3]-0.4
				key=(math.floor(skillPos[1]/0.3)*0.3)..(math.floor(skillPos[3]/0.3)*0.3)
			end
			double[key]=true
		end
	end
end

--Update the text in the Main User Interface

--Alternating reward highlights show the two legal Skill + Advanced Action pairings without enforcing either choice.
rewardSkillHighlightWait=nil
rewardSkillHighlightReadyWait=nil
rewardSkillHighlightPhase=false
rewardSkillHighlighted={}
rewardSkillHighlightColor={1,0.9,0}

function clearRewardSkillChoiceHighlights(keepFirstAction)
	local keepGUID=nil
	if keepFirstAction==true then
		local firstAction=mainOfferFirstCard("Advanced Action")
		if firstAction~=nil then keepGUID=firstAction.guid end
	end
	local kept={}
	for guid, _ in pairs(rewardSkillHighlighted) do
		if guid==keepGUID then kept[guid]=true
		else
			local obj=getObjectFromGUID(guid)
			if obj~=nil then obj.highlightOff(rewardSkillHighlightColor) end
		end
	end
	rewardSkillHighlighted=kept
end

function addRewardSkillChoiceHighlight(obj)
	if obj==nil or rewardSkillHighlighted[obj.guid]==true then return end
	--Explicitly clear highlights between phases; no timed expiry means the first AA can remain highlighted across both legal pairings.
	obj.highlightOn(rewardSkillHighlightColor)
	rewardSkillHighlighted[obj.guid]=true
end

function rewardSkillChoiceActionCards()
	return mainOfferCards("Advanced Action")
end

function rewardSkillChoiceActionHighlights(allCards)
	local actionCards=rewardSkillChoiceActionCards()
	if allCards==true then
		for _,card in ipairs(actionCards) do addRewardSkillChoiceHighlight(card) end
	elseif actionCards[1]~=nil then
		addRewardSkillChoiceHighlight(actionCards[1])
	end
end

function rewardSkillChoiceForeignSkillExists()
	--Hero Challenges never permit the Common Skills alternative after the forced first Skill.
	if gStates.heroChallenges==true then return false end
	if gStates.mageSkills==nil or gStates.skillButtons==nil or gStates.skillButtons<=0 then return false end
	for skillGUID, skillPos in pairs(gStates.mageSkills) do
		local skill=getObjectFromGUID(skillGUID)
		if skill~=nil and skillPos~=nil and skillPos[1]~=nil and skillPos[3]~=nil and skillPos[3]>-30 then
			local skillColumn=math.ceil((skillPos[1]-12.85)/3.7)
			if skillColumn+1~=gStates.skillButtons then return true end
		end
	end
	return false
end

function rewardSkillChoiceCurrentSkills()
	local currentPlayerSkills={}
	if gStates.mageSkills==nil or gStates.skillButtons==nil or gStates.skillButtons<=0 then return currentPlayerSkills end
	for skillGUID, skillPos in pairs(gStates.mageSkills) do
		local skill=getObjectFromGUID(skillGUID)
		if skill~=nil and skillPos~=nil and skillPos[1]~=nil and skillPos[3]~=nil and skillPos[3]>-30 then
			local skillColumn=math.ceil((skillPos[1]-12.85)/3.7)
			if skillColumn+1==gStates.skillButtons then currentPlayerSkills[#currentPlayerSkills+1]={obj=skill, z=skillPos[3]} end
		end
	end
	table.sort(currentPlayerSkills, function(a,b) return a.z>b.z end)
	return currentPlayerSkills
end

function rewardSkillChoiceHighlightsReady()
	if rewardSkillChoiceForeignSkillExists()==false then return false end
	local currentPlayerSkills=rewardSkillChoiceCurrentSkills()
	if currentPlayerSkills[1]==nil or currentPlayerSkills[2]==nil or currentPlayerSkills[1].obj.resting==false or currentPlayerSkills[2].obj.resting==false then return false end
	local actionCards=rewardSkillChoiceActionCards()
	--Do not start while the Advanced Action offer is still being dealt/slid into place.
	if #actionCards<(gStates.offerSize or 3) then return false end
	for _, card in ipairs(actionCards) do if card.resting==false then return false end end
	return true
end

function rewardSkillChoiceSkillHighlights(ownSkills)
	if gStates.mageSkills==nil or gStates.skillButtons==nil or gStates.skillButtons<=0 then return end
	local currentPlayerSkills=rewardSkillChoiceCurrentSkills()
	local playerLevel=0
	for _, details in pairs(turnOrder) do if details.seatPos==gStates.skillButtons then playerLevel=details.level or 0 break end end
	if ownSkills==true then
		if currentPlayerSkills[1]~=nil then addRewardSkillChoiceHighlight(currentPlayerSkills[1].obj) end
		if currentPlayerSkills[2]~=nil and playerLevel<=10 then addRewardSkillChoiceHighlight(currentPlayerSkills[2].obj) end
	else
		for skillGUID, skillPos in pairs(gStates.mageSkills) do
			local skill=getObjectFromGUID(skillGUID)
			if skill~=nil and skillPos~=nil and skillPos[1]~=nil and skillPos[3]~=nil and skillPos[3]>-30 then
				local skillColumn=math.ceil((skillPos[1]-12.85)/3.7)
				if skillColumn+1~=gStates.skillButtons then addRewardSkillChoiceHighlight(skill) end
			end
		end
	end
end

function stopRewardSkillChoiceHighlights()
	if rewardSkillHighlightReadyWait~=nil then Wait.stop(rewardSkillHighlightReadyWait) rewardSkillHighlightReadyWait=nil end
	if rewardSkillHighlightWait~=nil then Wait.stop(rewardSkillHighlightWait) rewardSkillHighlightWait=nil end
	clearRewardSkillChoiceHighlights()
end

function beginRewardSkillChoiceHighlights()
	if gStates.skillButtons==nil or gStates.skillButtons<=0 or rewardSkillChoiceForeignSkillExists()==false then return end
	rewardSkillHighlightPhase=false
	local function alternateHighlights()
		if gStates.skillButtons==nil or gStates.skillButtons<=0 or rewardSkillChoiceForeignSkillExists()==false then stopRewardSkillChoiceHighlights() return end
		--The first Advanced Action belongs to both pairings, so keep it highlighted across the phase switch.
		clearRewardSkillChoiceHighlights(true)
		rewardSkillHighlightPhase=not rewardSkillHighlightPhase
		if rewardSkillHighlightPhase==true then
			--Foreign Skill choice: only the first Advanced Action is paired with it.
			rewardSkillChoiceActionHighlights(false)
			rewardSkillChoiceSkillHighlights(false)
		else
			--Own Skill choice: every Advanced Action in the offer is paired with it.
			rewardSkillChoiceActionHighlights(true)
			rewardSkillChoiceSkillHighlights(true)
		end
	end
	alternateHighlights()
	rewardSkillHighlightWait=safeWaitTime("PlayerBoard.Skills",alternateHighlights, 2, -1)
end

function startRewardSkillChoiceHighlights()
	if gStates.skillButtons==nil or gStates.skillButtons<=0 or rewardSkillHighlightWait~=nil or rewardSkillHighlightReadyWait~=nil then return end
	--On the first Skill claim there are no foreign Skills, so the reminder has nothing useful to explain.
	if rewardSkillChoiceForeignSkillExists()==false then return end
	if rewardSkillChoiceHighlightsReady()==true then beginRewardSkillChoiceHighlights() return end
	rewardSkillHighlightReadyWait=safeWaitCondition("PlayerBoard.Skills",function()
		rewardSkillHighlightReadyWait=nil
		if rewardSkillChoiceHighlightsReady()==true then beginRewardSkillChoiceHighlights() end
	end, function()
		return gStates.skillButtons==nil or gStates.skillButtons<=0 or rewardSkillChoiceForeignSkillExists()==false or rewardSkillChoiceHighlightsReady()==true
	end)
end

--Moves claimed skill to player location
masterOfChaosPause=false
function __skillMove_raw(player, mouseButton, id, rewindReady)
	if mouseButton=="-1" then
		if legalPlayerCheck(player.color, gStates.skillButtons)==true then--and turnOrder[gStates.turnNumber].mage~=gStates.positionMageKnight[5]
			local skillRewindOwner="Skill claim "..tostring(gStates.skillButtons)
			stopRewardSkillChoiceHighlights()
			--The Claim button already contains the exact Skill GUID. Use that as the authority instead of
			--decoding the communal row/column number back into approximate coordinates; the old decode was
			--fragile if the pool shifted and was wrong on row numbers 8/16/24/32.
			local claimedGUID=id:sub(1, 6)
			local claimedSkill=getObjectFromGUID(claimedGUID)
			local claimedHome=gStates.mageSkills~=nil and gStates.mageSkills[claimedGUID] or nil
			--A live Claim button also carries its 1..32 offer slot. Normally the saved GUID location is
			--present, but keep a correctly decoded fallback so damaged bookkeeping cannot deadlock the reward.
			if claimedHome==nil then
				local source=tonumber(id:sub(7, string.len(id)))
				if source~=nil and source>=1 and source<=32 then
					local column=math.floor((source-1)/8)
					local row=((source-1)%8)+1
					claimedHome={(column*3.7)+11,2,(row*1.35)-25.3}
				end
			end
			if gStates.heroChallenges==true and claimedSkill~=nil and claimedHome~=nil and claimedHome[3]>-30 then
				local claimedColumn=math.ceil((claimedHome[1]-12.85)/3.7)+1
				if claimedColumn~=gStates.skillButtons then
					claimedSkill.unlock()
					claimedSkill.setPositionSmooth(claimedHome)
					broadcastToColor("{en}Hero Challenges: choose one of your two newly flipped Skills.{ru}Испытания героев: выберите один из двух только что открытых навыков.{zh-tw}英雄挑戰：從你剛翻開的兩個技能中選擇一個。{zh-cn}英雄挑战：从你刚翻开的两个技能中选择一个。{ko}영웅 도전: 방금 공개한 두 스킬 중 하나를 선택하세요.{es}Desafíos de Héroe: elige una de tus dos Habilidades recién reveladas.{fr}Défis de Héros : choisissez l'une des deux Compétences que vous venez de révéler.{pt-br}Desafios de Herói: escolha uma das duas Habilidades recém-reveladas.{de}Heldenherausforderungen: Wähle eine deiner beiden gerade aufgedeckten Fertigkeiten.",player.color or "Black",{1,0.6,0.2})
					if rewindReady==true then rewindTransactionFinish(skillRewindOwner) end
					return
				end
			end
			--Skill claiming rewrites the saved skill-location table while several tokens are still moving.
			--Take the rewind point before that transaction begins, then release after the layout has settled.
			if rewindReady~=true then
				if rewindTransactionOwnerActive(skillRewindOwner)==true then return end
				rewindTransactionStart(function() skillMove(player,mouseButton,id,true) end,skillRewindOwner)
				return
			end
			if claimedSkill==nil or claimedHome==nil or claimedHome[1]==nil or claimedHome[3]==nil then
				rewindTransactionFinish(skillRewindOwner)
				skillButtonActivate()
				return
			end
			local communalHome={claimedHome[1], claimedHome[2] or 2, claimedHome[3]}
			--update skill location register with a free spot on player board
			local count=0
			for skillGUID, skillPos in pairs(gStates.mageSkills) do
				if skillPos~=nil and skillPos[1]~=nil and skillPos[3]~=nil and skillPos[3]<-36.9 and math.floor(skillPos[1])==math.floor(((gStates.skillButtons*40)-107.45)) then count=count+1 end
			end
			gStates.mageSkills[claimedGUID]={((gStates.skillButtons*40)-107.45), 1.1, -38.67-(1.48*count)}
			--Bonds of Loyalty goes to unit area
			if claimedGUID=="f30dd4" then
				local bondsX=unitLayoutNextCommandX(gStates.skillButtons)
				gStates.mageSkills[claimedGUID]={bondsX,1.1,-31.19}
				scheduleUnitLayoutRefresh(gStates.skillButtons)
				addRegularUnitsToOffer(2)
				broadcastToAll("{en}Two more Regular units added to the Unit Offer for this round.{ru}Два дополнительных обычных отряда доступны в этом раунде{zh-tw}本輪的部隊供應區增加兩個常規部隊。{zh-cn}本轮增加了两个部队供应{ko}일반 유닛 두 개를 공급처에 추가합니다{es}Se agregaron dos unidades regulares más a la oferta de unidades para esta ronda.{fr}Deux autres unités régulières ajoutées à l'offre d'unités pour ce tour.{pt-br}2 unidades Regulares a mais adicionadas a Oferta de Unidades por esta Rodada{de}Zwei weitere reguläre Einheiten wurden dem Einheitenangebot für diese Runde hinzugefügt.", {1,1,0.5})
			end
			--Master of Chaos
			if claimedGUID=="1ff34f" then masterOfChaosSetup(gStates.skillButtons) end
			--move selected skill
			claimedSkill.unlock()
			claimedSkill.setPositionSmooth(gStates.mageSkills[claimedGUID])
			if gStates.motivationSkill[claimedGUID]~=nil then
				gStates.motivationSkill[claimedGUID].pos=gStates.skillButtons
				gStates.motivationSkill[claimedGUID].state="active"
				mainUIUpdate("Skill Claimed")
			end
			--move remaining skills in the claimed communal column down. Missing/stale GUIDs are ignored;
			--they must never be able to strand a completed claim with gStates.skillButtons still active.
			for skillGUID, skillPos in pairs(gStates.mageSkills) do
				if skillGUID~=claimedGUID and skillPos~=nil and skillPos[1]~=nil and skillPos[3]~=nil
					and math.floor(communalHome[1])==math.floor(skillPos[1]) and skillPos[3]>communalHome[3] then
					local remainingSkill=getObjectFromGUID(skillGUID)
					if remainingSkill~=nil then
						gStates.mageSkills[skillGUID][3]=gStates.mageSkills[skillGUID][3]-1.35
						remainingSkill.unlock()
						remainingSkill.setPositionSmooth(gStates.mageSkills[skillGUID])
						local remainingGUID=skillGUID
						safeWaitTime("PlayerBoard.Skills",function()
							safeWaitCondition("PlayerBoard.Skills",function()
								local obj=getObjectFromGUID(remainingGUID)
								if obj~=nil then obj.unlock() end
							end, function()
								local obj=getObjectFromGUID(remainingGUID)
								return obj==nil or obj.resting
							end)
						end, 1)
					end
				end
			end
			--Lock Reward claim check button

			--limit advanced action selection if another players skill chosen

			--deploy a dummy skill for next level up.
			if gStates.playersRef==5 then
				local exist=0
				local dummyPos=0
				for a=1, #turnOrder, 1 do
					if turnOrder[a].mage==gStates.positionMageKnight[5] then dummyPos=a break end
				end
				if dummyPos>0 and turnOrder[dummyPos]~=nil then
					for skillGUID, skillPos in pairs(gStates.mageSkills) do
						if skillPos~=nil and skillPos[1]~=nil and math.floor(skillPos[1])==math.floor((turnOrder[dummyPos].seatPos*3.7)+7.3) then exist=exist+1 end
					end
					local pos={(turnOrder[dummyPos].seatPos*3.7)+7.3, 2.00, -23.95+(exist*1.35)}
					local b=nil
					local allSkillsBag=getObjectFromGUID(GUID.bag.allSkills)
					if allSkillsBag~=nil then--use "all Skills" bag if it exists
						b=allSkillsBag.takeObject({position=pos, rotation={0, 180, 0}})
					else
						local dummySkillBag=getObjectFromGUID(turnOrder[dummyPos].skillBagGUID)
						if dummySkillBag~=nil then b=dummySkillBag.takeObject({position=pos, rotation={0, 180, 0}}) end
					end
					if b~=nil then
						safeWaitCondition("PlayerBoard.Skills",function() if b~=nil then b.lock() end end, function() return b==nil or b.resting end)
						gStates.mageSkills[b.guid]=pos
					end
				end
			end
			--turn off skill claim buttons
			local found=false
			for a=1, #turnOrder, 1 do
				if turnOrder[a].seatPos==gStates.skillButtons and turnOrder[a].levelUp>0 then levelUp(a) found=true end
			end
			if found==false then
				gStates.skillButtons=0
				stopRewardSkillChoiceHighlights()
				safeWaitFrames("PlayerBoard.Skills",function()
					for skillGUID, _ in pairs(gStates.mageSkills) do
						local skill=getObjectFromGUID(skillGUID)
						if skill~=nil then skill.UI.setXmlTable({{}}) end
					end
				end, 5)
			end
			safeWaitTime("PlayerBoard.Skills",function() rewindTransactionFinish(skillRewindOwner) end,2.0)
		else
			if rewindReady==true then rewindTransactionFinish("Skill claim "..tostring(gStates.skillButtons)) end
			if turnOrder[gStates.turnNumber].mage==gStates.positionMageKnight[5] then
				broadcastToAll("{en}Dummy doesn't claim skill!{ru}Виртуальный игрок не получает навыков!{zh-tw}虛擬玩家不會獲得技能！{zh-cn}虚拟玩家不会选技能{ko}가상 플레이어는 스킬을 얻지 않습니다!{es}¡Dummy no dice tener habilidad!{fr}Le mannequin ne réclame pas de compétence !{pt-br}Jog. Fictício não clama habilidades{de}Dummy beansprucht keine Fertigkeit!", warningColor)
			end
		end
	end
end

--Removes all claim buttons and re-activates only buttons with cards
function claimButtonRefresh()
	--Remove buttons if dummy is choosing
	getObjectFromGUID("483ed5").UI.setXmlTable({{}})
	if gStates.tacticShown==false or turnOrder[gStates.turnNumber].mage==gStates.positionMageKnight[5] then
		for zoneGUID, cardSource in pairs(tacticClaimingZones) do
			for _, obj in pairs(getObjectFromGUID(zoneGUID).getObjects()) do
				if isTacticCard(obj) then
					obj.UI.setXmlTable({{}})
				end
			end
		end
	end
	--Add buttons
	safeWaitTime("PlayerBoard.Skills",function()
		if gStates.tacticShown==true then
			--Tactic card claim buttons
			if turnOrder[gStates.turnNumber].mage==gStates.positionMageKnight[5] then
				getObjectFromGUID("483ed5").UI.setXmlTable({createClaimButton("483ed5", "tactic7")})
			else
				for zoneGUID, cardSource in pairs(tacticClaimingZones) do
					if getObjectFromGUID(zoneGUID).getObjects()~=nil then
						for _, obj in pairs(getObjectFromGUID(zoneGUID).getObjects()) do
							for a=1, 12, 1 do
								if obj.guid==tacticCard[a] then
									obj.UI.setXmlTable({createClaimButton(obj.guid, cardSource)})
									break
								end
							end
						end
					end
				end
			end
		end
		if gStates.tacticRemove==true then
			--Remove Tactic Claim Button
			if gStates.discardTactics==2 then
				getObjectFromGUID("483ed5").UI.setXmlTable({createClaimButton("483ed5", "removeTactic5")})
			else
				for zoneGUID, cardSource in pairs(tacticClaimingZones) do
					if cardSource:sub(1,6)=="tactic" then
						local cardSourceRemove="removeTactic"..cardSource:sub(7,8)
						local card=getObjectFromGUID(zoneGUID).getObjects()
						if #card>=1 then
							card[1].UI.setXmlTable({createClaimButton(card[1].guid, cardSourceRemove)})
						end
					end
				end
			end
		end
		if gStates.tacticRemove==false and gStates.tacticShown==false then
			--offer buttons
			for zoneGUID, _ in pairs(cardClaimingZones) do
				local zone=getObjectFromGUID(zoneGUID)
				if zone~=nil then
					for _, card in pairs(zone.getObjects()) do
						local cardSource=offerClaimSource(zoneGUID,card)
						if card.type=="Card" and gameCards[card.guid]~=nil and cardSource~=nil then
							card.UI.setXmlTable({{}})
							if gStates.preEndTurn==false or cardSource~="monastery" then
								card.UI.setXmlTable({createClaimButton(card.guid, cardSource)})
							end
						end
					end
				end
			end
			--artifact buttons
			local count=0
			if gStates.dealtArtifacts~=nil then
				for guid, state in pairs(gStates.dealtArtifacts) do
					if state==true then
						count=count+1
						local artifact=getObjectFromGUID(guid)
						if artifact~=nil then artifact.UI.setXmlTable({createClaimButton(guid, "artifactReward")}) end
					end
				end
			end
			if count==0 then
				local artifactDeck=getObjectFromGUID(GUID.deck.artifact)
				if artifactDeck~=nil then
					artifactDeck.UI.setAttribute("ac75c4ArtifactDown", "active", "true")
					artifactDeck.UI.setAttribute("ac75c4ArtifactOffer", "active", "true")
					artifactDeck.UI.setAttribute("ac75c4ArtifactUp", "active", "true")
					artifactDeck.UI.setAttribute("ac75c4ArtifactDownImage", "image", "Overkill Down")
					artifactDeck.UI.setAttribute("ac75c4ArtifactOfferImage", "image", "Sliced Button/Button Object Active")
					artifactDeck.UI.setAttribute("ac75c4ArtifactUpImage", "image", "Overkill Up")
				end
			end
		end
	end, 0.3)
end

local function skillPositionCopy(position)
	if position==nil then return nil end
	return {position[1], position[2], position[3]}
end

local function coopCompSkillActivationTable()
	if gStates.coopCompSkillActivation==nil then gStates.coopCompSkillActivation={} end
	return gStates.coopCompSkillActivation
end

local function coopCompSkillOwnedAreaPlayer(position)
	if position==nil or position[3]>=-35 then return nil end
	for playerIndex, details in pairs(turnOrder) do
		if details.seatPos~=nil and math.abs(position[1]-((details.seatPos*40)-107.45))<2 then return playerIndex end
	end
	return nil
end

local function coopCompSkillPoolPosition(position)
	return position~=nil and position[3]>-25
end

local function coopCompSkillBroadcast(message, playerIndex)
	if playerIndex~=nil and turnOrder[playerIndex]~=nil then broadcastToAll(message, positionToColor(playerIndex))
	else broadcastToAll(message, {1,1,0.5}) end
end

local function deactivateCoopCompSkill(skillGUID, showBroadcast)
	local active=coopCompSkillActivationTable()
	local record=active[skillGUID]
	if record==nil then return false end
	active[skillGUID]=nil
	if showBroadcast~=false then coopCompSkillBroadcast("{en}Skill Deactivated{ru}Навык деактивирован{zh-tw}技能已停用{zh-cn}技能已停用{ko}스킬 비활성화됨{es}Habilidad desactivada{fr}Compétence désactivée{pt-br}Habilidade desativada{de}Fertigkeit deaktiviert", record.player) end
	return true
end

--A Tome swap is inferred from an owned Skill being physically dropped in the common Skill area. This
--also lets a replacement go straight from the pool into the Play Area without losing its new home.
local function tomeSkillSwapTable()
	if gStates.tomeSkillSwapPending==nil then gStates.tomeSkillSwapPending={} end
	return gStates.tomeSkillSwapPending
end

--Motivation ownership is normally assigned by the Skill claim button. Tome/Circlet swaps are physical,
--so mirror that ownership here and refresh only the Out of Turn Actions menu.
local function tomeMotivationSnapshot(skillGUID)
	local stats=gStates.motivationSkill~=nil and gStates.motivationSkill[skillGUID] or nil
	if stats==nil then return nil end
	return {pos=stats.pos, state=stats.state}
end

local function tomeRestoreMotivation(skillGUID, snapshot)
	local stats=gStates.motivationSkill~=nil and gStates.motivationSkill[skillGUID] or nil
	if stats==nil or snapshot==nil then return false end
	stats.pos=snapshot.pos
	stats.state=snapshot.state
	return true
end

local function tomeAssignMotivation(skillGUID, playerIndex)
	local stats=gStates.motivationSkill~=nil and gStates.motivationSkill[skillGUID] or nil
	local player=turnOrder[playerIndex]
	if stats==nil or player==nil or player.seatPos==nil then return false end
	stats.pos=player.seatPos
	stats.state="active"
	return true
end

local function tomeRemoveMotivationOwner(skillGUID)
	local stats=gStates.motivationSkill~=nil and gStates.motivationSkill[skillGUID] or nil
	if stats==nil then return false end
	stats.pos=0
	return true
end

local function tomeRefreshMotivationUI(changed)
	if changed==true and refreshOutOfTurnActions~=nil then refreshOutOfTurnActions(nil, nil, true, false) end
end

local function tomeRestoreReplacement(pending, deactivateReplacement)
	if pending==nil or pending.replacementGUID==nil then return end
	local replacementGUID=pending.replacementGUID
	if pending.replacementPoolHome~=nil then gStates.mageSkills[replacementGUID]=skillPositionCopy(pending.replacementPoolHome) end
	local replacement=getObjectFromGUID(replacementGUID)
	if replacement~=nil and pending.replacementPoolHome~=nil then
		replacement.unlock()
		replacement.setPositionSmooth(pending.replacementPoolHome)
	end
	local motivationChanged=tomeRestoreMotivation(replacementGUID, pending.replacementMotivation)
	if deactivateReplacement==true then
		local record=coopCompSkillActivationTable()[replacementGUID]
		if record~=nil and record.tomeReplacement==true and gStates.doingTheRounds[replacementGUID]==nil then deactivateCoopCompSkill(replacementGUID, true) end
	end
	pending.replacementGUID=nil
	pending.replacementPoolHome=nil
	pending.replacementMotivation=nil
	tomeRefreshMotivationUI(motivationChanged)
end

local function tomeUndoSkillSwap(playerIndex)
	local swaps=tomeSkillSwapTable()
	local pending=swaps[playerIndex]
	if pending==nil then return false end
	tomeRestoreReplacement(pending, true)
	if pending.oldSkill~=nil and pending.ownerHome~=nil then
		gStates.mageSkills[pending.oldSkill]=skillPositionCopy(pending.ownerHome)
		local oldSkill=getObjectFromGUID(pending.oldSkill)
		if oldSkill~=nil then
			oldSkill.unlock()
			oldSkill.setPositionSmooth(pending.ownerHome)
		end
	end
	local motivationChanged=tomeRestoreMotivation(pending.oldSkill, pending.oldMotivation)
	swaps[playerIndex]=nil
	tomeRefreshMotivationUI(motivationChanged)
	return true
end

local function tomeAssignReplacement(skillGUID, playerIndex)
	local pending=tomeSkillSwapTable()[playerIndex]
	if pending==nil or skillGUID==pending.oldSkill then return false end
	if pending.replacementGUID==skillGUID then return true end
	local currentHome=gStates.mageSkills[skillGUID]
	if coopCompSkillPoolPosition(currentHome)~=true then return false end
	tomeRestoreReplacement(pending, true)
	pending.replacementGUID=skillGUID
	pending.replacementPoolHome=skillPositionCopy(currentHome)
	pending.replacementMotivation=tomeMotivationSnapshot(skillGUID)
	gStates.mageSkills[skillGUID]=skillPositionCopy(pending.ownerHome)
	tomeRefreshMotivationUI(tomeAssignMotivation(skillGUID, playerIndex))
	return true
end

function tomeSkillEnteredPlay(skillGUID, playerIndex)
	local pending=tomeSkillSwapTable()[playerIndex]
	if pending==nil then return end
	if skillGUID==pending.oldSkill then tomeUndoSkillSwap(playerIndex)
	else tomeAssignReplacement(skillGUID, playerIndex) end
end

--Run immediately on human drop, before the older resting/home-position update, so a quick physical
--swap cannot put the replacement into the Play Area before we remember which owned Skill was traded.
function tomeSkillDropped(skillGUID, position)
	if skillGUID==nil or skillTokens[skillGUID]==nil or position==nil then return end
	local swaps=tomeSkillSwapTable()

	--Returning a tentative replacement to the pool means the player changed their choice.
	if coopCompSkillPoolPosition(position)==true then
		for _, pending in pairs(swaps) do
			if pending.replacementGUID==skillGUID then
				tomeRestoreReplacement(pending, true)
				break
			end
		end
	end

	--Dropping the original Skill back into its owner's Skill column cancels the physical swap.
	local droppedOwner=coopCompSkillOwnedAreaPlayer(position)
	if droppedOwner~=nil then
		local pending=swaps[droppedOwner]
		if pending~=nil then
			if pending.oldSkill==skillGUID then tomeUndoSkillSwap(droppedOwner) return
			elseif tomeAssignReplacement(skillGUID, droppedOwner)==true then return end
		end
	end

	--An owned Skill entering the common offer begins/replaces the pending Tome transaction. A temporary
	--Circlet Skill already has a pool home, so it deliberately does not satisfy this test.
	if coopCompSkillPoolPosition(position)==true then
		local oldHome=gStates.mageSkills[skillGUID]
		local owner=coopCompSkillOwnedAreaPlayer(oldHome)
		if owner~=nil then
			local existing=swaps[owner]
			if existing~=nil and existing.oldSkill~=skillGUID then tomeUndoSkillSwap(owner) end
			swaps[owner]={player=owner, oldSkill=skillGUID, ownerHome=skillPositionCopy(oldHome), oldPoolHome=skillPositionCopy(position), oldMotivation=tomeMotivationSnapshot(skillGUID)}
			--Commit the traded Skill's new home immediately; the older resting callback will refine the exact Y/Z later.
			gStates.mageSkills[skillGUID]=skillPositionCopy(position)
			tomeRefreshMotivationUI(tomeRemoveMotivationOwner(skillGUID))
		end
	end
end

function activateCoopCompSkill(skillGUID, playerIndex)
	local details=skillTokens[skillGUID]
	if details==nil or (details.skillType~="Coop" and details.skillType~="Comp") then return end
	local active=coopCompSkillActivationTable()
	local record=active[skillGUID]
	if record==nil then
		--A newly played Interactive skill is illegal once End of Round / Scenario End has locked new plays.
		if coopCompSkillPlayLocked~=nil and coopCompSkillPlayLocked()==true then return end
		record={player=playerIndex, round=gStates.currentRound, location="play"}
		local pending=tomeSkillSwapTable()[playerIndex]
		if pending~=nil and pending.replacementGUID==skillGUID then record.tomeReplacement=true end
		active[skillGUID]=record
		coopCompSkillBroadcast("{en}Skill Activated{ru}Навык активирован{zh-tw}技能已啟動{zh-cn}技能已激活{ko}스킬 활성화됨{es}Habilidad activada{fr}Compétence activée{pt-br}Habilidade ativada{de}Fertigkeit aktiviert", playerIndex)
	else
		if record.player==nil then record.player=playerIndex end
		record.location="play"
		record.detached=nil
		record.leftPlayArea=nil
	end
end

function coopCompSkillLeftPlayArea(skillGUID, playerIndex)
	local record=coopCompSkillActivationTable()[skillGUID]
	if record==nil then return end
	record.leftPlayArea=true
	record.leftPlayer=playerIndex
	record.location="moving"
end

function coopCompSkillDropped(skillGUID, position)
	local record=coopCompSkillActivationTable()[skillGUID]
	if record==nil then return end
	if coopCompSkillPoolPosition(position)==true then
		--A tentative Tome replacement being put back is an undo, not a surviving activation.
		if record.tomeReplacement==true then return end
		if record.location~="pool" then coopCompSkillBroadcast("{en}Skill Still Activated{ru}Навык всё ещё активен{zh-tw}技能仍然啟動{zh-cn}技能仍然激活{ko}스킬이 아직 활성화되어 있습니다{es}La Habilidad sigue activada{fr}La Compétence est toujours activée{pt-br}A Habilidade continua ativada{de}Fertigkeit ist weiterhin aktiviert", record.player) end
		record.location="pool"
		record.detached=true
		record.leftPlayArea=nil
		return
	end
	if coopCompSkillOwnedAreaPlayer(position)~=nil then
		if gStates.doingTheRounds[skillGUID]~=nil and doingTheRounds~=nil then doingTheRounds(skillGUID, "", 0, true)
		else deactivateCoopCompSkill(skillGUID, true) end
	end
end

local function commitTomeSkillSwap(playerIndex)
	local swaps=tomeSkillSwapTable()
	local pending=swaps[playerIndex]
	if pending==nil then return end
	if pending.replacementGUID~=nil then
		local record=coopCompSkillActivationTable()[pending.replacementGUID]
		if record~=nil then record.tomeReplacement=nil end
	end
	swaps[playerIndex]=nil
end

local function unlockCommonSkillPoolTokens()
	for skillGUID, position in pairs(gStates.mageSkills or {}) do
		if coopCompSkillPoolPosition(position)==true then
			local skill=getObjectFromGUID(skillGUID)
			if skill~=nil then skill.unlock() end
		end
	end
end

--Coop/competitive skills cannot be newly played after End of Round or Scenario End.
function coopCompSkillPlayLocked()
	return gStates.endRoundCalled==true or (gStates.endGameAchieved~=nil and gStates.endGameAchieved~="false")
end

function coopCompSkillPlayAreaPlayer(skillGUID)
	for playerIndex, playerDetails in pairs(turnOrder) do
		if playerDetails.seatPos~=nil then
			local playArea=getObjectFromGUID(playerPlayAreas[playerDetails.seatPos])
			if playArea~=nil then
				for _, obj in pairs(playArea.getObjects()) do if obj.guid==skillGUID then return playerIndex end end
			end
		end
	end
	return nil
end

--Mark Coop/Competitive skills that cannot be newly played. Skills already legally doing the rounds stay available.
function coopCompSkillXClick() end
local function clearCoopCompSkillX(skill)
	local remove={}
	for _, button in pairs(skill.getButtons() or {}) do if button.click_function=="coopCompSkillXClick" then remove[#remove+1]=button.index end end
	table.sort(remove, function(a,b) return a>b end)
	for _, index in ipairs(remove) do skill.removeButton(index) end
end
function refreshCoopCompSkillXs()
	local locked=coopCompSkillPlayLocked()
	for skillGUID, details in pairs(skillTokens) do
		if details.skillType=="Coop" or details.skillType=="Comp" then
			local skill=getObjectFromGUID(skillGUID)
			if skill~=nil then
				clearCoopCompSkillX(skill)
				local paused=gStates.coopCompSkillPaused~=nil and gStates.coopCompSkillPaused[skillGUID]~=nil
				local inRotation=gStates.doingTheRounds[skillGUID]~=nil and paused==false
				if locked==true and inRotation==false then
					skill.createButton({click_function="coopCompSkillXClick", function_owner=Global, label="X", position={0,0.25,0}, rotation={0,0,0}, width=0, height=0, font_size=800, font_color={1,0.1,0.1}, tooltip="{en}Unavailable after End of Round / Scenario End{ru}Недоступно после объявления конца раунда / окончания сценария{zh-tw}宣布回合結束／達成劇本結束後不可使用{zh-cn}宣布回合结束／达成剧本结束后不可使用{ko}라운드 종료 선언 / 시나리오 종료 후에는 사용할 수 없습니다{es}No disponible después de Fin de Ronda / Fin del Escenario{fr}Indisponible après la Fin de la Manche / la Fin du Scénario{pt-br}Indisponível após o Fim da Rodada / Fim do Cenário{de}Nach Rundenende / Szenarioende nicht verfügbar"})
				end
			end
		end
	end
end

function pauseLateCoopCompSkill(skillGUID, playerIndex)
	if skillTokens[skillGUID]==nil or (skillTokens[skillGUID].skillType~="Coop" and skillTokens[skillGUID].skillType~="Comp") then return false end
	if coopCompSkillPlayLocked()==false then return false end
	if playerIndex==nil then playerIndex=coopCompSkillPlayAreaPlayer(skillGUID) end
	if playerIndex==nil then return false end
	if gStates.coopCompSkillPaused==nil then gStates.coopCompSkillPaused={} end
	if gStates.coopCompSkillPaused[skillGUID]==nil then
		gStates.coopCompSkillPaused[skillGUID]={round=gStates.currentRound, player=playerIndex}
		--Keep it registered as doing the rounds so the normal next-round reset returns it home, but skip movement until then.
		if gStates.doingTheRounds[skillGUID]==nil then gStates.doingTheRounds[skillGUID]=playerIndex end
		broadcastToAll("{en}Cooperative and Competitive Skills cannot be played after End of Round has been called or Scenario End has been achieved. Skill automation is paused until the next round.{ru}Кооперативные и соревновательные навыки нельзя разыгрывать после объявления конца раунда или достижения конца сценария. Автоматизация навыков приостановлена до следующего раунда.{zh-tw}宣布回合結束或達成劇本結束後，不能再打出合作或競爭技能。技能自動處理會暫停到下一回合。{zh-cn}宣布回合结束或达成剧本结束后，不能再打出合作或竞争技能。技能自动处理会暂停到下一回合。{ko}라운드 종료가 선언되었거나 시나리오 종료 조건이 달성된 뒤에는 협력/경쟁 스킬을 사용할 수 없습니다. 스킬 자동 처리는 다음 라운드까지 일시 중지됩니다.{es}Las Habilidades Cooperativas y Competitivas no pueden jugarse después de declarar el Fin de Ronda o alcanzar el Fin del Escenario. La automatización de Habilidades queda pausada hasta la siguiente ronda.{fr}Les Compétences Coopératives et Compétitives ne peuvent plus être jouées après l'annonce de la Fin de la Manche ou lorsque la Fin du Scénario est atteinte. L'automatisation des Compétences est suspendue jusqu'à la manche suivante.{pt-br}Habilidades Cooperativas e Competitivas não podem ser jogadas após o Fim da Rodada ser declarado ou o Fim do Cenário ser alcançado. A automação das Habilidades fica pausada até a próxima rodada.{de}Kooperative und kompetitive Fertigkeiten können nicht mehr gespielt werden, nachdem das Rundenende ausgerufen oder das Szenarioende erreicht wurde. Die Fertigkeitsautomatik pausiert bis zur nächsten Runde.", {1,0.5,0})
		refreshCoopCompSkillXs()
	end
	return true
end

--Competitive skill clones are reminders only and are never registered as skills. Source Freeze and Mana Suppression stay played for their owner reward.
sharedSkillAboveZone={	["725de9"]="40ef14",--Krang's Coop Skill
							["818aea"]="8fc095",--Tovak's Coop Skill
							["c4546c"]="d28865",--Tovak's Comp Skill
							["958209"]="22b866"}--Krang's Comp Skill
local competitiveOwnerReward={ ["3bd08e"]=true, ["958209"]=true }

local function lockCompetitiveSkillCloneWhenSettled(clone)
	if clone==nil then return end
	local cloneGUID=clone.guid
	clone.unlock()
	safeWaitFrames("PlayerBoard.Skills",function() safeWaitCondition("PlayerBoard.Skills",function()
		local obj=getObjectFromGUID(cloneGUID)
		if obj~=nil then obj.lock() end
	end, function()
		local obj=getObjectFromGUID(cloneGUID)
		return obj==nil or obj.resting
	end) end, 5)
end

local function competitiveSkillPlayerForSeat(seatPos)
	for playerIndex, details in pairs(turnOrder) do
		if details.seatPos==seatPos and details.seatPos<5 and details.mage~=gStates.positionMageKnight[5] and playerDropoutInactive(playerIndex)==false then return playerIndex end
	end
	return nil
end

local function competitiveSkillReminderCount(seatPos)
	local count=0
	for _, record in pairs(gStates.competitiveSkillReminders or {}) do
		for reminderGUID, reminderSeat in pairs(record.reminders or {}) do
			if reminderSeat==seatPos and getObjectFromGUID(reminderGUID)~=nil then count=count+1 end
		end
	end
	return count
end

local basicManaToken={ ["Red Mana"]=true, ["Blue Mana"]=true, ["Green Mana"]=true, ["White Mana"]=true }

local function competitiveSkillReminderForSeat(record, seatPos)
	for reminderGUID, reminderSeat in pairs(record.reminders or {}) do
		if reminderSeat==seatPos then
			local reminder=getObjectFromGUID(reminderGUID)
			if reminder~=nil then return reminder end
		end
	end
	return nil
end

local function nextCompetitiveSkillReminder(record, fromSeat, nextPlayer)
	if nextPlayer~=nil and turnOrder[nextPlayer]~=nil and turnOrder[nextPlayer].seatPos~=fromSeat then
		local reminder=competitiveSkillReminderForSeat(record, turnOrder[nextPlayer].seatPos)
		if reminder~=nil then return reminder end
	end
	local currentPlayer=gStates.turnNumber
	for playerIndex, details in pairs(turnOrder) do if details.seatPos==fromSeat then currentPlayer=playerIndex break end end
	local best=nil
	local bestDistance=nil
	for reminderGUID, seatPos in pairs(record.reminders or {}) do
		local reminder=getObjectFromGUID(reminderGUID)
		local playerIndex=seatPos~=fromSeat and competitiveSkillPlayerForSeat(seatPos) or nil
		if reminder~=nil and playerIndex~=nil then
			local distance=playerIndex-currentPlayer
			if distance<=0 then distance=distance+#turnOrder end
			if bestDistance==nil or distance<bestDistance then best=reminder bestDistance=distance end
		end
	end
	return best or getObjectFromGUID("958209")
end

local function manaSuppressionTokensAtReminder(record, seatPos)
	local tokens={}
	local reminder=record~=nil and competitiveSkillReminderForSeat(record, seatPos) or nil
	local playArea=playerPlayAreas[seatPos]~=nil and getObjectFromGUID(playerPlayAreas[seatPos]) or nil
	if reminder==nil or playArea==nil then return tokens, reminder end
	local reminderPos=reminder.getPosition()
	for _, token in pairs(playArea.getObjects()) do
		if basicManaToken[token.getName()]==true then
			local tokenPos=token.getPosition()
			if math.abs(tokenPos[1]-reminderPos[1])<=1 and math.abs(tokenPos[3]-reminderPos[3])<=0.65 then tokens[#tokens+1]=token end
		end
	end
	return tokens, reminder
end

local function passManaSuppressionTokens(record, fromSeat, nextPlayer)
	local moved={}
	local tokens, reminder=manaSuppressionTokensAtReminder(record, fromSeat)
	local destination=record~=nil and nextCompetitiveSkillReminder(record, fromSeat, nextPlayer) or nil
	if reminder==nil or destination==nil or destination.guid==reminder.guid then return moved end
	local destinationPos=destination.getPosition()
	local spacing=0.45
	local start=-((#tokens-1)*spacing)/2
	for index, token in ipairs(tokens) do
		token.unlock()
		token.setPositionSmooth({destinationPos[1]+start+((index-1)*spacing), 2+(index*0.25), destinationPos[3]})
		moved[token.guid]=true
	end
	return moved
end

local function clearCompetitiveSkillSeat(skillGUID, seatPos, nextPlayer)
	local record=gStates.competitiveSkillReminders~=nil and gStates.competitiveSkillReminders[skillGUID] or nil
	if record==nil then return {} end
	local moved=skillGUID=="958209" and passManaSuppressionTokens(record, seatPos, nextPlayer) or {}
	for reminderGUID, reminderSeat in pairs(record.reminders or {}) do
		if reminderSeat==seatPos then
			local reminder=getObjectFromGUID(reminderGUID)
			if reminder~=nil then reminder.destruct() end
			record.reminders[reminderGUID]=nil
		end
	end
	for markerGUID, details in pairs(record.markers or {}) do
		if details.seat==seatPos then
			local marker=getObjectFromGUID(markerGUID)
			if marker~=nil then marker.destruct() end
			record.markers[markerGUID]=nil
		end
	end
	return moved
end

function clearCompetitiveSkillReminders(skillGUID)
	if gStates.competitiveSkillReminders==nil then return end
	local record=gStates.competitiveSkillReminders[skillGUID]
	if record==nil then return end
	if skillGUID=="958209" then
		local clearedSeats={}
		for _, seatPos in pairs(record.reminders or {}) do
			if clearedSeats[seatPos]~=true then
				local tokens=manaSuppressionTokensAtReminder(record, seatPos)
				for _, token in pairs(tokens) do getObjectFromGUID(trashCan).putObject(token) end
				clearedSeats[seatPos]=true
			end
		end
	end
	for reminderGUID, _ in pairs(record.reminders or {}) do
		local reminder=getObjectFromGUID(reminderGUID)
		if reminder~=nil then reminder.destruct() end
	end
	for markerGUID, _ in pairs(record.markers or {}) do
		local marker=getObjectFromGUID(markerGUID)
		if marker~=nil then marker.destruct() end
	end
	gStates.competitiveSkillReminders[skillGUID]=nil
end

local function refreshCompetitiveSkillReminderMarkers(skillGUID)
	local record=gStates.competitiveSkillReminders~=nil and gStates.competitiveSkillReminders[skillGUID] or nil
	local zoneGUID=sharedSkillAboveZone[skillGUID]
	local zone=zoneGUID~=nil and getObjectFromGUID(zoneGUID) or nil
	if record==nil then return end
	local seatsToClear={}
	for reminderGUID, seatPos in pairs(record.reminders or {}) do
		if getObjectFromGUID(reminderGUID)==nil or competitiveSkillPlayerForSeat(seatPos)==nil then seatsToClear[seatPos]=true end
	end
	for seatPos, _ in pairs(seatsToClear) do clearCompetitiveSkillSeat(skillGUID, seatPos) end
	if zone==nil then return end
	local originals={}
	for _, marker in pairs(zone.getObjects()) do if marker.type=="Figurine" then originals[marker.guid]=marker end end
	for cloneGUID, details in pairs(record.markers or {}) do
		local clone=getObjectFromGUID(cloneGUID)
		local reminderExists=false
		for reminderGUID, seatPos in pairs(record.reminders or {}) do
			if seatPos==details.seat and getObjectFromGUID(reminderGUID)~=nil then reminderExists=true break end
		end
		if clone==nil then record.markers[cloneGUID]=nil
		elseif reminderExists==false or (competitiveOwnerReward[skillGUID]==true and originals[details.source]==nil) then clone.destruct() record.markers[cloneGUID]=nil end
	end
	local zonePos=zone.getPosition()
	for reminderGUID, seatPos in pairs(record.reminders or {}) do
		local reminder=getObjectFromGUID(reminderGUID)
		if reminder~=nil then
			local reminderPos=reminder.getPosition()
			for sourceGUID, marker in pairs(originals) do
				local found=false
				for cloneGUID, details in pairs(record.markers or {}) do
					if details.source==sourceGUID and details.seat==seatPos and getObjectFromGUID(cloneGUID)~=nil then found=true break end
				end
				if found==false then
					local markerPos=marker.getPosition()
					local clone=marker.clone({position={reminderPos[1]+zonePos[1]-markerPos[1], 2, reminderPos[3]+zonePos[3]-markerPos[3]}, rotation=marker.getRotation()})
					clone.setGMNotes("Competitive Skill Marker:"..skillGUID..":"..sourceGUID..":"..seatPos)
					clone.interactable=false
					lockCompetitiveSkillCloneWhenSettled(clone)
					record.markers[clone.guid]={source=sourceGUID, seat=seatPos}
				end
			end
		end
	end
end

function createCompetitiveSkillReminders(skillGUID, owner)
	if skillTokens[skillGUID]==nil or skillTokens[skillGUID].skillType~="Comp" then return end
	local skill=getObjectFromGUID(skillGUID)
	if skill==nil then return end
	if gStates.competitiveSkillReminders==nil then gStates.competitiveSkillReminders={} end
	local record=gStates.competitiveSkillReminders[skillGUID]
	if record==nil then record={owner=owner, reminders={}, markers={}} gStates.competitiveSkillReminders[skillGUID]=record end
	record.owner=owner record.reminders=record.reminders or {} record.markers=record.markers or {}
	local physicalPlayer=coopCompSkillPlayAreaPlayer(skillGUID)
	if physicalPlayer~=nil and physicalPlayer~=owner and turnOrder[owner]~=nil then
		local target={turnOrder[owner].seatPos*40-109.5, 1.5, -39.41}
		local zoneGUID=sharedSkillAboveZone[skillGUID]
		local zone=zoneGUID~=nil and getObjectFromGUID(zoneGUID) or nil
		if zone~=nil then
			local zonePos=zone.getPosition()
			for _, marker in pairs(zone.getObjects()) do
				if marker.type=="Figurine" then marker.setPositionSmooth({target[1]+zonePos[1]-marker.getPosition()[1], 2, target[3]+zonePos[3]-marker.getPosition()[3]}) end
			end
			zone.setPosition({target[1], 1.4, target[3]})
		end
		skill.setPositionSmooth(target)
	end
	local targetSeats={}
	for playerIndex, details in pairs(turnOrder) do
		if details.seatPos~=nil and details.seatPos<5 and details.mage~=gStates.positionMageKnight[5] and playerIndex~=owner and playerDropoutInactive(playerIndex)==false then targetSeats[details.seatPos]=true end
	end
	for reminderGUID, seatPos in pairs(record.reminders) do
		if targetSeats[seatPos]~=true or getObjectFromGUID(reminderGUID)==nil then clearCompetitiveSkillSeat(skillGUID, seatPos) end
	end
	for seatPos, _ in pairs(targetSeats) do
		local found=false
		for reminderGUID, reminderSeat in pairs(record.reminders) do if reminderSeat==seatPos and getObjectFromGUID(reminderGUID)~=nil then found=true break end end
		if found==false then
			local count=competitiveSkillReminderCount(seatPos)
			local reminder=skill.clone({position={seatPos*40-105, 1.5, -39.41-(1.48*count)}, rotation={0,180,0}})
			reminder.setGMNotes("Competitive Skill Reminder:"..skillGUID..":"..seatPos)
			reminder.clearButtons()
			reminder.UI.setXml("")
			lockCompetitiveSkillCloneWhenSettled(reminder)
			record.reminders[reminder.guid]=seatPos
		end
	end
	refreshCompetitiveSkillReminderMarkers(skillGUID)
	if competitiveOwnerReward[skillGUID]~=true and gStates.mageSkills[skillGUID]~=nil then
		skill.setPositionSmooth({gStates.mageSkills[skillGUID][1], 1.5, gStates.mageSkills[skillGUID][3]})
		skill.setRotationSmooth({0,180,180})
	end
end

local function finishCompetitiveSkill(skillGUID, reset)
	clearCompetitiveSkillReminders(skillGUID)
	local skill=getObjectFromGUID(skillGUID)
	if skill~=nil and gStates.mageSkills[skillGUID]~=nil then
		skill.setPositionSmooth({gStates.mageSkills[skillGUID][1], 1.5, gStates.mageSkills[skillGUID][3]})
		if reset~=true then skill.setRotationSmooth({0,180,180}) end
	end
	gStates.doingTheRounds[skillGUID]=nil
	gStates.soloCoop[skillGUID]=nil
	if gStates.doingTheRoundsVisited~=nil then gStates.doingTheRoundsVisited[skillGUID]=nil end
	deactivateCoopCompSkill(skillGUID, true)
	local zoneGUID=sharedSkillAboveZone[skillGUID]
	local zone=zoneGUID~=nil and getObjectFromGUID(zoneGUID) or nil
	if zone~=nil then for _, marker in pairs(zone.getObjects()) do if marker.type=="Figurine" then getObjectFromGUID(trashCan).putObject(marker) end end end
end

--Move cooperative skills to the next player. Competitive reminders are removed as each affected player's turn finishes.
function doingTheRounds(skillGUID, nextPlayer, count, reset)
	local keepSafe={}
	local skillDetails=skillTokens[skillGUID]
	if skillDetails~=nil and skillDetails.skillType=="Comp" then
		local owner=gStates.doingTheRounds[skillGUID]
		if reset==true then finishCompetitiveSkill(skillGUID, true) return {keepSafe, count} end
		if owner==nil then return {keepSafe, count} end
		if gStates.competitiveSkillReminders==nil or gStates.competitiveSkillReminders[skillGUID]==nil then createCompetitiveSkillReminders(skillGUID, owner) end
		local ownerRewardPending=gStates.soloCoop[skillGUID]==true
		local extraTurnStarted=(gStates.tacticSixState=="Started" or gStates.timeBending=="Started") and gStates.turnNumber==gStates.realTurn
		local currentSeat=turnOrder[gStates.turnNumber]~=nil and turnOrder[gStates.turnNumber].seatPos or nil
		if currentSeat~=nil and extraTurnStarted==false then
			local moved=clearCompetitiveSkillSeat(skillGUID, currentSeat, nextPlayer)
			for tokenGUID, _ in pairs(moved) do keepSafe[tokenGUID]=true end
		end
		refreshCompetitiveSkillReminderMarkers(skillGUID)
		local record=gStates.competitiveSkillReminders~=nil and gStates.competitiveSkillReminders[skillGUID] or nil
		local remindersLeft=0
		if record~=nil then for reminderGUID, _ in pairs(record.reminders or {}) do if getObjectFromGUID(reminderGUID)~=nil then remindersLeft=remindersLeft+1 end end end
		if ownerRewardPending==true and gStates.turnNumber==owner and extraTurnStarted==false then finishCompetitiveSkill(skillGUID, false) return {keepSafe, count}
		elseif ownerRewardPending==false and remindersLeft==0 then
			if gStates.playerCount<=1 or competitiveOwnerReward[skillGUID]==true then gStates.soloCoop[skillGUID]=true
			else finishCompetitiveSkill(skillGUID, false) return {keepSafe, count} end
		end
		local zoneGUID=sharedSkillAboveZone[skillGUID]
		local zone=zoneGUID~=nil and getObjectFromGUID(zoneGUID) or nil
		if zone~=nil and competitiveOwnerReward[skillGUID]==true then for _, marker in pairs(zone.getObjects()) do if marker.type=="Figurine" then keepSafe[marker.guid]=true end end end
		if record~=nil and currentSeat~=nil then
			for markerGUID, details in pairs(record.markers or {}) do if details.seat==currentSeat and getObjectFromGUID(markerGUID)~=nil then keepSafe[markerGUID]=true end end
		end
		return {keepSafe, count}
	end

	if gStates.doingTheRoundsVisited==nil then gStates.doingTheRoundsVisited={} end
	local roundSkill=skillDetails~=nil and skillDetails.skillType=="Coop"
	local roundVisitedLoop=false
	if roundSkill and reset~=true then
		if gStates.doingTheRoundsVisited[skillGUID]==nil then
			gStates.doingTheRoundsVisited[skillGUID]={}
			if gStates.doingTheRounds[skillGUID]~=nil then gStates.doingTheRoundsVisited[skillGUID][gStates.doingTheRounds[skillGUID]]=true end
		end
		--Out-of-order turns such as co-op assaults can skip the original return marker. Reaching any player
		--already visited means a Coop skill has completed one circuit. Same-player extra turns do not count.
		roundVisitedLoop=nextPlayer~=gStates.turnNumber and gStates.doingTheRoundsVisited[skillGUID][nextPlayer]==true
	end
	if gStates.doingTheRounds[skillGUID]==nextPlayer or roundVisitedLoop==true or gStates.soloCoop[skillGUID]==true or reset==true then
		if gStates.playerCount>1 or gStates.soloCoop[skillGUID]==true or reset==true then
			--Flip and return completed skill
			getObjectFromGUID(skillGUID).setPositionSmooth({gStates.mageSkills[skillGUID][1], 1.5, gStates.mageSkills[skillGUID][3]})
			if reset~=true then getObjectFromGUID(skillGUID).setRotationSmooth({0.0, 180.0, 180.0}) end
			gStates.doingTheRounds[skillGUID]=nil
			gStates.soloCoop[skillGUID]=nil
			if gStates.doingTheRoundsVisited~=nil then gStates.doingTheRoundsVisited[skillGUID]=nil end
			deactivateCoopCompSkill(skillGUID, true)
			if sharedSkillAboveZone[skillGUID]~=nil then
				for _, b in pairs(getObjectFromGUID(sharedSkillAboveZone[skillGUID]).getObjects()) do
					if b.type=="Figurine" then getObjectFromGUID(trashCan).putObject(b) end
				end
			end
		else
			--place next to owner skill for solo cooperative play
			if sharedSkillAboveZone[skillGUID]~=nil then
				for _, b in pairs(getObjectFromGUID(sharedSkillAboveZone[skillGUID]).getObjects()) do
					if b.type=="Figurine" then
						local offsetX=getObjectFromGUID(sharedSkillAboveZone[skillGUID]).getPosition()[1]-b.getPosition()[1]
						local offsetZ=getObjectFromGUID(sharedSkillAboveZone[skillGUID]).getPosition()[3]-b.getPosition()[3]
						b.setPositionSmooth({turnOrder[nextPlayer].seatPos*40-109.5+offsetX , 2.0, -39.41+offsetZ})
						keepSafe[b.guid]=true
					end
				end
			end
			getObjectFromGUID(skillGUID).setPositionSmooth({turnOrder[nextPlayer].seatPos*40-109.5 , 1.5, -39.41})
			gStates.soloCoop[skillGUID]=true
		end
	else
		--move cooperative token to next player board
		local position={109.5, 1.48}
		if sharedSkillAboveZone[skillGUID]~=nil then
			for _, b in pairs(getObjectFromGUID(sharedSkillAboveZone[skillGUID]).getObjects()) do
				if b.type=="Figurine" then
					local offsetX=getObjectFromGUID(sharedSkillAboveZone[skillGUID]).getPosition()[1]-b.getPosition()[1]
					local offsetZ=getObjectFromGUID(sharedSkillAboveZone[skillGUID]).getPosition()[3]-b.getPosition()[3]
					b.setPositionSmooth({turnOrder[nextPlayer].seatPos*40-position[1]+offsetX , 2.0, -39.41+(position[2]*count)+offsetZ})
					keepSafe[b.guid]=true
				end
			end
		end
		getObjectFromGUID(skillGUID).setPositionSmooth({turnOrder[nextPlayer].seatPos*40-position[1] , 1.5, -39.41+(position[2]*count)})
		if roundSkill then
			if gStates.doingTheRoundsVisited==nil then gStates.doingTheRoundsVisited={} end
			if gStates.doingTheRoundsVisited[skillGUID]==nil then gStates.doingTheRoundsVisited[skillGUID]={} end
			gStates.doingTheRoundsVisited[skillGUID][nextPlayer]=true
		end
		count=count+1
	end
	return {keepSafe, count}
end

--Recover a played Interactive skill that Tome moved to the common offer before the normal play-area scan.
--Competitive effects can continue from their remembered activation. Cooperative secondary effects require
--the real token, and Source Freeze explicitly works only while its real token remains in the Source.
function registerDetachedCoopCompSkills(playerIndex)
	local toDeactivate={}
	for skillGUID, record in pairs(coopCompSkillActivationTable()) do
		local details=skillTokens[skillGUID]
		if record.player==playerIndex and record.round==gStates.currentRound and record.location=="pool" and details~=nil and gStates.doingTheRounds[skillGUID]==nil then
			if details.skillType=="Comp" and skillGUID~="3bd08e" then
				gStates.doingTheRounds[skillGUID]=playerIndex
				createCompetitiveSkillReminders(skillGUID, playerIndex)
				record.rotationStarted=true
			else
				toDeactivate[#toDeactivate+1]=skillGUID
			end
		end
	end
	for _, skillGUID in ipairs(toDeactivate) do deactivateCoopCompSkill(skillGUID, true) end
	commitTomeSkillSwap(playerIndex)
end

--drop a shield

function heroChallengeClaimReservedSkill(playerIndex,higherLevel)
	if gStates.heroChallenges~=true or turnOrder[playerIndex]==nil then return false end
	local playerData=turnOrder[playerIndex]
	local challenge=heroChallengesData[playerData.mage]
	if challenge==nil then return false end
	--The prescribed GUID is the source of truth. Reservations are keyed by Mage Knight because turnOrder
	--changes order during the game; an array-index reservation can otherwise point at another Hero's Skill.
	local reserved=(gStates.heroChallengeReservedSkills or {})[playerData.mage]
	local guid=reserved==challenge.skillGUID and reserved or challenge.skillGUID
	local skillDetails=skillTokens[guid]
	if skillDetails==nil or skillDetails.mage~=playerData.mage then
		print("HERO CHALLENGE SKILL ERROR: "..tostring(challenge.skillName).." does not belong to "..tostring(playerData.mage)..".")
		return false
	end
	local skill=getObjectFromGUID(guid)
	if skill==nil then print("HERO CHALLENGE SKILL ERROR: "..tostring(challenge.skillName).." could not be found.") return false end
	local count=0
	local skillX=(playerData.seatPos*40)-107.45
	for _,skillPos in pairs(gStates.mageSkills or {}) do if skillPos[3]<-36.9 and math.abs(skillPos[1]-skillX)<1 then count=count+1 end end
	local target={skillX,1.1,-38.67-(1.48*count)}
	if guid=="f30dd4" then
		local bondsX=unitLayoutNextCommandX(playerData.seatPos)
		target={bondsX,1.1,-31.19}
		scheduleUnitLayoutRefresh(playerData.seatPos)
		if higherLevel==true then
			local unitDeck=getObjectFromGUID(GUID.zone.regularUnit).getObjects()[1]
			for _=1,2 do
				standardDeckCycleShuffleIfReached("Regular Unit",unitDeck)
				unitDeck=getObjectFromGUID(GUID.zone.regularUnit).getObjects()[1]
				unitDeck.takeObject({position={(playerData.seatPos*40)-101,3.0,-48.4},smooth=true,rotation={0,180,0}})
			end
			gStates.bondsOfLoyalty[playerIndex]=5
			UI.setAttribute("Mage"..playerData.seatPos.."influenceTotalText","Text",joinLang({"{en}Influence to Spend : {ru}Доступно влияния: {zh-tw}可花費影響力：{zh-cn}影响力额度：{ko}주어진 영향력: {es}Influencia para Gastar : {fr}Influence à Dépenser : {pt-br}Influência para Gastar : {de}Einfluss zum Ausgeben : ",(playerData.influence*playerData.level)+gStates.bondsOfLoyalty[playerIndex]}))
		else
			addRegularUnitsToOffer(2)
		end
	end
	gStates.mageSkills[guid]=target
	skill.unlock()
	skill.setPositionSmooth(target)
	skill.UI.setXmlTable({{}})
	if gStates.motivationSkill[guid]~=nil then gStates.motivationSkill[guid].state="active" gStates.motivationSkill[guid].pos=playerData.seatPos end
	broadcastToAll(joinLang({translateWord[playerData.mage] or playerData.mage, "{en} gained {ru} получил навык {zh-tw}獲得了{zh-cn}获得了{ko}이(가) {es} obtuvo {fr} a obtenu {pt-br} obteve {de} erhielt ", translateWord[challenge.skillName] or challenge.skillName, "{en} from Hero Challenges.{ru} благодаря Испытаниям героев.{zh-tw}（英雄挑戰）。{zh-cn}（英雄挑战）。{ko} 스킬을 영웅 도전으로 획득했습니다.{es} de Desafíos de Héroe.{fr} grâce aux Défis de Héros.{pt-br} dos Desafios de Herói.{de} aus den Heldenherausforderungen."}),positionToColor(playerIndex))
	return true
end

--perform Level Up
function levelUp(playerTurnSequence)
	if turnOrder[playerTurnSequence].levelUp>0 then
		--The prescribed level-2 Hero Challenge Skill is automatic, so it does not need the normal
		--end-turn "Gained a New Skill Token" reminder. Reset this for every live level-up sequence;
		--a later normal Skill level in the same sequence turns the reminder back on.
		turnOrder[playerTurnSequence].skipHeroChallengeSkillReminder=false
		local multiSkill=false
		local loops=turnOrder[playerTurnSequence].levelUp
		for a=1, loops, 1 do
			if ((turnOrder[playerTurnSequence].level)+1)%2==0 then --Skill and Advanced Action Level Up
				local nextLevel=turnOrder[playerTurnSequence].level+1
				if gStates.heroChallenges==true and nextLevel==2 and heroChallengesData[turnOrder[playerTurnSequence].mage]~=nil then
					if heroChallengeClaimReservedSkill(playerTurnSequence,false)==true then
						turnOrder[playerTurnSequence].skipHeroChallengeSkillReminder=true
					end
					broadcastToAll(joinLang({translateWord[turnOrder[playerTurnSequence].mage] or turnOrder[playerTurnSequence].mage, "{en} may gain any one Advanced Action card.{ru} может получить любую одну карту Особого действия.{zh-tw}可以獲得任意一張高級行動卡。{zh-cn}可以获得任意一张高级行动卡。{ko}은(는) 원하는 고급 액션 카드 한 장을 얻을 수 있습니다.{es} puede obtener cualquier carta de Acción Avanzada.{fr} peut gagner n'importe quelle carte d'Action Avancée.{pt-br} pode ganhar qualquer carta de Ação Avançada.{de} darf eine beliebige Erweiterte Aktionskarte erhalten."}),positionToColor(playerTurnSequence))
				elseif multiSkill==false then
					--This is a normal Skill choice, so keep the standard reminder even if level 2 was also
					--crossed earlier in an unusual multi-level jump.
					turnOrder[playerTurnSequence].skipHeroChallengeSkillReminder=false
					--draw two skills to communal
					local exist=0
					local drawnSkillGUIDs={}
					for skillGUID, skillPos in pairs(gStates.mageSkills) do
						if math.floor(skillPos[1])==math.floor((turnOrder[playerTurnSequence].seatPos*3.7)+7.3) then exist=exist+1 end
					end
					for b=0, 1, 1 do
						local pos={(turnOrder[playerTurnSequence].seatPos*3.7)+7.3, 2.00, -23.95+(b*1.35)+(exist*1.35)}
						local skillDrawn=nil
						local usedFallback=false
						if getObjectFromGUID(turnOrder[playerTurnSequence].skillBagGUID).getQuantity()>=1 then
							skillDrawn=getObjectFromGUID(turnOrder[playerTurnSequence].skillBagGUID).takeObject({position=pos, smooth=true, rotation={0, 180, 0}})
						else
							skillDrawn=getObjectFromGUID("70c31f").clone({position=pos, rotation={0, 180, 0}})
							usedFallback=true
						end
						if skillDrawn~=nil then
							gStates.mageSkills[skillDrawn.guid]=pos
							drawnSkillGUIDs[#drawnSkillGUIDs+1]=skillDrawn.guid
						end
						if usedFallback==true then break end
					end
					--activate claim buttons only after every newly dealt Skill has actually settled.
					gStates.skillButtons=turnOrder[playerTurnSequence].seatPos
					safeWaitCondition("PlayerBoard.Skills",function()
						for _, guid in ipairs(drawnSkillGUIDs) do local skill=getObjectFromGUID(guid) if skill~=nil then skill.unlock() end end
						skillButtonActivate()
					end, function()
						if #drawnSkillGUIDs==0 then return true end
						for _, guid in ipairs(drawnSkillGUIDs) do local skill=getObjectFromGUID(guid) if skill==nil or skill.resting~=true then return false end end
						return true
					end, 10, function() skillButtonActivate() end)
					--Highlight reminder starts from the same synchronized skillButtonActivate refresh.
					--Look at skill Area
					broadcastToAll(joinLang({translateWord[turnOrder[playerTurnSequence].mage], "{en} needs to gain a new Skill and Advanced Action card.{ru} должен получить новый Навык и карту Особых действий.{zh-tw}需要獲得一個新技能和一張高級行動卡。{zh-cn}需要获得新技能和高级行动卡{ko}: 스킬과 상급 액션을 선택하세요.{es} necesita obtener una nueva tarjeta de Habilidad y Acción Avanzada.{fr} doit gagner une nouvelle carte de compétence et d'action avancée.{pt-br} precisa ganhar uma nova Carta de ação e Habilidade.{de} muss eine neue Fertigkeit und eine erweiterte Aktionskarte erhalten."}), positionToColor(playerTurnSequence))
					multiSkill=true
				else
					break
				end
			else --odd number levels
				--Command Token Deploy. Bonus Command sources can already occupy the printed row, so use the shared elastic layout.
				local commandSeat=turnOrder[playerTurnSequence].seatPos
				local xPlayLocation=unitLayoutNextCommandX(commandSeat)
				getObjectFromGUID(turnOrder[playerTurnSequence].commandGUID).takeObject({position={xPlayLocation,2.00,-31.2}, rotation={0,180,180}})
				scheduleUnitLayoutRefresh(commandSeat)
				broadcastToAll(joinLang({translateWord[turnOrder[playerTurnSequence].mage], "{en} gained a new Command token.{ru} получает новый Жетон командования.{zh-tw}獲得一個新的指揮標記。{zh-cn}增加一个新的部队控制标记{ko}: 새 지휘 토큰 획득{es} ganó una nueva ficha de Comando.{fr} gagné un nouveau jeton Commandement.{pt-br} ganhou uma nova FIcha de Comando.{de} hat ein neues Befehlsplättchen erhalten."}), positionToColor(playerTurnSequence))
				--Hand Size Increase
				if (turnOrder[playerTurnSequence].level)+1==5 or (turnOrder[playerTurnSequence].level)+1==9 then
					turnOrder[playerTurnSequence].baseHand=turnOrder[playerTurnSequence].baseHand+1
					turnOrder[playerTurnSequence].hand=turnOrder[playerTurnSequence].hand+1
					broadcastToAll(joinLang({translateWord[turnOrder[playerTurnSequence].mage], "{en}'s hand size increased by one.{ru} имеет увеличенный предел карт на 1.{zh-tw}的手牌上限增加 1。{zh-cn}的手牌上限增加了1{ko}: 카드 보유 제한 1 증가{es}'s tamaño de la mano aumenta en uno.{fr}'s la taille de la main a augmenté de un.{pt-br}'s tamanho de mão aumentado em 1.{de} die Handgröße des Spielers wurde um eins erhöht."}), positionToColor(playerTurnSequence))
				end
			end
			turnOrder[playerTurnSequence].level=turnOrder[playerTurnSequence].level+1
			turnOrder[playerTurnSequence].levelUp=turnOrder[playerTurnSequence].levelUp-1
		end
		if turnOrder[playerTurnSequence].levelUp==0 then levelUpcalled=false end
	end
end

--put skill buttons on skills when appropiate
function skillButtonActivate()
	refreshMageSkillLocations()
	unlockCommonSkillPoolTokens()
	if gStates.skillButtons~=nil and gStates.skillButtons>0 then startRewardSkillChoiceHighlights() end
	safeWaitTime("PlayerBoard.Skills",function()
		--blank existing claim buttons
		for skillGUID, x in pairs(gStates.mageSkills) do
			if getObjectFromGUID(skillGUID)~=nil then getObjectFromGUID(skillGUID).UI.setXmlTable({{}}) end
		end
		if gStates.tacticShown==false and gStates.tacticRemove==false then
			--Work out which skills exist where.
			local skillSort={currentPlayer={}}
			if gStates.skillButtons>0 then
				for skillGUID, skillPos in pairs(gStates.mageSkills) do
					if skillPos[3]>-30 then
						local skillColumn=math.ceil((skillPos[1]-12.85)/3.7)
						local skillRow=math.ceil((skillPos[3]+24.625)/1.35)
						if gStates.skillButtons~=skillColumn+1 then
							skillSort[(skillColumn*8)+skillRow]=skillGUID
						else
							skillSort.currentPlayer[#skillSort.currentPlayer+1]={skillGUID, skillPos[3], (skillColumn*8)+skillRow}
						end
					end
				end
			end
			--Add claim buttons for skills that are legal
			table.sort(skillSort.currentPlayer, function (k1, k2) return k1[2] > k2[2] end)
			for buttonNumber=1, 32, 1 do
				if gStates.skillButtons>0 then
					if math.ceil(buttonNumber/8)~=gStates.skillButtons then
						if gStates.heroChallenges~=true and skillSort[buttonNumber]~=nil then
							local skill=getObjectFromGUID(skillSort[buttonNumber])
							if skill~=nil then skill.UI.setXmlTable({createClaimButton(skillSort[buttonNumber], tostring(buttonNumber))}) end
						end
					else
						if skillSort.currentPlayer[1]~=nil and buttonNumber==skillSort.currentPlayer[1][3] then
							local skill=getObjectFromGUID(skillSort.currentPlayer[1][1])
							if skill~=nil then skill.UI.setXmlTable({createClaimButton(skillSort.currentPlayer[1][1], tostring(buttonNumber))}) end
						end
						if skillSort.currentPlayer[2]~=nil and buttonNumber==skillSort.currentPlayer[2][3] and turnOrder[gStates.turnNumber].level<=10 then
							local skill=getObjectFromGUID(skillSort.currentPlayer[2][1])
							if skill~=nil then skill.UI.setXmlTable({createClaimButton(skillSort.currentPlayer[2][1], tostring(buttonNumber))}) end
						end
					end
				end
			end
		end
	end, 0.5)
end

--Players may leave the game between turns. Pending dropouts can still be undone until normal turn order advances.

function masterOfChaosSetup(position)
	masterOfChaosPause=true
	for a=1, #turnOrder, 1 do
		if turnOrder[a].seatPos==position then
			turnOrder[a].masterOfChaos="first played"
			break
		end
	end
	safeWaitFrames("PlayerBoard.Skills",function() masterOfChaosPause=false end, 80)
	safeWaitFrames("PlayerBoard.Skills",function() safeWaitCondition("PlayerBoard.Skills",function()
		gStates.masterOfChaos=math.random(1,6)
		getObjectFromGUID("1ff34f").setCustomObject({image=masterOfChaosData[gStates.masterOfChaos].image})
		getObjectFromGUID("1ff34f").setDescription(masterOfChaosData[gStates.masterOfChaos].description)
		getObjectFromGUID("1ff34f").reload()
		broadcastToAll("{en}'Master of Chaos' start Randomly picked.{ru}Старт «Мастер магии Хаоса» выбирается случайным образом.{zh-tw}「混亂大師」的起始位置已隨機選擇。{zh-cn}“混乱大师”开始随机挑选{ko}스킬 '혼돈의 달인'의 첫 칸이 무작위로 결정되었습니다.{es}Inicio de 'Master of Chaos' Elegido al azar.{fr}Début de 'Master of Chaos' Choisi au hasard.{pt-br}Início de 'Mestre do Caos' é aleatóriamente escolhido.{de}Meister des Chaos' startet Zufällig gewählt.", {1,1,0.5})
	end, function() return getObjectFromGUID("1ff34f").resting end) end, 5)
end

--masterOfChaos
function masterOfChaos(player, mouseButton, id)
	if mouseButton=="-1" then
		if legalPlayerCheck(player.color, tonumber(id:sub(14, 14)))==true then
			for a=1, #turnOrder, 1 do
				if turnOrder[a].seatPos==tonumber(id:sub(14, 14)) then
					broadcastToAll(joinLang({translateWord[turnOrder[a].mage], "{en} incremented 'Master of Chaos' skill.{ru} передвигает навык «Мастер магии Хаоса».{zh-tw}推進了「混亂大師」技能。{zh-cn}增加了混乱大师技能{ko}: '혼돈의 달인' 스킬 칸 이동{es} se incrementó la habilidad de 'Maestro del Caos'.{fr} compétence 'Maître du Chaos' incrémentée.{pt-br} incrementou a Habilidade 'Mestre do Caos'{de} hat die Fertigkeit 'Meister des Chaos' erhöht."}), positionToColor(a))
					--change skill to next image
					gStates.masterOfChaos=gStates.masterOfChaos+1
					if gStates.masterOfChaos==7 then gStates.masterOfChaos=1 end
					getObjectFromGUID("1ff34f").setCustomObject({image=masterOfChaosData[gStates.masterOfChaos].image})
					getObjectFromGUID("1ff34f").setDescription(masterOfChaosData[gStates.masterOfChaos].description)
					getObjectFromGUID("1ff34f").reload()
					--only allow once per turn
					turnOrder[a].masterOfChaos="incrementented out of turn"
					mainUIUpdate()
					break
				end
			end
		end
	end
end

--Quick Witted remains Set Aside at the bottom of Coral's physical Deed Deck.
--While another Deed card remains above it, the containing Deck is returned so the draw-choice UI can offer Quick Witted.

-- Coral Tales site shields
function coralTalesSiteShield(siteType)
	local playerDetails=turnOrder[gStates.turnNumber]
	if playerDetails==nil or playerDetails.mage~="Coral" then return end
	local adventureSites={['monster den']=true, ['spawning grounds']=true, maze=true, labyrinth=true, ruin=true, dungeon=true, tomb=true, ziggurat=true, pyramid=true}
	local skillGUID=nil
	if adventureSites[siteType]==true then skillGUID="9cf272"--Tales of Adventure
	elseif siteType=="keep" or siteType=="mage tower" then skillGUID="de5b04" end--Tales of Conquest
	if skillGUID==nil then return end
	local skill=getObjectFromGUID(skillGUID)
	local recordedPos=gStates.mageSkills~=nil and gStates.mageSkills[skillGUID] or nil
	if skill==nil or recordedPos==nil then return end
	--Claimed skills live in the owner's skill column; communal/pool skills are recorded elsewhere.
	local claimedX=(playerDetails.seatPos*40)-107.45
	if math.abs(recordedPos[1]-claimedX)>2 or recordedPos[3]>-35 then return end
	local shieldContainer=nil
	for _, details in pairs(mageKnights) do if details.mage=="Coral" then shieldContainer=getObjectFromGUID(details.shieldContainer) break end end
	if shieldContainer==nil then return end
	local location=skill.getPosition()
	local snapPoints=skill.getSnapPoints()
	if snapPoints~=nil and snapPoints[1]~=nil then location=skill.positionToWorld(snapPoints[1].position) end
	--Drop above the snap point so the first shield snaps to the skill and later shields can stack naturally.
	location={location[1], skill.getPosition()[2]+2.5, location[3]}
	shieldContainer.takeObject({position=location, rotation={0, skill.getRotation()[2], 0}, smooth=false})
end

--Claim the Skill reserved by Hero Challenges. higherLevel=true mirrors the Start-at-Higher-Level
--Bonds of Loyalty setup rather than adding cards to the live Unit Offer.

-- Motivation skill runtime
function motivation(player, mouseButton, id)
	if mouseButton=="-1" then
		if legalPlayerCheck(player.color, tonumber(id:sub(18, 18)))==true then
			for a=1, #turnOrder, 1 do
				if turnOrder[a].seatPos==tonumber(id:sub(18, 18)) then
					broadcastToAll(joinLang({translateWord[turnOrder[a].mage], "{en} used a Motivation skill.{ru} использует навык Мотивация.{zh-tw}使用了激励技能{zh-cn}使用了激励技能{ko}: 스킬 '동기 부여' 사용{es} usó una habilidad de Motivación.{fr} utilisé une compétence de Motivation.{pt-br} usou uma Habilidade de Motivação{de} eine Motivationsfertigkeit eingesetzt."}), positionToColor(a))
					--One exact two-card request keeps the whole Motivation draw inside one Quick Witted choice flow.
					drawExactDeedCards(a, 2, "DrawOne")
					--Gain Fame or mana token
					local lowestFame=1
					for b=2, #turnOrder, 1 do
						if turnOrder[b].mage~=gStates.positionMageKnight[5] then
							if turnOrder[b].fame<turnOrder[lowestFame].fame or turnOrder[lowestFame].mage==gStates.positionMageKnight[5] then lowestFame=b end
						end
					end
					for b=1, #turnOrder, 1 do if turnOrder[b].fame==turnOrder[lowestFame].fame and b~=lowestFame then lowestFame=0 break end end--find ties
					if lowestFame~=0 and turnOrder[lowestFame].seatPos==tonumber(id:sub(18, 18)) then
						local params={position={(gStates.motivationSkill[id:sub(1, 6)].pos*40)-101, 1.65, -39}, rotation={0, 0, 0}, smooth=false}
						if gStates.motivationSkill[id:sub(1, 6)].bonus:sub(11, 13)=="Red" then
							takeManaCrystal(getObjectFromGUID(GUID.bag.mana.red),params)
							broadcastToAll("{en}Also gained a Red Mana Token.{ru}Также получает Красный жетон маны.{zh-tw}同时增加了一个红色魔晶{zh-cn}同时增加了一个红色魔晶{ko}빨간색 마나 추가 획득.{es}También ganó una ficha de Maná Roja.{fr}A également gagné un jeton de Mana Rouge.{pt-br}Também ganhou um Marcador de Mana Vermelha.{de}Außerdem erhielt er ein rotes Mana-Plättchen.", positionToColor(a))
						end
						if gStates.motivationSkill[id:sub(1, 6)].bonus:sub(11, 14)=="Blue" then
							takeManaCrystal(getObjectFromGUID(GUID.bag.mana.blue),params)
							broadcastToAll("{en}Also gained a Blue Mana Token.{ru}Также получает Синий жетон маны.{zh-tw}同时增加了一个蓝色魔晶{zh-cn}同时增加了一个蓝色魔晶{ko}파란색 마나 추가 획득.{es}También ganó una ficha de Maná Azul.{fr}A également gagné un jeton de Mana Bleu.{pt-br}Também ganhou um Marcador de Mana Azul.{de}Außerdem ein blaues Mana-Plättchen erhalten.", positionToColor(a))
						end
						if gStates.motivationSkill[id:sub(1, 6)].bonus:sub(11, 15)=="White" then
							takeManaCrystal(getObjectFromGUID(GUID.bag.mana.white),params)
							broadcastToAll("{en}Also gained a White Mana Token.{ru}Также получает Белый жетон маны.{zh-tw}同时增加了一个白色魔晶{zh-cn}同时增加了一个白色魔晶{ko}흰색 마나 추가 획득.{es}También ganó una ficha de Maná Blanca.{fr}A également gagné un jeton de Mana Blanc.{pt-br}Também ganhou um Marcador de Mana Branca.{de}Außerdem erhielt er ein weißes Mana-Plättchen.", positionToColor(a))
						end
						if gStates.motivationSkill[id:sub(1, 6)].bonus:sub(11, 15)=="Green" then
							takeManaCrystal(getObjectFromGUID(GUID.bag.mana.green),params)
							broadcastToAll("{en}Also gained a Green Mana Token.{ru}Также получает Зеленый жетон маны.{zh-tw}同时增加了一个绿色魔晶{zh-cn}同时增加了一个绿色魔晶{ko}녹색 마나 추가 획득.{es}También ganó una ficha de Maná Verde.{fr}A également gagné un jeton de Mana Vert.{pt-br}Também ganhou um Marcador de Mana Verde.{de}Hat auch ein grünes Mana-Plättchen erhalten.", positionToColor(a))
						end
						if gStates.motivationSkill[id:sub(1, 6)].bonus:sub(11, 14)=="Fame" then
							local startingFameToLevel=math.floor(math.sqrt((turnOrder[a].fame-(gStates.scoreIfLooped*turnOrder[a].scoreLoop))+1))
							local newFame=turnOrder[a].fame+1-(gStates.scoreIfLooped*turnOrder[a].scoreLoop)
							local scoreLooped=false
							if newFame>=gStates.scoreIfLooped then newFame=newFame-gStates.scoreIfLooped scoreLooped=true end
							local fameToLevel=math.floor(math.sqrt(newFame+1))
							local startPosition=(newFame-(fameToLevel*fameToLevel))+2
							if scoreLooped==false then startPosition=startPosition+((fameToLevel-startingFameToLevel)*gStates.blitz) end
							local levelRowFameQuantity=(((fameToLevel-1)*cellGainPerLevel)+normalCellAmount)
							local levelRowLength=((fameToLevel-1)*gStates.rowLengthGainPerLevel)+gStates.normalRowLength
							local xOffset=(1/levelRowFameQuantity*levelRowLength)/2
							local yOffset=(heightOfFameBoard/gStates.rowsOnBoard)/2
							local horizontalValue=leftOfFameBoard+(startPosition/levelRowFameQuantity*levelRowLength)-xOffset
							local verticalValue=(topOfFameBoard-((fameToLevel/gStates.rowsOnBoard)*heightOfFameBoard))+yOffset-0.25
							getObjectFromGUID(turnOrder[a].fameGUID).setPosition({horizontalValue, 1.5, verticalValue+((turnOrder[a].seatPos-2.5)/5)})
							recordPlayerFameChange(a, 1)
							broadcastToAll("{en}and gained a Fame also{ru}и получает Славу{zh-tw}也增加了1名望{zh-cn}也增加了1名望{ko}명성 1 추가 획득.{es}y ganó Fama también{fr}et a également gagné une renommée{pt-br}e também ganhou uma Fama.{de}und auch einen Ruhmespunkt gewonnen", positionToColor(a))
						end
					end
					--flip skill down.
					getObjectFromGUID(id:sub(1, 6)).setRotationSmooth({0, 180, 180})
					getObjectFromGUID(id:sub(1, 6)).setPositionSmooth({gStates.mageSkills[id:sub(1, 6)][1], 1.5, gStates.mageSkills[id:sub(1, 6)][3]})
					--only allow once per round
					gStates.motivationSkill[id:sub(1, 6)].state="used"
					mainUIUpdate("Motivation Skill activated")
					break
				end
			end
		end
	end
end

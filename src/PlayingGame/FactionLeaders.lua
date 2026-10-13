-- Dark Crusader and Elementalist: Faction Leader deployment, levels, combat and scoring.
-- City owns shared garrisons and Combat owns generic turn cleanup.


local function ultimateConquestLeaderLevel(cityCount)
	if cityCount>0 and gStates.cityLevels[cityCount]~=nil then return gStates.cityLevels[cityCount] end
	local lowest=nil
	for cityIndex=1, gStates.cityTiles do
		local cityLevel=gStates.cityLevels[cityIndex]
		if cityLevel~=nil and (lowest==nil or cityLevel<lowest) then lowest=cityLevel end
	end
	return lowest or 1
end


function factionLeaderForCity(cityGUID)
	if cityGUID==elementalist.terrainHex then return elementalist end
	if cityGUID==darkCrusader.terrainHex then return darkCrusader end
	return nil
end

function setFactionLeaderLevel(cityGUID, level)
	local currentLeader=factionLeaderForCity(cityGUID)
	local levelData=currentLeader~=nil and leaderData[currentLeader.terrainHex] or nil
	level=math.min(tonumber(level) or 1, 12)
	if currentLeader==nil or levelData==nil or levelData[level]==nil then return false end
	local disc=getObjectFromGUID(currentLeader.disc)
	local token=getObjectFromGUID(currentLeader.token)
	if disc~=nil then disc.setCustomObject({image=levelData[level].discImg}) disc.reload() end
	if token~=nil then
		token.setCustomObject({image=levelData[level].tokenImg})
		token.setName((currentLeader==elementalist and "Elementalist" or "Dark Crusader").." Leader Level "..level)
		token.reload()
	end
	monsterPugs[currentLeader.token]=levelData[level].abilities
	if currentLeader==elementalist then gStates.elementalistLevel=level else gStates.darkCrusaderLevel=level end
	if gStates.cityMonsterQty[cityGUID]~=nil then gStates.cityMonsterQty[cityGUID][currentLeader.token]="alive" end
	return true
end


function factionLeaderForToken(guid)
	if guid==elementalist.token then return elementalist end
	if guid==darkCrusader.token then return darkCrusader end
	return nil
end

-- The followers can remain on the table briefly after a faction leader reaches level zero.
function factionLeaderTargetDefeated(cityGUID)
	if cityTargetDefeated(cityGUID)==true then return true end
	local leader=factionLeaderForCity(cityGUID)
	if leader==nil then return false end
	local level=leader==darkCrusader and gStates.darkCrusaderLevel or gStates.elementalistLevel
	return (level or 1)<=0 or (gStates.cityMonsterQty[cityGUID]~=nil and gStates.cityMonsterQty[cityGUID][leader.token]=="dead")
end


local function factionLeaderDeployOrder(cityGUID, ultimateCitiesPlayed, leaderLevel)
	if gStates.cityDeployOrder[cityGUID]~=nil then return gStates.cityDeployOrder[cityGUID], gStates.cityLevels[gStates.cityDeployOrder[cityGUID]] end
	local leaderOrder=#gStates.citiesPlayed-(gStates.megapolisPlayed or 0)
	if gStates.gameScenario=="Ultimate Conquest" then leaderOrder=#gStates.cityLevels+1 gStates.cityLevels[leaderOrder]=leaderLevel end
	gStates.cityDeployOrder[cityGUID]=leaderOrder
	return leaderOrder, leaderLevel
end


-- The leader sets its level and map identity; City then deploys the ordinary garrison.
function factionLeaderDeploy(cityGUID,ultimateCitiesPlayed,obj)
	local leader=factionLeaderForCity(cityGUID)
	if leader==nil then return nil end
	local leaderLevel=gStates.cityLevels[#gStates.citiesPlayed-(gStates.megapolisPlayed or 0)-math.ceil((gStates.megapolisPlayed or 0)/2)]
	if gStates.gameScenario=="Ultimate Conquest" then leaderLevel=ultimateConquestLeaderLevel(ultimateCitiesPlayed) end
	if gStates.gameScenario=="The War of Four" then
		leaderLevel=999
		for _, level in pairs(gStates.cityLevels) do if level<leaderLevel then leaderLevel=level end end
	end
	local order
	order, leaderLevel=factionLeaderDeployOrder(cityGUID, ultimateCitiesPlayed, leaderLevel)
	leaderLevel=math.min(tonumber(leaderLevel) or 1,12)
	gStates.cityLevels[order]=leaderLevel
	setFactionLeaderLevel(cityGUID,leaderLevel)
	if leader==elementalist then
		runtimeMapSetHexFeature(obj.guid,"center","hidden valley")
		gStates.hexOverideSave[obj.guid].center="hidden valley"
		gStates.monsterPlayLocation[elementalist.token]={-55.3,1.5,15.3}
	else
		runtimeMapSetHexFeature(obj.guid,"center","necropolis")
		gStates.hexOverideSave[obj.guid].center="necropolis"
		gStates.monsterPlayLocation[darkCrusader.token]={-55.3,1.5,6.7}
	end
	return leaderLevel
end


function factionLeaderSortShields(objectsOnCity,zoneObj)
	local tilePos=zoneObj.getPosition()
	table.sort(objectsOnCity, function(k1, k2)
		local rot=math.rad(90)
		local p1=k1.getPosition()
		local p2=k2.getPosition()
		local var1=math.atan2(((p1[3]-tilePos[3])*math.cos(rot))+((p1[1]-tilePos[1])*math.sin(rot)), ((p1[1]-tilePos[1])*math.cos(rot))-((p1[3]-tilePos[3])*math.sin(rot)))
		local var2=math.atan2(((p2[3]-tilePos[3])*math.cos(rot))+((p2[1]-tilePos[1])*math.sin(rot)), ((p2[1]-tilePos[1])*math.cos(rot))-((p2[3]-tilePos[3])*math.sin(rot)))
		return var1<var2
	end)
end


function factionLeaderAddTerrainContributions(cityZone,cityScoring)
	if (cityZone==darkCrusader.discZone or cityZone==elementalist.discZone) and (gStates.coop==0 or gStates.WarOfFourComp==true) then
		for c=1, #turnOrder, 1 do
			if turnOrder[c].mage~=gStates.positionMageKnight[5] then
				if cityScoring[turnOrder[c].mage]==nil then cityScoring[turnOrder[c].mage]=0 end
				if cityZone==elementalist.discZone then cityScoring[turnOrder[c].mage]=cityScoring[turnOrder[c].mage]+turnOrder[c].score.Glade end
				if cityZone==darkCrusader.discZone then cityScoring[turnOrder[c].mage]=cityScoring[turnOrder[c].mage]+turnOrder[c].score.GraveYard end
			end
		end
	end

end


function factionLeaderScoreZone(cityZone,cityScoring,factionAssistTest)
	if cityZone==darkCrusader.discZone or cityZone==elementalist.discZone then
		local factionBothAssistTest={}
		local highest={0, nil}
		for mage, value in pairs(cityScoring) do
			if value>0 then
				for c=1, #turnOrder, 1 do
					if turnOrder[c].mage==mage then
						if cityZone==elementalist.discZone then turnOrder[c].score.ElemFactionAssist=turnOrder[c].score.ElemFactionAssist+1 end
						if cityZone==darkCrusader.discZone then turnOrder[c].score.DarkFactionAssist=turnOrder[c].score.DarkFactionAssist+1 end
						if highest[1]<value then highest[1]=value highest[2]=mage end
						factionAssistTest[turnOrder[c].mage]=true
						factionBothAssistTest[turnOrder[c].mage]=true
						break
					end
				end
			end
		end
		for c=1, #turnOrder, 1 do
			if turnOrder[c].mage==highest[2] then
				if cityZone==darkCrusader.discZone then
					turnOrder[c].score.DarkFactionAssist=turnOrder[c].score.DarkFactionAssist-1
					turnOrder[c].score.DarkFactionLead=turnOrder[c].score.DarkFactionLead+1
				end
				if cityZone==elementalist.discZone then
					turnOrder[c].score.ElemFactionAssist=turnOrder[c].score.ElemFactionAssist-1
					turnOrder[c].score.ElemFactionLead=turnOrder[c].score.ElemFactionLead+1
				end
				break
			end
		end
		local count=0
		for _ in pairs(factionBothAssistTest) do count=count+1 end
		return count==#turnOrder-1
	end
	return false
end

function factionLeaderResetScoring()
	gStates.allPlayersFoughtAFactionLeaderCheck=false
	gStates.allPlayersFoughtBothFactionLeaderCheck=false
end

function factionLeaderFinishScoring(factionAssistTest,bothTest)
	gStates.allPlayersFoughtBothFactionLeaderCheck=bothTest==2
	local count=0
	for _ in pairs(factionAssistTest) do count=count+1 end
	gStates.allPlayersFoughtAFactionLeaderCheck=count==#turnOrder-1
end

function factionLeaderRegisterConquered(cityGUID)
	gStates.defeatedFaction=gStates.defeatedFaction+1
	gStates.defeatedFactionTest[cityGUID]="Beat"
end


--Faction-leader co-op participants get unlocked planning copies. These clones are visual only and are never registered as monsters.
function factionLeaderClearCoopPreview()
	for playerIndex, cloneGUID in pairs(gStates.coopLeaderPreviewClones or {}) do
		local clone=getObjectFromGUID(cloneGUID)
		if clone~=nil then clone.destruct() end
	end
	gStates.coopLeaderPreviewClones={}
end


function factionLeaderCreateCoopPreview()
	factionLeaderClearCoopPreview()
	if gStates.coopAssaultPhase~="combat" or coopAssaultTargetType()~="leader" then return end
	local leaderGUID=elementalist.token
	if gStates.coopAssaultCityGUID==darkCrusader.terrainHex then leaderGUID=darkCrusader.token end
	local leaderObj=getObjectFromGUID(leaderGUID)
	if leaderObj==nil then return end
	for playerIndex, _ in pairs(gStates.coopAssaultParticipants or {}) do
		if playerIndex~=gStates.turnNumber and turnOrder[playerIndex]~=nil then
			local clone=leaderObj.clone({position={turnOrder[playerIndex].seatPos*40-100, 1.5, -39.41}, rotation={0, 180, 0}, smooth=false})
			if clone~=nil then
				clone.unlock()
				clone.interactable=true
				clone.UI.setXmlTable({{}})
				gStates.coopLeaderPreviewClones[playerIndex]=clone.guid
			end
		end
	end
end

--Replace the next player's movable planning copy with the real leader token and its combat controls.
function factionLeaderPromoteCoopPreview(playerIndex, leaderObj)
	if leaderObj==nil or turnOrder[playerIndex]==nil then return end
	local destination={turnOrder[playerIndex].seatPos*40-100, 1.5, -39.41}
	local cloneGUID=gStates.coopLeaderPreviewClones~=nil and gStates.coopLeaderPreviewClones[playerIndex] or nil
	local clone=cloneGUID~=nil and getObjectFromGUID(cloneGUID) or nil
	if clone~=nil then
		--Respect where the player moved the preview as long as it is still inside that player's combat area.
		local playZone=getObjectFromGUID(playerPlayAreas[turnOrder[playerIndex].seatPos])
		if playZone~=nil then
			for _, obj in pairs(playZone.getObjects()) do
				if obj.guid==clone.guid then
					local clonePos=clone.getPosition()
					destination={clonePos[1], 1.5, clonePos[3]}
					break
				end
			end
		end
		clone.destruct()
	end
	if gStates.coopLeaderPreviewClones~=nil then gStates.coopLeaderPreviewClones[playerIndex]=nil end
	leaderObj.unlock()
	leaderObj.setPositionSmooth(destination,false,false)
	leaderObj.setRotation({0, 180, 0})
	setMonsterObjectButtons(leaderObj)
end


function factionLeaderOverkillButtons(obj)
	if obj==nil or factionLeaderForToken(obj.guid)==nil then return {} end
	local addedButtons={}
		addedButtons[#addedButtons+1]={tag="Button", attributes={id=obj.guid.."OverkillUp", onMouseDown="global/buttonClicked", onMouseUp="global/buttonClicked", onClick="global/adjustOverkill", height=50/0.9, width=50/0.9,
			color="rgba(0,0,0,0.0)", position="-62 "..tostring(-120/0.9).." "..tostring(-15/0.9), rotation="0 0 180"}, children={{tag="Image", attributes={id=obj.guid.."OverkillUpImage", image="Overkill Up"}}}}
		addedButtons[#addedButtons+1]={tag="Image", attributes={image="Overkill Text", height=50/0.9, width=55/0.9, position="0 "..tostring(-120/0.9).." "..tostring(-15/0.9), rotation="0 0 180"},
			children={{tag="Text", attributes={id=obj.guid.."Overkill", color="rgb(0,0,0)", fontSize="45", fontStyle="Bold", alignment="MiddleCenter", text=gStates.leaderOverkill}}}}
		addedButtons[#addedButtons+1]={tag="Button", attributes={id=obj.guid.."OverkillDown", onMouseDown="global/buttonClicked", onMouseUp="global/buttonClicked", onClick="global/adjustOverkill", height=50/0.9, width=50/0.9,
			color="rgba(0,0,0,0.0)", position="62 "..tostring(-120/0.9).." "..tostring(-15/0.9), rotation="0 0 180"}, children={{tag="Image", attributes={id=obj.guid.."OverkillDownImage", image="Overkill Down"}}}}
	return addedButtons
end


--Object UI is not reliably restored by TTS after load/rewind. Rebuild a faction Leader's
--combat controls when the real Leader token is in either a player's Play Area or Unit Area.
function refreshLeaderOverkillButtons()
	for _, leaderGUID in ipairs({darkCrusader.token, elementalist.token}) do
		local leaderObj=getObjectFromGUID(leaderGUID)
		if leaderObj~=nil and objectInPlayerCombatArea(leaderGUID)==true then setMonsterObjectButtons(leaderObj) end
	end
end


--Leader overkill adjust
adjustOverkill=function(player, mouseButton, id)
	if mouseButton=="-1" then
		local level=gStates.elementalistLevel-gStates.leaderReduction
		if id:sub(1,6)==darkCrusader.token then level=gStates.darkCrusaderLevel-gStates.leaderReduction end
		if id:sub(7,16)=="OverkillUp" and gStates.leaderOverkill<level then
			gStates.leaderOverkill=gStates.leaderOverkill+1
		end
		if id:sub(7,18)=="OverkillDown" and gStates.leaderOverkill>1 then
			gStates.leaderOverkill=gStates.leaderOverkill-1
		end
		local leaderObj=getObjectFromGUID(id:sub(1,6))
		if leaderObj~=nil then leaderObj.UI.setAttribute(id:sub(1,14),"Text",gStates.leaderOverkill) end
		mainUIUpdate("Leader Overkilled")
	end
end


-- Solo and cooperative damage use the same visual and ability level transition.
local function factionLeaderApplyCombatLevel(leader,level)
	local art=leaderData[leader.terrainHex]~=nil and leaderData[leader.terrainHex][level] or nil
	if art==nil then return end
	local token=getObjectFromGUID(leader.token)
	if token~=nil then
		token.setCustomObject({image=art.tokenImg})
		token.setName(joinLang({leader==darkCrusader and "{en}Dark Crusader Leader Level {it}Capo dei Crociati Oscuri, Livello {ru}Уровень лидера Тёмных крестоносцев: {zh-tw}黑暗十字軍領袖等級 {zh-cn}黑暗十字军领袖等级 {ko}다크 크루세이더 지도자 레벨 {es}Nivel del líder Cruzado Oscuro {fr}Niveau du chef Croisé Sombre {pt-br}Nível do líder Cruzado Sombrio {de}Stufe des Anführers der Dunklen Kreuzritter " or "{en}Elementalist Leader Level {it}Capo degli Elementalisti, Livello {ru}Уровень лидера Элементалистов: {zh-tw}元素使領袖等級 {zh-cn}元素使领袖等级 {ko}엘리멘탈리스트 지도자 레벨 {es}Nivel del líder Elementalista {fr}Niveau du chef Élémentaliste {pt-br}Nível do líder Elementalista {de}Stufe des Elementalisten-Anführers ", level}))
		token.reload()
	end
	monsterPugs[leader.token]=art.abilities
	local disc=getObjectFromGUID(leader.disc)
	if disc~=nil then disc.setCustomObject({image=art.discImg}) disc.reload() end
end

local function factionLeaderDiscardFollowers(leader,discardMonster,context)
	local roster=gStates.cityMonsterQty[leader.terrainHex]
	if roster==nil then return end
	for monsterGUID,state in pairs(roster) do
		if monsterGUID~="extra" and monsterGUID~=leader.token and state~="dead" then
			local monster=getObjectFromGUID(monsterGUID)
			if monster~=nil and monster.getRotationValues()[2]~=nil then discardMonster(monster,false,context) end
		end
	end
end

local function factionLeaderCombatDefeated(leader,discardMonster,context,deferFollowers)
	local token=getObjectFromGUID(leader.token)
	local trash=getObjectFromGUID(trashCan)
	if token~=nil and trash~=nil then trash.putObject(token) end
	local roster=gStates.cityMonsterQty[leader.terrainHex]
	if roster~=nil then roster[leader.token]="dead" end
	local disc=getObjectFromGUID(leader.disc)
	local deadArt=leaderData[leader.terrainHex]~=nil and leaderData[leader.terrainHex]["dead"] or nil
	if disc~=nil and deadArt~=nil then disc.setCustomObject({image=deadArt.discImg}) disc.reload() end
	if deferFollowers then
		safeWaitTime("FactionLeaders",function() factionLeaderDiscardFollowers(leader,discardMonster,context) end,2)
	else
		factionLeaderDiscardFollowers(leader,discardMonster,context)
	end
end

-- A face-down Leader took no damage: pass the real token on without changing its level.
function factionLeaderReturnUnbeatenCoopToken(token)
	if coopAssaultPendingCombat()==true then
		factionLeaderPromoteCoopPreview(nextTurnMerged("nextMage"),token)
	else
		factionLeaderClearCoopPreview()
		token.setRotation({0,180,0})
		local position=gStates.monsterPlayLocation[token.guid]
		if position~=nil then token.setPositionSmooth(position,false,false) end
	end
end

-- A face-up Leader is handled here, rather than by standard enemy token discard logic.
function factionLeaderResolveCombatToken(token,playerIndex,cleanupContext,discardMonster)
	local leader=factionLeaderForToken(token.guid)
	if leader==nil then return end
	local startingLevel=leader==darkCrusader and gStates.darkCrusaderLevel or gStates.elementalistLevel
	local reduction=gStates.leaderReduction or 0
	local overkill=gStates.leaderOverkill or 1
	local disc=getObjectFromGUID(leader.disc)
	if disc~=nil then
		local position=disc.getPosition()
		for count=1,overkill do
			local angle=math.rad(120-30*(startingLevel-reduction-(count-1)))
			dropShield({position[1]+math.cos(angle)*2.9,2+count*1.5,position[3]+math.sin(angle)*2.9},false,nil,playerIndex)
		end
	end
	gStates.leaderReduction=reduction+overkill
	local beaten=gStates.leaderReduction>=startingLevel
	gStates.leaderOverkill=1
	if gStates.coopAssaultPhase=="combat" and coopAssaultTargetType()=="leader" then
		-- Co-op participants register damage without changing the shared level until combat is complete.
		if coopAssaultPendingCombat()==true and beaten==false then
			factionLeaderPromoteCoopPreview(nextTurnMerged("nextMage"),token)
		else
			factionLeaderClearCoopPreview()
			local position=gStates.monsterPlayLocation[token.guid]
			if position~=nil then token.setPositionSmooth(position,false,false) end
		end
		return
	end
	local remaining=math.max(0,startingLevel-gStates.leaderReduction)
	if leader==darkCrusader then gStates.darkCrusaderLevel=remaining else gStates.elementalistLevel=remaining end
	gStates.leaderReduction=0
	if remaining==0 then
		factionLeaderCombatDefeated(leader,discardMonster,cleanupContext,true)
	else
		local position=gStates.monsterPlayLocation[token.guid]
		if position~=nil then token.setPositionSmooth(position,false,false) end
		safeWaitFrames("FactionLeaders",function() factionLeaderApplyCombatLevel(leader,remaining) end,100)
	end
end

-- Cooperative damage is finalized after every assault participant has fought.
function factionLeaderFinalizeCoopCombat(discardMonster)
	if gStates.coopAssaultPhase~="combat" or coopAssaultTargetType()~="leader" then return end
	factionLeaderClearCoopPreview()
	if (gStates.leaderReduction or 0)<=0 then return end
	local leader=factionLeaderForCity(gStates.coopAssaultCityGUID)
	if leader==nil then return end
	local level=leader==darkCrusader and gStates.darkCrusaderLevel or gStates.elementalistLevel
	if level==nil then gStates.leaderReduction=0 return end
	local remaining=math.max(0,level-gStates.leaderReduction)
	gStates.leaderReduction=0
	if leader==darkCrusader then gStates.darkCrusaderLevel=remaining else gStates.elementalistLevel=remaining end
	if remaining==0 then
		factionLeaderCombatDefeated(leader,discardMonster,{player=gStates.turnNumber,avatarPos=mageKnightAvatarPosition(gStates.turnNumber) or {}},false)
	else
		local token=getObjectFromGUID(leader.token)
		local position=token~=nil and gStates.monsterPlayLocation[token.guid] or nil
		if position~=nil then token.setPositionSmooth(position,false,false) end
		factionLeaderApplyCombatLevel(leader,remaining)
	end
end

publishPublicUICallbacks({adjustOverkill=adjustOverkill})

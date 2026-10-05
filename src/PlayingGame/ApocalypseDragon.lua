-- Apocalypse Dragon-private helpers. Predeclared so forward references keep resolving locally.
local apocalypseDragonHeadTokenPosition, apocalypseDragonPositionHeadToken, apocalypseDragonCopyAttack, apocalypseDragonRefreshRuntimeData
local apocalypseDragonDeployHeadToken, apocalypseDragonLevelMarkerPosition, apocalypseDragonLockLevelMarker, apocalypseDragonDefeatedHeadCount, apocalypseDragonSyncControlLevel
local apocalypseDragonCheckAndResolveDefeat, apocalypseDragonHeadStateChanged, apocalypseDragonGroundReduction, apocalypseDragonGroundControlGUIDs
local apocalypseDragonGroundPrepareColoredHead, apocalypseDragonGroundPrepareControl, apocalypseDragonNewGroundCombat, apocalypseDragonGroundTokenInPlayerArea
local apocalypseDragonCoopAdjacentPlayers, apocalypseDragonGroundApplyFinalLevels, apocalypseDragonGroundCleanupRuntime

-- Shared Apocalypse Dragon entity, head-level and landed-combat helpers.
-- Scenario-specific AI/turn rules remain in Scenario.lua.

function syncDragonHeadAttackBonusDecal(tokenGUID,bonus)
	local token=tokenGUID~=nil and getObjectFromGUID(tokenGUID) or nil
	if token==nil then return false end
	--The head tokens sit at 180 degrees, so positive local X is visually left.
	--Keep the Control bonus centred vertically rather than using the Quest possessed-token offset.
	combatSyncNamedAttackBonusDecal(token,"DragonAllAttack+",bonus,{1.1,0.15,0})
	return true
end

function apocalypseDragonPossessSummonedEnemy(enemyGUID,target)
	local enemy=getObjectFromGUID(enemyGUID)
	if target==nil then
		if enemy==nil then return false end
		local p=enemy.getPosition()
		target={p[1],p[2],p[3]}
	end
	local bag=getObjectFromGUID(GUID.bag.possessed)
	if bag==nil or bag.getQuantity()==0 then
		tokenRefill()
		bag=getObjectFromGUID(GUID.bag.possessed)
	end
	if bag==nil or bag.getQuantity()==0 then return false end
	--Match the working Quest possessed-enemy path: draw both tokens to the same X/Z, with the
	--Possessed token above the enemy. Falling through the player scripting zone performs the link.
	local possessed=bag.takeObject({position={target[1],target[2]+1.10,target[3]},rotation={0,180,0},smooth=true})
	if possessed==nil then return false end
	gStates.apocalypsePossessedFactionByToken=gStates.apocalypsePossessedFactionByToken or {}
	gStates.apocalypsePossessedFactionByToken[possessed.guid]="Apoc"
	--Control-head summons are temporary enemies: neither the summoned monster nor its Possessed
	--token may award Fame or a Faction Reward. Mark the attachment with the same summoned state
	--used by ordinary monster cleanup so every reward path treats both pieces consistently.
	gStates.summonStates=gStates.summonStates or {}
	gStates.summonStates[possessed.guid]="summoned"
	return true
end

function apocalypseDragonScenario()
	return scenarioUsesApocalypseDragon()
end

function apocalypseDragonStartingLevel()
	if apocalypseDragonScenario()~=true then return nil end
	local override=tonumber(gStates.apocalypseDragonStartingLevelOverride)
	if override~=nil and override>=1 and override<=12 then return math.floor(override) end
	if gStates.gameScenario=="Fury of the Apocalypse Dragon" then
		if gStates.playerCount==1 then return 1 end
		return gStates.coop==1 and gStates.playerCount or gStates.playerCount-1
	end
	if gStates.playerCount==1 then
		if gStates.gameScenario=="Against the Dragon Blitz" then return 4 end
		return 5
	end
	if gStates.gameScenario=="Against the Dragon Blitz" then
		return gStates.playerCount+(gStates.coop==1 and 3 or 1)
	end
	return gStates.playerCount+(gStates.coop==1 and 4 or 2)
end

function apocalypseDragonHeadData(headName)
	for _,headData in ipairs(apocalypseDragon.heads) do if headData.name==headName then return headData end end
	return nil
end

function apocalypseDragonCurrentLevelData(headName,level)
	local data=apocalypseDragonLevelData~=nil and apocalypseDragonLevelData[headName] or nil
	level=math.floor(tonumber(level) or 0)
	if data==nil or level<1 or level>12 then return nil end
	return data.levels~=nil and data.levels[level] or nil
end

apocalypseDragonHeadTokenPosition=function(headData)
	if headData==nil or headData.position==nil then return nil end
	return {headData.position[1],headData.position[2]+0.12,headData.position[3]}
end

apocalypseDragonPositionHeadToken=function(headData)
	if headData==nil or headData.tokenGUID==nil then return false end
	local token=getObjectFromGUID(headData.tokenGUID)
	local target=apocalypseDragonHeadTokenPosition(headData)
	if token==nil or target==nil then return false end
	local pos=token.getPosition()
	local moved=math.abs(pos[1]-target[1])>0.03 or math.abs(pos[2]-target[2])>0.03 or math.abs(pos[3]-target[3])>0.03
	token.setLock(false)
	if moved==true then token.setPosition(target) end
	token.setRotation({0,180,0})
	token.setLock(true)
	return moved
end

apocalypseDragonCopyAttack=function(attack,bonus)
	if type(attack)~="table" then return nil end
	local copied={}
	for attackType,values in pairs(attack) do
		if type(values)=="table" then
			copied[attackType]={}
			for _,value in ipairs(values) do copied[attackType][#copied[attackType]+1]=(tonumber(value) or 0)+(bonus or 0) end
		end
	end
	return copied
end

function apocalypseDragonMonsterData(headName,level)
	local levelData=apocalypseDragonCurrentLevelData(headName,level)
	if levelData==nil then return nil end
	local data={name="Apocalypse Dragon - "..headName,pugType="dragonHead",dragonHead=headName,dragonHeadLevel=level}
	for key,value in pairs(levelData) do
		if key~="image" and key~="attackBonus" and key~="possessedSummon" then
			if key=="attack" then data.attack=apocalypseDragonCopyAttack(value,0)
			elseif key=="monsters" then
				data.monsters={}
				for _,monsterColor in ipairs(value) do data.monsters[#data.monsters+1]=monsterColor end
			else data[key]=value end
		end
	end
	return data
end

--Refresh the persistent small head token stats. Printed level data lives in monsterPugs; Control's
--whole-head Attack bonus is a runtime monsterPerks attack override so every displayed attack gets it.
apocalypseDragonRefreshRuntimeData=function()
	if gStates==nil then return end
	local monsterPerks=gStates.monsterPerks
	if monsterPerks==nil then
		monsterPerks={}
		gStates.monsterPerks=monsterPerks
	end
	for _,headData in ipairs(apocalypseDragon.heads) do
		local tokenGUID=headData.tokenGUID
		if tokenGUID~=nil then
			local level=tonumber(gStates.apocalypseDragonHeadLevels~=nil and gStates.apocalypseDragonHeadLevels[headData.name] or 0) or 0
			if level>0 then monsterPugs[tokenGUID]=apocalypseDragonMonsterData(headData.name,level) else monsterPugs[tokenGUID]=nil end
			local perks=monsterPerks[tokenGUID]
			if perks~=nil and perks.dragonControlBonus~=nil then
				perks.attack=nil
				perks.dragonControlBonus=nil
				if next(perks)==nil then monsterPerks[tokenGUID]=nil end
			end
			if headData.name~="Control" then syncDragonHeadAttackBonusDecal(tokenGUID,0) end
		end
	end
	local headLevels=gStates.apocalypseDragonHeadLevels or {}
	local controlLevel=tonumber(headLevels.Control) or 0
	local controlData=apocalypseDragonCurrentLevelData("Control",controlLevel)
	local bonus=controlData~=nil and tonumber(controlData.attackBonus) or 0
	if bonus>0 then
		for _,headName in ipairs(apocalypseDragonColoredHeads or {}) do
			local headData=apocalypseDragonHeadData(headName)
			if headData~=nil and headData.tokenGUID~=nil then
				local tokenGUID=headData.tokenGUID
				local printed=monsterPugs[tokenGUID]
				if printed~=nil and printed.attack~=nil then
					local perks=monsterPerks[tokenGUID] or {}
					perks.attack=apocalypseDragonCopyAttack(printed.attack,bonus)
					perks.dragonControlBonus=bonus
					monsterPerks[tokenGUID]=perks
					syncDragonHeadAttackBonusDecal(tokenGUID,bonus)
				end
			end
		end
	end
end

function apocalypseDragonApplyHeadLevel(headName,level)
	local headData=apocalypseDragonHeadData(headName)
	local tokenData=apocalypseDragonLevelData~=nil and apocalypseDragonLevelData[headName] or nil
	if headData==nil or tokenData==nil then return false end
	level=math.max(0,math.min(12,math.floor(tonumber(level) or 0)))
	local token=getObjectFromGUID(headData.tokenGUID)
	local levelData=level>0 and apocalypseDragonCurrentLevelData(headName,level) or nil
	local image=levelData~=nil and levelData.image or tokenData.blank
	if token~=nil then
		token.setLock(false)
		if type(image)=="string" and image~="" then token.setCustomObject({image=image}) end
		token.setName(level>0 and (headName.." Dragon Head Level "..tostring(level)) or (headName.." Dragon Head Defeated"))
		token.reload()
		--Refresh logical data immediately, then repeat the object-dependent refresh after reload()
		--has produced fresh userdata so Control attack-bonus decals are applied deterministically.
		apocalypseDragonRefreshRuntimeData()
		safeWaitFrames("Scenario",function()
			local current=getObjectFromGUID(headData.tokenGUID)
			if current~=nil then apocalypseDragonPositionHeadToken(headData) end
			apocalypseDragonRefreshRuntimeData()
		end,1)
	else
		apocalypseDragonRefreshRuntimeData()
	end
	return true
end

apocalypseDragonDeployHeadToken=function(headData,bag)
	if headData==nil or headData.tokenGUID==nil then return nil end
	local target=apocalypseDragonHeadTokenPosition(headData)
	if target==nil then return nil end
	local token=getObjectFromGUID(headData.tokenGUID)
	if token==nil and bag~=nil then
		token=bag.takeObject({guid=headData.tokenGUID,position=target,rotation={0,180,0},smooth=false})
	elseif token~=nil then
		token.setLock(false)
		token.setPosition(target)
		token.setRotation({0,180,0})
	end
	if token~=nil then token.setLock(true) end
	return token
end

--The Dragon heads use the same 12-position circular level layout as the Shades of Tezla leader discs.
--Level 1 is at the top, then levels advance clockwise in 30-degree steps.
apocalypseDragonLevelMarkerPosition=function(head,level)
	if head==nil or level==nil or level<1 then return nil end
	local angle=math.rad(120-(30*level))
	local pos=head.getPosition()
	return {pos[1]+(math.cos(angle)*apocalypseDragon.levelMarkerRadius),1.12,pos[3]+(math.sin(angle)*apocalypseDragon.levelMarkerRadius)}
end

apocalypseDragonLockLevelMarker=function(marker,target)
	if marker==nil or target==nil then return end
	marker.setLock(false)
	marker.setPosition(target)
	marker.setRotation({0,180,0})
	marker.setLock(true)
end


function apocalypseDragonColoredHeadsDefeated()
	if gStates==nil or type(gStates.apocalypseDragonHeadLevels)~="table" then return false end
	for _,headName in ipairs(apocalypseDragonColoredHeads) do
		if tonumber(gStates.apocalypseDragonHeadLevels[headName])~=0 then return false end
	end
	return true
end

apocalypseDragonDefeatedHeadCount=function()
	if gStates==nil or type(gStates.apocalypseDragonHeadLevels)~="table" then return 0 end
	local count=0
	for _,headName in ipairs(apocalypseDragonColoredHeads) do
		if tonumber(gStates.apocalypseDragonHeadLevels[headName])==0 then count=count+1 end
	end
	return count
end

apocalypseDragonSyncControlLevel=function()
	if gStates==nil or type(gStates.apocalypseDragonHeadLevels)~="table" then return false end
	local highest=0
	local found=false
	for _,headName in ipairs(apocalypseDragonColoredHeads) do
		local level=tonumber(gStates.apocalypseDragonHeadLevels[headName])
		if level~=nil then
			found=true
			if level>highest then highest=level end
		end
	end
	if found~=true then return false end
	if tonumber(gStates.apocalypseDragonHeadLevels.Control)==highest then return false end
	return apocalypseDragonSetHeadLevel("Control",highest)
end

apocalypseDragonCheckAndResolveDefeat=function()
	if gStates==nil or gStates.apocalypseDragonDefeated==true then return false end
	if scenarioUsesApocalypseDragon()~=true and gStates.apocalypseDragonCityPlaced~=true then return false end
	if apocalypseDragonColoredHeadsDefeated()~=true then return false end

	gStates.apocalypseDragonDefeated=true
	gStates.apocalypseDragonDefeatedRound=gStates.currentRound
	gStates.apocalypseDragonLairAttacked=true
	if tonumber(gStates.apocalypseDragonHeadLevels.Control)~=0 then apocalypseDragonSetHeadLevel("Control",0) end

	local dragonGUID=gStates.gameScenario=="Fury of the Apocalypse Dragon" and apocalypseDragon.furyMarker or apocalypseDragon.model
	local dragon=getObjectFromGUID(dragonGUID)
	if dragon~=nil then
		local trash=getObjectFromGUID(trashCan)
		if trash~=nil then dragon.unlock() trash.putObject(dragon) else dragon.destruct() end
	end
	if gStates.gameScenario=="Fury of the Apocalypse Dragon" then
		local die=gStates.furyDragonManaDieGUID~=nil and getObjectFromGUID(gStates.furyDragonManaDieGUID) or nil
		local spare=getObjectFromGUID(GUID.bag.spareDice)
		if die~=nil then
			die.unlock()
			if spare~=nil then spare.putObject(die) else die.destruct() end
		end
		gStates.furyDragonManaDieGUID=nil
		gStates.furyDragonFlightTarget=nil
		gStates.furyDragonAwaitingCombat=nil
	end

	if scenarioUsesApocalypseDragon()~=true and gStates.apocalypseDragonCityPlaced==true then
		gStates.apocalypseDragonCityDefeated=true
		broadcastToAll("{en}The Apocalypse Dragon replacing the City has been defeated.{ru}Дракон Апокалипсиса, заменивший город, побеждён.{zh-tw}取代城市的末日巨龍已被擊敗。{zh-cn}取代城市的末日巨龙已被击败。{ko}도시를 대신한 아포칼립스 드래곤을 쓰러뜨렸습니다.{es}El Dragón del Apocalipsis que sustituyó a la Ciudad ha sido derrotado.{fr}Le Dragon de l’Apocalypse qui remplaçait la Cité a été vaincu.{pt-br}O Dragão do Apocalipse que substituiu a Cidade foi derrotado.{de}Der Apokalypse-Drache, der die Stadt ersetzt hat, wurde besiegt.",{1,1,0.5})
		local completesScenario=cityConquestScenarioEndAchieved~=nil and cityConquestScenarioEndAchieved()==true
		if completesScenario==true and gStates.endGameAchieved=="false" then
			local coopDragon=gStates.coopAssaultPhase=="combat" and coopAssaultTargetType~=nil and coopAssaultTargetType()=="dragon"
			if coopDragon==true then gStates.coopAssaultScenarioEndPending=true else markScenarioEndAchieved() end
		end
		return true
	end

	local defeatMessage="{en}The Apocalypse Dragon has been defeated! Each Mage Knight has one final turn; the Dummy player does not.{ru}Дракон Апокалипсиса побеждён! У каждого Рыцаря-мага остался один последний ход; у виртуального игрока его нет.{zh-tw}末日巨龍已被擊敗！每位魔法騎士各有最後一個回合；虛擬玩家沒有。{zh-cn}末日巨龙已被击败！每位魔法骑士各有最后一个回合；虚拟玩家没有。{ko}아포칼립스 드래곤을 쓰러뜨렸습니다! 각 마법 기사에게 마지막 한 턴이 남으며, 더미 플레이어에게는 없습니다.{es}¡El Dragón del Apocalipsis ha sido derrotado! Cada Caballero Mago tiene un último turno; el Jugador Virtual no.{fr}Le Dragon de l’Apocalypse a été vaincu ! Chaque Chevalier-Mage a un dernier tour ; le joueur fantôme n’en a pas.{pt-br}O Dragão do Apocalipse foi derrotado! Cada Cavaleiro-Mago tem um último turno; o Jogador Fictício não.{de}Der Apokalypse-Drache wurde besiegt! Jeder Magieritter hat noch einen letzten Zug; der Dummy-Spieler nicht."
	broadcastToAll(defeatMessage,{1,1,0.5})
	local coopDragon=gStates.coopAssaultPhase=="combat" and coopAssaultTargetType~=nil and coopAssaultTargetType()=="dragon"
	if coopDragon==true then gStates.coopAssaultScenarioEndPending=true
	elseif gStates.endGameAchieved=="false" then markScenarioEndAchieved() end
	return true
end

apocalypseDragonHeadStateChanged=function(headName)
	if gStates~=nil and gStates.gameScenario=="Fury of the Apocalypse Dragon" and headName~="Control" and
		tonumber(gStates.apocalypseDragonHeadLevels~=nil and gStates.apocalypseDragonHeadLevels[headName] or -1)==0 then
		--Fury scoring remembers every coloured head defeated at least once, even if a later Dragon turn
		--raises that head back to level 1. Victory still depends on the live levels below.
		gStates.furyDragonEverDefeatedHeads=gStates.furyDragonEverDefeatedHeads or {}
		gStates.furyDragonEverDefeatedHeads[headName]=true
	end
	if headName~="Control" then apocalypseDragonSyncControlLevel() end
	if gStates~=nil and (scenarioUsesApocalypseDragon()==true or gStates.apocalypseDragonCityPlaced==true) then apocalypseDragonCheckAndResolveDefeat() end
end

--Read the physical player Shields on the four large coloured head boards.
--All Dragon scenarios use this shared scoring summary; a one-off getAllObjects() scan is acceptable.
function apocalypseDragonCompetitiveScoreSummary()
	local defeatedHeads=apocalypseDragonDefeatedHeadCount()
	if gStates.gameScenario=="Fury of the Apocalypse Dragon" then
		defeatedHeads=0
		local everDefeated=gStates.furyDragonEverDefeatedHeads or {}
		for _,headName in ipairs(apocalypseDragonColoredHeads) do
			if everDefeated[headName]==true or tonumber(gStates.apocalypseDragonHeadLevels~=nil and gStates.apocalypseDragonHeadLevels[headName] or -1)==0 then defeatedHeads=defeatedHeads+1 end
		end
	end
	local summary={defeatedHeads=defeatedHeads,byMage={},heads={}}
	local mageToPlayer={}
	for playerIndex,details in ipairs(turnOrder or {}) do
		if details~=nil and details.mage~=gStates.positionMageKnight[5] then
			mageToPlayer[details.mage]=playerIndex
			summary.byMage[details.mage]={levels=0,slayerBonus=0,slayerHeads={}}
		end
	end

	local slots={}
	for _,headName in ipairs(apocalypseDragonColoredHeads) do
		local headData=apocalypseDragonHeadData(headName)
		local head=headData~=nil and getObjectFromGUID(headData.guid) or nil
		local headSummary={countByMage={},highestByMage={},winner=nil}
		summary.heads[headName]=headSummary
		if head~=nil then
			for level=1,12 do
				local pos=apocalypseDragonLevelMarkerPosition(head,level)
				if pos~=nil then slots[#slots+1]={head=headName,level=level,pos=pos} end
			end
		end
	end

	for _,obj in ipairs(getAllObjects()) do
		if obj.getName()=="Shield" then
			local mage=obj.getDescription()
			if mageToPlayer[mage]~=nil then
				local pos=obj.getPosition()
				local nearest=nil
				local best=0.72
				for _,slot in ipairs(slots) do
					local dist=math.sqrt(((pos[1]-slot.pos[1])^2)+((pos[3]-slot.pos[3])^2))
					if dist<best then best=dist nearest=slot end
				end
				if nearest~=nil then
					local headSummary=summary.heads[nearest.head]
					headSummary.countByMage[mage]=(headSummary.countByMage[mage] or 0)+1
					headSummary.highestByMage[mage]=math.max(headSummary.highestByMage[mage] or 0,nearest.level)
				end
			end
		end
	end

	if gStates.gameScenario=="Apocalypse is Here" then
		for _,headName in ipairs(apocalypseDragonColoredHeads) do
			local state=gStates.horsemen~=nil and gStates.horsemen[headName] or nil
			local mage=state~=nil and (state.defeatedBy or (gStates.horsemenDefeatedBy~=nil and gStates.horsemenDefeatedBy[headName] or nil)) or nil
			local headSummary=summary.heads[headName]
			if state~=nil and state.defeated==true and mage~=nil and summary.byMage[mage]~=nil and headSummary~=nil then
				local bonus=math.max(1,math.min(6,tonumber(state.defeatedLevel or state.level) or 1))
				headSummary.countByMage[mage]=(headSummary.countByMage[mage] or 0)+bonus
			end
		end
	end

	local fury=gStates.gameScenario=="Fury of the Apocalypse Dragon"
	for headName,headSummary in pairs(summary.heads) do
		local bestCount=0
		local bestHighest=0
		local leaders={}
		for mage,_ in pairs(mageToPlayer) do
			local count=headSummary.countByMage[mage] or 0
			local highest=headSummary.highestByMage[mage] or 0
			if count>bestCount or (count==bestCount and count>0 and highest>bestHighest) then
				bestCount=count
				bestHighest=highest
				leaders={mage}
			elseif count==bestCount and count>0 and highest==bestHighest then
				leaders[#leaders+1]=mage
			end
		end
		headSummary.winners=leaders
		headSummary.winner=#leaders==1 and leaders[1] or nil
		local bonusByMage={}
		if #leaders==1 then
			bonusByMage[leaders[1]]=5
		elseif fury==true and #leaders>1 then
			--Fury explicitly keeps an unresolved tie after the highest-level tiebreaker: every tied
			--Mage Knight receives +3 instead of one player receiving the +5 Greatest Slayer bonus.
			for _,mage in ipairs(leaders) do bonusByMage[mage]=3 end
		end
		for mage,data in pairs(summary.byMage) do
			data.levels=data.levels+(headSummary.countByMage[mage] or 0)
			local bonus=bonusByMage[mage] or 0
			if bonus>0 then
				data.slayerBonus=data.slayerBonus+bonus
				data.slayerHeads[#data.slayerHeads+1]=headName
			end
		end
	end
	return summary
end

function apocalypseDragonSetHeadLevel(headName,level)
	local headData=apocalypseDragonHeadData(headName)
	local head=headData~=nil and getObjectFromGUID(headData.guid) or nil
	if head==nil then return false end
	level=math.max(0,math.min(12,math.floor(tonumber(level) or 0)))
	gStates.apocalypseDragonHeadLevels=gStates.apocalypseDragonHeadLevels or {}
	gStates.apocalypseDragonLevelMarkers=gStates.apocalypseDragonLevelMarkers or {}
	gStates.apocalypseDragonHeadLevels[headName]=level
	local markerGUID=gStates.apocalypseDragonLevelMarkers[headName]
	local marker=markerGUID~=nil and getObjectFromGUID(markerGUID) or nil
	if level==0 then
		if marker~=nil then marker.destruct() end
		gStates.apocalypseDragonLevelMarkers[headName]=nil
		apocalypseDragonApplyHeadLevel(headName,level)
		apocalypseDragonHeadStateChanged(headName)
		return true
	end
	local target=apocalypseDragonLevelMarkerPosition(head,level)
	if target==nil then return false end
	if marker==nil then
		local shieldBag=getObjectFromGUID(GUID.bag.neutralShield)
		if shieldBag==nil then return false end
		marker=shieldBag.takeObject({position=target,rotation={0,180,0},smooth=false})
		if marker==nil then return false end
		gStates.apocalypseDragonLevelMarkers[headName]=marker.guid
	end
	--The Dragon head boards are fixed, so use the tested table height directly.
	target=apocalypseDragonLevelMarkerPosition(head,level)
	marker.setName(headName.." Dragon Head Level "..level)
	apocalypseDragonLockLevelMarker(marker,target)
	apocalypseDragonApplyHeadLevel(headName,level)
	apocalypseDragonHeadStateChanged(headName)
	return true
end

local apocalypseDragonVariantManaFaces={
	[1]={name="Blue",rotation={0,0,0},head="Death"},
	[2]={name="White",rotation={0,0,270},head="Famine"},
	[3]={name="Green",rotation={0,0,90},head="Pestilence"},
	[4]={name="Red",rotation={0,0,180},head="War"},
	[5]={name="Gold",rotation={90,0,0}},
	[6]={name="Black",rotation={270,0,0}}
}

local function apocalypseDragonShowVariantRollHistories(histories,onComplete,xStart)
	local bag=getObjectFromGUID(GUID.bag.spareDice)
	if bag==nil then if onComplete~=nil then onComplete() end return false end
	xStart=xStart or -9
	local dice={}
	local maxSteps=1
	for index,history in ipairs(histories or {}) do
		maxSteps=math.max(maxSteps,#history)
		local face=apocalypseDragonVariantManaFaces[history[1] or 1]
		local die=bag.takeObject({position={xStart+((index-1)*3),2.5,-22.20},rotation=face.rotation,smooth=false})
		if die~=nil then
			die.lock()
			dice[index]=die.guid
		end
	end
	for step=2,maxSteps do
		local rerollStep=step
		safeWaitTime("Scenario",function()
			for index,history in ipairs(histories or {}) do
				local faceIndex=history[rerollStep]
				local dieGUID=dice[index]
				local die=dieGUID~=nil and getObjectFromGUID(dieGUID) or nil
				local face=faceIndex~=nil and apocalypseDragonVariantManaFaces[faceIndex] or nil
				if die~=nil and face~=nil then die.setRotationSmooth(face.rotation,false,false) end
			end
		end,(step-1)*0.65)
	end
	safeWaitTime("Scenario",function()
		local spare=getObjectFromGUID(GUID.bag.spareDice)
		for _,dieGUID in pairs(dice) do
			local die=getObjectFromGUID(dieGUID)
			if die~=nil then
				die.unlock()
				if spare~=nil then spare.putObject(die) else die.destruct() end
			end
		end
		if onComplete~=nil then onComplete() end
	end,((maxSteps-1)*0.65)+1.25)
	return true
end

local function apocalypseDragonRollStartingLevels(baseLevel,positions,onComplete)
	local levels={Famine=math.max(0,baseLevel-1),Death=math.max(0,baseLevel-1),Pestilence=math.max(0,baseLevel-1),War=math.max(0,baseLevel-1)}
	local bag=getObjectFromGUID(GUID.bag.spareDice)
	if bag==nil then error("Random heads could not find the spare mana-die bag.",2) end
	local dice={}
	local sourceGUID=nil

	local function cleanupDice()
		local spare=getObjectFromGUID(GUID.bag.spareDice)
		for index,guid in ipairs(dice) do
			local die=getObjectFromGUID(guid)
			if die~=nil then
				die.unlock()
				--Only the original die came out of the spare-dice bag. The other three are temporary
				--Quest-style clones, so destroy those rather than increasing the bag's contents.
				if index==1 and guid==sourceGUID and spare~=nil then spare.putObject(die) else die.destruct() end
			end
		end
	end

	local function failRoll(message)
		cleanupDice()
		error("Random heads: "..message,2)
	end

	local readSettledResults
	local function rollDice(indices)
		local rollGUIDs={}
		for _,index in ipairs(indices) do
			local guid=dice[index]
			if guid==nil or getObjectFromGUID(guid)==nil then
				return failRoll("a mana die disappeared before rolling.")
			end
			rollGUIDs[#rollGUIDs+1]=guid
		end
		rollPhysicalDice("Scenario",rollGUIDs,readSettledResults,function()
			failRoll("the physical mana-die roll could not settle.")
		end)
	end

	readSettledResults=function()
		--Read the complete physical group after every throw. A Black/Gold reroll can bump another
		--die, so the final levels always come from the faces actually showing on the table.
		for _,headName in ipairs(apocalypseDragonColoredHeads) do levels[headName]=math.max(0,baseLevel-1) end
		local reroll={}
		for index,guid in ipairs(dice) do
			local die=getObjectFromGUID(guid)
			if die==nil then return failRoll("a mana die disappeared before its result was read.") end
			local color=string.lower(tostring(die.getRotationValue() or "")):match("^(%a+)")
			local face=nil
			for _,candidate in ipairs(apocalypseDragonVariantManaFaces) do
				if string.lower(candidate.name)==color then face=candidate break end
			end
			if face~=nil and face.head~=nil then
				levels[face.head]=math.min(12,levels[face.head]+1)
			elseif face~=nil then
				reroll[#reroll+1]=index
			else
				return failRoll("unrecognized settled mana colour "..tostring(color)..".")
			end
		end
		if #reroll>0 then return rollDice(reroll) end

		levels.Control=math.max(levels.Famine,levels.Death,levels.Pestilence,levels.War)
		--Match the Quest crystal-reward presentation: leave the settled faces visible, then clean up
		--the temporary dice and only then apply the result.
		safeWaitTime("Scenario",function()
			cleanupDice()
			onComplete(levels)
		end,1.25)
	end

	--Mirror the proven Quest crystal-reward setup instead of taking four independently spawning dice:
	--take one real die, let it settle, clone the remaining three from that stable source, then roll the
	--whole group together through rollPhysicalDice().
	local source=safeTakeObject("Scenario",bag,{position=positions[1],rotation={0,180,0},smooth=false})
	if source==nil then return failRoll("could not draw the source mana die.") end
	source.unlock()
	sourceGUID=source.guid
	dice[1]=sourceGUID

	safeWaitCondition("Scenario",function()
		local liveSource=getObjectFromGUID(sourceGUID)
		if liveSource==nil then return failRoll("the source mana die disappeared before cloning.") end
		for index=2,4 do
			local die=liveSource.clone({position=positions[index]})
			if die==nil then return failRoll("could not create all four mana dice.") end
			die.unlock()
			dice[index]=die.guid
		end
		rollDice({1,2,3,4})
	end,function()
		local liveSource=getObjectFromGUID(sourceGUID)
		return liveSource~=nil and liveSource.spawning~=true and liveSource.isSmoothMoving()==false and liveSource.resting==true
	end,10,function() failRoll("timed out waiting for the source mana die to settle before cloning.") end)
end

local function apocalypseDragonApplyStartingLevels(levels,onComplete)
	gStates.apocalypseDragonDefeated=false
	gStates.apocalypseDragonHeadLevels={
		Famine=levels.Famine or 0,
		Death=levels.Death or 0,
		Pestilence=levels.Pestilence or 0,
		War=levels.War or 0,
		Control=levels.Control or 0
	}
	for _,headName in ipairs({"Famine","Death","Pestilence","War","Control"}) do
		if apocalypseDragonSetHeadLevel(headName,gStates.apocalypseDragonHeadLevels[headName])~=true then
			error("Could not set the initial level for Apocalypse Dragon head "..tostring(headName)..".",2)
		end
	end
	if onComplete~=nil then onComplete() end
end

function apocalypseDragonInitializeHeadLevels(baseLevel,onComplete)
	baseLevel=math.max(1,math.min(12,math.floor(tonumber(baseLevel) or 1)))
	if gStates.randomizedDragonHeads~=true then
		local levels={Famine=baseLevel,Death=baseLevel,Pestilence=baseLevel,War=baseLevel,Control=baseLevel}
		apocalypseDragonApplyStartingLevels(levels,onComplete)
		return true
	end
	--Keep the four dice in the central gap between the coloured head discs.
	local centerX,centerZ=0,0
	for _,headName in ipairs(apocalypseDragonColoredHeads) do
		local headData=apocalypseDragonHeadData(headName)
		centerX=centerX+headData.position[1]
		centerZ=centerZ+headData.position[3]
	end
	centerX,centerZ=centerX/#apocalypseDragonColoredHeads,centerZ/#apocalypseDragonColoredHeads
	local positions={}
	for index=1,4 do
		positions[index]={centerX+(((index-1)%2)-0.5)*1.1,2.5,centerZ+(math.floor((index-1)/2)-0.5)*1.1}
	end
	apocalypseDragonRollStartingLevels(baseLevel,positions,function(levels)
		apocalypseDragonApplyStartingLevels(levels,onComplete)
	end)
	return true
end

function setupApocalypseDragonHeads()
	if apocalypseDragonComponentsNeeded()~=true then return end
	local scenarioDragon=apocalypseDragonScenario()==true
	local startingLevel=scenarioDragon and apocalypseDragonStartingLevel() or nil
	gStates.apocalypseDragonHeadsSetupReady=false
	gStates.apocalypseDragonHeadLevels={}
	gStates.apocalypseDragonLevelMarkers={}
	gStates.apocalypseDragonDefeated=false
	gStates.furyDragonEverDefeatedHeads=gStates.gameScenario=="Fury of the Apocalypse Dragon" and {} or nil
	local bag=getObjectFromGUID(GUID.bag.apocalypseDragon)
	if gStates.gameScenario=="Against the Dragon Blitz" then
		local roundToken=getObjectFromGUID(apocalypseDragon.roundOrder)
		local roundPos={-1.90,0.97,-22.20}
		if roundToken==nil and bag~=nil then
			roundToken=bag.takeObject({guid=apocalypseDragon.roundOrder,position=roundPos,rotation={0,180,0},smooth=false})
		elseif roundToken~=nil then
			roundToken.setPosition(roundPos)
			roundToken.setRotation({0,180,0})
		end
		if roundToken~=nil then roundToken.lock() end
	end
	for _,headData in ipairs(apocalypseDragon.heads) do
		local head=getObjectFromGUID(headData.guid)
		if head==nil and bag~=nil then
			head=bag.takeObject({guid=headData.guid,position=headData.position,rotation={0,180,0},smooth=false})
		elseif head~=nil then
			head.setPosition(headData.position)
			head.setRotation({0,180,0})
		end
		if head~=nil then head.lock() end
		apocalypseDragonDeployHeadToken(headData,bag)
	end
	if gStates.gameScenario~="Fury of the Apocalypse Dragon" then
		local dragon=getObjectFromGUID(apocalypseDragon.model)
		if dragon==nil and bag~=nil then
			dragon=bag.takeObject({guid=apocalypseDragon.model,position=apocalypseDragon.modelPosition,rotation={0,180,180},smooth=false})
		elseif dragon~=nil then
			dragon.setPosition(apocalypseDragon.modelPosition)
			dragon.setRotation({0,180,180})
		end
		if dragon~=nil then dragon.setLock(scenarioDragon~=true) end
	end

	local function dragonHeadSetupObjectsReady()
		if getObjectFromGUID(GUID.bag.neutralShield)==nil then return false end
		for _,headData in ipairs(apocalypseDragon.heads) do
			if getObjectFromGUID(headData.guid)==nil or getObjectFromGUID(headData.tokenGUID)==nil then return false end
		end
		if gStates.gameScenario~="Fury of the Apocalypse Dragon" and getObjectFromGUID(apocalypseDragon.model)==nil then return false end
		return true
	end
	local function dragonHeadLevelsSettled()
		for _,headData in ipairs(apocalypseDragon.heads) do
			local head=getObjectFromGUID(headData.guid)
			local token=getObjectFromGUID(headData.tokenGUID)
			local target=apocalypseDragonHeadTokenPosition(headData)
			if head==nil or token==nil or target==nil or head.spawning==true or token.spawning==true or head.resting~=true or token.resting~=true then return false end
			local pos=token.getPosition()
			if math.abs(pos[1]-target[1])>0.03 or math.abs(pos[2]-target[2])>0.03 or math.abs(pos[3]-target[3])>0.03 then return false end
		end
		return true
	end
	local function markDragonHeadSetupReady()
		positionApocalypseDragonHeads()
		gStates.apocalypseDragonHeadsSetupReady=true
	end
	local function waitForFinalHeadObjects()
		safeWaitCondition("Scenario",markDragonHeadSetupReady,dragonHeadLevelsSettled,10,function()
			error("SetupGame timed out waiting for Apocalypse Dragon head reloads to settle.",2)
		end)
	end
	local function finishDragonHeadSetup()
		if scenarioDragon==true then
			apocalypseDragonInitializeHeadLevels(startingLevel,waitForFinalHeadObjects)
		else
			--The City replacement's level is unknown until the chosen City tile is revealed.
			--Blank the small tokens now without running defeat logic or creating level markers.
			for _,headData in ipairs(apocalypseDragon.heads) do
				gStates.apocalypseDragonHeadLevels[headData.name]=0
				apocalypseDragonApplyHeadLevel(headData.name,0)
			end
			waitForFinalHeadObjects()
		end
	end
	if dragonHeadSetupObjectsReady()==true then
		finishDragonHeadSetup()
	else
		safeWaitCondition("Scenario",finishDragonHeadSetup,dragonHeadSetupObjectsReady,10,function()
			error("SetupGame timed out waiting for Apocalypse Dragon setup objects.",2)
		end)
	end
end

local apocalypseDragonCityTileGUIDs={
	[GUID.tile.city05]=true,[GUID.tile.city06]=true,[GUID.tile.city07]=true,[GUID.tile.city08]=true
}

function apocalypseDragonCityVariantApplyTerrainOverride()
	if gStates==nil or gStates.apocalypseDragonCityPlaced~=true or gStates.apocalypseDragonLair==nil then return false end
	local key=gStates.apocalypseDragonLair.cityHexKey
	local terrainGUID,bearing=nil,nil
	if key~=nil then terrainGUID,bearing=tostring(key):match("^([^|]+)|(.+)$") end
	if terrainGUID==nil or bearing==nil then return false end
	return runtimeMapSetHexType(terrainGUID,bearing,"plains")
end

function apocalypseDragonFormerCitySpacePlayer(playerIndex)
	if gStates==nil or gStates.apocalypseDragonLair==nil then return false end
	local player=turnOrder[playerIndex]
	if player==nil then return false end
	local pos=fracturedLandsTeleportSourcePosition~=nil and fracturedLandsTeleportSourcePosition(playerIndex) or nil
	if pos==nil then local avatar=coopAssaultAvatarObject(playerIndex) if avatar~=nil then pos=avatar.getPosition() end end
	if pos==nil then return false end
	for _,hex in ipairs(gStates.apocalypseDragonLair.hexes or {}) do
		if hex.formerCity==true and hex.position~=nil and ((pos[1]-hex.position[1])^2)+((pos[3]-hex.position[3])^2)<2.25 then return true end
	end
	return false
end

function apocalypseDragonCityVariantTerrainRevealed(tile)
	if apocalypseDragonCityVariantEnabled()~=true or tile==nil or gStates.apocalypseDragonCityPlaced==true then return false end
	local tileData=terrainTiles[tile.guid]
	if tileData==nil then return false end
	local isCityTile=apocalypseDragonCityTileGUIDs[tile.guid]==true or
		(tile.guid==GUID.tile.volkareCamp and gStates.volkareCampAsCity==true)
	if isCityTile~=true then return false end
	local centerFeature=tostring(tileData.hexFeature~=nil and tileData.hexFeature.center or "")
	if centerFeature:sub(1,4)~="city" and centerFeature~="Volkare's Camp" then return false end

	gStates.apocalypseDragonCityRevealCount=(tonumber(gStates.apocalypseDragonCityRevealCount) or 0)+1
	local mode=math.max(0,math.min(2,math.floor(tonumber(gStates.apocalypseDragonCityMode) or 0)))
	local replaceCity=false
	if mode==1 then
		replaceCity=gStates.apocalypseDragonCityRevealCount>=(tonumber(gStates.cityTiles) or 0)
	elseif mode==2 then
		local faceIndex=math.random(1,6)
		local face=apocalypseDragonVariantManaFaces[faceIndex]
		apocalypseDragonShowVariantRollHistories({{faceIndex}},nil,4)
		broadcastToAll(joinLang({"{en}Apocalypse Dragon City roll: {ru}Бросок города для Дракона Апокалипсиса: {zh-tw}末日巨龍城市擲骰：{zh-cn}末日巨龙城市掷骰：{ko}아포칼립스 드래곤 도시 주사위: {es}Tirada de Ciudad del Dragón del Apocalipsis: {fr}Jet de Cité du Dragon de l’Apocalypse : {pt-br}Rolagem de Cidade do Dragão do Apocalipse: {de}Stadtwurf des Apokalypse-Drachen: ",face.name}),{1,1,0.5})
		replaceCity=faceIndex==6
	end
	if replaceCity~=true then return false end

	local order,cityLevel=cityReplacementLevelForDragon()
	if order==nil or tonumber(cityLevel)==nil or tonumber(cityLevel)<=0 then
		broadcastToAll("{en}The Apocalypse Dragon City variant could not determine the level this City would have had; the normal City is used instead.{ru}Не удалось определить уровень города для варианта с Драконом; используется обычный город.{zh-tw}無法判定此城市原本的等級，因此改用普通城市。{zh-cn}无法判定此城市原本的等级，因此改用普通城市。{ko}이 도시의 원래 레벨을 정할 수 없어 일반 도시를 사용합니다.{es}No se pudo determinar el nivel que habría tenido esta Ciudad; se usa la Ciudad normal.{fr}Impossible de déterminer le niveau qu’aurait eu cette Cité ; la Cité normale est utilisée.{pt-br}Não foi possível determinar o nível que esta Cidade teria; a Cidade normal será usada.{de}Die vorgesehene Stadtstufe konnte nicht ermittelt werden; die normale Stadt wird verwendet.",warningColor)
		return false
	end

	gStates.apocalypseDragonCityPlaced=true
	gStates.apocalypseDragonCityDefeated=false
	gStates.apocalypseDragonDefeated=false
	gStates.apocalypseDragonLairAttacked=false
	gStates.apocalypseDragonLairRevealed=true
	gStates.apocalypseDragonCity={tileGUID=tile.guid,order=order,baseLevel=cityLevel}
	local tilePos=tile.getPosition()
	local tileRotation=tile.getRotation()
	local tileYaw=tileRotation.y or tileRotation[2] or 180
	local dragonRotation={0,tileYaw,180}
	local positions={
		{tilePos[1],0.97,tilePos[3]},
		(function() local xy=angleToXY(tile,"240",tilePos,tileRotation) return {xy[1],0.97,xy[2]} end)(),
		(function() local xy=angleToXY(tile,"300",tilePos,tileRotation) return {xy[1],0.97,xy[2]} end)()
	}
	local hexes={}
	for index,pos in ipairs(positions) do
		local bearing=terrainHexBearing(tile,pos)
		hexes[#hexes+1]={bearing=bearing,position=pos,formerCity=index==1}
		if bearing~=nil then
			local feature=terrainTiles[tile.guid].hexFeature[bearing] or ""
			--Sites under the figure are ignored; rampaging/draconum enemies are not sites and remain.
			if feature~="rampaging" and feature~="draconum" then
				gStates.hexOverideSave=gStates.hexOverideSave or {}
				gStates.hexOverideSave[tile.guid]=gStates.hexOverideSave[tile.guid] or {}
				gStates.hexOverideSave[tile.guid][bearing]=""
				runtimeMapSetHexFeature(tile.guid,bearing,"")
			end
		end
	end
	local target={positions[1][1],1.18,positions[1][3]}
	gStates.apocalypseDragonLair={tileGUID=tile.guid,hexes=hexes,position=target,rotation=dragonRotation,cityHexKey=tile.guid.."|"..tostring(hexes[1].bearing)}
	apocalypseDragonCityVariantApplyTerrainOverride()

	local dragon=getObjectFromGUID(apocalypseDragon.model)
	if dragon~=nil then
		dragon.unlock()
		dragon.setRotationSmooth(dragonRotation,false,true)
		dragon.setPositionSmooth(target,false,true)
		apocalypseDragonLockModelWhenSettled()
	end

	local dragonLevel=math.max(1,math.min(12,math.floor(tonumber(cityLevel) or 1)))
	if tonumber(cityLevel)>12 then
		broadcastToAll("{en}The replaced City is above level 12; Apocalypse Dragon heads are capped at level 12 because the head boards have no higher levels.{ru}Уровень заменённого города выше 12; головы Дракона ограничены уровнем 12.{zh-tw}被取代城市高於 12 級；龍首板最高只有 12 級，因此龍首以 12 級為上限。{zh-cn}被取代城市高于 12 级；龙首板最高只有 12 级，因此龙首以 12 级为上限。{ko}대체된 도시가 12레벨을 넘으므로 드래곤 머리는 보드의 최대치인 12레벨로 제한됩니다.{es}La Ciudad sustituida supera el nivel 12; las cabezas del Dragón se limitan a 12.{fr}La Cité remplacée dépasse le niveau 12 ; les têtes du Dragon sont limitées au niveau 12.{pt-br}A Cidade substituída está acima do nível 12; as cabeças do Dragão ficam limitadas ao nível 12.{de}Die ersetzte Stadt liegt über Stufe 12; die Drachenköpfe werden auf Stufe 12 begrenzt.",warningColor)
	end
	apocalypseDragonInitializeHeadLevels(dragonLevel)
	broadcastToAll(joinLang({"{en}The Apocalypse Dragon replaces this City at level {ru}Дракон Апокалипсиса заменяет этот город на уровне {zh-tw}末日巨龍取代此城市，等級 {zh-cn}末日巨龙取代此城市，等级 {ko}아포칼립스 드래곤이 이 도시를 대체합니다. 레벨 {es}El Dragón del Apocalipsis sustituye esta Ciudad al nivel {fr}Le Dragon de l’Apocalypse remplace cette Cité au niveau {pt-br}O Dragão do Apocalipse substitui esta Cidade no nível {de}Der Apokalypse-Drache ersetzt diese Stadt auf Stufe ",tostring(dragonLevel),"{en}. The former City space is Plains; sites under the Dragon are ignored.{ru}. Бывшее городское поле считается Равниной; места под Драконом игнорируются.{zh-tw}。原城市格視為平原；巨龍下方的地點忽略。{zh-cn}。原城市格视为平原；巨龙下方的地点忽略。{ko}. 기존 도시 칸은 평원이며 드래곤 아래의 장소는 무시합니다.{es}. El antiguo espacio de Ciudad es Llanura; se ignoran los sitios bajo el Dragón.{fr}. L’ancienne case Cité est une Plaine ; les sites sous le Dragon sont ignorés.{pt-br}. O antigo espaço de Cidade é Planície; locais sob o Dragão são ignorados.{de}. Das ehemalige Stadtfeld ist Ebene; Orte unter dem Drachen werden ignoriert."}),{1,0.75,0.2})
	return true
end

function apocalypseDragonLockModelWhenSettled()
	local guid=apocalypseDragon.model
	local function lockDragon()
		local dragon=getObjectFromGUID(guid)
		if dragon~=nil then dragon.lock() end
	end
	safeWaitCondition("Scenario",lockDragon,function()
		local dragon=getObjectFromGUID(guid)
		return dragon==nil or dragon.resting==true
	end,5,lockDragon)
end

--The shared Dragon combat helpers need the Dragon's current footprint, not necessarily its original
--Lair. Fury uses a single marker which alternates between a landed map/City space and off-map flight.
function apocalypseDragonCombatHexes()
	if gStates==nil or gStates.apocalypseDragonLairRevealed~=true then return {} end
	if gStates.gameScenario=="Fury of the Apocalypse Dragon" then
		if gStates.furyDragonFlightTarget~=nil or gStates.furyDragonCurrentHexKey==nil then return {} end
		local key=tostring(gStates.furyDragonCurrentHexKey)
		local tileGUID,bearing=key:match("^([^|]+)|(.+)$")
		local tile=tileGUID~=nil and getObjectFromGUID(tileGUID) or nil
		if tile==nil or bearing==nil then return {} end
		local xy=angleToXY(tile,bearing)
		return {{tileGUID=tileGUID,bearing=bearing,key=key,position={xy[1],0.97,xy[2]}}}
	end
	return gStates.apocalypseDragonLair~=nil and (gStates.apocalypseDragonLair.hexes or {}) or {}
end

function apocalypseDragonCombatContainsPosition(pos)
	if pos==nil or gStates==nil or gStates.apocalypseDragonDefeated==true then return false end
	for _,hex in ipairs(apocalypseDragonCombatHexes()) do
		local p=hex.position
		if p~=nil and ((pos[1]-p[1])^2)+((pos[3]-p[3])^2)<2.25 then return true end
	end
	return false
end

function apocalypseDragonCombatContainsPlayer(playerIndex)
	if gStates==nil or gStates.apocalypseDragonDefeated==true or turnOrder[playerIndex]==nil then return false end
	local pos=mageKnightAvatarPosition~=nil and mageKnightAvatarPosition(playerIndex) or nil
	if pos~=nil and apocalypseDragonCombatContainsPosition(pos)==true then return true end
	if gStates.gameScenario~="Fury of the Apocalypse Dragon" or gStates.furyDragonFlightTarget~=nil then return false end
	local key=gStates.furyDragonCurrentHexKey
	if key==nil then return false end
	local tileGUID,bearing=tostring(key):match("^([^|]+)|(.+)$")
	local details=tileGUID~=nil and terrainTiles[tileGUID] or nil
	local feature=details~=nil and details.hexFeature~=nil and details.hexFeature[bearing] or ""
	if tostring(feature):sub(1,4)~="city" then return false end
	local color=tostring(feature):lower():match("^city%s+(%a+)")
	local cityGUID=color~=nil and cityModel[color] or nil
	local player=turnOrder[playerIndex]
	return cityGUID~=nil and (player.avatarSwapCity==cityGUID or player.avatarLocation==feature)
end

--Fury fortifies the Dragon only when the Mage Knights attack it in its Lair, or in an undefended
--City which has not been destroyed. When the Dragon attacks the Heroes, the underlying site is ignored.
function apocalypseDragonFuryAttackFortified()
	if gStates==nil or gStates.gameScenario~="Fury of the Apocalypse Dragon" or gStates.furyDragonFlightTarget~=nil then return false end
	local key=gStates.furyDragonCurrentHexKey
	if key==nil then return false end
	if gStates.apocalypseDragonLair~=nil and key==gStates.apocalypseDragonLair.cityHexKey then return true end
	local tileGUID,bearing=tostring(key):match("^([^|]+)|(.+)$")
	local details=tileGUID~=nil and terrainTiles[tileGUID] or nil
	local feature=details~=nil and details.hexFeature~=nil and details.hexFeature[bearing] or ""
	if tostring(feature):sub(1,4)~="city" then return false end
	local color=tostring(feature):lower():match("^city%s+(%a+)")
	local cityGUID=color~=nil and cityModel[color] or nil
	local defenders=cityGUID~=nil and gStates.cityMonsterQty~=nil and gStates.cityMonsterQty[cityGUID] or nil
	for guid,state in pairs(defenders or {}) do
		if guid~="extra" and state=="alive" then return false end
	end
	return true
end

function apocalypseDragonGroundCombatForPlayer(playerIndex)
	local combat=gStates~=nil and gStates.apocalypseDragonGroundCombat or nil
	if combat==nil or combat.finished==true then return false end
	if combat.coop==true then return combat.players~=nil and combat.players[playerIndex]==true and (combat.finishedPlayers==nil or combat.finishedPlayers[playerIndex]~=true) end
	return combat.playerIndex==playerIndex
end

function apocalypseDragonGroundHeadNameForGUID(guid)
	if guid==nil then return nil end
	for _,headData in ipairs(apocalypseDragon.heads) do if headData.tokenGUID==guid then return headData.name end end
	local combat=gStates~=nil and gStates.apocalypseDragonGroundCombat or nil
	if combat~=nil and combat.controlClones~=nil and combat.controlClones[guid]~=nil then return "Control" end
	return nil
end

function apocalypseDragonGroundHeadOwner(headName)
	local combat=gStates~=nil and gStates.apocalypseDragonGroundCombat or nil
	if combat==nil or headName==nil then return nil end
	if combat.headOwners~=nil and combat.headOwners[headName]~=nil then return combat.headOwners[headName] end
	return combat.playerIndex
end

function apocalypseDragonGroundHeadToken(guid)
	local combat=gStates~=nil and gStates.apocalypseDragonGroundCombat or nil
	local headName=apocalypseDragonGroundHeadNameForGUID(guid)
	if combat==nil or headName==nil then return false,headName end
	if headName=="Control" and combat.controlClones~=nil and combat.controlClones[guid]~=nil then return false,headName end
	return combat.deployed~=nil and combat.deployed[headName]==true,headName
end

function apocalypseDragonGroundControlToken(guid)
	local combat=gStates~=nil and gStates.apocalypseDragonGroundCombat or nil
	if combat==nil or guid==nil then return false,nil end
	local controlData=apocalypseDragonHeadData("Control")
	if controlData~=nil and guid==controlData.tokenGUID and combat.deployed~=nil and combat.deployed.Control==true then return true,combat.playerIndex end
	if combat.controlClones~=nil and combat.controlClones[guid]~=nil then return true,combat.controlClones[guid] end
	return false,nil
end

function apocalypseDragonGroundCombatToken(guid)
	local active,headName=apocalypseDragonGroundHeadToken(guid)
	if active==true then return true,headName,apocalypseDragonGroundHeadOwner(headName) end
	local control,owner=apocalypseDragonGroundControlToken(guid)
	if control==true then return true,"Control",owner end
	return false,nil,nil
end

function apocalypseDragonGroundTokenPosition(playerIndex,slot)
	local details=turnOrder[playerIndex]
	if details==nil then return nil end
	--Keep the Dragon fight clear of the normal left-side combat controls: two enemy slots right.
	return {(details.seatPos*40)-100+((slot-1)*2.5),1.5,-39.25}
end

apocalypseDragonGroundReduction=function(headName)
	local combat=gStates~=nil and gStates.apocalypseDragonGroundCombat or nil
	if combat==nil or combat.reductions==nil then return 1 end
	return math.max(1,math.floor(tonumber(combat.reductions[headName]) or 1))
end

apocalypseDragonGroundControlGUIDs=function()
	local combat=gStates~=nil and gStates.apocalypseDragonGroundCombat or nil
	local guids={}
	if combat==nil then return guids end
	local controlData=apocalypseDragonHeadData("Control")
	if controlData~=nil and combat.deployed~=nil and combat.deployed.Control==true then guids[#guids+1]=controlData.tokenGUID end
	for guid,_ in pairs(combat.controlClones or {}) do guids[#guids+1]=guid end
	return guids
end

function apocalypseDragonRefreshGroundAttackSuppression()
	local combat=gStates~=nil and gStates.apocalypseDragonGroundCombat or nil
	if combat==nil then return false end
	gStates.monsterPerks=gStates.monsterPerks or {}
	local controlLevel=tonumber(gStates.apocalypseDragonHeadLevels~=nil and gStates.apocalypseDragonHeadLevels.Control or 0) or 0
	local controlLevelData=apocalypseDragonCurrentLevelData("Control",controlLevel)
	local controlBonus=controlLevelData~=nil and tonumber(controlLevelData.attackBonus) or 0
	for _,headName in ipairs(apocalypseDragonColoredHeads) do
		local headData=apocalypseDragonHeadData(headName)
		local level=tonumber(gStates.apocalypseDragonHeadLevels~=nil and gStates.apocalypseDragonHeadLevels[headName] or 0) or 0
		if level>0 then
			if headData~=nil and combat.deployed~=nil and combat.deployed[headName]==true then
				local printed=apocalypseDragonMonsterData(headName,level)
				if printed~=nil then
					--The head remains at its entered-combat level until cleanup. The player decides combat
					--phase timing manually, so the reduction dial never changes/suppresses its printed stats.
					printed.fame=1
					monsterPugs[headData.tokenGUID]=printed
				end
				local perks=gStates.monsterPerks[headData.tokenGUID] or {}
				perks.attack=nil
				perks.dragonControlBonus=nil
				if controlBonus>0 and printed~=nil and printed.attack~=nil then
					perks.attack=apocalypseDragonCopyAttack(printed.attack,controlBonus)
					perks.dragonControlBonus=controlBonus
				end
				gStates.monsterPerks[headData.tokenGUID]=perks
				syncDragonHeadAttackBonusDecal(headData.tokenGUID,(controlBonus>0 and printed~=nil and printed.attack~=nil) and controlBonus or 0)
			end
		end
	end
	for _,guid in ipairs(apocalypseDragonGroundControlGUIDs()) do
		local control=getObjectFromGUID(guid)
		if control~=nil and controlLevel>0 then
			local printed=apocalypseDragonMonsterData("Control",controlLevel)
			if printed~=nil then
				printed.fame=0
				monsterPugs[guid]=printed
			end
			local perks=gStates.monsterPerks[guid] or {}
			perks.dragonGround=true
			perks.dragonGroundLevel=controlLevel
			perks.dragonLevelFame=nil
			gStates.monsterPerks[guid]=perks
			setMonsterObjectButtons(control)
		end
	end
	return true
end

apocalypseDragonGroundReductionAdjust=function(player,mouseButton,id)
	if mouseButton~="-1" then return end
	local guid=tostring(id or ""):sub(1,6)
	local active,headName=apocalypseDragonGroundHeadToken(guid)
	local combat=gStates~=nil and gStates.apocalypseDragonGroundCombat or nil
	if active~=true or combat==nil or headName==nil or headName=="Control" then return end
	local owner=apocalypseDragonGroundHeadOwner(headName)
	if owner==nil then return end
	if combat.finishedPlayers~=nil and combat.finishedPlayers[owner]==true then return end
	local color=player~=nil and player.color or nil
	local allowed=positionToColor(owner)
	if color~="Black" and color~=allowed then return end
	local current=tonumber(gStates.apocalypseDragonHeadLevels~=nil and gStates.apocalypseDragonHeadLevels[headName] or 0) or 0
	if current<1 then return end
	local value=apocalypseDragonGroundReduction(headName)
	if id:find("GroundOverkillUp",1,true)~=nil and value<current then value=value+1 end
	if id:find("GroundOverkillDown",1,true)~=nil and value>1 then value=value-1 end
	local reductions=combat.reductions or {}
	combat.reductions=reductions
	reductions[headName]=value
	local token=getObjectFromGUID(guid)
	if token~=nil then token.UI.setAttribute(guid.."GroundOverkill","text",tostring(value)) end
	apocalypseDragonRefreshGroundAttackSuppression()
	apocalypseDragonRefreshGroundFameGain(owner)
	mainUIUpdate("Dragon Head Reduction")
end

function apocalypseDragonGroundHeadButtons(obj)
	local active,headName=apocalypseDragonGroundHeadToken(obj~=nil and obj.guid or nil)
	if active~=true or headName==nil or headName=="Control" then return {} end
	local combat=gStates~=nil and gStates.apocalypseDragonGroundCombat or nil
	if combat~=nil and combat.processedTokens~=nil and combat.processedTokens[obj.guid]==true then return {} end
	local value=apocalypseDragonGroundReduction(headName)
	return {
		{tag="Button",attributes={id=obj.guid.."GroundOverkillUp",onMouseDown="global/buttonClicked",onMouseUp="global/buttonClicked",onClick="global/apocalypseDragonGroundReductionAdjust",height=50/0.9,width=50/0.9,color="rgba(0,0,0,0.0)",position="-62 "..tostring(-120/0.9).." "..tostring(-15/0.9),rotation="0 0 180"},children={{tag="Image",attributes={id=obj.guid.."GroundOverkillUpImage",image="Overkill Up"}}}},
		{tag="Image",attributes={image="Overkill Text",height=50/0.9,width=55/0.9,position="0 "..tostring(-120/0.9).." "..tostring(-15/0.9),rotation="0 0 180"},children={{tag="Text",attributes={id=obj.guid.."GroundOverkill",color="rgb(0,0,0)",fontSize="45",fontStyle="Bold",alignment="MiddleCenter",text=tostring(value)}}}},
		{tag="Button",attributes={id=obj.guid.."GroundOverkillDown",onMouseDown="global/buttonClicked",onMouseUp="global/buttonClicked",onClick="global/apocalypseDragonGroundReductionAdjust",height=50/0.9,width=50/0.9,color="rgba(0,0,0,0.0)",position="62 "..tostring(-120/0.9).." "..tostring(-15/0.9),rotation="0 0 180"},children={{tag="Image",attributes={id=obj.guid.."GroundOverkillDownImage",image="Overkill Down"}}}}
	}
end

apocalypseDragonGroundPrepareColoredHead=function(combat,headName,playerIndex)
	local headData=apocalypseDragonHeadData(headName)
	local level=tonumber(gStates.apocalypseDragonHeadLevels~=nil and gStates.apocalypseDragonHeadLevels[headName] or 0) or 0
	if headData==nil or level<=0 then return false end
	local token=getObjectFromGUID(headData.tokenGUID)
	if token==nil then return false end
	combat.deployed[headName]=true
	combat.headOwners[headName]=playerIndex
	combat.reductions[headName]=1
	local printed=apocalypseDragonMonsterData(headName,level)
	if printed~=nil then
		printed.fame=1
		if combat.fortifiedPlayers~=nil and combat.fortifiedPlayers[playerIndex]==true then printed.fortified=true end
		monsterPugs[headData.tokenGUID]=printed
	end
	local perks=gStates.monsterPerks[headData.tokenGUID] or {}
	perks.dragonGround=true
	perks.dragonGroundLevel=level
	perks.dragonLevelFame=1
	gStates.monsterPerks[headData.tokenGUID]=perks
	gStates.monsterPlayLocation[headData.tokenGUID]=apocalypseDragonHeadTokenPosition(headData)
	token.setLock(false)
	token.setRotation({0,180,0})
	setMonsterObjectButtons(token)
	return true
end

apocalypseDragonGroundPrepareControl=function(combat,playerIndex,slot,useOriginal)
	local controlData=apocalypseDragonHeadData("Control")
	local level=tonumber(gStates.apocalypseDragonHeadLevels~=nil and gStates.apocalypseDragonHeadLevels.Control or 0) or 0
	if controlData==nil or level<=0 then return nil end
	local original=getObjectFromGUID(controlData.tokenGUID)
	if original==nil then return nil end
	local target=apocalypseDragonGroundTokenPosition(playerIndex,slot)
	local token=original
	if useOriginal~=true then
		token=original.clone({position=target,rotation={0,180,0},smooth=false})
		if token==nil then return nil end
		combat.controlClones[token.guid]=playerIndex
	else
		combat.deployed.Control=true
		gStates.monsterPlayLocation[controlData.tokenGUID]=apocalypseDragonHeadTokenPosition(controlData)
		original.setLock(false)
		original.setRotation({0,180,0})
		if target~=nil then original.setPositionSmooth(target,false,true) end
	end
	local printed=apocalypseDragonMonsterData("Control",level)
	if printed~=nil then printed.fame=0 monsterPugs[token.guid]=printed end
	local perks=gStates.monsterPerks[token.guid] or {}
	perks.dragonGround=true
	perks.dragonGroundLevel=level
	perks.dragonLevelFame=nil
	gStates.monsterPerks[token.guid]=perks
	token.setLock(false)
	token.setRotation({0,180,0})
	if useOriginal~=true and target~=nil then token.setPosition(target) end
	safeWaitFrames("Scenario",function() local current=getObjectFromGUID(token.guid) if current~=nil then setMonsterObjectButtons(current) end end,2)
	return token
end

apocalypseDragonNewGroundCombat=function(coop)
	return {coop=coop==true,players={},headOwners={},deployed={},reductions={},processedTokens={},fameByPlayer={},previewFameByPlayer={},finishedPlayers={},controlClones={},fortifiedPlayers={},finished=false,levelsApplied=false}
end

apocalypseDragonGroundTokenInPlayerArea=function(tokenGUID,playerIndex)
	local details=turnOrder[playerIndex]
	if tokenGUID==nil or details==nil then return false end
	for _,obj in pairs(playerCombatObjects(details.seatPos)) do if obj.guid==tokenGUID then return true end end
	return false
end

function apocalypseDragonRefreshGroundFameGain(playerIndex)
	local combat=gStates~=nil and gStates.apocalypseDragonGroundCombat or nil
	local details=turnOrder[playerIndex]
	if combat==nil or details==nil or combat.finished==true then return false end
	--Resolved heads stay earned while unprocessed heads behave like faction leaders: they only
	--contribute while face up and physically inside their owner's Play/Unit combat area.
	local total=tonumber(combat.fameByPlayer~=nil and combat.fameByPlayer[playerIndex] or 0) or 0
	for _,headName in ipairs(apocalypseDragonColoredHeads) do
		if apocalypseDragonGroundHeadOwner(headName)==playerIndex and combat.deployed~=nil and combat.deployed[headName]==true then
			local headData=apocalypseDragonHeadData(headName)
			local token=headData~=nil and getObjectFromGUID(headData.tokenGUID) or nil
			if token~=nil and (combat.processedTokens==nil or combat.processedTokens[token.guid]~=true) and token.is_face_down==false
				and apocalypseDragonGroundTokenInPlayerArea(token.guid,playerIndex)==true then
				total=total+apocalypseDragonGroundReduction(headName)
			end
		end
	end
	combat.previewFameByPlayer=combat.previewFameByPlayer or {}
	local previous=tonumber(combat.previewFameByPlayer[playerIndex]) or 0
	if total~=previous then
		details.fameGain=(details.fameGain or 0)+(total-previous)
		if details.fameGain<0 then details.fameGain=0 end
		combat.previewFameByPlayer[playerIndex]=total
	end
	return true
end

function apocalypseDragonBeginGroundCombat(playerIndex)
	if apocalypseDragonCombatEnabled()~=true then return false end
	if gStates.apocalypseDragonGroundCombat~=nil then return apocalypseDragonGroundCombatForPlayer(playerIndex) end
	local details=turnOrder[playerIndex]
	if details==nil or details.mage==gStates.positionMageKnight[5] then return false end
	if gStates.gameScenario=="Fury of the Apocalypse Dragon" then
		gStates.apocalypseDragonAssaultFortifiedInitiator=apocalypseDragonFuryAttackFortified()
	else
		gStates.apocalypseDragonLairAttacked=true --Against/Here stop their automated Dragon/Horsemen sequence after the first assault.
	end
	local combat=apocalypseDragonNewGroundCombat(false)
	combat.playerIndex=playerIndex
	combat.mage=details.mage
	combat.players[playerIndex]=true
	if gStates.apocalypseDragonAssaultFortifiedInitiator==true then combat.fortifiedPlayers[playerIndex]=true end
	gStates.apocalypseDragonGroundCombat=combat
	gStates.monsterPerks=gStates.monsterPerks or {}
	--Control is always the first/left-most Dragon head; coloured heads follow it.
	apocalypseDragonGroundPrepareControl(combat,playerIndex,1,true)
	local slot=2
	for _,headName in ipairs(apocalypseDragonColoredHeads) do
		if apocalypseDragonGroundPrepareColoredHead(combat,headName,playerIndex)==true then
			local headData=apocalypseDragonHeadData(headName)
			local token=headData~=nil and getObjectFromGUID(headData.tokenGUID) or nil
			local target=apocalypseDragonGroundTokenPosition(playerIndex,slot)
			if token~=nil and target~=nil then token.setPositionSmooth(target,false,true) end
			slot=slot+1
		end
	end
	apocalypseDragonRefreshGroundAttackSuppression()
	apocalypseDragonRefreshGroundFameGain(playerIndex)
	combatCameraFocus(playerIndex)
	mainUIUpdate("Apocalypse Dragon Ground Combat")
	broadcastToAll(joinLang({translateWord[details.mage] or tostring(details.mage),"{en} attacks the landed Apocalypse Dragon. Each coloured head is a separate enemy; use the +/- control on a face-up head to record how many levels your attack reduced. Flip a coloured head face down if you did not reduce it. The Control head cannot be attacked.{ru} атакует приземлившегося Дракона Апокалипсиса. Каждая цветная голова считается отдельным врагом; используйте +/- на открытой голове, чтобы записать, на сколько уровней её снизила атака. Переверните цветную голову лицом вниз, если вы не снизили её уровень. Голову Контроля атаковать нельзя.{zh-tw} 攻擊已落地的末日巨龍。每個彩色龍首都是獨立敵人；用正面龍首上的 +/- 控制記錄攻擊降低了多少等級。若未降低某個彩色龍首的等級，將其翻至背面。控制龍首不能被攻擊。{zh-cn} 攻击已落地的末日巨龙。每个彩色龙首都是独立敌人；用正面龙首上的 +/- 控制记录攻击降低了多少等级。若未降低某个彩色龙首的等级，将其翻至背面。控制龙首不能被攻击。{ko}이(가) 착륙한 아포칼립스 드래곤을 공격합니다. 각 색깔 머리는 별도의 적입니다. 앞면인 머리의 +/-를 사용해 공격으로 낮춘 레벨 수를 기록하십시오. 레벨을 낮추지 못한 색깔 머리는 뒷면으로 뒤집으십시오. 제어 머리는 공격할 수 없습니다.{es} ataca al Dragón del Apocalipsis aterrizado. Cada cabeza de color es un enemigo separado; usa el control +/- de una cabeza boca arriba para registrar cuántos niveles redujo tu ataque. Voltea boca abajo una cabeza de color si no redujiste su nivel. La cabeza de Control no puede ser atacada.{fr} attaque le Dragon de l’Apocalypse au sol. Chaque tête colorée est un ennemi distinct ; utilisez le contrôle +/- d’une tête face visible pour noter le nombre de niveaux retirés par votre attaque. Retournez une tête colorée face cachée si vous n’avez réduit aucun niveau. La tête de Contrôle ne peut pas être attaquée.{pt-br} ataca o Dragão do Apocalipse pousado. Cada cabeça colorida é um inimigo separado; use o controle +/- em uma cabeça virada para cima para registrar quantos níveis seu ataque reduziu. Vire uma cabeça colorida para baixo se você não reduziu seu nível. A cabeça de Controle não pode ser atacada.{de} greift den gelandeten Apokalypse-Drachen an. Jeder farbige Kopf ist ein eigener Gegner; verwende die +/- Steuerung eines offenen Kopfes, um festzuhalten, um wie viele Stufen dein Angriff ihn reduziert hat. Drehe einen farbigen Kopf verdeckt, wenn du ihn nicht reduziert hast. Der Kontrollkopf kann nicht angegriffen werden."}),positionToColor(playerIndex))
	return true
end

apocalypseDragonCoopAdjacentPlayers=function(playerIndex)
	local result={}
	if gStates==nil then return result end
	local dragonHexes=apocalypseDragonCombatHexes()
	if #dragonHexes<1 then return result end
	for candidate,details in ipairs(turnOrder or {}) do
		if candidate~=playerIndex and details~=nil and details.mage~=gStates.positionMageKnight[5] and playerDropoutInactive(candidate)==false then
			local pos=fracturedLandsTeleportSourcePosition~=nil and fracturedLandsTeleportSourcePosition(candidate) or nil
			if pos==nil then local avatar=coopAssaultAvatarObject(candidate) if avatar~=nil then pos=avatar.getPosition() end end
			local adjacent=false
			if pos~=nil then
				for _,hex in ipairs(dragonHexes) do
					local p=hex.position
					if p~=nil then
						local d=((pos[1]-p[1])^2)+((pos[3]-p[3])^2)
						if d>4.2 and d<7.4 then adjacent=true break end
					end
				end
			end
			if adjacent==true then result[#result+1]={mage=details.mage,turn=candidate} end
		end
	end
	return result
end

function apocalypseDragonBeginLairAssault(playerIndex,approachPosition)
	if apocalypseDragonCombatEnabled()~=true then return false end
	if gStates.coopAssaultPhase~=nil or gStates.apocalypseDragonGroundCombat~=nil then return false end
	local player=turnOrder[playerIndex]
	if player==nil or playerIndex~=gStates.turnNumber or playerDropoutInactive(playerIndex)==true then return false end
	local endHorsemenOnStart=gStates.gameScenario=="Apocalypse is Here" and gStates.apocalypseDragonLairAttacked~=true and apocalypseIsHereEndHorsemen~=nil
	if gStates.gameScenario=="Fury of the Apocalypse Dragon" then
		gStates.apocalypseDragonAssaultFortifiedInitiator=apocalypseDragonFuryAttackFortified()
	elseif gStates.gameScenario=="Apocalypse is Here" or gStates.apocalypseDragonCityPlaced==true then
		gStates.apocalypseDragonAssaultFortifiedInitiator=apocalypseDragonFormerCitySpacePlayer(playerIndex)
	else
		gStates.apocalypseDragonAssaultFortifiedInitiator=false
	end
	local liveHeads={}
	for _,headName in ipairs(apocalypseDragonColoredHeads) do
		local level=tonumber(gStates.apocalypseDragonHeadLevels~=nil and gStates.apocalypseDragonHeadLevels[headName] or 0) or 0
		local headData=apocalypseDragonHeadData(headName)
		if level>0 and headData~=nil and getObjectFromGUID(headData.tokenGUID)~=nil then liveHeads[#liveHeads+1]=headData.tokenGUID end
	end
	if #liveHeads<1 then return false end
	local nearby=apocalypseDragonCoopAdjacentPlayers(playerIndex)
	if #liveHeads<2 or #nearby<1 then
		local started=apocalypseDragonBeginGroundCombat(playerIndex)
		if started==true and endHorsemenOnStart==true then apocalypseIsHereEndHorsemen() end
		return started
	end

	gStates.apocalypseDragonAssaultOrigin=assaultOriginFromPosition(approachPosition)
	gStates.assaultData={[player.mage]={primary={},secondary={},UIPos={1},joined=true}}
	for _,guid in ipairs(liveHeads) do
		gStates.assaultData[player.mage].primary[#gStates.assaultData[player.mage].primary+1]=guid
		local headName=apocalypseDragonGroundHeadNameForGUID(guid)
		local headData=headName~=nil and apocalypseDragonHeadData(headName) or nil
		if headData~=nil then gStates.monsterPlayLocation[guid]=apocalypseDragonHeadTokenPosition(headData) end
	end
	local count=1
	for _,candidate in ipairs(nearby) do
		count=count+1
		gStates.assaultData[candidate.mage]={primary={},secondary={},UIPos={count},joined=false}
	end
	gStates.coopAssaultUnassigned={primary={},secondary={}}
	gStates.coopAssaultCityGUID=apocalypseDragon.model
	gStates.coopAssaultLocation="apocalypse dragon"
	gStates.coopAssaultType="dragon"
	gStates.coopAssaultInitiator=playerIndex
	player.combatIconHide="Avatar"
	locationAttacked=true
	applyColorBarButtons()
	coopAssaultUIUpdate()
	if endHorsemenOnStart==true then apocalypseIsHereEndHorsemen() end
	return true
end

function apocalypseDragonBeginCoopGroundCombat()
	if gStates==nil or gStates.coopAssaultPhase~="combat" or coopAssaultTargetType()~="dragon" then return false end
	if gStates.apocalypseDragonGroundCombat~=nil then return true end
	local combat=apocalypseDragonNewGroundCombat(true)
	combat.initiator=gStates.coopAssaultInitiator or gStates.turnNumber
	gStates.apocalypseDragonGroundCombat=combat
	if gStates.gameScenario~="Fury of the Apocalypse Dragon" then gStates.apocalypseDragonLairAttacked=true end
	gStates.monsterPerks=gStates.monsterPerks or {}
	for playerIndex,_ in pairs(gStates.coopAssaultParticipants or {}) do
		combat.players[playerIndex]=true
		combat.fameByPlayer[playerIndex]=0
		if gStates.gameScenario=="Fury of the Apocalypse Dragon" and gStates.apocalypseDragonAssaultFortifiedInitiator==true then combat.fortifiedPlayers[playerIndex]=true end
	end
	if gStates.gameScenario~="Fury of the Apocalypse Dragon" and gStates.apocalypseDragonAssaultFortifiedInitiator==true then combat.fortifiedPlayers[combat.initiator]=true end
	for playerIndex,details in ipairs(turnOrder or {}) do
		local assigned=details~=nil and gStates.assaultData~=nil and gStates.assaultData[details.mage] or nil
		if assigned~=nil and assigned.joined==true then
			for _,army in ipairs({"primary","secondary"}) do
				for _,guid in ipairs(assigned[army] or {}) do
					local headName=apocalypseDragonGroundHeadNameForGUID(guid)
					if headName~=nil and headName~="Control" then apocalypseDragonGroundPrepareColoredHead(combat,headName,playerIndex) end
				end
			end
			apocalypseDragonGroundPrepareControl(combat,playerIndex,1,false)
		end
	end
	apocalypseDragonRefreshGroundAttackSuppression()
	for playerIndex,_ in pairs(combat.players or {}) do apocalypseDragonRefreshGroundFameGain(playerIndex) end
	broadcastToAll("{en}The cooperative assault on the Apocalypse Dragon begins. The coloured heads have been divided between the participating Mage Knights; every participant also faces the Control head.{ru}Начинается совместный штурм Дракона Апокалипсиса. Цветные головы распределены между участвующими Рыцарями-магами; каждый участник также сражается с головой Контроля.{zh-tw}對末日巨龍的合作攻城開始。彩色龍首已分配給參戰的魔法騎士；每名參戰者也都要面對控制龍首。{zh-cn}对末日巨龙的合作攻城开始。彩色龙首已分配给参战的魔法骑士；每名参战者也都要面对控制龙首。{ko}아포칼립스 드래곤 협동 공격이 시작됩니다. 색깔 머리는 참가한 마법 기사들에게 나뉘어 배정되며, 모든 참가자는 제어 머리도 상대합니다.{es}Comienza el asalto cooperativo al Dragón del Apocalipsis. Las cabezas de colores se han repartido entre los Caballeros Mago participantes; cada participante también se enfrenta a la cabeza de Control.{fr}L’assaut coopératif contre le Dragon de l’Apocalypse commence. Les têtes colorées ont été réparties entre les Chevaliers-Mages participants ; chacun affronte également la tête de Contrôle.{pt-br}Começa o assalto cooperativo ao Dragão do Apocalipse. As cabeças coloridas foram divididas entre os Cavaleiros-Magos participantes; cada participante também enfrenta a cabeça de Controle.{de}Der kooperative Angriff auf den Apokalypse-Drachen beginnt. Die farbigen Köpfe wurden auf die teilnehmenden Magieritter verteilt; jeder Teilnehmer stellt sich außerdem dem Kontrollkopf.",{1,0.75,0.2})
	return true
end

--Fury defensive combat uses the same landed head engine, but the Dragon is the attacker.
--When several Heroes share a City, every Hero participates. Coloured heads are randomly dealt in
--reverse Round order while every participant receives a Control-head clone. All level reductions are
--applied together after the last participant, preserving the combat's starting head levels.
function apocalypseDragonBeginFuryDefenseCombat(players)
	if gStates==nil or gStates.gameScenario~="Fury of the Apocalypse Dragon" or gStates.apocalypseDragonDefeated==true or type(players)~="table" or #players<1 then return false end
	if gStates.apocalypseDragonGroundCombat~=nil then return false end
	local ordered={}
	for _,playerIndex in ipairs(players) do
		local details=turnOrder[playerIndex]
		if details~=nil and details.mage~=gStates.positionMageKnight[5] and playerDropoutInactive(playerIndex)==false then ordered[#ordered+1]=playerIndex end
	end
	table.sort(ordered)
	if #ordered<1 then return false end

	local combat=apocalypseDragonNewGroundCombat(true)
	combat.furyDefense=true
	combat.assignments={}
	gStates.apocalypseDragonGroundCombat=combat
	gStates.monsterPerks=gStates.monsterPerks or {}
	for _,playerIndex in ipairs(ordered) do
		combat.players[playerIndex]=true
		combat.fameByPlayer[playerIndex]=0
		combat.assignments[playerIndex]={}
	end

	local liveHeads={}
	for _,headName in ipairs(apocalypseDragonColoredHeads) do
		if (tonumber(gStates.apocalypseDragonHeadLevels~=nil and gStates.apocalypseDragonHeadLevels[headName] or 0) or 0)>0 then liveHeads[#liveHeads+1]=headName end
	end
	for i=#liveHeads,2,-1 do
		local j=math.random(1,i)
		liveHeads[i],liveHeads[j]=liveHeads[j],liveHeads[i]
	end
	local recipient=#ordered
	for _,headName in ipairs(liveHeads) do
		local playerIndex=ordered[recipient]
		combat.assignments[playerIndex][#combat.assignments[playerIndex]+1]=headName
		recipient=recipient-1
		if recipient<1 then recipient=#ordered end
	end

	for _,playerIndex in ipairs(ordered) do
		apocalypseDragonGroundPrepareControl(combat,playerIndex,1,false)
		local slot=2
		for _,headName in ipairs(combat.assignments[playerIndex]) do
			if apocalypseDragonGroundPrepareColoredHead(combat,headName,playerIndex)==true then
				local headData=apocalypseDragonHeadData(headName)
				local token=headData~=nil and getObjectFromGUID(headData.tokenGUID) or nil
				local target=apocalypseDragonGroundTokenPosition(playerIndex,slot)
				if token~=nil and target~=nil then token.setPositionSmooth(target,false,true) end
				slot=slot+1
			end
		end
	end
	apocalypseDragonRefreshGroundAttackSuppression()
	for _,playerIndex in ipairs(ordered) do apocalypseDragonRefreshGroundFameGain(playerIndex) end
	return true
end

function apocalypseDragonFuryDefenseSetActivePlayer(playerIndex)
	local combat=gStates~=nil and gStates.apocalypseDragonGroundCombat or nil
	if combat==nil or combat.furyDefense~=true or combat.players[playerIndex]~=true or combat.finishedPlayers[playerIndex]==true then return false end
	combat.activePlayerIndex=playerIndex
	apocalypseDragonRefreshGroundAttackSuppression()
	apocalypseDragonRefreshGroundFameGain(playerIndex)
	combatCameraFocus(playerIndex)
	mainUIUpdate("Fury Dragon Defense")
	return true
end

function apocalypseDragonFuryDefenseFinishPlayer(playerIndex,fullAttend)
	local combat=gStates~=nil and gStates.apocalypseDragonGroundCombat or nil
	local details=turnOrder[playerIndex]
	if combat==nil or combat.furyDefense~=true or details==nil or combat.players[playerIndex]~=true or combat.finishedPlayers[playerIndex]==true then return false end
	for _,headName in ipairs(apocalypseDragonColoredHeads) do
		if combat.headOwners[headName]==playerIndex then
			local headData=apocalypseDragonHeadData(headName)
			local token=headData~=nil and getObjectFromGUID(headData.tokenGUID) or nil
			if token~=nil and combat.processedTokens[token.guid]~=true then apocalypseDragonGroundResolveToken(token) end
		end
	end
	local controls={}
	for guid,owner in pairs(combat.controlClones or {}) do if owner==playerIndex then controls[#controls+1]=guid end end
	for _,guid in ipairs(controls) do
		local token=getObjectFromGUID(guid)
		if token~=nil and combat.processedTokens[guid]~=true then apocalypseDragonGroundResolveToken(token) end
	end
	apocalypseDragonRefreshGroundFameGain(playerIndex)
	local dragonFame=tonumber(combat.previewFameByPlayer~=nil and combat.previewFameByPlayer[playerIndex] or 0) or 0
	if fullAttend~=true and dragonFame>0 then
		local pendingFame=tonumber(details.fameGain) or 0
		local otherFame=math.max(0,pendingFame-dragonFame)
		local oldRepGain=details.repGain or 0
		details.fameGain=dragonFame
		details.repGain=0
		applyPlayerFameReputation(playerIndex)
		details.fameGain=otherFame
		details.repGain=oldRepGain
	end
	combat.finishedPlayers[playerIndex]=true
	combat.activePlayerIndex=nil
	return true
end

function apocalypseDragonFinalizeFuryDefense()
	local combat=gStates~=nil and gStates.apocalypseDragonGroundCombat or nil
	if combat==nil or combat.furyDefense~=true or combat.finished==true then return false end
	combat.finished=true
	for headName,_ in pairs(combat.deployed or {}) do
		if headName~="Control" then
			local headData=apocalypseDragonHeadData(headName)
			local token=headData~=nil and getObjectFromGUID(headData.tokenGUID) or nil
			if token~=nil and combat.processedTokens[token.guid]~=true then
				combat.reductions[headName]=0
				token.UI.setXmlTable({{}})
				token.setRotation({0,180,0})
				local home=apocalypseDragonHeadTokenPosition(headData)
				if home~=nil then token.setPositionSmooth(home,false,true) end
			end
		end
	end
	apocalypseDragonGroundApplyFinalLevels(combat)
	combat.levelsApplied=true
	for playerIndex,fame in pairs(combat.fameByPlayer or {}) do
		if fame>0 and turnOrder[playerIndex]~=nil then
			broadcastToAll(joinLang({translateWord[turnOrder[playerIndex].mage] or tostring(turnOrder[playerIndex].mage),"{en} reduced the Apocalypse Dragon by {ru} снизил уровень Дракона Апокалипсиса суммарно на {zh-tw} 總共降低末日巨龍 {zh-cn} 总共降低末日巨龙 {ko}이(가) 아포칼립스 드래곤의 총 레벨을 {es} redujo al Dragón del Apocalipsis un total de {fr} a réduit le Dragon de l’Apocalypse de {pt-br} reduziu o Dragão do Apocalipse em um total de {de} hat den Apokalypse-Drachen insgesamt um ",tostring(fame),"{en} total level(s).{ru} уровней.{zh-tw} 個等級。{zh-cn} 个等级。{ko}만큼 낮췄습니다.{es} nivel(es).{fr} niveau(x) au total.{pt-br} nível(is).{de} Stufe(n)."}),positionToColor(playerIndex))
		end
	end
	apocalypseDragonGroundCleanupRuntime(combat)
	gStates.apocalypseDragonGroundCombat=nil
	apocalypseDragonCheckAndResolveDefeat()
	mainUIUpdate("Fury Dragon Defense Complete")
	return true
end

function apocalypseDragonDropScoringShield(playerIndex,position)
	local details=turnOrder[playerIndex]
	if details==nil or position==nil then return false end
	local mage=mageKnightsByName~=nil and mageKnightsByName[details.mage] or nil
	if mage==nil then
		for _,candidate in ipairs(mageKnights or {}) do if candidate.mage==details.mage then mage=candidate break end end
	end
	local bag=mage~=nil and mage.shieldContainer~=nil and getObjectFromGUID(mage.shieldContainer) or nil
	if bag==nil then return false end
	return bag.takeObject({position=position,smooth=false})~=nil
end

function apocalypseDragonGroundResolveToken(obj)
	local combat=gStates~=nil and gStates.apocalypseDragonGroundCombat or nil
	if combat==nil or obj==nil or combat.processedTokens[obj.guid]==true then return false end
	local active,headName,owner=apocalypseDragonGroundCombatToken(obj.guid)
	if active~=true or headName==nil or owner==nil then return false end
	combat.processedTokens=combat.processedTokens or {}
	combat.processedTokens[obj.guid]=true
	obj.UI.setXmlTable({{}})
	if headName=="Control" then
		local controlData=apocalypseDragonHeadData("Control")
		if controlData~=nil and obj.guid==controlData.tokenGUID then
			local home=apocalypseDragonHeadTokenPosition(controlData)
			obj.setLock(false)
			obj.setRotation({0,180,0})
			if home~=nil then obj.setPositionSmooth(home,false,true) end
		else
			--Do not destroy the clone while the normal end-turn loop still owns this userdata.
			--Move it out of the play area now, then clear the temporary monster registration next frame.
			local cloneGUID=obj.guid
			if combat.controlClones~=nil then combat.controlClones[cloneGUID]=nil end
			obj.setPosition({0,-20,0})
			safeWaitFrames("Scenario",function()
				local clone=getObjectFromGUID(cloneGUID)
				if clone~=nil then clone.destruct() end
				if gStates.monsterPerks~=nil then gStates.monsterPerks[cloneGUID]=nil end
				if gStates.summonStates~=nil then gStates.summonStates[cloneGUID]=nil end
				monsterPugs[cloneGUID]=nil
			end,1)
		end
		return true
	end

	if obj.is_face_down==false and apocalypseDragonGroundTokenInPlayerArea(obj.guid,owner)==true then
		local headLevels=gStates.apocalypseDragonHeadLevels or {}
		local current=tonumber(headLevels[headName]) or 0
		local reduction=math.min(current,apocalypseDragonGroundReduction(headName))
		combat.reductions=combat.reductions or {}
		combat.fameByPlayer=combat.fameByPlayer or {}
		combat.reductions[headName]=reduction
		combat.fameByPlayer[owner]=(combat.fameByPlayer[owner] or 0)+reduction
		local headData=apocalypseDragonHeadData(headName)
		local disc=headData~=nil and getObjectFromGUID(headData.guid) or nil
		if disc~=nil then
			for step=0,reduction-1 do
				local target=apocalypseDragonLevelMarkerPosition(disc,current-step)
				if target~=nil then apocalypseDragonDropScoringShield(owner,{target[1],2+(step*0.15),target[3]}) end
			end
		end
	else
		combat.reductions=combat.reductions or {}
		combat.reductions[headName]=0
	end
	local headData=apocalypseDragonHeadData(headName)
	local home=headData~=nil and apocalypseDragonHeadTokenPosition(headData) or nil
	obj.setLock(false)
	obj.setRotation({0,180,0})
	if home~=nil then obj.setPositionSmooth(home,false,true) end
	apocalypseDragonRefreshGroundAttackSuppression()
	return true
end

function apocalypseDragonGroundPlayerFinished(playerIndex)
	local combat=gStates~=nil and gStates.apocalypseDragonGroundCombat or nil
	if combat==nil or combat.coop~=true or combat.players[playerIndex]~=true then return false end
	combat.finishedPlayers[playerIndex]=true
	return true
end

apocalypseDragonGroundApplyFinalLevels=function(combat)
	for _,headName in ipairs(apocalypseDragonColoredHeads) do
		local reduction=tonumber(combat.reductions[headName]) or 0
		if reduction>0 then
			local current=tonumber(gStates.apocalypseDragonHeadLevels[headName]) or 0
			apocalypseDragonSetHeadLevel(headName,math.max(0,current-reduction))
		end
	end
	apocalypseDragonSyncControlLevel()
end

function apocalypseDragonGroundTryApplyLevelsBeforeRewards(playerIndex)
	local combat=gStates~=nil and gStates.apocalypseDragonGroundCombat or nil
	if combat==nil or combat.coop==true or combat.playerIndex~=playerIndex or combat.levelsApplied==true then return false end
	for headName,_ in pairs(combat.deployed or {}) do
		local headData=apocalypseDragonHeadData(headName)
		local guid=headData~=nil and headData.tokenGUID or nil
		if guid~=nil and (combat.processedTokens==nil or combat.processedTokens[guid]~=true) then return false end
	end
	combat.levelsApplied=true
	apocalypseDragonGroundApplyFinalLevels(combat)
	apocalypseDragonCheckAndResolveDefeat()
	mainUIUpdate("Apocalypse Dragon Levels Resolved")
	return true
end

apocalypseDragonGroundCleanupRuntime=function(combat)
	for guid,_ in pairs(combat.controlClones or {}) do
		local clone=getObjectFromGUID(guid)
		if clone~=nil then clone.destruct() end
		monsterPugs[guid]=nil
		if gStates.monsterPerks~=nil then gStates.monsterPerks[guid]=nil end
		if gStates.summonStates~=nil then gStates.summonStates[guid]=nil end
	end
	for _,headData in ipairs(apocalypseDragon.heads) do
		if gStates.summonStates~=nil then gStates.summonStates[headData.tokenGUID]=nil end
		if gStates.monsterPerks~=nil and gStates.monsterPerks[headData.tokenGUID]~=nil then
			gStates.monsterPerks[headData.tokenGUID].dragonGround=nil
			gStates.monsterPerks[headData.tokenGUID].dragonGroundLevel=nil
			gStates.monsterPerks[headData.tokenGUID].dragonLevelFame=nil
			gStates.monsterPerks[headData.tokenGUID].dragonControlBonus=nil
		end
		local token=getObjectFromGUID(headData.tokenGUID)
		local home=apocalypseDragonHeadTokenPosition(headData)
		if token~=nil then
			token.UI.setXmlTable({{}})
			token.setLock(false)
			token.setRotation({0,180,0})
			if home~=nil then
				local settlingHeadData=headData
				local tokenGUID=settlingHeadData.tokenGUID
				token.setPositionSmooth(home,false,true)
				safeWaitCondition("Scenario",function()
					local current=getObjectFromGUID(tokenGUID)
					if current~=nil then apocalypseDragonPositionHeadToken(settlingHeadData) end
				end,function()
					local current=getObjectFromGUID(tokenGUID)
					return current==nil or current.isSmoothMoving()==false
				end,5,function()
					local current=getObjectFromGUID(tokenGUID)
					if current~=nil then apocalypseDragonPositionHeadToken(settlingHeadData) end
				end)
			else
				token.setLock(true)
			end
		end
		gStates.monsterPlayLocation[headData.tokenGUID]=nil
		if gStates.attackedMonsters~=nil then gStates.attackedMonsters[headData.tokenGUID]=nil end
	end
	--Final levels were already applied before cleanup. Rebuild the normal head stats/perks once
	--without reloading every persistent token a second time.
	apocalypseDragonRefreshRuntimeData()
end

function apocalypseDragonFinalizeGroundCombat(playerIndex)
	local combat=gStates~=nil and gStates.apocalypseDragonGroundCombat or nil
	if combat==nil or combat.coop==true or combat.playerIndex~=playerIndex or combat.finished==true then return false end
	combat.finished=true
	for headName,_ in pairs(combat.deployed or {}) do
		local headData=apocalypseDragonHeadData(headName)
		local token=headData~=nil and getObjectFromGUID(headData.tokenGUID) or nil
		if token~=nil and combat.processedTokens[token.guid]~=true then apocalypseDragonGroundResolveToken(token) end
	end
	if combat.levelsApplied~=true then
		apocalypseDragonGroundApplyFinalLevels(combat)
		combat.levelsApplied=true
	end
	local fame=tonumber(combat.fameByPlayer[playerIndex]) or 0
	apocalypseDragonGroundCleanupRuntime(combat)
	gStates.apocalypseDragonGroundCombat=nil
	if fame>0 then broadcastToAll(joinLang({translateWord[turnOrder[playerIndex].mage] or tostring(turnOrder[playerIndex].mage),"{en} reduced the Apocalypse Dragon by {ru} снизил уровень Дракона Апокалипсиса суммарно на {zh-tw} 總共降低末日巨龍 {zh-cn} 总共降低末日巨龙 {ko}이(가) 아포칼립스 드래곤의 총 레벨을 {es} redujo al Dragón del Apocalipsis un total de {fr} a réduit le Dragon de l’Apocalypse de {pt-br} reduziu o Dragão do Apocalipse em um total de {de} hat den Apokalypse-Drachen insgesamt um ",tostring(fame),"{en} total level(s) and gains {ru} уровней и получает {zh-tw} 個等級，並獲得 {zh-cn} 个等级，并获得 {ko}만큼 낮추고 명성 {es} nivel(es) y gana {fr} niveau(x) au total et gagne {pt-br} nível(is) e ganha {de} Stufe(n) reduziert und erhält ",tostring(fame),"{en} Fame.{ru} Славы.{zh-tw} 聲望值。{zh-cn} 声望值。{ko}을(를) 얻습니다.{es} de Fama.{fr} de Renommée.{pt-br} de Fama.{de} Ruhm."}),positionToColor(playerIndex)) end
	apocalypseDragonCheckAndResolveDefeat()
	mainUIUpdate("Apocalypse Dragon Ground Combat Complete")
	return true
end

function finalizeCoopDragonCombat()
	local combat=gStates~=nil and gStates.apocalypseDragonGroundCombat or nil
	if combat==nil or combat.coop~=true or combat.finished==true then return false end
	combat.finished=true
	--All reductions should already have been recorded by each participant's normal combat cleanup.
	--If a persistent head token somehow escaped that cleanup, treat it as unreduced and return it home.
	for headName,_ in pairs(combat.deployed or {}) do
		if headName~="Control" then
			local headData=apocalypseDragonHeadData(headName)
			local token=headData~=nil and getObjectFromGUID(headData.tokenGUID) or nil
			if token~=nil and combat.processedTokens[token.guid]~=true then
				combat.reductions[headName]=0
				local home=apocalypseDragonHeadTokenPosition(headData)
				token.UI.setXmlTable({{}})
				token.setRotation({0,180,0})
				if home~=nil then token.setPositionSmooth(home,false,true) end
			end
		end
	end
	apocalypseDragonGroundApplyFinalLevels(combat)
	combat.levelsApplied=true
	--Dragon Fame was already in each player's fameGain when the co-op reward snapshot was made.
	for playerIndex,fame in pairs(combat.fameByPlayer or {}) do
		if fame>0 and turnOrder[playerIndex]~=nil then broadcastToAll(joinLang({translateWord[turnOrder[playerIndex].mage] or tostring(turnOrder[playerIndex].mage),"{en} reduced the Apocalypse Dragon by {ru} снизил уровень Дракона Апокалипсиса суммарно на {zh-tw} 總共降低末日巨龍 {zh-cn} 总共降低末日巨龙 {ko}이(가) 아포칼립스 드래곤의 총 레벨을 {es} redujo al Dragón del Apocalipsis un total de {fr} a réduit le Dragon de l’Apocalypse de {pt-br} reduziu o Dragão do Apocalipse em um total de {de} hat den Apokalypse-Drachen insgesamt um ",tostring(fame),"{en} total level(s) and will gain {ru} уровней и получит {zh-tw} 個等級，並將在合作獎勵階段獲得 {zh-cn} 个等级，并将在合作奖励阶段获得 {ko}만큼 낮추고 협동 보상 단계에서 명성 {es} nivel(es) y ganará {fr} niveau(x) au total et gagnera {pt-br} nível(is) e ganhará {de} Stufe(n) reduziert und erhält in der kooperativen Belohnungsphase ",tostring(fame),"{en} Fame in the cooperative reward phase.{ru} Славы на этапе совместной награды.{zh-tw} 聲望值。{zh-cn} 声望值。{ko}을(를) 얻습니다.{es} de Fama en la fase de recompensa cooperativa.{fr} de Renommée pendant la phase de récompense coopérative.{pt-br} de Fama na fase de recompensa cooperativa.{de} Ruhm."}),positionToColor(playerIndex)) end
	end
	apocalypseDragonGroundCleanupRuntime(combat)
	gStates.apocalypseDragonGroundCombat=nil
	apocalypseDragonCheckAndResolveDefeat()
	return true
end


function apocalypseDragonChoicePlayerIndex()
	local chosen=nil
	for index,details in ipairs(turnOrder or {}) do
		local human=details~=nil and (details.seatPos or 99)<=4 and details.mage~=gStates.positionMageKnight[5]
		if human==true and playerDropoutInactive(index)==false then
			if chosen==nil or (details.tactic or 99)<(turnOrder[chosen].tactic or 99) then chosen=index end
		end
	end
	return chosen
end

function apocalypseDragonChoicePlayerLabel(index)
	if index==nil or turnOrder[index]==nil then return "the player with the lowest-numbered Tactic" end
	local color=positionToColor(index)
	local mage=tostring(turnOrder[index].mage or "player")
	if color~=nil and color~="Black" then return color.." ("..mage..")" end
	return mage
end

function apocalypseDragonChoiceAuthorized(player,pending)
	if pending==nil then return false end
	local color=type(player)=="string" and player or (player~=nil and player.color or nil)
	local allowed=pending.playerIndex~=nil and positionToColor(pending.playerIndex) or nil
	if color=="Black" or color==allowed then return true end
	if color~=nil then
		broadcastToAll(joinLang({apocalypseDragonChoicePlayerLabel(pending.playerIndex),"{en} has the lowest-numbered Tactic and must make this Dragon choice. A player seated Black may also choose.{ru} имеет Тактику с наименьшим номером и должен сделать этот выбор Дракона. Игрок на чёрном месте также может выбрать.{zh-tw} 擁有編號最低的戰術，必須做出此巨龍選擇。坐在黑色席位的玩家也可以選擇。{zh-cn} 拥有编号最低的战术，必须做出此巨龙选择。坐在黑色席位的玩家也可以选择。{ko}이(가) 가장 낮은 번호의 전술을 가지고 있어 이 드래곤 선택을 해야 합니다. 검은색 자리에 앉은 플레이어도 선택할 수 있습니다.{es} tiene la Táctica con el número más bajo y debe realizar esta elección del Dragón. Un jugador sentado en Negro también puede elegir.{fr} possède la Tactique au numéro le plus bas et doit effectuer ce choix du Dragon. Un joueur assis en Noir peut également choisir.{pt-br} tem a Tática de menor número e deve fazer esta escolha do Dragão. Um jogador sentado no Preto também pode escolher.{de} hat die Taktik mit der niedrigsten Nummer und muss diese Drachenwahl treffen. Ein Spieler auf Schwarz darf ebenfalls wählen."}),warningColor)
	end
	return false
end

function positionApocalypseDragonHeads()
	if apocalypseDragonComponentsNeeded()~=true then return false end
	local moved=false
	for _,headData in ipairs(apocalypseDragon.heads) do
		local head=getObjectFromGUID(headData.guid)
		if head~=nil then
			local pos=head.getPosition()
			if math.abs(pos[1]-headData.position[1])>0.05 or math.abs(pos[3]-headData.position[3])>0.05 then
				head.setPositionSmooth(headData.position)
				moved=true
			end
			head.lock()
			if apocalypseDragonPositionHeadToken(headData)==true then moved=true end
		end
	end
	return moved
end

-- Shared interstitial Dragon-turn shell used by Against the Dragon and Fury.
function apocalypseDragonResetTurnRuntime()
	gStates.apocalypseDragonTurn=0
	gStates.apocalypseDragonTurnActive=false
	gStates.apocalypseDragonResumeTurn=nil
	gStates.apocalypseDragonPendingChoice=nil
	gStates.apocalypseDragonPendingAttack=nil
	gStates.apocalypseDragonFullAttendPlayer=nil
	gStates.apocalypseDragonUIState=nil
	gStates.apocalypseDragonTurnAction=nil
	gStates.apocalypseDragonTurnReport=nil
	gStates.apocalypseDragonTurnReportPrefix=nil
end

function apocalypseDragonBeginInterstitialTurn(nextTurnNumber,newOutOfTurn,sameTurn,action,report,source)
	gStates.apocalypseDragonTurnActive=true
	gStates.apocalypseDragonResumeTurn={turnNumber=nextTurnNumber,newOutOfTurn=newOutOfTurn==true,sameTurn=sameTurn==true}
	gStates.apocalypseDragonTurn=(gStates.apocalypseDragonTurn or 0)+1
	local dragonTurn=gStates.apocalypseDragonTurn
	local resolvedAction=type(action)=="function" and action(dragonTurn) or action
	gStates.apocalypseDragonTurnAction=resolvedAction
	gStates.apocalypseDragonUIState="ReadyToProcess"
	gStates.apocalypseDragonTurnReportPrefix=nil
	gStates.apocalypseDragonTurnReport=type(report)=="function" and report(dragonTurn,resolvedAction) or report
	apocalypseDragonMainUIRefresh()
	mainUIUpdate(source)
	return true
end

function apocalypseDragonCompleteInterstitialTurn(text,source,clearPending)
	if clearPending==true then
		gStates.apocalypseDragonPendingChoice=nil
		gStates.apocalypseDragonPendingAttack=nil
		gStates.apocalypseDragonTurnAction=nil
	end
	gStates.apocalypseDragonUIState="ReadyToEnd"
	if text~=nil then
		gStates.apocalypseDragonTurnReport=text
	elseif gStates.apocalypseDragonTurnReport==nil or gStates.apocalypseDragonTurnReport=="" then
		gStates.apocalypseDragonTurnReport="The Apocalypse Dragon finished its turn."
	end
	apocalypseDragonMainUIRefresh()
	mainUIUpdate(source)
	return true
end

function apocalypseDragonTurnOrdinal(turnNumber)
	local n=tonumber(turnNumber) or 1
	if n==1 then return "1st" end
	if n==2 then return "2nd" end
	if n==3 then return "3rd" end
	if n==4 then return "4th" end
	return tostring(n).."th"
end

function apocalypseDragonMainUIPanelSpec()
	if gStates==nil or gStates.apocalypseDragonTurnActive~=true then return nil end
	local pending=gStates.apocalypseDragonPendingAttack
	local turnNumber=tonumber(gStates.apocalypseDragonTurn) or 1
	local mainText=joinLang({"{en}<size=25>Apocalypse Dragon's Turn</size><size=6>\n\n</size><size=18>Round {ru}<size=25>Ход Дракона Апокалипсиса</size><size=6>\n\n</size><size=18>Раунд {zh-tw}<size=25>末日巨龍回合</size><size=6>\n\n</size><size=18>回合輪 {zh-cn}<size=25>末日巨龙回合</size><size=6>\n\n</size><size=18>回合轮 {ko}<size=25>아포칼립스 드래곤의 턴</size><size=6>\n\n</size><size=18>라운드 {es}<size=25>Turno del Dragón del Apocalipsis</size><size=6>\n\n</size><size=18>Ronda {fr}<size=25>Tour du Dragon de l'Apocalypse</size><size=6>\n\n</size><size=18>Manche {pt-br}<size=25>Turno do Dragão do Apocalipse</size><size=6>\n\n</size><size=18>Rodada {de}<size=25>Zug des Apokalypse-Drachen</size><size=6>\n\n</size><size=18>Runde ",tostring(gStates.currentRound or 1),"{en} - Dragon turn {ru} — ход Дракона {zh-tw}－巨龍回合 {zh-cn}－巨龙回合 {ko} - 드래곤 턴 {es} - turno del Dragón {fr} - tour du Dragon {pt-br} - turno do Dragão {de} - Drachenzug ",tostring(turnNumber),"</size><size=4>\n</size>"})
	if pending~=nil then
		if pending.phase=="choose" then
			return {actor="dragon",mainText=mainText,notes=gStates.apocalypseDragonTurnReport or "Resolve the Apocalypse Dragon attack.",onClick="apocalypseDragonProcessUI",label="{en}Resolve Dragon Attack{ru}Разрешите атаку Дракона{zh-tw}處理巨龍攻擊{zh-cn}处理巨龙攻击{ko}드래곤 공격 해결{es}Resolver Ataque del Dragón{fr}Résoudre l'Attaque du Dragon{pt-br}Resolver Ataque do Dragão{de}Drachenangriff abhandeln",interactable=false,responseSpec=againstDragonAttendanceResponseSpec()}
		end
		return {actor="dragon",panelActive=false}
	end
	local state=gStates.apocalypseDragonUIState
	local label="{en}Processing Dragon...{ru}Дракон действует...{zh-tw}巨龍行動處理中...{zh-cn}巨龙行动处理中...{ko}드래곤 처리 중...{es}Procesando Dragón...{fr}Traitement du Dragon...{pt-br}Processando Dragão...{de}Drache wird verarbeitet..."
	local active=false
	if state=="ReadyToProcess" then label="{en}Process Dragon{ru}Ход Дракона{zh-tw}執行巨龍行動{zh-cn}执行巨龙行动{ko}드래곤 진행{es}Procesar Dragón{fr}Traiter le Dragon{pt-br}Processar Dragão{de}Drache aktivieren" active=true
	elseif state=="ReadyToEnd" then label="{en}Dragon Processed{ru}Дракон обработан{zh-tw}巨龍行動結束{zh-cn}巨龙行动结束{ko}드래곤 처리 완료{es}Dragón Procesado{fr}Dragon traité{pt-br}Dragão Processado{de}Drache verarbeitet" active=true
	elseif state=="WaitingChoice" then label="{en}Pick Target{ru}Выберите цель{zh-tw}選擇目標{zh-cn}选择目标{ko}대상 선택{es}Elige Objetivo{fr}Choisir la Cible{pt-br}Escolha o Alvo{de}Ziel wählen"
	elseif state=="WaitingCombat" then label="{en}Combat Resolved{ru}Бой завершён{zh-tw}戰鬥已解決{zh-cn}战斗已解决{ko}전투 해결 완료{es}Combate resuelto{fr}Combat résolu{pt-br}Combate resolvido{de}Kampf beendet" active=true end
	return {actor="dragon",mainText=mainText,notes=gStates.apocalypseDragonTurnReport or joinLang({"{en}The Apocalypse Dragon is preparing for turn {ru}Дракон Апокалипсиса готовится к ходу {zh-tw}末日巨龍正在準備第 {zh-cn}末日巨龙正在准备第 {ko}아포칼립스 드래곤이 {es}El Dragón del Apocalipsis prepara el turno {fr}Le Dragon de l’Apocalypse prépare le tour {pt-br}O Dragão do Apocalipse está preparando o turno {de}Der Apokalypse-Drache bereitet Zug ",tostring(turnNumber),"{en}.{ru}.{zh-tw} 個回合。{zh-cn} 个回合。{ko}번째 턴을 준비하고 있습니다.{es}.{fr}.{pt-br}.{de} vor."}),onClick="apocalypseDragonProcessUI",label=label,interactable=active}
end

function apocalypseDragonMainUIRefresh()
	local spec=apocalypseDragonMainUIPanelSpec()
	if spec==nil then return false end
	return automatedMainPanelApply(spec)
end

function apocalypseDragonProcessUI(player,mouseButton,id)
	if mouseButton~="-1" or gStates==nil or gStates.apocalypseDragonTurnActive~=true then return end
	local state=gStates.apocalypseDragonUIState
	if state=="ReadyToEnd" then
		apocalypseDragonFinishTurn()
		return
	end
	if furyDragonIsActive~=nil and furyDragonIsActive()==true then
		furyDragonProcessTurn()
		return
	end
	if state~="ReadyToProcess" then return end
	local action=gStates.apocalypseDragonTurnAction
	gStates.apocalypseDragonTurnReportPrefix=nil
	if action=="attack" then
		againstDragonSetTurnReport("The Apocalypse Dragon is determining which player to attack.","Processing")
		againstDragonBeginAttack()
	elseif action=="destroy" then
		againstDragonSetTurnReport("The Apocalypse Dragon is determining what it will destroy.","Processing")
		againstDragonBeginDestroy()
	else
		local ordinal=apocalypseDragonTurnOrdinal(gStates.apocalypseDragonTurn)
		againstDragonSetTurnReport("The Apocalypse Dragon took no action on its "..ordinal.." turn.","Processing")
		safeWaitFrames("Scenario",function() againstDragonCompleteTurn() end,1)
	end
end

function apocalypseDragonFinishTurn(force)
	if gStates==nil or gStates.apocalypseDragonTurnActive~=true then return false end
	if force~=true and gStates.apocalypseDragonUIState~="ReadyToEnd" then return false end
	apocalypseDragonTurnChoiceClearButtons()
	againstDragonAttackControlUI(false)
	UI.setAttribute("DummyTurn","active","false")
	automatedAttackResponseUI(nil)
	gStates.apocalypseDragonTurnActive=false
	local resume=gStates.apocalypseDragonResumeTurn
	local fullAttendPlayer=gStates.apocalypseDragonFullAttendPlayer
	local furyFullAttendPlayers=gStates.furyDragonFullAttendPlayers or {}
	gStates.apocalypseDragonResumeTurn=nil
	gStates.apocalypseDragonPendingChoice=nil
	gStates.apocalypseDragonPendingAttack=nil
	gStates.apocalypseDragonFullAttendPlayer=nil
	gStates.furyDragonFullAttendPlayers={}
	gStates.apocalypseDragonUIState=nil
	gStates.apocalypseDragonTurnAction=nil
	gStates.apocalypseDragonTurnReport=nil
	gStates.apocalypseDragonTurnReportPrefix=nil
	if resume~=nil and mergedTurnCommit~=nil then
		local resumeTurn=resume.turnNumber
		local resumeFullyAttended=(fullAttendPlayer~=nil and resumeTurn==fullAttendPlayer) or furyFullAttendPlayers[resumeTurn]==true
		if resumeFullyAttended==true and gStates.skipTurn[resumeTurn]==true then
			gStates.skipTurn[resumeTurn]=nil
			local skipped=turnOrder[resumeTurn]
			local token=skipped~=nil and getObjectFromGUID(skipped.turnOrderTokenGUID) or nil
			if token~=nil and token.is_face_down==true then token.flip() end
			if skipped~=nil then broadcastToAll(joinLang({translateWord[skipped.mage] or tostring(skipped.mage),"{en} skips their normal turn because they fully attended the Dragon attack.{ru} пропускает обычный ход, потому что полностью участвовал в атаке Дракона.{zh-tw} 因完全參與巨龍攻擊而跳過正常回合。{zh-cn} 因完全参与巨龙攻击而跳过正常回合。{ko}은(는) 드래곤 공격에 완전히 참가했으므로 일반 턴을 건너뜁니다.{es} se salta su turno normal porque participó por completo en el ataque del Dragón.{fr} saute son tour normal car il a pleinement participé à l’attaque du Dragon.{pt-br} pula seu turno normal porque participou completamente do ataque do Dragão.{de} überspringt den normalen Zug, weil vollständig am Drachenangriff teilgenommen wurde."}),positionToColor(resumeTurn)) end
			for _=1,#turnOrder do
				resumeTurn=resumeTurn+1
				if resumeTurn>#turnOrder then resumeTurn=1 end
				if playerDropoutInactive(resumeTurn)==false then
					if gStates.skipTurn[resumeTurn]==true then
						gStates.skipTurn[resumeTurn]=nil
						local skippedDetails=turnOrder[resumeTurn]
						local skippedToken=skippedDetails~=nil and getObjectFromGUID(skippedDetails.turnOrderTokenGUID) or nil
						if skippedToken~=nil and skippedToken.is_face_down==true then skippedToken.flip() end
						if skippedDetails~=nil then broadcastToAll(joinLang({translateWord[skippedDetails.mage] or tostring(skippedDetails.mage),"{en} skips their turn. They already played out of order.{ru} пропускает ход: он уже сыграл вне очереди.{zh-tw} 跳過回合，因為已經提前行動過。{zh-cn} 跳过回合，因为已经提前行动过。{ko}은(는) 이미 순서를 벗어나 턴을 진행했으므로 이번 턴을 건너뜁니다.{es} se salta su turno. Ya jugó fuera de orden.{fr} saute son tour. Il a déjà joué hors ordre.{pt-br} pula seu turno. Já jogou fora de ordem.{de} überspringt den Zug. Es wurde bereits außerhalb der Reihenfolge gespielt."}),positionToColor(resumeTurn)) end
					else
						break
					end
				end
			end
		end
		mergedTurnCommit(resumeTurn,resume.newOutOfTurn,resume.sameTurn)
	else
		mainUIUpdate("Dragon Turn Complete")
	end
	return true
end

function apocalypseDragonTurnChoiceClearButtons()
	againstDragonTargetChoiceClearButtons()
	againstDragonOffMapChoiceClearButtons()
end

-- Public UI callback ownership: publish protected TTS/XML entry points from the module that implements them.
publishPublicUICallbacks({
	apocalypseDragonGroundReductionAdjust=apocalypseDragonGroundReductionAdjust,
	apocalypseDragonProcessUI=apocalypseDragonProcessUI
})

-- Apocalypse Proxy Player runtime.

--Apocalypse Dragon Proxy Player variant. It shares the normal Dummy deck/tactic machinery, but keeps its Hero on the map and resolves its turn visibly.
proxyStandardBasicNames={Stamina=true,Determination=true,Crystallize=true,March=true,Tranquility=true,Concentration=true,Swiftness=true,["Mana Draw"]=true,Promise=true,Improvisation=true,Threaten=true,Rage=true}

function proxyPlayerActive()
	return gStates~=nil and gStates.proxyPlayer==true and gStates.positionMageKnight~=nil and gStates.positionMageKnight[5]~=nil and gStates.positionMageKnight[5]~="nobody" and gStates.positionMageKnight[5]~="Volkare"
end

function automatedPlayerTurnFunction()
	if gStates.positionMageKnight[5]=="Volkare" then return "volkareTurn" end
	if proxyPlayerActive()==true then return "proxyTurn" end
	return "dummyTurn"
end

function refreshProxySetupLabel()
	if gStates==nil or gStates.positionMageKnight==nil or gStates.positionMageKnight[5]=="Volkare" then return end
	if gStates.proxyPlayer==true then
		UI.setAttribute("DummyPosText","text","{en}Proxy Mage Knight -{ru}Прокси Рыцарь-маг -{zh-tw}代理魔法騎士：{zh-cn}代理魔法骑士：{ko}프록시 메이지 나이트 -{es}Mage Knight Proxy -{fr}Mage Knight Proxy -{pt-br}Mage Knight Proxy -{de}Proxy-Magier-Ritter -")
	else
		UI.setAttribute("DummyPosText","text","{en}Dummy Mage Knight -{ru}Виртуальный Рыцарь-маг -{zh-tw}虛擬玩家：{zh-cn}虚拟玩家：{ko}가상 플레이어 -{es}Mage Knight Virtual -{fr}Mage fantôme -{pt-br}Mage Knight Fictício -{de}Dummy-Magier-Ritter -")
	end
end

--Deploy the two Apocalypse Proxy reference cards relative to the live Dummy board so they follow
--whichever setup slot the Proxy actually occupies.
function proxySetupReferenceCards()
	if proxyPlayerActive()~=true then return end
	local board=getObjectFromGUID(dummyBoard)
	local bag=getObjectFromGUID(GUID.bag.apocalypseDragon)
	if board==nil or bag==nil then return end
	local p=board.getPosition()
	safeTakeObject("AI.Proxy",bag,{guid="0e855c",position={p[1]+9.44,p[2],p[3]-5.17},rotation={0,180,0},smooth=false,callback_function=function(obj) obj.lock() end})
	safeTakeObject("AI.Proxy",bag,{guid="dbf566",position={p[1]+12.91,p[2],p[3]-5.17},rotation={0,180,0},smooth=false,callback_function=function(obj) obj.lock() end})
end

function proxySetupAvatarPosition()
	--The Proxy borrows an unused normal player parking slot so the ordinary Portal/City swap
	--machinery can treat them like a Mage Knight. In a four-human game there is no spare slot.
	local portalPositionBySeat={
		[1]={-45.5,1.3,-11.4},
		[2]={-42.5,1.3,-11.4},
		[3]={-45.5,1.3,-13.2},
		[4]={-42.5,1.3,-13.2}}
	gStates.proxyParkingSeat=nil
	for seat=1,4 do
		if gStates.positionMageKnight[seat]==nil or gStates.positionMageKnight[seat]=="nobody" then
			gStates.proxyParkingSeat=seat
			return portalPositionBySeat[seat],true
		end
	end
	local board=getObjectFromGUID(dummyBoard)
	if board~=nil then local p=board.getPosition() return {p[1],1.4,p[3]},false end
	return {-43.94,1.4,-12.36},false
end

function proxyMageDetails()
	if proxyPlayerActive()~=true then return nil end
	for _,details in ipairs(mageKnights or {}) do
		if details.mage==gStates.positionMageKnight[5] then return details end
	end
	return nil
end

--Preserve the Proxy's infinite Shield bag before playerSetup removes unused player-position pieces.
--Normally the live source can simply be cloned. If that source is already inside its Mage component bag,
--clone the component bag and extract the same contained index without altering the master setup bag.
function proxyStageShieldBag()
	if proxyPlayerActive()~=true then return nil end
	if gStates.proxyShieldBagGUID~=nil then
		local existing=getObjectFromGUID(gStates.proxyShieldBagGUID)
		if existing~=nil then return existing end
		gStates.proxyShieldBagGUID=nil
	end
	local details=proxyMageDetails()
	if details==nil then return nil end
	local bag=nil
	local source=details.shieldContainer~=nil and getObjectFromGUID(details.shieldContainer) or nil
	if source~=nil then
		bag=source.clone()
	else
		local component=details.bag~=nil and getObjectFromGUID(details.bag) or nil
		if component~=nil then
			local sourceIndex=nil
			for _,entry in ipairs(component.getObjects()) do
				if entry.guid==details.shieldContainer then sourceIndex=entry.index break end
			end
			if sourceIndex~=nil then
				local componentCopy=component.clone()
				if componentCopy~=nil then
					componentCopy.setPosition({0,-20,0})
					bag=componentCopy.takeObject({index=sourceIndex,position={0,-20,0},rotation={0,180,0},smooth=false})
					componentCopy.destruct()
				end
			end
		end
	end
	if bag==nil then return nil end
	bag.setPosition({0,-20,0})
	bag.setRotation({0,180,0})
	bag.lock()
	gStates.proxyShieldBagGUID=bag.guid
	return bag
end

function proxySetupShieldBag()
	if proxyPlayerActive()~=true then return nil end
	local bag=nil
	if gStates.proxyShieldBagGUID~=nil then bag=getObjectFromGUID(gStates.proxyShieldBagGUID) end
	if bag==nil then bag=proxyStageShieldBag() end
	if bag==nil then return nil end

	--Keep the Proxy Shield supply in the same place relative to whichever player slot owns the Dummy board.
	local board=getObjectFromGUID(dummyBoard)
	if board==nil then return bag end
	local p=board.getPosition()
	bag.setPosition({p[1]-5.62,p[2]+0.16,p[3]+4.47})
	bag.setRotation({0,180,0})
	bag.lock()
	return bag
end
function proxyPlayerIndex()
	if proxyPlayerActive()~=true then return nil end
	for a,details in ipairs(turnOrder or {}) do if details.mage==gStates.positionMageKnight[5] then return a end end
	return nil
end

function proxyAvatarObject()
	if proxyPlayerActive()~=true then return nil end
	for _,details in ipairs(mageKnights or {}) do
		if details.mage==gStates.positionMageKnight[5] then
			local obj=nil
			if details.model~=nil then obj=getObjectFromGUID(details.model) end
			if obj==nil and details.token~=nil then obj=getObjectFromGUID(details.token) end
			if obj==nil and details.standee~=nil then obj=getObjectFromGUID(details.standee) end
			return obj
		end
	end
	return nil
end

function proxyShieldContainer()
	if proxyPlayerActive()~=true then return nil end
	if gStates.proxyShieldBagGUID~=nil then
		local bag=getObjectFromGUID(gStates.proxyShieldBagGUID)
		if bag~=nil then return bag end
	end
	return proxySetupShieldBag()
end

function proxyObjectivePosition()
	local board=getObjectFromGUID(dummyBoard)
	if board==nil then return {-90,1.4,-20} end
	local pos=board.getPosition()
	return {pos[1]+5.1,1.35,pos[3]+0.7}
end

function proxyObjectiveObject()
	return gStates.proxyObjectiveGUID~=nil and getObjectFromGUID(gStates.proxyObjectiveGUID) or nil
end

function proxyDrawObjective(seatPos)
	local zone=getObjectFromGUID(deedDeckZones[seatPos])
	if zone==nil then return nil end
	local pile=nil
	for _,obj in pairs(zone.getObjects()) do if obj.type=="Deck" or obj.type=="Card" then pile=obj break end end
	if pile==nil then return nil end
	local pos=proxyObjectivePosition()
	local card=nil
	if pile.type=="Card" then
		card=pile
		card.unlock()
		card.setPositionSmooth(pos)
		card.setRotationSmooth({0,180,0})
	else
		card=pile.takeObject({position=pos,rotation={0,180,0},smooth=true})
	end
	if card~=nil then
		gStates.proxyObjectiveGUID=card.guid
		gStates.proxyObjectiveShieldGUIDs={}
		local objectiveName=card.getName()
		if gameCards[card.guid]~=nil and gameCards[card.guid].name~=nil then objectiveName=type(gameCards[card.guid].name)=="table" and gameCards[card.guid].name[1] or gameCards[card.guid].name end
		broadcastToAll(joinLang({"{en}Proxy objective: {ru}Цель прокси: {zh-tw}代理目標：{zh-cn}代理目标：{ko}프록시 목표: {es}Objetivo del Proxy: {fr}Objectif du Proxy : {pt-br}Objetivo do Proxy: {de}Proxy-Ziel: ",objectiveName}),{1,0.75,0.2})
	end
	return card
end

function proxyAddObjectiveShield()
	local objective=proxyObjectiveObject()
	local bag=proxyShieldContainer()
	if objective==nil or bag==nil then return nil end
	if gStates.proxyObjectiveShieldGUIDs==nil then gStates.proxyObjectiveShieldGUIDs={} end
	local pos=objective.getPosition()
	local count=#gStates.proxyObjectiveShieldGUIDs
	local shield=bag.takeObject({position={pos[1]-0.65+(0.43*count),pos[2]+0.22,pos[3]+1.15},rotation={0,180,0},smooth=false})
	if shield~=nil then proxyLockShieldWhenResting(shield) gStates.proxyObjectiveShieldGUIDs[#gStates.proxyObjectiveShieldGUIDs+1]=shield.guid end
	return shield
end

function proxySendObjectiveToDiscard()
	local objective=proxyObjectiveObject()
	if objective==nil then gStates.proxyObjectiveGUID=nil return end
	objective.unlock()
	local proxyIndex=proxyPlayerIndex()
	local seat=(proxyIndex~=nil and turnOrder[proxyIndex]~=nil and turnOrder[proxyIndex].seatPos) or 5
	local zone=getObjectFromGUID(deedDeckDiscardZones[seat])
	if zone~=nil then
		local pile=nil
		for _,obj in pairs(zone.getObjects()) do if obj.type=="Deck" then pile=obj break end end
		if pile~=nil then pile.putObject(objective)
		else local p=zone.getPosition() objective.setPosition({p[1],p[2]+1.2,p[3]}) objective.setRotation({0,180,0}) end
	else objective.setPosition({-95,1,-30}) end
	gStates.proxyObjectiveGUID=nil
end

function proxyClearObjective(sendToDiscard)
	for _,guid in ipairs(gStates.proxyObjectiveShieldGUIDs or {}) do local shield=getObjectFromGUID(guid) if shield~=nil then shield.destruct() end end
	gStates.proxyObjectiveShieldGUIDs={}
	if sendToDiscard==true then proxySendObjectiveToDiscard() else gStates.proxyObjectiveGUID=nil end
end

function proxySnapshotCrystals(stats)
	local result={Red=0,White=0,Green=0,Blue=0}
	if stats==nil then return result end
	local zone=getObjectFromGUID(playerCrystalAreas[stats.seatPos])
	if zone~=nil then
		for _,obj in pairs(zone.getObjects()) do
			if obj.getName()=="Red Mana" or obj.getName()=="Blue Mana" or obj.getName()=="Green Mana" or obj.getName()=="White Mana" then
				local color=obj.getDescription()
				if result[color]~=nil then result[color]=result[color]+1 end
			end
		end
	end
	stats.dummyCrystals={Red=result.Red,White=result.White,Green=result.Green,Blue=result.Blue}
	return result
end

function proxyObjectiveBaseMove(card)
	if card==nil then return 1 end
	if gameCardType(card)=="Advanced Action" then return 2 end
	if gameCardType(card)=="Starting" and gameCards[card.guid]~=nil then
		local name=gameCards[card.guid].name
		if type(name)=="table" then name=name[1] end
		if name~=nil and proxyStandardBasicNames[name]~=true then return 2 end
	end
	return 1
end

function proxySourceManaOptions(colors)
	local zone=getObjectFromGUID(GUID.zone.mana)
	if zone==nil then return {},nil end
	local wanted={}
	local order={}
	for _,color in ipairs(colors or {}) do
		if wanted[color]~=true then wanted[color]=true order[#order+1]=color end
	end
	local exactByColor={}
	local gold=nil
	for _,die in pairs(zone.getObjects()) do
		if die.getName()=="Mana Dice" then
			local color=apocalypseQuestManaDieColor(die)
			if color~=nil and wanted[color]==true and exactByColor[color]==nil then exactByColor[color]=die.guid end
			if color=="Gold" and gStates.dayRound==true and gold==nil then gold=die.guid end
		end
	end
	local exact={}
	for _,color in ipairs(order) do if exactByColor[color]~=nil then exact[#exact+1]={color=color,guid=exactByColor[color]} end end
	return exact,gold
end

function proxyRerollSourceManaGUID(guid,color)
	local die=guid~=nil and getObjectFromGUID(guid) or nil
	if die==nil and color~=nil then
		local zone=getObjectFromGUID(GUID.zone.mana)
		if zone~=nil then
			for _,candidate in pairs(zone.getObjects()) do
				if candidate.getName()=="Mana Dice" and apocalypseQuestManaDieColor(candidate)==color then die=candidate break end
			end
		end
	end
	if die==nil then return false end
	die.randomize()
	onObjectRandomize({type="Dice"})
	return true
end

function proxyUseSourceMana(colors,selectedColor)
	local exact,gold=proxySourceManaOptions(colors)
	if selectedColor~=nil then
		for _,option in ipairs(exact) do if option.color==selectedColor then return proxyRerollSourceManaGUID(option.guid,option.color),nil end end
		return false,nil
	end
	if #exact>1 then return nil,exact end
	if #exact==1 then return proxyRerollSourceManaGUID(exact[1].guid,exact[1].color),nil end
	if gold~=nil then return proxyRerollSourceManaGUID(gold,"Gold"),nil end
	return false,nil
end

function proxyHexHasOtherHero(hex,proxyIndex)
	if hex==nil then return false end
	--The Portal is the one space multiple Mage Knights may share. In Volkare's Quest it only becomes
	--an ordinary one-Mage-Knight space after the Council closes it. Do not let a human still standing
	--on the open starting Portal make the Proxy's first-turn distance map empty.
	local feature=string.lower(tostring(hex.feature or ""))
	if feature=="portal" and not (gStates.gameScenario=="Volkare's Quest" and gStates.volkarePortalClosed==true) then return false end
	for a,details in ipairs(turnOrder or {}) do
		if a~=proxyIndex and details.mage~=gStates.positionMageKnight[5] and details.dropoutState==nil then
			local pos=nil
			if fracturedLandsTeleportSourcePosition~=nil then pos=fracturedLandsTeleportSourcePosition(a) end
			if pos~=nil then
				local dx=pos[1]-hex.position[1]
				local dz=pos[3]-hex.position[3]
				if (dx*dx)+(dz*dz)<1 then return true end
			end
		end
	end
	return false
end

function proxyHexPassable(hex,proxyIndex)
	if hex==nil or hex.hexType=="lake" or hex.hexType=="mountain" or hex.hexType=="ocean" then return false end
	return proxyHexHasOtherHero(hex,proxyIndex)~=true
end

function proxyRouteTopology(hexes,proxyIndex)
	local context={byKey={},neighbors={},neighborSet={},passable={}}
	local snapshot=runtimeMapSnapshot()
	local useCachedTopology=hexes==snapshot.hexes
	for _,hex in ipairs(hexes or {}) do
		local key=runtimeMapHexKey(hex)
		if key~=nil then
			context.byKey[key]=hex
			context.passable[key]=proxyHexPassable(hex,proxyIndex)==true
			if useCachedTopology==true then
				context.neighbors[key]=snapshot.neighbors[key] or {}
				context.neighborSet[key]=snapshot.neighborSet[key] or {}
			else
				context.neighbors[key]={}
				context.neighborSet[key]={}
			end
		end
	end
	if useCachedTopology~=true then
		for a=1,#(hexes or {}) do
			local first=hexes[a]
			local firstKey=runtimeMapHexKey(first)
			if firstKey~=nil then
				for b=a+1,#hexes do
					local second=hexes[b]
					local secondKey=runtimeMapHexKey(second)
					if secondKey~=nil and runtimeMapHexesAdjacent(first,second)==true then
						context.neighbors[firstKey][#context.neighbors[firstKey]+1]=second
						context.neighbors[secondKey][#context.neighbors[secondKey]+1]=first
						context.neighborSet[firstKey][secondKey]=true
						context.neighborSet[secondKey][firstKey]=true
					end
				end
			end
		end
	end
	return context
end

function proxyDistanceMap(hexes,starts,proxyIndex,context)
	context=context or proxyRouteTopology(hexes,proxyIndex)
	local distances={}
	local queue={}
	for _,hex in ipairs(starts or {}) do
		local key=runtimeMapHexKey(hex)
		if key~=nil and distances[key]==nil and context.passable[key]==true then distances[key]=0 queue[#queue+1]=hex end
	end
	local head=1
	while queue[head]~=nil do
		local current=queue[head] head=head+1
		local currentKey=runtimeMapHexKey(current)
		local currentDistance=distances[currentKey] or 0
		for _,candidate in ipairs(context.neighbors[currentKey] or {}) do
			local key=runtimeMapHexKey(candidate)
			if key~=nil and distances[key]==nil and context.passable[key]==true then
				distances[key]=currentDistance+1 queue[#queue+1]=candidate
			end
		end
	end
	return distances
end

function proxyCityGUIDForHex(hex)
	if hex==nil then return nil end
	for cityGUID,data in pairs(gStates.cityMonsterQty or {}) do
		if data.extra~=nil and data.extra.terainGUID==hex.terrainGUID then return cityGUID end
	end
	return nil
end

function proxyCityAliveEnemies(cityGUID)
	local result={}
	local data=cityGUID~=nil and gStates.cityMonsterQty[cityGUID] or nil
	if data~=nil then for guid,state in pairs(data) do if guid~="extra" and state=="alive" then result[#result+1]=guid end end end
	return result
end

function proxyFortifiedType(hex,mapObjects,proxyIndex)
	if hex==nil then return nil end
	local feature=string.lower(tostring(hex.feature or ""))
	if feature=="destroyed" or feature:sub(1,7)=="raised " then return nil end
	if apocalypseQuestFeatureIsCity(feature)==true then
		local cityGUID=proxyCityGUIDForHex(hex)
		if cityGUID~=nil and #proxyCityAliveEnemies(cityGUID)>0 then return "city" end
		return nil
	end
	if feature=="keep" then if apocalypseQuestHexHasShield(hex,mapObjects,proxyIndex,false)==true then return nil end return "keep" end
	if feature=="mage tower" then if apocalypseQuestHexHasShield(hex,mapObjects,proxyIndex,true)==true then return nil end return "mage tower" end
	return nil
end

function proxyFeatureRecruitKey(feature)
	local value=string.lower(tostring(feature or ""))
	if apocalypseQuestFeatureIsCity(value)==true then return "city" end
	if value=="volkare's camp" then return "camp" end
	return value
end

function proxyInteractionOfferCache(crystals)
	local cache={}
	local unitZone=getObjectFromGUID("a3d99b")
	if unitZone~=nil then
		for _,card in pairs(unitZone.getObjects()) do
			local data=gameCards[card.guid]
			if card.type=="Card" and data~=nil then
				if (data.cardType=="Regular Unit" or data.cardType=="Elite Unit") and data.recruit~=nil then
					for _,site in ipairs(data.recruit) do
						local feature=string.lower(site)
						if cache[feature]==nil then cache[feature]={} end
						cache[feature][#cache[feature]+1]={kind="unit",card=card,cost=data.influence or 99}
					end
				elseif data.cardType=="Advanced Action" then
					if cache.monastery==nil then cache.monastery={} end
					cache.monastery[#cache.monastery+1]={kind="action",card=card,cost=6}
				end
			end
		end
	end
	local card=mainOfferFirstCard("Spell")
	if card~=nil then
		for _,color in ipairs(dummyCardColors(card)) do
			if (crystals[color] or 0)>0 then
				if cache["mage tower"]==nil then cache["mage tower"]={} end
				cache["mage tower"][#cache["mage tower"]+1]={kind="spell",card=card,cost=7}
				break
			end
		end
	end
	for _,options in pairs(cache) do
		table.sort(options,function(a,b) if a.cost~=b.cost then return a.cost<b.cost end if a.kind==b.kind then return a.card.guid<b.card.guid end return a.kind=="unit" end)
	end
	return cache
end

function proxyInteractionOptions(hex,mapObjects,proxyIndex,crystals,offerCache)
	local options={}
	if hex==nil or string.lower(tostring(hex.feature or ""))=="destroyed" then return options end
	local feature=proxyFeatureRecruitKey(hex.feature)
	if feature=="monastery" and gStates.monasteryBurned~=nil and gStates.monasteryBurned[hex.terrainGUID]==true then return options end
	if feature=="keep" and apocalypseQuestHexHasShield(hex,mapObjects,proxyIndex,false)~=true then return options end
	if feature=="mage tower" and apocalypseQuestHexHasShield(hex,mapObjects,proxyIndex,true)~=true then return options end
	if feature=="city" then local city=proxyCityGUIDForHex(hex) if city~=nil and #proxyCityAliveEnemies(city)>0 then return options end end
	offerCache=offerCache or proxyInteractionOfferCache(crystals)
	for _,option in ipairs(offerCache[feature] or {}) do options[#options+1]=option end
	return options
end

function proxyInteractionBestChoices(options)
	if options==nil or #options==0 then return {} end
	local bestCost=options[1].cost
	local sameCost={}
	local unitAtBest=false
	for _,option in ipairs(options) do
		if option.cost~=bestCost then break end
		sameCost[#sameCost+1]=option
		if option.kind=="unit" then unitAtBest=true end
	end
	--Units win an equal-cost tie over Spells/Advanced Actions. Otherwise every equally cheapest
	--card remains a genuine player choice instead of being broken by GUID order.
	if unitAtBest==true then
		local units={}
		for _,option in ipairs(sameCost) do if option.kind=="unit" then units[#units+1]=option end end
		return units
	end
	return sameCost
end

function proxyFeatureDisplayName(value)
	local feature=string.lower(tostring(value or ""))
	local names={
		["keep"]="Keep", ["mage tower"]="Mage Tower", ["city"]="City", ["monastery"]="Monastery",
		["ruin"]="Ruins", ["dungeon"]="Dungeon", ["tomb"]="Tomb", ["monster den"]="Monster Den",
		["spawning grounds"]="Spawning Grounds", ["ziggurat"]="Ziggurat", ["pyramid"]="Pyramid",
		["magical glade"]="Magical Glade", ["village"]="Village", ["camp"]="Refugee Camp", ["refugee camp"]="Refugee Camp",
		["volkare's camp"]="Volkare's Camp", ["rampaging"]="Rampaging Enemy", ["draconum"]="Draconum"
	}
	if names[feature]~=nil then return names[feature] end
	if feature=="" then return "target" end
	return feature:gsub("(%a)([%w']*)",function(a,b) return string.upper(a)..b end)
end

function proxyCardDisplayName(card)
	if card==nil then return "Unknown" end
	local data=gameCards[card.guid]
	if data~=nil and data.name~=nil then
		local name=type(data.name)=="table" and data.name[1] or data.name
		if name~=nil and name~="" then return tostring(name) end
	end
	local name=card.getName()
	return name~="" and name or "Objective Card"
end

function proxyObjectiveReason(colors,mode)
	if mode=="explore" then return "No legal objective matching the Objective Card was available, so the Proxy moved to the nearest space from which they could explore." end
	if mode=="fallback" then return "Exploration was unavailable, so the Proxy used the closest legal Green, Red, or White objective." end
	local list={}
	for _,color in ipairs(colors or {}) do list[#list+1]=color end
	if #list>1 then return table.concat(list,"/").." objective: the closest legal target matching either colour was selected." end
	local color=list[1]
	if color=="Green" then return "Green objective: the nearest unconquered Adventure Site was selected." end
	if color=="Red" then return "Red objective: the nearest unconquered Fortified Site or unburned Monastery was selected." end
	if color=="White" then return "White objective: the nearest site with a legal interaction was selected." end
	if color=="Blue" then return "Blue objective: the nearest legal Green, Red, or White target farther from the Portal was selected." end
	return "The closest legal objective was selected."
end

function proxyTargetDisplayName(target)
	if target==nil then return "objective" end
	if target.action=="interact" and target.choice~=nil then
		if target.choice.kind=="unit" then return "recruitable Unit" end
		if target.choice.kind=="action" then return "Advanced Action" end
		if target.choice.kind=="spell" then return "Spell" end
	end
	if target.action=="explore" then return "exploration point" end
	if target.hex~=nil then return proxyFeatureDisplayName(target.hex.feature) end
	return "objective"
end

function proxyTurnReportBegin(objective,colors,baseMove,shieldMove,sourceMove)
	local cardType=gameCardType(objective)
	local baseReason=cardType=="Starting" and "Starter Card +1" or "Card +1"
	if (baseMove or 1)==2 then baseReason=cardType=="Advanced Action" and "Advanced Action +2" or "Unique Basic Action +2" end
	gStates.proxyTurnReport={
		objective=proxyCardDisplayName(objective),
		colors=table.concat(colors or {},"/"),
		baseMove=baseMove or 1,
		baseReason=baseReason,
		shieldMove=shieldMove or 0,
		sourceMove=sourceMove==true and 1 or 0,
		allowance=(baseMove or 1)+(shieldMove or 0)+(sourceMove==true and 1 or 0),
		moved=0,
		action=nil,
		reason=nil,
		target=nil
	}
end

function proxyTurnReportSetTarget(target)
	local report=gStates.proxyTurnReport
	if report==nil or target==nil then return end
	report.target=proxyTargetDisplayName(target)
	report.reason=target.proxyReason or report.reason
	if (target.proxyChoiceCount or 0)>1 then
		report.choiceCount=target.proxyChoiceCount
		report.choiceTarget=report.target
		report.choiceTargets={}
		for _,choice in ipairs(target.proxyChoiceTargets or {}) do
			--Destination candidates store their site on choice.hex; use the same display helper as
			--the map buttons instead of looking for a top-level .feature that normally does not exist.
			report.choiceTargets[#report.choiceTargets+1]=proxyTargetDisplayName(choice)
		end
		report.choiceRouteReason=target.proxyChoiceRouteReason
	elseif (report.choiceCount or 0)>1 then
		--Once the player has picked one of the tied destinations, remember the actual selection for
		--the temporary choice display rather than leaving whichever candidate represented the tie.
		report.choiceTarget=report.target
	end
end

function proxyTurnReportSetMoved(moved)
	if gStates.proxyTurnReport~=nil then gStates.proxyTurnReport.moved=moved or 0 end
end

function proxyTurnReportSetAction(action)
	if gStates.proxyTurnReport~=nil then gStates.proxyTurnReport.action=action end
end

function proxyLocalizedTerm(value)
	local text=tostring(value or "")
	local terms={
		["objective"]="{en}objective{ru}цель{zh-tw}目標{zh-cn}目标{ko}목표{es}objetivo{fr}objectif{pt-br}objetivo{de}Ziel",
		["recruitable Unit"]="{en}recruitable Unit{ru}доступный для найма отряд{zh-tw}可招募部隊{zh-cn}可招募部队{ko}모집 가능한 유닛{es}Unidad reclutable{fr}Unité recrutable{pt-br}Unidade recrutável{de}rekrutierbare Einheit",
		["Advanced Action"]="{en}Advanced Action{ru}Продвинутое действие{zh-tw}進階行動{zh-cn}进阶行动{ko}고급 행동{es}Acción Avanzada{fr}Action Avancée{pt-br}Ação Avançada{de}Fortgeschrittene Aktion",
		["Spell"]="{en}Spell{ru}Заклинание{zh-tw}法術{zh-cn}法术{ko}주문{es}Hechizo{fr}Sort{pt-br}Feitiço{de}Zauber",
		["exploration point"]="{en}exploration point{ru}точка исследования{zh-tw}探索點{zh-cn}探索点{ko}탐험 지점{es}punto de exploración{fr}point d’exploration{pt-br}ponto de exploração{de}Erkundungspunkt",
		["Keep"]="{en}Keep{ru}Крепость{zh-tw}要塞{zh-cn}要塞{ko}성채{es}Fortaleza{fr}Forteresse{pt-br}Fortaleza{de}Burg",
		["Mage Tower"]="{en}Mage Tower{ru}Башня мага{zh-tw}法師塔{zh-cn}法师塔{ko}마법사 탑{es}Torre de Mago{fr}Tour de Mage{pt-br}Torre de Mago{de}Magierturm",
		["City"]="{en}City{ru}Город{zh-tw}城市{zh-cn}城市{ko}도시{es}Ciudad{fr}Cité{pt-br}Cidade{de}Stadt",
		["Monastery"]="{en}Monastery{ru}Монастырь{zh-tw}修道院{zh-cn}修道院{ko}수도원{es}Monasterio{fr}Monastère{pt-br}Mosteiro{de}Kloster",
		["Ruins"]="{en}Ruins{ru}Руины{zh-tw}遺跡{zh-cn}遗迹{ko}유적{es}Ruinas{fr}Ruines{pt-br}Ruínas{de}Ruinen",
		["Dungeon"]="{en}Dungeon{ru}Подземелье{zh-tw}地下城{zh-cn}地下城{ko}던전{es}Mazmorra{fr}Donjon{pt-br}Masmorra{de}Kerker",
		["Tomb"]="{en}Tomb{ru}Гробница{zh-tw}墓穴{zh-cn}墓穴{ko}무덤{es}Tumba{fr}Tombeau{pt-br}Tumba{de}Grabmal",
		["Monster Den"]="{en}Monster Den{ru}Логово монстров{zh-tw}怪物巢穴{zh-cn}怪物巢穴{ko}괴물 소굴{es}Guarida de Monstruos{fr}Repaire de Monstres{pt-br}Covil de Monstros{de}Monsterhöhle",
		["Spawning Grounds"]="{en}Spawning Grounds{ru}Место появления{zh-tw}繁殖地{zh-cn}繁殖地{ko}산란지{es}Campo de Aparición{fr}Terrain de Reproduction{pt-br}Terreno de Criação{de}Brutstätte",
		["Magical Glade"]="{en}Magical Glade{ru}Магическая поляна{zh-tw}魔法林地{zh-cn}魔法林地{ko}마법의 숲{es}Claro Mágico{fr}Clairière Magique{pt-br}Clareira Mágica{de}Magische Lichtung",
		["Village"]="{en}Village{ru}Деревня{zh-tw}村莊{zh-cn}村庄{ko}마을{es}Aldea{fr}Village{pt-br}Vila{de}Dorf",
		["Refugee Camp"]="{en}Refugee Camp{ru}Лагерь беженцев{zh-tw}難民營{zh-cn}难民营{ko}난민 캠프{es}Campamento de Refugiados{fr}Camp de Réfugiés{pt-br}Acampamento de Refugiados{de}Flüchtlingslager",
		["Volkare's Camp"]="{en}Volkare's Camp{ru}Лагерь Волкара{zh-tw}沃卡里營地{zh-cn}沃卡里营地{ko}볼케어의 야영지{es}Campamento de Volkare{fr}Camp de Volkare{pt-br}Acampamento de Volkare{de}Volkares Lager",
		["Rampaging Enemy"]="{en}Rampaging Enemy{ru}Бродячий враг{zh-tw}遊蕩敵人{zh-cn}游荡敌人{ko}방랑 적{es}Enemigo Arrasador{fr}Ennemi Ravageur{pt-br}Inimigo Errante{de}Streunender Gegner",
		["Draconum"]="{en}Draconum{ru}Драконид{zh-tw}龍人{zh-cn}龙人{ko}드라코넘{es}Draconum{fr}Draconum{pt-br}Draconum{de}Draconum"
	}
	return terms[text] or translateWord[text] or text
end

function proxyLocalizedList(values,separator)
	local parts={}
	for _,value in ipairs(values or {}) do
		if #parts>0 then parts[#parts+1]=separator or ", " end
		parts[#parts+1]=value
	end
	return #parts>0 and joinLang(parts) or ""
end

function proxyLocalizedColorList(colors)
	local values={}
	for color in tostring(colors or ""):gmatch("[^/]+") do values[#values+1]=translateWord[color] or color end
	return proxyLocalizedList(values,"/")
end

function proxyLocalizedReason(reason,colors)
	local text=tostring(reason or "")
	local exact={
		["The closest legal objective was selected."]="{en}The closest legal objective was selected.{ru}Выбрана ближайшая допустимая цель.{zh-tw}已選擇最近的合法目標。{zh-cn}已选择最近的合法目标。{ko}가장 가까운 합법적인 목표를 선택했습니다.{es}Se seleccionó el objetivo legal más cercano.{fr}L’objectif légal le plus proche a été sélectionné.{pt-br}O objetivo válido mais próximo foi selecionado.{de}Das nächstgelegene gültige Ziel wurde ausgewählt.",
		["No legal objective matching the Objective Card was available, so the Proxy moved to the nearest space from which they could explore."]="{en}No legal objective matching the Objective Card was available, so the Proxy moved to the nearest space from which they could explore.{ru}Подходящей цели по карте цели не было, поэтому Прокси переместился к ближайшей клетке, откуда можно исследовать.{zh-tw}沒有符合目標牌的合法目標，因此代理玩家移向最近可進行探索的空間。{zh-cn}没有符合目标牌的合法目标，因此代理玩家移向最近可进行探索的空间。{ko}목표 카드와 일치하는 합법적인 목표가 없어 프록시는 탐험할 수 있는 가장 가까운 칸으로 이동했습니다.{es}No había un objetivo legal que coincidiera con la Carta de Objetivo, así que el Proxy se movió al espacio más cercano desde el que podía explorar.{fr}Aucun objectif légal ne correspondait à la Carte Objectif ; le Proxy s’est donc déplacé vers la case la plus proche depuis laquelle il pouvait explorer.{pt-br}Não havia objetivo válido correspondente à Carta de Objetivo, então o Proxy se moveu para o espaço mais próximo de onde pudesse explorar.{de}Es gab kein gültiges Ziel passend zur Zielkarte, daher bewegte sich der Proxy zum nächstgelegenen Feld, von dem aus er erkunden konnte.",
		["Exploration was unavailable, so the Proxy used the closest legal Green, Red, or White objective."]="{en}Exploration was unavailable, so the Proxy used the closest legal Green, Red, or White objective.{ru}Исследование было недоступно, поэтому Прокси выбрал ближайшую допустимую зелёную, красную или белую цель.{zh-tw}無法探索，因此代理玩家使用最近的合法綠色、紅色或白色目標。{zh-cn}无法探索，因此代理玩家使用最近的合法绿色、红色或白色目标。{ko}탐험할 수 없어 프록시는 가장 가까운 합법적인 녹색, 빨간색 또는 흰색 목표를 사용했습니다.{es}No se podía explorar, así que el Proxy usó el objetivo Verde, Rojo o Blanco legal más cercano.{fr}L’exploration était impossible ; le Proxy a donc utilisé l’objectif Vert, Rouge ou Blanc légal le plus proche.{pt-br}A exploração não estava disponível, então o Proxy usou o objetivo Verde, Vermelho ou Branco válido mais próximo.{de}Erkundung war nicht möglich, daher verwendete der Proxy das nächstgelegene gültige grüne, rote oder weiße Ziel.",
		["Green objective: the nearest unconquered Adventure Site was selected."]="{en}Green objective: the nearest unconquered Adventure Site was selected.{ru}Зелёная цель: выбрано ближайшее непокорённое место приключения.{zh-tw}綠色目標：已選擇最近的未征服冒險地點。{zh-cn}绿色目标：已选择最近的未征服冒险地点。{ko}녹색 목표: 가장 가까운 미정복 모험 장소를 선택했습니다.{es}Objetivo Verde: se seleccionó el Lugar de Aventura no conquistado más cercano.{fr}Objectif Vert : le Site d’Aventure non conquis le plus proche a été sélectionné.{pt-br}Objetivo Verde: o Local de Aventura não conquistado mais próximo foi selecionado.{de}Grünes Ziel: Der nächstgelegene nicht eroberte Abenteuerort wurde ausgewählt.",
		["Red objective: the nearest unconquered Fortified Site or unburned Monastery was selected."]="{en}Red objective: the nearest unconquered Fortified Site or unburned Monastery was selected.{ru}Красная цель: выбрано ближайшее непокорённое укреплённое место или несожжённый Монастырь.{zh-tw}紅色目標：已選擇最近的未征服要塞地點或未焚毀修道院。{zh-cn}红色目标：已选择最近的未征服要塞地点或未焚毁修道院。{ko}빨간색 목표: 가장 가까운 미정복 요새 장소 또는 불타지 않은 수도원을 선택했습니다.{es}Objetivo Rojo: se seleccionó el Lugar Fortificado no conquistado o Monasterio no quemado más cercano.{fr}Objectif Rouge : le Site Fortifié non conquis ou le Monastère non brûlé le plus proche a été sélectionné.{pt-br}Objetivo Vermelho: o Local Fortificado não conquistado ou Mosteiro não queimado mais próximo foi selecionado.{de}Rotes Ziel: Der nächstgelegene nicht eroberte befestigte Ort oder das nächstgelegene nicht niedergebrannte Kloster wurde ausgewählt.",
		["White objective: the nearest site with a legal interaction was selected."]="{en}White objective: the nearest site with a legal interaction was selected.{ru}Белая цель: выбрано ближайшее место с допустимым взаимодействием.{zh-tw}白色目標：已選擇最近可合法互動的地點。{zh-cn}白色目标：已选择最近可合法互动的地点。{ko}흰색 목표: 합법적으로 상호작용할 수 있는 가장 가까운 장소를 선택했습니다.{es}Objetivo Blanco: se seleccionó el lugar más cercano con una interacción legal.{fr}Objectif Blanc : le site le plus proche avec une interaction légale a été sélectionné.{pt-br}Objetivo Branco: o local mais próximo com interação válida foi selecionado.{de}Weißes Ziel: Der nächstgelegene Ort mit einer gültigen Interaktion wurde ausgewählt.",
		["Blue objective: the nearest legal Green, Red, or White target farther from the Portal was selected."]="{en}Blue objective: the nearest legal Green, Red, or White target farther from the Portal was selected.{ru}Синяя цель: выбрана ближайшая допустимая зелёная, красная или белая цель, находящаяся дальше от Портала.{zh-tw}藍色目標：已選擇距傳送門更遠且最近的合法綠色、紅色或白色目標。{zh-cn}蓝色目标：已选择距传送门更远且最近的合法绿色、红色或白色目标。{ko}파란색 목표: 포털에서 더 멀리 있는 가장 가까운 합법적인 녹색, 빨간색 또는 흰색 목표를 선택했습니다.{es}Objetivo Azul: se seleccionó el objetivo Verde, Rojo o Blanco legal más cercano que estuviera más lejos del Portal.{fr}Objectif Bleu : la cible Verte, Rouge ou Blanche légale la plus proche et plus éloignée du Portail a été sélectionnée.{pt-br}Objetivo Azul: o alvo Verde, Vermelho ou Branco válido mais próximo e mais distante do Portal foi selecionado.{de}Blaues Ziel: Das nächstgelegene gültige grüne, rote oder weiße Ziel, das weiter vom Portal entfernt liegt, wurde ausgewählt."
	}
	if exact[text]~=nil then return exact[text] end
	if text:find(" objective: the closest legal target matching either colour was selected.",1,true)~=nil then
		return joinLang({proxyLocalizedColorList(colors),"{en} objective: the closest legal target matching either colour was selected.{ru} цель: выбрана ближайшая допустимая цель, соответствующая одному из цветов.{zh-tw} 目標：已選擇符合任一顏色的最近合法目標。{zh-cn} 目标：已选择符合任一颜色的最近合法目标。{ko} 목표: 두 색 중 하나와 일치하는 가장 가까운 합법적인 목표를 선택했습니다.{es}: se seleccionó el objetivo legal más cercano que coincide con cualquiera de los colores.{fr} : la cible légale la plus proche correspondant à l’une ou l’autre couleur a été sélectionnée.{pt-br}: o alvo válido mais próximo correspondente a qualquer uma das cores foi selecionado.{de}-Ziel: Das nächstgelegene gültige Ziel, das einer der Farben entspricht, wurde ausgewählt."})
	end
	return text
end

function proxyLocalizedAction(action)
	local text=tostring(action or "")
	local exact={
		["could not restore the selected route"]="{en}could not restore the selected route{ru}не смог восстановить выбранный маршрут{zh-tw}無法恢復所選路線{zh-cn}无法恢复所选路线{ko}선택한 경로를 복원하지 못했습니다{es}no pudo restaurar la ruta seleccionada{fr}n’a pas pu restaurer l’itinéraire sélectionné{pt-br}não conseguiu restaurar a rota selecionada{de}konnte die ausgewählte Route nicht wiederherstellen",
		["could not restore the selected destination"]="{en}could not restore the selected destination{ru}не смог восстановить выбранное место назначения{zh-tw}無法恢復所選目的地{zh-cn}无法恢复所选目的地{ko}선택한 목적지를 복원하지 못했습니다{es}no pudo restaurar el destino seleccionado{fr}n’a pas pu restaurer la destination sélectionnée{pt-br}não conseguiu restaurar o destino selecionado{de}konnte das ausgewählte Ziel nicht wiederherstellen",
		["conquered the City"]="{en}conquered the City{ru}покорил Город{zh-tw}征服了城市{zh-cn}征服了城市{ko}도시를 정복했습니다{es}conquistó la Ciudad{fr}a conquis la Cité{pt-br}conquistou a Cidade{de}hat die Stadt erobert",
		["could not find the selected offer card"]="{en}could not find the selected offer card{ru}не смог найти выбранную карту предложения{zh-tw}找不到所選供應牌{zh-cn}找不到所选供应牌{ko}선택한 제안 카드를 찾지 못했습니다{es}no pudo encontrar la carta seleccionada de la oferta{fr}n’a pas pu trouver la carte sélectionnée dans l’offre{pt-br}não conseguiu encontrar a carta selecionada da oferta{de}konnte die ausgewählte Angebotskarte nicht finden",
		["found no legal card to take at the interaction site"]="{en}found no legal card to take at the interaction site{ru}не нашёл допустимой карты для получения в месте взаимодействия{zh-tw}在互動地點找不到可合法取得的牌{zh-cn}在互动地点找不到可合法取得的牌{ko}상호작용 장소에서 가져갈 수 있는 합법적인 카드를 찾지 못했습니다{es}no encontró ninguna carta legal para tomar en el lugar de interacción{fr}n’a trouvé aucune carte légale à prendre sur le site d’interaction{pt-br}não encontrou nenhuma carta válida para pegar no local de interação{de}fand am Interaktionsort keine gültige Karte zum Nehmen",
		["explored a predefined tile"]="{en}explored a predefined tile{ru}исследовал предопределённую плитку{zh-tw}探索了一個預設板塊{zh-cn}探索了一个预设板块{ko}미리 정해진 타일을 탐험했습니다{es}exploró una loseta predefinida{fr}a exploré une tuile prédéfinie{pt-br}explorou uma peça predefinida{de}hat ein vordefiniertes Plättchen erkundet",
		["explored a new tile"]="{en}explored a new tile{ru}исследовал новую плитку{zh-tw}探索了一個新板塊{zh-cn}探索了一个新板块{ko}새 타일을 탐험했습니다{es}exploró una nueva loseta{fr}a exploré une nouvelle tuile{pt-br}explorou uma nova peça{de}hat ein neues Plättchen erkundet",
		["burned the Monastery"]="{en}burned the Monastery{ru}сжёг Монастырь{zh-tw}焚毀了修道院{zh-cn}焚毁了修道院{ko}수도원을 불태웠습니다{es}quemó el Monasterio{fr}a brûlé le Monastère{pt-br}queimou o Mosteiro{de}hat das Kloster niedergebrannt",
		["had no legal objective or exploration destination"]="{en}had no legal objective or exploration destination{ru}не имел допустимой цели или места исследования{zh-tw}沒有合法目標或探索目的地{zh-cn}没有合法目标或探索目的地{ko}합법적인 목표나 탐험 목적지가 없었습니다{es}no tenía objetivo legal ni destino de exploración{fr}n’avait aucun objectif légal ni destination d’exploration{pt-br}não tinha objetivo válido nem destino de exploração{de}hatte kein gültiges Ziel oder Erkundungsziel"
	}
	if exact[text]~=nil then return exact[text] end
	local name=text:match("^defeated (.+) in the City and retreated$")
	if name~=nil then return joinLang({"{en}defeated {ru}победил {zh-tw}擊敗了 {zh-cn}击败了 {ko}을(를) 쓰러뜨리고 {es}derrotó a {fr}a vaincu {pt-br}derrotou {de}besiegte ",name,"{en} in the City and retreated{ru} в Городе и отступил{zh-tw} 於城市並撤退{zh-cn} 于城市并撤退{ko}도시에서 후퇴했습니다{es} en la Ciudad y se retiró{fr} dans la Cité et a battu en retraite{pt-br} na Cidade e recuou{de} in der Stadt und zog sich zurück"}) end
	name=text:match("^defeated (.+) at the Ruins$")
	if name~=nil then return joinLang({"{en}defeated {ru}победил {zh-tw}在遺跡擊敗了 {zh-cn}在遗迹击败了 {ko}유적에서 {es}derrotó a {fr}a vaincu {pt-br}derrotou {de}besiegte ",name,"{en} at the Ruins{ru} в Руинах{zh-tw}{zh-cn}{ko}을(를) 쓰러뜨렸습니다{es} en las Ruinas{fr} dans les Ruines{pt-br} nas Ruínas{de} in den Ruinen"}) end
	name=text:match("^defeated the rampaging (.+)$")
	if name~=nil then return joinLang({"{en}defeated the rampaging {ru}победил бродячего врага: {zh-tw}擊敗遊蕩敵人：{zh-cn}击败游荡敌人：{ko}방랑 적을 쓰러뜨렸습니다: {es}derrotó al enemigo arrasador {fr}a vaincu l’ennemi ravageur {pt-br}derrotou o inimigo errante {de}besiegte den streunenden Gegner ",name}) end
	local count=text:match("^defeated (%d+) rampaging enemies$")
	if count~=nil then return joinLang({"{en}defeated {ru}победил {zh-tw}擊敗 {zh-cn}击败 {ko}방랑 적 {es}derrotó a {fr}a vaincu {pt-br}derrotou {de}besiegte ",count,"{en} rampaging enemies{ru} бродячих врагов{zh-tw} 個遊蕩敵人{zh-cn} 个游荡敌人{ko}명을 쓰러뜨렸습니다{es} enemigos arrasadores{fr} ennemis ravageurs{pt-br} inimigos errantes{de} streunende Gegner"}) end
	name=text:match("^resolved the (.+)$")
	if name~=nil then return joinLang({"{en}resolved the {ru}разрешил {zh-tw}完成了 {zh-cn}完成了 {ko}을(를) 해결했습니다: {es}resolvió {fr}a résolu {pt-br}resolveu {de}hat abgeschlossen: ",proxyLocalizedTerm(name)}) end
	name=text:match("^conquered the (.+)$")
	if name~=nil then return joinLang({"{en}conquered the {ru}покорил {zh-tw}征服了 {zh-cn}征服了 {ko}을(를) 정복했습니다: {es}conquistó {fr}a conquis {pt-br}conquistou {de}hat erobert: ",proxyLocalizedTerm(name)}) end
	local card,kind=text:match("^took (.+) %((.+)%) from the offer$")
	if card~=nil then return joinLang({"{en}took {ru}взял {zh-tw}從供應中取得 {zh-cn}从供应中取得 {ko}제안에서 {es}tomó {fr}a pris {pt-br}pegou {de}nahm ",card," (",kind,"){en} from the offer{ru} из предложения{zh-tw}{zh-cn}{ko}을(를) 가져갔습니다{es} de la oferta{fr} de l’offre{pt-br} da oferta{de} aus dem Angebot"}) end
	local target=text:match("^moved toward the (.+)\nbut did not reach it$")
	if target~=nil then return joinLang({"{en}moved toward the {ru}двигался к {zh-tw}朝 {zh-cn}朝 {ko} 방향으로 이동했지만 도달하지 못했습니다: {es}se movió hacia {fr}s’est déplacé vers {pt-br}moveu-se em direção a {de}bewegte sich in Richtung ",proxyLocalizedTerm(target),"{en}\nbut did not reach it{ru}, но не достиг цели{zh-tw} 移動，但未抵達{zh-cn} 移动，但未抵达{ko}{es}\npero no llegó{fr}\nmais ne l’a pas atteint{pt-br}\nmas não chegou{de}, erreichte das Ziel aber nicht"}) end
	return text
end

function proxyTurnReportText()
	local report=gStates.proxyTurnReport
	if report==nil then return "{en}Proxy processing is complete.{ru}Обработка Прокси завершена.{zh-tw}代理玩家處理完成。{zh-cn}代理玩家处理完成。{ko}프록시 처리가 완료되었습니다.{es}El procesamiento del Proxy ha terminado.{fr}Le traitement du Proxy est terminé.{pt-br}O processamento do Proxy foi concluído.{de}Die Proxy-Verarbeitung ist abgeschlossen." end
	local moved=report.moved or 0
	local action=report.action
	local first
	local active=gStates.proxyState=="Processing" or gStates.proxyState=="PickDestination" or gStates.proxyState=="PickRoute" or gStates.proxyState=="PickCard" or gStates.proxyState=="PickEnemy" or gStates.proxyState=="PickMana"
	local target=proxyLocalizedTerm(report.target)
	if action==nil or action=="" then
		if report.target~=nil then
			if active==true then first=joinLang({"{en}Proxy is moving toward the {ru}Прокси движется к {zh-tw}代理玩家正朝 {zh-cn}代理玩家正朝 {ko}프록시가 다음 목표로 이동 중입니다: {es}El Proxy se mueve hacia {fr}Le Proxy se déplace vers {pt-br}O Proxy está se movendo em direção a {de}Der Proxy bewegt sich in Richtung ",target,"."})
			elseif moved<=0 then first=joinLang({"{en}Proxy did not move toward the {ru}Прокси не двигался к {zh-tw}代理玩家沒有朝 {zh-cn}代理玩家没有朝 {ko}프록시는 다음 목표로 이동하지 않았습니다: {es}El Proxy no se movió hacia {fr}Le Proxy ne s’est pas déplacé vers {pt-br}O Proxy não se moveu em direção a {de}Der Proxy bewegte sich nicht in Richtung ",target,"."})
			elseif moved==1 then first=joinLang({"{en}Proxy moved 1 space toward the {ru}Прокси переместился на 1 клетку к {zh-tw}代理玩家朝 {zh-cn}代理玩家朝 {ko}프록시가 다음 목표로 1칸 이동했습니다: {es}El Proxy se movió 1 espacio hacia {fr}Le Proxy s’est déplacé d’une case vers {pt-br}O Proxy moveu-se 1 espaço em direção a {de}Der Proxy bewegte sich 1 Feld in Richtung ",target,"."})
			else first=joinLang({"{en}Proxy moved {ru}Прокси переместился на {zh-tw}代理玩家移動了 {zh-cn}代理玩家移动了 {ko}프록시가 {es}El Proxy se movió {fr}Le Proxy s’est déplacé de {pt-br}O Proxy moveu-se {de}Der Proxy bewegte sich ",tostring(moved),"{en} spaces toward the {ru} клетки к {zh-tw} 格，朝向 {zh-cn} 格，朝向 {ko}칸 이동했습니다: {es} espacios hacia {fr} cases vers {pt-br} espaços em direção a {de} Felder in Richtung ",target,"."}) end
		else
			if active==true then first="{en}Proxy is preparing their movement.{ru}Прокси готовится к движению.{zh-tw}代理玩家正在準備移動。{zh-cn}代理玩家正在准备移动。{ko}프록시가 이동을 준비하고 있습니다.{es}El Proxy prepara su movimiento.{fr}Le Proxy prépare son déplacement.{pt-br}O Proxy está preparando seu movimento.{de}Der Proxy bereitet seine Bewegung vor."
			elseif moved<=0 then first="{en}Proxy completed their movement.{ru}Прокси завершил движение.{zh-tw}代理玩家完成移動。{zh-cn}代理玩家完成移动。{ko}프록시가 이동을 완료했습니다.{es}El Proxy completó su movimiento.{fr}Le Proxy a terminé son déplacement.{pt-br}O Proxy concluiu seu movimento.{de}Der Proxy hat seine Bewegung abgeschlossen."
			elseif moved==1 then first="{en}Proxy moved 1 space.{ru}Прокси переместился на 1 клетку.{zh-tw}代理玩家移動了 1 格。{zh-cn}代理玩家移动了 1 格。{ko}프록시가 1칸 이동했습니다.{es}El Proxy se movió 1 espacio.{fr}Le Proxy s’est déplacé d’une case.{pt-br}O Proxy moveu-se 1 espaço.{de}Der Proxy bewegte sich 1 Feld."
			else first=joinLang({"{en}Proxy moved {ru}Прокси переместился на {zh-tw}代理玩家移動了 {zh-cn}代理玩家移动了 {ko}프록시가 {es}El Proxy se movió {fr}Le Proxy s’est déplacé de {pt-br}O Proxy moveu-se {de}Der Proxy bewegte sich ",tostring(moved),"{en} spaces.{ru} клетки.{zh-tw} 格。{zh-cn} 格。{ko}칸 이동했습니다.{es} espacios.{fr} cases.{pt-br} espaços.{de} Felder."}) end
		end
	else
		local localizedAction=proxyLocalizedAction(action)
		if moved<=0 then first=joinLang({"{en}Proxy {ru}Прокси {zh-tw}代理玩家{zh-cn}代理玩家{ko}프록시가 {es}El Proxy {fr}Le Proxy {pt-br}O Proxy {de}Der Proxy ",localizedAction,"."})
		elseif moved==1 then first=joinLang({"{en}Proxy moved 1 space and\n{ru}Прокси переместился на 1 клетку и\n{zh-tw}代理玩家移動 1 格並\n{zh-cn}代理玩家移动 1 格并\n{ko}프록시가 1칸 이동하고\n{es}El Proxy se movió 1 espacio y\n{fr}Le Proxy s’est déplacé d’une case et\n{pt-br}O Proxy moveu-se 1 espaço e\n{de}Der Proxy bewegte sich 1 Feld und\n",localizedAction,"."})
		else first=joinLang({"{en}Proxy moved {ru}Прокси переместился на {zh-tw}代理玩家移動 {zh-cn}代理玩家移动 {ko}프록시가 {es}El Proxy se movió {fr}Le Proxy s’est déplacé de {pt-br}O Proxy moveu-se {de}Der Proxy bewegte sich ",tostring(moved),"{en} spaces and\n{ru} клетки и\n{zh-tw} 格並\n{zh-cn} 格并\n{ko}칸 이동하고\n{es} espacios y\n{fr} cases et\n{pt-br} espaços e\n{de} Felder und\n",localizedAction,"."}) end
	end

	local reason=proxyLocalizedReason(report.reason or "The closest legal objective was selected.",report.colors)
	local colors=report.colors or ""
	local shortReason=reason
	if colors=="Green" then shortReason="{en}Nearest unconquered Adventure Site{ru}Ближайшее непокорённое место приключения{zh-tw}最近的未征服冒險地點{zh-cn}最近的未征服冒险地点{ko}가장 가까운 미정복 모험 장소{es}Lugar de Aventura no conquistado más cercano{fr}Site d’Aventure non conquis le plus proche{pt-br}Local de Aventura não conquistado mais próximo{de}Nächstgelegener nicht eroberter Abenteuerort"
	elseif colors=="Red" then shortReason="{en}Nearest unconquered Fortified Site or unburned Monastery{ru}Ближайшее непокорённое укреплённое место или несожжённый Монастырь{zh-tw}最近的未征服要塞地點或未焚毀修道院{zh-cn}最近的未征服要塞地点或未焚毁修道院{ko}가장 가까운 미정복 요새 장소 또는 불타지 않은 수도원{es}Lugar Fortificado no conquistado o Monasterio no quemado más cercano{fr}Site Fortifié non conquis ou Monastère non brûlé le plus proche{pt-br}Local Fortificado não conquistado ou Mosteiro não queimado mais próximo{de}Nächstgelegener nicht eroberter befestigter Ort oder nicht niedergebranntes Kloster"
	elseif colors=="White" then shortReason="{en}Nearest site with a legal interaction{ru}Ближайшее место с допустимым взаимодействием{zh-tw}最近可合法互動的地點{zh-cn}最近可合法互动的地点{ko}합법적으로 상호작용할 수 있는 가장 가까운 장소{es}Lugar más cercano con una interacción legal{fr}Site le plus proche avec une interaction légale{pt-br}Local mais próximo com interação válida{de}Nächstgelegener Ort mit gültiger Interaktion"
	elseif colors=="Blue" then shortReason="{en}Nearest legal Green, Red, or White target farther from the Portal{ru}Ближайшая допустимая зелёная, красная или белая цель дальше от Портала{zh-tw}距傳送門更遠的最近合法綠色、紅色或白色目標{zh-cn}距传送门更远的最近合法绿色、红色或白色目标{ko}포털에서 더 멀리 있는 가장 가까운 합법적인 녹색, 빨간색 또는 흰색 목표{es}Objetivo Verde, Rojo o Blanco legal más cercano y más lejos del Portal{fr}Cible Verte, Rouge ou Blanche légale la plus proche et plus éloignée du Portail{pt-br}Alvo Verde, Vermelho ou Branco válido mais próximo e mais distante do Portal{de}Nächstgelegenes gültiges grünes, rotes oder weißes Ziel weiter vom Portal entfernt" end
	local objectiveLabel=colors~="" and proxyLocalizedColorList(colors) or tostring(report.objective or "{en}Unknown{ru}Неизвестно{zh-tw}未知{zh-cn}未知{ko}알 수 없음{es}Desconocido{fr}Inconnu{pt-br}Desconhecido{de}Unbekannt")
	local choiceLine=""
	if gStates.proxyState=="PickDestination" and (report.choiceCount or 0)>1 then
		local choices
		if report.choiceTargets~=nil then
			local translated={}
			for _,choice in ipairs(report.choiceTargets) do translated[#translated+1]=proxyLocalizedTerm(choice) end
			choices=proxyLocalizedList(translated,", ")
		else choices=joinLang({tostring(report.choiceCount),"{en} equally close{ru} равноудалённых{zh-tw} 個同樣接近{zh-cn} 个同样接近{ko}개의 동일 거리{es} igualmente cercanos{fr} à égale distance{pt-br} igualmente próximos{de} gleich nahe"}) end
		choiceLine=joinLang({"{en}\n\nMultiple targets: {ru}\n\nНесколько целей: {zh-tw}\n\n多個目標：{zh-cn}\n\n多个目标：{ko}\n\n여러 목표: {es}\n\nMúltiples objetivos: {fr}\n\nPlusieurs cibles : {pt-br}\n\nVários alvos: {de}\n\nMehrere Ziele: ",choices})
	end

	local interactionLine=""
	if gStates.proxyState=="PickCard" and (report.interactionChoiceCount or 0)>1 then
		local choices=report.interactionChoiceNames~=nil and proxyLocalizedList(report.interactionChoiceNames,", ") or tostring(report.interactionChoiceCount)
		interactionLine=joinLang({"{en}\n\nMultiple interaction choices: {ru}\n\nНесколько вариантов взаимодействия: {zh-tw}\n\n多個互動選擇：{zh-cn}\n\n多个互动选择：{ko}\n\n여러 상호작용 선택: {es}\n\nMúltiples opciones de interacción: {fr}\n\nPlusieurs choix d’interaction : {pt-br}\n\nVárias escolhas de interação: {de}\n\nMehrere Interaktionsmöglichkeiten: ",choices})
	end

	local movementParts={report.baseReason or (report.baseMove==2 and "Card +2" or "Card +1")}
	if (report.shieldMove or 0)>0 then movementParts[#movementParts+1]="Shield +"..tostring(report.shieldMove) end
	if (report.sourceMove or 0)>0 then movementParts[#movementParts+1]="Source +1" end
	local movementText=table.concat(movementParts,", ")
	local summaryLine=joinLang({"{en}Objective: {ru}Цель: {zh-tw}目標：{zh-cn}目标：{ko}목표: {es}Objetivo: {fr}Objectif : {pt-br}Objetivo: {de}Ziel: ",objectiveLabel," (",shortReason,").\n\n{en}Movement: {ru}Движение: {zh-tw}移動：{zh-cn}移动：{ko}이동: {es}Movimiento: {fr}Déplacement : {pt-br}Movimento: {de}Bewegung: ",tostring(report.allowance or 0)," (",movementText,")."})
	return joinLang({first,choiceLine,interactionLine,"\n\n",summaryLine})
end
--Return the logical Portal hex used by Proxy rules. Against the Horsemen starts from Country Tile 1's
--central Magical Glade; even after the Round 3 ritual closes the actual Portal, Blue-objective distance
--continues to be measured from that original Portal space rather than from the physical Portal card.
function proxyPortalHex(hexes)
	if gStates~=nil and gStates.gameScenario=="Against the Horsemen Blitz" then
		for _,hex in ipairs(hexes or {}) do
			if hex.terrainGUID==GUID.tile.country01 and tostring(hex.bearing)=="center" then return hex end
		end
	end
	for _,hex in ipairs(hexes or {}) do
		if string.lower(tostring(hex.feature or ""))=="portal" then return hex end
	end
	return nil
end

--Green objectives must still be legally conquerable, not merely unclaimed by the Proxy.
--Ordinary Adventure Sites close as soon as any Mage Knight has conquered them. Maze/Labyrinth
--and Ziggurat/Pyramid use three shield slots; mirror the normal player controls by leaving the
--site available while fewer than three slots are claimed, but never send the same Proxy back to
--a multi-shield site they have already conquered.
function proxyAdventureSiteAvailable(hex,mapObjects,proxyIndex)
	if hex==nil then return false end
	local feature=string.lower(tostring(hex.feature or ""))
	local multiShield=feature=="maze" or feature=="labyrinth" or feature=="ziggurat" or feature=="pyramid"
	if multiShield~=true then return apocalypseQuestHexHasShield(hex,mapObjects,proxyIndex,true)~=true end

	local mage=turnOrder[proxyIndex]~=nil and turnOrder[proxyIndex].mage or nil
	local shieldCount=0
	local proxyShield=false
	local radiusSquared=(feature=="ziggurat" or feature=="pyramid") and 2.25 or 1.44
	for _,obj in pairs(mapObjects or {}) do
		if obj.getName()=="Shield" and volkarePursuitShieldRegistered(obj)~=true then
			local pos=obj.getPosition()
			local dx=pos[1]-hex.position[1]
			local dz=pos[3]-hex.position[3]
			if (dx*dx)+(dz*dz)<radiusSquared then
				shieldCount=shieldCount+1
				if mage~=nil and obj.getDescription()==mage then proxyShield=true end
			end
		end
	end
	if shieldCount>=3 or proxyShield==true then return false end
	if feature=="ziggurat" or feature=="pyramid" then return proxyMultiFloorNext(hex,mapObjects)~=nil end
	return true
end

function proxyTargetCandidatesForColor(color,hexes,mapObjects,proxyIndex,crystals,fartherOnly,portalDistances,currentPortalDistance,offerCache)
	local candidates={}
	for _,hex in ipairs(hexes or {}) do
		local feature=string.lower(tostring(hex.feature or ""))
		local validFarther=fartherOnly~=true or ((portalDistances[runtimeMapHexKey(hex)] or -1)>currentPortalDistance)
		if validFarther and feature~="destroyed" then
			if color=="Green" and apocalypseQuestHexAdventureSite(hex)==true and proxyAdventureSiteAvailable(hex,mapObjects,proxyIndex)==true then
				if not (gStates.gameScenario=="Against the Apocalypse Blitz" and (feature=="ziggurat" or feature=="pyramid")) then candidates[#candidates+1]={hex=hex,action="adventure",objectiveColor=color} end
			elseif color=="Red" then
				local fortified=proxyFortifiedType(hex,mapObjects,proxyIndex)
				--Another player's Keep is already conquered, so it is not a Red objective.
				--proxyFortifiedType() deliberately still recognizes it for unavoidable route hazards.
				local conqueredKeep=fortified=="keep" and apocalypseQuestHexHasShield(hex,mapObjects,proxyIndex,true)==true
				if fortified~=nil and conqueredKeep~=true then candidates[#candidates+1]={hex=hex,action="fortified",fortified=fortified,objectiveColor=color}
				elseif feature=="monastery" and (gStates.monasteryBurned==nil or gStates.monasteryBurned[hex.terrainGUID]~=true) then candidates[#candidates+1]={hex=hex,action="burn",objectiveColor=color} end
			elseif color=="White" then
				local options=proxyInteractionBestChoices(proxyInteractionOptions(hex,mapObjects,proxyIndex,crystals,offerCache))
				if #options>0 then candidates[#candidates+1]={hex=hex,action="interact",choice=options[1],interactionChoices=options,objectiveColor=color} end
			end
		end
	end
	return candidates
end

function proxyExploreButtonPosition(button)
	if button==nil or button.attributes==nil or button.attributes.id==nil then return nil end
	local pos={}
	local index=1
	for value in tostring(button.attributes.id):gmatch("([^,]+)") do
		if index==1 then pos[index]=tonumber(value:sub(7)) else pos[index]=tonumber(value) end
		index=index+1
	end
	if pos[1]==nil or pos[2]==nil then return nil end
	return {pos[1],1.3,pos[2]}
end

function proxyExploreTarget(hexes,distances)
	local candidates={}
	--Ordinary maps expose legal Explore buttons. Use those exactly as before.
	for _,button in pairs(terrainExploreOptions()) do
		local p=proxyExploreButtonPosition(button)
		if p~=nil then
			local bestHex,bestTravel,bestEdge=nil,nil,nil
			for _,hex in ipairs(hexes or {}) do
				local travel=distances[runtimeMapHexKey(hex)]
				if travel~=nil then
					local dx=hex.position[1]-p[1]
					local dz=hex.position[3]-p[3]
					local edge=(dx*dx)+(dz*dz)
					if edge<26 and (bestTravel==nil or travel<bestTravel or (travel==bestTravel and edge<bestEdge)) then
						bestHex,bestTravel,bestEdge=hex,travel,edge
					end
				end
			end
			if bestHex~=nil then candidates[#candidates+1]={hex=bestHex,action="explore",button=button,edge=bestEdge,proxyExplorePosition=p,proxyDistance=bestTravel} end
		end
	end

	--Predefined maps already contain every terrain tile. A player explores them by flipping the adjacent
	--face-down tile in place, so give the Proxy the same destinations instead of asking exploreMap() to
	--draw a new terrain tile. The same <26 edge test used by ordinary Explore buttons identifies the
	--revealed map hex from which this tile can be explored.
	if gStates.mapShapeKey=="predefined" then
		local snapshot=runtimeMapSnapshot()
		for _,tile in pairs(snapshot.terrainObjects or {}) do
			local details=terrainTiles[tile.guid]
			if details~=nil and details.tileType~="tilePile" and tile.is_face_down==true and gStates.playedAllready[tile.guid]~=true then
				local p=tile.getPosition()
				local bestHex,bestTravel,bestEdge=nil,nil,nil
				for _,hex in ipairs(hexes or {}) do
					local travel=distances[runtimeMapHexKey(hex)]
					if travel~=nil then
						local dx=hex.position[1]-p[1]
						local dz=hex.position[3]-p[3]
						local edge=(dx*dx)+(dz*dz)
						if edge<26 and (bestTravel==nil or travel<bestTravel or (travel==bestTravel and edge<bestEdge)) then
							bestHex,bestTravel,bestEdge=hex,travel,edge
						end
					end
				end
				if bestHex~=nil then
					candidates[#candidates+1]={hex=bestHex,action="explore",predefinedTileGUID=tile.guid,edge=bestEdge,proxyExplorePosition={p[1],p[2],p[3]},proxyDistance=bestTravel}
				end
			end
		end
	end

	local bestDistance=nil
	local tied={}
	for _,candidate in ipairs(candidates) do
		if bestDistance==nil or candidate.proxyDistance<bestDistance then bestDistance=candidate.proxyDistance tied={candidate}
		elseif candidate.proxyDistance==bestDistance then tied[#tied+1]=candidate end
	end
	if #tied==0 then return nil end
	local best=tied[1]
	if #tied>1 then best.proxyChoiceTargets=tied best.proxyChoiceCount=#tied end
	return best
end

function proxyCandidateForObjective(candidate,choiceColor)
	local copy={}
	for key,value in pairs(candidate or {}) do copy[key]=value end
	copy.choiceObjectiveColor=choiceColor or copy.objectiveColor
	return copy
end

function proxyChooseTarget(objective,hexes,mapObjects,proxyIndex,crystals,startHex,move)
	local colors=dummyCardColors(objective)
	local fromStart=proxyDistanceMap(hexes,{startHex},proxyIndex)
	local portal=proxyPortalHex(hexes)
	local portalDistances=portal~=nil and runtimeMapHexDistanceMap(hexes,{portal}) or {}
	local currentPortalDistance=portalDistances[runtimeMapHexKey(startHex)] or 0
	local candidates={}
	local offerCache=proxyInteractionOfferCache(crystals)
	local candidateCache={}
	local function candidatesFor(color,farther)
		local key=color..(farther==true and ":farther" or ":all")
		if candidateCache[key]==nil then candidateCache[key]=proxyTargetCandidatesForColor(color,hexes,mapObjects,proxyIndex,crystals,farther,portalDistances,currentPortalDistance,offerCache) end
		return candidateCache[key]
	end
	for _,color in ipairs(colors) do
		if color=="Blue" then
			for _,baseColor in ipairs({"Green","Red","White"}) do for _,candidate in ipairs(candidatesFor(baseColor,true)) do candidates[#candidates+1]=proxyCandidateForObjective(candidate,"Blue") end end
		else
			for _,candidate in ipairs(candidatesFor(color,false)) do candidates[#candidates+1]=proxyCandidateForObjective(candidate,color) end
		end
	end
	local function nearest(list)
		--Only collapse choices that are genuinely identical this turn: the same physical hex and same
		--action are one destination even if several objective colours qualify it. Different actions at
		--the same site remain separate choices and are shown as a split square when the choice matters.
		local unique={}
		local seen={}
		for _,candidate in ipairs(list or {}) do
			local hexKey=candidate.hex~=nil and runtimeMapHexKey(candidate.hex) or nil
			local actionKey=tostring(candidate.action or "")
			if candidate.action=="explore" then
				if candidate.button~=nil and candidate.button.attributes~=nil then actionKey=actionKey..":"..tostring(candidate.button.attributes.id or "")
				elseif candidate.predefinedTileGUID~=nil then actionKey=actionKey..":"..tostring(candidate.predefinedTileGUID) end
			end
			local key=hexKey~=nil and (hexKey.."|"..actionKey) or nil
			if key~=nil and seen[key]~=true then seen[key]=true unique[#unique+1]=candidate end
		end
		local distance=nil
		local tied={}
		for _,candidate in ipairs(unique) do
			local d=fromStart[runtimeMapHexKey(candidate.hex)]
			if d~=nil and (distance==nil or d<distance) then distance=d tied={candidate}
			elseif d~=nil and d==distance then tied[#tied+1]=candidate end
		end
		if #tied==0 then return nil end
		local best=tied[1]
		if #tied>1 then best.proxyChoiceTargets=tied best.proxyChoiceCount=#tied end
		return best
	end
	local best=nearest(candidates)
	if best~=nil then best.proxyReason=proxyObjectiveReason(colors,"direct") return best end
	best=proxyExploreTarget(hexes,fromStart)
	if best~=nil then best.proxyReason=proxyObjectiveReason(colors,"explore") return best end
	--Once exploration is unavailable, Blue drops its farther-from-Portal restriction and every colour
	--falls back to the nearest legal Green/Red/White destination.
	local fallback={}
	for _,baseColor in ipairs({"Green","Red","White"}) do
		for _,candidate in ipairs(candidatesFor(baseColor,false)) do fallback[#fallback+1]=proxyCandidateForObjective(candidate,baseColor) end
	end
	best=nearest(fallback)
	if best~=nil then best.proxyReason=proxyObjectiveReason(colors,"fallback") end
	return best
end

function proxyRouteHazard(hex,mapObjects,proxyIndex)
	local feature=string.lower(tostring(hex.feature or ""))
	if feature=="rampaging" or feature=="draconum" then
		local enemies={}
		for _,obj in pairs(mapObjects or {}) do
			if monsterPugs[obj.guid]~=nil and monsterPugs[obj.guid].name~="Ruin" then
				local pos=obj.getPosition() local dx=pos[1]-hex.position[1] local dz=pos[3]-hex.position[3]
				if (dx*dx)+(dz*dz)<1 then enemies[#enemies+1]=obj end
			end
		end
		if #enemies>0 then return {action="rampager",enemy=enemies[1],enemies=enemies,enterHex=false} end
	end
	local fortified=proxyFortifiedType(hex,mapObjects,proxyIndex)
	if fortified~=nil then return {action="fortified",fortified=fortified,enterHex=true} end
	return nil
end

function proxyRouteContext(hexes,mapObjects,proxyIndex)
	local context=proxyRouteTopology(hexes,proxyIndex)
	context.directHazard={}
	context.rampagers={}
	context.edgeHazard={}
	for _,obj in pairs(mapObjects or {}) do
		if obj~=nil and obj.guid~=nil and gStates.rampagingMonsters~=nil and gStates.rampagingMonsters[obj.guid]==true then
			local rampHex=runtimeMapHexForPosition(hexes,obj.getPosition(),mapObjects)
			local key=rampHex~=nil and runtimeMapHexKey(rampHex) or nil
			if key~=nil then context.rampagers[#context.rampagers+1]={obj=obj,key=key} end
		end
	end
	return context
end

--A normal Rampager is also provoked when the Proxy moves between two spaces adjacent to that enemy.
--Several Rampagers can be provoked by the same edge; collect all of them and resolve the fight together.
function proxyMovementHazard(fromHex,toHex,hexes,mapObjects,proxyIndex,context)
	if fromHex==nil or toHex==nil then return nil end
	local fromKey=runtimeMapHexKey(fromHex)
	local toKey=runtimeMapHexKey(toHex)
	if fromKey==nil or toKey==nil then return nil end
	local edgeKey=fromKey..">"..toKey
	if context~=nil and context.edgeHazard[edgeKey]~=nil then
		local cached=context.edgeHazard[edgeKey]
		return cached~=false and cached or nil
	end
	local direct=nil
	if context~=nil then
		direct=context.directHazard[toKey]
		if direct==nil then
			direct=proxyRouteHazard(toHex,mapObjects,proxyIndex) or false
			context.directHazard[toKey]=direct
		end
		if direct==false then direct=nil end
	else direct=proxyRouteHazard(toHex,mapObjects,proxyIndex) end
	if direct~=nil and direct.action~="rampager" then
		if context~=nil then context.edgeHazard[edgeKey]=direct end
		return direct
	end
	local enemies={}
	local seen={}
	for _,obj in ipairs(direct~=nil and direct.enemies or {}) do
		if obj~=nil and seen[obj.guid]~=true then seen[obj.guid]=true enemies[#enemies+1]=obj end
	end
	if context~=nil then
		local fromNeighbors=context.neighborSet[fromKey] or {}
		local toNeighbors=context.neighborSet[toKey] or {}
		for _,entry in ipairs(context.rampagers) do
			local obj=entry.obj
			if obj~=nil and seen[obj.guid]~=true and fromNeighbors[entry.key]==true and toNeighbors[entry.key]==true then
				seen[obj.guid]=true enemies[#enemies+1]=obj
			end
		end
	else
		for _,obj in pairs(mapObjects or {}) do
			if gStates.rampagingMonsters~=nil and gStates.rampagingMonsters[obj.guid]==true and seen[obj.guid]~=true then
				local rampHex=runtimeMapHexForPosition(hexes,obj.getPosition(),mapObjects)
				if rampHex~=nil and runtimeMapHexesAdjacent(fromHex,rampHex)==true and runtimeMapHexesAdjacent(toHex,rampHex)==true then
					seen[obj.guid]=true enemies[#enemies+1]=obj
				end
			end
		end
	end
	local hazard=nil
	if #enemies>0 then
		local enterHex=true
		if direct~=nil and direct.enterHex==false then enterHex=false end
		hazard={action="rampager",enemy=enemies[1],enemies=enemies,enterHex=enterHex,provoked=direct==nil}
	end
	if context~=nil then context.edgeHazard[edgeKey]=hazard or false end
	return hazard
end

function proxyPlanRoute(startHex,target,hexes,mapObjects,proxyIndex,move,forcedFirstKey,sharedContext)
	if startHex==nil or target==nil or target.hex==nil then return {},nil,nil end
	local context=sharedContext or proxyRouteContext(hexes,mapObjects,proxyIndex)
	local toTarget=proxyDistanceMap(hexes,{target.hex},proxyIndex,context)
	local targetKey=runtimeMapHexKey(target.hex)
	local safeMemo={}
	local function safeRun(hex)
		local key=runtimeMapHexKey(hex)
		if key==nil or key==targetKey then return 0 end
		if safeMemo[key]~=nil then return safeMemo[key] end
		local distance=toTarget[key]
		if distance==nil or distance<=0 then safeMemo[key]=0 return 0 end
		local best=-1
		for _,candidate in ipairs(context.neighbors[key] or {}) do
			if context.passable[runtimeMapHexKey(candidate)]==true and toTarget[runtimeMapHexKey(candidate)]==distance-1 then
				local hazard=proxyMovementHazard(hex,candidate,hexes,mapObjects,proxyIndex,context)
				local score=hazard~=nil and 0 or (1+safeRun(candidate))
				if score>best then best=score end
			end
		end
		if best<0 then best=0 end
		safeMemo[key]=best
		return best
	end
	local current=startHex
	local route={}
	local lastSafe=startHex
	local hazard=nil
	for step=1,move do
		if runtimeMapHexKey(current)==targetKey then break end
		local currentDistance=toTarget[runtimeMapHexKey(current)]
		if currentDistance==nil or currentDistance<=0 then break end
		local choices={}
		for _,candidate in ipairs(context.neighbors[runtimeMapHexKey(current)] or {}) do
			if context.passable[runtimeMapHexKey(candidate)]==true and toTarget[runtimeMapHexKey(candidate)]==currentDistance-1 then
				local candidateHazard=proxyMovementHazard(current,candidate,hexes,mapObjects,proxyIndex,context)
				choices[#choices+1]={hex=candidate,hazard=candidateHazard,safe=candidateHazard~=nil and 0 or (1+safeRun(candidate))}
			end
		end
		if #choices==0 then break end
		table.sort(choices,function(a,b) if a.safe~=b.safe then return a.safe>b.safe end return runtimeMapHexKey(a.hex)<runtimeMapHexKey(b.hex) end)
		local choice=choices[1]
		if step==1 and forcedFirstKey~=nil then
			local bestSafe=choices[1].safe
			for _,candidate in ipairs(choices) do if candidate.safe==bestSafe and runtimeMapHexKey(candidate.hex)==forcedFirstKey then choice=candidate break end end
		end
		local nextHex=choice.hex
		hazard=choice.hazard
		if hazard~=nil then hazard.hex=nextHex end
		if hazard==nil or hazard.enterHex~=false then route[#route+1]=nextHex end
		if hazard~=nil then break end
		lastSafe=nextHex
		current=nextHex
	end
	return route,hazard,lastSafe
end

function proxyRouteOutcomeSignature(startHex,target,route,hazard,lastSafe)
	local finalHex=(route~=nil and route[#route]) or startHex
	local finalKey=tostring(runtimeMapHexKey(finalHex) or "?")
	local targetKey=target~=nil and target.hex~=nil and runtimeMapHexKey(target.hex) or nil
	local reached=hazard==nil and targetKey~=nil and runtimeMapHexKey(finalHex)==targetKey
	if hazard==nil then
		--Two safe paths that both reach the same objective have exactly the same game result. Do not
		--ask a human merely because their intermediate/penultimate hexes differ. If neither reaches
		--this turn, the endpoint still matters because it becomes next turn's starting position.
		if reached==true then return "arrive|"..tostring(target.action or "arrive").."|"..tostring(targetKey) end
		return "move|"..finalKey
	end
	local parts={"hazard",tostring(hazard.action or "hazard"),tostring(runtimeMapHexKey(hazard.hex) or "?"),tostring(hazard.enterHex),tostring(hazard.provoked),tostring(hazard.fortified or "")}
	local enemies={}
	for _,enemy in ipairs(hazard.enemies or {}) do if enemy~=nil then enemies[#enemies+1]=tostring(enemy.guid or "") end end
	if #enemies==0 and hazard.enemy~=nil then enemies[1]=tostring(hazard.enemy.guid or "") end
	table.sort(enemies)
	parts[#parts+1]=table.concat(enemies,",")
	--For a hazard/assault, the previous safe hex can affect where the Proxy ends up after resolution
	--(for example after a retreat), so retain it as a genuinely meaningful route difference.
	parts[#parts+1]=tostring(runtimeMapHexKey(lastSafe) or "")
	return table.concat(parts,"|")
end

function proxyFindRouteChoice(startHex,target,hexes,mapObjects,proxyIndex,move)
	if startHex==nil or target==nil or target.hex==nil or (move or 0)<=0 then return nil end
	local context=proxyRouteContext(hexes,mapObjects,proxyIndex)
	local toTarget=proxyDistanceMap(hexes,{target.hex},proxyIndex,context)
	local targetKey=runtimeMapHexKey(target.hex)
	local safeMemo={}
	local function safeRun(hex)
		local key=runtimeMapHexKey(hex)
		if key==nil or key==targetKey then return 0 end
		if safeMemo[key]~=nil then return safeMemo[key] end
		local distance=toTarget[key]
		if distance==nil or distance<=0 then safeMemo[key]=0 return 0 end
		local best=-1
		for _,candidate in ipairs(context.neighbors[key] or {}) do
			if context.passable[runtimeMapHexKey(candidate)]==true and toTarget[runtimeMapHexKey(candidate)]==distance-1 then
				local h=proxyMovementHazard(hex,candidate,hexes,mapObjects,proxyIndex,context)
				local score=h~=nil and 0 or (1+safeRun(candidate))
				if score>best then best=score end
			end
		end
		if best<0 then best=0 end safeMemo[key]=best return best
	end
	local current=startHex
	local prefix={}
	for step=1,move do
		if runtimeMapHexKey(current)==targetKey then return nil,context end
		local distance=toTarget[runtimeMapHexKey(current)]
		if distance==nil or distance<=0 then return nil,context end
		local choices={}
		for _,candidate in ipairs(context.neighbors[runtimeMapHexKey(current)] or {}) do
			if context.passable[runtimeMapHexKey(candidate)]==true and toTarget[runtimeMapHexKey(candidate)]==distance-1 then
				local h=proxyMovementHazard(current,candidate,hexes,mapObjects,proxyIndex,context)
				choices[#choices+1]={hex=candidate,hazard=h,safe=h~=nil and 0 or (1+safeRun(candidate))}
			end
		end
		if #choices==0 then return nil,context end
		table.sort(choices,function(a,b) if a.safe~=b.safe then return a.safe>b.safe end return runtimeMapHexKey(a.hex)<runtimeMapHexKey(b.hex) end)
		local bestSafe=choices[1].safe
		local tied={}
		for _,choice in ipairs(choices) do if choice.safe==bestSafe then tied[#tied+1]=choice else break end end
		if #tied>1 then
			local signature=nil
			local matters=false
			local remaining=move-step+1
			for _,choice in ipairs(tied) do
				local key=runtimeMapHexKey(choice.hex)
				local route,hazard,lastSafe=proxyPlanRoute(current,target,hexes,mapObjects,proxyIndex,remaining,key,context)
				local currentSignature=proxyRouteOutcomeSignature(current,target,route,hazard,lastSafe)
				if signature==nil then signature=currentSignature elseif currentSignature~=signature then matters=true break end
			end
			if matters==true then return {prefix=prefix,choices=tied,remainingMove=remaining,current=current},context end
		end
		local choice=tied[1]
		if choice.hazard~=nil then return nil,context end
		prefix[#prefix+1]=choice.hex
		current=choice.hex
	end
	return nil,context
end

function proxyDestinationTurnSignature(startHex,target,hexes,mapObjects,proxyIndex,move,sharedContext)
	local route,hazard,lastSafe=proxyPlanRoute(startHex,target,hexes,mapObjects,proxyIndex,move,nil,sharedContext)
	local parts={}
	for _,hex in ipairs(route or {}) do parts[#parts+1]=tostring(runtimeMapHexKey(hex) or "?") end
	local finalHex=(route~=nil and route[#route]) or startHex
	local reached=hazard==nil and finalHex~=nil and target~=nil and target.hex~=nil and runtimeMapHexKey(finalHex)==runtimeMapHexKey(target.hex)
	local hazardParts={"none"}
	if hazard~=nil then
		hazardParts={tostring(hazard.action or "hazard"),tostring(runtimeMapHexKey(hazard.hex) or "?"),tostring(hazard.enterHex),tostring(hazard.provoked),tostring(hazard.fortified or "")}
		local enemies={}
		for _,enemy in ipairs(hazard.enemies or {}) do if enemy~=nil then enemies[#enemies+1]=tostring(enemy.guid or "") end end
		if #enemies==0 and hazard.enemy~=nil then enemies[1]=tostring(hazard.enemy.guid or "") end
		table.sort(enemies)
		hazardParts[#hazardParts+1]=table.concat(enemies,",")
	end
	local arrival="not-reached"
	if reached==true then
		arrival=tostring(target.action or "arrive")
		if target.action=="explore" then
			if target.button~=nil and target.button.attributes~=nil then arrival=arrival..":"..tostring(target.button.attributes.id or "")
			elseif target.predefinedTileGUID~=nil then arrival=arrival..":"..tostring(target.predefinedTileGUID) end
		end
	end
	return table.concat(parts,">").."|"..table.concat(hazardParts,":").."|"..arrival.."|"..tostring(runtimeMapHexKey(lastSafe) or "")
end

function proxyDestinationChoiceMattersThisTurn(targets,startHex,hexes,mapObjects,proxyIndex,move)
	if targets==nil or #targets<2 then return false end
	local signature=nil
	local context=proxyRouteContext(hexes,mapObjects,proxyIndex)
	for _,target in ipairs(targets) do
		local current=proxyDestinationTurnSignature(startHex,target,hexes,mapObjects,proxyIndex,move,context)
		if signature==nil then signature=current
		elseif current~=signature then return true end
	end
	return false
end

function proxyChoicePlayerIndex()
	local chosen=nil
	for index,stats in ipairs(turnOrder or {}) do
		local human=stats~=nil and (stats.seatPos or 99)<=4 and stats.mage~=gStates.positionMageKnight[5]
		if human==true and (playerDropoutInactive==nil or playerDropoutInactive(index)==false) then
			if chosen==nil or (stats.fame or 0)<(turnOrder[chosen].fame or 0) or ((stats.fame or 0)==(turnOrder[chosen].fame or 0) and index>chosen) then chosen=index end
		end
	end
	return chosen
end

function proxyChoicePlayerColor(index)
	if index==nil then return nil end
	return positionToColor(index)
end

function proxyChoicePlayerLabel(index)
	if index==nil or turnOrder[index]==nil then return "the lowest-Fame player" end
	local color=proxyChoicePlayerColor(index)
	local mage=tostring(turnOrder[index].mage or "player")
	if color~=nil and color~="Black" then return color.." ("..mage..")" end
	return mage
end

function proxyChoiceAuthorized(player,pending)
	if pending==nil then return false end
	local color=type(player)=="string" and player or (player~=nil and player.color or nil)
	local allowed=proxyChoicePlayerColor(pending.playerIndex)
	--Black is the table/controller seat and may make Proxy choices as well as the designated
	--lowest-Fame player's normal seat colour. Everyone else is rejected with a table-wide reminder.
	if color==allowed or color=="Black" then return true end
	if color~=nil then
		broadcastToAll(joinLang({proxyChoicePlayerLabel(pending.playerIndex),"{en} has the lowest Fame and must make this Proxy choice. A player seated Black may also choose.{ru} имеет наименьшую Славу и должен сделать этот выбор за Прокси. Игрок на чёрном месте также может выбрать.{zh-tw} 的聲望值最低，必須替代理玩家做出此選擇。坐在黑色席位的玩家也可以選擇。{zh-cn} 的声望值最低，必须替代理玩家做出此选择。坐在黑色席位的玩家也可以选择。{ko}의 명성이 가장 낮아 이 프록시 선택을 해야 합니다. 검은색 자리에 앉은 플레이어도 선택할 수 있습니다.{es} tiene la Fama más baja y debe tomar esta decisión del Proxy. Un jugador sentado en Negro también puede elegir.{fr} possède la Renommée la plus faible et doit faire ce choix pour le Proxy. Un joueur assis en Noir peut également choisir.{pt-br} tem a menor Fama e deve fazer esta escolha do Proxy. Um jogador sentado no Preto também pode escolher.{de} hat den niedrigsten Ruhm und muss diese Proxy-Auswahl treffen. Ein Spieler auf Schwarz darf ebenfalls wählen."}),{1,0.65,0.2})
	end
	return false
end

function proxyTargetSave(target)
	if target==nil or target.hex==nil then return nil end
	local saved={
		key=runtimeMapHexKey(target.hex),
		action=target.action,
		fortified=target.fortified,
		proxyReason=target.proxyReason,
		feature=target.hex.feature,
		choiceObjectiveColor=target.choiceObjectiveColor or target.objectiveColor
	}
	if target.action=="explore" then
		if target.button~=nil and target.button.attributes~=nil then
			saved.exploreID=target.button.attributes.id
			local p=target.proxyExplorePosition or proxyExploreButtonPosition(target.button)
			if p~=nil then saved.choicePosition={p[1],p[2],p[3]} end
		elseif target.predefinedTileGUID~=nil then
			saved.predefinedTileGUID=target.predefinedTileGUID
			local p=target.proxyExplorePosition
			if p==nil then local tile=getObjectFromGUID(target.predefinedTileGUID) if tile~=nil then p=tile.getPosition() end end
			if p~=nil then saved.choicePosition={p[1],p[2],p[3]} end
		end
	else
		saved.choicePosition={target.hex.position[1],target.hex.position[2],target.hex.position[3]}
	end
	return saved
end

function proxyTargetLoad(saved,hexes)
	if saved==nil or saved.key==nil then return nil end
	local hex=nil
	for _,candidate in ipairs(hexes or {}) do if runtimeMapHexKey(candidate)==saved.key then hex=candidate break end end
	if hex==nil then return nil end
	local target={hex=hex,action=saved.action,fortified=saved.fortified,proxyReason=saved.proxyReason,choiceObjectiveColor=saved.choiceObjectiveColor}
	if saved.action=="explore" then
		if saved.exploreID~=nil then
			for _,button in pairs(terrainExploreOptions()) do
				if button.attributes~=nil and button.attributes.id==saved.exploreID then target.button=button target.proxyExplorePosition=proxyExploreButtonPosition(button) break end
			end
			if target.button==nil then return nil end
		elseif saved.predefinedTileGUID~=nil then
			local tile=getObjectFromGUID(saved.predefinedTileGUID)
			if tile==nil or tile.is_face_down~=true then return nil end
			target.predefinedTileGUID=saved.predefinedTileGUID
			local p=tile.getPosition()
			target.proxyExplorePosition={p[1],p[2],p[3]}
		end
	end
	return target
end

function proxyDestinationChoiceClearButtons()
	local marker="ProxyDestinationChoice"
	local snapshot=runtimeMapSnapshot()
	for _,terrain in pairs(snapshot.terrainObjects or {}) do
		if terrainTiles[terrain.guid]~=nil then
			local xml=terrain.UI.getXmlTable() or {}
			local changed=false
			for i=#xml,1,-1 do
				local attributes=xml[i].attributes
				local id=attributes~=nil and tostring(attributes.id or "") or ""
				local suffix=id:sub(7)
				if suffix:sub(1,#marker)==marker then table.remove(xml,i) changed=true end
			end
			if changed==true then
				if #xml>0 then terrain.UI.setXmlTable(xml) else terrain.UI.setXml("") end
			end
		end
	end
end

function proxyDestinationChoiceActionText(saved)
	local actions={adventure="Conquer",fortified="Conquer",burn="Burn",interact="Interact",explore="Explore",route="Route"}
	local action=saved~=nil and actions[tostring(saved.action or "")] or nil
	return "Proxy\n"..tostring(action or "Choose")
end

function proxyDestinationChoiceButton(saved,index,xml,splitIndex,splitCount)
	if saved==nil or saved.key==nil then return nil,xml end
	local terrain,placement=terrainHexChoiceUIPlacement(saved.key,0.16,splitIndex,splitCount,0.38)
	if terrain==nil or placement==nil then return nil,xml end
	local id=terrain.guid.."ProxyDestinationChoice"..tostring(index)
	xml=xml or terrain.UI.getXmlTable() or {}
	xml[#xml+1]={tag="Button",attributes={id=id,onClick="global/proxyDestinationChoiceSelect",onMouseDown="global/buttonClicked",onMouseUp="global/buttonClicked",
		height=placement.height,width=320,color="rgba(0,0,0,0.0)",position=placement.x.." "..placement.y.." "..placement.depth,rotation="0 0 "..tostring(placement.rotation),scale=placement.scale.." "..placement.scale},
		children={{tag="Image",attributes={id=id.."Image",image="Sliced Button/Button Object Active",type="Sliced"}},
			{tag="HorizontalLayout",attributes={padding="20 20 12 12"},children={{tag="Text",attributes={id=id.."Text",font="Fonts/MKCardText",offsetXY="0 1",fontSize=placement.count>1 and "62" or "76",fontStyle="Normal",alignment="MiddleCenter",resizeTextForBestFit="true",resizeTextMaxSize=placement.count>1 and "62" or "76",text=proxyDestinationChoiceActionText(saved)}}}}}}
	return terrain,xml
end

function proxyChoiceMapRefresh(pending)
	--Keep the ordinary Explore controls on the map UI; Proxy destination/route choices live on the
	--actual terrain tiles so each square button floats over the exact chosen hex.
	local mapUI=getObjectFromGUID(GUID.ui.mapExplore)
	if mapUI~=nil then
		local xml={}
		for _,button in pairs(terrainExploreOptions()) do xml[#xml+1]=button end
		mapUI.UI.setXmlTable(xml)
	end
	proxyDestinationChoiceClearButtons()
	if pending~=nil and (pending.type=="destination" or pending.type=="route") then
		local byTerrain={}
		local sameHexCounts={}
		local sameHexSeen={}
		for _,saved in ipairs(pending.options or {}) do if saved~=nil and saved.key~=nil then sameHexCounts[saved.key]=(sameHexCounts[saved.key] or 0)+1 end end
		for index,saved in ipairs(pending.options or {}) do
			local terrainGUID=saved~=nil and saved.key~=nil and tostring(saved.key):match("^([^|]+)|") or nil
			local terrain=terrainGUID~=nil and getObjectFromGUID(terrainGUID) or nil
			if terrain~=nil then
				local group=byTerrain[terrainGUID]
				if group==nil then group={terrain=terrain,xml=terrain.UI.getXmlTable() or {}} byTerrain[terrainGUID]=group end
				sameHexSeen[saved.key]=(sameHexSeen[saved.key] or 0)+1
				local _,xml=proxyDestinationChoiceButton(saved,index,group.xml,sameHexSeen[saved.key],sameHexCounts[saved.key])
				group.xml=xml or group.xml
			end
		end
		for _,group in pairs(byTerrain) do group.terrain.UI.setXmlTable(group.xml) end
	end
end

function proxyChoiceWaitingText(choiceType)
	if choiceType=="destination" then return "Pick Destination" end
	if choiceType=="route" then return "Pick Route" end
	if choiceType=="card" then return "Pick Card" end
	if choiceType=="enemy" then return "Pick Enemy" end
	if choiceType=="mana" then return "Choose Source Mana" end
	return "Make Proxy Choice"
end

function proxyManaChoiceUI(pending)
	local show=pending~=nil and pending.type=="mana" and #(pending.options or {})>=2
	UI.setAttribute("DummyChoiceButtons","active",show and "true" or "false")
	UI.setAttribute("DummyButton","active",show and "false" or "true")
	if show then
		local left=pending.options[1]
		local right=pending.options[2]
		UI.setAttribute("DummyChoiceLeftText","text",joinLang({"{en}Reroll {ru}Перебросить {zh-tw}重擲 {zh-cn}重掷 {ko}다시 굴리기: {es}Relanzar {fr}Relancer {pt-br}Rerrolar {de}Neu würfeln: ",translateWord[left.color] or tostring(left.color or "{en}Mana{ru}Мана{zh-tw}魔力{zh-cn}魔力{ko}마나{es}Maná{fr}Mana{pt-br}Mana{de}Mana")}))
		UI.setAttribute("DummyChoiceRightText","text",joinLang({"{en}Reroll {ru}Перебросить {zh-tw}重擲 {zh-cn}重掷 {ko}다시 굴리기: {es}Relanzar {fr}Relancer {pt-br}Rerrolar {de}Neu würfeln: ",translateWord[right.color] or tostring(right.color or "{en}Mana{ru}Мана{zh-tw}魔力{zh-cn}魔力{ko}마나{es}Maná{fr}Mana{pt-br}Mana{de}Mana")}))
		UI.setAttribute("DummyChoiceLeft","interactable","true")
		UI.setAttribute("DummyChoiceRight","interactable","true")
		UI.setAttribute("DummyChoiceLeftImage","image","Sliced Button/Button New Active")
		UI.setAttribute("DummyChoiceRightImage","image","Sliced Button/Button New Active")
	end
end

function proxyChoiceSetWaiting(pending)
	if pending==nil then return false end
	gStates.proxyPendingChoice=pending
	if pending.type=="destination" then gStates.proxyState="PickDestination"
	elseif pending.type=="route" then gStates.proxyState="PickRoute"
	elseif pending.type=="card" then gStates.proxyState="PickCard"
	elseif pending.type=="enemy" then gStates.proxyState="PickEnemy"
	elseif pending.type=="mana" then gStates.proxyState="PickMana"
	else gStates.proxyState="Processing" end
	--Now that the waiting state is known, the shared renderer publishes the action plus choice state.
	automatedMainPanelRefresh()
	mainUIUpdate("Proxy waiting for choice")
	--A Proxy choice is a human decision and may take a while. Release the automated-turn rewind guard,
	--then start a fresh protected transaction when the authorised player actually clicks an option.
	automatedTurnRewindRelease()
	return true
end

function proxyChoiceResumeProcessing()
	gStates.proxyState="Processing"
	automatedMainPanelRefresh()
end

function proxyBeginDestinationChoice(targets,proxyIndex,move,reason)
	if targets==nil or #targets<2 then return false end
	local chooser=proxyChoicePlayerIndex()
	if chooser==nil then return false end
	local pending={type="destination",proxyIndex=proxyIndex,move=move,playerIndex=chooser,playerColor=proxyChoicePlayerColor(chooser),options={}}
	local names={}
	for _,target in ipairs(targets) do
		if target.proxyReason==nil then target.proxyReason=reason end
		local saved=proxyTargetSave(target)
		if saved~=nil and saved.choicePosition~=nil then
			pending.options[#pending.options+1]=saved
			local label=target.action=="explore" and "{en}Explore{ru}Исследовать{zh-tw}探索{zh-cn}探索{ko}탐험{es}Explorar{fr}Explorer{pt-br}Explorar{de}Erkunden" or proxyLocalizedTerm(proxyFeatureDisplayName(target.hex~=nil and target.hex.feature or nil))
			if target.choiceObjectiveColor~=nil then
				local colorLabel=translateWord[target.choiceObjectiveColor] or tostring(target.choiceObjectiveColor)
				label=joinLang({label," (",colorLabel," ",proxyDestinationChoiceActionText(saved):match("\n(.+)$"),")"})
			end
			names[#names+1]=label
		end
	end
	if #pending.options<2 then return false end
	gStates.proxyPendingChoice=pending
	proxyChoiceMapRefresh(pending)
	broadcastToAll(joinLang({"{en}Proxy has {ru}У Прокси есть {zh-tw}代理玩家有 {zh-cn}代理玩家有 {ko}프록시에게 {es}El Proxy tiene {fr}Le Proxy a {pt-br}O Proxy tem {de}Der Proxy hat ",tostring(#pending.options),"{en} equally close legal choices: {ru} равноудалённых допустимых вариантов: {zh-tw} 個距離相同的合法選擇：{zh-cn} 个距离相同的合法选择：{ko}개의 동일 거리 합법 선택지가 있습니다: {es} opciones legales igualmente cercanas: {fr} choix légaux à égale distance : {pt-br} escolhas válidas igualmente próximas: {de} gleich nahe gültige Optionen: ",proxyLocalizedList(names,", "),". ",proxyChoicePlayerLabel(chooser),"{en} must choose one.{ru} должен выбрать один.{zh-tw} 必須選擇一個。{zh-cn} 必须选择一个。{ko}이(가) 하나를 선택해야 합니다.{es} debe elegir una.{fr} doit en choisir une.{pt-br} deve escolher uma.{de} muss eine auswählen."}),{1,0.75,0.2})
	return proxyChoiceSetWaiting(pending)
end

function proxyBeginRouteChoice(routeChoice,target,proxyIndex,move)
	if routeChoice==nil or #(routeChoice.choices or {})<2 then return false end
	local chooser=proxyChoicePlayerIndex()
	if chooser==nil then return false end
	local pending={type="route",proxyIndex=proxyIndex,playerIndex=chooser,playerColor=proxyChoicePlayerColor(chooser),move=routeChoice.remainingMove or move,target=proxyTargetSave(target),prefix={},options={}}
	for _,hex in ipairs(routeChoice.prefix or {}) do pending.prefix[#pending.prefix+1]=runtimeMapHexKey(hex) end
	for _,choice in ipairs(routeChoice.choices or {}) do
		local hex=choice.hex
		if hex~=nil then pending.options[#pending.options+1]={key=runtimeMapHexKey(hex),action="route",choicePosition={hex.position[1],hex.position[2],hex.position[3]},feature=hex.feature} end
	end
	if #pending.options<2 then return false end
	gStates.proxyPendingChoice=pending
	proxyChoiceMapRefresh(pending)
	broadcastToAll(joinLang({"{en}Proxy has {ru}У Прокси есть {zh-tw}代理玩家有 {zh-cn}代理玩家有 {ko}프록시에게 {es}El Proxy tiene {fr}Le Proxy a {pt-br}O Proxy tem {de}Der Proxy hat ",tostring(#pending.options),"{en} equally direct routes toward the {ru} одинаково прямых маршрута к {zh-tw} 條同樣直接的路線通往 {zh-cn} 条同样直接的路线通往 {ko}개의 동일하게 직접적인 경로가 있습니다: {es} rutas igualmente directas hacia {fr} itinéraires tout aussi directs vers {pt-br} rotas igualmente diretas em direção a {de} gleich direkte Routen in Richtung ",proxyLocalizedTerm(proxyTargetDisplayName(target)),". ",proxyChoicePlayerLabel(chooser),"{en} must choose the next route branch.{ru} должен выбрать следующую ветвь маршрута.{zh-tw} 必須選擇下一條路線分支。{zh-cn} 必须选择下一条路线分支。{ko}이(가) 다음 경로 분기를 선택해야 합니다.{es} debe elegir la siguiente rama de la ruta.{fr} doit choisir la prochaine branche de l’itinéraire.{pt-br} deve escolher o próximo ramo da rota.{de} muss den nächsten Routenzweig wählen."}),{1,0.75,0.2})
	return proxyChoiceSetWaiting(pending)
end

function proxyRouteChoiceAnimatePrefix(pending,target,hexes,mapObjects,index,callback)
	local key=(pending.prefix or {})[index]
	if key==nil then callback() return end
	local hex=proxyHexByKey(hexes,key)
	if hex==nil then callback() return end
	proxyAnimateStep(hex,hexes,mapObjects,pending.proxyIndex,function() proxyRouteChoiceAnimatePrefix(pending,target,hexes,mapObjects,index+1,callback) end)
end

function proxyResolveRouteChoice(pending,saved)
	if pending==nil or saved==nil or gStates.turnNumber~=pending.proxyIndex then automatedTurnRewindRelease() return end
	local hexes,mapObjects=runtimeMapHexesAndObjects()
	local target=proxyTargetLoad(pending.target,hexes)
	local avatar=proxyAvatarObject()
	if target==nil or avatar==nil then proxyTurnReportSetAction("could not restore the selected route") proxyFinishTurn(hexes,mapObjects,pending.proxyIndex) return end
	proxyRouteChoiceAnimatePrefix(pending,target,hexes,mapObjects,1,function()
		local freshHexes,freshObjects=runtimeMapHexesAndObjects()
		local current=runtimeMapHexForPosition(freshHexes,avatar.getPosition(),freshObjects)
		local nextHex=proxyHexByKey(freshHexes,saved.key)
		if current==nil or nextHex==nil then proxyFinishTurn(freshHexes,freshObjects,pending.proxyIndex) return end
		local context=proxyRouteContext(freshHexes,freshObjects,pending.proxyIndex)
		local hazard=proxyMovementHazard(current,nextHex,freshHexes,freshObjects,pending.proxyIndex,context)
		if hazard~=nil then hazard.hex=nextHex end
		if hazard~=nil and hazard.enterHex==false then proxyResolveArrival(target,hazard,current,freshHexes,freshObjects,pending.proxyIndex) return end
		proxyAnimateStep(nextHex,freshHexes,freshObjects,pending.proxyIndex,function()
			if hazard~=nil then proxyResolveArrival(target,hazard,current,freshHexes,freshObjects,pending.proxyIndex)
			else proxyContinueTowardTarget(target,pending.proxyIndex,math.max(0,(pending.move or 1)-1),true) end
		end)
	end)
end

function proxyBeginManaChoice(options,proxyIndex,move,crystals)
	if options==nil or #options<2 then return false end
	local chooser=proxyChoicePlayerIndex()
	if chooser==nil then return false end
	local pending={type="mana",proxyIndex=proxyIndex,move=move,crystals=crystals,playerIndex=chooser,playerColor=proxyChoicePlayerColor(chooser),options={}}
	for _,option in ipairs(options) do pending.options[#pending.options+1]={color=option.color,guid=option.guid} end
	if #pending.options<2 then return false end
	broadcastToAll(joinLang({"{en}Proxy can use more than one matching basic Source die. {ru}Прокси может использовать несколько подходящих базовых кубиков Источника. {zh-tw}代理玩家可以使用多個符合條件的基本源泉骰。{zh-cn}代理玩家可以使用多个符合条件的基本源泉骰。{ko}프록시는 일치하는 기본 원천 주사위를 둘 이상 사용할 수 있습니다. {es}El Proxy puede usar más de un dado básico de la Fuente que coincida. {fr}Le Proxy peut utiliser plusieurs dés de Source de base correspondants. {pt-br}O Proxy pode usar mais de um dado básico da Fonte correspondente. {de}Der Proxy kann mehr als einen passenden Basis-Quellenwürfel verwenden. ",proxyChoicePlayerLabel(chooser),"{en} must choose which colour to reroll.{ru} должен выбрать, какой цвет перебросить.{zh-tw} 必須選擇要重擲的顏色。{zh-cn} 必须选择要重掷的颜色。{ko}이(가) 다시 굴릴 색을 선택해야 합니다.{es} debe elegir qué color relanzar.{fr} doit choisir quelle couleur relancer.{pt-br} deve escolher qual cor rerrolar.{de} muss wählen, welche Farbe neu gewürfelt wird."}),{1,0.75,0.2})
	return proxyChoiceSetWaiting(pending)
end

function proxyManaChoiceSelect(player,mouseButton,id)
	if mouseButton~="-1" or gStates.proxyState~="PickMana" then return end
	local pending=gStates.proxyPendingChoice
	if pending==nil or pending.type~="mana" then return end
	if proxyChoiceAuthorized(player,pending)~=true then return end
	local index=tostring(id or "")=="DummyChoiceRight" and 2 or 1
	local option=pending.options[index]
	if option==nil then return end
	gStates.proxyPendingChoice=nil
	proxyChoiceResumeProcessing()
	automatedTurnRewindStart(function()
		if gStates.turnNumber~=pending.proxyIndex then automatedTurnRewindRelease() return end
		proxyRerollSourceManaGUID(option.guid,option.color)
		proxyContinueAfterMovementSetup(pending.proxyIndex,pending.move,pending.crystals)
	end)
end

function proxyDestinationChoiceSelect(player,mouseButton,id)
	if mouseButton~="-1" then return end
	local pending=gStates.proxyPendingChoice
	if pending==nil or (pending.type~="destination" and pending.type~="route") then return end
	local expectedState=pending.type=="route" and "PickRoute" or "PickDestination"
	if gStates.proxyState~=expectedState then return end
	local index=tonumber(tostring(id or ""):match("ProxyDestinationChoice(%d+)$"))
	if index==nil or pending.options[index]==nil then return end
	if proxyChoiceAuthorized(player,pending)~=true then return end
	local saved=pending.options[index]
	proxyChoiceMapRefresh(nil)
	gStates.proxyPendingChoice=nil
	proxyChoiceResumeProcessing()
	if pending.type=="route" then
		automatedTurnRewindStart(function() proxyResolveRouteChoice(pending,saved) end)
		return
	end
	automatedTurnRewindStart(function()
		if gStates.turnNumber~=pending.proxyIndex then automatedTurnRewindRelease() return end
		local hexes,mapObjects=runtimeMapHexesAndObjects()
		local target=proxyTargetLoad(saved,hexes)
		if target==nil then proxyTurnReportSetAction("could not restore the selected destination") proxyFinishTurn(hexes,mapObjects,pending.proxyIndex) return end
		proxyContinueTowardTarget(target,pending.proxyIndex,pending.move)
	end)
end

function proxyDiscardMonster(obj)
	if obj==nil then return end
	local data=monsterPugs[obj.guid]
	local discardByType={green=GUID.bag.discard.orcs,red=GUID.bag.discard.draconum,tan=GUID.bag.discard.dungeon,purple=GUID.bag.discard.towerGarrison,white=GUID.bag.discard.cityGarrison,gray=GUID.bag.discard.keepGarrison,yellow=GUID.bag.discard.ruin}
	local discardGUID=data~=nil and discardByType[data.pugType] or nil
	local bag=discardGUID~=nil and getObjectFromGUID(discardGUID) or nil
	--Possessed enemies are two physical pieces. Detach and discard the Possessed token first so the
	--circular enemy returns to its normal discard pile without leaving stale Apocalypse bookkeeping.
	local detached=clearPossessedEnemy(obj)
	local possessedDiscard=getObjectFromGUID(GUID.bag.discard.possessed)
	for _,token in ipairs(detached or {}) do
		token.unlock()
		if possessedDiscard~=nil then possessedDiscard.putObject(token) else token.destruct() end
	end
	obj.unlock()
	if bag~=nil then bag.putObject(obj) elseif getObjectFromGUID(trashCan)~=nil then getObjectFromGUID(trashCan).putObject(obj) else obj.destruct() end
end

function proxyMonstersOnHex(hex,mapObjects)
	local list={}
	for _,obj in pairs(mapObjects or {}) do
		if monsterPugs[obj.guid]~=nil and monsterPugs[obj.guid].name~="Ruin" then
			local pos=obj.getPosition() local dx=pos[1]-hex.position[1] local dz=pos[3]-hex.position[3]
			if (dx*dx)+(dz*dz)<1.5 then list[#list+1]=obj end
		end
	end
	return list
end

function proxyRuinOnHex(hex,mapObjects)
	for _,obj in pairs(mapObjects or {}) do
		if monsterPugs[obj.guid]~=nil and monsterPugs[obj.guid].name=="Ruin" then
			local pos=obj.getPosition() local dx=pos[1]-hex.position[1] local dz=pos[3]-hex.position[3]
			if (dx*dx)+(dz*dz)<1 then return obj end
		end
	end
	return nil
end

function proxyLockShieldWhenResting(shield)
	if shield==nil then return end
	local guid=shield.guid
	--Match normal shield placement: let physics complete first, then lock only after the token rests.
	safeWaitTime("AI.Proxy",function()
		local current=getObjectFromGUID(guid)
		if current==nil then return end
		safeWaitCondition("AI.Proxy",function()
			local settled=getObjectFromGUID(guid)
			if settled~=nil then settled.lock() end
		end,function()
			local settling=getObjectFromGUID(guid)
			return settling==nil or settling.resting==true
		end)
	end,1.5)
end

function proxyTakeShield(location,lockToken,rotation)
	local bag=proxyShieldContainer()
	if bag==nil then
		if gStates.proxyShieldSupplyWarned~=true then
			gStates.proxyShieldSupplyWarned=true
			broadcastToAll("{en}Proxy Shield supply is missing; no Proxy Shield was placed.{ru}Запас щитов Прокси отсутствует; щит Прокси не размещён.{zh-tw}找不到代理玩家盾牌供應；未放置代理玩家盾牌。{zh-cn}找不到代理玩家盾牌供应；未放置代理玩家盾牌。{ko}프록시 방패 공급이 없어 프록시 방패를 배치하지 않았습니다.{es}Falta la reserva de Escudos del Proxy; no se colocó ningún Escudo del Proxy.{fr}La réserve de Boucliers du Proxy est manquante ; aucun Bouclier du Proxy n’a été placé.{pt-br}A reserva de Escudos do Proxy está ausente; nenhum Escudo do Proxy foi colocado.{de}Der Vorrat an Proxy-Schilden fehlt; es wurde kein Proxy-Schild platziert.",{1,0.25,0.25})
		end
		return nil
	end
	local shield=bag.takeObject({position=location,rotation=rotation or {0,180,0},smooth=false})
	if shield~=nil and lockToken==true then proxyLockShieldWhenResting(shield) end
	return shield
end

function proxyMultiFloorNext(hex,mapObjects)
	if hex==nil then return nil end
	local feature=string.lower(tostring(hex.feature or ""))
	if feature~="ziggurat" and feature~="pyramid" then return nil end
	local terrain=hex.terrain or getObjectFromGUID(hex.terrainGUID)
	if terrain==nil then return nil end
	local occupied={}
	local objects=mapObjects or runtimeMapSnapshot().objects or {}
	for _,obj in pairs(objects) do
		if obj~=nil and obj.getName~=nil and obj.getName()=="Shield" and volkarePursuitShieldRegistered(obj)~=true then
			local pos=obj.getPosition()
			local dx=pos[1]-hex.position[1]
			local dz=pos[3]-hex.position[3]
			if (dx*dx)+(dz*dz)<2.25 then
				local floor=zigguratPyramidFloorFromPosition(terrain,hex.position,pos)
				if floor~=nil then occupied[floor]=true end
			end
		end
	end
	for floor=1,3 do
		if occupied[floor]~=true then
			return floor,zigguratPyramidFloorPosition(terrain,hex.position,floor),{0,terrain.getRotation()[2],0}
		end
	end
	return nil
end

function proxyPlaceMapShield(hex,mapObjects)
	if hex==nil then return nil end
	local location={hex.position[1],2,hex.position[3]}
	local rotation=nil
	local feature=string.lower(tostring(hex.feature or ""))
	if feature=="ziggurat" or feature=="pyramid" then
		local floor,pos,rot=proxyMultiFloorNext(hex,mapObjects)
		if floor==nil or pos==nil then return nil end
		location=pos
		rotation=rot
	end
	return proxyTakeShield(location,true,rotation)
end


--Temporarily lift the Proxy avatar while site tokens/shields are being placed beneath it.
--This mirrors the normal player cleanup lift so newly revealed Ruin enemies can settle flat instead of striking the model.
function proxyLiftAvatarForSiteObjects(hex)
	if hex==nil then return nil end
	local avatar=proxyAvatarObject()
	if avatar==nil then return nil end
	local pos=avatar.getPosition()
	local dx=pos[1]-hex.position[1]
	local dz=pos[3]-hex.position[3]
	if (dx*dx)+(dz*dz)>=1 then return nil end
	local lift={guid=avatar.guid,position={pos[1],pos[2],pos[3]}}
	avatar.unlock()
	avatar.setPosition({pos[1],pos[2]+2,pos[3]})
	avatar.lock()
	return lift
end

function proxyRestoreAvatarAfterSiteObjects(lift,objectGUIDs)
	if lift==nil then return end
	local finished=false
	local function restore()
		if finished==true then return end
		finished=true
		local avatar=getObjectFromGUID(lift.guid)
		if avatar~=nil then
			avatar.unlock()
			avatar.setPositionSmooth({lift.position[1],lift.position[2]+1.0,lift.position[3]})
		end
	end
	safeWaitFrames("AI.Proxy",function()
		safeWaitCondition("AI.Proxy",restore,function()
			for _,guid in ipairs(objectGUIDs or {}) do
				local obj=getObjectFromGUID(guid)
				if obj~=nil and obj.resting~=true then return false end
			end
			return true
		end,1.5,restore)
	end,2)
end

function proxyPlaceCityShield(cityGUID)
	local cityZone={[cityModel.blue]=GUID.zone.blueCity,[cityModel.red]=GUID.zone.redCity,[cityModel.green]=GUID.zone.greenCity,[cityModel.white]=GUID.zone.whiteCity,[volkare.terrainHex]=volkare.discZone}
	local data=gStates.cityMonsterQty[cityGUID]
	local zone=cityZone[cityGUID]~=nil and getObjectFromGUID(cityZone[cityGUID]) or nil
	if data==nil or data.extra==nil or zone==nil then return nil end
	data.extra.shieldsThere=data.extra.shieldsThere or 0
	local location={zone.getPosition()[1]+(-2+data.extra.shieldsThere),1.13,zone.getPosition()[3]+1}
	if data.extra.shieldsThere>4 then location[1]=location[1]-5 location[3]=location[3]-0.5 end
	local shield=proxyTakeShield(location,true)
	if shield~=nil then data.extra.shieldsThere=data.extra.shieldsThere+1 end
	return shield
end

function proxyRemoveOtherKeepShield(hex,mapObjects,proxyIndex)
	local mage=turnOrder[proxyIndex].mage
	for _,obj in pairs(mapObjects or {}) do
		if obj.getName()=="Shield" and obj.getDescription()~=mage and obj.getDescription()~="Neutral" then
			local pos=obj.getPosition() local dx=pos[1]-hex.position[1] local dz=pos[3]-hex.position[3]
			if (dx*dx)+(dz*dz)<1 then obj.destruct() return end
		end
	end
end

function proxyHexByKey(hexes,key)
	if key==nil then return nil end
	for _,hex in ipairs(hexes or {}) do if runtimeMapHexKey(hex)==key then return hex end end
	return nil
end

function proxyLowestFameEnemies(enemies)
	local lowest=nil
	local tied={}
	for _,enemy in ipairs(enemies or {}) do
		local obj=type(enemy)=="string" and getObjectFromGUID(enemy) or enemy
		if obj~=nil and monsterPugs[obj.guid]~=nil then
			local fame=monsterPugs[obj.guid].fame or 99
			if lowest==nil or fame<lowest then lowest=fame tied={obj}
			elseif fame==lowest then tied[#tied+1]=obj end
		end
	end
	return tied,lowest
end

function proxyEnemyChoiceSnapshot(enemy)
	if enemy==nil then return nil end
	return {guid=enemy.guid,name=((monsterPugs[enemy.guid] or {}).name or enemy.getName() or "enemy"),ui=enemy.UI.getXmlTable() or {}}
end

function proxyEnemyChoiceButton(enemy)
	if enemy==nil then return end
	local id=enemy.guid.."ProxyEnemyChoice"
	enemy.UI.setXmlTable({{tag="Button",attributes={id=id,onClick="global/proxyEnemyChoiceSelect",onMouseDown="global/buttonClicked",onMouseUp="global/buttonClicked",
		height=150,width=500,position="0 190 -10",rotation="0 0 180",scale="0.32 0.32",color="rgba(0,0,0,0.0)"},
		children={{tag="Image",attributes={id=id.."Image",image="Sliced Button/Button Object Active",type="Sliced"}},
			{tag="HorizontalLayout",attributes={padding="25 25 25 25"},children={{tag="Text",attributes={id=id.."Text",font="Fonts/MKCardText",fontSize="82",fontStyle="Normal",alignment="MiddleCenter",resizeTextForBestFit="true",resizeTextMaxSize="82",text="{en}CHOOSE FOR PROXY{ru}ВЫБОР ЗА ПРОКСИ{zh-tw}為代理玩家選擇{zh-cn}为代理玩家选择{ko}프록시 선택{es}ELEGIR POR EL PROXY{fr}CHOISIR POUR LE PROXY{pt-br}ESCOLHER PELO PROXY{de}FÜR PROXY WÄHLEN"}}}}}}})
end

function proxyEnemyChoiceClearButtons(pending)
	if pending==nil or pending.type~="enemy" then return end
	for guid,snap in pairs(pending.options or {}) do
		local enemy=getObjectFromGUID(guid)
		if enemy~=nil then
			if snap.ui~=nil and #snap.ui>0 then enemy.UI.setXmlTable(snap.ui) else setMonsterObjectButtons(enemy) end
		end
	end
end

function proxyBeginEnemyChoice(enemies,context,proxyIndex)
	if enemies==nil or #enemies<2 then return false end
	local chooser=proxyChoicePlayerIndex()
	if chooser==nil then return false end
	local pending={type="enemy",proxyIndex=proxyIndex,playerIndex=chooser,playerColor=proxyChoicePlayerColor(chooser),context=context,options={},order={}}
	local names={}
	for _,enemy in ipairs(enemies) do
		local snap=proxyEnemyChoiceSnapshot(enemy)
		if snap~=nil then
			pending.options[snap.guid]=snap
			pending.order[#pending.order+1]=snap.guid
			names[#names+1]=snap.name
		end
	end
	if #pending.order<2 then return false end
	gStates.proxyPendingChoice=pending
	for _,guid in ipairs(pending.order) do local enemy=getObjectFromGUID(guid) if enemy~=nil then proxyEnemyChoiceButton(enemy) end end
	broadcastToAll(joinLang({"{en}Proxy must choose between tied lowest-Fame enemies: {ru}Прокси должен выбрать между врагами с одинаковой наименьшей Славой: {zh-tw}代理玩家必須在聲望值同為最低的敵人中選擇：{zh-cn}代理玩家必须在声望值同为最低的敌人中选择：{ko}프록시는 명성이 공동 최저인 적 중 선택해야 합니다: {es}El Proxy debe elegir entre los enemigos empatados con la Fama más baja: {fr}Le Proxy doit choisir parmi les ennemis à égalité pour la Renommée la plus faible : {pt-br}O Proxy deve escolher entre os inimigos empatados com a menor Fama: {de}Der Proxy muss zwischen den Gegnern mit gleich niedrigstem Ruhm wählen: ",proxyLocalizedList(names,", "),". ",proxyChoicePlayerLabel(chooser),"{en} must choose one.{ru} должен выбрать одного.{zh-tw} 必須選擇一個。{zh-cn} 必须选择一个。{ko}이(가) 하나를 선택해야 합니다.{es} debe elegir uno.{fr} doit en choisir un.{pt-br} deve escolher um.{de} muss einen auswählen."}),{1,0.75,0.2})
	return proxyChoiceSetWaiting(pending)
end

function proxyResolveCitySelectedEnemy(hex,mapObjects,proxyIndex,lastSafe,selectedGUID)
	local city=proxyCityGUIDForHex(hex)
	if city==nil then return end
	local alive=proxyCityAliveEnemies(city)
	local chosen=selectedGUID
	local found=false
	for _,guid in ipairs(alive) do if guid==chosen then found=true break end end
	if found~=true then
		local lowest=proxyLowestFameEnemies(alive)
		chosen=lowest[1]~=nil and lowest[1].guid or nil
	end
	local defeatedName=nil
	if chosen~=nil then
		local enemy=getObjectFromGUID(chosen)
		if enemy~=nil then
			defeatedName=((monsterPugs[enemy.guid] or {}).name or enemy.getName() or "enemy")
			proxyDiscardMonster(enemy)
		end
		if gStates.cityMonsterQty[city]~=nil then gStates.cityMonsterQty[city][chosen]="dead" end
	end
	proxyPlaceCityShield(city)
	refreshCityDefeatState()
	local cityRemaining=#proxyCityAliveEnemies(city)
	if cityRemaining>0 then proxyTurnReportSetAction("defeated "..tostring(defeatedName or "an enemy").." in the City and retreated")
	else proxyTurnReportSetAction("conquered the City") end
	if cityRemaining>0 and lastSafe~=nil then
		local avatar=proxyAvatarObject()
		if avatar~=nil then avatar.unlock() avatar.setPositionSmooth({lastSafe.position[1],1.5,lastSafe.position[3]}) end
	end
end

function proxyResolveEnemyChoice(pending,selectedGUID)
	if pending==nil or pending.context==nil then automatedTurnRewindRelease() return end
	local hexes,mapObjects=runtimeMapHexesAndObjects()
	local hex=proxyHexByKey(hexes,pending.context.hexKey)
	if hex==nil then proxyFinishTurn(hexes,mapObjects,pending.proxyIndex) return end
	if pending.context.kind=="ruin" then
		local enemy=getObjectFromGUID(selectedGUID)
		local enemyName=enemy~=nil and ((monsterPugs[enemy.guid] or {}).name or enemy.getName() or "enemy") or "enemy"
		local lift=proxyLiftAvatarForSiteObjects(hex)
		if enemy~=nil then proxyDiscardMonster(enemy) end
		proxyRestoreAvatarAfterSiteObjects(lift,{})
		proxyTurnReportSetAction("defeated "..tostring(enemyName).." at the Ruins")
		proxyClearObjective(true)
		broadcastToAll("{en}Proxy resolved the tied Ruins enemy choice.{ru}Прокси разрешил ничью при выборе врага в Руинах.{zh-tw}代理玩家已解決遺跡敵人選擇的平手。{zh-cn}代理玩家已解决遗迹敌人选择的平手。{ko}프록시가 유적 적 선택의 동률을 해결했습니다.{es}El Proxy resolvió el empate en la elección de enemigo de las Ruinas.{fr}Le Proxy a résolu l’égalité du choix d’ennemi des Ruines.{pt-br}O Proxy resolveu o empate na escolha de inimigo das Ruínas.{de}Der Proxy hat den Gleichstand bei der Gegnerwahl in den Ruinen aufgelöst.",{1,0.75,0.2})
	elseif pending.context.kind=="city" then
		local lastSafe=proxyHexByKey(hexes,pending.context.lastSafeKey)
		proxyResolveCitySelectedEnemy(hex,mapObjects,pending.proxyIndex,lastSafe,selectedGUID)
		proxyClearObjective(true)
		broadcastToAll("{en}Proxy resolved the tied City defender choice.{ru}Прокси разрешил ничью при выборе защитника Города.{zh-tw}代理玩家已解決城市防守者選擇的平手。{zh-cn}代理玩家已解决城市防守者选择的平手。{ko}프록시가 도시 수비자 선택의 동률을 해결했습니다.{es}El Proxy resolvió el empate en la elección de defensor de la Ciudad.{fr}Le Proxy a résolu l’égalité du choix de défenseur de la Cité.{pt-br}O Proxy resolveu o empate na escolha de defensor da Cidade.{de}Der Proxy hat den Gleichstand bei der Verteidigerwahl der Stadt aufgelöst.",{1,0.75,0.2})
	end
	safeWaitTime("AI.Proxy",function()
		local freshHexes,freshObjects=runtimeMapHexesAndObjects()
		proxyFinishTurn(freshHexes,freshObjects,pending.proxyIndex)
	end,1.1)
end

function proxyEnemyChoiceSelect(player,mouseButton,id)
	if mouseButton~="-1" or gStates.proxyState~="PickEnemy" then return end
	local buttonID=tostring(id or "")
	local guid=buttonID:sub(1,6)
	local pending=gStates.proxyPendingChoice
	if buttonID:sub(7)~="ProxyEnemyChoice" or pending==nil or pending.type~="enemy" or pending.options[guid]==nil then return end
	if proxyChoiceAuthorized(player,pending)~=true then return end
	proxyEnemyChoiceClearButtons(pending)
	gStates.proxyPendingChoice=nil
	proxyChoiceResumeProcessing()
	automatedTurnRewindStart(function() proxyResolveEnemyChoice(pending,guid) end)
end

function proxyResolveRampager(target,mapObjects)
	local enemies={}
	local seen={}
	for _,enemy in ipairs(target~=nil and target.enemies or {}) do
		if enemy~=nil and seen[enemy.guid]~=true then seen[enemy.guid]=true enemies[#enemies+1]=enemy end
	end
	if #enemies==0 and target~=nil and target.enemy~=nil then enemies[1]=target.enemy end
	if #enemies==0 and target~=nil and target.hex~=nil then enemies=proxyMonstersOnHex(target.hex,mapObjects) end
	local names={}
	for _,enemy in ipairs(enemies) do
		if enemy~=nil then
			names[#names+1]=tostring(((monsterPugs[enemy.guid] or {}).name or enemy.getName() or "enemy"))
			proxyDiscardMonster(enemy)
		end
	end
	if #names<=1 then proxyTurnReportSetAction("defeated the rampaging "..tostring(names[1] or "enemy"))
	else proxyTurnReportSetAction("defeated "..tostring(#names).." rampaging enemies") end
	broadcastToAll(#names<=1 and "{en}Proxy discarded a rampaging enemy.{ru}Прокси сбросил Бродячего врага.{zh-tw}代理玩家棄掉了一個遊蕩敵人。{zh-cn}代理玩家弃掉了一个游荡敌人。{ko}프록시가 방랑 적 하나를 버렸습니다.{es}El Proxy descartó un enemigo arrasador.{fr}Le Proxy a défaussé un ennemi ravageur.{pt-br}O Proxy descartou um inimigo errante.{de}Der Proxy hat einen streunenden Gegner abgeworfen." or joinLang({"{en}Proxy discarded {ru}Прокси сбросил {zh-tw}代理玩家棄掉了 {zh-cn}代理玩家弃掉了 {ko}프록시가 방랑 적 {es}El Proxy descartó {fr}Le Proxy a défaussé {pt-br}O Proxy descartou {de}Der Proxy hat ",tostring(#names),"{en} rampaging enemies.{ru} Бродячих врагов.{zh-tw} 個遊蕩敵人。{zh-cn} 个游荡敌人。{ko}명을 버렸습니다.{es} enemigos arrasadores.{fr} ennemis ravageurs.{pt-br} inimigos errantes.{de} streunende Gegner abgeworfen."}),{1,0.75,0.2})
	proxyClearObjective(true)
	return true
end

function proxyResolveAdventure(hex,mapObjects,proxyIndex)
	local feature=string.lower(tostring(hex.feature or ""))
	local reportAction=nil
	local lift=proxyLiftAvatarForSiteObjects(hex)
	local settleGUIDs={}
	local function settle(obj) if obj~=nil then settleGUIDs[#settleGUIDs+1]=obj.guid end end
	if feature=="ruin" then
		local ruin=proxyRuinOnHex(hex,mapObjects)
		local enemies=proxyMonstersOnHex(hex,mapObjects)
		settle(ruin)
		for _,enemy in ipairs(enemies) do settle(enemy) end
		if ruin~=nil and #enemies==0 and monsterPugs[ruin.guid]~=nil and monsterPugs[ruin.guid].monsters~=nil then
			for a,pugType in ipairs(monsterPugs[ruin.guid].monsters) do
				local bag=getObjectFromGUID(monsterPiles[pugType])
				if bag~=nil and bag.getQuantity()>0 then
					local enemy=bag.takeObject({position={hex.position[1]+((a-1)*0.28),2+(a*0.15),hex.position[3]+0.25},rotation={0,180,0},smooth=false})
					if enemy~=nil then
						if enemy.is_face_down==true then enemy.flip() end
						enemies[#enemies+1]=enemy
						settle(enemy)
					end
				end
			end
		end
		if #enemies>0 then
			local lowest=proxyLowestFameEnemies(enemies)
			if #lowest>1 and proxyBeginEnemyChoice(lowest,{kind="ruin",hexKey=runtimeMapHexKey(hex)},proxyIndex)==true then
				proxyRestoreAvatarAfterSiteObjects(lift,settleGUIDs)
				return false
			end
			local defeated=lowest[1] or enemies[1]
			local defeatedName=(defeated~=nil and monsterPugs[defeated.guid]~=nil and monsterPugs[defeated.guid].name) or "enemy"
			proxyDiscardMonster(defeated)
			if #enemies==1 then
				if ruin~=nil then proxyDiscardMonster(ruin) end
				settle(proxyPlaceMapShield(hex,mapObjects))
				reportAction="defeated "..tostring(defeatedName).." and conquered the Ruins"
			else reportAction="defeated "..tostring(defeatedName).." at the Ruins" end
		else
			if ruin~=nil then proxyDiscardMonster(ruin) end
			settle(proxyPlaceMapShield(hex,mapObjects))
			reportAction="conquered the Ruins"
		end
	else
		for _,enemy in ipairs(proxyMonstersOnHex(hex,mapObjects)) do proxyDiscardMonster(enemy) end
		settle(proxyPlaceMapShield(hex,mapObjects))
		reportAction="conquered the "..proxyFeatureDisplayName(hex.feature)
	end
	proxyRestoreAvatarAfterSiteObjects(lift,settleGUIDs)
	proxyTurnReportSetAction(reportAction or ("resolved the "..proxyFeatureDisplayName(hex.feature)))
	broadcastToAll("{en}Proxy resolved an adventure site.{ru}Прокси разрешил место приключения.{zh-tw}代理玩家已完成一個冒險地點。{zh-cn}代理玩家已完成一个冒险地点。{ko}프록시가 모험 장소를 해결했습니다.{es}El Proxy resolvió un lugar de aventura.{fr}Le Proxy a résolu un site d’aventure.{pt-br}O Proxy resolveu um local de aventura.{de}Der Proxy hat einen Abenteuerort abgewickelt.",{1,0.75,0.2})
	proxyClearObjective(true)
	return true
end

function proxyResolveFortified(hex,mapObjects,proxyIndex,lastSafe)
	local fortified=proxyFortifiedType(hex,mapObjects,proxyIndex)
	if fortified=="city" then
		local city=proxyCityGUIDForHex(hex)
		local alive=proxyCityAliveEnemies(city)
		local lowest=proxyLowestFameEnemies(alive)
		if #lowest>1 and proxyBeginEnemyChoice(lowest,{kind="city",hexKey=runtimeMapHexKey(hex),lastSafeKey=lastSafe~=nil and runtimeMapHexKey(lastSafe) or nil},proxyIndex)==true then return false end
		local selected=lowest[1]~=nil and lowest[1].guid or nil
		proxyResolveCitySelectedEnemy(hex,mapObjects,proxyIndex,lastSafe,selected)
	elseif fortified~=nil then
		local lift=proxyLiftAvatarForSiteObjects(hex)
		for _,enemy in ipairs(proxyMonstersOnHex(hex,mapObjects)) do proxyDiscardMonster(enemy) end
		if fortified=="keep" then proxyRemoveOtherKeepShield(hex,mapObjects,proxyIndex) end
		local shield=proxyPlaceMapShield(hex,mapObjects)
		proxyRestoreAvatarAfterSiteObjects(lift,shield~=nil and {shield.guid} or {})
		proxyTurnReportSetAction("conquered the "..proxyFeatureDisplayName(fortified))
	end
	broadcastToAll("{en}Proxy resolved a fortified site.{ru}Прокси разрешил укреплённое место.{zh-tw}代理玩家已完成一個要塞地點。{zh-cn}代理玩家已完成一个要塞地点。{ko}프록시가 요새 장소를 해결했습니다.{es}El Proxy resolvió un lugar fortificado.{fr}Le Proxy a résolu un site fortifié.{pt-br}O Proxy resolveu um local fortificado.{de}Der Proxy hat einen befestigten Ort abgewickelt.",{1,0.75,0.2})
	proxyClearObjective(true)
	return true
end

function proxyReturnOfferCard(card)
	if card==nil then return end
	local cardType=gameCardType(card)
	local zoneByType={["Regular Unit"]=GUID.zone.regularUnit,["Elite Unit"]=GUID.zone.eliteUnit,["Advanced Action"]=GUID.zone.actionDeck,["Spell"]=GUID.zone.spellDeck}
	local zone=zoneByType[cardType]~=nil and getObjectFromGUID(zoneByType[cardType]) or nil
	card.unlock()
	if zone~=nil then
		standardDeckCycleMarkReturned(cardType,card)
		local pile=standardDeckCycleObject(cardType)
		if pile~=nil and pile.guid~=card.guid then putCardAtBottom(pile,card)
		else
			--A temporarily empty source zone has nothing to merge with; leave the returned card at the
			--source-deck position so it becomes the live one-card source pile.
			local p=zone.getPosition()
			card.setPosition({p[1],p[2]+1.0,p[3]})
			card.setRotation({0,180,180})
		end
	elseif getObjectFromGUID(trashCan)~=nil then getObjectFromGUID(trashCan).putObject(card) end
end

function proxyInteractionChoiceButton(card)
	if card==nil then return end
	local id=card.guid.."ProxyInteractionChoice"
	card.UI.setXmlTable({{tag="Button",attributes={id=id,onClick="global/proxyInteractionChoiceSelect",onMouseDown="global/buttonClicked",onMouseUp="global/buttonClicked",
		height=150,width=500,position="0 190 -10",rotation="0 0 180",scale="0.32 0.32",color="rgba(0,0,0,0.0)"},
		children={{tag="Image",attributes={id=id.."Image",image="Sliced Button/Button Object Active",type="Sliced"}},
			{tag="HorizontalLayout",attributes={padding="25 25 25 25"},children={{tag="Text",attributes={id=id.."Text",font="Fonts/MKCardText",fontSize="82",fontStyle="Normal",alignment="MiddleCenter",resizeTextForBestFit="true",resizeTextMaxSize="82",text="{en}CHOOSE FOR PROXY{ru}ВЫБОР ЗА ПРОКСИ{zh-tw}為代理玩家選擇{zh-cn}为代理玩家选择{ko}프록시 선택{es}ELEGIR POR EL PROXY{fr}CHOISIR POUR LE PROXY{pt-br}ESCOLHER PELO PROXY{de}FÜR PROXY WÄHLEN"}}}}}}})
end

function proxyInteractionChoiceSnapshot(choice)
	if choice==nil or choice.card==nil then return nil end
	local card=choice.card
	return {guid=card.guid,kind=choice.kind,cost=choice.cost,name=proxyCardDisplayName(card),ui=card.UI.getXmlTable() or {}}
end

function proxyInteractionChoiceClearButtons(pending)
	if pending==nil or pending.type~="card" then return end
	for guid,snap in pairs(pending.options or {}) do
		local card=getObjectFromGUID(guid)
		if card~=nil then
			if snap.ui~=nil and #snap.ui>0 then card.UI.setXmlTable(snap.ui) else card.UI.setXmlTable({{}}) end
		end
	end
end

function proxyTakeInteractionChoice(choice)
	if choice==nil or choice.card==nil then return false end
	local cardName=proxyCardDisplayName(choice.card)
	local kind=choice.kind=="unit" and "Unit" or (choice.kind=="spell" and "Spell" or "Advanced Action")
	proxyTurnReportSetAction("took "..cardName.." ("..kind..") from the offer")
	proxyReturnOfferCard(choice.card)
	if choice.kind~="unit" then safeWaitFrames("AI.Proxy",function() fillSlide() end,2) end
	proxyClearObjective(true)
	broadcastToAll(joinLang({"{en}Proxy took {ru}Прокси взял {zh-tw}代理玩家從供應中取得 {zh-cn}代理玩家从供应中取得 {ko}프록시가 제안에서 {es}El Proxy tomó {fr}Le Proxy a pris {pt-br}O Proxy pegou {de}Der Proxy nahm ",cardName,"{en} from the offer.{ru} из предложения.{zh-tw}。{zh-cn}。{ko}을(를) 가져갔습니다.{es} de la oferta.{fr} dans l’offre.{pt-br} da oferta.{de} aus dem Angebot."}),{1,0.75,0.2})
	return true
end

function proxyBeginCardChoice(choices,proxyIndex)
	if choices==nil or #choices<2 then return false end
	local chooser=proxyChoicePlayerIndex()
	if chooser==nil then return false end
	local pending={type="card",proxyIndex=proxyIndex,playerIndex=chooser,playerColor=proxyChoicePlayerColor(chooser),options={},order={}}
	local names={}
	for _,choice in ipairs(choices) do
		local snap=proxyInteractionChoiceSnapshot(choice)
		if snap~=nil and pending.options[snap.guid]==nil then
			pending.options[snap.guid]=snap
			pending.order[#pending.order+1]=snap.guid
			names[#names+1]=snap.name
		end
	end
	if #pending.order<2 then return false end
	gStates.proxyPendingChoice=pending
	for _,guid in ipairs(pending.order) do local card=getObjectFromGUID(guid) if card~=nil then proxyInteractionChoiceButton(card) end end
	broadcastToAll(joinLang({"{en}Proxy has {ru}У Прокси есть {zh-tw}代理玩家有 {zh-cn}代理玩家有 {ko}프록시에게 {es}El Proxy tiene {fr}Le Proxy a {pt-br}O Proxy tem {de}Der Proxy hat ",tostring(#pending.order),"{en} equally valid lowest-cost cards: {ru} равно допустимых карт с наименьшей стоимостью: {zh-tw} 張同樣有效且費用最低的牌：{zh-cn} 张同样有效且费用最低的牌：{ko}개의 동일하게 유효한 최저 비용 카드가 있습니다: {es} cartas de coste mínimo igualmente válidas: {fr} cartes de coût minimal également valides : {pt-br} cartas de menor custo igualmente válidas: {de} gleich gültige Karten mit den niedrigsten Kosten: ",proxyLocalizedList(names,", "),". ",proxyChoicePlayerLabel(chooser),"{en} must choose one.{ru} должен выбрать одну.{zh-tw} 必須選擇一張。{zh-cn} 必须选择一张。{ko}이(가) 하나를 선택해야 합니다.{es} debe elegir una.{fr} doit en choisir une.{pt-br} deve escolher uma.{de} muss eine auswählen."}),{1,0.75,0.2})
	return proxyChoiceSetWaiting(pending)
end

function proxyInteractionChoiceSelect(player,mouseButton,id)
	if mouseButton~="-1" or gStates.proxyState~="PickCard" then return end
	local buttonID=tostring(id or "")
	local guid=buttonID:sub(1,6)
	local pending=gStates.proxyPendingChoice
	if buttonID:sub(7)~="ProxyInteractionChoice" or pending==nil or pending.type~="card" or pending.options[guid]==nil then return end
	if proxyChoiceAuthorized(player,pending)~=true then return end
	local snap=pending.options[guid]
	proxyInteractionChoiceClearButtons(pending)
	gStates.proxyPendingChoice=nil
	proxyChoiceResumeProcessing()
	automatedTurnRewindStart(function()
		local card=getObjectFromGUID(guid)
		if card~=nil then proxyTakeInteractionChoice({card=card,kind=snap.kind,cost=snap.cost})
		else proxyTurnReportSetAction("could not find the selected offer card") proxyClearObjective(true) end
		safeWaitTime("AI.Proxy",function()
			local hexes,mapObjects=runtimeMapHexesAndObjects()
			proxyFinishTurn(hexes,mapObjects,pending.proxyIndex)
		end,1.1)
	end)
end

function proxyResolveInteraction(choice,choices,proxyIndex)
	if choices~=nil and #choices>1 and proxyBeginCardChoice(choices,proxyIndex)==true then return false end
	if choice~=nil and choice.card~=nil then proxyTakeInteractionChoice(choice)
	else
		proxyTurnReportSetAction("found no legal card to take at the interaction site")
		proxyClearObjective(true)
	end
	return true
end

function proxyResolveExplore(target)
	if target~=nil and target.predefinedTileGUID~=nil then
		local tile=getObjectFromGUID(target.predefinedTileGUID)
		if tile~=nil and tile.is_face_down==true then
			--Use the same TTS flip animation as a player. The tile leaves/re-enters the map scripting zone,
			--so the ordinary terrain-entry handler remains the single authority for population/reveal logic.
			tile.flip()
			proxyTurnReportSetAction("explored a predefined tile")
			broadcastToAll("{en}Proxy explored a predefined terrain tile.{ru}Прокси исследовал предопределённую плитку местности.{zh-tw}代理玩家探索了一個預設地形板塊。{zh-cn}代理玩家探索了一个预设地形板块。{ko}프록시가 미리 정해진 지형 타일을 탐험했습니다.{es}El Proxy exploró una loseta de terreno predefinida.{fr}Le Proxy a exploré une tuile de terrain prédéfinie.{pt-br}O Proxy explorou uma peça de terreno predefinida.{de}Der Proxy hat ein vordefiniertes Geländeplättchen erkundet.",{1,0.75,0.2})
			proxyClearObjective(true)
		end
	elseif target~=nil and target.button~=nil and target.button.attributes~=nil and target.button.attributes.id~=nil then
		exploreMap({color="Black"},"-1",target.button.attributes.id)
		proxyTurnReportSetAction("explored a new tile")
		broadcastToAll("{en}Proxy explored a new tile.{ru}Прокси исследовал новую плитку.{zh-tw}代理玩家探索了一個新板塊。{zh-cn}代理玩家探索了一个新板块。{ko}프록시가 새 타일을 탐험했습니다.{es}El Proxy exploró una nueva loseta.{fr}Le Proxy a exploré une nouvelle tuile.{pt-br}O Proxy explorou uma nova peça.{de}Der Proxy hat ein neues Plättchen erkundet.",{1,0.75,0.2})
		proxyClearObjective(true)
	end
	return true
end

function proxyFinishTurn(hexes,mapObjects,proxyIndex)
	proxyIndex=proxyIndex or gStates.turnNumber
	local stats=turnOrder[proxyIndex]
	local avatar=proxyAvatarObject()
	if stats~=nil and avatar~=nil then
		refreshAvatarLocationOnly(proxyIndex,avatar)
		portalSwap("endOfTurn",proxyIndex)
	end
	if stats~=nil then stats.dummyProcessedThisTurn=true dummyRefreshDeedState(stats.seatPos) end
	gStates.proxyState="ReadyToEnd"
	gStates.proxyPendingChoice=nil
	automatedMainPanelRefresh()
	mainUIUpdate("Proxy ready to end")
	automatedTurnRewindRelease()
end

function proxyResolveBurn(hex,mapObjects)
	if hex==nil then return true end
	local lift=proxyLiftAvatarForSiteObjects(hex)
	local shield=proxyPlaceMapShield(hex,mapObjects)
	proxyRestoreAvatarAfterSiteObjects(lift,shield~=nil and {shield.guid} or {})
	proxyTurnReportSetAction("burned the Monastery")
	proxyClearObjective(true)
	broadcastToAll("{en}Proxy burned a monastery.{ru}Прокси сжёг Монастырь.{zh-tw}代理玩家焚毀了一座修道院。{zh-cn}代理玩家焚毁了一座修道院。{ko}프록시가 수도원을 불태웠습니다.{es}El Proxy quemó un monasterio.{fr}Le Proxy a brûlé un monastère.{pt-br}O Proxy queimou um mosteiro.{de}Der Proxy hat ein Kloster niedergebrannt.",{1,0.75,0.2})
	return true
end

function proxyResolveArrival(target,hazard,lastSafe,hexes,mapObjects,proxyIndex)
	local completed=true
	if hazard~=nil then
		if hazard.action=="rampager" then completed=proxyResolveRampager(hazard,mapObjects)
		elseif hazard.action=="fortified" then completed=proxyResolveFortified(hazard.hex or (target~=nil and target.hex or nil),mapObjects,proxyIndex,lastSafe) end
	elseif target~=nil then
		if target.action=="adventure" then completed=proxyResolveAdventure(target.hex,mapObjects,proxyIndex)
		elseif target.action=="fortified" then completed=proxyResolveFortified(target.hex,mapObjects,proxyIndex,lastSafe)
		elseif target.action=="burn" then completed=proxyResolveBurn(target.hex,mapObjects)
		elseif target.action=="interact" then
			--Destination and purchase are separate decisions. Re-evaluate the offer only after the Proxy
			--actually reaches the chosen White site, then pause only if the cheapest legal cards tie.
			local crystals=proxySnapshotCrystals(turnOrder[proxyIndex])
			local choices=proxyInteractionBestChoices(proxyInteractionOptions(target.hex,mapObjects,proxyIndex,crystals,proxyInteractionOfferCache(crystals)))
			completed=proxyResolveInteraction(choices[1],choices,proxyIndex)
		elseif target.action=="explore" then completed=proxyResolveExplore(target) end
	end
	if completed~=false then safeWaitTime("AI.Proxy",function() proxyFinishTurn(hexes,mapObjects,proxyIndex) end,1.1) end
end

function proxyRevealGarrisonsAtHex(hex,hexes,mapObjects,proxyIndex)
	if hex==nil or gStates.autoFlip~=true then return end
	local revealHexes={hex}
	for _,nearHex in ipairs(hexes or {}) do
		if runtimeMapHexKey(nearHex)~=runtimeMapHexKey(hex) and runtimeMapHexesAdjacent(hex,nearHex)==true then revealHexes[#revealHexes+1]=nearHex end
	end
	local revealed=false
	for _,revealHex in ipairs(revealHexes) do
		if apocalypseQuestFeatureIsCity(revealHex.feature)==true then
			local city=proxyCityGUIDForHex(revealHex)
			for _,guid in ipairs(proxyCityAliveEnemies(city)) do
				local enemy=getObjectFromGUID(guid)
				if enemy~=nil and enemy.is_face_down==true then enemy.flip() revealed=true end
			end
		end
		if gStates.dayRound==true then
			for _,obj in pairs(mapObjects or {}) do
				if monsterPugs[obj.guid]~=nil then
					local pos=obj.getPosition()
					local dx=pos[1]-revealHex.position[1]
					local dz=pos[3]-revealHex.position[3]
					if (dx*dx)+(dz*dz)<1.25 then
						local values=obj.getRotationValues() or {}
						local second=values[2]
						local value=second~=nil and tostring(second.value or "") or ""
						if value=="Mage Tower Garrison" or value=="Keep Garrison" or value=="Marauding Elementalist" then
							if obj.is_face_down==true then obj.flip() revealed=true end
						end
					end
				end
			end
		end
	end
	if revealed==true then broadcastToAll("{en}Site Garrison Revealed{ru}Гарнизон Укрепленного места раскрыт{zh-tw}守军揭示了{zh-cn}守军揭示了{ko}수비자가 공개되었습니다.{es}Guarnición del Sitio Revelada{fr}La Garnison du Site Révélée{pt-br}Lugar de Guarnição Revelada{de}Standort Garnison aufgedeckt",{1,1,0.5}) end
end

function proxyAnimateStep(hex,hexes,mapObjects,proxyIndex,callback)
	local avatar=proxyAvatarObject()
	if avatar==nil or hex==nil then if callback~=nil then callback() end return end
	avatar.unlock()
	avatar.setPositionSmooth({hex.position[1],1.5,hex.position[3]})
	safeWaitFrames("AI.Proxy",function()
		local finished=false
		local function complete()
			if finished==true then return end
			finished=true
			if avatar~=nil then avatar.unlock() end
			if gStates.proxyTurnReport~=nil then proxyTurnReportSetMoved((gStates.proxyTurnReport.moved or 0)+1) end
			proxyRevealGarrisonsAtHex(hex,hexes,mapObjects,proxyIndex)
			if callback~=nil then callback() end
		end
		safeWaitCondition("AI.Proxy",complete,function() return avatar==nil or avatar.isSmoothMoving()==false end,3.5,complete)
	end,2)
end

function proxyAnimateRoute(route,index,target,hazard,lastSafe,hexes,mapObjects,proxyIndex)
	local avatar=proxyAvatarObject()
	if avatar==nil then proxyFinishTurn(hexes,mapObjects,proxyIndex) return end
	if route[index]==nil then
		local current=runtimeMapHexForPosition(hexes,avatar.getPosition(),mapObjects)
		if hazard~=nil or (target~=nil and current~=nil and runtimeMapHexKey(current)==runtimeMapHexKey(target.hex)) then proxyResolveArrival(target,hazard,lastSafe,hexes,mapObjects,proxyIndex)
		else
			if gStates.proxyTurnReport~=nil and gStates.proxyTurnReport.action==nil then proxyTurnReportSetAction("moved toward the "..proxyTargetDisplayName(target).."\nbut did not reach it") end
			proxyFinishTurn(hexes,mapObjects,proxyIndex)
		end
		return
	end
	proxyAnimateStep(route[index],hexes,mapObjects,proxyIndex,function() proxyAnimateRoute(route,index+1,target,hazard,lastSafe,hexes,mapObjects,proxyIndex) end)
end

function proxyContinueTowardTarget(target,proxyIndex,move,preserveMoved)
	local avatar=proxyAvatarObject()
	local hexes,mapObjects=runtimeMapHexesAndObjects()
	if avatar==nil then proxyFinishTurn(hexes,mapObjects,proxyIndex) return end
	local startHex=runtimeMapHexForPosition(hexes,avatar.getPosition(),mapObjects)
	if startHex==nil then proxyFinishTurn(hexes,mapObjects,proxyIndex) return end
	proxyRevealGarrisonsAtHex(startHex,hexes,mapObjects,proxyIndex)
	proxyTurnReportSetTarget(target)
	if preserveMoved~=true then proxyTurnReportSetMoved(0) end
	--Publish the intended destination and full allowance before physical movement begins.
	automatedMainPanelRefresh()
	local routeChoice,routeContext=proxyFindRouteChoice(startHex,target,hexes,mapObjects,proxyIndex,move or 0)
	if routeChoice~=nil and proxyBeginRouteChoice(routeChoice,target,proxyIndex,move)==true then return end
	local route,hazard,lastSafe=proxyPlanRoute(startHex,target,hexes,mapObjects,proxyIndex,move or 0,nil,routeContext)
	if #route==0 and runtimeMapHexKey(startHex)==runtimeMapHexKey(target.hex) then proxyResolveArrival(target,nil,startHex,hexes,mapObjects,proxyIndex)
	else proxyAnimateRoute(route,1,target,hazard,lastSafe,hexes,mapObjects,proxyIndex) end
end

function proxyClearPendingChoice()
	local pending=gStates.proxyPendingChoice
	if pending~=nil then
		if pending.type=="destination" or pending.type=="route" then proxyChoiceMapRefresh(nil)
		elseif pending.type=="card" then proxyInteractionChoiceClearButtons(pending)
		elseif pending.type=="enemy" then proxyEnemyChoiceClearButtons(pending) end
	end
	proxyManaChoiceUI(nil)
	gStates.proxyPendingChoice=nil
end

function proxyRestorePendingChoiceUI()
	local pending=gStates.proxyPendingChoice
	if pending==nil then proxyManaChoiceUI(nil) return end
	if pending.type=="destination" then gStates.proxyState="PickDestination"
	elseif pending.type=="route" then gStates.proxyState="PickRoute"
	elseif pending.type=="card" then gStates.proxyState="PickCard"
	elseif pending.type=="enemy" then gStates.proxyState="PickEnemy"
	elseif pending.type=="mana" then gStates.proxyState="PickMana" end
	if pending.type=="destination" or pending.type=="route" then proxyChoiceMapRefresh(pending)
	elseif pending.type=="card" then
		for _,guid in ipairs(pending.order or {}) do local card=getObjectFromGUID(guid) if card~=nil then proxyInteractionChoiceButton(card) end end
	elseif pending.type=="enemy" then
		for _,guid in ipairs(pending.order or {}) do local enemy=getObjectFromGUID(guid) if enemy~=nil then proxyEnemyChoiceButton(enemy) end end
	elseif pending.type=="mana" then proxyManaChoiceUI(pending) end
end

function proxyContinueAfterMovementSetup(proxyIndex,move,crystals)
	if gStates.turnNumber~=proxyIndex then automatedTurnRewindRelease() return end
	local avatar=proxyAvatarObject()
	local objectiveNow=proxyObjectiveObject()
	local hexes,mapObjects=runtimeMapHexesAndObjects()
	if avatar==nil or objectiveNow==nil then proxyFinishTurn(hexes,mapObjects,proxyIndex) return end
	local startHex=runtimeMapHexForPosition(hexes,avatar.getPosition(),mapObjects)
	if startHex==nil then proxyFinishTurn(hexes,mapObjects,proxyIndex) return end
	local target=proxyChooseTarget(objectiveNow,hexes,mapObjects,proxyIndex,crystals or proxySnapshotCrystals(turnOrder[proxyIndex]),startHex,move)
	if target==nil then
		proxyTurnReportSetAction("had no legal objective or exploration destination")
		if gStates.proxyTurnReport~=nil then gStates.proxyTurnReport.reason="No legal target or exploration point was available." end
		broadcastToAll("{en}Proxy has no legal objective or exploration destination.{ru}У Прокси нет допустимой цели или места исследования.{zh-tw}代理玩家沒有合法目標或探索目的地。{zh-cn}代理玩家没有合法目标或探索目的地。{ko}프록시에게 합법적인 목표나 탐험 목적지가 없습니다.{es}El Proxy no tiene objetivo legal ni destino de exploración.{fr}Le Proxy n’a aucun objectif légal ni destination d’exploration.{pt-br}O Proxy não tem objetivo válido nem destino de exploração.{de}Der Proxy hat kein gültiges Ziel oder Erkundungsziel.",{1,0.65,0.2})
		proxyFinishTurn(hexes,mapObjects,proxyIndex)
		return
	end
	--Publish the selected objective before a tied destination can pause for human input. This lets the
	--Proxy Info panel explain what they are trying to do before the Pick Destination button appears.
	proxyTurnReportSetTarget(target)
	if target.proxyChoiceTargets~=nil and #target.proxyChoiceTargets>1 then
		if proxyDestinationChoiceMattersThisTurn(target.proxyChoiceTargets,startHex,hexes,mapObjects,proxyIndex,move)==true then
			if proxyBeginDestinationChoice(target.proxyChoiceTargets,proxyIndex,move,target.proxyReason)==true then return end
		else
			target.proxyChoiceTargets=nil target.proxyChoiceCount=nil target.proxyChoiceRouteReason=nil
		end
	end
	proxyContinueTowardTarget(target,proxyIndex,move)
end

function proxyProcessTurn(proxyIndex)
	if gStates.turnNumber~=proxyIndex then automatedTurnRewindRelease() return end
	local stats=turnOrder[proxyIndex]
	if stats==nil or stats.mage~=gStates.positionMageKnight[5] then automatedTurnRewindRelease() return end
	stats.dummyProcessedThisTurn=true
	gStates.proxyState="Processing"
	gStates.proxyTurnReport=nil
	proxyClearPendingChoice()
	automatedMainPanelRefresh()
	local avatar=proxyAvatarObject()
	local hexes,mapObjects=runtimeMapHexesAndObjects()
	local portal=proxyPortalHex(hexes)
	if avatar==nil or portal==nil then gStates.proxyTurnReport={moved=0,action="could not find their Hero or Portal",reason="Setup could not provide both required objects.",allowance=0} broadcastToAll("{en}Proxy Player could not find its Hero or Portal.{ru}Прокси-игрок не смог найти своего Героя или Портал.{zh-tw}代理玩家找不到英雄或傳送門。{zh-cn}代理玩家找不到英雄或传送门。{ko}프록시 플레이어가 영웅 또는 포털을 찾지 못했습니다.{es}El jugador Proxy no pudo encontrar su Héroe o Portal.{fr}Le joueur Proxy n’a pas pu trouver son Héros ou le Portail.{pt-br}O jogador Proxy não conseguiu encontrar seu Herói ou o Portal.{de}Der Proxy-Spieler konnte seinen Helden oder das Portal nicht finden.",{1,0.25,0.25}) proxyFinishTurn(hexes,mapObjects,proxyIndex) return end
	local physicalStartHex=runtimeMapHexForPosition(hexes,avatar.getPosition(),mapObjects)
	if physicalStartHex==nil then
		avatar.unlock() avatar.setPosition({portal.position[1],1.5,portal.position[3]}) gStates.proxyAvatarOffMap=false
		stats.avatarLocation=gStates.gameScenario=="Against the Horsemen Blitz" and "glade" or "portal"
		if gStates.gameScenario=="Against the Horsemen Blitz" then stats.avatarSharedHex=againstHorsemenSharedHexKey end
	else gStates.proxyAvatarOffMap=false end
	local crystals=proxySnapshotCrystals(stats)
	local objective=proxyObjectiveObject()
	local lastCard=nil
	if objective~=nil then proxyAddObjectiveShield() lastCard=automatedDeedDraw(stats.seatPos,3,1)
	else
		objective=proxyDrawObjective(stats.seatPos)
		local drawn=0
		lastCard,drawn=automatedDeedDraw(stats.seatPos,2,1)
		if drawn==0 then lastCard=objective end
	end
	local bonus=0
	if lastCard~=nil then for _,color in ipairs(dummyCardColors(lastCard)) do bonus=bonus+(crystals[color] or 0) end end
	safeWaitTime("AI.Proxy",function()
		if bonus>0 then automatedDeedDraw(stats.seatPos,bonus,2) end
		local objectiveNow=proxyObjectiveObject()
		if objectiveNow==nil then proxyFinishTurn(hexes,mapObjects,proxyIndex) return end
		local colors=dummyCardColors(objectiveNow)
		local baseMove=proxyObjectiveBaseMove(objectiveNow)
		local shieldMove=#(gStates.proxyObjectiveShieldGUIDs or {})
		local sourceUsed,manaOptions=proxyUseSourceMana(colors)
		local willUseSource=sourceUsed==true or manaOptions~=nil
		local move=baseMove+shieldMove+(willUseSource and 1 or 0)
		proxyTurnReportBegin(objectiveNow,colors,baseMove,shieldMove,willUseSource)
		broadcastToAll(joinLang({translateWord[stats.mage],"{en} Proxy may move {ru} прокси может переместиться на {zh-tw} 代理可移動 {zh-cn} 代理可移动 {ko} 프록시는 {es} Proxy puede mover {fr} Proxy peut se déplacer de {pt-br} Proxy pode mover {de} Proxy darf sich ",tostring(move),"{en} spaces.{ru} гексов.{zh-tw} 格。{zh-cn} 格。{ko}칸 이동할 수 있습니다.{es} espacios.{fr} cases.{pt-br} espaços.{de} Felder bewegen."}),{1,0.75,0.2})
		if manaOptions~=nil and #manaOptions>1 then
			if proxyBeginManaChoice(manaOptions,proxyIndex,move,crystals)==true then return end
			proxyRerollSourceManaGUID(manaOptions[1].guid,manaOptions[1].color)
		end
		proxyContinueAfterMovementSetup(proxyIndex,move,crystals)
	end,1.4)
end

function proxyTurn(player,mouseButton,id)
	if mouseButton~="-1" or proxyPlayerActive()~=true then return end
	if gStates.tacticShown==true then
		automatedTurnRewindStart(function()
			automatedPlayerRandomTactic()
			gStates.proxyState="Start"
			nextTurnMerged("incrementTurn")
			automatedTacticRewindRelease()
		end)
		return
	end
	if gStates.endRoundCalled==true then return end
	local proxyIndex=gStates.turnNumber
	local stats=turnOrder[proxyIndex]
	if stats==nil or stats.mage~=gStates.positionMageKnight[5] then return end
	--The completed state is deliberately a second click, matching Volkare's visible confirmation flow.
	if gStates.proxyState=="ReadyToEnd" then
		gStates.proxyState="Start"
		nextTurnMerged("incrementTurn")
		return
	end
	if gStates.proxyState=="Processing" or gStates.proxyState=="PickDestination" or gStates.proxyState=="PickRoute" or gStates.proxyState=="PickCard" or gStates.proxyState=="PickEnemy" or gStates.proxyState=="PickMana" then return end
	if readDeedPileCardCount(stats.seatPos)==0 then dummyRefreshDeedState(stats.seatPos) PreEndRound({color="Black"},"-1","DummyButton") return end
	if stats.dummyProcessedThisTurn==true then return end
	--Give immediate visual feedback before the rewind transaction callback starts without mutating
	--the saved Proxy state until the protected transaction begins.
	automatedMainPanelRefresh(automatedProxyPanelSpec(stats,"Processing"))
	automatedTurnRewindStart(function() proxyProcessTurn(proxyIndex) end)
end

-- Monster token-pool replenishment and bag presentation runtime.

-- Token pile refill
local tokenPileLinks={	{discard=GUID.bag.discard.towerGarrison, destination=monsterPiles.purple},--Mage Towers Discard-->Main
						{discard=GUID.bag.discard.keepGarrison, destination=monsterPiles.gray},--Keeps Discard-->Main
						{discard=GUID.bag.discard.cityGarrison, destination=monsterPiles.white},--Cities Discard-->Main
						{discard=GUID.bag.discard.ruin, destination=monsterPiles.yellow},--Ruins Discard-->Main
						{discard=GUID.bag.discard.draconum, destination=monsterPiles.red},--Draconum Discard-->Main
						{discard=GUID.bag.discard.dungeon, destination=monsterPiles.tan},--Dungeon Discard-->Main
						{discard=GUID.bag.discard.orcs, destination=monsterPiles.green},--Orc Discard-->Main
						{discard=GUID.bag.discard.darkDraconum, destination=monsterPiles.redDark},--Dark Crusader Draconum Discard-->Main
						{discard=GUID.bag.discard.darkDungeon, destination=monsterPiles.tanDark},--Dark Crusader Dungeon Discard-->Main
						{discard=GUID.bag.discard.darkMarauders, destination=monsterPiles.greenDark},--Dark Crusader Orc Discard-->Main
						{discard=GUID.bag.discard.darkReward, destination=monsterPiles.rewardDark},--Dark Crusader Reward Discard-->Main
						{discard=GUID.bag.discard.elementalistDraconum, destination=monsterPiles.redElem},--Elementalist Draconum Discard-->Main
						{discard=GUID.bag.discard.elementalistDungeon, destination=monsterPiles.tanElem},--Elementalist Dungeon Discard-->Main
						{discard=GUID.bag.discard.elementalistOrcs, destination=monsterPiles.greenElem},--Elementalist Orc Discard-->Main
						{discard=GUID.bag.discard.elementalistReward, destination=monsterPiles.rewardElem},--Elementalist Reward Discard-->Main
						{discard=GUID.bag.discard.possessed, destination=monsterPiles.possessed},--Possessed-->Main
						{discard=GUID.bag.discard.apocReward, destination=monsterPiles.rewardApoc},--Apocalypse Cult Reward Discard-->Main
						{discard=GUID.bag.discard.councilReward, destination=monsterPiles.rewardCouncil}}--Council of the Void Reward Discard-->Main

--refill empty token piles. Both onObjectEnterScriptingZone and endRound call this routine
function tokenRefill(reportResult)
	--Token piles cannot need refilling during initial setup, and some Apocalypse piles are still being extracted then.
	if gStates==nil or gStates.tokenRefillEnabled~=true then return true end
	local noWait=true
	local emptyPile=false
	for a=1, #tokenPileLinks, 1 do
		local discardObj=getObjectFromGUID(tokenPileLinks[a].discard)
		local destinationObj=getObjectFromGUID(tokenPileLinks[a].destination)
		if destinationObj~=nil and discardObj~=nil then
			if #destinationObj.getObjects()==0 then
				emptyPile=true
				local discardObjects=discardObj.getObjects()
				if #discardObjects>0 then
					discardObj.shuffle()
					for _=1, #discardObjects do
						local obj=discardObj.takeObject()
						gStates.monsterPlayLocation[obj.guid]=nil
						destinationObj.putObject(obj)
					end
					noWait=false
				end
			end
		end
	end
	if reportResult==true and noWait==true then
		if emptyPile==true then
			broadcastToAll("{en}Sorry, I have no discard tokens to fill those empty stacks{ru}Извините, у меня нет жетонов в сбросе, чтобы заполнить эти пустые стопки.{zh-tw}抱歉，我没有废弃标记来填充那些空的标记堆{zh-cn}抱歉，我没有废弃标记来填充那些空的标记堆{ko}버린 토큰을 찾을 수 없어 더미를 채우지 못했습니다.{es}Lo siento, no tengo tokens de descarte para llenar esas pilas vacías{fr}Désolé, je n'ai pas de jetons de défausse pour remplir ces piles vides{pt-br}Desculpe, Eu tenho nenhuma ficha de descarte para preencher as estas pilhas vazias{de}Leider habe ich keine Abwurfmarken, um diese leeren Stapel zu füllen.", {0, 0.5, 1})
		else
			broadcastToAll("{en}All token piles still have tokens to play{ru}Во всех стопках жетонов все еще есть жетоны для игры.{zh-tw}所有标记都还够用呢，先不用返还{zh-cn}所有标记都还够用呢，先不用返还{ko}빈 토큰 더미가 없습니다.{es}Todas las pilas de fichas todavía tienen fichas para jugar.{fr}Toutes les piles de jetons ont encore des jetons à jouer{pt-br}Todas as pilhas de fichas ainda tem fichas para jogar{de}Alle Spielsteinstapel haben noch Spielsteine zum Spielen", {0, 0.5, 1})
		end
	end
	return noWait
end

--Run a draw only after the specific destination pile has been replenished when necessary.
--Unlike the old combat pattern, this does not scan every pool and then wait a fixed five frames
--for draws whose requested pile was already ready.
function withTokenPoolReady(pileGUID, callback, context)
	if callback==nil then return end
	local pile=pileGUID~=nil and getObjectFromGUID(pileGUID) or nil
	if pile==nil or pile.getQuantity()~=0 then callback() return end

	local refillable=false
	for _, link in ipairs(tokenPileLinks) do
		if link.destination==pileGUID then
			local discard=getObjectFromGUID(link.discard)
			refillable=discard~=nil and #discard.getObjects()>0
			break
		end
	end
	if refillable~=true then callback() return end

	tokenRefill()
	local function ready()
		local target=getObjectFromGUID(pileGUID)
		return target==nil or target.getQuantity()~=0
	end
	if ready()==true then callback()
	else safeWaitCondition(context or "TokenPools",callback,ready,2,callback) end
end

--Object UI callback for the Monster Replenish panel. The refill logic itself is shared with automatic refills.
function returnPugs(player, mouseButton, id)
	if mouseButton=="-1" then tokenRefill(true) end
end

-- Bag scaling and discard-face maintenance
bagSearch=nil
local possessedBagBottomY={}
local delayFaceChange=nil
local discardFace={}
function scaleBags(bag, obj, state)
	if bag==nil then return end
	local currentBag=getObjectFromGUID(bag.guid)
	if currentBag==nil then return end
	if currentBag.type~="Bag" and currentBag.type~="Deck" then return end
	local bagContents=currentBag.getObjects()
	if bagContents==nil then return end
	local bagNotes=bag.getGMNotes()
	if bagNotes=="monsterBag" or bagNotes=="Skills" or bagNotes=="terrainBag" or bagNotes=="Command Tokens" then
		--color tint the bag
		local contents=#bagContents
		if state=="enter" and bag.guid==bagSearch then contents=contents+1 end
		if contents==0 then bag.setColorTint({r=0.4, g=0.4, b=0.4}) contents=1 else bag.setColorTint({r=1, g=1, b=1}) end
		if bagNotes=="terrainBag" then
			if gStates.nightTint==true and gStates.firstStarted==true then
				bag.setColorTint({r=0.6, g=0.6, b=0.6})
				if state=="exit" then obj.setColorTint({r=0.6, g=0.6, b=0.6}) end
			else
				if state=="exit" then obj.setColorTint({r=1.0, g=1.0, b=1.0}) end
			end
		end
		--scale the bag
		local bagScaleDetails={	["monsterBag"]=		{scaleMult=1, 		bagPos=1, 		bagScaleMult=0.15},
								["Command Tokens"]=	{scaleMult=1, 		bagPos=1, 		bagScaleMult=0.15},
								["Skills"]=			{scaleMult=0.55, 	bagPos=1, 		bagScaleMult=0.05},
								["terrainBag"]=		{scaleMult=2.5, 	bagPos=0.97, 	bagScaleMult=0.125}}
		local bagScaleY=contents*bagScaleDetails[bagNotes].scaleMult
		--The normal Ruin pile stays planted because its mesh scales from the table-facing base. The Possessed
		--main/discard piles use a centered mesh pivot, so keep each pile's bottom edge fixed explicitly.
		local possessedStack=bag.guid==monsterPiles.possessed or bag.guid==GUID.bag.discard.possessed
		if possessedStack and possessedBagBottomY[bag.guid]==nil then
			local bounds=bag.getBoundsNormalized()
			possessedBagBottomY[bag.guid]=bounds.center[2]-(bounds.size[2]/2)
		end
		bag.setScale({x=bag.getScale()[1], y=bagScaleY, z=bag.getScale()[3]})
		if possessedStack then
			safeWaitFrames("TokenPools",function()
				if bag==nil or bag.isDestroyed() then return end
				local bounds=bag.getBoundsNormalized()
				local newBottom=bounds.center[2]-(bounds.size[2]/2)
				local targetBottom=possessedBagBottomY[bag.guid]
				if targetBottom~=nil and math.abs(targetBottom-newBottom)>0.001 then
					local pos=bag.getPosition()
					bag.setPosition({pos[1],pos[2]+targetBottom-newBottom,pos[3]})
				end
			end,1)
		end
		--TTS changes the effective ALT orientation of these tall bag meshes when the stack drops from 12 to 11 tokens.
		--Re-select the explicit high/low-count angle after every monster-bag scale change.
		if bagNotes=="monsterBag" then applyAltViewAngle(bag) end
		if bagNotes=="Skills" or bagNotes=="terrainBag" then bag.setPosition({bag.getPosition()[1], bagScaleDetails[bagNotes].bagPos+(contents*bagScaleDetails[bagNotes].bagScaleMult), bag.getPosition()[3]}) end
		if state=="exit" and bagSearch~=bag.guid then obj.setPosition({bag.getPosition()[1], 2.00+(contents*bagScaleDetails[bagNotes].bagScaleMult), bag.getPosition()[3]}) end
	end

	--Change the face of discard bags to simulate stacks
	local faceUpdateBags={[GUID.bag.discard.orcs]={empty="https://steamusercontent-a.akamaihd.net/ugc/17394071079569158125/E741F2F3BC2D802154845C79BF5FE8E0D2897C14/", last=""},--Orcs
							[GUID.bag.discard.dungeon]={empty="https://steamusercontent-a.akamaihd.net/ugc/11745447351685623762/7A4F92FE411C15551904DF42DE956D68FF7108C0/", last=""},--Dungeon
							[GUID.bag.discard.draconum]={empty="https://steamusercontent-a.akamaihd.net/ugc/18216193721391379495/100F7CA9D63623D161040786361C08E5E7D59292/", last=""},--Dragon
							[GUID.bag.discard.keepGarrison]={empty="https://steamusercontent-a.akamaihd.net/ugc/18166193477599219316/C7CC99FBECF2E509EC45A7DFA73D38ABBB82B5F6/", last=""},--Keep
							[GUID.bag.discard.towerGarrison]={empty="https://steamusercontent-a.akamaihd.net/ugc/13983820052964173806/843E10E03FE9D005D226D828003CCFE69CF98413/", last=""},--Mages
							[GUID.bag.discard.cityGarrison]={empty="https://steamusercontent-a.akamaihd.net/ugc/13829892540840002628/51D5CBA828224CFC04C74EC99B83B15F9E582218/", last=""},--City
							[GUID.bag.discard.ruin]={empty="https://steamusercontent-a.akamaihd.net/ugc/16408024805248842569/8ED6E462581719446CA9B2D9ED3A4789FBC855CE/", last=""},--Ruins
							[GUID.bag.discard.darkReward]={empty="https://steamusercontent-a.akamaihd.net/ugc/938341811900383197/E0745EA1293600D6004CC8C56D11462620900FB9/", last=""},--Dark Crusader Rewards
							[GUID.bag.discard.elementalistReward]={empty="https://steamusercontent-a.akamaihd.net/ugc/938341811900383323/F1D0AFC443E37F19C882E713D8D9F468CFD8D574/", last=""},--Elementalist Rewards
							[GUID.bag.discard.apocReward]={empty="https://steamusercontent-a.akamaihd.net/ugc/12094604589800574619/D8E7BF873319442DF81F35DE7E6BC14A53F31561/", last=""},--Apocalypse Cult Rewards
							[GUID.bag.discard.councilReward]={empty="https://steamusercontent-a.akamaihd.net/ugc/17402070254408062099/CEA25FAE0DFAC406E16D1D4AFACF8914AA536C11/", last=""},--Council of the Void Rewards
							[GUID.bag.discard.possessed]={empty="https://steamusercontent-a.akamaihd.net/ugc/15274516273430316784/0BF7DE5777EFF417E514C3510A3E82EFABF02A7B/", last=""},--Possessed
							[GUID.bag.discard.darkMarauders]={empty="https://steamusercontent-a.akamaihd.net/ugc/14928619505389787044/457C605B7972A34C1FC3C1A6E794454CDB315A29/", last=""},--Dark Crusader Green
							[GUID.bag.discard.darkDungeon]={empty="https://steamusercontent-a.akamaihd.net/ugc/15658631720343793034/87B0A8991BB4F5E5B68521B5123985788B78730D/", last=""},--Dark Crusader Tan
							[GUID.bag.discard.darkDraconum]={empty="https://steamusercontent-a.akamaihd.net/ugc/15743640597225539307/4589E50E316BC31A511475B618E0D2ED81806867/", last=""},--Dark Crusader Red
							[GUID.bag.discard.elementalistOrcs]={empty="https://steamusercontent-a.akamaihd.net/ugc/9376260431025960719/2209BFC139062A9ED0293AF9B6A0497DC8F28BB3/", last=""},--Elementalist Green
							[GUID.bag.discard.elementalistDungeon]={empty="https://steamusercontent-a.akamaihd.net/ugc/15828100274106315938/16138FF5D8C1A5100DABE503A55E11855C547378/", last=""},--Elementalist Tan
							[GUID.bag.discard.elementalistDraconum]={empty="https://steamusercontent-a.akamaihd.net/ugc/12276219328362097098/5086999374988FB9F208F17BB79E1427823288CB/", last=""},--Elementalist Red
							["927f52"]={empty="https://steamusercontent-a.akamaihd.net/ugc/2308724878077127112/0A9DFF145270A1373728EFCF95263C7C65F80D35/", last=""},--Norowas Command
							["51a8a0"]={empty="https://steamusercontent-a.akamaihd.net/ugc/2308724878077012222/4ECDBBF2A67C8914B662C828EDE77D0A8594FF90/", last=""},--Goldyx Command
							["1de952"]={empty="https://steamusercontent-a.akamaihd.net/ugc/2308724878077366749/EEF40846649F811D28B6247364E6B7E61223189E/", last=""},--Tovak Command
							["855a00"]={empty="https://steamusercontent-a.akamaihd.net/ugc/2308724878077445983/643A10EA4408CE9E224757AD9B24C4C9B89CED51/", last=""},--Wolfhawk Command
							["4b6d60"]={empty="https://steamusercontent-a.akamaihd.net/ugc/2308724878077103782/FD56191F069E4739F4899914CE4BB472E9794DC3/", last=""},--Coral Command
							["ab4b31"]={empty="https://steamusercontent-a.akamaihd.net/ugc/2308724878076980481/1FC7F984894FAA1242795CEAAEB63D797F599FE1/", last=""},--Braevalar Command
							["b76529"]={empty="https://steamusercontent-a.akamaihd.net/ugc/2308724878077103782/FD56191F069E4739F4899914CE4BB472E9794DC3/", last=""},--Krang Command
							["73e384"]={empty="https://steamusercontent-a.akamaihd.net/ugc/2308724878077521120/AD30FAA0799E1D6358B3FF9F3123F4C1C97AC7E3/", last=""},--Ymirgh Command
							["73442d"]={empty="https://steamusercontent-a.akamaihd.net/ugc/2546304515602308695/928F544BABD137632F1F35A7F13133FEFCA64867/", last=""},--Mevok Command
							["30feec"]={empty="https://steamusercontent-a.akamaihd.net/ugc/16723819408713751858/3F43F49B76B46CEBBA7A6118D65EF6B20351DE0F/", last=""},--Zirtae Command
							["c02f61"]={empty="https://steamusercontent-a.akamaihd.net/ugc/2546304515602322632/97711A8C0A9500D7F195AA55B3AD032A3FF2789D/", last=""},--Duscenia Command
							["453e1f"]={empty="https://steamusercontent-a.akamaihd.net/ugc/2308724878076712667/8DBB295DD4C83BF9DE02CE9B29B3DCC2CF279C49/", last=""},--Arythea Command
							["e4f01a"]={empty="https://steamusercontent-a.akamaihd.net/ugc/2308724878077032409/4C39163B0CCE024E04D2F54BDA80419D2C5D4B04/", last=""},--Jormund Command
							["d6e01e"]={empty="https://steamusercontent-a.akamaihd.net/ugc/14479946909127380756/3B50E70C9A791C876BE2A3BF5DA8D0E01F7743D8/", last=""},--Malek Command
							[GUID.bag.terrain.stack]={empty="https://steamusercontent-a.akamaihd.net/ugc/1688270643043527253/68E270678D47C66202EAF01B86981ADF5509CE89/", last=""}}--Terrain Stack
	if faceUpdateBags[bag.guid]~=nil then
		if state~="shuffle" and obj.getGMNotes()~="Command Token" and obj.getName()~="MapTile" then bag.setColorTint({r=0.5, g=0.5, b=0.5}) end
		if state=="enter" then
			discardFace[bag.guid]=obj.getCustomObject().image
			if obj.type=="Generic" then discardFace[bag.guid]=obj.getCustomObject().diffuse end
		end
		if (state=="exit" or state=="shuffle") and #bagContents>0 then
			local clone=bag.clone({})
			clone.setGMNotes("")
			local cloneObject=clone.takeObject({smooth=false})
			clone.destruct()
			discardFace[bag.guid]=cloneObject.getCustomObject().image
			if cloneObject.type=="Generic" then discardFace[bag.guid]=cloneObject.getCustomObject().diffuse end
			cloneObject.destruct()
		end
		if #bagContents==0 then discardFace[bag.guid]=faceUpdateBags[bag.guid].empty end

		if delayFaceChange~=nil then Wait.stop(delayFaceChange) end
		delayFaceChange=safeWaitFrames("TokenPools",function()
			for guid, image in pairs(discardFace) do
				getObjectFromGUID(guid).setCustomObject({diffuse=image})
				getObjectFromGUID(guid).reload()
				local bagGUID=guid
				safeWaitFrames("TokenPools",function() applyAltViewAngle(getObjectFromGUID(bagGUID)) end, 1)
			end
			discardFace={}
			delayFaceChange=nil
		end, 2)
	end
end

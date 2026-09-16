function onLoad(save_state)
	-- self.UI.setAttribute("d7a165swapMonsterImageImage", "image", "Sliced Button/Button Object Active")
	-- self.UI.setAttribute("d7a165swapMonsterImageText", "font", "Fonts/MKCardText")
	self.UI.setAttribute("d7a165replenishMonsterPilesImage", "image", "Sliced Button/Button Object Active")
	self.UI.setAttribute("d7a165replenishMonsterPilesText", "font", "Fonts/MKCardText")
	-- self.UI.setAttribute("d7a165swapTableImage", "image", "Sliced Button/Button Object Active")
	-- self.UI.setAttribute("d7a165swapTableText", "font", "Fonts/MKCardText")
end

-- Moves discared token to empty piles
function returnPugs(player, mouseButton, id)
	if mouseButton=="-1" then
		local transfer="noneed"
		local tokenPileLink={	{discard="6ae8c3", destination="c03e08"},--Mage Towers Discard-->Main
								{discard="b336a7", destination="7a85f5"},--Keeps Discard-->Main
								{discard="730898", destination="baac01"},--Cities Discard-->Main
								{discard="869a0f", destination="cf4631"},--Ruins Discard-->Main
								{discard="b23c77", destination="4537fa"},--Draconum Discard-->Main
								{discard="763c2d", destination="e4b016"},--Dungeon Discard-->Main
								{discard="ed0ec9", destination="c8e6e4"},--Ork Discard-->Main
								{discard="9860ce", destination="bc9d0e"},--Dark Crusader Draconum Discard-->Main
								{discard="e9b18c", destination="0fde4d"},--Dark Crusader Dungeon Discard-->Main
								{discard="61ba30", destination="cfef57"},--Dark Crusader Ork Discard-->Main
								{discard="f9d3a4", destination="f469f4"},--Dark Crusader Reward Discard-->Main
								{discard="80c10d", destination="54c45b"},--Elementalist Draconum Discard-->Main
								{discard="236555", destination="30bbae"},--Elementalist Dungeon Discard-->Main
								{discard="4aecb4", destination="0596bd"},--Elementalist Ork Discard-->Main
								{discard="076ab9", destination="33de41"},--Elementalist Reward Discard-->Main
								{discard="53b986", destination="9677da"},--Possessed-->Main 
								{discard="f362a2", destination="45d509"},--Apocalypse Cult Reward Discard-->Main
								{discard="f67cac", destination="f4d26c"}}--Council of the Void Reward Discard-->Main
		for a=1, #tokenPileLink, 1 do
			local discardPug = tokenPileLink[a].discard
			local destinationPug = tokenPileLink[a].destination
			if getObjectFromGUID(destinationPug)~=nil and getObjectFromGUID(discardPug)~=nil then
				if #getObjectFromGUID(destinationPug).getObjects() == 0 then
					if transfer~="didtransfer" then transfer="DestinationEmpty" end
					if #getObjectFromGUID(discardPug).getObjects() > 0 then
						getObjectFromGUID(discardPug).shuffle()
						local params = {position = getObjectFromGUID(destinationPug).getPosition(), rotation = { 0, 180, 180 } }
						params.position.y = params.position.y + 3.0
						local temp=Global.getTable("gStates")
						for _, take in pairs(getObjectFromGUID(discardPug).getObjects()) do
							local obj=getObjectFromGUID(discardPug).takeObject(params)
							temp.monsterPlayLocation[obj.guid]=nil
							params.position.y = params.position.y + 0.5
						end
						Global.setTable("gStates", temp)
						transfer="didtransfer"
					end
				end
			end
		end
		if transfer=="noneed" then broadcastToAll("{en}All token piles still have tokens to play{ru}Во всех стопках жетонов все еще есть жетоны для игры.{zh-cn}所有标记都还够用呢，先不用返还{ko}빈 토큰 더미가 없습니다.{es}Todas las pilas de fichas todavía tienen fichas para jugar.{fr}Toutes les piles de jetons ont encore des jetons à jouer{pt-br}Todas as pilhas de fichas ainda tem fichas para jogar{de}Alle Spielsteinstapel haben noch Spielsteine zum Spielen", {0, 0.5, 1}) end
		if transfer=="DestinationEmpty" then broadcastToAll("{en}Sorry, I have no discard tokens to fill those empty stacks{ru}Извините, у меня нет жетонов в сбросе, чтобы заполнить эти пустые стопки.{zh-cn}抱歉，我没有废弃标记来填充那些空的标记堆{ko}버린 토큰을 찾을 수 없어 더미를 채우지 못했습니다.{es}Lo siento, no tengo tokens de descarte para llenar esas pilas vacías{fr}Désolé, je n'ai pas de jetons de défausse pour remplir ces piles vides{pt-br}Desculpe, Eu tenho nenhuma ficha de descarte para preencher as estas pilhas vazias{de}Leider habe ich keine Abwurfmarken, um diese leeren Stapel zu füllen.", {0, 0.5, 1}) end
	end
end

-- function lowerTable(player, mouseButton, id)
-- 	if mouseButton=="-1" then
-- 		if getObjectFromGUID("3d4319").getPosition()[2]==0 then
-- 			getObjectFromGUID("3d4319").setPosition({0.00, -0.2, -5.00})
-- 			getObjectFromGUID("519f96").setScale({200, 1, 200})
-- 			getObjectFromGUID("519f96").setPosition({0.00, 0.77, -5.00})
-- 			Global.call("skillButtonActivate")
-- 			return
-- 		end
-- 		if getObjectFromGUID("3d4319").getPosition()[2]<0 then
-- 			getObjectFromGUID("3d4319").setPosition({0.00, 0.0, -5.00})
-- 			getObjectFromGUID("519f96").setScale({1, 1, 1})
-- 			getObjectFromGUID("519f96").setPosition({0.00, -0.2, -5.00})
-- 			Global.call("skillButtonActivate")
-- 		end
-- 	end
-- end
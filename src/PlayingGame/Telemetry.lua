-- Opt-in statistics, bug-report and score-report submission.

function SendDataRequest(player, mouseButton, id)
	--Send an explicit false for Apocalypse Quest when the option was never touched.
	if gStates~=nil then gStates.apocalypseQuestCards=(gStates.apocalypseQuestCards==true) end
	if mouseButton=="-1" and (player=="skip" or player=="auto" or (player.color~=nil and Player[player.color].admin==true)) then
		UI.setAttribute("SendDataRequest", "active", "false")
		UI.setAttribute("SendBugRequest", "active", "false")
		UI.setAttribute("SendScoreRequest", "active", "false")
		if id=="SendDataRequestYes" or id=="SendBugRequestYes" or id=="SendScoreRequestYes" then
			local STAT_URL="https://script.google.com/macros/s/AKfycbyivB9o1wmTXvdmKu9SNz6x5Lq8osELhIGNgkNJq2mvP0X5sNIQUQtidETq7ZeqXMm6xw/exec"
			if id=="SendBugRequestYes" then STAT_URL="https://script.google.com/macros/s/AKfycbzU1dSg2mafsUbUTNqOHce0cdWId2I8fkYiNO1JUgG73wtV9E2DCvm7uZ02bXviO-vnFw/exec" end
			if id=="SendScoreRequestYes" then STAT_URL="https://script.google.com/macros/s/AKfycbzLnjL_IH1gOb1hwgfDLrnrsnRkHM9bve20ph4PVqViMe5lhYtBzTOndL4T6DWo4HFXbQ/exec" end
			log("Writing stats.")
			local GameRecord={gameScenario=gStates.gameScenario,
				blitz=gStates.blitz,
				rounds=scenarioList[gStates.scenarioRef][gStates.playersRef].rounds,
				mapShape=scenarioList[gStates.scenarioRef][gStates.playersRef].mapShape,
				countryTiles=scenarioList[gStates.scenarioRef][gStates.playersRef].countryTiles,
				coreTiles=scenarioList[gStates.scenarioRef][gStates.playersRef].coreTiles,
				cityTiles=scenarioList[gStates.scenarioRef][gStates.playersRef].cityTiles,
				randomTileOrientation=gStates.randomTileOrientation,
				volkareCampAsCity=gStates.volkareCampAsCity,
				megapolis=gStates.megapolis,
				randomCities=gStates.randomCities,
				positionMageKnight1=gStates.positionMageKnight[1],
				positionMageKnight2=gStates.positionMageKnight[2],
				positionMageKnight3=gStates.positionMageKnight[3],
				positionMageKnight4=gStates.positionMageKnight[4],
				positionMageKnight5=gStates.positionMageKnight[5],
				proxyPlayer=gStates.proxyPlayer==true,
				includeYmirgh=gStates.useCustomMageKnights,
				dummyAllSkills=gStates.dummyAllSkills,
				mageKnightLevels=gStates.mageKnightLevels,
				rampagePursuit=gStates.rampagePursuit,
				rampageAmbush=gStates.rampageAmbush,
				rampage=gStates.rampage,
				removeLostLegionExpansion=gStates.removeLostLegionExpansion,
				removeShadesOfTezlaMonsters=gStates.removeShadesOfTezlaMonsters,
				removeApocalypseTerrain=gStates.removeApocalypseTerrain,
				removeBonusCards=gStates.removeBonusCards,
				volkareCombatLevel=" ",
				volkareRaceLevel=" ",
				darknessComing=gStates.darknessComing,
				startAtNight=gStates.startAtNight,
				heroChallenges=gStates.heroChallenges,
				apocalypseQuestCards=gStates.apocalypseQuestCards,
				questMod=gStates.questMod,
				weatherMod=gStates.weatherMod,
				itemShopMod=gStates.itemShopMod,
				removeTerrain=gStates.removeTerrain,
				useAlternatePugs=gStates.useAlternatePugs,
				riseOfTheForgemasters=gStates.riseOfTheForgemasters,
				autoFlip=gStates.autoFlip,
				offerSize=gStates.offerSize}
			local telemetryShape={wedgeUnlimited="Wedge",wedge="Wedge",open3="3 Columns",open4="4 Columns",open="Fully Open",predefined="Predefined"}
			GameRecord.mapShape=telemetryShape[gStates.mapShapeKey] or tostring(gStates.mapShapeKey or "")
			if gStates.positionMageKnight[5]=="Volkare" then
				GameRecord.volkareCombatLevel=gStates.volkareCombatLevel
				GameRecord.volkareRaceLevel=gStates.volkareRaceLevel
			end
			GameRecord["cityLevel"]="[ "
			for a, b in ipairs(gStates.cityLevels) do
				GameRecord["cityLevel"]=GameRecord["cityLevel"]..tostring(b).." "
			end
			for a=1, 5, 1 do
				if gStates.originalChoiceMageKnights[a]=="Random" or gStates.originalChoiceMageKnights[a]=="All Skills" then GameRecord["positionMageKnight"..tostring(a)]=GameRecord["positionMageKnight"..tostring(a)].." [R]" end
			end
			GameRecord["cityLevel"]=GameRecord["cityLevel"].."]"
			GameRecord["Comment"]=UI.getAttribute("SendBugComment", "text")
			if id=="SendScoreRequestYes" then GameRecord["Comment"]=UI.getAttribute("SendScoreComment", "text") end
			local count=0
			for index, color in pairs(Player.getAvailableColors()) do
				if Player[color].seated==true then count=count+1 end
			end
			if Player["Black"].seated==true then count=count+1 end
			GameRecord.multihand=false
			if count==1 and gStates.playerCount>1 then GameRecord.multihand=true end
			if gStates.playerCount==1 then GameRecord.gameType="Solo" end
			if gStates.playerCount>1 and (gStates.coop==0 or gStates.WarOfFourComp==true) then GameRecord.gameType="Comp" end
			if gStates.playerCount>1 and (gStates.coop==1 and gStates.WarOfFourComp==false) then GameRecord.gameType="Coop" end
			if getObjectFromGUID("519f96").getScale().x==1 then GameRecord["table"]="Original" else GameRecord["table"]="New" end
			if id=="SendBugRequestYes" then
				if player=="auto" then GameRecord["reporter"]="Automatic Lua Error" else GameRecord["reporter"]=Player[player.color].steam_name end
			end
			for _,playerDetails in pairs(turnOrder) do if playerDetails.score.finalScore==nil then playerDetails.score.finalScore=0 end end
			local reportPlayers={}
			for a,playerDetails in ipairs(turnOrder) do reportPlayers[a]=playerDetails end
			if id=="SendScoreRequestYes" then
				table.sort(reportPlayers,function(k1,k2) return k1.score.finalScore>k2.score.finalScore end)
				for c=1,4 do GameRecord["positionMageKnight"..c]="" end
			end
			for playerNo=1,#reportPlayers do
				local reportPlayer=reportPlayers[playerNo]
				for _, color in pairs(Player.getAvailableColors()) do
					local colorPos=math.ceil((Player[color].getHandTransform().position[1]+97.59)/40)
					if reportPlayer.seatPos==colorPos then
						--steam user name
						if gStates.positionMageKnight[colorPos]~="nobody" then
							local recordPos=colorPos
							if id=="SendScoreRequestYes" then recordPos=playerNo end
							GameRecord["steamName"..recordPos]=Player[color].steam_name
							if GameRecord["steamName"..recordPos]==nil then
								if player.color~=nil then GameRecord["steamName"..recordPos]=Player[player.color].steam_name end
								if player.color==nil then GameRecord["steamName"..recordPos]=Player["Black"].steam_name end
								if GameRecord["steamName"..recordPos]==nil then GameRecord["steamName"..recordPos]="No Player" end
							end
						end
						if id=="SendScoreRequestYes" then
							--Mage knight used
							GameRecord["positionMageKnight"..playerNo]=gStates.positionMageKnight[colorPos]
							if GameRecord["positionMageKnight"..playerNo]=="nobody" then GameRecord["positionMageKnight"..playerNo]="" end
							--score achieved
							GameRecord["score"..playerNo]=reportPlayer.score.finalScore
							if GameRecord["score"..playerNo]==0 then GameRecord["score"..playerNo]="" end
							if GameRecord["riseOfTheForgemasters"]==0 then GameRecord["riseOfTheForgemasters"]="" end
						end
						break
					end
				end
			end
			WebRequest.post(STAT_URL, GameRecord, function(w)
				log(w.text)
				if id=="SendBugRequestYes" or id=="SendScoreRequestYes" then
					broadcastToAll("{en}Data Received, Thank You{ru}Данные получены, спасибо!{zh-tw}數據已收到，謝謝{zh-cn}数据已收到，谢谢{ko}데이터 수신 완료. 감사합니다.{es}Datos Recibidos, Gracias{fr}Données Reçues, Merci{pt-br}Dados recebidos, obrigado{de}Daten Erfasst, Danke", {1,1,0.5})
				end
			end)
		end
	end
end

-- Automatic Lua error reporting, protected callback helpers and diagnostic context builders.

-- Error-report boundaries for callbacks that TTS invokes after the originating function has returned.
-- These helpers deliberately keep the native Wait signatures so existing timing/return behaviour is unchanged.
function automaticLuaTraceback(errorText)
	if debug and debug.traceback then return debug.traceback(tostring(errorText),2) end
	return tostring(errorText)
end

function automaticLuaAsyncLabel(scope, kind)
	return tostring(scope or "Async").." / "..tostring(kind or "callback")
end

function safeAsyncCallback(label, callback, contextCallback)
	if type(callback)~="function" then return callback end
	return function(...)
		local args={n=select("#",...),...}
		return safeCallback(label,function() return callback(table.unpack(args,1,args.n)) end,contextCallback)
	end
end

function safeObjectCallbackParams(scope, params)
	if type(params)~="table" or type(params.callback_function)~="function" then return params end
	local safeParams={}
	for key,value in pairs(params) do safeParams[key]=value end
	safeParams.callback_function=safeAsyncCallback(automaticLuaAsyncLabel(scope,"callback_function"),params.callback_function)
	return safeParams
end

-- Automatic Lua error reporting
local automaticLuaErrorReporting=false
local automaticLuaErrorLastReport=0 --kept for the manual test hook / compatibility
local automaticLuaErrorCooldown=10
local automaticLuaErrorSignatures={}
local automaticLuaErrorBreadcrumbs={}
local automaticLuaErrorBreadcrumbLimit=10
local automaticLuaErrorURL="https://script.google.com/macros/s/AKfycbzU1dSg2mafsUbUTNqOHce0cdWId2I8fkYiNO1JUgG73wtV9E2DCvm7uZ02bXviO-vnFw/exec"
local automaticLuaErrorReporterVersion="418"

function automaticLuaErrorValue(callback, fallback)
	local ok, value=pcall(callback)
	if ok==true and value~=nil then return value end
	return fallback
end

function automaticLuaErrorStateValue(key, fallback)
	return automaticLuaErrorValue(function()
		if gStates==nil then return nil end
		return gStates[key]
	end, fallback)
end

function automaticLuaErrorScenarioValue(key, fallback)
	return automaticLuaErrorValue(function()
		return scenarioList[gStates.scenarioRef][gStates.playersRef][key]
	end, fallback)
end

function automaticLuaErrorMageValue(position)
	local value=automaticLuaErrorValue(function() return gStates.positionMageKnight[position] end, "")
	local randomChoice=automaticLuaErrorValue(function() return gStates.originalChoiceMageKnights[position] end, "")
	if value~="" and (randomChoice=="Random" or randomChoice=="All Skills") then value=tostring(value).." [R]" end
	return value
end

function automaticLuaErrorMapShape()
	local mapShape=automaticLuaErrorScenarioValue("mapShape", "")
	if mapShape=="{en}Open Limited to 4 Columns{ru}Открытое поле с ограничением в 4 ряда{zh-tw}4 列的限制開放地圖{zh-cn}4 列的限制开放地图 {ko}4열 제한{es}Abierto Limitado a 4 Columnas{fr}Ouvert Limité à 4 Colonnes{pt-br}Aberto Limitado a 4 Colunas{de}Offen Begrenzt auf 4 Spalten" then return "4 Columns" end
	if mapShape=="{en}Open Limited to 3 Columns{ru}Открытое поле с ограничением в 3 ряда{zh-tw}3 列的限制開放地圖{zh-cn}3 列的限制开放地图 {ko}3열 제한{es}Abierto Limitado a 3 Columnas{fr}Ouvert Limité à 3 Colonnes{pt-br}Aberto Limitado a 3 Colunas{de}Offen Begrenzt auf 3 Spalten" then return "3 Columns" end
	if mapShape=="{en}Wedge with No Limitations{ru}Клиновидное поле без ограничений{zh-tw}錐形無限制地圖{zh-cn}锥形无限制地图{ko}쐐기형(무제한){es}En Cuña sin Límites{fr}Coin sans Limites{pt-br}Cônico sem Limitações{de}Keil ohne Begrenzungen" then return "Wedge" end
	if mapShape=="{en}Wedge{ru}Клиновидное поле{zh-tw}錐形地圖{zh-cn}锥形地图{ko}쐐기형{es}En Cuña{fr}Coin{pt-br}Cônico{de}Keil" then return "Wedge" end
	if mapShape=="{en}Fully Open{ru}Полностью открытое поле{zh-tw}完全開放地圖{zh-cn}完全开放地图{ko}전체 개방형{es}Totalmente Abierto{fr}Entièrement Ouvert{pt-br}Totalmente Aberto{de}Vollständig Offen" then return "Fully Open" end
	if mapShape=="{en}Predefined{ru}Предопределенное поле{zh-tw}按劇本預設{zh-cn}按剧本预设{ko}미리 정해짐{es}Predefinido{fr}Prédéfini{pt-br}Pré-definido{de}Vordefiniert" then return "Predefined" end
	return mapShape
end

function automaticLuaErrorCityLevel()
	return automaticLuaErrorValue(function()
		local text="[ "
		for _, level in pairs(gStates.cityLevels) do text=text..tostring(level).." " end
		return text.."]"
	end, "")
end

function automaticLuaErrorGameType()
	return automaticLuaErrorValue(function()
		if gStates.playerCount==1 then return "Solo" end
		if gStates.playerCount>1 and (gStates.coop==0 or gStates.WarOfFourComp==true) then return "Comp" end
		if gStates.playerCount>1 and gStates.coop==1 and gStates.WarOfFourComp==false then return "Coop" end
	end, "")
end

function automaticLuaErrorMultiHand()
	return automaticLuaErrorValue(function()
		local count=0
		for _, color in pairs(Player.getAvailableColors()) do if Player[color].seated==true then count=count+1 end end
		if Player["Black"].seated==true then count=count+1 end
		return count==1 and gStates.playerCount>1
	end, "")
end

function sendAutomaticLuaErrorRequest(comment)
	-- Build the normal bug-report context, but protect every lookup independently.
	-- A broken game-state field must never be able to stop the emergency report.
	local gameRecord={Comment=comment, reporter="Automatic Lua Error", reporterVersion=automaticLuaErrorReporterVersion,
		gameScenario=automaticLuaErrorStateValue("gameScenario", ""),
		gameType=automaticLuaErrorGameType(),
		blitz=automaticLuaErrorStateValue("blitz", ""),
		rounds=automaticLuaErrorScenarioValue("rounds", ""),
		mapShape=automaticLuaErrorMapShape(),
		countryTiles=automaticLuaErrorScenarioValue("countryTiles", ""),
		coreTiles=automaticLuaErrorScenarioValue("coreTiles", ""),
		cityTiles=automaticLuaErrorScenarioValue("cityTiles", ""),
		cityLevel=automaticLuaErrorCityLevel(),
		randomTileOrientation=automaticLuaErrorStateValue("randomTileOrientation", ""),
		volkareCampAsCity=automaticLuaErrorStateValue("volkareCampAsCity", ""),
		megapolis=automaticLuaErrorStateValue("megapolis", ""),
		randomCities=automaticLuaErrorStateValue("randomCities", ""),
		positionMageKnight1=automaticLuaErrorMageValue(1),
		positionMageKnight2=automaticLuaErrorMageValue(2),
		positionMageKnight3=automaticLuaErrorMageValue(3),
		positionMageKnight4=automaticLuaErrorMageValue(4),
		positionMageKnight5=automaticLuaErrorMageValue(5),
		proxyPlayer=automaticLuaErrorStateValue("proxyPlayer", false),
		multihand=automaticLuaErrorMultiHand(),
		includeYmirgh=automaticLuaErrorStateValue("useCustomMageKnights", ""),
		dummyAllSkills=automaticLuaErrorStateValue("dummyAllSkills", ""),
		mageKnightLevels=automaticLuaErrorStateValue("mageKnightLevels", ""),
		rampagePursuit=automaticLuaErrorStateValue("rampagePursuit", ""),
		rampageAmbush=automaticLuaErrorStateValue("rampageAmbush", ""),
		rampage=automaticLuaErrorStateValue("rampage", ""),
		removeLostLegionExpansion=automaticLuaErrorStateValue("removeLostLegionExpansion", ""),
		removeShadesOfTezlaMonsters=automaticLuaErrorStateValue("removeShadesOfTezlaMonsters", ""),
		removeApocalypseTerrain=automaticLuaErrorStateValue("removeApocalypseTerrain", ""),
		removeBonusCards=automaticLuaErrorStateValue("removeBonusCards", ""),
		volkareCombatLevel=" ", volkareRaceLevel=" ",
		darknessComing=automaticLuaErrorStateValue("darknessComing", ""),
		startAtNight=automaticLuaErrorStateValue("startAtNight", ""),
		heroChallenges=automaticLuaErrorStateValue("heroChallenges", ""),
		questMod=automaticLuaErrorStateValue("questMod", ""),
		weatherMod=automaticLuaErrorStateValue("weatherMod", ""),
		itemShopMod=automaticLuaErrorStateValue("itemShopMod", ""),
		removeTerrain=automaticLuaErrorStateValue("removeTerrain", ""),
		useAlternatePugs=automaticLuaErrorStateValue("useAlternatePugs", ""),
		riseOfTheForgemasters=automaticLuaErrorStateValue("riseOfTheForgemasters", ""),
		autoFlip=automaticLuaErrorStateValue("autoFlip", ""),
		offerSize=automaticLuaErrorStateValue("offerSize", ""),
		table=automaticLuaErrorValue(function()
			local obj=getObjectFromGUID("519f96")
			if obj~=nil and obj.getScale().x==1 then return "Original" end
			if obj~=nil then return "New" end
		end, "")}
	if automaticLuaErrorValue(function() return gStates.positionMageKnight[5]=="Volkare" end, false)==true then
		gameRecord.volkareCombatLevel=automaticLuaErrorStateValue("volkareCombatLevel", " ")
		gameRecord.volkareRaceLevel=automaticLuaErrorStateValue("volkareRaceLevel", " ")
	end
	--WebRequest.post form tables require string keys and values. Preserve boolean false/true explicitly;
	--nil/error lookups have already been converted to their fallback (normally an empty string).
	for key, value in pairs(gameRecord) do gameRecord[tostring(key)]=tostring(value) end
	WebRequest.post(automaticLuaErrorURL, gameRecord, function(w)
		log("Automatic Lua error report response: "..tostring(w.text))
	end)
end

function automaticLuaBreadcrumb(label)
	label=tostring(label or "")
	if label=="" or label=="maintenanceTick" or label=="onObjectHover" or label:find(" / Wait.",1,true)~=nil then return end
	if automaticLuaErrorBreadcrumbs[#automaticLuaErrorBreadcrumbs]==label then return end
	automaticLuaErrorBreadcrumbs[#automaticLuaErrorBreadcrumbs+1]=label
	while #automaticLuaErrorBreadcrumbs>automaticLuaErrorBreadcrumbLimit do table.remove(automaticLuaErrorBreadcrumbs,1) end
end

function automaticLuaBreadcrumbText()
	if #automaticLuaErrorBreadcrumbs==0 then return "" end
	return table.concat(automaticLuaErrorBreadcrumbs," -> ")
end

function automaticLuaErrorSignature(functionName,errorText)
	local firstLine=tostring(errorText or ""):match("[^\n]+") or ""
	return tostring(functionName).."|"..firstLine
end

function reportAutomaticLuaError(functionName, errorText, context)
	if automaticLuaErrorReporting then return end
	local now=os.time()
	local signature=automaticLuaErrorSignature(functionName,errorText)
	local last=automaticLuaErrorSignatures[signature]
	if last~=nil and now-last<automaticLuaErrorCooldown then return end
	automaticLuaErrorSignatures[signature]=now
	automaticLuaErrorLastReport=now
	--Keep the signature table bounded during very long sessions.
	local signatureCount=0
	for key,when in pairs(automaticLuaErrorSignatures) do
		signatureCount=signatureCount+1
		if now-when>300 then automaticLuaErrorSignatures[key]=nil end
	end
	if signatureCount>100 then automaticLuaErrorSignatures={} automaticLuaErrorSignatures[signature]=now end
	automaticLuaErrorReporting=true
	local comment="AUTOMATIC LUA ERROR\nReporter Version: "..tostring(automaticLuaErrorReporterVersion).."\nFunction: "..tostring(functionName)
	if context~=nil and context~="" then comment=comment.."\n"..tostring(context) end
	local breadcrumbs=automaticLuaBreadcrumbText()
	if breadcrumbs~="" then comment=comment.."\nRecent script actions: "..breadcrumbs end
	comment=comment.."\n\n"..tostring(errorText)
	pcall(function() UI.setAttribute("SendBugComment", "text", comment) end)
	local ok, reportError=pcall(function() sendAutomaticLuaErrorRequest(comment) end)
	if not ok then log("Automatic Lua error report failed: "..tostring(reportError).."\n"..comment) end
	automaticLuaErrorReporting=false
end

function safeCallback(functionName, callback, contextCallback)
	automaticLuaBreadcrumb(functionName)
	local ok, result=xpcall(callback, automaticLuaTraceback)
	if not ok then
		local context=nil
		if contextCallback~=nil then
			local contextOK, contextText=pcall(contextCallback)
			if contextOK==true then context=contextText end
		end
		reportAutomaticLuaError(functionName, result, context)
		return false
	end
	return result
end

--Lighter boundary for high-frequency zone events. Pass arguments directly so successful movement events
--do not allocate breadcrumb/context closures; detailed zone context is built only after an actual failure.
function safeZoneCallback(functionName, callback, zone, obj)
	local ok, result=pcall(callback,zone,obj)
	if not ok then
		reportAutomaticLuaError(functionName,tostring(result),automaticLuaZoneContext(zone,obj))
		return false
	end
	return result
end

-- Lightweight boundary for hot TTS callbacks where allocating the normal safeCallback closure/breadcrumb
-- path on every event is unnecessary. Detailed context can be added by the callback itself if needed.
function safeDirectCallback(functionName, callback, first, second)
	local ok, result=pcall(callback,first,second)
	if not ok then
		reportAutomaticLuaError(functionName,tostring(result))
		return false
	end
	return result
end

-- Temporary test hook: type !testerror in chat as an admin.
-- Reports the captured traceback, then rethrows the same error so TTS also shows the player-facing error.
function testAutomaticLuaError()
	local rawError=nil
	local ok, err=xpcall(function()
		error("Intentional automatic Lua error reporting test", 0)
	end, function(e)
		rawError=tostring(e)
		if debug and debug.traceback then return debug.traceback(rawError, 2) end
		return rawError
	end)
	if ok==true then return end
	automaticLuaErrorLastReport=0
	automaticLuaErrorSignatures={}
	reportAutomaticLuaError("TEST - automatic Lua error reporting", err, "Intentional test error triggered with !testerror")
	error(rawError or "Intentional automatic Lua error reporting test", 0)
end

function testAutomaticLuaAsyncError()
	automaticLuaErrorSignatures={}
	safeWaitFrames("TEST async",function() error("Intentional asynchronous automatic Lua error reporting test",0) end,1)
end

function automaticLuaZoneContext(zone, obj)
	local objectGUID=obj~=nil and obj.guid or "nil"
	local zoneGUID=zone~=nil and zone.guid or "nil"
	local objectName=""
	if obj~=nil then
		local ok, name=pcall(function() return obj.getName() end)
		if ok==true and name~=nil then objectName=tostring(name) end
	end
	return "Object: "..tostring(objectGUID)..(objectName~="" and " ("..objectName..")" or "").."\nZone: "..tostring(zoneGUID)
end

function automaticLuaTurnPhaseContext(player, id)
	local context="Turn: "..tostring(automaticLuaErrorStateValue("turnNumber", "")).." / Round: "..tostring(automaticLuaErrorStateValue("currentRound", ""))
	if player~=nil then context=context.."\nPlayer: "..tostring(player.color or player) end
	if id~=nil then context=context.."\nAction: "..tostring(id) end
	return context
end

function automaticLuaSkillClaimContext(player, id)
	local guid=id~=nil and tostring(id):sub(1,6) or ""
	local context=automaticLuaTurnPhaseContext(player,id).."\nSkill buttons: "..tostring(automaticLuaErrorStateValue("skillButtons","")).."\nSkill GUID: "..tostring(guid)
	local skill=getObjectFromGUID(guid)
	if skill~=nil then
		local p=skill.getPosition()
		context=context.."\nLive position: "..tostring(p[1])..", "..tostring(p[2])..", "..tostring(p[3])
	end
	local home=automaticLuaErrorValue(function() return gStates.mageSkills[guid] end,nil)
	if home~=nil then context=context.."\nRecorded position: "..tostring(home[1])..", "..tostring(home[2])..", "..tostring(home[3]) end
	return context
end

function setupGameErrorContext(player,id,rewindReady)
	local playerColor=player~=nil and (player.color or player) or ""
	return "Scenario: "..tostring(gStates~=nil and gStates.gameScenario or "")..
		"\nScenario Ref: "..tostring(gStates~=nil and gStates.scenarioRef or "")..
		"\nPlayers Ref: "..tostring(gStates~=nil and gStates.playersRef or "")..
		"\nPlayer: "..tostring(playerColor)..
		"\nStart ID: "..tostring(id or "")..
		"\nRewind Ready: "..tostring(rewindReady==true)
end

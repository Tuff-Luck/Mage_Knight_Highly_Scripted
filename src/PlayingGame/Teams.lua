-- Team membership belongs to Mage Knight seats, not to the occupant's Steam identity.
-- Zero means No Team. TTS suits are a presentation mirror, never the source of truth.
local TEAM_SUITS={"None","Hearts","Diamonds","Clubs","Spades"}

local function notifyBlackMageKnightTeamChange(seatPos,team)
    local black=Player["Black"]
    if black==nil or black.seated~=true then return end
    local teamText=team==0
        and "{en}No Team{it}Nessuna Squadra{ru}Без команды{zh-tw}無隊伍{zh-cn}无队伍{ko}팀 없음{es}Sin equipo{fr}Sans équipe{pt-br}Sem equipe{de}Kein Team"
        or ("{en}Team "..team.."{it}Squadra "..team.."{ru}Команда "..team.."{zh-tw}隊伍 "..team.."{zh-cn}队伍 "..team.."{ko}팀 "..team.."{es}Equipo "..team.."{fr}Équipe "..team.."{pt-br}Equipe "..team.."{de}Team "..team)
    broadcastToColor(joinLang({"{en}Seat {it}Postazione {ru}Место {zh-tw}座位 {zh-cn}座位 {ko}좌석 {es}Asiento {fr}Place {pt-br}Assento {de}Sitz ",seatPos,": ",teamText}),"Black",{1,1,0.5})
end

function mageKnightSeatTeam(seatPos)
    local teams=gStates and gStates.seatTeams
    local team=teams and teams[seatPos] or 0
    return type(team)=="number" and team>=1 and team<=4 and team or 0
end

function mageKnightPlayersAllied(firstSeat,secondSeat)
    local team=mageKnightSeatTeam(firstSeat)
    return team~=0 and team==mageKnightSeatTeam(secondSeat)
end

function syncMageKnightSeatTeams()
    if gStates==nil or gStates.handColors==nil then return end
    for color,seatPos in pairs(gStates.handColors) do
        if color~="Black" and color~="Grey" and Player[color]~=nil and Player[color].seated then
            local wanted=gStates.coop==1 and ((gStates.coopShareHands or {})[seatPos]==true and "Hearts" or "None") or TEAM_SUITS[mageKnightSeatTeam(seatPos)+1]
            if Player[color].team~=wanted then Player[color].team=wanted end
        end
    end
end

function cycleMageKnightSeatTeam(player,mouseButton,id)
    if mouseButton~="-1" or gStates==nil or gStates.handColors==nil then return end
    local guid=id:sub(1,6)
    local seatPos=nil
    for pos,barGUID in pairs(colorBand) do if guid==barGUID then seatPos=pos break end end
    if seatPos==nil then return end
    local authorized=player.color=="Black" or player.host or player.admin
    if not authorized then authorized=gStates.handColors[player.color]==seatPos end
    if not authorized then return end
    if gStates.coop==1 then
        gStates.coopShareHands=gStates.coopShareHands or {}
        gStates.coopShareHands[seatPos]=not (gStates.coopShareHands[seatPos]==true)
        syncMageKnightSeatTeams()
        applyColorBarButtons()
        return
    end
    gStates.seatTeams=gStates.seatTeams or {}
    local team=(mageKnightSeatTeam(seatPos)+1)%5
    gStates.seatTeams[seatPos]=team
    syncMageKnightSeatTeams()
    applyColorBarButtons()
    notifyBlackMageKnightTeamChange(seatPos,team)
    -- An alliance change can immediately add or remove a Keep assault action.
    if gStates.firstStarted==true then addAvatarButtons() end
end

-- TTS permits manual suit changes; retain the authoritative Mage Knight seat assignment.
function mageKnightTeamChanged(color)
    if color=="Black" or color=="Grey" then return end
    syncMageKnightSeatTeams()
end

-- Resolve a shield owner to their Mage Knight seat, independently of TTS colours.
function mageKnightShieldOwnerAllied(seatPos,ownerMage)
    if ownerMage==nil then return false end
    for _,details in ipairs(turnOrder or {}) do
        if details.mage==ownerMage and details.seatPos~=seatPos then
            return mageKnightPlayersAllied(seatPos,details.seatPos)
        end
    end
    return false
end

-- Allied Keep shields permit entering/recruiting, but never grant the owner's hand bonus.
function mageKnightAlliedKeepOccupied(seatPos,position)
    if mageKnightSeatTeam(seatPos)==0 or position==nil then return false end
    local _,_,_,feature=terrainHexAtPosition(position)
    if feature~="keep" then return false end
    local snapshot=runtimeMapSpatialSnapshot()
    for _,obj in ipairs(runtimeMapSpatialNearbyObjects(snapshot,position,1.5)) do
        if isShieldObject(obj) and volkarePursuitShieldRegistered(obj)~=true then
            local p=obj.getPosition()
            if (p[1]-position[1])^2+(p[3]-position[3])^2<1.44
                and mageKnightShieldOwnerAllied(seatPos,shieldOwner(obj)) then return true end
        end
    end
    return false
end

-- Conquer and Hold treats owned Mage Towers like owned Keeps.
function mageKnightAlliedOwnedSiteAt(seatPos,position)
    if gStates==nil or gStates.gameScenario~="Conquer and Hold" or position==nil then return false end
    if mageKnightAlliedKeepOccupied(seatPos,position) then return true end
    local _,_,_,feature=terrainHexAtPosition(position)
    if feature~="mage tower" or mageKnightSeatTeam(seatPos)==0 then return false end
    local snapshot=runtimeMapSpatialSnapshot()
    for _,obj in ipairs(runtimeMapSpatialNearbyObjects(snapshot,position,1.5)) do
        if isShieldObject(obj) and volkarePursuitShieldRegistered(obj)~=true then
            local p=obj.getPosition()
            if (p[1]-position[1])^2+(p[3]-position[3])^2<1.44 and mageKnightShieldOwnerAllied(seatPos,shieldOwner(obj)) then return true end
        end
    end
    return false
end

function conquerHoldPersonalMageTowers(playerIndex)
    local details=turnOrder[playerIndex]
    if details==nil or gStates.gameScenario~="Conquer and Hold" then return 0,false end
    local snapshot=runtimeMapSpatialSnapshot()
    local magePosition=mageKnightAvatarPosition(playerIndex)
    local count,nearOwn=0,false
    for _,obj in ipairs(getObjectFromGUID(mapArea).getObjects()) do
        if isShieldObject(obj) and shieldOwner(obj)==details.mage and volkarePursuitShieldRegistered(obj)~=true then
            local p=obj.getPosition()
            local _,_,_,feature=terrainHexAtPosition(p)
            if feature=="mage tower" then
                count=count+1
                if magePosition~=nil and (p[1]-magePosition[1])^2+(p[3]-magePosition[3])^2<8.5 then nearOwn=true end
            end
        end
    end
    return count,nearOwn
end

-- One to Return (four-player team variant): randomly pick and privately announce
-- one designated returning hero per two-player team.
function oneToReturnEnsureChosenMages()
    if gStates==nil or gStates.gameScenario~="One to Return" or gStates.coop~=0 or gStates.firstStarted~=true then return false end
    if gStates.oneToReturnChosenMages~=nil then return true end
    local members={}
    local realCount=0
    for _,details in ipairs(turnOrder or {}) do
        if details.mage~=gStates.positionMageKnight[5] and details.seatPos~=nil and details.seatPos<=4 then
            realCount=realCount+1
            local team=mageKnightSeatTeam(details.seatPos)
            if team==0 then return false end
            members[team]=members[team] or {}
            members[team][#members[team]+1]=details
        end
    end
    if realCount~=4 then return false end
    local teams={}
    for team,players in pairs(members) do
        if #players~=2 then return false end
        teams[#teams+1]=team
    end
    if #teams~=2 then return false end
    local chosen={}
    for _,team in ipairs(teams) do
        local member=members[team][math.random(1,2)]
        chosen[team]=member.mage
    end
    gStates.oneToReturnChosenMages=chosen
    for _,team in ipairs(teams) do
        local message=joinLang({"{en}One to Return — your team's secretly chosen hero: {it}Unico a Tornare — eroe scelto in segreto: {ru}Единственный вернётся — тайный герой вашей команды: {zh-tw}唯一歸來者——隊伍秘密選定英雄：{zh-cn}唯一归来者——队伍秘密选定英雄：{ko}유일한 귀환자 — 팀의 비밀 영웅: {es}Único en Regresar — héroe secreto del equipo: {fr}Seul à Revenir — héros secret de l'équipe : {pt-br}Único a Retornar — herói secreto da equipe: {de}Einziger Rückkehrer — geheimer Held des Teams: ", translateWord[chosen[team]]})
        for _,member in ipairs(members[team]) do
            for color,seat in pairs(gStates.handColors or {}) do
                if seat==member.seatPos and Player[color]~=nil and Player[color].seated==true then
                    broadcastToColor(message,color,{1,1,0.5})
                end
            end
        end
    end
    return true
end

-- Distinguish an opponent-held site from one held by a teammate or self.
function conquerHoldEnemyOwnedSiteAt(seatPos,position)
    if gStates==nil or gStates.gameScenario~="Conquer and Hold" or position==nil then return false end
    local _,_,_,feature=terrainHexAtPosition(position)
    if feature~="keep" and feature~="mage tower" then return false end
    local snapshot=runtimeMapSpatialSnapshot()
    for _,obj in ipairs(runtimeMapSpatialNearbyObjects(snapshot,position,1.5)) do
        if isShieldObject(obj) and volkarePursuitShieldRegistered(obj)~=true then
            local p=obj.getPosition()
            if (p[1]-position[1])^2+(p[3]-position[3])^2<1.44 then
                local owner=shieldOwner(obj)
                for _,details in ipairs(turnOrder or {}) do
                    if details.mage==owner and details.seatPos~=seatPos and not mageKnightPlayersAllied(seatPos,details.seatPos) then return true end
                end
            end
        end
    end
    return false
end

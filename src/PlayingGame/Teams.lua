-- Team membership belongs to Mage Knight seats, not to the occupant's Steam identity.
-- Zero means No Team. TTS suits are a presentation mirror, never the source of truth.
local TEAM_SUITS={"None","Hearts","Diamonds","Clubs","Spades"}

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
            local wanted=TEAM_SUITS[mageKnightSeatTeam(seatPos)+1]
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
    gStates.seatTeams=gStates.seatTeams or {}
    gStates.seatTeams[seatPos]=(mageKnightSeatTeam(seatPos)+1)%5
    syncMageKnightSeatTeams()
    applyColorBarButtons()
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

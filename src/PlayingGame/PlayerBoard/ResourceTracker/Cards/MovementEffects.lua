-- Resource Tracker movement effects. Static weather modifier records retain
-- their identities across scans; live globals are read when calculating costs.
local terrainModifiers=require("PlayingGame.PlayerBoard.ResourceTracker.Cards.TerrainModifiers")
local function ownedSkillAtSeat(guid,seatPos)
    local home=gStates~=nil and gStates.mageSkills~=nil and gStates.mageSkills[guid] or nil
    return home~=nil and home[1]~=nil and home[3]~=nil
        and home[3]<-30.5 and math.abs(home[1]-(seatPos*40-109.5))<15
end

-- Static rule objects are reused by every scan. The movement panel compares
-- terrain modifier identity to avoid expensive redraws on unchanged positions.
local weatherTerrain={}
for _,guid in ipairs({"55e5e5","676856"}) do
    local rule=skillResourceDefinitions[guid] or {}
    local roles={}
    for role,amount in pairs(rule.weatherTerrain or {}) do
        roles[role]={mode="weather",terrains="weather",amount=amount}
    end
    weatherTerrain[guid]=roles
end

-- Interactive Weather skills use the same persistent activation/circulation
-- state as the physical token. The owner gets -2 on activation; the other
-- player's Calming benefit lasts only on their eligible turn; Prayer affects
-- opponents while its competitive circulation is still active.
local function resourceCardsWeatherTerrainEffects(seatPos)
    local effects={}
    local states=gStates or {}
    local current=states.turnNumber
    local player=turnOrder~=nil and turnOrder[current] or nil
    if player==nil or player.seatPos~=seatPos then return effects end
    local active=states.coopCompSkillActivation or {}
    for _,guid in ipairs({"55e5e5","676856"}) do
        local record=active[guid]
        local details=weatherTerrain[guid]
        if record~=nil and record.round==states.currentRound then
            if record.player==current and (states.doingTheRounds or {})[guid]==nil then
                if details.owner~=nil then effects[#effects+1]=details.owner end
            elseif record.player~=current and guid=="676856" then
                if details.others~=nil then effects[#effects+1]=details.others end
            elseif record.player~=current and guid=="55e5e5"
                and coopCompSkillPlayAreaPlayer~=nil
                and coopCompSkillPlayAreaPlayer(guid)==current then
                if details.recipient~=nil then effects[#effects+1]=details.recipient end
            end
        end
    end
    local claimed=states.weatherBenefitThisTurn
    if claimed~=nil and claimed.player==current and claimed.round==states.currentRound
        and weatherTerrain["55e5e5"].recipient~=nil then
        local already=false
        for _,effect in ipairs(effects) do
            if effect==weatherTerrain["55e5e5"].recipient then already=true break end
        end
        if not already then effects[#effects+1]=weatherTerrain["55e5e5"].recipient end
    end
    return effects
end

local function cardTerrainEffects(rule,powered)
    return terrainModifiers.side(rule,powered)
end

local function terrainEffectActive(effect)
    return terrainModifiers.active(effect,gStates.dayRound)
end

local function resourceCardsEffectiveTerrainCost(terrain)
    local base=gStates~=nil and gStates.moveCost~=nil and gStates.moveCost[terrain] or nil
    if base==nil then base=999 end
    if not resourceCardsPanelOpen() then return base end
    local player=turnOrder~=nil and gStates~=nil
        and turnOrder[gStates.turnNumber] or nil
    local scan=player~=nil and resourceCardScanBySeat[player.seatPos] or nil
    local effects=scan~=nil and scan.terrainModifiers or nil
    return terrainModifiers.cost(base,terrain,effects)
end

-- Exploring is not ordinary terrain. Apply the existing explicit explore modifiers
-- (Hawk Eyes at night, Feral Allies, and any later explore-specific effects).
-- In Hidden Valley the modified price is tripled, not the other way around.
local function resourceCardsEffectiveExploreCost()
    local cost=resourceCardsEffectiveTerrainCost("explore")
    -- Owned passive Skills still apply when the tracker has been minimized.
    -- Played-card effects require an active scanner and remain player-managed while OFF.
    if not resourceCardsPanelOpen() and gStates~=nil and turnOrder~=nil
        and turnOrder[gStates.turnNumber]~=nil then
        local seatPos=turnOrder[gStates.turnNumber].seatPos
        local effects={}
        for guid,rule in pairs(skillResourceDefinitions) do
            if ownedSkillAtSeat(guid,seatPos) then
                terrainModifiers.passive(effects,rule,gStates.dayRound)
            end
        end
        local reductions={}
        for _,effect in ipairs(effects) do
            if effect.mode=="reduce" then reductions[#reductions+1]=effect end
        end
        cost=terrainModifiers.cost(cost,"explore",reductions)
    end
    if gStates~=nil and gStates.gameScenario=="The Hidden Valley Blitz" then
        cost=cost*3
    end
    return math.max(0,cost)
end

return {
    ownedSkillAtSeat=ownedSkillAtSeat,
    resourceCardsWeatherTerrainEffects=resourceCardsWeatherTerrainEffects,
    cardTerrainEffects=cardTerrainEffects,
    terrainEffectActive=terrainEffectActive,
    resourceCardsEffectiveTerrainCost=resourceCardsEffectiveTerrainCost,
    resourceCardsEffectiveExploreCost=resourceCardsEffectiveExploreCost
}

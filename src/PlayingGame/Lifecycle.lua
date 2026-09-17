-- Final Global lifecycle integration for subsystem helpers moved out of object scripts.
-- Required last so TTS sees one active onLoad/onSave pair after all modules are defined.

local baseOnSave = onSave
local MONSTER_RESTOCK_TEXT = "{en}Restock Empty Piles{ru}Восполнить пустые стопки{zh-tw}補齊抽空的標記{zh-cn}补齐抽空的标记{ko}빈 토큰더미채우기{es}Reabastecer Vacío Pilas{fr}Réapprovisionner Vider Les piles{pt-br}Reestocar Pilhas Vazias{de}Leere Stapel auffüllen"

local function savedRollerState(saved_data)
    if type(saved_data) ~= "string" or saved_data == "" then return nil end
    local ok, data = pcall(JSON.decode, saved_data)
    if ok and type(data) == "table" then return data.rollerDice end
    return nil
end

--Monster Replenish no longer carries its own Lua/XML. Rebuild its physical Restock button from
--Global, and keep the old status ids as hidden targets for legacy onLoad/swap helpers.
local function monsterReplenishObjectOnLoad()
    local obj=getObjectFromGUID("d7a165")
    if obj==nil then return end
    obj.UI.setXml([=[
<Button id="d7a165replenishMonsterPiles" interactable="true"
    onClick="global/returnPugs"
    tooltipPosition="Left" tooltipBackgroundColor="clear" tooltipOffset="20"
    width="900" height="200" color="#7F7F7F" textColor="#FFFFFF"
    position="200 270 -100" rotation="0 0 0" scale="0.48 0.48"
    shadow="rgb(0, 0, 0)" shadowDistance="0 -0">
    <Image id="d7a165replenishMonsterPilesImage" image="Sliced Button/Button Object Active" type="Sliced"/>
    <HorizontalLayout padding="30 30 30 30">
        <Text id="d7a165replenishMonsterPilesText" fontSize="90" font="Fonts/MKCardText" fontStyle="Normal"
            textColor="rgb(0, 0, 0)" offsetXY="0 1" alignment="MiddleCenter"
            resizeTextForBestFit="true" resizeTextMaxSize="90">{en}Restock Empty Piles{ru}Восполнить пустые стопки{zh-tw}補齊抽空的標記{zh-cn}补齐抽空的标记{ko}빈 토큰더미채우기{es}Reabastecer Vacío Pilas{fr}Réapprovisionner Vider Les piles{pt-br}Reestocar Pilhas Vazias{de}Leere Stapel auffüllen</Text>
    </HorizontalLayout>
</Button>
<Text id="d7a165swapMonsterImageText" active="false"></Text>
<Text id="d7a165swapTableText" active="false"></Text>
]=])
    --Object UI finishes loading after setXml; repeat the translated text on the next frame so TTS
    --resolves the language tags during onLoad. The legacy hidden ids also keep the old refresh block safe.
    safeWaitFrames("Lifecycle",function()
        if obj~=nil then obj.UI.setAttribute("d7a165replenishMonsterPilesText", "text", MONSTER_RESTOCK_TEXT) end
    end,1)
end

function onLoad(saved_data)
    return safeCallback("onLoad", function()
        --Install this before the main load path in case saved setup state invokes monsterImageSwap().
        monsterReplenishObjectOnLoad()
        artifactOnLoad()
        rollerOnLoad(savedRollerState(saved_data))
        return __onLoad_raw(saved_data)
    end)
end

function onSave()
    return safeCallback("onSave", function()
        local saved_data = baseOnSave()
        if type(saved_data) ~= "string" or saved_data == "" then return saved_data end

        local ok, data = pcall(JSON.decode, saved_data)
        if not ok or type(data) ~= "table" then return saved_data end

        data.rollerDice = rollerOnSave()
        return JSON.encode(data)
    end)
end

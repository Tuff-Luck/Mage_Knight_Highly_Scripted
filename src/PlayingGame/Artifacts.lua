-- Artifact deck object UI moved out of the object and into the Global source structure.

local ARTIFACT_GUID = "ac75c4"
local ARTIFACT_UI = [=[
<Button id="ac75c4ArtifactDown" active="false" onMouseDown="global/ButtonClickDownOverkill" onMouseUp="global/ButtonClickUpOverkill" onClick="global/artifactAdjust"
    height="150" width="150" color="rgba(0,0,0,0.0)" position="-120 190 5" rotation="0 180 180" scale="0.32 0.32">
    <Image id="ac75c4ArtifactDownImage" image="Overkill Down"></Image>
</Button>
<Button id="ac75c4ArtifactOffer" active="false" onMouseDown="global/ButtonClickDown" onMouseUp="global/ButtonClickUp" onClick="global/offerArtifacts"
    height="150" width="540" color="rgba(0,0,0,0.0)" position="0 190 5" rotation="0 180 180" scale="0.32 0.32">
    <Image id="ac75c4ArtifactOfferImage" image="Sliced Button/Button Object Active" type="Sliced"></Image>
    <Text id="ac75c4ArtifactOfferText" font="Fonts/MKCardText" fontSize="90" color="black" fontStyle="Normal" alignment="MiddleCenter">{en}Reward 1{zh-cn}奖励1{ko}보상 1{pt-br}Recompensa 1</Text>
</Button>
<Button id="ac75c4ArtifactUp" active="false" onMouseDown="global/ButtonClickDownOverkill" onMouseUp="global/ButtonClickUpOverkill" onClick="global/artifactAdjust"
    height="150" width="150" color="rgba(0,0,0,0.0)" position="120 190 5" rotation="0 180 180" scale="0.32 0.32">
    <Image id="ac75c4ArtifactUpImage" image="Overkill Up"></Image>
</Button>
]=]

local function installArtifactUI(attempt)
    local artifacts = getObjectFromGUID(ARTIFACT_GUID)
    if artifacts ~= nil then
        artifacts.UI.setXml(ARTIFACT_UI)
        return
    end

    if attempt < 60 then
        Wait.frames(function()
            installArtifactUI(attempt + 1)
        end, 1)
    end
end

Wait.frames(function()
    installArtifactUI(1)
end, 1)

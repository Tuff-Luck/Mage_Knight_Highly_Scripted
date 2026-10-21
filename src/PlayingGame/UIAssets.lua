-- Canonical Custom UI image registry taken from the current TTS save JSON.
-- Keep original registered asset names: Global XML and object controls use them.
-- Fonts and Sliced Button are special type-1 assets. Keep those entries in the
-- saved JSON; Lua's documented setCustomAssets API only supports image assets.
-- The save's existing registrations are intentionally retained as a bootstrap
-- until script-based loading has been tested on the TTS desktop.
local originalGlobalImages={
    {name="Cover",url="{en}https://steamusercontent-a.akamaihd.net/ugc/1001431857106606245/56F9EF00A526043AA1D6D7AD68C3EBD4DEA0AD1D/{ru}https://steamusercontent-a.akamaihd.net/ugc/23178046637433768/A8670F5F2554A00C22800E7F3A6C070BA1673917/{zh-tw}https://steamusercontent-a.akamaihd.net/ugc/18118113768376199548/C906F520D66B8FB611535FBD85A0B85F944FE9E6/{zh-cn}https://steamusercontent-a.akamaihd.net/ugc/1722045645694644325/B47636C60FD1BD9C002BC9C5298406899E9C88A1/{ko}https://steamusercontent-a.akamaihd.net/ugc/1710786701654505469/8B9265F16224ABC429332BF91D382E663810D294/{es}https://steamusercontent-a.akamaihd.net/ugc/1028454670706702049/E5A416003E52198C9AD317E7858DAC8EDEA0E161/"},
    {name="Background",url="https://steamusercontent-a.akamaihd.net/ugc/1692777521334268216/66D5DE3D4B7BAEB8D40F9B7C7F7F291BA8243D9F/"},
    {name="Ambush Circle",url="https://steamusercontent-a.akamaihd.net/ugc/1617313257052487169/A0FE9D65A1E285BC563116914A5D6C36DF0B7B6E/"},
    {name="Shield Button Arythea",url="https://steamusercontent-a.akamaihd.net/ugc/1478823218929326097/5CCE1BAD2CA52C846D233A207EC5E1207BBF02FC/"},
    {name="Shield Button Braevalar",url="https://steamusercontent-a.akamaihd.net/ugc/1478823218929326822/51CEC6AB36E912FF509CEA91C0F9C5522EA03BB9/"},
    {name="Shield Button Goldyx",url="https://steamusercontent-a.akamaihd.net/ugc/1478823218929327577/C637088E8131F23A2A49870FA12237A05C82D506/"},
    {name="Shield Button Coral",url="https://steamusercontent-a.akamaihd.net/ugc/10610372278788842040/2D5B9D46272240F75F6A9E66ED31EEEB2425136A/"},
    {name="Shield Button Mevok",url="https://steamusercontent-a.akamaihd.net/ugc/2546304515602238427/658CFE0897AC8F2C7C78CE9CDFE3E722B879C213/"},
    {name="Shield Button Duscenia",url="https://steamusercontent-a.akamaihd.net/ugc/2546304515607467014/4CF3182975623739C7BDA7289F68A5DB6486BD21/"},
    {name="Shield Button Malek",url="https://steamusercontent-a.akamaihd.net/ugc/12424961374538369837/2012206D5BB83801410056E8D0AB4FEA2525EDFC/"},
    {name="Shield Button Zirtae",url="https://steamusercontent-a.akamaihd.net/ugc/16461512022954963475/A1F601513AA7E6EB96C877B520144B451BFC627B/"},
    {name="Shield Button Krang",url="https://steamusercontent-a.akamaihd.net/ugc/1478823218929328785/877D06E4394E2085FE76D68E570C4EE88A4B0494/"},
    {name="Shield Button Jormund",url="https://steamusercontent-a.akamaihd.net/ugc/1771580164154280004/8B48C21581945BBCCDA60548A8E1B615A92CA9C6/"},
    {name="Shield Button Norowas",url="https://steamusercontent-a.akamaihd.net/ugc/2308724878077147072/B6CE29FBF5DA1A716B79F7185665746CBC23F36E/"},
    {name="Shield Button Tovak",url="https://steamusercontent-a.akamaihd.net/ugc/2308724878077364817/479E6B88CC3F769C1DF7C6916190B2FCBB0AAC49/"},
    {name="Shield Button Wolfhawk",url="https://steamusercontent-a.akamaihd.net/ugc/2308724878077506154/AAC2FE8D26864A0A817B77719446CA0DE62FD73F/"},
    {name="Shield Button Ymirgh",url="https://steamusercontent-a.akamaihd.net/ugc/1478823218929331940/2337A82743D4BA6AD9FE3F948A30AA33591675BC/"},
    {name="Marker Button Krang",url="https://steamusercontent-a.akamaihd.net/ugc/938341811900454919/BE8DC0BAC1C9114838EBFBAE63E4F48DC610C9F1/"},
    {name="Marker Button Jormund",url="https://steamusercontent-a.akamaihd.net/ugc/1771580164154422300/D10B1F46315559284ADF4C886C412A660942B214/"},
    {name="Marker Button Arythea",url="https://steamusercontent-a.akamaihd.net/ugc/938341811900459001/C5C3C2D266749057903B3A4FC65AF929B8D73034/"},
    {name="Marker Button Norowas",url="https://steamusercontent-a.akamaihd.net/ugc/938341811900458181/A01EA1C74D0C351F3766BF671AE27DD0EAF29688/"},
    {name="Marker Button Mevok",url="https://steamusercontent-a.akamaihd.net/ugc/2546304515608577393/E3187F6F09AB17C3C69716098CF3C63C7CCD3775/"},
    {name="Marker Button Duscenia",url="https://steamusercontent-a.akamaihd.net/ugc/2546304515608573142/6FA2F15189718A0B6628CF9FDBB34CD48BBBF31C/"},
    {name="Marker Button Malek",url="https://steamusercontent-a.akamaihd.net/ugc/15111052234560841989/97B5D9EED9CD204FCEF022F5D9F9A01E53ED7244/"},
    {name="Marker Button Zirtae",url="https://steamusercontent-a.akamaihd.net/ugc/9712078442154105947/CA4245E023B94D832778B37CC1BDFB6485565B66/"},
    {name="Marker Button Tovak",url="https://steamusercontent-a.akamaihd.net/ugc/938341811900457603/0A91310F070E085C89C5169652391D05107A8CFC/"},
    {name="Marker Button Braevalar",url="https://steamusercontent-a.akamaihd.net/ugc/938341811900456916/199CFF14DC36DEA07DA4F4A4B748F901244BA633/"},
    {name="Marker Button Goldyx",url="https://steamusercontent-a.akamaihd.net/ugc/938341811900456092/138D851EF2F5039F6D2D31A4AEDC6EA340687EC4/"},
    {name="Marker Button Wolfhawk",url="https://steamusercontent-a.akamaihd.net/ugc/938341811900455545/878C60CB8DF08C33EC9A798E0F55E889E36B17F4/"},
    {name="Marker Button Coral",url="https://steamusercontent-a.akamaihd.net/ugc/11960801215047559534/F6A0015AA2DCCA2BFED337BB02EEDA33248E1B53/"},
    {name="Marker Button Ymirgh",url="https://steamusercontent-a.akamaihd.net/ugc/938341811900426220/77D486C8959DE0B7183EC0C946F04A01C394D12E/"},
    {name="Attack Button",url="https://steamusercontent-a.akamaihd.net/ugc/1478823458284696597/E384FED8D0278DC024FF21A6B892BB5D4FC5F947/"},
    {name="Restore Button",url="https://steamusercontent-a.akamaihd.net/ugc/9877613356937477628/AAE49A069E26436B6EB4BB8B316EEC047D343ECB/"},
    {name="Unlink Button",url="https://steamusercontent-a.akamaihd.net/ugc/18034186033810785733/8DE1541ACFB46B4B63EC44CFA30276B7C3905385/"},
    {name="Overkill Up",url="https://steamusercontent-a.akamaihd.net/ugc/1617310718810263627/D8529784D1CF63D5C8F2594149276FE1AFDE65EE/"},
    {name="Overkill Down",url="https://steamusercontent-a.akamaihd.net/ugc/1617310718810264528/A1A8BCBC8028B6AA3630F12CF1374EC1FD5C82BC/"},
    {name="Overkill Up Deactive",url="https://steamusercontent-a.akamaihd.net/ugc/1754683441111500070/3FD48DA490B88DEB39FF767B920A3203151DD6C3/"},
    {name="Overkill Down Deactive",url="https://steamusercontent-a.akamaihd.net/ugc/1754683441111499559/52B367C71FDCE6BDBAB0DFBB0184FB332504FEFB/"},
    {name="Overkill Text",url="https://steamusercontent-a.akamaihd.net/ugc/1617310718810265172/BEC692EFD0588753AE8E3C09D25A6BA59D8945FC/"},
    {name="Fortified",url="https://steamusercontent-a.akamaihd.net/ugc/15769941683634999180/45D8BF9859C1F2C026A3B40DA634B74286E2C3EB/"},
    {name="Wall Fortified",url="https://steamusercontent-a.akamaihd.net/ugc/11147958722484508587/09808504747D568FFAECC06537C487DF223C3872/"},
    {name="Offer Button",url="https://steamusercontent-a.akamaihd.net/ugc/1646593864307901145/CFDEFA739F127EC9D29B7E3AC3BA47E3397BC65D/"},
    {name="Megapolis Add",url="https://steamusercontent-a.akamaihd.net/ugc/1754683565841541012/5BBE54C97CBEE0DFBF4391A55891FFC68DE37860/"},
    {name="Megapolis Subtract",url="https://steamusercontent-a.akamaihd.net/ugc/1754683565841541650/C496D0404524A37E77050A8E9A104505CAC7A730/"},
    {name="Banner Command",url="https://steamusercontent-a.akamaihd.net/ugc/18012141070723747826/A01D57BBED437196992DA98622DE5728C46CB5D5/"},
    {name="Card Remove",url="https://steamusercontent-a.akamaihd.net/ugc/1661232230977162756/90D8AEB60005119DD4182B5FD24D7BDD8243B5F3/"},
    {name="Quick Witted",url="https://steamusercontent-a.akamaihd.net/ugc/14433121776859152176/48DBFDAE388D5BA84AC56BB045184714B6628072/"},
    {name="Glade Heal Button",url="https://steamusercontent-a.akamaihd.net/ugc/15126280775024282950/D258DCBD2A2FD392BA1132CD71B28CDC90E48CFE/"},
    {name="Horseman Attack Button",url="https://steamusercontent-a.akamaihd.net/ugc/12647478740119221952/A4E3602A20A7A1C0FA03DA5C0FBEDF8910DE1E7D/"},
    {name="Volkare Pursuit Button",url="https://steamusercontent-a.akamaihd.net/ugc/13293042467654760772/E72DCC400EC451ABB80DC722F3657A631FC30C70/"},
    {name="Pursuit Stunned",url="https://steamusercontent-a.akamaihd.net/ugc/9820771160644960489/29318B61F2A30E0E941F355C3664303B0C95BC60/"},
    {name="Incantation Button",url="https://steamusercontent-a.akamaihd.net/ugc/2252424264022049991/BE0E6510D1DC7D3CD43FF6986F8373AE88DE7D8C/"},
}

-- New resource/Skill choice images use a dedicated prefix to avoid clashes.
local resourceChoiceImages={
    target={name="MKTargetIcon",url="https://steamusercontent-a.akamaihd.net/ugc/10727875827929703324/92E5145A412AFBE2EB1716DF8B6CF965359A0372/"},
    siege={name="MKChoiceSiege",url="https://steamusercontent-a.akamaihd.net/ugc/13001275488421638021/429A4C25B493880579B1EEE1BA38C5E8C2C7DD2B/"},
    ranged={name="MKChoiceRanged",url="https://steamusercontent-a.akamaihd.net/ugc/16825643705965136812/86750D2D0CE31C2AB2A08D518FDFA9606332DC69/"},
    move={name="MKChoiceMove",url="https://steamusercontent-a.akamaihd.net/ugc/15089597231616187129/97560F942A1D143CC2BD816D1F8E0B117A659AFA/"},
    influence={name="MKChoiceInfluence",url="https://steamusercontent-a.akamaihd.net/ugc/11982150083081031635/75C1352D375B05271C34514F3C578728423768AA/"},
    healing={name="MKChoiceHealing",url="https://steamusercontent-a.akamaihd.net/ugc/18027929342726570953/67A059840F886E825064D757DD9EEA63AAC7D2B9/"},
    block={name="MKChoiceBlock",url="https://steamusercontent-a.akamaihd.net/ugc/10652687051429766943/75A1D745D425D4D57D65971DB6F5E1BA1A80C6E6/"},
    attack={name="MKChoiceAttack",url="https://steamusercontent-a.akamaihd.net/ugc/12125700784244572260/5257BAD169E970724105406C69CC5918293111EE/"},
}
-- Fire choices use the existing artwork. Their "F" overlay is drawn by
-- CardRecognition, not stored as a second asset with a conflicting name.
resourceChoiceImages.fireAttack=resourceChoiceImages.attack
resourceChoiceImages.fireBlock=resourceChoiceImages.block

local allGlobalImages={}
for _,entry in ipairs(originalGlobalImages) do
    allGlobalImages[#allGlobalImages+1]=entry
end
for _,category in ipairs({"target","siege","ranged","move","influence","healing","block","attack"}) do
    allGlobalImages[#allGlobalImages+1]=resourceChoiceImages[category]
end

-- Runtime-only diagnostics. Never silently overwrite someone else's asset
-- when the same name is already registered with a different URL.
local warnedAssetCollisions={}
local function warnAssetCollision(name)
    if warnedAssetCollisions[name] then return end
    warnedAssetCollisions[name]=true
    print("Custom UI Asset conflict: '"..name.."' has a different URL; keeping the existing asset.")
end

local function mergeCustomImages(ui,desired)
    local existing=ui.getCustomAssets() or {}
    local nameIndexes={}
    local blocked={}
    for i,entry in ipairs(existing) do
        local name=entry.name
        if type(name)=="string" then
            if nameIndexes[name]~=nil then
                -- Preserve TTS's original list but do not add a third entry.
                warnAssetCollision(name)
            else
                nameIndexes[name]=i
            end
        end
    end
    local changed=false
    for _,entry in ipairs(desired) do
        local index=nameIndexes[entry.name]
        if index==nil then
            existing[#existing+1]={name=entry.name,url=entry.url}
            nameIndexes[entry.name]=#existing
            changed=true
        elseif existing[index].url~=entry.url then
            warnAssetCollision(entry.name)
            blocked[entry.name]=true
        end
    end
    -- Only call setCustomAssets/setXmlTable(...,assets) when required; these
    -- replace the asset list and can otherwise reload unrelated assets.
    return changed and existing or nil,blocked
end

function resourceCardsRegisterIconAssets()
    local merged=mergeCustomImages(UI,allGlobalImages)
    if merged~=nil then UI.setCustomAssets(merged) end
end

function resourceCardsChoiceIcon(category)
    return resourceChoiceImages[category]
end

function resourceCardsChoiceAssetsFor(ui,categories)
    local needed={}
    for _,category in ipairs(categories) do
        local asset=resourceChoiceImages[category]
        if asset~=nil then needed[#needed+1]=asset end
    end
    return mergeCustomImages(ui,needed)
end

-- Printed abilities for all 56 Regular and Elite Units (including Lost Legion).
-- Stable physical GUIDs identify cards. Type labels below are identifiers for
-- maintainers only: never compare a translated nickname or description.
-- A shared row means alternate options printed on the SAME line of the card.
-- Unit selection, Command history and object UI live in CardRecognition.lua.
local function value(row,resource,amount,tooltip,extra)
    local a={row=row,tooltip=tooltip}
    a[resource]=amount
    for _,family in ipairs({"siege","ranged","block","attack","move","influence","healing"}) do
        if resource:sub(1,#family)==family then
            a.key=family
            a.icon=family
            break
        end
    end
    if resource:find("ColdFire",1,true) then
        a.iconOverlay="CF"
        a.iconOverlayColor="#EC75F8"
    elseif resource:find("Fire",1,true) then
        a.iconOverlay="F"
        a.iconOverlayColor="#FF564A"
    elseif resource:find("Ice",1,true) then
        a.iconOverlay="I"
        a.iconOverlayColor="#66BAFF"
    end
    for k,v in pairs(extra or {}) do a[k]=v end
    if a.manaCost~=nil and a.iconOverlay==nil then
        a.iconOverlay=a.manaCost:sub(1,1)
        a.iconOverlayColor=({Red="#FF564A",Blue="#66BAFF",
            White="#FFFFFF",Green="#69E370",Black="#333333"})[a.manaCost]
    end
    return a
end

local function special(row,tooltip,extra)
    local a={row=row,key="other",tooltip=tooltip}
    for k,v in pairs(extra or {}) do a[k]=v end
    return a
end

local byType={
    Peasants={
        value(1,"attack",2,"Attack 2"),value(1,"block",2,"Block 2"),
        value(2,"influence",2,"Influence 2"),value(3,"move",2,"Move 2")},
    Herbalists={
        value(1,"healing",2,"Heal 2"),
        special(2,"Ready a Level I or II Unit",{key="ready"}),
        special(3,"Gain a green mana token",{key="gain"})},
    Foresters={
        value(1,"move",2,"Move 2; forests, hills and swamps cost 1 less (minimum 0)",{terrainReduce=true}),
        value(2,"block",3,"Block 3")},
    UtemCrossbowmen={
        value(1,"attack",3,"Attack 3"),value(1,"block",3,"Block 3"),
        value(2,"ranged",2,"Ranged Attack 2")},
    UtemGuardsmen={
        value(1,"attack",2,"Attack 2"),
        value(2,"block",4,"Block 4; counts twice against Swiftness")},
    UtemSwordsmen={
        value(1,"attack",3,"Attack 3"),value(1,"block",3,"Block 3"),
        value(2,"attack",6,"Attack 6; wound this Unit after resolving",{woundsSelf=true}),
        value(2,"block",6,"Block 6; wound this Unit after resolving",{woundsSelf=true})},
    GuardianGolems={
        value(1,"attack",2,"Attack 2"),value(1,"block",2,"Block 2"),
        value(2,"blockFire",4,"Fire Block 4"),
        value(3,"blockIce",4,"Ice Block 4")},
    Illusionists={
        value(1,"influence",4,"Influence 4"),
        special(2,"An unfortified enemy does not attack this combat"),
        special(3,"Gain a white crystal to your inventory",{key="gain"})},
    RedCapeMonks={
        value(1,"attack",3,"Attack 3"),value(1,"block",3,"Block 3"),
        value(2,"attackFire",4,"Fire Attack 4"),
        value(2,"blockFire",4,"Fire Block 4")},
    NorthernMonks={
        value(1,"attack",3,"Attack 3"),value(1,"block",3,"Block 3"),
        value(2,"attackIce",4,"Ice Attack 4"),
        value(2,"blockIce",4,"Ice Block 4")},
    SavageMonks={
        value(1,"attack",3,"Attack 3"),value(1,"block",3,"Block 3"),
        value(2,"siege",4,"Siege Attack 4")},
    Scouts={
        value(1,"siege",1,"Siege Attack 1"),
        special(2,"Peek at a face-down enemy token within 3 spaces, or top of an unused enemy pile; +1 Fame if defeated this turn"),
        value(3,"move",2,"Move 2; you may reveal a tile from 2 spaces away")},
    Thugs={
        value(1,"block",3,"Block 3"),
        value(2,"attack",3,"Attack 3; Reputation -1"),
        value(3,"influence",4,"Influence 4; Reputation -1")},
    Shocktroops={
        value(1,"ranged",1,"Ranged Attack 1; all your other Units get +1 to all Attacks this turn",{boostOtherUnits=true}),
        special(2,"Chosen enemy gets Armor -1 and one Attack -1"),
        special(3,"Reduce one enemy Attack by 3; assign its damage to Shocktroops first")},
    MagicFamiliars={
        value(1,"attack",3,"Attack 3 (+2 if the Unit's crystal is red)",{bonusColor="Red",bonus=2}),
        value(2,"block",4,"Block 4 (+3 if the Unit's crystal is blue)",{bonusColor="Blue",bonus=3}),
        value(3,"move",3,"Move 3 (+2 if the Unit's crystal is white)",{bonusColor="White",bonus=2}),
        value(3,"influence",3,"Influence 3 (+2 if the Unit's crystal is white)",{bonusColor="White",bonus=2}),
        value(4,"healing",2,"Heal 2 (+1 if the Unit's crystal is green)",{bonusColor="Green",bonus=1})},
    FireGolems={
        value(1,"attack",3,"Attack 3"),value(1,"block",3,"Block 3"),
        value(2,"rangedFire",4,"Ranged Fire Attack 4")},
    IceGolems={
        value(1,"attack",3,"Attack 3"),value(1,"block",3,"Block 3"),
        value(2,"attackIce",6,"Ice Attack 6")},
    FireMages={
        value(1,"rangedFire",3,"Ranged Fire Attack 3"),
        value(2,"attackFire",6,"Fire Attack 6"),value(2,"blockFire",6,"Fire Block 6"),
        special(3,"Gain a red mana token and a red crystal",{key="gain"})},
    IceMages={
        value(1,"attackIce",4,"Ice Attack 4"),value(1,"blockIce",4,"Ice Block 4"),
        value(2,"siegeIce",4,"Siege Ice Attack 4"),
        special(3,"Gain a blue mana token and a blue crystal",{key="gain"})},
    AmotepGunners={
        value(1,"attack",5,"Attack 5"),value(1,"block",5,"Block 5"),
        value(2,"rangedFire",6,"Ranged Fire Attack 6")},
    AmotepFreezers={
        value(1,"attack",5,"Attack 5"),value(1,"block",5,"Block 5"),
        special(2,"Chosen enemy does not attack and gets Armor -3 (minimum 1)")},
    Catapults={
        value(1,"siege",3,"Siege Attack 3"),
        value(2,"siegeFire",5,"Pay red mana: Siege Fire Attack 5",{manaCost="Red"}),
        value(3,"siegeIce",5,"Pay blue mana: Siege Ice Attack 5",{manaCost="Blue"})},
    AltemMages={
        special(1,"Gain two mana tokens of any colors",{key="gain"}),
        value(2,"attackColdFire",5,"Cold Fire Attack 5; +2 with red or blue mana, +4 with both",{manaScale=true}),
        value(2,"blockColdFire",5,"Cold Fire Block 5; +2 with red or blue mana, +4 with both",{manaScale=true}),
        special(3,"Pay black mana: all your Attacks this combat become Cold Fire",{manaCost="Black",buttonLabel="CF"}),
        special(3,"Pay black mana: all your Attacks this combat become Siege, retaining elements",{manaCost="Black",buttonLabel="S"})},
    AltemGuardians={
        value(1,"attack",5,"Attack 5"),
        value(2,"block",8,"Block 8; counts twice against Swiftness"),
        special(3,"Pay green mana: all your Units gain all resistances this turn",{manaCost="Green"})},
    HeroesWhite={
        value(1,"attack",5,"Attack 5"),value(1,"block",5,"Block 5"),
        value(2,"ranged",7,"Ranged Attack 7"),
        value(3,"influence",5,"Influence 5; +1 Reputation if used in interaction")},
    HeroesGreen={
        value(1,"attack",5,"Attack 5"),value(1,"block",5,"Block 5"),
        value(2,"healing",4,"Heal 4"),
        value(3,"influence",5,"Influence 5; +1 Reputation if used in interaction")},
    HeroesBlue={
        value(1,"attack",5,"Attack 5"),value(1,"block",5,"Block 5"),
        value(2,"blockColdFire",8,"Cold Fire Block 8"),
        value(3,"influence",5,"Influence 5; +1 Reputation if used in interaction")},
    HeroesRed={
        value(1,"attack",5,"Attack 5"),value(1,"block",5,"Block 5"),
        value(2,"attackColdFire",6,"Cold Fire Attack 6"),
        value(3,"influence",5,"Influence 5; +1 Reputation if used in interaction")},
    Sorcerers={
        value(1,"ranged",3,"Ranged Attack 3"),
        value(2,"ranged",3,"Pay white mana: target loses all fortifications; Ranged Attack 3",{manaCost="White"}),
        value(3,"ranged",3,"Pay green mana: target loses all resistances; Ranged Attack 3",{manaCost="Green"})},
    DelphanaMasters={
        special(1,"Pay blue mana: target enemy does not attack",{manaCost="Blue",buttonLabel="B"}),
        special(2,"Pay red mana: target enemy is destroyed if blocked",{manaCost="Red",buttonLabel="R"}),
        special(3,"Pay green mana: target enemy Armor -5 (minimum 1)",{manaCost="Green",buttonLabel="G"}),
        special(4,"Pay white mana: target enemy loses all fortifications and resistances",{manaCost="White",buttonLabel="W"})}
}
byType.DelphanaMasters.multi=true

local guidGroups={
    Peasants={"a0a6cb","794e16","484fa3"},
    Herbalists={"b33811","db04a7"},
    Foresters={"e8acd7","d55e5c"},
    UtemCrossbowmen={"004558","506ea7"},
    UtemGuardsmen={"c1f77c","00ebf3"},
    UtemSwordsmen={"c10664","aff9b6"},
    GuardianGolems={"84e5d3","b5500d"},
    Illusionists={"8dc143","c72d43"},
    RedCapeMonks={"868e12"},
    NorthernMonks={"f17813"},
    SavageMonks={"b8d41f"},
    Scouts={"246b0d","bd1011"},
    Thugs={"4339c4","ff2a54"},
    Shocktroops={"75307e","422b8b"},
    MagicFamiliars={"0a2e0b","d8e49b"},
    FireGolems={"d81a4f","97f64a"},
    IceGolems={"18446c","c6ca7b"},
    FireMages={"9ea578","f80455"},
    IceMages={"2806cf","094bd9"},
    AmotepGunners={"7ba7be","f60766"},
    AmotepFreezers={"9e8205","f8ebe0"},
    Catapults={"1aa68c","1aa681","d6d932"},
    AltemMages={"bb1660","0fe22e"},
    AltemGuardians={"f288ea","5726ab","f288e1"},
    HeroesWhite={"8ccbdd"},
    HeroesGreen={"613dca"},
    HeroesBlue={"88f3f2"},
    HeroesRed={"4ee245"},
    Sorcerers={"c3e3c5","223b47"},
    DelphanaMasters={"9c5c38","5c2da0"}
}

unitResourceDefinitions={}
for unitType,guids in pairs(guidGroups) do
    for _,guid in ipairs(guids) do
        unitResourceDefinitions[guid]=byType[unitType]
    end
end

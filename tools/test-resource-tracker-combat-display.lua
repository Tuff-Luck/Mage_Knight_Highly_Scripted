-- Direct production formatting and grouped display tests.
local traits={}
local config={COMBAT_GREEN="green",enemyDefenceTraits=traits}
local display=dofile("src/PlayingGame/PlayerBoard/ResourceTracker/CombatDisplay.lua")(config,
    function(text,color) return "<"..color..">"..text.."</"..color..">" end,
    function(data,perks,definitions)
        return {data=data,perks=perks,definitions=definitions}
    end)
local function eq(actual,expected,label)
    assert(actual==expected,label..": expected "..tostring(expected)..", got "..tostring(actual))
end
local function row(range,block,attack)
    return {range=range or {},block=block or {},attack=attack or {}}
end
local allocated={
    [1]=row({"r1","r2","r3"},{"b1","b2","b3"},{"a1"}),
    [2]=row({"r4"},{"b4"},{"a2","a3","a4"}),
    [3]=row({},{"b5"},{})
}
local rows,overflow=display.groupResourceRows({1,2},allocated,2)
eq(rows[1].range[2],"r2","Ranged icons fill first group row")
eq(rows[2].range[1],"r3","Ranged icons spill to next group row")
eq(rows[2].range[2],"r4","Original range order retained")
eq(rows[1].attack[2],"a2","Melee icons shared across group")
eq(rows[2].attack[2],"a4","Melee order retained")
eq(rows[1].block[2],"b2","Block stays on owning row first")
eq(rows[2].block[1],"b4","Second enemy's own Block shown before overflow")
eq(rows[2].block[2],"b3","Overflow fills remaining group slot")
eq(rows[3],nil,"No spill outside group")
eq(overflow,0,"All group icons fit")
eq(#allocated[1].range,3,"Physical allocation list unchanged")
eq(#allocated[1].block,3,"Original Block allocation unchanged")
rows,overflow=display.groupResourceRows({1},allocated,2)
eq(overflow,2,"Single enemy counts hidden range and Block icons")
eq(rows[2],nil,"Single enemy never uses unrelated row")
eq(display.groupAttackLine(0,4),nil,"No Attack produces no line")
eq(display.groupAttackLine(3,4),"Attack 3/4","Insufficient Attack displayed")
eq(display.groupAttackLine(4,4),"Attack 4/4 <green>Defeated</green>","Defeat uses calculated Attack")
local full={"one","two"}
eq(display.compactResultLines(full,{},{}),full,"Full result retained without expansion markers")
local entry={data={elusive=true,defend=2},perks={arcaneImmunity=true}}
local group={data={fortified=true,fResist=true,pResist=true},perks={wallFortified=true}}
local shared=display.groupTraitsText(entry,group)
eq(shared.data.elusive,true,"Individual Elusive preserved")
eq(shared.data.defend,2,"Individual Defend preserved")
eq(shared.perks.arcaneImmunity,true,"Individual perk immunity retained")
eq(shared.data.fortified,true,"Group fortification shared")
eq(shared.data.fResist,true,"Group resistance shared")
eq(shared.perks.wallFortified,true,"Group wall shared")
eq(shared.definitions,traits,"Live trait definitions forwarded")
eq(entry.data.fResist,nil,"Printed token data unchanged")
local notes=display.damageNotes({assassination=true},{
    units={{unit={name="Shocktroops"},wounded=true,wounds=2,destroyed=true,forced=true},
        {unit={name="Golems"},wounded=false}},
    heroWounds=1,discard=1,veilWoundIgnored=true,prevented=2,elementPrevented=1,paralyse=true})
eq(notes[1],"Wounds: Shocktroops (2), Hero (1) Poison (1) (Veil of Mist: 1 Wound ignored)","Wound distribution")
eq(notes[2],"Battle Hardened: -2 Hero damage","Mitigation displayed")
eq(notes[3],"Elemental Resistance: -1 Hero damage","Elemental mitigation displayed")
eq(notes[4],"Resisted (no Wound): Golems","Resisting Unit displayed")
eq(notes[5],"Destroyed (Paralyse): Shocktroops","Destroyed Unit displayed")
eq(notes[6],"Must take damage first: Shocktroops","Forced target displayed")
eq(notes[7],"Assassination","Assassination displayed")
eq(notes[8],"Paralyse: discard hand","Hero paralysis displayed")
eq(display.damageNotes({},{units={},heroWounds=0,discard=0})[1],"Wounds: None","No damage display")
print("Combat display text, grouped resource rows and damage notes passed")

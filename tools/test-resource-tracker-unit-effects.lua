-- Direct regression for the extracted Unit numeric effects and Glory modifier.
package.path="src/?.lua;"..package.path
local payment=require("PlayingGame.PlayerBoard.ResourceTracker.Scanning.ManaPayments")
local day=true
local function dayMana() return day end
local function blackAllowed() return not day end
local tracker={totalsKeys={attack=true,attackFire=true,attackColdFire=true,
    block=true,blockIce=true,ranged=true,siege=true,move=true,influence=true,healing=true}}
local effects=require("PlayingGame.PlayerBoard.ResourceTracker.Units.UnitEffects")(
    tracker,function(ability,counts)
        return payment.unitAbilityPaid(ability,counts,dayMana,blackAllowed)
    end,dayMana)
local function eq(actual,expected,label)
    assert(actual==expected,label..": expected "..tostring(expected)..", got "..tostring(actual))
end
local function calc(ability,counts,crystals,boost,howl)
    return effects.unitAbilityResources(ability,counts or {},crystals,boost or 0,howl)
end
eq(calc(nil),nil,"No selected ability")
eq(calc({attack=3,manaCost="Red"}),nil,"Unpaid ability")
eq(calc({attack=3,manaCost="Red"},{Gold=1}).attack,3,"Day Gold payment")
day=false
eq(calc({attack=3,manaCost="Red"},{Gold=1}),nil,"Night Gold denied")
eq(calc({ranged=3,manaCost="White",baseWithoutPayment=true}).ranged,3,"Unpaid base resource retained")
local familiar={attack=3,bonusColor="Red",bonus=2,row=1}
eq(calc(familiar,{Red=1},{}).attack,3,"Mana is not a persistent crystal")
eq(calc(familiar,{}, {Red=1}).attack,5,"Familiar crystal bonus")
eq(calc(familiar,{}, {Red=1}).row,nil,"Metadata is not a resource")
eq(calc(familiar,{}, {Red=1},2,true).attack,6,"Crystal, combat boost and Howl ordering")
local result=calc({attackFire=2,blockIce=1,ranged=3,siege=4,move=2,influence=3,healing=1},nil,nil,2,true)
eq(result.attackFire,3,"Elemental Attack boost and Howl")
eq(result.blockIce,2,"Elemental Block boost and Howl")
eq(result.ranged,4,"Ranged modifier")
eq(result.siege,5,"Siege modifier")
eq(result.move,2,"Move unchanged")
eq(result.influence,3,"Influence unchanged")
eq(result.healing,1,"Heal unchanged")
eq(calc({block=0},nil,nil,0,true).block,0,"Howl floors at zero")
local original={attack=2,block=0,move=3}
local boosted,glory=effects.applyGlory(original,true)
eq(boosted.attack,3,"Glory increases Attack")
eq(boosted.block,1,"Glory preserves existing zero-resource treatment")
eq(boosted.move,3,"Glory leaves Move unchanged")
eq(glory,true,"Positive combat resource enables Glory Fame")
eq(original.attack,2,"Glory does not mutate original record")
boosted,glory=effects.applyGlory({block=0,move=2},true)
eq(glory,false,"No positive original combat resource means no Glory Fame")
boosted,glory=effects.applyGlory(original,false)
eq(boosted,original,"No Glory preserves original resource table")
eq(glory,false,"No Glory Fame without Banner")
boosted,glory=effects.applyGlory(nil,true)
eq(boosted,nil,"No resource remains nil")
eq(glory,false,"No resource means no Glory Fame")
print("Unit resource calculations, modifier ordering and Glory passed")

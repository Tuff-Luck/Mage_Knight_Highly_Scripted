-- Direct Unit ability decision regressions (no TTS object discovery).
package.path="src/?.lua;"..package.path
local payment=require("PlayingGame.PlayerBoard.ResourceTracker.ManaPayments")
local gold,black=true,false
local function goldAllowed() return gold end
local function blackAllowed() return black end
local manaReads=0
local function signature(counts)
    return payment.unitManaSignature(counts,goldAllowed,blackAllowed)
end
local decide=require("PlayingGame.PlayerBoard.ResourceTracker.UnitChoices")({
    unitManaCounts=function(unit,seatPos)
        assert(unit.guid=="unit" and seatPos==1)
        manaReads=manaReads+1
        return {Red=1}
    end,
    unitManaSignature=signature,
    unitAbilityPaid=function(ability,counts)
        return payment.unitAbilityPaid(ability,counts,goldAllowed,blackAllowed)
    end,
    resourceCardsGoldAllowed=goldAllowed
})
local function eq(a,b,label)
    assert(a==b,label..": expected "..tostring(b)..", got "..tostring(a))
end
local function choice(abilities,activation,counts)
    activation.seatPos=1
    return decide({guid="unit"},abilities,activation,counts)
end
local basic={{key="attack"},{key="block"},{key="attack",manaCost="Red"},
    {key="block",manaCost="Blue"},{key="other",manaCost="Black"}}
local act={choice=2}
eq(choice(basic,act,{}).index,2,"Unpaid base choice")
eq(choice(basic,act,nil).index,3,"Missing counts use live scan")
eq(manaReads,1,"Read live mana once")
eq(act.lastPaidIndex,3,"Remember unambiguous paid choice")
eq(choice(basic,act,{Red=1,Blue=1}).index,3,"Keep earlier valid paid choice")
act.manaChoice=4
eq(choice(basic,act,{Red=1,Blue=1}).index,4,"Manual paid choice wins")
eq(choice(basic,act,{Red=1}).index,3,"New sole payable ability")
eq(act.manaChoice,nil,"Invalid manual choice cleared")
eq(choice(basic,{choice=2},{Red=1,Blue=1}).index,4,"Unique matching family carried forward")
eq(choice({{key="attack"},{key="attack",manaCost="Red"},
    {key="attack",manaCost="Blue"}},{choice=1},{Red=1,Blue=1}).index,nil,
    "Multiple payable abilities in same family remain ambiguous")
eq(choice(basic,{choice=1},{Gold=1}).index,3,"Gold preserves uniquely matching family")
gold=false
eq(choice(basic,{choice=2},{Gold=1}).index,2,"Night rejects Gold")
black=true
eq(choice(basic,{choice=1},{Black=1}).index,5,"Permitted Black selects ability")
black=false
eq(choice(basic,{choice=1},{Black=1}).index,1,"Black permission checked live")
gold=true
local multi={{key="other",manaCost="Red"},{key="other",manaCost="Green"},
    {key="other",manaCost="White"},multi=true}
local counts={Red=1,Gold=1}
local result=choice(multi,{},counts)
eq(result.selected[1],true,"Direct color payment kept")
eq(result.ambiguous,true,"One Gold cannot pay two other colors")
eq(#result.display,2,"Only wildcard alternatives displayed")
eq(result.selected[2],nil,"No automatic ambiguous Gold spend")
result=choice(multi,{manaSignature=signature(counts),selected={[2]=true,[3]=true}},counts)
eq(result.selected[2],true,"Valid explicit wildcard choice retained")
eq(result.selected[3],nil,"Wildcard choice capped by token count")
result=choice(multi,{manaSignature="stale",selected={[2]=true}},counts)
eq(result.selected[2],nil,"Stale selection signature ignored")
result=choice(multi,{}, {Red=1,Gold=2})
eq(result.selected[1] and result.selected[2] and result.selected[3],true,"Enough Gold pays both alternatives")
gold=false
result=choice(multi,{},counts)
eq(result.selected[1],true,"Direct payment survives Night")
eq(result.selected[2],nil,"Night Gold rejected for multi ability")
gold=true
local fear={{key="attack"},{key="block",manaCost="Blue"},{key="fear"},bannerFearIndex=3}
result=choice(fear,{choice=3,bannerFearSelected=true},{Blue=1})
eq(result.index,3,"Explicit Banner of Fear selection wins")
eq(result.selected[3],true,"Fear recorded as selected")
eq(result.display[1],3,"Fear first when selected")
eq(result.display[2],2,"Paid alternative available")
eq(result.display[3],1,"Free alternative available")
result=choice(fear,{choice=1},{Blue=1})
eq(result.index,2,"Paid ability selected when Fear not chosen")
eq(result.display[2],3,"Fear remains available beside paid ability")
result=choice(basic,{choice=3,bannerFearSelected=true},nil)
eq(result.index,nil,"Removed Banner cannot retroactively create attack")
eq(#result.display,0,"Removed Banner has no selectable abilities")
result=choice(basic,{choice=1,priorTurnSpent=true},nil)
eq(result.index,nil,"Previous-turn spent activation cannot contribute")
eq(manaReads,1,"Inactive historical uses never rescan mana")
print("Unit ability decisions, mana ambiguity, Gold capacity and historical Fear passed")

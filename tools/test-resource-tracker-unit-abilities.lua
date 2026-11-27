-- Related regressions share a runner and fixtures while each case retains local state.
-- Run from repository root: lua5.2 tools/test-resource-tracker-unit-abilities.lua
package.path="src/?.lua;"..package.path
local payment=require("PlayingGame.PlayerBoard.ResourceTracker.Scanning.ManaPayments")

local function eq(actual,expected,label)
    assert(actual==expected,(label or "Mismatch")..": expected "..tostring(expected)..", got "..tostring(actual))
end

local failures={}
local function run(name,body)
    local ok,message=xpcall(body,debug.traceback)
    if not ok then
        failures[#failures+1]=name..": "..tostring(message)
    end
end

run("resource-tracker-unit-choices",function()
    -- Direct Unit ability decision regressions (no TTS object discovery).
    local gold,black=true,false
    local function goldAllowed() return gold end
    local function blackAllowed() return black end
    local manaReads=0
    local function signature(counts)
        return payment.unitManaSignature(counts,goldAllowed,blackAllowed)
    end
    local decide=require("PlayingGame.PlayerBoard.ResourceTracker.Units.UnitChoices")({
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
end)

run("resource-tracker-unit-effects",function()
    -- Direct regression for the extracted Unit numeric effects and Glory modifier.
    local day=true
    local function dayMana() return day end
    local function blackAllowed() return not day end
    local tracker={totalsKeys={attack=true,attackFire=true,attackColdFire=true,
        block=true,blockIce=true,ranged=true,siege=true,move=true,influence=true,healing=true}}
    local effects=require("PlayingGame.PlayerBoard.ResourceTracker.Units.UnitEffects")(
        tracker,function(ability,counts)
            return payment.unitAbilityPaid(ability,counts,dayMana,blackAllowed)
        end,dayMana)
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
end)

run("resource-tracker-unit-self-wounds",function()
    -- Direct phase eligibility regressions for self-wounding Unit abilities.
    local abilities={
        block={{block=4,woundsSelf=true}},
        attack={{attack=4,woundsSelf=true}},
        elemental={{blockFire=4,woundsSelf=true}},
        ordinary={{attack=3}},
        multiple={{block=3,woundsSelf=true},{attack=4,woundsSelf=true}},
        otherSeat={{attack=3,woundsSelf=true}},
        incomplete={{block=3,woundsSelf=true}},
        missing={{attack=3,woundsSelf=true}},
        defeated={{attack=3,woundsSelf=true}},
        unused={{attack=3,woundsSelf=true}},
        unpaid={{attack=3,woundsSelf=true}}
    }
    local activations,records={},{}
    local observed={}
    local function key(guid,index) return guid.."#use"..index end
    for guid in pairs(abilities) do
        activations[guid]={seatPos=1,uses={{index=1}}}
        records[key(guid,1)]={complete=true}
    end
    activations.otherSeat.seatPos=2
    activations.multiple.uses={{index=1,frozenCounts={red=1},lastCounts={blue=1}},
        {index=2,lastCounts={red=2}}}
    records[key("multiple",2)]={complete=true}
    records[key("incomplete",1)].complete=false
    local calculate=dofile("src/PlayingGame/PlayerBoard/ResourceTracker/Units/UnitSelfWounds.lua")(
        function(guid) return abilities[guid] end,
        function(guid,activation) return activation.uses end,key,
        function(guid) if guid~="missing" then return {guid=guid} end end,
        function(unit,choices,activation,counts)
            observed[activation]=counts
            if unit.guid=="unpaid" then return nil end
            return {index=activation.index}
        end)
    local active={}
    for guid in pairs(abilities) do
        if guid~="defeated" and guid~="unused" then active[#active+1]={key=key(guid,1)} end
    end
    active[#active+1]={key=key("multiple",2)}
    local groups={{sources=active},{rangeDefeated=true,sources={{key=key("defeated",1)}}}}
    local early,late=calculate(1,groups,records,activations)
    eq(early.block,true,"Block ability wounds before enemy damage")
    eq(late.block,nil,"Block wound is not a late wound")
    eq(late.attack,true,"Attack ability wounds in final Attack")
    eq(early.attack,nil,"Attack wound does not occur before enemy damage")
    eq(early.elemental,true,"Elemental Block is an early wound")
    eq(early.multiple,true,"Historical Block use retained")
    eq(late.multiple,true,"Later Attack use separately recognized")
    eq(observed[activations.multiple.uses[1]],activations.multiple.uses[1].frozenCounts,"Frozen mana preferred")
    eq(observed[activations.multiple.uses[2]],activations.multiple.uses[2].lastCounts,"Live count fallback")
    for _,guid in ipairs({"ordinary","otherSeat","incomplete","missing","defeated","unused","unpaid"}) do
        eq(early[guid],nil,guid.." has no early wound")
        eq(late[guid],nil,guid.." has no late wound")
    end
    local e,l=calculate(1,{{destroyed=true,sources=active}},records,activations)
    eq(next(e),nil,"Destroyed group grants no early wounds")
    eq(next(l),nil,"Destroyed group grants no late wounds")
    e,l=calculate(1,nil,records,activations)
    eq(next(e),nil,"Missing groups grants no early wounds")
    eq(next(l),nil,"Missing groups grants no late wounds")
    eq(records[key("block",1)].complete,true,"Scan records left intact")
    print("Unit self-wound phase timing and activation eligibility passed")
end)

run("resource-tracker-unit-management",function()
    -- Exercise Command ownership/exhaustion and the actual extracted Ready payment pass.
    local root="src/PlayingGame/PlayerBoard/ResourceTracker/"
    local retired={}
    local env=setmetatable({gStates={currentRound=2},gameCards={},cardResourceDefinitions={},
        unitLayoutObjectInAnyUnitArea=function(guid) return guid=="present" end,
        resourceUnitsRetireUnit=function(guid) retired[#retired+1]=guid end}, {__index=_G})
    local management=assert(loadfile(root.."Units/UnitManagement.lua","t",env))()
    env.resourceUnitsSpentCommands=management.spentCommands
    env.resourceUnitsSetCommandSpent=management.setCommandSpent
    eq(management.commandSpent("token"),false,"Fresh Command")
    management.setCommandSpent("token",true)
    env.gStates.unitSpentCommandTokens.owners.token="present"
    eq(management.adoptCommand("token","present",1,false),true,"Same Unit retains Command")
    eq(management.commandSpent("token"),true,"Same Unit remains spent")
    eq(management.adoptCommand("token","new",1,false),false,"Cannot steal existing Unit's Command")
    env.gStates.unitSpentCommandTokens.owners.token="departed"
    eq(management.adoptCommand("token","new",1,false),true,"Vacated Command can be adopted")
    eq(retired[1],"departed","Old Unit retired")
    eq(management.commandOwner("token"),"new","New owner recorded")
    eq(management.commandSpent("token"),false,"New Unit is ready")
    management.setCommandSpent("token",true)
    env.gStates.currentRound=3
    eq(management.commandSpent("token"),false,"New Round clears exhaustion")
    eq(management.commandOwner("token"),nil,"New Round clears ownership")
    env.gameCards={abc={resourceKey="ready"},one={level=1},two={level=2}}
    env.cardResourceDefinitions.ready={readyWithInfluence={maxLevel=2,costPerLevel=2}}
    env.gStates.unitReadyLinks={["abc#ready1"]={unitGUID="one"},["abc#ready2"]={unitGUID="two"}}
    local cancelled={}
    env.unitHistoryCancelReadySource=function(key)
        cancelled[#cancelled+1]=key
        env.gStates.unitReadyLinks[key]=nil
    end
    local scan=assert(loadfile(root.."Units/UnitScan.lua","t",env))()
    local records={abc={complete=true,powered=true}}
    local totals={influence=5}
    local spent,rescan=scan.payReadyInfluence({records=records,totals=totals})
    eq(spent,2,"First eligible Ready paid")
    eq(totals.influence,3,"Only affordable Ready deducted")
    eq(records.abc.readyInfluenceSpent,2,"Payment attributed to source")
    eq(cancelled[1],"abc#ready2","Unaffordable second Ready cancelled")
    eq(rescan,true,"Cancelled activation requests a new scan")
    print("Unit management and Ready payment regressions passed")
end)

run("ready-level-policy",function()
    local env=setmetatable({
        gameCards={low={level=2},high={level=3},source={cardType="Regular Unit"}},
        unitResourceDefinitions={source={{key="ready",readyMaxLevel=2}}},
        cardResourceDefinitions={},
        unitHistorySourceBase=function(key) return key end
    },{__index=_G})
    local policy=assert(loadfile("src/PlayingGame/PlayerBoard/ResourceTracker/Units/ReadyPolicy.lua","t",env))()
    eq(policy.sourceLevelLimit("source",1),2,"Read the printed Unit level limit")
    eq(policy.targetEligible("source","low",1),true,"Level II allowed")
    eq(policy.targetEligible("source","high",1),false,"Level III rejected")
end)

run("faction-reward-exchange",function()
    local env=setmetatable({gStates={manaSource={}}},{__index=_G})
    local scan=assert(loadfile("src/PlayingGame/PlayerBoard/ResourceTracker/Scanning/FactionRewardScan.lua","t",env))()
    local token={guid="reward",is_face_down=true}
    local rule={name="Manual reward"}
    local function evaluate(selection)
        local records={}
        scan.read({
            objects={reward=token},placements={reward="play"},records=records,current={},totals={},
            resourceObjectKind=function(obj) return obj==token and "factionReward" or nil end,
            factionRewardForObject=function(obj) return obj==token and rule or nil end,
            chosenEffect=function(guid,powered,choices)
                assert(guid=="reward" and powered==token.is_face_down)
                return selection and choices[selection] or nil
            end,
            effectHasTrackedResource=function(effect) return effect~=nil and effect.influence~=nil end,
            showChoiceButtons=function(obj,choices,flipped,linked,repeatLink,effect) end,
            addResourceAmounts=function(record,totals) end,
            setHighlight=function(obj,status,powered) end
        })
        return records.reward
    end
    local record=evaluate(1)
    eq(record.resources.influence,3,"Default exchange remains reversible Influence")
    eq(record.fameRep,nil,"Influence does not award Fame")
    record=evaluate(2)
    eq(record.fameRep.fame,1,"Fame is published by the existing ledger")
    eq(record.resources.influence,nil,"Fame replaces Influence")
    eq(evaluate(1).fameRep,nil,"Switching back retracts Fame")
    token.is_face_down=false
    record=evaluate(nil)
    eq(record.complete,false,"Recognition alone is not a completed effect")
    eq(record.status,"yellow","Unknown effect remains visibly partial")
end)

if #failures>0 then
    error(table.concat(failures,"\n\n"),0)
end

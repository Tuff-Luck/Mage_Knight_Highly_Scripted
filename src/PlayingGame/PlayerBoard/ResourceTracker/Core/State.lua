-- Initial private runtime state for one Resource Tracker instance.
-- A factory preserves the coordinator's ownership and never stores derived
-- observations in gStates. Lifecycle resets remain in CardRecognition.
return function()
    local trackerPrivate={}
    -- Small module-private state tables live here to keep sufficient headroom
    -- beneath Lua 5.2's 200-active-local limit when this module is bundled.
    trackerPrivate.generation={}
    -- One settling watcher per object and one render request per seat. A moving
    -- crystal must not block a second, already-settled card from updating.
    trackerPrivate.pendingSeatSettles={}
    trackerPrivate.pendingSeatRender={}
    -- Mana crystal figurines are still read for powering cards, but should never
    -- receive Resource Tracker highlights. Avoid repeated highlightOff calls.
    trackerPrivate.crystalHighlightCleared={}
    trackerPrivate.bySeat={}
    -- Known play sources survive transient shallow-zone exits while a card is
    -- lifted or still falling above the mat. Rebuilt from entries/scans, not saved.
    trackerPrivate.playCandidatesBySeat={}
    -- Protect explicit options and targets from half-complete relocation scans.
    trackerPrivate.playCardMovements={}
    trackerPrivate.playCandidateKind=function(kind)
        return kind=="card" or kind=="skill" or kind=="factionReward"
    end
    -- A choice lasts for one play; delayed departure checks must not race a return.
    trackerPrivate.choiceResetGenerationByGUID={}
    -- Highlights show how confidently the tracker understands the selected effect.
    -- Blue is a deliberate neutral/not-calculated state, not an illegal-play warning.
    -- Purple takes precedence when objects are linked; brightness indicates power.
    trackerPrivate.palette={
        green={{0.10,0.55,0.14},{0.35,1.00,0.38}},
        yellow={{0.62,0.48,0.08},{1.00,0.94,0.19}},
        blue={{0.08,0.34,0.64},{0.26,0.66,1.00}},
        purple={{0.47,0.19,0.62},{0.92,0.43,1.00}}
    }
    -- Distinguish elemental and physical damage. Otherwise a Ranged Fire Attack
    -- would be incorrectly added to the Physical Ranged field.
    trackerPrivate.totalsKeys={move=true,ranged=true,siege=true,attack=true,block=true,influence=true,healing=true,
        rangedFire=true,rangedIce=true,rangedColdFire=true,rangedPsychic=true,
        siegeFire=true,siegeIce=true,siegeColdFire=true,siegePsychic=true,
        attackFire=true,attackIce=true,attackColdFire=true,attackPsychic=true,
        blockFire=true,blockIce=true,blockColdFire=true,blockPsychic=true}
    return trackerPrivate
end

-- Cohesive CombatPanel services; preserve original lexical and factory boundaries.

-- CombatPanelLayout
local layout=(function()
-- Pure sizing and pagination for the Combat Calculator. No UI or assignment state.
-- TTS does not expose Unity's measured text width to Lua. Estimate 13px
-- display text by glyph type (and UTF-8 codepoint, not byte count), with
-- room for margins, so even long or translated enemy names stay readable.
local widthCache,widthCount={},0
local function estimatedTextWidth(label)
    label=tostring(label or "")
    local cached=widthCache[label]
    if cached~=nil then return cached end
    local width=18
    for i=1,#label do
        local byte=label:byte(i)
        if byte<128 then
            local char=label:sub(i,i)
            if char==" " then width=width+5
            elseif char=="i" or char=="l" or char=="I" or char=="t"
                or char=="f" or char=="r" or char=="j" or char=="1"
                or char=="'" or char=="." or char=="," then width=width+5
            elseif char=="M" or char=="W" or char=="m" or char=="w"
                or char=="@" then width=width+12
            elseif char:match("%u") then width=width+10
            else width=width+8 end
        elseif byte>=240 and byte<248 then width=width+17
        elseif byte>=224 and byte<240 then width=width+15
        elseif byte>=192 and byte<224 then width=width+10
        end
    end
    -- Bounded cache of pure string measurements; no UI or combat state.
    if widthCount>=512 then widthCache,widthCount={},0 end
    widthCache[label]=width
    widthCount=widthCount+1
    return width
end

-- Compact 13px name labels while retaining a margin for the glyph estimates.
local function enemyNameColumnWidth(label)
    return math.max(54,math.ceil(8+(estimatedTextWidth(label)-18)*0.85))
end

-- Size textual combat columns from the longest displayed line rather than the
-- combined length of multiline abilities/attacks. Ignore TTS rich-text tags.
local function textColumnWidth(texts,minWidth)
    local width=minWidth or 78
    for _,text in pairs(texts or {}) do
        local plain=tostring(text or ""):gsub("<[^>]+>","")
        for line in plain:gmatch("[^\n]+") do
            width=math.max(width,math.max(74,math.ceil(estimatedTextWidth(line))))
        end
    end
    return width
end
local function traitColumnWidth(traits)
    return textColumnWidth(traits,78)
end

local function paginate(entries,joined,crowdedPageSize,rowCount,page)
    local pageSize=#entries>crowdedPageSize
        and crowdedPageSize or rowCount
    -- Keep joined groups together on a page whenever they fit. Combat math always
    -- covers every enemy; paging only controls which rows are displayed.
    local pageStarts,pageEnds={},{}
    local nextStart=1
    while nextStart<=#entries do
        local finish=math.min(#entries,nextStart+pageSize-1)
        if finish<#entries then
            local boundary=finish
            while boundary>nextStart do
                local nextEnemy=entries[boundary+1]
                if joined[nextEnemy.guid]~=true
                    or entries[boundary].destroyed or nextEnemy.destroyed
                    or entries[boundary].attackOnly or nextEnemy.attackOnly then break end
                boundary=boundary-1
            end
            -- Oversized groups can span pages; never leave a page empty.
            if boundary>nextStart then finish=boundary end
        end
        pageStarts[#pageStarts+1]=nextStart
        pageEnds[#pageEnds+1]=finish
        nextStart=finish+1
    end
    local pages=math.max(1,#pageStarts)
    page=math.max(1,math.min(page,pages))
    local pageOffset=(pageStarts[page] or 1)-1
    local pageEnd=pageEnds[page] or 0
    local visibleRows=pageEnd-pageOffset
    return page,pages,pageOffset,pageEnd,visibleRows
end

local function nameColumnWidth(entries,groupOf,pageOffset,pageEnd)
    -- The name and header occupy one shared column. Size it from the longest
    -- name on this page, including the '+ ' prefix for a joined enemy.
    local enemyNameWidth=54
    for index=pageOffset+1,pageEnd do
        local entry=entries[index]
        local joined=groupOf[index]~=nil and groupOf[index].leader~=index
        local label=(joined and "+ " or "")..tostring(entry.name or "")
        enemyNameWidth=math.max(enemyNameWidth,enemyNameColumnWidth(label))
    end
    return enemyNameWidth
end

return {enemyNameColumnWidth=enemyNameColumnWidth,textColumnWidth=textColumnWidth,
    traitColumnWidth=traitColumnWidth,paginate=paginate,nameColumnWidth=nameColumnWidth,
    estimatedTextWidth=estimatedTextWidth}
end)()

-- CombatPanelRenderer
local renderer=(function()
local estimatedTextWidth=layout.estimatedTextWidth
-- Apply panel geometry, damage summary and final header/overflow attributes.
return function(combatConfig,combatPanelSetAttribute,combatRich,combatWoundsText,joinLang)
    local function columns(shownTraits,shownOffence,shownAttacks,colUsed,maxResourceCounts,enemyNameWidth)
        -- Hide a column when every visible enemy leaves it blank or "None".
        local function textBlank(text) return text==nil or text=="" or text=="None" or text=="-" end
        local colShown={range=colUsed.range,block=colUsed.block,attack=colUsed.attack,traits=false,offence=false,enemyAttack=false}
        for row=1,combatConfig.rowCount do
            if not textBlank(shownTraits[row]) then colShown.traits=true end
            if not textBlank(shownOffence[row]) then colShown.offence=true end
            if not textBlank(shownAttacks[row]) then colShown.enemyAttack=true end
        end
        -- Keep columns aligned across visible enemy rows, but size each
        -- resource phase to its fullest row (three to six icons wide).
        -- GridLayout wraps additional icons below the first line.
        local columnWidths={
            traits=combatConfig.traitColumnWidth(shownTraits),
            offence=combatConfig.textColumnWidth(shownOffence,math.max(74,estimatedTextWidth("Off. Ability"))),
            enemyAttack=combatConfig.textColumnWidth(shownAttacks,math.max(74,estimatedTextWidth("E. Attack")))
        }
        -- Text columns share widths with their headers. Recalculate for each page
        -- and refresh, including after ranged kills remove attacks/abilities.
        for row=1,combatConfig.rowCount do
            combatPanelSetAttribute("CombatEnemyRow"..row.."Traits","preferredWidth",tostring(columnWidths.traits))
            combatPanelSetAttribute("CombatEnemyAttackCell"..row,"preferredWidth",tostring(columnWidths.enemyAttack))
            combatPanelSetAttribute("CombatEnemyRow"..row.."Attacks","preferredWidth",tostring(columnWidths.enemyAttack))
            combatPanelSetAttribute("CombatEnemyRow"..row.."Offence","preferredWidth",tostring(columnWidths.offence))
        end
        for _,family in ipairs({"range","block","attack"}) do
            local columns=math.max(3,math.min(combatConfig.lineSlotCount,maxResourceCounts[family]))
            columnWidths[family]=columns*24
            for row=1,combatConfig.rowCount do
                combatPanelSetAttribute("CombatSourceCell"..row..family,"preferredWidth",
                    tostring(columnWidths[family]))
                combatPanelSetAttribute("CombatSourceGrid"..row..family,"constraintCount",tostring(columns))
                combatPanelSetAttribute("CombatSourceGrid"..row..family,"width",
                    tostring(columnWidths[family]))
            end
        end
        local headerIDs={traits="CombatDefenceTraitsHeader",range="CombatRangeSiegeHeader",offence="CombatOffenceHeader",
            enemyAttack="CombatEnemyAttackHeader",
            block="CombatBlockHeader",attack="CombatAssignedAttackHeader"}
        -- Outer layout: 6+6 horizontal padding; header/rows: 5 left padding.
        -- Sum visible cells directly rather than subtracting from a legacy wide panel.
        local baseWidth=17+enemyNameWidth+55
        for column,shown in pairs(colShown) do
            local active=shown and "true" or "false"
            if shown then baseWidth=baseWidth+columnWidths[column] end
            combatPanelSetAttribute(headerIDs[column],"active",active)
            for index=1,combatConfig.rowCount do
                local cell=(column=="traits" and "CombatEnemyRow"..index.."Traits")
                    or (column=="offence" and "CombatEnemyRow"..index.."Offence")
                    or (column=="enemyAttack" and "CombatEnemyAttackCell"..index)
                    or "CombatSourceCell"..index..column
                combatPanelSetAttribute(cell,"active",active)
            end
        end

        return columnWidths,baseWidth
    end

    -- Measure only visible result text, including the expansion marker.
    -- Use the cached solution so opening a result never reruns combat.
    local function refreshResultWidth(expandedResults)
        local width=65
        for _,cache in pairs(combatConfig.resultRowCache or {}) do
            local expanded=cache.hasDetails and expandedResults[cache.guid]==true
            local display=expanded and cache.detailText or cache.compactText
            if cache.hasDetails then display=display..(expanded and " [-]" or " [+]") end
            for line in display:gsub("<[^>]+>",""):gmatch("[^\n]+") do
                width=math.max(width,math.ceil(10+(estimatedTextWidth(line)-18)*0.82))
            end
        end
        combatPanelSetAttribute("CombatResultHeader","preferredWidth",tostring(width))
        for row=1,combatConfig.rowCount do
            combatPanelSetAttribute("CombatEnemyResultToggle"..row,"preferredWidth",tostring(width))
            combatPanelSetAttribute("CombatEnemyRow"..row.."Result","preferredWidth",tostring(width))
        end
        local panelWidth=math.max(combatConfig.combatPanelMinimumWidth or 0,
            (combatConfig.combatPanelBaseWidth or 0)+width)
        combatPanelSetAttribute("CombatEnemyPanel","width",tostring(panelWidth))
    end

    local function woundSummary(totalHeroWounds,totalDiscardWounds,knockout,pendingHand,pendingDiscard,changed,effects)
        -- Unit assignments need a phase commit even when no Wound is drawn.
        local showTotal=totalHeroWounds>0 or knockout or effects.destroyCount>0
            or effects.handDiscard or effects.stagedDiscardCount>0
            or (effects.unitAssignments or 0)>0
        combatConfig.combatPanelShowsWounds=showTotal
        combatPanelSetAttribute("CombatTotalRow","active",showTotal and "true" or "false")
        if showTotal then
            -- The XML's fixed-width, right-anchored Panel is outside any
            -- HorizontalLayout, so Unity's layout group cannot expand its child.
            local poisonText=totalDiscardWounds>0 and " ("..tostring(totalDiscardWounds).." Poison)" or ""
            local text=totalHeroWounds>0
                and ("Draw: "..combatRich(combatWoundsText(totalHeroWounds)..poisonText,combatConfig.COMBAT_RED))
                or (effects.handDiscard and "Apply: Discard hand"
                    or (effects.stagedDiscardCount>0 and "Apply: Discard Attack"
                        or (knockout and "Knocked out (applied)"
                        or (effects.destroyCount>0 and ("Apply: Destroy "..tostring(effects.destroyCount)..
                            (effects.destroyCount==1 and " Unit" or " Units"))
                            or (effects.unitCommitPending and "Draw: 0 Wounds" or "Damage: Confirmed")))))
            combatPanelSetAttribute("CombatTotalDamage","text",text)
            combatPanelSetAttribute("CombatTotalDamage","font","Fonts/MKCardText")
            local pending=pendingHand+pendingDiscard>0
                or effects.handDiscard or effects.destroyCount>0
                or effects.stagedDiscardCount>0 or effects.unitCommitPending
            combatPanelSetAttribute("CombatApplyWounds","interactable",
                (pending or changed) and not combatConfig.woundApplying and "true" or "false")
            combatPanelSetAttribute("CombatApplyWounds","color",
                pending and "rgb(0.48,0.36,0.20)" or changed and "rgb(0.49,0.30,0.22)"
                or "rgb(0.23,0.37,0.24)")
            -- The commit confirmation already explains the consequences.
            -- Clear any tooltip cached from an earlier calculator refresh.
            combatPanelSetAttribute("CombatApplyWounds","tooltip","")
            combatPanelSetAttribute("CombatKnockoutWarning","active",knockout and "true" or "false")
            if knockout then
                combatPanelSetAttribute("CombatKnockoutWarning","text",
                    "KNOCKED OUT")
                combatPanelSetAttribute("CombatKnockoutWarning","font","Fonts/MKCardText")
            end
            local summaryHeight=knockout and 40 or 22
            combatPanelSetAttribute("CombatTotalRow","preferredHeight",tostring(summaryHeight))
            return summaryHeight
        end
        return 0
    end

    local function finish(overflow,baseWidth,columnWidths,enemyNameWidth,expandedResults,pages)
        -- A solo enemy can show twelve icons per phase; larger grouped stacks
        -- continue onto the next member row. Do not silently hide any remainder.
        combatPanelSetAttribute("CombatResourceOverflow","active",overflow>0 and "true" or "false")
        if overflow>0 then
            combatPanelSetAttribute("CombatResourceOverflow","text",joinLang({
                "{en}"..overflow.." resource icons exceed the available rows.",
                "{it}"..overflow.." icone delle risorse oltre le righe disponibili.",
                "{ru}"..overflow.." значков ресурсов не помещается в строках.",
                "{zh-tw}有 "..overflow.." 個資源圖示超出可用列數。",
                "{zh-cn}有 "..overflow.." 个资源图标超出可用行数。",
                "{ko}"..overflow.."개 자원 아이콘이 표시 행을 초과했습니다.",
                "{es}"..overflow.." iconos de recursos superan las filas disponibles.",
                "{fr}"..overflow.." icônes de ressources dépassent les lignes disponibles.",
                "{pt-br}"..overflow.." ícones de recursos excedem as linhas disponíveis.",
                "{de}"..overflow.." Ressourcensymbole passen nicht in die verfügbaren Zeilen."
            }))
        end
        combatConfig.combatPanelBaseWidth=baseWidth
        -- Preserve room for the absolutely anchored damage prompt and wound button.
        combatConfig.combatPanelMinimumWidth=math.max(combatConfig.combatPanelShowsWounds and 430 or 0,
            pages>1 and 260 or 0,overflow>0 and 350 or 0)
        refreshResultWidth(expandedResults)
        combatPanelSetAttribute("CombatEnemyPanel","color","rgb(0.24,0.2,0.15)")
        local headerWidths={Monster=enemyNameWidth,Armour=55,DefenceTraits=columnWidths.traits,RangeSiege=columnWidths.range,
            EnemyAttack=columnWidths.enemyAttack,Offence=columnWidths.offence,
            Block=columnWidths.block,AssignedAttack=columnWidths.attack}
        combatPanelSetAttribute("CombatResultHeader","font","Fonts/MKCardTittle")
        combatPanelSetAttribute("CombatResultHeader","color","rgb(0.95,0.9,0.78)")
        for name,width in pairs(headerWidths) do
            local id="Combat"..name.."Header"
            combatPanelSetAttribute(id,"font","Fonts/MKCardTittle")
            combatPanelSetAttribute(id,"color","rgb(0.95,0.9,0.78)")
            combatPanelSetAttribute(id,"preferredWidth",tostring(width))
            if name=="DefenceTraits" or name=="Offence" then
                combatPanelSetAttribute(id,"alignment","MiddleCenter")
            end
        end
    end
    return {columns=columns,woundSummary=woundSummary,finish=finish,refreshResultWidth=refreshResultWidth}
end
end)()

return {layout=layout,renderer=renderer}

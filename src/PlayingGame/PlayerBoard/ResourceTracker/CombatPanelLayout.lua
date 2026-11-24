-- Pure sizing and pagination for the Combat Calculator. No UI or assignment state.
-- TTS does not expose Unity's measured text width to Lua. Estimate 13px
-- display text by glyph type (and UTF-8 codepoint, not byte count), with
-- room for margins, so even long or translated enemy names stay readable.
local function enemyNameColumnWidth(label)
    label=tostring(label or "")
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
    return math.max(74,math.ceil(width))
end

-- Size textual combat columns from the longest displayed line rather than the
-- combined length of multiline abilities/attacks. Ignore TTS rich-text tags.
local function textColumnWidth(texts,minWidth)
    local width=minWidth or 78
    for _,text in pairs(texts or {}) do
        local plain=tostring(text or ""):gsub("<[^>]+>","")
        for line in plain:gmatch("[^\n]+") do
            width=math.max(width,enemyNameColumnWidth(line))
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
    local enemyNameWidth=74
    for index=pageOffset+1,pageEnd do
        local entry=entries[index]
        local joined=groupOf[index]~=nil and groupOf[index].leader~=index
        local label=(joined and "+ " or "")..tostring(entry.name or "")
        enemyNameWidth=math.max(enemyNameWidth,enemyNameColumnWidth(label))
    end
    return enemyNameWidth
end

return {enemyNameColumnWidth=enemyNameColumnWidth,textColumnWidth=textColumnWidth,
    traitColumnWidth=traitColumnWidth,paginate=paginate,nameColumnWidth=nameColumnWidth}

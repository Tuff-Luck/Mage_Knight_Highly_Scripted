-- Ordered combat groups and their assigned source records, independent of UI and targeting.
local function build(entries,joined)
    -- Joined enemies form a group (the leader is its first row) that is attacked as one.
    local groups,groupOf={},{}
    for index=1,#entries do
        local group=groups[#groups]
        if index==1 or joined[entries[index].guid]~=true
            or entries[index].destroyed or entries[index-1].destroyed
            or entries[index].attackOnly or entries[index-1].attackOnly then
            group={members={},sources={}}
            groups[#groups+1]=group
        end
        group.members[#group.members+1]=index
        group.leader=group.members[1]
        groupOf[index]=group
    end
    return groups,groupOf
end

local function collect(group,entries,allocated)
    local members,sources={},{}
    for _,index in ipairs(group.members) do
        members[#members+1]=entries[index]
        for _,source in ipairs((allocated[index] or {sources={}}).sources) do
            sources[#sources+1]=source
        end
    end
    return members,sources
end

return {build=build,collect=collect}

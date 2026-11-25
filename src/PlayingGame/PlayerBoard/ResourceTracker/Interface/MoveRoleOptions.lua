-- Shared Move option policy. Choice IDs and activation ownership stay with
-- their Card/Unit adapters; the saved role remains in resourceCardMoveRoles.
local M={}
function M.producesMove(option,category)
    return option~=nil and ((tonumber(option.move) or 0)>0
        or (option.shapeshiftTargetGUID~=nil and category=="move"))
end

function M.hasAlternative(producesMove,available)
    return producesMove and not not available
end

-- A nil requested role means an ordinary option. Combat is valid only
-- for a Move-producing effect when the owning source permits Combat Move.
function M.resolve(producesMove,available,requestedRole)
    if requestedRole=="combat" then
        if M.hasAlternative(producesMove,available) then return "combat",true end
        return nil,false
    end
    return producesMove and "movement" or nil,true
end

function M.cardCategory(category,role)
    return role=="combat" and "combatMove"..category or category
end

function M.decodeCardCategory(category)
    local original=category:match("^combatMove(.+)$")
    if original~=nil then return original,"combat" end
    return category,nil
end

function M.visibleRoles(dual,expanded,role)
    return not dual or expanded or role~="combat",
        dual and (expanded or role=="combat")
end

function M.badge(role)
    return role=="combat" and "C" or "M"
end

function M.badgeNode(letter)
    return {tag="Text",attributes={text=letter,width=82,height=82,
        alignment="LowerRight",fontSize=37,fontStyle="Bold",
        color=letter=="C" and "#69AEFF" or "#9AFFA4",
        outline="#101820",outlineSize="2 -2",raycastTarget="false"}}
end

return M

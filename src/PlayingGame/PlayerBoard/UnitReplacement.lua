-- Player-confirmed replacement when every Command slot is occupied.
-- The selected Unit is disbanded only AFTER a safe rewind snapshot is stored.
-- Physical Command slots remain owned by UnitLayout; spent-history handoff is
-- owned by CardRecognition / UnitHistory.
local REPLACEMENT_PREFIX="UnitReplaceSelect_"
local function replacementState()
    return gStates~=nil and gStates.unitReplacementPending or nil
end

local function replacementUnitName(guid)
    local data=gameCards~=nil and gameCards[guid] or nil
    local name=data~=nil and data.name or nil
    return type(name)=="table" and name[1] or tostring(guid)
end

local function replacementPlayerAllowed(player,state)
    return player~=nil and state~=nil and player.color~=nil
        and legalPlayerCheck(player.color,state.seatPos)==true
        and gStates.turnNumber==state.turnNumber
end

local function replacementOfferUnit(guid)
    local unit=guid~=nil and getObjectFromGUID(guid) or nil
    local data=guid~=nil and gameCards[guid] or nil
    if unit==nil or data==nil
        or (data.cardType~="Regular Unit" and data.cardType~="Elite Unit")
        or not objectGUIDInZone(guid,GUID.zone.unitOffer) then return nil end
    return unit
end

local function replacementRemoveUnitButton(unit)
    if unit==nil or unit.UI==nil then return end
    local xml=resourceObjectUiXmlTable(unit.UI)
    local changed=false
    for i=#xml,1,-1 do
        local attributes=xml[i].attributes
        local id=attributes~=nil and attributes.id or nil
        if type(id)=="string" and id:sub(1,#REPLACEMENT_PREFIX)==REPLACEMENT_PREFIX then
            table.remove(xml,i)
            changed=true
        end
    end
    if changed then
        resourceObjectUiSetTable(unit.UI,xml,
            resourceCardsExistingImageAssetsFor(unit.UI,{}))
    end
end

local function replacementShowUnitButton(unit,selected)
    if unit==nil or unit.UI==nil then return end
    local xml=resourceObjectUiXmlTable(unit.UI)
    local expected=REPLACEMENT_PREFIX..unit.guid
    for i=#xml,1,-1 do
        local attributes=xml[i].attributes
        local id=attributes~=nil and attributes.id or nil
        if type(id)=="string" and id:sub(1,#REPLACEMENT_PREFIX)==REPLACEMENT_PREFIX then
            table.remove(xml,i)
        end
    end
    xml[#xml+1]={tag="Button",attributes={
        id=expected,onClick="global/unitReplacementSelectClicked",
        position="0 -205 -38",rotation="0 0 180",
        width=200,height=80,scale="0.25 0.25",fontSize=38,
        textColor="#FFFFFF",textAlignment="MiddleCenter",
        colors=selected and "#28672E|#36973F|#28672E|#28672E"
            or "#80451D|#A46627|#80451D|#80451D"},
        value=selected and "SELECTED" or "DISBAND"}
    resourceObjectUiSetTable(unit.UI,xml,
        resourceCardsExistingImageAssetsFor(unit.UI,{}))
end

local function replacementClearVisuals(state)
    if state~=nil then
        -- Use both saved candidates and the current layout, since a card can
        -- be lifted or manually removed while the selection is displayed.
        local seen={}
        for _,guid in ipairs(state.candidates or {}) do
            local unit=getObjectFromGUID(guid)
            if unit~=nil then
                seen[guid]=true
                replacementRemoveUnitButton(unit)
                if unit.highlightOff~=nil then unit.highlightOff() end
            end
        end
        local layout=unitLayoutSnapshot(state.seatPos)
        for _,unit in ipairs(layout.units) do
            if not seen[unit.guid] then
                replacementRemoveUnitButton(unit)
                if unit.highlightOff~=nil then unit.highlightOff() end
            end
        end
    end
    UI.setAttribute("UnitReplacement","active","false")
end

function unitReplacementClose()
    local state=replacementState()
    if state~=nil then replacementClearVisuals(state) end
    if gStates~=nil then gStates.unitReplacementPending=nil end
    -- The temporary selection highlight replaces the Resource Tracker's
    -- normal Unit highlights. Restore those after cancelling or completing.
    if state~=nil and resourceCardsSourceChanged~=nil then
        resourceCardsSourceChanged()
    end
end

local function replacementRender(state)
    if state==nil then return end
    local layout=unitLayoutSnapshot(state.seatPos)
    local current={}
    for _,unit in ipairs(layout.units) do current[unit.guid]=unit end
    for _,guid in ipairs(state.candidates or {}) do
        if current[guid]==nil then
            local removed=getObjectFromGUID(guid)
            if removed~=nil then replacementRemoveUnitButton(removed) end
        end
    end
    state.candidates={}
    for _,unit in ipairs(layout.units) do
        if layout.unitSlotByGuid[unit.guid]~=nil then
            state.candidates[#state.candidates+1]=unit.guid
            replacementShowUnitButton(unit,unit.guid==state.selectedGUID)
            if unit.highlightOn~=nil then
                unit.highlightOn(unit.guid==state.selectedGUID
                    and {0.25,0.95,0.30} or {1,0.60,0.12})
            end
        end
    end
    if current[state.selectedGUID]==nil then state.selectedGUID=nil end
    UI.setAttribute("UnitReplacement","active","true")
    UI.setAttribute("UnitReplacementClaimText","text",
        replacementUnitName(state.claimGUID))
    UI.setAttribute("UnitReplacementSelectedText","text",
        state.selectedGUID~=nil and replacementUnitName(state.selectedGUID)
            or "{en}Select a Unit on your board.{it}Scegli un'Unità sulla plancia.{ru}Выберите отряд на планшете.{zh-tw}選擇一個現有單位。{zh-cn}选择一个现有单位。{ko}기존 유닛을 선택하세요.{es}Elige una Unidad del tablero.{fr}Choisissez une Unité sur votre plateau.{pt-br}Escolha uma Unidade no tabuleiro.{de}Wähle eine Einheit auf dem Spielertableau.")
    UI.setAttribute("UnitReplacementConfirm","interactable",
        state.selectedGUID~=nil and "true" or "false")
end

function unitReplacementEnsureControls(seatPos)
    local state=replacementState()
    if state==nil or (seatPos~=nil and seatPos~=state.seatPos) then return end
    -- CardRecognition and UnitLayout may rewrite Unit object UI during a
    -- scan. Repaint only controls that are genuinely missing; do not disrupt
    -- normal activation/targeting buttons on every refresh.
    local layout=unitLayoutSnapshot(state.seatPos)
    for _,unit in ipairs(layout.units) do
        local exists=false
        for _,node in ipairs(resourceObjectUiXmlTable(unit.UI)) do
            if node.attributes~=nil
                and node.attributes.id==REPLACEMENT_PREFIX..unit.guid then
                exists=true
                break
            end
        end
        if not exists then replacementShowUnitButton(unit,unit.guid==state.selectedGUID) end
    end
end

function unitReplacementBegin(player,claimGUID,seatPos)
    if replacementState()~=nil or gStates==nil or player==nil
        or legalPlayerCheck(player.color,seatPos)~=true then return false end
    if replacementOfferUnit(claimGUID)==nil then return false end
    local slot=unitLayoutFirstFreeCommand(seatPos)
    if slot~=nil then return false end
    local state={seatPos=seatPos,turnNumber=gStates.turnNumber,
        claimGUID=claimGUID,candidates={},selectedGUID=nil}
    gStates.unitReplacementPending=state
    replacementRender(state)
    return true
end

function unitReplacementRestoreOnLoad()
    local state=replacementState()
    if state==nil then
        UI.setAttribute("UnitReplacement","active","false")
        return
    end
    if state.turnNumber~=gStates.turnNumber
        or replacementOfferUnit(state.claimGUID)==nil then
        unitReplacementClose()
        return
    end
    replacementRender(state)
end

local function unitReplacementSelectClicked(player,value,id)
    local state=replacementState()
    if not replacementPlayerAllowed(player,state) then return end
    local guid=type(id)=="string" and id:match("^UnitReplaceSelect_([0-9a-f]+)$") or nil
    local layout=unitLayoutSnapshot(state.seatPos)
    if guid==nil or layout.unitSlotByGuid[guid]==nil then return end
    state.selectedGUID=guid
    replacementRender(state)
end

local function unitReplacementCancel(player)
    local state=replacementState()
    if not replacementPlayerAllowed(player,state) then return end
    unitReplacementClose()
end

-- The old Unit's Wound markers leave play; attached Banner Artifacts go to
-- the player's DISCARD (base rules), not into the Trash or onto the new Unit.
-- Command sources (including Banner of Command and Bonds) are never removed.
local function replacementDetachAccessories(layout,unit,seatPos)
    local bounds=unit.getBounds()
    local size=bounds~=nil and bounds.size or nil
    local centre=bounds~=nil and bounds.center or unit.getPosition()
    local cx,cz=centre.x or centre[1],centre.z or centre[3]
    local halfX=size~=nil and (size.x or size[1])*0.46 or 1
    local halfZ=size~=nil and (size.z or size[3])*0.46 or 1.5
    local woundBag=getObjectFromGUID("ab56f3") or getObjectFromGUID(trashCan)
    for _,obj in ipairs(layout.objects) do
        if unitLayoutIsWound(obj) then
            local p=obj.getPosition()
            if math.abs((p.x or p[1])-cx)<halfX
                and math.abs((p.z or p[3])-cz)<halfZ
                and woundBag~=nil then woundBag.putObject(obj) end
        end
    end
    local state=unitLayoutResourceState(seatPos)
    local banners=state~=nil and state.bannersByUnit[unit.guid] or nil
    local discardZone=getObjectFromGUID(deedDeckDiscardZones[seatPos])
    if banners~=nil and discardZone~=nil then
        local pos=discardZone.getPosition()
        for _,banner in pairs(banners) do
            local card=getObjectFromGUID(banner.guid)
            if card~=nil then
                card.unlock()
                card.setPositionSmooth({(pos.x or pos[1]),(pos.y or pos[2])+2,
                    (pos.z or pos[3])},false,false)
            end
        end
    end
end

local function replacementValid(state)
    if state==nil or state.turnNumber~=gStates.turnNumber then return nil end
    local claimed=replacementOfferUnit(state.claimGUID)
    local old=state.selectedGUID~=nil and getObjectFromGUID(state.selectedGUID) or nil
    local layout=unitLayoutSnapshot(state.seatPos)
    local slot=old~=nil and layout.unitSlotByGuid[old.guid] or nil
    local token=slot~=nil and layout.commands[slot] or nil
    local unitX=slot~=nil and layout.slotX[slot] or nil
    if claimed==nil or old==nil or token==nil or unitX==nil
        or layout.unitBySlot[slot]==nil
        or layout.unitBySlot[slot].guid~=old.guid then return nil end
    return claimed,old,layout,unitX,token
end

local function unitReplacementConfirm(player)
    local state=replacementState()
    if not replacementPlayerAllowed(player,state) then return end
    local claimed,old,layout,unitX,token=replacementValid(state)
    if claimed==nil then
        replacementRender(state)
        broadcastToColor("{en}The Unit offer or board changed. Select the Unit to replace again.{it}L'offerta o la plancia sono cambiate. Seleziona di nuovo l'Unità.{ru}Предложение или планшет изменились. Выберите отряд снова.",player.color,warningColor)
        return
    end
    if cardFlowUnitClaimBusy~=nil and cardFlowUnitClaimBusy() then return end
    local owner="Replace Unit "..state.claimGUID
    local expectedSelected=state.selectedGUID
    if rewindTransactionOwnerActive(owner) then return end
    rewindTransactionStart(function()
        -- A rewind snapshot may take several frames; do not apply a stale
        -- selection or destroy the Unit if the table changed meanwhile.
        local pending=replacementState()
        local newUnit,oldUnit,currentLayout,x,command=replacementValid(pending)
        local trash=getObjectFromGUID(trashCan)
        if newUnit==nil or trash==nil or pending.selectedGUID~=expectedSelected
            or (cardFlowUnitClaimBusy~=nil and cardFlowUnitClaimBusy()) then
            rewindTransactionFinish(owner)
            if pending~=nil then replacementRender(pending) end
            return
        end
        -- A spent token can physically cover the discarded card. Move it to
        -- the actual READY snap before placing the new Unit; clearing its
        -- history flag alone would leave the replacement visibly spent.
        local tokenOnOld=unitLayoutCommandTarget(command,pending.seatPos)
        local readyPosition=nil
        if tokenOnOld~=nil and tokenOnOld.guid==oldUnit.guid then
            readyPosition=unitLayoutReadyCommandPosition(pending.seatPos,
                currentLayout.unitSlotByGuid[oldUnit.guid],currentLayout)
            if readyPosition==nil then
                rewindTransactionFinish(owner)
                broadcastToColor("{en}Cannot find the Command Ready snap. Move the Command above the Unit and try again.{it}Posizione Comando pronto non trovata. Sposta il segnalino e riprova.{ru}Позиция готового жетона не найдена. Переместите жетон и повторите.",player.color,warningColor)
                return
            end
        end
        replacementDetachAccessories(currentLayout,oldUnit,pending.seatPos)
        if resourceUnitsRetireUnit~=nil then resourceUnitsRetireUnit(oldUnit.guid) end
        if readyPosition~=nil then command.setPositionSmooth(readyPosition,false,false) end
        trash.putObject(oldUnit)
        -- Claiming and disbanding share ONE rewind point. Release it only
        -- after both the replacement Unit and its reused Command have settled.
        local commandGUID=command.guid
        local claimedOK=cardFlowClaimUnitAtSlot(newUnit,pending.seatPos,x,currentLayout,
            command,function()
                local function completed()
                    rewindTransactionFinish(owner)
                    if resourceCardsSourceChanged~=nil then resourceCardsSourceChanged() end
                end
                if readyPosition==nil then
                    completed()
                else
                    safeWaitCondition("PlayerBoard.UnitReplacement",completed,function()
                        local token=getObjectFromGUID(commandGUID)
                        return token==nil or (token.resting==true
                            and token.isSmoothMoving()==false)
                    end,8,completed)
                end
            end)
        if claimedOK then
            unitReplacementClose()
        else
            -- A failed physical claim should be extremely rare and can be
            -- recovered with the saved rewind snapshot.
            rewindTransactionFinish(owner)
            broadcastToColor("{en}The Unit did not settle into its slot. Use Undo to restore the old Unit.{it}La nuova Unità non è stata posizionata. Usa Annulla per ripristinare la precedente.{ru}Новый отряд не разместился. Используйте Отменить для восстановления.",player.color,warningColor)
        end
    end,owner)
end

publishPublicUICallbacks({
    unitReplacementSelectClicked=unitReplacementSelectClicked,
    unitReplacementCancel=unitReplacementCancel,
    unitReplacementConfirm=unitReplacementConfirm
})

-- Player-confirmed replacement when every Command slot is occupied.
-- The selected Unit is disbanded only AFTER a safe rewind snapshot is stored.
-- Physical Command slots remain owned by UnitLayout; spent-history handoff is
-- owned by CardRecognition / UnitHistory.
local REPLACEMENT_PREFIX="UnitReplaceSelect_" -- only for removing old visible saved buttons
local REPLACEMENT_CLICK="unitReplacementSelectClicked"
local unitReplacementConfirm -- forward reference for the direct Unit click callback
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

-- Old builds attached a visible DISBAND button in the Unit's XML.
-- Strip it once, including in saves paused at an unfinished replacement.
local function replacementRemoveLegacyButton(unit)
    if unit==nil or unit.UI==nil then return end
    local xml=resourceObjectUiXmlTable(unit.UI)
    local changed=false
    for i=#xml,1,-1 do
        local attr=xml[i].attributes
        local id=attr~=nil and attr.id or nil
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

local function replacementRemoveUnitButton(unit)
    if unit==nil then return end
    replacementRemoveLegacyButton(unit)
    if attackAssignmentsRemoveInvisibleUnitTargetButton~=nil then
        attackAssignmentsRemoveInvisibleUnitTargetButton(unit,REPLACEMENT_CLICK)
    end
end

local function replacementShowUnitButton(unit)
    if unit==nil then return end
    replacementRemoveLegacyButton(unit)
    -- Exactly the same invisible full-card target used for assigning enemy
    -- damage to a Unit; no visible object UI buttons or labels.
    if attackAssignmentsAddInvisibleUnitTargetButton~=nil then
        attackAssignmentsAddInvisibleUnitTargetButton(unit,REPLACEMENT_CLICK)
    end
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
            replacementRemoveUnitButton(getObjectFromGUID(guid))
        end
    end
    state.candidates={}
    for _,unit in ipairs(layout.units) do
        if layout.unitSlotByGuid[unit.guid]~=nil then
            state.candidates[#state.candidates+1]=unit.guid
            replacementShowUnitButton(unit)
            if unit.highlightOn~=nil then unit.highlightOn({1,0.60,0.12}) end
        end
    end
    UI.setAttribute("UnitReplacement","active","true")
    UI.setAttribute("UnitReplacementDescription","text",joinLang({
        "{en}No free Command Tokens.\nClick a Unit you wish to disband and Replace with {it}Nessun segnalino Comando libero.\nScegli un'Unità da congedare e sostituire con {ru}Нет свободных жетонов Командования.\nВыберите отряд для роспуска и замены на {zh-tw}沒有空閒指揮標記。\n點選要解散並替換的單位：{zh-cn}没有空闲指挥标记。\n点击要解散并替换的单位：{ko}남은 명령 토큰이 없습니다.\n해산하여 교체할 유닛을 클릭하세요: {es}No hay fichas de Mando libres.\nHaz clic en la Unidad que quieres disolver y reemplazar por {fr}Aucun jeton Commandement libre.\nCliquez sur l'Unité à dissoudre et remplacer par {pt-br}Sem fichas de Comando livres.\nClique na Unidade que deseja dispensar e substituir por {de}Keine freien Befehlsmarker.\nKlicke auf die Einheit, die du auflösen und ersetzen möchtest durch ",
        replacementUnitName(state.claimGUID),"."}))
end

function unitReplacementEnsureControls(seatPos)
    local state=replacementState()
    if state==nil or (seatPos~=nil and seatPos~=state.seatPos) then return end
    -- The Resource Tracker can rewrite card XML without affecting classic
    -- buttons. Reconcile invisible hit areas without stacking duplicates.
    for _,unit in ipairs(unitLayoutSnapshot(state.seatPos).units) do
        replacementShowUnitButton(unit)
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

-- Unit card is clicked directly, just as with enemy damage targeting.
-- The click is also confirmation: no second panel action is required.
local function unitReplacementSelectClicked(unit,playerColor)
    local state=replacementState()
    if unit==nil or not replacementPlayerAllowed({color=playerColor},state)
        or state.committing==true then return end
    local layout=unitLayoutSnapshot(state.seatPos)
    if layout.unitSlotByGuid[unit.guid]==nil then return end
    state.selectedGUID=unit.guid
    state.committing=true
    unitReplacementConfirm({color=playerColor})
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
    local bannerGUIDs={}
    if banners~=nil then
        local pos=discardZone~=nil and discardZone.getPosition() or nil
        for _,banner in pairs(banners) do
            bannerGUIDs[banner.guid]=true
            local card=getObjectFromGUID(banner.guid)
            if card~=nil and pos~=nil then
                card.unlock()
                card.setPositionSmooth({(pos.x or pos[1]),(pos.y or pos[2])+2,
                    (pos.z or pos[3])},false,false)
            end
        end
    end
    -- Preserve miscellaneous attached reminders and spent mana instead of
    -- silently transferring them to the incoming Unit or destroying them.
    -- Stage them outside the Unit Area so the calculator cannot mistake
    -- their old physical overlap for payment on the replacement.
    local extras=0
    local stagingX=unitLayoutX(seatPos,1,#layout.commands)-3.2
    for _,obj in ipairs(layout.objects) do
        if obj.guid~=unit.guid and not unitLayoutIsUnit(obj)
            and not unitLayoutIsCommand(obj) and not unitLayoutIsWound(obj)
            and bannerGUIDs[obj.guid]~=true and obj.setPositionSmooth~=nil
            and (obj.held_by_color==nil or obj.held_by_color=="") then
            local p=obj.getPosition()
            if math.abs((p.x or p[1])-cx)<halfX
                and math.abs((p.z or p[3])-cz)<halfZ then
                extras=extras+1
                obj.setPositionSmooth({stagingX+(extras-1)*0.55,
                    math.max(1.4,p.y or p[2]),-40.3},false,false)
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

unitReplacementConfirm=function(player)
    local state=replacementState()
    if not replacementPlayerAllowed(player,state) then return end
    local claimed,old,layout,unitX,token=replacementValid(state)
    if claimed==nil then
        state.committing=false
        state.selectedGUID=nil
        replacementRender(state)
        broadcastToColor("{en}The Unit offer or board changed. Select the Unit to replace again.{it}L'offerta o la plancia sono cambiate. Seleziona di nuovo l'Unità.{ru}Предложение или планшет изменились. Выберите отряд снова.",player.color,warningColor)
        return
    end
    if cardFlowUnitClaimBusy~=nil and cardFlowUnitClaimBusy() then
        state.committing=false
        return
    end
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
            if pending~=nil then
                pending.committing=false
                pending.selectedGUID=nil
                replacementRender(pending)
            end
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
                pending.committing=false
                pending.selectedGUID=nil
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
    end,owner,function()
        -- Snapshot failure must not leave the selection locked.
        local pending=replacementState()
        if pending~=nil and pending.claimGUID==state.claimGUID then
            pending.committing=false
            pending.selectedGUID=nil
        end
    end)
end

publishPublicUICallbacks({
    unitReplacementSelectClicked=unitReplacementSelectClicked,
    unitReplacementCancel=unitReplacementCancel
})

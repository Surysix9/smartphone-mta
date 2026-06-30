function getDB()
    local coreRes = getResourceFromName("core")
    if coreRes and getResourceState(coreRes) == "running" then
        return exports.core:getDatabase()
    end
    return nil
end

addEvent("phone:requestBankData", true)
addEventHandler("phone:requestBankData", root, function()
    local charId = getElementData(client, "char:id")
    if not charId then return end
    
    local db = getDB()
    if not db then return end
    
    dbQuery(function(qh, cp)
        local result = dbPoll(qh, 0)
        if result and #result > 0 then
            local balance = result[1].bank or 0
            local name = (result[1].name or "Jogador") .. " " .. (result[1].lastname or "")
            triggerClientEvent(cp, "phone:receiveBankData", cp, name, balance)
        end
    end, {client}, db, "SELECT name, lastname, bank FROM characters WHERE id = ?", charId)
end)

addEvent("phone:processPix", true)
addEventHandler("phone:processPix", root, function(targetId, amount)
    local charId = getElementData(client, "char:id")
    if not charId then return end
    
    amount = tonumber(amount)
    targetId = tonumber(targetId)
    
    if not amount or amount <= 0 then
        triggerClientEvent(client, "core:addNotification", client, "Erro", "Valor inválido.", "error")
        return
    end
    
    if targetId == charId then
        triggerClientEvent(client, "core:addNotification", client, "Erro", "Você não pode transferir para si mesmo.", "error")
        return
    end
    
    local db = getDB()
    if not db then return end
    
    -- Check sender balance
    dbQuery(function(qh, cp, amt, tId, sId)
        local result = dbPoll(qh, 0)
        if result and #result > 0 then
            local balance = result[1].bank or 0
            if balance >= amt then
                -- Check if target exists
                dbQuery(function(targetQh, cl, sAmt, sTargetId, senderId, senderName)
                    local targetResult = dbPoll(targetQh, 0)
                    if targetResult and #targetResult > 0 then
                        -- Target exists, proceed with transfer
                        local tName = (targetResult[1].name or "Desconhecido") .. " " .. (targetResult[1].lastname or "")
                        
                        -- Update Sender
                        dbExec(db, "UPDATE characters SET bank = bank - ? WHERE id = ?", sAmt, senderId)
                        -- Update Target
                        dbExec(db, "UPDATE characters SET bank = bank + ? WHERE id = ?", sAmt, sTargetId)
                        
                        triggerClientEvent(cl, "phone:pushNotification", cl, "Pix Enviado", "Transferência de R$"..sAmt.." para "..tName.." realizada.", "bank")
                        
                        -- Refresh sender bank data
                        triggerEvent("phone:requestBankData", cl)
                        
                        -- If target is online, notify them and refresh
                        for _, player in ipairs(getElementsByType("player")) do
                            if getElementData(player, "char:id") == sTargetId then
                                triggerClientEvent(player, "phone:pushNotification", player, "Pix Recebido", "Você recebeu R$"..sAmt.." de "..senderName..".", "bank")
                                triggerClientEvent(player, "phone:receiveBankData", player, tName, (targetResult[1].bank or 0) + sAmt) -- update if they have phone open
                                break
                            end
                        end
                    else
                        triggerClientEvent(cl, "phone:pushNotification", cl, "Pix Recusado", "Conta destino não encontrada.", "bank")
                    end
                end, {cp, amt, tId, sId, (result[1].name or "")}, db, "SELECT name, lastname, bank FROM characters WHERE id = ?", tId)
            else
                triggerClientEvent(cp, "phone:pushNotification", cp, "Pix Recusado", "Saldo insuficiente.", "bank")
            end
        else
            triggerClientEvent(cp, "phone:pushNotification", cp, "Erro", "Erro ao acessar sua conta.", "bank")
        end
    end, {client, amount, targetId, charId}, db, "SELECT name, bank FROM characters WHERE id = ?", charId)
end)

local phoneObjects = {}
local animTimers = {}

addEvent("phone:syncAnimation", true)
addEventHandler("phone:syncAnimation", root, function(isOpen)
    if isOpen then
        setPedAnimation(client, "ped", "phone_in", 1000, false, false, false, true)
        if isElement(phoneObjects[client]) then
            destroyElement(phoneObjects[client])
        end
        local obj = createObject(330, 0, 0, 0)
        if obj then
            phoneObjects[client] = obj
            setObjectScale(obj, 1.4)
            -- Fine-tuned tilt to -42 to align perfectly with vertical
            exports.pAttach:attach(obj, client, "right-hand", 0, 0.01, 0.03, -15, 350, 15)
        end
        
        -- Freeze animation at 0.8 to hold the phone
        if isTimer(animTimers[client]) then killTimer(animTimers[client]) end
        animTimers[client] = setTimer(function(player)
            if isElement(player) then
                setPedAnimationProgress(player, 'phone_in', 0.8)
            end
        end, 500, 0, client)
        
    else
        if isTimer(animTimers[client]) then
            killTimer(animTimers[client])
            animTimers[client] = nil
        end
        
        setPedAnimation(client, "ped", "phone_out", 500, false, false, false, false)
        if isElement(phoneObjects[client]) then
            destroyElement(phoneObjects[client])
            phoneObjects[client] = nil
        end
        setTimer(function(p)
            if isElement(p) then
                setPedAnimation(p, nil, nil)
            end
        end, 500, 1, client)
    end
end)

addEventHandler("onPlayerQuit", root, function()
    if isElement(phoneObjects[source]) then
        destroyElement(phoneObjects[source])
        phoneObjects[source] = nil
    end
    if isTimer(animTimers[source]) then
        killTimer(animTimers[source])
        animTimers[source] = nil
    end
end)

-- Test Command for Phone Notifications (Only for ID 1 or for testing)
addCommandHandler("testpix", function(player, cmd, amount)
    local val = amount or "500.00"
    triggerClientEvent(player, "phone:pushNotification", player, "Transferência Recebida", "Você recebeu um Pix de $" .. val .. " do Sistema.", "bank")
end)

local dbConnection = nil

-- Inicializa a conexão com o banco de dados quando o script ligar
addEventHandler("onResourceStart", resourceRoot, function()
    if ConfigDB.type == "mysql" then
        dbConnection = dbConnect("mysql", "dbname="..ConfigDB.mysql.db..";host="..ConfigDB.mysql.host..";port="..ConfigDB.mysql.port, ConfigDB.mysql.user, ConfigDB.mysql.pass)
        if dbConnection then
            outputServerLog("[PHONE] Conectado ao banco de dados MySQL com sucesso!")
        else
            outputServerLog("[PHONE] ERRO: Falha ao conectar ao MySQL. Verifique as credenciais no server_config.lua.")
        end
    elseif ConfigDB.type == "sqlite" then
        dbConnection = dbConnect("sqlite", ConfigDB.sqlite.path)
        if dbConnection then
            outputServerLog("[PHONE] Conectado ao banco de dados SQLite com sucesso!")
            
            -- Auto-instalação: Cria a tabela characters se não existir para o celular funcionar "out of the box"
            local q = string.format("CREATE TABLE IF NOT EXISTS %s (%s INTEGER PRIMARY KEY, %s TEXT, %s TEXT, %s INTEGER DEFAULT 0)", 
                ConfigDB.integration.tableName, ConfigDB.integration.idColumn, ConfigDB.integration.nameColumn, ConfigDB.integration.lastnameColumn, ConfigDB.integration.bankColumn)
            dbExec(dbConnection, q)
        else
            outputServerLog("[PHONE] ERRO: Falha ao criar/conectar ao SQLite.")
        end
    end
end)

-- Evento chamado pelo celular para pegar as informações do banco do jogador
addEvent("phone:requestBankData", true)
addEventHandler("phone:requestBankData", root, function()
    -- Pega o ID do personagem que está no jogador (salvo no element data configurado)
    local charId = getElementData(client, ConfigDB.integration.elementDataID)
    if not charId then return end
    
    if not dbConnection then return end
    
    -- Faz uma consulta no banco de dados buscando nome, sobrenome e saldo (bank)
    local q = string.format("SELECT %s, %s, %s FROM %s WHERE %s = ?", 
        ConfigDB.integration.nameColumn, ConfigDB.integration.lastnameColumn, ConfigDB.integration.bankColumn, ConfigDB.integration.tableName, ConfigDB.integration.idColumn)
        
    dbQuery(function(qh, cp)
        local result = dbPoll(qh, 0)
        if result and #result > 0 then
            -- Se encontrou os dados, pega o saldo e monta o nome completo
            local balance = result[1][ConfigDB.integration.bankColumn] or 0
            local name = (result[1][ConfigDB.integration.nameColumn] or "Jogador") .. " " .. (result[1][ConfigDB.integration.lastnameColumn] or "")
            -- Envia de volta pro cliente que pediu os dados
            triggerClientEvent(cp, "phone:receiveBankData", cp, name, balance)
        end
    end, {client}, dbConnection, q, charId)
end)

-- Evento chamado pelo celular quando o jogador tenta enviar um Pix
addEvent("phone:processPix", true)
addEventHandler("phone:processPix", root, function(targetId, amount)
    -- Verifica quem está enviando
    local charId = getElementData(client, ConfigDB.integration.elementDataID)
    if not charId then return end
    
    amount = tonumber(amount)
    targetId = tonumber(targetId)
    
    -- Verifica se o valor é válido (maior que 0)
    if not amount or amount <= 0 then
        triggerClientEvent(client, "core:addNotification", client, "Erro", "Valor inválido.", "error")
        return
    end
    
    -- Impede de mandar pix pra si mesmo
    if targetId == charId then
        triggerClientEvent(client, "core:addNotification", client, "Erro", "Você não pode transferir para si mesmo.", "error")
        return
    end
    
    if not dbConnection then return end
    
    -- Check sender balance (Verifica o saldo de quem está enviando)
    local querySender = string.format("SELECT %s, %s FROM %s WHERE %s = ?", ConfigDB.integration.nameColumn, ConfigDB.integration.bankColumn, ConfigDB.integration.tableName, ConfigDB.integration.idColumn)
    local queryTarget = string.format("SELECT %s, %s, %s FROM %s WHERE %s = ?", ConfigDB.integration.nameColumn, ConfigDB.integration.lastnameColumn, ConfigDB.integration.bankColumn, ConfigDB.integration.tableName, ConfigDB.integration.idColumn)
    local updateQ = string.format("UPDATE %s SET %s = %s + ? WHERE %s = ?", ConfigDB.integration.tableName, ConfigDB.integration.bankColumn, ConfigDB.integration.bankColumn, ConfigDB.integration.idColumn)
    local updateSubQ = string.format("UPDATE %s SET %s = %s - ? WHERE %s = ?", ConfigDB.integration.tableName, ConfigDB.integration.bankColumn, ConfigDB.integration.bankColumn, ConfigDB.integration.idColumn)

    dbQuery(function(qh, cp, amt, tId, sId)
        local result = dbPoll(qh, 0)
        if result and #result > 0 then
            local balance = result[1][ConfigDB.integration.bankColumn] or 0
            -- Se o saldo for maior ou igual ao valor que quer enviar
            if balance >= amt then
                -- Check if target exists (Busca a conta de quem vai receber)
                dbQuery(function(targetQh, cl, sAmt, sTargetId, senderId, senderName)
                    local targetResult = dbPoll(targetQh, 0)
                    if targetResult and #targetResult > 0 then
                        -- Target exists, proceed with transfer (A conta existe, faz a transferência)
                        local tName = (targetResult[1][ConfigDB.integration.nameColumn] or "Desconhecido") .. " " .. (targetResult[1][ConfigDB.integration.lastnameColumn] or "")
                        
                        -- Update Sender (Tira o dinheiro de quem enviou)
                        dbExec(dbConnection, updateSubQ, sAmt, senderId)
                        -- Update Target (Coloca o dinheiro pra quem recebeu)
                        dbExec(dbConnection, updateQ, sAmt, sTargetId)
                        
                        -- Manda notificação no celular de quem enviou
                        triggerClientEvent(cl, "phone:pushNotification", cl, "Pix Enviado", "Transferência de R$"..sAmt.." para "..tName.." realizada.", "bank")
                        
                        -- Refresh sender bank data (Atualiza a tela do banco de quem enviou)
                        triggerEvent("phone:requestBankData", cl)
                        
                        -- If target is online, notify them and refresh (Se quem recebeu estiver online, manda notificação e atualiza também)
                        for _, player in ipairs(getElementsByType("player")) do
                            if getElementData(player, ConfigDB.integration.elementDataID) == sTargetId then
                                triggerClientEvent(player, "phone:pushNotification", player, "Pix Recebido", "Você recebeu R$"..sAmt.." de "..senderName..".", "bank")
                                triggerClientEvent(player, "phone:receiveBankData", player, tName, (targetResult[1][ConfigDB.integration.bankColumn] or 0) + sAmt) -- update if they have phone open
                                break
                            end
                        end
                    else
                        -- Se o ID de destino não existir
                        triggerClientEvent(cl, "phone:pushNotification", cl, "Pix Recusado", "Conta destino não encontrada.", "bank")
                    end
                end, {cp, amt, tId, sId, (result[1][ConfigDB.integration.nameColumn] or "")}, dbConnection, queryTarget, tId)
            else
                -- Se não tiver dinheiro suficiente
                triggerClientEvent(cp, "phone:pushNotification", cp, "Pix Recusado", "Saldo insuficiente.", "bank")
            end
        else
            -- Erro de banco de dados
            triggerClientEvent(cp, "phone:pushNotification", cp, "Erro", "Erro ao acessar sua conta.", "bank")
        end
    end, {client, amount, targetId, charId}, dbConnection, querySender, charId)
end)

local phoneObjects = {} -- Tabela que guarda o objeto 3D do celular de cada jogador
local animTimers = {} -- Tabela que guarda o timer da animação de cada jogador

-- Evento pra sincronizar a animação do personagem segurando o celular pra todos no servidor
addEvent("phone:syncAnimation", true)
addEventHandler("phone:syncAnimation", root, function(isOpen)
    if isOpen then
        -- Coloca a animação do personagem olhando pro celular
        setPedAnimation(client, "ped", "phone_in", 1000, false, false, false, true)
        
        -- Se ele já tiver um celular na mão, destrói antes de criar outro
        if isElement(phoneObjects[client]) then
            destroyElement(phoneObjects[client])
        end
        -- Cria o objeto do celular (ID 330)
        local obj = createObject(330, 0, 0, 0)
        if obj then
            phoneObjects[client] = obj
            setObjectScale(obj, 1.4) -- Aumenta um pouco o tamanho
            -- Fine-tuned tilt to -42 to align perfectly with vertical (Gruda o celular na mão do jogador)
            exports.pAttach:attach(obj, client, "right-hand", 0, 0.01, 0.03, -15, 350, 15)
        end
        
        -- Freeze animation at 0.8 to hold the phone (Pausa a animação no frame certo pra ele ficar segurando)
        if isTimer(animTimers[client]) then killTimer(animTimers[client]) end
        animTimers[client] = setTimer(function(player)
            if isElement(player) then
                setPedAnimationProgress(player, 'phone_in', 0.8)
            end
        end, 500, 0, client)
        
    else
        -- Se for pra guardar o celular
        if isTimer(animTimers[client]) then
            killTimer(animTimers[client])
            animTimers[client] = nil
        end
        
        -- Toca a animação de guardar
        setPedAnimation(client, "ped", "phone_out", 500, false, false, false, false)
        
        -- Destrói o objeto da mão dele
        if isElement(phoneObjects[client]) then
            destroyElement(phoneObjects[client])
            phoneObjects[client] = nil
        end
        
        -- Cancela a animação depois de meio segundo pra ele voltar ao normal
        setTimer(function(p)
            if isElement(p) then
                setPedAnimation(p, nil, nil)
            end
        end, 500, 1, client)
    end
end)

-- Quando o jogador sair do servidor, limpa o celular e as animações dele pra não bugar
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

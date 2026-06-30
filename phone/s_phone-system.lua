local dbConnection = nil

-- Sistema Anti-Lag Switch / Anti-Dupping
local actionCooldowns = {}

local function isSpamming(player, actionType, cooldownMs)
    if not actionCooldowns[player] then actionCooldowns[player] = {} end
    local lastTime = actionCooldowns[player][actionType] or 0
    if getTickCount() - lastTime < cooldownMs then
        return true
    end
    actionCooldowns[player][actionType] = getTickCount()
    return false
end

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
        else
            outputServerLog("[PHONE] ERRO: Falha ao criar/conectar ao SQLite.")
        end
    elseif ConfigDB.type == "core" then
        dbConnection = exports.core:getDatabase()
        if dbConnection then
            outputServerLog("[PHONE] Conectado ao banco de dados via CORE export com sucesso!")
        else
            outputServerLog("[PHONE] ERRO: Falha ao obter a conexão do banco pelo exports.core:getDatabase().")
        end
    end

    -- Criação de tabelas necessárias (Funciona para SQLite e MySQL)
    if dbConnection then
        -- Auto-instalação da tabela characters (caso use sqlite puro)
        if ConfigDB.type == "sqlite" then
            local q = string.format("CREATE TABLE IF NOT EXISTS %s (%s INTEGER PRIMARY KEY, %s TEXT, %s TEXT, %s INTEGER DEFAULT 0)", 
                ConfigDB.integration.tableName, ConfigDB.integration.idColumn, ConfigDB.integration.nameColumn, ConfigDB.integration.lastnameColumn, ConfigDB.integration.bankColumn)
            dbExec(dbConnection, q)
        end
        
        -- Criação da tabela de Contas Bancárias do Celular
        local b = ConfigDB.bank
        local qBank = string.format([[
            CREATE TABLE IF NOT EXISTS %s (
                %s VARCHAR(20) PRIMARY KEY,
                %s VARCHAR(10) DEFAULT '0001',
                %s INTEGER NOT NULL,
                %s VARCHAR(20) NOT NULL,
                %s INTEGER DEFAULT 0,
                %s VARCHAR(50)
            )
        ]], b.tableName, b.accountColumn, b.agencyColumn, b.charIdColumn, b.passwordColumn, b.balanceColumn, b.pixKeyColumn)
        dbExec(dbConnection, qBank)
        
        -- Criação da tabela de Histórico de Transações
        local autoInc = "AUTOINCREMENT"
        if ConfigDB.type == "mysql" or ConfigDB.type == "core" then
            autoInc = "AUTO_INCREMENT"
        end
        
        local qHist = string.format([[
            CREATE TABLE IF NOT EXISTS %s (
                id INTEGER PRIMARY KEY %s,
                sender VARCHAR(20) NOT NULL,
                receiver VARCHAR(20) NOT NULL,
                amount INTEGER NOT NULL,
                sender_name VARCHAR(50),
                receiver_name VARCHAR(50),
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
            )
        ]], b.historyTableName or "phone_bank_transactions", autoInc)
        dbExec(dbConnection, qHist)
    end
end)

local loggedInBankAccounts = {} -- Guarda a sessão de quem está logado no banco (player -> account_id)

-- Função auxiliar para gerar número de conta aleatório único
local function generateAccountNumber()
    return tostring(math.random(10000, 99999)) .. "-" .. tostring(math.random(1, 9))
end

-- Evento para verificar status da conta ao abrir o app
addEvent("phone:checkBankStatus", true)
addEventHandler("phone:checkBankStatus", root, function()
    local cp = client
    if not cp then return end
    
    -- Verifica se já está logado na memória do servidor
    if loggedInBankAccounts[cp] then
        triggerClientEvent(cp, "phone:onBankStatusChecked", cp, "logged_in", loggedInBankAccounts[cp])
        return
    end
    
    local charId = getElementData(cp, ConfigDB.integration.elementDataID)
    if not charId then return end
    if not dbConnection then return end
    
    local b = ConfigDB.bank
    local q = string.format("SELECT %s FROM %s WHERE %s = ?", b.accountColumn, b.tableName, b.charIdColumn)
    
    dbQuery(function(qh, player)
        local result = dbPoll(qh, 0)
        if result and #result > 0 then
            -- Possui conta no banco de dados, retorna o número da conta para auto-preencher
            triggerClientEvent(player, "phone:onBankStatusChecked", player, "has_account", result[1][b.accountColumn])
        else
            -- Não possui nenhuma conta cadastrada
            triggerClientEvent(player, "phone:onBankStatusChecked", player, "no_account")
        end
    end, {cp}, dbConnection, q, charId)
end)

-- Evento para Criar Conta
addEvent("phone:createAccount", true)
addEventHandler("phone:createAccount", root, function(password)
    local charId = getElementData(client, ConfigDB.integration.elementDataID)
    if not charId then return end
    if not dbConnection then return end
    
    local b = ConfigDB.bank
    local maxContas = b.maxAccountsPerPlayer or 1
    
    -- Verifica contas existentes do personagem
    local checkQ = string.format("SELECT * FROM %s WHERE %s = ?", b.tableName, b.charIdColumn)
    dbQuery(function(qh, cp, cId, pwd)
        local result = dbPoll(qh, 0)
        if result and #result >= maxContas then
            triggerClientEvent(cp, "core:addNotification", cp, "Erro", "Você já atingiu o limite de contas bancárias ("..maxContas..").", "error")
        else
            local newAccount = generateAccountNumber()
            local insertQ = string.format("INSERT INTO %s (%s, %s, %s, %s, %s) VALUES (?, '0001', ?, ?, 0)", 
                b.tableName, b.accountColumn, b.agencyColumn, b.charIdColumn, b.passwordColumn, b.balanceColumn)
            dbExec(dbConnection, insertQ, newAccount, cId, pwd)
            triggerClientEvent(cp, "core:addNotification", cp, "Sucesso", "Conta criada: " .. newAccount, "success")
            triggerClientEvent(cp, "phone:onAccountCreated", cp, newAccount)
        end
    end, {client, charId, password}, dbConnection, checkQ, charId)
end)

-- Evento para Login na Conta
addEvent("phone:loginAccount", true)
addEventHandler("phone:loginAccount", root, function(account, password)
    if not dbConnection then return end
    local b = ConfigDB.bank
    local q = string.format("SELECT * FROM %s WHERE %s = ? AND %s = ?", b.tableName, b.accountColumn, b.passwordColumn)
    
    dbQuery(function(qh, cp, acc)
        local result = dbPoll(qh, 0)
        if result and #result > 0 then
            -- Verifica se a conta pertence a este personagem
            local charId = getElementData(cp, ConfigDB.integration.elementDataID)
            if tostring(result[1][b.charIdColumn]) == tostring(charId) then
                loggedInBankAccounts[cp] = acc
                triggerClientEvent(cp, "phone:onLoginSuccess", cp, acc)
                triggerEvent("phone:requestBankData", cp) -- Puxa os dados para atualizar a tela
            else
                triggerClientEvent(cp, "core:addNotification", cp, "Erro", "Esta conta não pertence a você.", "error")
            end
        else
            triggerClientEvent(cp, "core:addNotification", cp, "Erro", "Conta ou senha inválidos.", "error")
        end
    end, {client, account}, dbConnection, q, account, password)
end)

-- Pega as informações do banco do jogador (Logado)
addEvent("phone:requestBankData", true)
addEventHandler("phone:requestBankData", root, function()
    -- Quando acionado pelo client, usa 'client', quando pelo server (após login), usa 'source'
    local player = client or source
    
    local accId = loggedInBankAccounts[player]
    if not accId or not dbConnection then return end
    
    local b = ConfigDB.bank
    local i = ConfigDB.integration
    
    local q = string.format([[
        SELECT b.%s, b.%s, c.*
        FROM %s b
        LEFT JOIN %s c ON b.%s = c.%s
        WHERE b.%s = ?
    ]], b.balanceColumn, b.pixKeyColumn, b.tableName, i.tableName, b.charIdColumn, i.idColumn, b.accountColumn)
        
    dbQuery(function(qh, cp)
        local result = dbPoll(qh, 0)
        
        if result and #result > 0 then
            local balance = result[1][b.balanceColumn] or 0
            local pixKey = result[1][b.pixKeyColumn] or ""
            
            local fName = result[1][i.nameColumn]
            local lName = result[1][i.lastnameColumn]
            
            local name = "Jogador"
            if fName and lName then
                name = tostring(fName) .. " " .. tostring(lName)
            elseif fName then
                name = tostring(fName)
            end
            
            name = string.gsub(name, "'", "\\'")
            
            -- Busca o histórico
            local histQ = string.format("SELECT * FROM %s WHERE sender = ? OR receiver = ? ORDER BY timestamp DESC LIMIT 50", b.historyTableName or "phone_bank_transactions")
            dbQuery(function(histQh, clientPlayer, pName, pBal, pAccId, pPixKey)
                local histRes = dbPoll(histQh, 0)
                local history = {}
                if histRes and #histRes > 0 then
                    history = histRes
                end
                
                triggerClientEvent(clientPlayer, "phone:receiveBankData", clientPlayer, pName, pBal, pAccId, history, pPixKey)
            end, {cp, name, balance, loggedInBankAccounts[cp], pixKey}, dbConnection, histQ, accId, accId)
        end
    end, {player}, dbConnection, q, accId)
end)

-- Primeira Etapa: Verifica se tem saldo e se a conta existe, e retorna o nome
addEvent("phone:verifyPixTarget", true)
addEventHandler("phone:verifyPixTarget", root, function(targetAccount, amount)
    if isSpamming(client, "verifyPix", 2000) then
        triggerClientEvent(client, "phone:pushNotification", client, "Aguarde", "Você está fazendo buscas muito rápido.", "error")
        triggerClientEvent(client, "phone:hideBankLoading", client)
        return
    end

    local senderAccount = loggedInBankAccounts[client]
    if not senderAccount or not dbConnection then 
        triggerClientEvent(client, "phone:hideBankLoading", client)
        return 
    end
    
    amount = tonumber(amount)
    if not amount or amount <= 0 or amount == math.huge or amount ~= amount then
        triggerClientEvent(client, "phone:pushNotification", client, "Erro", "Valor inválido.", "error")
        triggerClientEvent(client, "phone:hideBankLoading", client)
        return
    end
    amount = math.floor(amount * 100) / 100 -- Evita float bug (garante no máximo 2 casas decimais)
    
    if targetAccount == senderAccount then
        triggerClientEvent(client, "phone:pushNotification", client, "Erro", "Você não pode transferir para si mesmo.", "error")
        triggerClientEvent(client, "phone:hideBankLoading", client)
        return
    end
    
    local b = ConfigDB.bank
    local i = ConfigDB.integration
    
    local querySender = string.format("SELECT %s FROM %s WHERE %s = ?", b.balanceColumn, b.tableName, b.accountColumn)
    
    dbQuery(function(qh, cp, amt, tAcc, sAcc)
        local result = dbPoll(qh, 0)
        if result and #result > 0 then
            local balance = result[1][b.balanceColumn] or 0
            if balance >= amt then
                local queryTarget = string.format([[
                    SELECT b.%s AS real_account, c.*
                    FROM %s b 
                    LEFT JOIN %s c ON b.%s = c.%s
                    WHERE b.%s = ? OR b.%s = ?
                ]], b.accountColumn, b.tableName, i.tableName, b.charIdColumn, i.idColumn, b.accountColumn, b.pixKeyColumn)
                
                dbQuery(function(targetQh, cl, sAmt, originalInput, senderAcc)
                    local targetResult = dbPoll(targetQh, 0)
                    if targetResult and #targetResult > 0 then
                        local realAcc = targetResult[1].real_account
                        
                        if tostring(realAcc) == tostring(senderAcc) then
                            triggerClientEvent(cl, "phone:pushNotification", cl, "Erro", "Você não pode transferir para si mesmo.", "error")
                            triggerClientEvent(cl, "phone:hideBankLoading", cl)
                            return
                        end
                        
                        local fName = targetResult[1][i.nameColumn]
                        local lName = targetResult[1][i.lastnameColumn]
                        local tName = "Jogador"
                        if fName and lName then
                            tName = tostring(fName) .. " " .. tostring(lName)
                        elseif fName then
                            tName = tostring(fName)
                        end
                        
                        triggerClientEvent(cl, "phone:onPixTargetVerified", cl, sAmt, tName, realAcc)
                    else
                        triggerClientEvent(cl, "phone:pushNotification", cl, "Pix Recusado", "Chave ou Conta destino não encontrada.", "bank")
                        triggerClientEvent(cl, "phone:hideBankLoading", cl)
                    end
                end, {cp, amt, tAcc, sAcc}, dbConnection, queryTarget, tAcc, tAcc)
            else
                triggerClientEvent(cp, "phone:pushNotification", cp, "Pix Recusado", "Saldo insuficiente.", "bank")
                triggerClientEvent(cp, "phone:hideBankLoading", cp)
            end
        else
            triggerClientEvent(cp, "phone:hideBankLoading", cp)
        end
    end, {client, amount, targetAccount, senderAccount}, dbConnection, querySender, senderAccount)
end)

-- Segunda Etapa: Processa PIX/Transferência (Valida senha)
addEvent("phone:processPix", true)
addEventHandler("phone:processPix", root, function(targetAccount, amount, password)
    if isSpamming(client, "processPix", 5000) then
        triggerClientEvent(client, "phone:pushNotification", client, "Erro de Segurança", "Aguarde a transação anterior terminar.", "error")
        triggerClientEvent(client, "phone:hideBankLoading", client)
        return
    end

    local senderAccount = loggedInBankAccounts[client]
    if not senderAccount or not dbConnection then 
        triggerClientEvent(client, "phone:hideBankLoading", client)
        return 
    end
    
    amount = tonumber(amount)
    if not amount or amount <= 0 or amount == math.huge or amount ~= amount then
        triggerClientEvent(client, "phone:pushNotification", client, "Erro", "Valor de transferência inválido.", "error")
        triggerClientEvent(client, "phone:hideBankLoading", client)
        return
    end
    amount = math.floor(amount * 100) / 100 -- Evita float bug (garante no máximo 2 casas decimais)
    
    local b = ConfigDB.bank
    local i = ConfigDB.integration
    
    local querySender = string.format([[
        SELECT b.%s, b.%s, c.*
        FROM %s b
        LEFT JOIN %s c ON b.%s = c.%s
        WHERE b.%s = ?
    ]], b.balanceColumn, b.passwordColumn, b.tableName, i.tableName, b.charIdColumn, i.idColumn, b.accountColumn)
    
    dbQuery(function(qh, cp, amt, tAcc, sAcc, pwd)
        local result = dbPoll(qh, 0)
        if result and #result > 0 then
            local dbPwd = result[1][b.passwordColumn]
            
            -- Pega nome de quem envia
            local sfName = result[1][i.nameColumn]
            local slName = result[1][i.lastnameColumn]
            local sName = "Jogador"
            if sfName and slName then sName = tostring(sfName) .. " " .. tostring(slName)
            elseif sfName then sName = tostring(sfName) end
            if tostring(dbPwd) ~= tostring(pwd) then
                triggerClientEvent(cp, "phone:pushNotification", cp, "Erro", "Senha incorreta.", "error")
                triggerClientEvent(cp, "phone:hideBankLoading", cp)
                return
            end
            
            local balance = result[1][b.balanceColumn] or 0
            if balance >= tonumber(amt) then
                local queryTarget = string.format([[
                    SELECT b.%s, b.%s as real_account, c.*
                    FROM %s b 
                    LEFT JOIN %s c ON b.%s = c.%s
                    WHERE b.%s = ? OR b.%s = ?
                ]], b.charIdColumn, b.accountColumn, b.tableName, i.tableName, b.charIdColumn, i.idColumn, b.accountColumn, b.pixKeyColumn)
                
                dbQuery(function(targetQh, cl, sAmt, originalInput, senderAcc)
                    local targetResult = dbPoll(targetQh, 0)
                    if targetResult and #targetResult > 0 then
                        local fName = targetResult[1][i.nameColumn]
                        local lName = targetResult[1][i.lastnameColumn]
                        local tName = "Jogador"
                        if fName and lName then
                            tName = tostring(fName) .. " " .. tostring(lName)
                        elseif fName then
                            tName = tostring(fName)
                        end
                        
                        local targetCharId = targetResult[1][b.charIdColumn]
                        local realTargetAcc = targetResult[1].real_account
                        
                        if tostring(realTargetAcc) == tostring(senderAcc) then
                            triggerClientEvent(cl, "phone:pushNotification", cl, "Erro", "Você não pode transferir para si mesmo.", "error")
                            triggerClientEvent(cl, "phone:hideBankLoading", cl)
                            return
                        end
                        
                        local updateSubQ = string.format("UPDATE %s SET %s = %s - ? WHERE %s = ?", b.tableName, b.balanceColumn, b.balanceColumn, b.accountColumn)
                        local updateAddQ = string.format("UPDATE %s SET %s = %s + ? WHERE %s = ?", b.tableName, b.balanceColumn, b.balanceColumn, b.accountColumn)
                        dbExec(dbConnection, updateSubQ, sAmt, senderAcc)
                        dbExec(dbConnection, updateAddQ, sAmt, realTargetAcc)
                        
                        -- Salva no extrato
                        local insertHist = string.format("INSERT INTO %s (sender, receiver, amount, sender_name, receiver_name) VALUES (?, ?, ?, ?, ?)", b.historyTableName or "phone_bank_transactions")
                        dbExec(dbConnection, insertHist, senderAcc, realTargetAcc, sAmt, sName, tName)
                        
                        triggerClientEvent(cl, "phone:onPixSuccess", cl)
                        triggerClientEvent(cl, "phone:pushNotification", cl, "Pix Enviado", "Transferência de $"..sAmt.." para "..tName.." realizada.", "bank")
                        triggerEvent("phone:requestBankData", cl)
                        
                        -- Notifica o recebedor
                        for _, player in ipairs(getElementsByType("player")) do
                            if tostring(getElementData(player, ConfigDB.integration.elementDataID)) == tostring(targetCharId) then
                                triggerClientEvent(player, "phone:pushNotification", player, "Pix Recebido", "Você recebeu $"..sAmt..".", "bank")
                                if loggedInBankAccounts[player] == realTargetAcc then
                                    triggerEvent("phone:requestBankData", player)
                                end
                                break
                            end
                        end
                    else
                        triggerClientEvent(cl, "phone:pushNotification", cl, "Erro", "A conta destino não existe mais.", "error")
                        triggerClientEvent(cl, "phone:hideBankLoading", cl)
                    end
                end, {cp, amt, tAcc, sAcc}, dbConnection, queryTarget, tAcc, tAcc)
            else
                triggerClientEvent(cp, "phone:pushNotification", cp, "Pix Recusado", "Saldo insuficiente.", "bank")
                triggerClientEvent(cp, "phone:hideBankLoading", cp)
            end
        else
            triggerClientEvent(cp, "phone:hideBankLoading", cp)
        end
    end, {client, amount, targetAccount, senderAccount, password}, dbConnection, querySender, senderAccount)
end)

-- Função auxiliar para gerar chave aleatória no formato XXXX-XXXX-XXXX
local function generateRandomPixKey()
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local function randomChar()
        local r = math.random(1, #chars)
        return chars:sub(r, r)
    end
    
    local key = ""
    for i = 1, 14 do
        if i == 5 or i == 10 then
            key = key .. "-"
        else
            key = key .. randomChar()
        end
    end
    return key
end

-- Terceira Etapa: Gera uma nova chave PIX aleatória
addEvent("phone:generatePixKey", true)
addEventHandler("phone:generatePixKey", root, function(password)
    if isSpamming(client, "generatePix", 4000) then
        triggerClientEvent(client, "phone:pushNotification", client, "Aguarde", "Processando a criação da sua chave...", "bank")
        return
    end

    local cp = client
    local accountId = loggedInBankAccounts[cp]
    if not accountId or not dbConnection then 
        triggerClientEvent(cp, "phone:hideBankLoading", cp)
        return 
    end
    
    local b = ConfigDB.bank
    local q = string.format("SELECT %s FROM %s WHERE %s = ?", b.passwordColumn, b.tableName, b.accountColumn)
    
    dbQuery(function(qh, player, accId, pwd)
        local result = dbPoll(qh, 0)
        if result and #result > 0 then
            local dbPwd = result[1][b.passwordColumn]
            if tostring(dbPwd) ~= tostring(pwd) then
                triggerClientEvent(player, "phone:pushNotification", player, "Erro", "Senha incorreta.", "error")
                triggerClientEvent(player, "phone:hideBankLoading", player)
                return
            end
            
            -- Senha correta
            local newKey = generateRandomPixKey()
            local updateQ = string.format("UPDATE %s SET %s = ? WHERE %s = ?", b.tableName, b.pixKeyColumn, b.accountColumn)
            dbExec(dbConnection, updateQ, newKey, accId)
            
            triggerClientEvent(player, "phone:pushNotification", player, "Chave PIX", "Nova chave gerada com sucesso!", "bank")
            triggerClientEvent(player, "phone:hideBankLoading", player)
            triggerClientEvent(player, "phone:closeKeyModal", player)
            triggerEvent("phone:requestBankData", player)
        else
            triggerClientEvent(player, "phone:hideBankLoading", player)
        end
    end, {cp, accountId, password}, dbConnection, q, accountId)
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

-- Comando útil para testes quando usando o modo SQLite standalone
addCommandHandler("setup_phone_test", function(player, cmd, amount)
    -- Apenas para admins ou testes locais
    local charId = getElementData(player, ConfigDB.integration.elementDataID)
    if not charId then
        outputChatBox("ERRO: Você precisa ter um ID de personagem setado.", player, 255, 0, 0)
        return
    end
    
    local balance = tonumber(amount) or 5000 -- Saldo inicial de teste
    local playerName = getPlayerName(player):gsub("_", " ")
    local nameParts = split(playerName, " ")
    local firstName = nameParts[1] or "Test"
    local lastName = nameParts[2] or "User"
    
    -- Deleta o registro antigo se existir e cria um novo com saldo
    local deleteQ = string.format("DELETE FROM %s WHERE %s = ?", ConfigDB.integration.tableName, ConfigDB.integration.idColumn)
    dbExec(dbConnection, deleteQ, charId)
    
    local insertQ = string.format("INSERT INTO %s (%s, %s, %s, %s) VALUES (?, ?, ?, ?)", 
        ConfigDB.integration.tableName, ConfigDB.integration.idColumn, ConfigDB.integration.nameColumn, ConfigDB.integration.lastnameColumn, ConfigDB.integration.bankColumn)
    
    local success = dbExec(dbConnection, insertQ, charId, firstName, lastName, balance)
    
    if success then
        outputChatBox("✅ [PHONE] Conta de teste configurada no banco de dados isolado!", player, 0, 255, 0)
        outputChatBox("ID: " .. charId .. " | Nome: " .. firstName .. " " .. lastName .. " | Saldo: R$" .. balance, player, 0, 200, 0)
        triggerEvent("phone:requestBankData", player) -- Atualiza a tela se o celular estiver aberto
    else
        outputChatBox("❌ [PHONE] Erro ao criar conta de teste.", player, 255, 0, 0)
    end
end)

--======================================
-- COMANDOS DE ADMINISTRAÇÃO (TESTE)
--======================================

-- Comando para adicionar saldo na própria conta (Apenas ID 1)
addCommandHandler("deposito", function(player, cmd, amount)
    local charId = getElementData(player, ConfigDB.integration.elementDataID)
    if tostring(charId) ~= "1" then
        outputChatBox("Apenas o personagem ID 1 pode usar este comando.", player, 255, 0, 0)
        return
    end
    
    amount = tonumber(amount)
    if not amount or amount <= 0 then
        outputChatBox("Uso: /deposito <valor>", player, 255, 255, 0)
        return
    end
    
    local accId = loggedInBankAccounts[player]
    if not accId then
        outputChatBox("Você precisa estar logado no banco do celular para receber o depósito.", player, 255, 0, 0)
        return
    end
    
    local b = ConfigDB.bank
    local updateQ = string.format("UPDATE %s SET %s = %s + ? WHERE %s = ?", b.tableName, b.balanceColumn, b.balanceColumn, b.accountColumn)
    dbExec(dbConnection, updateQ, amount, accId)
    
    outputChatBox("Depositado $" .. amount .. " na sua conta bancária digital.", player, 0, 255, 0)
    triggerEvent("phone:requestBankData", player) -- Atualiza a tela
end)

-- Comando para criar conta fantasma para testes de PIX
addCommandHandler("contafantasma", function(player)
    local charId = getElementData(player, ConfigDB.integration.elementDataID)
    if tostring(charId) ~= "1" then
        outputChatBox("Apenas o personagem ID 1 pode usar este comando.", player, 255, 0, 0)
        return
    end
    
    local b = ConfigDB.bank
    local i = ConfigDB.integration
    
    -- Insere um personagem falso na tabela characters se não existir um com ID 999
    local checkChar = string.format("SELECT * FROM %s WHERE %s = ?", i.tableName, i.idColumn)
    local query1 = dbQuery(dbConnection, checkChar, 999)
    local resChar = dbPoll(query1, -1)
    if not resChar or #resChar == 0 then
        local insertChar = string.format("INSERT INTO %s (%s, %s, %s) VALUES (?, ?, ?)", i.tableName, i.idColumn, i.nameColumn, i.lastnameColumn)
        dbExec(dbConnection, insertChar, 999, "Conta", "Fantasma")
    end
    
    -- Não vamos mais verificar se já existe, vamos sempre criar uma nova!
    local function generateGhostAccount()
        local acc = ""
        for i = 1, 5 do acc = acc .. tostring(math.random(0, 9)) end
        acc = acc .. "-" .. tostring(math.random(0, 9))
        return acc
    end
    
    local ghostAcc = generateGhostAccount()
    local ghostPix = generateRandomPixKey()
    
    local insertBank = string.format("INSERT INTO %s (%s, %s, %s, %s, %s) VALUES (?, ?, ?, ?, ?)", b.tableName, b.accountColumn, b.passwordColumn, b.charIdColumn, b.balanceColumn, b.pixKeyColumn)
    dbExec(dbConnection, insertBank, ghostAcc, "0000", 999, 1000, ghostPix)
    
    outputChatBox("Nova conta fantasma criada! Conta: " .. ghostAcc .. " | PIX: " .. ghostPix, player, 0, 255, 0)
end)

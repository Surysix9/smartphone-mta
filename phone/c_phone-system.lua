
local sw, sh = guiGetScreenSize() -- Pega a resolução da tela do jogador (largura, altura)
local toggle = false -- Variável que define se o celular está aberto (true) ou fechado (false)
local w, h = 300, 570 -- Largura e altura da interface do celular em pixels
local intBrowser, browserContent, renderTimer = nil -- Variáveis para o navegador CEF e temporizador

-- Função responsável por carregar a página HTML local do celular
function loadBrowser() 
    loadBrowserURL(source, "http://mta/local/html/index.html")
end

-- Fecha modal da Chave Pix
addEvent("phone:closeKeyModal", true)
addEventHandler("phone:closeKeyModal", root, function()
    if isElement(browserContent) then
        executeBrowserJavascript(browserContent, "if(window.closeKeyModal) window.closeKeyModal();")
    end
end)

-- Função disparada quando a página termina de carregar
function whenBrowserReady()
    -- Pode ser usada para enviar informações iniciais ao JS
end

-- Função que atualiza o relógio do celular a cada segundo (1000ms)
function renderTime(bool)
    if bool then         
        renderTimer = setTimer(
            function () 
                -- Executa a função updateTime no JavaScript do HTML
                executeBrowserJavascript(browserContent, "updateTime();")
            end, 0, 1000
        )
    else
        -- Se estiver fechando, cancela o temporizador para não consumir processamento
        if isTimer(renderTimer) then
            killTimer(renderTimer)
            renderTimer = nil
        end
    end
end

local animTimer = nil

-- Função que faz a animação de subida e descida do celular na tela
function animateBrowserY(startY, endY, duration)
    if isTimer(animTimer) then killTimer(animTimer) end
    local startTime = getTickCount()
    animTimer = setTimer(function()
        local progress = (getTickCount() - startTime) / duration
        if progress >= 1 then
            progress = 1
            killTimer(animTimer)
            animTimer = nil
        end
        -- Usa interpolação (OutQuad) para um movimento suave
        local currentY = interpolateBetween(startY, 0, 0, endY, 0, 0, progress, "OutQuad")
        if isElement(intBrowser) then
            -- Define a nova posição na tela
            guiSetPosition(intBrowser, (sw - w), currentY, false)
        end
    end, 20, 0)
end

-- Função que abre (true) ou fecha (false) o celular
function toggleBrowser(bool)
    local x, currentY = guiGetPosition(intBrowser, false)
    if bool then 
        -- Anima subindo
        animateBrowserY(currentY, sh - h - 10, 400)
        guiSetInputMode("no_binds_when_editing") -- Permite digitar sem ativar binds do jogo
        playSound("sounds/openphone.mp3") -- Som de abrir
    else 
        -- Anima descendo (some da tela)
        animateBrowserY(currentY, sh + 50, 400)
        guiSetInputMode("allow_binds") -- Volta ao normal
        playSound("sounds/closephone.mp3") -- Som de fechar
    end
    renderTime(bool) -- Inicia ou para o relógio
end

-- Evento quando o recurso é iniciado (quando o script liga)
addEventHandler("onClientResourceStart", resourceRoot, function()
    -- Initialize the persistent browser off-screen (Cria o navegador fora da tela para ficar pronto)
    intBrowser = guiCreateBrowser((sw - w), sh + 50, w, h, true, true, false)
    browserContent = guiGetBrowser(intBrowser)
    addEventHandler("onClientBrowserCreated", intBrowser, loadBrowser)
    addEventHandler("onClientBrowserDocumentReady", intBrowser, whenBrowserReady)

    -- Carrega o modelo 3D do celular para o personagem segurar
    local txd = engineLoadTXD("model/phone.txd")
    if txd then engineImportTXD(txd, 330) end
    local dff = engineLoadDFF("model/phone.dff", 330)
    if dff then engineReplaceModel(dff, 330) end
end)

-- Tecla para abrir/fechar o celular (k)
bindKey(Config.OpenKey, "down", 
    function () 
        toggle = not toggle 
        showCursor(toggle) -- Mostra o mouse se abrir
        toggleBrowser(toggle)
        -- Avisa o servidor se o celular abriu/fechou para mostrar animação pros outros
        triggerServerEvent("phone:syncAnimation", localPlayer, toggle)
    end
)

-- Evento quando o script é desligado ou restartado
addEventHandler("onClientResourceStop", resourceRoot, 
    function () 
        if toggle then
            triggerServerEvent("phone:syncAnimation", localPlayer, false)
        end
        toggleBrowser(false)
        sw, sh, w, h, toggle = nil
        collectgarbage() -- Limpa a memória
    end
)

-- Eventos do Aplicativo do Banco (Bank App Events)

-- Quando o html/JS pedir os dados bancários
addEvent("phone:fetchBankData", true)
addEventHandler("phone:fetchBankData", root, function()
    -- Pede pro servidor pegar os dados no banco de dados
    triggerServerEvent("phone:requestBankData", localPlayer)
end)

-- Recebe os dados do banco que vieram do servidor
addEvent("phone:receiveBankData", true)
addEventHandler("phone:receiveBankData", root, function(playerName, balance, accountId, history, pixKey)
    if isElement(browserContent) then
        local histJson = "[]"
        if history and type(history) == "table" then
            histJson = toJSON(history)
            -- Remove os colchetes extras que o MTA coloca (o MTA coloca [ [ ] ] às vezes)
            if histJson:sub(1,1) == "[" then
                -- É válido, mas vamos escapar as aspas simples e barras
                histJson = string.gsub(histJson, "\\", "\\\\")
                histJson = string.gsub(histJson, "'", "\\'")
            end
        end
        executeBrowserJavascript(browserContent, string.format("updateBankData('%s', %s, '%s', '%s', '%s');", playerName, balance, accountId, histJson, pixKey or ""))
    end
end)

-- JS verifica status da conta ao abrir app
addEvent("phone:checkBankStatus", true)
addEventHandler("phone:checkBankStatus", root, function()
    triggerServerEvent("phone:checkBankStatus", localPlayer)
end)

-- Recebe o status da conta do servidor
addEvent("phone:onBankStatusChecked", true)
addEventHandler("phone:onBankStatusChecked", root, function(status, accountData)
    if isElement(browserContent) then
        executeBrowserJavascript(browserContent, string.format("window.handleBankStatus('%s', '%s');", status, accountData or ""))
    end
end)

-- JS envia login pro servidor
addEvent("phone:sendBankLogin", true)
addEventHandler("phone:sendBankLogin", root, function(account, password)
    triggerServerEvent("phone:loginAccount", localPlayer, account, password)
end)

-- JS envia registro pro servidor
addEvent("phone:sendBankRegister", true)
addEventHandler("phone:sendBankRegister", root, function(password)
    triggerServerEvent("phone:createAccount", localPlayer, password)
end)

-- Servidor avisa que logou com sucesso
addEvent("phone:onLoginSuccess", true)
addEventHandler("phone:onLoginSuccess", root, function(accountId)
    if isElement(browserContent) then
        executeBrowserJavascript(browserContent, "window.onBankLoginSuccess('" .. accountId .. "');")
    end
end)

-- Servidor avisa que criou a conta com sucesso
addEvent("phone:onAccountCreated", true)
addEventHandler("phone:onAccountCreated", root, function(newAccount)
    if isElement(browserContent) then
        executeBrowserJavascript(browserContent, "window.onBankRegisterSuccess('" .. newAccount .. "');")
    end
end)

-- Solicita verificação do alvo do PIX
addEvent("phone:verifyPixTarget", true)
addEventHandler("phone:verifyPixTarget", root, function(targetAccount, amount)
    triggerServerEvent("phone:verifyPixTarget", localPlayer, targetAccount, amount)
end)

-- Retorno da verificação do servidor
addEvent("phone:onPixTargetVerified", true)
addEventHandler("phone:onPixTargetVerified", root, function(amount, targetName, targetAccount)
    if isElement(browserContent) then
        executeBrowserJavascript(browserContent, string.format("window.onPixVerified('%s', '%s', '%s');", amount, targetName, targetAccount))
    end
end)

-- Processa PIX final com a senha
addEvent("phone:processPix", true)
addEventHandler("phone:processPix", root, function(targetAccount, amount, password)
    triggerServerEvent("phone:processPix", localPlayer, targetAccount, amount, password)
end)

-- Solicita a geração de uma nova chave PIX com senha
addEvent("phone:generatePixKey", true)
addEventHandler("phone:generatePixKey", root, function(password)
    triggerServerEvent("phone:generatePixKey", localPlayer, password)
end)

-- Sucesso no PIX
addEvent("phone:onPixSuccess", true)
addEventHandler("phone:onPixSuccess", root, function()
    if isElement(browserContent) then
        executeBrowserJavascript(browserContent, "window.onPixSuccess();")
    end
end)

-- Erro genérico para ocultar loading
addEvent("phone:hideBankLoading", true)
addEventHandler("phone:hideBankLoading", root, function()
    if isElement(browserContent) then
        executeBrowserJavascript(browserContent, "window.hideBankLoading();")
    end
end)

-- Recebe uma notificação do servidor para aparecer no celular
addEvent("phone:pushNotification", true)
addEventHandler("phone:pushNotification", root, function(title, message, iconType)
    if isElement(browserContent) then
        -- Escape single quotes to prevent JS errors (Previne erros se a mensagem tiver aspas)
        local safeTitle = string.gsub(title, "'", "\\'")
        local safeMessage = string.gsub(message, "'", "\\'")
        local safeIcon = string.gsub(iconType or "bank", "'", "\\'")
        
        -- Manda o JS mostrar a notificação
        executeBrowserJavascript(browserContent, string.format("showPhoneNotification('%s', '%s', '%s');", safeTitle, safeMessage, safeIcon))
        playSound("sounds/notification.mp3") -- Toca o som de notificação
        
        -- Se o celular estiver fechado, sobe ele um pouquinho pra mostrar a notificação
        if not toggle then
            local x, currentY = guiGetPosition(intBrowser, false)
            -- Slide up partially to show the notification (Sobe só uma parte)
            animateBrowserY(currentY, sh - 115, 400)
        end
    end
end)

-- Copia texto para a área de transferência do Windows/Celular
addEvent("phone:copyToClipboard", true)
addEventHandler("phone:copyToClipboard", root, function(textToCopy)
    if setClipboard(textToCopy) then
        -- Simula como se o servidor estivesse enviando a notificação
        triggerEvent("phone:pushNotification", localPlayer, "Copiado", "Chave copiada: " .. textToCopy, "bank")
    end
end)

-- Quando a notificação terminar de aparecer (esconde o celular se ele estiver fechado)
addEvent("phone:notificationsDone", true)
addEventHandler("phone:notificationsDone", root, function()
    if not toggle and isElement(intBrowser) then
        local _, currentY2 = guiGetPosition(intBrowser, false)
        animateBrowserY(currentY2, sh + 50, 400)
    end
end)
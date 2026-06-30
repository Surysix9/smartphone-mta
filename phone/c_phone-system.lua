
local sw, sh = guiGetScreenSize() -- Pega a resolução da tela do jogador (largura, altura)
local toggle = false -- Variável que define se o celular está aberto (true) ou fechado (false)
local w, h = 300, 570 -- Largura e altura da interface do celular em pixels
local intBrowser, browserContent, renderTimer = nil -- Variáveis para o navegador CEF e temporizador

-- Função responsável por carregar a página HTML local do celular
function loadBrowser() 
    loadBrowserURL(source, "http://mta/local/html/index.html")
end

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
addEventHandler("phone:receiveBankData", root, function(playerName, balance)
    if isElement(browserContent) then
        -- Envia pro JavaScript atualizar a tela do banco (nome e saldo)
        executeBrowserJavascript(browserContent, "updateBankData('" .. playerName .. "', " .. balance .. ");")
    end
end)

-- Quando o jogador clica em 'Enviar Pix' no celular
addEvent("phone:sendPix", true)
addEventHandler("phone:sendPix", root, function(targetId, amount)
    -- Envia pro servidor processar a transferência
    triggerServerEvent("phone:processPix", localPlayer, targetId, amount)
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

-- Quando a notificação terminar de aparecer (esconde o celular se ele estiver fechado)
addEvent("phone:notificationsDone", true)
addEventHandler("phone:notificationsDone", root, function()
    if not toggle and isElement(intBrowser) then
        local _, currentY2 = guiGetPosition(intBrowser, false)
        animateBrowserY(currentY2, sh + 50, 400)
    end
end)
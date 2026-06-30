
local sw, sh = guiGetScreenSize()
local toggle = false
local w, h = 300, 570
local intBrowser, browserContent, renderTimer = nil

function loadBrowser() 
    loadBrowserURL(source, "http://mta/local/html/index.html")
end

function whenBrowserReady()
    
end

function renderTime(bool)
    if bool then         
        renderTimer = setTimer(
            function () 
                executeBrowserJavascript(browserContent, "updateTime();")
            end, 0, 1000
        )
    else
        if isTimer(renderTimer) then
            killTimer(renderTimer)
            renderTimer = nil
        end
    end
end

local animTimer = nil

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
        local currentY = interpolateBetween(startY, 0, 0, endY, 0, 0, progress, "OutQuad")
        if isElement(intBrowser) then
            guiSetPosition(intBrowser, (sw - w), currentY, false)
        end
    end, 20, 0)
end

function toggleBrowser(bool)
    local x, currentY = guiGetPosition(intBrowser, false)
    if bool then 
        animateBrowserY(currentY, sh - h - 10, 400)
        guiSetInputMode("no_binds_when_editing")
        playSound("sounds/openphone.mp3")
    else 
        animateBrowserY(currentY, sh + 50, 400)
        guiSetInputMode("allow_binds")
        playSound("sounds/closephone.mp3")
    end
    renderTime(bool)
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    -- Initialize the persistent browser off-screen
    intBrowser = guiCreateBrowser((sw - w), sh + 50, w, h, true, true, false)
    browserContent = guiGetBrowser(intBrowser)
    addEventHandler("onClientBrowserCreated", intBrowser, loadBrowser)
    addEventHandler("onClientBrowserDocumentReady", intBrowser, whenBrowserReady)

    local txd = engineLoadTXD("model/phone.txd")
    if txd then engineImportTXD(txd, 330) end
    local dff = engineLoadDFF("model/phone.dff", 330)
    if dff then engineReplaceModel(dff, 330) end
end)

bindKey("k","down", 
    function () 
        toggle = not toggle 
        showCursor(toggle)
        toggleBrowser(toggle)
        triggerServerEvent("phone:syncAnimation", localPlayer, toggle)
    end
)

addEventHandler("onClientResourceStop", resourceRoot, 
    function () 
        if toggle then
            triggerServerEvent("phone:syncAnimation", localPlayer, false)
        end
        toggleBrowser(false)
        sw, sh, w, h, toggle = nil
        collectgarbage()
    end
)

-- Bank App Events
addEvent("phone:fetchBankData", true)
addEventHandler("phone:fetchBankData", root, function()
    triggerServerEvent("phone:requestBankData", localPlayer)
end)

addEvent("phone:receiveBankData", true)
addEventHandler("phone:receiveBankData", root, function(playerName, balance)
    if isElement(browserContent) then
        executeBrowserJavascript(browserContent, "updateBankData('" .. playerName .. "', " .. balance .. ");")
    end
end)

addEvent("phone:sendPix", true)
addEventHandler("phone:sendPix", root, function(targetId, amount)
    triggerServerEvent("phone:processPix", localPlayer, targetId, amount)
end)

addEvent("phone:pushNotification", true)
addEventHandler("phone:pushNotification", root, function(title, message, iconType)
    if isElement(browserContent) then
        -- Escape single quotes to prevent JS errors
        local safeTitle = string.gsub(title, "'", "\\'")
        local safeMessage = string.gsub(message, "'", "\\'")
        local safeIcon = string.gsub(iconType or "bank", "'", "\\'")
        
        executeBrowserJavascript(browserContent, string.format("showPhoneNotification('%s', '%s', '%s');", safeTitle, safeMessage, safeIcon))
        playSound("sounds/notification.mp3")
        
        if not toggle then
            local x, currentY = guiGetPosition(intBrowser, false)
            -- Slide up partially to show the notification
            animateBrowserY(currentY, sh - 115, 400)
        end
    end
end)

addEvent("phone:notificationsDone", true)
addEventHandler("phone:notificationsDone", root, function()
    if not toggle and isElement(intBrowser) then
        local _, currentY2 = guiGetPosition(intBrowser, false)
        animateBrowserY(currentY2, sh + 50, 400)
    end
end)
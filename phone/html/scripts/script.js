"use strict";

// Prevent any mouse-wheel vertical scrolling across the entire phone
document.addEventListener('wheel', function(e) {
    // Only block vertical scrolling to allow horizontal dragging scripts to function normally if they rely on it
    // Or just block all wheel events, since we drag with mousedown/move
    e.preventDefault();
}, { passive: false });

const get = (element) => { return document.querySelector(element) };
const getAll = (element) => { return document.querySelectorAll(element) };

const config = {
    battery: {
        getValue: () => get('.battery .bar').style.width,
        setValue: (value) => (get('.battery .bar').style.width = `${value}%`),
    },
    screenTimer: 30000,
}

onload = () => {
    config.battery.setValue(48);
    get('.battery .bar').style.width = `${config.battery.currentValue}%`;
}

const [lock, unlock] = [get('.lock-screen'), get('.unlock-screen')];
const interfaces = get('.apps-interfaces');
const apps = getAll('.app');
const appsInterfaces = getAll('.app-interface');

const homeButtom = get('.home-button');

function openApp(appId) {
    // Keep unlock screen visible behind apps for immersion
    interfaces.style.display = 'block';
    
    // Remove active class from all
    appsInterfaces.forEach(e => e.classList.remove('active'));
    
    let targetApp = appsInterfaces.item(appId);
    targetApp.style.display = 'block';
    // Add active class to trigger animation
    targetApp.classList.add('active');
    
    // If it's the bank app (index 5), request data from server
    if (appId == 5) {
        if (typeof mta !== 'undefined') {
            mta.triggerEvent("phone:fetchBankData");
        }
    }
}

function returnToHomePage() {
    if (interfaces.style.display === 'none') return;
    
    // reset interface style in case it was swiped
    interfaces.style.transform = 'translateX(0)';
    interfaces.style.opacity = '1';
    interfaces.style.transition = 'none';
    
    interfaces.style.display = 'none';
    appsInterfaces.forEach(e => e.style.display = 'none');
}

/* App Swipe to Exit Logic */
let appTouchStartX = 0;
let appTouchCurrentX = 0;
let isAppSwiping = false;

interfaces.addEventListener('mousedown', (e) => {
    // Only allow swipe if starting near the left edge (within 30px)
    let rect = interfaces.getBoundingClientRect();
    let relativeX = e.clientX - rect.left;
    
    if (relativeX < 30) {
        appTouchStartX = e.clientX;
        isAppSwiping = true;
        interfaces.style.transition = 'none';
    }
});

interfaces.addEventListener('mousemove', (e) => {
    if (!isAppSwiping) return;
    appTouchCurrentX = e.clientX;
    
    let deltaX = appTouchCurrentX - appTouchStartX;
    if (deltaX > 0) {
        interfaces.style.transform = `translateX(${deltaX}px)`;
        interfaces.style.opacity = Math.max(1 - (deltaX / 300), 0.3);
    }
});

function handleAppSwipeEnd() {
    if (!isAppSwiping) return;
    isAppSwiping = false;
    
    let deltaX = appTouchCurrentX - appTouchStartX;
    interfaces.style.transition = 'transform 0.3s cubic-bezier(0.25, 1, 0.5, 1), opacity 0.3s ease';
    
    if (deltaX > 80) { // threshold to exit
        interfaces.style.transform = 'translateX(100%)';
        interfaces.style.opacity = '0';
        
        setTimeout(() => {
            returnToHomePage();
        }, 300);
    } else {
        interfaces.style.transform = 'translateX(0)';
        interfaces.style.opacity = '1';
    }
}

interfaces.addEventListener('mouseup', handleAppSwipeEnd);
interfaces.addEventListener('mouseleave', handleAppSwipeEnd);


let inactivityTimeout;

function resetInactivityTimer() {
    clearTimeout(inactivityTimeout);
    inactivityTimeout = setTimeout(function () {
        appsInterfaces.forEach(e => e.style.display = 'none');
        interfaces.style.display = 'none';
        
        let unlock = get('.unlock-screen');
        let lock = get('.lock-screen');
        if (unlock) unlock.style.display = 'none';
        if (lock) {
            lock.style.display = 'block';
            lock.style.transform = 'translateY(0)';
            lock.style.opacity = '1';
        }
    }, config.screenTimer || 30000);
}

document.addEventListener("mousemove", resetInactivityTimer);
document.addEventListener("keydown", resetInactivityTimer);

function updateTime() {
    get('.digital-clock').textContent = new Intl.DateTimeFormat('en-US', { hour: 'numeric', minute: 'numeric' }).format(new Date());
    get('.the-date').textContent = new Intl.DateTimeFormat('en-US', { month: 'long', day: '2-digit', weekday: 'long' }).format(new Date());
    get('.time').textContent = new Intl.DateTimeFormat('en-US', { hour: 'numeric', minute: 'numeric' }).format(new Date()).replace(/(PM|AM)/i, '');
}

apps.forEach((app, key) => app.onclick = (e) => openApp(key));
homeButtom.onclick = (e) => {
    let lock = get('.lock-screen');
    let unlock = get('.unlock-screen');
    if (lock && lock.style.display !== 'none') {
        lock.style.display = 'none';
        if (unlock) unlock.style.display = 'flex';
        resetInactivityTimer();
    } else {
        returnToHomePage();
    }
};

/* Swipe up to unlock logic */
let touchStartY = 0;
let touchEndY = 0;
let isDragging = false;

lock.addEventListener('mousedown', (e) => {
    touchStartY = e.clientY;
    isDragging = true;
    lock.style.transition = 'none'; // Disable transition during drag
});

lock.addEventListener('mousemove', (e) => {
    if (!isDragging) return;
    touchEndY = e.clientY;
    
    // Optional: Visual feedback during drag
    let deltaY = touchStartY - touchEndY;
    if (deltaY > 0) {
        lock.style.transform = `translateY(-${Math.min(deltaY, 150)}px)`;
        lock.style.opacity = Math.max(1 - (deltaY / 300), 0.3);
    }
});

lock.addEventListener('mouseup', () => {
    if (!isDragging) return;
    isDragging = false;
    handleSwipe();
});

lock.addEventListener('mouseleave', () => {
    if (!isDragging) return;
    isDragging = false;
    handleSwipe();
});

function handleSwipe() {
    let deltaY = touchStartY - touchEndY;
    
    lock.style.transition = 'transform 0.3s cubic-bezier(0.25, 1, 0.5, 1), opacity 0.3s ease';
    
    // If swiped up at least 50px
    if (deltaY > 50) {
        lock.style.transform = 'translateY(-100%)';
        lock.style.opacity = '0';
        
        setTimeout(() => {
            lock.style.display = 'none';
            lock.style.transform = 'translateY(0)'; // reset for later
            lock.style.opacity = '1'; // reset for later
            unlock.style.display = 'flex';
            resetInactivityTimer();
        }, 300);
    } else {
        lock.style.transform = 'translateY(0)';
        lock.style.opacity = '1';
    }
}

/* Calculator App */

const resultBoard = get('.result-board');
const operations = getAll('.operations > button');

operations.forEach((operation, key) => operation.onclick = (e) => {
    operation.blur();
    switch (operation.textContent) {
        case 'AC':
            resultBoard.value = '';
            break;
        case 'C':
            resultBoard.value = resultBoard.value.length == 0 ? false : resultBoard.value.slice(0, resultBoard.value.length - 1);
            break;
        case '=':
            try {
                const expression = resultBoard.value.replace(/(×|÷)/g, match => (match === '×' ? '*' : '/'));
                const calculate = new Function('return ' + expression);
                const result = calculate();
                resultBoard.value = Number.isInteger(result) ? result : result.toFixed(2);
            } catch (error) {
                resultBoard.value = 'NaN';
            }
            break;
        default:
            resultBoard.value = resultBoard.value === 'NaN' ? operation.textContent : resultBoard.value + operation.textContent;
            break;
    }
});

/* Bank App Logic Refactored */

// Horizontal Drag to Scroll for Bank Action Squares
const bankActionSquares = get('.bank-action-squares');
let isDraggingBankMenu = false;
let startXBankMenu;
let scrollLeftBankMenu;

if (bankActionSquares) {
    bankActionSquares.addEventListener('mousedown', (e) => {
        isDraggingBankMenu = true;
        startXBankMenu = e.pageX - bankActionSquares.offsetLeft;
        scrollLeftBankMenu = bankActionSquares.scrollLeft;
    });

    bankActionSquares.addEventListener('mouseleave', () => {
        isDraggingBankMenu = false;
    });

    bankActionSquares.addEventListener('mouseup', () => {
        isDraggingBankMenu = false;
    });

    bankActionSquares.addEventListener('mousemove', (e) => {
        if (!isDraggingBankMenu) return;
        e.preventDefault();
        const x = e.pageX - bankActionSquares.offsetLeft;
        const walk = (x - startXBankMenu) * 1.5; // Scroll speed multiplier
        bankActionSquares.scrollLeft = scrollLeftBankMenu - walk;
    });
}

let currentBalance = 0;
let isBalanceHidden = false;

// Update UI from Lua
function updateBankData(playerName, balance) {
    get('#bank-user-name').textContent = playerName;
    currentBalance = parseFloat(balance);
    
    if (!isBalanceHidden) {
        get('#bank-balance-text').textContent = '$ ' + currentBalance.toLocaleString('en-US', {minimumFractionDigits: 2});
    }
}

// Balance Toggle Eye
get('#toggle-balance-eye').onclick = () => {
    isBalanceHidden = !isBalanceHidden;
    if (isBalanceHidden) {
        get('#bank-balance-text').textContent = '$ ••••';
    } else {
        get('#bank-balance-text').textContent = '$ ' + currentBalance.toLocaleString('en-US', {minimumFractionDigits: 2});
    }
};

// Navigation
const viewHome = get('.bank-view-home');
const viewPix = get('.bank-view-pix');

get('#open-pix-area').onclick = () => {
    viewHome.style.display = 'none';
    viewPix.style.display = 'flex';
};

get('#close-pix-area').onclick = () => {
    viewPix.style.display = 'none';
    viewHome.style.display = 'flex';
};

// Transfer Modal
const bankModal = get('.bank-transfer-modal');
get('#open-transfer-modal').onclick = () => {
    bankModal.style.display = 'flex';
};

get('.close-modal').onclick = () => {
    bankModal.style.display = 'none';
};

// Send Pix
const btnSendPix = get('#btn-send-pix');
btnSendPix.onclick = () => {
    const target = get('#pix-target').value;
    const amount = get('#pix-amount').value;
    
    if (!target || !amount) {
        return;
    }
    
    if (typeof mta !== 'undefined') {
        mta.triggerEvent("phone:sendPix", target, amount);
    }
    
    bankModal.style.display = 'none';
    get('#pix-target').value = '';
    get('#pix-amount').value = '';
    
    // Auto return to home
    viewPix.style.display = 'none';
    viewHome.style.display = 'flex';
};

// Global Notifications
let notificationQueue = [];
let isDisplayingNotification = false;

window.showPhoneNotification = function(title, message, iconType) {
    notificationQueue.push({title, message, iconType});
    processNotificationQueue();
};

function processNotificationQueue() {
    if (isDisplayingNotification || notificationQueue.length === 0) return;
    
    isDisplayingNotification = true;
    const notifData = notificationQueue.shift();
    
    const container = get('#notifications-container');
    if (!container) {
        isDisplayingNotification = false;
        return;
    }
    
    let notif = document.createElement('div');
    notif.className = 'phone-notification';
    
    // Icon Logic
    let iconHTML = '';
    if (notifData.iconType === 'bank') {
        iconHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M3 22h18"></path><path d="M6 18v-7"></path><path d="M10 18v-7"></path><path d="M14 18v-7"></path><path d="M18 18v-7"></path><path d="M12 2l-10 5h20l-10-5z"></path></svg>';
    } else {
        iconHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2"><path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"></path><path d="M13.73 21a2 2 0 0 1-3.46 0"></path></svg>';
    }
    
    notif.innerHTML = `
        <div class="pn-icon" ${notifData.iconType !== 'bank' ? 'style="background: #007AFF;"' : ''}>
            ${iconHTML}
        </div>
        <div class="pn-content">
            <div class="pn-title">${notifData.title}</div>
            <div class="pn-message">${notifData.message}</div>
        </div>
    `;
    
    container.appendChild(notif);
    
    // Auto remove after 5 seconds
    setTimeout(() => {
        notif.classList.add('hiding');
        setTimeout(() => {
            if(notif.parentNode) notif.parentNode.removeChild(notif);
            isDisplayingNotification = false;
            
            if (notificationQueue.length > 0) {
                processNotificationQueue();
            } else {
                if (typeof mta !== 'undefined') {
                    mta.triggerEvent("phone:notificationsDone");
                }
            }
        }, 300); // match animation duration
    }, 5000);
};
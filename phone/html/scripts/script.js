"use strict";

// Prevent any mouse-wheel vertical scrolling across the entire phone (Previne rolagem da página com o mouse para não bugar o celular)
document.addEventListener('wheel', function(e) {
    // Only block vertical scrolling to allow horizontal dragging scripts to function normally if they rely on it
    // Or just block all wheel events, since we drag with mousedown/move
    e.preventDefault();
}, { passive: false });

// Atalhos para selecionar elementos do HTML mais fácil
const get = (element) => { return document.querySelector(element) };
const getAll = (element) => { return document.querySelectorAll(element) };

// Configurações básicas do celular
const config = {
    battery: {
        getValue: () => get('.battery .bar').style.width,
        setValue: (value) => (get('.battery .bar').style.width = `${value}%`),
    },
    screenTimer: 30000, // Tempo para a tela desligar sozinha por inatividade (30 segundos)
}

// Quando a página termina de carregar
onload = () => {
    config.battery.setValue(48); // Define a bateria inicial em 48%
    get('.battery .bar').style.width = `${config.battery.currentValue}%`;
}

const [lock, unlock] = [get('.lock-screen'), get('.unlock-screen')]; // Telas de bloqueio e início
const interfaces = get('.apps-interfaces'); // Contêiner de todos os aplicativos
const apps = getAll('.app'); // Todos os ícones de aplicativos na tela inicial
const appsInterfaces = getAll('.app-interface'); // Todas as telas de aplicativos

const homeButtom = get('.home-button'); // Botão inicial (home) na parte de baixo do celular

// Função para abrir um aplicativo
function openApp(appId) {
    // Keep unlock screen visible behind apps for immersion (Mostra os aplicativos)
    interfaces.style.display = 'block';
    
    // Remove active class from all (Esconde todos os aplicativos abertos antes de abrir o novo)
    appsInterfaces.forEach(e => e.classList.remove('active'));
    
    let targetApp = appsInterfaces.item(appId);
    targetApp.style.display = 'block';
    // Add active class to trigger animation (Adiciona a classe 'active' pra fazer a animação de abrir)
    targetApp.classList.add('active');
    
    // If it's the bank app (index 5), request data from server (Se for o aplicativo do banco, avisa o Lua pra buscar os dados)
    if (appId == 5) {
        if (typeof mta !== 'undefined') {
            mta.triggerEvent("phone:fetchBankData"); // Chama o evento no lado cliente
        }
    }
}

// Função para voltar para a tela inicial
function returnToHomePage() {
    if (interfaces.style.display === 'none') return;
    
    // reset interface style in case it was swiped (Reseta o estilo caso tenha sido arrastado)
    interfaces.style.transform = 'translateX(0)';
    interfaces.style.opacity = '1';
    interfaces.style.transition = 'none';
    
    interfaces.style.display = 'none'; // Esconde a interface de aplicativos
    appsInterfaces.forEach(e => e.style.display = 'none'); // Esconde todos os aplicativos
}

/* App Swipe to Exit Logic (Lógica de arrastar da esquerda pra direita para sair do app) */
let appTouchStartX = 0;
let appTouchCurrentX = 0;
let isAppSwiping = false;

// Quando clica e segura o mouse
interfaces.addEventListener('mousedown', (e) => {
    // Only allow swipe if starting near the left edge (within 30px) (Só permite arrastar se começar bem no cantinho esquerdo)
    let rect = interfaces.getBoundingClientRect();
    let relativeX = e.clientX - rect.left;
    
    if (relativeX < 30) {
        appTouchStartX = e.clientX;
        isAppSwiping = true;
        interfaces.style.transition = 'none';
    }
});

// Quando arrasta o mouse
interfaces.addEventListener('mousemove', (e) => {
    if (!isAppSwiping) return;
    appTouchCurrentX = e.clientX;
    
    let deltaX = appTouchCurrentX - appTouchStartX;
    if (deltaX > 0) {
        interfaces.style.transform = `translateX(${deltaX}px)`;
        interfaces.style.opacity = Math.max(1 - (deltaX / 300), 0.3); // Vai ficando transparente
    }
});

// Quando solta o mouse
function handleAppSwipeEnd() {
    if (!isAppSwiping) return;
    isAppSwiping = false;
    
    let deltaX = appTouchCurrentX - appTouchStartX;
    interfaces.style.transition = 'transform 0.3s cubic-bezier(0.25, 1, 0.5, 1), opacity 0.3s ease';
    
    if (deltaX > 80) { // threshold to exit (Se arrastou mais de 80px, fecha o app)
        interfaces.style.transform = 'translateX(100%)';
        interfaces.style.opacity = '0';
        
        setTimeout(() => {
            returnToHomePage();
        }, 300);
    } else { // Se não, volta pro lugar
        interfaces.style.transform = 'translateX(0)';
        interfaces.style.opacity = '1';
    }
}

interfaces.addEventListener('mouseup', handleAppSwipeEnd);
interfaces.addEventListener('mouseleave', handleAppSwipeEnd);


let inactivityTimeout; // Variável para controlar o temporizador de desligar a tela

// Função para resetar o tempo de inatividade (Sempre que mexe no celular, a tela não desliga)
function resetInactivityTimer() {
    clearTimeout(inactivityTimeout);
    inactivityTimeout = setTimeout(function () {
        // Quando o tempo acabar, fecha tudo e vai pra tela de bloqueio
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

// Atualiza os relógios do celular
function updateTime() {
    get('.digital-clock').textContent = new Intl.DateTimeFormat('en-US', { hour: 'numeric', minute: 'numeric' }).format(new Date());
    get('.the-date').textContent = new Intl.DateTimeFormat('en-US', { month: 'long', day: '2-digit', weekday: 'long' }).format(new Date());
    get('.time').textContent = new Intl.DateTimeFormat('en-US', { hour: 'numeric', minute: 'numeric' }).format(new Date()).replace(/(PM|AM)/i, '');
}

// Eventos de clique para abrir os aplicativos
apps.forEach((app, key) => app.onclick = (e) => openApp(key));

// Evento de clique do botão Home (Botão do meio embaixo)
homeButtom.onclick = (e) => {
    let lock = get('.lock-screen');
    let unlock = get('.unlock-screen');
    // Se a tela de bloqueio estiver aberta, destrava o celular
    if (lock && lock.style.display !== 'none') {
        lock.style.display = 'none';
        if (unlock) unlock.style.display = 'flex';
        resetInactivityTimer();
    } else {
        // Se já estiver destravado, volta pra tela inicial
        returnToHomePage();
    }
};

/* Swipe up to unlock logic (Lógica de arrastar para cima para desbloquear) */
let touchStartY = 0;
let touchEndY = 0;
let isDragging = false;

// Quando clica/toca na tela de bloqueio
lock.addEventListener('mousedown', (e) => {
    touchStartY = e.clientY;
    isDragging = true;
    lock.style.transition = 'none'; // Disable transition during drag (Desativa a transição para seguir o mouse sem lag)
});

// Quando arrasta
lock.addEventListener('mousemove', (e) => {
    if (!isDragging) return;
    touchEndY = e.clientY;
    
    // Optional: Visual feedback during drag (Move a tela pra cima acompanhando o mouse)
    let deltaY = touchStartY - touchEndY;
    if (deltaY > 0) {
        lock.style.transform = `translateY(-${Math.min(deltaY, 150)}px)`; // Limita até onde sobe
        lock.style.opacity = Math.max(1 - (deltaY / 300), 0.3); // Fica transparente enquanto sobe
    }
});

// Quando solta o clique
lock.addEventListener('mouseup', () => {
    if (!isDragging) return;
    isDragging = false;
    handleSwipe();
});

// Se o mouse sair do elemento
lock.addEventListener('mouseleave', () => {
    if (!isDragging) return;
    isDragging = false;
    handleSwipe();
});

// Função que decide se vai desbloquear ou não
function handleSwipe() {
    let deltaY = touchStartY - touchEndY;
    
    lock.style.transition = 'transform 0.3s cubic-bezier(0.25, 1, 0.5, 1), opacity 0.3s ease';
    
    // If swiped up at least 50px (Se arrastou pra cima pelo menos 50px, desbloqueia)
    if (deltaY > 50) {
        lock.style.transform = 'translateY(-100%)'; // Joga a tela toda pra cima
        lock.style.opacity = '0';
        
        // Espera a animação terminar (300ms) pra mostrar a tela inicial
        setTimeout(() => {
            lock.style.display = 'none';
            lock.style.transform = 'translateY(0)'; // reset for later (Reseta pra quando travar de novo)
            lock.style.opacity = '1'; // reset for later
            unlock.style.display = 'flex';
            resetInactivityTimer();
        }, 300);
    } else {
        // Se arrastou pouco, volta pro lugar
        lock.style.transform = 'translateY(0)';
        lock.style.opacity = '1';
    }
}

/* Calculator App (Aplicativo de Calculadora) */

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

/* Bank App Logic Refactored (Lógica do Aplicativo do Banco) */

// Horizontal Drag to Scroll for Bank Action Squares (Arrastar para os lados no menu do banco)
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
        const walk = (x - startXBankMenu) * 1.5; // Scroll speed multiplier (Velocidade da rolagem)
        bankActionSquares.scrollLeft = scrollLeftBankMenu - walk;
    });
}

let currentBalance = 0; // Guarda o saldo atual
let isBalanceHidden = false; // Controla se o saldo está oculto ou não

// Update UI from Lua (Função chamada pelo Lua para atualizar o nome e saldo no celular)
function updateBankData(playerName, balance) {
    get('#bank-user-name').textContent = playerName; // Atualiza o nome
    currentBalance = parseFloat(balance); // Salva o saldo real
    
    // Se o saldo não estiver oculto, mostra o valor na tela
    if (!isBalanceHidden) {
        get('#bank-balance-text').textContent = '$ ' + currentBalance.toLocaleString('en-US', {minimumFractionDigits: 2});
    }
}

// Balance Toggle Eye (Botão de olhinho para esconder/mostrar o saldo)
get('#toggle-balance-eye').onclick = () => {
    isBalanceHidden = !isBalanceHidden; // Inverte o estado
    if (isBalanceHidden) {
        get('#bank-balance-text').textContent = '$ ••••'; // Oculta
    } else {
        get('#bank-balance-text').textContent = '$ ' + currentBalance.toLocaleString('en-US', {minimumFractionDigits: 2}); // Mostra
    }
};

// Navigation (Navegação dentro do aplicativo do banco)
const viewHome = get('.bank-view-home'); // Tela principal do banco
const viewPix = get('.bank-view-pix'); // Tela da área pix

// Abre a área Pix
get('#open-pix-area').onclick = () => {
    viewHome.style.display = 'none';
    viewPix.style.display = 'flex';
};

// Fecha a área pix e volta pro início
get('#close-pix-area').onclick = () => {
    viewPix.style.display = 'none';
    viewHome.style.display = 'flex';
};

// Transfer Modal (Janela de fazer transferência/Pix)
const bankModal = get('.bank-transfer-modal');
get('#open-transfer-modal').onclick = () => {
    bankModal.style.display = 'flex'; // Abre a janela
};

get('.close-modal').onclick = () => {
    bankModal.style.display = 'none'; // Fecha a janela
};

// Send Pix (Botão de enviar Pix)
const btnSendPix = get('#btn-send-pix');
btnSendPix.onclick = () => {
    const target = get('#pix-target').value; // Pega o ID que o jogador digitou
    const amount = get('#pix-amount').value; // Pega o valor que o jogador digitou
    
    // Se algum campo estiver vazio, não faz nada
    if (!target || !amount) {
        return;
    }
    
    // Se o MTA estiver conectado, envia pro Lua processar a transferência
    if (typeof mta !== 'undefined') {
        mta.triggerEvent("phone:sendPix", target, amount);
    }
    
    // Fecha a janela e limpa os campos
    bankModal.style.display = 'none';
    get('#pix-target').value = '';
    get('#pix-amount').value = '';
    
    // Auto return to home (Volta pra tela inicial do banco automaticamente)
    viewPix.style.display = 'none';
    viewHome.style.display = 'flex';
};

// Global Notifications (Sistema de Notificações do Celular tipo iOS)
let notificationQueue = []; // Fila de notificações para mostrar uma de cada vez
let isDisplayingNotification = false; // Controle para saber se já tem uma na tela

// Função principal chamada pelo Lua para adicionar uma notificação na tela
window.showPhoneNotification = function(title, message, iconType) {
    notificationQueue.push({title, message, iconType}); // Adiciona na fila
    processNotificationQueue(); // Tenta mostrar a notificação
};

// Função que pega a notificação da fila e exibe
function processNotificationQueue() {
    // Se já estiver mostrando uma ou a fila estiver vazia, não faz nada
    if (isDisplayingNotification || notificationQueue.length === 0) return;
    
    isDisplayingNotification = true;
    const notifData = notificationQueue.shift(); // Pega a primeira notificação da fila e remove ela
    
    const container = get('#notifications-container');
    if (!container) {
        isDisplayingNotification = false;
        return;
    }
    
    let notif = document.createElement('div');
    notif.className = 'phone-notification';
    
    // Icon Logic (Lógica para escolher o ícone baseado no tipo)
    let iconHTML = '';
    if (notifData.iconType === 'bank') {
        iconHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M3 22h18"></path><path d="M6 18v-7"></path><path d="M10 18v-7"></path><path d="M14 18v-7"></path><path d="M18 18v-7"></path><path d="M12 2l-10 5h20l-10-5z"></path></svg>';
    } else { // Ícone padrão
        iconHTML = '<svg viewBox="0 0 24 24" fill="none" stroke="white" stroke-width="2"><path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9"></path><path d="M13.73 21a2 2 0 0 1-3.46 0"></path></svg>';
    }
    
    // Monta o HTML da notificação
    notif.innerHTML = `
        <div class="pn-icon" ${notifData.iconType !== 'bank' ? 'style="background: #007AFF;"' : ''}>
            ${iconHTML}
        </div>
        <div class="pn-content">
            <div class="pn-title">${notifData.title}</div>
            <div class="pn-message">${notifData.message}</div>
        </div>
    `;
    
    container.appendChild(notif); // Adiciona na tela
    
    // Auto remove after 5 seconds (Remove automaticamente depois de 5 segundos)
    setTimeout(() => {
        notif.classList.add('hiding'); // Adiciona classe para fazer a animação de sumir
        setTimeout(() => {
            if(notif.parentNode) notif.parentNode.removeChild(notif); // Deleta o elemento HTML
            isDisplayingNotification = false;
            
            if (notificationQueue.length > 0) {
                // Se tiver mais notificação na fila, chama a função de novo
                processNotificationQueue();
            } else {
                // Se acabaram as notificações, avisa o Lua para fechar/baixar o celular
                if (typeof mta !== 'undefined') {
                    mta.triggerEvent("phone:notificationsDone");
                }
            }
        }, 300); // match animation duration (300ms = tempo da animação do CSS)
    }, 5000); // 5000ms = 5 segundos
};
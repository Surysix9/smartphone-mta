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
    
    // If it's the bank app (index 5)
    if (appId == 5) {
        // Pedimos pro servidor verificar se o jogador tem conta e se já tá logado
        if (typeof mta !== 'undefined') {
            mta.triggerEvent("phone:checkBankStatus");
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
function updateBankData(playerName, balance, accountId, historyJson, pixKey) {
    get('#bank-user-name').textContent = playerName; // Atualiza o nome
    currentBalance = parseFloat(balance); // Salva o saldo real
    
    // Atualiza a chave da conta
    const accountDisplay = get('#current-account-key');
    if (accountDisplay) {
        accountDisplay.textContent = accountId;
    }
    
    // Atualiza a chave pix na interface
    const keyDisplay = get('#current-pix-key');
    if (keyDisplay) {
        if (pixKey && pixKey.length > 0) {
            keyDisplay.textContent = pixKey;
        } else {
            keyDisplay.textContent = "Nenhuma chave gerada";
        }
    }
    
    // Se o saldo não estiver oculto, mostra o valor na tela
    if (!isBalanceHidden) {
        get('#bank-balance-text').textContent = '$ ' + currentBalance.toLocaleString('en-US', {minimumFractionDigits: 2});
    }
    
    // Processa e renderiza o histórico
    if (historyJson) {
        try {
            let history = JSON.parse(historyJson);
            
            // Corrige o aninhamento que o toJSON do MTA cria [ [ {...} ] ]
            if (Array.isArray(history) && history.length === 1 && Array.isArray(history[0])) {
                history = history[0];
            }
            
            renderBankHistory(history, accountId);
        } catch(e) {
            console.error("Erro ao carregar historico:", e);
        }
    }
}

function renderBankHistory(history, myAccountId) {
    const listHome = get('.bank-history-section .history-list');
    const listFull = get('.full-history-list');
    
    if (listHome) listHome.innerHTML = '';
    if (listFull) listFull.innerHTML = '';
    
    if (!history || history.length === 0) {
        const noDataHtml = '<div style="text-align:center; padding:20px; color:#999; font-family:sf-medium;">Nenhuma transação recente.</div>';
        if (listHome) listHome.innerHTML = noDataHtml;
        if (listFull) listFull.innerHTML = noDataHtml;
        return;
    }
    
    history.forEach((tx, index) => {
        const isSender = (tx.sender === myAccountId);
        const iconClass = isSender ? 'sent' : 'received';
        const title = isSender ? 'Transferência enviada' : 'Transferência recebida';
        const otherName = isSender ? tx.receiver_name : tx.sender_name;
        const valClass = isSender ? 'negative' : 'positive';
        const valSign = isSender ? '-$' : '+$';
        const amount = parseFloat(tx.amount).toLocaleString('en-US', {minimumFractionDigits: 2});
        
        let svg = isSender 
            ? '<svg viewBox="0 0 24 24" fill="none" stroke="#E74C3C" stroke-width="2"><line x1="5" y1="19" x2="19" y2="5"></line><polyline points="5 5 19 5 19 19"></polyline></svg>'
            : '<svg viewBox="0 0 24 24" fill="none" stroke="#8A05BE" stroke-width="2"><line x1="19" y1="5" x2="5" y2="19"></line><polyline points="19 19 5 19 5 5"></polyline></svg>';
            
        const html = `
        <div class="history-item">
            <div class="hi-icon ${iconClass}">${svg}</div>
            <div class="hi-details">
                <div class="hi-title">${title}</div>
                <div class="hi-subtitle">${otherName || 'Desconhecido'}</div>
            </div>
            <div class="hi-value ${valClass}">${valSign}${amount}</div>
        </div>
        `;
        
        if (listFull) listFull.insertAdjacentHTML('beforeend', html);
        if (listHome && index < 3) listHome.insertAdjacentHTML('beforeend', html);
    });
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
const viewAuth = get('.bank-view-auth');
const viewLogin = get('.bank-view-login');
const viewRegister = get('.bank-view-register');
const viewHome = get('.bank-view-home'); // Tela principal do banco
const viewPix = get('.bank-view-pix'); // Tela da área pix
const viewHistory = get('.bank-view-history'); // Tela do extrato completo
const viewKeys = get('.bank-view-keys'); // Tela das chaves pix

let isBankLogged = false;

// Recebe a verificação do servidor se a pessoa já tem conta ou já ta logada
window.handleBankStatus = function(status, accountData) {
    if (status === 'logged_in') {
        isBankLogged = true;
        viewAuth.style.display = 'none';
        viewLogin.style.display = 'none';
        viewRegister.style.display = 'none';
        viewHome.style.display = 'flex';
        viewPix.style.display = 'none';
        if (typeof mta !== 'undefined') {
            mta.triggerEvent("phone:fetchBankData");
        }
    } else if (status === 'has_account') {
        isBankLogged = false;
        viewAuth.style.display = 'none';
        viewRegister.style.display = 'none';
        viewHome.style.display = 'none';
        viewPix.style.display = 'none';
        viewLogin.style.display = 'flex';
        
        const accInput = get('#login-account');
        accInput.value = accountData; // Preenche automático
        accInput.readOnly = true; // Impede alterar
        accInput.style.color = '#8A05BE'; // Estiliza pra mostrar que tá bloqueado/verificado
        
        // Foca automaticamente no campo de senha
        setTimeout(() => get('#login-password').focus(), 100);
    } else {
        // no_account
        isBankLogged = false;
        viewLogin.style.display = 'none';
        viewRegister.style.display = 'none';
        viewHome.style.display = 'none';
        viewPix.style.display = 'none';
        viewAuth.style.display = 'flex'; // Mostra a tela de boas vindas
    }
}

// Botões da tela de Auth
get('#btn-show-login').onclick = () => {
    viewAuth.style.display = 'none';
    viewLogin.style.display = 'flex';
};

get('#btn-show-register').onclick = () => {
    viewAuth.style.display = 'none';
    viewRegister.style.display = 'flex';
};

// Botões de voltar para Auth
getAll('.back-to-auth').forEach(btn => {
    btn.onclick = () => {
        viewLogin.style.display = 'none';
        viewRegister.style.display = 'none';
        viewAuth.style.display = 'flex';
    };
});

// Enviar Registro
get('#btn-submit-register').onclick = () => {
    const pwd = get('#register-password').value;
    if (pwd.length < 4) return;
    if (typeof mta !== 'undefined') {
        mta.triggerEvent("phone:sendBankRegister", pwd);
    }
};

// Callback do Lua ao criar conta com sucesso
window.onBankRegisterSuccess = function(newAccount) {
    viewRegister.style.display = 'none';
    viewLogin.style.display = 'flex';
    get('#login-account').value = newAccount;
};

// Enviar Login
get('#btn-submit-login').onclick = () => {
    const acc = get('#login-account').value;
    const pwd = get('#login-password').value;
    if (!acc || pwd.length < 4) return;
    if (typeof mta !== 'undefined') {
        mta.triggerEvent("phone:sendBankLogin", acc, pwd);
    }
};

// Callback do Lua ao logar com sucesso
window.onBankLoginSuccess = function(accountId) {
    isBankLogged = true;
    viewLogin.style.display = 'none';
    viewHome.style.display = 'flex';
    // fetchBankData will be called by the server event requestBankData automatically
};


// Abre a área Pix
get('#open-pix-area').onclick = () => {
    viewHome.style.display = 'none';
    viewPix.style.display = 'block';
};

// Fecha a área pix e volta pro início
get('#close-pix-area').onclick = () => {
    viewPix.style.display = 'none';
    viewHome.style.display = 'flex';
};

// Abre o Extrato
get('#btn-see-all-history').onclick = (e) => {
    e.preventDefault();
    viewHome.style.display = 'none';
    viewHistory.style.display = 'flex';
};

// Fecha o Extrato
get('#close-history-area').onclick = () => {
    viewHistory.style.display = 'none';
    viewHome.style.display = 'flex';
};

// Abre Minhas Chaves
get('#open-keys-area').onclick = () => {
    viewPix.style.display = 'none';
    viewKeys.style.display = 'flex';
};

// Fecha Minhas Chaves
get('#close-keys-area').onclick = () => {
    viewKeys.style.display = 'none';
    viewPix.style.display = 'block'; // Volta pra tela do pix
};

// Modal de Senha da Chave
const keyPasswordModal = get('.key-password-modal');

// Quando clica em Gerar Chave Aleatória
get('#btn-generate-pix-key').onclick = () => {
    keyPasswordModal.style.display = 'flex';
    get('#key-password-input').value = '';
};

// Fechar modal da senha da chave
get('.key-password-modal .close-key-modal').onclick = () => {
    keyPasswordModal.style.display = 'none';
};

// Fechar pelo comando do servidor
window.closeKeyModal = function() {
    keyPasswordModal.style.display = 'none';
};

// Confirmar senha para gerar chave
get('#btn-confirm-key-generate').onclick = () => {
    const pwd = get('#key-password-input').value;
    if (pwd.length < 4) return;
    
    const loadingText = loadingModal.querySelector('span');
    loadingText.textContent = "Gerando nova chave...";
    loadingModal.style.display = 'flex'; // Exibe loading
    
    setTimeout(() => { loadingText.textContent = "Registrando no banco..."; }, 800);
    
    setTimeout(() => {
        if (typeof mta !== 'undefined') {
            mta.triggerEvent("phone:generatePixKey", pwd);
        }
        loadingText.textContent = "Processando..."; // Reset
    }, 1800);
};

// Transfer Modal (Janela de fazer transferência/Pix)
const bankModal = get('.pix-transfer-modal');
get('#open-transfer-modal').onclick = () => {
    bankModal.style.display = 'flex'; // Abre a janela
};

get('.pix-transfer-modal .close-modal').onclick = () => {
    bankModal.style.display = 'none'; // Fecha a janela
};

// Modal elements
const confirmModal = get('.pix-confirm-modal');
const loadingModal = get('.bank-loading-modal');

// Verify Pix (Botão da tela inicial de transferência)
const btnVerifyPix = get('#btn-verify-pix');
btnVerifyPix.onclick = () => {
    const target = get('#pix-target').value;
    const amount = get('#pix-amount').value;
    
    if (!target || !amount || amount <= 0) return;
    
    const loadingText = loadingModal.querySelector('span');
    loadingText.textContent = "Buscando dados...";
    loadingModal.style.display = 'flex';
    
    setTimeout(() => {
        if (typeof mta !== 'undefined') {
            mta.triggerEvent("phone:verifyPixTarget", target, amount);
        }
        loadingText.textContent = "Processando..."; // Reset
    }, 800);
};

// Função para copiar a chave ao clicar no cartão
window.copyKey = function(type) {
    let keyToCopy = "";
    if (type === 'account') {
        keyToCopy = get('#current-account-key').textContent;
    } else if (type === 'random') {
        keyToCopy = get('#current-pix-key').textContent;
    }
    
    // Se não tiver chave, não faz nada
    if (!keyToCopy || keyToCopy.includes("Nenhuma") || keyToCopy === "Carregando...") return;
    
    if (typeof mta !== 'undefined') {
        mta.triggerEvent("phone:copyToClipboard", keyToCopy);
    }
};

// Recebido do Lua quando o alvo existe e o saldo é suficiente
window.onPixVerified = function(amount, targetName, targetAccount) {
    loadingModal.style.display = 'none'; // esconde loading
    bankModal.style.display = 'none'; // esconde tela de valor
    
    // Preenche tela de confirmação
    get('#confirm-pix-amount').innerText = '$' + amount;
    get('#confirm-pix-name').innerText = targetName;
    get('#confirm-pix-target').innerText = targetAccount;
    get('#pix-password').value = '';
    
    confirmModal.style.display = 'flex'; // Abre tela de senha
    setTimeout(() => get('#pix-password').focus(), 100);
};

// Voltar da tela de confirmação
get('.pix-confirm-modal .close-confirm').onclick = () => {
    confirmModal.style.display = 'none';
    bankModal.style.display = 'flex';
};

// Fechar tela de loading caso dê erro na verificação
window.hideBankLoading = function() {
    loadingModal.style.display = 'none';
};

// Botão de confirmar PIX com a senha
const btnConfirmPix = get('#btn-confirm-pix');
btnConfirmPix.onclick = () => {
    const target = get('#pix-target').value;
    const amount = get('#pix-amount').value;
    const password = get('#pix-password').value;
    
    if (!password || password.length < 4) return;
    
    const loadingText = loadingModal.querySelector('span');
    loadingText.textContent = "Preparando transferência...";
    loadingModal.style.display = 'flex';
    
    setTimeout(() => { loadingText.textContent = "Enviando valor..."; }, 900);
    setTimeout(() => { loadingText.textContent = "Gerando comprovante..."; }, 1800);
    
    setTimeout(() => {
        if (typeof mta !== 'undefined') {
            mta.triggerEvent("phone:processPix", target, amount, password);
        }
        loadingText.textContent = "Processando..."; // Reset
    }, 2800);
};

// Quando o PIX termina (sucesso)
window.onPixSuccess = function() {
    loadingModal.style.display = 'none';
    confirmModal.style.display = 'none';
    
    get('#pix-target').value = '';
    get('#pix-amount').value = '';
    get('#pix-password').value = '';
    
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
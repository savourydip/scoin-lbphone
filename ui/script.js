// Store current balance and citizen ID
let currentBalance = 0;
let currentCitizenId = null;
let balanceInterval = null;

// In a plain browser (no FiveM) there is no invokeNative
const devMode = !window.invokeNative;

// Resolves once the phone has injected its API (fetchNui, useNuiEvent, etc.)
function whenReady() {
    return new Promise((resolve) => {
        if (window.componentsLoaded) return resolve();

        const poll = setInterval(() => {
            if (window.componentsLoaded) {
                clearInterval(poll);
                resolve();
            }
        }, 50);

        window.addEventListener('message', (e) => {
            if (e.data === 'componentsLoaded') {
                clearInterval(poll);
                resolve();
            }
        });
    });
}

// Wrapper around the phone's injected fetchNui (targets THIS resource's NUI callbacks).
// Named "nui" on purpose so it never clashes with the injected global.
function nui(eventName, data) {
    if (typeof window.fetchNui !== 'function') return Promise.resolve();
    return window.fetchNui(eventName, data || {});
}

// SD phone: useNuiEvent. lb-phone fallback: plain window message event.
function onNui(action, cb) {
    if (typeof window.useNuiEvent === 'function') {
        window.useNuiEvent(action, cb);
    } else {
        window.addEventListener('message', (e) => {
            if (e.data && e.data.action === action) {
                cb(e.data.data !== undefined ? e.data.data : e.data);
            }
        });
    }
}

// Light/dark theme from the phone settings
function setTheme(theme) {
    document.documentElement.setAttribute('data-theme', theme === 'dark' ? 'dark' : 'light');
}

async function initTheme() {
    try {
        if (typeof window.GetSettings !== 'function') return;
        const settings = await window.GetSettings();
        setTheme(settings && settings.display && settings.display.theme);

        if (typeof window.OnSettingsChange === 'function') {
            window.OnSettingsChange((s) => setTheme(s && s.display && s.display.theme));
        }
    } catch (e) {
        // keep default theme
    }
}

// Update balance display
function updateBalance(balance, citizenId) {
    currentBalance = balance;
    currentCitizenId = citizenId;

    const balanceElement = document.getElementById('balance');
    const transferBalanceElement = document.getElementById('transferBalance');
    const citizenIdElement = document.getElementById('citizenId');
    const refreshBtn = document.getElementById('refreshBtn');

    // Update citizen ID
    if (citizenId && citizenIdElement) {
        citizenIdElement.textContent = citizenId;
    }

    // Stop any animation still running from a previous update
    if (balanceInterval) {
        clearInterval(balanceInterval);
        balanceInterval = null;
    }

    // Animate number change for balance
    const currentDisplayBalance = parseInt(balanceElement.textContent.replace(/,/g, '')) || 0;
    const targetBalance = balance;
    const duration = 1000; // 1 second
    const steps = 30;
    const increment = (targetBalance - currentDisplayBalance) / steps;
    const stepDuration = duration / steps;

    let currentStep = 0;

    balanceInterval = setInterval(() => {
        currentStep++;
        const newValue = Math.round(currentDisplayBalance + (increment * currentStep));
        balanceElement.textContent = newValue.toLocaleString();

        if (currentStep >= steps) {
            clearInterval(balanceInterval);
            balanceInterval = null;
            balanceElement.textContent = targetBalance.toLocaleString();
            if (transferBalanceElement) {
                transferBalanceElement.textContent = targetBalance.toLocaleString() + ' sCoin';
            }
            refreshBtn.classList.remove('loading');
        }
    }, stepDuration);
}

// Request balance from server
async function requestBalance() {
    const refreshBtn = document.getElementById('refreshBtn');
    if (refreshBtn) {
        refreshBtn.classList.add('loading');
    }

    await nui('getBalance', {});
}

// Copy citizen ID to clipboard
function copyCitizenId() {
    if (currentCitizenId) {
        // Create a temporary input to copy from
        const tempInput = document.createElement('input');
        tempInput.value = currentCitizenId;
        document.body.appendChild(tempInput);
        tempInput.select();
        document.execCommand('copy');
        document.body.removeChild(tempInput);

        // Show feedback
        const copyBtn = document.getElementById('copyCitizenBtn');
        const originalHTML = copyBtn.innerHTML;
        copyBtn.innerHTML = '<span style="font-size: 0.75rem;">Copied!</span>';
        setTimeout(() => {
            copyBtn.innerHTML = originalHTML;
        }, 1500);
    }
}

// Handle tab switching
function switchTab(tabName) {
    // Update tab buttons
    const tabButtons = document.querySelectorAll('.tab-btn');
    tabButtons.forEach(btn => {
        if (btn.dataset.tab === tabName) {
            btn.classList.add('active');
        } else {
            btn.classList.remove('active');
        }
    });

    // Update tab content
    const tabContents = document.querySelectorAll('.tab-content');
    tabContents.forEach(content => {
        if (content.id === `${tabName}-tab`) {
            content.classList.add('active');
        } else {
            content.classList.remove('active');
        }
    });

    // Update transfer balance when switching to transfer tab
    if (tabName === 'transfer') {
        const transferBalanceElement = document.getElementById('transferBalance');
        if (transferBalanceElement) {
            transferBalanceElement.textContent = currentBalance.toLocaleString() + ' sCoin';
        }
    }
}

// Show alert message
function showAlert(message, isSuccess) {
    const alert = document.getElementById('transferAlert');
    const alertMessage = document.getElementById('alertMessage');

    if (alert && alertMessage) {
        alertMessage.textContent = message;
        alert.className = 'alert ' + (isSuccess ? 'alert-success' : 'alert-error');
        alert.style.display = 'block';

        // Auto hide after 5 seconds
        setTimeout(() => {
            alert.style.display = 'none';
        }, 5000);
    }
}

// Handle transfer form submission
async function handleTransfer(event) {
    event.preventDefault();

    const recipientId = document.getElementById('recipientId').value.trim();
    const amount = parseInt(document.getElementById('amount').value);
    const transferBtn = document.getElementById('transferBtn');

    // Validate inputs
    if (!recipientId) {
        showAlert('Please enter a recipient Citizen ID', false);
        return;
    }

    if (!amount || amount <= 0) {
        showAlert('Please enter a valid amount', false);
        return;
    }

    if (amount > currentBalance) {
        showAlert('Insufficient balance', false);
        return;
    }

    if (recipientId === currentCitizenId) {
        showAlert('Cannot transfer to yourself', false);
        return;
    }

    // Show loading state
    transferBtn.classList.add('loading');
    transferBtn.disabled = true;

    // Send transfer request
    await nui('transfer', {
        citizenId: recipientId,
        amount: amount
    });
}

// Result of a transfer, pushed from client.lua
function handleTransferResult(data) {
    const transferBtn = document.getElementById('transferBtn');
    if (transferBtn) {
        transferBtn.classList.remove('loading');
        transferBtn.disabled = false;
    }

    showAlert(data.message, data.success);

    if (data.success) {
        // Clear form
        document.getElementById('recipientId').value = '';
        document.getElementById('amount').value = '';

        // Update balance
        if (data.newBalance !== undefined && data.newBalance !== null) {
            currentBalance = data.newBalance;
            const balanceElement = document.getElementById('balance');
            const transferBalanceElement = document.getElementById('transferBalance');
            if (balanceElement) {
                balanceElement.textContent = data.newBalance.toLocaleString();
            }
            if (transferBalanceElement) {
                transferBalanceElement.textContent = data.newBalance.toLocaleString() + ' sCoin';
            }
        }

        // Switch back to balance tab after successful transfer
        setTimeout(() => {
            switchTab('balance');
        }, 2000);
    }
}

// Runs once the phone API exists
function initApp() {
    onNui('updateBalance', (d) => updateBalance(d.balance, d.citizenId));

    onNui('transferResult', handleTransferResult);

    onNui('receiveNotification', (d) => {
        showAlert(`You received ${Number(d.amount).toLocaleString()} sCoin from ${d.senderCitizenId}`, true);
        requestBalance();
    });

    initTheme();

    // UI pulls its own data on mount (don't push from onOpen)
    requestBalance();
}

// DOM listeners (safe at parse time, they only use the phone API on click)
document.addEventListener('DOMContentLoaded', () => {
    const refreshBtn = document.getElementById('refreshBtn');
    const copyCitizenBtn = document.getElementById('copyCitizenBtn');
    const transferForm = document.getElementById('transferForm');
    const tabButtons = document.querySelectorAll('.tab-btn');

    if (refreshBtn) {
        refreshBtn.addEventListener('click', requestBalance);
    }

    if (copyCitizenBtn) {
        copyCitizenBtn.addEventListener('click', copyCitizenId);
    }

    if (transferForm) {
        transferForm.addEventListener('submit', handleTransfer);
    }

    tabButtons.forEach(btn => {
        btn.addEventListener('click', () => {
            switchTab(btn.dataset.tab);
        });
    });
});

// Boot
if (devMode) {
    // Plain browser: reveal the page, no phone API available
    document.body.style.visibility = 'visible';
} else {
    whenReady().then(initApp);
}

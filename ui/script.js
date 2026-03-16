// Store current balance and citizen ID
let currentBalance = 0;
let currentCitizenId = null;

// Fetch NUI function for communicating with FiveM
async function fetchNui(eventName, data) {
    const options = {
        method: 'post',
        headers: {
            'Content-Type': 'application/json; charset=UTF-8',
        },
        body: JSON.stringify(data || {})
    };

    const resourceName = window.GetParentResourceName ? window.GetParentResourceName() : 'scoin-lbphone';
    const resp = await fetch(`https://${resourceName}/${eventName}`, options);
    return await resp.json();
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
    
    // Animate number change for balance
    const currentDisplayBalance = parseInt(balanceElement.textContent.replace(/,/g, '')) || 0;
    const targetBalance = balance;
    const duration = 1000; // 1 second
    const steps = 30;
    const increment = (targetBalance - currentDisplayBalance) / steps;
    const stepDuration = duration / steps;
    
    let currentStep = 0;
    
    const interval = setInterval(() => {
        currentStep++;
        const newValue = Math.round(currentDisplayBalance + (increment * currentStep));
        balanceElement.textContent = newValue.toLocaleString();
        
        if (currentStep >= steps) {
            clearInterval(interval);
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
    
    await fetchNui('getBalance', {});
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
    await fetchNui('transfer', {
        citizenId: recipientId,
        amount: amount
    });
}

// Listen for messages from client.lua
window.addEventListener('message', (event) => {
    const data = event.data;
    
    if (data.action === 'updateBalance') {
        updateBalance(data.balance, data.citizenId);
    } else if (data.action === 'transferResult') {
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
            if (data.newBalance !== undefined) {
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
    } else if (data.action === 'receiveNotification') {
        // Show notification when receiving sCoin
        showAlert(`You received ${data.amount.toLocaleString()} sCoin from ${data.senderCitizenId}`, true);
        
        // Refresh balance
        requestBalance();
    }
});

// Load balance on page load
document.addEventListener('DOMContentLoaded', () => {
    const refreshBtn = document.getElementById('refreshBtn');
    const copyCitizenBtn = document.getElementById('copyCitizenBtn');
    const transferForm = document.getElementById('transferForm');
    const tabButtons = document.querySelectorAll('.tab-btn');
    
    // Add click listener to refresh button
    if (refreshBtn) {
        refreshBtn.addEventListener('click', requestBalance);
    }
    
    // Add click listener to copy citizen ID button
    if (copyCitizenBtn) {
        copyCitizenBtn.addEventListener('click', copyCitizenId);
    }
    
    // Add submit listener to transfer form
    if (transferForm) {
        transferForm.addEventListener('submit', handleTransfer);
    }
    
    // Add click listeners to tab buttons
    tabButtons.forEach(btn => {
        btn.addEventListener('click', () => {
            switchTab(btn.dataset.tab);
        });
    });
    
    // Auto-load balance on open
    setTimeout(() => {
        requestBalance();
    }, 100);
});

// Bol-Khata Final - Working JavaScript with Professional UI

// Configuration - Update these URLs after Render deployment
const API_BASE = window.location.hostname === 'localhost' 
    ? 'http://localhost:8081/api' 
    : 'https://bolkhata-banking.onrender.com/api';
const VOICE_API = window.location.hostname === 'localhost'
    ? 'http://localhost:8000'
    : 'https://bolkhata-voice.onrender.com';

// State
let currentUser = null;
let isRecording = false;
let mediaRecorder = null;
let audioChunks = [];
let recordingTimer = null;
let recordingSeconds = 0;
let currentIntent = null;
let currentTranscription = null;
let currentAudioData = null;
let allCustomers = [];
let allTransactions = [];
let revenueChart = null;
let transactionTypeChart = null;

// Initialize App
document.addEventListener('DOMContentLoaded', async () => {
    console.log('App initializing...');
    
    // Check authentication
    const userId = localStorage.getItem('userId');
    const shopName = localStorage.getItem('shopName');
    const mobile = localStorage.getItem('mobile');
    const language = localStorage.getItem('language');
    
    if (!userId) {
        console.log('No user ID, redirecting to login');
        window.location.href = 'login-pro.html';
        return;
    }
    
    currentUser = { userId, shopName, mobile, language };
    console.log('Current user:', currentUser);
    
    // Update UI with user info
    document.getElementById('userShopName').textContent = shopName || 'Shopkeeper';
    document.getElementById('userMobile').textContent = mobile || '';
    
    // Hide loading screen
    setTimeout(() => {
        document.getElementById('loadingScreen').style.display = 'none';
        document.getElementById('appContainer').style.display = 'flex';
        console.log('App container displayed');
    }, 1000);
    
    // Setup navigation
    setupNavigation();
    
    // Setup event listeners
    setupEventListeners();
    
    // Load theme preference
    loadThemePreference();
    
    console.log('App initialization complete');
});

// Setup Navigation
function setupNavigation() {
    document.querySelectorAll('.nav-item').forEach(item => {
        item.addEventListener('click', (e) => {
            e.preventDefault();
            const page = item.getAttribute('data-page');
            if (page) {
                navigateTo(page);
            }
        });
    });
}

function navigateTo(page) {
    console.log('Navigating to:', page);
    
    // Update active nav item
    document.querySelectorAll('.nav-item').forEach(item => {
        item.classList.remove('active');
    });
    const navItem = document.querySelector(`[data-page="${page}"]`);
    if (navItem) {
        navItem.classList.add('active');
    }
    
    // Show page
    document.querySelectorAll('.page').forEach(p => {
        p.classList.remove('active');
    });
    const pageElement = document.getElementById(`${page}-page`);
    if (pageElement) {
        pageElement.classList.add('active');
    }
    
    // Load page data
    switch(page) {
        case 'dashboard':
            loadDashboard();
            break;
        case 'customers':
            loadCustomers();
            break;
        case 'transactions':
            loadTransactions();
            break;
        case 'passbook':
            loadPassbook();
            break;
    }
}

// Setup Event Listeners
function setupEventListeners() {
    // Voice button
    const voiceBtn = document.getElementById('voiceBtn');
    if (voiceBtn) {
        voiceBtn.addEventListener('click', toggleRecording);
    }
    
    // Try again button
    const tryAgainBtn = document.getElementById('tryAgainBtn');
    if (tryAgainBtn) {
        tryAgainBtn.addEventListener('click', resetVoiceEntry);
    }
    
    // Confirm button
    const confirmBtn = document.getElementById('confirmBtn');
    if (confirmBtn) {
        confirmBtn.addEventListener('click', confirmTransaction);
    }
    
    // Manual entry button - add event listener with ID
    const manualEntryBtn = document.getElementById('manualEntryBtn');
    if (manualEntryBtn) {
        console.log('Manual entry button found, adding event listener');
        manualEntryBtn.addEventListener('click', function(e) {
            e.preventDefault();
            e.stopPropagation();
            console.log('Manual entry button clicked via event listener!');
            openManualEntryModal();
        });
    } else {
        console.warn('Manual entry button not found by ID');
    }
}

// Voice Recording Functions
async function toggleRecording() {
    if (!isRecording) {
        await startRecording();
    } else {
        stopRecording();
    }
}

async function startRecording() {
    try {
        const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
        mediaRecorder = new MediaRecorder(stream);
        audioChunks = [];
        
        mediaRecorder.ondataavailable = (event) => {
            audioChunks.push(event.data);
        };
        
        mediaRecorder.onstop = async () => {
            const audioBlob = new Blob(audioChunks, { type: 'audio/wav' });
            await processAudio(audioBlob);
        };
        
        mediaRecorder.start();
        isRecording = true;
        
        // Update UI
        document.getElementById('voiceBtn').classList.add('recording');
        document.getElementById('voiceBtn').innerHTML = '<i class="fas fa-stop"></i>';
        document.getElementById('voiceStatus').textContent = 'Recording... Speak now';
        document.getElementById('voiceWaves').classList.add('active');
        
        // Start timer
        recordingSeconds = 0;
        recordingTimer = setInterval(() => {
            recordingSeconds++;
            const minutes = Math.floor(recordingSeconds / 60);
            const seconds = recordingSeconds % 60;
            document.getElementById('voiceTimer').textContent = 
                `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
        }, 1000);
        
    } catch (error) {
        console.error('Error starting recording:', error);
        showToast('Microphone access denied. Please enable microphone access.', 'error');
    }
}

function stopRecording() {
    if (mediaRecorder && isRecording) {
        mediaRecorder.stop();
        mediaRecorder.stream.getTracks().forEach(track => track.stop());
        isRecording = false;
        
        // Update UI
        document.getElementById('voiceBtn').classList.remove('recording');
        document.getElementById('voiceBtn').innerHTML = '<i class="fas fa-microphone"></i>';
        document.getElementById('voiceStatus').textContent = 'Processing...';
        document.getElementById('voiceWaves').classList.remove('active');
        
        // Stop timer
        clearInterval(recordingTimer);
    }
}

async function processAudio(audioBlob) {
    try {
        const formData = new FormData();
        formData.append('audio', audioBlob, 'recording.wav');
        formData.append('language', currentUser.language || 'hi');
        formData.append('user_id', currentUser.userId);

        const response = await fetch(`${VOICE_API}/process-voice`, {
            method: 'POST',
            body: formData
        });

        if (!response.ok) {
            throw new Error('Voice processing failed');
        }

        const result = await response.json();
        showIntent(result);

    } catch (error) {
        console.error('Error:', error);
        document.getElementById('voiceStatus').textContent = 'Error processing audio';
        showToast('Error processing audio: ' + error.message, 'error');
        setTimeout(resetVoiceEntry, 3000);
    }
}

function showIntent(result) {
    currentIntent = result;
    currentTranscription = result.transcription;
    currentAudioData = result.audio_data;

    // Show results section
    document.getElementById('transcriptionResults').style.display = 'grid';
    
    // Show original transcription
    document.getElementById('originalText').textContent = result.transcription;

    // Show English translation
    document.getElementById('translatedText').textContent = result.english_translation || result.transcription;

    // Show extracted intent
    document.getElementById('detectedCustomer').textContent = result.name || 'Unknown';
    document.getElementById('detectedAmount').textContent = '₹' + (result.amount || 0);
    
    const typeBadge = document.getElementById('detectedType');
    typeBadge.textContent = result.type || 'Unknown';
    typeBadge.className = `value badge ${result.type}`;

    // Show confidence
    const confidence = Math.round((result.confidence || 0) * 100);
    document.getElementById('confidenceFill').style.width = `${confidence}%`;
    document.getElementById('confidenceText').textContent = `${confidence}%`;

    // Show warning for low confidence
    const lowConfWarning = document.getElementById('lowConfidenceWarning');
    if (result.confidence < 0.7) {
        lowConfWarning.style.display = 'block';
    } else {
        lowConfWarning.style.display = 'none';
    }

    document.getElementById('voiceStatus').textContent = 'Review and confirm';
}

function resetVoiceEntry() {
    document.getElementById('transcriptionResults').style.display = 'none';
    document.getElementById('resultBox').style.display = 'none';
    document.getElementById('voiceStatus').textContent = 'Click microphone to start recording';
    document.getElementById('voiceTimer').textContent = '00:00';
    currentIntent = null;
    currentTranscription = null;
    currentAudioData = null;
}

async function confirmTransaction() {
    try {
        const response = await fetch(`${API_BASE}/transactions/log`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-User-Id': currentUser.userId
            },
            body: JSON.stringify({
                name: currentIntent.name,
                amount: currentIntent.amount,
                type: currentIntent.type,
                confidence: currentIntent.confidence || 0.95,
                transcription: currentTranscription,
                audioData: currentAudioData
            })
        });

        const result = await response.json();

        const resultBox = document.getElementById('resultBox');
        resultBox.style.display = 'block';
        
        if (result.success) {
            resultBox.style.background = 'linear-gradient(135deg, #d1fae5 0%, #a7f3d0 100%)';
            resultBox.style.color = '#065f46';
            resultBox.style.border = '3px solid #10b981';
            resultBox.innerHTML = `
                <h3 style="margin-bottom: 10px;"><i class="fas fa-check-circle"></i> Success!</h3>
                <p>${result.responseText || result.message}</p>
                <p style="font-size:1.5em; font-weight:700; margin-top:10px;">Balance: ₹${result.updatedBalance}</p>
            `;
            
            showToast('Transaction recorded successfully!', 'success');
            
            setTimeout(() => {
                resetVoiceEntry();
            }, 3000);
        } else {
            resultBox.style.background = 'linear-gradient(135deg, #fee2e2 0%, #fecaca 100%)';
            resultBox.style.color = '#991b1b';
            resultBox.style.border = '3px solid #ef4444';
            resultBox.innerHTML = `
                <h3 style="margin-bottom: 10px;"><i class="fas fa-times-circle"></i> Error</h3>
                <p>${result.responseText || result.message}</p>
            `;
            showToast('Error recording transaction', 'error');
        }

    } catch (error) {
        console.error('Error:', error);
        showToast('Error: ' + error.message, 'error');
    }
}

// Dashboard Functions
async function loadDashboard() {
    try {
        const [statsRes, transactionsRes, customersRes] = await Promise.all([
            fetch(`${API_BASE}/statistics`, { headers: { 'X-User-Id': currentUser.userId } }),
            fetch(`${API_BASE}/transactions`, { headers: { 'X-User-Id': currentUser.userId } }),
            fetch(`${API_BASE}/customers`, { headers: { 'X-User-Id': currentUser.userId } })
        ]);

        const stats = await statsRes.json();
        const transactions = await transactionsRes.json();
        const customers = await customersRes.json();

        // Update statistics cards with new financial model
        document.getElementById('totalCustomers').textContent = stats.totalCustomers || 0;
        document.getElementById('totalCredit').textContent = '₹' + (stats.totalCreditGiven || 0).toFixed(2);
        document.getElementById('totalPayment').textContent = '₹' + (stats.totalIncome || 0).toFixed(2);
        document.getElementById('outstandingBalance').textContent = '₹' + (stats.totalOutstanding || 0).toFixed(2);

        // Update trends
        const outstandingPercent = stats.totalCreditGiven > 0 
            ? ((stats.totalOutstanding / stats.totalCreditGiven) * 100).toFixed(0)
            : 0;
        document.getElementById('outstandingTrend').textContent = `${outstandingPercent}% of credit`;

        // Recent transactions
        const list = document.getElementById('recentTransactionsList');
        if (transactions.length === 0) {
            list.innerHTML = '<p style="text-align: center; color: var(--text-secondary); padding: 20px;">No transactions yet</p>';
        } else {
            list.innerHTML = '<table class="data-table"><thead><tr><th>Customer</th><th>Type</th><th>Amount</th><th>Date</th><th>Audio</th></tr></thead><tbody>' +
                transactions.slice(0, 10).map(t => `
                    <tr>
                        <td>${t.customerName || 'Unknown'}</td>
                        <td><span class="badge ${getTransactionBadgeClass(t.type)}">${getTransactionLabel(t.type)}</span></td>
                        <td style="font-weight: 600;">₹${t.amount}</td>
                        <td>${new Date(t.timestamp).toLocaleString()}</td>
                        <td>${t.audioFilePath ? `<button class="action-icon" onclick="playAudio('${t.audioFilePath}')"><i class="fas fa-play"></i></button>` : '-'}</td>
                    </tr>
                `).join('') + '</tbody></table>';
        }

        // Top customers by outstanding
        const topCustomers = customers
            .filter(c => c.outstanding > 0)
            .sort((a, b) => b.outstanding - a.outstanding)
            .slice(0, 5);

        const topList = document.getElementById('topCustomersList');
        if (topCustomers.length === 0) {
            topList.innerHTML = '<p style="text-align: center; color: var(--text-secondary); padding: 20px;">No outstanding balances</p>';
        } else {
            topList.innerHTML = '<div class="top-customers-grid">' +
                topCustomers.map(c => `
                    <div class="top-customer-card">
                        <div class="customer-avatar">${c.name.charAt(0).toUpperCase()}</div>
                        <div class="customer-details">
                            <h4>${c.name}</h4>
                            <p class="customer-mobile">${c.mobile || 'No mobile'}</p>
                        </div>
                        <div class="customer-outstanding">
                            <span class="outstanding-amount">₹${c.outstanding.toFixed(2)}</span>
                            <span class="outstanding-label">Outstanding</span>
                        </div>
                    </div>
                `).join('') + '</div>';
        }

        // Initialize charts
        initializeCharts(transactions);

    } catch (error) {
        console.error('Error loading dashboard:', error);
        showToast('Error loading dashboard', 'error');
    }
}

// Initialize Charts
function initializeCharts(transactions) {
    // Revenue Trend Chart
    const revenueData = calculateRevenueData(transactions, 7);
    initializeRevenueChart(revenueData);

    // Transaction Type Chart
    const typeData = calculateTransactionTypeData(transactions);
    initializeTransactionTypeChart(typeData);
}

function calculateRevenueData(transactions, days) {
    const now = new Date();
    const labels = [];
    const data = [];

    for (let i = days - 1; i >= 0; i--) {
        const date = new Date(now);
        date.setDate(date.getDate() - i);
        const dateStr = date.toISOString().split('T')[0];
        labels.push(date.toLocaleDateString('en-US', { month: 'short', day: 'numeric' }));

        const dayRevenue = transactions
            .filter(t => {
                const tDate = new Date(t.timestamp).toISOString().split('T')[0];
                return tDate === dateStr && (t.type === 'SALE_PAID' || t.type === 'PAYMENT_RECEIVED');
            })
            .reduce((sum, t) => sum + parseFloat(t.amount), 0);

        data.push(dayRevenue);
    }

    return { labels, data };
}

function calculateTransactionTypeData(transactions) {
    const counts = {
        SALE_PAID: 0,
        SALE_CREDIT: 0,
        PAYMENT_RECEIVED: 0
    };

    transactions.forEach(t => {
        if (counts.hasOwnProperty(t.type)) {
            counts[t.type]++;
        }
    });

    return {
        labels: ['Sale (Paid)', 'Sale (Credit)', 'Payment Received'],
        data: [counts.SALE_PAID, counts.SALE_CREDIT, counts.PAYMENT_RECEIVED],
        colors: ['#10b981', '#ef4444', '#3b82f6']
    };
}

function initializeRevenueChart(data) {
    const ctx = document.getElementById('revenueChart');
    if (!ctx) return;

    if (revenueChart) {
        revenueChart.destroy();
    }

    revenueChart = new Chart(ctx, {
        type: 'line',
        data: {
            labels: data.labels,
            datasets: [{
                label: 'Revenue (₹)',
                data: data.data,
                borderColor: '#667eea',
                backgroundColor: 'rgba(102, 126, 234, 0.1)',
                borderWidth: 3,
                fill: true,
                tension: 0.4,
                pointRadius: 4,
                pointHoverRadius: 6,
                pointBackgroundColor: '#667eea',
                pointBorderColor: '#fff',
                pointBorderWidth: 2
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    display: false
                },
                tooltip: {
                    backgroundColor: 'rgba(0, 0, 0, 0.8)',
                    padding: 12,
                    titleFont: { size: 14, weight: 'bold' },
                    bodyFont: { size: 13 },
                    callbacks: {
                        label: function(context) {
                            return 'Revenue: ₹' + context.parsed.y.toFixed(2);
                        }
                    }
                }
            },
            scales: {
                y: {
                    beginAtZero: true,
                    grid: {
                        color: 'rgba(0, 0, 0, 0.05)'
                    },
                    ticks: {
                        callback: function(value) {
                            return '₹' + value;
                        }
                    }
                },
                x: {
                    grid: {
                        display: false
                    }
                }
            }
        }
    });
}

function initializeTransactionTypeChart(data) {
    const ctx = document.getElementById('transactionTypeChart');
    if (!ctx) return;

    if (transactionTypeChart) {
        transactionTypeChart.destroy();
    }

    transactionTypeChart = new Chart(ctx, {
        type: 'doughnut',
        data: {
            labels: data.labels,
            datasets: [{
                data: data.data,
                backgroundColor: data.colors,
                borderWidth: 0,
                hoverOffset: 10
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    position: 'bottom',
                    labels: {
                        padding: 15,
                        font: { size: 12 },
                        usePointStyle: true
                    }
                },
                tooltip: {
                    backgroundColor: 'rgba(0, 0, 0, 0.8)',
                    padding: 12,
                    titleFont: { size: 14, weight: 'bold' },
                    bodyFont: { size: 13 }
                }
            }
        }
    });
}

async function updateRevenueChart() {
    const period = parseInt(document.getElementById('revenuePeriod').value);
    try {
        const response = await fetch(`${API_BASE}/transactions`, {
            headers: { 'X-User-Id': currentUser.userId }
        });
        const transactions = await response.json();
        const revenueData = calculateRevenueData(transactions, period);
        initializeRevenueChart(revenueData);
    } catch (error) {
        console.error('Error updating chart:', error);
    }
}

// Customers Functions
async function loadCustomers() {
    try {
        const response = await fetch(`${API_BASE}/customers`, {
            headers: { 'X-User-Id': currentUser.userId }
        });
        allCustomers = await response.json();
        displayCustomers(allCustomers);
    } catch (error) {
        console.error('Error loading customers:', error);
        showToast('Error loading customers', 'error');
    }
}

function displayCustomers(customers) {
    const tbody = document.getElementById('customersTableBody');
    
    if (!customers || customers.length === 0) {
        tbody.innerHTML = '<tr><td colspan="7" style="text-align: center; padding: 40px;">No customers yet</td></tr>';
        return;
    }
    
    tbody.innerHTML = customers.map(c => {
        const riskScore = calculateRiskScore(c);
        const riskBadge = getRiskBadge(riskScore);
        
        return `
        <tr>
            <td>
                <div style="display: flex; align-items: center; gap: 12px;">
                    <div class="avatar" style="width: 40px; height: 40px; font-size: 16px;">
                        ${c.name.charAt(0).toUpperCase()}
                    </div>
                    <strong>${c.name}</strong>
                </div>
            </td>
            <td>${c.mobile || '-'}</td>
            <td style="color: ${c.outstanding > 0 ? 'var(--danger)' : 'var(--success)'}; font-weight: 600;">₹${c.outstanding || 0}</td>
            <td>
                ${c.outstanding === 0 
                    ? '<span class="badge PAYMENT_RECEIVED">Cleared</span>' 
                    : '<span class="badge SALE_CREDIT">Pending</span>'}
            </td>
            <td>${riskBadge}</td>
            <td>${new Date(c.createdAt).toLocaleDateString()}</td>
            <td>
                <div class="table-actions">
                    <button class="action-icon" onclick="openEditCustomerModal(${c.id})" title="Edit Customer">
                        <i class="fas fa-edit"></i>
                    </button>
                    <button class="action-icon whatsapp-btn" onclick="sendWhatsAppReminder(${c.id})" title="Send WhatsApp Reminder">
                        <i class="fab fa-whatsapp"></i>
                    </button>
                </div>
            </td>
        </tr>
    `}).join('');
}

// Open edit customer modal
async function openEditCustomerModal(customerId) {
    try {
        // Find customer in allCustomers array
        const customer = allCustomers.find(c => c.id === customerId);
        
        if (!customer) {
            showToast('Customer not found', 'error');
            return;
        }
        
        // Populate form
        document.getElementById('editCustomerId').value = customer.id;
        document.getElementById('editCustomerName').value = customer.name;
        document.getElementById('editCustomerMobile').value = customer.mobile || '';
        document.getElementById('editCustomerCredit').textContent = '₹' + (customer.totalCredit || 0).toFixed(2);
        document.getElementById('editCustomerPayments').textContent = '₹' + (customer.totalPayments || 0).toFixed(2);
        document.getElementById('editCustomerOutstanding').textContent = '₹' + (customer.outstanding || 0).toFixed(2);
        
        // Show modal
        document.getElementById('editCustomerModal').classList.add('active');
        document.querySelector('.edit-customer-modal').classList.add('active');
        
        // Focus on name input
        setTimeout(() => {
            document.getElementById('editCustomerName').focus();
        }, 100);
        
    } catch (error) {
        console.error('Error opening edit modal:', error);
        showToast('Error opening edit form', 'error');
    }
}

// Close edit customer modal
function closeEditCustomerModal() {
    document.getElementById('editCustomerModal').classList.remove('active');
    document.querySelector('.edit-customer-modal').classList.remove('active');
}

// Save customer changes
async function saveCustomerChanges() {
    try {
        const customerId = document.getElementById('editCustomerId').value;
        const name = document.getElementById('editCustomerName').value.trim();
        const mobile = document.getElementById('editCustomerMobile').value.trim();
        
        // Validate
        if (!name) {
            showToast('Customer name is required', 'error');
            return;
        }
        
        if (mobile && (mobile.length !== 10 || !/^\d+$/.test(mobile))) {
            showToast('Mobile number must be 10 digits', 'error');
            return;
        }
        
        // Update customer
        const response = await fetch(`${API_BASE}/customers/${customerId}`, {
            method: 'PUT',
            headers: {
                'Content-Type': 'application/json',
                'X-User-Id': currentUser.userId
            },
            body: JSON.stringify({ name, mobile })
        });
        
        const data = await response.json();
        
        if (data.success) {
            showToast('Customer updated successfully!', 'success');
            closeEditCustomerModal();
            
            // Reload customers
            await loadCustomers();
        } else {
            showToast(data.message || 'Failed to update customer', 'error');
        }
        
    } catch (error) {
        console.error('Error saving customer:', error);
        showToast('Error updating customer', 'error');
    }
}

// Calculate customer risk score
function calculateRiskScore(customer) {
    if (customer.outstanding === 0) return 'low';
    
    const creditRatio = customer.totalCredit > 0 
        ? (customer.outstanding / customer.totalCredit) 
        : 0;
    
    if (creditRatio > 0.7) return 'high';
    if (creditRatio > 0.4) return 'medium';
    return 'low';
}

// Get risk badge HTML
function getRiskBadge(risk) {
    const badges = {
        low: '<span class="risk-badge low"><i class="fas fa-check-circle"></i> Low Risk</span>',
        medium: '<span class="risk-badge medium"><i class="fas fa-exclamation-circle"></i> Medium Risk</span>',
        high: '<span class="risk-badge high"><i class="fas fa-times-circle"></i> High Risk</span>'
    };
    return badges[risk] || badges.low;
}

function filterCustomers() {
    const search = document.getElementById('customerSearch').value.toLowerCase();
    const filtered = allCustomers.filter(c => 
        c.name.toLowerCase().includes(search) || 
        (c.mobile && c.mobile.includes(search))
    );
    displayCustomers(filtered);
}

// Transactions Functions
async function loadTransactions() {
    try {
        const response = await fetch(`${API_BASE}/transactions`, {
            headers: { 'X-User-Id': currentUser.userId }
        });
        allTransactions = await response.json();
        displayTransactions(allTransactions);
    } catch (error) {
        console.error('Error loading transactions:', error);
        showToast('Error loading transactions', 'error');
    }
}

function displayTransactions(transactions) {
    const tbody = document.getElementById('transactionsTableBody');
    
    if (!transactions || transactions.length === 0) {
        tbody.innerHTML = '<tr><td colspan="6" style="text-align: center; padding: 40px;">No transactions yet</td></tr>';
        return;
    }
    
    tbody.innerHTML = transactions.map(t => `
        <tr>
            <td>${new Date(t.timestamp).toLocaleString()}</td>
            <td><strong>${t.customerName || 'Unknown'}</strong></td>
            <td><span class="badge ${getTransactionBadgeClass(t.type)}">${getTransactionLabel(t.type)}</span></td>
            <td style="font-weight: 600; color: ${getTransactionColor(t.type)};">₹${t.amount}</td>
            <td style="max-width:200px; overflow:hidden; text-overflow:ellipsis;">${t.transcription || '-'}</td>
            <td>${t.audioFilePath ? `<button class="action-icon" onclick="playAudio('${t.audioFilePath}')"><i class="fas fa-play"></i></button>` : '-'}</td>
        </tr>
    `).join('');
}

function getTransactionBadgeClass(type) {
    switch(type) {
        case 'SALE_PAID': return 'success';
        case 'SALE_CREDIT': return 'danger';
        case 'PAYMENT_RECEIVED': return 'info';
        // Backward compatibility
        case 'CREDIT': return 'danger';
        case 'PAYMENT': return 'info';
        default: return 'secondary';
    }
}

function getTransactionLabel(type) {
    switch(type) {
        case 'SALE_PAID': return '🟢 Sale (Paid)';
        case 'SALE_CREDIT': return '🔴 Sale (Credit)';
        case 'PAYMENT_RECEIVED': return '🔵 Payment';
        // Backward compatibility
        case 'CREDIT': return '🔴 Credit';
        case 'PAYMENT': return '🔵 Payment';
        default: return type;
    }
}

function getTransactionColor(type) {
    switch(type) {
        case 'SALE_PAID': return 'var(--success)';
        case 'SALE_CREDIT': return 'var(--danger)';
        case 'PAYMENT_RECEIVED': return 'var(--info)';
        case 'CREDIT': return 'var(--danger)';
        case 'PAYMENT': return 'var(--info)';
        default: return 'var(--text-primary)';
    }
}

function filterTransactions() {
    const typeFilter = document.getElementById('transactionTypeFilter').value;
    
    const filtered = allTransactions.filter(t => {
        const matchesType = !typeFilter || t.type === typeFilter;
        return matchesType;
    });
    
    displayTransactions(filtered);
}

function playAudio(audioPath) {
    if (!audioPath) return;
    const audioUrl = `${API_BASE}/audio/${audioPath}`;
    const audio = new Audio(audioUrl);
    audio.play().catch(err => {
        showToast('Error playing audio: ' + err.message, 'error');
    });
}

// Utility Functions
function logout() {
    if (confirm('Are you sure you want to logout?')) {
        localStorage.removeItem('userId');
        localStorage.removeItem('shopName');
        localStorage.removeItem('mobile');
        localStorage.removeItem('language');
        window.location.href = 'login-pro.html';
    }
}

function toggleSidebar() {
    document.getElementById('sidebar').classList.toggle('active');
}

function toggleTheme() {
    document.body.classList.toggle('dark-mode');
    const icon = document.getElementById('themeIcon');
    if (document.body.classList.contains('dark-mode')) {
        icon.className = 'fas fa-sun';
        localStorage.setItem('theme', 'dark');
    } else {
        icon.className = 'fas fa-moon';
        localStorage.setItem('theme', 'light');
    }
}

function loadThemePreference() {
    const theme = localStorage.getItem('theme');
    if (theme === 'dark') {
        document.body.classList.add('dark-mode');
        document.getElementById('themeIcon').className = 'fas fa-sun';
    }
}

function showToast(message, type = 'success') {
    const toast = document.getElementById('toast');
    const toastMessage = document.getElementById('toastMessage');
    const icon = toast.querySelector('i');
    
    toastMessage.textContent = message;
    
    if (type === 'error') {
        icon.className = 'fas fa-times-circle';
        icon.style.color = 'var(--danger)';
    } else {
        icon.className = 'fas fa-check-circle';
        icon.style.color = 'var(--success)';
        
        // Trigger confetti for success
        if (type === 'success') {
            triggerConfetti();
        }
    }
    
    toast.classList.add('show');
    
    setTimeout(() => {
        toast.classList.remove('show');
    }, 3000);
}

// Confetti Effect
function triggerConfetti() {
    const colors = ['#667eea', '#764ba2', '#10b981', '#f59e0b', '#ef4444', '#3b82f6'];
    const confettiCount = 50;
    
    for (let i = 0; i < confettiCount; i++) {
        setTimeout(() => {
            const confetti = document.createElement('div');
            confetti.className = 'confetti';
            confetti.style.left = Math.random() * 100 + 'vw';
            confetti.style.background = colors[Math.floor(Math.random() * colors.length)];
            confetti.style.animationDelay = Math.random() * 0.5 + 's';
            confetti.style.animationDuration = (Math.random() * 2 + 2) + 's';
            document.body.appendChild(confetti);
            
            setTimeout(() => confetti.remove(), 3000);
        }, i * 30);
    }
}

// Format helpers
function formatTimeAgo(timestamp) {
    const now = new Date();
    const then = new Date(timestamp);
    const seconds = Math.floor((now - then) / 1000);
    
    if (seconds < 60) return 'Just now';
    if (seconds < 3600) return Math.floor(seconds / 60) + 'm ago';
    if (seconds < 86400) return Math.floor(seconds / 3600) + 'h ago';
    return Math.floor(seconds / 86400) + 'd ago';
}

console.log('App script loaded');

// Language Toggle Feature
let currentLanguage = 'en';
const translations = {
    en: {
        dashboard: 'Dashboard',
        'voice-entry': 'Voice Entry',
        customers: 'Customers',
        transactions: 'Transactions',
        passbook: 'Passbook',
        'total-customers': 'Total Customers',
        'total-credit': 'Total Credit Given',
        'total-payment': 'Total Payments Received',
        'outstanding-balance': 'Outstanding Balance',
        customer: 'Customer',
        mobile: 'Mobile',
        outstanding: 'Outstanding',
        status: 'Status',
        'risk-score': 'Risk Score',
        created: 'Created',
        actions: 'Actions',
        'date-time': 'Date & Time',
        type: 'Type',
        amount: 'Amount',
        transcription: 'Transcription',
        audio: 'Audio',
        whatsapp: 'WhatsApp'
    },
    hi: {
        dashboard: 'डैशबोर्ड',
        'voice-entry': 'आवाज़ प्रविष्टि',
        customers: 'ग्राहक',
        transactions: 'लेन-देन',
        passbook: 'पासबुक',
        'total-customers': 'कुल ग्राहक',
        'total-credit': 'कुल उधार दिया',
        'total-payment': 'कुल भुगतान प्राप्त',
        'outstanding-balance': 'बकाया राशि',
        customer: 'ग्राहक',
        mobile: 'मोबाइल',
        outstanding: 'बकाया',
        status: 'स्थिति',
        'risk-score': 'जोखिम स्कोर',
        created: 'बनाया गया',
        actions: 'कार्रवाई',
        'date-time': 'तारीख और समय',
        type: 'प्रकार',
        amount: 'राशि',
        transcription: 'प्रतिलेखन',
        audio: 'ऑडियो',
        whatsapp: 'व्हाट्सएप'
    }
};

function toggleLanguage() {
    currentLanguage = currentLanguage === 'en' ? 'hi' : 'en';
    const icon = document.getElementById('languageIcon');
    icon.textContent = currentLanguage === 'en' ? 'A' : 'अ';
    
    // Translate all elements with data-translate attribute
    document.querySelectorAll('[data-translate]').forEach(element => {
        const key = element.getAttribute('data-translate');
        if (translations[currentLanguage][key]) {
            element.textContent = translations[currentLanguage][key];
        }
    });
    
    // Translate stat labels
    const statLabels = document.querySelectorAll('.stat-label');
    statLabels.forEach(label => {
        const key = label.textContent.toLowerCase().replace(/ /g, '-');
        if (translations[currentLanguage][key]) {
            label.textContent = translations[currentLanguage][key];
        }
    });
    
    showToast(`Language switched to ${currentLanguage === 'en' ? 'English' : 'हिंदी'}`, 'success');
}

// Manual Entry Modal Functions
function openManualEntryModal() {
    console.log('Opening manual entry modal...');
    const overlay = document.getElementById('manualEntryModal');
    if (!overlay) {
        console.error('Manual entry modal not found!');
        return;
    }
    const modal = overlay.querySelector('.modal');
    if (!modal) {
        console.error('Modal element not found inside overlay!');
        return;
    }
    overlay.classList.add('active');
    modal.classList.add('active');
    console.log('Modal opened successfully');
    setTimeout(() => {
        const nameInput = document.getElementById('manualCustomerName');
        if (nameInput) {
            nameInput.focus();
        }
    }, 100);
}

function closeManualEntryModal() {
    console.log('Closing manual entry modal...');
    const overlay = document.getElementById('manualEntryModal');
    if (!overlay) return;
    const modal = overlay.querySelector('.modal');
    if (!modal) return;
    overlay.classList.remove('active');
    modal.classList.remove('active');
    const form = document.getElementById('manualEntryForm');
    if (form) {
        form.reset();
    }
    console.log('Modal closed successfully');
}

// Make functions globally accessible
window.openManualEntryModal = openManualEntryModal;
window.closeManualEntryModal = closeManualEntryModal;

async function saveManualEntry() {
    console.log('Saving manual entry...');
    const name = document.getElementById('manualCustomerName').value.trim();
    const amount = parseFloat(document.getElementById('manualAmount').value);
    const type = document.getElementById('manualType').value;
    const notes = document.getElementById('manualNotes').value.trim();
    
    console.log('Form values:', { name, amount, type, notes });
    
    if (!name || !amount || !type) {
        console.error('Validation failed:', { name, amount, type });
        showToast('Please fill all required fields', 'error');
        return;
    }
    
    if (!currentUser || !currentUser.userId) {
        console.error('No current user found!');
        showToast('User not logged in', 'error');
        return;
    }
    
    try {
        console.log('Sending request to:', `${API_BASE}/transactions/log`);
        const response = await fetch(`${API_BASE}/transactions/log`, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-User-Id': currentUser.userId
            },
            body: JSON.stringify({
                name: name,
                amount: amount,
                type: type,
                confidence: 1.0,
                transcription: notes || `Manual entry: ${name} - ₹${amount}`,
                audioData: null
            })
        });

        console.log('Response status:', response.status);
        const result = await response.json();
        console.log('Response data:', result);

        if (result.success) {
            showToast('Transaction recorded successfully!', 'success');
            closeManualEntryModal();
            
            // Reload data if on relevant pages
            const activePage = document.querySelector('.page.active');
            if (activePage) {
                const pageId = activePage.id;
                console.log('Active page:', pageId);
                if (pageId === 'dashboard-page') loadDashboard();
                if (pageId === 'transactions-page') loadTransactions();
                if (pageId === 'customers-page') loadCustomers();
            }
        } else {
            showToast(result.message || 'Failed to record transaction', 'error');
        }
    } catch (error) {
        console.error('Error saving manual entry:', error);
        showToast('Error recording transaction: ' + error.message, 'error');
    }
}

// Make function globally accessible
window.saveManualEntry = saveManualEntry;

function sendWhatsAppReminder(customerId) {
    // Simulated WhatsApp reminder
    showToast('WhatsApp reminder sent successfully!', 'success');
    console.log('Sending WhatsApp reminder to customer:', customerId);
}

// Enhanced display function for transactions
function displayTransactionsEnhanced(transactions) {
    const tbody = document.getElementById('transactionsTableBody');
    
    if (!transactions || transactions.length === 0) {
        tbody.innerHTML = '<tr><td colspan="6" style="text-align: center; padding: 40px;">No transactions yet</td></tr>';
        return;
    }
    
    tbody.innerHTML = transactions.map(t => {
        const hasLowConfidence = t.confidence && t.confidence < 0.7;
        
        return `
        <tr>
            <td>${new Date(t.timestamp).toLocaleString()}</td>
            <td><strong>${t.customerName || 'Unknown'}</strong></td>
            <td><span class="badge ${getTransactionBadgeClass(t.type)}">${getTransactionLabel(t.type)}</span></td>
            <td style="font-weight: 600; color: ${getTransactionColor(t.type)};">₹${t.amount}</td>
            <td style="max-width:200px; overflow:hidden; text-overflow:ellipsis;">
                ${hasLowConfidence ? '<i class="fas fa-exclamation-triangle" style="color: #f59e0b;" title="Low confidence - verify"></i> ' : ''}
                ${t.transcription || '-'}
            </td>
            <td>${t.audioFilePath ? `<button class="action-icon" onclick="playAudio('${t.audioFilePath}')"><i class="fas fa-play"></i></button>` : '-'}</td>
        </tr>
    `}).join('');
}

// Override the original display functions
window.displayTransactions = displayTransactionsEnhanced;


// ==================== PASSBOOK FUNCTIONS ====================

// Passbook Functions
async function loadPassbook() {
    try {
        const period = document.getElementById('passbookPeriod').value;
        const customDateRange = document.getElementById('customDateRange');
        
        // Show/hide custom date range
        if (period === 'custom') {
            customDateRange.style.display = 'block';
        } else {
            customDateRange.style.display = 'none';
        }
        
        // Get date range
        const { fromDate, toDate, periodTitle } = getDateRange(period);
        document.getElementById('periodTitle').textContent = periodTitle;
        
        // Fetch transactions
        const response = await fetch(`${API_BASE}/transactions`, {
            headers: { 'X-User-Id': currentUser.userId }
        });
        const allTransactions = await response.json();
        
        // Filter transactions by date range
        const filteredTransactions = allTransactions.filter(t => {
            const tDate = new Date(t.timestamp);
            return tDate >= fromDate && tDate <= toDate;
        });
        
        // Calculate statistics
        const stats = calculatePassbookStats(filteredTransactions);
        
        // Update UI
        updatePassbookSummary(stats);
        displayPassbookLedger(filteredTransactions);
        
    } catch (error) {
        console.error('Error loading passbook:', error);
        showToast('Error loading passbook', 'error');
    }
}

function getDateRange(period) {
    const now = new Date();
    let fromDate, toDate, periodTitle;
    
    switch(period) {
        case 'today':
            fromDate = new Date(now.setHours(0, 0, 0, 0));
            toDate = new Date(now.setHours(23, 59, 59, 999));
            periodTitle = 'Today';
            break;
            
        case 'week':
            fromDate = new Date(now.setDate(now.getDate() - 7));
            fromDate.setHours(0, 0, 0, 0);
            toDate = new Date();
            toDate.setHours(23, 59, 59, 999);
            periodTitle = 'Last 7 Days';
            break;
            
        case 'month':
            fromDate = new Date(now.getFullYear(), now.getMonth(), 1);
            toDate = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59, 999);
            periodTitle = 'This Month';
            break;
            
        case 'year':
            fromDate = new Date(now.getFullYear(), 0, 1);
            toDate = new Date(now.getFullYear(), 11, 31, 23, 59, 59, 999);
            periodTitle = 'This Year';
            break;
            
        case 'custom':
            const customFrom = document.getElementById('customFromDate').value;
            const customTo = document.getElementById('customToDate').value;
            
            if (!customFrom || !customTo) {
                fromDate = new Date(now.getFullYear(), now.getMonth(), 1);
                toDate = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59, 999);
                periodTitle = 'This Month';
            } else {
                fromDate = new Date(customFrom);
                fromDate.setHours(0, 0, 0, 0);
                toDate = new Date(customTo);
                toDate.setHours(23, 59, 59, 999);
                periodTitle = `${customFrom} to ${customTo}`;
            }
            break;
            
        default:
            fromDate = new Date(now.getFullYear(), now.getMonth(), 1);
            toDate = new Date(now.getFullYear(), now.getMonth() + 1, 0, 23, 59, 59, 999);
            periodTitle = 'This Month';
    }
    
    return { fromDate, toDate, periodTitle };
}

function calculatePassbookStats(transactions) {
    let totalIncome = 0;
    let totalCredit = 0;
    let totalPayments = 0;
    
    let salePaidCount = 0;
    let salePaidAmount = 0;
    let saleCreditCount = 0;
    let saleCreditAmount = 0;
    let paymentReceivedCount = 0;
    let paymentReceivedAmount = 0;
    
    transactions.forEach(t => {
        const amount = parseFloat(t.amount);
        
        switch(t.type) {
            case 'SALE_PAID':
                totalIncome += amount;
                salePaidCount++;
                salePaidAmount += amount;
                break;
                
            case 'SALE_CREDIT':
                totalCredit += amount;
                saleCreditCount++;
                saleCreditAmount += amount;
                break;
                
            case 'PAYMENT_RECEIVED':
                totalIncome += amount;
                totalPayments += amount;
                paymentReceivedCount++;
                paymentReceivedAmount += amount;
                break;
        }
    });
    
    const netChange = totalPayments - totalCredit;
    
    return {
        totalIncome,
        totalCredit,
        totalPayments,
        netChange,
        totalTransactions: transactions.length,
        salePaidCount,
        salePaidAmount,
        saleCreditCount,
        saleCreditAmount,
        paymentReceivedCount,
        paymentReceivedAmount
    };
}

function updatePassbookSummary(stats) {
    // Update three-pillar cards
    document.getElementById('passbookIncome').textContent = '₹' + stats.totalIncome.toFixed(2);
    document.getElementById('passbookCredit').textContent = '₹' + stats.totalCredit.toFixed(2);
    document.getElementById('passbookChange').textContent = '₹' + Math.abs(stats.netChange).toFixed(2);
    
    // Update change description
    const changeDesc = document.getElementById('passbookChangeDesc');
    if (stats.netChange > 0) {
        changeDesc.textContent = 'More payments received ✓';
        changeDesc.style.color = 'var(--success)';
    } else if (stats.netChange < 0) {
        changeDesc.textContent = 'More credit given';
        changeDesc.style.color = 'var(--danger)';
    } else {
        changeDesc.textContent = 'Balanced';
        changeDesc.style.color = 'var(--text-tertiary)';
    }
    
    // Update summary grid
    document.getElementById('totalTransactions').textContent = stats.totalTransactions;
    document.getElementById('salePaidCount').textContent = `${stats.salePaidCount} (₹${stats.salePaidAmount.toFixed(2)})`;
    document.getElementById('saleCreditCount').textContent = `${stats.saleCreditCount} (₹${stats.saleCreditAmount.toFixed(2)})`;
    document.getElementById('paymentReceivedCount').textContent = `${stats.paymentReceivedCount} (₹${stats.paymentReceivedAmount.toFixed(2)})`;
}

function displayPassbookLedger(transactions) {
    const tbody = document.getElementById('passbookTableBody');
    
    if (!transactions || transactions.length === 0) {
        tbody.innerHTML = '<tr><td colspan="5" style="text-align: center; padding: 40px; color: var(--text-secondary);">No transactions in this period</td></tr>';
        return;
    }
    
    // Sort by date (newest first)
    const sortedTransactions = [...transactions].sort((a, b) => 
        new Date(b.timestamp) - new Date(a.timestamp)
    );
    
    tbody.innerHTML = sortedTransactions.map(t => {
        let rowClass = '';
        if (t.type === 'SALE_PAID' || t.type === 'PAYMENT_RECEIVED') {
            rowClass = 'income-row';
        } else if (t.type === 'SALE_CREDIT') {
            rowClass = 'credit-row';
        }
        
        return `
        <tr class="${rowClass}">
            <td style="font-weight: 500;">${new Date(t.timestamp).toLocaleString('en-IN', { 
                day: '2-digit', 
                month: 'short', 
                year: 'numeric',
                hour: '2-digit',
                minute: '2-digit'
            })}</td>
            <td><strong>${t.customerName || 'Unknown'}</strong></td>
            <td><span class="badge ${getTransactionBadgeClass(t.type)}">${getTransactionLabel(t.type)}</span></td>
            <td style="font-weight: 700; font-size: 16px; color: ${getTransactionColor(t.type)};">₹${parseFloat(t.amount).toFixed(2)}</td>
            <td style="color: var(--text-secondary); font-size: 13px;">${t.transcription || '-'}</td>
        </tr>
    `}).join('');
}

// PDF Download Function
async function downloadPassbookPDF() {
    try {
        showToast('Generating PDF...', 'success');
        
        const period = document.getElementById('passbookPeriod').value;
        const { fromDate, toDate, periodTitle } = getDateRange(period);
        
        // Fetch transactions
        const response = await fetch(`${API_BASE}/transactions`, {
            headers: { 'X-User-Id': currentUser.userId }
        });
        const allTransactions = await response.json();
        
        // Filter transactions
        const filteredTransactions = allTransactions.filter(t => {
            const tDate = new Date(t.timestamp);
            return tDate >= fromDate && tDate <= toDate;
        });
        
        // Calculate stats
        const stats = calculatePassbookStats(filteredTransactions);
        
        // Generate PDF content
        generatePDF(periodTitle, stats, filteredTransactions);
        
    } catch (error) {
        console.error('Error generating PDF:', error);
        showToast('Error generating PDF', 'error');
    }
}

function generatePDF(periodTitle, stats, transactions) {
    // Create a printable HTML document
    const printWindow = window.open('', '_blank');
    
    const htmlContent = `
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <title>Vyapar Passbook - ${currentUser.shopName}</title>
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body {
                font-family: 'Arial', sans-serif;
                padding: 40px;
                background: white;
                color: #000;
            }
            .header {
                text-align: center;
                margin-bottom: 30px;
                border-bottom: 3px solid #6366f1;
                padding-bottom: 20px;
            }
            .header h1 {
                font-size: 28px;
                color: #6366f1;
                margin-bottom: 5px;
            }
            .header h2 {
                font-size: 20px;
                color: #333;
                margin-bottom: 10px;
            }
            .header p {
                font-size: 14px;
                color: #666;
            }
            .summary-cards {
                display: grid;
                grid-template-columns: repeat(3, 1fr);
                gap: 20px;
                margin: 30px 0;
            }
            .card {
                border: 2px solid #e5e7eb;
                border-radius: 10px;
                padding: 20px;
                text-align: center;
            }
            .card.income { border-color: #10b981; background: #f0fdf4; }
            .card.credit { border-color: #ef4444; background: #fef2f2; }
            .card.change { border-color: #3b82f6; background: #eff6ff; }
            .card h3 {
                font-size: 12px;
                color: #666;
                text-transform: uppercase;
                margin-bottom: 10px;
                letter-spacing: 1px;
            }
            .card .amount {
                font-size: 32px;
                font-weight: bold;
                margin-bottom: 5px;
            }
            .card.income .amount { color: #10b981; }
            .card.credit .amount { color: #ef4444; }
            .card.change .amount { color: #3b82f6; }
            .card p {
                font-size: 11px;
                color: #999;
            }
            .summary-section {
                margin: 30px 0;
                padding: 20px;
                background: #f9fafb;
                border-radius: 10px;
            }
            .summary-section h3 {
                font-size: 16px;
                margin-bottom: 15px;
                color: #333;
            }
            .summary-grid {
                display: grid;
                grid-template-columns: repeat(2, 1fr);
                gap: 10px;
            }
            .summary-item {
                display: flex;
                justify-content: space-between;
                padding: 10px;
                background: white;
                border-radius: 5px;
                font-size: 13px;
            }
            .summary-item .label { color: #666; }
            .summary-item .value { font-weight: bold; color: #000; }
            table {
                width: 100%;
                border-collapse: collapse;
                margin-top: 20px;
            }
            table thead {
                background: #6366f1;
                color: white;
            }
            table th {
                padding: 12px;
                text-align: left;
                font-size: 12px;
                text-transform: uppercase;
                letter-spacing: 0.5px;
            }
            table td {
                padding: 10px 12px;
                border-bottom: 1px solid #e5e7eb;
                font-size: 13px;
            }
            table tbody tr:hover {
                background: #f9fafb;
            }
            .income-row { border-left: 4px solid #10b981; }
            .credit-row { border-left: 4px solid #ef4444; }
            .payment-row { border-left: 4px solid #3b82f6; }
            .badge {
                padding: 4px 10px;
                border-radius: 12px;
                font-size: 11px;
                font-weight: bold;
                text-transform: uppercase;
            }
            .badge.green { background: #d1fae5; color: #065f46; }
            .badge.red { background: #fee2e2; color: #991b1b; }
            .badge.blue { background: #dbeafe; color: #1e40af; }
            .footer {
                margin-top: 40px;
                padding-top: 20px;
                border-top: 2px solid #e5e7eb;
                text-align: center;
                font-size: 12px;
                color: #999;
            }
            @media print {
                body { padding: 20px; }
                .no-print { display: none; }
            }
        </style>
    </head>
    <body>
        <div class="header">
            <h1>🏪 ${currentUser.shopName || 'Shop Name'}</h1>
            <h2>Vyapar Passbook</h2>
            <p><strong>Period:</strong> ${periodTitle} | <strong>Generated:</strong> ${new Date().toLocaleString('en-IN')}</p>
        </div>
        
        <div class="summary-cards">
            <div class="card income">
                <h3>Total Shop Income</h3>
                <div class="amount">₹${stats.totalIncome.toFixed(2)}</div>
                <p>Cash in Hand (Realized)</p>
            </div>
            <div class="card credit">
                <h3>Total Credit Given</h3>
                <div class="amount">₹${stats.totalCredit.toFixed(2)}</div>
                <p>New Udhaar Given</p>
            </div>
            <div class="card change">
                <h3>Net Outstanding Change</h3>
                <div class="amount">₹${Math.abs(stats.netChange).toFixed(2)}</div>
                <p>${stats.netChange >= 0 ? 'More Payments Received' : 'More Credit Given'}</p>
            </div>
        </div>
        
        <div class="summary-section">
            <h3>📊 Transaction Summary</h3>
            <div class="summary-grid">
                <div class="summary-item">
                    <span class="label">Total Transactions:</span>
                    <span class="value">${stats.totalTransactions}</span>
                </div>
                <div class="summary-item">
                    <span class="label">Sale (Paid):</span>
                    <span class="value">${stats.salePaidCount} (₹${stats.salePaidAmount.toFixed(2)})</span>
                </div>
                <div class="summary-item">
                    <span class="label">Sale (Credit):</span>
                    <span class="value">${stats.saleCreditCount} (₹${stats.saleCreditAmount.toFixed(2)})</span>
                </div>
                <div class="summary-item">
                    <span class="label">Payments Received:</span>
                    <span class="value">${stats.paymentReceivedCount} (₹${stats.paymentReceivedAmount.toFixed(2)})</span>
                </div>
            </div>
        </div>
        
        <h3 style="margin-top: 30px; margin-bottom: 10px; color: #333;">📋 Transaction Ledger</h3>
        <table>
            <thead>
                <tr>
                    <th>Date & Time</th>
                    <th>Customer</th>
                    <th>Type</th>
                    <th>Amount</th>
                    <th>Description</th>
                </tr>
            </thead>
            <tbody>
                ${transactions.length === 0 ? '<tr><td colspan="5" style="text-align: center; padding: 20px; color: #999;">No transactions in this period</td></tr>' : 
                    transactions.sort((a, b) => new Date(b.timestamp) - new Date(a.timestamp)).map(t => {
                        let rowClass = '';
                        let badgeClass = '';
                        let typeLabel = '';
                        
                        if (t.type === 'SALE_PAID') {
                            rowClass = 'income-row';
                            badgeClass = 'green';
                            typeLabel = 'Sale (Paid)';
                        } else if (t.type === 'SALE_CREDIT') {
                            rowClass = 'credit-row';
                            badgeClass = 'red';
                            typeLabel = 'Sale (Credit)';
                        } else if (t.type === 'PAYMENT_RECEIVED') {
                            rowClass = 'payment-row';
                            badgeClass = 'blue';
                            typeLabel = 'Payment';
                        }
                        
                        return `
                        <tr class="${rowClass}">
                            <td>${new Date(t.timestamp).toLocaleString('en-IN', { 
                                day: '2-digit', 
                                month: 'short', 
                                year: 'numeric',
                                hour: '2-digit',
                                minute: '2-digit'
                            })}</td>
                            <td><strong>${t.customerName || 'Unknown'}</strong></td>
                            <td><span class="badge ${badgeClass}">${typeLabel}</span></td>
                            <td style="font-weight: bold;">₹${parseFloat(t.amount).toFixed(2)}</td>
                            <td>${t.transcription || '-'}</td>
                        </tr>
                        `;
                    }).join('')
                }
            </tbody>
        </table>
        
        <div class="footer">
            <p>Generated by Bol-Khata - Voice Financial Ledger</p>
            <p>This is a computer-generated document. No signature required.</p>
        </div>
        
        <div class="no-print" style="margin-top: 30px; text-align: center;">
            <button onclick="window.print()" style="padding: 12px 30px; background: #6366f1; color: white; border: none; border-radius: 8px; font-size: 16px; cursor: pointer; font-weight: bold;">
                🖨️ Print / Save as PDF
            </button>
            <button onclick="window.close()" style="padding: 12px 30px; background: #6b7280; color: white; border: none; border-radius: 8px; font-size: 16px; cursor: pointer; font-weight: bold; margin-left: 10px;">
                ✕ Close
            </button>
        </div>
    </body>
    </html>
    `;
    
    printWindow.document.write(htmlContent);
    printWindow.document.close();
    
    showToast('PDF ready! Click Print to save', 'success');
}

console.log('Passbook functions loaded');

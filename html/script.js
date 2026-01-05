/*
 * RSG-Pets Enhanced - Wild West Edition
 * NUI JavaScript
 */

// State
const RESOURCE_NAME = GetParentResourceName();
let currentCategory = 'dog';
let pets = [];
let selectedPet = null;
let playerMoney = 0;

// DOM Elements
const shopContainer = document.getElementById('shop-container');
const petsGrid = document.getElementById('pets-grid');
const playerCash = document.getElementById('player-cash');
const confirmModal = document.getElementById('confirm-modal');
const modalPetImage = document.getElementById('modal-pet-image');
const modalPetName = document.getElementById('modal-pet-name');
const modalPetPrice = document.getElementById('modal-pet-price');

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    setupEventListeners();
});

// Event Listeners
function setupEventListeners() {
    // Category tabs
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.addEventListener('click', () => {
            const category = btn.dataset.category;
            setActiveCategory(category);
        });
    });

    // Close button
    document.getElementById('close-btn').addEventListener('click', closeShop);

    // Modal buttons
    document.getElementById('confirm-yes').addEventListener('click', confirmPurchase);
    document.getElementById('confirm-no').addEventListener('click', closeModal);
    document.querySelector('.modal-backdrop').addEventListener('click', closeModal);

    // Escape key to close
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            if (!confirmModal.classList.contains('hidden')) {
                closeModal();
            } else if (!shopContainer.classList.contains('hidden')) {
                closeShop();
            }
        }
    });
}

// NUI Message Handler
window.addEventListener('message', (event) => {
    const data = event.data;

    switch (data.action) {
        case 'openShop':
            openShop(data.pets, data.money);
            break;
        case 'closeShop':
            hideShop();
            break;
        case 'updateMoney':
            updateMoney(data.money);
            break;
        case 'purchaseResult':
            handlePurchaseResult(data.success, data.message);
            break;
        case 'showPetStatus':
            showPetStatus(data);
            break;
        case 'closePetStatus':
            closePetStatus();
            break;
        case 'showFeedMenu':
            showFeedMenu(data);
            break;
        case 'closeFeedMenu':
            closeFeedMenu();
            break;
        case 'showProgressBar':
            showProgressBar(data);
            break;
        case 'cancelProgressBar':
            cancelProgressBar();
            break;
    }
});

// Shop Functions
function openShop(petData, money) {
    pets = petData || [];
    playerMoney = money || 0;

    updateMoney(playerMoney);
    setActiveCategory('dog');
    shopContainer.classList.remove('hidden');

    // Focus for keyboard events
    document.body.focus();
}

function hideShop() {
    shopContainer.classList.add('hidden');
    closeModal();
}

function closeShop() {
    hideShop();

    // Send close message to client
    fetch('https://${RESOURCE_NAME}/closeShop', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
}

function updateMoney(amount) {
    playerMoney = amount;
    playerCash.textContent = '$' + formatMoney(amount);
}

function formatMoney(amount) {
    return parseFloat(amount).toFixed(2).replace(/\B(?=(\d{3})+(?!\d))/g, ",");
}

// Category Functions
function setActiveCategory(category) {
    currentCategory = category;

    // Update tab buttons
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.classList.toggle('active', btn.dataset.category === category);
    });

    // Render filtered pets
    renderPets();
}

// Render Functions
function renderPets() {
    const filteredPets = pets.filter(pet => pet.type === currentCategory);

    petsGrid.innerHTML = '';

    if (filteredPets.length === 0) {
        petsGrid.innerHTML = `
            <div class="no-pets" style="grid-column: 1 / -1; text-align: center; padding: 40px; color: #8b4513; font-family: 'Playfair Display', serif; font-style: italic;">
                No ${currentCategory === 'dog' ? 'hounds' : 'felines'} available at this time, partner.
            </div>
        `;
        return;
    }

    filteredPets.forEach(pet => {
        const card = createPetCard(pet);
        petsGrid.appendChild(card);
    });
}

function createPetCard(pet) {
    const card = document.createElement('div');
    card.className = 'pet-card';
    card.innerHTML = `
        <div class="pet-image-container">
            <img class="pet-image" src="nui://rsg-inventory/html/images/${pet.image}" alt="${pet.label}" 
                 onerror="this.src='data:image/svg+xml,<svg xmlns=%22http://www.w3.org/2000/svg%22 width=%22100%22 height=%22100%22><rect fill=%22%23e8d4a8%22 width=%22100%22 height=%22100%22/><text x=%2250%22 y=%2255%22 text-anchor=%22middle%22 fill=%22%238b4513%22 font-size=%2240%22>${pet.type === 'dog' ? '🐕' : '🐈'}</text></svg>'">
        </div>
        <div class="pet-info">
            <h3 class="pet-name">${pet.label}</h3>
            <p class="pet-description">${pet.description}</p>
            <div class="pet-price">${pet.price}</div>
            <button class="buy-btn" data-pet="${pet.name}">Purchase</button>
        </div>
    `;

    // Add click handler for buy button
    card.querySelector('.buy-btn').addEventListener('click', () => {
        showPurchaseModal(pet);
    });

    return card;
}

// Modal Functions
function showPurchaseModal(pet) {
    selectedPet = pet;

    modalPetImage.src = `nui://rsg-inventory/html/images/${pet.image}`;
    modalPetImage.onerror = function () {
        this.src = `data:image/svg+xml,<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100"><rect fill="#e8d4a8" width="100" height="100"/><text x="50" y="55" text-anchor="middle" fill="#8b4513" font-size="40">${pet.type === 'dog' ? '🐕' : '🐈'}</text></svg>`;
    };
    modalPetName.textContent = pet.label;
    modalPetPrice.textContent = '$' + formatMoney(pet.price);

    confirmModal.classList.remove('hidden');
}

function closeModal() {
    confirmModal.classList.add('hidden');
    selectedPet = null;
}

function confirmPurchase() {
    if (!selectedPet) return;

    // Check if player has enough money
    if (playerMoney < selectedPet.price) {
        // Show error feedback
        const confirmBtn = document.getElementById('confirm-yes');
        confirmBtn.style.background = 'linear-gradient(180deg, #8b3a3a 0%, #6b2a2a 100%)';
        confirmBtn.innerHTML = '<span>Not Enough Money!</span>';

        setTimeout(() => {
            confirmBtn.style.background = '';
            confirmBtn.innerHTML = '<span>🤝 Purchase</span>';
        }, 2000);

        return;
    }

    // Send purchase request to client
    fetch('https://${RESOURCE_NAME}/purchasePet', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
            petName: selectedPet.name,
            petLabel: selectedPet.label,
            price: selectedPet.price
        })
    });

    closeModal();
}

function handlePurchaseResult(success, message) {
    if (success) {
        // Update displayed money after purchase
        // The actual update will come from updateMoney call
    }
    // Could add a toast notification here if desired
}

// =========================================
// PET STATUS PANEL
// =========================================
const statusContainer = document.getElementById('pet-status-container');
const statusPetName = document.getElementById('status-pet-name');
const lifespanBar = document.getElementById('lifespan-bar');
const lifespanText = document.getElementById('lifespan-text');
const healthBar = document.getElementById('health-bar');
const healthText = document.getElementById('health-text');
const hungerBar = document.getElementById('hunger-bar');
const hungerText = document.getElementById('hunger-text');
const statusTip = document.getElementById('status-tip');

// Status panel event listeners
document.getElementById('status-close-btn').addEventListener('click', closePetStatus);

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && !statusContainer.classList.contains('hidden')) {
        closePetStatus();
    }
});

function showPetStatus(data) {
    statusPetName.textContent = data.name || 'Pet';

    // Calculate lifespan percentage and remaining days
    const lifespanPercent = Math.max(0, Math.min(100, data.lifespan || 100));
    const daysRemaining = Math.ceil((data.lifespanSeconds || 0) / 86400);
    lifespanBar.style.width = lifespanPercent + '%';
    lifespanText.textContent = daysRemaining + ' days';

    // Health
    const healthPercent = Math.max(0, Math.min(100, data.health || 100));
    healthBar.style.width = healthPercent + '%';
    healthText.textContent = Math.round(healthPercent) + '%';

    // Hunger
    const hungerPercent = Math.max(0, Math.min(100, data.hunger || 100));
    hungerBar.style.width = hungerPercent + '%';
    hungerText.textContent = Math.round(hungerPercent) + '%';

    // Dynamic tip based on stats
    if (lifespanPercent < 20) {
        statusTip.textContent = "⚠️ Your companion's time is running short...";
    } else if (hungerPercent < 30) {
        statusTip.textContent = "🍖 Your pet is hungry! Feed them soon!";
    } else if (healthPercent < 50) {
        statusTip.textContent = "❤️ Keep feeding to restore health!";
    } else {
        statusTip.textContent = "Keep your companion well fed!";
    }

    statusContainer.classList.remove('hidden');
}

function closePetStatus() {
    statusContainer.classList.add('hidden');

    fetch('https://${RESOURCE_NAME}/closeStatus', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
}

// =========================================
// PET FEED MENU
// =========================================
const feedContainer = document.getElementById('pet-feed-container');
const feedPetName = document.getElementById('feed-pet-name');
const foodItemsList = document.getElementById('food-items-list');
const noFoodMsg = document.getElementById('no-food-msg');

// Feed menu event listeners
document.getElementById('feed-close-btn').addEventListener('click', closeFeedMenu);

document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && !feedContainer.classList.contains('hidden')) {
        closeFeedMenu();
    }
});

function showFeedMenu(data) {
    feedPetName.textContent = 'Feed ' + (data.petName || 'Pet');
    foodItemsList.innerHTML = '';

    const foodItems = data.foodItems || [];

    if (foodItems.length === 0) {
        noFoodMsg.classList.remove('hidden');
        foodItemsList.classList.add('hidden');
    } else {
        noFoodMsg.classList.add('hidden');
        foodItemsList.classList.remove('hidden');

        foodItems.forEach(item => {
            const foodElement = document.createElement('div');
            foodElement.className = 'food-item';
            foodElement.innerHTML = `
                <div class="food-item-info">
                    <span class="food-item-name">🍖 ${item.label}</span>
                    <span class="food-item-stats">+${item.hunger} Hunger | +${item.health} Health</span>
                </div>
                <span class="food-item-count">x${item.amount}</span>
            `;
            foodElement.addEventListener('click', () => {
                selectFood(item.name, item.label);
            });
            foodItemsList.appendChild(foodElement);
        });
    }

    feedContainer.classList.remove('hidden');
}

function selectFood(itemName, itemLabel) {
    feedContainer.classList.add('hidden');

    fetch('https://${RESOURCE_NAME}/selectFood', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ itemName: itemName, itemLabel: itemLabel })
    });
}

function closeFeedMenu() {
    feedContainer.classList.add('hidden');

    fetch('https://${RESOURCE_NAME}/closeFeedMenu', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({})
    });
}

// =========================================
// CUSTOM PROGRESS BAR
// =========================================
const progressContainer = document.getElementById('progress-container');
const progressLabel = document.getElementById('progress-label');
const progressFill = document.getElementById('progress-fill');
let progressInterval;

function showProgressBar(data) {
    const duration = data.duration || 5000;
    const label = data.label || 'Processing...';

    progressLabel.textContent = label;
    progressFill.style.width = '0%';
    progressFill.style.transition = `width ${duration}ms linear`;

    progressContainer.classList.remove('hidden');

    // Force reflow
    void progressContainer.offsetWidth;

    // Start animation
    setTimeout(() => {
        progressFill.style.width = '100%';
    }, 50);

    // Auto hide after duration
    if (progressInterval) clearTimeout(progressInterval);
    progressInterval = setTimeout(() => {
        progressContainer.classList.add('hidden');
        progressFill.style.width = '0%';
        fetch('https://${RESOURCE_NAME}/progressBarComplete', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({})
        });
    }, duration);
}

function cancelProgressBar() {
    if (progressInterval) clearTimeout(progressInterval);
    progressContainer.classList.add('hidden');
    progressFill.style.width = '0%';
}

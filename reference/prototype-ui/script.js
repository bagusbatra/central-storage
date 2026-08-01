// DUMMY DATA APPLICATION
const BUYERS = [
    { id: 'nordic', name: 'Nordic Living', pct: 64 },
    { id: 'maison', name: 'Maison Clair', pct: 58 },
    { id: 'westfield', name: 'Westfield Home', pct: 40 },
    { id: 'sakura', name: 'Sakura Interior', pct: 16 },
    { id: 'aussie', name: 'Aussie Timber', pct: 36 },
    { id: 'kastel', name: 'Kastel Möbel', pct: 88 },
    { id: 'green', name: 'Green Valley', pct: 20 },
    { id: 'oakhouse', name: 'Oakhouse Ltd', pct: 45 },
    { id: 'bella', name: 'Bella Casa', pct: 59 },
    { id: 'lotus', name: 'Lotus Home', pct: 14 }
];

const WORK_CENTERS_MC = Array.from({ length: 40 }, (_, i) => {
    const id = i + 1;
    const value = Math.floor(Math.random() * 12) + 1;
    let load = 'low';
    if (value > 4 && value <= 8) load = 'med';
    if (value > 8) load = 'high';
    return { id: `MC-${id < 10 ? '0' + id : id}`, value, load };
});

const WORK_CENTERS_EBS = Array.from({ length: 20 }, (_, i) => {
    const id = i + 1;
    const value = Math.floor(Math.random() * 5) + 0;
    let load = 'low';
    if (value === 2 || value === 3) load = 'med';
    if (value > 3) load = 'high';
    return { id: `EBS-${id < 10 ? '0' + id : id}`, value, load };
});

const SO_DATA = [
    { id: 'SO-2401', buyerId: 'nordic', buyerName: 'Nordic Living', desc: 'Wardrobe 3-Pintu - Aurora', plonum: 'PLO-24-0037', pct: 88, compCount: 60, pcsCount: 120, selesai: 51, colors: ['#b45309', '#2563eb', '#10b981', '#cbd5e1'], widths: ['30%', '40%', '18%', '12%'] },
    { id: 'SO-2402', buyerId: 'nordic', buyerName: 'Nordic Living', desc: 'Credenza - Aurora', plonum: 'PLO-24-0039', pct: 79, compCount: 50, pcsCount: 97, selesai: 41, colors: ['#b45309', '#2563eb', '#10b981', '#cbd5e1'], widths: ['25%', '35%', '19%', '21%'] },
    { id: 'SO-2403', buyerId: 'maison', buyerName: 'Maison Clair', desc: 'TV Cabinet - Nordic', plonum: 'PLO-24-0021', pct: 71, compCount: 55, pcsCount: 112, selesai: 37, colors: ['#b45309', '#2563eb', '#10b981', '#cbd5e1'], widths: ['40%', '20%', '11%', '29%'] },
    { id: 'SO-2404', buyerId: 'maison', buyerName: 'Maison Clair', desc: 'Sideboard - Nordic', plonum: 'PLO-24-0035', pct: 28, compCount: 60, pcsCount: 135, selesai: 6, colors: ['#b45309', '#2563eb', '#10b981', '#cbd5e1'], widths: ['50%', '30%', '5%', '15%'] },
    { id: 'SO-2405', buyerId: 'westfield', buyerName: 'Westfield Home', desc: 'Kitchen Upper Set - Lumen', plonum: 'PLO-24-0015', pct: 52, compCount: 62, pcsCount: 129, selesai: 24, colors: ['#b45309', '#2563eb', '#10b981', '#cbd5e1'], widths: ['42%', '30%', '10%', '18%'] },
    { id: 'SO-2406', buyerId: 'westfield', buyerName: 'Westfield Home', desc: 'Dresser 6-Laci - Lumen', plonum: 'PLO-24-0078', pct: 18, compCount: 58, pcsCount: 121, selesai: 2, colors: ['#b45309', '#2563eb', '#10b981', '#cbd5e1'], widths: ['20%', '20%', '5%', '55%'] }
];

const COMPONENT_DATA = [
    { name: 'Ambalan #8', code: 'SD-2401-C005', buyerId: 'nordic', buyerName: 'Nordic Living', mat: 'MDF15-MAT', qty: 1, center: 'MC', wc: 'MC-01', status: 'antri', pos: '0%' },
    { name: 'Sekat Vertikal #9', code: 'SD-2401-C009', buyerId: 'nordic', buyerName: 'Nordic Living', mat: 'PB18-PTH', qty: 2, center: 'MC', wc: 'MC-25', status: 'dikerjakan', pos: '0%' },
    { name: 'Rak Tengah #39', code: 'SD-2401-C020', buyerId: 'nordic', buyerName: 'Nordic Living', mat: 'MDF15-MAT', qty: 1, center: 'MC', wc: 'MC-08', status: 'antri', pos: '0%' },
    { name: 'Rak Tengah #51', code: 'SD-2401-C051', buyerId: 'nordic', buyerName: 'Nordic Living', mat: 'MDF15-MAT', qty: 1, center: 'MC', wc: 'MC-01', status: 'antri', pos: '0%' },
    { name: 'Pintu Kiri #50', code: 'SD-2401-C050', buyerId: 'nordic', buyerName: 'Nordic Living', mat: 'HPL-3021', qty: 1, center: 'MC', wc: 'MC-08', status: 'dikerjakan', pos: '0%' },
    { name: 'Samping Kanan #3', code: 'SD-2401-C003', buyerId: 'nordic', buyerName: 'Nordic Living', mat: 'PB18-PTH', qty: 4, center: 'MC', wc: 'MC-12', status: 'antri', pos: '0%' },
    { name: 'Pintu Laci #5', code: 'SD-2401-C005', buyerId: 'nordic', buyerName: 'Nordic Living', mat: 'BLK18-MLN', qty: 1, center: 'MC', wc: 'MC-32', status: 'dikerjakan', pos: '0%' },
    
    { name: 'Rak Bawah #9', code: 'SD-2405-C009', buyerId: 'westfield', buyerName: 'Westfield Home', mat: 'PB18-PTH', qty: 4, center: 'EBS', wc: 'EBS-14', status: 'antri', pos: '50%' },
    { name: 'Samping Kanan #10', code: 'SD-2405-C010', buyerId: 'westfield', buyerName: 'Westfield Home', mat: 'PB18-PTH', qty: 1, center: 'EBS', wc: 'EBS-13', status: 'antri', pos: '50%' },
    { name: 'Partisi #12', code: 'SD-2405-C012', buyerId: 'westfield', buyerName: 'Westfield Home', mat: 'PB18-PTH', qty: 2, center: 'EBS', wc: 'EBS-02', status: 'dikerjakan', pos: '50%' },
    { name: 'Back Panel B #19', code: 'SD-2405-C019', buyerId: 'westfield', buyerName: 'Westfield Home', mat: 'PLY12-MRN', qty: 2, center: 'EBS', wc: 'EBS-20', status: 'dikerjakan', pos: '50%' },
    { name: 'Rak Atas #21', code: 'SD-2405-C021', buyerId: 'westfield', buyerName: 'Westfield Home', mat: 'PB18-PTH', qty: 3, center: 'EBS', wc: 'EBS-14', status: 'antri', pos: '50%' },
    { name: 'Rak Tengah #22', code: 'SD-2405-C022', buyerId: 'westfield', buyerName: 'Westfield Home', mat: 'MDF15-MAT', qty: 2, center: 'EBS', wc: 'EBS-02', status: 'dikerjakan', pos: '50%' },
    { name: 'Balok Penguat #30', code: 'SD-2405-C030', buyerId: 'westfield', buyerName: 'Westfield Home', mat: 'PLY12-MRN', qty: 4, center: 'EBS', wc: 'EBS-11', status: 'dikerjakan', pos: '50%' }
];

// STATE MANAGEMENT
let selectedBuyer = null; // null berarti "Semua Buyer"
let selectedCenter = 'MC'; // 'MC' atau 'EBS'
let selectedTab = 'semua';
let searchQuery = '';

// DOM ELEMENTS
const buyerFilterContainer = document.getElementById('buyer-filter-container');
const btnAllBuyer = document.getElementById('btn-all-buyer');
const mcBox = document.getElementById('mc-box');
const ebsBox = document.getElementById('ebs-box');
const wcGridContainer = document.getElementById('wc-grid-container');
const wcMapTitle = document.getElementById('wc-map-title');
const soListContainer = document.getElementById('so-list-container');
const componentTableBody = document.getElementById('component-table-body');
const searchComponent = document.getElementById('search-component');
const wipDisplayStatus = document.getElementById('wip-display-status');
const detailSubLabel = document.getElementById('detail-sub-label');
const soBuyerLabel = document.getElementById('so-buyer-label');

// INIT
function init() {
    renderBuyerFilters();
    renderWCLoadGrid();
    renderSOList();
    renderComponentTable();
    setupEventListeners();
}

// RENDER FILTERS BUYER
function renderBuyerFilters() {
    buyerFilterContainer.innerHTML = '';
    BUYERS.forEach(buyer => {
        const btn = document.createElement('button');
        btn.className = `filter-btn ${selectedBuyer === buyer.id ? 'active' : ''}`;
        btn.innerHTML = `${buyer.name} <span class="pct">${buyer.pct}%</span>`;
        btn.addEventListener('click', () => selectBuyer(buyer.id));
        buyerFilterContainer.appendChild(btn);
    });
}

function selectBuyer(buyerId) {
    if (buyerId === null) {
        selectedBuyer = null;
        btnAllBuyer.classList.add('active');
    } else {
        selectedBuyer = buyerId;
        btnAllBuyer.classList.remove('active');
    }
    
    // Auto toggle center box layout base on buyer visual reference image context
    if (buyerId === 'westfield') {
        switchCenter('EBS');
        document.getElementById('mc-wip-text').innerText = '34';
        document.getElementById('ebs-wip-text').innerText = '27';
    } else {
        switchCenter('MC');
        document.getElementById('mc-wip-text').innerText = '213';
        document.getElementById('ebs-wip-text').innerText = '167';
    }

    renderBuyerFilters();
    updateLabels();
    renderWCLoadGrid();
    renderSOList();
    renderComponentTable();
}

function switchCenter(center) {
    selectedCenter = center;
    if (center === 'MC') {
        mcBox.classList.add('active');
        ebsBox.classList.remove('active');
        wcMapTitle.innerText = 'Machining Center';
    } else {
        ebsBox.classList.add('active');
        mcBox.classList.remove('active');
        wcMapTitle.innerText = 'Edge Banding & Sanding';
    }
    updateLabels();
    renderWCLoadGrid();
    renderComponentTable();
}

function updateLabels() {
    const buyerName = selectedBuyer ? BUYERS.find(b => b.id === selectedBuyer).name : 'Semua Buyer';
    wipDisplayStatus.innerText = `${buyerName} • Semua SO`;
    detailSubLabel.innerText = `${buyerName} • ${selectedCenter === 'MC' ? 'Machining Center' : 'Edge Banding & Sanding'}`;
    
    const filteredSOs = selectedBuyer ? SO_DATA.filter(so => so.buyerId === selectedBuyer) : SO_DATA;
    soBuyerLabel.innerText = `${buyerName} • ${filteredSOs.length} PLO`;
}

// RENDER WORK CENTER GRID MAP
function renderWCLoadGrid() {
    wcGridContainer.innerHTML = '';
    const items = selectedCenter === 'MC' ? WORK_CENTERS_MC : WORK_CENTERS_EBS;
    
    items.forEach(wc => {
        const div = document.createElement('div');
        div.className = `wc-item load-${wc.load}`;
        div.innerHTML = `
            <span class="wc-name">${wc.id.split('-')[1]}</span>
            <span class="wc-value">${wc.value}</span>
            <span class="wc-sub">/12</span>
        `;
        wcGridContainer.appendChild(div);
    });
}

// RENDER SO / PLO LIST
function renderSOList() {
    soListContainer.innerHTML = '';
    
    // Header All Progress Bar
    const allBar = document.createElement('div');
    allBar.className = 'so-all-bar';
    allBar.innerHTML = `<span>SEMUA SO</span> <span class="color-green">46%</span>`;
    soListContainer.appendChild(allBar);

    const filteredSOs = selectedBuyer ? SO_DATA.filter(so => so.buyerId === selectedBuyer) : SO_DATA;

    filteredSOs.forEach(so => {
        const item = document.createElement('div');
        item.className = 'so-item-box';
        
        // Buat Multi-segmented progress bar template
        let barSegments = '';
        so.widths.forEach((w, idx) => {
            barSegments += `<div class="so-bar-part" style="width: ${w}; background: ${so.colors[idx]};"></div>`;
        });

        item.innerHTML = `
            <div class="so-item-header">
                <div>
                    ${so.id}
                    <div class="so-meta"><i class="fa-solid fa-user"></i> ${so.buyerName}</div>
                </div>
                <div class="so-pct-val">${so.pct}%</div>
            </div>
            <div class="so-meta" style="color:#1e293b; font-weight:500;">${so.desc}</div>
            <div class="so-meta" style="font-family:monospace;">${so.plonum}</div>
            
            <div class="so-progress-bar">
                ${barSegments}
            </div>
            
            <div class="so-item-footer">
                <span>${so.compCount} komp - ${so.pcsCount} pcs</span>
                <span class="color-green" style="font-weight:600;">${so.selesai} selesai</span>
            </div>
        `;
        soListContainer.appendChild(item);
    });
}

// RENDER COMPONENT TABLE DETAIL
function renderComponentTable() {
    componentTableBody.innerHTML = '';
    
    let filtered = COMPONENT_DATA.filter(c => c.center === selectedCenter);
    
    if (selectedBuyer) {
        filtered = filtered.filter(c => c.buyerId === selectedBuyer);
    }
    
    if (selectedTab !== 'semua') {
        filtered = filtered.filter(c => c.status === selectedTab);
    }
    
    if (searchQuery) {
        filtered = filtered.filter(c => 
            c.name.toLowerCase().includes(searchQuery.toLowerCase()) || 
            c.code.toLowerCase().includes(searchQuery.toLowerCase()) || 
            c.buyerName.toLowerCase().includes(searchQuery.toLowerCase())
        );
    }

    if(filtered.length === 0) {
        componentTableBody.innerHTML = `<tr><td colspan="5" style="text-align:center; color:var(--text-muted); padding:20px;">Tidak ada data komponen ditemukan</td></tr>`;
        return;
    }

    filtered.forEach(c => {
        const tr = document.createElement('tr');
        tr.innerHTML = `
            <td>
                <span class="comp-name">${c.name}</span>
                <span class="comp-sub">${c.code} • ${c.buyerName}</span>
            </td>
            <td><span class="mat-code">${c.mat}</span></td>
            <td>
                <div class="routing-badge">
                    <span style="color:#059669; font-weight:700;">${c.qty}</span> | <i class="fa-solid fa-table-cells" style="font-size:8px;"></i> ${c.center} @ ${c.wc}
                </div>
            </td>
            <td><span class="status-badge ${c.status}">${c.status.toUpperCase()}</span></td>
            <td style="text-align: right; font-weight:700;">${c.pos}</td>
        `;
        componentTableBody.appendChild(tr);
    });
}

// EVENT LISTENERS
function setupEventListeners() {
    btnAllBuyer.addEventListener('click', () => selectBuyer(null));
    
    mcBox.addEventListener('click', () => switchCenter('MC'));
    ebsBox.addEventListener('click', () => switchCenter('EBS'));
    
    // Tab Event Filter
    document.querySelectorAll('.tab-btn').forEach(btn => {
        btn.addEventListener('click', (e) => {
            document.querySelectorAll('.tab-btn').forEach(b => b.classList.remove('active'));
            e.target.classList.add('active');
            selectedTab = e.target.getAttribute('data-tab');
            renderComponentTable();
        });
    });

    // Realtime Input Search Box
    searchComponent.addEventListener('input', (e) => {
        searchQuery = e.target.value;
        renderComponentTable();
    });
}

// RUN APPLICATION
window.addEventListener('DOMContentLoaded', init);
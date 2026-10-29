import { auth, db } from "./firebase-init.js";
import { watchAuth, logout } from "./auth.js";
import { showToast, showAlert, closeModal } from "./ui.js";
import {
collection, doc, getDoc, setDoc, addDoc, updateDoc, deleteDoc,
onSnapshot, increment, serverTimestamp
} from "https://www.gstatic.com/firebasejs/11.6.1/firebase-firestore.js";

let uid = null;
let profile = null;
let menuItems = [], orders = [], inventory = [], cart = [];
let menuReady = false, invReady = false;
let firstOrdersLoad = true;
let currentRole = 'cajero';
let editingIngredientFbId = null;
let editingProductId = null, editingProductRecipe = [];
let editingSale = null;
let calYear = new Date().getFullYear(), calMonth = new Date().getMonth(), selDate = null;
let audioCtx = null;
try { audioCtx = new (window.AudioContext || window.webkitAudioContext)(); } catch(e){}

const menuCol = () => collection(db, 'users', uid, 'menu');
const ordersCol = () => collection(db, 'users', uid, 'orders');
const invCol = () => collection(db, 'users', uid, 'inventory');

watchAuth(async (user, prof) => {
if (!user) { window.location.href = 'index.html'; return; }
if (!prof?.onboarded) { window.location.href = 'onboarding.html'; return; }
uid = user.uid;
profile = prof;
applyTheme(prof.theme);
document.getElementById('biz-name').textContent = (prof.businessName || 'MI NEGOCIO').toUpperCase();
const deskName = document.getElementById('biz-name-desk');
if (deskName) deskName.textContent = (prof.businessName || 'MI NEGOCIO').toUpperCase();
document.getElementById('loading').classList.add('hidden');
document.getElementById('main-app').classList.remove('hidden');
attachListeners();
});

function applyTheme(theme) {
const themes = {
mustard: 'bg-amber-500',
olive: 'bg-lime-700',
rose: 'bg-rose-600'
};
const bg = themes[theme] || themes.mustard;
document.getElementById('brand-icon').className = `${bg} text-white w-8 h-8 rounded-xl flex items-center justify-center text-sm`;
const deskIcon = document.getElementById('brand-icon-desk');
if (deskIcon) deskIcon.className = `${bg} text-white w-10 h-10 rounded-xl flex items-center justify-center text-lg`;
}

function attachListeners() {
onSnapshot(menuCol(), async (snap) => {
if (snap.empty && !menuReady) { await seedDefaultMenu(); return; }
menuItems = snap.docs.map(d => ({ firebaseId: d.id, ...d.data() })).sort((a,b)=>a.id-b.id);
menuReady = true;
setSyncOk();
refresh();
});

onSnapshot(ordersCol(), (snap) => {
const prevPend = orders.filter(o=>o.status==='pendiente').length;
orders = snap.docs.map(d => ({ firebaseId: d.id, ...d.data() })).sort((a,b)=>(b.timestamp||0)-(a.timestamp||0));
const nowPend = orders.filter(o=>o.status==='pendiente').length;
if (!firstOrdersLoad && nowPend > prevPend) playBeep();
firstOrdersLoad = false;
refresh();
});

onSnapshot(invCol(), async (snap) => {
if (snap.empty && !invReady) { await seedDefaultInventory(); return; }
inventory = snap.docs.map(d => ({ firebaseId: d.id, ...d.data() })).sort((a,b)=>a.id-b.id);
invReady = true;
refresh();
});
}

function setSyncOk() {
const el = document.getElementById('sync-indicator');
if (el) {
el.title = 'Conectado';
el.innerHTML = '<span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span><span class="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span>';
}
const deskEl = document.getElementById('sync-indicator-desk');
if (deskEl) {
deskEl.title = 'Conectado';
deskEl.innerHTML = '<span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span><span class="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span>';
}
}

async function seedDefaultMenu() {
const defaults = [
{ id:1, name:"CLASICO", desc:"Chorizo + pan", price:10000, icon:"fa-solid fa-hotdog", recipe:[{ingredientId:1,qty:1},{ingredientId:2,qty:1}] },
{ id:2, name:"GRATINADO", desc:"Con queso", price:11000, icon:"fa-solid fa-cheese", recipe:[{ingredientId:1,qty:1},{ingredientId:2,qty:1},{ingredientId:3,qty:1}] },
{ id:3, name:"COMBO", desc:"Choripan + papas", price:14000, icon:"fa-solid fa-utensils", recipe:[{ingredientId:1,qty:1},{ingredientId:2,qty:1},{ingredientId:4,qty:1}] }
];
for (const item of defaults) await setDoc(doc(menuCol(), `item_${item.id}`), item);
}

async function seedDefaultInventory() {
const defaults = [
{ id:1, name:"Chorizo", stock:80, unit:"und" },
{ id:2, name:"Pan", stock:85, unit:"und" },
{ id:3, name:"Queso", stock:45, unit:"porc" },
{ id:4, name:"Papas", stock:60, unit:"porc" }
];
for (const item of defaults) await setDoc(doc(invCol(), `item_${item.id}`), item);
}

window.switchRole = (role) => {
currentRole = role;
['cajero','cocinero','inventario','admin'].forEach(r => {
document.getElementById(`view-${r}`).classList.add('hidden');
document.getElementById(`nav-btn-${r}`).className = "flex flex-col items-center gap-1 text-stone-400 hover:text-stone-700 transition";
const d = document.getElementById(`desk-btn-${r}`);
if (d) d.className = "w-full flex items-center gap-3 px-4 py-3 rounded-xl text-stone-400 hover:bg-stone-50 transition font-bold text-sm";
});
document.getElementById(`view-${role}`).classList.remove('hidden');
document.getElementById(`nav-btn-${role}`).className = "flex flex-col items-center gap-1 text-amber-600 transition";
const deskBtn = document.getElementById(`desk-btn-${role}`);
if (deskBtn) deskBtn.className = "w-full flex items-center gap-3 px-4 py-3 rounded-xl bg-amber-50 text-amber-600 transition font-bold text-sm";
const labels = { cajero:'Caja', cocinero:'Cocina', inventario:'Inventario', admin:'Admin' };
document.getElementById('active-role-label').textContent = labels[role];
const deskTitle = document.getElementById('desktop-role-title');
if (deskTitle) deskTitle.textContent = labels[role];
refresh();
};

function refresh() {
if (currentRole === 'cajero') { renderMenu(); updateCart(); renderCashierOrders(); }
if (currentRole === 'cocinero') updateKitchen();
if (currentRole === 'inventario') renderInventorySection();
if (currentRole === 'admin') updateAdmin();
}

window.doLogout = logout;

const dateKey = (d) => `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;
const todayKey = () => dateKey(new Date());
const ordersOfDate = (k) => orders.filter(o => o.timestamp && dateKey(new Date(o.timestamp)) === k);
const fmtShort = (n) => n >= 1000000 ? (n/1000000).toFixed(1).replace('.0','')+'M' : n >= 1000 ? Math.round(n/1000)+'k' : String(n);
const getIng = (id) => inventory.find(i => i.id === id);

function formatElapsed(ms) {
const t = Math.max(0, Math.floor(ms/1000));
const m = Math.floor(t/60), s = t%60;
if (m === 0) return `${s}s`;
if (m >= 60) return `${Math.floor(m/60)}h ${m%60}m`;
return `${m}m ${String(s).padStart(2,'0')}s`;
}

function timerClass(ms) {
const min = ms/60000;
if (min < 5) return 'bg-emerald-100 text-emerald-700 border-emerald-200';
if (min < 10) return 'bg-amber-100 text-amber-800 border-amber-200';
if (min < 15) return 'bg-orange-100 text-orange-800 border-orange-200';
return 'bg-rose-100 text-rose-700 border-rose-300 urgent-pulse';
}

setInterval(() => {
if (currentRole !== 'cocinero' && currentRole !== 'cajero') return;
const now = Date.now();
document.querySelectorAll('[data-timer]').forEach(el => {
const o = orders.find(x => x.firebaseId === el.getAttribute('data-timer'));
if (!o || !o.timestamp) return;
const e = now - o.timestamp;
el.textContent = formatElapsed(e);
el.className = `text-[10px] font-bold px-2 py-0.5 rounded-md border ${timerClass(e)}`;
});
}, 1000);

function playBeep() {
try {
if (!audioCtx) return;
const o = audioCtx.createOscillator(), g = audioCtx.createGain();
o.connect(g); g.connect(audioCtx.destination);
o.type = 'sine'; o.frequency.value = 880;
g.gain.setValueAtTime(0.18, audioCtx.currentTime);
g.gain.exponentialRampToValueAtTime(0.001, audioCtx.currentTime + 0.45);
o.start(); o.stop(audioCtx.currentTime + 0.45);
} catch(e){}
}

function renderMenu() {
const grid = document.getElementById('menu-grid');
const summary = document.getElementById('menu-prices-summary');
if (!menuReady) { grid.innerHTML = '<p class="text-stone-400 text-xs py-3 text-center">Cargando menu...</p>'; return; }
summary.textContent = `${menuItems.length} productos`;
grid.innerHTML = menuItems.map(i => `
<div onclick="addToCart(${i.id})" class="bg-white p-3 rounded-2xl border border-stone-200 active:scale-[0.99] transition flex items-center justify-between cursor-pointer shadow-sm hover:shadow-md">
<div class="flex items-center gap-3">
<div class="w-10 h-10 rounded-xl bg-stone-100 text-stone-800 flex items-center justify-center font-bold text-sm"><i class="${i.icon}"></i></div>
<div>
<h4 class="font-bold text-sm text-stone-900">${i.name}</h4>
<p class="text-[11px] text-stone-400 line-clamp-1">${i.desc || ''}</p>
</div>
</div>
<div class="text-right">
<span class="font-black text-sm text-amber-600">$${i.price.toLocaleString()}</span>
<div class="text-[10px] text-stone-400 font-medium">+ Agregar</div>
</div>
</div>
`).join('');
}

window.addToCart = (id) => {
const item = menuItems.find(m => m.id === id);
if (!item) return;
const ex = cart.find(c => c.id === id);
if (ex) ex.qty++;
else cart.push({ id: item.id, name: item.name, price: item.price, qty: 1 });
updateCart();
};

window.updateCartQty = (id, delta) => {
const it = cart.find(c => c.id === id);
if (it) { it.qty += delta; if (it.qty <= 0) cart = cart.filter(c => c.id !== id); }
updateCart();
};

window.clearCart = () => { cart = []; document.getElementById('customer-name').value = ''; updateCart(); };

function updateCart() {
const c = document.getElementById('cart-items'), t = document.getElementById('cart-total');
if (!cart.length) { c.innerHTML = '<p class="text-stone-400 text-xs py-2 text-center">Sin items en el pedido</p>'; t.textContent = '$0'; return; }
let total = 0;
c.innerHTML = cart.map(it => {
total += it.price * it.qty;
return `<div class="flex justify-between items-center py-1.5">
<span class="font-semibold text-sm text-stone-800">${it.name}</span>
<div class="flex items-center gap-2">
<button onclick="updateCartQty(${it.id},-1)" class="w-6 h-6 bg-stone-100 hover:bg-stone-200 rounded text-sm font-bold">-</button>
<span class="text-sm font-bold w-5 text-center">${it.qty}</span>
<button onclick="updateCartQty(${it.id},1)" class="w-6 h-6 bg-stone-100 hover:bg-stone-200 rounded text-sm font-bold">+</button>
</div>
</div>`;
}).join('');
t.textContent = `$${total.toLocaleString()}`;
}

async function applyRecipe(items, sign) {
const updates = {};
for (const it of items) {
const p = menuItems.find(m => m.id === it.id);
if (!p || !Array.isArray(p.recipe)) continue;
for (const r of p.recipe) {
if (!r.ingredientId || !r.qty) continue;
const ing = getIng(r.ingredientId);
if (!ing) continue;
updates[ing.firebaseId] = (updates[ing.firebaseId] || 0) + sign * r.qty * it.qty;
}
}
for (const fb in updates) {
try { await updateDoc(doc(invCol(), fb), { stock: increment(updates[fb]) }); } catch(e){ console.error(e); }
}
}

window.submitOrder = async () => {
if (!menuReady || !invReady) { showAlert("Sincronizando, espera un segundo..."); return; }
const customer = document.getElementById('customer-name').value.trim() || 'Cliente';
if (!cart.length) { showAlert("Agrega al menos un producto."); return; }
const total = cart.reduce((s,i) => s + i.price * i.qty, 0);
const now = new Date();
const time = `${String(now.getHours()).padStart(2,'0')}:${String(now.getMinutes()).padStart(2,'0')}`;
const order = {
id: Math.floor(100 + Math.random()*900),
customer, items: [...cart], total,
status: 'pendiente', time, timestamp: Date.now()
};
const btn = document.getElementById('btn-submit');
btn.disabled = true;
try {
await addDoc(ordersCol(), order);
await applyRecipe(order.items, -1);
try {
await updateDoc(doc(db, 'users', uid), {
'stats.totalOrders': increment(1),
'stats.totalSales': increment(total)
});
const gRef = doc(db, 'stats', 'global');
const gSnap = await getDoc(gRef);
if (gSnap.exists()) await updateDoc(gRef, { totalOrders: increment(1), totalSales: increment(total), lastUpdated: serverTimestamp() });
} catch(e) { console.warn("Stats:", e); }
clearCart();
showToast("Pedido enviado", 'success');
} catch(e) {
console.error(e);
showAlert("Error al enviar. Revisa tu conexion.", "Error");
} finally { btn.disabled = false; }
};

function statusClass(s) {
if (s === 'pendiente') return 'bg-amber-100 text-amber-800';
if (s === 'preparacion') return 'bg-blue-100 text-blue-800';
return 'bg-emerald-100 text-emerald-800';
}

function renderCashierOrders() {
const c = document.getElementById('cashier-orders-list');
const now = Date.now();
c.innerHTML = orders.slice(0,5).map(o => {
const e = o.timestamp ? now - o.timestamp : 0;
const t = o.status !== 'listo' ? `<span data-timer="${o.firebaseId}" class="text-[10px] font-bold px-2 py-0.5 rounded-md border ${timerClass(e)}">${formatElapsed(e)}</span>` : '';
return `<div class="flex justify-between items-center bg-stone-50 p-2.5 rounded-xl border border-stone-100 text-xs">
<div class="min-w-0 flex-1">
<div class="flex items-center gap-1.5 flex-wrap"><span class="font-bold text-stone-900">#${o.id} - ${o.customer}</span>${t}</div>
<div class="text-[10px] text-stone-400 truncate">${(o.items||[]).map(i=>`${i.qty}x${i.name}`).join(', ')}</div>
</div>
<div class="text-right shrink-0 ml-2"><span class="font-bold text-amber-600">$${(o.total||0).toLocaleString()}</span><div><span class="text-[9px] px-1.5 py-0.5 rounded font-bold ${statusClass(o.status)}">${o.status}</span></div></div>
</div>`;
}).join('') || '<p class="text-stone-400 text-xs py-2 text-center">No hay pedidos recientes</p>';
}

function updateKitchen() {
const c = document.getElementById('kitchen-orders-list');
const activos = orders.filter(o => o.status !== 'listo').sort((a,b) => (a.timestamp||0)-(b.timestamp||0));
const listos = orders.filter(o => o.status === 'listo').sort((a,b) => (b.timestamp||0)-(a.timestamp||0)).slice(0,3);
document.getElementById('kitchen-count').textContent = `${activos.length} pendientes`;
const now = Date.now();
const card = (o) => {
const e = o.timestamp ? now - o.timestamp : 0;
const min = e/60000;
const border = o.status === 'listo' ? 'border-emerald-200 opacity-70' : min >= 15 ? 'border-rose-300' : min >= 10 ? 'border-orange-300' : min >= 5 ? 'border-amber-300' : 'border-stone-200';
return `<div class="bg-white p-4 rounded-2xl shadow-sm border-2 ${border} space-y-3">
<div class="flex justify-between items-center gap-2">
<span class="font-bold text-sm text-stone-900 truncate">#${o.id} - ${o.customer}</span>
${o.status !== 'listo' ? `<span data-timer="${o.firebaseId}" class="text-[10px] font-bold px-2 py-0.5 rounded-md border ${timerClass(e)}">${formatElapsed(e)}</span>` : `<span class="text-[10px] text-stone-400">${o.time}</span>`}
</div>
<div class="bg-stone-50 p-3 rounded-xl text-sm space-y-1">${(o.items||[]).map(i => `<div class="font-medium text-stone-800">- ${i.qty}x${i.name}</div>`).join('')}</div>
<div class="flex justify-between items-center pt-1">
<span class="text-[10px] text-stone-400">${o.time}</span>
<div class="flex gap-2">
${o.status==='pendiente' ? `<button onclick="setStatus('${o.firebaseId}','preparacion')" class="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded-xl text-xs font-bold">Cocinar</button>` : ''}
${o.status==='preparacion' ? `<button onclick="setStatus('${o.firebaseId}','listo')" class="bg-emerald-600 hover:bg-emerald-700 text-white px-4 py-2 rounded-xl text-xs font-bold">Listo</button>` : ''}
${o.status==='listo' ? `<span class="text-xs font-bold text-emerald-600">Entregado</span>` : ''}
</div>
</div>
</div>`;
};
c.innerHTML = (activos.map(card).join('') || '<p class="text-stone-400 text-xs py-2 text-center col-span-full">No hay pedidos en cocina</p>') +
(listos.length ? `<div class="pt-2 text-[10px] font-bold text-stone-400 uppercase tracking-wider col-span-full mt-4">Ultimos listos</div>` + listos.map(card).join('') : '');
}

window.setStatus = async (fbId, status) => {
try { await updateDoc(doc(ordersCol(), fbId), { status }); } catch(e) { console.error(e); }
};

function renderInventorySection() {
const list = document.getElementById('inventory-list');
if (!invReady) { list.innerHTML = '<p class="text-stone-400 text-xs py-3 text-center col-span-full">Cargando inventario...</p>'; return; }
if (!inventory.length) { list.innerHTML = '<p class="text-stone-400 text-xs py-3 text-center col-span-full">No hay ingredientes.</p>'; return; }
list.innerHTML = inventory.map(i => {
const low = i.stock <= 10;
return `<div class="bg-white rounded-2xl p-4 shadow-sm border border-stone-200">
<div class="flex flex-col gap-3">
<div class="flex items-center justify-between gap-2">
<div class="flex items-center gap-3 min-w-0">
<div class="w-10 h-10 rounded-xl bg-stone-100 flex items-center justify-center"><i class="fa-solid fa-box text-stone-700 text-sm"></i></div>
<div class="min-w-0"><h4 class="font-bold text-sm text-stone-900 truncate">${i.name}</h4><p class="text-[11px] text-stone-400">Stock: <span class="font-bold ${low?'text-rose-600':'text-stone-700'}">${i.stock} ${i.unit}</span></p></div>
</div>
<button onclick="openIngredientModal('${i.firebaseId}')" class="w-8 h-8 bg-rose-50 hover:bg-rose-100 text-rose-600 rounded-lg text-xs shrink-0"><i class="fa-solid fa-pen"></i></button>
</div>
<div class="flex items-center gap-1">
<button onclick="adjustStock('${i.firebaseId}',-10)" class="flex-1 bg-stone-100 hover:bg-stone-200 rounded-lg text-xs font-bold py-1.5">-10</button>
<button onclick="adjustStock('${i.firebaseId}',-1)" class="flex-1 bg-stone-100 hover:bg-stone-200 rounded-lg text-xs font-bold py-1.5">-1</button>
<button onclick="adjustStock('${i.firebaseId}',1)" class="flex-1 bg-stone-100 hover:bg-stone-200 rounded-lg text-xs font-bold py-1.5">+1</button>
<button onclick="adjustStock('${i.firebaseId}',10)" class="flex-1 bg-stone-100 hover:bg-stone-200 rounded-lg text-xs font-bold py-1.5">+10</button>
</div>
</div>
</div>`;
}).join('');

const todayOrders = ordersOfDate(todayKey());
const usage = {};
inventory.forEach(i => usage[i.id] = 0);
todayOrders.forEach(o => (o.items||[]).forEach(it => {
const p = menuItems.find(m => m.id === it.id);
if (!p || !Array.isArray(p.recipe)) return;
p.recipe.forEach(r => { if (r.ingredientId && r.qty) usage[r.ingredientId] = (usage[r.ingredientId]||0) + r.qty * it.qty; });
}));
const stats = document.getElementById('ingredient-usage-stats');
stats.innerHTML = inventory.map(i => ({ name: i.name, unit: i.unit, qty: usage[i.id] || 0 }))
.sort((a,b) => b.qty - a.qty)
.map(u => `<div class="flex justify-between items-center bg-stone-50 p-2.5 rounded-lg text-xs border border-stone-100"><span class="font-semibold text-stone-700 truncate">${u.name}</span><span class="font-bold text-stone-900">${u.qty} ${u.unit}</span></div>`).join('') || '<p class="text-stone-400 text-xs py-2 text-center col-span-full">Sin datos aun.</p>';
}

window.adjustStock = async (fbId, delta) => {
try { await updateDoc(doc(invCol(), fbId), { stock: increment(delta) }); } catch(e){ console.error(e); }
};

window.openIngredientModal = (fbId) => {
const modal = document.getElementById('ingredient-modal');
const title = document.getElementById('ingredient-modal-title');
const name = document.getElementById('ingredient-modal-name');
const stock = document.getElementById('ingredient-modal-stock');
const unit = document.getElementById('ingredient-modal-unit');
const del = document.getElementById('ingredient-modal-delete');
if (fbId) {
const i = inventory.find(x => x.firebaseId === fbId);
if (!i) return;
editingIngredientFbId = fbId;
title.textContent = 'Editar Ingrediente';
name.value = i.name; stock.value = i.stock; unit.value = i.unit;
del.classList.remove('hidden');
} else {
editingIngredientFbId = null;
title.textContent = 'Nuevo Ingrediente';
name.value = ''; stock.value = 0; unit.value = 'und';
del.classList.add('hidden');
}
modal.classList.remove('hidden');
setTimeout(() => name.focus(), 150);
};

window.closeIngredientModal = () => { document.getElementById('ingredient-modal').classList.add('hidden'); editingIngredientFbId = null; };

window.saveIngredient = async () => {
const name = document.getElementById('ingredient-modal-name').value.trim();
const stock = parseInt(document.getElementById('ingredient-modal-stock').value) || 0;
const unit = document.getElementById('ingredient-modal-unit').value;
if (!name) { showAlert("Escribe un nombre."); return; }
try {
if (editingIngredientFbId) {
await updateDoc(doc(invCol(), editingIngredientFbId), { name, stock, unit });
} else {
const maxId = inventory.reduce((m,i) => Math.max(m, i.id||0), 0);
const newId = maxId + 1;
await setDoc(doc(invCol(), `item_${newId}_${Date.now()}`), { id: newId, name, stock, unit });
}
closeIngredientModal();
showToast("Ingrediente guardado", 'success');
} catch(e) { console.error(e); showAlert("No se pudo guardar.", "Error"); }
};

window.deleteIngredientFromModal = async () => {
if (!editingIngredientFbId || !confirm("Eliminar este ingrediente?")) return;
try { await deleteDoc(doc(invCol(), editingIngredientFbId)); closeIngredientModal(); showToast("Eliminado", 'success'); }
catch(e) { console.error(e); showAlert("No se pudo eliminar.", "Error"); }
};

function updateAdmin() {
document.getElementById('stat-sales').textContent = `$${orders.reduce((s,o)=>s+(o.total||0),0).toLocaleString()}`;
document.getElementById('stat-orders').textContent = orders.length;
renderCalendar();
renderProductStats();
renderAdminMenu();
}

function renderAdminMenu() {
const c = document.getElementById('admin-menu-list');
if (!menuReady) { c.innerHTML = '<p class="text-stone-400 text-xs py-2 text-center col-span-full">Cargando...</p>'; return; }
c.innerHTML = menuItems.map(i => {
const r = Array.isArray(i.recipe) && i.recipe.length
? i.recipe.map(x => { const ing = getIng(x.ingredientId); return ing ? `${x.qty} ${ing.unit} ${ing.name}` : null; }).filter(Boolean).join(' - ')
: 'Sin receta';
return `<div class="bg-stone-50 p-3 rounded-xl text-sm border border-stone-100">
<div class="flex justify-between items-center gap-2">
<div class="flex items-center gap-2 min-w-0">
<div class="w-8 h-8 rounded-lg bg-stone-200 text-stone-700 flex items-center justify-center text-xs shrink-0"><i class="${i.icon}"></i></div>
<div class="min-w-0"><p class="font-bold text-stone-900 truncate">${i.name}</p><p class="text-[10px] text-stone-400 truncate">${i.desc || ''}</p></div>
</div>
<div class="flex items-center gap-2 shrink-0"><span class="font-bold text-amber-600">$${i.price.toLocaleString()}</span><button onclick="openProductModal(${i.id})" class="bg-stone-200 hover:bg-stone-300 px-2 py-1.5 rounded-lg text-[10px] font-bold"><i class="fa-solid fa-pen"></i></button></div>
</div>
<p class="text-[10px] text-stone-500 mt-2 leading-snug">${r}</p>
</div>`;
}).join('');
}

function renderProductStats() {
const counts = {};
menuItems.forEach(m => counts[m.id] = { name: m.name, qty: 0 });
orders.forEach(o => (o.items||[]).forEach(it => {
if (counts[it.id]) counts[it.id].qty += it.qty;
else counts[it.id] = { name: it.name, qty: it.qty };
}));
const arr = Object.values(counts).filter(x=>x.qty>0).sort((a,b)=>b.qty-a.qty);
const top = arr.slice(0,3), bot = arr.slice(-3).reverse();
document.getElementById('stats-top-products').innerHTML = top.length
? top.map((p,i)=>`<div class="flex justify-between items-center bg-emerald-50 p-2 rounded-lg text-xs border border-emerald-100"><span class="font-semibold text-emerald-800">${i+1}. ${p.name}</span><span class="font-bold text-emerald-700">${p.qty} und</span></div>`).join('')
: '<p class="text-stone-400 text-xs py-1 text-center">Sin ventas aun.</p>';
document.getElementById('stats-bottom-products').innerHTML = bot.length
? bot.map((p,i)=>`<div class="flex justify-between items-center bg-rose-50 p-2 rounded-lg text-xs border border-rose-100"><span class="font-semibold text-rose-800">${i+1}. ${p.name}</span><span class="font-bold text-rose-700">${p.qty} und</span></div>`).join('')
: '<p class="text-stone-400 text-xs py-1 text-center">Sin ventas aun.</p>';
}

window.openProductModal = (productId) => {
const modal = document.getElementById('product-modal');
const title = document.getElementById('product-modal-title');
const name = document.getElementById('product-modal-name');
const desc = document.getElementById('product-modal-desc');
const price = document.getElementById('product-modal-price');
const icon = document.getElementById('product-modal-icon');
const del = document.getElementById('product-modal-delete');
if (productId) {
const p = menuItems.find(m => m.id === productId);
if (!p) return;
editingProductId = productId;
editingProductRecipe = Array.isArray(p.recipe) ? p.recipe.map(r => ({...r})) : [];
title.textContent = 'Editar Producto';
name.value = p.name; desc.value = p.desc || ''; price.value = p.price; icon.value = p.icon;
del.classList.remove('hidden');
} else {
editingProductId = null; editingProductRecipe = [];
title.textContent = 'Nuevo Producto';
name.value = ''; desc.value = ''; price.value = 10000; icon.value = 'fa-solid fa-hotdog';
del.classList.add('hidden');
}
renderProductRecipe();
modal.classList.remove('hidden');
setTimeout(() => name.focus(), 150);
};

window.closeProductModal = () => { document.getElementById('product-modal').classList.add('hidden'); editingProductId = null; editingProductRecipe = []; };

function renderProductRecipe() {
const c = document.getElementById('product-modal-recipe');
if (!inventory.length) { c.innerHTML = '<p class="text-stone-400 text-xs py-2 text-center col-span-full">No hay ingredientes creados. Ve a Inventario para crearlos.</p>'; return; }
const sortedInventory = [...inventory].sort((a, b) => {
    const aQty = editingProductRecipe.find(r => r.ingredientId === a.id)?.qty || 0;
    const bQty = editingProductRecipe.find(r => r.ingredientId === b.id)?.qty || 0;
    return bQty - aQty;
});
c.innerHTML = sortedInventory.map(ing => {
    const found = editingProductRecipe.find(r => r.ingredientId === ing.id);
    const qty = found ? found.qty : 0;
    const isActive = qty > 0;
    return `<div class="flex justify-between items-center bg-white p-2 rounded-lg border ${isActive ? 'border-amber-400 shadow-sm' : 'border-stone-200 opacity-70'} transition-all">
    <span class="text-xs font-semibold text-stone-700 truncate ${isActive ? 'text-stone-900' : ''}">${ing.name}</span>
    <div class="flex items-center gap-2">
    <input type="number" min="0" value="${qty}" onchange="updateRecipeQty(${ing.id},this.value)" class="w-16 text-center text-sm font-bold bg-stone-50 border border-stone-200 rounded-lg py-1 focus:outline-none focus:border-amber-600">
    <span class="text-[10px] text-stone-400 w-6">${ing.unit}</span>
    ${isActive ? `<button onclick="updateRecipeQty(${ing.id}, 0)" class="text-rose-500 hover:text-rose-700 p-1"><i class="fa-solid fa-xmark text-sm"></i></button>` : `<div class="w-6"></div>`}
    </div>
    </div>`;
}).join('');
}).join('');
}

window.updateRecipeQty = (ingId, val) => {
    const q = parseInt(val) || 0;
    const idx = editingProductRecipe.findIndex(r => r.ingredientId === ingId);
    if (q <= 0) { if (idx >= 0) editingProductRecipe.splice(idx,1); }
    else { if (idx >= 0) editingProductRecipe[idx].qty = q; else editingProductRecipe.push({ ingredientId: ingId, qty: q }); }
    renderProductRecipe();
};

window.saveProduct = async () => {
const name = document.getElementById('product-modal-name').value.trim().toUpperCase();
const desc = document.getElementById('product-modal-desc').value.trim();
const price = parseInt(document.getElementById('product-modal-price').value) || 0;
const icon = document.getElementById('product-modal-icon').value;
if (!name) { showAlert("Escribe un nombre."); return; }
if (price <= 0) { showAlert("Precio invalido."); return; }
try {
if (editingProductId) {
const p = menuItems.find(m => m.id === editingProductId);
if (!p) return;
await updateDoc(doc(menuCol(), p.firebaseId), { name, desc, price, icon, recipe: editingProductRecipe });
} else {
const maxId = menuItems.reduce((m,i) => Math.max(m, i.id||0), 0);
const newId = maxId + 1;
await setDoc(doc(menuCol(), `item_${newId}_${Date.now()}`), { id: newId, name, desc, price, icon, recipe: editingProductRecipe });
}
closeProductModal();
showToast("Producto guardado", 'success');
} catch(e) { console.error(e); showAlert("No se pudo guardar.", "Error"); }
};

window.deleteProductFromModal = async () => {
if (!editingProductId || !confirm("Eliminar este producto?")) return;
const p = menuItems.find(m => m.id === editingProductId);
if (!p) return;
try { await deleteDoc(doc(menuCol(), p.firebaseId)); closeProductModal(); showToast("Producto eliminado", 'success'); }
catch(e) { console.error(e); showAlert("No se pudo eliminar.", "Error"); }
};

const MONTHS = ['Enero','Febrero','Marzo','Abril','Mayo','Junio','Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'];

window.changeCalendarMonth = (d) => {
calMonth += d;
if (calMonth < 0) { calMonth = 11; calYear--; }
if (calMonth > 11) { calMonth = 0; calYear++; }
renderCalendar();
};

window.selectSaleDate = (k) => { selDate = (selDate === k) ? null : k; renderCalendar(); };

function renderCalendar() {
document.getElementById('calendar-month-label').textContent = `${MONTHS[calMonth]} ${calYear}`;
const grid = document.getElementById('calendar-grid');
const first = new Date(calYear, calMonth, 1);
const days = new Date(calYear, calMonth+1, 0).getDate();
let start = (first.getDay() + 6) % 7;
const totals = {};
orders.forEach(o => {
if (!o.timestamp) return;
const d = new Date(o.timestamp);
if (d.getFullYear() !== calYear || d.getMonth() !== calMonth) return;
totals[d.getDate()] = (totals[d.getDate()]||0) + (o.total||0);
});
const today = todayKey();
let html = '';
for (let i = 0; i < start; i++) html += '<div class="aspect-square"></div>';
for (let d = 1; d <= days; d++) {
const key = `${calYear}-${String(calMonth+1).padStart(2,'0')}-${String(d).padStart(2,'0')}`;
const tot = totals[d] || 0, has = tot > 0, sel = selDate === key, isT = key === today;
let cls = 'aspect-square rounded-lg flex flex-col items-center justify-center transition border text-[11px] relative ';
if (sel) cls += 'bg-amber-500 text-white border-amber-500 font-bold ';
else if (has) cls += 'bg-emerald-50 text-emerald-800 border-emerald-200 font-bold ';
else cls += 'text-stone-700 border-stone-100 hover:bg-stone-50 ';
if (isT && !sel) cls += 'ring-2 ring-amber-400 ';
html += `<button onclick="selectSaleDate('${key}')" class="${cls}"><span>${d}</span>${has?`<span class="text-[7px] leading-none ${sel?'opacity-90':''}">$${fmtShort(tot)}</span>`:''}</button>`;
}
grid.innerHTML = html;
const sumEl = document.getElementById('calendar-day-summary');
const det = document.getElementById('calendar-day-detail');
if (!selDate) { sumEl.classList.add('hidden'); det.innerHTML = '<p class="text-stone-400 text-xs py-2 text-center">Toca un dia del calendario.</p>'; return; }
const dayOrders = ordersOfDate(selDate).sort((a,b)=>(a.timestamp||0)-(b.timestamp||0));
const dayTot = dayOrders.reduce((s,o)=>s+(o.total||0),0);
sumEl.classList.remove('hidden');
const [y,m,dd] = selDate.split('-');
document.getElementById('calendar-day-summary-text').textContent = `${dayOrders.length} pedido${dayOrders.length===1?'':'s'} el ${dd}/${m}/${y}`;
document.getElementById('calendar-day-summary-total').textContent = `$${dayTot.toLocaleString()}`;
det.innerHTML = dayOrders.length ? dayOrders.map(o => `
<div class="flex justify-between items-center bg-stone-50 p-2.5 rounded-xl border border-stone-100 text-xs">
<div class="min-w-0 flex-1">
<div class="flex items-center gap-1.5 flex-wrap"><span class="font-bold text-stone-900">#${o.id} - ${o.customer}</span><span class="text-[10px] text-stone-400">${o.time||''}</span></div>
<div class="text-[10px] text-stone-400 truncate">${(o.items||[]).map(i=>`${i.qty}x${i.name}`).join(', ')}</div>
</div>
<div class="text-right shrink-0 ml-2 flex flex-col items-end gap-1">
<span class="font-bold text-amber-600">$${(o.total||0).toLocaleString()}</span>
<button onclick="openEditSale('${o.firebaseId}')" class="bg-stone-200 hover:bg-stone-300 px-2 py-0.5 rounded text-[9px] font-bold"><i class="fa-solid fa-pen"></i></button>
</div>
</div>`).join('') : '<p class="text-stone-400 text-xs py-2 text-center">Sin ventas ese dia.</p>';
}

window.openEditSale = (fbId) => {
const o = orders.find(x => x.firebaseId === fbId);
if (!o) return;
editingSale = {
firebaseId: o.firebaseId, id: o.id, customer: o.customer || 'Cliente',
time: o.time || '', timestamp: o.timestamp || Date.now(), status: o.status || 'pendiente',
items: (o.items||[]).map(i => ({ id:i.id, name:i.name, price:i.price, qty:i.qty })),
originalItems: (o.items||[]).map(i => ({ id:i.id, name:i.name, price:i.price, qty:i.qty }))
};
document.getElementById('edit-sale-id').textContent = `#${editingSale.id}`;
document.getElementById('edit-sale-time').textContent = `Pedido a las ${editingSale.time}`;
document.getElementById('edit-sale-customer').value = editingSale.customer;
renderEditSaleItems();
document.getElementById('edit-sale-modal').classList.remove('hidden');
};

window.closeEditSale = () => { document.getElementById('edit-sale-modal').classList.add('hidden'); editingSale = null; };

function renderEditSaleItems() {
const c = document.getElementById('edit-sale-items');
if (!editingSale || !editingSale.items.length) { c.innerHTML = '<p class="text-stone-400 text-xs py-2 text-center">Sin productos.</p>'; }
else {
c.innerHTML = editingSale.items.map((it, idx) => `
<div class="flex flex-col sm:flex-row sm:items-center gap-2 bg-stone-50 p-2.5 rounded-xl border border-stone-100">
<input type="text" value="${(it.name||'').replace(/"/g,'&quot;')}" oninput="updateSaleItem(${idx},'name',this.value)" class="w-full bg-white sm:bg-transparent px-2 py-1 sm:p-0 rounded border sm:border-0 border-stone-200 text-sm font-semibold focus:outline-none">
<div class="flex items-center justify-between gap-2">
<div class="flex items-center gap-1 bg-white rounded-lg border border-stone-200 px-1.5 py-1">
<button onclick="adjustSaleQty(${idx},-1)" class="text-stone-500 text-sm font-bold w-5 text-center">-</button>
<input type="number" value="${it.qty}" oninput="updateSaleItem(${idx},'qty',this.value)" class="w-8 text-center text-sm font-bold bg-transparent focus:outline-none">
<button onclick="adjustSaleQty(${idx},1)" class="text-stone-500 text-sm font-bold w-5 text-center">+</button>
</div>
<div class="flex items-center bg-white rounded-lg border border-stone-200 px-1.5 py-1"><span class="text-[10px] text-stone-400">$</span><input type="number" value="${it.price}" oninput="updateSaleItem(${idx},'price',this.value)" class="w-16 text-right text-sm font-bold bg-transparent focus:outline-none"></div>
<button onclick="removeSaleItem(${idx})" class="text-rose-500 hover:text-rose-700 p-1"><i class="fa-solid fa-trash"></i></button>
</div>
</div>`).join('');
}
if (editingSale) document.getElementById('edit-sale-total').textContent = `$${editingSale.items.reduce((s,i)=>s+i.price*i.qty,0).toLocaleString()}`;
}

window.updateSaleItem = (idx, field, val) => {
if (!editingSale) return;
const it = editingSale.items[idx];
if (!it) return;
if (field === 'qty') it.qty = Math.max(1, parseInt(val) || 1);
else if (field === 'price') it.price = Math.max(0, parseInt(val) || 0);
else it.name = val;
document.getElementById('edit-sale-total').textContent = `$${editingSale.items.reduce((s,i)=>s+i.price*i.qty,0).toLocaleString()}`;
};

window.adjustSaleQty = (idx, d) => { if (!editingSale) return; const it = editingSale.items[idx]; if (it) { it.qty = Math.max(1, (it.qty||1)+d); renderEditSaleItems(); } };

window.removeSaleItem = (idx) => { if (!editingSale) return; editingSale.items.splice(idx,1); renderEditSaleItems(); };

window.addSaleItem = () => { if (!editingSale) return; editingSale.items.push({ id:0, name:'Producto', price:0, qty:1 }); renderEditSaleItems(); };

window.saveSaleEdit = async () => {
if (!editingSale) return;
const customer = document.getElementById('edit-sale-customer').value.trim() || 'Cliente';
if (!editingSale.items.length) { showAlert("Debe tener al menos un producto."); return; }
const items = editingSale.items.map(i => ({ id:i.id||0, name:i.name||'Producto', price:parseInt(i.price)||0, qty:parseInt(i.qty)||1 }));
const total = items.reduce((s,i)=>s+i.price*i.qty,0);
try {
await applyRecipe(editingSale.originalItems, +1);
await applyRecipe(items, -1);
await updateDoc(doc(ordersCol(), editingSale.firebaseId), { customer, items, total });
closeEditSale(); showToast("Venta actualizada", 'success');
} catch(e) { console.error(e); showAlert("No se pudo guardar.", "Error"); }
};

window.deleteSale = async () => {
if (!editingSale || !confirm(`Eliminar venta #${editingSale.id}?`)) return;
try {
await applyRecipe(editingSale.originalItems, +1);
await deleteDoc(doc(ordersCol(), editingSale.firebaseId));
closeEditSale(); showToast("Venta eliminada", 'success');
} catch(e) { console.error(e); showAlert("No se pudo eliminar.", "Error"); }
};

window.resetData = async () => {
if (!confirm("Borrar TODOS los pedidos?")) return;
try {
for (const o of orders) await deleteDoc(doc(ordersCol(), o.firebaseId));
showToast("Pedidos borrados", 'success');
} catch(e) { console.error(e); showAlert("No se pudo reiniciar.", "Error"); }
};

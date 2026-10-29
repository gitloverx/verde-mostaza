import { auth, db } from "./firebase-init.js";
import { signInWithGoogle, logout } from "./auth.js";
import { doc, getDoc, collection, getDocs, query, where, orderBy, limit }
    from "https://www.gstatic.com/firebasejs/11.6.1/firebase-firestore.js";

let allUsers = [];

window.handleGoogle = async () => {
    try { await signInWithGoogle(); }
    catch(e) { document.getElementById('status').textContent = 'Error: ' + e.message; }
};
window.doLogout = logout;

auth.onAuthStateChanged(async (user) => {
    if (!user) { document.getElementById('login-view').classList.remove('hidden'); document.getElementById('panel').classList.add('hidden'); return; }
    // Verificar si es super admin
    try {
        const sa = await getDoc(doc(db, 'super_admins', user.uid));
        if (!sa.exists()) {
            document.getElementById('status').textContent = '❌ No autorizado como super admin';
            return;
        }
        document.getElementById('login-view').classList.add('hidden');
        document.getElementById('panel').classList.remove('hidden');
        loadAll();
    } catch(e) {
        document.getElementById('status').textContent = 'Error: ' + e.message;
    }
});

async function loadAll() {
    try {
        // KPIs globales
        const gSnap = await getDoc(doc(db, 'stats', 'global'));
        const g = gSnap.exists() ? gSnap.data() : {};
        document.getElementById('kpi-users').textContent  = (g.totalUsers  || 0).toLocaleString();
        document.getElementById('kpi-orders').textContent = (g.totalOrders || 0).toLocaleString();
        document.getElementById('kpi-sales').textContent  = '$' + (g.totalSales || 0).toLocaleString();

        // DAU: usuarios con lastLoginAt en últimas 24h
        const cutoff = Date.now() - 24*3600000;
        const usersSnap = await getDocs(collection(db, 'users'));
        allUsers = usersSnap.docs.map(d => ({ uid: d.id, ...d.data() }));
        const dau = allUsers.filter(u => (u.lastLoginAt?.toMillis?.() || 0) > cutoff).length;
        document.getElementById('kpi-dau').textContent = dau.toLocaleString();

        renderUsers();
        renderTopStores();
        renderChartNew();
    } catch(e) {
        console.error(e);
        alert('Error cargando datos: ' + e.message);
    }
}
window.loadAll = loadAll;

function renderUsers() {
    const q = (document.getElementById('search').value || '').toLowerCase().trim();
    const c = document.getElementById('users-list');
    const list = allUsers.filter(u => {
        if (!q) return true;
        return (u.email||'').toLowerCase().includes(q) || (u.businessName||'').toLowerCase().includes(q);
    }).sort((a,b) => (b.stats?.totalSales||0) - (a.stats?.totalSales||0));
    if (!list.length) { c.innerHTML = '<p class="text-stone-400 text-xs py-3 text-center">Sin usuarios.</p>'; return; }
    c.innerHTML = list.map(u => {
        const last = u.lastLoginAt?.toDate ? u.lastLoginAt.toDate() : (u.lastLoginAt?.toMillis ? new Date(u.lastLoginAt.toMillis()) : null);
        const lastStr = last ? last.toLocaleDateString('es-CO') + ' ' + last.toLocaleTimeString('es-CO',{hour:'2-digit',minute:'2-digit'}) : '—';
        return `<div class="flex justify-between items-center bg-stone-50 p-2.5 rounded-xl border border-stone-100 text-xs">
            <div class="min-w-0 flex-1">
                <div class="font-bold text-stone-900 truncate">${u.businessName || '(sin tienda)'}</div>
                <div class="text-[10px] text-stone-500 truncate">${u.email||''} · /${u.businessSlug||'—'}</div>
                <div class="text-[10px] text-stone-400">Último login: ${lastStr}</div>
            </div>
            <div class="text-right shrink-0 ml-2">
                <div class="font-bold text-amber-600">$${(u.stats?.totalSales||0).toLocaleString()}</div>
                <div class="text-[10px] text-stone-500">${u.stats?.totalOrders||0} pedidos</div>
                <div class="text-[9px] ${u.onboarded?'text-emerald-600':'text-rose-500'} font-bold">${u.onboarded?'✓ Activo':'⚠ Sin onboarding'}</div>
            </div>
        </div>`;
    }).join('');
}
window.renderUsers = renderUsers;

function renderTopStores() {
    const top = [...allUsers].filter(u=>u.stats?.totalSales).sort((a,b)=>(b.stats?.totalSales||0)-(a.stats?.totalSales||0)).slice(0,10);
    document.getElementById('top-stores').innerHTML = top.length ? top.map((u,i)=>`
        <div class="flex justify-between items-center bg-amber-50 p-2 rounded-lg text-xs border border-amber-100">
            <span class="font-semibold text-amber-900 truncate">${i+1}. ${u.businessName||u.email}</span>
            <span class="font-bold text-amber-700 shrink-0 ml-2">$${(u.stats.totalSales||0).toLocaleString()}</span>
        </div>`).join('') : '<p class="text-stone-400 text-xs py-2 text-center">Sin datos aún.</p>';
}

let chartInstance = null;
function renderChartNew() {
    const ctx = document.getElementById('chart-new').getContext('2d');
    const days = [], counts = [];
    for (let i = 13; i >= 0; i--) {
        const d = new Date(); d.setDate(d.getDate() - i);
        const key = `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,'0')}-${String(d.getDate()).padStart(2,'0')}`;
        days.push(d.getDate() + '/' + (d.getMonth()+1));
        const cnt = allUsers.filter(u => {
            const t = u.createdAt?.toMillis?.() || 0;
            if (!t) return false;
            const ud = new Date(t);
            return `${ud.getFullYear()}-${String(ud.getMonth()+1).padStart(2,'0')}-${String(ud.getDate()).padStart(2,'0')}` === key;
        }).length;
        counts.push(cnt);
    }
    if (chartInstance) chartInstance.destroy();
    chartInstance = new Chart(ctx, {
        type: 'bar',
        data: { labels: days, datasets: [{ label: 'Nuevos', data: counts, backgroundColor: '#d4a017', borderRadius: 4 }] },
        options: { plugins: { legend: { display: false } }, scales: { y: { beginAtZero: true, ticks: { stepSize: 1 } } } }
    });
}

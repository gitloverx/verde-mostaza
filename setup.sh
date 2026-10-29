#!/data/data/com.termux/files/usr/bin/bash
# ==============================================================
# VERDE MOSTAZA — Setup completo del proyecto (un solo script)
# ==============================================================
set -e
GREEN='\033[0;32m'; YELLOW='\033[0;33m'; NC='\033[0m'

echo -e "${GREEN}🌱 Creando Verde Mostaza...${NC}"
mkdir -p js assets

# ══════════════════════════════════════════════════════════════
# 1. firebase-config.js
# ══════════════════════════════════════════════════════════════
cat > firebase-config.js << 'END_FIREBASE_CONFIG'
// ⚠️ REEMPLAZA ESTOS VALORES con los de tu proyecto Firebase
// Firebase Console → ⚙️ Project Settings → Tus apps → Web → Config
window.FIREBASE_CONFIG = {
    apiKey:            "REEMPLAZA_API_KEY",
    authDomain:        "REEMPLAZA.firebaseapp.com",
    projectId:         "REEMPLAZA",
    storageBucket:     "REEMPLAZA.appspot.com",
    messagingSenderId: "REEMPLAZA",
    appId:             "REEMPLAZA"
};
END_FIREBASE_CONFIG
echo -e "${GREEN}✓ firebase-config.js${NC}"

# ══════════════════════════════════════════════════════════════
# 2. js/firebase-init.js
# ══════════════════════════════════════════════════════════════
cat > js/firebase-init.js << 'END_FIREBASE_INIT'
import { initializeApp } from "https://www.gstatic.com/firebasejs/11.6.1/firebase-app.js";
import { getAuth } from "https://www.gstatic.com/firebasejs/11.6.1/firebase-auth.js";
import { getFirestore, enableIndexedDbPersistence } from "https://www.gstatic.com/firebasejs/11.6.1/firebase-firestore.js";

const app = initializeApp(window.FIREBASE_CONFIG);
export const auth = getAuth(app);
export const db = getFirestore(app);

// Persistencia offline (reduce reads y permite funcionar sin red)
enableIndexedDbPersistence(db).catch((err) => {
    if (err.code === 'failed-precondition') console.warn("Offline: múltiples pestañas");
    if (err.code === 'unimplemented') console.warn("Offline: no soportado");
});
END_FIREBASE_INIT
echo -e "${GREEN}✓ js/firebase-init.js${NC}"

# ══════════════════════════════════════════════════════════════
# 3. js/auth.js
# ══════════════════════════════════════════════════════════════
cat > js/auth.js << 'END_AUTH'
import { auth, db } from "./firebase-init.js";
import { GoogleAuthProvider, signInWithPopup, signOut, onAuthStateChanged }
    from "https://www.gstatic.com/firebasejs/11.6.1/firebase-auth.js";
import { doc, getDoc, setDoc, updateDoc, serverTimestamp }
    from "https://www.gstatic.com/firebasejs/11.6.1/firebase-firestore.js";

const provider = new GoogleAuthProvider();

export async function signInWithGoogle() {
    const r = await signInWithPopup(auth, provider);
    return r.user;
}

export async function logout() {
    await signOut(auth);
    window.location.href = "index.html";
}

export function watchAuth(cb) {
    onAuthStateChanged(auth, async (user) => {
        if (!user) { cb(null, null); return; }
        const ref = doc(db, 'users', user.uid);
        let snap = await getDoc(ref);
        if (!snap.exists()) {
            await setDoc(ref, {
                email: user.email,
                displayName: user.displayName || 'Usuario',
                photoURL: user.photoURL || '',
                onboarded: false,
                createdAt: serverTimestamp(),
                lastLoginAt: serverTimestamp(),
                stats: { totalOrders: 0, totalSales: 0 }
            });
            snap = await getDoc(ref);
        } else {
            const d = snap.data();
            const last = d.lastLoginAt?.toMillis?.() || 0;
            if (Date.now() - last > 3600000) {
                updateDoc(ref, { lastLoginAt: serverTimestamp() }).catch(()=>{});
            }
        }
        cb(user, { uid: user.uid, ...snap.data() });
    });
}
END_AUTH
echo -e "${GREEN}✓ js/auth.js${NC}"

# ══════════════════════════════════════════════════════════════
# 4. js/ui.js
# ══════════════════════════════════════════════════════════════
cat > js/ui.js << 'END_UI'
export function showToast(msg, type='info') {
    const colors = { info:'bg-stone-900', success:'bg-emerald-600', error:'bg-rose-600', warn:'bg-amber-600' };
    const el = document.createElement('div');
    el.className = `fixed top-4 left-1/2 -translate-x-1/2 z-[100] ${colors[type]||colors.info} text-white text-xs font-bold px-4 py-2.5 rounded-xl shadow-lg`;
    el.textContent = msg;
    document.body.appendChild(el);
    setTimeout(() => el.remove(), 2800);
}

export function showAlert(msg, title='Aviso') {
    const m = document.getElementById('custom-modal');
    if (!m) { alert(msg); return; }
    document.getElementById('modal-title').textContent = title;
    document.getElementById('modal-message').textContent = msg;
    m.classList.remove('hidden');
}

export function closeModal() {
    document.getElementById('custom-modal')?.classList.add('hidden');
}

// Globales para onclick
window.showAlert = showAlert;
window.closeModal = closeModal;
END_UI
echo -e "${GREEN}✓ js/ui.js${NC}"

# ══════════════════════════════════════════════════════════════
# 5. index.html (landing + Google login)
# ══════════════════════════════════════════════════════════════
cat > index.html << 'END_INDEX_HTML'
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="theme-color" content="#d4a017">
    <title>Verde Mostaza — Tu puesto, organizado</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700;800;900&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <link rel="manifest" href="manifest.json">
    <script>
        tailwind.config = { theme: { extend: {
            colors: { brand: { 50:'#fef8e7',100:'#fcefc8',600:'#d4a017',700:'#a87f0f',900:'#3f2f05' } },
            fontFamily: { sans: ['Inter','sans-serif'] }
        }}}
    </script>
    <style>body{-webkit-tap-highlight-color:transparent}</style>
</head>
<body class="bg-stone-100 text-stone-800 font-sans min-h-screen flex flex-col">

    <main class="flex-1 flex flex-col items-center justify-center px-6 py-10">
        <div class="w-20 h-20 bg-gradient-to-br from-amber-400 to-amber-600 text-white rounded-3xl flex items-center justify-center text-4xl mb-5 shadow-2xl shadow-amber-500/40">
            <i class="fa-solid fa-seedling"></i>
        </div>

        <h1 class="font-black text-3xl text-stone-900 tracking-tight text-center">VERDE MOSTAZA</h1>
        <p class="text-sm text-stone-500 text-center mt-2 max-w-xs">Tu puesto de comida, con la organización de un restaurante.</p>

        <div class="w-full max-w-xs mt-8 space-y-3">
            <button id="btn-google" onclick="handleGoogle()"
                class="w-full bg-white hover:bg-stone-50 text-stone-900 font-bold py-3.5 rounded-xl text-sm shadow-md border border-stone-200 flex items-center justify-center gap-3 active:scale-[0.98] transition">
                <svg width="18" height="18" viewBox="0 0 48 48"><path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/><path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/><path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/><path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/></svg>
                Continuar con Google
            </button>
            <p id="status" class="text-[11px] text-stone-400 text-center"></p>
        </div>

        <div class="mt-10 text-[11px] text-stone-400 space-y-2 text-center">
            <p><i class="fa-solid fa-lock text-[10px]"></i> Tus datos son privados. Cada negocio tiene su propio espacio.</p>
            <a href="admin.html" class="text-stone-500 hover:text-brand-700 underline">Acceso administrador</a>
        </div>
    </main>

    <script src="firebase-config.js"></script>
    <script type="module">
        import { signInWithGoogle, watchAuth } from "./js/auth.js";
        window.handleGoogle = async () => {
            const btn = document.getElementById('btn-google');
            const status = document.getElementById('status');
            btn.disabled = true; status.textContent = 'Conectando...';
            try {
                await signInWithGoogle();
            } catch (e) {
                console.error(e);
                status.textContent = 'Error: ' + (e.message || 'intenta de nuevo');
                btn.disabled = false;
            }
        };
        watchAuth((user, profile) => {
            if (!user) return;
            document.getElementById('status').textContent = '¡Bienvenido ' + (profile?.displayName || user.email) + '!';
            setTimeout(() => {
                window.location.href = profile?.onboarded ? 'app.html' : 'onboarding.html';
            }, 500);
        });
    </script>
</body>
</html>
END_INDEX_HTML
echo -e "${GREEN}✓ index.html${NC}"

# ══════════════════════════════════════════════════════════════
# 6. onboarding.html
# ══════════════════════════════════════════════════════════════
cat > onboarding.html << 'END_ONBOARDING_HTML'
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta name="theme-color" content="#d4a017">
    <title>Crear mi tienda — Verde Mostaza</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700;800;900&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <script>tailwind.config={theme:{extend:{colors:{brand:{600:'#d4a017',700:'#a87f0f'}},fontFamily:{sans:['Inter','sans-serif']}}}}</script>
</head>
<body class="bg-stone-100 text-stone-800 font-sans min-h-screen flex flex-col pb-10">
    <header class="bg-white border-b border-stone-200 sticky top-0 z-40 px-4 py-3 flex items-center gap-2">
        <div class="bg-amber-500 text-white w-8 h-8 rounded-xl flex items-center justify-center text-sm">
            <i class="fa-solid fa-seedling"></i>
        </div>
        <h1 class="font-black text-xs text-stone-900">CREAR MI TIENDA</h1>
    </header>

    <main class="flex-1 max-w-md w-full mx-auto p-4 space-y-4">
        <div class="bg-amber-50 border border-amber-200 rounded-2xl p-3 text-[12px] text-amber-900">
            <i class="fa-solid fa-circle-info"></i> Completa los datos de tu puesto. Solo se hace una vez.
        </div>

        <div class="bg-white rounded-2xl p-4 shadow-xs border border-stone-200 space-y-3">
            <div>
                <label class="text-[10px] font-bold text-stone-400 uppercase tracking-wider">Nombre del negocio</label>
                <input id="bname" type="text" placeholder="Ej: Perros de Juan" oninput="suggestSlug()"
                    class="w-full bg-stone-100 border border-stone-200 rounded-xl px-3 py-2.5 text-sm font-bold focus:outline-none focus:border-brand-600 transition">
            </div>
            <div>
                <label class="text-[10px] font-bold text-stone-400 uppercase tracking-wider">Slug único (URL de tu negocio)</label>
                <div class="flex items-center bg-stone-100 border border-stone-200 rounded-xl px-3 py-2.5 text-sm">
                    <span class="text-stone-400 text-[11px]">verdemostaza.app/</span>
                    <input id="bslug" type="text" placeholder="perros-juan" oninput="checkSlugAvailability()"
                        class="flex-1 bg-transparent font-bold focus:outline-none ml-1">
                </div>
                <p id="slug-status" class="text-[10px] mt-1 text-stone-400">Se genera automáticamente.</p>
            </div>
            <div>
                <label class="text-[10px] font-bold text-stone-400 uppercase tracking-wider">PIN de tu negocio (opcional, 4 dígitos)</label>
                <input id="bpin" type="password" maxlength="4" inputmode="numeric" placeholder="0000"
                    class="w-full bg-stone-100 border border-stone-200 rounded-xl px-3 py-2.5 text-sm font-bold text-center tracking-widest focus:outline-none focus:border-brand-600 transition">
                <p class="text-[10px] text-stone-400 mt-1">Si lo pones, se pedirá al abrir la app. Puedes dejarlo vacío.</p>
            </div>
            <div>
                <label class="text-[10px] font-bold text-stone-400 uppercase tracking-wider">Tema</label>
                <select id="btheme" class="w-full bg-stone-100 border border-stone-200 rounded-xl px-3 py-2.5 text-sm font-bold focus:outline-none focus:border-brand-600 transition">
                    <option value="mustard">Mostaza (clásico)</option>
                    <option value="olive">Verde oliva</option>
                    <option value="rose">Rosa (como Pan al Chori)</option>
                </select>
            </div>
            <button id="btn-create" onclick="createBusiness()"
                class="w-full bg-stone-900 hover:bg-stone-800 text-white font-bold py-3 rounded-xl text-xs shadow-md active:scale-[0.98] transition">
                <i class="fa-solid fa-check"></i> Crear mi tienda
            </button>
        </div>

        <p id="message" class="text-xs text-center text-rose-600"></p>
    </main>

    <script src="firebase-config.js"></script>
    <script type="module">
        import { auth, db } from "./js/firebase-init.js";
        import { watchAuth } from "./js/auth.js";
        import { doc, getDoc, setDoc, updateDoc, increment, serverTimestamp }
            from "https://www.gstatic.com/firebasejs/11.6.1/firebase-firestore.js";
        import { showToast, showAlert } from "./js/ui.js";

        let currentUid = null;

        watchAuth((user, profile) => {
            if (!user) { window.location.href = 'index.html'; return; }
            currentUid = user.uid;
            if (profile?.onboarded) { window.location.href = 'app.html'; return; }
            if (profile?.businessName) document.getElementById('bname').value = profile.businessName;
        });

        window.suggestSlug = () => {
            const name = document.getElementById('bname').value.trim().toLowerCase();
            const slug = name.normalize('NFD').replace(/[\u0300-\u036f]/g,'')
                .replace(/[^a-z0-9]+/g,'-').replace(/^-+|-+$/g,'').slice(0,30);
            document.getElementById('bslug').value = slug;
            checkSlugAvailability();
        };

        window.checkSlugAvailability = async () => {
            const slug = document.getElementById('bslug').value.trim().toLowerCase();
            const status = document.getElementById('slug-status');
            if (!slug) { status.textContent = 'Se genera automáticamente.'; status.className = 'text-[10px] mt-1 text-stone-400'; return; }
            if (slug.length < 3) { status.textContent = 'Mínimo 3 caracteres'; status.className = 'text-[10px] mt-1 text-rose-600'; return; }
            status.textContent = 'Verificando...'; status.className = 'text-[10px] mt-1 text-stone-400';
            try {
                const snap = await getDoc(doc(db, 'business_slugs', slug));
                if (snap.exists()) { status.textContent = '✗ Ese slug ya está en uso'; status.className = 'text-[10px] mt-1 text-rose-600'; }
                else { status.textContent = '✓ Disponible'; status.className = 'text-[10px] mt-1 text-emerald-600'; }
            } catch (e) { status.textContent = 'Error verificando'; }
        };

        async function sha256(str) {
            const buf = new TextEncoder().encode(str);
            const h = await crypto.subtle.digest('SHA-256', buf);
            return Array.from(new Uint8Array(h)).map(b => b.toString(16).padStart(2,'0')).join('');
        }

        window.createBusiness = async () => {
            if (!currentUid) return;
            const name = document.getElementById('bname').value.trim();
            const slug = document.getElementById('bslug').value.trim().toLowerCase();
            const pin = document.getElementById('bpin').value.trim();
            const theme = document.getElementById('btheme').value;
            const msg = document.getElementById('message');

            if (name.length < 2) { msg.textContent = 'Escribe el nombre de tu negocio.'; return; }
            if (slug.length < 3) { msg.textContent = 'El slug debe tener al menos 3 caracteres.'; return; }
            if (pin && !/^\d{4}$/.test(pin)) { msg.textContent = 'El PIN debe ser 4 dígitos o vacío.'; return; }

            const btn = document.getElementById('btn-create');
            btn.disabled = true; msg.textContent = '';

            try {
                const slugRef = doc(db, 'business_slugs', slug);
                const slugSnap = await getDoc(slugRef);
                if (slugSnap.exists()) { msg.textContent = 'Ese slug ya está en uso, elige otro.'; btn.disabled = false; return; }

                await setDoc(slugRef, { uid: currentUid, businessName: name, createdAt: serverTimestamp() });

                const pinHash = pin ? await sha256(pin) : null;
                await updateDoc(doc(db, 'users', currentUid), {
                    businessName: name, businessSlug: slug, businessPinHash: pinHash,
                    theme, onboarded: true, onboardedAt: serverTimestamp()
                });

                // Incrementar contador global
                const globalRef = doc(db, 'stats', 'global');
                const gSnap = await getDoc(globalRef);
                if (gSnap.exists()) {
                    await updateDoc(globalRef, { totalUsers: increment(1), lastUpdated: serverTimestamp() });
                } else {
                    await setDoc(globalRef, { totalUsers: 1, totalOrders: 0, totalSales: 0, lastUpdated: serverTimestamp() });
                }

                showToast('¡Tienda creada!', 'success');
                setTimeout(() => window.location.href = 'app.html', 800);
            } catch (e) {
                console.error(e);
                msg.textContent = 'Error: ' + (e.message || 'intenta de nuevo');
                btn.disabled = false;
            }
        };
    </script>
</body>
</html>
END_ONBOARDING_HTML
echo -e "${GREEN}✓ onboarding.html${NC}"

# ══════════════════════════════════════════════════════════════
# 7. app.html (la app principal — Pan al Chori refactorizada)
# ══════════════════════════════════════════════════════════════
cat > app.html << 'END_APP_HTML'
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
    <meta name="theme-color" content="#d4a017">
    <title>Verde Mostaza</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800;900&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <link rel="manifest" href="manifest.json">
    <script>tailwind.config={theme:{extend:{colors:{brand:{50:'#fef8e7',100:'#fcefc8',600:'#d4a017',700:'#a87f0f',900:'#3f2f05'}},fontFamily:{sans:['Inter','sans-serif']}}}}</script>
    <style>
        body{-webkit-tap-highlight-color:transparent;touch-action:manipulation}
        @keyframes urgentPulse{0%,100%{box-shadow:0 0 0 0 rgba(225,29,72,.7)}50%{box-shadow:0 0 0 4px rgba(225,29,72,0)}}
        .urgent-pulse{animation:urgentPulse 1.5s infinite}
    </style>
</head>
<body class="bg-stone-100 text-stone-800 font-sans min-h-screen flex flex-col pb-20 select-none">

<div id="loading" class="fixed inset-0 bg-stone-100 flex flex-col items-center justify-center z-50">
    <div class="w-14 h-14 bg-amber-500 text-white rounded-2xl flex items-center justify-center text-2xl animate-pulse"><i class="fa-solid fa-seedling"></i></div>
    <p class="text-xs text-stone-500 mt-3">Cargando tu tienda...</p>
</div>

<div id="main-app" class="hidden flex-1 flex flex-col">
    <header class="bg-white border-b border-stone-200 sticky top-0 z-40 px-4 py-3 flex justify-between items-center">
        <div class="flex items-center gap-2">
            <div id="brand-icon" class="bg-amber-500 text-white w-8 h-8 rounded-xl flex items-center justify-center text-sm">
                <i class="fa-solid fa-seedling"></i>
            </div>
            <div>
                <h1 id="biz-name" class="font-black text-xs tracking-tight text-stone-900 leading-none">VERDE MOSTAZA</h1>
                <span id="active-role-label" class="text-[10px] text-stone-400 font-semibold uppercase tracking-wider">Caja</span>
            </div>
        </div>
        <div class="flex items-center gap-2">
            <span id="sync-indicator" class="flex h-2 w-2 relative" title="Conectando..."><span class="relative inline-flex rounded-full h-2 w-2 bg-stone-400"></span></span>
            <button onclick="doLogout()" class="text-stone-400 hover:text-rose-600 p-2 text-xs rounded-xl"><i class="fa-solid fa-right-from-bracket"></i></button>
        </div>
    </header>

    <main class="flex-1 max-w-md w-full mx-auto p-3 space-y-3">
        <!-- CAJERO -->
        <div id="view-cajero" class="space-y-3">
            <div class="bg-white rounded-2xl p-2.5 shadow-xs border border-stone-200 flex gap-2 items-center">
                <i class="fa-solid fa-user text-stone-400 pl-2 text-xs"></i>
                <input id="customer-name" type="text" placeholder="Nombre cliente..." class="w-full bg-transparent text-sm focus:outline-none font-medium placeholder:text-stone-400">
            </div>
            <div class="space-y-2">
                <div class="flex justify-between items-center px-1">
                    <span class="text-[11px] font-bold text-stone-400 uppercase tracking-wider">Menú Rápido</span>
                    <span class="text-[10px] text-amber-600 font-semibold" id="menu-prices-summary">Cargando...</span>
                </div>
                <div id="menu-grid" class="grid grid-cols-1 gap-2"></div>
            </div>
            <div class="bg-white rounded-2xl p-3.5 shadow-sm border border-stone-200 space-y-3">
                <div class="flex justify-between items-center border-b border-stone-100 pb-2">
                    <span class="font-bold text-xs text-stone-900 flex items-center gap-1.5 uppercase tracking-wide"><i class="fa-solid fa-receipt text-amber-600"></i> Pedido Actual</span>
                    <button onclick="clearCart()" class="text-[11px] text-stone-400 hover:text-rose-600 font-medium">Vaciar</button>
                </div>
                <div id="cart-items" class="divide-y divide-stone-100 max-h-36 overflow-y-auto space-y-1 pr-1 text-xs">
                    <p class="text-stone-400 text-xs py-2 text-center">Sin items en el pedido</p>
                </div>
                <div class="border-t border-stone-100 pt-2 flex justify-between items-center">
                    <span class="text-[11px] text-stone-500 uppercase font-bold">Total:</span>
                    <span id="cart-total" class="text-amber-600 font-black text-base">$0</span>
                </div>
                <button onclick="submitOrder()" id="btn-submit" class="w-full bg-stone-900 hover:bg-stone-800 text-white font-bold py-3 rounded-xl text-xs shadow-xs active:scale-[0.98] transition flex items-center justify-center gap-2 disabled:opacity-40">
                    <i class="fa-solid fa-check text-xs"></i> Enviar a Cocina
                </button>
            </div>
            <div class="bg-white rounded-2xl p-3.5 shadow-xs border border-stone-200 space-y-2">
                <span class="text-[11px] font-bold text-stone-400 uppercase tracking-wider">Últimos Pedidos</span>
                <div id="cashier-orders-list" class="space-y-2 max-h-40 overflow-y-auto"></div>
            </div>
        </div>

        <!-- COCINERO -->
        <div id="view-cocinero" class="hidden space-y-3">
            <div class="flex justify-between items-center px-1">
                <span class="text-[11px] font-bold text-stone-400 uppercase tracking-wider">Cocina (En Vivo)</span>
                <span id="kitchen-count" class="bg-amber-100 text-amber-800 text-[11px] px-2 py-0.5 rounded-full font-bold">0 pendientes</span>
            </div>
            <div id="kitchen-orders-list" class="space-y-2.5"></div>
        </div>

        <!-- INVENTARIO -->
        <div id="view-inventario" class="hidden space-y-3">
            <div class="flex justify-between items-center px-1">
                <span class="text-[11px] font-bold text-stone-400 uppercase tracking-wider">Inventario</span>
                <button onclick="openIngredientModal()" class="bg-stone-900 hover:bg-stone-800 text-white text-[11px] font-bold px-3 py-1.5 rounded-lg"><i class="fa-solid fa-plus"></i> Nuevo ingrediente</button>
            </div>
            <div id="inventory-list" class="space-y-2"></div>
            <div class="bg-white rounded-2xl p-3.5 shadow-xs border border-stone-200 space-y-2 mt-2">
                <span class="text-[11px] font-bold text-stone-400 uppercase tracking-wider">Consumo de Ingredientes (hoy)</span>
                <div id="ingredient-usage-stats" class="space-y-2"></div>
            </div>
        </div>

        <!-- ADMIN -->
        <div id="view-admin" class="hidden space-y-3">
            <div class="grid grid-cols-2 gap-2.5">
                <div class="bg-white p-3 rounded-2xl shadow-xs border border-stone-200"><span class="text-[10px] uppercase font-bold text-stone-400">Ventas Totales</span><h3 id="stat-sales" class="text-base font-black text-stone-900 mt-1">$0</h3></div>
                <div class="bg-white p-3 rounded-2xl shadow-xs border border-stone-200"><span class="text-[10px] uppercase font-bold text-stone-400">Total Pedidos</span><h3 id="stat-orders" class="text-base font-black text-stone-900 mt-1">0</h3></div>
            </div>
            <div class="bg-white rounded-2xl p-3.5 shadow-xs border border-stone-200 space-y-2">
                <div class="flex justify-between items-center">
                    <span class="text-[11px] font-bold text-stone-400 uppercase tracking-wider">Ventas por Día</span>
                    <div class="flex items-center gap-1">
                        <button onclick="changeCalendarMonth(-1)" class="w-7 h-7 bg-stone-100 hover:bg-stone-200 rounded-lg text-xs font-bold flex items-center justify-center">‹</button>
                        <span id="calendar-month-label" class="text-[11px] font-bold text-stone-800 min-w-[92px] text-center">-</span>
                        <button onclick="changeCalendarMonth(1)" class="w-7 h-7 bg-stone-100 hover:bg-stone-200 rounded-lg text-xs font-bold flex items-center justify-center">›</button>
                    </div>
                </div>
                <div class="grid grid-cols-7 gap-1 text-center">
                    <span class="text-[9px] font-bold text-stone-400">Lu</span><span class="text-[9px] font-bold text-stone-400">Ma</span><span class="text-[9px] font-bold text-stone-400">Mi</span><span class="text-[9px] font-bold text-stone-400">Ju</span><span class="text-[9px] font-bold text-stone-400">Vi</span><span class="text-[9px] font-bold text-stone-400">Sá</span><span class="text-[9px] font-bold text-stone-400">Do</span>
                </div>
                <div id="calendar-grid" class="grid grid-cols-7 gap-1"></div>
                <div id="calendar-day-summary" class="hidden text-[11px] text-stone-600 bg-stone-50 rounded-xl px-3 py-2 border border-stone-100 flex justify-between items-center">
                    <span id="calendar-day-summary-text">-</span><span id="calendar-day-summary-total" class="font-black text-amber-600">$0</span>
                </div>
                <div id="calendar-day-detail" class="space-y-2 max-h-72 overflow-y-auto"></div>
            </div>
            <div class="bg-white rounded-2xl p-3.5 shadow-xs border border-stone-200 space-y-3">
                <span class="text-[11px] font-bold text-stone-400 uppercase tracking-wider">Estadísticas</span>
                <div><p class="text-[10px] font-bold text-emerald-700 uppercase tracking-wider mb-1"><i class="fa-solid fa-arrow-trend-up"></i> Más vendidos</p><div id="stats-top-products" class="space-y-1"></div></div>
                <div><p class="text-[10px] font-bold text-rose-600 uppercase tracking-wider mb-1"><i class="fa-solid fa-arrow-trend-down"></i> Menos vendidos</p><div id="stats-bottom-products" class="space-y-1"></div></div>
            </div>
            <div class="bg-white rounded-2xl p-3.5 shadow-xs border border-stone-200 space-y-2">
                <div class="flex justify-between items-center">
                    <span class="text-[11px] font-bold text-stone-400 uppercase tracking-wider">Productos</span>
                    <button onclick="openProductModal()" class="bg-stone-900 hover:bg-stone-800 text-white text-[11px] font-bold px-3 py-1.5 rounded-lg"><i class="fa-solid fa-plus"></i> Nuevo producto</button>
                </div>
                <div id="admin-menu-list" class="space-y-2 max-h-96 overflow-y-auto"></div>
            </div>
            <button onclick="resetData()" class="w-full bg-white hover:bg-rose-50 text-stone-600 hover:text-rose-600 font-bold py-2.5 rounded-xl text-xs transition border border-stone-200"><i class="fa-solid fa-rotate-right mr-1"></i> Reiniciar Pedidos</button>
        </div>
    </main>

    <nav class="fixed bottom-0 left-0 right-0 bg-white/95 backdrop-blur-md border-t border-stone-200 py-2 px-3 flex justify-around items-center z-40 max-w-md mx-auto">
        <button onclick="switchRole('cajero')" id="nav-btn-cajero" class="flex flex-col items-center gap-1 text-amber-600 transition"><i class="fa-solid fa-cash-register text-base"></i><span class="text-[10px] font-bold">Caja</span></button>
        <button onclick="switchRole('cocinero')" id="nav-btn-cocinero" class="flex flex-col items-center gap-1 text-stone-400 hover:text-stone-700 transition"><i class="fa-solid fa-fire-burner text-base"></i><span class="text-[10px] font-bold">Cocina</span></button>
        <button onclick="switchRole('inventario')" id="nav-btn-inventario" class="flex flex-col items-center gap-1 text-stone-400 hover:text-stone-700 transition"><i class="fa-solid fa-boxes-stacked text-base"></i><span class="text-[10px] font-bold">Inventario</span></button>
        <button onclick="switchRole('admin')" id="nav-btn-admin" class="flex flex-col items-center gap-1 text-stone-400 hover:text-stone-700 transition"><i class="fa-solid fa-chart-pie text-base"></i><span class="text-[10px] font-bold">Admin</span></button>
    </nav>
</div>

<!-- MODAL GENÉRICO -->
<div id="custom-modal" class="fixed inset-0 bg-stone-900/40 backdrop-blur-xs z-[60] hidden flex items-center justify-center p-4">
    <div class="bg-white rounded-2xl p-5 max-w-xs w-full shadow-xl space-y-3 text-center border border-stone-100">
        <div class="w-10 h-10 bg-stone-100 text-stone-900 rounded-full flex items-center justify-center text-sm mx-auto"><i class="fa-solid fa-bell"></i></div>
        <h3 id="modal-title" class="font-bold text-stone-900 text-sm">Aviso</h3>
        <p id="modal-message" class="text-xs text-stone-500">Mensaje</p>
        <button onclick="closeModal()" class="w-full bg-stone-900 text-white font-bold py-2.5 rounded-xl text-xs">Aceptar</button>
    </div>
</div>

<!-- MODAL INGREDIENTE -->
<div id="ingredient-modal" class="fixed inset-0 bg-stone-900/60 backdrop-blur-sm z-50 hidden overflow-y-auto">
    <div class="min-h-full flex items-start justify-center p-3 py-6">
        <div class="bg-white rounded-2xl p-4 max-w-md w-full shadow-xl space-y-3 border border-stone-100">
            <div class="flex justify-between items-center border-b border-stone-100 pb-2">
                <h3 id="ingredient-modal-title" class="font-bold text-stone-900 text-sm">Nuevo Ingrediente</h3>
                <button onclick="closeIngredientModal()" class="text-stone-400 hover:text-rose-600 p-1 text-sm"><i class="fa-solid fa-xmark"></i></button>
            </div>
            <div><label class="text-[10px] font-bold text-stone-400 uppercase tracking-wider">Nombre</label><input id="ingredient-modal-name" type="text" placeholder="Ej: Chorizo" class="w-full bg-stone-100 border border-stone-200 rounded-xl px-3 py-2 text-sm font-medium focus:outline-none focus:border-amber-600 transition"></div>
            <div class="grid grid-cols-2 gap-2">
                <div><label class="text-[10px] font-bold text-stone-400 uppercase tracking-wider">Cantidad</label><input id="ingredient-modal-stock" type="number" inputmode="numeric" value="0" class="w-full bg-stone-100 border border-stone-200 rounded-xl px-3 py-2 text-sm font-bold text-center focus:outline-none focus:border-amber-600 transition"></div>
                <div><label class="text-[10px] font-bold text-stone-400 uppercase tracking-wider">Unidad</label><select id="ingredient-modal-unit" class="w-full bg-stone-100 border border-stone-200 rounded-xl px-3 py-2 text-sm font-medium focus:outline-none focus:border-amber-600 transition"><option value="und">unidades</option><option value="porc">porciones</option><option value="kg">kg</option><option value="g">g</option><option value="L">L</option><option value="ml">ml</option><option value="paq">paquete</option></select></div>
            </div>
            <div class="flex gap-2 pt-1">
                <button id="ingredient-modal-delete" onclick="deleteIngredientFromModal()" class="hidden bg-rose-100 hover:bg-rose-200 text-rose-700 font-bold py-2.5 px-3 rounded-xl text-xs"><i class="fa-solid fa-trash"></i></button>
                <button onclick="closeIngredientModal()" class="flex-1 bg-stone-100 hover:bg-stone-200 text-stone-700 font-bold py-2.5 rounded-xl text-xs">Cancelar</button>
                <button onclick="saveIngredient()" class="flex-1 bg-stone-900 hover:bg-stone-800 text-white font-bold py-2.5 rounded-xl text-xs">Guardar</button>
            </div>
        </div>
    </div>
</div>

<!-- MODAL PRODUCTO -->
<div id="product-modal" class="fixed inset-0 bg-stone-900/60 backdrop-blur-sm z-50 hidden overflow-y-auto">
    <div class="min-h-full flex items-start justify-center p-3 py-6">
        <div class="bg-white rounded-2xl p-4 max-w-md w-full shadow-xl space-y-3 border border-stone-100">
            <div class="flex justify-between items-center border-b border-stone-100 pb-2">
                <h3 id="product-modal-title" class="font-bold text-stone-900 text-sm">Nuevo Producto</h3>
                <button onclick="closeProductModal()" class="text-stone-400 hover:text-rose-600 p-1 text-sm"><i class="fa-solid fa-xmark"></i></button>
            </div>
            <div><label class="text-[10px] font-bold text-stone-400 uppercase tracking-wider">Nombre</label><input id="product-modal-name" type="text" placeholder="Ej: ESPECIAL" class="w-full bg-stone-100 border border-stone-200 rounded-xl px-3 py-2 text-sm font-bold uppercase focus:outline-none focus:border-amber-600 transition"></div>
            <div><label class="text-[10px] font-bold text-stone-400 uppercase tracking-wider">Descripción</label><input id="product-modal-desc" type="text" placeholder="Ej: Chorizo + queso" class="w-full bg-stone-100 border border-stone-200 rounded-xl px-3 py-2 text-sm focus:outline-none focus:border-amber-600 transition"></div>
            <div class="grid grid-cols-2 gap-2">
                <div><label class="text-[10px] font-bold text-stone-400 uppercase tracking-wider">Precio</label><input id="product-modal-price" type="number" inputmode="numeric" value="10000" class="w-full bg-stone-100 border border-stone-200 rounded-xl px-3 py-2 text-sm font-bold text-center focus:outline-none focus:border-amber-600 transition"></div>
                <div><label class="text-[10px] font-bold text-stone-400 uppercase tracking-wider">Icono</label><select id="product-modal-icon" class="w-full bg-stone-100 border border-stone-200 rounded-xl px-2 py-2 text-sm font-medium focus:outline-none focus:border-amber-600 transition"><option value="fa-solid fa-hotdog">🌭 Perro</option><option value="fa-solid fa-utensils">🍽️ Combo</option><option value="fa-solid fa-bowl-food">🥣 Tazón</option><option value="fa-solid fa-pepper-hot">🌶️ Picante</option><option value="fa-solid fa-cheese">🧀 Queso</option><option value="fa-solid fa-burger">🍔 Hamburguesa</option><option value="fa-solid fa-pizza-slice">🍕 Pizza</option><option value="fa-solid fa-mug-hot">☕ Bebida caliente</option><option value="fa-solid fa-glass-water">🥤 Bebida</option><option value="fa-solid fa-ice-cream">🍦 Helado</option><option value="fa-solid fa-cookie">🍪 Galleta</option><option value="fa-solid fa-drumstick-bite">🍗 Pollo</option></select></div>
            </div>
            <div>
                <label class="text-[10px] font-bold text-stone-400 uppercase tracking-wider">Receta</label>
                <p class="text-[10px] text-stone-400 mb-1">Cantidad que usa este producto. Deja 0 si no lo usa.</p>
                <div id="product-modal-recipe" class="space-y-1.5 bg-stone-50 rounded-xl p-2 border border-stone-100 max-h-52 overflow-y-auto"></div>
            </div>
            <div class="flex gap-2 pt-1">
                <button id="product-modal-delete" onclick="deleteProductFromModal()" class="hidden bg-rose-100 hover:bg-rose-200 text-rose-700 font-bold py-2.5 px-3 rounded-xl text-xs"><i class="fa-solid fa-trash"></i></button>
                <button onclick="closeProductModal()" class="flex-1 bg-stone-100 hover:bg-stone-200 text-stone-700 font-bold py-2.5 rounded-xl text-xs">Cancelar</button>
                <button onclick="saveProduct()" class="flex-1 bg-stone-900 hover:bg-stone-800 text-white font-bold py-2.5 rounded-xl text-xs">Guardar</button>
            </div>
        </div>
    </div>
</div>

<!-- MODAL EDITAR VENTA -->
<div id="edit-sale-modal" class="fixed inset-0 bg-stone-900/60 backdrop-blur-sm z-50 hidden overflow-y-auto">
    <div class="min-h-full flex items-start justify-center p-3 py-6">
        <div class="bg-white rounded-2xl p-4 max-w-md w-full shadow-xl space-y-3 border border-stone-100">
            <div class="flex justify-between items-center border-b border-stone-100 pb-2">
                <div><h3 class="font-bold text-stone-900 text-sm">Editar Venta <span id="edit-sale-id" class="text-amber-600"></span></h3><p id="edit-sale-time" class="text-[10px] text-stone-400"></p></div>
                <button onclick="closeEditSale()" class="text-stone-400 hover:text-rose-600 p-1 text-sm"><i class="fa-solid fa-xmark"></i></button>
            </div>
            <div><label class="text-[10px] font-bold text-stone-400 uppercase tracking-wider">Cliente</label><input id="edit-sale-customer" type="text" class="w-full bg-stone-100 border border-stone-200 rounded-xl px-3 py-2 text-sm font-medium focus:outline-none focus:border-amber-600 transition"></div>
            <div>
                <div class="flex justify-between items-center mb-1"><label class="text-[10px] font-bold text-stone-400 uppercase tracking-wider">Productos</label><button onclick="addSaleItem()" class="text-[10px] font-bold text-amber-600 hover:text-amber-700"><i class="fa-solid fa-plus"></i> Añadir</button></div>
                <div id="edit-sale-items" class="space-y-2 max-h-[45vh] overflow-y-auto pr-1"></div>
            </div>
            <div class="border-t border-stone-100 pt-2 flex justify-between items-center"><span class="text-[11px] text-stone-500 uppercase font-bold">Total:</span><span id="edit-sale-total" class="text-amber-600 font-black text-lg">$0</span></div>
            <div class="flex gap-2 pt-1">
                <button onclick="deleteSale()" class="bg-rose-100 hover:bg-rose-200 text-rose-700 font-bold py-2.5 px-3 rounded-xl text-xs"><i class="fa-solid fa-trash"></i></button>
                <button onclick="closeEditSale()" class="flex-1 bg-stone-100 hover:bg-stone-200 text-stone-700 font-bold py-2.5 rounded-xl text-xs">Cancelar</button>
                <button onclick="saveSaleEdit()" class="flex-1 bg-stone-900 hover:bg-stone-800 text-white font-bold py-2.5 rounded-xl text-xs">Guardar</button>
            </div>
        </div>
    </div>
</div>

<script src="firebase-config.js"></script>
<script type="module" src="js/app-page.js"></script>
</body>
</html>
END_APP_HTML
echo -e "${GREEN}✓ app.html${NC}"

# ══════════════════════════════════════════════════════════════
# 8. js/app-page.js  (toda la lógica de la app multi-tenant)
# ══════════════════════════════════════════════════════════════
cat > js/app-page.js << 'END_APP_PAGE_JS'
import { auth, db } from "./firebase-init.js";
import { watchAuth, logout } from "./auth.js";
import { showToast, showAlert, closeModal } from "./ui.js";
import {
    collection, doc, getDoc, setDoc, addDoc, updateDoc, deleteDoc,
    onSnapshot, increment, serverTimestamp
} from "https://www.gstatic.com/firebasejs/11.6.1/firebase-firestore.js";

// ── Estado global
let uid = null;
let profile = null;
let menuItems = [], orders = [], inventory = [], cart = [];
let menuReady = false, ordersReady = false, invReady = false;
let firstOrdersLoad = true;
let currentRole = 'cajero';
let editingIngredientFbId = null;
let editingProductId = null, editingProductRecipe = [];
let editingSale = null;
let calYear = new Date().getFullYear(), calMonth = new Date().getMonth(), selDate = null;

// ── Colecciones dinámicas por UID
const menuCol  = () => collection(db, 'users', uid, 'menu');
const ordersCol() => collection(db, 'users', uid, 'orders');
const invCol  = () => collection(db, 'users', uid, 'inventory');

// ── Auth guard
watchAuth(async (user, prof) => {
    if (!user) { window.location.href = 'index.html'; return; }
    if (!prof?.onboarded) { window.location.href = 'onboarding.html'; return; }
    uid = user.uid;
    profile = prof;
    applyTheme(prof.theme);
    document.getElementById('biz-name').textContent = (prof.businessName || 'MI NEGOCIO').toUpperCase();
    document.getElementById('loading').classList.add('hidden');
    document.getElementById('main-app').classList.remove('hidden');
    attachListeners();
});

function applyTheme(theme) {
    const themes = {
        mustard: { bg: 'bg-amber-500', text: 'text-amber-600', hover: 'hover:text-amber-600' },
        olive:   { bg: 'bg-lime-700',  text: 'text-lime-700',  hover: 'hover:text-lime-700' },
        rose:    { bg: 'bg-rose-600',  text: 'text-rose-600',  hover: 'hover:text-rose-600' }
    };
    const t = themes[theme] || themes.mustard;
    document.getElementById('brand-icon').className = `${t.bg} text-white w-8 h-8 rounded-xl flex items-center justify-center text-sm`;
}

// ── Listeners Firestore
function attachListeners() {
    onSnapshot(menuCol(), async (snap) => {
        if (snap.empty && !menuReady) { await seedDefaultMenu(); return; }
        menuItems = snap.docs.map(d => ({ firebaseId: d.id, ...d.data() })).sort((a,b)=>a.id-b.id);
        menuReady = true;
        document.getElementById('sync-indicator').title = 'Conectado';
        document.getElementById('sync-indicator').innerHTML = '<span class="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span><span class="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span>';
        refresh();
    });

    onSnapshot(ordersCol(), (snap) => {
        const prevPend = orders.filter(o=>o.status==='pendiente').length;
        orders = snap.docs.map(d => ({ firebaseId: d.id, ...d.data() })).sort((a,b)=>(b.timestamp||0)-(a.timestamp||0));
        const nowPend = orders.filter(o=>o.status==='pendiente').length;
        if (!firstOrdersLoad && nowPend > prevPend) playBeep();
        firstOrdersLoad = false;
        ordersReady = true;
        refresh();
    });

    onSnapshot(invCol(), async (snap) => {
        if (snap.empty && !invReady) { await seedDefaultInventory(); return; }
        inventory = snap.docs.map(d => ({ firebaseId: d.id, ...d.data() })).sort((a,b)=>a.id-b.id);
        invReady = true;
        refresh();
    });
}

async function seedDefaultMenu() {
    const defaults = [
        { id:1, name:"CLÁSICO", desc:"Chorizo + pan", price:10000, icon:"fa-solid fa-hotdog", recipe:[{ingredientId:1,qty:1},{ingredientId:2,qty:1}] },
        { id:2, name:"GRATINADO", desc:"Con queso", price:11000, icon:"fa-solid fa-cheese", recipe:[{ingredientId:1,qty:1},{ingredientId:2,qty:1},{ingredientId:3,qty:1}] },
        { id:3, name:"COMBO", desc:"Choripán + papas", price:14000, icon:"fa-solid fa-utensils", recipe:[{ingredientId:1,qty:1},{ingredientId:2,qty:1},{ingredientId:4,qty:1}] }
    ];
    for (const item of defaults) await setDoc(doc(menuCol(), `item_${item.id}`), item);
}
async function seedDefaultInventory() {
    const defaults = [
        { id:1, name:"Chorizo",  stock:80, unit:"und" },
        { id:2, name:"Pan",      stock:85, unit:"und" },
        { id:3, name:"Queso",    stock:45, unit:"porc" },
        { id:4, name:"Papas",    stock:60, unit:"porc" }
    ];
    for (const item of defaults) await setDoc(doc(invCol(), `item_${item.id}`), item);
}

// ── Navegación
window.switchRole = (role) => {
    currentRole = role;
    ['cajero','cocinero','inventario','admin'].forEach(r => {
        document.getElementById(`view-${r}`).classList.add('hidden');
        document.getElementById(`nav-btn-${r}`).className = "flex flex-col items-center gap-1 text-stone-400 hover:text-stone-700 transition";
    });
    document.getElementById(`view-${role}`).classList.remove('hidden');
    document.getElementById(`nav-btn-${role}`).className = "flex flex-col items-center gap-1 text-amber-600 transition";
    const labels = { cajero:'Caja', cocinero:'Cocina', inventario:'Inventario', admin:'Admin' };
    document.getElementById('active-role-label').textContent = labels[role];
    refresh();
};

function refresh() {
    if (currentRole === 'cajero')     { renderMenu(); updateCart(); renderCashierOrders(); }
    if (currentRole === 'cocinero')   updateKitchen();
    if (currentRole === 'inventario') renderInventorySection();
    if (currentRole === 'admin')      updateAdmin();
}

window.doLogout = logout;

// ── Helpers tiempo
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
    if (min < 5)  return 'bg-emerald-100 text-emerald-700 border-emerald-200';
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

// ── Audio beep
let audioCtx = null;
try { audioCtx = new (window.AudioContext || window.webkitAudioContext)(); } catch(e){}
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

// ── Caja
function renderMenu() {
    const grid = document.getElementById('menu-grid');
    const summary = document.getElementById('menu-prices-summary');
    if (!menuReady) { grid.innerHTML = '<p class="text-stone-400 text-xs py-3 text-center">Cargando menú...</p>'; return; }
    summary.textContent = `${menuItems.length} productos`;
    grid.innerHTML = menuItems.map(i => `
        <div onclick="addToCart(${i.id})" class="bg-white p-2.5 rounded-2xl border border-stone-200 active:scale-[0.99] transition flex items-center justify-between cursor-pointer">
            <div class="flex items-center gap-2.5">
                <div class="w-9 h-9 rounded-xl bg-stone-100 text-stone-800 flex items-center justify-center font-bold text-xs"><i class="${i.icon}"></i></div>
                <div>
                    <h4 class="font-bold text-xs text-stone-900">${i.name}</h4>
                    <p class="text-[10px] text-stone-400 line-clamp-1">${i.desc || ''}</p>
                </div>
            </div>
            <div class="text-right"><span class="font-black text-xs text-amber-600">$${i.price.toLocaleString()}</span><div class="text-[9px] text-stone-400 font-medium">+ Agregar</div></div>
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
        return `<div class="flex justify-between items-center py-1">
            <span class="font-semibold text-xs text-stone-800">${it.name}</span>
            <div class="flex items-center gap-2">
                <button onclick="updateCartQty(${it.id},-1)" class="w-5 h-5 bg-stone-100 rounded text-xs font-bold">-</button>
                <span class="text-xs font-bold w-4 text-center">${it.qty}</span>
                <button onclick="updateCartQty(${it.id},1)" class="w-5 h-5 bg-stone-100 rounded text-xs font-bold">+</button>
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
        // Actualizar stats del usuario y global
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
        showToast("¡Pedido enviado!", 'success');
    } catch(e) {
        console.error(e);
        showAlert("Error al enviar. Revisa tu conexión.", "Error");
    } finally { btn.disabled = false; }
};

function statusClass(s) {
    if (s === 'pendiente')   return 'bg-amber-100 text-amber-800';
    if (s === 'preparacion') return 'bg-blue-100 text-blue-800';
    return 'bg-emerald-100 text-emerald-800';
}

function renderCashierOrders() {
    const c = document.getElementById('cashier-orders-list');
    const now = Date.now();
    c.innerHTML = orders.slice(0,5).map(o => {
        const e = o.timestamp ? now - o.timestamp : 0;
        const t = o.status !== 'listo' ? `<span data-timer="${o.firebaseId}" class="text-[10px] font-bold px-2 py-0.5 rounded-md border ${timerClass(e)}">${formatElapsed(e)}</span>` : '';
        return `<div class="flex justify-between items-center bg-stone-50 p-2 rounded-xl border border-stone-100 text-xs">
            <div class="min-w-0 flex-1">
                <div class="flex items-center gap-1.5 flex-wrap"><span class="font-bold text-stone-900">#${o.id} - ${o.customer}</span>${t}</div>
                <div class="text-[10px] text-stone-400 truncate">${(o.items||[]).map(i=>`${i.qty}x${i.name}`).join(', ')}</div>
            </div>
            <div class="text-right shrink-0 ml-2"><span class="font-bold text-amber-600">$${(o.total||0).toLocaleString()}</span><div><span class="text-[9px] px-1.5 py-0.5 rounded font-bold ${statusClass(o.status)}">${o.status}</span></div></div>
        </div>`;
    }).join('') || '<p class="text-stone-400 text-xs py-2 text-center">No hay pedidos recientes</p>';
}

// ── Cocina
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
        return `<div class="bg-white p-3 rounded-2xl shadow-xs border-2 ${border} space-y-2">
            <div class="flex justify-between items-center gap-2">
                <span class="font-bold text-xs text-stone-900 truncate">#${o.id} - ${o.customer}</span>
                ${o.status !== 'listo' ? `<span data-timer="${o.firebaseId}" class="text-[10px] font-bold px-2 py-0.5 rounded-md border ${timerClass(e)}">${formatElapsed(e)}</span>` : `<span class="text-[10px] text-stone-400">${o.time}</span>`}
            </div>
            <div class="bg-stone-50 p-2 rounded-xl text-xs space-y-1">${(o.items||[]).map(i => `<div class="font-medium text-stone-800">• ${i.qty}x${i.name}</div>`).join('')}</div>
            <div class="flex justify-between items-center pt-1">
                <span class="text-[10px] text-stone-400">${o.time}</span>
                <div class="flex gap-1.5">
                    ${o.status==='pendiente' ? `<button onclick="setStatus('${o.firebaseId}','preparacion')" class="bg-blue-600 hover:bg-blue-700 text-white px-3 py-1.5 rounded-xl text-xs font-bold">Cocinar</button>` : ''}
                    ${o.status==='preparacion' ? `<button onclick="setStatus('${o.firebaseId}','listo')" class="bg-emerald-600 hover:bg-emerald-700 text-white px-3 py-1.5 rounded-xl text-xs font-bold">Listo ✔</button>` : ''}
                    ${o.status==='listo' ? `<span class="text-xs font-bold text-emerald-600">Entregado</span>` : ''}
                </div>
            </div>
        </div>`;
    };
    c.innerHTML = (activos.map(card).join('') || '<p class="text-stone-400 text-xs py-2 text-center">No hay pedidos en cocina</p>') +
        (listos.length ? '<div class="pt-2 text-[10px] font-bold text-stone-400 uppercase tracking-wider">Últimos listos</div>' + listos.map(card).join('') : '');
}

window.setStatus = async (fbId, status) => {
    try { await updateDoc(doc(ordersCol(), fbId), { status }); } catch(e) { console.error(e); }
};

// ── Inventario
function renderInventorySection() {
    const list = document.getElementById('inventory-list');
    if (!invReady) { list.innerHTML = '<p class="text-stone-400 text-xs py-3 text-center">Cargando inventario...</p>'; return; }
    if (!inventory.length) { list.innerHTML = '<p class="text-stone-400 text-xs py-3 text-center">No hay ingredientes.</p>'; return; }
    list.innerHTML = inventory.map(i => {
        const low = i.stock <= 10;
        return `<div class="bg-white rounded-2xl p-3 shadow-xs border border-stone-200">
            <div class="flex items-center justify-between gap-2">
                <div class="flex items-center gap-2 min-w-0">
                    <div class="w-9 h-9 rounded-xl bg-stone-100 flex items-center justify-center"><i class="fa-solid fa-box text-stone-700 text-xs"></i></div>
                    <div class="min-w-0"><h4 class="font-bold text-xs text-stone-900 truncate">${i.name}</h4><p class="text-[10px] text-stone-400">Stock: <span class="font-bold ${low?'text-rose-600':'text-stone-700'}">${i.stock} ${i.unit}</span></p></div>
                </div>
                <div class="flex items-center gap-1">
                    <button onclick="adjustStock('${i.firebaseId}',-10)" class="w-8 h-8 bg-stone-100 hover:bg-stone-200 rounded-lg text-[11px] font-bold">-10</button>
                    <button onclick="adjustStock('${i.firebaseId}',-1)" class="w-8 h-8 bg-stone-100 hover:bg-stone-200 rounded-lg text-xs font-bold">-1</button>
                    <button onclick="adjustStock('${i.firebaseId}',1)" class="w-8 h-8 bg-stone-100 hover:bg-stone-200 rounded-lg text-xs font-bold">+1</button>
                    <button onclick="adjustStock('${i.firebaseId}',10)" class="w-8 h-8 bg-stone-100 hover:bg-stone-200 rounded-lg text-[11px] font-bold">+10</button>
                    <button onclick="openIngredientModal('${i.firebaseId}')" class="w-8 h-8 bg-rose-50 hover:bg-rose-100 text-rose-600 rounded-lg text-xs"><i class="fa-solid fa-pen"></i></button>
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
        .map(u => `<div class="flex justify-between items-center bg-stone-50 p-2 rounded-lg text-xs border border-stone-100"><span class="font-semibold text-stone-700 truncate">${u.name}</span><span class="font-bold text-stone-900">${u.qty} ${u.unit}</span></div>`).join('') || '<p class="text-stone-400 text-xs py-2 text-center">Sin datos aún.</p>';
}

window.adjustStock = async (fbId, delta) => {
    try { await updateDoc(doc(invCol(), fbId), { stock: increment(delta) }); } catch(e){ console.error(e); }
};

// ── Modal ingrediente
window.openIngredientModal = (fbId) => {
    const modal = document.getElementById('ingredient-modal');
    const title = document.getElementById('ingredient-modal-title');
    const name  = document.getElementById('ingredient-modal-name');
    const stock = document.getElementById('ingredient-modal-stock');
    const unit  = document.getElementById('ingredient-modal-unit');
    const del   = document.getElementById('ingredient-modal-delete');
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
    if (!editingIngredientFbId || !confirm("¿Eliminar este ingrediente?")) return;
    try { await deleteDoc(doc(invCol(), editingIngredientFbId)); closeIngredientModal(); showToast("Eliminado", 'success'); }
    catch(e) { console.error(e); showAlert("No se pudo eliminar.", "Error"); }
};

// ── Admin
function updateAdmin() {
    document.getElementById('stat-sales').textContent = `$${orders.reduce((s,o)=>s+(o.total||0),0).toLocaleString()}`;
    document.getElementById('stat-orders').textContent = orders.length;
    renderCalendar();
    renderProductStats();
    renderAdminMenu();
}

function renderAdminMenu() {
    const c = document.getElementById('admin-menu-list');
    if (!menuReady) { c.innerHTML = '<p class="text-stone-400 text-xs py-2 text-center">Cargando...</p>'; return; }
    c.innerHTML = menuItems.map(i => {
        const r = Array.isArray(i.recipe) && i.recipe.length
            ? i.recipe.map(x => { const ing = getIng(x.ingredientId); return ing ? `${x.qty} ${ing.unit} ${ing.name}` : null; }).filter(Boolean).join(' · ')
            : 'Sin receta';
        return `<div class="bg-stone-50 p-2.5 rounded-xl text-xs border border-stone-100">
            <div class="flex justify-between items-center gap-2">
                <div class="flex items-center gap-2 min-w-0">
                    <div class="w-7 h-7 rounded-lg bg-stone-200 text-stone-700 flex items-center justify-center text-[11px] shrink-0"><i class="${i.icon}"></i></div>
                    <div class="min-w-0"><p class="font-bold text-stone-900 truncate">${i.name}</p><p class="text-[10px] text-stone-400 truncate">${i.desc || ''}</p></div>
                </div>
                <div class="flex items-center gap-1 shrink-0"><span class="font-bold text-amber-600">$${i.price.toLocaleString()}</span><button onclick="openProductModal(${i.id})" class="bg-stone-200 hover:bg-stone-300 px-2 py-1 rounded-lg text-[10px] font-bold"><i class="fa-solid fa-pen"></i></button></div>
            </div>
            <p class="text-[10px] text-stone-500 mt-1.5 leading-snug">📋 ${r}</p>
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
        : '<p class="text-stone-400 text-xs py-1 text-center">Sin ventas aún.</p>';
    document.getElementById('stats-bottom-products').innerHTML = bot.length
        ? bot.map((p,i)=>`<div class="flex justify-between items-center bg-rose-50 p-2 rounded-lg text-xs border border-rose-100"><span class="font-semibold text-rose-800">${i+1}. ${p.name}</span><span class="font-bold text-rose-700">${p.qty} und</span></div>`).join('')
        : '<p class="text-stone-400 text-xs py-1 text-center">Sin ventas aún.</p>';
}

// ── Modal producto
window.openProductModal = (productId) => {
    const modal = document.getElementById('product-modal');
    const title = document.getElementById('product-modal-title');
    const name  = document.getElementById('product-modal-name');
    const desc  = document.getElementById('product-modal-desc');
    const price = document.getElementById('product-modal-price');
    const icon  = document.getElementById('product-modal-icon');
    const del   = document.getElementById('product-modal-delete');
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
    if (!inventory.length) { c.innerHTML = '<p class="text-stone-400 text-xs py-2 text-center">No hay ingredientes creados.</p>'; return; }
    c.innerHTML = inventory.map(ing => {
        const found = editingProductRecipe.find(r => r.ingredientId === ing.id);
        return `<div class="flex justify-between items-center bg-white p-2 rounded-lg border border-stone-200">
            <span class="text-xs font-semibold text-stone-700 truncate">${ing.name}</span>
            <div class="flex items-center gap-1">
                <input type="number" min="0" value="${found?found.qty:0}" data-ingid="${ing.id}" oninput="updateRecipeQty(${ing.id},this.value)" class="w-16 text-center text-xs font-bold bg-stone-50 border border-stone-200 rounded-lg py-1 focus:outline-none focus:border-amber-600">
                <span class="text-[10px] text-stone-400 w-8">${ing.unit}</span>
            </div>
        </div>`;
    }).join('');
}
window.updateRecipeQty = (ingId, val) => {
    const q = parseInt(val) || 0;
    const idx = editingProductRecipe.findIndex(r => r.ingredientId === ingId);
    if (q <= 0) { if (idx >= 0) editingProductRecipe.splice(idx,1); }
    else { if (idx >= 0) editingProductRecipe[idx].qty = q; else editingProductRecipe.push({ ingredientId: ingId, qty: q }); }
};
window.saveProduct = async () => {
    const name = document.getElementById('product-modal-name').value.trim().toUpperCase();
    const desc = document.getElementById('product-modal-desc').value.trim();
    const price = parseInt(document.getElementById('product-modal-price').value) || 0;
    const icon = document.getElementById('product-modal-icon').value;
    if (!name) { showAlert("Escribe un nombre."); return; }
    if (price <= 0) { showAlert("Precio inválido."); return; }
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
    if (!editingProductId || !confirm("¿Eliminar este producto?")) return;
    const p = menuItems.find(m => m.id === editingProductId);
    if (!p) return;
    try { await deleteDoc(doc(menuCol(), p.firebaseId)); closeProductModal(); showToast("Producto eliminado", 'success'); }
    catch(e) { console.error(e); showAlert("No se pudo eliminar.", "Error"); }
};

// ── Calendario
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
    if (!selDate) { sumEl.classList.add('hidden'); det.innerHTML = '<p class="text-stone-400 text-xs py-2 text-center">Toca un día del calendario.</p>'; return; }
    const dayOrders = ordersOfDate(selDate).sort((a,b)=>(a.timestamp||0)-(b.timestamp||0));
    const dayTot = dayOrders.reduce((s,o)=>s+(o.total||0),0);
    sumEl.classList.remove('hidden');
    const [y,m,dd] = selDate.split('-');
    document.getElementById('calendar-day-summary-text').textContent = `${dayOrders.length} pedido${dayOrders.length===1?'':'s'} el ${dd}/${m}/${y}`;
    document.getElementById('calendar-day-summary-total').textContent = `$${dayTot.toLocaleString()}`;
    det.innerHTML = dayOrders.length ? dayOrders.map(o => `
        <div class="flex justify-between items-center bg-stone-50 p-2 rounded-xl border border-stone-100 text-xs">
            <div class="min-w-0 flex-1">
                <div class="flex items-center gap-1.5 flex-wrap"><span class="font-bold text-stone-900">#${o.id} - ${o.customer}</span><span class="text-[10px] text-stone-400">${o.time||''}</span></div>
                <div class="text-[10px] text-stone-400 truncate">${(o.items||[]).map(i=>`${i.qty}x${i.name}`).join(', ')}</div>
            </div>
            <div class="text-right shrink-0 ml-2 flex flex-col items-end gap-1">
                <span class="font-bold text-amber-600">$${(o.total||0).toLocaleString()}</span>
                <button onclick="openEditSale('${o.firebaseId}')" class="bg-stone-200 hover:bg-stone-300 px-2 py-0.5 rounded text-[9px] font-bold"><i class="fa-solid fa-pen"></i></button>
            </div>
        </div>`).join('') : '<p class="text-stone-400 text-xs py-2 text-center">Sin ventas ese día.</p>';
}

// ── Editar venta
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
            <div class="flex items-center gap-1.5 bg-stone-50 p-2 rounded-xl border border-stone-100">
                <input type="text" value="${(it.name||'').replace(/"/g,'&quot;')}" oninput="updateSaleItem(${idx},'name',this.value)" class="flex-1 min-w-0 bg-transparent text-xs font-semibold focus:outline-none">
                <div class="flex items-center gap-1 bg-white rounded-lg border border-stone-200 px-1.5">
                    <button onclick="adjustSaleQty(${idx},-1)" class="text-stone-500 text-xs font-bold w-4 text-center">-</button>
                    <input type="number" value="${it.qty}" oninput="updateSaleItem(${idx},'qty',this.value)" class="w-8 text-center text-xs font-bold bg-transparent focus:outline-none">
                    <button onclick="adjustSaleQty(${idx},1)" class="text-stone-500 text-xs font-bold w-4 text-center">+</button>
                </div>
                <div class="flex items-center bg-white rounded-lg border border-stone-200 px-1.5"><span class="text-[10px] text-stone-400">$</span><input type="number" value="${it.price}" oninput="updateSaleItem(${idx},'price',this.value)" class="w-16 text-right text-xs font-bold bg-transparent focus:outline-none"></div>
                <button onclick="removeSaleItem(${idx})" class="text-rose-500 hover:text-rose-700 px-1"><i class="fa-solid fa-trash text-xs"></i></button>
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
    if (!editingSale || !confirm(`¿Eliminar venta #${editingSale.id}?`)) return;
    try {
        await applyRecipe(editingSale.originalItems, +1);
        await deleteDoc(doc(ordersCol(), editingSale.firebaseId));
        closeEditSale(); showToast("Venta eliminada", 'success');
    } catch(e) { console.error(e); showAlert("No se pudo eliminar.", "Error"); }
};

// ── Reset
window.resetData = async () => {
    if (!confirm("¿Borrar TODOS los pedidos?")) return;
    try {
        for (const o of orders) await deleteDoc(doc(ordersCol(), o.firebaseId));
        showToast("Pedidos borrados", 'success');
    } catch(e) { console.error(e); showAlert("No se pudo reiniciar.", "Error"); }
};
END_APP_PAGE_JS
echo -e "${GREEN}✓ js/app-page.js${NC}"

# ══════════════════════════════════════════════════════════════
# 9. admin.html + js/admin-page.js (super admin)
# ══════════════════════════════════════════════════════════════
cat > admin.html << 'END_ADMIN_HTML'
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Verde Mostaza — Super Admin</title>
    <script src="https://cdn.tailwindcss.com"></script>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700;800;900&display=swap" rel="stylesheet">
    <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
    <script>tailwind.config={theme:{extend:{fontFamily:{sans:['Inter','sans-serif']}}}}</script>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
</head>
<body class="bg-stone-100 text-stone-800 font-sans min-h-screen">

<div id="login-view" class="fixed inset-0 bg-stone-900/90 backdrop-blur flex items-center justify-center p-4 z-50">
    <div class="bg-white rounded-3xl p-6 max-w-xs w-full text-center space-y-4 shadow-2xl">
        <div class="w-14 h-14 bg-stone-900 text-white rounded-2xl flex items-center justify-center text-xl mx-auto"><i class="fa-solid fa-shield-halved"></i></div>
        <div>
            <h2 class="font-black text-lg text-stone-900">SUPER ADMIN</h2>
            <p class="text-xs text-stone-400 mt-0.5">Panel de control global</p>
        </div>
        <button onclick="handleGoogle()" class="w-full bg-stone-900 hover:bg-stone-800 text-white font-bold py-3 rounded-xl text-xs">Login con Google</button>
        <p id="status" class="text-[10px] text-stone-400"></p>
        <a href="index.html" class="text-[11px] text-stone-500 hover:text-stone-700 underline block">← Volver al inicio</a>
    </div>
</div>

<div id="panel" class="hidden max-w-5xl mx-auto p-4 space-y-4 pb-10">
    <header class="bg-white rounded-2xl p-4 shadow-xs border border-stone-200 flex justify-between items-center">
        <div class="flex items-center gap-2">
            <div class="bg-stone-900 text-white w-9 h-9 rounded-xl flex items-center justify-center"><i class="fa-solid fa-shield-halved"></i></div>
            <div><h1 class="font-black text-sm text-stone-900">VERDE MOSTAZA</h1><p class="text-[10px] text-stone-400 uppercase tracking-wider font-bold">Super Admin</p></div>
        </div>
        <button onclick="doLogout()" class="text-stone-400 hover:text-rose-600 p-2 text-xs"><i class="fa-solid fa-right-from-bracket"></i></button>
    </header>

    <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
        <div class="bg-white p-3.5 rounded-2xl shadow-xs border border-stone-200"><p class="text-[10px] uppercase font-bold text-stone-400">Usuarios</p><h3 id="kpi-users" class="text-xl font-black text-stone-900 mt-1">—</h3></div>
        <div class="bg-white p-3.5 rounded-2xl shadow-xs border border-stone-200"><p class="text-[10px] uppercase font-bold text-stone-400">Pedidos</p><h3 id="kpi-orders" class="text-xl font-black text-stone-900 mt-1">—</h3></div>
        <div class="bg-white p-3.5 rounded-2xl shadow-xs border border-stone-200"><p class="text-[10px] uppercase font-bold text-stone-400">Ventas globales</p><h3 id="kpi-sales" class="text-xl font-black text-stone-900 mt-1">—</h3></div>
        <div class="bg-white p-3.5 rounded-2xl shadow-xs border border-stone-200"><p class="text-[10px] uppercase font-bold text-stone-400">Activos hoy</p><h3 id="kpi-dau" class="text-xl font-black text-emerald-600 mt-1">—</h3></div>
    </div>

    <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
        <div class="bg-white p-4 rounded-2xl shadow-xs border border-stone-200">
            <p class="text-[11px] font-bold text-stone-400 uppercase tracking-wider mb-2">Usuarios nuevos (últimos 14 días)</p>
            <canvas id="chart-new" height="100"></canvas>
        </div>
        <div class="bg-white p-4 rounded-2xl shadow-xs border border-stone-200">
            <p class="text-[11px] font-bold text-stone-400 uppercase tracking-wider mb-2">Top 10 tiendas por ventas</p>
            <div id="top-stores" class="space-y-1.5 max-h-52 overflow-y-auto"></div>
        </div>
    </div>

    <div class="bg-white rounded-2xl p-4 shadow-xs border border-stone-200 space-y-2">
        <div class="flex justify-between items-center">
            <p class="text-[11px] font-bold text-stone-400 uppercase tracking-wider">Usuarios registrados</p>
            <button onclick="loadAll()" class="text-[10px] text-stone-500 hover:text-stone-900 font-bold"><i class="fa-solid fa-rotate"></i> Refrescar</button>
        </div>
        <input id="search" type="text" placeholder="Buscar por email o negocio..." oninput="renderUsers()" class="w-full bg-stone-100 border border-stone-200 rounded-xl px-3 py-2 text-xs focus:outline-none focus:border-stone-600">
        <div id="users-list" class="space-y-2 max-h-96 overflow-y-auto"></div>
    </div>
</div>

<script src="firebase-config.js"></script>
<script type="module" src="js/admin-page.js"></script>
</body>
</html>
END_ADMIN_HTML
echo -e "${GREEN}✓ admin.html${NC}"

cat > js/admin-page.js << 'END_ADMIN_PAGE_JS'
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
END_ADMIN_PAGE_JS
echo -e "${GREEN}✓ js/admin-page.js${NC}"

# ══════════════════════════════════════════════════════════════
# 10. firestore.rules
# ══════════════════════════════════════════════════════════════
cat > firestore.rules << 'END_RULES'
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    function isSignedIn()  { return request.auth != null; }
    function isOwner(uid)  { return isSignedIn() && request.auth.uid == uid; }
    function isSuperAdmin() {
      return isSignedIn() &&
        exists(/databases/$(database)/documents/super_admins/$(request.auth.uid));
    }

    // Super admins: solo escritura desde la consola
    match /super_admins/{uid} {
      allow read:  if isSignedIn() && (request.auth.uid == uid || isSuperAdmin());
      allow write: if false;
    }

    // Perfil + subcolecciones (multi-tenant real)
    match /users/{uid} {
      allow read:   if isOwner(uid) || isSuperAdmin();
      allow create: if isOwner(uid)
                    && request.resource.data.email == request.auth.token.email
                    && request.resource.data.onboarded == false;
      allow update: if isOwner(uid) || isSuperAdmin();
      allow delete: if isOwner(uid);

      // Subcolecciones (menu, orders, inventory): solo el dueño
      match /{collection}/{docId} {
        allow read, write: if isOwner(uid);
      }
    }

    // Contadores globales
    match /stats/global {
      allow read:   if isSignedIn();
      allow create: if isSignedIn();
      allow update: if isSignedIn()
        && request.resource.data.diff(resource.data).affectedKeys()
             .hasOnly(['totalUsers', 'totalOrders', 'total

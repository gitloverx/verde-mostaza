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

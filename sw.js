const CACHE = 'verde-mostaza-v1';
const SHELL = ['index.html', 'onboarding.html', 'app.html', 'admin.html', 'firebase-config.js', 'manifest.json', 'assets/icon.svg'];
self.addEventListener('install', (e) => {
    e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)).catch(()=>{}));
});
self.addEventListener('activate', (e) => {
    e.waitUntil(caches.keys().then(keys => Promise.all(keys.filter(k=>k!==CACHE).map(k=>caches.delete(k)))));
});
self.addEventListener('fetch', (e) => {
    if (e.request.method !== 'GET') return;
    if (e.request.url.includes('gstatic') || e.request.url.includes('firestore') || e.request.url.includes('googleapis')) return;
    e.respondWith(caches.match(e.request).then(r => r || fetch(e.request).catch(()=>caches.match('index.html'))));
});

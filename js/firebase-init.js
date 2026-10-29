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

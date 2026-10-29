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

import { auth, db } from "./firebase-init.js";
import { GoogleAuthProvider, signInWithPopup, signInWithRedirect, getRedirectResult, signOut, onAuthStateChanged, signInWithEmailAndPassword, createUserWithEmailAndPassword, sendPasswordResetEmail, updateProfile } from "https://www.gstatic.com/firebasejs/11.6.1/firebase-auth.js";
import { doc, getDoc, setDoc, updateDoc, serverTimestamp } from "https://www.gstatic.com/firebasejs/11.6.1/firebase-firestore.js";

const provider = new GoogleAuthProvider();
provider.setCustomParameters({ prompt: 'select_account' });

export async function signInWithGoogle() {
    if (window.innerWidth < 768) {
        await signInWithRedirect(auth, provider);
    } else {
        const r = await signInWithPopup(auth, provider);
        return r.user;
    }
}

export async function signInWithEmail(email, pass) {
    const r = await signInWithEmailAndPassword(auth, email, pass);
    return r.user;
}

export async function registerWithEmail(email, pass, name) {
    const r = await createUserWithEmailAndPassword(auth, email, pass);
    await updateProfile(r.user, { displayName: name });
    return r.user;
}

export async function resetPassword(email) {
    await sendPasswordResetEmail(auth, email);
}

export async function logout() {
    await signOut(auth);
    localStorage.clear();
    window.location.href = "index.html";
}

export function watchAuth(cb) {
    getRedirectResult(auth).catch((error) => console.error("Error redirect:", error));
    onAuthStateChanged(auth, async (user) => {
        if (!user) { cb(null, null); return; }
        const ref = doc(db, 'users', user.uid);
        let snap = await getDoc(ref);
        if (!snap.exists()) {
            await setDoc(ref, {
                email: user.email,
                displayName: user.displayName || user.email.split('@')[0],
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

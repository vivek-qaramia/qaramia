'use client';
import { useEffect } from 'react';
import { onAuthStateChanged, signInWithEmailAndPassword, createUserWithEmailAndPassword, signOut, GoogleAuthProvider, signInWithPopup } from 'firebase/auth';
import { doc, getDoc, setDoc, serverTimestamp } from 'firebase/firestore';
import { auth, db } from '@/lib/firebase';
import { useAuthStore } from '@/store/auth-store';
import { AppUser } from '@/lib/types';

export function useAuthListener() {
  const { setUser, setFirebaseUid } = useAuthStore();

  useEffect(() => {
    const unsub = onAuthStateChanged(auth, async (firebaseUser) => {
      if (!firebaseUser) {
        setUser(null);
        setFirebaseUid(null);
        return;
      }
      setFirebaseUid(firebaseUser.uid);
      const snap = await getDoc(doc(db, 'users', firebaseUser.uid));
      if (snap.exists()) {
        const data = snap.data();
        setUser({ ...data, uid: snap.id, createdAt: data.createdAt?.toDate() } as AppUser);
      }
    });
    return unsub;
  }, [setUser, setFirebaseUid]);
}

export async function signUpWithEmail(
  email: string,
  password: string,
  username: string,
  displayName: string,
  ageRange?: string,
  country?: string,
) {
  const cred = await createUserWithEmailAndPassword(auth, email, password);
  await setDoc(doc(db, 'users', cred.user.uid), {
    uid: cred.user.uid,
    username,
    displayName,
    followerCount: 0,
    followingCount: 0,
    likeCount: 0,
    isLive: false,
    createdAt: serverTimestamp(),
    ...(ageRange && { ageRange }),
    ...(country && { country }),
  });
  return cred.user;
}

export async function signInWithEmail(email: string, password: string) {
  return signInWithEmailAndPassword(auth, email, password);
}

export async function signInWithGoogle() {
  const provider = new GoogleAuthProvider();
  const result = await signInWithPopup(auth, provider);
  const uid = result.user.uid;
  const snap = await getDoc(doc(db, 'users', uid));
  if (!snap.exists()) {
    const username = result.user.email?.split('@')[0] ?? uid.slice(0, 8);
    await setDoc(doc(db, 'users', uid), {
      uid,
      username,
      displayName: result.user.displayName ?? username,
      avatarUrl: result.user.photoURL,
      followerCount: 0,
      followingCount: 0,
      likeCount: 0,
      isLive: false,
      createdAt: serverTimestamp(),
    });
  }
  return result.user;
}

export async function logout() {
  return signOut(auth);
}

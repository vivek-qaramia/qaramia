'use client';
import { useEffect, useState } from 'react';
import { doc, getDoc } from 'firebase/firestore';
import { db } from '@/lib/firebase';
import { useAuthStore } from '@/store/auth-store';

// Admin = an admins/{uid} doc exists (bootstrapped by hand in the console).
// Gates the game-catalog authoring UI (3d).
export function useIsAdmin(): boolean {
  const { user } = useAuthStore();
  const [isAdmin, setIsAdmin] = useState(false);
  useEffect(() => {
    if (!user?.uid) { setIsAdmin(false); return; }
    getDoc(doc(db, 'admins', user.uid))
      .then((s) => setIsAdmin(s.exists()))
      .catch(() => setIsAdmin(false));
  }, [user?.uid]);
  return isAdmin;
}

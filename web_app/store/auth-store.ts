import { create } from 'zustand';
import { AppUser } from '@/lib/types';

interface AuthStore {
  user: AppUser | null;
  firebaseUid: string | null;
  setUser: (user: AppUser | null) => void;
  setFirebaseUid: (uid: string | null) => void;
}

export const useAuthStore = create<AuthStore>((set) => ({
  user: null,
  firebaseUid: null,
  setUser: (user) => set({ user }),
  setFirebaseUid: (uid) => set({ firebaseUid: uid }),
}));

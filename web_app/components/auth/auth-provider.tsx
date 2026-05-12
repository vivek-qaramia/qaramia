'use client';
import { useAuthListener } from '@/hooks/use-auth';

export function AuthProvider({ children }: { children: React.ReactNode }) {
  useAuthListener();
  return <>{children}</>;
}

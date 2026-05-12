'use client';
import { useEffect } from 'react';

// Agora SDK leaves internal Promises uncaught when leave() races with join().
// OPERATION_ABORTED is non-fatal — suppress it globally so it doesn't pollute the console.
export function AgoraErrorSuppressor() {
  useEffect(() => {
    const handler = (event: PromiseRejectionEvent) => {
      if (event.reason?.code === 'OPERATION_ABORTED') {
        event.preventDefault();
      }
    };
    window.addEventListener('unhandledrejection', handler);
    return () => window.removeEventListener('unhandledrejection', handler);
  }, []);
  return null;
}

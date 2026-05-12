'use client';
import Link from 'next/link';
import { useRouter } from 'next/navigation';
import { useAuthStore } from '@/store/auth-store';
import { logout } from '@/hooks/use-auth';
import { WalletBadge } from '@/components/wallet/wallet-badge';

export function Navbar() {
  const { user } = useAuthStore();
  const router = useRouter();

  return (
    <header className="fixed top-0 inset-x-0 z-50 h-14 bg-black/90 backdrop-blur border-b border-white/10 flex items-center px-6 gap-6">
      <Link href="/" className="text-2xl font-black text-[#FF7043] tracking-tight">
        streamr
      </Link>

      <nav className="flex gap-4 ml-4">
        <Link href="/" className="text-sm text-white/70 hover:text-white transition">Home</Link>
        <Link href="/live" className="text-sm text-white/70 hover:text-white transition">Live</Link>
        {user && (
          <Link href="/studio" className="text-sm text-white/70 hover:text-white transition">Studio</Link>
        )}
        {user && (
          <Link href="/studio/ads" className="text-sm text-white/70 hover:text-white transition">Ads</Link>
        )}
      </nav>

      <div className="ml-auto flex items-center gap-3">
        {user && <WalletBadge />}
        {user ? (
          <>
            <Link href={`/profile/${user.uid}`}>
              <div className="flex items-center gap-2">
                {user.avatarUrl ? (
                  <img src={user.avatarUrl} alt="" className="w-8 h-8 rounded-full object-cover" />
                ) : (
                  <div className="w-8 h-8 rounded-full bg-gray-700 flex items-center justify-center text-sm font-bold">
                    {user.displayName[0]}
                  </div>
                )}
                <span className="text-sm text-white/80">@{user.username}</span>
              </div>
            </Link>
            <button
              onClick={() => { logout(); router.push('/'); }}
              className="text-sm text-white/50 hover:text-white transition"
            >
              Sign out
            </button>
          </>
        ) : (
          <Link
            href="/login"
            className="px-4 py-2 bg-[#FF7043] text-white rounded-lg text-sm font-semibold hover:bg-[#e55a2b] transition"
          >
            Sign in
          </Link>
        )}
      </div>
    </header>
  );
}

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
      <Link href="/" className="flex items-center gap-2 group" aria-label="peekuu home">
        {/* Mark — inline so we can size it precisely against the 56px navbar */}
        <svg viewBox="0 0 320 320" width="36" height="36" aria-hidden="true" className="transition-transform group-hover:scale-105">
          <defs>
            {/* userSpaceOnUse so the gradient paints on the vertical stem,
                whose object bounding box has zero width. */}
            <linearGradient id="nav-ring" gradientUnits="userSpaceOnUse" x1="124" y1="72" x2="124" y2="248">
              <stop offset="0%"   stopColor="#FFD166"/>
              <stop offset="45%"  stopColor="#FF8A5C"/>
              <stop offset="100%" stopColor="#E94560"/>
            </linearGradient>
            <linearGradient id="nav-c" x1="25%" y1="10%" x2="75%" y2="90%">
              <stop offset="0%"   stopColor="#FF6B81"/>
              <stop offset="100%" stopColor="#C9184A"/>
            </linearGradient>
          </defs>
          {/* peekuu "P" — rose bowl first, warm stem on top (clean junction) */}
          <path d="M 124 72 A 58 58 0 0 1 124 188" fill="none" stroke="url(#nav-c)" strokeWidth="30" strokeLinecap="round"/>
          <line x1="124" y1="72" x2="124" y2="248" stroke="url(#nav-ring)" strokeWidth="30" strokeLinecap="round"/>
        </svg>
        <span
          className="text-2xl font-semibold italic tracking-tight bg-gradient-to-r from-[#FF8A5C] to-[#E94560] bg-clip-text text-transparent"
          style={{ fontFamily: "var(--font-playfair), Georgia, serif" }}
        >
          peekuu
        </span>
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

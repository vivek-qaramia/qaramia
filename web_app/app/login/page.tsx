'use client';
import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { signInWithEmail, signUpWithEmail, signInWithGoogle } from '@/hooks/use-auth';

export default function LoginPage() {
  const [isLogin, setIsLogin] = useState(true);
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [username, setUsername] = useState('');
  const [displayName, setDisplayName] = useState('');
  const [ageRange, setAgeRange] = useState('');
  const [country, setCountry] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const router = useRouter();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    try {
      if (isLogin) {
        await signInWithEmail(email, password);
      } else {
        await signUpWithEmail(email, password, username.toLowerCase(), displayName, ageRange || undefined, country || undefined);
      }
      router.push('/');
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Something went wrong');
    } finally {
      setLoading(false);
    }
  };

  const handleGoogle = async () => {
    setLoading(true);
    try {
      await signInWithGoogle();
      router.push('/');
    } catch (err: unknown) {
      setError(err instanceof Error ? err.message : 'Something went wrong');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-[calc(100vh-3.5rem)] flex items-center justify-center px-4">
      <div className="w-full max-w-md">
        <div className="text-center mb-8 flex flex-col items-center">
          <svg viewBox="0 0 320 320" width="80" height="80" aria-hidden="true">
            <defs>
              {/* userSpaceOnUse so the gradient paints on the vertical stem
                  (zero-width object bounding box otherwise renders nothing). */}
              <linearGradient id="login-ring" gradientUnits="userSpaceOnUse" x1="124" y1="72" x2="124" y2="248">
                <stop offset="0%"   stopColor="#FFD166"/>
                <stop offset="45%"  stopColor="#FF8A5C"/>
                <stop offset="100%" stopColor="#E94560"/>
              </linearGradient>
              <linearGradient id="login-c" x1="25%" y1="10%" x2="75%" y2="90%">
                <stop offset="0%"   stopColor="#FF6B81"/>
                <stop offset="100%" stopColor="#C9184A"/>
              </linearGradient>
              <radialGradient id="login-halo" cx="50%" cy="50%" r="60%">
                <stop offset="0%"   stopColor="#FFD166" stopOpacity="0.4"/>
                <stop offset="100%" stopColor="#FF7043" stopOpacity="0"/>
              </radialGradient>
            </defs>
            <circle cx="160" cy="160" r="155" fill="url(#login-halo)"/>
            {/* peekuu "P" — rose bowl first, warm stem on top (clean junction) */}
            <path d="M 124 72 A 58 58 0 0 1 124 188" fill="none" stroke="url(#login-c)" strokeWidth="30" strokeLinecap="round"/>
            <line x1="124" y1="72" x2="124" y2="248" stroke="url(#login-ring)" strokeWidth="30" strokeLinecap="round"/>
          </svg>
          <h1
            className="text-5xl font-semibold italic tracking-tight bg-gradient-to-r from-[#FF8A5C] to-[#E94560] bg-clip-text text-transparent mt-2"
            style={{ fontFamily: "var(--font-playfair), Georgia, serif" }}
          >
            peekuu
          </h1>
          <p className="text-white/50 mt-2 text-sm tracking-[0.3em] uppercase">Live Streaming &amp; Commerce</p>
        </div>

        <div className="bg-zinc-900 rounded-2xl p-8 border border-zinc-700">
          {error && (
            <div className="bg-red-500/10 border border-red-500/30 text-red-400 text-sm rounded-lg p-3 mb-4">
              {error}
            </div>
          )}

          <form onSubmit={handleSubmit} className="space-y-4">
            {!isLogin && (
              <>
                <input
                  type="text"
                  placeholder="Display Name"
                  value={displayName}
                  onChange={(e) => setDisplayName(e.target.value)}
                  required
                  className="w-full bg-zinc-800 border border-zinc-600 rounded-xl px-4 py-3 text-white placeholder-zinc-400 focus:outline-none focus:border-[#FF7043] transition"
                />
                <input
                  type="text"
                  placeholder="Username"
                  value={username}
                  onChange={(e) => setUsername(e.target.value)}
                  required
                  className="w-full bg-zinc-800 border border-zinc-600 rounded-xl px-4 py-3 text-white placeholder-zinc-400 focus:outline-none focus:border-[#FF7043] transition"
                />
                <div className="flex gap-3">
                  <select
                    value={ageRange}
                    onChange={(e) => setAgeRange(e.target.value)}
                    className="flex-1 bg-zinc-800 border border-zinc-600 rounded-xl px-4 py-3 text-white focus:outline-none focus:border-[#FF7043] transition"
                  >
                    <option value="">Age range (optional)</option>
                    <option value="18-24">18–24</option>
                    <option value="25-34">25–34</option>
                    <option value="35-44">35–44</option>
                    <option value="45+">45+</option>
                  </select>
                  <input
                    type="text"
                    placeholder="Country (optional)"
                    value={country}
                    onChange={(e) => setCountry(e.target.value)}
                    className="flex-1 bg-zinc-800 border border-zinc-600 rounded-xl px-4 py-3 text-white placeholder-zinc-400 focus:outline-none focus:border-[#FF7043] transition"
                  />
                </div>
              </>
            )}
            <input
              type="email"
              placeholder="Email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
              className="w-full bg-zinc-800 border border-zinc-600 rounded-xl px-4 py-3 text-white placeholder-zinc-400 focus:outline-none focus:border-[#FF7043] transition"
            />
            <input
              type="password"
              placeholder="Password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              required
              className="w-full bg-zinc-800 border border-zinc-600 rounded-xl px-4 py-3 text-white placeholder-zinc-400 focus:outline-none focus:border-[#FF7043] transition"
            />

            <button
              type="submit"
              disabled={loading}
              className="w-full py-3 bg-[#FF7043] hover:bg-[#e55a2b] disabled:opacity-50 rounded-xl font-bold transition"
            >
              {loading ? 'Please wait...' : isLogin ? 'Sign In' : 'Create Account'}
            </button>
          </form>

          <div className="relative my-6">
            <div className="absolute inset-0 flex items-center">
              <div className="w-full border-t border-zinc-700" />
            </div>
            <div className="relative flex justify-center">
              <span className="bg-zinc-900 px-4 text-zinc-400 text-sm">or</span>
            </div>
          </div>

          <button
            onClick={handleGoogle}
            disabled={loading}
            className="w-full py-3 bg-zinc-800 hover:bg-zinc-700 border border-zinc-600 rounded-xl font-medium transition flex items-center justify-center gap-2 text-white"
          >
            <span className="font-bold">G</span> Continue with Google
          </button>

          <p className="text-center mt-6 text-white/40 text-sm">
            {isLogin ? "Don't have an account? " : 'Already have an account? '}
            <button
              onClick={() => setIsLogin(!isLogin)}
              className="text-[#FFD166] hover:underline"
            >
              {isLogin ? 'Sign up' : 'Sign in'}
            </button>
          </p>
        </div>
      </div>
    </div>
  );
}

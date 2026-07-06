// Shared score + countdown HUD for the web Game Zone engines (parity with the
// Flutter GameHud).

export function GameHud({
  score,
  successScore,
  secondsLeft,
  timeLimitSec,
}: {
  score: number;
  successScore: number;
  secondsLeft: number;
  timeLimitSec: number;
}) {
  const progress = timeLimitSec > 0 ? Math.max(0, Math.min(1, secondsLeft / timeLimitSec)) : 0;
  return (
    <div className="px-4 pt-3 pb-2">
      <div className="flex items-center justify-between">
        <span className="text-white font-extrabold">Score {score} / {successScore}</span>
        <span className={`font-extrabold ${secondsLeft <= 5 ? 'text-[#E94560]' : 'text-white'}`}>⏱ {secondsLeft}s</span>
      </div>
      <div className="mt-2 h-[5px] rounded-full overflow-hidden bg-white/10">
        <div className="h-full" style={{ width: `${progress * 100}%`, backgroundColor: '#5BE1FF' }} />
      </div>
    </div>
  );
}

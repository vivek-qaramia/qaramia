// Copies the single-threaded ffmpeg.wasm core out of node_modules into
// public/ffmpeg/ so the app can self-host it (lib/video-transcode loads from
// /ffmpeg/...). Runs on postinstall, so fresh installs / CI get the files
// automatically — they're gitignored, not committed (the wasm is ~32 MB).
import { mkdirSync, copyFileSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const srcDir = join(root, 'node_modules', '@ffmpeg', 'core', 'dist', 'umd');
const outDir = join(root, 'public', 'ffmpeg');
const files = ['ffmpeg-core.js', 'ffmpeg-core.wasm'];

if (!existsSync(join(srcDir, files[1]))) {
  // @ffmpeg/core not installed (e.g. --omit=dev without it as a dep). Don't
  // fail the install — the app only needs these at runtime when publishing.
  console.warn('[copy-ffmpeg-core] @ffmpeg/core not found; skipping');
  process.exit(0);
}

mkdirSync(outDir, { recursive: true });
for (const f of files) {
  copyFileSync(join(srcDir, f), join(outDir, f));
}
console.log(`[copy-ffmpeg-core] copied ${files.join(', ')} → public/ffmpeg/`);

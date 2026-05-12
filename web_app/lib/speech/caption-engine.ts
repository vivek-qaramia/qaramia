// Browser Web Speech API wrapper. Free, real-time, no server cost.
// Supported in Chrome, Edge, Safari (with webkit prefix). Firefox does not support it.

// Minimal SpeechRecognition typing — the global TS lib doesn't include these in all environments.
interface SpeechRecognitionAlternative { transcript: string; confidence: number }
interface SpeechRecognitionResult { 0: SpeechRecognitionAlternative; isFinal: boolean; length: number }
interface SpeechRecognitionResultList { [index: number]: SpeechRecognitionResult; length: number }
interface SpeechRecognitionEvent extends Event { resultIndex: number; results: SpeechRecognitionResultList }
interface SpeechRecognitionErrorEvent extends Event { error: string; message: string }

interface SpeechRecognitionInstance extends EventTarget {
  lang: string;
  continuous: boolean;
  interimResults: boolean;
  maxAlternatives: number;
  start: () => void;
  stop: () => void;
  abort: () => void;
  onresult: ((e: SpeechRecognitionEvent) => void) | null;
  onerror: ((e: SpeechRecognitionErrorEvent) => void) | null;
  onend: (() => void) | null;
}

type SpeechRecognitionCtor = new () => SpeechRecognitionInstance;

function getCtor(): SpeechRecognitionCtor | null {
  if (typeof window === 'undefined') return null;
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const w = window as any;
  return (w.SpeechRecognition as SpeechRecognitionCtor)
      ?? (w.webkitSpeechRecognition as SpeechRecognitionCtor)
      ?? null;
}

export function isCaptionSupported(): boolean {
  return getCtor() !== null;
}

export interface CaptionResult {
  text: string;
  isFinal: boolean;
}

export class CaptionEngine {
  private recognition: SpeechRecognitionInstance | null = null;
  private running = false;
  private shouldRestart = false;
  private onResult: (result: CaptionResult) => void;
  private lang: string;

  constructor(onResult: (result: CaptionResult) => void, lang = 'en-US') {
    this.onResult = onResult;
    this.lang = lang;
  }

  start(): boolean {
    const Ctor = getCtor();
    if (!Ctor) return false;
    if (this.running) return true;

    const r = new Ctor();
    r.continuous = true;
    r.interimResults = true;
    r.lang = this.lang;
    r.maxAlternatives = 1;

    r.onresult = (event) => {
      for (let i = event.resultIndex; i < event.results.length; i++) {
        const res = event.results[i];
        const text = res[0]?.transcript?.trim();
        if (!text) continue;
        this.onResult({ text, isFinal: res.isFinal });
      }
    };

    r.onerror = (event) => {
      // 'no-speech' and 'aborted' fire frequently and are not real errors
      if (event.error !== 'no-speech' && event.error !== 'aborted') {
        console.warn('Caption engine error:', event.error);
      }
    };

    r.onend = () => {
      // Browser stops recognition after periods of silence; restart if we still want it
      if (this.shouldRestart) {
        try { r.start(); } catch { /* already started */ }
      } else {
        this.running = false;
      }
    };

    this.recognition = r;
    this.shouldRestart = true;
    try {
      r.start();
      this.running = true;
      return true;
    } catch (err) {
      console.error('Failed to start caption engine:', err);
      this.recognition = null;
      this.running = false;
      return false;
    }
  }

  stop() {
    this.shouldRestart = false;
    if (this.recognition) {
      try { this.recognition.stop(); } catch { /* already stopped */ }
      this.recognition = null;
    }
    this.running = false;
  }

  setLanguage(lang: string) {
    this.lang = lang;
    if (this.running) {
      // Restart with new language
      this.stop();
      this.start();
    }
  }

  get isRunning() { return this.running; }
}

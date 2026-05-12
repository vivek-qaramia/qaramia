export interface AudioEffect {
  id: string;
  name: string;
  emoji: string;
}

export const AUDIO_EFFECTS: AudioEffect[] = [
  { id: 'none',      name: 'Normal',    emoji: '🎤' },
  { id: 'echo',      name: 'Echo',      emoji: '🔊' },
  { id: 'reverb',    name: 'Reverb',    emoji: '🏛️' },
  { id: 'robot',     name: 'Robot',     emoji: '🤖' },
  { id: 'telephone', name: 'Telephone', emoji: '📞' },
  { id: 'megaphone', name: 'Megaphone', emoji: '📣' },
  { id: 'deep',      name: 'Deep',      emoji: '🦁' },
];

export class AudioEffectPipeline {
  private ctx: AudioContext;
  private source: MediaStreamAudioSourceNode;
  readonly destination: MediaStreamAudioDestinationNode;
  private activeNodes: (AudioNode | OscillatorNode)[] = [];

  constructor(stream: MediaStream) {
    this.ctx = new AudioContext();
    this.source = this.ctx.createMediaStreamSource(stream);
    this.destination = this.ctx.createMediaStreamDestination();
    this.applyNone();
  }

  get outputStream(): MediaStream {
    return this.destination.stream;
  }

  setEffect(id: string) {
    this.teardown();
    switch (id) {
      case 'echo':      this.applyEcho(); break;
      case 'reverb':    this.applyReverb(); break;
      case 'robot':     this.applyRobot(); break;
      case 'telephone': this.applyTelephone(); break;
      case 'megaphone': this.applyMegaphone(); break;
      case 'deep':      this.applyDeep(); break;
      default:          this.applyNone(); break;
    }
  }

  close() {
    this.teardown();
    this.ctx.close();
  }

  private teardown() {
    this.source.disconnect();
    this.activeNodes.forEach((n) => {
      try { (n as OscillatorNode).stop?.(); } catch (_) {}
      n.disconnect();
    });
    this.activeNodes = [];
  }

  private track(...nodes: (AudioNode | OscillatorNode)[]) {
    this.activeNodes.push(...nodes);
  }

  // ── Effects ──────────────────────────────────────────────────────────────

  private applyNone() {
    this.source.connect(this.destination);
  }

  private applyEcho() {
    const delay = this.ctx.createDelay(1.0);
    const feedback = this.ctx.createGain();
    const wetGain = this.ctx.createGain();
    delay.delayTime.value = 0.28;
    feedback.gain.value = 0.38;
    wetGain.gain.value = 0.5;

    this.source.connect(this.destination);          // dry
    this.source.connect(delay);
    delay.connect(feedback);
    feedback.connect(delay);                        // feedback loop
    delay.connect(wetGain);
    wetGain.connect(this.destination);              // wet
    this.track(delay, feedback, wetGain);
  }

  private applyReverb() {
    const conv = this.ctx.createConvolver();
    conv.buffer = this.buildImpulse(2.8, 2.5);
    const wet = this.ctx.createGain();
    const dry = this.ctx.createGain();
    wet.gain.value = 0.55;
    dry.gain.value = 0.65;

    this.source.connect(dry);
    this.source.connect(conv);
    conv.connect(wet);
    dry.connect(this.destination);
    wet.connect(this.destination);
    this.track(conv, wet, dry);
  }

  private applyRobot() {
    // Ring-modulate the voice with a 50 Hz sawtooth carrier → buzzy robotic tone
    const carrier = this.ctx.createOscillator();
    carrier.type = 'sawtooth';
    carrier.frequency.value = 50;

    const mod = this.ctx.createGain();
    mod.gain.value = 0;          // starts at 0; carrier drives it ±amplitude
    carrier.connect(mod.gain);
    this.source.connect(mod);
    mod.connect(this.destination);
    carrier.start();
    this.track(carrier, mod);
  }

  private applyTelephone() {
    const hi = this.ctx.createBiquadFilter();
    hi.type = 'highpass';
    hi.frequency.value = 300;

    const lo = this.ctx.createBiquadFilter();
    lo.type = 'lowpass';
    lo.frequency.value = 3400;

    const dist = this.ctx.createWaveShaper();
    dist.curve = this.distortionCurve(30);

    this.source.connect(hi);
    hi.connect(lo);
    lo.connect(dist);
    dist.connect(this.destination);
    this.track(hi, lo, dist);
  }

  private applyMegaphone() {
    const hi = this.ctx.createBiquadFilter();
    hi.type = 'highpass';
    hi.frequency.value = 500;

    const lo = this.ctx.createBiquadFilter();
    lo.type = 'lowpass';
    lo.frequency.value = 4000;

    const dist = this.ctx.createWaveShaper();
    dist.curve = this.distortionCurve(60);

    const gain = this.ctx.createGain();
    gain.gain.value = 1.8;

    this.source.connect(hi);
    hi.connect(lo);
    lo.connect(dist);
    dist.connect(gain);
    gain.connect(this.destination);
    this.track(hi, lo, dist, gain);
  }

  private applyDeep() {
    const shelf = this.ctx.createBiquadFilter();
    shelf.type = 'lowshelf';
    shelf.frequency.value = 180;
    shelf.gain.value = 9;

    const conv = this.ctx.createConvolver();
    conv.buffer = this.buildImpulse(1.4, 3.5);

    const wet = this.ctx.createGain();
    const dry = this.ctx.createGain();
    wet.gain.value = 0.28;
    dry.gain.value = 0.85;

    this.source.connect(shelf);
    shelf.connect(dry);
    shelf.connect(conv);
    conv.connect(wet);
    dry.connect(this.destination);
    wet.connect(this.destination);
    this.track(shelf, conv, wet, dry);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  private buildImpulse(duration: number, decay: number): AudioBuffer {
    const sr = this.ctx.sampleRate;
    const len = Math.floor(sr * duration);
    const buf = this.ctx.createBuffer(2, len, sr);
    for (let ch = 0; ch < 2; ch++) {
      const d = buf.getChannelData(ch);
      for (let i = 0; i < len; i++) {
        d[i] = (Math.random() * 2 - 1) * Math.pow(1 - i / len, decay);
      }
    }
    return buf;
  }

  private distortionCurve(amount: number): Float32Array<ArrayBuffer> {
    const n = 512;
    const curve = new Float32Array(new ArrayBuffer(n * 4));
    for (let i = 0; i < n; i++) {
      const x = (i * 2) / n - 1;
      curve[i] = ((Math.PI + amount) * x) / (Math.PI + amount * Math.abs(x));
    }
    return curve;
  }
}

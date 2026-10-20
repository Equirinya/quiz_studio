// Synthesises the built-in sound effects that can be made from plain tones
// and noise, into assets/sounds/effects/. All come out at the same loudness
// (RMS of the loud part matched, peaks kept below -1 dBFS).
//
//   node tool/make_effects.js
const fs = require("fs");
const path = require("path");

const rate = 44100;
const TAU = Math.PI * 2;

let seed = 0x2545f491;
function noise() {
  seed ^= seed << 13; seed >>>= 0;
  seed ^= seed >>> 17;
  seed ^= seed << 5; seed >>>= 0;
  return seed / 0x100000000 * 2 - 1;
}

const buffer = (seconds) => new Float64Array(Math.ceil(seconds * rate));

/// Adds a sine at [freq] (Hz, or a function of time) with an envelope.
function tone(out, { start = 0, freq, gain = 1, attack = 0.005, decay = 0.5, length }) {
  const s0 = Math.floor(start * rate);
  const n = Math.floor((length ?? decay * 6) * rate);
  let phase = 0;
  for (let i = 0; i < n && s0 + i < out.length; i++) {
    const t = i / rate;
    const f = typeof freq === "function" ? freq(t) : freq;
    phase += TAU * f / rate;
    const env = Math.min(1, t / attack) * Math.exp(-t / decay);
    out[s0 + i] += Math.sin(phase) * env * gain;
  }
}

/// A bell: a few partials, the higher ones dying faster.
function bell(out, start, freq, gain = 1, decay = 0.8) {
  for (const [ratio, g, d] of [[1, 1, 1], [2.0, 0.5, 0.6], [3.01, 0.25, 0.35], [4.2, 0.12, 0.2]]) {
    tone(out, { start, freq: freq * ratio, gain: gain * g, decay: decay * d });
  }
}

/// Noise through a simple one-pole low-pass with a moving cutoff.
function filteredNoise(out, { start = 0, length, cutoff, gain = 1, envelope }) {
  const s0 = Math.floor(start * rate);
  const n = Math.floor(length * rate);
  let low = 0;
  for (let i = 0; i < n && s0 + i < out.length; i++) {
    const t = i / rate;
    const c = typeof cutoff === "function" ? cutoff(t) : cutoff;
    const a = 1 - Math.exp(-TAU * c / rate);
    low += a * (noise() - low);
    out[s0 + i] += low * gain * envelope(t / length);
  }
}

function click(out, start, freq, gain = 1) {
  tone(out, { start, freq, gain, attack: 0.0005, decay: 0.012, length: 0.06 });
  filteredNoise(out, { start, length: 0.02, cutoff: 6000, gain: gain * 0.6, envelope: (x) => 1 - x });
}

/// Matches the loudness of the loudest part, then keeps the peaks safe.
function level(samples) {
  const window = Math.floor(rate * 0.1);
  let loudest = 0;
  for (let i = 0; i + window <= samples.length; i += window / 2) {
    let sum = 0;
    for (let j = i; j < i + window; j++) sum += samples[j] * samples[j];
    loudest = Math.max(loudest, Math.sqrt(sum / window));
  }
  if (loudest === 0) return samples;
  const target = Math.pow(10, -16 / 20);
  let gain = target / loudest;
  let peak = 0;
  for (const s of samples) peak = Math.max(peak, Math.abs(s * gain));
  const ceiling = Math.pow(10, -1 / 20);
  if (peak > ceiling) gain *= ceiling / peak;
  return samples.map((s) => s * gain);
}

function fadeEdges(samples, seconds = 0.004) {
  const n = Math.floor(seconds * rate);
  for (let i = 0; i < n && i < samples.length; i++) {
    samples[i] *= i / n;
    samples[samples.length - 1 - i] *= i / n;
  }
  return samples;
}

function write(name, samples) {
  const data = Buffer.alloc(samples.length * 2);
  fadeEdges(level(samples)).forEach((s, i) => data.writeInt16LE(Math.round(Math.max(-1, Math.min(1, s)) * 32767), i * 2));
  const header = Buffer.alloc(44);
  header.write("RIFF", 0);
  header.writeUInt32LE(36 + data.length, 4);
  header.write("WAVE", 8);
  header.write("fmt ", 12);
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20);
  header.writeUInt16LE(1, 22);
  header.writeUInt32LE(rate, 24);
  header.writeUInt32LE(rate * 2, 28);
  header.writeUInt16LE(2, 32);
  header.writeUInt16LE(16, 34);
  header.write("data", 36);
  header.writeUInt32LE(data.length, 40);
  fs.writeFileSync(path.join(dir, name + ".wav"), Buffer.concat([header, data]));
  console.log(name, (samples.length / rate).toFixed(2) + " s");
}

let dir = path.join(__dirname, "..", "assets", "sounds", "effects");
fs.mkdirSync(dir, { recursive: true });

// Reveal: a soft airy whoosh into a bright ding.
{
  const out = buffer(1.6);
  filteredNoise(out, { length: 0.28, cutoff: (t) => 800 + t * 14000, gain: 0.5, envelope: (x) => Math.sin(Math.PI * x) });
  bell(out, 0.22, 1318.5, 0.9, 0.7);
  write("reveal", out);
}

// Tick: one short wooden tick, for moving on in a Fragenhagel.
{
  const out = buffer(0.15);
  click(out, 0, 1800, 1);
  write("tick", out);
}

// Countdown: ten seconds of tick-tock, ending on a higher double beep.
{
  const out = buffer(10.6);
  for (let s = 0; s < 10; s++) click(out, s, s % 2 === 0 ? 1800 : 1350, s >= 7 ? 1.3 : 1);
  tone(out, { start: 10, freq: 1760, gain: 0.8, decay: 0.06, length: 0.2 });
  tone(out, { start: 10.18, freq: 1760, gain: 0.8, decay: 0.06, length: 0.2 });
  write("countdown", out);
}

// Locked in: a quick rising two-note ping.
{
  const out = buffer(0.6);
  tone(out, { freq: 987.8, gain: 0.7, decay: 0.08, length: 0.3 });
  tone(out, { start: 0.08, freq: 1479.98, gain: 0.8, decay: 0.15, length: 0.5 });
  write("lock_in", out);
}

// Question: a rising three-note chime.
{
  const out = buffer(1.8);
  [1046.5, 1318.5, 1568].forEach((f, i) => bell(out, i * 0.11, f, 0.7, 0.6));
  write("question_open", out);
}

// Time's up: a gong, deep and inharmonic, with a slow shimmer.
{
  const out = buffer(4);
  const base = 98;
  for (const [ratio, g, d] of [[1, 1, 1.6], [1.48, 0.6, 1.2], [2.02, 0.45, 0.9], [2.74, 0.3, 0.7], [3.76, 0.2, 0.5], [5.4, 0.12, 0.3]]) {
    tone(out, { freq: (t) => base * ratio * (1 + 0.004 * Math.sin(TAU * 3.2 * t)), gain: g, attack: 0.01, decay: d, length: 4 });
  }
  filteredNoise(out, { length: 0.08, cutoff: 3000, gain: 0.5, envelope: (x) => 1 - x });
  write("times_up", out);
}

// Boing: a spring, wobbling up and settling.
{
  const out = buffer(1);
  tone(out, {
    freq: (t) => 180 + 260 * (1 - Math.exp(-t * 7)) + 60 * Math.sin(TAU * 11 * t) * Math.exp(-t * 4),
    gain: 1,
    attack: 0.004,
    decay: 0.28,
    length: 1,
  });
  write("boing", out);
}

// Steal: a rising swoop that lands on a hit.
{
  const out = buffer(1.3);
  tone(out, { freq: (t) => 220 * Math.pow(6, Math.min(t / 0.45, 1)), gain: 0.6, attack: 0.05, decay: 10, length: 0.45 });
  tone(out, { freq: (t) => 330 * Math.pow(6, Math.min(t / 0.45, 1)), gain: 0.3, attack: 0.05, decay: 10, length: 0.45 });
  filteredNoise(out, { length: 0.45, cutoff: (t) => 500 + t * 8000, gain: 0.3, envelope: (x) => x });
  tone(out, { start: 0.45, freq: 110, gain: 1, attack: 0.002, decay: 0.25, length: 0.8 });
  filteredNoise(out, { start: 0.45, length: 0.25, cutoff: 2500, gain: 0.8, envelope: (x) => Math.pow(1 - x, 3) });
  write("steal", out);
}

// Drumroll: a snare roll swelling for three seconds, then a crash.
{
  const out = buffer(5);
  const hits = 3 * 28;
  for (let i = 0; i < hits; i++) {
    const t = i / 28 + (noise() * 0.004);
    const swell = 0.25 + 0.75 * (i / hits);
    filteredNoise(out, { start: t, length: 0.05, cutoff: 5000, gain: swell * (0.8 + 0.2 * noise()), envelope: (x) => Math.pow(1 - x, 4) });
    tone(out, { start: t, freq: 190, gain: swell * 0.3, attack: 0.0005, decay: 0.02, length: 0.05 });
  }
  // The final hit: a bass drum and a crash cymbal.
  tone(out, { start: 3, freq: (t) => 60 + 60 * Math.exp(-t * 30), gain: 1.4, attack: 0.001, decay: 0.25, length: 1 });
  filteredNoise(out, { start: 3, length: 2, cutoff: 9000, gain: 0.9, envelope: (x) => Math.exp(-x * 4) });
  write("drumroll", out);
}

// ── More versions to choose from: node tool/make_effects.js --candidates <dir>
// writes every version as <name>_<letter>.wav, the ones above being "a".
const variants = {
  reveal: [
    // b: a glassy upward glissando.
    () => {
      const out = buffer(1.4);
      [1568, 2093, 2637].forEach((f, i) => bell(out, i * 0.05, f, 0.5, 0.5));
      return out;
    },
    // c: a soft marimba-like knock.
    () => {
      const out = buffer(1);
      tone(out, { freq: 784, gain: 1, attack: 0.002, decay: 0.18 });
      tone(out, { freq: 784 * 4, gain: 0.25, attack: 0.002, decay: 0.05 });
      return out;
    },
  ],
  tick: [
    () => {
      const out = buffer(0.12);
      tone(out, { freq: 2600, gain: 1, attack: 0.0005, decay: 0.008, length: 0.05 });
      return out;
    },
  ],
  countdown: [
    // b: beeps instead of ticks.
    () => {
      const out = buffer(10.8);
      for (let s = 0; s < 10; s++) tone(out, { start: s, freq: s >= 7 ? 1320 : 880, gain: 0.9, attack: 0.003, decay: 0.05, length: 0.15 });
      tone(out, { start: 10, freq: 1760, gain: 1, attack: 0.003, decay: 0.4, length: 0.8 });
      return out;
    },
  ],
  lock_in: [
    // b: a soft "pop" with a click.
    () => {
      const out = buffer(0.4);
      tone(out, { freq: (t) => 500 + 900 * Math.exp(-t * 40), gain: 1, attack: 0.001, decay: 0.05, length: 0.3 });
      return out;
    },
  ],
  question_open: [
    // b: a two-note "attention" chime, like on a train.
    () => {
      const out = buffer(2);
      bell(out, 0, 784, 0.8, 0.9);
      bell(out, 0.35, 659.25, 0.8, 1.1);
      return out;
    },
  ],
  times_up: [
    // b: a game-show buzzer horn.
    () => {
      const out = buffer(1.4);
      for (const f of [146.8, 155.6, 293.7]) {
        const s0 = 0, n = Math.floor(1.1 * rate);
        let phase = 0;
        for (let i = 0; i < n; i++) {
          phase += TAU * f / rate;
          const t = i / rate;
          // A square-ish wave: harsh on purpose.
          const v = Math.tanh(4 * Math.sin(phase));
          const env = Math.min(1, t / 0.01) * (t > 1 ? (1.1 - t) / 0.1 : 1);
          out[s0 + i] += v * env * 0.3;
        }
      }
      return out;
    },
  ],
  boing: [
    // b: a slide whistle going up and down.
    () => {
      const out = buffer(1.2);
      tone(out, { freq: (t) => 700 + 900 * Math.sin(Math.PI * Math.min(t / 1.1, 1)), gain: 0.9, attack: 0.03, decay: 10, length: 1.1 });
      return out;
    },
  ],
  steal: [
    // b: a quick double whoosh.
    () => {
      const out = buffer(0.9);
      filteredNoise(out, { length: 0.3, cutoff: (t) => 400 + t * 20000, gain: 0.8, envelope: (x) => Math.sin(Math.PI * x) });
      filteredNoise(out, { start: 0.32, length: 0.4, cutoff: (t) => 8000 - t * 15000, gain: 0.8, envelope: (x) => Math.sin(Math.PI * x) });
      return out;
    },
  ],
  drumroll: [
    // b: shorter and tighter, two seconds, ending on a cymbal only.
    () => {
      const out = buffer(3.5);
      const hits = 2 * 32;
      for (let i = 0; i < hits; i++) {
        const swell = 0.3 + 0.7 * (i / hits);
        filteredNoise(out, { start: i / 32, length: 0.035, cutoff: 7000, gain: swell, envelope: (x) => Math.pow(1 - x, 5) });
      }
      filteredNoise(out, { start: 2, length: 1.5, cutoff: 11000, gain: 1, envelope: (x) => Math.exp(-x * 3) });
      return out;
    },
  ],
  fanfare: [
    // a: a short brass-like "ta-da-daaa".
    () => {
      const out = buffer(2.2);
      const brass = (start, f, len) => {
        for (const [k, g] of [[1, 1], [2, 0.6], [3, 0.4], [4, 0.25], [5, 0.15]]) {
          tone(out, { start, freq: (t) => f * k * (1 + 0.006 * Math.sin(TAU * 5.5 * t)), gain: g * 0.5, attack: 0.03, decay: 10, length: len });
        }
      };
      brass(0, 523.25, 0.16);
      brass(0.18, 523.25, 0.16);
      brass(0.36, 659.25, 0.16);
      brass(0.54, 783.99, 1.2);
      return out;
    },
  ],
  right_answer: [
    // a: a bright rising "ding-ding".
    () => {
      const out = buffer(1.4);
      bell(out, 0, 1046.5, 0.9, 0.5);
      bell(out, 0.12, 1568, 1, 0.8);
      return out;
    },
  ],
  wrong_answer: [
    // a: a low falling "bwomp".
    () => {
      const out = buffer(1);
      tone(out, { freq: (t) => 220 * Math.pow(0.6, t / 0.6), gain: 1, attack: 0.01, decay: 0.35, length: 0.9 });
      tone(out, { freq: (t) => 233 * Math.pow(0.6, t / 0.6), gain: 0.7, attack: 0.01, decay: 0.35, length: 0.9 });
      return out;
    },
  ],
};

const candidates = process.argv.indexOf("--candidates");
if (candidates >= 0) {
  dir = process.argv[candidates + 1];
  fs.mkdirSync(dir, { recursive: true });
  for (const [name, makers] of Object.entries(variants)) {
    const first = ["fanfare", "right_answer", "wrong_answer"].includes(name) ? "a" : "b";
    makers.forEach((make, i) => write(`${name}_${String.fromCharCode(first.charCodeAt(0) + i)}`, make()));
  }
}

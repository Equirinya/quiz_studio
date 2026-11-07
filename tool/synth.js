// Small synthesiser shared by the make_effects scripts: plucked strings,
// filtered brass, FM bells, noise sweeps, a room reverb, levelling and WAV out.
const fs = require("fs");
const path = require("path");

const rate = 44100;
const TAU = Math.PI * 2;
let dir = '.';
const setDir = (d) => { dir = d; fs.mkdirSync(d, { recursive: true }); };

let seed = 0x6d2b79f5;
function rnd() {
  seed ^= seed << 13; seed >>>= 0;
  seed ^= seed >>> 17;
  seed ^= seed << 5; seed >>>= 0;
  return seed / 0x100000000 * 2 - 1;
}
const buf = (s) => new Float64Array(Math.ceil(s * rate));
const note = (n) => 440 * Math.pow(2, (n - 69) / 12); // MIDI number to Hz

/// A plucked string (Karplus-Strong): harp, guitar, marimba-ish when short.
function pluck(out, start, freq, gain = 1, damp = 0.996, bright = 0.5) {
  const n = Math.max(2, Math.round(rate / freq));
  const line = Float64Array.from({ length: n }, () => rnd());
  const s0 = Math.floor(start * rate);
  let i = 0, prev = 0;
  for (let k = 0; s0 + k < out.length && k < rate * 3; k++) {
    const v = line[i];
    const next = line[(i + 1) % n];
    line[i] = damp * (bright * v + (1 - bright) * (v + next) / 2);
    out[s0 + k] += (v * 0.6 + prev * 0.4) * gain;
    prev = v;
    i = (i + 1) % n;
  }
}

/// A brass-like voice: a sawtooth through a low-pass that opens on attack.
function brass(out, start, freq, length, gain = 1) {
  const s0 = Math.floor(start * rate);
  let phase = 0, low = 0;
  const n = Math.floor((length + 0.25) * rate);
  for (let k = 0; k < n && s0 + k < out.length; k++) {
    const t = k / rate;
    const vib = 1 + 0.004 * Math.sin(TAU * 5.6 * t) * Math.min(1, t / 0.2);
    phase = (phase + freq * vib / rate) % 1;
    const saw = 2 * phase - 1;
    const env = Math.min(1, t / 0.03) * (t < length ? 1 - 0.25 * Math.min(1, t / 0.4) : Math.max(0, 0.75 * (1 - (t - length) / 0.25)));
    const cutoff = 600 + 3800 * env;
    low += (1 - Math.exp(-TAU * cutoff / rate)) * (saw - low);
    out[s0 + k] += low * env * gain;
  }
}

/// An FM bell: bright at first, mellowing as it rings.
function fmBell(out, start, freq, gain = 1, decay = 1.2, ratio = 1.4, depth = 3) {
  const s0 = Math.floor(start * rate);
  const n = Math.floor(decay * 5 * rate);
  for (let k = 0; k < n && s0 + k < out.length; k++) {
    const t = k / rate;
    const env = Math.min(1, t / 0.002) * Math.exp(-t / decay);
    const mod = depth * Math.exp(-t / (decay * 0.4)) * Math.sin(TAU * freq * ratio * t);
    out[s0 + k] += Math.sin(TAU * freq * t + mod) * env * gain;
  }
}

function sweepNoise(out, start, length, from, to, gain, shape) {
  const s0 = Math.floor(start * rate);
  let low = 0, band = 0;
  for (let k = 0; k < length * rate && s0 + k < out.length; k++) {
    const x = k / (length * rate);
    const c = from * Math.pow(to / from, x);
    const a = 1 - Math.exp(-TAU * c / rate);
    low += a * (rnd() - low);
    band += a * (low - band);
    out[s0 + k] += (low - band) * 2.5 * gain * shape(x);
  }
}

function sine(out, start, length, freq, gain, attack = 0.005, decay = 0.3) {
  const s0 = Math.floor(start * rate);
  let ph = 0;
  for (let k = 0; k < length * rate && s0 + k < out.length; k++) {
    const t = k / rate;
    const f = typeof freq === "function" ? freq(t) : freq;
    ph += TAU * f / rate;
    out[s0 + k] += Math.sin(ph) * gain * Math.min(1, t / attack) * Math.exp(-t / decay);
  }
}

/// A small, warm room: four combs and two all-passes (Schroeder).
function reverb(dry, wet = 0.25, size = 1) {
  const out = new Float64Array(dry.length);
  const combs = [1557, 1617, 1491, 1422].map((d) => ({ d: Math.round(d * size), b: new Float64Array(Math.round(d * size)), i: 0, low: 0 }));
  const alls = [225, 556].map((d) => ({ d, b: new Float64Array(d), i: 0 }));
  for (let k = 0; k < dry.length; k++) {
    let sum = 0;
    for (const c of combs) {
      const y = c.b[c.i];
      c.low = y * 0.7 + c.low * 0.3;
      c.b[c.i] = dry[k] + c.low * 0.8;
      c.i = (c.i + 1) % c.d;
      sum += y;
    }
    let y = sum / 4;
    for (const a of alls) {
      const bv = a.b[a.i];
      const o = -y + bv;
      a.b[a.i] = y + bv * 0.5;
      a.i = (a.i + 1) % a.d;
      y = o;
    }
    out[k] = dry[k] * (1 - wet) + y * wet * 2.2;
  }
  return out;
}

function level(s) {
  const w = Math.floor(rate * 0.1);
  let loud = 0;
  for (let i = 0; i + w <= s.length; i += w / 2) {
    let sum = 0;
    for (let j = i; j < i + w; j++) sum += s[j] * s[j];
    loud = Math.max(loud, Math.sqrt(sum / w));
  }
  let g = Math.pow(10, -16 / 20) / (loud || 1);
  let peak = 0;
  for (const v of s) peak = Math.max(peak, Math.abs(v * g));
  if (peak > 0.89) g *= 0.89 / peak;
  const out = s.map((v) => v * g);
  const f = Math.floor(0.004 * rate);
  for (let i = 0; i < f; i++) { out[i] *= i / f; out[out.length - 1 - i] *= i / f; }
  return out;
}

function write(name, s) {
  const lv = level(s);
  const data = Buffer.alloc(lv.length * 2);
  lv.forEach((v, i) => data.writeInt16LE(Math.round(Math.max(-1, Math.min(1, v)) * 32767), i * 2));
  const h = Buffer.alloc(44);
  h.write("RIFF", 0); h.writeUInt32LE(36 + data.length, 4); h.write("WAVE", 8); h.write("fmt ", 12);
  h.writeUInt32LE(16, 16); h.writeUInt16LE(1, 20); h.writeUInt16LE(1, 22); h.writeUInt32LE(rate, 24);
  h.writeUInt32LE(rate * 2, 28); h.writeUInt16LE(2, 32); h.writeUInt16LE(16, 34); h.write("data", 36); h.writeUInt32LE(data.length, 40);
  fs.writeFileSync(path.join(dir, name + ".wav"), Buffer.concat([h, data]));
  console.log(name, (s.length / rate).toFixed(2), "s");
}


module.exports = { rate, TAU, rnd, buf, note, pluck, brass, fmBell, sweepNoise, sine, reverb, level, write, setDir };

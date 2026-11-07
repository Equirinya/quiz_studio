// Third round: more reveals, the two countdown ideas with new sounds, more
// time's-up endings and new boings.
//
//   node tool/make_effects3.js <folder>
const { TAU, rnd, buf, note, pluck, fmBell, sweepNoise, sine, reverb, write, setDir, rate } = require("./synth");

setDir(process.argv[2]);

/// A clock tick: a very short resonant click, [high] or low for tick/tock.
function clockTick(out, start, high, gain = 1) {
  sweepNoise(out, start, 0.012, high ? 4200 : 2600, high ? 3800 : 2300, gain * 1.5, (x) => (1 - x) ** 2);
  sine(out, start, 0.05, high ? 3100 : 2200, gain * 0.35, 0.0003, 0.006);
}

/// A soft glassy ping, like Kenney's "glass" ones.
function glassPing(out, start, n, gain = 1) {
  fmBell(out, start, note(n), gain, 0.35, 3.5, 0.6);
  fmBell(out, start, note(n + 12), gain * 0.25, 0.2, 2, 0.3);
}

// ── reveal ────────────────────────────────────────────────────────────────
{ const o = buf(1); glassPing(o, 0, 88, 1); write("reveal_f", reverb(o, 0.25)); }
{ const o = buf(1); glassPing(o, 0, 81, 0.8); glassPing(o, 0.07, 88, 0.9); write("reveal_g", reverb(o, 0.25)); }
{ const o = buf(0.8); sine(o, 0, 0.3, (t) => 500 * Math.pow(3, Math.min(t / 0.12, 1)), 1, 0.003, 0.08); write("reveal_h", reverb(o, 0.2)); }
{ const o = buf(1.4); for (let i = 0; i < 9; i++) glassPing(o, i * 0.025, 84 + i * 2, 0.35); write("reveal_i", reverb(o, 0.35, 1.2)); }

// ── countdown: the tick-tock rhythm with real clock ticks ─────────────────
const endings = {
  chime: (o, t) => { glassPing(o, t, 84, 1); glassPing(o, t + 0.12, 91, 1); },
  bell: (o, t) => { for (let i = 0; i < 8; i++) fmBell(o, t + i * 0.07, note(96), 0.6, 0.12, 1.5, 1); },
  none: () => {},
};
for (const [name, end] of Object.entries(endings)) {
  const o = buf(11);
  for (let s = 0; s < 10; s++) clockTick(o, s, s % 2 === 0, s >= 7 ? 1.3 : 1);
  end(o, 10);
  write(`countdown_tick_${name}`, reverb(o, 0.12));
}

// ── countdown: the pulse that speeds up, with other endings ───────────────
const pulse = (o) => {
  let t = 0, gap = 1.1;
  while (t < 10) { sine(o, t, 0.4, (x) => 70 * Math.exp(-x * 8) + 45, 1, 0.003, 0.12); t += gap; gap = Math.max(0.35, gap * 0.9); }
};
{ const o = buf(11); pulse(o); endings.chime(o, 10); write("countdown_pulse_chime", reverb(o, 0.2)); }
{ const o = buf(11.5); pulse(o); for (const n of [60, 64, 67, 72]) sine(o, 10, 1.4, note(n), 0.35, 0.02, 0.6); write("countdown_pulse_chord", reverb(o, 0.25)); }
{ const o = buf(10.5); pulse(o); write("countdown_pulse_none", reverb(o, 0.2)); }

// ── time's up ─────────────────────────────────────────────────────────────
// A three-note fall, like a game show's "time's up".
{ const o = buf(2.2); [76, 72, 67].forEach((n, i) => { fmBell(o, i * 0.22, note(n), 0.8, 0.5, 1, 1); sine(o, i * 0.22, 0.6, note(n - 12), 0.4, 0.01, 0.3); }); write("times_up_f", reverb(o, 0.3)); }
// An old alarm bell, ringing fast.
{ const o = buf(2.2); for (let i = 0; i < 40; i++) fmBell(o, i * 0.045, note(93), 0.5, 0.06, 1.47, 2.5); write("times_up_g", reverb(o, 0.2)); }
// A deep horn chord that swells and stops.
{
  const o = buf(2);
  for (const n of [43, 50, 55, 59]) {
    let ph = 0, low = 0;
    for (let k = 0; k < 1.4 * rate; k++) {
      const t = k / rate;
      ph = (ph + note(n) / rate) % 1;
      low += 0.04 * ((2 * ph - 1) - low);
      o[k] += low * 0.5 * Math.min(1, t / 0.08) * (t > 1.25 ? (1.4 - t) / 0.15 : 1);
    }
  }
  write("times_up_h", reverb(o, 0.25, 1.2));
}

// ── boing ─────────────────────────────────────────────────────────────────
// A jaw harp: a buzzy tone whose vowel wobbles.
{
  const o = buf(1.2);
  let ph = 0, a = 0, b = 0;
  for (let k = 0; k < 1.1 * rate; k++) {
    const t = k / rate;
    ph = (ph + 98 / rate) % 1;
    const saw = 2 * ph - 1;
    const formant = 500 + 900 * (0.5 + 0.5 * Math.sin(TAU * (6 - 3 * t) * t));
    const c = 1 - Math.exp(-TAU * formant / rate);
    a += c * (saw - a); b += c * (a - b);
    o[k] += (a - b) * 3 * Math.exp(-t / 0.4) * Math.min(1, t / 0.005);
  }
  write("boing_f", reverb(o, 0.15));
}
// A spring door stop: a fast wobble that dies down.
{ const o = buf(1.4); sine(o, 0, 1.3, (t) => 330 + 220 * Math.sin(TAU * 18 * t) * Math.exp(-t * 3), 1, 0.001, 0.35); write("boing_g", reverb(o, 0.15)); }
// A cartoon ball bouncing to a stop.
{ const o = buf(1.6); let t = 0, gap = 0.3, g = 1; for (let i = 0; i < 6; i++) { sine(o, t, 0.2, (x) => 600 * Math.exp(-x * 14) + 180, g, 0.002, 0.07); t += gap; gap *= 0.7; g *= 0.75; } write("boing_h", reverb(o, 0.15)); }
// A slide whistle down, then a pop.
{ const o = buf(1.1); sine(o, 0, 0.7, (t) => 1800 * Math.pow(0.25, t / 0.7), 0.9, 0.03, 10); sine(o, 0.7, 0.2, (t) => 300 + 900 * Math.exp(-t * 50), 1, 0.001, 0.04); write("boing_i", reverb(o, 0.15)); }

// ── buzzers ───────────────────────────────────────────────────────────────
// The horn chord, short enough to be a team's buzzer.
{
  const o = buf(0.8);
  for (const n of [43, 50, 55, 59]) {
    let ph = 0, low = 0;
    for (let k = 0; k < 0.45 * rate; k++) {
      const t = k / rate;
      ph = (ph + note(n) / rate) % 1;
      low += 0.05 * ((2 * ph - 1) - low);
      o[k] += low * 0.5 * Math.min(1, t / 0.02) * (t > 0.37 ? (0.45 - t) / 0.08 : 1);
    }
  }
  write("buzzer_horn", reverb(o, 0.2));
}

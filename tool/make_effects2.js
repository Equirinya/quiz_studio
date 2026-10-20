// Second round of generated effects: plucked strings, filtered brass, FM bells
// and a small room reverb, which sound far less "beepy" than plain sines.
// Writes <name>_<letter>.wav into the folder given, for picking.
//
//   node tool/make_effects2.js <folder>
const { TAU, rnd, buf, note, pluck, brass, fmBell, sweepNoise, sine, reverb, write, setDir, rate } = require("./synth");

setDir(process.argv[2]);

// Question opens: d a brass stab chord; e a marimba run up.
{ const o = buf(1.6); for (const n of [60, 64, 67, 72]) brass(o, 0, note(n), 0.35, 0.3); write("question_open_d", reverb(o, 0.3)); }
{ const o = buf(1.6); [72, 76, 79, 84].forEach((n, i) => pluck(o, i * 0.07, note(n), 0.8, 0.985, 0.2)); write("question_open_e", reverb(o, 0.3)); }

// Reveal: d a harp glissando; e a whoosh that lands on a soft bell.
{ const o = buf(2); [67, 71, 74, 79, 83, 86].forEach((n, i) => pluck(o, i * 0.045, note(n), 0.7, 0.997, 0.5)); write("reveal_d", reverb(o, 0.35, 1.2)); }
{ const o = buf(1.8); sweepNoise(o, 0, 0.35, 300, 9000, 0.6, (x) => Math.sin(Math.PI * x) ** 2); fmBell(o, 0.3, note(84), 0.6, 0.5, 2, 1.5); write("reveal_e", reverb(o, 0.3)); }

// Fanfare: d synth brass "ta-ta-ta-taaa" in thirds; e a bright bell chord cascade.
{
  const o = buf(2.6);
  const hit = (t, root, len) => { for (const n of [root, root + 4, root + 7]) brass(o, t, note(n), len, 0.28); };
  hit(0, 60, 0.12); hit(0.15, 60, 0.12); hit(0.3, 60, 0.12); hit(0.45, 65, 0.25); hit(0.75, 67, 0.9);
  write("fanfare_d", reverb(o, 0.3, 1.3));
}
{ const o = buf(2.8); [72, 76, 79, 84, 88].forEach((n, i) => fmBell(o, i * 0.08, note(n), 0.5, 1, 3.5, 1.2)); for (const n of [48, 55]) sine(o, 0.32, 2, note(n), 0.5, 0.01, 0.8); write("fanfare_e", reverb(o, 0.35, 1.3)); }

// Time's up: d an FM gong in a room; e a two-tone game-show buzzer, rounded off.
{ const o = buf(4.5); fmBell(o, 0, 92, 1, 1.4, 1.41, 4); fmBell(o, 0, 92 * 2.76, 0.3, 0.8, 1.2, 2); write("times_up_d", reverb(o, 0.35, 1.4)); }
{
  const o = buf(1.2);
  for (const f of [180, 240]) {
    let ph = 0, low = 0;
    for (let k = 0; k < 0.9 * rate; k++) {
      ph = (ph + f / rate) % 1;
      const sq = ph < 0.5 ? 1 : -1;
      low += 0.15 * (sq - low);
      const t = k / rate;
      o[k] += low * 0.4 * Math.min(1, t / 0.01) * (t > 0.8 ? (0.9 - t) / 0.1 : 1);
    }
  }
  write("times_up_e", reverb(o, 0.15));
}

// Countdown: d a woodblock tick-tock; e a low pulse that speeds up.
{ const o = buf(10.8); for (let s = 0; s < 10; s++) pluck(o, s, s % 2 ? note(79) : note(84), s >= 7 ? 1 : 0.7, 0.9, 0.1); fmBell(o, 10, note(88), 0.8, 0.6, 2, 1); write("countdown_d", reverb(o, 0.2)); }
{ const o = buf(10.8); let t = 0, gap = 1.1; while (t < 10) { sine(o, t, 0.4, (x) => 70 * Math.exp(-x * 8) + 45, 1, 0.003, 0.12); t += gap; gap = Math.max(0.35, gap * 0.9); } fmBell(o, 10, note(76), 0.9, 0.8, 1.4, 3); write("countdown_e", reverb(o, 0.2)); }

// Next item: d a woodblock; e a soft pop.
{ const o = buf(0.5); pluck(o, 0, note(84), 1, 0.9, 0.1); write("tick_d", reverb(o, 0.15)); }
{ const o = buf(0.4); sine(o, 0, 0.2, (t) => 300 + 1200 * Math.exp(-t * 60), 1, 0.001, 0.04); write("tick_e", reverb(o, 0.15)); }

// Steal: d a riser into an impact; e a quick harp swoop down and up.
{ const o = buf(2); sweepNoise(o, 0, 0.7, 200, 8000, 0.5, (x) => x * x); sine(o, 0, 0.7, (t) => 100 * Math.pow(4, t / 0.7), 0.5, 0.05, 10); sine(o, 0.7, 1.2, (t) => 55 + 40 * Math.exp(-t * 20), 1.2, 0.002, 0.35); sweepNoise(o, 0.7, 0.6, 3000, 600, 0.6, (x) => (1 - x) ** 3); write("steal_d", reverb(o, 0.3, 1.2)); }
{ const o = buf(1.6); [84, 79, 76, 72, 76, 79, 84, 88].forEach((n, i) => pluck(o, i * 0.035, note(n), 0.6, 0.996, 0.5)); write("steal_e", reverb(o, 0.3)); }

// Boing: d a plucked spring with a bend; e a cartoon "bloop".
{
  const o = buf(1.2);
  sine(o, 0, 1.1, (t) => 140 * (1 + 0.6 * Math.exp(-t * 6) * Math.sin(TAU * 9 * t)) * (1 + 1.4 * (1 - Math.exp(-t * 10))), 1, 0.002, 0.3);
  write("boing_d", reverb(o, 0.15));
}
{ const o = buf(0.8); sine(o, 0, 0.6, (t) => 900 * Math.exp(-t * 6) + 120, 1, 0.003, 0.15); sine(o, 0.12, 0.5, (t) => 1400 * Math.exp(-t * 7) + 200, 0.6, 0.003, 0.12); write("boing_e", reverb(o, 0.15)); }

// Drumroll: d a snare roll built from noise and a body tone, with a crash, in a room.
{
  const o = buf(4.5);
  for (let i = 0; i < 2.6 * 30; i++) {
    const t = i / 30 + rnd() * 0.003, g = 0.25 + 0.75 * (i / 78);
    sweepNoise(o, t, 0.04, 5000, 3000, g, (x) => (1 - x) ** 4);
    sine(o, t, 0.04, 210, g * 0.4, 0.0005, 0.015);
  }
  sine(o, 2.6, 1, (t) => 55 + 70 * Math.exp(-t * 35), 1.5, 0.001, 0.3);
  sweepNoise(o, 2.6, 1.8, 9000, 6000, 1, (x) => Math.exp(-x * 4));
  write("drumroll_d", reverb(o, 0.25, 1.2));
}

// Fourth round: a soft "pling" for a team locking its answer in, and a
// theatrical three-note fail ("dum dum duuum").
//
//   node tool/sounds/make_effects4.js <folder>
const { buf, note, fmBell, brass, sine, reverb, write, setDir } = require("./synth");

setDir(process.argv[2]);

// ── lock in: a short glassy pling, a little below the other effects ──────
{
  const o = buf(0.9);
  fmBell(o, 0, note(88), 1, 0.22, 3.5, 0.5);
  fmBell(o, 0, note(100), 0.18, 0.12, 2, 0.3);
  write("pling", reverb(o, 0.2), -6);
}

// ── fail: three brass notes, each lower, the last held and fading ────────
{
  const o = buf(3.2);
  const notes = [[0, 55, 0.3], [0.42, 54, 0.3], [0.84, 53, 1.6]];
  for (const [t, n, len] of notes) {
    brass(o, t, note(n), len, 0.6);
    brass(o, t, note(n - 12), len, 0.35);
    // A low thump under each note.
    sine(o, t, 0.35, (x) => 70 * Math.pow(0.6, x / 0.3), 0.5, 0.002, 0.18);
  }
  write("dum_dum_duum", reverb(o, 0.3, 1.2));
}

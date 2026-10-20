// Writes the two built-in noise loops to assets/sounds/ambience/:
//   white_noise.wav: plain white noise
//   soft_noise.wav:  brown noise, mostly low frequencies, much easier on the ear
// Both are quiet (they only keep speakers awake) and loop without a seam:
// the last half second is cross-faded into the first.
//
//   node tool/make_noise.js
const fs = require("fs");
const path = require("path");

const rate = 22050;
const seconds = 20;
const fade = Math.floor(rate * 0.5);
const n = rate * seconds;

// A small seeded generator, so a re-run gives the same files.
let seed = 0x9e3779b9;
function random() {
  seed ^= seed << 13; seed >>>= 0;
  seed ^= seed >>> 17;
  seed ^= seed << 5; seed >>>= 0;
  return seed / 0x100000000 * 2 - 1;
}

function white(count) {
  return Float64Array.from({ length: count }, () => random());
}

function brown(count) {
  const out = new Float64Array(count);
  let last = 0;
  for (let i = 0; i < count; i++) {
    last = (last + 0.02 * random()) / 1.02;
    out[i] = last * 3.5;
  }
  return out;
}

/// The last [fade] samples blended into the first, then cut off: the loop
/// point is the same sound on both sides.
function seamless(samples) {
  const body = samples.slice(0, samples.length - fade);
  for (let i = 0; i < fade; i++) {
    const t = i / fade;
    body[i] = body[i] * t + samples[samples.length - fade + i] * (1 - t);
  }
  return body;
}

function writeWav(file, samples, volume) {
  let peak = 0;
  for (const s of samples) peak = Math.max(peak, Math.abs(s));
  const data = Buffer.alloc(samples.length * 2);
  samples.forEach((s, i) => data.writeInt16LE(Math.round((s / peak) * volume * 32767), i * 2));
  const header = Buffer.alloc(44);
  header.write("RIFF", 0);
  header.writeUInt32LE(36 + data.length, 4);
  header.write("WAVE", 8);
  header.write("fmt ", 12);
  header.writeUInt32LE(16, 16);
  header.writeUInt16LE(1, 20); // PCM
  header.writeUInt16LE(1, 22); // mono
  header.writeUInt32LE(rate, 24);
  header.writeUInt32LE(rate * 2, 28);
  header.writeUInt16LE(2, 32);
  header.writeUInt16LE(16, 34);
  header.write("data", 36);
  header.writeUInt32LE(data.length, 40);
  fs.writeFileSync(file, Buffer.concat([header, data]));
}

const dir = path.join(__dirname, "..", "assets", "sounds", "ambience");
fs.mkdirSync(dir, { recursive: true });
writeWav(path.join(dir, "white_noise.wav"), seamless(white(n + fade)), 0.25);
writeWav(path.join(dir, "soft_noise.wav"), seamless(brown(n + fade)), 0.5);
console.log("written to", dir);

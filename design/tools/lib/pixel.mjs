import fs from 'node:fs';
import path from 'node:path';
import { PNG } from 'pngjs';
import pixelmatch from 'pixelmatch';

const readPng = (p) => PNG.sync.read(fs.readFileSync(p));

/** Crop a PNG to w×h from the top-left (pages legitimately differ in height). */
function crop(src, w, h) {
  const out = new PNG({ width: w, height: h });
  PNG.bitblt(src, out, 0, 0, Math.min(w, src.width), Math.min(h, src.height), 0, 0);
  return out;
}

/**
 * Pixel-compare two screenshots over their overlapping area.
 * Returns { mismatchPct, sizeDelta, diffPath } — advisory by design: fonts,
 * real data and antialiasing move pixels without breaking fidelity. The
 * structural checks are the hard gate; this is the eyeball.
 */
export function pixelDiff(goldenPath, implPath, diffPath, { threshold = 0.12 } = {}) {
  if (!fs.existsSync(goldenPath) || !fs.existsSync(implPath)) return null;
  const a = readPng(goldenPath), b = readPng(implPath);
  const w = Math.min(a.width, b.width), h = Math.min(a.height, b.height);
  if (!w || !h) return null;
  const ca = crop(a, w, h), cb = crop(b, w, h);
  const diff = new PNG({ width: w, height: h });
  const bad = pixelmatch(ca.data, cb.data, diff.data, w, h, { threshold, includeAA: false });
  fs.mkdirSync(path.dirname(diffPath), { recursive: true });
  fs.writeFileSync(diffPath, PNG.sync.write(diff));
  return {
    mismatchPct: +((bad / (w * h)) * 100).toFixed(2),
    comparedArea: `${w}×${h}`,
    sizeDelta: { w: b.width - a.width, h: b.height - a.height },
    diffPath,
  };
}

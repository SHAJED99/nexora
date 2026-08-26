import fs from 'node:fs';
import path from 'node:path';
import url from 'node:url';
import YAML from 'yaml';

export const ROOT = path.resolve(path.dirname(url.fileURLToPath(import.meta.url)), '../../..');
export const rel = (p) => path.relative(ROOT, p);

const read = (p) => YAML.parse(fs.readFileSync(p, 'utf8'));

export function loadSources(file = 'design/sources.yaml') {
  const p = path.join(ROOT, file);
  if (!fs.existsSync(p)) throw new Error(`missing ${file} — see design/README.md`);
  const cfg = read(p);
  cfg.screens = cfg.screens || [];
  // Where the golden lands. Overridable so the self-test can use a scratch dir
  // instead of writing fixture data into the project's committed design law.
  cfg.golden_root = cfg.golden_root || 'design/golden';
  for (const s of cfg.screens) {
    s.viewports = (s.viewports || ['1440x900']).map(parseViewport);
    s.states = s.states?.length ? s.states : [{ name: 'default' }];
    s.mask = s.mask || [];
    s.ignore_text = s.ignore_text || [];
  }
  return cfg;
}

export function loadThresholds(file = 'design/thresholds.yaml') {
  return read(path.join(ROOT, file));
}

export function parseViewport(v) {
  if (typeof v === 'object') return v;
  const [w, h] = String(v).split('x').map(Number);
  return { w, h, name: String(v) };
}

export function parseArgs(argv) {
  const out = { _: [] };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a.startsWith('--')) {
      const k = a.slice(2);
      const v = argv[i + 1] && !argv[i + 1].startsWith('--') ? argv[++i] : true;
      out[k] = v;
    } else out._.push(a);
  }
  return out;
}

export const goldenDir = (screen, state, vp, root = 'design/golden') =>
  path.join(ROOT, root, screen, `${state}@${vp.name}`);

export function writeJson(p, data) {
  fs.mkdirSync(path.dirname(p), { recursive: true });
  fs.writeFileSync(p, JSON.stringify(data, null, 2));
}

export function readJson(p) {
  return JSON.parse(fs.readFileSync(p, 'utf8'));
}

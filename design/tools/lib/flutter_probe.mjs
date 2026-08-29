// design/tools/lib/flutter_probe.mjs — normalizes a Flutter widget-tree dump
// (written by test/design/flutter_probe_dumper.dart's dumpScreenProbe) into
// the exact shape design/tools/lib/probe.mjs returns for a DOM page, so
// design/tools/lib/compare.mjs runs completely unchanged against either
// source (E06-T01).
//
// The Dart dumper already emits colors as CSS rgb()/rgba() strings and
// lengths as "Npx" strings — it does the DOM-unit conversion, not this file
// (see test/design/flutter_probe_dumper.dart's header for that choice) — so
// this loader is deliberately a thin, mostly-structural pass: read the JSON,
// fill in any field a hand-written dump might omit, and hand back exactly
// what probe.mjs's return value looks like.
import fs from 'node:fs';

/** @typedef {import('./probe.mjs')} _ProbeShapeReference */

const FIELD_DEFAULTS = {
  tag: 'GENERIC', role: 'generic', text: '', depth: 0, type: '', name: '',
  placeholder: '', alt: '', required: false, disabled: false, surface: false,
};

const STYLE_DEFAULTS = {
  color: 'rgb(0, 0, 0)',
  background: 'rgba(0, 0, 0, 0)',
  fontFamily: '',
  fontSize: '0px',
  fontWeight: '400',
  radius: '0px',
  borderWidth: '0px',
  borderColor: 'rgba(0, 0, 0, 0)',
  padding: '0px',
  shadow: 'none',
  textTransform: 'none',
};

const TOKEN_GROUPS = [
  'color', 'background', 'fontFamily', 'fontSize',
  'fontWeight', 'radius', 'borderColor', 'shadow', 'spacing',
];

/**
 * Reads the JSON at `dumpPath` (written by `dumpScreenProbe`) and returns the
 * same normalized structure `probe.mjs`'s `probeFn()` returns for a DOM page:
 * `{ url, title, viewport, scrollHeight, elements, tokens }`.
 *
 * @param {string} dumpPath
 * @returns {{url: string, title: string, viewport: {w:number,h:number}, scrollHeight: number, elements: object[], tokens: object}}
 */
export function loadFlutterProbe(dumpPath) {
  if (!fs.existsSync(dumpPath)) {
    throw new Error(`no Flutter probe dump at ${dumpPath} — run: make design-probe`);
  }
  const raw = JSON.parse(fs.readFileSync(dumpPath, 'utf8'));

  const elements = (raw.elements || []).map((e) => ({
    ...FIELD_DEFAULTS,
    ...e,
    box: { x: 0, y: 0, w: 0, h: 0, ...(e.box || {}) },
    style: { ...STYLE_DEFAULTS, ...(e.style || {}) },
  }));

  const tokens = {};
  for (const group of TOKEN_GROUPS) tokens[group] = { ...(raw.tokens?.[group] || {}) };

  return {
    url: raw.url || '',
    title: raw.title || '',
    viewport: raw.viewport || { w: 0, h: 0 },
    scrollHeight: raw.scrollHeight || 0,
    elements,
    tokens,
  };
}

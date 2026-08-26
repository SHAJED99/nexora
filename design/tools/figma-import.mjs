#!/usr/bin/env node
// figma-import.mjs — Figma node tree → the same golden shape extract.mjs produces.
//
//   node design/tools/figma-import.mjs --screen login
//
// Expects, saved by you or by the figma MCP (see
// agent/skills/design-fidelity/references/ingest.md §Figma):
//   design/sources/figma/<screen>/nodes.json   ← GET /v1/files/:key/nodes?ids=…
//   design/sources/figma/<screen>/frame.png    ← GET /v1/images/:key?ids=…&scale=2
//
// Honest scope: a Figma node tree is not a rendered DOM. Roles are inferred from
// layer names and node types, so `Button/Primary` reads perfectly and `Frame 247`
// reads as a generic box. Prefer exporting the design to HTML and using
// extract.mjs — the probe then reads real computed styles. Use this when only
// the Figma file exists.
import fs from 'node:fs';
import path from 'node:path';
import { loadSources, parseArgs, goldenDir, writeJson, rel, ROOT } from './lib/config.mjs';

const args = parseArgs(process.argv.slice(2));
const cfg = loadSources(args.sources || 'design/sources.yaml');
const screens = cfg.screens.filter((s) => !args.screen || s.id === args.screen);

const round = (n) => Math.round(n || 0);
const rgba = (c, opacity = 1) => {
  if (!c) return 'rgba(0, 0, 0, 0)';
  const a = (c.a ?? 1) * opacity;
  const ch = (v) => Math.round((v ?? 0) * 255);
  return a >= 1 ? `rgb(${ch(c.r)}, ${ch(c.g)}, ${ch(c.b)})` : `rgba(${ch(c.r)}, ${ch(c.g)}, ${ch(c.b)}, ${+a.toFixed(3)})`;
};

const solidFill = (fills = []) => {
  const f = fills.find((x) => x.visible !== false && x.type === 'SOLID');
  return f ? rgba(f.color, f.opacity ?? 1) : null;
};

/** Layer names carry the intent. This is why naming your layers pays off. */
function roleOf(node) {
  const n = (node.name || '').toLowerCase();
  if (node.type === 'TEXT') {
    const size = node.style?.fontSize || 0;
    if (/^h([1-6])\b|title|heading/.test(n)) return `heading:${(n.match(/^h([1-6])/) || [, size >= 24 ? '1' : '2'])[1]}`;
    return 'generic';
  }
  if (/\bbutton\b|\bbtn\b|\bcta\b/.test(n)) return 'button';
  if (/\blink\b/.test(n)) return 'link';
  if (/\bcheckbox\b/.test(n)) return 'checkbox';
  if (/\bradio\b/.test(n)) return 'radio';
  if (/\bselect\b|\bdropdown\b|\bcombobox\b/.test(n)) return 'combobox';
  if (/\btextarea\b/.test(n)) return 'textbox:multiline';
  if (/\binput\b|\bfield\b|\btextbox\b/.test(n)) {
    const m = n.match(/\b(email|password|search|tel|url|number|date)\b/);
    return `textbox:${m ? m[1] : 'text'}`;
  }
  if (/\bnav\b|\bsidebar\b|\bmenu\b/.test(n)) return 'navigation';
  if (/\bicon\b|\bimage\b|\bavatar\b|\blogo\b/.test(n) || node.type === 'VECTOR') return 'image';
  if (/\btable\b/.test(n)) return 'table';
  if (/\blist\b/.test(n)) return 'list';
  if (/\bform\b/.test(n)) return 'form';
  return 'generic';
}

/** Figma placeholder convention: a TEXT child of an input layer. */
function inputPlaceholder(node) {
  const t = (node.children || []).find((c) => c.type === 'TEXT' && c.characters);
  return t ? t.characters.trim() : '';
}

function convert(root, frameBox) {
  const elements = [];
  const tokens = { color: {}, background: {}, fontFamily: {}, fontSize: {}, fontWeight: {}, radius: {}, borderColor: {}, shadow: {}, spacing: {} };
  const bump = (m, k) => { if (k && k !== 'rgba(0, 0, 0, 0)') m[k] = (m[k] || 0) + 1; };

  const walk = (node, depth) => {
    if (!node || node.visible === false) return;
    const bb = node.absoluteBoundingBox;
    const role = roleOf(node);
    const isText = node.type === 'TEXT';
    const text = isText ? (node.characters || '').replace(/\s+/g, ' ').trim() : '';
    const bg = solidFill(node.fills);
    const stroke = solidFill(node.strokes);
    const radius = node.cornerRadius ?? node.rectangleCornerRadii?.[0] ?? 0;
    const borderWidth = node.strokes?.length ? (node.strokeWeight ?? 1) : 0;
    const surface = !isText && !!bb && bb.width >= 8 && bb.height >= 8 && (!!bg || borderWidth > 0 || !!node.effects?.length);
    const isInputish = role.startsWith('textbox') || ['button', 'combobox', 'checkbox', 'radio'].includes(role);

    if (bb && (text || surface || isInputish || role === 'image')) {
      const style = {
        color: isText ? (solidFill(node.fills) || 'rgb(0, 0, 0)') : (solidFill(node.fills) || 'rgba(0, 0, 0, 0)'),
        background: isText ? 'rgba(0, 0, 0, 0)' : (bg || 'rgba(0, 0, 0, 0)'),
        fontFamily: node.style?.fontFamily || '',
        fontSize: node.style?.fontSize ? `${node.style.fontSize}px` : '16px',
        fontWeight: String(node.style?.fontWeight || 400),
        radius: `${round(radius)}px`,
        borderWidth: `${round(borderWidth)}px`,
        borderColor: stroke || 'rgb(0, 0, 0)',
        padding: node.paddingTop !== undefined
          ? `${round(node.paddingTop)}px ${round(node.paddingRight)}px ${round(node.paddingBottom)}px ${round(node.paddingLeft)}px`
          : '0px',
        shadow: node.effects?.some((e) => e.type === 'DROP_SHADOW' && e.visible !== false) ? 'shadow' : 'none',
        textTransform: node.style?.textCase === 'UPPER' ? 'uppercase' : 'none',
      };

      bump(tokens.fontFamily, style.fontFamily);
      if (text) { bump(tokens.color, style.color); bump(tokens.fontSize, style.fontSize); bump(tokens.fontWeight, style.fontWeight); }
      if (surface) {
        bump(tokens.background, style.background);
        bump(tokens.radius, style.radius);
        if (borderWidth > 0) bump(tokens.borderColor, style.borderColor);
        bump(tokens.spacing, style.padding);
      }

      elements.push({
        tag: node.type, role, text, depth,
        type: '', name: node.name || '',
        placeholder: isInputish ? inputPlaceholder(node) : '',
        alt: role === 'image' ? node.name || '' : '',
        required: /\brequired\b|\*/.test(node.name || ''),
        disabled: /\bdisabled\b/.test(node.name || ''),
        surface,
        box: {
          x: round(bb.x - frameBox.x), y: round(bb.y - frameBox.y),
          w: round(bb.width), h: round(bb.height),
        },
        style,
      });
    }
    for (const c of node.children || []) walk(c, depth + 1);
  };

  walk(root, 0);
  return { elements, tokens };
}

let n = 0;
for (const screen of screens) {
  const src = path.join(ROOT, 'design/sources/figma', screen.id);
  const nodesPath = path.join(src, 'nodes.json');
  if (!fs.existsSync(nodesPath)) {
    console.error(`design: ✗ ${screen.id} — missing ${rel(nodesPath)}\n` +
      `  Export it first: figma MCP, or GET /v1/files/:key/nodes?ids=<node-id>\n` +
      `  See agent/skills/design-fidelity/references/ingest.md §Figma`);
    process.exitCode = 1;
    continue;
  }
  const raw = JSON.parse(fs.readFileSync(nodesPath, 'utf8'));
  // Accept the REST envelope ({nodes:{"12:345":{document:…}}}) or a bare node.
  const doc = raw.nodes ? Object.values(raw.nodes)[0].document : (raw.document || raw);
  const bb = doc.absoluteBoundingBox;
  if (!bb) { console.error(`design: ✗ ${screen.id} — node has no absoluteBoundingBox (is it a frame?)`); process.exitCode = 1; continue; }

  const vp = screen.viewports[0];
  const state = screen.states[0];
  const dir = goldenDir(screen.id, state.name, vp, cfg.golden_root);
  const { elements, tokens } = convert(doc, bb);

  writeJson(path.join(dir, 'probe.json'), {
    url: screen.impl_path,
    title: doc.name || screen.id,
    viewport: { w: vp.w, h: vp.h },
    scrollHeight: round(bb.height),
    elements, tokens,
    meta: {
      screen: screen.id, state: state.name, viewport: vp.name,
      source: screen.source, design_url: `figma:${doc.id}`, impl_path: screen.impl_path,
      ingester: 'figma-import', extracted_at: new Date().toISOString(),
      caveat: 'roles inferred from layer names; styles from node fills, not a rendered DOM',
    },
  });

  const png = path.join(src, 'frame.png');
  if (fs.existsSync(png)) fs.copyFileSync(png, path.join(dir, 'page.png'));
  else console.warn(`design: ⚠ ${screen.id} — no frame.png; pixel diff will be skipped`);

  n++;
  console.log(`design: ✓ ${screen.id} — ${elements.length} nodes → ${rel(dir)}`);
}

if (n) console.log(`design: imported ${n} frame(s). Next: make design-contract\n` +
  `design: ⚠ Figma-derived goldens infer roles from layer names — review the contract carefully,\n` +
  `        and consider loosening tolerance.color/radius_px until the design system settles.`);

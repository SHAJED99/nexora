// The comparison engine. Given a probe of the DESIGN and a probe of the
// IMPLEMENTATION, decide what is missing, what drifted, and by how much.
//
// Design principle: match elements by what a human means by "the same thing"
// (its role and its words), NOT by CSS selector — the implementation is allowed
// to use different tags and class names, it is not allowed to lose the thing.

const lc = (s) => (s || '').toLowerCase().trim();

/** rgb/rgba/hex → [r,g,b,a]; null when unparseable. */
export function parseColor(c) {
  if (!c) return null;
  const s = String(c).trim();
  let m = s.match(/^rgba?\(\s*([\d.]+)[,\s]+([\d.]+)[,\s]+([\d.]+)(?:[,/\s]+([\d.%]+))?\s*\)$/i);
  if (m) {
    let a = m[4] === undefined ? 1 : (m[4].endsWith('%') ? parseFloat(m[4]) / 100 : parseFloat(m[4]));
    return [+m[1], +m[2], +m[3], a];
  }
  m = s.match(/^#([0-9a-f]{3,8})$/i);
  if (m) {
    let h = m[1];
    if (h.length === 3 || h.length === 4) h = h.split('').map((x) => x + x).join('');
    const n = (i) => parseInt(h.slice(i, i + 2), 16);
    return [n(0), n(2), n(4), h.length === 8 ? n(6) / 255 : 1];
  }
  if (s === 'transparent') return [0, 0, 0, 0];
  return null;
}

/** Max per-channel distance. Transparent-vs-transparent = 0 whatever the rgb. */
export function colorDistance(a, b) {
  const ca = parseColor(a), cb = parseColor(b);
  if (!ca || !cb) return lc(a) === lc(b) ? 0 : Infinity;
  if (ca[3] === 0 && cb[3] === 0) return 0;
  return Math.max(
    Math.abs(ca[0] - cb[0]), Math.abs(ca[1] - cb[1]), Math.abs(ca[2] - cb[2]),
    Math.abs(ca[3] - cb[3]) * 255
  );
}

const num = (v) => parseFloat(v) || 0;

/** A human-readable handle for an element, used in every report line. */
export function label(el) {
  const bits = [el.role];
  if (el.text) bits.push(`"${el.text.slice(0, 48)}"`);
  else if (el.placeholder) bits.push(`placeholder="${el.placeholder}"`);
  else if (el.alt) bits.push(`label="${el.alt}"`);
  else if (el.name) bits.push(`#${el.name}`);
  else bits.push(`<${el.tag.toLowerCase()}> @${el.box.x},${el.box.y} ${el.box.w}×${el.box.h}`);
  return bits.join(' ');
}

const keyText = (el) => `${el.role}|${lc(el.text)}`;
const keyAttr = (el) => `${el.role}|${lc(el.placeholder || el.alt || el.name)}`;

function indexBy(list, keyFn, filter) {
  const m = new Map();
  list.forEach((el, i) => {
    if (filter && !filter(el)) return;
    const k = keyFn(el);
    if (!m.has(k)) m.set(k, []);
    m.get(k).push(i);
  });
  return m;
}

/**
 * Three-pass match: words → attributes → geometry.
 * Returns { pairs: [{g, i}], missing: [goldenEl], extra: [implEl] }.
 */
export function matchElements(golden, impl) {
  const usedG = new Set(), usedI = new Set();
  const pairs = [];
  const take = (gi, ii) => { usedG.add(gi); usedI.add(ii); pairs.push({ g: golden[gi], i: impl[ii] }); };

  // Pass A — same role, same words.
  const iByText = indexBy(impl, keyText, (el) => el.text);
  golden.forEach((g, gi) => {
    if (!g.text || usedG.has(gi)) return;
    const cands = (iByText.get(keyText(g)) || []).filter((ii) => !usedI.has(ii));
    if (cands.length) take(gi, cands[0]);
  });

  // Pass B — same role, same placeholder/aria-label/name. Catches every input.
  const iByAttr = indexBy(impl, keyAttr, (el) => el.placeholder || el.alt || el.name);
  golden.forEach((g, gi) => {
    if (usedG.has(gi) || !(g.placeholder || g.alt || g.name)) return;
    const cands = (iByAttr.get(keyAttr(g)) || []).filter((ii) => !usedI.has(ii));
    if (cands.length) take(gi, cands[0]);
  });

  // Pass C — same thing, RE-ROLED. Identical box, identical words, new role.
  //
  // The promise at the top of this file is that a build may use different tags,
  // only that it may not LOSE anything. Every other pass keys on role, so a
  // faithful port that improves semantics — a row <div> becoming a <li>, a
  // clickable div becoming a <button> — used to report the design element as
  // *missing* and the better one as *extra*. Nothing was lost; the role got
  // better.
  //
  // ORDER MATTERS, and this is why this pass runs before the geometric one:
  // "identical box AND identical text, different role" is much stronger
  // evidence than "same role, nearest box within 240px". Run the fuzzy pass
  // first and it greedily eats a candidate this pass needed, which then
  // cascades — one mis-pair leaves a real element unmatched several rows away.
  // Strongest evidence first.
  //
  // Deliberately tight, because this is the pass that could hide a genuine
  // loss: every edge within 2px and the text identical. Looser than that and
  // "missing" stops meaning missing.
  const roleChanges = [];
  golden.forEach((g, gi) => {
    if (usedG.has(gi)) return;
    for (let ii = 0; ii < impl.length; ii++) {
      if (usedI.has(ii)) continue;
      const im = impl[ii];
      if (im.role === g.role) continue;                    // A/B/D handle same-role
      if (lc(im.text) !== lc(g.text)) continue;            // words must be identical
      const near = Math.abs(g.box.x - im.box.x) <= 2 && Math.abs(g.box.y - im.box.y) <= 2
                && Math.abs(g.box.w - im.box.w) <= 2 && Math.abs(g.box.h - im.box.h) <= 2;
      if (!near) continue;
      take(gi, ii);
      roleChanges.push({ from: g.role, to: im.role, element: label(g), box: g.box });
      break;
    }
  });

  // Pass D — same role, nearest box. Surfaces and icons have no words.
  golden.forEach((g, gi) => {
    if (usedG.has(gi)) return;
    let best = -1, bestCost = Infinity;
    impl.forEach((im, ii) => {
      if (usedI.has(ii) || im.role !== g.role) return;
      const dc = Math.hypot((g.box.x + g.box.w / 2) - (im.box.x + im.box.w / 2),
                            (g.box.y + g.box.h / 2) - (im.box.y + im.box.h / 2));
      const ds = Math.abs(g.box.w - im.box.w) + Math.abs(g.box.h - im.box.h);
      const cost = dc + ds * 0.5;
      if (cost < bestCost) { bestCost = cost; best = ii; }
    });
    if (best >= 0 && bestCost < 240) take(gi, best);
  });

  return {
    pairs,
    roleChanges,
    missing: golden.filter((_, gi) => !usedG.has(gi)),
    extra: impl.filter((_, ii) => !usedI.has(ii)),
  };
}

/**
 * Copy parity — every string the design shows must appear in the build, on the
 * same element, character for character. This is where "close enough" hides.
 *
 * Two checks, because each catches what the other misses:
 *  - per pair: the matched element's words changed ("Sign in" → "Login")
 *  - globally: a design string exists nowhere in the build at all
 */
export function copyDiff(pairs, golden, impl, ignoreText = []) {
  const skip = ignoreText.map((r) => new RegExp(r));
  const ignored = (t) => skip.some((r) => r.test(t));
  const out = [];
  const reported = new Set();

  for (const { g, i } of pairs) {
    if (!g.text || ignored(g.text) || g.text === i.text) continue;
    out.push({
      kind: lc(g.text) === lc(i.text) ? 'case/spacing' : 'changed',
      element: label(g), expected: g.text, actual: i.text || '(empty)',
    });
    reported.add(g.text);
  }

  const iSet = new Set(impl.map((e) => e.text).filter(Boolean));
  const iLower = new Map();
  for (const t of iSet) iLower.set(lc(t), t);
  for (const g of golden) {
    const t = g.text;
    if (!t || ignored(t) || iSet.has(t) || reported.has(t)) continue;
    reported.add(t);
    const near = iLower.get(lc(t));
    out.push(near
      ? { kind: 'case/spacing', element: label(g), expected: t, actual: near }
      : { kind: 'absent', element: label(g), expected: t, actual: null });
  }
  return out;
}

const STYLE_PROPS = [
  ['color', 'color'], ['background', 'color'], ['borderColor', 'color'],
  ['fontSize', 'px'], ['fontWeight', 'int'], ['radius', 'px'],
  ['borderWidth', 'px'], ['fontFamily', 'exact'], ['textTransform', 'exact'],
];

/** Per matched pair: which style properties drifted beyond tolerance. */
export function styleDeltas(pairs, tol) {
  const out = [];
  for (const { g, i } of pairs) {
    for (const [prop, kind] of STYLE_PROPS) {
      const a = g.style[prop], b = i.style[prop];
      if (a === undefined || b === undefined) continue;
      let bad = false, delta = '';
      if (kind === 'color') {
        // A transparent background on a non-surface is noise, not a finding.
        if (prop !== 'color' && !g.surface && !i.surface) continue;
        const d = colorDistance(a, b);
        bad = tol.color === 'exact' ? d > 0 : d > Number(tol.color);
        delta = d === Infinity ? 'unparseable' : `Δ${Math.round(d)}`;
      } else if (kind === 'px') {
        const key = prop === 'fontSize' ? 'font_size_px' : prop === 'radius' ? 'radius_px' : 'spacing_px';
        const d = Math.abs(num(a) - num(b));
        bad = d > (tol[key] ?? 1);
        delta = `Δ${d.toFixed(1)}px`;
      } else if (kind === 'int') {
        const d = Math.abs(num(a) - num(b));
        bad = d > (tol.font_weight ?? 0);
        delta = `Δ${d}`;
      } else {
        bad = lc(a) !== lc(b);
      }
      if (bad) out.push({ element: label(g), prop, expected: a, actual: b, delta });
    }
  }
  return out;
}

/** Per matched pair: position/size drift. Soft by default — data changes size. */
export function layoutDeltas(pairs, tolPx) {
  const out = [];
  for (const { g, i } of pairs) {
    const d = {
      x: Math.abs(g.box.x - i.box.x), y: Math.abs(g.box.y - i.box.y),
      w: Math.abs(g.box.w - i.box.w), h: Math.abs(g.box.h - i.box.h),
    };
    const worst = Math.max(d.x, d.y, d.w, d.h);
    if (worst > tolPx) {
      out.push({
        element: label(g),
        expected: `${g.box.w}×${g.box.h} @${g.box.x},${g.box.y}`,
        actual: `${i.box.w}×${i.box.h} @${i.box.x},${i.box.y}`,
        delta: `${worst}px`,
      });
    }
  }
  return out;
}

/** Design tokens the build never used, and off-palette values it invented. */
export function tokenDiff(gTokens, iTokens, tol) {
  const out = [];
  for (const group of ['color', 'background', 'radius', 'fontSize', 'fontWeight', 'borderColor']) {
    const gKeys = Object.keys(gTokens[group] || {});
    const iKeys = Object.keys(iTokens[group] || {});
    if (!gKeys.length) continue;
    const isColor = /color|background/i.test(group);
    for (const k of iKeys) {
      const hit = gKeys.some((gk) => isColor
        ? colorDistance(gk, k) <= (tol.color === 'exact' ? 0 : Number(tol.color))
        : Math.abs(num(gk) - num(k)) <= (group === 'fontSize' ? tol.font_size_px : group === 'radius' ? tol.radius_px : 0));
      // Every use counts. A single invented accent is exactly the drift that
      // slips past review, and `tolerance.color` already absorbs real noise.
      if (!hit) {
        out.push({ group, value: k, uses: iTokens[group][k], nearest: nearestOf(k, gKeys, isColor) });
      }
    }
  }
  return out;
}

function nearestOf(v, keys, isColor) {
  let best = null, bd = Infinity;
  for (const k of keys) {
    const d = isColor ? colorDistance(k, v) : Math.abs(num(k) - num(v));
    if (d < bd) { bd = d; best = k; }
  }
  return best;
}

export const topTokens = (m, n = 8) =>
  Object.entries(m || {}).sort((a, b) => b[1] - a[1]).slice(0, n);

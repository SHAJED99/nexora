// The probe: what we extract from a rendered page, identically for the design
// and for the implementation. Runs inside the browser via page.evaluate, so it
// must be a self-contained function with no imports and no closure references.

export function probeFn() {
  const SKIP = new Set(['SCRIPT', 'STYLE', 'META', 'LINK', 'HEAD', 'NOSCRIPT', 'TITLE', 'BR']);
  const INTERACTIVE = new Set(['A', 'BUTTON', 'INPUT', 'SELECT', 'TEXTAREA', 'LABEL', 'SUMMARY', 'OPTION']);
  const MEDIA = new Set(['IMG', 'SVG', 'CANVAS', 'VIDEO', 'PICTURE']);

  const norm = (s) => (s || '').replace(/\s+/g, ' ').trim();
  const px = (v) => Math.round(parseFloat(v) || 0);

  // Implicit role — enough to identify "the same thing" across two codebases
  // that use different tags/classes for it.
  const roleOf = (el) => {
    const explicit = el.getAttribute && el.getAttribute('role');
    if (explicit) return explicit.toLowerCase();
    const t = el.tagName;
    if (t === 'A') return el.hasAttribute('href') ? 'link' : 'generic';
    if (t === 'BUTTON') return 'button';
    if (t === 'INPUT') {
      const it = (el.getAttribute('type') || 'text').toLowerCase();
      if (it === 'checkbox') return 'checkbox';
      if (it === 'radio') return 'radio';
      if (it === 'submit' || it === 'button') return 'button';
      return 'textbox:' + it;
    }
    if (t === 'SELECT') return 'combobox';
    if (t === 'TEXTAREA') return 'textbox:multiline';
    if (t === 'LABEL') return 'label';
    if (/^H[1-6]$/.test(t)) return 'heading:' + t[1];
    if (t === 'IMG' || t === 'SVG') return 'image';
    if (t === 'TABLE') return 'table';
    if (t === 'UL' || t === 'OL') return 'list';
    if (t === 'LI') return 'listitem';
    if (t === 'NAV') return 'navigation';
    if (t === 'FORM') return 'form';
    return 'generic';
  };

  // Only the text this element owns, not its descendants' — so a wrapper div
  // doesn't shadow the button inside it.
  const ownText = (el) => {
    let s = '';
    for (const n of el.childNodes) if (n.nodeType === 3) s += n.nodeValue;
    return norm(s);
  };

  const visible = (el, cs, box) => {
    if (cs.display === 'none' || cs.visibility === 'hidden') return false;
    if (parseFloat(cs.opacity) === 0) return false;
    return box.width > 0 && box.height > 0;
  };

  // A surface = something that draws a box (card, panel, chip, divider).
  const isSurface = (cs, box) => {
    if (box.width < 8 || box.height < 8) return false;
    const bg = cs.backgroundColor;
    const hasBg = bg && bg !== 'rgba(0, 0, 0, 0)' && bg !== 'transparent';
    const hasBorder = px(cs.borderTopWidth) + px(cs.borderLeftWidth) +
      px(cs.borderRightWidth) + px(cs.borderBottomWidth) > 0;
    const hasShadow = cs.boxShadow && cs.boxShadow !== 'none';
    return hasBg || hasBorder || hasShadow;
  };

  const tokens = {
    color: {}, background: {}, fontFamily: {}, fontSize: {},
    fontWeight: {}, radius: {}, borderColor: {}, shadow: {}, spacing: {},
  };
  const bump = (m, k) => { if (k && k !== 'none' && k !== '0px' && k !== 'rgba(0, 0, 0, 0)') m[k] = (m[k] || 0) + 1; };

  const elements = [];
  const walk = (el, depth) => {
    if (!el || !el.tagName || SKIP.has(el.tagName)) return;
    const cs = getComputedStyle(el);
    const r = el.getBoundingClientRect();
    const box = { x: Math.round(r.x), y: Math.round(r.y), w: Math.round(r.width), h: Math.round(r.height) };
    if (!visible(el, cs, r)) return;

    const tag = el.tagName;
    const role = roleOf(el);
    const text = ownText(el);
    const surface = isSurface(cs, r);
    const keep = INTERACTIVE.has(tag) || MEDIA.has(tag) || text.length > 0 || surface;

    // Token census over every visible node — this is the design's real palette,
    // not what a style guide claims.
    bump(tokens.fontFamily, (cs.fontFamily || '').split(',')[0].trim().replace(/["']/g, ''));
    if (text) {
      bump(tokens.color, cs.color);
      bump(tokens.fontSize, cs.fontSize);
      bump(tokens.fontWeight, cs.fontWeight);
    }
    if (surface) {
      bump(tokens.background, cs.backgroundColor);
      bump(tokens.radius, cs.borderTopLeftRadius);
      bump(tokens.borderColor, px(cs.borderTopWidth) > 0 ? cs.borderTopColor : null);
      bump(tokens.shadow, cs.boxShadow);
      bump(tokens.spacing, cs.padding);
    }

    if (keep) {
      elements.push({
        tag, role, text, depth,
        type: el.getAttribute && el.getAttribute('type') || '',
        name: el.getAttribute && (el.getAttribute('name') || el.getAttribute('id')) || '',
        placeholder: el.getAttribute && el.getAttribute('placeholder') || '',
        alt: el.getAttribute && (el.getAttribute('alt') || el.getAttribute('aria-label')) || '',
        required: !!(el.hasAttribute && el.hasAttribute('required')),
        disabled: !!(el.disabled),
        surface,
        box,
        style: {
          color: cs.color,
          background: cs.backgroundColor,
          fontFamily: (cs.fontFamily || '').split(',')[0].trim().replace(/["']/g, ''),
          fontSize: cs.fontSize,
          fontWeight: cs.fontWeight,
          radius: cs.borderTopLeftRadius,
          borderWidth: cs.borderTopWidth,
          borderColor: cs.borderTopColor,
          padding: cs.padding,
          shadow: cs.boxShadow,
          textTransform: cs.textTransform,
        },
      });
    }
    for (const c of el.children) walk(c, depth + 1);
  };

  walk(document.body, 0);

  return {
    url: location.pathname,
    title: document.title,
    viewport: { w: window.innerWidth, h: window.innerHeight },
    scrollHeight: document.documentElement.scrollHeight,
    elements,
    tokens,
  };
}

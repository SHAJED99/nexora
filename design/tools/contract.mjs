#!/usr/bin/env node
// contract.mjs — golden probe → design/screens/<id>.md, the human/agent-readable
// design contract.
//
//   node design/tools/contract.mjs [--screen login]
//
// Why this exists: nobody — human or agent — can hold a 400KB design bundle in
// their head, so they skim it and drift. The contract is the ~150-line
// checklist version of the same truth. Agents read THIS. `probe.json` next to
// the golden stays the machine truth that verify.mjs uses.
import fs from 'node:fs';
import path from 'node:path';
import { loadSources, parseArgs, goldenDir, readJson, rel, ROOT } from './lib/config.mjs';
import { topTokens, label } from './lib/compare.mjs';

const args = parseArgs(process.argv.slice(2));
const cfg = loadSources(args.sources || 'design/sources.yaml');
const screens = cfg.screens.filter((s) => !args.screen || s.id === args.screen);
const MAX_ROWS = 140;

const esc = (s) => String(s).replace(/\|/g, '\\|');

function tokenTable(tokens) {
  const rows = [];
  const groups = [
    ['text colour', 'color'], ['surface / fill', 'background'], ['border', 'borderColor'],
    ['font size', 'fontSize'], ['font weight', 'fontWeight'], ['radius', 'radius'],
    ['font family', 'fontFamily'], ['shadow', 'shadow'],
  ];
  for (const [title, key] of groups) {
    for (const [value, uses] of topTokens(tokens[key], 6)) {
      rows.push(`| ${title} | \`${esc(value)}\` | ${uses} |`);
    }
  }
  return rows;
}

function elementRows(elements) {
  const interesting = elements.filter((e) => e.text || e.placeholder || e.alt ||
    ['button', 'link', 'combobox', 'checkbox', 'radio', 'image', 'form'].includes(e.role) ||
    e.role.startsWith('textbox') || e.role.startsWith('heading'));
  const rows = interesting.slice(0, MAX_ROWS).map((e, i) => {
    const style = [
      e.style.fontSize !== '16px' ? e.style.fontSize : null,
      e.style.fontWeight !== '400' ? `w${e.style.fontWeight}` : null,
      e.text ? e.style.color : null,
      e.surface && e.style.background !== 'rgba(0, 0, 0, 0)' ? `bg ${e.style.background}` : null,
      parseFloat(e.style.radius) ? `r${e.style.radius}` : null,
    ].filter(Boolean).join(' · ');
    const copy = e.text || (e.placeholder && `placeholder: ${e.placeholder}`) || e.alt || '—';
    const flags = [e.required ? 'required' : null, e.disabled ? 'disabled' : null].filter(Boolean).join(',');
    return `| ${i + 1} | \`${e.role}\`${flags ? ` (${flags})` : ''} | ${esc(copy)} | ${e.box.w}×${e.box.h} | ${esc(style) || '—'} |`;
  });
  return { rows, total: interesting.length, surfaces: elements.filter((e) => e.surface).length };
}

let written = 0;
for (const screen of screens) {
  const state = screen.states[0], vp = screen.viewports[0];
  const dir = goldenDir(screen.id, state.name, vp, cfg.golden_root);
  const probePath = path.join(dir, 'probe.json');
  if (!fs.existsSync(probePath)) {
    console.error(`design: ✗ ${screen.id} — no golden yet. Run: make design-extract SCREEN=${screen.id}`);
    process.exitCode = 1;
    continue;
  }
  const probe = readJson(probePath);
  const { rows, total, surfaces } = elementRows(probe.elements);
  const copy = [...new Set(probe.elements.map((e) => e.text).filter(Boolean))];

  const md = `---
id: ${screen.id}
impl_path: ${screen.impl_path}
source: ${screen.source}
states: [${screen.states.map((s) => s.name).join(', ')}]
viewports: [${screen.viewports.map((v) => v.name).join(', ')}]
golden: ${rel(dir)}/
elements: ${probe.elements.length}
generated_by: design/tools/contract.mjs
generated_at: ${new Date().toISOString()}
---
# ${screen.id} · design contract

> **Generated — do not hand-edit the tables.** Regenerate with
> \`make design-contract SCREEN=${screen.id}\` after the design changes.
> Hand-written sections at the bottom (Journey gaps, Notes) are preserved by you,
> not by the generator — keep them below the marker.
>
> **Rule 2 (design is law).** Every element below exists in the build, with that
> copy, character for character. The gate is \`make design-verify SCREEN=${screen.id}\`
> — it fails on a missing element, changed copy, or an off-token style.
> Deliberate divergence goes in the task's §Deviations with its spec reason, and
> in \`design/gaps.md\`. Silence is not an option.

- **Route:** \`${screen.impl_path}\`
- **Golden:** \`${rel(dir)}/page.png\` (screenshot) + \`probe.json\` (machine truth)
- **Captured:** ${probe.elements.length} visible elements · ${surfaces} surfaces · ${copy.length} distinct strings
- **Page:** ${probe.viewport.w}×${probe.viewport.h} viewport, ${probe.scrollHeight}px tall

## Tokens this screen actually uses
These are measured from the rendered design, not aspirational. Off-palette
values in the build are reported by the gate.

| role | value | uses |
|---|---|---|
${tokenTable(probe.tokens).join('\n')}

## Elements — the build checklist
${total > MAX_ROWS ? `> Showing ${MAX_ROWS} of ${total}. Full truth: \`${rel(dir)}/probe.json\`.\n` : ''}
| # | role | copy / label | size | key styles |
|---|---|---|---|---|
${rows.join('\n')}

## Copy — verbatim
Every string, exactly as the design writes it. The gate compares character for
character; a case or spacing change is a finding, not a nit.

${copy.map((c) => `- \`${c.replace(/`/g, '\\`')}\``).join('\n')}

<!-- ── generated above · hand-written below ────────────────────────────── -->

## Journey gaps
> States, flows or screens the SPEC requires that this design does not show.
> Fill from the BRD / SRS / feature list, keep consistent with the primitives
> above, log each one in \`design/gaps.md\`, and get 🧍 human approval before
> building. Do not invent silently.

- (none identified yet)

## Notes for the implementing agent
- (exact copy quirks, dynamic data, anything the probe cannot see)
`;

  const out = path.join(ROOT, 'design/screens', `${screen.id}.md`);
  fs.mkdirSync(path.dirname(out), { recursive: true });

  // Preserve hand-written sections across regeneration.
  const MARK = '<!-- ── generated above · hand-written below';
  if (fs.existsSync(out)) {
    const prev = fs.readFileSync(out, 'utf8');
    const idx = prev.indexOf(MARK);
    if (idx > -1) {
      fs.writeFileSync(out, md.slice(0, md.indexOf(MARK)) + prev.slice(idx));
      console.log(`design: ✓ ${screen.id} → ${rel(out)} (hand-written sections kept)`);
      written++;
      continue;
    }
  }
  fs.writeFileSync(out, md);
  written++;
  console.log(`design: ✓ ${screen.id} → ${rel(out)}`);
}

console.log(`design: ${written} contract(s). 🧍 human gate: review them (harness.yaml design_contract_approval), then build.`);

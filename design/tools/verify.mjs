#!/usr/bin/env node
// verify.mjs — THE GATE. Built UI vs golden design. Exits non-zero on drift.
//
//   make design-verify                       # every screen, impl from sources.yaml
//   make design-verify SCREEN=login
//   make design-verify SCREEN=login IMPL=http://localhost:3000
//
// This is the whole answer to "the implementation doesn't match the design":
// stop asking an agent to eyeball two screenshots, and measure it instead.
import { pathToFileURL } from 'node:url';
import fs from 'node:fs';
import path from 'node:path';
import { loadSources, loadThresholds, parseArgs, goldenDir, readJson, writeJson, rel, ROOT } from './lib/config.mjs';
import { launch, capture } from './lib/browser.mjs';
import { openSource } from './lib/source.mjs';
import { probeFn } from './lib/probe.mjs';
import { pixelDiff } from './lib/pixel.mjs';
import { matchElements, copyDiff, styleDeltas, layoutDeltas, tokenDiff, label } from './lib/compare.mjs';

export async function verify({ sourcesFile = 'design/sources.yaml', screenFilter = null, implBase = null, reportDir = 'design/reports', quiet = false } = {}) {
  const cfg = loadSources(sourcesFile);
  const th = loadThresholds();
  const screens = cfg.screens.filter((s) => !screenFilter || s.id === screenFilter);
  if (!screens.length) throw new Error(`no screen matched ${screenFilter || '(none configured)'}`);

  const browser = await launch();
  let impl = null;
  const results = [];
  try {
    impl = implBase
      ? { url: implBase.replace(/\/$/, ''), close: async () => {} }
      : await openSource(cfg.impl, 'impl');

    for (const screen of screens) {
      for (const state of screen.states) {
        for (const vp of screen.viewports) {
          const dir = goldenDir(screen.id, state.name, vp, cfg.golden_root);
          const gPath = path.join(dir, 'probe.json');
          if (!fs.existsSync(gPath)) {
            throw new Error(`${screen.id}/${state.name}@${vp.name}: no golden — run make design-extract SCREEN=${screen.id}`);
          }
          const golden = readJson(gPath);
          const outDir = path.join(ROOT, reportDir, screen.id, `${state.name}@${vp.name}`);
          const url = impl.url + (state.impl_path || screen.impl_path || '/');

          const built = await capture(browser, url, {
            viewport: vp, probeFn, mask: screen.mask,
            setup: state.impl_setup || state.setup || [],
            screenshotPath: path.join(outDir, 'built.png'),
          });

          const { pairs, missing, extra, roleChanges } = matchElements(golden.elements, built.elements);
          const findings = {
            missing: missing.map((e) => ({ element: label(e), role: e.role, text: e.text, box: e.box })),
            roleChanges,
            extra: extra.map((e) => ({ element: label(e), role: e.role })),
            copy: copyDiff(pairs, golden.elements, built.elements, screen.ignore_text),
            style: styleDeltas(pairs, th.tolerance),
            layout: layoutDeltas(pairs, th.tolerance.layout_box_px),
            tokens: tokenDiff(golden.tokens, built.tokens, th.tolerance),
            pixel: pixelDiff(path.join(dir, 'page.png'), path.join(outDir, 'built.png'),
              path.join(outDir, 'diff.png'), { threshold: th.pixel?.antialias_threshold ?? 0.12 }),
          };

          const hard = [
            findings.missing.length > th.hard.missing_elements_max && `${findings.missing.length} missing element(s) (max ${th.hard.missing_elements_max})`,
            findings.copy.length > th.hard.copy_mismatch_max && `${findings.copy.length} copy mismatch(es) (max ${th.hard.copy_mismatch_max})`,
            findings.style.length > th.hard.style_deltas_max && `${findings.style.length} style delta(s) (max ${th.hard.style_deltas_max})`,
            th.hard.off_palette_tokens_max !== undefined && findings.tokens.length > th.hard.off_palette_tokens_max && `${findings.tokens.length} off-palette token(s) (max ${th.hard.off_palette_tokens_max})`,
          ].filter(Boolean);
          const soft = [
            findings.layout.length > th.soft.layout_deltas_max && `${findings.layout.length} layout delta(s) (max ${th.soft.layout_deltas_max})`,
            findings.pixel && findings.pixel.mismatchPct > th.soft.pixel_mismatch_max_pct && `pixel ${findings.pixel.mismatchPct}% (max ${th.soft.pixel_mismatch_max_pct}%)`,
            findings.roleChanges.length && `${findings.roleChanges.length} element(s) re-roled — same box and copy, different role`,
            th.extra_elements === 'fail' && findings.extra.length && `${findings.extra.length} extra element(s)`,
          ].filter(Boolean);

          const matchPct = golden.elements.length
            ? +((pairs.length / golden.elements.length) * 100).toFixed(1) : 100;
          const r = {
            screen: screen.id, state: state.name, viewport: vp.name, url,
            pass: hard.length === 0 && (th.extra_elements !== 'fail' || !findings.extra.length),
            hard, soft, matchPct,
            counts: { golden: golden.elements.length, built: built.elements.length, matched: pairs.length },
            findings, outDir,
          };
          writeReport(r);
          results.push(r);
          if (!quiet) printResult(r);
        }
      }
    }
  } finally {
    if (impl) await impl.close();
    await browser.close();
  }
  return results;
}

function fmt(rows, cols) {
  if (!rows.length) return '_none_\n';
  const head = `| ${cols.join(' | ')} |\n|${cols.map(() => '---').join('|')}|`;
  const body = rows.map((r) => `| ${cols.map((c) => String(r[c] ?? '—').replace(/\|/g, '\\|').slice(0, 90)).join(' | ')} |`).join('\n');
  return `${head}\n${body}\n`;
}

function writeReport(r) {
  const f = r.findings;
  const md = `# design-verify · ${r.screen} · ${r.state}@${r.viewport}

**${r.pass ? '✅ PASS' : '❌ FAIL'}** — element match ${r.matchPct}% (${r.counts.matched}/${r.counts.golden} golden elements found in the build)
${r.hard.length ? `\n**Hard failures (block the merge):**\n${r.hard.map((h) => `- ❌ ${h}`).join('\n')}\n` : ''}
${r.soft.length ? `\n**Soft warnings (explain or fix):**\n${r.soft.map((h) => `- ⚠️ ${h}`).join('\n')}\n` : ''}
- Built: ${r.url}
- Images: \`built.png\` · \`diff.png\` (red = drift) · golden \`page.png\`
${f.pixel ? `- Pixel: ${f.pixel.mismatchPct}% over ${f.pixel.comparedArea}; page height Δ${f.pixel.sizeDelta.h}px\n` : ''}
## ❌ Missing — in the design, not in the build
${fmt(f.missing, ['element'])}

## ⚠️ Re-roled — same box, same copy, different role
Not a loss: the build kept the element and changed what it *is*. Usually a
semantic improvement (a row div becoming a list item, a clickable div becoming a
button). Confirm it was intended, then move on.
${f.roleChanges.length ? fmt(f.roleChanges.map((r) => ({ from: r.from, to: r.to, element: r.element })), ['from', 'to', 'element']) : '_none_'}

## ❌ Copy mismatches
${fmt(f.copy, ['kind', 'element', 'expected', 'actual'])}
## ❌ Style deltas
${fmt(f.style, ['element', 'prop', 'expected', 'actual', 'delta'])}
## ⚠️ Off-palette tokens the build invented
${fmt(f.tokens, ['group', 'value', 'uses', 'nearest'])}
## ⚠️ Layout deltas
${fmt(f.layout, ['element', 'expected', 'actual', 'delta'])}
## ℹ️ Extra — in the build, not in the design
Legitimate when the spec requires it (log in the task's §Deviations + design/gaps.md).
${fmt(f.extra, ['element'])}
`;
  fs.mkdirSync(r.outDir, { recursive: true });
  fs.writeFileSync(path.join(r.outDir, 'report.md'), md);
  writeJson(path.join(r.outDir, 'report.json'), r);
}

function printResult(r) {
  const tag = r.pass ? '\x1b[32m✅ PASS\x1b[0m' : '\x1b[31m❌ FAIL\x1b[0m';
  console.log(`\ndesign: ${tag} ${r.screen}/${r.state}@${r.viewport} — match ${r.matchPct}% (${r.counts.matched}/${r.counts.golden})`);
  for (const h of r.hard) console.log(`  ❌ ${h}`);
  for (const s of r.soft) console.log(`  ⚠️  ${s}`);
  const f = r.findings;
  for (const m of f.missing.slice(0, 5)) console.log(`     missing: ${m.element}`);
  for (const r of (f.roleChanges || []).slice(0, 5)) console.log(`     re-roled: ${r.from} -> ${r.to}  ${r.element}`);
  for (const c of f.copy.slice(0, 5)) console.log(`     copy [${c.kind}]: expected "${c.expected}"${c.actual ? ` · got "${c.actual}"` : ''}`);
  for (const s of f.style.slice(0, 5)) console.log(`     style: ${s.element} — ${s.prop}: expected ${s.expected}, got ${s.actual} (${s.delta})`);
  const more = f.missing.length + f.copy.length + f.style.length - 15;
  if (more > 0) console.log(`     …+${more} more`);
  console.log(`     report: ${rel(path.join(r.outDir, 'report.md'))}`);
}

// Entry-point guard. `file://${process.argv[1]}` is WRONG on Windows:
// import.meta.url is file:///C:/... while argv[1] is C:\..., so the naive
// concatenation never matches, this block never runs, and the gate exits 0
// having verified NOTHING. A gate that always passes is worse than no gate.
if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  const args = parseArgs(process.argv.slice(2));
  try {
    const results = await verify({
      sourcesFile: args.sources || 'design/sources.yaml',
      screenFilter: args.screen || null,
      implBase: args.impl && args.impl !== true ? args.impl : null,
    });
    const failed = results.filter((r) => !r.pass);
    console.log(`\ndesign: ${results.length - failed.length}/${results.length} screen-state(s) pass the gate`);
    if (failed.length) {
      console.log(`design: rule 2 — fix the ❌ list or log each as a §Deviation with its spec reason, then re-run.`);
      process.exit(1);
    }
  } catch (e) {
    console.error(`design: ✗ ${e.message}`);
    process.exit(2);
  }
}

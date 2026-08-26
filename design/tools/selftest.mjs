#!/usr/bin/env node
// selftest.mjs — prove the gate works, on every clone, in CI, in ~10 seconds.
//
//   make design-selftest
//
// A gate nobody has seen fail is a gate nobody should trust. This extracts a
// golden from the synthetic reference page in selftest-data/, then runs the
// gate twice:
//   • against a FAITHFUL port (different markup, same design) → must PASS
//   • against a DRIFTED port (five planted defects)           → must FAIL,
//     and must name all five
//
// Touches nothing under design/golden or design/screens — those hold the
// project's committed design law. Everything here lands in design/.cache.
import fs from 'node:fs';
import path from 'node:path';
import { execFileSync } from 'node:child_process';
import { ROOT } from './lib/config.mjs';
import { serveStatic } from './lib/browser.mjs';
import { verify } from './verify.mjs';

const DATA = 'design/tools/selftest-data';
const CACHE = path.join(ROOT, 'design/.cache/selftest');
const cfgPath = path.join(CACHE, 'sources.yaml');

// One check per detector. If a future edit silently breaks one, this is where
// you find out — instead of via a bad merge.
const EXPECT = [
  { name: 'missing "Remember me" checkbox', test: (f) => f.missing.some((m) => /checkbox/.test(m.element)) },
  { name: 'button copy "Sign in" → "Login"', test: (f) => f.copy.some((c) => c.expected === 'Sign in' && c.actual === 'Login') },
  { name: 'subtitle copy rewritten', test: (f) => f.copy.some((c) => /Welcome back\. Use your work account\./.test(c.expected)) },
  { name: 'accent #059669 → #10b981', test: (f) => f.style.some((s) => /background|color/i.test(s.prop) && /16, 185, 129/.test(s.actual)) },
  { name: 'control radius 7px → 12px', test: (f) => f.style.some((s) => s.prop === 'radius' && s.expected === '7px' && s.actual === '12px') },
  { name: 'off-palette accent flagged as a token', test: (f) => f.tokens.some((t) => /16, 185, 129/.test(t.value)) },
];

// Self-contained config: its own golden root, its own screen list. The design
// and both ports are served from one folder, so the only thing that varies
// between the two runs is which page the "implementation" resolves to.
const yaml = (implPage) => `version: 1
golden_root: design/.cache/selftest/golden
sources:
  reference: { kind: static, root: ${DATA} }
screens:
  - id: selftest-page
    source: reference
    design_path: /reference.html
    impl_path: ${implPage}
    viewports: [1440x900]
    states: [{ name: default }]
`;

async function run(implPage) {
  fs.mkdirSync(CACHE, { recursive: true });
  fs.writeFileSync(cfgPath, yaml(implPage));
  const srv = await serveStatic(path.join(ROOT, DATA));
  try {
    return (await verify({
      sourcesFile: path.relative(ROOT, cfgPath),
      implBase: srv.url,
      reportDir: 'design/.cache/selftest/reports',
      quiet: true,
    }))[0];
  } finally { await srv.close(); }
}

let failures = 0;
const say = (ok, msg) => { console.log(`  ${ok ? '\x1b[32m✓\x1b[0m' : '\x1b[31m✗\x1b[0m'} ${msg}`); if (!ok) failures++; };

console.log('design-selftest: extracting a golden from the synthetic reference page…');
fs.mkdirSync(CACHE, { recursive: true });
fs.writeFileSync(cfgPath, yaml('/faithful.html'));
execFileSync('node', ['design/tools/extract.mjs', '--sources', path.relative(ROOT, cfgPath)],
  { cwd: ROOT, stdio: 'inherit' });

console.log('\ndesign-selftest: 1/2 — faithful port (different markup, same design)');
const good = await run('/faithful.html');
say(good.pass, `PASS expected → ${good.pass ? 'PASS' : 'FAIL'} (element match ${good.matchPct}%)`);
if (!good.pass) {
  for (const h of good.hard) console.log(`      unexpected: ${h}`);
  for (const m of good.findings.missing) console.log(`      missing: ${m.element}`);
  for (const c of good.findings.copy) console.log(`      copy: ${c.expected} → ${c.actual}`);
  for (const s of good.findings.style.slice(0, 8)) console.log(`      style: ${s.element} ${s.prop} ${s.expected}→${s.actual}`);
}

console.log('\ndesign-selftest: 2/2 — drifted port (five planted defects)');
const bad = await run('/drifted.html');
say(!bad.pass, `FAIL expected → ${bad.pass ? 'PASS' : 'FAIL'} (element match ${bad.matchPct}%)`);
for (const e of EXPECT) say(e.test(bad.findings), `detected: ${e.name}`);

if (bad.findings.pixel) {
  console.log(`\n  ℹ️  that drifted build is only \x1b[1m${bad.findings.pixel.mismatchPct}%\x1b[0m different by pixel comparison —`);
  console.log('      which is why nobody can catch this by looking, and why the gate measures instead.');
}

console.log(
  failures
    ? `\ndesign-selftest: \x1b[31m${failures} check(s) failed\x1b[0m — the gate is not trustworthy, fix it before relying on it.`
    : `\ndesign-selftest: \x1b[32mall checks passed\x1b[0m — the gate catches drift a human review waves through.`
);
process.exit(failures ? 1 : 0);

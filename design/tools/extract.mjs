#!/usr/bin/env node
// extract.mjs — design source → golden probes + screenshots.
//
//   node design/tools/extract.mjs [--screen login] [--sources design/sources.yaml]
//
// The golden is the LAW: design/golden/<screen>/<state>@<vp>/{probe.json,page.png}.
// Commit it. Re-run only when the design itself changes — then the diff on the
// golden IS the design changelog.
import path from 'node:path';
import { loadSources, parseArgs, goldenDir, writeJson, rel, ROOT } from './lib/config.mjs';
import { launch, capture } from './lib/browser.mjs';
import { openSource } from './lib/source.mjs';
import { probeFn } from './lib/probe.mjs';

const args = parseArgs(process.argv.slice(2));
const cfg = loadSources(args.sources || 'design/sources.yaml');
const screens = cfg.screens.filter((s) => !args.screen || s.id === args.screen);

if (!screens.length) {
  console.error(`design: no screen matched ${args.screen ? `--screen ${args.screen}` : '(sources.yaml has no screens)'}`);
  process.exit(1);
}

const browser = await launch();
const opened = new Map();
let count = 0;

try {
  for (const screen of screens) {
    const srcName = screen.source;
    if (!opened.has(srcName)) opened.set(srcName, await openSource(cfg.sources?.[srcName], srcName));
    const base = opened.get(srcName).url;

    for (const state of screen.states) {
      for (const vp of screen.viewports) {
        const dir = goldenDir(screen.id, state.name, vp, cfg.golden_root);
        const url = base + (state.design_path || screen.design_path || '/');
        const probe = await capture(browser, url, {
          viewport: vp,
          probeFn,
          mask: screen.mask,
          setup: state.setup || [],
          screenshotPath: path.join(dir, 'page.png'),
        });
        probe.meta = {
          screen: screen.id, state: state.name, viewport: vp.name,
          source: srcName, design_url: url, impl_path: screen.impl_path,
          extracted_at: new Date().toISOString(),
        };
        writeJson(path.join(dir, 'probe.json'), probe);
        count++;
        console.log(`design: ✓ ${screen.id}/${state.name}@${vp.name} — ${probe.elements.length} elements → ${rel(dir)}`);
      }
    }
  }
} finally {
  for (const o of opened.values()) await o.close();
  await browser.close();
}

console.log(`design: extracted ${count} golden capture(s). Next: make design-contract`);

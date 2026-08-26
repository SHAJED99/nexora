// Resolve a design source (or the implementation) to a live base URL.
// kind: static  → serve a folder here
// kind: command → boot a dev server, wait for it, kill it after
// kind: url     → already running; we just point at it
import { spawn } from 'node:child_process';
import { serveStatic, waitForUrl } from './browser.mjs';
import { ROOT } from './config.mjs';

export async function openSource(def, name = 'source') {
  if (!def) throw new Error(`design source "${name}" is not defined in design/sources.yaml`);

  if (def.kind === 'static') {
    const s = await serveStatic(`${ROOT}/${def.root}`);
    return { url: s.url, close: s.close };
  }

  if (def.kind === 'url' || def.base_url) {
    const url = def.url || def.base_url;
    await waitForUrl(url, (def.timeout_s || 30) * 1000);
    return { url, close: async () => {} };
  }

  if (def.kind === 'command') {
    const child = spawn(def.cmd, { cwd: ROOT, shell: true, stdio: 'ignore', detached: true });
    try {
      await waitForUrl(def.ready_url || def.url, (def.timeout_s || 120) * 1000);
    } catch (e) {
      try { process.kill(-child.pid, 'SIGKILL'); } catch {}
      throw e;
    }
    return {
      url: def.ready_url || def.url,
      close: async () => { try { process.kill(-child.pid, 'SIGKILL'); } catch {} },
    };
  }

  if (def.kind === 'figma') {
    throw new Error(
      `source "${name}" is kind: figma — Figma frames are not browsable.\n` +
      `Import them instead:  node design/tools/figma-import.mjs --screen <id>\n` +
      `See agent/skills/design-fidelity/references/ingest.md §Figma.`
    );
  }

  throw new Error(`source "${name}": unknown kind "${def.kind}" (static | command | url | figma)`);
}

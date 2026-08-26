// Browser + static server helpers. Deliberately dependency-light: the gate must
// run in CI without a browser download (falls back to system Chrome).
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { chromium } from 'playwright';

const MIME = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript', '.mjs': 'text/javascript',
  '.css': 'text/css', '.json': 'application/json', '.png': 'image/png', '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg', '.svg': 'image/svg+xml', '.woff': 'font/woff', '.woff2': 'font/woff2',
  '.ico': 'image/x-icon', '.gif': 'image/gif', '.webp': 'image/webp',
};

/** Serve a directory on a free port. Returns { url, close }. */
export async function serveStatic(root) {
  const abs = path.resolve(root);
  const server = http.createServer((req, res) => {
    let rel = decodeURIComponent(new URL(req.url, 'http://x').pathname);
    if (rel.endsWith('/')) rel += 'index.html';
    let file = path.join(abs, rel);
    if (!file.startsWith(abs)) { res.writeHead(403).end('forbidden'); return; }
    if (!fs.existsSync(file) && fs.existsSync(file + '.html')) file += '.html';
    if (!fs.existsSync(file) || fs.statSync(file).isDirectory()) { res.writeHead(404).end('not found'); return; }
    res.writeHead(200, { 'content-type': MIME[path.extname(file)] || 'application/octet-stream' });
    fs.createReadStream(file).pipe(res);
  });
  await new Promise((r) => server.listen(0, '127.0.0.1', r));
  const { port } = server.address();
  return {
    url: `http://127.0.0.1:${port}`,
    close: () => new Promise((r) => server.close(r)),
  };
}

/** Launch Chromium — bundled if present, else the system Chrome. */
export async function launch() {
  for (const opts of [{ channel: 'chrome' }, {}]) {
    try { return await chromium.launch(opts); } catch { /* try next */ }
  }
  throw new Error(
    'no browser: run `npx playwright install chromium` or install Google Chrome'
  );
}

/**
 * Load a page and run the probe. Freezes the page first so the capture is
 * deterministic: animations off, caret hidden, fonts settled.
 */
export async function capture(browser, url, { viewport, probeFn, mask = [], setup = [], screenshotPath = null }) {
  const ctx = await browser.newContext({
    viewport: { width: viewport.w, height: viewport.h },
    deviceScaleFactor: 1,
    reducedMotion: 'reduce',
    colorScheme: 'light',
  });
  const page = await ctx.newPage();
  await page.goto(url, { waitUntil: 'networkidle', timeout: 45000 }).catch(async (e) => {
    await ctx.close();
    throw new Error(`could not load ${url} — ${String(e).split('\n')[0]}`);
  });
  await page.addStyleTag({
    content: `*,*::before,*::after{animation:none!important;transition:none!important;
      caret-color:transparent!important;scroll-behavior:auto!important}`,
  });
  for (const step of setup) {
    if (step.click) await page.click(step.click, { timeout: 5000 }).catch(() => {});
    if (step.fill) await page.fill(step.fill.selector, step.fill.value, { timeout: 5000 }).catch(() => {});
    if (step.wait_for) await page.waitForSelector(step.wait_for, { timeout: 5000 }).catch(() => {});
    if (step.wait_ms) await page.waitForTimeout(step.wait_ms);
  }
  await page.evaluate(() => document.fonts && document.fonts.ready).catch(() => {});
  await page.waitForTimeout(150);

  const data = await page.evaluate(probeFn);

  if (screenshotPath) {
    for (const sel of mask) {
      await page.$$eval(sel, (els) => els.forEach((e) => (e.style.visibility = 'hidden'))).catch(() => {});
    }
    fs.mkdirSync(path.dirname(screenshotPath), { recursive: true });
    await page.screenshot({ path: screenshotPath, fullPage: true });
  }
  await ctx.close();
  return data;
}

/** Wait until a URL answers, or throw. Used when booting a dev server. */
export async function waitForUrl(url, timeoutMs = 120000) {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    try {
      const res = await fetch(url, { method: 'GET' });
      if (res.status < 500) return true;
    } catch { /* not up yet */ }
    await new Promise((r) => setTimeout(r, 500));
  }
  throw new Error(`timed out waiting for ${url}`);
}

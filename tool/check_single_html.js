// Ouvre le fichier HTML autonome en file://, navigateur hors ligne, et vérifie
// que l'application démarre sans requête réseau ni erreur JavaScript.
// Usage : node tool/check_single_html.js cisso-academy.html
const path = require('path');
const { chromium } = require('playwright');

(async () => {
  const file = path.resolve(process.argv[2] || 'cisso-academy.html');
  const browser = await chromium.launch();
  const ctx = await browser.newContext({ offline: true, viewport: { width: 1280, height: 800 } });
  const page = await ctx.newPage();
  const problems = [];
  page.on('pageerror', e => problems.push('Erreur JS : ' + e.message));
  page.on('requestfailed', r => problems.push('Requête échouée : ' + r.url()));
  await page.goto('file://' + file);
  await page.waitForFunction(() => !document.getElementById('cisso-loading'), null, { timeout: 90000 });
  await page.waitForTimeout(3000);
  const hasStorage = await page.evaluate(() => {
    localStorage.setItem('cisso-check', '1');
    return localStorage.getItem('cisso-check') === '1';
  });
  if (!hasStorage) problems.push('localStorage indisponible');
  await page.screenshot({ path: 'cisso-academy-html.png' });
  await browser.close();
  if (problems.length) {
    console.error(problems.join('\n'));
    process.exit(1);
  }
  console.log('OK : application démarrée hors ligne depuis ' + file);
})();

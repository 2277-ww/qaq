const { chromium } = require('playwright');
const fs = require('fs');

const OUT = 'C:/Users/paradox/Desktop/自学·平台/research/shots';
fs.mkdirSync(OUT, { recursive: true });

(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 2, locale: 'zh-CN' });
  const page = await ctx.newPage();
  const url = process.argv[2] || 'https://demo.playedu.xyz';
  await page.goto(url, { waitUntil: 'networkidle', timeout: 60000 }).catch(e => console.log('goto:', e.message));
  await page.waitForTimeout(2500);
  console.log('URL:', page.url());
  console.log('TITLE:', await page.title());
  const txt = await page.evaluate(() => document.body.innerText.slice(0, 600));
  console.log('TEXT:', txt.replace(/\n+/g, ' | '));
  const inputs = await page.$$eval('input', els => els.map(e => ({ type: e.type, name: e.name, ph: e.placeholder })));
  console.log('INPUTS:', JSON.stringify(inputs));
  const btns = await page.$$eval('button', els => els.map(e => e.innerText.trim()).filter(Boolean).slice(0, 12));
  console.log('BUTTONS:', JSON.stringify(btns));
  await page.screenshot({ path: OUT + '/probe_playedu.png' });
  await browser.close();
})();

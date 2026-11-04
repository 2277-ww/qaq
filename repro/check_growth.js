const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch({ channel: 'msedge', headless: true });
  const p = await (await b.newContext({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 2 })).newPage();
  await p.goto('http://127.0.0.1:8000/uc/growth', { waitUntil: 'networkidle' });
  const info = await p.$$eval('.kg-growth-card', els => els.map(e => {
    const r = e.getBoundingClientRect();
    return { text: e.innerText.replace(/\s+/g, ' ').trim(), w: Math.round(r.width), top: Math.round(r.top) };
  }));
  console.log(JSON.stringify(info, null, 1));
  await p.screenshot({ path: 'C:/Users/paradox/Desktop/自学·平台/repro/shots_noauth/03_growth.png', fullPage: true });
  await b.close();
})();

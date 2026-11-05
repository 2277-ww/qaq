/**
 * 采集「学习进度」窗口截图（只读）
 */
const { chromium } = require('playwright');
const fs = require('fs');

const BASE = 'https://8.138.34.151';
const OUT = 'C:/Users/paradox/Desktop/自学·平台/docs/theme-shots';
fs.mkdirSync(OUT, { recursive: true });

(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const ctx = await browser.newContext({
    viewport: { width: 1440, height: 900 },
    deviceScaleFactor: 2,
    locale: 'zh-CN',
    ignoreHTTPSErrors: true,
  });
  const page = await ctx.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(String(e)));

  await page.goto(BASE + '/uc/progress', { waitUntil: 'networkidle', timeout: 45000 });
  await page.waitForTimeout(1200);

  await page.screenshot({ path: `${OUT}/progress_1440.png`, fullPage: false });
  await page.screenshot({ path: `${OUT}/progress_full.png`, fullPage: true });

  const stat = await page.evaluate(() => ({
    title: document.title,
    rows: document.querySelectorAll('.kg-lp-table tbody tr').length,
    overflow: document.documentElement.scrollWidth > window.innerWidth,
    text: document.querySelector('.kg-lp-channel-stats') ? document.querySelector('.kg-lp-channel-stats').innerText.replace(/\s+/g, ' ') : '',
  }));

  console.log(JSON.stringify(stat, null, 2));
  console.log('errors:', errors.length ? errors.join(' | ') : 'none');

  await browser.close();
})();

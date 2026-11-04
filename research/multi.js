const { chromium } = require('playwright');
const OUT = 'C:/Users/paradox/Desktop/自学·平台/research/shots';
(async () => {
  const urls = process.argv.slice(2);
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  for (const url of urls) {
    const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 2 });
    const page = await ctx.newPage();
    try {
      await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 45000 });
      await page.waitForTimeout(4000);
      const t = (await page.evaluate(() => document.body.innerText.replace(/\n+/g, ' | '))).slice(0, 400);
      console.log('###', url, '->', page.url(), '|', await page.title());
      console.log('   ', t);
    } catch (e) {
      console.log('###', url, 'FAIL', e.message.slice(0, 60));
    }
    await ctx.close();
  }
  await browser.close();
})();

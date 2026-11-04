const { chromium } = require('playwright');
const OUT = 'C:/Users/paradox/Desktop/自学·平台/research/shots';

async function login(page, url, u, p) {
  await page.goto(url, { waitUntil: 'networkidle' });
  await page.fill('input[type=text]', u);
  await page.fill('input[type=password]', p);
  await page.click('button:has-text("立即登录")');
  await page.waitForTimeout(4000);
}

(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 2, locale: 'zh-CN' });
  const page = await ctx.newPage();
  await login(page, 'https://demo.playedu.xyz/login', '1@playedu.xyz', '123123');

  // click course card
  await page.click('text=市场调研与分析', { timeout: 15000 }).catch(async e => {
    console.log('click course failed:', e.message.slice(0, 80));
  });
  await page.waitForTimeout(3500);
  console.log('URL:', page.url());
  await page.screenshot({ path: OUT + '/pe_01_course.png' });
  console.log('TEXT:', (await page.evaluate(() => document.body.innerText.replace(/\n+/g, ' | '))).slice(0, 900));
  const items = await page.$$eval('div,li,a,span', els =>
    els.filter(e => /课时|章节|第.*讲|播放/.test(e.innerText || '') && e.children.length === 0)
       .map(e => e.innerText.trim().slice(0, 30)).slice(0, 20));
  console.log('LESSON-LIKE:', JSON.stringify(items));
  await browser.close();
})();

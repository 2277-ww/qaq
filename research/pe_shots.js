const { chromium } = require('playwright');
const OUT = 'C:/Users/paradox/Desktop/自学·平台/research/shots';

(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 860 }, deviceScaleFactor: 2, locale: 'zh-CN' });
  const page = await ctx.newPage();

  // login
  await page.goto('https://demo.playedu.xyz/login', { waitUntil: 'networkidle' });
  await page.fill('input[type=text]', '1@playedu.xyz');
  await page.fill('input[type=password]', '123123');
  await page.click('button:has-text("立即登录")');
  await page.waitForTimeout(4000);

  // 1 home
  await page.waitForTimeout(1200);
  await page.screenshot({ path: OUT + '/pe_01_home.png' });
  console.log('home ok', page.url());

  // 2 course detail
  await page.click('text=市场调研与分析', { timeout: 15000 });
  await page.waitForTimeout(3000);
  await page.screenshot({ path: OUT + '/pe_02_course.png' });
  console.log('course ok', page.url());

  // 3 player: click last lesson
  await page.click('text=开始学习', { timeout: 15000 }).catch(e => console.log('no start btn'));
  await page.waitForTimeout(5000);
  await page.screenshot({ path: OUT + '/pe_03_player.png' });
  console.log('player ok', page.url());
  console.log('PLAYER TEXT:', (await page.evaluate(() => document.body.innerText.replace(/\n+/g, ' | '))).slice(0, 500));

  // 4 recent learning
  await page.goto('https://demo.playedu.xyz/', { waitUntil: 'networkidle' });
  await page.waitForTimeout(1500);
  await page.click('text=最近学习', { timeout: 10000 }).catch(e => console.log('no recent'));
  await page.waitForTimeout(3000);
  await page.screenshot({ path: OUT + '/pe_04_recent.png' });
  console.log('recent ok', page.url());

  await browser.close();
})();

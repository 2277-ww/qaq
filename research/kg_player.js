const { chromium } = require('playwright');
const OUT = 'C:/Users/paradox/Desktop/自学·平台/research/shots';
(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true, args: ['--autoplay-policy=no-user-gesture-required'] });
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 2, locale: 'zh-CN' });
  const page = await ctx.newPage();
  await page.goto('https://ctc.koogua.com/account/login', { waitUntil: 'networkidle' });
  await page.fill('input[name=account]', '100015@163.com');
  await page.fill('input[name=password]', '123456');
  await page.click('button:has-text("登录")');
  await page.waitForTimeout(3500);

  await page.goto('https://ctc.koogua.com/course/1404', { waitUntil: 'networkidle' });
  await page.waitForTimeout(2500);
  await page.click('text=测试课时', { timeout: 10000 }).catch(e => console.log('lesson click fail'));
  await page.waitForTimeout(6000);
  console.log('URL:', page.url());
  const v = await page.evaluate(async () => {
    const el = document.querySelector('video');
    if (!el) return 'no video';
    try { el.muted = true; await el.play(); } catch (e) {}
    await new Promise(r => setTimeout(r, 2500));
    el.currentTime = 8;
    await new Promise(r => setTimeout(r, 2000));
    return { rs: el.readyState, w: el.videoWidth, t: el.currentTime };
  });
  console.log('VIDEO:', JSON.stringify(v));
  await page.screenshot({ path: OUT + '/kg_04_player.png' });
  console.log('TEXT:', (await page.evaluate(() => document.body.innerText.replace(/\n+/g,' | '))).slice(0, 400));

  await page.goto('https://ctc.koogua.com/user/100015', { waitUntil: 'networkidle' });
  await page.waitForTimeout(3000);
  await page.screenshot({ path: OUT + '/kg_05_user.png' });
  console.log('USER TEXT:', (await page.evaluate(() => document.body.innerText.replace(/\n+/g,' | '))).slice(0, 500));
  await browser.close();
})();

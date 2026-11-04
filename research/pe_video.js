const { chromium } = require('playwright');
const OUT = 'C:/Users/paradox/Desktop/自学·平台/research/shots';
(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true, args: ['--autoplay-policy=no-user-gesture-required'] });
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 860 }, deviceScaleFactor: 2, locale: 'zh-CN' });
  const page = await ctx.newPage();
  await page.goto('https://demo.playedu.xyz/login', { waitUntil: 'networkidle' });
  await page.fill('input[type=text]', '1@playedu.xyz');
  await page.fill('input[type=password]', '123123');
  await page.click('button:has-text("立即登录")');
  await page.waitForTimeout(3500);
  await page.goto('https://demo.playedu.xyz/course/5', { waitUntil: 'networkidle' });
  await page.waitForTimeout(2500);
  await page.click('text=开始学习', { timeout: 15000 }).catch(() => {});
  await page.waitForTimeout(4000);
  const info = await page.evaluate(async () => {
    const v = document.querySelector('video');
    if (!v) return 'no video el';
    try { v.muted = true; await v.play(); } catch (e) {}
    v.currentTime = 25;
    await new Promise(r => setTimeout(r, 2500));
    return { rs: v.readyState, ct: v.currentTime, w: v.videoWidth, h: v.videoHeight, err: v.error && v.error.code };
  });
  console.log('VIDEO:', JSON.stringify(info));
  await page.waitForTimeout(1500);
  await page.screenshot({ path: OUT + '/pe_03_player.png' });
  await browser.close();
})();

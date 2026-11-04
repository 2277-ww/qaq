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
  await page.waitForTimeout(3000);

  const courses = await page.$$eval('a', els => [...new Set(els.map(e => e.getAttribute('href')).filter(h => h && h.startsWith('/course/') && /^\d+$/.test(h.split('/')[2] || '')))]);
  console.log('courses:', courses.slice(0, 8).join(','));
  for (const c of courses.slice(0, 8)) {
    await page.goto('https://ctc.koogua.com' + c, { waitUntil: 'networkidle' });
    await page.waitForTimeout(1800);
    const free = await page.$$('.lesson-item:not(.deny)');
    if (free.length) {
      const url = await free[0].getAttribute('data-url');
      console.log('course', c, 'open lessons', free.length, 'first', url);
      await page.goto('https://ctc.koogua.com' + url, { waitUntil: 'networkidle' });
      await page.waitForTimeout(5000);
      const v = await page.evaluate(async () => {
        const el = document.querySelector('video');
        if (!el) return 'no video';
        try { el.muted = true; await el.play(); } catch (e) {}
        await new Promise(r => setTimeout(r, 3000));
        return { rs: el.readyState, w: el.videoWidth, t: el.currentTime };
      });
      console.log('URL now:', page.url(), 'VIDEO:', JSON.stringify(v));
      await page.screenshot({ path: OUT + '/kg_04_player.png' });
      console.log('TEXT:', (await page.evaluate(() => document.body.innerText.replace(/\n+/g,' | '))).slice(0, 350));
      break;
    }
  }
  await browser.close();
})();

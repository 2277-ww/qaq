const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const page = await (await browser.newContext({ viewport: { width: 1440, height: 900 } })).newPage();
  await page.goto('https://ctc.koogua.com/account/login', { waitUntil: 'networkidle' });
  await page.fill('input[name=account]', '100015@163.com');
  await page.fill('input[name=password]', '123456');
  await page.click('button:has-text("登录")');
  await page.waitForTimeout(3000);
  await page.goto('https://ctc.koogua.com/course/1404', { waitUntil: 'networkidle' });
  await page.waitForTimeout(2500);
  const html = await page.evaluate(() => {
    const el = [...document.querySelectorAll('*')].find(e => e.children.length === 0 && /01分钟01秒/.test(e.innerText || ''));
    let p = el; for (let i = 0; i < 4 && p; i++) p = p.parentElement;
    return p ? p.outerHTML.slice(0, 900) : 'none';
  });
  console.log(html);
  await browser.close();
})();

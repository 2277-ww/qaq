const { chromium } = require('playwright');
const OUT = 'C:/Users/paradox/Desktop/自学·平台/research/shots';
const B = 'https://school.moodledemo.net';
const HIDE = '[data-region="notification-area"],.toast,.toast-wrapper,.notifications{display:none!important}';
(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 2, locale: 'zh-CN' });
  const page = await ctx.newPage();
  await page.goto(B + '/login/index.php?lang=zh_cn', { waitUntil: 'domcontentloaded' });
  await page.fill('#username', 'teacher');
  await page.fill('#password', 'moodle26');
  await page.click('#loginbtn');
  await page.waitForTimeout(4000);

  await page.goto(B + '/my/courses.php?lang=zh_cn', { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(2500);
  const cls = await page.$$eval('a', els => [...new Set(els.map(e => e.getAttribute('href')||'').filter(h => /course\/view\.php\?id=\d+/.test(h)))]);
  console.log('teacher courses:', JSON.stringify(cls.slice(0,5)));
  const id = (cls[0] || '').match(/id=(\d+)/)[1];
  const sesskey = await page.evaluate(() => (window.M && M.cfg && M.cfg.sesskey) || '');

  await page.goto(`${B}/course/view.php?id=${id}&lang=zh_cn&edit=1&sesskey=${sesskey}`, { waitUntil: 'domcontentloaded' });
  await page.addStyleTag({ content: HIDE });
  await page.waitForTimeout(4000);
  await page.screenshot({ path: OUT + '/md_03_teacher_edit.png' });
  console.log('EDIT TEXT:', (await page.evaluate(() => document.body.innerText.replace(/\n+/g,' | '))).slice(0, 400));

  await page.goto(`${B}/report/progress/index.php?course=${id}&lang=zh_cn`, { waitUntil: 'domcontentloaded' });
  await page.addStyleTag({ content: HIDE });
  await page.waitForTimeout(3000);
  await page.screenshot({ path: OUT + '/md_04_progress.png' });
  console.log('PROG:', (await page.evaluate(() => document.body.innerText.replace(/\n+/g,' | '))).slice(0, 400));
  await browser.close();
})();

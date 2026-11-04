const { chromium } = require('playwright');
const OUT = 'C:/Users/paradox/Desktop/自学·平台/research/shots';
const B = 'https://school.moodledemo.net';
(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 2, locale: 'zh-CN' });
  const page = await ctx.newPage();
  await page.goto(B + '/login/index.php?lang=zh_cn', { waitUntil: 'domcontentloaded' });
  await page.fill('#username', 'student');
  await page.fill('#password', 'moodle26');
  await page.click('#loginbtn');
  await page.waitForTimeout(4500);

  await page.goto(B + '/my/courses.php?lang=zh_cn', { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(3000);
  await page.screenshot({ path: OUT + '/md_01_mycourses.png' });
  console.log('MY:', (await page.evaluate(() => document.body.innerText.replace(/\n+/g,' | '))).slice(0, 400));

  await page.goto(B + '/course/view.php?id=80&lang=zh_cn', { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(3500);
  await page.screenshot({ path: OUT + '/md_02_course.png' });
  console.log('COURSE:', (await page.evaluate(() => document.body.innerText.replace(/\n+/g,' | '))).slice(0, 700));
  await browser.close();
})();

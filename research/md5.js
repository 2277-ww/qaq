const { chromium } = require('playwright');
const OUT = 'C:/Users/paradox/Desktop/自学·平台/research/shots';
const B = 'https://school.moodledemo.net';
const HIDE = '[data-region="notification-area"],.toast,.toast-wrapper,.notifications{display:none!important}';
(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 2, locale: 'zh-CN' });
  const page = await ctx.newPage();
  await page.goto(B + '/login/index.php?lang=zh_cn', { waitUntil: 'domcontentloaded' });
  await page.fill('#username', 'student');
  await page.fill('#password', 'moodle26');
  await page.click('#loginbtn');
  await page.waitForTimeout(4000);

  await page.goto(B + '/my/courses.php?lang=zh_cn', { waitUntil: 'domcontentloaded' });
  await page.addStyleTag({ content: HIDE });
  await page.waitForTimeout(2500);
  await page.screenshot({ path: OUT + '/md_01_mycourses.png' });

  await page.goto(B + '/course/view.php?id=80&lang=zh_cn', { waitUntil: 'domcontentloaded' });
  await page.addStyleTag({ content: HIDE });
  await page.waitForTimeout(3000);
  await page.screenshot({ path: OUT + '/md_02_course.png' });
  console.log('student ok');

  // logout then teacher
  await page.goto(B + '/login/logout.php?sesskey=x', { waitUntil: 'domcontentloaded' }).catch(()=>{});
  await ctx.clearCookies();
  await page.goto(B + '/login/index.php?lang=zh_cn', { waitUntil: 'domcontentloaded' });
  await page.fill('#username', 'teacher');
  await page.fill('#password', 'moodle26');
  await page.click('#loginbtn');
  await page.waitForTimeout(4000);
  console.log('teacher url:', page.url());

  await page.goto(B + '/course/view.php?id=80&lang=zh_cn&edit=1', { waitUntil: 'domcontentloaded' });
  await page.addStyleTag({ content: HIDE });
  await page.waitForTimeout(3500);
  await page.screenshot({ path: OUT + '/md_03_teacher_edit.png' });
  console.log('EDIT:', (await page.evaluate(() => document.body.innerText.replace(/\n+/g,' | '))).slice(0, 300));

  await page.goto(B + '/report/progress/index.php?courseid=80&lang=zh_cn', { waitUntil: 'domcontentloaded' });
  await page.addStyleTag({ content: HIDE });
  await page.waitForTimeout(3000);
  await page.screenshot({ path: OUT + '/md_04_progress.png' });
  console.log('PROGRESS:', (await page.evaluate(() => document.body.innerText.replace(/\n+/g,' | '))).slice(0, 400));
  await browser.close();
})();

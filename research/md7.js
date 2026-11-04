const { chromium } = require('playwright');
const OUT = 'C:/Users/paradox/Desktop/自学·平台/research/shots';
const B = 'https://school.moodledemo.net';
const HIDE = '[data-region="notification-area"],.toast,.toast-wrapper,.notifications{display:none!important}';
const CLEAN = () => {
  document.querySelectorAll('div,section,aside').forEach(el => {
    const t = el.innerText || '';
    if (/reset in \d+ min/i.test(t) && t.length < 200) { el.style.display = 'none'; }
  });
};
(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const shot = async (page, name) => {
    await page.addStyleTag({ content: HIDE });
    await page.evaluate(CLEAN);
    await page.waitForTimeout(800);
    await page.screenshot({ path: OUT + '/' + name });
  };
  // student
  let ctx = await browser.newContext({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 2, locale: 'zh-CN' });
  let page = await ctx.newPage();
  await page.goto(B + '/login/index.php?lang=zh_cn', { waitUntil: 'domcontentloaded' });
  await page.fill('#username', 'student'); await page.fill('#password', 'moodle26');
  await page.click('#loginbtn'); await page.waitForTimeout(4000);
  await page.goto(B + '/my/courses.php?lang=zh_cn', { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(2500); await shot(page, 'md_01_mycourses.png');
  await page.goto(B + '/course/view.php?id=80&lang=zh_cn', { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(3000); await shot(page, 'md_02_course.png');
  await ctx.close();

  // teacher
  ctx = await browser.newContext({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 2, locale: 'zh-CN' });
  page = await ctx.newPage();
  await page.goto(B + '/login/index.php?lang=zh_cn', { waitUntil: 'domcontentloaded' });
  await page.fill('#username', 'teacher'); await page.fill('#password', 'moodle26');
  await page.click('#loginbtn'); await page.waitForTimeout(4000);
  const sesskey = await page.evaluate(() => (window.M && M.cfg && M.cfg.sesskey) || '');
  await page.goto(`${B}/course/view.php?id=69&lang=zh_cn&edit=1&sesskey=${sesskey}`, { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(3500); await shot(page, 'md_03_teacher_edit.png');
  await page.goto(`${B}/report/progress/index.php?course=69&lang=zh_cn`, { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(3000); await shot(page, 'md_04_progress.png');
  console.log('done');
  await browser.close();
})();

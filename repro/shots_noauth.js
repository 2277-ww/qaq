/**
 * 采集无登录模式的页面截图（只读，不产生数据）
 */
const { chromium } = require('playwright');
const fs = require('fs');

const BASE = 'http://127.0.0.1:8000';
const OUT = 'C:/Users/paradox/Desktop/自学·平台/repro/shots_noauth';
fs.mkdirSync(OUT, { recursive: true });

(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const ctx = await browser.newContext({
    viewport: { width: 1440, height: 900 },
    deviceScaleFactor: 2,
    locale: 'zh-CN',
  });
  const page = await ctx.newPage();
  const errors = [];
  page.on('pageerror', e => errors.push(e.message));

  const shots = [
    ['/', '01_home.png', false],
    ['/course/1', '02_course_panel.png', true],
    ['/uc/growth', '03_growth.png', true],
    ['/uc/notes', '04_notes.png', true],
    ['/uc/favorites?type=chapter', '05_favorites_video.png', true],
    ['/chapter/3', '06_chapter.png', true],
    ['/admin', '07_admin.png', false],
  ];

  for (const [path, name, full] of shots) {
    await page.goto(BASE + path, { waitUntil: 'networkidle' });
    await page.waitForTimeout(700);
    await page.screenshot({ path: `${OUT}/${name}`, fullPage: full });
    console.log(`${name}  ${path}`);
  }

  // 笔记页统计
  await page.goto(BASE + '/uc/notes', { waitUntil: 'networkidle' });
  const stats = await page.$eval('.kg-note-stats', e => e.innerText.replace(/\s+/g, ' ').trim());
  console.log('笔记统计:', stats);

  console.log('js errors:', errors.length ? JSON.stringify(errors) : 'none');
  await browser.close();
})();

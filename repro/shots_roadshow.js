/**
 * 采集线上站点（8.138.34.151）路演用截图，只读，不改数据
 */
const { chromium } = require('playwright');
const fs = require('fs');

const BASE = 'https://8.138.34.151';
const OUT = 'C:/Users/paradox/Desktop/自学·平台/自学平台答辩/assets2';
fs.mkdirSync(OUT, { recursive: true });

(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const ctx = await browser.newContext({
    viewport: { width: 1440, height: 900 },
    deviceScaleFactor: 2,
    locale: 'zh-CN',
    ignoreHTTPSErrors: true,
    // 后台凭据不写死：从环境变量读取，未设置则不带认证（只能截公开页）
    //   Windows: set CTC_ADMIN_PASS=xxx && node repro/shots_roadshow.js
    ...(process.env.CTC_ADMIN_PASS
      ? { httpCredentials: { username: process.env.CTC_ADMIN_USER || 'admin', password: process.env.CTC_ADMIN_PASS } }
      : {}),
  });
  const page = await ctx.newPage();

  const shots = [
    ['/', 'home_1440.png', false],
    ['/course/9', 'course_1440.png', false],
    ['/chapter/2', 'chapter_1440.png', false],
    ['/admin/course/list', 'admin_course_1440.png', false],
    ['/admin/video_upload/list', 'admin_video_1440.png', false],
  ];

  for (const [path, name, full] of shots) {
    try {
      await page.goto(BASE + path, { waitUntil: 'networkidle', timeout: 45000 });
      await page.waitForTimeout(1200);
      await page.screenshot({ path: `${OUT}/${name}`, fullPage: full });
      const t = await page.title();
      console.log(`${name}\t${path}\t${t}`);
    } catch (e) {
      console.log(`${name}\tFAILED\t${e.message.split('\n')[0]}`);
    }
  }

  await browser.close();
})();

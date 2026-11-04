const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch({ channel: 'msedge', headless: true });
  const p = await (await b.newContext({ viewport: { width: 1440, height: 900 } })).newPage();
  await p.goto('http://127.0.0.1:8000/course/7', { waitUntil: 'networkidle' });
  const tab = p.locator('.layui-tabs-header li', { hasText: '目录' }).first();
  await tab.click();
  await p.waitForTimeout(800);
  const text = await p.evaluate(() => document.body.innerText);
  console.log('目录标签页含:', ['第一章 开发环境', '环境搭建与工具链入门', '并发编程：从线程到协程'].map(t => t + '=' + text.includes(t)).join(' '));
  await p.screenshot({ path: 'shots_vodsync/02b_course_7_catalog.png', fullPage: true });
  await b.close();
})();

const { chromium } = require('playwright');

const BASE = 'http://127.0.0.1:8000';
const OUT = 'C:/Users/paradox/Desktop/自学·平台/repro/shots_vodsync';

(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 1.5 });
  const page = await ctx.newPage();

  const errors = [];
  page.on('pageerror', e => errors.push('[pageerror] ' + e.message.slice(0, 120)));
  page.on('response', r => { if (r.status() >= 400 && !r.url().includes('mux.dev')) errors.push('[http ' + r.status() + '] ' + r.url().slice(0, 100)); });

  // 1. 分类列表页：应能看到两门同步课程
  await page.goto(BASE + '/course/list?tc=2', { waitUntil: 'networkidle' });
  const courseTitles = await page.$$eval('.course-name, .kg-course-card, a', els =>
    els.map(e => e.innerText).filter(t => t.includes('Python 进阶实战') || t.includes('前端基础补完计划'))
  );
  console.log('分类页可见新课:', JSON.stringify(courseTitles.slice(0, 4)));
  await page.screenshot({ path: OUT + '/01_course_list_tc2.png', fullPage: true });

  // 2. 课程详情：目录两章四节
  await page.goto(BASE + '/course/7', { waitUntil: 'networkidle' });
  const catalog = await page.evaluate(() => document.body.innerText);
  console.log('课程目录包含:', ['第一章 开发环境', '第二章 语言进阶', '环境搭建与工具链入门', '并发编程：从线程到协程'].map(t => t + '=' + catalog.includes(t)).join(' '));
  await page.screenshot({ path: OUT + '/02_course_7.png', fullPage: true });

  // 3. 播放页：远程地址注入
  await page.goto(BASE + '/chapter/38', { waitUntil: 'networkidle' });
  const playUrls = await page.$eval('input[name="chapter.play_urls"]', el => el.value).catch(() => '');
  console.log('播放页远程地址注入:', playUrls.includes('mux.dev') ? 'OK' : 'MISSING ' + playUrls.slice(0, 80));
  await page.screenshot({ path: OUT + '/03_chapter_38.png', fullPage: true });

  // 4. 后台：源管理页 + 菜单
  await page.goto(BASE + '/admin/vod_sync', { waitUntil: 'networkidle' });
  const adminText = await page.evaluate(() => document.body.innerText);
  console.log('后台源管理页:', ['视频同步源', '演示源', '无默认分类源', '添加同步源'].map(t => t + '=' + adminText.includes(t)).join(' '));
  const menuHasVodSync = await page.$$eval('.layui-side a, .layui-nav-tree a', els => els.some(e => e.innerText.includes('视频同步')));
  console.log('侧栏菜单含「视频同步」:', menuHasVodSync);
  await page.screenshot({ path: OUT + '/04_admin_vod_sync.png', fullPage: true });

  // 5. 手动触发同步按钮（CSRF 流程）
  const runResult = await page.evaluate(async () => {
    const token = document.querySelector('meta[name="csrf-token"]').getAttribute('content');
    const res = await fetch('/admin/vod_sync/run', {
      method: 'POST',
      headers: { 'X-Csrf-Token': token },
      body: new URLSearchParams({ source_id: '0' })
    });
    return await res.json();
  }).catch(e => ({ code: -1, msg: String(e).slice(0, 80) }));
  console.log('手动触发同步:', JSON.stringify(runResult).slice(0, 200));

  // 6. 同步日志页
  await page.goto(BASE + '/admin/vod_sync/logs', { waitUntil: 'networkidle' });
  const logText = await page.evaluate(() => document.body.innerText);
  console.log('日志页:', ['同步日志', '已同步', '失败', '分类缺失'].map(t => t + '=' + logText.includes(t)).join(' '));
  await page.screenshot({ path: OUT + '/05_admin_logs.png', fullPage: true });

  console.log('js errors:', errors.length ? JSON.stringify(errors.slice(0, 6)) : 'none');
  await browser.close();
})();

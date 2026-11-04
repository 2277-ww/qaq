/**
 * 无登录模式回归校验
 *
 * 验证目标：
 * 1. 前台与后台均无登录/注册/退出入口，且相关路由不可达
 * 2. 内置身份生效，笔记、收藏、学习进度、成长档案等依赖 user_id 的功能照常工作
 * 3. 写操作（收藏切换、笔记保存、成长档案同步）在无会话情况下可正常提交
 */
const { chromium } = require('playwright');
const fs = require('fs');

const BASE = 'http://127.0.0.1:8000';
const OUT = 'C:/Users/paradox/Desktop/自学·平台/repro/shots_noauth';
fs.mkdirSync(OUT, { recursive: true });

const NOTE_TEXT = '无登录模式回归校验 ' + Date.now();

(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const ctx = await browser.newContext({
    viewport: { width: 1440, height: 900 },
    deviceScaleFactor: 2,
    locale: 'zh-CN',
  });
  const page = await ctx.newPage();

  const errors = [];
  const missing = [];
  page.on('pageerror', e => errors.push('[pageerror] ' + e.message));
  page.on('console', m => { if (m.type() === 'error') errors.push('[console] ' + m.text()); });
  page.on('response', r => { if (r.status() === 404) missing.push(r.url()); });
  page.on('response', r => { if (r.status() >= 500) missing.push('[500] ' + r.url()); });

  // ---------- 1. 首页导航 ----------
  await page.goto(BASE + '/', { waitUntil: 'networkidle' });
  const navText = await page.$eval('.layui-nav', e => e.innerText.replace(/\s+/g, ' ').trim()).catch(() => '');
  const hasLoginLink = await page.$('a[href*="/account/login"]') !== null;
  const hasRegisterLink = await page.$('a[href*="/account/register"]') !== null;
  const hasLogoutLink = await page.$('a[href*="/account/logout"]') !== null;
  console.log('导航文案:', navText);
  console.log('登录入口:', hasLoginLink, '| 注册入口:', hasRegisterLink, '| 退出入口:', hasLogoutLink);
  await page.screenshot({ path: `${OUT}/01_home.png` });

  // ---------- 2. 课程详情：学习面板 + 收藏往返 + 笔记保存 ----------
  await page.goto(BASE + '/course/1', { waitUntil: 'networkidle' });
  const hasPanel = await page.$('.kg-study-panel') !== null;
  console.log('学习面板存在:', hasPanel);

  if (hasPanel) {
    const before = await page.$eval('#btn-course-favorite', e => ({ text: e.innerText.trim(), fav: e.dataset.favorited }));
    await page.click('#btn-course-favorite');
    await page.waitForTimeout(1600);
    const mid = await page.$eval('#btn-course-favorite', e => ({ text: e.innerText.trim(), fav: e.dataset.favorited }));
    await page.click('#btn-course-favorite');
    await page.waitForTimeout(1600);
    const after = await page.$eval('#btn-course-favorite', e => ({ text: e.innerText.trim(), fav: e.dataset.favorited }));
    console.log('收藏前:', JSON.stringify(before));
    console.log('收藏后:', JSON.stringify(mid));
    console.log('还原后:', JSON.stringify(after));

    await page.fill('#kg-note-input', NOTE_TEXT);
    await page.click('#btn-note-save');
    await page.waitForTimeout(2600);
    const noteVisible = await page.locator('.kg-note-mini li', { hasText: NOTE_TEXT }).count();
    console.log('笔记保存并回显:', noteVisible > 0);
    await page.screenshot({ path: `${OUT}/02_course_panel.png`, fullPage: true });
  }

  // ---------- 3. 成长档案 ----------
  await page.goto(BASE + '/uc/growth', { waitUntil: 'networkidle' });
  const overview = await page.$$eval('.kg-growth-card', els =>
    els.map(e => e.innerText.replace(/\s+/g, ' ').trim())
  );
  console.log('成长档案概览:', JSON.stringify(overview));
  const timelineRows = await page.$$eval('.kg-growth-section table tbody tr', trs => trs.length);
  console.log('档案表格行数:', timelineRows);
  await page.screenshot({ path: `${OUT}/03_growth.png`, fullPage: true });

  // ---------- 4. 我的笔记 ----------
  await page.goto(BASE + '/uc/notes', { waitUntil: 'networkidle' });
  const noteCount = await page.$$eval('.kg-note-list li', els => els.length).catch(() => 0);
  const noteStats = await page.$eval('.kg-note-stats', e => e.innerText.replace(/\s+/g, ' ').trim()).catch(() => '');
  const noteHasTest = await page.locator('.kg-note-list', { hasText: NOTE_TEXT }).count();
  console.log('笔记页统计:', noteStats, '| 列表项:', noteCount, '| 含本次测试笔记:', noteHasTest > 0);
  await page.screenshot({ path: `${OUT}/04_notes.png`, fullPage: true });

  // ---------- 5. 收藏视频 ----------
  await page.goto(BASE + '/uc/favorites?type=chapter', { waitUntil: 'networkidle' });
  const favRows = await page.$$eval('table tbody tr', trs =>
    trs.map(tr => tr.innerText.replace(/\s+/g, ' ').trim())
  );
  console.log('收藏视频行数:', favRows.length);
  favRows.slice(0, 4).forEach(r => console.log('  ', r));
  await page.screenshot({ path: `${OUT}/05_favorites_video.png`, fullPage: true });

  // ---------- 6. 播放页 ----------
  await page.goto(BASE + '/chapter/3', { waitUntil: 'networkidle' });
  const chapterTools = await page.$('.kg-study-tools') !== null;
  const chapterNotes = await page.$('#kg-chapter-note') !== null;
  const chapterFavBtn = await page.$('#btn-chapter-favorite') !== null;
  console.log('播放页工具栏:', chapterTools, '| 课时笔记区:', chapterNotes, '| 收藏视频按钮:', chapterFavBtn);
  await page.screenshot({ path: `${OUT}/06_chapter.png`, fullPage: true });

  // ---------- 7. 后台免登录 ----------
  await page.goto(BASE + '/admin', { waitUntil: 'networkidle' });
  const adminLoginForm = await page.$('.kg-login-form') !== null;
  const adminLogout = await page.$$eval('a', as => as.some(a => a.innerText.includes('退出登录')));
  console.log('后台 URL:', page.url());
  console.log('后台登录表单:', adminLoginForm, '| 后台退出入口:', adminLogout);
  await page.screenshot({ path: `${OUT}/07_admin.png` });

  // ---------- 8. 已删除路由 ----------
  const removed = ['/account/login', '/account/register', '/account/logout', '/account/forget', '/oauth/qq', '/uc/account', '/admin/login'];
  for (const path of removed) {
    const res = await page.goto(BASE + path, { waitUntil: 'domcontentloaded' });
    console.log(`  ${res.status()}  ${path}`);
  }

  console.log('js errors:', errors.length ? JSON.stringify(errors.slice(0, 5)) : 'none');
  console.log('404 资源:', missing.length ? JSON.stringify([...new Set(missing)].slice(0, 10)) : 'none');
  console.log('NOTE_TEXT=' + NOTE_TEXT);

  await browser.close();
})();

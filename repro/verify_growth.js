const { chromium } = require('playwright');
const fs = require('fs');

const BASE = 'http://127.0.0.1:8000';
const OUT = 'C:/Users/paradox/Desktop/自学·平台/repro/shots_growth';
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
  page.on('console', m => { if (m.type() === 'error') errors.push('console: ' + m.text()); });

  // 登录
  await page.goto(BASE + '/account/login', { waitUntil: 'networkidle' });
  await page.fill('form[action="/account/password/login"] input[name=account]', '10000@163.com');
  await page.fill('form[action="/account/password/login"] input[name=password]', '123456');
  await page.click('form[action="/account/password/login"] button[type=submit], form[action="/account/password/login"] .layui-btn');
  await page.waitForTimeout(3000);
  console.log('after login url:', page.url());

  // 1. 成长档案
  await page.goto(BASE + '/uc/growth', { waitUntil: 'networkidle' });
  await page.waitForTimeout(800);
  const overview = await page.$$eval('.kg-growth-card', els =>
    els.map(e => e.innerText.replace(/\s+/g, ' ').trim())
  );
  console.log('overview:', JSON.stringify(overview));
  const courseRows = await page.$$eval('.kg-growth-section table tbody tr', trs =>
    trs.map(tr => tr.innerText.replace(/\s+/g, ' ').trim())
  );
  console.log('course rows:', courseRows.length);
  courseRows.slice(0, 4).forEach(r => console.log('  ', r));
  const syncText = await page.$eval('.kg-sync-panel', e => e.innerText.replace(/\s+/g, ' ').trim()).catch(() => '');
  console.log('sync:', syncText);
  await page.screenshot({ path: `${OUT}/01_growth_full.png`, fullPage: true });

  // 2. 我的笔记
  await page.goto(BASE + '/uc/notes', { waitUntil: 'networkidle' });
  await page.waitForTimeout(600);
  const noteStats = await page.$eval('.kg-note-stats', e => e.innerText.replace(/\s+/g, ' ').trim());
  console.log('note stats:', noteStats);
  const noteCount = await page.$$eval('.kg-note-item', els => els.length);
  console.log('note cards:', noteCount);
  await page.screenshot({ path: `${OUT}/02_notes_full.png`, fullPage: true });

  // 2b. 笔记检索
  await page.goto(BASE + '/uc/notes?keyword=' + encodeURIComponent('字典'), { waitUntil: 'networkidle' });
  await page.waitForTimeout(500);
  const searched = await page.$$eval('.kg-note-item', els => els.length);
  console.log('search "字典" hits:', searched);
  await page.screenshot({ path: `${OUT}/03_notes_search.png`, fullPage: true });

  // 3. 收藏视频
  await page.goto(BASE + '/uc/favorites?type=chapter', { waitUntil: 'networkidle' });
  await page.waitForTimeout(600);
  const favRows = await page.$$eval('table tbody tr', trs =>
    trs.map(tr => tr.innerText.replace(/\s+/g, ' ').trim())
  );
  console.log('favorites rows:', favRows.length);
  favRows.forEach(r => console.log('  ', r));
  await page.screenshot({ path: `${OUT}/04_favorites_chapter.png`, fullPage: true });

  // 4. 课程详情页的学习区
  await page.goto(BASE + '/course/1', { waitUntil: 'networkidle' });
  await page.waitForTimeout(600);
  const study = await page.$eval('.kg-study-panel', e => e.innerText.replace(/\s+/g, ' ').trim()).catch(() => '');
  console.log('course study panel:', study.slice(0, 150));
  const panel = await page.$('.kg-study-panel');
  if (panel) await panel.screenshot({ path: `${OUT}/05_course_study_panel.png` });
  await page.screenshot({ path: `${OUT}/06_course_show.png`, fullPage: false });

  // 5. 学习页的笔记与收藏
  await page.goto(BASE + '/chapter/3', { waitUntil: 'networkidle' });
  await page.waitForTimeout(800);
  const toolTip = await page.$eval('.kg-study-tools', e => e.innerText.replace(/\s+/g, ' ').trim()).catch(() => '');
  console.log('chapter tools:', toolTip.slice(0, 200));
  const tools = await page.$('.kg-study-tools');
  if (tools) await tools.screenshot({ path: `${OUT}/07_chapter_tools.png` });

  console.log('js errors:', errors.length ? JSON.stringify(errors.slice(0, 5)) : 'none');

  await browser.close();
})();

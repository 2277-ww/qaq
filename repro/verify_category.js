const { chromium } = require('playwright');
const fs = require('fs');

const BASE = 'http://127.0.0.1:8000';
const OUT = 'C:/Users/paradox/Desktop/自学·平台/repro/shots_add';
fs.mkdirSync(OUT, { recursive: true });

(async () => {
  const browser = await chromium.launch({ channel: 'msedge', headless: true });
  const ctx = await browser.newContext({
    viewport: { width: 1440, height: 900 },
    deviceScaleFactor: 2,
    locale: 'zh-CN',
  });
  const page = await ctx.newPage();

  // 1. front-end list: category filter chips
  await page.goto(BASE + '/course/list', { waitUntil: 'networkidle' });
  await page.waitForSelector('#course-list a[href^="/course/"]', { timeout: 15000 }).catch(() => {});
  const chips = await page.$$eval('.filter-group:first-child .content a', els =>
    els.map(e => ({ text: e.innerText.trim(), href: e.getAttribute('href'), active: e.className.includes('layui-btn') }))
  );
  console.log('chips:', JSON.stringify(chips, null, 0));
  const filter = await page.$('.filter-group:first-child');
  await filter.screenshot({ path: `${OUT}/01_filter_chips.png` });
  await page.screenshot({ path: `${OUT}/02_course_list_full.png` });

  // 2. click the new category
  const link = await page.$('.filter-group:first-child .content a[href="/course/list?tc=7"]');
  console.log('new chip found:', !!link);
  if (link) {
    await link.click();
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(1500);
    console.log('url after click:', page.url());
    const active = await page.$$eval('.filter-group:first-child .content a.layui-btn', els =>
      els.map(e => e.innerText.trim())
    );
    console.log('active chip:', JSON.stringify(active));
    await page.screenshot({ path: `${OUT}/03_tc7_selected.png` });
  }

  // 3. admin category list
  await page.goto(BASE + '/admin/login', { waitUntil: 'networkidle' });
  await page.fill('form[action="/admin/login"] input[name=account]', '10000@163.com');
  await page.fill('form[action="/admin/login"] input[name=password]', '123456');
  await page.click('form[action="/admin/login"] button[type=submit], form[action="/admin/login"] .layui-btn');
  await page.waitForTimeout(3500);
  console.log('admin url:', page.url());

  await page.goto(BASE + '/admin/category/list', { waitUntil: 'networkidle' });
  await page.waitForTimeout(2000);
  const rows = await page.$$eval('table tbody tr', trs =>
    trs.map(tr => tr.innerText.replace(/\s+/g, ' ').trim())
  );
  console.log('admin category rows:', rows.length);
  rows.forEach((r, i) => console.log(' ', i + 1, r));
  await page.screenshot({ path: `${OUT}/04_admin_category.png`, fullPage: true });

  await browser.close();
})();

/**
 * 会员功能清除后的界面核验
 */
const { chromium } = require('playwright');
const fs = require('fs');

const BASE = 'http://127.0.0.1:8000';
const OUT = 'C:/Users/paradox/Desktop/自学·平台/repro/shots_noauth';

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

  const pages = [
    ['/admin/course/1/edit', 'vip_check_01_course_edit.png'],
    ['/admin/package/list', 'vip_check_02_package_list.png'],
    ['/admin/point/gift/add', 'vip_check_03_pointgift_add.png'],
    ['/admin', 'vip_check_04_admin_home.png'],
    ['/admin/user/20000/edit', 'vip_check_05_user_edit.png'],
    ['/point/gift/list', 'vip_check_06_point_mall.png'],
  ];

  for (const [path, name] of pages) {
    await page.goto(BASE + path, { waitUntil: 'networkidle' });
    await page.waitForTimeout(600);
    const text = await page.evaluate(() => document.body.innerText);
    const vipHits = (text.match(/会员/g) || []).length;
    console.log(`${name}  会员字样=${vipHits}  url=${path}`);
    await page.screenshot({ path: `${OUT}/${name}`, fullPage: true });
  }

  // 后台首页统计卡片
  await page.goto(BASE + '/admin', { waitUntil: 'networkidle' });
  const cards = await page.$$eval('.kg-stat-card .name', els => els.map(e => e.innerText.trim()));
  console.log('后台统计卡片:', JSON.stringify(cards));

  // 前台导航与课程详情
  await page.goto(BASE + '/', { waitUntil: 'networkidle' });
  const nav = await page.$eval('.layui-nav', e => e.innerText.replace(/\s+/g, ' ').trim());
  console.log('前台导航:', nav);

  await page.goto(BASE + '/course/1', { waitUntil: 'networkidle' });
  const priceArea = await page.evaluate(() => {
    const el = document.querySelector('.course-price, .kg-course-price, .price');
    return el ? el.innerText.replace(/\s+/g, ' ').trim() : '(未找到价格区)';
  });
  console.log('课程价格区:', priceArea);

  console.log('js errors:', errors.length ? JSON.stringify(errors.slice(0, 5)) : 'none');
  await browser.close();
})();

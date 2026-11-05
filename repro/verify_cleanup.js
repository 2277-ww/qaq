// 验证：直播/面授/订单/积分/收货地址已下线，中级高级课程可筛选可播放
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const BASE = 'http://127.0.0.1:8000';
const OUT = path.join(__dirname, '..', 'docs', 'cleanup-shots');

(async () => {
  fs.mkdirSync(OUT, { recursive: true });
  const browser = await chromium.launch({ channel: 'msedge' });
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 2 });
  const page = await ctx.newPage();

  const errors = [];
  page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  page.on('pageerror', e => errors.push('pageerror: ' + e.message));

  const shot = async (name) => page.screenshot({ path: path.join(OUT, name + '.png'), fullPage: false });
  const results = [];
  const check = (label, ok, extra = '') => {
    results.push(`${ok ? 'PASS' : 'FAIL'}  ${label}${extra ? '  ' + extra : ''}`);
  };

  // 1. 课程列表 + 难度筛选
  await page.goto(BASE + '/course/list', { waitUntil: 'networkidle' });
  await page.waitForTimeout(800);
  await shot('01_course_list');

  const bodyText = await page.locator('body').innerText();
  check('列表页无「直播/面授」文本', !/直播|面授/.test(bodyText));

  const midChip = page.locator('.filter-group a', { hasText: '中级' }).first();
  const highChip = page.locator('.filter-group a', { hasText: '高级' }).first();
  check('难度筛选含「中级」「高级」', await midChip.count() > 0 && await highChip.count() > 0);

  if (await midChip.count() > 0) {
    await midChip.click();
    await page.waitForTimeout(1200);
    const cardsMid = await page.locator('.course-card').count();
    const titlesMid = await page.locator('.course-card .title').allInnerTexts();
    await shot('02_filter_mid');
    check('中级筛选返回 2 门课程', cardsMid === 2, `实际 ${cardsMid}：${titlesMid.join(' / ')}`);
  }

  if (await highChip.count() > 0) {
    await highChip.click();
    await page.waitForTimeout(1200);
    const cardsHigh = await page.locator('.course-card').count();
    const titlesHigh = await page.locator('.course-card .title').allInnerTexts();
    await shot('03_filter_high');
    check('高级筛选返回 2 门课程', cardsHigh === 2, `实际 ${cardsHigh}：${titlesHigh.join(' / ')}`);
  }

  // 2. 课程详情
  await page.goto(BASE + '/course/10', { waitUntil: 'networkidle' });
  await page.waitForTimeout(600);
  const metaText = await page.locator('.course-meta').innerText();
  check('课程详情难度显示「中级」', metaText.includes('中级'));
  check('课程详情无退款期限', !metaText.includes('退款期限'));
  await shot('04_course_mid_detail');

  const lessons = await page.locator('.lesson-item').count();
  check('中级课程目录 4 课时', lessons === 4, `实际 ${lessons}`);

  // 3. 播放验证
  await page.goto(BASE + '/chapter/52', { waitUntil: 'networkidle' });
  await page.waitForTimeout(1500);
  const playInfo = await page.evaluate(async () => {
    const v = document.querySelector('video');
    if (!v) return { ok: false, reason: 'no video element' };
    try {
      v.muted = true;
      await v.play();
    } catch (e) {
      return { ok: false, reason: 'play error: ' + e.message };
    }
    await new Promise(r => setTimeout(r, 3000));
    return { ok: v.currentTime > 0.5, currentTime: v.currentTime, duration: v.duration, src: v.currentSrc };
  });
  check('课时视频可播放', playInfo.ok, JSON.stringify(playInfo));
  await shot('05_chapter_play');

  // 4. 用户中心
  await page.goto(BASE + '/uc/courses', { waitUntil: 'networkidle' });
  await page.waitForTimeout(500);
  const menuText = await page.locator('.my-menu').first().locator('..').locator('..').innerText();
  const sideText = await page.locator('.layout-sidebar, .uc-sidebar, aside').first().innerText().catch(() => bodyText);
  await shot('06_user_center');
  const ucAll = await page.locator('body').innerText();
  check('用户中心无「订单中心」', !ucAll.includes('订单中心'));
  check('用户中心无「积分中心」', !ucAll.includes('积分中心'));
  check('用户中心无「收货地址」', !ucAll.includes('收货地址'));

  // 5. 后台首页
  await page.goto(BASE + '/admin', { waitUntil: 'networkidle' });
  await page.waitForTimeout(800);
  const adminText = await page.locator('body').innerText();
  await shot('07_admin_index');
  check('后台无「财务管理/订单管理/积分商城」', !/财务管理|订单管理|积分商城/.test(adminText));
  check('后台今日统计无成交订单/退款', !/成交订单|成功退款|退款金额/.test(adminText));

  // 6. 后台课程表单只剩点播/图文
  await page.goto(BASE + '/admin/course/add', { waitUntil: 'networkidle' });
  await page.waitForTimeout(500);
  const modelRadios = await page.locator('input[name=model]').count();
  await shot('08_admin_course_add');
  check('课程类型仅 2 项（点播/图文）', modelRadios === 2, `实际 ${modelRadios}`);

  const cleanErrors = errors.filter(e => !/favicon|net::ERR_ABORTED/i.test(e));
  check('页面无 JS 报错', cleanErrors.length === 0, cleanErrors.slice(0, 3).join(' | '));

  console.log(results.join('\n'));
  console.log('\n截图目录：' + OUT);
  await browser.close();
  if (results.some(r => r.startsWith('FAIL'))) process.exitCode = 1;
})();

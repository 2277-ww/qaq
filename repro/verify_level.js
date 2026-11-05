// 验证：学习等级自选（保存、回显、列表联动、移动端适配）
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const BASE = 'http://127.0.0.1:8000';
const OUT = path.join(__dirname, '..', 'docs', 'upload-shots');

(async () => {
  fs.mkdirSync(OUT, { recursive: true });

  const browser = await chromium.launch({ channel: 'msedge' });
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 2 });
  const page = await ctx.newPage();

  const errors = [];
  page.on('pageerror', e => errors.push('pageerror: ' + e.message));

  const results = [];
  const check = (label, ok, extra = '') => results.push(`${ok ? 'PASS' : 'FAIL'}  ${label}${extra ? '  ' + extra : ''}`);

  const submitForm = async (p) => {
    await p.evaluate(() => window.scrollTo(0, document.body.scrollHeight));
    await p.waitForTimeout(200);
    const resp = p.waitForResponse(r => r.url().indexOf('/uc/profile/update') > -1, { timeout: 15000 }).catch(() => null);
    await p.evaluate(() => document.querySelector('button[lay-filter="go"]').click());
    await resp;
    await p.waitForTimeout(1700);
    await p.waitForLoadState('networkidle');
  };

  await page.goto(BASE + '/uc/profile', { waitUntil: 'networkidle' });

  const chips = page.locator('.kg-level-chip');
  check('等级选项共 5 个（4 档 + 暂不设置）', await chips.count() === 5, String(await chips.count()));

  const levelNames = await page.locator('.kg-level-chip .name').allInnerTexts();
  check('预设等级列表为 入门/初级/中级/高级', ['入门', '初级', '中级', '高级'].every(n => levelNames.includes(n)), levelNames.join('/'));

  await page.screenshot({ path: path.join(OUT, '07_profile_level.png'), clip: { x: 0, y: 0, width: 1440, height: 760 } });

  // 选择「高级」并保存
  await page.locator('.kg-level-chip[data-level="4"]').click();
  const hidden = await page.locator('#level-value').inputValue();
  check('点击选卡后隐藏域同步', hidden === '4', hidden);

  await submitForm(page);
  await page.waitForTimeout(800);

  const tipText = await page.locator('.kg-level-tip').innerText();
  check('保存后回显「当前等级：高级」', /高级/.test(tipText), tipText.replace(/\n/g, ' ').slice(0, 40));

  const activeText = await page.locator('.kg-level-chip.is-active .name').innerText();
  check('刷新后选中态保持', activeText === '高级', activeText);

  // 课程列表联动
  await page.goto(BASE + '/course/list', { waitUntil: 'networkidle' });
  const myLevel = await page.locator('.kg-my-level').count();
  check('课程列表展示「我的等级」提示', myLevel > 0);

  if (myLevel > 0) {
    const badge = await page.locator('.kg-my-level .layui-badge').innerText();
    check('提示中的等级与设置一致', badge === '高级', badge);

    await page.locator('.kg-my-level a').click();
    await page.waitForTimeout(1200);
    const cards = await page.locator('.course-card').count();
    check('按等级筛选返回高级课程 2 门', cards === 2, `实际 ${cards}`);
    await page.screenshot({ path: path.join(OUT, '08_my_level_filter.png') });
  }

  // 移动端
  const mctx = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true });
  const mpage = await mctx.newPage();
  await mpage.goto(BASE + '/uc/profile', { waitUntil: 'networkidle' });
  await mpage.locator('#level-group').scrollIntoViewIfNeeded();
  await mpage.waitForTimeout(400);
  await mpage.screenshot({ path: path.join(OUT, '09_mobile_level.png') });

  const overflow = await mpage.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
  check('移动端无横向溢出', overflow <= 1, `溢出 ${overflow}px`);

  const chipBox = await mpage.locator('.kg-level-chip').first().boundingBox();
  const groupBox = await mpage.locator('#level-group').boundingBox();
  check('移动端选卡两列布局', chipBox && groupBox && chipBox.width < groupBox.width * 0.6,
    chipBox ? `${Math.round(chipBox.width)}/${Math.round(groupBox.width)}` : '未取到');

  await mpage.locator('.kg-level-chip[data-level="1"]').click();
  await submitForm(mpage);
  await mpage.waitForTimeout(600);
  const mobileTip = await mpage.locator('.kg-level-tip').innerText();
  check('移动端可切换并保存等级', /入门/.test(mobileTip), mobileTip.replace(/\n/g, ' ').slice(0, 30));

  // 恢复为中级，保持演示一致
  await mpage.locator('.kg-level-chip[data-level="3"]').click();
  await submitForm(mpage);

  check('页面无 JS 异常', errors.length === 0, errors.slice(0, 2).join(' | '));

  console.log(results.join('\n'));
  await browser.close();
})().catch(e => {
  console.error('SCRIPT ERROR', e);
  process.exit(1);
});

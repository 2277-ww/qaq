const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch({ channel: 'msedge', headless: true });
  const p = await (await b.newContext({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 2 })).newPage();
  await p.goto('http://127.0.0.1:8000/admin/course/1/edit', { waitUntil: 'networkidle' });
  // 点击“营销设置”标签
  const tab = p.locator('.layui-tabs-header li', { hasText: '营销设置' });
  await tab.click();
  await p.waitForTimeout(600);
  const text = await p.evaluate(() => document.body.innerText);
  console.log('会员字样出现次数:', (text.match(/会员/g) || []).length);
  console.log('页面含字段:', ['市场价格','学习期限','退款期限'].map(f => `${f}=${text.includes(f)}`).join(' '));
  await p.screenshot({ path: 'C:/Users/paradox/Desktop/自学·平台/repro/shots_noauth/vip_check_01b_course_sale.png', fullPage: true });
  await b.close();
})();

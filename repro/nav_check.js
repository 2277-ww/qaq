const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch({ channel: 'msedge', headless: true });
  const p = await (await b.newContext({ viewport: { width: 1440, height: 900 } })).newPage();
  await p.goto('http://127.0.0.1:8000/', { waitUntil: 'networkidle' });
  console.log('首页导航:', await p.$eval('.layui-nav', e => e.innerText.replace(/\s+/g, ' ').trim()));
  await p.goto('http://127.0.0.1:8000/admin', { waitUntil: 'networkidle' });
  const menus = await p.$$eval('.layui-nav-tree a, .layui-side-scroll a', els => els.map(e => e.innerText.trim()).filter(Boolean));
  console.log('后台菜单:', JSON.stringify(menus.slice(0, 60)));
  const vipMenu = menus.filter(m => m.includes('会员'));
  console.log('后台含会员的菜单项:', JSON.stringify(vipMenu));
  await b.close();
})();

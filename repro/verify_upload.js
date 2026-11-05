// 验证：课时视频本地上传（分片进度、格式/大小校验、失败提示、保存生效）
const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const BASE = 'http://127.0.0.1:8000';
const OUT = path.join(__dirname, '..', 'docs', 'upload-shots');
const SAMPLE = 'C:/ctc/www/public/static/vod/database/btree-index.mp4';
const BIG = 'C:/Users/paradox/AppData/Local/Temp/big_video.mp4';
const TXT = 'C:/Users/paradox/AppData/Local/Temp/bad_file.txt';

(async () => {
  fs.mkdirSync(OUT, { recursive: true });

  const browser = await chromium.launch({ channel: 'msedge' });
  const ctx = await browser.newContext({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 2 });
  const page = await ctx.newPage();

  const errors = [];
  page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
  page.on('pageerror', e => errors.push('pageerror: ' + e.message));

  const results = [];
  const check = (label, ok, extra = '') => {
    results.push(`${ok ? 'PASS' : 'FAIL'}  ${label}${extra ? '  ' + extra : ''}`);
  };
  const shot = (name) => page.screenshot({ path: path.join(OUT, name + '.png') });

  // 打开课时点播信息
  await page.goto(BASE + '/admin/chapter/52/edit', { waitUntil: 'networkidle' });
  await page.locator('.layui-tabs-header li', { hasText: '点播信息' }).first().click();
  await page.waitForTimeout(400);

  const dropVisible = await page.locator('#kg-uploader .kg-upload-drop').isVisible();
  check('点播页出现「本地上传」区块', dropVisible);
  await shot('01_upload_tab');

  // 1. 非法格式
  await page.locator('#kg-uploader input[type=file]').setInputFiles(TXT);
  await page.waitForTimeout(400);
  let alertText = await page.locator('#kg-uploader .kg-alert-text').innerText();
  check('非法格式提示', /不支持的视频格式/.test(alertText), alertText.slice(0, 40));
  await shot('02_invalid_ext');

  // 2. 超出大小
  await page.locator('#kg-uploader input[type=file]').setInputFiles(BIG);
  await page.waitForTimeout(600);
  alertText = await page.locator('#kg-uploader .kg-alert-text').innerText();
  check('超出 500MB 提示', /500 MB/.test(alertText), alertText.slice(0, 60));
  await shot('03_too_large');

  // 3. 正常上传（限速以便观察进度）
  const cdp = await ctx.newCDPSession(page);
  await cdp.send('Network.enable');
  await cdp.send('Network.emulateNetworkConditions', {
    offline: false, latency: 20, downloadThroughput: -1, uploadThroughput: 1500 * 1024,
  });

  await page.locator('#kg-uploader input[type=file]').setInputFiles(SAMPLE);
  await page.waitForTimeout(900);

  const percentDuring = await page.locator('#kg-uploader .kg-upload-percent').innerText();
  const progressVisible = await page.locator('#kg-uploader .kg-upload-progress').isVisible();
  check('上传中显示进度条', progressVisible && /\d+%/.test(percentDuring), `当前 ${percentDuring}`);
  await shot('04_uploading');

  await page.locator('#kg-uploader .kg-upload-done').waitFor({ state: 'visible', timeout: 120000 });
  await cdp.send('Network.emulateNetworkConditions', {
    offline: false, latency: 0, downloadThroughput: -1, uploadThroughput: -1,
  });

  const doneText = await page.locator('#kg-uploader .kg-upload-done').innerText();
  const hiddenUrl = await page.locator('#local-vod-url').inputValue();
  const submitEnabled = await page.locator('#local-vod-submit').isEnabled();
  check('上传完成并回填地址', /static\/vod\/uploads\//.test(hiddenUrl), hiddenUrl.slice(-40));
  check('完成后「保存为课时视频」可点击', submitEnabled);
  check('结果区展示文件名与大小', /大小/.test(doneText), doneText.replace(/\n/g, ' | ').slice(0, 80));
  await shot('05_uploaded');

  // 4. 保存并校验落库
  await page.locator('#local-vod-submit').click();
  await page.waitForTimeout(2500);

  const chapterResp = await page.goto(BASE + '/chapter/52', { waitUntil: 'networkidle' });
  const html = await chapterResp.text();
  check('课时页返回 200', chapterResp.status() === 200, String(chapterResp.status()));
  const plainHtml = html.replace(/\\\//g, '/');
  check('课时页播放源指向新上传文件', /uploads\/\d{6}\//.test(plainHtml));

  const videoSrc = await page.locator('video').first().getAttribute('src').catch(() => null);
  check('播放器已挂载上传后的地址', !!videoSrc && /uploads\//.test(videoSrc), videoSrc || '未取到');

  // 5. 移动端
  const mctx = await browser.newContext({ viewport: { width: 390, height: 844 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true });
  const mpage = await mctx.newPage();
  await mpage.goto(BASE + '/admin/chapter/52/edit', { waitUntil: 'networkidle' });
  await mpage.locator('.layui-tabs-header li', { hasText: '点播信息' }).first().click();
  await mpage.waitForTimeout(500);
  await mpage.locator('#kg-uploader').scrollIntoViewIfNeeded();
  await mpage.screenshot({ path: path.join(OUT, '06_mobile_upload.png') });

  const mobileOverflow = await mpage.evaluate(() => document.documentElement.scrollWidth - document.documentElement.clientWidth);
  check('移动端无横向溢出', mobileOverflow <= 1, `溢出 ${mobileOverflow}px`);

  check('控制台无报错', errors.length === 0, errors.slice(0, 2).join(' | '));

  console.log(results.join('\n'));
  console.log('\n截图目录:', OUT);

  await browser.close();
})().catch(e => {
  console.error('SCRIPT ERROR', e);
  process.exit(1);
});

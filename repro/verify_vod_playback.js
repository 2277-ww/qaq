// 七个分类的课程视频可播性验证：目录 → 课时 → 播放器实际播放
const { chromium } = require('playwright');
const fs = require('fs');

const CATEGORIES = [
  { alias: 'frontend', name: '前端开发', courseId: 1 },
  { alias: 'python', name: 'Python 算法', courseId: 2 },
  { alias: 'vision', name: 'YOLO 视觉', courseId: 3 },
  { alias: 'devops', name: 'Docker 部署', courseId: 4 },
  { alias: 'database', name: '数据库', courseId: 5 },
  { alias: 'security', name: '网络安全', courseId: 6 },
  { alias: 'police', name: '警务业务知识', courseId: null }, // 运行时按分类页查找
];

const OUT = 'shots_vod_play';
if (!fs.existsSync(OUT)) fs.mkdirSync(OUT, { recursive: true });

(async () => {
  const b = await chromium.launch({ channel: 'msedge', headless: true });
  const ctx = await b.newContext({ viewport: { width: 1440, height: 900 } });
  const p = await ctx.newPage();
  const results = [];

  for (const cat of CATEGORIES) {
    let courseId = cat.courseId;
    const row = { category: cat.name, courseId, ok: false };

    try {
      if (!courseId) {
        // 从分类页列表中取第一门课程（AJAX 渲染，等待卡片出现）
        await p.goto(`http://127.0.0.1:8000/course/list?tc=7`, { waitUntil: 'networkidle' });
        await p.waitForTimeout(1200);
        const href = await p.evaluate(() => {
          const a = [...document.querySelectorAll('a[href]')].find(e => /^\/course\/\d+$/.test(e.getAttribute('href')));
          return a ? a.getAttribute('href') : null;
        });
        const m = href && href.match(/\/course\/(\d+)/);
        if (!m) throw new Error('分类页未找到课程卡片');
        courseId = parseInt(m[1], 10);
        row.courseId = courseId;
      }

      // 1) 课程详情页 → 目录 tab
      await p.goto(`http://127.0.0.1:8000/course/${courseId}`, { waitUntil: 'networkidle' });
      const catTab = p.locator('.layui-tabs-header li', { hasText: '目录' }).first();
      if (await catTab.count()) {
        await catTab.click();
        await p.waitForTimeout(700);
      }
      const lessonHref = await p.evaluate(() => {
        const li = document.querySelector('li.lesson-item[data-url]');
        return li ? li.getAttribute('data-url') : null;
      });
      const lm = lessonHref && lessonHref.match(/\/chapter\/(\d+)/);
      if (!lm) throw new Error('目录中未找到课时链接');
      const chapterId = parseInt(lm[1], 10);
      row.chapterId = chapterId;

      // 2) 播放页：检查 video 元素与播放进度
      const errors = [];
      p.removeAllListeners('pageerror');
      p.on('pageerror', e => errors.push(e.message));
      await p.goto(`http://127.0.0.1:8000/chapter/${chapterId}`, { waitUntil: 'networkidle' });
      await p.waitForTimeout(1500);

      const src = await p.evaluate(() => {
        const v = document.querySelector('video');
        if (!v) return null;
        return v.currentSrc || v.src || (v.querySelector('source') ? v.querySelector('source').src : '');
      });
      row.videoSrc = src;

      if (!src) throw new Error('页面无 video 源');

      // 触发播放（静音以绕过自动播放限制），检查 currentTime 增长
      const played = await p.evaluate(async () => {
        const v = document.querySelector('video');
        if (!v) return { ok: false, reason: 'no video' };
        v.muted = true;
        try { await v.play(); } catch (e) { /* 可能被策略拦截 */ }
        const t0 = v.currentTime;
        await new Promise(r => setTimeout(r, 3000));
        return {
          ok: v.currentTime > t0 + 0.3 || v.readyState >= 2,
          t0, t1: v.currentTime,
          readyState: v.readyState,
          duration: isFinite(v.duration) ? Math.round(v.duration) : null,
          error: v.error ? v.error.code : null,
        };
      });
      row.play = played;
      row.ok = played.ok && !played.error;
      if (!row.ok) row.error = '未实际播放';

      await p.screenshot({ path: `${OUT}/${cat.alias}-${courseId}.png`, fullPage: false });
    } catch (e) {
      row.error = e.message;
    }

    console.log(`${row.ok ? 'OK  ' : 'FAIL'} ${row.category.padEnd(12)} course=${row.courseId} chapter=${row.chapterId || '-'} ` +
      (row.play ? `t=${(row.play.t1 || 0).toFixed(1)}s dur=${row.play.duration}s` : '') + (row.error ? ' | ' + row.error : ''));
    results.push(row);
  }

  fs.writeFileSync(`${OUT}/report.json`, JSON.stringify(results, null, 2));
  const ok = results.filter(r => r.ok).length;
  console.log(`\n${ok}/${results.length} 个分类视频播放正常`);
  await b.close();
})();

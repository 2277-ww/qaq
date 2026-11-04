// 按 vod_plan.json 批量下载课程视频到 static/vod/<category>/<slug>.mp4
// 输出 repro/vod_downloaded.json 供入库脚本使用
const https = require('https');
const fs = require('fs');
const path = require('path');

const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
const OUT_ROOT = 'C:/ctc/www/static/vod';
const PLAN = JSON.parse(fs.readFileSync(path.join(__dirname, 'vod_plan.json'), 'utf8'));
const RESULT_FILE = path.join(__dirname, 'vod_downloaded.json');

let cookieJar = '';
function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

function rawGet(url, headers = {}) {
  return new Promise((resolve, reject) => {
    const req = https.get(url, {
      headers: {
        'User-Agent': UA,
        'Referer': 'https://www.bilibili.com/',
        ...(cookieJar ? { Cookie: cookieJar } : {}),
        ...headers,
      },
    }, res => {
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        res.resume();
        return rawGet(res.headers.location, headers).then(resolve, reject);
      }
      const chunks = [];
      res.on('data', c => chunks.push(c));
      res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, body: Buffer.concat(chunks) }));
    });
    req.on('error', reject);
    req.setTimeout(60000, () => req.destroy(new Error('timeout')));
  });
}

async function jget(url) {
  if (!cookieJar) {
    try {
      const home = await rawGet('https://www.bilibili.com/');
      cookieJar = (home.headers['set-cookie'] || []).map(c => c.split(';')[0]).join('; ');
    } catch (e) { /* ignore */ }
  }
  const r = await rawGet(url);
  return JSON.parse(r.body.toString('utf8'));
}

const viewCache = {};
async function viewInfo(bvid) {
  if (!viewCache[bvid]) {
    const j = await jget('https://api.bilibili.com/x/web-interface/view?bvid=' + bvid);
    if (j.code !== 0) throw new Error('view ' + bvid + ' code=' + j.code);
    viewCache[bvid] = j.data;
    await sleep(400);
  }
  return viewCache[bvid];
}

async function playurl(bvid, cid) {
  const j = await jget('https://api.bilibili.com/x/player/playurl?bvid=' + bvid + '&cid=' + cid + '&qn=64&platform=html5&high_quality=1');
  if (j.code !== 0) throw new Error('playurl code=' + j.code + ' ' + j.message);
  const d = j.data.durl && j.data.durl[0];
  if (!d) throw new Error('no durl');
  return { url: d.url, size: d.size, quality: j.data.quality, seconds: Math.round(j.data.timelength / 1000) };
}

async function downloadFile(url, dest) {
  const r = await rawGet(url);
  if (r.status !== 200) throw new Error('http ' + r.status);
  if (r.body.length < 100 * 1024) throw new Error('too small ' + r.body.length);
  fs.writeFileSync(dest, r.body);
  return r.body.length;
}

async function fetchOne(category, slug, bvid, page) {
  const dir = path.join(OUT_ROOT, category);
  fs.mkdirSync(dir, { recursive: true });
  const dest = path.join(dir, slug + '.mp4');
  if (fs.existsSync(dest) && fs.statSync(dest).size > 1024 * 1024) {
    return { file: dest, size: fs.statSync(dest).size, skipped: true };
  }
  const info = await viewInfo(bvid);
  const pg = info.pages.find(p => p.page === page) || info.pages[0];
  let lastErr;
  for (let attempt = 1; attempt <= 3; attempt++) {
    try {
      const pu = await playurl(bvid, pg.cid);
      const size = await downloadFile(pu.url, dest);
      return { file: dest, size, quality: pu.quality, seconds: pu.seconds, part: pg.part };
    } catch (e) {
      lastErr = e;
      console.log('    retry ' + attempt + ' failed: ' + e.message);
      await sleep(2000 * attempt);
    }
  }
  throw lastErr;
}

(async () => {
  const jobs = [];
  for (const c of PLAN.courses) {
    for (const ch of c.chapters) {
      if (!ch.bvid) continue;
      jobs.push({ kind: 'course', course_id: c.course_id, chapter_id: ch.chapter_id, category: c.category, slug: ch.slug, bvid: ch.bvid, page: ch.page, title: ch.title });
    }
  }
  for (const ch of PLAN.police_course.chapters) {
    for (const l of ch.lessons) {
      jobs.push({ kind: 'police', category: 'police', slug: l.slug, bvid: l.bvid, page: l.page, title: l.title, chapterTitle: ch.title, summary: l.summary });
    }
  }

  const results = [];
  console.log('total jobs: ' + jobs.length);
  for (let i = 0; i < jobs.length; i++) {
    const job = jobs[i];
    console.log(`[${i + 1}/${jobs.length}] ${job.category}/${job.slug} <- ${job.bvid} p${job.page} (${job.title})`);
    try {
      const r = await fetchOne(job.category, job.slug, job.bvid, job.page);
      console.log(`    ok ${(r.size / 1048576).toFixed(1)}MB${r.skipped ? ' (exists)' : ''} ${r.seconds ? Math.round(r.seconds / 60) + 'min' : ''}`);
      results.push({ ...job, ...r, ok: true });
    } catch (e) {
      console.log('    FAILED: ' + e.message);
      results.push({ ...job, ok: false, error: e.message });
    }
    await sleep(800);
  }
  fs.writeFileSync(RESULT_FILE, JSON.stringify(results, null, 2));
  const okCount = results.filter(r => r.ok).length;
  console.log(`done: ${okCount}/${results.length} ok`);
})().catch(e => { console.error('FATAL ' + e.message); process.exit(1); });

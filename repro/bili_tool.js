// B站公开课视频工具：搜索 / 取视频信息 / 取播放地址 / 下载
// 用法:
//   node bili_tool.js search "关键词"          -> 搜索结果(前20条: bvid 标题 时长 up主)
//   node bili_tool.js info BV1xxxx             -> 视频信息与分P列表
//   node bili_tool.js playurl BV1xxxx [page]   -> 取 mp4 播放地址
//   node bili_tool.js download BV1xxxx [page] dest.mp4  -> 下载
const https = require('https');
const fs = require('fs');

const UA = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

let cookieJar = '';

function sleep(ms) { return new Promise(r => setTimeout(r, ms)); }

async function initCookie() {
  if (cookieJar) return;
  const r = await get('https://www.bilibili.com/');
  const setCookies = r.headers['set-cookie'] || [];
  cookieJar = setCookies.map(c => c.split(';')[0]).join('; ');
}

function get(url, headers = {}) {
  return new Promise((resolve, reject) => {
    const req = https.get(url, {
      headers: {
        'User-Agent': UA,
        'Referer': 'https://www.bilibili.com/',
        ...headers,
      },
    }, res => {
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        res.resume();
        return get(res.headers.location, headers).then(resolve, reject);
      }
      const chunks = [];
      res.on('data', c => chunks.push(c));
      res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, body: Buffer.concat(chunks) }));
    });
    req.on('error', reject);
    req.setTimeout(15000, () => req.destroy(new Error('timeout')));
  });
}

async function jget(url) {
  await initCookie();
  const r = await get(url, cookieJar ? { Cookie: cookieJar } : {});
  try { return JSON.parse(r.body.toString('utf8')); }
  catch (e) { throw new Error('bad json from ' + url + ' status=' + r.status + ' body=' + r.body.slice(0, 120)); }
}

function fmtDur(s) {
  if (typeof s === 'string') return s; // 搜索接口返回 "mm:ss"
  const m = Math.floor(s / 60), ss = s % 60;
  return m + '分' + (ss < 10 ? '0' : '') + ss + '秒';
}

async function search(keyword, page = 1) {
  await sleep(1500);
  const data = await jget('https://api.bilibili.com/x/web-interface/search/type?search_type=video&keyword=' + encodeURIComponent(keyword) + '&page=' + page);
  if (data.code !== 0) throw new Error('search code=' + data.code + ' ' + data.message);
  const out = [];
  for (const it of (data.data.result || [])) {
    if (it.type && it.type !== 'video') continue; // 过滤课堂/付费
    const title = it.title.replace(/<[^>]+>/g, '');
    out.push({
      bvid: it.bvid,
      title,
      duration: it.duration,
      durTxt: fmtDur(it.duration),
      author: it.author,
      play: it.play,
      review: it.review,
    });
  }
  return out;
}

async function info(bvid) {
  const data = await jget('https://api.bilibili.com/x/web-interface/view?bvid=' + bvid);
  if (data.code !== 0) throw new Error('view code=' + data.code + ' ' + data.message);
  const d = data.data;
  return {
    bvid: d.bvid,
    title: d.title,
    owner: d.owner.name,
    duration: d.duration,
    pages: (d.pages || []).map(p => ({ page: p.page, part: p.part, cid: p.cid, duration: p.duration })),
    cid: d.cid,
    desc: (d.desc || '').slice(0, 100),
  };
}

async function playurl(bvid, cid) {
  const data = await jget('https://api.bilibili.com/x/player/playurl?bvid=' + bvid + '&cid=' + cid + '&qn=32&platform=html5&high_quality=1');
  if (data.code !== 0) throw new Error('playurl code=' + data.code + ' ' + data.message);
  const durl = data.data.durl;
  if (!durl || !durl.length) throw new Error('no durl, dash only?');
  return { url: durl[0].url, size: durl[0].size, quality: data.data.quality, duration: data.data.timelength / 1000 };
}

async function download(url, dest) {
  // B站 CDN 需要带 UA 与 Referer
  const r = await get(url);
  if (r.status !== 200) throw new Error('download status=' + r.status + ' url=' + url.slice(0, 80));
  fs.writeFileSync(dest, r.body);
  return { size: r.body.length, dest };
}

(async () => {
  const cmd = process.argv[2];
  try {
    if (cmd === 'search') {
      const list = await search(process.argv[3]);
      for (const it of list) console.log(`${it.bvid}  [${it.durTxt}]  ${it.author}  播放${it.play}  ${it.title}`);
    } else if (cmd === 'info') {
      const i = await info(process.argv[3]);
      console.log(JSON.stringify(i, null, 2));
    } else if (cmd === 'playurl') {
      const i = await info(process.argv[3]);
      const page = parseInt(process.argv[4] || '1', 10);
      const pg = (i.pages.length ? i.pages.find(p => p.page === page) : null) || { cid: i.cid };
      const r = await playurl(i.bvid, pg.cid);
      console.log(JSON.stringify(r, null, 2));
    } else if (cmd === 'download') {
      const i = await info(process.argv[3]);
      const page = parseInt(process.argv[4] || '1', 10);
      const pg = (i.pages.length ? i.pages.find(p => p.page === page) : null) || { cid: i.cid };
      const r = await playurl(i.bvid, pg.cid);
      const dest = process.argv[process.argv.length - 1];
      const d = await download(r.url, dest);
      console.log(JSON.stringify({ ...d, bvid: i.bvid, page, quality: r.quality }));
    } else {
      console.log('commands: search|info|playurl|download');
    }
  } catch (e) {
    console.error('ERROR: ' + e.message);
    process.exit(1);
  }
})();

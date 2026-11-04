// 从下载结果生成警务业务知识课程的同步清单（供 VodSync 拉取）
const fs = require('fs');
const path = require('path');

const base = __dirname;
const plan = JSON.parse(fs.readFileSync(path.join(base, 'vod_plan.json'), 'utf8'));
const downloaded = JSON.parse(fs.readFileSync(path.join(base, 'vod_downloaded.json'), 'utf8'));

const police = downloaded.filter(r => r.kind === 'police' && r.ok);
if (!police.length) {
  console.error('no police videos downloaded');
  process.exit(1);
}

// 按 plan 中的顺序输出
const items = [];
let seq = 0;
for (const ch of plan.police_course.chapters) {
  for (const lesson of ch.lessons) {
    const rec = police.find(r => r.slug === lesson.slug);
    if (!rec) {
      console.error('missing download: ' + lesson.slug);
      continue;
    }
    seq++;
    items.push({
      id: 'police-' + String(seq).padStart(3, '0'),
      title: lesson.title,
      url: 'http://127.0.0.1:8000/static/vod/police/' + lesson.slug + '.mp4',
      sd_url: 'http://127.0.0.1:8000/static/vod/police/' + lesson.slug + '.mp4',
      duration: rec.seconds || 0,
      course: plan.police_course.course,
      chapter: ch.title,
      category: plan.police_course.category,
      summary: lesson.summary || '',
    });
  }
}

const out = path.join('C:/ctc/www/storage', 'vod_manifest_police.json');
fs.writeFileSync(out, JSON.stringify({ items }, null, 2), 'utf8');
console.log('wrote ' + out + ' items=' + items.length);

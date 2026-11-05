/* 时间轴引擎：window.__render(t) 由录制脚本逐帧调用，画面状态完全由 t 决定 */
(function () {
  'use strict';

  var TL = window.TIMELINE || { fps: 25, duration: 0, scenes: [] };
  var DEFS = window.SCENE_DEFS;
  var clamp = function (x, a, b) { a = a === undefined ? 0 : a; b = b === undefined ? 1 : b; return Math.min(b, Math.max(a, x)); };
  var lerp = function (a, b, t) { return a + (b - a) * t; };
  var eo = function (t) { t = clamp(t); return 1 - Math.pow(1 - t, 3); };
  var eio = function (t) { t = clamp(t); return t < .5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2; };
  function $(s, r) { return (r || document).querySelector(s); }
  function $$(s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); }
  function center(el) { var r = el.getBoundingClientRect(); return { x: r.left + r.width / 2, y: r.top + r.height / 2 }; }

  var ROLES = {
    student: { av: '王', name: '王立军 · 20260001', desc: '学生 / student', chip: '学生', dim: ['teach', 'sys'] },
    teacher: { av: '张', name: '张海洋 · T2019033', desc: '教师 / teacher', chip: '教师', dim: ['sys'] },
    admin: { av: '陈', name: '陈立明 · A0001', desc: '管理员 / admin', chip: '管理员', dim: [] }
  };
  var NAV = ['home', 'catalog', 'mine', 'archive', 'teach', 'sys'];

  var stage = $('#stage'), win = $('#win'), content = $('#content'),
      cap = $('#cap'), capTx = $('#capTx'), cursor = $('#cursor'),
      navhl = $('#navhl'), urlEl = $('#url'), crumbEl = $('#crumb'),
      idxEl = $('#sceneIdx'), nameEl = $('#sceneName'), hintEl = $('#hintText');

  /* ---- 场景装配 ---- */
  var scenes = [];
  var pages = {};
  var cur = null, curPage = null, curRender = null;

  (TL.scenes.length ? TL.scenes : [{ id: 'intro', title: '片头', start: 0, dur: 6, lines: [] },
                                   { id: 'catalog', title: '课程目录', start: 6, dur: 6, lines: [] }])
    .forEach(function (s, i) {
      var def = DEFS[s.id];
      if (!def) return;
      var host;
      if (def.shell) {
        host = document.createElement('div');
        host.className = 'page';
        host.style.display = 'none';
        content.appendChild(host);
      } else {
        host = document.createElement('div');
        host.style.position = 'absolute';
        host.style.inset = '0';
        host.style.zIndex = '20';
        host.style.display = 'none';
        stage.appendChild(host);
      }
      var r = def.build(host);
      var o = {
        id: s.id, title: s.title || def.title || s.id,
        startMs: s.start * 1000, durMs: s.dur * 1000,
        def: def, host: host, render: r, lines: (s.lines || []).map(function (l) {
          return { text: l.text, startMs: l.start * 1000, endMs: l.end * 1000 };
        })
      };
      scenes.push(o);
    });

  /* ---- chrome ---- */
  var navPrevIdx = null, navCurIdx = null, navT0 = -1;

  function setRole(key) {
    var r = ROLES[key] || ROLES.student;
    $('#roleAv').textContent = r.av;
    $('#roleName').textContent = r.name;
    $('#roleDesc').textContent = r.desc;
    $('#chipAv').textContent = r.av;
    $('#chipRole').textContent = r.chip;
    $$('.navi').forEach(function (n) {
      var k = n.getAttribute('data-k');
      var lock = $('.lock', n);
      var dim = r.dim.indexOf(k) >= 0;
      n.className = 'navi' + (dim ? ' dim' : '');
      if (lock) lock.style.display = dim ? 'inline-block' : 'none';
    });
  }

  function activate(sc) {
    if (cur && cur.host) cur.host.style.display = 'none';
    cur = sc;
    var shell = sc.def.shell !== false;
    win.style.opacity = shell ? 1 : 0;
    win.style.pointerEvents = shell ? 'auto' : 'none';
    sc.host.style.display = 'block';
    curRender = sc.render;

    if (shell) {
      setRole(sc.def.role || 'student');
      urlEl.textContent = sc.def.url || '';
      hintEl.textContent = sc.def.hint || '搜索课程、资源';
      var cr = sc.def.crumb || ['教学空间', ''];
      crumbEl.innerHTML = cr.map(function (t, i) {
        if (i === cr.length - 1) return '<b>' + t + '</b>';
        return '<span>' + t + '</span>' + (i < cr.length - 1 ? '<span style="opacity:.4">/</span>' : '');
      }).join('');
      var idx = sc.def.nav ? NAV.indexOf(sc.def.nav) : -1;
      navPrevIdx = navCurIdx === null ? idx : navCurIdx;
      navCurIdx = idx;
      navT0 = -1;
    } else {
      navCurIdx = -1; navPrevIdx = -1;
    }
    idxEl.textContent = ('0' + (scenes.indexOf(sc) + 1)).slice(-2) + ' / ' + ('0' + scenes.length).slice(-2);
    nameEl.textContent = sc.title;
  }

  function updateNav(t) {
    if (navCurIdx === undefined) return;
    if (navCurIdx < 0 && navPrevIdx < 0) { navhl.style.opacity = 0; return; }
    if (navT0 < 0) navT0 = t;
    var k = eio(clamp((t - navT0) / 360));
    var from = navPrevIdx >= 0 ? navPrevIdx : navCurIdx;
    var to = navCurIdx >= 0 ? navCurIdx : from;
    navhl.style.opacity = navCurIdx >= 0 ? String(1) : String(1 - k);
    navhl.style.transform = 'translateY(' + lerp(from, to, k) * 42 + 'px)';
  }

  function updateCaption(t) {
    var sc = cur;
    if (!sc || !sc.lines.length) { cap.style.opacity = 0; return; }
    var i = -1;
    for (var j = 0; j < sc.lines.length; j++) {
      if (t >= sc.lines[j].startMs - 60) i = j; else break;
    }
    if (i < 0) { cap.style.opacity = 0; return; }
    var ln = sc.lines[i];
    capTx.textContent = ln.text;
    var end = i + 1 < sc.lines.length ? sc.lines[i + 1].startMs - 70
      : Math.min(sc.startMs + sc.durMs, ln.endMs + 700);
    var inK = clamp((t - (ln.startMs - 80)) / 220);
    var outK = clamp((end - t) / 200);
    cap.style.opacity = String(Math.min(inK, outK));
  }

  /* ---- cursor ---- */
  var rip = document.createElement('div');
  rip.className = 'rip';
  rip.style.opacity = '0';
  stage.appendChild(rip);

  function drawCursor(p, keys) {
    if (!keys || !keys.length) { cursor.style.opacity = 0; return; }
    cursor.style.opacity = '1';
    var i = 0;
    for (; i < keys.length - 1; i++) if (p >= keys[i].p && p < keys[i + 1].p) break;
    if (p <= keys[0].p) i = 0;
    var a = keys[i], b = keys[Math.min(i + 1, keys.length - 1)];
    var k = b.p === a.p ? 0 : eio((p - a.p) / (b.p - a.p));
    var x = lerp(a.x, b.x, k), y = lerp(a.y, b.y, k);
    cursor.style.transform = 'translate(' + (x - 3) + 'px,' + (y - 2) + 'px)';

    var clickAt = null;
    for (var j = 0; j < keys.length; j++) {
      if (keys[j].click && p >= keys[j].p && p <= keys[j].p + 0.035) clickAt = keys[j];
    }
    if (clickAt) {
      var q = (p - clickAt.p) / 0.035;
      rip.style.left = (clickAt.x - 30) + 'px';
      rip.style.top = (clickAt.y - 30) + 'px';
      rip.style.width = '60px';
      rip.style.height = '60px';
      rip.style.opacity = String((1 - q) * 0.6);
      rip.style.transform = 'scale(' + (0.4 + q * 1.4) + ')';
    } else rip.style.opacity = '0';
  }

  var ctx = {
    cursor: drawCursor,
    center: center
  };

  /* ---- 主渲染 ---- */
  function sceneAt(t) {
    for (var i = scenes.length - 1; i >= 0; i--) if (t >= scenes[i].startMs) return scenes[i];
    return scenes[0];
  }

  var lastSc = null;
  function render(t) {
    if (!scenes.length) return;
    var sc = sceneAt(t);
    if (sc !== lastSc) { activate(sc); lastSc = sc; }
    var localMs = t - sc.startMs;
    var p = clamp(localMs / sc.durMs, 0, 1);
    if (sc.def.shell !== false) updateNav(t);
    cursor.style.opacity = '0';
    rip.style.opacity = '0';
    curRender(p, localMs, ctx);
    updateCaption(t);
    stage.setAttribute('data-scene', sc.id);
  }
  window.__render = render;

  window.__scenes = scenes.map(function (s) { return { id: s.id, start: s.startMs, dur: s.durMs }; });

  /* 手动预览：?scene=catalog&p=0.4 */
  var qs = new URLSearchParams(location.search);
  if (qs.get('scene')) {
    var want = qs.get('scene'), pp = parseFloat(qs.get('p') || '0.5');
    var idx = scenes.findIndex(function (s) { return s.id === want; });
    if (idx >= 0) render(scenes[idx].startMs + scenes[idx].durMs * pp);
    else render(0);
  } else if (!TL.scenes.length) {
    render(0);
  } else {
    render(0);
  }
})();

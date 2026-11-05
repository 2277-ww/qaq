/* scene definitions for the demo film — build() returns render(p, tl) */
(function () {
  'use strict';

  var clamp = function (x, a, b) { a = a === undefined ? 0 : a; b = b === undefined ? 1 : b; return Math.min(b, Math.max(a, x)); };
  var lerp = function (a, b, t) { return a + (b - a) * t; };
  var eo = function (t) { t = clamp(t); return 1 - Math.pow(1 - t, 3); };
  var eio = function (t) { t = clamp(t); return t < .5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2; };
  var st = function (p, a, b) { return clamp((p - a) / (b - a)); };
  var S = function (el, o) { if (el) for (var k in o) el.style[k] = o[k]; };
  function $(s, r) { return (r || document).querySelector(s); }
  function $$(s, r) { return Array.prototype.slice.call((r || document).querySelectorAll(s)); }
  function center(el) { var r = el.getBoundingClientRect(); return { x: r.left + r.width / 2, y: r.top + r.height / 2 }; }

  /* ---------- shared fragments ---------- */
  function card(d) {
    var p = d.progress;
    return '<div class="ccard">' +
      '<div class="cover" style="background:' + d.bg + '">' +
        '<div class="pat"></div>' +
        '<div class="code">' + d.code + '</div>' +
        '<div class="st"><span class="tag ' + d.tagc + '">' + d.st + '</span></div>' +
        '<div class="ct">' + d.cat + '</div>' +
      '</div>' +
      '<div class="cbody">' +
        '<h4>' + d.title + '</h4>' +
        '<div class="cmeta">' + d.teacher + '<span style="opacity:.35">·</span>' + d.hours + ' 学时<span style="opacity:.35">·</span>' + d.level + '</div>' +
        (p > 0 ? '<div class="pbar"><i style="width:' + p + '%"></i></div><div class="cfoot"><span>进度 ' + p + '%</span><span>' + d.people + ' 人在学</span></div>'
               : '<div class="cfoot" style="margin-top:0"><span>' + d.people + ' 人在学</span><span style="color:#22509B">查看课程</span></div>') +
      '</div></div>';
  }

  var COURSES = [
    { code: 'course_01J8F2', title: '网络安全基础', cat: '网络安全', teacher: '张海洋', hours: 16, level: '中级', people: 128, st: '已发布', tagc: 'g', p: 42, bg: 'linear-gradient(135deg,#1F3A5F,#2E5FA8)' },
    { code: 'course_01J8G7', title: '数据库原理与应用', cat: '数据库', teacher: '李文博', hours: 24, level: '初级', people: 96, st: '已发布', tagc: 'g', p: 0, bg: 'linear-gradient(135deg,#3B2A73,#6C4BC4)' },
    { code: 'course_01J8H1', title: '容器与云原生实践', cat: '云原生', teacher: '周敏', hours: 20, level: '中级', people: 74, st: '已发布', tagc: 'g', p: 18, bg: 'linear-gradient(135deg,#0F4C5C,#1D7A8C)' },
    { code: 'course_01J8H9', title: '目标检测实战', cat: '人工智能', teacher: '刘一鸣', hours: 22, level: '高级', people: 51, st: '已发布', tagc: 'g', p: 0, bg: 'linear-gradient(135deg,#5A2A2A,#A4523F)' },
    { code: 'course_01J8J3', title: '数据结构与算法', cat: '计算机基础', teacher: '陈晓东', hours: 32, level: '中级', people: 210, st: '已发布', tagc: 'g', p: 100, bg: 'linear-gradient(135deg,#243B53,#3E6B8C)' },
    { code: 'course_01J8K6', title: '内网攻防演练', cat: '网络安全', teacher: '张海洋', hours: 18, level: '高级', people: 43, st: '已发布', tagc: 'g', p: 0, bg: 'linear-gradient(135deg,#2A2F55,#4A5A9E)' },
    { code: 'course_01J8M2', title: 'Python 数据分析', cat: '数据分析', teacher: '孙倩', hours: 20, level: '初级', people: 167, st: '已发布', tagc: 'g', p: 0, bg: 'linear-gradient(135deg,#1B4A3A,#2E8B62)' },
    { code: 'course_01J8N8', title: '电子数据取证入门', cat: '网络安全', teacher: '王振宇', hours: 14, level: '初级', people: 62, st: '草稿', tagc: 'n', p: 0, bg: 'linear-gradient(135deg,#3A2F24,#8A6B3F)' }
  ];

  var CHAPTERS = [
    { n: '01', t: '课程导论与学习路径', d: '12:40', s: 'done', p: 100 },
    { n: '02', t: '网络协议与分层模型', d: '18:20', s: 'done', p: 100 },
    { n: '03', t: '容器网络与隔离', d: '22:05', s: 'doing', p: 62 },
    { n: '04', t: '访问控制与最小权限', d: '16:30', s: 'todo', p: 0 },
    { n: '05', t: '日志审计与追踪', d: '19:10', s: 'todo', p: 0 },
    { n: '06', t: '综合演练与复盘', d: '24:00', s: 'todo', p: 0 }
  ];

  function chapRows() {
    return CHAPTERS.map(function (c) {
      var tag = c.s === 'done' ? '<span class="tag g"><i class="dotm"></i>已完成</span>'
        : c.s === 'doing' ? '<span class="tag b"><i class="dotm"></i>进行中</span>'
        : '<span class="tag n">未开始</span>';
      return '<div class="chrow' + (c.s === 'doing' ? ' now' : '') + '" data-n="' + c.n + '">' +
        '<span class="cno">' + c.n + '</span>' +
        '<span class="ctt">' + c.t + '</span>' +
        '<span class="cdur mono">' + c.d + '</span>' +
        '<span class="cpg"><i style="width:' + c.p + '%"></i></span>' +
        '<span class="cst">' + tag + '</span></div>';
    }).join('');
  }

  function money(n) { return String(n).replace(/\B(?=(\d{3})+(?!\d))/g, ','); }

  /* ---------- scenes ---------- */
  var DEFS = {};

  /* ===== 01 片头 ===== */
  DEFS.intro = {
    shell: false,
    build: function (root) {
      root.innerHTML =
        '<div class="bleed dark">' +
          '<div class="gridbg"></div>' +
          '<div class="glow" style="left:-160px;top:-220px;width:680px;height:680px;background:#2E6BD0"></div>' +
          '<div class="glow" style="right:-120px;bottom:-260px;width:760px;height:760px;background:#1B4A80"></div>' +
          '<div class="i-wrap">' +
            '<div class="i-kick"><span class="ln"></span>警院 WeChat 全生态 · 平台功能演示</div>' +
            '<h1 class="i-h1">自学平台</h1>' +
            '<div class="i-en">SELF-LEARNING PLATFORM</div>' +
            '<div class="i-rule"></div>' +
            '<p class="i-sub">课程与学习记录的权威来源</p>' +
            '<div class="i-chips">' +
              '<span class="i-chip">统一身份 · OIDC / BFF</span>' +
              '<span class="i-chip">权威数据 · 课程与学习记录</span>' +
              '<span class="i-chip">事件联动 · course.completed</span>' +
            '</div>' +
          '</div>' +
          '<svg class="i-mark" width="420" height="470" viewBox="0 0 20 22" fill="none">' +
            '<path d="M3 5.2 10 2.4l7 2.8v6.1c0 3.3-3 5.8-7 6.5-4-.7-7-3.2-7-6.5V5.2Z" stroke="#7FA9E0" stroke-width=".5" stroke-linejoin="round"/>' +
            '<path d="M7 9.6l2.1 2.1L13.4 7.4" stroke="#7FA9E0" stroke-width=".5" stroke-linecap="round" stroke-linejoin="round"/>' +
          '</svg>' +
          '<div class="i-foot"><span>依据《五平台前端与功能联动约束规范 V2.0》</span><span class="mono">1920 × 1080 · 演示数据</span></div>' +
        '</div>';
      var w = $('.i-wrap', root), kick = $('.i-kick', root), h1 = $('.i-h1', root),
          en = $('.i-en', root), rule = $('.i-rule', root), sub = $('.i-sub', root),
          chips = $$('.i-chip', root), grid = $('.gridbg', root), foot = $('.i-foot', root);
      return function (p) {
        var a = eo(st(p, .02, .16));
        S(kick, { opacity: a, transform: 'translateY(' + (1 - a) * 12 + 'px)' });
        var b = eo(st(p, .06, .26));
        S(h1, { opacity: b, transform: 'translateY(' + (1 - b) * 22 + 'px)', letterSpacing: (6 + (1 - b) * 10) + 'px' });
        var c = eo(st(p, .14, .3));
        S(en, { opacity: c * .8 });
        S(rule, { width: (c * 320) + 'px', opacity: c });
        var d = eo(st(p, .2, .38));
        S(sub, { opacity: d, transform: 'translateY(' + (1 - d) * 14 + 'px)' });
        chips.forEach(function (el, i) {
          var k = eo(st(p, .3 + i * .05, .44 + i * .05));
          S(el, { opacity: k, transform: 'translateY(' + (1 - k) * 12 + 'px)' });
        });
        S(foot, { opacity: eo(st(p, .5, .6)) * .75 });
        grid.style.transform = 'translate(' + (-p * 30) + 'px,' + (-p * 22) + 'px)';
        w.style.transform = 'translateY(' + (-p * 6) + 'px)';
      };
    }
  };

  /* ===== 02 统一身份 ===== */
  DEFS.sso = {
    shell: true, nav: null, role: 'student',
    url: 'sso.campus.edu.cn/oauth2/authorize?client_id=learning-web',
    crumb: ['统一身份', '登录'],
    hint: '正在登录…',
    build: function (root) {
      root.innerHTML =
        '<div class="sso">' +
          '<div class="sso-l card">' +
            '<div class="sso-brand">' +
              '<div class="mk"><svg width="30" height="30" viewBox="0 0 20 20" fill="none"><path d="M3 5.2 10 2.4l7 2.8v6.1c0 3.3-3 5.8-7 6.5-4-.7-7-3.2-7-6.5V5.2Z" stroke="#fff" stroke-width="1.3" stroke-linejoin="round"/><path d="M7 9.6l2.1 2.1L13.4 7.4" stroke="#fff" stroke-width="1.3" stroke-linecap="round" stroke-linejoin="round"/></svg></div>' +
              '<div><div class="bt">论坛身份中心</div><div class="bs">统一身份认证 · OIDC Provider</div></div>' +
            '</div>' +
            '<div class="sso-par">' +
              '<div class="ph">授权请求参数</div>' +
              '<div class="pr"><span>client_id</span><b class="mono">learning-web</b></div>' +
              '<div class="pr"><span>response_type</span><b class="mono">code</b></div>' +
              '<div class="pr"><span>scope</span><b class="mono">openid profile</b></div>' +
              '<div class="pr"><span>state / nonce</span><b class="mono">st_9f2c… / n_71ab…</b></div>' +
              '<div class="pr"><span>code_challenge</span><b class="mono">S256 · PKCE</b></div>' +
              '<div class="pr"><span>redirect_uri</span><b class="mono">learning.campus.edu.cn/bff/cb</b></div>' +
            '</div>' +
            '<div class="sso-note"><i class="dotm"></i>仅授权码模式；重定向地址精确白名单；全链路 TLS</div>' +
            '<div class="sso-flow">' +
              '<div class="sf"><b>1</b>授权码请求 · state / nonce / PKCE S256</div>' +
              '<div class="sf"><b>2</b>BFF 服务端用授权码换取令牌</div>' +
              '<div class="sf"><b>3</b>仅下发 HttpOnly 会话 Cookie</div>' +
            '</div>' +
          '</div>' +

          '<div class="sso-right">' +
          '<div class="sso-r card" id="loginCard">' +
            '<div class="lc-h"><div class="t">登录自学平台</div><div class="s">使用警院统一账号</div></div>' +
            '<div class="fld"><span class="lb">学号 / 工号</span><div class="ipt"><span id="acc"></span><i class="caret" id="c1"></i></div></div>' +
            '<div class="fld"><span class="lb">密码</span><div class="ipt"><span id="pwd" class="mono"></span><i class="caret" id="c2" style="opacity:0"></i></div></div>' +
            '<div class="lrow"><span class="ck on"></span><span>记住登录状态</span><span class="lk">忘记密码</span></div>' +
            '<button class="btn p lg" id="btnLogin" style="width:100%;justify-content:center">登 录</button>' +
            '<div class="lfoot">登录即表示同意《账号使用规范》</div>' +
            '<div class="lspin" id="spin"><span class="sp"></span><span id="spinTx">正在跳转身份中心…</span></div>' +
          '</div>' +

          '<div class="sso-r card sso-id" id="idCard">' +
            '<div class="lc-h"><div class="t">授权成功</div><div class="s">已返回原路径 /course/list</div></div>' +
            '<div class="idchips">' +
              '<span class="tag b">sub = userId</span><span class="tag g">roles: student</span><span class="tag n">accountStatus: active</span>' +
            '</div>' +
            '<div class="code" id="idcode"></div>' +
            '<div class="idfoot">浏览器：无 Access / Refresh Token · Cookie：HttpOnly; Secure; SameSite=Lax</div>' +
          '</div>' +
          '</div>' +
        '</div>' +
        '<div class="toast" id="toast"><span class="ti">✓</span><span>BFF 会话已建立 · 已回到原路径 /course/list</span></div>';

      var acc = $('#acc', root), pwd = $('#pwd', root), c1 = $('#c1', root), c2 = $('#c2', root),
          btn = $('#btnLogin', root), spin = $('#spin', root), spinTx = $('#spinTx', root),
          loginCard = $('#loginCard', root), idCard = $('#idCard', root), idcode = $('#idcode', root),
          toast = $('#toast', root), ssoL = $('.sso-l', root);

      var idHTML =
        '<span class="p">{</span>\n' +
        '  <span class="k">"sub"</span><span class="p">:</span> <span class="s">"usr_01J7Q2M8"</span><span class="p">,</span>\n' +
        '  <span class="k">"userId"</span><span class="p">:</span> <span class="s">"usr_01J7Q2M8"</span><span class="p">,</span>\n' +
        '  <span class="k">"studentNo"</span><span class="p">:</span> <span class="s">"20260001"</span><span class="p">,</span>\n' +
        '  <span class="k">"realName"</span><span class="p">:</span> <span class="s">"王立军"</span><span class="p">,</span>\n' +
        '  <span class="k">"roles"</span><span class="p">:</span> <span class="p">[</span><span class="s">"student"</span><span class="p">],</span>\n' +
        '  <span class="k">"permissions"</span><span class="p">:</span> <span class="p">[</span><span class="s">"course:read"</span><span class="p">,</span> <span class="s">"record:write"</span><span class="p">],</span>\n' +
        '  <span class="k">"classId"</span><span class="p">:</span> <span class="s">"class_2026_03"</span><span class="p">,</span>\n' +
        '  <span class="k">"accountStatus"</span><span class="p">:</span> <span class="s">"active"</span>\n' +
        '<span class="p">}</span>';
      idcode.innerHTML = idHTML;
      var idLines = $$('.code .k', idcode).length;

      return function (p, tl) {
        S(ssoL, { opacity: eo(st(p, .0, .1)), transform: 'translateX(' + (1 - eo(st(p, .0, .1))) * -16 + 'px)' });
        var lcIn = eo(st(p, .04, .16));
        S(loginCard, { opacity: lcIn, transform: 'translateY(' + (1 - lcIn) * 18 + 'px)' });

        // 输入账号
        var q1 = st(p, .12, .26);
        acc.textContent = '20260001'.slice(0, Math.round(q1 * 8));
        S(c1, { opacity: q1 < 1 ? 1 : 0 });
        var q2 = st(p, .27, .38);
        pwd.textContent = q2 > 0 ? new Array(Math.round(q2 * 8) + 1).join('•') : '';
        S(c2, { opacity: q2 > 0 && q2 < 1 ? 1 : 0 });

        // 点击登录
        var press = st(p, .39, .42) * (1 - st(p, .44, .47));
        S(btn, { transform: 'scale(' + (1 - press * .04) + ')', background: press > .1 ? '#1A458F' : '#1E4FA8' });
        var sp = eo(st(p, .44, .5));
        S(spin, { opacity: sp, transform: 'translateY(' + (1 - sp) * 8 + 'px)' });
        spinTx.textContent = p < .52 ? '正在校验账号…' : (p < .6 ? '正在交换授权码…' : '会话已建立');

        // 切换到身份结果
        var out = eo(st(p, .52, .58));
        S(loginCard, { opacity: lcIn * (1 - out), transform: 'translateY(' + (-out * 12) + 'px)' });
        var inc = eo(st(p, .55, .64));
        S(idCard, { opacity: inc, transform: 'translateY(' + (1 - inc) * 16 + 'px)' });

        // 身份字段逐行显现
        var nl = Math.floor(st(p, .6, .78) * idLines);
        var ks = $$('.code .k', idcode);
        ks.forEach(function (k, i) { k.style.opacity = i < nl ? 1 : .18; });

        var tt = eo(st(p, .84, .9));
        S(toast, { opacity: tt, transform: 'translateY(' + (12 - tt * 12) + 'px)' });
      };
    }
  };

  /* ===== 03 课程目录 ===== */
  DEFS.catalog = {
    shell: true, nav: 'catalog', role: 'student',
    url: 'learning.campus.edu.cn/course/list',
    crumb: ['教学空间', '课程目录'],
    hint: '网络安全',
    build: function (root) {
      var cardsA = COURSES.map(card).join('');

      root.innerHTML =
        '<div class="phead">' +
          '<div><h2>课程目录</h2><div class="desc">共 47 门课程 · 服务端分页 · 每页 20 条上限 100 条</div></div>' +
          '<div class="r"><span class="api">GET /api/v1/learning/courses?page=1&amp;pageSize=20</span></div>' +
        '</div>' +
        '<div class="fbar">' +
          '<div class="tabs">' +
            '<span class="tab on">全部</span><span class="tab">网络安全</span><span class="tab">数据库</span>' +
            '<span class="tab">云原生</span><span class="tab">人工智能</span><span class="tab">数据分析</span>' +
          '</div>' +
          '<div class="sinput"><svg width="14" height="14" viewBox="0 0 14 14" fill="none"><circle cx="6.2" cy="6.2" r="4.3" stroke="#9AA7B8" stroke-width="1.3"/><path d="m9.6 9.6 2.4 2.4" stroke="#9AA7B8" stroke-width="1.3" stroke-linecap="round"/></svg><span id="q" class="ph">搜索课程、教师或资源</span><i class="caret" id="qc"></i></div>' +
        '</div>' +
        '<div class="gridwrap">' +
          '<div class="grid" id="gridA">' + cardsA + '</div>' +
          '<div class="loadgrid" id="loadgrid">' +
            '<div class="sk"><div class="skc"></div><div class="skt"></div><div class="sks"></div></div>' +
            '<div class="sk"><div class="skc"></div><div class="skt"></div><div class="sks"></div></div>' +
            '<div class="sk"><div class="skc"></div><div class="skt"></div><div class="sks"></div></div>' +
            '<div class="sk"><div class="skc"></div><div class="skt"></div><div class="sks"></div></div>' +
          '</div>' +
          '<div class="gwrapB" id="gridB">' +
            '<div class="resbar"><span class="tag b">搜索结果</span><span>“网络安全” · 匹配 12 门 · 按最近更新时间排序</span><span class="api" style="margin-left:auto">page=1 pageSize=20 total=12</span></div>' +
            '<div class="grid">' + card(COURSES[0]) + card(COURSES[5]) + card(COURSES[7]) + '</div>' +
          '</div>' +
        '</div>' +
        '<div class="pg"><span class="pgc">共 47 门</span><span class="pgn on">1</span><span class="pgn">2</span><span class="pgn">3</span><span class="pgd">…</span><span class="pgn">5</span><span class="pga">每页 20 条</span></div>';

      var gridA = $('#gridA', root), gridB = $('#gridB', root), loadgrid = $('#loadgrid', root),
          cards = $$('.ccard', gridA), q = $('#q', root), qc = $('#qc', root),
          tabs = $$('.tab', root), hint = $('#hintText'), pg = $('.pg', root);
      var bcards = $$('.ccard', gridB);

      return function (p, tl, ctx) {
        var inA = eo(st(p, 0, .12));
        S(gridA, { opacity: inA });
        cards.forEach(function (el, i) {
          var k = eo(st(p, .04 + i * .018, .18 + i * .018));
          S(el, { opacity: k, transform: 'translateY(' + (1 - k) * 16 + 'px)' });
        });

        // 搜索输入
        var typed = st(p, .2, .34);
        var text = '网络安全'.slice(0, Math.round(typed * 4));
        q.textContent = text || '搜索课程、教师或资源';
        q.className = text ? '' : 'ph';
        S(qc, { opacity: typed > 0 && typed < 1 ? 1 : 0 });
        S(hint, { opacity: 1 });

        // 回车 -> 加载 -> 结果
        var ld = eo(st(p, .38, .44)) * (1 - st(p, .5, .56));
        S(loadgrid, { opacity: ld, transform: 'translateY(' + (1 - ld) * 10 + 'px)', display: ld > .01 ? 'grid' : 'none' });
        S(gridA, { opacity: inA * (1 - eo(st(p, .38, .44))) });

        var inB = eo(st(p, .54, .66));
        S(gridB, { opacity: inB, transform: 'translateY(' + (1 - inB) * 14 + 'px)' });

        tabs[1].className = 'tab' + (p > .5 ? ' on' : '');
        tabs[0].className = 'tab' + (p > .5 ? '' : ' on');

        // 悬停 + 点击第一张卡
        var hv = eo(st(p, .74, .8)) * (1 - st(p, .94, 1));
        var target = bcards[0] ? center(bcards[0]) : { x: 700, y: 500 };
        if (bcards[0]) {
          S(bcards[0], {
            transform: 'translateY(' + (-hv * 5) + 'px) scale(' + (1 + hv * .012) + ')',
            boxShadow: hv > .02 ? '0 12px 30px rgba(20,48,95,' + (.10 + hv * .09) + ')' : '0 1px 2px rgba(16,35,70,.05)',
            borderColor: hv > .5 ? '#BFD4F2' : '#E3E8F0'
          });
        }
        S(pg, { opacity: eo(st(p, .58, .7)) });

        // 光标
        ctx.cursor(p, [
          { p: .18, x: 1500, y: 560 },
          { p: .24, x: 1436, y: 214 },
          { p: .5, x: 1436, y: 214 },
          { p: .72, x: target.x - 160, y: target.y + 30 },
          { p: .86, x: target.x, y: target.y },
          { p: .96, x: target.x, y: target.y, click: true }
        ]);
      };
    }
  };

  /* ===== 04 课程详情 ===== */
  DEFS.detail = {
    shell: true, nav: 'catalog', role: 'student',
    url: 'learning.campus.edu.cn/course/course_01J8F2',
    crumb: ['课程目录', '网络安全基础'],
    build: function (root) {
      root.innerHTML =
        '<div class="det">' +
          '<div class="det-l">' +
            '<div class="dhero card">' +
              '<div class="dhcover" style="background:linear-gradient(135deg,#1F3A5F,#2E5FA8)"><div class="pat"></div><div class="dhc">course_01J8F2</div></div>' +
              '<div class="dhbody">' +
                '<div class="dhtop"><h2>网络安全基础</h2><span class="tag g"><i class="dotm"></i>已发布</span></div>' +
                '<div class="dmeta">张海洋 · 网络空间安全教研室<span class="sp">|</span>16 学时<span class="sp">|</span>中级<span class="sp">|</span>更新于 2026-11-02</div>' +
                '<p class="dp">以分层模型为主线，覆盖访问控制、隔离与审计，配套 6 个可复现实验环境；完成后可参加结课测验。</p>' +
                '<div class="dhbtns"><button class="btn p" id="goOn">继续学习（第 3 章 · 62%）</button><button class="btn">下载课程大纲</button><span class="api">courseId = course_01J8F2</span></div>' +
              '</div>' +
            '</div>' +
            '<div class="dcard card">' +
              '<div class="dch"><b>课程章节</b><span>6 章 · 总时长 1:52:45</span></div>' +
              chapRows() +
              '<div class="dfoot"><span>已完成 2 章 · 进行中 1 章</span><span>学习进度由服务端保存，换设备可续学</span></div>' +
            '</div>' +
          '</div>' +
          '<div class="det-r">' +
            '<div class="card rcard">' +
              '<div class="rch">我的学习进度</div>' +
              '<div class="ringwrap">' +
                '<svg width="150" height="150" viewBox="0 0 150 150">' +
                  '<circle cx="75" cy="75" r="62" fill="none" stroke="#EDF1F7" stroke-width="11"/>' +
                  '<circle id="arc" cx="75" cy="75" r="62" fill="none" stroke="#1E4FA8" stroke-width="11" stroke-linecap="round" stroke-dasharray="389.6" stroke-dashoffset="389.6" transform="rotate(-90 75 75)"/>' +
                '</svg>' +
                '<div class="ringtx"><b id="pct">0%</b><span>已完成</span></div>' +
              '</div>' +
              '<div class="rstats"><div><b>6</b><span>/ 16 学时</span></div><div><b>2</b><span>/ 6 章</span></div></div>' +
              '<div class="rlast">上次学习<br><b>第 3 章 · 容器网络与隔离</b><span class="mono">2026-11-04 21:18</span></div>' +
            '</div>' +
            '<div class="card fcard">' +
              '<div class="rch">LearningRecord <span class="specref">规范 §7.2</span></div>' +
              '<div class="code" id="reccode" style="font-size:11.5px"></div>' +
            '</div>' +
          '</div>' +
        '</div>';

      var arc = $('#arc', root), pct = $('#pct', root), rows = $$('.chrow', root),
          goOn = $('#goOn', root), rec = $('#reccode', root), card2 = $('.fcard', root);

      var recLines = [
        'recordId   : "rec_01J8F2K9"',
        'userId     : "usr_01J7Q2M8"',
        'courseId   : "course_01J8F2"',
        'progress   : 42',
        'completedAt: null',
        'status     : "in_progress"'
      ];
      rec.innerHTML = recLines.map(function (l) {
        return '<div class="rl"><span class="k">' + l.split(':')[0] + '</span><span class="p">:</span> <span class="' + (/null/.test(l) ? 'n' : 's') + '">' + l.split(':').slice(1).join(':').trim() + '</span></div>';
      }).join('');

      return function (p, tl, ctx) {
        var a = eo(st(p, 0, .1));
        S($('.det-l', root), { opacity: a, transform: 'translateY(' + (1 - a) * 14 + 'px)' });
        S($('.det-r', root), { opacity: eo(st(p, .06, .16)), transform: 'translateY(' + (1 - eo(st(p, .06, .16))) * 16 + 'px)' });

        var pr = 42 * eo(st(p, .12, .34));
        arc.setAttribute('stroke-dashoffset', String(389.6 * (1 - pr / 100)));
        pct.textContent = Math.round(pr) + '%';

        rows.forEach(function (r, i) {
          var k = eo(st(p, .14 + i * .03, .26 + i * .03));
          S(r, { opacity: k, transform: 'translateX(' + (1 - k) * 10 + 'px)' });
        });

        // 高亮进行中章节
        var hl = eo(st(p, .5, .56));
        S(rows[2], { background: hl > .05 ? 'rgba(30,79,168,' + (.05 + hl * .04) + ')' : 'transparent' });

        var pulse = 1 + Math.sin((tl / 1000) * 4) * .012 * st(p, .5, .58);
        S(goOn, { transform: 'scale(' + pulse + ')' });

        // 字段逐条高亮
        var ls = $$('.rl', rec);
        var idx = Math.floor(st(p, .6, .92) * ls.length);
        ls.forEach(function (el, i) {
          S(el, {
            opacity: i <= idx ? 1 : .3,
            background: i === idx ? 'rgba(61,123,217,.25)' : 'transparent',
            borderRadius: '3px'
          });
        });

        ctx.cursor(p, [
          { p: .34, x: 1640, y: 610 },
          { p: .48, x: center(goOn).x, y: center(goOn).y },
          { p: .6, x: center(goOn).x, y: center(goOn).y },
          { p: .74, x: center(card2).x - 120, y: center(card2).y + 30 },
          { p: 1, x: center(card2).x - 40, y: center(card2).y + 60 }
        ]);
      };
    }
  };

  /* ===== 05 学习页 ===== */
  DEFS.learn = {
    shell: true, nav: 'mine', role: 'student',
    url: 'learning.campus.edu.cn/learn/course_01J8F2/chapter/03',
    crumb: ['我的学习', '网络安全基础', '第 3 章'],
    build: function (root) {
      root.innerHTML =
        '<div class="lp">' +
          '<div class="lp-l">' +
            '<div class="player">' +
              '<div class="pbg"></div>' +
              '<div class="pttl"><span class="pn">第 3 章</span><b>容器网络与隔离</b><span class="ps">03 / 06 · 22:05</span></div>' +
              '<div class="pbig" id="pbig"><svg width="74" height="74" viewBox="0 0 74 74"><circle cx="37" cy="37" r="36" fill="rgba(255,255,255,.14)" stroke="rgba(255,255,255,.55)"/><path d="M30 24.5 53 37 30 49.5V24.5Z" fill="#fff"/></svg></div>' +
              '<div class="pctl">' +
                '<div class="pline"><i id="pfill"></i></div>' +
                '<div class="prow">' +
                  '<span class="pbtn">▶</span><span class="ptime mono"><b id="tnow">00:00</b> / 22:05</span>' +
                  '<span class="pspd">1.0×</span><span class="pspd">高清 1080P</span>' +
                  '<span class="pvol">🔊</span><span class="pfull">⛶</span>' +
                '</div>' +
              '</div>' +
            '</div>' +
            '<div class="res card">' +
              '<div class="resh"><b>本章资源</b><span>文件服务返回 fileId，私有资源需鉴权下载</span></div>' +
              '<div class="reslist">' +
                '<div class="resrow"><span class="fico">PDF</span><div class="rinfo"><b>容器网络课件.pdf</b><span>4.2 MB · fileId file_01J8V3</span></div><span class="fbtn">下载</span></div>' +
                '<div class="resrow"><span class="fico z">ZIP</span><div class="rinfo"><b>实验环境与案例包.zip</b><span>126 MB · fileId file_01J8V7</span></div><span class="fbtn">下载</span></div>' +
                '<div class="resrow"><span class="fico c">CSV</span><div class="rinfo"><b>抓包明细.csv</b><span>2.8 MB · fileId file_01J8W1</span></div><span class="fbtn">下载</span></div>' +
              '</div>' +
            '</div>' +
          '</div>' +
          '<div class="lp-r card">' +
            '<div class="lrh"><b>章节目录</b><span>6 章</span></div>' +
            '<div class="chlist">' +
              CHAPTERS.map(function (c, i) {
                return '<div class="chitem' + (i === 2 ? ' now' : '') + (c.s === 'done' ? ' done' : '') + '">' +
                  '<span class="ci">' + (c.s === 'done' ? '✓' : c.n) + '</span>' +
                  '<div class="cm"><div class="ct">' + c.t + '</div><div class="cd">' + c.d + (c.s === 'doing' ? ' · 已学 13:41' : '') + '</div></div>' +
                  (i === 2 ? '<span class="eq"><i></i><i></i><i></i></span>' : '') +
                  '</div>';
              }).join('') +
            '</div>' +
            '<div class="lrfoot"><div class="sbar"><i style="width:62%"></i></div><span>本章 62% · 自动保存</span></div>' +
          '</div>' +
        '</div>' +
        '<div class="toast br" id="ltoast"><span class="ti">✓</span><span>进度已保存 <b class="mono">progress=58</b> · <b class="mono">requestId=req_01J9K2M</b></span></div>';

      var fill = $('#pfill', root), tnow = $('#tnow', root), pbig = $('#pbig', root),
          toast = $('#ltoast', root), eqs = $$('.eq i', root);

      return function (p, tl) {
        var a = eo(st(p, 0, .12));
        S($('.lp-l', root), { opacity: a, transform: 'translateY(' + (1 - a) * 14 + 'px)' });
        S($('.lp-r', root), { opacity: eo(st(p, .05, .18)), transform: 'translateX(' + (1 - eo(st(p, .05, .18))) * 16 + 'px)' });

        var play = eo(st(p, .12, .2));
        S(pbig, { opacity: 1 - play * .85, transform: 'scale(' + (1 - play * .08) + ')' });

        var prog = .18 + st(p, .1, 1) * .62;
        S(fill, { width: (prog * 100) + '%' });
        var sec = Math.round(prog * 1325);
        tnow.textContent = ('0' + Math.floor(sec / 60)).slice(-2) + ':' + ('0' + (sec % 60)).slice(-2);

        eqs.forEach(function (b, i) {
          var h = 5 + Math.abs(Math.sin(tl / 220 + i * 1.1)) * 12;
          b.style.height = h + 'px';
        });

        var tt = eo(st(p, .52, .58)) * (1 - st(p, .9, .97));
        S(toast, { opacity: tt, transform: 'translateY(' + (14 - tt * 14) + 'px)' });
      };
    }
  };

  /* ===== 06 完成课程与事件 ===== */
  DEFS.complete = {
    shell: true, nav: 'mine', role: 'student',
    url: 'learning.campus.edu.cn/learn/course_01J8F2/result',
    crumb: ['我的学习', '课程完成'],
    build: function (root) {
      root.innerHTML =
        '<div class="cmp">' +
          '<div class="cmp-l card">' +
            '<div class="okwrap"><svg width="96" height="96" viewBox="0 0 96 96">' +
              '<circle id="okc" cx="48" cy="48" r="43" fill="none" stroke="#1E9E63" stroke-width="3.4" stroke-linecap="round" stroke-dasharray="270" stroke-dashoffset="270" transform="rotate(-90 48 48)"/>' +
              '<path id="okp" d="M30 49.5 42.5 62 67 36" fill="none" stroke="#1E9E63" stroke-width="5" stroke-linecap="round" stroke-linejoin="round" stroke-dasharray="60" stroke-dashoffset="60"/>' +
            '</svg></div>' +
            '<div class="okt">课程已完成</div>' +
            '<div class="oks">网络安全基础 · course_01J8F2</div>' +
            '<div class="okstats">' +
              '<div><b>12 / 12</b><span>章节完成</span></div>' +
              '<div><b>16 h 40 m</b><span>累计学习</span></div>' +
              '<div><b>92</b><span>结课测验</span></div>' +
            '</div>' +
            '<div class="okrule"><b>完成规则</b><span>章节 100% · 学习时长 ≥ 90% · 测验 ≥ 80 分（规则版本 r3）</span></div>' +
            '<div class="okbtns"><button class="btn p lg" id="cert">生成学习证书</button><button class="btn lg">查看学习档案</button></div>' +
            '<div class="oknext"><span class="tag b">下游</span>结课测验已解锁 · 考试平台可在 1 秒内感知</div>' +
          '</div>' +

          '<div class="cmp-r">' +
            '<div class="evp">' +
              '<div class="evh"><span class="evdot"></span><b>事件封套</b><span class="evt mono">course.completed</span><span class="evv">v1.0</span></div>' +
              '<div class="code evcode" id="evcode"></div>' +
            '</div>' +
            '<div class="flow card">' +
              '<div class="flh"><b>投递链路</b><span>Transactional Outbox · 至少一次投递</span></div>' +
              '<div class="flowrow">' +
                '<div class="fstep"><i>1</i><b>本地事务</b><span>学习记录 + outbox</span></div>' +
                '<div class="farrow"><span id="fa1"></span></div>' +
                '<div class="fstep"><i>2</i><b>发布器</b><span>读取待发记录</span></div>' +
                '<div class="farrow"><span id="fa2"></span></div>' +
                '<div class="fstep"><i>3</i><b>事件代理</b><span>topic: learning.*</span></div>' +
                '<div class="farrow"><span id="fa3"></span></div>' +
                '<div class="fstep"><i>4</i><b>消费者</b><span>exam / archive</span></div>' +
              '</div>' +
              '<div class="fmbadges"><span class="tag g">eventId 全局唯一</span><span class="tag g">消费者按 eventId 去重</span><span class="tag b">失败指数退避 → 死信</span><span class="tag n">重放保留原 eventId</span></div>' +
            '</div>' +
          '</div>' +
        '</div>';

      var okc = $('#okc', root), okp = $('#okp', root), evcode = $('#evcode', root),
          arcs = [root.querySelector('#fa1'), root.querySelector('#fa2'), root.querySelector('#fa3')];

      var json =
        '<span class="p">{</span>\n' +
        '  <span class="k">"eventId"</span><span class="p">:</span> <span class="s">"evt_01J9K7WR2Q"</span><span class="p">,</span>\n' +
        '  <span class="k">"eventType"</span><span class="p">:</span> <span class="s">"course.completed"</span><span class="p">,</span>\n' +
        '  <span class="k">"eventVersion"</span><span class="p">:</span> <span class="s">"1.0"</span><span class="p">,</span>\n' +
        '  <span class="k">"occurredAt"</span><span class="p">:</span> <span class="s">"2026-11-05T09:42:11+08:00"</span><span class="p">,</span>\n' +
        '  <span class="k">"sourcePlatform"</span><span class="p">:</span> <span class="s">"learning"</span><span class="p">,</span>\n' +
        '  <span class="k">"sourceEntityId"</span><span class="p">:</span> <span class="s">"rec_01J8F2K9"</span><span class="p">,</span>\n' +
        '  <span class="k">"actorId"</span><span class="p">:</span> <span class="s">"usr_01J7Q2M8"</span><span class="p">,</span>\n' +
        '  <span class="k">"correlationId"</span><span class="p">:</span> <span class="s">"flow_01J9K7"</span><span class="p">,</span>\n' +
        '  <span class="k">"data"</span><span class="p">:</span> <span class="p">{</span>\n' +
        '    <span class="k">"userId"</span><span class="p">:</span> <span class="s">"usr_01J7Q2M8"</span><span class="p">,</span>\n' +
        '    <span class="k">"courseId"</span><span class="p">:</span> <span class="s">"course_01J8F2"</span><span class="p">,</span>\n' +
        '    <span class="k">"progress"</span><span class="p">:</span> <span class="n">100</span><span class="p">,</span>\n' +
        '    <span class="k">"completedAt"</span><span class="p">:</span> <span class="s">"2026-11-05T09:42:10+08:00"</span>\n' +
        '  <span class="p">}</span>\n' +
        '<span class="p">}</span>';
      evcode.innerHTML = json;
      var chars = [];
      (function walk(node) {
        Array.prototype.slice.call(node.childNodes).forEach(function (n) {
          if (n.nodeType === 3) {
            var frag = document.createDocumentFragment();
            Array.prototype.slice.call(n.textContent).forEach(function (ch) {
              var sp = document.createElement('span');
              sp.textContent = ch;
              sp.style.opacity = '0';
              frag.appendChild(sp);
              chars.push(sp);
            });
            node.replaceChild(frag, n);
          } else walk(n);
        });
      })(evcode);

      var shown = 0;
      return function (p, tl) {
        var a = eo(st(p, 0, .1));
        S($('.cmp-l', root), { opacity: a, transform: 'translateY(' + (1 - a) * 16 + 'px)' });
        S($('.cmp-r', root), { opacity: eo(st(p, .12, .24)), transform: 'translateX(' + (1 - eo(st(p, .12, .24))) * 18 + 'px)' });

        okc.setAttribute('stroke-dashoffset', String(270 * (1 - eio(st(p, .08, .3)))));
        okp.setAttribute('stroke-dashoffset', String(60 * (1 - eio(st(p, .24, .36)))));

        var n = Math.floor(st(p, .3, .72) * chars.length);
        if (n > shown) { for (var i = shown; i < n; i++) chars[i].style.opacity = '1'; shown = n; }
        else if (n < shown) { for (var j = n; j < shown; j++) chars[j].style.opacity = '0'; shown = n; }

        var f1 = eio(st(p, .74, .8)), f2 = eio(st(p, .8, .86)), f3 = eio(st(p, .86, .92));
        [f1, f2, f3].forEach(function (v, i) {
          var el = arcs[i];
          if (!el) return;
          el.style.width = (v * 46) + 'px';
          el.style.opacity = v > .02 ? 1 : 0;
          el.parentNode.style.position = 'relative';
        });
        S($('.fmbadges', root), { opacity: eo(st(p, .9, .98)) });
      };
    }
  };

  /* ===== 07 考试准入 ===== */
  DEFS.admit = {
    shell: true, nav: 'mine', role: 'student',
    url: 'exam.campus.edu.cn/exam/exam_01J9A2/admission',
    crumb: ['跨平台', '考试平台', '准入校验'],
    build: function (root) {
      root.innerHTML =
        '<div class="ad">' +
          '<div class="ad-l card">' +
            '<div class="adh"><div class="adht"><span class="tag b">考试平台</span><b>网络安全基础 · 结课测验</b></div><span class="tag o">待开始</span></div>' +
            '<div class="admeta">exam_01J9A2 · 60 分钟 · 50 题 · 通过线 80 分 · 规则版本 v1.2</div>' +
            '<div class="adcond">' +
              '<div class="adch">准入条件校验</div>' +
              '<div class="cond" id="c1"><span class="ck"></span><div class="cc"><b>课程已完成</b><span>来源 learning · evt_01J9K7WR2Q</span></div><span class="csrc">course.completed</span></div>' +
              '<div class="cond" id="c2"><span class="ck"></span><div class="cc"><b>学习时长达标</b><span>16 h 40 m ≥ 90% 课时</span></div><span class="csrc">learning.record</span></div>' +
              '<div class="cond" id="c3"><span class="ck"></span><div class="cc"><b>规则版本匹配</b><span>v1.2 · 2026-10-20 生效</span></div><span class="csrc">exam.rules</span></div>' +
            '</div>' +
            '<div class="adnotes">' +
              '<div class="an"><b>考试范围</b><span>第 1–6 章 · 50 题 · 单选 30 / 多选 10 / 案例 10</span></div>' +
              '<div class="an"><b>作答规则</b><span>60 分钟 · 允许 1 次 · 交卷即出分 · 通过线 80 分</span></div>' +
              '<div class="an"><b>成绩去向</b><span>本平台权威 · 通过后发 exam.passed 供工坊准入消费</span></div>' +
            '</div>' +
            '<div class="adfoot"><button class="btn p lg" id="startBtn">校验中…</button><span class="adr mono" id="reqid">GET /api/v1/learning/records/recent?courseId=course_01J8F2</span></div>' +
          '</div>' +

          '<div class="ad-r">' +
            '<div class="card seq">' +
              '<div class="sech"><b>同步查询</b><span>准入判定必须立即得到答案</span></div>' +
              '<div class="seqrow">' +
                '<div class="sq"><i>student</i><b>浏览器</b></div>' +
                '<span class="sar" id="s1"></span>' +
                '<div class="sq"><i>bff</i><b>考试 BFF</b></div>' +
                '<span class="sar" id="s2"></span>' +
                '<div class="sq"><i>learning</i><b>自学平台 API</b></div>' +
              '</div>' +
              '<div class="seqnote">令牌在服务端持有；浏览器只带会话 Cookie；单次调用总超时 ≤ 3s</div>' +
            '</div>' +
            '<div class="card proj">' +
              '<div class="sech"><b>本地投影</b><span class="tag g">已同步</span></div>' +
              '<div class="projrow"><span>userId</span><b class="mono">usr_01J7Q2M8</b></div>' +
              '<div class="projrow"><span>courseId</span><b class="mono">course_01J8F2</b></div>' +
              '<div class="projrow"><span>progress</span><b class="mono">100</b></div>' +
              '<div class="projrow"><span>sourceEventId</span><b class="mono">evt_01J9K7WR2Q</b></div>' +
              '<div class="projnote"><i class="dotm"></i>投影延迟时回源查询，不以过期缓存拒绝用户</div>' +
            '</div>' +
          '</div>' +
        '</div>';

      var conds = [root.querySelector('#c1'), root.querySelector('#c2'), root.querySelector('#c3')],
          btn = $('#startBtn', root), s1 = root.querySelector('#s1'), s2 = root.querySelector('#s2');

      return function (p, tl) {
        var a = eo(st(p, 0, .1));
        S($('.ad-l', root), { opacity: a, transform: 'translateY(' + (1 - a) * 14 + 'px)' });
        S($('.ad-r', root), { opacity: eo(st(p, .06, .18)), transform: 'translateX(' + (1 - eo(st(p, .06, .18))) * 16 + 'px)' });

        var times = [.14, .26, .38];
        conds.forEach(function (c, i) {
          var k = eio(st(p, times[i], times[i] + .1));
          var ck = $('.ck', c);
          ck.style.background = k > .4 ? '#1E9E63' : '#fff';
          ck.style.borderColor = k > .4 ? '#1E9E63' : '#CBD5E3';
          ck.innerHTML = k > .55 ? '<svg width="10" height="8" viewBox="0 0 10 8"><path d="M1 4.2 3.6 6.8 9 1.4" fill="none" stroke="#fff" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round"/></svg>' : '';
          S(c, { opacity: .45 + k * .55, background: k > .5 ? 'rgba(30,158,99,' + (.04 + k * .03) + ')' : '#fff' });
        });

        s1.style.width = (eio(st(p, .5, .58)) * 74) + 'px';
        s2.style.width = (eio(st(p, .58, .68)) * 74) + 'px';
        s1.style.opacity = s2.style.opacity = .85;

        var ok = st(p, .42, .48);
        btn.textContent = ok > .5 ? '开始考试（已具备准入资格）' : '校验中…';
        btn.style.background = ok > .5 ? '#1E9E63' : '#9AA7B8';
        btn.style.borderColor = ok > .5 ? '#1E9E63' : '#9AA7B8';
        btn.style.boxShadow = ok > .5 ? '0 4px 14px rgba(30,158,99,.28)' : 'none';
        btn.style.transform = 'scale(' + (1 + Math.sin(tl / 600) * .008 * ok) + ')';

        S($('.projnote', root), { opacity: eo(st(p, .72, .84)) });
        S($('.adr', root), { opacity: eo(st(p, .8, .92)) * .8 });
      };
    }
  };

  /* ===== 08 教师端 ===== */
  DEFS.teacher = {
    shell: true, nav: 'teach', role: 'teacher',
    url: 'learning.campus.edu.cn/teach/courses',
    crumb: ['教学管理', '课程与学情'],
    build: function (root) {
      var rows = [
        ['网络安全基础', 'course_01J8F2', '已发布', 'g', '128', '63%', '11-02 14:20'],
        ['内网攻防演练', 'course_01J8K6', '已发布', 'g', '43', '38%', '11-01 09:05'],
        ['电子数据取证入门', 'course_01J8N8', '草稿', 'n', '—', '—', '10-30 16:42'],
        ['数据库原理与应用', 'course_01J8G7', '已发布', 'g', '96', '71%', '10-28 10:11'],
        ['容器与云原生实践', 'course_01J8H1', '已发布', 'g', '74', '55%', '10-25 15:33'],
        ['目标检测实战', 'course_01J8H9', '已归档', 'o', '51', '88%', '09-18 11:07'],
        ['Python 数据分析', 'course_01J8M2', '已发布', 'g', '167', '44%', '09-12 14:26'],
        ['数据结构与算法', 'course_01J8J3', '已发布', 'g', '210', '76%', '09-05 08:50']
      ].map(function (r) {
        return '<tr><td><span class="b">' + r[0] + '</span><div class="sub mono">' + r[1] + '</div></td>' +
          '<td><span class="tag ' + r[3] + '">' + r[2] + '</span></td>' +
          '<td>' + r[4] + '</td><td>' + r[5] + '</td><td class="mono">' + r[6] + '</td>' +
          '<td><span class="lnk">编辑</span><span class="lnk">上架</span></td></tr>';
      }).join('');

      root.innerHTML =
        '<div class="phead">' +
          '<div><h2>教学管理</h2><div class="desc">张海洋 · 教师 · 权限点 course:read / course:create / course:update / course:publish</div></div>' +
          '<div class="r"><button class="btn" id="newc">+ 新建课程</button><button class="btn p" id="upbtn">上传资源</button></div>' +
        '</div>' +
        '<div class="tch">' +
          '<div class="tch-l card">' +
            '<div class="tblh"><b>我的课程</b><span>共 6 门 · 状态 draft / published / archived</span></div>' +
            '<table class="tbl"><thead><tr><th>课程</th><th>状态</th><th>报名</th><th>平均进度</th><th>更新时间</th><th>操作</th></tr></thead><tbody id="tb">' + rows + '</tbody></table>' +
          '</div>' +
          '<div class="tch-r">' +
            '<div class="card stat">' +
              '<div class="tblh"><b>学情分布</b><span>网络安全基础</span></div>' +
              '<div class="bars">' +
                '<div class="brow"><span>75–100%</span><div class="bt"><i id="b1"></i></div><b id="n1">0</b></div>' +
                '<div class="brow"><span>50–75%</span><div class="bt"><i id="b2"></i></div><b id="n2">0</b></div>' +
                '<div class="brow"><span>25–50%</span><div class="bt"><i id="b3"></i></div><b id="n3">0</b></div>' +
                '<div class="brow"><span>0–25%</span><div class="bt"><i id="b4"></i></div><b id="n4">0</b></div>' +
              '</div>' +
              '<div class="statfoot"><div><b id="rate">0%</b><span>课程完成率</span></div><div><b>128</b><span>在学人数</span></div></div>' +
            '</div>' +
            '<div class="card upl" id="upl">' +
              '<div class="tblh"><b>资源上传</b><span class="tag n">分片 8 MB</span></div>' +
              '<div class="upname"><span class="fico z">ZIP</span><div><b>实验环境_v3.zip</b><span>126.4 MB · 待写入 fileId</span></div></div>' +
              '<div class="upbar"><i id="upfill"></i></div>' +
              '<div class="upfoot"><span id="uptx">等待上传</span><span class="mono" id="uppct">0%</span></div>' +
            '</div>' +
          '</div>' +
        '</div>' +
        '<div class="toast" id="ttoast"><span class="ti">✓</span><span>已创建课程草稿 <b class="mono">course_01J9P3</b> · requestId=req_01J9M4T</span></div>';

      var trs = $$('#tb tr', root), toast = $('#ttoast', root),
          b1 = $('#b1', root), b2 = $('#b2', root), b3 = $('#b3', root), b4 = $('#b4', root),
          n1 = $('#n1', root), n2 = $('#n2', root), n3 = $('#n3', root), n4 = $('#n4', root),
          upfill = $('#upfill', root), uptx = $('#uptx', root), uppct = $('#uppct', root),
          rate = $('#rate', root), newc = $('#newc', root), upbtn = $('#upbtn', root);

      return function (p, tl, ctx) {
        trs.forEach(function (tr, i) {
          var k = eo(st(p, .04 + i * .026, .16 + i * .026));
          S(tr, { opacity: k, transform: 'translateY(' + (1 - k) * 8 + 'px)' });
        });
        var r = eo(st(p, .02, .12));
        S($('.tch-l', root), { opacity: r });

        var growth = eio(st(p, .3, .62));
        [b1, b2, b3, b4].forEach(function (b, i) {
          var w = [72, 48, 33, 17][i] * growth;
          b.style.width = w + '%';
          b.style.background = ['#1E4FA8', '#3D7BD9', '#6FA0DC', '#A9C4E6'][i];
        });
        var ns = [29, 34, 42, 23];
        [n1, n2, n3, n4].forEach(function (el, i) { el.textContent = Math.round(ns[i] * growth); });
        rate.textContent = Math.round(63 * growth) + '%';

        var up = st(p, .44, .78);
        upfill.style.width = (up * 68) + '%';
        uppct.textContent = Math.round(up * 68) + '%';
        uptx.textContent = up <= 0 ? '等待上传' : (up < .3 ? '正在计算分片…' : (up < .9 ? '上传中 · 已传 ' + (126.4 * up * .68).toFixed(1) + ' MB' : '校验容器魔数…'));

        var press = st(p, .22, .25) * (1 - st(p, .27, .3));
        S(newc, { transform: 'scale(' + (1 - press * .04) + ')' });
        var tt = eo(st(p, .26, .31)) * (1 - st(p, .4, .46));
        S(toast, { opacity: tt, transform: 'translateY(' + (14 - tt * 14) + 'px)' });

        ctx.cursor(p, [
          { p: .12, x: 1700, y: 700 },
          { p: .2, x: center(newc).x, y: center(newc).y },
          { p: .24, x: center(newc).x, y: center(newc).y, click: true },
          { p: .34, x: center(newc).x + 40, y: center(newc).y + 40 },
          { p: .5, x: center(upbtn).x, y: center(upbtn).y },
          { p: .62, x: center(upbtn).x + 30, y: center(upbtn).y + 60 },
          { p: 1, x: center(upbtn).x + 30, y: center(upbtn).y + 60 }
        ]);
      };
    }
  };

  /* ===== 09 权限边界 ===== */
  DEFS.perm = {
    shell: true, nav: 'mine', role: 'student',
    url: 'learning.campus.edu.cn/api/v1/learning/courses/course_01J8F2',
    crumb: ['安全', '权限边界'],
    build: function (root) {
      root.innerHTML =
        '<div class="pm">' +
          '<div class="pm-l">' +
            '<div class="reqp">' +
              '<div class="reqh"><span class="tag r">学生身份</span><b>构造写请求 · 绕过前端按钮</b><span class="mono" id="rm">PATCH</span></div>' +
              '<div class="code" id="reqcode"></div>' +
              '<div class="resph" id="resph"><span class="st403">403</span><b>Forbidden</b><span class="mono">req_01J9K4T</span></div>' +
              '<div class="code" id="respcode"></div>' +
              '<div class="jlist">' +
                '<div class="jr ok"><i>✓</i><span>身份有效</span><b class="mono">userId=usr_01J7Q2M8</b></div>' +
                '<div class="jr no"><i>✕</i><span>权限点缺失</span><b class="mono">course:update</b></div>' +
                '<div class="jr ok"><i>✓</i><span>已写入审计</span><b class="mono">req_01J9K4T</b></div>' +
              '</div>' +
            '</div>' +
            '<div class="chain">' +
              '<div class="chs" id="hs1"><i>1</i><b>身份有效</b><span>OIDC 会话 · userId</span></div>' +
              '<span class="cha"></span>' +
              '<div class="chs" id="hs2"><i>2</i><b>权限点</b><span>course:update</span></div>' +
              '<span class="cha"></span>' +
              '<div class="chs" id="hs3"><i>3</i><b>资源与范围</b><span>ownerId / classId</span></div>' +
              '<span class="cha"></span>' +
              '<div class="chs x" id="hs4"><i>✕</i><b>拒绝</b><span>403 + 审计</span></div>' +
            '</div>' +
          '</div>' +
          '<div class="pm-r">' +
            '<div class="miniwin card" id="mini">' +
              '<div class="mtb"><i></i><i></i><i></i><span class="mono">learning.campus.edu.cn</span></div>' +
              '<div class="mbody">' +
                '<div class="m403">' +
                  '<div class="mico"><svg width="46" height="46" viewBox="0 0 48 48" fill="none"><rect x="9" y="21" width="30" height="20" rx="4" stroke="#D9534F" stroke-width="2.4"/><path d="M16 21v-5.5a8 8 0 0 1 16 0V21" stroke="#D9534F" stroke-width="2.4" stroke-linecap="round"/><circle cx="24" cy="30" r="2.2" fill="#D9534F"/><path d="M24 32v3.6" stroke="#D9534F" stroke-width="2.2" stroke-linecap="round"/></svg></div>' +
                  '<div class="mt403">403 · 无权访问</div>' +
                  '<div class="ms403">当前账号缺少权限点 <b class="mono">course:update</b>，或资源不在可操作范围内。</div>' +
                  '<div class="mrow"><button class="btn">返回课程目录</button><button class="btn p">切换账号</button></div>' +
                  '<div class="mrid mono">requestId req_01J9K4T</div>' +
                '</div>' +
              '</div>' +
            '</div>' +
            '<div class="states">' +
              '<div class="smini card"><span class="smn mono">404</span><b>页面不存在</b><span>未知路由</span></div>' +
              '<div class="smini card"><span class="smn mono">503</span><b>服务不可用</b><span>下游超时</span></div>' +
              '<div class="smini card"><span class="smn mono">EMPTY</span><b>暂无数据</b><span>空状态组件</span></div>' +
            '</div>' +
          '</div>' +
        '</div>';

      var reqcode = $('#reqcode', root), respcode = $('#respcode', root),
          resph = $('#resph', root), mini = $('#mini', root),
          hs = [root.querySelector('#hs1'), root.querySelector('#hs2'), root.querySelector('#hs3'), root.querySelector('#hs4')],
          states = $$('.smini', root);

      reqcode.innerHTML =
        '<span class="hl"><span class="k">PATCH</span> /api/v1/learning/courses/course_01J8F2</span>\n' +
        '<span class="c">X-App-Code</span>: learning\n' +
        '<span class="c">X-Request-Id</span>: req_01J9K4T\n' +
        '<span class="c">Cookie</span>: bff_session=****  <span class="c">(HttpOnly)</span>\n' +
        '{\n  <span class="k">"title"</span>: <span class="s">"网络安全基础（修订）"</span>\n}';
      respcode.innerHTML =
        '<span class="k">HTTP/1.1</span> <span class="n">403 Forbidden</span>\n' +
        '{\n  <span class="k">"code"</span>: <span class="s">"FORBIDDEN"</span>,\n' +
        '  <span class="k">"message"</span>: <span class="s">"无权执行此操作"</span>,\n' +
        '  <span class="k">"data"</span>: <span class="n">null</span>,\n' +
        '  <span class="k">"requestId"</span>: <span class="s">"req_01J9K4T"</span>\n}';

      return function (p, tl) {
        var a = eo(st(p, 0, .1));
        S(reqcode, { opacity: a, transform: 'translateY(' + (1 - a) * 10 + 'px)' });
        var r = eo(st(p, .3, .4));
        S(resph, { opacity: r });
        S(respcode, { opacity: eo(st(p, .34, .46)), transform: 'translateY(' + (1 - eo(st(p, .34, .46))) * 10 + 'px)' });

        var m = eo(st(p, .5, .62));
        S(mini, { opacity: m, transform: 'translateY(' + (1 - m) * 18 + 'px)' });

        var t = [.62, .7, .78, .86];
        hs.forEach(function (h, i) {
          var k = eio(st(p, t[i], t[i] + .07));
          var on = k > .4;
          h.style.background = on ? (i === 3 ? 'rgba(217,83,79,.10)' : 'rgba(30,79,168,.08)') : '#fff';
          h.style.borderColor = on ? (i === 3 ? '#E7B7B5' : '#BCD2F0') : '#E3E8F0';
          $('i', h).style.background = on ? (i === 3 ? '#D9534F' : '#1E4FA8') : '#C9D4E2';
          $('i', h).style.color = '#fff';
        });
        states.forEach(function (s, i) {
          var k = eo(st(p, .86 + i * .03, .93 + i * .03));
          S(s, { opacity: k, transform: 'translateY(' + (1 - k) * 10 + 'px)' });
        });

        var idx = st(p, .6, .9);
        S(hs[0], { borderColor: idx > 0 ? '#BCD2F0' : '#E3E8F0' });
      };
    }
  };

  /* ===== 10 运营与审计 ===== */
  DEFS.ops = {
    shell: true, nav: 'sys', role: 'admin',
    url: 'learning.campus.edu.cn/admin/audit',
    crumb: ['系统管理', '审计与运行状态'],
    build: function (root) {
      var logs = [
        ['09:42:12', 'usr_01J7Q2M8', 'course.complete', 'rec_01J8F2K9', 'ok', 'req_01J9K7'],
        ['09:41:55', 'usr_01J7Q2M8', 'record.update', 'rec_01J8F2K9', 'ok', 'req_01J9K5'],
        ['09:38:20', 'usr_01J6P1Q3', 'course.update', 'course_01J8K6', 'ok', 'req_01J9H8'],
        ['09:31:07', 'usr_01J7Q2M8', 'course.update', 'course_01J8F2', 'deny', 'req_01J9K4T'],
        ['09:22:41', 'usr_01J5N8R2', 'file.upload', 'file_01J8V7', 'ok', 'req_01J9F2'],
        ['09:15:03', 'system', 'event.publish', 'evt_01J9K7WR2Q', 'ok', 'req_01J9K7'],
        ['09:02:44', 'usr_01J6P1Q3', 'course.publish', 'course_01J8H1', 'ok', 'req_01J9B1'],
        ['08:51:19', 'usr_01J5N8R2', 'file.download', 'file_01J8V3', 'ok', 'req_01J98K'],
        ['08:40:02', 'usr_01J7Q2M8', 'record.update', 'rec_01J8F2K9', 'ok', 'req_01J96C'],
        ['08:12:37', 'system', 'event.consume', 'evt_01J9H2M4X', 'ok', 'req_01J93P']
      ].map(function (r) {
        return '<tr><td class="mono">' + r[0] + '</td><td class="mono">' + r[1] + '</td><td>' + r[2] + '</td>' +
          '<td class="mono">' + r[3] + '</td><td>' + (r[4] === 'ok' ? '<span class="tag g">成功</span>' : '<span class="tag r">拒绝</span>') + '</td><td class="mono">' + r[5] + '</td></tr>';
      }).join('');

      root.innerHTML =
        '<div class="phead">' +
          '<div><h2>审计与运行状态</h2><div class="desc">陈立明 · 管理员 · 审计记录可由 requestId 反查整条链路</div></div>' +
          '<div class="r"><span class="api">GET /api/v1/learning/admin/audit?requestId=…</span></div>' +
        '</div>' +
        '<div class="ops">' +
          '<div class="ops-l card">' +
            '<div class="tblh"><b>审计日志</b><span>保留 180 天 · 不记录令牌与敏感载荷</span></div>' +
            '<div class="sinput2"><svg width="14" height="14" viewBox="0 0 14 14" fill="none"><circle cx="6.2" cy="6.2" r="4.3" stroke="#9AA7B8" stroke-width="1.3"/><path d="m9.6 9.6 2.4 2.4" stroke="#9AA7B8" stroke-width="1.3" stroke-linecap="round"/></svg><span id="aq">req_01J9K4T</span><i class="caret" style="opacity:.7"></i></div>' +
            '<table class="tbl"><thead><tr><th>时间</th><th>actorId</th><th>动作</th><th>资源</th><th>结果</th><th>requestId</th></tr></thead><tbody id="lt">' + logs + '</tbody></table>' +
            '<div class="lnote"><i class="dotm"></i>第 4 行与权限场景同一条 requestId，可定位到具体拒绝原因</div>' +
          '</div>' +
          '<div class="ops-r">' +
            '<div class="kpis">' +
              '<div class="kpi card"><span>网关 P95</span><b>82<em>ms</em></b><i style="width:82%"></i></div>' +
              '<div class="kpi card"><span>课程 API 可用性</span><b>99.98<em>%</em></b><i style="width:99%"></i></div>' +
              '<div class="kpi card"><span>事件消费滞后</span><b>0.4<em>s</em></b><i style="width:12%"></i></div>' +
              '<div class="kpi card"><span>死信队列</span><b>0<em>条</em></b><i style="width:4%"></i></div>' +
            '</div>' +
            '<div class="card lag">' +
              '<div class="tblh"><b>事件消费延迟</b><span>近 30 分钟</span></div>' +
              '<svg width="100%" height="86" viewBox="0 0 560 86" preserveAspectRatio="none">' +
                '<defs><linearGradient id="lg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#3D7BD9" stop-opacity=".28"/><stop offset="1" stop-color="#3D7BD9" stop-opacity="0"/></linearGradient></defs>' +
                '<path d="M0 62 L40 58 L80 64 L120 52 L160 55 L200 44 L240 48 L280 38 L320 41 L360 30 L400 34 L440 26 L480 29 L520 22 L560 25 L560 86 L0 86Z" fill="url(#lg)"/>' +
                '<path id="lagline" d="M0 62 L40 58 L80 64 L120 52 L160 55 L200 44 L240 48 L280 38 L320 41 L360 30 L400 34 L440 26 L480 29 L520 22 L560 25" fill="none" stroke="#3D7BD9" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" stroke-dasharray="700" stroke-dashoffset="700"/>' +
              '</svg>' +
            '</div>' +
            '<div class="card matrix">' +
              '<div class="tblh"><b>角色 · 权限点</b><span>平台映射，不改变角色语义</span></div>' +
              '<table class="tbl mini"><thead><tr><th>权限点</th><th>student</th><th>teacher</th><th>admin</th></tr></thead><tbody>' +
                '<tr><td class="mono">course:read</td><td class="yes">✓</td><td class="yes">✓</td><td class="yes">✓</td></tr>' +
                '<tr><td class="mono">record:write</td><td class="yes">✓</td><td class="yes">✓</td><td class="yes">✓</td></tr>' +
                '<tr><td class="mono">course:create</td><td class="no">—</td><td class="yes">✓</td><td class="yes">✓</td></tr>' +
                '<tr><td class="mono">course:publish</td><td class="no">—</td><td class="yes">✓</td><td class="yes">✓</td></tr>' +
                '<tr><td class="mono">audit:read</td><td class="no">—</td><td class="no">—</td><td class="yes">✓</td></tr>' +
              '</tbody></table>' +
            '</div>' +
          '</div>' +
        '</div>';

      var rows = $$('#lt tr', root), lagline = root.querySelector('#lagline'),
          kpis = $$('.kpi', root), matrix = $('.matrix', root), q = $('#aq', root);

      return function (p, tl) {
        rows.forEach(function (tr, i) {
          var k = eo(st(p, .04 + i * .03, .16 + i * .03));
          S(tr, { opacity: k, transform: 'translateY(' + (1 - k) * 8 + 'px)' });
        });
        lagline.setAttribute('stroke-dashoffset', String(700 * (1 - eio(st(p, .2, .7)))));
        kpis.forEach(function (k, i) {
          var a = eo(st(p, .1 + i * .04, .22 + i * .04));
          S(k, { opacity: a, transform: 'translateY(' + (1 - a) * 10 + 'px)' });
        });
        S(matrix, { opacity: eo(st(p, .5, .62)), transform: 'translateY(' + (1 - eo(st(p, .5, .62))) * 12 + 'px)' });

        var hl = eo(st(p, .66, .74));
        S(rows[3], { background: hl > .05 ? 'rgba(217,83,79,' + (.05 + hl * .04) + ')' : 'transparent' });
        var typed = st(p, .7, .82);
        q.textContent = 'req_01J9K4T'.slice(0, Math.round(typed * 11)) || '按 requestId 检索';
      };
    }
  };

  /* ===== 11 工程基线 ===== */
  DEFS.stack = {
    shell: true, nav: null, role: 'admin',
    url: 'github.campus.edu.cn/learning-platform',
    crumb: ['工程基线', '交付物'],
    build: function (root) {
      root.innerHTML =
        '<div class="phead">' +
          '<div><h2>工程基线与契约交付</h2><div class="desc">统一模板 · 版本化公共包 · 五项目一致的准入检查</div></div>' +
          '<div class="r"><span class="api">规范 §3.1 / §3.2 / §11 / §13</span></div>' +
        '</div>' +
        '<div class="stk">' +
          '<div class="card tree">' +
            '<div class="tblh"><b>目录结构</b><span>职责边界固定</span></div>' +
            '<pre class="mono">src/\n├─ app/        <i>路由 · Provider · 装配</i>\n├─ pages/      <i>路由页面</i>\n├─ features/   <i>业务用例与组件</i>\n├─ components/ <i>平台复用组件</i>\n├─ services/   <i>API 客户端适配</i>\n├─ types/      <i>契约与共享类型</i>\n├─ styles/     <i>主题 Token</i>\n└─ assets/</pre>' +
            '<div class="tnote">认证、HTTP 客户端、权限判断、状态页来自版本化公共包，禁止复制分叉</div>' +
          '</div>' +
          '<div class="stk-m">' +
            '<div class="card vers">' +
              '<div class="tblh"><b>版本锁定</b><span>lockfile 安装</span></div>' +
              '<div class="vgrid">' +
                '<span class="vchip">React 18.3</span><span class="vchip">TypeScript 5.4</span><span class="vchip">Vite 5.2</span>' +
                '<span class="vchip">Ant Design 5.21</span><span class="vchip">GSAP 3.12</span><span class="vchip ok">strict: true</span>' +
              '</div>' +
              '<div class="checks">' +
                '<div class="chk"><i>✓</i><span>lint · typecheck · build 全绿</span></div>' +
                '<div class="chk"><i>✓</i><span>无 any、无 ts-ignore、无秘密进产物</span></div>' +
                '<div class="chk"><i>✓</i><span>统一请求头：X-App-Code / X-Request-Id</span></div>' +
                '<div class="chk"><i>✓</i><span>加载 / 空 / 错误 / 403 / 404 共用组件</span></div>' +
                '<div class="chk"><i>✓</i><span>GSAP 时长 token 150 / 250 / 400 ms</span></div>' +
              '</div>' +
            '</div>' +
            '<div class="card deliver">' +
              '<div class="tblh"><b>交付物</b><span>联调前提交</span></div>' +
              '<div class="dchips"><span>README</span><span>OpenAPI 3.x</span><span>事件 schema</span><span>权限点矩阵</span><span>网络矩阵</span><span>Demo</span></div>' +
            '</div>' +
          '</div>' +
          '<div class="card spec">' +
            '<div class="tblh"><b>条款对照</b><span>本平台落实情况</span></div>' +
            '<table class="tbl"><tbody>' +
              '<tr><td>§3.1 前端工程基线</td><td><span class="tag g">已满足</span></td></tr>' +
              '<tr><td>§3.3 路由与统一状态页</td><td><span class="tag g">已满足</span></td></tr>' +
              '<tr><td>§4 主题 Token 与动效</td><td><span class="tag g">已满足</span></td></tr>' +
              '<tr><td>§5 统一身份 · BFF 会话</td><td><span class="tag g">已满足</span></td></tr>' +
              '<tr><td>§7 数据字典字段</td><td><span class="tag g">已满足</span></td></tr>' +
              '<tr><td>§9 事件封套与投递</td><td><span class="tag g">已满足</span></td></tr>' +
              '<tr><td>§2 权威数据边界</td><td><span class="tag g">已满足</span></td></tr>' +
              '<tr><td>§12 权限点与审计</td><td><span class="tag g">已满足</span></td></tr>' +
            '</tbody></table>' +
          '</div>' +
        '</div>';

      var rows = $$('.spec tbody tr', root), chips = $$('.dchips span', root),
          chks = $$('.chk', root), vg = $$('.vchip', root);

      return function (p, tl) {
        var a = eo(st(p, 0, .1));
        S($('.tree', root), { opacity: a, transform: 'translateX(' + (1 - a) * -14 + 'px)' });
        S($('.stk-m', root), { opacity: eo(st(p, .06, .18)), transform: 'translateY(' + (1 - eo(st(p, .06, .18))) * 14 + 'px)' });
        S($('.spec', root), { opacity: eo(st(p, .12, .24)), transform: 'translateX(' + (1 - eo(st(p, .12, .24))) * 16 + 'px)' });

        vg.forEach(function (c, i) {
          var k = eo(st(p, .14 + i * .03, .26 + i * .03));
          S(c, { opacity: .3 + k * .7, transform: 'translateY(' + (1 - k) * 8 + 'px)' });
        });
        chks.forEach(function (c, i) {
          var k = eo(st(p, .3 + i * .05, .42 + i * .05));
          S(c, { opacity: .25 + k * .75, transform: 'translateX(' + (1 - k) * 10 + 'px)' });
          $('i', c).style.background = k > .5 ? '#1E9E63' : '#DCE3EE';
          $('i', c).style.color = '#fff';
        });
        rows.forEach(function (r, i) {
          var k = eo(st(p, .45 + i * .045, .56 + i * .045));
          S(r, { opacity: .2 + k * .8 });
          $('td:last-child', r).style.opacity = k;
        });
        chips.forEach(function (c, i) {
          var k = eo(st(p, .78 + i * .025, .86 + i * .025));
          S(c, { opacity: .2 + k * .8, transform: 'translateY(' + (1 - k) * 8 + 'px)' });
        });
      };
    }
  };

  /* ===== 12 片尾 ===== */
  DEFS.outro = {
    shell: false,
    build: function (root) {
      root.innerHTML =
        '<div class="bleed dark">' +
          '<div class="gridbg"></div>' +
          '<div class="glow" style="right:-140px;top:-200px;width:640px;height:640px;background:#2E6BD0"></div>' +
          '<div class="o-wrap">' +
            '<div class="o-tag"><span class="ln"></span>演示数据说明</div>' +
            '<h2 class="o-h">界面中的课程、身份与事件<br>均为用于说明契约的模拟数据</h2>' +
            '<div class="o-cols">' +
              '<div class="o-col"><b>权威边界</b><span>自学平台只对课程、资源、学习记录与课程完成状态负责；其他平台数据仅作投影展示。</span></div>' +
              '<div class="o-col"><b>联动方式</b><span>即时判定走同步 API，状态传播走 course.completed 事件；不直连其他平台数据库。</span></div>' +
              '<div class="o-col"><b>未连接项</b><span>Demo 未接入真实 SSO、事件代理与文件服务，接口地址为示例值。</span></div>' +
            '</div>' +
            '<div class="o-end"><span class="o-ln"></span><span>自学平台 · 功能演示</span><span class="o-dot"></span><span>2026-11</span></div>' +
          '</div>' +
        '</div>';
      var wrap = $('.o-wrap', root), cols = $$('.o-col', root), end = $('.o-end', root), tag = $('.o-tag', root);
      return function (p) {
        var a = eo(st(p, .02, .16));
        S(tag, { opacity: a, transform: 'translateY(' + (1 - a) * 10 + 'px)' });
        var b = eo(st(p, .08, .3));
        S($('.o-h', root), { opacity: b, transform: 'translateY(' + (1 - b) * 18 + 'px)' });
        cols.forEach(function (c, i) {
          var k = eo(st(p, .3 + i * .08, .46 + i * .08));
          S(c, { opacity: k, transform: 'translateY(' + (1 - k) * 14 + 'px)' });
        });
        S(end, { opacity: eo(st(p, .6, .75)) });
      };
    }
  };

  window.SCENE_DEFS = DEFS;
})();

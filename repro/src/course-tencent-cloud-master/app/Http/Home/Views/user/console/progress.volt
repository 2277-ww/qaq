{% extends 'templates/main.volt' %}

{% block content %}

    <div class="layout-main">
        <div class="my-sidebar">{{ partial('user/console/menu') }}</div>
        <div class="my-content">
            <div class="wrap">

                <div class="my-nav">
                    <span class="title">学习进度</span>
                    {% if progress.courses|length > 0 %}
                        <button class="layui-btn layui-btn-sm kg-lp-btn" id="btn-progress-sync-all">同步到考试平台</button>
                    {% endif %}
                </div>

                <div class="kg-lp-overview">
                    <div class="kg-lp-card">
                        <div class="num">{{ progress.overview.course_total }}</div>
                        <div class="label">学习课程</div>
                    </div>
                    <div class="kg-lp-card">
                        <div class="num">{{ progress.overview.completed_total }}</div>
                        <div class="label">已完成课程</div>
                    </div>
                    <div class="kg-lp-card">
                        <div class="num">{{ progress.overview.lesson_completed }}<span class="unit">/{{ progress.overview.lesson_total }}</span></div>
                        <div class="label">完成课时</div>
                    </div>
                    <div class="kg-lp-card">
                        <div class="num num-text">{{ progress.overview.duration_text }}</div>
                        <div class="label">累计学习时长</div>
                    </div>
                </div>

                <div class="kg-lp-channel">
                    <div class="kg-lp-channel-main">
                        <span class="kg-lp-dot"></span>
                        <span class="kg-lp-channel-title">考试平台通道</span>
                        {% if progress.sync.enabled %}
                            {% if progress.sync.mode == 'gateway' %}
                                <span class="layui-badge layui-bg-green">经统一网关</span>
                                <span class="kg-lp-endpoint">{{ progress.sync.endpoint }}</span>
                            {% else %}
                                <span class="layui-badge layui-bg-blue">本地直连（未配置网关地址）</span>
                                <span class="kg-lp-endpoint">事件照常入箱，配置 gateway.base_uri 后自动改走网关</span>
                            {% endif %}
                        {% else %}
                            <span class="layui-badge layui-bg-gray">已关闭推送</span>
                            <span class="kg-lp-endpoint">config 中 exam.enabled = false</span>
                        {% endif %}
                    </div>
                    <div class="kg-lp-channel-stats">
                        <span>待推送 <b>{{ progress.sync.pending }}</b></span>
                        <span>已推送 <b>{{ progress.sync.sent }}</b></span>
                        <span>待重试 <b>{{ progress.sync.failed }}</b></span>
                        <span>失败 <b>{{ progress.sync.dead }}</b></span>
                        <span class="kg-lp-last">最近推送 {{ progress.sync.last_sent_text }}</span>
                    </div>
                </div>

                <div class="kg-lp-section">
                    <h3>各课程进度</h3>
                    {% if progress.courses|length > 0 %}
                        <table class="layui-table kg-lp-table" lay-skin="line">
                            <colgroup>
                                <col>
                                <col width="22%">
                                <col width="14%">
                                <col width="15%">
                                <col width="17%">
                                <col width="10%">
                            </colgroup>
                            <thead>
                            <tr>
                                <th>课程</th>
                                <th>学习进度</th>
                                <th>课时 / 时长</th>
                                <th>最近学习</th>
                                <th>考试平台</th>
                                <th>操作</th>
                            </tr>
                            </thead>
                            <tbody>
                            {% for item in progress.courses %}
                                {% set course_url = url({'for':'home.course.show','id':item.course_id}) %}
                                <tr>
                                    <td>
                                        <div class="kg-lp-course">
                                            <a href="{{ course_url }}" target="_blank">{{ item.course_title }}</a>
                                            <div class="kg-lp-badge-row">
                                                <span class="layui-badge {{ item.status == 2 ? 'layui-bg-green' : (item.status == 1 ? 'layui-bg-blue' : 'layui-bg-gray') }}">{{ item.status_text }}</span>
                                            </div>
                                        </div>
                                    </td>
                                    <td>
                                        <div class="kg-lp-bar">
                                            <div class="kg-lp-bar-inner" style="width:{{ item.progress }}%"></div>
                                        </div>
                                        <span class="kg-lp-bar-text">{{ item.progress }}%</span>
                                    </td>
                                    <td>
                                        {% if item.total_count > 0 %}
                                            {{ item.completed_count }}/{{ item.total_count }} 课时<br><span class="kg-lp-muted">{{ item.duration_text }}</span>
                                        {% else %}
                                            <span class="kg-lp-muted">暂无课时记录</span>
                                        {% endif %}
                                    </td>
                                    <td class="kg-lp-muted">{{ item.last_active_text ? item.last_active_text : '—' }}</td>
                                    <td>
                                        <span class="layui-badge {{ item.push.status_class }}">{{ item.push.status_text }}</span>
                                        {% if item.push.time_text %}
                                            <div class="kg-lp-muted">{{ item.push.time_text }}</div>
                                        {% endif %}
                                        {% if item.push.last_error %}
                                            <div class="kg-lp-error" title="{{ item.push.last_error }}">失败原因见同步记录</div>
                                        {% endif %}
                                    </td>
                                    <td>
                                        {% if item.progress > 0 %}
                                            <button class="layui-btn layui-btn-xs layui-btn-primary btn-progress-sync" data-course-id="{{ item.course_id }}">推送</button>
                                        {% else %}
                                            <button class="layui-btn layui-btn-xs layui-btn-disabled" title="还没有学习进度">推送</button>
                                        {% endif %}
                                    </td>
                                </tr>
                            {% endfor %}
                            </tbody>
                        </table>
                    {% else %}
                        <p class="kg-lp-empty">还没有学习记录，去<a href="{{ url({'for':'home.course.list'}) }}">课程列表</a>挑一门开始学习。</p>
                    {% endif %}
                </div>

                <div class="kg-lp-section">
                    <h3>同步记录</h3>
                    {% if progress.timeline|length > 0 %}
                        <table class="layui-table kg-lp-table" lay-skin="line">
                            <colgroup>
                                <col width="12%">
                                <col>
                                <col width="10%">
                                <col width="10%">
                                <col width="17%">
                                <col width="16%">
                            </colgroup>
                            <thead>
                            <tr>
                                <th>事件</th>
                                <th>课程</th>
                                <th>进度</th>
                                <th>状态</th>
                                <th>发生时间</th>
                                <th>事件编号</th>
                            </tr>
                            </thead>
                            <tbody>
                            {% for item in progress.timeline %}
                                <tr>
                                    <td>{{ item.event_label }}</td>
                                    <td>{{ item.course_title }}</td>
                                    <td>{{ item.progress }}%</td>
                                    <td>
                                        <span class="layui-badge {{ item.status == 1 ? 'layui-bg-green' : (item.status == 3 ? 'layui-bg-red' : (item.status == 2 ? 'layui-bg-orange' : 'layui-bg-gray')) }}">{{ item.status_text }}</span>
                                        {% if item.retry_count > 0 %}
                                            <span class="kg-lp-muted">重试 {{ item.retry_count }}</span>
                                        {% endif %}
                                    </td>
                                    <td class="kg-lp-muted">{{ item.time_text }}</td>
                                    <td class="kg-lp-mono">{{ item.event_id }}</td>
                                </tr>
                            {% endfor %}
                            </tbody>
                        </table>
                    {% else %}
                        <p class="kg-lp-empty">还没有同步记录。点击右上角「同步到考试平台」，把当前进度推送给考试平台。</p>
                    {% endif %}
                </div>

                <div class="kg-lp-tips">
                    <p><b>上报口径</b>：课程进度 = 已完成课时 / 课程总课时；课时观看达到 30% 视为完成。进度按增量上报，距上次上报不足 5 个百分点时合并，避免高频请求打满网关。</p>
                    <p><b>传输方式</b>：事件先写入发件箱（kg_exam_outbox），再由投递器经统一网关发送，带 X-Internal-Sign 内部签名与 Idempotency-Key；失败按 1s/5s/30s/2min/10min/1h 退避重试，第 6 次仍失败转死信。</p>
                    <p><b>考试平台</b>：可调用 GET /api/v1/learning/completion/{userId}/{courseId} 回源课程完成状态，作为开放随堂测试的依据；本平台不反向读取考试数据。</p>
                </div>

            </div>
        </div>
    </div>

{% endblock %}

{% block inline_css %}
    <style>
        .kg-lp-btn { float: right; background: #0B1F3A; border-color: #0B1F3A; color: #fff; }
        .kg-lp-btn:hover { background: #16345C; border-color: #16345C; color: #fff; }
        .kg-lp-overview { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 12px; margin: 16px 0 14px; }
        .kg-lp-card { background: #fff; border: 1px solid #e8e8e8; border-top: 3px solid #0B1F3A; border-radius: 3px; padding: 16px 12px; text-align: center; }
        .kg-lp-card .num { font-size: 22px; font-weight: 600; color: #0B1F3A; line-height: 1.4; }
        .kg-lp-card .num .unit { font-size: 13px; color: #98A2B3; font-weight: 400; }
        .kg-lp-card .num-text { font-size: 18px; letter-spacing: -0.2px; }
        .kg-lp-card .label { font-size: 13px; color: #667085; margin-top: 4px; }
        .kg-lp-channel { background: #FAF7F0; border: 1px solid #EFE3C8; border-left: 4px solid #C8A24A; border-radius: 3px; padding: 12px 16px; margin-bottom: 22px; }
        .kg-lp-channel-main { display: flex; align-items: center; flex-wrap: wrap; gap: 8px; font-size: 13px; }
        .kg-lp-channel-title { font-weight: 600; color: #0B1F3A; }
        .kg-lp-dot { width: 8px; height: 8px; border-radius: 50%; background: #C8A24A; display: inline-block; }
        .kg-lp-endpoint { color: #8A6D2F; font-size: 12px; }
        .kg-lp-channel-stats { margin-top: 8px; padding-top: 8px; border-top: 1px dashed #E7D9BB; font-size: 12px; color: #7A5B1E; display: flex; flex-wrap: wrap; gap: 16px; }
        .kg-lp-channel-stats b { color: #0B1F3A; font-size: 14px; margin-left: 2px; }
        .kg-lp-last { margin-left: auto; color: #98A2B3; }
        .kg-lp-section { margin-bottom: 26px; }
        .kg-lp-section h3 { font-size: 15px; font-weight: 600; color: #0B1F3A; margin: 0 0 10px; padding-left: 9px; border-left: 3px solid #C8A24A; line-height: 1.2; }
        .kg-lp-table td { vertical-align: middle; padding: 13px 10px; line-height: 1.7; }
        .kg-lp-course { display: block; line-height: 1.5; }
        .kg-lp-badge-row { margin-top: 5px; }
        .kg-lp-badge-row .layui-badge { margin: 0; }
        .kg-lp-bar { display: inline-block; width: 110px; height: 8px; background: #ECEFF3; border-radius: 4px; overflow: hidden; vertical-align: middle; }
        .kg-lp-bar-inner { height: 100%; background: linear-gradient(90deg, #0B1F3A, #2E5C8A); }
        .kg-lp-bar-text { font-size: 12px; color: #475467; margin-left: 8px; }
        .kg-lp-muted { font-size: 12px; color: #98A2B3; }
        .kg-lp-mono { font-family: Consolas, Monaco, monospace; font-size: 11px; color: #667085; }
        .kg-lp-error { font-size: 11px; color: #C0392B; margin-top: 2px; }
        .kg-lp-empty { color: #98A2B3; font-size: 13px; line-height: 1.9; }
        .kg-lp-tips { font-size: 12px; color: #8A94A6; line-height: 1.9; border-top: 1px solid #eee; padding-top: 12px; }
        .kg-lp-tips b { color: #667085; }
        @media (max-width: 991px) {
            .kg-lp-overview { grid-template-columns: repeat(2, 1fr); }
            .kg-lp-last { margin-left: 0; }
        }
    </style>
{% endblock %}

{% block inline_js %}
    <script>
        layui.use(['jquery', 'layer'], function () {
            var $ = layui.jquery, layer = layui.layer;

            function push(courseId, btn) {
                var text = btn.text();
                btn.addClass('layui-btn-disabled').text('推送中');
                $.post('/uc/progress/sync', {course_id: courseId}, function (res) {
                    layer.msg(res.msg || '推送完成', {icon: 1});
                    setTimeout(function () { location.reload(); }, 900);
                }).fail(function (xhr) {
                    btn.removeClass('layui-btn-disabled').text(text);
                    layer.msg('推送失败，请稍后重试', {icon: 2});
                });
            }

            $('#btn-progress-sync-all').on('click', function () {
                push(0, $(this));
            });

            $('.btn-progress-sync').on('click', function () {
                push($(this).data('course-id'), $(this));
            });
        });
    </script>
{% endblock %}

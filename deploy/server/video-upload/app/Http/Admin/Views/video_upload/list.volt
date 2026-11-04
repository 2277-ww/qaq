{% extends 'templates/main.volt' %}

{% block content %}

    {% set index_url = url({'for':'admin.video_upload.index'}) %}
    {% set delete_url = url({'for':'admin.video_upload.delete'}) %}

    <div class="kg-nav">
        <div class="kg-nav-left">
            <span class="layui-breadcrumb">
                <a><cite>媒体库</cite></a>
            </span>
        </div>
        <div class="kg-nav-right">
            <a class="layui-btn layui-btn-sm" href="{{ index_url }}">
                <i class="layui-icon layui-icon-upload"></i>上传新视频
            </a>
        </div>
    </div>

    <div class="kg-stat-bar">
        <span>存储目录 <code>{{ stat.media_root }}</code></span>
        <span>文件数 <strong>{{ files|length }}</strong></span>
        <span>已占用 <strong>{{ stat.used_text }}</strong></span>
        <span>剩余 <strong>{{ stat.free_text }}</strong></span>
    </div>

    <table class="layui-table kg-table">
        <colgroup>
            <col>
            <col width="12%">
            <col width="16%">
            <col width="16%">
        </colgroup>
        <thead>
        <tr>
            <th>播放地址</th>
            <th>大小</th>
            <th>上传时间</th>
            <th>操作</th>
        </tr>
        </thead>
        <tbody>
        {% for item in files %}
            <tr>
                <td class="kg-ellipsis" title="{{ item.url }}">{{ item.url }}</td>
                <td>{{ item.size_text }}</td>
                <td>{{ item.mtime_text }}</td>
                <td>
                    <a class="layui-btn layui-btn-xs layui-btn-primary" href="{{ item.url }}" target="_blank">预览</a>
                    <button type="button" class="layui-btn layui-btn-xs layui-btn-danger kg-del"
                            data-url="{{ item.url }}">删除</button>
                </td>
            </tr>
        {% else %}
            <tr>
                <td colspan="4" class="center">媒体库为空，先上传一个视频</td>
            </tr>
        {% endfor %}
        </tbody>
    </table>

{% endblock %}

{% block inline_css %}
    <style>
        .kg-stat-bar {
            margin-bottom: 14px;
            font-size: 13px;
            color: #666;
        }
        .kg-stat-bar span {
            margin-right: 22px;
        }
        .kg-stat-bar code {
            background: #f4f4f4;
            padding: 1px 5px;
            border-radius: 3px;
            font-size: 12px;
        }
    </style>
{% endblock %}

{% block inline_js %}
    <script>
        layui.use(['layer'], function () {
            var layer = layui.layer;
            var $ = layui.$;

            $('.kg-del').on('click', function () {
                var url = $(this).data('url');
                layer.confirm('删除后该文件立即不可访问，已绑定的章节会播放失败。确认删除？', {
                    title: '删除确认',
                    btn: ['删除', '取消']
                }, function (index) {
                    $.post('{{ delete_url }}', {url: url}, function (res) {
                        if (res.code === 0) {
                            layer.msg('已删除', {icon: 1}, function () {
                                window.location.reload();
                            });
                        } else {
                            layer.msg(res.msg, {icon: 2});
                        }
                    }, 'json');
                    layer.close(index);
                });
            });
        });
    </script>
{% endblock %}

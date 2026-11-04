{% extends 'templates/main.volt' %}

{% block content %}

    {% set list_url = url({'for':'admin.video_upload.list'}) %}
    {% set init_url = url({'for':'admin.video_upload.init'}) %}
    {% set chunk_url = url({'for':'admin.video_upload.chunk'}) %}
    {% set finish_url = url({'for':'admin.video_upload.finish'}) %}
    {% set attach_url = url({'for':'admin.video_upload.attach'}) %}
    {% set chapters_url = url({'for':'admin.video_upload.chapters'}) %}

    <div class="kg-nav">
        <div class="kg-nav-left">
            <span class="layui-breadcrumb">
                <a><cite>演示视频上传</cite></a>
            </span>
        </div>
        <div class="kg-nav-right">
            <a class="layui-btn layui-btn-sm layui-btn-primary" href="{{ list_url }}">
                <i class="layui-icon layui-icon-list"></i>媒体库
            </a>
        </div>
    </div>

    <div class="layui-row layui-col-space15">
        <div class="layui-col-md8">
            <div class="layui-card">
                <div class="layui-card-header">上传新视频</div>
                <div class="layui-card-body">

                    <div class="layui-form" lay-filter="upload-form">

                        <div class="layui-form-item">
                            <label class="layui-form-label">所属课程</label>
                            <div class="layui-input-block">
                                <select id="course-id" lay-filter="course">
                                    <option value="">请选择课程</option>
                                    {% for course in courses %}
                                        <option value="{{ course.id }}">{{ course.title }}</option>
                                    {% endfor %}
                                </select>
                                <div class="layui-form-mid layui-word-aux">文件会归档到该课程目录下</div>
                            </div>
                        </div>

                        <div class="layui-form-item">
                            <label class="layui-form-label">视频文件</label>
                            <div class="layui-input-block">
                                <div id="drop-zone" class="kg-drop-zone">
                                    <i class="layui-icon layui-icon-upload-drag"></i>
                                    <p class="kg-drop-title">点击选择文件，或把视频拖到这里</p>
                                    <p class="kg-drop-tip">
                                        支持 {{ stat.allowed_ext }}，单文件不超过 {{ stat.max_size_text }}
                                    </p>
                                    <input type="file" id="file-input" accept="video/mp4,video/webm,.mp4,.webm,.m4v" hidden>
                                </div>
                                <div id="file-meta" class="kg-file-meta layui-hide">
                                    <span id="file-name"></span>
                                    <span id="file-size" class="kg-muted"></span>
                                    <a href="javascript:" id="file-reset" class="kg-link">重新选择</a>
                                </div>
                            </div>
                        </div>

                        <div class="layui-form-item">
                            <div class="layui-input-block">
                                <button type="button" class="layui-btn" id="btn-start" disabled>
                                    <i class="layui-icon layui-icon-upload"></i>开始上传
                                </button>
                                <button type="button" class="layui-btn layui-btn-primary" id="btn-cancel" disabled>
                                    取消
                                </button>
                            </div>
                        </div>

                    </div>

                    <div id="progress-box" class="kg-progress-box layui-hide">
                        <div class="layui-progress layui-progress-big" lay-showpercent="true" lay-filter="upload-progress">
                            <div class="layui-progress-bar layui-bg-blue" lay-percent="0%"></div>
                        </div>
                        <p class="kg-progress-text">
                            <span id="progress-detail">准备中</span>
                            <span id="progress-speed" class="kg-muted"></span>
                        </p>
                    </div>

                    <div id="result-box" class="kg-result-box layui-hide">
                        <div class="layui-elem-quote layui-quote-nm">
                            <p><strong>上传成功</strong>，文件已归档。</p>
                            <p class="kg-result-line">
                                播放地址：
                                <a id="result-url" href="#" target="_blank" class="kg-link"></a>
                            </p>
                        </div>

                        <div class="layui-form" lay-filter="attach-form" style="margin-top:15px;">
                            <div class="layui-form-item">
                                <label class="layui-form-label">绑定章节</label>
                                <div class="layui-input-block">
                                    <select id="chapter-id">
                                        <option value="">可选：绑定到某个课时</option>
                                    </select>
                                    <div class="layui-form-mid layui-word-aux">
                                        绑定后该课时的播放器立即使用此视频
                                    </div>
                                </div>
                            </div>
                            <div class="layui-form-item">
                                <div class="layui-input-block">
                                    <button type="button" class="layui-btn layui-btn-sm" id="btn-attach">
                                        绑定到章节
                                    </button>
                                    <a class="layui-btn layui-btn-sm layui-btn-primary" id="result-preview" href="#" target="_blank">
                                        预览播放
                                    </a>
                                </div>
                            </div>
                        </div>
                    </div>

                </div>
            </div>
        </div>

        <div class="layui-col-md4">
            <div class="layui-card">
                <div class="layui-card-header">存储与限制</div>
                <div class="layui-card-body">
                    <table class="layui-table kg-table kg-table-plain">
                        <tbody>
                        <tr>
                            <td class="kg-key">存储位置</td>
                            <td><code>{{ stat.media_root }}</code></td>
                        </tr>
                        <tr>
                            <td class="kg-key">访问路径</td>
                            <td><code>/media/vod/</code></td>
                        </tr>
                        <tr>
                            <td class="kg-key">单文件上限</td>
                            <td>{{ stat.max_size_text }}</td>
                        </tr>
                        <tr>
                            <td class="kg-key">允许格式</td>
                            <td>{{ stat.allowed_ext }}</td>
                        </tr>
                        <tr>
                            <td class="kg-key">分片大小</td>
                            <td>{{ stat.chunk_size_text }}</td>
                        </tr>
                        <tr>
                            <td class="kg-key">已占用</td>
                            <td>{{ stat.used_text }}</td>
                        </tr>
                        <tr>
                            <td class="kg-key">剩余空间</td>
                            <td>{{ stat.free_text }}</td>
                        </tr>
                        </tbody>
                    </table>
                    <p class="kg-muted kg-note">
                        文件存放在 web 根目录之外，通过 nginx 独立路径对外提供，
                        升级代码不会影响已上传的视频。
                    </p>
                </div>
            </div>
        </div>
    </div>

{% endblock %}

{% block inline_css %}
    <style>
        .kg-drop-zone {
            border: 2px dashed #d2d2d2;
            border-radius: 6px;
            padding: 32px 16px;
            text-align: center;
            cursor: pointer;
            transition: all .2s;
            background: #fafafa;
        }
        .kg-drop-zone:hover,
        .kg-drop-zone.kg-dragover {
            border-color: #1e9fff;
            background: #f2f8ff;
        }
        .kg-drop-zone .layui-icon {
            font-size: 40px;
            color: #1e9fff;
        }
        .kg-drop-title {
            margin: 8px 0 4px;
            font-size: 15px;
            color: #333;
        }
        .kg-drop-tip {
            font-size: 12px;
            color: #999;
        }
        .kg-file-meta {
            margin-top: 10px;
            font-size: 13px;
        }
        .kg-file-meta #file-name {
            margin-right: 10px;
            color: #333;
        }
        .kg-progress-box {
            margin-top: 20px;
        }
        .kg-progress-text {
            margin-top: 8px;
            font-size: 13px;
        }
        .kg-result-box {
            margin-top: 24px;
        }
        .kg-result-line {
            margin-top: 6px;
            word-break: break-all;
        }
        .kg-muted {
            color: #999;
            font-size: 12px;
        }
        .kg-note {
            line-height: 1.7;
            margin-top: 10px;
        }
        .kg-table-plain td {
            border: none;
            padding: 7px 0;
            font-size: 13px;
        }
        .kg-key {
            color: #666;
            width: 82px;
        }
        .kg-link {
            color: #1e9fff;
        }
        .kg-table-plain code {
            background: #f4f4f4;
            padding: 1px 5px;
            border-radius: 3px;
            font-size: 12px;
        }
    </style>
{% endblock %}

{% block inline_js %}
    <script>
        var CSRF_TOKEN = document.querySelector('meta[name="csrf-token"]').getAttribute('content');
        var URLS = {
            init: '{{ init_url }}',
            chunk: '{{ chunk_url }}',
            finish: '{{ finish_url }}',
            attach: '{{ attach_url }}',
            chapters: '{{ chapters_url }}'
        };
        var LIMIT = {
            maxSize: {{ stat.max_size }},
            chunkSize: {{ stat.chunk_size }}
        };
        var ALLOWED = ['mp4', 'webm', 'm4v'];

        layui.use(['layer', 'form', 'element'], function () {
            var layer = layui.layer;
            var form = layui.form;
            var element = layui.element;
            var $ = layui.$;

            var state = {
                file: null,
                uploadId: null,
                chunkSize: LIMIT.chunkSize,
                totalChunks: 0,
                courseId: 0,
                startAt: 0,
                aborted: false,
                resultUrl: ''
            };

            var $drop = $('#drop-zone');
            var $input = $('#file-input');
            var $start = $('#btn-start');
            var $cancel = $('#btn-cancel');

            function fmtSize(bytes) {
                if (bytes >= 1073741824) return (bytes / 1073741824).toFixed(2) + ' GB';
                if (bytes >= 1048576) return (bytes / 1048576).toFixed(1) + ' MB';
                if (bytes >= 1024) return (bytes / 1024).toFixed(1) + ' KB';
                return bytes + ' B';
            }

            function extOf(name) {
                var pos = name.lastIndexOf('.');
                return pos < 0 ? '' : name.substring(pos + 1).toLowerCase();
            }

            function resetFile() {
                state.file = null;
                $input.val('');
                $('#file-meta').addClass('layui-hide');
                $start.attr('disabled', true);
            }

            function acceptFile(file) {
                if (!file) return;
                var ext = extOf(file.name);
                if (ALLOWED.indexOf(ext) < 0) {
                    layer.msg('仅支持 ' + ALLOWED.join(' / ') + ' 格式', {icon: 2});
                    return;
                }
                if (file.size > LIMIT.maxSize) {
                    layer.msg('文件 ' + fmtSize(file.size) + ' 超过上限 ' + fmtSize(LIMIT.maxSize), {icon: 2});
                    return;
                }
                if (file.size === 0) {
                    layer.msg('文件内容为空', {icon: 2});
                    return;
                }
                state.file = file;
                $('#file-name').text(file.name);
                $('#file-size').text('（' + fmtSize(file.size) + '，分 ' +
                    Math.ceil(file.size / LIMIT.chunkSize) + ' 片）');
                $('#file-meta').removeClass('layui-hide');
                $start.attr('disabled', false);
            }

            $drop.on('click', function () {
                $input.trigger('click');
            });

            $input.on('change', function () {
                acceptFile(this.files[0]);
            });

            $drop.on('dragover dragenter', function (e) {
                e.preventDefault();
                $drop.addClass('kg-dragover');
            }).on('dragleave dragend', function () {
                $drop.removeClass('kg-dragover');
            }).on('drop', function (e) {
                e.preventDefault();
                $drop.removeClass('kg-dragover');
                var files = e.originalEvent.dataTransfer.files;
                if (files && files.length) acceptFile(files[0]);
            });

            $('#file-reset').on('click', function (e) {
                e.stopPropagation();
                resetFile();
            });

            form.on('select(course)', function (data) {
                state.courseId = parseInt(data.value || 0, 10);
            });

            function setProgress(percent, detail, speed) {
                element.progress('upload-progress', percent + '%');
                $('#progress-detail').text(detail);
                $('#progress-speed').text(speed || '');
            }

            function failUpload(msg) {
                $cancel.attr('disabled', true);
                $start.attr('disabled', false);
                layer.msg(msg, {icon: 2, time: 5000});
            }

            function doFinish() {
                setProgress(100, '正在合并分片并校验…', '');
                $.post(URLS.finish, {upload_id: state.uploadId}, function (res) {
                    if (res.code !== 0) {
                        return failUpload('合并失败：' + res.msg);
                    }
                    state.resultUrl = res.url;
                    $('#result-url').text(location.origin + res.url).attr('href', res.url);
                    $('#result-preview').attr('href', res.url);
                    $('#result-box').removeClass('layui-hide');
                    setProgress(100, '上传完成，共 ' + fmtSize(res.size), '');
                    $cancel.attr('disabled', true);
                    $start.attr('disabled', false);
                    layer.msg('上传成功', {icon: 1});
                    loadChapters(state.courseId);
                }, 'json').fail(function () {
                    failUpload('合并请求失败，请查看服务端日志');
                });
            }

            function sendChunk(index) {
                if (state.aborted) return;

                var start = index * state.chunkSize;
                var end = Math.min(start + state.chunkSize, state.file.size);
                var blob = state.file.slice(start, end);
                var fd = new FormData();
                fd.append('upload_id', state.uploadId);
                fd.append('index', index);
                fd.append('chunk', blob, 'part');

                var xhr = new XMLHttpRequest();
                xhr.open('POST', URLS.chunk, true);
                xhr.setRequestHeader('X-Csrf-Token', CSRF_TOKEN);

                xhr.upload.onprogress = function (e) {
                    if (!e.lengthComputable) return;
                    var loaded = start + e.loaded;
                    var percent = Math.floor(loaded * 100 / state.file.size);
                    var elapsed = (Date.now() - state.startAt) / 1000;
                    var speed = elapsed > 0.5 ? (loaded / elapsed / 1048576).toFixed(2) + ' MB/s' : '';
                    setProgress(percent,
                        '第 ' + (index + 1) + ' / ' + state.totalChunks + ' 片，' +
                        fmtSize(loaded) + ' / ' + fmtSize(state.file.size),
                        speed);
                };

                xhr.onload = function () {
                    var res;
                    try {
                        res = JSON.parse(xhr.responseText);
                    } catch (err) {
                        return failUpload('服务端返回异常（HTTP ' + xhr.status + '）');
                    }
                    if (res.code !== 0) {
                        return failUpload('第 ' + (index + 1) + ' 片失败：' + res.msg);
                    }
                    var next = index + 1;
                    if (next >= state.totalChunks) {
                        doFinish();
                    } else {
                        sendChunk(next);
                    }
                };

                xhr.onerror = function () {
                    failUpload('网络中断，已完成 ' + index + ' 片，刷新后可重新上传');
                };

                xhr.send(fd);
            }

            $start.on('click', function () {
                if (!state.courseId) {
                    return layer.msg('请先选择所属课程', {icon: 2});
                }
                if (!state.file) {
                    return layer.msg('请先选择视频文件', {icon: 2});
                }

                state.aborted = false;
                $start.attr('disabled', true);
                $cancel.attr('disabled', false);
                $('#result-box').addClass('layui-hide');
                $('#progress-box').removeClass('layui-hide');
                setProgress(0, '正在初始化上传…', '');

                $.post(URLS.init, {
                    course_id: state.courseId,
                    filename: state.file.name,
                    size: state.file.size
                }, function (res) {
                    if (res.code !== 0) {
                        return failUpload(res.msg);
                    }
                    state.uploadId = res.upload_id;
                    state.chunkSize = res.chunk_size;
                    state.totalChunks = res.total_chunks;
                    state.startAt = Date.now();
                    setProgress(0, '开始上传，共 ' + state.totalChunks + ' 片', '');
                    sendChunk(0);
                }, 'json').fail(function () {
                    failUpload('初始化请求失败，请确认已登录后台');
                });
            });

            $cancel.on('click', function () {
                state.aborted = true;
                $cancel.attr('disabled', true);
                $start.attr('disabled', false);
                layer.msg('已取消，未完成的分片会在 24 小时后自动清理');
            });

            function loadChapters(courseId) {
                var $sel = $('#chapter-id');
                $sel.html('<option value="">可选：绑定到某个课时</option>');
                if (!courseId) {
                    form.render('select');
                    return;
                }
                $.get(URLS.chapters, {course_id: courseId}, function (res) {
                    if (res.code !== 0) return;
                    var items = res.items || [];
                    for (var i = 0; i < items.length; i++) {
                        var prefix = items[i].parent_id > 0 ? '　└ ' : '';
                        $sel.append('<option value="' + items[i].id + '">' +
                            prefix + items[i].title + '</option>');
                    }
                    form.render('select');
                }, 'json');
            }

            $('#btn-attach').on('click', function () {
                var chapterId = parseInt($('#chapter-id').val() || 0, 10);
                if (!state.resultUrl) {
                    return layer.msg('请先完成上传', {icon: 2});
                }
                if (!chapterId) {
                    return layer.msg('请选择要绑定的章节', {icon: 2});
                }
                $.post(URLS.attach, {
                    course_id: state.courseId,
                    chapter_id: chapterId,
                    url: state.resultUrl
                }, function (res) {
                    if (res.code !== 0) {
                        return layer.msg(res.msg, {icon: 2});
                    }
                    layer.msg('已绑定到「' + res.chapter_title + '」', {icon: 1});
                }, 'json');
            });
        });
    </script>
{% endblock %}

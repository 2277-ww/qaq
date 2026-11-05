# -*- coding: utf-8 -*-
"""阶段一：移除「直播」「面授」功能（前台、教师端、后台、调度、模型分支）。

用法： python phase1_live.py            # 执行
       python phase1_live.py --dry-run  # 只检查匹配，不写盘
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import editlib as E

ROOT = r'C:/ctc/www'


def p(rel):
    return os.path.join(ROOT, rel.replace('/', os.sep))


def run():
    # ---------- 1. 前台：首页 / 公开接口 / 章节 ----------
    E.edit(p('app/Http/Home/Controllers/PublicController.php'), [
        ('use App\\Services\\LiveNotify as LiveNotifyService;\n', ''),
        lambda d: d.drop_method('liveNotifyAction'),
    ])

    E.edit(p('app/Http/Home/Controllers/IndexController.php'), [
        ("        $this->view->setVar('lives', $service->getLives());\n", '', 2),
    ])

    E.edit(p('app/Http/Home/Services/Index.php'), [
        ('use App\\Caches\\IndexLiveList;\n', ''),
        lambda d: d.drop_plain_method('getLives'),
    ])

    E.edit(p('app/Http/Api/Controllers/IndexController.php'), [
        ('use App\\Caches\\IndexLiveList;\n', ''),
        lambda d: d.drop_method('livesAction'),
    ])

    E.edit(p('app/Http/Home/Controllers/ChapterController.php'), [
        ('use App\\Models\\ChapterLive as LiveModel;\n', ''),
        ("""        } elseif ($chapter['model'] == CourseModel::MODEL_LIVE) {
            if ($chapter['status'] == LiveModel::STATUS_FORBID) {
                $this->view->pick('chapter/live/forbid');
            } elseif ($chapter['status'] == LiveModel::STATUS_ACTIVE) {
                $this->view->pick('chapter/live/active');
            } elseif ($chapter['status'] == LiveModel::STATUS_INACTIVE) {
                $this->view->pick('chapter/live/inactive');
            }
        }
""", '        }\n'),
    ])

    # ---------- 2. 章节信息服务 ----------
    E.edit(p('app/Services/Logic/Chapter/BasicInfo.php'), [
        ('use App\\Models\\ChapterLive as ChapterLiveModel;\n', ''),
        ('use App\\Services\\Live as LiveService;\n', ''),
        ("""            case CourseModel::MODEL_LIVE:
                $result = $this->formatChapterLive($chapter);
                break;
""", ''),
        lambda d: d.drop_plain_method('formatChapterLive'),
    ])

    E.edit(p('app/Services/Logic/Chapter/ChapterInfo.php'), [
        ("""            } elseif ($chapter->model == CourseModel::MODEL_LIVE) {
                $result['play_urls'] = new \\stdClass();
""", ''),
    ])

    # ---------- 3. 课程 / 章节模型 ----------
    E.edit(p('app/Models/Chapter.php'), [
        ("""                } elseif ($this->model == Course::MODEL_LIVE) {
                    $this->attrs = $this->_live_attrs;
""", ''),
        ("""                } elseif ($this->model == Course::MODEL_OFFLINE) {
                    $this->attrs = $this->_offline_attrs;
""", ''),
        ("""                case Course::MODEL_LIVE:
                    $live = new ChapterLive();
                    $live->assign($data);
                    $live->create();
                    break;
""", ''),
        ("""                case Course::MODEL_OFFLINE:
                    $offline = new ChapterOffline();
                    $offline->assign($data);
                    $offline->create();
                    break;
""", ''),
        lambda d: d.resub(r"    protected \$_live_attrs = \[.*?\];\n\n", '', flags=re.S),
        lambda d: d.resub(r"    protected \$_offline_attrs = \[.*?\];\n\n", '', flags=re.S),
    ])

    E.edit(p('app/Models/Course.php'), [
        ('    const MODEL_LIVE = 2; // 直播\n', '    const MODEL_LIVE = 2; // 直播（已下线，仅保留常量兼容历史数据）\n'),
        ('    const MODEL_OFFLINE = 4; // 面授\n', '    const MODEL_OFFLINE = 4; // 面授（已下线，仅保留常量兼容历史数据）\n'),
        ("""            } elseif ($this->model == self::MODEL_LIVE) {
                $this->attrs = $this->_live_attrs;
""", ''),
        ("""            } elseif ($this->model == self::MODEL_OFFLINE) {
                $this->attrs = $this->_offline_attrs;
""", ''),
        ('            self::MODEL_LIVE => \'直播\',\n', ''),
        ('            self::MODEL_OFFLINE => \'面授\',\n', ''),
        lambda d: d.resub(r"    protected \$_live_attrs = \[.*?\];\n\n", '', flags=re.S),
        lambda d: d.resub(r"    protected \$_offline_attrs = \[.*?\];\n\n", '', flags=re.S),
    ])

    # ---------- 4. 课程详情视图 ----------
    E.edit(p('app/Http/Home/Views/macros/course.volt'), [
        ("""    {% if value == 1 %}
        点播
    {% elseif value == 2 %}
        直播
    {% elseif value == 3 %}
        图文
    {% elseif value == 4 %}
        面授
    {% endif %}""", """    {% if value == 1 %}
        点播
    {% elseif value == 3 %}
        图文
    {% endif %}"""),
        ("""    {% if value == 1 %}
        <span class="layui-badge layui-bg-green">点播</span>
    {% elseif value == 2 %}
        <span class="layui-badge layui-bg-red">直播</span>
    {% elseif value == 3 %}
        <span class="layui-badge layui-bg-blue">图文</span>
    {% elseif value == 4 %}
        <span class="layui-badge layui-bg-orange">面授</span>
    {% endif %}""", """    {% if value == 1 %}
        <span class="layui-badge layui-bg-green">点播</span>
    {% elseif value == 3 %}
        <span class="layui-badge layui-bg-blue">图文</span>
    {% endif %}"""),
    ])

    E.edit(p('app/Http/Home/Views/course/show_meta.volt'), [
        lambda d: d.drop_macro('live_meta_info'),
        lambda d: d.drop_macro('offline_meta_info'),
        ("""        {% if course.model == 1 %}
            {{ vod_meta_info(course) }}
        {% elseif course.model == 2 %}
            {{ live_meta_info(course) }}
        {% elseif course.model == 3 %}
            {{ read_meta_info(course) }}
        {% elseif course.model == 4 %}
            {{ offline_meta_info(course) }}
        {% endif %}""", """        {% if course.model == 1 %}
            {{ vod_meta_info(course) }}
        {% elseif course.model == 3 %}
            {{ read_meta_info(course) }}
        {% endif %}"""),
    ])

    E.edit(p('app/Http/Home/Views/course/show_catalog.volt'), [
        ("""            {% elseif lesson.model == 2 %}
                <li class="lesson-item {{ priv }}" data-url="{{ url }}">{{ live_lesson_info(lesson) }}</li>
""", ''),
        ("""            {% elseif lesson.model == 4 %}
                <li class="lesson-item deny" data-url="{{ url }}">{{ offline_lesson_info(lesson) }}</li>
""", ''),
        lambda d: d.drop_macro('live_lesson_info'),
        lambda d: d.drop_macro('offline_lesson_info'),
        lambda d: d.drop_macro('live_status_info'),
        lambda d: d.drop_macro('offline_status_info'),
    ])

    # ---------- 5. 教师端 ----------
    E.edit(p('app/Http/Home/Controllers/TeacherConsoleController.php'), [
        ('use App\\Services\\Logic\\Teacher\\Console\\LiveList as LiveListService;\n', ''),
        ('use App\\Services\\Logic\\Teacher\\Console\\LivePushUrl as LivePushUrlService;\n', ''),
        lambda d: d.drop_method('livesAction'),
        lambda d: d.drop_method('liveAction'),
    ])

    E.edit(p('app/Http/Home/Views/teacher/console/menu.volt'), [
        ("            <li><a href=\"{{ url({'for':'home.tc.lives'}) }}\">我的直播</a></li>\n", ''),
    ])

    E.edit(p('app/Http/Home/Views/teacher/show.volt'), [
        ("""                <li class="layui-this">点播课程</li>
                <li>直播课程</li>
                <li>图文课程</li>
                <li>面授课程</li>""", """                <li class="layui-this">点播课程</li>
                <li>图文课程</li>"""),
        ("""                <div class="layui-tabs-item" id="tab-live" data-url="{{ courses_url }}?model=2"></div>
""", ''),
        ("""                <div class="layui-tabs-item" id="tab-offline" data-url="{{ courses_url }}?model=4"></div>
""", ''),
    ])

    # ---------- 6. 后台：设置、章节内容、课程表单 ----------
    E.edit(p('app/Http/Admin/Controllers/SettingController.php'), [
        lambda d: d.drop_method('liveAction'),
    ])

    E.edit(p('app/Http/Admin/Services/Setting.php'), [
        lambda d: d.drop_method('getLiveSettings'),
    ])

    E.edit(p('app/Http/Admin/Services/ChapterContent.php'), [
        ('use App\\Validators\\ChapterLive as ChapterLiveValidator;\n', ''),
        ('use App\\Validators\\ChapterOffline as ChapterOfflineValidator;\n', ''),
        lambda d: d.drop_method('getChapterLive'),
        lambda d: d.drop_method('getChapterOffline'),
        lambda d: d.drop_method('updateChapterLive'),
        lambda d: d.drop_method('updateChapterOffline'),
        ("""            case CourseModel::MODEL_LIVE:
                $this->updateChapterLive($chapter);
                break;
""", ''),
        ("""            case CourseModel::MODEL_OFFLINE:
                $this->updateChapterOffline($chapter);
                break;
""", ''),
    ])

    E.edit(p('app/Http/Admin/Controllers/ChapterController.php'), [
        ('use App\\Models\\ChapterLive as ChapterLiveModel;\n', ''),
        ("""                case CourseModel::MODEL_LIVE:
                    $live = $contentService->getChapterLive($chapter->id);
                    $streamName = ChapterLiveModel::generateStreamName($chapter->id);
                    $this->view->setVar('live', $live);
                    $this->view->setVar('stream_name', $streamName);
                    break;
""", ''),
        ("""                case CourseModel::MODEL_OFFLINE:
                    $offline = $contentService->getChapterOffline($chapter->id);
                    $this->view->setVar('offline', $offline);
                    break;
""", ''),
    ])

    E.edit(p('app/Http/Admin/Views/course/add.volt'), [
        ("""                '2': '通过直播呈现课程内容，交互性强，适合需要交互反馈、情绪表达的场景',
""", ''),
        ("""                '4': '面对面讲授课程内容，传统教学，适合有条件开展线下教学的场景',
""", ''),
    ])

    E.edit(p('app/Http/Admin/Views/course/edit.volt'), [
        ("""            {% if course.model == 4 %}
                <li>面授信息</li>
            {% endif %}
""", ''),
        ("""            {% if course.model == 4 %}
                <div class="layui-tabs-item">
                    {{ partial('course/edit_offline') }}
                </div>
            {% endif %}
""", ''),
    ])

    E.edit(p('app/Http/Admin/Views/chapter/edit_lesson.volt'), [
        ("""        {% if model == '1' %}
            点播信息
        {% elseif model == '2' %}
            直播信息
        {% elseif model == '3' %}
            图文信息
        {% elseif model == '4' %}
            面授信息
        {% endif %}""", """        {% if model == '1' %}
            点播信息
        {% elseif model == '3' %}
            图文信息
        {% endif %}"""),
        ("""                {% elseif course.model == 2 %}
                    {{ partial('chapter/edit_lesson_live') }}
""", ''),
        ("""                {% elseif course.model == 4 %}
                    {{ partial('chapter/edit_lesson_offline') }}
""", ''),
        ("""            laydate.render({
                elem: 'input[name=start_time]',
                type: 'datetime'
            });

            laydate.render({
                elem: 'input[name=end_time]',
                type: 'datetime'
            });

            $('#show-push-test').on('click', function () {
                var streamName = $('input[name=stream_name]').val();
                var url = '/admin/test/live/push?stream=' + streamName;
                layer.open({
                    type: 2,
                    title: '推流测试',
                    area: ['720px', '540px'],
                    content: [url, 'no']
                });
            });

""", ''),
        ("layui.use(['jquery', 'layer', 'laydate'], function () {", "layui.use(['jquery', 'layer'], function () {"),
    ])

    E.edit(p('app/Http/Admin/Services/Package.php'), [
        ("""        /**
         * 面授课程不参与套餐计划，因为无法进行退款计算
         */
        $model = [
            CourseModel::MODEL_VOD,
            CourseModel::MODEL_LIVE,
            CourseModel::MODEL_READ,
        ];""", """        /**
         * 仅点播与图文课程可加入套餐计划
         */
        $model = [
            CourseModel::MODEL_VOD,
            CourseModel::MODEL_READ,
        ];"""),
    ])

    E.edit(p('app/Http/Admin/Controllers/TestController.php'), [
        ('use App\\Services\\Live as LiveService;\n', ''),
        lambda d: d.drop_method('livePushAction'),
        lambda d: d.drop_method('livePullAction'),
    ])

    # ---------- 7. 校验器 / 仓储 / URL ----------
    E.edit(p('app/Validators/Chapter.php'), [
        ("""        } elseif ($chapter->model == CourseModel::MODEL_LIVE) {
            if ($attrs['start_time'] == 0) {
                throw new BadRequestException('chapter.live_time_empty');
            }
""", ''),
        ("""        } elseif ($chapter->model == CourseModel::MODEL_OFFLINE) {
            if ($attrs['start_time'] == 0) {
                throw new BadRequestException('chapter.offline_time_empty');
            }
""", ''),
        lambda d: d.drop_method('checkChapterLive'),
    ])

    E.edit(p('app/Repos/Chapter.php'), [
        ('use App\\Models\\ChapterLive as ChapterLiveModel;\n', ''),
        ('use App\\Models\\ChapterOffline as ChapterOfflineModel;\n', ''),
        lambda d: d.drop_method('findChapterLive'),
        lambda d: d.drop_method('findChapterOffline'),
    ])

    E.edit(p('app/Services/Logic/Url/FullH5Url.php'), [
        ("""        } elseif ($chapter->model == CourseModel::MODEL_LIVE) {
            return $this->getFullUrl('/chapter/live', ['id' => $id]);
""", ''),
    ])

    # ---------- 8. 统计 / 学习同步 ----------
    E.edit(p('app/Services/CourseStat.php'), [
        ("""        } elseif ($course->model == CourseModel::MODEL_LIVE) {
            $this->updateLiveAttrs($course->id);
""", ''),
        ("""        } elseif ($course->model == CourseModel::MODEL_OFFLINE) {
            $this->updateOfflineAttrs($course->id);
""", ''),
        lambda d: d.drop_plain_method('updateLiveAttrs'),
        lambda d: d.drop_plain_method('updateOfflineAttrs'),
    ])

    E.edit(p('app/Console/Tasks/SyncLearningTask.php'), [
        ("""        } elseif ($chapter->model == CourseModel::MODEL_LIVE) {

            $chapterUser->consumed = $chapterUser->duration > 600 ? 1 : 0;

""", ''),
    ])

    # ---------- 9. 调度与通知任务 ----------
    E.edit(p('scheduler.php'), [
        ("""$scheduler->php($script, $bin, ['--task' => 'teacher_live_notice', '--action' => 'consume'])
    ->everyMinute(9);

""", ''),
        ("""$scheduler->php($script, $bin, ['--task' => 'close_live', '--action' => 'main'])
    ->hourly(31);

""", ''),
        ("""$scheduler->php($script, $bin, ['--task' => 'teacher_live_notice', '--action' => 'provide'])
    ->daily(4, 7);

""", ''),
    ])

    E.edit(p('app/Console/Tasks/NoticeTask.php'), [
        ('use App\\Services\\Logic\\Notice\\External\\DingTalk\\TeacherLive as TeacherLiveNotice;\n', ''),
        ("""                    case TaskModel::TYPE_STAFF_NOTICE_TEACHER_LIVE:
                        $this->handleTeacherLiveNotice($task);
                        break;
""", ''),
        lambda d: d.drop_method('handleTeacherLiveNotice'),
    ])

    # ---------- 10. 删除文件 ----------
    E.remove([p(x) for x in [
        'app/Http/Home/Controllers/LiveController.php',
        'app/Http/Api/Controllers/LiveController.php',
        'app/Http/Home/Views/chapter/live',
        'app/Http/Home/Views/teacher/console/lives.volt',
        'app/Http/Home/Views/teacher/console/live.volt',
        'app/Services/Live.php',
        'app/Services/LiveNotify.php',
        'app/Services/Logic/Live',
        'app/Services/Logic/Teacher/Console/LiveList.php',
        'app/Services/Logic/Teacher/Console/LivePushUrl.php',
        'app/Services/Logic/Notice/External/DingTalk/TeacherLive.php',
        'app/Caches/IndexLiveList.php',
        'app/Console/Tasks/CloseLiveTask.php',
        'app/Console/Tasks/TeacherLiveNoticeTask.php',
        'app/Repos/ChapterLive.php',
        'app/Repos/TeacherLive.php',
        'app/Models/ChapterLive.php',
        'app/Models/ChapterOffline.php',
        'app/Validators/ChapterLive.php',
        'app/Validators/ChapterOffline.php',
        'app/Builders/LiveList.php',
        'public/static/home/js/chapter.live.chat.js',
        'public/static/home/js/chapter.live.countdown.js',
        'public/static/home/js/chapter.live.player.js',
        'app/Http/Admin/Views/setting/live.volt',
        'app/Http/Admin/Views/setting/live_notify.volt',
        'app/Http/Admin/Views/setting/live_pull.volt',
        'app/Http/Admin/Views/setting/live_pull_test.volt',
        'app/Http/Admin/Views/setting/live_push.volt',
        'app/Http/Admin/Views/setting/live_push_test.volt',
        'app/Http/Admin/Views/chapter/edit_lesson_live.volt',
        'app/Http/Admin/Views/chapter/edit_lesson_offline.volt',
        'app/Http/Admin/Views/course/edit_offline.volt',
    ]])


if __name__ == '__main__':
    if '--dry-run' in sys.argv:
        print('dry-run 模式：仅校验匹配，不写盘')
        _orig_save = E.Doc.save
        E.Doc.save = lambda self: None
    run()
    print('阶段一完成')

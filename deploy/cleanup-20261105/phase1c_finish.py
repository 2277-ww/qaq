# -*- coding: utf-8 -*-
"""阶段一收尾：通知任务清理 + 文件删除（scheduler.php 已在前一次执行中处理）。"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import editlib as E

ROOT = r'C:/ctc/www'
def p(rel):
    return os.path.join(ROOT, rel.replace('/', os.sep))

E.edit(p('app/Console/Tasks/NoticeTask.php'), [
    ('use App\\Services\\Logic\\Notice\\External\\DingTalk\\TeacherLive as TeacherLiveNotice;\n', ''),
    ("""                    case TaskModel::TYPE_STAFF_NOTICE_TEACHER_LIVE:
                        $this->handleTeacherLiveNotice($task);
                        break;
""", ''),
    lambda d: d.drop_method('handleTeacherLiveNotice'),
])

targets = [
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
]

missing = [t for t in targets if not os.path.exists(p(t))]
E.remove([p(t) for t in targets if os.path.exists(p(t))])
if missing:
    print('已不存在（跳过）：', len(missing))
print('阶段一收尾完成')

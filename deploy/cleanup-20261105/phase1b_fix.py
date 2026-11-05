# -*- coding: utf-8 -*-
"""阶段一补丁：清理剩余的面授 / 直播残留分支。"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import editlib as E

ROOT = r'C:/ctc/www'
def p(rel):
    return os.path.join(ROOT, rel.replace('/', os.sep))

E.edit(p('app/Services/Logic/ChapterTrait.php'), [
    lambda d: d.drop_plain_method('checkChapterLive'),
])

E.edit(p('app/Http/Admin/Services/Course.php'), [
    ("""
        if ($course->model == CourseModel::MODEL_OFFLINE) {

            $validator = new CourseOfflineValidator();

            $data['study_expiry'] = 0;
            $data['refund_expiry'] = 0;

            if (isset($post['attrs']['start_date']) && isset($post['attrs']['end_date'])) {
                $data['attrs']['start_date'] = $validator->checkStartDate($post['attrs']['start_date']);
                $data['attrs']['end_date'] = $validator->checkEndDate($post['attrs']['end_date']);
                $validator->checkDateRange($data['attrs']['start_date'], $data['attrs']['end_date']);
            }

            if (isset($post['attrs']['user_limit'])) {
                $data['attrs']['user_limit'] = $validator->checkUserLimit($post['attrs']['user_limit']);
            }

            if (isset($post['attrs']['location'])) {
                $data['attrs']['location'] = $validator->checkLocation($post['attrs']['location']);
            }
        }
""", ''),
    ('use App\\Validators\\CourseOffline as CourseOfflineValidator;\n', ''),
])

E.edit(p('app/Services/Logic/Deliver/CourseDeliver.php'), [
    ("""        if ($course->model == CourseModel::MODEL_OFFLINE) {
            $expiryTime = strtotime($course->attrs['end_date']);
        }

""", ''),
])

E.edit(p('app/Services/Logic/Course/CourseInfo.php'), [
    ("""        $caseOwned = $this->ownedCourse == false;
        $casePrice = $course->market_price > 0;
        $caseModel = true;

        /**
         * 过期直播不允许购买
         */
        if ($course->model == CourseModel::MODEL_LIVE) {
            $caseModel = $course->attrs['end_date'] < date('Y-m-d');
        }
""", """        $caseOwned = $this->ownedCourse == false;
        $casePrice = $course->market_price > 0;
"""),
    ("""            if ($caseOwned && $casePrice && $caseModel) {
                $me['allow_order'] = 1;
            }

            if ($this->ownedCourse && $course->model != CourseModel::MODEL_OFFLINE) {
                $me['allow_study'] = 1;
            }""", """            if ($this->ownedCourse) {
                $me['allow_study'] = 1;
            }"""),
])

print('阶段一补丁完成')

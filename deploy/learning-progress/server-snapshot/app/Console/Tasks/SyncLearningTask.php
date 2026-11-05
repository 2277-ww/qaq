<?php
/**
 * @copyright Copyright (c) 2021 深圳市酷瓜软件有限公司
 * @license https://opensource.org/licenses/GPL-2.0
 * @link https://www.koogua.com
 */

namespace App\Console\Tasks;

use App\Models\ChapterUser as ChapterUserModel;
use App\Models\Course as CourseModel;
use App\Models\CourseUser as CourseUserModel;
use App\Models\Learning as LearningModel;
use App\Repos\Chapter as ChapterRepo;
use App\Repos\ChapterUser as ChapterUserRepo;
use App\Repos\Course as CourseRepo;
use App\Repos\CourseUser as CourseUserRepo;
use App\Repos\Learning as LearningRepo;
use App\Services\Growth\Collect as GrowthCollect;
use App\Services\Learning\Collect as ExamCollect;
use App\Services\Logic\Growth\Sync as GrowthSync;
use App\Services\Logic\Learning\Sync as ExamSync;
use App\Services\Logic\Point\History\ChapterStudy as ChapterStudyPointHistory;
use App\Services\Sync\Learning as LearningSyncService;

class SyncLearningTask extends Task
{

    public function mainAction()
    {
        $redis = $this->getRedis();

        $sync = new LearningSyncService();

        $syncKey = $sync->getSyncKey();

        $requestIds = $redis->sMembers($syncKey);

        if (!$requestIds) return;

        foreach ($requestIds as $requestId) {

            $itemKey = $sync->getItemKey($requestId);

            $this->handleLearning($itemKey);

            $redis->sRem($syncKey, $requestId);
        }

        /**
         * 学习事实落库后立刻投递成长档案事件，避免事件积压
         */
        $growthSync = new GrowthSync();

        $growthSync->flush(0, 500);

        /**
         * 学习进度事件投递到考试平台（单次限量，避免拖慢同步任务）
         */
        $examSync = new ExamSync();

        $examSync->flush(0, 20);
    }

    /**
     * @param string $itemKey
     */
    protected function handleLearning($itemKey)
    {
        $cache = $this->getCache();

        /**
         * @var LearningModel|null $cacheLearning
         */
        $cacheLearning = $cache->get($itemKey);

        if (!$cacheLearning) return;

        $learningRepo = new LearningRepo();

        $dbLearning = $learningRepo->findByRequestId($cacheLearning->request_id);

        if (!$dbLearning) {

            $cacheLearning->create();

            $this->updateChapterUser($cacheLearning);

        } else {

            $dbLearning->duration = $cacheLearning->duration;
            $dbLearning->position = $cacheLearning->position;
            $dbLearning->active_time = $cacheLearning->active_time;

            $dbLearning->update();

            $this->updateChapterUser($dbLearning);
        }

        $cache->delete($itemKey);
    }

    /**
     * @param LearningModel $learning
     */
    protected function updateChapterUser(LearningModel $learning)
    {
        $chapterUserRepo = new ChapterUserRepo();

        $chapterUser = $chapterUserRepo->findPlanChapterUser($learning->chapter_id, $learning->user_id, $learning->plan_id);

        if (!$chapterUser) return;

        $chapterRepo = new ChapterRepo();

        $chapter = $chapterRepo->findById($learning->chapter_id);

        if (!$chapter) return;

        $chapterUser->duration += $learning->duration;

        /**
         * 消费规则
         *
         * 1.点播观看时间大于时长30%
         * 2.直播观看时间超过10分钟
         * 3.图文浏览即消费
         */
        if ($chapter->model == CourseModel::MODEL_VOD) {

            $duration = $chapter->attrs['duration'] ?: 300;

            $progress = floor(100 * $chapterUser->duration / $duration);

            /**
             * 过于接近结束位置当作已结束处理，播放位置为起点０
             */
            $playPosition = $duration - $learning->position > 10 ? floor($learning->position) : 0;

            $chapterUser->position = $playPosition;
            $chapterUser->progress = $progress < 100 ? $progress : 100;
            $chapterUser->consumed = $chapterUser->duration > 0.3 * $duration ? 1 : 0;

        } elseif ($chapter->model == CourseModel::MODEL_LIVE) {

            $chapterUser->consumed = $chapterUser->duration > 600 ? 1 : 0;

        } elseif ($chapter->model == CourseModel::MODEL_READ) {

            $chapterUser->consumed = 1;
        }

        /**
         * 学习状态与完成时间
         *
         * 状态机见 SRS 3.4.4：首次上报任意进度即进入学习中；
         * 达到完成标准写入完成时间，此后不再变化。
         */
        if (empty($chapterUser->first_time)) {
            $chapterUser->first_time = $learning->active_time ?: time();
        }

        $wasCompleted = !empty($chapterUser->complete_time);

        $chapterUser->status = $chapterUser->consumed == 1
            ? ChapterUserModel::STATUS_COMPLETED
            : ChapterUserModel::STATUS_LEARNING;

        if ($chapterUser->status == ChapterUserModel::STATUS_COMPLETED && !$wasCompleted) {
            $chapterUser->complete_time = $learning->active_time ?: time();
        }

        $chapterUser->update();

        if ($chapterUser->consumed == 1) {

            if (!$wasCompleted) {
                $this->collectLessonCompleted($chapterUser, $chapter);
            }

            $this->updateCourseUser($learning);

            $this->handleStudyPoint($chapterUser);
        }
    }

    /**
     * 课时完成事件入箱
     */
    protected function collectLessonCompleted(ChapterUserModel $chapterUser, $chapter)
    {
        $courseRepo = new CourseRepo();

        $course = $courseRepo->findById($chapter->course_id);

        if (!$course) return;

        $collect = new GrowthCollect();

        $collect->lessonCompleted($chapterUser, $chapter, $course);
    }

    /**
     * @param LearningModel $learning
     */
    protected function updateCourseUser(LearningModel $learning)
    {
        $courseUserRepo = new CourseUserRepo();

        $courseUser = $courseUserRepo->findPlanCourseUser($learning->course_id, $learning->user_id, $learning->plan_id);

        if (!$courseUser) return;

        $courseRepo = new CourseRepo();

        $courseLessons = $courseRepo->findLessons($learning->course_id);

        if ($courseLessons->count() == 0) return;

        $userLearnings = $courseRepo->findUserLearnings($learning->course_id, $learning->user_id, $learning->plan_id);

        if ($userLearnings->count() == 0) return;

        $consumedUserLearnings = [];

        foreach ($userLearnings->toArray() as $userLearning) {
            if ($userLearning['consumed'] == 1) {
                $consumedUserLearnings[] = $userLearning;
            }
        }

        if (count($consumedUserLearnings) == 0) return;

        $duration = 0;

        foreach ($consumedUserLearnings as $userLearning) {
            $duration += $userLearning['duration'];
        }

        $courseLessonIds = kg_array_column($courseLessons->toArray(), 'id');
        $consumedUserLessonIds = kg_array_column($consumedUserLearnings, 'chapter_id');
        $consumedLessonIds = array_intersect($courseLessonIds, $consumedUserLessonIds);

        $totalCount = count($courseLessonIds);
        $consumedCount = count($consumedLessonIds);
        $progress = intval(100 * $consumedCount / $totalCount);

        $wasCompleted = $courseUser->status == CourseUserModel::STATUS_COMPLETED
            || !empty($courseUser->complete_time);

        $courseUser->progress = $progress;
        $courseUser->duration = $duration;
        $courseUser->active_time = $learning->active_time;
        $courseUser->completed_count = $consumedCount;
        $courseUser->total_count = $totalCount;

        if (empty($courseUser->first_time)) {
            $courseUser->first_time = $learning->active_time ?: time();
        }

        $courseUser->status = $consumedCount >= $totalCount
            ? CourseUserModel::STATUS_COMPLETED
            : CourseUserModel::STATUS_LEARNING;

        if ($courseUser->status == CourseUserModel::STATUS_COMPLETED && empty($courseUser->complete_time)) {
            $courseUser->complete_time = $learning->active_time ?: time();
            $courseUser->complete_version = 1;
        }

        $courseUser->update();

        $course = $courseRepo->findById($learning->course_id);

        if ($course) {

            /**
             * 进度变化入箱，经网关增量推送给考试平台
             * 节流与去重由 ExamCollect 内部处理（单调递增 + 最小增量 + 完成事实去重）
             */
            $examCollect = new ExamCollect();

            $examCollect->progressUpdated($courseUser, $course);

            /**
             * 首次完成课程时投递 course.completed 到成长档案
             */
            if ($courseUser->status == CourseUserModel::STATUS_COMPLETED && !$wasCompleted) {

                $collect = new GrowthCollect();
                $collect->courseCompleted($courseUser, $course);
            }
        }
    }

    /**
     * @param ChapterUserModel $chapterUser
     */
    protected function handleStudyPoint(ChapterUserModel $chapterUser)
    {
        $service = new ChapterStudyPointHistory();

        $service->handle($chapterUser);
    }

}

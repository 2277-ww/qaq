<?php
/**
 * 学习进度视图聚合
 *
 * 一处口径，三处复用：
 * 1) 「学习进度」窗口（学生视角，含推送状态）；
 * 2) 对外接口 GET /api/v1/learning/progress/{userId}（考试平台/成长档案取数）；
 * 3) 对外接口 GET /api/v1/learning/completion/{userId}/{courseId}（考试准入回源）。
 *
 * 口径：课程进度 = 已完成课时 / 课程总课时；完成状态由 kg_course_user.status 判定。
 * 进度数据只读本平台事实表，不反向读取考试平台数据。
 */

namespace App\Services\Logic\Learning;

use App\Exceptions\BadRequest as BadRequestException;
use App\Models\CourseUser as CourseUserModel;
use App\Models\ExamOutbox as ExamOutboxModel;
use App\Repos\Course as CourseRepo;
use App\Repos\ExamOutbox as ExamOutboxRepo;
use App\Services\Learning\IdentityKey;
use App\Services\Logic\Service as LogicService;
use App\Validators\User as UserValidator;

class Progress extends LogicService
{

    const RULE_VERSION = 'v1';

    /**
     * 窗口数据（当前登录用户）
     *
     * @return array
     */
    public function handle()
    {
        $user = $this->getLoginUser();

        $data = $this->build($user->id);

        $sync = new Sync();

        $data['sync'] = $sync->stats($user->id);

        return $data;
    }

    /**
     * 全量进度快照（接口）
     *
     * @param int $userId
     * @return array
     */
    public function snapshot($userId)
    {
        $user = $this->checkUser($userId);

        $data = $this->build($user->id);

        $identity = new IdentityKey();

        return [
            'userId' => $identity->forUserId($user->id),
            'overview' => $data['overview'],
            'courses' => $data['courses'],
            'ruleVersion' => self::RULE_VERSION,
            'generatedAt' => gmdate('Y-m-d\TH:i:s\Z'),
        ];
    }

    /**
     * 单课程进度明细（接口）
     *
     * @param int $userId
     * @param int $courseId
     * @return array
     */
    public function courseDetail($userId, $courseId)
    {
        $completion = $this->completion($userId, $courseId);

        $courseUser = $this->findCourseUser($userId, $courseId);

        $completion['durationSec'] = (int)$courseUser->duration;
        $completion['firstLearnedAt'] = $courseUser->first_time > 0
            ? gmdate('Y-m-d\TH:i:s\Z', $courseUser->first_time) : null;
        $completion['lastActiveAt'] = $courseUser->active_time > 0
            ? gmdate('Y-m-d\TH:i:s\Z', $courseUser->active_time) : null;

        return $completion;
    }

    /**
     * 课程完成状态（考试平台判准入的权威回源点）
     *
     * @param int $userId
     * @param int $courseId
     * @return array
     */
    public function completion($userId, $courseId)
    {
        $user = $this->checkUser($userId);

        $courseUser = $this->findCourseUser($user->id, $courseId);

        $identity = new IdentityKey();

        $completed = (int)$courseUser->status == CourseUserModel::STATUS_COMPLETED;

        $completedAt = $courseUser->complete_time > 0
            ? gmdate('Y-m-d\TH:i:s\Z', $courseUser->complete_time) : null;

        return [
            'userId' => $identity->forUserId($user->id),
            'courseId' => 'course_' . (int)$courseId,
            'completed' => $completed,
            'progress' => (int)$courseUser->progress,
            'completedChapters' => (int)$courseUser->completed_count,
            'totalChapters' => (int)$courseUser->total_count,
            'completedAt' => $completedAt,
            'recordId' => 'rec_' . (int)$courseUser->id,
            'ruleVersion' => self::RULE_VERSION,
        ];
    }

    /**
     * @param int $userId
     * @return array
     */
    protected function build($userId)
    {
        $rows = CourseUserModel::find([
            'conditions' => 'user_id = :user_id: AND deleted = 0',
            'bind' => ['user_id' => $userId],
            'order' => 'active_time DESC, id DESC',
        ]);

        $courseUsers = $rows ? $rows->toArray() : [];

        $courseMap = $this->getCourses($courseUsers);

        $latestPush = (new ExamOutboxRepo())->findLatestPerCourse($userId);

        $courses = [];
        $completedTotal = 0;
        $learningTotal = 0;
        $duration = 0;
        $lessonTotal = 0;
        $lessonCompleted = 0;
        $progressSum = 0;

        foreach ($courseUsers as $row) {

            $courseId = (int)$row['course_id'];

            if (!isset($courseMap[$courseId])) continue;

            $status = (int)$row['status'];

            if ($status == CourseUserModel::STATUS_COMPLETED) {
                $completedTotal++;
            } elseif ($status == CourseUserModel::STATUS_LEARNING || (int)$row['progress'] > 0) {
                $learningTotal++;
            }

            $duration += (int)$row['duration'];
            $lessonTotal += (int)$row['total_count'];
            $lessonCompleted += (int)$row['completed_count'];
            $progressSum += (int)$row['progress'];

            $push = $latestPush[$courseId] ?? null;

            $courses[] = [
                'course_id' => $courseId,
                'course_title' => $courseMap[$courseId]['title'],
                'progress' => (int)$row['progress'],
                'status' => $status,
                'status_text' => $this->statusText($status),
                'completed_count' => (int)$row['completed_count'],
                'total_count' => (int)$row['total_count'],
                'duration_text' => $this->formatDuration($row['duration']),
                'last_active_text' => $row['active_time'] > 0 ? date('Y-m-d H:i', $row['active_time']) : '',
                'complete_text' => $row['complete_time'] > 0 ? date('Y-m-d', $row['complete_time']) : '',
                'push' => $this->formatPush($push),
            ];
        }

        $courseTotal = count($courses);

        $overview = [
            'course_total' => $courseTotal,
            'completed_total' => $completedTotal,
            'learning_total' => $learningTotal,
            'lesson_completed' => $lessonCompleted,
            'lesson_total' => $lessonTotal,
            'duration_text' => $this->formatDuration($duration),
            'avg_progress' => $courseTotal > 0 ? intval($progressSum / $courseTotal) : 0,
        ];

        return [
            'overview' => $overview,
            'courses' => $courses,
            'timeline' => $this->buildTimeline($userId, $courseMap),
        ];
    }

    /**
     * @param array $courseUsers
     * @return array
     */
    protected function getCourses(array $courseUsers)
    {
        if (count($courseUsers) == 0) return [];

        $courseIds = kg_array_column($courseUsers, 'course_id');

        $courseRepo = new CourseRepo();

        $courses = $courseRepo->findByIds($courseIds, 'id, title, cover');

        $map = [];

        if ($courses) {
            foreach ($courses->toArray() as $row) {
                $map[(int)$row['id']] = $row;
            }
        }

        return $map;
    }

    /**
     * @param ExamOutboxModel|null $push
     * @return array
     */
    protected function formatPush($push)
    {
        if (!$push) {
            return [
                'status' => -1,
                'status_text' => '未推送',
                'status_class' => 'layui-bg-gray',
                'event_id' => '',
                'progress' => 0,
                'time_text' => '',
                'retry_count' => 0,
                'last_error' => '',
            ];
        }

        $status = (int)$push->status;

        $classes = [
            ExamOutboxModel::STATUS_PENDING => 'layui-bg-gray',
            ExamOutboxModel::STATUS_SENT => 'layui-bg-green',
            ExamOutboxModel::STATUS_FAILED => 'layui-bg-orange',
            ExamOutboxModel::STATUS_DEAD => 'layui-bg-red',
        ];

        $time = $push->sent_at > 0 ? $push->sent_at : $push->occurred_at;

        return [
            'status' => $status,
            'status_text' => $push->getStatusText(),
            'status_class' => $classes[$status] ?? 'layui-bg-gray',
            'event_id' => $push->event_id,
            'progress' => (int)$push->progress,
            'time_text' => $time > 0 ? date('Y-m-d H:i', $time) : '',
            'retry_count' => (int)$push->retry_count,
            'last_error' => (string)$push->last_error,
        ];
    }

    /**
     * @param int $userId
     * @param array $courseMap
     * @return array
     */
    protected function buildTimeline($userId, array $courseMap)
    {
        $repo = new ExamOutboxRepo();

        $rows = $repo->findTimeline($userId, 15);

        if (!$rows) return [];

        $labels = [
            ExamOutboxModel::TYPE_PROGRESS => '进度上报',
            ExamOutboxModel::TYPE_COMPLETED => '课程完成',
        ];

        $items = [];

        foreach ($rows as $row) {

            $courseId = (int)$row->course_id;

            $items[] = [
                'event_id' => $row->event_id,
                'event_label' => $labels[$row->event_type] ?? $row->event_type,
                'course_title' => $courseMap[$courseId]['title'] ?? ('课程 #' . $courseId),
                'progress' => (int)$row->progress,
                'status' => (int)$row->status,
                'status_text' => $row->getStatusText(),
                'response_code' => (int)$row->response_code,
                'retry_count' => (int)$row->retry_count,
                'time_text' => date('Y-m-d H:i:s', (int)$row->occurred_at),
                'last_error' => (string)$row->last_error,
            ];
        }

        return $items;
    }

    /**
     * @param int $userId
     * @param int $courseId
     * @return CourseUserModel|\Phalcon\Mvc\Model
     */
    protected function findCourseUser($userId, $courseId)
    {
        $row = CourseUserModel::findFirst([
            'conditions' => 'user_id = :user_id: AND course_id = :course_id: AND deleted = 0',
            'bind' => ['user_id' => $userId, 'course_id' => $courseId],
            'order' => 'id DESC',
        ]);

        if (!$row) {
            throw new BadRequestException('course_user.not_found');
        }

        return $row;
    }

    /**
     * @param int $userId
     * @return \App\Models\User
     */
    protected function checkUser($userId)
    {
        $validator = new UserValidator();

        return $validator->checkUser((int)$userId);
    }

    /**
     * @param int $status
     * @return string
     */
    protected function statusText($status)
    {
        $map = [
            CourseUserModel::STATUS_NONE => '未开始',
            CourseUserModel::STATUS_LEARNING => '学习中',
            CourseUserModel::STATUS_COMPLETED => '已完成',
        ];

        return $map[$status] ?? '学习中';
    }

    /**
     * @param int $seconds
     * @return string
     */
    protected function formatDuration($seconds)
    {
        $seconds = (int)$seconds;

        if ($seconds <= 0) return '0 分钟';

        $hours = intval($seconds / 3600);
        $minutes = intval(($seconds % 3600) / 60);

        if ($hours > 0) {
            return sprintf('%d 小时 %d 分钟', $hours, $minutes);
        }

        if ($minutes > 0) {
            return sprintf('%d 分钟', $minutes);
        }

        return sprintf('%d 秒', $seconds);
    }

}

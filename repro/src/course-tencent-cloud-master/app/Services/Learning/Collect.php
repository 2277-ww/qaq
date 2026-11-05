<?php
/**
 * 学习进度事件入箱
 *
 * 把「课程进度」这一业务事实转成符合跨平台事件目录的封套，写入发件箱。
 * 封套字段与取值口径对齐《自学平台统一身份与网关接入说明》8.2：
 * eventId / eventType / eventVersion / occurredAt / sourcePlatform /
 * sourceEntityId / actorId / correlationId / requestId / data。
 *
 * 纪律：跨平台通道只发目录内事件。learning.progress.updated 为进度增量，
 * course.completed 为完成事实，两者都由考试平台订阅。
 */

namespace App\Services\Learning;

use App\Models\Course as CourseModel;
use App\Models\CourseUser as CourseUserModel;
use App\Models\ExamOutbox as ExamOutboxModel;
use App\Repos\ExamOutbox as ExamOutboxRepo;
use App\Services\Service;

class Collect extends Service
{

    const EVENT_VERSION = '1.0';

    const SOURCE_PLATFORM = 'learning';

    const RULE_VERSION = 'v1';

    /**
     * 进度变化入库
     *
     * 节流口径（避免高频上报打满网关）：
     * 1) 进度必须单调不减；
     * 2) 距上次上报不足 min_progress_delta 个百分点时跳过；
     * 3) 完成事实只入箱一次。
     *
     * @param CourseUserModel $courseUser
     * @param CourseModel $course
     * @param string $actorKey 操作者对外主键，留空取本人
     * @param string $requestId 单次请求 ID，留空自动生成
     * @return ExamOutboxModel|null
     */
    public function progressUpdated(CourseUserModel $courseUser, CourseModel $course, $actorKey = '', $requestId = '')
    {
        if ($courseUser->user_id <= 0 || $course->id <= 0) return null;

        if (!$this->isEnabled()) return null;

        $progress = (int)$courseUser->progress;

        if ($progress <= 0) return null;

        $completed = (int)$courseUser->status == CourseUserModel::STATUS_COMPLETED;

        $eventType = $completed ? ExamOutboxModel::TYPE_COMPLETED : ExamOutboxModel::TYPE_PROGRESS;

        $repo = new ExamOutboxRepo();

        if ($completed) {

            if ($repo->existsFact($eventType, $courseUser->user_id, $course->id, self::EVENT_VERSION)) {
                return null;
            }

        } else {

            $lastProgress = $repo->findLastProgress($courseUser->user_id, $course->id);

            if ($progress <= $lastProgress) return null;

            $minDelta = (int)$this->getConfig()->path('exam.min_progress_delta', 5);

            if ($lastProgress > 0 && ($progress - $lastProgress) < $minDelta) return null;
        }

        $identity = new IdentityKey();

        $userKey = $identity->forUserId($courseUser->user_id);

        $actorKey = $actorKey !== '' ? $actorKey : $userKey;

        $eventId = $this->makeEventId();

        $requestId = $requestId !== '' ? $requestId : (new Gateway())->makeRequestId();

        $data = [
            'userId' => $userKey,
            'courseId' => 'course_' . $course->id,
            'courseTitle' => (string)$course->title,
            'progress' => $progress,
            'completedChapters' => (int)$courseUser->completed_count,
            'totalChapters' => (int)$courseUser->total_count,
            'durationSec' => (int)$courseUser->duration,
            'completed' => $completed,
            'completedAt' => $completed && $courseUser->complete_time > 0
                ? $this->formatTime($courseUser->complete_time)
                : null,
            'status' => $completed ? 'completed' : 'learning',
            'ruleVersion' => self::RULE_VERSION,
        ];

        $payload = [
            'eventId' => $eventId,
            'eventType' => $eventType,
            'eventVersion' => self::EVENT_VERSION,
            'occurredAt' => $this->formatTime(null),
            'sourcePlatform' => self::SOURCE_PLATFORM,
            'sourceEntityId' => 'course_' . $course->id,
            'actorId' => $actorKey,
            'correlationId' => $this->makeCorrelationId(),
            'requestId' => $requestId,
            'data' => $data,
        ];

        $outbox = new ExamOutboxModel();

        $outbox->event_id = $eventId;
        $outbox->event_type = $eventType;
        $outbox->event_version = self::EVENT_VERSION;
        $outbox->user_id = (int)$courseUser->user_id;
        $outbox->course_id = (int)$course->id;
        $outbox->user_key = $userKey;
        $outbox->course_key = 'course_' . $course->id;
        $outbox->progress = $progress;
        $outbox->payload = kg_json_encode($payload);
        $outbox->status = ExamOutboxModel::STATUS_PENDING;
        $outbox->retry_count = 0;
        $outbox->next_retry_at = 0;
        $outbox->request_id = $requestId;
        $outbox->occurred_at = time();
        $outbox->create_time = time();

        $outbox->create();

        return $outbox;
    }

    /**
     * 是否开启向考试平台推送
     *
     * @return bool
     */
    public function isEnabled()
    {
        return (bool)$this->getConfig()->path('exam.enabled', true);
    }

    /**
     * 事件编号：evt_ + 20 位十六进制
     *
     * @return string
     */
    protected function makeEventId()
    {
        try {
            $raw = bin2hex(random_bytes(10));
        } catch (\Exception $e) {
            $raw = substr(md5(uniqid('', true) . mt_rand()), 0, 20);
        }

        return 'evt_' . strtoupper($raw);
    }

    /**
     * 业务流程串联 ID
     *
     * @return string
     */
    protected function makeCorrelationId()
    {
        try {
            $raw = bin2hex(random_bytes(6));
        } catch (\Exception $e) {
            $raw = substr(md5(uniqid('', true)), 0, 12);
        }

        return 'flow_' . strtoupper($raw);
    }

    /**
     * RFC 3339 UTC（Z）时间
     *
     * @param int|null $timestamp 空表示取当前时间
     * @return string
     */
    protected function formatTime($timestamp = null)
    {
        $timestamp = $timestamp === null ? time() : (int)$timestamp;

        return gmdate('Y-m-d\TH:i:s\Z', $timestamp);
    }

}

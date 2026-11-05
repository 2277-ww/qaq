<?php
/**
 * 学习进度事件入箱
 *
 * 把「课程进度」这一业务事实转成符合跨平台事件目录的封套，写入发件箱。
 * 封套字段与取值口径对齐《自学平台统一身份与网关接入说明》8.2：
 * eventId / eventType / eventVersion / occurredAt / sourcePlatform /
 * sourceEntityId / actorId / correlationId / requestId / data。
 *
 * 纪律（接入说明 8.1）：跨平台正式通道只发事件目录内类型，目前是 course.completed。
 * learning.progress.updated 属本地扩展事件，默认不投递（中间态由对端回源
 * GET /progress 获取），只有对端显式开启 extensions 并配置独立路径时才走扩展通道。
 *
 * 多对端：事件带 target，标识发给考试平台 / 实训平台 / 论坛平台，投递时按 target 路由。
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
     * @param string $target 对端标识（exam|training|forum）
     * @return ExamOutboxModel|null
     */
    public function progressUpdated(CourseUserModel $courseUser, CourseModel $course, $actorKey = '', $requestId = '', $target = 'exam')
    {
        if ($courseUser->user_id <= 0 || $course->id <= 0) return null;

        if (!$this->isEnabled($target)) return null;

        $progress = (int)$courseUser->progress;

        if ($progress <= 0) return null;

        $completed = (int)$courseUser->status == CourseUserModel::STATUS_COMPLETED;

        $eventType = $completed ? ExamOutboxModel::TYPE_COMPLETED : ExamOutboxModel::TYPE_PROGRESS;

        /**
         * 通道纪律：事件不在该对端白名单内则不入箱，
         * 避免下游收到未定义类型后按「未知主版本」隔离告警。
         */
        $registry = new Peers();

        $channel = $registry->allows($target, $eventType);

        if ($channel === '') return null;

        $repo = new ExamOutboxRepo();

        if ($completed) {

            if ($repo->existsFact($eventType, $courseUser->user_id, $course->id, self::EVENT_VERSION, $target)) {
                return null;
            }

        } else {

            $lastProgress = $repo->findLastProgress($courseUser->user_id, $course->id, $target);

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

        $outbox->target = $target;
        $outbox->channel = $channel;
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
     * 是否开启向该对端推送
     *
     * @param string $target
     * @return bool
     */
    public function isEnabled($target = 'exam')
    {
        return (new Peers())->isEnabled($target);
    }

    /**
     * 完成事实扇出：给每个已启用且允许该事件的对端各入箱一条
     *
     * 课程完成是事件目录内的类型，考试平台、实训平台、论坛平台都可订阅；
     * 各自独立入箱（独立 eventId、独立 target），某个对端失败不影响其他对端。
     *
     * @param CourseUserModel $courseUser
     * @param CourseModel $course
     * @return array target => eventId
     */
    public function courseCompletedFanout(CourseUserModel $courseUser, CourseModel $course)
    {
        $result = [];

        $registry = new Peers();

        foreach ($registry->enabled() as $target => $peer) {

            if ($registry->allows($target, ExamOutboxModel::TYPE_COMPLETED) === '') continue;

            $outbox = $this->progressUpdated($courseUser, $course, '', '', $target);

            if ($outbox) $result[$target] = (string)$outbox->event_id;
        }

        return $result;
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

<?php
/**
 * 学习进度推送发件箱仓储
 */

namespace App\Repos;

use App\Models\ExamOutbox as ExamOutboxModel;

class ExamOutbox extends Repository
{

    /**
     * 取到期可投递的事件
     *
     * 待投递(0) 与 待重试(2) 中 next_retry_at 已到期者。
     *
     * @param int $limit
     * @param int $userId 0 表示全部用户
     * @param string $target 对端，留空表示全部对端
     * @return ExamOutboxModel[]
     */
    public function findDue($limit = 200, $userId = 0, $target = '')
    {
        $now = time();

        $conditions = 'status IN (0, 2) AND next_retry_at <= :now:';
        $bind = ['now' => $now];

        if ($userId > 0) {
            $conditions .= ' AND user_id = :user_id:';
            $bind['user_id'] = $userId;
        }

        if ($target !== '') {
            $conditions .= ' AND target = :target:';
            $bind['target'] = $target;
        }

        return ExamOutboxModel::find([
            'conditions' => $conditions,
            'bind' => $bind,
            'order' => 'id ASC',
            'limit' => $limit,
        ]);
    }

    /**
     * @param string $eventId
     * @return ExamOutboxModel|\Phalcon\Mvc\Model|bool
     */
    public function findByEventId($eventId)
    {
        return ExamOutboxModel::findFirst([
            'conditions' => 'event_id = :event_id:',
            'bind' => ['event_id' => $eventId],
        ]);
    }

    /**
     * 同一事实是否已入箱（用于完成类事件去重）
     *
     * @param string $eventType
     * @param int $userId
     * @param int $courseId
     * @param string $eventVersion
     * @param string $target 对端
     * @return bool
     */
    public function existsFact($eventType, $userId, $courseId, $eventVersion = '1.0', $target = 'exam')
    {
        $row = ExamOutboxModel::findFirst([
            'conditions' => 'event_type = ?1 AND user_id = ?2 AND course_id = ?3 AND event_version = ?4 AND target = ?5',
            'bind' => [1 => $eventType, 2 => $userId, 3 => $courseId, 4 => $eventVersion, 5 => $target],
        ]);

        return (bool)$row;
    }

    /**
     * 该课程最近一次入箱的进度值
     *
     * @param int $userId
     * @param int $courseId
     * @param string $target 对端
     * @return int
     */
    public function findLastProgress($userId, $courseId, $target = 'exam')
    {
        $row = ExamOutboxModel::findFirst([
            'conditions' => 'user_id = :user_id: AND course_id = :course_id: AND target = :target:',
            'bind' => ['user_id' => $userId, 'course_id' => $courseId, 'target' => $target],
            'order' => 'id DESC',
        ]);

        return $row ? (int)$row->progress : 0;
    }

    /**
     * 最近一条记录
     *
     * @param int $userId
     * @param int $courseId
     * @return ExamOutboxModel|\Phalcon\Mvc\Model|bool
     */
    public function findLatest($userId, $courseId = 0)
    {
        $conditions = 'user_id = :user_id:';
        $bind = ['user_id' => $userId];

        if ($courseId > 0) {
            $conditions .= ' AND course_id = :course_id:';
            $bind['course_id'] = $courseId;
        }

        return ExamOutboxModel::findFirst([
            'conditions' => $conditions,
            'bind' => $bind,
            'order' => 'id DESC',
        ]);
    }

    /**
     * 每个课程最近一条推送记录
     *
     * @param int $userId
     * @param string $target 对端，留空表示全部
     * @return array
     */
    public function findLatestPerCourse($userId, $target = '')
    {
        $conditions = 'user_id = :user_id:';
        $bind = ['user_id' => $userId];

        if ($target !== '') {
            $conditions .= ' AND target = :target:';
            $bind['target'] = $target;
        }

        $rows = ExamOutboxModel::find([
            'conditions' => $conditions,
            'bind' => $bind,
            'order' => 'id DESC',
            'limit' => 500,
        ]);

        $map = [];

        if ($rows) {
            foreach ($rows as $row) {
                if (!isset($map[(int)$row->course_id])) {
                    $map[(int)$row->course_id] = $row;
                }
            }
        }

        return $map;
    }

    /**
     * 推送时间线
     *
     * @param int $userId
     * @param int $limit
     * @param string $target 对端，留空表示全部
     * @return ExamOutboxModel[]
     */
    public function findTimeline($userId, $limit = 15, $target = '')
    {
        $conditions = 'user_id = :user_id:';
        $bind = ['user_id' => $userId];

        if ($target !== '') {
            $conditions .= ' AND target = :target:';
            $bind['target'] = $target;
        }

        return ExamOutboxModel::find([
            'conditions' => $conditions,
            'bind' => $bind,
            'order' => 'id DESC',
            'limit' => $limit,
        ]);
    }

    /**
     * 按状态统计
     *
     * @param int $userId 0 表示全部用户
     * @param int|null $status
     * @param string $target 对端，留空表示全部
     * @return int
     */
    public function countByStatus($userId = 0, $status = null, $target = '')
    {
        $conditions = '1 = 1';
        $bind = [];

        if ($userId > 0) {
            $conditions .= ' AND user_id = :user_id:';
            $bind['user_id'] = $userId;
        }

        if ($target !== '') {
            $conditions .= ' AND target = :target:';
            $bind['target'] = $target;
        }

        if ($status !== null) {
            $conditions .= ' AND status = :status:';
            $bind['status'] = $status;
        }

        return (int)ExamOutboxModel::count([
            'conditions' => $conditions,
            'bind' => $bind,
        ]);
    }

    /**
     * 最近一次成功投递时间
     *
     * @param int $userId
     * @param string $target 对端，留空表示全部
     * @return int
     */
    public function findLastSentTime($userId = 0, $target = '')
    {
        $conditions = 'status = :status:';
        $bind = ['status' => ExamOutboxModel::STATUS_SENT];

        if ($userId > 0) {
            $conditions .= ' AND user_id = :user_id:';
            $bind['user_id'] = $userId;
        }

        if ($target !== '') {
            $conditions .= ' AND target = :target:';
            $bind['target'] = $target;
        }

        $row = ExamOutboxModel::findFirst([
            'conditions' => $conditions,
            'bind' => $bind,
            'order' => 'sent_at DESC, id DESC',
        ]);

        return $row ? (int)$row->sent_at : 0;
    }

    /**
     * 供对端增量拉取的事件（按自增 id 做游标，避免时间戳重复导致的漏读）
     *
     * 双重过滤，缺一不可：
     * 1) channel = official —— 扩展事件走对端独立路径；
     * 2) event_type 命中事件目录 —— 改造前入箱的存量事件 channel 字段
     *    被统一补成 official，只看 channel 会把不在目录内的中间态事件
     *    漏给对端，触发下游「未知事件类型」告警（接入说明 8.1）。
     *
     * @param int $userId
     * @param string $target
     * @param int $afterId 游标，取 id 大于该值的记录
     * @param int $since 起始时间戳，0 表示不限
     * @param int $limit
     * @param array $eventTypes 事件目录白名单，空数组表示不限（仅供内部排障）
     * @return ExamOutboxModel[]
     */
    public function findPullable($userId, $target, $afterId = 0, $since = 0, $limit = 200, array $eventTypes = [])
    {
        $conditions = 'user_id = :user_id: AND target = :target: AND channel = :channel: AND id > :after_id:';

        $bind = [
            'user_id' => $userId,
            'target' => $target,
            'channel' => 'official',
            'after_id' => $afterId,
        ];

        if ($since > 0) {
            $conditions .= ' AND occurred_at >= :since:';
            $bind['since'] = $since;
        }

        if (count($eventTypes) > 0) {
            $conditions .= ' AND event_type IN ({event_types:array})';
            $bind['event_types'] = array_values(array_map('strval', $eventTypes));
        }

        return ExamOutboxModel::find([
            'conditions' => $conditions,
            'bind' => $bind,
            'order' => 'id ASC',
            'limit' => $limit,
        ]);
    }

    /**
     * 记录对端回执
     *
     * accepted：保持已投递状态，只补充回执时间与对端记录号；
     * rejected：对端入库失败，退回待重试，由投递器按退避重发。
     *
     * @param ExamOutboxModel $event
     * @param string $ackStatus accepted|rejected
     * @param string $remoteId 对端记录号
     * @param string $reason 拒绝原因
     * @return bool
     */
    public function acknowledge(ExamOutboxModel $event, $ackStatus, $remoteId = '', $reason = '')
    {
        $event->ack_status = (string)$ackStatus;

        $event->remote_id = mb_substr((string)$remoteId, 0, 64);

        $event->acked_at = time();

        if ($ackStatus === 'rejected') {
            $event->status = ExamOutboxModel::STATUS_FAILED;
            $event->last_error = mb_substr('回执拒绝：' . (string)$reason, 0, 255);
            $event->next_retry_at = time() + 60;
        }

        return (bool)$event->update();
    }

    /**
     * 待重放事件（投递失败或已进死信）
     *
     * 同样按 channel + 事件目录双重过滤：重放的意义是补投该发而未发出的事件，
     * 把不再允许上正式通道的历史事件重放出去，等于主动制造一次 8.1 违规。
     *
     * @param int $userId 0 表示全部用户
     * @param int $courseId 0 表示全部课程
     * @param string $target
     * @param int $limit
     * @param array $eventTypes 事件目录白名单，空数组表示不限
     * @return ExamOutboxModel[]
     */
    public function findReplayable($userId = 0, $courseId = 0, $target = 'exam', $limit = 100, array $eventTypes = [])
    {
        $conditions = 'status IN (:failed:, :dead:) AND target = :target: AND channel = :channel:';

        $bind = [
            'failed' => ExamOutboxModel::STATUS_FAILED,
            'dead' => ExamOutboxModel::STATUS_DEAD,
            'target' => $target,
            'channel' => 'official',
        ];

        if ($userId > 0) {
            $conditions .= ' AND user_id = :user_id:';
            $bind['user_id'] = $userId;
        }

        if ($courseId > 0) {
            $conditions .= ' AND course_id = :course_id:';
            $bind['course_id'] = $courseId;
        }

        if (count($eventTypes) > 0) {
            $conditions .= ' AND event_type IN ({event_types:array})';
            $bind['event_types'] = array_values(array_map('strval', $eventTypes));
        }

        return ExamOutboxModel::find([
            'conditions' => $conditions,
            'bind' => $bind,
            'order' => 'id ASC',
            'limit' => $limit,
        ]);
    }

    /**
     * 把事件重置回待投递（重放）
     *
     * @param ExamOutboxModel $event
     * @return bool
     */
    public function resetForReplay(ExamOutboxModel $event)
    {
        $event->status = ExamOutboxModel::STATUS_PENDING;
        $event->retry_count = 0;
        $event->next_retry_at = 0;
        $event->last_error = '';
        $event->dead_at = 0;
        $event->ack_status = '';
        $event->acked_at = 0;

        return (bool)$event->update();
    }

    /**
     * 按 eventId 批量取事件
     *
     * @param array $eventIds
     * @param string $target
     * @return ExamOutboxModel[]
     */
    public function findByEventIds(array $eventIds, $target = 'exam')
    {
        $eventIds = array_values(array_filter(array_map('strval', $eventIds)));

        if (count($eventIds) == 0) return [];

        $rows = ExamOutboxModel::find([
            'conditions' => 'event_id IN ({event_ids:array}) AND target = :target:',
            'bind' => ['event_ids' => $eventIds, 'target' => $target],
        ]);

        $map = [];

        foreach ($rows as $row) {
            $map[(string)$row->event_id] = $row;
        }

        return $map;
    }

    /**
     * 已确认 / 未确认数量
     *
     * @param string $target
     * @param bool $acked
     * @param int $userId 0 表示全部用户
     * @return int
     */
    public function countAcked($target, $acked = true, $userId = 0)
    {
        $conditions = 'target = :target: AND status = :status:';
        $bind = ['target' => $target, 'status' => ExamOutboxModel::STATUS_SENT];

        $conditions .= $acked ? ' AND acked_at > 0' : ' AND acked_at = 0';

        if ($userId > 0) {
            $conditions .= ' AND user_id = :user_id:';
            $bind['user_id'] = $userId;
        }

        return (int)ExamOutboxModel::count([
            'conditions' => $conditions,
            'bind' => $bind,
        ]);
    }

}

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
     * @return ExamOutboxModel[]
     */
    public function findDue($limit = 200, $userId = 0)
    {
        $now = time();

        $conditions = 'status IN (0, 2) AND next_retry_at <= :now:';
        $bind = ['now' => $now];

        if ($userId > 0) {
            $conditions .= ' AND user_id = :user_id:';
            $bind['user_id'] = $userId;
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
     * @return bool
     */
    public function existsFact($eventType, $userId, $courseId, $eventVersion = '1.0')
    {
        $row = ExamOutboxModel::findFirst([
            'conditions' => 'event_type = ?1 AND user_id = ?2 AND course_id = ?3 AND event_version = ?4',
            'bind' => [1 => $eventType, 2 => $userId, 3 => $courseId, 4 => $eventVersion],
        ]);

        return (bool)$row;
    }

    /**
     * 该课程最近一次入箱的进度值
     *
     * @param int $userId
     * @param int $courseId
     * @return int
     */
    public function findLastProgress($userId, $courseId)
    {
        $row = ExamOutboxModel::findFirst([
            'conditions' => 'user_id = :user_id: AND course_id = :course_id:',
            'bind' => ['user_id' => $userId, 'course_id' => $courseId],
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
     * @return array
     */
    public function findLatestPerCourse($userId)
    {
        $rows = ExamOutboxModel::find([
            'conditions' => 'user_id = :user_id:',
            'bind' => ['user_id' => $userId],
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
     * @return ExamOutboxModel[]
     */
    public function findTimeline($userId, $limit = 15)
    {
        return ExamOutboxModel::find([
            'conditions' => 'user_id = :user_id:',
            'bind' => ['user_id' => $userId],
            'order' => 'id DESC',
            'limit' => $limit,
        ]);
    }

    /**
     * 按状态统计
     *
     * @param int $userId 0 表示全部用户
     * @param int|null $status
     * @return int
     */
    public function countByStatus($userId = 0, $status = null)
    {
        $conditions = '1 = 1';
        $bind = [];

        if ($userId > 0) {
            $conditions .= ' AND user_id = :user_id:';
            $bind['user_id'] = $userId;
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
     * @return int
     */
    public function findLastSentTime($userId = 0)
    {
        $conditions = 'status = :status:';
        $bind = ['status' => ExamOutboxModel::STATUS_SENT];

        if ($userId > 0) {
            $conditions .= ' AND user_id = :user_id:';
            $bind['user_id'] = $userId;
        }

        $row = ExamOutboxModel::findFirst([
            'conditions' => $conditions,
            'bind' => $bind,
            'order' => 'sent_at DESC, id DESC',
        ]);

        return $row ? (int)$row->sent_at : 0;
    }

}

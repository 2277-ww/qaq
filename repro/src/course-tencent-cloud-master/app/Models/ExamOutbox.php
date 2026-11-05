<?php
/**
 * 学习进度推送发件箱（考试平台）
 *
 * 本平台是学习数据的生产方。学习进度先落本地事实表，再以事件形式写入本表，
 * 由投递动作经统一网关推送给考试平台。推送失败不丢事实，可退避重试与重放。
 *
 * 表结构见 db/migrations/20261105180000.php
 */

namespace App\Models;

class ExamOutbox extends Model
{

    /**
     * 待投递
     */
    const STATUS_PENDING = 0;

    /**
     * 已投递
     */
    const STATUS_SENT = 1;

    /**
     * 投递失败，等待重试
     */
    const STATUS_FAILED = 2;

    /**
     * 死信，不再自动重试
     */
    const STATUS_DEAD = 3;

    /**
     * 学习进度更新（增量）
     */
    const TYPE_PROGRESS = 'learning.progress.updated';

    /**
     * 课程完成（考试平台据此开放随堂测试）
     */
    const TYPE_COMPLETED = 'course.completed';

    public $id = 0;

    public $event_id = '';

    public $event_type = '';

    public $event_version = '1.0';

    public $user_id = 0;

    public $course_id = 0;

    public $user_key = '';

    public $course_key = '';

    public $progress = 0;

    public $payload = '';

    public $status = 0;

    public $retry_count = 0;

    public $next_retry_at = 0;

    public $last_error = '';

    public $response_code = 0;

    public $request_id = '';

    public $occurred_at = 0;

    public $sent_at = 0;

    public $dead_at = 0;

    public $create_time = 0;

    public $update_time = 0;

    public function getSource(): string
    {
        return 'kg_exam_outbox';
    }

    public function beforeCreate()
    {
        if (empty($this->create_time)) {
            $this->create_time = time();
        }

        if (empty($this->occurred_at)) {
            $this->occurred_at = time();
        }
    }

    public function beforeUpdate()
    {
        $this->update_time = time();
    }

    /**
     * @return array
     */
    public function getPayloadArray()
    {
        $payload = json_decode((string)$this->payload, true);

        return is_array($payload) ? $payload : [];
    }

    /**
     * 状态文案
     *
     * @return string
     */
    public function getStatusText()
    {
        $map = [
            self::STATUS_PENDING => '待推送',
            self::STATUS_SENT => '已推送',
            self::STATUS_FAILED => '待重试',
            self::STATUS_DEAD => '推送失败',
        ];

        return $map[(int)$this->status] ?? '未知';
    }

}

<?php
/**
 * 学习进度推送发件箱（考试平台 / 实训平台 / 论坛平台）
 *
 * 本平台是学习数据的生产方。学习进度先落本地事实表，再以事件形式写入本表，
 * 由投递动作经统一网关推送给各对端。推送失败不丢事实，可退避重试与重放。
 *
 * target 标识对端，channel 标识通道：
 *   official  —— 事件目录内类型，可上跨平台正式通道；
 *   extension —— 本地扩展类型，必须走对端独立路径（接入说明 8.1 纪律）。
 *
 * 表结构见 db/migrations/20261105180000.php 与 20261105230000.php
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
     * 学习进度更新（本地扩展事件，不在接入说明 8.1 目录内）
     *
     * 默认不投递：中间态进度由对端回源 GET /progress 获取；
     * 仅当对端显式开启 extensions 且配置了独立的 extension_path 时，才走扩展通道。
     */
    const TYPE_PROGRESS = 'learning.progress.updated';

    /**
     * 课程完成（事件目录内，可上正式通道）
     */
    const TYPE_COMPLETED = 'course.completed';

    public $id = 0;

    public $target = 'exam';

    public $channel = 'official';

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

    /**
     * 对端回执时间（0 表示对端尚未确认）
     */
    public $acked_at = 0;

    /**
     * 对端侧记录号（如考试平台的成绩单编号），对账用
     */
    public $remote_id = '';

    /**
     * 回执结论：accepted / rejected
     */
    public $ack_status = '';

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
     * 已投递且对端已回执确认时，对外显示「已确认」，便于区分「发出去了」
     * 与「对方确实入库了」。回执被拒时回到「待重试」。
     *
     * @return string
     */
    public function getStatusText()
    {
        if ((int)$this->status === self::STATUS_SENT && (int)$this->acked_at > 0) {
            return '已确认';
        }

        $map = [
            self::STATUS_PENDING => '待推送',
            self::STATUS_SENT => '已推送',
            self::STATUS_FAILED => '待重试',
            self::STATUS_DEAD => '推送失败',
        ];

        return $map[(int)$this->status] ?? '未知';
    }

    /**
     * 是否已被对端确认
     *
     * @return bool
     */
    public function isAcked()
    {
        return (int)$this->acked_at > 0;
    }

}

<?php
/**
 * 跨平台入站事件收件箱（实训平台 / 论坛平台 → 自学平台）
 *
 * 对端回传的事件先落到本表，再由后续的处理器消费，避免在 HTTP 请求里做重活。
 * 幂等键是 (source, event_id)：同一事件重复投递只登记一次。
 *
 * 表结构见 db/migrations/20261105230000.php
 */

namespace App\Models;

class PeerInbox extends Model
{

    /**
     * 已接收，待处理
     */
    const STATUS_RECEIVED = 0;

    /**
     * 已处理
     */
    const STATUS_PROCESSED = 1;

    /**
     * 已忽略（类型暂不处理）
     */
    const STATUS_IGNORED = 2;

    /**
     * 处理失败
     */
    const STATUS_FAILED = 3;

    public $id = 0;

    public $source = '';

    public $event_id = '';

    public $event_type = '';

    public $event_version = '1.0';

    public $actor_key = '';

    public $payload = '';

    public $status = 0;

    public $note = '';

    public $request_id = '';

    public $received_at = 0;

    public $processed_at = 0;

    public $create_time = 0;

    public $update_time = 0;

    public function getSource(): string
    {
        return 'kg_peer_inbox';
    }

    public function beforeCreate()
    {
        if (empty($this->create_time)) $this->create_time = time();

        if (empty($this->received_at)) $this->received_at = time();
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
     * @return string
     */
    public function getStatusText()
    {
        $map = [
            self::STATUS_RECEIVED => '已接收',
            self::STATUS_PROCESSED => '已处理',
            self::STATUS_IGNORED => '已忽略',
            self::STATUS_FAILED => '处理失败',
        ];

        return $map[(int)$this->status] ?? '未知';
    }

}

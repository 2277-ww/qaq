<?php
/**
 * 跨平台入站事件接收
 *
 * 预留方向：实训平台（training）、论坛平台（forum）把自身事件回传给本平台，
 * 用于后续的学情汇总（如实训完成、论坛答疑贡献）。本类只做三件事：
 *   1) 校验来源对端是否开通入站、事件类型是否在白名单内；
 *   2) 按 (source, event_id) 幂等落库；
 *   3) 返回受理结果，不在此处做业务处理，处理交给后续的消费者。
 *
 * 这样做的原因：入站请求可能来自任意对端，响应必须快且可控；
 * 业务处理逻辑会随对端演进，不该绑死在 HTTP 请求里。
 */

namespace App\Services\Learning;

use App\Models\PeerInbox as PeerInboxModel;
use App\Repos\PeerInbox as PeerInboxRepo;
use App\Services\Service;

class Inbox extends Service
{

    /**
     * 受理一条入站事件
     *
     * @param string $source 来源对端（training|forum）
     * @param array $body 事件封套
     * @param string $requestId 网关请求编号
     * @return array {ok, code, message, status, inboxId}
     */
    public function accept($source, array $body, $requestId = '')
    {
        $registry = new Peers();

        $peer = $registry->get($source);

        if (!$peer['enabled'] || !$peer['inbound']) {
            return $this->reject('PEER_NOT_OPEN', sprintf('对端 %s 未开通入站通道', $source));
        }

        $eventId = trim((string)($body['eventId'] ?? ''));

        $eventType = trim((string)($body['eventType'] ?? ''));

        if ($eventId === '' || $eventType === '') {
            return $this->reject('VALIDATION_ERROR', '缺少 eventId 或 eventType');
        }

        if (strlen($eventId) > 64) {
            return $this->reject('VALIDATION_ERROR', 'eventId 超长');
        }

        $allowed = $registry->inboundEvents($source);

        if (!in_array($eventType, $allowed, true)) {
            return $this->reject('EVENT_NOT_ALLOWED', sprintf('事件类型 %s 不在 %s 的入站白名单内', $eventType, $source));
        }

        $repo = new PeerInboxRepo();

        $exists = $repo->findByEventId($source, $eventId);

        if ($exists) {
            return [
                'ok' => true,
                'code' => 'OK',
                'message' => '该事件已受理，幂等返回',
                'status' => 'duplicate',
                'inboxId' => (int)$exists->id,
                'eventId' => $eventId,
            ];
        }

        $inbox = new PeerInboxModel();

        $inbox->source = (string)$source;
        $inbox->event_id = $eventId;
        $inbox->event_type = $eventType;
        $inbox->event_version = (string)($body['eventVersion'] ?? '1.0');
        $inbox->actor_key = (string)($body['actorId'] ?? '');
        $inbox->payload = kg_json_encode($body);
        $inbox->status = PeerInboxModel::STATUS_RECEIVED;
        $inbox->note = '';
        $inbox->request_id = (string)$requestId;
        $inbox->received_at = time();

        $inbox->create();

        return [
            'ok' => true,
            'code' => 'OK',
            'message' => '已受理',
            'status' => 'accepted',
            'inboxId' => (int)$inbox->id,
            'eventId' => $eventId,
        ];
    }

    /**
     * 查询入站事件处理状态
     *
     * @param string $source
     * @param string $eventId
     * @return PeerInboxModel|null
     */
    public function status($source, $eventId)
    {
        $repo = new PeerInboxRepo();

        $row = $repo->findByEventId($source, $eventId);

        return $row ? $row : null;
    }

    /**
     * 待处理数量（监控用）
     *
     * @param string $source
     * @return int
     */
    public function pendingCount($source = '')
    {
        return (new PeerInboxRepo())->countPending($source);
    }

    /**
     * @param string $code
     * @param string $message
     * @return array
     */
    protected function reject($code, $message)
    {
        return [
            'ok' => false,
            'code' => $code,
            'message' => $message,
            'status' => 'rejected',
            'inboxId' => 0,
            'eventId' => '',
        ];
    }

}

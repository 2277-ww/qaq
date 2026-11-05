<?php
/**
 * 考试平台投递回执处理
 *
 * 本平台把 course.completed 推给考试平台后，只知道「网关收下了」，
 * 并不知道「考试平台是否真的入库」。回执接口补上这一段：
 * 考试平台入库成功后回传 exam.progress.ack，本平台把发件箱记录标记为已确认。
 *
 * 回执与推送的关系是 1:1，靠 correlationId（被回执进度事件的 eventId）关联。
 * 回执本身也走幂等：对端可能因为网络抖动重发，按 (source, receiptId) 去重。
 *
 * 注意方向：本类处理的是「对端 → 本平台」，属于反向通道，
 * 不受接入说明 8.1 事件目录约束（该约束只针对本平台向外发的事件）。
 */

namespace App\Services\Learning;

use App\Models\PeerInbox as PeerInboxModel;
use App\Repos\ExamOutbox as ExamOutboxRepo;
use App\Repos\PeerInbox as PeerInboxRepo;
use App\Services\Service;

class Receipt extends Service
{

    /**
     * 回执事件类型默认值（考试平台）
     *
     * 实际以该对端 inbound_events 中登记的 *.ack 为准，见 ackEventType()；
     * 这样实训、论坛接入时只改配置，不用改代码。
     */
    const EVENT_ACK = 'exam.progress.ack';

    const ACCEPTED = 'accepted';

    const REJECTED = 'rejected';

    /**
     * 该对端允许的回执事件类型
     *
     * @param string $source
     * @return string
     */
    public function ackEventType($source)
    {
        $registry = new Peers();

        foreach ($registry->inboundEvents($source) as $eventType) {

            if (substr($eventType, -4) === '.ack') return $eventType;
        }

        return self::EVENT_ACK;
    }

    /**
     * 应用一条回执
     *
     * @param string $source 对端标识
     * @param array $body 事件封套
     * @param string $requestId 网关请求编号
     * @return array{ok:bool,code:string,message:string,status:string,data:array}
     */
    public function apply($source, array $body, $requestId = '')
    {
        $registry = new Peers();

        if (!$registry->hasAbility($source, 'ack')) {
            return $this->reject('RECEIPT_NOT_OPEN', sprintf('对端 %s 未开通回执通道', $source));
        }

        $ackEvent = $this->ackEventType($source);

        $receiptId = trim((string)($body['eventId'] ?? ''));

        $eventType = trim((string)($body['eventType'] ?? $ackEvent));

        if ($receiptId === '' || $eventType === '') {
            return $this->reject('VALIDATION_ERROR', '缺少 eventId 或 eventType');
        }

        if (strlen($receiptId) > 64) {
            return $this->reject('VALIDATION_ERROR', 'eventId 超长');
        }

        if ($eventType !== $ackEvent) {
            return $this->reject('EVENT_NOT_ALLOWED', sprintf('回执通道只接受 %s', $ackEvent));
        }

        $payload = isset($body['payload']) && is_array($body['payload']) ? $body['payload'] : [];

        $targetEventId = trim((string)($body['correlationId'] ?? ($payload['eventId'] ?? '')));

        if ($targetEventId === '') {
            return $this->reject('VALIDATION_ERROR', '缺少 correlationId（被回执的进度事件 eventId）');
        }

        $ackStatus = strtolower(trim((string)($payload['status'] ?? self::ACCEPTED)));

        if (!in_array($ackStatus, [self::ACCEPTED, self::REJECTED], true)) {
            return $this->reject('VALIDATION_ERROR', 'payload.status 只能是 accepted 或 rejected');
        }

        $remoteId = trim((string)($payload['remoteId'] ?? ''));

        $reason = trim((string)($payload['reason'] ?? ''));

        $inboxRepo = new PeerInboxRepo();

        $exists = $inboxRepo->findByEventId($source, $receiptId);

        if ($exists) {
            return [
                'ok' => true,
                'code' => 'OK',
                'message' => '该回执已受理，幂等返回',
                'status' => 'duplicate',
                'data' => [
                    'receiptId' => $receiptId,
                    'targetEventId' => $targetEventId,
                    'ackStatus' => (string)$exists->note,
                ],
            ];
        }

        $repo = new ExamOutboxRepo();

        $event = $repo->findByEventId($targetEventId);

        if (!$event || (string)$event->target !== (string)$source) {
            return $this->reject('TARGET_EVENT_NOT_FOUND', '被回执的进度事件不存在或不属于该对端');
        }

        $repo->acknowledge($event, $ackStatus, $remoteId, $reason);

        $inbox = new PeerInboxModel();

        $inbox->source = (string)$source;
        $inbox->event_id = $receiptId;
        $inbox->event_type = $eventType;
        $inbox->event_version = (string)($body['eventVersion'] ?? '1.0');
        $inbox->actor_key = (string)($body['actorId'] ?? '');
        $inbox->payload = kg_json_encode($body);
        $inbox->status = $ackStatus === self::ACCEPTED
            ? PeerInboxModel::STATUS_PROCESSED : PeerInboxModel::STATUS_IGNORED;
        $inbox->note = $ackStatus;
        $inbox->request_id = (string)$requestId;
        $inbox->received_at = time();
        $inbox->processed_at = time();

        $inbox->create();

        return [
            'ok' => true,
            'code' => 'OK',
            'message' => $ackStatus === self::ACCEPTED ? '回执已确认' : '回执已记录，事件转为待重试',
            'status' => 'accepted',
            'data' => [
                'receiptId' => $receiptId,
                'targetEventId' => $targetEventId,
                'ackStatus' => $ackStatus,
                'remoteId' => (string)$event->remote_id,
                'ackedAt' => gmdate('Y-m-d\TH:i:s\Z', (int)$event->acked_at),
                'eventStatus' => (int)$event->status,
            ],
        ];
    }

    /**
     * 已确认分布（页面与对账用）
     *
     * @param string $source
     * @return array
     */
    public function summary($source)
    {
        $repo = new ExamOutboxRepo();

        return [
            'acked' => $repo->countAcked($source, true),
            'unacked' => $repo->countAcked($source, false),
        ];
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
            'data' => [],
        ];
    }

}

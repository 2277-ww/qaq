<?php
/**
 * 失败事件重放（对账后重推）
 *
 * 死信不会自动重试，这是有意为之：连续失败通常意味着契约变更或对端故障，
 * 盲目重试只会放大故障。但对账修好之后需要一个明确的重推入口，本类就是它。
 *
 * 只做「重置为待投递」，不在 HTTP 请求里直接投递：
 * 1) 投递要走网关，耗时不可控，不能占着请求线程；
 * 2) 重置后由 exam_sync 定时任务（3 分钟一轮）按退避策略自然接走，
 *    也能被下一次一键同步立即带走，两条路径都通。
 */

namespace App\Services\Learning;

use App\Models\ExamOutbox as ExamOutboxModel;
use App\Repos\ExamOutbox as ExamOutboxRepo;
use App\Services\Service;

class Replay extends Service
{

    /**
     * 单次重放上限，防止对端一次把整表翻起来
     */
    const MAX_BATCH = 100;

    /**
     * 重置事件为待投递
     *
     * @param string $source 对端标识
     * @param array $body {eventIds?: array, userId?: string, courseId?: int}
     * @return array
     */
    public function apply($source, array $body)
    {
        $registry = new Peers();

        if (!$registry->hasAbility($source, 'replay')) {
            return $this->reject('REPLAY_NOT_OPEN', sprintf('对端 %s 未开通重放通道', $source));
        }

        $eventIds = isset($body['eventIds']) && is_array($body['eventIds']) ? $body['eventIds'] : [];

        $userKey = trim((string)($body['userId'] ?? ''));

        $courseId = isset($body['courseId']) ? (int)$body['courseId'] : 0;

        if (count($eventIds) == 0 && $userKey === '') {
            return $this->reject('VALIDATION_ERROR', '需提供 eventIds，或提供 userId（可带 courseId）按条件重放');
        }

        if (count($eventIds) > self::MAX_BATCH) {
            return $this->reject('VALIDATION_ERROR', sprintf('单次最多重放 %d 条', self::MAX_BATCH));
        }

        $repo = new ExamOutboxRepo();

        $replayed = [];

        $skipped = [];

        if (count($eventIds) > 0) {

            $map = $repo->findByEventIds($eventIds, $source);

            foreach ($eventIds as $eventId) {

                $eventId = trim((string)$eventId);

                if ($eventId === '') continue;

                if (!isset($map[$eventId])) {
                    $skipped[] = ['eventId' => $eventId, 'reason' => 'NOT_FOUND'];
                    continue;
                }

                $row = $map[$eventId];

                $reason = $this->skipReason($row, $registry, $source);

                if ($reason !== '') {
                    $skipped[] = ['eventId' => $eventId, 'reason' => $reason];
                    continue;
                }

                $repo->resetForReplay($row);

                $replayed[] = $eventId;
            }
        } else {

            $identity = new IdentityKey();

            $userId = (int)$identity->resolveUserId($userKey);

            if ($userId <= 0) {
                return $this->reject('USER_NOT_FOUND', '该用户不存在');
            }

            $rows = $repo->findReplayable($userId, $courseId, $source, self::MAX_BATCH, $registry->get($source)['events']);

            foreach ($rows as $row) {
                $repo->resetForReplay($row);
                $replayed[] = (string)$row->event_id;
            }
        }

        return [
            'ok' => true,
            'code' => 'OK',
            'message' => count($replayed) > 0 ? '已重置为待投递' : '没有需要重放的事件',
            'data' => [
                'peer' => $source,
                'requested' => count($eventIds),
                'replayed' => count($replayed),
                'eventIds' => $replayed,
                'skipped' => $skipped,
                'deliveredBy' => 'exam_sync（3 分钟一轮）或下一次一键同步',
            ],
        ];
    }

    /**
     * 该事件是否可重放；返回空串表示可以
     *
     * @param ExamOutboxModel $row
     * @param Peers $registry
     * @param string $source
     * @return string
     */
    protected function skipReason(ExamOutboxModel $row, Peers $registry, $source)
    {
        if ($registry->allows($source, (string)$row->event_type) === '') {
            return 'EVENT_NOT_ALLOWED';
        }

        $status = (int)$row->status;

        if ($status === ExamOutboxModel::STATUS_PENDING) {
            return 'ALREADY_PENDING';
        }

        if ($status === ExamOutboxModel::STATUS_SENT) {
            return $row->isAcked() ? 'ALREADY_ACKED' : 'ALREADY_SENT';
        }

        return '';
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
            'data' => [],
        ];
    }

}

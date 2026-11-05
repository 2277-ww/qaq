<?php
/**
 * 对端增量拉取（考试平台补漏推）
 *
 * 推送是「本平台推、对端收」，一旦网关抖动或对端短暂不可用，
 * 光靠重试可能仍会漏；拉取给对端一个主动对齐的入口：
 * 对端按游标（afterId）从本平台取增量事件，自己按 eventId 幂等入库。
 *
 * 为什么用自增 id 而不是时间戳做游标：
 * 同一秒内可能有多条事件入箱，时间戳做游标会漏读（>= 会重复、> 会漏）。
 * 自增 id 单调递增，天然适合做游标。
 *
 * 只输出正式通道（official）事件：扩展事件不在事件目录内，
 * 混进正式通道会让下游按「未知事件类型」告警（接入说明 8.1）。
 */

namespace App\Services\Learning;

use App\Models\ExamOutbox as ExamOutboxModel;
use App\Repos\ExamOutbox as ExamOutboxRepo;
use App\Services\Service;

class Pull extends Service
{

    /**
     * 拉取增量事件
     *
     * @param string $source 对端标识
     * @param string $userKey 对外 userId（OIDC sub 或 usr_ 占位）
     * @param int $afterId 游标，取 id 大于该值的事件
     * @param int $since 起始时间戳，0 表示不限
     * @param int $limit 期望条数，0 表示取对端配置上限
     * @return array
     */
    public function events($source, $userKey, $afterId = 0, $since = 0, $limit = 0)
    {
        $registry = new Peers();

        if (!$registry->hasAbility($source, 'pull')) {
            return $this->reject('PULL_NOT_OPEN', sprintf('对端 %s 未开通拉取通道', $source));
        }

        $peer = $registry->get($source);

        $max = (int)$peer['pull_limit'];

        $limit = (int)$limit;

        if ($limit <= 0) $limit = $max;

        if ($limit > $max) $limit = $max;

        $identity = new IdentityKey();

        $userId = (int)$identity->resolveUserId((string)$userKey);

        if ($userId <= 0) {
            return $this->reject('USER_NOT_FOUND', '该用户不存在');
        }

        $repo = new ExamOutboxRepo();

        $rows = $repo->findPullable($userId, $source, (int)$afterId, (int)$since, $limit + 1, $peer['events']);

        $items = [];

        $cursor = (int)$afterId;

        $hasMore = false;

        foreach ($rows as $row) {

            if (count($items) >= $limit) {
                $hasMore = true;
                break;
            }

            $items[] = $this->format($row);

            $cursor = (int)$row->id;
        }

        return [
            'ok' => true,
            'code' => 'OK',
            'message' => 'success',
            'data' => [
                'peer' => $source,
                'userId' => (string)$userKey,
                'channel' => Peers::CHANNEL_OFFICIAL,
                'afterId' => (int)$afterId,
                'nextCursor' => $cursor,
                'hasMore' => $hasMore,
                'limit' => $limit,
                'count' => count($items),
                'events' => $items,
            ],
        ];
    }

    /**
     * 单条事件转对外结构
     *
     * course_key 形如 course_12，直接转 int 会得到 0，
     * 这里取末尾数字，兼容纯数字与带前缀两种写法。
     *
     * @param ExamOutboxModel $row
     * @return array
     */
    protected function format(ExamOutboxModel $row)
    {
        $courseId = 0;

        if (preg_match('/(\d+)$/', (string)$row->course_key, $match)) {
            $courseId = (int)$match[1];
        }

        return [
            'eventId' => (string)$row->event_id,
            'eventType' => (string)$row->event_type,
            'eventVersion' => (string)$row->event_version,
            'occurredAt' => gmdate('Y-m-d\TH:i:s\Z', (int)$row->occurred_at),
            'userId' => (string)$row->user_key,
            'courseId' => $courseId,
            'progress' => (int)$row->progress,
            'deliveryStatus' => (int)$row->status,
            'deliveryText' => $row->getStatusText(),
            'acked' => $row->isAcked(),
            'remoteId' => (string)$row->remote_id,
            'sentAt' => $row->sent_at > 0 ? gmdate('Y-m-d\TH:i:s\Z', (int)$row->sent_at) : null,
            'payload' => $row->getPayloadArray(),
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
            'data' => [],
        ];
    }

}

<?php
/**
 * 学习进度推送任务
 *
 * 用法：
 *   php console.php exam_sync main                 投递到期的待发/待重试事件（定时器每分钟调用）
 *   php console.php exam_sync replay <eventId>     重放指定事件（死信排障用）
 *
 * 定时器见 scheduler.php；重放保留原 event_id，下游按 eventId 幂等，不会产生重复副作用。
 */

namespace App\Console\Tasks;

use App\Models\ExamOutbox as ExamOutboxModel;
use App\Repos\ExamOutbox as ExamOutboxRepo;
use App\Services\Logic\Learning\Sync as ExamSyncService;

class ExamSyncTask extends Task
{

    public function mainAction()
    {
        $service = new ExamSyncService();

        $result = $service->flush(0, 200);

        $byPeer = [];

        foreach ((array)($result['byPeer'] ?? []) as $peer => $count) {
            $byPeer[] = sprintf('%s:%d', $peer, $count);
        }

        $this->successPrint(sprintf(
            'peer sync: sent=%d failed=%d dead=%d [%s] mode=%s endpoint=%s',
            $result['sent'],
            $result['failed'],
            $result['dead'],
            count($byPeer) > 0 ? implode(' ', $byPeer) : '-',
            $result['mode'],
            $result['endpoint'] === '' ? '(local)' : $result['endpoint']
        ));
    }

    public function replayAction()
    {
        $params = $this->dispatcher->getParams();

        $eventId = isset($params[0]) ? trim((string)$params[0]) : '';

        if ($eventId === '') {
            $this->errorPrint('usage: php console.php exam_sync replay <eventId>');
            return;
        }

        $repo = new ExamOutboxRepo();

        $event = $repo->findByEventId($eventId);

        if (!$event) {
            $this->errorPrint(sprintf('event not found: %s', $eventId));
            return;
        }

        $event->status = ExamOutboxModel::STATUS_PENDING;
        $event->retry_count = 0;
        $event->next_retry_at = 0;
        $event->dead_at = 0;
        $event->last_error = '';

        $event->update();

        $service = new ExamSyncService();

        $result = $service->flush((int)$event->user_id, 200);

        $this->successPrint(sprintf(
            'replay %s: sent=%d failed=%d dead=%d',
            $eventId,
            $result['sent'],
            $result['failed'],
            $result['dead']
        ));
    }

}

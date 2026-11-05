<?php
/**
 * 跨平台进度对账任务
 *
 * 用法：
 *   php console.php peer_reconcile main            对全部已启用对端做一次对账
 *   php console.php peer_reconcile main exam       只对指定对端对账
 *
 * 定时器见 scheduler.php（每日 03:47）。对账只补缺口，可反复执行。
 */

namespace App\Console\Tasks;

use App\Services\Logic\Learning\Reconcile as ReconcileService;

class PeerReconcileTask extends Task
{

    public function mainAction()
    {
        $params = $this->dispatcher->getParams();

        $target = isset($params[0]) ? trim((string)$params[0]) : '';

        $service = new ReconcileService();

        $report = $service->run($target);

        if (count($report) == 0) {
            $this->errorPrint('peer reconcile: 没有已启用的对端，跳过');
            return;
        }

        foreach ($report as $peer => $item) {

            if (!empty($item['skipped'])) {
                $this->errorPrint(sprintf('peer reconcile %s: skipped (%s)', $peer, $item['reason']));
                continue;
            }

            $this->successPrint(sprintf(
                'peer reconcile %s: checked=%d repaired=%d dead=%d',
                $peer,
                $item['checked'],
                $item['repaired'],
                $item['dead']
            ));
        }
    }

}

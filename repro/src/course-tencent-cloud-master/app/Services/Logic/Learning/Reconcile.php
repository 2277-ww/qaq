<?php
/**
 * 跨平台进度对账（方案 C 的落地，作为推送链路的兜底）
 *
 * 推送是「尽力而为 + 重试」的链路，仍可能因为进程中断、表被清理、
 * 对端长期不可用转死信而留下缺口。对账每天跑一次，用平台自己的事实表
 * 与发件箱比对，把缺口重新补齐：
 *
 *   1) 已完成课程，但对端没有 course.completed 记录 → 补入箱；
 *   2) 进度差超过阈值，且对端允许扩展通道 → 补一条进度事件（默认关闭）；
 *   3) 统计各对端死信数量，异常时写日志告警。
 *
 * 对账只读事实、只补缺口，不修改学习数据本身，可重复执行。
 */

namespace App\Services\Logic\Learning;

use App\Models\CourseUser as CourseUserModel;
use App\Models\ExamOutbox as ExamOutboxModel;
use App\Repos\Course as CourseRepo;
use App\Repos\ExamOutbox as ExamOutboxRepo;
use App\Services\Learning\Collect as CollectService;
use App\Services\Learning\Peers as PeersService;
use App\Services\Logic\Service as LogicService;

class Reconcile extends LogicService
{

    /**
     * 单轮最多扫描的完成课程数
     */
    const SCAN_LIMIT = 2000;

    /**
     * @param string $target 留空表示全部已启用对端
     * @return array
     */
    public function run($target = '')
    {
        $registry = new PeersService();

        $targets = $target !== ''
            ? [$target => $registry->get($target)]
            : $registry->enabled();

        $report = [];

        foreach ($targets as $key => $peer) {

            if (!$peer['enabled']) {
                $report[$key] = ['skipped' => true, 'reason' => 'peer_disabled'];
                continue;
            }

            $report[$key] = $this->reconcilePeer($key);
        }

        return $report;
    }

    /**
     * @param string $target
     * @return array
     */
    protected function reconcilePeer($target)
    {
        $rows = CourseUserModel::find([
            'conditions' => 'status = :status: AND deleted = 0',
            'bind' => ['status' => CourseUserModel::STATUS_COMPLETED],
            'order' => 'id DESC',
            'limit' => self::SCAN_LIMIT,
        ]);

        $repaired = 0;
        $checked = 0;

        if ($rows) {

            $courseRepo = new CourseRepo();

            $outboxRepo = new ExamOutboxRepo();

            $collect = new CollectService();

            $courseMap = [];

            foreach ($rows as $row) {

                $checked++;

                $courseId = (int)$row->course_id;

                if (!isset($courseMap[$courseId])) {

                    $course = $courseRepo->findById($courseId);

                    $courseMap[$courseId] = $course ? $course : null;
                }

                $course = $courseMap[$courseId];

                if (!$course) continue;

                $factExists = $outboxRepo->existsFact(
                    ExamOutboxModel::TYPE_COMPLETED,
                    (int)$row->user_id,
                    $courseId,
                    CollectService::EVENT_VERSION,
                    $target
                );

                if ($factExists) continue;

                $outbox = $collect->progressUpdated($row, $course, '', '', $target);

                if ($outbox) $repaired++;
            }
        }

        $dead = (new ExamOutboxRepo())->countByStatus(0, ExamOutboxModel::STATUS_DEAD, $target);

        if ($dead > 0) {
            $logger = $this->getLogger('exam');
            $logger->error(sprintf('对账发现 %s 通道存在 %d 条死信，请检查契约字段与网关配置', $target, $dead));
        }

        return [
            'skipped' => false,
            'checked' => $checked,
            'repaired' => $repaired,
            'dead' => $dead,
        ];
    }

}

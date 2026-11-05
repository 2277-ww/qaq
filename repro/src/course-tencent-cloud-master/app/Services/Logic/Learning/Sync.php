<?php
/**
 * 学习进度推送执行器
 *
 * 两个入口：
 * 1) 学生/管理员在「学习进度」窗口点同步 —— 先把当前进度补入发件箱，再投递；
 * 2) 定时任务 exam_sync —— 只投递到期的待发与待重试记录。
 *
 * 投递走统一网关，退避间隔与死信规则对齐接入说明 8.4：
 * 1s / 5s / 30s / 2min / 10min / 1h，第 6 次仍失败转死信；
 * 4xx 属契约错误，不重试，直接置死信并告警。
 *
 * 多对端：一条发送记录带 target，投递时按 target 取路径与白名单；
 * 未启用的对端跳过（保留待发状态），启用后自动补发，不丢事件。
 */

namespace App\Services\Logic\Learning;

use App\Models\Course as CourseModel;
use App\Models\CourseUser as CourseUserModel;
use App\Models\ExamOutbox as ExamOutboxModel;
use App\Repos\Course as CourseRepo;
use App\Repos\ExamOutbox as ExamOutboxRepo;
use App\Services\Learning\Collect as CollectService;
use App\Services\Learning\Gateway as GatewayService;
use App\Services\Learning\Peers as PeersService;
use App\Services\Logic\Service as LogicService;

class Sync extends LogicService
{

    /**
     * 重试退避（秒）
     */
    const BACKOFF = [1, 5, 30, 120, 600, 3600];

    /**
     * 手动同步：把当前学习进度全部入箱并投递
     *
     * @return array
     */
    public function handle()
    {
        $user = $this->getLoginUser();

        $queued = $this->queueUserCourses($user->id);

        $result = $this->flush($user->id);

        $result['queued'] = $queued;

        $result['note'] = $this->policyNote($queued);

        return $result;
    }

    /**
     * 没有新事件入箱时给出原因，避免使用者误以为推送失效
     *
     * @param int $queued
     * @return string
     */
    protected function policyNote($queued)
    {
        if ($queued > 0) return '';

        return '当前是进度中间态：不在跨平台事件目录内，由考试平台回源 '
            . 'GET /api/v1/learning/progress 查询；课程首次完成时才推送 course.completed。';
    }

    /**
     * 同步单门课程
     *
     * @param int $courseId
     * @param int $userId 0 表示当前登录用户（服务态调用时显式传入）
     * @return array
     */
    public function pushCourse($courseId, $userId = 0)
    {
        if ($userId <= 0) {
            $user = $this->getLoginUser();
            $userId = (int)$user->id;
        }

        $queued = $this->queueCourse($userId, $courseId);

        $result = $this->flush($userId);

        $result['queued'] = $queued;

        $result['note'] = $this->policyNote($queued);

        return $result;
    }

    /**
     * 以当前事实补齐发件箱
     *
     * 进度是「状态」而非「流水」，入箱时以最新状态为准；
     * 已上报过的进度由 Collect 内部节流去重。
     *
     * @param int $userId
     * @return int 入箱条数
     */
    public function queueUserCourses($userId)
    {
        $rows = CourseUserModel::find([
            'conditions' => 'user_id = :user_id: AND deleted = 0',
            'bind' => ['user_id' => $userId],
            'order' => 'active_time DESC, id DESC',
        ]);

        if (!$rows) return 0;

        $courseIds = [];

        foreach ($rows as $row) {
            if ((int)$row->progress > 0) {
                $courseIds[] = (int)$row->course_id;
            }
        }

        if (count($courseIds) == 0) return 0;

        $courseRepo = new CourseRepo();

        $courses = $courseRepo->findByIds($courseIds, 'id, title');

        $map = [];

        if ($courses) {
            foreach ($courses->toArray() as $row) {
                $map[(int)$row['id']] = $row;
            }
        }

        $collect = new CollectService();

        $queued = 0;

        foreach ($rows as $row) {

            $courseId = (int)$row->course_id;

            if (!isset($map[$courseId])) continue;

            $course = $this->makeCourse($map[$courseId]);

            $outbox = $collect->progressUpdated($row, $course);

            if ($outbox) $queued++;
        }

        return $queued;
    }

    /**
     * @param int $userId
     * @param int $courseId
     * @return int
     */
    public function queueCourse($userId, $courseId)
    {
        $row = CourseUserModel::findFirst([
            'conditions' => 'user_id = :user_id: AND course_id = :course_id: AND deleted = 0',
            'bind' => ['user_id' => $userId, 'course_id' => $courseId],
            'order' => 'id DESC',
        ]);

        if (!$row) return 0;

        $courseRepo = new CourseRepo();

        $course = $courseRepo->findById($courseId);

        if (!$course) return 0;

        $collect = new CollectService();

        $outbox = $collect->progressUpdated($row, $course);

        return $outbox ? 1 : 0;
    }

    /**
     * 投递到期的待发事件
     *
     * @param int $userId 0 表示全部用户
     * @param int $limit
     * @return array
     */
    public function flush($userId = 0, $limit = 200, $target = '')
    {
        $repo = new ExamOutboxRepo();

        $gateway = new GatewayService();

        $registry = new PeersService();

        $events = $repo->findDue($limit, $userId, $target);

        $maxRetry = (int)$this->getConfig()->path('exam.retry_max', 6);

        $sent = 0;
        $failed = 0;
        $dead = 0;

        $byPeer = [];

        if ($events) {

            foreach ($events as $event) {

                $peerKey = (string)$event->target;

                if ($peerKey === '') $peerKey = 'exam';

                /**
                 * 未启用的对端不投递、也不算失败：事件留在待发状态，
                 * 对端启用后由下一轮定时器自动补发。
                 */
                if (!$registry->isEnabled($peerKey)) continue;

                $error = '';
                $code = 0;

                $ok = $gateway->sendEvent(
                    $peerKey,
                    (string)$event->event_type,
                    $event->getPayloadArray(),
                    $event->event_id,
                    $event->request_id,
                    (string)$event->user_key,
                    $error,
                    $code
                );

                $event->response_code = $code;

                if ($ok) {

                    $event->status = ExamOutboxModel::STATUS_SENT;
                    $event->sent_at = time();
                    $event->last_error = '';
                    $event->next_retry_at = 0;

                    $sent++;

                    $byPeer[$peerKey] = ($byPeer[$peerKey] ?? 0) + 1;

                } else {

                    $event->retry_count = (int)$event->retry_count + 1;
                    $event->last_error = kg_substr((string)$error, 0, 500);

                    /**
                     * 契约错误（4xx）不重试，但 429 与 408 例外：
                     * 429 是网关限流、408 是请求超时，都属于「这次不行、下次可能行」，
                     * 直接判死信会把正常流量当故障丢掉。APISIX 默认限流返回 429。
                     */
                    $retryable = in_array($code, [408, 429], true);

                    $isContractError = $code >= 400 && $code < 500 && !$retryable;

                    if ($isContractError || $event->retry_count >= $maxRetry) {

                        $event->status = ExamOutboxModel::STATUS_DEAD;
                        $event->dead_at = time();
                        $event->next_retry_at = 0;

                        $dead++;

                    } else {

                        $index = min((int)$event->retry_count - 1, count(self::BACKOFF) - 1);

                        $event->status = ExamOutboxModel::STATUS_FAILED;
                        $event->next_retry_at = time() + self::BACKOFF[$index];

                        $failed++;
                    }
                }

                $event->update();
            }
        }

        if ($dead > 0) {
            $logger = $this->getLogger('exam');
            $logger->error(sprintf('学习进度推送进入死信：%d 条，请检查网关地址与契约字段', $dead));
        }

        return [
            'sent' => $sent,
            'failed' => $failed,
            'dead' => $dead,
            'byPeer' => $byPeer,
            'mode' => $gateway->getMode(),
            'endpoint' => $gateway->getEndpoint(),
        ];
    }

    /**
     * 各对端投递统计（页面与接口共用）
     *
     * @param int $userId
     * @return array
     */
    public function peerStats($userId = 0)
    {
        $repo = new ExamOutboxRepo();

        $registry = new PeersService();

        $result = [];

        foreach ($registry->all() as $key => $peer) {

            $lastSent = $repo->findLastSentTime($userId, $key);

            $result[] = [
                'peer' => $key,
                'name' => $peer['name'],
                'enabled' => $peer['enabled'],
                'events' => $peer['events'],
                'extensions' => $peer['extensions'],
                'base_uri' => $peer['enabled'] ? $registry->baseUri($key) : '',
                'endpoint' => $peer['enabled'] ? $registry->endpoint($key) : '',
                'mode' => $registry->baseUri($key) === '' ? 'local' : 'gateway',
                'pending' => $repo->countByStatus($userId, ExamOutboxModel::STATUS_PENDING, $key),
                'sent' => $repo->countByStatus($userId, ExamOutboxModel::STATUS_SENT, $key),
                'failed' => $repo->countByStatus($userId, ExamOutboxModel::STATUS_FAILED, $key),
                'dead' => $repo->countByStatus($userId, ExamOutboxModel::STATUS_DEAD, $key),
                'last_sent_text' => $lastSent > 0 ? date('Y-m-d H:i', $lastSent) : '暂无',
            ];
        }

        return $result;
    }

    /**
     * 同步统计（页面与接口共用）
     *
     * @param int $userId 0 表示全部用户
     * @return array
     */
    public function stats($userId = 0)
    {
        $repo = new ExamOutboxRepo();

        $gateway = new GatewayService();

        $lastSent = $repo->findLastSentTime($userId);

        $registry = new PeersService();

        $exam = $registry->get('exam');

        return [
            'pending' => $repo->countByStatus($userId, ExamOutboxModel::STATUS_PENDING),
            'sent' => $repo->countByStatus($userId, ExamOutboxModel::STATUS_SENT),
            'failed' => $repo->countByStatus($userId, ExamOutboxModel::STATUS_FAILED),
            'dead' => $repo->countByStatus($userId, ExamOutboxModel::STATUS_DEAD),
            'acked' => $repo->countAcked('exam', true, $userId),
            'last_sent_at' => $lastSent,
            'last_sent_text' => $lastSent > 0 ? date('Y-m-d H:i', $lastSent) : '暂无',
            'mode' => $gateway->getMode(),
            'endpoint' => $gateway->getEndpoint(),
            'enabled' => $exam['enabled'],
            'auth_mode' => $registry->authMode('exam'),
            'app_code' => $exam['inbound_app_code'],
            'query_enabled' => $exam['query'],
            'peers' => $this->peerStats($userId),
        ];
    }

    /**
     * @param array $row
     * @return CourseModel
     */
    protected function makeCourse(array $row)
    {
        $course = new CourseModel();

        $course->id = (int)$row['id'];
        $course->title = (string)$row['title'];

        return $course;
    }

}

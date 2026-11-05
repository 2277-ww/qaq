<?php
/**
 * 学习进度对外接口（预留契约）
 *
 * 路径：/api/v1/learning/*
 * 入口：浏览器/考试平台 → 统一网关 → 本控制器
 *
 * 已实现：
 *   GET  /api/v1/learning/progress/{userId}              全量进度快照
 *   GET  /api/v1/learning/progress/{userId}/{courseId}   单课程进度明细
 *   GET  /api/v1/learning/completion/{userId}/{courseId} 完成状态（考试准入回源）
 *   POST /api/v1/learning/progress/push                  触发进度推送（服务态）
 *   GET  /api/v1/learning/sync/{eventId}                 查询单条推送状态
 *
 * 约定：
 * 1) 只信任网关注入的可信头，且按 gateway.verify_sign 校验 X-Internal-Sign；
 * 2) 响应体统一 {code, message, data, requestId}，code 为字符串业务码；
 * 3) 写操作必须带 Idempotency-Key。
 */

namespace App\Http\Api\Controllers;

use App\Exceptions\BadRequest as BadRequestException;
use App\Services\Learning\IdentityKey;
use App\Services\Learning\TrustedHeader;
use App\Services\Logic\Learning\Progress as ProgressService;
use App\Services\Logic\Learning\Sync as SyncService;
use App\Repos\ExamOutbox as ExamOutboxRepo;
use Phalcon\Mvc\Dispatcher;

/**
 * @RoutePrefix("/api/v1/learning")
 */
class LearningController extends Controller
{

    /**
     * @var array
     */
    protected $trusted = [];

    public function beforeExecuteRoute(Dispatcher $dispatcher)
    {
        parent::beforeExecuteRoute($dispatcher);

        $service = new TrustedHeader();

        $trusted = $service->verify();

        $this->trusted = $trusted;

        if (!$trusted['ok']) {
            $message = $trusted['error'] == 'bad_signature'
                ? '请求签名校验失败' : '网关身份头校验失败';

            $this->sendEnvelope('AUTH_REQUIRED', $message, $trusted['requestId'], 401);

            return false;
        }

        return true;
    }

    /**
     * @Get("/progress/{userId}", name="api.learning.progress")
     */
    public function progressAction($userId)
    {
        $this->assertReadable($userId);

        $service = new ProgressService();

        return $this->respond(function () use ($service, $userId) {
            return $service->snapshot($this->resolveUserId($userId));
        });
    }

    /**
     * @Get("/progress/{userId}/{courseId:[0-9]+}", name="api.learning.progress_course")
     */
    public function progressCourseAction($userId, $courseId)
    {
        $this->assertReadable($userId);

        $service = new ProgressService();

        return $this->respond(function () use ($service, $userId, $courseId) {
            return $service->courseDetail($this->resolveUserId($userId), (int)$courseId);
        });
    }

    /**
     * @Get("/completion/{userId}/{courseId:[0-9]+}", name="api.learning.completion")
     */
    public function completionAction($userId, $courseId)
    {
        $this->assertReadable($userId);

        $service = new ProgressService();

        return $this->respond(function () use ($service, $userId, $courseId) {
            return $service->completion($this->resolveUserId($userId), (int)$courseId);
        });
    }

    /**
     * @Post("/progress/push", name="api.learning.progress_push")
     */
    public function progressPushAction()
    {
        if ($this->trusted['verified'] && $this->trusted['mode'] !== 'service') {
            return $this->fail('FORBIDDEN', '该操作仅允许服务态调用（X-Auth-Mode: service）', 403);
        }

        $idempotencyKey = trim((string)$this->request->getHeader('Idempotency-Key'));

        if ($idempotencyKey === '') {
            return $this->fail('VALIDATION_ERROR', '缺少 Idempotency-Key', 400);
        }

        $body = $this->request->getJsonRawBody(true);

        $userId = isset($body['userId']) ? (string)$body['userId'] : (string)$this->request->getPost('userId', 'string', '');

        $courseId = isset($body['courseId']) ? (int)preg_replace('/\D/', '', (string)$body['courseId']) : 0;

        if ($userId === '') {
            return $this->fail('VALIDATION_ERROR', '缺少 userId', 400);
        }

        $internalId = $this->resolveUserId($userId);

        if ($internalId <= 0) {
            return $this->fail('NOT_FOUND', '用户不存在', 404);
        }

        $service = new SyncService();

        $result = $courseId > 0
            ? $service->pushCourse($courseId, $internalId)
            : $this->queueAll($service, $internalId);

        $result['idempotencyKey'] = $idempotencyKey;

        return $this->ok($result, 200);
    }

    /**
     * @Get("/sync/{eventId}", name="api.learning.sync_status")
     */
    public function syncStatusAction($eventId)
    {
        $repo = new ExamOutboxRepo();

        $event = $repo->findByEventId($eventId);

        if (!$event) {
            return $this->fail('NOT_FOUND', '事件不存在', 404);
        }

        $data = [
            'eventId' => $event->event_id,
            'eventType' => $event->event_type,
            'userId' => $event->user_key,
            'courseId' => $event->course_key,
            'progress' => (int)$event->progress,
            'status' => (int)$event->status,
            'statusText' => $event->getStatusText(),
            'retryCount' => (int)$event->retry_count,
            'responseCode' => (int)$event->response_code,
            'lastError' => (string)$event->last_error,
            'occurredAt' => gmdate('Y-m-d\TH:i:s\Z', (int)$event->occurred_at),
            'sentAt' => $event->sent_at > 0 ? gmdate('Y-m-d\TH:i:s\Z', (int)$event->sent_at) : null,
        ];

        return $this->ok($data);
    }

    /**
     * @param SyncService $service
     * @param int $userId
     * @return array
     */
    protected function queueAll(SyncService $service, $userId)
    {
        $queued = $service->queueUserCourses($userId);

        $result = $service->flush($userId);

        $result['queued'] = $queued;

        return $result;
    }

    /**
     * 服务态可读任意用户；用户态只能读自己
     *
     * @param string $userKey
     */
    protected function assertReadable($userKey)
    {
        if (!$this->trusted['verified']) return;

        if ($this->trusted['mode'] === 'service') return;

        if ((string)$this->trusted['userId'] === (string)$userKey) return;

        throw new \App\Exceptions\Forbidden('sys.forbidden');
    }

    /**
     * @param string $userKey
     * @return int 无法解析时返回 0，由调用方按 404 处理
     */
    protected function resolveUserId($userKey)
    {
        $identity = new IdentityKey();

        return (int)$identity->resolveUserId($userKey);
    }

    /**
     * 统一把业务异常转成契约错误码，避免 API 落到站点 404 页
     *
     * @param callable $handler
     * @return \Phalcon\Http\Response
     */
    protected function respond(callable $handler)
    {
        try {

            return $this->ok($handler());

        } catch (BadRequestException $e) {

            return $this->fail('NOT_FOUND', '用户或课程学习记录不存在', 404);

        } catch (\App\Exceptions\Forbidden $e) {

            return $this->fail('FORBIDDEN', '无权访问该用户的学习数据', 403);
        }
    }

    /**
     * @param array $data
     * @param int $status
     * @return \Phalcon\Http\Response
     */
    protected function ok($data, $status = 200)
    {
        return $this->sendEnvelope('OK', 'success', $this->trusted['requestId'], $status, $data);
    }

    /**
     * @param string $code
     * @param string $message
     * @param int $status
     * @return \Phalcon\Http\Response
     */
    protected function fail($code, $message, $status = 400)
    {
        return $this->sendEnvelope($code, $message, $this->trusted['requestId'], $status);
    }

    /**
     * @param string $code
     * @param string $message
     * @param string $requestId
     * @param int $status
     * @param array $data
     * @return \Phalcon\Http\Response
     */
    protected function sendEnvelope($code, $message, $requestId, $status = 200, $data = [])
    {
        $content = [
            'code' => $code,
            'message' => $message,
            'data' => $data,
            'requestId' => $requestId,
        ];

        $this->response->setStatusCode($status);

        $this->response->setHeader('X-Request-Id', $requestId);

        $this->response->setJsonContent($content);

        return $this->response;
    }

}

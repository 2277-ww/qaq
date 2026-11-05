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
 * 预留（实训平台 / 论坛平台对接）：
 *   GET  /api/v1/learning/peers                          能力发现：对端、事件类型、路径
 *   POST /api/v1/learning/internal/peers/{source}/events          接收对端回传事件（服务态）
 *   GET  /api/v1/learning/internal/peers/{source}/events/{eventId} 查询回传事件受理状态
 *
 * 预留（考试平台对接，双向）：
 *   POST /api/v1/learning/internal/peers/{source}/receipts        接收投递回执（服务态）
 *   GET  /api/v1/learning/internal/peers/{source}/pull            按游标增量拉取（服务态）
 *   POST /api/v1/learning/internal/peers/{source}/replay          失败事件重放（服务态，需 Idempotency-Key）
 *   GET  /api/v1/learning/internal/peers/{source}/handshake       对接握手：契约版本、鉴权要求、能力清单
 *   GET  /api/v1/learning/internal/peers/{source}/students/{userId}/progress      服务态查学习进度
 *   GET  /api/v1/learning/internal/peers/{source}/students/{userId}/completion/{courseId}  服务态查准入判定
 *
 * 鉴权三条通道（按可信度从高到低）：
 * 1) 用户态：统一网关注入 X-User-Id / X-Auth-Mode / X-Timestamp / X-Internal-Sign，
 *    按 gateway.verify_sign 校验签名，身份即该用户；
 * 2) 网关服务态：网关 L2 验过对端 AppKey 后注入 X-Auth-Mode=service，
 *    没有 X-App-Code，对端身份由路径里的 {source} 决定，只能读该通道开放的能力；
 * 3) 对端直连态：对端自带 X-App-Code + X-Request-Id + X-Timestamp + X-Internal-Sign，
 *    按 peers.<对端>.auth_mode 校验（signature / token / none），身份只限自己的通道。
 *    用于对端与网关同机直连、或尚未过网关的联调阶段。
 *
 * 注意 2 与 3 的签名规范不同，但都写在 X-Internal-Sign 这个头名上：
 *   网关服务态 —— 七字段（user/role/client/tokenExp/requestId/authMode/timestamp）
 *   对端直连态 —— 四字段（appCode / requestId / timestamp / sha256(body)）
 * 区分依据是 X-Auth-Mode：网关一定注入该头且值为 service（L2）或 user（L1），
 * 因此服务态分支优先于 X-App-Code 判定。对端经网关调用时即使多带一个
 * X-App-Code 也不会被误判成直连态，但建议不带，避免排障时两条链路混淆。
 *
 * 约定：
 * 1) 响应体统一 {code, message, data, requestId}，code 为字符串业务码；
 * 2) 写操作必须带 Idempotency-Key。
 */

namespace App\Http\Api\Controllers;

use App\Exceptions\BadRequest as BadRequestException;
use App\Services\Learning\Gateway;
use App\Services\Learning\GatewaySign;
use App\Services\Learning\IdentityKey;
use App\Services\Learning\Inbox as InboxService;
use App\Services\Learning\PeerAuth;
use App\Services\Learning\Peers as PeersService;
use App\Services\Learning\Pull as PullService;
use App\Services\Learning\Receipt as ReceiptService;
use App\Services\Learning\Replay as ReplayService;
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

        if ((string)$dispatcher->getActionName() === 'unauthorized') return true;

        $trusted = (new TrustedHeader())->verify();

        $this->trusted = $trusted;

        /**
         * 带用户身份的网关调用优先：这类请求已经过统一身份认证，
         * 对端服务态鉴权只用于「没有用户」的机器调用。
         */
        if ($trusted['ok'] && $trusted['userId'] !== '') {
            return true;
        }

        /**
         * 网关服务态（L2）：网关验过对端 AppKey 后注入 X-Auth-Mode=service。
         *
         * 这类请求没有用户身份，也没有 X-App-Code——网关只把七头加内部签名
         * 转给上游，不透传 AppKey。因此对端身份由 URL 里的 {source} 决定，
         * 由 peerGuard 校验该通道是否登记、能力是否开通。
         *
         * 安全性依据：走到这里说明 TrustedHeader 已按 gateway.verify_sign
         * 校验过内部签名，伪造一个 X-Auth-Mode 头无法通过。
         *
         * 注意 message 中的 mode 与直连对端（peer）区分开：前者对端未知、
         * 只受通道约束；后者已由 X-App-Code 认到具体对端，必须收紧到自己的通道。
         */
        if ($trusted['ok'] && $trusted['mode'] === 'service') {

            $this->trusted['mode'] = 'peer-service';

            $this->trusted['peer'] = '';

            return true;
        }

        $peer = (new PeerAuth())->authenticate();

        if ($peer['ok']) {

            $this->trusted = [
                'ok' => true,
                'error' => '',
                'userId' => '',
                'roles' => [],
                'mode' => 'peer',
                'peer' => $peer['peer'],
                'authMode' => $peer['authMode'],
                'verified' => $peer['verified'],
                'requestId' => $peer['requestId'],
                'tokenExp' => 0,
                'clientId' => $peer['clientId'],
            ];

            return true;
        }

        /**
         * 握手与能力发现免鉴权：对端接入前还没拿到密钥，只能先读契约；
         * 两者都不返回任何学生数据。
         *
         * 这里按请求路径判断，不用 dispatcher 的 action 名——action 会受
         * camelize / 后缀 / 命名风格配置影响，一旦取值变化就会把握手挡在
         * 鉴权外面，对端反而拿不到签名规范。
         */
        $path = (string)parse_url((string)$this->request->getURI(), PHP_URL_PATH);

        $open = (bool)preg_match(
            '#^/api/v1/learning/(internal/)?peers(/[A-Za-z0-9_\-]+/handshake)?$#',
            $path
        );

        if ($open) return true;

        /**
         * 未接入网关的复现环境：TrustedHeader 已放行但没有用户身份，
         * 按本机调用处理（便于本地联调与运维脚本），生产环境应开启 verify_sign。
         *
         * 但请求一旦声明了 X-App-Code，就必须通过对端鉴权——否则随便填一个
         * 编码就能绕过校验，等于没有鉴权。
         */
        if ($trusted['ok'] && $peer['appCode'] === '') {

            $this->trusted['mode'] = 'local';

            return true;
        }

        $map = [
            'bad_signature' => '请求签名校验失败',
            'missing_signature' => '缺少 X-Internal-Sign',
            'missing_request_id' => '缺少 X-Request-Id（参与签名）',
            'missing_app_code' => '缺少 X-App-Code，无法识别调用方',
            'unknown_app_code' => 'X-App-Code 未注册',
            'peer_disabled' => '该对端通道未启用',
            'bad_token' => '对端令牌校验失败',
            'missing_timestamp' => '缺少 X-Timestamp',
            'timestamp_expired' => '请求时间戳超出允许窗口',
            'secret_not_configured' => '对端密钥未配置，无法校验签名',
            'token_not_configured' => '对端令牌未配置，无法校验',
        ];

        $message = $map[$peer['error']] ?? '网关身份头校验失败';

        /**
         * 在 beforeExecuteRoute 里中断 dispatch 时，框架不会把 response 送出去。
         * 这里 forward 到统一的未授权动作，走正常动作返回流程，
         * 保证调用方拿到完整契约错误体（只有状态码对对接方毫无帮助）。
         */
        $dispatcher->forward([
            'controller' => 'learning',
            'action' => 'unauthorized',
            'params' => [$message],
        ]);

        return false;
    }

    /**
     * 统一未授权响应（由 beforeExecuteRoute forward 进入）
     *
     * 注意：不注册路由注解，避免对外多开一个入口；forward 不需要路由。
     *
     * @param string $message
     * @return \Phalcon\Http\Response
     */
    public function unauthorizedAction($message = '网关身份头校验失败')
    {
        /**
         * forward 会重新进入 dispatch，此时 $this->trusted 可能已被重置，
         * 请求编号直接从请求头取，没有再生成一个，保证与调用方手里的值一致。
         */
        $requestId = trim((string)$this->request->getHeader('X-Request-Id'));

        if ($requestId === '') {
            $requestId = (new Gateway())->makeRequestId();
        }

        return $this->sendEnvelope('AUTH_REQUIRED', (string)$message, $requestId, 401);
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
     * 能力发现：对端接入前自检用
     *
     * @Get("/peers", name="api.learning.peers")
     */
    public function peersAction()
    {
        $registry = new PeersService();

        return $this->ok([
            'peers' => $registry->describe(),
            'catalog' => PeersService::CATALOG,
            'generatedAt' => gmdate('Y-m-d\TH:i:s\Z'),
        ]);
    }

    /**
     * 对接握手：对端接入的第一步，拿契约版本、鉴权要求、能力清单与路径
     *
     * 免鉴权，但不返回任何学生数据。对端可用它自检「我的 appCode 配对了没」
     * 「我该签哪个串」「哪条能力还没对我开通」，避免双方靠猜路径联调。
     *
     * @Get("/peers/{source}/handshake", name="api.learning.peer_handshake")
     */
    public function peerHandshakeAction($source)
    {
        $registry = new PeersService();

        $peer = $registry->get($source);

        $appCode = trim((string)$this->request->getHeader('X-App-Code'));

        $resolved = $registry->findByAppCode($appCode);

        $auth = new PeerAuth();

        $authMode = $registry->authMode($source);

        $prefix = '/api/v1/learning/internal/peers/' . $source;

        return $this->ok([
            'contract' => 'learning-progress/1.0',
            'peer' => (string)$source,
            'peerName' => $peer['name'],
            'peerEnabled' => $peer['enabled'],
            'serverTime' => gmdate('Y-m-d\TH:i:s\Z'),
            'timestamp' => time(),
            'timezone' => 'UTC',
            'declaredAppCode' => $appCode,
            'appCodeMatched' => $resolved !== '' && $resolved === (string)$source,
            'auth' => [
                'mode' => $authMode,
                'upgradable' => $authMode === 'none',
                'headers' => ['X-App-Code', 'X-Request-Id', 'X-Timestamp', 'X-Internal-Sign'],
                'signature' => [
                    'algorithm' => 'HMAC-SHA256',
                    'output' => 'hex-lowercase',
                    'secretRef' => 'peers.' . $source . '.secret',
                    'canonical' => $auth->canonicalPattern(),
                    'skewSeconds' => $auth->skewSeconds(),
                ],
                'token' => [
                    'header' => 'Authorization: Bearer <token>',
                    'alternative' => 'X-Api-Key: <token>',
                    'enabled' => $authMode === 'token',
                ],
            ],
            'catalog' => PeersService::CATALOG,
            /**
             * 经统一网关调用本平台的入口规范
             *
             * 对端在本平台「上游」位置时，请求必须先过网关。网关对机器调用
             * 只认 L2 签名，本平台自建的 X-App-Code 那套到不了这一层；
             * 网关验完后会剥离 L2 头、重算七字段 X-Internal-Sign 注入本平台，
             * 所以对端只需要签 L2，本平台验的是网关重算结果。
             */
            'gatewayEntry' => [
                'baseUri' => (new Gateway())->getBaseUri(),
                'route' => '/api/v1/learning/*',
                'note' => '服务态调用走网关 L2；learning-internal 配额为 200 QPS/AppKey',
                'l2' => [
                    'enabled' => (new GatewaySign())->isEnabled($source),
                    'appKey' => (new GatewaySign())->appKey($source),
                    'headers' => GatewaySign::HEADERS,
                    'algorithm' => GatewaySign::ALG,
                    'canonical' => (new GatewaySign())->canonicalPattern(),
                    'skewSeconds' => (int)$this->getConfig()->path('gateway.timestamp_skew', 300),
                    'nonceTtlSeconds' => 600,
                    'queryRule' => '按 (key, value) 字典序排序后重新编码，空格编码为 "+"',
                    'errors' => GatewaySign::ERRORS,
                ],
                'upstreamSignature' => [
                    'header' => 'X-Internal-Sign',
                    'algorithm' => 'HMAC-SHA256',
                    'note' => '网关重算后注入，对端无需自行生成；本平台按 gateway.verify_sign 校验',
                ],
            ],
            'outboundReady' => (new Gateway())->isConfigured($source),
            'notice' => (new Gateway())->isConfigured($source)
                ? '' : '本平台尚未配置该对端网关地址，进度事件只入箱、暂不外发；配好 base_uri 后自动补发',
            'capabilities' => [
                'push' => [
                    'enabled' => $peer['enabled'],
                    'path' => $peer['push_path'],
                    'endpoint' => $peer['enabled'] ? $registry->endpoint($source) : '',
                    'mode' => (new Gateway())->getMode($source),
                    'events' => $peer['events'],
                    'idempotencyKey' => 'eventId',
                ],
                'receipts' => [
                    'enabled' => $peer['ack'],
                    'path' => $peer['ack'] ? $prefix . '/receipts' : '',
                    'eventTypes' => $peer['ack'] ? [(new ReceiptService())->ackEventType($source)] : [],
                ],
                'pull' => [
                    'enabled' => $peer['pull'],
                    'path' => $peer['pull'] ? $prefix . '/pull' : '',
                    'limit' => $peer['pull'] ? (int)$peer['pull_limit'] : 0,
                    'cursor' => 'afterId',
                ],
                'replay' => [
                    'enabled' => $peer['replay'],
                    'path' => $peer['replay'] ? $prefix . '/replay' : '',
                    'requiredHeader' => 'Idempotency-Key',
                ],
                'query' => [
                    'enabled' => $peer['query'],
                    'progressPath' => $peer['query'] ? $prefix . '/students/{userId}/progress' : '',
                    'completionPath' => $peer['query'] ? $prefix . '/students/{userId}/completion/{courseId}' : '',
                ],
                'eventStatus' => [
                    'path' => $prefix . '/events/{eventId}',
                ],
                'inboundEvents' => $registry->inboundEvents($source),
            ],
            'envelope' => [
                'eventId' => 'evt_0123456789ABCDEF',
                'eventType' => 'course.completed',
                'eventVersion' => '1.0',
                'occurredAt' => '2026-11-05T10:00:00Z',
                'sourcePlatform' => 'learning',
                'sourceEntityId' => 'course_2',
                'actorId' => 'usr_10000',
                'correlationId' => '',
                'requestId' => 'req_0123456789ABCDEF',
                'data' => [
                    'userId' => 'usr_10000',
                    'courseId' => 'course_2',
                    'progress' => 100,
                    'completed' => true,
                ],
            ],
        ]);
    }

    /**
     * 服务态查询单个学生的学习进度（考试平台开放随堂测试用）
     *
     * @Get("/peers/{source}/students/{userId:[A-Za-z0-9_\-]+}/progress", name="api.learning.peer_student_progress")
     */
    public function peerStudentProgressAction($source, $userId)
    {
        if ($guard = $this->peerGuard($source, 'query')) return $guard;

        $service = new ProgressService();

        return $this->respond(function () use ($service, $userId) {
            return $service->snapshot($this->resolveUserId($userId));
        });
    }

    /**
     * 服务态查询准入判定（考试平台开考前回源）
     *
     * @Get("/peers/{source}/students/{userId:[A-Za-z0-9_\-]+}/completion/{courseId:[0-9]+}", name="api.learning.peer_student_completion")
     */
    public function peerStudentCompletionAction($source, $userId, $courseId)
    {
        if ($guard = $this->peerGuard($source, 'query')) return $guard;

        $service = new ProgressService();

        return $this->respond(function () use ($service, $userId, $courseId) {
            return $service->completion($this->resolveUserId($userId), (int)$courseId);
        });
    }

    /**
     * 接收对端回传的事件（实训平台 / 论坛平台）
     *
     * @Post("/peers/{source}/events", name="api.learning.peer_event")
     */
    public function peerEventAction($source)
    {
        if ($guard = $this->peerGuard($source)) return $guard;

        $body = $this->request->getJsonRawBody(true);

        if (!is_array($body) || count($body) == 0) {
            return $this->fail('VALIDATION_ERROR', '请求体必须是事件封套 JSON', 400);
        }

        $service = new InboxService();

        $result = $service->accept((string)$source, $body, $this->trusted['requestId']);

        if (!$result['ok']) {

            $map = ['PEER_NOT_OPEN' => 403, 'EVENT_NOT_ALLOWED' => 422];

            $status = $map[$result['code']] ?? 400;

            return $this->fail($result['code'], $result['message'], $status);
        }

        return $this->sendEnvelope('OK', $result['message'], $this->trusted['requestId'], 202, [
            'status' => $result['status'],
            'inboxId' => $result['inboxId'],
            'eventId' => $result['eventId'],
        ]);
    }

    /**
     * 查询回传事件受理状态
     *
     * @Get("/peers/{source}/events/{eventId}", name="api.learning.peer_event_status")
     */
    public function peerEventStatusAction($source, $eventId)
    {
        if ($guard = $this->peerGuard($source)) return $guard;

        $service = new InboxService();

        $row = $service->status((string)$source, (string)$eventId);

        if (!$row) {
            return $this->fail('NOT_FOUND', '该事件未受理', 404);
        }

        return $this->ok([
            'source' => $row->source,
            'eventId' => $row->event_id,
            'eventType' => $row->event_type,
            'eventVersion' => $row->event_version,
            'status' => (int)$row->status,
            'statusText' => $row->getStatusText(),
            'receivedAt' => gmdate('Y-m-d\TH:i:s\Z', (int)$row->received_at),
            'processedAt' => $row->processed_at > 0 ? gmdate('Y-m-d\TH:i:s\Z', (int)$row->processed_at) : null,
        ]);
    }

    /**
     * 接收对端投递回执（考试平台确认已入库）
     *
     * @Post("/peers/{source}/receipts", name="api.learning.peer_receipt")
     */
    public function peerReceiptAction($source)
    {
        if ($guard = $this->peerGuard($source)) return $guard;

        $body = $this->request->getJsonRawBody(true);

        if (!is_array($body) || count($body) == 0) {
            return $this->fail('VALIDATION_ERROR', '请求体必须是事件封套 JSON', 400);
        }

        $service = new ReceiptService();

        $result = $service->apply((string)$source, $body, $this->trusted['requestId']);

        if (!$result['ok']) {

            $map = [
                'RECEIPT_NOT_OPEN' => 403,
                'EVENT_NOT_ALLOWED' => 422,
                'TARGET_EVENT_NOT_FOUND' => 422,
            ];

            $status = $map[$result['code']] ?? 400;

            return $this->fail($result['code'], $result['message'], $status);
        }

        return $this->sendEnvelope('OK', $result['message'], $this->trusted['requestId'], 202, $result['data']);
    }

    /**
     * 对端增量拉取（考试平台补漏推）
     *
     * @Get("/peers/{source}/pull", name="api.learning.peer_pull")
     */
    public function peerPullAction($source)
    {
        if ($guard = $this->peerGuard($source)) return $guard;

        $userId = trim((string)$this->request->getQuery('userId', 'string', ''));

        if ($userId === '') {
            return $this->fail('VALIDATION_ERROR', '缺少 userId', 400);
        }

        $afterId = (int)$this->request->getQuery('afterId', 'int', 0);

        $limit = (int)$this->request->getQuery('limit', 'int', 0);

        $since = 0;

        $sinceRaw = trim((string)$this->request->getQuery('since', 'string', ''));

        if ($sinceRaw !== '') {
            $since = (int)strtotime($sinceRaw);
            if ($since <= 0) {
                return $this->fail('VALIDATION_ERROR', 'since 需为 ISO8601 时间，如 2026-11-05T00:00:00Z', 400);
            }
        }

        $service = new PullService();

        $result = $service->events((string)$source, $userId, $afterId, $since, $limit);

        if (!$result['ok']) {

            $map = ['PULL_NOT_OPEN' => 403];

            $status = $map[$result['code']] ?? 400;

            return $this->fail($result['code'], $result['message'], $status);
        }

        return $this->ok($result['data']);
    }

    /**
     * 失败事件重放（对账后重推）
     *
     * @Post("/peers/{source}/replay", name="api.learning.peer_replay")
     */
    public function peerReplayAction($source)
    {
        if ($guard = $this->peerGuard($source)) return $guard;

        $idempotencyKey = trim((string)$this->request->getHeader('Idempotency-Key'));

        if ($idempotencyKey === '') {
            return $this->fail('VALIDATION_ERROR', '缺少 Idempotency-Key', 400);
        }

        $body = $this->request->getJsonRawBody(true);

        if (!is_array($body)) {
            $body = [];
        }

        $service = new ReplayService();

        $result = $service->apply((string)$source, $body);

        if (!$result['ok']) {

            $map = ['REPLAY_NOT_OPEN' => 403];

            $status = $map[$result['code']] ?? 400;

            return $this->fail($result['code'], $result['message'], $status);
        }

        $result['data']['idempotencyKey'] = $idempotencyKey;

        return $this->ok($result['data']);
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
            'acked' => $event->isAcked(),
            'ackStatus' => (string)$event->ack_status,
            'remoteId' => (string)$event->remote_id,
            'ackedAt' => $event->acked_at > 0 ? gmdate('Y-m-d\TH:i:s\Z', (int)$event->acked_at) : null,
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
     * 对端通道守卫
     *
     * 1) 服务态身份只能访问自己的通道——否则拿到考试平台密钥的一方
     *    就能读实训、论坛的数据；
     * 2) 指定的能力未开通时直接拒绝，避免对端在通道未启用时误以为调用成功。
     *
     * @param string $source
     * @param string $ability ack|pull|replay|query
     * @return \Phalcon\Http\Response|null
     */
    protected function peerGuard($source, $ability = '')
    {
        $registry = new PeersService();

        if (!$registry->exists($source)) {
            return $this->fail('PEER_NOT_FOUND', '该对端未在平台登记', 404);
        }

        $mode = (string)($this->trusted['mode'] ?? '');

        if ($mode === 'peer' && (string)($this->trusted['peer'] ?? '') !== (string)$source) {
            return $this->fail('PEER_SCOPE_DENIED', '对端只能访问自己的通道', 403);
        }

        /**
         * 网关服务态的对端归属收紧
         *
         * 当前网关版本不把 AppKey 转给上游，因此服务态调用只能靠路径认通道，
         * 理论上一家对端可以读另一家的通道——前提是它知道路径且对方通道已开通。
         *
         * 一旦网关侧补上 proxy-rewrite 注入 X-App-Key（不改路径，仍满足
         * 「路径不重写」约束），该分支会自动生效，把服务态调用钉回自己的通道，
         * 本平台无需再改代码。
         */
        if ($mode === 'peer-service') {

            $appKey = trim((string)$this->request->getHeader('X-App-Key'));

            $expect = (string)$registry->get($source)['app_key'];

            if ($appKey !== '' && $expect !== '' && !hash_equals($expect, $appKey)) {

                return $this->fail('PEER_SCOPE_DENIED', '该应用凭据无权访问此对端通道', 403);
            }
        }

        if ($ability !== '' && !$registry->hasAbility($source, $ability)) {
            return $this->fail(strtoupper($ability) . '_NOT_OPEN', '该对端通道未开通此能力', 403);
        }

        return null;
    }

    /**
     * 服务态可读任意用户；用户态只能读自己；对端服务态只能走 peers 通道
     *
     * @param string $userKey
     */
    protected function assertReadable($userKey)
    {
        if (($this->trusted['mode'] ?? '') === 'peer') {
            throw new \App\Exceptions\Forbidden('sys.forbidden');
        }

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

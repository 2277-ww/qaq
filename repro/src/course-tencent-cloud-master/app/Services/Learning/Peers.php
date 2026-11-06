<?php
/**
 * 跨平台对端注册表
 *
 * 本平台的学习进度除考试平台外，后续还要对接实训平台与论坛平台。
 * 三者共用同一条出口链路（发件箱 → 统一网关），差异只在：
 *   1) 网关上的投递路径（push_path）；
 *   2) 允许发送的事件类型（事件目录白名单）；
 *   3) 是否允许发送本地扩展事件（extensions，对应接入说明 8.1 的通道隔离纪律）；
 *   4) 反向能力：回执（ack）、增量拉取（pull）、失败重放（replay）。
 *
 * 因此把"对端"抽成一份配置，新增对端只改 config/peers，不改投递代码。
 *
 * 配置位置：config/config.php 的 $config['peers']
 */

namespace App\Services\Learning;

use App\Services\Service;

class Peers extends Service
{

    /**
     * 正式通道：事件目录内的类型，可上跨平台通道
     */
    const CHANNEL_OFFICIAL = 'official';

    /**
     * 扩展通道：本地扩展事件，必须与正式通道隔离（不同路径）
     */
    const CHANNEL_EXTENSION = 'extension';

    /**
     * 事件目录（接入说明 8.1）：只有这些类型允许上正式通道
     */
    const CATALOG = [
        'course.completed',
    ];

    /**
     * 对端默认值
     *
     * base_uri    —— 该对端专属网关根地址。留空表示沿用全局 gateway.base_uri；
     *               五平台统一网关若按平台分片部署（如论坛平台独立一台），在此覆盖。
     * 入站方向（对端调我们）：
     * inbound_app_code —— 对端自己的应用编码，入站时用它识别调用方。注意与
     *                    app_code（我们投递给对端时用的编码）方向相反，不能混用，
     *                    三个平台共用出站 app_code=`learning`，入站必须各自唯一。
     * secret           —— 该对端专用的签名密钥，留空表示尚未发放（走 auth_mode 回退）。
     * auth_mode        —— auto|signature|token|none。auto 表示有 secret 就必须签名。
     * token            —— token 模式下比对的 Bearer 令牌。
     * query            —— 是否允许该对端查询学生学习进度与完成状态（准入回源）。
     *
     * 出站方向（我们调对端）：
     * access_token —— 该对端网关要求的 Bearer 令牌，覆盖全局 gateway.access_token。
     * headers      —— 附加请求头，适配 APISIX key-auth（X-API-Key）等网关插件。
     * app_key      —— 网关 L2 应用标识（如 jy-learning-svc），覆盖全局 gateway.app_key。
     *                 五平台共用同一把 AppKey，但对端若挂在另一个网关实例上，
     *                 可能被发放了不同的 AppKey，因此允许对端级覆盖。
     * app_secret   —— 上述 AppKey 对应的密钥，覆盖全局 gateway.app_secret。
     *
     * 注意 app_code 与 app_key 不是一回事：app_code 是本平台自建的 X-App-Code
     * 通道标识，app_key 是统一网关的 L2 凭据。两者会同时出现在一次出站请求里，
     * 前者给下游业务验，后者给网关验。
     *
     * ack     —— 是否接收该对端的投递回执（对端确认已入库）；
     * pull    —— 是否允许该对端主动拉取增量事件（补漏推）；
     * replay  —— 是否允许该对端请求重放失败事件；
     * pull_limit —— 单次拉取的最大条数上限。
     */
    const DEFAULTS = [
        'enabled' => false,
        'name' => '',
        'base_uri' => '',
        'app_code' => 'learning',
        'app_key' => '',
        'app_secret' => '',
        'push_path' => '',
        'events' => [],
        'extensions' => false,
        'extension_path' => '',
        'inbound' => false,
        'inbound_events' => [],
        'inbound_app_code' => '',
        'secret' => '',
        'auth_mode' => 'auto',
        'token' => '',
        'query' => false,
        'access_token' => '',
        'headers' => [],
        'ack' => false,
        'pull' => false,
        'pull_limit' => 200,
        'replay' => false,
    ];

    /**
     * 全部对端（含未启用，供能力发现与管理页展示）
     *
     * @return array
     */
    public function all()
    {
        $raw = $this->toArray($this->getConfig()->path('peers', []));

        if (count($raw) == 0) {
            $raw = $this->legacy();
        }

        $peers = [];

        foreach ($raw as $key => $item) {
            $peers[(string)$key] = $this->normalize((string)$key, $item);
        }

        return $peers;
    }

    /**
     * 已启用的对端
     *
     * @return array
     */
    public function enabled()
    {
        $result = [];

        foreach ($this->all() as $key => $peer) {
            if ($peer['enabled']) $result[$key] = $peer;
        }

        return $result;
    }

    /**
     * @param string $key
     * @return array
     */
    public function get($key)
    {
        $peers = $this->all();

        $key = (string)$key;

        if (isset($peers[$key])) return $peers[$key];

        return $this->normalize($key, []);
    }

    /**
     * 该对端是否已在平台登记
     *
     * 与 isEnabled 区分：未登记的对端应返回 404，登记但关闭的返回 403，
     * 对端排查时能直接区分「路径/编码写错」和「通道没开」。
     *
     * @param string $key
     * @return bool
     */
    public function exists($key)
    {
        return isset($this->all()[(string)$key]);
    }

    /**
     * @param string $key
     * @return bool
     */
    public function isEnabled($key)
    {
        $peer = $this->get($key);

        return $peer['enabled'];
    }

    /**
     * 事件能否发往该对端
     *
     * @param string $key 对端标识
     * @param string $eventType 事件类型
     * @return string 空串表示不允许；否则返回 official|extension
     */
    public function allows($key, $eventType)
    {
        $peer = $this->get($key);

        $eventType = (string)$eventType;

        if (in_array($eventType, $peer['events'], true)) {
            return self::CHANNEL_OFFICIAL;
        }

        if ($peer['extensions'] && $peer['extension_path'] !== '') {
            return self::CHANNEL_EXTENSION;
        }

        return '';
    }

    /**
     * 投递路径（相对网关根地址）
     *
     * @param string $key
     * @param string $channel
     * @return string
     */
    public function path($key, $channel = self::CHANNEL_OFFICIAL)
    {
        $peer = $this->get($key);

        if ($channel === self::CHANNEL_EXTENSION) {
            return (string)$peer['extension_path'];
        }

        return (string)$peer['push_path'];
    }

    /**
     * 该对端实际使用的网关根地址
     *
     * 优先取对端自己的 base_uri，为空时回退全局。五平台统一网关按平台分片时，
     * 论坛平台可能挂在另一台网关上，此时只改对端配置，不动全局。
     *
     * @param string $key
     * @return string
     */
    public function baseUri($key)
    {
        $peer = $this->get($key);

        $base = trim((string)$peer['base_uri']);

        if ($base !== '') return rtrim($base, '/');

        return rtrim((string)$this->getConfig()->path('gateway.base_uri', ''), '/');
    }

    /**
     * 完整投递地址（便于页面展示与排障）
     *
     * @param string $key
     * @param string $channel
     * @return string
     */
    public function endpoint($key, $channel = self::CHANNEL_OFFICIAL)
    {
        $base = $this->baseUri($key);

        $path = $this->path($key, $channel);

        if ($base === '' || $path === '') return '';

        return $base . $path;
    }

    /**
     * 入站事件白名单（实训/论坛回传、考试平台回执）
     *
     * @param string $key
     * @return array
     */
    public function inboundEvents($key)
    {
        $peer = $this->get($key);

        return $peer['inbound'] ? $peer['inbound_events'] : [];
    }

    /**
     * 该对端是否已开通某项对接能力
     *
     * @param string $key
     * @param string $ability ack|pull|replay|query
     * @return bool
     */
    public function hasAbility($key, $ability)
    {
        $peer = $this->get($key);

        if (!$peer['enabled']) return false;

        return (bool)($peer[$ability] ?? false);
    }

    /**
     * 按对端自己的应用编码反查对端标识
     *
     * 入站请求靠 X-App-Code 识别调用方，因此这里只看 inbound_app_code，
     * 不看 outbound 的 app_code（后者是「我们是谁」，三个对端都是 learning）。
     *
     * @param string $appCode
     * @return string 未注册返回空串
     */
    public function findByAppCode($appCode)
    {
        $appCode = trim((string)$appCode);

        if ($appCode === '') return '';

        foreach ($this->all() as $key => $peer) {
            if ($peer['inbound_app_code'] === $appCode) return $key;
        }

        return '';
    }

    /**
     * 该对端实际生效的入站鉴权方式
     *
     * auto 的语义：配了 secret 就强制签名，配了 token 就用令牌，都没有则退化为
     * 只校验应用编码（内网白名单/联调阶段）。上线前必须落到 signature 或 token。
     *
     * @param string $key
     * @return string signature|token|none
     */
    public function authMode($key)
    {
        $peer = $this->get($key);

        if ($peer['auth_mode'] !== 'auto') return $peer['auth_mode'];

        if (trim((string)$peer['secret']) !== '') return 'signature';

        if (trim((string)$peer['token']) !== '') return 'token';

        return 'none';
    }

    /**
     * 该对端的入站签名密钥，未单独发放时回落到全局内部签名密钥
     *
     * @param string $key
     * @return string
     */
    public function secretOf($key)
    {
        $peer = $this->get($key);

        $secret = trim((string)$peer['secret']);

        if ($secret !== '') return $secret;

        return (string)$this->getConfig()->path('gateway.internal_sign_secret', '');
    }

    /**
     * 出站 Bearer 令牌：对端专属优先，回落全局
     *
     * @param string $key
     * @return string
     */
    public function accessTokenOf($key)
    {
        $peer = $this->get($key);

        $token = trim((string)$peer['access_token']);

        if ($token !== '') return $token;

        return (string)$this->getConfig()->path('gateway.access_token', '');
    }

    /**
     * 能力发现：对端对接前用它自检，不用猜路径与事件类型
     *
     * 入站路径一律下发本平台 upstream 的真实路径（/api/v1/learning/...），
     * 不带 internal 段。网关侧用 /api/v1/learning/internal/* 区分 L1/L2，
     * 转发到本平台时由网关或本平台入口剥离该段。下发网关侧路径会让对端
     * 直呼本平台得到 404，这是最容易踩的对接坑。
     *
     * @return array
     */
    public function describe()
    {
        $result = [];

        foreach ($this->all() as $key => $peer) {

            $result[] = [
                'peer' => $key,
                'name' => $peer['name'],
                'enabled' => $peer['enabled'],
                'outbound' => [
                    'appCode' => $peer['app_code'],
                    'baseUri' => $peer['enabled'] ? $this->baseUri($key) : '',
                    'path' => $peer['enabled'] ? $peer['push_path'] : '',
                    'endpoint' => $peer['enabled'] ? $this->endpoint($key) : '',
                    'events' => $peer['enabled'] ? $peer['events'] : [],
                    'extensions' => [
                        'enabled' => $peer['extensions'],
                        'path' => $peer['extensions'] ? $peer['extension_path'] : '',
                    ],
                    'signature' => 'X-Internal-Sign: hmac-sha256(secret, canonical)',
                    'idempotency' => 'Idempotency-Key = eventId',
                    /**
                     * 网关 L2 与内部签名是两套规范：前者给网关入口鉴权、验完即剥离，
                     * 后者由网关重算后注入上游。对端看到的能力描述里必须分开列，
                     * 否则接的人会以为「带一个签名就够了」。
                     */
                    'gateway' => [
                        'enabled' => (new GatewaySign())->isEnabled($key),
                        'appKey' => (new GatewaySign())->appKey($key),
                        'headers' => GatewaySign::HEADERS,
                        'algorithm' => GatewaySign::ALG,
                        'canonical' => (new GatewaySign())->canonicalPattern(),
                        'skew' => (int)$this->getConfig()->path('gateway.timestamp_skew', 300),
                        'nonceTtl' => 600,
                    ],
                ],
                'inbound' => [
                    'enabled' => $peer['inbound'],
                    'path' => $peer['inbound'] ? '/api/v1/learning/peers/' . $key . '/events' : '',
                    'events' => $peer['inbound'] ? $peer['inbound_events'] : [],
                ],
                'receipts' => [
                    'enabled' => $peer['ack'],
                    'path' => $peer['ack'] ? '/api/v1/learning/peers/' . $key . '/receipts' : '',
                    'events' => $peer['ack'] ? ['exam.progress.ack'] : [],
                ],
                'pull' => [
                    'enabled' => $peer['pull'],
                    'path' => $peer['pull'] ? '/api/v1/learning/peers/' . $key . '/pull' : '',
                    'limit' => $peer['pull'] ? (int)$peer['pull_limit'] : 0,
                    'cursor' => 'afterId',
                ],
                'replay' => [
                    'enabled' => $peer['replay'],
                    'path' => $peer['replay'] ? '/api/v1/learning/peers/' . $key . '/replay' : '',
                ],
                'query' => [
                    'enabled' => $peer['query'],
                    'progressPath' => $peer['query'] ? '/api/v1/learning/peers/' . $key . '/students/{userId}/progress' : '',
                    'completionPath' => $peer['query'] ? '/api/v1/learning/peers/' . $key . '/students/{userId}/completion/{courseId}' : '',
                ],
                'auth' => [
                    'appCode' => $peer['inbound_app_code'],
                    'mode' => $this->authMode($key),
                    'headers' => ['X-App-Code', 'X-Request-Id', 'X-Timestamp', 'X-Internal-Sign'],
                    'signature' => 'hex(hmac-sha256(secret, appCode + "\\n" + requestId + "\\n" + timestamp + "\\n" + sha256(rawBody)))',
                ],
                'handshake' => [
                    'path' => '/api/v1/learning/peers/' . $key . '/handshake',
                    'auth' => 'none',
                ],
            ];
        }

        return $result;
    }

    /**
     * @param string $key
     * @param array $item
     * @return array
     */
    protected function normalize($key, $item)
    {
        $item = array_merge(self::DEFAULTS, $this->toArray($item));

        $item['peer'] = $key;

        $item['enabled'] = (bool)$item['enabled'];

        $item['base_uri'] = trim((string)$item['base_uri']);

        $item['app_key'] = trim((string)$item['app_key']);

        $item['app_secret'] = trim((string)$item['app_secret']);

        $item['extensions'] = (bool)$item['extensions'];

        $item['inbound'] = (bool)$item['inbound'];

        $item['ack'] = (bool)$item['ack'];

        $item['pull'] = (bool)$item['pull'];

        $item['replay'] = (bool)$item['replay'];

        $item['query'] = (bool)$item['query'];

        $item['pull_limit'] = (int)$item['pull_limit'];

        if ($item['inbound_app_code'] === '') $item['inbound_app_code'] = $key;

        $mode = strtolower(trim((string)$item['auth_mode']));

        if (!in_array($mode, ['auto', 'signature', 'token', 'none'], true)) $mode = 'auto';

        $item['auth_mode'] = $mode;

        $item['headers'] = $this->normalizeHeaders($item['headers']);

        if ($item['pull_limit'] <= 0) $item['pull_limit'] = 200;

        if ($item['pull_limit'] > 500) $item['pull_limit'] = 500;

        $item['events'] = array_values(array_filter(array_map('strval', (array)$item['events'])));

        $item['inbound_events'] = array_values(array_filter(array_map('strval', (array)$item['inbound_events'])));

        if ($item['name'] === '') $item['name'] = $key;

        if ($item['app_code'] === '') $item['app_code'] = 'learning';

        return $item;
    }

    /**
     * 兼容旧配置：只有 exam.* 时按考试平台单对端运行
     *
     * @return array
     */
    protected function legacy()
    {
        return [
            'exam' => [
                'enabled' => (bool)$this->getConfig()->path('exam.enabled', true),
                'name' => '考试平台',
                'app_code' => (string)$this->getConfig()->path('gateway.app_code', 'learning'),
                'push_path' => (string)$this->getConfig()->path('exam.push_path', '/api/v1/exam/learning/progress'),
                'events' => self::CATALOG,
            ],
        ];
    }

    /**
     * @param mixed $value
     * @return array
     */
    protected function toArray($value)
    {
        if ($value instanceof \Phalcon\Config) return $value->toArray();

        return is_array($value) ? $value : [];
    }

    /**
     * 附加请求头统一成 string => string，避免配置写成数字或嵌套数组时出错
     *
     * @param mixed $headers
     * @return array
     */
    protected function normalizeHeaders($headers)
    {
        $result = [];

        foreach ($this->toArray($headers) as $name => $value) {

            $name = trim((string)$name);

            if ($name === '') continue;

            /**
             * 头名只允许字母数字与连字符：配置写错时宁可丢掉这个头，
             * 也不能把换行带进请求头造成头注入。
             */
            if (!preg_match('/^[A-Za-z0-9-]+$/', $name)) continue;

            if (!is_scalar($value)) continue;

            $result[$name] = (string)$value;
        }

        return $result;
    }

}

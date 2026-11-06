<?php
/**
 * 统一网关出口
 *
 * 本平台所有跨平台写操作都必须经统一网关，不得直连考试平台。
 * 网关承担 HTTPS 入口、鉴权、限流、日志与身份上下文注入；本平台只负责
 * 按契约组装报文并带上内部签名（X-Internal-Sign），供网关与下游校验。
 *
 * 签名规范见《自学平台统一身份与网关接入说明》5.3：
 *   canonical = X-User-Id \n X-User-Role \n X-Client-Id \n X-Token-Exp
 *             \n X-Request-Id \n X-Auth-Mode \n X-Timestamp
 *   X-Internal-Sign = hex( HMAC-SHA256( internalSignSecret, canonical ) )
 */

namespace App\Services\Learning;

use App\Services\Service;

class Gateway extends Service
{

    /**
     * 网关入口根地址，留空表示未接入（本地直连模式）
     *
     * @param string $peer 对端标识；传空取全局配置
     * @return string
     */
    public function getBaseUri($peer = '')
    {
        if ($peer !== '') {
            return (new Peers())->baseUri($peer);
        }

        return rtrim((string)$this->getConfig()->path('gateway.base_uri', ''), '/');
    }

    /**
     * 投递模式
     *
     * 按对端判断：统一网关若按平台分片，不同对端可能一个已接入、一个还在本地模式。
     *
     * @param string $peer
     * @return string gateway|local
     */
    public function getMode($peer = '')
    {
        return $this->getBaseUri($peer) === '' ? 'local' : 'gateway';
    }

    /**
     * 是否已配置网关
     *
     * @param string $peer
     * @return bool
     */
    public function isConfigured($peer = '')
    {
        return $this->getMode($peer) === 'gateway';
    }

    /**
     * 完整投递地址（便于页面展示）
     *
     * @param string $peer
     * @return string
     */
    public function getEndpoint($peer = 'exam')
    {
        return (new Peers())->endpoint($peer);
    }

    /**
     * 取对端对应的 X-App-Code
     *
     * @param string $peer
     * @return string
     */
    public function getAppCode($peer = '')
    {
        $fallback = (string)$this->getConfig()->path('gateway.app_code', 'learning');

        if ($peer === '') return $fallback;

        $config = (new Peers())->get($peer);

        return $config['app_code'] !== '' ? $config['app_code'] : $fallback;
    }

    /**
     * 按对端投递一条事件
     *
     * 路径、App-Code 全部来自对端注册表，新增实训/论坛平台时无需改这里。
     *
     * @param string $peer 对端标识（exam|training|forum）
     * @param string $eventType 事件类型（决定走正式通道还是扩展通道）
     * @param array $payload 事件封套
     * @param string $idempotencyKey 幂等键
     * @param string $requestId 请求编号
     * @param string $actorKey 操作者对外主键
     * @param string $error 出参：失败原因
     * @param int $code 出参：HTTP 状态码（0 为网络层失败）
     * @return bool
     */
    public function sendEvent($peer, $eventType, array $payload, $idempotencyKey, $requestId, $actorKey, &$error, &$code)
    {
        $error = '';
        $code = 0;

        $registry = new Peers();

        $channel = $registry->allows($peer, $eventType);

        if ($channel === '') {

            /**
             * 通道纪律：不在对端白名单内的事件一律不发，
             * 避免下游收到未定义类型后按「未知主版本」隔离告警。
             */
            $error = sprintf('event_not_allowed:%s->%s', $eventType, $peer);

            return false;
        }

        $path = $registry->path($peer, $channel);

        if ($path === '') {
            $error = sprintf('peer_path_missing:%s', $peer);

            return false;
        }

        return $this->send($path, $payload, $idempotencyKey, $requestId, $actorKey, $error, $code, $peer);
    }

    /**
     * 经网关投递一条事件
     *
     * @param string $path 网关路径（含 /api 前缀）
     * @param array $payload 事件封套
     * @param string $idempotencyKey 幂等键（同一事件重放保持同一值）
     * @param string $requestId 单次请求 ID（沿用入箱时的值，便于全链路反查）
     * @param string $actorKey 操作者对外主键
     * @param string $error 出参：失败原因
     * @param int $code 出参：HTTP 状态码（0 表示网络层失败）
     * @param string $peer 对端标识，用于取 App-Code 与专属网关地址；留空取全局配置
     * @return bool
     */
    public function send($path, array $payload, $idempotencyKey, $requestId, $actorKey, &$error, &$code, $peer = '')
    {
        $error = '';
        $code = 0;

        $base = $this->getBaseUri($peer);

        if ($base === '') {

            /**
             * 本地直连模式：未接入网关时不外发，仅标记为已投递，
             * 保证复现环境链路完整、界面状态可信。
             */
            return true;
        }

        $timeout = (int)$this->getConfig()->path('gateway.timeout', 5);

        /**
         * 网关 L2 服务签名
         *
         * 统一网关对机器调用走 L2 档，要求 X-App-Key / X-Timestamp / X-Nonce /
         * X-Sign-Alg / X-Signature 五头，与下面的 X-Internal-Sign 是两套规范。
         * 少了这组头，请求会在网关入口被判 40105，根本到不了对端。
         *
         * 配了 app_key 却没配 app_secret 时直接失败，不发这个必然被拒的请求：
         * 否则每条事件都要等一次 401 往返才进死信，排障时还会误以为是签名算法写错。
         */
        $signer = new GatewaySign();

        if (!$signer->isEnabled($peer) && $signer->appKey($peer) !== '') {

            $error = sprintf('gateway_app_secret_missing:%s', $peer !== '' ? $peer : 'default');

            return false;
        }

        if ($signer->isEnabled($peer)
            && trim((string)$this->getConfig()->path('gateway.internal_sign_secret', '')) === '') {

            /**
             * 经网关出站时，内部签名密钥同时是「网关重算给上游」的基准。
             * 本地没配就等于用空串当密钥，签名永远对不上，属于启动期配置缺失。
             */
            $error = 'internal_sign_secret_missing';

            return false;
        }

        $timestamp = (string)time();

        $headers = $this->buildSignHeaders([
            'X-User-Id' => $actorKey,
            'X-User-Role' => '',
            'X-Client-Id' => 'learning-service',
            'X-Token-Exp' => '',
            'X-Request-Id' => $requestId,
            'X-Auth-Mode' => 'service',
            'X-Timestamp' => $timestamp,
        ]);

        $httpHeaders = [
            'Content-Type: application/json',
            'Accept: application/json',
            'X-App-Code: ' . $this->getAppCode($peer),
            'Idempotency-Key: ' . $idempotencyKey,
        ];

        /**
         * 网关若开启了统一鉴权（APISIX 的 jwt-auth / key-auth 会要求 Bearer），
         * 服务态调用需要带上约定令牌。令牌按对端取：五平台各自网关的鉴权
         * 相互独立，考试平台的 token 不能拿去调论坛平台的网关。
         */
        $registry = new Peers();

        $token = $peer !== ''
            ? $registry->accessTokenOf($peer)
            : (string)$this->getConfig()->path('gateway.access_token', '');

        if ($token !== '') {
            $httpHeaders[] = 'Authorization: Bearer ' . $token;
        }

        /**
         * 对端附加头：适配 APISIX 的 key-auth（X-API-Key）等插件。
         * 头名在注册表里已做合法性校验，避免配置写错导致请求头注入。
         */
        if ($peer !== '') {

            foreach ($registry->get($peer)['headers'] as $name => $value) {
                $httpHeaders[] = sprintf('%s: %s', $name, $value);
            }
        }

        /**
         * L2 签名按「实际请求的方法 / 路径 / 请求体」计算，不能用配置里的
         * push_path 近似——投递路径里若带 query，签名段必须与真实一致。
         */
        $body = kg_json_encode($payload);

        $l2Headers = $signer->headers('POST', $path, $body, $peer, $timestamp);

        foreach ($l2Headers as $name => $value) {
            $httpHeaders[] = sprintf('%s: %s', $name, $value);
        }

        foreach ($headers as $name => $value) {

            /**
             * L2 五头与内部签名七字段都含 X-Timestamp。两个同名头都发时，
             * 网关（OpenResty）读到的是重复头（Lua table）而非字符串，
             * 实测会被判 40106「时间戳格式非法」。经网关时由 L2 头携带
             * 同一个时间戳（上方 headers() 传入的就是内部签名用的
             * $timestamp，值必然一致）；本地直连（L2 未启用、无五头）
             * 时才由内部签名头自己携带。
             */
            if ($name === 'X-Timestamp' && isset($l2Headers['X-Timestamp'])) continue;

            $httpHeaders[] = sprintf('%s: %s', $name, $value);
        }

        $ch = curl_init($base . $path);

        curl_setopt_array($ch, [
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => $body,
            CURLOPT_HTTPHEADER => $httpHeaders,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_CONNECTTIMEOUT => 2,
            CURLOPT_TIMEOUT => $timeout > 0 ? $timeout : 5,
        ]);

        $response = curl_exec($ch);

        $code = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);

        if ($response === false) {
            $error = curl_error($ch);
        }

        curl_close($ch);

        if ($code >= 200 && $code < 300) {

            /**
             * 防假成功：状态码 2xx 不等于「对端真的收下了」。
             *
             * APISIX 这类网关常配一条 catch-all 路由兜底，未配置的路径会回
             * 默认页——状态码 200、内容是 HTML。只看状态码就会把它判成功，
             * 事件被标记「已推送」且不再重试，数据静默丢失，监控也看不出来。
             * 这里按可重试处理（不改 response_code，保留原始 200 便于排障），
             * 错误信息明确指向网关配置而不是业务契约。
             */
            if (!$this->isAcceptableResponse($response)) {

                $plain = preg_replace('/\s+/', ' ', strip_tags((string)$response));

                $error = 'gateway_returned_non_json:' . kg_substr(trim((string)$plain), 0, 120);

                return false;
            }

            return true;
        }

        if ($error === '') {

            /**
             * 网关自身生成的拒绝（L2 签名、nonce、时间戳、AppKey）都是数字码，
             * 原样记录会让运维只看到「HTTP 401」而不知道是签名算法不一致还是
             * 时钟没同步。这里把数字码翻成可读原因并保留原始响应，两边都能查。
             */
            $gwCode = $signer->errorCodeOf($code, (string)$response);

            $reason = $gwCode > 0 ? $signer->errorText($gwCode) : '';

            $error = $reason !== ''
                ? sprintf('gateway_%d:%s', $gwCode, $reason)
                : sprintf('HTTP %d %s', $code, kg_substr((string)$response, 0, 300));
        }

        return false;
    }

    /**
     * 响应体是否可信
     *
     * 空响应（204 / 只回状态码）视为成功；约定为 JSON 的通道要求以 { 或 [ 开头。
     * HTML 兜底页、网关错误页都会被判为不可信。
     *
     * @param string $body
     * @return bool
     */
    protected function isAcceptableResponse($body)
    {
        $body = ltrim((string)$body);

        if ($body === '') return true;

        if (!$this->getConfig()->path('gateway.expect_json', true)) return true;

        $first = substr($body, 0, 1);

        return $first === '{' || $first === '[';
    }

    /**
     * 生成带内部签名的一组头
     *
     * @param array $fields
     * @return array
     */
    public function buildSignHeaders(array $fields)
    {
        $fields['X-Internal-Sign'] = $this->sign($fields);

        return $fields;
    }

    /**
     * 计算内部签名
     *
     * @param array $fields
     * @return string
     */
    public function sign(array $fields)
    {
        $order = [
            'X-User-Id',
            'X-User-Role',
            'X-Client-Id',
            'X-Token-Exp',
            'X-Request-Id',
            'X-Auth-Mode',
            'X-Timestamp',
        ];

        $parts = [];

        foreach ($order as $name) {
            $parts[] = isset($fields[$name]) ? (string)$fields[$name] : '';
        }

        $canonical = implode("\n", $parts);

        $secret = (string)$this->getConfig()->path('gateway.internal_sign_secret', '');

        return hash_hmac('sha256', $canonical, $secret);
    }

    /**
     * 生成 UUID v4（请求编号）
     *
     * @return string
     */
    public function makeRequestId()
    {
        $bytes = random_bytes(16);

        $bytes[6] = chr((ord($bytes[6]) & 0x0f) | 0x40);
        $bytes[8] = chr((ord($bytes[8]) & 0x3f) | 0x80);

        return vsprintf('%s%s-%s-%s-%s-%s%s%s', str_split(bin2hex($bytes), 4));
    }

}

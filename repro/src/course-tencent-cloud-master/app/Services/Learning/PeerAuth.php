<?php
/**
 * 对端服务态鉴权
 *
 * 考试平台、实训平台、论坛平台调本平台时，手里没有用户身份，只有自己的应用
 * 凭据。因此不能走用户的 X-User-Id 可信头链路，需要独立的服务态身份：
 *
 *   X-App-Code: exam            对端自己的应用编码（不是 learning）
 *   X-Request-Id: 每次请求唯一  参与签名，同时用于全链路反查
 *   X-Timestamp: 秒级时间戳     参与签名，限制重放窗口
 *   X-Internal-Sign: 签名        hex(hmac-sha256(secret, canonical))
 *
 * canonical = appCode + "\n" + requestId + "\n" + timestamp + "\n" + sha256(rawBody)
 *
 * 三种模式（peers.<对端>.auth_mode，默认 auto）：
 *   signature —— 校验 HMAC，安全等级最高，上线要求
 *   token     —— 比对固定 Bearer 令牌，网关已做鉴权时可用
 *   none      —— 只校验应用编码，联调阶段用；生产环境不应停留在这一档
 *
 * auto 的语义是「配了 secret 就必须签名」，因此发放密钥即完成升级，不需要改代码。
 */

namespace App\Services\Learning;

use App\Services\Service;

class PeerAuth extends Service
{

    const MODE_SIGNATURE = 'signature';

    const MODE_TOKEN = 'token';

    const MODE_NONE = 'none';

    /**
     * @return array {
     *     ok: bool, error: string, peer: string, appCode: string, mode: string,
     *     authMode: string, requestId: string, verified: bool, clientId: string
     * }
     */
    public function authenticate()
    {
        $request = $this->request;

        $appCode = trim((string)$request->getHeader('X-App-Code'));

        $headerRequestId = trim((string)$request->getHeader('X-Request-Id'));

        $requestId = $headerRequestId !== '' ? $headerRequestId : (new Gateway())->makeRequestId();

        $registry = new Peers();

        $peerKey = $registry->findByAppCode($appCode);

        $result = [
            'ok' => false,
            'error' => '',
            'peer' => $peerKey,
            'appCode' => $appCode,
            'mode' => 'peer',
            'authMode' => self::MODE_NONE,
            'requestId' => $requestId,
            'verified' => false,
            'clientId' => $peerKey,
        ];

        if ($appCode === '') {
            $result['error'] = 'missing_app_code';

            return $result;
        }

        if ($peerKey === '') {
            $result['error'] = 'unknown_app_code';

            return $result;
        }

        $peer = $registry->get($peerKey);

        if (!$peer['enabled']) {
            $result['error'] = 'peer_disabled';

            return $result;
        }

        $mode = $registry->authMode($peerKey);

        $result['authMode'] = $mode;

        if ($mode === self::MODE_NONE) {

            /**
             * 联调档：只认应用编码。身份可信度低，因此调用方只能访问自己
             * 那条通道（由控制器 assertPeer 兜底），拿不到其他平台的数据。
             */
            $result['ok'] = true;

            return $result;
        }

        if ($mode === self::MODE_TOKEN) {
            return $this->checkToken($result, (string)$peer['token']);
        }

        return $this->checkSignature($result, $registry, $peerKey, $appCode, $headerRequestId, $requestId);
    }

    /**
     * 生成签名，供对端自检脚本与文档示例复用
     *
     * @param string $secret
     * @param string $appCode
     * @param string $requestId
     * @param string $timestamp
     * @param string $body 原始请求体，GET 传空串
     * @return string
     */
    public function sign($secret, $appCode, $requestId, $timestamp, $body = '')
    {
        $canonical = implode("\n", [
            (string)$appCode,
            (string)$requestId,
            (string)$timestamp,
            hash('sha256', (string)$body),
        ]);

        return hash_hmac('sha256', $canonical, (string)$secret);
    }

    /**
     * 本文档声明的 canonical 形式，能力发现接口直接回给对端
     *
     * @return string
     */
    public function canonicalPattern()
    {
        return 'appCode + "\n" + requestId + "\n" + timestamp + "\n" + sha256(rawBody)';
    }

    /**
     * 允许的时间戳偏移（秒），握手接口回给对端做时钟校准
     *
     * @return int
     */
    public function skewSeconds()
    {
        return (int)$this->getConfig()->path('gateway.timestamp_skew', 300);
    }

    /**
     * @param array $result
     * @param string $expect
     * @return array
     */
    protected function checkToken(array $result, $expect)
    {
        $given = $this->bearerToken();

        if ($expect === '') {
            $result['error'] = 'token_not_configured';

            return $result;
        }

        if ($given === '' || !hash_equals($expect, $given)) {
            $result['error'] = 'bad_token';

            return $result;
        }

        $result['ok'] = true;

        $result['verified'] = true;

        return $result;
    }

    /**
     * @param array $result
     * @param Peers $registry
     * @param string $peerKey
     * @param string $appCode
     * @param string $headerRequestId
     * @param string $requestId
     * @return array
     */
    protected function checkSignature(array $result, Peers $registry, $peerKey, $appCode, $headerRequestId, $requestId)
    {
        if ($headerRequestId === '') {
            $result['error'] = 'missing_request_id';

            return $result;
        }

        $skew = (int)$this->getConfig()->path('gateway.timestamp_skew', 300);

        $timestamp = trim((string)$this->request->getHeader('X-Timestamp'));

        if ($timestamp === '' || !ctype_digit($timestamp)) {
            $result['error'] = 'missing_timestamp';

            return $result;
        }

        if (abs(time() - (int)$timestamp) > $skew) {
            $result['error'] = 'timestamp_expired';

            return $result;
        }

        $sign = strtolower(trim((string)$this->request->getHeader('X-Internal-Sign')));

        if ($sign === '') {
            $result['error'] = 'missing_signature';

            return $result;
        }

        $secret = $registry->secretOf($peerKey);

        if ($secret === '') {
            $result['error'] = 'secret_not_configured';

            return $result;
        }

        $expect = $this->sign($secret, $appCode, $requestId, $timestamp, (string)$this->request->getRawBody());

        if (!hash_equals($expect, $sign)) {
            $result['error'] = 'bad_signature';

            return $result;
        }

        $result['ok'] = true;

        $result['verified'] = true;

        return $result;
    }

    /**
     * 取调用方令牌：Authorization: Bearer xxx 或 X-Api-Key
     *
     * @return string
     */
    protected function bearerToken()
    {
        $header = trim((string)$this->request->getHeader('Authorization'));

        if ($header !== '' && stripos($header, 'Bearer ') === 0) {
            return trim(substr($header, 7));
        }

        return trim((string)$this->request->getHeader('X-Api-Key'));
    }

}

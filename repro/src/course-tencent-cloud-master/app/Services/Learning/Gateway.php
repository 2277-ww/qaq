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
     * @return string
     */
    public function getBaseUri()
    {
        return rtrim((string)$this->getConfig()->path('gateway.base_uri', ''), '/');
    }

    /**
     * 投递模式
     *
     * @return string gateway|local
     */
    public function getMode()
    {
        return $this->getBaseUri() === '' ? 'local' : 'gateway';
    }

    /**
     * 是否已配置网关
     *
     * @return bool
     */
    public function isConfigured()
    {
        return $this->getMode() === 'gateway';
    }

    /**
     * 完整投递地址（便于页面展示）
     *
     * @return string
     */
    public function getEndpoint()
    {
        $base = $this->getBaseUri();

        if ($base === '') return '';

        return $base . (string)$this->getConfig()->path('exam.push_path', '/api/v1/exam/learning/progress');
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
     * @return bool
     */
    public function send($path, array $payload, $idempotencyKey, $requestId, $actorKey, &$error, &$code)
    {
        $error = '';
        $code = 0;

        $base = $this->getBaseUri();

        if ($base === '') {

            /**
             * 本地直连模式：未接入网关时不外发，仅标记为已投递，
             * 保证复现环境链路完整、界面状态可信。
             */
            return true;
        }

        $timeout = (int)$this->getConfig()->path('gateway.timeout', 5);

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
            'X-App-Code: ' . (string)$this->getConfig()->path('gateway.app_code', 'learning'),
            'Idempotency-Key: ' . $idempotencyKey,
        ];

        foreach ($headers as $name => $value) {
            $httpHeaders[] = sprintf('%s: %s', $name, $value);
        }

        $ch = curl_init($base . $path);

        curl_setopt_array($ch, [
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => kg_json_encode($payload),
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
            return true;
        }

        if ($error === '') {
            $error = sprintf('HTTP %d %s', $code, kg_substr((string)$response, 0, 300));
        }

        return false;
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

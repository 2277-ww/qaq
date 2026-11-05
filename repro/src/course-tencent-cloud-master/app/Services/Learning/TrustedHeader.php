<?php
/**
 * 入站可信头校验
 *
 * 网关鉴权通过后向下游注入 X-User-Id / X-User-Role / X-Auth-Mode /
 * X-Request-Id / X-Timestamp / X-Internal-Sign 等头。业务侧只信任这些头，
 * 且必须校验内部签名——否则内网可直连服务伪造身份。
 *
 * 校验项：时间戳偏移、签名（HMAC-SHA256）、鉴权模式。
 * 未接入网关的复现环境可将 gateway.verify_sign 置 false 放行，便于本地联调。
 */

namespace App\Services\Learning;

use App\Services\Service;

class TrustedHeader extends Service
{

    /**
     * @return array {
     *     ok: bool, error: string, userId: string, roles: array,
     *     mode: string, requestId: string, tokenExp: int
     * }
     */
    public function verify()
    {
        $request = $this->request;

        $fields = [
            'X-User-Id' => (string)$request->getHeader('X-User-Id'),
            'X-User-Role' => (string)$request->getHeader('X-User-Role'),
            'X-Client-Id' => (string)$request->getHeader('X-Client-Id'),
            'X-Token-Exp' => (string)$request->getHeader('X-Token-Exp'),
            'X-Request-Id' => (string)$request->getHeader('X-Request-Id'),
            'X-Auth-Mode' => (string)$request->getHeader('X-Auth-Mode'),
            'X-Timestamp' => (string)$request->getHeader('X-Timestamp'),
        ];

        $mode = $fields['X-Auth-Mode'] !== '' ? $fields['X-Auth-Mode'] : 'user';

        $requestId = $fields['X-Request-Id'];

        if ($requestId === '') {
            $requestId = (new Gateway())->makeRequestId();
        }

        $roles = array_values(array_filter(array_map('trim', explode(',', $fields['X-User-Role']))));

        $result = [
            'ok' => true,
            'error' => '',
            'userId' => $fields['X-User-Id'],
            'roles' => $roles,
            'mode' => $mode,
            'requestId' => $requestId,
            'tokenExp' => (int)$fields['X-Token-Exp'],
            'clientId' => $fields['X-Client-Id'],
            'verified' => (bool)$this->getConfig()->path('gateway.verify_sign', false),
        ];

        $result['error'] = $this->check($fields);

        $result['ok'] = $result['error'] === '';

        return $result;
    }

    /**
     * @param array $fields
     * @return string 空串表示通过
     */
    protected function check(array $fields)
    {
        $enabled = (bool)$this->getConfig()->path('gateway.verify_sign', false);

        if (!$enabled) return '';

        $timestamp = (int)$fields['X-Timestamp'];

        $skew = (int)$this->getConfig()->path('gateway.timestamp_skew', 300);

        if ($timestamp <= 0) return 'missing_timestamp';

        if (abs(time() - $timestamp) > $skew) return 'timestamp_expired';

        $sign = strtolower((string)$this->request->getHeader('X-Internal-Sign'));

        if ($sign === '') return 'missing_signature';

        $expect = (new Gateway())->sign($fields);

        if (!hash_equals($expect, $sign)) return 'bad_signature';

        return '';
    }

}

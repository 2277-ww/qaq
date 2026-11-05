<?php
/**
 * 论坛账号确认客户端
 *
 * 走统一网关的 L2 服务态调用：
 *
 *   本平台 ——(L2 五头)——> 网关 8.138.246.181 ——(内部签名 + 回环)——> 论坛 9088
 *
 * 接口只做只读账号确认：返回「账号密码是否匹配 + 最小身份信息」，
 * 不签发论坛 token，也不返回密码摘要。本平台据此建立**自己的会话**。
 *
 * ── 三个必须守住的边界 ────────────────────────────────────────────────
 *
 * 1) 密码只进请求体，不进任何日志、不进异常信息、不进缓存键。
 *    论坛侧审计也只记 login 不记 pass，本平台若在这里把密码打出来，
 *    等于在整条链路上开了一个明文旁路。
 *
 * 2) 失败原因对用户不可区分。「账号不存在」与「密码错误」论坛返回同一
 *    结论（invalid_credentials），本平台不应再细分——否则两个平台各自
 *    泄露一点信息，拼起来就是账号枚举工具。
 *
 * 3) 与投递链路复用同一套 L2 签名（GatewaySign），但**不复用 gateway.base_uri**。
 *    投递侧的 base_uri 为空表示「本地直连、不外发」，账号确认必须真实走网关，
 *    借用同一个空值会让两种情况无法区分。
 */

namespace App\Services\Gateway;

use App\Services\Learning\GatewaySign;
use App\Services\Service;

class AccountVerify extends Service
{

    /**
     * 网关错误码 → 本平台可读原因
     *
     * 40104 之外的码都属于「接入配置或链路问题」，与用户输入无关，
     * 对用户统一提示稍后重试，具体原因留在日志里给运维看。
     */
    const ERRORS = [
        40001 => 'invalid_params',
        41300 => 'body_too_large',
        40104 => 'invalid_credentials',
        40105 => 'bad_signature',
        40106 => 'timestamp_expired',
        40107 => 'nonce_replayed',
        40108 => 'unknown_app_key',
        40300 => 'route_not_registered',
        40303 => 'direct_access_denied',
        42901 => 'rate_limited',
        50000 => 'upstream_error',
        50200 => 'upstream_unavailable',
        50400 => 'upstream_timeout',
    ];

    /**
     * 参数约束（与论坛侧一致，本地先拦一次可少打一次网关）
     */
    const LOGIN_MAX = 100;
    const PASS_MIN = 8;
    const PASS_MAX = 32;
    const BODY_MAX = 65536;

    /**
     * 是否具备调用条件
     *
     * 缺 app_secret 时直接判定不可用，不发这个必然被 40105 的请求——
     * 否则每次登录都要等一次往返才失败，排障时还会误以为签名算错了。
     *
     * @return bool
     */
    public function isEnabled()
    {
        $base = $this->baseUri();

        if ($base === '') return false;

        return (new GatewaySign())->isEnabled();
    }

    /**
     * 确认论坛账号
     *
     * @param string $login 用户名或邮箱
     * @param string $password 明文密码，仅在本次请求内使用
     * @param string $loginType auto / username / email
     * @param string $clientId 调用方业务标识，仅审计用
     * @return array {
     *     ok: bool,             是否确认通过
     *     status: int,          HTTP 状态码，0 表示网络层失败
     *     reason: string,       失败原因（见 ERRORS）
     *     error: string,        排障信息，可写日志，不含密码
     *     user: array,          确认通过时的最小身份信息
     *     requestId: string     全链路追踪号
     * }
     */
    public function verify($login, $password, $loginType = 'auto', $clientId = '')
    {
        $result = [
            'ok' => false,
            'status' => 0,
            'reason' => '',
            'error' => '',
            'user' => [],
            'requestId' => '',
        ];

        $login = trim((string)$login);

        $password = (string)$password;

        $loginType = $loginType === 'username' || $loginType === 'email' ? $loginType : 'auto';

        if ($login === '' || kg_strlen($login) > self::LOGIN_MAX) {

            $result['reason'] = 'invalid_params';

            return $result;
        }

        $passLen = strlen($password);

        if ($passLen < self::PASS_MIN || $passLen > self::PASS_MAX) {

            $result['reason'] = 'invalid_params';

            $result['error'] = sprintf('pass_length=%d', $passLen);

            return $result;
        }

        if (!$this->isEnabled()) {

            $result['reason'] = 'not_configured';

            $result['error'] = $this->baseUri() === ''
                ? 'account_base_missing'
                : 'app_secret_missing';

            return $result;
        }

        $body = json_encode([
            'login' => $login,
            'pass' => $password,
            'login_type' => $loginType,
            'client_id' => $clientId !== '' ? $clientId : (string)$this->getConfig()->path('gateway.app_key', ''),
        ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);

        if ($body === false) {

            $result['reason'] = 'invalid_params';

            return $result;
        }

        if (strlen($body) > self::BODY_MAX) {

            $result['reason'] = 'body_too_large';

            return $result;
        }

        $path = $this->path();

        return $this->dispatch($path, $body, $result);
    }

    /**
     * 发出请求并解析响应
     *
     * @param string $path
     * @param string $body
     * @param array $result
     * @return array
     */
    protected function dispatch($path, $body, array $result)
    {
        $signer = new GatewaySign();

        $headers = [];

        foreach ($signer->headers('POST', $path, $body) as $name => $value) {
            $headers[] = sprintf('%s: %s', $name, $value);
        }

        $headers[] = 'Content-Type: application/json';

        $headers[] = 'Accept: application/json';

        $respHeaders = [];

        $timeout = (int)$this->getConfig()->path('gateway.account_timeout', 5);

        $ch = curl_init($this->baseUri() . $path);

        curl_setopt_array($ch, [
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => $body,
            CURLOPT_HTTPHEADER => $headers,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_CONNECTTIMEOUT => 2,
            CURLOPT_TIMEOUT => $timeout > 0 ? $timeout : 5,
            CURLOPT_HEADERFUNCTION => function ($ch, $line) use (&$respHeaders) {
                $pos = strpos($line, ':');
                if ($pos !== false) {
                    $name = strtolower(trim(substr($line, 0, $pos)));
                    $respHeaders[$name] = trim(substr($line, $pos + 1));
                }
                return strlen($line);
            },
        ]);

        $response = curl_exec($ch);

        $errno = curl_errno($ch);

        $result['status'] = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);

        $result['requestId'] = (string)($respHeaders['x-request-id'] ?? '');

        curl_close($ch);

        if ($response === false || $errno !== 0) {

            /**
             * 超时与连接失败要分开记：超时通常是对端慢，连接失败多半是地址或
             * 网络策略问题，两者排查方向完全不同。
             */
            $result['reason'] = $errno === CURLE_OPERATION_TIMEDOUT ? 'gateway_timeout' : 'gateway_unreachable';

            $result['error'] = sprintf('curl_errno=%d', $errno);

            return $result;
        }

        $decoded = json_decode((string)$response, true);

        if (!is_array($decoded)) {

            /**
             * 网关有兜底路由，未登记的路径会回 200 + HTML 默认页。
             * 不校验响应体就会把「路由没配」当成「账号已确认」。
             */
            $result['reason'] = 'gateway_returned_non_json';

            $result['error'] = kg_substr(preg_replace('/\s+/', ' ', (string)$response), 0, 160);

            return $result;
        }

        $code = isset($decoded['code']) && is_numeric($decoded['code']) ? (int)$decoded['code'] : $result['status'];

        $data = isset($decoded['data']) && is_array($decoded['data']) ? $decoded['data'] : [];

        if (!empty($data['request_id'])) {
            $result['requestId'] = (string)$data['request_id'];
        }

        if ($result['status'] === 200 && !empty($data['confirmed'])) {

            $result['ok'] = true;

            $result['user'] = [
                'forumUid' => (string)($data['user_id'] ?? ''),
                'username' => (string)($data['username'] ?? ''),
                'displayName' => (string)($data['display_name'] ?? ''),
                'role' => (string)($data['role'] ?? ''),
                'emailMasked' => (string)($data['e_mail_masked'] ?? ''),
                'accountSource' => (string)($data['account_source'] ?? ''),
                'status' => (string)($data['status'] ?? ''),
            ];

            return $result;
        }

        $reason = isset($data['reason']) && is_string($data['reason']) && $data['reason'] !== ''
            ? $data['reason']
            : (self::ERRORS[$code] ?? '');

        $result['reason'] = $reason !== '' ? $reason : 'unknown_error';

        $result['error'] = sprintf('code=%d message=%s', $code, kg_substr((string)($decoded['message'] ?? ''), 0, 120));

        return $result;
    }

    /**
     * 网关地址
     *
     * @return string
     */
    protected function baseUri()
    {
        return rtrim(trim((string)$this->getConfig()->path('gateway.account_base', '')), '/');
    }

    /**
     * 接口路径
     *
     * @return string
     */
    protected function path()
    {
        $path = trim((string)$this->getConfig()->path('gateway.account_path', ''));

        return $path !== '' ? $path : '/answer/api/v1/account/verify';
    }

}

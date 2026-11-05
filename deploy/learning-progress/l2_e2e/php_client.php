<?php
/**
 * L2 出站链路端到端验证
 *
 * 用真实的 GatewaySign::headers() 生成签名头，用真实的 curl 发出 HTTP 请求，
 * 打到一个按文档规范独立实现验签的本地网关。
 *
 * 这一步验证的不是「签名函数算得对不对」（那已用基准对拍过），
 * 而是「实际发出去的请求能否被验签方接受」——包括 curl 是否真的带上了头、
 * body 是否与签名时逐字节一致、path 是否与签名时相同。
 */

namespace App\Services {

    class FakeConfig
    {
        private $data;

        public function __construct(array $data)
        {
            $this->data = $data;
        }

        public function path($key, $default = null)
        {
            return array_key_exists($key, $this->data) ? $this->data[$key] : $default;
        }
    }

    class Service
    {
        public static $config;

        public function getConfig()
        {
            return self::$config;
        }
    }
}

namespace {

    /**
     * 项目源码根目录：默认按本脚本位置推导（deploy/learning-progress/l2_e2e
     * 上三级即仓库根），服务器上可用 LEARNING_ROOT 覆盖。
     */
    $root = getenv('LEARNING_ROOT');

    if (!$root) {
        $root = dirname(__DIR__, 3) . '/repro/src/course-tencent-cloud-master';
    }

    $root = rtrim(str_replace('\\', '/', $root), '/');

    require $root . '/app/Services/Learning/GatewaySign.php';

    const BASE = 'http://127.0.0.1:19090';
    const SECRET = 'local-test-secret-0123456789';
    const APP_KEY = 'jy-learning-svc';

    \App\Services\Service::$config = new \App\Services\FakeConfig([
        'gateway.app_key' => APP_KEY,
        'gateway.app_secret' => SECRET,
    ]);

    $signer = new \App\Services\Learning\GatewaySign();

    $results = [];

    function check($name, $ok, $detail = '')
    {
        global $results;
        $results[] = $ok;
        printf("[%s] %s  %s\n", $ok ? 'PASS' : 'FAIL', $name, $detail);
    }

    function post($url, $body, array $headers)
    {
        $lines = [];
        foreach ($headers as $k => $v) {
            $lines[] = sprintf('%s: %s', $k, $v);
        }
        $lines[] = 'Content-Type: application/json';

        $ch = curl_init($url);

        curl_setopt_array($ch, [
            CURLOPT_POST => true,
            CURLOPT_POSTFIELDS => $body,
            CURLOPT_HTTPHEADER => $lines,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_CONNECTTIMEOUT => 2,
            CURLOPT_TIMEOUT => 5,
            CURLOPT_PROXY => '',
        ]);

        $resp = curl_exec($ch);
        $code = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);

        return [$code, json_decode((string)$resp, true), (string)$resp];
    }

    $path = '/answer/api/v1/account/verify';
    $url = BASE . $path;

    // ── 1 正确签名 + 正确密码 ─────────────────────────────────────────
    $body = json_encode([
        'login' => 'admin',
        'pass' => 'Correct@12345',
        'login_type' => 'auto',
        'client_id' => APP_KEY,
    ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);

    $headers = $signer->headers('POST', $path, $body);

    check('0  五头齐备', count($headers) === 5 && isset($headers['X-Signature']),
        implode(',', array_keys($headers)));

    list($st, $d, $raw) = post($url, $body, $headers);
    check('1  正确签名 + 正确密码 -> 200 confirmed',
        $st === 200 && !empty($d['data']['confirmed']),
        sprintf('status=%d uid=%s role=%s', $st,
            $d['data']['user_id'] ?? '-', $d['data']['role'] ?? '-'));

    // ── 2 复用同一组头（nonce 重放）──────────────────────────────────
    list($st, $d) = post($url, $body, $headers);
    check('2  同 nonce 重放 -> 40107',
        $st === 401 && (int)($d['code'] ?? 0) === 40107,
        sprintf('status=%d code=%s', $st, $d['code'] ?? '-'));

    // ── 3 篡改签名 ───────────────────────────────────────────────────
    $body3 = json_encode(['login' => 'admin', 'pass' => 'Correct@12345'], JSON_UNESCAPED_SLASHES);
    $h3 = $signer->headers('POST', $path, $body3);
    $h3['X-Signature'] = str_repeat('0', 64);
    list($st, $d) = post($url, $body3, $h3);
    check('3  签名篡改 -> 40105',
        $st === 401 && (int)($d['code'] ?? 0) === 40105,
        sprintf('status=%d code=%s', $st, $d['code'] ?? '-'));

    // ── 4 时间戳超窗 ─────────────────────────────────────────────────
    $body4 = json_encode(['login' => 'admin', 'pass' => 'Correct@12345'], JSON_UNESCAPED_SLASHES);
    $h4 = $signer->headers('POST', $path, $body4);
    $h4['X-Timestamp'] = (string)(time() - 3600);
    list($st, $d) = post($url, $body4, $h4);
    check('4  时间戳超窗 -> 40106',
        $st === 401 && (int)($d['code'] ?? 0) === 40106,
        sprintf('status=%d code=%s', $st, $d['code'] ?? '-'));

    // ── 5 未知 AppKey ────────────────────────────────────────────────
    $body5 = json_encode(['login' => 'admin', 'pass' => 'Correct@12345'], JSON_UNESCAPED_SLASHES);
    $h5 = $signer->headers('POST', $path, $body5);
    $h5['X-App-Key'] = 'jy-unknown-svc';
    list($st, $d) = post($url, $body5, $h5);
    check('5  未知 AppKey -> 40108',
        $st === 401 && (int)($d['code'] ?? 0) === 40108,
        sprintf('status=%d code=%s', $st, $d['code'] ?? '-'));

    // ── 6 正确签名 + 错误密码（防枚举口径）───────────────────────────
    $body6 = json_encode(['login' => 'admin', 'pass' => 'Wrong@000000'], JSON_UNESCAPED_SLASHES);
    $h6 = $signer->headers('POST', $path, $body6);
    list($st, $d) = post($url, $body6, $h6);
    check('6  错误密码 -> 40104 invalid_credentials',
        $st === 401 && (int)($d['code'] ?? 0) === 40104
            && ($d['data']['reason'] ?? '') === 'invalid_credentials',
        sprintf('status=%d reason=%s', $st, $d['data']['reason'] ?? '-'));

    // ── 7 带 query 的路径（验 canonicalQuery 排序）───────────────────
    $qpath = '/answer/api/v1/account/verify?b=2&a=1&flag=';
    $body7 = json_encode(['login' => 'admin', 'pass' => 'Correct@12345'], JSON_UNESCAPED_SLASHES);
    $h7 = $signer->headers('POST', $qpath, $body7);
    list($st, $d) = post(BASE . $qpath, $body7, $h7);
    check('7  query 参与签名 -> 验签通过',
        $st === 200 && !empty($d['data']['confirmed']),
        sprintf('status=%d code=%s', $st, $d['code'] ?? '-'));

    // ── 8 中文登录名（UTF-8 body 哈希）───────────────────────────────
    $body8 = json_encode(['login' => '张三', 'pass' => 'Correct@12345'],
        JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    $h8 = $signer->headers('POST', $path, $body8);
    list($st, $d) = post($url, $body8, $h8);
    check('8  中文 body -> 验签通过',
        $st === 200 && !empty($d['data']['confirmed']),
        sprintf('status=%d username=%s', $st, $d['data']['username'] ?? '-'));

    $pass = count(array_filter($results));

    printf("\n%d/%d 通过\n", $pass, count($results));

    exit($pass === count($results) ? 0 : 1);
}

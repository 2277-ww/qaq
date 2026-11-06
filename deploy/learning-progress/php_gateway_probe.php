<?php
/**
 * 网关 L2 出站探针（独立运行，不依赖项目框架）
 *
 * 用途：在部署前证明「PHP 侧算出的签名 + PHP cURL 发出的请求」能被真实网关接受。
 * 签名算法与 app/Services/Learning/GatewaySign.php 逐字节一致，此处内联一份，
 * 是为了让探针能在没有 DI / 没有 autoload 的环境下单独跑起来。
 *
 * 密钥从 STDIN 读，不接受命令行参数——参数会进 shell history 与进程列表。
 *
 * 用法（在服务器上）：
 *     printf '%s\n' "$SECRET" | php php_gateway_probe.php
 *     printf '%s\n' "$SECRET" | php php_gateway_probe.php 'user@x.cn' 'Passw0rd!'
 */

$secret = trim((string)fgets(STDIN));

if ($secret === '') {
    fwrite(STDERR, "缺少密钥：请从 STDIN 传入\n");
    exit(2);
}

$base = getenv('JY_GATEWAY_BASE') ?: 'http://8.138.246.181';
$path = '/answer/api/v1/account/verify';
$appKey = getenv('JY_APP_KEY') ?: 'jy-learning-svc';

$login = $argv[1] ?? 'admin@jspi.edu.cn';
$pass = $argv[2] ?? 'Admin@12345';

/**
 * 与 GatewaySign 一致的 query 规范化：按 (key, value) 排序，空格编码为 "+"
 */
function canonical_query($query)
{
    $query = ltrim((string)$query, '?');
    if ($query === '') return '';
    $pairs = [];
    foreach (explode('&', $query) as $segment) {
        if ($segment === '') continue;
        $kv = explode('=', $segment, 2);
        $pairs[] = [urldecode($kv[0]), isset($kv[1]) ? urldecode($kv[1]) : ''];
    }
    usort($pairs, function ($a, $b) {
        $cmp = strcmp($a[0], $b[0]);
        return $cmp !== 0 ? $cmp : strcmp($a[1], $b[1]);
    });
    $out = [];
    foreach ($pairs as $p) {
        $enc = function ($v) { return str_replace('%20', '+', rawurlencode((string)$v)); };
        $out[] = $enc($p[0]) . '=' . $enc($p[1]);
    }
    return implode('&', $out);
}

$pos = strpos($path, '?');
$purePath = $pos === false ? $path : substr($path, 0, $pos);
$query = $pos === false ? '' : substr($path, $pos + 1);

$body = json_encode([
    'login' => $login,
    'pass' => $pass,
    'login_type' => 'auto',
    'client_id' => $appKey,
], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);

$ts = (string)time();
$nonce = bin2hex(random_bytes(16));

$canonical = implode("\n", [
    $appKey,
    $ts,
    $nonce,
    'POST',
    $purePath,
    canonical_query($query),
    hash('sha256', $body),
]);

$signature = hash_hmac('sha256', $canonical, $secret);

$headers = [
    'X-App-Key: ' . $appKey,
    'X-Timestamp: ' . $ts,
    'X-Nonce: ' . $nonce,
    'X-Sign-Alg: HMAC-SHA256',
    'X-Signature: ' . $signature,
    'Content-Type: application/json',
    'Accept: application/json',
];

$ch = curl_init($base . $path);

curl_setopt_array($ch, [
    CURLOPT_POST => true,
    CURLOPT_POSTFIELDS => $body,
    CURLOPT_HTTPHEADER => $headers,
    CURLOPT_RETURNTRANSFER => true,
    CURLOPT_CONNECTTIMEOUT => 3,
    CURLOPT_TIMEOUT => 8,
    CURLOPT_FOLLOWLOCATION => false,
]);

$resp = curl_exec($ch);
$errno = curl_errno($ch);
$status = (int)curl_getinfo($ch, CURLINFO_HTTP_CODE);
curl_close($ch);

$out = [
    'http_status' => $status,
    'curl_errno' => $errno,
    'php_version' => PHP_VERSION,
    'app_key' => $appKey,
    'body_sha256' => hash('sha256', $body),
    'response' => is_string($resp) ? json_decode($resp, true) : null,
];

if (!is_array($out['response'])) {
    $out['raw'] = is_string($resp) ? substr($resp, 0, 300) : '';
}

echo json_encode($out, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES | JSON_PRETTY_PRINT), "\n";

/**
 * 退出码语义：0 表示签名被网关接受（业务码非 40105）
 * 40104（密码错）同样算通过——签名已过，只是凭据不对
 */
$code = $out['response']['code'] ?? 0;

exit(in_array((int)$code, [40105, 40106, 40107, 40108], true) ? 1 : 0);

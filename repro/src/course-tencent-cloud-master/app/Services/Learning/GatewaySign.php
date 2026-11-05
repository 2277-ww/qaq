<?php
/**
 * 统一网关 L2 服务签名
 *
 * 五平台统一网关（Apache APISIX 3.13）对「没有用户、只有应用凭据」的机器调用
 * 走 L2 签名档，与平台之间自建的 X-Internal-Sign 是两套不同规范，不能混用：
 *
 *   网关 L2（本类负责）       —— 网关入口鉴权，验完即剥离，不进上游
 *   X-Internal-Sign（Gateway）—— 网关重算后注入上游，供业务侧校验身份头
 *
 * 因此服务态调用必须两套都带：先用 L2 过网关，再由网关重算出内部签名给下游。
 * 只带其中一套的后果很具体——只带 X-Internal-Sign 会被网关判 40105（缺签名头），
 * 只带 L2 则上游拿到的是网关重算的签名（正常），但本地直连对端时无法验签。
 *
 * ── 网关 L2 规范（以网关侧 jy-l2-sign 插件为准）────────────────────────────
 *
 *   请求头：
 *     X-App-Key    应用标识，本项目为 jy-learning-svc
 *     X-Timestamp  秒级时间戳，允许 ±300 s
 *     X-Nonce      单次随机串，Redis SET NX EX 600 去重
 *     X-Sign-Alg   固定 HMAC-SHA256
 *     X-Signature  hex(HMAC-SHA256(appSecret, canonical))
 *
 *   canonical 七段，以 "\n" 连接，段内不得再出现换行：
 *     appKey
 *     timestamp
 *     nonce
 *     METHOD            大写
 *     path              仅路径，不含域名与 query
 *     canonicalQuery    query 参数按 (key, value) 字典序排序后重新编码；无 query 传空串
 *     sha256(rawBody)   十六进制小写；GET 传空体时是 sha256("") 而非空串
 *
 *   网关侧错误码：
 *     40105 签名缺失或不匹配
 *     40106 时间戳超出窗口
 *     40107 nonce 重放
 *     40108 AppKey 未注册
 *
 * ── 与网关对齐时的两个易错点 ──────────────────────────────────────────────
 *
 * 1) query 的空格编码。网关侧用 Python urllib.parse.urlencode 生成基准串，
 *    空格编码为 "+"；PHP 的 rawurlencode 编码为 "%20"。两者不一致会导致
 *    「本地算得出、网关验不过」且签名长度相同、极难察觉。这里统一按 "+" 处理。
 * 2) 排序键是 (key, value)。只按 key 排序时，同名参数（如 a=2&a=1）顺序不定，
 *    网关与本平台各自排序结果可能不同。
 */

namespace App\Services\Learning;

use App\Services\Service;

class GatewaySign extends Service
{

    const ALG = 'HMAC-SHA256';

    /**
     * 签名头名称（顺序即规范顺序，文档与自检脚本共用）
     */
    const HEADERS = [
        'X-App-Key',
        'X-Timestamp',
        'X-Nonce',
        'X-Sign-Alg',
        'X-Signature',
    ];

    /**
     * 网关 L2 数字错误码 → 可读原因
     */
    const ERRORS = [
        40105 => '网关签名校验失败（缺签名头或签名不匹配）',
        40106 => '网关时间戳超出允许窗口（±300s）',
        40107 => '网关 nonce 重放被拒（同一 nonce 600s 内不可复用）',
        40108 => '网关 AppKey 未注册或已停用',
        40101 => '网关要求访问令牌，服务态调用需改用 /internal/ 路由',
        40300 => '网关未登记该路径，请求被默认拒绝',
    ];

    /**
     * 出站是否启用 L2 签名
     *
     * 对端级 app_key 存在即视为启用，避免每个对端都要单独开关。
     *
     * @param string $peer
     * @return bool
     */
    public function isEnabled($peer = '')
    {
        return $this->appKey($peer) !== '' && $this->appSecret($peer) !== '';
    }

    /**
     * 应用标识（对端可覆盖全局）
     *
     * @param string $peer
     * @return string
     */
    public function appKey($peer = '')
    {
        if ($peer !== '') {
            $peerConfig = (new Peers())->get($peer);

            if (trim((string)$peerConfig['app_key']) !== '') {
                return trim((string)$peerConfig['app_key']);
            }
        }

        return trim((string)$this->getConfig()->path('gateway.app_key', ''));
    }

    /**
     * 应用密钥（对端可覆盖全局）
     *
     * 与 L2 的 AppSecret 是「应用级」凭据，与 L1 的用户令牌、与 X-Internal-Sign
     * 的内部签名密钥都不是同一把，不可互相替代。
     *
     * @param string $peer
     * @return string
     */
    public function appSecret($peer = '')
    {
        if ($peer !== '') {
            $peerConfig = (new Peers())->get($peer);

            if (trim((string)$peerConfig['app_secret']) !== '') {
                return trim((string)$peerConfig['app_secret']);
            }
        }

        return trim((string)$this->getConfig()->path('gateway.app_secret', ''));
    }

    /**
     * 生成一次请求的 L2 头
     *
     * 未启用时返回空数组，调用方按「不带签名」处理（本地直连对端）。
     *
     * @param string $method
     * @param string $path 含 query 也可，内部会拆分
     * @param string $body 原始请求体
     * @param string $peer 对端标识
     * @return array
     */
    public function headers($method, $path, $body = '', $peer = '')
    {
        if (!$this->isEnabled($peer)) return [];

        $appKey = $this->appKey($peer);

        $timestamp = (string)time();

        $nonce = $this->nonce();

        $signature = $this->sign(
            $this->appSecret($peer),
            $appKey,
            $timestamp,
            $nonce,
            $method,
            $path,
            $body
        );

        return [
            'X-App-Key' => $appKey,
            'X-Timestamp' => $timestamp,
            'X-Nonce' => $nonce,
            'X-Sign-Alg' => self::ALG,
            'X-Signature' => $signature,
        ];
    }

    /**
     * 计算 L2 签名
     *
     * @param string $secret
     * @param string $appKey
     * @param string $timestamp
     * @param string $nonce
     * @param string $method
     * @param string $path 可含 query
     * @param string $body
     * @return string
     */
    public function sign($secret, $appKey, $timestamp, $nonce, $method, $path, $body = '')
    {
        $canonical = $this->canonical($appKey, $timestamp, $nonce, $method, $path, $body);

        return hash_hmac('sha256', $canonical, (string)$secret);
    }

    /**
     * 待签名字符串（排障时与网关侧逐段比对用）
     *
     * @param string $appKey
     * @param string $timestamp
     * @param string $nonce
     * @param string $method
     * @param string $path
     * @param string $body
     * @return string
     */
    public function canonical($appKey, $timestamp, $nonce, $method, $path, $body = '')
    {
        $parts = $this->splitPath((string)$path);

        return implode("\n", [
            (string)$appKey,
            (string)$timestamp,
            (string)$nonce,
            strtoupper((string)$method),
            $parts[0],
            $this->canonicalQuery($parts[1]),
            hash('sha256', (string)$body),
        ]);
    }

    /**
     * 规范形式（供能力发现接口与文档展示）
     *
     * @return string
     */
    public function canonicalPattern()
    {
        return 'appKey + "\n" + timestamp + "\n" + nonce + "\n" + METHOD + "\n"'
            . ' + path + "\n" + canonicalQuery + "\n" + sha256(rawBody)';
    }

    /**
     * query 规范串
     *
     * 空 query 返回空串（不是 "?"，也不是空数组的编码结果）。同名参数按
     * (key, value) 排序，空格编码为 "+"——两者都与网关侧的基准实现一致。
     *
     * @param string $query
     * @return string
     */
    public function canonicalQuery($query)
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

        $encoded = [];

        foreach ($pairs as $pair) {
            $encoded[] = $this->encode($pair[0]) . '=' . $this->encode($pair[1]);
        }

        return implode('&', $encoded);
    }

    /**
     * 网关 L2 错误码转可读原因，未收录的返回空串
     *
     * @param int $code
     * @return string
     */
    public function errorText($code)
    {
        return self::ERRORS[(int)$code] ?? '';
    }

    /**
     * 从响应体里取网关错误码
     *
     * 网关错误体形如 {"code":40105,"message":"...","requestId":"..."}，
     * 也存在只回状态码不带体的情况，因此两处都要看。
     *
     * @param int $status HTTP 状态码
     * @param string $body
     * @return int 未识别返回 0
     */
    public function errorCodeOf($status, $body)
    {
        $decoded = json_decode((string)$body, true);

        if (is_array($decoded) && isset($decoded['code']) && is_numeric($decoded['code'])) {

            $code = (int)$decoded['code'];

            if (isset(self::ERRORS[$code])) return $code;
        }

        /**
         * 401 但没给数字码时不能猜具体原因，交给调用方按状态码处理；
         * 这里只做「网关拒绝」的归类。
         */
        return 0;
    }

    /**
     * 生成 nonce
     *
     * 32 位十六进制。网关按 (appKey, nonce) 去重且保留 600 s，因此随机源
     * 必须足够宽；用 random_bytes 而不是 uniqid/mt_rand，后者在并发下会撞。
     *
     * @return string
     */
    public function nonce()
    {
        return bin2hex(random_bytes(16));
    }

    /**
     * 拆分 path 与 query
     *
     * @param string $path
     * @return array [path, query]
     */
    protected function splitPath($path)
    {
        $pos = strpos($path, '?');

        if ($pos === false) return [$path, ''];

        return [substr($path, 0, $pos), substr($path, $pos + 1)];
    }

    /**
     * 按网关基准实现的编码方式（quote_plus 语义）
     *
     * @param string $value
     * @return string
     */
    protected function encode($value)
    {
        return str_replace('%20', '+', rawurlencode((string)$value));
    }

}

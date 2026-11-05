<?php
/**
 * 登录接口限流
 *
 * 论坛账号登录会把用户输入的账号密码转发给论坛校验，本平台因此成了论坛
 * 账号确认接口的一个「代理入口」。不限流的话，任何人都能借这个入口对论坛
 * 做密码尝试——虽然论坛侧有防枚举与 200 QPS 限流，但代价是消耗配额、
 * 把审计日志填满，而且本平台自己完全没有感知。
 *
 * 用固定窗口计数而不是滑动窗口：登录是低频操作，窗口边界多放过几十次
 * 的影响可以忽略，换来的是 import 更少的实现与更低的 Redis 开销。
 *
 * 计数与过期用 Lua 原子执行。分两步做 INCR 再 EXPIRE 有个真实坑：
 * 若中间连接断开，key 会永久留存，等于把这个 IP 永久封禁。
 */

namespace App\Services\Gateway;

use App\Services\Service;

class LoginThrottle extends Service
{

    /**
     * 计数加一并在首次计数时设置过期，返回当前计数
     */
    const LUA = <<<'LUA'
local current = redis.call('incr', KEYS[1])
if current == 1 then
    redis.call('expire', KEYS[1], ARGV[1])
end
return current
LUA;

    /**
     * @param string $bucket 限流桶名，如 forum_login
     * @param string $identity 计数维度，通常是客户端 IP
     * @param int $limit 窗口内允许次数
     * @param int $window 窗口长度（秒）
     * @param int $retryAfter 出参：建议重试等待秒数
     * @return bool true 表示放行
     */
    public function allow($bucket, $identity, $limit, $window, &$retryAfter = 0)
    {
        $retryAfter = 0;

        $limit = (int)$limit;

        if ($limit <= 0) return true;

        $key = sprintf('throttle:%s:%s', $bucket, md5((string)$identity));

        try {

            $redis = $this->getRedis();

            $current = (int)$redis->eval(self::LUA, [$key, (int)$window], 1);

            if ($current <= $limit) return true;

            $ttl = (int)$redis->ttl($key);

            $retryAfter = $ttl > 0 ? $ttl : (int)$window;

            return false;

        } catch (\Throwable $e) {

            /**
             * Redis 故障时放行。登录是主路径，缓存不可用不应该让所有用户
             * 都登不进来——此时失去的是防刷能力，而不是可用性。
             */
            $this->getLogger()->warning('Login Throttle Unavailable: ' . $e->getMessage());

            return true;
        }
    }

}

<?php
/**
 * 对外用户主键（userId / sub）映射
 *
 * 按《自学平台统一身份与网关接入说明》1.4「身份主键换轨」：
 * 对外 userId 一律等于身份中心的 OIDC sub，kg_user.id 不再对外暴露。
 *
 * 当前部署尚未接入身份中心，本类做两件事：
 * 1) 若已建 kg_identity_binding 映射表，优先返回其中的 sub；
 * 2) 否则按配置的前缀生成可逆的占位主键（usr_<id>），保证联调期接口形态稳定。
 * 接入 OIDC 后只需保证映射表有数据，业务侧无需改动。
 */

namespace App\Services\Learning;

use App\Services\Service;
use Phalcon\Db;

class IdentityKey extends Service
{

    /**
     * 映射表是否可用（只探测一次）
     *
     * @var bool|null
     */
    protected static $bindingReady = null;

    /**
     * 内部编号 => 对外主键（单次请求内缓存）
     *
     * @var array
     */
    protected static $keyCache = [];

    /**
     * @param int $userId 内部 kg_user.id
     * @return string
     */
    public function forUserId($userId)
    {
        $userId = (int)$userId;

        if ($userId <= 0) return '';

        if (isset(self::$keyCache[$userId])) {
            return self::$keyCache[$userId];
        }

        $key = '';

        if ($this->hasBindingTable()) {
            try {
                $row = $this->db->fetchOne(
                    'SELECT sub FROM kg_identity_binding WHERE user_id = ? LIMIT 1',
                    Db::FETCH_ASSOC,
                    [$userId]
                );
                if ($row && !empty($row['sub'])) {
                    $key = (string)$row['sub'];
                }
            } catch (\Exception $e) {
                $key = '';
            }
        }

        if ($key === '') {
            $prefix = (string)$this->getConfig()->path('exam.user_prefix', 'usr_');
            $key = $prefix . $userId;
        }

        self::$keyCache[$userId] = $key;

        return $key;
    }

    /**
     * 对外主键 => 内部编号
     *
     * @param string $userKey
     * @return int 无法解析时返回 0
     */
    public function resolveUserId($userKey)
    {
        $userKey = trim((string)$userKey);

        if ($userKey === '') return 0;

        if ($this->hasBindingTable()) {
            try {
                $row = $this->db->fetchOne(
                    'SELECT user_id FROM kg_identity_binding WHERE sub = ? LIMIT 1',
                    Db::FETCH_ASSOC,
                    [$userKey]
                );
                if ($row && !empty($row['user_id'])) {
                    return (int)$row['user_id'];
                }
            } catch (\Exception $e) {
                // 忽略，回落到前缀解析
            }
        }

        $prefix = (string)$this->getConfig()->path('exam.user_prefix', 'usr_');

        if (strpos($userKey, $prefix) === 0) {
            $userKey = substr($userKey, strlen($prefix));
        }

        return ctype_digit($userKey) ? (int)$userKey : 0;
    }

    /**
     * @return bool
     */
    protected function hasBindingTable()
    {
        if (self::$bindingReady !== null) {
            return self::$bindingReady;
        }

        try {
            self::$bindingReady = (bool)$this->db->tableExists('kg_identity_binding');
        } catch (\Exception $e) {
            self::$bindingReady = false;
        }

        return self::$bindingReady;
    }

}

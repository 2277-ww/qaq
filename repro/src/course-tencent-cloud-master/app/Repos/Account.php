<?php
/**
 * @copyright Copyright (c) 2021 深圳市酷瓜软件有限公司
 * @license https://opensource.org/licenses/GPL-2.0
 * @link https://www.koogua.com
 */

namespace App\Repos;

use App\Models\Account as AccountModel;
use Phalcon\Mvc\Model;
use Phalcon\Mvc\Model\Resultset;
use Phalcon\Mvc\Model\ResultsetInterface;

class Account extends Repository
{

    /**
     * @param int $id
     * @return AccountModel|Model|bool
     */
    public function findById($id)
    {
        return AccountModel::findFirst([
            'conditions' => 'id = :id:',
            'bind' => ['id' => $id],
        ]);
    }

    /**
     * @param string $phone
     * @return AccountModel|Model|bool
     */
    public function findByPhone($phone)
    {
        return AccountModel::findFirst([
            'conditions' => 'phone = :phone:',
            'bind' => ['phone' => $phone],
        ]);
    }

    /**
     * @param string $email
     * @return AccountModel|Model|bool
     */
    public function findByEmail($email)
    {
        return AccountModel::findFirst([
            'conditions' => 'email = :email:',
            'bind' => ['email' => $email],
        ]);
    }

    /**
     * 按论坛用户主键查本地账号
     *
     * 论坛账号登录的映射入口。forum_uid 上有唯一索引，因此最多一条；
     * 未绑定的账号存 NULL，不会被任何查询命中。
     *
     * @param int $forumUid
     * @return AccountModel|Model|bool
     */
    public function findByForumUid($forumUid)
    {
        $forumUid = (int)$forumUid;

        if ($forumUid <= 0) return false;

        return AccountModel::findFirst([
            'conditions' => 'forum_uid = :forum_uid:',
            'bind' => ['forum_uid' => $forumUid],
        ]);
    }

    /**
     * @param array $ids
     * @param array|string $columns
     * @return ResultsetInterface|Resultset|AccountModel[]
     */
    public function findByIds($ids, $columns = '*')
    {
        return AccountModel::query()
            ->columns($columns)
            ->inWhere('id', $ids)
            ->execute();
    }

}

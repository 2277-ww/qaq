<?php
/**
 * @copyright Copyright (c) 2021 深圳市酷瓜软件有限公司
 * @license https://opensource.org/licenses/GPL-2.0
 * @link https://www.koogua.com
 */

namespace App\Models;

use Phalcon\Mvc\Model\Behavior\SoftDelete;

class Account extends Model
{

    /**
     * 主键编号
     *
     * @var int
     */
    public $id = 0;

    /**
     * 邮箱
     *
     * @var string
     */
    public $email = '';

    /**
     * 手机
     *
     * @var string
     */
    public $phone = '';

    /**
     * 论坛用户主键
     *
     * 跨平台身份：由论坛账号确认接口返回的 user_id，NULL 表示未绑定。
     * 用独立字段而不是复用 email/phone，因为论坛登录名可能是 admin
     * 这类非邮箱值，塞进 email 会把字段语义搞乱且不可逆。
     *
     * @var int|null
     */
    public $forum_uid = null;

    /**
     * 论坛用户名
     *
     * @var string
     */
    public $forum_name = '';

    /**
     * 密码
     *
     * @var string
     */
    public $password = '';

    /**
     * 密盐
     *
     * @var string
     */
    public $salt = '';

    /**
     * 删除标识
     *
     * @var int
     */
    public $deleted = 0;

    /**
     * 创建时间
     *
     * @var int
     */
    public $create_time = 0;

    /**
     * 更新时间
     *
     * @var int
     */
    public $update_time = 0;

    public function getSource(): string
    {
        return 'kg_account';
    }

    public function initialize()
    {
        parent::initialize();

        $this->addBehavior(
            new SoftDelete([
                'field' => 'deleted',
                'value' => 1,
            ])
        );
    }

    public function beforeCreate()
    {
        $this->create_time = time();
    }

    public function beforeUpdate()
    {
        $this->update_time = time();
    }

    public function afterCreate()
    {
        $user = new User();
        $user->id = $this->id;
        $user->name = "user_{$this->id}";
        $user->create();

        $userBalance = new UserBalance();
        $userBalance->user_id = $user->id;
        $userBalance->create();
    }

}

<?php
/**
 * 论坛账号映射：kg_account 增加跨平台身份字段
 *
 * forum_uid  —— 论坛主库 user.id，跨平台唯一标识。允许 NULL 而不是默认 0：
 *               存量账号全部为 0 时会互相冲突，唯一索引必然建立失败。
 *               MySQL 唯一索引允许多个 NULL，正好表达「尚未绑定论坛账号」。
 * forum_name —— 论坛用户名，仅用于展示与排障，不参与鉴权判定。
 *
 * 为什么不在 email 上做文章：论坛登录名可能是 admin / oyu 这类非邮箱值，
 * 而本平台登录名只认手机与邮箱（Validators\Account::checkLoginName）。
 * 用 email 存占位值会把「邮箱」这个语义污染的不可逆，且掩码邮箱
 * （a***@jspi.edu.cn）本身也不能当真实邮箱用。
 *
 * email / phone 保持空串：kg_account 上二者都是普通索引（KEY）而非 UNIQUE，
 * 多个空串可以共存，不会撞约束。
 */

use Phinx\Migration\AbstractMigration;

final class V20261106002000 extends AbstractMigration
{

    public function change()
    {
        $account = $this->table('kg_account');

        $account
            ->addColumn('forum_uid', 'integer', [
                'signed' => false, 'null' => true, 'default' => null,
                'after' => 'phone', 'comment' => '论坛用户主键，NULL 表示未绑定',
            ])
            ->addColumn('forum_name', 'string', [
                'limit' => 64, 'null' => false, 'default' => '',
                'after' => 'forum_uid', 'comment' => '论坛用户名，仅展示用',
            ])
            ->addIndex(['forum_uid'], [
                'name' => 'idx_forum_uid', 'unique' => true,
            ])
            ->update();
    }

}

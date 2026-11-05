<?php
/**
 * 考试平台回执：发件箱增加 acknowledge 相关字段
 *
 * acked_at   —— 对端回执到达时间，0 表示尚未确认；
 * remote_id  —— 对端侧记录号（如考试平台成绩单编号），对账时按它反查；
 * ack_status —— 回执结论 accepted / rejected。
 *
 * 加字段而不是新表，是因为回执与投递记录是一对一关系，
 * 拆表会把「一条事件的生命周期」摊到两处，排障时要多一次 join。
 */

use Phinx\Migration\AbstractMigration;

final class V20261105233000 extends AbstractMigration
{

    public function change()
    {
        $outbox = $this->table('kg_exam_outbox');

        $outbox
            ->addColumn('acked_at', 'integer', [
                'signed' => false, 'null' => false, 'default' => 0,
                'after' => 'sent_at', 'comment' => '对端回执时间，0 表示未确认',
            ])
            ->addColumn('remote_id', 'string', [
                'limit' => 64, 'null' => false, 'default' => '',
                'after' => 'acked_at', 'comment' => '对端记录号，对账用',
            ])
            ->addColumn('ack_status', 'string', [
                'limit' => 16, 'null' => false, 'default' => '',
                'after' => 'remote_id', 'comment' => 'accepted / rejected',
            ])
            ->addIndex(['target', 'acked_at'], ['name' => 'idx_target_acked'])
            ->update();
    }

}

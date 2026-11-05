<?php
/**
 * 学习进度推送发件箱
 *
 * 对应《自学平台统一身份与网关接入说明》8.3「发件箱表增补」的落地版本。
 * 与 kg_growth_outbox（成长档案通道）分表存放：跨平台通道按下游隔离，
 * 考试平台通道的退避、死信与重放互不影响档案通道。
 */

use Phinx\Migration\AbstractMigration;

final class V20261105180000 extends AbstractMigration
{

    public function change()
    {
        $table = $this->table('kg_exam_outbox', [
            'id' => 'id',
            'engine' => 'InnoDB',
            'encoding' => 'utf8mb4',
            'collation' => 'utf8mb4_general_ci',
            'comment' => '学习进度推送发件箱（考试平台）',
        ]);

        $table
            ->addColumn('event_id', 'string', ['limit' => 64, 'null' => false, 'default' => '', 'comment' => '事件编号 evt_ 前缀'])
            ->addColumn('event_type', 'string', ['limit' => 64, 'null' => false, 'default' => '', 'comment' => 'learning.progress.updated / course.completed'])
            ->addColumn('event_version', 'string', ['limit' => 10, 'null' => false, 'default' => '1.0'])
            ->addColumn('user_id', 'integer', ['signed' => false, 'null' => false, 'default' => 0, 'comment' => '内部用户编号'])
            ->addColumn('course_id', 'integer', ['signed' => false, 'null' => false, 'default' => 0])
            ->addColumn('user_key', 'string', ['limit' => 64, 'null' => false, 'default' => '', 'comment' => '对外 userId（OIDC sub）'])
            ->addColumn('course_key', 'string', ['limit' => 64, 'null' => false, 'default' => '', 'comment' => '对外 courseId'])
            ->addColumn('progress', 'integer', ['signed' => false, 'null' => false, 'default' => 0, 'comment' => '入箱时进度，用于节流比较'])
            ->addColumn('payload', 'text', ['null' => true, 'comment' => '事件封套 JSON'])
            ->addColumn('status', 'integer', ['limit' => 1, 'signed' => false, 'null' => false, 'default' => 0, 'comment' => '0待发 1已发 2待重试 3死信'])
            ->addColumn('retry_count', 'integer', ['signed' => false, 'null' => false, 'default' => 0])
            ->addColumn('next_retry_at', 'integer', ['signed' => false, 'null' => false, 'default' => 0])
            ->addColumn('last_error', 'string', ['limit' => 500, 'null' => false, 'default' => ''])
            ->addColumn('response_code', 'integer', ['null' => false, 'default' => 0, 'comment' => '网关返回状态码，0 为网络层失败'])
            ->addColumn('request_id', 'string', ['limit' => 64, 'null' => false, 'default' => ''])
            ->addColumn('occurred_at', 'integer', ['signed' => false, 'null' => false, 'default' => 0])
            ->addColumn('sent_at', 'integer', ['signed' => false, 'null' => false, 'default' => 0])
            ->addColumn('dead_at', 'integer', ['signed' => false, 'null' => false, 'default' => 0])
            ->addColumn('create_time', 'integer', ['signed' => false, 'null' => false, 'default' => 0])
            ->addColumn('update_time', 'integer', ['signed' => false, 'null' => false, 'default' => 0])
            ->addIndex(['event_id'], ['unique' => true, 'name' => 'uniq_event_id'])
            ->addIndex(['status', 'next_retry_at'], ['name' => 'idx_due'])
            ->addIndex(['user_id', 'course_id'], ['name' => 'idx_user_course'])
            ->addIndex(['event_type'], ['name' => 'idx_type'])
            ->create();
    }

}

<?php
/**
 * 多对端改造：发件箱增加 target/channel，新增对端入站收件箱
 *
 * target  —— 事件发往哪个对端（exam|training|forum），投递时按它取路径与白名单；
 * channel —— official（事件目录内类型）或 extension（本地扩展事件走独立路径）。
 *
 * 存量数据默认 target=exam、channel=official，与改造前的行为一致。
 */

use Phinx\Migration\AbstractMigration;

final class V20261105230000 extends AbstractMigration
{

    public function change()
    {
        $outbox = $this->table('kg_exam_outbox');

        $outbox
            ->addColumn('target', 'string', [
                'limit' => 32, 'null' => false, 'default' => 'exam',
                'after' => 'id', 'comment' => '对端：exam|training|forum',
            ])
            ->addColumn('channel', 'string', [
                'limit' => 16, 'null' => false, 'default' => 'official',
                'after' => 'target', 'comment' => 'official 正式通道 / extension 扩展通道',
            ])
            ->addIndex(['target', 'status', 'next_retry_at'], ['name' => 'idx_target_due'])
            ->update();

        $inbox = $this->table('kg_peer_inbox', [
            'id' => 'id',
            'engine' => 'InnoDB',
            'encoding' => 'utf8mb4',
            'collation' => 'utf8mb4_general_ci',
            'comment' => '跨平台入站事件收件箱（实训/论坛回传）',
        ]);

        $inbox
            ->addColumn('source', 'string', ['limit' => 32, 'null' => false, 'default' => '', 'comment' => '来源对端 training|forum'])
            ->addColumn('event_id', 'string', ['limit' => 64, 'null' => false, 'default' => ''])
            ->addColumn('event_type', 'string', ['limit' => 64, 'null' => false, 'default' => ''])
            ->addColumn('event_version', 'string', ['limit' => 10, 'null' => false, 'default' => '1.0'])
            ->addColumn('actor_key', 'string', ['limit' => 64, 'null' => false, 'default' => '', 'comment' => '对外 userId（OIDC sub）'])
            ->addColumn('payload', 'text', ['null' => true, 'comment' => '原始事件封套'])
            ->addColumn('status', 'integer', ['limit' => 1, 'signed' => false, 'null' => false, 'default' => 0, 'comment' => '0已接收 1已处理 2已忽略 3处理失败'])
            ->addColumn('note', 'string', ['limit' => 255, 'null' => false, 'default' => ''])
            ->addColumn('request_id', 'string', ['limit' => 64, 'null' => false, 'default' => ''])
            ->addColumn('received_at', 'integer', ['signed' => false, 'null' => false, 'default' => 0])
            ->addColumn('processed_at', 'integer', ['signed' => false, 'null' => false, 'default' => 0])
            ->addColumn('create_time', 'integer', ['signed' => false, 'null' => false, 'default' => 0])
            ->addColumn('update_time', 'integer', ['signed' => false, 'null' => false, 'default' => 0])
            ->addIndex(['source', 'event_id'], ['unique' => true, 'name' => 'uniq_source_event'])
            ->addIndex(['status'], ['name' => 'idx_status'])
            ->addIndex(['event_type'], ['name' => 'idx_type'])
            ->create();
    }

}

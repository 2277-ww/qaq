SET @db := 'ctc';

SET @add_target := (
  SELECT IF(COUNT(*) = 0,
    'ALTER TABLE `kg_exam_outbox` ADD COLUMN `target` varchar(32) NOT NULL DEFAULT ''exam'' COMMENT ''对端 exam|training|forum'' AFTER `id`',
    'DO 0')
  FROM information_schema.columns
  WHERE table_schema = @db AND table_name = 'kg_exam_outbox' AND column_name = 'target'
);
PREPARE s1 FROM @add_target; EXECUTE s1; DEALLOCATE PREPARE s1;

SET @add_channel := (
  SELECT IF(COUNT(*) = 0,
    'ALTER TABLE `kg_exam_outbox` ADD COLUMN `channel` varchar(16) NOT NULL DEFAULT ''official'' COMMENT ''official 正式通道 / extension 扩展通道'' AFTER `target`',
    'DO 0')
  FROM information_schema.columns
  WHERE table_schema = @db AND table_name = 'kg_exam_outbox' AND column_name = 'channel'
);
PREPARE s2 FROM @add_channel; EXECUTE s2; DEALLOCATE PREPARE s2;

SET @add_idx := (
  SELECT IF(COUNT(*) = 0,
    'ALTER TABLE `kg_exam_outbox` ADD KEY `idx_target_due` (`target`,`status`,`next_retry_at`)',
    'DO 0')
  FROM information_schema.statistics
  WHERE table_schema = @db AND table_name = 'kg_exam_outbox' AND index_name = 'idx_target_due'
);
PREPARE s3 FROM @add_idx; EXECUTE s3; DEALLOCATE PREPARE s3;

CREATE TABLE IF NOT EXISTS `kg_peer_inbox` (
  `id` int(11) unsigned NOT NULL AUTO_INCREMENT,
  `source` varchar(32) NOT NULL DEFAULT '' COMMENT '来源对端 training|forum',
  `event_id` varchar(64) NOT NULL DEFAULT '',
  `event_type` varchar(64) NOT NULL DEFAULT '',
  `event_version` varchar(10) NOT NULL DEFAULT '1.0',
  `actor_key` varchar(64) NOT NULL DEFAULT '' COMMENT '对外 userId（OIDC sub）',
  `payload` text COMMENT '原始事件封套',
  `status` tinyint(3) unsigned NOT NULL DEFAULT '0' COMMENT '0已接收 1已处理 2已忽略 3处理失败',
  `note` varchar(255) NOT NULL DEFAULT '',
  `request_id` varchar(64) NOT NULL DEFAULT '',
  `received_at` int(11) unsigned NOT NULL DEFAULT '0',
  `processed_at` int(11) unsigned NOT NULL DEFAULT '0',
  `create_time` int(11) unsigned NOT NULL DEFAULT '0',
  `update_time` int(11) unsigned NOT NULL DEFAULT '0',
  PRIMARY KEY (`id`),
  UNIQUE KEY `uniq_source_event` (`source`,`event_id`),
  KEY `idx_status` (`status`),
  KEY `idx_type` (`event_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COMMENT='跨平台入站事件收件箱（实训/论坛回传）';

UPDATE `kg_exam_outbox` SET `target` = 'exam' WHERE `target` = '';

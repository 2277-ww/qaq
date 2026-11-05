-- 考试平台回执字段（幂等，可重复执行）
-- 目标表：kg_exam_outbox
-- 对应迁移：db/migrations/20261105233000.php

SET @db := DATABASE();

SET @sql := (
  SELECT IF(COUNT(*) = 0,
    'ALTER TABLE `kg_exam_outbox` ADD COLUMN `acked_at` INT UNSIGNED NOT NULL DEFAULT 0 COMMENT ''对端回执时间，0 表示未确认'' AFTER `sent_at`',
    'SELECT ''acked_at exists''')
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = @db AND TABLE_NAME = 'kg_exam_outbox' AND COLUMN_NAME = 'acked_at'
);
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @sql := (
  SELECT IF(COUNT(*) = 0,
    'ALTER TABLE `kg_exam_outbox` ADD COLUMN `remote_id` VARCHAR(64) NOT NULL DEFAULT '''' COMMENT ''对端记录号，对账用'' AFTER `acked_at`',
    'SELECT ''remote_id exists''')
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = @db AND TABLE_NAME = 'kg_exam_outbox' AND COLUMN_NAME = 'remote_id'
);
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @sql := (
  SELECT IF(COUNT(*) = 0,
    'ALTER TABLE `kg_exam_outbox` ADD COLUMN `ack_status` VARCHAR(16) NOT NULL DEFAULT '''' COMMENT ''accepted / rejected'' AFTER `remote_id`',
    'SELECT ''ack_status exists''')
  FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = @db AND TABLE_NAME = 'kg_exam_outbox' AND COLUMN_NAME = 'ack_status'
);
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

SET @sql := (
  SELECT IF(COUNT(*) = 0,
    'ALTER TABLE `kg_exam_outbox` ADD INDEX `idx_target_acked` (`target`, `acked_at`)',
    'SELECT ''idx_target_acked exists''')
  FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = @db AND TABLE_NAME = 'kg_exam_outbox' AND INDEX_NAME = 'idx_target_acked'
);
PREPARE s FROM @sql; EXECUTE s; DEALLOCATE PREPARE s;

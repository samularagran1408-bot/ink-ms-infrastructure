-- Eliminación lógica de usuarios (HU08).
-- Idempotente: no falla si las columnas ya existen.

USE user_ms;

SET @col_deleted := (
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = 'user_ms' AND TABLE_NAME = 'user_profile' AND COLUMN_NAME = 'deleted'
);
SET @sql_deleted := IF(@col_deleted = 0,
    'ALTER TABLE user_profile ADD COLUMN deleted BOOLEAN NOT NULL DEFAULT FALSE',
    'SELECT 1');
PREPARE stmt FROM @sql_deleted;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @col_deleted_at := (
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = 'user_ms' AND TABLE_NAME = 'user_profile' AND COLUMN_NAME = 'deleted_at'
);
SET @sql_deleted_at := IF(@col_deleted_at = 0,
    'ALTER TABLE user_profile ADD COLUMN deleted_at DATETIME NULL',
    'SELECT 1');
PREPARE stmt FROM @sql_deleted_at;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

UPDATE user_profile SET deleted = FALSE WHERE deleted IS NULL;

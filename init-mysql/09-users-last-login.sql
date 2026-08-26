-- Último acceso del usuario (panel admin).
-- Idempotente: no falla si la columna ya existe.

USE user_ms;

SET @col_last_login := (
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = 'user_ms' AND TABLE_NAME = 'user_profile' AND COLUMN_NAME = 'last_login_at'
);
SET @sql_last_login := IF(@col_last_login = 0,
    'ALTER TABLE user_profile ADD COLUMN last_login_at DATETIME NULL',
    'SELECT 1');
PREPARE stmt FROM @sql_last_login;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

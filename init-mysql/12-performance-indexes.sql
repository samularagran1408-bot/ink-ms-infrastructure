-- Índices y UNIQUE para catálogo de eventos e inscripciones concurrentes.
-- Idempotente: se puede aplicar sobre una base ya existente (Docker o MySQL gestionado).

USE sports_events_ms;

SET NAMES utf8mb4;

-- Si hubo dobles inscripciones antes del UNIQUE, deja la más antigua.
DELETE r1 FROM event_registration r1
INNER JOIN event_registration r2
  ON r1.user_id = r2.user_id
 AND r1.event_id = r2.event_id
 AND (
     r1.registration_date > r2.registration_date
     OR (r1.registration_date = r2.registration_date AND r1.id > r2.id)
 );

SET @idx_status_date := (
    SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = 'sports_events_ms'
      AND TABLE_NAME = 'event'
      AND INDEX_NAME = 'idx_event_status_date'
);
SET @sql_status_date := IF(@idx_status_date = 0,
    'ALTER TABLE event ADD INDEX idx_event_status_date (status, event_date, event_time)',
    'SELECT 1');
PREPARE stmt FROM @sql_status_date;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @idx_created_by := (
    SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = 'sports_events_ms'
      AND TABLE_NAME = 'event'
      AND INDEX_NAME = 'idx_event_created_by'
);
SET @sql_created_by := IF(@idx_created_by = 0,
    'ALTER TABLE event ADD INDEX idx_event_created_by (created_by)',
    'SELECT 1');
PREPARE stmt FROM @sql_created_by;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @idx_reg_event := (
    SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = 'sports_events_ms'
      AND TABLE_NAME = 'event_registration'
      AND INDEX_NAME = 'idx_registration_event'
);
SET @sql_reg_event := IF(@idx_reg_event = 0,
    'ALTER TABLE event_registration ADD INDEX idx_registration_event (event_id)',
    'SELECT 1');
PREPARE stmt FROM @sql_reg_event;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @uk_user_event := (
    SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = 'sports_events_ms'
      AND TABLE_NAME = 'event_registration'
      AND INDEX_NAME = 'uk_user_event'
);
SET @sql_uk := IF(@uk_user_event = 0,
    'ALTER TABLE event_registration ADD UNIQUE KEY uk_user_event (user_id, event_id)',
    'SELECT 1');
PREPARE stmt FROM @sql_uk;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Índices de listados admin (user_ms)
USE user_ms;

SET @idx_user_list := (
    SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = 'user_ms'
      AND TABLE_NAME = 'user_profile'
      AND INDEX_NAME = 'idx_user_list'
);
SET @sql_user_list := IF(@idx_user_list = 0,
    'ALTER TABLE user_profile ADD INDEX idx_user_list (deleted, is_active, full_name)',
    'SELECT 1');
PREPARE stmt FROM @sql_user_list;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @idx_user_disability := (
    SELECT COUNT(*) FROM information_schema.STATISTICS
    WHERE TABLE_SCHEMA = 'user_ms'
      AND TABLE_NAME = 'user_profile'
      AND INDEX_NAME = 'idx_user_disability'
);
SET @sql_user_disability := IF(@idx_user_disability = 0,
    'ALTER TABLE user_profile ADD INDEX idx_user_disability (disability)',
    'SELECT 1');
PREPARE stmt FROM @sql_user_disability;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

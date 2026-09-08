-- Comentario opcional al registrar asistencia (QR o formulario).
-- Idempotente: no falla si la columna ya existe.

USE sports_events_ms;

SET @col_notes := (
    SELECT COUNT(*) FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = 'sports_events_ms'
      AND TABLE_NAME = 'event_attendance'
      AND COLUMN_NAME = 'notes'
);
SET @sql_notes := IF(@col_notes = 0,
    'ALTER TABLE event_attendance ADD COLUMN notes VARCHAR(500) NULL',
    'SELECT 1');
PREPARE stmt FROM @sql_notes;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

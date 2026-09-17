-- Columnas para programación de reporte semanal (HU35).
USE analytics_ms;

-- Ejecutar una vez en el MySQL de analytics si JPA_DDL_AUTO=validate.
-- Con ddl-auto=update Hibernate ya crea estas columnas al arrancar reports.

ALTER TABLE report_configs ADD COLUMN schedule_enabled TINYINT(1) NULL;
ALTER TABLE report_configs ADD COLUMN schedule_frequency VARCHAR(20) NULL;
ALTER TABLE report_configs ADD COLUMN recipient_email VARCHAR(255) NULL;
ALTER TABLE report_configs MODIFY COLUMN owner_id VARCHAR(255) NOT NULL;

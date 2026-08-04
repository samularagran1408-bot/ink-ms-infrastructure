-- Parche: filas antiguas con NULL en flags booleanos/enteros rompían
-- Hibernate al mapear a primitivos Java (error en GET /api/users/perfil).
-- Idempotente: seguro ejecutarlo varias veces.

USE user_ms;

UPDATE user_profile SET is_active = TRUE WHERE is_active IS NULL;
UPDATE user_profile SET blocked_permanently = FALSE WHERE blocked_permanently IS NULL;

-- Columnas que JPA puede haber añadido después (nullable sin default)
UPDATE user_profile SET email_verified = FALSE WHERE email_verified IS NULL;
UPDATE user_profile SET phone_verified = FALSE WHERE phone_verified IS NULL;
UPDATE user_profile SET test_event_created = FALSE WHERE test_event_created IS NULL;
UPDATE user_profile SET organizer_quiz_passed = FALSE WHERE organizer_quiz_passed IS NULL;
UPDATE user_profile SET trainer_quiz_passed = FALSE WHERE trainer_quiz_passed IS NULL;

UPDATE user_profile SET events_attended = 0 WHERE events_attended IS NULL;
UPDATE user_profile SET events_created = 0 WHERE events_created IS NULL;
UPDATE user_profile SET platform_days = 0 WHERE platform_days IS NULL;
UPDATE user_profile SET experience_months = 0 WHERE experience_months IS NULL;
UPDATE user_profile SET events_as_trainer = 0 WHERE events_as_trainer IS NULL;

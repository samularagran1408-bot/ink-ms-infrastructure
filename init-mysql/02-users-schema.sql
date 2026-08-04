-- Schema user_ms (RF26-RF30 admin panel support)

CREATE DATABASE IF NOT EXISTS user_ms;
USE user_ms;

-- Perfil completo del usuario
CREATE TABLE IF NOT EXISTS user_profile (
    id CHAR(36) PRIMARY KEY,
    full_name VARCHAR(150) NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(100) UNIQUE NOT NULL,
    profile_picture TEXT,
    bio TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    block_reason VARCHAR(500),
    blocked_until DATETIME,
    blocked_permanently BOOLEAN NOT NULL DEFAULT FALSE,
    disability VARCHAR(100),
    companion_full_name VARCHAR(150),
    companion_phone VARCHAR(20),
    companion_relationship VARCHAR(80),
    companion_email VARCHAR(100),
    support_preference VARCHAR(50),
    support_preference_notes VARCHAR(255),
    email_verified BOOLEAN NOT NULL DEFAULT FALSE,
    phone_verified BOOLEAN NOT NULL DEFAULT FALSE,
    events_attended INT NOT NULL DEFAULT 0,
    events_created INT NOT NULL DEFAULT 0,
    platform_days INT NOT NULL DEFAULT 0,
    test_event_created BOOLEAN NOT NULL DEFAULT FALSE,
    organizer_quiz_score DOUBLE NULL,
    organizer_quiz_passed BOOLEAN NOT NULL DEFAULT FALSE,
    organizer_verification_status VARCHAR(20) DEFAULT 'pending',
    certification_file VARCHAR(255),
    experience_months INT NOT NULL DEFAULT 0,
    events_as_trainer INT NOT NULL DEFAULT 0,
    trainer_quiz_score DOUBLE NULL,
    trainer_quiz_passed BOOLEAN NOT NULL DEFAULT FALSE,
    identity_document VARCHAR(255),
    trainer_verification_status VARCHAR(20) DEFAULT 'pending',
    verified_roles VARCHAR(255) DEFAULT '',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Roles
CREATE TABLE IF NOT EXISTS role (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT
);

-- Usuario - Rol
CREATE TABLE IF NOT EXISTS user_role (
    user_id CHAR(36),
    role_id INT,
    assigned_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    assigned_by VARCHAR(100),
    PRIMARY KEY (user_id, role_id),
    FOREIGN KEY (user_id) REFERENCES user_profile(id),
    FOREIGN KEY (role_id) REFERENCES role(id)
);

-- Historial de actividad del usuario
CREATE TABLE IF NOT EXISTS user_activity (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    user_id CHAR(36) NOT NULL,
    action VARCHAR(100) NOT NULL,
    details TEXT,
    ip_address VARCHAR(45),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES user_profile(id)
);

-- RF29: historial de acciones administrativas
CREATE TABLE IF NOT EXISTS admin_audit_log (
    id CHAR(36) PRIMARY KEY,
    admin_email VARCHAR(100) NOT NULL,
    action VARCHAR(100) NOT NULL,
    target_email VARCHAR(100),
    target_user_id CHAR(36),
    details TEXT,
    ip_address VARCHAR(45),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_admin_audit_admin (admin_email),
    INDEX idx_admin_audit_target (target_email),
    INDEX idx_admin_audit_created (created_at)
);

-- RF30: configuración global del sistema
CREATE TABLE IF NOT EXISTS system_config (
    config_key VARCHAR(100) PRIMARY KEY,
    config_value VARCHAR(500) NOT NULL,
    description VARCHAR(255),
    updated_by VARCHAR(100),
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Roles por defecto (RF27)
INSERT IGNORE INTO role (id, name, description) VALUES
(1, 'ADMIN', 'CONTROL DE TODO'),
(2, 'ENTRENADOR', 'PREVENTIVO DE LESIONES'),
(3, 'USUARIO', 'CLIENTE'),
(4, 'ORGANIZADOR', 'ENCARGADO DE LOS EVENTOS');

-- Parámetros globales por defecto (RF30)
INSERT IGNORE INTO system_config (config_key, config_value, description, updated_by) VALUES
('max_login_attempts', '5', 'Intentos fallidos de login antes de bloqueo temporal', 'SYSTEM'),
('block_duration_minutes', '15', 'Minutos de bloqueo por fuerza bruta', 'SYSTEM'),
('session_timeout_minutes', '1440', 'Duración máxima de sesión en minutos', 'SYSTEM'),
('password_min_length', '8', 'Longitud mínima de contraseña', 'SYSTEM'),
('registration_enabled', 'true', 'Permite nuevos registros en la plataforma', 'SYSTEM'),
('maintenance_mode', 'false', 'Modo mantenimiento: restringe operaciones no admin', 'SYSTEM'),
('max_events_per_organizer', '50', 'Límite de eventos activos por organizador', 'SYSTEM'),
('default_event_capacity', '30', 'Cupo por defecto al crear un evento', 'SYSTEM'),
('waitlist_enabled', 'true', 'Habilita listas de espera cuando se agotan cupos', 'SYSTEM'),
('waitlist_notification_enabled', 'true', 'Notificar a usuarios en espera cuando hay cupo', 'SYSTEM');

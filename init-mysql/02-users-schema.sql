-- V1__init_users_db.sql

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
    is_active BOOLEAN DEFAULT TRUE,
    disability VARCHAR(100),
    companion_full_name VARCHAR(150),
    companion_phone VARCHAR(20),
    companion_relationship VARCHAR(80),
    companion_email VARCHAR(100),
    support_preference VARCHAR(50),
    support_preference_notes VARCHAR(255),
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
    PRIMARY KEY (user_id, role_id),
    FOREIGN KEY (user_id) REFERENCES user_profile(id),
    FOREIGN KEY (role_id) REFERENCES role(id)
);

-- Historial de actividad del usuario
CREATE TABLE IF NOT EXISTS user_activity (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    user_id CHAR(36) NOT NULL,
    action VARCHAR(100) NOT NULL,
    details JSON,
    ip_address VARCHAR(45),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES user_profile(id)
);

-- Insertar roles por defecto
INSERT IGNORE INTO role (id, name, description) VALUES 
(1, 'ADMIN', 'CONTROL DE TODO'),
(2, 'ENTRENADOR', 'PREVENTIVO DE LESIONES'),
(3, 'USUARIO', 'CLIENTE'),
(4, 'ORGANIZADOR', 'ENCARGADO DE LOS EVENTOS');
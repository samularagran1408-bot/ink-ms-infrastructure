CREATE DATABASE IF NOT EXISTS auth_ms;
USE auth_ms;

-- Usuarios solo para autenticación
CREATE TABLE auth_user (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    email VARCHAR(100) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    last_login DATETIME,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Tokens de recuperación
CREATE TABLE password_reset_token (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    user_id CHAR(36) NOT NULL,
    token VARCHAR(255) UNIQUE NOT NULL,
    expires_at DATETIME NOT NULL,
    used BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (user_id) REFERENCES auth_user(id)
);

-- Registro de intentos de login
CREATE TABLE login_attempt (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    email VARCHAR(100) NOT NULL,
    attempt_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    successful BOOLEAN DEFAULT FALSE,
    ip_address VARCHAR(45)
);

-- Modificación del token para que sea de 6 caracteres
ALTER TABLE password_reset_token MODIFY token VARCHAR(6) NOT NULL;

describe password_reset_token;

select * from auth_user;
select * from password_reset_token;
select * from login_attempt;
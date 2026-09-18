-- Solicitudes de rol (ENTRENADOR / ORGANIZADOR) en el registro.
USE user_ms;

CREATE TABLE IF NOT EXISTS role_request (
    id CHAR(36) PRIMARY KEY,
    user_id CHAR(36) NOT NULL,
    user_email VARCHAR(100) NOT NULL,
    user_full_name VARCHAR(150) NOT NULL,
    requested_role VARCHAR(50) NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    requested_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    reviewed_by VARCHAR(100) NULL,
    reviewed_at DATETIME NULL,
    review_notes VARCHAR(500) NULL,
    INDEX idx_role_request_status (status),
    INDEX idx_role_request_user (user_id),
    INDEX idx_role_request_email (user_email),
    CONSTRAINT fk_role_request_user
        FOREIGN KEY (user_id) REFERENCES user_profile(id)
);

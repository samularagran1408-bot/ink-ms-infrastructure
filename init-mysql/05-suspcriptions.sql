CREATE DATABASE inklusport_subscriptions;
USE inklusport_subscriptions;

-- IDs de organizador/usuario/evento alineados con users/sports (UUID CHAR(36)).

CREATE TABLE plan (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,
    precio DECIMAL(10,2) NOT NULL,
    limite_eventos_mes INT NOT NULL,
    porcentaje_comision DECIMAL(5,2) NOT NULL,
    duracion_dias INT NOT NULL,
    activo BOOLEAN DEFAULT TRUE,
    es_gratuito BOOLEAN DEFAULT FALSE,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE beneficio_plan (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    plan_id BIGINT NOT NULL,
    beneficio VARCHAR(255) NOT NULL,

    CONSTRAINT fk_beneficio_plan
    FOREIGN KEY (plan_id)
    REFERENCES plan(id)
);

CREATE TABLE suscripcion (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    organizador_id VARCHAR(36) NOT NULL,
    plan_id BIGINT NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,
    estado ENUM(
        'ACTIVA',
        'VENCIDA',
        'CANCELADA',
        'SUSPENDIDA'
    ) NOT NULL,
    eventos_creados_mes INT DEFAULT 0,
    renovacion_automatica BOOLEAN DEFAULT FALSE,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_suscripcion_plan
    FOREIGN KEY (plan_id)
    REFERENCES plan(id),

    INDEX idx_suscripcion_organizador (organizador_id),
    INDEX idx_suscripcion_estado (estado)
);

CREATE TABLE historial_suscripcion (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    suscripcion_id BIGINT NOT NULL,
    tipo_movimiento ENUM(
        'CREACION',
        'RENOVACION',
        'CAMBIO_PLAN',
        'CANCELACION'
    ) NOT NULL,
    plan_anterior_id BIGINT NULL,
    plan_nuevo_id BIGINT NULL,
    fecha_movimiento TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_historial_suscripcion
    FOREIGN KEY (suscripcion_id)
    REFERENCES suscripcion(id)
);

CREATE TABLE pago_suscripcion (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    suscripcion_id BIGINT NOT NULL,
    monto DECIMAL(10,2) NOT NULL,
    metodo_pago VARCHAR(50),
    referencia_transaccion VARCHAR(150),
    estado ENUM(
        'PENDIENTE',
        'APROBADO',
        'RECHAZADO'
    ) NOT NULL,
    fecha_pago TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_pago_suscripcion
    FOREIGN KEY (suscripcion_id)
    REFERENCES suscripcion(id)
);

CREATE TABLE configuracion_evento_pago (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    evento_id VARCHAR(36) NOT NULL,
    organizador_id VARCHAR(36) NOT NULL,
    es_pago BOOLEAN DEFAULT FALSE,
    valor_inscripcion DECIMAL(10,2),
    porcentaje_comision DECIMAL(5,2),
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    UNIQUE KEY uk_config_evento (evento_id)
);

CREATE TABLE pago_evento (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    usuario_id VARCHAR(36) NOT NULL,
    evento_id VARCHAR(36) NOT NULL,
    monto DECIMAL(10,2) NOT NULL,
    metodo_pago VARCHAR(50),
    referencia_transaccion VARCHAR(150),
    estado ENUM(
        'PENDIENTE',
        'APROBADO',
        'RECHAZADO'
    ) NOT NULL,
    fecha_pago TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_pago_evento_usuario (usuario_id),
    INDEX idx_pago_evento_evento (evento_id)
);

CREATE TABLE comprobante_pago (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    pago_evento_id BIGINT NULL,
    pago_suscripcion_id BIGINT NULL,
    numero_comprobante VARCHAR(100) UNIQUE NOT NULL,
    url_pdf VARCHAR(500),
    fecha_generacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_comprobante_evento
    FOREIGN KEY (pago_evento_id)
    REFERENCES pago_evento(id),

    CONSTRAINT fk_comprobante_suscripcion
    FOREIGN KEY (pago_suscripcion_id)
    REFERENCES pago_suscripcion(id)
);

-- Plan gratuito básico (RF66)
INSERT INTO plan (nombre, descripcion, precio, limite_eventos_mes, porcentaje_comision, duracion_dias, activo, es_gratuito)
VALUES (
    'Básico Gratuito',
    'Plan gratuito inicial para organizadores nuevos. Funcionalidades y eventos limitados.',
    0.00,
    2,
    15.00,
    30,
    TRUE,
    TRUE
);

INSERT INTO beneficio_plan (plan_id, beneficio) VALUES
(1, 'Hasta 2 eventos por mes'),
(1, 'Comisión del 15% en eventos pagos'),
(1, 'Soporte por correo');

INSERT INTO plan (nombre, descripcion, precio, limite_eventos_mes, porcentaje_comision, duracion_dias, activo, es_gratuito)
VALUES (
    'Pro',
    'Plan para organizadores con mayor volumen de eventos.',
    49.99,
    20,
    10.00,
    30,
    TRUE,
    FALSE
),
(
    'Enterprise',
    'Plan ilimitado para organizaciones grandes.',
    149.99,
    999,
    5.00,
    30,
    TRUE,
    FALSE
);

INSERT INTO beneficio_plan (plan_id, beneficio) VALUES
(2, 'Hasta 20 eventos por mes'),
(2, 'Comisión del 10% en eventos pagos'),
(2, 'Reportes financieros básicos'),
(2, 'Soporte prioritario'),
(3, 'Eventos ilimitados'),
(3, 'Comisión del 5% en eventos pagos'),
(3, 'Reportes financieros avanzados'),
(3, 'Soporte dedicado');

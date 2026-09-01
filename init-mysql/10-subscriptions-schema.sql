-- Schema inklusport_subscriptions (RF54–RF68)
-- IDs de organizador/usuario/evento alineados con user_ms y sports_events_ms (UUID CHAR(36)).
-- No hay FK cruzadas entre microservicios: esas columnas son referencias lógicas.
-- Pasarela: Mercado Pago (Checkout Pro + webhooks). PAYMENT_GATEWAY_MODE=mock en local.

CREATE DATABASE IF NOT EXISTS inklusport_subscriptions
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;
USE inklusport_subscriptions;

SET NAMES utf8mb4;

-- ---------------------------------------------------------------------------
-- RF54 / RF64 / RF65 — Catálogo de planes
-- activo=FALSE oculta el plan a nuevos organizadores; las suscripciones ya
-- contratadas siguen usando el snapshot guardado en `suscripcion` hasta el
-- fin de ciclo (RF65).
-- ---------------------------------------------------------------------------
CREATE TABLE plan (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,
    precio DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    moneda CHAR(3) NOT NULL DEFAULT 'COP',
    limite_eventos_mes INT NULL COMMENT 'NULL = ilimitado',
    porcentaje_comision DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    duracion_dias INT NOT NULL DEFAULT 30,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    es_gratuito BOOLEAN NOT NULL DEFAULT FALSE,
    es_plan_inicial BOOLEAN NOT NULL DEFAULT FALSE COMMENT 'RF64: se asigna al registrar un organizador',
    plan_inicial_unico TINYINT GENERATED ALWAYS AS (IF(es_plan_inicial, 1, NULL)) STORED,
    fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    creado_por CHAR(36) NULL,
    actualizado_por CHAR(36) NULL,

    UNIQUE KEY uk_plan_nombre (nombre),
    UNIQUE KEY uk_plan_inicial (plan_inicial_unico),
    INDEX idx_plan_activo (activo),
    CONSTRAINT chk_plan_precio CHECK (precio >= 0),
    CONSTRAINT chk_plan_comision CHECK (porcentaje_comision >= 0 AND porcentaje_comision <= 100),
    CONSTRAINT chk_plan_duracion CHECK (duracion_dias > 0)
);

-- RF54: beneficios visibles en el catálogo
CREATE TABLE beneficio_plan (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    plan_id BIGINT NOT NULL,
    beneficio VARCHAR(255) NOT NULL,
    orden INT NOT NULL DEFAULT 0,

    CONSTRAINT fk_beneficio_plan
        FOREIGN KEY (plan_id) REFERENCES plan(id) ON DELETE CASCADE,
    INDEX idx_beneficio_plan (plan_id)
);

-- RF58 / RF54: funcionalidades y cupos extra del plan (además de eventos/mes)
CREATE TABLE funcionalidad_plan (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    plan_id BIGINT NOT NULL,
    codigo VARCHAR(50) NOT NULL COMMENT 'EVENTOS_PAGOS, REPORTES_FINANCIEROS, SOPORTE_PRIORITARIO, ...',
    nombre VARCHAR(100) NOT NULL,
    habilitada BOOLEAN NOT NULL DEFAULT TRUE,
    limite INT NULL COMMENT 'NULL = sin cupo numérico (flag on/off)',

    CONSTRAINT fk_funcionalidad_plan
        FOREIGN KEY (plan_id) REFERENCES plan(id) ON DELETE CASCADE,
    UNIQUE KEY uk_funcionalidad_plan (plan_id, codigo)
);

-- RF65: auditoría de cambios de catálogo (precio, límites, comisión, beneficios)
CREATE TABLE historial_plan (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    plan_id BIGINT NOT NULL,
    campo_modificado VARCHAR(80) NOT NULL,
    valor_anterior TEXT,
    valor_nuevo TEXT,
    modificado_por CHAR(36) NULL,
    fecha_modificacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_historial_plan
        FOREIGN KEY (plan_id) REFERENCES plan(id) ON DELETE CASCADE,
    INDEX idx_historial_plan (plan_id, fecha_modificacion)
);

-- ---------------------------------------------------------------------------
-- RF56 / RF57 / RF58 / RF59 / RF64 — Suscripción del organizador
-- Los campos *_aplicado congelan las condiciones del ciclo vigente (RF65).
-- ---------------------------------------------------------------------------
CREATE TABLE suscripcion (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    organizador_id VARCHAR(100) NOT NULL,
    plan_id BIGINT NOT NULL,

    precio_aplicado DECIMAL(12,2) NOT NULL,
    moneda CHAR(3) NOT NULL DEFAULT 'COP',
    limite_eventos_aplicado INT NULL,
    porcentaje_comision_aplicado DECIMAL(5,2) NOT NULL,
    duracion_dias_aplicada INT NOT NULL,

    fecha_inicio DATE NOT NULL,
    fecha_fin DATE NOT NULL,
    estado ENUM('ACTIVA', 'VENCIDA', 'CANCELADA', 'SUSPENDIDA') NOT NULL DEFAULT 'ACTIVA',

    eventos_creados_periodo INT NOT NULL DEFAULT 0,
    periodo_inicio DATE NOT NULL COMMENT 'Inicio del mes/ciclo de conteo de eventos (RF58)',

    renovacion_automatica BOOLEAN NOT NULL DEFAULT FALSE,
    origen ENUM('ASIGNACION_INICIAL', 'COMPRA', 'RENOVACION', 'CAMBIO_PLAN') NOT NULL DEFAULT 'COMPRA',

    fecha_cancelacion TIMESTAMP NULL,
    motivo_cancelacion VARCHAR(500) NULL,
    fecha_suspension TIMESTAMP NULL,
    motivo_suspension VARCHAR(500) NULL,
    fecha_ultima_renovacion DATE NULL,

    fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    CONSTRAINT fk_suscripcion_plan
        FOREIGN KEY (plan_id) REFERENCES plan(id),
    INDEX idx_suscripcion_organizador (organizador_id),
    INDEX idx_suscripcion_estado_fin (estado, fecha_fin),
    CONSTRAINT chk_suscripcion_fechas CHECK (fecha_fin >= fecha_inicio),
    CONSTRAINT chk_suscripcion_eventos CHECK (eventos_creados_periodo >= 0)
);

-- RF61: historial de altas, renovaciones, cambios de plan y estados
CREATE TABLE historial_suscripcion (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    suscripcion_id BIGINT NOT NULL,
    tipo_movimiento ENUM(
        'ASIGNACION_INICIAL',
        'CREACION',
        'RENOVACION',
        'CAMBIO_PLAN',
        'CANCELACION',
        'SUSPENSION',
        'REACTIVACION',
        'VENCIMIENTO'
    ) NOT NULL,
    plan_anterior_id BIGINT NULL,
    plan_nuevo_id BIGINT NULL,
    estado_anterior VARCHAR(20) NULL,
    estado_nuevo VARCHAR(20) NULL,
    fecha_fin_anterior DATE NULL,
    fecha_fin_nueva DATE NULL,
    monto DECIMAL(12,2) NULL,
    realizado_por CHAR(36) NULL COMMENT 'UUID del actor; NULL = sistema',
    notas VARCHAR(500) NULL,
    fecha_movimiento TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_historial_suscripcion
        FOREIGN KEY (suscripcion_id) REFERENCES suscripcion(id),
    CONSTRAINT fk_historial_plan_anterior
        FOREIGN KEY (plan_anterior_id) REFERENCES plan(id),
    CONSTRAINT fk_historial_plan_nuevo
        FOREIGN KEY (plan_nuevo_id) REFERENCES plan(id),
    INDEX idx_historial_suscripcion (suscripcion_id, fecha_movimiento)
);

-- ---------------------------------------------------------------------------
-- RF68 — Transacciones con la pasarela (Mercado Pago)
-- Una fila por intento de cobro: inscripción a evento o plan de organizador.
-- ---------------------------------------------------------------------------
CREATE TABLE transaccion_pasarela (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    pasarela ENUM('MERCADOPAGO', 'MOCK') NOT NULL DEFAULT 'MERCADOPAGO',
    tipo ENUM('INSCRIPCION_EVENTO', 'SUSCRIPCION_ORGANIZADOR') NOT NULL,

    preferencia_id VARCHAR(100) NULL COMMENT 'Preference.id de Checkout Pro',
    pago_externo_id VARCHAR(100) NULL COMMENT 'Payment.id de Mercado Pago',
    orden_externa_id VARCHAR(100) NULL COMMENT 'Merchant order id',
    referencia_externa VARCHAR(150) NULL COMMENT 'external_reference propia',

    estado_pasarela VARCHAR(50) NULL COMMENT 'approved, pending, rejected, refunded, cancelled, ...',
    detalle_estado VARCHAR(100) NULL COMMENT 'status_detail de Mercado Pago',
    metodo_pago VARCHAR(50) NULL COMMENT 'visa, master, pse, account_money, ...',
    tipo_pago VARCHAR(50) NULL COMMENT 'credit_card, debit_card, bank_transfer, ticket, ...',

    moneda CHAR(3) NOT NULL DEFAULT 'COP',
    monto DECIMAL(12,2) NOT NULL,
    url_checkout VARCHAR(500) NULL COMMENT 'init_point / sandbox_init_point',

    payload_creacion JSON NULL,
    payload_webhook JSON NULL,

    fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY uk_preferencia (pasarela, preferencia_id),
    UNIQUE KEY uk_pago_externo (pasarela, pago_externo_id),
    INDEX idx_referencia_externa (referencia_externa),
    INDEX idx_estado_pasarela (estado_pasarela),
    CONSTRAINT chk_transaccion_monto CHECK (monto >= 0)
);

-- RF68: bitácora de notificaciones IPN / webhooks (idempotencia)
CREATE TABLE webhook_pasarela (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    pasarela ENUM('MERCADOPAGO', 'MOCK') NOT NULL DEFAULT 'MERCADOPAGO',
    tipo_notificacion VARCHAR(80) NOT NULL COMMENT 'payment, merchant_order, plan, subscription, ...',
    id_externo VARCHAR(100) NULL,
    transaccion_id BIGINT NULL,
    payload JSON NOT NULL,
    firma_recibida VARCHAR(255) NULL,
    procesado BOOLEAN NOT NULL DEFAULT FALSE,
    resultado VARCHAR(500) NULL,
    fecha_recepcion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_proceso TIMESTAMP NULL,

    CONSTRAINT fk_webhook_transaccion
        FOREIGN KEY (transaccion_id) REFERENCES transaccion_pasarela(id),
    INDEX idx_webhook_externo (pasarela, id_externo),
    INDEX idx_webhook_pendiente (procesado, fecha_recepcion)
);

-- ---------------------------------------------------------------------------
-- RF56 / RF59 — Pagos de planes de organizador
-- ---------------------------------------------------------------------------
CREATE TABLE pago_suscripcion (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    suscripcion_id BIGINT NOT NULL,
    transaccion_id BIGINT NULL,
    tipo ENUM('NUEVA', 'RENOVACION', 'CAMBIO_PLAN') NOT NULL DEFAULT 'NUEVA',
    monto DECIMAL(12,2) NOT NULL,
    moneda CHAR(3) NOT NULL DEFAULT 'COP',
    metodo_pago VARCHAR(50) NULL,
    referencia_transaccion VARCHAR(150) NULL,
    estado ENUM('PENDIENTE', 'APROBADO', 'RECHAZADO', 'REEMBOLSADO', 'CANCELADO') NOT NULL DEFAULT 'PENDIENTE',
    fecha_pago TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_pago_suscripcion
        FOREIGN KEY (suscripcion_id) REFERENCES suscripcion(id),
    CONSTRAINT fk_pago_suscripcion_tx
        FOREIGN KEY (transaccion_id) REFERENCES transaccion_pasarela(id),
    INDEX idx_pago_suscripcion (suscripcion_id, estado),
    CONSTRAINT chk_pago_suscripcion_monto CHECK (monto >= 0)
);

-- ---------------------------------------------------------------------------
-- RF63 — Evento gratuito o pago (valor de inscripción)
-- ---------------------------------------------------------------------------
CREATE TABLE configuracion_evento_pago (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    evento_id CHAR(36) NOT NULL,
    organizador_id VARCHAR(100) NOT NULL,
    es_pago BOOLEAN NOT NULL DEFAULT FALSE,
    valor_inscripcion DECIMAL(12,2) NULL,
    moneda CHAR(3) NOT NULL DEFAULT 'COP',
    porcentaje_comision DECIMAL(5,2) NULL COMMENT 'Snapshot del plan del organizador al configurar',
    fecha_creacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    UNIQUE KEY uk_config_evento (evento_id),
    INDEX idx_config_organizador (organizador_id),
    CONSTRAINT chk_config_valor CHECK (
        (es_pago = FALSE AND (valor_inscripcion IS NULL OR valor_inscripcion = 0))
        OR (es_pago = TRUE AND valor_inscripcion IS NOT NULL AND valor_inscripcion > 0)
    )
);

-- ---------------------------------------------------------------------------
-- RF55 / RF66 — Inscripción pagada a un evento
-- inscripcion_id apunta a sports_events_ms.event_registration (referencia lógica).
-- ---------------------------------------------------------------------------
CREATE TABLE pago_evento (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    usuario_id VARCHAR(100) NOT NULL,
    evento_id CHAR(36) NOT NULL,
    organizador_id VARCHAR(100) NOT NULL,
    inscripcion_id CHAR(36) NULL,
    transaccion_id BIGINT NULL,

    nombre_evento VARCHAR(150) NULL COMMENT 'Snapshot para el historial del usuario (RF66)',
    monto DECIMAL(12,2) NOT NULL,
    moneda CHAR(3) NOT NULL DEFAULT 'COP',
    porcentaje_comision DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    comision_plataforma DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    monto_neto_organizador DECIMAL(12,2) NOT NULL DEFAULT 0.00,

    metodo_pago VARCHAR(50) NULL,
    referencia_transaccion VARCHAR(150) NULL,
    estado ENUM('PENDIENTE', 'APROBADO', 'RECHAZADO', 'REEMBOLSADO', 'CANCELADO') NOT NULL DEFAULT 'PENDIENTE',
    fecha_pago TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_pago_evento_tx
        FOREIGN KEY (transaccion_id) REFERENCES transaccion_pasarela(id),
    INDEX idx_pago_evento_usuario (usuario_id, fecha_pago),
    INDEX idx_pago_evento_evento (evento_id, estado),
    INDEX idx_pago_evento_organizador (organizador_id),
    CONSTRAINT chk_pago_evento_monto CHECK (monto >= 0)
);

-- ---------------------------------------------------------------------------
-- RF67 — Comprobante de pago e inscripción (PDF + envío por correo)
-- ---------------------------------------------------------------------------
CREATE TABLE comprobante_pago (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    pago_evento_id BIGINT NULL,
    pago_suscripcion_id BIGINT NULL,
    transaccion_id BIGINT NULL,

    numero_comprobante VARCHAR(100) NOT NULL,
    numero_transaccion VARCHAR(150) NULL,
    tipo ENUM('INSCRIPCION', 'SUSCRIPCION') NOT NULL,
    monto DECIMAL(12,2) NOT NULL,
    moneda CHAR(3) NOT NULL DEFAULT 'COP',

    detalle_evento VARCHAR(255) NULL,
    email_destino VARCHAR(150) NULL,
    email_enviado BOOLEAN NOT NULL DEFAULT FALSE,
    fecha_envio TIMESTAMP NULL,
    error_envio VARCHAR(500) NULL,
    url_pdf VARCHAR(500) NULL,

    fecha_generacion TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_comprobante_evento
        FOREIGN KEY (pago_evento_id) REFERENCES pago_evento(id),
    CONSTRAINT fk_comprobante_suscripcion
        FOREIGN KEY (pago_suscripcion_id) REFERENCES pago_suscripcion(id),
    CONSTRAINT fk_comprobante_tx
        FOREIGN KEY (transaccion_id) REFERENCES transaccion_pasarela(id),
    UNIQUE KEY uk_numero_comprobante (numero_comprobante),
    CONSTRAINT chk_comprobante_origen CHECK (
        (pago_evento_id IS NOT NULL AND pago_suscripcion_id IS NULL)
        OR (pago_evento_id IS NULL AND pago_suscripcion_id IS NOT NULL)
    )
);

-- ---------------------------------------------------------------------------
-- RF60 — Avisos de vencimiento (job del sistema)
-- ---------------------------------------------------------------------------
CREATE TABLE notificacion_vencimiento (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    suscripcion_id BIGINT NOT NULL,
    dias_antes INT NOT NULL,
    canal ENUM('EMAIL', 'IN_APP') NOT NULL DEFAULT 'EMAIL',
    estado ENUM('PENDIENTE', 'ENVIADA', 'FALLIDA') NOT NULL DEFAULT 'PENDIENTE',
    fecha_programada DATE NOT NULL,
    fecha_envio TIMESTAMP NULL,
    destinatario VARCHAR(150) NULL,
    error_envio VARCHAR(500) NULL,

    CONSTRAINT fk_notif_suscripcion
        FOREIGN KEY (suscripcion_id) REFERENCES suscripcion(id),
    UNIQUE KEY uk_notif_ciclo (suscripcion_id, dias_antes, fecha_programada),
    INDEX idx_notif_pendiente (estado, fecha_programada),
    CONSTRAINT chk_notif_dias CHECK (dias_antes > 0)
);

-- Parámetros del dominio (días de aviso, pasarela activa, etc.)
CREATE TABLE parametro_suscripciones (
    clave VARCHAR(100) PRIMARY KEY,
    valor VARCHAR(500) NOT NULL,
    descripcion VARCHAR(255),
    actualizado_en TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- ---------------------------------------------------------------------------
-- RF62 — Vistas de reportes financieros
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_ingresos_por_evento AS
SELECT
    pe.evento_id,
    pe.organizador_id,
    MAX(pe.nombre_evento) AS nombre_evento,
    COUNT(*) AS inscritos_pagos,
    SUM(pe.monto) AS ingresos_brutos,
    SUM(pe.comision_plataforma) AS comisiones,
    SUM(pe.monto_neto_organizador) AS ingresos_netos,
    pe.moneda
FROM pago_evento pe
WHERE pe.estado = 'APROBADO'
GROUP BY pe.evento_id, pe.organizador_id, pe.moneda;

CREATE OR REPLACE VIEW v_ingresos_suscripciones AS
SELECT
    s.organizador_id,
    s.plan_id,
    p.nombre AS plan_nombre,
    COUNT(*) AS pagos_aprobados,
    SUM(ps.monto) AS ingresos,
    ps.moneda
FROM pago_suscripcion ps
JOIN suscripcion s ON s.id = ps.suscripcion_id
JOIN plan p ON p.id = s.plan_id
WHERE ps.estado = 'APROBADO'
GROUP BY s.organizador_id, s.plan_id, p.nombre, ps.moneda;

CREATE OR REPLACE VIEW v_comisiones_plataforma AS
SELECT
    DATE(pe.fecha_pago) AS fecha,
    pe.organizador_id,
    pe.evento_id,
    SUM(pe.comision_plataforma) AS comision_eventos,
    COUNT(*) AS transacciones
FROM pago_evento pe
WHERE pe.estado = 'APROBADO'
GROUP BY DATE(pe.fecha_pago), pe.organizador_id, pe.evento_id;

-- ---------------------------------------------------------------------------
-- Datos iniciales
-- ---------------------------------------------------------------------------
INSERT INTO parametro_suscripciones (clave, valor, descripcion) VALUES
('dias_aviso_vencimiento', '7,3,1', 'Días antes del vencimiento para notificar (RF60)'),
('pasarela_activa', 'MERCADOPAGO', 'Pasarela de cobro (RF68). MOCK en desarrollo.'),
('moneda_default', 'COP', 'Moneda de cobro (Mercado Pago Colombia)'),
('renovacion_automatica_default', 'false', 'Valor inicial de renovación automática');

-- RF64: plan gratuito básico asignado a cada organizador nuevo
INSERT INTO plan (
    nombre, descripcion, precio, moneda, limite_eventos_mes,
    porcentaje_comision, duracion_dias, activo, es_gratuito, es_plan_inicial
) VALUES (
    'Básico Gratuito',
    'Plan inicial para organizadores nuevos. Eventos y funcionalidades limitados.',
    0.00, 'COP', 2, 15.00, 30, TRUE, TRUE, TRUE
);

INSERT INTO beneficio_plan (plan_id, beneficio, orden) VALUES
(1, 'Hasta 2 eventos por mes', 1),
(1, 'Comisión del 15% en eventos pagos', 2),
(1, 'Soporte por correo', 3);

INSERT INTO funcionalidad_plan (plan_id, codigo, nombre, habilitada, limite) VALUES
(1, 'EVENTOS_PAGOS', 'Crear eventos de pago', TRUE, NULL),
(1, 'REPORTES_FINANCIEROS', 'Reportes financieros detallados', FALSE, NULL),
(1, 'SOPORTE_PRIORITARIO', 'Soporte prioritario', FALSE, NULL);

INSERT INTO plan (
    nombre, descripcion, precio, moneda, limite_eventos_mes,
    porcentaje_comision, duracion_dias, activo, es_gratuito, es_plan_inicial
) VALUES
(
    'Pro',
    'Para organizadores con mayor volumen de eventos mensuales.',
    79900.00, 'COP', 20, 10.00, 30, TRUE, FALSE, FALSE
),
(
    'Enterprise',
    'Plan ilimitado para organizaciones con alto volumen.',
    249900.00, 'COP', NULL, 5.00, 30, TRUE, FALSE, FALSE
);

INSERT INTO beneficio_plan (plan_id, beneficio, orden) VALUES
(2, 'Hasta 20 eventos por mes', 1),
(2, 'Comisión del 10% en eventos pagos', 2),
(2, 'Reportes financieros básicos', 3),
(2, 'Soporte prioritario', 4),
(3, 'Eventos ilimitados', 1),
(3, 'Comisión del 5% en eventos pagos', 2),
(3, 'Reportes financieros avanzados', 3),
(3, 'Soporte dedicado', 4);

INSERT INTO funcionalidad_plan (plan_id, codigo, nombre, habilitada, limite) VALUES
(2, 'EVENTOS_PAGOS', 'Crear eventos de pago', TRUE, NULL),
(2, 'REPORTES_FINANCIEROS', 'Reportes financieros detallados', TRUE, NULL),
(2, 'SOPORTE_PRIORITARIO', 'Soporte prioritario', TRUE, NULL),
(3, 'EVENTOS_PAGOS', 'Crear eventos de pago', TRUE, NULL),
(3, 'REPORTES_FINANCIEROS', 'Reportes financieros detallados', TRUE, NULL),
(3, 'SOPORTE_PRIORITARIO', 'Soporte prioritario', TRUE, NULL);

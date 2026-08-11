CREATE DATABASE IF NOT EXISTS sports_events_ms;
USE sports_events_ms;

-- Sin esta declaración el cliente de MySQL interpreta el archivo como latin1 y
-- los acentos quedan doblemente codificados ("Fútbol" se guarda como "FÃºtbol").
SET NAMES utf8mb4;

-- 1. Tabla: deporte
CREATE TABLE sport (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    difficulty ENUM('bajo', 'medio', 'alto') DEFAULT 'medio',
    required_materials TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 2. Tabla: discapacidad
CREATE TABLE disability (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    category VARCHAR(50),
    is_active BOOLEAN DEFAULT TRUE
);

-- 3. Tabla: relación deporte-discapacidad
CREATE TABLE sport_disability (
    sport_id INT,
    disability_id INT,
    adaptations TEXT NOT NULL,
    PRIMARY KEY (sport_id, disability_id),
    FOREIGN KEY (sport_id) REFERENCES sport(id) ON DELETE CASCADE,
    FOREIGN KEY (disability_id) REFERENCES disability(id) ON DELETE CASCADE
);

-- 4. Tabla: evento
CREATE TABLE event (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    sport_id INT NOT NULL,
    name VARCHAR(150) NOT NULL,
    description TEXT,
    event_date DATE NOT NULL,
    event_time TIME NOT NULL,
    location VARCHAR(255),
    image_url VARCHAR(512),
    latitude DOUBLE,
    longitude DOUBLE,
    max_capacity INT NOT NULL,
    available_capacity INT NOT NULL,
    status ENUM('draft', 'active', 'cancelled', 'finished') DEFAULT 'draft',
    created_by CHAR(36),
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (sport_id) REFERENCES sport(id),
    INDEX idx_event_date (event_date),
    INDEX idx_event_status (status)
);

-- 5. Tabla: inscripciones
CREATE TABLE event_registration (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    user_id CHAR(36) NOT NULL,
    event_id CHAR(36) NOT NULL,
    registration_date DATETIME DEFAULT CURRENT_TIMESTAMP,
    attended BOOLEAN DEFAULT FALSE,
    waitlist_position INT,
    qr_code TEXT,
    FOREIGN KEY (event_id) REFERENCES event(id) ON DELETE CASCADE,
    INDEX idx_user_event (user_id, event_id)
);

-- 6. Tabla: asistencia
CREATE TABLE event_attendance (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    registration_id CHAR(36) NOT NULL,
    check_in_time DATETIME DEFAULT CURRENT_TIMESTAMP,
    check_in_method ENUM('qr', 'manual', 'admin') DEFAULT 'qr',
    verified_by CHAR(36),
    FOREIGN KEY (registration_id) REFERENCES event_registration(id)
);

-- 7. Tabla: lista de espera
CREATE TABLE waitlist (
    id CHAR(36) PRIMARY KEY DEFAULT (UUID()),
    user_id CHAR(36) NOT NULL,
    event_id CHAR(36) NOT NULL,
    requested_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    notified_at DATETIME,
    notified BOOLEAN DEFAULT FALSE,
    position INT,
    status ENUM('waiting', 'offered', 'accepted', 'expired') DEFAULT 'waiting',
    FOREIGN KEY (event_id) REFERENCES event(id) ON DELETE CASCADE,
    INDEX idx_event_position (event_id, position)
);

-- 8. Vista: calendario de eventos
CREATE VIEW event_calendar AS
SELECT 
    e.id AS event_id,
    e.name AS event_name,
    e.event_date,
    e.event_time,
    e.location,
    s.name AS sport_name,
    e.available_capacity,
    e.max_capacity
FROM event e
JOIN sport s ON e.sport_id = s.id
WHERE e.status = 'active'
ORDER BY e.event_date, e.event_time;

-- 9. Datos iniciales
INSERT INTO sport (name, description, difficulty) VALUES 
('Fútbol Sala', 'Deporte colectivo adaptado para espacios reducidos', 'medio'),
('Baloncesto en Silla', 'Baloncesto adaptado para silla de ruedas', 'alto'),
('Natación Adaptada', 'Natación con adaptaciones según discapacidad', 'medio');

INSERT INTO disability (name, description, category) VALUES 
('Discapacidad Visual', 'Pérdida parcial o total de visión', 'visual'),
('Discapacidad Física', 'Limitación en movilidad de brazos, piernas o tronco', 'fisica'),
('Discapacidad Auditiva', 'Pérdida parcial o total de audición', 'auditiva');

INSERT INTO sport_disability (sport_id, disability_id, adaptations) VALUES 
(1, 1, 'Balón sonoro, guías táctiles, comunicación verbal constante'),
(1, 3, 'Señales visuales del árbitro, sistema de luces'),
(2, 2, 'Silla de ruedas deportiva, cancha adaptada'),
(3, 1, 'Guías táctiles en bordes, cuerdas guía en carriles');

-- 10. Categorías de discapacidad y adaptaciones complementarias
INSERT IGNORE INTO disability (id, name, description, category) VALUES
(4, 'Discapacidad Intelectual', 'Limitación en funciones intelectuales y de aprendizaje', 'intelectual'),
(5, 'Discapacidad Múltiple', 'Combinación de dos o más discapacidades', 'multiple');

INSERT IGNORE INTO sport_disability (sport_id, disability_id, adaptations) VALUES
(1, 4, 'Reglas simplificadas, instrucciones cortas y apoyo visual con pictogramas'),
(2, 3, 'Señales visuales del entrenador, marcador luminoso y comunicación por gestos'),
(2, 5, 'Acompañante de apoyo individual, tiempos de juego reducidos y material adaptado'),
(3, 2, 'Entrada asistida con grúa o rampa, flotadores de apoyo y trabajo del tren superior'),
(3, 3, 'Señales visuales de salida y llegada, luces indicadoras en el borde de la piscina'),
(3, 4, 'Secuencia de pasos fija, demostración previa y acompañamiento dentro del agua');

-- 11. Eventos publicados, con fechas relativas para que siempre sean futuras
INSERT IGNORE INTO event
    (id, sport_id, name, description, event_date, event_time, location, max_capacity, available_capacity, status)
VALUES
('a0000001-0000-4000-8000-000000000001', 1,
 'Torneo Inclusivo de Fútbol Sala',
 'Torneo por equipos mixtos con balón sonoro, guías táctiles y señalización luminosa para el arbitraje. Acceso sin barreras y baños adaptados.',
 DATE_ADD(CURDATE(), INTERVAL 21 DAY), '10:00:00', 'Polideportivo Municipal El Salitre', 20, 14, 'active'),

('a0000001-0000-4000-8000-000000000002', 1,
 'Clínica de Iniciación en Fútbol Sala Adaptado',
 'Sesión formativa para nuevos participantes. Instrucciones cortas con apoyo visual y acompañamiento individual durante toda la actividad.',
 DATE_ADD(CURDATE(), INTERVAL 35 DAY), '09:00:00', 'Coliseo Cubierto La Aurora', 16, 16, 'active'),

('a0000001-0000-4000-8000-000000000003', 1,
 'Liga Abierta de Fútbol Sala Inclusivo',
 'Competencia por jornadas durante seis semanas. Arbitraje con señales visuales y balón sonoro disponible en todos los partidos.',
 DATE_ADD(CURDATE(), INTERVAL 70 DAY), '15:30:00', 'Complejo Deportivo Norte', 24, 8, 'active'),

('a0000002-0000-4000-8000-000000000001', 2,
 'Copa Nacional de Baloncesto en Silla',
 'Competencia oficial con cancha adaptada y préstamo de sillas deportivas. Marcador luminoso y comunicación por gestos con el equipo arbitral.',
 DATE_ADD(CURDATE(), INTERVAL 28 DAY), '11:00:00', 'Coliseo El Campín', 24, 6, 'active'),

('a0000002-0000-4000-8000-000000000002', 2,
 'Entrenamiento Abierto de Baloncesto en Silla',
 'Sesión abierta de técnica y desplazamiento. Se dispone de sillas deportivas de préstamo y apoyo individual para quien lo necesite.',
 DATE_ADD(CURDATE(), INTERVAL 14 DAY), '17:00:00', 'Centro Deportivo Sur', 12, 12, 'active'),

('a0000002-0000-4000-8000-000000000003', 2,
 'Torneo Amistoso de Baloncesto en Silla',
 'Encuentro amistoso entre clubes con tiempos de juego reducidos y acompañamiento para participantes con discapacidad múltiple.',
 DATE_ADD(CURDATE(), INTERVAL 56 DAY), '10:30:00', 'Polideportivo Parque Simón Bolívar', 20, 20, 'active'),

('a0000003-0000-4000-8000-000000000001', 3,
 'Encuentro de Natación Adaptada',
 'Pruebas por tramos cortos con cuerdas guía en los carriles, aviso táctil en los bordes y luces indicadoras de salida y llegada.',
 DATE_ADD(CURDATE(), INTERVAL 18 DAY), '08:00:00', 'Piscina Olímpica Distrital', 15, 5, 'active'),

('a0000003-0000-4000-8000-000000000002', 3,
 'Taller de Técnica en Natación Adaptada',
 'Trabajo de respiración y propulsión con acompañamiento dentro del agua. Entrada asistida con grúa y flotadores de apoyo disponibles.',
 DATE_ADD(CURDATE(), INTERVAL 42 DAY), '16:00:00', 'Piscina Cubierta Zona Occidente', 10, 10, 'active'),

('a0000003-0000-4000-8000-000000000003', 3,
 'Festival Acuático Inclusivo',
 'Jornada recreativa abierta a todas las categorías de discapacidad, con estaciones adaptadas y personal de apoyo en cada carril.',
 DATE_ADD(CURDATE(), INTERVAL 90 DAY), '09:30:00', 'Centro Acuático Nacional', 30, 30, 'active');
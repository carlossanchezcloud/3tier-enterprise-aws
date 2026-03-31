-- ============================================================
-- SALÓN DE BELLEZA — Schema MySQL 8.0
-- Ejecutar en RDS después de conectarse vía mysql client
-- ============================================================

-- UUID como VARCHAR(36) — MySQL 8.0 tiene UUID() nativo
-- DATETIME en lugar de TIMESTAMPTZ
-- DECIMAL en lugar de NUMERIC
-- Triggers con sintaxis MySQL (no plpgsql)
-- ENGINE=InnoDB para soporte de foreign keys y transacciones

-- ============================================================
-- TABLA: clientes
-- ============================================================
CREATE TABLE IF NOT EXISTS clientes (
    id          VARCHAR(36)   NOT NULL DEFAULT (UUID()),
    nombre      VARCHAR(100)  NOT NULL,
    apellido    VARCHAR(100)  NOT NULL,
    email       VARCHAR(150)  NOT NULL,
    telefono    VARCHAR(20)   DEFAULT NULL,
    created_at  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
                              ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    UNIQUE KEY uq_clientes_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- TABLA: servicios
-- ============================================================
CREATE TABLE IF NOT EXISTS servicios (
    id           VARCHAR(36)    NOT NULL DEFAULT (UUID()),
    nombre       VARCHAR(100)   NOT NULL,
    descripcion  TEXT           DEFAULT NULL,
    duracion_min INT            NOT NULL,
    precio       DECIMAL(10,2)  NOT NULL,
    activo       TINYINT(1)     NOT NULL DEFAULT 1,
    created_at   DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP
                                ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT chk_duracion CHECK (duracion_min > 0),
    CONSTRAINT chk_precio   CHECK (precio >= 0)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- TABLA: turnos
-- ============================================================
CREATE TABLE IF NOT EXISTS turnos (
    id           VARCHAR(36)  NOT NULL DEFAULT (UUID()),
    cliente_id   VARCHAR(36)  NOT NULL,
    servicio_id  VARCHAR(36)  NOT NULL,
    fecha_hora   DATETIME     NOT NULL,
    estado       ENUM('pendiente','confirmado','cancelado','completado')
                              NOT NULL DEFAULT 'pendiente',
    notas        TEXT         DEFAULT NULL,
    created_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at   DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP
                              ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    CONSTRAINT fk_turnos_cliente
        FOREIGN KEY (cliente_id)  REFERENCES clientes(id)  ON DELETE CASCADE,
    CONSTRAINT fk_turnos_servicio
        FOREIGN KEY (servicio_id) REFERENCES servicios(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
-- ÍNDICES para performance
-- ============================================================
CREATE INDEX idx_turnos_cliente    ON turnos(cliente_id);
CREATE INDEX idx_turnos_servicio   ON turnos(servicio_id);
CREATE INDEX idx_turnos_fecha_hora ON turnos(fecha_hora);
CREATE INDEX idx_turnos_estado     ON turnos(estado);

-- ============================================================
-- DATOS SEMILLA — servicios de ejemplo
-- ============================================================
INSERT INTO servicios (nombre, descripcion, duracion_min, precio) VALUES
    ('Corte de cabello',  'Corte y estilizado para dama o caballero', 30,  25000),
    ('Tinte completo',    'Aplicación de color con productos premium', 90,  85000),
    ('Manicure',          'Limpieza, forma y esmaltado de uñas',       45,  30000),
    ('Pedicure',          'Tratamiento completo de pies',              60,  40000),
    ('Alisado brasileño', 'Keratina + alisado con plancha',           120, 150000);
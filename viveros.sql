-- ============================================================================
-- UNIVERSIDAD DE LA LAGUNA
-- Grado en Ingeniería Informática
-- Administración y Diseño de Bases de Datos
-- Práctica: Modelo Relacional - Escenario Viveros (Tajinaste S.A.)
-- ============================================================================

-- 1. CREACIÓN DE LA BASE DE DATOS
DROP DATABASE IF EXISTS viveros;
CREATE DATABASE viveros;

\c viveros;

-- Limpieza previa de tablas por si se ejecuta sobre un esquema existente
DROP TABLE IF EXISTS contiene CASCADE;
DROP TABLE IF EXISTS pedido CASCADE;
DROP TABLE IF EXISTS bonificacion CASCADE;
DROP TABLE IF EXISTS cliente_tajinaste_plus CASCADE;
DROP TABLE IF EXISTS cliente CASCADE;
DROP TABLE IF EXISTS puesto CASCADE;
DROP TABLE IF EXISTS empleado CASCADE;
DROP TABLE IF EXISTS tarea CASCADE;
DROP TABLE IF EXISTS almacena CASCADE;
DROP TABLE IF EXISTS producto CASCADE;
DROP TABLE IF EXISTS zona CASCADE;
DROP TABLE IF EXISTS vivero CASCADE;

-- ============================================================================
-- 2. CREACIÓN DE TABLAS DEL MODELO RELACIONAL
-- ============================================================================

-- Tabla 1: VIVERO
CREATE TABLE vivero (
    id_vivero INT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    latitud DECIMAL(9,6) NOT NULL,
    longitud DECIMAL(9,6) NOT NULL,
    CONSTRAINT chk_vivero_latitud CHECK (latitud BETWEEN -90.0 AND 90.0),
    CONSTRAINT chk_vivero_longitud CHECK (longitud BETWEEN -180.0 AND 180.0),
    CONSTRAINT chk_vivero_nombre CHECK (LENGTH(TRIM(nombre)) > 0)
);

-- Tabla 2: ZONA (Entidad débil dependiente de VIVERO)
CREATE TABLE zona (
    id_vivero INT NOT NULL,
    id_zona INT NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    latitud DECIMAL(9,6) NOT NULL,
    longitud DECIMAL(9,6) NOT NULL,
    PRIMARY KEY (id_vivero, id_zona),
    CONSTRAINT fk_zona_vivero
        FOREIGN KEY (id_vivero)
        REFERENCES vivero(id_vivero)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT chk_zona_latitud CHECK (latitud BETWEEN -90.0 AND 90.0),
    CONSTRAINT chk_zona_longitud CHECK (longitud BETWEEN -180.0 AND 180.0)
);

-- Tabla 3: PRODUCTO
CREATE TABLE producto (
    codigo_prod INT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    precio DECIMAL(10,2) NOT NULL,
    CONSTRAINT chk_producto_precio CHECK (precio > 0)
);

-- Tabla 4: ALMACENA (Relación N:M entre ZONA y PRODUCTO)
CREATE TABLE almacena (
    id_vivero INT NOT NULL,
    id_zona INT NOT NULL,
    codigo_prod INT NOT NULL,
    cantidad INT NOT NULL DEFAULT 0,
    PRIMARY KEY (id_vivero, id_zona, codigo_prod),
    CONSTRAINT fk_almacena_zona
        FOREIGN KEY (id_vivero, id_zona)
        REFERENCES zona(id_vivero, id_zona)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_almacena_producto
        FOREIGN KEY (codigo_prod)
        REFERENCES producto(codigo_prod)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT chk_almacena_cantidad CHECK (cantidad >= 0)
);

-- Tabla 5: TAREA
CREATE TABLE tarea (
    nombre VARCHAR(100) PRIMARY KEY,
    descripcion TEXT NOT NULL,
    CONSTRAINT chk_tarea_nombre CHECK (LENGTH(TRIM(nombre)) > 0)
);

-- Tabla 6: EMPLEADO
CREATE TABLE empleado (
    dni VARCHAR(15) PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    apellidos VARCHAR(150) NOT NULL,
    CONSTRAINT chk_empleado_dni CHECK (dni ~ '^[0-9]{8}[A-Z]$')
);

-- Tabla 7: PUESTO (Histórico de puestos: relaciona EMPLEADO, TAREA y ZONA)
CREATE TABLE puesto (
    dni VARCHAR(15) NOT NULL,
    fecha_inicio DATE NOT NULL,
    nombre_tarea VARCHAR(100) NOT NULL DEFAULT 'Mantenimiento General',
    id_vivero INT NOT NULL,
    id_zona INT NOT NULL,
    tipo VARCHAR(50) NOT NULL,
    fecha_fin DATE NULL, -- Puede ser NULL si es el puesto actual del empleado
    PRIMARY KEY (dni, fecha_inicio),
    CONSTRAINT fk_puesto_empleado
        FOREIGN KEY (dni)
        REFERENCES empleado(dni)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_puesto_tarea
        FOREIGN KEY (nombre_tarea)
        REFERENCES tarea(nombre)
        ON DELETE SET DEFAULT
        ON UPDATE CASCADE,
    CONSTRAINT fk_puesto_zona
        FOREIGN KEY (id_vivero, id_zona)
        REFERENCES zona(id_vivero, id_zona)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT chk_puesto_fechas CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio)
);

-- Tabla 8: CLIENTE
CREATE TABLE cliente (
    id_cliente INT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    apellidos VARCHAR(150) NOT NULL
);

-- Tabla 9: CLIENTE_TAJINASTE_PLUS (Especialización de CLIENTE)
CREATE TABLE cliente_tajinaste_plus (
    id_cliente INT PRIMARY KEY,
    fecha_ingreso DATE NOT NULL DEFAULT CURRENT_DATE,
    CONSTRAINT fk_cliente_plus_cliente
        FOREIGN KEY (id_cliente)
        REFERENCES cliente(id_cliente)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

-- Tabla 10: BONIFICACION (Entidad débil dependiente de CLIENTE_TAJINASTE_PLUS)
CREATE TABLE bonificacion (
    id_cliente INT NOT NULL,
    tipo_bonificacion VARCHAR(50) NOT NULL,
    volumen_compra DECIMAL(10,2) NOT NULL,
    PRIMARY KEY (id_cliente, tipo_bonificacion),
    CONSTRAINT fk_bonificacion_cliente_plus
        FOREIGN KEY (id_cliente)
        REFERENCES cliente_tajinaste_plus(id_cliente)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT chk_bonificacion_volumen CHECK (volumen_compra >= 0)
);

-- Tabla 11: PEDIDO
-- El atributo 'importe' es un atributo derivado/calculado a partir de las líneas de 'contiene'.
-- Se mantiene actualizado automáticamente mediante un TRIGGER en PostgreSQL.
CREATE TABLE pedido (
    numero_pedido INT PRIMARY KEY,
    fecha DATE NOT NULL DEFAULT CURRENT_DATE,
    importe DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    dni_empleado VARCHAR(15) NULL,
    id_cliente INT NOT NULL,
    CONSTRAINT fk_pedido_empleado
        FOREIGN KEY (dni_empleado)
        REFERENCES empleado(dni)
        ON DELETE SET NULL
        ON UPDATE CASCADE,
    CONSTRAINT fk_pedido_cliente
        FOREIGN KEY (id_cliente)
        REFERENCES cliente(id_cliente)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT chk_pedido_importe CHECK (importe >= 0)
);

-- Tabla 12: CONTIENE (Relación N:M entre PEDIDO y PRODUCTO)
CREATE TABLE contiene (
    numero_pedido INT NOT NULL,
    codigo_prod INT NOT NULL,
    cantidad INT NOT NULL,
    precio DECIMAL(10,2) NOT NULL,
    subtotal DECIMAL(10,2) GENERATED ALWAYS AS (cantidad * precio) STORED, -- Atributo calculado por línea
    PRIMARY KEY (numero_pedido, codigo_prod),
    CONSTRAINT fk_contiene_pedido
        FOREIGN KEY (numero_pedido)
        REFERENCES pedido(numero_pedido)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_contiene_producto
        FOREIGN KEY (codigo_prod)
        REFERENCES producto(codigo_prod)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,
    CONSTRAINT chk_contiene_cantidad CHECK (cantidad > 0),
    CONSTRAINT chk_contiene_precio CHECK (precio > 0)
);

-- ============================================================================
-- 3. TRIGGER PARA ATRIBUTO DERIVADO (importe en PEDIDO)
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_actualizar_importe_pedido()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        UPDATE pedido
        SET importe = COALESCE((
            SELECT SUM(cantidad * precio)
            FROM contiene
            WHERE numero_pedido = OLD.numero_pedido
        ), 0.00)
        WHERE numero_pedido = OLD.numero_pedido;
        RETURN OLD;
    ELSE
        UPDATE pedido
        SET importe = COALESCE((
            SELECT SUM(cantidad * precio)
            FROM contiene
            WHERE numero_pedido = NEW.numero_pedido
        ), 0.00)
        WHERE numero_pedido = NEW.numero_pedido;
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_calcular_importe_pedido
AFTER INSERT OR UPDATE OR DELETE ON contiene
FOR EACH ROW
EXECUTE FUNCTION fn_actualizar_importe_pedido();

-- ============================================================================
-- 4. INSERCIÓN DE DATOS (Mínimo 5 filas por tabla)
-- ============================================================================

-- 4.1. VIVERO (5 filas)
INSERT INTO vivero (id_vivero, nombre, latitud, longitud) VALUES
(1, 'Vivero Tajinaste La Laguna', 28.487400, -16.315900),
(2, 'Vivero Tajinaste La Orotava', 28.390500, -16.523000),
(3, 'Vivero Tajinaste Santa Cruz', 28.463600, -16.251800),
(4, 'Vivero Tajinaste Adeje', 28.122700, -16.726000),
(5, 'Vivero Tajinaste Tegueste', 28.522200, -16.336400);

-- 4.2. ZONA (6 filas)
INSERT INTO zona (id_vivero, id_zona, nombre, latitud, longitud) VALUES
(1, 1, 'Zona Exterior Norte', 28.487500, -16.315800),
(1, 2, 'Almacén Central', 28.487300, -16.316000),
(2, 1, 'Invernadero Subtropical', 28.390600, -16.523100),
(3, 1, 'Exposición Decoración', 28.463700, -16.251900),
(4, 1, 'Zona Cactus y Suculentas', 28.122800, -16.726100),
(5, 1, 'Vivero Semillero', 28.522300, -16.336500);

-- 4.3. PRODUCTO (6 filas)
INSERT INTO producto (codigo_prod, nombre, precio) VALUES
(101, 'Tajinaste Rojo (Echium wildpretii)', 18.50),
(102, 'Drago Canario Joven', 45.00),
(103, 'Sustrato Universal Ecológico 20L', 9.95),
(104, 'Maceta Cerámica Terracota 30cm', 14.20),
(105, 'Fertilizante Orgánico Líquido 1L', 11.50),
(106, 'Palmera Canaria Maceta 50L', 65.00);

-- 4.4. ALMACENA (6 filas)
INSERT INTO almacena (id_vivero, id_zona, codigo_prod, cantidad) VALUES
(1, 1, 101, 50),
(1, 2, 103, 120),
(2, 1, 102, 25),
(3, 1, 104, 80),
(4, 1, 105, 60),
(5, 1, 106, 15);

-- 4.5. TAREA (6 filas, incluyendo la tarea por defecto)
INSERT INTO tarea (nombre, descripcion) VALUES
('Mantenimiento General', 'Tarea asignada por defecto para labores generales de vivero'),
('Riego y Abonado', 'Control de humedad, riego programado y aplicación de fertilizantes'),
('Atención al Cliente', 'Asesoramiento técnico en plantas y gestión de ventas en tienda'),
('Control de Stock', 'Inventario de productos en almacén y recepción de mercancía'),
('Poda y Trasplante', 'Mantenimiento sanitario de ejemplares y cambio de macetas'),
('Preparación de Pedidos', 'Embalaje y preparación de pedidos para clientes Tajinaste Plus');

-- 4.6. EMPLEADO (5 filas)
INSERT INTO empleado (dni, nombre, apellidos) VALUES
('43123456A', 'Carlos', 'Hernández Pérez'),
('43234567B', 'Laura', 'González Acosta'),
('43345678C', 'Miguel', 'Rodríguez Padrón'),
('43456789D', 'Sofía', 'Díaz Jorge'),
('43567890E', 'Javier', 'Martín León');

-- 4.7. PUESTO (6 filas: incluye puestos históricos con fecha_fin y actuales con NULL)
INSERT INTO puesto (dni, fecha_inicio, nombre_tarea, id_vivero, id_zona, tipo, fecha_fin) VALUES
('43123456A', '2025-01-10', 'Riego y Abonado', 1, 1, 'Operario Agrícola', '2025-06-30'),
('43123456A', '2025-07-01', 'Atención al Cliente', 1, 2, 'Vendedor Senior', NULL),
('43234567B', '2025-03-15', 'Control de Stock', 2, 1, 'Encargado Almacén', NULL),
('43345678C', '2025-05-01', 'Poda y Trasplante', 3, 1, 'Especialista Botánico', NULL),
('43456789D', '2025-09-01', 'Preparación de Pedidos', 4, 1, 'Gestor Comercial', NULL),
('43567890E', '2026-01-15', 'Atención al Cliente', 5, 1, 'Asesor Jardinería', NULL);

-- 4.8. CLIENTE (6 filas)
INSERT INTO cliente (id_cliente, nombre, apellidos) VALUES
(1, 'Elena', 'Morales Trujillo'),
(2, 'David', 'Cabrera Santos'),
(3, 'Lucía', 'Perdomo Armas'),
(4, 'Andrés', 'Betancor Reyes'),
(5, 'Marta', 'Expósito Bello'),
(6, 'Roberto', 'Navarro Gil');

-- 4.9. CLIENTE_TAJINASTE_PLUS (5 filas: subconjunto de CLIENTE)
INSERT INTO cliente_tajinaste_plus (id_cliente, fecha_ingreso) VALUES
(1, '2025-02-01'),
(2, '2025-04-12'),
(3, '2025-06-20'),
(4, '2025-11-05'),
(5, '2026-01-10');

-- 4.10. BONIFICACION (5 filas)
INSERT INTO bonificacion (id_cliente, tipo_bonificacion, volumen_compra) VALUES
(1, 'Descuento Oro 15%', 350.00),
(2, 'Descuento Plata 10%', 180.50),
(3, 'Vale Regalo Sustratos', 120.00),
(4, 'Envío Gratuito Mensual', 240.00),
(5, 'Descuento Bronce 5%', 95.00);

-- 4.11. PEDIDO (5 filas: el importe se inicializa a 0 y el trigger lo calcula al insertar en CONTIENE)
INSERT INTO pedido (numero_pedido, fecha, dni_empleado, id_cliente) VALUES
(1001, '2026-02-10', '43123456A', 1),
(1002, '2026-02-15', '43234567B', 2),
(1003, '2026-03-01', '43345678C', 3),
(1004, '2026-03-12', '43456789D', 4),
(1005, '2026-03-20', '43567890E', 5);

-- 4.12. CONTIENE (6 filas: disparan automáticamente el cálculo de 'importe' en PEDIDO)
INSERT INTO contiene (numero_pedido, codigo_prod, cantidad, precio) VALUES
(1001, 101, 2, 18.50),
(1001, 103, 3, 9.95),
(1002, 102, 1, 45.00),
(1003, 104, 4, 14.20),
(1004, 105, 2, 11.50),
(1005, 106, 1, 65.00);

-- ============================================================================
-- 5. CONSULTAS SELECT DE COMPROBACIÓN DE TODAS LAS TABLAS
-- ============================================================================

SELECT * FROM vivero;
SELECT * FROM zona;
SELECT * FROM producto;
SELECT * FROM almacena;
SELECT * FROM tarea;
SELECT * FROM empleado;
SELECT * FROM puesto;
SELECT * FROM cliente;
SELECT * FROM cliente_tajinaste_plus;
SELECT * FROM bonificacion;
SELECT * FROM pedido;
SELECT * FROM contiene;

-- ============================================================================
-- 6. EJEMPLOS REPRESENTATIVOS DE OPERACIONES DELETE
-- ============================================================================

-- Escenario 1: ON DELETE CASCADE en entidad débil (BONIFICACION al borrar CLIENTE_TAJINASTE_PLUS)
-- Al dar de baja al cliente 5 del programa Tajinaste Plus, se eliminan en cascada sus bonificaciones.
DELETE FROM cliente_tajinaste_plus WHERE id_cliente = 5;

-- Escenario 2: ON DELETE SET DEFAULT en PUESTO al eliminar una TAREA
-- Si se elimina la tarea 'Poda y Trasplante', los puestos asociados pasan a 'Mantenimiento General'.
DELETE FROM tarea WHERE nombre = 'Poda y Trasplante';

-- Escenario 3: ON DELETE SET NULL en PEDIDO al dar de baja a un EMPLEADO
-- Si se elimina al empleado '43567890E', sus pedidos gestionados no se pierden, sino que dni_empleado queda a NULL.
DELETE FROM empleado WHERE dni = '43567890E';

-- Escenario 4: Actualización automática del atributo derivado 'importe' al borrar una línea en CONTIENE
-- El pedido 1001 tiene dos líneas (2*18.50 + 3*9.95 = 66.85). Al borrar una línea, el importe pasa a 37.00.
DELETE FROM contiene WHERE numero_pedido = 1001 AND codigo_prod = 103;

-- Comprobación tras los DELETE
SELECT * FROM pedido WHERE numero_pedido IN (1001, 1005);
SELECT * FROM puesto WHERE dni = '43345678C';
SELECT * FROM bonificacion WHERE id_cliente = 5;

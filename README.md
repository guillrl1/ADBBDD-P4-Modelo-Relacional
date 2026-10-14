# Práctica: Modelo Entidad-Relación y Modelo Relacional - Escenario Viveros (Tajinaste S.A.)

**Universidad de La Laguna (ULL)**  
**Grado en Ingeniería Informática**  
**Asignatura:** Administración y Diseño de Bases de Datos (ADBD)  

---

## Archivos del Repositorio y Enlaces Rápidos

* **Modelo Entidad-Relación:**
  * [Diagrama E/R editable (`ejercicio3_entidad_relacion.drawio`)](https://github.com/guillrl1/ADBBDD-P4-Modelo-Relacional/blob/main/ejercicio3_entidad_relacion.drawio)
  * [Imagen del Modelo E/R (`ejercicio3_entidad_relacion.drawio.png`)](https://github.com/guillrl1/ADBBDD-P4-Modelo-Relacional/blob/main/ejercicio3_entidad_relacion.png)
* **Modelo Relacional:**
  * [Imagen del Modelo Relacional (`modelo_relacional_viveros.png`)](https://github.com/guillrl1/ADBBDD-P4-Modelo-Relacional/blob/main/modelo_relacional_viveros.drawio.png)
* **Implementación en PostgreSQL:**
  * [Script SQL (`viveros.sql`)](https://github.com/guillrl1/ADBBDD-P4-Modelo-Relacional/blob/main/viveros.sql)

---

## 1. Modelo Entidad-Relación (Conceptual)

### Vista Previa del Diagrama E/R
![Modelo Entidad-Relación Viveros](https://github.com/guillrl1/ADBBDD-P4-Modelo-Relacional/blob/main/ejercicio3_entidad_relacion.png)


## 2. Modelo Relacional 

### Esquema Relacional Resultante
![Modelo Relacional Crow's Foot](https://github.com/guillrl1/ADBBDD-P4-Modelo-Relacional/blob/main/modelo_relacional_viveros.drawio.png)

### 2.1. Esquema Relacional Resultante
A partir del modelo Entidad-Relación se obtienen las siguientes **12 relaciones (tablas)**:

1. **`VIVERO`** (`id_vivero` [PK], `nombre`, `latitud`, `longitud`)
2. **`ZONA`** (`id_vivero` [PK, FK -> VIVERO], `id_zona` [PK], `nombre`, `latitud`, `longitud`)
3. **`PRODUCTO`** (`codigo_prod` [PK], `nombre`, `precio`)
4. **`ALMACENA`** (`id_vivero` [PK, FK -> ZONA], `id_zona` [PK, FK -> ZONA], `codigo_prod` [PK, FK -> PRODUCTO], `cantidad`)
5. **`TAREA`** (`nombre` [PK], `descripcion`)
6. **`EMPLEADO`** (`dni` [PK], `nombre`, `apellidos`)
7. **`PUESTO`** (`dni` [PK, FK -> EMPLEADO], `fecha_inicio` [PK], `nombre_tarea` [FK -> TAREA], `id_vivero` [FK -> ZONA], `id_zona` [FK -> ZONA], `tipo`, `fecha_fin`)
8. **`CLIENTE`** (`id_cliente` [PK], `nombre`, `apellidos`)
9. **`CLIENTE_TAJINASTE_PLUS`** (`id_cliente` [PK, FK -> CLIENTE], `fecha_ingreso`)
10. **`BONIFICACION`** (`id_cliente` [PK, FK -> CLIENTE_TAJINASTE_PLUS], `tipo_bonificacion` [PK], `volumen_compra`)
11. **`PEDIDO`** (`numero_pedido` [PK], `fecha`, `/importe` [Derivado], `dni_empleado` [FK -> EMPLEADO], `id_cliente` [FK -> CLIENTE])
12. **`CONTIENE`** (`numero_pedido` [PK, FK -> PEDIDO], `codigo_prod` [PK, FK -> PRODUCTO], `cantidad`, `precio`, `/subtotal` [Calculado])

---

## 3. Decisiones de Implementación en PostgreSQL (`viveros.sql`)

* **Restricciones de Dominio (`CHECK`)**:
  * Validación de coordenadas geográficas en `vivero` y `zona` (`latitud BETWEEN -90.0 AND 90.0` y `longitud BETWEEN -180.0 AND 180.0`).
  * Validación de formato de DNI en `empleado` mediante expresión regular (`dni ~ '^[0-9]{8}[A-Z]$'`).
  * Control de valores positivos en precios, cantidades, volúmenes de compra e importes.
  * Coherencia temporal en `puesto` (`fecha_fin IS NULL OR fecha_fin >= fecha_inicio`).
* **Políticas de Integridad Referencial (`ON DELETE` / `ON UPDATE`)**:
  * **`ON DELETE CASCADE`**: Aplicado en entidades débiles (`zona`, `bonificacion`), jerarquía (`cliente_tajinaste_plus`) y tablas de detalle/intermedias (`almacena`, `contiene`, `puesto` respecto al empleado/zona).
  * **`ON DELETE SET DEFAULT`**: Aplicado en `puesto(nombre_tarea)` para que, si se elimina una tarea del catálogo, los registros históricos pasen a `'Mantenimiento General'`.
  * **`ON DELETE SET NULL`**: Aplicado en `pedido(dni_empleado)` para conservar el historial de facturación de pedidos aunque un empleado cause baja en la empresa.
  * **`ON DELETE RESTRICT`**: Aplicado en `contiene(codigo_prod)` para impedir el borrado accidental de productos que ya figuran en líneas de pedidos.
* **Atributos Derivados / Calculados**:
  * En `contiene`, el atributo `subtotal` se define como columna generada almacenada (`GENERATED ALWAYS AS (cantidad * precio) STORED`).
  * En `pedido`, el atributo derivado `importe` se mantiene actualizado automáticamente mediante el trigger `trg_calcular_importe_pedido` (`AFTER INSERT OR UPDATE OR DELETE ON contiene`), que recalcula la suma de `cantidad * precio` de todas las líneas asociadas al pedido.

---

## 4. Comprobación y Salida de Consultas (`SELECT`)

Tras la ejecución completa del script [`viveros.sql`](https://github.com/guillrl1/ADBBDD-P4-Modelo-Relacional/blob/main/viveros.sql) (incluyendo las inserciones iniciales y las 4 operaciones `DELETE` de prueba al final del fichero), se verifican todas las tablas de la base de datos mediante **3 consultas con `JOIN`** que agrupan los tres bloques funcionales del sistema:

### 4.1. Bloque 1: Stock e Inventario (`VIVERO` + `ZONA` + `ALMACENA` + `PRODUCTO`)

```sql
SELECT 
    v.id_vivero, v.nombre AS vivero,
    z.id_zona, z.nombre AS zona,
    p.codigo_prod, p.nombre AS producto, p.precio,
    a.cantidad AS stock_disponible
FROM vivero v
JOIN zona z ON v.id_vivero = z.id_vivero
JOIN almacena a ON z.id_vivero = a.id_vivero AND z.id_zona = a.id_zona
JOIN producto p ON a.codigo_prod = p.codigo_prod;
```

**Salida obtenida:**
```text
 id_vivero |           vivero            | id_zona |           zona           | codigo_prod |              producto              | precio | stock_disponible
-----------+-----------------------------+---------+--------------------------+-------------+------------------------------------+--------+------------------
         1 | Vivero Tajinaste La Laguna  |       1 | Zona Exterior Norte      |         101 | Tajinaste Rojo (Echium wildpretii) |  18.50 |               50
         1 | Vivero Tajinaste La Laguna  |       2 | Almacén Central          |         103 | Sustrato Universal Ecológico 20L   |   9.95 |              120
         2 | Vivero Tajinaste La Orotava |       1 | Invernadero Subtropical  |         102 | Drago Canario Joven                |  45.00 |               25
         3 | Vivero Tajinaste Santa Cruz |       1 | Exposición Decoración    |         104 | Maceta Cerámica Terracota 30cm     |  14.20 |               80
         4 | Vivero Tajinaste Adeje      |       1 | Zona Cactus y Suculentas |         105 | Fertilizante Orgánico Líquido 1L   |  11.50 |               60
         5 | Vivero Tajinaste Tegueste   |       1 | Vivero Semillero         |         106 | Palmera Canaria Maceta 50L         |  65.00 |               15
(6 rows)
```

---

### 4.2. Puestos (`EMPLEADO` + `PUESTO` + `TAREA` + `ZONA` + `VIVERO`)

```sql
SELECT 
    e.dni, e.nombre || ' ' || e.apellidos AS empleado,
    pu.tipo AS puesto, pu.fecha_inicio, pu.fecha_fin,
    t.nombre AS tarea,
    v.nombre AS vivero, z.nombre AS zona
FROM puesto pu
JOIN empleado e ON pu.dni = e.dni
RIGHT JOIN tarea t ON pu.nombre_tarea = t.nombre
LEFT JOIN zona z ON pu.id_vivero = z.id_vivero AND pu.id_zona = z.id_zona
LEFT JOIN vivero v ON z.id_vivero = v.id_vivero;
```

**Salida obtenida:**
* Se observa cómo el empleado `43345678C` (Miguel Rodríguez Padrón), que tenía asignada la tarea `'Poda y Trasplante'`, ha pasado automáticamente a `'Mantenimiento General'` gracias a la restricción **`ON DELETE SET DEFAULT`**.
* El puesto del empleado `43567890E` se eliminó automáticamente por **`ON DELETE CASCADE`** al dar de baja a dicho empleado en la sección de pruebas de borrado.

```text
    dni    |        empleado         |        puesto         | fecha_inicio | fecha_fin  |         tarea          |           vivero            |           zona
-----------+-------------------------+-----------------------+--------------+------------+------------------------+-----------------------------+--------------------------
 43123456A | Carlos Hernández Pérez  | Operario Agrícola     | 2025-01-10   | 2025-06-30 | Riego y Abonado        | Vivero Tajinaste La Laguna  | Zona Exterior Norte
 43123456A | Carlos Hernández Pérez  | Vendedor Senior       | 2025-07-01   |            | Atención al Cliente    | Vivero Tajinaste La Laguna  | Almacén Central
 43234567B | Laura González Acosta   | Encargado Almacén     | 2025-03-15   |            | Control de Stock       | Vivero Tajinaste La Orotava | Invernadero Subtropical
 43345678C | Miguel Rodríguez Padrón | Especialista Botánico | 2025-05-01   |            | Mantenimiento General  | Vivero Tajinaste Santa Cruz | Exposición Decoración
 43456789D | Sofía Díaz Jorge        | Gestor Comercial      | 2025-09-01   |            | Preparación de Pedidos | Vivero Tajinaste Adeje      | Zona Cactus y Suculentas
(5 rows)
```

---

### 4.3. Programa de Fidelización y Bonificaciones

```sql
SELECT 
    c.id_cliente, c.nombre || ' ' || c.apellidos AS cliente,
    ctp.fecha_ingreso AS alta_plus,
    b.tipo_bonificacion, b.volumen_compra
FROM cliente c
LEFT JOIN cliente_tajinaste_plus ctp ON c.id_cliente = ctp.id_cliente
LEFT JOIN bonificacion b ON ctp.id_cliente = b.id_cliente
ORDER BY c.id_cliente;
```

```text
id_cliente |        cliente         | alta_plus  |   tipo_bonificacion    | volumen_compra
------------+------------------------+------------+------------------------+----------------
          1 | Elena Morales Trujillo | 2025-02-01 | Descuento Oro 15%      |         350.00
          2 | David Cabrera Santos   | 2025-04-12 | Descuento Plata 10%    |         180.50
          3 | Lucía Perdomo Armas    | 2025-06-20 | Vale Regalo Sustratos  |         120.00
          4 | Andrés Betancor Reyes  | 2025-11-05 | Envío Gratuito Mensual |         240.00
          5 | Marta Expósito Bello   |            |                        |               
          6 | Roberto Navarro Gil    |            |                        |               
(6 rows)
```
### 4.4. Pedidos y Detalle de Ventas (PEDIDO + CLIENTE + CONTIENE + PRODUCTO)

```sql
SELECT 
    pe.numero_pedido, pe.fecha AS fecha_pedido,
    c.nombre || ' ' || c.apellidos AS cliente,
    pe.dni_empleado,
    pr.nombre AS producto_comprado,
    co.cantidad, co.precio AS precio_ud, co.subtotal,
    pe.importe AS total_pedido_calculado
FROM pedido pe
JOIN cliente c ON pe.id_cliente = c.id_cliente
JOIN contiene co ON pe.numero_pedido = co.numero_pedido
JOIN producto pr ON co.codigo_prod = pr.codigo_prod
ORDER BY pe.numero_pedido;
```

```text
numero_pedido | fecha_pedido |        cliente         | dni_empleado |         producto_comprado          | cantidad | precio_ud | subtotal | total_pedido_calculado
---------------+--------------+------------------------+--------------+------------------------------------+----------+-----------+----------+------------------------
          1001 | 2026-02-10   | Elena Morales Trujillo | 43123456A    | Tajinaste Rojo (Echium wildpretii) |        2 |     18.50 |    37.00 |                  37.00
          1002 | 2026-02-15   | David Cabrera Santos   | 43234567B    | Drago Canario Joven                |        1 |     45.00 |    45.00 |                  45.00
          1003 | 2026-03-01   | Lucía Perdomo Armas    | 43345678C    | Maceta Cerámica Terracota 30cm     |        4 |     14.20 |    56.80 |                  56.80
          1004 | 2026-03-12   | Andrés Betancor Reyes  | 43456789D    | Fertilizante Orgánico Líquido 1L   |        2 |     11.50 |    23.00 |                  23.00
          1005 | 2026-03-20   | Marta Expósito Bello   |              | Palmera Canaria Maceta 50L         |        1 |     65.00 |    65.00 |                  65.00
(5 rows)
```



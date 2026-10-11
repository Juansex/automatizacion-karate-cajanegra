# Requisitos de los ejercicios

Fuentes:
- Enunciados funcionales del *Taller de Técnicas de Prueba de Caja Negra – Parte 2* (texto entregado por el estudiante).
- `Archivos de apoyo/DocumentaciónTecnica_APIs_pruebas_de_caja_negra (1).md`, secciones 1.4 y 2.2.
- `Archivos de apoyo/ColeccionPostman_APIs_cajaNegra (1).json`, carpetas con los mismos nombres.

Formato del ID de requisito: `REQ-<EJERCICIO>-<NN>`, con `ILU` = Iluminación y `CLI` = Climatización.
**Supuesto:** la guía pide tags de requisito, pero no define su formato.

---

## Bloque 1 · Transición de Estados: Sistema de Iluminación Inteligente en Auditorio Teatral

### Estados y eventos

| Estado | Nombre |
|---|---|
| S1 | Apagado Total (estado inicial) |
| S2 | Luces de Cortesía |
| S3 | Iluminación de Ensayo |
| S4 | Escena en Vivo |
| S5 | Modo Emergencia |

Los eventos se envían en el body de la petición, con el texto **literal** de la documentación de la API:
`"Encender"`, `"Iniciar Show"`, `"Alarma de Humo"` y `"Fin Emergencia / Reset"`.

### Endpoints (documentación técnica, sección 1.4)

| Acción | Método | Path | Body |
|---|---|---|---|
| Ver estado actual | GET | `/api/iluminacion-teatro/estado` | — |
| Enviar evento | POST | `/api/iluminacion-teatro/evento` | `{ "evento": "<evento>" }` |
| Reiniciar | POST | `/api/iluminacion-teatro/reiniciar` | — |

### Requisitos

| ID | Regla del enunciado | Requisito |
|---|---|---|
| REQ-ILU-01 | "Inicia en S1" | El sistema arranca en S1. El endpoint de reinicio lo devuelve a S1. |
| REQ-ILU-02 | a | Desde S1, el evento Encender lleva a S2. |
| REQ-ILU-03 | b | Iniciar Show hace avanzar el show: S2 → S3 y S3 → S4. |
| REQ-ILU-04 | c | Alarma de Humo tiene prioridad absoluta: desde S1, S2, S3 o S4 lleva a S5. |
| REQ-ILU-05 | d | Desde S5, Fin Emergencia / Reset lleva **siempre** a S1, sin importar en qué estado estaba antes de la alarma. |
| REQ-ILU-06 | b | El show no retrocede y no se inicia fuera de S2/S3: Iniciar Show desde S1 o S4 es una transición no definida y el estado no cambia. |
| REQ-ILU-07 | d | En S5 el único evento válido es Reset. Alarma de Humo en S5 no tiene efecto, y Encender o Iniciar Show en S5 tampoco cambian el estado. |
| REQ-ILU-08 | matriz (celdas no definidas en a–d) | Encender fuera de S1 y Reset fuera de S5 son transiciones no definidas: el estado no cambia. |
| REQ-ILU-09 | robustez de la API | Un evento que no pertenece a la máquina (p. ej. `Apagar`, `encender` en minúscula) se rechaza con 400 y el estado no cambia. |

> **Retroceso S4 → S3 y S3 → S2:** la API no tiene ningún evento de retroceso, así que no se puede enviar.
> Se prueba de forma indirecta: Iniciar Show desde S4 no debe cambiar el estado (REQ-ILU-06).

### Matriz completa de transiciones (5 estados × 4 eventos = 20 celdas)

| Estado \ Evento | Encender | Iniciar Show | Alarma de Humo | Fin Emergencia / Reset |
|---|---|---|---|---|
| **S1** | ✅ → S2 (ILU-02) | ❌ (ILU-06) | ✅ → S5 (ILU-04) | ❌ (ILU-08) |
| **S2** | ❌ (ILU-08) | ✅ → S3 (ILU-03) | ✅ → S5 (ILU-04) | ❌ (ILU-08) |
| **S3** | ❌ (ILU-08) | ✅ → S4 (ILU-03) | ✅ → S5 (ILU-04) | ❌ (ILU-08) |
| **S4** | ❌ (ILU-08) | ❌ (ILU-06) | ✅ → S5 (ILU-04) | ❌ (ILU-08) |
| **S5** | ❌ (ILU-07) | ❌ (ILU-07) | ❌ sin efecto (ILU-07) | ✅ → S1 (ILU-05) |

- **8 transiciones válidas:** S1-Encender, S2-Iniciar Show, S3-Iniciar Show, Alarma desde S1, S2, S3 y S4, y S5-Reset.
- **12 transiciones inválidas:** las otras 12 celdas. El diseño de casos las cubre **todas**.

Para las inválidas, el enunciado solo dice que la transición "no está definida". No define ningún código HTTP.
Lo único documentado y verificable es que **el estado no cambia**. El código exacto se tomará de la observación real (Fase 2).

---

## Bloque 2 · Tablas de Decisión: Controlador de Climatización Inteligente en una Smart Home

### Condiciones

| Nº | Condición |
|---|---|
| C1 | La temperatura interior es superior a 26 °C. |
| C2 | Hay presencia humana activa en la habitación (sensores de movimiento). |
| C3 | Puertas o ventanas principales abiertas por más de 3 minutos. |

**Orden supuesto del arreglo `valores` = [C1, C2, C3].** Se deduce de la colección: la Regla 1 (ventanas abiertas) usa `[false,false,true]`. Confirmado con `GET /definicion` (ver `HALLAZGOS_API.md`).

### Endpoints (documentación técnica, sección 2.2)

| Acción | Método | Path | Body |
|---|---|---|---|
| Ver definición (condiciones + historial) | GET | `/api/decision/climatizacion/definicion` | — |
| Evaluar | POST | `/api/decision/climatizacion/evaluar` | `{ "valores": [C1, C2, C3] }` |
| Reiniciar historial | POST | `/api/decision/climatizacion/reiniciar` | — |

### Requisitos (reglas)

| ID | Regla API | Condiciones | Acción esperada (texto del enunciado y de la API) |
|---|---|---|---|
| REQ-CLI-01 | Regla 1 | C3 = V (C1 y C2 cualquiera) | Apagar sistema de climatización y emitir alerta sonora |
| REQ-CLI-02 | Regla 2 | C1 = V, C2 = V, C3 = F | Encender aire acondicionado en modo refrigeración |
| REQ-CLI-03 | Regla 3 | C1 = V, C2 = F, C3 = F | Mantener en modo de bajo consumo energético |
| REQ-CLI-04 | Regla 4 | C1 = F, C3 = F (C2 cualquiera) | Mantener sistema apagado |
| REQ-CLI-05 | Validación de entrada | `valores` sin exactamente 3 elementos | HTTP 400 `Se esperaban 3 valores booleanos` y no se registra en el historial |

### Tabla de decisión completa (8 combinaciones → 4 reglas)

| # | C1 Temp > 26 | C2 Presencia | C3 Ventanas abiertas | Regla | Requisito |
|---|---|---|---|---|---|
| 1 | V | V | V | R1 | REQ-CLI-01 |
| 2 | V | F | V | R1 | REQ-CLI-01 |
| 3 | F | V | V | R1 | REQ-CLI-01 |
| 4 | F | F | V | R1 | REQ-CLI-01 |
| 5 | V | V | F | R2 | REQ-CLI-02 |
| 6 | V | F | F | R3 | REQ-CLI-03 |
| 7 | F | V | F | R4 | REQ-CLI-04 |
| 8 | F | F | F | R4 | REQ-CLI-04 |

La API documenta exactamente 4 reglas, con los mismos nombres de acción que el enunciado, así que la cantidad coincide.
Los textos exactos de la respuesta (campo de la acción, número de regla) se confirmarán en la Fase 2.

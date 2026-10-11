# Hallazgos de la exploración de la API

- **Fecha:** 2026-10-08.
- **Herramienta:** `curl`, contra `https://taller-de-tecnicas-de-prueba-de-caja.onrender.com/api`.
- **Alcance:** solo los endpoints de los dos ejercicios elegidos.

## Configuración y tiempos

- `src/test/resources/karate-config.js`, de la profesora, **no define `baseUrl` ni timeouts**: solo configura los logs (`logPrettyRequest` y `logPrettyResponse`).
  Por eso la `baseUrl` se declara en el `Background` de cada feature y el config se deja sin cambios.
- **Arranque en frío de Render:** la primera petición tardó **22,6 s**. Las siguientes tardaron entre 0,2 y 0,4 s.
  Un timeout de 5000 ms (el que aparece en la guía de Karate) **no sería suficiente** para la primera petición.
  Karate usa por defecto 30 s de connect y 30 s de read, que sí alcanza.

---

## Iluminación Teatral (`/api/iluminacion-teatro`)

### GET `/estado` → HTTP 200
```json
{"estadoActual":"S1 (Apagado Total)","historial":[],
 "maquina":{"nombre":"Sistema de Iluminación Inteligente en Auditorio Teatral",
  "estados":["S1 (Apagado Total)","S2 (Luces de Cortesía)","S3 (Iluminación de Ensayo)","S4 (Escena en Vivo)","S5 (Modo Emergencia)"],
  "eventos":["Encender","Iniciar Show","Alarma de Humo","Fin Emergencia / Reset"],"guardias":{}}}
```

### POST `/reiniciar` (sin body) → HTTP 200
```json
{"estadoActual":"S1 (Apagado Total)"}
```
El reinicio deja el sistema en **S1** y **vacía el historial**.

### POST `/evento` con body `{"evento":"<evento>"}`: todas las celdas observadas

Forma de la respuesta:
- **Transición válida:** `{estadoAnterior, evento, guardia:null, estadoNuevo, valida:true, accion}`.
- **Transición inválida:** `{estadoAnterior, evento, guardia:null, estadoNuevo (= estadoAnterior), valida:false, noDefinida:true}`.

| Estado previo | Evento | HTTP | estadoNuevo | valida | noDefinida | accion |
|---|---|---|---|---|---|---|
| S1 | Iniciar Show | 200 | S1 | false | true | — |
| S1 | Fin Emergencia / Reset | 200 | S1 | false | true | — |
| S1 | Encender | 200 | **S2** | true | — | null |
| S2 | Encender | 200 | S2 | false | true | — |
| S2 | Fin Emergencia / Reset | 200 | S2 | false | true | — |
| S2 | Iniciar Show | 200 | **S3** | true | — | null |
| S3 | Encender | 200 | S3 | false | true | — |
| S3 | Iniciar Show | 200 | **S4** | true | — | null |
| S4 | Iniciar Show | 200 | S4 | false | true | — |
| S4 | Fin Emergencia / Reset | 200 | S4 | false | true | — |
| S4 | Encender | 200 | S4 | false | true | — |
| S4 | Alarma de Humo | 200 | **S5** | true | — | "Override absoluto" |
| S5 | Alarma de Humo | 200 | S5 | false | true | — |
| S5 | Encender | 200 | S5 | false | true | — |
| S5 | Iniciar Show | 200 | S5 | false | true | — |
| S5 | Fin Emergencia / Reset | 200 | **S1** | true | — | "Reset total" |
| S1 | Alarma de Humo | 200 | **S5** | true | — | "Override absoluto" |
| (cualquiera) | "Inexistente" | **400** | — | — | — | `{"error":"Evento desconocido: Inexistente"}` |

Después de cada evento inválido, `GET /estado` confirmó que el estado **no cambió**. El historial registra cada intento.
Las celdas S2-Alarma, S3-Alarma y S3-Reset, y el Reset tras una alarma desde S2/S3, no se exploraron con curl para no hacer llamadas de más. **Quedaron verificadas en la ejecución Karate** (Issues #5, #6 y #9, todas aprobadas), con el mismo patrón de respuesta.

**Conclusión:** el comportamiento coincide con el enunciado (reglas a–d).
- Una transición no definida **no se rechaza con un código 4xx**: la API responde 200 con `valida:false`, `noDefinida:true` y el estado sin cambios.
- El enunciado no define el código HTTP, y la guía admite "ignorar el comando o mostrar una alerta de acción inválida".
- Por eso **no se considera defecto**. Las pruebas validan el código observado (200), los flags `valida` y `noDefinida`, y que el estado no cambie.

---

## Climatización Smart Home (`/api/decision/climatizacion`)

### POST `/reiniciar` → HTTP 200
```json
{"ok":true}
```
Vacía el historial: un `GET /definicion` posterior devuelve `historial: []`.

### GET `/definicion` → HTTP 200
```json
{"nombre":"Controlador de Climatización Inteligente en una Smart Home",
 "condiciones":["Temperatura interior > 26°C","Presencia humana activa detectada","Puertas/ventanas abiertas por más de 3 minutos"],
 "historial":[],"totalReglas":4}
```
Esto **confirma el orden de `valores`**: [temperatura > 26, presencia, ventanas abiertas]. También confirma que hay **4 reglas**, igual que el enunciado.

### POST `/evaluar` con body `{"valores":[C1,C2,C3]}`: las 8 combinaciones

Forma de la respuesta: `{valores, accion, reglaIndex, noDefinida:false}`. `reglaIndex` empieza en 0, así que 0 = Regla 1.

| C1 Temp>26 | C2 Presencia | C3 Ventanas | HTTP | accion | reglaIndex |
|---|---|---|---|---|---|
| true | true | true | 200 | Apagar sistema de climatización y emitir alerta sonora | 0 |
| true | false | true | 200 | Apagar sistema de climatización y emitir alerta sonora | 0 |
| false | true | true | 200 | Apagar sistema de climatización y emitir alerta sonora | 0 |
| false | false | true | 200 | Apagar sistema de climatización y emitir alerta sonora | 0 |
| true | true | false | 200 | Encender aire acondicionado en modo refrigeración | 1 |
| true | false | false | 200 | Mantener en modo de bajo consumo energético | 2 |
| false | true | false | 200 | Mantener sistema apagado | 3 |
| false | false | false | 200 | Mantener sistema apagado | 3 |
| `[true,true]` (2 valores) | | | **400** | `{"error":"Se esperaban 3 valores booleanos"}` | — |

**Conclusión:** las 8 combinaciones dan exactamente las 4 reglas del enunciado. Las ventanas abiertas tienen prioridad sobre la temperatura y la presencia.

## Verificación adicional (2026-10-11)

| Petición | HTTP | Respuesta | Historial |
|---|---|---|---|
| `evaluar {"valores":[true,true]}` | 400 | `{"error":"Se esperaban 3 valores booleanos"}` | no se registra |
| `evaluar {"valores":[true,true,true,false]}` | 400 | igual | no se registra |
| `evaluar {}` | 400 | igual | no se registra |
| `evaluar {"valores":["si",true,false]}` | **200** | `{"accion":null,"reglaIndex":null,"noDefinida":true}` | **sí se registra** |
| `evento {"evento":"Apagar"}` / `"encender"` / `{}` | 400 | `{"error":"Evento desconocido: …"}` | el estado no cambia |

Los rechazos 400 se automatizaron en `@Issue-15` (REQ-CLI-05) y `@Issue-16` (REQ-ILU-09).

## Posibles defectos

1. **Climatización acepta valores no booleanos.** Con `["si", true, false]` responde 200, no aplica ninguna regla (`accion: null`) y guarda la evaluación en el historial. El propio mensaje de error de la API dice "Se esperaban 3 valores booleanos", así que lo esperable es un 400 como en el resto de entradas inválidas. No se automatizó como prueba que pase, para no fijar un comportamiento defectuoso; en un proyecto real se reportaría como Issue con label `bug`.

Frente a las reglas del enunciado (transiciones y tabla de decisión) no se encontraron defectos.

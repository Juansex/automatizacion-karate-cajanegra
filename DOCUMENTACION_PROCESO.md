# Automatización de Pruebas Backend con Karate — Iluminación Teatral y Climatización Smart Home

**APIs bajo prueba:** `https://taller-de-tecnicas-de-prueba-de-caja.onrender.com/api` (APIs del taller de caja negra)
**Stack:** Java 21 · Gradle 9.3.0 (wrapper) · Karate 1.4.1 · JUnit 5 · GitHub Actions

| Bloque | Ejercicio elegido | Técnica | Feature |
|---|---|---|---|
| 1 | 1.4 Sistema de Iluminación Inteligente en Auditorio Teatral | Transición de estados | `src/test/resources/features/iluminacionTeatro.feature` |
| 2 | 2.2 Controlador de Climatización Inteligente en una Smart Home | Tabla de decisión | `src/test/resources/features/climatizacionSmartHome.feature` |

Anexos: [docs/REQUISITOS.md](docs/REQUISITOS.md) (reglas, matriz de 20 transiciones y tabla de 8 combinaciones) y [docs/HALLAZGOS_API.md](docs/HALLAZGOS_API.md) (respuestas reales de la API y posible defecto).

---

## 1. Punto de partida

El ejercicio de clase (`Documents\10 sem\Automatizacion de pruebas\Backend con Karate`) se copió a `C:\Automatizacion_Karate` y se completó ahí. Ese avance tenía 14 escenarios en verde (32 ejecuciones), pero no era un repositorio git y tenía estos puntos por mejorar:

| Problema | Por qué importa | Corrección |
|---|---|---|
| `baseUrl` repetida en el `Background` de cada feature | Cambiar de servidor obligaba a editar varios archivos | `baseUrl` en `karate-config.js`, con soporte para `karate.env` |
| `headers { Content-Type…, Accept… }` repetido en cada request | Ruido en cada escenario | `karate.configure('headers', { Accept: 'application/json' })` global. Karate pone `Content-Type: application/json` solo cuando el body es JSON |
| Sin timeouts explícitos | Render "duerme" el servicio: la primera petición tardó 22,6 s | `connectTimeout` y `readTimeout` de 60 s en `karate-config.js` |
| Climatización no tenía escenarios negativos | La guía pide positivos y negativos para demostrar dominio de la lógica | `@Issue-15` (entrada con cantidad incorrecta de condiciones → 400) |
| Sin prueba de eventos inexistentes en iluminación | La API los rechaza con 400; no se verificaba | `@Issue-16` (evento inexistente → 400 y el estado no cambia) |
| `ci.yml`: el comentario al Issue se armaba con `jq -R .` | Con un texto de varias líneas, `jq -R` genera un string JSON por línea → body inválido → el comentario no se publica | `jq -Rs .` (todo el texto como un solo string) |
| `ci.yml`: subía `target/test-results` | Gradle deja los resultados JUnit en `build/test-results/test` → artefacto vacío | Ruta corregida |
| Sin `gradle.properties` | El equipo local tiene poca memoria libre | `-Xmx384m` para Gradle y `maxHeapSize = "384m"` para las pruebas |
| 9 documentos sueltos en `docs/` | Difícil de seguir para la sustentación | Este documento único + 2 anexos |

---

## 2. Cómo funciona Karate en este proyecto

### 2.1 Flujo de ejecución

```
gradlew test  ("-Dkarate.options=--tags @Issue-5" opcional)
  └─ Gradle → JUnit 5 (useJUnitPlatform)
       └─ runner/cajanegra2runner.java  @Test testParallel()
            └─ Runner.path("classpath:features").parallel(1)
                 ├─ karate-config.js  → se ejecuta ANTES DE CADA escenario: baseUrl, timeouts, headers, logs
                 ├─ lee features/*.feature y filtra por los tags de karate.options
                 └─ por cada Scenario y cada fila de Examples:
                      Background → pasos del escenario → (call read(helper) si hace falta)
                      cada "method get/post" hace la petición HTTP real
                      cada "status" / "match" es una aserción: si falla, el escenario falla
            └─ assertEquals(0, results.getFailCount())   ← esto es lo que hace fallar el build
  └─ target/karate-reports/karate-summary.html  (request, response y aserciones de cada paso)
```

Puntos clave:

- **Karate no necesita step definitions.** `url`, `path`, `request`, `method`, `status` y `match` son palabras clave del propio framework, que ya sabe hacer la petición y la aserción. En Serenity/Cucumber cada frase había que programarla en Java.
- **El runner es una prueba JUnit.** Gradle solo "ve" un test (`testParallel`). Karate ejecuta todos los escenarios dentro de él y, al final, `assertEquals(0, failCount)` convierte cualquier fallo de Karate en un fallo del build. Sin esa línea el build saldría verde aunque fallaran escenarios.
- **`parallel(1)`**: un solo hilo. La máquina de estados de iluminación vive en el servidor; con dos hilos, el reinicio de un escenario rompería otro que está a la mitad.
- **El `Background` corre antes de cada escenario y de cada fila de `Examples`**, no una vez por feature.
- **`-Dkarate.options`** llega al runner porque `build.gradle` lo pasa como propiedad del sistema (`systemProperty "karate.options", System.getProperty("karate.options")`).
- **Ojo:** un tag mal escrito ejecuta 0 escenarios y el build sale **verde**. Siempre hay que revisar el conteo en el reporte.

### 2.2 Estructura

```
.github/workflows/ci.yml                 → pipeline del curso (con 2 correcciones, sección 6)
build.gradle · settings.gradle · gradle.properties
gradlew · gradlew.bat · gradle/wrapper/  → Gradle 9.3.0 sin instalarlo
scripts/crear_issues.sh                  → crea labels, los 16 Issues y los agrega al Project
src/test/java/runner/cajanegra2runner.java
src/test/resources/
  karate-config.js                       → configuración global
  logback-test.xml                       → nivel de logs
  features/                              → LAS PRUEBAS (lo único que ejecuta el runner)
    iluminacionTeatro.feature            → 11 escenarios (Issues 1–10 y 16)
    climatizacionSmartHome.feature       → 5 escenarios (Issues 11–15)
  helpers/                               → features reutilizables, con @ignore (no son pruebas)
    estadosIluminacion.json              → S1..S5 → nombre completo ("S2 (Luces de Cortesía)")
    irAEstadoIluminacion.feature         → lleva la máquina desde S1 al estado pedido y lo verifica
    enviarEventoIluminacion.feature      → envía un evento de preparación (debe ser válido)
    verificarEstadoIluminacion.feature   → GET /estado y compara con el esperado
docs/REQUISITOS.md · docs/HALLAZGOS_API.md
```

### 2.3 `karate-config.js`

```javascript
var config = { env: env, baseUrl: urls[env] || urls.dev };
karate.configure('connectTimeout', 60000);
karate.configure('readTimeout', 60000);
karate.configure('headers', { Accept: 'application/json' });
```

Todo lo que devuelve `config` (por ejemplo `baseUrl`) queda disponible como variable en **todos** los features y helpers. Para apuntar a otro servidor: agregar una URL en `urls` y ejecutar con `-Dkarate.env=<nombre>`.

### 2.4 Un escenario línea por línea (`@Issue-2`)

```gherkin
@REQ-ILU-02 @Issue-2 @smoketest @positivo
Scenario: Verificar que el evento Encender lleva el sistema de S1 (Apagado Total) a S2 (Luces de Cortesía)
  Given url baseUrl
  And path 'iluminacion-teatro/evento'
  And request { evento: 'Encender' }
  When method post
  Then status 200
  And match response contains { estadoAnterior: '#(estados.S1)', evento: 'Encender', estadoNuevo: '#(estados.S2)', valida: true }
  * call read(verificarEstado) { estadoEsperado: 'S2' }
```

| Línea | Qué hace |
|---|---|
| Tags | `@REQ-ILU-02` = requisito · `@Issue-2` = Issue #2 · `@smoketest` = corre en cada push · `@positivo` = transición válida |
| `url baseUrl` | URL base que viene de `karate-config.js` |
| `path` | Se agrega a la URL → `…/api/iluminacion-teatro/evento` |
| `request` | Body JSON. Karate pone `Content-Type: application/json` automáticamente |
| `method post` | **Aquí se envía** la petición HTTP |
| `status 200` | Aserción del código HTTP |
| `match … contains` | Aserción del body. `'#(estados.S1)'` es una **expresión embebida**: Karate la reemplaza por `"S1 (Apagado Total)"` |
| `call read(verificarEstado)` | Llama al helper que hace `GET /estado` y confirma que el **servidor** quedó en S2 (no basta con lo que dice la respuesta del POST) |

**`match ==` vs `match contains`:** `==` exige igualdad exacta (ni un campo de más). `contains` exige que estén esos campos. En climatización se usa `==` porque la respuesta es pequeña y estable; en iluminación, `contains`, porque la respuesta trae `guardia` y `accion`, que no son parte del requisito.

### 2.5 Helpers: cómo se prepara un estado

La guía pide que antes del `Given` se consulte el estado y se mueva la máquina al estado inicial. Eso hace el `Background` de iluminación:

```gherkin
Background:
  * def estados = read('classpath:helpers/estadosIluminacion.json')
  Given url baseUrl
  And path 'iluminacion-teatro/estado'      # 1. consultar el estado actual
  When method get
  ...
  And path 'iluminacion-teatro/reiniciar'   # 2. mover a S1
  When method post
  And match response.estadoActual == estados.S1
```

Para llegar a otro estado, `irAEstadoIluminacion.feature` aplica la secuencia mínima de eventos válidos:

| Estado destino | Secuencia desde S1 |
|---|---|
| S1 | — |
| S2 | Encender |
| S3 | Encender → Iniciar Show |
| S4 | Encender → Iniciar Show → Iniciar Show |
| S5 | Alarma de Humo |

```gherkin
* def pasos = karate.map(secuencias[estadoObjetivo], toEventPayload)   # ['Encender'] → [{evento:'Encender'}]
* call read('classpath:helpers/enviarEventoIluminacion.feature') pasos # call con un ARREGLO = un bucle
* call read('classpath:helpers/verificarEstadoIluminacion.feature') { estadoEsperado: '#(estadoObjetivo)' }
```

- `call read(archivo) { … }` ejecuta otro feature y le pasa variables.
- Si se le pasa un **arreglo**, lo ejecuta una vez por elemento.
- Los helpers llevan `@ignore` y están fuera de `features/`, así que el runner nunca los ejecuta como pruebas sueltas.
- Cada helper hace sus propias aserciones: si la preparación falla, falla el escenario que lo llamó. Esto evita "pasar" una prueba que en realidad empezó en el estado equivocado.

---

## 3. Diseño de casos y trazabilidad

### 3.1 Técnicas

- **Transición de estados (iluminación):** la matriz tiene 5 estados × 4 eventos = **20 celdas**, 8 válidas y 12 inválidas. Se cubren **las 20**. Los positivos validan el nuevo estado; los negativos validan que el estado **no cambia**.
- **Tabla de decisión (climatización):** 3 condiciones booleanas = **8 combinaciones**, que se reducen a **4 reglas**. Las 8 aparecen en los `Examples`, así se ve la reducción.
- **Validación de entrada (ambas):** valores fuera del dominio → 400.

**Scenario vs Scenario Outline:** un `Scenario Outline` es una plantilla con variables `<x>` que se ejecuta una vez por fila de `Examples`. Cuenta como **un** escenario con **un** Issue, pero en el reporte aparecen varias ejecuciones (igual que el ejemplo de envío gratis de la guía).

### 3.2 Matriz de trazabilidad

| Issue | Requisito | Escenario | Tipo | Forma | Ejecuciones | Suite |
|---|---|---|---|---|---|---|
| #1 | REQ-ILU-01 | Reinicio deja la máquina en S1 y declara 5 estados y 4 eventos | + | Scenario | 1 | smoke |
| #2 | REQ-ILU-02 | Encender: S1 → S2 | + | Scenario | 1 | smoke |
| #3 | REQ-ILU-03 | Iniciar Show: S2 → S3 | + | Scenario | 1 | regression |
| #4 | REQ-ILU-03 | Iniciar Show: S3 → S4 | + | Scenario | 1 | regression |
| #5 | REQ-ILU-04 | Alarma de Humo → S5 desde S1, S2, S3, S4 | + | Outline | 4 | regression |
| #6 | REQ-ILU-05 | Reset → S1 sin importar desde dónde se activó la alarma | + | Outline | 4 | regression |
| #7 | REQ-ILU-06 | Iniciar Show no cambia el estado en S1 ni en S4 | − | Outline | 2 | regression |
| #8 | REQ-ILU-08 | Encender no cambia el estado en S2, S3, S4, S5 | − | Outline | 4 | regression |
| #9 | REQ-ILU-08 | Reset no cambia el estado en S1, S2, S3, S4 | − | Outline | 4 | regression |
| #10 | REQ-ILU-07 | En S5, Alarma de Humo e Iniciar Show no tienen efecto | − | Outline | 2 | regression |
| #11 | REQ-CLI-01 | Regla 1: ventanas abiertas → apagar y alerta (4 combinaciones) | + | Outline | 4 | smoke |
| #12 | REQ-CLI-02 | Regla 2: temp. alta + presencia + ventanas cerradas → refrigeración | + | Scenario | 1 | regression |
| #13 | REQ-CLI-03 | Regla 3: temp. alta + sin presencia + ventanas cerradas → bajo consumo | + | Scenario | 1 | regression |
| #14 | REQ-CLI-04 | Regla 4: temp. normal + ventanas cerradas → apagado (2 combinaciones) | + | Outline | 2 | regression |
| #15 | REQ-CLI-05 | Rechazo de entradas sin exactamente 3 condiciones (2, 4, ninguna) | − | Outline | 3 | regression |
| #16 | REQ-ILU-09 | Rechazo de un evento inexistente (`Apagar`, `encender`) sin cambiar el estado | − | Outline | 2 | regression |

**Totales:** 14 requisitos · **16 escenarios (10 positivos, 6 negativos) · 16 Issues · 37 ejecuciones**. `@smoketest` = 3 escenarios / 6 ejecuciones.

**Cobertura de la matriz de transiciones** (número = Issue que prueba la celda):

| Estado \ Evento | Encender | Iniciar Show | Alarma de Humo | Fin Emergencia / Reset |
|---|---|---|---|---|
| S1 | ✅ #2 | ❌ #7 | ✅ #5 | ❌ #9 |
| S2 | ❌ #8 | ✅ #3 | ✅ #5 | ❌ #9 |
| S3 | ❌ #8 | ✅ #4 | ✅ #5 | ❌ #9 |
| S4 | ❌ #8 | ❌ #7 | ✅ #5 | ❌ #9 |
| S5 | ❌ #8 | ❌ #10 | ❌ #10 | ✅ #6 |

**Cobertura de la tabla de decisión:** 8 de 8 combinaciones: 4 en #11, 1 en #12, 1 en #13 y 2 en #14.

### 3.3 Tags

| Tag | Nivel | Para qué |
|---|---|---|
| `@api @iluminacion` / `@api @climatizacion` | Feature | Agrupar por módulo (todos los escenarios los heredan) |
| `@REQ-ILU-NN` / `@REQ-CLI-NN` | Scenario | **Requisito** al que pertenece el escenario (guía §4.4) |
| `@Issue-N` | Scenario | Vincula el escenario con el **Issue #N** de GitHub |
| `@smoketest` / `@regression` | Scenario | Tipo de suite: smoke corre en cada push |
| `@positivo` / `@negativo` | Scenario | Tipo de caso |

```
Issue #9 (GitHub Project)  ←→  @Issue-9  ←→  Scenario Outline "Fin Emergencia / Reset no cambia el estado…"
                                @REQ-ILU-08 ←→ Requisito "Reset fuera de S5 no está definido" (docs/REQUISITOS.md)
```

### 3.4 Respuestas reales de la API (resumen de `docs/HALLAZGOS_API.md`)

- **Transición inválida → HTTP 200**, con `valida: false`, `noDefinida: true` y el estado sin cambios. No es un 4xx: la API "ignora el comando", que es lo que admite la guía. Por eso los negativos validan `status 200` + flags + `GET /estado`.
- **Evento inexistente → HTTP 400** `{"error":"Evento desconocido: <evento>"}`.
- **Climatización con ≠ 3 valores → HTTP 400** `{"error":"Se esperaban 3 valores booleanos"}`, sin registrarse en el historial.
- **Posible defecto:** climatización con `["si", true, false]` responde **200** con `accion: null` y lo guarda en el historial. Por el mensaje de error de la propia API, se esperaría 400. Está documentado y no se automatizó como prueba "verde" para no fijar un comportamiento defectuoso.

---

## 4. Ejecución y resultados

```powershell
# Windows PowerShell: las comillas deben envolver TODO el -D... (si no, PowerShell parte el argumento en el punto)
.\gradlew.bat clean test --console=plain                                           # todo
.\gradlew.bat clean test --console=plain "-Dkarate.options=--tags @smoketest"      # humo
.\gradlew.bat clean test --console=plain "-Dkarate.options=--tags @Issue-5"        # un Issue
.\gradlew.bat clean test --console=plain "-Dkarate.options=--tags @REQ-ILU-08"     # un requisito (Issues 8 y 9)
.\gradlew.bat clean test --console=plain "-Dkarate.options=--tags @negativo"       # todos los negativos
.\gradlew.bat clean test --console=plain "-Dkarate.options=--tags @Issue-15,@Issue-16"  # coma = OR
```

Reporte: `target/karate-reports/karate-summary.html` → clic en un escenario para ver request, headers, response y cada `match`.

**Registro de ejecuciones locales (11/10/2026):**

| # | Ejecución | Resultado |
|---|---|---|
| 1 | Línea base del proyecto de clase, sin cambios: `@Issue-3` y suite completa | ✅ 1/1 y ✅ 32/32 |
| 2 | Escenarios nuevos `@Issue-15,@Issue-16` | ✅ 5/5 |
| 3 | Suite completa con todos los cambios (`karate-config.js`, sin headers repetidos, 16 escenarios) | ✅ **37/37** ejecuciones (16 escenarios, 2 features), 44 s |
| 4 | Control negativo: en `@Issue-12` se cambió `reglaIndex: 1` por `2` | ✅ **BUILD FAILED**, como se esperaba: `$.reglaIndex not equal` (real 1, esperado 2). Archivo restaurado |

---

## 5. Pipeline (GitHub Actions)

Archivo `.github/workflows/ci.yml` (el del curso). Funcionamiento:

1. **push / pull_request** a `main` o `develop` → `./gradlew clean test -Dkarate.options="--tags @smoketest"`.
2. **workflow_dispatch** (Actions → *Run workflow*) → corre el tag escrito en `testTag` (vacío = todos).
3. El paso de pruebas tiene `continue-on-error: true` para que los pasos siguientes siempre corran. Al final, *Fail workflow if tests failed* pone el job en rojo si hubo fallos.
4. Sube `target/karate-reports` (artefacto `karate-reports`) y `build/test-results/test`.
5. Si el tag es `@Issue-N`: extrae `N` con la regex `Issue-([0-9]+)`, quita los labels `status:*` anteriores del Issue #N, pone `status:passed` o `status:failed` y **comenta** el resultado con el enlace a la corrida. Esto es la **ejecución del escenario desde el TestCase**.

Cambios respecto al archivo del curso: `jq -Rs` en el comentario y la ruta `build/test-results/test` (sección 1).

### Publicar en GitHub

```bash
# 1. Repositorio vacío en GitHub (sin README, para que el primer Issue sea el #1) y subir el código
git remote add origin https://github.com/<usuario>/<repo>.git
git push -u origin main            # → en Actions corre @smoketest automáticamente

# 2. Project: Projects → New project (Board) → nombre "TestCases"; en el repo: Projects → Link a project

# 3. Labels + 16 Issues en orden + agregarlos al Project
gh auth login && gh auth refresh -s project
bash scripts/crear_issues.sh <usuario> <numero-del-project>

# 4. Ejecutar un TestCase: Actions → CI / CD Pipeline → Run workflow → testTag = @Issue-6
```

`crear_issues.sh` pone en cada Issue el Gherkin del escenario (leído del `.feature`), los labels `REQ-…`, `positivo/negativo`, módulo y `test-case`, y se detiene si el número creado no coincide con `@Issue-N`.

> `.github/copilot-instructions.md` es el archivo de instrucciones de Copilot entregado en clase (está en `.gitignore`); no es una regla del proyecto.

---

## 6. Guía de sustentación

### 6.1 Guion (10–15 min)

Antes: correr una vez `curl.exe -s https://taller-de-tecnicas-de-prueba-de-caja.onrender.com/api/iluminacion-teatro/estado` para despertar Render; tener abiertos el repo, el Project, Actions, el IDE y un reporte ya generado.

1. **Ejercicios y técnicas (2 min).** Mostrar la matriz de 20 transiciones y la tabla de 8 combinaciones (sección 3).
2. **Feature y Gherkin (2 min).** Abrir `iluminacionTeatro.feature`: historia de usuario, `Background` (consultar + reiniciar), un `Scenario` (#2) y un `Scenario Outline` (#5) con `Examples`.
3. **Trazabilidad (2 min).** Abrir el Issue #5 en el Project: mismo Gherkin, labels `REQ-ILU-04`, `positivo`, `test-case`. Explicar Issue #5 ↔ `@Issue-5` ↔ escenario ↔ `@REQ-ILU-04`.
4. **Ejecución local (2 min).** `.\gradlew.bat clean test --console=plain "-Dkarate.options=--tags @Issue-5"` → abrir el reporte → 4 ejecuciones → clic en una: request, response, `match`.
5. **Ejecución desde el TestCase (3 min).** Actions → Run workflow → `testTag = @Issue-5` → al terminar, el Issue #5 tiene el comentario y el label `status:passed`; descargar el artefacto `karate-reports`.
6. **Cambio en vivo (2 min).** Sección 6.2.

### 6.2 Cambios en vivo

**A. Demostrar que las aserciones detectan errores**
1. En `climatizacionSmartHome.feature`, `@Issue-12`, cambiar `reglaIndex: 1` por `reglaIndex: 2`.
2. `.\gradlew.bat clean test --console=plain "-Dkarate.options=--tags @Issue-12"` → **BUILD FAILED**; el reporte muestra `match failed` con el valor real (1).
3. Volver a `1` → **BUILD SUCCESSFUL**.

**B. Agregar una fila a `Examples`**
1. En `@Issue-7` (Iniciar Show inválido, filas S1 y S4) agregar `| S5            |`.
2. Ejecutar `--tags @Issue-7` → 3 ejecuciones en verde.
3. Agregar `| S2 |` → **falla**, porque Iniciar Show en S2 sí es válido (lleva a S3). La prueba distingue válido de inválido.

**C. Mover un caso al smoke**
1. En `@Issue-13` cambiar `@regression` por `@smoketest`.
2. `--tags @smoketest` → 7 ejecuciones en vez de 6. Al hacer push, el pipeline también lo correrá.

**D. Crear un escenario nuevo** (si lo pide): copiar `@Issue-12`, cambiar `valores`, `accion` y `reglaIndex` por los de otra combinación, ponerle un tag `@Issue-17` y crear el Issue #17 con el mismo título.

### 6.3 Preguntas probables

| Pregunta | Respuesta corta |
|---|---|
| ¿Por qué Karate no tiene step definitions? | Sus palabras clave (`url`, `path`, `method`, `status`, `match`) ya implementan la petición y la aserción. |
| ¿Qué hace el `Background`? | Corre antes de cada escenario y cada fila de `Examples`. En iluminación consulta y reinicia a S1, para que los casos sean independientes. |
| ¿Cómo llegas a S4? | Con el helper `irAEstadoIluminacion`: Encender → Iniciar Show → Iniciar Show, y luego verifica con `GET /estado`. |
| ¿Cómo pruebas una transición inválida? | Llevo a X, confirmo X, envío el evento, valido `200`, `valida: false`, `noDefinida: true` y con `GET` que **sigue en X**. |
| ¿Por qué una inválida da 200 y no 400? | La API ignora el comando y lo marca con flags; el enunciado no define el código. El 400 es solo para eventos que no existen (#16). |
| ¿Cómo se reducen 8 combinaciones a 4 reglas? | Con ventanas abiertas, temperatura y presencia no importan (4 → R1). Con ventanas cerradas y temperatura normal, la presencia no importa (2 → R4). R2 y R3 son una combinación cada una. |
| ¿Qué es `reglaIndex`? | El número de regla que devuelve la API, desde 0 (0 = Regla 1). |
| ¿Qué es `'#(estados.S1)'`? | Una expresión embebida: Karate la reemplaza por el valor de la variable dentro del JSON. |
| ¿`match ==` o `contains`? | `==` igualdad exacta; `contains` solo los campos indicados. |
| ¿Qué hace fallar el build? | `assertEquals(0, results.getFailCount())` en el runner. |
| ¿Por qué `parallel(1)`? | El estado está en el servidor; en paralelo un reinicio pisaría otro escenario. |
| ¿Qué riesgo tiene usar un servidor compartido? | Si un compañero usa la misma API al mismo tiempo, puede cambiar el estado a mitad de un escenario. Se mitiga con el reinicio del `Background` y verificando el estado antes de cada evento; si pasa, se re-ejecuta. |
| ¿Cómo se vincula un escenario con su Issue? | Con `@Issue-N`; el pipeline extrae `N` y actualiza el Issue #N. |
| ¿`@smoketest` vs `@regression`? | Smoke: 3 casos esenciales en cada push. Regression: el resto. |
| ¿Dónde se ve qué se envió y qué respondió? | En `karate-summary.html`, clic en el escenario. |
| ¿Cómo usaste la IA? | Como asistente para leer la guía, explorar la API, diseñar casos y escribir features. Cada decisión está documentada aquí para poder explicarla y modificarla. |

### 6.4 Checklist

- [ ] Suite local en verde y reporte generado.
- [ ] Repositorio en GitHub con `gradlew` (LF, ejecutable), `gradle/wrapper` y `.github/workflows/ci.yml`.
- [ ] Project vinculado al repositorio con los 16 Issues.
- [ ] Una corrida verde por push (`@smoketest`) y una manual con `@Issue-N` que comentó el Issue.

---

## 7. Resumen de cumplimiento

| Requisito del taller | Cómo se cumple |
|---|---|
| §2 Un ejercicio por bloque | 1.4 Iluminación (transición de estados) y 2.2 Climatización (tabla de decisión) |
| §3 Casos en Gherkin | 16 escenarios; Outlines con `Examples` como en los ejemplos de la guía; consulta y movimiento a S1 antes del `Given` |
| §3 Todas las transiciones válidas | 8 de 8 (y además las 12 inválidas) |
| §4.1 Continuar el ejercicio de clase | Mismo runner, `build.gradle`, `karate-config.js` y `ci.yml` del curso |
| §4.4 Tags de requisito + Issue | `@REQ-…` y `@Issue-N` en cada escenario |
| 5.1 ≥ 10 escenarios con Issue | 16 escenarios / 16 Issues (10 positivos, 6 negativos) |
| 5.2 Código en repositorio | Repositorio git local listo para `push` (pendiente publicar) |
| 5.3 Despliegue en GitHub Actions | `ci.yml` (pendiente la primera corrida en GitHub) |
| 5.4 TestCases con Issues vinculados | `scripts/crear_issues.sh` + Project (pendiente crear en GitHub) |
| 5.5 Sustentación | Sección 6 |

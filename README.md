# Automatización de pruebas backend con Karate

Automatización de pruebas de API con Karate Framework sobre dos ejercicios del taller de técnicas de caja negra:

| Bloque | Ejercicio | Técnica | Feature |
|---|---|---|---|
| 1 | 1.4 Sistema de Iluminación Inteligente en Auditorio Teatral | Transición de estados | `iluminacionTeatro.feature` |
| 2 | 2.2 Controlador de Climatización Inteligente en una Smart Home | Tabla de decisión | `climatizacionSmartHome.feature` |

- **API:** `https://taller-de-tecnicas-de-prueba-de-caja.onrender.com/api/`
- **Stack:** Java 21, Gradle (wrapper), Karate 1.4.1, JUnit 5, GitHub Actions
- **Casos:** 14 escenarios (10 positivos, 4 negativos), 32 ejecuciones contando las filas de `Examples`

## Estructura

```
.github/workflows/ci.yml              Pipeline de GitHub Actions
src/test/java/runner/
  cajanegra2runner.java               Runner JUnit 5: ejecuta classpath:features y falla si hay errores
src/test/resources/
  karate-config.js                    baseUrl, timeouts y headers comunes
  logback-test.xml                    Nivel de logs
  features/
    iluminacionTeatro.feature         Issues 1 a 10
    climatizacionSmartHome.feature    Issues 11 a 14
  helpers/                            Features reutilizables (@ignore) para preparar estados
    estadosIluminacion.json           Nombres completos de S1..S5
    irAEstadoIluminacion.feature      Lleva la máquina desde S1 hasta el estado pedido
    enviarEventoIluminacion.feature   Envía un evento de preparación
    verificarEstadoIluminacion.feature  Consulta GET /estado y lo compara con el esperado
```

## Diseño de los casos

### Iluminación (transición de estados)

Estados S1 Apagado Total, S2 Luces de Cortesía, S3 Iluminación de Ensayo, S4 Escena en Vivo y S5 Modo Emergencia.
Eventos: Encender, Iniciar Show, Alarma de Humo y Fin Emergencia / Reset.

| Estado \ Evento | Encender | Iniciar Show | Alarma de Humo | Fin Emergencia / Reset |
|---|---|---|---|---|
| S1 | S2 (#2) | inválida (#7) | S5 (#5) | inválida (#9) |
| S2 | inválida (#8) | S3 (#3) | S5 (#5) | inválida (#9) |
| S3 | inválida (#8) | S4 (#4) | S5 (#5) | inválida (#9) |
| S4 | inválida (#8) | inválida (#7) | S5 (#5) | inválida (#9) |
| S5 | inválida (#8) | inválida (#10) | inválida (#10) | S1 (#6) |

Se cubren las 8 transiciones válidas y las 12 inválidas.

- El `Background` consulta el estado actual y reinicia la máquina a S1 antes de cada escenario, para que cada caso sea independiente.
- Para probar una transición desde S2..S5, el helper `irAEstadoIluminacion` aplica la secuencia mínima de eventos válidos y verifica que se llegó al estado.
- En una transición inválida la API responde `200` con `valida: false` y `noDefinida: true`. La prueba valida esos campos y, con `GET /estado`, que el estado no cambió.

### Climatización (tabla de decisión)

Condiciones, en el orden del arreglo `valores`: temperatura interior > 26 °C, presencia humana activa, puertas/ventanas abiertas > 3 min.

| Regla | Condiciones | Acción | Issue |
|---|---|---|---|
| 1 | ventanas abiertas (temperatura y presencia indiferentes) | Apagar sistema de climatización y emitir alerta sonora | #11 (4 combinaciones) |
| 2 | temperatura alta, presencia, ventanas cerradas | Encender aire acondicionado en modo refrigeración | #12 |
| 3 | temperatura alta, sin presencia, ventanas cerradas | Mantener en modo de bajo consumo energético | #13 |
| 4 | temperatura normal, ventanas cerradas (presencia indiferente) | Mantener sistema apagado | #14 (2 combinaciones) |

Las 8 combinaciones posibles quedan cubiertas en los `Examples`. La API devuelve `reglaIndex` empezando en 0.

## Trazabilidad

Cada escenario tiene un tag de requisito y uno de Issue:

| Tag | Uso |
|---|---|
| `@REQ-ILU-01`..`@REQ-ILU-08`, `@REQ-CLI-01`..`@REQ-CLI-04` | Requisito al que pertenece el escenario |
| `@Issue-N` | Vincula el escenario con el Issue #N del repositorio |
| `@smoketest` / `@regression` | Suite: `@smoketest` corre en cada push |
| `@positivo` / `@negativo` | Tipo de caso |

Los Issues #1 a #14 están en el GitHub Project **TestCases**, vinculado al repositorio. Cada Issue contiene el escenario Gherkin y los labels del requisito y del tipo.

## Pipeline

`.github/workflows/ci.yml`:

- **push / pull request** a `main` o `develop`: ejecuta `@smoketest`.
- **Ejecución manual** (`workflow_dispatch`): ejecuta el tag indicado en `testTag`. Si el tag es `@Issue-N`, comenta el resultado en el Issue #N y le asigna el label `status:passed` o `status:failed`.
- Publica los artefactos `karate-reports` y `test-results`.

---

# Manual de uso

## Requisitos

- JDK 21
- Conexión a internet (la API está publicada en Render; la primera petición puede tardar unos segundos mientras el servicio arranca, y los timeouts están en 60 s)
- No hace falta instalar Gradle: se usa `gradlew` / `gradlew.bat`

## Ejecutar en local

Windows (PowerShell). Las comillas deben envolver todo el argumento `-D...`:

```powershell
.\gradlew.bat clean test --console=plain                                         # suite completa
.\gradlew.bat clean test --console=plain "-Dkarate.options=--tags @smoketest"    # smoke
.\gradlew.bat clean test --console=plain "-Dkarate.options=--tags @Issue-5"      # un caso
.\gradlew.bat clean test --console=plain "-Dkarate.options=--tags @REQ-ILU-08"   # un requisito
.\gradlew.bat clean test --console=plain "-Dkarate.options=--tags @negativo"     # solo negativos
```

Linux / macOS / Git Bash:

```bash
./gradlew clean test --console=plain -Dkarate.options="--tags @Issue-5"
```

## Ver resultados

- `target/karate-reports/karate-summary.html`: resultado por feature y escenario, con request, response y cada `match`.
- Si un escenario falla, el build termina en `BUILD FAILED` y el detalle aparece en consola y en el reporte.
- Un tag mal escrito ejecuta 0 escenarios y el build termina en verde: revisar siempre el conteo en el reporte.

## Ejecutar un caso desde GitHub

1. **Actions** → **CI / CD Pipeline** → **Run workflow**.
2. Rama `main`, `testTag` = `@Issue-5` (o el número del caso) → **Run workflow**.
3. Al terminar, el Issue #5 tiene un comentario con el resultado y el enlace a la corrida, y el label `status:passed` o `status:failed`.
4. En la corrida, sección **Artifacts**, descargar `karate-reports` y abrir `karate-summary.html`.

Con GitHub CLI:

```bash
gh workflow run ci.yml -f testTag=@Issue-5
gh run watch
gh issue view 5 --comments
```

## Agregar un caso

1. Escribir el escenario en el `.feature` correspondiente con sus tags, por ejemplo `@REQ-CLI-02 @Issue-17 @regression @positivo`.
2. Ejecutarlo en local con `--tags @Issue-17`.
3. Crear el Issue en GitHub (debe quedar con el mismo número del tag; GitHub no reutiliza números, el siguiente libre es el 17) y agregarlo al Project TestCases.
4. Hacer push a `main`.

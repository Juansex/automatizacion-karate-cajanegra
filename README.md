# Automatización de pruebas backend con Karate

Taller *Automatización de Pruebas Backend con Karate Framework*. Se automatizan dos APIs del taller de caja negra:

| Bloque | Ejercicio | Técnica | Feature |
|---|---|---|---|
| 1 | Sistema de Iluminación Inteligente en Auditorio Teatral | Transición de estados | `src/test/resources/features/iluminacionTeatro.feature` |
| 2 | Controlador de Climatización Inteligente en una Smart Home | Tabla de decisión | `src/test/resources/features/climatizacionSmartHome.feature` |

Son 16 escenarios (37 ejecuciones; 10 positivos y 6 negativos). Cada uno tiene un tag de requisito `@REQ-…` y uno de Issue `@Issue-N`.

## Ejecutar

```powershell
.\gradlew.bat clean test --console=plain                                        # suite completa
.\gradlew.bat clean test --console=plain "-Dkarate.options=--tags @smoketest"   # humo
.\gradlew.bat clean test --console=plain "-Dkarate.options=--tags @Issue-5"     # un escenario
```
Reporte: `target/karate-reports/karate-summary.html`.

## CI

`.github/workflows/ci.yml` ejecuta `@smoketest` en cada push o pull request a `main`/`develop`. En ejecución manual recibe un tag; si es `@Issue-N`, comenta el resultado en el Issue #N y le pone el label `status:passed` o `status:failed`.

## Documentación

- **[DOCUMENTACION_PROCESO.md](DOCUMENTACION_PROCESO.md)**: funcionamiento de Karate, flujo de ejecución, diseño de casos, trazabilidad, pipeline y guía de sustentación.
- Anexos: [docs/REQUISITOS.md](docs/REQUISITOS.md) y [docs/HALLAZGOS_API.md](docs/HALLAZGOS_API.md).
- Issues: `bash scripts/crear_issues.sh <usuario> <numero-del-project>`.

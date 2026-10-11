#!/usr/bin/env bash
# Crea los labels y los 16 Issues (TestCases) en el repositorio y los agrega al GitHub Project.
#
# Requisitos: gh instalado y autenticado (gh auth login && gh auth refresh -s project)
# Uso (desde la raíz del repositorio, ya publicado en GitHub):
#   bash scripts/crear_issues.sh <owner> <numero-del-project>
#
# IMPORTANTE: ejecutarlo en un repositorio SIN Issues ni Pull Requests previos.
# GitHub numera Issues y PRs con el mismo contador; el Issue #N debe coincidir con el tag @Issue-N.

set -euo pipefail

OWNER="${1:?Falta el owner (usuario de GitHub)}"
PROJECT="${2:?Falta el número del GitHub Project}"
REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"
FEATURES="src/test/resources/features"

crear_label() { gh label create "$1" --color "$2" --description "$3" --force >/dev/null; }

echo "Creando labels en $REPO..."
for n in 01 02 03 04 05 06 07 08 09; do crear_label "REQ-ILU-$n" "1D76DB" "Requisito Iluminación teatral"; done
for n in 01 02 03 04 05; do crear_label "REQ-CLI-$n" "5319E7" "Requisito Climatización smart home"; done
crear_label "iluminacion"   "C5DEF5" "Bloque 1 - Transición de estados"
crear_label "climatizacion" "D4C5F9" "Bloque 2 - Tabla de decisión"
crear_label "positivo"      "0E8A16" "Caso de prueba positivo"
crear_label "negativo"      "B60205" "Caso de prueba negativo"
crear_label "test-case"     "FBCA04" "Caso de prueba automatizado en Karate"
crear_label "status:passed" "0E8A16" "Última ejecución del pipeline: aprobada"
crear_label "status:failed" "D93F0B" "Última ejecución del pipeline: fallida"

# Devuelve el bloque Gherkin del escenario que tiene el tag @Issue-N (hasta el siguiente tag de escenario)
gherkin_de() {
  awk -v tag="@Issue-$1" '
    $0 ~ "^[[:space:]]*@" && found { exit }
    index($0, tag" ") || $0 ~ tag"$" { found = 1 }
    found && $0 ~ /^[[:space:]]*#[[:space:]]*-+/ { exit }
    found { print }
  ' "$2"
}

# numero | requisito | tipo | módulo | archivo | título
CASOS=(
  "1|REQ-ILU-01|positivo|iluminacion|iluminacionTeatro.feature|Reinicio deja la iluminación en el estado inicial S1"
  "2|REQ-ILU-02|positivo|iluminacion|iluminacionTeatro.feature|Encender: S1 Apagado Total → S2 Luces de Cortesía"
  "3|REQ-ILU-03|positivo|iluminacion|iluminacionTeatro.feature|Iniciar Show: S2 Luces de Cortesía → S3 Iluminación de Ensayo"
  "4|REQ-ILU-03|positivo|iluminacion|iluminacionTeatro.feature|Iniciar Show: S3 Iluminación de Ensayo → S4 Escena en Vivo"
  "5|REQ-ILU-04|positivo|iluminacion|iluminacionTeatro.feature|Alarma de Humo lleva a S5 desde S1, S2, S3 y S4"
  "6|REQ-ILU-05|positivo|iluminacion|iluminacionTeatro.feature|Fin Emergencia / Reset devuelve a S1 sin importar el estado previo"
  "7|REQ-ILU-06|negativo|iluminacion|iluminacionTeatro.feature|Iniciar Show no cambia el estado en S1 ni en S4"
  "8|REQ-ILU-08|negativo|iluminacion|iluminacionTeatro.feature|Encender no cambia el estado fuera de S1"
  "9|REQ-ILU-08|negativo|iluminacion|iluminacionTeatro.feature|Fin Emergencia / Reset no cambia el estado fuera de S5"
  "10|REQ-ILU-07|negativo|iluminacion|iluminacionTeatro.feature|En S5 Modo Emergencia, Alarma de Humo e Iniciar Show no tienen efecto"
  "11|REQ-CLI-01|positivo|climatizacion|climatizacionSmartHome.feature|Regla 1: ventanas abiertas → apagar climatización y alerta sonora"
  "12|REQ-CLI-02|positivo|climatizacion|climatizacionSmartHome.feature|Regla 2: temperatura alta + presencia + ventanas cerradas → refrigeración"
  "13|REQ-CLI-03|positivo|climatizacion|climatizacionSmartHome.feature|Regla 3: temperatura alta + sin presencia + ventanas cerradas → bajo consumo"
  "14|REQ-CLI-04|positivo|climatizacion|climatizacionSmartHome.feature|Regla 4: temperatura normal + ventanas cerradas → sistema apagado"
  "15|REQ-CLI-05|negativo|climatizacion|climatizacionSmartHome.feature|Evaluación rechazada si no trae exactamente 3 condiciones"
  "16|REQ-ILU-09|negativo|iluminacion|iluminacionTeatro.feature|Evento inexistente rechazado sin cambiar el estado"
)

for caso in "${CASOS[@]}"; do
  IFS='|' read -r num req tipo modulo archivo titulo <<< "$caso"
  gherkin="$(gherkin_de "$num" "$FEATURES/$archivo")"

  body="### Trazabilidad de automatización
- **Tag Karate:** \`@Issue-$num\`
- **Requisito:** \`@$req\`
- **Tipo:** $tipo
- **Feature:** \`$FEATURES/$archivo\`

### Escenario Gherkin
\`\`\`gherkin
$gherkin
\`\`\`

### Ejecución desde el TestCase
Actions → *CI / CD Pipeline* → *Run workflow* → \`testTag = @Issue-$num\`.
El pipeline comenta el resultado en este Issue y le pone el label \`status:passed\` o \`status:failed\`."

  url="$(gh issue create --title "[TC-$num] $titulo" --body "$body" \
          --label "$req" --label "$tipo" --label "$modulo" --label "test-case")"
  creado="${url##*/}"
  if [ "$creado" != "$num" ]; then
    echo "ERROR: se creó el Issue #$creado pero se esperaba #$num. El repositorio ya tenía Issues o PRs." >&2
    exit 1
  fi
  gh project item-add "$PROJECT" --owner "$OWNER" --url "$url" >/dev/null
  echo "Issue #$num creado y agregado al Project $PROJECT"
done

echo "Listo: 16 Issues vinculados a los escenarios @Issue-1 … @Issue-16."

@api @climatizacion
Feature: Tabla de decisión del Controlador de Climatización Inteligente en una Smart Home
  Como residente de una casa inteligente
  Quiero que el climatizador decida su acción según la temperatura, la presencia y las ventanas
  Para mantener el confort sin desperdiciar energía y recibir una alerta si dejo ventanas abiertas

  # Orden del arreglo valores (confirmado con GET /definicion):
  #   [ temperatura interior > 26°C, presencia humana activa, puertas/ventanas abiertas > 3 min ]
  # reglaIndex empieza en 0: 0 = Regla 1, 1 = Regla 2, 2 = Regla 3, 3 = Regla 4

  Background:
    # Se limpia el historial del servidor para que cada evaluación quede aislada
    Given url baseUrl
    And path 'decision/climatizacion/reiniciar'
    When method post
    Then status 200
    And match response == { ok: true }

  @REQ-CLI-01 @Issue-11 @smoketest @positivo
  Scenario Outline: Verificar que con ventanas abiertas se apaga la climatización y se emite alerta sonora (temperatura alta: <temperaturaAlta>, presencia: <presencia>)
    Given url baseUrl
    And path 'decision/climatizacion/evaluar'
    And request { valores: [<temperaturaAlta>, <presencia>, <ventanasAbiertas>] }
    When method post
    Then status 200
    And match response == { valores: [<temperaturaAlta>, <presencia>, <ventanasAbiertas>], accion: 'Apagar sistema de climatización y emitir alerta sonora', reglaIndex: 0, noDefinida: false }

    Examples:
      | temperaturaAlta | presencia | ventanasAbiertas |
      | true            | true      | true             |
      | true            | false     | true             |
      | false           | true      | true             |
      | false           | false     | true             |

  @REQ-CLI-02 @Issue-12 @regression @positivo
  Scenario: Verificar que con temperatura alta, presencia y ventanas cerradas se enciende el aire acondicionado en modo refrigeración
    Given url baseUrl
    And path 'decision/climatizacion/evaluar'
    And request { valores: [true, true, false] }
    When method post
    Then status 200
    And match response == { valores: [true, true, false], accion: 'Encender aire acondicionado en modo refrigeración', reglaIndex: 1, noDefinida: false }

  @REQ-CLI-03 @Issue-13 @regression @positivo
  Scenario: Verificar que con temperatura alta, habitación vacía y ventanas cerradas se mantiene el modo de bajo consumo energético
    Given url baseUrl
    And path 'decision/climatizacion/evaluar'
    And request { valores: [true, false, false] }
    When method post
    Then status 200
    And match response == { valores: [true, false, false], accion: 'Mantener en modo de bajo consumo energético', reglaIndex: 2, noDefinida: false }

  @REQ-CLI-04 @Issue-14 @regression @positivo
  Scenario Outline: Verificar que con temperatura normal y ventanas cerradas se mantiene el sistema apagado (presencia: <presencia>)
    Given url baseUrl
    And path 'decision/climatizacion/evaluar'
    And request { valores: [false, <presencia>, false] }
    When method post
    Then status 200
    And match response == { valores: [false, <presencia>, false], accion: 'Mantener sistema apagado', reglaIndex: 3, noDefinida: false }

    Examples:
      | presencia |
      | true      |
      | false     |

  # ---------------------------------------------------------------------------
  # Escenario negativo: validación de la entrada (ver HALLAZGOS en DOCUMENTACION_PROCESO.md)
  # ---------------------------------------------------------------------------

  @REQ-CLI-05 @Issue-15 @regression @negativo
  Scenario Outline: Verificar que se rechaza una evaluación que no trae exactamente 3 condiciones (<caso>)
    Given url baseUrl
    And path 'decision/climatizacion/evaluar'
    And request <cuerpo>
    When method post
    Then status 400
    And match response == { error: 'Se esperaban 3 valores booleanos' }
    # La petición rechazada no debe quedar registrada como una evaluación
    Given url baseUrl
    And path 'decision/climatizacion/definicion'
    When method get
    Then status 200
    And match response.historial == []

    Examples:
      | caso              | cuerpo                                   |
      | solo 2 valores    | { valores: [true, true] }                |
      | 4 valores         | { valores: [true, true, false, false] }  |
      | sin campo valores | {}                                       |

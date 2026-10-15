@api @iluminacion
Feature: Transición de estados del Sistema de Iluminación Inteligente en Auditorio Teatral
  Como técnico de iluminación del auditorio
  Quiero que el sistema de luces cambie de estado solo ante los eventos permitidos
  Para garantizar un show ordenado y una respuesta inmediata ante una emergencia

  Background:
    * def estados = read('classpath:helpers/estadosIluminacion.json')
    * def irAEstado = 'classpath:helpers/irAEstadoIluminacion.feature'
    * def verificarEstado = 'classpath:helpers/verificarEstadoIluminacion.feature'
    * def enviarEventoValido = 'classpath:helpers/enviarEventoIluminacion.feature'
    # 1. Consultar el estado actual (el servidor es compartido y puede estar en cualquier estado)
    Given url baseUrl
    And path 'iluminacion-teatro/estado'
    When method get
    Then status 200
    * print 'Estado antes de reiniciar:', response.estadoActual
    # 2. Mover el sistema al estado inicial S1 para que cada caso sea independiente
    Given url baseUrl
    And path 'iluminacion-teatro/reiniciar'
    When method post
    Then status 200
    And match response.estadoActual == estados.S1

  # ---------------------------------------------------------------------------
  # Escenarios positivos: todas las transiciones válidas
  # ---------------------------------------------------------------------------

  @REQ-ILU-01 @Issue-1 @smoketest @positivo
  Scenario: Verificar que al reiniciar el sistema queda en el estado inicial S1 (Apagado Total)
    Given url baseUrl
    And path 'iluminacion-teatro/estado'
    When method get
    Then status 200
    And match response.estadoActual == estados.S1
    And match response.maquina.estados == [ '#(estados.S1)', '#(estados.S2)', '#(estados.S3)', '#(estados.S4)', '#(estados.S5)' ]
    And match response.maquina.eventos == [ 'Encender', 'Iniciar Show', 'Alarma de Humo', 'Fin Emergencia / Reset' ]

  @REQ-ILU-02 @Issue-2 @smoketest @positivo
  Scenario: Verificar que el evento Encender lleva el sistema de S1 (Apagado Total) a S2 (Luces de Cortesía)
    Given url baseUrl
    And path 'iluminacion-teatro/evento'
    And request { evento: 'Encender' }
    When method post
    Then status 200
    And match response contains { estadoAnterior: '#(estados.S1)', evento: 'Encender', estadoNuevo: '#(estados.S2)', valida: true }
    * call read(verificarEstado) { estadoEsperado: 'S2' }

  @REQ-ILU-03 @Issue-3 @regression @positivo
  Scenario: Verificar que Iniciar Show lleva el sistema de S2 (Luces de Cortesía) a S3 (Iluminación de Ensayo)
    * call read(irAEstado) { estadoObjetivo: 'S2' }
    Given url baseUrl
    And path 'iluminacion-teatro/evento'
    And request { evento: 'Iniciar Show' }
    When method post
    Then status 200
    And match response contains { estadoAnterior: '#(estados.S2)', evento: 'Iniciar Show', estadoNuevo: '#(estados.S3)', valida: true }
    * call read(verificarEstado) { estadoEsperado: 'S3' }

  @REQ-ILU-03 @Issue-4 @regression @positivo
  Scenario: Verificar que Iniciar Show lleva el sistema de S3 (Iluminación de Ensayo) a S4 (Escena en Vivo)
    * call read(irAEstado) { estadoObjetivo: 'S3' }
    Given url baseUrl
    And path 'iluminacion-teatro/evento'
    And request { evento: 'Iniciar Show' }
    When method post
    Then status 200
    And match response contains { estadoAnterior: '#(estados.S3)', evento: 'Iniciar Show', estadoNuevo: '#(estados.S4)', valida: true }
    * call read(verificarEstado) { estadoEsperado: 'S4' }

  @REQ-ILU-04 @Issue-5 @regression @positivo
  Scenario Outline: Verificar que la Alarma de Humo lleva a S5 (Modo Emergencia) desde el estado operativo <estadoInicial>
    * call read(irAEstado) { estadoObjetivo: '<estadoInicial>' }
    Given url baseUrl
    And path 'iluminacion-teatro/evento'
    And request { evento: 'Alarma de Humo' }
    When method post
    Then status 200
    And match response contains { estadoAnterior: '#(estados.<estadoInicial>)', evento: 'Alarma de Humo', estadoNuevo: '#(estados.S5)', valida: true }
    * call read(verificarEstado) { estadoEsperado: 'S5' }

    Examples:
      | estadoInicial |
      | S1            |
      | S2            |
      | S3            |
      | S4            |

  @REQ-ILU-05 @Issue-6 @regression @positivo
  Scenario Outline: Verificar que Fin Emergencia / Reset devuelve el sistema a S1 cuando la alarma se activó desde <estadoPrevio>
    * call read(irAEstado) { estadoObjetivo: '<estadoPrevio>' }
    * call read(enviarEventoValido) { evento: 'Alarma de Humo' }
    * call read(verificarEstado) { estadoEsperado: 'S5' }
    Given url baseUrl
    And path 'iluminacion-teatro/evento'
    And request { evento: 'Fin Emergencia / Reset' }
    When method post
    Then status 200
    And match response contains { estadoAnterior: '#(estados.S5)', evento: 'Fin Emergencia / Reset', estadoNuevo: '#(estados.S1)', valida: true }
    * call read(verificarEstado) { estadoEsperado: 'S1' }

    Examples:
      | estadoPrevio |
      | S1           |
      | S2           |
      | S3           |
      | S4           |

  # ---------------------------------------------------------------------------
  # Escenarios negativos: transiciones no definidas (el estado NO debe cambiar)
  # La API responde 200 con valida=false y noDefinida=true
  # ---------------------------------------------------------------------------

  @REQ-ILU-06 @Issue-7 @regression @negativo
  Scenario Outline: Verificar que Iniciar Show no cambia el estado cuando el sistema está en <estadoInicial>
    * call read(irAEstado) { estadoObjetivo: '<estadoInicial>' }
    Given url baseUrl
    And path 'iluminacion-teatro/evento'
    And request { evento: 'Iniciar Show' }
    When method post
    Then status 200
    And match response contains { estadoAnterior: '#(estados.<estadoInicial>)', estadoNuevo: '#(estados.<estadoInicial>)', valida: false, noDefinida: true }
    * call read(verificarEstado) { estadoEsperado: '<estadoInicial>' }

    Examples:
      | estadoInicial |
      | S1            |
      | S4            |

  @REQ-ILU-08 @Issue-8 @regression @negativo
  Scenario Outline: Verificar que Encender no cambia el estado cuando el sistema está en <estadoInicial>
    * call read(irAEstado) { estadoObjetivo: '<estadoInicial>' }
    Given url baseUrl
    And path 'iluminacion-teatro/evento'
    And request { evento: 'Encender' }
    When method post
    Then status 200
    And match response contains { estadoAnterior: '#(estados.<estadoInicial>)', estadoNuevo: '#(estados.<estadoInicial>)', valida: false, noDefinida: true }
    * call read(verificarEstado) { estadoEsperado: '<estadoInicial>' }

    Examples:
      | estadoInicial |
      | S2            |
      | S3            |
      | S4            |
      | S5            |

  @REQ-ILU-08 @Issue-9 @regression @negativo
  Scenario Outline: Verificar que Fin Emergencia / Reset no cambia el estado cuando el sistema está en <estadoInicial>
    * call read(irAEstado) { estadoObjetivo: '<estadoInicial>' }
    Given url baseUrl
    And path 'iluminacion-teatro/evento'
    And request { evento: 'Fin Emergencia / Reset' }
    When method post
    Then status 200
    And match response contains { estadoAnterior: '#(estados.<estadoInicial>)', estadoNuevo: '#(estados.<estadoInicial>)', valida: false, noDefinida: true }
    * call read(verificarEstado) { estadoEsperado: '<estadoInicial>' }

    Examples:
      | estadoInicial |
      | S1            |
      | S2            |
      | S3            |
      | S4            |

  @REQ-ILU-07 @Issue-10 @regression @negativo
  Scenario Outline: Verificar que en S5 (Modo Emergencia) el evento <evento> no tiene efecto
    * call read(irAEstado) { estadoObjetivo: 'S5' }
    Given url baseUrl
    And path 'iluminacion-teatro/evento'
    And request { evento: '<evento>' }
    When method post
    Then status 200
    And match response contains { estadoAnterior: '#(estados.S5)', evento: '<evento>', estadoNuevo: '#(estados.S5)', valida: false, noDefinida: true }
    * call read(verificarEstado) { estadoEsperado: 'S5' }

    Examples:
      | evento         |
      | Alarma de Humo |
      | Iniciar Show   |

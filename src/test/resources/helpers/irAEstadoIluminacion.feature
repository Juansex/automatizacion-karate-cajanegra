@ignore
Feature: Helper - llevar la máquina de iluminación desde S1 hasta un estado objetivo
  Precondición: el sistema está en S1 (lo garantiza el reinicio del Background del feature que llama).
  Recibe: estadoObjetivo ('S1'..'S5').
  Aplica la secuencia mínima de eventos válidos y verifica que se llegó al estado objetivo.

  Scenario: Ir al estado objetivo
    * def estados = read('classpath:helpers/estadosIluminacion.json')
    * def secuencias =
      """
      {
        S1: [],
        S2: ['Encender'],
        S3: ['Encender', 'Iniciar Show'],
        S4: ['Encender', 'Iniciar Show', 'Iniciar Show'],
        S5: ['Alarma de Humo']
      }
      """
    * def toEventPayload = function(eventName) { return { evento: eventName } }
    * def pasos = karate.map(secuencias[estadoObjetivo], toEventPayload)
    * call read('classpath:helpers/enviarEventoIluminacion.feature') pasos
    * call read('classpath:helpers/verificarEstadoIluminacion.feature') { estadoEsperado: '#(estadoObjetivo)' }

@ignore
Feature: Helper - consultar el estado actual de la iluminación y compararlo con el esperado
  Recibe: estadoEsperado ('S1'..'S5').

  Scenario: Verificar estado actual
    * def estados = read('classpath:helpers/estadosIluminacion.json')
    Given url baseUrl
    And path 'iluminacion-teatro/estado'
    When method get
    Then status 200
    And match response.estadoActual == estados[estadoEsperado]

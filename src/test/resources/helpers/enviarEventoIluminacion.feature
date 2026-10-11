@ignore
Feature: Helper - enviar un evento VÁLIDO a la máquina de iluminación (solo para preparar estados)
  Recibe: evento. La baseUrl viene de karate-config.js.
  Falla si la transición no es válida, porque una preparación incorrecta invalidaría la prueba.

  Scenario: Enviar evento de preparación
    Given url baseUrl
    And path 'iluminacion-teatro/evento'
    And request { evento: '#(evento)' }
    When method post
    Then status 200
    And match response.valida == true

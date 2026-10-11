package runner;

import com.intuit.karate.Results;
import com.intuit.karate.Runner;
import com.intuit.karate.junit5.Karate;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

public class cajanegra2runner {
    //@Karate.Test
    //Karate testAll() {
    //    return Karate.run("classpath:features").relativeTo(getClass());
    //}
   @Test
   void testParallel() {
       Results results = Runner.path("classpath:features")
               .outputCucumberJson(true) // <--- AQUÍ SE CONFIGURA
               .parallel(1);             // Define el número de hilos concurrentes

       // Aserción para asegurar que el build de Gradle/Maven falle si alguna prueba no pasa
       assertEquals(0, results.getFailCount(), results.getErrorMessages());
   }
}




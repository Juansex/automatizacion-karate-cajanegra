function fn() {
    var env = karate.env || 'dev';

    // URL base de las APIs del taller de caja negra (una sola fuente para todos los features)
    var urls = {
        dev: 'https://taller-de-tecnicas-de-prueba-de-caja.onrender.com/api/'
    };

    var config = {
        env: env,
        baseUrl: urls[env] || urls.dev
    };

    // Render "duerme" el servicio: la primera petición puede tardar ~20 s (arranque en frío)
    karate.configure('connectTimeout', 60000);
    karate.configure('readTimeout', 60000);

    // Todas las APIs responden JSON. El Content-Type del body JSON lo pone Karate automáticamente.
    karate.configure('headers', { Accept: 'application/json' });

    // Simplifica y formatea el JSON/XML de los Requests y Responses en la consola
    karate.configure('logPrettyRequest', true);
    karate.configure('logPrettyResponse', true);

    return config;
}

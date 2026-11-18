> En v1.0.0, Google queda fuera de la evaluación y oculto por `EvaluationFeatures` y la configuración visual de `LapticonApp`. Activar solo la variable del servicio no muestra su acceso. Las instrucciones de Google son para una integración futura. Consulta la [configuración actual](docs/CONFIGURACION.md).

# Conectar búsqueda de vuelos y Google

## Vuelos por ruta

En **Mi viaje**, cuando no hay un viaje activo, elige origen y destino directamente en los selectores y selecciona fecha. Solo hay seis opciones: **Bogotá (BOG), Medellín (MDE), Cali (CLO), New York (JFK), Miami (MIA) y Washington (IAD)**. Los códigos se envían automáticamente a la API; no hay que escribir el número del vuelo. Origen y destino deben ser diferentes. Al buscar se muestran los vuelos devueltos por el proveedor para esa ruta y fecha. Al elegir uno se completan número, ciudades y fecha, y se solicita confirmación antes de publicarlo en el backend del profesor. Cancelar conserva los resultados; los errores permiten reintentar. Si no hay resultados o el proveedor falla, no se ofrece registro manual sin validar.

Se utiliza un aeropuerto por ciudad: New York corresponde a JFK y Washington a Dulles/IAD; no se agregan automáticamente otros aeropuertos metropolitanos. Referencias oficiales: [JFK](https://www.jfkairport.com/flights), [Dulles](https://www.flydulles.com/airport-overview) y [MDE](https://www.aeropuertorionegro.co/). Esta restricción pertenece a los selectores de la app; el servicio de vuelos sigue siendo genérico y no necesita desplegarse de nuevo.

La búsqueda necesita fecha: un número de vuelo no identifica una salida concreta sin ella. El día inicial es hoy. La disponibilidad depende de cobertura y suscripción, y no se inventan resultados si la configuración falta o el proveedor falla.

### Servicio incluido

`flight_proxy/` es un servicio Node independiente con llamadas reales a AeroDataBox vía RapidAPI, búsqueda de aeropuertos, filtrado por ruta y fecha, exclusión de cancelados, deduplicación, caché breve y límite de consultas por usuario. Consulta dos ventanas de 12 horas con información de ambos extremos del vuelo. No es un reemplazo del backend de negocio.

1. Obtén una suscripción de AeroDataBox con acceso a búsqueda de aeropuertos, consulta de aeropuerto y horarios de vuelos. Revisa las cuotas y cargos del proveedor antes de usar una clave.
2. En `flight_proxy/`, copia `.env.example` a `.env` y completa `RAPIDAPI_KEY`. Ese archivo está ignorado por Git. No copies la clave a Dart ni a `config/android.local.json`.
3. Con Node 22.9 o posterior, ejecuta `npm start` desde esa carpeta. No requiere paquetes externos. Ejecuta `npm test` para sus pruebas.
4. Para Android, aloja este servicio con una URL **HTTPS**. En un alojamiento que inyecta variables, configura `RAPIDAPI_KEY`, `PORT` y, si cambia, `AUTH_API_BASE_URL`. Comando de inicio: `node server.mjs`.
5. Copia `config/android.example.json` a `config/android.local.json`, completa `FLIGHT_SEARCH_BASE_URL` con el origen HTTPS (sin `/api/...`) y ejecuta:

```powershell
powershell -ExecutionPolicy Bypass -File .\herramientas.ps1 run --dart-define-from-file=config/android.local.json
```

El servicio exige el ID token del mismo usuario. Para comprobarlo consulta el perfil propio en el backend del profesor, que valida Firebase; no necesita Firebase Admin ni claves de servicio. Si el backend no acepta la sesión o el usuario aún no tiene perfil, no se consulta el proveedor.

Contrato del servicio: `GET /api/flights/airports?q=Bogota` devuelve `{iata,label}[]`; `GET /api/flights/search?origin=BOG&destination=MAD&date=AAAA-MM-DD` devuelve `{number,airline,departure,origin:{iata,city,country},destination:{iata,city,country}}[]`. `departure` conserva hora local del aeropuerto de salida. No se afirma cobertura total ni se incorporan reservas o compra de tiquetes.

Documentación oficial usada: [AeroDataBox OpenAPI](https://doc.aerodatabox.com/docs/openapi-rapidapi-v1.json). No se ha usado una suscripción real ni desplegado el servicio durante esta entrega.

## Google

El código de intercambio Google → Firebase → perfil ya existe. Se habilita mediante `GOOGLE_SIGN_IN_ENABLED=true`; permanece deshabilitado por defecto para no ofrecer un proveedor sin configurar. El JSON actual tiene cliente OAuth web, pero no registra la firma local.

En Firebase, proyecto `lapticon-eba31`:

1. Authentication → Sign-in method → habilita Google y configura correo de soporte.
2. Configuración del proyecto → app Android `com.lapticon.app` → registra SHA-1:

```text
FF:36:2F:42:07:76:E0:66:42:D9:50:1B:10:15:2D:61:F7:BD:B6:56
```

3. Descarga el JSON actualizado y reemplaza `android/app/google-services.json`.
4. Ejecuta `powershell -ExecutionPolicy Bypass -File .\verificar-google.ps1`. Comprueba paquete, cliente OAuth web y firma local sin mostrar claves. En otro computador la firma puede ser distinta.
5. Pon `GOOGLE_SIGN_IN_ENABLED: true` en el JSON de configuración local (JSON sin comillas alrededor de `true`), o ejecuta `flutter run --dart-define=GOOGLE_SIGN_IN_ENABLED=true`. Detén y recompila; hot reload no actualiza recursos Android.
6. Prueba acceso Google, cancelar el selector, completar perfil si no existe, restaurar sesión y cerrarla. La firma de distribución también deberá registrarse si más adelante cambia el tipo de APK.

Fuente: [Firebase: acceso con proveedores](https://firebase.google.com/docs/auth/flutter/federated-auth). Estas verificaciones de consola y de cuenta real están pendientes; habilitar la bandera no las reemplaza.

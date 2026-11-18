# Configuración y solución de problemas

## Entorno Android

Trabaja desde la carpeta con `pubspec.yaml`, con Flutter 3.27.4/Dart 3.6.2, JDK 17 y Android SDK. `flutter doctor -v` muestra las instalaciones detectadas. Si faltan licencias, ejecuta `flutter doctor --android-licenses` y revisa los términos presentados.

Selecciona JDK 17 como Gradle JDK en Android Studio. Si necesitas `org.gradle.java.home`, colócalo en el archivo de usuario `~/.gradle/gradle.properties`, con tu ruta real. No incluyas una ruta personal en el archivo del repositorio.

## Firebase

El paquete es `com.lapticon.app`. Coloca el JSON autorizado en `android/app/google-services.json`; renombra la descarga si contiene un sufijo como `(3)`. Debe corresponder al Firebase que valida la API. La configuración de clase conocida utiliza `lapticon-eba31`.

El archivo conecta la app, pero no concede acceso administrativo a la consola. Correo/contraseña debe estar habilitado por el dueño del proyecto. Un Firebase diferente puede generar tokens rechazados por el backend.

Sin configuración válida se conserva el arranque con la conexión pendiente y las acciones reales bloqueadas. Detén y recompila después de cambiar el JSON. No copies contraseñas de Postman, tokens ni claves de cuenta de servicio al código.

## Configuración local de la app

Se lee con `--dart-define-from-file=config/android.local.json`. Crea el archivo desde `config/android.example.json` y conserva tu configuración al actualizar Git.

| Clave | Uso |
| --- | --- |
| `API_BASE_URL` | Origen HTTPS del backend; valor inicial `https://lapticon-backend.onrender.com` |
| `FLIGHT_SEARCH_BASE_URL` | Origen HTTPS del proxy; ejemplo desplegado `https://lapticon-propuesta.onrender.com` |
| `GOOGLE_SIGN_IN_ENABLED` | Mantener `false` para esta entrega |
| `CHAT_FIRESTORE_ENABLED` | Mantener `false` para esta entrega |

Las URL no deben contener rutas `/api/...`, credenciales, consultas ni fragmentos. Los accesos de Google y chat también están ocultos por `EvaluationFeatures` y los valores predeterminados de `LapticonApp`. Cambiar una bandera de servicios no los incorpora a la evaluación.

En la configuración Flutter de Android Studio usa `lib/main.dart` y añade `--dart-define-from-file=config/android.local.json` a los argumentos de ejecución. Los archivos locales de cada equipo no se publican por Git.

## Servicio de vuelos

La app puede utilizar el despliegue HTTPS existente; no es necesario ejecutar Node en cada computador. Para desarrollar el proxy incluido:

```powershell
cd flight_proxy
Copy-Item .env.example .env
# Completar RAPIDAPI_KEY en .env, sin publicarla.
npm start
```

Requiere Node >=22.9; el entorno de esta entrega tiene Node 24.22.3. No utiliza paquetes externos. El archivo `.env` define:

| Variable | Uso |
| --- | --- |
| `RAPIDAPI_KEY` | Clave de AeroDataBox mediante RapidAPI, con acceso a los endpoints usados |
| `AUTH_API_BASE_URL` | Backend que verifica el token y el perfil; por defecto el de clase |
| `PORT` | Puerto de escucha; 8080 por defecto o el asignado por el alojamiento |

Si 8080 está ocupado, utiliza otro puerto en el entorno local. El servidor local usa HTTP; **la app exige HTTPS**, así que Android debe apuntar al despliegue HTTPS. No se coloca la clave RapidAPI en el APK.

En Render: raíz `flight_proxy`, construcción `npm install`, inicio `npm start`. Configura la clave y el backend como variables del servicio; el servidor acepta el `PORT` proporcionado por el alojamiento. También admite `node server.mjs` como inicio. `npm server.mjs` es incorrecto.

## Errores habituales

| Síntoma | Comprobación o solución |
| --- | --- |
| Falta `android.local.json` | Ejecutar desde la raíz y crear el archivo desde el ejemplo |
| Firebase pendiente | Revisar ubicación, formato y paquete del JSON; detener y recompilar |
| Sesión rechazada 401 | Ingresar de nuevo y confirmar que Firebase y backend corresponden al mismo proyecto |
| Permisos 403 | Revisar la cuenta y la asignación de la encomienda; no modificar UID o tokens en el cliente |
| Catálogo sin configurar o sin resultados | Revisar URL HTTPS, clave del servidor, suscripción, cobertura, ruta y fecha |
| ADB `device offline` | Cerrar la ejecución, hacer Cold Boot del emulador y revisar `flutter devices`; reiniciar ADB si persiste |
| Almacenamiento insuficiente al instalar | Liberar almacenamiento o usar otro AVD. Borrar los datos del emulador elimina sus cuentas y apps |
| Avisos de Java o SDK XML | Confirmar JDK 17 y SDK compatibles; distinguir avisos de un error final de compilación o instalación |

Los problemas del emulador no requieren cambiar el paquete Android o el Firebase compartido. Los pendientes del servidor se registran en [Limitaciones](LIMITACIONES.md).

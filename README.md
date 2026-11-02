# Lapticon para Android

Flujo de autenticación Android implementado con Flutter: correo y contraseña, Google, registro, recuperación, restauración y cierre de sesión. Conserva las cuatro pantallas del prototipo y agrega inicio protegido y finalización del perfil.

**Estado actual:** falta el Firebase del profesor. El APK arranca con **Conexión con Firebase pendiente** y bloquea las operaciones de autenticación. No hay un modo de sesión falsa. Los servicios simulados existen solo en las pruebas.

Consulta **[CONEXION_FIREBASE.md](CONEXION_FIREBASE.md)** para completar la conexión, registrar la firma Android y configurar la dirección de la API. No introduzcas contraseñas administrativas ni claves de Firebase Admin en la app.

## Ejecutar en Android

Abre esta carpeta, donde está `pubspec.yaml`, en Android Studio. Inicia un emulador o conecta un teléfono por USB. Conserva JDK 17 para Gradle 8.3. En este computador, `android/gradle.properties` ya contiene su ruta; adáptala si cambias de equipo.

Desde PowerShell en esta carpeta:

```powershell
powershell -ExecutionPolicy Bypass -File .\herramientas.ps1 pub get
powershell -ExecutionPolicy Bypass -File .\herramientas.ps1 devices
powershell -ExecutionPolicy Bypass -File .\herramientas.ps1 run -d emulator-5554
```

Sustituye `emulator-5554` por el identificador que muestre `devices`. También puedes usar los comandos equivalentes `flutter pub get`, `flutter devices` y `flutter run -d ...`; el script evita problemas con el wrapper `flutter.bat` de este equipo.

Requisitos de esta entrega: Flutter 3.27.4, Dart 3.6.2, JDK 17, Android SDK y Android 6.0/API 23 o posterior. Las versiones de Firebase y Google están limitadas a las compatibles con esta cadena de compilación y fijadas en `pubspec.lock`. La autenticación web e iOS no forma parte de esta entrega; los archivos web anteriores se conservan como referencia visual.

## Flujo implementado

- Firebase administra las identidades, la sesión persistente y las contraseñas. El cliente no guarda contraseñas ni mantiene un almacén propio de tokens.
- Cada petición de perfiles obtiene un ID token y lo envía en `Authorization: Bearer`. No se registra el token en los logs ni se siguen redirecciones HTTP.
- Login consulta `GET /api/users/{uid}`. Una cuenta nueva guarda nombre, apellido y correo con `POST /api/users/register`. Un perfil existente nunca se sobrescribe al ingresar.
- Una cuenta autenticada sin perfil debe completarlo. Si el guardado falla, puede reintentarse sin recrear la cuenta Firebase. El reintento consulta primero si el perfil ya existe.
- Ante un 401 se fuerza una renovación y se reintenta una sola vez. Un segundo 401 cierra la sesión. Un 403 conserva la sesión y comunica el error de permisos. Hay mensajes separados para red, tiempo agotado y errores del servidor.
- La recuperación solo confirma la solicitud después de que Firebase la acepte. La respuesta no revela si un correo tiene cuenta. Se utiliza el manejador de recuperación alojado por Firebase.
- La pantalla protegida muestra nombre, correo y cierre de sesión. Las rutas se comprueban también al abrirlas directamente. Roles, viajes y encomiendas quedan fuera de esta etapa.

## Organización

| Elemento | Responsabilidad |
| --- | --- |
| `lib/auth/` | Contrato de autenticación, adaptador Firebase, estado de sesión y operaciones |
| `lib/data/` | Perfiles, cliente HTTP y recuperación de tokens |
| `lib/screens/` | Bienvenida, login, registro, recuperación, perfil pendiente e inicio protegido |
| `lib/widgets/` y `lib/theme/` | Componentes visuales, accesibilidad, tema e ilustración local |
| `config/android.example.json` | Ejemplo de `API_BASE_URL`; no contiene valores secretos |
| `test/` | Pruebas de servicios, API e interfaz con servicios simulados |
| `integration_test/` y `test_driver/` | Comprobación del arranque sin Firebase sobre Android real o emulado |

Los controles visuales reciben sus datos a través de `AuthScope`. `AuthController` coordina `AuthService` y `UserRepository`; el código real usa `FirebaseAuthService` y `ApiUserRepository`. Se pueden inyectar servicios de prueba sin cambiar las pantallas.

## Pruebas y compilación

```powershell
powershell -ExecutionPolicy Bypass -File .\herramientas.ps1 analyze
powershell -ExecutionPolicy Bypass -File .\herramientas.ps1 test
powershell -ExecutionPolicy Bypass -File .\herramientas.ps1 build apk --debug
```

Las pruebas verifican validación, errores, cancelación de Google, reintento de perfil, sesión restaurada, acceso protegido, cierre y limpieza de sesión, concurrencia de envíos, contrato HTTP y renovación limitada de tokens. También revisan el contraste y diseños de 320×568, 430×932 y 1280×800 con texto al 200 % y teclado simulado.

Con un emulador encendido y **sin** `google-services.json`, la prueba de integración verifica la conexión pendiente y guarda una captura de la pantalla de login:

```powershell
powershell -ExecutionPolicy Bypass -File .\herramientas.ps1 drive --driver=test_driver/integration_test.dart --target=integration_test/unconfigured_android_test.dart -d emulator-5554
```

El APK de desarrollo se genera en `build/app/outputs/flutter-apk/app-debug.apk`. No abrirá una sesión real hasta configurar y recompilar el Firebase correcto. La compilación puede emitir avisos del SDK y AGP antiguos aunque termine correctamente.

## Entrega y configuración local

`android/app/google-services.json`, `config/*.local.json`, archivos de firma y propiedades locales quedan fuera del ZIP de entrega. Conserva los archivos de tu configuración por separado. Si ya hay una API válida no necesitas modificar nada: el destino predeterminado es `https://lapticon-backend.onrender.com`.

La guía Word de ejecución entregada durante el prototipo sigue sirviendo para iniciar un emulador, pero sus referencias a sesiones de demostración pertenecen a la etapa visual anterior. Para activar esta versión, utiliza `CONEXION_FIREBASE.md`.

## Recursos

Fuente Manrope incluida localmente con su licencia OFL. Iconos Material de Flutter e ilustración vectorial local. Las capturas originales de la carpeta `capturas/` documentan el prototipo visual anterior; las verificaciones Android de esta etapa se guardan en `capturas/autenticacion/`.

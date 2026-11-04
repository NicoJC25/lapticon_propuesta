# Lapticon para Android

Aplicación Android en Flutter. **Fase 1:** autenticación con correo y contraseña, Google, registro, recuperación, restauración y cierre de sesión. **Fase 2:** selección de rol (remitente o viajero), menús por rol y creación de encomiendas con `POST /api/encomiendas`.

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
- Las rutas protegidas se comprueban también al abrirlas directamente. Con el perfil completo, la sesión pasa a la selección de rol (fase 2).

## Fase 2: roles y encomiendas

Corresponde a las prácticas 2 y 3 del plan (semana 2: roles y crear encomienda).

```
Login ─► Perfil completo ─► RoleRedirectorScreen ─┬─► Elegir rol (sin rol guardado)
                                                  ├─► Menú remitente ─► Crear encomienda
                                                  └─► Menú viajero
```

- **Elegir rol.** Tras el login, un usuario sin rol elige *remitente* o *viajero*. Puede cambiarlo desde su menú con **Cambiar de rol**.
- **Dónde vive el rol.** Se lee primero del perfil del backend (campo `rol`) y, si no está, de una caché en `SharedPreferences` guardada **por uid** (dos cuentas en el mismo teléfono no comparten rol). Al elegir se guarda en la caché y se envía con `PUT /api/users/{uid}` (`nombre`, `apellido`, `rol`).
- **Limitación conocida del backend.** El modelo `Usuario` del Swagger no tiene campo `rol`. Si el servidor no lo devuelve tras el `PUT`, la app muestra el aviso *Rol guardado en el teléfono*: funciona en ese dispositivo, pero no se recupera en otro. Cuando el backend agregue el campo, el rol se sincronizará sin cambiar la app.
- **Menú remitente.** *Crear encomienda* está activo. *Mis encomiendas* y *Calificar viajeros* aparecen como pendientes de las semanas 3 y 4.
- **Menú viajero.** *Registrar viaje*, *Buscar encomiendas* y *Mis entregas* aparecen como pendientes de las semanas 3 y 4.
- **Crear encomienda.** Origen y destino se eligen con país y ciudad (`GET /api/ciudades/paises` y `GET /api/ciudades/ciudades-por-pais`, rutas públicas sin token, con búsqueda que ignora tildes). Se valida que destino ≠ origen, que haya descripción (máx. 300 caracteres) y que el valor sea un entero entre 1 y 100.000.000. Moneda: COP, USD o EUR.
- **Fecha límite opcional.** El `POST` del Swagger no documenta `fechaVencimiento`; la app la envía solo si el usuario la elige y la pantalla de confirmación muestra la fecha que devolvió el servidor, o avisa si no la confirmó.
- **Errores.** Los 400 muestran el mensaje `error` de la API; red, tiempo agotado, 5xx y sesión vencida reutilizan el manejo de la fase 1 (renovación del token una sola vez ante 401). El botón se bloquea mientras se publica.

Preguntas abiertas para el profesor: si el backend agregará `rol` al modelo `Usuario`, si el `POST` acepta `fechaVencimiento` y qué valores admite `moneda`.

## Organización

| Elemento | Responsabilidad |
| --- | --- |
| `lib/auth/` | Contrato de autenticación, adaptador Firebase, estado de sesión y operaciones |
| `lib/data/` | Cliente HTTP compartido (`api_client.dart`), perfiles y encomiendas |
| `lib/roles/` | Rol del usuario, caché por uid y `RoleController` |
| `lib/screens/` | Acceso (fase 1); selección de rol, redirector, menús y crear encomienda (fase 2) |
| `lib/widgets/` y `lib/theme/` | Componentes visuales, accesibilidad, tema e ilustración local |
| `config/android.example.json` | Ejemplo de `API_BASE_URL`; no contiene valores secretos |
| `test/` | Pruebas de servicios, API e interfaz con servicios simulados |
| `integration_test/` y `test_driver/` | Comprobación del arranque sin Firebase sobre Android real o emulado |

Los controles visuales reciben sus datos a través de `AuthScope`, `RoleScope` y `ShipmentScope`. `AuthController` coordina `AuthService` y `UserRepository`; `RoleController` escucha la sesión y decide el rol; el código real usa `FirebaseAuthService`, `ApiUserRepository`, `SharedPreferencesRoleStore` y `ApiShipmentRepository`. Se pueden inyectar servicios de prueba sin cambiar las pantallas.

## Pruebas y compilación

```powershell
powershell -ExecutionPolicy Bypass -File .\herramientas.ps1 analyze
powershell -ExecutionPolicy Bypass -File .\herramientas.ps1 test
powershell -ExecutionPolicy Bypass -File .\herramientas.ps1 build apk --debug
```

Las pruebas verifican validación, errores, cancelación de Google, reintento de perfil, sesión restaurada, acceso protegido, cierre y limpieza de sesión, concurrencia de envíos, contrato HTTP y renovación limitada de tokens. En la fase 2 se agregan: elección, restauración y cambio de rol, caché separada por uid, prioridad del rol del servidor, contrato de `POST /api/encomiendas` y de las rutas de ciudades, validación del formulario, reintento tras error y bloqueo del botón mientras se publica. También revisan el contraste y diseños de 320×568, 430×932 y 1280×800 con texto al 200 % y teclado simulado.

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

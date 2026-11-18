# Lapticon Android

**Versión 1.0.0 · Primera versión funcional para evaluación académica.**

Lapticon conecta a quienes envían encomiendas con viajeros que pueden llevarlas en su ruta. Está desarrollada en Flutter y Dart para Android. La entrega reúne registro de usuarios, encomiendas, viajes e interacción sin chat, con seguimiento, entrega y calificaciones.

El funcionamiento real requiere el Firebase y la API del profesor, además del catálogo de vuelos. Los archivos locales no se descargan con Git. Sin configuración Firebase válida, la app abre e indica **Conexión con Firebase pendiente**; no simula el ingreso.

## Funciones de esta versión

- Registro e ingreso con correo y contraseña, recuperación, sesión persistente y cierre de sesión.
- Elección de rol y menús para remitente y viajero.
- Creación y consulta de encomiendas por estado.
- Selección de vuelo por ciudades y fecha, registro y cancelación del viaje.
- Búsqueda y toma de encomiendas de la ruta, marcado de entrega `recibida` y calificaciones.
- Regreso fijo, confirmación de descarte y bloqueo de acciones durante envíos.

Chat, chatbot, Google, matching con IA y vencimientos programados están **fuera del alcance evaluado**. Chat y Google conservan su código, con accesos ocultos. Hay restricciones del servidor documentadas en [Limitaciones y pendientes](docs/LIMITACIONES.md).

## Requisitos

| Componente | Requisito o versión utilizada |
| --- | --- |
| Flutter | 3.27.4, estable |
| Dart | 3.6.2, incluido con ese Flutter |
| JDK para Gradle | 17 |
| Android | Android 6.0/API 23 o posterior; emulador probado con API 35 |
| Herramientas | Android Studio, Android SDK y licencias aceptadas |
| Red | Internet para Firebase, backend y catálogo |

`pubspec.lock` fija las dependencias de la entrega. Node solo hace falta para trabajar en `flight_proxy/`; no se necesita para utilizar un proxy ya desplegado.

## Ejecutar desde cero

### 1 Descargar y preparar

```powershell
git clone --branch main https://github.com/NicoJC25/lapticon_propuesta.git
cd lapticon_propuesta
flutter --version
flutter doctor -v
flutter pub get
```

Si ya tienes el proyecto, ejecuta los comandos desde **la carpeta con `pubspec.yaml`**. En el equipo original se llama `outputs/entrega-semana-cuatro`; cambiar a `main` no modifica ese nombre.

Selecciona JDK 17 como Gradle JDK en Android Studio. Si Flutter detecta otro, usa `flutter config --jdk-dir "RUTA_AL_JDK_17"`, sustituyendo el texto por tu ruta real. No agregues rutas personales al `android/gradle.properties` del repositorio.

### 2 Configurar los servicios

Coloca el archivo Android del profesor en **`android/app/google-services.json`**. Debe corresponder a `com.lapticon.app` y al mismo Firebase que valida el backend. Git lo excluye.

Crea la configuración local si todavía no existe:

```powershell
if (!(Test-Path "config/android.local.json")) {
    Copy-Item "config/android.example.json" "config/android.local.json"
}
```

Revisa su contenido:

```json
{
  "API_BASE_URL": "https://lapticon-backend.onrender.com",
  "FLIGHT_SEARCH_BASE_URL": "https://lapticon-propuesta.onrender.com",
  "GOOGLE_SIGN_IN_ENABLED": false,
  "CHAT_FIRESTORE_ENABLED": false
}
```

Las direcciones deben ser orígenes HTTPS, sin añadir `/api/...`. Son servicios externos y su disponibilidad depende de sus administradores. La clave RapidAPI va en el **servidor de vuelos**, nunca en Dart ni en este JSON. Más detalle en [Configuración](docs/CONFIGURACION.md).

### 3 Iniciar en Android

Enciende un emulador desde Android Studio o conecta un teléfono con depuración USB y autoriza el equipo.

```powershell
flutter devices
flutter run -d emulator-5554 --dart-define-from-file=config/android.local.json
```

Sustituye `emulator-5554` por tu ID de dispositivo. Si `flutter.bat` falla en Windows, utiliza el invocador incluido:

```powershell
powershell -ExecutionPolicy Bypass -File .\herramientas.ps1 pub get
powershell -ExecutionPolicy Bypass -File .\herramientas.ps1 run -d emulator-5554 --dart-define-from-file=config/android.local.json
```

Para el botón Run de Android Studio, abre esta carpeta, usa la entrada Flutter `lib/main.dart` y agrega `--dart-define-from-file=config/android.local.json` en **Additional run args**. Detén y recompila después de cambiar Firebase o estos valores; hot reload no aplica la configuración nativa ni las constantes compiladas.

## Generar un APK

```powershell
flutter build apk --debug --dart-define-from-file=config/android.local.json
```

Se genera `build/app/outputs/flutter-apk/app-debug.apk`. Es un APK de desarrollo para evaluación. La configuración actual de release también utiliza la firma debug; publicar en tiendas requiere firma y preparación propias.

## Verificar

```powershell
flutter analyze
flutter test
```

El recorrido Android con servicios simulados guarda capturas y evita escribir datos en los servicios del salón:

```powershell
flutter drive --driver=test_driver/ux_android_driver.dart --target=integration_test/ux_android_test.dart -d emulator-5554 --no-enable-impeller
```

La aceptación con dos cuentas reales sigue siendo independiente. Consulta el [plan y los resultados de pruebas](docs/PRUEBAS.md).

## Documentación

| Documento | Contenido |
| --- | --- |
| [Configuración](docs/CONFIGURACION.md) | Firebase, Android Studio, variables, proxy y solución de problemas |
| [Manual de usuario](docs/MANUAL_USUARIO.md) | Recorridos del remitente y del viajero |
| [Arquitectura](docs/ARQUITECTURA.md) | Componentes, servicios, datos y contratos |
| [Pruebas](docs/PRUEBAS.md) | Reproducción, evidencia y aceptación pendiente |
| [Limitaciones](docs/LIMITACIONES.md) | Restricciones de v1 y solicitudes al profesor |
| [Cambios de versión](CHANGELOG.md) | Consolidación y funciones entregadas |

Las guías de fases y semanas conservadas en la raíz documentan la evolución. **Este README y `docs/` describen la versión consolidada actual.** Las capturas iniciales pertenecen al prototipo; las recientes están en `capturas/revision-ux-ui/`, con su [procedencia](capturas/revision-ux-ui/README.md).

## Configuración privada y recursos

Git excluye entornos privados, configuración local Firebase, firmas y compilaciones. No se incluyen cuentas de prueba, contraseñas, tokens ni claves Firebase Admin. Firebase administra la sesión; la app obtiene el ID token para cada petición protegida.

La fuente Manrope conserva su [licencia OFL](assets/fonts/OFL.txt). La interfaz utiliza iconos Material e ilustraciones locales. El backend de negocio y su base de datos son servicios del profesor y no forman parte del repositorio.

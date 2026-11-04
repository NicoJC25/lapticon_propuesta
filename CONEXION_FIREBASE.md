# Firebase Android: acceso con correo

## Configuración actual

- Rama: `autenticacion-lapticon`.
- Proyecto Firebase: `lapticon-eba31`.
- Identificador Android: `com.lapticon.app` (incluido en el JSON del profesor).
- API: `https://lapticon-backend.onrender.com`.
- Correo/contraseña, registro, recuperación y cierre de sesión usan servicios reales.
- Google permanece deshabilitado como **Google · Pendiente**.

En cada equipo, copia el archivo del profesor a `android/app/google-services.json`. Git lo excluye, así que no se descarga al clonar. Sin ese archivo válido, la app muestra la conexión pendiente y bloquea acciones reales. No cambies el paquete dentro del JSON: debe corresponder a una app registrada en Firebase.

No copies credenciales de Postman, tokens ni claves administrativas al código. Firebase gestiona las contraseñas y la sesión; la app obtiene su ID token para las peticiones protegidas y lo envía como `Authorization: Bearer`.

## Ejecutar

Desde la carpeta con `pubspec.yaml`, con Android conectado:

```powershell
powershell -ExecutionPolicy Bypass -File .\herramientas.ps1 pub get
powershell -ExecutionPolicy Bypass -File .\herramientas.ps1 run -d emulator-5554
```

También sirven `flutter pub get` y `flutter run`. Detén y vuelve a ejecutar tras cambiar el JSON: hot reload no recompila recursos nativos. El nuevo identificador se instala como una app distinta de `com.lapticon.lapticon`.

Usa JDK 17. Configura su ruta en tu archivo de usuario `~/.gradle/gradle.properties`, por ejemplo `org.gradle.java.home=C:/Program Files/Java/jdk-17`, adaptándola a tu equipo.

Puedes cambiar la API con `--dart-define=API_BASE_URL=https://servidor.example` o con `--dart-define-from-file=config/android.local.json`, tomando `config/android.example.json` como referencia. Los archivos `*.local.json` están ignorados.

## Verificación

La cuenta de prueba del profesor pudo ingresar mediante la API REST de Firebase (HTTP 200) y consultar su perfil protegido en el backend (HTTP 200). Esto comprueba que la API acepta el token del proyecto. No se guardaron credenciales en el código ni se imprimieron tokens.

Para comprobar en Android la inicialización nativa, correo habilitado y Google deshabilitado, con el JSON presente:

```powershell
powershell -ExecutionPolicy Bypass -File .\herramientas.ps1 drive --driver=test_driver/integration_test.dart --target=integration_test/configured_android_test.dart -d emulator-5554
```

Esta prueba cierra la sesión local y guarda `capturas/autenticacion/firebase-correo-android.png`. La prueba `unconfigured_android_test.dart` requiere quitar temporalmente el JSON y volver a compilar.

Falta comprobar manualmente el ingreso desde el formulario Android, restauración tras reiniciar, registro de una cuenta nueva y recepción del correo de recuperación. La comprobación REST no sustituye esas verificaciones.

## Google pendiente

Registra la SHA-1 de desarrollo en la app `com.lapticon.app` del mismo Firebase, habilita el proveedor y descarga un JSON actualizado. Obtén la firma con `gradlew.bat signingReport` desde `android` o desde Android Studio.

Después cambia `FirebaseAuthService.googleAvailable` a `true`, recompila y verifica acceso, cancelación y cierre de sesión. Las pruebas simuladas conservan cobertura del flujo futuro.
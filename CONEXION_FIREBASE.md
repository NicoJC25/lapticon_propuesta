# Conectar el Firebase del profesor

La autenticación Android ya está implementada. Mientras no coloques una configuración válida, la app muestra **Conexión con Firebase pendiente** y deshabilita ingresar, registrarse, Google y recuperación. Puedes recorrer las pantallas, pero no se crean sesiones de demostración. Los servicios simulados están únicamente en `test/`.

## 1 Identificar el proyecto correcto

Confirma con el profesor el Project ID del Firebase que acepta su backend. Un proyecto Firebase diferente puede permitir iniciar sesión y aun así producir 401 en la API. No es suficiente tener acceso a Firestore: necesitas poder configurar **Authentication** y las aplicaciones Android del proyecto.

No se requiere una cuenta de servicio, Firebase Admin, la contraseña del profesor ni una clave de MongoDB dentro de la aplicación.

## 2 Registrar Android y habilitar los proveedores

En Configuración del proyecto de Firebase, registra o selecciona una aplicación Android con este nombre de paquete exacto:

```text
com.lapticon.lapticon
```

Si el profesor exige otro paquete, habrá que alinear el identificador del proyecto Android con ese registro antes de conectar. No reutilices un JSON de otra app cambiando sus valores a mano.

En Authentication, habilita **Correo electrónico y contraseña** y **Google**. Completa el correo de soporte que solicite Google. Si el consentimiento OAuth del proyecto está limitado a usuarios de prueba, el profesor deberá habilitar las cuentas con las que se verificará el acceso.

## 3 Registrar la firma Android

La firma debug de este computador tiene estas huellas, obtenidas el 2 de noviembre de 2026:

```text
SHA-1
FF:36:2F:42:07:76:E0:66:42:D9:50:1B:10:15:2D:61:F7:BD:B6:56

SHA-256
73:79:43:8B:D6:B6:18:37:6B:5B:11:B3:CB:82:90:9D:6C:6F:FD:77:72:CA:7F:85:6B:BE:89:2E:FE:FD:9A:03
```

Añade SHA-1 al registro Android en Firebase para Google; puedes registrar también SHA-256. En otro computador o con otra firma, genera el informe de nuevo. Desde la carpeta `lapticon`:

```powershell
$env:JAVA_HOME = 'C:\Program Files\Java\jdk-17'
Push-Location android
.\gradlew.bat --no-daemon :app:signingReport
Pop-Location
```

No compartas el archivo de firma privada. El APK actual utiliza la firma debug, incluida también en la configuración de release del prototipo; una publicación definitiva requiere preparar su propia firma y registrar sus huellas.

## 4 Descargar la configuración del cliente

Después de habilitar Google y registrar la firma, descarga de nuevo `google-services.json` desde el registro Android del proyecto Firebase. Colócalo exactamente en:

```text
android/app/google-services.json
```

Este proyecto Android inicializa Firebase a partir de los recursos generados con ese archivo. No necesita que escribas API keys en Dart ni que agregues `firebase_options.dart`. Para Google, el JSON actualizado debe incluir el cliente OAuth web que el complemento transforma en `default_web_client_id`.

Si el archivo está ausente, mal formado o no corresponde al paquete, Gradle omite su aplicación y mantiene la conexión pendiente. Si sus identificadores son incorrectos pero el archivo tiene estructura válida, Firebase puede inicializar y luego rechazar el acceso; los errores aparecen en español. La aceptación de un proyecto solo se confirma con las pruebas reales del paso 6.

El archivo queda excluido de Git y del ZIP de entrega. Si lo agregas después de generar el APK, debes volver a compilar e instalar: un APK ya construido no cambia al copiar el JSON al proyecto.

## 5 Confirmar la dirección de la API

La dirección predeterminada es `https://lapticon-backend.onrender.com`. El Swagger también declara un host con sufijo `-ed`; confirma con el profesor cuál utiliza su curso. No se prueba el backend usando credenciales administrativas: la app envía el token de Firebase.

Si debes cambiar la dirección, copia `config/android.example.json` a `config/android.local.json` y ajusta `API_BASE_URL`. Usa solo el origen HTTPS, sin `/api`, parámetros ni usuario y contraseña:

```json
{
  "API_BASE_URL": "https://lapticon-backend.onrender.com"
}
```

El archivo `.local.json` queda excluido de Git y del ZIP. Esta variable configura el destino de las solicitudes, no una clave secreta.

Desde PowerShell en `lapticon`, ejecuta cada comando:

```powershell
powershell -ExecutionPolicy Bypass -File .\herramientas.ps1 clean
powershell -ExecutionPolicy Bypass -File .\herramientas.ps1 pub get
powershell -ExecutionPolicy Bypass -File .\herramientas.ps1 devices
powershell -ExecutionPolicy Bypass -File .\herramientas.ps1 run -d emulator-5554 --dart-define-from-file=config/android.local.json
```

Sustituye el dispositivo por el que muestre `devices`. Si mantienes la API predeterminada, omite `--dart-define-from-file`. Para Run en Android Studio, esa misma opción puede colocarse en los argumentos adicionales de ejecución Flutter. Mantén JDK 17; `android/gradle.properties` contiene la ruta de este equipo y debe adaptarse si trasladas el proyecto.

## 6 Verificar la conexión real

1. Registra un correo de prueba. Debe crearse la cuenta en Firebase Authentication y el perfil con nombre y apellido en la API.
2. Cierra sesión y vuelve a ingresar. El perfil existente debe consultarse, sin volver a guardarlo ni sobrescribirlo.
3. Cierra la app y ábrela de nuevo. La sesión se restaura mediante Firebase y se consulta el perfil antes de mostrar el inicio.
4. Prueba Google con una cuenta permitida. Cancelar el selector debe regresar al formulario. Si no existe perfil, la app solicitará nombre y apellido.
5. Prueba recuperación con un correo de prueba que controles. Revisa el mensaje, el enlace y el cambio de contraseña. La app usa el manejador de recuperación alojado por Firebase; no requiere un dominio propio.
6. Comprueba la primera petición protegida: `GET /api/users/{uid}`. No publiques el token en capturas o registros.

Si la API falla después de crear la cuenta, la app ofrece **Reintentar perfil** y **Cerrar sesión**. El reintento primero consulta el perfil, de modo que no repite el guardado si el servidor ya lo recibió. Un 401 provoca una renovación de token y un solo reintento; un segundo 401 cierra la sesión. Un 403 conserva la sesión y muestra la falta de permisos.

La pantalla **Tu sesión está lista** solo aparece tras autenticar y recibir el perfil de la API. En esta entrega no se exige verificar el correo antes de entrar, ni se implementan roles, envíos o viajes.

## Estado de las comprobaciones

La lógica se verifica mediante pruebas automatizadas con servicios simulados. El APK sin JSON debe arrancar en Android y mostrar la conexión pendiente. El registro real, Google, los correos y la aceptación del token por la API quedan pendientes hasta recuperar el acceso del profesor.

Referencias: [Firebase en Android](https://firebase.google.com/docs/android/setup), [autenticación Flutter](https://firebase.google.com/docs/auth/flutter/start), [Google Sign-In](https://firebase.google.com/docs/auth/flutter/federated-auth) y [API Lapticon](https://lapticon-backend.onrender.com/api-docs/).

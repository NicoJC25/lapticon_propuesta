# Pruebas y evidencia de v1.0.0

## Comandos

Desde la raíz con `pubspec.yaml`:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug --dart-define-from-file=config/android.local.json
```

En Windows se puede sustituir `flutter` por `powershell -ExecutionPolicy Bypass -File .\herramientas.ps1`. La construcción configurada necesita los archivos de [Configuración](CONFIGURACION.md); también se puede compilar sin Firebase y mostrar la conexión pendiente.

Pruebas independientes del proveedor real, desde el proxy:

```powershell
cd flight_proxy
node --test
```

## Cobertura

| Área | Casos |
| --- | --- |
| Acceso y perfiles | Registro, credenciales rechazadas, recuperación, cuenta existente, perfil pendiente, reintento parcial, sesión y rutas protegidas |
| HTTP | Bearer, renovación limitada, permisos, red, respuestas inválidas y errores del servidor |
| Roles | Elección, caché por UID, prioridad del servidor y comprobación de persistencia |
| Encomiendas y viajes | Validaciones, lugares, estados, seis ciudades, selección, registro, toma y cancelación |
| Entrega y calificación | Participantes, estados, confirmación, duplicados, fallos y respuesta perdida |
| UX/UI | Regreso fijo y Android, teclado primero, descarte, conservación de datos y cambio de rol sin borrar la elección |
| Accesibilidad | Contraste, tamaños pequeños y grandes, texto al 200 % y teclado simulado |
| Continuidad | Chat y Google conservan pruebas con sus accesos habilitados explícitamente en esos casos |

## Recorrido Android

Con el emulador iniciado:

```powershell
flutter drive --driver=test_driver/ux_android_driver.dart --target=integration_test/ux_android_test.dart -d emulator-5554 --no-enable-impeller
```

Registra una cuenta simulada, cambia roles, publica una encomienda, registra un vuelo, toma una encomienda, marca la entrega y califica. Usa repositorios simulados y no escribe en Firebase ni en la API del salón. Sus capturas se guardan en `capturas/revision-ux-ui/`.

La opción de renderizado corresponde a la captura de pruebas; la app normal conserva su renderizador predeterminado. Algunas capturas de la superficie Flutter pueden omitir partes durante transiciones. Las imágenes 11–14 complementan la evidencia con capturas directas de la app normal instalada, incluido teclado y regreso.

Las entradas `configured_android_test.dart` y `unconfigured_android_test.dart` verifican configuraciones específicas. La primera requiere el JSON real y cierra la sesión del dispositivo; la segunda requiere compilar sin él. No hay que quitar el archivo personal para ejecutar unitarias o el recorrido simulado.

## Registro de consolidación

Comprobaciones ejecutadas el **18 de noviembre de 2026** sobre la consolidación local de `main`, versión `1.0.0+4`:

| Comprobación | Resultado |
| --- | --- |
| Resolución de dependencias | `flutter pub get` completado, con el lockfile conservado |
| Análisis Flutter | Sin observaciones |
| Pruebas Flutter | **177 aprobadas**, sin fallos |
| Pruebas del proxy Node | **7 aprobadas**, sin fallos; Node 24.22.3 |
| Compilación Android configurada | APK debug generado correctamente, `1.0.0+4` |
| Enlaces Markdown del README y documentos nuevos | Sin referencias locales rotas |

Las pruebas de esta consolidación no escriben en los servicios compartidos. El recorrido nativo y las capturas de la revisión UX del 17 de noviembre se conservan como evidencia anterior: no se presenta una nueva ejecución de ese recorrido durante esta consolidación.

## Aceptación con servicios reales

| Paso | Resultado esperado |
| --- | --- |
| Crear cuenta | Identidad Firebase y perfil del mismo UID; recuperación si el perfil falla |
| Publicar | Encomienda guardada y recuperable por su remitente |
| Registrar viaje | Vuelo del proveedor aceptado por el backend |
| Tomar desde otra cuenta | Asignación visible para ambos participantes |
| Entregar | Estado `recibida` recuperable según los listados disponibles |
| Calificar ambos | Opiniones confirmadas por la API, sin anunciar éxito por una respuesta ambigua |
| Reiniciar y cambiar dispositivo | Comprobar sesión y documentar las limitaciones de rol e historial |

Este recorrido requiere cuentas y datos acordados. La comprobación completa entre dos cuentas reales permanece pendiente y no se presenta como aprobada.

La compilación mostró avisos de acceso nativo de Java, compatibilidad de metadatos SDK y futura retirada de Android x86; finalizó correctamente. El APK se construyó con la configuración local real, sin ejecutar escrituras de negocio. La firma es de desarrollo.

## Corrección de coincidencia de rutas

En el diagnóstico real se consultó el viaje activo del usuario, sin escrituras: estaba guardado como `Santiago de Cali → Rionegro`. Esa búsqueda devolvía cero disponibles; `Cali → Medellín` devolvía una encomienda y `Cali → Medellin` devolvía cero. El servidor diferencia esos textos.

El cliente ahora utiliza el IATA para asignar las ciudades del servicio al seleccionar el vuelo. Viajes y encomiendas nuevos serializan nombres compartidos. La lectura de viajes antiguos normaliza sus ciudades y la búsqueda consulta las variantes conocidas, unifica por ID y da prioridad a la lista de tomadas. No se modifican registros anteriores. El servidor sigue decidiendo permisos y disponibilidad al tomar una encomienda.

`test/route_matching_test.dart` reproduce el vuelo CLO/MDE con municipios del proveedor, el viaje antiguo, las variantes de búsqueda, la eliminación de duplicados y los errores que no deben parecer listas vacías.

Verificación posterior: análisis Flutter sin observaciones y **181 pruebas aprobadas**. APK recompilado e instalado. Desde los repositorios de la app actualizada y la sesión real del viajero, la lectura del viaje antiguo produjo `Cali → Medellín` y su búsqueda devolvió **1 disponible y 0 tomadas**. Esta comprobación no tomó ni modificó encomiendas y no reemplaza la aceptación de entrega y calificaciones.

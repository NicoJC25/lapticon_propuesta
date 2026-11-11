# Semana 4: calificaciones entre participantes

Esta entrega continúa en `entrega-semana-cuatro`. Añade calificaciones y su relación con las entregas recibidas; conserva los vuelos, el login y el marcado de entrega. No incorpora chat ni cambia Google o la configuración del Firebase compartido.

## Cómo probar el recorrido

1. Como remitente, abre **Calificar viajeros**. También puedes abrir **Mis encomiendas** y calificar desde una tarjeta recibida que tenga viajero asignado.
2. Como viajero, marca una encomienda como recibida desde **Mis entregas** y vuelve al menú **Calificar remitentes**.
3. Selecciona entre 1 y 5 estrellas y, si quieres, escribe un comentario de hasta 500 caracteres. Pulsa **Enviar calificación**.
4. Al volver a calificar a la misma persona en el mismo rol se muestra la calificación existente. La app no ofrece edición ni eliminación.

Solo se habilitan entregas con estado `recibida`, identificador y dos participantes distintos. La cuenta debe ser remitente o viajero de esa entrega. El formulario determina automáticamente quién recibe la calificación y su rol; no permite escribir un UID arbitrario. Estas comprobaciones del cliente no sustituyen los permisos que debe validar el servidor.

## Contrato utilizado

Documentación consultada: https://lapticon-backend.onrender.com/api-docs/ y su `swagger-ui-init.js`.

- Consulta pública: `GET /api/ratings/{uid}`, respuesta `{ total, promedio, calificaciones }`.
- Escritura protegida: `POST /api/ratings`, con `Authorization: Bearer <Firebase ID token>`.
- Cuerpo: `usuarioDestino`, `rolDestino` (`remitente` o `viajero`), `calificacion` (1–5), `comentario`.
- La identidad del autor procede del token; no se envían contraseñas ni un campo de autor manipulable.

El contrato actual no tiene `encomiendaId`. Por eso esta versión admite una calificación por autor, destinatario y rol, aunque existan varias entregas entre las mismas personas. No debe interpretarse como una calificación independiente por paquete.

Antes de cada POST se consulta si ya existe una calificación del mismo autor para ese destinatario y rol. Las llamadas simultáneas en esta instancia del repositorio comparten una sola operación. Si se pierde la respuesta del POST, se vuelve a consultar antes de anunciar éxito o permitir un nuevo intento. La unicidad entre dispositivos requiere una restricción o una clave de idempotencia en el backend; la app por sí sola no puede garantizarla.

## Historial del viajero: limitación conocida

`GET /api/encomiendas` devuelve las encomiendas publicadas por el remitente. La búsqueda por ruta documenta disponibles y tomadas, pero no un historial global de recibidas del viajero. No se inventa un endpoint ni se intenta consultar directamente la base de datos.

La app conserva en SharedPreferences una copia de las entregas que esta cuenta marcó correctamente como recibidas desde este dispositivo. Se guarda únicamente después de que el servidor acepte el cambio, separada por UID. No guarda tokens ni contraseñas. Las calificaciones se guardan en la API, no en esta caché.

Consecuencias:

- El remitente puede recuperar sus recibidas desde la API.
- El viajero puede calificar las entregas que él marcó en este dispositivo, incluso tras reiniciar o cambiar de rol.
- Las entregas anteriores a este cambio, marcadas por el remitente, hechas desde otro teléfono o perdidas al borrar los datos de la app no aparecen en el listado local del viajero.
- Para eliminar esta limitación se necesita un endpoint autenticado de entregas recibidas del viajero, con ambos participantes. No hacen falta credenciales administrativas dentro de Flutter.
- Si falla el guardado local después del PUT, se informa que la entrega sí se registró. No se repite el PUT ni se presenta como entrega fallida.

## Código y comprobaciones

- `lib/data/rating_repository.dart`: contrato, destinatario, consultas y POST.
- `lib/data/delivered_shipment_store.dart`: historial local separado por cuenta.
- `lib/screens/ratings_screen.dart` y `rating_form_screen.dart`: listado y formulario.
- `lib/widgets/rating_action.dart`: acceso desde las tarjetas.
- `test/rating_test.dart`: contrato HTTP con ambos roles, entrega recibida, participantes, validación, duplicados, concurrencia, respuesta perdida, permisos, caché, navegación, reintentos y formulario con texto al 200 % y teclado.

Comandos desde la raíz de este proyecto:

```powershell
powershell -ExecutionPolicy Bypass -File .\herramientas.ps1 analyze
powershell -ExecutionPolicy Bypass -File .\herramientas.ps1 test
powershell -ExecutionPolicy Bypass -File .\herramientas.ps1 run -d emulator-5554 --dart-define-from-file=config/android.local.json
```

La configuración local existente basta para este módulo. No se agregan variables de entorno ni cambios en Firebase. Las pruebas automatizadas usan servicios simulados: no publican opiniones contra las cuentas compartidas del salón. La prueba de escritura real con dos cuentas y una entrega acordada queda pendiente; conviene hacerla con datos propios de prueba.

Verificación automatizada de esta entrega: análisis sin observaciones y 135 pruebas aprobadas (22 nuevas). Compilación Android de desarrollo correcta.

# Semana 4 — cambio 1: marcar la entrega

Base: commit `84164f6` (seis ciudades de vuelos), rama `correcciones-roles-viajes-google`.

Este directorio es una copia de trabajo Git independiente (worktree), en la rama **entrega-semana-cuatro**. Comparte el historial y el remoto del repositorio original. El proyecto anterior permanece en `../lapticon`. Para continuar esta entrega abre en Android Studio la carpeta **entrega-semana-cuatro**, donde están este archivo y `pubspec.yaml`.

## Único cambio funcional de esta etapa

- **Viajero → Mis entregas:** muestra encomiendas tomadas y asignadas a su uid. Consulta las rutas de todos sus viajes, incluidos los completados, sin exigir un viaje activo. Deduplica rutas y encomiendas.
- **Remitente → Mis encomiendas:** permite marcar la entrega de sus encomiendas tomadas.
- **Marcar entrega:** solicita confirmación y envía `PUT /api/encomiendas/{id}/estado` con `{"estado":"recibida"}` y Bearer Firebase.
- El botón solo aparece para el remitente o viajero asignado de una encomienda tomada. El servidor conserva la responsabilidad de comprobar permisos y transición.
- Mientras se confirma o envía, bloquea duplicados. Un fallo de permisos, sesión, red o servidor se comunica sin modificar el estado local. Tras una respuesta aceptada, muestra confirmación y vuelve a consultar la lista.
- Si el servidor acepta la entrega pero falla la recarga, la acción queda deshabilitada como **Entrega registrada** para no reenviar la operación en esa tarjeta. Se puede actualizar el listado.
- En el listado del remitente, una entrega recibida aparece en **Recibidas**. En el listado del viajero deja de aparecer entre pendientes; no se presenta ese listado como un historial de entregas completadas.

El contrato actual de la API usa **recibida**, aunque la presentación llama **entregada** al estado final. Se implementa una sola transición; no se inventa una confirmación independiente para cada participante.

## Límite del listado del viajero

El Swagger actual no documenta un endpoint global para listar todas las entregas del viajero. Se utilizan `GET /api/viajes` y `GET /api/encomiendas/buscar?origen=...&destino=...`, filtrando `tomadas` por `viajeroId`. Esto incluye pendientes de rutas de viajes anteriores creados desde la app. Asignaciones creadas externamente sin un viaje propio correspondiente requerirían un endpoint adicional del backend.

## Ejecutar y verificar

```powershell
powershell -ExecutionPolicy Bypass -File .\herramientas.ps1 pub get
powershell -ExecutionPolicy Bypass -File .\herramientas.ps1 test
powershell -ExecutionPolicy Bypass -File .\herramientas.ps1 run -d emulator-5554 --dart-define-from-file=config/android.local.json
```

Pruebas específicas en `test/delivery_test.dart`: contrato HTTP y token, autorización, renovación limitada del token, cancelación, confirmación, errores y reintento, duplicados, recarga fallida tras aceptación, participantes y estados válidos, rutas históricas, actualización del remitente y tamaños pequeños con texto al 200 %.

Las pruebas de escritura usan servicios simulados. La aceptación real del cambio y su visibilidad entre dos cuentas debe comprobarse con una encomienda de prueba acordada; no se marcan paquetes reales del servidor compartido durante el desarrollo.

## Trazabilidad

Ajuste de accesibilidad solicitado después del cambio de entrega: **Mi viaje** ahora inicia con ciudades y fecha, muestra vuelos disponibles y registra solo tras elegir y confirmar. Se retiraron el campo manual del número y el registro sin validar. El ajuste está concentrado en `mi_viaje_screen.dart`, `flight_search_screen.dart` y las pruebas de viajes; no modifica el comportamiento de marcar entregas.

Este cambio no incorpora chat, chatbot ni calificaciones. Se conservan pendientes para cambios posteriores independientes. No se modifica Firebase compartido ni se requiere desplegar nuevamente el servicio de vuelos en Render. El repositorio queda preparado para un commit dedicado a esta entrega.

# Limitaciones y pendientes de v1.0.0

La entrega cubre registro, encomiendas, viajes e interacción sin chat, con entrega, calificaciones y UX/UI. Requiere configuración y servicios externos disponibles. Las pruebas simuladas no equivalen a la aceptación de todas las operaciones por el backend real.

## Información o cambios del profesor

| Punto | Situación y solicitud |
| --- | --- |
| Rol persistido | En pruebas anteriores el PUT respondía con éxito, pero un GET no confirmaba `rol`. La app usa caché y comunica la situación. Confirmar o corregir que el servidor guarde y devuelva `remitente`/`viajero`. |
| Fecha de vencimiento | La app envía la fecha elegida, pero el POST publicado no documenta `fechaVencimiento`. Confirmar nombre, restricciones y respuesta de la fecha persistida. No se anuncia como guardada si no se confirmó. |
| Confirmación de entrega | La API acepta `recibida`; la presentación utiliza `entregada` y menciona confirmación del remitente. Precisar si basta una acción de un participante o si existe una segunda confirmación, con su contrato. |
| Historial recibido del viajero | No se identificó un endpoint documentado con todas sus recibidas. Se necesita una consulta autenticada con ID, estado y ambos UID, incluidas entregas marcadas por el remitente o desde otro teléfono. |
| Unidad de calificación | El contrato no recibe `encomiendaId`. La app consulta por autor, destinatario y rol. Confirmar si se requiere una por paquete y cómo evita duplicados el servidor; ampliar el contrato si corresponde. |

La revisión del Swagger del 17 de noviembre de 2026 confirmó que seguían sin documentarse `rol` en la actualización de perfil, `fechaVencimiento` al crear encomienda y `encomiendaId` al calificar. Esa revisión no demuestra cómo está implementado internamente el servidor hoy. Son aclaraciones y verificaciones pendientes, sin inventar campos ni endpoints alternativos.

## Consecuencias

- El rol puede no recuperarse en otro teléfono si el servidor no lo persiste.
- Las entregas pendientes del viajero se buscan en las rutas de sus viajes. Asignaciones externas sin un viaje propio correspondiente pueden necesitar soporte adicional.
- El viajero puede calificar las recibidas que él marcó y conservó en ese dispositivo. Las marcadas por el remitente, anteriores a la caché o perdidas al borrar datos pueden no aparecer.
- La consulta previa y la reutilización de operaciones reducen duplicados en esta app. La unicidad entre dispositivos requiere una restricción del servidor.
- Los vuelos dependen de cobertura, fecha y suscripción. Un resultado vacío o error no produce vuelos ficticios ni permite registrar manualmente sin validar.

## Fuera del alcance evaluado

Chat entre usuarios, chatbot, Google, matching con IA y vencimientos programados. Sus dependencias no se presentan como bloqueos de la evaluación. Chat y Google conservan código y pruebas con accesos ocultos.

El APK es de desarrollo. La publicación en tiendas requiere firma propia y preparación de distribución; la configuración actual de release utiliza la firma debug. La configuración privada se conserva fuera de Git y del ZIP de código.

## Aceptación real pendiente

Con dos cuentas y una encomienda acordada, comprobar el estado visible para ambas partes y las dos calificaciones persistidas. Repetir tras reiniciar y en otro dispositivo permite comprobar sesión, rol e historial. No se modifican paquetes de terceros para realizar estas pruebas.

Las guías de semanas de la raíz son históricas. Este documento y el [README](../README.md) describen la versión consolidada.

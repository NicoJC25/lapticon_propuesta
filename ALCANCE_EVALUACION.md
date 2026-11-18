# Alcance de evaluación y pendientes del profesor

Revisión del 17 de noviembre de 2026. Rama `revision-ux-ui`, creada desde `entrega-semana-cuatro`. La carpeta del proyecto conserva el nombre `entrega-semana-cuatro`; cambiar de rama no requiere moverla.

## Qué se presenta

Registro de usuarios con correo y contraseña, creación de encomiendas, registro de viaje mediante selección de vuelo e interacción entre viajero y remitente: búsqueda, toma, seguimiento, entrega y calificaciones. La revisión incluye UX/UI y navegación accesible en Android.

Los accesos de chat y Google están ocultos por la configuración central `EvaluationFeatures`, con sus valores predeterminados `false`. Se conserva su código y las pruebas de esos módulos mediante inyección explícita de sus funciones. No se modifica el Firebase compartido.

## Información o cambios necesarios del profesor

| Punto | Por qué sigue pendiente | Qué solicitar al profesor |
| --- | --- | --- |
| Persistencia del rol | En pruebas anteriores, actualizar el rol devolvía éxito, pero el perfil consultado no lo devolvía. La caché local permite continuar en ese teléfono. | Confirmar si el backend ya guarda y devuelve `rol` como `remitente` o `viajero`. Si continúa el problema, corregir la actualización y lectura del perfil, con autorización por UID. |
| Fecha de vencimiento | El formulario permite elegir fecha y la envía; el POST documentado no especifica `fechaVencimiento`. No se afirma que fue guardada si la respuesta no la confirma. | Confirmar el nombre del campo, si se acepta al crear la encomienda, sus restricciones y cómo se devuelve la fecha persistida. |
| Confirmación de entrega | La API actual se usa con `recibida`; la presentación habla de `entregada` y menciona confirmación del remitente. No hay una segunda confirmación implementada sin un contrato. | Precisar si basta la acción de un participante o se necesita una confirmación independiente del remitente. Confirmar estados, permisos y endpoint/cuerpo si existe esa segunda acción. |
| Historial recibido del viajero | No se identificó un endpoint documentado con todas sus encomiendas recibidas. Solo se conserva localmente lo que él marca desde ese dispositivo. | Proporcionar o identificar un endpoint autenticado de recibidas del viajero, con ID, estado y UID de ambos participantes, para recuperar también entregas marcadas por el remitente o desde otro teléfono. |
| Calificaciones por persona o encomienda | El contrato actual no recibe `encomiendaId`. Se consulta si el autor ya calificó a esa persona en ese rol; la prevención entre dispositivos requiere soporte del servidor. | Confirmar la unidad de calificación. Si es por paquete, ampliar el contrato con `encomiendaId` y la validación de participantes/entrega. Confirmar también cómo evita duplicados el backend. |

Estos puntos son aclaraciones o limitaciones del contrato del servidor, no una afirmación de que todos los flujos estén bloqueados. El registro, los listados y las acciones ya implementadas pueden demostrarse; la aceptación real se debe comprobar con datos de prueba acordados.

## Fuera de esta evaluación

Chat entre usuarios, chatbot, Google, matching con IA y vencimientos programados. Sus dependencias no se presentan como bloqueos de esta entrega. El documento general anterior se conserva como referencia del alcance completo.

## Navegación y comprobaciones

- Barra superior fija con flecha y texto. Solo la bienvenida carece de regreso.
- En menús: `Volver a roles` abre la selección sin borrar la elección; cancelar retorna al mismo menú.
- En selección inicial: `Volver al acceso` confirma el cierre de sesión. Volver desde una pantalla secundaria no cierra la sesión.
- Formulario modificado: confirmar descarte y conservar los datos al cancelar. Los envíos en curso bloquean la salida hasta confirmarse o fallar.
- `Volver al menú` después de publicar llega al menú aunque el formulario se haya abierto desde Mis encomiendas.
- El botón Android cierra primero el teclado; las salidas con cambios utilizan la misma confirmación.
- Las contraseñas de formularios fallidos permanecen únicamente en memoria durante esa pantalla; no se escriben en archivos, preferencias ni logs, y sus controladores se descartan al salir.

Pruebas de navegación: `test/ux_navigation_test.dart`. Las pruebas de chat y Google se conservan con los accesos habilitados explícitamente en esos casos; el modo evaluado los mantiene ocultos.

Recorrido Android con servicios simulados, sin escritura en la API compartida:

```powershell
powershell -ExecutionPolicy Bypass -File .\herramientas.ps1 drive --driver=test_driver/ux_android_driver.dart --target=integration_test/ux_android_test.dart -d emulator-5554 --no-enable-impeller
```

Las capturas de ese recorrido se guardan en `capturas/revision-ux-ui`. La comprobación real con dos cuentas y la persistencia del backend quedan separadas de estos resultados simulados.

## Resultado de esta revisión

- Análisis de Flutter sin observaciones y **177 pruebas aprobadas**, incluidas 17 nuevas de navegación y conservación de datos.
- Recorrido Android completo aprobado en `Medium_Phone_API_35` con servicios simulados: registro, roles, encomienda, viaje, toma, entrega y calificación.
- APK normal compilado con la configuración local existente, instalado y abierto en Android. Se revisó manualmente el formulario con teclado, desplazamiento y confirmación de salida, sin enviar el registro al servidor.
- Copia de entrega: `../Lapticon-revision-ux-ui.apk`. Word actualizado: `../Lapticon-pendientes-alcance-evaluacion.docx`. El Word anterior se conserva.
- El Swagger se volvió a consultar el 17 de noviembre de 2026: sigue sin documentar `rol` en PUT de perfil, `fechaVencimiento` en POST de encomienda y `encomiendaId` en POST de calificación. Esto no demuestra cómo persiste internamente el servidor; esa comprobación real sigue pendiente.

No se publicaron ni calificaron encomiendas reales durante esta revisión. Chat, Google y los demás servicios excluidos siguen fuera de la evaluación. Los cambios se dejan locales en `revision-ux-ui`, sin commit ni push automáticos.

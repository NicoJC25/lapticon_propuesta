# Revisión del alcance — 9 de noviembre de 2026

Fuente: `session 10.pdf`, diapositivas 21–23. La presentación propone **seis prácticas en cinco semanas**, no cuatro. La semana 4 corresponde al ciclo completo y la 5 a pruebas, ajustes y sustentación. El chatbot se mantiene a cargo de la compañera y no se implementa en esta corrección.

| Etapa | Estado de esta versión | Pendiente real |
| --- | --- | --- |
| Semana 1: Firebase, correo, Google y petición protegida | Correo conectado y token aceptado por el backend | Registrar SHA-1, actualizar JSON, habilitar Google y probar una cuenta real |
| Semana 2: roles y creación de encomiendas | Menús, caché por cuenta y formulario implementados | El backend no persiste `rol`; hay que modificar su modelo y actualización |
| Semana 3: listas, viaje validado y tomar encomienda | Implementados; se añade búsqueda por ruta con selección y datos automáticos | Configurar proveedor y servidor de búsqueda; probar rutas reales y concurrencia con dos cuentas |
| Semana 4: chat Firestore | Pantallas, API de estado y adaptador Firestore preparados; desactivado por defecto | Confirmar esquema, creación del documento padre y reglas del profesor. Activar y probar dos cuentas; ver SEMANA_4_CHAT.md |
| Semana 4: entrega | Implementado en el cambio 1 de `entrega-semana-cuatro`: Mis entregas y acción de remitente, con confirmación y PUT `recibida` | Verificar una encomienda real de prueba con dos cuentas; ver `SEMANA_4_ENTREGA.md` |
| Semana 4: calificación | Implementada para ambas partes, con pruebas simuladas | Escritura real con dos cuentas y limitación del historial recibido del viajero; ver SEMANA_4_CALIFICACIONES.md |
| Semana 4: cierre del chat | Cliente consulta estado y bloquea el envío cuando se cierra | Verificar cierre real en API y Firestore tras ambas calificaciones y rechazo por reglas |
| Semana 5 | Pruebas automatizadas y compilación disponibles | Prueba del ciclo real con dos cuentas, errores, accesibilidad, documentación y demo |

## Chat y chatbot son módulos diferentes

El **chat de entrega** conecta dos usuarios en Firestore (`chats/{uid1_uid2}` con los uid ordenados). Es parte explícita de la semana 4. El **chatbot** consume `/api/chatbot` y responde mediante IA. Implementar uno no completa el otro; acuerden con la compañera quién hará el chat entre usuarios.

## Roles: evidencia y cambio necesario en el backend

Con la cuenta de prueba se envió `PUT /api/users/{uid}` con `rol: remitente`: respondió 200, pero no incluyó rol. Un GET posterior tampoco lo incluyó. **El cambio no está persistiendo actualmente.** La app ahora hace ese GET antes de considerar confirmada la sincronización; conserva la caché y ofrece reintentar.

El propietario del backend debe agregar `rol` al modelo de usuario con valores `remitente`/`viajero`, permitirlo en la actualización propia y devolverlo en GET/PUT. Debe validar valores y autorizar por el uid del token. No se cuenta con ese código en este repositorio y no se puede corregir MongoDB desde Flutter. No se agregan claves administrativas al cliente.

Aceptación del arreglo del servidor: cambiar a viajero, consultar el perfil, cerrar sesión y entrar desde otro dispositivo; después repetir como remitente. Un 200 del PUT por sí solo no prueba persistencia. La selección del menú tampoco sustituye los permisos del servidor.

## Vuelos y otras dependencias del servidor

El Swagger del profesor no documenta una búsqueda de vuelos por ruta. `/api/viajes/disponibles` lista viajes de usuarios, no el catálogo de una aerolínea. AV40 y AV41 no se guardan como rutas estáticas ni se dan por existentes: deben estar publicados para la ruta y fecha consultadas.

Se incorpora `flight_proxy/` para consultar AeroDataBox sin exponer RAPIDAPI_KEY en el APK. Configuración e instrucciones: [VUELOS_Y_GOOGLE.md](VUELOS_Y_GOOGLE.md). El flujo está preparado y probado con respuestas simuladas; faltan clave, suscripción con acceso a horarios, alojamiento HTTPS y prueba contra el proveedor real.

El matching con IA aparece como servicio/reto adicional en la presentación: faltan URL del microservicio y pantalla de sugerencias. Los vencimientos programados son otro reto del backend; actualmente el servidor los actualiza al consultar. No pueden solucionarse con una tarea en el teléfono.

La presentación llama `entregada` al estado final, mientras que el Swagger actual acepta `recibida`. El cliente de entrega debe seguir el contrato publicado y confirmar con el profesor la semántica. También falta confirmar que el backend acepte la fecha de vencimiento solicitada al crear una encomienda.

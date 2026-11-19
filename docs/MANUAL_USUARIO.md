# Manual de usuario

La app utiliza Android y la configuración descrita en el [README](../README.md). Para la demostración con servicios reales, acuerden cuentas y encomiendas de prueba.

## Cuenta y acceso

1. Pulsa **Crear una cuenta** en la bienvenida.
2. Completa nombre, apellido, correo, contraseña y confirmación. Usa al menos seis caracteres y contraseñas coincidentes.
3. Pulsa **Crear cuenta** y espera la respuesta. Si el perfil queda pendiente, utiliza completar o reintentar perfil; no vuelvas a crear la cuenta Firebase.
4. Una cuenta existente entra con **Iniciar sesión**. Puedes mostrar u ocultar la contraseña.
5. **¿Olvidaste tu contraseña?** solicita el correo de recuperación. La confirmación no revela si el correo tiene cuenta.

Al ingresar elige **Remitente** o **Viajero** si no tienes un rol recuperado. El aviso de rol guardado solo en el teléfono significa que la persistencia del servidor no se confirmó; puedes continuar en ese dispositivo.

## Remitente

1. Abre **Crear encomienda** y elige país y ciudad de origen y destino. Solo están habilitadas Bogotá, Medellín, Cali, New York, Miami y Washington. Origen y destino deben ser diferentes.
2. Describe qué envías, elige pesos colombianos (COP) o dólares estadounidenses (USD) y escribe el valor ofrecido como entero positivo, sin separadores. El máximo del formulario es 100.000.000.
3. Opcionalmente elige una fecha límite. La confirmación muestra la fecha devuelta por el servidor o indica que no la confirmó.
4. Pulsa **Publicar encomienda**. Después puedes volver al menú o crear otra.
5. En **Mis encomiendas**, consulta y filtra disponibles, tomadas, recibidas y vencidas. **Actualizar** recupera el estado del servidor.
6. Si una encomienda tomada admite **Marcar entrega**, confirma solo cuando el paquete haya llegado. El estado final utilizado es **Recibida**, sujeto a los permisos de la API.
7. Desde una tarjeta recibida o **Calificar viajeros**, selecciona entre una y cinco estrellas, añade un comentario opcional de hasta 500 caracteres y envía la calificación.

## Viajero

1. Abre **Mi viaje**. Si no tienes uno activo, elige ciudades y fecha.
2. Las seis opciones son Bogotá, Medellín, Cali, New York, Miami y Washington; utilizan BOG, MDE, CLO, JFK, MIA e IAD respectivamente.
3. Pulsa **Buscar vuelos**, selecciona un resultado y confirma **Registrar viaje**. Se completan automáticamente número, ciudades y fecha; no se exige escribir el código del vuelo.
4. Si no hay resultados, revisa ruta, fecha y cobertura antes de reintentar. No se inventan vuelos ni se ofrece registro sin validar.
5. Abre **Buscar encomiendas de mi ruta** desde el viaje, o **Buscar encomiendas** desde el menú.
6. Revisa una encomienda, pulsa **Tomar encomienda** y confirma. El servidor decide si aún está disponible para asignártela.
7. En **Mis entregas**, consulta tus tomadas y marca la entrega cuando corresponda. Se revisan rutas de tus viajes, incluidos los anteriores.
8. En **Calificar remitentes**, califica las entregas recibidas guardadas en este dispositivo. Consulta la restricción del historial en [Limitaciones](LIMITACIONES.md).

En **Mi viaje** también puedes cancelar el viaje activo tras confirmar la acción.

## Navegación y recuperación de errores

- **Volver** permanece en la barra superior al desplazarte y abrir el teclado. La bienvenida es la pantalla sin regreso.
- **Volver a roles** abre la selección sin borrar la elección; **Volver al menú** permite cancelarla. Cambiar el rol no cierra la sesión.
- En la selección inicial, **Volver al acceso** confirma el cierre de sesión.
- Al salir de un formulario modificado puedes **Seguir editando** o **Descartar cambios**.
- Los envíos en curso bloquean los controles para evitar duplicados. Ante un error se conservan los datos que permiten corregir y reintentar.
- El botón Android cierra primero el teclado cuando está abierto.
- Para salir de la cuenta utiliza **Cerrar sesión**.

Las calificaciones se consultan por persona y rol; la app no ofrece edición ni eliminación. Chat y Google no aparecen en esta entrega evaluada.

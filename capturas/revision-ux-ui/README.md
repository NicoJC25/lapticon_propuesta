# Capturas de la revisión UX/UI

Las capturas numeradas 01 a 10 proceden del recorrido Android de integración con servicios simulados. Los nombres, mensajes, vuelos, encomiendas y resultados de ese recorrido son datos de prueba; no representan operaciones contra Firebase ni la API del salón. El renderizador de capturas de Flutter puede omitir partes de una barra durante transiciones; por eso el regreso fijo se comprobó además en la app normal.

Las capturas 11 a 14 proceden de la app normal instalada en el emulador: bienvenida, registro vacío, registro con teclado y confirmación de salida. El texto «Prueba» se escribió solo en el formulario, sin enviar el registro. Estas imágenes permiten revisar la barra fija y su disponibilidad al desplazarse y abrir el teclado.

Para reproducir el recorrido automatizado, utiliza el comando de ALCANCE_EVALUACION.md. Las comprobaciones de texto al 200 % y tamaños 320×568 y 430×932 están en test/ux_navigation_test.dart. La verificación real del ciclo de encomienda con dos cuentas sigue pendiente de datos acordados.

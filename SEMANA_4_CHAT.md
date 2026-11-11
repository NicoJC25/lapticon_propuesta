# Chat entre remitente y viajero: preparado para conectar

Este cambio pertenece a `entrega-semana-cuatro`. El chat de usuarios es independiente del chatbot de IA de la compañera. No se modifica el Firebase compartido ni se publican mensajes de prueba en él.

## Qué funciona en el código

- Botón **Abrir chat** en las tarjetas de encomiendas tomadas o recibidas, solo para el remitente y el viajero asignado. Disponible en Mis encomiendas, Mis entregas, encomiendas ya tomadas de la búsqueda y tarjetas de calificación.
- ID compartido por pareja: los dos UID ordenados unidos con `_`, según la diapositiva 16 de `session 10.pdf`. Varias entregas entre la misma pareja abren la misma conversación.
- Consulta real protegida `GET /api/chats/estado/{chatId}` con el ID token existente. Se espera `{ "estado": "abierto" | "cerrado", "fechaCierre": null | fecha ISO }`. Valores distintos se consideran no confirmados, no abiertos.
- Estado consultado al entrar, al actualizar, al regresar del segundo plano y cada 30 segundos mientras la pantalla está activa y la conexión de mensajes está habilitada.
- Lectura de mensajes mediante stream, historial de los últimos 100, mensajes propios y ajenos, fechas, texto seleccionable, borrador en memoria y mensajes de error.
- Validación de 1–1000 caracteres, bloqueo de doble envío y consulta del estado inmediatamente antes de escribir. Un cierre detectado mantiene el historial y deshabilita el compositor.
- Reintento del mismo texto con el mismo ID de documento mientras la pantalla permanezca abierta. El adaptador verifica si ese documento ya existe para evitar duplicar un envío cuya confirmación se perdió.
- Las escuchas y el temporizador se cancelan al salir; el borrador no se persiste entre cuentas ni reinicios.

## Cómo queda esta entrega

`CHAT_FIRESTORE_ENABLED` es `false` por defecto. El ejemplo `config/android.example.json` lo muestra explícitamente; los archivos locales actuales pueden omitirlo y siguen desactivados.

La pantalla muestra **Conexión del chat pendiente** y bloquea lectura y escritura de mensajes. Puede consultar el estado por API aunque Firestore esté pendiente. Un 404 significa que no se confirmó la apertura; no se crea un chat por cuenta del cliente. No hay mensajes ficticios ni respuestas automáticas en producción. Los servicios simulados se usan únicamente en pruebas.

El archivo `google-services.json` ya conecta la identidad de Android. No hacen falta otra API key ni contraseñas de administrador para este módulo.

## Contrato que aún debe confirmar el profesor

La presentación y el Swagger confirman el ID y la consulta de estado, pero no publican la estructura interna de Firestore ni sus reglas. El archivo `lib/chat/firestore_chat_transport.dart` aísla una **propuesta**, no un esquema descubierto en la base de datos:

```text
chats/{uidMenor_uidMayor}
  participantes: [uidMenor, uidMayor]
  estado: "abierto" o "cerrado"
  fechaCierre: ... (gestionada por el servidor)

  mensajes/{messageId}
    autorId: UID del autor
    texto: mensaje
    fechaCreacion: timestamp del servidor
```

`ChatSchema` concentra los nombres propuestos. El cliente no crea el documento padre, no escribe participantes ni altera el estado. Antes de cada mensaje, la transacción exige un padre existente, los dos participantes esperados y estado abierto. Esto evita reabrir un chat cerrado o inventar su pertenencia desde Flutter. La escritura solo se confirma con respuesta de Firestore; no se guarda una cola offline de mensajes. Se deshabilita la caché persistente de Firestore en este adaptador.

Si el backend no crea el documento padre al tomar la encomienda, hará falta que el profesor confirme quién debe crearlo y con qué validaciones. El Swagger no contiene una ruta para crear o abrir chats. No puede resolverse correctamente cambiando una bandera de Flutter sin conocer ese contrato.

## Conexión final, cuando llegue la información

1. Confirmar que Cloud Firestore está creado en el mismo Firebase del backend y de la app.
2. Obtener un documento de ejemplo, la subcolección de mensajes y las reglas actuales. Ajustar `ChatSchema` y la validación de los campos/timestamps si difieren de la propuesta.
3. Confirmar cómo y cuándo se crea el documento padre y que el backend actualiza su estado al cerrar el chat tras las dos calificaciones. Su API y Firestore deben reflejar el mismo cierre.
4. Revisar las reglas para que solo ambos participantes lean y escriban, cada autor solo cree sus propios mensajes y nadie escriba después del cierre. Se deja un fragmento **no desplegado** en `firestore/chat.rules.example`; requiere revisión e integración por el dueño del proyecto. No sustituir las reglas compartidas del salón.
5. Con el contrato y permisos confirmados, agregar `"CHAT_FIRESTORE_ENABLED": true` a `config/android.local.json` y recompilar. No cambiar Google ni instalar claves Firebase Admin dentro de la app.
6. Probar con dos cuentas y una encomienda acordada: tomar, abrir desde ambos teléfonos, intercambiar mensajes, entregar, calificar por ambos lados y comprobar el cierre. Intentar leer/escribir con una tercera cuenta y escribir tras el cierre debe ser rechazado también por Firestore.

El cierre no lo decide el cliente ni se simula después de calificar: lo controla el backend. La consulta y el bloqueo en Flutter ayudan a la experiencia; las reglas son las que deben impedir un envío tardío desde otra app o en una carrera con el cierre.

## Archivos y verificación

- `lib/chat/chat_repository.dart`: contrato y estado por API, mensajes desacoplados del transporte.
- `lib/chat/chat_controller.dart`: estado de pantalla, errores, stream y reintentos.
- `lib/chat/firestore_chat_transport.dart`: adaptador Firestore desactivado por defecto y esquema pendiente de confirmar.
- `lib/screens/chat_screen.dart` y `lib/widgets/chat_action.dart`: interfaz y navegación.
- `test/chat_test.dart`: pruebas con API y mensajes simulados. No equivalen a una validación real de reglas ni del adaptador contra Firestore.

Desde la raíz del proyecto:

```powershell
powershell -ExecutionPolicy Bypass -File .\herramientas.ps1 analyze
powershell -ExecutionPolicy Bypass -File .\herramientas.ps1 test
powershell -ExecutionPolicy Bypass -File .\herramientas.ps1 run -d emulator-5554 --dart-define-from-file=config/android.local.json
```

Fuentes técnicas: [escuchas de Firestore](https://firebase.google.com/docs/firestore/query-data/listen), [transacciones](https://firebase.google.com/docs/firestore/manage-data/transactions), [reglas de acceso](https://firebase.google.com/docs/firestore/security/rules-conditions) y [Swagger del profesor](https://lapticon-backend.onrender.com/api-docs/).

Resultado de verificación local: análisis sin observaciones y 160 pruebas aprobadas (25 nuevas de chat). Se validaron con servicios simulados el estado, los permisos, el stream, los reintentos, el cierre y diseños de 320/430 píxeles con texto al 200 % y teclado. La estructura y las reglas reales de Firestore siguen pendientes de confirmar.

La compilación Android de desarrollo terminó correctamente con la configuración local existente y el chat desactivado. El APK se genera en `build/app/outputs/flutter-apk/app-debug.apk`. No se ejecutó una prueba de mensajes contra Firestore real.

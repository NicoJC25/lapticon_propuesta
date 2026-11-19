# Historial de versiones

## Ajustes posteriores a 1.0.0

- Unifica ciudades de encomiendas y vuelos por IATA; recupera rutas antiguas Santiago de Cali/Rionegro y variantes con o sin tilde, sin migrar registros ni duplicar tarjetas.

- Limita las nuevas encomiendas a las mismas seis ciudades de los vuelos y a monedas COP o USD.

## 1.0.0 — 18 de noviembre de 2026

Primera versión funcional consolidada para evaluación Android. Versión Flutter: `1.0.0+4`.

- Reúne en `main` autenticación, roles, encomiendas, viajes, entrega, calificaciones y revisión UX/UI.
- Mantiene selección de vuelos por ciudades y fecha, toma de encomiendas y marcado `recibida`.
- Incorpora regreso fijo, protección de formularios y navegación consistente al cambiar de rol.
- Conserva chat y Google con accesos ocultos para el alcance evaluado.
- Reorganiza el README para ejecutar y compilar, con configuración, manual, arquitectura, pruebas y pendientes en `docs/`.
- Declara las verificaciones reales y dependencias del servidor que siguen pendientes.

Se conserva el historial y los autores originales. `revision-ux-ui` ya incluía autenticación, fase 2, semana 3 y semana 4; `main` avanzó hasta esa línea sin reescribir las otras ramas. Las guías de fases y semanas se conservan como historial.

El APK es de desarrollo para evaluación. La distribución en tiendas y los módulos fuera del alcance no se anuncian como completados.

/// Formatos de fecha y dinero para la interfaz.

/// 07/03/2026. Las fechas sin hora de la API llegan como medianoche UTC
/// (`2026-11-07T00:00:00.000Z`); se leen en UTC para que en Bogotá (UTC-5)
/// no aparezcan como el día anterior.
String formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

/// AAAA-MM-DD, el formato que recibe la API.
String isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// 50000 COP → "$ 50.000 COP".
String formatMoney(num value, String currency) {
  final whole = value.round().abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < whole.length; i++) {
    if (i > 0 && (whole.length - i) % 3 == 0) buffer.write('.');
    buffer.write(whole[i]);
  }
  final sign = value < 0 ? '-' : '';
  return '$sign\$ ${buffer.toString()} $currency'.trim();
}

/// Fecha de la API a texto, o el texto alterno si no hay fecha.
String formatOptionalDate(DateTime? date, String fallback) =>
    date == null ? fallback : formatDate(date);

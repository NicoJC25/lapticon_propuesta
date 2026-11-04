import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import '../auth/auth_service.dart';
import '../utils/format.dart';
import 'api_client.dart';

/// Estados que maneja la API (`disponible · tomada · recibida · vencida`).
enum ShipmentStatus {
  disponible('disponible', 'Disponible'),
  tomada('tomada', 'Tomada'),
  recibida('recibida', 'Recibida'),
  vencida('vencida', 'Vencida'),
  desconocido('', 'Sin estado');

  const ShipmentStatus(this.apiValue, this.label);
  final String apiValue;
  final String label;
  static ShipmentStatus parse(Object? value) {
    for (final status in values) {
      if (value is String && status.apiValue == value.trim().toLowerCase()) {
        return status;
      }
    }
    return desconocido;
  }
}

/// Monedas que ofrece el formulario. La API recibe el código como texto.
const shipmentCurrencies = ['COP', 'USD', 'EUR'];

/// Lugar elegido en el formulario. La API solo recibe la ciudad.
class Place {
  const Place({required this.country, required this.city});
  final String country;
  final String city;
  String get label => '$city, $country';
  @override
  bool operator ==(Object other) =>
      other is Place && other.country == country && other.city == city;
  @override
  int get hashCode => Object.hash(country, city);
}

class ShipmentDraft {
  const ShipmentDraft(
      {required this.origin,
      required this.destination,
      required this.notes,
      required this.currency,
      required this.value,
      this.expiresOn});
  final Place origin;
  final Place destination;
  final String notes;
  final String currency;
  final num value;

  /// Fecha límite elegida por el remitente. El Swagger no documenta
  /// `fechaVencimiento` en el POST: se envía y la respuesta dice si se usó.
  final DateTime? expiresOn;

  Map<String, Object?> toJson() => {
        'ciudadOrigen': origin.city,
        'ciudadDestino': destination.city,
        'observaciones': notes.trim(),
        'moneda': currency,
        'valor': value,
        if (expiresOn != null)
          'fechaVencimiento': isoDate(expiresOn!),
      };
}

class Shipment {
  const Shipment(
      {required this.id,
      required this.origin,
      required this.destination,
      required this.notes,
      required this.currency,
      required this.value,
      required this.status,
      this.ownerId = '',
      this.travelerId = '',
      this.ownerName = '',
      this.createdAt,
      this.expiresAt});
  final String id;

  /// uid del remitente que la publicó.
  final String ownerId;

  /// uid del viajero que la tomó; vacío si nadie la ha tomado.
  final String travelerId;

  /// Nombre del remitente, cuando la búsqueda lo incluye.
  final String ownerName;
  final String origin;
  final String destination;
  final String notes;
  final String currency;
  final num? value;
  final ShipmentStatus status;
  final DateTime? createdAt;
  final DateTime? expiresAt;

  factory Shipment.fromJson(Map<String, dynamic> json) {
    String text(String key) => json[key] is String ? json[key] as String : '';
    DateTime? date(String key) =>
        json[key] is String ? DateTime.tryParse(json[key] as String) : null;
    final rawValue = json['valor'];
    return Shipment(
        id: text('_id'),
        origin: text('ciudadOrigen'),
        destination: text('ciudadDestino'),
        notes: text('observaciones'),
        currency: text('moneda'),
        value: rawValue is num
            ? rawValue
            : rawValue is String
                ? num.tryParse(rawValue)
                : null,
        status: ShipmentStatus.parse(json['estado']),
        ownerId: text('uid'),
        travelerId: text('viajeroId'),
        ownerName: text('nombreRemitente').isNotEmpty
            ? text('nombreRemitente')
            : text('nombreUsuario'),
        createdAt: date('fechaCreacion'),
        expiresAt: date('fechaVencimiento'));
  }
}

/// Resultado de buscar por ruta: disponibles y las que ya tomé.
class ShipmentSearch {
  const ShipmentSearch({required this.available, required this.taken});
  final List<Shipment> available;
  final List<Shipment> taken;
}

abstract class ShipmentRepository {
  Future<List<String>> countries();
  Future<List<String>> cities(String country);
  Future<Shipment> create(ShipmentDraft draft);

  /// Encomiendas del remitente (`GET /api/encomiendas`). El backend marca
  /// como vencidas las que pasaron su fecha al consultar.
  Future<List<Shipment>> mine();

  /// Disponibles y tomadas por mí en una ruta (`GET /api/encomiendas/buscar`).
  Future<ShipmentSearch> search(String origin, String destination);

  /// Toma una encomienda como viajero (`PUT /api/encomiendas/tomar/{id}`).
  Future<void> take(String id);
  void close() {}
}

/// Lista de encomiendas; acepta un arreglo o un objeto que lo envuelva.
List<Shipment> parseShipments(Object? decoded, {String key = 'encomiendas'}) {
  final list = decoded is List
      ? decoded
      : decoded is Map && decoded[key] is List
          ? decoded[key] as List
          : null;
  if (list == null) {
    throw const AppFailure(
        'La lista de encomiendas no tiene el formato esperado.',
        code: 'invalid-response');
  }
  return [
    for (final item in list)
      if (item is Map<String, dynamic> && item['_id'] is String)
        Shipment.fromJson(item)
  ];
}

class ApiShipmentRepository implements ShipmentRepository {
  ApiShipmentRepository(AuthService auth,
      {http.Client? client,
      String baseUrl = defaultApiBaseUrl,
      Duration timeout = const Duration(seconds: 20)})
      : _api = ApiClient(auth,
            client: client, baseUrl: baseUrl, timeout: timeout);
  final ApiClient _api;
  List<String>? _countries;
  final _cities = <String, List<String>>{};

  List<String> _names(http.Response response) {
    const message = 'La lista de lugares no tiene el formato esperado.';
    final decoded = _api.decode(response, message);
    if (decoded is! List) {
      throw const AppFailure(message, code: 'invalid-response');
    }
    final names = <String>{
      for (final item in decoded)
        if (item is String && item.trim().isNotEmpty) item.trim()
    }.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }

  @override
  Future<List<String>> countries() async => _countries ??= _names(await _api
      .send('GET', '/api/ciudades/paises', authenticated: false));

  @override
  Future<List<String>> cities(String country) async =>
      _cities[country] ??= _names(await _api.send(
          'GET', '/api/ciudades/ciudades-por-pais',
          query: {'nombre': country}, authenticated: false));

  @override
  Future<Shipment> create(ShipmentDraft draft) async {
    final response = await _api.send('POST', '/api/encomiendas',
        body: draft.toJson(),
        forbiddenMessage: 'No tienes permiso para crear encomiendas.');
    const message = 'La respuesta de la encomienda no tiene el formato esperado.';
    final decoded = _api.decode(response, message);
    if (decoded is Map<String, dynamic>) {
      final nested = decoded['encomienda'];
      final json = nested is Map<String, dynamic> ? nested : decoded;
      if (json['_id'] is String) return Shipment.fromJson(json);
    }
    throw const AppFailure(message, code: 'invalid-response');
  }

  static const _listMessage =
      'La lista de encomiendas no tiene el formato esperado.';

  @override
  Future<List<Shipment>> mine() async {
    final response = await _api.send('GET', '/api/encomiendas',
        forbiddenMessage: 'No tienes permiso para ver estas encomiendas.');
    return parseShipments(_api.decode(response, _listMessage));
  }

  @override
  Future<ShipmentSearch> search(String origin, String destination) async {
    final response = await _api.send('GET', '/api/encomiendas/buscar',
        query: {'origen': origin, 'destino': destination},
        forbiddenMessage: 'No tienes permiso para buscar encomiendas.');
    final decoded = _api.decode(response, _listMessage);
    if (decoded is! Map) {
      throw const AppFailure(_listMessage, code: 'invalid-response');
    }
    List<Shipment> part(String key) =>
        decoded[key] == null ? const [] : parseShipments(decoded[key]);
    return ShipmentSearch(
        available: part('disponibles'), taken: part('tomadas'));
  }

  @override
  Future<void> take(String id) async {
    await _api.send('PUT', '/api/encomiendas/tomar/${Uri.encodeComponent(id)}',
        forbiddenMessage: 'No tienes permiso para tomar esta encomienda.');
  }

  @override
  void close() => _api.close();
}

class ShipmentScope extends InheritedWidget {
  const ShipmentScope(
      {super.key, required this.repository, required super.child});
  final ShipmentRepository repository;
  static ShipmentRepository of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShipmentScope>()!.repository;
  @override
  bool updateShouldNotify(ShipmentScope oldWidget) =>
      repository != oldWidget.repository;
}

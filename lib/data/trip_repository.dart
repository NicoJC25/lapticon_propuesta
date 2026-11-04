import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import '../auth/auth_service.dart';
import '../utils/format.dart';
import 'api_client.dart';
import 'shipment_repository.dart';

/// Estados de viaje que maneja la API.
enum TripStatus {
  disponible('disponible', 'Disponible'),
  contactado('contactado', 'Contactado'),
  completado('completado', 'Completado'),
  cancelado('cancelado', 'Cancelado'),
  desconocido('', 'Sin estado');

  const TripStatus(this.apiValue, this.label);
  final String apiValue;
  final String label;
  static TripStatus parse(Object? value) {
    for (final status in values) {
      if (value is String && status.apiValue == value.trim().toLowerCase()) {
        return status;
      }
    }
    return desconocido;
  }
}

class Trip {
  const Trip(
      {required this.id,
      required this.flightNumber,
      required this.origin,
      required this.destination,
      required this.date,
      required this.status});
  final String id;
  final String flightNumber;
  final String origin;
  final String destination;
  final DateTime? date;
  final TripStatus status;

  factory Trip.fromJson(Map<String, dynamic> json) {
    String text(String key) => json[key] is String ? json[key] as String : '';
    return Trip(
        id: text('_id'),
        flightNumber: text('numeroVuelo'),
        origin: text('ciudadOrigen'),
        destination: text('ciudadDestino'),
        date: DateTime.tryParse(text('fechaViaje')),
        status: TripStatus.parse(json['estado']));
  }
}

class TripDraft {
  const TripDraft(
      {required this.flightNumber,
      required this.origin,
      required this.destination,
      required this.date});
  final String flightNumber;
  final Place origin;
  final Place destination;
  final DateTime date;

  Map<String, Object?> toJson() => {
        'numeroVuelo': normalizeFlightNumber(flightNumber),
        'ciudadOrigen': origin.city,
        'ciudadDestino': destination.city,
        'fechaViaje': isoDate(date),
      };
}

/// "av 9361" → "AV9361".
String normalizeFlightNumber(String value) =>
    value.replaceAll(RegExp(r'\s+'), '').toUpperCase();

/// Código IATA de aerolínea (2 caracteres) + 1 a 4 dígitos + letra opcional.
bool isValidFlightNumber(String value) =>
    RegExp(r'^[A-Z0-9]{2}\d{1,4}[A-Z]?$').hasMatch(normalizeFlightNumber(value));

enum FlightCheckResult { found, notFound, unavailable }

/// Resultado de `GET /api/vuelos/{numero}/{fecha}` (AeroDataBox).
class FlightCheck {
  const FlightCheck(this.result, {this.summary, this.message});
  final FlightCheckResult result;

  /// Resumen legible del vuelo encontrado, si la respuesta lo permite.
  final String? summary;

  /// Por qué no se pudo validar.
  final String? message;
}

abstract class TripRepository {
  /// Viaje disponible del usuario; `null` si no tiene (404).
  Future<Trip?> active();
  Future<List<Trip>> mine();
  Future<FlightCheck> checkFlight(String flightNumber, DateTime date);
  Future<Trip> register(TripDraft draft);
  Future<void> cancel(String id);
  void close() {}
}

class ApiTripRepository implements TripRepository {
  ApiTripRepository(AuthService auth,
      {http.Client? client,
      String baseUrl = defaultApiBaseUrl,
      Duration timeout = const Duration(seconds: 20)})
      : _api = ApiClient(auth,
            client: client, baseUrl: baseUrl, timeout: timeout);
  final ApiClient _api;
  static const _invalid = 'La respuesta del viaje no tiene el formato esperado.';
  static const _forbidden = 'No tienes permiso para gestionar este viaje.';

  Trip _trip(Object? decoded) {
    if (decoded is Map<String, dynamic>) {
      final nested = decoded['viaje'];
      final json = nested is Map<String, dynamic> ? nested : decoded;
      if (json['_id'] is String) return Trip.fromJson(json);
    }
    throw const AppFailure(_invalid, code: 'invalid-response');
  }

  @override
  Future<Trip?> active() async {
    final response = await _api.send('GET', '/api/viajes/disponible',
        allowNotFound: true, forbiddenMessage: _forbidden);
    if (response.statusCode == 404) return null;
    return _trip(_api.decode(response, _invalid));
  }

  @override
  Future<List<Trip>> mine() async {
    final response =
        await _api.send('GET', '/api/viajes', forbiddenMessage: _forbidden);
    final decoded = _api.decode(response, _invalid);
    final list = decoded is List
        ? decoded
        : decoded is Map && decoded['viajes'] is List
            ? decoded['viajes'] as List
            : null;
    if (list == null) {
      throw const AppFailure(_invalid, code: 'invalid-response');
    }
    return [
      for (final item in list)
        if (item is Map<String, dynamic> && item['_id'] is String)
          Trip.fromJson(item)
    ];
  }

  @override
  Future<FlightCheck> checkFlight(String flightNumber, DateTime date) async {
    final number = Uri.encodeComponent(normalizeFlightNumber(flightNumber));
    try {
      final response = await _api.send(
          'GET', '/api/vuelos/$number/${isoDate(date)}',
          authenticated: false, allowNotFound: true);
      if (response.statusCode == 404) {
        return const FlightCheck(FlightCheckResult.notFound);
      }
      Object? decoded;
      try {
        decoded = _api.decode(response, _invalid);
      } on AppFailure {
        decoded = null;
      }
      if (decoded is List && decoded.isEmpty) {
        return const FlightCheck(FlightCheckResult.notFound);
      }
      return FlightCheck(FlightCheckResult.found,
          summary: flightSummary(decoded));
    } on AppFailure catch (e) {
      // 5xx (p. ej. RAPIDAPI_KEY sin configurar), red o tiempo agotado: el
      // vuelo no se pudo comprobar, lo que no significa que no exista.
      if (const {'server', 'network', 'timeout', 'rate-limit'}
          .contains(e.code)) {
        return FlightCheck(FlightCheckResult.unavailable, message: e.message);
      }
      rethrow;
    }
  }

  @override
  Future<Trip> register(TripDraft draft) async {
    final response = await _api.send('POST', '/api/viajes',
        body: draft.toJson(), forbiddenMessage: _forbidden);
    return _trip(_api.decode(response, _invalid));
  }

  @override
  Future<void> cancel(String id) async {
    await _api.send(
        'PATCH', '/api/viajes/${Uri.encodeComponent(id)}/estado',
        body: {'estado': TripStatus.cancelado.apiValue},
        forbiddenMessage: _forbidden);
  }

  @override
  void close() => _api.close();
}

/// Resumen de un vuelo de AeroDataBox: "Avianca · Bogotá → Madrid".
/// Tolera que la respuesta sea una lista, un objeto o venga envuelta.
String? flightSummary(Object? decoded) {
  Object? flight = decoded;
  if (flight is Map && flight['vuelo'] != null) flight = flight['vuelo'];
  if (flight is Map && flight['data'] != null) flight = flight['data'];
  if (flight is List) flight = flight.isEmpty ? null : flight.first;
  if (flight is! Map) return null;
  String? at(List<String> path) {
    Object? value = flight;
    for (final key in path) {
      if (value is! Map) return null;
      value = value[key];
    }
    return value is String && value.trim().isNotEmpty ? value.trim() : null;
  }

  String? place(String side) =>
      at([side, 'airport', 'municipalityName']) ??
      at([side, 'airport', 'name']) ??
      at([side, 'airport', 'iata']);
  final airline = at(['airline', 'name']);
  final from = place('departure');
  final to = place('arrival');
  final parts = [
    if (airline != null) airline,
    if (from != null && to != null) '$from → $to',
  ];
  return parts.isEmpty ? null : parts.join(' · ');
}

class TripScope extends InheritedWidget {
  const TripScope({super.key, required this.repository, required super.child});
  final TripRepository repository;
  static TripRepository of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TripScope>()!.repository;
  @override
  bool updateShouldNotify(TripScope oldWidget) =>
      repository != oldWidget.repository;
}

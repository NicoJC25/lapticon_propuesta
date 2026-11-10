import '../auth/auth_service.dart';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import 'shipment_repository.dart';
import 'trip_repository.dart';

class AirportOption {
  const AirportOption(this.iata, this.label);
  final String iata, label;
}

class FlightOption {
  const FlightOption(this.number, this.airline, this.departure, this.originCode,
      this.destinationCode, this.origin, this.destination);
  final String number, airline, departure, originCode, destinationCode;
  final Place origin, destination;
  TripDraft get draft => TripDraft(
      flightNumber: number,
      origin: origin,
      destination: destination,
      date: DateTime.parse(departure.substring(0, 10)));
  factory FlightOption.fromJson(Map<String, dynamic> j) {
    final number = j['number'] as String;
    final departure = j['departure'] as String;
    if (!isValidFlightNumber(number) ||
        departure.length < 10 ||
        DateTime.tryParse(departure) == null) {
      throw const FormatException('Invalid flight');
    }
    Place place(String k) =>
        Place(city: j[k]['city'] as String, country: j[k]['country'] as String);
    return FlightOption(
        number,
        j['airline'] as String,
        departure,
        j['origin']['iata'] as String,
        j['destination']['iata'] as String,
        place('origin'),
        place('destination'));
  }
}

/// Adaptador servidor de flight_proxy/. Nunca lleva RAPIDAPI_KEY en Android.
class FlightCatalog {
  FlightCatalog(AuthService auth,
      {String baseUrl = const String.fromEnvironment('FLIGHT_SEARCH_BASE_URL'),
      http.Client? client})
      : _api = baseUrl.isEmpty
            ? null
            : ApiClient(auth, baseUrl: baseUrl, client: client);
  final ApiClient? _api;
  Future<List<AirportOption>> airports(String query) async {
    final api = _api;
    if (api == null) {
      throw const AppFailure(
          'Falta conectar el catálogo de vuelos. Consulta la guía de configuración.',
          code: 'configuration');
    }
    try {
      final response =
          await api.send('GET', '/api/flights/airports', query: {'q': query});
      final list =
          api.decode(response, 'Respuesta de aeropuertos inválida.') as List;
      return list
          .map((j) => AirportOption(j['iata'] as String, j['label'] as String))
          .toList();
    } on TypeError {
      throw const AppFailure('Respuesta de aeropuertos inválida.',
          code: 'invalid-response');
    }
  }

  Future<List<FlightOption>> search(
      String origin, String destination, String date) async {
    final api = _api;
    if (api == null) {
      throw const AppFailure(
          'Falta configurar FLIGHT_SEARCH_BASE_URL. Consulta la guía de vuelos para conectar el catálogo real.',
          code: 'configuration');
    }
    try {
      final r = await api.send('GET', '/api/flights/search',
          query: {'origin': origin, 'destination': destination, 'date': date});
      final list = api.decode(r, 'Respuesta de vuelos inválida.') as List;
      final flights = list
          .map((j) => FlightOption.fromJson(j as Map<String, dynamic>))
          .toList();
      if (flights.any((f) =>
          f.originCode != origin ||
          f.destinationCode != destination ||
          !f.departure.startsWith(date))) {
        throw const FormatException('Route mismatch');
      }
      return flights;
    } on TypeError {
      throw const AppFailure('Respuesta de vuelos inválida.',
          code: 'invalid-response');
    } on FormatException {
      throw const AppFailure(
          'Los vuelos no corresponden a la ruta o fecha solicitada.',
          code: 'invalid-response');
    }
  }

  void close() => _api?.close();
}

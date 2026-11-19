import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lapticon/auth/auth_service.dart';
import 'package:lapticon/data/flight_catalog.dart';
import 'package:lapticon/data/flight_city.dart';
import 'package:lapticon/data/shipment_repository.dart';
import 'package:lapticon/data/trip_repository.dart';
import 'fakes.dart';

Map<String, Object?> parcel(String id, {String state = 'disponible'}) => {
      '_id': id,
      'ciudadOrigen': 'Cali',
      'ciudadDestino': 'Medellín',
      'estado': state,
      'uid': 'otra-cuenta',
    };
http.Response response(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status,
        headers: {'content-type': 'application/json; charset=utf-8'});

void main() {
  test('El vuelo CLO/MDE usa las ciudades del servicio y no los municipios',
      () {
    final flight = FlightOption.fromJson({
      'number': 'AV40',
      'airline': 'Avianca',
      'departure': '2026-11-26T08:00:00',
      'origin': {'iata': 'CLO', 'city': 'Santiago de Cali', 'country': 'CO'},
      'destination': {'iata': 'MDE', 'city': 'Rionegro', 'country': 'CO'},
    });
    expect(flight.draft.origin, FlightCity.cali.place);
    expect(flight.draft.destination, FlightCity.medellin.place);
    expect(flight.draft.toJson()['ciudadOrigen'], 'Cali');
    expect(flight.draft.toJson()['ciudadDestino'], 'Medellín');
  });

  test('El viaje antiguo y la encomienda nueva comparten los mismos nombres',
      () {
    final trip = Trip.fromJson({
      '_id': 'viaje-antiguo',
      'numeroVuelo': 'AV40',
      'ciudadOrigen': 'Santiago de Cali',
      'ciudadDestino': 'Rionegro',
      'fechaViaje': '2026-11-26',
      'estado': 'disponible',
    });
    expect(trip.origin, 'Cali');
    expect(trip.destination, 'Medellín');
    final draft = ShipmentDraft(
        origin: const Place(city: 'Santiago de Cali', country: 'Colombia'),
        destination: const Place(city: 'Medellin', country: 'Colombia'),
        notes: 'Libros',
        currency: 'COP',
        value: 10000);
    expect(draft.toJson()['ciudadOrigen'], trip.origin);
    expect(draft.toJson()['ciudadDestino'], trip.destination);
    expect(FlightCity.canonicalName('Madrid'), 'Madrid');
  });

  test('Busca registros antiguos y nuevos de la misma ruta, sin duplicarlos',
      () async {
    final auth = FakeAuthService(user: testUser);
    final queries = <Map<String, String>>[];
    final repo = ApiShipmentRepository(auth, client: MockClient((r) async {
      expect(r.headers['Authorization'], 'Bearer initial-test-token');
      final q = r.url.queryParameters;
      queries.add(q);
      if (q['origen'] == 'Cali' && q['destino'] == 'Medellín') {
        return response({
          'disponibles': [parcel('nueva'), parcel('duplicada')],
          'tomadas': []
        });
      }
      if (q['origen'] == 'Santiago de Cali' && q['destino'] == 'Rionegro') {
        return response({
          'disponibles': [parcel('antigua'), parcel('duplicada')],
          'tomadas': []
        });
      }
      if (q['origen'] == 'Cali' && q['destino'] == 'Medellin') {
        return response({
          'disponibles': [],
          'tomadas': [parcel('duplicada', state: 'tomada')]
        });
      }
      return response({'disponibles': [], 'tomadas': []});
    }));
    final result = await repo.search('Santiago de Cali', 'Rionegro');
    expect(queries, hasLength(6));
    expect(
        queries.every((q) =>
            ['Cali', 'Santiago de Cali'].contains(q['origen']) &&
            ['Medellín', 'Medellin', 'Rionegro'].contains(q['destino'])),
        isTrue);
    expect(result.available.map((s) => s.id).toSet(), {'nueva', 'antigua'});
    expect(result.taken.single.id, 'duplicada');
    repo.close();
    await auth.close();
  });

  test('Un error o contrato inválido no se presenta como una ruta vacía',
      () async {
    for (final status in [200, 403, 500]) {
      final auth = FakeAuthService(user: testUser);
      final repo = ApiShipmentRepository(auth,
          client: MockClient((_) async => response({'ok': true}, status)));
      await expectLater(
          repo.search('Cali', 'Medellín'), throwsA(isA<AppFailure>()));
      repo.close();
      await auth.close();
    }
  });
}

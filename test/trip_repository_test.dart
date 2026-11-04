import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lapticon/auth/auth_service.dart';
import 'package:lapticon/data/shipment_repository.dart';
import 'package:lapticon/data/trip_repository.dart';
import 'fakes.dart';

http.Response jsonResponse(Object body, [int status = 200]) => http.Response(
    jsonEncode(body), status,
    headers: {'content-type': 'application/json; charset=utf-8'});

Matcher failure(String code) =>
    isA<AppFailure>().having((e) => e.code, 'code', code);

const viajeJson = {
  '_id': 'v-1',
  'uid': 'u-123',
  'numeroVuelo': 'AV9361',
  'ciudadOrigen': 'Bogotá',
  'ciudadDestino': 'Madrid',
  'fechaViaje': '2026-11-07T00:00:00.000Z',
  'estado': 'disponible',
};

void main() {
  late FakeAuthService auth;
  setUp(() => auth = FakeAuthService(user: testUser));
  tearDown(() async => auth.close());

  test('POST /api/viajes envía vuelo normalizado, ruta y fecha', () async {
    final requests = <http.Request>[];
    final repo = ApiTripRepository(auth, client: MockClient((r) async {
      requests.add(r);
      return jsonResponse(viajeJson, 201);
    }));
    final trip = await repo.register(TripDraft(
        flightNumber: ' av 9361 ',
        origin: const Place(country: 'Colombia', city: 'Bogotá'),
        destination: const Place(country: 'España', city: 'Madrid'),
        date: DateTime(2026, 11, 7)));
    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/api/viajes');
    expect(requests.single.headers['Authorization'], 'Bearer initial-test-token');
    expect(jsonDecode(requests.single.body), {
      'numeroVuelo': 'AV9361',
      'ciudadOrigen': 'Bogotá',
      'ciudadDestino': 'Madrid',
      'fechaViaje': '2026-11-07',
    });
    expect(trip.id, 'v-1');
    expect(trip.status, TripStatus.disponible);
    // Fecha sin hora: medianoche UTC, se muestra como el 7 y no el 6.
    expect(trip.date!.isUtc, isTrue);
    expect(trip.date!.day, 7);
    repo.close();
  });

  test('Ya existe un viaje: el 400 muestra el mensaje de la API', () async {
    final repo = ApiTripRepository(auth,
        client: MockClient((_) async => jsonResponse(
            {'error': 'Ya existe un viaje disponible para este usuario'}, 400)));
    await expectLater(
        repo.register(TripDraft(
            flightNumber: 'AV9361',
            origin: const Place(country: 'Colombia', city: 'Bogotá'),
            destination: const Place(country: 'España', city: 'Madrid'),
            date: DateTime(2026, 11, 7))),
        throwsA(isA<AppFailure>().having((e) => e.message, 'message',
            'Ya existe un viaje disponible para este usuario')));
    repo.close();
  });

  test('Viaje activo: 200 lo devuelve y 404 significa que no hay', () async {
    var found = true;
    final repo = ApiTripRepository(auth, client: MockClient((r) async {
      expect(r.url.path, '/api/viajes/disponible');
      return found
          ? jsonResponse(viajeJson)
          : jsonResponse({'error': 'No hay viajes disponibles'}, 404);
    }));
    expect((await repo.active())!.flightNumber, 'AV9361');
    found = false;
    expect(await repo.active(), isNull);
    repo.close();
  });

  test('Cancelar usa PATCH con estado cancelado', () async {
    late http.Request request;
    final repo = ApiTripRepository(auth, client: MockClient((r) async {
      request = r;
      return jsonResponse({'mensaje': 'Estado actualizado'});
    }));
    await repo.cancel('v-1');
    expect(request.method, 'PATCH');
    expect(request.url.path, '/api/viajes/v-1/estado');
    expect(jsonDecode(request.body), {'estado': 'cancelado'});
    repo.close();
  });

  group('Validar vuelo', () {
    Future<FlightCheck> check(http.Response Function(http.Request) reply) async {
      late http.Request request;
      final repo = ApiTripRepository(auth, client: MockClient((r) async {
        request = r;
        return reply(r);
      }));
      final result = await repo.checkFlight('av9361', DateTime(2026, 11, 7));
      expect(request.url.path, '/api/vuelos/AV9361/2026-11-07');
      expect(request.headers.containsKey('Authorization'), isFalse);
      repo.close();
      return result;
    }

    test('Encontrado resume aerolínea y ruta', () async {
      final result = await check((_) => jsonResponse([
            {
              'number': 'AV 9361',
              'airline': {'name': 'Avianca'},
              'departure': {
                'airport': {'municipalityName': 'Bogotá', 'iata': 'BOG'}
              },
              'arrival': {
                'airport': {'name': 'Madrid Barajas', 'iata': 'MAD'}
              }
            }
          ]));
      expect(result.result, FlightCheckResult.found);
      expect(result.summary, 'Avianca · Bogotá → Madrid Barajas');
    });

    test('404 o lista vacía: el vuelo no existe', () async {
      expect((await check((_) => jsonResponse({'error': 'x'}, 404))).result,
          FlightCheckResult.notFound);
      expect((await check((_) => jsonResponse([]))).result,
          FlightCheckResult.notFound);
    });

    test('500 del servidor (sin RAPIDAPI_KEY): no se pudo validar', () async {
      final result = await check((_) => jsonResponse(
          {'error': 'RAPIDAPI_KEY no está configurada en el servidor'}, 500));
      expect(result.result, FlightCheckResult.unavailable);
      expect(auth.logoutCalls, 0);
    });

    test('Respuesta con formato desconocido cuenta como encontrado', () async {
      final result = await check((_) => jsonResponse({'ok': true}));
      expect(result.result, FlightCheckResult.found);
      expect(result.summary, isNull);
    });
  });

  test('Formato del número de vuelo', () {
    expect(isValidFlightNumber('AV9361'), isTrue);
    expect(isValidFlightNumber('av 9361'), isTrue);
    expect(isValidFlightNumber('LA2425A'), isTrue);
    expect(isValidFlightNumber('U21234'), isTrue);
    expect(isValidFlightNumber('AVIANCA'), isFalse);
    expect(isValidFlightNumber('A1'), isFalse);
    expect(isValidFlightNumber('AV12345'), isFalse);
  });

  group('Encomiendas del viajero y del remitente', () {
    Map<String, Object?> encomienda(String id, String estado) => {
          '_id': id,
          'uid': 'remitente-1',
          'ciudadOrigen': 'Bogotá',
          'ciudadDestino': 'Madrid',
          'observaciones': 'Libros',
          'moneda': 'COP',
          'valor': 1000,
          'estado': estado,
          'viajeroId': estado == 'tomada' ? 'u-123' : null,
        };

    test('Mis encomiendas lee el arreglo de GET /api/encomiendas', () async {
      final repo = ApiShipmentRepository(auth,
          client: MockClient((r) async {
            expect(r.url.path, '/api/encomiendas');
            expect(r.headers['Authorization'], 'Bearer initial-test-token');
            return jsonResponse(
                [encomienda('e1', 'disponible'), encomienda('e2', 'vencida')]);
          }));
      final items = await repo.mine();
      expect(items.map((s) => s.status),
          [ShipmentStatus.disponible, ShipmentStatus.vencida]);
      expect(items.first.ownerId, 'remitente-1');
      repo.close();
    });

    test('Buscar envía origen y destino y separa disponibles y tomadas',
        () async {
      late http.Request request;
      final repo = ApiShipmentRepository(auth, client: MockClient((r) async {
        request = r;
        return jsonResponse({
          'disponibles': [encomienda('e1', 'disponible')],
          'tomadas': [encomienda('e2', 'tomada')],
        });
      }));
      final result = await repo.search('Bogotá', 'Madrid');
      expect(request.url.path, '/api/encomiendas/buscar');
      expect(request.url.queryParameters,
          {'origen': 'Bogotá', 'destino': 'Madrid'});
      expect(result.available.single.id, 'e1');
      expect(result.taken.single.travelerId, 'u-123');
      repo.close();
    });

    test('Tomar usa PUT y un 400 explica que ya fue tomada', () async {
      final requests = <http.Request>[];
      var taken = false;
      final repo = ApiShipmentRepository(auth, client: MockClient((r) async {
        requests.add(r);
        if (taken) {
          return jsonResponse({'error': 'Ya fue tomada o venció'}, 400);
        }
        taken = true;
        return jsonResponse({'mensaje': 'Encomienda tomada'});
      }));
      await repo.take('e1');
      expect(requests.single.method, 'PUT');
      expect(requests.single.url.path, '/api/encomiendas/tomar/e1');
      await expectLater(
          repo.take('e1'),
          throwsA(isA<AppFailure>()
              .having((e) => e.message, 'message', 'Ya fue tomada o venció')));
      repo.close();
    });

    test('Lista con formato inválido se rechaza', () async {
      final repo = ApiShipmentRepository(auth,
          client: MockClient((_) async => jsonResponse({'ok': true})));
      await expectLater(repo.mine(), throwsA(failure('invalid-response')));
      repo.close();
    });
  });
}

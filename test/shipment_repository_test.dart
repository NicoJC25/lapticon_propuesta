import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lapticon/auth/auth_service.dart';
import 'package:lapticon/data/shipment_repository.dart';
import 'fakes.dart';

Matcher failure(String code) =>
    isA<AppFailure>().having((e) => e.code, 'code', code);

http.Response jsonResponse(Object body, [int status = 200]) => http.Response(
    jsonEncode(body), status,
    headers: {'content-type': 'application/json; charset=utf-8'});

const bogota = Place(country: 'Colombia', city: 'Bogotá');
const madrid = Place(country: 'España', city: 'Madrid');

Map<String, Object?> encomiendaJson({String? vence}) => {
      '_id': '665f1c2a9b1e8a0012345678',
      'uid': 'u-123',
      'ciudadOrigen': 'Bogotá',
      'ciudadDestino': 'Madrid',
      'observaciones': 'Dos libros',
      'moneda': 'COP',
      'valor': 50000,
      'estado': 'disponible',
      'fechaCreacion': '2026-11-04T15:00:00.000Z',
      if (vence != null) 'fechaVencimiento': vence,
    };

void main() {
  late FakeAuthService auth;
  setUp(() => auth = FakeAuthService(user: testUser));
  tearDown(() async => auth.close());

  test('POST /api/encomiendas envía token y el contrato del Swagger', () async {
    final requests = <http.Request>[];
    final repo = ApiShipmentRepository(auth, client: MockClient((r) async {
      requests.add(r);
      return jsonResponse(encomiendaJson(vence: '2026-11-20T00:00:00.000Z'), 201);
    }));
    final created = await repo.create(ShipmentDraft(
        origin: bogota,
        destination: madrid,
        notes: '  Dos libros  ',
        currency: 'COP',
        value: 50000,
        expiresOn: DateTime(2026, 11, 20)));
    final request = requests.single;
    expect(request.method, 'POST');
    expect(request.url.toString(),
        'https://lapticon-backend.onrender.com/api/encomiendas');
    expect(request.headers['Authorization'], 'Bearer initial-test-token');
    expect(request.followRedirects, isFalse);
    expect(jsonDecode(request.body), {
      'ciudadOrigen': 'Bogotá',
      'ciudadDestino': 'Madrid',
      'observaciones': 'Dos libros',
      'moneda': 'COP',
      'valor': 50000,
      'fechaVencimiento': '2026-11-20',
    });
    expect(created.id, '665f1c2a9b1e8a0012345678');
    expect(created.status, ShipmentStatus.disponible);
    expect(created.value, 50000);
    expect(created.expiresAt, DateTime.utc(2026, 11, 20));
    repo.close();
  });

  test('Sin fecha límite no se envía fechaVencimiento', () async {
    late Map<String, dynamic> body;
    final repo = ApiShipmentRepository(auth, client: MockClient((r) async {
      body = jsonDecode(r.body) as Map<String, dynamic>;
      return jsonResponse({'encomienda': encomiendaJson()}, 201);
    }));
    final created = await repo.create(const ShipmentDraft(
        origin: bogota,
        destination: madrid,
        notes: 'Dos libros',
        currency: 'USD',
        value: 20));
    expect(body.containsKey('fechaVencimiento'), isFalse);
    expect(body['moneda'], 'USD');
    expect(created.expiresAt, isNull);
    repo.close();
  });

  test('Países y ciudades son públicos, ordenados y se guardan en memoria',
      () async {
    final requests = <http.Request>[];
    final repo = ApiShipmentRepository(auth, client: MockClient((r) async {
      requests.add(r);
      return r.url.path.endsWith('/paises')
          ? jsonResponse(['Colombia', 'Argentina', 'Colombia', ''])
          : jsonResponse(['Madrid', 'barcelona']);
    }));
    expect(await repo.countries(), ['Argentina', 'Colombia']);
    expect(await repo.cities('España'), ['barcelona', 'Madrid']);
    await repo.countries();
    await repo.cities('España');
    expect(requests, hasLength(2));
    expect(requests.every((r) => !r.headers.containsKey('Authorization')),
        isTrue);
    expect(requests.last.url.path, '/api/ciudades/ciudades-por-pais');
    expect(requests.last.url.queryParameters, {'nombre': 'España'});
    expect(auth.tokenRequests, isEmpty);
    repo.close();
  });

  test('Un 400 muestra el mensaje de la API', () async {
    final repo = ApiShipmentRepository(auth,
        client: MockClient(
            (_) async => jsonResponse({'error': 'Faltan campos obligatorios'}, 400)));
    await expectLater(
        repo.create(const ShipmentDraft(
            origin: bogota,
            destination: madrid,
            notes: 'x',
            currency: 'COP',
            value: 1)),
        throwsA(isA<AppFailure>()
            .having((e) => e.code, 'code', 'api')
            .having((e) => e.message, 'message', 'Faltan campos obligatorios')));
    repo.close();
  });

  test('Respuesta sin encomienda o lista inválida se rechaza', () async {
    final repo = ApiShipmentRepository(auth,
        client: MockClient((_) async => jsonResponse({'ok': true}, 201)));
    await expectLater(
        repo.create(const ShipmentDraft(
            origin: bogota,
            destination: madrid,
            notes: 'x',
            currency: 'COP',
            value: 1)),
        throwsA(failure('invalid-response')));
    repo.close();
    final places = ApiShipmentRepository(auth,
        client: MockClient((_) async => http.Response('no-json', 200)));
    await expectLater(places.countries(), throwsA(failure('invalid-response')));
    places.close();
  });

  test('Segundo 401 al crear cierra la sesión', () async {
    var calls = 0;
    final repo = ApiShipmentRepository(auth, client: MockClient((_) async {
      calls++;
      return http.Response('', 401);
    }));
    await expectLater(
        repo.create(const ShipmentDraft(
            origin: bogota,
            destination: madrid,
            notes: 'x',
            currency: 'COP',
            value: 1)),
        throwsA(failure('session-expired')));
    expect(calls, 2);
    expect(auth.tokenRequests, [false, true]);
    expect(auth.logoutCalls, 1);
    repo.close();
  });
}

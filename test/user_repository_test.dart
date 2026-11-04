import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lapticon/auth/auth_service.dart';
import 'package:lapticon/data/user_repository.dart';
import 'package:lapticon/roles/user_role.dart';
import 'fakes.dart';

http.Response profileResponse() => http.Response(
    jsonEncode({
      'user': {'uid': 'u-123', 'nombre': 'Ana', 'apellido': 'Gómez'}
    }),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'});
Matcher failure(String code) =>
    isA<AppFailure>().having((e) => e.code, 'code', code);

void main() {
  late FakeAuthService auth;
  setUp(() {
    auth = FakeAuthService(user: testUser);
  });
  tearDown(() async {
    await auth.close();
  });
  test('GET usa token actual y perfil; POST solo datos de perfil', () async {
    final requests = <http.Request>[];
    final repo = ApiUserRepository(auth, client: MockClient((r) async {
      requests.add(r);
      return profileResponse();
    }));
    expect((await repo.fetch(testUser))!.fullName, 'Ana Gómez');
    await repo.create(testUser, ' Ana ', ' Gómez ');
    expect(requests.first.url.toString(),
        'https://lapticon-backend.onrender.com/api/users/u-123');
    expect(
        requests.first.headers['Authorization'], 'Bearer initial-test-token');
    expect(requests.last.method, 'POST');
    expect(requests.last.url.path, '/api/users/register');
    expect(jsonDecode(requests.last.body),
        {'nombre': 'Ana', 'apellido': 'Gómez', 'correo': 'ana@example.com'});
    expect(requests.last.followRedirects, isFalse);
    repo.close();
  });
  test('401 renueva una sola vez y usa token nuevo', () async {
    var calls = 0;
    final repo = ApiUserRepository(auth, client: MockClient((r) async {
      calls++;
      if (calls == 1) return http.Response('', 401);
      expect(r.headers['Authorization'], 'Bearer renewed-test-token');
      return profileResponse();
    }));
    await repo.fetch(testUser);
    expect(auth.tokenRequests, [false, true]);
    expect(auth.logoutCalls, 0);
    expect(calls, 2);
    repo.close();
  });
  test('Segundo 401 cierra sesión sin bucle de reintentos', () async {
    var calls = 0;
    final repo = ApiUserRepository(auth, client: MockClient((_) async {
      calls++;
      return http.Response('', 401);
    }));
    await expectLater(
        repo.fetch(testUser), throwsA(failure('session-expired')));
    expect(calls, 2);
    expect(auth.logoutCalls, 1);
    repo.close();
  });
  test('Token revocado cierra sesión sin enviar solicitud', () async {
    auth.tokenFailure =
        const AppFailure('Sesión terminada', code: 'session-expired');
    var calls = 0;
    final repo = ApiUserRepository(auth, client: MockClient((_) async {
      calls++;
      return profileResponse();
    }));
    await expectLater(
        repo.fetch(testUser), throwsA(failure('session-expired')));
    expect(calls, 0);
    expect(auth.logoutCalls, 1);
    repo.close();
  });
  test('403 no renueva token ni cierra una sesión válida', () async {
    final repo = ApiUserRepository(auth,
        client: MockClient((_) async => http.Response('', 403)));
    await expectLater(repo.fetch(testUser), throwsA(failure('forbidden')));
    expect(auth.tokenRequests, [false]);
    expect(auth.logoutCalls, 0);
    repo.close();
  });
  test('404 permite completar perfil y 500 permite reintentar', () async {
    final repo = ApiUserRepository(auth,
        client: MockClient((_) async => http.Response('', 404)));
    expect(await repo.fetch(testUser), isNull);
    repo.close();
    final failed = ApiUserRepository(auth,
        client: MockClient((_) async => http.Response('', 503)));
    await expectLater(
        failed.create(testUser, 'Ana', 'Gómez'), throwsA(failure('server')));
    expect(auth.logoutCalls, 0);
    failed.close();
  });
  test('Tiempo agotado y red tienen errores distinguibles', () async {
    final slow = ApiUserRepository(auth,
        timeout: const Duration(milliseconds: 1),
        client: MockClient((_) => Completer<http.Response>().future));
    await expectLater(slow.fetch(testUser), throwsA(failure('timeout')));
    slow.close();
    final offline = ApiUserRepository(auth,
        client: MockClient((_) async => throw http.ClientException('offline')));
    await expectLater(offline.fetch(testUser), throwsA(failure('network')));
    offline.close();
  });
  test('Respuesta inválida o de otro usuario no abre sesión completa',
      () async {
    for (final body in ['not-json', '{}', '{"user":{"uid":"otro-uid"}}']) {
      final repo = ApiUserRepository(auth,
          client: MockClient((_) async => http.Response(body, 200)));
      await expectLater(
          repo.fetch(testUser), throwsA(failure('invalid-response')));
      repo.close();
    }
  });
  test('Config rechaza HTTP, rutas, fragmentos y credenciales', () {
    for (final url in [
      'http://example.com',
      'https://example.com/api',
      'https://example.com?key=x',
      'https://user:secret@example.com',
      'https://example.com/#fragment'
    ]) {
      expect(() => ApiUserRepository(auth, baseUrl: url),
          throwsA(failure('configuration')));
    }
  });
  test('Perfil con rol en el servidor lo interpreta', () async {
    final repo = ApiUserRepository(auth,
        client: MockClient((_) async => http.Response(
            jsonEncode({
              'user': {
                'uid': 'u-123',
                'nombre': 'Ana',
                'apellido': 'Gómez',
                'rol': 'viajero'
              }
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'})));
    expect((await repo.fetch(testUser))!.role, UserRole.viajero);
    repo.close();
  });
  test('saveRole usa PUT del dueño, conserva nombre y no envía uid ni correo',
      () async {
    final requests = <http.Request>[];
    var keepsRole = true;
    final repo = ApiUserRepository(auth, client: MockClient((r) async {
      requests.add(r);
      return http.Response(
          jsonEncode({
            'uid': 'u-123',
            'nombre': 'Ana',
            'apellido': 'Gómez',
            if (keepsRole) 'rol': 'remitente'
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }));
    expect(await repo.saveRole(testUser, testProfile, UserRole.remitente),
        UserRole.remitente);
    expect(requests.single.method, 'PUT');
    expect(requests.single.url.path, '/api/users/u-123');
    expect(
        requests.single.headers['Authorization'], 'Bearer initial-test-token');
    expect(jsonDecode(requests.single.body),
        {'nombre': 'Ana', 'apellido': 'Gómez', 'rol': 'remitente'});
    keepsRole = false;
    expect(
        await repo.saveRole(testUser, testProfile, UserRole.remitente), isNull);
    repo.close();
  });
}

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:lapticon/auth/auth_controller.dart';
import 'package:lapticon/auth/auth_service.dart';
import 'fakes.dart';

Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeAuthService auth;
  late FakeUserRepository users;
  late AuthController controller;
  setUp(() async {
    auth = FakeAuthService();
    users = FakeUserRepository();
    controller = AuthController(auth, users);
    await tick();
  });
  tearDown(() async {
    controller.dispose();
    await auth.close();
  });

  test('Configuración ausente bloquea operaciones y no consulta la API',
      () async {
    final c = AuthController(const UnconfiguredAuthService(), users);
    await tick();
    expect(c.available, isFalse);
    expect(await c.signIn('a@example.com', 'demo123'), isFalse);
    expect(await c.register('a@example.com', 'demo123', 'A', 'B'), isFalse);
    expect(await c.google(), isFalse);
    expect(await c.recover('a@example.com'), isFalse);
    expect(c.signedIn, isFalse);
    expect(users.reads, 0);
    c.dispose();
  });
  test('Login consulta perfil existente sin sobrescribirlo', () async {
    users.stored = testProfile;
    expect(await controller.signIn('ana@example.com', 'demo123'), isTrue);
    expect(controller.phase, SessionPhase.ready);
    expect(controller.profile!.fullName, 'Ana Gómez');
    expect(users.writes, 0);
  });
  test('Credenciales rechazadas o correo existente conservan estado sin sesión',
      () async {
    auth.failure =
        const AppFailure('El correo o la contraseña no son correctos.');
    expect(await controller.signIn('ana@example.com', 'incorrecta'), isFalse);
    expect(controller.signedIn, isFalse);
    expect(controller.error, contains('no son correctos'));
    auth.failure = const AppFailure('Este correo ya tiene una cuenta.');
    expect(
        await controller.register('ana@example.com', 'demo123', 'Ana', 'Gómez'),
        isFalse);
    expect(users.writes, 0);
    expect(controller.busy, isFalse);
  });
  test('Google cancelado no autentica ni muestra error', () async {
    auth.googleCancelled = true;
    await controller.google();
    expect(controller.signedIn, isFalse);
    expect(controller.error, isNull);
    expect(users.reads, 0);
  });
  test('Google sin perfil solicita datos y completa con POST', () async {
    await controller.google();
    expect(controller.phase, SessionPhase.needsProfile);
    expect(users.writes, 0);
    await controller.completeProfile(' Ana ', ' Gómez ');
    expect(controller.phase, SessionPhase.ready);
    expect(controller.profile!.fullName, 'Ana Gómez');
    expect(auth.googleCalls, 1);
    expect(users.writes, 1);
  });
  test('Registro guarda perfil y fallo parcial se reintenta sin recrear cuenta',
      () async {
    users.createFailure =
        const AppFailure('La API no está disponible.', code: 'server');
    await controller.register('ana@example.com', 'demo123', 'Ana', 'Gómez');
    expect(controller.signedIn, isTrue);
    expect(controller.phase, SessionPhase.profileError);
    users.createFailure = null;
    await controller.retryProfile();
    expect(controller.phase, SessionPhase.ready);
    expect(auth.registerCalls, 1);
    expect(controller.profile!.name, 'Ana');
  });
  test('Si POST llegó pero se perdió respuesta, reintentar GET no repite POST',
      () async {
    users.createFailure = const AppFailure('Tiempo agotado', code: 'timeout');
    await controller.register('ana@example.com', 'demo123', 'Ana', 'Gómez');
    users.stored = testProfile;
    users.createFailure = null;
    await controller.retryProfile();
    expect(users.writes, 1);
    expect(controller.phase, SessionPhase.ready);
  });
  test('Restauración consulta perfil y cerrar sesión limpia datos', () async {
    controller.dispose();
    auth.user = testUser;
    users.stored = testProfile;
    controller = AuthController(auth, users);
    await tick();
    expect(controller.phase, SessionPhase.ready);
    expect(auth.loginCalls, 0);
    await controller.signOut();
    expect(controller.user, isNull);
    expect(controller.profile, isNull);
    expect(auth.logoutCalls, 1);
  });
  test('Bloquea envíos duplicados mientras Firebase está ocupado', () async {
    auth.gate = Completer<void>();
    users.stored = testProfile;
    final first = controller.signIn('ana@example.com', 'demo123');
    expect(controller.busy, isTrue);
    expect(await controller.signIn('ana@example.com', 'demo123'), isFalse);
    expect(await controller.google(), isFalse);
    auth.gate!.complete();
    await first;
    expect(auth.loginCalls, 1);
    expect(auth.googleCalls, 0);
  });
  test('Recuperación no autentica; fallo de red no cuenta como enviada',
      () async {
    expect(await controller.recover('ana@example.com'), isTrue);
    expect(controller.signedIn, isFalse);
    auth.failure = const AppFailure('Sin conexión', code: 'network');
    expect(await controller.recover('ana@example.com'), isFalse);
    expect(controller.error, 'Sin conexión');
  });
  test('Una respuesta tardía no restaura un perfil tras cerrar sesión',
      () async {
    controller.dispose();
    auth.user = testUser;
    users.stored = testProfile;
    users.gate = Completer<void>();
    controller = AuthController(auth, users);
    await tick();
    expect(controller.phase, SessionPhase.loadingProfile);
    await controller.signOut();
    users.fetchFailure =
        const AppFailure('Error de una consulta anterior', code: 'network');
    users.gate!.complete();
    await tick();
    expect(controller.phase, SessionPhase.signedOut);
    expect(controller.profile, isNull);
    expect(controller.error, isNull);
  });
}

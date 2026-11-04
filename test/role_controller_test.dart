import 'package:flutter_test/flutter_test.dart';
import 'package:lapticon/auth/auth_controller.dart';
import 'package:lapticon/auth/auth_service.dart';
import 'package:lapticon/data/user_repository.dart';
import 'package:lapticon/roles/role_controller.dart';
import 'package:lapticon/roles/role_store.dart';
import 'package:lapticon/roles/user_role.dart';
import 'fakes.dart';

Future<void> flush() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakeAuthService auth;
  late FakeUserRepository users;
  late MemoryRoleStore store;
  late AuthController controller;
  late RoleController roles;

  Future<void> start() async {
    controller = AuthController(auth, users);
    roles = RoleController(controller, store);
    await flush();
  }

  setUp(() {
    auth = FakeAuthService(user: testUser);
    users = FakeUserRepository()..stored = testProfile;
    store = MemoryRoleStore();
  });
  tearDown(() async {
    roles.dispose();
    controller.dispose();
    await auth.close();
  });

  test('Sesión sin rol guardado pide elegir', () async {
    await start();
    expect(controller.phase, SessionPhase.ready);
    expect(roles.needsChoice, isTrue);
    expect(roles.role, isNull);
  });

  test('Elegir guarda en la caché, intenta el servidor y avisa si no lo conserva',
      () async {
    await start();
    await roles.choose(UserRole.remitente);
    expect(roles.role, UserRole.remitente);
    expect(store.roles['u-123'], UserRole.remitente);
    expect(users.savedRoles, [UserRole.remitente]);
    expect(roles.notice, contains('servidor todavía no lo conserva'));
    roles.dismissNotice();
    expect(roles.notice, isNull);
  });

  test('Servidor que conserva el rol no muestra aviso', () async {
    users.serverKeepsRole = true;
    await start();
    await roles.choose(UserRole.viajero);
    expect(roles.role, UserRole.viajero);
    expect(roles.notice, isNull);
  });

  test('Fallo del servidor conserva el rol local y lo informa', () async {
    users.roleFailure =
        const AppFailure('La API no está disponible.', code: 'server');
    await start();
    await roles.choose(UserRole.viajero);
    expect(roles.role, UserRole.viajero);
    expect(store.roles['u-123'], UserRole.viajero);
    expect(roles.notice, contains('no se pudo sincronizar'));
  });

  test('Al reabrir la app se restaura el rol de la caché del mismo uid',
      () async {
    store.roles['u-123'] = UserRole.viajero;
    store.roles['otro-uid'] = UserRole.remitente;
    await start();
    expect(roles.role, UserRole.viajero);
    expect(roles.needsChoice, isFalse);
  });

  test('El rol de otra cuenta en el mismo teléfono no se reutiliza', () async {
    store.roles['otro-uid'] = UserRole.viajero;
    await start();
    expect(roles.needsChoice, isTrue);
  });

  test('El rol del perfil en el servidor manda y actualiza la caché', () async {
    users.stored = const UserProfile(
        uid: 'u-123',
        email: 'ana@example.com',
        name: 'Ana',
        surname: 'Gómez',
        role: UserRole.viajero);
    store.roles['u-123'] = UserRole.remitente;
    await start();
    expect(roles.role, UserRole.viajero);
    expect(store.roles['u-123'], UserRole.viajero);
  });

  test('Cerrar sesión olvida el rol en memoria pero conserva la caché',
      () async {
    await start();
    await roles.choose(UserRole.remitente);
    await controller.signOut();
    await flush();
    expect(roles.role, isNull);
    expect(roles.needsChoice, isFalse);
    expect(store.roles['u-123'], UserRole.remitente);
  });

  test('Cambiar de rol limpia la caché y vuelve a la selección', () async {
    store.roles['u-123'] = UserRole.remitente;
    await start();
    await roles.change();
    expect(roles.needsChoice, isTrue);
    expect(store.roles.containsKey('u-123'), isFalse);
  });

  test('UserRole interpreta valores del servidor sin distinguir mayúsculas',
      () {
    expect(UserRole.parse(' Remitente '), UserRole.remitente);
    expect(UserRole.parse('VIAJERO'), UserRole.viajero);
    expect(UserRole.parse('admin'), isNull);
    expect(UserRole.parse(3), isNull);
  });
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lapticon/auth/auth_controller.dart';
import 'package:lapticon/auth/auth_service.dart';
import 'package:lapticon/main.dart';
import 'package:lapticon/roles/role_controller.dart';
import 'package:lapticon/roles/role_store.dart';
import 'package:lapticon/roles/user_role.dart';
import 'package:lapticon/utils/format.dart';
import 'fakes.dart';

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder fieldTap(String key) => find.descendant(
    of: find.byKey(ValueKey(key)), matching: find.byType(InkWell));

Future<void> pickPlace(
    WidgetTester tester, String key, String country, String city) async {
  await tapVisible(tester, fieldTap(key));
  await tapVisible(tester, find.text(country));
  await tapVisible(tester, find.text(city));
}

const selectionTitle = '¿Cómo quieres\nusar Lapticon?';
const senderTitle = '¿Qué quieres\nenviar hoy?';
const travelerTitle = '¿A dónde\nviajas?';

void main() {
  late FakeAuthService auth;
  late FakeUserRepository users;
  late FakeShipmentRepository shipments;
  late MemoryRoleStore store;
  late AuthController controller;
  late RoleController roles;
  var started = false;

  setUp(() {
    auth = FakeAuthService(user: testUser);
    users = FakeUserRepository()..stored = testProfile;
    shipments = FakeShipmentRepository();
    store = MemoryRoleStore();
  });
  tearDown(() async {
    // Solo se liberan los controladores que creó esta prueba.
    if (started) {
      roles.dispose();
      controller.dispose();
      started = false;
    }
    await auth.close();
  });

  Widget app() {
    controller = AuthController(auth, users);
    roles = RoleController(controller, store);
    started = true;
    return LapticonApp(
        controller: controller,
        roles: roles,
        shipments: shipments,
        initialRoute: '/home');
  }

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
  }

  testWidgets('Sin rol elige remitente, ve su menú y el aviso de sincronización',
      (tester) async {
    await open(tester);
    expect(find.text(selectionTitle), findsOneWidget);
    expect(find.text('Hola, Ana Gómez.'), findsOneWidget);
    await tapVisible(tester, find.text('Envío paquetes'));
    expect(find.text(senderTitle), findsOneWidget);
    expect(find.text('Rol guardado en el teléfono'), findsOneWidget);
    expect(store.roles['u-123'], UserRole.remitente);
    expect(users.savedRoles, [UserRole.remitente]);
    await tapVisible(tester, find.byTooltip('Cerrar aviso'));
    expect(find.text('Rol guardado en el teléfono'), findsNothing);
  });

  testWidgets('Rol guardado abre directo su menú y se puede cambiar',
      (tester) async {
    store.roles['u-123'] = UserRole.viajero;
    await open(tester);
    expect(find.text(travelerTitle), findsOneWidget);
    expect(find.text('Mi viaje'), findsOneWidget);
    await tapVisible(tester, find.text('Cambiar de rol'));
    expect(find.text(selectionTitle), findsOneWidget);
    expect(store.roles.containsKey('u-123'), isFalse);
    await tapVisible(tester, find.text('Envío paquetes'));
    expect(find.text(senderTitle), findsOneWidget);
  });

  testWidgets('Cerrar sesión desde el menú vuelve al login', (tester) async {
    store.roles['u-123'] = UserRole.remitente;
    await open(tester);
    await tapVisible(tester, find.text('Cerrar sesión'));
    expect(find.text('Qué bueno\nverte de nuevo.'), findsOneWidget);
    expect(find.text(senderTitle), findsNothing);
    expect(store.roles['u-123'], UserRole.remitente);
  });

  testWidgets('Crear encomienda valida, busca lugares y publica',
      (tester) async {
    store.roles['u-123'] = UserRole.remitente;
    await open(tester);
    await tapVisible(tester, find.text('Crear encomienda'));
    expect(find.text('Publica tu\nencomienda.'), findsOneWidget);

    await tapVisible(tester, find.text('Publicar encomienda'));
    expect(find.text('Elige la ciudad de origen.'), findsOneWidget);
    expect(find.text('Elige la ciudad de destino.'), findsOneWidget);
    expect(find.text('Describe qué envías y cualquier cuidado especial.'),
        findsOneWidget);
    expect(find.text('Escribe el valor que ofreces al viajero.'),
        findsOneWidget);
    expect(shipments.created, isEmpty);

    await pickPlace(tester, 'campo-origen', 'Colombia', 'Bogotá');
    expect(find.text('Bogotá, Colombia'), findsOneWidget);

    // Mismo origen y destino no se permite.
    await pickPlace(tester, 'campo-destino', 'Colombia', 'Bogotá');
    await tester.enterText(
        find.byKey(const ValueKey('campo-observaciones')), 'Dos libros');
    await tester.enterText(find.byKey(const ValueKey('campo-valor')), '50000');
    await tapVisible(tester, find.text('Publicar encomienda'));
    expect(find.text('El destino debe ser diferente del origen.'),
        findsOneWidget);
    expect(shipments.created, isEmpty);

    // La búsqueda ignora tildes y mayúsculas.
    await tapVisible(tester, fieldTap('campo-destino'));
    await tester.enterText(find.byType(TextField).last, 'espana');
    await tester.pumpAndSettle();
    expect(find.text('Colombia'), findsNothing);
    await tapVisible(tester, find.text('España'));
    await tapVisible(tester, find.text('Madrid'));
    expect(find.text('Madrid, España'), findsOneWidget);

    await tapVisible(tester, find.text('Publicar encomienda'));
    expect(find.text('Tu encomienda\nya está disponible.'), findsOneWidget);
    expect(find.text('Bogotá → Madrid'), findsOneWidget);
    expect(find.text('\$ 50.000 COP'), findsOneWidget);
    expect(find.text('Disponible'), findsOneWidget);
    expect(shipments.created.single.toJson(), {
      'ciudadOrigen': 'Bogotá',
      'ciudadDestino': 'Madrid',
      'observaciones': 'Dos libros',
      'moneda': 'COP',
      'valor': 50000,
    });

    await tapVisible(tester, find.text('Volver al menú'));
    expect(find.text(senderTitle), findsOneWidget);
  });

  testWidgets('Error de la API se muestra y se puede reintentar sin perder datos',
      (tester) async {
    store.roles['u-123'] = UserRole.remitente;
    shipments.createFailure =
        const AppFailure('Faltan campos obligatorios', code: 'api');
    await open(tester);
    await tapVisible(tester, find.text('Crear encomienda'));
    await pickPlace(tester, 'campo-origen', 'Colombia', 'Cali');
    await pickPlace(tester, 'campo-destino', 'España', 'Barcelona');
    await tester.enterText(
        find.byKey(const ValueKey('campo-observaciones')), 'Café');
    await tester.enterText(find.byKey(const ValueKey('campo-valor')), '1200');
    await tapVisible(tester, find.text('Publicar encomienda'));
    expect(find.text('No se publicó la encomienda'), findsOneWidget);
    expect(find.text('Faltan campos obligatorios'), findsOneWidget);
    shipments.createFailure = null;
    await tapVisible(tester, find.text('Publicar encomienda'));
    expect(find.text('Tu encomienda\nya está disponible.'), findsOneWidget);
    expect(shipments.created, hasLength(2));
    await tapVisible(tester, find.text('Crear otra encomienda'));
    expect(find.text('Publica tu\nencomienda.'), findsOneWidget);
    expect(find.text('Cali, Colombia'), findsNothing);
  });

  testWidgets('Mientras publica, el botón queda bloqueado', (tester) async {
    store.roles['u-123'] = UserRole.remitente;
    shipments.gate = Completer<void>();
    await open(tester);
    await tapVisible(tester, find.text('Crear encomienda'));
    await pickPlace(tester, 'campo-origen', 'Colombia', 'Cali');
    await pickPlace(tester, 'campo-destino', 'España', 'Madrid');
    await tester.enterText(
        find.byKey(const ValueKey('campo-observaciones')), 'Café');
    await tester.enterText(find.byKey(const ValueKey('campo-valor')), '1200');
    final button = find.widgetWithText(FilledButton, 'Publicar encomienda');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pump();
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.tap(button, warnIfMissed: false);
    await tester.pump();
    expect(shipments.created, hasLength(1));
    shipments.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Tu encomienda\nya está disponible.'), findsOneWidget);
  });

  testWidgets('Lista de lugares con error permite reintentar', (tester) async {
    store.roles['u-123'] = UserRole.remitente;
    shipments.placesFailure =
        const AppFailure('No se pudo conectar con la API.', code: 'network');
    await open(tester);
    await tapVisible(tester, find.text('Crear encomienda'));
    await tapVisible(tester, fieldTap('campo-origen'));
    expect(find.text('No se pudo conectar con la API.'), findsOneWidget);
    shipments.placesFailure = null;
    await tapVisible(tester, find.text('Reintentar'));
    expect(find.text('Colombia'), findsOneWidget);
  });

  test('Validación y formato del valor', () {
    expect(formatMoney(50000, 'COP'), '\$ 50.000 COP');
    expect(formatMoney(1234567, 'USD'), '\$ 1.234.567 USD');
    expect(formatMoney(900, 'EUR'), '\$ 900 EUR');
    expect(formatDate(DateTime(2026, 3, 7)), '07/03/2026');
  });

  for (final size in [const Size(320, 568), const Size(1280, 800)]) {
    testWidgets('Roles, menús y formulario sin desbordes al 200 % en $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!),
          home: app()));
      await tester.pumpAndSettle();
      expect(find.text(selectionTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tapVisible(tester, find.text('Viajo y llevo paquetes'));
      expect(find.text(travelerTitle), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tapVisible(tester, find.text('Cambiar de rol'));
      await tapVisible(tester, find.text('Envío paquetes'));
      expect(tester.takeException(), isNull);
      await tapVisible(tester, find.text('Crear encomienda'));
      await tapVisible(tester, find.text('Publicar encomienda'));
      expect(find.text('Elige la ciudad de origen.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tapVisible(tester, fieldTap('campo-origen'));
      expect(tester.takeException(), isNull);
    });
  }
}

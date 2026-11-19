import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lapticon/auth/auth_controller.dart';
import 'package:lapticon/auth/auth_service.dart';
import 'package:lapticon/data/flight_city.dart';
import 'package:lapticon/data/shipment_repository.dart';
import 'package:lapticon/main.dart';
import 'package:lapticon/roles/role_controller.dart';
import 'package:lapticon/roles/role_store.dart';
import 'package:lapticon/roles/user_role.dart';
import 'package:lapticon/screens/crear_encomienda_screen.dart';
import 'package:lapticon/screens/flight_search_screen.dart';
import 'package:lapticon/screens/login_screen.dart';
import 'package:lapticon/screens/mis_encomiendas_screen.dart';
import 'package:lapticon/screens/register_screen.dart';
import 'package:lapticon/screens/role_selection_screen.dart';
import 'package:lapticon/screens/welcome_screen.dart';
import 'fakes.dart';

const back = ValueKey('page-back');
Future<void> tap(WidgetTester t, Finder finder) async {
  await t.ensureVisible(finder);
  await t.pumpAndSettle();
  await t.tap(finder);
  await t.pumpAndSettle();
}

Future<void> place(
    WidgetTester t, String key, String country, String city) async {
  await tap(
      t,
      find.descendant(
          of: find.byKey(ValueKey(key)), matching: find.byType(InkWell)));
  await tap(t, find.text(country));
  await tap(t, find.text(city));
}

void main() {
  late FakeAuthService auth;
  late FakeUserRepository users;
  late FakeShipmentRepository shipments;
  late FakeTripRepository trips;
  late MemoryRoleStore store;
  AuthController? controller;
  RoleController? roles;
  setUp(() {
    users = FakeUserRepository()..stored = testProfile;
    shipments = FakeShipmentRepository();
    trips = FakeTripRepository();
    store = MemoryRoleStore();
  });
  tearDown(() async {
    roles?.dispose();
    controller?.dispose();
    await auth.close();
  });
  Future<void> open(WidgetTester t,
      {bool signedIn = false,
      UserRole? role,
      String route = '/',
      bool largeText = false}) async {
    auth = FakeAuthService(user: signedIn ? testUser : null);
    if (role != null) store.roles[testUser.uid] = role;
    controller = AuthController(auth, users);
    roles = RoleController(controller!, store);
    Widget app = LapticonApp(
        controller: controller,
        roles: roles,
        shipments: shipments,
        trips: trips,
        initialRoute: route);
    if (largeText) {
      app = MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: app);
    }
    await t.pumpWidget(app);
    await t.pumpAndSettle();
  }

  Future<void> fillParcel(WidgetTester t) async {
    await place(t, 'campo-origen', 'Colombia', 'Cali');
    await place(t, 'campo-destino', 'Estados Unidos', 'Miami');
    await t.enterText(
        find.byKey(const ValueKey('campo-observaciones')), 'Libros');
    await t.enterText(find.byKey(const ValueKey('campo-valor')), '15000');
  }

  testWidgets(
      'Bienvenida sin regreso; resto con barra fija y sin módulos excluidos',
      (t) async {
    await open(t);
    expect(find.byKey(back), findsNothing);
    expect(find.text('PROTOTIPO'), findsNothing);
    await tap(t, find.text('Crear una cuenta'));
    expect(find.byKey(back), findsOneWidget);
    expect(find.textContaining('Google'), findsNothing);
    final initial = t.getTopLeft(find.byKey(back));
    await t.ensureVisible(find.text('¿Ya tienes una cuenta?'));
    await t.pumpAndSettle();
    expect(t.getTopLeft(find.byKey(back)), initial);
    expect(t.getSize(find.byKey(back)).height, greaterThanOrEqualTo(48));
    await tap(t, find.byKey(back));
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });
  testWidgets(
      'Registro conserva datos si cancela descarte y los descarta al salir',
      (t) async {
    await open(t);
    await tap(t, find.text('Crear una cuenta'));
    await t.enterText(find.byType(TextFormField).first, 'Nicolás');
    await tap(t, find.byKey(back));
    expect(find.text('¿Descartar los cambios?'), findsOneWidget);
    await tap(t, find.text('Seguir editando'));
    expect(find.text('Nicolás'), findsOneWidget);
    await tap(t, find.byKey(back));
    await tap(t, find.text('Descartar cambios'));
    expect(find.byType(WelcomeScreen), findsOneWidget);
    await tap(t, find.text('Crear una cuenta'));
    expect(find.text('Nicolás'), findsNothing);
  });
  testWidgets('Regreso de Android usa la misma confirmación de datos',
      (t) async {
    await open(t);
    await tap(t, find.text('Crear una cuenta'));
    await t.enterText(find.byType(TextFormField).first, 'Ana');
    t.testTextInput.hide();
    await t.pumpAndSettle();
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.text('¿Descartar los cambios?'), findsOneWidget);
    await tap(t, find.text('Seguir editando'));
    expect(find.byType(RegisterScreen), findsOneWidget);
  });
  testWidgets('Android cierra primero el teclado antes de pedir descartar',
      (t) async {
    addTearDown(t.view.resetViewInsets);
    await open(t, route: '/register');
    await t.enterText(find.byType(TextFormField).first, 'Ana');
    t.view.viewInsets = FakeViewPadding(bottom: 240);
    await t.pumpAndSettle();
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(find.text('¿Descartar los cambios?'), findsNothing);
    t.view.resetViewInsets();
    await t.pumpAndSettle();
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.text('¿Descartar los cambios?'), findsOneWidget);
    await tap(t, find.text('Seguir editando'));
  });

  testWidgets(
      'Acceso cruzado preserva formulario anterior sin duplicar pantallas',
      (t) async {
    await open(t, route: '/login');
    await t.enterText(find.byType(TextFormField).first, 'ana@example.com');
    await tap(t, find.text('Crea una cuenta'));
    expect(find.byType(RegisterScreen), findsOneWidget);
    await tap(t, find.text('Inicia sesión'));
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('ana@example.com'), findsOneWidget);
    await tap(t, find.text('Crea una cuenta'));
    await tap(t, find.byKey(back));
    expect(find.byType(LoginScreen), findsOneWidget);
  });
  testWidgets(
      'Error de registro mantiene todos los datos para corregir y reintentar',
      (t) async {
    await open(t, route: '/register');
    auth.failure = const AppFailure('Cuenta existente');
    final fields = find.byType(TextFormField);
    for (var i = 0; i < 5; i++) {
      await t.enterText(fields.at(i),
          ['Ana', 'Gómez', 'ana@example.com', 'demo123', 'demo123'][i]);
    }
    await tap(t, find.widgetWithText(FilledButton, 'Crear cuenta'));
    expect(find.text('Cuenta existente'), findsOneWidget);
    expect(t.widget<TextField>(find.byType(TextField).at(3)).controller!.text,
        'demo123');
    expect(t.widget<TextField>(find.byType(TextField).at(4)).controller!.text,
        'demo123');
  });
  testWidgets('Registro en curso bloquea regreso visual y de Android',
      (t) async {
    await open(t, route: '/register');
    auth.gate = Completer<void>();
    for (var i = 0; i < 5; i++) {
      await t.enterText(find.byType(TextFormField).at(i),
          ['Ana', 'Gómez', 'ana@example.com', 'demo123', 'demo123'][i]);
    }
    await t.ensureVisible(find.widgetWithText(FilledButton, 'Crear cuenta'));
    await t.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
    await t.pump();
    expect(t.widget<TextButton>(find.byKey(back)).onPressed, isNull);
    await t.binding.handlePopRoute();
    await t.pump();
    expect(find.byType(RegisterScreen), findsOneWidget);
    auth.gate!.complete();
    await t.pumpAndSettle();
    expect(find.byType(RoleSelectionScreen), findsOneWidget);
  });
  testWidgets('Volver a roles no borra elección y cancelar conserva sesión',
      (t) async {
    await open(t, signedIn: true, role: UserRole.remitente);
    await tap(t, find.byKey(back));
    expect(find.byType(RoleSelectionScreen), findsOneWidget);
    expect(store.roles[testUser.uid], UserRole.remitente);
    expect(users.savedRoles, isEmpty);
    await tap(t, find.byKey(back));
    expect(find.text('Crear encomienda'), findsOneWidget);
    expect(auth.logoutCalls, 0);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byType(RoleSelectionScreen), findsOneWidget);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.text('Crear encomienda'), findsOneWidget);
  });
  testWidgets('Cambiar rol actualiza menú y una sola vuelta abre selección',
      (t) async {
    await open(t, signedIn: true, role: UserRole.remitente);
    await tap(t, find.byKey(back));
    await tap(t, find.text('Viajo y llevo paquetes'));
    expect(find.text('Mi viaje'), findsOneWidget);
    expect(find.byType(RoleSelectionScreen), findsNothing);
    expect(store.roles[testUser.uid], UserRole.viajero);
    await tap(t, find.byKey(back));
    await tap(t, find.text('Envío paquetes'));
    expect(find.text('Crear encomienda'), findsOneWidget);
    expect(auth.logoutCalls, 0);
  });
  testWidgets('Selección inicial confirma cierre para volver al acceso',
      (t) async {
    await open(t, signedIn: true);
    await tap(t, find.byKey(back));
    expect(find.text('¿Volver al acceso?'), findsOneWidget);
    await tap(t, find.text('Quedarme aquí'));
    expect(auth.logoutCalls, 0);
    await tap(t, find.byKey(back));
    await tap(t, find.text('Cerrar sesión y volver'));
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(auth.logoutCalls, 1);
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });
  testWidgets('Encomienda publicada desde lista vuelve realmente al menú',
      (t) async {
    await open(t, signedIn: true, role: UserRole.remitente);
    await tap(t, find.text('Mis encomiendas'));
    await tap(t, find.text('Nueva'));
    await fillParcel(t);
    await tap(t, find.text('Publicar encomienda'));
    await tap(t, find.text('Volver al menú'));
    expect(find.text('Crear encomienda'), findsOneWidget);
    expect(find.byType(MisEncomiendasScreen), findsNothing);
    expect(find.byType(CrearEncomiendaScreen), findsNothing);
    expect(auth.logoutCalls, 0);
  });
  testWidgets('Encomienda fallida y selector cancelado conservan borrador',
      (t) async {
    await open(t, signedIn: true, role: UserRole.remitente);
    await tap(t, find.text('Crear encomienda'));
    await fillParcel(t);
    shipments.createFailure = const AppFailure('Sin red');
    await tap(t, find.text('Publicar encomienda'));
    expect(find.text('Libros'), findsOneWidget);
    await tap(
        t,
        find.descendant(
            of: find.byKey(const ValueKey('campo-origen')),
            matching: find.byType(InkWell)));
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    await tap(t, find.byKey(back));
    await tap(t, find.text('Seguir editando'));
    expect(find.text('Libros'), findsOneWidget);
    expect(find.text('15000'), findsOneWidget);
  });
  testWidgets('Escritura de entrega bloquea regreso sin romper la lista',
      (t) async {
    shipments.mineItems = [
      const Shipment(
          id: 'e1',
          origin: 'Bogotá',
          destination: 'Miami',
          notes: 'Prueba',
          currency: 'COP',
          value: 100,
          status: ShipmentStatus.tomada,
          ownerId: 'u-123',
          travelerId: 'v1')
    ];
    await open(t, signedIn: true, role: UserRole.remitente);
    await tap(t, find.text('Mis encomiendas'));
    shipments.deliveryGate = Completer<void>();
    await tap(t, find.text('Marcar entrega'));
    await t.tap(find.text('Sí, marcar entrega'));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
    expect(t.widget<TextButton>(find.byKey(back)).onPressed, isNull);
    await t.binding.handlePopRoute();
    await t.pump();
    expect(find.byType(MisEncomiendasScreen), findsOneWidget);
    shipments.deliveryGate!.complete();
    await t.pumpAndSettle();
    expect(find.text('Calificar viajero'), findsOneWidget);
    expect(find.text('Abrir chat'), findsNothing);
  });
  testWidgets('Registrar viaje desde búsqueda conserva un regreso a búsqueda',
      (t) async {
    await open(t, signedIn: true, role: UserRole.viajero);
    await tap(t, find.text('Buscar encomiendas'));
    await tap(t, find.text('Registrar mi viaje'));
    expect(find.byType(FlightSearchScreen), findsOneWidget);
    await tap(t, find.byKey(back));
    expect(find.text('Registrar mi viaje'), findsOneWidget);
    await tap(t, find.byKey(back));
    expect(find.text('Mi viaje'), findsOneWidget);
  });
  testWidgets(
      'Vuelo por ruta conserva ciudades tras error y pide confirmar descarte',
      (t) async {
    await open(t, signedIn: true, role: UserRole.viajero);
    await tap(t, find.text('Mi viaje'));
    for (final field in [
      ('vuelo-origen', 'Bogotá'),
      ('vuelo-destino', 'Miami')
    ]) {
      await tap(
          t,
          find.descendant(
              of: find.byKey(ValueKey(field.$1)),
              matching: find.byType(DropdownButton<FlightCity>)));
      await tap(t, find.text(field.$2).last);
    }
    trips.catalogFailure = const AppFailure('Sin conexión');
    await tap(t, find.text('Buscar vuelos'));
    expect(find.text('Bogotá'), findsOneWidget);
    expect(find.text('Miami'), findsOneWidget);
    await tap(t, find.byKey(back));
    await tap(t, find.text('Seguir editando'));
    expect(find.byType(FlightSearchScreen), findsOneWidget);
  });
  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets('Regreso visible con teclado y texto 200% en $size', (t) async {
      t.view.physicalSize = size;
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetViewInsets);
      await open(t, route: '/register', largeText: true);
      await t.enterText(find.byType(TextFormField).last, 'demo123');
      t.view.viewInsets = FakeViewPadding(bottom: 240);
      await t.pumpAndSettle();
      expect(t.getRect(find.byKey(back)).top, lessThan(90));
      expect(t.getRect(find.byKey(back)).bottom, lessThan(size.height - 240));
      expect(t.takeException(), isNull);
    });
  }
}

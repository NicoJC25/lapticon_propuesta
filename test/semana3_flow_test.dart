import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lapticon/auth/auth_controller.dart';
import 'package:lapticon/auth/auth_service.dart';
import 'package:lapticon/data/shipment_repository.dart';
import 'package:lapticon/data/trip_repository.dart';
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

/// Abre el calendario y acepta la fecha propuesta (hoy).
Future<void> pickToday(WidgetTester tester) async {
  await tapVisible(tester, fieldTap('campo-fecha-viaje'));
  await tapVisible(
      tester,
      find
          .descendant(of: find.byType(Dialog), matching: find.byType(TextButton))
          .last);
}

void main() {
  late FakeAuthService auth;
  late FakeUserRepository users;
  late FakeShipmentRepository shipments;
  late FakeTripRepository trips;
  late MemoryRoleStore store;
  late AuthController controller;
  late RoleController roles;
  var started = false;

  setUp(() {
    auth = FakeAuthService(user: testUser);
    users = FakeUserRepository()..stored = testProfile;
    shipments = FakeShipmentRepository();
    trips = FakeTripRepository();
    store = MemoryRoleStore();
  });
  tearDown(() async {
    if (started) {
      roles.dispose();
      controller.dispose();
      started = false;
    }
    await auth.close();
  });

  Widget app(UserRole role) {
    store.roles['u-123'] = role;
    controller = AuthController(auth, users);
    roles = RoleController(controller, store);
    started = true;
    return LapticonApp(
        controller: controller,
        roles: roles,
        shipments: shipments,
        trips: trips,
        initialRoute: '/home');
  }

  Future<void> open(WidgetTester tester, UserRole role) async {
    await tester.pumpWidget(app(role));
    await tester.pumpAndSettle();
  }

  group('Remitente · Mis encomiendas', () {
    testWidgets('Agrupa por estado y filtra', (tester) async {
      shipments.mineItems = [
        shipment('e1', destination: 'Madrid'),
        shipment('e2', destination: 'Lima', status: ShipmentStatus.tomada),
        shipment('e3', destination: 'Quito', status: ShipmentStatus.vencida),
        shipment('e4', destination: 'Cali', status: ShipmentStatus.disponible),
      ];
      await open(tester, UserRole.remitente);
      await tapVisible(tester, find.text('Mis encomiendas'));
      expect(find.text('Sigue tus\nencomiendas.'), findsOneWidget);
      expect(find.text('Disponibles · 2'), findsOneWidget);
      expect(find.text('Tomadas · 1'), findsOneWidget);
      expect(find.text('Vencidas · 1'), findsOneWidget);
      expect(find.text('Recibidas · 0'), findsNothing);
      expect(find.text('Bogotá → Lima'), findsOneWidget);

      await tapVisible(tester, find.text('Tomadas (1)'));
      expect(find.text('Bogotá → Lima'), findsOneWidget);
      expect(find.text('Bogotá → Madrid'), findsNothing);

      await tapVisible(tester, find.text('Recibidas (0)'));
      expect(find.text('No tienes encomiendas recibidas.'), findsOneWidget);
    });

    testWidgets('Sin encomiendas invita a crear; error permite reintentar',
        (tester) async {
      shipments.listFailure =
          const AppFailure('No se pudo conectar con la API.', code: 'network');
      await open(tester, UserRole.remitente);
      await tapVisible(tester, find.text('Mis encomiendas'));
      expect(find.text('No se pudo conectar con la API.'), findsOneWidget);
      shipments.listFailure = null;
      await tapVisible(tester, find.text('Actualizar'));
      expect(find.textContaining('Todavía no has publicado'), findsOneWidget);
      await tapVisible(tester, find.text('Nueva'));
      expect(find.text('Publica tu\nencomienda.'), findsOneWidget);
    });
  });

  group('Viajero · Mi viaje', () {
    Future<void> fillTrip(WidgetTester tester) async {
      await tester.enterText(find.byKey(const ValueKey('campo-vuelo')), 'av 9361');
      await pickToday(tester);
      await pickPlace(tester, 'campo-origen', 'Colombia', 'Bogotá');
      await pickPlace(tester, 'campo-destino', 'España', 'Madrid');
    }

    testWidgets('Valida campos, comprueba el vuelo y registra', (tester) async {
      await open(tester, UserRole.viajero);
      await tapVisible(tester, find.text('Mi viaje'));
      expect(find.text('Registra\ntu viaje.'), findsOneWidget);

      await tapVisible(tester, find.text('Validar vuelo y registrar'));
      expect(find.text('Escribe el número de vuelo.'), findsOneWidget);
      expect(find.text('Elige la fecha del vuelo.'), findsOneWidget);
      expect(find.text('Elige la ciudad de origen.'), findsOneWidget);
      expect(find.text('Elige la ciudad de destino.'), findsOneWidget);

      await tester.enterText(
          find.byKey(const ValueKey('campo-vuelo')), 'AVIANCA');
      await tapVisible(tester, find.text('Validar vuelo y registrar'));
      expect(find.text('Usa el código de la aerolínea y el número, como AV9361.'),
          findsOneWidget);
      expect(trips.checks, isEmpty);

      await fillTrip(tester);
      await tapVisible(tester, find.text('Validar vuelo y registrar'));
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      expect(trips.checks.single.$2, today);
      expect(trips.registered.single.toJson(), {
        'numeroVuelo': 'AV9361',
        'ciudadOrigen': 'Bogotá',
        'ciudadDestino': 'Madrid',
        'fechaViaje': isoDate(today),
      });
      expect(find.text('Tu viaje\nestá activo.'), findsOneWidget);
      expect(find.text('AV9361'), findsOneWidget);
      expect(find.text('Vuelo validado: Avianca · Bogotá → Madrid.'),
          findsOneWidget);
    });

    testWidgets('Vuelo inexistente bloquea el registro', (tester) async {
      trips.check = const FlightCheck(FlightCheckResult.notFound);
      await open(tester, UserRole.viajero);
      await tapVisible(tester, find.text('Mi viaje'));
      await fillTrip(tester);
      await tapVisible(tester, find.text('Validar vuelo y registrar'));
      expect(find.textContaining('No encontramos el vuelo AV9361'),
          findsOneWidget);
      expect(trips.registered, isEmpty);
    });

    testWidgets('Sin servicio de vuelos permite registrar sin validar',
        (tester) async {
      trips.check = const FlightCheck(FlightCheckResult.unavailable,
          message: 'La API no está disponible.');
      await open(tester, UserRole.viajero);
      await tapVisible(tester, find.text('Mi viaje'));
      await fillTrip(tester);
      await tapVisible(tester, find.text('Validar vuelo y registrar'));
      expect(find.text('No se pudo validar el vuelo'), findsOneWidget);
      expect(trips.registered, isEmpty);
      await tapVisible(tester, find.text('Registrar sin validar'));
      expect(trips.registered, hasLength(1));
      expect(find.text('Tu viaje\nestá activo.'), findsOneWidget);
      expect(find.textContaining('sin validar el vuelo'), findsOneWidget);
    });

    testWidgets('El 400 de viaje existente se muestra', (tester) async {
      trips.registerFailure = const AppFailure(
          'Ya existe un viaje disponible para este usuario',
          code: 'api');
      await open(tester, UserRole.viajero);
      await tapVisible(tester, find.text('Mi viaje'));
      await fillTrip(tester);
      await tapVisible(tester, find.text('Validar vuelo y registrar'));
      expect(find.text('Ya existe un viaje disponible para este usuario'),
          findsOneWidget);
      expect(find.text('Registra\ntu viaje.'), findsOneWidget);
    });

    testWidgets('Viaje activo se muestra y se puede cancelar', (tester) async {
      trips.activeTrip = Trip(
          id: 'v-9',
          flightNumber: 'LA2425',
          origin: 'Bogotá',
          destination: 'Lima',
          date: DateTime.utc(2026, 11, 7),
          status: TripStatus.disponible);
      await open(tester, UserRole.viajero);
      await tapVisible(tester, find.text('Mi viaje'));
      expect(find.text('LA2425'), findsOneWidget);
      // Medianoche UTC se muestra como el 7, no como el 6 de Bogotá.
      expect(find.text('07/11/2026'), findsOneWidget);
      await tapVisible(tester, find.text('Cancelar viaje'));
      expect(find.text('¿Cancelar tu viaje?'), findsOneWidget);
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Cancelar viaje'));
      expect(trips.cancelled, ['v-9']);
      expect(find.text('Registra\ntu viaje.'), findsOneWidget);
      expect(find.text('Cancelaste tu viaje. Puedes registrar otro.'),
          findsOneWidget);
    });
  });

  group('Viajero · Buscar y tomar', () {
    void withTrip() => trips.activeTrip = Trip(
        id: 'v-1',
        flightNumber: 'AV9361',
        origin: 'Bogotá',
        destination: 'Madrid',
        date: DateTime.utc(2026, 11, 7),
        status: TripStatus.disponible);

    testWidgets('Sin viaje pide registrarlo primero', (tester) async {
      await open(tester, UserRole.viajero);
      await tapVisible(tester, find.text('Buscar encomiendas'));
      expect(find.textContaining('Primero registra tu viaje'), findsOneWidget);
      expect(shipments.searches, isEmpty);
      await tapVisible(tester, find.text('Registrar mi viaje'));
      expect(find.text('Registra\ntu viaje.'), findsOneWidget);
    });

    testWidgets('Busca por la ruta del viaje y toma una encomienda',
        (tester) async {
      withTrip();
      shipments.available = [shipment('e1'), shipment('e2', notes: 'Café')];
      await open(tester, UserRole.viajero);
      await tapVisible(tester, find.text('Buscar encomiendas'));
      expect(shipments.searches.single, ('Bogotá', 'Madrid'));
      expect(find.text('DISPONIBLES · 2'), findsOneWidget);
      expect(find.text('Café'), findsOneWidget);

      await tapVisible(tester, find.byKey(const ValueKey('tomar-e2')));
      expect(find.text('¿Tomar esta encomienda?'), findsOneWidget);
      await tapVisible(tester, find.text('Sí, tomarla'));
      expect(shipments.takes, ['e2']);
      expect(find.text('Encomienda tomada'), findsOneWidget);
      expect(find.text('DISPONIBLES · 1'), findsOneWidget);
      expect(find.text('YA LAS TOMASTE · 1'), findsOneWidget);
    });

    testWidgets('Si ya la tomó otro, explica y recarga', (tester) async {
      withTrip();
      shipments.available = [shipment('e1')];
      shipments.takeFailure =
          const AppFailure('Ya fue tomada o venció', code: 'api');
      await open(tester, UserRole.viajero);
      await tapVisible(tester, find.text('Buscar encomiendas'));
      await tapVisible(tester, find.byKey(const ValueKey('tomar-e1')));
      await tapVisible(tester, find.text('Sí, tomarla'));
      expect(find.text('Ya fue tomada o venció'), findsOneWidget);
      expect(shipments.searches, hasLength(2));
    });

    testWidgets('Desde Mi viaje se abre la búsqueda de la ruta',
        (tester) async {
      withTrip();
      await open(tester, UserRole.viajero);
      await tapVisible(tester, find.text('Mi viaje'));
      await tapVisible(tester, find.text('Buscar encomiendas de mi ruta'));
      expect(find.text('Encomiendas\nde tu ruta.'), findsOneWidget);
      expect(find.textContaining('No hay encomiendas disponibles'),
          findsOneWidget);
    });
  });

  for (final size in [const Size(320, 568), const Size(1280, 800)]) {
    testWidgets('Pantallas de la semana 3 sin desbordes al 200 % en $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      withTripAndItems() {
        trips.activeTrip = Trip(
            id: 'v-1',
            flightNumber: 'AV9361',
            origin: 'Bogotá',
            destination: 'Madrid',
            date: DateTime.utc(2026, 11, 7),
            status: TripStatus.disponible);
        shipments.available = [shipment('e1')];
        shipments.mineItems = [
          shipment('e2', status: ShipmentStatus.tomada),
          shipment('e3', status: ShipmentStatus.vencida)
        ];
      }

      withTripAndItems();
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!),
          home: app(UserRole.viajero)));
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Mi viaje'));
      expect(tester.takeException(), isNull);
      await tapVisible(tester, find.text('Buscar encomiendas de mi ruta'));
      expect(tester.takeException(), isNull);
      await tapVisible(tester, find.byKey(const ValueKey('tomar-e1')));
      expect(tester.takeException(), isNull);
      await tapVisible(
          tester,
          find.descendant(
              of: find.byType(AlertDialog), matching: find.text('Volver')));
      expect(tester.takeException(), isNull);
    });
  }
}

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lapticon/auth/auth_controller.dart';
import 'package:lapticon/auth/auth_service.dart';
import 'package:lapticon/data/shipment_repository.dart';
import 'package:lapticon/data/trip_repository.dart';
import 'package:lapticon/main.dart';
import 'package:lapticon/roles/role_controller.dart';
import 'package:lapticon/roles/role_store.dart';
import 'package:lapticon/roles/user_role.dart';
import 'package:lapticon/widgets/delivery_action.dart';
import 'fakes.dart';

Shipment parcel(String id,
        {String owner = 'sender',
        String traveler = 'u-123',
        ShipmentStatus status = ShipmentStatus.tomada}) =>
    Shipment(
        id: id,
        origin: 'Bogotá',
        destination: 'Miami',
        notes: 'Paquete de prueba',
        currency: 'COP',
        value: 50000,
        status: status,
        ownerId: owner,
        travelerId: traveler);
Trip historyTrip(String id) => Trip(
    id: id,
    flightNumber: 'AV40',
    origin: 'Bogotá',
    destination: 'Miami',
    date: DateTime(2026, 1, 1),
    status: TripStatus.completado);

class HistoryOnlyTrips extends FakeTripRepository {
  @override
  Future<Trip?> active() =>
      throw StateError('Las entregas no requieren viaje activo');
}

class RefreshFailingShipments extends FakeShipmentRepository {
  @override
  Future<void> markDelivered(String id) async {
    await super.markDelivered(id);
    listFailure =
        const AppFailure('No se pudo actualizar la lista.', code: 'network');
  }
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder confirmDelivery() => find.descendant(
    of: find.byType(AlertDialog), matching: find.text('Sí, marcar entrega'));
void main() {
  group('Contrato de entrega', () {
    late FakeAuthService auth;
    setUp(() => auth = FakeAuthService(user: testUser));
    tearDown(() async => auth.close());
    test('PUT autenticado solo envía recibida y conserva el identificador',
        () async {
      final repo = ApiShipmentRepository(auth, client: MockClient((r) async {
        expect(r.method, 'PUT');
        expect(r.url.path, '/api/encomiendas/e-1/estado');
        expect(r.headers['Authorization'], 'Bearer initial-test-token');
        expect(jsonDecode(r.body), {'estado': 'recibida'});
        return http.Response('{}', 200);
      }));
      await repo.markDelivered('e-1');
      repo.close();
    });
    test('Permisos rechazados y error del servidor se comunican', () async {
      for (final status in [403, 500]) {
        final repo = ApiShipmentRepository(auth,
            client: MockClient((_) async => http.Response('{}', status)));
        await expectLater(
            repo.markDelivered('e-1'),
            throwsA(isA<AppFailure>().having((e) => e.code, 'code',
                status == 403 ? 'forbidden' : 'server')));
        repo.close();
      }
    });
    test('401 renueva una sola vez y cierra una sesión rechazada', () async {
      var calls = 0;
      final repo = ApiShipmentRepository(auth, client: MockClient((_) async {
        calls++;
        return http.Response('{}', 401);
      }));
      await expectLater(repo.markDelivered('e-1'), throwsA(isA<AppFailure>()));
      expect(calls, 2);
      expect(auth.tokenRequests, [false, true]);
      expect(auth.logoutCalls, 1);
      repo.close();
    });
    test('Identificador vacío no envía solicitudes', () async {
      final repo = ApiShipmentRepository(auth,
          client: MockClient((_) async => throw StateError('No debe enviar')));
      await expectLater(repo.markDelivered(' '), throwsA(isA<AppFailure>()));
      repo.close();
    });
    test('Solo los participantes de una encomienda tomada tienen la acción',
        () {
      expect(canMarkDelivered(parcel('e'), 'u-123'), isTrue);
      expect(canMarkDelivered(parcel('e'), 'sender'), isTrue);
      expect(canMarkDelivered(parcel('e'), 'otro'), isFalse);
      expect(canMarkDelivered(parcel('e'), null), isFalse);
      for (final state
          in ShipmentStatus.values.where((s) => s != ShipmentStatus.tomada)) {
        expect(canMarkDelivered(parcel('e', status: state), 'u-123'), isFalse);
      }
    });
  });

  group('Pantallas de entrega', () {
    late FakeAuthService auth;
    late FakeShipmentRepository shipments;
    late HistoryOnlyTrips trips;
    late AuthController controller;
    late RoleController roles;
    setUp(() {
      auth = FakeAuthService(user: testUser);
      shipments = FakeShipmentRepository();
      trips = HistoryOnlyTrips();
      trips.history = [historyTrip('v1'), historyTrip('v2')];
      shipments.taken = [parcel('e-1')];
      controller =
          AuthController(auth, FakeUserRepository()..stored = testProfile);
    });
    tearDown(() async {
      roles.dispose();
      controller.dispose();
      await auth.close();
    });
    Future<void> open(WidgetTester tester,
        {UserRole role = UserRole.viajero, bool largeText = false}) async {
      final store = MemoryRoleStore()..roles[testUser.uid] = role;
      roles = RoleController(controller, store);
      final app = LapticonApp(
          controller: controller,
          roles: roles,
          shipments: shipments,
          trips: trips);
      await tester.pumpWidget(largeText
          ? MediaQuery(
              data: const MediaQueryData(
                  textScaler: TextScaler.linear(2),
                  viewInsets: EdgeInsets.only(bottom: 260)),
              child: app)
          : app);
      await tester.pumpAndSettle();
      await tap(
          tester,
          find.text(
              role == UserRole.viajero ? 'Mis entregas' : 'Mis encomiendas'));
    }

    testWidgets(
        'Viajes terminados, rutas únicas y solo encomiendas asignadas pendientes',
        (tester) async {
      shipments.taken = [
        parcel('e-1'),
        parcel('other', traveler: 'otro'),
        parcel('done', status: ShipmentStatus.recibida),
        parcel('available', status: ShipmentStatus.disponible)
      ];
      await open(tester);
      expect(shipments.searches, [('Bogotá', 'Miami')]);
      expect(find.byKey(const ValueKey('entregar-e-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('entregar-other')), findsNothing);
      expect(find.byKey(const ValueKey('entregar-done')), findsNothing);
    });
    testWidgets('Cancelar no envía el cambio', (tester) async {
      await open(tester);
      await tap(tester, find.byKey(const ValueKey('entregar-e-1')));
      await tap(
          tester,
          find.descendant(
              of: find.byType(AlertDialog), matching: find.text('Volver')));
      expect(shipments.deliveries, isEmpty);
      expect(shipments.taken.single.status, ShipmentStatus.tomada);
    });
    testWidgets(
        'Confirmar entrega actualiza la lista tras aceptación de la API',
        (tester) async {
      await open(tester);
      await tap(tester, find.byKey(const ValueKey('entregar-e-1')));
      await tap(tester, confirmDelivery());
      expect(shipments.deliveries, ['e-1']);
      expect(shipments.searches, hasLength(2));
      expect(find.byKey(const ValueKey('entregar-e-1')), findsNothing);
      expect(find.text('Entrega marcada como recibida.'), findsOneWidget);
      expect(find.textContaining('No tienes encomiendas pendientes'),
          findsOneWidget);
    });
    testWidgets('Fallo de permisos conserva la encomienda y permite reintentar',
        (tester) async {
      shipments.deliveryFailure =
          const AppFailure('No tienes permiso.', code: 'forbidden');
      await open(tester);
      await tap(tester, find.byKey(const ValueKey('entregar-e-1')));
      await tap(tester, confirmDelivery());
      expect(find.text('No tienes permiso.'), findsOneWidget);
      expect(shipments.taken.single.status, ShipmentStatus.tomada);
      shipments.deliveryFailure = null;
      await tap(tester, find.byKey(const ValueKey('entregar-e-1')));
      await tap(tester, confirmDelivery());
      expect(shipments.deliveries, ['e-1', 'e-1']);
      expect(shipments.taken, isEmpty);
    });
    testWidgets('No admite envíos duplicados mientras espera respuesta',
        (tester) async {
      shipments.deliveryGate = Completer<void>();
      await open(tester);
      await tap(tester, find.byKey(const ValueKey('entregar-e-1')));
      await tester.ensureVisible(confirmDelivery());
      await tester.tap(confirmDelivery());
      await tester.pump(const Duration(milliseconds: 400));
      expect(
          tester
              .widget<FilledButton>(find.byKey(const ValueKey('entregar-e-1')))
              .onPressed,
          isNull);
      expect(shipments.deliveries, ['e-1']);
      shipments.deliveryGate!.complete();
      await tester.pumpAndSettle();
      expect(shipments.deliveries, ['e-1']);
    });
    testWidgets('Remitente marca su encomienda y la ve como recibida',
        (tester) async {
      shipments.mineItems = [
        parcel('own', owner: testUser.uid, traveler: 'otro')
      ];
      await open(tester, role: UserRole.remitente);
      await tap(tester, find.byKey(const ValueKey('entregar-own')));
      await tap(tester, confirmDelivery());
      expect(shipments.mineItems.single.status, ShipmentStatus.recibida);
      expect(find.text('Recibidas (1)'), findsOneWidget);
      expect(find.byKey(const ValueKey('entregar-own')), findsNothing);
    });
    testWidgets('Entrega aceptada no se reenvía si falla la recarga',
        (tester) async {
      shipments = RefreshFailingShipments()..taken = [parcel('e-1')];
      await open(tester);
      await tap(tester, find.byKey(const ValueKey('entregar-e-1')));
      await tap(tester, confirmDelivery());
      expect(find.text('No se pudo actualizar la lista.'), findsOneWidget);
      expect(find.text('Entrega registrada'), findsOneWidget);
      expect(
          tester
              .widget<FilledButton>(find.byKey(const ValueKey('entregar-e-1')))
              .onPressed,
          isNull);
      expect(shipments.deliveries, ['e-1']);
    });
    testWidgets('Error de listado permite actualizar sin declarar lista vacía',
        (tester) async {
      shipments.listFailure =
          const AppFailure('Sin conexión.', code: 'network');
      await open(tester);
      expect(find.text('Sin conexión.'), findsOneWidget);
      expect(find.textContaining('No tienes encomiendas pendientes'),
          findsNothing);
      shipments.listFailure = null;
      await tap(tester, find.text('Actualizar'));
      expect(find.byKey(const ValueKey('entregar-e-1')), findsOneWidget);
    });
    for (final size in [const Size(320, 568), const Size(430, 932)]) {
      testWidgets('Texto ampliado y confirmación desplazable en $size',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await open(tester, largeText: true);
        expect(
            MediaQuery.textScalerOf(
                    tester.element(find.byKey(const ValueKey('entregar-e-1'))))
                .scale(10),
            20);
        await tap(tester, find.byKey(const ValueKey('entregar-e-1')));
        await tap(tester, confirmDelivery());
        expect(shipments.deliveries, ['e-1']);
        expect(tester.takeException(), isNull);
      });
    }
  });
}

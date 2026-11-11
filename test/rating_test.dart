import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lapticon/auth/auth_controller.dart';
import 'package:lapticon/auth/auth_service.dart';
import 'package:lapticon/data/delivered_shipment_store.dart';
import 'package:lapticon/data/rating_repository.dart';
import 'package:lapticon/data/shipment_repository.dart';
import 'package:lapticon/data/trip_repository.dart';
import 'package:lapticon/main.dart';
import 'package:lapticon/roles/role_controller.dart';
import 'package:lapticon/roles/role_store.dart';
import 'package:lapticon/roles/user_role.dart';
import 'package:lapticon/screens/rating_form_screen.dart';
import 'fakes.dart';

Shipment shipment(
        {String id = 'e1',
        String owner = 'u-123',
        String traveler = 'traveler',
        ShipmentStatus state = ShipmentStatus.recibida}) =>
    Shipment(
        id: id,
        origin: 'Bogotá',
        destination: 'Miami',
        notes: 'Prueba',
        currency: 'COP',
        value: 10000,
        status: state,
        ownerId: owner,
        travelerId: traveler);
Map<String, Object> ratingJson(
        {String author = 'u-123',
        String target = 'traveler',
        String role = 'viajero',
        int score = 4}) =>
    {
      'usuarioOrigen': author,
      'usuarioDestino': target,
      'rolDestino': role,
      'calificacion': score,
      'comentario': 'Muy bien'
    };
http.Response listing([List<Map<String, Object>> items = const []]) =>
    http.Response(
        jsonEncode(
            {'total': items.length, 'promedio': 4, 'calificaciones': items}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'});

class FakeRatings implements RatingRepository {
  UserRating? saved;
  AppFailure? failure;
  AppFailure? checkFailure;
  Completer<void>? gate;
  int calls = 0;
  @override
  Future<UserRating?> existing(String author, RatingTarget target) async {
    if (checkFailure != null) throw checkFailure!;
    return saved;
  }

  @override
  Future<RatingReceipt> rate(
      AuthUser author, Shipment shipment, int score, String comment) async {
    calls++;
    if (gate != null) await gate!.future;
    if (failure != null) throw failure!;
    final target = RatingTarget.forShipment(shipment, author.uid)!;
    saved = UserRating(
        author: author.uid,
        target: target.uid,
        role: target.role,
        score: score,
        comment: comment);
    return RatingReceipt(saved!);
  }

  @override
  void close() {}
}

Future<void> tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

void main() {
  group('Contrato de calificaciones', () {
    late FakeAuthService auth;
    setUp(() => auth = FakeAuthService(user: testUser));
    tearDown(() async => auth.close());
    test('Destino automático, entrega recibida y participantes distintos', () {
      expect(RatingTarget.forShipment(shipment(), 'u-123')?.role,
          UserRole.viajero);
      expect(RatingTarget.forShipment(shipment(), 'traveler')?.role,
          UserRole.remitente);
      expect(RatingTarget.forShipment(shipment(), 'otro'), isNull);
      expect(RatingTarget.forShipment(shipment(traveler: 'u-123'), 'u-123'),
          isNull);
      expect(RatingTarget.forShipment(shipment(traveler: ''), 'u-123'), isNull);
      for (final state
          in ShipmentStatus.values.where((s) => s != ShipmentStatus.recibida)) {
        expect(
            RatingTarget.forShipment(shipment(state: state), 'u-123'), isNull);
      }
    });
    for (final asTraveler in [false, true]) {
      test('POST autenticado y rol ${asTraveler ? 'remitente' : 'viajero'}',
          () async {
        final s = asTraveler
            ? shipment(owner: 'sender', traveler: testUser.uid)
            : shipment();
        final target = asTraveler ? 'sender' : 'traveler';
        final role = asTraveler ? 'remitente' : 'viajero';
        var posts = 0;
        final repo = ApiRatingRepository(auth, client: MockClient((r) async {
          if (r.method == 'GET') {
            expect(r.url.path, '/api/ratings/$target');
            expect(r.headers.containsKey('Authorization'), isFalse);
            return listing();
          }
          posts++;
          expect(r.url.path, '/api/ratings');
          expect(r.headers['Authorization'], 'Bearer initial-test-token');
          expect(jsonDecode(r.body), {
            'usuarioDestino': target,
            'rolDestino': role,
            'calificacion': 4,
            'comentario': 'Muy bien'
          });
          return http.Response(
              jsonEncode(ratingJson(target: target, role: role)), 201);
        }));
        final result = await repo.rate(testUser, s, 4, '  Muy bien  ');
        expect(result.rating.target, target);
        expect(posts, 1);
        repo.close();
      });
    }
    test('Una calificación existente impide repetir el POST', () async {
      final repo = ApiRatingRepository(auth, client: MockClient((r) async {
        expect(r.method, 'GET');
        return listing([ratingJson()]);
      }));
      expect(
          (await repo.rate(testUser, shipment(), 5, '')).alreadyExists, isTrue);
      repo.close();
    });
    test('Respuesta perdida se reconcilia sin reenviar el POST', () async {
      var posted = false;
      final repo = ApiRatingRepository(auth, client: MockClient((r) async {
        if (r.method == 'GET') return listing(posted ? [ratingJson()] : []);
        posted = true;
        throw http.ClientException('lost');
      }));
      expect(
          (await repo.rate(testUser, shipment(), 4, 'Muy bien')).alreadyExists,
          isTrue);
      repo.close();
    });
    test('Dos formularios concurrentes comparten una sola petición', () async {
      final gate = Completer<http.Response>();
      var posts = 0;
      final repo = ApiRatingRepository(auth, client: MockClient((r) async {
        if (r.method == 'GET') return listing();
        posts++;
        return gate.future;
      }));
      final a = repo.rate(testUser, shipment(), 4, 'Muy bien');
      final b = repo.rate(testUser, shipment(), 4, 'Muy bien');
      await Future<void>.delayed(Duration.zero);
      expect(posts, 1);
      gate.complete(http.Response(jsonEncode(ratingJson()), 201));
      await Future.wait([a, b]);
      expect(posts, 1);
      repo.close();
    });
    test('Consulta fallida bloquea el POST y permite informar el error',
        () async {
      final repo = ApiRatingRepository(auth, client: MockClient((r) async {
        expect(r.method, 'GET');
        return http.Response('{}', 500);
      }));
      await expectLater(repo.rate(testUser, shipment(), 4, ''),
          throwsA(isA<AppFailure>().having((e) => e.code, 'code', 'server')));
      repo.close();
    });
    test('Datos inválidos o sesión cambiada no producen peticiones', () async {
      final repo = ApiRatingRepository(auth, client: MockClient((r) async {
        fail('No debe llamar la API');
      }));
      for (final score in [0, 6]) {
        await expectLater(repo.rate(testUser, shipment(), score, ''),
            throwsA(isA<AppFailure>()));
      }
      await expectLater(repo.rate(testUser, shipment(), 4, 'x' * 501),
          throwsA(isA<AppFailure>()));
      await expectLater(repo.rate(testUser, shipment(owner: 'other'), 4, ''),
          throwsA(isA<AppFailure>()));
      auth.user = null;
      await expectLater(
          repo.rate(testUser, shipment(), 4, ''),
          throwsA(isA<AppFailure>()
              .having((e) => e.code, 'code', 'session-changed')));
      repo.close();
    });
    test('Un 403 no reintenta ni anuncia éxito', () async {
      var posts = 0;
      final repo = ApiRatingRepository(auth, client: MockClient((r) async {
        if (r.method == 'GET') return listing();
        posts++;
        return http.Response('{}', 403);
      }));
      await expectLater(
          repo.rate(testUser, shipment(), 4, ''),
          throwsA(
              isA<AppFailure>().having((e) => e.code, 'code', 'forbidden')));
      expect(posts, 1);
      repo.close();
    });
    test('No confunde una calificación en el otro rol con una existente',
        () async {
      final repo = ApiRatingRepository(auth,
          client: MockClient(
              (r) async => listing([ratingJson(role: 'remitente')])));
      expect(
          await repo.existing(
              testUser.uid, const RatingTarget('traveler', UserRole.viajero)),
          isNull);
      repo.close();
    });
  });
  group('Historial local', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));
    test(
        'Persiste por cuenta, conserva escrituras concurrentes y no duplica IDs',
        () async {
      final store = SharedPreferencesDeliveredShipmentStore();
      await Future.wait([
        store.remember('u-123', shipment()),
        store.remember('u-123', shipment(id: 'e2'))
      ]);
      await store.remember('u-123', shipment());
      expect(
          (await SharedPreferencesDeliveredShipmentStore().read('u-123'))
              .map((s) => s.id),
          ['e1', 'e2']);
      expect(await store.read('otra'), isEmpty);
      await expectLater(
          store.remember('otra', shipment()), throwsA(isA<AppFailure>()));
      await expectLater(
          store.remember('u-123', shipment(state: ShipmentStatus.tomada)),
          throwsA(isA<AppFailure>()));
    });
    test('Historial corrupto informa fallo sin inventar entregas', () async {
      SharedPreferences.setMockInitialValues(
          {SharedPreferencesDeliveredShipmentStore.keyFor('u-123'): '{bad'});
      await expectLater(SharedPreferencesDeliveredShipmentStore().read('u-123'),
          throwsA(isA<AppFailure>()));
    });
  });
  group('Interfaz de calificaciones', () {
    late FakeAuthService auth;
    late AuthController controller;
    late RoleController roles;
    late FakeRatings ratings;
    late FakeShipmentRepository shipments;
    late MemoryDeliveredShipmentStore history;
    late FakeTripRepository trips;
    setUp(() {
      auth = FakeAuthService(user: testUser);
      controller =
          AuthController(auth, FakeUserRepository()..stored = testProfile);
      ratings = FakeRatings();
      shipments = FakeShipmentRepository()..mineItems = [shipment()];
      history = MemoryDeliveredShipmentStore();
      trips = FakeTripRepository();
    });
    tearDown(() async {
      roles.dispose();
      controller.dispose();
      await auth.close();
    });
    Future<void> open(WidgetTester t,
        {UserRole role = UserRole.remitente,
        bool largeText = false,
        String? menu}) async {
      roles = RoleController(
          controller, MemoryRoleStore()..roles[testUser.uid] = role);
      Widget app = LapticonApp(
          controller: controller,
          roles: roles,
          shipments: shipments,
          trips: trips,
          ratings: ratings,
          history: history);
      if (largeText) {
        app = MediaQuery(
            data: const MediaQueryData(
                textScaler: TextScaler.linear(2),
                viewInsets: EdgeInsets.only(bottom: 260)),
            child: app);
      }
      await t.pumpWidget(app);
      await t.pumpAndSettle();
      await tap(
          t,
          find.text(menu ??
              (role == UserRole.remitente
                  ? 'Calificar viajeros'
                  : 'Calificar remitentes')));
    }

    testWidgets(
        'Marcar entrega alimenta el historial y habilita calificar remitente',
        (t) async {
      shipments.taken = [
        shipment(
            owner: 'sender',
            traveler: testUser.uid,
            state: ShipmentStatus.tomada)
      ];
      trips.history = [
        Trip(
            id: 'v1',
            flightNumber: 'AV40',
            origin: 'Bogotá',
            destination: 'Miami',
            date: DateTime(2026, 11, 10),
            status: TripStatus.completado)
      ];
      await open(t, role: UserRole.viajero, menu: 'Mis entregas');
      await tap(t, find.text('Marcar entrega'));
      await tap(t, find.text('Sí, marcar entrega'));
      expect((await history.read(testUser.uid)).single.status,
          ShipmentStatus.recibida);
      await tap(t, find.text('Volver'));
      await tap(t, find.text('Calificar remitentes'));
      await tap(t, find.text('Calificar remitente'));
      expect(find.byType(RatingFormScreen), findsOneWidget);
    });
    testWidgets('Remitente elige estrellas, valida y guarda una sola vez',
        (t) async {
      await open(t);
      await tap(t, find.text('Calificar viajero'));
      await tap(t, find.text('Enviar calificación'));
      expect(find.text('Selecciona de 1 a 5 estrellas.'), findsOneWidget);
      expect(ratings.calls, 0);
      await tap(t, find.byKey(const ValueKey('rating-4')));
      await t.enterText(find.byType(TextField), 'Muy bien');
      await tap(t, find.text('Enviar calificación'));
      expect(ratings.calls, 1);
      expect(ratings.saved?.role, UserRole.viajero);
      expect(find.text('Calificación registrada'), findsOneWidget);
    });
    testWidgets(
        'Viajero usa entregas confirmadas locales para evaluar remitente',
        (t) async {
      await history.remember(
          testUser.uid, shipment(owner: 'sender', traveler: testUser.uid));
      await open(t, role: UserRole.viajero);
      await tap(t, find.text('Calificar remitente'));
      await tap(t, find.byKey(const ValueKey('rating-5')));
      await tap(t, find.text('Enviar calificación'));
      expect(ratings.saved?.target, 'sender');
      expect(ratings.saved?.role, UserRole.remitente);
    });
    testWidgets('Calificación previa se muestra sin permitir reenviar',
        (t) async {
      ratings.saved = const UserRating(
          author: 'u-123',
          target: 'traveler',
          role: UserRole.viajero,
          score: 4,
          comment: 'Bien');
      await open(t);
      await tap(t, find.text('Calificar viajero'));
      expect(find.text('Ya calificaste a este usuario como viajero.'),
          findsOneWidget);
      expect(find.text('Enviar calificación'), findsNothing);
      expect(ratings.calls, 0);
    });
    testWidgets('Fallo al consultar bloquea formulario hasta reintentar',
        (t) async {
      ratings.checkFailure = const AppFailure('Sin conexión', code: 'network');
      await open(t);
      await tap(t, find.text('Calificar viajero'));
      expect(find.text('Enviar calificación'), findsNothing);
      ratings.checkFailure = null;
      await tap(t, find.text('Volver a consultar'));
      expect(find.text('Enviar calificación'), findsOneWidget);
    });
    testWidgets('Error al enviar conserva comentario y permite reintento',
        (t) async {
      ratings.failure = const AppFailure('Sin conexión', code: 'network');
      await open(t);
      await tap(t, find.text('Calificar viajero'));
      await tap(t, find.byKey(const ValueKey('rating-3')));
      await t.enterText(find.byType(TextField), 'Opinión');
      await tap(t, find.text('Enviar calificación'));
      expect(find.text('Sin conexión'), findsOneWidget);
      expect(find.text('Opinión'), findsOneWidget);
      ratings.failure = null;
      await tap(t, find.text('Enviar calificación'));
      expect(ratings.calls, 2);
    });
    testWidgets('Petición en curso bloquea envíos duplicados', (t) async {
      ratings.gate = Completer<void>();
      await open(t);
      await tap(t, find.text('Calificar viajero'));
      await tap(t, find.byKey(const ValueKey('rating-4')));
      await t.ensureVisible(find.text('Enviar calificación'));
      await t.tap(find.text('Enviar calificación'));
      await t.pump();
      expect(
          t
              .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Enviando calificación…'))
              .onPressed,
          isNull);
      expect(ratings.calls, 1);
      ratings.gate!.complete();
      await t.pumpAndSettle();
    });
    testWidgets('No permite calificar entregas pendientes o ajenas', (t) async {
      shipments.mineItems = [
        shipment(state: ShipmentStatus.tomada),
        shipment(id: 'other', owner: 'other')
      ];
      await open(t);
      expect(find.text('Calificar viajero'), findsNothing);
      expect(find.text('Aún no tienes entregas recibidas para calificar.'),
          findsOneWidget);
    });
    for (final width in [320.0, 430.0]) {
      testWidgets('Formulario accesible ancho $width, texto 200% y teclado',
          (t) async {
        t.view.physicalSize = Size(width, 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        await open(t, largeText: true);
        await tap(t, find.text('Calificar viajero'));
        expect(find.byType(RatingFormScreen), findsOneWidget);
        await tap(t, find.byKey(const ValueKey('rating-4')));
        await t.ensureVisible(find.byType(TextField));
        await t.enterText(find.byType(TextField), 'Todo bien');
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
      });
    }
  });
}

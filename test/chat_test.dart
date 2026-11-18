import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lapticon/auth/auth_controller.dart';
import 'package:lapticon/auth/auth_service.dart';
import 'package:lapticon/chat/chat_controller.dart';
import 'package:lapticon/chat/chat_repository.dart';
import 'package:lapticon/chat/firestore_chat_transport.dart';
import 'package:lapticon/data/shipment_repository.dart';
import 'package:lapticon/main.dart';
import 'package:lapticon/roles/role_controller.dart';
import 'package:lapticon/roles/role_store.dart';
import 'package:lapticon/roles/user_role.dart';
import 'fakes.dart';
import 'package:lapticon/widgets/shipment_card.dart';

Shipment parcel(
        {String owner = 'u-123',
        String traveler = 'traveler',
        ShipmentStatus state = ShipmentStatus.tomada}) =>
    Shipment(
        id: 'e1',
        origin: 'Bogotá',
        destination: 'Miami',
        notes: 'Paquete',
        currency: 'COP',
        value: 10000,
        status: state,
        ownerId: owner,
        travelerId: traveler);
ChatConversation room() =>
    ChatConversation.forShipment(parcel(), testUser.uid)!;

class FakeTransport implements ChatTransport {
  final updates = StreamController<List<ChatMessage>>.broadcast(sync: true);
  bool enabled = true;
  int watches = 0, writes = 0;
  final ids = <String>[];
  AppFailure? failure;
  Completer<void>? gate;
  @override
  bool get configured => enabled;
  @override
  Stream<List<ChatMessage>> watch(ChatConversation chat) async* {
    watches++;
    yield [];
    yield* updates.stream;
  }

  @override
  Future<void> send(ChatConversation chat, String id, String text) async {
    writes++;
    ids.add(id);
    if (gate != null) await gate!.future;
    if (failure != null) throw failure!;
    updates.add([
      ChatMessage(
          id: id,
          author: chat.author,
          text: text,
          createdAt: DateTime(2026, 11, 10, 15))
    ]);
  }

  Future<void> close() => updates.close();
}

void main() {
  group('Contrato del chat', () {
    late FakeAuthService auth;
    late FakeTransport transport;
    setUp(() {
      auth = FakeAuthService(user: testUser);
      transport = FakeTransport();
    });
    tearDown(() async {
      await auth.close();
      await transport.close();
    });
    test('Ambas partes generan el mismo ID ordenado y solo ellas acceden', () {
      final s = parcel();
      expect(ChatConversation.forShipment(s, 'u-123')!.id,
          ChatConversation.forShipment(s, 'traveler')!.id);
      expect(room().id, 'traveler_u-123');
      expect(ChatConversation.forShipment(s, 'otro'), isNull);
      expect(
          ChatConversation.forShipment(parcel(traveler: ''), 'u-123'), isNull);
      expect(ChatConversation.forShipment(parcel(traveler: 'u-123'), 'u-123'),
          isNull);
      expect(ChatConversation.forShipment(parcel(owner: 'a/b'), 'a/b'), isNull);
      for (final state in [
        ShipmentStatus.disponible,
        ShipmentStatus.vencida,
        ShipmentStatus.desconocido
      ]) {
        expect(ChatConversation.forShipment(parcel(state: state), 'u-123'),
            isNull);
      }
      expect(
          ChatConversation.forShipment(
              parcel(state: ShipmentStatus.recibida), 'u-123'),
          isNotNull);
    });
    test('Consulta el endpoint real con token, sin POST de mensajes a la API',
        () async {
      final repo = ApiChatRepository(auth, transport: transport,
          client: MockClient((r) async {
        expect(r.method, 'GET');
        expect(r.url.path, '/api/chats/estado/traveler_u-123');
        expect(r.headers['Authorization'], 'Bearer initial-test-token');
        return http.Response('{"estado":"abierto","fechaCierre":null}', 200);
      }));
      expect((await repo.status(room())).state, ChatState.abierto);
      await repo.send(room(), newChatMessageId(), ' Hola ');
      expect(transport.writes, 1);
      repo.close();
    });
    test('Configuración pendiente no accede a mensajes ni envía', () async {
      final repo = ApiChatRepository(auth,
          client: MockClient(
              (_) async => http.Response('{"estado":"abierto"}', 200)));
      expect(repo.configured, isFalse);
      expect(configuredChatTransport().configured, isFalse);
      await expectLater(
          repo.watch(room()),
          emitsError(
              isA<AppFailure>().having((e) => e.code, 'code', 'chat-pending')));
      await expectLater(repo.send(room(), newChatMessageId(), 'Hola'),
          throwsA(isA<AppFailure>()));
      repo.close();
    });
    for (final response in [
      http.Response('{}', 404),
      http.Response('{}', 403),
      http.Response('{}', 500),
      http.Response('{"estado":"desconocido"}', 200),
      http.Response('bad json', 200),
      http.Response(
          '{"estado":"cerrado","fechaCierre":"2026-11-10T12:00:00Z"}', 200)
    ]) {
      test(
          'Estado no abierto bloquea escritura (${response.statusCode}, ${response.body})',
          () async {
        final repo = ApiChatRepository(auth,
            transport: transport, client: MockClient((_) async => response));
        await expectLater(repo.send(room(), newChatMessageId(), 'Hola'),
            throwsA(isA<AppFailure>()));
        expect(transport.writes, 0);
        repo.close();
      });
    }
    test('Sesión cambiada y datos inválidos no tocan red ni mensajes',
        () async {
      final repo = ApiChatRepository(auth, transport: transport,
          client: MockClient((_) async {
        fail('No debe llamar la API');
      }));
      for (final text in ['  ', 'x' * 1001]) {
        await expectLater(repo.send(room(), newChatMessageId(), text),
            throwsA(isA<AppFailure>()));
      }
      await expectLater(
          repo.send(room(), 'bad/id', 'Hola'), throwsA(isA<AppFailure>()));
      auth.user = null;
      await expectLater(
          repo.status(room()),
          throwsA(isA<AppFailure>()
              .having((e) => e.code, 'code', 'session-changed')));
      expect(transport.writes, 0);
      repo.close();
    });
    test('401 renueva una vez, después cierra la sesión y bloquea', () async {
      var calls = 0;
      final repo = ApiChatRepository(auth, transport: transport,
          client: MockClient((_) async {
        calls++;
        return http.Response('{}', 401);
      }));
      await expectLater(repo.send(room(), newChatMessageId(), 'Hola'),
          throwsA(isA<AppFailure>()));
      expect(calls, 2);
      expect(auth.logoutCalls, 1);
      expect(transport.writes, 0);
      repo.close();
    });
    test('Cierre entre consulta inicial y envío se vuelve a verificar',
        () async {
      var closed = false;
      final repo = ApiChatRepository(auth,
          transport: transport,
          client: MockClient((_) async => http.Response(
              '{"estado":"${closed ? 'cerrado' : 'abierto'}"}', 200)));
      final controller = ChatController(repo, room());
      await controller.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(controller.canSend, isTrue);
      closed = true;
      expect(await controller.send('Hola'), isFalse);
      expect(controller.status?.state, ChatState.cerrado);
      expect(transport.writes, 0);
      controller.dispose();
      repo.close();
    });
    test(
        'Respuesta perdida conserva ID para reintento; evita envíos concurrentes',
        () async {
      final repo = ApiChatRepository(auth,
          transport: transport,
          client: MockClient(
              (_) async => http.Response('{"estado":"abierto"}', 200)));
      final c = ChatController(repo, room());
      await c.refresh();
      await Future<void>.delayed(Duration.zero);
      transport.failure =
          const AppFailure('Respuesta perdida', code: 'network');
      expect(await c.send('Hola'), isFalse);
      final id = transport.ids.single;
      transport.failure = null;
      transport.gate = Completer<void>();
      final sending = c.send('Hola');
      expect(await c.send('Hola'), isFalse);
      transport.gate!.complete();
      expect(await sending, isTrue);
      expect(transport.ids, [id, id]);
      c.dispose();
      repo.close();
    });
    test('Error del stream bloquea, actualizar recupera y dispose cancela',
        () async {
      final repo = ApiChatRepository(auth,
          transport: transport,
          client: MockClient(
              (_) async => http.Response('{"estado":"abierto"}', 200)));
      final c = ChatController(repo, room());
      await c.refresh();
      await Future<void>.delayed(Duration.zero);
      transport.updates
          .addError(const AppFailure('Sin conexión', code: 'network'));
      expect(c.canSend, isFalse);
      await c.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(c.canSend, isTrue);
      c.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(transport.updates.hasListener, isFalse);
      repo.close();
    });

    test('Permisos revocados limpian mensajes y cancelan la escucha', () async {
      var forbidden = false;
      final repo = ApiChatRepository(auth,
          transport: transport,
          client: MockClient((_) async => forbidden
              ? http.Response('{}', 403)
              : http.Response('{"estado":"abierto"}', 200)));
      final c = ChatController(repo, room());
      await c.refresh();
      await Future<void>.delayed(Duration.zero);
      transport.updates.add([
        ChatMessage(
            id: 'm1',
            author: 'traveler',
            text: 'Privado',
            createdAt: DateTime(2026))
      ]);
      expect(c.messages, isNotEmpty);
      forbidden = true;
      await c.refresh();
      await Future<void>.delayed(Duration.zero);
      expect(c.messages, isEmpty);
      expect(c.canSend, isFalse);
      expect(transport.updates.hasListener, isFalse);
      c.dispose();
      repo.close();
    });
    test('Stream terminado bloquea nuevos envíos hasta reconectar', () async {
      final repo = ApiChatRepository(auth,
          transport: transport,
          client: MockClient(
              (_) async => http.Response('{"estado":"abierto"}', 200)));
      final c = ChatController(repo, room());
      await c.refresh();
      await Future<void>.delayed(Duration.zero);
      await transport.close();
      await Future<void>.delayed(Duration.zero);
      expect(c.canSend, isFalse);
      expect(c.messagesError, isNotNull);
      c.dispose();
      repo.close();
    });
  });
  group('Interfaz del chat', () {
    late FakeAuthService auth;
    late AuthController controller;
    late RoleController roles;
    late FakeTransport transport;
    late ApiChatRepository chats;
    var closed = false;
    setUp(() {
      auth = FakeAuthService(user: testUser);
      controller =
          AuthController(auth, FakeUserRepository()..stored = testProfile);
      transport = FakeTransport();
      closed = false;
      chats = ApiChatRepository(auth,
          transport: transport,
          client: MockClient((_) async => http.Response(
              '{"estado":"${closed ? 'cerrado' : 'abierto'}"}', 200)));
    });
    tearDown(() async {
      roles.dispose();
      controller.dispose();
      chats.close();
      await auth.close();
      await transport.close();
    });
    Future<void> tap(WidgetTester t, Finder f) async {
      await t.ensureVisible(f);
      await t.pumpAndSettle();
      await t.tap(f);
      await t.pumpAndSettle();
    }

    Future<void> open(WidgetTester t,
        {bool largeText = false, bool traveler = false}) async {
      final s = traveler
          ? parcel(
              owner: 'sender',
              traveler: testUser.uid,
              state: ShipmentStatus.recibida)
          : parcel();
      final shipments = FakeShipmentRepository()..mineItems = [s];
      roles = RoleController(
          controller,
          MemoryRoleStore()
            ..roles[testUser.uid] =
                traveler ? UserRole.viajero : UserRole.remitente);
      final app = LapticonApp(
          controller: controller,
          roles: roles,
          shipments: shipments,
          trips: FakeTripRepository(),
          chats: chats,
          showChat: true);
      await t.pumpWidget(largeText
          ? MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: app)
          : app);
      await t.pumpAndSettle();
      if (traveler) {
        // Mostrar la misma tarjeta desde un scope existente permite probar el destino inverso.
        final context = t.element(find.text('Calificar remitentes'));
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => _ChatEntry(s)));
        await t.pumpAndSettle();
      } else {
        await tap(t, find.text('Mis encomiendas'));
      }
      await tap(t, find.text('Abrir chat'));
    }

    testWidgets('Pendiente: aviso visible y envío bloqueado', (t) async {
      transport.enabled = false;
      await open(t);
      expect(find.text(chatPendingMessage), findsOneWidget);
      expect(transport.watches, 0);
      expect(
          t
              .widget<TextField>(find.byKey(const ValueKey('chat-message')))
              .enabled,
          isFalse);
      expect(
          t
              .widget<FilledButton>(
                  find.byWidgetPredicate((w) => w is FilledButton))
              .onPressed,
          isNull);
      await t.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('Stream, envío confirmado y borrado del borrador', (t) async {
      await open(t);
      await t.enterText(find.byType(TextField), 'Hola, coordinemos');
      await tap(t, find.text('Enviar mensaje'));
      expect(find.text('Hola, coordinemos'), findsOneWidget);
      expect(transport.writes, 1);
      expect(t.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty);
      await t.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('Fallo conserva borrador, reintento usa el mismo ID',
        (t) async {
      transport.failure = const AppFailure('Sin conexión', code: 'network');
      await open(t);
      await t.enterText(find.byType(TextField), 'Hola');
      await tap(t, find.text('Enviar mensaje'));
      expect(find.text('Sin conexión'), findsOneWidget);
      expect(
          t.widget<TextField>(find.byType(TextField)).controller!.text, 'Hola');
      transport.failure = null;
      await tap(t, find.text('Enviar mensaje'));
      expect(transport.ids[0], transport.ids[1]);
      await t.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('Chat cerrado mantiene mensajes y bloquea el compositor',
        (t) async {
      closed = true;
      await open(t);
      transport.updates.add([
        ChatMessage(
            id: 'm1',
            author: 'traveler',
            text: 'Entrega coordinada',
            createdAt: DateTime(2026))
      ]);
      await t.pumpAndSettle();
      expect(find.text('Entrega coordinada'), findsOneWidget);
      expect(t.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      await t.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('Refrescar detecta cierre, no depende de volver a entrar',
        (t) async {
      await open(t);
      closed = true;
      await tap(t, find.byTooltip('Actualizar estado del chat'));
      expect(t.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      await t.pumpWidget(const SizedBox.shrink());
    });
    testWidgets('Acceso del viajero identifica al remitente', (t) async {
      await open(t, traveler: true);
      expect(find.text('Chat con remitente'), findsOneWidget);
      await t.pumpWidget(const SizedBox.shrink());
    });
    for (final width in [320.0, 430.0]) {
      testWidgets('Ancho $width, texto 200% y teclado sin desbordes',
          (t) async {
        t.view.physicalSize = Size(width, 700);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        await open(t, largeText: true);
        await t.enterText(find.byType(TextField), 'Mensaje accesible');
        t.view.viewInsets = FakeViewPadding(bottom: 260);
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox.shrink());
        t.view.resetViewInsets();
      });
    }
    testWidgets('Salir de la pantalla cancela la escucha', (t) async {
      await open(t);
      await tap(t, find.byTooltip('Volver'));
      await t.pumpAndSettle();
      expect(transport.updates.hasListener, isFalse);
      await t.pumpWidget(const SizedBox.shrink());
    });
  });
}

// Acceso de prueba con el mismo componente usado por las tarjetas de producción.
class _ChatEntry extends StatelessWidget {
  const _ChatEntry(this.shipment);
  final Shipment shipment;
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: ShipmentCard(shipment: shipment));
}

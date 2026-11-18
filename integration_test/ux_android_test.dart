import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lapticon/auth/auth_controller.dart';
import 'package:lapticon/auth/auth_service.dart';
import 'package:lapticon/data/delivered_shipment_store.dart';
import 'package:lapticon/data/flight_catalog.dart';
import 'package:lapticon/data/flight_city.dart';
import 'package:lapticon/data/rating_repository.dart';
import 'package:lapticon/data/shipment_repository.dart';
import 'package:lapticon/main.dart';
import 'package:lapticon/roles/role_controller.dart';
import 'package:lapticon/roles/role_store.dart';
import 'package:lapticon/utils/format.dart';
import '../test/fakes.dart';

// Todos los cambios de datos de este recorrido son simulados y locales al test.
class ScenarioShipments extends FakeShipmentRepository {
  Shipment copy(Shipment s,
          {String? owner, String? traveler, ShipmentStatus? status}) =>
      Shipment(
          id: s.id,
          origin: s.origin,
          destination: s.destination,
          notes: s.notes,
          currency: s.currency,
          value: s.value,
          status: status ?? s.status,
          ownerId: owner ?? s.ownerId,
          travelerId: traveler ?? s.travelerId,
          ownerName: s.ownerName);
  @override
  Future<Shipment> create(ShipmentDraft draft) async {
    final item = copy(await super.create(draft), owner: testUser.uid);
    mineItems.add(item);
    return item;
  }

  @override
  Future<void> take(String id) async {
    await super.take(id);
    taken = [
      for (final s in taken)
        s.id == id
            ? copy(s, traveler: testUser.uid, status: ShipmentStatus.tomada)
            : s
    ];
  }
}

class ScenarioRatings implements RatingRepository {
  UserRating? saved;
  @override
  Future<UserRating?> existing(String author, RatingTarget target) async =>
      saved;
  @override
  Future<RatingReceipt> rate(
      AuthUser author, Shipment shipment, int score, String comment) async {
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

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Recorrido Android del alcance evaluado con servicios simulados',
      (t) async {
    final auth = FakeAuthService();
    final controller =
        AuthController(auth, FakeUserRepository()..stored = testProfile);
    final roles = RoleController(controller, MemoryRoleStore());
    final shipments = ScenarioShipments();
    shipments.places['Estados Unidos'] = ['Miami'];
    shipments.available = [
      const Shipment(
          id: 'otra-encomienda',
          origin: 'Bogotá',
          destination: 'Miami',
          notes: 'Documentos para entregar',
          currency: 'COP',
          value: 50000,
          status: ShipmentStatus.disponible,
          ownerId: 'remitente-prueba',
          ownerName: 'Remitente de prueba')
    ];
    final trips = FakeTripRepository()
      ..catalog = [
        FlightOption(
            'AV40',
            'Avianca',
            '${isoDate(DateTime.now())}T08:00:00',
            'BOG',
            'MIA',
            const Place(country: 'Colombia', city: 'Bogotá'),
            const Place(country: 'Estados Unidos', city: 'Miami'))
      ];
    final ratings = ScenarioRatings();
    await t.pumpWidget(LapticonApp(
        controller: controller,
        roles: roles,
        shipments: shipments,
        trips: trips,
        ratings: ratings,
        history: MemoryDeliveredShipmentStore()));
    await t.pumpAndSettle();
    Future<void> tap(Finder f) async {
      await t.ensureVisible(f);
      await t.pumpAndSettle();
      await t.tap(f);
      await t.pumpAndSettle();
    }

    Future<void> back() => tap(find.byKey(const ValueKey('page-back')));
    Future<void> pick(String key, String country, String city) async {
      await tap(find.descendant(
          of: find.byKey(ValueKey(key)), matching: find.byType(InkWell)));
      await tap(find.text(country));
      await tap(find.text(city));
    }

    Future<void> capture(String name) async {
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pumpAndSettle();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      await t.pumpAndSettle();
      if (name == '09-calificacion') {
        // Permite revisar el compositor nativo después del cierre del teclado.
        debugPrint('UX_REVIEW_CALIFICACION');
        await Future<void>.delayed(const Duration(seconds: 6));
        await t.pumpAndSettle();
      }
      await binding.takeScreenshot(name);
    }

    await binding.convertFlutterSurfaceToImage();
    await t.pumpAndSettle();
    await tap(find.text('Crear una cuenta'));
    for (var i = 0; i < 5; i++) {
      await t.enterText(find.byType(TextFormField).at(i),
          ['Ana', 'Gómez', 'ana@example.com', 'demo123', 'demo123'][i]);
    }
    await capture('01-registro-simulado');
    await back();
    expect(find.text('¿Descartar los cambios?'), findsOneWidget);
    await capture('02-confirmar-descarte');
    await tap(find.text('Seguir editando'));
    await tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
    await tap(find.text('Envío paquetes'));
    await capture('03-menu-remitente');
    await back();
    await back();
    expect(find.text('Crear encomienda'), findsOneWidget);
    await tap(find.text('Mis encomiendas'));
    await tap(find.text('Nueva'));
    await pick('campo-origen', 'Colombia', 'Bogotá');
    await pick('campo-destino', 'Estados Unidos', 'Miami');
    await t.enterText(find.byKey(const ValueKey('campo-observaciones')),
        'Dos libros de estudio');
    await t.enterText(find.byKey(const ValueKey('campo-valor')), '50000');
    await capture('04-registro-encomienda');
    await tap(find.text('Publicar encomienda'));
    await capture('05-encomienda-publicada');
    await tap(find.text('Volver al menú'));
    expect(find.text('Crear encomienda'), findsOneWidget);
    await back();
    await tap(find.text('Viajo y llevo paquetes'));
    await tap(find.text('Mi viaje'));
    for (final field in [
      ('vuelo-origen', 'Bogotá'),
      ('vuelo-destino', 'Miami')
    ]) {
      await tap(find.descendant(
          of: find.byKey(ValueKey(field.$1)),
          matching: find.byType(DropdownButton<FlightCity>)));
      await tap(find.text(field.$2).last);
    }
    await tap(find.text('Buscar vuelos'));
    await capture('06-seleccion-vuelo');
    await tap(find.text('AV40 · Avianca'));
    await tap(find.text('Registrar viaje'));
    await capture('07-viaje-registrado');
    await tap(find.text('Buscar encomiendas de mi ruta'));
    await tap(find.text('Tomar encomienda'));
    await tap(find.text('Sí, tomarla'));
    expect(shipments.takes, ['otra-encomienda']);
    await capture('08-encomienda-tomada');
    await back();
    await back();
    await tap(find.text('Mis entregas'));
    await tap(find.text('Marcar entrega'));
    await tap(find.text('Sí, marcar entrega'));
    expect(shipments.deliveries, ['otra-encomienda']);
    await back();
    await tap(find.text('Calificar remitentes'));
    await tap(find.text('Calificar remitente'));
    await tap(find.byKey(const ValueKey('rating-5')));
    await t.enterText(
        find.byType(TextField), 'Entrega coordinada correctamente.');
    await capture('09-calificacion');
    await tap(find.text('Enviar calificación'));
    expect(ratings.saved?.score, 5);
    await capture('10-calificacion-registrada');
    expect(find.text('Abrir chat'), findsNothing);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox.shrink());
    roles.dispose();
    controller.dispose();
    await auth.close();
  });
}

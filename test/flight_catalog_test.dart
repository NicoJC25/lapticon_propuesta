import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lapticon/auth/auth_service.dart';
import 'package:lapticon/auth/auth_controller.dart';
import 'package:lapticon/data/flight_catalog.dart';
import 'package:lapticon/data/trip_repository.dart';
import 'package:lapticon/data/flight_city.dart';
import 'package:lapticon/screens/flight_search_screen.dart';
import 'package:lapticon/theme/app_theme.dart';
import 'fakes.dart';

Map<String, dynamic> flight(String date, {String destination = 'MAD'}) => {
      'number': 'AV40',
      'airline': 'Avianca',
      'departure': '${date}T08:00:00',
      'origin': {'iata': 'BOG', 'city': 'Bogotá', 'country': 'CO'},
      'destination': {'iata': destination, 'city': 'Madrid', 'country': 'ES'}
    };

class CatalogTrips extends FakeTripRepository {
  @override
  Future<List<FlightOption>> searchFlights(
          String origin, String destination, String date) async =>
      [
        FlightOption.fromJson({
          ...flight(date, destination: destination),
          'destination': {'iata': destination, 'city': 'Miami', 'country': 'US'}
        })
      ];
}

void main() {
  test('Sin configuración no inventa vuelos', () async {
    final auth = FakeAuthService();
    final catalog = FlightCatalog(auth);
    await expectLater(
        catalog.search('BOG', 'MAD', '2026-11-10'), throwsA(isA<AppFailure>()));
    catalog.close();
    await auth.close();
  });
  test('Consulta autenticada comprueba ruta y autocompleta el viaje', () async {
    final auth = FakeAuthService();
    final catalog = FlightCatalog(auth, baseUrl: 'https://flights.example',
        client: MockClient((r) async {
      expect(r.headers['Authorization'], 'Bearer initial-test-token');
      expect(r.url.queryParameters,
          {'origin': 'BOG', 'destination': 'MAD', 'date': '2026-11-10'});
      return http.Response(jsonEncode([flight('2026-11-10')]), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }));
    final draft =
        (await catalog.search('BOG', 'MAD', '2026-11-10')).single.draft;
    expect(draft.flightNumber, 'AV40');
    expect(draft.origin.city, 'Bogotá');
    expect(draft.destination.city, 'Madrid');
    expect(draft.date, DateTime(2026, 11, 10));
    catalog.close();
    await auth.close();
  });
  test('Rechaza vuelos que no coinciden con la ruta', () async {
    final auth = FakeAuthService();
    final catalog = FlightCatalog(auth,
        baseUrl: 'https://flights.example',
        client: MockClient((r) async => http.Response(
            jsonEncode([flight('2026-11-10', destination: 'MIA')]), 200)));
    await expectLater(
        catalog.search('BOG', 'MAD', '2026-11-10'), throwsA(isA<AppFailure>()));
    catalog.close();
    await auth.close();
  });
  for (final size in [const Size(320, 568), const Size(430, 932)]) {
    testWidgets(
        'Selección por ruta devuelve datos sin publicar al elegir $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      TripDraft? chosen;
      final trips = CatalogTrips();
      final auth = FakeAuthService();
      final controller = AuthController(auth, FakeUserRepository());
      addTearDown(() async {
        controller.dispose();
        await auth.close();
      });
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => AuthScope(
              controller: controller,
              child: MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!)),
          home: Builder(
              builder: (context) => Scaffold(
                  body: TextButton(
                      onPressed: () async {
                        chosen = await Navigator.of(context).push<TripDraft>(
                            MaterialPageRoute(
                                builder: (_) =>
                                    FlightSearchScreen(repository: trips)));
                      },
                      child: const Text('Abrir'))))));
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();
      for (final field in tester.widgetList<DropdownButton<FlightCity>>(
          find.byType(DropdownButton<FlightCity>))) {
        expect(field.items!.map((i) => (i.child as Text).data),
            ['Bogotá', 'Medellín', 'Cali', 'New York', 'Miami', 'Washington']);
      }
      Future<void> choose(String key, String city) async {
        final dropdown = find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(DropdownButton<FlightCity>));
        await tester.ensureVisible(dropdown);
        await tester.tap(dropdown);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text(city).last);
        await tester.tap(find.text(city).last);
        await tester.pumpAndSettle();
      }

      await choose('vuelo-origen', 'Bogotá');
      await choose('vuelo-destino', 'Bogotá');
      await tester.ensureVisible(find.text('Buscar vuelos'));
      await tester.tap(find.text('Buscar vuelos'));
      await tester.pumpAndSettle();
      expect(find.text('El destino debe ser diferente del origen.'),
          findsOneWidget);
      await choose('vuelo-destino', 'Miami');
      await tester.ensureVisible(find.text('Buscar vuelos'));
      await tester.tap(find.text('Buscar vuelos'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('AV40 · Avianca'));
      await tester.tap(find.text('AV40 · Avianca'));
      await tester.pumpAndSettle();
      expect(chosen?.flightNumber, 'AV40');
      expect(chosen?.destination.city, 'Miami');
      expect(trips.registered, isEmpty);
    });
  }
}

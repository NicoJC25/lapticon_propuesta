import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lapticon/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android sin Firebase muestra aviso y bloquea acceso real',
      (tester) async {
    await app.main();
    await tester.pumpAndSettle();
    expect(find.text('Conexión con Firebase pendiente'), findsOneWidget);
    // Navegación del propio Flutter para inspeccionar la pantalla de acceso.
    final navigator =
        tester.state<NavigatorState>(find.byType(Navigator).first);
    navigator.pushNamed('/login');
    await tester.pumpAndSettle();
    expect(find.text('Conexión con Firebase pendiente'), findsOneWidget);
    final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Iniciar sesión'));
    expect(button.onPressed, isNull);
    final google = tester.widget<OutlinedButton>(
        find.byWidgetPredicate((widget) => widget is OutlinedButton));
    expect(google.onPressed, isNull);
    expect(find.text('Tu sesión\nestá lista.'), findsNothing);
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await binding.takeScreenshot('conexion-pendiente-android');
  });
}

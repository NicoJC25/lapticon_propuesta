import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lapticon/auth/firebase_auth_service.dart';
import 'package:lapticon/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
      'Firebase Android configurado habilita correo y deja Google pendiente',
      (tester) async {
    final auth = await FirebaseAuthService.bootstrap();
    expect(auth.configured, isTrue);
    expect(auth.googleAvailable, isFalse);
    await auth.signOut();
    await app.main();
    await tester.pumpAndSettle();
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .pushNamed('/login');
    await tester.pumpAndSettle();
    expect(find.text('Conexión con Firebase pendiente'), findsNothing);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Iniciar sesión'))
            .onPressed,
        isNotNull);
    expect(find.text('Google · Pendiente'), findsOneWidget);
    expect(
        tester
            .widget<OutlinedButton>(
                find.byWidgetPredicate((widget) => widget is OutlinedButton))
            .onPressed,
        isNull);
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await binding.takeScreenshot('firebase-correo-android');
  });
}

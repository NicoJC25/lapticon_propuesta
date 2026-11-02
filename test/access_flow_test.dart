import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lapticon/main.dart';
import 'package:lapticon/auth/auth_controller.dart';
import 'package:lapticon/auth/auth_service.dart';
import 'package:lapticon/theme/app_theme.dart';
import 'fakes.dart';

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  late FakeAuthService auth;
  late FakeUserRepository users;
  late AuthController controller;
  setUp(() {
    auth = FakeAuthService();
    users = FakeUserRepository();
    controller = AuthController(auth, users);
  });
  tearDown(() async {
    controller.dispose();
    await auth.close();
  });
  Future<void> open(WidgetTester tester, String route) async {
    await tester
        .pumpWidget(LapticonApp(controller: controller, initialRoute: route));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'Sin configuración se ven pantallas y se bloquean todas las acciones reales',
      (tester) async {
    await tester.pumpWidget(const LapticonApp(initialRoute: '/login'));
    await tester.pumpAndSettle();
    expect(find.text('Conexión con Firebase pendiente'), findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Iniciar sesión'))
            .onPressed,
        isNull);
    expect(
        tester
            .widget<OutlinedButton>(
                find.byWidgetPredicate((widget) => widget is OutlinedButton))
            .onPressed,
        isNull);
    await tapVisible(tester, find.text('Crea una cuenta'));
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Crear cuenta'))
            .onPressed,
        isNull);
    await tapVisible(tester, find.text('Inicia sesión'));
    await tapVisible(tester, find.text('¿Olvidaste tu contraseña?'));
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Enviar enlace'))
            .onPressed,
        isNull);
    expect(find.text('SOLICITUD RECIBIDA'), findsNothing);
  });

  testWidgets(
      'Login valida, muestra contraseña, maneja rechazo y abre perfil protegido',
      (tester) async {
    users.stored = testProfile;
    await open(tester, '/login');
    await tapVisible(
        tester, find.widgetWithText(FilledButton, 'Iniciar sesión'));
    expect(find.text('Escribe tu correo electrónico.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'invalido');
    await tester.enterText(find.byType(TextFormField).at(1), 'demo123');
    await tapVisible(tester, find.byTooltip('Mostrar contraseña'));
    expect(tester.widget<TextField>(find.byType(TextField).at(1)).obscureText,
        isFalse);
    await tapVisible(
        tester, find.widgetWithText(FilledButton, 'Iniciar sesión'));
    expect(find.text('Escribe un correo válido, como tu@correo.com.'),
        findsOneWidget);
    expect(auth.loginCalls, 0);
    await tester.enterText(find.byType(TextFormField).at(0), 'ana@example.com');
    auth.failure =
        const AppFailure('El correo o la contraseña no son correctos.');
    await tapVisible(
        tester, find.widgetWithText(FilledButton, 'Iniciar sesión'));
    expect(find.text('El correo o la contraseña no son correctos.'),
        findsOneWidget);
    expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
        isEmpty);
    auth.failure = null;
    await tester.enterText(find.byType(TextFormField).at(1), 'demo123');
    await tapVisible(
        tester, find.widgetWithText(FilledButton, 'Iniciar sesión'));
    expect(find.text('Tu sesión\nestá lista.'), findsOneWidget);
    expect(find.text('Hola, Ana Gómez.'), findsOneWidget);
    expect(users.writes, 0);
    await tapVisible(tester, find.text('Cerrar sesión'));
    expect(find.text('Qué bueno\nverte de nuevo.'), findsOneWidget);
    expect(find.text('Tu sesión\nestá lista.'), findsNothing);
  });

  testWidgets(
      'Registro valida coincidencia y permite reintentar perfil sin otra cuenta',
      (tester) async {
    await open(tester, '/register');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Crear cuenta'));
    expect(find.text('Completa este campo.'), findsNWidgets(2));
    final fields = find.byType(TextFormField);
    for (final e in {
      0: 'Ana',
      1: 'Gómez',
      2: 'ana@example.com',
      3: '123',
      4: '456'
    }.entries) {
      await tester.enterText(fields.at(e.key), e.value);
    }
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Crear cuenta'));
    expect(find.text('Usa al menos 6 caracteres.'), findsOneWidget);
    expect(find.text('Las contraseñas no coinciden.'), findsOneWidget);
    await tester.enterText(fields.at(3), 'demo123');
    await tester.enterText(fields.at(4), 'demo123');
    users.createFailure = const AppFailure('API temporalmente no disponible');
    await tapVisible(tester, find.widgetWithText(FilledButton, 'Crear cuenta'));
    expect(find.text('Falta conectar\ntu perfil.'), findsOneWidget);
    users.createFailure = null;
    await tapVisible(tester, find.text('Reintentar perfil'));
    expect(find.text('Tu sesión\nestá lista.'), findsOneWidget);
    expect(auth.registerCalls, 1);
  });

  testWidgets(
      'Google cancelado no muestra error; usuario nuevo completa perfil',
      (tester) async {
    auth.googleCancelled = true;
    await open(tester, '/login');
    await tapVisible(tester, find.text('Continuar con Google'));
    expect(find.text('Qué bueno\nverte de nuevo.'), findsOneWidget);
    expect(controller.error, isNull);
    auth.googleCancelled = false;
    await tapVisible(tester, find.text('Continuar con Google'));
    expect(find.text('Completa\ntu perfil.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'Ana');
    await tester.enterText(find.byType(TextFormField).at(1), 'Gómez');
    await tapVisible(tester, find.text('Guardar perfil'));
    expect(find.text('Hola, Ana Gómez.'), findsOneWidget);
  });

  testWidgets('Recuperación solo confirma tras éxito y permite cambiar correo',
      (tester) async {
    await open(tester, '/recovery');
    await tapVisible(tester, find.text('Enviar enlace'));
    expect(find.text('Escribe tu correo electrónico.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), 'ana@example.com');
    auth.failure = const AppFailure('Sin conexión');
    await tapVisible(tester, find.text('Enviar enlace'));
    expect(find.text('SOLICITUD RECIBIDA'), findsNothing);
    auth.failure = null;
    await tapVisible(tester, find.text('Enviar enlace'));
    expect(find.text('SOLICITUD RECIBIDA'), findsOneWidget);
    expect(find.text('ana@example.com'), findsOneWidget);
    await tapVisible(tester, find.text('Usar otro correo'));
    expect(find.byType(TextFormField), findsOneWidget);
    await tapVisible(tester, find.text('Enviar enlace'));
    await tapVisible(tester, find.text('Volver al login'));
    expect(find.text('Qué bueno\nverte de nuevo.'), findsOneWidget);
  });

  testWidgets('Ruta directa protegida sin sesión muestra login',
      (tester) async {
    await open(tester, '/home');
    expect(find.text('Qué bueno\nverte de nuevo.'), findsOneWidget);
    expect(find.text('Tu sesión\nestá lista.'), findsNothing);
  });
  testWidgets('Sesión restaurada entra protegida; expiración vuelve al login',
      (tester) async {
    controller.dispose();
    auth.user = testUser;
    users.stored = testProfile;
    controller = AuthController(auth, users);
    await open(tester, '/home');
    expect(find.text('Tu sesión\nestá lista.'), findsOneWidget);
    expect(auth.loginCalls, 0);
    auth.changes.add(null);
    await tester.pumpAndSettle();
    expect(find.text('Qué bueno\nverte de nuevo.'), findsOneWidget);
    expect(find.text('ana@example.com'), findsNothing);
  });
  testWidgets('Carga bloquea botón y campos mientras Firebase responde',
      (tester) async {
    users.stored = testProfile;
    auth.gate = Completer<void>();
    await open(tester, '/login');
    await tester.enterText(find.byType(TextFormField).at(0), 'ana@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'demo123');
    final button = find.widgetWithText(FilledButton, 'Iniciar sesión');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pump();
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    expect(tester.widget<TextField>(find.byType(TextField).first).enabled,
        isFalse);
    expect(auth.loginCalls, 1);
    auth.gate!.complete();
    await tester.pumpAndSettle();
  });

  for (final size in [
    const Size(320, 568),
    const Size(430, 932),
    const Size(1280, 800)
  ]) {
    testWidgets(
        'Pantallas sin desbordamientos con teclado y texto al 200 por ciento en $size',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2),
                  viewInsets: const EdgeInsets.only(bottom: 260)),
              child: child!),
          home: LapticonApp(controller: controller)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tapVisible(
          tester, find.widgetWithText(FilledButton, 'Iniciar sesión'));
      expect(tester.takeException(), isNull);
      await tapVisible(tester, find.text('Crea una cuenta'));
      expect(tester.takeException(), isNull);
      await tapVisible(tester, find.text('Inicia sesión'));
      await tapVisible(tester, find.text('¿Olvidaste tu contraseña?'));
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byType(TextFormField), 'ana@example.com');
      await tapVisible(tester, find.text('Enviar enlace'));
      expect(tester.takeException(), isNull);
      // También cubre inicio, perfil pendiente y error de API autenticados.
      auth.user = testUser;
      auth.changes.add(testUser);
      await tester.pump(const Duration(milliseconds: 100));
      // El evento externo de restauración debe terminar antes de inspeccionar la UI.
      await tester.runAsync(() async {
        await Future<void>.delayed(Duration.zero);
      });
      await tester.pumpAndSettle();
      expect(find.text('Completa\ntu perfil.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      users.stored = testProfile;
      await controller.retryProfile();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  test('Contraste AA en colores principales', () {
    double contrast(Color a, Color b) {
      final x = a.computeLuminance(), y = b.computeLuminance();
      return (x > y ? x + .05 : y + .05) / (x > y ? y + .05 : x + .05);
    }

    expect(contrast(AppColors.ink, Colors.white), greaterThanOrEqualTo(4.5));
    expect(
        contrast(AppColors.muted, AppColors.paper), greaterThanOrEqualTo(4.5));
    expect(
        contrast(AppColors.teal, AppColors.paper), greaterThanOrEqualTo(4.5));
  });
}

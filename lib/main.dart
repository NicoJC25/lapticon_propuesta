import 'config/evaluation_features.dart';
import 'chat/chat_repository.dart';
import 'chat/firestore_chat_transport.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/login_screen.dart';
import 'screens/recovery_screen.dart';
import 'screens/register_screen.dart';
import 'screens/welcome_screen.dart';
import 'theme/app_theme.dart';
import 'auth/auth_service.dart';
import 'auth/auth_controller.dart';
import 'auth/firebase_auth_service.dart';
import 'data/shipment_repository.dart';
import 'data/rating_repository.dart';
import 'data/delivered_shipment_store.dart';
import 'data/trip_repository.dart';
import 'data/user_repository.dart';
import 'roles/role_controller.dart';
import 'roles/role_store.dart';
import 'screens/role_redirector_screen.dart';
import 'screens/session_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  var auth = await FirebaseAuthService.bootstrap();
  UserRepository users;
  ShipmentRepository shipments;
  TripRepository trips;
  RatingRepository ratings;
  ChatRepository chats;
  try {
    users = ApiUserRepository(auth);
    shipments = ApiShipmentRepository(auth);
    trips = ApiTripRepository(auth);
    ratings = ApiRatingRepository(auth);
    chats = ApiChatRepository(auth, transport: configuredChatTransport());
  } catch (_) {
    auth = const UnconfiguredAuthService(
        configurationMessage:
            'La dirección API_BASE_URL no es válida. Revisa la configuración local y vuelve a compilar.');
    users = ApiUserRepository(auth,
        baseUrl: 'https://lapticon-backend.onrender.com');
    shipments = ApiShipmentRepository(auth,
        baseUrl: 'https://lapticon-backend.onrender.com');
    trips = ApiTripRepository(auth,
        baseUrl: 'https://lapticon-backend.onrender.com');
    ratings = ApiRatingRepository(auth,
        baseUrl: 'https://lapticon-backend.onrender.com');
    chats = ApiChatRepository(auth,
        baseUrl: 'https://lapticon-backend.onrender.com');
  }
  final controller = AuthController(auth, users);
  runApp(LapticonApp(
      controller: controller,
      roles: RoleController(controller, SharedPreferencesRoleStore()),
      shipments: shipments,
      trips: trips,
      ratings: ratings,
      chats: chats,
      history: SharedPreferencesDeliveredShipmentStore()));
}

class LapticonApp extends StatefulWidget {
  const LapticonApp(
      {super.key,
      this.controller,
      this.roles,
      this.shipments,
      this.trips,
      this.ratings,
      this.history,
      this.chats,
      this.showChat = false,
      this.showGoogle = false,
      this.initialRoute = '/'});
  final AuthController? controller;

  /// Sin inyectar se usa una caché de rol en memoria.
  final RoleController? roles;
  final ShipmentRepository? shipments;
  final TripRepository? trips;
  final RatingRepository? ratings;
  final DeliveredShipmentStore? history;
  final ChatRepository? chats;
  final bool showChat, showGoogle;
  final String initialRoute;
  @override
  State<LapticonApp> createState() => _LapticonAppState();
}

class _LapticonAppState extends State<LapticonApp> {
  final _navigator = GlobalKey<NavigatorState>();
  late final AuthController _controller;
  late final RoleController _roles;
  late final ShipmentRepository _shipments;
  late final TripRepository _trips;
  late final RatingRepository _ratings;
  late final DeliveredShipmentStore _history;
  late final ChatRepository _chats;
  String? _sessionUid;
  @override
  void initState() {
    super.initState();
    _controller = widget.controller ??
        AuthController(const UnconfiguredAuthService(),
            ApiUserRepository(const UnconfiguredAuthService()));
    _roles = widget.roles ?? RoleController(_controller, MemoryRoleStore());
    _shipments = widget.shipments ??
        ApiShipmentRepository(const UnconfiguredAuthService());
    _trips = widget.trips ?? ApiTripRepository(const UnconfiguredAuthService());
    _ratings = widget.ratings ?? ApiRatingRepository(_controller.auth);
    _history = widget.history ?? MemoryDeliveredShipmentStore();
    _chats = widget.chats ?? ApiChatRepository(_controller.auth);
    _controller.addListener(_sessionChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sessionChanged();
    });
  }

  void _sessionChanged() {
    final uid = _controller.user?.uid;
    if (_sessionUid == uid) return;
    _sessionUid = uid;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.user?.uid == uid) {
        _navigator.currentState?.pushNamedAndRemoveUntil(
            uid == null ? '/login' : '/home', (_) => false);
      }
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_sessionChanged);
    if (widget.roles == null) _roles.dispose();
    if (widget.shipments == null) _shipments.close();
    if (widget.trips == null) _trips.close();
    if (widget.ratings == null) _ratings.close();
    if (widget.chats == null) _chats.close();
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  Route<void> _route(RouteSettings settings) => MaterialPageRoute<void>(
        settings: settings,
        builder: (context) => AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              if (_controller.phase == SessionPhase.starting) {
                return const Scaffold(
                    body: Center(child: CircularProgressIndicator()));
              }
              if (_controller.signedIn) {
                // Con perfil completo se decide el menú por rol; el resto de
                // fases (cargando, perfil pendiente, error) siguen en sesión.
                return _controller.phase == SessionPhase.ready
                    ? const RoleRedirectorScreen()
                    : const SessionScreen();
              }
              return switch (settings.name) {
                '/' => const WelcomeScreen(),
                '/register' => const RegisterScreen(),
                '/recovery' => const RecoveryScreen(),
                _ =>
                  const LoginScreen(), // Incluye /home y cualquier ruta protegida.
              };
            }),
      );
  @override
  Widget build(BuildContext context) => AuthScope(
      controller: _controller,
      child: RoleScope(
          controller: _roles,
          child: ShipmentScope(
              repository: _shipments,
              child: TripScope(
                  repository: _trips,
                  child: RatingScope(
                      repository: _ratings,
                      history: _history,
                      child: ChatScope(
                          repository: _chats,
                          child: EvaluationFeatures(
                              chat: widget.showChat,
                              google: widget.showGoogle,
                              child: MaterialApp(
                                navigatorKey: _navigator,
                                title: 'Lapticon · Cada viaje conecta',
                                debugShowCheckedModeBanner: false,
                                theme: AppTheme.light,
                                locale: const Locale('es'),
                                supportedLocales: const [Locale('es')],
                                localizationsDelegates:
                                    GlobalMaterialLocalizations.delegates,
                                initialRoute: widget.initialRoute,
                                onGenerateInitialRoutes: (name) =>
                                    [_route(RouteSettings(name: name))],
                                onGenerateRoute: _route,
                              ))))))));
}

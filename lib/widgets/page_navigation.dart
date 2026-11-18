import 'package:flutter/material.dart';
import '../auth/auth_controller.dart';

class NavigationActivity extends ChangeNotifier {
  int _writes = 0;
  bool _disposed = false;
  bool get busy => _writes > 0;
  void begin() {
    if (_disposed) return;
    _writes++;
    notifyListeners();
  }

  void end() {
    if (_disposed) return;
    if (_writes > 0) _writes--;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class PageNavigation extends InheritedWidget {
  const PageNavigation(
      {super.key,
      required this.activity,
      required this.leave,
      required super.child});
  final NavigationActivity activity;
  final Future<void> Function(VoidCallback? destination) leave;
  static PageNavigation? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PageNavigation>();
  @override
  bool updateShouldNotify(PageNavigation oldWidget) =>
      activity != oldWidget.activity;
}

Future<void> confirmSignOut(BuildContext context) async {
  final auth = AuthScope.of(context);
  if (auth.busy) return;
  final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
              scrollable: true,
              title: const Text('¿Volver al acceso?'),
              content: const Text(
                  'Se cerrará tu sesión. Podrás volver a ingresar con tu cuenta.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Quedarme aquí')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Cerrar sesión y volver'))
              ]));
  if (confirmed == true && context.mounted) await auth.signOut();
}

void returnToMenu(BuildContext context) =>
    Navigator.of(context).popUntil((route) => route.isFirst);

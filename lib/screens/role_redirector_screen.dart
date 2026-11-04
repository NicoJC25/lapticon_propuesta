import 'package:flutter/material.dart';
import '../roles/role_controller.dart';
import '../roles/user_role.dart';
import 'remitente_menu_screen.dart';
import 'role_selection_screen.dart';
import 'viajero_menu_screen.dart';

/// Decide a qué menú va una sesión con perfil completo.
class RoleRedirectorScreen extends StatelessWidget {
  const RoleRedirectorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final roles = RoleScope.of(context);
    if (roles.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return switch (roles.role) {
      UserRole.remitente => const RemitenteMenuScreen(),
      UserRole.viajero => const ViajeroMenuScreen(),
      null => const RoleSelectionScreen(),
    };
  }
}

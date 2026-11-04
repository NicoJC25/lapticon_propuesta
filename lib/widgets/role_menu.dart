import 'package:flutter/material.dart';
import '../auth/auth_controller.dart';
import '../roles/role_controller.dart';
import '../roles/user_role.dart';
import 'access_components.dart';
import 'access_shell.dart';
import 'app_components.dart';

/// Estructura común de los menús de remitente y viajero.
class RoleMenu extends StatelessWidget {
  const RoleMenu(
      {super.key,
      required this.role,
      required this.title,
      required this.options});
  final UserRole role;
  final String title;
  final List<Widget> options;

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final roles = RoleScope.of(context);
    final name = auth.profile?.fullName ?? '';
    return AccessShell(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AccessHeader(
          back: false,
          eyebrow: 'MENÚ ${role.label.toUpperCase()}',
          title: title,
          subtitle: name.isNotEmpty ? 'Hola, $name.' : 'Bienvenido a Lapticon.'),
      if (roles.notice != null)
        InlineNotice(
            title: 'Rol guardado en el teléfono',
            message: roles.notice!,
            onClose: roles.dismissNotice),
      ...options,
      const SizedBox(height: 8),
      const Divider(),
      const SizedBox(height: 4),
      TextButton.icon(
          onPressed: roles.saving ? null : roles.change,
          icon: const Icon(Icons.swap_horiz_rounded),
          label: const Text('Cambiar de rol')),
      TextButton.icon(
          onPressed: auth.canSubmit ? auth.signOut : null,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Cerrar sesión')),
    ]));
  }
}

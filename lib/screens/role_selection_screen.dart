import 'package:flutter/material.dart';
import '../auth/auth_controller.dart';
import '../roles/role_controller.dart';
import '../roles/user_role.dart';
import '../theme/app_theme.dart';
import '../widgets/access_components.dart';
import '../widgets/access_shell.dart';

/// Primera pantalla de una sesión sin rol: el usuario elige remitente o viajero.
class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final roles = RoleScope.of(context);
    final name = auth.profile?.fullName ?? '';
    return AccessShell(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AccessHeader(
          back: false,
          eyebrow: 'ELIGE TU ROL',
          title: '¿Cómo quieres\nusar Lapticon?',
          subtitle: name.isNotEmpty ? 'Hola, $name.' : 'Bienvenido a Lapticon.'),
      const Text(
          'Elige con qué rol quieres empezar. Puedes cambiarlo después desde tu menú.'),
      const SizedBox(height: 20),
      for (final role in UserRole.values)
        _RoleOption(
            role: role,
            busy: roles.saving,
            onPressed: roles.saving ? null : () => roles.choose(role)),
      const SizedBox(height: 12),
      TextButton.icon(
          onPressed: auth.canSubmit && !roles.saving ? auth.signOut : null,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Cerrar sesión')),
    ]));
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption(
      {required this.role, required this.onPressed, required this.busy});
  final UserRole role;
  final VoidCallback? onPressed;
  final bool busy;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Semantics(
          button: true,
          enabled: onPressed != null,
          label: '${role.label}. ${role.choiceTitle}. ${role.description}',
          excludeSemantics: true,
          child: Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                  side: const BorderSide(color: AppColors.border)),
              child: InkWell(
                  key: ValueKey('rol-${role.apiValue}'),
                  borderRadius: BorderRadius.circular(18),
                  onTap: onPressed,
                  child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(children: [
                        Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                                color: AppColors.mint,
                                borderRadius: BorderRadius.circular(14)),
                            child: Icon(role.icon,
                                size: 26, color: AppColors.teal)),
                        const SizedBox(width: 16),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(role.label.toUpperCase(),
                                  style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.4,
                                      color: AppColors.teal)),
                              const SizedBox(height: 4),
                              Text(role.choiceTitle,
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.ink)),
                              const SizedBox(height: 4),
                              Text(role.description,
                                  style: const TextStyle(
                                      fontSize: 12.5,
                                      height: 1.4,
                                      color: AppColors.muted)),
                            ])),
                        const SizedBox(width: 8),
                        if (busy)
                          const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2))
                        else
                          const Icon(Icons.arrow_forward_rounded,
                              size: 18, color: AppColors.ink),
                      ]))))));
}

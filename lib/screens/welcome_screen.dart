import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/access_components.dart';
import '../widgets/access_shell.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) => AccessShell(
      welcome: true,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AccessHeader(
            back: false,
            eyebrow: 'BIENVENIDO A LAPTICON',
            title: 'Lo que envías,\nmás cerca.',
            subtitle:
                'Tu paquete encuentra a alguien que ya va en camino. Conecta, envía y acorta distancias.'),
        const Wrap(spacing: 8, runSpacing: 8, children: [
          _RoleChip(icon: Icons.inventory_2_outlined, label: 'Quiero enviar'),
          _RoleChip(icon: Icons.flight_takeoff_rounded, label: 'Voy a viajar'),
        ]),
        const SizedBox(height: 32),
        PrimaryAction(
            label: 'Iniciar sesión',
            onPressed: () => Navigator.pushNamed(context, '/login')),
        const SizedBox(height: 12),
        SizedBox(
            width: double.infinity,
            child: OutlinedButton(
                onPressed: () => Navigator.pushNamed(context, '/register'),
                child: const Text('Crear una cuenta'))),
        const SizedBox(height: 28),
        const Center(
            child: Text('Personas que viajan. Paquetes que llegan.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: AppColors.muted))),
        const SizedBox(height: 12),
      ]));
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
            color: const Color(0xFFEBF3EF),
            borderRadius: BorderRadius.circular(9)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: AppColors.teal),
          const SizedBox(width: 6),
          Flexible(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.teal)))
        ]),
      );
}

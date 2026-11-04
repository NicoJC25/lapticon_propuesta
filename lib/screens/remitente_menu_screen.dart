import 'package:flutter/material.dart';
import '../roles/user_role.dart';
import '../widgets/app_components.dart';
import '../widgets/role_menu.dart';
import 'crear_encomienda_screen.dart';

class RemitenteMenuScreen extends StatelessWidget {
  const RemitenteMenuScreen({super.key});

  @override
  Widget build(BuildContext context) => RoleMenu(
          role: UserRole.remitente,
          title: '¿Qué quieres\nenviar hoy?',
          options: [
            MenuTile(
                icon: Icons.add_box_outlined,
                title: 'Crear encomienda',
                subtitle:
                    'Publica qué envías, la ruta y el valor para que un viajero la tome.',
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    settings: const RouteSettings(name: '/encomiendas/nueva'),
                    builder: (_) => const CrearEncomiendaScreen()))),
            const MenuTile(
                icon: Icons.inventory_2_outlined,
                title: 'Mis encomiendas',
                subtitle: 'Disponibles, tomadas y vencidas.',
                badge: 'Disponible en la semana 3'),
            const MenuTile(
                icon: Icons.star_outline_rounded,
                title: 'Calificar viajeros',
                subtitle: 'Evalúa al viajero cuando recibas tu entrega.',
                badge: 'Disponible en la semana 4'),
          ]);
}

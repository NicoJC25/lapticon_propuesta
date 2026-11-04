import 'package:flutter/material.dart';
import '../roles/user_role.dart';
import '../widgets/app_components.dart';
import '../widgets/role_menu.dart';
import 'crear_encomienda_screen.dart';
import 'mis_encomiendas_screen.dart';

class RemitenteMenuScreen extends StatelessWidget {
  const RemitenteMenuScreen({super.key});

  void _open(BuildContext context, String name, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
          settings: RouteSettings(name: name), builder: (_) => screen));

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
                onTap: () => _open(context, '/encomiendas/nueva',
                    const CrearEncomiendaScreen())),
            MenuTile(
                icon: Icons.inventory_2_outlined,
                title: 'Mis encomiendas',
                subtitle: 'Disponibles, tomadas, recibidas y vencidas.',
                onTap: () => _open(context, '/encomiendas/mias',
                    const MisEncomiendasScreen())),
            const MenuTile(
                icon: Icons.star_outline_rounded,
                title: 'Calificar viajeros',
                subtitle: 'Evalúa al viajero cuando recibas tu entrega.',
                badge: 'Disponible en la semana 4'),
          ]);
}

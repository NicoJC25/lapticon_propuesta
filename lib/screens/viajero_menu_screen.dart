import 'package:flutter/material.dart';
import '../roles/user_role.dart';
import '../widgets/app_components.dart';
import '../widgets/role_menu.dart';
import 'buscar_encomiendas_screen.dart';
import 'mi_viaje_screen.dart';

class ViajeroMenuScreen extends StatelessWidget {
  const ViajeroMenuScreen({super.key});

  void _open(BuildContext context, String name, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
          settings: RouteSettings(name: name), builder: (_) => screen));

  @override
  Widget build(BuildContext context) => RoleMenu(
          role: UserRole.viajero,
          title: '¿A dónde\nviajas?',
          options: [
            MenuTile(
                icon: Icons.flight_takeoff_rounded,
                title: 'Mi viaje',
                subtitle:
                    'Registra tu vuelo y fecha, o revisa y cancela tu viaje activo.',
                onTap: () =>
                    _open(context, '/viajes/mio', const MiViajeScreen())),
            MenuTile(
                icon: Icons.search_rounded,
                title: 'Buscar encomiendas',
                subtitle:
                    'Encomiendas disponibles en la ruta de tu viaje, para tomarlas.',
                onTap: () => _open(context, '/encomiendas/buscar',
                    const BuscarEncomiendasScreen())),
            const MenuTile(
                icon: Icons.local_shipping_outlined,
                title: 'Mis entregas',
                subtitle: 'Marca como recibidas las encomiendas que llevaste.',
                badge: 'Disponible en la semana 4'),
          ]);
}

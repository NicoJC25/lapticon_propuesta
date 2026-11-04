import 'package:flutter/material.dart';
import '../roles/user_role.dart';
import '../widgets/app_components.dart';
import '../widgets/role_menu.dart';

class ViajeroMenuScreen extends StatelessWidget {
  const ViajeroMenuScreen({super.key});

  @override
  Widget build(BuildContext context) => const RoleMenu(
          role: UserRole.viajero,
          title: '¿A dónde\nviajas?',
          options: [
            MenuTile(
                icon: Icons.flight_takeoff_rounded,
                title: 'Registrar viaje',
                subtitle: 'Ingresa tu vuelo y fecha; se valida contra un vuelo real.',
                badge: 'Disponible en la semana 3'),
            MenuTile(
                icon: Icons.search_rounded,
                title: 'Buscar encomiendas',
                subtitle: 'Encuentra encomiendas disponibles en tu ruta.',
                badge: 'Disponible en la semana 3'),
            MenuTile(
                icon: Icons.local_shipping_outlined,
                title: 'Mis entregas',
                subtitle: 'Encomiendas que tomaste y su estado.',
                badge: 'Disponible en la semana 4'),
          ]);
}

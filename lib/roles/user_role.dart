import 'package:flutter/material.dart';

/// Rol con el que el usuario usa Lapticon.
enum UserRole {
  remitente('remitente', 'Remitente', 'Envío paquetes',
      'Publica encomiendas y sigue su estado hasta la entrega.',
      Icons.inventory_2_outlined),
  viajero('viajero', 'Viajero', 'Viajo y llevo paquetes',
      'Registra tus vuelos y toma encomiendas de tu ruta.',
      Icons.flight_takeoff_rounded);

  const UserRole(
      this.apiValue, this.label, this.choiceTitle, this.description, this.icon);

  /// Valor que se guarda en el servidor y en el teléfono.
  final String apiValue;
  final String label;
  final String choiceTitle;
  final String description;
  final IconData icon;

  UserRole get other =>
      this == UserRole.remitente ? UserRole.viajero : UserRole.remitente;

  static UserRole? parse(Object? value) {
    if (value is! String) return null;
    final normalized = value.trim().toLowerCase();
    for (final role in values) {
      if (role.apiValue == normalized) return role;
    }
    return null;
  }
}

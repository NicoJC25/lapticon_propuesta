import 'package:flutter/material.dart';
import '../data/shipment_repository.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';

/// Tarjeta de una encomienda con su ruta, valor, estado y fechas.
class ShipmentCard extends StatelessWidget {
  const ShipmentCard(
      {super.key, required this.shipment, this.action, this.showOwner = false});
  final Shipment shipment;

  /// Botón opcional al pie (p. ej. "Tomar encomienda").
  final Widget? action;
  final bool showOwner;

  @override
  Widget build(BuildContext context) {
    final s = shipment;
    return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
                child: Text('${s.origin} → ${s.destination}',
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink))),
            const SizedBox(width: 8),
            StatusChip(label: s.status.label, tone: toneFor(s.status)),
          ]),
          if (s.notes.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(s.notes,
                style: const TextStyle(
                    fontSize: 13, height: 1.4, color: AppColors.muted)),
          ],
          const SizedBox(height: 12),
          Wrap(spacing: 16, runSpacing: 6, children: [
            if (s.value != null)
              _Detail(
                  icon: Icons.payments_outlined,
                  text: formatMoney(s.value!, s.currency)),
            if (s.expiresAt != null)
              _Detail(
                  icon: Icons.event_outlined,
                  text: 'Vence ${formatDate(s.expiresAt!)}'),
            if (showOwner && s.ownerName.isNotEmpty)
              _Detail(icon: Icons.person_outline_rounded, text: s.ownerName),
          ]),
          if (action != null) ...[const SizedBox(height: 14), action!],
        ]));
  }
}

enum ChipTone { teal, blue, green, grey }

ChipTone toneFor(ShipmentStatus status) => switch (status) {
      ShipmentStatus.disponible => ChipTone.teal,
      ShipmentStatus.tomada => ChipTone.blue,
      ShipmentStatus.recibida => ChipTone.green,
      ShipmentStatus.vencida || ShipmentStatus.desconocido => ChipTone.grey,
    };

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label, required this.tone});
  final String label;
  final ChipTone tone;
  @override
  Widget build(BuildContext context) {
    final (background, ink) = switch (tone) {
      ChipTone.teal => (AppColors.mint, const Color(0xFF00594F)),
      ChipTone.blue => (const Color(0xFFE3ECFA), const Color(0xFF1F4E8C)),
      ChipTone.green => (const Color(0xFFDDF2E1), const Color(0xFF1E6130)),
      ChipTone.grey => (const Color(0xFFECEFF1), const Color(0xFF455A64)),
    };
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: background, borderRadius: BorderRadius.circular(20)),
        child: Text(label.toUpperCase(),
            style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: ink)));
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: AppColors.muted),
        const SizedBox(width: 5),
        Flexible(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink))),
      ]);
}

/// Estado de carga reutilizable: indicador, error con reintento o vacío.
class LoadingBlock extends StatelessWidget {
  const LoadingBlock({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Center(child: CircularProgressIndicator()));
}

class EmptyBlock extends StatelessWidget {
  const EmptyBlock(
      {super.key, required this.icon, required this.message, this.action});
  final IconData icon;
  final String message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: const Color(0xFFEFF5F4),
          borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        Icon(icon, size: 32, color: AppColors.muted),
        const SizedBox(height: 10),
        Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppColors.muted)),
        if (action != null) ...[const SizedBox(height: 14), action!],
      ]));
}

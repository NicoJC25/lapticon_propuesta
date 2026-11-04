import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Aviso en línea, anunciado por lectores de pantalla.
class InlineNotice extends StatelessWidget {
  const InlineNotice(
      {super.key,
      required this.message,
      this.title,
      this.error = false,
      this.onClose});
  final String message;
  final String? title;
  final bool error;
  final VoidCallback? onClose;
  static const errorBackground = Color(0xFFFCE8E6);
  static const errorInk = Color(0xFF8A1C12);

  @override
  Widget build(BuildContext context) => Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
            color: error ? errorBackground : AppColors.mint,
            borderRadius: BorderRadius.circular(14)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
              padding: const EdgeInsets.only(top: 2, right: 10),
              child: Icon(
                  error
                      ? Icons.error_outline_rounded
                      : Icons.info_outline_rounded,
                  size: 18,
                  color: error ? errorInk : AppColors.teal)),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                if (title != null)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(title!,
                          style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: error ? errorInk : AppColors.ink))),
                Text(message,
                    style: TextStyle(
                        fontSize: 13, color: error ? errorInk : AppColors.ink)),
              ])),
          if (onClose != null)
            IconButton(
                tooltip: 'Cerrar aviso',
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded,
                    size: 18, color: AppColors.muted)),
        ]),
      ));
}

/// Opción de menú. Sin [onTap] se muestra como pendiente con su [badge].
class MenuTile extends StatelessWidget {
  const MenuTile(
      {super.key,
      required this.icon,
      required this.title,
      required this.subtitle,
      this.onTap,
      this.badge});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Material(
            color: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                    color: enabled ? AppColors.teal : AppColors.border,
                    width: enabled ? 1.5 : 1)),
            child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: onTap,
                child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                              color: enabled
                                  ? AppColors.mint
                                  : const Color(0xFFEFF3F3),
                              borderRadius: BorderRadius.circular(12)),
                          child: Icon(icon,
                              size: 22,
                              color: enabled ? AppColors.teal : AppColors.muted)),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text(title,
                                style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.ink)),
                            const SizedBox(height: 4),
                            Text(subtitle,
                                style: const TextStyle(
                                    fontSize: 12.5,
                                    height: 1.4,
                                    color: AppColors.muted)),
                            if (badge != null) ...[
                              const SizedBox(height: 8),
                              Text(badge!.toUpperCase(),
                                  style: const TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.1,
                                      color: AppColors.muted)),
                            ],
                          ])),
                      if (enabled)
                        const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Icon(Icons.arrow_forward_rounded,
                                size: 18, color: AppColors.teal)),
                    ])))));
  }
}

/// Etiqueta de campo con el mismo estilo de los formularios de acceso.
class FieldLabel extends StatelessWidget {
  const FieldLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.ink)));
}

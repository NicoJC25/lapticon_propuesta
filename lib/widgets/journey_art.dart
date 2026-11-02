import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Ilustración vectorial local: no descarga imágenes ni requiere servicios.
class JourneyArt extends StatelessWidget {
  const JourneyArt({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
        image: true,
        label: 'Un paquete conecta dos destinos por una ruta de avión',
        child: ExcludeSemantics(
          child: AspectRatio(
            aspectRatio: 1.18,
            child: CustomPaint(painter: _JourneyPainter()),
          ),
        ),
      );
}

class _JourneyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 400, size.height / 340);
    final paint = Paint()..isAntiAlias = true;
    void line(Offset a, Offset b, Color color, [double width = 2]) {
      canvas.drawLine(
          a,
          b,
          paint
            ..color = color
            ..strokeWidth = width
            ..style = PaintingStyle.stroke);
      paint.style = PaintingStyle.fill;
    }

    void polygon(List<Offset> points, Color color) {
      final path = Path()..addPolygon(points, true);
      canvas.drawPath(
          path,
          paint
            ..color = color
            ..style = PaintingStyle.fill);
    }

    void text(String value, Offset offset, double fontSize, Color color,
        FontWeight weight) {
      final tp = TextPainter(
          text: TextSpan(
              text: value,
              style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: fontSize,
                  color: color,
                  fontWeight: weight)),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, offset);
    }

    canvas.drawCircle(
        const Offset(205, 164), 130, paint..color = const Color(0xFFCFEFE5));
    canvas.drawCircle(
        const Offset(205, 164),
        107,
        paint
          ..color = const Color(0xFFE1F6EF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
    paint.style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(51, 214)
      ..cubicTo(0, 72, 252, 8, 327, 109)
      ..cubicTo(411, 233, 259, 298, 285, 215);
    paint
      ..color = const Color(0xFF5C9E94)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 10) {
        canvas.drawPath(
            metric.extractPath(d, math.min(d + 4, metric.length)), paint);
      }
    }
    paint.style = PaintingStyle.fill;
    // Paquete isométrico y cinta.
    canvas.drawOval(const Rect.fromLTWH(106, 274, 191, 22),
        paint..color = const Color(0x18546C64));
    polygon([
      const Offset(109, 147),
      const Offset(211, 110),
      const Offset(302, 156),
      const Offset(202, 196)
    ], const Color(0xFFF1CA96));
    polygon([
      const Offset(109, 147),
      const Offset(202, 196),
      const Offset(202, 283),
      const Offset(110, 234)
    ], const Color(0xFFDAA263));
    polygon([
      const Offset(202, 196),
      const Offset(302, 156),
      const Offset(301, 245),
      const Offset(202, 283)
    ], const Color(0xFFE9B77D));
    polygon([
      const Offset(149, 132),
      const Offset(169, 125),
      const Offset(261, 172),
      const Offset(241, 180)
    ], const Color(0xFFFAE4C4));
    polygon([
      const Offset(241, 180),
      const Offset(261, 172),
      const Offset(261, 204),
      const Offset(241, 212)
    ], const Color(0xFFFFEDCF));
    line(const Offset(202, 197), const Offset(202, 281),
        const Color(0xFFC38C50), 1);
    canvas.save();
    canvas.translate(131, 181);
    canvas.skew(0, .49);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(0, 0, 49, 34), const Radius.circular(4)),
        paint..color = const Color(0xFFFFF9EF));
    for (int i = 0; i < 11; i++) {
      line(Offset(8 + i * 3, 9), Offset(8 + i * 3, 21), AppColors.ink,
          i.isEven ? 1.5 : .7);
    }
    canvas.restore();
    // Avión.
    canvas.save();
    canvas.translate(307, 83);
    canvas.rotate(-.5);
    final plane = Path()
      ..moveTo(0, -35)
      ..quadraticBezierTo(7, -36, 7, -15)
      ..lineTo(36, 7)
      ..lineTo(36, 15)
      ..lineTo(7, 4)
      ..lineTo(7, 24)
      ..lineTo(17, 33)
      ..lineTo(17, 38)
      ..lineTo(1, 32)
      ..lineTo(-15, 38)
      ..lineTo(-15, 33)
      ..lineTo(-6, 24)
      ..lineTo(-6, 4)
      ..lineTo(-35, 15)
      ..lineTo(-35, 7)
      ..lineTo(-6, -15)
      ..quadraticBezierTo(-6, -35, 0, -35)
      ..close();
    canvas.drawShadow(plane, AppColors.ink.withValues(alpha: .25), 7, true);
    canvas.drawPath(plane, paint..color = AppColors.ink);
    canvas.restore();
    // Tarjeta de ruta.
    final card = RRect.fromRectAndRadius(
        const Rect.fromLTWH(216, 235, 160, 70), const Radius.circular(16));
    canvas.drawShadow(
        Path()..addRRect(card), const Color(0x302E6157), 12, false);
    canvas.drawRRect(card, paint..color = Colors.white);
    text('BOG', const Offset(231, 248), 17, AppColors.ink, FontWeight.w800);
    text('MDE', const Offset(322, 248), 17, AppColors.ink, FontWeight.w800);
    line(const Offset(277, 259), const Offset(311, 259), AppColors.teal, 1.3);
    polygon([
      const Offset(312, 259),
      const Offset(307, 255),
      const Offset(307, 263)
    ], AppColors.teal);
    text('Cada viaje conecta', const Offset(231, 276), 10, AppColors.muted,
        FontWeight.w500);
    // Sello pequeño flotante.
    canvas.drawCircle(const Offset(79, 135), 24, paint..color = Colors.white);
    canvas.drawCircle(const Offset(79, 135), 16, paint..color = AppColors.teal);
    line(const Offset(72, 135), const Offset(77, 140), Colors.white, 2.4);
    line(const Offset(77, 140), const Offset(86, 130), Colors.white, 2.4);
    for (final point in [
      const Offset(92, 268),
      const Offset(352, 173),
      const Offset(165, 48)
    ]) {
      line(point.translate(-4, 0), point.translate(4, 0),
          const Color(0xFF77B6A6), 1.5);
      line(point.translate(0, -4), point.translate(0, 4),
          const Color(0xFF77B6A6), 1.5);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

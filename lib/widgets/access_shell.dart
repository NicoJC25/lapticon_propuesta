import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'journey_art.dart';
import 'access_components.dart';

class Brand extends StatelessWidget {
  const Brand({super.key});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Lapticon',
        child: ExcludeSemantics(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: AppColors.ink,
                  borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.near_me_rounded,
                  color: AppColors.mint, size: 23)),
          const SizedBox(width: 10),
          const Text('lapticon',
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                  fontSize: 25,
                  letterSpacing: -1.1,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink)),
          const Text('.',
              textScaler: TextScaler.noScaling,
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.teal)),
        ])),
      );
}

class AccessShell extends StatelessWidget {
  const AccessShell({super.key, required this.child, this.welcome = false});
  final Widget child;
  final bool welcome;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final padding = wide ? 40.0 : 24.0;
            return Column(children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                    padding, wide ? 26 : 18, padding, wide ? 26 : 12),
                child: SizedBox(
                    width: double.infinity,
                    child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 20,
                        runSpacing: 10,
                        children: [
                          const Brand(),
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                  color: const Color(0xFFE8F2EF),
                                  borderRadius: BorderRadius.circular(30)),
                              child: const Text('PROTOTIPO',
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                      color: AppColors.teal))),
                        ])),
              ),
              Expanded(
                  child: wide
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                          child: Row(children: [
                            const Expanded(child: _StoryPanel()),
                            Expanded(child: _ScrollableContent(child: child)),
                          ]),
                        )
                      : _ScrollableContent(
                          child: Column(children: [
                          if (welcome)
                            const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6),
                                child: JourneyArt()),
                          child,
                        ]))),
            ]);
          }),
        ),
      );
}

class _ScrollableContent extends StatelessWidget {
  const _ScrollableContent({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  minHeight:
                      (constraints.maxHeight - 32).clamp(0, double.infinity)),
              child: Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [const AuthStatus(), child]))),
            ),
          ));
}

class _StoryPanel extends StatelessWidget {
  const _StoryPanel();
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: const Color(0xFFE8F4EE),
            borderRadius: BorderRadius.circular(28)),
        child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
                  padding: const EdgeInsets.all(32),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                        minHeight: (constraints.maxHeight - 64)
                            .clamp(0, double.infinity)),
                    child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(children: [
                            Icon(Icons.public_rounded,
                                size: 16, color: AppColors.teal),
                            SizedBox(width: 8),
                            Flexible(
                                child: Text('MENOS DISTANCIA. MÁS CONEXIONES.',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.5,
                                        color: AppColors.teal)))
                          ]),
                          const SizedBox(height: 24),
                          Text('Un paquete.\nUn viaje.\nUna conexión.',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineLarge
                                  ?.copyWith(fontSize: 46)),
                          const SizedBox(height: 12),
                          ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 340),
                              child: const JourneyArt()),
                          const SizedBox(height: 12),
                          const Text('Eso que importa, llega más lejos.',
                              style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink)),
                          const SizedBox(height: 8),
                          Text(
                              'Conectamos a quienes envían con quienes ya van en camino.',
                              style: Theme.of(context).textTheme.bodyLarge),
                          const SizedBox(height: 28),
                          const Wrap(spacing: 16, runSpacing: 10, children: [
                            _Feature(
                                icon: Icons.inventory_2_outlined,
                                text: 'Envía con propósito'),
                            _Feature(
                                icon: Icons.flight_takeoff_rounded,
                                text: 'Viaja y conecta')
                          ]),
                        ]),
                  ),
                )),
      );
}

class _Feature extends StatelessWidget {
  const _Feature({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) =>
      Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 17, color: AppColors.teal),
        const SizedBox(width: 6),
        Flexible(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.muted)))
      ]);
}

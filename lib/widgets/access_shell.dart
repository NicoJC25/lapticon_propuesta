import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'journey_art.dart';
import 'access_components.dart';
import 'page_navigation.dart';

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

class AccessShell extends StatefulWidget {
  const AccessShell(
      {super.key,
      required this.child,
      this.welcome = false,
      this.backLabel = 'Volver',
      this.onBack,
      this.isDirty,
      this.changes,
      this.busy = false});
  final Widget child;
  final bool welcome, busy;
  final String backLabel;
  final Future<void> Function()? onBack;
  final bool Function()? isDirty;
  final Listenable? changes;
  @override
  State<AccessShell> createState() => _AccessShellState();
}

class _AccessShellState extends State<AccessShell> {
  final _activity = NavigationActivity();
  bool _leaving = false, _allowPop = false;
  bool get _busy => widget.busy || _activity.busy;
  bool get _dirty => widget.isDirty?.call() ?? false;
  @override
  void initState() {
    super.initState();
    _activity.addListener(_changed);
    widget.changes?.addListener(_changed);
  }

  @override
  void didUpdateWidget(AccessShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.changes != widget.changes) {
      oldWidget.changes?.removeListener(_changed);
      widget.changes?.addListener(_changed);
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.changes?.removeListener(_changed);
    _activity.removeListener(_changed);
    _activity.dispose();
    super.dispose();
  }

  Future<void> _leave(VoidCallback? destination) async {
    if (_busy || _leaving || widget.welcome) return;
    _leaving = true;
    FocusScope.of(context).unfocus();
    try {
      if (_dirty) {
        final discard = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
                    scrollable: true,
                    title: const Text('¿Descartar los cambios?'),
                    content: const Text(
                        'Tienes datos sin enviar. Si sales ahora, se perderán los cambios de este formulario.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Seguir editando')),
                      FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Descartar cambios'))
                    ]));
        if (discard != true || !mounted || _busy) return;
      }
      if (!mounted || _busy) return;
      if (destination != null || widget.onBack != null) {
        setState(() => _allowPop = true);
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
        if (destination != null) {
          destination();
        } else {
          await widget.onBack!();
        }
        return;
      }
      final navigator = Navigator.of(context);
      if (navigator.canPop()) {
        setState(() => _allowPop = true);
        await WidgetsBinding.instance.endOfFrame;
        if (mounted) navigator.pop();
      } else {
        navigator.pushReplacementNamed('/');
      }
    } finally {
      if (mounted) {
        setState(() {
          _leaving = false;
          _allowPop = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<Object?>(
        canPop: widget.welcome ||
            _allowPop ||
            (!_busy &&
                !_dirty &&
                widget.onBack == null &&
                MediaQuery.viewInsetsOf(context).bottom == 0 &&
                Navigator.canPop(context)),
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (MediaQuery.viewInsetsOf(context).bottom > 0) {
            FocusScope.of(context).unfocus();
            return;
          }
          _leave(null);
        },
        child: PageNavigation(
            activity: _activity,
            leave: _leave,
            child: Scaffold(
              body: SafeArea(
                  child: LayoutBuilder(builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                return Column(children: [
                  Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      child: widget.welcome
                          ? const Align(
                              alignment: Alignment.centerLeft, child: Brand())
                          : Row(children: [
                              Expanded(
                                  child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: TextButton.icon(
                                          key: const ValueKey('page-back'),
                                          onPressed: _busy || _leaving
                                              ? null
                                              : () => _leave(null),
                                          icon: const Icon(
                                              Icons.arrow_back_rounded),
                                          label: Text(widget.backLabel)))),
                              Semantics(
                                  label: 'Lapticon',
                                  child: const ExcludeSemantics(
                                      child: Icon(Icons.near_me_rounded,
                                          color: AppColors.teal, size: 28))),
                            ])),
                  Expanded(
                      child: wide
                          ? Padding(
                              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                              child: Row(children: [
                                const Expanded(child: _StoryPanel()),
                                Expanded(
                                    child:
                                        _ScrollableContent(child: widget.child))
                              ]))
                          : _ScrollableContent(
                              child: Column(children: [
                              if (widget.welcome)
                                const Padding(
                                    padding:
                                        EdgeInsets.symmetric(horizontal: 6),
                                    child: JourneyArt()),
                              widget.child,
                            ]))),
                ]);
              })),
            )),
      );
}

class _ScrollableContent extends StatelessWidget {
  const _ScrollableContent({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [const AuthStatus(), child]),
            )),
      );
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

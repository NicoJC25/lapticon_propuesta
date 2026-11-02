import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../auth/auth_controller.dart';

class AccessHeader extends StatelessWidget {
  const AccessHeader(
      {super.key,
      required this.eyebrow,
      required this.title,
      required this.subtitle,
      this.back = true});
  final String eyebrow;
  final String title;
  final String subtitle;
  final bool back;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (back) ...[
          TextButton.icon(
              onPressed: () {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  Navigator.pushReplacementNamed(context, '/');
                }
              },
              icon: const Icon(Icons.arrow_back_rounded, size: 17),
              label: const Text('Volver'),
              style: TextButton.styleFrom(padding: EdgeInsets.zero)),
          const SizedBox(height: 18),
        ],
        Text(eyebrow,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.7,
                color: AppColors.teal)),
        const SizedBox(height: 12),
        Semantics(
            header: true,
            child:
                Text(title, style: Theme.of(context).textTheme.headlineLarge)),
        const SizedBox(height: 12),
        Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 28),
      ]);
}

class AccessField extends StatefulWidget {
  const AccessField(
      {super.key,
      required this.label,
      required this.hint,
      required this.icon,
      required this.controller,
      required this.validator,
      this.password = false,
      this.email = false,
      this.last = false,
      this.onSubmitted,
      this.enabled = true,
      this.autofillHints});
  final bool enabled;
  final String label;
  final String hint;
  final IconData icon;
  final TextEditingController controller;
  final String? Function(String?) validator;
  final bool password;
  final bool email;
  final bool last;
  final VoidCallback? onSubmitted;
  final Iterable<String>? autofillHints;

  @override
  State<AccessField> createState() => _AccessFieldState();
}

class _AccessFieldState extends State<AccessField> {
  bool _hidden = true;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink)),
          const SizedBox(height: 8),
          Semantics(
              label: widget.label,
              child: TextFormField(
                enabled: widget.enabled,
                controller: widget.controller,
                validator: widget.validator,
                obscureText: widget.password && _hidden,
                enableSuggestions: !widget.password,
                autocorrect: !widget.password && !widget.email,
                keyboardType: widget.email
                    ? TextInputType.emailAddress
                    : TextInputType.text,
                textCapitalization: widget.email || widget.password
                    ? TextCapitalization.none
                    : TextCapitalization.words,
                textInputAction:
                    widget.last ? TextInputAction.done : TextInputAction.next,
                autofillHints: widget.autofillHints,
                onFieldSubmitted: (_) {
                  if (widget.last) widget.onSubmitted?.call();
                },
                style: const TextStyle(fontSize: 14, color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  prefixIcon:
                      Icon(widget.icon, size: 19, color: AppColors.muted),
                  suffixIcon: widget.password
                      ? IconButton(
                          tooltip: _hidden
                              ? 'Mostrar ${widget.label.toLowerCase()}'
                              : 'Ocultar ${widget.label.toLowerCase()}',
                          onPressed: widget.enabled
                              ? () => setState(() => _hidden = !_hidden)
                              : null,
                          icon: Icon(
                              _hidden
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 19,
                              color: AppColors.muted),
                        )
                      : null,
                ),
              )),
        ]),
      );
}

abstract final class Validators {
  static String? required(String? value) =>
      value == null || value.trim().isEmpty ? 'Completa este campo.' : null;
  static String? email(String? value) {
    if (required(value) != null) return 'Escribe tu correo electrónico.';
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value!.trim())) {
      return 'Escribe un correo válido, como tu@correo.com.';
    }
    return null;
  }

  static String? password(String? value) =>
      value == null || value.isEmpty ? 'Escribe tu contraseña.' : null;
  static String? newPassword(String? value) {
    if (password(value) != null) return password(value);
    return value!.length < 6 ? 'Usa al menos 6 caracteres.' : null;
  }
}

class PrimaryAction extends StatelessWidget {
  const PrimaryAction(
      {super.key,
      required this.label,
      required this.onPressed,
      this.busy = false,
      this.icon = Icons.arrow_forward_rounded});
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData icon;
  @override
  Widget build(BuildContext context) => SizedBox(
      width: double.infinity,
      child: FilledButton(
          onPressed: onPressed,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Flexible(child: Text(label, textAlign: TextAlign.center)),
            const SizedBox(width: 12),
            if (busy)
              const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
            else
              Icon(icon, size: 18)
          ])));
}

class GoogleAction extends StatelessWidget {
  const GoogleAction({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: AuthScope.of(context).canSubmit
            ? AuthScope.of(context).google
            : null,
        icon: const ExcludeSemantics(
            child: Text('G',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF356AC3)))),
        label: const Text('Continuar con Google'),
      ));
}

class OrDivider extends StatelessWidget {
  const OrDivider({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
      padding: EdgeInsets.symmetric(vertical: 22),
      child: Row(children: [
        Expanded(child: Divider()),
        Flexible(
            flex: 2,
            child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('o continúa con',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: AppColors.muted)))),
        Expanded(child: Divider())
      ]));
}

class AccessFooter extends StatelessWidget {
  const AccessFooter(
      {super.key,
      required this.prompt,
      required this.action,
      required this.route});
  final String prompt;
  final String action;
  final String route;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(children: [
        Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(prompt,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              TextButton(
                  onPressed: () =>
                      Navigator.pushReplacementNamed(context, route),
                  child: Text(action))
            ]),
        const SizedBox(height: 18),
        const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.lock_outline_rounded, size: 13, color: AppColors.muted),
          SizedBox(width: 6),
          Flexible(
              child: Text('Acceso con Firebase Authentication',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 10, color: AppColors.muted)))
        ]),
        const SizedBox(height: 10),
      ]));
}

class AuthStatus extends StatelessWidget {
  const AuthStatus({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final message = !auth.available ? auth.configurationMessage : auth.error;
    if (message == null) return const SizedBox.shrink();
    return Semantics(
        liveRegion: true,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
              color: AppColors.mint, borderRadius: BorderRadius.circular(14)),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (!auth.available)
              const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Text('Conexión con Firebase pendiente',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, color: AppColors.ink))),
            Text(message,
                style: const TextStyle(color: AppColors.ink, fontSize: 13)),
          ]),
        ));
  }
}

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/access_components.dart';
import '../widgets/access_shell.dart';
import '../auth/auth_controller.dart';

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key});
  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sent = false;

  Future<void> _submit() async {
    final auth = AuthScope.of(context);
    if (!auth.canSubmit) return;
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final sent = await auth.recover(_email.text);
    if (mounted && sent) setState(() => _sent = true);
  }

  void _login() => Navigator.pushNamedAndRemoveUntil(
      context, '/login', (route) => route.isFirst);

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AccessShell(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!_sent) ...[
          const AccessHeader(
              eyebrow: 'VOLVAMOS A CONECTAR',
              title: '¿Olvidaste\ntu contraseña?',
              subtitle:
                  'A veces pasa. Escribe tu correo para recuperar el acceso a tu cuenta.'),
          Container(
              width: 68,
              height: 68,
              margin: const EdgeInsets.only(bottom: 28),
              decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.key_rounded,
                  color: AppColors.teal, size: 32)),
          Form(
              key: _form,
              child: AccessField(
                  label: 'Correo electrónico',
                  hint: 'tu@correo.com',
                  icon: Icons.mail_outline_rounded,
                  controller: _email,
                  validator: Validators.email,
                  enabled: !AuthScope.of(context).busy,
                  email: true,
                  last: true,
                  onSubmitted: _submit)),
          const SizedBox(height: 10),
          PrimaryAction(
              label: 'Enviar enlace',
              busy: AuthScope.of(context).busy,
              onPressed: AuthScope.of(context).canSubmit ? _submit : null,
              icon: Icons.mail_outline_rounded),
          const SizedBox(height: 20),
          Center(
              child: TextButton(
                  onPressed: _login,
                  child: const Text('Volver a iniciar sesión'))),
        ] else ...[
          Container(
              width: 88,
              height: 88,
              margin: const EdgeInsets.only(bottom: 28),
              decoration: BoxDecoration(
                  color: AppColors.mint,
                  borderRadius: BorderRadius.circular(26)),
              child: const Icon(Icons.mark_email_read_outlined,
                  color: AppColors.teal, size: 42)),
          const AccessHeader(
              back: false,
              eyebrow: 'SOLICITUD RECIBIDA',
              title: 'El siguiente paso,\nen tu correo.',
              subtitle:
                  'Si el correo tiene una cuenta, recibirás un enlace para cambiar tu contraseña. Revisa también la carpeta de spam.'),
          Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(14)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Correo indicado',
                        style: TextStyle(fontSize: 11, color: AppColors.muted)),
                    const SizedBox(height: 6),
                    Text(_email.text.trim(),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 12),
                    const Text(
                        'Por privacidad, no confirmamos si existe una cuenta con este correo.',
                        style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  ])),
          const SizedBox(height: 28),
          PrimaryAction(label: 'Volver al login', onPressed: _login),
          const SizedBox(height: 12),
          Center(
              child: TextButton(
                  onPressed: () => setState(() => _sent = false),
                  child: const Text('Usar otro correo'))),
        ],
        const SizedBox(height: 28),
        const Center(
            child: Text('Recuperación con Firebase Authentication',
                style: TextStyle(fontSize: 10, color: AppColors.muted))),
      ]));
}

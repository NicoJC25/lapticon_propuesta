import 'package:flutter/material.dart';
import '../widgets/access_components.dart';
import '../widgets/access_shell.dart';
import '../auth/auth_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  void _submit() {
    final auth = AuthScope.of(context);
    if (!auth.canSubmit) return;
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final password = _password.text;
    _password.clear();
    auth.signIn(_email.text, password);
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AccessShell(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AccessHeader(
            eyebrow: 'TU PRÓXIMA CONEXIÓN EMPIEZA AQUÍ',
            title: 'Qué bueno\nverte de nuevo.',
            subtitle: 'Ingresa a tu cuenta y sigue conectando destinos.'),
        Form(
            key: _form,
            child: Column(children: [
              AccessField(
                  label: 'Correo electrónico',
                  hint: 'tu@correo.com',
                  icon: Icons.mail_outline_rounded,
                  controller: _email,
                  validator: Validators.email,
                  enabled: !AuthScope.of(context).busy,
                  email: true),
              AccessField(
                  label: 'Contraseña',
                  hint: 'Escribe tu contraseña',
                  icon: Icons.lock_outline_rounded,
                  controller: _password,
                  validator: Validators.password,
                  enabled: !AuthScope.of(context).busy,
                  password: true,
                  last: true,
                  onSubmitted: _submit),
              Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/recovery'),
                      child: const Text('¿Olvidaste tu contraseña?'))),
              const SizedBox(height: 12),
              PrimaryAction(
                  label: 'Iniciar sesión',
                  busy: AuthScope.of(context).busy,
                  onPressed: AuthScope.of(context).canSubmit ? _submit : null),
            ])),
        const OrDivider(),
        const GoogleAction(),
        const AccessFooter(
            prompt: '¿Primera vez por aquí?',
            action: 'Crea una cuenta',
            route: '/register'),
      ]));
}

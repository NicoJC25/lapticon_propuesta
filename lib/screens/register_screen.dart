import 'package:flutter/material.dart';
import '../widgets/access_components.dart';
import '../widgets/access_shell.dart';
import '../auth/auth_controller.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _surname = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  void _submit() {
    final auth = AuthScope.of(context);
    if (!auth.canSubmit) return;
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final password = _password.text;
    _password.clear();
    _confirmation.clear();
    auth.register(_email.text, password, _name.text, _surname.text);
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _surname,
      _email,
      _password,
      _confirmation
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AccessShell(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AccessHeader(
            eyebrow: 'EL INICIO DE ALGO QUE CONECTA',
            title: 'Acorta distancias.\nCrea tu cuenta.',
            subtitle: 'Un solo lugar para enviar o llevar eso que importa.'),
        Form(
            key: _form,
            child: Column(children: [
              AccessField(
                  label: 'Nombre',
                  enabled: !AuthScope.of(context).busy,
                  hint: 'Tu nombre',
                  icon: Icons.person_outline_rounded,
                  controller: _name,
                  validator: Validators.required),
              AccessField(
                  label: 'Apellido',
                  enabled: !AuthScope.of(context).busy,
                  hint: 'Tu apellido',
                  icon: Icons.person_outline_rounded,
                  controller: _surname,
                  validator: Validators.required),
              AccessField(
                  label: 'Correo electrónico',
                  enabled: !AuthScope.of(context).busy,
                  hint: 'tu@correo.com',
                  icon: Icons.mail_outline_rounded,
                  controller: _email,
                  validator: Validators.email,
                  email: true),
              AccessField(
                  label: 'Contraseña',
                  enabled: !AuthScope.of(context).busy,
                  hint: 'Mínimo 6 caracteres',
                  icon: Icons.lock_outline_rounded,
                  controller: _password,
                  validator: Validators.newPassword,
                  password: true),
              AccessField(
                  label: 'Confirmar contraseña',
                  enabled: !AuthScope.of(context).busy,
                  hint: 'Repite tu contraseña',
                  icon: Icons.lock_outline_rounded,
                  controller: _confirmation,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Confirma tu contraseña.';
                    }
                    return value != _password.text
                        ? 'Las contraseñas no coinciden.'
                        : null;
                  },
                  password: true,
                  last: true,
                  onSubmitted: _submit),
              const SizedBox(height: 6),
              PrimaryAction(
                  label: 'Crear cuenta',
                  busy: AuthScope.of(context).busy,
                  onPressed: AuthScope.of(context).canSubmit ? _submit : null),
            ])),
        const OrDivider(),
        const GoogleAction(),
        const AccessFooter(
            prompt: '¿Ya tienes una cuenta?',
            action: 'Inicia sesión',
            route: '/login'),
      ]));
}

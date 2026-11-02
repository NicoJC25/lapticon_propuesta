import 'package:flutter/material.dart';
import '../auth/auth_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/access_components.dart';
import '../widgets/access_shell.dart';

class SessionScreen extends StatefulWidget {
  const SessionScreen({super.key});
  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _surname = TextEditingController();
  @override
  void dispose() {
    _name.dispose();
    _surname.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final profile = auth.profile;
    return AccessShell(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (auth.phase == SessionPhase.loadingProfile) ...[
        const AccessHeader(
            back: false,
            eyebrow: 'CONEXIÓN SEGURA',
            title: 'Preparando\ntu cuenta.',
            subtitle: 'Estamos consultando tu perfil en Lapticon.'),
        const Center(child: CircularProgressIndicator()),
      ] else if (auth.phase == SessionPhase.profileError) ...[
        const AccessHeader(
            back: false,
            eyebrow: 'SESIÓN INICIADA',
            title: 'Falta conectar\ntu perfil.',
            subtitle:
                'Tu cuenta ya está autenticada. Puedes reintentar sin volver a registrarte.'),
        PrimaryAction(
            label: 'Reintentar perfil',
            onPressed: auth.canSubmit ? auth.retryProfile : null,
            busy: auth.busy),
      ] else if (auth.phase == SessionPhase.needsProfile) ...[
        const AccessHeader(
            back: false,
            eyebrow: 'UN PASO MÁS',
            title: 'Completa\ntu perfil.',
            subtitle:
                'Dinos tu nombre y apellido para terminar de crear tu perfil en Lapticon.'),
        Form(
            key: _form,
            child: Column(children: [
              AccessField(
                  label: 'Nombre',
                  hint: 'Tu nombre',
                  icon: Icons.person_outline_rounded,
                  controller: _name,
                  validator: Validators.required,
                  enabled: !auth.busy),
              AccessField(
                  label: 'Apellido',
                  hint: 'Tu apellido',
                  icon: Icons.person_outline_rounded,
                  controller: _surname,
                  validator: Validators.required,
                  last: true,
                  enabled: !auth.busy),
              PrimaryAction(
                  label: 'Guardar perfil',
                  busy: auth.busy,
                  onPressed: auth.canSubmit
                      ? () {
                          if (_form.currentState!.validate()) {
                            FocusScope.of(context).unfocus();
                            auth.completeProfile(_name.text, _surname.text);
                          }
                        }
                      : null),
            ])),
      ] else ...[
        const Icon(Icons.verified_user_outlined,
            size: 48, color: AppColors.teal),
        const SizedBox(height: 24),
        AccessHeader(
            back: false,
            eyebrow: 'YA ESTÁS EN LAPTICON',
            title: 'Tu sesión\nestá lista.',
            subtitle: profile?.fullName.isNotEmpty == true
                ? 'Hola, ${profile!.fullName}.'
                : 'Bienvenido a Lapticon.'),
        SelectableText(auth.user?.email ?? '',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        const Text(
            'Tu perfil se consultó mediante una petición protegida. Los módulos de envíos y viajes se agregarán en la siguiente etapa.'),
      ],
      const SizedBox(height: 24),
      TextButton.icon(
          onPressed: auth.canSubmit ? auth.signOut : null,
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Cerrar sesión')),
    ]));
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiendaw/features/auth/presentation/session_view_model.dart';

class InvitePasswordPage extends ConsumerStatefulWidget {
  const InvitePasswordPage({super.key});

  @override
  ConsumerState<InvitePasswordPage> createState() => _InvitePasswordPageState();
}

class _InvitePasswordPageState extends ConsumerState<InvitePasswordPage> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionViewModelProvider).valueOrNull;
    final theme = Theme.of(context);
    final errorMessage = session?.errorMessage;
    final inviteEmail = session?.inviteEmail;
    final isBusy = session?.isBusy ?? false;
    final isInviteReady = session?.isInviteSessionReady ?? false;
    final statusMessage = _buildStatusMessage(
      inviteEmail: inviteEmail,
      isInviteReady: isInviteReady,
    );

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Activa tu cuenta',
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Define tu contrasena para terminar de activar la cuenta.',
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 20),
                      if (errorMessage != null && errorMessage.isNotEmpty) ...[
                        _MessageCard(
                          message: errorMessage,
                          background: const Color(0xFFFEF2F2),
                          border: const Color(0xFFFCA5A5),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _MessageCard(
                        message: statusMessage,
                        background: const Color(0xFFF0FDF4),
                        border: const Color(0xFF86EFAC),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Nueva contrasena',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ingresa una contrasena.';
                          }
                          if (value.length < 6) {
                            return 'Usa al menos 6 caracteres.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Confirmar contrasena',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Confirma la contrasena.';
                          }
                          if (value != _passwordController.text) {
                            return 'Las contrasenas no coinciden.';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          // Evitamos enviar la nueva contrasena hasta que
                          // Supabase termine de cargar la sesion del link.
                          onPressed: isBusy || !isInviteReady ? null : _submit,
                          child:
                              isBusy
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Text('Guardar contrasena'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Cuando guardes la contrasena, la app cerrara esa sesion temporal y te devolvera al login normal.',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    await ref
        .read(sessionViewModelProvider.notifier)
        .completeInvitePassword(password: _passwordController.text);
  }

  String _buildStatusMessage({
    required String? inviteEmail,
    required bool isInviteReady,
  }) {
    if (inviteEmail != null && inviteEmail.isNotEmpty) {
      return 'Correo invitado: $inviteEmail';
    }

    if (isInviteReady) {
      return 'Invitacion validada. Ya puedes crear tu contrasena.';
    }

    return 'Validando la invitacion y cargando la sesion segura de Supabase...';
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.message,
    required this.background,
    required this.border,
  });

  final String message;
  final Color background;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Text(message),
    );
  }
}

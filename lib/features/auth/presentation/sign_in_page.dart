import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiendaw/features/auth/presentation/session_view_model.dart';

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key, this.errorMessage});

  final String? errorMessage;

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionViewModelProvider).valueOrNull;
    final errorMessage = session?.errorMessage ?? widget.errorMessage;
    final isBusy = session?.isBusy ?? false;
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
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
                        'Conecta tu sesion',
                        style: theme.textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ingresa con tu usuario de Supabase Auth para cargar categorias, productos, ventas y compras reales.',
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 20),
                      if (errorMessage != null && errorMessage.isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Text(errorMessage),
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(labelText: 'Correo'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Ingresa tu correo.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Contrasena'),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ingresa tu contrasena.';
                          }
                          return null;
                        },
                        onFieldSubmitted: (_) => _submit(),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: isBusy ? null : _submit,
                          child:
                              isBusy
                                  ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                  : const Text('Ingresar con Supabase'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Tip: si el usuario existe en Auth pero aun no tiene perfil, la app creara su fila en public.profiles con el rol seller por defecto.',
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
        .signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
  }
}

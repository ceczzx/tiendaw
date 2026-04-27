import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiendaw/core/theme/system_w_theme.dart';
import 'package:tiendaw/features/auth/presentation/session_view_model.dart';
import 'package:tiendaw/features/auth/presentation/sign_in_page.dart';
import 'package:tiendaw/features/home/presentation/system_w_shell.dart';

class SystemWApp extends StatelessWidget {
  const SystemWApp({super.key, this.bootstrapError});

  final String? bootstrapError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistema W',
      debugShowCheckedModeBanner: false,
      theme: SystemWTheme.light(),
      home:
          bootstrapError == null
              ? const _SessionGate()
              : SetupRequiredPage(message: bootstrapError!),
    );
  }
}

class _SessionGate extends ConsumerWidget {
  const _SessionGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionViewModelProvider);

    return session.when(
      data:
          (state) =>
              state.isAuthenticated
                  ? const SystemWShell()
                  : SignInPage(errorMessage: state.errorMessage),
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error:
          (error, _) => SignInPage(
            errorMessage: 'No se pudo cargar la sesion: $error',
          ),
    );
  }
}

class SetupRequiredPage extends StatelessWidget {
  const SetupRequiredPage({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Configura Supabase', style: theme.textTheme.headlineMedium),
                    const SizedBox(height: 12),
                    Text(message, style: theme.textTheme.bodyLarge),
                    const SizedBox(height: 16),
                    Text(
                      'Archivo esperado:',
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    const SelectableText(
                      'SUPABASE_URL=https://tu-proyecto.supabase.co\nSUPABASE_ANON_KEY=tu_anon_key',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

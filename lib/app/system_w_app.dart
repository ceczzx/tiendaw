import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiendaw/features/auth/presentation/offline_session_page.dart';
import 'package:tiendaw/core/theme/system_w_theme.dart';
import 'package:tiendaw/features/auth/presentation/session_view_model.dart';
import 'package:tiendaw/features/auth/presentation/sign_in_page.dart';
import 'package:tiendaw/features/home/presentation/system_w_shell.dart';

class SystemWApp extends StatelessWidget {
  const SystemWApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sistema W',
      debugShowCheckedModeBanner: false,
      theme: SystemWTheme.light(),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es', 'PE'), Locale('es'), Locale('en')],
      home: const _SessionGate(),
    );
  }
}

class _SessionGate extends ConsumerWidget {
  const _SessionGate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionViewModelProvider);

    return session.when(
      data: (state) {
        if (state.isAuthenticated && state.isOfflineMode) {
          return OfflineSessionPage(state: state);
        }

        return state.isAuthenticated
            ? const SystemWShell()
            : SignInPage(errorMessage: state.errorMessage);
      },
      loading:
          () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
      error:
          (error, _) => const SignInPage(
            errorMessage:
                'No pudimos validar tu sesion en este momento. Revisa tu conexion e intenta nuevamente.',
          ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiendaw/features/auth/domain/app_user.dart';
import 'package:tiendaw/features/auth/presentation/session_view_model.dart';

class OfflineSessionPage extends ConsumerStatefulWidget {
  const OfflineSessionPage({required this.state, super.key});

  final SessionState state;

  @override
  ConsumerState<OfflineSessionPage> createState() => _OfflineSessionPageState();
}

class _OfflineSessionPageState extends ConsumerState<OfflineSessionPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = widget.state.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final email =
        widget.state.authEmail != null && widget.state.authEmail!.trim().isNotEmpty
            ? widget.state.authEmail!.trim()
            : 'Correo no disponible';
    final roleLabel = switch (user.role) {
      UserRole.admin => 'Administrador',
      UserRole.seller => 'Vendedor',
    };

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFBF5), Color(0xFFF4F1EA), Color(0xFFE7ECF2)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _AnimatedW(controller: _controller),
                    const SizedBox(height: 28),
                    Text(
                      'Sin conexion a internet',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: const Color(0xFF0F172A),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Reconocimos tu sesion, pero necesitamos internet para cargar el sistema.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: const Color(0xFF475569),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.82),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFD6D3D1)),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x1A0F172A),
                            blurRadius: 28,
                            offset: Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _IdentityRow(label: 'Rol', value: roleLabel),
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Divider(height: 1),
                          ),
                          _IdentityRow(label: 'Correo', value: email),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFDBA74)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.wifi_off_rounded,
                            color: Color(0xFFC2410C),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              widget.state.infoMessage ??
                                  'No hay conexion disponible en este momento.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF9A3412),
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => ref.invalidate(sessionViewModelProvider),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF0F766E),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Reintentar conexion'),
                      ),
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

class _AnimatedW extends StatelessWidget {
  const _AnimatedW({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 220,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final pulse = Curves.easeInOut.transform(controller.value);
          final ringOpacity = 0.18 + (pulse * 0.14);
          final scale = 0.96 + (pulse * 0.08);

          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: scale * 1.18,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF0F766E).withOpacity(ringOpacity),
                      width: 2,
                    ),
                  ),
                ),
              ),
              Transform.scale(
                scale: scale,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF0F766E), Color(0xFFEA580C)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F766E).withOpacity(0.22),
                        blurRadius: 30,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'W',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 28,
                right: 34,
                child: _SignalDot(
                  size: 14,
                  opacity: 0.3 + (pulse * 0.35),
                ),
              ),
              Positioned(
                bottom: 36,
                left: 30,
                child: _SignalDot(
                  size: 10,
                  opacity: 0.22 + (pulse * 0.28),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SignalDot extends StatelessWidget {
  const _SignalDot({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFFEA580C).withOpacity(opacity),
      ),
    );
  }
}

class _IdentityRow extends StatelessWidget {
  const _IdentityRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF78716C),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              color: const Color(0xFF0F172A),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

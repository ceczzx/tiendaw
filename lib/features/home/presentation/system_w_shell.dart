import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiendaw/core/constants/app_breakpoints.dart';
import 'package:tiendaw/features/auth/domain/app_user.dart';
import 'package:tiendaw/features/auth/presentation/session_view_model.dart';
import 'package:tiendaw/features/dashboard/presentation/admin_desktop_dashboard_page.dart';
import 'package:tiendaw/features/purchases/presentation/admin_mobile_dashboard_page.dart';
import 'package:tiendaw/features/sales/presentation/seller_dashboard_page.dart';
import 'package:tiendaw/shared/widgets/system_w_widgets.dart';

class SystemWShell extends ConsumerStatefulWidget {
  const SystemWShell({super.key});

  @override
  ConsumerState<SystemWShell> createState() => _SystemWShellState();
}

class _SystemWShellState extends ConsumerState<SystemWShell> {
  AdminDesktopSection _adminSection = AdminDesktopSection.sales;

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<SessionState>>(sessionViewModelProvider, (
      previous,
      next,
    ) {
      if (!mounted) {
        return;
      }

      final previousState = previous?.valueOrNull;
      final nextState = next.valueOrNull;

      _showSessionNotice(
        context: context,
        previousMessage: previousState?.errorMessage,
        nextMessage: nextState?.errorMessage,
        backgroundColor: const Color(0xFF991B1B),
      );
      _showSessionNotice(
        context: context,
        previousMessage: previousState?.infoMessage,
        nextMessage: nextState?.infoMessage,
        backgroundColor: const Color(0xFF9A3412),
      );
    });

    final session = ref.watch(sessionViewModelProvider).valueOrNull;
    final user = session?.currentUser;
    final infoMessage = session?.infoMessage;
    final errorMessage = session?.errorMessage;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLaptop = constraints.maxWidth >= AppBreakpoints.laptop;
        final isLaptopAdmin = isLaptop && user.role == UserRole.admin;
        final body = _resolveBody(isLaptop, user.role);

        return Scaffold(
          appBar: AppBar(
            toolbarHeight: isLaptop ? 88 : 72,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sistema W',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  isLaptop ? 'Modo laptop' : 'Modo celular',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
            actions: [
              if (isLaptopAdmin)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Center(
                    child: Wrap(
                      spacing: 10,
                      children: [
                        _HeaderSectionButton(
                          label: 'Ventas',
                          selected: _adminSection == AdminDesktopSection.sales,
                          onPressed:
                              () => setState(
                                () => _adminSection = AdminDesktopSection.sales,
                              ),
                        ),
                        _HeaderSectionButton(
                          label: 'Compras',
                          selected:
                              _adminSection == AdminDesktopSection.purchases,
                          onPressed:
                              () => setState(
                                () =>
                                    _adminSection =
                                        AdminDesktopSection.purchases,
                              ),
                        ),
                        _HeaderSectionButton(
                          label: 'Movimientos',
                          selected:
                              _adminSection == AdminDesktopSection.movements,
                          onPressed:
                              () => setState(
                                () =>
                                    _adminSection =
                                        AdminDesktopSection.movements,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  tooltip: 'Cerrar sesion',
                  onPressed:
                      user == null ? null : () => _confirmSignOut(context, user),
                  icon: const Icon(Icons.logout_rounded),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20, isLaptop ? 8 : 0, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        StatusPill(
                          label: user.name,
                          background: const Color(0xFFFDF2E8),
                          foreground: const Color(0xFF9A3412),
                        ),
                        StatusPill(
                          label:
                              user.role == UserRole.admin
                                  ? 'Rol: admin'
                                  : 'Rol: vendedor',
                          background: const Color(0xFFECFDF5),
                          foreground: const Color(0xFF047857),
                        ),
                        StatusPill(
                          label:
                              infoMessage == null || infoMessage.isEmpty
                                  ? 'Supabase conectado'
                                  : 'Modo sin conexion',
                          background:
                              infoMessage == null || infoMessage.isEmpty
                                  ? const Color(0xFFEFF6FF)
                                  : const Color(0xFFFFF7ED),
                          foreground:
                              infoMessage == null || infoMessage.isEmpty
                                  ? const Color(0xFF1D4ED8)
                                  : const Color(0xFF9A3412),
                        ),
                      ],
                    ),
                    if (infoMessage != null && infoMessage.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _SessionNoticeCard(
                        message: infoMessage,
                        background: const Color(0xFFFFF7ED),
                        border: const Color(0xFFFDBA74),
                        foreground: const Color(0xFF9A3412),
                        icon: Icons.wifi_off_rounded,
                      ),
                    ],
                    if (errorMessage != null && errorMessage.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _SessionNoticeCard(
                        message: errorMessage,
                        background: const Color(0xFFFEF2F2),
                        border: const Color(0xFFFCA5A5),
                        foreground: const Color(0xFF991B1B),
                        icon: Icons.warning_amber_rounded,
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: body,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _resolveBody(bool isLaptop, UserRole role) {
    if (isLaptop && role == UserRole.admin) {
      return AdminDesktopDashboardPage(activeSection: _adminSection);
    }

    if (isLaptop && role == UserRole.seller) {
      return const _LaptopAdminOnlyState();
    }

    if (role == UserRole.seller) {
      return const SellerDashboardPage();
    }

    return const AdminMobileDashboardPage();
  }

  void _showSessionNotice({
    required BuildContext context,
    required String? previousMessage,
    required String? nextMessage,
    required Color backgroundColor,
  }) {
    if (nextMessage == null ||
        nextMessage.isEmpty ||
        nextMessage == previousMessage) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final messenger = ScaffoldMessenger.of(context);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(nextMessage),
            backgroundColor: backgroundColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
    });
  }

  Future<void> _confirmSignOut(BuildContext context, AppUser user) async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => _SignOutDialog(user: user),
    );

    if (shouldSignOut != true || !mounted) {
      return;
    }

    await ref.read(sessionViewModelProvider.notifier).signOut();
  }
}

class _SessionNoticeCard extends StatelessWidget {
  const _SessionNoticeCard({
    required this.message,
    required this.background,
    required this.border,
    required this.foreground,
    required this.icon,
  });

  final String message;
  final Color background;
  final Color border;
  final Color foreground;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignOutDialog extends StatelessWidget {
  const _SignOutDialog({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final isSeller = user.role == UserRole.seller;
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Cerrar sesion'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isSeller
                ? '¿Seguro que quieres cerrar sesion ahora?'
                : '¿Seguro que quieres cerrar sesion y volver al login?',
          ),
          if (isSeller) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFF59E0B), width: 1.4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Color(0xFFC2410C),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'NO TE OLVIDES CERRAR LA CAJA',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF9A3412),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Antes de salir, confirma que tu turno y tu caja ya quedaron cerrados correctamente.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF9A3412),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Cerrar sesion'),
        ),
      ],
    );
  }
}

class _HeaderSectionButton extends StatelessWidget {
  const _HeaderSectionButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final style =
        selected
            ? FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            )
            : OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0F172A),
              side: const BorderSide(color: Color(0xFFD6D3D1)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            );

    final child = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);

    if (selected) {
      return FilledButton(onPressed: onPressed, style: style, child: child);
    }

    return OutlinedButton(onPressed: onPressed, style: style, child: child);
  }
}

class _LaptopAdminOnlyState extends StatelessWidget {
  const _LaptopAdminOnlyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SectionCard(
            title: 'Acceso restringido',
            subtitle:
                'En laptop el dashboard esta reservado para administracion.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Para vendedores se mantiene el flujo optimizado en celular. Inicia sesion con un perfil admin para ver tablas, KPIs y alertas.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

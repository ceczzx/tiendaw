import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiendaw/core/constants/app_breakpoints.dart';
import 'package:tiendaw/core/utils/formatters.dart';
import 'package:tiendaw/features/auth/domain/app_user.dart';
import 'package:tiendaw/features/auth/presentation/session_view_model.dart';
import 'package:tiendaw/features/dashboard/presentation/admin_desktop_dashboard_page.dart';
import 'package:tiendaw/features/purchases/presentation/admin_mobile_dashboard_page.dart';
import 'package:tiendaw/features/purchases/presentation/admin_mobile_dashboard_view_model.dart';
import 'package:tiendaw/features/sales/domain/sales_entities.dart';
import 'package:tiendaw/features/sales/presentation/seller_dashboard_page.dart';
import 'package:tiendaw/features/sales/presentation/seller_dashboard_view_model.dart';
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
        final isTablet =
            constraints.maxWidth >= AppBreakpoints.tablet &&
            constraints.maxWidth < AppBreakpoints.laptop;
        final isWideScreen = isLaptop || isTablet;
        final isWideAdmin = isWideScreen && user.role == UserRole.admin;
        final modeLabel =
            isLaptop
                ? 'Modo laptop'
                : isTablet
                ? 'Modo tablet'
                : 'Modo celular';
        final body = _resolveBody(isWideScreen, user.role);

        return Scaffold(
          appBar: AppBar(
            toolbarHeight: isWideScreen ? 88 : 72,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sistema W',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(modeLabel, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            actions: [
              if (isWideAdmin)
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
                          label: 'Productos',
                          selected:
                              _adminSection == AdminDesktopSection.products,
                          onPressed:
                              () => setState(
                                () =>
                                    _adminSection =
                                        AdminDesktopSection.products,
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
                        _HeaderSectionButton(
                          label: 'Operaciones',
                          selected:
                              _adminSection == AdminDesktopSection.operations,
                          onPressed:
                              () => setState(
                                () =>
                                    _adminSection =
                                        AdminDesktopSection.operations,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (user.role == UserRole.admin &&
                  (!isWideScreen ||
                      _adminSection == AdminDesktopSection.operations))
                _AdminMobileShiftNotificationsButton(currentUser: user),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  tooltip: 'Cerrar sesion',
                  onPressed:
                      // ignore: unnecessary_null_comparison
                      user == null
                          ? null
                          : () => _confirmSignOut(context, user),
                  icon: const Icon(Icons.logout_rounded),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(20, isWideScreen ? 8 : 0, 20, 12),
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
                                  ? 'Conectado a DB'
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

  Widget _resolveBody(bool isWideScreen, UserRole role) {
    if (isWideScreen && role == UserRole.admin) {
      return AdminDesktopDashboardPage(activeSection: _adminSection);
    }

    if (isWideScreen && role == UserRole.seller) {
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
    final showCashWarning =
        user.role == UserRole.seller
            ? (ref
                    .read(sellerDashboardViewModelProvider)
                    .valueOrNull
                    ?.hasOpenShift ??
                true)
            : false;
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder:
          (context) =>
              _SignOutDialog(user: user, showCashWarning: showCashWarning),
    );

    if (shouldSignOut != true || !mounted) {
      return;
    }

    await ref.read(sessionViewModelProvider.notifier).signOut();
  }
}

class _AdminMobileShiftNotificationsButton extends ConsumerStatefulWidget {
  const _AdminMobileShiftNotificationsButton({required this.currentUser});

  final AppUser currentUser;

  @override
  ConsumerState<_AdminMobileShiftNotificationsButton> createState() =>
      _AdminMobileShiftNotificationsButtonState();
}

class _AdminMobileShiftNotificationsButtonState
    extends ConsumerState<_AdminMobileShiftNotificationsButton> {
  final MenuController _menuController = MenuController();
  bool _isBusy = false;

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(adminMobileDashboardViewModelProvider);
    final allPending =
        dashboard.valueOrNull?.pendingShiftApprovals ?? const <CashShift>[];
    final visiblePending = _visibleSpecialShiftRequests(allPending);
    if (visiblePending.isEmpty) {
      return const SizedBox.shrink();
    }

    final latest = visiblePending.take(5).toList();
    return Padding(
      padding: const EdgeInsets.only(right: 2),
      child: MenuAnchor(
        controller: _menuController,
        alignmentOffset: const Offset(-300, 8),
        menuChildren: [
          SizedBox(
            width: 340,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Permisos especiales',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Ultimas solicitudes pendientes',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  for (final shift in latest) ...[
                    _ShiftRequestMenuCard(
                      shift: shift,
                      isBusy: _isBusy,
                      onApprove: () => _approve(shift),
                      onReject: () => _reject(context, shift),
                    ),
                    if (shift != latest.last) const SizedBox(height: 10),
                  ],
                ],
              ),
            ),
          ),
        ],
        builder: (context, controller, child) {
          return Badge(
            label: Text('${visiblePending.length}'),
            child: IconButton(
              tooltip: 'Permisos especiales pendientes',
              onPressed: () {
                if (controller.isOpen) {
                  controller.close();
                } else {
                  controller.open();
                }
              },
              icon: const Icon(Icons.notifications_active_rounded),
            ),
          );
        },
      ),
    );
  }

  List<CashShift> _visibleSpecialShiftRequests(List<CashShift> shifts) {
    final filtered = [...shifts]
      ..sort((a, b) => b.openedAt.compareTo(a.openedAt));
    return filtered;
  }

  Future<void> _approve(CashShift shift) async {
    if (_isBusy) {
      return;
    }

    setState(() => _isBusy = true);
    try {
      final success = await ref
          .read(adminMobileDashboardViewModelProvider.notifier)
          .approveShiftRequest(
            shiftId: shift.id,
            adminId: widget.currentUser.id,
          );
      if (success) {
        _menuController.close();
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<void> _reject(BuildContext context, CashShift shift) async {
    if (_isBusy) {
      return;
    }

    final reason = await _promptRejectionReason(context);
    if (reason == null || reason.trim().isEmpty || !mounted) {
      return;
    }

    setState(() => _isBusy = true);
    try {
      final success = await ref
          .read(adminMobileDashboardViewModelProvider.notifier)
          .rejectShiftRequest(
            shiftId: shift.id,
            adminId: widget.currentUser.id,
            rejectionReason: reason,
          );
      if (success) {
        _menuController.close();
      }
    } finally {
      if (mounted) {
        setState(() => _isBusy = false);
      }
    }
  }

  Future<String?> _promptRejectionReason(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Rechazar permiso'),
            content: TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Mensaje para el vendedor',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed:
                    () => Navigator.of(context).pop(controller.text.trim()),
                child: const Text('Enviar'),
              ),
            ],
          ),
    );
  }
}

class _ShiftRequestMenuCard extends StatelessWidget {
  const _ShiftRequestMenuCard({
    required this.shift,
    required this.isBusy,
    required this.onApprove,
    required this.onReject,
  });

  final CashShift shift;
  final bool isBusy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              shift.sellerName ?? 'Vendedor',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              SystemWFormatters.shortDateTime.format(shift.openedAt),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 6),
            Text(
              'Inicial ${SystemWFormatters.currency.format(shift.openingAmount)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: isBusy ? null : onApprove,
                    child: const Text('Aceptar'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: isBusy ? null : onReject,
                    child: const Text('No'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
  const _SignOutDialog({required this.user, required this.showCashWarning});

  final AppUser user;
  final bool showCashWarning;

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
          if (isSeller && showCashWarning) ...[
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
                'En laptop o tablet el dashboard esta reservado para administracion.',
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

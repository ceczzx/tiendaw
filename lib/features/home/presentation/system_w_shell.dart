import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiendaw/core/constants/app_breakpoints.dart';
import 'package:tiendaw/features/auth/domain/app_user.dart';
import 'package:tiendaw/features/auth/presentation/session_view_model.dart';
import 'package:tiendaw/features/dashboard/presentation/admin_desktop_dashboard_page.dart';
import 'package:tiendaw/features/purchases/presentation/admin_mobile_dashboard_page.dart';
import 'package:tiendaw/features/sales/presentation/seller_dashboard_page.dart';
import 'package:tiendaw/shared/widgets/system_w_widgets.dart';

class SystemWShell extends ConsumerWidget {
  const SystemWShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionViewModelProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLaptop = constraints.maxWidth >= AppBreakpoints.laptop;
        final body = _resolveBody(isLaptop, session.currentUser.role);

        return Scaffold(
          appBar: AppBar(
            toolbarHeight: isLaptop ? 88 : 110,
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
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Row(
                  children: [
                    StatusPill(
                      label:
                          session.isOnline
                              ? 'Online - ${session.pendingSyncCount} pendientes'
                              : 'Offline - ${session.pendingSyncCount} pendientes',
                      background:
                          session.isOnline
                              ? const Color(0xFFECFDF5)
                              : const Color(0xFFFEF2F2),
                      foreground:
                          session.isOnline
                              ? const Color(0xFF047857)
                              : const Color(0xFFB91C1C),
                    ),
                    const SizedBox(width: 12),
                    Switch(
                      value: session.isOnline,
                      onChanged: (value) {
                        ref
                            .read(sessionViewModelProvider.notifier)
                            .toggleOnline(value);
                      },
                    ),
                    const SizedBox(width: 12),
                    SegmentedButton<UserRole>(
                      segments: const [
                        ButtonSegment(
                          value: UserRole.admin,
                          label: Text('Admin'),
                          icon: Icon(Icons.admin_panel_settings_outlined),
                        ),
                        ButtonSegment(
                          value: UserRole.seller,
                          label: Text('Vendedor'),
                          icon: Icon(Icons.point_of_sale_rounded),
                        ),
                      ],
                      selected: {session.currentUser.role},
                      onSelectionChanged:
                          (selection) => ref
                              .read(sessionViewModelProvider.notifier)
                              .switchRole(selection.first),
                    ),
                  ],
                ),
              ),
            ],
          ),
          body: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: body,
          ),
        );
      },
    );
  }

  Widget _resolveBody(bool isLaptop, UserRole role) {
    if (isLaptop && role == UserRole.admin) {
      return const AdminDesktopDashboardPage();
    }

    if (isLaptop && role == UserRole.seller) {
      return const _LaptopAdminOnlyState();
    }

    if (role == UserRole.seller) {
      return const SellerDashboardPage();
    }

    return const AdminMobileDashboardPage();
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
                  'Para vendedores se mantiene el flujo optimizado en celular. Cambia el rol a Admin para ver tablas, KPIs y alertas.',
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

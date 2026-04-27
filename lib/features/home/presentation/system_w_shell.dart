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
    final session = ref.watch(sessionViewModelProvider).valueOrNull;
    final user = session?.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isLaptop = constraints.maxWidth >= AppBreakpoints.laptop;
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
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  tooltip: 'Cerrar sesion',
                  onPressed: () {
                    ref.read(sessionViewModelProvider.notifier).signOut();
                  },
                  icon: const Icon(Icons.logout_rounded),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  isLaptop ? 8 : 0,
                  20,
                  12,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Wrap(
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
                      const StatusPill(
                        label: 'Supabase conectado',
                        background: Color(0xFFEFF6FF),
                        foreground: Color(0xFF1D4ED8),
                      ),
                    ],
                  ),
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

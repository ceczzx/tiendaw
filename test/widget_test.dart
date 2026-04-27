import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiendaw/app/system_w_app.dart';

void main() {
  testWidgets('Sistema W muestra la pantalla de configuracion', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: SystemWApp(
          bootstrapError: 'Completa SUPABASE_URL y SUPABASE_ANON_KEY.',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Configura Supabase'), findsOneWidget);
    expect(find.textContaining('SUPABASE_URL'), findsWidgets);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tiendaw/app/system_w_app.dart';

void main() {
  testWidgets('Sistema W renders main shell', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SystemWApp()));
    await tester.pumpAndSettle();

    expect(find.text('Sistema W'), findsOneWidget);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kpss/main.dart';

void main() {
  testWidgets('App initializes smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: KaeruKpssApp()));
    expect(find.byType(KaeruKpssApp), findsOneWidget);
  });
}

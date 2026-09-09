import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ahmad_pharmacy_pos/main.dart';

void main() {
  testWidgets('App load test', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: AhmadPharmacyApp()));
    expect(find.byType(AhmadPharmacyApp), findsOneWidget);
  });
}

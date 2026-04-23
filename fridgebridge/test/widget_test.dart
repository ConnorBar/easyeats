import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fridgebridge/main.dart';

void main() {
  testWidgets('App renders bottom navigation', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: FridgeBridgeApp()),
    );
    expect(find.text('Inventory'), findsOneWidget);
    expect(find.text('Recipes'), findsOneWidget);
    expect(find.text('Report'), findsOneWidget);
  });
}

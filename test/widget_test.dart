import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:grocery_price_tracker/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: GroceryTrackerApp(),
      ),
    );

    // Verify the app title is displayed
    expect(find.text('Price Tracker'), findsOneWidget);
  });
}

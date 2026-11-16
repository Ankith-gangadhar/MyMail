import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:my_mail/main.dart';

void main() {
  testWidgets('MyMailApp launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MyMailApp(),
      ),
    );

    // Initial frame check
    expect(find.byType(MyMailApp), findsOneWidget);
  });
}

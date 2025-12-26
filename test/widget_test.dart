import 'package:flutter_test/flutter_test.dart';

import 'package:save_smart_app/main.dart';

void main() {
  testWidgets('App shows SaveSmart text', (WidgetTester tester) async {
    await tester.pumpWidget(const SaveSmartApp());

    expect(find.text('SaveSmart'), findsOneWidget);
  });
}

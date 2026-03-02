import 'package:flutter_test/flutter_test.dart';

import 'package:screen_translator/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ScreenTranslatorApp());
    expect(find.text('Screen Translator'), findsOneWidget);
  });
}

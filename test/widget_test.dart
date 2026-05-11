import 'package:flutter_test/flutter_test.dart';

import 'package:worker_manager/main.dart';

void main() {
  testWidgets('App launches with splash screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('LINKER'), findsOneWidget);
    expect(find.text('SYSTEM INITIALIZING'), findsOneWidget);
  });
}

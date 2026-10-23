import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:kodoo_todo/main.dart';

void main() {
  testWidgets('MyApp builds', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();
    expect(find.byType(GetMaterialApp), findsOneWidget);
  });
}

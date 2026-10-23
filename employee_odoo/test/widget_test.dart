import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:employee_odoo/modules/auth/bindings/auth_binding.dart';
import 'package:employee_odoo/modules/auth/controllers/auth_controller.dart';
import 'package:employee_odoo/modules/auth/views/login_view.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    Get.put<AuthController>(AuthController());
    AuthBinding().dependencies();
  });

  tearDown(Get.reset);

  testWidgets('Two-step login screen shows server config', (tester) async {
    await tester.pumpWidget(
      const GetMaterialApp(home: LoginView()),
    );
    await tester.pump();

    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Configure Your Server Connection'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });
}

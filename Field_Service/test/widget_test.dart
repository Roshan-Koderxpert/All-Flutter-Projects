import 'package:field_service/app.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    const pathProviderChannel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(pathProviderChannel, (call) async {
      return '.';
    });
    await GetStorage.init();
  });

  tearDown(Get.reset);

  testWidgets('FSMApp builds with splash as initial route', (WidgetTester tester) async {
    await tester.pumpWidget(
      const FSMApp(
        languageCode: 'en_US',
        initialThemeMode: 'light',
      ),
    );
    await tester.pump();
    expect(find.byType(GetMaterialApp), findsOneWidget);
    // Splash waits for video end or max timeout (see SplashView._maxSplashDuration).
    await tester.pump(const Duration(seconds: 31));
  });
}

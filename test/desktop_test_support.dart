import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void initializeDesktopWidgetTests() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  // Widget tests have no AppKit host. Native integration tests use the real plugin.
  if (binding is AutomatedTestWidgetsFlutterBinding) {
    setUp(() {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
    });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('appkit_ui_element_colors'),
          (call) async => switch (call.method) {
            'getColorComponents' => <String, double>{'hueComponent': 0.0},
            'getColor' => 0xffbcbcbc,
            _ => throw MissingPluginException(call.method),
          },
        );
  }
}

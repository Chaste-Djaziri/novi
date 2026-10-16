import 'package:novi/main.dart';
import 'package:novi/tablet_connection.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void initializeDesktopWidgetTests() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  // Widget tests have no AppKit host. Native integration tests use the real plugin.
  if (binding is AutomatedTestWidgetsFlutterBinding) {
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

void setTabletHardware(WidgetTester tester, List<String> devices) {
  final dynamic workspace = tester.state(find.byType(Workspace));
  (workspace.tablets as TabletConnection).apply({
    'available': true,
    'devices': devices,
  });
}

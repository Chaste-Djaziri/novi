import 'package:flutter_test/flutter_test.dart';
import 'package:novi/tablet_connection.dart';

import '../test/notebook_controls_test.dart' as control_tests;

import 'package:integration_test/integration_test.dart';

import '../test/widget_test.dart' as notebook_tests;
import '../test/workspace_test.dart' as workspace_tests;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Drive the native Flutter editor deterministically; avoid racing the OS IME
  // against synthetic tester.enterText messages. Native file/tablet plugins remain real.
  setUp(() => binding.testTextInput.register());
  tearDown(() => binding.testTextInput.unregister());
  test(
    'native tablet monitor exposes initial connection and event snapshots',
    () async {
      final state = await TabletConnection.methods
          .invokeMethod<Map<dynamic, dynamic>>('getState');
      expect(state, isNotNull);
      expect(state!['available'], isA<bool>());
      expect(state['devices'], isA<List>());
      final initialEvent = await TabletConnection.events
          .receiveBroadcastStream()
          .first
          .timeout(const Duration(seconds: 5));
      expect(initialEvent, isA<Map>());
      expect((initialEvent as Map)['devices'], isA<List>());
    },
  );
  notebook_tests.main();
  workspace_tests.main();
  control_tests.main();
}

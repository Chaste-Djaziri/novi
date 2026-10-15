import 'package:integration_test/integration_test.dart';

import '../test/widget_test.dart' as notebook_tests;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  notebook_tests.main();
}

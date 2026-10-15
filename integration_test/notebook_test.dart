import 'package:integration_test/integration_test.dart';

import '../test/widget_test.dart' as notebook_tests;
import '../test/workspace_test.dart' as workspace_tests;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  notebook_tests.main();
  workspace_tests.main();
}

import 'dart:io';

const softCeiling = 500;
const excludedDirectories = {'build', '.dart_tool', 'macos', 'windows', 'linux'};

void main() {
  final root = Directory.current;
  final warnings = <String>[];
  for (final entity in root.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final relative = entity.path.substring(root.path.length + 1);
    if (relative.split(Platform.pathSeparator).any(excludedDirectories.contains)) continue;
    final lines = entity.readAsLinesSync().length;
    if (lines > softCeiling) warnings.add('$relative: $lines lines (soft ceiling $softCeiling)');
  }
  if (warnings.isEmpty) {
    stdout.writeln('No Dart files exceed the $softCeiling-line soft ceiling.');
    return;
  }
  stdout.writeln('Dart file length warnings (existing files are non-blocking):');
  for (final warning in warnings..sort()) stdout.writeln('  $warning');
  exitCode = 0;
}

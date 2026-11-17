import 'dart:io';

/// The source of `AppStrings`, which is split across `app_strings.dart` and its
/// `app_strings_*.dart` parts (getters by area, plus the EN and AR tables).
///
/// Tests that read the copy as text read it through here so they keep seeing
/// the whole thing however it is divided.
String appStringsSource() {
  final dir = Directory('lib/core/i18n');
  final files = dir.listSync().whereType<File>().where((f) {
    final name = f.uri.pathSegments.last;
    return name == 'app_strings.dart' ||
        (name.startsWith('app_strings_') && name.endsWith('.dart'));
  }).toList()..sort((a, b) => a.path.compareTo(b.path));
  return files.map((f) => f.readAsStringSync()).join('\n');
}

import 'dart:convert';
import 'dart:io';

Map<String, dynamic> readConcordFixture(String name) {
  var directory = Directory.current;
  for (var depth = 0; depth < 8; depth++) {
    for (final relative in [
      'test/fixtures/$name',
      '../concord_protocol/test/fixtures/$name',
      'packages/concord_protocol/test/fixtures/$name',
      'mobile/packages/concord_protocol/test/fixtures/$name',
    ]) {
      final file = File('${directory.path}/$relative');
      if (file.existsSync()) {
        return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
      }
    }
    final parent = directory.parent;
    if (parent.path == directory.path) break;
    directory = parent;
  }
  throw StateError('Concord test fixture $name was not found');
}

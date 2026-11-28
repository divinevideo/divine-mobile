import 'dart:convert';
import 'dart:io';

/// Resolves synthetic package fixtures independently of the test runner's cwd.
Future<File> fixtureFile(String name) async => File.fromUri(
  (await _packageDirectory('divine_camera')).uri.resolve('test/fixtures/$name'),
);

Future<Directory> _packageDirectory(String name) async {
  var directory = Directory.current;
  while (!File(
    '${directory.path}/.dart_tool/package_config.json',
  ).existsSync()) {
    if (directory.parent.path == directory.path) {
      throw StateError('Test package configuration not found.');
    }
    directory = directory.parent;
  }
  final config = File('${directory.path}/.dart_tool/package_config.json');
  final json = jsonDecode(await config.readAsString()) as Map<String, dynamic>;
  final package = (json['packages'] as List<dynamic>)
      .cast<Map<String, dynamic>>()
      .singleWhere((package) => package['name'] == name);
  return Directory.fromUri(config.uri.resolve(package['rootUri'] as String));
}

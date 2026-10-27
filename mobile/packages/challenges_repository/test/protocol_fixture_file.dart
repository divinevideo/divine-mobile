import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

final Uri _fixtureDirectory = _resolveFixtureDirectory();

Uri _resolveFixtureDirectory() {
  // Flutter's test VM supplies --packages but omits isolate package resolution.
  final option = Platform.executableArguments
      .where((arg) => arg.startsWith('--packages='))
      .firstOrNull;
  if (option != null) {
    final configFile = File(option.substring('--packages='.length)).absolute;
    final config =
        jsonDecode(configFile.readAsStringSync()) as Map<String, Object?>;
    final package = (config['packages']! as List<Object?>)
        .cast<Map<String, Object?>>()
        .singleWhere((item) => item['name'] == 'challenge_protocol');
    final root = Directory.fromUri(
      configFile.uri.resolve(package['rootUri']! as String),
    );
    return root.uri.resolve('test/fixtures/');
  }
  final library = Isolate.resolvePackageUriSync(
    Uri.parse('package:challenge_protocol/challenge_protocol.dart'),
  );
  if (library == null || library.scheme != 'file') {
    throw StateError('Cannot resolve challenge_protocol test fixtures');
  }
  return library.resolve('../test/fixtures/');
}

// Resolve from the runner's package mapping, never its working directory.
File fixtureFile(String relativePath) =>
    File.fromUri(_fixtureDirectory.resolve(relativePath));

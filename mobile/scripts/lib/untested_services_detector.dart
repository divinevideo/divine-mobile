// ABOUTME: Finds services without an exact-name or directly importing split test.
// ABOUTME: Keeps the untested-services ratchet honest for aspect-based suites.

import 'dart:io';

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln(
      'usage: untested_services_detector.dart <services-dir> <test-dir>',
    );
    exitCode = 2;
    return;
  }

  final servicesDirectory = Directory(args[0]);
  final testDirectory = Directory(args[1]);
  if (!servicesDirectory.existsSync() || !testDirectory.existsSync()) {
    stderr.writeln('service and test directories must exist');
    exitCode = 2;
    return;
  }

  findUntestedServices(
    servicesDirectory,
    testDirectory,
  ).forEach(stdout.writeln);
}

List<String> findUntestedServices(
  Directory servicesDirectory,
  Directory testDirectory,
) {
  final services = servicesDirectory
      .listSync(recursive: true)
      .whereType<File>()
      .where(
        (file) =>
            file.path.endsWith('.dart') &&
            !file.path.endsWith('.g.dart') &&
            !file.path.endsWith('.freezed.dart'),
      )
      .map((file) => _basenameWithoutSuffix(file.path, '.dart'))
      .toSet();
  final testFiles = testDirectory
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('_test.dart'))
      .toList();

  final tested = <String>{};
  for (final file in testFiles) {
    final testName = _basenameWithoutSuffix(file.path, '_test.dart');
    if (services.contains(testName)) {
      tested.add(testName);
    }

    final splitCandidates = services.where(
      (service) => testName.startsWith('${service}_'),
    );
    if (splitCandidates.isEmpty) continue;

    final source = file.readAsStringSync();
    for (final service in splitCandidates) {
      final serviceImport = RegExp(
        "import ['\"][^'\"]*/services/(?:[^'\"]*/)?$service\\.dart['\"]",
      );
      if (serviceImport.hasMatch(source)) tested.add(service);
    }
  }

  return services.difference(tested).toList()..sort();
}

String _basenameWithoutSuffix(String path, String suffix) {
  final basename = path.split(Platform.pathSeparator).last;
  return basename.substring(0, basename.length - suffix.length);
}

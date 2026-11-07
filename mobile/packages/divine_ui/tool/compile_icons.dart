// ABOUTME: Compiles the app's SVG icon sources into packaged vector assets.
// ABOUTME: Run `dart run tool/compile_icons.dart` from this package after editing icons.

import 'dart:io';

import 'package:vector_graphics_compiler/vector_graphics_compiler.dart';

/// Regenerates the binary artwork without changing the source SVG assets.
Future<void> main() async {
  final packageRoot = File.fromUri(Platform.script).parent.parent;
  final source = Directory.fromUri(
    packageRoot.uri.resolve('../../assets/icon/'),
  );
  final destination = Directory.fromUri(
    packageRoot.uri.resolve('assets/icons/'),
  );
  final icons =
      source
          .listSync()
          .whereType<File>()
          .where(
            (file) => file.path.endsWith('.svg'),
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  // Compile everything before replacing any output, so a bad source cannot
  // leave a partially regenerated icon set behind.
  final compiled = <String, List<int>>{};
  for (final icon in icons) {
    final name = icon.uri.pathSegments.last.replaceFirst(RegExp(r'\.svg$'), '');
    compiled['$name.vec'] = encodeSvg(
      xml: await icon.readAsString(),
      debugName: 'Svg loader',
      // Match flutter_svg's runtime compiler to preserve existing artwork.
      enableClippingOptimizer: false,
      enableMaskingOptimizer: false,
      enableOverdrawOptimizer: false,
    );
  }

  await destination.create(recursive: true);
  for (final output in compiled.entries) {
    await File.fromUri(
      destination.uri.resolveUri(Uri(path: output.key)),
    ).writeAsBytes(output.value);
  }
  for (final file in destination.listSync().whereType<File>()) {
    if (file.path.endsWith('.vec') &&
        !compiled.containsKey(file.uri.pathSegments.last)) {
      await file.delete();
    }
  }
  stdout.writeln('Compiled ${compiled.length} icon assets.');
}

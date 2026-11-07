import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_graphics/vector_graphics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every design-system icon decodes from the package bundle', () async {
    for (final icon in DivineIconName.values) {
      final picture = await vg.loadPicture(
        AssetBytesLoader(icon.vectorAssetPath, packageName: 'divine_ui'),
        null,
      );
      expect(picture.size.isEmpty, isFalse, reason: icon.name);
      picture.picture.dispose();
    }
  });

  test('compiled artwork exactly matches the runtime SVG compiler', () async {
    final sources = Directory('../../assets/icon')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('.svg'))
        .toList();
    final expectedAssets = <String>[];
    for (final source in sources) {
      final name = source.uri.pathSegments.last.replaceFirst(
        RegExp(r'\.svg$'),
        '.vec',
      );
      final asset = 'packages/divine_ui/assets/icons/$name';
      // A package's own manifest uses unprefixed keys when tested directly.
      expectedAssets.add('assets/icons/$name');
      final compiled = await rootBundle.load(asset);
      final reference = await SvgStringLoader(
        await source.readAsString(),
      ).loadBytes(null);
      expect(
        compiled.buffer.asUint8List(
          compiled.offsetInBytes,
          compiled.lengthInBytes,
        ),
        orderedEquals(
          reference.buffer.asUint8List(
            reference.offsetInBytes,
            reference.lengthInBytes,
          ),
        ),
        reason: '${source.path}: run dart run tool/compile_icons.dart',
      );
    }
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    expect(
      manifest.listAssets().where(
        (asset) => asset.startsWith('assets/icons/'),
      ),
      unorderedEquals(expectedAssets),
      reason: 'Regenerate icons after adding or removing an SVG source.',
    );
  });
}

import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vector_graphics/vector_graphics.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Compiled icon assets', () {
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
      // flutter test can be invoked from either the app or this package.
      var workspace = Directory.current.absolute;
      while (!Directory.fromUri(
        workspace.uri.resolve('assets/icon/'),
      ).existsSync()) {
        expect(
          workspace.parent.path,
          isNot(workspace.path),
          reason: 'Run icon tests from within the mobile workspace.',
        );
        workspace = workspace.parent;
      }
      final sources =
          Directory.fromUri(
                workspace.uri.resolve('assets/icon/'),
              )
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
        // Direct package tests and app tests use different manifest prefixes.
        manifest
            .listAssets()
            .map(
              (asset) => asset.replaceFirst(RegExp('^packages/divine_ui/'), ''),
            )
            .where((asset) => asset.startsWith('assets/icons/'))
            .toSet(),
        unorderedEquals(expectedAssets),
        reason: 'Regenerate icons after adding or removing an SVG source.',
      );
    });
  });
}

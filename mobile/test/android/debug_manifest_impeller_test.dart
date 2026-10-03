// ABOUTME: Pins the debug manifest to the engine's default renderer.
// ABOUTME: An EnableImpeller entry there would put every debug build on Skia.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

const _androidNamespace = 'http://schemas.android.com/apk/res/android';
const _enableImpellerKey = 'io.flutter.embedding.android.EnableImpeller';

void main() {
  group('debug manifest renderer', () {
    test('declares no EnableImpeller entry', () {
      final manifest = File('android/app/src/debug/AndroidManifest.xml')
          .readAsStringSync();

      expect(
        _declaresEnableImpeller(manifest),
        isFalse,
        reason:
            'Debug builds render with the engine default, like release. To '
            'turn Impeller off for one run, use the per-run switches in '
            'docs/ANDROID_LOCAL_SETUP.md instead of committing an entry.',
      );
    });

    test('recognises an EnableImpeller entry whatever its value', () {
      expect(_declaresEnableImpeller(_manifestWithEntry('false')), isTrue);
      expect(_declaresEnableImpeller(_manifestWithEntry('true')), isTrue);
    });

    test('ignores other application metadata', () {
      expect(_declaresEnableImpeller(_manifestWithOtherEntry), isFalse);
    });
  });
}

bool _declaresEnableImpeller(String source) {
  final document = XmlDocument.parse(source);
  return document.rootElement.childElements
      .where((element) => element.name.local == 'application')
      .expand((application) => application.childElements)
      .where((element) => element.name.local == 'meta-data')
      .any(
        (metaData) =>
            metaData.getAttribute('name', namespace: _androidNamespace) ==
            _enableImpellerKey,
      );
}

String _manifestWithEntry(String value) =>
    '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <application>
    <meta-data
      android:name="$_enableImpellerKey"
      android:value="$value" />
  </application>
</manifest>
''';

const _manifestWithOtherEntry = '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
  <application>
    <meta-data
      android:name="firebase_performance_collection_deactivated"
      android:value="true" />
  </application>
</manifest>
''';

// ABOUTME: Keeps files that need an Android Keystore key out of backups and
// ABOUTME: device transfers, so a restore cannot bring them back without it.

import 'dart:io';

// The package barrel exports this native-only helper conditionally, and the
// analyzer resolves that export to the stub, which does not declare it.
import 'package:db_client/src/database/connection/connection_native.dart'
    show buildSharedDatabasePath;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:xml/xml.dart';

const _androidNamespace = 'http://schemas.android.com/apk/res/android';
const _toolsNamespace = 'http://schemas.android.com/tools';

const _mainManifestPath = 'android/app/src/main/AndroidManifest.xml';
const _buildTypeManifestPaths = [
  'android/app/src/debug/AndroidManifest.xml',
  'android/app/src/profile/AndroidManifest.xml',
];
const _dataExtractionRulesPath =
    'android/app/src/main/res/xml/data_extraction_rules.xml';
const _fullBackupContentPath =
    'android/app/src/main/res/xml/full_backup_content.xml';

const _backupAttributes = {
  'dataExtractionRules': '@xml/data_extraction_rules',
  'fullBackupContent': '@xml/full_backup_content',
};

typedef _RuleTarget = ({String domain, String path});

/// Everything a restored copy cannot use without this phone's Keystore.
///
/// flutter_secure_storage keeps its values in `FlutterSecureStorage.xml`
/// (the plugin's default file name) and, outside EncryptedSharedPreferences
/// mode, its wrapped AES key in `FlutterSecureKeyStorage.xml`. The database
/// directory is resolved from db_client, so moving the database fails here
/// until the rules follow it. `getApplicationSupportDirectory()` is the
/// `file` domain on Android.
Set<_RuleTarget> _keystoreBoundTargets() {
  const base = '/files';
  final databaseDirectory = p
      .split(
        p.relative(p.dirname(buildSharedDatabasePath(base)), from: base),
      )
      .join('/');
  return {
    (domain: 'sharedpref', path: 'FlutterSecureStorage.xml'),
    (domain: 'sharedpref', path: 'FlutterSecureKeyStorage.xml'),
    (domain: 'file', path: databaseDirectory),
  };
}

void main() {
  final required = _keystoreBoundTargets();

  group('Android backup rules', () {
    test('main manifest points both backup attributes at the rule files', () {
      final manifest = File(_mainManifestPath).readAsStringSync();

      expect(_mainManifestProblems(manifest), isEmpty);
      expect(File(_dataExtractionRulesPath).existsSync(), isTrue);
      expect(File(_fullBackupContentPath).existsSync(), isTrue);
    });

    test('build-type manifests leave the backup attributes alone', () {
      for (final path in _buildTypeManifestPaths) {
        expect(
          _buildTypeManifestProblems(File(path).readAsStringSync()),
          isEmpty,
          reason: path,
        );
      }
    });

    test('Android 12+ rules exclude Keystore-bound files from cloud backup '
        'and device transfer', () {
      expect(
        _dataExtractionRuleProblems(
          File(_dataExtractionRulesPath).readAsStringSync(),
          required,
        ),
        isEmpty,
      );
    });

    test('Android 11 and older rules exclude Keystore-bound files', () {
      expect(
        _fullBackupContentProblems(
          File(_fullBackupContentPath).readAsStringSync(),
          required,
        ),
        isEmpty,
      );
    });

    test('no secure storage renames the preferences file the rules '
        'exclude', () {
      final renamed =
          [
                Directory('lib'),
                ...Directory('packages').listSync().whereType<Directory>().map(
                  (package) => Directory(p.join(package.path, 'lib')),
                ),
              ]
              .where((directory) => directory.existsSync())
              .expand((directory) => directory.listSync(recursive: true))
              .whereType<File>()
              .where((file) => file.path.endsWith('.dart'))
              .where(
                (file) => RegExp(
                  r'\bsharedPreferencesName\s*:',
                ).hasMatch(file.readAsStringSync()),
              )
              .map((file) => file.path)
              .toList();

      expect(
        renamed,
        isEmpty,
        reason:
            'The backup rules exclude flutter_secure_storage by its default '
            'file name. Exclude the new name as well before renaming it.',
      );
    });
  });

  group('backup rule validators', () {
    test('reject a main manifest without dataExtractionRules', () {
      expect(
        _mainManifestProblems(
          _manifest(
            'android:fullBackupContent="@xml/full_backup_content"',
          ),
        ),
        contains(contains('dataExtractionRules')),
      );
    });

    test('reject a main manifest without fullBackupContent', () {
      expect(
        _mainManifestProblems(
          _manifest(
            'android:dataExtractionRules="@xml/data_extraction_rules"',
          ),
        ),
        contains(contains('fullBackupContent')),
      );
    });

    test('reject a build-type manifest that removes a backup attribute', () {
      expect(
        _buildTypeManifestProblems(
          _manifest('tools:remove="android:dataExtractionRules"'),
        ),
        isNotEmpty,
      );
    });

    test('reject rules that still restore the database', () {
      // The rules #761 shipped: the secure storage file alone.
      const legacyRules = '''
<data-extraction-rules>
  <cloud-backup>
    <exclude domain="sharedpref" path="FlutterSecureStorage" />
  </cloud-backup>
  <device-transfer>
    <exclude domain="sharedpref" path="FlutterSecureStorage" />
  </device-transfer>
</data-extraction-rules>
''';

      final problems = _dataExtractionRuleProblems(legacyRules, required);

      expect(problems, contains(contains('openvine/database')));
      expect(problems, contains(contains('FlutterSecureKeyStorage.xml')));
      expect(problems, isNot(contains(contains('FlutterSecureStorage.xml'))));
    });

    test('reject rules with no device-transfer section', () {
      final rules = _dataExtractionRules(required).replaceAll(
        RegExp('<device-transfer>.*</device-transfer>', dotAll: true),
        '',
      );

      expect(
        _dataExtractionRuleProblems(rules, required),
        contains(contains('device-transfer')),
      );
    });

    test('reject full backup content without the database', () {
      const rules = '''
<full-backup-content>
  <exclude domain="sharedpref" path="FlutterSecureStorage.xml" />
  <exclude domain="sharedpref" path="FlutterSecureKeyStorage.xml" />
</full-backup-content>
''';

      expect(
        _fullBackupContentProblems(rules, required),
        contains(contains('openvine/database')),
      );
    });

    test('accept complete rules', () {
      expect(
        _dataExtractionRuleProblems(_dataExtractionRules(required), required),
        isEmpty,
      );
    });
  });
}

List<String> _mainManifestProblems(String source) {
  final application = _application(source);
  return [
    for (final MapEntry(key: name, value: reference)
        in _backupAttributes.entries)
      if (application.getAttribute(name, namespace: _androidNamespace) !=
          reference)
        'main <application> must set android:$name="$reference"',
  ];
}

List<String> _buildTypeManifestProblems(String source) {
  final application = _application(source);
  final toolsOverrides = [
    application.getAttribute('replace', namespace: _toolsNamespace),
    application.getAttribute('remove', namespace: _toolsNamespace),
  ].whereType<String>().join(',');
  return [
    for (final name in _backupAttributes.keys)
      if (application.getAttribute(name, namespace: _androidNamespace) !=
              null ||
          toolsOverrides.contains('android:$name'))
        'build-type <application> must not override android:$name',
  ];
}

List<String> _dataExtractionRuleProblems(
  String source,
  Set<_RuleTarget> required,
) {
  final root = XmlDocument.parse(source).rootElement;
  return [
    for (final section in ['cloud-backup', 'device-transfer'])
      ..._sectionProblems(
        root.childElements.where((element) => element.localName == section),
        section,
        required,
      ),
  ];
}

List<String> _fullBackupContentProblems(
  String source,
  Set<_RuleTarget> required,
) => _sectionProblems(
  [XmlDocument.parse(source).rootElement],
  'full-backup-content',
  required,
);

/// A section that is missing backs up everything, so it fails like a section
/// missing every exclusion.
List<String> _sectionProblems(
  Iterable<XmlElement> sections,
  String name,
  Set<_RuleTarget> required,
) {
  if (sections.length != 1) {
    return ['<$name> must appear exactly once'];
  }
  final excluded = _excludedTargets(sections.single);
  return [
    for (final target in required)
      if (!excluded.contains(target))
        '<$name> must exclude ${target.domain}:${target.path}',
  ];
}

Set<_RuleTarget> _excludedTargets(XmlElement section) => {
  for (final exclude in section.childElements.where(
    (element) => element.localName == 'exclude',
  ))
    _normalized(
      domain: exclude.getAttribute('domain') ?? '',
      path: exclude.getAttribute('path') ?? '',
    ),
};

/// Android matches a `sharedpref` rule with or without the `.xml` extension,
/// and a directory rule with or without its trailing slash.
_RuleTarget _normalized({required String domain, required String path}) {
  var normalized = path.replaceFirst(RegExp(r'^\./'), '');
  normalized = normalized.replaceFirst(RegExp(r'/+$'), '');
  if (domain == 'sharedpref' && !normalized.endsWith('.xml')) {
    normalized = '$normalized.xml';
  }
  return (domain: domain, path: normalized);
}

XmlElement _application(String source) =>
    XmlDocument.parse(source).rootElement.childElements
        .singleWhere((element) => element.localName == 'application');

String _manifest(String applicationAttributes) =>
    '''
<manifest xmlns:android="$_androidNamespace" xmlns:tools="$_toolsNamespace">
  <application $applicationAttributes />
</manifest>
''';

String _dataExtractionRules(Set<_RuleTarget> excluded) {
  final excludes = [
    for (final target in excluded)
      '<exclude domain="${target.domain}" path="${target.path}" />',
  ].join('\n');
  return '''
<data-extraction-rules>
  <cloud-backup>
$excludes
  </cloud-backup>
  <device-transfer>
$excludes
  </device-transfer>
</data-extraction-rules>
''';
}

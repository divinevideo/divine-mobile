// ABOUTME: Pins that a Maestro flow copying the private key also overwrites it.
// ABOUTME: The copy is the journey under test; the key left behind is not.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:yaml/yaml.dart';

/// The control whose tap puts the signed-in account's `nsec` on the device
/// clipboard.
///
/// Asserting the button is *visible* is harmless and several flows do it;
/// only a tap moves key material, so this guard keys on the tap.
const String _copyPrivateKeyId = SemanticIds.keyManagementCopyNsecButton;

/// The public key copy on the same screen: the control a flow taps to
/// overwrite the device clipboard.
///
/// Maestro cannot do that itself. Its `setClipboard` only sets Maestro's own
/// copied text, which `pasteText` reads back, and never reaches the device
/// (`Orchestra.setClipboardCommand` in the `MAESTRO_VERSION` codemagic.yaml
/// pins).
const String _copyPublicKeyId = SemanticIds.keyManagementCopyNpubButton;

/// The flow-config key whose commands Maestro runs from a `finally`.
///
/// A trailing command runs only when the flow reaches it, so a failure
/// between the copy and the end of the flow leaves the key on the clipboard —
/// which is the state #8828 is about. The hook runs pass or fail, for a direct
/// run and for a subflow reached through `runFlow:` alike, so the guard
/// requires the overwrite there rather than anywhere in the command list.
const _onFlowComplete = 'onFlowComplete';

const _maestroDir = 'e2e/maestro';

/// A Maestro flow's optional config header and its command list.
///
/// A flow is two YAML documents — an `appId`/`onFlowComplete` header, then the
/// commands — so the commands are the last document rather than the first. A
/// file with a single document declares no header.
({YamlMap? header, List<Object?> commands}) _documentsOf(File flow) {
  final documents = loadYamlDocuments(flow.readAsStringSync());
  if (documents.isEmpty) return (header: null, commands: const []);
  final header = documents.length > 1 ? documents.first.contents.value : null;
  final commands = documents.last.contents.value;
  return (
    header: header is YamlMap ? header : null,
    commands: commands is YamlList ? commands.toList() : const [],
  );
}

/// Whether [node] or anything nested under it taps [id].
///
/// The walk is recursive because `tapOn` can sit under `repeat:`, `retry:` or
/// an inline `runFlow:`, and reads the argument as a map rather than matching
/// source text because Maestro accepts both the nested and inline forms.
bool _tapsId(Object? node, String id) {
  if (node is List) return node.any((child) => _tapsId(child, id));
  if (node is! YamlMap) return false;
  final argument = node['tapOn'];
  if (argument is YamlMap && argument['id'] == id) return true;
  return node.values.any((child) => _tapsId(child, id));
}

/// Whether [header]'s `onFlowComplete` hook overwrites the device clipboard.
bool _overwritesClipboardOnComplete(YamlMap? header) =>
    _tapsId(header?[_onFlowComplete], _copyPublicKeyId);

void main() {
  group('Maestro clipboard hygiene', () {
    final flows =
        Directory(_maestroDir)
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('.yaml'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    test('the suite is present and readable', () {
      // A guard over an empty set passes for the wrong reason; #8777 is
      // exactly the kind of change that can move these files.
      expect(flows, isNotEmpty, reason: 'no flows found under $_maestroDir');
      expect(
        flows.map((file) => file.path),
        contains(contains('backupYourKey.yaml')),
      );
    });

    test('a flow still taps the control the guard watches', () {
      // The guard below skips every flow that does not tap the button, so a
      // flow that stops reaching it by id turns the guard green while the
      // copy still happens — #8777's shape exactly. Pin that the detector has
      // something to check.
      expect(
        flows.where(
          (flow) => _tapsId(_documentsOf(flow).commands, _copyPrivateKeyId),
        ),
        isNotEmpty,
        reason:
            'no flow under $_maestroDir taps $_copyPrivateKeyId, so the '
            'clipboard guard checks nothing. If the copy journey reaches the '
            'button another way, target it by '
            '`SemanticIds.keyManagementCopyNsecButton`; if the journey was '
            'deleted, delete this guard with it (#8828).',
      );
    });

    test('a flow that copies the private key overwrites it on completion', () {
      for (final flow in flows) {
        final (:header, :commands) = _documentsOf(flow);
        if (!_tapsId(commands, _copyPrivateKeyId)) continue;

        expect(
          _overwritesClipboardOnComplete(header),
          isTrue,
          reason:
              '${flow.path} taps $_copyPrivateKeyId, which copies a live '
              "account's private key to the device clipboard. The flow must "
              'tap $_copyPublicKeyId from an `$_onFlowComplete` hook, which '
              'Maestro runs pass or fail, so the app overwrites the key. '
              "Maestro's own `setClipboard` never reaches the device, and a "
              'trailing command is skipped by any failure after the copy '
              '(#8828).',
        );
      }
    });

    group('detector', () {
      test('finds a tap nested inside another command', () {
        final commands = loadYaml('''
- retry:
    maxRetries: 2
    commands:
      - tapOn:
          id: "$_copyPrivateKeyId"
''');

        expect(_tapsId(commands, _copyPrivateKeyId), isTrue);
      });

      test('does not treat a visibility assertion as a tap', () {
        final commands = loadYaml('''
- assertVisible:
    id: "$_copyPrivateKeyId"
- extendedWaitUntil:
    visible:
      id: "$_copyPrivateKeyId"
    timeout: 30000
''');

        expect(_tapsId(commands, _copyPrivateKeyId), isFalse);
      });

      test('accepts only a hook that taps the public key copy', () {
        final tapsPublicKeyCopy = loadYaml('''
appId: co.openvine.app.staging
$_onFlowComplete:
  - runFlow:
      when:
        visible:
          id: "$_copyPrivateKeyId"
      commands:
        - scrollUntilVisible:
            element:
              id: "$_copyPublicKeyId"
            direction: UP
            optional: true
        - tapOn:
            id: "$_copyPublicKeyId"
            optional: true
''') as YamlMap;
        final scrollsWithoutTapping = loadYaml('''
appId: co.openvine.app.staging
$_onFlowComplete:
  - scrollUntilVisible:
      element:
        id: "$_copyPublicKeyId"
      direction: UP
''') as YamlMap;
        final setsMaestroClipboard = loadYaml('''
appId: co.openvine.app.staging
$_onFlowComplete:
  - setClipboard: "cleared"
''') as YamlMap;
        final tapsPrivateKeyCopy = loadYaml('''
appId: co.openvine.app.staging
$_onFlowComplete:
  - tapOn:
      id: "$_copyPrivateKeyId"
''') as YamlMap;
        final withoutHook =
            loadYaml('appId: co.openvine.app.staging') as YamlMap;

        expect(_overwritesClipboardOnComplete(tapsPublicKeyCopy), isTrue);
        expect(_overwritesClipboardOnComplete(scrollsWithoutTapping), isFalse);
        // Sets Maestro's copied text only; the device keeps the key.
        expect(_overwritesClipboardOnComplete(setsMaestroClipboard), isFalse);
        expect(_overwritesClipboardOnComplete(tapsPrivateKeyCopy), isFalse);
        expect(_overwritesClipboardOnComplete(withoutHook), isFalse);
        expect(_overwritesClipboardOnComplete(null), isFalse);
      });
    });
  });
}
